# Phase 26: DefectDojo Generic Chart - Context

**Gathered:** 2026-09-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver `kubernetes/defectdojo/` in `OttawaCloudConsulting/security-platform`: a public, generic Helm chart that deploys DefectDojo with external ingress and cert-manager-issued TLS (DDOJO-01). It must be deployable to any Kubernetes cluster; every environment-specific value (hostname, ClusterIssuer name, StorageClass override, IngressClass) is consumer-supplied and lives only in a private overlay, never in the public package.

Proven in this phase: an offline chart gate plus a live kind smoke that exercises the ingress + cert-manager TLS path once.

NOT in this phase:
- CI scan jobs importing findings into DefectDojo (Phase 27, DDOJO-02), including pre-creating Products, Engagements or API tokens for CI.
- Deduplication rules and triage workflow (Phase 28, DDOJO-03/04).
- Deploying to the homelab via the private ArgoCD overlay, and any homelab ingress-controller or ClusterIssuer work (Phase 29, DDOJO-05).
- Backup automation, NetworkPolicy, monitoring (hardening bucket, REQUIREMENTS.md Out of Scope).

</domain>

<decisions>
## Implementation Decisions

### Chart base and version pin
- **D-01:** Wrap the official DefectDojo Helm chart (from the `DefectDojo/django-DefectDojo` repository, published on its `helm-charts` branch at `https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts`) as a `Chart.yaml` dependency and override it through values. Same shape as Phase 23 D-01 (Nexus wraps `stevehipwell/nexus3`). Do not author DefectDojo's Deployments/Celery/initializer templates, and do not vendor a copy.
- **D-02:** Layout follows Phase 23 D-02/D-03: `kubernetes/defectdojo/` in `security-platform`, next to `kubernetes/nexus/`.
- **D-03:** **Pin both** the subchart version (Chart.yaml + Chart.lock) **and** the DefectDojo image tag/appVersion to one specific DefectDojo release. This deliberately departs from Nexus D-08 (floating image): DefectDojo runs Django DB migrations on upgrade, so a floating tag could migrate the findings schema unannounced. Bumps go through a deliberate update (Dependabot or the manual update process).
- **D-04:** Wrapper `values.yaml` is **thin with a small footprint**: override only what DDOJO-01 and generic-first require (ingress, TLS, secrets, persistence), plus single-replica and modest resource requests so it fits a small cluster. Everything else passes through to the upstream chart untouched (Phase 23 D-07 carried forward).

### Database and Valkey sourcing
- **D-05:** Upstream's bundled PostgreSQL and Valkey subcharts are **enabled by default** so one install brings up a working stack. Consumers can disable them and point at an external PostgreSQL / Valkey (host + existingSecret); the chart README documents that override recipe.
- **D-06:** No backup provision and no backup callout beyond the existing REQUIREMENTS.md Out-of-Scope row. The operator explicitly chose to accept this silently — do not add README/ADR risk sections about backups, and do not add a pg_dump CronJob.
- **D-07:** Take upstream's Postgres/Valkey subchart images **as-is** — no image-repository override, even if they are Bitnami-sourced. The operator chose this over a verify-then-override approach. Researcher should still record which images the pinned subcharts pull (informational, feeds the version pin in D-03); if they fail to pull during the kind smoke, that is a failure to report, not a silent swap.
- **D-08:** Bundled PostgreSQL has **persistence enabled** (PVC) so findings survive a pod restart (same reasoning as Nexus D-10). Valkey stays **ephemeral** (it is only the Celery broker; loss = in-flight tasks only). StorageClass is left unset so the cluster default applies (Phase 23 D-06 carried forward — plain omission, not `""`).

### Ingress and TLS shape
- **D-09:** Ingress is **on by default** (DDOJO-01 says "external ingress"). The host defaults to a **placeholder** (e.g. `defectdojo.example.local` — exact string Claude's discretion) rather than a `required` value. README tells consumers to override it.
- **D-10:** TLS is **on by default**. cert-manager issues the certificate through the **ingress annotation** (`cert-manager.io/cluster-issuer`, or `cert-manager.io/issuer`) — cert-manager's ingress-shim creates the Certificate. No explicit `Certificate` template in the chart.
- **D-11:** The issuer name has **no default and is required** when TLS is on: rendering with TLS on and no issuer name must fail fast with a clear `required` message. Consequence (accepted): a bare `helm install` with no values fails until an issuer is supplied; the placeholder host only saves one flag. ClusterIssuer names live only in the private overlay (PROJECT.md generic-first decision).
- **D-12:** `ingressClassName` is **left unset** by default so the cluster's default IngressClass applies (same pattern as StorageClass). The overlay sets it where needed.

### Secrets and validation depth
- **D-13:** Secrets (Django secret key, credential AES key, admin password, PostgreSQL and Valkey passwords) default to **existingSecret**: the chart expects pre-created Secrets (the homelab will supply them as SealedSecrets at sync-wave `-1`, per ADR-022 decision 3). Upstream's `createSecret` / `createPostgresqlSecret` / `createValkeySecret` generation is available as an **opt-in** for quick local tries. Reason: chart-generated secrets risk regenerating on ArgoCD sync / helm upgrade, which would break the AES-encrypted stored credentials.
- **D-14:** Validation for this phase = **offline gate + kind TLS smoke**:
  - Offline gate script (Phase 23 `check-nexus-chart.sh` pattern): lint, template renders, required-value failure when TLS is on with no issuer, defaults assertions (ingress on, TLS on, ingressClassName unset, StorageClass unset, Postgres persistence on, existingSecret default), Checkov measured.
  - Live kind smoke (Phase 23 `nexus-live-smoke.sh` pattern): ingress-nginx + cert-manager with a self-signed ClusterIssuer, pre-created secrets, install, Certificate `Ready`, HTTPS request to the DefectDojo login page returns 200.
- **D-15:** The kind smoke covers **first install only** — no second `helm upgrade` idempotency pass. Resync/second-sync safety is proven live in Phase 29 (as Phase 25 did for Nexus).

### Claude's Discretion
- Script names (e.g. `scripts/check-defectdojo-chart.sh`, `scripts/defectdojo-live-smoke.sh`), placeholder host string, README structure, exact small-footprint resource numbers.
- Whether to use `cluster-issuer` vs `issuer` annotation key selection (e.g. an `issuerKind` value) — keep it minimal.
- ADR for this phase (ADR-023 expected, following ADR-020/021/022 pattern) and its ADR index row.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirement and project constraints
- `.planning/REQUIREMENTS.md` — DDOJO-01 text; Out of Scope table (backup automation, NetworkPolicy, monitoring deferred)
- `.planning/PROJECT.md` — v3.0 milestone goal and the generic-first Key Decision (environment values only in the private overlay)
- `.planning/ROADMAP.md` — Phase 26 goal; Phases 27–29 boundaries (import, dedup/triage, homelab live)

### Chart-shape precedents (Nexus)
- `.planning/phases/23-nexus-generic-chart/23-CONTEXT.md` — D-01 wrap-don't-reimplement, D-02/D-03 repo location and `kubernetes/<service>/` layout, D-06 StorageClass omission, D-07 values passthrough, D-08 floating tag (deliberately NOT followed here, see D-03), D-10 persistence on
- `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md` — Nexus chart base ADR; opt-in-not-auto-accept stance
- `docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md` — off-by-default stance for anything that opens access
- `docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md` — decision 3 (SealedSecret at sync-wave -1, informs D-13); decision 4 (homelab had no IngressClass/Gateway CRDs and no TLS at Phase 25 time)
- `docs/adr/README.md` — ADR index (new ADR row goes here)

### Code in security-platform (local clone at `repos/security-platform/`)
- `repos/security-platform/kubernetes/nexus/Chart.yaml`, `values.yaml`, `README.md`, `templates/_helpers.tpl` — wrapper chart layout to mirror
- `repos/security-platform/scripts/check-nexus-chart.sh` — offline chart gate pattern (D-14)
- `repos/security-platform/scripts/nexus-live-smoke.sh` — kind live smoke pattern (D-14)

### Upstream
- DefectDojo Helm chart: `https://github.com/DefectDojo/django-DefectDojo/tree/master/helm/defectdojo` (README + values.yaml + Chart.yaml dependencies); repo URL `https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts`. Documents `host`, `django.ingress.*` (`enabled`, `activateTLS`, `secretName`, annotations), `createSecret` / `createPostgresqlSecret` / `createValkeySecret`, external PostgreSQL recipe, and notes the generated secret is kept across installs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `kubernetes/nexus/` wrapper chart: dependency-on-community-chart structure, `_helpers.tpl`, heavily commented `values.yaml` style (comments explain WHY each default is set).
- `scripts/check-nexus-chart.sh`: offline helm lint/template/assertion gate to clone for DefectDojo.
- `scripts/nexus-live-smoke.sh`: kind install + live assertions harness to clone and extend with ingress-nginx and cert-manager.

### Established Patterns
- Wrap upstream chart, override via values, never reimplement upstream templates.
- Omit StorageClass (and now ingressClassName) so cluster defaults apply.
- Nothing that opens access or accepts terms on the consumer's behalf by default; credentials supplied as pre-created Secrets in the overlay.
- Each phase ships an ADR plus an ADR index row, and the chart README carries the measured limitations.

### Integration Points
- Phase 27 will point `security-platform` CI jobs at this chart's DefectDojo API — the ingress hostname and TLS set up here become that endpoint.
- Phase 29 will consume this chart from the private ArgoCD overlay (two-source Application + SealedSecrets), exactly as Phase 25 consumed `kubernetes/nexus/`.

</code_context>

<specifics>
## Specific Ideas

- **Open question for the researcher (feeds Phase 29, not blocking here):** ADR-022 decision 4 recorded no IngressClass, no Gateway API CRDs and no TLS on the homelab at Phase 25 time, but the local `~/git-repos/OCC-github/kubernetes_stack/` config repos contain an `ingressClassName: internal-nginx` and several `ClusterIssuer` manifests. Either that config is planned/unapplied or it landed after 25-RESEARCH. Record which repo/directory these come from; the live `kubectl get ingressclass,clusterissuer` check belongs to Phase 29.
- Record which images the pinned upstream Postgres/Valkey subcharts pull (D-07), informational.

</specifics>

<deferred>
## Deferred Ideas

- Upgrade/resync idempotency check (second `helm upgrade` pass) — deferred to Phase 29's live second sync.
- Pre-creating DefectDojo Product/Engagement/API token for CI import — Phase 27.
- Homelab ingress controller / ClusterIssuer provisioning — Phase 29 (or outside this milestone if absent).
- PostgreSQL backup automation — hardening bucket (already Out of Scope in REQUIREMENTS.md).
- Gateway API (HTTPRoute) support as an alternative to Ingress — not discussed; future if needed.

</deferred>

---

*Phase: 26-defectdojo-generic-chart*
*Context gathered: 2026-09-24*
