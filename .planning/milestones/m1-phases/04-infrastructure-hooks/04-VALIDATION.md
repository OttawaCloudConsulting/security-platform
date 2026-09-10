---
phase: 4
slug: infrastructure-hooks
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pre-commit (hook execution framework) |
| **Config file** | `.pre-commit-config.yaml` in each target repo |
| **Quick run command** | `pre-commit run <hook-id> --files <file>` |
| **Full suite command** | `pre-commit run --all-files` (per repo) |
| **Estimated runtime** | ~30 seconds (first terraform validate may take longer due to provider init) |

---

## Sampling Rate

- **After every task commit:** Run specific hook against relevant files
- **After every plan wave:** `pre-commit run --all-files` in each target repo
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 0 | LINT-07 | setup | `cd repos/aws-zabbix-monitoring-solution && npm audit --audit-level=high` | N/A | ⬜ pending |
| 04-01-02 | 01 | 0 | LINT-08, LINT-09 | setup | `cd repos/terraform-pipelines && pre-commit run --all-files` | N/A | ⬜ pending |
| 04-01-03 | 01 | 1 | LINT-07 | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run npm-audit --files package-lock.json` | N/A | ⬜ pending |
| 04-01-04 | 01 | 1 | LINT-08 | smoke | `cd repos/terraform-pipelines && pre-commit run terraform_fmt --all-files` | N/A | ⬜ pending |
| 04-01-05 | 01 | 1 | LINT-09 | smoke | `cd repos/terraform-pipelines && pre-commit run terraform_validate --all-files` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Run `npm audit fix` in `repos/aws-zabbix-monitoring-solution` to clear existing high vulnerabilities
- [ ] Clone `terraform-pipelines` to `repos/terraform-pipelines/`
- [ ] Copy `.pre-commit-config.yaml` to terraform-pipelines
- [ ] Run `pre-commit install` in terraform-pipelines
- [ ] Run `pre-commit autoupdate` in terraform-pipelines for latest hook versions

*Wave 0 must complete before any validation tasks can run.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| terraform_fmt auto-fixes staged files | LINT-08 | Must observe in-place rewrite and commit failure/retry cycle | 1. Mis-format a .tf file 2. Stage and commit 3. Observe hook reformats file 4. Re-stage and commit successfully |
| terraform_validate catches invalid HCL | LINT-09 | Must observe error output on deliberately invalid syntax | 1. Add invalid HCL to a .tf file 2. Stage and commit 3. Observe validation error blocks commit |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
