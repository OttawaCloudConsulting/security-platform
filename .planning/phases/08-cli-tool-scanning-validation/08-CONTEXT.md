# Phase 8: CLI Tool Scanning Validation - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Run each of the 6 security CLI tools (Trivy, Syft, Grype, Semgrep, Checkov, Gitleaks) against a real codebase and verify they produce machine-readable JSON output. This validates TOOL-07 (scan without errors) and TOOL-08 (JSON report generation). This phase does NOT enforce severity thresholds or gate on findings — that's M2 CI scope.

</domain>

<decisions>
## Implementation Decisions

### Scan targets
- **Scan the aws-zabbix repository** — real project repo with CDK TypeScript, Python, Terraform, Dockerfiles, K8s YAML; exercises all 6 tools
- **Trivy**: filesystem scan only (`trivy fs`) — matches CI workflow usage; container image and remote repo scanning not in scope
- **Checkov**: directory scan only (`checkov -d .`) — scans all supported frameworks (Terraform, CDK, K8s, Dockerfile, GitHub Actions); no framework-specific targeting needed
- **Semgrep**: `semgrep scan --config auto` — default ruleset against full directory
- **Grype**: `grype dir:.` — filesystem vulnerability scan
- **Syft**: `syft dir:.` — SBOM generation in CycloneDX-JSON format
- **Gitleaks**: `gitleaks detect --source .` — full repository secrets scan

### Report storage
- **Write JSON reports to aws-zabbix/reports/** directory
- **Commit reports/.gitignore** to establish the convention — JSON files are git-ignored, directory persists
- Future CI (M2) can reuse the same directory convention
- **Filenames match M2 CI naming convention**: `semgrep-results.json`, `checkov-results.json`, `trivy-results.json`, `grype-results.json`, `gitleaks-results.json`, `sbom.json`

### Finding handling
- **Permissive — no fail flags** — all tools run to completion regardless of findings
- Phase 8 validates "can it scan and produce JSON" — not "is the codebase clean"
- CI (M2) enforces severity thresholds (`--error`, `--fail-on high`, etc.)
- **Validation check**: file exists and size > 0 — sufficient for validation purposes
- **Empty results are valid** — an empty findings array is still valid JSON output (tool ran, produced structured output, found nothing)

### Documentation updates
- **Add "Local validation" note to each tool's section** in `docs/development-security-stack-option-1.md` — follows the "Verified versions" pattern from Phases 6/7
- **Just confirm success**: "Validated: [tool] scan completed, JSON output produced (2026-03-16)" — no finding counts (go stale immediately)
- **Syft validation note**: mention CycloneDX-JSON format specifically (matches main doc convention and Grype consumption pattern)

### Claude's Discretion
- Exact placement of validation notes within each tool's section
- Order of tool execution (any order is fine — no dependencies between scans)
- Whether to run Grype against the Syft SBOM or against the directory directly (both produce JSON)
- Handling of any tool-specific warnings or non-fatal errors during scans

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scan command reference
- `docs/development-security-stack-option-1.md` lines 181-185 — Semgrep scan commands: JSON and SARIF output flags
- `docs/development-security-stack-option-1.md` lines 237-241 — Checkov scan commands: JSON and SARIF output, directory mode
- `docs/development-security-stack-option-1.md` lines 274-290 — Trivy scan commands: filesystem, image, K8s modes; JSON and CycloneDX output
- `docs/development-security-stack-option-1.md` lines 329-345 — Syft SBOM generation + Grype scanning: CycloneDX-JSON, vulnerability JSON output
- `docs/development-security-stack-option-1.md` lines 379-380 — Gitleaks detect command: JSON report output

### CI workflow (reference for filename conventions)
- `docs/development-security-stack-option-1.md` lines 1488-1584 — GitHub Actions security workflow: 5 parallel scan jobs with JSON artifact names

### Prior phase patterns
- `.planning/phases/06-sca-and-container-cli-tools/06-CONTEXT.md` — Phase 6 documentation pattern (verified versions notes)
- `.planning/phases/07-sast-and-iac-cli-tools/07-CONTEXT.md` — Phase 7 documentation pattern (verified versions notes)

### Milestone done criteria
- `docs/milestone-plan/milestone-1-workstation.md` — M1 verification checks for CLI tool scanning

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- All 6 CLI tools already on PATH from Phases 5/6/7 — no installation needed
- Scan command templates exist in main doc — can be adapted directly
- Phase 5 established `.gitleaksignore` in aws-zabbix for CDK asset hash false positives — Gitleaks scan will respect this

### Established Patterns
- Phase 6/7 pattern: verify tool works -> document in main doc with validated note
- M2 CI workflow defines the canonical JSON filenames and scan flags — local validation should mirror these
- Homebrew tools (Trivy, Syft, Grype, Gitleaks) and pip tools (Semgrep, Checkov) — all verified on PATH

### Integration Points
- JSON reports feed into M2 CI pipeline (GitHub Actions artifacts) and M4 DefectDojo import
- Syft SBOM (CycloneDX-JSON) can be consumed by Grype (`grype sbom:sbom.json`) — but direct `grype dir:.` also works
- aws-zabbix/reports/ directory establishes a convention that M2 CI can reference
- `.gitleaksignore` baseline from Phase 5 applies to Gitleaks scans in aws-zabbix

</code_context>

<specifics>
## Specific Ideas

- This is a validation phase — the goal is proving each tool works end-to-end, not finding/fixing security issues
- aws-zabbix is the richest target repo (CDK, Python, Terraform, Docker, K8s) — exercises all tools meaningfully
- Filenames matching CI convention means less cognitive overhead when building M2 workflows
- The reports/.gitignore pattern keeps the repo clean while establishing the directory for future use

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-cli-tool-scanning-validation*
*Context gathered: 2026-03-16*
