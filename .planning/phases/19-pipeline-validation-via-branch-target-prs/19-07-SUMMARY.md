---
phase: 19-pipeline-validation-via-branch-target-prs
plan: 07
subsystem: ci-cd
tags: [phase-close, val-01, d-10, deviation, out-of-band-merge, checkpoint, halted]

# Dependency graph
requires:
  - phase: 19-03
    provides: "SC1 captured on PR #10, run 34786019516; the preflight baseline (gh variable list EMPTY) and the main ruleset baseline"
  - phase: 19-04
    provides: "SC3 closed MET on both halves — alert 98's three-hop trace plus the operator's `approved` on the rendered alert"
  - phase: 19-05
    provides: "SC2 measured on PR #11 (the replacement validation PR); D-09 executed — GATE_MODE deleted"
  - phase: 19-06
    provides: "SC4 measured on PR #12 (the clean PR), since closed by that plan"
provides:
  - "the PR #10 out-of-band-merge deviation record, read live in this plan: MERGED 2026-09-13T22:34:18Z, merge commit 80e91de, head branch deleted"
  - "D-04 VERIFIED from origin/main in this plan and attributed to PR #10's merge, not inherited from plan prose"
  - "PR #11's pre-decision state read live: OPEN, MERGEABLE, CLEAN, mergedAt null, head 426c84c"
  - "the D-10 merge-or-close question put to the operator with both options and their consequences — PENDING"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Every claim about the shared repository is read live in this plan (gh + git show origin/main), never copied from the plan's own prose"

key-files:
  created:
    - .planning/phases/19-pipeline-validation-via-branch-target-prs/19-07-SUMMARY.md
  modified: []

key-decisions:
  - "HALTED at Task 1's blocking checkpoint:decision. Not auto-approved. config.json has no workflow.auto_advance and workflow._auto_chain_active is false; the plan is autonomous:false; the task carries gate=\"blocking\"; and the orchestrator's dispatch states explicitly that this is the one deliberately-human decision in the phase. Auto-selecting `merge` would have merged a pull request into the main branch of a shared live public repository on the executor's own authority."
  - "No `gh pr merge` and no `gh pr close` ran in this session. Verified: the only mutating gh subcommands invoked were none — every gh call was `view`, `list` or a read-only `api` GET."
  - "PR #10 was read, never acted on. It is a record, not a decision."
  - "VAL-01 NOT yet marked complete — following 19-01 through 19-06 and the 17-01 precedent. Task 2 owns the mark-complete, and only after the four-SUMMARY precondition check."
  - "No state.advance-plan / state.update-progress / roadmap.update-plan-progress tick at this halt, matching 19-05's two halts: the plan is not complete and the counters must not say it is."

requirements-completed: []

# Metrics
duration: 12min (Task 1 up to the halt)
completed: null
---

# Phase 19 Plan 07: Close the Phase and Decide the Replacement PR's Fate Summary

**STATUS: HALTED at Task 1's `checkpoint:decision` (gate="blocking") — awaiting the operator's D-10
selection for PR #11.** Everything Task 1 asks to be established BEFORE the question was established, read
live in this session: PR #10's out-of-band merge, D-04's satisfaction on `origin/main` by that merge, PR
#11's pre-decision state, and the four captured success criteria. The question itself is below under
[The D-10 decision — PENDING](#the-d-10-decision--pending). **No pull request was merged or closed in this
session.**

## 1. The deviation — PR #10 merged out of band, read live in THIS session

```
$ gh pr view 10 -R OttawaCloudConsulting/security-platform \
    --json number,state,mergedAt,mergeCommit,headRefName
{"headRefName":"feature/phase-19-pipeline-validation",
 "mergeCommit":{"oid":"80e91de51812e8ca189dab3107629ad8d501b83d"},
 "mergedAt":"2026-09-13T22:34:18Z","number":10,"state":"MERGED"}
```

| Field | Value, verbatim |
|---|---|
| `number` | **10** |
| `state` | **`MERGED`** |
| `mergedAt` | **`2026-09-13T22:34:18Z`** |
| `mergeCommit.oid` | **`80e91de51812e8ca189dab3107629ad8d501b83d`** |
| `headRefName` | `feature/phase-19-pipeline-validation` (auto-deleted — 19-05 recorded the prune) |

**Stated plainly, not smoothed into the plan's narrative.** PR #10 was the original long-lived D-05
validation PR, and plan 07 — this plan — was to be the only point in the phase where its fate was decided.
It was merged through the GitHub web UI by the operator on **2026-09-13T22:34:18Z**: *after* 19-04 closed SC1
and SC3, and *before* SC2 or SC4 were measured. Its head branch was auto-deleted, so neither the PR nor its
branch exists to re-run. That is why plans 05 and 06 were replanned onto new pull requests, and why SC2's
literal ROADMAP wording ("that **same** pull request" as SC1's) stopped being satisfiable at that timestamp.

**This is a recorded event, not a decision to revisit.** No action is offered against PR #10 and the question
of whether it should have been merged is not re-argued here.

**It is the second such event, and the pattern is the hand-off.** PR #9 was merged out of band on
2026-09-12T12:48:34Z before 18-08 ran; PR #10 on 2026-09-13T22:34:18Z before SC2 and SC4 were measured. Twice
now a pull request has been resolved outside the plan that owned the decision, and the second time it
invalidated a planned measurement. Recorded as an observation about how this work and its operator interact,
handed to Phase 20 — **not** proposed as a process fix inside this phase.

## 2. D-04 — VERIFIED live from `origin/main`, and attributed to PR #10's merge

Run in this session after `git -C repos/security-platform fetch origin --prune`. Read from `origin/main`,
never from the local working tree (precedent: 15-05, 16-07, 18-08; 18-07 was caught out by exactly this).

| Read | Result |
|---|---|
| `git rev-parse origin/main` | **`80e91de51812e8ca189dab3107629ad8d501b83d`** — identical to PR #10's `mergeCommit.oid` |
| `git rev-parse origin/main^{tree}` | **`2d7f5ad91315abb0b070ffe634bbfb65b9506df0`** |
| `git show origin/main:fixtures/vulnerable.py \| head -1` | `# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX" OR RUN` |
| `git show origin/main:fixtures/secret.env \| head -1` | `# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"` |
| `git show origin/main:fixtures/README.md \| grep -c 'vulnerable\.py'` | **6** (≥1 required) |
| `git show origin/main:fixtures/README.md \| grep -c 'secret\.env'` | **7** (≥1 required) |
| `git show origin/main:scripts/smoke-scans.sh \| grep -c 'eval-detected'` | **2** |
| `git show origin/main:scripts/smoke-scans.sh \| grep -c 'aws-access-token'` | **4** |
| `git show origin/main:fixtures/README.md \| grep -c 'GH013\|Push Protection'` | **0** — the D-19-A correction is **not** on `main`; it is what PR #11 carries |

**D-04 is satisfied, and the vehicle was PR #10's merge commit `80e91de`** — not the replacement PR. Both
fixtures, the `fixtures/README.md` Fixture Reference rows and the two 19-02 rule-id assertions in
`scripts/smoke-scans.sh` are all on `origin/main`. **D-04 therefore does not constrain the merge-vs-close
choice below.** Closing PR #11 would strand nothing D-04 required.

## 3. PR #11 — the replacement validation PR, pre-decision state read live

Its number was taken from 19-05-SUMMARY (`PR #11 … OPEN at head 426c84c`) and then confirmed live:

```
$ gh pr view 11 -R OttawaCloudConsulting/security-platform \
    --json number,state,mergedAt,mergeCommit,mergeable,mergeStateStatus,headRefName,headRefOid,title
{"headRefName":"feature/phase-19-gate-mode-proof",
 "headRefOid":"426c84c3fcc3207af2a4dd90263b2f7dd0a17df5",
 "mergeCommit":null,"mergeStateStatus":"CLEAN","mergeable":"MERGEABLE",
 "mergedAt":null,"number":11,"state":"OPEN",
 "title":"Phase 19: gate-mode proof (replacement for PR #10) + D-19-A push-protection correction"}
```

| Field | Value |
|---|---|
| `state` | **`OPEN`** — it was **not** resolved out of band; the D-10 action is genuinely still available |
| `mergedAt` / `mergeCommit` | `null` / `null` |
| `mergeable` / `mergeStateStatus` | **`MERGEABLE`** / **`CLEAN`** |
| head | `426c84c3fcc3207af2a4dd90263b2f7dd0a17df5` |

The third PR, for completeness: **PR #12** (`feature/phase-19-clean-pr`, the SC4 clean probe) reads
`state: CLOSED`, `closedAt: 2026-09-14T00:33:02Z` — closed by 19-06 itself, as that plan intended. It is not
part of this decision.

`gh pr list --state open` returns **exactly one** open pull request on the repository: **PR #11**. It is the
only Phase 19 PR left open, and the only thing standing between this phase and its close-state assertions.

## 4. The four captured criteria — what the decision is being made against

| SC | Plan | Pull request | Run id | Proof artefact | Stated in that SUMMARY as |
|----|------|--------------|--------|----------------|---------------------------|
| **SC1** — a detection from each of the five jobs | 19-03 | **#10** | `34786019516` | the five-row table: `eval-detected` @ `fixtures/vulnerable.py:20`; `aws-access-token` @ `fixtures/secret.env:21`; `CKV_TF_1`/`CKV_TF_2` (+10) @ `/fixtures/main.tf`; Trivy FS targets `package-lock.json` + `requirements.txt`; 58 vulns on the `Dockerfile` image. "All five exited **0**." | "all five retained artifacts were downloaded and read to yield **one named, path-scoped detection per job**" — captured |
| **SC2** — one PR failing under blocking, passing under report-only, byte-identical tree | 19-05 | **#11** | `34791497579` (blocking) vs `34790727189` / `34791562222` (report-only) | one tree hash `895c1bdf`, empty `git diff` between the outer two commits; five `security / …` checks all `failure` under `GATE_MODE=blocking`, all `success` either side of it | "**SC2 is measured.**" |
| **SC3** — one finding traced source → Security tab → retained artifact, human-confirmed | 19-04 | **#10** | `34786019516` | three-hop trace on line 20: source → code-scanning **alert 98** (`…/security/code-scanning/98`) → re-downloaded `semgrep-results.json`, all three agreeing on rule and line; operator replied `approved` on the rendered alert | "SC3's UI half is therefore **OBSERVED** … and **SC3 closes MET on both halves**" |
| **SC4** — a clean PR, five green | 19-06 | **#12** | `34792868246` | five `security / …` check runs all `success` on head `9483ba5`; non-`success` count queried explicitly = **0**; recorded beside the findings that were still there (8/11/14/6/58), never as "zero findings" | "**SC4 is measured.**" |

**Which PR carries which:** SC1 and SC3 on **PR #10**, SC2 on **PR #11**, SC4 on **PR #12**. Three different
pull requests.

**SC2's departure from its literal wording, stated rather than implied.** The ROADMAP criterion says the
blocking/report-only pair must be observed on "that **same** pull request" as SC1's. PR #10 was merged and
its branch deleted at `2026-09-13T22:34:18Z`, which made that unsatisfiable. SC2 was closed on its
**essential claim** instead: one pull request, two gate modes, opposite verdicts, byte-identical trees
(`895c1bdf`), with the same five seeded fixture categories present in the scanned checkout (six fixture paths
asserted present in 19-05, not assumed).

**Precondition note for Task 2 (the four-SUMMARY check).** Three of the four SUMMARYs state their criterion
with an explicit verdict token (`SC2 is measured`, `SC3 closes MET on both halves`, `SC4 is measured`).
19-03 does **not** use the token "MET" for SC1; it states the criterion in its own words instead — the
document is titled "Open the Validation PR and **Capture SC1**", its banner asserts one named, path-scoped
detection per job, its `## SC1 — the five-row detection table` section names a rule id **and** a fixture path
on every row, and it records that all five assertions "exited **0**" with non-zero exits reserved for absent
targets and unreadable reports. It further states that "SC2 … and SC3 … are still unmeasured", which is only
coherent if SC1 is not. The precondition is judged **satisfied on substance** for SC1, and the absence of a
literal "MET" token is recorded here rather than papered over.

## 5. Repository close-state, read live in this session

| Assertion | Command | Result |
|---|---|---|
| D-09 — no `GATE_MODE` variable | `gh variable list -R …` | **empty output**, rc=0 — no variables of any kind |
| `main` ruleset unchanged from 19-03's preflight | `gh api repos/…/rules/branches/main --jq '.[].type'` | **`deletion`**, **`non_fast_forward`** — exactly the two 19-03 recorded, nothing added |
| Open Phase 19 PRs | `gh pr list --state open` | **one: PR #11** — which is what the decision below resolves |

No ruleset write and no variable write occurred in this plan. No workflow file was edited.

## The D-10 decision — PENDING

**Question (D-10):** is **PR #11** — the replacement Phase 19 validation PR on
`feature/phase-19-gate-mode-proof`, opened by plan 05 after PR #10 was merged out of band — **MERGED** or
**CLOSED**, now that all four success criteria are captured?

**What PR #11 still carries:** the **D-19-A** correction to `fixtures/README.md` (+23 lines, insertions only,
one file) — the measured fact that a **server-side** GitHub Push Protection layer (`GH013`) blocked 19-03's
push and that `git push --no-verify` cannot skip it, which the copy on `main` currently omits (grep for
`GH013\|Push Protection` on `origin/main` → **0**). It also carries the two empty re-trigger commits that are
part of the SC2 evidence trail.

**What merging does NOT do:** `main` is never analysed by code scanning (ADR-016 D-02 keeps the trigger
`pull_request`-only), so merging creates no alerts on the default branch. The `fixtures/secret.env` history
consequence is already irreversible — it happened with PR #10's merge on 2026-09-13, not with this choice.

| Option | Pros | Cons |
|---|---|---|
| **`merge`** (RECOMMENDED) | Lands the D-19-A correction, so `fixtures/README.md` on `main` stops documenting `--no-verify` as the only obstacle and names the server-side control that actually blocked a push in this phase. Matches how Phases 15, 16, 17 and 18 each closed. Leaves no follow-up debt and no open Phase 19 pull request. | The two empty re-trigger commits from 19-05 land in `main`'s history alongside the documentation commit — harmless, and they are the SC2 evidence trail. |
| **`close`** | Keeps the two empty commits out of `main`'s history. The fixtures are already on `main` via PR #10's merge `80e91de`, so closing strands nothing D-04 required. | `fixtures/README.md` on `main` keeps its incomplete bypass paragraph, so **D-19-A stays open and needs a named owner in the same breath** or it is never corrected. Phase 20 inherits a fixtures README that understates the control stack this phase measured. |

**Resume signal:** `merge`, or `close` — and if `close`, name who owns landing the D-19-A correction.

### Operator Reply — PENDING

Not yet received. To be recorded here **verbatim**, together with any reasoning given, before Task 2 executes
anything. A deliberate `close` is a decision and will be recorded as one, not as an absence of one.

## Why this halted rather than auto-selecting

`.planning/config.json` carries `"mode": "yolo"` but **no** `workflow.auto_advance`, and
`workflow._auto_chain_active` is `false`. The task is `checkpoint:decision` with `gate="blocking"`, the plan
is `autonomous: false`, the plan's own `<notes>` open with "**Do not decide D-10 on your own initiative**",
and the dispatching orchestrator stated that this is the one deliberately-human decision in the phase.
Auto-selecting the recommended option would have merged a pull request into the default branch of a shared
live public repository on the executor's authority — precisely threat **T-19-30**. 19-05 halted twice on the
same reasoning and neither halt was auto-approved.

## Handoff to the continuation agent

1. **Record the operator's reply verbatim** in §"Operator Reply", then execute **only** what they chose,
   against **PR #11 only**. Never touch PR #10.
   - `merge` → `gh pr merge 11 -R OttawaCloudConsulting/security-platform --merge` (a merge commit, matching
     15/16/18).
   - `close` → `gh pr close 11 -R OttawaCloudConsulting/security-platform` **and** record the named D-19-A
     owner.
2. **Re-verify from `origin/main` after the action** — `git -C repos/security-platform fetch origin --prune`,
   then re-record `git rev-parse origin/main origin/main^{tree}`, re-run the D-04 reads in §2, and assert the
   D-19-A grep is **non-zero if merged** / **0 with a named owner if closed**.
3. **Precondition before `requirements.mark-complete`:** §4's table already carries the four-SUMMARY check;
   re-read the four files if anything above is stale. If any criterion is silent or NOT MET, STOP (17-01
   precedent).
4. **`gsd-sdk` state handlers take NAMED flags, not positional args** — D-19-D, measured in 19-04. Use
   `state.record-metric --phase --plan --duration --tasks --files`, `state.add-decision --summary
   [--rationale]`, `state.record-session --stopped-at --resume-file` followed by `state.sync` (which is what
   actually advances frontmatter `stopped_at`). `record-session` returns `recorded: true` while silently
   dropping `Stopped At` if called positionally — read its `updated` array.
5. **Still to write into this SUMMARY at close:** the executed action and its verification, the `VAL-01`
   mark-complete with the method used, the still-open deferred items with owners (D-19-B … D-19-E, plus
   D-19-A if `close`), and the two Phase 20 hand-offs (Q1 fork-PR gate bypass
   [CITED: github.com/orgs/community/discussions/44322], deliberately not tested since D-07 scopes every PR
   to the same repository, plus the stale `pr-security.yml` comment that is a workflow edit and therefore out
   of scope here; and Pitfall 5 — `fixtures/` is permanent, so report-only is currently the only state in
   which this repo's own PRs merge green, which is why Phase 18 D-07 step 3 stays deferred).
6. **Do not** tick `state.advance-plan`, `state.update-progress` or `roadmap.update-plan-progress` until the
   plan actually completes. None of them ran at this halt.

## Self-Check: PASSED

| Claim | Check | Result |
|---|---|---|
| This SUMMARY exists | `[ -f .planning/phases/19-…/19-07-SUMMARY.md ]` | written by this session |
| PR #10 read live, never acted on | only `gh pr view 10` ran; no `gh pr merge`/`gh pr close` anywhere in the session | PASS |
| D-04 verified from `origin/main` | both headers printed; README 6/7; smoke-scans 2/4 | PASS |
| PR #11 state read before options were presented | `gh pr view 11` output quoted above | PASS |
| Repository close-state read live | variable list empty; ruleset `deletion`,`non_fast_forward`; one open PR | PASS |
| `VAL-01` not marked complete | `requirements.mark-complete` not invoked | PASS |
