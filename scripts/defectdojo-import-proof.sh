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
#   --scheme-only   offline, no cluster, no network: P-HTTP and
#                   P-CONFIGURE-GUARD only. Extracts and runs the committed
#                   dd-import and dd-delete bodies with a non-https
#                   DEFECTDOJO_URL and asserts they refuse before any request
#                   (27-11, CR-01). Also runs scripts/defectdojo-configure.sh
#                   with a dummy token offline: its non-https refusal (P-HTTP)
#                   and its preflight guards (P-CONFIGURE-GUARD, 28-02).
#   --hook          live, called by the smoke: mint tokens, run the committed
#                   bodies, assert run 1, the in-place reimport (run 2), the
#                   schedule path, a hostile head ref, product-scoped cleanup,
#                   the cleanup refusals and no-match no-op, and the
#                   insecure-TLS warning and the non-https refusal
#                   (P-HTTP). Prints one
#                   "PROOF: <ID> PASS|FAIL <detail>" line per assertion and
#                   ends with "PROOF PASS - <n> assertions" or
#                   "PROOF FAIL - <k> of <n>".
#
# DD_PROOF_WORKFLOW overrides the workflow path (scratch-copy self-tests only).
#
# Assertion groups (D-20): P-EXTRACT P-TLS P-ADMIN-TOKEN P-USER
# P-IMPORTER-TOKEN P-GATE P-RUN1 P-CONTEXT P-TESTS P-COUNTS (run 1, 27-05);
# P-RUN2 P-SCHEDULE P-HOSTILE P-SCOPE P-CLEANUP P-REFUSE P-NOMATCH P-INSECURE
# (27-06); P-HTTP (27-11, CR-01); P-CONFIGURE-GUARD (28-02); P-CONFIGURE
# P-IDEMPOTENT P-DEDUP-MODE P-DEDUP-BRANCH P-CROSSTOOL (28-03, --hook only,
# after every Phase 27 assertion). Every body run uses the ci-importer token;
# the offline configure-script cases use a gen_secret dummy token and never
# reach the network; the live configure runs (P-CONFIGURE, P-IDEMPOTENT) use
# the admin (superuser) token from a 0600 file, as the script requires.
#
# Credentials are generated or read at runtime, written only to 0600 files,
# sent with `--data-binary @file` or `-H @file`, never placed on any argv and
# never echoed. xtrace is never enabled anywhere in this script.
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/defectdojo-import-proof.sh <reports-dir>
#   bash scripts/defectdojo-import-proof.sh --extract-only
#   bash scripts/defectdojo-import-proof.sh --scheme-only
#
# Exit codes:
#   0  --extract-only: every static check passed; --hook: every proof
#      assertion passed
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

# Run 2 and cleanup identities (27-06). The hostile head ref is a LITERAL
# (single quotes): it must reach the committed bodies unchanged, and the
# proof asserts nothing ever executes it. It is only ever passed as a quoted
# expansion into an exported environment value or a Python env dict.
readonly PROOF_DEFAULT_BRANCH="main"
readonly PROOF_OTHER_PRODUCT="proof/other-product"
# shellcheck disable=SC2016  # the $( ) is the point: it must stay literal
readonly PROOF_HOSTILE_REF='@dd-proof/$(touch pwned)'
readonly PROOF_NOMATCH_REF="never/existed"

# Phase 28 identities (28-03, D-11). Every dedup and triage scenario runs in a
# FRESH product (RESEARCH OQ4), after all Phase 27 assertions, so turning
# deduplication on cannot disturb P-COUNTS and the scenarios cannot disturb
# each other: proof/dedup holds main-first (P-DEDUP-BRANCH, P-CROSSTOOL and the
# 28-04 dispositions), proof/dedup-reparent the reverse PR-first order
# (28-04 P-REPARENT). The PR branch names contain a slash on purpose.
readonly PROOF_DEDUP_PRODUCT="proof/dedup"
readonly PROOF_REPARENT_PRODUCT="proof/dedup-reparent"
readonly PROOF_DEDUP_PR="proof/pr-delta"
readonly PROOF_SUPPRESS_PR="proof/pr-suppress"
readonly PROOF_REPARENT_PR="proof/pr-first"

usage() {
  echo "usage: bash scripts/defectdojo-import-proof.sh <reports-dir> | --extract-only | --scheme-only | --hook" >&2
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

# proof_finish: the terminal verdict.
proof_finish() {
  echo
  if [ "$PROOF_FAILED" -gt 0 ]; then
    echo "PROOF FAIL - ${PROOF_FAILED} of ${PROOF_N}"
    exit 1
  fi
  echo "PROOF PASS - ${PROOF_N} assertions"
  exit 0
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

# tally_assert_log FILE: relay every "PROOF: <ID> PASS|FAIL <detail>" line a
# read-side Python script wrote into the harness tally; other lines are
# printed as they are.
tally_assert_log() {
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
  done < "$1"
}

# write_read_py PATH: the read-side lookup script used after run 1 (admin
# token, --cacert, the CURL_HOME resolve entry). Inputs come from the
# environment only, so a hostile engagement name is never part of any shell
# string. Modes:
#   engagements       READ_PRODUCT, READ_ENGAGEMENT -> JSON
#                     {"product_id": <id|null>, "engagements": [{"id", "tests"}]}
#                     (exact product name, then exact engagement name inside it)
#   engagement-total  -> JSON {"count": <engagements on the whole instance>}
write_read_py() {
  cat > "$1" <<'PY'
import json
import os
import subprocess
import sys
import urllib.parse

env = os.environ
base = env["BASE_URL"].rstrip("/")
ca = env["DD_CA_FILE"]
hdr = env["PROOF_ADMIN_HDR"]
resp_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "read-response.json")


def get(path, params, count_only=False):
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
        sys.exit("GET {} -> curl exit {}, http {}, ssl_verify_result {}: {}".format(
            path, proc.returncode, code, verify, (body or proc.stderr)[:300]))
    data = json.loads(body)
    if not count_only and isinstance(data, dict) and data.get("next"):
        sys.exit("GET {} returned more than one page".format(path))
    return data


mode = sys.argv[1] if len(sys.argv) > 1 else ""
if mode == "engagements":
    product, name = env["READ_PRODUCT"], env["READ_ENGAGEMENT"]
    products = [p for p in get("/api/v2/products/", {"name_exact": product, "limit": 100})["results"]
                if p.get("name") == product]
    if len(products) > 1:
        sys.exit("{} products exactly named {!r}".format(len(products), product))
    out = {"product_id": None, "engagements": []}
    if products:
        pid = products[0]["id"]
        out["product_id"] = pid
        for e in get("/api/v2/engagements/", {"product": pid, "name": name, "limit": 100})["results"]:
            if e.get("name") == name and e.get("product") == pid:
                tests = get("/api/v2/tests/", {"engagement": e["id"], "limit": 1}, count_only=True).get("count")
                out["engagements"].append({"id": e["id"], "tests": tests})
    print(json.dumps(out))
elif mode == "engagement-total":
    print(json.dumps({"count": get("/api/v2/engagements/", {"limit": 1}, count_only=True).get("count")}))
else:
    sys.exit("unknown read mode {!r}".format(mode))
PY
}

# read_engagements PRODUCT NAME: exact-name engagements of NAME inside the
# product exactly named PRODUCT. Sets READ_N (match count, or "error"),
# READ_TESTS (Test count of the first match, or "none") and READ_ERR.
read_engagements() {
  local out="${PROOF_DIR}/read-engagements.json" rc=0
  READ_PRODUCT="$1" READ_ENGAGEMENT="$2" python3 "$PROOF_READ_PY" engagements \
    > "$out" 2> "${out}.err" || rc=$?
  if [ "$rc" -ne 0 ]; then
    READ_N="error"
    READ_TESTS="none"
    READ_ERR="(read-side lookup failed: $(head -c 300 "${out}.err" | tr '\n' ' '))"
    return 0
  fi
  READ_N="$(jq -r '.engagements | length' "$out")"
  READ_TESTS="$(jq -r '.engagements[0].tests // "none"' "$out")"
  READ_ERR=""
}

# read_engagement_total: prints the instance-wide engagement count, or
# "error".
read_engagement_total() {
  local out="${PROOF_DIR}/read-total.json"
  if python3 "$PROOF_READ_PY" engagement-total > "$out" 2> "${out}.err"; then
    jq -r '.count' "$out"
  else
    echo "error"
  fi
}

# prove_http_refusal BODIES_DIR REPORTS_DIR: P-HTTP (27-11, CR-01). Runs the
# COMMITTED dd-import and dd-delete bodies (extract_bodies output, never a
# copy) with a non-https DEFECTDOJO_URL and asserts each one refuses before
# anything else: exit 1, the "must be https://" line, no "TLS mode:" line (so
# no false verified-system label), no "http=" line (no request was reported),
# no results file, and the dummy token never in the log. REPORTS_DIR must be
# POPULATED so an unrefused import would attempt requests; an empty dir would
# make "no request" vacuous. Nothing listens on port 9. The token is a
# gen_secret dummy, never a real credential. Emits one P-HTTP line per
# sub-case through proof_pass/proof_fail and never aborts.
#
# It also covers scripts/defectdojo-configure.sh (28-02), the System Settings
# bootstrap, run the same way (run_body, exported env, the same dummy token
# written to a 0600 file under $PROOF_DIR, never on argv): P-HTTP for an
# http:// and a scheme-less DEFECTDOJO_URL (exit 1, "must be https://"), and
# P-CONFIGURE-GUARD for an empty DEFECTDOJO_ADMIN_TOKEN_FILE and a
# group-readable (0644) token file (exit 2, a FATAL line, no request).
prove_http_refusal() {
  local bodies="$1" reports="$2"
  local b_import="${bodies}/defectdojo-import__dd-import.sh"
  local b_delete="${bodies}/defectdojo-cleanup__dd-delete.sh"
  local tok label case_url res why
  tok="p27http$(gen_secret 24)"

  echo
  echo "=== non-https DEFECTDOJO_URL is refused before any request (P-HTTP) ==="
  for label in import-http import-noscheme delete-http; do
    case "$label" in
      import-noscheme) case_url="127.0.0.1:9" ;;
      *) case_url="http://127.0.0.1:9" ;;
    esac
    res="${PROOF_DIR}/results-${label}.json"
    rm -f "$res"
    if [ "$label" = "delete-http" ]; then
      run_body "$label" "$b_delete" \
        "DD_URL=${case_url}" \
        "DD_TOKEN=${tok}" \
        "DD_PRODUCT=${PROOF_PRODUCT}" \
        "DD_INSECURE=" \
        "DD_CA_CERT=" \
        "DD_DEFAULT_BRANCH=${PROOF_DEFAULT_BRANCH}" \
        "DD_CLEANUP_RESULT_FILE=${res}" \
        "GITHUB_HEAD_REF=${PROOF_BRANCH_A}"
    else
      run_body "$label" "$b_import" \
        "DD_URL=${case_url}" \
        "DD_TOKEN=${tok}" \
        "DD_PRODUCT=${PROOF_PRODUCT}" \
        "DD_PRODUCT_TYPE=${PROOF_PRODUCT_TYPE}" \
        "DD_INSECURE=" \
        "DD_CA_CERT=" \
        "DD_REPORTS_DIR=${reports}" \
        "DD_RESULTS_FILE=${res}" \
        "GITHUB_ACTOR=proof-actor" \
        "GITHUB_EVENT_NAME=pull_request" \
        "GITHUB_HEAD_REF=${PROOF_BRANCH_A}" \
        "GITHUB_REF_NAME=27/merge" \
        "GITHUB_SHA=${PROOF_SHA}" \
        "GITHUB_RUN_ID=${PROOF_RUN_ID}" \
        "GITHUB_SERVER_URL=${PROOF_SERVER_URL}" \
        "GITHUB_REPOSITORY=${PROOF_REPOSITORY}"
    fi
    # The token must not reach the terminal either: mask it before echoing.
    sed -e "s/${tok}/<dummy-token>/g" -e 's/^/    | /' "$BODY_LOG"
    why=""
    [ "$BODY_RC" -eq 1 ] || why="${why} exit ${BODY_RC} (expected 1);"
    grep -q 'must be https://' "$BODY_LOG" || why="${why} no 'must be https://' refusal line;"
    if grep -q 'TLS mode:' "$BODY_LOG"; then why="${why} a 'TLS mode:' line was printed;"; fi
    if grep -q 'http=' "$BODY_LOG"; then why="${why} an 'http=' request line was printed;"; fi
    if [ -e "$res" ]; then why="${why} results file ${res##*/} was written;"; fi
    if grep -qF -- "$tok" "$BODY_LOG"; then why="${why} the dummy token appears in the log;"; fi
    if [ -z "$why" ]; then
      proof_pass "P-HTTP" "${label}: DD_URL=${case_url} -> exit 1, refused before the TLS label, no request, no results file, token absent"
    else
      proof_fail "P-HTTP" "${label}: DD_URL=${case_url}:${why}"
    fi
  done

  # scripts/defectdojo-configure.sh (28-02): the same dummy token, in a 0600
  # file (printf into the file, never on argv), plus a 0644 copy for the
  # loose-permissions guard. DEFECTDOJO_CA_FILE is exported empty so nothing
  # from the caller's environment leaks in.
  local b_configure="${REPO_ROOT}/scripts/defectdojo-configure.sh"
  local tokfile="${PROOF_DIR}/configure-dummy.token"
  local loosefile="${PROOF_DIR}/configure-dummy-loose.token"
  rm -f "$tokfile" "$loosefile"
  printf '%s' "$tok" > "$tokfile"
  chmod 600 "$tokfile"
  cp "$tokfile" "$loosefile"
  chmod 644 "$loosefile"

  echo
  echo "=== defectdojo-configure.sh refuses a non-https URL and fails its preflight guards offline (P-HTTP, P-CONFIGURE-GUARD) ==="
  for label in configure-http configure-noscheme configure-no-env configure-loose-perms; do
    case "$label" in
      configure-http)
        case_url="http://127.0.0.1:9"
        run_body "$label" "$b_configure" \
          "DEFECTDOJO_URL=${case_url}" \
          "DEFECTDOJO_ADMIN_TOKEN_FILE=${tokfile}" \
          "DEFECTDOJO_CA_FILE="
        ;;
      configure-noscheme)
        case_url="127.0.0.1:9"
        run_body "$label" "$b_configure" \
          "DEFECTDOJO_URL=${case_url}" \
          "DEFECTDOJO_ADMIN_TOKEN_FILE=${tokfile}" \
          "DEFECTDOJO_CA_FILE="
        ;;
      configure-no-env)
        case_url="https://127.0.0.1:9"
        run_body "$label" "$b_configure" \
          "DEFECTDOJO_URL=${case_url}" \
          "DEFECTDOJO_ADMIN_TOKEN_FILE=" \
          "DEFECTDOJO_CA_FILE="
        ;;
      configure-loose-perms)
        case_url="https://127.0.0.1:9"
        run_body "$label" "$b_configure" \
          "DEFECTDOJO_URL=${case_url}" \
          "DEFECTDOJO_ADMIN_TOKEN_FILE=${loosefile}" \
          "DEFECTDOJO_CA_FILE="
        ;;
    esac
    sed -e "s/${tok}/<dummy-token>/g" -e 's/^/    | /' "$BODY_LOG"
    why=""
    if grep -q 'http=' "$BODY_LOG"; then why="${why} an 'http=' request line was printed;"; fi
    if grep -qF -- "$tok" "$BODY_LOG"; then why="${why} the dummy token appears in the log;"; fi
    case "$label" in
      configure-http|configure-noscheme)
        [ "$BODY_RC" -eq 1 ] || why="${why} exit ${BODY_RC} (expected 1);"
        grep -q 'must be https://' "$BODY_LOG" || why="${why} no 'must be https://' refusal line;"
        if grep -qE '^(NO CHANGE|CHANGED:)' "$BODY_LOG"; then why="${why} a NO CHANGE/CHANGED: line was printed;"; fi
        if [ -z "$why" ]; then
          proof_pass "P-HTTP" "${label}: DEFECTDOJO_URL=${case_url} -> exit 1, refused before the token file is read, no request, token absent"
        else
          proof_fail "P-HTTP" "${label}: DEFECTDOJO_URL=${case_url}:${why}"
        fi
        ;;
      configure-no-env)
        [ "$BODY_RC" -eq 2 ] || why="${why} exit ${BODY_RC} (expected 2);"
        grep -q '^FATAL: DEFECTDOJO_ADMIN_TOKEN_FILE' "$BODY_LOG" || why="${why} no FATAL line naming DEFECTDOJO_ADMIN_TOKEN_FILE;"
        if [ -z "$why" ]; then
          proof_pass "P-CONFIGURE-GUARD" "${label}: empty DEFECTDOJO_ADMIN_TOKEN_FILE -> exit 2, FATAL names the variable, no request"
        else
          proof_fail "P-CONFIGURE-GUARD" "${label}:${why}"
        fi
        ;;
      configure-loose-perms)
        [ "$BODY_RC" -eq 2 ] || why="${why} exit ${BODY_RC} (expected 2);"
        grep -F -- "$loosefile" "$BODY_LOG" | grep -q '^FATAL:' || why="${why} no FATAL line naming the token file path;"
        if [ -z "$why" ]; then
          proof_pass "P-CONFIGURE-GUARD" "${label}: 0644 token file -> exit 2, FATAL names the path, no request, token absent"
        else
          proof_fail "P-CONFIGURE-GUARD" "${label}:${why}"
        fi
        ;;
    esac
  done
  rm -f "$tokfile" "$loosefile"
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 28 (28-03): dedup and triage helpers, --hook only
# ─────────────────────────────────────────────────────────────────────────────

# write_dedup_py PATH: the Phase 28 read-side script (admin token, --cacert,
# the CURL_HOME resolve entry; the same transport as write_read_py). Inputs
# come from the environment only. Unlike write_read_py it pages list reads
# with an explicit limit=250&offset=N until it holds `count` rows, and never
# follows the returned `next` URL. It never defaults a missing field: a
# finding without one of the keys below is a contradiction of RESEARCH and
# exits non-zero naming the missing and the present keys. Modes:
#   settings        -> GET /api/v2/system_settings/ results[0] as JSON
#                      (exactly one row, else exit non-zero)
#   snapshot        SNAP_PRODUCT, SNAP_ENGAGEMENT -> JSON {"engagement_id",
#                      "tests": {"<id>": {"title", "scan_type"}},
#                      "findings": [...]} for the exact-name engagement in the
#                      exact-name product. Findings are read with
#                      test__engagement=<id>, and every one must belong to a
#                      Test of that engagement (an ignored filter would
#                      otherwise return the whole instance silently).
#   findings-by-id  SNAP_IDS (comma-separated) -> JSON {"<id>": finding + the
#                      finding's test "engagement", "scan_type", "test_title"},
#                      to resolve duplicate_finding targets.
write_dedup_py() {
  cat > "$1" <<'PY'
import json
import os
import subprocess
import sys
import urllib.parse

env = os.environ
base = env["BASE_URL"].rstrip("/")
ca = env["DD_CA_FILE"]
hdr = env["PROOF_ADMIN_HDR"]
resp_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "dedup-response-{}.json".format(os.getpid()))
PAGE = 250
FIELDS = ["id", "test", "title", "active", "verified", "duplicate", "duplicate_finding", "false_p",
          "out_of_scope", "risk_accepted", "is_mitigated", "mitigated", "component_name",
          "component_version", "vulnerability_ids"]


def get(path, params=None):
    url = base + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
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
        sys.exit("GET {} -> curl exit {}, http {}, ssl_verify_result {}: {}".format(
            path, proc.returncode, code, verify, (body or proc.stderr)[:300]))
    try:
        return json.loads(body)
    except ValueError:
        sys.exit("GET {} -> http 200 but the body is not JSON: {}".format(path, body[:300]))


def get_all(path, params):
    rows, offset, count = [], 0, None
    while True:
        data = get(path, dict(params, limit=PAGE, offset=offset))
        if (not isinstance(data, dict) or not isinstance(data.get("results"), list)
                or not isinstance(data.get("count"), int)):
            sys.exit("GET {} offset {}: expected a paged object with count and results".format(path, offset))
        if count is None:
            count = data["count"]
        elif data["count"] != count:
            sys.exit("GET {}: count changed from {} to {} while paging".format(path, count, data["count"]))
        page = data["results"]
        rows.extend(page)
        if len(rows) >= count:
            break
        if not page:
            sys.exit("GET {}: empty page at offset {} with {} of {} rows read".format(path, offset, len(rows), count))
        offset += len(page)
    if len(rows) != count:
        sys.exit("GET {}: read {} rows, count says {}".format(path, len(rows), count))
    return rows


def is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def slim(f):
    if not isinstance(f, dict):
        sys.exit("a finding is not an object: {!r}".format(f)[:300])
    missing = [k for k in FIELDS if k not in f]
    if missing:
        sys.exit("finding {} lacks {}; keys present: {}".format(f.get("id"), missing, sorted(f)))
    if not is_int(f["test"]):
        sys.exit("finding {}: test is {!r}, expected an integer id".format(f["id"], f["test"]))
    raw = f["vulnerability_ids"]
    if not isinstance(raw, list):
        sys.exit("finding {}: vulnerability_ids is {!r}, expected a list".format(f["id"], raw))
    vids = []
    for item in raw:
        if isinstance(item, dict) and isinstance(item.get("vulnerability_id"), str):
            vids.append(item["vulnerability_id"])
        elif isinstance(item, str):
            vids.append(item)
        else:
            sys.exit("finding {}: unexpected vulnerability_ids entry {!r}".format(f["id"], item))
    out = {k: f[k] for k in FIELDS}
    out["vulnerability_ids"] = vids
    return out


mode = sys.argv[1] if len(sys.argv) > 1 else ""
if mode == "settings":
    data = get("/api/v2/system_settings/")
    rows = data.get("results") if isinstance(data, dict) else None
    if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict):
        sys.exit("GET /api/v2/system_settings/: expected exactly one results row: {}".format(json.dumps(data)[:300]))
    print(json.dumps(rows[0]))
elif mode == "snapshot":
    product, name = env["SNAP_PRODUCT"], env["SNAP_ENGAGEMENT"]
    products = [p for p in get_all("/api/v2/products/", {"name_exact": product}) if p.get("name") == product]
    if len(products) != 1:
        sys.exit("{} products exactly named {!r}, expected 1".format(len(products), product))
    pid = products[0]["id"]
    engs = [e for e in get_all("/api/v2/engagements/", {"product": pid, "name": name})
            if e.get("name") == name and e.get("product") == pid]
    if len(engs) != 1:
        sys.exit("{} engagements exactly named {!r} in product {}, expected 1".format(len(engs), name, pid))
    eid = engs[0]["id"]
    tests = {}
    for t in get_all("/api/v2/tests/", {"engagement": eid}):
        if t.get("engagement") != eid:
            sys.exit("GET /api/v2/tests/?engagement={} returned test {} of engagement {}".format(
                eid, t.get("id"), t.get("engagement")))
        tests[str(t["id"])] = {"title": t.get("title"), "scan_type": t.get("scan_type")}
    findings = []
    for f in get_all("/api/v2/findings/", {"test__engagement": eid}):
        s = slim(f)
        if str(s["test"]) not in tests:
            sys.exit("GET /api/v2/findings/?test__engagement={} returned finding {} of test {}, which is not "
                     "a Test of that engagement (tests {}); the filter was not applied".format(
                         eid, s["id"], s["test"], sorted(tests)))
        findings.append(s)
    print(json.dumps({"product_id": pid, "engagement_id": eid, "tests": tests, "findings": findings}))
elif mode == "findings-by-id":
    out = {}
    for raw_id in [x.strip() for x in env.get("SNAP_IDS", "").split(",") if x.strip()]:
        s = slim(get("/api/v2/findings/{}/".format(int(raw_id))))
        t = get("/api/v2/tests/{}/".format(s["test"]))
        if not isinstance(t, dict) or not is_int(t.get("engagement")):
            sys.exit("test {} of finding {} has no integer engagement: {}".format(s["test"], s["id"], json.dumps(t)[:300]))
        s.update({"engagement": t["engagement"], "scan_type": t.get("scan_type"), "test_title": t.get("title")})
        out[str(s["id"])] = s
    print(json.dumps(out))
else:
    sys.exit("unknown dedup read mode {!r}".format(mode))
PY
}

# snippet FILE...: up to 300 bytes of the FILEs, newlines flattened. Never
# fails (a missing file is skipped), so it is safe inside an assignment under
# set -e.
snippet() {
  cat "$@" 2>/dev/null | head -c 300 | tr '\n' ' ' || true
}

# read_settings OUTFILE: System Settings row into OUTFILE (stderr into
# OUTFILE.err). Returns the script's exit status.
read_settings() {
  python3 "$PROOF_DEDUP_PY" settings > "$1" 2> "${1}.err"
}

# snapshot_engagement PRODUCT ENGAGEMENT OUTFILE: the `snapshot` mode into
# OUTFILE (stderr into OUTFILE.err). Returns the script's exit status.
snapshot_engagement() {
  SNAP_PRODUCT="$1" SNAP_ENGAGEMENT="$2" python3 "$PROOF_DEDUP_PY" snapshot > "$3" 2> "${3}.err"
}

# print_masked FILE SECRET: print FILE indented, with every occurrence of
# SECRET replaced by <admin-token>. Bash builtins only (read, printf and
# parameter expansion), so the secret never reaches any process argv (the
# sed idiom used for the dummy token would put it on sed's argv).
print_masked() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    printf '    | %s\n' "${line//"$2"/<admin-token>}"
  done < "$1"
}

# import_as_branch LABEL PRODUCT BRANCH REPORTS_DIR RESULTS_FILE: run the
# COMMITTED dd-import body (T-27-01) with the P-RUN1 env list and the
# ci-importer token. BRANCH equal to PROOF_DEFAULT_BRANCH takes the schedule
# form (empty GITHUB_HEAD_REF, GITHUB_REF_NAME=main -> ci/main); any other
# BRANCH takes the pull_request form (GITHUB_HEAD_REF=BRANCH,
# GITHUB_REF_NAME=28/merge -> ci/BRANCH). Reads three variables that
# prove_dedup_triage sets and never re-extracts anything:
#   DEDUP_B_IMPORT      path of the extracted, checked dd-import body
#   DEDUP_IMPORTER_TOK  path of the ci-importer token file
#   DEDUP_CA_PEM        the kind CA as PEM text (DD_CA_CERT)
# Prints the body log indented and leaves BODY_RC / BODY_LOG to the caller.
import_as_branch() {
  local label="$1" product="$2" branch="$3" reports="$4" results="$5"
  local event head ref
  if [ "$branch" = "$PROOF_DEFAULT_BRANCH" ]; then
    event="schedule"
    head=""
    ref="$PROOF_DEFAULT_BRANCH"
  else
    event="pull_request"
    head="$branch"
    ref="28/merge"
  fi
  echo "    import ${label}: ${product} / ci/${branch} (${event}) from ${reports##*/}"
  run_body "$label" "$DEDUP_B_IMPORT" \
    "DD_URL=${BASE_URL}" \
    "DD_TOKEN=$(cat "$DEDUP_IMPORTER_TOK")" \
    "DD_PRODUCT=${product}" \
    "DD_PRODUCT_TYPE=${PROOF_PRODUCT_TYPE}" \
    "DD_INSECURE=" \
    "DD_CA_CERT=${DEDUP_CA_PEM}" \
    "DD_REPORTS_DIR=${reports}" \
    "DD_RESULTS_FILE=${results}" \
    "GITHUB_ACTOR=proof-actor" \
    "GITHUB_EVENT_NAME=${event}" \
    "GITHUB_HEAD_REF=${head}" \
    "GITHUB_REF_NAME=${ref}" \
    "GITHUB_SHA=${PROOF_SHA}" \
    "GITHUB_RUN_ID=${PROOF_RUN_ID}" \
    "GITHUB_SERVER_URL=${PROOF_SERVER_URL}" \
    "GITHUB_REPOSITORY=${PROOF_REPOSITORY}"
  sed -e 's/^/    | /' "$BODY_LOG"
}

# wait_dedup_settled PRODUCT ENGAGEMENT: belt-and-braces for RESEARCH
# Pitfall 3 (async_wait is the primary measure). Snapshots the engagement
# until its duplicate/total finding counts are unchanged across two
# consecutive snapshots 5 s apart, or 120 s have passed. Prints the elapsed
# seconds and the final counts; never fails by itself (the assertions do).
wait_dedup_settled() {
  local product="$1" engagement="$2" snap="${PROOF_DIR}/settle.json"
  local start now prev="" cur rc
  start="$(date +%s)"
  while :; do
    rc=0
    snapshot_engagement "$product" "$engagement" "$snap" || rc=$?
    if [ "$rc" -eq 0 ]; then
      cur="$(jq -r '"\([.findings[] | select(.duplicate == true)] | length) duplicate of \(.findings | length)"' "$snap")" || cur="error"
    else
      cur="error"
    fi
    now="$(date +%s)"
    if [ "$cur" != "error" ] && [ "$cur" = "$prev" ]; then
      echo "    dedup settled after $((now - start)) s: ${cur} findings in ${product} / ${engagement} (unchanged across two snapshots 5 s apart)"
      return 0
    fi
    if [ $((now - start)) -ge 120 ]; then
      echo "    dedup settle poll stopped at $((now - start)) s: last ${cur} findings in ${product} / ${engagement}$([ "$cur" = "error" ] && printf ' (%s)' "$(head -c 300 "${snap}.err" | tr '\n' ' ')")"
      return 0
    fi
    prev="$cur"
    sleep 5
  done
}

# read_contact_info USER_ID ADMIN_HDR: the user_contact_infos row(s) of
# USER_ID, selected CLIENT-SIDE by .user (an ignored ?user= filter would
# otherwise return every row). Sets CONTACT_N (row count, or "error"),
# CONTACT_ROW_ID, CONTACT_MODE (deduplication_execution_mode of the first
# row) and CONTACT_ERR.
read_contact_info() {
  local uid="$1" hdr="$2" out="${PROOF_DIR}/contact-get.json" rc=0 res code sel
  CONTACT_N="error"
  CONTACT_ROW_ID=""
  CONTACT_MODE=""
  CONTACT_ERR=""
  res="$(api_call "$out" -G -H "@${hdr}" --data-urlencode "user=${uid}" --data-urlencode "limit=100" \
    "${BASE_URL}/api/v2/user_contact_infos/" 2>"${out}.err")" || rc=$?
  code="${res%% *}"
  if [ "$rc" -ne 0 ] || [ "$code" != "200" ]; then
    CONTACT_ERR="GET /api/v2/user_contact_infos/?user=${uid}: curl exit ${rc}, http ${code:-none}: $(snippet "$out" "${out}.err")"
    return 0
  fi
  sel="$(jq -r --argjson id "$uid" \
    'if .next != null then "paged" else ([.results[] | select(.user == $id)] | "\(length) \(.[0].id // "-") \(.[0].deduplication_execution_mode // "-")") end' \
    "$out" 2>/dev/null)" || sel="unparseable"
  case "$sel" in
    paged | unparseable)
      CONTACT_ERR="GET /api/v2/user_contact_infos/?user=${uid}: response ${sel}: $(snippet "$out")"
      return 0
      ;;
  esac
  read -r CONTACT_N CONTACT_ROW_ID CONTACT_MODE <<< "$sel"
}

# prove_dedup_triage BODIES_DIR ADMIN_HDR IMPORTER_TOK CA_PEM: the Phase 28
# live block (28-03; 28-04 adds the second half). Runs after every Phase 27
# assertion, in fresh products. Every import and delete goes through the
# COMMITTED security.yml bodies (run_body, ci-importer token, T-27-01). The
# admin (superuser) token is used only for scripts/defectdojo-configure.sh
# (which requires a superuser), the user_contact_infos write and reads.
prove_dedup_triage() {
  local bodies="$1" admin_hdr="$2"
  DEDUP_B_IMPORT="${bodies}/defectdojo-import__dd-import.sh"
  DEDUP_IMPORTER_TOK="$3"
  DEDUP_CA_PEM="$4"
  PROOF_ADMIN_HDR="$admin_hdr"
  PROOF_DEDUP_PY="${PROOF_DIR}/dedup.py"
  # Readonly names cannot be passed as command-prefix assignments (see the
  # P-CONTEXT comment), so the ones the Python heredocs read are exported.
  export PROOF_ADMIN_HDR PROOF_DEDUP_PY PROOF_DEFAULT_BRANCH
  export PROOF_DEDUP_PRODUCT PROOF_REPARENT_PRODUCT PROOF_DEDUP_PR PROOF_SUPPRESS_PR PROOF_REPARENT_PR
  write_dedup_py "$PROOF_DEDUP_PY"

  echo
  echo "=== Phase 28: dedup and triage (fresh products) ==="

  # ── P-CONFIGURE (D-10, D-21, D-22) ────────────────────────────────────────
  # The committed bootstrap, from the repository path, with the admin token.
  # The script wants the BARE token in a 0600 file: derive it from admin.hdr
  # with sed (the file content never reaches an argv), and remove it after
  # P-IDEMPOTENT or on any abort.
  echo
  echo "=== bootstrap: scripts/defectdojo-configure.sh with the admin token (P-CONFIGURE) ==="
  local pre="${PROOF_DIR}/settings-pre.json" post="${PROOF_DIR}/settings-post.json" rc=0 why
  read_settings "$pre" || rc=$?
  if [ "$rc" -ne 0 ]; then
    proof_abort "P-CONFIGURE" "System Settings read before the bootstrap failed: $(head -c 300 "${pre}.err" | tr '\n' ' ')"
  fi
  echo "    before: $(jq -c '{enable_deduplication, delete_duplicates, false_positive_history, retroactive_false_positive_history, risk_acceptance_form_default_days, enable_finding_sla}' "$pre")"
  local bare="${PROOF_DIR}/admin-bare.token" admin_token
  rm -f "$bare"
  sed -n 's/^Authorization: Token //p' "$admin_hdr" > "$bare"
  chmod 600 "$bare"
  if [ ! -s "$bare" ] || [ "$(wc -l < "$bare" | tr -d ' ')" != "1" ] || grep -q '^$' "$bare"; then
    rm -f "$bare"
    proof_abort "P-CONFIGURE" "could not derive exactly one non-empty bare token line from admin.hdr"
  fi
  admin_token="$(cat "$bare")"
  local b_configure="${REPO_ROOT}/scripts/defectdojo-configure.sh"
  run_body configure-1 "$b_configure" \
    "DEFECTDOJO_URL=${BASE_URL}" \
    "DEFECTDOJO_ADMIN_TOKEN_FILE=${bare}" \
    "DEFECTDOJO_CA_FILE=${DD_CA_FILE}"
  print_masked "$BODY_LOG" "$admin_token"
  if [ "$BODY_RC" -ne 0 ]; then
    rm -f "$bare"
    proof_abort "P-CONFIGURE" "defectdojo-configure.sh (run 1) exited ${BODY_RC}; every Phase 28 scenario needs deduplication on (log ${BODY_LOG})"
  fi
  why=""
  grep -q '^CHANGED: .*enable_deduplication' "$BODY_LOG" || why="${why} no 'CHANGED:' line naming enable_deduplication;"
  grep -q '^VERIFIED:' "$BODY_LOG" || why="${why} no 'VERIFIED:' line;"
  if [ -z "$why" ]; then
    proof_pass "P-CONFIGURE" "run 1 on the fresh install -> exit 0, CHANGED: names enable_deduplication, VERIFIED: printed"
  else
    proof_fail "P-CONFIGURE" "run 1 exited 0 but:${why}"
  fi
  rc=0
  read_settings "$post" || rc=$?
  if [ "$rc" -ne 0 ]; then
    proof_fail "P-CONFIGURE" "System Settings read-back after run 1 failed: $(head -c 300 "${post}.err" | tr '\n' ' ')"
  else
    echo "    after:  $(jq -c '{enable_deduplication, delete_duplicates, false_positive_history, retroactive_false_positive_history, risk_acceptance_form_default_days, enable_finding_sla}' "$post")"
    # jq == is type-strict: 1 is not true and "90" is not 90.
    if jq -e '.enable_deduplication == true and .delete_duplicates == false
        and .false_positive_history == false and .retroactive_false_positive_history == false
        and .risk_acceptance_form_default_days == 90' "$post" > /dev/null; then
      proof_pass "P-CONFIGURE" "read-back: enable_deduplication=true, delete_duplicates=false, both false-positive-history flags false, risk_acceptance_form_default_days=90"
    else
      proof_fail "P-CONFIGURE" "read-back does not hold the desired values: $(jq -c '{enable_deduplication, delete_duplicates, false_positive_history, retroactive_false_positive_history, risk_acceptance_form_default_days}' "$post")"
    fi
    local sla_pre sla_post
    sla_pre="$(jq -c 'if has("enable_finding_sla") then .enable_finding_sla else "absent" end' "$pre")" || sla_pre="unparseable"
    sla_post="$(jq -c 'if has("enable_finding_sla") then .enable_finding_sla else "absent" end' "$post")" || sla_post="unparseable"
    if [ "$sla_pre" = "$sla_post" ] && [ "$sla_pre" != '"absent"' ] && [ "$sla_pre" != "unparseable" ]; then
      proof_pass "P-CONFIGURE" "enable_finding_sla unchanged by the bootstrap (${sla_pre} -> ${sla_post}, D-21)"
    else
      proof_fail "P-CONFIGURE" "enable_finding_sla ${sla_pre} -> ${sla_post}; expected present and unchanged (D-21)"
    fi
  fi
  # The pattern comes from the file (-f), so the token is not on grep's argv.
  if grep -qF -f "$bare" "$BODY_LOG"; then
    proof_fail "P-CONFIGURE" "the admin token string appears in the run-1 log"
  else
    proof_pass "P-CONFIGURE" "the admin token string does not appear in the run-1 log"
  fi

  # ── P-IDEMPOTENT (D-10, D-11) ─────────────────────────────────────────────
  echo
  echo "=== bootstrap rerun changes nothing (P-IDEMPOTENT) ==="
  local before2="${PROOF_DIR}/settings-before2.json" after2="${PROOF_DIR}/settings-after2.json" rc2=0
  rc=0
  read_settings "$before2" || rc=$?
  run_body configure-2 "$b_configure" \
    "DEFECTDOJO_URL=${BASE_URL}" \
    "DEFECTDOJO_ADMIN_TOKEN_FILE=${bare}" \
    "DEFECTDOJO_CA_FILE=${DD_CA_FILE}"
  print_masked "$BODY_LOG" "$admin_token"
  read_settings "$after2" || rc2=$?
  why=""
  [ "$BODY_RC" -eq 0 ] || why="${why} exit ${BODY_RC} (expected 0);"
  grep -q '^NO CHANGE' "$BODY_LOG" || why="${why} no line starting 'NO CHANGE';"
  if grep -q '^CHANGED:' "$BODY_LOG"; then why="${why} a 'CHANGED:' line was printed;"; fi
  if grep -qF -f "$bare" "$BODY_LOG"; then why="${why} the admin token string appears in the log;"; fi
  if [ "$rc" -ne 0 ] || [ "$rc2" -ne 0 ]; then
    why="${why} a System Settings read failed: $(snippet "${before2}.err" "${after2}.err");"
  elif ! jq -S . "$before2" > "${before2}.sorted" || ! jq -S . "$after2" > "${after2}.sorted"; then
    why="${why} a System Settings snapshot is not JSON;"
  elif ! cmp -s "${before2}.sorted" "${after2}.sorted"; then
    why="${why} the System Settings object changed: $(diff "${before2}.sorted" "${after2}.sorted" | head -c 300 | tr '\n' ' ' || true);"
  fi
  if [ -z "$why" ]; then
    proof_pass "P-IDEMPOTENT" "run 2 -> exit 0, NO CHANGE, no CHANGED: line, System Settings byte-identical (jq -S) before and after"
  else
    proof_fail "P-IDEMPOTENT" "run 2:${why}"
  fi
  rm -f "$bare"
  admin_token=""

  # ── P-DEDUP-MODE (RESEARCH Pitfall 3) ─────────────────────────────────────
  # Harness only: ci-importer's contact-info row gets
  # deduplication_execution_mode=async_wait, so an import's 201 waits for
  # dedup. security.yml is not changed (T-28-14).
  echo
  echo "=== ci-importer dedup execution mode: async_wait (P-DEDUP-MODE) ==="
  local importer_id
  importer_id="$(jq -r --arg u "$PROOF_USER" \
    '[.results[]? | select(.username == $u) | .id] | if length == 1 then .[0] else "none" end' \
    "${PROOF_DIR}/user-get.json")" || importer_id="none"
  if ! [[ "$importer_id" =~ ^[0-9]+$ ]]; then
    proof_fail "P-DEDUP-MODE" "no single ${PROOF_USER} id in user-get.json (got '${importer_id}')"
  else
    read_contact_info "$importer_id" "$admin_hdr"
    local cbody="${PROOF_DIR}/contact-body.json" cresp="${PROOF_DIR}/contact-write.json"
    local method="" expect="" curl_url="" res code
    case "$CONTACT_N" in
      0)
        jq -n --argjson u "$importer_id" '{user: $u, deduplication_execution_mode: "async_wait"}' > "$cbody"
        method="POST"
        expect="201"
        curl_url="${BASE_URL}/api/v2/user_contact_infos/"
        ;;
      1)
        jq -n '{deduplication_execution_mode: "async_wait"}' > "$cbody"
        method="PATCH"
        expect="200"
        curl_url="${BASE_URL}/api/v2/user_contact_infos/${CONTACT_ROW_ID}/"
        ;;
      *)
        proof_fail "P-DEDUP-MODE" "user_contact_infos rows for ${PROOF_USER} (id ${importer_id}): ${CONTACT_N} ${CONTACT_ERR}"
        ;;
    esac
    if [ -n "$method" ]; then
      echo "    ${PROOF_USER} (id ${importer_id}) has ${CONTACT_N} contact-info row(s): ${method} deduplication_execution_mode=async_wait"
      rc=0
      res="$(api_call "$cresp" -X "$method" -H "@${admin_hdr}" -H 'Content-Type: application/json' \
        --data-binary "@${cbody}" "$curl_url" 2>"${cresp}.err")" || rc=$?
      rm -f "$cbody"
      code="${res%% *}"
      if [ "$rc" -ne 0 ] || [ "$code" != "$expect" ]; then
        proof_fail "P-DEDUP-MODE" "${method} ${curl_url#"${BASE_URL}"}: curl exit ${rc}, http ${code:-none} (expected ${expect}): $(head -c 400 "$cresp" 2>/dev/null | tr '\n' ' ')$(tr '\n' ' ' < "${cresp}.err")"
      else
        read_contact_info "$importer_id" "$admin_hdr"
        if [ "$CONTACT_N" = "1" ] && [ "$CONTACT_MODE" = "async_wait" ]; then
          proof_pass "P-DEDUP-MODE" "${method} -> ${code}; read-back: ${PROOF_USER}'s contact-info row ${CONTACT_ROW_ID} has deduplication_execution_mode=async_wait (harness only; security.yml unchanged)"
        else
          proof_fail "P-DEDUP-MODE" "read-back after ${method}: ${CONTACT_N} row(s), mode '${CONTACT_MODE}'; expected 1 row with async_wait ${CONTACT_ERR}"
        fi
      fi
    fi
  fi

  # ── P-DEDUP-BRANCH (D-01, D-11, RESEARCH Pitfall 7) ───────────────────────
  # A real delta, built here from the CI reports (never a committed fixture):
  # ci/main is imported from a copy with exactly one trivy-fs vulnerability
  # removed, then the PR from the full reports. The removed entry must be
  # unique in trivy-fs.json and absent from trivy-image.json (Trivy fs and
  # image share the "Trivy Scan" type, so a copy there would dedup it).
  echo
  echo "=== branch-engagement dedup with a unique delta (P-DEDUP-BRANCH) ==="
  local trimmed="${PROOF_DIR}/reports-main-trimmed" trivy_only="${PROOF_DIR}/reports-trivy-only"
  local delta="${PROOF_DIR}/delta.json" delta_rc=0
  rm -rf "$trimmed" "$trivy_only"
  mkdir -p "$trimmed" "$trivy_only"
  find "$DD_PROOF_REPORTS" -maxdepth 1 -type f -exec cp {} "${trimmed}/" \;
  # Untrimmed trivy-fs.json alone, for the 28-04 P-REPARENT scenario.
  cp "${DD_PROOF_REPORTS}/trivy-fs.json" "${trivy_only}/trivy-fs.json"
  PROOF_TRIMMED="$trimmed" PROOF_FULL_REPORTS="$DD_PROOF_REPORTS" PROOF_DELTA="$delta" \
    python3 - > "${delta}.log" 2>&1 <<'PY' || delta_rc=$?
import json
import os
import sys

env = os.environ
fs_path = os.path.join(env["PROOF_TRIMMED"], "trivy-fs.json")
img_path = os.path.join(env["PROOF_FULL_REPORTS"], "trivy-image.json")


def entries(doc):
    for result in (doc.get("Results") or []):
        if not isinstance(result, dict):
            continue
        for vuln in (result.get("Vulnerabilities") or []):
            if isinstance(vuln, dict):
                key = (vuln.get("VulnerabilityID"), vuln.get("PkgName"), vuln.get("InstalledVersion"))
                yield key, result, vuln


with open(fs_path, encoding="utf-8") as handle:
    fs = json.load(handle)
counts = {}
for key, _, _ in entries(fs):
    counts[key] = counts.get(key, 0) + 1
image = set()
if os.path.isfile(img_path):
    with open(img_path, encoding="utf-8") as handle:
        image = {key for key, _, _ in entries(json.load(handle))}

chosen = None
for key, result, vuln in entries(fs):
    if None not in key and counts[key] == 1 and key not in image:
        chosen = (key, result, vuln)
        break
if chosen is None:
    print("NO-DELTA: {} trivy-fs vulnerabilities ({} distinct triples), trivy-image {}: none occurs exactly once "
          "in trivy-fs.json and not in trivy-image.json".format(
              sum(counts.values()), len(counts), "present" if os.path.isfile(img_path) else "absent"))
    sys.exit(3)
key, result, vuln = chosen
index = next(i for i, v in enumerate(result["Vulnerabilities"]) if v is vuln)
del result["Vulnerabilities"][index]
with open(fs_path, "w", encoding="utf-8") as handle:
    json.dump(fs, handle)
record = {"VulnerabilityID": key[0], "PkgName": key[1], "InstalledVersion": key[2],
          "Title": vuln.get("Title"), "Severity": vuln.get("Severity"), "Target": result.get("Target")}
with open(env["PROOF_DELTA"], "w", encoding="utf-8") as handle:
    json.dump(record, handle, indent=2)
print("delta: removed {} {} {} ({}, {!r}) from the ci/main copy of trivy-fs.json".format(
    key[0], key[1], key[2], record["Severity"], record["Target"]))
PY
  sed -e 's/^/    /' "${delta}.log"
  if [ "$delta_rc" -eq 3 ]; then
    proof_abort "P-DEDUP-BRANCH" "no unique trivy-fs vulnerability available as a delta ($(snippet "${delta}.log"))"
  elif [ "$delta_rc" -ne 0 ]; then
    proof_abort "P-DEDUP-BRANCH" "building the delta reports failed (exit ${delta_rc}): $(snippet "${delta}.log")"
  fi

  # Default branch FIRST: its findings get the lower ids and stay the
  # originals (D-01); the PR copies are then marked duplicate.
  import_as_branch dedup-main "$PROOF_DEDUP_PRODUCT" "$PROOF_DEFAULT_BRANCH" "$trimmed" \
    "${PROOF_DIR}/results-dedup-main.json"
  if [ "$BODY_RC" -ne 0 ]; then
    proof_abort "P-DEDUP-BRANCH" "committed dd-import body (ci/${PROOF_DEFAULT_BRANCH}, trimmed reports) exited ${BODY_RC} (log ${BODY_LOG})"
  fi
  import_as_branch dedup-pr "$PROOF_DEDUP_PRODUCT" "$PROOF_DEDUP_PR" "$DD_PROOF_REPORTS" \
    "${PROOF_DIR}/results-dedup-pr.json"
  if [ "$BODY_RC" -ne 0 ]; then
    proof_abort "P-DEDUP-BRANCH" "committed dd-import body (ci/${PROOF_DEDUP_PR}, full reports) exited ${BODY_RC} (log ${BODY_LOG})"
  fi
  wait_dedup_settled "$PROOF_DEDUP_PRODUCT" "ci/${PROOF_DEDUP_PR}"

  local main_snap="${PROOF_DIR}/dedup-main.json" pr_snap="${PROOF_DIR}/dedup-pr.json"
  rc=0
  snapshot_engagement "$PROOF_DEDUP_PRODUCT" "ci/${PROOF_DEFAULT_BRANCH}" "$main_snap" || rc=$?
  if [ "$rc" -ne 0 ]; then
    proof_abort "P-DEDUP-BRANCH" "snapshot of ${PROOF_DEDUP_PRODUCT} / ci/${PROOF_DEFAULT_BRANCH} failed: $(snippet "${main_snap}.err")"
  fi
  snapshot_engagement "$PROOF_DEDUP_PRODUCT" "ci/${PROOF_DEDUP_PR}" "$pr_snap" || rc=$?
  if [ "$rc" -ne 0 ]; then
    proof_abort "P-DEDUP-BRANCH" "snapshot of ${PROOF_DEDUP_PRODUCT} / ci/${PROOF_DEDUP_PR} failed: $(snippet "${pr_snap}.err")"
  fi

  local branch_log="${PROOF_DIR}/assert-dedup-branch.log" branch_rc=0
  PROOF_MAIN_SNAP="$main_snap" PROOF_PR_SNAP="$pr_snap" PROOF_DELTA="$delta" \
    python3 - > "$branch_log" 2>&1 <<'PY' || branch_rc=$?
import json
import os
import subprocess
import sys

env = os.environ
PID = "P-DEDUP-BRANCH"


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


main, pr, delta = load(env["PROOF_MAIN_SNAP"]), load(env["PROOF_PR_SNAP"]), load(env["PROOF_DELTA"])
failures = 0


def say(pid, ok, detail):
    global failures
    print("PROOF: {} {} {}".format(pid, "PASS" if ok else "FAIL", detail))
    if not ok:
        failures += 1


def by_id(ids):
    if not ids:
        return {}
    proc = subprocess.run([sys.executable, env["PROOF_DEDUP_PY"], "findings-by-id"],
                          env=dict(env, SNAP_IDS=",".join(str(i) for i in sorted(ids))),
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    if proc.returncode != 0:
        raise RuntimeError("findings-by-id {} failed: {}".format(sorted(ids), (proc.stderr or proc.stdout).strip()[:300]))
    return json.loads(proc.stdout)


def scan_type(snap, f):
    return (snap["tests"].get(str(f["test"])) or {}).get("scan_type")


def brief(snap, f):
    return "#{} {} {!r} dup={} active={} dup_of={}".format(
        f["id"], scan_type(snap, f), f["title"][:60], f["duplicate"], f["active"], f["duplicate_finding"])


try:
    main_f, pr_f = main["findings"], pr["findings"]
    main_ids = {f["id"] for f in main_f}
    pr_ids = {f["id"] for f in pr_f}
    print("    counts: PR total {}, PR duplicates {}, main total {}, main duplicates {}".format(
        len(pr_f), sum(1 for f in pr_f if f["duplicate"] is True),
        len(main_f), sum(1 for f in main_f if f["duplicate"] is True)))

    say(PID, len(pr_f) >= 10, "ci/{} holds {} findings (at least 10, non-vacuous)".format(
        env["PROOF_DEDUP_PR"], len(pr_f)))

    def is_delta(f):
        return (scan_type(pr, f) == "Trivy Scan" and delta["VulnerabilityID"] in f["vulnerability_ids"]
                and f["component_name"] == delta["PkgName"] and f["component_version"] == delta["InstalledVersion"])

    nondup = [f for f in pr_f if f["duplicate"] is not True]
    say(PID, len(nondup) == 1 and is_delta(nondup[0]) and nondup[0]["active"] is True,
        "exactly one PR finding is non-duplicate and it is the active delta {} {} {}: {} non-duplicate{}".format(
            delta["VulnerabilityID"], delta["PkgName"], delta["InstalledVersion"], len(nondup),
            "" if not nondup else " ({})".format("; ".join(brief(pr, f) for f in nondup[:5]))))

    others = [f for f in pr_f if not is_delta(f)]
    bad = [f for f in others
           if not (f["duplicate"] is True and f["active"] is False and f["duplicate_finding"] in main_ids)]
    elsewhere = {f["duplicate_finding"] for f in bad
                 if f["duplicate_finding"] is not None and f["duplicate_finding"] not in main_ids}
    resolved = by_id(elsewhere)
    notes = []
    for f in bad[:5]:
        target = resolved.get(str(f["duplicate_finding"]))
        where = "" if target is None else " (original #{} is in engagement {}, {})".format(
            target["id"], target["engagement"], target["scan_type"])
        notes.append(brief(pr, f) + where)
    say(PID, bool(others) and not bad,
        "every other PR finding ({}) is duplicate=true, active=false, with its original in ci/{}{}".format(
            len(others), env["PROOF_DEFAULT_BRANCH"],
            "" if not bad else "; {} do not: {}".format(len(bad), "; ".join(notes))))

    crossing = [f for f in main_f if f["duplicate_finding"] in pr_ids]
    say(PID, not crossing,
        "no ci/{} finding has its original in the PR engagement (the older default-branch finding stays the "
        "original){}".format(env["PROOF_DEFAULT_BRANCH"],
                             "" if not crossing else ": {}".format("; ".join(brief(main, f) for f in crossing[:5]))))
except (RuntimeError, KeyError, TypeError, ValueError) as exc:
    say(PID, False, "branch-dedup assertions aborted: {}".format(exc))
sys.exit(1 if failures else 0)
PY
  tally_assert_log "$branch_log"
  if [ "$branch_rc" -ne 0 ] && ! grep -q '^PROOF: P-DEDUP-BRANCH FAIL' "$branch_log"; then
    proof_fail "P-DEDUP-BRANCH" "the branch-dedup assertion script exited ${branch_rc} without reporting a failed assertion (see ${branch_log})"
  fi

  # ── P-CROSSTOOL (D-05, D-07 evidence) ─────────────────────────────────────
  # The measured cross-tool SCA gap in ci/main: RESEARCH says no duplicate
  # link can cross Trivy / pip-audit / NPM Audit v7+ (different id
  # namespaces and fields), so ADR-026 ships within-tool dedup only. The
  # CROSSTOOL: lines are the evidence 28-05 and ADR-026 quote.
  echo
  echo "=== cross-tool SCA gap in ci/${PROOF_DEFAULT_BRANCH} (P-CROSSTOOL) ==="
  local cross_log="${PROOF_DIR}/assert-crosstool.log" cross_rc=0
  PROOF_MAIN_SNAP="$main_snap" python3 - > "$cross_log" 2>&1 <<'PY' || cross_rc=$?
import json
import os
import subprocess
import sys

env = os.environ
PID = "P-CROSSTOOL"
SCA = ["Trivy Scan", "pip-audit Scan", "NPM Audit v7+ Scan"]
with open(env["PROOF_MAIN_SNAP"], encoding="utf-8") as handle:
    main = json.load(handle)
failures = 0


def say(pid, ok, detail):
    global failures
    print("PROOF: {} {} {}".format(pid, "PASS" if ok else "FAIL", detail))
    if not ok:
        failures += 1


def by_id(ids):
    if not ids:
        return {}
    proc = subprocess.run([sys.executable, env["PROOF_DEDUP_PY"], "findings-by-id"],
                          env=dict(env, SNAP_IDS=",".join(str(i) for i in sorted(ids))),
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    if proc.returncode != 0:
        raise RuntimeError("findings-by-id {} failed: {}".format(sorted(ids), (proc.stderr or proc.stdout).strip()[:300]))
    return json.loads(proc.stdout)


def norm(name):
    # pip-audit reports normalised lower-case names; Trivy keeps the
    # distribution's spelling. Compare case-insensitively.
    return (name or "").strip().lower()


try:
    findings = main["findings"]
    types = {f["id"]: (main["tests"].get(str(f["test"])) or {}).get("scan_type") for f in findings}
    by_type = {t: [f for f in findings if types[f["id"]] == t] for t in SCA}

    missing = [t for t in SCA if not by_type[t]]
    say(PID, not missing, "ci/{} holds findings of every SCA parser ({}){}".format(
        env["PROOF_DEFAULT_BRANCH"], ", ".join("{}={}".format(t, len(by_type[t])) for t in SCA),
        "" if not missing else "; missing: {} (the SCA overlap cannot be measured, the D-07 evidence would be "
                               "vacuous)".format(", ".join(missing))))

    trivy_names = {norm(f["component_name"]) for f in by_type["Trivy Scan"] if norm(f["component_name"])}
    pip_names = {norm(f["component_name"]) for f in by_type["pip-audit Scan"] if norm(f["component_name"])}
    overlap = sorted(trivy_names & pip_names)
    say(PID, bool(overlap), "packages reported by both Trivy and pip-audit (non-vacuous gap): {}".format(
        overlap or "none"))

    # Every duplicate link that touches an SCA finding, with both ends typed;
    # originals outside ci/main are resolved through findings-by-id.
    outside = {f["duplicate_finding"] for f in findings
               if f["duplicate_finding"] is not None and f["duplicate_finding"] not in types}
    for key, target in by_id(outside).items():
        types[int(key)] = target["scan_type"]
    links, cross = 0, []
    for f in findings:
        orig = f["duplicate_finding"]
        if orig is None:
            continue
        mine, theirs = types[f["id"]], types.get(orig)
        if mine in SCA or theirs in SCA:
            links += 1
            if mine != theirs:
                cross.append("#{} ({}) -> #{} ({})".format(f["id"], mine, orig, theirs))
    say(PID, not cross, "{} duplicate link(s) touch an SCA finding in ci/{}; {} cross scan types{}".format(
        links, env["PROOF_DEFAULT_BRANCH"], len(cross),
        "" if not cross else " (contradicts RESEARCH and the ADR-026 D-07 basis): {}".format("; ".join(cross[:10]))))

    for t in SCA:
        fs = by_type[t]
        samples = sorted({f["component_name"] for f in fs if f["component_name"]})[:3]
        print("CROSSTOOL: scan_type={!r} findings={} with_vulnerability_ids={} with_component_version={} "
              "sample_components={}".format(t, len(fs), sum(1 for f in fs if f["vulnerability_ids"]),
                                            sum(1 for f in fs if f["component_version"]), samples))
    for name in overlap:
        tv = sorted({v for f in by_type["Trivy Scan"] if norm(f["component_name"]) == name
                     for v in f["vulnerability_ids"]})
        pv = sorted({v for f in by_type["pip-audit Scan"] if norm(f["component_name"]) == name
                     for v in f["vulnerability_ids"]})
        print("CROSSTOOL: package={} trivy_ids={} pip_audit_ids={} shared={}".format(
            name, tv, pv, sorted(set(tv) & set(pv))))
except (RuntimeError, KeyError, TypeError, ValueError) as exc:
    say(PID, False, "cross-tool measurement aborted: {}".format(exc))
sys.exit(1 if failures else 0)
PY
  tally_assert_log "$cross_log"
  if [ "$cross_rc" -ne 0 ] && ! grep -q '^PROOF: P-CROSSTOOL FAIL' "$cross_log"; then
    proof_fail "P-CROSSTOOL" "the cross-tool script exited ${cross_rc} without reporting a failed assertion (see ${cross_log})"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# --scheme-only (offline P-HTTP; no cluster, no network)
# ─────────────────────────────────────────────────────────────────────────────
mode_scheme_only() {
  require_bins jq yq python3
  umask 077
  DD_SMOKE_OUT="$(mktemp -d)"
  # shellcheck disable=SC2064  # expand now: the path is fixed for this run
  trap "rm -rf '${DD_SMOKE_OUT}'" EXIT
  PROOF_DIR="${DD_SMOKE_OUT}/proof"
  mkdir -p "$PROOF_DIR"
  local bodies="${PROOF_DIR}/bodies" reports="${PROOF_DIR}/reports" ex_rc=0
  mkdir -p "$bodies" "$reports"
  extract_bodies "$bodies" || ex_rc=$?
  if [ "$ex_rc" -ne 0 ]; then
    echo "FATAL: --scheme-only: the committed side-channel bodies failed the static contract (exit ${ex_rc})" >&2
    exit 1
  fi
  printf '{}\n' > "${reports}/semgrep-results.json"
  printf '{}\n' > "${reports}/checkov-results.json"
  prove_http_refusal "$bodies" "$reports"
  proof_finish
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

  echo "=== DefectDojo import proof against ${BASE_URL} (run 1) ==="
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
  local b_delete="${bodies}/defectdojo-cleanup__dd-delete.sh"
  local b_cleanup_verify="${bodies}/defectdojo-cleanup__dd-cleanup-verify.sh"

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
  # PROOF_PRODUCT / PROOF_PRODUCT_TYPE are readonly, and bash refuses a
  # command-prefix assignment to a readonly name (the variable is then NOT
  # passed), so they are exported instead.
  export PROOF_PRODUCT PROOF_PRODUCT_TYPE
  PROOF_ADMIN_HDR="$admin_hdr" PROOF_RESULTS="$results1" PROOF_RUN1_OUT="${DD_SMOKE_OUT}/proof-run1.json" \
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


def get(path, params, count_only=False):
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
    # A list lookup must fit on one page (no guessing); a count-only query
    # (limit=1, reads `count`) is paged by design.
    if not count_only and isinstance(data, dict) and data.get("next"):
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
        count = get("/api/v2/findings/", {"test": r.get("test_id"), "limit": 1},
                    count_only=True).get("count")
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

# Saved for the run-2 comparison below (Pitfall 6 c).
with open(env["PROOF_RUN1_OUT"], "w", encoding="utf-8") as handle:
    json.dump(run1, handle, indent=2)
sys.exit(1 if failures else 0)
PY
  tally_assert_log "$assert_log"
  if [ "$py_rc" -ne 0 ] && [ "$PROOF_FAILED" -eq 0 ]; then
    proof_fail "P-COUNTS" "the read-side assertion script exited ${py_rc} without reporting a failed assertion (see ${assert_log})"
  fi
  if [ "$PROOF_FAILED" -gt 0 ]; then
    # Run 2 compares against run 1; a failed run-1 read side leaves nothing
    # sound to compare with.
    echo "    aborting: run 2 and the cleanup assertions depend on a clean run 1"
    proof_finish
  fi

  # Read-side helper for everything below (admin token, verified TLS).
  PROOF_ADMIN_HDR="$admin_hdr"
  PROOF_READ_PY="${PROOF_DIR}/read.py"
  export PROOF_ADMIN_HDR PROOF_READ_PY
  write_read_py "$PROOF_READ_PY"

  local reports_one="${PROOF_DIR}/reports-gitleaks-only" reports_none="${PROOF_DIR}/reports-empty"
  mkdir -p "$reports_one" "$reports_none"
  cp "${DD_PROOF_REPORTS}/gitleaks-results.json" "${reports_one}/gitleaks-results.json"

  # ── P-RUN2 ────────────────────────────────────────────────────────────────
  # The SAME env as P-RUN1: a reimport in place (D-07). Every file must
  # create zero findings, keep its after-total and keep its Test (Pitfall 6c).
  echo
  echo "=== run 2: reimport the same reports into ci/${PROOF_BRANCH_A} ==="
  local results2="${PROOF_DIR}/results-run2.json"
  run_body import-run2 "$b_import" \
    "DD_URL=${BASE_URL}" \
    "DD_TOKEN=$(cat "$importer_tok")" \
    "DD_PRODUCT=${PROOF_PRODUCT}" \
    "DD_PRODUCT_TYPE=${PROOF_PRODUCT_TYPE}" \
    "DD_INSECURE=" \
    "DD_CA_CERT=${ca_pem}" \
    "DD_REPORTS_DIR=${DD_PROOF_REPORTS}" \
    "DD_RESULTS_FILE=${results2}" \
    "GITHUB_ACTOR=proof-actor" \
    "GITHUB_EVENT_NAME=pull_request" \
    "GITHUB_HEAD_REF=${PROOF_BRANCH_A}" \
    "GITHUB_REF_NAME=27/merge" \
    "GITHUB_SHA=${PROOF_SHA}" \
    "GITHUB_RUN_ID=${PROOF_RUN_ID}" \
    "GITHUB_SERVER_URL=${PROOF_SERVER_URL}" \
    "GITHUB_REPOSITORY=${PROOF_REPOSITORY}"
  sed -e 's/^/    | /' "$BODY_LOG"
  if [ "$BODY_RC" -ne 0 ] || [ ! -s "$results2" ]; then
    proof_abort "P-RUN2" "committed dd-import body (run 2) exited ${BODY_RC} (results file present: $([ -s "$results2" ] && echo yes || echo no)); log ${BODY_LOG}"
  fi
  run_body verify-run2 "$b_verify" "DD_IMPORT_OUTCOME=success" "DD_RESULTS_FILE=${results2}"
  sed -e 's/^/    | /' "$BODY_LOG"
  if [ "$BODY_RC" -eq 0 ]; then
    proof_pass "P-RUN2" "committed dd-import (run 2) and dd-verify bodies exited 0"
  else
    proof_fail "P-RUN2" "committed dd-verify body exited ${BODY_RC} on the run-2 results (log ${BODY_LOG})"
  fi
  local run2_log="${PROOF_DIR}/assert-run2.log" run2_rc=0
  PROOF_RESULTS2="$results2" PROOF_RUN1_OUT="${DD_SMOKE_OUT}/proof-run1.json" \
    python3 - > "$run2_log" 2>&1 <<'PY' || run2_rc=$?
import json
import os
import subprocess
import sys

env = os.environ
with open(env["PROOF_RUN1_OUT"], encoding="utf-8") as handle:
    run1 = json.load(handle)
with open(env["PROOF_RESULTS2"], encoding="utf-8") as handle:
    run2 = json.load(handle)
failures = 0


def check(ok, detail):
    global failures
    print("PROOF: P-RUN2 {} {}".format("PASS" if ok else "FAIL", detail))
    if not ok:
        failures += 1


def total_of(stats, *path):
    node = stats
    for key in path:
        if not isinstance(node, dict):
            return None
        node = node.get(key)
    return node


files1 = run1.get("files") or {}
attempted2 = run2.get("attempted") or []
names1 = sorted(files1)
names2 = sorted(r.get("file") for r in attempted2)
# Iterate run 2, and require the same non-empty file set: an empty run-1
# record must not let this pass vacuously.
check(bool(names2) and names1 == names2,
      "run 2 attempted {} == run 1 files {}".format(names2, names1))
print("    file                       test(run1) test(run2)  after(run1) after(run2)  delta.created")
for r in attempted2:
    name = r.get("file")
    one = files1.get(name) or {}
    stats = r.get("statistics") if isinstance(r.get("statistics"), dict) else {}
    created = total_of(stats, "delta", "created", "total", "total")
    after = total_of(stats, "after", "total", "total")
    print("    {:<26} {:>10} {:>10} {:>12} {:>11} {:>14}".format(
        str(name), str(one.get("test_id")), str(r.get("test_id")), str(one.get("after_total")),
        str(after), str(created)))
    if created is None:
        check(False, "{}: statistics.delta.created.total.total missing; statistics keys {} (delta keys {})".format(
            name, sorted(stats), sorted((stats.get("delta") or {}) if isinstance(stats.get("delta"), dict) else [])))
    else:
        check(created == 0, "{}: delta.created.total.total {} == 0".format(name, created))
    check(after is not None and after == one.get("after_total"),
          "{}: after.total.total {} == run-1 {}".format(name, after, one.get("after_total")))
    check(r.get("test_id") is not None and r.get("test_id") == one.get("test_id"),
          "{}: test_id {} == run-1 test_id {} (reimported in place)".format(
              name, r.get("test_id"), one.get("test_id")))

proc = subprocess.run([sys.executable, env["PROOF_READ_PY"], "engagements"],
                      env=dict(env, READ_PRODUCT=run1.get("product", ""),
                               READ_ENGAGEMENT=run1.get("engagement", "")),
                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
if proc.returncode != 0:
    check(False, "engagement read-back failed: {}".format((proc.stderr or proc.stdout).strip()[:300]))
else:
    state = json.loads(proc.stdout)
    engs = state.get("engagements") or []
    tests_now = engs[0].get("tests") if len(engs) == 1 else None
    check(len(engs) == 1 and tests_now == run1.get("test_count"),
          "engagement {!r}: {} match(es), Test count {} == run-1 {}".format(
              run1.get("engagement"), len(engs), tests_now, run1.get("test_count")))
    run1["test_count_run2"] = tests_now
    with open(env["PROOF_RUN1_OUT"], "w", encoding="utf-8") as handle:
        json.dump(run1, handle, indent=2)
sys.exit(1 if failures else 0)
PY
  tally_assert_log "$run2_log"
  if [ "$run2_rc" -ne 0 ] && ! grep -q '^PROOF: P-RUN2 FAIL' "$run2_log"; then
    proof_fail "P-RUN2" "the run-2 comparison script exited ${run2_rc} without reporting a failed assertion (see ${run2_log})"
  fi
  local branch_a_tests
  branch_a_tests="$(jq -r '.test_count_run2 // "unknown"' "${DD_SMOKE_OUT}/proof-run1.json")"

  # ── P-SCHEDULE ────────────────────────────────────────────────────────────
  # A scheduled run has no head ref: the branch comes from GITHUB_REF_NAME
  # and the default-branch engagement is created (D-07, D-14).
  echo
  echo "=== schedule event: branch from GITHUB_REF_NAME ==="
  run_body import-schedule "$b_import" \
    "DD_URL=${BASE_URL}" \
    "DD_TOKEN=$(cat "$importer_tok")" \
    "DD_PRODUCT=${PROOF_PRODUCT}" \
    "DD_PRODUCT_TYPE=${PROOF_PRODUCT_TYPE}" \
    "DD_INSECURE=" \
    "DD_CA_CERT=${ca_pem}" \
    "DD_REPORTS_DIR=${reports_one}" \
    "DD_RESULTS_FILE=${PROOF_DIR}/results-schedule.json" \
    "GITHUB_ACTOR=proof-actor" \
    "GITHUB_EVENT_NAME=schedule" \
    "GITHUB_HEAD_REF=" \
    "GITHUB_REF_NAME=${PROOF_DEFAULT_BRANCH}" \
    "GITHUB_SHA=${PROOF_SHA}" \
    "GITHUB_RUN_ID=${PROOF_RUN_ID}" \
    "GITHUB_SERVER_URL=${PROOF_SERVER_URL}" \
    "GITHUB_REPOSITORY=${PROOF_REPOSITORY}"
  sed -e 's/^/    | /' "$BODY_LOG"
  read_engagements "$PROOF_PRODUCT" "ci/${PROOF_DEFAULT_BRANCH}"
  if [ "$BODY_RC" -eq 0 ] && [ "$READ_N" = "1" ]; then
    proof_pass "P-SCHEDULE" "schedule event, empty head ref, GITHUB_REF_NAME=${PROOF_DEFAULT_BRANCH} -> exit 0 and engagement 'ci/${PROOF_DEFAULT_BRANCH}' exists in ${PROOF_PRODUCT} (${READ_TESTS} Test)"
  else
    proof_fail "P-SCHEDULE" "schedule import exited ${BODY_RC}; engagement 'ci/${PROOF_DEFAULT_BRANCH}' matches in ${PROOF_PRODUCT}: ${READ_N} ${READ_ERR}"
  fi

  # ── P-HOSTILE ─────────────────────────────────────────────────────────────
  # The hostile head ref reaches the body ONLY as an exported environment
  # value (run_body's `export` builtin; nothing re-parses it). The leading @
  # would make curl read a file if the body ever used -F for it; the $( )
  # would run if anything interpolated it into a shell string (T-27-01).
  echo
  echo "=== hostile head ref ==="
  local hostile_dir
  run_body import-hostile "$b_import" \
    "DD_URL=${BASE_URL}" \
    "DD_TOKEN=$(cat "$importer_tok")" \
    "DD_PRODUCT=${PROOF_PRODUCT}" \
    "DD_PRODUCT_TYPE=${PROOF_PRODUCT_TYPE}" \
    "DD_INSECURE=" \
    "DD_CA_CERT=${ca_pem}" \
    "DD_REPORTS_DIR=${reports_one}" \
    "DD_RESULTS_FILE=${PROOF_DIR}/results-hostile.json" \
    "GITHUB_ACTOR=proof-actor" \
    "GITHUB_EVENT_NAME=pull_request" \
    "GITHUB_HEAD_REF=${PROOF_HOSTILE_REF}" \
    "GITHUB_REF_NAME=28/merge" \
    "GITHUB_SHA=${PROOF_SHA}" \
    "GITHUB_RUN_ID=${PROOF_RUN_ID}" \
    "GITHUB_SERVER_URL=${PROOF_SERVER_URL}" \
    "GITHUB_REPOSITORY=${PROOF_REPOSITORY}"
  hostile_dir="$BODY_DIR"
  sed -e 's/^/    | /' "$BODY_LOG"
  if [ "$BODY_RC" -eq 0 ]; then
    proof_pass "P-HOSTILE" "import with the hostile head ref exited 0"
  else
    proof_fail "P-HOSTILE" "import with the hostile head ref exited ${BODY_RC} (log above)"
  fi
  read_engagements "$PROOF_PRODUCT" "ci/${PROOF_HOSTILE_REF}"
  if [ "$READ_N" = "1" ]; then
    proof_pass "P-HOSTILE" "exactly one engagement named literally 'ci/${PROOF_HOSTILE_REF}' exists in ${PROOF_PRODUCT}"
  else
    proof_fail "P-HOSTILE" "engagement named literally 'ci/${PROOF_HOSTILE_REF}' in ${PROOF_PRODUCT}: ${READ_N} match(es) ${READ_ERR}"
  fi
  local pwned
  pwned="$( { [ -e "${hostile_dir}/pwned" ] && echo "${hostile_dir}/pwned"; [ -e "${REPO_ROOT}/pwned" ] && echo "${REPO_ROOT}/pwned"; find "$DD_SMOKE_OUT" -name pwned -print; } 2>/dev/null | tr '\n' ' ')" || pwned="find failed"
  if [ -z "$pwned" ]; then
    proof_pass "P-HOSTILE" "no file named pwned in the body's cwd, ${REPO_ROOT} or anywhere under \$DD_SMOKE_OUT: the \$( ) never ran"
  else
    proof_fail "P-HOSTILE" "a file named pwned exists: ${pwned}- the hostile ref was executed"
  fi

  # ── P-SCOPE ───────────────────────────────────────────────────────────────
  # The identical engagement name in a SECOND product: the cleanup below
  # must leave this one alone (delete is product-scoped, D-10).
  echo
  echo "=== same hostile engagement name in ${PROOF_OTHER_PRODUCT} ==="
  run_body import-scope "$b_import" \
    "DD_URL=${BASE_URL}" \
    "DD_TOKEN=$(cat "$importer_tok")" \
    "DD_PRODUCT=${PROOF_OTHER_PRODUCT}" \
    "DD_PRODUCT_TYPE=${PROOF_PRODUCT_TYPE}" \
    "DD_INSECURE=" \
    "DD_CA_CERT=${ca_pem}" \
    "DD_REPORTS_DIR=${reports_one}" \
    "DD_RESULTS_FILE=${PROOF_DIR}/results-scope.json" \
    "GITHUB_ACTOR=proof-actor" \
    "GITHUB_EVENT_NAME=pull_request" \
    "GITHUB_HEAD_REF=${PROOF_HOSTILE_REF}" \
    "GITHUB_REF_NAME=28/merge" \
    "GITHUB_SHA=${PROOF_SHA}" \
    "GITHUB_RUN_ID=${PROOF_RUN_ID}" \
    "GITHUB_SERVER_URL=${PROOF_SERVER_URL}" \
    "GITHUB_REPOSITORY=${PROOF_REPOSITORY}"
  sed -e 's/^/    | /' "$BODY_LOG"
  read_engagements "$PROOF_OTHER_PRODUCT" "ci/${PROOF_HOSTILE_REF}"
  if [ "$BODY_RC" -eq 0 ] && [ "$READ_N" = "1" ]; then
    proof_pass "P-SCOPE" "an engagement with the identical hostile name exists in ${PROOF_OTHER_PRODUCT} too"
  else
    proof_fail "P-SCOPE" "import into ${PROOF_OTHER_PRODUCT} exited ${BODY_RC}; matches there: ${READ_N} ${READ_ERR}"
  fi

  # ── P-CLEANUP ─────────────────────────────────────────────────────────────
  echo
  echo "=== cleanup: delete ci/<hostile ref> in ${PROOF_PRODUCT} only ==="
  local cleanup_res="${PROOF_DIR}/cleanup-hostile.json" outcome
  run_body delete-hostile "$b_delete" \
    "DD_URL=${BASE_URL}" \
    "DD_TOKEN=$(cat "$importer_tok")" \
    "DD_PRODUCT=${PROOF_PRODUCT}" \
    "DD_INSECURE=" \
    "DD_CA_CERT=${ca_pem}" \
    "DD_DEFAULT_BRANCH=${PROOF_DEFAULT_BRANCH}" \
    "DD_CLEANUP_RESULT_FILE=${cleanup_res}" \
    "GITHUB_ACTOR=proof-actor" \
    "GITHUB_EVENT_NAME=pull_request" \
    "GITHUB_HEAD_REF=${PROOF_HOSTILE_REF}"
  sed -e 's/^/    | /' "$BODY_LOG"
  outcome="$(jq -r '.outcome // "none"' "$cleanup_res" 2>/dev/null || echo "no-result-file")"
  if [ "$BODY_RC" -eq 0 ] && [ "$outcome" = "deleted" ]; then
    proof_pass "P-CLEANUP" "committed dd-delete body exited 0 with outcome deleted, as ${PROOF_USER}"
  else
    proof_fail "P-CLEANUP" "dd-delete exited ${BODY_RC} with outcome '${outcome}'; expected exit 0 and deleted"
  fi
  read_engagements "$PROOF_PRODUCT" "ci/${PROOF_HOSTILE_REF}"
  if [ "$READ_N" = "0" ]; then
    proof_pass "P-CLEANUP" "the hostile engagement is gone from ${PROOF_PRODUCT}"
  else
    proof_fail "P-CLEANUP" "the hostile engagement in ${PROOF_PRODUCT}: ${READ_N} match(es) remain ${READ_ERR}"
  fi
  read_engagements "$PROOF_OTHER_PRODUCT" "ci/${PROOF_HOSTILE_REF}"
  if [ "$READ_N" = "1" ]; then
    proof_pass "P-CLEANUP" "the same-named engagement in ${PROOF_OTHER_PRODUCT} still exists (product-scoped delete)"
  else
    proof_fail "P-CLEANUP" "the same-named engagement in ${PROOF_OTHER_PRODUCT}: ${READ_N} match(es), expected 1 ${READ_ERR}"
  fi
  read_engagements "$PROOF_PRODUCT" "ci/${PROOF_BRANCH_A}"
  if [ "$READ_N" = "1" ] && [ "$READ_TESTS" = "$branch_a_tests" ]; then
    proof_pass "P-CLEANUP" "ci/${PROOF_BRANCH_A} still exists with its run-2 Test count ${READ_TESTS}"
  else
    proof_fail "P-CLEANUP" "ci/${PROOF_BRANCH_A}: ${READ_N} match(es), Test count ${READ_TESTS}; expected 1 with ${branch_a_tests} ${READ_ERR}"
  fi
  read_engagements "$PROOF_PRODUCT" "ci/${PROOF_DEFAULT_BRANCH}"
  if [ "$READ_N" = "1" ]; then
    proof_pass "P-CLEANUP" "ci/${PROOF_DEFAULT_BRANCH} still exists"
  else
    proof_fail "P-CLEANUP" "ci/${PROOF_DEFAULT_BRANCH}: ${READ_N} match(es), expected 1 ${READ_ERR}"
  fi
  run_body cleanup-verify "$b_cleanup_verify" "DD_DELETE_OUTCOME=success" "DD_CLEANUP_RESULT_FILE=${cleanup_res}"
  sed -e 's/^/    | /' "$BODY_LOG"
  if [ "$BODY_RC" -eq 0 ]; then
    proof_pass "P-CLEANUP" "committed dd-cleanup-verify body exited 0 on the deleted result"
  else
    proof_fail "P-CLEANUP" "committed dd-cleanup-verify body exited ${BODY_RC} (log above)"
  fi

  # ── P-REFUSE ──────────────────────────────────────────────────────────────
  # The default branch and an empty head ref are refused before any request.
  echo
  echo "=== cleanup refusals ==="
  local refuse_head refuse_label
  for refuse_head in "$PROOF_DEFAULT_BRANCH" ""; do
    refuse_label="default-branch"
    [ -z "$refuse_head" ] && refuse_label="empty-head"
    cleanup_res="${PROOF_DIR}/cleanup-${refuse_label}.json"
    run_body "delete-${refuse_label}" "$b_delete" \
      "DD_URL=${BASE_URL}" \
      "DD_TOKEN=$(cat "$importer_tok")" \
      "DD_PRODUCT=${PROOF_PRODUCT}" \
      "DD_INSECURE=" \
      "DD_CA_CERT=${ca_pem}" \
      "DD_DEFAULT_BRANCH=${PROOF_DEFAULT_BRANCH}" \
      "DD_CLEANUP_RESULT_FILE=${cleanup_res}" \
      "GITHUB_ACTOR=proof-actor" \
      "GITHUB_EVENT_NAME=pull_request" \
      "GITHUB_HEAD_REF=${refuse_head}"
    sed -e 's/^/    | /' "$BODY_LOG"
    outcome="$(jq -r '.outcome // "none"' "$cleanup_res" 2>/dev/null || echo "no-result-file")"
    if [ "$BODY_RC" -eq 0 ] && [ "$outcome" = "refused" ] && grep -q '^REFUSE:' "$BODY_LOG"; then
      proof_pass "P-REFUSE" "head ref '${refuse_head}' (${refuse_label}) -> exit 0, outcome refused, REFUSE: line"
    else
      proof_fail "P-REFUSE" "head ref '${refuse_head}' (${refuse_label}): exit ${BODY_RC}, outcome '${outcome}'; expected exit 0, refused and a REFUSE: line"
    fi
  done
  read_engagements "$PROOF_PRODUCT" "ci/${PROOF_DEFAULT_BRANCH}"
  if [ "$READ_N" = "1" ]; then
    proof_pass "P-REFUSE" "ci/${PROOF_DEFAULT_BRANCH} still exists after both refusals"
  else
    proof_fail "P-REFUSE" "ci/${PROOF_DEFAULT_BRANCH}: ${READ_N} match(es) after the refusals, expected 1 ${READ_ERR}"
  fi

  # ── P-NOMATCH ─────────────────────────────────────────────────────────────
  echo
  echo "=== cleanup of a branch that never existed ==="
  local total_before total_after
  total_before="$(read_engagement_total)"
  cleanup_res="${PROOF_DIR}/cleanup-nomatch.json"
  run_body delete-nomatch "$b_delete" \
    "DD_URL=${BASE_URL}" \
    "DD_TOKEN=$(cat "$importer_tok")" \
    "DD_PRODUCT=${PROOF_PRODUCT}" \
    "DD_INSECURE=" \
    "DD_CA_CERT=${ca_pem}" \
    "DD_DEFAULT_BRANCH=${PROOF_DEFAULT_BRANCH}" \
    "DD_CLEANUP_RESULT_FILE=${cleanup_res}" \
    "GITHUB_ACTOR=proof-actor" \
    "GITHUB_EVENT_NAME=pull_request" \
    "GITHUB_HEAD_REF=${PROOF_NOMATCH_REF}"
  sed -e 's/^/    | /' "$BODY_LOG"
  total_after="$(read_engagement_total)"
  outcome="$(jq -r '.outcome // "none"' "$cleanup_res" 2>/dev/null || echo "no-result-file")"
  if [ "$BODY_RC" -eq 0 ] && [ "$outcome" = "nothing-to-delete" ] \
    && [ "$total_before" != "error" ] && [ "$total_before" = "$total_after" ]; then
    proof_pass "P-NOMATCH" "head ref '${PROOF_NOMATCH_REF}' -> exit 0, outcome nothing-to-delete, instance engagement count ${total_before} -> ${total_after}"
  else
    proof_fail "P-NOMATCH" "head ref '${PROOF_NOMATCH_REF}': exit ${BODY_RC}, outcome '${outcome}', engagement count ${total_before} -> ${total_after}; expected exit 0, nothing-to-delete, unchanged"
  fi

  # ── P-INSECURE ────────────────────────────────────────────────────────────
  # The D-18 warning path WITHOUT any unverified request: nothing listens on
  # port 9 and the reports dir is empty, so every table row is skipped before
  # a request could be made. DD_CA_CERT is empty so exactly the one warning
  # line is expected. Match the ::warning:: marker (the cleanup wording
  # differs from the import wording) plus the shared "TLS verification is
  # OFF" phrase.
  echo
  echo "=== insecure-TLS warning, no request ==="
  local results_insecure="${PROOF_DIR}/results-insecure.json" insecure_state
  run_body import-insecure "$b_import" \
    "DD_URL=https://127.0.0.1:9" \
    "DD_TOKEN=$(cat "$importer_tok")" \
    "DD_PRODUCT=${PROOF_PRODUCT}" \
    "DD_PRODUCT_TYPE=${PROOF_PRODUCT_TYPE}" \
    "DD_INSECURE=true" \
    "DD_CA_CERT=" \
    "DD_REPORTS_DIR=${reports_none}" \
    "DD_RESULTS_FILE=${results_insecure}" \
    "GITHUB_ACTOR=proof-actor" \
    "GITHUB_EVENT_NAME=pull_request" \
    "GITHUB_HEAD_REF=${PROOF_BRANCH_A}" \
    "GITHUB_REF_NAME=27/merge" \
    "GITHUB_SHA=${PROOF_SHA}" \
    "GITHUB_RUN_ID=${PROOF_RUN_ID}" \
    "GITHUB_SERVER_URL=${PROOF_SERVER_URL}" \
    "GITHUB_REPOSITORY=${PROOF_REPOSITORY}"
  sed -e 's/^/    | /' "$BODY_LOG"
  insecure_state="$(jq -r '"\(.tls_mode) attempted=\(.attempted | length) skipped=\(.skipped | length)"' "$results_insecure" 2>/dev/null || echo "no-result-file")"
  if [ "$BODY_RC" -eq 0 ] && grep -q '::warning::' "$BODY_LOG" && grep -q 'TLS verification is OFF' "$BODY_LOG" \
    && [ "$insecure_state" = "insecure attempted=0 skipped=8" ]; then
    proof_pass "P-INSECURE" "DD_INSECURE=true -> ::warning:: line printed, exit 0, ${insecure_state}: no request was made"
  else
    proof_fail "P-INSECURE" "DD_INSECURE=true: exit ${BODY_RC}, results '${insecure_state}', warning marker $(grep -c '::warning::' "$BODY_LOG" || true); expected exit 0, the ::warning:: line and 'insecure attempted=0 skipped=8'"
  fi

  # ── P-HTTP (27-11, CR-01) ─────────────────────────────────────────────────
  prove_http_refusal "$bodies" "$DD_PROOF_REPORTS"

  # ── Phase 28: dedup and triage (28-03) ────────────────────────────────────
  # After every Phase 27 assertion, which all ran with dedup still off.
  prove_dedup_triage "$bodies" "$admin_hdr" "$importer_tok" "$ca_pem"

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
  --scheme-only)
    [ "$#" -eq 1 ] || usage
    mode_scheme_only
    ;;
  "" | -*)
    usage
    ;;
  *)
    [ "$#" -eq 1 ] || usage
    mode_entry "$1"
    ;;
esac
