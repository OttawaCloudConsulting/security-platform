# Phase 26: DefectDojo Generic Chart - Research

**Researched:** 2026-09-24
**Domain:** Helm wrapper chart around the official DefectDojo chart; cert-manager ingress-shim TLS; offline Helm gate plus a kind live smoke
**Confidence:** HIGH. The core shape was prototyped and installed live on kind during this session. Measured values are marked `[VERIFIED: measured ...]`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Chart base and version pin
- **D-01:** Wrap the official DefectDojo Helm chart (from the `DefectDojo/django-DefectDojo` repository, published on its `helm-charts` branch at `https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts`) as a `Chart.yaml` dependency and override it through values. Same shape as Phase 23 D-01 (Nexus wraps `stevehipwell/nexus3`). Do not author DefectDojo's Deployments/Celery/initializer templates, and do not vendor a copy.
- **D-02:** Layout follows Phase 23 D-02/D-03: `kubernetes/defectdojo/` in `security-platform`, next to `kubernetes/nexus/`.
- **D-03:** **Pin both** the subchart version (Chart.yaml + Chart.lock) **and** the DefectDojo image tag/appVersion to one specific DefectDojo release. This deliberately departs from Nexus D-08 (floating image): DefectDojo runs Django DB migrations on upgrade, so a floating tag could migrate the findings schema unannounced. Bumps go through a deliberate update (Dependabot or the manual update process).
- **D-04:** Wrapper `values.yaml` is **thin with a small footprint**: override only what DDOJO-01 and generic-first require (ingress, TLS, secrets, persistence), plus single-replica and modest resource requests so it fits a small cluster. Everything else passes through to the upstream chart untouched (Phase 23 D-07 carried forward).

#### Database and Valkey sourcing
- **D-05:** Upstream's bundled PostgreSQL and Valkey subcharts are **enabled by default** so one install brings up a working stack. Consumers can disable them and point at an external PostgreSQL / Valkey (host + existingSecret); the chart README documents that override recipe.
- **D-06:** No backup provision and no backup callout beyond the existing REQUIREMENTS.md Out-of-Scope row. The operator explicitly chose to accept this silently — do not add README/ADR risk sections about backups, and do not add a pg_dump CronJob.
- **D-07:** Take upstream's Postgres/Valkey subchart images **as-is** — no image-repository override, even if they are Bitnami-sourced. The operator chose this over a verify-then-override approach. Researcher should still record which images the pinned subcharts pull (informational, feeds the version pin in D-03); if they fail to pull during the kind smoke, that is a failure to report, not a silent swap.
- **D-08:** Bundled PostgreSQL has **persistence enabled** (PVC) so findings survive a pod restart (same reasoning as Nexus D-10). Valkey stays **ephemeral** (it is only the Celery broker; loss = in-flight tasks only). StorageClass is left unset so the cluster default applies (Phase 23 D-06 carried forward — plain omission, not `""`).

#### Ingress and TLS shape
- **D-09:** Ingress is **on by default** (DDOJO-01 says "external ingress"). The host defaults to a **placeholder** (e.g. `defectdojo.example.local` — exact string Claude's discretion) rather than a `required` value. README tells consumers to override it.
- **D-10:** TLS is **on by default**. cert-manager issues the certificate through the **ingress annotation** (`cert-manager.io/cluster-issuer`, or `cert-manager.io/issuer`) — cert-manager's ingress-shim creates the Certificate. No explicit `Certificate` template in the chart.
- **D-11:** The issuer name has **no default and is required** when TLS is on: rendering with TLS on and no issuer name must fail fast with a clear `required` message. Consequence (accepted): a bare `helm install` with no values fails until an issuer is supplied; the placeholder host only saves one flag. ClusterIssuer names live only in the private overlay (PROJECT.md generic-first decision).
- **D-12:** `ingressClassName` is **left unset** by default so the cluster's default IngressClass applies (same pattern as StorageClass). The overlay sets it where needed.

#### Secrets and validation depth
- **D-13:** Secrets (Django secret key, credential AES key, admin password, PostgreSQL and Valkey passwords) default to **existingSecret**: the chart expects pre-created Secrets (the homelab will supply them as SealedSecrets at sync-wave `-1`, per ADR-022 decision 3). Upstream's `createSecret` / `createPostgresqlSecret` / `createValkeySecret` generation is available as an **opt-in** for quick local tries. Reason: chart-generated secrets risk regenerating on ArgoCD sync / helm upgrade, which would break the AES-encrypted stored credentials.
- **D-14:** Validation for this phase = **offline gate + kind TLS smoke**:
  - Offline gate script (Phase 23 `check-nexus-chart.sh` pattern): lint, template renders, required-value failure when TLS is on with no issuer, defaults assertions (ingress on, TLS on, ingressClassName unset, StorageClass unset, Postgres persistence on, existingSecret default), Checkov measured.
  - Live kind smoke (Phase 23 `nexus-live-smoke.sh` pattern): ingress-nginx + cert-manager with a self-signed ClusterIssuer, pre-created secrets, install, Certificate `Ready`, HTTPS request to the DefectDojo login page returns 200.
- **D-15:** The kind smoke covers **first install only** — no second `helm upgrade` idempotency pass. Resync/second-sync safety is proven live in Phase 29 (as Phase 25 did for Nexus).

### Claude's Discretion
- Script names (e.g. `scripts/check-defectdojo-chart.sh`, `scripts/defectdojo-live-smoke.sh`), placeholder host string, README structure, exact small-footprint resource numbers.
- Whether to use `cluster-issuer` vs `issuer` annotation key selection (e.g. an `issuerKind` value) — keep it minimal.
- ADR for this phase (ADR-023 expected, following ADR-020/021/022 pattern) and its ADR index row.

### Deferred Ideas (OUT OF SCOPE)
- Upgrade/resync idempotency check (second `helm upgrade` pass) — deferred to Phase 29's live second sync.
- Pre-creating DefectDojo Product/Engagement/API token for CI import — Phase 27.
- Homelab ingress controller / ClusterIssuer provisioning — Phase 29 (or outside this milestone if absent).
- PostgreSQL backup automation — hardening bucket (already Out of Scope in REQUIREMENTS.md).
- Gateway API (HTTPRoute) support as an alternative to Ingress — not discussed; future if needed.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DDOJO-01 | Public Helm chart deploys DefectDojo with external ingress and cert-manager-issued TLS | Upstream chart `defectdojo` 1.9.53 / app 3.3.200 already renders an `Ingress` with `spec.tls`, and the TLS block is on by default. Ingress annotations pass through verbatim, so cert-manager ingress-shim works with no template changes. Measured on kind: a Certificate reached `Ready`, curl with `--cacert` verified the served certificate for the host, the login page returned 200, and an admin login POST returned 302 followed by a dashboard 200. Details are in §Architecture Patterns and §Code Examples. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- This is a documentation repository. The chart and its scripts are authored in `OttawaCloudConsulting/security-platform`, whose local clone is `repos/security-platform/`. This repository gets the ADR, the ADR index row and possibly a `CLAUDE.md` scope line. Phase 23-07 edited `CLAUDE.md` for the same reason.
- ADRs in `docs/adr/` are append-only. Add ADR-023 as a new file plus one row in `docs/adr/README.md`. Do not edit ADR-006, ADR-009 or ADR-022, even though each one is relevant here.
- Never set the executable bit on scripts. Invoke them as `bash scripts/<name>.sh` (`.claude/rules/defensive-protocol-v2-anti-slop.md`).
- On failure: stop, report, then wait. No silent fallbacks such as `|| true` on assertions. Both Nexus scripts already follow this.
- Irreversible actions need operator confirmation. The Phase 23-08 precedent is that merging to `security-platform` `main` is an explicit, non-autonomous operator approval gate.
- The **kube context is the homelab**: `kubectl config current-context` returns `admin@occ-new` [VERIFIED: measured]. Every kubectl and helm call in the smoke MUST pin `--context`/`--kube-context`. Also note that Helm 4's `helm template` reads the context namespace: an unpinned render emitted `namespace: argocd` [VERIFIED: measured].

## Summary

The upstream chart already does most of what DDOJO-01 needs. `defectdojo` 1.9.53 (appVersion 3.3.200, published 2026-09-21) defaults to `django.ingress.enabled: true`, `activateTLS: true`, `secretName: defectdojo-tls` and `ingressClassName: ""`, and its template guards the class with `if`, so an unset class is omitted. It also defaults all three `create*Secret` flags to `false` and enables PostgreSQL persistence. The upstream `Ingress` template copies `django.ingress.annotations` verbatim, so a consumer-supplied `cert-manager.io/cluster-issuer` annotation is all ingress-shim needs [VERIFIED: tarball read + render]. The wrapper therefore restates very little:
- a placeholder `host`/`siteUrl`
- pinned image tags
- Valkey persistence off (upstream default is **on**)
- the uwsgi small-footprint settings (see below)
- one `fail` guard template for the issuer.

Two findings change what the planner must write.
1. **Upstream defaults do not survive a real login on kind.** Measured: uwsgi at 4 processes was OOMKilled at its 512Mi limit, first on startup. The likely cause, inferred rather than proven, is `uwsgi` sizing its fd table from the container's `RLIMIT_NOFILE` (1073741816 on Docker Desktop kind). After `maxFd: 102400` the pod started, but the **first login POST** OOMKilled it again. With `processes: 2` plus `maxFd: 102400`, idle memory was 286 MiB and peak after login was 388–430 MiB. A smoke that only GETs `/login` passed while the app was one POST away from crashing, so the smoke must do a real login. Celery `Running` is equally uninformative, because upstream ships no celery probes, so the smoke also needs a broker round-trip (`celery inspect ping`).
2. **D-11 cannot use Helm's `required` literally.** The issuer name lives inside the subchart's annotation map, and a parent chart cannot inject into subchart values. The mechanism is a wrapper template that calls `fail` when TLS is on and neither issuer annotation is set. This was prototyped and works.

Wrapper and subchart are both named `defectdojo`, and Helm named templates are global. A wrapper `_helpers.tpl` defining `defectdojo.fullname` **silently replaced the subchart's**: the Ingress and ConfigMap were renamed to the wrapper's output [VERIFIED: measured]. The wrapper must not define any `defectdojo.*` template names.

**Primary recommendation:** Build `kubernetes/defectdojo/` as a values-only wrapper around `defectdojo` 1.9.53 with a single `templates/validate-tls.yaml` `fail` guard. Pin the image tags to `3.3.200`, set uwsgi `processes: 2` and `maxFd: 102400`, and turn off Valkey persistence. Clone the Nexus gate and smoke. The smoke's success signal is Deployment readiness, a verified-TLS GET that returns 200, and an admin login POST that returns 302. It must not wait on the initializer Job, which deletes itself 60 s after it completes.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| DefectDojo workloads (uwsgi/nginx, celery, initializer) | Upstream subchart `defectdojo` 1.9.53 | — | D-01: wrap, never author |
| PostgreSQL / Valkey | Upstream nested subcharts (DefectDojo-mirrored Bitnami postgresql 16.7.27; cloudpirates valkey 0.25.8) | External DB via consumer override (D-05) | D-05, D-07 |
| Ingress object | Upstream `django-ingress.yaml` | — | Already renders `spec.tls` and passes annotations through verbatim |
| TLS certificate issuance | cert-manager ingress-shim (cluster add-on) | Consumer's ClusterIssuer/Issuer | D-10: no `Certificate` template in the chart |
| Issuer-required enforcement | Wrapper `templates/validate-tls.yaml` (`fail`) | — | Only the wrapper can assert across the subchart's values |
| Secrets | Consumer (pre-created / SealedSecret) | Upstream `create*Secret` opt-in | D-13 |
| Environment values (host, issuer, class, StorageClass) | Consumer private overlay | — | Generic-first (PROJECT.md) |
| Offline correctness | `scripts/check-defectdojo-chart.sh` | — | D-14 |
| Live TLS proof | `scripts/defectdojo-live-smoke.sh` on kind + cert-manager + ingress-nginx | — | D-14 |

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `defectdojo` Helm chart | **1.9.53** (appVersion **3.3.200**, created 2026-09-21T16:45Z, index digest `0393332d77412d2a76921f418faf933e9739088ddbf207b2a4b94867daa0657d`) | The application | Official chart, D-01 [VERIFIED: helm-charts index.yaml + tarball sha256 match] |
| Repository URL | `https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts` | Chart source | `helm dependency build` succeeded against it [VERIFIED: measured]. Tarball URLs point to GitHub release assets `.../releases/download/3.3.200/defectdojo-1.9.53.tgz` |
| cert-manager (smoke only) | **v1.21.2** (2026-09-11). v1.20.4 is a patch on the older line | ingress-shim TLS on kind | [VERIFIED: GitHub releases API] Static manifest `https://github.com/cert-manager/cert-manager/releases/download/v1.21.2/cert-manager.yaml` |
| ingress-nginx (smoke only) | **controller-v1.15.1**, the final release | Ingress controller on kind | D-14 locks it. The **project was archived** in March 2026 [VERIFIED: GitHub API `archived: true`; CITED: kubernetes.io/blog/2025/11/11/ingress-nginx-retirement]. It is acceptable for a throwaway kind harness. The README must not recommend it to consumers. Manifest `https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml` |

### Supporting
None. This wrapper has no wrapper-owned value tree: every key lives under `defectdojo:`, and the only template is the guard.

### Images the pinned chart pulls (D-07, informational)
| Image | Source | arm64? |
|-------|--------|--------|
| `defectdojo/defectdojo-django:3.3.200` (index `sha256:1cee5281e176128aa141dd9a506427af4924550f3e771272e85f42321c37c1ed`) | uwsgi, celery worker/beat, initializer, db-migration-checker | yes |
| `defectdojo/defectdojo-nginx:3.3.200` (index `sha256:825d9ad8abaf7d2013d82a85b5562d096006727ef32cfa8940996efa70c6e5f9`) | nginx sidecar | yes |
| `us-docker.pkg.dev/os-public-container-registry/defectdojo/bitnami/postgresql:17.6.0-debian-12-r4` (`sha256:926356130b77d5742d8ce605b258d35db9b62f2f8fd1601f9dbaef0c8a710a8d`) | PostgreSQL 17.6. **DefectDojo's own mirror** of the Bitnami image, not `docker.io/bitnami`, so the Bitnami catalog deprecation does not bite | yes |
| `docker.io/valkey/valkey:9.1.0-alpine3.23@sha256:c9b77919…9e02` | Valkey 9.1.0, digest-pinned upstream | yes |

All four pulled and ran on kind (arm64) this session [VERIFIED: measured].

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `fail` guard on the annotation map | A wrapper value `tls.clusterIssuer` + `required` | **Does not work.** A parent cannot write the value into the subchart's `django.ingress.annotations`, because Helm values are static and upstream does not `tpl` annotations. |
| `fail` guard | Disable upstream ingress and render the wrapper's own Ingress | Re-implements an upstream template, which contradicts D-01. Also `DD_SESSION_COOKIE_SECURE` keys off `django.ingress.activateTLS`, so the two would drift. |
| Tag pin `3.3.200` | Digest pin (`images.*.image.digest`) | The ADR-004 spirit favours digests. But `images.image` replaces `:tag` with `@digest`, so the rendered ref loses its readable version, and it doubles the bump work. Recommended: tag pin plus an offline tag==appVersion drift check. Digest is discretionary [ASSUMED operator preference]. |

**Installation (inside `repos/security-platform`):**
```bash
helm dependency build kubernetes/defectdojo   # needs network; charts/*.tgz is already gitignored
```

## Package Legitimacy Audit

No npm, PyPI or cargo packages are installed in this phase, so slopcheck does not apply. The only external artifacts are a Helm chart and container images, verified as follows:

| Artifact | Registry | Age | Source Repo | Check | Disposition |
|----------|----------|-----|-------------|-------|-------------|
| `defectdojo` chart 1.9.53 | GitHub raw `helm-charts` branch | 3 days (weekly release cadence since at least 1.9.39 on 2026-07-27) | github.com/DefectDojo/django-DefectDojo (OWASP project) | index digest == downloaded tarball sha256 | Approved |
| Nested `postgresql` 16.7.27, `valkey` 0.25.8 | Vendored inside the 1.9.53 tarball (`charts/`) | — | DefectDojo OCI mirror; cloudpirates | Read from tarball `Chart.lock` | Approved (D-07 as-is) |
| cert-manager v1.21.2 | GitHub release | 13 days | github.com/cert-manager/cert-manager | Official release asset | Approved (smoke only) |
| ingress-nginx controller-v1.15.1 | GitHub tag / registry.k8s.io, digest-pinned in the manifest | 6 months, archived | github.com/kubernetes/ingress-nginx | Official final release | Approved for smoke only. Archived: no security fixes. |

**Packages removed:** none. **Flagged:** none.

## Architecture Patterns

### System Architecture Diagram

```
 consumer overlay values ──┐
 (host, siteUrl, issuer    │
  annotation, class, SC)   ▼
                    ┌──────────────────────────────┐
 helm template ───▶ │ wrapper kubernetes/defectdojo │
                    │  templates/validate-tls.yaml  │──fail──▶ "no cert-manager issuer" (render aborts)
                    │  values.yaml (defectdojo.*)   │
                    └──────────────┬───────────────┘
                                   │ values under `defectdojo:` pass through
                                   ▼
                    ┌──────────────────────────────┐
                    │ subchart defectdojo 1.9.53   │── Ingress (tls + annotations verbatim)
                    │  ConfigMap, Deployments,     │── Deployment django (uwsgi+nginx, init: db-migration-checker)
                    │  initializer Job (ttl 60s)   │── celery worker / beat
                    │  ├─ postgresql 16.7.27 (PVC) │── StatefulSet + PVC (no storageClassName)
                    │  └─ valkey 0.25.8 (emptyDir) │── StatefulSet, no VCT
                    └──────────────┬───────────────┘
                                   │ kubectl apply (cluster)
        ┌──────────────────────────┼──────────────────────────────┐
        ▼                          ▼                              ▼
 pre-created Secrets       cert-manager ingress-shim        IngressClass (default)
 <fullname>, *-postgresql-  sees annotation → Certificate    admission sets
 specific, *-valkey-specific  named tls.secretName → Secret  spec.ingressClassName
        │                          │                              │
        └──────────────▶ pods start │ ◀── TLS Secret ──────────────┘
                                   ▼
          client ──HTTPS(SNI host)──▶ ingress controller ──HTTP──▶ django Service :http ──▶ nginx ──uwsgi sock──▶ Django
```

### Recommended Project Structure (in `repos/security-platform`)
```
kubernetes/defectdojo/
├── Chart.yaml              # name: defectdojo, appVersion "3.3.200", dependency defectdojo 1.9.53
├── Chart.lock              # committed; charts/*.tgz stays gitignored (existing .gitignore rule)
├── .helmignore             # mirror nexus
├── values.yaml             # everything under `defectdojo:`; helm-docs `# --` comment style
├── README.md               # mirror nexus README section order
└── templates/
    └── validate-tls.yaml   # the only wrapper template; renders nothing on success
scripts/
├── check-defectdojo-chart.sh   # offline gate (clone check-nexus-chart.sh)
└── defectdojo-live-smoke.sh    # kind smoke (clone section 7 of nexus-live-smoke.sh)
```
There is **no `_helpers.tpl`**. If a helper is ever needed, prefix it (for example `ddwrap.*`), and never use `defectdojo.*` (Pitfall 1).

No repo-plumbing edits are needed. `.gitignore` already has `kubernetes/*/charts/*.tgz`, and `.pre-commit-config.yaml` yamllint already excludes `^kubernetes/.*/templates/` [VERIFIED: file read]. The repo `README.md` line 41 says "DefectDojo planned", so update it to point at the chart.

### Pattern 1: Values-only wrapper with a fail guard (D-10/D-11)
**What:** The consumer sets the issuer as the annotation itself: `defectdojo.django.ingress.annotations."cert-manager.io/cluster-issuer"`, or `"cert-manager.io/issuer"` for a namespaced or external issuer. That removes the need for any `issuerKind` value, because the annotation key *is* the kind selector. The guard fails the render when:
- ingress and TLS are on and neither key has a non-empty value, or
- both keys are set, or
- `secretName` is empty. ingress-shim names the Certificate after `tls.secretName`, and upstream omits `secretName` when it is empty.

**Example (prototyped; the bare render failed with exit 1 and this message [VERIFIED: measured]):**
```yaml
{{- /* templates/validate-tls.yaml — renders nothing; aborts the render on a misconfigured TLS path */ -}}
{{- $ing := .Values.defectdojo.django.ingress -}}
{{- if and $ing.enabled $ing.activateTLS -}}
{{-   $a := $ing.annotations | default dict -}}
{{-   $ci := get $a "cert-manager.io/cluster-issuer" -}}
{{-   $ns := get $a "cert-manager.io/issuer" -}}
{{-   if not (or $ci $ns) -}}
{{-     fail "defectdojo.django.ingress.activateTLS is true but no cert-manager issuer is set: set defectdojo.django.ingress.annotations.\"cert-manager.io/cluster-issuer\" (or \"cert-manager.io/issuer\"), or set defectdojo.django.ingress.activateTLS=false" -}}
{{-   end -}}
{{-   if and $ci $ns -}}
{{-     fail "set only one of cert-manager.io/cluster-issuer and cert-manager.io/issuer" -}}
{{-   end -}}
{{-   if not $ing.secretName -}}
{{-     fail "defectdojo.django.ingress.secretName must be non-empty when TLS is on (cert-manager ingress-shim names the Certificate after it)" -}}
{{-   end -}}
{{- end -}}
```
`--set` form: `--set 'defectdojo.django.ingress.annotations.cert-manager\.io/cluster-issuer=NAME'` [VERIFIED: measured]. In overlay YAML it is simply a quoted key.

### Pattern 2: Recommended wrapper `values.yaml` content (the whole override surface)
```yaml
defectdojo:
  host: defectdojo.example.com            # placeholder; README: override
  siteUrl: https://defectdojo.example.com # MUST move with host (DD_SITE_URL; upstream default is http://localhost:8080)
  images:
    django: {image: {tag: "3.3.200"}}     # D-03; gate asserts == subchart appVersion
    nginx:  {image: {tag: "3.3.200"}}
  django:
    ingress:
      annotations: {}                      # consumer adds cert-manager.io/cluster-issuer here
      # enabled/activateTLS/secretName/ingressClassName: upstream defaults already match
      # D-09/D-10/D-12. Restating is optional. If restated, NEVER write ingressClassName: null
      # (the schema types it `string`); omit it or leave "".
    uwsgi:
      appSettings:
        processes: 2                       # measured: 4 processes OOMKilled at 512Mi on first login
        maxFd: 102400                      # measured: 0 (auto) sizes from RLIMIT_NOFILE=1073741816 → OOM on start
      resources:                           # small-footprint, measured-headroom numbers
        requests: {cpu: 100m, memory: 384Mi}
        limits:   {cpu: 2000m, memory: 1Gi}
  valkey:
    persistence:
      enabled: false                       # D-08: upstream valkey 0.25.8 defaults this to true (8Gi PVC)
  # createSecret / createPostgresqlSecret / createValkeySecret: upstream defaults are false (D-13).
  # postgresql.primary.persistence.enabled: upstream default is true; storageClass "" → omitted (D-08).
```
Upstream defaults are already single-replica: django 1, worker 1, beat 1 (schema max 1), autoscaling off. Other upstream resource defaults fit the measured usage: celery ~180 MiB against a 512Mi/256Mi limit, Postgres 127 MiB against Bitnami preset `nano` (limit 192Mi, **CPU 150m**), Valkey 15 MiB. The uwsgi numbers above are measurements plus headroom; the planner may tune them, but not below a 512Mi limit with 2 processes [VERIFIED: measured, cgroup `memory.current`/`memory.peak`].

### Pattern 3: Secret contract with `createSecret: false` (D-13)
[VERIFIED: template read + live install]
| Secret name | Keys | What happens if it is absent |
|-------------|------|------------------------|
| `<subchart fullname>`, which is **`defectdojo` when the release name contains "defectdojo"** and `<release>-defectdojo` otherwise | `DD_ADMIN_PASSWORD`, `DD_SECRET_KEY`, `DD_CREDENTIAL_AES_256_KEY`, `METRICS_HTTP_AUTH_PASSWORD` | The nginx container's `METRICS_HTTP_AUTH_PASSWORD` has no `optional: true`, so the pod gets `CreateContainerConfigError`. `DD_SECRET_KEY`/`DD_CREDENTIAL_AES_256_KEY` are `optional: true`, so a missing key moves the failure to runtime (settings default `DD_SECRET_KEY=""`, `DD_CREDENTIAL_AES_256_KEY="."`). A missing `DD_ADMIN_PASSWORD` makes the initializer **generate one and print it to the pod log** (`complete_initialization.py` line 127). |
| `defectdojo-postgresql-specific` (value `postgresql.auth.existingSecret`) | `postgresql-postgres-password`, `postgresql-password` | Postgres and all DB clients fail |
| `defectdojo-valkey-specific` (value `valkey.auth.existingSecret`) | `valkey-password` | Celery broker auth fails |

The admin password is read **only on first boot** ("Admin user already exists; skipping first-boot setup"). Rotating the Secret later does not change the password.

### Anti-Patterns to Avoid
- **Any `define "defectdojo.*"` in the wrapper:** silently overrides the subchart's helpers (measured).
- **Waiting on the initializer Job in the smoke:** `initializer.keepSeconds: 60` gives `ttlSecondsAfterFinished: 60`. The Job was gone within about a minute of completion [VERIFIED: measured]. The Nexus smoke treats an empty Job set as a FAIL, so a copied check fails spuriously. Readiness of the django Deployment is the right signal: its `db-migration-checker` init container blocks until `manage.py migrate --check` passes.
- **A diff-based / byte-identical offline check on the full render:** `initializer.staticName: false` embeds `now` in the Job name, so every render differs. Select by `kind`, or pass `--set defectdojo.initializer.staticName=true` in the gate's render helper.
- **Recommending ingress-nginx in the README:** it is archived. Use it only in the smoke.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DefectDojo workloads / initializer / Celery | Own templates | Upstream chart 1.9.53 | D-01. Upstream handles migrations, the initializer and the migration-checker init containers |
| Certificate object | `Certificate` template | cert-manager ingress-shim annotation | D-10. Upstream already emits `spec.tls.hosts` + `secretName` |
| Smoke CA | openssl-generated certs | cert-manager SelfSigned → CA Certificate → CA ClusterIssuer bootstrap | Documented cert-manager pattern [CITED: cert-manager.io/docs/configuration/selfsigned]. The issued Secret carries `ca.crt`, so curl can verify the served cert with `--cacert` instead of `-k` [VERIFIED: measured] |
| Secret generation | wrapper `randAlphaNum` | Consumer pre-created Secrets; upstream `create*Secret` opt-in | D-13 |

**Key insight:** in this phase the correctness risk lives in values and runtime (memory, secrets, Job TTL), not in templates. The wrapper stays almost template-free, and the evidence has to come from the live smoke.

## Common Pitfalls

### Pitfall 1: Named-template collision between wrapper and subchart
**What goes wrong:** the wrapper `_helpers.tpl` defines `defectdojo.fullname`, and every subchart object is renamed to the wrapper's output.
**Why:** Helm's template namespace is global across parent and subcharts. Nexus avoided this only because the names differed (`nexus` vs `nexus3`).
**How to avoid:** ship no `_helpers.tpl`, or prefix it. Add gate check `NO-HELPER-COLLISION`: grep the wrapper `templates/` for `define "defectdojo.` and expect 0.
**Warning signs:** Ingress or ConfigMap names that don't match `<release>-defectdojo`.

### Pitfall 2: uwsgi OOMKilled with upstream defaults
**What goes wrong:** the django pod ends in CrashLoopBackOff (`OOMKilled`, exit 137), and `helm install --wait` never succeeds.
**Why:** (a) `maxFd: 0` appears to let uwsgi size its fd table from `RLIMIT_NOFILE` (1073741816 here, visible in the uwsgi log line "detected max file descriptor number") [ASSUMED mechanism. It is consistent with the log line, with the chart exposing `maxFd` for this purpose, and with the isolation test: `maxFd` alone fixed the startup OOM and `processes: 2` alone did not. The *fix* is measured]. That limit comes from Docker Desktop/linuxkit; stock containerd defaults to 1048576, so the homelab may never have hit the startup OOM, and the setting is harmless either way; (b) 4 processes × Django ≈ 440 MiB idle against a 512Mi limit, and the first login pushes it over.
**How to avoid:** `maxFd: 102400`, `processes: 2`, limit ≥ 512Mi (recommend 1Gi). Also have the smoke do a login POST.
**Warning signs:** `Last State: Terminated, Reason: OOMKilled` on container `uwsgi`. A GET `/login` 200 does **not** rule this out (measured).

### Pitfall 3: Helm 4 `--wait` fails fast on a Deployment that already failed
**What goes wrong:** `helm upgrade --wait` returned in 0 s with `Progress deadline exceeded`.
**Why:** local Helm is **v4.3.0**, whose kstatus-based wait reports a `Failed` Deployment immediately [VERIFIED: measured]. Config-only changes also don't restart pods, because upstream `trackConfig: disabled` means a ConfigMap change (uwsgi settings live in the ConfigMap) needs a pod restart.
**How to avoid:** the smoke only does a fresh install (D-15). Record the Helm client version in its output. Note that every measurement this session used Helm **v4.3.0**. Helm 3 behaviour (the CI Checkov container ships v3.22.0) was not measured, so write the scripts to depend only on exit codes and on `kubectl` readiness, not on Helm-version-specific wait semantics.

### Pitfall 4: Offline render depends on the operator's kubeconfig
**What goes wrong:** `helm template` emitted `namespace: argocd` from the current context.
**How to avoid:** the gate's `render()` passes `--namespace defectdojo`. The smoke passes `--kube-context kind-<name>` on every helm call and `--context` on every kubectl call, and restores `KUBECTX_BEFORE` in the trap (the Nexus pattern). The current context is the homelab.

### Pitfall 5: CI Checkov will not scan this chart
**What goes wrong:** the guard fails a bare render. The pinned CI Checkov container (`checkov:3.3.17`, helm runner) renders without values, so it covers the chart zero times, the same as Nexus (23-08 SUMMARY).
**How to avoid:** do not weaken the guard. "Checkov measured" means measuring locally against a rendered manifest with values supplied. This session measured `checkov 3.2.396 -f rendered.yaml --framework kubernetes`: **66 failed / 568 passed over 26 resources**, all on upstream-rendered objects. The wrapper contributes 0 resources. Top IDs are `CKV_K8S_40`×7, `CKV2_K8S_6`×6, `CKV_K8S_43`×6, `CKV_K8S_35`×6 and `CKV_K8S_31`×6. The executor should re-measure with the final values and, as in Phase 23, state both the local count and the "CI coverage = 0" fact.

### Pitfall 6: `siteUrl` does not follow `host`
**What goes wrong:** the consumer overrides `host` only, and `DD_SITE_URL` stays at the placeholder (or `http://localhost:8080` if the wrapper doesn't set it), so links in notifications and Jira are wrong.
**How to avoid:** the wrapper ships a matching placeholder pair. The README tells consumers to set both, and the gate asserts the default pair is consistent (`siteUrl == "https://" + host`).

### Pitfall 7: kind networking for the HTTPS check
**What goes wrong:** curl against `localhost` gets Django `DisallowedHost`, or ingress-nginx returns a 404 for the wrong Host (measured 404). `-k` would hide the ingress-nginx fake default certificate.
**How to avoid:** use `kubectl port-forward svc/ingress-nginx-controller <highport>:443` (no kind `extraPortMappings`, no host 80/443 conflicts), then `curl --resolve HOST:PORT:127.0.0.1 --cacert <ca.crt from the issued Secret>`. Measured: `ssl_verify_result=0`, SAN `DNS:defectdojo.smoke.test`, issuer `CN=smoke-ca`.

### Pitfall 8: D-12 is only proven if the IngressClass is the cluster default
The kind ingress-nginx manifest's IngressClass `nginx` is **not** annotated as default, and the controller runs `--watch-ingress-without-class=true`. A classless Ingress is served either way, which proves nothing about D-12. **Smoke step:** `kubectl annotate ingressclass nginx ingressclass.kubernetes.io/is-default-class=true`, then assert live `.spec.ingressClassName == "nginx"`, set by the API server's DefaultIngressClass admission. Measured: the live Ingress got `ingressClassName: nginx` while the rendered one had none.

### Pitfall 9: ingress-nginx admission webhook race
The controller Deployment's rollout finishing is the gate for applying Ingresses. The measured sequence (`rollout status deploy/ingress-nginx-controller` before `helm install`) had no webhook error. The cert-manager webhook needs the same treatment: roll out all three cert-manager Deployments first, then retry the ClusterIssuer apply a few times, because the webhook can briefly refuse connections after rollout [ASSUMED; the measured run succeeded on its first apply].

## Code Examples

### Offline gate — recommended check IDs (clone `check-nexus-chart.sh` structure: SKIP guards, exit 0/1/2, `fail()` collects all, `CHECK_COUNT` literal in 3 places)
`render()`: `helm template t kubernetes/defectdojo --namespace defectdojo --set 'defectdojo.django.ingress.annotations.cert-manager\.io/cluster-issuer=gate-issuer' "$@"`

| ID | Assertion (all measured true on the prototype unless noted) |
|----|-----------|
| CHART-LINT | `helm lint` with the issuer set exits 0 (measured: only `[INFO] icon is recommended`) |
| ISSUER-REQUIRED | a bare `helm template` exits non-zero and stderr contains `cert-manager.io/cluster-issuer` |
| ISSUER-EITHER-KEY | the render succeeds with only `cert-manager.io/issuer` set |
| ISSUER-NOT-BOTH | the render fails with both keys set |
| TLS-OFF-RENDERS | `--set defectdojo.django.ingress.activateTLS=false` renders without an issuer and the Ingress has no `spec.tls` (measured rc=0) |
| INGRESS-ON | exactly 1 `Ingress`; `spec.rules[0].host == defectdojo.example.com` |
| TLS-ON | Ingress `spec.tls[0].hosts[0] == host`, `secretName == defectdojo-tls`, annotation carries the issuer |
| INGRESSCLASS-UNSET | Ingress `.spec | has("ingressClassName") == false`; with `--set ...ingressClassName=x` it equals `x` |
| STORAGECLASS-OMITTED | Postgres StatefulSet VCT `has("storageClassName") == false` (measured); override `defectdojo.postgresql.primary.persistence.storageClass=test` → `test` |
| POSTGRES-PERSISTENT | Postgres StatefulSet has 1 volumeClaimTemplate (measured) |
| VALKEY-EPHEMERAL | Valkey StatefulSet has 0 volumeClaimTemplates (measured) |
| NO-SECRETS-RENDERED | default render contains 0 `kind: Secret` (measured: none in the object list) |
| CREATE-SECRET-OPT-IN | `--set defectdojo.createSecret=true` renders a Secret with the 4 keys |
| IMAGE-PIN | `values.yaml` `.defectdojo.images.django.image.tag` == `.nginx…tag` == `appVersion` of the vendored `charts/defectdojo-*.tgz` == wrapper `Chart.yaml` `appVersion` (D-03 drift guard) |
| RENDERED-IMAGES | every rendered `defectdojo/defectdojo-*` image ends in `:3.3.200` |
| SITEURL-MATCHES-HOST | the default `siteUrl == "https://" + host` |
| UWSGI-FOOTPRINT | ConfigMap `DD_UWSGI_MAX_FD` non-empty and `DD_UWSGI_NUM_OF_PROCESSES == "2"` |
| NO-HELPER-COLLISION | no `define "defectdojo.` under wrapper `templates/` |
| PLACEHOLDER-ONLY | `values.yaml` contains no real hostnames or issuer names (e.g. grep for `ottawacloudconsulting`, `letsencrypt`, `occ-` returns 0) — generic-first |

Preflight exit 2: `helm`, `yq`, `jq` present, and `kubernetes/defectdojo/charts/defectdojo-1.9.53.tgz` present (message: `run: helm dependency build kubernetes/defectdojo`). SKIP guards for the chart directory being absent or `templates/validate-tls.yaml` being absent (the vacuous-pass convention).

### Live smoke — measured sequence (kind v0.33.0, Docker Desktop 12 CPU / 7.65 GiB)
```bash
# Source: this session's measurement (scratchpad measure.sh); pin --context everywhere
kind create cluster --name dd-smoke                                    # ownership guard as in nexus smoke
kubectl --context kind-dd-smoke apply -f cert-manager-v1.21.2.yaml
for d in cert-manager cert-manager-webhook cert-manager-cainjector; do
  kubectl --context kind-dd-smoke -n cert-manager rollout status deploy/$d --timeout=300s; done
kubectl --context kind-dd-smoke apply -f ingress-nginx-controller-v1.15.1-kind.yaml
kubectl --context kind-dd-smoke -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s
kubectl --context kind-dd-smoke annotate ingressclass nginx ingressclass.kubernetes.io/is-default-class=true
# SelfSigned ClusterIssuer -> isCA Certificate (ns cert-manager, secret smoke-ca) -> CA ClusterIssuer smoke-ca
kubectl ... -n cert-manager wait --for=condition=Ready certificate/smoke-ca --timeout=120s
# namespace + 3 Secrets via stdin (never argv), release name `defectdojo` => app Secret name `defectdojo`
helm dependency build kubernetes/defectdojo
helm install defectdojo kubernetes/defectdojo --kube-context kind-dd-smoke -n defectdojo \
  --set defectdojo.host=defectdojo.smoke.test --set defectdojo.siteUrl=https://defectdojo.smoke.test \
  --set 'defectdojo.django.ingress.annotations.cert-manager\.io/cluster-issuer=smoke-ca' \
  --wait --timeout 15m              # measured 101 s warm-image; cold pulls add minutes
kubectl ... -n defectdojo wait --for=condition=Ready certificate/defectdojo-tls --timeout=300s
# assert live Ingress .spec.ingressClassName == nginx (D-12)
kubectl ... -n defectdojo get secret defectdojo-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > "$OUT/ca.crt"
kubectl ... -n ingress-nginx port-forward svc/ingress-nginx-controller 18443:443 &   # kill in trap
curl --resolve defectdojo.smoke.test:18443:127.0.0.1 --cacert "$OUT/ca.crt" \
  -o /dev/null -w '%{http_code}' https://defectdojo.smoke.test:18443/login          # measured 200
# Recommended extra: CSRF-token login POST as admin -> measured 302 to "/", then /dashboard 200
# Recommended extra (UNMEASURED): broker proof -- celery Running 1/1 proves nothing (upstream ships no
# celery probes; neither login nor the initializer dispatches a task), and the wrapper changes Valkey config:
kubectl ... -n defectdojo exec deploy/defectdojo-celery-worker -c celery -- celery -A dojo inspect ping -t 5   # expect exit 0 and 'pong'
```
Measured results this session: Certificate `defectdojo-tls` Ready; served cert issuer `CN=smoke-ca`, SAN `DNS:defectdojo.smoke.test`, `ssl_verify_result=0`; `/login` 200; `/` 302 to `/login?next=/`; wrong Host 404; unauthenticated `/api/v2/users/` 403; admin login POST 302 then `/dashboard` 200 **with no `DD_SECURE_PROXY_SSL_HEADER` or `DD_CSRF_TRUSTED_ORIGINS` set**. The mechanism behind that last point (why Django treated the proxied request as passing the CSRF origin check) was not identified; the result is empirical for 3.3.200 behind ingress-nginx 1.15.1. The postgres PVC bound on kind's default `standard` StorageClass.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Redis broker, `createRedisSecret` | Valkey (cloudpirates chart), `createValkeySecret`; the old keys hard-`fail` | pre-1.9.x | The wrapper must never set `redis:` or `createRedisSecret` (upstream `secret-valkey.yaml` calls `fail`) |
| `docker.io/bitnami/postgresql` | DefectDojo-mirrored `us-docker.pkg.dev/os-public-container-registry/defectdojo/bitnami/postgresql` | current | D-07 "as-is" is safe with respect to the Bitnami catalog changes |
| ingress-nginx as the default controller | Archived 2026-03. Gateway API or other controllers recommended | 2026-03 | Smoke-only use. Gateway API stays deferred |
| DefectDojo 2.x versioning (ADR-006 says `2.x.y`) | 3.x (3.3.200) with weekly chart bumps (1.9.39→1.9.53 in 8 weeks) | 2026 | ADR-023 should note that ADR-006's `2.x.y` example is superseded in practice (append-only, so don't edit ADR-006) |
| Helm 3 `--wait` | Helm 4 kstatus watcher (local v4.3.0); CI Checkov container ships Helm v3.22.0 | 2025–26 | Scripts must work under both |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The operator prefers a tag pin plus a drift check over a digest pin for DefectDojo images | Standard Stack / Alternatives | Low. Switching to digests is a values edit plus a gate tweak |
| A2 | Placeholder `defectdojo.example.com` (RFC 2606 reserved, and ACME issuers refuse it, so a forgotten override fails loudly) rather than `.example.local` (`.local` is mDNS, RFC 6762) | Pattern 2 | Cosmetic. D-09 leaves the string to discretion |
| A3 | The cert-manager webhook may briefly refuse ClusterIssuer creation right after rollout, so a retry loop is prudent | Pitfall 9 | Low. The measured run succeeded first try |
| A4 | Dependabot's `helm` ecosystem (GA 2025-04) would bump the `Chart.yaml` dependency. A community report says chart/image name collisions can overwrite values image tags, and here the dependency `defectdojo` and the image `defectdojo/defectdojo-*` might collide | Open Questions | Medium. A partial bump would split the pins. The IMAGE-PIN gate check catches it either way |
| A5 | uwsgi limit 1Gi / request 384Mi is "small footprint" enough for the operator | Pattern 2 | Low. The measured floor is 512Mi limit with 2 processes; 430 MiB peak left thin headroom |
| A6 | The uwsgi startup OOM is caused by fd-table sizing from RLIMIT_NOFILE (the fix, `maxFd: 102400`, is measured; the mechanism is inferred) | Pitfall 2 | Low. The setting is harmless whether or not the mechanism is right |
| A7 | `celery -A dojo inspect ping -t 5` works inside the worker container as a broker-connectivity proof (upstream suggests it as a liveness command) | Code Examples / Validation | Medium. If it does not work, fall back to a log grep for the worker's broker-connected line |

## Open Questions

1. **Media volume is `emptyDir` upstream (`django.mediaPersistentVolume.type: emptyDir`).**
   - What we know: uploaded files and attachments are lost on pod restart. The PVC option defaults to RWX. CONTEXT is silent (D-08 covers Postgres and Valkey only).
   - Recommendation: keep the upstream default (thin, D-04) and list it as a README Limitations row. It is a data-loss property, not a backup callout, so D-06 does not forbid it. If the operator wants persistence, that is a new decision.
2. **`initializer.staticName` for ArgoCD (Phase 29).**
   - What we know: `false` gives a new Job name on every render, which ArgoCD shows as perpetually OutOfSync and re-runs on each sync. `true` gives a stable name, but with `keepSeconds: 60` the Job is TTL-deleted, which ArgoCD shows as missing, and selfHeal recreates it. The initializer is idempotent ("Admin user already exists; skipping"). Upstream says `staticName` is "handy for ArgoCD".
   - Recommendation: leave the upstream default in Phase 26 (D-15 defers resync). Put it on Phase 29's list together with the ArgoCD Job hook/ignore strategy. The gate should not depend on the Job name.
3. **Dependabot `helm` ecosystem for the D-03 bump path.**
   - Recommendation: do not add it this phase. Document the manual bump procedure in the README (update Chart.yaml dep + appVersion + both image tags, `helm dependency update`, run the gate). IMAGE-PIN enforces consistency. See A4.
4. **CSRF behind a different proxy (carry to Phase 29).** The login POST passed CSRF behind ingress-nginx 1.15.1 on kind with neither `DD_SECURE_PROXY_SSL_HEADER` nor `DD_CSRF_TRUSTED_ORIGINS` set. The mechanism was not identified. Phase 29 will run behind whatever proxy the homelab ends up with (none exists yet, see OQ 6), so it must re-run the login POST there. Fallback if it returns 403: `defectdojo.extraConfigs.DD_CSRF_TRUSTED_ORIGINS: https://<host>` (and/or `DD_SECURE_PROXY_SSL_HEADER: "True"`) in the overlay. Neither needs a chart change.
5. **Should the smoke's login POST and celery ping become locked assertions?** D-14 names only "login page returns 200". The measurements show that is insufficient (Pitfall 2). Recommendation: planner includes `KIND-LOGIN` (CSRF-token POST, expect 302, then `/dashboard` 200) and `KIND-CELERY-PING` (a broker round-trip; worker `Running` is not evidence because upstream ships no celery probes and the wrapper changes Valkey persistence) as additional checks, and records both as going beyond D-14's literal text in the plan. The admin password comes from the smoke's own pre-created Secret, so no log scraping is needed.
6. **Homelab readiness for Phase 29 (recorded, not blocking here).**
   - ClusterIssuers `letsencrypt-dns01-prod` and `letsencrypt-dns01-staging` (Route53 DNS-01) are defined in `~/git-repos/OCC-github/kubernetes_stack/occ-k8s-cluster-config/application-sets/cert-manager/templates/` (last commit on that dir 2026-09-07; repo HEAD `fe7af30`, 2026-09-19). Apps in `occ-k8s-app-config` use explicit `Certificate` objects plus ghostunnel sidecars on LoadBalancer IPs, not Ingress.
   - `ingressClassName: internal-nginx` appears only in `kubernetes_stack/_config_archive/kube-dash/templates/values.yaml` (archived config). No live-repo IngressClass, Ingress controller or Gateway was found.
   - This matches ADR-022 decision 4 ("no IngressClass") and refines its "no TLS anywhere" wording: cert-manager plus DNS-01 issuers exist for other apps.
   - **DDOJO-05 needs an ingress controller that appears absent.** Phase 29 must run `kubectl get ingressclass,clusterissuer` live and decide.
7. **Bitnami postgres `NetworkPolicy` is rendered by default** (`primary.networkPolicy.enabled`, `allowExternal: true`, egress `{}`). It is permissive and inert on kind (kindnet). On the homelab's Cilium it is enforced but allow-all on 5432. Record it for Phase 29; no action here.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| helm | gate, smoke | ✓ | v4.3.0 | — (CI Checkov uses v3.22.0 internally) |
| yq (mikefarah) | gate | ✓ | v4.53.6 | — |
| jq | gate | ✓ | present | — |
| kind | smoke | ✓ | v0.33.0 | SKIPPED tier, as in the nexus smoke |
| kubectl | smoke | ✓ | present | SKIPPED tier |
| docker | kind | ✓ | Server 28.3.2, 12 CPU, 7.65 GiB | — |
| checkov | "Checkov measured" | ✓ | 3.2.396 local (CI pins 3.3.17 via action v12.3123.0) | Measure in the pinned container as 23-06 did |
| shellcheck | script lint | ✓ | present | — |
| Network to raw.githubusercontent.com, GitHub releases, docker.io, us-docker.pkg.dev, quay.io, registry.k8s.io | dependency build, smoke | ✓ | — | none |

**Missing dependencies with no fallback:** none.
**Resource note:** the full smoke stack fitted comfortably. DefectDojo used about 1.2 GiB in total, plus cert-manager and ingress-nginx. A cluster name collision is guarded as in the nexus smoke; no kind clusters existed at research end.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Standing bash gates under `scripts/` (repo convention; there is no Helm unit-test framework) |
| Config file | none. Wave 0 creates `repos/security-platform/scripts/check-defectdojo-chart.sh` |
| Quick run command | `bash scripts/check-defectdojo-chart.sh` (offline, a few seconds; needs a vendored tgz) |
| Full suite command | `bash scripts/check-defectdojo-chart.sh && bash scripts/defectdojo-live-smoke.sh` |
| Estimated runtime | gate ~5–10 s. Smoke: dominated by cold image pulls and not measured end to end. kind nodes run their own containerd and never share the host Docker image cache, so every fresh smoke run is cold. Measured pieces: cluster 11 s, cert-manager ~27 s, ingress-nginx ~22 s, and a 101 s helm install that was a reinstall on an already-warm cluster. The first cold install was confounded by the OOM. Keep the 15 m helm timeout. |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DDOJO-01 | Chart lints/renders; ingress on; TLS on; issuer required; class/SC unset; PG persistent; Valkey ephemeral; no secrets rendered; pins consistent; no helper collision; placeholders only | offline | `bash scripts/check-defectdojo-chart.sh` | ❌ Wave 0 |
| DDOJO-01 | Install on kind → Deployments Ready → Certificate Ready → Ingress class defaulted → verified-TLS `/login` 200 → admin login 302 + `/dashboard` 200 → `celery inspect ping` succeeds (KIND-CELERY-PING) | live smoke | `bash scripts/defectdojo-live-smoke.sh` | ❌ Wave 0 |
| DDOJO-01 | Checkov measured on the rendered chart (count recorded; CI coverage = 0 recorded) | measurement | `helm template … > r.yaml && checkov -f r.yaml --framework kubernetes` | manual record in SUMMARY |
| DDOJO-01 | Chart is public on `security-platform` main; CI green | human gate | `gh pr checks <n> --watch` | n/a (operator approval) |

### Sampling Rate
- **Per task commit:** `bash scripts/check-defectdojo-chart.sh`. It must exit 0 at every intermediate commit (vacuous-pass SKIP guards).
- **Per wave merge:** the gate plus `shellcheck scripts/*defectdojo*.sh`.
- **Phase gate:** the full suite green (smoke with 0 FAIL and 0 SKIPPED, run on this workstation) before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `scripts/check-defectdojo-chart.sh`: covers DDOJO-01 offline (check IDs above)
- [ ] `scripts/defectdojo-live-smoke.sh`: covers DDOJO-01 live. Clone the ownership guard, the context restore and the SKIPPED/FAILURES/CHECKS_PASSED accounting from `nexus-live-smoke.sh`. There is no docker half (DefectDojo has no provisioning script to exercise outside Kubernetes).
- [ ] Framework install: none; all tools are present.

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Admin password is a consumer pre-created Secret. The chart ships none and generates none by default (D-13). Pitfall: a missing key leaks a generated password to the logs |
| V3 Session Management | yes | Upstream sets `DD_SESSION_COOKIE_SECURE`/`DD_CSRF_COOKIE_SECURE=True` when `activateTLS` (verified in the live env) |
| V4 Access Control | partial | Unauthenticated API returns 403 (measured). The RBAC model is DefectDojo's own |
| V5 Input Validation | n/a in chart | App-level |
| V6 Cryptography | yes | `DD_CREDENTIAL_AES_256_KEY` must be stable across upgrades/syncs. That is why D-13 uses existingSecret: regeneration makes stored credentials undecryptable |
| V9 Communications | yes | TLS at the ingress via cert-manager. In-cluster ingress→pod and app→Postgres/Valkey traffic is plaintext (NetworkPolicy/mTLS is out of scope per REQUIREMENTS) |
| V14 Configuration | yes | Pinned versions (D-03). No environment values in the public chart (PLACEHOLDER-ONLY check) |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Chart-generated secrets regenerate on sync, breaking AES-encrypted data | Tampering/DoS | existingSecret default; `create*Secret` opt-in only (D-13) |
| Admin password printed to initializer logs | Information disclosure | Always supply `DD_ADMIN_PASSWORD`. The README states it, and the smoke supplies it |
| Unannounced schema migration from a floating tag | Tampering | Tag pin + IMAGE-PIN drift check (D-03) |
| Environment leakage into the public chart | Information disclosure | Placeholder host; issuer has no default; PLACEHOLDER-ONLY gate check |
| Serving the ingress default (fake) cert unnoticed | Spoofing | Smoke verifies with `--cacert` from the cert-manager Secret, never `-k` |
| Archived ingress controller | Tampering (unpatched CVEs) | Smoke-only use, throwaway cluster; README does not recommend it |

## Sources

### Primary (HIGH confidence)
- DefectDojo helm-charts `index.yaml` and `defectdojo-1.9.53.tgz` (values.yaml, values.schema.json, templates/*, Chart.lock, nested charts): read and rendered locally
- DefectDojo 3.3.200 source: `dojo/settings/settings.dist.py`, `docker/entrypoint-initializer.sh`, `dojo/management/commands/complete_initialization.py`, `wsgi_params`, `nginx/nginx.conf`
- Context7 `/cert-manager/website`: ingress-shim annotations (`usage/ingress.md`), SelfSigned→CA bootstrap (`configuration/selfsigned.md`)
- GitHub API: cert-manager releases, ingress-nginx releases and `archived: true`
- `docker buildx imagetools inspect` for the 4 images (digests, platforms)
- Live kind measurement this session (install, OOM diagnosis, memory cgroup readings, TLS/login checks)
- `repos/security-platform`: nexus chart, both nexus scripts, `.gitignore`, `.pre-commit-config.yaml`, `security.yml` Checkov pin; Phase 23 SUMMARY/VALIDATION files; ADR-006/007/009/022

### Secondary (MEDIUM confidence)
- [GitHub Docs: Dependabot supported ecosystems](https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories): `helm` ecosystem, version updates only
- [GitHub Changelog 2025-04-09: Dependabot supports Helm](https://github.blog/changelog/2025-04-09-dependabot-version-updates-now-support-helm/)
- [Kubernetes blog: Ingress NGINX Retirement](https://www.kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/); [Steering/SRC statement](https://www.kubernetes.io/blog/2026/01/29/ingress-nginx-statement/)

### Tertiary (LOW confidence)
- Community report on Dependabot helm chart/image name-collision overwrites (surfaced in a web-search summary; not verified against official docs) → A4

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH. Versions, digests and pulls were verified against the registries and the tarball.
- Architecture: HIGH. The guard, render assertions and live TLS path were prototyped and measured.
- Pitfalls: HIGH for 1–5, 7 and 8 (measured); MEDIUM for 9 (partly assumed).
- Footprint numbers: MEDIUM. They were measured on one arm64 kind node. Homelab hardware may differ.

**Research date:** 2026-09-24
**Valid until:** about 2026-10-01 for version numbers, because upstream publishes a chart release weekly (the pin itself stays valid indefinitely). About 30 days for patterns.
