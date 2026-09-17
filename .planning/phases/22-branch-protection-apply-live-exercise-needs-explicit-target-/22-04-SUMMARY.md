---
phase: 22-branch-protection-apply-live-exercise-needs-explicit-target
plan: 04
subsystem: infra
tags: [github-rulesets, branch-protection, required-status-checks, merge-refusal, mergeStateStatus, evidence-capture, live-exercise]

# Dependency graph
requires:
  - phase: 22-03
    provides: "The forward PUT at exit 0 — the five `security / …` contexts REQUIRED on main, without which there is nothing to witness"
  - phase: 22-02
    provides: "The control verdict UNSTABLE at head 969dc2c8 on tree 57a81e09, the two red checks, and 22-poll-merge-state.sh"
  - phase: 18-configurable-gate-mode-and-branch-protection
    provides: "18-05's one-tree-many-verdicts proof shape and its measured reason for preferring an empty commit over `gh run rerun`"
provides:
  - "22-evidence/merge-attempt.txt — GitHub's refusal VERBATIM. The observation the v2.0 milestone audit lists as never made"
  - "22-evidence/merge-state-blocked.json — BLOCKED at the SAME head SHA the control read UNSTABLE on"
  - "22-evidence/merge-state-clean.json — the third verdict, CLEAN with the contexts still required"
  - "22-evidence/check-runs-clean.json — five green conclusions at 34bf29cb"
  - "22-evidence/required-contexts-still-set.json — the requirement survived into the third verdict, byte-identical to plan 03's capture"
  - "22-assert-verdicts.py — both modes, 12/12 and 6/6"
  - "PROVENANCE FINDING: the refusal is gh's CLIENT-SIDE decline, not a server-side rejection from pulls/14/merge"
  - "require_extra_approval_for_unattributed_changes: true did NOT block — plan 03's UNVERIFIED belief settled empirically"
affects: [22-05, 22-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A write with no dry-run mode is handed to the operator as ONE script that carries its own fresh-read precondition in the same execution, never as a bare command — separating the check from the act is what turns a probe into a merge"
    - "Mechanical ordering interlock between two operator scripts: the second refuses to run until the first's artifact exists, so sequence is enforced rather than instructed"
    - "When reality falsifies an acceptance criterion, tighten the assertion to the criterion's INTENT and never edit the evidence to satisfy it"

key-files:
  created:
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-assert-verdicts.py
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-04-operator-merge-attempt.sh
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-04-operator-green-retrigger.sh
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/merge-attempt.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/merge-attempt-exit-code.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/merge-state-blocked.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/merge-state-clean.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/pr-after-attempt.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/main-head-after-attempt.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/check-runs-clean.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/check-runs-all-apps-clean.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/required-contexts-still-set.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/tree-hash-clean.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/head-sha-clean.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/poll-invocations.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/review-decision-blocked.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/review-decision-clean.json
  modified: []

key-decisions:
  - "Both of this plan's writes were denied by the Bash classifier and both were handed to the operator as self-contained scripts; Claude ran no write of any kind against the target repository"
  - "The refusal's provenance was inspected rather than assumed: it is gh's client-side precondition check, NOT a server-side 405, and the SUMMARY claims only what was observed"
  - "The plan's `merge-attempt.txt must not contain --admin` criterion was falsified by GitHub's own hint text; the transcript was left byte-intact and the assertion was tightened to parse the actual invocation instead"
  - "The direct orientation read of mergeStateStatus that preceded the first polled read was disclosed in the evidence rather than omitted"

patterns-established:
  - "Two coupled operator scripts with a file-based interlock, handed over in separate round-trips so the agent can take an independent measurement between them"
  - "Assert an evidence claim from the primary source that produced it — the script's own `gh pr merge` line — rather than from a proxy string search over its output"

requirements-completed: []  # VAL-02 remains plan 06's to tick, after the ruleset is restored

# Metrics
duration: ~50min wall clock (including two classifier halts and two operator round-trips)
completed: 2026-09-16
---

# Phase 22 Plan 04: Witness the refusal Summary

**GitHub refused to merge PR #14 because a required status check was red, and the refusal is on disk in GitHub's own words — on a pull request whose only change since it read `UNSTABLE` was plan 03's ruleset write, and on a tree hash that a third verdict then proved `CLEAN` once only the check conclusions moved.**

This is the one observation the v2.0 milestone audit lists as never made: *"Blocking gate, required check, merge blocked — UNVERIFIED — dry-run only, never applied."* It is now made.

## The refusal, verbatim

`22-evidence/merge-attempt.txt`, captured with `2>&1` and never reformatted, summarised or predicted. This project had no prior art for this wording — 22-PATTERNS lists it under "No Analog Found" with the instruction *capture it, do not predict it*:

```
X Pull request OttawaCloudConsulting/terraform-pipelines#14 is not mergeable: the base branch policy prohibits the merge.
To have the pull request merged after all the requirements have been met, add the `--auto` flag.
To use administrator privileges to immediately merge the pull request, add the `--admin` flag.
```

**`gh pr merge` exit code: `1`** (recorded independently in `merge-attempt-exit-code.txt`, so the transcript stays purely GitHub's output for ADR-019 to quote inline).

**Merge method passed: `--squash`.** `repo-config-before.json` shows `allow_squash_merge: true`, and plan 03's live read of the `pull_request` rule shows `allowed_merge_methods: ["merge", "squash", "rebase"]`. The transcript contains no text about a disabled or unavailable merge method, asserted programmatically against four patterns — this was a refusal, not a configuration error (T-22-19).

### What the refusal actually proves — and what it does not

**The refusal is gh's CLIENT-SIDE precondition check.** No HTTP status code appears anywhere in the transcript and no request reached `repos/…/pulls/14/merge`. `gh` read `mergeStateStatus`, saw the base branch policy prohibits the merge, and declined locally.

The honest claim is therefore: **the gh CLI declined to merge because GitHub reported the base branch policy prohibits it.** Not "the REST merge endpoint returned 405". The gate was *observed being enforced through the client a developer actually uses*, which is the operationally meaningful thing, but the server-side merge endpoint was not itself exercised. Recorded as a finding rather than glossed, because the distinction is exactly the kind an ADR should state precisely. Exercising the server path would need `gh api -X PUT repos/…/pulls/14/merge -f merge_method=squash` under the same fresh-`BLOCKED` guard; it is **out of this plan's scope and was not run**.

## Three commits, one tree, three verdicts

The tree hash is the invariant; the head SHA deliberately is not.

| # | Head SHA | Checks red (of 5) | Contexts required? | `mergeStateStatus` | `mergeable` |
|---|---|---|---|---|---|
| 0 | `a792e1a8b1054c99ae9406993b5d91d223dbe02f` | 0 | no | `CLEAN` (22-01, resettled) | `MERGEABLE` |
| 1 | `969dc2c8e12fc6c29f42cab1a9a0bde9eca686c7` | **2** | **no** | **`UNSTABLE`** (22-02 control) | `MERGEABLE` |
| 2 | `969dc2c8e12fc6c29f42cab1a9a0bde9eca686c7` | **2** | **YES** | **`BLOCKED`** ← the deliverable | `MERGEABLE` |
| 3 | `34bf29cb2fef09434339e48ba0a466d28241766b` | **0** | **YES** | **`CLEAN`** | `MERGEABLE` |
| | **Tree hash, all three commits** | | | **`57a81e0988c72b9772ca9f912ae8073eca9b5951`** | |

**Rows 1→2 are the phase deliverable, and it is the transition that carries the meaning, not either value alone.** Same head SHA, byte-identical `headRefOid` asserted between the two JSON records, same two red checks, nothing pushed in between. The only thing that moved is that plan 03's operator made the five contexts required.

**Rows 2→3 are what make row 2 attributable.** The ruleset is held constant and only the check conclusions change. Without row 3, `BLOCKED` could have been caused by `copilot_code_review`, by the `pull_request` rule, or by a review requirement (T-22-20). It moves to `CLEAN` with all of those still in force, so the red required check was the sole cause.

The tree hash at `34bf29cb` was verified **from GitHub's own commits API** (`.commit.tree.sha`), not only from the `git rev-parse` the operator's script wrote locally, and its parent is confirmed as `969dc2c8`.

## The third verdict in detail

Five check runs at `34bf29cb`, `app.id == 15368`, every one `success`:

| Context | Status | Conclusion |
|---|---|---|
| `security / SAST — Semgrep CE` | completed | `success` |
| `security / SCA — Trivy Filesystem` | completed | `success` |
| `security / IaC — Checkov` | completed | `success` |
| `security / Container — Trivy Image` | completed | `success` |
| `security / Secrets — Gitleaks` | completed | `success` |

The two that were red at `969dc2c8` — Semgrep CE and Trivy Filesystem — are the two that went green. `GATE_MODE` was confirmed absent before the retrigger, so this is what the callee's report-only default produces.

**The requirement did not go away; only the redness did.** `required-contexts-still-set.json` is **identical** to plan 03's `required-contexts-after.json` — five contexts, each `integration_id` 15368 — with rule types still `copilot_code_review,deletion,non_fast_forward,pull_request,required_status_checks`, `bypass_actors` still `[]` and `current_user_can_bypass` still `never`. A green verdict with the requirement silently removed would have proved nothing.

**All twelve check runs at `34bf29cb` were asserted complete before the merge-state read** — 0 incomplete, 0 non-success, across `github-actions` (5), `github-advanced-security` (6) and `gitguardian` (1). This is the 22-01 addendum's trap: one pending third-party check alone is enough to make the verdict read `UNSTABLE`, and a read taken too early would have measured GitGuardian rather than the gate.

## Plan 03's UNVERIFIED belief, settled

Plan 03 found `require_extra_approval_for_unattributed_changes: true` live on the `pull_request` rule, could not find it in GitHub's published documentation through two Context7 queries, and carried it forward as *the first suspect if the third verdict reads `BLOCKED` with all five green*.

**It did not block.** The third verdict is `CLEAN`, and `reviewDecision` is empty at both the blocked and the clean readings (`review-decision-blocked.json`, `review-decision-clean.json`). The inference plan 03 drew from PR #14's commit attribution held. Note the parameter's *semantics* are still not verified against documentation — what is now verified is only that it did not obstruct this pull request.

A related observation worth carrying to ADR-019: the `copilot_code_review` rule did request a review, and Copilot returned **`COMMENTED`** with *"Copilot was unable to review this pull request because the user who requested the review has reached their quota limit."* A preview rule type that degrades to a non-blocking comment when its quota is exhausted is a fact an adopter should know before relying on it.

## The settle-poll invocations, quoted

Both readings went through the helper; neither halt condition ever fired.

```bash
# Task 1 — the deliverable
bash .planning/phases/22-.../22-poll-merge-state.sh OttawaCloudConsulting/terraform-pipelines 14 "UNSTABLE"
#   exit 0   stdout: BLOCKED   stderr: read 1/20: mergeStateStatus=BLOCKED (previous='UNSTABLE')

# Task 2 — the third verdict
bash .planning/phases/22-.../22-poll-merge-state.sh OttawaCloudConsulting/terraform-pipelines 14 "BLOCKED"
#   exit 0   stdout: CLEAN     stderr: read 1/20: mergeStateStatus=CLEAN (previous='BLOCKED')
```

Passing the prior value is what lets the corrected two-condition post-loop assertion reject a stale read: had GitHub served the pre-write value in Task 1, `S` would have equalled `PREV` and the helper would have exited 1 rather than handing back something that merely looks like a measurement.

**The plan's Task 2 accommodation was not needed and was not used.** It anticipated a possible exit 1 "settled but unchanged" on the new SHA, requiring a 60-second wait and a re-poll with an empty previous value. The verdict moved on the first read, so there was no wait and no re-poll. Recorded explicitly because the acceptance criteria ask which path was taken.

## Nothing landed

| Check | Result |
|---|---|
| `diff main-head-before.txt main-head-after-attempt.txt` | **empty** |
| `main` HEAD, re-read after everything | `c490bed09f43bae5440594db7e76011e8951f26c` — unchanged since plan 01 |
| PR #14 | `OPEN`, `mergedAt: null` |
| `--admin` passed | **never** |
| `--auto` passed | **never** |
| `gh run rerun` used | **never** — empty commit, per 18-05's measured reason |
| `GATE_MODE` set by this plan | **never** |
| Ruleset written by this plan | **never** — this plan only reads it |

PR #14 is left `OPEN` and unmerged. It is now *mergeable*, which is a safer resting point than a blocked one for plan 05 to close — but it must be **closed, never merged**, and plan 05 owns that.

## Task Commits

1. **Task 1 (part): the BLOCKED verdict + both operator scripts** — `6662943` (feat)
2. **Task 1 (fix): retrigger interlock guard** — `31a43ca` (fix)
3. **Task 1: the refusal captured** — `ea1ed30` (feat)
4. **Task 2: the third verdict** — `bdca85b` (feat)

## Deviations from Plan

### 1. [Rule 4 - Escalated] Both of this plan's writes were denied by the Bash classifier and performed by the operator

- **Found during:** Task 1's merge attempt, then again at Task 2's push
- **Issue:** `bash …/22-04-operator-merge-attempt.sh` and `bash …/22-04-operator-green-retrigger.sh` were each **denied by the Claude Code auto mode classifier** — the fourth and fifth instances of the shape measured at 20-07, 20-10, 22-01 Task 4 and 22-02 Task 1. The plan marks both tasks `type="auto"`; it did not anticipate the denial, although 22-02's SUMMARY predicted exactly this for plan 05.
- **Action:** Stopped on each without retry and without any bypass, per the orchestrator's standing instruction and the project's anti-slop protocol. Verified after each denial that **nothing had moved**: no artifact created, PR `OPEN`/unmerged, `main` at `c490bed0`, ruleset intact, and after the second denial the clone still at `969dc2c8` with no local commit.
- **Resolution — and why each was a script rather than a pasted command.** `gh pr merge` has **no dry-run mode**. Its entire safety rests on a fresh `mergeStateStatus` read taken *in the same execution*; handing over a bare `gh pr merge` would have separated the check from the act, which is precisely how a probe becomes a merge (Pitfall 7). `22-04-operator-merge-attempt.sh` therefore carries its own preconditions — ruleset still in force, `main` unmoved, and a fresh read that hard-aborts on anything but `BLOCKED` — plus post-assertions from fresh reads and an exit-9 klaxon if anything merged. `22-04-operator-green-retrigger.sh` carries a **file-based interlock** refusing to run until `merge-attempt.txt` exists, because its push turns the checks green and would have destroyed the `BLOCKED` precondition the attempt depends on. Both were given as single absolute-path invocations — plan 03's exit 127 was a line-wrap paste artifact, and a single token cannot wrap.
- **The two were handed over in SEPARATE round-trips, deliberately.** Bundling them would have been one fewer human turn, but it would have left no point at which the agent could take an independent measurement between the refusal and the green retrigger, and it would have armed a mergeable PR inside the exposure window with no reading in between.
- **Claude ran no write of any kind against the target repository in this plan.** Every value in this document comes from the agent's own `gh api` / `gh pr view` **reads** (T-22-15).

### 2. [Rule 1 - Bug] An acceptance criterion falsified by GitHub's own refusal text

- **Found during:** Task 1 verification, immediately after the transcript arrived
- **Issue:** The plan requires that `merge-attempt.txt` "does not contain the string `--admin`". GitHub's refusal **advertises both bypass flags as hints** — *"add the `--admin` flag"*, *"add the `--auto` flag"*. The criterion as literally written is unsatisfiable by the very artifact it governs, and the artifact is the deliverable.
- **Fix:** The transcript was **not edited** — an evidence file altered to satisfy an assertion is not evidence. The assertion was tightened to the criterion's actual intent, that the *attempt* did not pass a bypass flag, and split in two: (a) every occurrence of `--admin` and `--auto` in the transcript must sit inside gh's own hint line, 0 stray; (b) the producing script is parsed to confirm it carries **exactly one** `gh pr merge` invocation and that it passes `--squash` and neither bypass flag. (b) is strictly stronger than the original string search, because it reads the primary source for what was actually run.
- **Files modified:** `22-assert-verdicts.py`
- **Commit:** `ea1ed30`

### 3. [Rule 1 - Bug] An evidence artifact of mine tripped the phase's own evidence gate

- **Found during:** Task 1 verification
- **Issue:** `poll-invocations.txt` explained the helper's semantics in prose, and that prose spelled out the literal sentinel token the phase's evidence gate greps for and forbids across `22-evidence/`. The gate exists to catch an *unsettled merge state* in an artifact; it is a literal grep and cannot tell prose about the token from a real occurrence of it. Plan 02 hit the identical collision in `gate-mode-loglines.txt`.
- **Fix:** Rephrased to "the unsettled sentinel", with the transformation, its reason and the 22-02 precedent documented **inside the file** so a reader can see what was changed and why. **No measured value was altered** — every recorded value is exactly as read from the API.
- **Files modified:** `22-evidence/poll-invocations.txt`
- **Commit:** `ea1ed30`

### 4. [Rule 2 - Correctness] Artifacts and assertions added beyond the plan's `<files>`

- **Found during:** Tasks 1 and 2
- **Issue:** Several of the plan's own acceptance criteria had no named artifact to rest on, and one of its threat-register mitigations was not represented in the helper.
- **Fix:** Added `merge-attempt-exit-code.txt` (so the transcript stays purely GitHub's output, quotable inline by ADR-019); `poll-invocations.txt` (the invocations, exit codes and both streams, which the criteria require be "quoted in the SUMMARY"); `review-decision-blocked.json` and `review-decision-clean.json` (the plan asks for `reviewDecision` only on a `BLOCKED` third verdict — capturing it at both readings is what lets the `require_extra_approval_for_unattributed_changes` question be answered rather than left open); `check-runs-all-apps-clean.json` (the twelve-check completeness assertion, without which the 22-01 addendum's trap is unguarded); and `head-sha-clean.txt`. The helper also gained the merge-method-error assertion (T-22-19), which the plan requires but did not place in it.

### 5. [Recorded, not a defect] A direct merge-state read preceded the first polled one

- **Found during:** orientation, before the helper existed
- **Issue:** While orienting — reading the clone and confirming the plan's precondition — a single `gh pr view … --json …mergeStateStatus…` was run **directly** rather than through the settle-poll, and it already returned `BLOCKED`. The poll script's header states that nothing in the phase reads `mergeStateStatus` directly.
- **Why it is disclosed rather than omitted:** the polled read is the measurement, and a reader is entitled to know it was not the session's first query. It does not weaken the reading — a direct read cannot make a later polled read stale, and the poll compared against `UNSTABLE`, not against the orientation read. Recorded in `poll-invocations.txt` under its own DISCLOSURE heading. (A second direct read, inside the merge-attempt script, is *required* by design: Pitfall 7 specifies a fresh single read in the same execution as the attempt.)

### 6. [Rule 1 - Bug] The STATE.md percent regression recurred and was repaired again

- **Found during:** state updates, after the task commits
- **Issue:** Exactly the regression plan 03 recorded and fixed: a state handler rewrote frontmatter `progress.percent` to `82` — the **phase** ratio (9/11) — while the body progress bar read `97%`, the **plan** ratio (61/63). Every prior value in this file has been the plan ratio. The handlers also continue to require **named** arguments (`--summary`, `--stopped-at`); the documented positional forms returned `{"error": "summary required"}`.
- **Fix:** Corrected `percent` to `97` so frontmatter and body agree, and re-ran the decision calls with `--summary`. The two decisions this plan added were also retagged from the handler's `[Phase ?]` placeholder to `[Phase 22]`, matching the surrounding Phase 22 entries.
- **Explicitly NOT fixed:** nine pre-existing `[Phase ?]` decision lines from earlier phases. They are out of this task's scope (executor scope boundary) and were left untouched.
- **Files modified:** `.planning/STATE.md`
- **Why it is recorded:** this is the second occurrence in two consecutive plans, which makes it a handler defect rather than a one-off. It belongs in the phase's record so plan 05 expects it rather than rediscovering it.

---

**Total deviations:** 6 (1 Rule 4 escalation, 3 Rule 1, 1 Rule 2, 1 disclosure)
**Impact on plan:** No scope creep, no objective changed, no guard bypassed, no evidence edited to fit an assertion. One acceptance criterion was found to be falsified by reality and its assertion was strengthened rather than relaxed; one belief plan 03 flagged as UNVERIFIED was settled empirically; and one claim the plan would have let pass unqualified — *"GitHub refused the merge"* — was narrowed to what was actually observed.

## Issues Encountered

Two classifier denials (deviation 1), each halted on rather than worked around, each followed by a verification that nothing had moved. No other issue. The workflow run at `34bf29cb` completed `success` on the first status poll.

## Verification

| Check | Result |
|---|---|
| `python3 22-assert-verdicts.py blocked` | **PASSED 12/12** |
| `python3 22-assert-verdicts.py clean` | **PASSED 6/6** |
| `22-assert-verdicts.py` not executable | pass (`test ! -x`, mode 100644) |
| `merge-state-blocked.json` reads `BLOCKED` | pass |
| `headRefOid` identical to `merge-state-unstable.json` | pass — `969dc2c8…` on both |
| Control verdict is not itself `BLOCKED` | pass — `UNSTABLE`, so a real transition |
| `merge-attempt.txt` non-empty, carries stderr | pass — 314 bytes |
| `--admin` / `--auto` outside gh's own hint line | **0 stray** each |
| The script's single `gh pr merge` line | `--squash`, no bypass flag |
| No merge-method configuration error in the transcript | pass — 4 patterns checked |
| `gh pr merge` exit code | **1** (non-zero, as required) |
| `pr-after-attempt.json` | `state: OPEN`, `mergedAt: null` |
| `diff main-head-before.txt main-head-after-attempt.txt` | **empty** |
| Three tree-hash files byte-identical | pass — `57a81e09…` |
| Three head SHAs distinct | pass — `a792e1a8`, `969dc2c8`, `34bf29cb` |
| Tree at `34bf29cb` verified from GitHub's commits API | pass — `.commit.tree.sha` = `57a81e09…` |
| `check-runs-clean.json` — 5 entries, all `success` | pass |
| All 12 check runs at `34bf29cb` complete before the read | pass — 0 incomplete, 0 non-success |
| `required-contexts-still-set.json` — 5 contexts, `integration_id` 15368 | pass — identical to plan 03's capture |
| `bypass_actors` / `current_user_can_bypass` at the third verdict | `[]` / `never` |
| `gh variable list` empty before the retrigger | pass |
| `! grep -rq UNKNOWN 22-evidence/` | pass — 45 files scanned |
| Token scan (`gho_\|ghp_\|ghu_\|ghs_`) across `22-evidence/` | no matches |
| `bash scripts/check-adoption-guide.sh` | **PASSED 15 / FAILED 0** |
| `gh pr merge` run by Claude | **no** — denied, run by the operator |
| `git push` run by Claude | **no** — denied, run by the operator |

## User Setup Required

None outstanding. Both manual actions this plan needed have been done.

## Next Phase Readiness

**Plan 05 must run now.** The exposure window is open: `main` on `OttawaCloudConsulting/terraform-pipelines` is currently locked by five required checks with `bypass_actors: []`, and every observation this phase needed has been captured.

| Value plan 05 needs | |
|---|---|
| Forward PUT happened? | **YES** — plan 05 takes its **restore** branch |
| Restore gate | `diff rules-before.txt rules-restored.txt` **empty**, non-negotiable |
| PR #14 | `OPEN`, `mergedAt: null`, head `34bf29cb…`, now **`CLEAN`/mergeable** |
| PR #14 disposition | **CLOSE UNMERGED** — never merge, then delete `chore/phase-22-required-check-exercise` |
| `main` HEAD to preserve | `c490bed09f43bae5440594db7e76011e8951f26c` |
| Exercise clone | `…/scratchpad/22-exercise-clone`, on the exercise branch at `34bf29cb`, clean |
| Classifier expectation | The restoring PUT, the PR close and the branch delete **will all be denied**. Structure them as operator actions from the outset — this is now the fifth and sixth measured instance. A single bounded operator script, as plans 02 and 04 used, is the established shape |

For plan 06 / ADR-019, the values to quote: the refusal text above verbatim, exit code `1`, `--squash`, the three-verdict table, the shared tree hash `57a81e09…`, **and the provenance qualification** — the decline was client-side, so ADR-019 should say the gate was observed being enforced through the CLI rather than claiming the REST merge endpoint rejected the request.

---
*Phase: 22-branch-protection-apply-live-exercise-needs-explicit-target-*
*Completed: 2026-09-16*

## Self-Check: PASSED

All 17 claimed artifacts exist and are non-empty. All four claimed commits (`6662943`, `31a43ca`, `ea1ed30`, `bdca85b`) resolve in `git log`. No `gho_`/`ghp_`/`ghu_`/`ghs_` token matches anywhere under `22-evidence/`. Neither script nor the Python helper carries an executable bit (all `100644`), per the project's script-safety rule.
