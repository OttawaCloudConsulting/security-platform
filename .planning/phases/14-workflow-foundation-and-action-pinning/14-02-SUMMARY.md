---
phase: 14-workflow-foundation-and-action-pinning
plan: 02
subsystem: infra
tags: [github-actions, pull-request, workflow-run, reusable-workflows, check-runs, rulesets, branch-protection, evidence]

# Dependency graph
requires:
  - phase: 14-workflow-foundation-and-action-pinning
    provides: "Plan 01's three committed `.github/` files on `feature/phase-14-workflow-foundation` in `repos/security-platform` (unpushed, 2 commits ahead of origin/main)"
provides:
  - "Pushed branch `feature/phase-14-workflow-foundation` on `OttawaCloudConsulting/security-platform` with upstream tracking"
  - "Open pull request #4 against `main` (three-file diff, unmerged) — the merge target for Plan 03"
  - "Observed-green workflow run 34519772020 (`PR Security`, event `pull_request`, conclusion `success`)"
  - "VERBATIM check-run name `security / Placeholder` — required by Phase 18 branch protection"
  - "Ruleset evidence that `main` carries no `required_status_checks` rule (nothing blocks the merge)"
affects: [14-03, 15-scan-jobs, 18-workflow-inputs, 19-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Check-run naming for a reusable-workflow call is `<caller-job-id> / <called-job-name>` — assumption A3 CONFIRMED"
    - "Merge-blocking evidence on this repo comes from the rulesets endpoint (`repos/<slug>/rules/branches/main`), never from a 404 on classic `branches/main/protection`"
    - "Runs are selected by `workflowName` + `event`, never by recency — unrelated Copilot/GitGuardian checks coexist on every PR"

key-files:
  created:
    - .planning/phases/14-workflow-foundation-and-action-pinning/14-02-SUMMARY.md
  modified: []

key-decisions:
  - "Used explicit `--title`/`--body` on `gh pr create` rather than `--fill`: with two commits on the branch `--fill` derives the title from the branch name, not a commit subject"
  - "Recorded the FULL `statusCheckRollup` JSON (with `__typename` and `workflowName`) rather than only the `.name` projection, so Phase 18 can distinguish our CheckRun from the two third-party app checks"
  - "Neither task produced a commit — this plan is purely observational; the only commit is the outer-repo docs commit"

patterns-established:
  - "Pattern: poll `gh run list --branch <br> --json ...` and filter on `workflowName==\"PR Security\" and event==\"pull_request\"` — the branch also carries a `Copilot` run with event `dynamic`"
  - "Pattern: prove a run is not hollow by grepping `gh run view --log` for `Uses: <repo>/.github/workflows/<file>@refs/pull/<N>/merge` plus the checkout command lines"

requirements-completed: []

# Metrics
duration: 7min
completed: 2026-09-10
---

# Phase 14 Plan 02: Live PR and Workflow Run Observation Summary

**Pushing `feature/phase-14-workflow-foundation` and opening PR #4 on `OttawaCloudConsulting/security-platform` triggered workflow run 34519772020 (`PR Security`, event `pull_request`) which completed `success` with the called workflow's `Placeholder` job genuinely executing checkout against `refs/pull/4/merge` — surfacing as the check-run `security / Placeholder`, with the `main` ruleset carrying only `deletion,non_fast_forward` so nothing blocks the merge.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-09-10T19:15Z
- **Completed:** 2026-09-10T19:22Z
- **Tasks:** 2
- **Files created:** 1 (this SUMMARY, outer repo). Zero source files changed in either repository.

## Recorded Values (the deliverable)

| Value | Verbatim |
|---|---|
| **Repository slug** | `OttawaCloudConsulting/security-platform` |
| **Head branch** | `feature/phase-14-workflow-foundation` |
| **Pull request number** | **`4`** — <https://github.com/OttawaCloudConsulting/security-platform/pull/4> |
| **Run `databaseId`** | **`34519772020`** — <https://github.com/OttawaCloudConsulting/security-platform/actions/runs/34519772020> |
| **Run `workflowName`** | `PR Security` |
| **Run `event`** | `pull_request` |
| **Run `status` / `conclusion`** | `completed` / `success` |
| **Check-run name (A3)** | **`security / Placeholder`** |
| **Nested job name** | `security / Placeholder` (`conclusion: success`) |
| **`mergeable`** | `MERGEABLE` |
| **`mergeStateStatus`** | `CLEAN` |
| **`main` ruleset `type`s** | `deletion,non_fast_forward` |
| **PR merged?** | **No.** State `OPEN`. Plan 03 owns the merge. |

## Task Commits

**Neither task produced a commit.** Both tasks are observation-only: Task 1 pushes already-committed work and opens a PR; Task 2 reads run and API state. Zero files changed in `repos/security-platform` (`git status --porcelain` empty, still exactly 2 commits ahead of `origin/main` at the end, same as at the start).

1. **Task 1: Push branch, open PR, confirm caller workflow registered** — no commit (push + PR creation only)
2. **Task 2: Observe run, capture check-run name and merge-blocking evidence** — no commit (read-only observation)

**Plan metadata:** outer documentation repo only (this SUMMARY + STATE + ROADMAP).

## ROADMAP Criteria Witnessed

### Criterion #1 — a PR triggers a security workflow run that does not block the merge — **WITNESSED**

```
{"conclusion":"success","databaseId":34519772020,"event":"pull_request",
 "status":"completed","workflowName":"PR Security",
 "headBranch":"feature/phase-14-workflow-foundation",
 "displayTitle":"feat(14): workflow foundation and action pinning"}
```

Does-not-block evidence (both halves required by the plan):

- `gh pr view 4 --json mergeable,mergeStateStatus` → `MERGEABLE / CLEAN`
- `gh api repos/OttawaCloudConsulting/security-platform/rules/branches/main` →

  ```json
  [{"ruleset_id":14243983,"ruleset_source":"OttawaCloudConsulting/security-platform","ruleset_source_type":"Repository","type":"deletion"},
   {"ruleset_id":14243983,"ruleset_source":"OttawaCloudConsulting/security-platform","ruleset_source_type":"Repository","type":"non_fast_forward"}]
  ```

  No `required_status_checks` rule. This is the **authoritative** evidence.

### Criterion #2's wiring — the caller's relative `uses:` actually resolved — **WITNESSED LIVE**

From `gh run view 34519772020 --log` (163 lines, all under `security / Placeholder`):

```
Uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@refs/pull/4/merge (a954d927054f26ca25d12a6e80e2527031a43fd6)
Complete job name: security / Placeholder
##[group]Run actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
Syncing repository: OttawaCloudConsulting/security-platform
##[group]Initializing the repository
[command]/usr/bin/git -c protocol.version=2 fetch --no-tags --prune --no-recurse-submodules --depth=1 origin +a954d927054f26ca25d12a6e80e2527031a43fd6:refs/remotes/pull/4/merge
##[group]Checking out the ref
[command]/usr/bin/git checkout --progress --force refs/remotes/pull/4/merge
HEAD is now at a954d92 Merge b09d06afff7caac01e5d069baf347ef584bb113b into 7943aa300e921d8d2ebfe80f78a61811a075f91a
Post job cleanup.
```

This is **not** a hollow pass. Three independent facts fall out of it:

1. The relative reference resolved to `security.yml@refs/pull/4/merge` — the workflow ran from the PR's own merge commit, empirically confirming the "a PR exercises its own workflow changes" property Plan 01 asserted structurally.
2. The checkout ran at the exact pinned SHA `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0`, so the pin is live, not merely well-formed YAML.
3. `HEAD is now at a954d92 Merge b09d06a… into 7943aa3…` confirms `GITHUB_SHA` is the base⊕head merge commit, exactly as RESEARCH predicted.

**T-14-03 verified live** — the runner's own token report:

```
##[group]GITHUB_TOKEN Permissions
Contents: read
Metadata: read
##[endgroup]
```

Only `contents: read` (plus unavoidable `metadata`). The `permissions:` block in both workflow files is enforced at runtime.

## Assumption A3: CONFIRMED

RESEARCH predicted the check would surface as `<caller-job-name> / <called-job-name>`. **It does.** Full raw `statusCheckRollup`, unreformatted:

```json
[{"__typename":"CheckRun","completedAt":"2026-09-10T19:20:08Z","conclusion":"SUCCESS","detailsUrl":"https://github.com/OttawaCloudConsulting/security-platform/actions/runs/34519772020/job/103014090693","name":"security / Placeholder","startedAt":"2026-09-10T19:20:03Z","status":"COMPLETED","workflowName":"PR Security"},
 {"__typename":"CheckRun","completedAt":"2026-09-10T19:20:01Z","conclusion":"SUCCESS","detailsUrl":"https://dashboard.gitguardian.com","name":"GitGuardian Security Checks","startedAt":"2026-09-10T19:20:00Z","status":"COMPLETED","workflowName":""}]
```

**For Phase 18, the string to configure as a required status check is exactly:**

```
security / Placeholder
```

Precise caveat on what that string is made of — Phase 18 must not get this wrong:

- The left half is the caller **job ID** (`security:`, the YAML key in `pr-security.yml`), which here coincidentally equals its `name:` value (also `security`). The right half is the called job's **`name:`** (`Placeholder`, from `security.yml`'s `name: Placeholder`, not its job ID `placeholder` — note the capital P).
- Separator is space-slash-space.
- **Phase 15 will change this string.** When the `Placeholder` job is replaced by five parallel scan jobs, this single check becomes five checks named `security / <each-new-job-name>`. Phase 18 must read the then-current names, not hard-code `security / Placeholder`.

## Other Check Runs Present — NOT Ours

Two third-party surfaces appear on this PR and must not be mistaken for phase output:

| Surface | Where it appears | Notes |
|---|---|---|
| `GitGuardian Security Checks` | in `statusCheckRollup`, `__typename: CheckRun`, `workflowName: ""` | A GitHub App (`dashboard.gitguardian.com`), not a workflow file. Concluded `SUCCESS`. **Not installed by this project** and not under this phase's control. |
| `Copilot` | in `gh run list` only, `databaseId 34519781051`, `event: dynamic`, `status: in_progress` | GitHub App run, absent from the rollup. The plan anticipated this under the name "Copilot code review". |

The `workflowName == "PR Security" && event == "pull_request"` filter correctly excluded both — matching on recency would have selected the `Copilot` run instead, since it is *newer* than ours.

## Workflows API — as the plan predicted

```
PR Security	.github/workflows/pr-security.yml	active
Copilot code review	dynamic/copilot-pull-request-reviewer/copilot-pull-request-reviewer	active
```

`.github/workflows/security.yml` is **absent**, exactly as the plan's `<notes>` warned it would be: the endpoint lists default-branch workflows plus those with runs of their own, and a callable-only workflow pre-merge has neither. This is not a defect. The both-registered assertion belongs to Plan 03, post-merge.

## Decisions Made

### `--title`/`--body` instead of `--fill`

`gh pr create --fill` with **two** commits on the branch derives the title from the branch name rather than a commit subject, producing `Feature/phase 14 workflow foundation`. An explicit title (`feat(14): workflow foundation and action pinning`) keeps the PR identifiable by phase, as the plan's step 3 requested.

### Full rollup JSON recorded, not just `.name`

`statusCheckRollup` entries are polymorphic — `CheckRun` objects carry `.name`, `StatusContext` objects carry `.context`. Recording the raw JSON preserves `__typename` and `workflowName`, which is what lets Phase 18 tell our `PR Security` CheckRun apart from GitGuardian's app CheckRun (whose `workflowName` is the empty string). A bare `.name` projection would have lost that discriminator.

### Classic branch-protection 404 recorded as illustration only, never as evidence

`gh api repos/<slug>/branches/main/protection` returns `{"message":"Branch not protected","status":"404"}`. Per the plan this is a **false negative** — the endpoint covers classic protection only, and this repo uses a ruleset (`ruleset_id 14243983`). It is recorded here purely to document the trap; the merge-blocking conclusion rests entirely on the rulesets endpoint.

## Deviations from Plan

**None — plan executed exactly as written.** Every precondition and assertion passed on first evaluation.

Two plan-anticipated contingencies did **not** materialise and so required no handling:

- **Gitleaks pre-push did not block.** `.git/hooks/pre-push` is installed and ran; `Detect hardcoded secrets ... Passed`. `--no-verify` was not used. (Plan 01 flagged that gitleaks had not yet been exercised against these files — it now has.)
- **`mergeable` never returned `UNKNOWN`.** It returned `MERGEABLE / CLEAN` on the first query. A second confirmatory query ~1 min later returned the same, so the re-query fallback the plan mandated was satisfied vacuously rather than skipped.

## Issues Encountered

None. Full precondition and gate results:

| Check | Result |
|---|---|
| `git -C repos/security-platform ls-files .github \| wc -l` | `3` |
| `git -C repos/security-platform status --porcelain` | empty (before and after) |
| `git -C repos/security-platform diff --quiet` / `--cached --quiet` | both exit 0 |
| `.git/hooks/pre-push` installed, `core.hooksPath` | present / unset |
| Push (`git -C repos/security-platform push -u origin HEAD`) | rc=0, `* [new branch]`, upstream tracking set |
| Pre-push hook run | `yamllint Passed`, `Detect hardcoded secrets Passed`, rest skipped |
| `gh pr create` | `.../pull/4` (**not** the pre-existing PR #3) |
| `gh pr diff 4 --name-only` | exactly the 3 `.github/` paths, nothing else |
| Workflows API contains `.github/workflows/pr-security.yml` `active` | yes |
| "workflow file issue" parse-error banner | none |
| Run located by `workflowName`+`event` | `34519772020` on poll attempt 1 |
| `gh run watch 34519772020 --exit-status` | rc=0 (`already completed with 'success'`) |
| Checkout step present in `--log` | yes (4 distinct checkout log lines) |
| Task 1 automated verify gate | PASS |
| Task 2 automated verify gate | PASS |

## Threat Model Coverage

| Threat ID | Disposition | Evidence in this plan |
|-----------|-------------|------------------------|
| T-14-17 | mitigated | Every git command scoped `git -C repos/security-platform`. Zero git or `gh` commands ran against the outer documentation repo's remote. The slug was resolved from the product repo's own `origin`, never hardcoded. |
| T-14-08 | mitigated | The product repo's `.git/hooks/pre-push` gitleaks hook ran and **Passed** on the real push. `--no-verify` was not used anywhere. |
| T-14-19 | mitigated | PR matched by head branch (→ #4, not the pre-existing #3); run matched by `workflowName`+`event` (→ 34519772020, not the newer `Copilot` run 34519781051). "Most recent" was never used as a selector — and would have picked the wrong run. |
| T-14-03 | mitigated | Runner log shows `GITHUB_TOKEN Permissions / Contents: read / Metadata: read`. Least privilege enforced at runtime, not just declared. |
| T-14-10 | mitigated | Selection filter `workflowName == "PR Security" and event == "pull_request"`. Searching for `Security Scans` would have found nothing (the callable workflow has no runs of its own). |
| T-14-11 | mitigated | The run passed first time; nothing was re-pushed or re-run. `gh run watch --exit-status` returned rc=0. |
| T-14-06 | accepted | Plain `pull_request` trigger (D-04), read-only token, no `secrets:` passed to the called workflow. |
| T-14-SC | mitigated | No npm/pip/cargo installs. Only `git` and `gh` operations were performed. |

## Known Stubs

The `Placeholder` job remains an intentional stub per D-01 — checkout and nothing else. This plan's purpose was to prove the *wiring* is live, and it did. **Phase 15** replaces it with the five real parallel scan jobs, which will also change the check-run name(s) recorded above.

## User Setup Required

None. PR #4 is open and awaiting Plan 03's merge — no user action is required before then.

## Next Phase Readiness

**Ready for Plan 03.** Carry-forward:

- **PR `4`** is OPEN, `MERGEABLE`/`CLEAN`, against base `main`, three-file diff, **unmerged**. Plan 03 merges it.
- **Run `34519772020`** is the green pre-merge witness. Post-merge, Plan 03 should expect the workflows API to then list **both** `pr-security.yml` and `security.yml` (the both-registered assertion the plan deliberately deferred out of Plan 02).
- **Criterion #4 (Dependabot v7.0.0 → v7.0.1 bump PR)** still requires `dependabot.yml` to reach the **default branch**, which only happens when PR #4 merges. Unchanged from Plan 01's assessment.
- **Phase 18** must use the check-run string `security / Placeholder` verbatim — while noting Phase 15 will replace it with five `security / <job-name>` checks.

ROADMAP criterion **#1** is now witnessed live, and criterion **#2**'s caller→called wiring is confirmed executing rather than merely well-formed.

---
*Phase: 14-workflow-foundation-and-action-pinning*
*Completed: 2026-09-10*

## Self-Check: PASSED

`14-02-SUMMARY.md` exists on disk and records both the PR number (`4`) and run `databaseId` (`34519772020`), with the verbatim check-run name `security / Placeholder`. Live re-verification at self-check time: PR 4 is `OPEN` (unmerged) and run 34519772020 is `completed/success`. No task in this plan produced a source commit — the plan is observation-only — so there are no per-task commit hashes to verify.
