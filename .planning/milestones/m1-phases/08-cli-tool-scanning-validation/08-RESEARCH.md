# Phase 8: CLI Tool Scanning Validation - Research

**Researched:** 2026-03-16
**Domain:** Security CLI tool scanning, JSON report generation, local validation
**Confidence:** HIGH

## Summary

Phase 8 validates that all 6 security CLI tools (Trivy, Syft, Grype, Semgrep, Checkov, Gitleaks) can run real scans against the aws-zabbix-monitoring-solution repository and produce machine-readable JSON output. All tools are already installed and on PATH from Phases 5-7. This phase is purely execution and documentation -- run each tool, capture JSON output to `reports/`, verify the files exist and contain valid content.

The commands are well-documented in the main doc (`development-security-stack-option-1.md`). The key work is: create the `reports/` directory with a `.gitignore`, run 6 scan commands with JSON output flags, verify each report file exists with size > 0, then add "Validated" notes to the main doc following the Phase 6/7 documentation pattern.

One important finding: the CONTEXT.md references a `.gitleaksignore` in aws-zabbix from Phase 5, but this file does not exist at `aws-zabbix-monitoring-solution/.gitleaksignore`. Gitleaks may produce false positive findings, but this is acceptable because Phase 8 validates "can it scan and produce JSON" not "is the codebase clean." Findings are expected and valid.

**Primary recommendation:** Execute 6 scan commands in the aws-zabbix-monitoring-solution repo with JSON output to `reports/`, verify file existence and size, update main doc with validation notes.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Scan the aws-zabbix repository** -- real project repo with CDK TypeScript, Python, Terraform, Dockerfiles, K8s YAML; exercises all 6 tools
- **Trivy**: filesystem scan only (`trivy fs`) -- matches CI workflow usage; container image and remote repo scanning not in scope
- **Checkov**: directory scan only (`checkov -d .`) -- scans all supported frameworks; no framework-specific targeting needed
- **Semgrep**: `semgrep scan --config auto` -- default ruleset against full directory
- **Grype**: `grype dir:.` -- filesystem vulnerability scan
- **Syft**: `syft dir:.` -- SBOM generation in CycloneDX-JSON format
- **Gitleaks**: `gitleaks detect --source .` -- full repository secrets scan
- **Write JSON reports to aws-zabbix/reports/** directory
- **Commit reports/.gitignore** to establish the convention -- JSON files are git-ignored, directory persists
- **Filenames match M2 CI naming convention**: `semgrep-results.json`, `checkov-results.json`, `trivy-results.json`, `grype-results.json`, `gitleaks-results.json`, `sbom.json`
- **Permissive -- no fail flags** -- all tools run to completion regardless of findings
- **Validation check**: file exists and size > 0 -- sufficient for validation purposes
- **Empty results are valid** -- an empty findings array is still valid JSON output
- **Add "Local validation" note to each tool's section** in `docs/development-security-stack-option-1.md`
- **Just confirm success**: "Validated: [tool] scan completed, JSON output produced (2026-03-16)" -- no finding counts
- **Syft validation note**: mention CycloneDX-JSON format specifically

### Claude's Discretion
- Exact placement of validation notes within each tool's section
- Order of tool execution (any order is fine -- no dependencies between scans)
- Whether to run Grype against the Syft SBOM or against the directory directly (both produce JSON)
- Handling of any tool-specific warnings or non-fatal errors during scans

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TOOL-07 | Each tool can run a basic scan against the local repository without errors | All 6 tools on PATH; exact scan commands documented in main doc; aws-zabbix-monitoring-solution is the target repo |
| TOOL-08 | Each tool can generate a JSON report (needed for M2 CI and M4 DefectDojo import) | JSON output flags verified for all 6 tools; filenames match M2 CI convention |
</phase_requirements>

## Standard Stack

### Core -- Scan Commands
| Tool | Scan Command | JSON Output Flag | Output File |
|------|-------------|-----------------|-------------|
| Trivy | `trivy fs --scanners vuln .` | `--format json --output reports/trivy-results.json` | `trivy-results.json` |
| Syft | `syft dir:.` | `-o cyclonedx-json=reports/sbom.json` | `sbom.json` |
| Grype | `grype dir:.` | `-o json > reports/grype-results.json` | `grype-results.json` |
| Semgrep | `semgrep scan --config auto .` | `--json --output reports/semgrep-results.json` | `semgrep-results.json` |
| Checkov | `checkov -d .` | `-o json > reports/checkov-results.json` | `checkov-results.json` |
| Gitleaks | `gitleaks detect --source .` | `--report-path reports/gitleaks-results.json --report-format json` | `gitleaks-results.json` |

### Full Commands (ready to execute)
```bash
# All commands run from aws-zabbix-monitoring-solution root
# Target repo: /Users/christian/git-repos/OCC-github/aws-zabbix-monitoring-solution

# 1. Create reports directory
mkdir -p reports

# 2. Trivy -- filesystem vulnerability scan
trivy fs --scanners vuln --format json --output reports/trivy-results.json .

# 3. Syft -- SBOM generation (CycloneDX-JSON)
syft dir:. -o cyclonedx-json=reports/sbom.json

# 4. Grype -- SCA vulnerability scan
grype dir:. -o json > reports/grype-results.json

# 5. Semgrep -- SAST scan
semgrep scan --config auto --json --output reports/semgrep-results.json .

# 6. Checkov -- IaC scan
checkov -d . -o json > reports/checkov-results.json

# 7. Gitleaks -- secrets scan
gitleaks detect --source . --report-path reports/gitleaks-results.json --report-format json
```

### Verification Commands
```bash
# Verify all 6 JSON report files exist and have content
for f in trivy-results.json sbom.json grype-results.json semgrep-results.json checkov-results.json gitleaks-results.json; do
  if [ -s "reports/$f" ]; then
    echo "PASS: $f ($(wc -c < "reports/$f") bytes)"
  else
    echo "FAIL: $f missing or empty"
  fi
done
```

## Architecture Patterns

### Reports Directory Convention
```
aws-zabbix-monitoring-solution/
  reports/
    .gitignore          # *.json -- keeps reports out of git
    trivy-results.json
    sbom.json
    grype-results.json
    semgrep-results.json
    checkov-results.json
    gitleaks-results.json
```

### reports/.gitignore Content
```
# Security scan reports -- generated locally and in CI
# JSON files are artifacts, not source code
*.json
*.sarif
```

### Documentation Update Pattern (from Phase 6/7)
Add a validation note after the existing "Verified:" version comment in each tool's setup section:
```bash
# Verified: v0.69.3 (2026-03-16) -- requires >= 0.69.2
# Validated: trivy fs scan completed, JSON output produced (2026-03-16)
```

### Documentation Update Locations
- **Trivy**: section 3, around line 266 (after install/version comment in setup code block)
- **Syft**: section 4, around line 315 (after install/version comment)
- **Grype**: section 4, around line 322 (after install/version comment)
- **Semgrep**: section 1, around line 170 (after install/version comment)
- **Checkov**: section 2, around line 219 (after install/version comment)
- **Gitleaks**: section 5, around line 371 (after install/version comment)

### Anti-Patterns to Avoid
- **Using --fail-on or --error flags:** Phase 8 is permissive. No severity gates. That is M2 CI scope.
- **Fixing or triaging findings:** This phase validates tool execution, not codebase compliance.
- **Scanning container images:** CONTEXT locks Trivy to `trivy fs` only. No `trivy image`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON validation | Custom JSON parsing scripts | `[ -s file.json ]` (file exists, size > 0) | CONTEXT.md explicitly says size > 0 is sufficient |
| Report formatting | Post-processing or jq transforms | Raw tool output | M2 CI and M4 DefectDojo consume native tool JSON formats directly |

## Common Pitfalls

### Pitfall 1: Gitleaks Exit Code on Findings
**What goes wrong:** Gitleaks exits with code 1 when it finds secrets (leaks detected). This may look like an error.
**Why it happens:** Gitleaks uses exit code 1 for "leaks found" and exit code 0 for "no leaks found." This is expected behavior, not a tool failure.
**How to avoid:** Do not treat exit code 1 as a scan failure. The JSON report will still be written. Check for the report file, not the exit code. If using `set -e` in a script, run Gitleaks with `|| true` or outside of strict mode.
**Warning signs:** "exit code 1" in output, but `gitleaks-results.json` exists and contains findings.

### Pitfall 2: Semgrep First-Run Rule Download
**What goes wrong:** First `semgrep scan --config auto` downloads the full rule registry from semgrep.dev, which takes 30-60 seconds.
**Why it happens:** `--config auto` fetches community rules from the Semgrep Registry on first use.
**How to avoid:** Just wait. This is expected. Subsequent runs use cached rules. Not an error.
**Warning signs:** Long pause before scan starts, network activity.

### Pitfall 3: Checkov JSON Output Format
**What goes wrong:** Checkov's JSON output via `-o json` writes to stdout, not a file. Must use shell redirect (`>`).
**Why it happens:** Unlike Trivy/Semgrep which have `--output` flags, Checkov's `-o json` changes the output format but still writes to stdout.
**How to avoid:** Use `checkov -d . -o json > reports/checkov-results.json` with explicit redirect.
**Warning signs:** JSON printed to terminal instead of file.

### Pitfall 4: Grype Database Download
**What goes wrong:** Grype needs to download its vulnerability database on first run (or if stale). This adds 30+ seconds.
**Why it happens:** Grype checks for DB freshness on each run and downloads updates automatically.
**How to avoid:** Just wait. Expected behavior. Not an error.
**Warning signs:** "Downloading vulnerability DB" message in output.

### Pitfall 5: Trivy Database Download
**What goes wrong:** Similar to Grype, Trivy downloads vulnerability databases on first run or when stale.
**Why it happens:** Trivy fetches vulnerability DB from GitHub releases.
**How to avoid:** Wait for download to complete. If it fails, may need to retry (network dependency).
**Warning signs:** "Downloading DB..." message.

### Pitfall 6: Gitleaks No Findings = No Report File
**What goes wrong:** If Gitleaks finds zero secrets, it may not create the report file at all (exits 0, no output).
**Why it happens:** Gitleaks only writes the report file when there are findings to report.
**How to avoid:** This is actually a success case -- zero findings means the repo has no detectable secrets. The CONTEXT.md says "empty results are valid." If the file does not exist after a clean scan, this is acceptable. The aws-zabbix repo likely HAS findings (CDK asset hashes) since the .gitleaksignore does not exist at the repo root, so the report file should be generated.
**Warning signs:** No `gitleaks-results.json` file after scan, exit code 0.

### Pitfall 7: Repo Path -- "aws-zabbix" vs actual name
**What goes wrong:** CONTEXT.md uses shorthand "aws-zabbix" but the actual repo directory is `aws-zabbix-monitoring-solution`.
**Why it happens:** Shorthand used in discussion.
**How to avoid:** Use full path: `/Users/christian/git-repos/OCC-github/aws-zabbix-monitoring-solution`
**Warning signs:** "No such file or directory" errors.

## Code Examples

### reports/.gitignore
```gitignore
# Security scan reports -- generated locally and in CI
# JSON files are artifacts, not source code
*.json
*.sarif
```

### Complete Scan Script (for reference)
```bash
#!/usr/bin/env bash
# Run all 6 security scans and generate JSON reports
# Execute from aws-zabbix-monitoring-solution root

set -u  # No set -e: some tools exit non-zero on findings

REPO_DIR="/Users/christian/git-repos/OCC-github/aws-zabbix-monitoring-solution"
REPORT_DIR="$REPO_DIR/reports"
mkdir -p "$REPORT_DIR"

cd "$REPO_DIR"

# Trivy -- filesystem vulnerability scan
trivy fs --scanners vuln --format json --output "$REPORT_DIR/trivy-results.json" .

# Syft -- SBOM generation (CycloneDX-JSON)
syft dir:. -o "cyclonedx-json=$REPORT_DIR/sbom.json"

# Grype -- SCA vulnerability scan
grype dir:. -o json > "$REPORT_DIR/grype-results.json"

# Semgrep -- SAST scan (first run downloads rules)
semgrep scan --config auto --json --output "$REPORT_DIR/semgrep-results.json" .

# Checkov -- IaC scan (stdout redirect for JSON)
checkov -d . -o json > "$REPORT_DIR/checkov-results.json"

# Gitleaks -- secrets scan (exit code 1 = findings, not error)
gitleaks detect --source . --report-path "$REPORT_DIR/gitleaks-results.json" --report-format json || true

# Verify
echo "=== Report Verification ==="
for f in trivy-results.json sbom.json grype-results.json semgrep-results.json checkov-results.json gitleaks-results.json; do
  if [ -s "$REPORT_DIR/$f" ]; then
    echo "PASS: $f ($(wc -c < "$REPORT_DIR/$f") bytes)"
  else
    echo "FAIL: $f missing or empty"
  fi
done
```

### Documentation Validation Note Pattern
```bash
# In each tool's setup code block, after the existing "Verified:" line:

# For Trivy (section 3):
# Validated: trivy fs scan completed, JSON output produced (2026-03-16)

# For Syft (section 4):
# Validated: syft SBOM generation completed, CycloneDX-JSON output produced (2026-03-16)

# For Grype (section 4):
# Validated: grype scan completed, JSON output produced (2026-03-16)

# For Semgrep (section 1):
# Validated: semgrep scan completed, JSON output produced (2026-03-16)

# For Checkov (section 2):
# Validated: checkov scan completed, JSON output produced (2026-03-16)

# For Gitleaks (section 5):
# Validated: gitleaks detect completed, JSON output produced (2026-03-16)
```

## State of the Art

No state-of-the-art changes relevant to this phase. All tool versions are current from Phases 5-7 (installed within the last day). JSON output flags are stable across versions.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell commands (scan execution + file verification) |
| Config file | none -- direct CLI execution and file checks |
| Quick run command | `ls -la reports/*.json` (verify files exist after scans) |
| Full suite command | Run all 6 scans then verify all 6 JSON files exist with size > 0 |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOOL-07 | Each tool runs a scan without errors | smoke | Run each scan command; tool completes without crash | N/A (CLI execution) |
| TOOL-08 | Each tool generates a JSON report | smoke | `[ -s reports/<filename>.json ]` for each of 6 files | N/A (file check) |

### Sampling Rate
- **Per task commit:** Verify the specific tool's JSON output file exists and has size > 0
- **Per wave merge:** Verify all 6 JSON files exist with size > 0
- **Phase gate:** All 6 scans complete, all 6 JSON files present with content

### Wave 0 Gaps
- [ ] `aws-zabbix-monitoring-solution/reports/` directory -- needs creation
- [ ] `aws-zabbix-monitoring-solution/reports/.gitignore` -- needs creation to git-ignore JSON files

## Open Questions

1. **Missing .gitleaksignore in aws-zabbix-monitoring-solution**
   - What we know: Phase 5 PLAN specified creating `.gitleaksignore` in `repos/aws-zabbix-monitoring-solution/`, STATE.md says "40 baseline false positives in aws-zabbix suppressed." However, no `.gitleaksignore` file exists at `/Users/christian/git-repos/OCC-github/aws-zabbix-monitoring-solution/.gitleaksignore`.
   - What's unclear: Whether Phase 5 work was done in a different directory structure (e.g., `repos/` subdirectory within the security-solution project) or whether the file was not committed.
   - Recommendation: Proceed with the scan regardless. Gitleaks will produce findings (potentially many false positives from CDK asset hashes), but CONTEXT.md says findings are expected and valid. The JSON report will still be generated. This is not a blocker for TOOL-07 or TOOL-08.

2. **Grype: direct scan vs SBOM consumption**
   - What we know: CONTEXT.md gives Claude discretion on whether to run `grype dir:.` or `grype sbom:reports/sbom.json`
   - Recommendation: Run `grype dir:.` for simplicity and independence from Syft execution order. Both produce equivalent JSON output. Direct scan is more robust (no dependency on prior step).

## Sources

### Primary (HIGH confidence)
- Main doc `docs/development-security-stack-option-1.md` lines 181-185 (Semgrep JSON), 237-241 (Checkov JSON), 274-295 (Trivy scan commands), 329-349 (Syft/Grype commands), 379-380 (Gitleaks JSON)
- Main doc lines 1488-1584 (CI workflow with canonical JSON filenames)
- Phase 8 CONTEXT.md -- locked decisions on scan commands and filenames
- Direct filesystem verification: aws-zabbix-monitoring-solution exists, reports/ does not yet exist, .gitleaksignore does not exist

### Secondary (MEDIUM confidence)
- Phase 6/7 RESEARCH.md and PLAN.md patterns for documentation updates
- STATE.md accumulated decisions for tool versions and installation paths
- Milestone 1 done criteria (lines 90-91): "Each tool can run a basic scan" and "generate a JSON report"

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all commands documented in main doc, tools verified on PATH from prior phases
- Architecture: HIGH -- straightforward execution phase, directory convention well-defined
- Pitfalls: HIGH -- exit codes, database downloads, and output redirection patterns are well-known CLI behaviors

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (tool versions and JSON output flags are stable)
