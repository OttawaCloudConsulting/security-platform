# ADR-033: A Closed-Then-Reopened Pull Request Is Not Merged on Its Close Run's Skipped Checks

**Status:** Accepted
**Date:** 2026-10-08
**Addresses:** 27-HUMAN-UAT item 3 (the closed-PR reopen race), T-27-11, 27-RESEARCH Pitfall 8, ADR-024
"What was NOT verified" item 2 (the closed-PR reopen window), and v3.0-MILESTONE-AUDIT item 6

This record lives in this documentation repository. Every measured value below is quoted from a file in the Phase 29.6
`evidence/` directory (`.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-/evidence/`),
and each is attributed where it appears. The exercise ran in a throwaway repository,
`OttawaCloudConsulting/sp-reopen-race-scratch`. The first line of `29.6-11-repo-delete.txt` reads
`29.6-11-repo-delete: deleted`: the throwaway repo OttawaCloudConsulting/sp-reopen-race-scratch
was deleted after capture (D-06), so run links are dead and the files stand alone. The closeout captures ran from 2026-10-08T19:47:35Z to
19:47:48Z, the orchestrator's 404 readback was at 19:48:11Z, and `29.6-11-manifest.json` reads `complete: true`,
`missing: []` over PRs #1 to #7, nine head SHAs and the six attempt directories. Run and suite IDs are cited below as
bare numbers for that reason.

Who ran what. The orchestrating Claude session ran the live writes (repository bootstrap, ruleset apply, the race
script) on the operator's explicit approval at each checkpoint (`29.6-09-race-run.txt` and `29.6-10-race-run.txt` record
this for the two race variants).
The operator ran two actions personally: the plan 07 Task 3 merge attempt on PR #1 ("I'll run it myself",
`29.6-07-refusal.txt`), and the repository delete. The delete was a deviation from the D-06 procedure: the operator
deleted the repository outside the session, after the capture but ahead of the planned delete checkpoint, and the
delete method was not observed (`29.6-11-repo-delete.txt`, DEVIATION block).

## Context

- **The mechanism under test (27-RESEARCH Pitfall 8).** `pr-security.yml` triggers on `closed` as well as `opened`,
  `synchronize` and `reopened`, so DefectDojo can delete a branch engagement on close. On a closed pull request the
  five scan jobs are skipped, so the close run writes a `skipped` check run for each of the five required contexts on
  the head SHA. GitHub treats `skipped` as passing. If the pull request is reopened and merged before the reopen run's
  jobs are queued, the newest check run per context could be the close run's `skipped` one, and a red head could merge.
- **ADR-024 left this open.** ADR-024 "What was NOT verified" item 2 reads: "27-08 observed what Pitfall 8 assumed: on
  the merged PR's head `7c47270`, every `security / ...` context has two check runs, `success` from 36156728417 and a
  newer `skipped` from the close run 36158851741. Skipped counts as passing. PR #21 was merged, so nothing was blocked.
  Whether a close, reopen and merge could land before the reopen run's jobs queue, and so merge on the skipped runs,
  was not exercised."
- **The adoption-guide claim tested.** `docs/adoption-guide.md` says: "On a closed pull request, the five scan jobs
  report as skipped, which counts as success. The pull request is already closed at that point, so nothing is
  blocked." The race asks whether that stays true once the pull request is reopened.
- **Every attempt ran on a red head SHA (D-18).** `skipped` over `success` merges under normal GitHub behaviour, so an
  attempt on a green SHA cannot tell the race apart from ordinary behaviour. Each attempt therefore ran with
  `GATE_MODE=blocking` and a deterministic finding, so the head's last real scan was `failure` on two required
  contexts. Green-SHA attempts were not run.
- **The account and the plan tier (D-20, D-04).** `OttawaCloudConsulting` is a User account, not an organisation
  (`29.6-05-preflight.txt`: `{"login":"OttawaCloudConsulting","type":"User"}`; `orgs/OttawaCloudConsulting` returned
  404). The plan tier is inferred to be Pro and was not verified. Because a ruleset that GitHub accepts but does not
  enforce would make every attempt look blocked for the wrong reason, a live enforcement proof on the private repo was
  mandatory before any race attempt.
- **DefectDojo was off (D-03).** The scratch repo had no `DEFECTDOJO_URL` and no `DEFECTDOJO_API_TOKEN`, so both
  DefectDojo jobs skipped. The homelab instance and the ARC runner (ADR-028) were not involved.
- **The caller.** The scratch repo's Mode B caller (`29.6-seed/pr-security.yml`) called
  `OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1`. `v1` read
  `6c0d5319b1c328f135b47acd47e1a5e92ae2b10c` at the start and at the end (`29.6-v1-start.txt`, `29.6-v1-end.txt`).

## Decision

1. **Record the race as measured: six attempts, six refused merges, none accepted.** 27-HUMAN-UAT item 3 passes on
   evidence (D-12). The operator ruled `accept-blocked` at the D-11 gate after the client-side and server-side caveat
   below was presented (`29.6-10-d11-gate.txt`, canonical line `ruling: accept-blocked`).
2. **No change to `security.yml`, `pr-security.yml` or the adoption guide.** The Pitfall 8 "zero-risk alternative" (a
   separate caller file for `closed` with a different job id) is not needed on this evidence. No release follows from
   this record.
3. **ADR-024 "What was NOT verified" item 2 is resolved by this record, with the caveats stated below.** ADR-024 is
   not edited; `docs/adr/` is append-only per `CLAUDE.md`, so the resolution is by reference.

What is resolved, stated precisely: a close, reopen and merge on a red head did not merge in six attempts across two
timings, and in the two attempts where the server judged the merge, it judged the reopen run's queued required checks,
not the close run's skipped ones. What is not resolved: variant (b), the UAT literal timing, was refused by `gh` on the
client side in all three attempts, so under (b) the server merge path was not reached; and six finite attempts do not
prove the merge is impossible.

## Measured evidence

### Enforcement proof on the private repo (plans 05 to 08)

| Measurement | Where | Result | Source |
|---|---|---|---|
| Target repo | live | `OttawaCloudConsulting/sp-reopen-race-scratch`, visibility `PRIVATE`, ruleset 24593937; `fallback: false` (no public fallback) | `29.6-race-target.json`, `29.6-08-enforcement-verdict.json` |
| Red set on SHA-2 | live | SHA-2 `172d2c237f9ef6045d26df0b42a4e5d6b97ebee0`, run 37496059742: `security / IaC — Checkov` and `security / SAST — Semgrep CE` `failure`, the other three `success`. Checkov `CKV_DOCKER_2`, `CKV_DOCKER_3` (on `/Dockerfile`); Semgrep `dockerfile.security.missing-user.missing-user` | `29.6-06-red-set.json` |
| UNSTABLE | live | SHA-2, 2026-10-06T16:31:41.010Z, `GATE_MODE=blocking`, 0 rulesets | `29.6-06-merge-state-unstable.json` |
| BLOCKED | live | same SHA-2, 2026-10-06T16:40:56.777Z, ruleset 24593937 applied with the five required contexts | `29.6-07-merge-state-blocked.json` |
| CLEAN | live | SHA-3 `377b4caf2a6d33f161cf9c9bcb8987976905fc42`, 2026-10-07T12:48:18.440Z, `GATE_MODE` unset, all five required contexts `success` (run 37623424945), ruleset unchanged | `29.6-08-merge-state-clean.json`, `29.6-08-checkruns-clean.json` |
| Bypass | live | `bypass_actors: []`, `current_user_can_bypass: never`, re-read unchanged at the refusal and in plan 08 | `29.6-07-ruleset-after.json`, `29.6-08-enforcement-verdict.json` |
| PR-0 refusal | live | PR #1 on SHA-2 (BLOCKED), operator-run `gh pr merge 1 --squash --match-head-commit`: rc 1, PR still `OPEN`, `mergedAt` null; classified client-side | `29.6-07-refusal.txt`, `29.6-07-refusal-stderr.txt` |
| Enforcement ruling | operator | reply verbatim `proceed (Recommended)`; `ruling: proceed` | `29.6-08-enforcement-ruling.txt` |

PR-0 refusal stderr, verbatim (`29.6-07-refusal-stderr.txt`):

```text
X Pull request OttawaCloudConsulting/sp-reopen-race-scratch#1 is not mergeable: the base branch policy prohibits the merge.
To have the pull request merged after all the requirements have been met, add the `--auto` flag.
To use administrator privileges to immediately merge the pull request, add the `--admin` flag.
```

For PR-0, a read by the session about one minute after the attempt returned `mergeStateStatus` `BLOCKED` on SHA-2
(`29.6-07-refusal.txt`), so the client-side decline there followed a BLOCKED state.

### The race (plans 09 and 10)

Two variants (D-08), three attempts each, every attempt on a fresh red PR (D-09, D-18):

- **(a) The Pitfall 8 window.** Close; wait until the close run completed and its five `skipped` check runs existed on
  the head SHA (the `detect` block in each `meta.json`); reopen; read merge state; merge.
- **(b) The UAT literal.** Close, reopen and merge back to back with no wait.

In all six attempts: `gate_mode` `blocking`, `current_user_can_bypass` `never`, `bypass_actors` `[]`, ruleset 24593937
with rule types `deletion`, `non_fast_forward`, `required_status_checks`, `pull_request`; the settled pre-close state was
`BLOCKED` (red precondition); the post-merge PR state was `OPEN`/`BLOCKED`; and the close suite's five required checks
had final conclusion `skipped`, none cancelled (`29.6-race-verdict.json`, each `29.6-race-<label>/meta.json`,
`29.6-10-d11-gate.txt`). The merge command was `gh pr merge` only; no direct REST merge was run (D-19).

| Attempt | PR | Head SHA | Verdict | Merge rc | Refusal source | Pre-merge read (`mergeStateStatus`/`mergeable`) | Reopen suite at post-merge snap | Where |
|---|---|---|---|---|---|---|---|---|
| a1 | #2 | `8d3641e3d45615f20b12c208273f74b88bc1f472` | blocked | 1 | client-side | `UNKNOWN`/`UNKNOWN` | 102139492102: 5 of 5 queued, incomplete | `29.6-race-verdict.json`, `29.6-race-a1/` |
| a2 | #3 | `9d0dbc0fa2d516fd6d6aa14c092b7564cd5d3b9d` | blocked | 1 | server-side | `UNKNOWN`/`UNKNOWN` | 102139962032: 5 of 5 queued, incomplete | `29.6-race-verdict.json`, `29.6-race-a2/` |
| a3 | #4 | `3803e8ad51243ed81ab6067f5061b26aab75fe65` | blocked | 1 | server-side | `UNKNOWN`/`MERGEABLE` | 102140501752: 3 in progress, 2 queued, incomplete | `29.6-race-verdict.json`, `29.6-race-a3/` |
| b1 | #5 | `5ed2e01bafae3cc81db7db216834afe2dbc861a7` | blocked | 1 | client-side | `UNKNOWN`/`UNKNOWN` | 102319657637: 5 of 5 queued, incomplete | `29.6-race-verdict.json`, `29.6-race-b1/` |
| b2 | #6 | `2a9b5d0e8cf3b694e070785c758e37b29d0377e2` | blocked | 1 | client-side | `UNKNOWN`/`UNKNOWN` | 102322508585: 5 of 5 queued, incomplete | `29.6-race-verdict.json`, `29.6-race-b2/` |
| b3 | #7 | `a55b75cc05be1dfbd9acdaf28c0bc447d1c08dab` | blocked | 1 | client-side | `UNKNOWN`/`UNKNOWN` | 102325415860: 5 of 5 queued, incomplete | `29.6-race-verdict.json`, `29.6-race-b3/` |

Counts (`29.6-race-verdict.json`): variant (a) run 3, blocked 3, lost 0, invalid 0, anomaly 0; variant (b) run 3,
blocked 3, lost 0, invalid 0, anomaly 0; `overall: blocked`. Refusal sources: client-side 4 (a1, b1, b2, b3),
server-side 2 (a2, a3). By variant: (a) 1 client-side, 2 server-side; (b) 3 client-side, 0 server-side.

Client-side refusal stderr, verbatim (`29.6-race-a1/merge-stderr.txt`; b1, b2 and b3 differ only in the PR number):

```text
X Pull request OttawaCloudConsulting/sp-reopen-race-scratch#2 is not mergeable: the base branch policy prohibits the merge.
To have the pull request merged after all the requirements have been met, add the `--auto` flag.
To use administrator privileges to immediately merge the pull request, add the `--admin` flag.
```

Server-side refusal stderr, verbatim (`29.6-race-a2/merge-stderr.txt`; a3 is identical):

```text
GraphQL: Repository rule violations found

5 of 5 required status checks are queued.

 (mergePullRequest)
```

Timing, from each attempt's `meta.json`: in variant (a) the merge started 0.2 s after the pre-merge read ended and
about 3 to 4 s after the reopen started (for example a2: reopen 23:20:29.732Z, merge 23:20:32.538Z to 23:20:34.512Z);
in variant (b) the merge started about 4 s after the close (for example b1: close 11:09:15.846Z, reopen
11:09:17.196Z, merge 11:09:20.030Z to 11:09:20.814Z).

D-11 gate: reply verbatim `accept-blocked (Recommended)`, canonical line `ruling: accept-blocked`, given after the
caveat below was presented (`29.6-10-d11-gate.txt`).

### What the refusal proves, stated precisely

- **Server-side, 2 of 6 (a2, a3, variant (a) only).** GitHub rejected `gh`'s GraphQL `mergePullRequest` mutation with
  "Repository rule violations found" and "5 of 5 required status checks are queued." The checks it named as queued are
  the reopen run's: the close run's five check runs were `completed`/`skipped` (each attempt's `detect` block), and the
  only queued required checks on the head SHA belonged to the reopen suite. So in these two attempts the server judged
  the reopen run's queued checks, not the close run's skipped ones. This is the measured datum on Pitfall 8's
  tie-break question, inferred from these two outcomes only.
- **Client-side, 4 of 6 (a1, b1, b2, b3).** `gh` declined locally with "the base branch policy prohibits the merge",
  the ADR-019 client-side text, and the server merge path was not reached. The script's own read, which ended about 0.2 s before
  the merge started, returned `UNKNOWN`; `gh`'s internal read inside `gh pr merge` is not captured. BLOCKED is inferred from the
  message `gh` prints for a BLOCKED read, not observed in these attempts.
- **The variant (b) caveat.** Variant (b), the UAT literal "close, reopen, merge quickly", was refused client-side in
  3 of 3 attempts, so the server merge path was not reached under (b). The server-side refusals (a2, a3) cite "5 of 5
  required status checks are queued." and show the server path only under variant (a) timing (reopen, then a
  pre-merge read, then merge). No merge was accepted in any of the six attempts.

## Consequences

**Improved:** 27-HUMAN-UAT item 3 is closed on evidence, and ADR-024 "What was NOT verified" item 2 is resolved by
reference, within the caveats above. The adoption-guide statement that a closed pull request blocks nothing is
consistent with the measurement: after a reopen, the reopen run's checks gated the merge in every attempt where the
server judged it.

**Tradeoff — a finite number of attempts cannot prove impossibility.** Six attempts at two timings found no accepted
merge. They do not prove that no timing exists in which the close run's `skipped` check runs are the newest per
context when the server evaluates a merge. Under variant (b) the refusal came from `gh`, not the server, so for the UAT
literal timing the evidence shows that the client a developer uses refused, not that the server would have.

**Tradeoff — the measurement used one client.** Every merge went through `gh pr merge`. A client that skips `gh`'s
local mergeability check (the REST endpoint, the web UI, another tool) reaches the server directly; for that path the
only evidence is the two server-side refusals in variant (a).

**Unchanged:** `security.yml` and `pr-security.yml` in `security-platform`; `v1` (`6c0d5319`, start equals end);
`docs/adoption-guide.md`; and `security-platform`'s own `main`, which remains un-required per ADR-017. No caller file
changes, and no Mode B consumer needs to act.

## What was NOT verified

What WAS measured and must not be re-litigated: the private-repo enforcement proof (UNSTABLE, then BLOCKED on the same
SHA-2, then CLEAN on SHA-3, with `bypass_actors: []` and `current_user_can_bypass: never`); the PR-0 client-side
refusal; six race attempts on red heads, all refused with merge rc 1 and every PR still `OPEN`; the refusal stderr
quoted above and its client-side or server-side classification per attempt; the close suites' final `skipped`
conclusions; and `v1` unchanged from start to end.

1. **Green-SHA attempts were not run (D-18).** On a head whose last real scan was `success`, `skipped` over `success`
   merges under normal GitHub behaviour, so such an attempt cannot discriminate. Nothing here bears on green heads.
2. **The REST merge endpoint was not exercised (D-19).** No `gh api -X PUT repos/…/pulls/N/merge` was run. ADR-019
   "What was NOT verified" item 2 is **NARROWED, not closed**: a server-side refusal was observed in a2 and a3, but on
   the GraphQL `mergePullRequest` path that `gh` uses, not on the REST endpoint that item names. ADR-019 is not
   edited.
3. **The server path under variant (b).** All three variant (b) refusals were client-side; the server never judged a
   merge at the UAT literal timing.
4. **Whether variant (b) hit the Pitfall 8 window at all.** Variant (b) does not wait for the close run, and its
   `meta.json` files have no `detect` block. In b1 to b3 the close suite's `skipped` check runs carry `completed_at`
   in the same second as the merge start (for example b1: `completed_at` 2026-10-08T11:09:20Z,
   `t_merge_start` 11:09:20.030Z, `29.6-race-b1/checkruns-final.json` and `meta.json`). At second resolution it cannot
   be determined whether those skipped runs existed on the head SHA when `gh pr merge` fired.
5. **The sub-second window between the reopen and the reopen suite's check runs.** In a2 and a3 the server reported
   the reopen suite's five checks as queued about 3 s after the reopen started, so they already existed. No attempt
   demonstrably landed a merge request in the interval before the reopen suite's check runs were created.
6. **GitHub's tie-break rule among same-named check runs.** Research found the sources in conflict (27-RESEARCH and
   29.6-RESEARCH Pitfall 8: newest run only, or all runs). This record adopts neither; the server-side outcomes above
   are consistent with the newest run per context being judged, and that is an inference from two attempts only.
7. **The plan tier.** Inferred to be Pro, not verified. Enforcement was proven live on the private repo used, which is
   what the race depends on.
8. **The delete method.** The operator deleted the repository outside the session; the token scopes were unchanged
   afterwards, which suggests the web UI, but the method was not observed (`29.6-11-repo-delete.txt`).
9. **Fork pull requests.** Every attempt used a same-repository branch. Fork PRs were not exercised.
10. **Deferred items, untouched here.** The 27-REVIEW WR-03 orphan-engagement race and a live Mode B DefectDojo import
    from a separate consumer repository remain deferred (29.6-CONTEXT, Deferred Ideas). DefectDojo was off in the
    scratch repo (D-03).
11. **ADR-024 is closed by reference only.** ADR-024 itself is unchanged; its item 2 is resolved by this record.
