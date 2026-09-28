---
phase: 29-defectdojo-live-validation
plan: 13
subsystem: k8s-infrastructure
tags: [defectdojo, arc, gha-runner-scale-set, argocd, ordered-merge, d-06, d-07, ddojo-05]
requires:
  - "29-12: feat/arc-systems @ ad8c5db and feat/arc-runners @ 1070fac, SealedSecret arc-github-pat, fork policy all_external_contributors"
  - "29-02: homelab context admin@occ-new, platform AppProject admits arc-systems/arc-runners"
provides:
  - "occ-k8s-app-config main: PR #251 (arc-systems) merge 03404fd, PR #252 (arc-runners) merge d32c5e1"
  - "Live ARC controller arc-systems/arc-gha-rs-controller (0.14.2) with 4 actions.github.com CRDs Established"
  - "Live repo-scoped scale set occ-homelab-defectdojo (min 0, max 2) with listener arc-systems/occ-homelab-defectdojo-776f7979-listener Running and holding a broker message session"
  - "Precondition 2 of the 29-14 ordering gate (listener Running) holds"
affects: [29-14, ADR-027, ADR-028]
tech-stack:
  added: []
  patterns:
    - "Ordered GitOps merge: controller PR first, assert CRDs Established + controller Available from live reads, then merge dependent PR with --match-head-commit"
    - "Listener log capture is scanned in scratch (token prefixes, JWT, 40+ char tokens, 401/403) before it is written to evidence; the evidence records the scan counts, not the patterns themselves"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-13-arc-systems.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-13-arc-runners.txt
  modified: []
decisions:
  - "29-13: operator reply to Task 2 was `merge the PRs and then stop`, so both PRs were merged in order and execution stops after 29-13"
  - "29-13: ARC listener for 0.14.x runs in arc-systems (controller namespace), not arc-runners; name occ-homelab-defectdojo-776f7979-listener"
  - "29-13: security-platform runners API total_count=0 after the merges is the expected state with minRunners 0; the first registered runner is evidence for the first import job in 29-14+"
  - "29-13: shared overlay tree was not checked out to main (another session owns feat/lightrag-scaffold); only worktree remove + fetch were run"
metrics:
  duration: "PRs opened 15:41Z, #251 merged 15:45:51Z; executor interrupted (machine sleep); resumed 22:16Z, #252 merged 22:16:25Z, listener Running by 22:19Z"
  completed: 2026-09-28
  tasks: 3
  files: 2
---

# Phase 29 Plan 13: Ordered ARC merges, controller and listener verified Summary

The ARC controller and the repo-scoped scale set are live on `admin@occ-new`, and they were merged in order. PR #251 (arc-systems) merged first at 15:45:51Z. All four `actions.github.com` CRDs were read as `Established=True` and the controller Deployment as `Available=True` before PR #252 (arc-runners) merged at 22:16:25Z. About three minutes later, Application `arc-runners` was Synced/Healthy. The listener `arc-systems/occ-homelab-defectdojo-776f7979-listener` was Running and had opened a broker message session with the sealed fine-grained PAT, with no 401/403. The security-platform runners API reports `total_count=0`, which is expected with minRunners 0.

## Operator decisions (verbatim)

| Question | Reply |
|---|---|
| Task 2 checkpoint (approve ordered ARC merges) | `merge the PRs and then stop` |
| Orphaned first PAT from the 29-12 sealing incident revoked? | `revoked` |
| After the executor interruption | `retry and restart if you need to` |

## Merges

| PR | Branch | Head | Merge commit | Merged at | Files |
|---|---|---|---|---|---|
| #251 | feat/arc-systems | ad8c5db8c09cc44971c5216265125d9baf2fc3e9 | 03404fd30d99321b832bea6be84b2e529e9170d3 | 2026-09-28T15:45:51Z | arc-systems/README.md, arc-systems/argocd-overrides.yaml |
| #252 | feat/arc-runners | 1070fac4bbb2bb9315b4ab3304cc8e633b9c6557 | d32c5e177848e192609f7b8d10491b5e2c787433 | 2026-09-28T22:16:25Z | .gitleaksignore, arc-runners/{Chart.yaml, README.md, argocd-overrides.yaml, templates/sealedsecret-arc-github-pat.yaml} |

Both diffs touch only their own directory, plus `.gitleaksignore` for arc-runners. At merge time, #252 had `conformance` pass and `GitGuardian Security Checks` pass. It was merged with `--match-head-commit 1070fac…`.

## For plan 29-14

| Item | Value |
|---|---|
| Listener | `arc-systems/occ-homelab-defectdojo-776f7979-listener`, 1/1 Running, node occ-cs-k8worker01 |
| Controller | `arc-systems/arc-gha-rs-controller-f6b864554-tvc7v`, 1/1 Running, 0 restarts |
| AutoscalingRunnerSet | `arc-runners/occ-homelab-defectdojo`, min 0, max 2; EphemeralRunnerSet `occ-homelab-defectdojo-qqrsp` replicas 0 |
| Secret | `arc-runners/arc-github-pat`, Opaque, key `github_token`; SealedSecret Synced=True |
| Runs-on label | `occ-homelab-defectdojo` (inert until `DEFECTDOJO_RUNS_ON` is set) |
| Repo runners API | `total_count=0` (minRunners 0) |

## Task 1: Push and open both PRs

The earlier executor did this before the interruption. PR #251 was created at 15:41:20Z and PR #252 at 15:41:23Z, with titles as specified in the plan. `conformance` and GitGuardian are green on both.

## Task 2: Operator checkpoint

The operator replied `merge the PRs and then stop`. That reply grants both merges in order, and it bounds execution to this plan.

## Task 3: Ordered merge and verification (docs 6d8039c)

1. **arc-systems** (`evidence/29-13-arc-systems.txt`). Application Synced/Healthy, and the operation Succeeded at 15:48:26Z on chart revision `0.14.2`. The four CRDs are `autoscalingrunnersets`, `autoscalinglisteners`, `ephemeralrunners` and `ephemeralrunnersets.actions.github.com`, all `=True`. The Deployment `arc-gha-rs-controller` is 1/1 and `Available=True`, with image `ghcr.io/actions/gha-runner-scale-set-controller:0.14.2`. These were captured at 22:16:03Z, just before #252 merged, so the gate was checked against live state and not taken from before the interruption.
2. **arc-runners** (`evidence/29-13-arc-runners.txt`). The Application appeared on the 6th 30s poll, at 22:19:05Z, as Synced/Healthy. Its operation Succeeded at 22:18:44Z on revisions `["0.14.2","d32c5e1…"]`. The listener log has 14 lines in total, all of them captured. They show `refreshing token` → `getting runner registration token` → `getting Actions tenant URL and JWT` → a session POST to `runnerscalesets/1/sessions` → `Starting listener` → `totalAssignedJobs=0` → `Ephemeral runner set scaled ... replicas=0` → `Getting next message`. The scan run before writing found 0 GitHub token prefixes, 0 `eyJ`, 0 strings of 40+ token characters and 0 401/403/unauthorized/forbidden/bad credentials, so no redaction was needed. RESEARCH A6 (a fine-grained PAT failing on a user-owned repo) did not materialise, and no classic-PAT fallback is needed.
3. **Cleanup.** Ran `git -C occ-k8s-app-config worktree remove wt-29-12` (clean on feat/arc-runners @ 1070fac), then `git fetch origin`, which moved origin/main `08ce26b..d32c5e1`. The shared tree was left on `feat/lightrag-scaffold` @ `ce2f8f0`, which belongs to another session. Its worktree list is the main tree plus `/private/tmp/occ-5.4-outage` [drill/5.4-authentik-restore, prunable], which is not ours and was left untouched. The remote branches feat/arc-systems and feat/arc-runners were left in place.

Plan verify: `VERIFY_PASS` (6 `=True` lines, `occ-homelab-defectdojo` and `Running` present, 0 PAT-prefix matches across both evidence files).

## Deviations from Plan

1. **Executor interrupted after the #251 merge (machine sleep) and resumed.** The previous executor had opened both PRs, got the operator reply, and merged #251. No evidence or SUMMARY had been written. The resumed executor re-captured arc-systems evidence from live state about 6.5h after the merge, with the controller at 0 restarts and age 6h27m. It then re-confirmed #252's head and checks and merged with `--match-head-commit`. The arc-systems poll-until-healthy step (step 1 of Task 3) was therefore a single live read rather than a poll, because the state had already converged.
2. **No `checkout main && pull --ff-only` in the shared overlay tree.** Another session has `feat/lightrag-scaffold` checked out there. Only `worktree remove` and `fetch origin` were run, as the orchestrator instructed.
3. **Evidence wording.** The listener-scan note in `29-13-arc-runners.txt` describes the token prefixes in words rather than quoting the regex, so that the plan's own PAT-pattern verify doesn't count the note as a hit.

## Threat Flags

None beyond the plan's threat model. T-29-02 was mitigated: logs were scanned before they were written. T-29-20 was mitigated: the controller and CRDs were verified before the scale-set merge.

## Known Stubs

None.

## Next

Execution stops here at the operator's request (`merge the PRs and then stop`). The next plan is 29-14 (wave 9), and it was not started. DDOJO-05 is not complete, because the CI import is not yet proven live.

## Self-Check: PASSED

- FOUND: evidence/29-13-arc-systems.txt, evidence/29-13-arc-runners.txt
- FOUND: docs commit 6d8039c
- FOUND: overlay merge commits 03404fd, d32c5e1 on origin/main
