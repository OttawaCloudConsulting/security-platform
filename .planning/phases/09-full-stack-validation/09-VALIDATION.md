---
phase: 9
slug: full-stack-validation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pre-commit framework (shell-based validation) |
| **Config file** | `.pre-commit-config.yaml` (per-repo) |
| **Quick run command** | `pre-commit run --all-files` |
| **Full suite command** | `pre-commit run --all-files` (run in each target repo) |
| **Estimated runtime** | ~30-60 seconds per repo |

---

## Sampling Rate

- **After every task commit:** Run `pre-commit run --all-files` in affected repo
- **After every plan wave:** Run `pre-commit run --all-files` in all target repos
- **Before `/gsd:verify-work`:** Full suite must be green in all repos
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | PCOM-04 | integration | `pre-commit run --all-files` (security_solution) | ✅ | ⬜ pending |
| 09-01-02 | 01 | 1 | PCOM-04 | integration | `pre-commit run --all-files` (aws-zabbix) | ✅ | ⬜ pending |
| 09-01-03 | 01 | 1 | PCOM-04 | integration | `pre-commit run --all-files` (terraform-pipelines) | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] hadolint native binary installed (`brew install hadolint`) — prerequisite for hook ID change
- [ ] `.markdownlint.json` present in terraform-pipelines — prevents mass failures

*These are infrastructure prerequisites that must be resolved before validation tasks.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| All 9 Tier 1 hooks execute | PCOM-04 | Need to inspect output for each hook name | Review `pre-commit run --all-files` output, confirm each hook listed |
| Gitleaks Tier 2 hook executes | PCOM-04 | Gitleaks output must show in hook output | Verify gitleaks hook appears in output |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
