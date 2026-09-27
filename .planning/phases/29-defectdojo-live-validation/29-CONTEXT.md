# Phase 29: DefectDojo Live Validation - Context

**Gathered:** 2026-09-26
**Status:** Ready for planning

<domain>
## Phase Boundary

DDOJO-05: the Phase 26 DefectDojo chart is deployed to the operator's homelab cluster through the private ArgoCD overlay (`occ-k8s-app-config/application-sets/platform/`). This phase also proves two things live, against that deployment and through real GitHub Actions runs:

- CI import (Phase 27) works end to end.
- Dedup and triage (Phase 28) work end to end.

The phase also closes the reachability question that 27 D-17 deferred: how GitHub Actions import jobs reach a DefectDojo that sits on the private LAN. It closes the Phase 26/28 items handed forward as well:

- the CSRF login check behind a new proxy;
- second-sync idempotency and `initializer.staticName`;
- the Bitnami Postgres NetworkPolicy on Cilium;
- the ADR-026 bootstrap hand-forward.

NOT in this phase:
- A cluster-wide ingress controller, Gateway API or Cilium ingress. Exposure follows the existing LB VIP + ghostunnel convention (D-01).
- Backup automation, runner-egress NetworkPolicy, monitoring and alerting (the hardening bucket).
- A Mode B test consumer repo. `security-platform` itself is the importer (D-10).
- Observing a cron-fired 06:00 scheduled run as a closing requirement (D-12).

</domain>

<decisions>
## Implementation Decisions

Carried forward, not re-decided:
- Claude has direct kubeconfig access and git access to the overlay repo (25 D-01/D-02).
- The overlay uses the existing `platform` AppProject, amended by enumerated kinds, and a two-source Application pinned to a `security-platform` commit (ADR-022 decisions 1-2).
- Secrets are SealedSecrets at sync-wave `-1` (ADR-022 decision 3, 26 D-13).
- DefectDojo stays pinned at 1.9.53 / 3.3.200 (26 D-03). Postgres persistence is on and Valkey is ephemeral (26 D-08). There is no backup provision (26 D-06).

### Exposure and TLS
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

### Runner reachability
- **D-06:** CI reaches DefectDojo through a **self-hosted runner** from actions-runner-controller (ARC, runner scale set) running in the homelab cluster. **Only `defectdojo-import` and `defectdojo-cleanup`** use it. The five scan jobs stay on `ubuntu-latest`.
- **D-07 (amended 2026-09-26, supersedes the org-level wording):** The runner is registered at **repository scope on `security-platform`** (`githubConfigUrl` = the repo URL, no `runnerGroup`). Research verified `OttawaCloudConsulting` is a personal `User` account (`orgs/OttawaCloudConsulting` returns 404), so org-level registration and runner groups do not exist. Each future consumer repo gets its own runner scale set. The operator ruled this on 2026-09-26.
- **D-08 (amended 2026-09-26):** ARC authenticates with a **fine-grained PAT scoped to the `security-platform` repository only**, with repository permission **Administration: Read and write** (the minimum for repo-scoped runner registration). The PAT is stored as a SealedSecret. This permission is broader than runner management on that repo (settings, webhooks, branch protection); ADR-028 records it as an accepted risk. The operator chose a PAT over a GitHub App, and PAT expiry means manual rotation (accepted, see Accepted Risks).
- **D-09:** Routing works through an **optional caller repo variable `DEFECTDOJO_RUNS_ON`**, read in the callee. This is the same mechanism as `DEFECTDOJO_URL` (27 D-11). When it is unset, the two jobs keep `ubuntu-latest`, and old callers work unchanged. This is a `security.yml` change, so it brings:
  - an additive v1.x tag and a `v1` move (ADR-018, 27 D-16);
  - an adoption-guide update, with `bash scripts/check-adoption-guide.sh` kept green;
  - a new ADR (D-17).

  Runner hardening: **ephemeral pods only** (the ARC default). The operator explicitly declined a runner-egress NetworkPolicy.

### Live proof scope
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
  5. **Close the PR unmerged**, and assert that the engagement is deleted, `ci/main` finding counts and dispositions are unchanged, and no finding references a deleted finding as its duplicate. (Amended 2026-09-26 by operator ruling: re-parenting cannot be exercised live because no `ci/main` finding is a duplicate of a PR finding; ADR-027 records re-parenting as NOT exercised live.)

  Assertions check API state, not HTTP status.
- **D-12:** **`workflow_dispatch` of the scheduled caller is enough** for the scheduled path. A cron-fired 06:00 America/Toronto run is observed only if it lands before close, and is then recorded. It does not block close.
- **D-13:** `bash scripts/defectdojo-configure.sh` runs **once, before the first live import**, right after the first Synced+Healthy. It uses an operator-held superuser token that is never stored in GitHub. A second run must show no change. As a result, ADR-026 NOT-verified item 1 (turning dedup on over existing findings) stays **open and not exercised**, and ADR-027 records that.
- **D-14:** Measured live, never assumed. Research proposes how to measure each:
  - Second-sync idempotency, including the `initializer.staticName` choice and how ArgoCD treats the TTL-deleted initializer Job (26-RESEARCH OQ2, ADR-023 NOT-verified item 4).
  - Bitnami Postgres NetworkPolicy behaviour on Cilium (26-RESEARCH OQ7).
  - Bitnami image pulls succeeding on the homelab.

### Data layer and tokens
- **D-15:** **Bundled Bitnami Postgres** (26 D-05 default), exactly as shipped, so the live run validates the defaults. The CloudNativePG operator in `platform/cloudnative-pg` is not used.
- **D-16:** The CI token belongs to a **dedicated least-privilege user**. Per ADR-024, that is a `ci-importer` user with `is_staff=true` and `is_superuser=false`, the smallest identity proven able to import, auto-create a Product Type and delete an engagement at 3.3.200. The superuser token is used only for D-13 and is held by the operator.

### Records
- **D-17:** Write **ADR-027** for the homelab DefectDojo live validation: exposure via LB VIP + ghostunnel, ARC reachability, `DEFECTDOJO_RUNS_ON`, the proof results and the accepted risks. Add its row to `docs/adr/README.md`. Research decides whether ARC needs its own ADR (ADR-028). ADRs are append-only, so do not edit ADR-022 to ADR-026.
  - The ADR must also state that the import job **queues, rather than fails,** when the named runner is offline. GitHub cancels a queued job after about 24h. Merge is unaffected because the job is not a required check, and it must never become one (27 D-03).
  - Mark DDOJO-05 Complete in `.planning/REQUIREMENTS.md`. Update the chart README's DDOJO-05 row.

### Operator rulings after research (2026-09-26)
- **D-18:** The pod-to-VIP reachability probe (runner image, with and without `hostAliases`) runs as a **one-off `kubectl run --rm` ephemeral pod** from the workstation. The operator waived the overlay repo's no-workstation-`kubectl apply` rule for this measurement only. Nothing persistent is created; the pod is deleted after, and output is captured to `evidence/`.
- **D-19:** The VLAN43 allocation table in `occ-k8s-cluster-config/docs/upgrade/cilium-l2-vantage-host-runbook.md` is **refreshed from a live `kubectl get svc -A` read**, not only appended: add .65 / DefectDojo, correct the stale counts and the `.77`/`.60` ownership, and update the table date.
- **D-20 (carried forward from ADR-022, not a new ruling):** ADR-027 and ADR-028 follow the ADR-022 address rule: they describe the design and do not record homelab addresses, hostnames, node names or context names.

### Claude's Discretion
- The overlay directory name. `platform/defectdojo/` follows the Nexus precedent.
- Where ARC lives: `occ-k8s-cluster-config` or `occ-k8s-app-config`, following whichever convention fits a cluster-wide controller. It also covers the ARC chart version, and the scale-set name and label.
- The `initializer.staticName` value and any ArgoCD ignore or hook settings, based on the measurement in D-14.
- The ghostunnel image tag (homepage uses `ghostunnel/ghostunnel:v1.11.3-distroless`) and how cert reload is handled; homepage's deployment carries a comment on this.
- How `ci-importer` and its token are created: manual operator steps, or a scripted step run by the operator.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirement and project constraints
- `.planning/REQUIREMENTS.md`: DDOJO-05 and the Out of Scope table (hardening bucket).
- `.planning/PROJECT.md` §Key Decisions: "v3.0 K8s packages: generic-first, not private-then-strip". The private overlay holds only env values and the Application.
- `.planning/ROADMAP.md`: the Phase 29 goal.

### Prior phase context and hand-forwards
- `.planning/phases/25-nexus-live-validation/25-CONTEXT.md` and `docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md`: the live-validation precedent (AppProject amend, two-source pin, SealedSecret wave, no-ingress finding, second-sync measurement).
- `.planning/phases/26-defectdojo-generic-chart/26-CONTEXT.md` and `26-RESEARCH.md` Open Questions 2, 4, 6 and 7: staticName, CSRF, homelab readiness, the Postgres NetworkPolicy.
- `docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md` §What was NOT verified, items 1-4.
- `.planning/phases/27-defectdojo-ci-auto-import/27-CONTEXT.md` (D-03, D-11, D-12, D-16, D-17) and `27-RESEARCH.md` OQ5: the proof workflow side effect.
- `docs/adr/adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md`: the `ci-importer` staff/non-superuser identity and the token permission set.
- `docs/adr/adr025-defectdojo-import-https-only.md`: https-only, TLS verified.
- `.planning/phases/28-defectdojo-dedup-and-triage/28-CONTEXT.md` (D-20 to D-24) and `docs/adr/adr026-defectdojo-dedup-product-wide-and-triage-on-default-branch.md`: the Phase 29 hand-forward, and NOT-verified items 1-5.
- `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md`: the v1.x tag and `v1` move for the `DEFECTDOJO_RUNS_ON` change.
- `docs/adr/adr001-remove-continue-on-error.md`: the side-channel carve-out.
- `docs/adr/README.md`: the ADR index.
- `docs/adoption-guide.md` and `scripts/check-adoption-guide.sh`: document `DEFECTDOJO_RUNS_ON` and the runner group.

### security-platform (local clone `repos/security-platform/`)
- `.github/workflows/security.yml`: seven `runs-on: ubuntu-latest` lines (83, 250, 386, 913, 1105, 1269 and 1652 at time of discussion), plus the `defectdojo-import` and `defectdojo-cleanup` jobs. Research must check that their inline `python3`/`curl` tooling exists on the ARC runner image. Otherwise choose a custom runner image in the overlay, or a setup step under the same v1.x change.
- `.github/workflows/pr-security.yml`, `scheduled-security.yml`, `defectdojo-import-proof.yml`: the callers affected by D-10.
- `scripts/set-required-checks.sh`: the five required contexts, which must not change.
- `scripts/defectdojo-configure.sh`: the D-13 bootstrap.
- `kubernetes/defectdojo/values.yaml`, `README.md`, `TRIAGE.md`: the chart under deploy, the DDOJO-05 row, and the triage filters used in D-11.
- `scripts/nexus-homelab-validate.sh`: the host-parameterised live-gate precedent for any DefectDojo live gate script.

### Homelab overlay (`~/git-repos/OCC-github/kubernetes_stack/`)
- `occ-k8s-app-config/application-sets/platform/nexus/`: the two-source Application shape to mirror.
- `occ-k8s-app-config/application-sets/platform/homepage/templates/service.yaml`, `certificate.yaml`, `deployment.yaml` and `networkpolicy.yaml`: the LB VIP + ghostunnel + DNS-01 exposure pattern, including the cert-reload and `externalTrafficPolicy` comments.
- `occ-k8s-app-config/application-sets/platform/admission-policies/`: enforcement of `externalTrafficPolicy: Cluster` on L2 VIPs.
- `occ-k8s-app-config/application-sets/automation/argocd/templates/projects.yaml`: the `platform` AppProject to amend.
- `occ-k8s-cluster-config/docs/upgrade/cilium-l2-vantage-host-runbook.md`: the VLAN43 allocation table. Add .65 / DefectDojo there.

### Upstream (verify against the pinned versions, not the latest docs)
- actions-runner-controller runner scale sets: org-level registration, runner groups, PAT permissions, and the contents of the default runner image.
- DefectDojo 3.3.200 settings for CSRF trusted origins, allowed hosts and site URL behind a non-header-injecting TLS proxy.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/nexus-homelab-validate.sh`: the pattern for a `DEFECTDOJO_HOST`-parameterised live gate.
- `scripts/defectdojo-live-smoke.sh`: the login POST and Celery-ping checks (KIND-LOGIN, KIND-CELERY-PING), to retarget at the live host.
- `kubernetes/defectdojo/TRIAGE.md`: the untriaged-queue and disposition filters, used for the D-11 assertions.
- The overlay's `scripts/seal-secret.sh`: its controller namespace is `sealed-secrets`, not the script default `kube-system` (ADR-022).

### Established Patterns
- Live-gate evidence is captured into `.planning/phases/29-.../evidence/` with run IDs, and every value comes from `gh api` or `kubectl`, not recall.
- The chart pin is a commit SHA, so any chart change during the phase requires an overlay pin bump.
- Side-channel jobs are `continue-on-error` with a red verify step and are never required checks.
- Scripts run as `bash script.sh`. Never set the executable bit.

### Integration Points
- ArgoCD Application in the overlay, pointing at `security-platform` `kubernetes/defectdojo` at a pinned SHA.
- ghostunnel Deployment → django Service. LB Service at 10.40.3.65 → ghostunnel.
- ARC runner pod → DefectDojo. Two hops are unmeasured and must be measured before `DEFECTDOJO_URL` is committed:
  - Does in-cluster DNS (CoreDNS) resolve `defectdojo.infra...`, given the records exist only in Pi-hole 10.40.1.53?
  - Can a pod reach the L2 VIP 10.40.3.65 from inside the cluster (hairpin through the Cilium LB)?

  The fallback, if either hop fails, is for research to propose.
- `security.yml` `runs-on` for the two DefectDojo jobs → `vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest'`.

</code_context>

<specifics>
## Specific Ideas

### Operator-only steps (the planner models each one as a checkpoint)
1. A UniFi client/ARP check that no non-Kubernetes device statically uses 10.40.3.65, before the VIP is pinned.
2. Pi-hole Local DNS entries on 10.40.1.53 for `defectdojo.infra.ottawacloudconsulting.com` and `defectdojo.home.ottawacloudconsulting.com` → 10.40.3.65, and a decision on whether 10.30.1.53 needs them too.
3. Creating the fine-grained PAT scoped to `security-platform` with Administration: Read and write. Claude seals it; the operator supplies it without printing it.
4. ~~Creating the org runner group~~ — dropped (D-07 amended: personal account, repo-scoped registration). Replaced by: raising the `security-platform` fork-PR workflow approval policy to `all_external_contributors` before `DEFECTDOJO_RUNS_ON` is set (research finding).
5. Holding the superuser token for the one-off `defectdojo-configure.sh` run.
6. Creating `ci-importer` (`is_staff=true`, `is_superuser=false`) and its token, and setting the `security-platform` secret and variables.
7. Approving any `security.yml` merge and the v1.x tag / `v1` move, and approving the overlay merges.
8. Adding the .65 / DefectDojo row to the VLAN43 table in `cilium-l2-vantage-host-runbook.md`.

### Accepted risks (the operator chose each explicitly; ADR-027 states them as accepted, not silent)
- A self-hosted runner serves a **public** repository. Mitigation: only the import and cleanup jobs route to it, and both already skip fork and Dependabot runs. The runner group is restricted to selected repos.
- There is **no egress NetworkPolicy** on runner pods, so a compromised job can reach the LAN.
- A **PAT** is used instead of a GitHub App, so expiry needs manual rotation. Because registration is repo-scoped (D-07/D-08 amended), the PAT holds Administration: Read and write on `security-platform`.

### Other notes
- The cluster-team session also noted that app-config `docs/_working/rag-implementation/discovery/requirements-and-current-state.md:145` lists "where internal A records are managed" as open question O-11. D-04's finding (manual Pi-hole) can inform it, but closing it there is outside this repo.

</specifics>

<deferred>
## Deferred Ideas

- An egress NetworkPolicy for ARC runner pods (declined for now; hardening bucket).
- A GitHub App for ARC instead of the PAT.
- CloudNativePG as the DefectDojo database, and Postgres backups (hardening bucket).
- A cluster ingress controller or Cilium ingress/Gateway API, which would let the chart's own ingress path run live.
- A Mode B test consumer repo that proves the `@v1` adoption path against the live instance.
- Observing turning dedup on over existing findings, and the `manage.py dedupe` recompute on real data (ADR-026 NOT-verified items 1-2).
- Tracking internal DNS records in git instead of manual Pi-hole entries.

</deferred>

---

*Phase: 29-defectdojo-live-validation*
*Context gathered: 2026-09-26*
