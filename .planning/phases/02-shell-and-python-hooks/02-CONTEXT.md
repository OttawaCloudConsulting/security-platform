# Phase 2: Shell and Python Hooks - Context

**Gathered:** 2026-03-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Validate that ShellCheck and Ruff pre-commit hooks work correctly in the target repository. Hooks are already configured in `.pre-commit-config.yaml` (Phase 1). This phase verifies they trigger on violations, auto-fix where configured, and appear in hook output. Existing violations in tracked files should be resolved or suppressed so hooks pass cleanly.

</domain>

<decisions>
## Implementation Decisions

### Hook configuration (carried from Phase 1)
- ShellCheck: `shellcheck-py` rev v0.10.0.1 — catches shell script issues
- Ruff: `ruff-pre-commit` rev v0.8.4 — `ruff --fix` for linting + `ruff-format` for formatting
- Both hooks already present in `.pre-commit-config.yaml` committed in Phase 1

### Target files in aws-zabbix-monitoring-solution
- Shell scripts: `scripts/cdk-validation.sh`, `scripts/dev-certs/generate-certs.sh`, `scripts/zabbix_agent_install.sh`
- Python files: `scripts/snippet-python-hostname.py`
- `node_modules/` is gitignored — hooks only run on tracked files

### Validation approach
- Run each hook against existing files to identify current violations
- Fix violations where practical, suppress with inline annotations where fixing would change behavior
- Verify success criteria: ShellCheck catches unquoted variables, Ruff auto-fixes formatting

### Claude's Discretion
- Whether to fix or suppress specific ShellCheck/Ruff violations
- Inline suppression comment style (`# shellcheck disable=SC2xxx` vs `.shellcheckrc`)
- Whether to add a `.ruff.toml` for project-level Ruff configuration

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Pre-commit configuration
- `docs/development-security-stack-option-1.md` lines 1302-1384 — Hook config with ShellCheck (line 1328) and Ruff (line 1320) entries
- `docs/development-security-stack-option-1.md` lines 1120-1130 — Tier 1/Tier 2 architecture rationale

### Milestone done criteria
- `docs/milestone-plan/milestone-1-workstation.md` — M1-F1 done criteria: "A test commit introducing an unquoted variable in a shell script is flagged by ShellCheck" and "A test commit with a Python formatting violation is auto-fixed by Ruff"

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.pre-commit-config.yaml` already committed to target repo with ShellCheck and Ruff configured
- `pre-commit install` already run — hooks active on commit

### Established Patterns
- Target repo is TypeScript/CDK primary — shell scripts and Python are utility/helper files
- Scripts directory contains operational scripts (cert generation, CDK validation, agent installation)

### Integration Points
- Target repo: `repos/aws-zabbix-monitoring-solution/` on branch `feature/add-pre-commit`
- Hooks run against staged files on `git commit`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — standard hook validation with existing files.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-shell-and-python-hooks*
*Context gathered: 2026-03-15*
