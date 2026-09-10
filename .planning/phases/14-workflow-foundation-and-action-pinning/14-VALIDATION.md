---
phase: 14
slug: workflow-foundation-and-action-pinning
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-10
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — this repo has no test runner (CLAUDE.md: "not buildable software"). Validation is static linting plus live observation of GitHub-side state via `gh`. |
| **Config file** | none — Wave 0 installs `actionlint`; yamllint uses `-d relaxed` (matches `repos/security-platform/.pre-commit-config.yaml`), no new `.yamllint` file added |
| **Quick run command** | `actionlint repos/security-platform/.github/workflows/*.yml && yamllint -d relaxed repos/security-platform/.github/` |
| **Full suite command** | Quick run, then the `gh`-based observation sequence (workflow registration → PR run status → merge-eligibility → post-merge Dependabot classification) |
| **Estimated runtime** | ~5s static; e2e steps depend on GitHub Actions run time (~1-3 min per PR run) |

Do **not** introduce pytest/jest/etc. A test framework would be scaffolding with nothing to test; the meaningful assertions are all about GitHub-side state (workflow files parse, pins are correct SHAs, PR runs complete, Dependabot reacts).

---

## Sampling Rate

- **After every task commit:** `actionlint .github/workflows/*.yml` + SHA-pin format grep (< 2s)
- **After every plan wave:** full static set + `gh api .../actions/workflows` registration check
- **Phase gate:** PR-triggered run observed green and non-blocking → merge to `main` (user-confirmed checkpoint) → Dependabot PR/log observed → all 4 ROADMAP criteria witnessed
- **Max feedback latency:** ~180s (bounded by GitHub Actions run completion, not local test execution)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | CICD-05 (preflight) | Fresh branch off `origin/main`, clean tree, `.github/` doesn't yet exist, tooling present | static | `git fetch` + ancestry + clean-tree + `actionlint --version` checks | ✅ | ⬜ pending |
| 14-01-02 | 01 | 1 | CICD-05 / Criteria #2, #3 | Callable workflow (`workflow_call`) + thin caller, `actions/checkout` pinned to `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0  # v7.0.0`, no `pull_request` on callable, no job-shape leakage on caller | static | `actionlint` + grep assertions on both workflow files | ✅ | ⬜ pending |
| 14-01-03 | 01 | 1 | CICD-05 (Dependabot config) | Single `github-actions` ecosystem entry, weekly schedule, SHA belongs to canonical `v7.0.0` tag, all 3 files committed and not gitignored | static + integration | `yamllint -d relaxed` + `actionlint` + `gh api repos/actions/checkout/...` tag resolution + git state checks | ✅ | ⬜ pending |
| 14-02-01 | 02 | 2 | Criterion #1, #2 | Branch pushed, PR opened against `main`, both workflows registered server-side | integration | `gh pr view`/`gh api .../actions/workflows` | ✅ | ⬜ pending |
| 14-02-02 | 02 | 2 | Criterion #1 | PR-triggered run completes successfully, PR is mergeable, no required-status-check rule blocks merge | e2e | `gh run view` + `gh pr view --json mergeable` + `gh api .../rules/branches/main` | ✅ | ⬜ pending |
| 14-03-01 | 03 | 3 | (checkpoint) | Human-confirmed merge of PR to `main` — not autonomous | manual | checkpoint:human-verify, blocking gate | N/A | ⬜ pending |
| 14-03-02 | 03 | 3 | CICD-05 / Criterion #4 | Dependabot config live on `main`, pin present, classify witnessed/inferred/broken per branch logic | e2e, post-merge | `gh api contents/...` + `gh pr list --author app/dependabot` + `gh api repos/actions/checkout/releases/latest` | ✅ | ⬜ pending |
| 14-03-03 | 03 | 3 | CICD-05 (close-out) | Final state confirmation across all 4 criteria | e2e | `gh api contents/...` + `gh pr list --author app/dependabot --state all` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `actionlint` — install via `brew install actionlint` (Task 14-01-01 preflight, verified present before Task 2 runs)
- [x] yamllint override — resolved as `-d relaxed` (matches `repos/security-platform/.pre-commit-config.yaml`); no new `.yamllint` file needed, default ruleset's `line-length`/`truthy` false positives on Actions YAML are covered by `relaxed`

*No test-framework stubs required — this phase has no unit-testable logic, only static config/YAML and live GitHub state.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Merge PR to `main` | CICD-05 (enables Criterion #4 observation) | Dependabot config is only read from the default branch; merging is an irreversible, shared-state action per this project's session-management protocol (Irreversible Actions) — must not be automated | Task 14-03-01: user reviews the green PR run, then merges via `gh pr merge` or the GitHub UI; agent halts and waits for explicit confirmation before proceeding to Task 14-03-02 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or are the documented manual checkpoint (14-03-01)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (only 1 manual task, bracketed by automated tasks on both sides)
- [x] Wave 0 covers all MISSING references (actionlint install, yamllint override resolved)
- [x] No watch-mode flags
- [x] Feedback latency bounded by GitHub Actions run time (~180s), acceptable for this phase's e2e-only validation shape
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-09-10
