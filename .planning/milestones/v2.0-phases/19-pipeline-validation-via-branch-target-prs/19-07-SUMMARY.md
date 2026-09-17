---
phase: 19-pipeline-validation-via-branch-target-prs
plan: 07
subsystem: ci-cd
tags: [phase-close, val-01, d-10, deviation, out-of-band-merge, merge, complete]

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
  - "D-10 EXECUTED: PR #11 MERGED 2026-09-14T01:19:32Z as merge commit b4cb207 on the operator's verbatim reply `merge it`"
  - "D-19-A CLOSED — the GH013/Push Protection correction is on origin/main (grep count 0 → 4)"
  - "the phase-close assertion set: no repository variables, main ruleset unchanged (deletion, non_fast_forward), zero open pull requests"
  - "the SC1–SC4 evidence index spanning three pull requests (#10, #11, #12) with the SC2 wording departure stated"
  - "VAL-01 complete in both places .planning/REQUIREMENTS.md tracks it"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Every claim about the shared repository is read live in this plan (gh + git show origin/main), never copied from the plan's own prose"
    - "An irreversible action against a shared live repository is taken only after a blocking checkpoint, and the operator's words are recorded verbatim"

key-files:
  created:
    - .planning/phases/19-pipeline-validation-via-branch-target-prs/19-07-SUMMARY.md
  modified:
    - .planning/REQUIREMENTS.md
    - .planning/phases/19-pipeline-validation-via-branch-target-prs/deferred-items.md

key-decisions:
  - "D-10 resolved by the OPERATOR, not by the executor: PR #11 MERGED. Their reply, verbatim and complete: `merge it`. No reasoning was volunteered and none is invented here."
  - "The merge was executed as a MERGE COMMIT (`gh pr merge 11 --merge`), matching how Phases 15, 16 and 18 each closed. Proven a merge commit, not a squash or rebase: origin/main^1 = 80e91de (PR #10's merge) and origin/main^2 = 426c84c (PR #11's head)."
  - "PR #10 was read, never acted on. It is a record, not a decision."
  - "VAL-01 marked complete ONLY after all four SUMMARYs were re-read and each confirmed to record its assigned criterion — the 17-01 precedent."
  - "PR #11's head branch was NOT auto-deleted by the merge, unlike PR #10's. Recorded as observed; no branch was deleted by this plan."
  - "STATE.md frontmatter `percent` reads 86 while the body bar reads 100%. Left alone — this is D-19-E, which state.validate calls valid; not hand-corrected here."

requirements-completed: [VAL-01]

# Metrics
duration: 20min (12min Task 1 + 8min Task 2 resume)
completed: 2026-09-14
---

# Phase 19 Plan 07: Close the Phase and Decide the Replacement PR's Fate Summary

**Phase 19 is closed. The operator answered D-10 with `merge it`; PR #11 was merged into `main` as merge
commit `b4cb207` at `2026-09-14T01:19:32Z`, landing the D-19-A push-protection correction. Verified from
`origin/main`, never from the local tree. The repository ends in its default state: no repository variables,
a `main` ruleset of exactly `deletion` and `non_fast_forward`, and zero open pull requests. `VAL-01` is
complete against a four-row SC1–SC4 evidence index spanning three different pull requests.**

## 1. The deviation — PR #10 merged out of band, read live in THIS plan

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

**This is a recorded event, not a decision to revisit.** No action was offered or taken against PR #10 and
the question of whether it should have been merged is not re-argued here.

**It is the second such event, and the pattern is the hand-off.** PR #9 was merged out of band on
**2026-09-12T12:48:34Z** before 18-08 ran; PR #10 on **2026-09-13T22:34:18Z** before SC2 and SC4 were
measured. Twice now a pull request has been resolved outside the plan that owned the decision, and the second
time it invalidated a planned measurement and forced two plans to be replanned. Recorded as an observation
about how this work and its operator interact, **handed to Phase 20** — not proposed as a process fix inside
this phase.

## 2. D-04 — VERIFIED live from `origin/main`, and attributed to PR #10's merge

Read at Task 1 (before the decision) from `origin/main` after `git fetch origin --prune`, never from the
local working tree (precedent: 15-05, 16-07, 18-08; 18-07 was caught out by exactly this).

| Read | Result at Task 1 (pre-merge) |
|---|---|
| `git rev-parse origin/main` | **`80e91de51812e8ca189dab3107629ad8d501b83d`** — identical to PR #10's `mergeCommit.oid` |
| `git rev-parse origin/main^{tree}` | **`2d7f5ad91315abb0b070ffe634bbfb65b9506df0`** |
| `git show origin/main:fixtures/vulnerable.py \| head -1` | `# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX" OR RUN` |
| `git show origin/main:fixtures/secret.env \| head -1` | `# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"` |
| `git show origin/main:fixtures/README.md \| grep -c 'vulnerable\.py'` | **6** |
| `git show origin/main:fixtures/README.md \| grep -c 'secret\.env'` | **7** |
| `git show origin/main:scripts/smoke-scans.sh \| grep -c 'eval-detected'` | **2** |
| `git show origin/main:scripts/smoke-scans.sh \| grep -c 'aws-access-token'` | **4** |
| `git show origin/main:fixtures/README.md \| grep -c 'GH013\|Push Protection'` | **0** — the D-19-A correction was **not** on `main`; it is what PR #11 carried |

**D-04 is satisfied, and the vehicle was PR #10's merge commit `80e91de`** — not the replacement PR. Both
fixtures, the `fixtures/README.md` Fixture Reference rows and the two 19-02 rule-id assertions in
`scripts/smoke-scans.sh` were already on `origin/main` before this plan acted. **D-04 therefore did not
constrain the merge-vs-close choice**; closing PR #11 would have stranded nothing D-04 required. The choice
turned on D-19-A alone, which is exactly how it was put to the operator.

## 3. PR #11 — the replacement validation PR, pre-decision state read live

Its number was taken from 19-05-SUMMARY (`PR #11 … OPEN at head 426c84c`) and then confirmed live, **before**
the options were presented and before any mutating command ran:

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
| `state` | **`OPEN`** — it was **not** resolved out of band; the D-10 action was genuinely still available |
| `mergedAt` / `mergeCommit` | `null` / `null` |
| `mergeable` / `mergeStateStatus` | **`MERGEABLE`** / **`CLEAN`** |
| head | `426c84c3fcc3207af2a4dd90263b2f7dd0a17df5` |

The third PR, for completeness: **PR #12** (`feature/phase-19-clean-pr`, the SC4 clean probe) read
`state: CLOSED`, `closedAt: 2026-09-14T00:33:02Z` — closed by 19-06 itself, as that plan intended. It was not
part of this decision and needed no action here.

## 4. The four captured criteria — what the decision was made against

| SC | Plan | Pull request | Run id | Proof artefact | Stated in that SUMMARY as |
|----|------|--------------|--------|----------------|---------------------------|
| **SC1** — a detection from each of the five jobs | 19-03 | **#10** | `34786019516` | the five-row table: `eval-detected` @ `fixtures/vulnerable.py:20`; `aws-access-token` @ `fixtures/secret.env:21`; `CKV_TF_1`/`CKV_TF_2` (+10) @ `/fixtures/main.tf`; Trivy FS targets `package-lock.json` + `requirements.txt`; 58 vulns on the `Dockerfile` image. "All five exited **0**." | "all five retained artifacts were downloaded and read to yield **one named, path-scoped detection per job**" — captured |
| **SC2** — one PR failing under blocking, passing under report-only, byte-identical tree | 19-05 | **#11** | `34791497579` (blocking) vs `34790727189` / `34791562222` (report-only) | one tree hash `895c1bdf`, empty `git diff` between the outer two commits; five `security / …` checks all `failure` under `GATE_MODE=blocking`, all `success` either side of it | "**SC2 is measured.**" |
| **SC3** — one finding traced source → Security tab → retained artifact, human-confirmed | 19-04 | **#10** | `34786019516` | three-hop trace on line 20: source → code-scanning **alert 98** (`…/security/code-scanning/98`) → re-downloaded `semgrep-results.json`, all three agreeing on rule and line; operator replied `approved` on the rendered alert | "SC3's UI half is therefore **OBSERVED** … and **SC3 closes MET on both halves**" |
| **SC4** — a clean PR, five green | 19-06 | **#12** | `34792868246` | five `security / …` check runs all `success` on head `9483ba5`; non-`success` count queried explicitly = **0**; recorded beside the findings that were still there (8/11/14/6/58), never as "zero findings" | "**SC4 is measured.**" |

**Which PR carries which:** SC1 and SC3 on **PR #10**, SC2 on **PR #11**, SC4 on **PR #12**. Three different
pull requests. This index is what a verifier reads instead of re-running anything.

**SC2's departure from its literal wording, stated rather than implied.** The ROADMAP criterion says the
blocking/report-only pair must be observed on "that **same** pull request" as SC1's. PR #10 was merged and
its branch deleted at `2026-09-13T22:34:18Z`, which made that unsatisfiable. SC2 was closed on its
**essential claim** instead: one pull request, two gate modes, opposite verdicts, byte-identical trees
(`895c1bdf`), with the same five seeded fixture categories present in the scanned checkout (six fixture paths
asserted present in 19-05, not assumed). The ROADMAP criterion itself carries the amendment note, so the
record and the criterion agree.

### The four-SUMMARY precondition check, run before `requirements.mark-complete`

Each SUMMARY was re-read in Task 2 and confirmed to record **its own** assigned criterion. A run id or a PR
number present in the file was not accepted as a substitute.

| SUMMARY | Assigned criterion | Verdict found in the file | Precondition |
|---|---|---|---|
| 19-03 | SC1 | Title "Capture SC1"; banner "all five retained artifacts were downloaded and read to yield one named, path-scoped detection per job"; `## SC1 — the five-row detection table` names a rule id **and** a fixture path on every row; "All five exited **0**" | **SATISFIED (on substance)** |
| 19-04 | SC3 | "SC3's UI half is therefore **OBSERVED** … and **SC3 closes MET on both halves**"; verdict table row `SC3 UI half → OBSERVED` | **SATISFIED** |
| 19-05 | SC2 | "**SC2 is measured.**" | **SATISFIED** |
| 19-06 | SC4 | "**SC4 is measured.**" | **SATISFIED** |

**The one honest caveat, recorded rather than papered over.** 19-03 does not use the literal token "MET" for
SC1; it states the criterion in its own words. It also states that "SC2 … and SC3 … are still unmeasured",
which is only coherent if SC1 is not. The precondition is judged **satisfied on substance** for SC1, and the
absence of the literal token is stated here so a verifier can disagree with the judgement rather than have to
discover it.

## 5. The D-10 decision — ASKED, ANSWERED, EXECUTED

**Question put to the operator (Task 1, blocking `checkpoint:decision`):** is **PR #11** — the replacement
Phase 19 validation PR on `feature/phase-19-gate-mode-proof`, opened by plan 05 after PR #10 was merged out
of band — **MERGED** or **CLOSED**, now that all four success criteria are captured? Both options were
presented with their consequences, `merge` was recommended, and the `close` option's cost was stated as
D-19-A remaining uncorrected on `main` — **not** as stranded fixtures, which PR #10's merge had already
settled.

### Operator reply — VERBATIM

```
merge it
```

That is the complete reply. It maps to option **`merge`** (the resume signal asked for `merge` or `close`).
**No reasoning was volunteered, and none is invented here.** Because the choice was `merge`, the `close`
branch's question — who owns landing the D-19-A correction — did not arise; the merge landed it.

**No `gh pr merge` and no `gh pr close` ran before this reply.** Every `gh` call in Task 1 was `view`, `list`
or a read-only `api` GET.

### The executed action

```
$ gh pr merge 11 -R OttawaCloudConsulting/security-platform --merge      # rc=0
```

A **merge commit**, matching how Phases 15, 16 and 18 each closed. `--delete-branch` was deliberately **not**
passed. PR #10 was never touched.

```
$ gh pr view 11 -R OttawaCloudConsulting/security-platform \
    --json number,state,mergedAt,mergeCommit,headRefName
{"headRefName":"feature/phase-19-gate-mode-proof",
 "mergeCommit":{"oid":"b4cb20723a158638205a01bf83d51bca4489eafc"},
 "mergedAt":"2026-09-14T01:19:32Z","number":11,"state":"MERGED"}
```

| Field | Value |
|---|---|
| `state` | **`MERGED`** |
| `mergedAt` | **`2026-09-14T01:19:32Z`** |
| `mergeCommit.oid` | **`b4cb20723a158638205a01bf83d51bca4489eafc`** |

**Observed, and recorded rather than smoothed:** PR #11's head branch was **not** auto-deleted by the merge —
`gh api repos/…/branches/feature/phase-19-gate-mode-proof` still returns the branch. PR #10's head branch
*was* deleted at its merge. Auto-delete is therefore not a repository-wide setting here; PR #10's deletion
came with the operator's web-UI merge. No branch was deleted by this plan, and the stale local
`feature/phase-19-pipeline-validation` branch was left alone as the plan required.

## 6. Post-merge verification — read from `origin/main`, after an explicit fetch

```
$ git -C repos/security-platform fetch origin --prune
```

| Read | Result | Meaning |
|---|---|---|
| `git rev-parse origin/main` | **`b4cb20723a158638205a01bf83d51bca4489eafc`** | identical to PR #11's `mergeCommit.oid` — the merge is on the default branch, confirmed from the remote and not from the local tree |
| `git rev-parse origin/main^{tree}` | **`895c1bdf42f32676b732dee10ec6cc36458568fc`** | the same tree hash 19-05 measured SC2 against — `main` now carries exactly the tree both gate-mode runs scanned |
| `git rev-parse origin/main^1` | **`80e91de…`** | parent 1 = PR #10's merge commit |
| `git rev-parse origin/main^2` | **`426c84c…`** | parent 2 = PR #11's head — **two parents, so this is a merge commit**, not a squash or a rebase |
| `git show origin/main:fixtures/vulnerable.py \| head -1` | `# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX" OR RUN` | D-04, still satisfied after the merge |
| `git show origin/main:fixtures/secret.env \| head -1` | `# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"` | D-04, still satisfied after the merge |
| `…:fixtures/README.md \| grep -c 'vulnerable\.py'` | **6** | Fixture Reference rows intact |
| `…:fixtures/README.md \| grep -c 'secret\.env'` | **9** (was 7) | +2 from the D-19-A insertions |
| `…:scripts/smoke-scans.sh \| grep -c 'eval-detected'` | **2** | 19-02's rule-id assertions on `main` |
| `…:scripts/smoke-scans.sh \| grep -c 'aws-access-token'` | **4** | 19-02's rule-id assertions on `main` |
| `…:fixtures/README.md \| grep -c 'GH013\|Push Protection'` | **4** — was **0** | **D-19-A is landed.** `fixtures/README.md` on `main` now names the server-side control that actually blocked 19-03's push |
| `gh pr diff 11 --name-only` | `fixtures/README.md` — **one file** | insertions-only documentation change; **no workflow file was edited anywhere in this phase** |

**D-04's vehicle remains PR #10's merge commit `80e91de`, not this one.** The fixtures, the README rows and
the smoke-gate assertions were on `main` before `b4cb207` existed; §2 recorded them there at Task 1. What
`b4cb207` added is the D-19-A correction and the two empty SC2 re-trigger commits.

## 7. Phase-close assertions — read live after the merge

| Assertion | Command | Result | Verdict |
|---|---|---|---|
| D-09 — no `GATE_MODE` variable | `gh variable list -R …` | **empty output**, rc=0 — no variables of any kind | PASS |
| `main` ruleset unchanged from 19-03's preflight | `gh api repos/…/rules/branches/main --jq '.[].type'` | **`deletion`**, **`non_fast_forward`** — exactly the two 19-03 recorded | PASS |
| No Phase 19 pull request left open | `gh pr list -R … --state open` | **`[]`** — zero open pull requests on the repository | PASS |

No ruleset write and no variable write occurred in this plan, or anywhere in this phase after D-09's revert.
No workflow file was edited.

## 8. `VAL-01` marked complete — method stated, file re-read

**Method:** `gsd-sdk query requirements.mark-complete VAL-01`, driven from this plan's `requirements`
frontmatter. Returned `{"updated": true, "marked_complete": ["VAL-01"], "already_complete": [],
"not_found": [], "total": 1}`. **The tool's own `updated: true` was not accepted as proof** — the file was
re-read (17-01's reverted mark-complete is the precedent):

```
$ grep -n 'VAL-01' .planning/REQUIREMENTS.md
32:- [x] **VAL-01**: Full pipeline validated in this repo using branch-target PRs (no second repo required…)
72:| VAL-01 | Phase 19 | Complete |
```

Both places the file tracks it changed: the checklist line (`[ ]` → `[x]`, line 32) and the
requirement-status table row (`Pending` → `Complete`, line 72). No hand edit was needed.

## 9. Deferred items at phase close — every item accounted for

| Item | Status at phase close | Owner |
|---|---|---|
| **D-19-A** — `fixtures/README.md` understates the control stack (GH013 / Push Protection unmentioned) | **CLOSED by this plan.** Landed on `main` via `b4cb207`; grep count 0 → 4. `deferred-items.md` annotated with the resolution. | — (done) |
| **D-19-B** — Secret Scanning eligible but disabled; `security_and_analysis` is a misleading place to look for whether push protection is in force | **OPEN** — observation only, no action taken in this phase | **Phase 20** |
| **D-19-C** — pre-commit Gitleaks hook is structurally a no-op (`stages: [pre-push]` + `--staged`) | **OPEN** — CONTEXT forbade config changes in this phase; fix options recorded in 19-02/19-03 | **Phase 20** |
| **D-19-D** — `gsd-sdk` state handlers take NAMED flags, not the positional args the executor template documents; `record-session` reports success while silently dropping `Stopped At` | **OPEN** — the fix is to the GSD agent templates under `.claude/`, which carry an unrelated uncommitted tooling self-update this phase must not disturb | **GSD tooling maintainer / Phase 20** |
| **D-19-E** — STATE.md frontmatter `percent` disagrees with its sibling counters | **OPEN, and observed again here:** after this plan's updates the frontmatter reads `completed_plans: 37 / total_plans: 37` with `percent: 86`, while the body bar reads `[██████████] 100%`. `state.validate` calls the file valid, so `percent` is evidently milestone-scoped (6 of 7 phases = 86%). **Deliberately not hand-edited.** | **GSD tooling maintainer / Phase 20** |

Nothing in `deferred-items.md` is silently dropped at phase close.

## 10. Hand-offs to Phase 20 — recorded, not tested and not solved here

### Q1 — repository variables are not passed to fork-triggered workflows, so the gate silently fails open

A workflow triggered by a pull request **from a fork** cannot read repository variables. `vars.GATE_MODE` is
therefore the empty string, the `||` fallback chain in `pr-security.yml` falls through to `'report-only'`,
and the gate **silently fails open** on fork PRs — no error, no warning, just a report-only run where a
blocking one was configured.

- **Source quality, stated honestly:** a **GitHub staff answer in an official community discussion**, not a
  documentation page, and the thread has been **unresolved since January 2023**.
  [CITED: github.com/orgs/community/discussions/44322]
- **Status: deliberately NOT tested.** D-07 scopes every pull request in this phase to the same repository,
  so no fork PR was opened and this phase has no measurement of its own to offer.
- **Consumer-template consequence for Phase 20:** a repository that needs blocking behaviour on fork PRs must
  pass a **literal** `with: gate_mode: blocking` at the call site rather than relying on a repository
  variable. `pr-security.yml`'s own comment already anticipates this.
- **One-line fix that is out of scope here:** `pr-security.yml` still carries a stale comment handing this
  question to Phase 19. Correcting it is a **workflow edit**, which CONTEXT's boundary excludes, so it goes
  to Phase 20 as a one-line fix rather than being made now.

### Pitfall 5 — `fixtures/` is permanent, so report-only is the only state in which this repo's own PRs merge green

`fixtures/` lives on `main` by D-04's design. Every pull request in this repository therefore checks out a
deliberately vulnerable tree and produces findings in all five jobs — **forever**. 19-06 measured this
directly: the "clean" PR was green with 14/11/8/58/6/3 findings still present, because report-only sets
`continue-on-error: true` on every scan step.

Two consequences, both handed on:

1. **D-09's revert was not merely cautious sequencing.** Report-only is currently the only gate mode in which
   this repository's own pull requests can merge green. Leaving `GATE_MODE=blocking` set would have blocked
   every future PR here, including this plan's own merge.
2. **Phase 18 D-07 step 3 (adopting required status checks on `main`) stays deferred.** Required checks plus
   permanent fixtures plus blocking mode would wedge the repository. Phase 20 inherits the sequencing
   question, not a defect.

### PROCESS — two pull requests resolved outside the plan that owned the decision

PR #9 on **2026-09-12T12:48:34Z** (before 18-08 ran) and PR #10 on **2026-09-13T22:34:18Z** (before SC2 and
SC4 were measured). The second invalidated a planned measurement and forced plans 05 and 06 to be replanned
onto new pull requests. Recorded as an **observation about how this work and its operator interact** and
handed to Phase 20. **No process fix is proposed inside this phase** — the phase absorbed the deviation and
recorded it, which is what it was asked to do.

## Deviations from Plan

**1. [Rule 2 — record accuracy] `deferred-items.md` D-19-A annotated as RESOLVED**

- **Found during:** Task 2, while compiling §9.
- **Issue:** The plan's `files_modified` lists only `.planning/REQUIREMENTS.md`. D-19-A's entry ends with
  "Owner: a later plan in this phase, or Phase 20." Leaving that untouched after the merge landed the
  correction would hand Phase 20 an item that reads open while being closed.
- **Fix:** Appended a four-line RESOLVED note to D-19-A naming merge commit `b4cb207` and the 0 → 4 grep
  evidence. No other entry was altered; D-19-B through D-19-E are untouched and remain open.
- **Files modified:** `.planning/phases/19-pipeline-validation-via-branch-target-prs/deferred-items.md`
- **Commit:** this plan's final docs commit.

**2. Observed, not fixed — PR #11's head branch survived the merge.** Recorded in §5. No branch deletion was
performed; the plan authorised a merge, not a branch cleanup.

**3. Observed, not fixed — STATE.md `percent: 86` against a 100% body bar.** This is D-19-E, which
`state.validate` reports as valid. Recorded in §9, deliberately not hand-edited, consistent with every plan
from 19-01 onward.

## What halted, and why it did not auto-approve

Task 1 halted at its `checkpoint:decision` (`gate="blocking"`) and was **not** auto-approved.
`.planning/config.json` carries `"mode": "yolo"` but **no** `workflow.auto_advance`, and
`workflow._auto_chain_active` is `false`; the plan is `autonomous: false`; the plan's `<notes>` open with
"Do not decide D-10 on your own initiative"; and the dispatching orchestrator stated this was the one
deliberately-human decision in the phase. Auto-selecting the recommended option would have merged a pull
request into the default branch of a shared live public repository on the executor's own authority —
precisely threat **T-19-30**. The operator answered, and the answer is recorded verbatim in §5.

## Performance

- **Duration:** 20min — 12min for Task 1 up to the halt, 8min for the resume and Task 2
- **Tasks:** 2 of 2
- **Inner-repo commits:** none authored by this plan. The only inner-repo write was the server-side merge of
  PR #11, producing merge commit `b4cb207` on `main`
- **Outer-repo commits:** `273347e` (Task 1's halt record), plus this plan's final docs commit

## Self-Check: PASSED

| Claim | Check | Result |
|---|---|---|
| This SUMMARY exists | `[ -f .planning/phases/19-…/19-07-SUMMARY.md ]` | written by this session |
| Task 1's halt commit exists | `git log --oneline -1 273347e` | `273347e docs(19-07): record PR #10 deviation live and halt at the D-10 decision` — FOUND |
| PR #11's merge commit exists on the inner repo | `git cat-file -t b4cb2072…` → `commit`; `git log --oneline -1 b4cb207` | `Merge pull request #11 from OttawaCloudConsulting/feature/phase-19-gate-mode-proof` — FOUND |
| The merge is on `origin/main` | `git rev-parse origin/main` = `b4cb2072…` = PR #11's `mergeCommit.oid` | PASS |
| It is a merge commit, not a squash | `origin/main^1` = `80e91de…`, `origin/main^2` = `426c84c…` | PASS |
| D-19-A landed | `…:fixtures/README.md \| grep -c 'GH013\|Push Protection'` = **4** (pre-merge **0**) | PASS |
| D-04 still satisfied post-merge | both headers printed byte-exact; README 6/9; smoke-scans 2/4 | PASS |
| PR #10 read, never acted on | only `gh pr view 10` ran; no `gh pr merge`/`gh pr close` against #10 anywhere | PASS |
| D-09 at phase close | `gh variable list` → empty, rc=0 | PASS |
| Ruleset unchanged | `rules/branches/main` → `deletion`, `non_fast_forward` | PASS |
| No open Phase 19 PR | `gh pr list --state open` → `[]` | PASS |
| `VAL-01` complete in both places | `grep -n 'VAL-01' .planning/REQUIREMENTS.md` → line 32 `[x]`, line 72 `Complete` | PASS |
| Four-SUMMARY precondition ran before mark-complete | §4's precondition table; all four SATISFIED | PASS |
| No workflow file edited | `gh pr diff 11 --name-only` → `fixtures/README.md` only; no outer-repo workflow edit | PASS |
