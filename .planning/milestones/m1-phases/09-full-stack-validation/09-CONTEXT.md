# Phase 9: Full Stack Validation - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Run `pre-commit run --all-files` to clean exit (exit code 0) across aws-zabbix and terraform-pipelines repositories on their `feature/add-pre-commit` branches. All 9 Tier 1 hooks pass without failure. Gitleaks Tier 2 hook validated separately via `--hook-stage pre-push`. Pre-existing violations are fixed or suppressed with inline annotations. This phase does NOT merge feature branches to main — that's a post-milestone step.

</domain>

<decisions>
## Implementation Decisions

### Target repo scope
- **Two repos in scope:** aws-zabbix-monitoring-solution and terraform-pipelines
- **Branch:** `feature/add-pre-commit` in both repos (where all Phases 2-5 hook work happened)
- **security-platform skipped entirely** — it's the canonical config source, not a validation target
- Merge to main is a separate post-milestone step, not part of Phase 9

### Failure remediation strategy
- **Fix first, suppress as last resort** — genuine issues get real code fixes
- **Suppress behavioral changes** — if a linter suggests restructuring logic (not just formatting), suppress with inline annotation and a comment explaining why
- Only use inline suppressions for intentional patterns (like SC2034 in Phase 2) or confirmed false positives
- **Inline annotations only** — no separate suppression log or tracking file; suppressions are discoverable by grep

### hadolint: switch to native binary
- **Install native hadolint** (`brew install hadolint`) instead of Docker wrapper (`hadolint-docker`)
- Update `.pre-commit-config.yaml` to use the `hadolint` hook instead of `hadolint-docker` — removes Docker daemon dependency
- **Propagate to all three repos** including security-platform (canonical config source) for consistency
- This is a config change, not a new capability — hadolint was already configured in Phase 3

### Terraform validate prerequisites
- **Run `terraform init` before `--all-files`** in directories with `.tf` files — known prereq from Phase 4
- Phase 4 already established this pattern; Phase 9 follows the same approach

### Other environment prereqs
- Claude's discretion to identify and handle prereqs for each hook (node_modules for ESLint, Python for Ruff, etc.)
- Document any setup steps needed before `--all-files` succeeds

### Gitleaks validation
- **Separate Gitleaks check** — run `pre-commit run gitleaks --all-files --hook-stage pre-push` independently
- Covers the Tier 2 hook that `pre-commit run --all-files` won't trigger (pre-push stage)
- Ensures all 10 hooks (9 Tier 1 + 1 Tier 2) are validated

### Documentation updates
- **Validation stamp per repo** in `docs/development-security-stack-option-1.md` pre-commit section
- Pattern: "Validated: pre-commit run --all-files passed (aws-zabbix, terraform-pipelines) — 2026-03-16"
- **No finding counts** — counts go stale immediately; follows Phase 8 established pattern
- Follows the "Verified versions" documentation pattern from Phases 6/7/8

### Claude's Discretion
- Order of hook remediation (which hooks to tackle first)
- Which hooks are relevant for terraform-pipelines vs aws-zabbix (let pre-commit skip non-matching naturally, or identify upfront)
- Exact placement of validation stamp in main doc
- Handling of any tool-specific warnings or non-fatal errors during the full run
- Environment prereq identification and resolution for each hook

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Pre-commit configuration
- `docs/development-security-stack-option-1.md` lines 1302-1384 — Complete `.pre-commit-config.yaml` with all hooks (canonical reference for hook entries)
- `docs/development-security-stack-option-1.md` lines 1120-1130 — Tier 1/Tier 2 architecture rationale

### Hook-specific references
- `docs/adr/adr011-precommit-bypass-warning.md` — Pre-commit bypass via `--no-verify`, CI as compensating control
- `.planning/phases/02-shell-and-python-hooks/02-CONTEXT.md` — ShellCheck SC2034 suppression pattern, Ruff configuration
- `.planning/phases/03-web-and-config-hooks/03-CONTEXT.md` — markdownlint disabled rules, hadolint-docker setup (to be replaced with native), ESLint config
- `.planning/phases/04-infrastructure-hooks/04-CONTEXT.md` — npm audit, terraform fmt/validate, pre-commit-terraform version
- `.planning/phases/05-secrets-detection-gate/05-CONTEXT.md` — Gitleaks pre-push config, .gitleaksignore baseline

### Milestone done criteria
- `docs/milestone-plan/milestone-1-workstation.md` — M1 verification checks for full stack validation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.pre-commit-config.yaml` in all three repos — fully configured from Phases 1-5, needs hadolint hook type change
- `.gitleaksignore` in aws-zabbix — 40 baseline false positives already suppressed (Phase 5)
- `.markdownlint-cli2.yaml` and `.markdownlint.jsonc` — rules already tuned (Phase 3)
- ESLint config with typescript-eslint — established in Phase 3

### Established Patterns
- Phase 2-4 pattern: run hooks, identify violations, fix or suppress, verify clean exit
- Phase 2: inline ShellCheck suppression with `# shellcheck disable=SCXXXX` + comment explaining why
- Phase 3: markdownlint rule disabling via config file (not inline) for project-wide patterns
- Phase 4: `pre-commit autoupdate` for version bumps; `terraform init` as prereq
- Phase 5: `.gitleaksignore` for false positive suppression

### Integration Points
- aws-zabbix-monitoring-solution: `repos/aws-zabbix-monitoring-solution/` on `feature/add-pre-commit` branch
- terraform-pipelines: `repos/terraform-pipelines/` on `feature/add-pre-commit` branch
- security-platform: canonical config source — hadolint change propagates here too
- Main doc (`docs/development-security-stack-option-1.md`): validation stamp destination

</code_context>

<specifics>
## Specific Ideas

- Native hadolint removes Docker daemon dependency — cleaner developer experience, simpler CI prereqs
- Two-repo validation mirrors the real M1 scope: aws-zabbix (richest target) + terraform-pipelines (infrastructure code)
- Separate Gitleaks check ensures the success criteria is fully met (all 10 hooks, not just 9)
- Fix-first approach maintains code quality; suppress-last-resort keeps the validation honest

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 09-full-stack-validation*
*Context gathered: 2026-03-16*
