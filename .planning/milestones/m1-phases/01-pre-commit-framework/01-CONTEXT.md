# Phase 1: Pre-commit Framework - Context

**Gathered:** 2026-03-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Install the pre-commit framework and create the hook configuration file. The config file includes all Tier 1 and Tier 2 hook definitions from the reference document. Individual hook testing and validation happens in Phases 2-5; this phase ensures the framework is installed, the config is committed, and `git commit` triggers hook execution.

</domain>

<decisions>
## Implementation Decisions

### Repository structure
- **Planning repo** (`security_solution/`) stays documentation/planning only — no deployable code here
- **Implementation repo** (`security-platform`) on GitHub (private, `OttawaCloudConsulting/security-platform`) holds the canonical config files, Helm values, scripts, and infrastructure code
- **Target repos** get pre-commit installed with the config copied/placed from the canonical source
- Both repos are cloned into `security_solution/repos/` for development access
- Work happens on feature branches, not main directly

### First target repo
- `OttawaCloudConsulting/aws-zabbix-monitoring-solution` — AWS CDK TypeScript project
- Good coverage target: has TypeScript, JSON, YAML, shell scripts, and `package-lock.json`
- Cloned to `repos/aws-zabbix-monitoring-solution/`

### Config file scope
- Phase 1 commits the FULL `.pre-commit-config.yaml` from the reference document (all 9 Tier 1 hooks + Gitleaks Tier 2)
- Phases 2-5 validate and test each hook category — they don't need to add hooks to the config

### Hook version pinning
- Use the versions from the reference document as the starting point
- `pre-commit autoupdate` can be run to bump to latest before committing

### Claude's Discretion
- Whether to run `pre-commit autoupdate` before or after initial commit
- README or documentation additions to `security-platform`
- `.gitignore` contents for `security-platform`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Pre-commit configuration
- `docs/development-security-stack-option-1.md` lines 1300-1395 — Complete `.pre-commit-config.yaml` with all Tier 1 and Tier 2 hooks, version pins, and maintenance guidance
- `docs/development-security-stack-option-1.md` lines 1120-1130 — Tier 1/Tier 2 architecture rationale (why Semgrep/Checkov are NOT in pre-commit)

### Bypass and enforcement model
- `docs/adr/adr011-precommit-bypass-warning.md` — Pre-commit bypass via `--no-verify`, CI as compensating control

### Milestone done criteria
- `docs/milestone-plan/milestone-1-workstation.md` — M1-F1 done criteria, verification checks

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Complete `.pre-commit-config.yaml` in reference doc (lines 1302-1384) — copy-pasteable, production-ready
- Target repo (`aws-zabbix-monitoring-solution`) already has `.snyk`, `jest.config.js`, `tsconfig.json` — mature project with existing tooling

### Established Patterns
- Target repo uses npm/TypeScript ecosystem — ESLint and npm audit hooks are directly relevant
- Target repo has `scripts/` directory with shell scripts — ShellCheck hook is relevant
- No existing `.pre-commit-config.yaml` in target repo — greenfield for hooks

### Integration Points
- `security-platform` repo: canonical config source, working branch `feature/m1-workstation-foundation`
- Target repo: hooks installed here, will need its own working branch for the pre-commit config commit

</code_context>

<specifics>
## Specific Ideas

- User wants clean separation: planning repo stays docs-only, implementation code goes in `security-platform`
- Single-developer workflow: no team coordination overhead, optimize for solo iteration
- Work on branches, PR-based workflow

</specifics>

<deferred>
## Deferred Ideas

- Multi-repo rollout (applying pre-commit to remaining 5+ repos) — after M1 validation on first target
- Template/automation for distributing config updates across repos — future consideration

</deferred>

---

*Phase: 01-pre-commit-framework*
*Context gathered: 2026-03-15*
