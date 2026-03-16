---
phase: 3
slug: web-and-config-hooks
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pre-commit 4.5.0 (hook execution framework) |
| **Config file** | `repos/aws-zabbix-monitoring-solution/.pre-commit-config.yaml` |
| **Quick run command** | `cd repos/aws-zabbix-monitoring-solution && pre-commit run eslint --all-files && pre-commit run yamllint --all-files && pre-commit run markdownlint --all-files` |
| **Full suite command** | `cd repos/aws-zabbix-monitoring-solution && pre-commit run --all-files --show-diff-on-failure` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run relevant hook(s) with `--all-files`
- **After every plan wave:** Run `cd repos/aws-zabbix-monitoring-solution && pre-commit run --all-files --show-diff-on-failure`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | LINT-03 | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run eslint --all-files` | N/A (pre-commit) | ⬜ pending |
| 03-02-01 | 02 | 1 | LINT-06 | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run markdownlint --all-files` | N/A (pre-commit) | ⬜ pending |
| 03-03-01 | 03 | 2 | LINT-05 | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run yamllint --all-files` | N/A (pre-commit) | ⬜ pending |
| 03-04-01 | 04 | 2 | LINT-04 | smoke (manual temp) | `cd repos/aws-zabbix-monitoring-solution && echo 'FROM ubuntu:22.04\nRUN apt-get install -y curl' > Dockerfile && pre-commit run hadolint-docker --files Dockerfile; git rm -f Dockerfile` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `eslint.config.mjs` — ESLint flat config file (does not exist yet)
- [ ] `npm install --save-dev eslint @eslint/js typescript-eslint` — ESLint packages not yet in devDependencies
- [ ] `.markdownlint.json` — markdownlint config file (does not exist yet)
- [ ] `.markdownlintignore` — markdownlint ignore file (does not exist yet)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| hadolint flags Dockerfile violations | LINT-04 | No Dockerfiles in repo; requires temp file creation + Docker running | Create temp Dockerfile with `apt-get install` (no pinned versions), run `pre-commit run hadolint-docker --files Dockerfile`, verify DL3008 warning, delete temp file |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
