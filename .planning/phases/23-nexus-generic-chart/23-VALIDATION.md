---
phase: 23
slug: nexus-generic-chart
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-17
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None exists for Helm charts yet. Repo convention is standing shell gates under `scripts/` (`check-workflow-uploads.sh`, `check-detector-parity.sh`, `smoke-scans.sh`) run with `bash script.sh`. |
| **Config file** | none — Wave 0 creates `repos/security-platform/scripts/check-nexus-chart.sh` |
| **Quick run command** | `bash scripts/check-nexus-chart.sh` (offline: lint + template + assertions) |
| **Full suite command** | `bash scripts/check-nexus-chart.sh && bash scripts/nexus-live-smoke.sh` (docker-based live smoke) |
| **Estimated runtime** | ~5s offline / ~3min live (docker boot + two-pass provisioning) |

---

## Sampling Rate

- **After every task commit:** `helm lint kubernetes/nexus` + `helm template`-based assertions
- **After every plan wave:** offline gate + docker-based two-pass idempotency test
- **Before `/gsd:verify-work`:** full offline gate + docker live smoke must be green
- **Max feedback latency:** ~3 minutes (live smoke)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 23-01-TBD | 01 | 0 | NEXUS-03 | — | Omitting `storageClass` emits no `storageClassName` key | unit | `helm template kubernetes/nexus \| yq 'select(.kind=="StatefulSet")\|.spec.volumeClaimTemplates[0].spec\|has("storageClassName")'` → `false` | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | NEXUS-03 | — | Setting `storageClass` emits it verbatim | unit | same command with `--set nexus3.persistence.storageClass=test` → `"test"` | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | NEXUS-03 | — | `persistence.enabled` defaults `true` (D-10) | unit | `yq '.nexus3.persistence.enabled' kubernetes/nexus/values.yaml` → `true` | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | NEXUS-01 | T-23-01 | Exactly one provisioning Job renders with `helm.sh/hook` annotation | unit | `helm template … \| yq 'select(.kind=="Job")\|.metadata.annotations'` contains `helm.sh/hook` | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | NEXUS-01 | T-23-04 | All four repo bodies render with correct `format`/`type: proxy` | unit | ConfigMap data keys parse as JSON; formats = `{npm,pypi,docker,helm}` | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | NEXUS-01 | T-23-04 | Docker body carries both `docker` and `dockerProxy` objects | unit | `jq -e '.docker and .dockerProxy'` on rendered body | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 1 | NEXUS-01 | T-23-01 | Provisioning script is idempotent | integration | `docker run sonatype/nexus3:<tag>`, run `provision.sh` twice, both exit 0 | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 1 | NEXUS-01 | T-23-05 (D-09 EULA) | EULA accepted (when `eula.accepted: true`) and a real component downloads | integration | after provisioning: `curl -f .../repository/npm-proxy/lodash/-/lodash-4.17.21.tgz` → 200, >100KB | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 1 | NEXUS-01 | — | Chart installs on a real cluster, Job succeeds | smoke | `kind create cluster && helm install … --wait`, `kubectl wait --for=condition=complete job/…` | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | — | — | Chart lints clean | unit | `helm lint kubernetes/nexus` | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | — | T-23-02 | No default admin credential in public chart | unit | `helm template` with no `auth.adminPassword` override fails (required value) | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | — | T-23-03 | `config.enabled: false` — Groovy scripting API not re-enabled | unit | `yq '.nexus3.config.enabled' kubernetes/nexus/values.yaml` → `false` | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | — | — | Anonymous access disabled by default | unit | `yq '.nexus3.config.anonymous.enabled' kubernetes/nexus/values.yaml` → `false` (NEXUS-02 deliberately deferred to Phase 24) | ❌ W0 | ⬜ pending |
| 23-01-TBD | 01 | 0 | — | — | Pre-commit passes on the new tree | regression | `pre-commit run --all-files` after yamllint exclusion added | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Task IDs are placeholders (`23-01-TBD`) — the planner assigns real task IDs when PLAN.md is written; this table's rows must be reconciled against actual task IDs at that point.*

---

## Wave 0 Requirements

- [ ] `repos/security-platform/scripts/check-nexus-chart.sh` — offline gate (lint, template, render assertions); covers NEXUS-01/NEXUS-03
- [ ] `repos/security-platform/scripts/nexus-live-smoke.sh` — docker-based two-pass idempotency + post-EULA artifact download; covers NEXUS-01
- [ ] `.pre-commit-config.yaml` — add `exclude: ^kubernetes/.*/templates/` to the `yamllint` hook (blocks all other work if missing — measured failure: `yamllint -d relaxed` exits 1 on Helm Go templates)
- [ ] `.gitignore` — add `kubernetes/*/charts/*.tgz`
- [ ] Checkov delta measurement against pinned `ghcr.io/bridgecrewio/checkov:3.3.17` container (verification task, not blocking — local runner would not load Helm v4.3.0 templates; confidence MEDIUM)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ArgoCD hook-annotation mapping and subchart dependency rebuild behavior | — (Phase 25 concern) | Requires a live ArgoCD instance; [ASSUMED] not [VERIFIED] in research | Deferred to Phase 25 live validation; annotations are set now as cheap insurance per research Pitfall 3 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers offline gate + live smoke script creation before any Wave 1 task depends on them
- [ ] The two integration tests (idempotency + post-EULA download) are present — research flags these as the only checks that would have caught the EULA 403 (a green `helm install` alone would not)
