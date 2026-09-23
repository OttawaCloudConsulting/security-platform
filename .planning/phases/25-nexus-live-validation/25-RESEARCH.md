# Phase 25: Nexus Live Validation - Research

**Researched:** 2026-09-21
**Domain:** Argo CD GitOps delivery of a git-sourced Helm chart to a live homelab cluster, plus protocol-level live validation of four Nexus proxy repositories
**Confidence:** HIGH for the cluster/overlay facts (measured live this session); MEDIUM for the recommended overlay file shape (generic-but-correct, must be conformance-checked at execution time)

> **⚠ HANDLING NOTE — read before committing.** This documentation repo's `git remote origin` is
> `https://github.com/OttawaCloudConsulting/security-platform.git`, which is **PUBLIC**, and `.planning/`
> **is tracked**. The current branch has no upstream and has never been pushed, and `commit_docs: true`
> commits only — it does not push. **Never `git push` from this repo** until the remote is corrected.
> This file deliberately omits homelab IP addresses, VIP pool assignments, DNS hostnames and NAS
> endpoints observed during research; it names the private overlay repository and its directory
> conventions only because the planner cannot act without them.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Cluster and overlay access**
- **D-01:** Claude gets direct kubeconfig access this session (via `KUBECONFIG` env var, defaulting to `~/.kube/config`) to run kubectl/helm against the homelab cluster live. Not user-relayed commands.
- **D-02:** Claude also gets git access to the private ArgoCD overlay repo (path/URL + credentials to be provided at execution time, not during this discussion) — clones it, writes the Application manifest + values, commits and pushes.
- **D-03:** ArgoCD and the private overlay repo pattern already exist on the homelab (other apps are already deployed this way). This phase is additive — add a new Application entry + values for Nexus, following the existing repo's established conventions. **Do not bootstrap ArgoCD or invent a new repo structure.**

**Validation depth**
- **D-04:** Match the rigor of Phase 24's live gates (24-02, 24-05) — a real package pull through each of the 4 proxies (npm/PyPI/Docker/Helm), verified served/cached from Nexus rather than straight from upstream. Same depth, now against the homelab cluster instead of kind.
- **D-05:** Validate **both** anonymous pull (the NEXUS-02 live proof deferred from Phase 24) and authenticated-write-refusal (negative test — write/admin still requires auth), same shape as Phase 24's local write-refusal check.

### Claude's Discretion
- Exact Application manifest field values (sync policy, namespace naming, etc.) — follow whatever pattern the existing private overlay repo already uses for other apps; do not introduce a new convention.
- Order of proxy validation (npm/PyPI/Docker/Helm) — Claude's call.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. (Phase 26-29 DefectDojo work is separately scoped and not part of this phase.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NEXUS-05 | Nexus chart validated live via private ArgoCD overlay deploy to the operator's homelab cluster | Overlay repo identity, ApplicationSet baseline, AppProject allowlist gaps, override-file rules, chart value surface, hook semantics under Argo CD, and the full live-check list are all documented below. The chart itself is unchanged apart from two optional annotation corrections named in Pitfall 2. |

Carried-forward proof obligations this phase also closes (from ADR-021 `## What was NOT verified`):

| ADR-021 item | What it says is unproven | How this phase closes it |
|---|---|---|
| 6 | The overlay **must** set `anonymous.enabled: true`; if omitted, NEXUS-02 ships closed and nine anonymous verdicts go red | Named as a mandatory overlay value below |
| 7 | No `helm upgrade` of an existing install was exercised; the guarded realms append was proven across two provisioning passes on a fresh instance, never across an upgrade of an instance whose PVC already carried Phase 23 state | Argo CD re-runs Sync hooks on **every** sync (verified, below) — so the second sync is exactly that test, and it is a named live check |
| ADR-020 item 3 | "ArgoCD's treatment of this chart's hook annotations remains training knowledge, not an observation" | Now partially resolved from official docs (Pitfall 1) and made an observable live check (`ARGOCD-HOOK-PHASE`) |
| 4 | Nothing measured against TLS; no ingress exists yet | **Not closed by this phase** — see Open Question 1; there is no ingress controller on this cluster at all |
| 1 | No pull performed by the operator's own Docker daemon | **Not closed by this phase** — see Open Question 6 |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

| Directive | Source | Consequence for this phase |
|---|---|---|
| This repo is **reference documentation only**; the canonical workflows and `kubernetes/<service>/` Helm charts live in `OttawaCloudConsulting/security-platform` | `CLAUDE.md` | Chart edits and any new validation script land in `security-platform`, **not** here. This repo gets ADR-022, `REQUIREMENTS.md` traceability, and blueprint/README prose only. |
| `docs/adr/` is **append-only** — never modify an accepted record | `CLAUDE.md` | ADR-020 and ADR-021 must not be edited. A new ADR-022 supersedes or extends them in prose, as ADR-021 did to ADR-020. |
| Preserve ASCII architecture diagrams and the 4-phase layered structure | `CLAUDE.md` | Any blueprint edit touching the K8s Infrastructure layer keeps the existing diagram shape. |
| `bash scripts/check-adoption-guide.sh` is a standing documentation gate | `CLAUDE.md` | Run it if `docs/adoption-guide.md` is touched. |
| **Never set the executable bit on scripts**; invoke as `bash scripts/x.sh` | `.claude/rules/defensive-protocol-v2-anti-slop.md` | The new homelab validation script must be non-executable and invoked with an explicit interpreter, like every other script in `security-platform/scripts/`. |
| Failure response: **STOP → REPORT → WAIT**; no silent retry | same | A red live check is reported, not retried. |
| Irreversible actions require an explicit pause and confirmation | `.claude/rules/defensive-protocol-v2-session-management.md` | Editing a shared `AppProject`, and merging to the overlay repo's protected `main`, both qualify. |
| Evidence standards: state what was actually tested | same | Every live check must derive its verdict from a measured value, not an exit code alone (the Phase 24 discipline). |

---

## Summary

This phase is the first time the Phase 23/24 Nexus chart meets a real, long-lived cluster and a real
GitOps controller. Almost everything that can go wrong is **outside** the chart: the private overlay
repo has a strongly-opinionated, schema-validated override format; the target cluster's `AppProject`
resources are **deny-by-default allowlists** that currently permit none of the resource kinds this
chart renders; and Argo CD's hook semantics differ from Helm's in one way that silently changes which
annotations on the provisioning Job are live.

Three facts change the plan's shape and were measured live this session. **First**, the ApplicationSet
`appset-apps` discovers applications by the *presence* of `application-sets/<project>/<app>/argocd-overrides.yaml`
in `OttawaCloudConsulting/occ-k8s-app-config` — you do not write an `Application` manifest, you write a
strategic-merge patch onto a generated one, and the generator derives the Application name, the
destination namespace and the `AppProject` from the directory path. **Second**, that repo's `main` branch
is protected with a required `conformance` status check, so D-02's "commits and pushes" is in practice
"opens a PR and merges it once `conformance` is green" — direct push is blocked. **Third**, there is
**no IngressClass and no Gateway API on this cluster**; every externally-reachable service is a Cilium
LoadBalancer VIP. An `Ingress` authored here would be created and never routed.

Against that, the good news is concrete: the `argocd-repo-server` can already reach
`https://stevehipwell.github.io/helm-charts/` and resolve `nexus3` 5.26.0 (measured), so the gitignored
subchart tarball resolves at render time; the cluster's default StorageClass is `default`
(`csi.trident.qnap.io`, `WaitForFirstConsumer`), which is the live proof NEXUS-03 has been waiting for;
`argocd-repo-server` runs Helm **4.2.1** and the workstation runs Helm **4.3.0**, so there is no Helm
3-vs-4 render boundary to worry about; and no `nexus` Application or `nexus` namespace exists yet, so
the name is free.

**Primary recommendation:** author one new application directory
`application-sets/<project>/nexus/` in `occ-k8s-app-config` whose `argocd-overrides.yaml` sets a
**two-source** Application — source 1 the public `security-platform` repo at path `kubernetes/nexus`
with an inline `helm.valuesObject`, source 2 the overlay directory itself carrying only a SealedSecret
for the admin credential — amend the target `AppProject` to admit the repo, the namespace and the six
resource kinds the chart renders, then validate over `kubectl port-forward` with a new
`security-platform/scripts/nexus-homelab-validate.sh` that is a `NEXUS_HOST`-parameterised extraction of
sections 4–6 and 6b of the existing `nexus-live-smoke.sh`. Do **not** add ingress or TLS in this phase
(Open Question 1).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Chart source of truth (templates, provisioning script, values contract) | Public package repo (`security-platform`) | — | PROJECT.md "generic-first, not private-then-strip": the generic chart is the source of truth and nothing environment-specific enters it |
| Environment values (EULA opt-in, anonymous opt-in, helm remote, secret name, sizes) | Private overlay repo (`occ-k8s-app-config`) | — | Same decision: hostnames, StorageClass overrides and per-environment toggles live only in the overlay |
| Admin credential material | Private overlay repo as a `SealedSecret` → sealed-secrets controller → `Secret` | Cluster (out-of-band `kubectl apply`) | Chart `required`s a Secret **name** and never ships a credential (ADR-020); the overlay repo already carries `scripts/seal-secret.sh` for this |
| Application identity, project, destination namespace, sync policy baseline | ApplicationSet `appset-apps` (cluster, git-managed from the overlay repo's `bootstrap/`) | `argocd-overrides.yaml` patch | Generator owns them; the override file supplies only the delta (F-9) |
| Authorisation boundary for what the Application may create | `AppProject` (cluster, git-managed from `application-sets/automation/argocd/templates/projects.yaml`) | — | Deny-by-default allowlists on source repo, destination namespace and resource kind |
| Repository provisioning (4 proxies, EULA, anonymous, DockerToken realm) | In-cluster provisioning Job (a chart resource, run by Argo as a **Sync** hook) | Nexus REST API | Chart-owned application state; idempotent by design, and Argo re-runs it on every sync |
| Live protocol validation (npm/PyPI/Helm/Docker pulls, write refusal) | Workstation script over `kubectl port-forward` | — | Same instrument Phase 24 used; keeps plaintext traffic on loopback, and there is no ingress controller to terminate TLS |
| Documentation of the outcome (ADR-022, requirement closure) | This documentation repo | — | CLAUDE.md: this repo documents, it does not ship |

---

## Environment Availability

All rows measured live this session against the homelab cluster (context `admin@occ-new`) unless noted.

| Dependency | Required By | Available | Version / value | Fallback |
|------------|------------|-----------|-----------------|----------|
| `kubectl` (workstation) | every live check | ✓ | client v1.34+ needed; **local client is v1.37.0 against server v1.34.1 — exceeds the ±1 minor skew and kubectl warns** | Use a matching client, or accept the warning for the read/port-forward operations used here |
| Kubernetes cluster | deploy target | ✓ | v1.34.1, 1 control plane + 3 workers, containerd 2.1.4 | — |
| Argo CD | GitOps delivery | ✓ | server image `quay.io/argoproj/argocd:v3.5.1`; `argocd` CLI v3.5.3 on workstation | — |
| `argocd-repo-server` Helm | renders the chart | ✓ | **v4.2.1** (Argo CD 3.5 bundles Helm 4.2.0+) | — |
| Workstation Helm | offline gate, local render parity | ✓ | **v4.3.0** — same major as repo-server | — |
| Egress repo-server → `https://stevehipwell.github.io/helm-charts/` | lazy `helm dependency build` for the gitignored subchart | ✓ | `helm show chart nexus3 --version 5.26.0` inside `deploy/argocd-repo-server` returned the chart metadata (appVersion 3.96.0) | none needed |
| Default StorageClass | NEXUS-03 live proof | ✓ | `default` — provisioner `csi.trident.qnap.io`, `WaitForFirstConsumer`, `Delete`, expansion allowed | — |
| sealed-secrets controller | admin credential delivery | ✓ | Application `sealed-secrets`, Synced/Healthy | Out-of-band `kubectl apply` of a plain Secret (not GitOps; use only if sealing is blocked) |
| cert-manager + ClusterIssuers | TLS, if ingress were in scope | ✓ | two DNS-01 ClusterIssuers, both `Ready` | — (not used this phase) |
| **IngressClass / ingress controller** | HTTP(S) exposure by hostname | **✗** | `kubectl get ingressclass` → **No resources found**; no Gateway API CRDs either | Cilium LoadBalancer VIP (`lbipam.cilium.io/ips`, requires an operator-assigned free IP) **or** `kubectl port-forward` |
| `gh` CLI authenticated to the org | overlay-repo PR path | ✓ | logged in as `OttawaCloudConsulting`, scopes `repo, workflow, read:org, gist` | — |
| Write path to `occ-k8s-app-config@main` | D-02 | ✓ (via PR) | ruleset: `pull_request` required (0 approvals), required status check context **`conformance`**, plus deletion / non-fast-forward protection | none — direct push to `main` is blocked |
| `docker` (workstation) | optional real-client Docker pull | ✓ | present | curl five-leg OCI handshake (what Phase 24 used) |
| `crane` (workstation) | optional second OCI client | **✗** | not on PATH | curl five-leg handshake |
| `jq`, `yq`, `curl`, `npm`, `pip3`, `git`, `kind` | validation script | ✓ | all present | — |

**Missing dependencies with no fallback:** none block this phase.

**Missing dependencies with fallback:**
- **No ingress controller** → validate over `kubectl port-forward` (recommended) or a LoadBalancer VIP (needs an operator-supplied free IP — see Open Question 1).
- **No `crane`** → the curl five-leg handshake is the assertion of record, exactly as in Phase 24.

---

## Standard Stack

Nothing is installed by this phase. The "stack" is the set of already-deployed platform components the
work must fit into.

### Core

| Component | Version | Purpose | Why standard |
|---|---|---|---|
| Argo CD | v3.5.1 (server), CLI v3.5.3 | Reconciles the Application | Already the cluster's sole delivery mechanism (D-03) `[VERIFIED: kubectl, live cluster]` |
| ApplicationSet `appset-apps` | git-files generator over `application-sets/*/*/argocd-overrides.yaml` in `occ-k8s-app-config@main` | Generates the `Application` from directory presence | The established convention for every non-cluster app on this cluster `[VERIFIED: kubectl -n argocd get applicationset appset-apps -o yaml]` |
| `nexus` wrapper chart | chart 0.1.0, appVersion 3.96.0 | The subject under validation | Phase 23 deliverable, `security-platform/kubernetes/nexus` `[VERIFIED: repo checkout]` |
| `nexus3` subchart | 5.26.0 from `https://stevehipwell.github.io/helm-charts/` | Nexus StatefulSet/Service/ConfigMaps | Pinned in `Chart.lock`; tarball gitignored and resolved at render time `[VERIFIED: Chart.lock + live repo-server fetch]` |
| sealed-secrets (`bitnami.com/SealedSecret`) | Application `sealed-secrets`, Healthy | Delivers the admin credential through git | The overlay repo's own convention — `scripts/seal-secret.sh`, `scripts/seal-secret-file.sh`, and SealedSecret templates in several apps `[VERIFIED: overlay repo contents via gh api]` |
| Helm | 4.2.1 (repo-server) / 4.3.0 (workstation) | Render | Bundled; not a choice `[VERIFIED: kubectl exec + helm version]` |

### Supporting

| Component | Version | Purpose | When to use |
|---|---|---|---|
| `docs/argocd/conformance/c1.py` | in `occ-k8s-app-config` | Validates the override file's schema and the F-1 naming rules | Run locally before every commit; it is also a pre-commit hook and part of the required `conformance` check |
| `docs/argocd/conformance/check_appconfig.py` | same | "project routing and successor rule (14g)" | Same — this is what decides whether the chosen `application-sets/<project>/` directory is legal |
| `docs/argocd/conformance/check.py` | same | C-2 render check (manual, from a pushed branch) | Recommended preview before merge, per guide §5.3–5.4 |
| `scripts/discover_apps.py` | same | Builds the CI render matrix | Your new directory will be rendered by CI; it must `helm template` cleanly on its own |
| `scripts/seal-secret.sh` / `seal-secret-file.sh` | same | Produce the SealedSecret | The sanctioned way to get a credential into the overlay repo |
| `security-platform/scripts/nexus-live-smoke.sh` | 1069 lines, 25 checks | Source of the assertion bodies to extract | Sections 4, 5, 6 and 6b are the homelab-portable parts |
| `security-platform/workstation/nexus-setup.sh --verify` | 1637 lines, 12 checks | Client-side routing proof | Optional second instrument once a `NEXUS_HOST` exists |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|---|---|---|
| Multi-source Application (chart from public repo + overlay dir) | Publish `kubernetes/nexus` to an OCI registry / GitHub Pages Helm repo, then declare it as an umbrella-chart `dependency:` — the shape `application-sets/automation/argocd` and `platform/reloader` use | Cleaner Helm semantics and it matches the *majority* overlay pattern, but it is a **packaging project** (release workflow, versioning, registry auth) that is not in NEXUS-05's scope. Multi-source is already established here by `identity/authentik` (its D15), so it is not a new convention. |
| `helm.valuesObject` inline in the override file | A `values.yaml` in the overlay dir referenced via a `$values` ref source | `$values` adds a third source and a ref indirection for four scalar values. `authentik` uses inline `valuesObject` for a far larger value tree `[VERIFIED: live Application spec]`; follow it. |
| `kubectl port-forward` for validation | LoadBalancer VIP + hostname + cert-manager TLS | The VIP pool is operator-owned and the repo's own precedent is "do not pick a replacement value without asking again". Port-forward keeps plaintext on loopback, which is what every Phase 23/24 measurement already assumed. |
| New `AppProject` for this workload | Amend an existing project (`platform` is closest) | New project = a clean, narrowly-scoped allowlist that Phases 26–29 (DefectDojo) can reuse; amending `platform` widens an existing project for all seven of its members. See Open Question 2. |
| A new homelab-specific validation script | Generalise `nexus-live-smoke.sh` in place with a `NEXUS_HOST` override | In-place generalisation risks the Phase 23/24 gate's 25 green checks. A sibling script that extracts the same assertion bodies keeps the existing gate untouched. Flagged for the planner either way. |

**Installation:** none. No package is added to any ecosystem by this phase.

---

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** No npm, PyPI, crates or Helm-repository
dependency is added by any deliverable. The only third-party artefacts involved are already pinned and
already shipped:

| Artefact | Pin | Where pinned | Status |
|---|---|---|---|
| `nexus3` chart 5.26.0 | `Chart.lock` digest `sha256:24ad740d…` | `security-platform/kubernetes/nexus/Chart.lock` | Unchanged by this phase `[VERIFIED: file]` |
| `docker.io/alpine/k8s:1.31.2` | `sha256:d489e3c7…` | chart `values.yaml` (`provision.image.digest`) | Unchanged `[VERIFIED: file]` |
| `cgr.dev/chainguard/bash` | `sha256:d57efd5f…` | chart `values.yaml` (`nexus3.bashImage.digest`) | Unchanged `[VERIFIED: file]` |

`slopcheck` was **not run**, because there is nothing to check. That is a factual skip, not a degraded
result; if the planner adds any package to any deliverable, the gate applies and this section must be
regenerated.

---

## Architecture Patterns

### System architecture diagram

```
 ┌───────────────────────── AUTHORING (workstation, this session) ────────────────────────┐
 │                                                                                         │
 │  public repo:  security-platform            private overlay: occ-k8s-app-config         │
 │  kubernetes/nexus/  (UNCHANGED*)            application-sets/<project>/nexus/           │
 │    Chart.yaml / Chart.lock                    argocd-overrides.yaml   <- THE APPLICATION│
 │    values.yaml  (ships fail-closed)           Chart.yaml (umbrella, NO dependencies)    │
 │    templates/ job-provision.yaml              templates/sealedsecret-nexus-admin.yaml   │
 │    files/provision.sh                                                                   │
 │  scripts/nexus-homelab-validate.sh  (NEW)   application-sets/automation/argocd/          │
 │                                               templates/projects.yaml  <- AppProject amend│
 └───────────────┬─────────────────────────────────────────┬───────────────────────────────┘
                 │ PR → required `conformance` check → main │
                 ▼                                          ▼
 ┌───────────────────────────────── CLUSTER (homelab) ────────────────────────────────────┐
 │                                                                                         │
 │  ApplicationSet appset-apps                                                             │
 │    git files generator: application-sets/*/*/argocd-overrides.yaml                      │
 │      ├─ name      := <dir basename>          → "nexus"                                  │
 │      ├─ namespace := <dir basename>          → "nexus"  (CreateNamespace=true)          │
 │      ├─ project   := path segment 1          → "<project>"                              │
 │      └─ templatePatch merges argocdOverrides.{labels,annotations,finalizers,spec}       │
 │                          │                                                              │
 │                          ▼                                                              │
 │                 Application "nexus"  ──── validated against AppProject <project> ────┐  │
 │                   sources[0]: security-platform @ <sha>, path kubernetes/nexus       │  │
 │                              helm.valuesObject {eula, anonymous, repos.helm, secret}  │  │
 │                   sources[1]: occ-k8s-app-config @ main, path <overlay dir>          │  │
 │                          │                                                            │  │
 │        argocd-repo-server│  helm template → "missing dependency" → helm dependency    │  │
 │                          │  build → fetch nexus3 5.26.0 from stevehipwell.github.io   │  │
 │                          ▼                                          (VERIFIED reachable)│
 │     ┌────────── SYNC (wave order; hooks re-run EVERY sync) ─────────┐                 │  │
 │     │ wave -1  SealedSecret ──sealed-secrets ctlr──▶ Secret nexus-admin               │  │
 │     │ wave  0  ServiceAccount, 5× ConfigMap, Service, Service-hl, StatefulSet         │  │
 │     │ wave  0  [Sync HOOK] Job nexus-provision  ◀── argocd.argoproj.io/hook: Sync     │  │
 │     └────────────────────────────┬────────────────────────────────┘                 │  │
 │                                  │ PVC from volumeClaimTemplates → default SC        │  │
 │                                  ▼                                                    │  │
 │            Nexus 3.96.0 (StatefulSet nexus-nexus3, Service :8081)                     │  │
 │              provision.sh: wait writable → EULA → anonymous PUT → realms GET/append   │  │
 │                            → 4× repo upsert (npm, pypi, docker, helm)                 │  │
 └──────────────────────────────────┬────────────────────────────────────────────────────┘  │
                                    │ kubectl port-forward svc/nexus-nexus3 8081:8081        │
                                    ▼                                                        │
 ┌───────────────── VALIDATION (workstation, loopback plaintext) ────────────────────────┐  │
 │  npm   GET /repository/npm-proxy/lodash/-/lodash-4.17.21.tgz   → 200, >100 000 B      │  │
 │  PyPI  GET /repository/pypi-proxy/simple/requests/             → 200, >20 000 B       │  │
 │  Helm  GET /repository/helm-proxy/index.yaml                   → 200, >100 000 B      │  │
 │  Docker GET /v2/ → 401+Bearer → token (no cred) → manifest 200 → blob >1 000 000 B    │  │
 │         GET /v2/repository/docker-proxy/... → 404   (the analogy trap)                │  │
 │  NEG   unauthenticated POST /service/rest/v1/repositories/npm/proxy → 403, created 0  │  │
 └────────────────────────────────────────────────────────────────────────────────────────┘
   * chart changes are OPTIONAL and limited to the two annotation corrections in Pitfall 2
```

### Recommended file layout

```
occ-k8s-app-config/                                   # PRIVATE overlay
├── application-sets/
│   ├── <project>/nexus/
│   │   ├── argocd-overrides.yaml                     # REQUIRED — discovery + Application spec patch
│   │   ├── Chart.yaml                                # umbrella, deliberately NO dependencies
│   │   ├── values.yaml                               # optional; only if templates/ needs values
│   │   └── templates/
│   │       └── sealedsecret-nexus-admin.yaml         # admin credential, wave -1
│   └── automation/argocd/templates/projects.yaml     # AppProject amend or new project
│
security-platform/                                    # PUBLIC package repo
├── kubernetes/nexus/templates/job-provision.yaml     # OPTIONAL: annotation corrections (Pitfall 2)
├── kubernetes/nexus/README.md                        # update "Validation so far…" limitation
└── scripts/nexus-homelab-validate.sh                 # NEW — NEXUS_HOST-parameterised live gate
│
security_solution/                                    # THIS repo — documentation only
├── docs/adr/adr022-*.md                              # new record (append-only rule)
└── .planning/REQUIREMENTS.md                         # NEXUS-05 → Complete
```

### Pattern 1: The override file *is* the Application — write the delta, not a manifest

```yaml
# application-sets/security/nexus/argocd-overrides.yaml   (project `security` — see OQ2)
# LIVE — THIS FILE IS THE APPLICATION. appset-apps discovers by FILE PRESENCE and merges this
# through its templatePatch. DELETING THIS FILE DELETES THE APPLICATION.
#
# spec.project is deliberately NOT set (F-10) — Argo CD restores it after the patch, so an
# override would be silently reverted. The project comes from the directory path.
argocdOverrides:
  spec:
    # REQUIRED for multi-source (F-11): the generator always sets spec.source, and source and
    # sources collide if both are present. `null` deletes the key; `sources: []` cannot express
    # this because empty collections are elided (F-9).
    source: null
    sources:
      # SOURCE 1 — the public generic chart. Pin targetRevision to an immutable ref (ADR-004
      # habit; the overlay repo's R23 makes implicit pins a finding).
      - repoURL: https://github.com/OttawaCloudConsulting/security-platform
        targetRevision: <commit-sha-or-tag>
        path: kubernetes/nexus
        helm:
          # Stated explicitly even though the default is the Application name. The rendered
          # Service is <releaseName>-nexus3, which every runbook and port-forward below assumes.
          releaseName: nexus
          valuesObject:
            nexus3:
              rootPassword:
                secret: nexus-admin      # must match the SealedSecret's metadata.name
                key: password
            eula:
              accepted: true             # else every component download is 403 at ~192 bytes
            anonymous:
              enabled: true              # ADR-021 item 6 — chart ships false
            repos:
              helm:
                remoteUrl: https://charts.jetstack.io   # no default; unset ⇒ no helm-proxy ⇒ 404
      # SOURCE 2 — local manifests (the SealedSecret). Same-namespace, same Application, so the
      # sync-wave below actually orders it relative to the chart's resources.
      - repoURL: https://github.com/OttawaCloudConsulting/occ-k8s-app-config
        targetRevision: main
        path: application-sets/security/nexus
    syncPolicy:
      # R5 recipe: `$patch: replace` renders `automated` with exactly the keys stated.
      automated:
        $patch: replace
        enabled: true
        selfHeal: true
        prune: true
      # F-12: syncOptions REPLACES rather than appends, so the generator baseline is restated
      # in full or it is lost.
      syncOptions:
        - CreateNamespace=true
        - ApplyOutOfSyncOnly=true
      # Cold Nexus boot is 1–3 minutes on homelab hardware and the Job's own readiness poll is
      # bounded at 600s; a retry budget keeps a slow first boot from ending as a hard failure.
      retry:
        limit: 5
        backoff:
          duration: 30s
          factor: 2
          maxDuration: 10m
```

`[VERIFIED: live ApplicationSet spec + application-sets/identity/authentik/argocd-overrides.yaml]`
for every structural rule; `[ASSUMED]` for the specific field *values* chosen above.

### Pattern 2: Put the credential a wave earlier than the thing that reads it

Argo CD's own sync-waves documentation states the failure directly: a hook that reads a password from a
Secret in the same Application "gets the old value or fails outright if the Secret is not there yet …
either keep the credentials for your hooks outside the Application, or make the Secret a hook as well
and give it a lower sync-wave so it lands first" `[CITED: argo-cd/docs/user-guide/sync-waves.md]`.

```yaml
# application-sets/<project>/nexus/templates/sealedsecret-nexus-admin.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: nexus-admin
  namespace: nexus          # strict scope binds name AND namespace — seal for this exact pair
  annotations:
    # Lands before the wave-0 StatefulSet and the wave-0 provisioning hook Job.
    argocd.argoproj.io/sync-wave: "-1"
spec:
  encryptedData:
    password: <sealed>
  template:
    metadata:
      name: nexus-admin
      namespace: nexus
    type: Opaque
```

Two residual races, both benign and both worth stating in the plan rather than discovering:

1. The sealed-secrets controller decrypts **asynchronously**, and Argo CD has **no health
   assessment for `bitnami.com/SealedSecret` on this cluster** — measured: every SealedSecret in
   the live `authentik` Application reports `"health": null`, and `argocd-cm` carries no
   `resource.customizations` entry for the kind `[VERIFIED: kubectl, 2026-09-21]`. A wave therefore
   **cannot** wait for decryption: a resource with no health is not something Argo blocks on. If
   the provisioning pod starts first it sits in `CreateContainerConfigError`; kubelet retries the
   same pod indefinitely, so this does **not** consume `backoffLimit: 0` and the Job recovers when
   the Secret appears. `[ASSUMED — the kubelet retry behaviour is well established but was not
   measured this session]` The wave `-1` annotation is still worth setting: it orders the *apply*,
   which shortens the window even though it cannot close it.
2. `provision.activeDeadlineSeconds: 900` is the hard ceiling on that recovery window.

### Pattern 3: Extract, don't generalise, the live assertions

`security-platform/scripts/nexus-live-smoke.sh` derives `NEXUS_HOST` from a `docker run` container it
owns, then runs (section numbering from the script):

| Section | Checks | Portable to homelab? |
|---|---|---|
| 1–3 | render, boot a throwaway container, extract repo bodies, `PROVISION-PASS-1/2` | No — replaced by the Argo sync itself |
| 4 | `ANONYMOUS-PULL-ALLOWED-{TRANSPORT,HTTP-200,SIZE}` (npm) | **Yes**, verbatim with a different `NEXUS_HOST` |
| 5 | `ANONYMOUS-PULL-{PYPI,HELM}-{TRANSPORT,HTTP-200,SIZE}` | **Yes** |
| 6 | `DOCKER-REALM-ACTIVE`, `DOCKER-PATH-SHAPE`, `ANONYMOUS-PULL-DOCKER` (5 legs) | **Yes** |
| 6b | `ANONYMOUS-WRITE-DENIED` (403 **and** non-creation, with an instrument check) | **Yes** — needs admin creds for the readback |
| 7 | kind cluster, `KIND-INSTALL`, `KIND-JOB-COMPLETE` | No — replaced by Argo + homelab assertions |

The new script should keep the file's existing discipline verbatim: `pass`/`fail` helpers that never
swallow a result, a `CHECKS_PASSED` counter so a run where nothing executed cannot print `ALL PASS`,
`SKIPPED` accounted separately from passes, and three distinguishable verdicts per fetch (transport,
status, size) so none can mask another.

**Admin credential handling for section 6b:** read it from the cluster, never from argv —
`kubectl -n nexus get secret nexus-admin -o jsonpath='{.data.password}' | base64 -d` into a shell
variable, passed to curl via `--config -` or `-u` from an env var, and never echoed. Phase 23's kind
half already applies the Secret from stdin for exactly this reason.

### Anti-patterns to avoid

- **Writing a standalone `Application` manifest into the overlay repo.** It would be an orphan: nothing
  applies it, `appset-apps` would *also* generate one from the directory, and C-1 would reject the file.
- **A second `argocd-overrides.yaml` anywhere below the app directory.** The generator's include glob is
  `application-sets/*/*/argocd-overrides.yaml` and legacy globbing lets `*` span `/`, so a nested file
  generates a stray Application named for the nested directory (R32).
- **Committing `charts/`.** Both repos gitignore vendored subchart tarballs, and the overlay repo has a
  `no-vendored-charts` pre-commit hook.
- **Setting `spec.project`, `destination.server` or `destination.name` in the override.** Schema-rejected
  (F-10, G-6).
- **Adding `argocd.argoproj.io/sync-wave` as an *Application*-scoped annotation.** It is a no-op between
  Applications (G-15); waves only order resources *within* one Application.
- **Assuming an `Ingress` will work.** There is no IngressClass on this cluster; the object would be
  created, reported Healthy-ish, and route nothing.
- **Deriving any verdict from a `docker pull` exit code.** ADR-021 decision 7: a mirror falls back to
  Docker Hub silently; only the Nexus components-endpoint delta is evidence.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| Getting an Application onto the cluster | A hand-written `Application` YAML applied with kubectl | `argocd-overrides.yaml` in the right directory | The generator owns name/namespace/project/baseline; a hand-written manifest is unmanaged and would collide |
| Validating the override file | Eyeballing it against the guide | `python3 docs/argocd/conformance/c1.py` + `check_appconfig.py` | Same scripts as the pre-commit hook and the required `conformance` check — a local PASS is the real thing |
| Previewing what Argo will generate | Mentally applying the templatePatch | `argocd appset generate` / the repo's C-2 render check (`docs/argocd/conformance/check.py`) | The templatePatch is a strategic merge with documented traps ($patch, list-replace, key elision) |
| Getting a credential into git | Base64 in a values file, or a plain Secret committed | `scripts/seal-secret.sh` → SealedSecret | The repo's own convention; gitleaks runs in the required check and will catch the alternative |
| Provisioning the four proxy repos | A bespoke `kubectl exec` + curl runbook | The chart's own hook Job (`files/provision.sh`) | It is idempotent by construction (GET→PUT/POST upsert, guarded realms append) and Argo re-runs it every sync |
| Waiting for Nexus to be writable | `sleep` | `provision.readiness.attempts` / `intervalSeconds` (wired through in Phase 24, ADR-021 decision 9) | Already a value surface; `sleep` hides a cold-boot failure as a timeout |
| Proving anonymous Docker pull | A single `curl` of the manifest URL | The five-leg handshake from `nexus-live-smoke.sh` | A header-less GET returns 200 even with the `DockerToken` realm removed — ADR-021 decision 5 records that 200 as evidence that must never be accepted |
| Proving write refusal | Any unauthenticated POST | A **structurally valid** npm-proxy body, asserting exactly 403 **and** a 404 readback, with an instrument check that the same URL shape returns 200 for an existing repo | A 400 means the body was rejected before authorisation was consulted and proves nothing (24-RESEARCH Pitfall 5) |

**Key insight:** every hand-rolled shortcut available in this phase has already been measured to produce
a *green* result for the wrong reason. The existing gates are not ceremony; they are the accumulated
list of false passes Phases 23 and 24 walked into.

---

## Common Pitfalls

### Pitfall 1: Under Argo CD, the chart's Helm hook annotations are DEAD

**What goes wrong:** a reader looks at `job-provision.yaml`, sees
`helm.sh/hook: post-install,post-upgrade` and `helm.sh/hook-delete-policy: before-hook-creation`, and
reasons about the Job as a PostSync hook with an explicit delete policy. Under Argo CD none of that is
in effect.

**Why it happens:** Argo CD's Helm documentation is unambiguous — *"If you define any Argo CD hooks,
**all** Helm hooks will be ignored."* `[CITED: argo-cd/docs/user-guide/helm.md]` The template sets
`argocd.argoproj.io/hook: Sync`, so:

| Annotation on the Job | Under `helm install` | Under Argo CD |
|---|---|---|
| `helm.sh/hook: post-install,post-upgrade` | post-install/post-upgrade | **ignored** (would have mapped to `PostSync`) |
| `helm.sh/hook-weight: "0"` | hook weight 0 | **ignored** (would have mapped to sync-wave 0) |
| `helm.sh/hook-delete-policy: before-hook-creation` | delete before re-create | **ignored** |
| `argocd.argoproj.io/hook: Sync` | (inert) | **live — Sync phase** |
| `argocd.argoproj.io/sync-options: Replace=true` | (inert) | **live** |

**Net effect, and why it is still correct:** the Job runs in the **Sync** phase (not PostSync), at the
default wave 0, alongside the StatefulSet — which is fine, because `provision.sh` owns a readiness poll
of up to 600 s. With no `argocd.argoproj.io/hook-delete-policy` set, Argo falls back to its documented
default of `BeforeHookCreation` `[CITED: argo-cd/docs/user-guide/sync-waves.md]`, which is the same
behaviour the Helm annotation intended: the previous Job is deleted before the new one is created, so
the `spec.template is immutable` failure the template's header comment predicts cannot occur, and the
Job survives its own success so its logs can be read.

**How to avoid:** do not "fix" the Job by removing the Argo annotations to let the Helm ones apply —
that would move it to PostSync and reintroduce the immutable-name problem the header comment describes.
Make the behaviour **observable** instead (see `ARGOCD-HOOK-PHASE` below).

**Warning signs:** an `Application` that reports Synced while `kubectl -n nexus get job` is empty; a Job
whose phase does not appear under `.status.operationState.syncResult.resources[] | select(.hookType)`.

### Pitfall 2: `ttlSecondsAfterFinished` on a hook Job is an Argo CD anti-pattern

**What goes wrong:** the Job is reaped by Kubernetes while Argo CD still needs to read it, and the sync
hangs waiting for a hook that no longer exists.

**Why it happens:** Argo CD's docs carry an explicit warning — *"Stick to the hook-delete-policy
annotation for cleaning up hooks and avoid `ttlSecondsAfterFinished` on hook Jobs. Argo CD needs to read
the Job to find out how the phase went, and if Kubernetes deletes it first, the sync can end up waiting
for a hook that is not there any more."* `[CITED: argo-cd/docs/user-guide/sync-waves.md]` The chart sets
`ttlSecondsAfterFinished: 900`.

**Assessment:** 900 s is generous relative to a normal sync (the TTL clock starts at Job completion, and
Argo reads the phase immediately after), so this is unlikely to bite on a healthy first sync. It is a
real risk when an operation stalls, and it caps the log-inspection window at 15 minutes after
completion — which matters for this phase's evidence capture.

**How to avoid:**
- Capture `kubectl -n nexus logs job/nexus-provision` **within the window**, immediately after the sync,
  and save it as phase evidence.
- Consider two small, additive chart changes in `security-platform` (planner's call — they are chart
  edits, so they belong in a `security-platform` PR, not the overlay):
  `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation` stated explicitly, and a note (or a value)
  covering the TTL/Argo interaction. **Do not** silently drop `ttlSecondsAfterFinished` — the template's
  own comment records that 900 is a *floor* protecting the `--timeout=300s` waits in plans 23-02 and
  23-06.

### Pitfall 3: The `AppProject` allowlists will reject this Application on first sync

**What goes wrong:** the Application is generated, then every resource fails with a
"…is not permitted in project…" style error, or the sync is blocked outright on the source repo.

**Why it happens:** the projects on this cluster are deny-by-default allowlists on three axes. Measured
live:

| Project | `sourceRepos` | `destinations` (namespaces) | `namespaceResourceWhitelist` — does it cover the chart? |
|---|---|---|---|
| `apps` | overlay repo only | edgebridge, smarthome-pihole, xmr-rig, kcl-pilot | ✗ no StatefulSet, no Job, no ServiceAccount |
| `platform` | overlay repo + two CNPG chart registries | 7 namespaces, none `nexus` | ✗ no StatefulSet, no Job |
| `automation` | overlay repo + argo-helm | argocd, argo, argo-events | ✓ kinds fit, ✗ repo and namespace do not |
| `identity` | overlay repo + goauthentik | authentik, entra-federation | ✗ no StatefulSet |
| `default` | `*` | `*` | ✓ but it is the unrestricted project — not the convention |

`[VERIFIED: kubectl -n argocd get appproject <name> -o json, 2026-09-21]`

The chart renders exactly these kinds (measured by `helm template nexus kubernetes/nexus --namespace
nexus` with the four required values set):

| apiVersion | kind | name |
|---|---|---|
| v1 | ServiceAccount | `nexus-nexus3` |
| v1 | ConfigMap ×5 | `nexus-nexus3-logback`, `-props`, `-scripts`, `nexus-provision-script`, `nexus-repos` |
| v1 | Service ×2 | `nexus-nexus3-hl`, `nexus-nexus3` |
| apps/v1 | StatefulSet | `nexus-nexus3` |
| batch/v1 | Job | `nexus-provision` (hook) |

plus `bitnami.com/SealedSecret` from the overlay directory. Note two kinds that are **not** needed in the
allowlist: the `PersistentVolumeClaim` is created by the StatefulSet controller from
`volumeClaimTemplates` (Argo never applies it), and the plaintext `Secret` is created by the
sealed-secrets controller (Argo applies only the SealedSecret) — which is exactly why the `apps` project
lists `SealedSecret` and not `Secret`.

**How to avoid:** the AppProject amendment is a **first-class task in the plan**, authored in
`application-sets/automation/argocd/templates/projects.yaml` in the overlay repo, and it must supply:
- `sourceRepos`: add `https://github.com/OttawaCloudConsulting/security-platform`
- `destinations`: add `{ namespace: nexus, server: https://kubernetes.default.svc, name: in-cluster }`
- `clusterResourceWhitelist`: `{ group: '', kind: Namespace }` — **name-scoped to `nexus`**, following
  the `identity` project's precedent. The repo's own comment records this as measured, not assumed:
  *"Argo CD DOES validate a multi-source Application's `CreateNamespace=true` Namespace against this
  list, proven live."*
- `namespaceResourceWhitelist`: `''/ServiceAccount`, `''/ConfigMap`, `''/Service`, `apps/StatefulSet`,
  `batch/Job`, `bitnami.com/SealedSecret`

**Note on the subchart repository:** it does **not** need a `sourceRepos` entry. Argo CD's security
documentation states the allow-list restricts only the repository that is cloned, not Helm chart
dependencies it then follows `[CITED: argo-cd/docs/operator-manual/security.md]`. That is a convenience
here and a standing caution generally.

**Sequencing — a transient red that must be predicted, not discovered.** `projects.yaml` is synced by
the `argocd` Application while the new app directory is discovered by `appset-apps`; the two reconcile
independently. If both land in one commit, `appset-apps` can generate `Application nexus` **before** the
`AppProject` exists, producing `InvalidSpecError: Application referencing project … which does not
exist`. It self-clears on the next reconcile, but under this project's anti-slop rule a red is a stop.
Plan **two PRs**: (1) the `AppProject` amendment, confirmed with
`kubectl -n argocd get appproject <name> -o json | jq .spec` showing the new repo, namespace and kinds;
then (2) the app directory. If the planner prefers one PR, the transient must be named in the plan in
advance so the executor does not report it as a defect.

**Warning signs:** `Application` condition `InvalidSpecError`; per-resource sync errors naming the
project; a `Namespace` that is never created despite `CreateNamespace=true`.

### Pitfall 4: The overlay repo's own override-file rules, each of which fails silently or loudly

Carry these verbatim into the plan's verification steps. All are from the repo's
`docs/reference/argocd-overrides-guide.md` and the live `identity/authentik` override.

| Rule | What it says | Failure mode if ignored |
|---|---|---|
| F-11 / R8 | `source: null` is **required** alongside `sources:` | `source` and `sources` collide; Argo rejects the spec |
| F-9 | `null` deletes a subtree; empty collections are elided; `$patch` permitted **only** under `syncPolicy.automated` | `sources: []` silently expresses nothing |
| F-10 | `spec.project` is schema-refused | Argo restores it after the patch; an override is silently reverted |
| G-6 | `destination.server` / `destination.name` are generator-owned and refused | Schema failure at C-1 |
| F-12 | `syncOptions` **replaces**, it does not append | Dropping `CreateNamespace=true` means the namespace is never created |
| R5 | `$patch: replace` renders `automated` with exactly the keys stated | A deep merge cannot *remove* a key; `null` would strip auto-sync entirely |
| F-6 | Four reserved label keys must not be set | A colliding key silently wins over the generator's |
| F-7 | Annotation values must be **strings** | Unquoted booleans/numerics fail the schema |
| R32 | Exactly one override file, at the app-directory root | A nested one generates a stray Application |
| F-1a/F-1b | Directory name is a DNS-1123 label, ≤46 chars under `application-sets/`, unique across both roots | Two Applications with one name |
| R9 | `retry` lives on `spec.syncPolicy`, not `spec` | `spec.retry` validates against the schema and is then **silently dropped** by Argo's typed unmarshal |

`nexus` is 5 characters and no `nexus` Application exists `[VERIFIED: kubectl, 2026-09-21]`.

### Pitfall 5: The guide in the overlay repo describes a *different* generator than the one that will pick this up

**What goes wrong:** the plan follows the guide's "What you inherit if you override nothing" baseline
and gets the repo, the branch and the directory depth wrong.

**Why it happens:** `docs/reference/argocd-overrides-guide.md` documents the **`appset-cluster`**
generator (repo `occ-k8s-cluster-config`, `targetRevision: migration`, single-level path
`application-sets/<app>`, `project: default`). The generator that will discover a new app directory in
`occ-k8s-app-config` is **`appset-apps`**, whose live spec differs:

| Property | Guide (`appset-cluster`) | Live `appset-apps` `[VERIFIED: kubectl]` |
|---|---|---|
| repoURL | `occ-k8s-cluster-config` | `occ-k8s-app-config` |
| revision | `migration` | `main` |
| discovery glob | `application-sets/<app>/argocd-overrides.yaml` | `application-sets/*/*/argocd-overrides.yaml`, excluding `development*` and `default*` |
| Application name | `{{.path.basename}}` | `{{.path.basename}}` |
| project | `default` | `{{ index .path.segments 1 }}` — **derived from the directory** |
| syncPolicy baseline | `automated {enabled, selfHeal, prune}` | `automated {prune, selfHeal}`, `syncOptions [CreateNamespace=true, ApplyOutOfSyncOnly=true]` |
| generator syncPolicy | — | `applicationsSync: sync`, `preserveResourcesOnDeletion: true` |

**How to avoid:** treat the **live ApplicationSet spec as authoritative** and the guide as vocabulary
(the merge semantics, the R-recipes and the F-rules are all correct and transferable). The
`authentik` override file's header is the better worked example, because it is under the same generator.

### Pitfall 6: `main` is protected — "commit and push" is "open a PR and merge it"

**What goes wrong:** the executor attempts a direct push under D-02 and is rejected, mid-phase, with
credentials already in hand.

**Why it happens:** measured on the repo's rulesets endpoint (`gh api repos/.../rules/branches/main`) —
an active `default` branch ruleset with `deletion`, `non_fast_forward`, `pull_request`
(`required_approving_review_count: 0`, all merge methods allowed) and `required_status_checks` with one
context: **`conformance`**. `[VERIFIED: GitHub rulesets API, 2026-09-21]` This is the same lesson Phase
14 recorded: read the **rulesets** endpoint, never `branches/main/protection`, whose 404 is a false
negative.

**How to avoid:** plan a branch → PR → wait for `conformance` → merge sequence. Zero approvals are
required, so the executor can merge its own PR. Note
`require_extra_approval_for_unattributed_changes: true` — commits whose author is not linked to the
pushing account may need an extra approval; author commits as the authenticated identity.

**What `conformance` runs** (`.github/workflows/conformance.yaml`, on PRs into `main`): `c1.py`;
`check_appconfig.py` ("project routing and successor rule (14g)" — **this is what decides whether a new
`application-sets/<project>/` directory is legal**, and it must be read before choosing the project);
`yamllint` on changed YAML; a **Helm render matrix** built by `scripts/discover_apps.py` (so the new
directory must `helm template` cleanly on its own, with no dependencies); a Kustomize render matrix; and
`gitleaks detect --no-git --redact`.

### Pitfall 7: The chart fails closed on four separate values, and each has a different symptom

`[VERIFIED: chart values.yaml + ADR-020/ADR-021 measurements]`

| Value | Chart default | If the overlay omits it | Symptom |
|---|---|---|---|
| `nexus3.rootPassword.secret` | `null` — `required` | **Render fails** | Argo reports a manifest-generation error naming the value |
| `eula.accepted` | `false` | Repos configure; metadata 200; **every component download 403 at ~192 bytes** | npm/Helm size checks fail at ~192 bytes; PyPI simple page still returns its full body, so a PyPI 200 is **not** evidence of an accepted licence |
| `anonymous.enabled` | `false` | Unauthenticated reads return **401** | Nine anonymous verdicts plus the full Docker handshake go red — ADR-021's named Phase 25 hand-off (item 6) |
| `repos.helm.remoteUrl` | `null` | The **helm-proxy repository is never created** | `ANONYMOUS-PULL-HELM` returns 404, not 401/403 |

### Pitfall 8: Docker's URL shape — the `/repository/` segment means opposite things in two places

Carried forward verbatim from ADR-021 decisions 5 and 7, and still exactly as load-bearing here.

| Context | Correct shape | Wrong-by-analogy shape | Measured |
|---|---|---|---|
| Image reference / OCI API | `HOST/docker-proxy/library/alpine:3.21` → `/v2/docker-proxy/library/alpine/manifests/3.21` | `/v2/repository/docker-proxy/...` | **200** vs **404** |
| Docker daemon `registry-mirrors` | `HOST/repository/docker-proxy` | `HOST/docker-proxy` (path-only) | components 0→1 vs **0→0 while the pull still succeeds** |

A third shape, `/repository/docker-proxy/v2/library/alpine/manifests/3.21`, returns 200 but **no Docker
client can be made to emit it** — it must never be documented as a pull target. Keep
`DOCKER-PATH-SHAPE`'s both-directions assertion (200 on the right shape, 404 on the wrong one) in the
homelab script: it is what catches a documentation copy-paste.

### Pitfall 9: The realms list is replace-not-append and the API stores duplicates

`PUT /service/rest/v1/security/realms/active` **replaces the entire list** — a body omitting
`NexusAuthenticatingRealm` locks out every user including admin — and the API **stores duplicates**, so
a blind `. + ["DockerToken"]` in a Job that re-runs grows the list without bound. `provision.sh` guards
both with `jq 'if index("DockerToken") then . else . + ["DockerToken"] end'` and a `jq -c`-normalised
`cmp -s` no-change skip (the raw GET body is 30 bytes with no trailing newline; `jq -c` emits 28 plus
one, so an un-normalised comparison differs every run and the skip becomes dead code).

**Why this matters more here than in Phase 24:** Argo CD **re-runs Sync hooks on every sync** —
*"Hooks also run on every sync, not only when something they care about has changed. A self-heal, a
manual sync from the UI, or a change to a completely unrelated part of the Application will all run them
again"* `[CITED: argo-cd/docs/user-guide/sync-waves.md]` — and `ApplyOutOfSyncOnly=true` does **not**
suppress them: *"when `ApplyOutOfSyncOnly` is enabled, Sync Hooks will still run"*
`[CITED: argo-cd/docs/user-guide/sync-options.md]`. With `selfHeal: true` in the baseline, this Job will
run many times over the life of the Application. `DOCKER-REALM-ACTIVE` asserting `DockerToken` **exactly
once** with `NexusAuthenticatingRealm` **still present** is therefore a standing production invariant
here, not a one-off test.

### Pitfall 10: Anonymous read is all-repository, and it is now on a real network

ADR-021's accepted tradeoffs do not change, but their blast radius does. The built-in `nx-anonymous`
role is `readOnly: true` with `nx-repository-view-*-*-read` / `-browse` — wildcards on **both** format
and repository name — so any repository added later is world-readable from creation, and
`GET /service/rest/v1/repositories` answers 200 anonymously with every repository's name, format, type
and URL. Everything is plaintext HTTP; there is no TLS and no NetworkPolicy (both explicitly out of
scope for this milestone). Validating over `kubectl port-forward` keeps this session's traffic on
loopback; a LoadBalancer VIP would put unauthenticated plaintext read on the homelab LAN. That is a
reason to prefer port-forward for the phase gate, independent of the ingress question.

### Pitfall 11: A sync that looks green while nothing was validated

Argo CD decides a hook phase purely from the Job's exit code — *"Argo CD only looks at the hook resource
to decide whether the phase worked. A Job that exits with 0 marks the phase as successful … even if the
database ended up in a different state than your application expects."*
`[CITED: argo-cd/docs/user-guide/sync-waves.md]` Synced + Healthy is therefore **not** NEXUS-05 evidence.
The requirement is closed by the protocol-level checks, with byte counts, or it is not closed.

---

## Runtime State Inventory

This phase creates new state; it does not rename anything. The table is included because "what exists
after this that git does not describe" is the reciprocal question and the planner needs it for the
phase's rollback story.

| Category | Items | Action required |
|---|---|---|
| Stored data | Nexus database on a new PVC (EULA acceptance, 4 repository definitions, anonymous setting, active realms, and every cached component) — **none of it in git**, all of it in the PVC | None this phase. Note in ADR-022 that `helm uninstall`/Argo prune does not necessarily delete the PVC, and that re-creating the Application against a surviving PVC is the re-entrant path (and is itself ADR-021 item 7's test) |
| Live service config | The `nexus` Argo CD `Application`, generated from directory presence. **Deleting `argocd-overrides.yaml` deletes the Application**; `preserveResourcesOnDeletion: true` on the generator stops that cascading into the workloads, which are then left unmanaged | Document the deletion semantics in the plan's rollback step |
| Live service config | The amended `AppProject` — shared, cluster-scoped-in-effect configuration, git-managed but reconciled by the `argocd` Application | Treat the amendment as an irreversible-ish action per the session-management rule: state the diff, confirm, then apply |
| OS-registered state | None — no workstation daemon, task or service is registered by this phase. `workstation/nexus-setup.sh --docker-daemon` is **not** in scope here | None — verified by reading the phase CONTEXT and ADR-021 decision 7 |
| Secrets / env vars | `Secret nexus-admin` in namespace `nexus`, derived by the sealed-secrets controller from a committed SealedSecret. The sealing is namespace-and-name bound (strict scope) | Generate with `scripts/seal-secret.sh`; record in the plan that renaming the Secret or the namespace requires re-sealing |
| Build artifacts | `kubernetes/nexus/charts/nexus3-5.26.0.tgz` on the workstation (gitignored) and a `.argocd-helm-dep-up` marker plus a fetched tarball inside `argocd-repo-server`'s cache | None — the marker is removed when the repo-server processes another commit `[CITED: argo-cd reposerver/repository/repository.go]` |

---

## Code Examples

### 1. Confirm the generator baseline before writing anything (authoritative, not the guide)

```bash
kubectl -n argocd get applicationset appset-apps -o yaml
# spec.generators[0].git.files[].path  -> application-sets/*/*/argocd-overrides.yaml
# spec.template.metadata.name          -> {{.path.basename}}
# spec.template.spec.destination.namespace -> {{.path.basename}}
# spec.template.spec.project           -> {{ index .path.segments 1 }}
# spec.template.spec.syncPolicy        -> the baseline your syncOptions must restate in full (F-12)
```

### 2. Enumerate exactly what the chart will ask the AppProject to permit

```bash
# Source: security-platform/kubernetes/nexus, run 2026-09-21 with helm v4.3.0
helm template nexus kubernetes/nexus --namespace nexus \
  --set nexus3.rootPassword.secret=nexus-admin \
  --set eula.accepted=true \
  --set anonymous.enabled=true \
  --set repos.helm.remoteUrl=https://charts.jetstack.io \
  | yq -r 'select(.kind != null) | .apiVersion + "\t" + .kind + "\t" + .metadata.name'
# v1          ServiceAccount  nexus-nexus3
# v1          ConfigMap       nexus-nexus3-logback / -props / -scripts
# v1          ConfigMap       nexus-provision-script / nexus-repos
# v1          Service         nexus-nexus3-hl / nexus-nexus3
# apps/v1     StatefulSet     nexus-nexus3
# batch/v1    Job             nexus-provision      (hook)
```

### 3. Prove the repo-server can resolve the gitignored subchart *before* the first sync

```bash
# Verified 2026-09-21 — returned nexus3 chart metadata, appVersion 3.96.0
kubectl -n argocd exec deploy/argocd-repo-server -c repo-server -- \
  helm show chart nexus3 --repo https://stevehipwell.github.io/helm-charts/ --version 5.26.0
```

Argo CD runs `helm dependency build` **lazily** — only after `helm template` returns a missing-dependency
error — and then writes a `.argocd-helm-dep-up` marker to skip it on subsequent calls
`[CITED: argo-cd reposerver/repository/repository.go]`. So the fetch happens on the first render of a
given commit and is invisible afterwards.

### 4. Read the hook phase back — the `ARGOCD-HOOK-PHASE` check

This is what converts ADR-020's "ArgoCD's treatment of this chart's hook annotations remains training
knowledge" into an observation.

```bash
kubectl -n argocd get applications.argoproj.io nexus -o json \
  | jq '.status.operationState.syncResult.resources[]
        | select(.hookType != null)
        | {kind, name, hookType, hookPhase, status, message}'
# EXPECT: kind "Job", name "nexus-provision", hookType "Sync", hookPhase "Succeeded"
# A hookType of "PostSync" would falsify Pitfall 1 and must be reported, not rationalised.
# An EMPTY result means the Job was not treated as a hook at all.
```

### 5. NEXUS-03's live proof — the default StorageClass, observed

```bash
kubectl get storageclass          # default (default)  csi.trident.qnap.io  WaitForFirstConsumer
kubectl -n nexus get pvc -o json \
  | jq '.items[] | {name:.metadata.name, sc:.spec.storageClassName, phase:.status.phase,
                    size:.status.capacity.storage}'
# EXPECT: storageClassName "default", phase "Bound", size 8Gi
# WaitForFirstConsumer means the PVC is legitimately Pending until the StatefulSet pod is
# scheduled — a Pending PVC before that point is not a failure.
```

### 6. The validation host — port-forward, and the four client URLs

```bash
kubectl -n nexus port-forward svc/nexus-nexus3 8081:8081 &
NEXUS_HOST=http://127.0.0.1:8081

# npm   (EULA-gated component download)
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' \
  "$NEXUS_HOST/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz"      # expect 200, >100000

# PyPI  (NOT EULA-gated — a 200 here is not evidence of an accepted licence)
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' \
  "$NEXUS_HOST/repository/pypi-proxy/simple/requests/"                # expect 200, >20000
#                                                   ^ trailing slash is load-bearing

# Helm
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' \
  "$NEXUS_HOST/repository/helm-proxy/index.yaml"                      # expect 200, >100000

# Docker — the reference shape, and the analogy trap
curl -s -o /dev/null -w '%{http_code}\n' "$NEXUS_HOST/v2/docker-proxy/library/alpine/manifests/3.21"             # 200
curl -s -o /dev/null -w '%{http_code}\n' "$NEXUS_HOST/v2/repository/docker-proxy/library/alpine/manifests/3.21"  # 404
```

Measured reference sizes from ADR-021, for setting floors: npm tarball **318,961** B, PyPI simple page
**76,776** B, Helm `index.yaml` **291,818** B (against `https://charts.jetstack.io`), Docker
`linux/amd64` layer blob **3,626,020** B. The existing script's floors (100 000 / 20 000 / 100 000 /
1 000 000) already sit well below these and above the ~192-byte EULA refusal and the 0-byte 401
challenge; reuse them rather than inventing new ones.

### 7. The write-refusal negative test — and why the instrument check is not optional

```bash
# A STRUCTURALLY VALID body. A malformed one returns 400 — rejected before authorisation was
# ever consulted — which proves nothing about the write boundary (24-RESEARCH Pitfall 5).
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'Content-Type: application/json' \
  --data '{"name":"anon-write-probe","online":true,
           "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
           "proxy":{"remoteUrl":"https://registry.npmjs.org","contentMaxAge":1440,"metadataMaxAge":1440},
           "negativeCache":{"enabled":true,"timeToLive":1440},
           "httpClient":{"blocked":false,"autoBlock":true},
           "npm":{"removeNonCataloged":false,"removeQuarantined":false}}' \
  "$NEXUS_HOST/service/rest/v1/repositories/npm/proxy"        # expect EXACTLY 403

# Instrument check: the same admin URL shape must return 200 for a repository that DOES exist,
# or the 404 below would prove nothing.
curl -s -u "admin:$PW" -o /dev/null -w '%{http_code}\n' "$NEXUS_HOST/service/rest/v1/repositories/npm-proxy"      # 200
curl -s -u "admin:$PW" -o /dev/null -w '%{http_code}\n' "$NEXUS_HOST/service/rest/v1/repositories/anon-write-probe" # 404
```

Read `$PW` from the cluster, never from argv or history:

```bash
PW="$(kubectl -n nexus get secret nexus-admin -o jsonpath='{.data.password}' | base64 -d)"
```

### 8. The second sync — closing ADR-021 item 7

```bash
argocd app sync nexus            # or let selfHeal/a refresh do it
kubectl -n nexus wait --for=condition=complete job/nexus-provision --timeout=900s
kubectl -n nexus logs job/nexus-provision | tail -20
# EXPECT on the SECOND run: action=updated for all four repositories (action=created on the first),
#   "anonymous: OPEN (HTTP 200)" and a read-back "enabled": true,
#   "realms: DockerToken already active — no change, and no request was made"

curl -s "$NEXUS_HOST/service/rest/v1/security/realms/active"
# EXPECT EXACTLY: ["NexusAuthenticatingRealm","DockerToken"]
```

This is the first time the provisioning path meets an instance whose **PVC already carries prior state**,
which is precisely what ADR-021 item 7 says was never exercised.

---

## State of the Art

| Old approach | Current approach | When changed | Impact here |
|---|---|---|---|
| Argo CD bundled Helm 3.x | Argo CD 3.5 bundles **Helm 4.2.0+**; repo-server here reports 4.2.1 | Argo CD v3.5 | No Helm 3-vs-4 render boundary — the workstation runs 4.3.0. Plain-HTTP **OCI** dependency repos now need explicit registration with `--insecure-oci-force-http`; not applicable here (the dependency is plain HTTPS) `[CITED: argo-cd/docs/operator-manual/upgrading/3.4-3.5.md]` |
| Single-source `Application` with `helm.values` as a YAML string | `sources[]` multi-source with `helm.valuesObject` as structured YAML | Argo CD 2.6 (multi-source) / 2.10 (`valuesObject`) | Both in use on this cluster today `[VERIFIED: live authentik Application]` |
| Per-app `ApplicationSet` generators (`appset-core-apps`, `appset-identity-apps`) | One `appset-apps` file-presence generator with a `templatePatch` | Overlay repo Features 3.9/3.10/3.14 | No name-based excludes are needed for a new app; drop the directory in and it is discovered |
| Sonatype `nexus-repository-manager` chart | `stevehipwell/nexus3` 5.26.0 wrapped by a thin chart | ADR-020 (Phase 23) | Unchanged; the Sonatype chart is deprecated and archived, and `nxrm-ha` requires Pro + PostgreSQL |

**Deprecated / not applicable:**
- `helm.sh/hook*` annotations on this chart, **under Argo CD only** — superseded by the Argo annotations
  on the same resource (Pitfall 1). They remain live and correct under a direct `helm install`, which is
  what the kind smoke exercises.
- `nexus3.config.anonymous.*` — measured inert in Phase 23 and removed; the wrapper's top-level
  `anonymous.*` is the control.
- Ingress as an exposure mechanism on this cluster — no controller exists; LoadBalancer VIPs are the
  convention.

---

## Validation Architecture

### Test framework

| Property | Value |
|---|---|
| Framework | **Bash gate scripts**, the established convention in `security-platform/scripts/` — there is no pytest/jest/vitest harness in either repo for this domain |
| Config file | none — each script is self-contained, non-executable, invoked as `bash scripts/<name>.sh` |
| Quick run command | `bash scripts/check-nexus-chart.sh` (offline, 18 checks, seconds) |
| Full suite command | `bash scripts/nexus-homelab-validate.sh` (new, live, minutes) — plus `bash scripts/nexus-live-smoke.sh` if the kind/container gate is re-run |
| Overlay-repo gate | `python3 docs/argocd/conformance/c1.py` and `check_appconfig.py`, run from the overlay repo clone |

### Phase requirements → test map

| Req | Behaviour | Test type | Automated command | File exists? |
|---|---|---|---|---|
| NEXUS-05 | Override file is schema- and routing-legal | static | `python3 docs/argocd/conformance/c1.py && python3 docs/argocd/conformance/check_appconfig.py` (overlay clone) | ✅ exists in overlay repo |
| NEXUS-05 | Chart still renders after any edit | static | `bash scripts/check-nexus-chart.sh` | ✅ `security-platform/scripts/` |
| NEXUS-05 | Application reaches Synced + Healthy | live | `argocd app wait nexus --sync --health --timeout 1200` | ❌ Wave 0 (new script) |
| NEXUS-05 | Provisioning Job ran **as a Sync hook** and succeeded | live | `ARGOCD-HOOK-PHASE` — jq over `.status.operationState.syncResult.resources[]` | ❌ Wave 0 |
| NEXUS-05 | Job completed; logs show 4× `action=created` | live | `kubectl wait --for=condition=complete job/nexus-provision` + log grep | ❌ Wave 0 |
| NEXUS-03 | PVC bound on the cluster's **default** StorageClass | live | `PVC-DEFAULT-STORAGECLASS` | ❌ Wave 0 |
| NEXUS-02 | Anonymous npm / PyPI / Helm pull (transport, 200, size — three verdicts each) | live | `ANONYMOUS-PULL-{ALLOWED,PYPI,HELM}-*` | ⚠️ bodies exist in `nexus-live-smoke.sh` §4–5; need `NEXUS_HOST` parameterisation |
| NEXUS-02 | `DockerToken` realm active exactly once, `NexusAuthenticatingRealm` intact | live | `DOCKER-REALM-ACTIVE` | ⚠️ §6 |
| NEXUS-01 | Docker path shape: 200 on the right shape, 404 on the analogy shape | live | `DOCKER-PATH-SHAPE` | ⚠️ §6 |
| NEXUS-02 | Full anonymous OCI handshake, layer blob > 1 000 000 B | live | `ANONYMOUS-PULL-DOCKER` (5 legs) | ⚠️ §6 |
| NEXUS-02 | Anonymous write refused **and** created nothing | live | `ANONYMOUS-WRITE-DENIED` (+ instrument check) | ⚠️ §6b |
| ADR-021 #7 | Second sync is idempotent against existing PVC state | live | `SECOND-SYNC-IDEMPOTENT` — `action=updated`, realms list unchanged | ❌ Wave 0 |
| NEXUS-04 | Client-side routing against the homelab host | live, optional | `bash workstation/nexus-setup.sh --verify` pointed at the port-forwarded URL | ✅ exists (12 checks) |

### Sampling rate

- **Per task commit:** `bash scripts/check-nexus-chart.sh` (if the chart was touched); `python3 c1.py`
  (if the override file was touched). Both are seconds.
- **Per overlay-repo PR:** the required `conformance` check — non-negotiable, and it gates the merge.
- **Per wave merge:** `bash scripts/nexus-homelab-validate.sh` against the live deployment.
- **Phase gate:** full homelab script green, with byte counts captured as evidence, before
  `/gsd:verify-work`.

### Wave 0 gaps

- [ ] `security-platform/scripts/nexus-homelab-validate.sh` — `NEXUS_HOST`-parameterised extraction of
      `nexus-live-smoke.sh` §4, §5, §6, §6b, plus the four new cluster-side checks
      (`ARGOCD-HOOK-PHASE`, `PROVISION-JOB-COMPLETE`, `PVC-DEFAULT-STORAGECLASS`,
      `SECOND-SYNC-IDEMPOTENT`). Must preserve the `pass`/`fail`/`CHECKS_PASSED`/`SKIPPED`
      discipline and the three-verdicts-per-fetch split.
- [ ] Overlay-repo clone on the workstation (D-02 credentials) so `c1.py` / `check_appconfig.py` can be
      run **before** the PR, not after.
- [ ] A decision on the target `AppProject` (Open Question 2) before any file is written — the directory
      path encodes it and renaming later means a new Application.

---

## Security Domain

### Applicable ASVS categories

| ASVS category | Applies | Standard control |
|---|---|---|
| V2 Authentication | yes | Admin credential never ships with the chart (Helm `required` on a Secret *name*, ADR-020); delivered as a SealedSecret; **anonymous read is deliberately open** for NEXUS-02 and the write boundary is the negative test |
| V3 Session management | no | Nexus sessions are not exercised; the Docker bearer token is minted per-request with no credential, by design |
| V4 Access control | yes | Two layers: Nexus's built-in `nx-anonymous` read-only role (wildcard on format and repository — a documented, accepted limitation), and Argo CD's `AppProject` allowlists on source repo, destination namespace and resource kind |
| V5 Input validation | partial | `provision.sh` consumes consumer-supplied values; the pod runs with `automountServiceAccountToken: false`, `readOnlyRootFilesystem: true`, all capabilities dropped, `runAsNonRoot: 65534` (T-23-10) |
| V6 Cryptography | **gap, accepted** | No TLS anywhere in this path. Sealing uses the sealed-secrets controller's own key — never hand-rolled. Validating over `port-forward` keeps plaintext on loopback |
| V14 Configuration | yes | Immutable digest pins on both non-Nexus images (ADR-004); `Chart.lock` as the single Nexus version control point; `gitleaks` in the overlay repo's required check |

### Known threat patterns for this stack

| Pattern | STRIDE | Standard mitigation | Status here |
|---|---|---|---|
| Anonymous read escalating to anonymous write | Elevation of privilege | Nexus authorisation; asserted by `ANONYMOUS-WRITE-DENIED` with a **valid** body and a non-creation readback | Named live check (D-05) |
| Repository-inventory disclosure to anyone who can reach the instance | Information disclosure | Network reach is the only control; NetworkPolicy is explicitly out of milestone scope | Accepted and documented (ADR-021); port-forward limits reach this session |
| Plaintext credentials / package content on the wire | Information disclosure | TLS — **absent** | Open Question 1; loopback-only validation is the interim control |
| Dependency confusion via a future hosted repo being world-readable | Information disclosure → supply chain | ADR-010's hosted-before-proxy group ordering; a custom narrow anonymous role (described, not shipped) | Unchanged; restate in ADR-022 |
| Cache poisoning of proxied content | Tampering | Upstream HTTPS to registry.npmjs.org / pypi.org / registry-1.docker.io; `strictContentTypeValidation` | Chart-owned, unchanged |
| Committing a credential to git | Information disclosure | SealedSecret + `gitleaks detect --no-git --redact` in the required `conformance` check | Enforced by the gate |
| A `git push` from this documentation repo to its **public** origin | Information disclosure | Never push; correct the remote | See the handling note at the top |
| Widening a shared `AppProject` beyond what one app needs | Elevation of privilege | Name-scope the `Namespace` entry; enumerate resource kinds from a fresh render, never `kind: '*'` | Recommended in Pitfall 3, following the repo's own precedent |
| Chart dependencies bypassing the repo allow-list | Spoofing / supply chain | Understood and accepted: the allow-list covers only the cloned repo `[CITED: argo-cd security.md]`; the dependency is pinned by `Chart.lock` digest | Documented |

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | The private ArgoCD overlay repo D-02 refers to is `https://github.com/OttawaCloudConsulting/occ-k8s-app-config`. **Discovered from live cluster state** (the `appset-apps` generator's `repoURL`), **not supplied by the user** | throughout | If the user means a different repo, the entire overlay design is retargeted. Confirm at execution time before writing any file |
| A2 | The right project directory is a **new** `application-sets/security/` (Application `nexus`, project `security`), requiring a new `AppProject` declared in `projects.yaml` | Pitfall 3, Open Question 2 | **Legality confirmed** — `check_appconfig.py` check 14b parses the project set from `projects.yaml`, so a new project is legal once declared `[VERIFIED]`. The residual risk is *preference*: the operator may prefer amending `platform`. Confirm before writing, since the directory path fixes the project permanently |
| A3 | `repos.helm.remoteUrl: https://charts.jetstack.io` is the right Helm remote for the homelab | Pattern 1 | Wrong remote ⇒ helm-proxy proxies something the operator does not want. It is only the value the kind smoke used; any repo serving an `index.yaml` > 100 KB satisfies the gate |
| A4 | Namespace and Application name `nexus`, Secret name `nexus-admin` | throughout | `nexus` is free `[VERIFIED]`; `nexus-admin` is copied from the chart README and the kind smoke. Renaming after sealing requires re-sealing (strict scope) |
| A5 | A `SealedSecret` at sync-wave `-1` plus kubelet's mount retry is sufficient ordering for the provisioning Job's `secretKeyRef`. **Argo CD reports no health for `SealedSecret` on this cluster** `[VERIFIED]`, so the wave orders the apply but cannot wait for decryption | Pattern 2 | If the kubelet retry behaviour differs from expectation the Job could fail instead of waiting. Mitigation is already in place (`activeDeadlineSeconds: 900`); observe the first sync rather than assume |
| A6 | Pinning `targetRevision` to a commit SHA on `security-platform` is the right currency policy | Pattern 1 | A SHA pin means chart updates need an overlay commit. `main` would auto-track and contradict ADR-004's pinning habit and the overlay's R23 |
| A7 | `ttlSecondsAfterFinished: 900` will not actually truncate a healthy sync | Pitfall 2 | If it does, the sync waits on a vanished Job. Watch the first sync; capture logs immediately |
| A8 | The retry budget (5 × 30 s doubling to 10 m) is appropriate for a cold Nexus boot | Pattern 1 | Too small and a slow first boot ends as a hard failure that automated sync will not retry on the same revision |
| A9 | Argo CD's default hook-delete-policy of `BeforeHookCreation` applies here because the chart sets no `argocd.argoproj.io/hook-delete-policy` | Pitfall 1 | Documented default `[CITED]`, but the interaction with an *ignored* Helm delete-policy annotation was not observed. `ARGOCD-HOOK-PHASE` plus a second sync will show it |
| A10 | The provisioning Job's effective sync-wave is 0 (Helm's `hook-weight: "0"` being ignored) | Pitfall 1 | Same outcome either way in this chart, but it matters for ordering against the wave `-1` SealedSecret |

---

## Open Questions (RESOLVED)

> **All seven questions below were closed at planning time (2026-09-23).** Each carries an inline
> **RESOLVED** pointer naming the locked decision, plan task or checkpoint that closed it. The prose
> under each question is the research-time record of *why* it was open, preserved unedited; the
> RESOLVED line is the disposition that supersedes the research-time recommendation where they differ.

1. **Is ingress / TLS in scope for NEXUS-05?**
   - What we know: ADR-021 (`## What was NOT verified` item 4) and the chart README both say "Phase 25's
     ingress is the first TLS anywhere in this stack". But the **CONTEXT.md decisions gathered on
     2026-09-20 do not mention ingress or TLS at all**, and the requirement text for NEXUS-05 does not
     either — where DDOJO-01 explicitly says "external ingress and cert-manager-issued TLS". Measured
     this session: **there is no IngressClass and no Gateway API on this cluster**, so an `Ingress` would
     route nothing; the convention is a Cilium LoadBalancer VIP, and the overlay repo's own rule is that
     a VIP must be confirmed free by the operator, not guessed.
   - What's unclear: whether the operator intends the "first TLS" work to land here or in the DefectDojo
     phases.
   - **Recommendation: exclude it.** Validate over `kubectl port-forward`, which is the same instrument
     Phase 24 used and keeps unauthenticated plaintext on loopback. Record the exclusion explicitly in
     ADR-022 so ADR-021 item 4 is visibly still open rather than silently skipped. Surface this to the
     user at planning time — it is a scope call, not Claude's discretion.
   - **RESOLVED — locked decision L-01: ingress/TLS is OUT of scope for Phase 25.** No IngressClass, Gateway API,
     `Ingress` object or VIP is added by any plan. Validation runs over `kubectl port-forward`. Enforced by the
     grep-based acceptance criteria in plans 25-02 and 25-03, and recorded in ADR-022 by plan 25-07 so ADR-021
     item 4 stays visibly open rather than silently dropped.

2. **Which `AppProject`? — narrowed, needs a user decision only on preference.**
   `docs/argocd/conformance/check_appconfig.py` was read this session. Its check **14b** requires that
   every directory `appset-apps` selects "route to a project that (a) exists in `projects.yaml`, (b) is
   not wildcard, (c) is not `default`", where the project set is **parsed from
   `application-sets/automation/argocd/templates/projects.yaml`** — one of exactly two tracked paths it
   accepts. The set is therefore **open**: a new project is legal the moment it is declared in that
   file, and because 14b reads the *tracked tree* rather than the cluster, a single PR carrying both the
   new project and the new directory passes CI (the runtime sequencing caveat in Pitfall 3 is separate).
   `[VERIFIED: check_appconfig.py, lines ~1021–1265]`
   - **Recommendation: a new `security` AppProject**, directory `application-sets/security/nexus/`. No
     existing project's `namespaceResourceWhitelist` covers `apps/StatefulSet` **and** `batch/Job`; a
     new narrow allowlist avoids widening `platform` for its seven current members, and Phases 26–29
     (DefectDojo, another StatefulSet + Job + PVC workload) reuse it unchanged.
   - **Alternative:** amend `platform` — a smaller diff, at the cost of granting every `platform` member
     StatefulSet and Job, plus adding a third-party source repo to that project.
   - Still requires user confirmation either way: writing to a shared `AppProject` is an
     irreversible-ish action under the session-management rule, and the directory path fixes the
     project permanently (renaming later means a different Application).
   - **RESOLVED — locked decision L-02: amend the existing `platform` AppProject; do NOT create a `security`
     project.** The operator chose the amend path over this section's new-project recommendation. The app
     directory is `application-sets/platform/nexus/`. Enforced by the same grep-based acceptance criteria in
     plans 25-02 and 25-03 (`no file under application-sets/security/`).

3. **Does the plan modify the public chart at all?** Two optional, additive corrections are identified
   (Pitfall 2: an explicit `argocd.argoproj.io/hook-delete-policy`, and a documented position on
   `ttlSecondsAfterFinished` under Argo CD). Both are chart edits and therefore a separate
   `security-platform` PR with its own gates. Recommendation: hold them until the first live sync tells
   you whether they are needed, then land them with measured justification — the Phase 23/24 house style.
   - **RESOLVED — deferred to a measured verdict, not decided here.** Plan 25-05 Task 3 ("Close Open Question 3")
     decides both optional chart edits from what the two live syncs actually showed and writes the verdict to
     `evidence/25-05-chart-edit-assessment.md`; plan 25-06 Task 1 executes that verdict conditionally, additively,
     and asserts an empty diff on the no-edit branch.

4. **Where does the homelab validation script live, and does it replace or sit beside
   `nexus-live-smoke.sh`?** Recommendation: a sibling script in `security-platform/scripts/`, so the
   existing 25-check gate keeps passing untouched. The alternative — parameterising
   `nexus-live-smoke.sh` in place — is cleaner long-term but puts a green gate at risk mid-phase.
   - **RESOLVED — a sibling script, as recommended.** Fixed in plan 25-01's context block ("Two planner forks
     resolved here", fork 2): `security-platform/scripts/nexus-homelab-validate.sh` is authored alongside
     `nexus-live-smoke.sh`, whose 25 green checks stay byte-untouched (asserted in 25-01's verification block).

5. **How is the Nexus PVC sized and reclaimed?** The chart defaults to `8Gi` on the default StorageClass
   (`Delete` reclaim policy, expansion allowed). Community Edition's ceiling is 40,000 components /
   100,000 requests per day. Is 8 Gi right for the homelab, and is a `Delete` reclaim policy acceptable
   for a cache whose loss means re-accepting the EULA and re-provisioning? Worth one explicit decision
   rather than an inherited default.
   - **RESOLVED at the plan 25-02 Task 2 operator checkpoint.** PVC size and reclaim policy are one of the four
     values that blocking `checkpoint:decision` fixes (proposed: the chart default `8Gi` on the cluster default
     StorageClass, `Delete` reclaim); the operator's verbatim reply and the resolved value are recorded in
     `25-02-SUMMARY.md`, which plan 25-03 reads.

6. **Is a real `dockerd` pull in scope?** ADR-021 `## What was NOT verified` item 1 — no pull has ever
   been performed by the operator's own Docker daemon. Doing it needs a routable host plus either TLS or
   an `insecure-registries` entry, i.e. it is gated on Question 1. Recommendation: defer, and say so in
   ADR-022 rather than leaving it ambiguous.
   - **RESOLVED — deferred, and recorded rather than left ambiguous.** No real `dockerd` pull is performed this
     phase (it is gated on Question 1, which L-01 closed as out of scope). Plan 25-07 writes the exclusion into
     ADR-022's `## What was NOT verified` section, so ADR-021 item 1 stays visibly open.

7. **Retry/timeout budget.** Nexus cold boot is 1–3 minutes on homelab hardware; the Job's readiness poll
   is bounded at 600 s and `activeDeadlineSeconds` at 900 s. Argo CD's operation stays `Progressing` for
   the whole hook, and after a retry budget is exhausted automated sync **never retries the same
   revision** even once conditions improve — recovery then needs a manual `argocd app sync`
   `[CITED: overlay repo's own measured note on the authentik retry budget]`. Confirm the budget in the
   override file is the window the operator is content to wait unattended.
   - **RESOLVED at the plan 25-02 Task 2 operator checkpoint.** The `syncPolicy.retry` budget is another of the
     four values that checkpoint fixes (proposed `limit: 5`, backoff `30s` / factor `2` / `maxDuration: 10m`,
     with both in-repo precedents quoted); the confirmed budget is recorded in `25-02-SUMMARY.md` and written
     into `argocd-overrides.yaml` by plan 25-03.

---

## Sources

### Primary (HIGH confidence — measured live this session, 2026-09-21)

- Homelab cluster via `kubectl` (context `admin@occ-new`): server v1.34.1; Argo CD `v3.5.1`;
  `appset-apps` / `appset-cluster` / `appset-development-apps` ApplicationSet specs; 31 Applications;
  8 AppProjects with full `sourceRepos` / `destinations` / `clusterResourceWhitelist` /
  `namespaceResourceWhitelist`; live `authentik` multi-source Application spec; StorageClasses;
  IngressClasses (none); Gateway API CRDs (none); Cilium LB IP pools; LoadBalancer Services;
  `argocd-repo-server` Helm version `v4.2.1`; `helm show chart nexus3 --version 5.26.0` executed **inside**
  `argocd-repo-server`.
- `OttawaCloudConsulting/occ-k8s-app-config` via `gh api` (read access confirmed): repository tree;
  `docs/reference/argocd-overrides-guide.md`; `application-sets/identity/authentik/{Chart.yaml,argocd-overrides.yaml}`;
  `application-sets/platform/homepage/argocd-overrides.yaml`;
  `application-sets/automation/argocd/templates/projects.yaml`;
  `docs/argocd/conformance/check_appconfig.py` (1854 lines — checks 14a/14b project routing);
  `.pre-commit-config.yaml`;
  `.github/workflows/conformance.yaml`; `scripts/` listing; branch rulesets for `main`.
- `OttawaCloudConsulting/security-platform` working clone at `repos/security-platform`
  (`aed14b9`): `kubernetes/nexus/{Chart.yaml,Chart.lock,values.yaml,README.md,templates/job-provision.yaml}`;
  `.gitignore` (`kubernetes/*/charts/*.tgz`); `git ls-files` proving the subchart tarball is untracked;
  `scripts/nexus-live-smoke.sh` (1069 lines, all check labels and constants); `helm template` render of
  the chart with the four required values.
- This repo: `.planning/phases/25-nexus-live-validation/25-CONTEXT.md`; `.planning/REQUIREMENTS.md`;
  `.planning/PROJECT.md`; `.planning/STATE.md`;
  `docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md` (full text);
  `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md`; `CLAUDE.md`; `.claude/rules/*`.

### Secondary (HIGH–MEDIUM — official Argo CD documentation and source, via Context7)

- `argo-cd/docs/user-guide/helm.md` — Helm→Argo hook mapping table; **"If you define any Argo CD hooks,
  all Helm hooks will be ignored"**; "Argo CD cannot know if it is running an install or an upgrade".
- `argo-cd/docs/user-guide/sync-waves.md` — hook delete policies and the `BeforeHookCreation` default;
  the `ttlSecondsAfterFinished` warning; "hooks run on every sync"; hooks judged solely by exit code;
  the PreSync-hook-reads-a-Secret ordering advice.
- `argo-cd/docs/user-guide/sync-options.md` — "when `ApplyOutOfSyncOnly` is enabled, Sync Hooks will
  still run".
- `argo-cd/reposerver/repository/repository.go` — lazy `helm dependency build` triggered only by a
  missing-dependency error, with the `.argocd-helm-dep-up` marker.
- `argo-cd/docs/operator-manual/security.md` — the repository allow-list does not restrict Helm chart
  dependencies.
- `argo-cd/docs/operator-manual/upgrading/3.4-3.5.md` — Helm upgraded to 4.2.0 in Argo CD 3.5.
- `argo-cd/gitops-engine/pkg/sync/hook/helm/{hook.go,type.go}` and
  `gitops-engine/pkg/sync/sync_context.go` — hook detection and the hooks-are-always-recreated path.

### Tertiary (LOW — reasoned, not verified this session; flagged in the Assumptions Log)

- Kubelet's retry behaviour for a pod blocked on a missing `secretKeyRef` (A5).
- The specific field values proposed in Pattern 1 (A2, A3, A4, A6, A8) — structurally correct, but their
  *values* are choices that must be confirmed against the live overlay repo and the operator.

---

## Metadata

**Confidence breakdown:**

- **Cluster and overlay facts: HIGH.** Argo CD version, ApplicationSet baseline, AppProject allowlists,
  StorageClass, absence of any ingress controller, repo-server Helm version and its egress to the
  subchart repository, and the `main` branch ruleset were all read directly from the live cluster and the
  GitHub API this session, not recalled.
- **Chart value surface and fail-closed behaviour: HIGH.** Read from the committed `values.yaml`,
  `job-provision.yaml` and README, and cross-checked against ADR-020/ADR-021's measured byte counts and
  status codes.
- **Argo CD hook semantics: HIGH for the documented rules** (all four load-bearing statements are direct
  quotations from official docs or source), **MEDIUM for this chart specifically** — the
  both-annotations-present case has never been observed on this chart, which is exactly why
  `ARGOCD-HOOK-PHASE` is a named live check rather than a claim.
- **Recommended overlay file shape: MEDIUM.** The structural rules are verified from the live generator
  and a working sibling application; the field *values* are proposals and are listed in the Assumptions
  Log.
- **Scope of ingress/TLS: MEDIUM-LOW, deliberately unresolved.** The documentary record and the locked
  decisions disagree, and the cluster has no ingress controller at all. Recorded as Open Question 1 for
  the user rather than decided here.

**Research date:** 2026-09-21
**Valid until:** 2026-10-05 (14 days) — the homelab cluster and the overlay repo are both actively
changing (`appset-apps` is 9 days old; three AppProjects were created 9 days ago), so re-read the live
ApplicationSet spec and the target AppProject immediately before writing any file.
