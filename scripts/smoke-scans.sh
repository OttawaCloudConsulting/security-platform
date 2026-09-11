#!/usr/bin/env bash
set -euo pipefail

# Local pass/fail gate for the five Phase 15 CI scan jobs (SAST, IaC, SCA,
# container, secrets) and the three Phase 16 SCA ecosystem sub-scans (npm
# audit, pip-audit, tflint). Runs the exact CI-shaped scanner commands against
# the real checkout and fails if a scanner exits 0 (nothing found), exits with
# a code that means "tool error" rather than "findings", or writes an empty or
# malformed report. An empty report that reads as "clean" is the failure mode
# this script exists to catch — it must never be possible to pass green with
# a skipped or stubbed scan.
#
# Not every tool signals findings with exit code 1: tflint uses 2 and reserves
# 1 for application errors. Scanners are therefore run through
# `run_scan_rc <expected_rc>`, and reports are checked for the top-level key a
# real report carries, so a tool's error object cannot be read as a clean scan.
#
# A sub-check whose tool is absent from this workstation is reported as
# SKIPPED and listed separately in the summary. A skip is never a pass.
#
# The SCA section runs `trivy fs` TWICE with identical flags, mirroring what
# CI does: once with --format json (the report retained as a build artifact)
# and once with --format sarif (the report uploaded to code scanning). It is
# deliberately NOT a scan plus a conversion — `trivy convert` writes an
# originalUriBaseIds.ROOTPATH pointing at its input JSON file rather than at
# the scan root, so the SCA path emits SARIF directly and asserts that base.
# Both invocations are scanners and are scored with scanner semantics.
#
# Usage:
#   bash scripts/smoke-scans.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

FAILURES=()
# SKIPPED: sub-checks that did not run (optional tool absent, or the ecosystem
# is not present in this repository). Reported separately from FAILURES and
# separately from passes — a skip must never read as a pass — and it never
# affects the exit status.
SKIPPED=()
# SCANS_PASSED: gated scan runs that produced the expected findings exit code.
# Counted from the run itself so the summary cannot go stale as sub-scans are
# added. Note it counts runs, not tools: Gitleaks is scanned twice (SARIF and
# JSON report formats), and so is Trivy fs (JSON for retention, SARIF for
# code scanning).
SCANS_PASSED=0

# run_scan_rc: capture a scanner's exit code without tripping `set -e`, and
# compare it against the exit code that means "this scanner found something".
#   rc == expected_rc        -> PASS, a real finding was made
#   rc == 0 (expected != 0)  -> FAIL, the tool found nothing: the exact
#                               failure this script exists to catch
#   anything else            -> FAIL, a tool/infrastructure error, not a
#                               scan verdict
# The expected code is a parameter rather than a per-tool special case because
# it genuinely differs per tool: npm audit, pip-audit, Trivy, Semgrep, Checkov
# and Gitleaks all use 1; tflint uses 2 for findings and 1 for an application
# error, so passing it through the rc=1 default would score a healthy tflint
# run as "tool/infrastructure error".
run_scan_rc() {
  local expected_rc="$1"
  local label="$2"
  shift 2
  local rc=0
  "$@" || rc=$?
  if [[ "$rc" -eq "$expected_rc" ]]; then
    echo "==> ${label}: exit=${rc} (PASS - finding(s) detected)"
    SCANS_PASSED=$((SCANS_PASSED + 1))
  elif [[ "$rc" -eq 0 ]]; then
    echo "==> ${label}: exit=${rc} (FAIL - scanner found nothing)"
    FAILURES+=("${label}: scanner exited 0 (no findings)")
  else
    echo "==> ${label}: exit=${rc} (FAIL - tool/infrastructure error)"
    FAILURES+=("${label}: scanner exited ${rc} (tool/infrastructure error)")
  fi
  return 0
}

# run_scan: the common case — a scanner that signals "findings present" with
# exit code 1. rc=1-as-PASS is a default, not a law; see run_scan_rc above.
# Use `run_scan_rc 2 …` for tflint rather than adding a special case here.
run_scan() {
  run_scan_rc 1 "$@"
}

# require_success: run a command that is expected to exit 0 (e.g. a docker
# build, or `trivy convert`, which are infrastructure/format-conversion steps,
# not scan verdicts). Any non-zero exit is a hard failure, distinct from
# run_scan's inverted PASS-on-1 semantics for actual scanners.
require_success() {
  local label="$1"
  shift
  local rc=0
  "$@" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    echo "==> ${label}: exit=${rc} (PASS - completed successfully)"
  else
    echo "==> ${label}: exit=${rc} (FAIL - expected exit 0)"
    FAILURES+=("${label}: exited ${rc}, expected 0")
  fi
  return 0
}

# require_nonempty: assert a report file exists and has non-zero size.
require_nonempty() {
  local label="$1"
  local file="$2"
  if [[ -s "$file" ]]; then
    echo "    report OK: ${file} ($(wc -c <"$file" | tr -d ' ') bytes)"
  else
    echo "    report MISSING/EMPTY: ${file}"
    FAILURES+=("${label}: report missing or empty (${file})")
  fi
}

# require_parses_json: assert a report file exists, parses as JSON, and
# carries <required_key> at its top level.
#
# This is an assertion, not a print helper. It pushes to FAILURES exactly like
# require_nonempty and must never swallow its own result with `|| true` — an
# assertion that ignores its own failure IS the false-pass mechanism this
# script exists to prevent. It is what discriminates a real report from a tool
# error object: `npm audit` writes {"error":{"code":"ENOLOCK",...}} on a
# directory with no lockfile, which is non-empty, valid JSON, and would sail
# past require_nonempty; a real report carries "auditReportVersion".
#
# Usage: require_parses_json <label> <file> <required_key>
require_parses_json() {
  local label="$1"
  local file="$2"
  local required_key="$3"
  if [[ ! -f "$file" ]]; then
    echo "    report MISSING: ${file}"
    FAILURES+=("${label}: report missing (${file})")
    return 0
  fi
  local rc=0
  python3 - "$file" "$required_key" <<'PY' || rc=$?
import json
import sys

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path) as handle:
        data = json.load(handle)
except Exception as exc:  # noqa: BLE001 - any parse/IO failure is a hard fail
    print("    report NOT VALID JSON: {} ({})".format(path, exc))
    sys.exit(2)

keys = list(data.keys()) if isinstance(data, dict) else []
if key not in keys:
    print("    report MISSING TOP-LEVEL KEY {!r}: {} (top-level keys: {})".format(
        key, path, sorted(keys)[:8] or type(data).__name__))
    sys.exit(3)

print("    report OK: {} (valid JSON, top-level {!r} present)".format(path, key))
PY
  if [[ "$rc" -ne 0 ]]; then
    FAILURES+=("${label}: report is not JSON with top-level '${required_key}' (${file})")
  fi
}

# npm_audit_to_file / tflint_sarif_to_file: thin wrappers, because run_scan_rc
# has to observe each scanner's own exit code and neither tool can be handed
# to it directly. `npm audit` must run in the lockfile's own directory and
# writes its report to stdout; tflint writes SARIF to stdout as well and has
# no output-file flag at all. Wrapping keeps shell redirection out of
# run_scan_rc's argument list.
#
# Both are invoked indirectly — as the command argument of `run_scan_rc`,
# which runs it as "$@" — and shellcheck's usage detection only counts a name
# in command position, which is the case its own SC2329 text calls out ("or
# ignored if invoked indirectly"). The suppression is scoped to these two
# definitions and describes a real, checkable call site: `grep -n
# 'npm_audit_to_file\|tflint_sarif_to_file' scripts/smoke-scans.sh` shows one
# run_scan_rc call for each. Delete the wrapper and the directive together if
# a future refactor removes the call.
# shellcheck disable=SC2329
npm_audit_to_file() {
  # Subshell so the cd cannot leak into the rest of the gate. --audit-level
  # gates the EXIT CODE only; it does not filter the report, so the severity
  # histogram asserted below is complete either way.
  (cd "$1" && npm audit --audit-level=high --json >"$2")
}

# --recursive is mandatory, not stylistic: a repo-root tflint without it sees
# zero .tf files and exits 0 — a silent false pass. No soft-fail flag is
# passed either; Phase 15's D-04 keeps native severity semantics so Phase 18
# does not have to re-derive thresholds.
# shellcheck disable=SC2329  # invoked indirectly via run_scan_rc; see above
tflint_sarif_to_file() {
  tflint --recursive --format sarif >"$1"
}

# Preflight, hard tier: fail fast, naming the missing binary, rather than
# surfacing a confusing scanner error partway through the run. Every binary
# here drives a check the gate cannot render a verdict without. `npm` is in
# this tier because it ships with node, which any workstation that ran
# workstation/setup.sh already has.
for bin in semgrep checkov trivy gitleaks docker python3 npm; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 1
  fi
done

# Preflight, soft tier: pip-audit and tflint each drive exactly one Phase 16
# sub-check. A clean workstation without them must not hard-fail the whole
# gate — but the skip has to be loud, named, and accounted for as SKIPPED so
# it can never be mistaken for a pass. The HAVE_* flags are read by the
# sub-scan sections, which are also where the SKIPPED entry is appended so a
# single absent tool cannot be counted as two skipped sub-checks; nothing here
# installs anything.
HAVE_PIP_AUDIT=1
HAVE_TFLINT=1
if ! command -v pip-audit &>/dev/null; then
  HAVE_PIP_AUDIT=0
  echo "NOTE: optional binary 'pip-audit' not found on PATH — the SCA-02 Python sub-check will be SKIPPED, not passed. Install it with: pipx install pip-audit"
fi
if ! command -v tflint &>/dev/null; then
  HAVE_TFLINT=0
  echo "NOTE: optional binary 'tflint' not found on PATH — the SCA-03 Terraform sub-check will be SKIPPED, not passed. Install it with: brew install tflint"
fi
echo "Optional tooling: pip-audit=${HAVE_PIP_AUDIT} tflint=${HAVE_TFLINT}"

echo "Report directory: ${OUT}"
echo

# --- 1. SAST: Semgrep ---------------------------------------------------
echo "--- SAST (Semgrep) ---"
run_scan "semgrep" semgrep scan --config p/default --metrics=off --error \
  --json-output="$OUT/semgrep-results.json" \
  --sarif-output="$OUT/semgrep.sarif" \
  .
require_nonempty "semgrep-json" "$OUT/semgrep-results.json"
require_nonempty "semgrep-sarif" "$OUT/semgrep.sarif"
python3 -c "
import json
with open('$OUT/semgrep-results.json') as f:
    data = json.load(f)
results = data.get('results', [])
print(f'    semgrep findings: {len(results)}')
for r in results:
    print(f\"      rule={r.get('check_id')} path={r.get('path')}\")
" || true
echo

# --- 2. IaC: Checkov ------------------------------------------------------
echo "--- IaC (Checkov) ---"
run_scan "checkov" checkov -d . --quiet --compact \
  --output cli --output json --output sarif \
  --output-file-path "console,$OUT/checkov-results.json,$OUT/checkov.sarif"
require_nonempty "checkov-json" "$OUT/checkov-results.json"
require_nonempty "checkov-sarif" "$OUT/checkov.sarif"
python3 -c "
import json
with open('$OUT/checkov-results.json') as f:
    data = json.load(f)
# Checkov emits a list when multiple frameworks report, a dict for one.
records = data if isinstance(data, list) else [data]
total_failed = 0
for rec in records:
    summary = rec.get('summary', {})
    failed = summary.get('failed', 0)
    check_type = rec.get('check_type', 'unknown')
    print(f'    checkov failed ({check_type}): {failed}')
    total_failed += failed
print(f'    checkov total failed: {total_failed}')
" || true
echo

# --- 3. SCA: Trivy filesystem (unfiltered, record only, not gated) -------
echo "--- SCA (Trivy fs, unfiltered - record only) ---"
rc=0
trivy fs . --scanners vuln --format json -o "$OUT/trivy-fs-all.json" || rc=$?
echo "==> trivy-fs-unfiltered: exit=${rc} (not gated, informational only)"
require_nonempty "trivy-fs-unfiltered-json" "$OUT/trivy-fs-all.json"
python3 -c "
import json
with open('$OUT/trivy-fs-all.json') as f:
    data = json.load(f)
total = sum(len(r.get('Vulnerabilities', []) or []) for r in (data.get('Results') or []))
print(f'    trivy fs unfiltered total vulnerabilities: {total}')
" || true
echo

# --- 4. SCA: Trivy filesystem (gated, exact CI flags) --------------------
echo "--- SCA (Trivy fs, HIGH/CRITICAL - gated, exact CI form) ---"
run_scan "trivy-fs" trivy fs . --scanners vuln --format json \
  -o "$OUT/trivy-fs.json" --exit-code 1 --severity HIGH,CRITICAL
require_nonempty "trivy-fs-json" "$OUT/trivy-fs.json"
# run_scan, NOT require_success: this is a SCANNER invocation carrying the
# same flags as the JSON run above, so exit 1 means "findings present" and
# require_success would score a healthy findings run as a FAIL — the same
# verdict inversion Phase 15 hit with `docker build` and `trivy convert`.
# require_success remains correct for the container job's
# "trivy-image-convert" below, which is genuinely an exit-0 conversion step.
run_scan "trivy-fs-sarif" trivy fs . --scanners vuln --format sarif \
  -o "$OUT/trivy-fs.sarif" --exit-code 1 --severity HIGH,CRITICAL
require_nonempty "trivy-fs-sarif" "$OUT/trivy-fs.sarif"
# ROOTPATH regression guard. `trivy convert` writes
# originalUriBaseIds.ROOTPATH = file:///<cwd>/trivy-fs.json/ — the INPUT FILE,
# not the scan root (measured 2026-09-11, trivy 0.74.0), which makes every
# uploaded result resolve to a path that does not exist. This assertion is
# what stops a future "simplify it back to trivy convert" from silently
# reintroducing that form.
rootpath_rc=0
python3 - "$OUT/trivy-fs.sarif" <<'PY' || rootpath_rc=$?
import json
import sys

path = sys.argv[1]
try:
    with open(path) as handle:
        data = json.load(handle)
except Exception as exc:  # noqa: BLE001 - any parse/IO failure is a hard fail
    print("    trivy-fs SARIF unreadable: {} ({})".format(path, exc))
    sys.exit(2)

runs = data.get("runs") or []
if not runs:
    print("    trivy-fs SARIF carries no runs[]")
    sys.exit(3)
bases = runs[0].get("originalUriBaseIds") or {}
rootpath = (bases.get("ROOTPATH") or {}).get("uri")
print("    trivy-fs SARIF originalUriBaseIds.ROOTPATH: {}".format(rootpath))
if not rootpath:
    print("    ROOTPATH absent: result locations have no base to resolve against")
    sys.exit(4)
if rootpath.rstrip("/").endswith(".json"):
    print("    ROOTPATH points at a .json INPUT FILE, not the scan root -- the")
    print("    trivy convert form (Phase 17 RESEARCH Pitfall 3)")
    sys.exit(5)
PY
if [ "$rootpath_rc" -ne 0 ]; then
  FAILURES+=("trivy-fs-sarif: originalUriBaseIds.ROOTPATH absent or pointing at a .json input file (${OUT}/trivy-fs.sarif)")
fi
python3 -c "
import json
with open('$OUT/trivy-fs.json') as f:
    data = json.load(f)
total = 0
for r in (data.get('Results') or []):
    vulns = r.get('Vulnerabilities') or []
    if vulns:
        print(f\"    trivy fs (filtered) target={r.get('Target')} count={len(vulns)}\")
        total += len(vulns)
print(f'    trivy fs (filtered) total HIGH/CRITICAL vulnerabilities: {total}')
" || true
echo

# --- 5. SCA-01: npm audit (npm lockfile advisories) -----------------------
echo "--- SCA-01 (npm audit) ---"
# Detect-then-guard. `npm audit` exits 1 when it finds vulnerabilities AND
# when there is no lockfile to read (ENOLOCK), so the exit code alone cannot
# tell a real scan from a missing input: the detector decides whether this
# sub-scan applies at all, and require_parses_json decides whether what came
# back is a report or an error object.
# The list file is written into $OUT, never into the checkout: invoked with no
# argument the detector defaults to writing it into the current directory,
# which would leave an untracked file behind in the repository.
bash scripts/detect-npm.sh "$OUT/npm-lockfiles.txt"
if [ -s "$OUT/npm-lockfiles.txt" ]; then
  npm_n=0
  # The list is read on fd 3 because npm reads stdin: a scanner that consumed
  # the loop's stdin would swallow the remaining lockfile paths. The loop and
  # the numbered reports exist because a consumer repository is not guaranteed
  # to have a single manifest at its root.
  while IFS= read -r lockfile <&3; do
    [ -n "$lockfile" ] || continue
    npm_n=$((npm_n + 1))
    npm_report="$OUT/npm-audit-${npm_n}.json"
    echo "    lockfile [${npm_n}]: ${lockfile}"
    run_scan_rc 1 "npm-audit" npm_audit_to_file "$(dirname "$lockfile")" "$npm_report"
    require_nonempty "npm-audit" "$npm_report"
    # auditReportVersion is the discriminator: the {"error":{"code":"ENOLOCK"}}
    # object is non-empty, valid JSON, and exits with the same code as a real
    # report, so only the top-level key separates them.
    require_parses_json "npm-audit" "$npm_report" auditReportVersion
    # Verdict assertion, not an informational print: Criterion 1 requires
    # findings WITH severity levels, so the metadata histogram has to be shown
    # to be populated, and printed so a human reading the log sees them.
    npm_rc=0
    python3 - "$npm_report" <<'PY' || npm_rc=$?
import json
import sys

path = sys.argv[1]
try:
    with open(path) as handle:
        data = json.load(handle)
except Exception as exc:  # noqa: BLE001 - any parse/IO failure is a hard fail
    print("    npm audit report unreadable: {} ({})".format(path, exc))
    sys.exit(2)

hist = (data.get("metadata") or {}).get("vulnerabilities") or {}
print("    npm audit severity histogram: " + " ".join(
    "{}={}".format(name, hist.get(name, 0))
    for name in ("info", "low", "moderate", "high", "critical", "total")))
for name, entry in sorted((data.get("vulnerabilities") or {}).items()):
    print("      package={} severity={}".format(name, entry.get("severity")))
gated = int(hist.get("high", 0)) + int(hist.get("critical", 0))
print("    npm audit high+critical: {}".format(gated))
if gated <= 0:
    print("    npm audit reports no high/critical entry in metadata.vulnerabilities")
    sys.exit(3)
PY
    if [ "$npm_rc" -ne 0 ]; then
      FAILURES+=("npm-audit: no high/critical entry in metadata.vulnerabilities (${npm_report})")
    fi
  done 3<"$OUT/npm-lockfiles.txt"
else
  echo "    SKIPPED: no npm lockfile in this repository"
  SKIPPED+=("SCA-01 (npm audit): no package-lock.json in this repository")
fi
echo

# --- 6. SCA-02: pip-audit (Python advisories) -----------------------------
echo "--- SCA-02 (pip-audit) ---"
if [ "$HAVE_PIP_AUDIT" -eq 0 ]; then
  echo "    SKIPPED: pip-audit is not available on this workstation"
  SKIPPED+=("SCA-02 (pip-audit): binary not found on PATH")
else
  # Same detect-then-guard and same $OUT list-file rule as the npm section:
  # pip-audit also exits 1 both for "advisories found" and for "input file
  # missing or invalid".
  bash scripts/detect-python.sh "$OUT/py-reqs.txt"
  if [ -s "$OUT/py-reqs.txt" ]; then
    py_n=0
    while IFS= read -r reqfile <&3; do
      [ -n "$reqfile" ] || continue
      py_n=$((py_n + 1))
      py_report="$OUT/pip-audit-${py_n}.json"
      echo "    requirements [${py_n}]: ${reqfile}"
      # Locked invocation: the default resolving mode, which walks the
      # transitive closure and costs ~14 s. Flags that skip resolution or
      # demand hash-pinned requirements are deliberately absent — both
      # hard-error on any requirement a consumer repo has not pinned exactly.
      run_scan_rc 1 "pip-audit" pip-audit -r "$reqfile" --format json \
        --progress-spinner=off -o "$py_report"
      require_nonempty "pip-audit" "$py_report"
      # On its error paths pip-audit writes no output file at all, so the
      # emptiness check above already discriminates; 'dependencies' is the
      # top-level key a real report carries.
      require_parses_json "pip-audit" "$py_report" dependencies
      # Verdict assertion. NOTE for Phase 17/18: pip-audit emits NO severity
      # and NO CVSS field anywhere in its JSON — unlike the npm section above,
      # this count is over advisory IDs, and no severity threshold can be
      # derived from this report. Do not infer pip-audit's shape from npm's.
      py_rc=0
      python3 - "$py_report" <<'PY' || py_rc=$?
import json
import sys

path = sys.argv[1]
try:
    with open(path) as handle:
        data = json.load(handle)
except Exception as exc:  # noqa: BLE001 - any parse/IO failure is a hard fail
    print("    pip-audit report unreadable: {} ({})".format(path, exc))
    sys.exit(2)

deps = data.get("dependencies") or []
entries = 0
ids = set()
for dep in deps:
    vulns = dep.get("vulns") or []
    if vulns:
        print("      package={} version={} advisories={}".format(
            dep.get("name"), dep.get("version"), len(vulns)))
    entries += len(vulns)
    ids.update(v.get("id") for v in vulns)
print("    pip-audit resolved dependencies: {}".format(len(deps)))
print("    pip-audit advisory entries: {} ({} unique ids)".format(entries, len(ids)))
if entries <= 0:
    print("    pip-audit reports no advisories across dependencies[]")
    sys.exit(3)
PY
      if [ "$py_rc" -ne 0 ]; then
        FAILURES+=("pip-audit: no advisories across dependencies[] (${py_report})")
      fi
    done 3<"$OUT/py-reqs.txt"
  else
    echo "    SKIPPED: no Python requirements file in this repository"
    SKIPPED+=("SCA-02 (pip-audit): no requirements*.txt in this repository")
  fi
fi
echo

# --- 7. SCA-03: tflint (provider and module pinning) ----------------------
echo "--- SCA-03 (tflint) ---"
# The verdict below is asserted on the RULE IDS, not on a finding count, and
# the missing-required_version rule (terraform_required_version) is
# deliberately NOT in the accepted set: it already fires on this fixture and
# reports an absent top-level version block, which says nothing about whether
# providers or modules are pinned. A bare "at least one finding" check would
# therefore pass with SCA-03 completely unproven.
# Recorded while measuring: tflint's default ruleset does NOT flag a floating
# range such as a >= constraint, so Criterion 3 is satisfied through missing
# constraints and unpinned module sources only.
if [ "$HAVE_TFLINT" -eq 0 ]; then
  echo "    SKIPPED: tflint is not available on this workstation"
  SKIPPED+=("SCA-03 (tflint): binary not found on PATH")
else
  bash scripts/detect-terraform.sh "$OUT/tf-files.txt"
  if [ -s "$OUT/tf-files.txt" ]; then
    # run_scan_rc 2, not run_scan: tflint signals findings with exit code 2
    # and reserves 1 for an application error, so the rc=1 default would score
    # a healthy tflint run as a tool/infrastructure error.
    run_scan_rc 2 "tflint" tflint_sarif_to_file "$OUT/tflint.sarif"
    require_nonempty "tflint" "$OUT/tflint.sarif"
    require_parses_json "tflint" "$OUT/tflint.sarif" runs
    tf_rc=0
    python3 - "$OUT/tflint.sarif" <<'PY' || tf_rc=$?
import json
import sys

path = sys.argv[1]
PINNING = {
    "terraform_required_providers",
    "terraform_module_version",
    "terraform_module_pinned_source",
}
try:
    with open(path) as handle:
        data = json.load(handle)
except Exception as exc:  # noqa: BLE001 - any parse/IO failure is a hard fail
    print("    tflint SARIF unreadable: {} ({})".format(path, exc))
    sys.exit(2)

found = set()
for run in data.get("runs") or []:
    for result in run.get("results") or []:
        found.add(result.get("ruleId"))
print("    tflint rule ids: {}".format(sorted(i for i in found if i)))
hits = sorted(PINNING & found)
print("    tflint pinning rule ids: {}".format(hits))
if not hits:
    print("    tflint reported no pinning rule id from {}".format(sorted(PINNING)))
    sys.exit(3)
PY
    if [ "$tf_rc" -ne 0 ]; then
      FAILURES+=("tflint: no pinning rule id in the SARIF results (${OUT}/tflint.sarif)")
    fi
  else
    echo "    SKIPPED: no Terraform files in this repository"
    SKIPPED+=("SCA-03 (tflint): no .tf files in this repository")
  fi
fi
echo

# --- 8. Container: docker build + Trivy image -----------------------------
echo "--- Container (docker build + Trivy image) ---"
docker_rc=0
docker build -f fixtures/Dockerfile -t scan-fixture:smoke fixtures/ || docker_rc=$?
if [[ "$docker_rc" -eq 0 ]]; then
  echo "==> docker-build: exit=${docker_rc} (PASS - completed successfully)"
else
  echo "==> docker-build: exit=${docker_rc} (FAIL - expected exit 0)"
  FAILURES+=("docker-build: exited ${docker_rc}, expected 0")
fi

if [[ "$docker_rc" -eq 0 ]]; then
  run_scan "trivy-image" trivy image scan-fixture:smoke --scanners vuln --format json \
    -o "$OUT/trivy-image.json" --exit-code 1 --severity HIGH,CRITICAL
  require_nonempty "trivy-image-json" "$OUT/trivy-image.json"
  require_success "trivy-image-convert" trivy convert --format sarif -o "$OUT/trivy-image.sarif" "$OUT/trivy-image.json"
  require_nonempty "trivy-image-sarif" "$OUT/trivy-image.sarif"
  if grep -q "no longer supported by the distribution" "$OUT/trivy-image.json" 2>/dev/null; then
    echo "    FAIL: EOL base image detected (\"no longer supported by the distribution\")"
    FAILURES+=("trivy-image: EOL base image warning found - job would report zero")
  else
    echo "    OK: no EOL base image warning found"
  fi
  python3 -c "
import json
with open('$OUT/trivy-image.json') as f:
    data = json.load(f)
total = sum(len(r.get('Vulnerabilities', []) or []) for r in (data.get('Results') or []))
print(f'    trivy image (filtered) total HIGH/CRITICAL vulnerabilities: {total}')
" || true
else
  echo "    SKIPPED: trivy-image (docker build did not succeed)"
  FAILURES+=("trivy-image: skipped because docker-build failed")
fi
echo

# --- 9. Secrets: Gitleaks (git history mode) -------------------------------
echo "--- Secrets (Gitleaks, git history mode) ---"
run_scan "gitleaks-sarif" gitleaks git . --no-banner --redact \
  --report-format sarif --report-path "$OUT/gitleaks.sarif"
require_nonempty "gitleaks-sarif" "$OUT/gitleaks.sarif"
run_scan "gitleaks-json" gitleaks git . --no-banner --redact \
  --report-format json --report-path "$OUT/gitleaks-results.json"
require_nonempty "gitleaks-json" "$OUT/gitleaks-results.json"
python3 -c "
import json
with open('$OUT/gitleaks-results.json') as f:
    data = json.load(f)
print(f'    gitleaks findings: {len(data)}')
for finding in data:
    print(f\"      rule={finding.get('RuleID')} file={finding.get('File')} line={finding.get('StartLine')}\")
" || true
echo

# --- Criterion 4: clean-skip negative test --------------------------------
# This is the ONLY place the skip path can be observed, and it cannot be
# replaced by a live CI observation: this repository contains npm, Python and
# Terraform fixtures, so every CI run takes the FOUND branch of all three
# detectors and never exercises a skip at all. Do not delete this section as
# redundant on the grounds that "CI already covers the detectors".
# It runs the same detector scripts CI runs — not a copy of their logic —
# from inside a throwaway git repository, with GITHUB_OUTPUT explicitly unset
# so the workstation case (no GitHub step-output file) is the one under test.
echo "--- Criterion 4: clean-skip negative test ---"
PROBE_DIR="$(mktemp -d)"
# The existing EXIT trap is extended rather than joined by a second one: bash
# replaces an EXIT trap instead of chaining it, so a second `trap … EXIT`
# would silently leak $OUT. The directory is also removed explicitly at the
# end of this section; the trap only covers an abnormal exit.
trap 'rm -rf "$OUT" "$PROBE_DIR"' EXIT
(cd "$PROBE_DIR" && git init -q)
echo "    probe repository: ${PROBE_DIR}"
for probe in npm python terraform; do
  probe_rc=0
  probe_out="$(cd "$PROBE_DIR" && env -u GITHUB_OUTPUT bash "$REPO_ROOT/scripts/detect-${probe}.sh" 2>&1)" || probe_rc=$?
  # BOTH conditions are required. A detector that exits 0 while printing
  # nothing has skipped silently — the invisible false pass this test exists
  # to catch — so the exit code alone is not evidence of a clean skip.
  if [ "$probe_rc" -eq 0 ] && printf '%s\n' "$probe_out" | grep -q '^SKIP:'; then
    echo "==> skip-${probe}: exit=${probe_rc} (PASS - clean skip, rc=0 with a SKIP: line)"
    echo "    ${probe_out}"
  else
    echo "==> skip-${probe}: exit=${probe_rc} (FAIL - expected rc=0 and a line matching ^SKIP:)"
    echo "    observed output: ${probe_out:-<none>}"
    FAILURES+=("skip-${probe}: expected rc=0 and a ^SKIP: line in an empty repository, observed rc=${probe_rc} and output: ${probe_out:-<none>}")
  fi
done
# The skip branch must also leave no list file behind: a zero-length or stale
# list file would make a downstream `[ -s … ]` guard read the wrong answer.
for leftover in npm-lockfiles.txt py-reqs.txt tf-files.txt; do
  if [ -e "${PROBE_DIR}/${leftover}" ]; then
    echo "    FAIL: detector wrote ${leftover} on the skip branch"
    FAILURES+=("skip-probe: ${leftover} was written in the empty repository; the skip branch must write no list file")
  fi
done
echo "    no list file written on the skip branch: OK"
rm -rf "$PROBE_DIR"
echo

# --- Summary ---------------------------------------------------------------
echo "=== Summary ==="
# Skips are printed before the verdict, on both the pass and the fail path,
# under their own heading. They are not failures and they are not passes.
if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo "SKIPPED - ${#SKIPPED[@]} sub-check(s) did not run. A SKIP IS NOT A PASS:"
  for s in "${SKIPPED[@]}"; do
    echo "  - ${s}"
  done
  echo
fi
if [ "${#FAILURES[@]}" -gt 0 ]; then
  echo "FAILED - one or more scanners did not produce the expected result:"
  for f in "${FAILURES[@]}"; do
    echo "  - ${f}"
  done
  exit 1
else
  echo "ALL PASS - ${SCANS_PASSED} gated scan run(s) produced real, non-empty findings; ${#SKIPPED[@]} sub-check(s) skipped (not passed)."
  exit 0
fi
