#!/usr/bin/env bash
set -euo pipefail

# Local pass/fail gate for the five Phase 15 CI scan jobs (SAST, IaC, SCA,
# container, secrets). Runs the exact CI-shaped scanner commands against the
# real checkout and fails if any scanner exits 0 (nothing found) or writes an
# empty report. An empty report that reads as "clean" is the failure mode
# this script exists to catch — it must never be possible to pass green with
# a skipped or stubbed scan.
#
# Usage:
#   bash scripts/smoke-scans.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

FAILURES=()

# run_scan: capture a scanner's exit code without tripping `set -e`. Exit
# code 1 is the expected PASS (a real finding was made). Exit code 0 means
# the tool found nothing — the exact failure this script exists to catch.
# Anything else is a tool/infrastructure error, not a scan verdict.
run_scan() {
  local label="$1"
  shift
  local rc=0
  "$@" || rc=$?
  if [[ "$rc" -eq 1 ]]; then
    echo "==> ${label}: exit=${rc} (PASS - finding(s) detected)"
  elif [[ "$rc" -eq 0 ]]; then
    echo "==> ${label}: exit=${rc} (FAIL - scanner found nothing)"
    FAILURES+=("${label}: scanner exited 0 (no findings)")
  else
    echo "==> ${label}: exit=${rc} (FAIL - tool/infrastructure error)"
    FAILURES+=("${label}: scanner exited ${rc} (tool/infrastructure error)")
  fi
  return 0
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

# Preflight: fail fast, naming the missing binary, rather than surfacing a
# confusing scanner error partway through the run.
for bin in semgrep checkov trivy gitleaks docker python3; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 1
  fi
done

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
if [ "${#FAILURES[@]}" -gt 0 ]; then
  echo "FAILED - one or more scanners did not produce the expected result:"
  for f in "${FAILURES[@]}"; do
    echo "  - ${f}"
  done
  exit 1
else
  echo "ALL PASS - all five scanners produced real, non-empty findings."
  exit 0
fi
