# Phase 29: DefectDojo Live Validation - Research

**Researched:** 2026-09-26
**Domain:** GitOps live deploy (Argo CD 3.5.1 overlay, Cilium 1.19.6 L2 VIP + ghostunnel TLS), actions-runner-controller self-hosted runner reachability, GitHub Actions reusable-workflow routing, and a DefectDojo 3.3.200 live API proof
**Confidence:** HIGH for the stack, the chart keys, the runner image and the account-type blocker. MEDIUM for in-cluster VIP hairpin, which has to be measured.

<user_constraints>
## User Constraints (from CONTEXT.md)

> **Superseded in part:** D-07, D-08, D-11 step 5 and D-16 were amended in 29-CONTEXT.md on 2026-09-26/27, and D-18 to D-20 were added. CONTEXT.md is authoritative where this copy differs.

### Locked Decisions

Carried forward, not re-decided:
- Claude has direct kubeconfig access and git access to the overlay repo (25 D-01/D-02).
- The overlay uses the existing `platform` AppProject, amended by enumerated kinds, and a two-source Application pinned to a `security-platform` commit (ADR-022 decisions 1-2).
- Secrets are SealedSecrets at sync-wave `-1` (ADR-022 decision 3, 26 D-13).
- DefectDojo stays pinned at 1.9.53 / 3.3.200 (26 D-03). Postgres persistence is on and Valkey is ephemeral (26 D-08). There is no backup provision (26 D-06).

#### Exposure and TLS
- **D-01:** The chart's ingress is **off in the overlay**. The cluster has no IngressClass: `kubectl get ingressclass` returned nothing on 2026-09-26, and Cilium ingressController and gatewayAPI are both disabled. DefectDojo is exposed by a `type: LoadBalancer` Service on a vlan43-static VIP, with TLS terminated by ghostunnel and a cert-manager DNS-01 Certificate from `letsencrypt-dns01-prod`, which is Ready live. This is the homepage/argo pattern. The chart's ingress path stays proven only on kind (Phase 26), and ADR-027 must state that.
- **D-02:** ghostunnel runs as a **standalone Deployment in the overlay** that proxies to the chart's django Service. It is not a sidecar injected through upstream values. The public chart is untouched.
- **D-03:** The VIP is **10.40.3.65**, as recommended by the cluster-team session on 2026-09-26:
  - it is the lowest free address in vlan43-static, and the pool had 15 of 20 free live;
  - avoid .69, which is dead config in cert-manager `values.yaml`;
  - this session's `.64`/`.79` references came from a loose regex grep, are unverified, and stay excluded.

  Service conventions to copy exactly:
  - labels `vlan: "43"` and `IPautoAssign: "false"` (quoted strings);
  - annotation `lbipam.cilium.io/ips: "10.40.3.65"`;
  - `externalTrafficPolicy: Cluster`. `Local` is rejected at admission by `application-sets/platform/admission-policies/`.
- **D-04:** The hostnames are **`defectdojo.infra.ottawacloudconsulting.com` plus a `.home` SAN, `defectdojo.home.ottawacloudconsulting.com`**. Both SANs go on the one Certificate, in the same form as `platform/homepage/templates/certificate.yaml`. The internal A records are **manual Pi-hole Local DNS entries on 10.40.1.53**. They are not in git; the `public-dns/aws-dns` appset handles only public Route53. VLAN30 clients use the in-cluster Pi-hole at 10.30.1.53, and whether they need the entries too is an open check.
- **D-05:** ghostunnel is L4. It adds no `X-Forwarded-Proto`, so the CSRF 403 from 26-RESEARCH OQ4 is **expected**. The overlay (not the chart) sets `defectdojo.extraConfigs` for:
  - `DD_CSRF_TRUSTED_ORIGINS` with both https origins;
  - allowed hosts for both names (`DD_ALLOWED_HOSTS`, or the chart's `host`/alternative-host keys; research picks);
  - the site URL.

  The live login POST (302, then `/dashboard` 200) must pass on both hostnames.

#### Runner reachability
- **D-06:** CI reaches DefectDojo through a **self-hosted runner** from actions-runner-controller (ARC, runner scale set) running in the homelab cluster. **Only `defectdojo-import` and `defectdojo-cleanup`** use it. The five scan jobs stay on `ubuntu-latest`.
- **D-07:** The runner is registered at **org level in a runner group restricted to selected repositories**, which today means `security-platform` only. "Allow public repositories" is enabled on that group only. Consumers are added to the group later.
- **D-08:** ARC authenticates with a **fine-grained PAT** that has the org `Self-hosted runners: read/write` permission (research confirms the minimum). The PAT is stored as a SealedSecret. The operator chose this over a GitHub App, and PAT expiry means manual rotation (accepted, see Accepted Risks).
- **D-09:** Routing works through an **optional caller repo variable `DEFECTDOJO_RUNS_ON`**, read in the callee. This is the same mechanism as `DEFECTDOJO_URL` (27 D-11). When it is unset, the two jobs keep `ubuntu-latest`, and old callers work unchanged. This is a `security.yml` change, so it brings:
  - an additive v1.x tag and a `v1` move (ADR-018, 27 D-16);
  - an adoption-guide update, with `bash scripts/check-adoption-guide.sh` kept green;
  - a new ADR (D-17).

  Runner hardening: **ephemeral pods only** (the ARC default). The operator explicitly declined a runner-egress NetworkPolicy.

#### Live proof scope
- **D-10:** **`security-platform` itself is the importer.** Its repo settings get:
  - `DEFECTDOJO_URL=https://defectdojo.infra.ottawacloudconsulting.com`;
  - `DEFECTDOJO_RUNS_ON`;
  - the `DEFECTDOJO_API_TOKEN` secret.

  Its `pr-security.yml` and `scheduled-security.yml` callers then import live. This deliberately realises the 27-RESEARCH OQ5 side effect, which extends to `defectdojo-import-proof.yml`: that workflow calls `security.yml`, so its import job now routes to ARC and imports into the live instance. Research states the exact effect and whether the proof workflow needs a guard. No `DEFECTDOJO_CA_CERT` is needed, because the Let's Encrypt prod certificate is publicly trusted.
- **D-11:** The Phase 28 behaviour is re-proved through a **real PR lifecycle**, not the proof script. The sequence:
  1. Open a **same-repo, non-Dependabot** PR on `security-platform` that introduces a new finding. Fork and Dependabot PRs skip every guarded step (17-03).
  2. Assert through the API that the pre-existing findings on `ci/<branch>` are duplicates of the `ci/main` originals, and that only the new finding is active.
  3. Set False Positive, Risk Accepted (90-day expiry and a reason, per D-22 of Phase 28) and Out of Scope on `ci/main` originals.
  4. Reimport by running `scheduled-security.yml` through `workflow_dispatch`, and assert that all three dispositions survive.
  5. **Close the PR unmerged**, and assert that the engagement is deleted and its duplicates re-parented.

  Assertions check API state, not HTTP status.
- **D-12:** **`workflow_dispatch` of the scheduled caller is enough** for the scheduled path. A cron-fired 06:00 America/Toronto run is observed only if it lands before close, and is then recorded. It does not block close.
- **D-13:** `bash scripts/defectdojo-configure.sh` runs **once, before the first live import**, right after the first Synced+Healthy. It uses an operator-held superuser token that is never stored in GitHub. A second run must show no change. As a result, ADR-026 NOT-verified item 1 (turning dedup on over existing findings) stays **open and not exercised**, and ADR-027 records that.
- **D-14:** Measured live, never assumed. Research proposes how to measure each:
  - Second-sync idempotency, including the `initializer.staticName` choice and how ArgoCD treats the TTL-deleted initializer Job (26-RESEARCH OQ2, ADR-023 NOT-verified item 4).
  - Bitnami Postgres NetworkPolicy behaviour on Cilium (26-RESEARCH OQ7).
  - Bitnami image pulls succeeding on the homelab.

#### Data layer and tokens
- **D-15:** **Bundled Bitnami Postgres** (26 D-05 default), exactly as shipped, so the live run validates the defaults. The CloudNativePG operator in `platform/cloudnative-pg` is not used.
- **D-16:** The CI token belongs to a **dedicated least-privilege user**. Per ADR-024, that is a `ci-importer` user with `is_staff=true` and `is_superuser=false`, the smallest identity proven able to import, auto-create a Product Type and delete an engagement at 3.3.200. The superuser token is used only for D-13 and is held by the operator.

#### Records
- **D-17:** Write **ADR-027** for the homelab DefectDojo live validation: exposure via LB VIP + ghostunnel, ARC reachability, `DEFECTDOJO_RUNS_ON`, the proof results and the accepted risks. Add its row to `docs/adr/README.md`. Research decides whether ARC needs its own ADR (ADR-028). ADRs are append-only, so do not edit ADR-022 to ADR-026.
  - The ADR must also state that the import job **queues, rather than fails,** when the named runner is offline. GitHub cancels a queued job after about 24h. Merge is unaffected because the job is not a required check, and it must never become one (27 D-03).
  - Mark DDOJO-05 Complete in `.planning/REQUIREMENTS.md`. Update the chart README's DDOJO-05 row.

### Claude's Discretion
- The overlay directory name. `platform/defectdojo/` follows the Nexus precedent.
- Where ARC lives: `occ-k8s-cluster-config` or `occ-k8s-app-config`, following whichever convention fits a cluster-wide controller. It also covers the ARC chart version, and the scale-set name and label.
- The `initializer.staticName` value and any ArgoCD ignore or hook settings, based on the measurement in D-14.
- The ghostunnel image tag (homepage uses `ghostunnel/ghostunnel:v1.11.3-distroless`) and how cert reload is handled; homepage's deployment carries a comment on this.
- How `ci-importer` and its token are created: manual operator steps, or a scripted step run by the operator.

### Deferred Ideas (OUT OF SCOPE)
- An egress NetworkPolicy for ARC runner pods (declined for now; hardening bucket).
- A GitHub App for ARC instead of the PAT.
- CloudNativePG as the DefectDojo database, and Postgres backups (hardening bucket).
- A cluster ingress controller or Cilium ingress/Gateway API, which would let the chart's own ingress path run live.
- A Mode B test consumer repo that proves the `@v1` adoption path against the live instance.
- Observing turning dedup on over existing findings, and the `manage.py dedupe` recompute on real data (ADR-026 NOT-verified items 1-2).
- Tracking internal DNS records in git instead of manual Pi-hole entries.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DDOJO-05 | DefectDojo chart validated live via private ArgoCD overlay deploy to the operator's homelab cluster | BLOCKING FINDING (ARC registration scope), Patterns 1-5, Pitfalls 1-9, ADR Recommendation, Validation Architecture (every row) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

**This repository (`security_solution/CLAUDE.md` and `.claude/rules/`):**
- It is a documentation repository. Canonical workflows and K8s packages live in `OttawaCloudConsulting/security-platform`. Document them here; do not ship them from here.
- ADRs in `docs/adr/` are **append-only**. ADR-027 (and ADR-028 if adopted) are new files plus rows in `docs/adr/README.md`. Never edit ADR-022 through ADR-026.
- Preserve the ASCII diagrams, the four-phase structure and the tool matrices in `development-security-stack-option-1.md`, if it is touched.
- Scripts run as `bash script.sh`. **Never `chmod +x`.** This applies in all three repositories.
- Anti-slop: on any failure, STOP, then REPORT (raw error, theory, proposal), then WAIT. No silent retries and no silent fallbacks.
- Verify every 3 actions on unfamiliar or risky work. Use the high-risk prediction format for destructive, irreversible or shared-environment actions: cluster syncs, secret sealing, tag moves, repo settings.
- Operator confirmation is required before git history rewrites, tag moves, public repo setting changes and merges.

**`occ-k8s-app-config/CLAUDE.md` (overlay repository; I read it this session):**
- `appset-apps` discovers `application-sets/*/*/argocd-overrides.yaml` **by file presence**. Deleting the file deletes the Application, and editing it edits the live spec. Read `docs/reference/argocd-overrides-guide.md` and `docs/argocd/argocd-overrides-adoption.md` before changing an Application. The guide exists [VERIFIED: ls].
- One override file per app directory, at its root (R32). No `spec.project` in overrides (F-10). `syncOptions` replaces rather than appends, so restate `CreateNamespace=true` and `ApplyOutOfSyncOnly=true` (F-12). `source: null` is needed with `sources:` (R8/F-11). `retry` goes under `syncPolicy` (R9). These come from the Nexus and CNPG override comments.
- The namespace equals the directory name, created via `CreateNamespace=true`. Do not add `Namespace` resources.
- AppProjects live in `application-sets/automation/argocd/templates/projects.yaml`. Enumerate kinds explicitly and never use wildcards.
- `externalTrafficPolicy: Local` is **rejected at admission** on any `vlan` 41/43/44 LoadBalancer Service.
- Secrets are SealedSecrets only. Never commit a raw `Secret`.
- Validate before committing:
  - `yamllint .`;
  - `helm template <release> application-sets/<project>/<app> > /dev/null` for Helm apps (`helm dependency update` if `Chart.yaml` changes);
  - `kubectl apply --dry-run=client` for raw manifests;
  - inspect the rendered projects, destinations and sync options for AppProject changes;
  - also run the conformance scripts `docs/argocd/conformance/c1.py` and `check_appconfig.py`, which exist [VERIFIED: ls] and are named by the homepage override comment.
- Use Argo CD for reconciliation. Never run a workstation `kubectl apply` for deployments.
- Argo CD CLI: `ARGOCD_AUTH_TOKEN=$(cat ~/.config/argocd/claude.token) argocd <cmd> --server argocd.infra.ottawacloudconsulting.com --grpc-web`. Never pass `--insecure`, and never log in with a username and password.
- Git: integration branch `main`, changes by PR. Write commit messages **through a file** (`.claude/scripts/gcommit` when present, else `git commit -F`), never heredoc or multiline `-m`. Cut a fresh branch from `main` after each PR closes.
- Have an explicit rollback plan for storage, PVCs, secrets and authentication changes, and for anything that can prune.

**`occ-k8s-cluster-config/CLAUDE.md` (read-only in this phase except the VLAN43 runbook row):**
- Commit via `bash .claude/scripts/gcommit`, since the heredoc commits hook is enforced.
- On an expired `argocd`/`aws` credential, **STOP** and report BLOCKED. Never work around it.
- Markdown must pass the repo's markdownlint config. This applies to the `cilium-l2-vantage-host-runbook.md` row addition.

**`security-platform`:** it has no CLAUDE.md [VERIFIED: ls]. Existing conventions apply: mode `100644` scripts, SHA-pinned actions, frozen required-check contexts (`scripts/set-required-checks.sh`), ADR-001 side-channel carve-out.

## BLOCKING FINDING: D-07 and D-08 cannot be carried out on this GitHub account

**This finding contradicts two locked decisions. The planner MUST put an operator decision checkpoint ahead of every ARC task. Do not quietly adapt around it.**

### Evidence (all measured in this session)
| Probe | Result | Tag |
|-------|--------|-----|
| `gh api users/OttawaCloudConsulting --jq .type` | `"User"` | [VERIFIED: GitHub API] |
| `gh api orgs/OttawaCloudConsulting` | `404 Not Found` | [VERIFIED: GitHub API] |
| `gh api user/orgs` | empty (the account belongs to no organisation) | [VERIFIED: GitHub API] |
| github/docs `data/reusables/actions/about-runner-groups.md` (fpt branch) | "To control access to runners at the organization level, organizations using the GitHub Team plan can use runner groups." | [CITED: github/docs source] |
| github/docs ARC auth how-to | fine-grained PAT: "Repository runners: **Administration: Read and write**"; "Organization runners: **Administration: Read**, **Self-hosted runners: Read and write**" | [CITED: github/docs content/actions/how-tos/manage-runners/use-actions-runner-controller/authenticate-to-the-api.md] |

`OttawaCloudConsulting` is a **personal user account**, not an organisation. None of the following exists for a user account:
- org-level runner registration;
- runner groups ("restricted to selected repositories", "Allow public repositories");
- the organisation permission `Self-hosted runners`.

Even a newly created **Free** organisation would get no custom runner groups, because runner groups need the Team plan. That conflicts with the zero-cost premise of the blueprint.

### Minimal replacement (recommended; operator must confirm)
- **Registration scope: repository.** Set `githubConfigUrl: https://github.com/OttawaCloudConsulting/security-platform` and **omit** `runnerGroup`, since ARC falls back to group ID 1 internally [VERIFIED: ARC controller source via Context7]. Only `security-platform` can target the runner. That preserves D-07's intent ("security-platform only") by the narrowest mechanism the account offers.
- **PAT: fine-grained, resource owner `OttawaCloudConsulting`, "Only select repositories" = `security-platform`.** Repository permission **Administration: Read and write**. Metadata: Read is added automatically [ASSUMED: general fine-grained PAT behaviour, not stated in the ARC doc]. This replaces D-08's org permission.
- **Accepted-risk delta for ADR-027/028:** repository Administration read/write is **broader than runner management**. On that one repository it also covers settings, webhooks, deploy keys and branch protection. A leaked PAT is therefore a repository-takeover credential for `security-platform`, not just a runner-registration credential. Because the blast radius is one repository and the PAT is SealedSecret-only, that is tolerable, but it must be stated as accepted rather than left silent.
- **Consequence for consumers (adoption guide):** with no runner group, each future consumer repo needs **its own** repository-scoped `AutoscalingRunnerSet`, with its own PAT or a PAT covering that repo too. The alternative is to move to an organisation on the Team plan. "Consumers are added to the group later" (D-07) becomes "consumers get their own scale set later".

## Summary

The deployment has four parts:
1. The Phase 26 wrapper chart runs in a two-source Argo CD Application under `occ-k8s-app-config/application-sets/platform/defectdojo/`, following the Nexus precedent. The chart ingress is disabled.
2. The overlay adds a standalone ghostunnel Deployment, a Certificate and a `LoadBalancer` Service on 10.40.3.65.
3. ARC 0.14.2 (controller plus one runner scale set) lives in the same repository and AppProject, following the CloudNativePG operator precedent.
4. A `security.yml` change routes only `defectdojo-import` and `defectdojo-cleanup` through `runs-on: ${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}`.

Every chart key the overlay needs exists in the pinned 1.9.53 subchart, and I rendered them all in this session: `host`, `alternativeHosts`, `siteUrl`, `extraConfigs`, `django.ingress.enabled: false`, `initializer.staticName` and `initializer.jobAnnotations`. The wrapper's TLS guard stands down when the ingress is off, and the session and CSRF cookies stay `Secure`. The default ARC runner image `ghcr.io/actions/actions-runner:2.337.0` (linux/amd64) contains `python3` 3.12 with every stdlib module the two jobs import, plus `curl`, `jq` and the ISRG Root X1 CA. I verified this by listing the image layers, so **no custom runner image is needed**.

Four findings change the plan's shape:
1. **The account-type blocker above.**
2. **CSRF mechanism, now identified.** Django 5.2.16 (DefectDojo 3.3.200's pin) skips both the Origin and Referer checks when a POST has **no `Origin` header** and the request is not `is_secure()`. That is why the kind login passed without `DD_CSRF_TRUSTED_ORIGINS`. It also means a curl login that sends only `Referer`, which is what `defectdojo-live-smoke.sh` does, would pass behind ghostunnel **even without the fix**. The live login check must therefore send `Origin: https://<host>`, as a browser does, on both hostnames.
3. **In-cluster DNS will not resolve the Pi-hole-only names.** `worker00` cannot resolve `homepage.infra…` (a Pi-hole-only name), and CoreDNS forwards to the node's `/etc/resolv.conf`. The runner pod therefore needs `hostAliases` pointing at the VIP. I rendered that key in the scale-set chart.
4. **`defectdojo-import-proof.yml` passes no secrets to `security.yml`.** Once `DEFECTDOJO_URL` is set, its import job runs on ARC and prints `SKIP`, and nothing reaches the live instance. The workflow's own header comment says the opposite and has to be corrected.

**Primary recommendation:** First, an operator checkpoint accepts repository-scoped ARC registration. Then deploy in this order:
1. DefectDojo overlay (ingress off, ghostunnel + LB VIP + Certificate), then `defectdojo-configure.sh` once and a second time for the no-change check.
2. The ARC controller and a repo-scoped scale set (runner image pinned to 2.337.0, `hostAliases` to 10.40.3.65).
3. Merge the `runs-on` change to `security-platform` `main`.
4. Only then set `DEFECTDOJO_URL`, `DEFECTDOJO_RUNS_ON` and the `DEFECTDOJO_API_TOKEN` secret, run the baseline and the PR lifecycle, and cut `v1.2.0` and move `v1` last.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| DefectDojo app (django/nginx/celery, initializer) | K8s workload (upstream chart via Argo source 1) | Postgres StatefulSet (bundled) | Generic-first: the public chart is untouched, and the overlay carries only env values (PROJECT.md key decision) |
| TLS termination + LAN exposure | Overlay (Argo source 2): ghostunnel Deployment + LB Service + Certificate | Cilium LB-IPAM/L2 announce, cert-manager DNS-01 | The cluster has no ingress controller (D-01). The homepage pattern is the convention |
| Hostname → VIP resolution (LAN clients) | Pi-hole 10.40.1.53 manual Local DNS (operator) | — | Records are not in git (D-04) |
| Hostname → VIP resolution (runner pod) | ARC scale-set pod template `hostAliases` | (fallback) ghostunnel Service with a pinned `clusterIP` | CoreDNS forwards to node resolvers that do not see Pi-hole records (measured) |
| CI job placement | `security.yml` `runs-on` expression reading caller `vars` | Caller repo variable `DEFECTDOJO_RUNS_ON` | Per-repo value never lives in public YAML (27 D-11 pattern) |
| Runner registration/lifecycle | ARC controller (arc-systems) + AutoscalingRunnerSet (arc-runners) | GitHub repo-level runner API | Ephemeral pods (D-09) |
| App settings (allowed hosts, CSRF origins, site URL) | Chart values in the overlay Application `valuesObject` | — | Render into the DefectDojo ConfigMap (verified render) |
| System Settings (dedup, RA days) | `scripts/defectdojo-configure.sh` (operator, superuser token) | — | D-13; superuser-only endpoint |
| CI identity | DefectDojo `ci-importer` user (staff, non-superuser), token in the GitHub secret | — | D-16 / ADR-024 |
| Evidence | `.planning/phases/29-…/evidence/` | `gh api`, `kubectl`, Argo Application status | ADR-022 precedent: values come from tools, never from recall |

## Standard Stack

### Core (all versions registry-verified this session)
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `kubernetes/defectdojo` wrapper (security-platform) | chart 0.2.0 → subchart `defectdojo` 1.9.53, app 3.3.200 | The workload under test | Locked (26 D-03). Pin a security-platform commit SHA (ADR-022 d2). `origin/main` is `c8027e6` today [VERIFIED: git] |
| Argo CD | v3.5.1 (live) | GitOps sync | [VERIFIED: kubectl image] |
| `gha-runner-scale-set-controller` | 0.14.2 (OCI `ghcr.io/actions/actions-runner-controller-charts`) | ARC controller + CRDs | Latest tag in the registry [VERIFIED: ghcr.io tags/list; GitHub release 2026-05-22] |
| `gha-runner-scale-set` | 0.14.2 | One AutoscalingRunnerSet | Must match the controller version [VERIFIED: registry] |
| `ghcr.io/actions/actions-runner` | 2.337.0 (linux/amd64 digest `sha256:5036480998…ec97`) | Runner container | Latest runner release 2026-08-26. Layer listing shows python3.12, curl, jq and the CA bundle [VERIFIED: registry layer listing] |
| `docker.io/ghostunnel/ghostunnel` | v1.11.3-distroless | L4 TLS terminator | Latest release 2026-08-22, same tag as homepage [VERIFIED: GitHub releases] |
| cert-manager `letsencrypt-dns01-prod` ClusterIssuer | live | Certificate for both SANs | Homepage precedent (D-01) |
| Cilium | v1.19.6, KPR=true, `bpf-lb-sock=true`, L2 announce on `bond0.43` | VIP + service LB | [VERIFIED: cilium-config, ds image] |

### Images the DefectDojo render pulls (D-14 "Bitnami image pull" reframed)
| Image | Registry |
|-------|----------|
| `defectdojo/defectdojo-django:3.3.200`, `defectdojo/defectdojo-nginx:3.3.200` | docker.io |
| `us-docker.pkg.dev/os-public-container-registry/defectdojo/bitnami/postgresql:17.6.0-debian-12-r4` | **Google Artifact Registry**, not docker.io/bitnami |
| `docker.io/valkey/valkey:9.1.0-alpine3.23@sha256:c9b7…9e02` | docker.io (digest-pinned) |

[VERIFIED: helm template render of the pinned tgz.] What D-14 calls the "Bitnami image pull" is therefore a GAR pull of a DefectDojo-maintained Bitnami rebuild. The measurement is the pod events (`Pulled`/`Successfully pulled`) for the postgresql-0 pod, not a docker.io reachability test.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Repo-scoped ARC (forced by the account type) | A new GitHub org on Team plan | Restores runner groups and org PAT scope, but costs money and moves repos. Out of the zero-cost premise |
| `hostAliases` in the runner pod | CoreDNS `hosts`/forward stanza for `infra.ottawacloudconsulting.com` → 10.40.1.53 | Cluster-wide blast radius. CoreDNS ConfigMap is not in either overlay repo (not verified to be GitOps-managed). Keep it as the last resort |
| `hostAliases` → VIP | `dnsPolicy: None` + `nameservers: [10.40.1.53]` on the runner pod | Pi-hole ad-blocking could break GitHub endpoints, and it loses cluster DNS. Rejected |
| Default runner image | A custom image | Not needed, since tooling was verified present |
| ARC chart in app-config `platform/` | `occ-k8s-cluster-config/application-sets/` | cluster-config holds cluster infrastructure (cilium, cert-manager, sealed-secrets, csi, trident, monitoring, headlamp), vendors chart tgz, and has no `argocd-overrides` + SealedSecret-in-overlay pattern. app-config `platform/cloudnative-pg` is the direct precedent for a CRD-owning operator (OCI source, SSA, prune off) |

**Installation:** none. This phase installs no packages on the workstation. Every component is a pinned chart or image consumed by Argo CD.

## Package Legitimacy Audit

Not applicable: this phase installs **no npm/PyPI/crates packages**. Slopcheck was not run because no package manager install is recommended. The external artifacts are OCI charts and container images. I verified each one against its canonical registry and upstream source repository:

| Artifact | Registry | Source Repo | Verification | Disposition |
|----------|----------|-------------|--------------|-------------|
| gha-runner-scale-set-controller 0.14.2 | ghcr.io | github.com/actions/actions-runner-controller | tags/list + chart tgz pulled and rendered | Approved |
| gha-runner-scale-set 0.14.2 | ghcr.io | same | same | Approved |
| actions-runner 2.337.0 | ghcr.io | github.com/actions/runner (Dockerfile read) | manifest + layer listing | Approved |
| ghostunnel v1.11.3-distroless | docker.io | github.com/ghostunnel/ghostunnel | releases API. Already running in homepage | Approved |
| defectdojo 1.9.53 (+ postgresql 16.7.27, valkey 0.25.8 subcharts) | raw.githubusercontent.com/DefectDojo helm-charts | github.com/DefectDojo/django-DefectDojo | Chart.lock digest (Phase 26) + vendored tgz | Approved (locked) |

**Packages removed:** none. **Packages flagged:** none.

## Architecture Patterns

### System Architecture Diagram

```
 LAN browser (VLAN4x)                         GitHub Actions (security-platform)
   │ DNS: Pi-hole 10.40.1.53                    │ pr-security / scheduled-security / proof
   │ defectdojo.{infra,home}… → 10.40.3.65      │   uses: ./.github/workflows/security.yml
   ▼                                            ▼
 ┌─────────────── L2 VIP 10.40.3.65:443 ───┐   5 scan jobs ── runs-on: ubuntu-latest (unchanged)
 │ Cilium L2 announce (bond0.43, vlan43)    │   defectdojo-import / -cleanup
 │ Service type=LoadBalancer, ETP=Cluster   │     runs-on: ${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}
 └───────────────┬─────────────────────────┘          │ (caller vars; unset ⇒ hosted, job-level
                 │                                    │  if: vars.DEFECTDOJO_URL != '' still gates)
                 ▼                                    ▼
      ghostunnel Deployment (ns defectdojo)    GitHub job queue ─► ARC listener (arc-runners)
      TLS: Secret defectdojo-tls (LE, 2 SANs)          │ long-poll, repo-scoped scale set
      --target=defectdojo-django:80                    ▼
                 │  plain HTTP, Host header     ephemeral runner pod (actions-runner:2.337.0)
                 │  preserved (L4)              hostAliases: defectdojo.infra… → 10.40.3.65
                 ▼                                     │ curl --proto =https (TLS verified by name)
      defectdojo-django Service :80 ◄──────────────────┘ via Cilium socket-LB hairpin (MEASURE)
        nginx → uwsgi (Django 5.2.16)
        ALLOWED_HOSTS = host + alternativeHosts
        CSRF_TRUSTED_ORIGINS = https://infra, https://home
                 │
                 ├─► celery-worker / beat ─► valkey (ephemeral)
                 └─► postgresql-0 (PVC on default SC; Bitnami NetworkPolicy: ingress 5432 from any)
```

### Recommended overlay layout (occ-k8s-app-config)
```
application-sets/platform/
├── defectdojo/                 # Application "defectdojo", ns defectdojo (Nexus precedent)
│   ├── argocd-overrides.yaml   # ONE per dir (R32); sources: [security-platform@SHA kubernetes/defectdojo, this dir]
│   ├── Chart.yaml              # source 2 rendered as a Helm chart (Nexus precedent)
│   ├── README.md
│   └── templates/
│       ├── sealedsecret-defectdojo.yaml              # wave -1: DD_ADMIN_PASSWORD, DD_SECRET_KEY, DD_CREDENTIAL_AES_256_KEY, METRICS_HTTP_AUTH_PASSWORD
│       ├── sealedsecret-defectdojo-postgresql-specific.yaml  # wave -1 (keys per chart README §1)
│       ├── sealedsecret-defectdojo-valkey-specific.yaml      # wave -1
│       ├── certificate.yaml                          # wave -1, both SANs (homepage form)
│       ├── ghostunnel-deployment.yaml
│       └── service.yaml                              # LB, 10.40.3.65, vlan "43", IPautoAssign "false", ETP Cluster
├── arc-systems/                # Application "arc-systems": gha-runner-scale-set-controller 0.14.2 (OCI), SSA, prune OFF
│   ├── argocd-overrides.yaml
│   └── README.md
└── arc-runners/                # Application "arc-runners": gha-runner-scale-set 0.14.2 + PAT SealedSecret
    ├── argocd-overrides.yaml
    ├── Chart.yaml
    └── templates/sealedsecret-arc-github-pat.yaml    # key github_token, wave -1
```
The directory basename becomes the Application name and the namespace. Using two ARC directories avoids the CNPG-style "recorded exception" `destination.namespace` override, and follows upstream's advice to keep the controller and runners in separate namespaces [ASSUMED: upstream recommendation from training; the separation itself is a normal ARC quickstart layout].

### Pattern 1: DefectDojo overlay values (verified by render)
```yaml
# argocd-overrides.yaml → sources[0].helm.valuesObject  (verified: helm template of the pinned tgz)
defectdojo:
  host: defectdojo.infra.ottawacloudconsulting.com          # also the probe Host header in django-deployment
  alternativeHosts:
    - defectdojo.home.ottawacloudconsulting.com             # → DD_ALLOWED_HOSTS "infra,home" (helper django.allowed_hosts)
  siteUrl: https://defectdojo.infra.ottawacloudconsulting.com   # → DD_SITE_URL
  django:
    ingress:
      enabled: false          # D-01. validate-tls.yaml only fires when enabled && activateTLS → stands down
      # activateTLS stays true (wrapper default) ⇒ DD_SESSION_COOKIE_SECURE / DD_CSRF_COOKIE_SECURE = "True" (rendered)
  extraConfigs:               # map-merges with the wrapper's two dedup guards (rendered: all three keys present)
    DD_CSRF_TRUSTED_ORIGINS: "https://defectdojo.infra.ottawacloudconsulting.com,https://defectdojo.home.ottawacloudconsulting.com"
  initializer:
    staticName: true
    keepSeconds: 0            # no ttlSecondsAfterFinished rendered (template guards on > 0)
    jobAnnotations:
      argocd.argoproj.io/hook: Sync
      argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```
- Use **`host` + `alternativeHosts` + `siteUrl`, never `extraConfigs.DD_ALLOWED_HOSTS` or `DD_SITE_URL`**. The ConfigMap template already emits both keys, so putting them in `extraConfigs` would produce **duplicate YAML keys** in the same `data:` map [VERIFIED: configmap.yaml lines 28-29 + `extraConfigs` toYaml at the end].
- `DD_CSRF_TRUSTED_ORIGINS` is parsed with `env.list` (comma-separated) [VERIFIED: settings.dist.py 3.3.200 line 66/679-680].
- **Do not set `DD_SECURE_PROXY_SSL_HEADER`.** ghostunnel adds no header, so enabling it would only make Django trust a client-supplied `X-Forwarded-Proto` passed straight through the L4 proxy.

### Pattern 2: ghostunnel as a standalone Deployment
Copy homepage's `tls` container verbatim, with these deltas:
- `--target=defectdojo-django.defectdojo.svc.cluster.local:80`. The Service is ClusterIP, port name `http` [VERIFIED: render].
- `--target-status`: homepage's loopback target does not apply. If kept, point it at an nginx-only path such as `/nginx_health` [ASSUMED: that nginx answers `/nginx_health` without Django host validation. The chart's own probes send `Host: <host>`, so measure it. If it is uncertain, drop `--target-status` and use the TCP-dial status].
- Keep `--timed-reload=300s` (ghostunnel does not watch cert files; homepage comment), the whole-directory secret mount (never subPath), the securityContext block, and `--disable-authentication`.
- Readiness: `/_status` on `:8082`. Liveness: tcpSocket.
- Run at least 1 replica. Two replicas are optional (ETP Cluster load-balances).
- **No NetworkPolicy** for the django Service. Namespace isolation is Out of Scope (REQUIREMENTS hardening bucket). Unlike homepage, DefectDojo authenticates, so its plaintext :80 staying reachable in-cluster is the hardening-bucket item and must be stated in ADR-027.

### Pattern 3: ARC scale set values (verified by render)
```yaml
githubConfigUrl: https://github.com/OttawaCloudConsulting/security-platform   # repo scope (BLOCKING FINDING)
githubConfigSecret: arc-github-pat          # pre-defined Secret (SealedSecret, key github_token) — never inline
runnerScaleSetName: occ-homelab-defectdojo  # == the runs-on label == DEFECTDOJO_RUNS_ON value
minRunners: 0
maxRunners: 2                                # import + cleanup never overlap per branch (shared concurrency group)
controllerServiceAccount:                   # REQUIRED under Argo: chart discovers it with `lookup`, which renders empty
  namespace: arc-systems
  name: arc-gha-rs-controller               # = <controller releaseName "arc">-gha-rs-controller (verified render)
template:
  spec:
    hostAliases:
      - ip: 10.40.3.65
        hostnames: [defectdojo.infra.ottawacloudconsulting.com]
    containers:
      - name: runner
        image: ghcr.io/actions/actions-runner:2.337.0
        command: ["/home/runner/run.sh"]
```
- No `containerMode`: the two jobs run `bash`/`python3`/`curl` directly and need no Docker. That avoids privileged dind.
- Controller Application: `ServerSideApply=true` is **required**. The four CRDs as compact JSON are 612,248 bytes (autoscalingrunnersets), 309,369 (autoscalinglisteners), 307,754 (ephemeralrunners) and 307,683 (ephemeralrunnersets). All exceed the 262,144-byte `last-applied-configuration` cap [VERIFIED: measured from the 0.14.2 tgz]. Automated prune stays **off** on the CRD-owning app (CNPG D5 precedent).

### Pattern 4: `security.yml` change shape (two lines + comments)
```yaml
  defectdojo-import:
    if: always() && github.event.action != 'closed' && vars.DEFECTDOJO_URL != ''
    runs-on: ${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}
  defectdojo-cleanup:
    if: github.event_name == 'pull_request' && github.event.action == 'closed' && vars.DEFECTDOJO_URL != ''
    runs-on: ${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}
```
- `jobs.<id>.runs-on` accepts the `github, needs, strategy, matrix, vars, inputs` contexts [CITED: github/docs contexts.md line 103].
- In a called workflow, `vars` resolves to the **caller** repository [CITED: docs variables reference; already relied on by `GATE_MODE` and `DEFECTDOJO_URL`].
- The five scan-job `runs-on: ubuntu-latest` lines and all job `name:` values stay unchanged, so the five required contexts are unchanged (`scripts/set-required-checks.sh`).
- **No tag is needed for the live proof.** All three local callers use `uses: ./.github/workflows/security.yml`, so the change is live on `main` once merged. The **`v1.2.0` (annotated) + lightweight `v1` move** is for Mode A/B consumers and comes **after** the live proof (ADR-018 ordering: the canonical file is correct before any tag is cut).
- **`v2.0` on security-platform is a GSD milestone tag** (`c6395e1 chore: remove REQUIREMENTS.md for v2.0 milestone`), not a workflow release. The next release is `v1.2.0`. `v1` and `v1.1.1` both point at `917352c` today [VERIFIED: git].

### Pattern 5: `defectdojo-import-proof.yml` — exact effect of D-10 and the guard decision
- **Exact effect (verified by reading the file on `origin/main`):** `scans` calls `security.yml` with **no `secrets:` block** (lines 73-77). Inside the callee, `secrets.DEFECTDOJO_API_TOKEN` is therefore empty. Once `DEFECTDOJO_URL` is set:
  1. the job-level `if:` is now true, so `scans / DefectDojo Import` **runs** instead of being skipped;
  2. `runs-on` sends it to the ARC runner;
  3. `dd-gate` prints `SKIP: DEFECTDOJO_API_TOKEN is not available to this run…`;
  4. download, import and verify are all skipped, and the job is green.

  **Nothing is imported into the live instance.** `defectdojo-cleanup` never runs there, because the proof workflow's `pull_request` uses the default types, which have no `closed`.
- **The file's header is now wrong in two places:**
  - "the defectdojo-import and defectdojo-cleanup jobs are skipped" (the opt-out regression proof) is no longer true at job level;
  - "`scans` additionally imports into the real instance" (lines 25-27) was never going to be true.

  Correct both comments in the same `security.yml` PR (the file is on the proof's paths filter anyway).
- **Stall risk:** `prove-import` has `needs: scans` with `if: always()`, so it waits for the whole `scans` reusable call, including the import job queued on ARC. If ARC is offline, the proof run stalls until GitHub cancels the queued job (about 24h).
- **Recommendation: comment correction plus an ADR-027 record, no functional guard.** The alternative is an additive `workflow_call` boolean input, for example `defectdojo_import: true`, that the proof passes as `false` and that is ANDed into both job-level `if:`s. That adds an interface input to a published workflow (v1.x surface, adoption-guide text, gate strings) only to protect a proof run against a runner outage. It can be added later if the stall is ever observed.

### Anti-Patterns to Avoid
- **Setting `DEFECTDOJO_URL`/`DEFECTDOJO_RUNS_ON` before the `runs-on` change is on `main` AND the ARC listener is Running.** Every pr-security, scheduled-security and proof run would then either call DefectDojo from a hosted runner (fails TLS/DNS, red side-channel) or queue for up to 24h.
- **Treating Synced+Healthy as evidence** (ADR-022). The initializer as a Sync hook only reports an exit code.
- **Adding `Pod` to the AppProject.** The chart's `defectdojo-unit-tests` Pod carries `helm.sh/hook: test-success`, which Argo CD skips as an unsupported hook [CITED: Argo CD helm.md "Unsupported hooks are ignored" / "skips manifests that include hooks not supported"].
- **Using bare `application`/`appproject` resource names** (ADR-022 item 6). Always use `applications.argoproj.io`.
- **Using `seal-secret.sh` with its default controller namespace.** The live controller namespace is `sealed-secrets` (ADR-022 d3).
- **Retargeting `defectdojo-live-smoke.sh`'s login as-is.** It sends only `Referer`, so it passes behind ghostunnel even without `DD_CSRF_TRUSTED_ORIGINS` and proves nothing about D-05 (see Pitfall 1).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Self-hosted runner lifecycle | Long-lived runner VM/Deployment with `config.sh` | ARC runner scale set (ephemeral, JIT registration) | Registration tokens, cleanup and autoscaling are handled. Ephemeral pods are D-09 |
| Runner → private hostname | Editing CoreDNS or `/etc/hosts` in the image | Pod `hostAliases` in `template.spec` | Scoped to runner pods only, and declarative (verified render) |
| TLS for DefectDojo | nginx TLS in the chart, or self-signed certs | ghostunnel + cert-manager DNS-01 Certificate | The existing cluster convention, with renewal handled by `--timed-reload` |
| Initializer ↔ Argo reconciliation | `ignoreDifferences` hacks, or a manual Job delete | `staticName: true` + Argo `Sync` hook + `BeforeHookCreation` + `keepSeconds: 0` | Argo's documented hook lifecycle; avoids TTL/selfHeal loops |
| ci-importer user + token | UI clicking with tokens pasted into a terminal | Reuse the proof harness's proven API sequence (`POST /api/v2/users/` as superuser → `POST /api/v2/api-token-auth/` as ci-importer), piped to `gh secret set` from a 0600 file | Already measured at 3.3.200 (P-USER, `mint_token`) |
| System Settings | Ad-hoc PATCHes | `bash scripts/defectdojo-configure.sh` | Idempotent: patches only drifted keys (D-13) |
| Secrets | Plain Secrets or chart-generated secrets | SealedSecrets at wave -1 | ADR-022 d3. Chart-generated secrets would rotate `DD_CREDENTIAL_AES_256_KEY` |

## Common Pitfalls

### Pitfall 1: A curl login "passes CSRF" without the fix (26 OQ4 mechanism, now identified)
**What goes wrong:** the live login check goes green whether or not `DD_CSRF_TRUSTED_ORIGINS` is set.
**Why:** Django 5.2.16 `CsrfViewMiddleware.process_view` works like this:
- if `HTTP_ORIGIN` is present, it runs `_origin_verified`, with the good origin built as `http://` because `is_secure()` is false behind an L4 proxy;
- else, only if `request.is_secure()`, it runs the Referer check;
- then the token check.

With no `Origin` header and a non-secure request, only the token is checked [VERIFIED: django/middleware/csrf.py @5.2.16; Django pin from DefectDojo 3.3.200 requirements.txt]. That explains the kind pass: ingress-nginx sent `X-Forwarded-Proto`, but `DD_SECURE_PROXY_SSL_HEADER` defaults to False. Browsers send `Origin` on POST, so they get `403 Origin checking failed` until `https://<host>` is trusted.
**How to avoid:** the live login check must send `-H "Origin: https://<host>"`, and should also run a **negative control**: the same POST with `Origin: https://evil.example` must return 403. Run it on both hostnames. Record the mechanism in ADR-027 as closing ADR-023's CSRF NOT-verified item. The chart README's "mechanism not established" caveat can then be corrected (a security-platform doc change, optional in this phase).
**Warning signs:** a login check that passes on the first deploy before `extraConfigs` is applied.

### Pitfall 2: Runner pod cannot resolve `defectdojo.infra…`
**What goes wrong:** `curl: (6) Could not resolve host`.
**Why:**
- CoreDNS is `forward . /etc/resolv.conf`, and the nodes use `10.40.4.1, 10.40.1.1, 10.30.1.1` [VERIFIED: Corefile + worker00 resolv.conf].
- None of those resolvers answer for Pi-hole-only names: `dig @10.40.4.1/10.40.1.1/10.30.1.1 homepage.infra…` returned empty, and `getent hosts` on worker00 returned `NO-RESOLVE` [VERIFIED].
- Only `@10.40.1.53` answers (homepage → 10.40.3.77).
- The name has no public record either.

**How to avoid:** use `hostAliases` in the scale-set pod template (Pattern 3). Measure it from a runner pod, or from an equivalent throwaway pod first (Validation Architecture).

### Pitfall 3: In-cluster hairpin to the L2 VIP
**What goes wrong:** the runner pod resolves the VIP but cannot connect.
**Why it probably works (MEDIUM):**
- Cilium runs with `kube-proxy-replacement=true` and `bpf-lb-sock=true`, and has no `bpf-lb-sock-hostns-only` key, so the socket LB is active in pod namespaces.
- LoadBalancer entries carry `SVC_FLAG_LOADBALANCER|ROUTABLE` in the BPF service map [VERIFIED config; CITED: cilium bpf/lib/lb.h].
- A connect() to 10.40.3.65:443 should therefore be translated to a ghostunnel backend without leaving the node.

This is not yet measured.
**Fallback if it fails:** pin `spec.clusterIP` on a ghostunnel ClusterIP Service in the overlay (a free address in the service CIDR, recorded in the README). Point `hostAliases` at that. TLS is still verified by hostname, because the cert SANs are unchanged. The cluster-wide CoreDNS `hosts` entry is the last resort.

### Pitfall 4: Initializer Job vs Argo CD (26 OQ2)
**What goes wrong:** the options below behave as follows.
| Setting | Result |
|---------|--------|
| upstream `staticName: false` | The name embeds `now` at minute precision (`initializer.jobname` helper), so each manifest regeneration yields a new Job name: OutOfSync, a re-run, and the old Job pruned [VERIFIED: template] |
| `staticName: true` + TTL 60 as a plain resource | TTL deletion makes the resource "missing", selfHeal recreates it, and the cycle loops |
| **Recommended** | `staticName: true`, Argo `Sync` hook, `BeforeHookCreation`, `keepSeconds: 0` |

Why the recommended setting holds: hooks are not part of the compared desired state. Argo deletes the previous Job right before creating the next one, and it warns against `ttlSecondsAfterFinished` on hook Jobs ("Argo CD needs to read the Job to find out how the phase went") [CITED: Argo CD sync-waves.md]. Adding an Argo hook annotation to the Job does **not** disable Helm-hook mapping on other resources, because the check is per resource (`Types()` falls back to Helm hooks only when that object has no Argo hook) [VERIFIED: argo-cd v3.5.1 gitops-engine/pkg/sync/hook/hook.go].
**Expected side observation:** the `defectdojo` ServiceAccount carries `helm.sh/hook: pre-install` + `before-hook-creation` + `resource-policy: keep`. Argo maps it to a **PreSync hook that is deleted and recreated on every sync**, so its UID changes [CITED: Argo helm.md mapping table]. This is harmless because every rendered DefectDojo pod has `automountServiceAccountToken: false` [VERIFIED: render].
**Falsifiers (reject the setting if any is observed):**
- the Application goes OutOfSync between syncs with no git change;
- the second sync does not create `defectdojo-initializer` with a new UID;
- the second-run logs show anything other than the idempotent path ("Admin user already exists; skipping", no new migrations applied);
- the operation hangs in the Sync phase.

### Pitfall 5: ARC under Argo CD
- **The CRDs exceed the client-side apply annotation cap**, so SSA is required (Pattern 3 numbers).
- **`controllerServiceAccount` must be explicit.** The chart's `lookup` renders empty under Argo, and the template calls `fail` ("No gha-rs-controller deployment found…") [VERIFIED: gha-runner-scale-set 0.14.2 _helpers.tpl lines 569-618].
- **Deletion ordering:** the scale set's manager Role/RoleBinding (and a chart-created github Secret, if used) carry `finalizers`. Deleting the `arc-runners` Application before the controller can strand them, so remove the scale set first, then the controller. `preserveResourcesOnDeletion: true` on appset-apps leaves resources unmanaged (ADR-022 tradeoff) [VERIFIED: templates contain `finalizers:`].
- **The AppProject needs new entries:**
  - destinations `defectdojo`, `arc-systems` and `arc-runners`;
  - sourceRepos `ghcr.io/actions/actions-runner-controller-charts` **and** `oci://ghcr.io/actions/actions-runner-controller-charts` (the CNPG precedent lists both spellings);
  - namespaced kinds `policy/PodDisruptionBudget` (Bitnami postgres PDB) and `actions.github.com/AutoscalingRunnerSet`.

  Everything else is already allowed live: Deployment, StatefulSet, Job, Service, ConfigMap, SA, Secret, SealedSecret, NetworkPolicy, Certificate, Role, RoleBinding, and cluster-scoped CRD, ClusterRole and ClusterRoleBinding [VERIFIED: live AppProject JSON].

### Pitfall 6: Pinned runner image vs GitHub's 30-day rule
**What goes wrong:** ARC registers scale sets with `DisableUpdate: true` [VERIFIED: controller source]. GitHub: "If you do not perform a software update within 30 days, the GitHub Actions service will not queue jobs to your runner" [CITED: github/docs self-hosted-runner-update-warning.md]. So 30 days after the **next** runner release, the pinned 2.337.0 image stops receiving jobs. The symptom is identical to "runner offline": the import job queues.
**How to avoid:** pin `2.337.0` (overlay R23 exact-pin rule) and record in ADR-027/028 that this is a **second cause** of the D-17 queue symptom. Give the bump procedure: new tag in `arc-runners` values → overlay PR → sync.

### Pitfall 7: Public repo + self-hosted runner + fork PRs
**What goes wrong:** `vars` are readable in fork-PR runs, so `runs-on` resolves to the self-hosted label. A fork PR's `pull_request` run also uses the **PR's own copy** of `pr-security.yml`/`security.yml`, and could rewrite any job to target the label. The runner group was the intended control, and it does not exist here. Repo-scope registration limits which repo can target the runner, but not which PR author.
**Current setting:** `approval_policy: first_time_contributors` [VERIFIED: `gh api repos/.../actions/permissions/fork-pr-contributor-approval`].
**How to avoid:** as an operator step, **before** `DEFECTDOJO_RUNS_ON` is set, raise the policy to `all_external_contributors` (Settings → Actions → "Require approval for all external contributors"). ADR-027/028 records the residual risk: an approved fork PR runs on the LAN, there is no egress NetworkPolicy (declined), and pods are ephemeral.

### Pitfall 8: Queued-job behaviour (for ADR-027, D-17)
- An offline or stale runner means the job **queues**. GitHub cancels queued jobs after about 24h [ASSUMED: the 24h queue limit is from training knowledge; the phrasing is already in CONTEXT D-17].
- `defectdojo-import`/`-cleanup` are not required checks, so merge is unaffected.
- The PR-close cleanup would then never run, which orphans `ci/<branch>`. Record it as recoverable: re-run the cleanup or DELETE the engagement manually.

### Pitfall 9: First-sync ordering
The SealedSecret has **no Argo health** on this cluster (ADR-022 d3), so wave -1 orders the apply but cannot wait for decryption. The Certificate at wave -1 is health-gated (Ready), which is the homepage precedent. Postgres reads its password Secret on first init only. If the postgres Secret arrives late and the pod crash-loops, kubelet retries. Do not delete the PVC to "fix" auth, or the data is lost (no backup, 26 D-06).

## Code Examples

### Live login check with an Origin header (replace the Referer-only POST)
```bash
# Source: Django 5.2.16 csrf.py process_view (verified); pattern adapted from scripts/defectdojo-live-smoke.sh KIND-LOGIN
host=defectdojo.infra.ottawacloudconsulting.com
jar="$(mktemp)"; form="$(mktemp)"
curl -sS -c "$jar" -o "$form" "https://${host}/login"
tok="$(sed -n 's/.*name="csrfmiddlewaretoken" value="\([^"]*\)".*/\1/p' "$form" | head -1)"
# positive: browser-equivalent Origin
curl -sS -b "$jar" -c "$jar" -H "Origin: https://${host}" -H "Referer: https://${host}/login" \
  --data-urlencode "username=admin" --data-urlencode "password@${ADMIN_PW_FILE}" \
  --data-urlencode "csrfmiddlewaretoken=${tok}" -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://${host}/login"
#   expect: 302 …/dashboard ; then GET /dashboard with the jar → 200
# negative control: foreign Origin must be refused
#   same POST with -H "Origin: https://evil.example"  → expect 403 ("Origin checking failed")
```

### Second-sync measurement (Argo)
```bash
# Source: ADR-022 25-05 method + Argo hook semantics (cited)
ctx=<homelab-context>
kubectl --context "$ctx" -n defectdojo get job defectdojo-initializer -o jsonpath='{.metadata.uid}{"\n"}' > uid1
kubectl --context "$ctx" -n defectdojo get sa defectdojo -o jsonpath='{.metadata.uid}{"\n"}' > sa1
# wait > 10 min, confirm no drift-triggered sync:
kubectl --context "$ctx" -n argocd get applications.argoproj.io defectdojo -o json \
  | jq '{sync:.status.sync.status, health:.status.health.status, rev:.status.sync.revisions, hist:[.status.history[]?|{id,revisions,deployedAt}]}'
ARGOCD_AUTH_TOKEN=$(cat ~/.config/argocd/claude.token) argocd app sync defectdojo --timeout 900 \
  --server argocd.infra.ottawacloudconsulting.com --grpc-web   # app-config CLAUDE.md auth form; same revision
kubectl --context "$ctx" -n argocd get applications.argoproj.io defectdojo -o json \
  | jq '.status.operationState.syncResult.resources[]|select(.hookType!=null)|{kind,name,hookType,hookPhase}'
kubectl --context "$ctx" -n defectdojo logs job/defectdojo-initializer --all-containers | tail -50
# expect: new Job UID ≠ uid1; SA UID ≠ sa1 (PreSync recreate); logs show "Admin user already exists"; no migrations applied
```

### ci-importer creation (operator-run, secrets never printed)
```bash
# Source: scripts/defectdojo-import-proof.sh P-USER + mint_token (measured at 3.3.200)
# 1. superuser header file (0600) from the operator-held token
# 2. POST /api/v2/users/ {username:"ci-importer", password:<gen 20 + "aA1!">, is_active:true, is_staff:true, is_superuser:false}
# 3. GET /api/v2/users/?username=ci-importer → assert is_staff=true is_superuser=false
# 4. POST /api/v2/api-token-auth/ as ci-importer → token to a 0600 file
# 5. gh secret set DEFECTDOJO_API_TOKEN -R OttawaCloudConsulting/security-platform < tokenfile ; shred/rm files
```

### Postgres NetworkPolicy on Cilium (D-14)
```bash
# Rendered policy: podSelector primary; ingress ports [5432] with NO from (allowExternal: true); egress [{}]
kubectl -n defectdojo get netpol defectdojo-postgresql -o yaml
kubectl -n kube-system exec ds/cilium -- cilium-dbg endpoint list | grep -i postgresql   # policy enforcement: ingress Enabled
# positive: initializer migrations + django Ready (allowed path). Cross-ns: throwaway pod `nc -zvw3 defectdojo-postgresql.defectdojo 5432` → open (expected, allowExternal)
# negative: throwaway pod → <pg-pod-IP>:5433 (or any non-5432) → dropped; confirm with
hubble observe --namespace defectdojo --verdict DROPPED --last 50
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Legacy ARC (`RunnerDeployment`, summerwind) | Runner scale sets (`gha-runner-scale-set*`, `actions.github.com` CRDs) | GA 2023. Chart 0.14.2 on 2026-05-22 | Use the scale-set charts only |
| Runner image on Ubuntu 22.04 (jammy) | `runtime-deps:8.0-noble` (Ubuntu 24.04, python3.12) | Current Dockerfile | python3 is present transitively via `software-properties-common` |
| Bitnami images from docker.io | DefectDojo-hosted GAR rebuild (`os-public-container-registry/defectdojo/bitnami/postgresql`) | Chart 1.9.x | Pull from us-docker.pkg.dev |
| Django CSRF Referer-only reasoning | Origin-header check first (Django ≥4.0) | Django 4.0 | Trusted origins must include the scheme, and curl tests must send Origin |

**Deprecated/outdated:** the "org runner group restricted to selected repos" model does not apply to user accounts (BLOCKING FINDING).

## ADR Recommendation (discretion under D-17)

**Write ADR-028 for ARC**, separate from ADR-027:
- ARC is reusable CI infrastructure with its own lifecycle (chart and runner-image bumps, the 30-day rule, PAT rotation) and its own accepted risks (public repo on a self-hosted runner, repo Administration read/write PAT, no egress policy, the fork-approval policy).
- It carries the D-07/D-08 deviation forced by the account type.
- Future consumers will need their own scale sets under ADR-028, not under the DefectDojo record.

ADR-027 then covers the DefectDojo live validation: exposure, the CSRF mechanism, second-sync results, the NetworkPolicy observation, the D-11 results and `DEFECTDOJO_RUNS_ON`. It cites ADR-028 for runner mechanics. Both are new files plus rows in `docs/adr/README.md` (append-only).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GitHub cancels a queued job after about 24h | Pitfall 8 | The ADR wording is off. Low |
| A2 | nginx answers `/nginx_health` without Django host validation, so ghostunnel `--target-status` can use it | Pattern 2 | ghostunnel readiness is never Ready. Measure it or drop `--target-status` |
| A3 | Cilium socket-LB makes the L2 VIP reachable from pods (hairpin) | Pitfall 3 | The runner cannot connect. The pinned-clusterIP fallback applies |
| A4 | Upstream recommends separate controller/runner namespaces | Layout | None functionally. It is a layout preference |
| A5 | ghostunnel `--target` accepts a DNS name (`svc.cluster.local:80`) | Pattern 2 | Use the Service ClusterIP instead. Low |
| A6 | Fine-grained PAT "Administration: Read and write" on a user-owned repo is sufficient for ARC repo-scope registration (docs list it for repository runners; not exercised on a user account here) | BLOCKING FINDING | ARC listener auth fails. Fall back to a classic PAT with `repo` scope (docs), which is broader |
| A7 | The CoreDNS ConfigMap is not GitOps-managed (not found in either overlay repo by directory listing; not exhaustively grepped) | Alternatives | Only matters for the last-resort fallback |

## Open Questions (RESOLVED)

> Resolutions: OQ1 by the D-07/D-08 amendment (repo-scoped runner); OQ2 by the D-11 step 5 amendment; OQ3 deferred to the operator checkpoint in plan 29-07 Task 1; OQ4 by the D-16 amendment (operator admin token used workstation-side). See 29-CONTEXT.md.

1. **Does the operator accept repository-scoped ARC (BLOCKING FINDING)?**
   - What we know: org-level registration, runner groups and the org PAT permission are impossible on a user account.
   - Recommendation: Wave 0 operator checkpoint. Record the answer in ADR-028. Everything ARC-related waits on it.
2. **D-11 step 5 "duplicates re-parented" may be vacuous in the stated sequence.**
   - What we know: with `ci/main` imported first, PR copies are the duplicates, and deleting the PR engagement deletes them. A `ci/main` finding is re-parented only if it is a duplicate **of a PR finding**, which needs `ci/main` to import that finding while the PR is open (TRIAGE.md lines 24, 122).
   - The sequence closes the PR unmerged and reimports `main` from `main`, so the new finding never reaches `ci/main`.
   - Recommendation: assert what the sequence can prove. (a) `GET /api/v2/engagements/?product=<id>&name=ci/<branch>` returns count 0. (b) `ci/main` finding count and every disposition are unchanged. (c) No finding in the product has `duplicate_finding` pointing at a deleted id. Record "re-parent not exercised live (proven on kind in Phase 28)", unless the operator wants a variant that pushes the finding to `main` (which contradicts "close unmerged").
3. **VLAN30 Pi-hole (10.30.1.53) entries (D-04 open check).**
   - It did not answer DNS from this workstation (timeout), so it cannot be checked from here. It is an operator check from a VLAN30 client, and it does not block the runner path.
4. **Who performs the D-11 dispositions?**
   - Recommendation: the operator's superuser/admin token (a human triage action, never stored in GitHub). The RA `owner` is the admin user id, as in P-DISPOSITION. `ci-importer` stays import-only in practice.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| kubectl + homelab context | all live checks | ✓ | client 1.37 / server 1.34.1 (skew warning, reads work) | — |
| argocd CLI | second-sync trigger | ✓ | present (session may expire; CLAUDE.md of cluster-config says STOP on expired auth) | `kubectl` annotate refresh + patch operation |
| helm | offline renders | ✓ | v4.3.0 | — |
| kubeseal + overlay `scripts/seal-secret.sh` | SealedSecrets | ✓ | present | — |
| gh (user `OttawaCloudConsulting`) | vars/secret set, run evidence | ✓ | logged in. **No `admin:org`, and there is no org** | — |
| hubble CLI + hubble-relay | NetworkPolicy drop evidence | ✓ | relay 1/1 running | `cilium-dbg monitor --type drop` |
| jq, yq, shellcheck, actionlint | gates | ✓ | actionlint 1.7.12 | — |
| docker (local) | not needed | ✓ (pull from ghcr.io stalled this session) | 28.3.2 | registry API (used) |
| ssh to nodes | DNS evidence | ✓ | `k8w00` worked | — |
| Pi-hole 10.40.1.53 admin | DNS records | operator-only | — | none (operator step) |

**Missing dependencies with no fallback:** none for execution. The operator-only steps are listed in CONTEXT specifics.

## Validation Architecture

**Principle (ADR-022):** Synced + Healthy is **not** evidence. Every verdict comes from a measured value (API field, log line, UID, run/job metadata), captured into `.planning/phases/29-defectdojo-live-validation/evidence/` with run IDs and timestamps.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Standing bash gates (repo convention). Recommended new sibling script `repos/security-platform/scripts/defectdojo-homelab-validate.sh`, modelled on `nexus-homelab-validate.sh`: required `--url`, `--context`, `--sync-pass first\|second`, no defaults, `NOTHING RAN` when nothing executed |
| Config file | none. Wave 0 creates the script |
| Quick run command | `bash scripts/check-defectdojo-chart.sh` (offline, security-platform) + `bash scripts/check-adoption-guide.sh` (this repo) |
| Full suite command | `bash scripts/defectdojo-homelab-validate.sh --url https://defectdojo.infra.ottawacloudconsulting.com --context <ctx> --sync-pass second` + D-11 API assertion script/run evidence |

### Success criteria → measurements
| SC / Req | Behavior | Type | Automated command / evidence | Exists? |
|----------|----------|------|------------------------------|---------|
| DDOJO-05 SC1 | Application `defectdojo` generated from the overlay, Synced/Healthy at the pinned SHA, no ComparisonError | live read | `kubectl get applications.argoproj.io defectdojo -o json` → `evidence/29-*-first-sync-application.json` | ✅ (kubectl) |
| SC1 | All images pulled (django/nginx docker.io, postgres GAR, valkey digest) | live read | `kubectl -n defectdojo get events --field-selector reason=Pulled` + `get pods -o jsonpath` image IDs | ✅ |
| SC1 | TLS: served cert is LE prod, both SANs, verified by the system trust store | live | `curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}' https://<both hosts>/login` → `200 0`; `openssl s_client -servername` SAN dump | ❌ Wave 0 (in validate script) |
| SC1 / D-05 | Login with `Origin: https://<host>` → 302 + `/dashboard` 200, on **both** hosts. Foreign Origin → 403 | live | validate script `HOMELAB-LOGIN-ORIGIN-{INFRA,HOME}`, `HOMELAB-CSRF-FOREIGN-403` | ❌ Wave 0 |
| SC1 | Celery broker round-trip | live | `kubectl exec deploy/defectdojo-celery-worker -- celery -A dojo inspect ping -t 5` (26 KIND-CELERY-PING) | ❌ Wave 0 (reuse) |
| D-13 | configure.sh first run patches the drifted keys; the second run reports no change | live | `bash scripts/defectdojo-configure.sh` ×2 → `evidence/29-*-configure-{1,2}.txt`, second shows zero PATCH | ✅ script exists |
| D-14 idempotency | Second sync: new initializer UID, SA UID changes (PreSync), logs show the idempotent path, app not OutOfSync between syncs, data preserved (product/finding counts equal before/after) | live | Code Example "Second-sync measurement" + `GET /api/v2/products/?name=…` counts → `evidence/29-*-second-sync-*.{json,log}` | ❌ Wave 0 |
| D-14 netpol | Postgres NetworkPolicy enforced: 5432 open cross-namespace (allowExternal), non-5432 dropped | live | `cilium-dbg endpoint list`, throwaway pod `nc`, `hubble observe --verdict DROPPED` | manual-with-evidence |
| Reachability | Pod-level: NXDOMAIN without hostAliases; TLS 200 with hostAliases → VIP (hairpin) | live | throwaway pod (runner image 2.337.0) `getent hosts` + `curl --resolve host:443:10.40.3.65 https://host/login` **before** `DEFECTDOJO_URL` is set | manual-with-evidence |
| ARC | Listener Running; scale set registered on the repo; a job lands on it | live | `kubectl -n arc-runners get autoscalingrunnersets,pods`; `gh api repos/OttawaCloudConsulting/security-platform/actions/runners`; per run `gh run view <id> --json jobs --jq '.jobs[]|{name,runnerName,labels,conclusion}'` → the import job's `runnerName`/`labels` show the scale set, while the five scan jobs show hosted runners | ✅ (gh) |
| D-06/D-09 | Unset `DEFECTDOJO_RUNS_ON` → hosted (regression). Set → ARC | static + live | `actionlint .github/workflows/security.yml`; yq assert that exactly two `runs-on` lines use the expression and five remain `ubuntu-latest`; required contexts unchanged (`gh api …/branches/main/protection/required_status_checks`) | ❌ Wave 0 (yq check; could extend `check-workflow-uploads.sh` or a new gate) |
| DDOJO-02 live | Baseline `workflow_dispatch` of scheduled-security on main → `ci/main` engagement with N findings; dd-verify green | live | `gh workflow run scheduled-security.yml`; `GET /api/v2/engagements/?product=<id>&name=ci/main`, `findings/?test__engagement=E&limit=1` count | API assertions ❌ Wave 0 |
| D-11 step 2 | On `ci/<branch>`: pre-existing findings `duplicate=true`, each `duplicate_finding` in a `ci/main` test; `active=true&duplicate=false` count == 1 and it is the introduced finding | live API | TRIAGE.md filters verbatim: `findings/?test__engagement=$ENG&active=true&verified=false&false_p=false&out_of_scope=false&risk_accepted=false&duplicate=false&is_mitigated=false` | ❌ Wave 0 |
| D-11 steps 3-4 | FP / OOS PATCH + RA POST (90-day expiry, reason) on `ci/main` originals. After a `workflow_dispatch` reimport, `false_p`, `out_of_scope` and `risk_accepted` remain true with the same `active`/`is_mitigated` state (TRIAGE table) | live API | TRIAGE.md PATCH/POST bodies. Read-back before/after → evidence JSON | ❌ Wave 0 |
| D-11 step 5 | PR closed unmerged: cleanup job ran on ARC; `engagements/?name=ci/<branch>` count 0; `ci/main` counts and dispositions unchanged; no dangling `duplicate_finding` | live API | see Open Question 2 | ❌ Wave 0 |
| D-10 proof side effect | Proof run: `scans / DefectDojo Import` ran on ARC and logged `SKIP`; product finding count unchanged | live | `gh run view <id> --log --job <id> \| grep 'SKIP: DEFECTDOJO_API_TOKEN'` + count before/after | ✅ (gh) |
| D-09 docs | Adoption guide documents `DEFECTDOJO_RUNS_ON` | offline | `bash scripts/check-adoption-guide.sh` after adding `"DEFECTDOJO_RUNS_ON"` to the DEFECTDOJO-SECTION required strings (line ~272) | ✅ gate exists (edit needed) |
| D-09 release | `v1.2.0` annotated and `v1` lightweight at the same commit | live | `gh api repos/…/git/ref/tags/v1 --jq .object.type` == `commit`, `v1.2.0` → `tag` → same commit (ADR-018 method) | ✅ |
| D-12 | Scheduled path via dispatch (required). Cron run recorded if observed | live | `gh run list -w scheduled-security.yml --json event,createdAt,databaseId` | ✅ |

### Sampling Rate
- **Per task commit:** `bash scripts/check-adoption-guide.sh` (this repo). For security-platform changes: `actionlint`, `shellcheck scripts/*defectdojo*.sh`, `bash scripts/check-defectdojo-chart.sh`.
- **Per wave merge:** a render of the overlay (`helm template` with the overlay values against the pinned SHA's chart), plus the overlay repo's own `conformance` check (c1.py / check_appconfig.py per the homepage override comment).
- **Phase gate:** the validate script `--sync-pass first` (0 FAIL, the expected SECOND-SYNC skip), then `--sync-pass second` (ALL PASS, 0 skipped), plus D-11 evidence complete, before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `repos/security-platform/scripts/defectdojo-homelab-validate.sh`: TLS, the Origin login on both hosts plus the foreign-Origin 403, celery ping, and second-sync checks (initializer UID/log, SA UID, counts preserved)
- [ ] A D-11 API assertion helper (script or documented `curl`+`jq` block run by the operator) using the TRIAGE.md filters verbatim, emitting evidence JSON
- [ ] `scripts/check-adoption-guide.sh`: add `DEFECTDOJO_RUNS_ON` to the required strings
- [ ] A yq/actionlint assertion on the `runs-on` shape (exactly 2 expression lines, 5 `ubuntu-latest`)
- [ ] Throwaway reachability pod manifest (runner image 2.337.0, with and without hostAliases) for the pre-`DEFECTDOJO_URL` measurement

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Admin password in a SealedSecret (read on first boot only). CI uses a `ci-importer` staff non-superuser token. The superuser token is operator-held and never in GitHub |
| V3 Session Management | yes | `DD_SESSION_COOKIE_SECURE`/`DD_CSRF_COOKIE_SECURE=True` stay on with ingress off (rendered). CSRF trusted origins are limited to the two exact https origins |
| V4 Access Control | yes | Runner registration scoped to one repo. Fork-PR approval raised to all external contributors. Import/cleanup jobs skip fork/Dependabot runs (dd-gate) |
| V5 Input Validation | partial | Existing `--form-string` / https-only guards in security.yml (ADR-025) are unchanged |
| V6 Cryptography | yes | LE prod ECDSA-256 cert via cert-manager. TLS verified by the runner (`--proto =https`, system CA). No `DEFECTDOJO_INSECURE` |
| V9 Communication | yes | LAN-only VIP. Plaintext django :80 reachable in-cluster (no NetworkPolicy, hardening bucket) |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Fork PR edits the workflow to target the self-hosted label | Elevation of Privilege | Require approval for all external contributors. Ephemeral pods. Repo-scoped registration. Accepted residual (no egress policy) |
| Leaked ARC PAT (repo Administration RW) | Elevation of Privilege | SealedSecret only, never printed. Single-repo scope. Expiry forces rotation (accepted) |
| Spoofed `X-Forwarded-Proto` through the L4 proxy | Spoofing | Leave `DD_SECURE_PROXY_SSL_HEADER` unset (False) |
| Cross-site POST | Tampering | Django CSRF with exact trusted origins. Negative-control test with a foreign Origin |
| Superuser token exposure | Information Disclosure | 0600 file, header-file curl (`-H @file`), never on argv. configure.sh refuses group/other-readable files |
| Stale runner silently stops taking jobs | Denial of Service | Documented 30-day bump. The job is never a required check |

## Sources

### Primary (HIGH confidence)
- Live cluster reads (2026-09-26): nodes, namespaces, the `platform` AppProject, LB pools and allocations, L2 policies, cilium-config, CoreDNS Corefile, the argocd-server image, the admission policies
- GitHub API reads: account type, fork-PR approval policy, repo runners (0), tags, and release list for ARC/runner/ghostunnel
- ghcr.io registry API: ARC chart tags (0.14.2), runner image manifest/config/layers (2.337.0 amd64)
- Rendered: the defectdojo 1.9.53 vendored tgz with draft overlay values; ARC 0.14.2 charts with draft values
- `/argoproj/argo-cd` (Context7): helm.md hook mapping table, sync-waves.md delete policies and the TTL warning; argo-cd v3.5.1 `gitops-engine/pkg/sync/hook/hook.go`
- `/actions/actions-runner-controller` (Context7): scale-set creation and runner-group lookup
- github/docs source: ARC auth how-to (PAT permissions), about-runner-groups reusable, the runner update warning, contexts.md (runs-on contexts)
- DefectDojo 3.3.200 `dojo/settings/settings.dist.py` and `requirements.txt` (Django 5.2.16); Django 5.2.16 `django/middleware/csrf.py`
- actions/runner `images/Dockerfile` (main)

### Secondary (MEDIUM confidence)
- `/cilium/cilium/v1.19.1` (Context7): bpf/lib/lb.h service flags, socket-LB docs (hairpin inference)

### Tertiary (LOW confidence)
- none relied on

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH. Every version was read from a registry or the live cluster.
- Architecture: HIGH for chart keys and Argo semantics, which were rendered or cited. MEDIUM for hairpin, which must be measured.
- Pitfalls: HIGH. The CSRF mechanism, DNS, account type, CRD sizes and the lookup failure were all verified.

**Research date:** 2026-09-26
**Valid until:** 2026-10-26. The runner image's 30-day clock starts at the next actions/runner release, so re-check that tag before execution if planning slips.

**Session note:** during research, a mistaken `git checkout origin/main --` briefly detached HEAD in `repos/security-platform`. The tree was clean, and the branch `feature/phase-28-defectdojo-dedup-and-triage` was restored immediately (`git status` confirmed). No cluster object was created or modified, and nothing was pushed.
