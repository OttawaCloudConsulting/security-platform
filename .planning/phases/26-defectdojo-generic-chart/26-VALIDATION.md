---
phase: 26
slug: defectdojo-generic-chart
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-24
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Standing bash gates under `scripts/` in `repos/security-platform` (no Helm unit-test framework) |
| **Config file** | none — Wave 0 creates `repos/security-platform/scripts/check-defectdojo-chart.sh` and `repos/security-platform/scripts/defectdojo-live-smoke.sh` |
| **Quick run command** | `bash scripts/check-defectdojo-chart.sh` (offline, run from `repos/security-platform`) |
| **Full suite command** | `bash scripts/check-defectdojo-chart.sh && bash scripts/defectdojo-live-smoke.sh` |
| **Estimated runtime** | gate ~10 seconds; live smoke dominated by cold image pulls on kind (helm timeout 15m) |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/check-defectdojo-chart.sh` (must exit 0 at every intermediate commit — vacuous-pass SKIP guards)
- **After every plan wave:** Run the gate plus `shellcheck scripts/*defectdojo*.sh`
- **Before `/gsd:verify-work`:** Full suite green — smoke with 0 FAIL and 0 SKIPPED, kube context pinned to the throwaway kind cluster
- **Max feedback latency:** 10 seconds (offline gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 26-TBD | TBD | 0 | DDOJO-01 | — | Offline gate exists and SKIP-guards absent chart | offline | `bash scripts/check-defectdojo-chart.sh` | ❌ W0 | ⬜ pending |
| 26-TBD | TBD | TBD | DDOJO-01 | T-26 secrets / env leakage | Chart renders; ingress+TLS on; issuer required via `fail`; class/SC unset; PG persistent; Valkey ephemeral; no secrets rendered; pins consistent; no `defectdojo.*` helper collision; placeholders only | offline | `bash scripts/check-defectdojo-chart.sh` | ❌ W0 | ⬜ pending |
| 26-TBD | TBD | TBD | DDOJO-01 | T-26 fake cert / spoofing | kind install → Deployments Ready → Certificate Ready → ingressClassName defaulted → `--cacert` TLS `/login` 200 → admin login 302 + `/dashboard` 200 → `celery inspect ping` | live smoke | `bash scripts/defectdojo-live-smoke.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Task IDs finalized by planner; rows above map to requirement coverage from 26-RESEARCH.md.*

---

## Wave 0 Requirements

- [ ] `repos/security-platform/scripts/check-defectdojo-chart.sh` — offline gate for DDOJO-01 (check IDs in 26-RESEARCH.md)
- [ ] `repos/security-platform/scripts/defectdojo-live-smoke.sh` — live smoke for DDOJO-01; clone ownership guard, context restore and SKIPPED/FAILURES/CHECKS_PASSED accounting from `nexus-live-smoke.sh`
- [ ] Framework install: none — all tools present (helm v4.3.0, kind, kubectl, checkov, shellcheck)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Checkov count on rendered chart recorded (CI coverage = 0) | DDOJO-01 | Guard fails bare render, so CI Checkov cannot cover chart | `helm template … > r.yaml && checkov -f r.yaml --framework kubernetes`; record counts in SUMMARY |
| Chart public on `security-platform` main; CI green | DDOJO-01 | Operator approval of PR merge | `gh pr checks <n> --watch`, then operator merges |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
