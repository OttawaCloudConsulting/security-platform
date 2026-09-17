---
phase: 23
slug: nexus-generic-chart
status: reconciled
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-17
updated: 2026-09-17
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> **Reconciled by the planner 2026-09-17.** Three corrections were applied to the draft:
> the admin-credential key path, the D-05 helm-proxy assertion, and the `render()` helper
> convention. Placeholder task IDs were replaced with real ones. See §Planner Reconciliation.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None exists for Helm charts yet. Repo convention is standing shell gates under `scripts/` (`check-workflow-uploads.sh`, `check-detector-parity.sh`, `smoke-scans.sh`) run with `bash script.sh`. |
| **Config file** | none — plan 23-01 creates `repos/security-platform/scripts/check-nexus-chart.sh` |
| **Quick run command** | `bash scripts/check-nexus-chart.sh` (offline: lint + template + assertions) |
| **Full suite command** | `bash scripts/check-nexus-chart.sh && bash scripts/nexus-live-smoke.sh` (docker + kind live smoke) |
| **Estimated runtime** | ~5s offline / ~3min docker live / ~8min with kind |

---

## Planner Reconciliation (2026-09-17)

Four items the pattern map flagged, resolved here so no downstream agent has to guess.

### 1. Admin credential: `nexus3.rootPassword.secret`, not `auth.adminPassword`

The draft's row 11 named `auth.adminPassword` (a literal password value). That design is
rejected: a literal credential key on a **public** chart is the exact finding `gitleaks`
exists to catch, and the upstream subchart already wires a Secret *name* to both the
StatefulSet (`NEXUS_SECURITY_INITIAL_PASSWORD`) and a Job (`NEXUS_PASSWORD`).

**Resolved design (used by every task and every assertion in this phase):**

- `nexus3.rootPassword.secret` — name of a consumer-created Kubernetes Secret. **No default.**
- `nexus3.rootPassword.key` — key inside that Secret. Wrapper defaults to `password`.
- `kubernetes/nexus/templates/job-provision.yaml` wraps the secret name in Helm's `required`,
  so a bare `helm template` / `helm lint` **fails** with a message containing the literal
  string `nexus3.rootPassword.secret`.
- There is **no** `auth.adminPassword` key anywhere in this chart.

### 2. The `render()` helper convention

Because the `required` guard above makes a bare render fail, **every positive assertion must
go through one wrapper**, and exactly one negative assertion deliberately omits it:

```bash
# in scripts/check-nexus-chart.sh
render() {   # every POSITIVE assertion goes through this
  helm template t kubernetes/nexus \
    --set nexus3.rootPassword.secret=dummy-secret-name "$@"
}
```

`dummy-secret-name` is a Kubernetes **object name**, not a credential — nothing gitleaks can
flag. `helm lint` evaluates `required` too, so the `CHART-LINT` check must pass the same
`--set`. The `NO-DEFAULT-PASSWORD` row is the **one** call that omits it, asserting a
non-zero exit and a message naming `nexus3.rootPassword.secret`.

### 3. D-05: the helm proxy has no default remote

`values.yaml` ships `repos.helm.remoteUrl` unset. `configmap-repos.yaml` emits the
`003-helm.json` body **only** when the consumer sets it. Therefore:

- default render ⇒ exactly **3** repo bodies, formats `{npm, pypi, docker}`
- render with `--set repos.helm.remoteUrl=https://charts.jetstack.io` ⇒ **4** bodies

This softens NEXUS-01's "Helm proxy repo configured" to "Helm proxy repo configured **when a
remote is supplied**". That is a locked user decision (D-05 REVISED) taken *because* research
verified Helm Hub is defunct and Artifact Hub is not a chart repository. Documented in
`kubernetes/nexus/README.md` and ADR-020.

### 4. Wave numbering

The draft's "Wave 0" maps onto **GSD wave 1** (plan 23-01) and **GSD wave 2** (plan 23-02).
All four draft Wave-0 items are created before any task depends on them.

### 5. Threat IDs (defined once, referenced by every plan)

| ID | STRIDE | Component |
|----|--------|-----------|
| T-23-01 | Denial of Service / Tampering | provisioning Job + `provision.sh` |
| T-23-02 | Spoofing / Information disclosure | admin credential in a public chart |
| T-23-03 | Elevation of privilege | Groovy scripting API (`nexus.scripts.allowCreation`) |
| T-23-04 | Tampering | consumer-supplied `remoteUrl` → repo JSON body |
| T-23-05 | Repudiation | Community Edition EULA acceptance |
| T-23-06 | Information disclosure | `NEXUS_PASSWORD` in Job / script logs |
| T-23-SC | Tampering | supply chain: community subchart + helper container images |

---

## Sampling Rate

- **After every task commit:** `bash scripts/check-nexus-chart.sh`
- **After every plan wave:** offline gate + docker two-pass idempotency test
- **Before `/gsd:verify-work`:** offline gate **non-vacuous** (`PASS - N checks, 0 failures`, never `SKIP`) + docker live smoke + kind install smoke all green
- **Max feedback latency:** ~3 minutes (docker live smoke)

---

## Per-Task Verification Map

| # | Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 1 | 23-01-T2 | 01 | 1 | — | — | Offline gate exists and is non-vacuous once the chart is complete | unit | `bash scripts/check-nexus-chart.sh` exits 0 | ⬜ pending |
| 2 | 23-01-T2 | 01 | 1 | — | — | `CHART-LINT`: chart lints clean (through `render()`'s `--set`) | unit | `helm lint kubernetes/nexus --set nexus3.rootPassword.secret=dummy-secret-name` | ⬜ pending |
| 3 | 23-02-T1 | 02 | 2 | NEXUS-01 | T-23-01 | Live smoke script exists; SKIPs (never passes) when `provision.sh` is absent | unit | `bash scripts/nexus-live-smoke.sh` exits 0 with a `SKIPPED` line | ⬜ pending |
| 4 | 23-03-T2 | 03 | 3 | NEXUS-03 | — | `STORAGECLASS-OMITTED`: no `storageClassName` key emitted | unit | `render() \| yq 'select(.kind=="StatefulSet")\|.spec.volumeClaimTemplates[0].spec\|has("storageClassName")'` → `false` | ⬜ pending |
| 5 | 23-03-T2 | 03 | 3 | NEXUS-03 | — | `STORAGECLASS-OVERRIDE`: consumer value emitted verbatim | unit | same with `--set nexus3.persistence.storageClass=test` → `"test"` | ⬜ pending |
| 6 | 23-03-T2 | 03 | 3 | NEXUS-03 | — | `PERSISTENCE-ENABLED`: `persistence.enabled` defaults `true` (D-10) | unit | `yq '.nexus3.persistence.enabled' kubernetes/nexus/values.yaml` → `true` | ⬜ pending |
| 7 | 23-03-T2 | 03 | 3 | NEXUS-03 | — | `PASSTHROUGH-SIZE`: full upstream surface overridable (D-07) | unit | `render() --set nexus3.persistence.size=20Gi \| yq '…storage'` → `20Gi` | ⬜ pending |
| 8 | 23-03-T2 | 03 | 3 | — | — | `IMAGE-TAG-FLOATING`: Nexus image tag not pinned (D-08) | unit | `yq '.nexus3.image.tag' kubernetes/nexus/values.yaml` → `null` | ⬜ pending |
| 9 | 23-03-T2 | 03 | 3 | — | T-23-03 | `CONFIG-DISABLED`: Groovy scripting API not re-enabled | unit | `yq '.nexus3.config.enabled' kubernetes/nexus/values.yaml` → `false` | ⬜ pending |
| 10 | 23-03-T2 | 03 | 3 | — | — | `ANONYMOUS-DISABLED`: anonymous stays off (NEXUS-02 is Phase 24) | unit | `yq '.nexus3.config.anonymous.enabled' kubernetes/nexus/values.yaml` → `false` | ⬜ pending |
| 11 | 23-03-T2 | 03 | 3 | — | T-23-05 | `EULA-OPT-IN`: EULA not auto-accepted (D-09) | unit | `yq '.eula.accepted' kubernetes/nexus/values.yaml` → `false` | ⬜ pending |
| 12 | 23-03-T2 | 03 | 3 | — | T-23-SC | `HELPER-DIGESTS`: helper images digest-pinned | unit | `yq '.nexus3.bashImage.digest'` and `yq '.provision.image.digest'` both start `sha256:` | ⬜ pending |
| 13 | 23-04-T2 | 04 | 4 | NEXUS-01 | T-23-04 | `REPO-BODIES`: default render emits exactly 3 bodies, formats `{npm,pypi,docker}`, each valid JSON | unit | `render() \| yq 'select(.kind=="ConfigMap" and (.metadata.name\|test("-repos$")))\|.data\|keys'` → `000-npm.json,001-pypi.json,002-docker.json` | ⬜ pending |
| 14 | 23-04-T2 | 04 | 4 | NEXUS-01 | T-23-04 | `HELM-REPO-OPT-IN`: 4th body appears only with a consumer remote (D-05) | unit | same with `--set repos.helm.remoteUrl=https://charts.jetstack.io` → adds `003-helm.json` | ⬜ pending |
| 15 | 23-04-T2 | 04 | 4 | NEXUS-01 | T-23-04 | `DOCKER-BODY`: docker body carries both `docker` and `dockerProxy` | unit | `jq -e '.docker and .dockerProxy'` on the rendered `002-docker.json` | ⬜ pending |
| 16 | 23-04-T3 | 04 | 4 | NEXUS-01 | T-23-01 | `JOB-HOOK`: exactly one Job, carrying `helm.sh/hook` and `argocd.argoproj.io/hook` | unit | `render() \| yq 'select(.kind=="Job")\|.metadata.annotations'` contains both | ⬜ pending |
| 17 | 23-04-T3 | 04 | 4 | — | T-23-02 | `NO-DEFAULT-PASSWORD`: bare render fails naming the missing value | unit (**negative**) | `helm template t kubernetes/nexus` exits non-zero, stderr contains `nexus3.rootPassword.secret` | ⬜ pending |
| 18 | 23-04-T3 | 04 | 4 | — | T-23-05 | `EULA-ENV`: Job env `EULA_ACCEPTED` wired from `.Values.eula.accepted` | unit | `render() --set eula.accepted=true \| yq '…env[]\|select(.name=="EULA_ACCEPTED").value'` → `"true"` | ⬜ pending |
| 19 | 23-06-T2 | 06 | 6 | NEXUS-01 | T-23-01 | `provision.sh` is idempotent | integration | `bash scripts/nexus-live-smoke.sh` — two passes, both exit 0 | ⬜ pending |
| 20 | 23-06-T2 | 06 | 6 | NEXUS-01 | T-23-05 | Post-EULA a real component downloads | integration | `curl -f .../repository/npm-proxy/lodash/-/lodash-4.17.21.tgz` → 200, >100 KB | ⬜ pending |
| 21 | 23-06-T2 | 06 | 6 | NEXUS-01 | — | Chart installs on a real cluster, Job reaches `complete` | smoke | `kind create cluster && helm install … --wait --timeout 15m`, `kubectl wait --for=condition=complete job/…` | ⬜ pending |
| 22 | 23-06-T1 | 06 | 6 | — | — | Pre-commit passes on the whole tree | regression | `pre-commit run --all-files` | ⬜ pending |
| 23 | 23-06-T3 | 06 | 6 | — | T-23-SC | Checkov `CKV_K8S_*` delta measured in the CI-equivalent state and resolved to zero new hard failures | integration | pinned `ghcr.io/bridgecrewio/checkov:3.3.17` over a fresh clone, `--framework helm --soft-fail` before/after | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements (→ GSD waves 1–2)

- [ ] `repos/security-platform/.pre-commit-config.yaml` — `exclude: ^kubernetes/.*/templates/` on the `yamllint` hook (**blocks all other work**; measured failure: `yamllint -d relaxed` exits 1 on a Helm Go template) — plan 23-01 T1
- [ ] `repos/security-platform/.gitignore` — `kubernetes/*/charts/*.tgz` — plan 23-01 T1
- [ ] `repos/security-platform/scripts/check-nexus-chart.sh` — offline gate (lint, template, render assertions); covers NEXUS-01/NEXUS-03 — plan 23-01 T2
- [ ] `repos/security-platform/scripts/nexus-live-smoke.sh` — docker two-pass idempotency + post-EULA artifact download + kind install smoke; covers NEXUS-01 — plan 23-02
- [ ] Checkov delta measurement against pinned `ghcr.io/bridgecrewio/checkov:3.3.17` — plan 23-06 T3 (must run before the merge gate in 23-08, because `soft_fail: false` in CI)

### Intermediate-commit convention (planner decision)

`check-nexus-chart.sh` uses the **vacuous-pass** convention (the 17-01 lesson,
`check-workflow-uploads.sh` lines 30-33), not expected-red. Guard order is fixed:

1. `kubernetes/nexus` absent ⇒ print `SKIP: chart not present yet`, **exit 0**
2. `kubernetes/nexus/templates/job-provision.yaml` absent ⇒ print `SKIP: chart incomplete`, **exit 0**
3. `helm` / `yq` / `jq` missing ⇒ **exit 2**
4. `kubernetes/nexus/charts/*.tgz` missing ⇒ **exit 2** (`helm dependency build` has not run)
5. run all assertions, accumulate every failure, `exit 1` if any

The anti-vacuity guard is plan 23-06 T1: the gate must print the literal
`PASS - N checks, 0 failures` line. A `SKIP` at that point is a **failure** of 23-06.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ArgoCD hook-annotation mapping and subchart dependency rebuild behavior | — (Phase 25 concern) | Requires a live ArgoCD instance; [ASSUMED] (A6/A8), not [VERIFIED] | Deferred to Phase 25 live validation; annotations are set now as cheap insurance per research Pitfall 3 |
| `docker pull` through the Docker proxy (`docker.pathEnabled: true`) | NEXUS-04/05 | Needs ingress + TLS | Deferred to Phase 25 (research A5) |
| Merge of the `security-platform` PR to `main` | — | Irreversible; project rule requires explicit operator approval | Plan 23-08 blocking checkpoint; operator replies literally, then `gh pr merge --merge`, then verify from `origin/main` via `git show` (never the local tree) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or a stated wave-1/2 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Waves 1–2 create both gate scripts before any task depends on them
- [ ] The two integration tests (idempotency + post-EULA download) are present — research flags these as the only checks that would have caught the EULA 403 (a green `helm install` alone would not)
- [ ] The offline gate is proven **non-vacuous** before `/gsd:verify-work`
