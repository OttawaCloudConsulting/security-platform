# 25-05 Chart edit assessment: closing 25-RESEARCH Open Question 3

**Question:** does `repos/security-platform/kubernetes/nexus/templates/job-provision.yaml` need either of the
two optional corrections named in 25-RESEARCH Pitfall 2?

1. an explicit `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation`
2. a changed position on `ttlSecondsAfterFinished: 900` under Argo CD

The answer below is based on the two live syncs on `admin@occ-new`, not on the documentation. Chart
revision under test: `aed14b916e9aa8ec1d0d47699b457040b99f7eac`. Overlay revision:
`a05471be7ea73d455d31e66f9026fccdaa4cd8f7`. Both syncs used the same two revisions.

## The annotation block as deployed

The live Job object carried these annotations (read with `kubectl get job nexus-provision -o json`,
2026-09-24T01:09:43Z):

```
argocd.argoproj.io/hook: Sync
argocd.argoproj.io/sync-options: Replace=true
helm.sh/hook: post-install,post-upgrade
helm.sh/hook-delete-policy: before-hook-creation
helm.sh/hook-weight: "0"
```

It carries no `argocd.argoproj.io/hook-delete-policy` key. `spec.ttlSecondsAfterFinished` is `900`.

## Q1: Was the provisioning Job treated as a Sync-phase Argo CD hook?

**Yes. Measured `hookType: Sync` on both syncs.**

- First sync: `25-04-first-sync-application.json` records
  `{"kind":"Job","name":"nexus-provision","hookType":"Sync","hookPhase":"Succeeded","status":"Synced"}`.
- Second sync: `.status.operationState.syncResult.resources[] | select(.hookType)` records
  `{"kind":"Job","name":"nexus-provision","hookType":"Sync","hookPhase":"Succeeded","status":"Synced","message":"Reached expected number of succeeded pods"}`.

This confirms Pitfall 1. `argocd.argoproj.io/hook: Sync` takes precedence, and the `helm.sh/hook: post-install,post-upgrade`
mapping to PostSync did not apply. `PostSync` was not observed.

## Q2: Did Argo CD's `BeforeHookCreation` behaviour actually apply?

**Yes. The first Job was deleted and a new Job was created under the same name, with no error.**

| | First sync | Second sync |
|---|---|---|
| Operation `startedAt` | `2026-09-24T01:03:06Z` | `2026-09-24T01:12:25Z` |
| Job `metadata.uid` | `11400922-1baf-48c3-a1e0-a63ed45aa332` | `f3c25405-d448-4fe9-b429-58b532c84eae` |
| Job `creationTimestamp` | `2026-09-24T01:03:09Z` | `2026-09-24T01:12:28Z` |
| Job `completionTime` | `2026-09-24T01:04:55Z` | `2026-09-24T01:12:32Z` |
| Operation phase / message | `Succeeded` | `Succeeded` / `successfully synced (no more tasks)` |

- **The first Job still existed right before the second sync.** At 01:09:43Z it was present with UID
  `11400922-…`, 288 s after it completed and inside its 900 s TTL. So the TTL reaper did not remove it.
  The sync did.
- **The second sync created a Job with a different UID under the same name** (`nexus-provision`). This is
  delete-then-create, which is what `BeforeHookCreation` means. A plain `kubectl apply` would have kept the
  object and its UID.
- **No `spec.template is immutable` error occurred.** The operation message was
  `successfully synced (no more tasks)`, and the operation reported zero sync-result resources with a status
  other than `Synced`.
- **The two logs differ in the expected ways.** The second log (`25-05-second-sync-provision.log`) shows
  `action=updated` 4 times and `action=created` 0 times. It also contains
  `realms: DockerToken already active — no change, and no request was made.` The first log shows
  `action=created` 4 times and `realms: appended DockerToken (HTTP 204)`.

**Caveat:** this measurement cannot tell which source supplied the policy. Two sources give
`BeforeHookCreation`:

- Argo CD's documented default when no delete policy is set.
- The `helm.sh/hook-delete-policy: before-hook-creation` annotation, which Argo CD's Helm mapping table
  lists as "Supported". This conflicts with the same page's "if you define any Argo CD hooks, *all* Helm
  hooks will be ignored".

Both sources lead to the same behaviour, and that behaviour is what was measured. See the unverified-items
line at the end.

**Also measured, and it does not change the verdict:** the Job carries
`argocd.argoproj.io/sync-options: Replace=true`. Both syncs rendered an identical pod template, because the
revisions were the same. So these two syncs did not exercise the immutable-template failure that the
template's header comment predicts when a template changes. The UID change shows that the Job is deleted
and recreated on every sync. That is the mechanism that prevents the immutable-template failure whatever
the template contents.

## Q3: Did `ttlSecondsAfterFinished: 900` truncate anything?

**No. Both Job logs were fully readable, and neither operation waited on a vanished hook.**

| Sync | Job `completionTime` | Log captured | Completion to capture | Source of the capture time |
|---|---|---|---|---|
| First | `01:04:55Z` | `01:05:04Z` | **9 s** | 25-04-SUMMARY timeline. The evidence file's mtime (`01:08:25Z`) records the FQDN-redaction rewrite in `58bc8ab`, not the capture, so it is not used here |
| Second | `01:12:32Z` | `01:12:36Z` | **4 s** | `date -u` printed at capture time, and the mtime of the unredacted raw capture (`01:12:36Z`) |

- **Neither operation stalled.** For the first sync, the 25-04 timeline shows the Job completing at
  `01:04:55Z` and the operation `Succeeded` by the `01:05:04Z` poll. The second operation's `finishedAt`
  (`01:12:32Z`) equals the Job's `completionTime` (`01:12:32Z`). Argo read the hook phase in the same second
  the Job completed, so the TTL was never close to mattering.
- **Both logs are complete.** Each ends with
  `Provisioning complete: 4 proxy repositor(ies) present and online.`
- The worst case measured across both syncs used 9 s of the 900 s window.

## Verdict

**NO CHART EDIT NEEDED.**

All three observations matched the documented behaviour:

- Q1: the Job ran as a Sync-phase hook.
- Q2: `BeforeHookCreation` delete-then-create happened on the second sync, with no immutable-template error.
- Q3: the 900 s TTL truncated nothing, and neither operation stalled.

Argo CD's defaults held when measured.

Pitfall 2 names one residual risk: the TTL limits the log-inspection window to 15 minutes after completion,
which matters if an operation stalls. It is handled by procedure, not by the chart. Capture the Job log as
soon as `.status.succeeded >= 1`, as plans 25-04 and 25-05 did, taking 9 s and 4 s.

**What plan 25-06 does with this:** makes no change to
`repos/security-platform/kubernetes/nexus/templates/job-provision.yaml`, and asserts an empty diff under
`kubernetes/nexus/`. The annotation keys considered and rejected on this evidence:

- Adding `argocd.argoproj.io/hook-delete-policy`. Its effective value `BeforeHookCreation` was measured
  without it.
- Removing or lowering `ttlSecondsAfterFinished`. It must **not** be removed in any case. The template's own
  comment records 900 as a floor that protects the `--timeout=300s` waits in plans 23-02 and 23-06
  (`Do not lower it below 600`).

The existing annotations stay as they are:

- `argocd.argoproj.io/hook: Sync`
- `argocd.argoproj.io/sync-options: Replace=true`
- `helm.sh/hook: post-install,post-upgrade`
- `helm.sh/hook-weight: "0"`
- `helm.sh/hook-delete-policy: before-hook-creation`

The `helm.sh/*` keys are still what the direct `helm install` path uses.

An explicit `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation` would only make the source of the
policy unambiguous. It would not change the behaviour measured here. If it is ever wanted as hardening, it
belongs in its own `security-platform` PR with its own gates. It is not a correction that this evidence
requires.

## For ADR-022 `## What was NOT verified`

Not verified about the hook semantics: which source supplied the observed `BeforeHookCreation` policy
(Argo's no-policy default or the mapped `helm.sh/hook-delete-policy`); a sync with a changed Job pod template;
a stalled operation that runs past the 900 s TTL; and hook behaviour across an Argo CD version upgrade.
