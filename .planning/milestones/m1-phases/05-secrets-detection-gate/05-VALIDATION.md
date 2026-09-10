---
phase: 5
slug: secrets-detection-gate
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash (shell command verification) |
| **Config file** | none — manual CLI verification |
| **Quick run command** | `gitleaks version && pre-commit --version` |
| **Full suite command** | `cd repos/aws-zabbix-monitoring-solution && git push --dry-run 2>&1` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `gitleaks version && pre-commit --version`
- **After every plan wave:** Run full push-test with dummy key on each repo
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | SECR-01 | integration | `git push --dry-run 2>&1 \| grep -i gitleaks` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | SECR-02 | integration | `echo "AKIAIOSFODNN7EXAMPLE" > /tmp/test-secret.txt && git add /tmp/test-secret.txt && git push --dry-run 2>&1` | ❌ W0 | ⬜ pending |
| 05-01-03 | 01 | 1 | SECR-03 | manual | See manual verifications below | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Gitleaks installed via `brew install gitleaks`
- [ ] Pre-push hook type installed in target repos via `pre-commit install --hook-type pre-push`

*Existing pre-commit infrastructure from Phase 1 covers framework requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Developer understands `--no-verify` bypass | SECR-03 | Requires human comprehension check | Read bypass documentation in main doc, README, and config comments; verify CI compensating control is mentioned |

*SECR-03 success criterion is "Developer can articulate" — inherently manual.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
