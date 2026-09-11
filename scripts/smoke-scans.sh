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
# JSON report formats).
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
#
# SC2329 is suppressed because this helper has no call site yet: the npm,
# pip-audit and tflint sub-scan sections that use it are added in the next
# plan, and adding scan behaviour here would mean this refactor could no
# longer be shown to be behaviour-preserving. Remove the suppression once
# those call sites exist.
# shellcheck disable=SC2329
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
# sub-scan sections; nothing here installs anything.
HAVE_PIP_AUDIT=1
HAVE_TFLINT=1
if ! command -v pip-audit &>/dev/null; then
  HAVE_PIP_AUDIT=0
  echo "NOTE: optional binary 'pip-audit' not found on PATH — the SCA-02 Python sub-check will be SKIPPED, not passed. Install it with: pipx install pip-audit"
  SKIPPED+=("SCA-02 (pip-audit): binary not found on PATH")
fi
if ! command -v tflint &>/dev/null; then
  HAVE_TFLINT=0
  echo "NOTE: optional binary 'tflint' not found on PATH — the SCA-03 Terraform sub-check will be SKIPPED, not passed. Install it with: brew install tflint"
  SKIPPED+=("SCA-03 (tflint): binary not found on PATH")
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
require_success "trivy-fs-convert" trivy convert --format sarif -o "$OUT/trivy-fs.sarif" "$OUT/trivy-fs.json"
require_nonempty "trivy-fs-sarif" "$OUT/trivy-fs.sarif"
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

# --- 5. Container: docker build + Trivy image -----------------------------
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

# --- 6. Secrets: Gitleaks (git history mode) -------------------------------
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
