# ADR-033: A Closed-Then-Reopened Red Pull Request Was Refused in Six Race Attempts

**Status:** Accepted
**Date:** 2026-10-08
**Addresses:** 27-HUMAN-UAT item 3 (the closed-PR reopen race), T-27-11, 27-RESEARCH Pitfall 8, ADR-024
"What was NOT verified" item 2 (the closed-PR reopen window), and v3.0-MILESTONE-AUDIT item 6

**Amended before acceptance (Phase 29.6 code review), 2026-10-08.** The Phase 29.6 code review of this record
(`29.6-REVIEW.md`) found one critical issue (CR-01), four warnings (WR-01 to WR-04) and four info items (IN-01 to
IN-04). This record was amended before the phase closed, and the original text is in the git history. The changes:
the title is narrowed to what was measured (WR-04; the file name is kept so existing links stay valid); the variant
(b) check-run ordering is added as a measured datum (CR-01, "Check-run ordering under variant (b)" below), and
Decision 2, the Consequences and "What was NOT verified" items 5 and 6 are scoped to it, with a new item 12 and a
follow-up; a related `CLOSED`/`CLEAN` observation from a1 to a3 is recorded with it; item 4 now uses the post-merge
snapshots (WR-01); the description of variant (b) and the timing paragraph are corrected (WR-02, WR-03);
and the provenance paragraph and item 6 are corrected (IN-01 to IN-03). CR-01 was put back to the operator, who ruled
`amend-keep-pass` (`29.6-review-ruling.txt`): item 3 stays closed on the measured result, no merge in 6 of 6.

This record lives in this documentation repository. Every measured value below is quoted from a file in the Phase 29.6
`evidence/` directory (`.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-/evidence/`),
and each is attributed where it appears. The exercise ran in a throwaway repository,
`OttawaCloudConsulting/sp-reopen-race-scratch`. The first line of `29.6-11-repo-delete.txt` reads
`29.6-11-repo-delete: deleted`: the throwaway repo OttawaCloudConsulting/sp-reopen-race-scratch
was deleted after capture (outside the D-06 checkpoint; see below), so run links are dead and the files stand alone.
The closeout captures ran from 2026-10-08T19:47:35Z to 19:47:48Z. The orchestrator reported a 404 readback at
19:48:11Z; that one was reported to the executor, not observed by it. The executor observed the 404 itself at
2026-10-08T19:50:29.162Z (`29.6-11-repo-delete.txt`). `29.6-11-manifest.json` reads `complete: true`,
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
  27-RESEARCH Pitfall 8 treats this as a short window that closes once the reopen run's check runs exist, because the
  reopen run "supersedes" the close run. The variant (b) evidence does not fit that model. In b1 and b3 a close-run
  `skipped` check run was created after the reopen run's check run for a red required context. It then stayed the
  newest by id for that context after the reopen run had completed, until the last snapshot about 8 minutes later
  ("Check-run ordering under variant (b)" below).
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
   below was presented (`29.6-10-d11-gate.txt`, canonical line `ruling: accept-blocked`). After the code review the
   operator ruled `amend-keep-pass` with the variant (b) ordering in view (`29.6-review-ruling.txt`).
2. **No change to `security.yml`, `pr-security.yml` or the adoption guide in this record.** The Pitfall 8 "zero-risk
   alternative" (a separate caller file for `closed` with a different job id) is not adopted here. That is a scoped
   statement, not a finding that the alternative is unneeded. The variant (a) server-side evidence (a2, a3) shows the
   reopen run's queued checks gating the merge. The variant (b) ordering, in which a close-run `skipped` check run ended
   up newest on a red required context and stayed newest, is recorded as an open risk and is not ruled on. A head
   red on exactly one required context was not tested ("What was NOT verified" item 12). No release follows from this
   record.
3. **ADR-024 "What was NOT verified" item 2 is resolved by this record, with the caveats stated below**, including
   the variant (b) ordering and the untested single-red-context head. ADR-024 is not edited; `docs/adr/` is append-only
   per `CLAUDE.md`, so the resolution is by reference.

What is resolved, stated precisely: a close, reopen and merge on a red head did not merge in six attempts, three
at each of two close-to-reopen gaps. In the two attempts where the server judged the merge, it judged the reopen run's
queued required checks, not the close run's skipped ones. Only the three variant (a) attempts are known to have run
inside the Pitfall 8 window. In b1 and b3 the window was shown not to be open for one red context, and b2 is
undetermined ("What was NOT verified" item 4). What is not resolved:

- variant (b), the UAT literal timing, was refused by `gh` on the client side in all three attempts, so under (b)
  the server merge path was not reached;
- every head was red on two required contexts. A head red on exactly one, under the ordering seen in b1 and b3
  (where that context's close-run `skipped` run ends up newest), was not exercised;
- six finite attempts do not prove the merge is impossible.

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
- **(b) The UAT literal.** Close, then reopen without waiting for the close run; read merge state; merge. After the
  reopen, the sequence (reopen, pre-merge read, merge) is the same as in (a). The only difference is the
  close-to-reopen gap (see the timing paragraph below).

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

Timing, from each attempt's `meta.json`. Both variants ran reopen, then a pre-merge read, then merge.

- In all six attempts the merge started 0.18 to 0.21 s after the pre-merge read ended.
- `t_merge_start` minus `t_reopen_start` was 2.68 to 2.98 s:
  - variant (a): a1 2.98 s, a2 2.81 s, a3 2.82 s;
  - variant (b): b1 2.83 s, b2 2.90 s, b3 2.68 s.
- The variants differ only in the gap from `t_close` to `t_reopen_start`:
  - variant (a): a1 18.52 s, a2 15.96 s, a3 16.28 s, because (a) waited for the close run's five `skipped`
    check runs;
  - variant (b): b1 1.35 s, b2 1.55 s, b3 1.65 s.
- Examples: a2 reopen 23:20:29.732Z, merge 23:20:32.538Z to 23:20:34.512Z; b1 close 11:09:15.846Z, reopen
  11:09:17.196Z, merge 11:09:20.030Z to 11:09:20.814Z.

D-11 gate: reply verbatim `accept-blocked (Recommended)`, canonical line `ruling: accept-blocked`, given after the
caveat below was presented (`29.6-10-d11-gate.txt`). That ruling was given without the variant (b) ordering datum
below. After the code review, the orchestrator put the datum to the operator. The reply, verbatim, was
`Amend records, keep pass (Recommended)`, with the canonical line `ruling: amend-keep-pass`
(`29.6-review-ruling.txt`; the orchestrator labelled that option Recommended).

### Check-run ordering under variant (b)

This datum was added by the code review (CR-01). The phase did not detect it: neither `29.6-verdict.sh` nor any
executor flagged it, although the `newest` field that `29.6-snap.sh` computes (`max_by(.id)`) shows it in each
`final` snapshot. Sources are each attempt's `checkruns-final.json` and `timeline.jsonl`, read newest by check-run id
per context. 29.6-RESEARCH ("Timestamps are unreliable for ordering check runs") explains why id is used rather than
timestamps. Note that close-suite `skipped`
runs carry a `completed_at` earlier than their `started_at`.

| Attempt | Red context | Reopen-suite run | Close-suite run | Newest by id | Newest from | Still newest at `final` |
|---|---|---|---|---|---|---|
| b1 (#5) | IaC — Checkov | 113280907712 `failure` (suite 102319657637) | 113280955772 `skipped` (suite 102319651891) | close `skipped` | settle-3, 11:09:31.674Z | yes, 11:18:36.371Z |
| b1 (#5) | SAST — Semgrep CE | 113280907382 `failure` | 113280901576 `skipped` | reopen `failure` | — | — |
| b2 (#6) | IaC — Checkov | 113284308908 `failure` | 113284302404 `skipped` | reopen `failure` | — | — |
| b2 (#6) | SAST — Semgrep CE | 113284308783 `failure` | 113284302234 `skipped` | reopen `failure` | — | — |
| b3 (#7) | SAST — Semgrep CE | 113287831272 `failure` (suite 102325415860) | 113287866366 `skipped` (suite 102325408925) | close `skipped` | settle-2, 11:28:28.489Z | yes, 11:37:33.990Z |
| b3 (#7) | IaC — Checkov | 113287831155 `failure` | 113287825303 `skipped` | reopen `failure` | — | — |

- In b1 and b3 the inverted run stayed newest after the reopen run's run for that context had completed `failure`.
  The b1 Checkov reopen run completed at 11:10:36Z and the b3 Semgrep reopen run at 11:29:37Z, so each inversion
  persisted for about 8 minutes, up to the `final` snapshot. The inversion was also present on green contexts: b1
  Gitleaks; b2 SCA and Gitleaks; b3 Container and Gitleaks.
- In a1 to a3 there was no inversion. The close suite had completed before the reopen, and the newest run for every
  required context at `final` belonged to the reopen suite.
- Every b pull request stayed `OPEN`/`BLOCKED` in all 123 snapshots of its `timeline.jsonl`. Each stayed BLOCKED
  because at least one red required context still had the reopen run's `failure` as its newest run. b1 and b3 were
  each red on two contexts, and only one context was inverted.
- This datum does not discriminate the candidate tie-break rules (item 6). On these heads, newest by id, most
  recently updated and all runs must pass all give BLOCKED.
- What it leaves open is a head red on only one required context, under this ordering. Once the reopen run has
  completed, that head's newest-by-id run is `skipped` on every red context. A merge request in that state might not
  be blocked by checks. This was not tested (item 12).

A related observation, also not in the phase's records. In a1, a2 and a3 the `pre-reopen` snapshot shows the
following, while the older red `failure` runs were still on the head (`29.6-race-a<n>/timeline.jsonl`, label
`pre-reopen`):

- the pull request was closed, and the newest run for all five required contexts was the close run's `skipped` run;
- the read returned `state` `CLOSED`, `mergeStateStatus` `CLEAN`, `mergeable` `MERGEABLE`.

The same head read BLOCKED before the close and again after the reopen. Two readings fit, and this evidence cannot
separate them:

- a newer `skipped` run overrides an older `failure` in GitHub's merge-state computation;
- a closed pull request is not evaluated against the ruleset's required checks at all.

It does not settle item 6.

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
  required status checks are queued." and show the server path only under variant (a) timing, meaning the attempts
  that waited for the close run before reopening. No merge was accepted in any of the six attempts. Both variants ran
  reopen, then a pre-merge read, then merge, with the same 2.7 to 3.0 s from reopen to merge. The D-11 gate
  transcript glossed variant (a) timing as "reopen, then a pre-merge read, then merge". That gloss was imprecise,
  because variant (b) had the same read (code review WR-02). The records that cite "variant (a) timing" use the label
  only.

## Consequences

**Improved:** 27-HUMAN-UAT item 3 is closed on evidence, and ADR-024 "What was NOT verified" item 2 is resolved by
reference, within the caveats above. The adoption-guide statement that a closed pull request blocks nothing is
consistent with the measurement where the server judged the merge (a2, a3): after the reopen, the reopen run's queued
checks gated it. The measurement does not show this for every head. In b1 and b3 a close-run `skipped` check run
ended up newest by id on one red required context and stayed newest after the reopen run completed. Those pull
requests stayed BLOCKED only because each head was also red on a second context, where the reopen run's `failure`
was newest ("Check-run ordering under variant (b)").

**Open risk — a head red on exactly one required context.** The variant (b) ordering leaves this case untested
("What was NOT verified" item 12). The operator ruled `amend-keep-pass` with this datum in view
(`29.6-review-ruling.txt`). The risk is recorded, not ruled on. This record proposes no workflow change.

**Follow-up — recommended, not scheduled.** A future race should use a head that is red on exactly one required
context. It should log newest-by-id per context, check-run ids and `check_suite` ids from the close through to after
the reopen run completes. It should attempt the merge both inside the window and after the reopen run completes,
including once that context's close-run `skipped` run is newest. Any change to `security.yml` or the caller after
that race is an operator ruling under D-11, not part of this record.

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
4. **Whether variant (b) hit the Pitfall 8 window.** Variant (b) does not wait for the close run, and its
   `meta.json` files have no `detect` block. In b1 to b3 the close suite's `skipped` check runs carry `completed_at`
   in the same second as the merge start (for example b1: `completed_at` 2026-10-08T11:09:20Z,
   `t_merge_start` 11:09:20.030Z, `29.6-race-b1/checkruns-final.json` and `meta.json`), so `completed_at` alone cannot
   order them. Each attempt's `post-merge` snapshot in `timeline.jsonl` does settle part of it. It was taken 0.20 to
   0.23 s after `t_merge_end` and lists every check run on the head SHA. A run absent there was also absent when the
   merge ran.
   - b1 (11:09:21.044Z): the close-suite `skipped` run for IaC — Checkov (red) was absent.
   - b3 (11:28:22.075Z): the close-suite `skipped` run for SAST — Semgrep CE (red) was absent.

   So in b1 and b3 the window was not open for those red contexts when `gh pr merge` fired. In b2 (11:18:51.639Z) the
   close-suite runs for both red contexts were present, and whether they existed when the merge fired is
   undetermined. At all three post-merge snapshots the newest-by-id run for each of the five required contexts was the
   reopen suite's queued run. Only the three variant (a) attempts are known to have run inside the window.
5. **The interval between the reopen and the reopen suite's check runs, and what follows it.** In a2 and a3 the
   server reported the reopen suite's five checks as queued about 2.8 s after the reopen started, so they already
   existed. No attempt demonstrably landed a merge request before the reopen suite's check runs were created. The
   risk is not confined to that interval. In b1 and b3 a close-run `skipped` check run was created after the reopen
   suite's run for a red required context. It stayed newest by id until the `final` snapshot, about 8 minutes after
   the reopen run's run for that context had completed ("Check-run ordering under variant (b)").
6. **GitHub's tie-break rule among same-named check runs.** 29.6-RESEARCH Pitfall 8 and its assumption A4 found the
   sources in conflict: only the most recently updated run counts, or all runs must pass. 27-RESEARCH Pitfall 8 did
   not describe a conflict. It assumed the reopen run supersedes the close run. This record adopts no rule.
   - The server-side outcomes (a2, a3) are consistent with the newest run per context being judged. That is an
     inference from two attempts only.
   - The variant (b) ordering does not discriminate. On b1 and b3 every candidate rule gives BLOCKED, because the
     other red context's newest run was a reopen `failure`.
   - For the inverted context itself (b1 Checkov, b3 Semgrep), newest by id selects the close run's `skipped` run.
     The later `completed_at`, the nearest captured field to "most recently updated", belongs to the reopen
     `failure`.
   - The `CLOSED`/`CLEAN` reads in a1 to a3 do not settle the rule either; see the observation after the table
     above.
7. **The plan tier.** Inferred to be Pro, not verified. Enforcement was proven live on the private repo used, which is
   what the race depends on.
8. **The delete method.** The operator deleted the repository outside the session; the token scopes were unchanged
   afterwards, which suggests the web UI, but the method was not observed (`29.6-11-repo-delete.txt`).
9. **Fork pull requests.** Every attempt used a same-repository branch. Fork PRs were not exercised.
10. **Deferred items, untouched here.** The 27-REVIEW WR-03 orphan-engagement race and a live Mode B DefectDojo import
    from a separate consumer repository remain deferred (29.6-CONTEXT, Deferred Ideas). DefectDojo was off in the
    scratch repo (D-03).
11. **ADR-024 is closed by reference only.** ADR-024 itself is unchanged; its item 2 is resolved by this record.
12. **A head red on exactly one required context was not tested.** A close-run `skipped` run can persist as the
    newest on a red required context. Every attempt's head was red on two required contexts (D-18 red set: IaC —
    Checkov and SAST — Semgrep CE). The untested case is a head red on only one, under an ordering in which that
    context's close-run `skipped` run ends up newest by id, as in b1 and b3. Once the reopen run has completed, every
    red context on such a head has a `skipped` run as its newest. A merge request in that state might not be blocked
    by checks; whether it is depends on the unresolved tie-break rule (item 6). The phase did not detect this ordering;
    the code review did (CR-01). The operator ruled `amend-keep-pass` (`29.6-review-ruling.txt`), and the follow-up is
    under Consequences.
