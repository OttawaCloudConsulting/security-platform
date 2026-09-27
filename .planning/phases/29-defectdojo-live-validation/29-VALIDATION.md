---
phase: 29
slug: defectdojo-live-validation
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-26
---

# Phase 29 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Principle (ADR-022): Synced + Healthy is not evidence. Every verdict comes from a measured value captured into `.planning/phases/29-defectdojo-live-validation/evidence/` with run IDs and timestamps.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Standing bash gates (repo convention). New live gate `repos/security-platform/scripts/defectdojo-homelab-validate.sh`, modelled on `nexus-homelab-validate.sh` |
| **Config file** | none — Wave 0 creates the validate script |
| **Quick run command** | `bash scripts/check-adoption-guide.sh` (this repo); `bash scripts/check-defectdojo-chart.sh` + `actionlint` + `shellcheck` (security-platform) |
| **Full suite command** | `bash scripts/defectdojo-homelab-validate.sh --url https://defectdojo.infra.ottawacloudconsulting.com --context <ctx> --sync-pass second` plus D-11 API assertion evidence |
| **Estimated runtime** | ~120 seconds (live gate); offline gates < 30 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick run command relevant to the repo touched
- **After every plan wave:** Render the overlay (`helm template` with overlay values against the pinned SHA) and run the overlay repo's conformance check; run the live gate once the Application exists
- **Before `/gsd:verify-work`:** `--sync-pass first` (0 FAIL, expected SECOND-SYNC skip), then `--sync-pass second` (ALL PASS, 0 skipped), and D-11 evidence complete
- **Max feedback latency:** 120 seconds for offline gates. Live GitHub Actions runs in plans 29-15 and 29-16 take 45-60 minutes by nature and are sampled at wave boundaries only.

---

## Per-Task Verification Map

Filled by the planner/executor per task. Measurement sources per success criterion (from 29-RESEARCH.md §Validation Architecture):

| Behavior | Requirement | Test Type | Automated Command / Evidence | File Exists | Status |
|----------|-------------|-----------|------------------------------|-------------|--------|
| Application Synced/Healthy at pinned SHA, no ComparisonError | DDOJO-05 | live read | `kubectl get applications.argoproj.io defectdojo -o json` | ✅ | ⬜ pending |
| All images pulled (incl. GAR postgres) | DDOJO-05 / D-14 | live read | `kubectl -n defectdojo get events --field-selector reason=Pulled` | ✅ | ⬜ pending |
| LE prod cert, both SANs, trusted | DDOJO-05 / D-04 | live | validate script TLS checks (`curl -w '%{ssl_verify_result}'`, `openssl s_client`) | ❌ W0 | ⬜ pending |
| Login with `Origin` → 302 + `/dashboard` 200 on both hosts; foreign Origin → 403 | D-05 | live | validate script `HOMELAB-LOGIN-ORIGIN-{INFRA,HOME}`, `HOMELAB-CSRF-FOREIGN-403` | ❌ W0 | ⬜ pending |
| Celery broker round-trip | DDOJO-05 | live | `celery -A dojo inspect ping -t 5` via kubectl exec | ❌ W0 | ⬜ pending |
| configure.sh first run patches, second run no change | D-13 | live | `bash scripts/defectdojo-configure.sh` ×2 → evidence | ✅ | ⬜ pending |
| Second-sync idempotency (initializer UID, logs, counts preserved) | D-14 | live | validate script `--sync-pass second` | ❌ W0 | ⬜ pending |
| Postgres NetworkPolicy enforced on Cilium | D-14 | manual-with-evidence | throwaway pod `nc`, `hubble observe --verdict DROPPED` | — | ⬜ pending |
| Pod DNS NXDOMAIN without hostAliases; TLS 200 via hostAliases → VIP | reachability | manual-with-evidence | throwaway runner-image pod, before `DEFECTDOJO_URL` is set | ❌ W0 | ⬜ pending |
| ARC listener Running; repo-scoped runner registered; import job lands on it | D-06/D-07 | live | `kubectl -n arc-runners get autoscalingrunnersets,pods`; `gh api repos/.../actions/runners`; `gh run view --json jobs` | ✅ | ⬜ pending |
| Exactly 2 `runs-on` use the expression, 5 stay `ubuntu-latest`; required contexts unchanged | D-09 | static | yq/actionlint assertion; `gh api .../required_status_checks` | ❌ W0 | ⬜ pending |
| Baseline `ci/main` import via dispatch | DDOJO-05 / D-12 | live API | `gh workflow run scheduled-security.yml`; engagements/findings API | ❌ W0 | ⬜ pending |
| PR lifecycle: duplicates, dispositions survive reimport, engagement deleted on close | D-11 | live API | D-11 assertion helper using TRIAGE.md filters | ❌ W0 | ⬜ pending |
| Proof workflow import job on ARC logs SKIP, counts unchanged | D-10 | live | `gh run view --log` grep + counts | ✅ | ⬜ pending |
| Adoption guide documents `DEFECTDOJO_RUNS_ON` | D-09 | offline | `bash scripts/check-adoption-guide.sh` | ✅ (edit) | ⬜ pending |
| `v1.2.0` annotated and `v1` at same commit | D-09 | live | `gh api repos/.../git/ref/tags/v1` (ADR-018 method) | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `repos/security-platform/scripts/defectdojo-homelab-validate.sh` — TLS, Origin login both hosts, foreign-Origin 403, celery ping, second-sync checks
- [ ] D-11 API assertion helper (script or documented curl+jq block) using TRIAGE.md filters verbatim, emitting evidence JSON
- [ ] `scripts/check-adoption-guide.sh` — add `DEFECTDOJO_RUNS_ON` to required strings
- [ ] yq/actionlint assertion on `runs-on` shape
- [ ] Throwaway reachability pod manifest (runner image 2.337.0, with and without hostAliases)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No non-K8s device uses 10.40.3.65 | D-03 | UniFi console, operator only | UniFi client/ARP check before VIP pin |
| Pi-hole Local DNS entries | D-04 | Pi-hole not in git | Add both names → 10.40.3.65 on 10.40.1.53; decide 10.30.1.53 |
| PAT creation, fork-approval policy, repo secrets/vars | D-08/D-10 | Operator credentials | Operator checkpoints; Claude seals PAT without printing it |
| Postgres NetworkPolicy behaviour | D-14 | Needs Cilium/hubble observation | Evidence captured to `evidence/` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
