# ADR-022: Nexus Live Validation via a Private ArgoCD Overlay

**Status:** Accepted
**Date:** 2026-09-23
**Addresses:** NEXUS-05 — the Nexus chart validated live via a private ArgoCD overlay deploy to the
operator's homelab cluster

This record lives in this documentation repository. The public `security-platform` chart README cites it
by number since PR #16 (merge commit `61589d5`), so a reader of the public repository cannot follow the
link. That is known and was accepted by the operator at the PR #16 review. Every measured value below
is quoted from a Phase 25 plan summary or from a file in that phase's `evidence/` directory. A value from
an earlier phase is attributed to the ADR that measured it. No homelab address, hostname, node name or
kube context name appears here; "the homelab kube context" stands in for the context name.

## Context

- **The override file is the Application.** The overlay repository (`occ-k8s-app-config`) runs an
  ApplicationSet, `appset-apps`, whose git-files generator matches `application-sets/*/*/argocd-overrides.yaml`.
  It derives the Application name and the destination namespace from `{{.path.basename}}` and the
  AppProject from `{{ index .path.segments 1 }}` (read live in 25-03; no divergence from research). So
  `application-sets/platform/nexus/argocd-overrides.yaml` produces an Application `nexus` in namespace
  `nexus` under project `platform`. No `Application` manifest was written or applied by hand; in 25-04 the
  ApplicationSet generated the Application after PR #241 merged (merge commit `a05471b`).
- **The AppProjects on this cluster are deny-by-default allowlists on three axes, and `platform` admitted
  none of the Nexus kinds before this phase.** The live `platform` project allowed none of
  `apps/StatefulSet`, `batch/Job` or `bitnami.com/SealedSecret`, did not allow the `security-platform`
  source repository, and did not allow the `nexus` destination. The 25-02 before/after set difference of
  the live `.spec` shows **exactly five additions and zero removals**: sourceRepos
  `https://github.com/OttawaCloudConsulting/security-platform`; destination `nexus` on `in-cluster`;
  namespaced kinds `apps/StatefulSet`, `batch/Job`, `bitnami.com/SealedSecret`. The
  `clusterResourceWhitelist` was byte-identical before and after. This landed as overlay PR #239 (merge
  commit `7b7e25c`), with the required `conformance` check passing.
- **Under Argo CD, the chart's Helm hook annotations are dead: the provisioning Job ran as a `Sync` hook,
  not PostSync.** The Job carries `argocd.argoproj.io/hook: Sync` alongside
  `helm.sh/hook: post-install,post-upgrade`, and Argo CD ignores all Helm hooks on a resource that carries
  any Argo hook annotation. `evidence/25-04-first-sync-application.json` records exactly one hook entry,
  `{kind: Job, name: nexus-provision, hookType: Sync, hookPhase: Succeeded}`, and the second sync
  recorded the same (`evidence/25-05-chart-edit-assessment.md`). **PostSync was not observed on either
  sync.** This closes ADR-020 `## What was NOT verified` item 3 by observation, and the observation
  **contradicts** what that item carried as training knowledge (that Argo would map the Helm hook to
  PostSync). A plain `helm template` read of the chart in 25-03 predicted PostSync too; only the live
  Application status settled it.
- **Argo CD resolved the gitignored subchart itself.** The chart does not commit `charts/*.tgz`, so the
  Argo CD repo-server must run the dependency build on first render. 25-04 recorded no `ComparisonError`
  and no `InvalidSpecError`, and the Application reached `Synced` / `Healthy` with operation `Succeeded` at
  chart revision `aed14b916e9aa8ec1d0d47699b457040b99f7eac`. This closes ADR-020 item 4 by observation:
  the tarball does not need to be committed.
- **NEXUS-03's default-StorageClass claim is now measured on a long-lived cluster.** The measured cluster
  default StorageClass is named `default`, and the chart set no `storageClass`. PVC `data-nexus-nexus3-0`
  is `Bound` on `default` at `8Gi` (`evidence/25-04-first-sync-cluster.txt`). The class's volume binding
  mode is `WaitForFirstConsumer` (25-02), so the PVC is legitimately `Pending` until the StatefulSet pod
  is scheduled, and a Pending PVC before that point is not a fault.
- **NEXUS-02's live proof: four ecosystems, anonymous, with byte counts.** Measured over loopback
  port-forward with no credential, identical on both gate passes (`evidence/25-04-homelab-validate-first.txt`,
  `evidence/25-05-homelab-validate-second.txt`): npm `lodash-4.17.21.tgz` **318,961** bytes; PyPI
  `simple/requests/` **76,776** bytes; Helm `index.yaml` **291,818** bytes; Docker layer blob
  `sha256:16333ee0…b8e5a` (alpine 3.21, `linux/amd64`) **3,626,020** bytes. The Docker blob came through
  the full anonymous OCI handshake: `GET /v2/` returns 401 with a `Bearer` challenge, a token is minted
  with no credential, the manifest returns 200 **with** `Authorization: Bearer`, and the layer streams.
  Each fetch has three verdicts (transport, HTTP 200, size above a floor) because the failure modes are
  different. ADR-021 measured that a refused licence answers with a ~192-byte 403 body and a closed
  anonymous posture answers with a 401 challenge. A status check alone would not tell those apart, and a
  byte count alone would not tell a transport failure apart from either.
- **The Docker path shape holds on the homelab in both directions.** `/v2/docker-proxy/library/alpine/manifests/3.21`
  returns **200**, and `/v2/repository/docker-proxy/library/alpine/manifests/3.21` (the `/repository/`
  prefix copied from npm, PyPI and Helm by analogy) returns **404**, on both gate passes. The documented
  reference `HOST/<repo>/<image>` is the one that routes.
- **The write boundary was tested with a request that authorisation had to decide.** An unauthenticated
  `POST` of a **structurally valid** npm proxy repository body returned exactly **403**. An admin `GET` of
  the existing `npm-proxy` returned **200**, which shows the read-back instrument works. An admin `GET` of
  the probe name `anon-write-probe` then returned **404**, which shows nothing was created. A 400 would
  have proven nothing, because Nexus rejects a malformed body before it consults authorisation.
- **Idempotency against existing state is a standing invariant, not a one-off test.** Argo CD re-runs
  Sync hooks on **every** sync, and `ApplyOutOfSyncOnly=true` (set by `appset-apps`) does not suppress
  them. 25-05 triggered a second sync with no revision change against a PVC that already held state.
  The provisioning log records **4** `action=updated` (HTTP 204) and **0** `action=created`, where the
  first sync had 4 `action=created` (HTTP 201). It also records the guarded no-change path
  `realms: DockerToken already active — no change, and no request was made.`, and the active realms read
  back exactly `["NexusAuthenticatingRealm","DockerToken"]` (`evidence/25-05-second-sync-provision.log`).
  "DockerToken exactly once, NexusAuthenticatingRealm still present" therefore has to hold after every
  self-heal and every sync, not only after the first. The second gate pass printed
  `ALL PASS - 18 live check(s) executed and passed; 0 sub-check(s) skipped`. The first pass had 17 passes
  plus the expected `SECOND-SYNC-IDEMPOTENT` skip.
- **Anonymous read of the realms list is refused, so the gate's admin fallback is load-bearing.** On the
  live instance an unauthenticated `GET /service/rest/v1/security/realms/active` returned **403** on both
  passes. The gate (`scripts/nexus-homelab-validate.sh`, 25-01) tries anonymously first and retries as
  admin only on 401/403, recording which identity read the list. Without that fallback,
  `DOCKER-REALM-ACTIVE` and `SECOND-SYNC-IDEMPOTENT` would be permanently red for a reason unrelated to
  the realms list.
- **A green sync is not evidence.** Argo CD decides a hook's phase purely from the Job's exit code, so
  `Synced` + `Healthy` says only that `provision.sh` exited 0. It says nothing about whether the
  repositories exist, whether anonymous pull works or whether writes are refused. Synced + Healthy was
  therefore explicitly **not** accepted as NEXUS-05 closure. The closure is the two gate passes above,
  read from the Nexus API and from real pulls.

## Decision

1. **Amend the existing `platform` AppProject rather than create a new `security` project.** The
   operator took this decision against the research recommendation, replying **"approve-defaults"** at
   the 25-02 checkpoint. The directory path `application-sets/platform/nexus/` permanently fixes the
   Application's project, because the generator derives it from the path. The pre-existing unscoped
   `''/Namespace` cluster-scoped entry was deliberately left byte-unchanged: narrowing it would revoke
   `CreateNamespace` for the other `platform` members, five of them as measured in 25-02. Resource kinds
   were enumerated from a fresh render of the chart rather than wildcarded, and `ServiceAccount`,
   `ConfigMap`, `Service` and `Secret` were already allowed, so none of them was added.
2. **A two-source Application.** Source 1 is the public `security-platform` repository's
   `kubernetes/nexus` chart, pinned to commit `aed14b916e9aa8ec1d0d47699b457040b99f7eac` rather than a
   branch. Source 2 is the overlay directory itself, which carries only the SealedSecret. A pin means a
   chart update requires an overlay commit. This is already visible: `security-platform` `main` moved to
   `61589d5` when PR #16 merged, while the deployed pin stays at `aed14b9`. The deployed provisioning Job
   is unaffected only because `kubernetes/nexus/templates/job-provision.yaml` is the same blob
   (`929bc35f`) before and after that merge (25-06).
3. **The admin credential is a SealedSecret at sync-wave `-1`.** `nexus/nexus-admin` (key `password`)
   holds a randomly generated password that was sealed through the overlay's `scripts/seal-secret.sh`
   and never printed. The live sealed-secrets controller runs in namespace `sealed-secrets`, not the
   helper script's `kube-system` default (25-03). Caveat, measured: Argo CD has **no health assessment**
   for `bitnami.com/SealedSecret` on this cluster. `evidence/25-04-first-sync-application.json` lists it
   `Synced` with `health: null`. The wave orders the apply but cannot wait for decryption, and the
   ordering relies on kubelet retrying the Secret mount. That was sufficient on the first sync.
4. **Ingress and TLS were excluded from this phase, deliberately.** The research session found no
   IngressClass and no Gateway API CRDs on the cluster (`kubectl get ingressclass` returned no
   resources; 25-RESEARCH, locked decision L-01), so an `Ingress` would be created and route nothing. The
   cluster's exposure convention is a LoadBalancer VIP, and the VIP pool is operator-owned; a VIP is not
   picked without asking. Validating over `kubectl port-forward` to `127.0.0.1:8081` keeps
   unauthenticated plaintext on loopback rather than putting it on the LAN. **ADR-021
   `## What was NOT verified` item 4 is therefore still open, and this record does not close it.** The
   first TLS anywhere in this stack has not been built yet.
5. **No chart edit.** `evidence/25-05-chart-edit-assessment.md` gives the verdict **NO CHART EDIT
   NEEDED** on 25-RESEARCH Open Question 3, on this evidence:
   - The Job ran as a `Sync` hook on both syncs.
   - `BeforeHookCreation` delete-then-create was measured on the second sync. The first Job (UID
     `11400922-…`) was still present inside its TTL right before the sync, and the second sync created a
     Job under the same name with a new UID (`f3c25405-…`). There was no `spec.template is immutable`
     error.
   - `ttlSecondsAfterFinished: 900` truncated nothing. The logs were captured **9 s** and **4 s** after
     completion, and the second operation's `finishedAt` equals the Job's `completionTime`.

   An explicit `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation` would only make the source
   of the policy unambiguous; it would not change the measured behaviour. The TTL stays, because the
   template records 900 as a floor. 25-06 verified `job-provision.yaml` byte-identical on
   `security-platform` `origin/main` before and after the merge.
6. **The validation instrument is a sibling script.** `scripts/nexus-homelab-validate.sh` was added
   rather than parameterising `nexus-live-smoke.sh` in place, so the existing 25-check Phase 24 gate stays
   untouched and green. `--url`, `--context` and `--sync-pass` are all required and have no defaults:
   every `kubectl` call pins `--context` on its own line, the script owns no port-forward, and a first
   pass cannot claim the second-sync check. With nothing executed, the script prints `NOTHING RAN` rather
   than `ALL PASS`. The script merged to `security-platform` `main` in PR #16 at mode `100644`. The
   operator replied **"merge"** after reading the full public diff at the 25-06 checkpoint.

## Consequences

**Improved:** the chart is proven on a long-lived cluster through the project's own GitOps path. The
Application was generated from a directory, synced automatically, provisioned by the chart's own hook,
re-synced against existing state, and measured twice by a gate that reads the Nexus API and pulls real
components. This is the first live exercise of the "generic-first, not private-then-strip" architecture
decision. The overlay holds only an override file, a sealed credential, chart metadata and a README; the
chart came from the public repository unmodified.

**Improved:** NEXUS-03's default-StorageClass claim is measured rather than asserted. ADR-021 item 7 (no
upgrade of an instance whose PVC already carried state) is closed by the second sync. ADR-020 items 3
and 4 (Argo's hook treatment and subchart resolution) are closed by observation. The workstation script
was also measured against the homelab instance in 25-05 (`evidence/25-05-nexus-setup-verify.txt`,
`Rows: 3 ok, 0 not ok, 1 MANUAL.`): npm pulled 318,961 bytes through `.npmrc`, pip downloaded
`six-1.17.0` through `pip.conf`, and Helm returned 12 chart rows from the repo-scoped configuration.

**Tradeoff — a shared AppProject is now wider.** The other `platform` members may now create
StatefulSets, Jobs and SealedSecrets, and may deploy from the `security-platform` repository. The
rejected alternative was a dedicated `security` AppProject. It would have scoped these kinds to Nexus
alone, but it would have needed a second project in `projects.yaml` and an `application-sets/security/`
directory tree. The operator chose the smaller change to an existing convention over the tighter blast
radius.

**Tradeoff — anonymous read is open on a real network.** `nx-anonymous` is wildcard read-only across
format and repository name, so any repository added later is world-readable from the moment it is
created. ADR-021 also measured that `GET /service/rest/v1/repositories` answers 200 anonymously. This
phase did not re-measure that endpoint; its gate made only admin reads of individual repositories. No
NetworkPolicy ships and none is in milestone scope. Reach is currently limited only by the absence of an
ingress or VIP, so decision 4 is also the interim access control.

**Tradeoff — everything is plaintext.** There is no TLS anywhere in this path. Every status code and
byte count in this record was measured over `http://127.0.0.1:8081` through a port-forward that each
plan started, used for one gate invocation and killed (after the kill, `curl` returned rc 7). Loopback-only
validation was the interim control, not a remedy.

**Tradeoff — a SHA pin.** A chart update needs an overlay commit that moves `sources[0].targetRevision`,
and that commit goes through the overlay's own `conformance` check. The pin is already one merge behind
`security-platform` `main` (decision 2).

**Tradeoff — the PVC reclaim policy is `Delete`.** The volume is `8Gi` on StorageClass `default`, whose
reclaim policy is `Delete` (25-02). Losing the volume costs re-accepting the EULA and re-provisioning,
and every proxied component is cached again from upstream. `helm uninstall` or an Argo CD prune does not
necessarily delete a StatefulSet's PVC. Re-creating the Application against a surviving PVC is the
re-entrant path, and that path is what the second sync tested for ADR-021 item 7: the upsert takes the
`updated` branch and the realms append takes its no-change branch.

**Tradeoff — deleting one file deletes the Application.** The Application exists because the override
file exists, and removing the file removes the Application. The generator sets
`preserveResourcesOnDeletion: true`, so the workloads survive **unmanaged**. A rollback therefore removes
the workloads first and the file second, or it leaves an orphaned StatefulSet and PVC that nothing
reconciles.

## What was NOT verified

1. **No pull was performed by the operator's own Docker daemon against a routable hostname (ADR-021
   item 1).** Deferred, because it depends on the ingress/TLS work that decision 4 excludes. In 25-05
   `--docker-daemon` was not passed, the operator's `daemon.json` sha256 was identical before and after
   (`evidence/25-05-docker-daemon.sha256`), and the workstation script reported Docker as `MANUAL`,
   which it never counts as a pass. Item 1 is untouched, not partially closed.
2. **TLS and ingress (ADR-021 item 4) are explicitly out of scope for this phase and still open.**
   Certificate verification by any of the four clients, the daemon's TLS handling against a real
   hostname and the mirror URL under https all remain untested. So does any exposure path other than a
   loopback port-forward.
3. **NetworkPolicy is out of milestone scope.** Nothing restricts which pods or hosts can reach the
   Nexus Service. See ADR-008 for the guidance and `REQUIREMENTS.md` for the deferral.
4. **Nothing in the 25-05 workstation run was red or skipped.** The run recorded `3 ok, 0 not ok,
   1 MANUAL`, with no SKIPPED or UNVERIFIABLE row. Docker `MANUAL` is by design (ADR-021 decision 7), not
   a Phase 25 constraint or defect, and it is not a pass. The three `ok` rows were measured over
   plaintext loopback HTTP only. Hostname routing and TLS for npm, pip and Helm are unmeasured, per
   item 2.
5. **Hook semantics** (quoting the closing line of `evidence/25-05-chart-edit-assessment.md`): "Not verified
   about the hook semantics: which source supplied the observed `BeforeHookCreation` policy (Argo's
   no-policy default or the mapped `helm.sh/hook-delete-policy`); a sync with a changed Job pod template;
   a stalled operation that runs past the 900 s TTL; and hook behaviour across an Argo CD version
   upgrade." Both syncs used the same two revisions, so the `Replace=true` immutable-template path the
   chart's template comment predicts was not exercised.
6. **Other items the Phase 25 summaries recorded as unmeasured or open:**
   - The absence of `CreateContainerConfigError` on the provisioning pod was observed only at 20-second
     poll granularity (25-04). Whether kubelet's Secret-mount retry ever fired in the wave `-1` ordering
     window was not measured.
   - `workstation/nexus-setup.sh --verify` is **not read-only**. Before verifying anything, it writes
     `.npmrc`, `pip.conf`, `.nexus-env` and `.helm/` into the enclosing git repository and appends to
     that repository's `.gitignore` (25-05). It was run from a throwaway repository for that reason. The
     workstation README does not say so. This is a follow-up for a future `security-platform` change
     and is not fixed here.
   - Bare `application` / `appproject` resource names are ambiguous on this cluster because another
     installed CRD also defines an `Application` kind. Every command used `applications.argoproj.io` /
     `applicationsets.argoproj.io` (25-02, 25-04). This is an operational note, not a chart defect.
   - ADR-021 items 2 (`forceBasicAuth` documented-versus-measured divergence), 3 (Checkov's zero coverage
     of the chart) and 5 (no custom anonymous role scoped to the four proxies) are unchanged by this
     phase.
