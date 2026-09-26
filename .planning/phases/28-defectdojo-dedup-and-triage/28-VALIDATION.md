---
phase: 28
slug: defectdojo-dedup-and-triage
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-25
---

# Phase 28 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `28-RESEARCH.md` § Validation Architecture, plus the operator decisions D-20 to D-23 in `28-CONTEXT.md`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash assertion harnesses (no unit-test framework): `check-defectdojo-chart.sh` (offline), `defectdojo-import-proof.sh` (kind), `check-adoption-guide.sh` (this repo) |
| **Config file** | none. The scripts are self-contained |
| **Quick run command** | `bash scripts/check-defectdojo-chart.sh` (run in `repos/security-platform/`) |
| **Full suite command** | `bash scripts/defectdojo-import-proof.sh <reports-dir>` (kind, in `repos/security-platform/`) plus a GitHub run of the `DefectDojo Import Proof` workflow |
| **Estimated runtime** | quick < 30 seconds; full 15-30 minutes |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/check-defectdojo-chart.sh`. When the proof script changes, also run `bash scripts/defectdojo-import-proof.sh --extract-only`. When this repo's docs change, run `bash scripts/check-adoption-guide.sh`.
- **After every plan wave:** Run a local kind proof.
- **Before `/gsd:verify-work`:** The kind proof is green locally, the GitHub `DefectDojo Import Proof` run is green (D-12), and `bash scripts/check-adoption-guide.sh` is green.
- **Max feedback latency:** 30 seconds (offline gates)

---

## Per-Task Verification Map

Task IDs filled in by the planner (28-01..28-09). The local kind run of every live row is 28-05-T1; the GitHub run is 28-07-T2. Each row is a behaviour that must map to at least one task.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 28-01-T1, 28-01-T2 | 28-01 | 1 | DDOJO-03 | cascade delete | extraConfigs renders `DD_DUPLICATE_CLUSTER_CASCADE_DELETE=False` and a JSON-valid `DD_DEDUPLICATION_ALGORITHM_PER_PARSER` for the 7 scan types; no `DD_HASHCODE_FIELDS_PER_SCANNER` (D-20) | offline | `bash scripts/check-defectdojo-chart.sh` | ✅ extend | ⬜ pending |
| 28-02-T1, 28-02-T2, 28-03-T1 | 28-02, 28-03 | 2, 3 | DDOJO-03/04 | token leak / http | The bootstrap turns dedup on, turns both FP-history flags off and sets `risk_acceptance_form_default_days=90`; it leaves `enable_finding_sla` untouched; a second run reports NO CHANGE; https only; token in a 0600 file | kind | proof `P-CONFIGURE` / `P-IDEMPOTENT` | ❌ W0 | ⬜ pending |
| 28-03-T2 | 28-03 | 3 | DDOJO-03 | — | After a main import, a PR import with a delta leaves the PR's active set equal to the delta; the other PR findings are `duplicate=true, active=false` | kind | `P-DEDUP-BRANCH` | ❌ W0 | ⬜ pending |
| 28-03-T2 | 28-03 | 3 | DDOJO-03 | — | The measured cross-tool SCA gap (no Trivy↔pip-audit or Trivy↔npm links) is recorded as the D-07 evidence | kind | `P-CROSSTOOL` | ❌ W0 | ⬜ pending |
| 28-04-T2 | 28-04 | 4 | DDOJO-03 | cascade delete | PR imported first, then main, then the PR engagement DELETE: the main copies are `duplicate=false, active=true` immediately | kind | `P-REPARENT` | ❌ W0 | ⬜ pending |
| 28-04-T1 | 28-04 | 4 | DDOJO-04 | disposition lost | After 2 reimports, the exact tuples hold: FP `false_p=T, active=F, is_mitigated=T`; OOS `out_of_scope=T, active=F, is_mitigated=T`; RA `risk_accepted=T, active=F, is_mitigated=F` | kind | `P-DISPOSITION` | ❌ W0 | ⬜ pending |
| 28-04-T1 | 28-04 | 4 | DDOJO-04 | PR hides finding | A new PR import after the dispositions makes the matching PR copies inactive duplicates | kind | `P-SUPPRESS` | ❌ W0 | ⬜ pending |
| 28-06-T1, 28-09-T2 | 28-06, 28-09 | 6, 9 | DDOJO-04 | — | The triage runbook is linked from `docs/adoption-guide.md` | offline | `bash scripts/check-adoption-guide.sh` | ✅ extend | ⬜ pending |
| 28-02-T2, 28-07-T2 | 28-02, 28-07 | 2, 7 | both | — | The real GitHub `DefectDojo Import Proof` run is green | CI | the workflow run (path-filtered and dispatch) | ✅ extend `paths:` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/defectdojo-configure.sh` (or the chosen name) exists before the proof calls it
- [ ] A delta fixture or report strategy for `P-DEDUP-BRANCH` (research Pitfall 7)
- [ ] A `paths:` entry for the bootstrap script in `defectdojo-import-proof.yml`
- [ ] A plan to bump the gate count literals (research Pitfall 5)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Triage runbook is usable by the operator (filters, disposition steps, 90-day RA expiry + reason by procedure) | DDOJO-04 | Documentation quality | Read the runbook against D-13 to D-15 and D-21 to D-23 |
| Hash recompute note in the chart README (D-08) | DDOJO-03 | No live install until Phase 29 | Confirm the README gives the `manage.py dedupe` command |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
