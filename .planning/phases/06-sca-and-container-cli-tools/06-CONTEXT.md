# Phase 6: SCA and Container CLI Tools - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Install and verify three supply chain / container security CLI tools — Trivy, Syft, and Grype — so they are on `$PATH` and meet minimum version requirements. Trivy is already installed (v0.69.3) and needs upgrading + DB refresh. Syft and Grype need fresh installation. This phase does NOT run scans or produce reports — that's Phase 8 (CLI Tool Scanning Validation).

</domain>

<decisions>
## Implementation Decisions

### Installation method
- **Homebrew for all three tools** — consistent with Gitleaks (Phase 5) and existing Trivy install
- `brew upgrade trivy`, `brew install syft`, `brew install grype`
- No curl-based binary installs — Homebrew provides simplest upgrade path via `brew upgrade`

### Trivy handling
- Trivy v0.69.3 already installed — upgrade to latest via `brew upgrade trivy`
- Refresh vulnerability database after upgrade: `trivy image --download-db-only` (DB last downloaded 2026-02-22, over 3 weeks stale)
- Verify version still meets >= 0.69.2 requirement after upgrade

### Grype version concern
- Install via Homebrew and verify version meets >= 0.88.0 requirement
- Only escalate if Homebrew version is below 0.88.0 — don't pre-solve a problem that may not exist
- If version is too old: fall back to curl-based install from Anchore GitHub releases as backup plan
- Context: DB schema v5 hit EOL 2026-03-06, versions below 0.88.0 cannot update their vulnerability database

### Documentation updates
- Update `docs/development-security-stack-option-1.md` with actual installed versions for Trivy, Syft, and Grype
- Add "Verified versions" notes to the Setup sections for each tool
- Keep the reference document accurate as a living record of what's actually deployed

### Claude's Discretion
- Exact format and placement of version notes in the main doc
- Whether to update the Trivy DB refresh section with current timestamps
- Order of installation (Trivy upgrade first, then Syft, then Grype — or parallel)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Tool setup documentation
- `docs/development-security-stack-option-1.md` lines 253-292 — Trivy setup: install commands, scan modes, DB management, offline mode
- `docs/development-security-stack-option-1.md` lines 296-352 — Syft + Grype setup: install commands, SBOM generation, vulnerability scanning, CI integration

### Milestone done criteria
- `docs/milestone-plan/milestone-1-workstation.md` — M1 verification checks for CLI tool installation

### Architecture context
- `docs/development-security-stack-option-1.md` lines 129-132 — Tool comparison table showing Trivy, Syft+Grype roles and what they replace

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Homebrew already managing Trivy (v0.69.3) and Gitleaks (v8.30.0) — established pattern for CLI tool lifecycle
- Phase 5 established the pattern: install tool, verify version, document in main doc

### Established Patterns
- Phase 5 pattern: `brew install` → verify `--version` → update main doc with actual versions
- All prior phases used Homebrew for tool installation (pre-commit, shellcheck via pre-commit, gitleaks)

### Integration Points
- Trivy, Syft, Grype are consumed by Phase 8 (scanning validation) — Phase 6 just makes them available on PATH
- Grype consumes Syft SBOMs in the CI pipeline (M2) — but that's future milestone scope
- TOOL-06 (Gitleaks on PATH) already satisfied by Phase 5 — not in this phase's scope

</code_context>

<specifics>
## Specific Ideas

- Trivy DB refresh is important — 3+ weeks stale means missing recent CVEs
- Grype version check is the only risk item — Homebrew usually tracks upstream closely but worth verifying
- This is a lightweight phase compared to the hook phases — pure install/verify/document

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-sca-and-container-cli-tools*
*Context gathered: 2026-03-16*
