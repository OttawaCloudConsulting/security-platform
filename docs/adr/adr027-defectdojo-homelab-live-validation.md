# ADR-027: DefectDojo Validated Live on the Homelab via an ArgoCD Overlay, an L4 TLS Proxy and a Self-Hosted Import Runner

**Status:** Accepted
**Date:** 2026-09-29
**Addresses:** DDOJO-05 — the DefectDojo chart validated live via a private ArgoCD overlay deploy to the
operator's homelab cluster

This record lives in this documentation repository. The public `security-platform` chart README cites
DDOJO-05 as Complete since PR #26 (merge commit `fdabac9`), so a reader of the public repository cannot
follow a link here. That is the same arrangement ADR-022 to ADR-026 recorded. Every measured value below
is quoted from a Phase 29 plan summary (29-01 to 29-18) or from a file in that phase's `evidence/`
directory, and the file is named where the value appears. A value from an earlier phase is attributed to
the ADR that measured it. No homelab address, hostname, node name or kube context name appears here. "The
homelab kube context" stands in for the context name, "an L2 VIP in the static VLAN pool" for the service
address, and "the `.infra` and `.home` names" for the two DefectDojo hostnames (D-20). The runner mechanics
(registration scope, PAT, scale set) are recorded separately in ADR-028.

## Context

- **The cluster has no IngressClass.** `kubectl get ingressclass` returned nothing on 2026-09-26, and the
  Cilium ingress controller and Gateway API are both disabled (29-CONTEXT D-01). The chart's own
  `Ingress` would be created and route nothing, which is the same finding ADR-022 decision 4 made for
  Nexus. The cluster's exposure convention is a `type: LoadBalancer` Service on an L2 VIP with TLS
  terminated by ghostunnel and a cert-manager DNS-01 certificate (the homepage pattern).
- **The ADR-022 overlay precedent is reused, not re-decided.** The overlay repository's ApplicationSet
  generates the `defectdojo` Application from `application-sets/platform/defectdojo/argocd-overrides.yaml`.
  It is a two-source Application pinned to a `security-platform` commit, with secrets as SealedSecrets at
  sync-wave `-1` (ADR-022 decisions 1-3). The shared `platform` AppProject was amended by enumerated kinds
  only: destinations `defectdojo`, `arc-systems` and `arc-runners`, both spellings of the ARC OCI chart
  repository, and the namespaced kinds `policy/PodDisruptionBudget` and
  `actions.github.com/AutoscalingRunnerSet`. `clusterResourceWhitelist` stayed byte-identical (overlay
  PR #246, merge `e965581`; `evidence/29-02-appproject-before.json` and `29-02-appproject-after.json`).
- **Phases 26 to 28 handed items forward to this phase.**
  - ADR-023 `## What was NOT verified` items 1 (the CSRF mechanism behind another proxy), 2 (no homelab
    ingress path), 4 (resync idempotency under Argo CD, including `initializer.staticName`) and 5 (the
    bundled Bitnami PostgreSQL NetworkPolicy on Cilium).
  - 27 D-17: how a GitHub Actions import job reaches a DefectDojo instance on the private LAN. A
    GitHub-hosted runner cannot.
  - ADR-026 hand-forward: the live install must run `scripts/defectdojo-configure.sh` once, and must
    re-prove dedup, the dispositions and the re-parent live rather than rely on the kind proof. ADR-026
    NOT-verified items 1 and 2 were Phase 29's to observe.
- **The GitHub account is a personal account, not an organisation.** Org-level runner registration and
  runner groups do not exist for it, so D-07 and D-08 were amended on 2026-09-26 to repository-scoped
  registration. That ruling and its accepted risks belong to ADR-028.

## Decision

1. **Chart ingress off; exposure through an LB Service on a pinned L2 VIP, with TLS terminated by a
   ghostunnel native sidecar in the django pod and a cert-manager DNS-01 certificate carrying both names
   (D-01 to D-04, as amended by 29-08a).** The overlay sets `django.ingress.enabled: false`. The
   Certificate `defectdojo-tls` (issuer `letsencrypt-dns01-prod`, ECDSA 256) carries the `.infra` and
   `.home` names as SANs. The internal A records are manual Pi-hole Local DNS entries on the LAN
   resolver and are not in git (D-04).
   - **As first built, ghostunnel was a standalone Deployment (D-02), and it crash-looped.** ghostunnel
     v1.11.3 refuses a non-loopback `--target` unless `--unsafe-target` is set, and printed
     `error: --target must be unix:PATH or localhost:PORT (unless --unsafe-target is set)`. The first
     sync on overlay `cc7fbc9` therefore ended `Succeeded` with health `Degraded` (29-08a).
   - **Operator decision, verbatim: `B1: overlay values` (2026-09-28).** ghostunnel moved into the
     `defectdojo-django` pod as a Kubernetes native sidecar: an init container named `tls` with
     `restartPolicy: Always` and `--target=127.0.0.1:8080`, listening on `:8443`. It is added purely
     through overlay values (`django.extraInitContainers` and `django.extraVolumes`); the public chart
     and its pin are unchanged, and `--unsafe-target` is not used. The LB Service now selects the django
     pod on numeric `targetPort` 8443. Argo CD pruned the standalone Deployment. This supersedes D-02
     (overlay PR #249, merge `08ce26b`; operator gate reply, verbatim: `approve terminate-op`. The
     terminate-op branch was never needed, because the pre-merge operation had already ended).
   - The Service carries the cluster's L2 labels and `externalTrafficPolicy: Cluster`, because `Local`
     is rejected at admission on L2 VIPs. The VIP was confirmed free by a live Service read and by the
     operator in UniFi before the merge. Operator reply, verbatim: `vip-free vlan30-skip` (29-07). The
     VLAN43 VIP inventory in the cluster-config runbook was rebuilt from a live read (cluster-config
     PR #43, `5c65ffb`; operator reply, verbatim: `approved`).
2. **CSRF: trusted origins in the overlay through `extraConfigs`, allowed hosts through
   `host`/`alternativeHosts`, and `DD_SECURE_PROXY_SSL_HEADER` deliberately unset (D-05, RESEARCH
   Pitfall 1).** The mechanism: Django 5.2.16 `CsrfViewMiddleware.process_view` runs
   `_origin_verified` whenever the POST carries an `Origin` header. Behind an L4 proxy that adds no
   `X-Forwarded-Proto`, `request.is_secure()` is false, so the good origin Django builds is `http://<host>`
   and a browser's `Origin: https://<host>` fails with `403 Origin checking failed` unless
   `https://<host>` is in `DD_CSRF_TRUSTED_ORIGINS`. With no `Origin` header and a non-secure request,
   only the token is checked. That explains the Phase 26 kind pass, where the smoke sent only `Referer`
   (ADR-023 item 1). The overlay sets `defectdojo.extraConfigs.DD_CSRF_TRUSTED_ORIGINS` to both https
   origins, and `host`/`alternativeHosts` render `DD_ALLOWED_HOSTS` with both names; `DD_SITE_URL` is the
   `.infra` https URL. Setting `DD_SECURE_PROXY_SSL_HEADER` would make Django trust a header that the L4
   proxy never sets and a client could forge, so it stays absent (29-05 render assertion (b)).
3. **The bundled Bitnami PostgreSQL is used exactly as shipped (D-15), and credentials are SealedSecrets at
   wave `-1`.** Seven generated credentials are sealed into three SealedSecrets (`defectdojo`,
   `defectdojo-postgresql-specific`, `defectdojo-valkey-specific`). No value was printed or committed;
   they exist in the clear only in the cluster (29-05). The chart's PostgreSQL NetworkPolicy renders
   by default and was left as shipped. The CloudNativePG operator on the cluster is not used.
4. **`initializer.staticName: true`, as an Argo CD `Sync` hook with `BeforeHookCreation` and
   `keepSeconds: 0`.** The upstream default (`staticName: false`) embeds the render minute in the Job
   name, so every render yields a new Job and the Application is perpetually OutOfSync; a plain resource
   with a TTL is deleted and self-healed in a loop (RESEARCH Pitfall 4). As a hook, the Job is not part of
   the compared desired state, and Argo deletes the previous Job right before creating the next. Counter-
   renders confirmed each value: without `keepSeconds` the Job gets `ttlSecondsAfterFinished: 60`, and
   without `staticName` it is named `defectdojo-initializer-2026-09-27-16-24` (29-05).
5. **`DEFECTDOJO_RUNS_ON` routes only the two DefectDojo jobs, and `security-platform` is its own importer
   (D-06, D-09, D-10).** `jobs.defectdojo-import` and `jobs.defectdojo-cleanup` in `security.yml` now use
   `runs-on: ${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}`. In a called workflow, `vars` resolves
   to the caller repository, so unset means `ubuntu-latest` and old callers are unchanged. The five scan
   jobs stay on `ubuntu-latest`. The change merged as PR #24 (`2fda1ac`) before either variable existed,
   and shipped to `@v1` consumers in `v1.2.0` (annotated tag `b8ae59d`, dereferencing to `fdabac9`), with
   `v1` moved from `917352c` to `fdabac9` (29-18; `evidence/29-18-tags.json`). `security-platform`
   carries `DEFECTDOJO_API_TOKEN`, `DEFECTDOJO_RUNS_ON=occ-homelab-defectdojo` and `DEFECTDOJO_URL`, set
   in that order, after an automated four-precondition ordering gate passed
   (`evidence/29-14-precondition-gate.txt`, `29-14-settings-readback.txt`). The token belongs to
   DefectDojo user `ci-importer` (id 3): `is_staff` true, `is_superuser` false, the ADR-024 identity. No
   `DEFECTDOJO_CA_CERT` is set, because the certificate chain is publicly trusted. The runner itself is
   ADR-028.
6. **`scripts/defectdojo-configure.sh` ran once, before the first import (D-13).** It ran with the
   operator-held superuser token, right after the first Synced and Healthy state, while the instance
   held 0 findings, 0 products, 0 engagements and 0 tests.
7. **Dispositions and API read-backs used the operator admin token, never the CI token (D-16, amended
   2026-09-27).** The CI token is staff and non-superuser by design and cannot read `/api/v2/users/`
   (29-14). The admin token was used only through 0600 header files in trap-removed temp directories.

**Operator rulings recorded verbatim in the plan summaries.** Besides those quoted above:
`approve` (29-02, the shared AppProject amendment); `approve` (29-07, the overlay merge without waiting
on GitGuardian); `Rerun, then merge if green` (29-06, PR #24 after a KIND-CELERY-PING red);
`wait, we don't actually have jira in our environment, descope this from the test` (29-10, JIRA
webhook secret rotation descoped); `approve-probes` (29-11, the D-18 one-off probe pods);
`passive-only` (29-11, the D-14 NetworkPolicy method); `merge the PRs and then stop` (29-13, the ordered
ARC merges); and `approve` (29-18, PR #26 and the `v1.2.0` tag), with the red check ruled on as
"ACCEPT it as a known external registry 429. Do not rerun it." The D-11 step-2 scope amendment of
2026-09-29 and the 29-17 measurement-window ruling are recorded where they apply below.

### Measured evidence

- **First sync (29-08, 29-08a).** Application `Synced` / `Healthy`, operation `Succeeded`, no conditions
  (so no `ComparisonError`), `revisions[0]` equal to the pin `c8027e6784ec631db128f45444c9a8092db9d0a1`
  and `revisions[1]` the overlay merge `08ce26b`. `syncResult` hooks: `Job/defectdojo-initializer` Sync
  `Succeeded`, and `ServiceAccount/defectdojo` PreSync `Succeeded`, which RESEARCH Pitfall 4 predicted.
  PVC `data-defectdojo-postgresql-0` `Bound` on StorageClass `default`. The evidence describes the
  operation that finished `2026-09-28T12:19:11Z`, not the first sync on `cc7fbc9`
  (`evidence/29-08-first-sync-application.json`, `29-08-first-sync-cluster.txt`). The first-sync
  initializer log is kept unchanged as `evidence/29-08-initializer-first.log`.
- **Image pulls (D-14; `evidence/29-08-image-pulls.txt`).** All pulled on the homelab:
  `us-docker.pkg.dev/os-public-container-registry/defectdojo/bitnami/postgresql:17.6.0-debian-12-r4`
  (the GAR PostgreSQL, `sha256:926356130b77…a710a8d`), `docker.io/defectdojo/defectdojo-django:3.3.200`,
  `docker.io/defectdojo/defectdojo-nginx:3.3.200`, `docker.io/valkey/valkey:9.1.0-alpine3.23` and
  `docker.io/ghostunnel/ghostunnel:v1.11.3-distroless`. For PostgreSQL, Valkey and Celery the Pulled
  events had aged out, so the live imageIDs plus `29-08-image-pulls.pre-ghostunnel-fix.txt` are the source.
- **TLS on both names (29-08 gate; `evidence/29-08-homelab-validate-first.txt`).** `HOMELAB-TLS-INFRA` and
  `HOMELAB-TLS-HOME` PASS: `/login` returned 200 with `ssl_verify_result` 0 against the system trust
  store, and both SANs were served. Certificate `defectdojo-tls` Ready, `notAfter`
  `2026-12-27T00:59:37Z` (`evidence/29-08a-live-after.txt`). This is the first live TLS exposure of a
  stack component; ADR-022's Nexus remains loopback-only and ADR-021 item 4 is not affected.
- **Origin login on both names, and the foreign-Origin 403 (same file).** `HOMELAB-LOGIN-ORIGIN-INFRA`
  and `HOMELAB-LOGIN-ORIGIN-HOME` PASS: a POST with `Origin: https://<host>` returned 302, then
  `/dashboard` returned 200. `HOMELAB-CSRF-FOREIGN-403` PASS: 403 `CSRF verification failed`, attributed
  to the Origin check by the uwsgi log line
  `WARNING [django.security.csrf:253] Forbidden (Origin checking failed - https://evil.example does not match any trusted origins.): /login`.
- **Celery (same file).** `HOMELAB-CELERY-PING` PASS: `celery -A dojo inspect ping` exited 0 with a pong.
  The first-pass gate printed `ALL PASS - 7 live check(s) executed and passed; 1 sub-check(s) skipped
  (not passed).`, the skip being the expected `SECOND-SYNC-IDEMPOTENT` on a first pass.
- **configure.sh CHANGED, then NO CHANGE (`evidence/29-10-configure-1.txt`, `29-10-configure-2.txt`).**
  Run 1 printed `CHANGED: enable_deduplication, risk_acceptance_form_default_days` and
  `VERIFIED: all 5 settings match`. Run 2 printed `NO CHANGE: all 5 settings already match`. The
  finding, product, engagement and test counts were 0 before run 1 and after run 2.
- **The reachability probe (`evidence/29-11-reachability-probe.txt`).** A one-off pod on the pinned
  runner image without `hostAliases` printed `NO-RESOLVE`: cluster DNS does not serve the Pi-hole-only
  name. With `hostAliases` mapping the `.infra` name to the VIP, `getent` resolved it and
  `curl --proto =https` to `/login` printed `200 0` (HTTP 200, TLS verified). The pod-to-VIP hairpin
  works, so no fallback was needed. Both pods were `NotFound` afterwards and the namespace inventory was
  unchanged.
- **The NetworkPolicy VERDICT (`evidence/29-11-postgres-netpol.txt`).** `VERDICT: allow path OBSERVED`:
  NetworkPolicy `defectdojo-postgresql` is present (ingress TCP/5432 from any peer, all egress); the
  PostgreSQL endpoint has ingress and egress enforcement Enabled; Hubble showed django and celery-worker
  to 5432 `ALLOWED`/`FORWARDED`, with zero `DROPPED` in the local ring. "Deny path (non-5432 ingress
  dropped) NOT verified, by operator decision `passive-only`."
- **Baseline job placement (29-15; `evidence/29-15-baseline-run.json`, `29-15-baseline-import.log`).**
  Run `36502430372` (`workflow_dispatch` on `main`, head `2fda1ac`): `DefectDojo Import` job
  `109196329353` ran on runner `occ-homelab-defectdojo-qqrsp-runner-tbt47` with labels
  `["occ-homelab-defectdojo"]`; the five scan jobs ran on GitHub-hosted `ubuntu-latest`. The log shows
  `TLS mode: verified-system` and 8 of 8 reports `IMPORTED` (http 201, `attempted=8 skipped=0
  failed=0`). The resulting `ci/main` engagement (id 1, product id 1) held 155 findings
  (`evidence/main-baseline-snapshot.json`).
- **The proof-workflow side effect (29-15; `evidence/29-15-proof-side-effect.txt`).** Run `36502717161`:
  `scans / DefectDojo Import` ran (not skipped) on runner `occ-homelab-defectdojo-qqrsp-runner-ntr9z`,
  logged `SKIP: DEFECTDOJO_API_TOKEN is not available to this run (...) — nothing sent to DefectDojo`
  and 0 `IMPORTED` lines; `count_before=155 count_after=155`. This is the RESEARCH Pattern 5 prediction:
  the proof workflow passes no `secrets:` block, so it routes to ARC and imports nothing.
- **D-11, the real PR lifecycle (29-16).** Fixture PR #25 added one Semgrep finding; PR run
  `36506042988` imported on ARC into engagement 2 (156 findings, tests 9-16).
  - Step 2 as first written: `D11-STEP2-DUPLICATES-POINT-TO-MAIN` **FAIL**, 59 of 155
    (`evidence/step2-assert.json`, kept unchanged). Under the 2026-09-29 amendment (below):
    `D11-STEP2A-ENGAGEMENT`, `D11-STEP2A-READ-GUARD`, `D11-STEP2A-EXCLUSION-KEY` (exactly Test 12,
    `Trivy Scan` + `trivy-image`) and `D11-STEP2-DUPLICATES-POINT-TO-MAIN (amended 2026-09-29)` all
    PASS: "all 96 non-fixture, non-trivy-image finding(s) ... are duplicates of ci/main snapshot
    findings", and the fixture (id 163) is the only Under Review finding
    (`evidence/29-16-step2-amended.txt`, `step2-amended-assert.json`).
  - Step 3: FP on finding 3 (Semgrep), OOS on 10 (Checkov), RA on 22 (Trivy fs, risk acceptance 1,
    expiry `2026-12-28T00:00:00Z`); `D11-STEP3-*` ALL PASS (`evidence/29-16-step3.txt`,
    `dispositions.json`).
  - Step 4: reimport by `scheduled-security.yml` `workflow_dispatch` run `36510481745` on ARC;
    `D11-STEP4-FP`, `-OOS`, `-RA` and `-RA-EXPIRY` PASS, with the exact P-DISPOSITION tuples of ADR-026
    (for example FP `{"false_p":true,"out_of_scope":false,"risk_accepted":false,"active":false,"is_mitigated":true}`)
    (`evidence/29-16-step4.txt`, `step4-assert.json`).
  - Step 5: PR closed unmerged; cleanup run `36510679451` ran `DefectDojo Cleanup` on ARC.
    `D11-STEP5-ENGAGEMENT-GONE`, `-MAIN-COUNT-UNCHANGED` (155), `-DISPOSITIONS-UNCHANGED` and
    `-NO-DANGLING-DUPLICATE` ("all 23 duplicate(s) among 155 product findings reference a finding that
    exists in the product") PASS (`evidence/29-16-step5.txt`, `step5-assert.json`). `ci/main` held 155
    findings at baseline, before the reimport, after it and after the close.
- **Second sync over real data (29-17).** A same-revision `argocd app sync` re-created Job
  `defectdojo-initializer` (UID `e43a2dcf-…` → `7b2753fd-…`) and the PreSync ServiceAccount (UID
  `d163032c-…` → `84144fe3-…`); the operation reached `Succeeded` in 21 s. Product count 1 → 1, finding
  count 155 → 155, revisions unchanged (`evidence/29-17-pre-state.json`,
  `29-17-second-sync-application.json`). The initializer log took the idempotent path
  (`No migrations to apply.`, `Admin user already exists; skipping first-boot setup`, 0 applied
  migrations, 0 `Running first boot setup`), and after timestamp stripping it is identical to the
  previous run's 90 lines (`evidence/29-17-initializer-second.log`). The drift watch took 11 samples at
  60 s intervals, from `02:30:23Z` to `02:40:25Z`: all `Synced Healthy`, same revisions, history id 1
  (`evidence/29-17-drift-watch.txt`), so the RESEARCH Pitfall 4 drift falsifier was not observed. The
  second-pass gate printed `ALL PASS - 8 live check(s) executed and passed; 0 sub-check(s) skipped`
  (`evidence/29-17-homelab-validate-second.txt`).
  - **Measurement-window gap, accepted.** The session paused about 10h41m between the sync (02:41Z) and
    the second-pass gate (13:22Z). The scheduled run `36553070357` imported in that gap. An admin
    read-back showed the same 155 finding ids (max id 155) and identical disposition flags
    (`evidence/29-17-post-gap-readback.json`), so a wipe-and-refill, which would have created ids above
    155, did not happen. Operator ruling, 2026-09-29: the result is accepted as is (option a), with no
    clean-window rerun.

## Consequences

**Improved:** the DefectDojo chart is proven on a long-lived cluster through the project's own GitOps
path, and the Phase 27 CI import and the Phase 28 dedup and triage are proven end to end against it
through real GitHub Actions runs, from API state rather than HTTP status. The public chart came from
`security-platform` at a pinned SHA, unmodified; the overlay holds only values, the Certificate, the
Service, sealed credentials and a README.

**Improved:** ADR-023 items are closed by measurement: item 1 (the CSRF mechanism is identified, and the
Origin login plus the foreign-Origin 403 pass on both names), item 2 (the homelab has no IngressClass,
and exposure is the VIP pattern, decided rather than left open), and item 4 (resync idempotency with
`initializer.staticName` under Argo CD, over real data). Item 5 is partly closed: the allow path is
observed and the deny path is not (below). ADR-026's hand-forward is carried out: the bootstrap ran
once with a NO CHANGE rerun, and dedup, dispositions and PR suppression were re-proved live.

**Improved:** the scheduled caller imports on a schedule. Cron-fired run `36553070357` (`schedule`,
created `2026-09-29T10:02:41Z`, `success`, head `2fda1ac`) ran `security / DefectDojo Import` on
runner `occ-homelab-defectdojo-qqrsp-runner-hqpfs` while the five scans ran on `ubuntu-latest`
(`evidence/29-19-scheduled-runs.json`, `29-19-cron-run-jobs.json`).

**Tradeoff — a self-hosted runner serves a public repository.** Only the import and cleanup jobs route
to it, and both already skip fork and Dependabot runs (17-03). The fork-PR approval policy was raised
from `first_time_contributors` to `all_external_contributors` before `DEFECTDOJO_RUNS_ON` existed
(`evidence/29-12-fork-approval-policy.json`). The residual risk, accepted by the operator: an approved
fork PR runs its own copy of the workflows and can target the runner label, so it runs on the LAN.
ADR-028 records the mechanics.

**Tradeoff — no egress NetworkPolicy on runner pods.** The operator declined it (D-09). A compromised job
on the runner can reach the LAN. Pods are ephemeral, which limits persistence but not reach.

**Tradeoff — plaintext django :80 is reachable in-cluster with no NetworkPolicy.** The native sidecar
moved the ghostunnel-to-nginx hop onto pod loopback, but the chart's `defectdojo-django` Service still
exposes port 80 (`http`), and nothing restricts which pods reach it. This belongs to the hardening
bucket in `REQUIREMENTS.md` (NetworkPolicy namespace isolation).

**Tradeoff — no backup.** PostgreSQL persistence is on and nothing backs it up (26 D-06). The overlay
README forbids deleting the PVC to "fix" authentication (RESEARCH Pitfall 9), because the data would
be lost.

**Tradeoff — the import job QUEUES rather than fails when the runner is offline or stale.** A named
self-hosted label with no online runner leaves the job queued; GitHub cancels a job queued for about
24h (RESEARCH A1, an assumption, not measured here). A runner image older than GitHub's 30-day update
window produces the same symptom (ADR-028). Merge is unaffected, because `DefectDojo Import` and
`DefectDojo Cleanup` are not required checks, and **they must never become required checks** (D-17,
27 D-03): a required check that can queue for a day would block every merge whenever the homelab is
down. A queued cleanup that is cancelled orphans the `ci/<branch>` engagement; recovery is re-running
the cleanup or deleting the engagement by hand (RESEARCH Pitfall 8).

**Tradeoff — the proof workflow can stall on a runner outage (RESEARCH Pattern 5).** `prove-import`
has `needs: scans` with `if: always()`, and `scans` now includes the import job routed to ARC. If the
runner is offline, the proof run waits until GitHub cancels the queued job. No functional guard was
added; a `workflow_call` input to switch the import off could be added if the stall is ever observed.

**Tradeoff — the sidecar is coupled to the chart.** The `tls` sidecar depends on the chart's
`extraInitContainers` ordering and on the django pod labels the Service selects. Rollback is
forward-fix only (29-08a).

**Tradeoff — trivy-image findings do not dedupe across branches.** `security.yml` builds and scans
`scan-target:${{ github.sha }}`, the tag appears in each finding's `file_path`, and a PR's merge SHA
never equals the default branch's. Measured in 29-16: on the PR engagement all 59 trivy-image findings
(Test 12) were active non-duplicates, with `file_path` `scan-target:17fd99dc… (debian 12.15)` against
`scan-target:2fda1ac… (debian 12.15)` on `ci/main`, while the other 96 pre-existing findings were all
duplicates of their `ci/main` copies. The Phase 28 proof (ADR-026, "154 duplicates, one new") never
exercised differing tags, because both of its engagements were imported from the same report. A PR
engagement's active list is therefore what the PR introduces plus the full trivy-image result. The
corrected `TRIAGE.md` and README text and the `assert-pr-duplicates` exclusion (with a new
`D11-STEP2-EXCLUSION-KEY` check) shipped in `security-platform` PR #26, merge `fdabac9`, tag `v1.2.0`
(commits `71a388c` and `0f401f7`). ADR-026 is not edited.

**Lesson — structural gates do not validate container arg semantics.** The 29-05 gates (`helm
template`, `kubectl --dry-run` client and server) validate structure and admission, and they passed a
ghostunnel `--target` that the binary refuses at runtime. The pattern is now a pre-merge runtime arg
check with a negative control for any proxy or sidecar whose args encode policy: the pinned image run
with the exact rendered args must stay up, and the known-bad arg must fail. For the sidecar, the
negative control exited rc=1 with the `--target must be` error (`evidence/29-08a-runtime-arg-check.txt`).

**Known flake — KIND-CELERY-PING in the kind proof.** The throwaway kind DefectDojo in
`defectdojo-import-proof.yml` has gone red at `KIND-CELERY-PING` (`celery -A dojo inspect ping exited
69 without pong`) with the code unchanged. At `2fda1ac`, run `36502717161` attempt 1 failed (job
`109197316267`) and attempt 2, an operator-approved rerun, passed (job `109200085064`). The same
failure had appeared on PR #24 (run `36350180923` attempt 1, which passed on rerun) and on `main` (run
`36159160216`, followed by the green run `36160366711`) (29-06). At PR #26, run `36600468850` job
`109516595106` passed, including `KIND-CELERY-PING: PASS`. It is recorded as a known flake of the kind
proof, not of the live instance; "a transient Celery worker readiness race" is an inference from
passes after fails, not a root cause (`deferred-items.md`). Hardening the ping retry stays optional.

**Accepted red check — the PR #26 trivy-image 429.** `security / Container — Trivy Image` in PR Security
run `36600468855` (job `109516223383`) failed on `429 Too Many Requests - Server message:
toomanyrequests: Data limit exceeded` while pulling the `debian:12-slim` base image from
`public.ecr.aws`, before any scan ran. The same job at the same head SHA passed in run `36600468850`
(job `109516224085`). The operator accepted it without a rerun (`evidence/29-18-red-check-429.txt`).
Because that report was lost, the PR's engagement (id 3) had 7 of 8 reports, and it was deleted by the
cleanup job on ARC after the merge (`evidence/29-18-cleanup.txt`).

**Process record — the `ci-importer` creation (29-14).** The plan's user-create body lacked the
required `email` field, and the first `POST /api/v2/users/` returned HTTP 400
`{"email":["This field is required."]}`. On the second attempt the helper script checked the new token
against `/api/v2/users/?username=ci-importer`, which returns 403 to a non-superuser; the script exited
before any repository setting changed. The user it had created (id 2) was deleted with operator
approval (`DELETE` returned 204, and a later read returned 404), and the check moved to
`GET /api/v2/user_profile/`. The final `ci-importer` is user id 3.

## What was NOT verified

What WAS measured and must not be re-litigated: the first sync and image pulls, TLS and the Origin
login on both names with the foreign-Origin negative control, the Celery ping, the configure
CHANGED-then-NO CHANGE runs, the runner reachability probe, the NetworkPolicy allow path, the ARC
placement of every import and cleanup job named above, the proof-workflow side effect, D-11 steps 1-5
under the amended step 2, and the same-revision second sync over 155 findings.

1. **The chart's own ingress path live.** It is proven on kind only (Phase 26, ADR-023). The homelab has
   no IngressClass, and this phase exposed DefectDojo through the VIP and the ghostunnel sidecar
   instead (D-01).
2. **ADR-026 item 1, turning dedup on over existing findings, was not exercised.** The bootstrap ran
   before any finding existed, over 0 findings, 0 products, 0 engagements and 0 tests (D-13; 29-10).
   It stays open.
3. **ADR-026 item 2, the `manage.py dedupe` hash recompute, was not run against real data.** No hash
   field changed in this phase.
4. **Re-parenting live was not exercised (D-11, amended 2026-09-26).** No `ci/main` finding is a
   duplicate of a PR finding in the D-11 sequence, so the delete-time re-parent had nothing to act on.
   `assert-closed` printed `INFO: re-parenting NOT asserted`. Re-parenting is proven on kind only
   (Phase 28, ADR-026 P-REPARENT, K=6).
   - **Next to it: the trivy-image cross-branch dedup gap and the step-2 scope amendment.** D-11 step 2
     was amended by operator ruling on 2026-09-29 (29-CONTEXT D-11 step 2; operator choice "(a) + (d)"
     in 29-16) so that the duplicates assertion excludes the trivy-image Test (scan_type `Trivy Scan`,
     test_title `trivy-image`). Every other pre-existing finding still had to be, and was, a duplicate of
     a `ci/main` finding. So cross-branch dedup of trivy-image findings is not only unverified but
     measured absent (see the Tradeoff above).
   - **Open follow-up (b): a fixed scan-image tag.** Tagging the scanned image with a fixed name, for
     example `scan-target:ci`, instead of `github.sha` might let trivy-image findings dedupe across
     branches. It is not done. Which field carries the SHA into the `Trivy Scan` dedup key at 3.3.200
     (`file_path`, measured to hold it, or also `description`) is unverified, and it would need a kind
     proof that two imports differing only in the tag dedupe. It changes `security.yml`, so it also needs
     a `v1` consumer impact check (`deferred-items.md`).
5. **`helm upgrade` was not exercised.** Only Argo CD syncs ran: the first, the sidecar sync and the
   same-revision second sync. No revision of the chart pin changed during the phase.
6. **The cron-fired scheduled run (D-12): observed.** D-12 did not require it. Run `36553070357`, event
   `schedule`, created `2026-09-29T10:02:41Z`, conclusion `success`, head `2fda1ac`, fired after the
   29-14 settings (2026-09-29T00:14:10Z). Its `security / DefectDojo Import` job succeeded on runner
   `occ-homelab-defectdojo-qqrsp-runner-hqpfs` (`evidence/29-19-scheduled-runs.json`,
   `29-19-cron-run-jobs.json`). One cron run was observed; no series of daily runs was.
7. **The PostgreSQL NetworkPolicy deny path.** The operator chose `passive-only`, so no probe tested that
   non-5432 ingress is dropped (ADR-023 item 5 is only partly closed).
8. **VLAN30 client resolution.** The operator chose `vlan30-skip`: the A records exist only on the LAN
   Pi-hole, not on the in-cluster Pi-hole that VLAN30 clients use, so VLAN30 clients cannot resolve the
   DefectDojo names. The runner path does not need them.
9. **Other items the Phase 29 summaries recorded as unmeasured or open:**
   - ghostunnel runs without `--target-status` (TCP-dial status); RESEARCH A2 (`/nginx_health` without
     host validation) is unmeasured.
   - ADR-023 item 3 (Helm 3 `--wait` semantics) is unchanged by this phase. ADR-026 items 3 to 6
     (multi-triager permissions, versions other than 3.3.200, re-parent caveats B and C, risk-acceptance
     expiry) are unchanged; risk acceptance 1 expires `2026-12-28` and its expiry handler was not run.
   - The runner-to-VIP hairpin was measured only from the node holding the VIP's L2 lease (ADR-028).
   - GitHub's cancellation of a job queued for about 24h is cited, not observed; no runner outage
     occurred during the phase.
