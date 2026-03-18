---
phase: 10
slug: cross-platform-install-script
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + ShellCheck (no test framework — shell scripts validated by execution) |
| **Config file** | none — Wave 0 creates scripts |
| **Quick run command** | `shellcheck dist/install.sh && bash -n dist/install.sh` |
| **Full suite command** | `bash dist/install.sh -v` followed by version verification of all tools |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `shellcheck dist/install.sh && bash -n dist/install.sh`
- **After every plan wave:** Run `bash dist/install.sh -v` (full install)
- **Before `/gsd:verify-work`:** Full suite must be green — all tools respond to version command
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | INST-01 | smoke | `bash dist/install.sh -v` | ❌ W0 | ⬜ pending |
| 10-01-02 | 01 | 1 | INST-02 | smoke | Run on macOS arm64, verify correct binaries | ❌ W0 | ⬜ pending |
| 10-01-03 | 01 | 1 | INST-03 | smoke | `bash dist/install.sh -v && trivy --version \| grep 0.69.3` | ❌ W0 | ⬜ pending |
| 10-01-04 | 01 | 1 | INST-04 | smoke | Check output for PATH warning | ❌ W0 | ⬜ pending |
| 10-01-05 | 01 | 1 | INST-05 | smoke | `pipx list \| grep pre-commit` | ❌ W0 | ⬜ pending |
| 10-01-06 | 01 | 1 | INST-06 | smoke | `trivy --version && syft --version && grype --version && gitleaks version` | ❌ W0 | ⬜ pending |
| 10-01-07 | 01 | 1 | INST-07 | smoke | `hadolint --version \| grep 2.14.0` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `dist/install.sh` — main install script (to be created)
- [ ] `dist/versions.conf` — version manifest (to be created)
- [ ] ShellCheck validation: `shellcheck dist/install.sh`
- [ ] Bash syntax check: `bash -n dist/install.sh`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Cross-platform install on Linux | INST-01 | Requires Linux environment | Run `bash dist/install.sh -v` in Linux container or VM |
| Idempotent re-install | INST-01 | Requires full install cycle | Run install twice, verify no errors on second run |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
