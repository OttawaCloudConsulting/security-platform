# Phase 23: Nexus Generic Chart - Research

**Researched:** 2026-09-17
**Domain:** Helm subchart packaging + Sonatype Nexus Repository 3 REST provisioning on Kubernetes
**Confidence:** HIGH for everything measured against a live Nexus 3.96.0 CE container and a rendered chart; MEDIUM only where noted

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Chart base**
- **D-01:** Wrap Sonatype's official upstream `nexus3` Helm chart as a subchart dependency in `Chart.yaml` (not authored from scratch, not vendored/forked). Override values rather than reimplementing StatefulSet/PVC/service-account templates.

**Repo location**
- **D-02:** Chart lives in the `OttawaCloudConsulting/security-platform` repo (not this docs-only repo, not a new dedicated repo). This repo's `CLAUDE.md` scope statement will need a note that `security-platform` now also hosts K8s packages, not just the CI workflow.
- **D-03:** Layout: top-level `kubernetes/` directory with well-named subdirectories — this phase creates `kubernetes/nexus/`. Phase 26 (DefectDojo) will follow the same pattern with `kubernetes/defectdojo/`.

**Proxy repo provisioning**
- **D-04:** A Helm post-install Job calls the Nexus REST API after the pod is ready to idempotently create the 4 proxy repos (npm, PyPI, Docker, Helm). Not a Groovy/ConfigMap script (deprecated upstream scripting API), not a manual doc step (would violate NEXUS-01's "configured" requirement).
- **D-05:** The 4 proxy upstream URLs (registry.npmjs.org, pypi.org, registry-1.docker.io, Helm Hub-style index) ship as hardcoded defaults in `values.yaml` but are consumer-overridable — not fixed/unoverridable, not left blank for the consumer to fill in.

**Values schema**
- **D-06:** `persistence.storageClass` is omitted/left unset in `values.yaml` by default so Kubernetes falls back to the cluster's default StorageClass automatically (satisfies NEXUS-03). Consumer sets a value only to override. Not an explicit `""` — plain omission.
- **D-07:** The chart passes through the full values surface the upstream `nexus3` subchart exposes — storage size, resource requests/limits, image tag, etc. — all overridable, none artificially restricted to a minimal surface for this phase.
- **D-08:** Image tag is NOT pinned by this phase — it tracks whatever the upstream `nexus3` chart's default resolves to (floating, not pinned to a specific Nexus version in `Chart.yaml`). User explicitly chose this over pinning for reproducibility — flag this to the researcher/planner as a point worth surfacing again if it causes drift issues.

### Claude's Discretion

None — all four areas resolved to explicit user choices.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **NEXUS-01** | Public Helm chart deploys Nexus Repository with npm, PyPI, Docker, and Helm proxy repos configured | Exact REST bodies for all four proxy formats verified live against Nexus 3.96.0 CE (§Code Examples). Upstream chart ships a built-in `config.repos[]` REST provisioning Job (§Architecture Patterns, Pattern 2). **Blocker discovered:** the CE EULA gate returns 403 on every component download until accepted — "configured" is hollow without an EULA step the upstream chart does not provide (§Pitfall 1). |
| **NEXUS-03** | Chart uses the cluster's default StorageClass unless overridden by the consumer | **Empirically verified** by rendering: omitting `persistence.storageClass` emits no `storageClassName` key at all in the `volumeClaimTemplates`; setting it emits `storageClassName: "<value>"` (§Code Examples, D-06 verification). D-06 is satisfiable exactly as written. |

Out of this phase (confirmed against REQUIREMENTS.md): NEXUS-02 (anonymous pull), NEXUS-04 (workstation install script), NEXUS-05 (live homelab validation). Findings relevant to those phases are collected in §Hand-off to Phase 24/25 rather than acted on here.
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

Directives extracted from `./CLAUDE.md` and `.claude/rules/*.md` that bind this phase:

| Constraint | Source | Effect on this phase |
|------------|--------|----------------------|
| This repo (`security_solution`) is **reference documentation only**, not buildable software | CLAUDE.md §What This Repository Is | No chart code lands here. All deliverables go to `repos/security-platform`. |
| The canonical workflows live in `OttawaCloudConsulting/security-platform`, "this repository documents them, it does not ship them" | CLAUDE.md §What This Repository Is | D-02 **changes this scope statement**. CLAUDE.md must be updated to say `security-platform` also hosts K8s packages. This is an explicit phase deliverable, not optional cleanup. |
| ADR records in `docs/adr/` are **append-only** | CLAUDE.md §Editing Guidelines | A new ADR for the chart-base decision must be a NEW file (next free number after ADR-018). Never edit an accepted ADR. |
| Preserve ASCII architecture diagrams and the 4-phase layered structure | CLAUDE.md §Editing Guidelines | Any blueprint edit describing Nexus must slot into the existing Phase 3 (K8s Infrastructure) layer, not restructure it. |
| **Never set the executable bit on script files**; always invoke with an explicit interpreter (`bash script.sh`) | rules/defensive-protocol-v2-anti-slop.md §Script Safety | The provisioning script shipped in the chart must not be `chmod +x`'d in git. In-container it is invoked as an explicit `args: ["/scripts/configure.sh"]` against a `bash` entrypoint — consistent with this rule. |
| Silent fallbacks (`or {}`, `try/except: pass`) convert hard failures into silent corruption. Let it crash. | rules/defensive-protocol-v2-anti-slop.md §Error Handling | The provisioning script must `set -euo pipefail` and fail loudly on non-expected HTTP status codes. Do not `\|\| true` a failed repo creation. |
| Before changing anything, list what reads/writes/depends on it | rules/defensive-protocol-v2-anti-slop.md §Second-Order Effects | Driven out in §Second-Order Effects on security-platform CI — the new directory measurably breaks an existing pre-commit gate. |
| Evidence standards: state what was **actually tested**, not "all items show X" | rules/defensive-protocol-v2-anti-slop.md §Evidence Standards | Every HIGH-confidence claim below cites the exact command and observed output. Claims not measured are tagged MEDIUM/`[ASSUMED]`. |
| Irreversible actions require explicit user confirmation | rules/defensive-protocol-v2-session-management.md | Merging to `security-platform` `main` needs the same explicit approval gate used in Phases 15-05/16-07/17-05. |

---

## Summary

The phase is buildable, but **D-01 as literally written is not satisfiable** and must be resolved before planning proceeds. There is no Sonatype-published Helm chart named `nexus3`. `nexus3` is the name of Sonatype's **Docker image** (`docker.io/sonatype/nexus3`) and of a well-maintained **community** chart by `stevehipwell`. Sonatype's own chart repository (`https://sonatype.github.io/helm3-charts/`) publishes `nexus-repository-manager`, which is explicitly **DEPRECATED** (frozen at chart 64.2.0 / app 3.64.0 since Feb 2024, with a Sonatype archive notice warning of database corruption), and `nxrm-ha`, which defaults to 3 clustered replicas and requires an external PostgreSQL database plus a Pro license file. Neither official chart fits a zero-cost single-developer homelab. The community `stevehipwell/nexus3` chart (5.26.0 / app 3.96.0, MIT, ArtifactHub verified publisher, 178 stars, pushed 9 days ago) does — and it already implements D-04's exact pattern as a first-class feature.

The most consequential discovery is not about charts at all. Since **Nexus 3.77.0, the free edition is "Community Edition" and ships an unaccepted EULA that blocks component downloads with HTTP 403 until an administrator accepts it.** This was verified end-to-end on a fresh 3.96.0 container: proxy repo creation returns 201, anonymous config returns 200, and *metadata* fetches return 200 — but the actual package tarball returns `403 "You must accept the End User License Agreement (EULA) ... before proceeding"`. After a single `POST /service/rest/v1/system/eula`, the identical request returns 200 with 318,961 bytes. The upstream chart has **zero** EULA handling (`grep -rin eula nexus3/` → no matches; zero upstream issues mention it). A chart that skips this will deploy green, show four correctly-configured proxy repos in the UI, and fail every single `npm install` — precisely the silent-corruption failure mode the project's anti-slop rules exist to prevent, and it would surface as a mystery in Phase 24/25 rather than here.

The second discovery creates a real tension with D-04's letter. The upstream chart's built-in config Job does use the REST API for repositories (`GET → 200 ? PUT : POST`, exactly D-04's idempotency pattern), but enabling it (`config.enabled: true`) also force-writes `nexus.scripts.allowCreation=true` into `nexus.properties` and unconditionally uploads two Groovy scripts to `/service/rest/v1/script` — the deprecated scripting API D-04 explicitly rejects. On a stock 3.96.0 that endpoint returns `HTTP 410 "Creating and updating scripts is disable"`. The chart re-enables it to make its own Job work. The planner must choose between reusing the upstream Job (fast, but re-enables deprecated scripting) and writing a purpose-built wrapper Job (pure D-04 compliance, ~80 lines of shell, also the natural home for the mandatory EULA step). This research recommends the latter, because the EULA step is required regardless and a second Job would otherwise duplicate the readiness-polling logic.

**Primary recommendation:** Confirm the chart-base substitution with the user, then wrap `stevehipwell/nexus3` 5.26.0 with `config.enabled: false` and ship one purpose-built post-install Job that (1) polls `/service/rest/v1/status/writable`, (2) accepts the EULA, (3) creates the four proxy repos via `GET → PUT/POST`. Omit `persistence.storageClass` entirely. Pin the subchart with a committed `Chart.lock` and pin the Job's container image by digest.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Nexus process, JVM, data directory | Kubernetes workload (StatefulSet) | — | Upstream subchart owns this entirely; D-01's intent is to never reimplement it. |
| Persistent storage / StorageClass selection | Kubernetes storage (PVC via `volumeClaimTemplates`) | Cluster default StorageClass | NEXUS-03 is satisfied by *omission* — the tier that resolves the default is the Kubernetes control plane, not the chart. |
| EULA acceptance | Nexus application state (on the PVC) | Post-install Job | It is runtime state persisted in the embedded H2 database, not config — so it must be applied by an API call after boot, and it survives pod restarts. |
| Proxy repository definitions | Nexus application state (on the PVC) | Post-install Job | Same: repositories live in the database, not in any Kubernetes object. This is why D-04's Job is the only mechanism that can satisfy "configured". |
| Upstream registry URLs | Chart values (`values.yaml`) | Consumer override | D-05 — declarative input rendered into the Job's ConfigMap. |
| Admin bootstrap password | Kubernetes Secret (consumer-supplied) | StatefulSet env + Job env | Upstream wires one Secret to both `NEXUS_SECURITY_INITIAL_PASSWORD` on the pod and `NEXUS_PASSWORD` on the Job. Never a chart default on a public chart. |
| Anonymous pull enablement | Nexus application state | Post-install Job | **Phase 24 (NEXUS-02)** — out of scope here, but the same Job is its natural home. Noted so Phase 24 extends rather than rebuilds. |
| Ingress / TLS / hostnames | Private ArgoCD overlay | — | PROJECT.md Key Decision: environment-specific values never land in the public chart. |

---

## Critical Finding: D-01 Is Not Satisfiable As Written

**This is the one item that must be resolved by the user before planning.** Research is not blocked; the planner is.

`helm search repo sonatype --versions` against `https://sonatype.github.io/helm3-charts/` returns exactly seven charts. None is named `nexus3`:

```
sonatype/nexus-iq-server          207.1.0   1.207.1   (a different product — IQ Server, not Repository)
sonatype/nexus-iq-server-ha       207.1.0   1.207.1   (a different product)
sonatype/nexus-repository-manager  64.2.0    3.64.0   DEPRECATED Sonatype Nexus Repository Manager
sonatype/nxrm-aws-resiliency       64.2.0    3.64.0   DEPRECATED
sonatype/nxrm-ha                   96.1.0    3.96.1   Resilient Deployment of Sonatype Nexus Repository
sonatype/nxrm-ha-aws               61.0.3    3.61.0   DEPRECATED
sonatype/nxrm-ha-azure             61.0.3    3.61.0   DEPRECATED
```
[VERIFIED: `helm search repo sonatype --versions`, 2026-09-17]

Sonatype's own archive notice on `github.com/sonatype/nxrm3-helm-repository` (repo `archived: true`, last push 2024-02-27) states:

> As of October 24, 2023, we will no longer update or support the Single-Instance OSS/Pro Helm Chart. Deploying Nexus Repository in containers with an embedded database has been known to corrupt the database under some circumstances. We strongly recommend that you use an external PostgreSQL database for Kubernetes deployments. ... We now provide one HA/Resiliency Helm Chart ... This is our only supported Helm chart for deploying Sonatype Nexus Repository; it requires a PostgreSQL database.

[VERIFIED: `gh api repos/sonatype/nxrm3-helm-repository` + README contents]

### The three candidates, measured

| | `sonatype/nexus-repository-manager` | `sonatype/nxrm-ha` | `stevehipwell/nexus3` |
|---|---|---|---|
| Published by | Sonatype (official) | Sonatype (official) | Community (MIT, ArtifactHub **verified publisher**) |
| Chart / app version | 64.2.0 / **3.64.0** | 96.1.0 / 3.96.1 | 5.26.0 / **3.96.0** |
| Status | **DEPRECATED**, frozen since Feb 2024 | Supported | Active (pushed 2026-09-08) |
| Workload | Deployment (`statefulset.enabled: false`, "not supported") | StatefulSet | StatefulSet |
| Database | Embedded — *Sonatype warns of corruption* | **External PostgreSQL required** | Embedded (`nexus.datastore.enabled=true`) |
| Defaults | 1 replica | **`replicaCount: 3`, `clustered: true`** | `replicas: 1` |
| License needed | No | **Yes** (`secret.license`, Pro) | No (`license.enabled: false`) |
| D-04 REST provisioning | Not provided | Not provided | **Built in** (`config.repos[]`) |
| D-06 storageClass omission | Supported (`persistence.storageClass` commented out) | **No** — uses a non-standard `storageClass.enabled/name/provisioner` block | **Verified working** |
| D-08 floating tag | Impossible — pinned `tag: 3.64.0` forever | Pinned `nexusTag: 3.96.1` | `tag:` empty → defaults to `.Chart.AppVersion` |

[VERIFIED: `helm show values` for each chart at the versions listed]

### Why each official chart fails this phase's own constraints

- **`nexus-repository-manager`** contradicts **D-08**. "Floats with upstream default" is meaningless on a chart whose default is frozen at Nexus 3.64.0 and will never move. It also ships a version predating Community Edition entirely, so the whole CE/EULA analysis below would not apply — at the cost of running 32 releases behind on a security tool, in a security-tooling repo, against Sonatype's own do-not-use advice.
- **`nxrm-ha`** contradicts the milestone's zero-cost premise (REQUIREMENTS.md core value: "zero ongoing cost") and **D-06**. It defaults to three clustered replicas, mandates an external PostgreSQL, and gates on a Pro license file. Its `storageClass` block is a bespoke provisioner-creating schema, not the standard `persistence.storageClass` passthrough D-06 assumes.
- **`stevehipwell/nexus3`** satisfies D-03 through D-08 as written and runs the same `docker.io/sonatype/nexus3` image Sonatype publishes. It fails only the word "official" in D-01.

### The reconciling reading (needs user confirmation — do not assume)

D-01 may have meant *"the upstream chart for the official `nexus3` image"* rather than *"a chart published by Sonatype."* Under that reading `stevehipwell/nexus3` satisfies D-01 exactly: it is upstream (not vendored, not forked — consumed as a `dependencies:` entry), it is the canonical chart for `nexus3`, and the deployed artifact is Sonatype's official image, digest `sha256:a1f2dbdc4c94d3710c52d0a5fa2dd1dc3816f1637ce293f95746e78d4b170242`. **This is `[ASSUMED]` (A1) — the planner must route it through user confirmation, not decide it.**

---

## Standard Stack

### Core

| Component | Version | Purpose | Why standard |
|-----------|---------|---------|--------------|
| `stevehipwell/nexus3` (Helm) | 5.26.0 | Subchart dependency providing StatefulSet, Service, PVC, ServiceAccount, probes | Only actively-maintained chart tracking current Nexus without a Pro license or external DB. ArtifactHub **verified publisher**, MIT, 178★, 94 forks. [VERIFIED: `helm search repo`, `gh api repos/stevehipwell/helm-charts`, ArtifactHub API] |
| `docker.io/sonatype/nexus3` | `3.96.0-ubi` | Nexus Repository Community Edition runtime | Sonatype's official image; the chart derives the tag as `{{ .Chart.AppVersion }}-ubi`, satisfying D-08's float. [VERIFIED: rendered image is `docker.io/sonatype/nexus3:3.96.0-ubi`] |
| Nexus REST API v1 | `/service/rest/v1` | EULA acceptance, repo CRUD, readiness | The only supported configuration surface since the Groovy scripting API was disabled by default. [VERIFIED: live OpenAPI spec at `/service/rest/swagger.json`] |
| Helm | 3.x / 4.x | Packaging, `dependency build`, `lint`, `template` | Locally `v4.3.0+gbec5b06`. `helm dependency build` + `helm lint` on a wrapper prototype both succeeded. [VERIFIED] |

### Supporting

| Component | Version | Purpose | When to use |
|-----------|---------|---------|-------------|
| `docker.io/alpine/k8s` | `1.31.2` (digest `sha256:d489e3c7a6221af7394bc54a1498b641ada49ca51c344630966a62411b91a3df`) | Job container — bundles `curl`, `jq`, `bash`, `kubectl` | Default in upstream `config.job.image`; reuse it for the wrapper Job so no new image is introduced. **Pin by digest** via the chart's `digest:` knob. [VERIFIED: `docker buildx imagetools inspect`] |
| `cgr.dev/chainguard/bash` | `latest` (digest `sha256:d57efd5fbb52ca2092c6a4ef80ebe45db24bc496ad3a3103eeab15871a33dd95`) | Init containers in the subchart | Defaults to the **mutable `latest` tag** — see §Pitfall 6. Pin via `bashImage.digest`. [VERIFIED] |
| `Chart.lock` | generated | Reproducible subchart resolution | `helm dependency build` writes it; commit it. Offsets D-08's floating-tag risk without contradicting D-08 (the *image* still floats with the chart's `appVersion`; only the *chart* is pinned). |
| Renovate (`helmv3` manager) | n/a | Keeping the `Chart.yaml` dependency current | Renovate's `helmv3` manager matches `/(^\|/)Chart\.ya?ml$/`; **Dependabot does not support Helm chart dependencies**. The repo currently has only `.github/dependabot.yml` (github-actions ecosystem). See Open Question Q3. [VERIFIED: Renovate docs + `ls` of security-platform] |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| `stevehipwell/nexus3` | `sonatype/nexus-repository-manager` 64.2.0 | "Official" badge; but deprecated, Nexus 3.64.0 frozen, Sonatype warns of DB corruption, contradicts D-08. |
| `stevehipwell/nexus3` | `sonatype/nxrm-ha` 96.1.0 | Officially supported and current; but 3 replicas + PostgreSQL + Pro license — breaks the zero-cost premise and D-06. |
| Purpose-built wrapper Job | Upstream `config.enabled: true` | Far less code; but re-enables the deprecated scripting API (D-04 tension) and still cannot accept the EULA. See §Pitfall 2. |
| Post-install Job | Groovy script via ConfigMap | Explicitly rejected by D-04, and **measured dead**: `POST /service/rest/v1/script` → `410 "Creating and updating scripts is disable"` on stock 3.96.0. [VERIFIED] |

**Installation (wrapper `Chart.yaml` dependency — verified to resolve):**
```bash
helm repo add stevehipwell https://stevehipwell.github.io/helm-charts/
helm dependency build kubernetes/nexus      # writes Chart.lock + charts/nexus3-5.26.0.tgz
helm lint kubernetes/nexus                  # observed: "1 chart(s) linted, 0 chart(s) failed"
```

---

## Package Legitimacy Audit

No npm/PyPI/crates packages are installed by this phase, so `slopcheck` (npm/PyPI-oriented) is **N/A**. The equivalent supply-chain surface is Helm chart repositories and container images, audited below with registry-native tooling.

| Artifact | Registry | Age / currency | Popularity | Source repo | Verification | Disposition |
|----------|----------|----------------|------------|-------------|--------------|-------------|
| `stevehipwell/nexus3` 5.26.0 | `stevehipwell.github.io/helm-charts` | pushed 2026-09-08 (9 days) | 178★ / 94 forks | [github.com/stevehipwell/helm-charts](https://github.com/stevehipwell/helm-charts) (MIT, not archived) | ArtifactHub `verified_publisher: true`; `signed: false` | **Approved, pending A1 user confirmation** |
| `docker.io/sonatype/nexus3:3.96.0-ubi` | Docker Hub | current (app 3.96.0) | Sonatype official | [github.com/sonatype/docker-nexus3](https://github.com/sonatype/docker-nexus3) | digest `sha256:a1f2dbdc…170242` resolved | Approved |
| `docker.io/alpine/k8s:1.31.2` | Docker Hub | tag-pinned, no digest by default | widely used | alpine/k8s | digest `sha256:d489e3c7…91a3df` resolved | **Flagged** — pin by digest in wrapper values |
| `cgr.dev/chainguard/bash:latest` | Chainguard | **mutable `latest`** | Chainguard official | chainguard-images | digest `sha256:d57efd5f…33dd95` resolved | **Flagged** — `latest` violates the repo's SHA-pin convention (ADR-004); pin via `bashImage.digest` |
| `sonatype/helm3-charts` (rejected) | — | — | — | — | charts are deprecated / license-gated | **REMOVED** from recommendations |

**Removed:** `sonatype/nexus-repository-manager`, `sonatype/nxrm-ha` — see §Critical Finding.
**Flagged:** `alpine/k8s` and `chainguard/bash` ship unpinned; the chart exposes a `digest:` knob for both. The planner should add a `checkpoint:human-verify` before the first `helm dependency build`, because chart-repo additions are not covered by any existing gate in `security-platform`.

**Caveat:** the chart is **not signed** (`signed: false`), and ArtifactHub "verified publisher" attests domain control, not code review. Combined with A1, this is the strongest argument for the user to consciously accept a community chart rather than have it substituted silently.

---

## Architecture Patterns

### System Architecture Diagram

```
                       consumer values.yaml                    private ArgoCD overlay
                    (public, in security-platform)          (hostnames, storageClass, TLS)
                                 │                                      │
                                 └───────────────┬──────────────────────┘
                                                 ▼
                                 ┌───────────────────────────────┐
                                 │  kubernetes/nexus (wrapper)   │
                                 │  Chart.yaml + Chart.lock      │
                                 └───────────────┬───────────────┘
                                                 │ dependency: nexus3 5.26.0
                          ┌──────────────────────┴───────────────────────┐
                          ▼                                              ▼
          ┌───────────────────────────────┐            ┌──────────────────────────────────┐
          │ subchart: StatefulSet         │            │ wrapper: provisioning Job        │
          │  sonatype/nexus3:<app>-ubi    │            │  ConfigMap(script) + ConfigMap   │
          │  env NEXUS_SECURITY_          │            │  (4 repo JSON bodies)            │
          │      INITIAL_PASSWORD ◄───┐   │            └──────────────┬───────────────────┘
          │  volumeClaimTemplates     │   │                           │
          │   └─ storageClassName ────┼───┼── OMITTED ⇒ cluster       │
          │        (absent by default)│   │   default StorageClass    │
          └───────────────┬───────────┘   │      (NEXUS-03 ✓)         │
                          │               │                           │
                          │      ┌────────┴─────────┐                 │
                          │      │ Secret           │                 │
                          │      │ (consumer-made)  │─── NEXUS_PASSWORD┤
                          │      │ admin password   │                 │
                          │      └──────────────────┘                 │
                          ▼                                           │
                 ┌─────────────────┐                                  │
                 │ Service :8081   │◄─────────────────────────────────┘
                 └────────┬────────┘   http://<fullname>.<ns>.svc.cluster.local:8081
                          │
                          │   Job step 1: poll GET /service/rest/v1/status/writable → 200
                          │   Job step 2: GET  /v1/system/eula → POST accepted:true → 204   ◄── MANDATORY
                          │   Job step 3: for each of 4 repos:
                          │                 GET /v1/repositories/{fmt}/proxy/{name}
                          │                   200 → PUT  (expect 204)
                          │                   404 → POST (expect 201)
                          ▼
              ┌───────────────────────────────────────────────┐
              │ Nexus application state (persisted on the PVC) │
              │  npm-proxy    → registry.npmjs.org             │
              │  pypi-proxy   → pypi.org                       │
              │  docker-proxy → registry-1.docker.io           │
              │  helm-proxy   → <index.yaml repo — see Q1>     │
              └───────────────────────────────────────────────┘
                          │
                          ▼  (Phase 24: anonymous pull / NEXUS-02 — currently 401)
                    developer workstation
```

### Recommended Project Structure

```
security-platform/
└── kubernetes/                    # D-03: top-level, well-named subdirectories
    └── nexus/
        ├── Chart.yaml             # dependencies: nexus3 5.26.0 (alias optional — see note)
        ├── Chart.lock             # COMMIT this
        ├── values.yaml            # D-05 upstream URLs; persistence.storageClass OMITTED (D-06)
        ├── README.md              # consumer-facing: required Secret, overrides, EULA note
        ├── .helmignore
        ├── files/
        │   └── provision.sh       # shellcheck-lintable by the existing pre-commit hook
        └── templates/
            ├── configmap-provision-script.yaml   # .Files.Get files/provision.sh
            ├── configmap-repos.yaml              # one <n>-repo.json per values entry
            └── job-provision.yaml                # post-install,post-upgrade hook
```

Keeping `provision.sh` as a real file under `files/` (rather than inline in a template) is deliberate: the repo's existing pre-commit `shellcheck` hook has `types: [shell]` and will lint it automatically. An inline heredoc inside a YAML template is invisible to shellcheck. This mirrors how the upstream chart does it (`.Files.Glob "scripts/*"`).

**Note on `alias:`** — the subchart is already named `nexus3`, so `alias: nexus3` is a no-op. Values nest under the `nexus3:` key either way. A prototype using it built and linted cleanly; use it only if the planner wants the key name stated explicitly in `Chart.yaml`.

### Pattern 1: StorageClass by omission (D-06 / NEXUS-03)

**What:** Leave `persistence.storageClass` unset so no `storageClassName` field is emitted at all, letting the Kubernetes control plane substitute the cluster's default StorageClass.
**Why it works here:** the upstream template guards on `{{- with .Values.persistence.storageClass }}`, which skips on nil/empty. It additionally maps the sentinel `"-"` to `storageClassName: ""` (explicitly disabling dynamic provisioning) — a distinct behaviour the chart README documents and that consumers should not confuse with the default.
**Measured, not assumed:**

```bash
# storageClass omitted (the chart default and D-06's choice)
$ helm template t stevehipwell/nexus3 --version 5.26.0 --set persistence.enabled=true \
    | yq 'select(.kind=="StatefulSet") | .spec.volumeClaimTemplates[0].spec'
accessModes:
  - "ReadWriteOnce"
resources:
  requests:
    storage: "8Gi"                # ← no storageClassName key at all ⇒ cluster default

# consumer override
$ helm template t stevehipwell/nexus3 --version 5.26.0 --set persistence.enabled=true \
    --set persistence.storageClass=longhorn | yq '…'
accessModes:
  - "ReadWriteOnce"
storageClassName: "longhorn"
resources:
  requests:
    storage: "8Gi"
```
[VERIFIED: executed 2026-09-17, Helm v4.3.0]

**One gotcha the planner must not miss:** the upstream default is `persistence.enabled: false` — an `emptyDir`. The wrapper `values.yaml` must set `persistence.enabled: true`, or Nexus loses all state (including EULA acceptance and every proxy repo) on pod restart.

### Pattern 2: Idempotent REST provisioning (D-04)

**What:** `GET` the resource; `200` → `PUT` to update, `404` → `POST` to create. Never blind-`POST`.
**Why it is required:** a repeat `POST` of an existing repository returns **400**, not a benign conflict. Measured across all four formats:

| Format | `GET` before | `POST` create | `GET` after | `POST` again | `PUT` update |
|--------|-------------|---------------|-------------|--------------|--------------|
| npm | 404 | **201** | 200 | **400** | **204** |
| pypi | 404 | **201** | 200 | **400** | **204** |
| docker | 404 | **201** | 200 | **400** | **204** |
| helm | 404 | **201** | 200 | **400** | **204** |

[VERIFIED: live against `sonatype/nexus3:3.96.0-ubi`, 2026-09-17]

This is exactly the shape of the upstream `configure.sh` loop, which is good independent corroboration that the pattern is correct — reuse the *logic* even if not the *script*.

**Service hostname the Job must target.** The subchart's Service renders as `{{ .Release.Name }}-nexus3` (helper `nexus3.serviceName` → `nexus3.fullname`); a release named `t` produced `Service/t-nexus3` on port 8081 [VERIFIED]. The Job's endpoint is therefore:

```
http://{{ .Release.Name }}-nexus3.{{ .Release.Namespace }}.svc.cluster.local:8081
```

Note this **breaks if a consumer sets `nexus3.fullnameOverride` or `nexus3.nameOverride`** — both are part of the D-07 passthrough surface. Prefer deriving the name through the same helper logic rather than hardcoding the `-nexus3` suffix, or document the limitation in the README.

**Stock repositories will also be created.** `nexus.skipDefaultRepositories=true` is only emitted when `config.enabled` is true. With the recommended `config.enabled: false`, Nexus provisions its stock maven/nuget repositories alongside the four proxies. Harmless, but noisy. The wrapper can suppress them by appending to the subchart's `properties: []` passthrough list — planner's choice, not a requirement.

### Pattern 3: Admin bootstrap via a single consumer-supplied Secret

The upstream chart wires one Secret to both sides, which removes the classic "the random admin password is in `/nexus-data/admin.password` on an RWO volume the Job can't mount" problem entirely:

```yaml
# statefulset.yaml (upstream, lines 220-231)
{{- if .Values.rootPassword.secret }}
  - name: NEXUS_SECURITY_RANDOMPASSWORD
    value: "false"
  - name: NEXUS_SECURITY_INITIAL_PASSWORD
    valueFrom: { secretKeyRef: { name: ..., key: ... } }
{{- else }}
  - name: NEXUS_SECURITY_RANDOMPASSWORD
    value: "true"
{{- end }}
```
The same Secret feeds the Job's `NEXUS_PASSWORD`. **Verified live:** launching the image with `NEXUS_SECURITY_RANDOMPASSWORD=false` + `NEXUS_SECURITY_INITIAL_PASSWORD=admin123` produced a working `admin:admin123` login against `/service/rest/v1/status/check`.

**The wrapper must `required` this value and ship no default.** This is a public chart in a security-tooling repo; a default password would be a genuine finding, and `gitleaks` already runs over the repo.

### Anti-Patterns to Avoid

- **Vendoring/forking the upstream chart.** Explicitly excluded by D-01, and it would strand the chart on 5.26.0 with no update path.
- **Blind `POST` for repository creation.** Returns 400 on re-run → with `backoffLimit: 0` the Job fails permanently on every upgrade.
- **Putting hostnames, ClusterIssuer names, or a concrete `storageClass` in the public `values.yaml`.** PROJECT.md's Key Decision reserves those for the private ArgoCD overlay.
- **Assuming a green Helm release means a working Nexus.** Pre-EULA, everything is green and nothing downloads. Whatever verification the plan defines must fetch a real artifact, not just assert `.status == "deployed"`.
- **Relying on `helm --wait` to sequence the Job.** The upstream config Job carries no `helm.sh/hook` annotations at all (verified: rendered `.metadata.annotations` is absent). It is an ordinary Job. Sequencing must come from in-script polling.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Nexus StatefulSet, PVC, probes, securityContext, ServiceAccount | Custom templates | `stevehipwell/nexus3` subchart | D-01's whole point. The upstream handles `readOnlyRootFilesystem`, fsGroup 200, the `chown-data-dir` init container, and StatefulSet ordinals — all easy to get subtly wrong. |
| Readiness detection | `sleep 120` | Poll `GET /service/rest/v1/status/writable` until 200 | The unauthenticated `/status` endpoint returns 200 while Nexus is still starting; `/status/writable` is the correct write-readiness gate. |
| Repository JSON schemas | Hand-written field lists from memory | The live OpenAPI spec at `/service/rest/swagger.json` | Required-field sets differ per format — `docker` requires `docker` **and** `dockerProxy`; `pypi` does **not** require `httpClient` while npm/docker/helm do. Verified by extracting `*ProxyRepositoryApiRequest.required` from the spec. |
| Idempotency logic | Custom conflict parsing | `GET → 200?PUT:POST` | Measured status codes above. |
| Secret management for the admin password | Chart-generated random password | Consumer-supplied Secret + `NEXUS_SECURITY_INITIAL_PASSWORD` | The upstream already wires it to both the pod and the Job. |
| Keeping the subchart current | A cron/script | Renovate `helmv3` manager | Dependabot cannot do Helm chart dependencies (Q3). |

**Key insight:** essentially every Nexus-on-Kubernetes failure in this domain is a *sequencing or application-state* problem, not a manifest problem. The manifests are solved upstream; the value this phase adds is the ordered, idempotent, loudly-failing application-state bootstrap — EULA first, then repositories.

---

## Common Pitfalls

### Pitfall 1: The Community Edition EULA silently 403s every download

**What goes wrong:** Chart deploys, pod is Ready, all four proxy repos exist and are visible in the UI, `helm status` is `deployed`, metadata requests return 200 — and every actual package download returns 403.
**Why it happens:** since Nexus **3.77.0** the free edition is Community Edition, which ships with `accepted: false` and blocks component fetch/upload until an administrator accepts the EULA via the onboarding wizard or the REST API. The chart never does this.
**Measured on a fresh 3.96.0 container (`accepted: false`):**

```
POST /service/rest/v1/repositories/npm/proxy    → 201   (repo creation works)
PUT  /service/rest/v1/security/anonymous        → 200   (anonymous config works)
GET  /repository/npm-proxy/lodash               → 200   249641 bytes   (metadata works!)
GET  /repository/npm-proxy/lodash/-/lodash-4.17.21.tgz → 403  192 bytes
     body: "You must accept the End User License Agreement (EULA) through the
            onboarding wizard or REST API before proceeding."

POST /service/rest/v1/system/eula {accepted:true} → 204
GET  /repository/npm-proxy/lodash/-/lodash-4.17.21.tgz → 200  318961 bytes
```
[VERIFIED end-to-end, 2026-09-17]

**How to avoid:** the provisioning Job must `GET /service/rest/v1/system/eula`, set `.accepted = true` on the returned object (the `disclaimer` string must be echoed back verbatim), and `POST` it. The call is **idempotent** — POSTing twice returns 204 both times [VERIFIED].
**Reproduced under the chart's exact rendered properties.** The run above used the stock image. Because the chart always renders `nexus.properties` containing `nexus.datastore.enabled=true` and (with `license.enabled: false`) `nexus.loadAsOSS=true`, the whole sequence was repeated on a third container booted with precisely those two lines at `/nexus-data/etc/nexus.properties` — the same path and content the chart mounts. Results were **identical**: `eula.accepted=false`, repo create `201`, tarball pre-EULA `403`, `POST eula` `204`, tarball post-EULA `200 / 318,961 bytes`, scripting API `410`. **`nexus.loadAsOSS=true` does not bypass the Community Edition EULA gate.** [VERIFIED, 2026-09-17]

**Also note:** repo creation succeeds *before* EULA acceptance, so the two steps are **order-independent** — there is no hook-weight race to design around. Do EULA first anyway, for a clean failure signal.

**Consent caveat:** accepting a licence agreement automatically on the consumer's behalf is a design decision, not a detail — see Open Question Q5.
**Warning signs:** proxies look perfect in the UI but `npm install` fails; a 192-byte response body where a tarball was expected.

### Pitfall 2: `config.enabled: true` re-enables the deprecated scripting API (D-04 tension)

**What goes wrong:** turning on the upstream chart's built-in provisioning also turns on the Groovy scripting API that D-04 explicitly rejects.
**Why it happens:** `templates/configmap-properties.yaml` is gated on `config.enabled`:

```yaml
{{- if .Values.config.enabled }}
    nexus.scripts.allowCreation=true
    nexus.blobstore.provisionDefaults={{ .Values.config.createDefaultBlobStore }}
    nexus.skipDefaultRepositories=true
{{- end }}
```
and `configure.sh` then loops `for script_file in /scripts/*.groovy` unconditionally, POSTing `cleanup.groovy` and `task.groovy` to `/service/rest/v1/script`. On a stock 3.96.0 (without that property) that endpoint returns:

```
HTTP 410  {"name":"cleanup","result":"Creating and updating scripts is disable"}
```
[VERIFIED: direct POST with a correctly JSON-escaped body]

Because `configure.sh` `error()`s on any unexpected status and the Job has `backoffLimit: 0`, a mis-set property means one permanent, unretried failure.
**How to avoid:** set `config.enabled: false` and ship a purpose-built wrapper Job. The wrapper needs its own Job for the EULA regardless, so this costs nothing extra and keeps D-04 satisfied in spirit as well as letter.
**If the planner prefers reusing the upstream Job:** that is defensible (less code, upstream-maintained), but it must be recorded as a conscious deviation from D-04's "not a Groovy/ConfigMap script" clause and routed to the user — the deprecated API gets re-enabled either way.

### Pitfall 3: The upstream config Job is not a Helm hook, and breaks under ArgoCD

**What goes wrong:** works under `helm upgrade`, silently stops re-running (or errors) under ArgoCD in Phase 25.
**Why it happens:** the Job's name is `{{ fullname }}-config-{{ .Release.Revision }}` and it carries **no** `helm.sh/hook` annotations (verified: rendered `.metadata.annotations` is absent; `ttlSecondsAfterFinished: 600`, `backoffLimit: 0`, `restartPolicy: Never`). Under `helm upgrade` the Revision increments, producing a new Job name each time. **ArgoCD renders with `helm template`, where `.Release.Revision` is always `1`** — so the name never changes, and a second sync tries to mutate an immutable Job spec.
**How to avoid:** on the wrapper's own Job, use real Helm hooks plus ArgoCD-compatible annotations:

```yaml
annotations:
  "helm.sh/hook": post-install,post-upgrade
  "helm.sh/hook-weight": "0"
  "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
  "argocd.argoproj.io/hook": Sync
  "argocd.argoproj.io/sync-options": Replace=true
```
Setting this now means Phase 25 validates the chart rather than rediscovering this. (If reusing the upstream Job, `config.job.annotations` is the lever.)
**Warning signs:** `Job.batch "…" is invalid: spec.template: field is immutable` on the second ArgoCD sync.

### Pitfall 4: No timeout on the readiness poll

**What goes wrong:** a Job that hangs forever instead of failing.
**Why it happens:** upstream `configure.sh` polls `while [[ "$(curl … /status)" -ne "200" ]]; do sleep 15; done` with **no** iteration cap, and the chart exposes no `activeDeadlineSeconds` knob. Combined with `backoffLimit: 0`, an unreachable Nexus produces a Job that never completes and never fails.
**How to avoid:** bound the loop (e.g. 60 × 10s = 10 min) and `exit 1` on exhaustion; set `activeDeadlineSeconds` on the wrapper Job. Nexus first boot was ~30s on this workstation, but Sonatype's own guidance and constrained homelab hardware make 1–3 minutes realistic — size the timeout for the slow case.
**Also:** poll `/status/writable`, not `/status`.

### Pitfall 5: `persistence.enabled` defaults to `false`

Upstream default is `false` → `emptyDir`. Every restart wipes the EULA acceptance and all four repos, and the Job would have to re-run to restore them. The wrapper must set `persistence.enabled: true`. Easy to miss precisely because D-06 focuses attention on `storageClass` rather than `enabled`.

### Pitfall 6: Unpinned third-party images inside the subchart

`bashImage.tag: latest` (mutable) and `config.job.image.tag: 1.31.2` (tag, not digest) sit inside a repo whose ADR-004 convention is SHA-pinning and whose CI SHA-pins every GitHub Action. Both expose a `digest:` knob. Pin them in the wrapper `values.yaml`. Note this does **not** conflict with D-08 — D-08 is about the *Nexus* image tag; these are incidental helper images.

### Pitfall 7: Community Edition usage limits

CE supports up to **40,000 total components and 100,000 requests per day**; beyond that, "Community Edition's safeguards will pause the addition of new components until usage returns below both thresholds." Comfortable for a single-developer homelab, but it is a real ceiling that belongs in the chart README, and it interacts with D-08: a floating tag means a future release could change these limits without any repo change. [CITED: help.sonatype.com/en/ce-onboarding.html]

---

## Code Examples

### EULA acceptance (idempotent) — the step upstream does not provide

```bash
# Source: verified live against sonatype/nexus3:3.96.0-ubi, 2026-09-17
# GET returns {"accepted":false,"disclaimer":"Use of Sonatype Nexus Repository - Community
# Edition is governed by ... ce-eula."} — the disclaimer must be echoed back verbatim.
curl -sS -u "admin:${NEXUS_PASSWORD}" "${NEXUS_HOST}/service/rest/v1/system/eula" \
  | jq '.accepted = true' > /tmp/eula.json

code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -u "admin:${NEXUS_PASSWORD}" \
  -d @/tmp/eula.json "${NEXUS_HOST}/service/rest/v1/system/eula")
[ "$code" = "204" ] || { echo "EULA acceptance failed: HTTP $code" >&2; exit 1; }
# Second POST also returns 204 — safe on every upgrade.
```

### Bounded readiness poll

```bash
# Source: adapted from upstream configure.sh; the unbounded original is Pitfall 4.
for i in $(seq 1 60); do
  code=$(curl -sS -o /dev/null -w '%{http_code}' "${NEXUS_HOST}/service/rest/v1/status/writable" || true)
  [ "$code" = "200" ] && break
  echo "Waiting for Nexus (attempt ${i}/60, HTTP ${code})..."
  sleep 10
done
[ "$code" = "200" ] || { echo "Nexus not writable after 600s" >&2; exit 1; }
```

### Idempotent proxy repository upsert

```bash
# Source: status codes measured live for all four formats (see Pattern 2 table).
upsert_repo() {   # $1=format  $2=name  $3=json file
  local fmt="$1" name="$2" body="$3" code
  code=$(curl -sS -o /dev/null -w '%{http_code}' -u "admin:${NEXUS_PASSWORD}" \
           "${NEXUS_HOST}/service/rest/v1/repositories/${fmt}/proxy/${name}")
  if [ "$code" = "200" ]; then
    code=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H 'Content-Type: application/json' \
             -u "admin:${NEXUS_PASSWORD}" -d "@${body}" \
             "${NEXUS_HOST}/service/rest/v1/repositories/${fmt}/proxy/${name}")
    [ "$code" = "204" ] || { echo "update ${name} failed: HTTP ${code}" >&2; exit 1; }
  else
    code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
             -u "admin:${NEXUS_PASSWORD}" -d "@${body}" \
             "${NEXUS_HOST}/service/rest/v1/repositories/${fmt}/proxy")
    [ "$code" = "201" ] || { echo "create ${name} failed: HTTP ${code}" >&2; exit 1; }
  fi
}
```

### The four request bodies (each returned 201 on create, 204 on PUT — D-05 defaults)

```jsonc
// npm — POST /service/rest/v1/repositories/npm/proxy
{"name":"npm-proxy","online":true,
 "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
 "proxy":{"remoteUrl":"https://registry.npmjs.org","contentMaxAge":1440,"metadataMaxAge":1440},
 "negativeCache":{"enabled":true,"timeToLive":1440},
 "httpClient":{"blocked":false,"autoBlock":true}}

// pypi — POST /service/rest/v1/repositories/pypi/proxy
{"name":"pypi-proxy","online":true,
 "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
 "proxy":{"remoteUrl":"https://pypi.org","contentMaxAge":1440,"metadataMaxAge":1440},
 "negativeCache":{"enabled":true,"timeToLive":1440},
 "httpClient":{"blocked":false,"autoBlock":true}}

// docker — POST /service/rest/v1/repositories/docker/proxy
// `docker` and `dockerProxy` are BOTH required by the schema.
// pathEnabled:true serves the registry on the main 8081 port as /repository/docker-proxy/...,
// avoiding a second connector port and a second ingress. forceBasicAuth:false is what
// Phase 24 will need for anonymous pull (it also requires the DockerToken realm — see hand-off).
{"name":"docker-proxy","online":true,
 "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
 "proxy":{"remoteUrl":"https://registry-1.docker.io","contentMaxAge":1440,"metadataMaxAge":1440},
 "negativeCache":{"enabled":true,"timeToLive":1440},
 "httpClient":{"blocked":false,"autoBlock":true},
 "docker":{"v1Enabled":false,"forceBasicAuth":false,"pathEnabled":true},
 "dockerProxy":{"indexType":"HUB","cacheForeignLayers":false}}

// helm — POST /service/rest/v1/repositories/helm/proxy
// remoteUrl below is the ONE value this research cannot recommend with confidence — see Q1.
{"name":"helm-proxy","online":true,
 "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
 "proxy":{"remoteUrl":"https://charts.helm.sh/stable","contentMaxAge":1440,"metadataMaxAge":1440},
 "negativeCache":{"enabled":true,"timeToLive":1440},
 "httpClient":{"blocked":false,"autoBlock":true}}
```
[VERIFIED: all four POSTed to a live 3.96.0 CE instance; npm/pypi/helm proxy fetches then returned 200 with 249,641 / 76,776 / 7,243,278 bytes respectively]

### Schema required-field sets (from the live OpenAPI spec)

```
NpmProxyRepositoryApiRequest     required: httpClient, name, negativeCache, online, proxy, storage
PypiProxyRepositoryApiRequest    required: name, negativeCache, online, proxy, storage      ← no httpClient
DockerProxyRepositoryApiRequest  required: docker, dockerProxy, httpClient, name, negativeCache, online, proxy, storage
HelmProxyRepositoryApiRequest    required: httpClient, name, negativeCache, online, proxy, storage
DockerAttributes                 required: forceBasicAuth, v1Enabled
DockerProxyAttributes            required: indexType  (enum: HUB | REGISTRY | CUSTOM)
```
[VERIFIED: `curl /service/rest/swagger.json | jq '.components.schemas[…].required'`]

### Wrapper `Chart.yaml` (built and linted successfully)

```yaml
apiVersion: v2
name: nexus
version: 0.1.0
appVersion: "3.96.0"
description: Nexus Repository with npm, PyPI, Docker and Helm proxy repositories preconfigured.
dependencies:
  - name: nexus3
    version: 5.26.0
    repository: https://stevehipwell.github.io/helm-charts/
```
```
$ helm dependency build kubernetes/nexus && helm lint kubernetes/nexus
Saving 1 charts / Downloading nexus3 from repo …
==> Linting kubernetes/nexus
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed
```
[VERIFIED]

---

## Second-Order Effects on `security-platform` CI

Adding `kubernetes/nexus/` to a repo with standing pre-commit and CI gates has measurable consequences. Per the project's Second-Order Effects rule, these were tested, not assumed.

### Confirmed breakage: the `yamllint` pre-commit hook

`.pre-commit-config.yaml` runs `yamllint -d relaxed` with `types: [yaml]` and **no** exclusion for chart templates. Helm Go templates are not valid YAML:

```
$ yamllint -d relaxed nexus3/templates/job-config.yaml
  1:3  error  syntax error: expected the node content, but found '-'  (syntax)
exit=1

$ yamllint -d relaxed nexus3/values.yaml   → exit 0
$ yamllint -d relaxed nexus3/Chart.yaml    → exit 0
```
[VERIFIED: yamllint 1.x, 2026-09-17]

**Fix:** add an exclusion to the `yamllint` hook, following the existing `^fixtures/` convention:
```yaml
      - id: yamllint
        args: [-d, relaxed]
        types: [yaml]
        exclude: ^kubernetes/.*/templates/   # Helm Go templates are not valid YAML
```
`Chart.yaml` and `values.yaml` remain linted — only `templates/` is excluded. This is a required task in the plan, not optional polish; without it every commit touching the chart fails pre-commit.

### Probable, unquantified: Checkov

`security.yml` runs `bridgecrewio/checkov-action` with `directory: .`, **no `framework:` filter**, and `soft_fail: false`. Checkov's `helm` framework renders charts and applies `CKV_K8S_*` checks, so the new chart will likely add findings.

**Honest status: could not quantify locally.** Checkov 3.2.396 refused to load the helm runner:
```
ERROR  There are no runners to run. This can happen if you ... specify a framework with
missing dependencies (e.g., helm or kustomize, which require those tools to be on your system).
```
Helm **is** on PATH — but it is Helm **v4.3.0**, and Checkov's helm runner appears not to detect it. CI uses the pinned `ghcr.io/bridgecrewio/checkov:3.3.17` image, which bundles its own Helm and very likely **will** engage. Confidence: **MEDIUM**.

**Planner action:** add an explicit verification task — run Checkov against the chart in CI (or in the pinned container locally) and record the delta in `CKV_K8S_*` findings *before* asserting the gate is unaffected. Note that `scripts/smoke-scans.sh` prints Checkov failure counts per framework but asserts no fixed totals, so it will not hard-break; the CI job's `soft_fail: false` is the thing to watch.

### Other gates

- **shellcheck** (`types: [shell]`) will lint `files/provision.sh` — desirable, and the reason for keeping it as a real file.
- **gitleaks** — ensure no literal example password (e.g. `admin123`) lands in `values.yaml` or the README.
- **markdownlint** — applies to the new `kubernetes/nexus/README.md`.
- **`helm dependency build` writes `charts/nexus3-5.26.0.tgz`.** Recommend `.gitignore`ing `kubernetes/*/charts/*.tgz` and committing `Chart.lock` instead: ArgoCD rebuilds dependencies itself `[ASSUMED]` (A8 — not verified in this session), and a committed tarball would be scanned by `trivy fs` as an opaque archive. If A8 turns out false, the tarball must be committed after all — verify in Phase 25 before removing it.

---

## Runtime State Inventory

Not a rename/refactor/migration phase — but the *substance* of this phase is runtime state, so the categories are answered explicitly.

| Category | Items found | Action required |
|----------|-------------|-----------------|
| Stored data | Nexus application state on the PVC: EULA acceptance flag, 4 proxy repo definitions, blob store, admin password hash. **None of it is a Kubernetes object** — it lives in the embedded H2 database. | Post-install Job (REST). Re-applied idempotently on upgrade. |
| Live service config | None yet — this is the first `kubernetes/` package. Phase 25's private ArgoCD overlay will hold the Application manifest and env values. | None this phase. |
| OS-registered state | None — nothing is registered outside the cluster. Verified: no host-level installers in scope. | None. |
| Secrets / env vars | One **consumer-supplied** Secret holding the admin password, consumed by `NEXUS_SECURITY_INITIAL_PASSWORD` (pod) and `NEXUS_PASSWORD` (Job). **`NEXUS_SECURITY_INITIAL_PASSWORD` applies only on FIRST boot** — rotating the Secret later changes the Job's credential but not Nexus's stored password, and the Job will start failing 401. | Document in README; do not rotate without an explicit change-password call. |
| Build artifacts | `Chart.lock` and `charts/nexus3-5.26.0.tgz` from `helm dependency build`. | Commit the lock; gitignore the tarball. |

---

## State of the Art

| Old approach | Current approach | When changed | Impact |
|--------------|------------------|--------------|--------|
| `sonatype/nexus-repository-manager` single-instance chart | Archived; Sonatype ships only `nxrm-ha` (PostgreSQL + license) | 2023-10-24 | No official zero-cost single-node chart exists. This is the root of the D-01 problem. |
| Nexus Repository **OSS** | Nexus Repository **Community Edition** + EULA + usage limits (40k components / 100k req/day) | **3.77.0** | Mandatory EULA acceptance step; a hard ceiling to document. |
| Groovy scripting API for provisioning | REST API v1; scripting disabled by default (`410` unless `nexus.scripts.allowCreation=true`) | progressively, ~3.21+ | Validates D-04. Note the upstream chart re-enables the old API. |
| Embedded OrientDB | H2 / `nexus.datastore.enabled=true` (`nexus.loadAsOSS=true` when unlicensed) | 3.x line | Single-node embedded storage still works; Sonatype recommends PostgreSQL at scale. **`loadAsOSS=true` does not opt out of Community Edition or its EULA gate** — verified by rerunning the full sequence under the chart's rendered properties (Pitfall 1). |
| Dependabot for all dependency classes | Renovate for Helm chart dependencies | ongoing | Dependabot has no Helm chart-dependency manager; Renovate's `helmv3` does. |

**Deprecated / do not use:**
- `sonatype/nexus-repository-manager`, `nxrm-aws-resiliency`, `nxrm-ha-aws`, `nxrm-ha-azure` — all carry `DEPRECATED` in their chart descriptions.
- `POST /service/rest/v1/script` (Groovy) — returns 410 by default.
- `https://charts.helm.sh/stable` — archived/read-only since Nov 2020, though it still serves an `index.yaml` (verified: 200, 9,839,197 bytes direct).

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| **A1** | D-01's "Sonatype's official upstream `nexus3` chart" is best satisfied by `stevehipwell/nexus3` 5.26.0, reading "nexus3" as the image/chart name rather than the publisher | Critical Finding, Standard Stack | **HIGH.** The entire chart base. If the user insists on a Sonatype-published chart, the phase must either accept a deprecated Nexus 3.64.0 or add PostgreSQL + a Pro license — both of which invalidate other locked decisions. Must be confirmed before planning. |
| **A2** | The Helm proxy's default upstream should be a classic `index.yaml` chart repository; `charts.helm.sh/stable` is the only general-purpose one that still responds | Code Examples, Q1 | MEDIUM. D-05 says "Helm Hub-style index" but Helm Hub is defunct and there is no universal Helm registry. A wrong default ships a proxy pointing at an archive. |
| **A3** | Checkov's helm framework will engage in CI (pinned 3.3.17 container) even though it did not engage locally with Helm v4.3.0 | Second-Order Effects | MEDIUM. If it does engage and `soft_fail: false`, new `CKV_K8S_*` findings could affect the gate. Quantify before asserting no impact. |
| **A4** | A purpose-built wrapper Job better satisfies D-04 than `config.enabled: true` | Summary, Pitfall 2 | MEDIUM. A judgement call on D-04's intent ("not a Groovy/ConfigMap script"). Reusing upstream is defensible but re-enables the deprecated scripting API. User should arbitrate. |
| **A5** | `docker.pathEnabled: true` (no separate connector port) is the right Docker proxy shape | Code Examples | MEDIUM. Accepted by the API and stored correctly (verified), but an actual `docker pull` through it was **not** tested — that needs ingress/TLS, which is Phase 25. Changing it later means recreating the repo. |
| **A6** | ArgoCD maps `helm.sh/hook: post-install,post-upgrade` to PostSync and honours `argocd.argoproj.io/sync-options: Replace=true` | Pitfall 3 | MEDIUM. From training knowledge, **not verified in this session**. Phase 25 is where it gets tested; the annotations are cheap insurance either way. |
| **A7** | Nexus first-boot readiness of 1–3 minutes on homelab hardware | Pitfall 4 | LOW. Measured ~30s on this workstation (12 cores). Only affects timeout sizing; a generous bound absorbs the error. |
| **A8** | ArgoCD resolves Helm subchart dependencies itself, so `charts/*.tgz` need not be committed | Second-Order Effects | LOW-MEDIUM. Not verified this session. If false, the tarball must be committed and will be scanned by `trivy fs`. Verify in Phase 25. |
| **A9** | Auto-accepting the EULA on the consumer's behalf is acceptable default behaviour for a public chart | Pitfall 1, Q5 | **MEDIUM-HIGH.** A legal act performed for whoever runs `helm install`. Q5 recommends an explicit opt-in value instead; the user should decide. |

---

## Open Questions

1. **What should the Helm proxy's default `remoteUrl` be? (blocks D-05)**
   - *What we know:* Nexus `helm` proxies classic chart repositories serving `index.yaml`; it does not proxy OCI registries. `https://charts.helm.sh/stable` still responds (direct: 200, 9,839,197 bytes; through the proxy: 200, 7,243,278 bytes) [VERIFIED].
   - *What's unclear:* it has been archived and read-only since November 2020. ArtifactHub is an index *of* repositories, not a repository. There is no universal Helm equivalent of registry.npmjs.org. (The byte-count difference between direct and proxied fetches was not investigated — likely metadata rewriting — and is worth a glance if this URL is kept.)
   - *Recommendation:* ask the user. Realistic options: (a) keep `charts.helm.sh/stable` as a documented-legacy default, (b) default to a repository the user actually consumes (e.g. `https://charts.jetstack.io`, `https://prometheus-community.github.io/helm-charts`), or (c) ship the repo definition with `online: false` and require the consumer to set a URL — which weakens NEXUS-01's "configured".

2. **Reuse the upstream config Job, or ship a purpose-built one? (D-04 interpretation)**
   - *What we know:* upstream does repositories via REST (D-04-compliant) but also force-enables `nexus.scripts.allowCreation=true` and uploads Groovy scripts (D-04-rejected). It cannot accept the EULA in either case.
   - *Recommendation:* purpose-built (`config.enabled: false`). The EULA Job is mandatory anyway; two Jobs would duplicate readiness polling.

3. **Adopt Renovate for the `Chart.yaml` dependency?**
   - *What we know:* Dependabot cannot update Helm chart dependencies; Renovate's `helmv3` manager can. The repo has `.github/dependabot.yml` (github-actions only) and no Renovate config. CONTEXT.md §Established Patterns explicitly asks whether an equivalent mechanism is expected.
   - *Recommendation:* out of scope for this phase — introducing a second bot is a repo-wide decision. Surface it and let the user decide whether it becomes a follow-up.

4. **Should the chart accept the Community Edition EULA automatically, or require explicit consumer opt-in?**
   - *What we know:* without acceptance, every component download returns 403 (Pitfall 1), so NEXUS-01's "configured" is not met. The acceptance call is a one-line idempotent `POST`. This is a **public** chart, so the Job would be accepting Sonatype's licence agreement on behalf of every future consumer, silently, at install time.
   - *What's unclear:* whether the user wants that convenience or wants consumers to opt in. The project's own AUTONOMY CHECK rule asks "would the user want to know first?" for exactly this class of decision.
   - *Recommendation:* **do not auto-accept by default.** Ship `eula.accepted: false` in `values.yaml` and have the template `required` it — failing the render with a message naming the EULA URL (`https://links.sonatype.com/products/nxrm/ce-eula`) when unset. The Job then runs the acceptance only when the consumer has explicitly set `eula.accepted: true`. This mirrors the established licence-flag pattern used by other vendored charts, keeps NEXUS-01 satisfiable with one documented value, and gives Phase 25's private overlay the natural place to record acceptance. Tracked as A9 — needs user confirmation either way.

5. **Should D-08 (floating image tag) be revisited?** CONTEXT.md flags this.
   - *What we know:* the tag floats with the subchart's `appVersion`, so pinning `Chart.lock` to 5.26.0 effectively pins the image to 3.96.0 until someone bumps the chart. D-08 is therefore already *softer* than it reads — real drift only happens on a deliberate chart bump. Given CE usage limits and the EULA both arrived in specific versions (3.77.0), a floating major-minor is a genuine behaviour-change vector.
   - *Recommendation:* keep D-08 as decided, but state plainly in the chart README that the Nexus version is determined by the subchart's `appVersion` and that `Chart.lock` is the control point.

---

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| helm | Chart authoring, `dependency build`, `lint`, `template` | ✓ | v4.3.0+gbec5b06 | — |
| kubectl | Manifest validation, kind smoke deploy | ✓ | v1.37.0 (kustomize 5.8.1) | — |
| kind | Full chart smoke deploy | ✓ | 0.33.0 | — |
| docker | Local Nexus for script testing; kind backend | ✓ | 28.3.2, daemon running | — |
| jq / yq | JSON/YAML assertions in scripts and tests | ✓ | jq 1.8.2 / yq 4.53.6 | — |
| curl | REST calls | ✓ | 8.7.1 | — |
| yamllint | Pre-commit gate parity | ✓ | installed this session | — |
| checkov | CI gate parity | ✓ (binary) | 3.2.396 | **helm runner does not load** — verify in the pinned CI container |
| gh | PR/merge workflow | ✓ | 2.101.0 | — |
| kubeconform | Manifest schema validation | ✗ | — | `kubectl apply --dry-run=server` against kind |
| `ct` (chart-testing) | Chart lint/install harness | ✗ | — | `helm lint` + `helm template` + kind |
| helm-unittest plugin | Template unit tests | ✗ (only `diff` 3.13.0 installed) | — | `helm template \| yq` assertions in a shell script |

**Missing with no fallback:** none.
**Missing with fallback:** `kubeconform`, `ct`, `helm-unittest` — all substitutable with installed tooling. No installs are required to execute this phase.

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`.

### Test framework

| Property | Value |
|----------|-------|
| Framework | None exists for charts. Repo convention is **standing shell gates** under `scripts/` (`check-workflow-uploads.sh`, `check-detector-parity.sh`, `smoke-scans.sh`) run with `bash script.sh`. |
| Config file | none — Wave 0 creates `repos/security-platform/scripts/check-nexus-chart.sh` |
| Quick run command | `bash scripts/check-nexus-chart.sh` (offline: lint + template + assertions) |
| Full suite command | `bash scripts/check-nexus-chart.sh && bash scripts/nexus-live-smoke.sh` (live: kind or local docker) |
| Phase gate | Offline gate green on every commit; live smoke green once before `/gsd:verify-work` |

Following the established pattern, the offline gate must be written so it **passes at every intermediate commit** (the 17-01 lesson), with per-check distinct exit codes (the 17-02 lesson).

### Phase requirements → test map

| Req | Behavior | Type | Automated command | Exists? |
|-----|----------|------|-------------------|---------|
| NEXUS-03 | Omitting `storageClass` emits no `storageClassName` | unit | `helm template kubernetes/nexus \| yq 'select(.kind=="StatefulSet")\|.spec.volumeClaimTemplates[0].spec \| has("storageClassName")'` → `false` | ❌ Wave 0 |
| NEXUS-03 | Setting `storageClass` emits it verbatim | unit | same with `--set nexus3.persistence.storageClass=test` → `"test"` | ❌ Wave 0 |
| NEXUS-03 | `persistence.enabled` is `true` in wrapper values (Pitfall 5) | unit | `yq '.nexus3.persistence.enabled' kubernetes/nexus/values.yaml` → `true` | ❌ Wave 0 |
| NEXUS-01 | Chart renders exactly one provisioning Job with hook annotations | unit | `helm template … \| yq 'select(.kind=="Job")\|.metadata.annotations'` contains `helm.sh/hook` | ❌ Wave 0 |
| NEXUS-01 | All four repo JSON bodies render with correct `format`/`type` | unit | ConfigMap data keys parse as JSON; formats = `{npm,pypi,docker,helm}`, all `type: proxy` | ❌ Wave 0 |
| NEXUS-01 | Docker body carries both required `docker` and `dockerProxy` objects | unit | `jq -e '.docker and .dockerProxy'` on the rendered body | ❌ Wave 0 |
| NEXUS-01 | Provisioning script is idempotent | **integration** | `docker run sonatype/nexus3:<tag>`, run `provision.sh` **twice**, both exit 0 | ❌ Wave 0 |
| NEXUS-01 | EULA is accepted and a real component downloads (Pitfall 1) | **integration** | after provisioning: `curl -f .../repository/npm-proxy/lodash/-/lodash-4.17.21.tgz` → 200, >100 KB | ❌ Wave 0 |
| NEXUS-01 | Chart installs on a real cluster and the Job succeeds | smoke | `kind create cluster && helm install … --wait`, then `kubectl wait --for=condition=complete job/…` | ❌ Wave 0 |
| — | Chart lints | unit | `helm lint kubernetes/nexus` | ❌ Wave 0 |
| — | Pre-commit passes on the new tree | regression | `pre-commit run --all-files` after the yamllint exclusion | ❌ Wave 0 |

**The two integration tests are the highest-value items in this table.** They need no Kubernetes cluster — just `docker run` — and they are the only checks that would have caught the EULA 403. A green `helm install` would not have.

### Sampling rate

- **Per task commit:** `helm lint` + `helm template`-based assertions (seconds)
- **Per wave merge:** offline gate + the two-pass docker idempotency test (~3 min: ~30s boot + provisioning ×2)
- **Phase gate:** full offline gate + kind install smoke, green before `/gsd:verify-work`

### Wave 0 gaps

- [ ] `repos/security-platform/scripts/check-nexus-chart.sh` — offline gate (lint, template, render assertions); covers NEXUS-01/NEXUS-03
- [ ] `repos/security-platform/scripts/nexus-live-smoke.sh` — docker-based two-pass idempotency + post-EULA artifact download; covers NEXUS-01
- [ ] `.pre-commit-config.yaml` — `exclude: ^kubernetes/.*/templates/` on the `yamllint` hook (**blocks all other work**; measured failure)
- [ ] `.gitignore` — `kubernetes/*/charts/*.tgz`
- [ ] Checkov delta measurement against the pinned `ghcr.io/bridgecrewio/checkov:3.3.17` container (closes A3)

---

## Security Domain

`security_enforcement` is not disabled in config — included.

### Applicable ASVS categories

| ASVS category | Applies | Standard control |
|---------------|---------|------------------|
| V2 Authentication | **yes** | Admin credential from a consumer-supplied Kubernetes Secret via `NEXUS_SECURITY_INITIAL_PASSWORD`. **No default password in the public chart** — `required` the value. |
| V3 Session Management | no | Job uses stateless HTTP Basic per request; no sessions. |
| V4 Access Control | **yes** (partially deferred) | Anonymous access is `enabled: false` by default (verified: anonymous fetch → **401**). NEXUS-02 opens it in Phase 24 — deliberately *not* opened here. |
| V5 Input Validation | **yes** | `remoteUrl` values are consumer-overridable and interpolated into JSON. Render via `toJson` in the template (never string concatenation) so a malicious value cannot break out of the JSON body. Upstream does this correctly: `{{- omit $repo "password" "bearerToken" \| toJson }}`. |
| V6 Cryptography | no | No crypto implemented. TLS terminates at ingress (Phase 25, private overlay). |
| V7 Error Handling & Logging | **yes** | Script must `set -euo pipefail` and never `\|\| true` a provisioning failure (CLAUDE.md §Error Handling). Never echo `NEXUS_PASSWORD`. |
| V10 Malicious Code | **yes** | Community subchart + 3 container images — see §Package Legitimacy Audit. Pin by digest; commit `Chart.lock`. |
| V14 Configuration | **yes** | `strictContentTypeValidation: true` on all four repos; `v1Enabled: false` on Docker; `readOnlyRootFilesystem: true` and dropped capabilities already set upstream. EULA acceptance should be an explicit opt-in value, not an implicit default (Q5 / A9). |

### Known threat patterns for this stack

| Pattern | STRIDE | Standard mitigation |
|---------|--------|---------------------|
| Default/leaked admin credential in a public chart | Spoofing / Info disclosure | `required` a consumer Secret; no default; gitleaks covers the repo |
| Deprecated Groovy scripting API re-enabled (`nexus.scripts.allowCreation=true`) grants arbitrary JVM code execution to any admin-token holder | Elevation of privilege | Keep `config.enabled: false`; do not set the property (Pitfall 2) |
| Typosquatted/hijacked upstream chart or image | Tampering | Digest-pin images; commit `Chart.lock`; §Package Legitimacy Audit |
| Proxy repo pointed at a hostile upstream via values override | Tampering | `toJson` rendering; document that `remoteUrl` is a trust boundary; `strictContentTypeValidation: true` |
| Unauthenticated write to the repository manager | Tampering | Anonymous stays disabled in this phase; Phase 24 must grant **read-only** roles (`nx-anonymous`), never write |
| Docker foreign-layer fetch from arbitrary hosts | Info disclosure / SSRF | `cacheForeignLayers: false` (as in the verified body) |
| Credential exposure in Job logs | Info disclosure | `curl -sS -o /dev/null -w '%{http_code}'`; never `set -x`; password only via `secretKeyRef` env |
| CE usage-limit exhaustion halts new components | Denial of service | Document the 40k component / 100k req-per-day ceiling in the README (Pitfall 7) |

---

## Hand-off to Phase 24 / 25

Measured facts that belong to later phases, recorded now so they are not rediscovered:

- **Anonymous access default is `enabled: false`.** An unauthenticated fetch of `/repository/npm-proxy/lodash` returns **401**; the identical authenticated request returns 200. NEXUS-02 is genuinely unmet by this phase's output. [VERIFIED]
- **After EULA acceptance + anonymous enablement, anonymous tarball download works:** `GET /repository/npm-proxy/lodash/-/lodash-4.17.21.tgz` unauthenticated → **200, 318,961 bytes**. [VERIFIED] So NEXUS-02 is a two-line REST change to the same Job.
- **Active realms are `["NexusAuthenticatingRealm"]` only.** `DockerToken` is available but inactive. With `forceBasicAuth: false` on the Docker proxy, anonymous `docker pull` will require activating `DockerToken` via `PUT /service/rest/v1/security/realms/active`. [VERIFIED: `/security/realms/available` and `/security/realms/active`]
- **The upstream chart already models anonymous + realms** (`config.anonymous.enabled`, `config.realms.values`) and renders `anonymous.json`, `anonymous-user.json`, `nx-metrics-role.json`. Even with `config.enabled: false`, those rendered bodies are a correct reference for Phase 24.
- **Phase 25 (ArgoCD):** `.Release.Revision` is pinned at 1 under `helm template`, so a Revision-suffixed Job name never changes. See Pitfall 3 for the annotations that should be set now.

---

## Sources

### Primary (HIGH confidence — measured in this session)
- Live `sonatype/nexus3:3.96.0-ubi` container: EULA gate (403 → 204 → 200), all four proxy repo create/update status codes, Groovy scripting API 410, realms, anonymous 401, OpenAPI schema extraction from `/service/rest/swagger.json`
- `helm show values` / `helm template` / `helm lint` / `helm dependency build` — `stevehipwell/nexus3` 5.26.0, `sonatype/nexus-repository-manager` 64.2.0, `sonatype/nxrm-ha` 96.1.0
- `helm pull stevehipwell/nexus3 --untar` — direct reading of `templates/statefulset.yaml`, `templates/job-config.yaml`, `templates/configmap-properties.yaml`, `templates/_helpers.tpl`, `scripts/configure.sh`
- `yamllint -d relaxed` against a real Helm template (syntax error, exit 1) vs `values.yaml`/`Chart.yaml` (exit 0)
- `gh api repos/sonatype/nxrm3-helm-repository` (archived) and its README archive notice; `gh api repos/stevehipwell/helm-charts`
- `docker buildx imagetools inspect` — digests for all three images
- Local working copy: `repos/security-platform/.pre-commit-config.yaml`, `.github/workflows/security.yml`, `.github/dependabot.yml`, `scripts/smoke-scans.sh`

### Secondary (MEDIUM–HIGH — official documentation)
- [help.sonatype.com/en/eula-rest-api.html](https://help.sonatype.com/en/eula-rest-api.html) — EULA endpoints, admin privilege requirement, blocking behaviour (corroborated by live testing)
- [help.sonatype.com/en/ce-onboarding.html](https://help.sonatype.com/en/ce-onboarding.html) — Community Edition from 3.77.0, 40,000 components / 100,000 requests per day
- [help.sonatype.com/en/repositories-api.html](https://help.sonatype.com/en/repositories-api.html) — endpoint shape (vague on bodies; superseded by the live OpenAPI spec)
- [docs.renovatebot.com/modules/manager/helmv3/](https://docs.renovatebot.com/modules/manager/helmv3/) — `helmv3` manager matches `Chart.yaml`
- [artifacthub.io](https://artifacthub.io/api/v1/packages/helm/stevehipwell/nexus3) — `verified_publisher: true`, `signed: false`

### Tertiary (LOW — unverified, flagged)
- ArgoCD hook-annotation mapping (A6) — training knowledge only, not tested this session
- Checkov helm-framework behaviour in the pinned CI container (A3) — inferred, not measured

---

## Metadata

**Confidence breakdown:**
- **Standard stack: MEDIUM-HIGH** — every technical property is verified, but the top-level chart choice depends on resolving A1 with the user
- **NEXUS-03 / D-06: HIGH** — rendered and diffed both ways
- **REST API contract: HIGH** — every status code and body measured against a live 3.96.0 CE instance
- **EULA finding: HIGH** — reproduced end-to-end on a fresh container, with the block and the unblock both observed
- **Pitfalls: HIGH** except Pitfall 3 (ArgoCD mapping, A6 = MEDIUM)
- **CI second-order effects: HIGH** for yamllint (measured failure), **MEDIUM** for Checkov (runner would not load locally)
- **Helm proxy default URL: LOW** — open question Q1

**Research date:** 2026-09-17
**Valid until:** ~2026-10-17 (30 days). The `stevehipwell/nexus3` chart releases roughly in step with Nexus; `appVersion` will likely have moved by then, which matters directly because of D-08.

---

*Phase: 23-Nexus Generic Chart*
*Researched: 2026-09-17*
