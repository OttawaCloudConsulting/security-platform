---
phase: 6
slug: sca-and-container-cli-tools
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell commands (version checks) |
| **Config file** | none — direct CLI verification |
| **Quick run command** | `trivy --version && syft version && grype version` |
| **Full suite command** | `trivy --version && syft version && grype version` |
| **Estimated runtime** | ~3 seconds |

---

## Sampling Rate

- **After every task commit:** Run `trivy --version && syft version && grype version`
- **After every plan wave:** Run `trivy --version && syft version && grype version`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 3 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | TOOL-01 | smoke | `trivy --version` | N/A (CLI) | ⬜ pending |
| 06-01-02 | 01 | 1 | TOOL-02 | smoke | `syft version` | N/A (CLI) | ⬜ pending |
| 06-01-03 | 01 | 1 | TOOL-03 | smoke | `grype version` | N/A (CLI) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.* CLI tools self-verify via `--version` commands. No test framework or test files needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Trivy DB freshness | TOOL-01 | DB timestamp not in `--version` output | Run `trivy image --download-db-only` and verify no errors |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 3s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
