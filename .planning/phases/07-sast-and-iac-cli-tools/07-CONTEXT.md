# Phase 7: SAST and IaC CLI Tools - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Install and verify three security CLI tools — Semgrep CE, Checkov, and Gitleaks — so they are on `$PATH` with version verification. Checkov (v3.2.396 via pip) and Gitleaks (v8.30.0 via Homebrew) are already installed from prior work. Semgrep needs fresh installation. This phase does NOT run scans or produce reports — that's Phase 8 (CLI Tool Scanning Validation).

</domain>

<decisions>
## Implementation Decisions

### Installation methods
- **Semgrep**: Install via pip (`pip install semgrep --break-system-packages`) — consistent with Checkov as a Python tool
- **Checkov**: Already installed (v3.2.396 via pip) — document actual state, do NOT switch to Homebrew
- **Gitleaks**: Already installed (v8.30.0 via Homebrew from Phase 5) — just verify on PATH and document

### Version policy
- No minimum version pinning — unlike Phase 6 (Grype DB schema v5 EOL), there are no hard version floors for these tools
- Just verify "latest" / "current" — record whatever version is installed
- Semgrep: Homebrew has v1.155.0, pip should install comparable latest
- Checkov: v3.2.396 already on PATH (Homebrew has v3.2.500 but we're keeping pip install as-is)
- Gitleaks: v8.30.0 already verified from Phase 5

### Documentation updates
- **Same pattern as Phase 6**: Add "Verified versions" notes to each tool's setup section in `development-security-stack-option-1.md`
- **Semgrep**: Add verified version note to section 1 (Semgrep CE, around line 154)
- **Checkov**: Add verified version note to section 2 (Checkov, around line 206)
- **Gitleaks**: Add CLI verified note to section 5 (Gitleaks, around line 361) — separate from Phase 5's hook documentation
- Document actual install methods used (pip for Semgrep and Checkov, brew for Gitleaks)

### Claude's Discretion
- Exact format and placement of version notes (follow Phase 6 pattern)
- Whether to upgrade Checkov from 3.2.396 to latest via pip before documenting
- Order of installation/verification operations

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Tool setup documentation
- `docs/development-security-stack-option-1.md` lines 154-203 — Semgrep CE setup: install commands (pip and brew), scan modes, rule configuration, custom rules, SARIF output
- `docs/development-security-stack-option-1.md` lines 206-258 — Checkov setup: install commands, scan targets (Terraform, CDK, K8s, Dockerfile, GitHub Actions), baseline management, JSON/SARIF output
- `docs/development-security-stack-option-1.md` lines 361-381 — Gitleaks CLI setup: install commands, detect/protect modes, full-history scan, JSON output

### Phase 6 pattern (reference for consistency)
- `.planning/phases/06-sca-and-container-cli-tools/06-01-SUMMARY.md` — How Phase 6 handled tool install + version verification + doc updates

### Architecture context
- `docs/development-security-stack-option-1.md` lines 127-131 — Tool comparison table showing Semgrep, Checkov, Gitleaks roles and what they replace

### Milestone done criteria
- `docs/milestone-plan/milestone-1-workstation.md` — M1 verification checks for CLI tool installation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Homebrew managing Gitleaks (v8.30.0), Trivy, Syft, Grype — established pattern for Go/Rust CLI tools
- pip managing Checkov (v3.2.396) — Python tool pattern
- Phase 6 established the pattern: install tool → verify `--version` → update main doc with actual versions

### Established Patterns
- Phase 6 pattern: `brew install` / `pip install` → verify version command → add "Verified versions" note to main doc
- Phase 5: Gitleaks installed via `brew install gitleaks` and documented in hook context — Phase 7 adds CLI verification note

### Integration Points
- Semgrep, Checkov, Gitleaks are consumed by Phase 8 (scanning validation) — Phase 7 just makes them available on PATH
- Gitleaks is also used as pre-push hook (Phase 5) — Phase 7 documents the CLI tool aspect
- All three tools need JSON output capability for M2 CI and M4 DefectDojo — but that's Phase 8 scope

</code_context>

<specifics>
## Specific Ideas

- This is the lightest phase yet — two tools already installed, only Semgrep needs fresh install
- Follow Phase 6 pattern exactly for doc updates (verified version notes)
- Gitleaks gets a separate CLI verified note even though Phase 5 documented it as a hook tool

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 07-sast-and-iac-cli-tools*
*Context gathered: 2026-03-16*
