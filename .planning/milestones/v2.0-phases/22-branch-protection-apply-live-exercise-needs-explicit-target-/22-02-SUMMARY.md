---
phase: 22-branch-protection-apply-live-exercise-needs-explicit-target
plan: 02
subsystem: infra
tags: [github-rulesets, branch-protection, mergeStateStatus, gate-mode, gh-cli, evidence-capture, live-exercise]

# Dependency graph
requires:
  - phase: 22-01
    provides: "PR #14 at tree 57a81e09, the exercise clone, 22-poll-merge-state.sh, the operator's recorded `proceed`, the CLEAN resettled baseline verdict, and the measured warning that the Bash classifier denies external-repo writes"
  - phase: 18-configurable-gate-mode-and-branch-protection
    provides: "The empty-commit retrigger technique, the one-tree-hash proof shape, the `gate_mode=` read-from-own-logs method (A10), and the delete-never-report-only close"
provides:
  - "22-evidence/check-runs-unstable.json — TWO red checks of five at head 969dc2c8 on the baseline tree hash"
  - "22-evidence/merge-state-unstable.json — the CONTROL verdict UNSTABLE, red but NOT required; the half of the pair without which a later BLOCKED proves nothing"
  - "22-evidence/gate-window.txt — a 66-second repository-wide blocking window, audited, with exactly one run inside it"
  - "22-evidence/gate-mode-loglines.txt — gate_mode=blocking from all five jobs' own log output, retiring assumption A10"
  - "22-evidence/verify-sha-preview.json + em-dash-codepoints.txt — the exact data plan 03's --verify-sha preflight reads, separator proven U+2014"
  - "22-evidence/exit2-fixture.json — the offline no-`rules`-key fixture for plan 03's guard rehearsal"
  - "22-02-operator-gate-window.sh — the script that produced the Task 1 evidence, committed as its provenance (T-22-07)"
affects: [22-03, 22-04, 22-05, 22-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Machine-bounded write window: when a classifier denies the opening write, hand the operator ONE script that opens, measures and closes inside a single run, rather than a bare `set` whose matching `delete` would face the same denial across a second human round-trip"
    - "EXIT-trap window closure — the repository-wide flag is deleted on every exit path including assertion failure, so a mid-script abort cannot leave the repository blocking"
    - "Persistence measured, not asserted: check runs re-read after the variable is deleted and diffed against the pre-delete capture"

key-files:
  created:
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-02-operator-gate-window.sh
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/tree-hash-blocking.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/check-runs-unstable.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/check-runs-after-variable-deleted.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/check-runs-all-apps-unstable.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/gate-window.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/gate-mode-loglines.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/merge-state-unstable.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/verify-sha-preview.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/em-dash-codepoints.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/exit2-fixture.json
  modified: []

key-decisions:
  - "Task 1's two writes were performed by the OPERATOR running a staged script, not by the executor — the auto-mode Bash classifier denied `gh variable set GATE_MODE` exactly as 22-01 predicted it would"
  - "The operator was given ONE script rather than a bare `gh variable set`, because the closing `gh variable delete` faces the identical denial; a hand-back after the `set` would have left the repository-wide window open across a second human round-trip"
  - "gate-mode-loglines.txt was re-derived from an independent log fetch, dropping gh's unresolvable step-name column, because that column carries a word the phase's own evidence gate forbids"
  - "The settle-poll was passed prev=\"CLEAN\" — the 22-01 addendum's resettled value — not the UNSTABLE literally sitting in merge-state-baseline.json that the plan's <read_first> points at"
  - "Assumption A4 is falsified in the safe direction and recorded as measured: TWO checks are red, not the predicted one"

patterns-established:
  - "A denied write is handed back as a bounded script with a precondition preamble and an EXIT trap, never as a raw command whose cleanup half is also denied"
  - "Re-derive an operator-produced evidence artifact from your own independent fetch before trusting it, and correct your own header when a measurement falsifies it"

requirements-completed: []  # VAL-02 remains plan 06's to tick, after the exercise is witnessed and the ruleset restored

# Metrics
duration: ~65min wall clock (including one classifier halt and the operator's script run)
completed: 2026-09-16
---

# Phase 22 Plan 02: The control verdict Summary

**Two of the five `security / …` checks are red on PR #14 at head `969dc2c8`, on a tree hash byte-identical to the baseline, proven to come from the mode flip by all five jobs' own log lines — and with those red checks NOT yet required the pull request reads `UNSTABLE`, which is the control observation the phase's whole deliverable rests on.**

## The pair, side by side

This is the phase's "before" half. Nothing about the code changed between the two rows; the head SHA moved only because an empty commit was the retrigger mechanism.

| | Baseline (22-01) | Control (this plan) |
|---|---|---|
| Head SHA | `a792e1a8b1054c99ae9406993b5d91d223dbe02f` | `969dc2c8e12fc6c29f42cab1a9a0bde9eca686c7` |
| **Tree hash** | `57a81e0988c72b9772ca9f912ae8073eca9b5951` | `57a81e0988c72b9772ca9f912ae8073eca9b5951` |
| `GATE_MODE` during the run | not set (callee default report-only) | `blocking` |
| Checks red (of five) | 0 | **2** |
| Contexts required? | no | no |
| **`mergeStateStatus`** | `CLEAN` (resettled — see 22-01 addendum) | **`UNSTABLE`** |
| `mergeable` | `MERGEABLE` | `MERGEABLE` |

`diff tree-hash-baseline.txt tree-hash-blocking.txt` produces **no output**. The head SHA differs and the tree hash does not: that is the invariant this phase asserts, and the SHA is explicitly not.

**Why `UNSTABLE` here is the control and not the deliverable.** The checks are red but nothing requires them, so GitHub reports a mergeable PR with a non-passing status. When plan 03's operator makes the five contexts required on this same head SHA with these same red checks, the only variable that will have moved is required-ness. A `BLOCKED` reading then is attributable to required-status-check enforcement rather than to `copilot_code_review`, to the `pull_request` rule, or to anything else on the ruleset. Without this row, it would not be.

## The five check runs at `969dc2c8`, verbatim

All `app.id == 15368`. **Seven** other check runs exist at this SHA — six `github-advanced-security` code-scanning runs derived from our own SARIF uploads, plus one `gitguardian` — and are not ours. An unfiltered count at this SHA is twelve, not five, so every read in plans 03-05 must keep filtering on `app.id == 15368`.

| Name | Status | Conclusion |
|---|---|---|
| `security / SAST — Semgrep CE` | completed | **`failure`** |
| `security / SCA — Trivy Filesystem` | completed | **`failure`** |
| `security / Secrets — Gitleaks` | completed | `success` |
| `security / Container — Trivy Image` | completed | `success` |
| `security / IaC — Checkov` | completed | `success` |

**Assumption A4 predicted exactly one red check and is falsified — in the safe direction.** The interfaces block, from the 2026-09-14 `20-10-evidence/run-a.log.txt` measurement, expected Semgrep alone to go red and `Trivy Filesystem` to stay green because its npm/Python sub-scans skip for want of lockfiles. `Trivy Filesystem` concluded `failure`. The plan's halt condition was *all five green* (no red check, no refusal witnessable); two red satisfies "at least one" with margin. The A4 measurement was two days stale and is now superseded by this one. Plan 04 should expect a refusal naming a `security / …` context but should not assume it names Semgrep specifically.

## The blocking window

```
WINDOW START (GitHub server, actions/variables/GATE_MODE .created_at): 2026-09-16T21:03:13Z
WINDOW END   (executor clock, recorded AFTER the delete):              2026-09-16T21:04:18Z
DURATION: 66 seconds
```

The start is taken from GitHub's own `created_at` on the variable rather than from a local clock, because the write was performed by the operator and a server-side timestamp is what an auditor can check. `GATE_MODE` was read back from the API as `blocking` before the retrigger.

**Runs inside the window: exactly one — `35150200030`, this exercise's own.** The full `gh run list --limit 30` capture is in `gate-window.txt`; the next most recent run on the repository started at `2026-09-16T20:03:37Z`, an hour before the window opened, and the one before that on 2026-09-14. No unrelated run was exposed (Pitfall 5 / T-22-06 mitigated and **measured**, not assumed).

The variable was **deleted**, never set to `report-only` — 18-05 proved deletion restores green. Closure used the guard-then-act form from 22-PATTERNS Shared Pattern 7, `gh variable list … | grep -qx GATE_MODE` before the delete; no `|| true` appears anywhere in this plan's work.

**The window closed inside this plan rather than staying open across plan 03's human checkpoint, and no step was skipped by doing so.** The check conclusions persist on the commit after the variable is gone. That is measured, not asserted: `check-runs-after-variable-deleted.json` was captured after the delete and `diff`s clean against `check-runs-unstable.json`, and a third read taken by the executor an hour later still matches both. Leaving the window open would have exposed every unrelated run on `terraform-pipelines` for the length of a human's response time, for no evidentiary gain.

## The mode proven from the run's own output (A10 retired)

Not inferred from the conclusions — read out of `gh run view 35150200030 --log`. All five jobs:

```
security / SAST — Semgrep CE        2026-09-16T21:03:31.7981855Z gate_mode=blocking
security / SCA — Trivy Filesystem   2026-09-16T21:03:31.7664743Z gate_mode=blocking
security / Container — Trivy Image  2026-09-16T21:03:33.4827841Z gate_mode=blocking
security / Secrets — Gitleaks       2026-09-16T21:03:34.7427634Z gate_mode=blocking
security / IaC — Checkov            2026-09-16T21:03:45.8477019Z gate_mode=blocking
```

Each is paired in the artifact with the emitting shell line, `blocking|report-only) echo "gate_mode=${GATE_MODE}" ;;`, so the value is traceable to the code that printed it. This is 18-05's method exactly and it is what makes the claim "the flip caused the red checks" a measurement rather than a correlation (T-22-07).

## The settle-poll invocation, quoted

```bash
bash .planning/phases/22-.../22-poll-merge-state.sh OttawaCloudConsulting/terraform-pipelines 14 "CLEAN"
```

→ **exit 0**, stdout `UNSTABLE`, stderr one line:

```
read 1/20: mergeStateStatus=UNSTABLE (previous='CLEAN')
```

**One invocation, not two.** The plan anticipated the settled-but-unchanged exit-1 path firing if the control verdict equalled the baseline, requiring a re-invocation with an empty `prev`. It did not fire: the verdict genuinely moved `CLEAN` → `UNSTABLE`, so the two-condition assertion was satisfied on the first read and no re-invocation with an empty `prev` was needed. Neither halt condition — a never-settled timeout, or the forbidden unsettled value — occurred.

**`prev` was `"CLEAN"`, not the `UNSTABLE` sitting in `merge-state-baseline.json`.** The plan's `<read_first>` points at that file as "the previous value the settle-poll must be told about", but the 22-01 addendum records that the baseline verdict resettled to `CLEAN` on the same head SHA once a third-party GitGuardian check completed. Passing `UNSTABLE` would have compared against a value the PR no longer held, and — because the new reading is also `UNSTABLE` — would have produced a spurious exit-1 settled-but-unchanged abort on a verdict that had in fact changed.

**All twelve check runs were asserted complete before the merge-state read**, not just our five. This is the trap the 22-01 addendum identified: a pending third-party check alone makes `mergeStateStatus` read `UNSTABLE`, so a read taken too early would have measured GitGuardian rather than the gate and the control would have been worthless.

| App | `app.id` | Count | Conclusions |
|---|---|---|---|
| `github-actions` (our reusable workflow) | 15368 | 5 | 2 × `failure`, 3 × `success` |
| `gitguardian` | 46505 | 1 | `success` |
| `github-advanced-security` | 57789 | 6 | 6 × `success` |

Twelve total, **zero incomplete**, and the only failures in the entire inventory are our two. The `UNSTABLE` is therefore attributable to the gate and to nothing else. Captured in `check-runs-all-apps-unstable.json`.

## What plan 03's checkpoint reads from here

`verify-sha-preview.json` holds the exact data the operator's `--verify-sha` preflight will query — five entries, every `app_id` 15368 — so the preflight can be *expected* to pass rather than hoped to. The em-dash separator is measured rather than eyeballed, because a one-codepoint error produces a permanently-pending required check with no runtime signal anywhere:

```
U+0053 S  U+0041 A  U+0053 S  U+0054 T  U+0020 SPACE  U+2014 EM DASH  U+0020 SPACE  U+0053 S …
```

The full dump of `security / SAST — Semgrep CE` is in `em-dash-codepoints.txt`, together with an assertion across all five names that their only non-ASCII codepoint is `U+2014` — no `U+2013` en dash, no `U+002D` hyphen-minus.

`exit2-fixture.json` is staged at:

```
/Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/exit2-fixture.json
```

It carries `name`, `target`, `enforcement`, `conditions` and `bypass_actors` and **no `rules` key at all** — `set-required-checks.sh` exits 2 on a missing key, and an empty array means something different to it. It was derived programmatically from `ruleset-before.json` rather than typed. The script was **not** run against it here.

## Task Commits

1. **Task 2 (partial): offline exit-2 fixture** — `058ffde` (chore) — committed at the classifier halt, ahead of Task 1, because it depends on nothing from Task 1
2. **Task 1: the blocking window and its evidence, plus the operator script** — `fa1503f` (feat)
3. **Task 2: control verdict, `--verify-sha` preview, codepoint proof** — `db8f4e0` (feat)

## Deviations from Plan

### 1. [Rule 4 - Escalated] `gh variable set GATE_MODE` denied by the Bash classifier; both writes performed by the operator

- **Found during:** Task 1, at its first live write
- **Issue:** `gh variable set GATE_MODE --body blocking -R OttawaCloudConsulting/terraform-pipelines` was **denied by the Claude Code auto mode classifier**. This is the third measured instance of the same shape: 20-07/20-10 on `set-required-checks.sh` and `gh release create`, and 22-01 Task 4 on `gh pr create`. 22-01's Next Phase Readiness predicted it for precisely this call.
- **Action:** Stopped without retrying and without any bypass, per the orchestrator's standing instruction and the project's anti-slop protocol. Verified and reported that **nothing had moved** — no variable set, `gate-window.txt` not even created (the denial blocked the whole compound command), ruleset unchanged, clone clean at `a792e1a8`.
- **Resolution — and why it was not a bare command hand-back.** `GATE_MODE` is repository-wide, and the *closing* `gh variable delete` faces the identical denial. Handing the operator only the `set` would have opened a repository-wide blocking window and then left it open across a second human round-trip, violating this plan's own must-have that the window be bounded "to minutes and not to the length of a human checkpoint" (T-22-06). Instead the operator was handed one self-contained script, `22-02-operator-gate-window.sh`, that opens the window, retriggers, measures, and closes it inside a single run, with an EXIT trap closing the window on every path including assertion failure. The operator ran it; it exited 0 and the window was 66 seconds.
- **Independent re-verification before any of it was trusted** (22-PATTERNS Shared Pattern 2 — Claude re-verifies operator writes): the executor re-read the check runs live from the API and `diff`ed them against the captured file (identical); `diff`ed the pre-delete and post-delete captures (identical); re-fetched the run log itself rather than reusing the script's derived output; confirmed `gh variable list` empty, `rules/branches/main` unchanged, and `main` still at `c490bed0`.
- **Committed in:** `fa1503f`, which includes the script itself as the evidence's provenance.
- **Significance for plan 05:** the restoring ruleset `PUT` will be denied the same way. Plan 05 should be structured as an operator action from the outset rather than discovering the denial mid-task.

### 2. [Rule 1 - Bug] `gate-mode-loglines.txt` as first captured would have failed the phase's own evidence gate

- **Found during:** Task 1 verification
- **Issue:** The plan's capture is `gh run view --log` grepped for `gate_mode=`. `gh` emits TSV whose second column is the step name; it could not resolve step names for this run and emitted a placeholder containing the word this phase's evidence gate greps for and forbids (`! grep -rq … 22-evidence/`, Pitfall 9: "any evidence artifact containing it is not evidence"). The gate exists to catch an unsettled `mergeStateStatus`; here the word was CLI column formatting appearing on **all 2591 log lines**, carrying no evidentiary meaning — but the gate is a literal grep and would have failed, and kept failing for plans 03-05.
- **Fix:** Re-derived the artifact from the executor's own independent log fetch, dropping only `gh`'s unresolvable step-name column. Job name, timestamp and payload are retained byte-for-byte. Asserted programmatically before dropping that **zero** log lines carry that word anywhere outside that column, so nothing of substance was removed. The file documents the transformation, its reason, and the raw line count, so a reader can reproduce it.
- **Files modified:** `22-evidence/gate-mode-loglines.txt`
- **Committed in:** `fa1503f`

### 3. [Rule 1 - Bug] A false claim in that artifact's own header, caught and corrected

- **Found during:** Task 1, reviewing the rebuilt artifact
- **Issue:** The first rebuild's header stated that ANSI SGR escape sequences had been stripped. `od -c` on the file showed the escapes still present, and then measured **zero** `0x1b` bytes in the raw log: `gh` renders SGR sequences as literal caret-notation ASCII when stdout is not a TTY. Nothing had been stripped because there was nothing to strip — the header described a transformation that never happened.
- **Fix:** Header rewritten to state one transformation rather than two, to record the measured ESC-byte count of 0, to explain that `^[[36;1m` in the file is six ordinary ASCII characters retained verbatim, and to note explicitly that the earlier claim was false and is corrected. An evidence artifact that misdescribes its own provenance is worse than no artifact.
- **Committed in:** `fa1503f`

### 4. [Rule 2 - Correctness] Two evidence files added beyond the plan's `<files>`

- **Found during:** Tasks 1 and 2
- **Issue:** The plan's `<files>` lists neither a post-delete capture nor an all-apps inventory, but two of its claims cannot be supported without them: "the red conclusion outlives the variable" (Task 1's `<done>`) and the attribution of `UNSTABLE` to the gate rather than to a pending third-party check (the 22-01 addendum's instruction).
- **Fix:** Added `check-runs-after-variable-deleted.json` (diffs clean against the pre-delete capture) and `check-runs-all-apps-unstable.json` (twelve runs, zero incomplete, failures only ours). Both turn an assertion into a measurement.
- **Committed in:** `fa1503f` and `db8f4e0`

### 5. [Rule 3 - Blocking] Settle-poll `prev` taken from the addendum, not the file the plan names

- **Found during:** Task 2
- **Issue:** The plan's `<read_first>` names `merge-state-baseline.json` as the source of the previous value; it holds `UNSTABLE`. The 22-01 addendum measured the baseline resettling to `CLEAN` on the same head SHA. Passing `UNSTABLE` would have aborted with a spurious settled-but-unchanged exit 1 on a verdict that had genuinely changed.
- **Fix:** Passed `"CLEAN"`. Documented in the invocation record above.

---

**Total deviations:** 5 (2 Rule 1, 1 Rule 2, 1 Rule 3, 1 Rule 4 escalated to the operator)
**Impact on plan:** No scope creep and no objective changed. Deviation 1 moved two commands from the executor to the operator and cost one operator action; 2 and 3 repaired an evidence artifact that would have failed the phase's own gate or misdescribed itself; 4 and 5 are corrections the plan's own later instructions require.

## Issues Encountered

One halt, resolved by the operator: the classifier denial in deviation 1. Assumption A4 was falsified (two red checks, not one) but in the direction that strengthens the exercise, and it was recorded as measured rather than as predicted. Nothing else.

## Verification

| Check | Result |
|---|---|
| `grep -qE '^proceed\b' go-decision.txt` before any write | pass |
| `diff tree-hash-baseline.txt tree-hash-blocking.txt` | empty |
| `check-runs-unstable.json` holds exactly 5 objects | pass |
| At least one `failure` among them | pass — **2** |
| `gate-mode-loglines.txt` contains `gate_mode=blocking` from all 5 jobs | pass |
| `gh variable list -R …/terraform-pipelines` at task end | empty |
| Delete guarded by `grep -qx GATE_MODE`; no `|| true` anywhere | pass |
| `gate-window.txt` has start, end, duration, and the runs inside | pass — 66s, one run |
| Exactly one run inside the window | pass |
| Live re-read of check runs `diff`s clean against the capture | pass |
| Pre-delete vs post-delete check-run capture | identical |
| `merge-state-unstable.json` `headRefOid` == `969dc2c8…` | pass |
| `merge-state-unstable.json` `state` | `OPEN` |
| `mergeStateStatus` neither the forbidden value nor `BLOCKED` | pass — `UNSTABLE` |
| All 12 check runs completed before the merge-state read | pass |
| `verify-sha-preview.json`: 5 entries, all `app_id` 15368 | pass |
| Separator is `U+2014` on all five names | pass |
| `exit2-fixture.json` parses and has no `rules` key | pass |
| `set-required-checks.sh` invoked | **no** — not once |
| `! grep -rq <forbidden> 22-evidence/` | pass |
| `rules/branches/main` | `copilot_code_review,deletion,non_fast_forward` — unchanged |
| `commits/main --jq .sha` | `c490bed0…` — nothing landed |
| `bash scripts/check-adoption-guide.sh` | PASSED 15 / FAILED 0 |
| Token scan (`gh[posu]_…`) across `22-evidence/` | no matches |

## User Setup Required

None outstanding. The one manual action needed — running `22-02-operator-gate-window.sh` — has been done, and the window it opened is closed.

## Next Phase Readiness

Plan 03 can proceed. The values its checkpoint text is assembled from:

| Value | |
|---|---|
| PR | **#14**, `OPEN`, base `main` |
| Head SHA for `--verify-sha` | **`969dc2c8e12fc6c29f42cab1a9a0bde9eca686c7`** — *not* `a792e1a8…` |
| Tree hash | `57a81e0988c72b9772ca9f912ae8073eca9b5951` |
| Control verdict to discriminate against | **`UNSTABLE`** |
| Red contexts | `security / SAST — Semgrep CE`, `security / SCA — Trivy Filesystem` |
| Ruleset | `12760793`, still `copilot_code_review,deletion,non_fast_forward` |
| Exit-2 rehearsal fixture | `22-evidence/exit2-fixture.json` |

Four things plan 03 onward must carry:

1. **The head SHA moved.** Every `--verify-sha` and every check-run read must target `969dc2c8…`. `a792e1a8…` is the baseline SHA and is now stale.
2. **Expect the ruleset `PUT` to be denied the executor.** Plan 03 already routes it to an operator checkpoint, which is correct; plan 05's restoring `PUT` needs the same treatment, decided up front rather than on a mid-task denial.
3. **Two contexts are red, not one.** A refusal in plan 04 should be confirmed to name a `security / …` context, but not assumed to name Semgrep.
4. **The transition to expect is `UNSTABLE` → `BLOCKED` → `CLEAN`**, measured on one tree hash. Plan 04 should pass `prev="BLOCKED"` to the settle-poll for its third verdict, and must wait for all check runs — GitGuardian included — before every merge-state read.

Outstanding across the phase, unchanged: PR #14 must be **closed unmerged and its branch deleted**, and the ruleset **restored**, with `diff rules-before.txt rules-restored.txt` empty as the non-negotiable gate. The only live residue on `terraform-pipelines` is the exercise branch and PR #14; `main`, the ruleset, and the repository's Actions variables are all untouched.

---
*Phase: 22-branch-protection-apply-live-exercise-needs-explicit-target-*
*Completed: 2026-09-16*

## Self-Check: PASSED

All 11 claimed artifacts exist and are non-empty; all 3 claimed commits (`058ffde`, `fa1503f`, `db8f4e0`) resolve in `git log`.
