# Phase 4: Infrastructure Hooks - Context

**Gathered:** 2026-03-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Validate that npm audit, terraform fmt, and terraform validate pre-commit hooks work correctly. Hooks are already configured in `.pre-commit-config.yaml` (Phase 1). This phase ensures npm audit triggers on `package-lock.json` changes, terraform fmt auto-formats HCL files, and terraform validate catches HCL syntax errors. Existing violations should be resolved so hooks pass cleanly.

</domain>

<decisions>
## Implementation Decisions

### Terraform validation approach
- Test terraform hooks against a real Terraform repo: `OttawaCloudConsulting/terraform-pipelines`
- Clone to `repos/terraform-pipelines/` alongside the existing target repos
- Deployable example at `examples/default/minimal/main.tf`, module in `modules/default`
- Install pre-commit in terraform-pipelines with the same `.pre-commit-config.yaml` config
- Full end-to-end test: install hooks, verify terraform_fmt and terraform_validate trigger on real `.tf` files
- Fix and commit any terraform fmt formatting violations (same clean-slate pattern as Phases 2/3)

### npm audit failure policy
- Run `npm audit fix` to resolve auto-fixable high/critical vulnerabilities in aws-zabbix-monitoring-solution
- If unfixable vulnerabilities remain (no patch available), document them and adjust audit-level threshold (e.g., `--audit-level=critical`) so the hook doesn't block commits indefinitely
- Goal: hook passes cleanly on current dependencies, blocks only on newly introduced high/critical vulns

### Terraform tool availability
- Terraform CLI is already installed on the workstation — no installation needed
- Run `pre-commit autoupdate` to get the latest `pre-commit-terraform` version (not pinned to v1.96.0 from reference doc)
- npm is already available (target repo is a Node.js project)

### Hook configuration (carried from Phase 1)
- npm-audit: local hook, `npm audit --audit-level=high`, triggers only on `package-lock.json` changes
- terraform_fmt: from `pre-commit-terraform` repo, auto-formats HCL
- terraform_validate: from `pre-commit-terraform` repo, checks HCL syntax
- All three hooks already present in `.pre-commit-config.yaml` committed in Phase 1

### Claude's Discretion
- Whether to adjust npm audit-level from `high` to `critical` based on findings
- How to handle terraform validate's need for `terraform init` (provider initialization)
- Whether terraform-pipelines needs its own feature branch or can work on main

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### npm audit hook
- `docs/development-security-stack-option-1.md` lines 1282-1294 — npm audit rationale: retained as lightweight pre-commit SCA, `--audit-level=high`, triggers only on `package-lock.json` changes
- `docs/development-security-stack-option-1.md` lines 1362-1370 — npm-audit hook config: local hook, `npm audit --audit-level=high`, `files: package-lock\.json$`

### Terraform hooks
- `docs/development-security-stack-option-1.md` lines 1313-1317 — pre-commit-terraform config: `terraform_fmt` and `terraform_validate` from `antonbabenko/pre-commit-terraform` v1.96.0
- `docs/development-security-stack-option-1.md` lines 1135-1136 — Tier 1 architecture: terraform fmt/validate listed as Tier 1 quality hooks

### Pre-commit framework
- `docs/development-security-stack-option-1.md` lines 1302-1384 — Complete `.pre-commit-config.yaml` with all hooks
- `docs/adr/adr011-precommit-bypass-warning.md` — Pre-commit bypass via `--no-verify`, CI as compensating control

### Milestone done criteria
- `docs/milestone-plan/milestone-1-workstation.md` — M1-F1 done criteria for infrastructure hooks

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.pre-commit-config.yaml` already committed to aws-zabbix-monitoring-solution with npm-audit, terraform_fmt, and terraform_validate hooks configured
- `pre-commit install` already run in aws-zabbix-monitoring-solution — hooks active on commit
- Same `.pre-commit-config.yaml` will be deployed to terraform-pipelines

### Established Patterns
- Phase 2/3 pattern: install hooks, identify violations, fix or suppress, verify success criteria
- Phase 3 hadolint pattern: tested via temp file when no real files exist — but for terraform we're using a real repo instead
- Target repo (aws-zabbix-monitoring-solution) has `package-lock.json` — npm audit hook is directly testable there
- terraform-pipelines has real `.tf` files — terraform hooks testable there

### Integration Points
- aws-zabbix-monitoring-solution: `repos/aws-zabbix-monitoring-solution/` on branch `feature/add-pre-commit` — npm audit testing
- terraform-pipelines: clone to `repos/terraform-pipelines/` — terraform hook testing
- security-platform: canonical config source at `OttawaCloudConsulting/security-platform`

</code_context>

<specifics>
## Specific Ideas

- User wants to test terraform hooks against a real Terraform repo rather than temp files — more realistic validation
- terraform-pipelines repo structure: `examples/default/minimal/main.tf` for deployable example, `modules/default` for the module code
- Clean-slate approach consistent across all phases: fix violations, don't just document them

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-infrastructure-hooks*
*Context gathered: 2026-03-15*
