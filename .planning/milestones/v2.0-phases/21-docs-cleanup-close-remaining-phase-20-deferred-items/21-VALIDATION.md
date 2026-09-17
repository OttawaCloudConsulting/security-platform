---
phase: 21
slug: docs-cleanup-close-remaining-phase-20-deferred-items
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-15
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — documentation-only phase (no code, no test runner). Verification is grep/markdownlint/bash-script assertions against prose. |
| **Config file** | `.markdownlint.jsonc` (effective lint rules), `.markdownlint-cli2.yaml` (lint entrypoint), `scripts/check-adoption-guide.sh` (standing doc gate, 15 assertions) |
| **Quick run command** | `markdownlint-cli2 {changed file}` |
| **Full suite command** | `bash scripts/check-adoption-guide.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `markdownlint-cli2 {file this task edited}`
- **After every plan wave:** Run `bash scripts/check-adoption-guide.sh` (must stay `PASSED 15 / FAILED 0`)
- **Before `/gsd:verify-work`:** Full suite (`check-adoption-guide.sh`) must be green and all four plans' `<automated>` verify blocks must pass
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 01 | 1 | DIST-06 | N/A — docs only | N/A | grep + lint | `grep -c -i grype` count check + `markdownlint-cli2` | ✅ | ⬜ pending |
| 21-01-02 | 01 | 1 | DIST-06 | N/A — docs only | N/A | grep + lint | `grep -c -i grype` -eq 0 + filename/parser-string greps + `markdownlint-cli2` | ✅ | ⬜ pending |
| 21-02-01 | 02 | 1 | DIST-06 | N/A — docs only | N/A | grep + lint | `grep -c -i grype` count check + `markdownlint-cli2` | ✅ | ⬜ pending |
| 21-02-02 | 02 | 1 | DIST-06 | N/A — docs only | N/A | grep + lint | `grep -c -i grype` -eq 0 + filename greps + `markdownlint-cli2` | ✅ | ⬜ pending |
| 21-03-01 | 03 | 1 | DIST-08 | N/A — docs only | N/A | grep + lint | limit-number/URL greps + heading-count check + `markdownlint-cli2` | ✅ | ⬜ pending |
| 21-03-02 | 03 | 1 | DIST-08 | T-20-12 (gate tampering) | Gate script and lint config remain untouched | lint + gate script + commit-scoped diff | `markdownlint-cli2` + `check-adoption-guide.sh` + `git diff HEAD~1 --name-only` scoped check | ✅ | ⬜ pending |
| 21-04-01 | 04 | 2 | DIST-06, DIST-08 | N/A — docs only | N/A | grep + commit-scoped diff | deferred-items.md status-recheck greps + `git diff --numstat` | ✅ | ⬜ pending |
| 21-04-02 | 04 | 2 | DIST-06, DIST-08 | T-20-12 (gate tampering), collateral-damage check on ADRs/M1 docs | No out-of-scope file touched; Grype fully removed from in-scope docs | grep + lint + gate script + porcelain allowlist | full 5-file grep/lint/gate check + `git status --porcelain` on out-of-scope allowlist | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — `scripts/check-adoption-guide.sh` (15 assertions,
measured baseline `PASSED 15 / FAILED 0`) and `markdownlint-cli2` (measured baseline `0 error(s)` on all
three target docs) already exist and were exercised during research. No new test infrastructure needed.

---

## Manual-Only Verifications

All phase behaviors have automated verification (grep/markdownlint/bash-gate assertions, all embedded in
each plan's `<automated>` verify block and `<acceptance_criteria>`).

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (all 8 tasks across 4 plans have one)
- [x] Wave 0 covers all MISSING references (none missing — existing gate + linter suffice)
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
