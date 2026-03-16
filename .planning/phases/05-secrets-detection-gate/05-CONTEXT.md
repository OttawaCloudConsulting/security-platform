# Phase 5: Secrets Detection Gate - Context

**Gathered:** 2026-03-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Configure Gitleaks as a pre-push hook to block credentials and secrets from being pushed to remote repositories. The Gitleaks entry already exists in `.pre-commit-config.yaml` (Phase 1) but needs to be reconfigured from pre-commit to pre-push stage with explicit `protect --staged` mode. All three repos with pre-commit get the hook installed. A full-history baseline scan clears existing false positives. End-to-end proof that a dummy AWS key is blocked on push.

</domain>

<decisions>
## Implementation Decisions

### Hook trigger point
- Change Gitleaks from default pre-commit stage to **pre-push only** (`stages: [pre-push]`)
- Add explicit args: `[protect, --staged]` to match SECR-01 requirement exactly
- Run `pre-commit autoupdate` to get latest Gitleaks version (not pinned to v8.21.2)
- Update canonical `.pre-commit-config.yaml` in security-platform first, then sync to all target repos
- Run `pre-commit install --hook-type pre-push` in each repo to activate the pre-push hook

### Existing findings handling
- Run full-history Gitleaks scan (`gitleaks detect --source . --log-opts="--all"`) on all three repos to establish baseline
- Add legitimate false positives to `.gitleaksignore` (aws-zabbix already has CDK asset hash entry)
- Suppress, don't fix — the pre-push hook with `protect --staged` only checks new changes, but a clean baseline avoids confusion
- SECR-02 demo: create temp file with dummy AWS key `AKIAIOSFODNN7EXAMPLE`, stage, attempt push, verify block, clean up (same pattern as hadolint temp file test in Phase 3)

### .gitleaksignore strategy
- **Canonical + per-repo:** security-platform has a base `.gitleaksignore` template with common suppression patterns
- Each target repo extends with repo-specific entries (e.g., CDK asset hashes in aws-zabbix, any Terraform-specific false positives in terraform-pipelines)
- Existing `.gitleaksignore` in aws-zabbix (CDK asset hash suppression from Phase 3) is kept and extended as needed

### Target repo scope
- All three repos get the Gitleaks pre-push hook: aws-zabbix-monitoring-solution, terraform-pipelines, security-platform
- Full-history baseline scan on all three repos
- Config sync: update `.pre-commit-config.yaml` in all three repos with the stages/args changes

### Gitleaks installation
- Install via `brew install gitleaks` (system-wide CLI)
- Pre-commit hooks use the system binary — no separate pre-commit-managed binary
- System install also satisfies Phase 7 TOOL-06 requirement (`gitleaks version` on PATH)

### Bypass documentation (SECR-03)
- Document `--no-verify` bypass and CI compensating control in **all three places:**
  1. `development-security-stack-option-1.md` — "Bypass & Compensating Controls" section
  2. `security-platform` README — developer-facing bypass guidance
  3. `.pre-commit-config.yaml` — inline comments on the Gitleaks hook entry
- References ADR-011 (pre-commit bypass warning)

### Claude's Discretion
- Exact `.gitleaksignore` template contents for the canonical base
- Whether to add a custom Gitleaks config (`.gitleaks.toml`) or use defaults
- Order of operations for multi-repo config sync
- How to structure the bypass documentation sections

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Gitleaks configuration
- `docs/development-security-stack-option-1.md` lines 1377-1384 — Gitleaks hook entry in `.pre-commit-config.yaml` (needs stages/args modification)
- `docs/development-security-stack-option-1.md` lines 362-377 — Gitleaks CLI setup, detect/protect modes, JSON output

### Bypass and enforcement model
- `docs/adr/adr011-precommit-bypass-warning.md` — Pre-commit bypass via `--no-verify`, CI as compensating control (SECR-03 source)

### Pre-commit framework
- `docs/development-security-stack-option-1.md` lines 1302-1384 — Complete `.pre-commit-config.yaml` with all hooks
- `docs/development-security-stack-option-1.md` lines 1120-1130 — Tier 1/Tier 2 architecture rationale

### Milestone done criteria
- `docs/milestone-plan/milestone-1-workstation.md` — M1 verification checks for secrets detection

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.pre-commit-config.yaml` in all three repos — already has Gitleaks entry, needs `stages` and `args` fields added
- `.gitleaksignore` in aws-zabbix-monitoring-solution — has CDK asset hash suppression (Phase 3), extend for baseline scan findings
- `.git/hooks/pre-commit` exists in target repos — `pre-commit install --hook-type pre-push` adds a sibling `pre-push` hook

### Established Patterns
- Phase 2/3/4 pattern: install/configure hooks, identify violations, fix or suppress, verify success criteria
- Phase 3 hadolint pattern: temp file test for end-to-end hook verification — reuse for SECR-02 dummy key test
- Phase 4 pattern: config sync across repos with `pre-commit autoupdate`
- Feature branch workflow: `feature/add-pre-commit` branches in target repos

### Integration Points
- security-platform: canonical config source, update `.pre-commit-config.yaml` first
- aws-zabbix-monitoring-solution: `repos/aws-zabbix-monitoring-solution/` on `feature/add-pre-commit` branch
- terraform-pipelines: `repos/terraform-pipelines/` on `feature/add-pre-commit` branch
- CI pipeline (M2): Gitleaks in CI is the compensating control for `--no-verify` bypass

</code_context>

<specifics>
## Specific Ideas

- Brew-only install for Gitleaks — single system binary, no pre-commit-managed copy
- All three places get bypass documentation: main doc, README, inline config comments
- Canonical + per-repo .gitleaksignore: base template in security-platform, repo-specific extensions in each target
- Temp file test for dummy AWS key proof — non-destructive, clean up after

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-secrets-detection-gate*
*Context gathered: 2026-03-15*
