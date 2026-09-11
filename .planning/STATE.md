---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: CI/CD Security Pipeline
status: executing
stopped_at: Completed 16-02-PLAN.md — shared ecosystem detectors + generalised smoke-gate helpers on feature/phase-16-sca-ecosystem-coverage (29dbc62)
last_updated: "2026-09-11T13:29:31.334Z"
last_activity: 2026-09-11
progress:
  total_phases: 7
  completed_phases: 2
  total_plans: 15
  completed_plans: 10
  percent: 29
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-10)

**Core value:** Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production -- with zero ongoing cost and zero vendor lock-in.
**Current focus:** Phase 16 — sca-ecosystem-coverage

## Current Position

Phase: 16 (sca-ecosystem-coverage) — EXECUTING
Plan: 3 of 7
Status: Ready to execute
Last activity: 2026-09-11

Progress: [███████░░░] 67%

## Performance Metrics

**Velocity:**

- Total plans completed: 18 (v1.0 + v1.1)
- Total execution time: ~2h 40min

**Recent Trend:**

- Phase 13 P04: ~40min
- Phase 13 P05: ~35min
- Phase 13 P06: ~30min
- Trend: Stable

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions. Recent decisions affecting current work:

- [v2.0 roadmap]: Scanning workflow is authored as `on: workflow_call` from Phase 14, invoked by a thin `pull_request` caller in this repo — so DIST-07 (reusable mode) is a publish step, not a late restructure that would invalidate Phase 19's validation.
- [v2.0 roadmap]: SCA split across two phases — SCA-04 (generic Trivy/Grype filesystem scan) lands in Phase 15 as the zero-config first cut of the 5th job, so CICD-01 ("5 parallel jobs") is genuinely true there; SCA-01/02/03 ecosystem sub-scans follow in Phase 16.
- [v2.0 roadmap]: Gate mode (CICD-06) must work as both a `workflow_call` input and a repo variable/env, since the two consumption modes configure differently.
- [Phase 13]: check/update/doctor split — doctor is a distinct subcommand, update success determined by re-probing not installer exit code, successful fallback never rewrites versions.conf.
- [Phase 12]: Replaced `dist/install.sh` with `workstation/setup.sh` bootstrapper (install + configure + activate).
- [Phase 14-01]: Product repo uses yamllint -d relaxed (its existing pre-commit convention) as the phase gate — no .yamllint added; RESEARCH's truthy+document-start override VERIFIED to error on the 81-char SHA-pin line.
- [Phase 14-01]: actions/checkout pinned to v7.0.0 (9c091bb2) one patch behind v7.0.1 on purpose, so Dependabot's first run yields an observable bump PR (ROADMAP criterion #4).
- [Phase 14-02]: Verbatim check-run name for a reusable-workflow call is 'security / Placeholder' (<caller-job-id> / <called-job-name>) — assumption A3 CONFIRMED; Phase 18 must re-read it after Phase 15 replaces the placeholder with five scan jobs.
- [Phase 14-02]: Merge-blocking evidence on security-platform comes from the rulesets endpoint (rules/branches/main = deletion,non_fast_forward); the 404 on classic branches/main/protection is a false negative and must never be used as evidence.
- [Phase 15-01]: D-02 corrected: currently-supported debian:12-slim digest pin used instead of EOL distro so Trivy reports real, non-decreasing CVE counts (222 vulns, 4 CRITICAL, 52 HIGH measured)
- [Phase 15-01]: D-02 corrected: Checkov findings for main.tf come from misconfigured aws_s3_bucket/aws_security_group resources, not the old provider pin, which produces zero findings alone
- [Phase 15-01]: D-03 corrected: no Gitleaks or .gitleaksignore change made — scoping intent satisfied entirely by four exclude: ^fixtures/ hook entries on terraform_fmt, terraform_validate, hadolint, npm-audit
- [Phase 15]: Split scanner-verdict logic (run_scan, PASS on exit 1) from infra-step logic (require_success, PASS on exit 0) in smoke-scans.sh; docker build and trivy convert both signal success via exit 0, and using the wrong helper on them inverted their pass/fail verdict during first live test.
- [Phase 15]: Assumption A6 confirmed: Checkov 3.3.17 (the exact image bridgecrewio/checkov-action runs in CI) writes identical filenames (checkov-results.json, checkov.sarif) under the comma-mapped --output-file-path syntax as local Checkov 3.2.396 — no filename drift for Plan 03.
- [Phase 15]: Task 1 has no separate commit by plan design — both tasks land in a single feat(15-03) commit at Task 2 step 4, matching 15-01/15-02's verification-then-commit pattern.
- [Phase 15]: Reworded two inline comments to avoid literal substrings ('config auto', 'gitleaks dir') that the plan's own negative-grep verify checks for — RESEARCH's authoritative example uses those exact substrings in comments, so a verbatim copy would have failed the plan's own verification.
- [Phase 15]: No .gitleaksignore change made in 15-03 — smoke gate re-run pre- and post-commit produced the identical 9-finding list from 15-02, none pointing at security.yml.
- [Phase 15]: Phase 15-04: Trivy JSON-format output prints no inline finding count; non-zero evidence rests on --exit-code 1 plus non-empty file sizes, cross-checked against 15-02/15-03 local baselines
- [Phase 15-05]: PR #6 merged to OttawaCloudConsulting/security-platform main via --merge (commit e8e1009); origin/main verified via git show, not local working tree
- [Phase 15-05]: Open Question Q3 closed — Dependabot vulnerability-alerts are disabled on OttawaCloudConsulting/security-platform (404 plus explicit 403 disabled message); dependabot.yml left unmodified
- [Phase 15-05]: D-02/D-03 RESEARCH-corrected forms (C-1, C-2, C-3) confirmed as deliberate implementation choices, not drift from CONTEXT.md
- [Phase 16-01]: fixtures/main.tf needs BOTH an unconstrained random provider AND a random_id resource that uses it — tflint terraform_required_providers does not fire on a declared-but-unused provider
- [Phase 16-01]: No floating range (>= 3.0) added to the fixture — measured NOT flagged by tflint default ruleset, so Criterion 3 is satisfiable only via missing-constraint and unpinned-module cases
- [Phase 16-01]: Measured side effects recorded not predicted — Checkov terraform 10 to 12 failed (CKV_TF_1/CKV_TF_2 on unpinned module), Trivy fs 9 to 19 (10 new pip vulns), Trivy image re-measured identical at 222
- [Phase 16]: 16-02: ecosystem detectors extracted as shared scripts (detect-npm/python/terraform.sh) — CI and the smoke gate call one implementation, so the negative skip test exercises the logic CI runs rather than a copy of it
- [Phase 16]: 16-02: run_scan generalised to run_scan_rc <expected_rc> — tflint signals findings with exit 2 and reserves 1 for application errors; the hardcoded rc=1 PASS would have scored a healthy tflint run as a tool error
- [Phase 16]: 16-02: pip-audit and tflint moved to a soft preflight tier with SKIPPED accounting — A clean workstation without them must not hard-fail the gate, but a skip must never be counted or printed as a pass

### Pending Todos

None.

### Blockers/Concerns

- ~~Scan fixtures are needed from Phase 15, not just Phase 19.~~ — RESOLVED in Phase 15 (merged to `main` in
  Plan 05, commit `e8e1009`): `fixtures/Dockerfile`, `fixtures/main.tf`, `fixtures/package.json`,
  `fixtures/package-lock.json`, and `fixtures/README.md` now exist on `OttawaCloudConsulting/security-platform`
  `main`, giving the IaC, container, and SCA jobs real content to scan.

- ~~This repo's own hooks will block committing those fixtures.~~ — RESOLVED in Phase 15 (merged to `main` in
  Plan 05): four `exclude: ^fixtures/` entries on `terraform_fmt`, `terraform_validate`, `hadolint`, and
  `npm-audit` in `.pre-commit-config.yaml` scope the exemption to `fixtures/` only, leaving the repo's
  protection intact elsewhere. No Gitleaks/`.gitleaksignore` change was needed (RESEARCH C-3).

- ~~No `.github/` directory exists yet~~ — RESOLVED in Phase 14 Plan 01, merged in Phase 14 Plan 03 (not
  "unpushed" — RESEARCH C-6 found this note stale): the product repo (`repos/security-platform`) has had
  `.github/workflows/security.yml`, `.github/workflows/pr-security.yml`, and `.github/dependabot.yml` on
  `main` since Phase 14, and `security.yml` now carries Phase 15's five parallel scan jobs.

## Deferred Items

Carried forward from v1.1 close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Target-repo issue | `aws-zabbix-monitoring-solution` package-lock.json has 16 real npm vulns (1 critical: handlebars, 10 high); npm-audit hook correctly blocks commits | Deferred — target-repo remediation, not tooling | v1.1 close (2026-09-10) |
| Known gap | ESLint hook uses `language: system`; if eslint is absent and a `.js`/`.ts` file is staged, hook errors rather than skipping | Accepted, not fixed | v1.1 close (2026-09-10) |
| Phase 14 P01 | 12min | 3 tasks | 3 files |
| Phase 14 P02 | 7min | 2 tasks | 1 files |
| Phase 15 P01 | 20min | 2 tasks | 6 files |
| Phase 15 P02 | 25min | 2 tasks | 1 files |
| Phase 15-five-parallel-scan-jobs P03 | 20min | 2 tasks | 1 files |
| Phase 15 P04 | 25min | 2 tasks | 0 files |
| Phase 15 P05 | 20min | 2 tasks | 0 files |
| Phase 16 P01 | 18min | 2 tasks | 3 files |
| Phase 16 P02 | ~56min | 2 tasks | 4 files |

## Session Continuity

Last session: 2026-09-11T13:29:31.325Z
Stopped at: Completed 16-02-PLAN.md — shared ecosystem detectors + generalised smoke-gate helpers on feature/phase-16-sca-ecosystem-coverage (29dbc62)
Resume file: None

## Operator Next Steps

- Phase 16 Plan 01 complete: fixtures seeded and re-measured on branch
  `feature/phase-16-sca-ecosystem-coverage` in `repos/security-platform` (commit `68c3bbb`, not pushed).

- Next: 16-02-PLAN.md — extract `scripts/detect-{npm,python,terraform}.sh` and generalise the smoke-gate
  helpers. Note `tflint` exits **2** on findings; `run_scan()` currently treats anything but rc=1 as a
  tool error and would misclassify a healthy tflint run.
