#!/usr/bin/env bash
set -euo pipefail

# defectdojo-import-proof.sh — the LIVE proof (Phase 27, D-19/D-20) that the
# committed DefectDojo side-channel jobs in .github/workflows/security.yml
# actually land findings in a real DefectDojo, as a least-privilege user, over
# verified TLS.
#
# WHY THIS EXISTS. A kind cluster is reachable only from the runner that
# created it, and a `uses: ./.github/workflows/security.yml` job runs the callee
# on OTHER runners, so the workflow cannot simply be called with DEFECTDOJO_URL
# pointed at the smoke cluster (RESEARCH Pattern 7). Instead this harness
# EXTRACTS the committed `run:` bodies of the side-channel steps from
# security.yml with yq and executes them itself, under the runner's default
# shell (`bash -e <file>`), with the same env: names the workflow supplies.
# There is exactly one source of truth: the harness never carries a copy of
# the import or cleanup logic, and it refuses any body that still contains a
# `${{` expression (T-27-01), because such a body would differ from what the
# runner executes after template expansion.
#
# The ephemeral DefectDojo is the Phase 26 kind smoke. This script is its
# DD_SMOKE_POST_HOOK: the smoke brings the cluster up, proves its own checks,
# and only on an all-pass run calls `bash <this script> --hook` while the
# cluster and the port-forward are still up.
#
# Least privilege (D-10): imports run as a dedicated user `ci-importer` that
# the harness creates with is_staff=true and is_superuser=false, which is the
# documented minimum for import + auto-create + delete. The admin token is used
# only to create that user and for read-side assertions.
#
# TLS (D-18): every call is verified against the kind CA (DEFECTDOJO_CA_CERT /
# --cacert). TLS verification is never switched off, DD_INSECURE is empty on
# every network-bound body run, and host resolution comes from a curlrc
# `resolve` entry under CURL_HOME, not from a hosts-file edit and not from a
# TLS bypass. The committed bodies call plain curl, so the curlrc reaches them
# too and they need no harness-only branch.
#
# Modes:
#   <reports-dir>   entry: preflight, the --extract-only checks, then run the
#                   kind smoke with this script as its post-hook. Exits with
#                   the smoke's exit code.
#   --extract-only  static, no cluster: extract the six side-channel run:
#                   bodies, refuse `${{`, `bash -n` each, cross-check every
#                   contract env name against the committed step env, and
#                   assert the two dd-gate bodies are identical.
#   --hook          live, called by the smoke: mint tokens, run the committed
#                   bodies, assert the run-1 state. Prints one
#                   "PROOF: <ID> PASS|FAIL <detail>" line per assertion.
#
# DD_PROOF_WORKFLOW overrides the workflow path (scratch-copy self-tests only).
#
# INTERMEDIATE STATE (27-05): run 2, the cleanup assertions and the
# insecure-warning check land in 27-06. Until then --hook never reports a pass:
# its last line is "PROOF INCOMPLETE - ..." and it exits 1. A partial proof is
# not a proof.
#
# Credentials are generated or read at runtime, written only to 0600 files,
# sent with `--data-binary @file` or `-H @file`, never placed on any argv and
# never echoed. xtrace is never enabled anywhere in this script.
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/defectdojo-import-proof.sh <reports-dir>
#   bash scripts/defectdojo-import-proof.sh --extract-only
#
# Exit codes:
#   0  --extract-only: every static check passed (--hook: reserved for 27-06)
#   1  at least one check or proof assertion failed, or the proof is incomplete
#   2  preflight failure: a required binary, report file or hook variable is
#      missing

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SELF="${REPO_ROOT}/scripts/defectdojo-import-proof.sh"
WORKFLOW="${DD_PROOF_WORKFLOW:-.github/workflows/security.yml}"

# The report files every scan run produces whatever the repository contains.
# The others (trivy-image, npm-audit-<N>, pip-audit-<N>, tflint.sarif) are
# conditional and, when present, must be imported too (P-TESTS).
readonly REQUIRED_REPORTS=(semgrep-results.json checkov-results.json trivy-fs.json gitleaks-results.json)

# Fixed proof identities (run 1). Branch-like values deliberately contain a
# slash, the case the engagement name and URL encoding must survive.
readonly PROOF_PRODUCT="proof/security-platform"
readonly PROOF_PRODUCT_TYPE="CI"
readonly PROOF_BRANCH_A="proof/branch-a"
readonly PROOF_USER="ci-importer"
readonly PROOF_SHA="0123456789abcdef0123456789abcdef01234567"
readonly PROOF_RUN_ID="2705001"
readonly PROOF_SERVER_URL="https://github.com"
readonly PROOF_REPOSITORY="OttawaCloudConsulting/security-platform"

usage() {
  echo "usage: bash scripts/defectdojo-import-proof.sh <reports-dir> | --extract-only | --hook" >&2
  exit 2
}

require_bins() {
  local bin
  for bin in "$@"; do
    if ! command -v "$bin" &>/dev/null; then
      echo "FATAL: required binary '${bin}' not found on PATH" >&2
      exit 2
    fi
  done
}

# gen_secret LENGTH: alphanumeric, same generator as defectdojo-live-smoke.sh.
gen_secret() {
  local want="$1" raw
  raw="$(head -c $((want * 2)) /dev/urandom | base64 | tr -d '/+=\n')"
  if [ "${#raw}" -lt "$want" ]; then
    echo "FATAL: credential generator produced ${#raw} chars, needed ${want}" >&2
    exit 2
  fi
  printf '%s' "${raw:0:want}"
}

# extract_bodies OUTDIR: the static contract checks. Converts the workflow to
# JSON with yq once and checks it in stdlib Python. Writes each checked body to
# OUTDIR/<job>__<step>.sh (0600) for --hook to execute. Prints one PASS/FAIL
# line per check; exits 0 only when every check passed.
extract_bodies() {
  local outdir="$1"
  if [ ! -f "$WORKFLOW" ]; then
    echo "FATAL: workflow ${WORKFLOW} not found" >&2
    return 2
  fi
  local wf_json="${outdir}/workflow.json"
  if ! yq -o=json '.' "$WORKFLOW" > "$wf_json"; then
    echo "FAIL: EXTRACT: yq could not parse ${WORKFLOW}"
    return 1
  fi
  python3 - "$wf_json" "$outdir" "$WORKFLOW" <<'PY'
import json
import os
import subprocess
import sys

wf_json, outdir, workflow = sys.argv[1], sys.argv[2], sys.argv[3]
with open(wf_json, encoding="utf-8") as handle:
    doc = json.load(handle)
jobs = doc.get("jobs") or {}

# SIDE-CHANNEL CONTRACT (27-02 / 27-03): the exact env: names each step gets.
# The harness supplies exactly these; a drifted step env would make the
# harness run a body under different inputs than the runner does.
CONTRACT = [
    ("defectdojo-import", "dd-gate", ["DD_TOKEN"]),
    ("defectdojo-import", "dd-import", ["DD_URL", "DD_TOKEN", "DD_PRODUCT", "DD_PRODUCT_TYPE",
                                        "DD_INSECURE", "DD_CA_CERT", "DD_REPORTS_DIR",
                                        "DD_RESULTS_FILE"]),
    ("defectdojo-import", "dd-verify", ["DD_IMPORT_OUTCOME", "DD_RESULTS_FILE"]),
    ("defectdojo-cleanup", "dd-gate", ["DD_TOKEN"]),
    ("defectdojo-cleanup", "dd-delete", ["DD_URL", "DD_TOKEN", "DD_PRODUCT", "DD_INSECURE",
                                         "DD_CA_CERT", "DD_DEFAULT_BRANCH",
                                         "DD_CLEANUP_RESULT_FILE"]),
    ("defectdojo-cleanup", "dd-cleanup-verify", ["DD_DELETE_OUTCOME", "DD_CLEANUP_RESULT_FILE"]),
]

failed = 0
passed = 0


def ok(label, message):
    global passed
    passed += 1
    print("PASS: {}: {}".format(label, message))


def bad(label, message):
    global failed
    failed += 1
    print("FAIL: {}: {}".format(label, message))


def find_step(job_id, step_id):
    job = jobs.get(job_id)
    if not isinstance(job, dict):
        return None, "job {!r} not found in {}".format(job_id, workflow)
    for step in job.get("steps") or []:
        if isinstance(step, dict) and step.get("id") == step_id:
            return step, None
    return None, "step id {!r} not found in job {!r}".format(step_id, job_id)


bodies = {}
for job_id, step_id, keys in CONTRACT:
    label = "{}/{}".format(job_id, step_id)
    step, err = find_step(job_id, step_id)
    if step is None:
        bad(label, err)
        continue
    # The runner default (`bash -e {0}`) is what the harness reproduces; a
    # shell: key would change the semantics.
    if "shell" in step:
        bad(label, "step has a shell: key ({!r}); the harness runs bodies as bash -e".format(step["shell"]))
        continue
    body = step.get("run")
    if not isinstance(body, str) or not body.strip():
        bad(label, "step has no run: body")
        continue
    if "${{" in body:
        bad(label, "run: body contains a ${{ expression; the executed body would differ from the committed text")
        continue
    env_keys = sorted((step.get("env") or {}).keys())
    if env_keys != sorted(keys):
        bad(label, "step env names {} differ from the side-channel contract {}".format(env_keys, sorted(keys)))
        continue
    path = os.path.join(outdir, "{}__{}.sh".format(job_id, step_id))
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as handle:
        handle.write(body)
    proc = subprocess.run(["bash", "-n", path], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          universal_newlines=True)
    if proc.returncode != 0:
        bad(label, "bash -n failed: {}".format(proc.stderr.strip()[:300]))
        continue
    bodies[(job_id, step_id)] = body
    ok(label, "extracted ({} lines), no ${{{{, bash -n clean, env names match the contract {}".format(
        len(body.splitlines()), sorted(keys)))

# dd-download is a uses: step with no run: body; it must stay that way, or the
# harness would be skipping a body the runner executes.
step, err = find_step("defectdojo-import", "dd-download")
if step is None:
    bad("defectdojo-import/dd-download", err)
elif "run" in step or "uses" not in step:
    bad("defectdojo-import/dd-download", "expected a uses: step with no run: body")

gate_a = bodies.get(("defectdojo-import", "dd-gate"))
gate_b = bodies.get(("defectdojo-cleanup", "dd-gate"))
if gate_a is not None and gate_b is not None:
    if gate_a == gate_b:
        ok("DD-GATE-IDENTICAL", "the import and cleanup dd-gate bodies are byte-identical")
    else:
        bad("DD-GATE-IDENTICAL", "the import and cleanup dd-gate bodies differ")

print("extract: {} passed, {} failed".format(passed, failed))
sys.exit(1 if failed else 0)
PY
}

# ─────────────────────────────────────────────────────────────────────────────
# --extract-only
# ─────────────────────────────────────────────────────────────────────────────
mode_extract_only() {
  require_bins yq python3 bash
  local tmp rc=0
  tmp="$(mktemp -d)"
  extract_bodies "$tmp" || rc=$?
  rm -rf "$tmp"
  if [ "$rc" -eq 0 ]; then
    echo "EXTRACT PASS - ${WORKFLOW}"
  else
    echo "EXTRACT FAIL - ${WORKFLOW} (exit ${rc})"
  fi
  exit "$rc"
}

# ─────────────────────────────────────────────────────────────────────────────
# entry: <reports-dir>
# ─────────────────────────────────────────────────────────────────────────────
mode_entry() {
  local reports="$1" missing=() f
  require_bins curl jq yq python3 kind kubectl helm docker openssl
  if [ ! -d "$reports" ]; then
    echo "FATAL: reports directory '${reports}' does not exist" >&2
    exit 2
  fi
  for f in "${REQUIRED_REPORTS[@]}"; do
    if [ ! -f "${reports}/${f}" ]; then
      missing+=("$f")
    fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "FATAL: reports directory '${reports}' is missing: ${missing[*]}" >&2
    exit 2
  fi
  local extract_rc=0
  bash "$SELF" --extract-only || extract_rc=$?
  if [ "$extract_rc" -ne 0 ]; then
    echo "FATAL: --extract-only failed (exit ${extract_rc}); no cluster was created" >&2
    exit "$extract_rc"
  fi
  DD_PROOF_REPORTS="$(cd "$reports" && pwd)"
  DD_SMOKE_POST_HOOK="$SELF"
  export DD_PROOF_REPORTS DD_SMOKE_POST_HOOK
  local smoke_rc=0
  bash scripts/defectdojo-live-smoke.sh || smoke_rc=$?
  exit "$smoke_rc"
}

# ─────────────────────────────────────────────────────────────────────────────
# --hook
# ─────────────────────────────────────────────────────────────────────────────
PROOF_N=0
PROOF_FAILED=0

proof_pass() {
  PROOF_N=$((PROOF_N + 1))
  echo "PROOF: $1 PASS $2"
}
proof_fail() {
  PROOF_N=$((PROOF_N + 1))
  PROOF_FAILED=$((PROOF_FAILED + 1))
  echo "PROOF: $1 FAIL $2"
}

# proof_finish: the terminal verdict. Never PASS in 27-05.
proof_finish() {
  echo
  if [ "$PROOF_FAILED" -gt 0 ]; then
    echo "PROOF FAIL - ${PROOF_FAILED} of ${PROOF_N}"
    exit 1
  fi
  # 27-06: once run 2, the cleanup assertions and the insecure-warning check
  # exist, this branch becomes "PROOF PASS - <n> assertions" with exit 0.
  echo "PROOF INCOMPLETE - run-2 and cleanup assertions pending (27-06)"
  exit 1
}

# proof_abort ID DETAIL: a failure every later assertion depends on.
proof_abort() {
  proof_fail "$1" "$2"
  echo "    aborting: later assertions depend on $1"
  proof_finish
}

# api_call OUTFILE ARGS...: a verified-TLS request against the smoke DefectDojo.
# Prints "<http_code> <ssl_verify_result>"; the curl exit status is returned.
# The resolve entry comes from the curlrc under CURL_HOME.
api_call() {
  local out="$1"
  shift
  curl -sS --cacert "$DD_CA_FILE" -o "$out" -w '%{http_code} %{ssl_verify_result}' "$@"
}

# mint_token USER PWFILE TOKENFILE LABEL: POST /api/v2/api-token-auth/ with a
# JSON body built in a 0600 file, and write the bare token to TOKENFILE (0600).
mint_token() {
  local user="$1" pwfile="$2" tokfile="$3" label="$4"
  local body="${PROOF_DIR}/${label}-auth.json" resp="${PROOF_DIR}/${label}-auth-resp.json"
  jq -n --arg u "$user" --rawfile pw "$pwfile" '{username: $u, password: $pw}' > "$body"
  local rc=0 out
  out="$(api_call "$resp" -X POST -H 'Content-Type: application/json' --data-binary "@${body}" \
    "${BASE_URL}/api/v2/api-token-auth/" 2>"${PROOF_DIR}/${label}-auth.err")" || rc=$?
  rm -f "$body"
  local code="${out%% *}" verify="${out##* }"
  if [ "$rc" -ne 0 ] || [ "$code" != "200" ] || [ "$verify" != "0" ]; then
    MINT_DETAIL="api-token-auth as ${user}: curl exit ${rc}, http ${code:-none}, ssl_verify_result ${verify:-none}: $(head -c 300 "$resp" 2>/dev/null | tr '\n' ' ')$(tr '\n' ' ' < "${PROOF_DIR}/${label}-auth.err")"
    rm -f "$resp"
    return 1
  fi
  jq -j '.token // empty' "$resp" > "$tokfile"
  rm -f "$resp"
  if [ ! -s "$tokfile" ]; then
    MINT_DETAIL="api-token-auth as ${user} returned 200 without a token"
    return 1
  fi
  MINT_DETAIL="api-token-auth as ${user} -> 200 with a token, over verified TLS"
  return 0
}

# run_body LABEL BODYFILE NAME=VALUE...: execute a committed step body the way
# the runner does (`bash -e <file>`), in a fresh working directory, with a
# fresh GITHUB_OUTPUT and exactly the given contract names exported. Values are
# exported inside a subshell with the `export` builtin, so no value (the token
# included) ever reaches an argv. Output goes to $DD_SMOKE_OUT/proof-LABEL.log.
# Sets BODY_RC, BODY_DIR and BODY_OUTPUT.
run_body() {
  local label="$1" body="$2"
  shift 2
  BODY_DIR="$(mktemp -d "${PROOF_DIR}/run-${label}.XXXXXX")"
  BODY_OUTPUT="${BODY_DIR}/github-output"
  : > "$BODY_OUTPUT"
  BODY_LOG="${DD_SMOKE_OUT}/proof-${label}.log"
  BODY_RC=0
  (
    cd "$BODY_DIR"
    export GITHUB_OUTPUT="$BODY_OUTPUT"
    for kv in "$@"; do
      export "${kv?}"
    done
    exec bash -e "$body"
  ) > "$BODY_LOG" 2>&1 || BODY_RC=$?
}

# gate_output: every enabled= line the last run_body wrote to GITHUB_OUTPUT,
# space-joined. Comparing it to "enabled=false" therefore also asserts there
# is exactly one such line. sed, not grep: no match must not be an error.
gate_output() {
  sed -n '/^enabled=/p' "$BODY_OUTPUT" | tr '\n' ' ' | sed 's/ $//'
}

mode_hook() {
  local v
  for v in BASE_URL SMOKE_HOST PF_PORT KIND_CONTEXT ADMIN_USER DD_CA_FILE DD_ADMIN_PW_FILE DD_SMOKE_OUT DD_PROOF_REPORTS; do
    if [ -z "${!v:-}" ]; then
      echo "FATAL: --hook needs ${v} (exported by defectdojo-live-smoke.sh / the entry mode)" >&2
      exit 2
    fi
  done
  require_bins curl jq yq python3
  for v in "$DD_CA_FILE" "$DD_ADMIN_PW_FILE"; do
    if [ ! -s "$v" ]; then
      echo "FATAL: --hook: ${v} is missing or empty" >&2
      exit 2
    fi
  done
  if [ ! -d "$DD_PROOF_REPORTS" ]; then
    echo "FATAL: --hook: DD_PROOF_REPORTS '${DD_PROOF_REPORTS}' is not a directory" >&2
    exit 2
  fi

  # Every file this mode creates (credentials, token header, bodies, results)
  # is private. The smoke's EXIT trap removes $DD_SMOKE_OUT afterwards.
  umask 077
  PROOF_DIR="${DD_SMOKE_OUT}/proof"
  mkdir -p "$PROOF_DIR"
  local bodies="${PROOF_DIR}/bodies"
  mkdir -p "$bodies"

  echo "=== DefectDojo import proof (run 1) against ${BASE_URL} ==="
  # The bodies must be the committed ones, re-checked here: a hook run never
  # executes a body that did not pass the static contract.
  local ex_rc=0
  extract_bodies "$bodies" || ex_rc=$?
  if [ "$ex_rc" -ne 0 ]; then
    proof_abort "P-EXTRACT" "the committed side-channel bodies failed the static contract (exit ${ex_rc})"
  fi
  proof_pass "P-EXTRACT" "six committed side-channel bodies extracted from ${WORKFLOW}"
  local b_gate="${bodies}/defectdojo-import__dd-gate.sh"
  local b_import="${bodies}/defectdojo-import__dd-import.sh"
  local b_verify="${bodies}/defectdojo-import__dd-verify.sh"

  # ── P-TLS ─────────────────────────────────────────────────────────────────
  local curlhome="${DD_SMOKE_OUT}/curlhome"
  mkdir -p "$curlhome"
  printf 'resolve = "%s:%s:127.0.0.1"\n' "$SMOKE_HOST" "$PF_PORT" > "${curlhome}/.curlrc"
  export CURL_HOME="$curlhome"
  if [ "$(wc -l < "${curlhome}/.curlrc" | tr -d ' ')" != "1" ] || grep -qiE 'insecure|(^|[[:space:]])-k' "${curlhome}/.curlrc"; then
    proof_abort "P-TLS" "the curlrc must hold exactly one resolve line and nothing that disables verification"
  fi
  local rc=0 out code verify
  out="$(api_call "${PROOF_DIR}/api-root.json" "${BASE_URL}/api/v2/" 2>"${PROOF_DIR}/api-root.err")" || rc=$?
  code="${out%% *}"
  verify="${out##* }"
  if [ "$rc" -ne 0 ] || [ "$verify" != "0" ] || [ "$code" = "000" ]; then
    proof_abort "P-TLS" "GET ${BASE_URL}/api/v2/ via CURL_HOME resolve: curl exit ${rc} (60 = verification failed), http ${code:-none}, ssl_verify_result ${verify:-none}: $(tr '\n' ' ' < "${PROOF_DIR}/api-root.err")"
  fi
  proof_pass "P-TLS" "GET ${BASE_URL}/api/v2/ -> http ${code}, ssl_verify_result 0 against the kind CA; host resolved by the CURL_HOME curlrc"

  # ── P-ADMIN-TOKEN ─────────────────────────────────────────────────────────
  local admin_tok="${PROOF_DIR}/admin.token" admin_hdr="${PROOF_DIR}/admin.hdr"
  MINT_DETAIL=""
  if ! mint_token "$ADMIN_USER" "$DD_ADMIN_PW_FILE" "$admin_tok" admin; then
    proof_abort "P-ADMIN-TOKEN" "$MINT_DETAIL"
  fi
  { printf 'Authorization: Token '; cat "$admin_tok"; printf '\n'; } > "$admin_hdr"
  rm -f "$admin_tok"
  proof_pass "P-ADMIN-TOKEN" "$MINT_DETAIL"

  # ── P-USER ────────────────────────────────────────────────────────────────
  # gen_secret is alphanumeric only and would be refused (RESEARCH Pitfall
  # 10); the fixed suffix covers every required class: 20 + 4 = 24 chars,
  # inside the 9-48 policy.
  local user_pw="${PROOF_DIR}/importer-pw" user_body="${PROOF_DIR}/importer-user.json"
  printf '%s' "$(gen_secret 20)aA1!" > "$user_pw"
  jq -n --arg u "$PROOF_USER" --rawfile pw "$user_pw" \
    '{username: $u, password: $pw, first_name: "CI", last_name: "Importer",
      email: "ci-importer@example.com", is_active: true, is_staff: true, is_superuser: false}' > "$user_body"
  rc=0
  out="$(api_call "${PROOF_DIR}/user-create.json" -X POST -H "@${admin_hdr}" -H 'Content-Type: application/json' \
    --data-binary "@${user_body}" "${BASE_URL}/api/v2/users/" 2>"${PROOF_DIR}/user-create.err")" || rc=$?
  rm -f "$user_body"
  code="${out%% *}"
  if [ "$rc" -ne 0 ] || [ "$code" != "201" ]; then
    proof_abort "P-USER" "POST /api/v2/users/ ${PROOF_USER}: curl exit ${rc}, http ${code:-none}: $(head -c 400 "${PROOF_DIR}/user-create.json" 2>/dev/null | tr '\n' ' ')"
  fi
  rc=0
  out="$(api_call "${PROOF_DIR}/user-get.json" -G -H "@${admin_hdr}" --data-urlencode "username=${PROOF_USER}" \
    "${BASE_URL}/api/v2/users/" 2>"${PROOF_DIR}/user-get.err")" || rc=$?
  code="${out%% *}"
  local user_state
  user_state="$(jq -r --arg u "$PROOF_USER" \
    '[.results[]? | select(.username == $u)] | if length == 1 then "\(.[0].is_staff) \(.[0].is_superuser)" else "count=\(length)" end' \
    "${PROOF_DIR}/user-get.json" 2>/dev/null || echo "unparseable")"
  if [ "$rc" -ne 0 ] || [ "$code" != "200" ]; then
    proof_abort "P-USER" "GET /api/v2/users/?username=${PROOF_USER}: curl exit ${rc}, http ${code:-none}"
  elif [ "$user_state" != "true false" ]; then
    proof_abort "P-USER" "${PROOF_USER} read back as '${user_state}', expected is_staff=true is_superuser=false"
  fi
  proof_pass "P-USER" "${PROOF_USER} created and read back with is_staff=true, is_superuser=false (the documented minimum, not superuser)"

  # ── P-IMPORTER-TOKEN ──────────────────────────────────────────────────────
  # Every body run below uses THIS token as DD_TOKEN, never the admin token.
  # If DefectDojo refuses it (for example a forced password reset), that is a
  # finding to report, not something to work around.
  local importer_tok="${PROOF_DIR}/importer.token"
  if ! mint_token "$PROOF_USER" "$user_pw" "$importer_tok" importer; then
    proof_abort "P-IMPORTER-TOKEN" "$MINT_DETAIL"
  fi
  proof_pass "P-IMPORTER-TOKEN" "$MINT_DETAIL; all body runs use this token"

  # ── P-GATE ────────────────────────────────────────────────────────────────
  # The committed dd-gate body, three ways (D-02, D-13). GITHUB_ACTOR is set
  # explicitly every time: on a runner it would otherwise be the real actor.
  run_body gate-no-token "$b_gate" "DD_TOKEN=" "GITHUB_ACTOR=proof-actor"
  if [ "$BODY_RC" -eq 0 ] && [ "$(gate_output)" = "enabled=false" ] \
    && grep -q '^SKIP: DEFECTDOJO_API_TOKEN is not available' "$BODY_LOG"; then
    proof_pass "P-GATE" "token absent -> exit 0, enabled=false, SKIP line printed"
  else
    proof_fail "P-GATE" "token absent: exit ${BODY_RC}, output '$(gate_output)'; expected exit 0, enabled=false and the SKIP line (log ${BODY_LOG})"
  fi
  run_body gate-dependabot "$b_gate" "DD_TOKEN=$(cat "$importer_tok")" "GITHUB_ACTOR=dependabot[bot]"
  if [ "$BODY_RC" -eq 0 ] && [ "$(gate_output)" = "enabled=false" ] \
    && grep -q '^SKIP: Dependabot run' "$BODY_LOG"; then
    proof_pass "P-GATE" "Dependabot actor with a token set -> exit 0, enabled=false"
  else
    proof_fail "P-GATE" "Dependabot actor: exit ${BODY_RC}, output '$(gate_output)'; expected exit 0 and enabled=false (log ${BODY_LOG})"
  fi
  run_body gate-enabled "$b_gate" "DD_TOKEN=$(cat "$importer_tok")" "GITHUB_ACTOR=proof-actor"
  if [ "$BODY_RC" -eq 0 ] && [ "$(gate_output)" = "enabled=true" ]; then
    proof_pass "P-GATE" "token present, normal actor -> exit 0, enabled=true"
  else
    proof_abort "P-GATE" "token present: exit ${BODY_RC}, output '$(gate_output)'; expected enabled=true (log ${BODY_LOG})"
  fi

  # ── P-RUN1 ────────────────────────────────────────────────────────────────
  local results1="${PROOF_DIR}/results-run1.json"
  local ca_pem
  ca_pem="$(cat "$DD_CA_FILE")"
  run_body import-run1 "$b_import" \
    "DD_URL=${BASE_URL}" \
    "DD_TOKEN=$(cat "$importer_tok")" \
    "DD_PRODUCT=${PROOF_PRODUCT}" \
    "DD_PRODUCT_TYPE=${PROOF_PRODUCT_TYPE}" \
    "DD_INSECURE=" \
    "DD_CA_CERT=${ca_pem}" \
    "DD_REPORTS_DIR=${DD_PROOF_REPORTS}" \
    "DD_RESULTS_FILE=${results1}" \
    "GITHUB_ACTOR=proof-actor" \
    "GITHUB_EVENT_NAME=pull_request" \
    "GITHUB_HEAD_REF=${PROOF_BRANCH_A}" \
    "GITHUB_REF_NAME=27/merge" \
    "GITHUB_SHA=${PROOF_SHA}" \
    "GITHUB_RUN_ID=${PROOF_RUN_ID}" \
    "GITHUB_SERVER_URL=${PROOF_SERVER_URL}" \
    "GITHUB_REPOSITORY=${PROOF_REPOSITORY}"
  sed -e 's/^/    | /' "$BODY_LOG"
  if [ "$BODY_RC" -ne 0 ] || [ ! -s "$results1" ]; then
    proof_abort "P-RUN1" "committed dd-import body exited ${BODY_RC} (results file present: $([ -s "$results1" ] && echo yes || echo no)); log ${BODY_LOG}"
  fi
  local tls_mode
  tls_mode="$(jq -r '.tls_mode' "$results1" 2>/dev/null)" || tls_mode="unparseable"
  if [ "$tls_mode" != "verified-ca" ] || grep -q '::warning::' "$BODY_LOG"; then
    proof_fail "P-RUN1" "dd-import ran with tls_mode '${tls_mode}' or printed a ::warning:: line; expected verified-ca and no warning"
  else
    proof_pass "P-RUN1" "committed dd-import body exited 0 as ${PROOF_USER}, tls_mode verified-ca, no ::warning::"
  fi
  run_body verify-run1 "$b_verify" "DD_IMPORT_OUTCOME=success" "DD_RESULTS_FILE=${results1}"
  sed -e 's/^/    | /' "$BODY_LOG"
  if [ "$BODY_RC" -eq 0 ]; then
    proof_pass "P-RUN1" "committed dd-verify body exited 0 on the run-1 results"
  else
    proof_fail "P-RUN1" "committed dd-verify body exited ${BODY_RC} (log ${BODY_LOG})"
  fi

  # ── P-CONTEXT / P-TESTS / P-COUNTS ────────────────────────────────────────
  # Read side, admin token. Stdlib Python; curl for transport so the same
  # CURL_HOME resolve entry and --cacert apply. Each assertion is printed as a
  # "PROOF: <ID> PASS|FAIL" line and tallied below.
  local assert_log="${PROOF_DIR}/assert-run1.log" py_rc=0
  PROOF_ADMIN_HDR="$admin_hdr" PROOF_RESULTS="$results1" PROOF_RUN1_OUT="${DD_SMOKE_OUT}/proof-run1.json" \
    PROOF_PRODUCT="$PROOF_PRODUCT" PROOF_PRODUCT_TYPE="$PROOF_PRODUCT_TYPE" \
    PROOF_ENGAGEMENT="ci/${PROOF_BRANCH_A}" PROOF_TMP="$PROOF_DIR" \
    python3 - > "$assert_log" 2>&1 <<'PY' || py_rc=$?
import glob
import json
import os
import re
import subprocess
import sys
import urllib.parse

env = os.environ
base = env["BASE_URL"].rstrip("/")
ca = env["DD_CA_FILE"]
hdr = env["PROOF_ADMIN_HDR"]
reports = env["DD_PROOF_REPORTS"]
want_product = env["PROOF_PRODUCT"]
want_ptype = env["PROOF_PRODUCT_TYPE"]
want_engagement = env["PROOF_ENGAGEMENT"]
resp_path = os.path.join(env["PROOF_TMP"], "assert-response.json")

with open(env["PROOF_RESULTS"], encoding="utf-8") as handle:
    results = json.load(handle)
attempted = results.get("attempted") or []
skipped = results.get("skipped") or []


def say(pid, ok, detail):
    print("PROOF: {} {} {}".format(pid, "PASS" if ok else "FAIL", detail))
    return ok


class ApiError(Exception):
    pass


def get(path, params):
    url = "{}{}?{}".format(base, path, urllib.parse.urlencode(params))
    cmd = ["curl", "-sS", "--cacert", ca, "-H", "@" + hdr, "-o", resp_path,
           "-w", "%{http_code} %{ssl_verify_result}", url]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    code, _, verify = (proc.stdout or "000 -").strip().partition(" ")
    body = ""
    if os.path.isfile(resp_path):
        with open(resp_path, encoding="utf-8", errors="replace") as handle:
            body = handle.read()
        os.remove(resp_path)
    if proc.returncode != 0 or code != "200" or verify != "0":
        raise ApiError("GET {} -> curl exit {}, http {}, ssl_verify_result {}: {}".format(
            path, proc.returncode, code, verify, (body or proc.stderr)[:300]))
    data = json.loads(body)
    if isinstance(data, dict) and data.get("next"):
        raise ApiError("GET {} returned more than one page".format(path))
    return data


# The import table the committed dd-import body uses (security.yml). Titles of
# None are "<prefix>-<N>". Kept here as the EXPECTATION, not as logic that runs.
TABLE = [
    ("semgrep-results.json", "Semgrep JSON Report", "semgrep", "bounded"),
    ("checkov-results.json", "Checkov Scan", "checkov", "exact"),
    ("trivy-fs.json", "Trivy Scan", "trivy-fs", "exact"),
    ("trivy-image.json", "Trivy Scan", "trivy-image", "exact"),
    ("gitleaks-results.json", "Gitleaks Scan", "gitleaks", "bounded"),
    ("npm-audit-*.json", "NPM Audit v7+ Scan", None, "bounded"),
    ("pip-audit-*.json", "pip-audit Scan", None, "exact"),
    ("tflint.sarif", "SARIF", "tflint", "bounded"),
]


def number_of(path):
    match = re.search(r"-(\d+)\.json$", path)
    return int(match.group(1)) if match else 0


expected = {}
for pattern, scan_type, title, kind in TABLE:
    for path in sorted(glob.glob(os.path.join(reports, pattern))):
        name = os.path.basename(path)
        if title is None:
            t = "{}-{}".format(pattern.split("-*")[0], number_of(path))
        else:
            t = title
        expected[name] = {"scan_type": scan_type, "title": t, "kind": kind, "path": path}


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


# Raw artifact counts (RESEARCH Pitfall 6). Exact for parsers that do not
# merge entries; an UPPER BOUND for the ones that do.
def raw_count(name, path):
    data = load(path)
    if name.startswith("checkov"):
        reports_list = data if isinstance(data, list) else [data]
        return sum(len(((r or {}).get("results") or {}).get("failed_checks") or [])
                   for r in reports_list if isinstance(r, dict))
    if name.startswith("trivy"):
        return sum(len((r or {}).get("Vulnerabilities") or [])
                   for r in (data.get("Results") or []) if isinstance(r, dict))
    if name.startswith("pip-audit"):
        deps = data.get("dependencies") if isinstance(data, dict) else data
        return sum(len((d or {}).get("vulns") or []) for d in (deps or []) if isinstance(d, dict))
    if name.startswith("semgrep"):
        return len(data.get("results") or [])
    if name.startswith("gitleaks"):
        return len(data or [])
    if name.startswith("npm-audit"):
        # The v7+ parser can emit one finding per advisory object in a
        # package's `via`, so the upper bound counts those, and 1 for a
        # package whose `via` holds only names (a transitive entry).
        total = 0
        for pkg in (data.get("vulnerabilities") or {}).values():
            vias = [v for v in ((pkg or {}).get("via") or []) if isinstance(v, dict)]
            total += len(vias) if vias else 1
        return total
    if name.endswith(".sarif"):
        return sum(len((run or {}).get("results") or []) for run in (data.get("runs") or []))
    raise ValueError("no raw-count rule for {}".format(name))


failures = 0


def check(pid, ok, detail):
    global failures
    if not say(pid, ok, detail):
        failures += 1


run1 = {"product": want_product, "product_type": want_ptype, "engagement": want_engagement,
        "files": {}}
try:
    # ── P-CONTEXT ──
    ptypes = [p for p in get("/api/v2/product_types/", {"name": want_ptype, "limit": 100})["results"]
              if p.get("name") == want_ptype]
    check("P-CONTEXT", len(ptypes) == 1,
          "product type exactly named {!r}: {} found".format(want_ptype, len(ptypes)))
    products = [p for p in get("/api/v2/products/", {"name_exact": want_product, "limit": 100})["results"]
                if p.get("name") == want_product]
    check("P-CONTEXT", len(products) == 1,
          "product exactly named {!r}: {} found".format(want_product, len(products)))
    if len(ptypes) != 1 or len(products) != 1:
        raise ApiError("product context missing; later assertions depend on it")
    pid = products[0]["id"]
    check("P-CONTEXT", products[0].get("prod_type") == ptypes[0]["id"],
          "product {} is under product type {!r} (id {}), found prod_type {}".format(
              pid, want_ptype, ptypes[0]["id"], products[0].get("prod_type")))
    engs = [e for e in get("/api/v2/engagements/", {"product": pid, "name": want_engagement,
                                                    "limit": 100})["results"]
            if e.get("name") == want_engagement and e.get("product") == pid]
    check("P-CONTEXT", len(engs) == 1,
          "engagement exactly named {!r} in product {}: {} found".format(want_engagement, pid, len(engs)))
    if len(engs) != 1:
        raise ApiError("engagement missing; later assertions depend on it")
    eid = engs[0]["id"]
    mismatched = [r.get("file") for r in attempted
                  if r.get("product_id") != pid or r.get("engagement_id") != eid]
    check("P-CONTEXT", not mismatched,
          "every attempted import reported product {} / engagement {}{}".format(
              pid, eid, "" if not mismatched else "; mismatched: {}".format(mismatched)))
    run1.update({"product_id": pid, "engagement_id": eid})

    # ── P-TESTS ──
    tests = get("/api/v2/tests/", {"engagement": eid, "limit": 100})["results"]
    check("P-TESTS", len(tests) == len(attempted),
          "engagement {} holds {} Test(s); {} report file(s) were attempted".format(
              eid, len(tests), len(attempted)))
    attempted_names = sorted(r.get("file") for r in attempted)
    check("P-TESTS", attempted_names == sorted(expected),
          "attempted files {} == present known report files {}".format(attempted_names, sorted(expected)))
    silently = sorted(s.get("file") for s in skipped if s.get("file") in expected)
    check("P-TESTS", not silently, "no present report file was skipped{}".format(
        "" if not silently else ": {}".format(silently)))
    by_id = {t.get("id"): t for t in tests}
    for r in attempted:
        name = r.get("file")
        want = expected.get(name, {})
        t = by_id.get(r.get("test_id"), {})
        check("P-TESTS",
              t.get("title") == want.get("title") == r.get("test_title")
              and t.get("scan_type") == want.get("scan_type") == r.get("scan_type"),
              "{}: test {} title={!r} scan_type={!r}; expected {!r} / {!r}".format(
                  name, r.get("test_id"), t.get("title"), t.get("scan_type"),
                  want.get("title"), want.get("scan_type")))

    # ── P-COUNTS ──
    print("    file                       raw   imported(after)  findings-api  rule")
    for r in attempted:
        name = r.get("file")
        want = expected.get(name)
        stats = r.get("statistics") if isinstance(r.get("statistics"), dict) else {}
        after = ((stats.get("after") or {}).get("total") or {}).get("total")
        count = get("/api/v2/findings/", {"test": r.get("test_id"), "limit": 1}).get("count")
        raw = raw_count(name, want["path"]) if want else None
        kind = want["kind"] if want else "unknown"
        print("    {:<26} {:>5} {:>17} {:>13}  {}".format(name, str(raw), str(after), str(count), kind))
        # (a) internal consistency: the import's own statistics vs the API.
        check("P-COUNTS", after is not None and after == count,
              "{}: statistics.after.total.total {} == findings?test={} count {}".format(
                  name, after, r.get("test_id"), count))
        # (b) against the artifact.
        if kind == "exact":
            check("P-COUNTS", count == raw,
                  "{}: imported {} == raw {} (exact: parser does not merge)".format(name, count, raw))
        elif raw == 0:
            check("P-COUNTS", count == 0, "{}: imported {} == raw 0".format(name, count))
        else:
            check("P-COUNTS", count is not None and 1 <= count <= raw,
                  "{}: 1 <= imported {} <= raw {} (bounded: parser merges entries)".format(
                      name, count, raw))
        run1["files"][name] = {"test_id": r.get("test_id"), "title": r.get("test_title"),
                               "scan_type": r.get("scan_type"), "after_total": after,
                               "findings_count": count, "raw": raw, "rule": kind}
    run1["test_count"] = len(tests)
except (ApiError, ValueError, KeyError, TypeError) as exc:
    say("P-CONTEXT", False, "read-side assertions aborted: {}".format(exc))
    failures += 1

# Saved for 27-06's run-2 comparison (Pitfall 6 c).
with open(env["PROOF_RUN1_OUT"], "w", encoding="utf-8") as handle:
    json.dump(run1, handle, indent=2)
sys.exit(1 if failures else 0)
PY
  local line id verdict detail
  while IFS= read -r line; do
    if [[ "$line" =~ ^PROOF:\ ([A-Z0-9-]+)\ (PASS|FAIL)\ (.*)$ ]]; then
      id="${BASH_REMATCH[1]}"
      verdict="${BASH_REMATCH[2]}"
      detail="${BASH_REMATCH[3]}"
      if [ "$verdict" = "PASS" ]; then
        proof_pass "$id" "$detail"
      else
        proof_fail "$id" "$detail"
      fi
    else
      echo "$line"
    fi
  done < "$assert_log"
  if [ "$py_rc" -ne 0 ] && [ "$PROOF_FAILED" -eq 0 ]; then
    proof_fail "P-COUNTS" "the read-side assertion script exited ${py_rc} without reporting a failed assertion (see ${assert_log})"
  fi

  # 27-06: run 2 goes here — reimport the same files into ci/proof/branch-a
  #        and compare against $DD_SMOKE_OUT/proof-run1.json (delta.created 0,
  #        after_total unchanged, Test count unchanged).
  # 27-06: cleanup assertions go here — run the committed dd-delete and
  #        dd-cleanup-verify bodies (and the default-branch refusal) as
  #        ci-importer.
  # 27-06: insecure-warning check goes here — assert the ::warning:: marker
  #        with DD_INSECURE=true WITHOUT any network call (the cleanup wording
  #        differs from the import wording, so match the marker, not the
  #        sentence).

  proof_finish
}

# ─────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
  --extract-only)
    [ "$#" -eq 1 ] || usage
    mode_extract_only
    ;;
  --hook)
    [ "$#" -eq 1 ] || usage
    mode_hook
    ;;
  "" | -*)
    usage
    ;;
  *)
    [ "$#" -eq 1 ] || usage
    mode_entry "$1"
    ;;
esac
