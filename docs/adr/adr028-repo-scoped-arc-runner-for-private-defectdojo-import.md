# ADR-028: A Repository-Scoped actions-runner-controller Scale Set Carries DefectDojo Import to a Private Instance

**Status:** Accepted
**Date:** 2026-09-29
**Addresses:** DDOJO-05 — the reachability part: how the `security-platform` import and cleanup jobs
reach a DefectDojo instance on the operator's private LAN (the question 27 D-17 deferred)

This record lives in this documentation repository, beside ADR-027, which records the DefectDojo live
validation and cites this record for the runner mechanics. Every measured value below is quoted from a
Phase 29 plan summary (29-02, 29-11 to 29-15) or from a file in that phase's `evidence/` directory, and
the file is named where the value appears. Statements about GitHub and ARC behaviour that were read,
not measured, are attributed to 29-RESEARCH. No homelab address, hostname, node name or kube context name
appears here; "the homelab kube context", "the L2 VIP" and "the `.infra` name" stand in for them (D-20).
The GitHub account name is a public login and is not a homelab literal.

## Context

- **A GitHub-hosted runner cannot reach the instance.** DefectDojo is exposed on an L2 VIP on the private
  LAN (ADR-027 decision 1), and its names resolve only on the LAN Pi-hole. The Phase 27 import and
  cleanup jobs must therefore run somewhere inside the network. D-06 chose a self-hosted runner from
  actions-runner-controller (ARC, runner scale sets) in the homelab cluster, for those two jobs only.
- **The account is a personal `User` account, not an organisation.** 29-RESEARCH measured
  `gh api users/OttawaCloudConsulting --jq .type` → `"User"`, `gh api orgs/OttawaCloudConsulting` →
  `404 Not Found`, and `gh api user/orgs` → empty. A user account has no org-level runner registration,
  no runner groups and no organisation permission `Self-hosted runners`. Runner groups need the GitHub
  Team plan even for an organisation ("organizations using the GitHub Team plan can use runner groups",
  github/docs), which conflicts with the blueprint's zero-cost premise.
- **The original D-07 and D-08 assumed an organisation.** As first written, they registered the runner at
  organisation level in a runner group restricted to selected repositories, authenticated by a PAT with
  organisation permissions (29-RESEARCH BLOCKING FINDING; 29-CONTEXT marks the amendment as superseding
  "the org-level wording"). Neither can be carried out on this account. 29-RESEARCH put an operator
  decision checkpoint ahead of every ARC task rather than adapting quietly.
- **The amendment, verbatim from 29-CONTEXT:**

  > **D-07 (amended 2026-09-26, supersedes the org-level wording):** The runner is registered at
  > **repository scope on `security-platform`** (`githubConfigUrl` = the repo URL, no `runnerGroup`).
  > Research verified `OttawaCloudConsulting` is a personal `User` account
  > (`orgs/OttawaCloudConsulting` returns 404), so org-level registration and runner groups do not exist.
  > Each future consumer repo gets its own runner scale set. The operator ruled this on 2026-09-26.
  >
  > **D-08 (amended 2026-09-26):** ARC authenticates with a **fine-grained PAT scoped to the
  > `security-platform` repository only**, with repository permission **Administration: Read and write**
  > (the minimum for repo-scoped runner registration). The PAT is stored as a SealedSecret. This
  > permission is broader than runner management on that repo (settings, webhooks, branch protection);
  > ADR-028 records it as an accepted risk. The operator chose a PAT over a GitHub App, and PAT expiry
  > means manual rotation (accepted, see Accepted Risks).

## Decision

1. **Repository-scoped registration, as an operator ruling on 2026-09-26 amending D-07 and D-08.** The
   scale set sets `githubConfigUrl` to the `security-platform` repository URL and omits `runnerGroup`;
   ARC then falls back to group ID 1 internally (29-RESEARCH, from the ARC controller source). Only
   `security-platform` can target the runner. That keeps D-07's intent ("security-platform only") by the
   narrowest mechanism the account offers.
2. **A fine-grained PAT limited to one repository, with Administration: Read and write, stored only as a
   SealedSecret.** Administration: Read and write is the documented minimum for repository runners
   (github/docs ARC authentication how-to). The token lives only in SealedSecret
   `arc-runners/arc-github-pat`, key `github_token`, sync-wave `-1` (29-12;
   `evidence/29-13-arc-runners.txt`: `name=arc-github-pat type=Opaque keys=github_token`,
   `sealedsecret=arc-github-pat synced=True`).
   - **29-RESEARCH A6 is now verified.** It was an open assumption that a fine-grained PAT is enough for
     repository-scope registration on a user-owned repository. The listener fetched a registration
     token, opened a broker message session and logged `Starting listener`, with 0 matches for
     401/403/unauthorized/forbidden/bad credentials in its log (29-13; `evidence/29-13-arc-runners.txt`).
     No classic-PAT fallback was needed.
   - **Process record, the 29-12 sealing incident.** The first sealing attempt wrote the env-file line
     through `printf ... >> $ENVF >/dev/null`; the last redirect wins, so the line went to `/dev/null`,
     `seal-secret.sh` failed with `No SECRET_LITERAL_* variables found`, and the command removed the
     plaintext files regardless. The token was never displayed, never reached `kubectl`'s argv, and never
     entered git or evidence. The operator was asked to revoke it, created a new token, and later
     confirmed revocation of the first, verbatim: `revoked` (29-13). The guarded retry was a single
     `set -euo pipefail` script. It checked the context, the literal line count and length without printing
     the value, and the result: kind SealedSecret, the right name and namespace, `Ag…` ciphertext of 832
     characters, and a `github_pat_` count of 0. Only then did it remove the plaintext. Operator replies,
     verbatim, in order: `pat-ready policy-raised`, `issue fixed, try again`, and a third reply naming
     the new token file.
3. **ARC 0.14.2 as two Applications: the controller and the scale set.**
   - `arc-systems`: chart `gha-runner-scale-set-controller` 0.14.2, release `arc`, with
     `ServerSideApply=true` and automated prune **off**, because this Application owns the CRDs. SSA is
     required: the four CRDs as compact JSON are 612,248 bytes (autoscalingrunnersets), 309,369
     (autoscalinglisteners), 307,754 (ephemeralrunners) and 307,683 (ephemeralrunnersets), and all exceed
     the 262,144-byte `last-applied-configuration` annotation cap of client-side apply (29-12; RESEARCH
     Pattern 3). The controller has no `--watch-single-namespace`, so it serves every namespace.
   - `arc-runners`: chart `gha-runner-scale-set` 0.14.2, release `occ-homelab-defectdojo`, prune on, no
     SSA (it owns no CRD).
   - **`controllerServiceAccount` is explicit (`arc-systems/arc-gha-rs-controller`).** The chart
     discovers the controller with `lookup`, which renders empty under Argo CD, and its template then
     calls `fail` ("No gha-rs-controller deployment found…") (RESEARCH Pitfall 5).
   - **Deletion ordering: the scale set first, then the controller.** The scale set's manager Role and
     RoleBinding carry `finalizers`, so deleting the controller first can strand them (RESEARCH
     Pitfall 5). The overlay README records the rollback in that order.
   - **Ordered merge.** Overlay PR #251 (`arc-systems`) merged as `03404fd` at `2026-09-28T15:45:51Z`.
     All four `actions.github.com` CRDs read `Established=True` and the controller Deployment
     `Available=True`, from live state, before PR #252 (`arc-runners`) merged as `d32c5e1` at
     `2026-09-28T22:16:25Z`, pinned by `--match-head-commit` (`evidence/29-13-arc-systems.txt`,
     `29-13-arc-runners.txt`). Operator reply, verbatim: `merge the PRs and then stop`. The listener
     `occ-homelab-defectdojo-776f7979-listener` runs in the controller namespace `arc-systems`, not in
     `arc-runners`, in 0.14.x.
4. **Ephemeral pods, `minRunners 0` / `maxRunners 2`, no `containerMode`, and an exact-pinned runner
   image.** ARC's default ephemeral runner pods are the only runner hardening (D-09). `maxRunners 2` is
   enough because import and cleanup never overlap per branch (they share a concurrency group). There is
   no `containerMode`, so no privileged Docker-in-Docker: the two jobs run `bash`, `python3` and `curl`
   directly. The image is `ghcr.io/actions/actions-runner:2.337.0` (release v2.337.0, published
   `2026-08-26T14:33:29Z`; index `sha256:e5496277be5d09bc968b3d64911b74e219ac4a3f2edce956a3ecf9271bea1ef4`,
   linux/amd64 `sha256:5036480998280bb21e32ade9fe1b02b493861ac314b62ba1aea320b94f56ec97`;
   `evidence/29-11-runner-image.txt`).
5. **`hostAliases` map the `.infra` name to the L2 VIP, because cluster DNS cannot resolve the
   Pi-hole-only name.** CoreDNS forwards to the node resolvers, and none of them answers for Pi-hole-only
   names (RESEARCH Pitfall 2). Measured with the pinned runner image under the one-off D-18 probe waiver
   (operator reply, verbatim: `approve-probes`): without `hostAliases` the pod printed `NO-RESOLVE`; with
   them, `getent` returned the VIP and `curl --proto =https` to `/login` printed `200 0`, HTTP 200 with
   TLS verified against the system trust store (`evidence/29-11-reachability-probe.txt`). TLS still
   verifies by hostname, because the certificate SANs are unchanged. The pod-to-VIP hairpin works, so the
   pinned-ClusterIP fallback of RESEARCH Pitfall 3 was not needed.
6. **The fork-PR approval policy was raised before the label became routable.** On `security-platform`,
   `approval_policy` went from `first_time_contributors` (read `2026-09-28T13:39:02Z`) to
   `all_external_contributors` (read `2026-09-28T13:48:46Z`) (`evidence/29-12-fork-approval-policy.json`).
   `DEFECTDOJO_RUNS_ON` was set only at `2026-09-29T00:14:10Z`, after an automated ordering gate
   confirmed the policy (PRECONDITION-4 PASS, `evidence/29-14-precondition-gate.txt`). The operator made
   the change; reply, verbatim: `pat-ready policy-raised`.
7. **Each future consumer repository gets its own scale set.** With no runner group, "consumers are added
   to the group later" becomes "each consumer repository gets its own repository-scoped
   `AutoscalingRunnerSet`", with its own PAT or a PAT covering that repository too. The scale set name is
   the `runs-on` label and the consumer's `DEFECTDOJO_RUNS_ON` value. The adoption guide's section 12
   caveats say so (29-03). The alternative is moving to an organisation on the Team plan.

**Measured in use (29-15, 29-16, 29-18, 29-19).** Every DefectDojo job after the settings ran on the scale
set: the baseline import (runner `occ-homelab-defectdojo-qqrsp-runner-tbt47`), the proof-workflow import
(`-ntr9z`), the D-11 PR import, reimport and cleanup, the PR #26 cleanup (`-cs6wv`) and the cron-fired
import (`-hqpfs`). The five scan jobs stayed on `ubuntu-latest`. Neither
of the two 29-15 import jobs queued longer than 5 s.

## Consequences

**Improved:** the import reaches a private instance with no inbound exposure to the internet. The
runner dials out to GitHub, the instance stays on the LAN, and TLS to it is verified against the system
trust store with no CA override. Only one repository can target the runner, and only two jobs do.

**Tradeoff — the PAT is repository-takeover-grade on one repository.** Administration: Read and write
on `security-platform` covers more than runner registration: repository settings, webhooks, deploy keys
and branch protection. A leaked PAT is therefore a takeover credential for `security-platform`, not a
runner-registration credential. The operator accepted this (D-08 amended). The blast radius is one
repository, and the token exists only as SealedSecret ciphertext. The residual exposure during sealing
(29-12): `seal-secret.sh` passes the value to a client-side `kubectl create secret --from-literal`, so
it was in the local process list for a sub-second window on a single-user workstation, and APFS has no
reliable overwrite for the deleted plaintext file.

**Tradeoff — PAT expiry means manual rotation.** A fine-grained PAT expires. Rotation is by hand: create
the new token, re-seal it into `arc-github-pat` through the overlay's sealing script, merge the overlay
change, and revoke the old token. An expired PAT would stop the listener authenticating, and the expected
symptom is the same queue as an offline runner (ADR-027); expiry was not observed. A GitHub App would avoid expiry and narrow the permission; it is deferred.

**Tradeoff — a public repository on a self-hosted runner.** `vars` are readable in fork-PR runs, so
`runs-on` resolves to the self-hosted label, and a fork PR's `pull_request` run uses the PR's own copy of
the workflows, so it could rewrite any job to target the label (RESEARCH Pitfall 7). Repository scope
limits which repository can target the runner, not which PR author. The mitigations are the fork
approval policy (decision 6), the skip of fork and Dependabot runs in both DefectDojo jobs, and ephemeral
pods. The residual risk, accepted: a fork PR that a maintainer approves runs on the LAN.

**Tradeoff — no egress NetworkPolicy on runner pods.** The operator declined it (D-09; 29-CONTEXT
Deferred Ideas). A compromised or malicious job on the runner can reach the LAN. It belongs to the
hardening bucket.

**Tradeoff — GitHub's 30-day runner update rule is a second cause of the queue symptom.** ARC registers
scale sets with `DisableUpdate: true` (29-RESEARCH, from the controller source), and GitHub will not
queue jobs to a runner that has gone 30 days without a software update (github/docs). So 30 days after
the **next** runner release, the pinned `2.337.0` image stops receiving jobs, and the import queues
exactly as if the runner were offline (ADR-027, the queue tradeoff). The bump procedure: set the new
exact tag in the `arc-runners` values, open an overlay PR, merge it, and let Argo CD sync. The overlay's
exact-pin rule forbids a floating tag.

**Tradeoff — with `minRunners 0`, the runners API lists nothing until a job runs.** After both merges,
the `security-platform` runners API returned `total_count=0` and no pod existed in `arc-runners` (29-13;
`evidence/29-13-arc-runners.txt`: `No resources found in arc-runners namespace.`). A healthy idle scale
set is only visible through the listener and the `AutoscalingRunnerSet`; the first registered runner
appeared with the first import job (29-15). An empty runner list is not evidence of a fault.

## What was NOT verified

What WAS measured and must not be re-litigated: the account type, the ordered controller-then-scale-set
merge with CRDs Established, the listener session with the fine-grained PAT, the reachability probe with
and without `hostAliases`, the fork approval policy before and after, and the placement of every
DefectDojo job named above on the scale set.

1. **A GitHub App instead of the PAT.** Deferred (29-CONTEXT Deferred Ideas). Its permission set and
   token lifecycle under ARC were not tried.
2. **Organisation-level runner groups.** Impossible on this personal account, and not free for an
   organisation (Team plan). Nothing about them was exercised.
3. **A fork-PR run on the runner.** Not exercised. Fixture PR #25 was a same-repository PR, as D-11
   requires, and no external contributor opened a PR during the phase. That the approval policy blocks
   an unapproved fork run is GitHub's documented behaviour, not a measurement here.
4. **Behaviour at the 30-day boundary.** Not reached: `2.337.0` was the latest release at 29-11. The
   queue-on-stale-runner symptom is from the documentation, and the bump procedure has not been run.
5. **An egress NetworkPolicy.** Declined by the operator; not designed or tested.
6. **The hairpin from other nodes.** Both probe pods were scheduled on the node that holds the VIP's L2
   lease. Cilium socket-LB translates the VIP at `connect()` on every node, so a runner elsewhere is
   expected to behave the same. That is a theory, not a measurement (29-11). The later jobs ran on
   ephemeral runners whose node placement was not recorded.
7. **A runner outage.** No queued job was observed. GitHub cancelling a job queued for about 24h is cited
   (RESEARCH A1), not measured.
8. **PAT rotation.** No rotation was performed after the first sealing. The expiry date of the sealed
   token was not recorded here.
