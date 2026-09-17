# Phase 23: Nexus Generic Chart - Context

**Gathered:** 2026-09-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Public Helm chart that deploys Nexus Repository with npm, PyPI, Docker, and Helm proxy repos configured, using the cluster's default StorageClass unless overridden. Covers NEXUS-01 and NEXUS-03. Anonymous pull (NEXUS-02), workstation install script (NEXUS-04), and live homelab validation (NEXUS-05) are Phase 24/25 — not this phase.

</domain>

<decisions>
## Implementation Decisions

### Chart base
- **D-01 (REVISED post-research 2026-09-17):** No Sonatype-published chart named `nexus3` exists — Sonatype's `nexus-repository-manager` is deprecated/frozen at 3.64.0 with a DB-corruption warning, and `nxrm-ha` requires 3 replicas + external Postgres + Pro license. Wrap the community `stevehipwell/nexus3` chart instead (MIT, ArtifactHub-verified publisher, runs the official Sonatype Nexus image) as a subchart dependency in `Chart.yaml`. Override values rather than reimplementing StatefulSet/PVC/service-account templates.
- **D-09 (NEW post-research 2026-09-17):** Nexus CE since 3.77.0 gates every proxy download behind an unaccepted EULA (`accepted: false` by default) — repos configure fine, metadata fetches 200, but actual package pulls 403 until `POST /service/rest/v1/system/eula` returns 204. This is required for NEXUS-01 to actually work, not optional polish. EULA acceptance is an **explicit opt-in** (`eula.accepted: false` default in `values.yaml`) — the chart must NOT auto-accept a legal agreement on the consumer's behalf. The setup Job only calls the EULA endpoint when `eula.accepted: true` is set.
- **D-10 (NEW post-research 2026-09-17):** `persistence.enabled` on the upstream chart defaults to `false` (emptyDir) — this phase MUST set `persistence.enabled: true` by default (size overridable) so EULA acceptance and the 4 proxy repos survive a pod restart. `persistence.storageClass` still stays omitted per D-06.

### Repo location
- **D-02:** Chart lives in the `OttawaCloudConsulting/security-platform` repo (not this docs-only repo, not a new dedicated repo). This repo's `CLAUDE.md` scope statement will need a note that `security-platform` now also hosts K8s packages, not just the CI workflow.
- **D-03:** Layout: top-level `kubernetes/` directory with well-named subdirectories — this phase creates `kubernetes/nexus/`. Phase 26 (DefectDojo) will follow the same pattern with `kubernetes/defectdojo/`.

### Proxy repo provisioning
- **D-04:** A Helm post-install Job calls the Nexus REST API after the pod is ready to idempotently create the 4 proxy repos (npm, PyPI, Docker, Helm). Not a Groovy/ConfigMap script (deprecated upstream scripting API), not a manual doc step (would violate NEXUS-01's "configured" requirement).
- **D-05 (REVISED post-research 2026-09-17):** The npm, PyPI, and Docker proxy upstream URLs (registry.npmjs.org, pypi.org, registry-1.docker.io) ship as hardcoded defaults in `values.yaml`, consumer-overridable. The Helm proxy upstream has **no default** — Helm Hub is defunct since 2020 and its replacement, Artifact Hub, is a cross-repo search index, not itself a chart repository serving a single `index.yaml` (confirmed via Nexus `helm-proxy` needing one upstream `index.yaml`, which Artifact Hub does not provide). Bitnami's repo (the historical default) is mid-deprecation through 2026 and unsuitable to hardcode. `values.yaml` leaves the Helm proxy remote unset; the chart README documents that the consumer must point it at a repo relevant to their stack (e.g. `ingress-nginx`, `jetstack`, `prometheus-community`).

### Values schema
- **D-06:** `persistence.storageClass` is omitted/left unset in `values.yaml` by default so Kubernetes falls back to the cluster's default StorageClass automatically (satisfies NEXUS-03). Consumer sets a value only to override. Not an explicit `""` — plain omission.
- **D-07:** The chart passes through the full values surface the upstream `nexus3` subchart exposes — storage size, resource requests/limits, image tag, etc. — all overridable, none artificially restricted to a minimal surface for this phase.
- **D-08:** Image tag is NOT pinned by this phase — it tracks whatever the upstream `nexus3` chart's default resolves to (floating, not pinned to a specific Nexus version in `Chart.yaml`). User explicitly chose this over pinning for reproducibility — flag this to the researcher/planner as a point worth surfacing again if it causes drift issues.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & architecture
- `.planning/REQUIREMENTS.md` §Nexus (NEXUS-01 through NEXUS-05) — locked requirement text and Out of Scope table for this milestone
- `.planning/PROJECT.md` — Key Decision: "v3.0 K8s packages: generic-first, not private-then-strip" (public chart is source of truth; private ArgoCD overlay holds only env values + Application manifest, never in this chart)
- `.planning/ROADMAP.md` — Phase 23 boundary line and v3.0 milestone phase sequence (23-29)

### Repo/host
- `OttawaCloudConsulting/security-platform` — target repo for `kubernetes/nexus/` (this repo, `security_solution`, stays docs-only per its own `CLAUDE.md`)

No further external specs/ADRs were referenced during discussion.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None in this repo (docs-only). The chart is new code living in `security-platform`, which the researcher should inspect directly for existing `kubernetes/` conventions (none expected yet — this is the first phase to add one).

### Established Patterns
- `security-platform` already SHA-pins GitHub Actions and uses Dependabot to keep pins current (Phase 14) — researcher should check whether an equivalent "keep the nexus3 subchart version current" mechanism (e.g., Renovate/Dependabot Helm chart updates) is expected, given D-08's floating-tag choice.

### Integration Points
- Private ArgoCD overlay repo (not this milestone's phase) will reference whatever chart/values structure this phase produces — keep `values.yaml` overrides clean and documented since Phase 25 consumes them live.

</code_context>

<specifics>
## Specific Ideas

- User specifically wants a `kubernetes/` top-level directory with "well-named sub-directories" — this is a naming/organization convention the user cares about, apply it consistently across Phase 23 and Phase 26.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 23-Nexus Generic Chart*
*Context gathered: 2026-09-17*
