---
phase: 25
slug: nexus-live-validation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-21
---

# Phase 25 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash gate scripts — the established `security-platform/scripts/` convention (Phase 23/24 pattern). No pytest/jest/vitest harness in either repo for this domain. |
| **Config file** | none — each script is self-contained, non-executable, invoked as `bash scripts/<name>.sh` |
| **Quick run command** | `bash scripts/check-nexus-chart.sh` (offline, 18 checks, seconds) |
| **Full suite command** | `bash scripts/nexus-homelab-validate.sh` (new, live, minutes) — plus overlay-repo gate `python3 docs/argocd/conformance/c1.py && python3 docs/argocd/conformance/check_appconfig.py` |
| **Estimated runtime** | ~5 seconds (quick, offline) / several minutes (full, live cluster round trip) |

Preserve the VACUOUS-PASS convention from Phase 24: a run in which nothing executed prints `NOTHING RAN`, not `ALL PASS`; SKIP is never counted as a pass.

---

## Sampling Rate

- **After every task commit:** `bash scripts/check-nexus-chart.sh` (if the chart was touched); `python3 c1.py` (if the override file was touched) — both seconds.
- **Per overlay-repo PR:** the required `conformance` check on the private overlay repo — non-negotiable, gates the merge (`main` is protected, PR required).
- **After every plan wave:** `bash scripts/nexus-homelab-validate.sh` against the live homelab deployment.
- **Before `/gsd:verify-work`:** full homelab script green with byte counts captured as evidence.
- **Max feedback latency:** ~a few minutes (live cluster sync + pull round trips dominate).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 25-W0-01 | TBD | 0 | NEXUS-05 | — | Override file is schema- and routing-legal (existing project, existing namespace, no `kind: '*'`) | static | `python3 docs/argocd/conformance/c1.py && python3 docs/argocd/conformance/check_appconfig.py` (overlay clone) | ✅ exists in overlay repo | ⬜ pending |
| 25-W0-02 | TBD | 0 | NEXUS-05 | — | Chart still renders after any edit | static | `bash scripts/check-nexus-chart.sh` | ✅ `security-platform/scripts/` | ⬜ pending |
| 25-W0-03 | TBD | 0 | NEXUS-05 | — | Application reaches Synced + Healthy | live | `argocd app wait nexus --sync --health --timeout 1200` | ❌ W0 (new script) | ⬜ pending |
| 25-W0-04 | TBD | 0 | NEXUS-05 | — | Provisioning Job ran as a Sync hook and succeeded | live | `ARGOCD-HOOK-PHASE` (jq over `.status.operationState.syncResult.resources[]`) | ❌ W0 | ⬜ pending |
| 25-W0-05 | TBD | 0 | NEXUS-05 | — | Job completed; logs show 4× `action=created` | live | `kubectl wait --for=condition=complete job/nexus-provision` + log grep (`PROVISION-JOB-COMPLETE`) | ❌ W0 | ⬜ pending |
| 25-W0-06 | TBD | 0 | NEXUS-03 | — | PVC bound on the cluster's default StorageClass | live | `PVC-DEFAULT-STORAGECLASS` | ❌ W0 | ⬜ pending |
| 25-W0-07 | TBD | 1 | NEXUS-02 | — | Anonymous npm / PyPI / Helm pull (transport, HTTP 200, size — three verdicts each) | live | `ANONYMOUS-PULL-{ALLOWED,PYPI,HELM}-*` | ⚠️ bodies exist in `nexus-live-smoke.sh`; need `NEXUS_HOST` parameterisation | ⬜ pending |
| 25-W0-08 | TBD | 1 | NEXUS-02 | — | `DockerToken` realm active exactly once, `NexusAuthenticatingRealm` intact | live | `DOCKER-REALM-ACTIVE` | ⚠️ needs parameterisation | ⬜ pending |
| 25-W0-09 | TBD | 1 | NEXUS-01 | — | Docker path shape: 200 on `HOST/<repo>/<image>`, 404 on the `/repository/` analogy shape | live | `DOCKER-PATH-SHAPE` | ⚠️ needs parameterisation | ⬜ pending |
| 25-W0-10 | TBD | 1 | NEXUS-02 | — | Full anonymous OCI handshake (5 legs), layer blob > 1,000,000 B | live | `ANONYMOUS-PULL-DOCKER` | ⚠️ needs parameterisation | ⬜ pending |
| 25-W0-11 | TBD | 1 | NEXUS-02 | — | Anonymous write refused (valid-body POST → 403) and created nothing (admin GET → 404, name exists → 200) | live | `ANONYMOUS-WRITE-DENIED` | ⚠️ needs parameterisation | ⬜ pending |
| 25-W0-12 | TBD | 2 | ADR-021 #7 | — | Second sync is idempotent against existing PVC state (`action=updated`, realms list unchanged) | live | `SECOND-SYNC-IDEMPOTENT` | ❌ W0 | ⬜ pending |
| 25-W0-13 | TBD | 2 | NEXUS-04 | — | Client-side routing against the homelab host (optional, non-blocking) | live | `bash workstation/nexus-setup.sh --verify` pointed at the port-forwarded URL | ✅ exists (12 checks) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Waves are provisional — the planner assigns actual wave numbers; ingress/TLS is out of scope (excluded per user decision 2026-09-21, recorded in ADR-022), validation runs over `kubectl port-forward`.*

---

## Wave 0 Requirements

- [ ] `security-platform/scripts/nexus-homelab-validate.sh` — `NEXUS_HOST`-parameterised extraction of `nexus-live-smoke.sh`'s anonymous-pull / write-refusal sections, plus four new cluster-side checks: `ARGOCD-HOOK-PHASE`, `PROVISION-JOB-COMPLETE`, `PVC-DEFAULT-STORAGECLASS`, `SECOND-SYNC-IDEMPOTENT`. Must preserve the `pass`/`fail`/`CHECKS_PASSED`/`SKIPPED` discipline and the three-verdicts-per-fetch split.
- [ ] Overlay-repo clone on the workstation (D-02 credentials) so `c1.py` / `check_appconfig.py` can run before the PR, not after.
- [ ] `platform` AppProject amendment declared and merged before the Application manifest references it (per user decision: amend `platform`, not a new `security` project).

*Existing offline gate `check-nexus-chart.sh` and `workstation/nexus-setup.sh --verify` already cover their rows — no new Wave 0 work for those.*

---

## Manual-Only Verifications

*None — all phase behaviors have automated (offline or live-gate) verification per RESEARCH.md.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < a few minutes (live round trips)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
