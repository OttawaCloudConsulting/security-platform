#!/usr/bin/env bash
set -euo pipefail

# defectdojo-homelab-validate.sh — the LIVE gate for the DefectDojo chart
# (kubernetes/defectdojo) once it is deployed by Argo CD onto a real cluster,
# behind the real TLS terminator and on the real hostnames, rather than on the
# throwaway kind cluster that scripts/defectdojo-live-smoke.sh owns.
#
# WHY THIS EXISTS. Synced + Healthy proves nothing (ADR-022). Argo CD decides a
# hook phase purely from the Job's exit code, and it decides Healthy from pod
# readiness. A DefectDojo whose CSRF trusted origins are wrong still deploys
# green, still serves GET /login with HTTP 200, and then refuses every browser
# login with `403 Origin checking failed`. A Celery worker whose broker password
# is wrong is still Running. A second sync that silently re-ran first-boot setup
# is still Synced. This gate therefore derives every verdict from a MEASURED
# value: an HTTP status plus ssl_verify_result against the system trust store,
# the SAN list of the certificate actually served, a login that ends at
# /dashboard 200, an exact 403 for a foreign Origin, a Celery pong, a hook phase
# read back out of the Application's status, a UID, a log-line count, and an
# API object count compared before and after.
#
# Runtime: well under a minute against a warm instance. No step waits on a
# rollout; the gate measures the state it finds.
#
# Never set the executable bit on this file (project rule). Invoke as: bash scripts/defectdojo-homelab-validate.sh
#
# Example (first sync; capture the state the second sync is compared against):
#   bash scripts/defectdojo-homelab-validate.sh \
#     --url https://<primary-host> --alt-url https://<alternative-host> \
#     --context <kube-context> --namespace defectdojo --app defectdojo \
#     --sync-pass first --write-state <state-file> --token-file <token-file>
#
# Example (after the second Argo CD sync of the SAME revision):
#   bash scripts/defectdojo-homelab-validate.sh \
#     --url https://<primary-host> --alt-url https://<alternative-host> \
#     --context <kube-context> --namespace defectdojo --app defectdojo \
#     --sync-pass second --pre-state <state-file> --token-file <token-file>
#
# TWO DESIGN FORKS, resolved in plan 29-01 and recorded here so a future reader
# does not re-open them:
#
#   1. Every URL, the kube context, the namespace and the Application name are
#      REQUIRED, and this script owns NO background process. It takes the two
#      public HTTPS URLs the operator's browser uses, so the TLS, SAN and CSRF
#      verdicts are about the real front door and not a port-forward. The same
#      gate is re-pointed at another instance with no code change.
#
#   2. This is a SIBLING of scripts/defectdojo-live-smoke.sh, not a
#      parameterised version of it. That script keeps its kind checks untouched;
#      its login step sends only a Referer and verifies against a smoke CA, and
#      both of those are exactly what this gate must NOT do (see CSRF below).
#      The accounting discipline (FAILURES / SKIPPED / CHECKS_PASSED and the
#      three-branch summary) is lifted verbatim from
#      scripts/nexus-homelab-validate.sh.
#
# CSRF (Phase 29 D-05). The kind smoke's comment "Do NOT add
# DD_CSRF_TRUSTED_ORIGINS" is SUPERSEDED by Phase 29 D-05 and is deliberately
# not copied here. Mechanism (Django 5.2.16 CsrfViewMiddleware.process_view):
# when an Origin header is present it is checked against the good origin, which
# is built as http:// because request.is_secure() is false behind an L4 TLS
# proxy; with no Origin and a non-secure request, only the token is checked. A
# Referer-only curl POST therefore passes whether or not the fix is deployed.
# Browsers always send Origin on POST, so this gate sends
# `Origin: https://<host>` on BOTH hostnames and must see 302 then /dashboard
# 200, and it runs a negative control with a foreign Origin that must be
# refused with 403. A 302 on the foreign Origin means the Origin check is not
# running at all.
#
# The 403 body does NOT carry the reason in production. Django's csrf_403.html
# (5.2.16) renders "Reason given for failure" only inside {% if DEBUG %}, and
# DefectDojo 3.3.200 defaults DD_DEBUG to False, so the body always says
# "CSRF verification failed. Request aborted." and nothing more. The reason
# ("Origin checking failed - <origin> does not match any trusted origins.") is
# logged by the django.security.csrf logger at WARNING, which the default
# DD_LOG_LEVEL (INFO) lets through to the uwsgi container's console. The
# negative control reads the reason from the body when DEBUG is on and from the
# uwsgi log otherwise; a 403 whose cause cannot be attributed is not a pass.
#
# IDEMPOTENT-PATH MARKERS (read from DefectDojo 3.3.200 source on 2026-09-27):
#   docker/entrypoint-initializer.sh at tag 3.3.200 contains no log message of
#   its own for either path. After waiting for the database it runs
#   `python manage.py complete_initialization`, and that management command,
#   dojo/management/commands/complete_initialization.py at tag 3.3.200, prints:
#     line 39:  "Admin user already exists; skipping first-boot setup"
#               (printed when the admin user already exists; first-boot setup
#               is skipped. The first-boot path prints "Running first boot
#               setup", line 135, instead.)
#     line 33:  call_command("migrate", interactive=False), preceded by the
#               literal "Applying migrations" on EVERY run (line 32), so that
#               literal is NOT evidence that a migration was applied.
#   Django's own migrate command, django/core/management/commands/migrate.py
#   at tag 5.2.16 (the Django==5.2.16 pin in DefectDojo 3.3.200
#   requirements.txt), prints on a no-op plan:
#     line 325: "  No migrations to apply."
#   and "  Applying <app>.<NNNN_name>..." for each migration it does apply.
#   The two marker strings asserted on a second sync are therefore:
#     ADMIN_EXISTS_MARKER  = "Admin user already exists; skipping first-boot setup"
#     NO_MIGRATIONS_MARKER = "No migrations to apply."
#
# Exit codes:
#   0  every live check that ran passed, or nothing ran (the summary then says
#      NOTHING RAN, never ALL PASS)
#   1  at least one live check failed, or a required hard-tier binary
#      (curl, jq, openssl) is missing. `kubectl` is SOFT tier: absent, the
#      cluster-side checks produce SKIPPED entries, not failures, and the TLS
#      checks still run against --url and --alt-url.
#   2  usage or preflight error (a required argument is missing, a value is
#      invalid, an argument is unknown, or a --pre-state / --token-file is
#      unreadable or malformed)
#
# Credentials: the admin password is read from the cluster Secret `defectdojo`
# (key DD_ADMIN_PASSWORD) straight into a mode-0600 file under a private temp
# directory, and is sent to curl only as `--data-urlencode password@FILE`, so it
# never reaches an argv. The API token (--token-file) is sent only as a
# `-H @FILE` header file, built mode 0600. Neither value is ever echoed, the
# state file holds no credential, `set -x` is never enabled anywhere in this
# file, and the EXIT trap removes the temp directory.
#
# No hostname, address, apex domain or kube-context name appears anywhere in
# this file: every one of them is a runtime argument.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'USAGE_EOF'
Usage: bash scripts/defectdojo-homelab-validate.sh --url <URL> --alt-url <URL> --context <kube-context> --namespace <ns> --app <name> --sync-pass <first|second> [options]

Required (there are NO defaults for these — the gate refuses to guess):
  --url <https://host>         Primary public URL of DefectDojo (checks named *-INFRA).
  --alt-url <https://host>     Alternative public URL (DD_SITE_URL alternative host,
                               checks named *-HOME). Both must start with https://.
  --context <kube-context>     kubeconfig context every kubectl call is pinned to.
                               KUBECONFIG is honoured from the environment.
  --namespace <ns>             Namespace DefectDojo is deployed in.
  --app <name>                 Argo CD Application name.
  --sync-pass <first|second>   Which Argo CD sync this run follows. `second`
                               evaluates SECOND-SYNC-IDEMPOTENT and needs
                               --pre-state and --token-file.

Optional:
  --write-state <file>         Write the measured state (initializer and
                               ServiceAccount UIDs, Application revision, product
                               and finding counts) as JSON to <file>.
  --pre-state <file>           State file written by an earlier run with
                               --write-state (required with --sync-pass second).
  --token-file <file>          File holding a DefectDojo API v2 token; used only
                               for the product/finding counts (required with
                               --sync-pass second).
  --argocd-namespace <ns>      Namespace Argo CD runs in (default: argocd)
  -h, --help                   Print this help and exit 0

Exit codes: 0 all checks that ran passed (or NOTHING RAN), 1 a check failed or
a hard-tier binary is missing, 2 usage or preflight error.
USAGE_EOF
}

usage_error() {
  echo "ERROR: $1" >&2
  usage >&2
  exit 2
}

# ── Arguments ────────────────────────────────────────────────────────────────
# A shift loop, because every option takes an argument (same shape as
# scripts/nexus-homelab-validate.sh).
PRIMARY_URL=""
ALT_URL=""
KUBE_CONTEXT=""
NS=""
APP=""
SYNC_PASS=""
WRITE_STATE=""
PRE_STATE=""
TOKEN_FILE=""
ARGOCD_NS="argocd"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      if [[ $# -lt 2 ]]; then usage_error "--url requires a value, e.g. --url https://<primary-host>"; fi
      PRIMARY_URL="$2"
      shift 2
      ;;
    --alt-url)
      if [[ $# -lt 2 ]]; then usage_error "--alt-url requires a value, e.g. --alt-url https://<alternative-host>"; fi
      ALT_URL="$2"
      shift 2
      ;;
    --context)
      if [[ $# -lt 2 ]]; then usage_error "--context requires a kube-context name"; fi
      KUBE_CONTEXT="$2"
      shift 2
      ;;
    --namespace)
      if [[ $# -lt 2 ]]; then usage_error "--namespace requires a value"; fi
      NS="$2"
      shift 2
      ;;
    --app)
      if [[ $# -lt 2 ]]; then usage_error "--app requires a value"; fi
      APP="$2"
      shift 2
      ;;
    --sync-pass)
      if [[ $# -lt 2 ]]; then usage_error "--sync-pass requires a value: first or second"; fi
      SYNC_PASS="$2"
      shift 2
      ;;
    --write-state)
      if [[ $# -lt 2 ]]; then usage_error "--write-state requires a file path"; fi
      WRITE_STATE="$2"
      shift 2
      ;;
    --pre-state)
      if [[ $# -lt 2 ]]; then usage_error "--pre-state requires a file path"; fi
      PRE_STATE="$2"
      shift 2
      ;;
    --token-file)
      if [[ $# -lt 2 ]]; then usage_error "--token-file requires a file path"; fi
      TOKEN_FILE="$2"
      shift 2
      ;;
    --argocd-namespace)
      if [[ $# -lt 2 ]]; then usage_error "--argocd-namespace requires a value"; fi
      ARGOCD_NS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage_error "Unknown argument: $1"
      ;;
  esac
done

# Checked AFTER the loop so --help and an unknown argument are both reachable
# without a URL. A missing required argument is an error, never a default.
if [[ -z "$PRIMARY_URL" ]]; then
  usage_error "--url is required and was not supplied. There is no default DefectDojo URL and this script will not guess one."
fi
if [[ -z "$ALT_URL" ]]; then
  usage_error "--alt-url is required and was not supplied. There is no default alternative hostname; both hostnames the operator uses must be tested, and neither is written into this file."
fi
if [[ -z "$KUBE_CONTEXT" ]]; then
  usage_error "--context is required and was not supplied. Every kubectl call is pinned to an explicit context; the current context is never assumed."
fi
if [[ -z "$NS" ]]; then
  usage_error "--namespace is required and was not supplied. There is no default namespace; the gate will not guess where DefectDojo runs."
fi
if [[ -z "$APP" ]]; then
  usage_error "--app is required and was not supplied. There is no default Argo CD Application name."
fi
# --sync-pass has no default FOR A REASON: a silent default of `first` on a
# second-sync run would skip SECOND-SYNC-IDEMPOTENT and let the run pass
# without ever asserting idempotency (D-14).
if [[ -z "$SYNC_PASS" ]]; then
  usage_error "--sync-pass is required and was not supplied (first or second). It selects whether SECOND-SYNC-IDEMPOTENT is asserted, so it is never defaulted."
fi
if [[ "$SYNC_PASS" != "first" && "$SYNC_PASS" != "second" ]]; then
  usage_error "--sync-pass must be 'first' or 'second', got '${SYNC_PASS}'"
fi
# https only: the TLS verdicts are the point, and an http:// URL would send the
# admin password in clear text.
for u in "$PRIMARY_URL" "$ALT_URL"; do
  if [[ "$u" != https://* ]]; then
    usage_error "URLs must start with https:// (got '${u}'); this gate verifies the served certificate and never sends credentials over plain HTTP."
  fi
done
# A first-sync run cannot satisfy the second-sync assertion: it needs the state
# an earlier run captured, and a token to re-count products and findings.
if [[ "$SYNC_PASS" = "second" ]]; then
  if [[ -z "$PRE_STATE" ]]; then
    usage_error "--sync-pass second requires --pre-state <file>, written by an earlier run with --write-state. Without it there is nothing to compare against."
  fi
  if [[ -z "$TOKEN_FILE" ]]; then
    usage_error "--sync-pass second requires --token-file <file>; the product and finding counts are part of the idempotency assertion."
  fi
fi
if [[ -n "$PRE_STATE" && ! -r "$PRE_STATE" ]]; then
  usage_error "--pre-state file '${PRE_STATE}' does not exist or is not readable"
fi
if [[ -n "$TOKEN_FILE" && ! -r "$TOKEN_FILE" ]]; then
  usage_error "--token-file '${TOKEN_FILE}' does not exist or is not readable"
fi

# URL -> host[:port] for Origin/Referer, bare host for SNI and the SAN check,
# host:port for openssl s_client. One trailing slash stripped.
PRIMARY_URL="${PRIMARY_URL%/}"
ALT_URL="${ALT_URL%/}"
url_hostport() {
  local hp="${1#https://}"
  printf '%s' "${hp%%/*}"
}
PRIMARY_HOSTPORT="$(url_hostport "$PRIMARY_URL")"
ALT_HOSTPORT="$(url_hostport "$ALT_URL")"
PRIMARY_HOST="${PRIMARY_HOSTPORT%%:*}"
ALT_HOST="${ALT_HOSTPORT%%:*}"
if [[ -z "$PRIMARY_HOST" || -z "$ALT_HOST" ]]; then
  usage_error "could not derive a hostname from --url '${PRIMARY_URL}' / --alt-url '${ALT_URL}'"
fi

# ── Scratch space ────────────────────────────────────────────────────────────
# Assigned BEFORE the trap so `set -u` cannot trip inside the cleanup path. The
# `|| true` here is cleanup hygiene on a best-effort teardown, not a silenced
# assertion — no verdict is derived from it. It is the ONLY `|| true` in this
# file.
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT" || true' EXIT

FAILURES=()
# SKIPPED: sub-checks that did not run (an optional tool is absent, or the
# subject of the check does not apply to this run). Reported separately from
# FAILURES and separately from passes — a skip must never read as a pass — and
# it never affects the exit status.
SKIPPED=()
# CHECKS_PASSED: live checks that actually executed and passed. Counted from the
# run itself, so the summary cannot claim a pass on a run where nothing ran.
CHECKS_PASSED=0

# require_success: run a command that is expected to exit 0.
#
# Deliberately NOT copied from smoke-scans.sh: run_scan / run_scan_rc. Their
# PASS-on-exit-1 inversion is scanner semantics — applied here it would score a
# BROKEN deployment as a pass, which is the exact failure mode this script
# exists to prevent.
#
# Kept verbatim with the rest of the accounting core even though no check in
# this gate currently wraps a bare command with it, so the core stays
# byte-comparable with scripts/nexus-homelab-validate.sh.
# shellcheck disable=SC2329
require_success() {
  local label="$1"
  shift
  local rc=0
  "$@" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    echo "==> ${label}: exit=${rc} (PASS - completed successfully)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    echo "==> ${label}: exit=${rc} (FAIL - expected exit 0)"
    FAILURES+=("${label}: exited ${rc}, expected 0")
  fi
  return 0
}

# pass / fail: the two ends of every inline assertion below. An assertion must
# never swallow its own result with `|| true` — an assertion that ignores its
# own failure IS the false-pass mechanism this script exists to prevent.
pass() {
  echo "==> $1: PASS - $2"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
}
fail() {
  echo "==> $1: FAIL - $2"
  FAILURES+=("$1: $2")
}

# print_summary: the terminal verdict. Skips print first, under their own
# heading, on every path — they are not failures and they are not passes.
print_summary() {
  echo
  echo "=== Summary ==="
  if [ "${#SKIPPED[@]}" -gt 0 ]; then
    echo "SKIPPED - ${#SKIPPED[@]} sub-check(s) did not run. A SKIP IS NOT A PASS:"
    for s in "${SKIPPED[@]}"; do
      echo "  - ${s}"
    done
    echo
  fi
  if [ "${#FAILURES[@]}" -gt 0 ]; then
    echo "FAILED - one or more live checks did not produce the expected result:"
    for f in "${FAILURES[@]}"; do
      echo "  - ${f}"
    done
    exit 1
  elif [ "$CHECKS_PASSED" -eq 0 ]; then
    # Zero failures on a run where zero checks executed is NOT a pass. Saying
    # ALL PASS here is the vacuous-green this convention exists to forbid.
    echo "NOTHING RAN - 0 live check(s) executed; ${#SKIPPED[@]} sub-check(s) skipped (not passed). Nothing was proven."
    exit 0
  else
    echo "ALL PASS - ${CHECKS_PASSED} live check(s) executed and passed; ${#SKIPPED[@]} sub-check(s) skipped (not passed)."
    exit 0
  fi
}

# ── Preflight, hard tier ─────────────────────────────────────────────────────
# Every binary here drives a check this gate cannot render a verdict without.
# Run AFTER argument parsing so --help and the usage errors work on a machine
# without them.
for bin in curl jq openssl; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 1
  fi
done

# The pre-state file must be the JSON an earlier --write-state produced. A
# malformed file is a preflight error (exit 2), not a failed check.
if [[ -n "$PRE_STATE" ]]; then
  if ! jq -e 'type == "object" and has("initializer_uid") and has("serviceaccount_uid") and has("product_count") and has("finding_count") and has("captured_at") and has("app_revision")' "$PRE_STATE" >/dev/null 2>&1; then
    echo "ERROR: --pre-state '${PRE_STATE}' is not a state file written by --write-state (expected keys initializer_uid, serviceaccount_uid, product_count, finding_count, captured_at, app_revision)" >&2
    exit 2
  fi
fi

# ── Preflight, soft tier ─────────────────────────────────────────────────────
# Without kubectl the cluster-side checks cannot run (and the admin password
# cannot be read), but the TLS checks against both URLs still can. The skip is
# named and accounted for, so it can never be mistaken for a pass.
KUBECTL_OK=1
if ! command -v kubectl &>/dev/null; then
  KUBECTL_OK=0
  SKIPPED+=("cluster-side checks (HOMELAB-LOGIN-ORIGIN-INFRA, HOMELAB-LOGIN-ORIGIN-HOME, the HOMELAB-CSRF-FOREIGN-403 log attribution, HOMELAB-CELERY-PING, ARGOCD-HOOK-PHASE, state capture, SECOND-SYNC-IDEMPOTENT): 'kubectl' not found on PATH")
fi

# The API token, as a curl header FILE (mode 0600). `$(< file)` strips trailing
# newlines; printf is a shell builtin, so the token never reaches an argv.
AUTH_HDR=""
if [[ -n "$TOKEN_FILE" ]]; then
  AUTH_HDR="$OUT/auth-hdr"
  token_val="$(tr -d '\r\n' < "$TOKEN_FILE")"
  if [[ -z "$token_val" ]]; then
    echo "ERROR: --token-file '${TOKEN_FILE}' is empty" >&2
    exit 2
  fi
  ( umask 077; printf 'Authorization: Token %s\n' "$token_val" > "$AUTH_HDR" )
  unset token_val
fi

echo "=== defectdojo-homelab-validate: ${PRIMARY_URL} + ${ALT_URL} (context ${KUBE_CONTEXT}, namespace ${NS}, app ${ARGOCD_NS}/${APP}, sync pass ${SYNC_PASS}) ==="
echo

# EVERY kubectl CALL IN THIS FILE PINS --context "$KUBE_CONTEXT" AND A
# --namespace ON THE SAME LINE AS `kubectl`. None may rely on the current
# context or namespace: the operator's current context may be a different
# cluster entirely. KUBECONFIG is honoured from the environment and never set.
#
# EVERY command that can fail is captured with `|| rc=$?` into an explicit
# verdict, never left bare. Under `set -euo pipefail` a bare failing command
# would kill the run before print_summary, which is a crash rather than a
# verdict.

# ── 1. HOMELAB-TLS-INFRA / HOMELAB-TLS-HOME ─────────────────────────────────
# Verified against the SYSTEM trust store: the certificate must be a publicly
# trusted (Let's Encrypt prod, ADR-025) certificate, so no CA file is passed and
# verification is never disabled. curl exits 60 on a verification failure, so
# its exit status is asserted as well as ssl_verify_result. The served
# certificate must carry BOTH hostnames as SANs, whichever name served it.
echo "--- 1. TLS on both hostnames (system trust store) ---"
check_tls() {
  local id="$1" url="$2" host="$3" hostport="$4"
  local tls_rc=0 tls_out="" tls_code="" tls_verify="" cert_rc=0 connect="$hostport"
  if [[ "$connect" != *:* ]]; then
    connect="${connect}:443"
  fi
  tls_out="$(curl -sS --proto =https -o /dev/null -w '%{http_code} %{ssl_verify_result}' "${url}/login" 2>"$OUT/${id}.err")" || tls_rc=$?
  tls_code="${tls_out%% *}"
  tls_verify="${tls_out##* }"
  openssl s_client -connect "$connect" -servername "$host" </dev/null 2>/dev/null \
    | openssl x509 -noout -ext subjectAltName > "$OUT/${id}-san.txt" 2>&1 || cert_rc=$?
  if [ "$tls_rc" -ne 0 ]; then
    fail "$id" "curl against ${url}/login exited ${tls_rc} (60 = certificate did not verify against the system trust store): $(tr '\n' ' ' < "$OUT/${id}.err")"
  elif [ "$tls_code" != "200" ] || [ "$tls_verify" != "0" ]; then
    fail "$id" "GET ${url}/login returned http_code ${tls_code}, ssl_verify_result ${tls_verify}; expected '200 0'"
  elif [ "$cert_rc" -ne 0 ]; then
    fail "$id" "could not read the subjectAltName of the certificate served at ${connect} (SNI ${host}) with openssl (exit ${cert_rc}): $(tr '\n' ' ' < "$OUT/${id}-san.txt" | cut -c1-300)"
  elif ! grep -qF "DNS:${PRIMARY_HOST}" "$OUT/${id}-san.txt"; then
    fail "$id" "certificate served at ${connect} has no SAN DNS:${PRIMARY_HOST}; SANs: $(tr '\n' ' ' < "$OUT/${id}-san.txt")"
  elif ! grep -qF "DNS:${ALT_HOST}" "$OUT/${id}-san.txt"; then
    fail "$id" "certificate served at ${connect} has no SAN DNS:${ALT_HOST}; SANs: $(tr '\n' ' ' < "$OUT/${id}-san.txt")"
  else
    pass "$id" "GET ${url}/login -> 200 with ssl_verify_result 0 against the system trust store; served certificate SANs include DNS:${PRIMARY_HOST} and DNS:${ALT_HOST}"
  fi
}
check_tls "HOMELAB-TLS-INFRA" "$PRIMARY_URL" "$PRIMARY_HOST" "$PRIMARY_HOSTPORT"
check_tls "HOMELAB-TLS-HOME" "$ALT_URL" "$ALT_HOST" "$ALT_HOSTPORT"
echo

# ── Admin password ───────────────────────────────────────────────────────────
# Read from the cluster Secret straight into a 0600 file. printf '%s' "$(...)"
# drops a trailing newline a hand-made Secret might carry: `password@FILE`
# would URL-encode it into the password and the login would re-render with 200.
ADMIN_PW_FILE="$OUT/admin-pw"
ADMIN_PW_OK=0
ADMIN_PW_ERR=""
if [ "$KUBECTL_OK" -eq 1 ]; then
  pw_rc=0
  kubectl --context "$KUBE_CONTEXT" --namespace "$NS" get secret defectdojo -o jsonpath='{.data.DD_ADMIN_PASSWORD}' > "$OUT/admin-pw.b64" 2>"$OUT/admin-pw.err" || pw_rc=$?
  if [ "$pw_rc" -ne 0 ]; then
    ADMIN_PW_ERR="kubectl exited ${pw_rc} reading Secret ${NS}/defectdojo: $(head -c 300 "$OUT/admin-pw.err")"
  elif [ ! -s "$OUT/admin-pw.b64" ]; then
    ADMIN_PW_ERR="Secret ${NS}/defectdojo has no DD_ADMIN_PASSWORD key (or it is empty)"
  else
    dec_rc=0
    ( umask 077; printf '%s' "$(base64 -d < "$OUT/admin-pw.b64")" > "$ADMIN_PW_FILE" ) || dec_rc=$?
    if [ "$dec_rc" -ne 0 ] || [ ! -s "$ADMIN_PW_FILE" ]; then
      ADMIN_PW_ERR="DD_ADMIN_PASSWORD in Secret ${NS}/defectdojo did not base64-decode to a non-empty value (exit ${dec_rc})"
    else
      ADMIN_PW_OK=1
    fi
  fi
  rm -f "$OUT/admin-pw.b64"
fi

# get_login_form: GET /login with a fresh cookie jar, extract the form's
# csrfmiddlewaretoken (the defectdojo-live-smoke.sh sed idiom). Sets FORM_ERR
# (empty on success) and FORM_TOKEN.
FORM_ERR=""
FORM_TOKEN=""
get_login_form() {
  local url="$1" jar="$2" tag="$3" get_rc=0 get_code=""
  FORM_ERR=""
  FORM_TOKEN=""
  get_code="$(curl -sS --proto =https -c "$jar" -o "$OUT/${tag}-form.html" -w '%{http_code}' "${url}/login" 2>"$OUT/${tag}-get.err")" || get_rc=$?
  if [ -f "$OUT/${tag}-form.html" ]; then
    FORM_TOKEN="$(sed -n 's/.*name="csrfmiddlewaretoken" value="\([^"]*\)".*/\1/p' "$OUT/${tag}-form.html")"
  fi
  FORM_TOKEN="${FORM_TOKEN%%$'\n'*}"
  if [ "$get_rc" -ne 0 ] || [ "$get_code" != "200" ]; then
    FORM_ERR="GET ${url}/login for the CSRF token returned http_code ${get_code:-none} (curl exit ${get_rc}): $(tr '\n' ' ' < "$OUT/${tag}-get.err")"
  elif [ -z "$FORM_TOKEN" ]; then
    FORM_ERR="the ${url}/login form carries no csrfmiddlewaretoken hidden field"
  elif ! grep -q 'csrftoken' "$jar"; then
    FORM_ERR="GET ${url}/login set no csrftoken cookie"
  fi
}

# csrf_reason_from_body: the "Reason given for failure" block, present only
# when DEBUG is on (analog: defectdojo-live-smoke.sh KIND-LOGIN 403 branch).
csrf_reason_from_body() {
  local body="$1" reason=""
  reason="$(sed -n '/Reason given for failure/,/<\/pre>/p' "$body" | sed -e 's/<[^>]*>//g' | tr -s ' \n' ' ')"
  if [ -z "$reason" ]; then
    reason="$(sed -e 's/<[^>]*>//g' "$body" | tr -s ' \n' ' ' | cut -c1-300)"
  fi
  printf '%s' "$reason"
}

# ── 2. HOMELAB-LOGIN-ORIGIN-INFRA / HOMELAB-LOGIN-ORIGIN-HOME ────────────────
# A browser-equivalent login: the POST carries Origin: https://<host> (what a
# browser sends) as well as the Referer. 302 away from /login, then /dashboard
# with the session must be 200. A 403 prints the Django reason so a CSRF
# failure names its cause. See the CSRF paragraph in the header.
echo "--- 2. admin login with a browser-equivalent Origin, on both hostnames ---"
check_login_origin() {
  local id="$1" url="$2" hostport="$3"
  local jar="$OUT/${id}-cookies.txt" post_rc=0 post_out="" post_code="" post_location="" reason="" dash_rc=0 dash_code=""
  if [ "$KUBECTL_OK" -ne 1 ]; then
    return 0
  fi
  if [ "$ADMIN_PW_OK" -ne 1 ]; then
    fail "$id" "no admin password to log in with: ${ADMIN_PW_ERR}"
    return 0
  fi
  get_login_form "$url" "$jar" "$id"
  if [ -n "$FORM_ERR" ]; then
    fail "$id" "$FORM_ERR"
    return 0
  fi
  post_out="$(curl -sS --proto =https -b "$jar" -c "$jar" \
    -H "Origin: https://${hostport}" \
    -H "Referer: https://${hostport}/login" \
    --data-urlencode "username=admin" \
    --data-urlencode "password@${ADMIN_PW_FILE}" \
    --data-urlencode "csrfmiddlewaretoken=${FORM_TOKEN}" \
    -o "$OUT/${id}-post.html" -w '%{http_code} %{redirect_url}' "${url}/login" 2>"$OUT/${id}-post.err")" || post_rc=$?
  post_code="${post_out%% *}"
  post_location="${post_out#* }"
  if [ "$post_rc" -ne 0 ]; then
    fail "$id" "login POST: curl exited ${post_rc}: $(tr '\n' ' ' < "$OUT/${id}-post.err")"
  elif [ "$post_code" = "403" ]; then
    reason="$(csrf_reason_from_body "$OUT/${id}-post.html")"
    fail "$id" "login POST with Origin https://${hostport} returned 403, the browser-login failure D-05 exists to fix (is https://${hostport} in DD_CSRF_TRUSTED_ORIGINS?): ${reason}"
  elif [ "$post_code" != "302" ]; then
    fail "$id" "login POST returned http_code ${post_code}, expected 302 (200 = credentials rejected; 502/503 = backend died, check uwsgi for OOMKilled)"
  elif printf '%s' "$post_location" | grep -q '/login$'; then
    fail "$id" "login POST redirected back to the login page (${post_location}); the session was not established"
  else
    dash_code="$(curl -sS --proto =https -b "$jar" -o /dev/null -w '%{http_code}' "${url}/dashboard" 2>"$OUT/${id}-dash.err")" || dash_rc=$?
    if [ "$dash_rc" -ne 0 ]; then
      fail "$id" "GET ${url}/dashboard: curl exited ${dash_rc}: $(tr '\n' ' ' < "$OUT/${id}-dash.err")"
    elif [ "$dash_code" != "200" ]; then
      fail "$id" "login POST gave 302 but GET ${url}/dashboard with the session returned ${dash_code}, expected 200"
    else
      pass "$id" "admin login POST with Origin https://${hostport} (plus Referer and CSRF token) -> 302 to ${post_location}; /dashboard with the session -> 200"
    fi
  fi
}
check_login_origin "HOMELAB-LOGIN-ORIGIN-INFRA" "$PRIMARY_URL" "$PRIMARY_HOSTPORT"
check_login_origin "HOMELAB-LOGIN-ORIGIN-HOME" "$ALT_URL" "$ALT_HOSTPORT"
echo

# ── 3. HOMELAB-CSRF-FOREIGN-403 ──────────────────────────────────────────────
# The negative control. A fresh jar and a valid token on the primary host, and
# the same POST with a foreign Origin. Expected: exactly 403, the body is
# Django's CSRF failure page, and the rejection is attributed to the Origin
# check (from the body when DEBUG is on, otherwise from the uwsgi log line
# "Forbidden (Origin checking failed - https://evil.example does not match any
# trusted origins.): /login"). A 302 means the Origin check is not running; a
# 200 means the request reached the view.
echo "--- 3. negative control: foreign Origin must be refused ---"
FOREIGN_ORIGIN="https://evil.example"
check_csrf_foreign() {
  local id="HOMELAB-CSRF-FOREIGN-403" jar="$OUT/foreign-cookies.txt"
  local post_rc=0 post_code="" pw_args=() log_rc=0 attributed=""
  get_login_form "$PRIMARY_URL" "$jar" "foreign"
  if [ -n "$FORM_ERR" ]; then
    fail "$id" "$FORM_ERR"
    return 0
  fi
  # The same POST as the positive check. Without the password (kubectl absent
  # or the Secret unreadable) it is still a valid CSRF probe: the middleware
  # runs before the view reads any credential.
  if [ "$ADMIN_PW_OK" -eq 1 ]; then
    pw_args=(--data-urlencode "password@${ADMIN_PW_FILE}")
  fi
  post_code="$(curl -sS --proto =https -b "$jar" -c "$jar" \
    -H "Origin: https://evil.example" \
    -H "Referer: https://${PRIMARY_HOSTPORT}/login" \
    --data-urlencode "username=admin" \
    ${pw_args[@]+"${pw_args[@]}"} \
    --data-urlencode "csrfmiddlewaretoken=${FORM_TOKEN}" \
    -o "$OUT/foreign-post.html" -w '%{http_code}' "${PRIMARY_URL}/login" 2>"$OUT/foreign-post.err")" || post_rc=$?
  if [ "$post_rc" -ne 0 ]; then
    fail "$id" "foreign-Origin POST: curl exited ${post_rc}: $(tr '\n' ' ' < "$OUT/foreign-post.err")"
    return 0
  fi
  if [ "$post_code" = "302" ]; then
    fail "$id" "POST with Origin ${FOREIGN_ORIGIN} returned 302: a foreign origin was accepted, so the CSRF Origin check is not running"
    return 0
  fi
  if [ "$post_code" != "403" ]; then
    fail "$id" "POST with Origin ${FOREIGN_ORIGIN} returned ${post_code}, expected exactly 403 (200 = the request reached the login view past the CSRF middleware)"
    return 0
  fi
  if ! grep -qF 'CSRF verification failed' "$OUT/foreign-post.html"; then
    fail "$id" "POST with Origin ${FOREIGN_ORIGIN} returned 403, but not Django's CSRF failure page (something other than the CSRF middleware refused it): $(sed -e 's/<[^>]*>//g' "$OUT/foreign-post.html" | tr -s ' \n' ' ' | cut -c1-300)"
    return 0
  fi
  if grep -qF 'Origin checking failed' "$OUT/foreign-post.html"; then
    attributed="the 403 body (DEBUG on) names it: $(csrf_reason_from_body "$OUT/foreign-post.html")"
  elif [ "$KUBECTL_OK" -ne 1 ]; then
    SKIPPED+=("${id} attribution: 403 'CSRF verification failed' was measured, but the reason is only in the uwsgi log and kubectl is absent, so the rejection could not be attributed to the Origin check")
    return 0
  else
    kubectl --context "$KUBE_CONTEXT" --namespace "$NS" logs deploy/defectdojo-django -c uwsgi --since=5m > "$OUT/uwsgi.log" 2>&1 || log_rc=$?
    if [ "$log_rc" -ne 0 ]; then
      fail "$id" "403 'CSRF verification failed' measured, but reading the uwsgi log to attribute it failed (kubectl exit ${log_rc}): $(head -c 300 "$OUT/uwsgi.log")"
      return 0
    fi
    if ! grep -qF "Origin checking failed - ${FOREIGN_ORIGIN}" "$OUT/uwsgi.log"; then
      fail "$id" "403 'CSRF verification failed' measured, but the uwsgi log of deploy/defectdojo-django (last 5m) has no 'Origin checking failed - ${FOREIGN_ORIGIN}' line, so the refusal cannot be attributed to the Origin check (a missing-cookie or bad-token 403 looks the same from outside)"
      return 0
    fi
    attributed="the uwsgi log names it: $(grep -F "Origin checking failed - ${FOREIGN_ORIGIN}" "$OUT/uwsgi.log" | sed -n '$p' | cut -c1-300)"
  fi
  pass "$id" "POST with Origin ${FOREIGN_ORIGIN} and a valid token -> 403 'CSRF verification failed'; ${attributed}"
}
check_csrf_foreign
echo

# ── 4. HOMELAB-CELERY-PING ───────────────────────────────────────────────────
# Upstream ships no Celery probes, so a Running worker proves nothing about the
# broker. A broker round-trip does. Fallback kept exactly as the kind smoke
# labels it: if `celery inspect ping` errors for a reason that is NOT broker
# connectivity (command or app module not found), fall back to the worker's own
# broker-connected log line and say so in the pass message.
echo "--- 4. Celery broker round-trip ---"
CELERY_DEPLOYMENT="defectdojo-celery-worker"
CELERY_CONTAINER="celery"
check_celery_ping() {
  local id="HOMELAB-CELERY-PING" ping_rc=0 logs_rc=0
  if [ "$KUBECTL_OK" -ne 1 ]; then
    return 0
  fi
  kubectl --context "$KUBE_CONTEXT" --namespace "$NS" exec "deploy/${CELERY_DEPLOYMENT}" -c "$CELERY_CONTAINER" -- celery -A dojo inspect ping -t 5 > "$OUT/celery-ping.txt" 2>&1 || ping_rc=$?
  if [ "$ping_rc" -eq 0 ] && grep -q 'pong' "$OUT/celery-ping.txt"; then
    pass "$id" "celery -A dojo inspect ping in ${CELERY_DEPLOYMENT}/${CELERY_CONTAINER} exited 0 with pong (broker round-trip)"
  elif [ "$ping_rc" -eq 126 ] || [ "$ping_rc" -eq 127 ] \
    || grep -qE 'No module named|executable file not found|command not found|Unable to load celery application|Invalid value for .-A' "$OUT/celery-ping.txt"; then
    echo "    celery inspect ping unusable here (exit ${ping_rc}, not a broker error): $(tr '\n' ' ' < "$OUT/celery-ping.txt" | cut -c1-300)"
    kubectl --context "$KUBE_CONTEXT" --namespace "$NS" logs "deploy/${CELERY_DEPLOYMENT}" -c "$CELERY_CONTAINER" > "$OUT/celery-worker.log" 2>&1 || logs_rc=$?
    if [ "$logs_rc" -eq 0 ] && grep -qE 'Connected to (redis|valkey)://' "$OUT/celery-worker.log"; then
      pass "$id" "(fallback: log grep) worker log shows: $(grep -E 'Connected to (redis|valkey)://' "$OUT/celery-worker.log" | sed -n '1p' | sed -e 's#//[^@]*@#//***@#')"
    else
      fail "$id" "inspect ping unusable (exit ${ping_rc}) AND no 'Connected to redis://|valkey://' line in the worker log (logs exit ${logs_rc})"
    fi
  else
    fail "$id" "celery -A dojo inspect ping exited ${ping_rc} without pong (broker unreachable or worker not replying): $(tr '\n' ' ' < "$OUT/celery-ping.txt" | cut -c1-300)"
  fi
}
check_celery_ping
echo

# ── 5. ARGOCD-HOOK-PHASE ─────────────────────────────────────────────────────
# Adapted from nexus-homelab-validate.sh check_argocd_hook_phase. The
# initializer Job (staticName, so literally `defectdojo-initializer`) must be
# recorded in the last sync operation as a Sync hook whose phase is Succeeded.
# The entry is selected by kind AND name, never by position: the DefectDojo
# render also produces a PreSync hook entry for the `defectdojo` ServiceAccount
# (its helm.sh/hook pre-install annotation is mapped to PreSync by Argo CD,
# RESEARCH Pitfall 4). That entry is EXPECTED and is printed as INFO.
# The resource is always addressed by its full name applications.argoproj.io.
echo "--- 5. Argo CD: initializer hook phase and Application status ---"
APP_JSON_OK=0
check_argocd_hook_phase() {
  local id="ARGOCD-HOOK-PHASE" app_rc=0 hooks="" hook_count="" job_hook="" sa_hook=""
  local hook_type="" hook_phase="" sync_status="" health_status="" cmp_errors=""
  local hook_ok=1
  if [ "$KUBECTL_OK" -ne 1 ]; then
    return 0
  fi
  kubectl --context "$KUBE_CONTEXT" --namespace "$ARGOCD_NS" get applications.argoproj.io "$APP" -o json >"$OUT/app.json" 2>"$OUT/app.err" || app_rc=$?
  if [ "$app_rc" -ne 0 ]; then
    fail "$id" "kubectl exited ${app_rc} reading Application ${ARGOCD_NS}/${APP} on context ${KUBE_CONTEXT}: $(head -c 300 "$OUT/app.err")"
    return 0
  fi
  if ! hooks="$(jq -c '[.status.operationState.syncResult.resources[]? | select(.hookType != null)]' "$OUT/app.json" 2>/dev/null)"; then
    fail "$id" "Application ${APP} JSON could not be parsed for .status.operationState.syncResult.resources"
    return 0
  fi
  APP_JSON_OK=1
  hook_count="$(printf '%s' "$hooks" | jq 'length')"
  # Emptiness guard FIRST: an empty hook list is not "nothing wrong", it is the
  # initializer never having been treated as a hook at all.
  if [ "$hook_count" -eq 0 ]; then
    fail "$id" "the last sync operation of Application ${APP} recorded NO hook resources; the initializer Job was not treated as a hook at all (or no sync operation has completed yet)"
    hook_ok=0
  else
    job_hook="$(printf '%s' "$hooks" | jq -c '[.[] | select(.kind == "Job" and .name == "defectdojo-initializer")][0] // empty')"
    if [ -z "$job_hook" ]; then
      fail "$id" "the sync recorded ${hook_count} hook resource(s) but none is kind Job named defectdojo-initializer: ${hooks}"
      hook_ok=0
    else
      hook_type="$(printf '%s' "$job_hook" | jq -r '.hookType // ""')"
      hook_phase="$(printf '%s' "$job_hook" | jq -r '.hookPhase // ""')"
      if [ "$hook_type" != "Sync" ]; then
        fail "$id" "Job defectdojo-initializer hookType is '${hook_type}', expected 'Sync' (the argocd.argoproj.io/hook annotation set through initializer.jobAnnotations)"
        hook_ok=0
      fi
      if [ "$hook_phase" != "Succeeded" ]; then
        fail "$id" "Job defectdojo-initializer hookPhase is '${hook_phase}', expected 'Succeeded'; the initializer did not complete successfully in the last sync"
        hook_ok=0
      fi
    fi
    sa_hook="$(printf '%s' "$hooks" | jq -c '[.[] | select(.kind == "ServiceAccount" and .name == "defectdojo")][0] // empty')"
    if [ -n "$sa_hook" ]; then
      echo "    INFO: ServiceAccount defectdojo recorded as hook $(printf '%s' "$sa_hook" | jq -r '"\(.hookType // "")/\(.hookPhase // "")"') (expected: helm pre-install mapped to PreSync, RESEARCH Pitfall 4; not a failure)"
    fi
  fi
  sync_status="$(jq -r '.status.sync.status // ""' "$OUT/app.json")"
  health_status="$(jq -r '.status.health.status // ""' "$OUT/app.json")"
  cmp_errors="$(jq -c '[.status.conditions[]? | select(.type == "ComparisonError") | .message]' "$OUT/app.json")"
  if [ "$sync_status" != "Synced" ]; then
    fail "$id" "Application ${APP} sync status is '${sync_status}', expected 'Synced'"
    hook_ok=0
  fi
  if [ "$health_status" != "Healthy" ]; then
    fail "$id" "Application ${APP} health status is '${health_status}', expected 'Healthy'"
    hook_ok=0
  fi
  if [ "$cmp_errors" != "[]" ]; then
    fail "$id" "Application ${APP} carries ComparisonError condition(s): ${cmp_errors}"
    hook_ok=0
  fi
  if [ "$hook_ok" -eq 1 ]; then
    pass "$id" "Application ${APP}: Job defectdojo-initializer ran as a Sync hook and its hookPhase is Succeeded; Synced, Healthy, no ComparisonError"
  fi
}
check_argocd_hook_phase
echo

# ── State measurement ────────────────────────────────────────────────────────
# One measurement function feeds both --write-state and SECOND-SYNC-IDEMPOTENT,
# so the before and after values are taken the same way. An unreadable value is
# recorded as empty (JSON null) with its reason in MEAS_ERRORS, never guessed.
MEAS_INIT_UID=""
MEAS_SA_UID=""
MEAS_REV="null"
MEAS_PRODUCTS="null"
MEAS_FINDINGS="null"
MEAS_ERRORS=()
# measure_uid / measure_count set a global (UID_VAL / COUNT_VAL) instead of
# printing, because a `$(...)` caller would run them in a subshell and every
# MEAS_ERRORS entry they append would be lost.
UID_VAL=""
COUNT_VAL="null"
measure_uid() {
  local kind="$1" name="$2" rc=0
  UID_VAL="$(kubectl --context "$KUBE_CONTEXT" --namespace "$NS" get "$kind" "$name" -o jsonpath='{.metadata.uid}' 2>"$OUT/uid.err")" || rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$UID_VAL" ]; then
    MEAS_ERRORS+=("${kind}/${name} uid: kubectl exit ${rc}: $(head -c 200 "$OUT/uid.err")")
    UID_VAL=""
  fi
}
measure_count() {
  local path="$1" tag="$2" rc=0 code=""
  COUNT_VAL="null"
  code="$(curl -sS --proto =https -H @"$AUTH_HDR" -o "$OUT/${tag}.json" -w '%{http_code}' "${PRIMARY_URL}${path}" 2>"$OUT/${tag}.err")" || rc=$?
  if [ "$rc" -ne 0 ] || [ "$code" != "200" ]; then
    MEAS_ERRORS+=("GET ${path}: http_code ${code:-none} (curl exit ${rc})")
    return 0
  fi
  COUNT_VAL="$(jq -r 'if (.count | type) == "number" then .count else "null" end' "$OUT/${tag}.json" 2>/dev/null)" || COUNT_VAL="null"
  if [ "$COUNT_VAL" = "null" ]; then
    MEAS_ERRORS+=("GET ${path}: response has no numeric count")
  fi
}
measure_state() {
  MEAS_ERRORS=()
  measure_uid job defectdojo-initializer
  MEAS_INIT_UID="$UID_VAL"
  measure_uid sa defectdojo
  MEAS_SA_UID="$UID_VAL"
  if [ "$APP_JSON_OK" -eq 1 ]; then
    # Multi-source Applications carry .status.sync.revisions (an array); single
    # source ones carry .status.sync.revision. Kept as compact JSON so the
    # comparison is exact.
    MEAS_REV="$(jq -c '.status.sync.revisions // .status.sync.revision // null' "$OUT/app.json")"
  else
    MEAS_REV="null"
    MEAS_ERRORS+=("app_revision: Application ${ARGOCD_NS}/${APP} was not read (see ARGOCD-HOOK-PHASE)")
  fi
  if [ -n "$AUTH_HDR" ]; then
    measure_count '/api/v2/products/?limit=1' products
    MEAS_PRODUCTS="$COUNT_VAL"
    measure_count '/api/v2/findings/?limit=1' findings
    MEAS_FINDINGS="$COUNT_VAL"
  else
    MEAS_PRODUCTS="null"
    MEAS_FINDINGS="null"
  fi
}

STATE_MEASURED=0
if [ "$KUBECTL_OK" -eq 1 ] && { [ -n "$WRITE_STATE" ] || [ "$SYNC_PASS" = "second" ]; }; then
  echo "--- 6. measuring state (initializer and ServiceAccount UIDs, revision, counts) ---"
  measure_state
  STATE_MEASURED=1
  if [ "${#MEAS_ERRORS[@]}" -gt 0 ]; then
    for e in "${MEAS_ERRORS[@]}"; do
      echo "    measurement gap: ${e}"
    done
  fi
fi

# ── --write-state ────────────────────────────────────────────────────────────
# The file holds no credential. Its path is printed; its values are not.
if [ -n "$WRITE_STATE" ]; then
  if [ "$STATE_MEASURED" -ne 1 ]; then
    SKIPPED+=("--write-state ${WRITE_STATE}: kubectl absent, so no state was measured and no file was written")
  else
    ws_rc=0
    jq -n \
      --arg initializer_uid "$MEAS_INIT_UID" \
      --arg serviceaccount_uid "$MEAS_SA_UID" \
      --argjson product_count "$MEAS_PRODUCTS" \
      --argjson finding_count "$MEAS_FINDINGS" \
      --arg captured_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson app_revision "$MEAS_REV" \
      '{initializer_uid: ($initializer_uid | if . == "" then null else . end),
        serviceaccount_uid: ($serviceaccount_uid | if . == "" then null else . end),
        product_count: $product_count, finding_count: $finding_count,
        captured_at: $captured_at, app_revision: $app_revision}' > "$WRITE_STATE" 2>"$OUT/ws.err" || ws_rc=$?
    if [ "$ws_rc" -ne 0 ]; then
      fail "WRITE-STATE" "could not write state file ${WRITE_STATE} (jq exit ${ws_rc}): $(head -c 300 "$OUT/ws.err")"
    else
      echo "    state written to ${WRITE_STATE}"
      if [ "${#MEAS_ERRORS[@]}" -gt 0 ]; then
        echo "    WARNING: ${#MEAS_ERRORS[@]} value(s) in the state file are null (see measurement gaps above); a second-sync run compared against it cannot assert them"
      fi
    fi
  fi
fi
echo

# ── 7. SECOND-SYNC-IDEMPOTENT ────────────────────────────────────────────────
# After a SECOND Argo CD sync of the SAME revision, every falsifier from
# RESEARCH Pitfall 4 is measured against the --pre-state file:
#   1. the initializer Job was re-created (new UID): the Sync hook re-ran;
#   2. the ServiceAccount UID changed (PreSync hook delete + recreate);
#   3. the initializer log shows the idempotent path: the admin-exists marker
#      AND the no-migrations marker (see IDEMPOTENT-PATH MARKERS in the
#      header), and none of Django's "  Applying <app>.<NNNN>" lines nor
#      "Running first boot setup";
#   4. the Application is Synced at the same revision as the pre-state;
#   5. product and finding counts are unchanged (data preserved).
# Each sub-assertion prints its before and after values. On a first-pass run
# this is not evaluated, and says so as a named SKIP — never a pass.
ADMIN_EXISTS_MARKER="Admin user already exists; skipping first-boot setup"
NO_MIGRATIONS_MARKER="No migrations to apply."
FIRST_BOOT_MARKER="Running first boot setup"
check_second_sync_idempotent() {
  local id="SECOND-SYNC-IDEMPOTENT" idem_ok=1 logs_rc=0
  local pre_init="" pre_sa="" pre_rev="" pre_products="" pre_findings="" pre_at=""
  local admin_count="" nomig_count="" applied_count="" firstboot_count="" sync_status=""
  if [ "$KUBECTL_OK" -ne 1 ]; then
    SKIPPED+=("${id}: kubectl absent, nothing about the second sync could be measured")
    return 0
  fi
  pre_init="$(jq -r '.initializer_uid // ""' "$PRE_STATE")"
  pre_sa="$(jq -r '.serviceaccount_uid // ""' "$PRE_STATE")"
  pre_rev="$(jq -c '.app_revision' "$PRE_STATE")"
  pre_products="$(jq -c '.product_count' "$PRE_STATE")"
  pre_findings="$(jq -c '.finding_count' "$PRE_STATE")"
  pre_at="$(jq -r '.captured_at // ""' "$PRE_STATE")"
  echo "    pre-state captured_at ${pre_at}"

  # 1. initializer UID
  echo "    initializer_uid: before '${pre_init}' after '${MEAS_INIT_UID}'"
  if [ -z "$pre_init" ] || [ -z "$MEAS_INIT_UID" ]; then
    fail "$id" "initializer_uid not measured on both sides (before '${pre_init}', after '${MEAS_INIT_UID}'); whether the Sync hook re-ran is unknown"
    idem_ok=0
  elif [ "$pre_init" = "$MEAS_INIT_UID" ]; then
    fail "$id" "initializer Job UID is unchanged (before ${pre_init}, after ${MEAS_INIT_UID}); the second sync did not re-create defectdojo-initializer"
    idem_ok=0
  fi

  # 2. ServiceAccount UID
  echo "    serviceaccount_uid: before '${pre_sa}' after '${MEAS_SA_UID}'"
  if [ -z "$pre_sa" ] || [ -z "$MEAS_SA_UID" ]; then
    fail "$id" "serviceaccount_uid not measured on both sides (before '${pre_sa}', after '${MEAS_SA_UID}')"
    idem_ok=0
  elif [ "$pre_sa" = "$MEAS_SA_UID" ]; then
    fail "$id" "ServiceAccount defectdojo UID is unchanged (before ${pre_sa}, after ${MEAS_SA_UID}); the expected PreSync delete-and-recreate did not happen, so the Argo CD hook mapping differs from RESEARCH Pitfall 4"
    idem_ok=0
  fi

  # 3. initializer log markers. grep -c exits 1 on zero matches; the fallback
  # is a count default, not a silenced assertion.
  kubectl --context "$KUBE_CONTEXT" --namespace "$NS" logs job/defectdojo-initializer --all-containers > "$OUT/initializer.log" 2>"$OUT/initializer.err" || logs_rc=$?
  if [ "$logs_rc" -ne 0 ]; then
    fail "$id" "kubectl exited ${logs_rc} reading the defectdojo-initializer log: $(head -c 300 "$OUT/initializer.err")"
    idem_ok=0
  else
    admin_count="$(grep -cF -- "$ADMIN_EXISTS_MARKER" "$OUT/initializer.log")" || admin_count=0
    nomig_count="$(grep -cF -- "$NO_MIGRATIONS_MARKER" "$OUT/initializer.log")" || nomig_count=0
    applied_count="$(grep -cE -- '^[[:space:]]*Applying [A-Za-z0-9_]+\.[0-9]{4}' "$OUT/initializer.log")" || applied_count=0
    firstboot_count="$(grep -cF -- "$FIRST_BOOT_MARKER" "$OUT/initializer.log")" || firstboot_count=0
    echo "    initializer log: '${ADMIN_EXISTS_MARKER}' x${admin_count}, '${NO_MIGRATIONS_MARKER}' x${nomig_count}, applied-migration lines x${applied_count}, '${FIRST_BOOT_MARKER}' x${firstboot_count}"
    if [ "$admin_count" -lt 1 ]; then
      fail "$id" "initializer log has no '${ADMIN_EXISTS_MARKER}' line (count ${admin_count}); the second run did not take the admin-exists path"
      idem_ok=0
    fi
    if [ "$nomig_count" -lt 1 ]; then
      fail "$id" "initializer log has no '${NO_MIGRATIONS_MARKER}' line (count ${nomig_count})"
      idem_ok=0
    fi
    if [ "$applied_count" -ne 0 ]; then
      fail "$id" "initializer log shows ${applied_count} applied migration line(s) on a same-revision second sync, expected 0"
      idem_ok=0
    fi
    if [ "$firstboot_count" -ne 0 ]; then
      fail "$id" "initializer log contains '${FIRST_BOOT_MARKER}' ${firstboot_count} time(s); first-boot setup re-ran against existing data"
      idem_ok=0
    fi
  fi

  # 4. Synced at the same revision
  sync_status="$(jq -r '.status.sync.status // ""' "$OUT/app.json" 2>/dev/null)" || sync_status=""
  echo "    app_revision: before ${pre_rev} after ${MEAS_REV}; sync status '${sync_status}'"
  if [ "$sync_status" != "Synced" ]; then
    fail "$id" "Application ${APP} sync status is '${sync_status}' after the second sync, expected 'Synced'"
    idem_ok=0
  fi
  if [ "$pre_rev" = "null" ] || [ "$MEAS_REV" = "null" ]; then
    fail "$id" "app_revision not measured on both sides (before ${pre_rev}, after ${MEAS_REV})"
    idem_ok=0
  elif [ "$pre_rev" != "$MEAS_REV" ]; then
    fail "$id" "Application revision changed (before ${pre_rev}, after ${MEAS_REV}); this was not a same-revision second sync, so it proves nothing about idempotency"
    idem_ok=0
  fi

  # 5. data preserved. A null on either side is a named SKIP for that
  # sub-assertion: the pre-state was captured without --token-file.
  local label before after
  for label in product_count finding_count; do
    if [ "$label" = "product_count" ]; then
      before="$pre_products"
      after="$MEAS_PRODUCTS"
    else
      before="$pre_findings"
      after="$MEAS_FINDINGS"
    fi
    echo "    ${label}: before ${before} after ${after}"
    if [ "$before" = "null" ]; then
      SKIPPED+=("${id} ${label}: the pre-state holds null (captured without --token-file), so data preservation was not compared")
      idem_ok=0
    elif [ "$after" = "null" ]; then
      fail "$id" "${label} could not be re-measured after the second sync (before ${before})"
      idem_ok=0
    elif [ "$before" != "$after" ]; then
      fail "$id" "${label} changed across the second sync (before ${before}, after ${after})"
      idem_ok=0
    fi
  done

  if [ "$idem_ok" -eq 1 ]; then
    pass "$id" "same-revision second sync: initializer UID ${pre_init} -> ${MEAS_INIT_UID}, ServiceAccount UID ${pre_sa} -> ${MEAS_SA_UID}, log shows '${ADMIN_EXISTS_MARKER}' and '${NO_MIGRATIONS_MARKER}' with 0 applied migrations and no first-boot setup, Synced at ${MEAS_REV}, products ${pre_products} = ${MEAS_PRODUCTS}, findings ${pre_findings} = ${MEAS_FINDINGS}"
  fi
}

echo "--- 7. second-sync idempotency ---"
if [ "$SYNC_PASS" = "second" ]; then
  check_second_sync_idempotent
else
  SKIPPED+=("SECOND-SYNC-IDEMPOTENT: not evaluated on a --sync-pass first run; re-run this gate with --sync-pass second --pre-state <file> --token-file <file> after the second Argo CD sync of the same revision")
  echo "    SKIPPED - --sync-pass first"
fi
echo

print_summary
