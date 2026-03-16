---
phase: 2
slug: shell-and-python-hooks
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pre-commit CLI (hooks as test harness) |
| **Config file** | `.pre-commit-config.yaml` |
| **Quick run command** | `pre-commit run --files <changed-file>` |
| **Full suite command** | `pre-commit run --all-files --show-diff-on-failure` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `pre-commit run --files <changed-file>`
- **After every plan wave:** Run `pre-commit run --all-files --show-diff-on-failure`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | LINT-01 | integration | `pre-commit run shellcheck --files scripts/*.sh` | ✅ | ⬜ pending |
| 02-01-02 | 01 | 1 | LINT-02 | integration | `pre-commit run ruff --files scripts/*.py` | ✅ | ⬜ pending |
| 02-01-03 | 01 | 1 | LINT-01, LINT-02 | integration | `pre-commit run --all-files --show-diff-on-failure` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Pre-commit framework installed in Phase 1.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Unquoted variable triggers ShellCheck warning | LINT-01 | Requires deliberate bad commit | 1. Create temp shell file with `echo $unquoted` 2. `git add` + `git commit` 3. Verify ShellCheck blocks/warns |
| Python formatting violation triggers Ruff auto-fix | LINT-02 | Requires deliberate bad commit | 1. Create temp .py with bad formatting 2. `git add` + `git commit` 3. Verify Ruff reformats file |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
