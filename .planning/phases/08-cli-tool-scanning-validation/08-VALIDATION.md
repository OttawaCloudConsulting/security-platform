---
phase: 8
slug: cli-tool-scanning-validation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell commands (scan execution + file verification) |
| **Config file** | none — direct CLI execution and file checks |
| **Quick run command** | `ls -la reports/*.json` |
| **Full suite command** | Run all 6 scans then verify all 6 JSON files exist with size > 0 |
| **Estimated runtime** | ~120 seconds (database downloads on first run may add time) |

---

## Sampling Rate

- **After every task commit:** Verify the specific tool's JSON output file exists and has size > 0
- **After every plan wave:** Verify all 6 JSON files exist with size > 0
- **Before `/gsd:verify-work`:** All 6 scans complete, all 6 JSON files present with content
- **Max feedback latency:** 30 seconds (file existence checks are instant; scans take longer but run during task)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | TOOL-07, TOOL-08 | smoke | `[ -s reports/trivy-results.json ]` | ❌ W0 | ⬜ pending |
| 08-01-02 | 01 | 1 | TOOL-07, TOOL-08 | smoke | `[ -s reports/sbom.json ]` | ❌ W0 | ⬜ pending |
| 08-01-03 | 01 | 1 | TOOL-07, TOOL-08 | smoke | `[ -s reports/grype-results.json ]` | ❌ W0 | ⬜ pending |
| 08-01-04 | 01 | 1 | TOOL-07, TOOL-08 | smoke | `[ -s reports/semgrep-results.json ]` | ❌ W0 | ⬜ pending |
| 08-01-05 | 01 | 1 | TOOL-07, TOOL-08 | smoke | `[ -s reports/checkov-results.json ]` | ❌ W0 | ⬜ pending |
| 08-01-06 | 01 | 1 | TOOL-07, TOOL-08 | smoke | `[ -s reports/gitleaks-results.json ]` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `aws-zabbix-monitoring-solution/reports/` directory — needs creation
- [ ] `aws-zabbix-monitoring-solution/reports/.gitignore` — needs creation to git-ignore JSON files

*Existing infrastructure covers test framework — shell commands only.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Documentation validation notes added | TOOL-08 | Content quality check | Verify each tool section in main doc has "Validated" note |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
