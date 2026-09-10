# Phase 3: Web and Config Hooks - Context

**Gathered:** 2026-03-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure ESLint, hadolint, yamllint, and markdownlint pre-commit hooks work correctly in the target repository. Hooks are already configured in `.pre-commit-config.yaml` (Phase 1). This phase installs ESLint dependencies, creates linter config files where needed, fixes existing violations, and verifies each hook triggers on violations.

</domain>

<decisions>
## Implementation Decisions

### ESLint setup
- Full ESLint install: `eslint` + `@typescript-eslint` as devDependencies in target repo
- Use flat config format (`eslint.config.mjs`) — modern standard
- Rule preset: `@typescript-eslint/recommended` — catches type errors, unused vars, any-type abuse without being overly opinionated
- Lint all files including test files (`test/*.test.ts`) — no exclusions
- Fix all existing violations across 36 TS files — clean slate, same approach as Phase 2

### hadolint (no Dockerfiles)
- Leave hadolint hook configured in `.pre-commit-config.yaml` as a no-op — zero cost, activates automatically when Dockerfiles are added
- Verify LINT-04 by creating a temporary Dockerfile with a known violation, confirming hadolint catches it, then deleting the temp file

### yamllint configuration
- Keep `-d relaxed` inline in hook args — no `.yamllintrc` config file
- Only one YAML file in repo (`.pre-commit-config.yaml`), config file would be over-engineering

### markdownlint configuration
- Add `.markdownlint.json` config file to disable noisy rules (e.g., line-length MD013, inline HTML MD033) that conflict with tooling-generated markdown
- Add `.markdownlintignore` to exclude all dot-prefixed directories (`.claude/`, `.obsidian/`, `.planning/`, etc.) — these contain agent/command markdown with non-standard formatting

### Violation strategy
- Fix all violations across all linters — clean slate, consistent with Phase 2 approach
- Suppress with inline annotations only where fixing would change meaningful content or behavior (same Phase 2 pattern)

### Claude's Discretion
- Specific ESLint rules to enable/disable beyond `@typescript-eslint/recommended`
- Specific markdownlint rules to disable in `.markdownlint.json`
- Which dot-prefixed directories to list in `.markdownlintignore`
- Whether `jest.config.js` needs special ESLint treatment (CommonJS in a TS project)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Pre-commit configuration
- `docs/development-security-stack-option-1.md` lines 1302-1384 — Hook config with ESLint (local hook), hadolint, yamllint, and markdownlint entries
- `docs/development-security-stack-option-1.md` lines 1120-1130 — Tier 1/Tier 2 architecture rationale

### Milestone done criteria
- `docs/milestone-plan/milestone-1-workstation.md` — M1-F1 done criteria for web/config hooks

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.pre-commit-config.yaml` already committed with ESLint (local hook, `npx eslint`), hadolint (`hadolint-docker`), yamllint (`-d relaxed`), and markdownlint hooks configured
- `pre-commit install` already run — hooks active on commit
- `jest.config.js` exists — Jest test runner already configured

### Established Patterns
- Target repo is TypeScript/CDK primary — `lib/` for CDK stacks, `test/` for Jest tests
- 36 TypeScript files across `lib/`, `test/`, and `bin/` directories
- No existing ESLint, yamllint, or markdownlint config files
- Phase 2 pattern: inline suppression comments preferred over config-file-level suppression

### Integration Points
- Target repo: `repos/aws-zabbix-monitoring-solution/` on branch `feature/add-pre-commit`
- ESLint hook entry: `npx eslint` (local hook, requires eslint in project devDependencies)
- Hooks run against staged files on `git commit`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — standard hook validation following Phase 2 patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-web-and-config-hooks*
*Context gathered: 2026-03-15*
