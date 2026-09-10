---
phase: 7
slug: sast-and-iac-cli-tools
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell commands (version checks) |
| **Config file** | none — direct CLI verification |
| **Quick run command** | `semgrep --version && checkov --version && gitleaks version` |
| **Full suite command** | `semgrep --version && checkov --version && gitleaks version` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `semgrep --version && checkov --version && gitleaks version`
- **After every plan wave:** Run `semgrep --version && checkov --version && gitleaks version`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | TOOL-04 | smoke | `semgrep --version` | N/A (CLI) | ⬜ pending |
| 07-01-02 | 01 | 1 | TOOL-05 | smoke | `checkov --version` | N/A (CLI) | ⬜ pending |
| 07-01-03 | 01 | 1 | TOOL-06 | smoke | `gitleaks version` | N/A (CLI) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework or stub files needed — tools self-verify via version commands.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
