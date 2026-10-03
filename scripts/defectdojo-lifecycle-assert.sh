#!/usr/bin/env bash
set -euo pipefail

# defectdojo-lifecycle-assert.sh — the Phase 29 D-11 API assertion helper for
# the REAL pull-request lifecycle against a live DefectDojo (DDOJO-05).
#
# WHY THIS EXISTS. Phase 28 proved deduplication, dispositions and the PR
# engagement delete with scripts/defectdojo-import-proof.sh on a throwaway kind
# cluster. Phase 29 D-11 re-proves that behaviour through a real same-repo PR on
# security-platform, with the imports done by the real security.yml callers.
# The assertions are about API STATE, never HTTP status: an import that returns
# 201 while dedup is off, or a disposition PATCH that returns 200 while a
# reimport later reactivates the finding, would pass any status check. Every
# verdict below is derived from a measured field read back from the API, every
# subcommand writes the measured sets to an evidence JSON file, and every
# assertion prints PASS or FAIL under its own ID.
#
# The API sequence and the disposition field tuples are those measured in
# Phase 28 by scripts/defectdojo-import-proof.sh (P-DISPOSITION); the Under
# Review query is copied verbatim from kubernetes/defectdojo/TRIAGE.md.
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/defectdojo-lifecycle-assert.sh <subcommand> [flags]
#
# INTERFACE. Every subcommand needs the environment variables
#   DEFECTDOJO_URL               https:// base URL of the DefectDojo instance
#   DEFECTDOJO_ADMIN_TOKEN_FILE  file holding the operator's BARE superuser API
#                                token (no "Token " prefix), mode 600: one line
#                                of 40 lowercase hex characters
# DEFECTDOJO_RESOLVE is a test hook set only by the proof harness; leave it
# unset (see TLS below).
# and the flags --product <name> and --out <evidence-dir>. No flag has a
# default. The D-11 sequence and the subcommand for each step:
#
#   (before step 2)  snapshot --engagement ci/main --label <label>
#                      -> <out>/<label>-snapshot.json
#   step 2           assert-pr-duplicates --branch <b> --main-snapshot <file>
#                      --fixture-path <path>          -> <out>/step2-assert.json
#                      (Phase 29.4: the trivy-image Test has its own
#                      title-keyed dedup assertion; see TRIVY-IMAGE DEDUP)
#   step 3           disposition --main-snapshot <file> --fp <id> --oos <id>
#                      --ra <id>                      -> <out>/dispositions.json
#   step 4           assert-dispositions --dispositions <file>
#                                                     -> <out>/step4-assert.json
#   (before step 5)  snapshot --engagement ci/main --label <label>, taken AFTER
#                      the step-4 reimport and immediately before the PR is
#                      closed, because that reimport legitimately changes the
#                      ci/main finding set
#   step 5           assert-closed --branch <b> --main-snapshot <that file>
#                      --dispositions <file>          -> <out>/step5-assert.json
#
# TRIVY-IMAGE DEDUP (Phase 29.4 D-08/D-21, replaces the 2026-09-29 exclusion).
# security.yml scans the image under the fixed tag scan-target:ci, so the same
# image content must give the same Trivy findings on a PR and on ci/main, and
# every trivy-image finding on the PR must be a duplicate of its ci/main
# counterpart. The Test on each side is read live (scan_type "Trivy Scan",
# title "trivy-image"; never passed in by id) and exactly one must match on
# each side, or D11-STEP2-TRIVY-IMAGE-KEY fails. The ci/main side comes from
# the --main-snapshot `tests` array, or from a live Tests read of the snapshot
# engagement when an older snapshot lacks it.
#   key          the finding title within the trivy-image Test on each side,
#                never across the whole engagement (trivy-fs shares the parser
#                and the title shape)
#   counterparts ci/main trivy-image findings that are not mitigated and not
#                duplicates (an upgrade reimport leaves mitigated old sets)
#   verdict      every matched PR finding must be duplicate=true with
#                duplicate_finding among that title's counterpart ids, and a
#                file_path that starts with scan-target: must be scan-target:ci
#   drift        a PR finding with no title counterpart (Trivy DB change) is
#                recorded, not failed
#   vacuous      zero matched findings is a FAIL
#   hash_code    a matched pair whose hash_code values differ is a FAIL; the
#                diagnostic prints both hashes
# The hashed carrier of the image reference is the description line
# `**Target:** <image>`, not file_path (file_path is not a Trivy Scan hash
# field). The verdict is one pure jq program, TRIVY_IMAGE_VERDICT, between
# BEGIN/END marker comments so the offline replay runs the same text.
# Every other non-fixture finding must still be a duplicate of a ci/main
# finding in the snapshot (D11-STEP2-DUPLICATES-POINT-TO-MAIN).
#
# WHICH TOKEN. The dispositions are written, and everything is read, with the
# OPERATOR-HELD admin (superuser) token only (Phase 28 D-22, Phase 29 D-16 as
# amended 2026-09-27, RESEARCH OQ4). The CI ci-importer token
# (DEFECTDOJO_API_TOKEN) must NEVER be used with this script: a disposition is
# an operator decision, not an importer action, and the ci-importer identity is
# kept least-privilege (ADR-024).
#
# TOKEN HANDLING (T-29-03). DEFECTDOJO_URL is checked for https:// BEFORE the
# token file is read. The token file must be a regular readable file, be
# non-empty, carry no group or other permission bits (the
# defectdojo-configure.sh contract) and hold exactly one bare DefectDojo API
# token: 40 lowercase hex characters on one line (at most one trailing LF or
# CRLF allowed; blank lines, a bare CR or NUL bytes are refused), no "Token "
# prefix. Anything else (a second line, a prefix, spaces) is refused with exit
# 2 before any connection. The
# token is copied once into a 0600 header file created exclusively (noclobber)
# inside a private mktemp -d directory, and is sent only as `-H @file`. Request
# bodies are built with jq into 0600 files, sent with --data-binary @file and
# removed. The token never reaches an argv, is never echoed, xtrace is never
# enabled in this file, and the EXIT trap removes the private directory.
#
# TLS (T-29-08, ADR-025). Every curl call is pinned to https with --proto and
# --proto-redir. TLS is always verified against the system trust store; there
# is no option to switch verification off.
#
# CURL CONFIG (ADR-029, Phase 28 CR-01). Every curl call passes -q as its first
# argument, so no curlrc is read (~/.curlrc, $CURL_HOME/.curlrc,
# $XDG_CONFIG_HOME/curlrc): an ambient `insecure`, `cacert`, `verbose` or
# `location-trusted` line cannot weaken TLS or leak the token. Every request
# must end with curl exit 0 AND ssl_verify_result 0 before its HTTP code is
# even considered; anything else is an API error and the run fails. curl
# stderr is discarded and never printed: failure lines carry only the path,
# the curl exit, the HTTP code, the TLS verification result, curl's own
# %{errormsg} and, for an HTTP-code mismatch, the response body. There is
# exactly one curl call site (api_transport). DEFECTDOJO_RESOLVE is a test hook
# set only by the proof harness: when set it must be host:port:IPv4 with the
# host and port of DEFECTDOJO_URL (else exit 2) and is passed as one --resolve,
# which keeps hostname verification.
#
# PAGINATION. List reads page with an explicit limit=250&offset=N until they
# hold `count` rows, check that `count` did not change while paging, and NEVER
# follow the returned `next` URL. Behind the L4 TLS proxy Django sees a
# non-secure request, so DRF builds `next` as http://, which the https pin
# would refuse (the same choice as the import-proof dedup reader).
#
# FILTER GUARDS. A DefectDojo filter the API does not recognise is ignored
# silently and returns every row. So products are read with name_exact and
# selected on the exact name client-side, engagements are selected on exact
# name and product id client-side, every finding read with test__engagement is
# checked to belong to a Test of that engagement, and every Under Review row is
# re-checked field by field.
#
# RE-PARENTING IS NOT ASSERTED. D-11 step 5 was amended on 2026-09-26 by
# operator ruling: in this sequence no ci/main finding is a duplicate of a PR
# finding (the pre-existing findings on the PR are duplicates of ci/main, not
# the other way round), so closing the PR cannot exercise the re-parent path.
# Re-parenting was proven on kind in Phase 28 (P-REPARENT); ADR-027 records it
# as not exercised live. assert-closed prints an explicit INFO line saying so.
#
# TRIVY CAVEAT (TRIAGE.md). Trivy findings arrive verified=true, so the
# verbatim Under Review filter (verified=false) never matches them. The step-2
# fixture must therefore be a finding from a non-Trivy parser, or
# D11-STEP2-UNTRIAGED-EQ-FIXTURE fails.
#
# DANGLING DUPLICATES. D11-STEP5-NO-DANGLING-DUPLICATE counts a finding with
# duplicate=true as dangling when its duplicate_finding id is not in the
# product's current finding id set, AND when duplicate_finding is null: a
# duplicate with no original is the shape an on-delete SET_NULL would leave.
#
# Exit codes (the accounting core of scripts/defectdojo-homelab-validate.sh):
#   0  every assertion that ran passed (ALL PASS), or nothing ran (the summary
#      then says NOTHING RAN, never ALL PASS); `snapshot` exits 0 when it wrote
#      its file
#   1  at least one assertion failed, an API read or write failed, or a
#      prerequisite (product, engagement, pre-validation) did not hold
#   2  usage or preflight error: a missing or unknown flag or subcommand, a
#      non-https URL, a malformed DEFECTDOJO_RESOLVE, a missing, empty,
#      group/other-accessible or malformed (not one 40-hex line) token file, a
#      missing binary (curl, jq, python3), or an unreadable input JSON file
#
# No hostname, address or token appears anywhere in this file: every one of
# them is a runtime input.

usage() {
  cat <<'USAGE_EOF'
Usage: DEFECTDOJO_URL=https://<host> DEFECTDOJO_ADMIN_TOKEN_FILE=<file> \
         bash scripts/defectdojo-lifecycle-assert.sh <subcommand> --product <name> --out <evidence-dir> [flags]

Subcommands (every flag shown is REQUIRED; there are no defaults):
  snapshot             --engagement <name> --label <label>
                       Write <out>/<label>-snapshot.json: product and engagement
                       ids, test ids, finding count and every finding.
  assert-pr-duplicates --branch <b> --main-snapshot <file> --fixture-path <path>
                       D-11 step 2 on engagement ci/<b>. The trivy-image Test
                       must dedupe by title against the ci/main trivy-image
                       Test (Phase 29.4 D-08/D-21).
                       Writes step2-assert.json.
  disposition          --main-snapshot <file> --fp <id> --oos <id> --ra <id>
                       D-11 step 3 on ci/main originals, admin token only.
                       Writes dispositions.json (refuses if it already exists).
  assert-dispositions  --dispositions <file>
                       D-11 step 4. Writes step4-assert.json.
  assert-closed        --branch <b> --main-snapshot <file> --dispositions <file>
                       D-11 step 5 (amended). The snapshot must be taken after
                       the step-4 reimport, immediately before the PR is closed.
                       Writes step5-assert.json.

--branch is the bare branch name; the engagement is ci/<b>.
DEFECTDOJO_ADMIN_TOKEN_FILE holds the bare operator superuser token (one line,
40 lowercase hex characters, no 'Token ' prefix), mode 600.
Never the ci-importer token.

Exit codes: 0 ALL PASS (or NOTHING RAN), 1 FAIL, 2 usage or preflight error.
USAGE_EOF
}

usage_error() {
  echo "ERROR: $1" >&2
  usage >&2
  exit 2
}

# ── Arguments ────────────────────────────────────────────────────────────────
SUBCMD="${1:-}"
case "$SUBCMD" in
  "") usage_error "a subcommand is required" ;;
  -h | --help)
    usage
    exit 0
    ;;
  snapshot | assert-pr-duplicates | disposition | assert-dispositions | assert-closed) ;;
  *) usage_error "unknown subcommand '${SUBCMD}'" ;;
esac
shift

PRODUCT=""
OUT_DIR=""
ENGAGEMENT=""
LABEL=""
BRANCH=""
MAIN_SNAPSHOT=""
FIXTURE_PATH=""
FP_ID=""
OOS_ID=""
RA_ID=""
DISPOSITIONS=""
GIVEN=" "

while [[ $# -gt 0 ]]; do
  case "$1" in
    --product | --out | --engagement | --label | --branch | --main-snapshot | --fixture-path | --fp | --oos | --ra | --dispositions)
      if [[ $# -lt 2 || -z "$2" ]]; then usage_error "$1 requires a non-empty value"; fi
      if [[ "$GIVEN" == *" $1 "* ]]; then usage_error "$1 given more than once"; fi
      GIVEN="${GIVEN}$1 "
      case "$1" in
        --product) PRODUCT="$2" ;;
        --out) OUT_DIR="$2" ;;
        --engagement) ENGAGEMENT="$2" ;;
        --label) LABEL="$2" ;;
        --branch) BRANCH="$2" ;;
        --main-snapshot) MAIN_SNAPSHOT="$2" ;;
        --fixture-path) FIXTURE_PATH="$2" ;;
        --fp) FP_ID="$2" ;;
        --oos) OOS_ID="$2" ;;
        --ra) RA_ID="$2" ;;
        --dispositions) DISPOSITIONS="$2" ;;
      esac
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) usage_error "unknown argument '$1'" ;;
  esac
done

case "$SUBCMD" in
  snapshot) REQUIRED="--product --out --engagement --label" ;;
  assert-pr-duplicates) REQUIRED="--product --out --branch --main-snapshot --fixture-path" ;;
  disposition) REQUIRED="--product --out --main-snapshot --fp --oos --ra" ;;
  assert-dispositions) REQUIRED="--product --out --dispositions" ;;
  assert-closed) REQUIRED="--product --out --branch --main-snapshot --dispositions" ;;
esac
for flag in $REQUIRED; do
  if [[ "$GIVEN" != *" ${flag} "* ]]; then usage_error "${SUBCMD} requires ${flag}"; fi
done
for flag in $GIVEN; do
  if [[ " ${REQUIRED} " != *" ${flag} "* ]]; then usage_error "${flag} is not a ${SUBCMD} flag"; fi
done

if [[ -n "$LABEL" && ! "$LABEL" =~ ^[A-Za-z0-9._-]+$ ]]; then
  usage_error "--label must match [A-Za-z0-9._-]+ (it becomes a file name)"
fi
if [[ -n "$BRANCH" && "$BRANCH" == ci/* ]]; then
  usage_error "--branch takes the bare branch name; the engagement name ci/<branch> is derived"
fi
for pair in "--fp:${FP_ID}" "--oos:${OOS_ID}" "--ra:${RA_ID}"; do
  if [[ -n "${pair#*:}" && ! "${pair#*:}" =~ ^[1-9][0-9]*$ ]]; then
    usage_error "${pair%%:*} must be a positive integer finding id"
  fi
done

# ── Preflight ────────────────────────────────────────────────────────────────
# Order matters: the https check runs BEFORE the token file is touched.
if [[ -z "${DEFECTDOJO_URL:-}" ]]; then usage_error "DEFECTDOJO_URL is not set"; fi
if [[ "$DEFECTDOJO_URL" != https://?* ]]; then
  echo "ERROR: DEFECTDOJO_URL must start with https:// (ADR-025); refusing before the token file is read" >&2
  exit 2
fi
if [[ "$DEFECTDOJO_URL" =~ [[:space:]?#] ]]; then
  echo "ERROR: DEFECTDOJO_URL must be a bare base URL (no whitespace, query or fragment)" >&2
  exit 2
fi
BASE="${DEFECTDOJO_URL%/}"

# DEFECTDOJO_RESOLVE is a test hook set only by the proof harness (ADR-029,
# Phase 28 CR-01). When set it must be host:port:IPv4 naming exactly the host
# and port of DEFECTDOJO_URL, and it is passed as one --resolve. Checked before
# the token file is read; the value is never echoed.
RESOLVE="${DEFECTDOJO_RESOLVE:-}"
if [[ -n "$RESOLVE" ]]; then
  resolve_re='^([A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?):([0-9]{1,5}):(([0-9]{1,3}\.){3}[0-9]{1,3})$'
  url_re='^https://([^/:?#]+)(:([0-9]+))?(/.*)?$'
  resolve_ok=0
  if [[ "$RESOLVE" =~ $resolve_re ]]; then
    r_host="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
    r_port="${BASH_REMATCH[3]}"
    if [[ "$BASE" =~ $url_re ]]; then
      u_host="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
      u_port="${BASH_REMATCH[3]:-443}"
      if [[ ${#u_port} -le 5 && "$r_host" == "$u_host" ]] && (($((10#$r_port)) == $((10#$u_port)))); then
        resolve_ok=1
      fi
    fi
  fi
  if [[ "$resolve_ok" -ne 1 ]]; then
    echo "ERROR: DEFECTDOJO_RESOLVE must be host:port:IPv4 with the host and port of DEFECTDOJO_URL (a test hook; leave it unset)" >&2
    exit 2
  fi
fi

if [[ -z "${DEFECTDOJO_ADMIN_TOKEN_FILE:-}" ]]; then usage_error "DEFECTDOJO_ADMIN_TOKEN_FILE is not set"; fi
CRED_FILE="$DEFECTDOJO_ADMIN_TOKEN_FILE"
if [[ ! -f "$CRED_FILE" || ! -r "$CRED_FILE" ]]; then
  echo "ERROR: DEFECTDOJO_ADMIN_TOKEN_FILE is not a readable file" >&2
  exit 2
fi
if [[ ! -s "$CRED_FILE" ]]; then
  echo "ERROR: DEFECTDOJO_ADMIN_TOKEN_FILE is empty" >&2
  exit 2
fi
if [[ "$(uname -s)" == "Darwin" ]]; then
  CRED_MODE="$(stat -f %Lp "$CRED_FILE")"
else
  CRED_MODE="$(stat -c %a "$CRED_FILE")"
fi
if [[ ! "$CRED_MODE" =~ ^[0-7]{3,4}$ ]] || (((8#$CRED_MODE & 8#077) != 0)); then
  echo "ERROR: DEFECTDOJO_ADMIN_TOKEN_FILE has mode ${CRED_MODE}; it must not be accessible by group or other (chmod 600)" >&2
  exit 2
fi

umask 077
# Assigned BEFORE the trap so `set -u` cannot trip inside the cleanup path. The
# `|| true` is cleanup hygiene on a best-effort teardown, not a silenced
# assertion.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" || true' EXIT
HDR="${WORK}/auth-header"
# read_token_file PATH: on success set cred to the one bare 40-hex token in
# PATH and return 0; otherwise return non-zero with no output. This matches
# defectdojo-configure.sh and ADR-029 decision 6: at most one trailing CRLF or
# LF is stripped, and what remains must be exactly 40 lowercase hex characters,
# so trailing blank lines, a bare trailing CR and a NUL byte are all refused.
# `$(< file)` is not used because it strips every trailing newline and drops
# NUL bytes. `read -d ''` always returns 1 at end of file, so its status says
# nothing; the byte-count comparison with `wc -c` is what catches a NUL
# (read stops or drops there) or any other short read, and that check is what
# makes the `|| true` safe. `local LC_ALL=C` evaluates the length and the
# [0-9a-f] range in the C locale and is restored when the function returns.
read_token_file() {
  local LC_ALL=C raw="" size
  IFS= read -r -d '' raw < "$1" || true
  size="$(wc -c < "$1")"
  size="${size//[[:space:]]/}"
  [[ "$size" == "${#raw}" ]] || return 1
  if [[ "$raw" == *$'\r\n' ]]; then
    raw="${raw%$'\r\n'}"
  elif [[ "$raw" == *$'\n' ]]; then
    raw="${raw%$'\n'}"
  fi
  [[ "$raw" =~ ^[0-9a-f]{40}$ ]] || return 1
  cred="$raw"
}
# The token file is read byte-exact by read_token_file (one trailing CRLF or LF
# stripped, nothing else), so a second line, blank lines, a bare CR, a NUL byte
# or a prefix is refused here, before any connection.
if ! read_token_file "$CRED_FILE"; then
  unset cred
  echo "ERROR: DEFECTDOJO_ADMIN_TOKEN_FILE must hold one bare DefectDojo API token: 40 lowercase hex characters on one line, no 'Token ' prefix" >&2
  exit 2
fi
# noclobber makes the redirection an exclusive create (O_EXCL).
set -C
printf 'Authorization: Token %s\n' "$cred" > "$HDR"
set +C
unset cred

for bin in curl jq python3; do
  if ! command -v "$bin" > /dev/null 2>&1; then
    echo "ERROR: required binary '${bin}' not found on PATH" >&2
    exit 2
  fi
done

for input in "$MAIN_SNAPSHOT" "$DISPOSITIONS"; do
  if [[ -n "$input" ]] && ! jq -e 'type == "object"' "$input" > /dev/null 2>&1; then
    echo "ERROR: input file '${input}' is not readable JSON object" >&2
    exit 2
  fi
done
if [[ -n "$MAIN_SNAPSHOT" ]] && ! jq -e '(.product_id | type == "number") and (.engagement_id | type == "number")
    and (.test_ids | type == "array") and (.findings | type == "array") and (.count | type == "number")' \
  "$MAIN_SNAPSHOT" > /dev/null; then
  echo "ERROR: --main-snapshot '${MAIN_SNAPSHOT}' is not a snapshot written by this script" >&2
  exit 2
fi
if [[ -n "$DISPOSITIONS" ]] && ! jq -e '([.fp, .oos, .ra, .risk_acceptance_id, .product_id] | all(type == "number"))
    and (.ra_expiry | type == "string")' "$DISPOSITIONS" > /dev/null; then
  echo "ERROR: --dispositions '${DISPOSITIONS}' is not a dispositions file written by this script" >&2
  exit 2
fi
if ! mkdir -p "$OUT_DIR" 2> /dev/null || [[ ! -d "$OUT_DIR" || ! -w "$OUT_DIR" ]]; then
  echo "ERROR: --out '${OUT_DIR}' cannot be created or is not writable" >&2
  exit 2
fi
if [[ "$SUBCMD" == "disposition" && -e "${OUT_DIR}/dispositions.json" ]]; then
  echo "ERROR: ${OUT_DIR}/dispositions.json already exists; refusing to disposition twice into one evidence dir" >&2
  exit 2
fi

# ── Accounting core (lifted from scripts/defectdojo-homelab-validate.sh) ─────
FAILURES=()
# SKIPPED: assertions that did not run because a prerequisite failed. Reported
# separately from FAILURES and from passes — a skip must never read as a pass.
SKIPPED=()
# CHECKS_PASSED: assertions that actually executed and passed. Counted from the
# run itself, so the summary cannot claim a pass on a run where nothing ran.
CHECKS_PASSED=0

# pass / fail: the two ends of every assertion below. An assertion must never
# swallow its own result with `|| true`.
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
    # Zero failures on a run where zero checks executed is NOT a pass.
    echo "NOTHING RAN - 0 live check(s) executed; ${#SKIPPED[@]} sub-check(s) skipped (not passed). Nothing was proven."
    exit 0
  else
    echo "ALL PASS - ${CHECKS_PASSED} live check(s) executed and passed; ${#SKIPPED[@]} sub-check(s) skipped (not passed)."
    exit 0
  fi
}

# abort ID DETAIL: a failed prerequisite every later assertion depends on.
abort() {
  fail "$1" "$2"
  SKIPPED+=("the remaining ${SUBCMD} assertions: not evaluated, they depend on $1")
  print_summary
}

# ── API ──────────────────────────────────────────────────────────────────────
API_ERROR=""
HTTP_CODE=""

# snippet FILE...: up to 300 bytes of the FILEs, newlines flattened.
snippet() {
  cat "$@" 2> /dev/null | head -c 300 | tr '\n' ' ' || true
}

# uri VALUE: VALUE percent-encoded for a query string.
uri() {
  jq -rn --arg v "$1" '$v | @uri'
}

# api_transport METHOD PATH OUTFILE [BODYFILE]: the ONLY curl call in this
# file. -q is curl's argv[1], so no curlrc is read (Phase 28 CR-01). The admin
# header goes by path (-H @file); a body goes by path and is removed after use.
# Sets HTTP_CODE. Returns 1 with API_ERROR set (path, curl exit, http code,
# TLS verification result and curl's own %{errormsg}; never the token) unless
# curl exited 0 AND ssl_verify_result is 0. curl stderr is discarded, never
# read or printed: under a verbose config it would carry request headers.
api_transport() {
  local method="$1" path="$2" out="$3" body="${4:-}" wout="" rc=0 verify="" emsg=""
  HTTP_CODE=""
  # The `=` in `--proto =https` is curl's exact-set operator, a literal here.
  # shellcheck disable=SC2191
  local args=(-q -sS --proto =https --proto-redir =https -H @"$HDR" -X "$method" -o "$out" -w '%{http_code}|%{ssl_verify_result}|%{errormsg}')
  if [[ -n "$RESOLVE" ]]; then
    args+=(--resolve "$RESOLVE")
  fi
  if [[ -n "$body" ]]; then
    args+=(-H 'Content-Type: application/json' --data-binary "@${body}")
  fi
  wout="$(curl "${args[@]}" "${BASE}${path}" 2> /dev/null)" || rc=$?
  if [[ -n "$body" ]]; then rm -f "$body"; fi
  IFS='|' read -r HTTP_CODE verify emsg <<< "$wout"
  if [[ "$rc" -ne 0 || "$verify" != "0" ]]; then
    API_ERROR="${method} ${path}: curl exit ${rc}, http ${HTTP_CODE:-none}, TLS verification result ${verify:-none} (must be 0): ${emsg}"
    return 1
  fi
  return 0
}

# api_request METHOD PATH OUTFILE EXPECT [BODYFILE]: one verified-TLS request
# whose HTTP code must be EXPECT. Returns 1 with API_ERROR set on a transport
# failure (see api_transport) or on another HTTP code, then quoting only the
# response body (D-18).
api_request() {
  local method="$1" path="$2" out="$3" expect="$4" body="${5:-}"
  api_transport "$method" "$path" "$out" "$body" || return 1
  if [[ "$HTTP_CODE" != "$expect" ]]; then
    API_ERROR="${method} ${path}: http ${HTTP_CODE:-none} (expected ${expect}): $(snippet "$out")"
    return 1
  fi
  return 0
}

# api_get PATH OUTFILE: GET one object, HTTP 200 required.
api_get() {
  api_request GET "$1" "$2" 200
}

# api_get_all PATH OUTFILE: GET every row of a paged list into OUTFILE as
# {"count": N, "results": [...]}. Pages with limit=250&offset=N and never
# follows `next` (see PAGINATION in the header).
api_get_all() {
  local path="$1" out="$2" offset=0 count="" got=0 sep='?' page meta c n
  if [[ "$path" == *\?* ]]; then sep='&'; fi
  page="${WORK}/page.json"
  : > "${out}.rows"
  while :; do
    api_get "${path}${sep}limit=250&offset=${offset}" "$page" || return 1
    meta="$(jq -r 'if type == "object" and (.count | type == "number") and (.results | type == "array")
      then "\(.count) \(.results | length)" else "bad" end' "$page" 2> /dev/null || echo bad)"
    if [[ "$meta" == "bad" ]]; then
      API_ERROR="GET ${path} offset ${offset}: expected a paged object with count and results: $(snippet "$page")"
      return 1
    fi
    c="${meta% *}"
    n="${meta#* }"
    if [[ -z "$count" ]]; then
      count="$c"
    elif [[ "$c" != "$count" ]]; then
      API_ERROR="GET ${path}: count changed from ${count} to ${c} while paging"
      return 1
    fi
    jq -c '.results[]' "$page" >> "${out}.rows"
    got=$((got + n))
    if [[ "$got" -ge "$count" ]]; then break; fi
    if [[ "$n" -eq 0 ]]; then
      API_ERROR="GET ${path}: empty page at offset ${offset} with ${got} of ${count} rows read"
      return 1
    fi
    offset=$((offset + n))
  done
  if [[ "$got" -ne "$count" ]]; then
    API_ERROR="GET ${path}: read ${got} rows, count says ${count}"
    return 1
  fi
  jq -s --argjson c "$count" '{count: $c, results: .}' "${out}.rows" > "$out"
  rm -f "${out}.rows" "$page"
}

# The finding fields every snapshot and read-back carries (the import-proof
# FIELDS that D-11 needs, plus file_path for the step-2 fixture match, plus
# hash_code, additive in Phase 29.4 D-21, for the trivy-image dedup diagnostic).
# shellcheck disable=SC2016
SLIM='def slim: . as $f
  | ["id", "test", "title", "file_path", "active", "verified", "duplicate", "duplicate_finding",
     "false_p", "out_of_scope", "risk_accepted", "is_mitigated", "hash_code"] as $keys
  | [$keys[] | . as $k | select(($f | has($k)) | not)] as $missing
  | if ($missing | length) > 0
    then error("finding \($f.id) lacks \($missing | join(",")); keys present: \($f | keys | join(","))")
    else $f | {id, test, title, file_path, active, verified, duplicate, duplicate_finding,
               false_p, out_of_scope, risk_accepted, is_mitigated, hash_code}
    end;'

# BEGIN TRIVY_IMAGE_VERDICT
# The D-08/D-21 trivy-image verdict (see TRIVY-IMAGE DEDUP above): a pure jq
# program, run with `jq -n --slurpfile pr <obj with .findings> --argjson prtid
# <PR image Test id> --slurpfile main <obj with .findings> --argjson mtid
# <ci/main image Test id>`. The offline replay extracts the lines between the
# assignment line and the closing quote line below, so keep the program free
# of single quotes and keep both of those lines as they are.
# shellcheck disable=SC2016
TRIVY_IMAGE_VERDICT='
($pr[0].findings | map(select(.test == $prtid))) as $pi
| ($main[0].findings | map(select(.test == $mtid and .is_mitigated != true and .duplicate != true))) as $mc
| (reduce $mc[] as $c ({}; .[$c.title // ""] += [$c])) as $by
| ($pi | map(select($by[.title // ""] != null))) as $matched
| ($pi | map(select($by[.title // ""] == null))) as $drift
| [$matched[] | . as $f
    | ($by[$f.title // ""]) as $cs
    | ($cs | map(.id)) as $cids
    | ($cs | map(.hash_code)) as $mh
    | ($f.file_path // "") as $fp
    | (($f.hash_code != null) and ($mh | all(. != null))) as $hc
    | [ (if $f.duplicate != true then "not_duplicate" else empty end),
        (if (($f.duplicate_finding // -1) | IN($cids[])) then empty else "duplicate_finding_not_counterpart" end),
        (if ($fp | startswith("scan-target:")) and (($fp == "scan-target:ci" or ($fp | startswith("scan-target:ci "))) | not)
         then "file_path_not_scan_target_ci" else empty end),
        (if $hc and ($mh | any(. != $f.hash_code)) then "hash_code_differs" else empty end)
      ] as $r
    | {hc: $hc,
       entry: {id: $f.id, title: $f.title, file_path: $f.file_path, duplicate: $f.duplicate,
               duplicate_finding: $f.duplicate_finding, pr_hash_code: $f.hash_code,
               main_hash_codes: $mh, reasons: $r}}
  ] as $eval
| [$eval[] | select((.entry.reasons | length) > 0) | .entry] as $bad
| {
    pr_image_count: ($pi | length),
    main_counterpart_count: ($mc | length),
    matched_count: ($matched | length),
    drift: {count: ($drift | length), titles: ($drift | map(.title))},
    bad_count: ($bad | length),
    bad: $bad,
    hash_compared: (($eval | length) > 0 and ($eval | all(.hc))),
    verdict: (if ($matched | length) > 0 and ($bad | length) == 0 then "PASS" else "FAIL" end)
  }
'
# END TRIVY_IMAGE_VERDICT

# resolve_product: PID = the id of the one product named exactly $PRODUCT.
resolve_product() {
  local f="${WORK}/products.json" n
  api_get_all "/api/v2/products/?name_exact=$(uri "$PRODUCT")" "$f" || abort "PREREQ-PRODUCT" "$API_ERROR"
  n="$(jq --arg p "$PRODUCT" '[.results[] | select(.name == $p)] | length' "$f")"
  if [[ "$n" != "1" ]]; then
    abort "PREREQ-PRODUCT" "${n} products named exactly '${PRODUCT}', expected 1"
  fi
  PID="$(jq --arg p "$PRODUCT" '[.results[] | select(.name == $p)][0].id' "$f")"
}

# check_product_matches FILE LABEL: FILE's product_id must equal PID.
check_product_matches() {
  local got
  got="$(jq '.product_id' "$1")"
  if [[ "$got" != "$PID" ]]; then
    abort "PREREQ-PRODUCT" "${2} '${1}' is for product id ${got}, but '${PRODUCT}' is product id ${PID}"
  fi
}

# engagements_named NAME OUTFILE: the engagements of PID named exactly NAME,
# as {"raw_count": N, "results": [...]}. raw_count is the API's own count.
engagements_named() {
  local raw="${WORK}/engagements-raw.json"
  api_get_all "/api/v2/engagements/?product=${PID}&name=$(uri "$1")" "$raw" || return 1
  jq --arg n "$1" --argjson pid "$PID" \
    '{raw_count: .count, results: [.results[] | select(.name == $n and .product == $pid)]}' "$raw" > "$2"
}

# engagement_findings EID OUTFILE: {"engagement_id", "test_ids", "count",
# "findings"} for engagement EID, every finding checked to belong to a Test of
# EID (an ignored filter would otherwise return the whole instance silently).
engagement_findings() {
  local eid="$1" out="$2" tests="${WORK}/tests-${1}.json" finds="${WORK}/findings-${1}.json"
  local foreign
  api_get_all "/api/v2/tests/?engagement=${eid}" "$tests" || return 1
  foreign="$(jq --argjson e "$eid" '[.results[] | select(.engagement != $e) | .id]' "$tests")"
  if [[ "$foreign" != "[]" ]]; then
    API_ERROR="GET /api/v2/tests/?engagement=${eid} returned tests of another engagement: ${foreign}"
    return 1
  fi
  api_get_all "/api/v2/findings/?test__engagement=${eid}" "$finds" || return 1
  if ! jq -n --argjson e "$eid" --slurpfile t "$tests" --slurpfile f "$finds" "${SLIM}"'
      ($t[0].results | map(.id)) as $tids
      | ($f[0].results | map(slim)) as $fs
      | [$fs[] | select((.test | IN($tids[])) | not) | .id] as $foreign
      | if ($foreign | length) > 0
        then error("GET /api/v2/findings/?test__engagement=\($e) returned findings \($foreign) outside the tests \($tids) of that engagement; the filter was not applied")
        else {engagement_id: $e, test_ids: $tids, count: ($fs | length), findings: $fs}
        end' > "$out" 2> "${out}.err"; then
    API_ERROR="$(snippet "${out}.err")"
    return 1
  fi
}

# measure_dispositions DISPFILE OUTFILE: read back the three dispositioned
# findings and the risk acceptance, and compare each finding with the exact
# tuple measured in Phase 28 (import-proof P-DISPOSITION). OUTFILE gets
# {"fp"|"oos"|"ra": {id, expected, measured, ok}, "risk_acceptance": {...}}.
measure_dispositions() {
  local disp="$1" out="$2" role id ra_acc="${WORK}/ra-acceptance.json"
  for role in fp oos ra; do
    id="$(jq ".${role}" "$disp")"
    if api_get "/api/v2/findings/${id}/" "${WORK}/disp-${role}.json"; then
      if ! jq "${SLIM}"' slim' "${WORK}/disp-${role}.json" > "${WORK}/disp-${role}-slim.json" 2> "${WORK}/disp-${role}.err"; then
        jq -n --arg e "$(snippet "${WORK}/disp-${role}.err")" '{read_error: $e}' > "${WORK}/disp-${role}-slim.json"
      fi
    else
      jq -n --arg e "$API_ERROR" '{read_error: $e}' > "${WORK}/disp-${role}-slim.json"
    fi
  done
  if api_get "/api/v2/risk_acceptance/$(jq '.risk_acceptance_id' "$disp")/" "$ra_acc"; then
    jq '{expiration_date, decision, decision_details, accepted_findings}' "$ra_acc" > "${WORK}/ra-slim.json"
  else
    jq -n --arg e "$API_ERROR" '{read_error: $e}' > "${WORK}/ra-slim.json"
  fi
  jq -n --slurpfile d "$disp" \
    --slurpfile fp "${WORK}/disp-fp-slim.json" --slurpfile oos "${WORK}/disp-oos-slim.json" \
    --slurpfile ra "${WORK}/disp-ra-slim.json" --slurpfile acc "${WORK}/ra-slim.json" '
    {
      fp: {false_p: true, out_of_scope: false, risk_accepted: false, active: false, is_mitigated: true},
      oos: {false_p: false, out_of_scope: true, risk_accepted: false, active: false, is_mitigated: true},
      ra: {false_p: false, out_of_scope: false, risk_accepted: true, active: false, is_mitigated: false}
    } as $E
    | {fp: $fp[0], oos: $oos[0], ra: $ra[0]} as $M
    | ($acc[0]) as $a
    | reduce ("fp", "oos", "ra") as $r ({};
        .[$r] = {
          id: $d[0][$r],
          expected: $E[$r],
          measured: ($M[$r] | if has("read_error") then . else
            {id, test, false_p, out_of_scope, risk_accepted, active, is_mitigated, verified, duplicate} end),
          ok: (($M[$r] | has("read_error") | not) and ($M[$r].id == $d[0][$r])
               and ([$E[$r] | keys[] as $k | $M[$r][$k] == $E[$r][$k]] | all))
        })
    | .risk_acceptance = {
        id: $d[0].risk_acceptance_id,
        expected_expiry_date: ($d[0].ra_expiry | .[0:10]),
        measured: $a,
        ok: (($a | has("read_error") | not)
             and (($a.expiration_date // "") | tostring | .[0:10]) == ($d[0].ra_expiry | .[0:10])
             and (($a.decision_details // "") | tostring | length) > 0
             and ($d[0].ra | IN(($a.accepted_findings // [])[] | if type == "object" then .id else . end)))
      }' > "$out"
}

# ── snapshot ─────────────────────────────────────────────────────────────────
cmd_snapshot() {
  local f="${WORK}/eng.json" n eid out="${OUT_DIR}/${LABEL}-snapshot.json"
  resolve_product
  engagements_named "$ENGAGEMENT" "$f" || abort "SNAPSHOT-ENGAGEMENT" "$API_ERROR"
  n="$(jq '.results | length' "$f")"
  if [[ "$n" != "1" ]]; then
    abort "SNAPSHOT-ENGAGEMENT" "${n} engagements named exactly '${ENGAGEMENT}' in product ${PID}, expected 1"
  fi
  eid="$(jq '.results[0].id' "$f")"
  engagement_findings "$eid" "${WORK}/snap.json" || abort "SNAPSHOT-FINDINGS" "$API_ERROR"
  # tests (additive, Phase 29.4): the engagement's Tests, already read by
  # engagement_findings into tests-<eid>.json (no extra API call).
  jq --arg p "$PRODUCT" --argjson pid "$PID" --arg e "$ENGAGEMENT" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --slurpfile t "${WORK}/tests-${eid}.json" \
    '{captured_at: $at, product: $p, product_id: $pid, engagement: $e} + .
     + {tests: ($t[0].results | map({id, title, scan_type}))}' "${WORK}/snap.json" > "$out"
  echo "snapshot ${ENGAGEMENT}: $(jq '.count' "$out") findings"
  echo "wrote ${out}"
  exit 0
}

# ── assert-pr-duplicates (D-11 step 2) ───────────────────────────────────────
cmd_assert_pr_duplicates() {
  local name="ci/${BRANCH}" f="${WORK}/eng.json" n eid ur="${WORK}/under-review.json"
  local out="${OUT_DIR}/step2-assert.json" v meid mtests="${WORK}/main-tests.json" foreign
  local verdict="${WORK}/trivy-image-verdict.json" prtid mtid
  resolve_product
  check_product_matches "$MAIN_SNAPSHOT" "--main-snapshot"

  engagements_named "$name" "$f" || abort "D11-STEP2-ENGAGEMENT" "$API_ERROR"
  n="$(jq '.results | length' "$f")"
  if [[ "$n" != "1" ]]; then
    abort "D11-STEP2-ENGAGEMENT" "${n} engagements named exactly '${name}' in product ${PID}, expected 1"
  fi
  eid="$(jq '.results[0].id' "$f")"
  if [[ "$eid" == "$(jq '.engagement_id' "$MAIN_SNAPSHOT")" ]]; then
    abort "D11-STEP2-ENGAGEMENT" "engagement '${name}' has id ${eid}, which is the --main-snapshot engagement"
  fi
  pass "D11-STEP2-ENGAGEMENT" "engagement '${name}' exists in product ${PID} (id ${eid})"

  engagement_findings "$eid" "${WORK}/branch.json" || abort "D11-STEP2-READ" "$API_ERROR"
  # The TRIAGE.md Under Review query, verbatim, scoped to the PR engagement.
  api_get_all "/api/v2/findings/?test__engagement=${eid}&active=true&verified=false&false_p=false&out_of_scope=false&risk_accepted=false&duplicate=false&is_mitigated=false" "$ur" ||
    abort "D11-STEP2-READ" "$API_ERROR"

  # The ci/main Tests: the --main-snapshot `tests` array, or (an older snapshot
  # without it) a live read of the snapshot engagement's Tests through the same
  # foreign-row guard as engagement_findings (see TRIVY-IMAGE DEDUP above).
  meid="$(jq '.engagement_id' "$MAIN_SNAPSHOT")"
  if jq -e 'has("tests")' "$MAIN_SNAPSHOT" > /dev/null; then
    jq '{count: (.tests | length), results: .tests}' "$MAIN_SNAPSHOT" > "$mtests"
  else
    api_get_all "/api/v2/tests/?engagement=${meid}" "$mtests" || abort "D11-STEP2-READ" "$API_ERROR"
    foreign="$(jq --argjson e "$meid" '[.results[] | select(.engagement != $e) | .id]' "$mtests")"
    if [[ "$foreign" != "[]" ]]; then
      abort "D11-STEP2-READ" "GET /api/v2/tests/?engagement=${meid} returned tests of another engagement: ${foreign}"
    fi
  fi

  # engagement_findings left the PR engagement's Tests in tests-<eid>.json; the
  # trivy-image Test is read from them (TRIVY-IMAGE DEDUP above).
  jq -n --slurpfile b "${WORK}/branch.json" --slurpfile u "$ur" --slurpfile m "$MAIN_SNAPSHOT" \
    --slurpfile t "${WORK}/tests-${eid}.json" --slurpfile mt "$mtests" \
    --arg fx "$FIXTURE_PATH" --arg name "$name" '
    ($b[0].findings) as $bf
    | [$t[0].results[] | select(.scan_type == "Trivy Scan" and .title == "trivy-image")] as $img_tests
    | ($img_tests | map(.id)) as $imgids
    | [$mt[0].results[] | select(.scan_type == "Trivy Scan" and .title == "trivy-image")] as $main_img_tests
    | ($bf | map(.id)) as $bids
    | ($m[0].findings | map(.id)) as $mids
    | ($u[0].results) as $ur
    | [$ur[] | select(((.id | IN($bids[])) | not) or .active != true or .verified != false or .false_p != false
        or .out_of_scope != false or .risk_accepted != false or .duplicate != false or .is_mitigated != false)
        | .id] as $ur_violations
    | ($ur | map(.id) | unique) as $ur_ids
    | ($bf | map(select((.file_path // "") | contains($fx)))) as $fixture
    | ($fixture | map(.id) | unique) as $fx_ids
    | ($bf | map(select(((.id | IN($fx_ids[])) | not) and ((.test | IN($imgids[])) | not)))) as $others
    | [$others[] | select(.duplicate != true or ((.duplicate_finding // -1) | IN($mids[]) | not))
        | {id, title, file_path, active, duplicate, duplicate_finding}] as $others_bad
    | {
        engagement: $name,
        engagement_id: $b[0].engagement_id,
        test_ids: $b[0].test_ids,
        branch_finding_count: ($bf | length),
        main_snapshot_engagement_id: $m[0].engagement_id,
        main_snapshot_finding_count: ($mids | length),
        fixture_path: $fx,
        under_review: {count: ($ur_ids | length), ids: $ur_ids,
                       file_paths: ($ur | map(.file_path) | unique), filter_violations: $ur_violations},
        fixture: {count: ($fx_ids | length), ids: $fx_ids, file_paths: ($fixture | map(.file_path) | unique)},
        untriaged_eq_fixture: (($ur_violations | length) == 0 and ($ur_ids | length) > 0 and $ur_ids == $fx_ids),
        trivy_image_key: {scan_type: "Trivy Scan", title: "trivy-image",
                          pr_tests: ($img_tests | map({id, title, scan_type})),
                          main_tests: ($main_img_tests | map({id, title, scan_type})),
                          ok: (($img_tests | length) == 1 and ($main_img_tests | length) == 1)},
        trivy_image_dedup: null,
        others: {count: ($others | length), ids: ($others | map(.id))},
        others_not_duplicate_of_main: $others_bad,
        duplicates_point_to_main: (($others | length) > 0 and ($others_bad | length) == 0)
      }' > "$out"

  v="$(jq -r '"\(.under_review.count) \(.fixture.count) \(.under_review.filter_violations | length)"' "$out")"
  if [[ "$(jq '.untriaged_eq_fixture' "$out")" == "true" ]]; then
    pass "D11-STEP2-UNTRIAGED-EQ-FIXTURE" "the Under Review set on ${name} is exactly the ${v%% *} finding(s) under '${FIXTURE_PATH}': $(jq -c '.under_review.file_paths' "$out")"
  else
    fail "D11-STEP2-UNTRIAGED-EQ-FIXTURE" "Under Review ids $(jq -c '.under_review.ids' "$out") file_paths $(jq -c '.under_review.file_paths' "$out") vs fixture ids $(jq -c '.fixture.ids' "$out") file_paths $(jq -c '.fixture.file_paths' "$out"); rows violating the filter client-side: $(jq -c '.under_review.filter_violations' "$out") (note: Trivy findings arrive verified=true and never match this filter, so the fixture must come from a non-Trivy parser)"
  fi

  if [[ "$(jq '.trivy_image_key.ok' "$out")" == "true" ]]; then
    prtid="$(jq '.trivy_image_key.pr_tests[0].id' "$out")"
    mtid="$(jq '.trivy_image_key.main_tests[0].id' "$out")"
    pass "D11-STEP2-TRIVY-IMAGE-KEY" "exactly one Test matches scan_type 'Trivy Scan' and title 'trivy-image' on each side: ${name} Test ${prtid}, ci/main snapshot engagement ${meid} Test ${mtid}"
    if ! jq -n --slurpfile pr "${WORK}/branch.json" --argjson prtid "$prtid" \
      --slurpfile main "$MAIN_SNAPSHOT" --argjson mtid "$mtid" "$TRIVY_IMAGE_VERDICT" > "$verdict" 2> "${verdict}.err"; then
      abort "D11-STEP2-TRIVY-IMAGE-DEDUP" "the verdict program failed: $(snippet "${verdict}.err")"
    fi
    jq --slurpfile vd "$verdict" '.trivy_image_dedup = $vd[0]' "$out" > "${out}.tmp" && mv "${out}.tmp" "$out"
    if [[ "$(jq -r '.trivy_image_dedup.verdict' "$out")" == "PASS" ]]; then
      pass "D11-STEP2-TRIVY-IMAGE-DEDUP" "all $(jq '.trivy_image_dedup.matched_count' "$out") trivy-image finding(s) with a ci/main counterpart are duplicates of it (hash_code compared: $(jq '.trivy_image_dedup.hash_compared' "$out"))"
    elif [[ "$(jq '.trivy_image_dedup.matched_count' "$out")" == "0" ]]; then
      fail "D11-STEP2-TRIVY-IMAGE-DEDUP" "no PR trivy-image finding has a title counterpart in the ci/main trivy-image Test (zero overlap; the assertion would be vacuous): $(jq '.trivy_image_dedup.pr_image_count' "$out") PR finding(s), $(jq '.trivy_image_dedup.main_counterpart_count' "$out") ci/main counterpart(s)"
    else
      fail "D11-STEP2-TRIVY-IMAGE-DEDUP" "$(jq '.trivy_image_dedup.bad_count' "$out") of $(jq '.trivy_image_dedup.matched_count' "$out") matched trivy-image finding(s) do not dedupe against ci/main: $(jq -c '.trivy_image_dedup.bad[:10]' "$out") (hash_code_differs means the Trivy DB content changed between the two scans or a hashed field still carries a varying value)"
    fi
    echo "    INFO: drift (measured, not asserted): $(jq '.trivy_image_dedup.drift.count' "$out") PR trivy-image finding(s) without a ci/main title counterpart: $(jq -c '.trivy_image_dedup.drift.titles[:10]' "$out")"
  else
    fail "D11-STEP2-TRIVY-IMAGE-KEY" "expected exactly 1 Test matching scan_type 'Trivy Scan' and title 'trivy-image' on each side, got ${name}: $(jq -c '.trivy_image_key.pr_tests' "$out"), ci/main snapshot engagement ${meid}: $(jq -c '.trivy_image_key.main_tests' "$out")"
    SKIPPED+=("D11-STEP2-TRIVY-IMAGE-DEDUP: not evaluated, it depends on D11-STEP2-TRIVY-IMAGE-KEY")
  fi

  if [[ "$(jq '.duplicates_point_to_main' "$out")" == "true" ]]; then
    pass "D11-STEP2-DUPLICATES-POINT-TO-MAIN" "all $(jq '.others.count' "$out") non-fixture, non-trivy-image finding(s) on ${name} are duplicates of ci/main originals in the snapshot"
  elif [[ "$(jq '.others.count' "$out")" == "0" ]]; then
    fail "D11-STEP2-DUPLICATES-POINT-TO-MAIN" "${name} has no non-fixture, non-trivy-image findings, so there are no pre-existing findings to be duplicates; the assertion would be vacuous"
  else
    fail "D11-STEP2-DUPLICATES-POINT-TO-MAIN" "$(jq '.others_not_duplicate_of_main | length' "$out") of $(jq '.others.count' "$out") non-fixture, non-trivy-image finding(s) are not duplicates of a --main-snapshot finding: $(jq -c '.others_not_duplicate_of_main[:10]' "$out")"
  fi
  echo "    evidence: ${out}"
  print_summary
}

# ── disposition (D-11 step 3) ────────────────────────────────────────────────
# Admin token only; never the ci-importer token (see WHICH TOKEN above).
cmd_disposition() {
  local pre ures="${WORK}/users.json" admin_id ra_expiry body="${WORK}/disp-body.json"
  local resp="${WORK}/disp-resp.json" ra_acc_id role id live done_writes=""
  local out="${OUT_DIR}/dispositions.json"

  # Pre-validate against the snapshot BEFORE any API call (T-29-12).
  pre="$(jq -r --argjson fp "$FP_ID" --argjson oos "$OOS_ID" --argjson ra "$RA_ID" '
    ([$fp, $oos, $ra] | unique | length) as $distinct
    | [$fp, $oos, $ra][] as $id
    | (.findings | map(select(.id == $id))) as $hit
    | if ($hit | length) != 1 then "finding \($id) is not in the --main-snapshot"
      elif $hit[0].active != true or $hit[0].duplicate != false
      then "finding \($id) is active=\($hit[0].active) duplicate=\($hit[0].duplicate) in the snapshot, expected active=true duplicate=false"
      elif $distinct != 3 then "the --fp, --oos and --ra ids must be distinct"
      else empty end' "$MAIN_SNAPSHOT" | sort -u | tr '\n' ';')"
  if [[ -n "$pre" ]]; then
    abort "D11-STEP3-PREVALIDATE" "${pre} nothing was written"
  fi
  resolve_product
  check_product_matches "$MAIN_SNAPSHOT" "--main-snapshot"
  # The snapshot can be stale: re-read each finding live before writing.
  for role in fp oos ra; do
    case "$role" in fp) id="$FP_ID" ;; oos) id="$OOS_ID" ;; ra) id="$RA_ID" ;; esac
    api_get "/api/v2/findings/${id}/" "${WORK}/pre-${role}.json" ||
      abort "D11-STEP3-PREVALIDATE" "live re-read of ${role} finding ${id}: ${API_ERROR}; nothing was written"
    live="$(jq -r --slurpfile s "$MAIN_SNAPSHOT" '
      if (.test | IN($s[0].test_ids[])) | not then "is in test \(.test), not a Test of the snapshot engagement"
      elif .active != true or .duplicate != false then "is now active=\(.active) duplicate=\(.duplicate)"
      else "ok" end' "${WORK}/pre-${role}.json")"
    if [[ "$live" != "ok" ]]; then
      abort "D11-STEP3-PREVALIDATE" "live re-read: ${role} finding ${id} ${live}; nothing was written"
    fi
  done
  pass "D11-STEP3-PREVALIDATE" "fp ${FP_ID}, oos ${OOS_ID}, ra ${RA_ID} are distinct, active, non-duplicate ci/main findings (snapshot and live)"

  # The RA owner is the admin user, read by username and selected client-side.
  api_get_all "/api/v2/users/?username=admin" "$ures" || abort "D11-STEP3-RA-OWNER" "$API_ERROR"
  admin_id="$(jq '[.results[] | select(.username == "admin") | .id] | if length == 1 then .[0] else "none" end' "$ures")"
  if [[ ! "$admin_id" =~ ^[0-9]+$ ]]; then
    abort "D11-STEP3-RA-OWNER" "GET /api/v2/users/?username=admin: expected exactly one user named admin; nothing was written"
  fi
  # UTC today + 90 days, the Phase 28 D-22 risk_acceptance_form_default_days value.
  ra_expiry="$(python3 -c 'import datetime; print((datetime.datetime.now(datetime.timezone.utc).date() + datetime.timedelta(days=90)).strftime("%Y-%m-%dT00:00:00Z"))')"
  echo "    RA owner: admin (id ${admin_id}); expiration_date ${ra_expiry}"

  jq -n '{false_p: true, active: false, verified: false}' > "$body"
  api_request PATCH "/api/v2/findings/${FP_ID}/" "$resp" 200 "$body" ||
    abort "D11-STEP3-WRITE" "fp: ${API_ERROR}; writes already done: none"
  done_writes="fp ${FP_ID}"
  jq -n '{out_of_scope: true, active: false}' > "$body"
  api_request PATCH "/api/v2/findings/${OOS_ID}/" "$resp" 200 "$body" ||
    abort "D11-STEP3-WRITE" "oos: ${API_ERROR}; writes already done: ${done_writes}"
  done_writes="${done_writes}, oos ${OOS_ID}"
  jq -n --argjson owner "$admin_id" --argjson f "$RA_ID" --arg exp "$ra_expiry" \
    '{name: "Phase 29 D-11 live lifecycle proof", owner: $owner, accepted_findings: [$f],
      expiration_date: $exp, decision: "A",
      decision_details: "Phase 29 D-11: disposition must survive a ci/main reimport"}' > "$body"
  api_request POST "/api/v2/risk_acceptance/" "$resp" 201 "$body" ||
    abort "D11-STEP3-WRITE" "ra: ${API_ERROR}; writes already done: ${done_writes}"
  ra_acc_id="$(jq '.id' "$resp")"
  if [[ ! "$ra_acc_id" =~ ^[0-9]+$ ]]; then
    abort "D11-STEP3-WRITE" "POST /api/v2/risk_acceptance/ returned 201 without an integer id; writes done: ${done_writes}, ra (unknown id)"
  fi
  pass "D11-STEP3-WRITE" "fp PATCH 200, oos PATCH 200, risk_acceptance POST 201 (id ${ra_acc_id})"

  jq -n --argjson pid "$PID" --slurpfile s "$MAIN_SNAPSHOT" --argjson fp "$FP_ID" --argjson oos "$OOS_ID" \
    --argjson ra "$RA_ID" --argjson acc "$ra_acc_id" --argjson owner "$admin_id" --arg exp "$ra_expiry" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{written_at: $at, product_id: $pid, main_engagement_id: $s[0].engagement_id, fp: $fp, oos: $oos, ra: $ra,
      risk_acceptance_id: $acc, ra_owner_id: $owner, ra_expiry: $exp}' > "${WORK}/disp-ids.json"
  measure_dispositions "${WORK}/disp-ids.json" "${WORK}/disp-readback.json"
  jq --slurpfile r "${WORK}/disp-readback.json" '. + {readback: $r[0]}' "${WORK}/disp-ids.json" > "$out"

  # Stage-0 read-back (import-proof P-DISPOSITION stage 0): each flag true and
  # active=false. The full tuples are D11-STEP4-*.
  for role in fp oos ra; do
    local flag sid
    case "$role" in
      fp) flag=false_p sid=D11-STEP3-FP ;;
      oos) flag=out_of_scope sid=D11-STEP3-OOS ;;
      ra) flag=risk_accepted sid=D11-STEP3-RA ;;
    esac
    if [[ "$(jq --arg r "$role" --arg k "$flag" '.readback[$r].measured | (.[$k] == true and .active == false)' "$out")" == "true" ]]; then
      pass "$sid" "finding $(jq ".${role}" "$out") reads ${flag}=true active=false"
    else
      fail "$sid" "finding $(jq ".${role}" "$out") read back as $(jq -c --arg r "$role" '.readback[$r].measured' "$out")"
    fi
  done
  echo "    evidence: ${out}"
  print_summary
}

# report_step4 MEASURED: the D-11 step-4 verdicts (IDs D11-STEP4-*) from a
# measure_dispositions file.
report_step4() {
  local m="$1" role id
  for role in fp oos ra; do
    case "$role" in fp) id=D11-STEP4-FP ;; oos) id=D11-STEP4-OOS ;; ra) id=D11-STEP4-RA ;; esac
    if [[ "$(jq --arg r "$role" '.[$r].ok' "$m")" == "true" ]]; then
      pass "$id" "finding $(jq --arg r "$role" '.[$r].id' "$m") matches $(jq -c --arg r "$role" '.[$r].expected' "$m")"
    else
      fail "$id" "finding $(jq --arg r "$role" '.[$r].id' "$m") expected $(jq -c --arg r "$role" '.[$r].expected' "$m"), measured $(jq -c --arg r "$role" '.[$r].measured' "$m")"
    fi
  done
  if [[ "$(jq '.risk_acceptance.ok' "$m")" == "true" ]]; then
    pass "D11-STEP4-RA-EXPIRY" "risk acceptance $(jq '.risk_acceptance.id' "$m") exists, expires $(jq -r '.risk_acceptance.expected_expiry_date' "$m"), has a reason and holds the ra finding"
  else
    fail "D11-STEP4-RA-EXPIRY" "risk acceptance $(jq '.risk_acceptance.id' "$m"): expected expiry date $(jq -r '.risk_acceptance.expected_expiry_date' "$m"), a non-empty decision_details and the ra finding; measured $(jq -c '.risk_acceptance.measured' "$m")"
  fi
}

# ── assert-dispositions (D-11 step 4) ────────────────────────────────────────
cmd_assert_dispositions() {
  local out="${OUT_DIR}/step4-assert.json"
  resolve_product
  check_product_matches "$DISPOSITIONS" "--dispositions"
  measure_dispositions "$DISPOSITIONS" "${WORK}/step4.json"
  jq --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{measured_at: $at} + .' "${WORK}/step4.json" > "$out"
  report_step4 "$out"
  echo "    evidence: ${out}"
  print_summary
}

# ── assert-closed (D-11 step 5, amended 2026-09-26) ──────────────────────────
cmd_assert_closed() {
  local name="ci/${BRANCH}" f="${WORK}/eng.json" out="${OUT_DIR}/step5-assert.json"
  local main_eid main_name engs="${WORK}/product-engagements.json" eid all="${WORK}/product-findings.rows"
  local offenders oid
  resolve_product
  check_product_matches "$MAIN_SNAPSHOT" "--main-snapshot"
  check_product_matches "$DISPOSITIONS" "--dispositions"

  # D11-STEP5-ENGAGEMENT-GONE: the exact-name set is what is asserted empty;
  # the API's own count is recorded beside it.
  engagements_named "$name" "$f" || abort "D11-STEP5-READ" "$API_ERROR"
  if [[ "$(jq '.results | length' "$f")" == "0" ]]; then
    pass "D11-STEP5-ENGAGEMENT-GONE" "no engagement named exactly '${name}' in product ${PID} (API count for the name filter: $(jq '.raw_count' "$f"))"
  else
    fail "D11-STEP5-ENGAGEMENT-GONE" "engagement(s) named '${name}' still exist: $(jq -c '[.results[] | {id, name}]' "$f")"
  fi

  # D11-STEP5-MAIN-COUNT-UNCHANGED: the same ci/main engagement, re-read.
  main_eid="$(jq '.engagement_id' "$MAIN_SNAPSHOT")"
  main_name="$(jq -r '.engagement' "$MAIN_SNAPSHOT")"
  api_get "/api/v2/engagements/${main_eid}/" "${WORK}/main-eng.json" || abort "D11-STEP5-READ" "$API_ERROR"
  engagement_findings "$main_eid" "${WORK}/main-now.json" || abort "D11-STEP5-READ" "$API_ERROR"
  jq -n --slurpfile s "$MAIN_SNAPSHOT" --slurpfile n "${WORK}/main-now.json" --slurpfile e "${WORK}/main-eng.json" '
    ($s[0].findings | map(.id)) as $before | ($n[0].findings | map(.id)) as $now
    | {engagement_id: $s[0].engagement_id, engagement_name_now: $e[0].name,
       snapshot_count: $s[0].count, count_now: $n[0].count,
       added: ($now - $before), removed: ($before - $now)}' > "${WORK}/main-count.json"
  if [[ "$(jq --arg n "$main_name" '.engagement_name_now == $n and .snapshot_count == .count_now' "${WORK}/main-count.json")" == "true" ]]; then
    pass "D11-STEP5-MAIN-COUNT-UNCHANGED" "${main_name} (id ${main_eid}) holds $(jq '.count_now' "${WORK}/main-count.json") findings, as in the snapshot"
  else
    fail "D11-STEP5-MAIN-COUNT-UNCHANGED" "${main_name} (id ${main_eid}): $(jq -c '{engagement_name_now, snapshot_count, count_now, added: .added[:10], removed: .removed[:10]}' "${WORK}/main-count.json")"
  fi

  # D11-STEP5-DISPOSITIONS-UNCHANGED: the step-4 comparisons, re-run.
  measure_dispositions "$DISPOSITIONS" "${WORK}/step5-disp.json"
  if [[ "$(jq '.fp.ok and .oos.ok and .ra.ok and .risk_acceptance.ok' "${WORK}/step5-disp.json")" == "true" ]]; then
    pass "D11-STEP5-DISPOSITIONS-UNCHANGED" "fp, oos and ra tuples and the risk acceptance match the step-4 expectations"
  else
    fail "D11-STEP5-DISPOSITIONS-UNCHANGED" "$(jq -c '{fp: {ok: .fp.ok, measured: .fp.measured}, oos: {ok: .oos.ok, measured: .oos.measured}, ra: {ok: .ra.ok, measured: .ra.measured}, risk_acceptance: {ok: .risk_acceptance.ok, measured: .risk_acceptance.measured}}' "${WORK}/step5-disp.json")"
  fi

  # D11-STEP5-NO-DANGLING-DUPLICATE: every finding of every engagement of the
  # product (import-proof `outside = [...]` shape).
  api_get_all "/api/v2/engagements/?product=${PID}" "$engs" || abort "D11-STEP5-READ" "$API_ERROR"
  if [[ "$(jq --argjson pid "$PID" '[.results[] | select(.product != $pid)] | length' "$engs")" != "0" ]]; then
    abort "D11-STEP5-READ" "GET /api/v2/engagements/?product=${PID} returned engagements of another product; the filter was not applied"
  fi
  : > "$all"
  for eid in $(jq '.results[].id' "$engs"); do
    engagement_findings "$eid" "${WORK}/eng-${eid}-findings.json" || abort "D11-STEP5-READ" "$API_ERROR"
    jq -c '.findings[]' "${WORK}/eng-${eid}-findings.json" >> "$all"
  done
  jq -s '. as $fs | ($fs | map(.id)) as $ids
    | ($fs | map(select(.duplicate == true))) as $dups
    | {product_finding_count: ($fs | length), duplicate_count: ($dups | length),
       dangling: [$dups[] | select(.duplicate_finding == null or ((.duplicate_finding | IN($ids[])) | not))
                  | {id, test, duplicate_finding}]}' "$all" > "${WORK}/dangling.json"
  # Enrich up to 10 offenders with the HTTP status of the referenced id.
  offenders="$(jq -r '.dangling[:10][] | .duplicate_finding // empty' "${WORK}/dangling.json")"
  : > "${WORK}/dangling-status.rows"
  for oid in $offenders; do
    # Any HTTP code (200, 404, ...) is recorded; a transport failure (curl
    # exit or TLS verification) aborts rather than being recorded as a code.
    api_transport GET "/api/v2/findings/${oid}/" /dev/null || abort "D11-STEP5-READ" "$API_ERROR"
    jq -n --argjson id "$oid" --arg c "$HTTP_CODE" '{duplicate_finding: $id, http: $c}' >> "${WORK}/dangling-status.rows"
  done
  jq --slurpfile st <(jq -s '.' "${WORK}/dangling-status.rows") '. + {referenced_status: $st[0]}' \
    "${WORK}/dangling.json" > "${WORK}/dangling-full.json"
  if [[ "$(jq '.dangling | length' "${WORK}/dangling-full.json")" == "0" ]]; then
    pass "D11-STEP5-NO-DANGLING-DUPLICATE" "all $(jq '.duplicate_count' "${WORK}/dangling-full.json") duplicate(s) among $(jq '.product_finding_count' "${WORK}/dangling-full.json") product findings reference a finding that exists in the product"
  else
    fail "D11-STEP5-NO-DANGLING-DUPLICATE" "$(jq '.dangling | length' "${WORK}/dangling-full.json") duplicate(s) reference a missing or null original: $(jq -c '{dangling: .dangling[:10], referenced_status}' "${WORK}/dangling-full.json")"
  fi

  echo "INFO: re-parenting NOT asserted (D-11 amended 2026-09-26): no ci/main finding is a duplicate of a PR finding in this sequence; re-parenting was proven on kind in Phase 28"

  jq -n --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg name "$name" --slurpfile e "$f" \
    --slurpfile c "${WORK}/main-count.json" --slurpfile d "${WORK}/step5-disp.json" \
    --slurpfile g "${WORK}/dangling-full.json" \
    '{measured_at: $at, closed_engagement: $name,
      engagement_gone: {raw_count: $e[0].raw_count, exact_name_matches: [$e[0].results[] | {id, name}]},
      main_count: $c[0], dispositions: $d[0], no_dangling_duplicate: $g[0],
      reparenting: "NOT asserted (D-11 amended 2026-09-26)"}' > "$out"
  echo "    evidence: ${out}"
  print_summary
}

case "$SUBCMD" in
  snapshot) cmd_snapshot ;;
  assert-pr-duplicates) cmd_assert_pr_duplicates ;;
  disposition) cmd_disposition ;;
  assert-dispositions) cmd_assert_dispositions ;;
  assert-closed) cmd_assert_closed ;;
esac
