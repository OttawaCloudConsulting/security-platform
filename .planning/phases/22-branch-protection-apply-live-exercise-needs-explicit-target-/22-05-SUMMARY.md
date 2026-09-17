---
phase: 22-branch-protection-apply-live-exercise-needs-explicit-target
plan: 05
subsystem: infra
tags: [github-rulesets, branch-protection, rollback, restore, evidence-capture, live-exercise, operator-checkpoint]

# Dependency graph
requires:
  - phase: 22-01
    provides: "ruleset-before.json and rules-before.txt — the capture taken before any write, the only copy of this document outside GitHub, without which no restore is possible"
  - phase: 22-03
    provides: "THE FORWARD PUT RETURNED 200 — the single fact that selects this plan's restore branch; and merged.json, the body GitHub accepted, used here as the local pre-flight cross-check"
  - phase: 22-04
    provides: "PR #14 left OPEN and unmerged at 34bf29cb with its refusal already witnessed — the thing this plan closes"
provides:
  - "The exposure window CLOSED: OttawaCloudConsulting/terraform-pipelines' main is back to copilot_code_review,deletion,non_fast_forward"
  - "22-evidence/rules-restored.txt — diffs EMPTY against rules-before.txt; the phase gate, verified twice from independent reads"
  - "22-evidence/ruleset-restored.json — identical to ruleset-before.json on every key except server-owned updated_at"
  - "22-evidence/rollback.json — the six-key PUT projection, cross-checked EQUAL to merged.json minus the two added rules before it was ever sent"
  - "22-evidence/pr-final.json — PR #14 CLOSED, mergedAt null, branch deleted"
  - "22-evidence/restore-transcript.txt — the operator run, tee'd by the script itself, unabridged"
  - "22-evidence/hygiene-report.txt — both scrub scans over every evidence file, no matches"
  - "22-05-operator-restore.sh — one bounded operator action for three ordered writes, guarded and idempotent"
affects: [22-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cross-check a rollback body against the forward body the server already ACCEPTED (merged.json minus the added rules) — the strongest evidence a restoring PUT will not 422, obtainable entirely offline before the write"
    - "Guarded idempotent steps instead of an EXIT trap: a trap that writes on the error path is a second incident; a re-run that converges is not"
    - "Do not trust a write command's exit code when its remote effect and its local effect can fail independently — judge by the read-back (gh pr close --delete-branch)"
    - "Prove a restore on the WHOLE document, not just the summary projection: full-dict equality excluding only server-owned mutable fields turns 'looks the same' into 'is the same'"

key-files:
  created:
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-05-operator-restore.sh
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/rollback.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/restore-command.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/rules-restored.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/ruleset-restored.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/pr-final.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/put-response.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/put-stderr.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/restore-exit-code.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/restore-transcript.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/main-head-after-restore.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/variables-after.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/hygiene-report.txt
  modified: []

key-decisions:
  - "The RESTORE branch was taken: plan 03's forward PUT returned 200, the ruleset WAS modified, and it was reversed. This is stated rather than inferred, per the plan's requirement"
  - "All three live writes were staged as ONE operator script from the outset — never attempted by Claude, not even once — on the strength of five measured classifier denials in plans 01-04"
  - "The pull request was closed BEFORE the ruleset write, because it was CLEAN and therefore mergeable at that moment; restoring first would have left a mergeable PR armed against an unprotected main"
  - "No EXIT trap: every step is guarded and idempotent so a re-run after partial failure converges rather than double-writing"
  - "gh pr close's exit code was deliberately treated as informational; the branch-delete outcome is judged by a fresh read-back plus a direct git/refs fallback"

patterns-established:
  - "Pre-flight a live PUT offline by proving the body equals a previously-accepted body minus the deltas being reverted"
  - "An operator script tees its own full transcript into the evidence directory from line one, so nothing has to be relayed by hand and abridged"

requirements-completed: []  # VAL-02 remains plan 06's to tick

# Metrics
duration: ~55min wall clock (including one operator round-trip)
completed: 2026-09-16
---

# Phase 22 Plan 05: Restore Summary

**The exposure window is closed. `OttawaCloudConsulting/terraform-pipelines`' `main` ruleset is byte-identical to the document plan 01 captured before anything was touched — proven by an empty `diff` and, beyond that, by full-document equality on every key except server-owned `updated_at` — and the exercise pull request is closed unmerged with its branch deleted.**

## Which branch was taken, stated plainly

**The RESTORE branch.** Plan 03's forward `--apply` exited **0** and the PUT returned **200**; the ruleset *was* modified, so it *was* reversed. The no-forward-write branch — where a rejected PUT would have meant nothing to undo and re-PUTting a byte-identical document would have written a misleading "restored" line into the evidence — was **not** taken.

The precondition was re-measured live before acting rather than read only from plan 03's SUMMARY: at the start of this plan `rules/branches/main` returned `copilot_code_review,deletion,non_fast_forward,pull_request,required_status_checks`. Five types. The forward write was still in force.

## The phase gate

```
$ diff 22-evidence/rules-before.txt 22-evidence/rules-restored.txt
$ echo $?
0
```

No output. That is the gate, and it is a diff rather than a claim.

It was run **twice against independent readings**: once inside the operator script, and once afterwards by the agent against its own fresh `gh api repos/…/rules/branches/main --jq '[.[].type]|sort|join(",")'`. Both empty.

```
rules-before.txt   : copilot_code_review,deletion,non_fast_forward
rules-restored.txt : copilot_code_review,deletion,non_fast_forward
my own fresh read  : copilot_code_review,deletion,non_fast_forward
```

### Stronger than the gate asks for

Rule *types* are a projection. The whole document was compared too:

| Comparison | Result |
|---|---|
| my fresh `GET /rulesets/12760793` six-key projection == `ruleset-before.json` projection | **True** |
| … == `rollback.json` (the body that was sent) | **True** |
| … == the script's own `ruleset-restored.json` projection | **True** |
| **full document, every key, excluding only `updated_at`** | **True** |
| `updated_at` before → now | `2026-02-21T16:30:08.396-05:00` → `2026-09-16T21:30:36.682-04:00` |

`updated_at` is server-owned and *must* move — a restore that left it untouched would mean no write happened. Everything else, including `copilot_code_review`'s `review_on_push` / `review_draft_pull_requests` parameters and the `conditions.ref_name` include/exclude lists, round-tripped unchanged.

`bypass_actors` is `[]` and `current_user_can_bypass` is `never`, read live. No actor was synthesised at any point (T-22-24); the value was carried through `.get("bypass_actors", [])` and asserted `[]` three separate times — when `rollback.json` was built, inside the script before the PUT, and on the post-restore read.

## Consolidated before / after

Every "after" value below is from **the agent's own fresh API read**, taken after the operator's run, not copied from the transcript.

| Axis | Before (plan 01 capture) | After restore | Verdict |
|---|---|---|---|
| `rules/branches/main` | `copilot_code_review,deletion,non_fast_forward` | `copilot_code_review,deletion,non_fast_forward` | **diff empty** |
| `required_status_checks` rule | absent | absent | reversed |
| `pull_request` rule | absent | absent | reversed |
| `bypass_actors` | `[]` | `[]` | unchanged |
| `enforcement` | `active` | `active` | unchanged |
| `gh variable list` | empty | empty | unchanged |
| `GATE_MODE` | absent | absent | never left behind |
| branch list | `["main"]`  *(exercise branch created by plan 01, deleted here)* | `["main"]` | restored |
| `refs/heads/chore/phase-22-required-check-exercise` | — | **404 Not Found** | deleted |
| PR #14 | did not exist → OPEN → **CLOSED**, `mergedAt: null` | `CLOSED`, unmerged | never merged |
| `main` HEAD | `c490bed09f43bae5440594db7e76011e8951f26c` | `c490bed09f43bae5440594db7e76011e8951f26c` | **diff empty** |

`diff main-head-before.txt` against a fresh `commits/main` read: **empty**. Nothing this phase did ever landed on `main`.

## Ordering: the pull request went first, deliberately

At the moment this plan began, PR #14 was `OPEN` and `CLEAN` — every one of the five required checks green, `mergeable`. It was the single most dangerous object in the repository, and the restoring PUT would have made it *more* so by removing the very protection standing between it and `main`.

So the script closes it first, verifies `CLOSED` / `mergedAt: null` and a branch list of `main` only, and **only then** writes the ruleset. Nothing could land while protection was in flux. This is 20-10's precedent for PRs #12 and #13 on this same repository: closed, unmerged, head branch deleted.

`gh pr merge` was **never invoked** by this plan — but the literal string is not absent from the
script, and this SUMMARY will not claim it is. Plan 04 learned this exact lesson when GitHub's own
refusal text advertised `--admin`; the honest claim is about invocations, not substrings:

| String | Occurrences in `22-05-operator-restore.sh` | What they are |
|---|---|---|
| `gh pr merge` at the start of a command | **0** — `grep -nE '^[[:space:]]*gh pr merge'` is empty | no invocation exists |
| `gh pr merge` anywhere | **1**, line 34 | a header comment *disclaiming* it: ``#   - merge the pull request (no `gh pr merge` appears anywhere in this file)`` — a self-referential line that makes its own claim false |
| `--admin` | **1**, line 128 | inside `echo "closing (no merge, no --admin, no --auto):"` |
| `--auto` | **1**, line 128 | the same echo |

Because that echo runs, `--admin` and `--auto` also appear once each in the committed
`restore-transcript.txt`, at line 14. **Neither flag was ever passed to anything.** The script was
left byte-intact rather than edited to make a grep come out clean — an artifact altered to satisfy an
assertion is not evidence (plan 04's rule), and this one is the artifact the operator actually ran.

## The restore was staged before it was run

`rollback.json` was built and fully validated **offline**, before any command touched GitHub:

- six keys exactly — `name`, `target`, `enforcement`, `conditions`, `bypass_actors`, `rules` — mirroring `set-required-checks.sh:237-244`, because `GET /rulesets/{id}` returns eight server-owned fields the PUT schema rejects (22-RESEARCH Pitfall 2)
- `bypass_actors` via `.get(…, [])`, asserted `[]`
- drop-detection in both directions against `rules-before.txt`: nothing missing, nothing extra
- UTF-8 on both ends with `ensure_ascii=False`, quoted heredoc, so no codepoint or `$` fragment was ever shell-touched
- **the cross-check that mattered most:** `rollback.json` was asserted **parsed-JSON EQUAL to `22-evidence/merged.json` with the `required_status_checks` and `pull_request` rules removed**. `merged.json` is the body GitHub answered **200** to in plan 03. That makes the rollback the same document shape, on the same endpoint, on the same repository, already proven to round-trip — the strongest available offline evidence that the restoring PUT would not 422, and it cost five lines.

`restore-command.txt` was written **before** the PUT was attempted, carrying the complete `gh api --method PUT … --input <absolute path>`. The script then asserts that this artifact names ruleset `12760793` and points at `rollback.json` before running the identical command, so the escalation paste and the actual execution cannot drift apart.

The PUT was not rejected. `restore-exit-code.txt` reads `0` and `put-stderr.txt` is 0 bytes. No 422, no key was removed by trial and error, no hand-edit.

## The classifier, sixth and seventh instances — pre-empted, not discovered

Plans 01-04 accumulated **five** measured denials of live writes by the Bash auto-mode classifier. Plan 04's SUMMARY predicted this plan's three writes would be denied too and told it to structure them as an operator action from the outset.

**That is what happened. Claude attempted none of the three writes, not even once.** The PR close, the branch delete and the restoring PUT were staged directly into `22-05-operator-restore.sh` and handed over as one absolute-path invocation. There was no denial to recover from because there was no attempt. Every number in this document comes from the agent's own `gh api` / `gh pr view` **reads**, which are not writes and were never denied.

Three design choices in that script are worth carrying forward:

1. **No EXIT trap.** A trap that writes on the error path is a second incident waiting to happen. Every step instead checks live state and skips work already done, so a re-run after a partial failure *converges*. Step B's guard — "if rule types already equal the capture, perform no PUT and say so" — is the same conditional the plan specifies for the no-forward-write branch, wired in as a runtime property rather than a decision made once at authoring time.
2. **`gh pr close`'s exit code is informational.** `--delete-branch` performs the *remote* delete first and can still fail afterwards on a *local* branch — and the script runs from this documentation repository, which has no such branch. Under `set -e` that would have killed the run with the PR closed and the ruleset still locked: exactly the half-done state the design exists to prevent. The outcome is judged by a fresh `branches` read, with a direct `gh api --method DELETE repos/…/git/refs/heads/…` as fallback. (The fallback was not needed — the close deleted the branch cleanly — but it was there.)
3. **The script tees its own transcript** into `22-evidence/restore-transcript.txt` from line one. Plan 03's operator output arrived abridged by hand-relay; this one could not.

## Evidence hygiene

`hygiene-report.txt` records two recursive scans over **all 56 files** that were in `22-evidence/` at scan time:

| Scan | Pattern | Result |
|---|---|---|
| 1 | GitHub token prefixes — broadened from the plan's two forms to all five (`o`/`p`/`r`/`s`/`u`) | **no matches** |
| 2 | the unsettled merge-state sentinel | **no matches** |

Neither forbidden literal is spelled out inside the report. Both greps are literal string searches over the directory the report lives in, so writing the patterns verbatim would have made the report itself the only hit — the same self-collision plan 02 hit in `gate-mode-loglines.txt` and plan 04 hit in `poll-invocations.txt`. The report says so in its own header.

Neither scan was made to pass by editing a file. `pr-final.json` was requested **without** `mergeStateStatus` for the same reason: that field's enum contains the sentinel, and a restore artifact does not need it.

The plan's own verification line then ran **verbatim** and printed `HYGIENE-OK`. It ran *after*
`hygiene-report.txt` had been written, so its sweep covered **57** files — the 56 scanned above plus
the report itself. The two counts differ by exactly one for that reason, and the later, larger sweep
is the one the plan's gate specifies.

## What remains changed on GitHub, and is not reversible

Two residues persist on `OttawaCloudConsulting/terraform-pipelines`. **No git revert in this repository touches either.** Both are low-impact and both match what the 20-10 pilots already left behind:

1. **Code-scanning analyses.** **18** analyses attributable to the exercise branch / `refs/pull/14/merge` sit in the repository's code-scanning tab — SARIF uploaded by the security workflow runs that produced the red and then green check conclusions. They are historical scan results on commits that no longer exist as a branch. They are not deleted, and deleting them is not attempted.
2. **The closed pull request.** PR #14 remains in the repository's pull-request history as a closed, unmerged entry with its full timeline — the merge refusal, the Copilot review comment, the check runs. This is the same shape PRs #12 and #13 were left in by 20-10.

The two things that *were* explicitly reversed are the ruleset and the variable, and both are proven above.

## Task Commits

1. **Task 1 (staging): rollback body, escalation command, operator script** — `a146f3e` (feat)
2. **Task 1 + 2 (verified): the restore and the evidence** — `72a2d9c` (feat) — bundled; see deviation 5

The operator's run sits between the two. Nothing was committed claiming a restore until the restore had been independently re-read.

## Deviations from Plan

### 1. [Rule 2 - Correctness] Both live-write tasks were staged as one operator action up front rather than attempted

- **Found during:** before Task 1's first write
- **Issue:** The plan marks both tasks `type="auto"`. Five prior denials in this phase establish that every write against this repository is refused by the Bash auto-mode classifier. Attempting them would have produced a sixth and seventh denial and nothing else.
- **Action:** Wrote `22-05-operator-restore.sh` covering all three writes in their required order and halted with it, rather than discovering the denial. The plan's own Task 1 text anticipates this outcome ("If the executor's Bash classifier denies the PUT … escalation is then one paste to the operator") — this simply reaches that state without the failed attempt.
- **Why it is a deviation and not just execution:** the plan structures Task 1 as agent-run with an escalation fallback; it was run the other way round.

### 2. [Rule 1 - Bug] `variables-after.txt` cannot diff clean against `variables-before.txt` as a whole file

- **Found during:** Task 2, before running the comparison
- **Issue:** The acceptance criterion asks that `variables-after.txt` "diffs clean against `variables-before.txt`". `variables-before.txt` carries a `# captured: <timestamp>` header line and an `# exit code:` line. A whole-file diff can never be empty — the timestamps differ by construction — so the criterion as literally written is unsatisfiable by any correct artifact.
- **Fix:** The comparison is scoped to the marker-bounded region both files already define (`--- begin output ---` / `--- end output ---`), which is the region that actually carries the measurement. That diff is **empty**. The after-file keeps the same header shape plus a line recording the guard-then-act result. No value was altered to make a check pass — the same rule plan 04 applied to `merge-attempt.txt`.
- **Files modified:** `22-evidence/variables-after.txt` (created)
- **Commit:** `72a2d9c`

### 3. [Rule 2 - Correctness] The variable delete never fired, and the SUMMARY says so rather than implying a deletion

- **Found during:** Task 2
- **Issue:** The plan's action says "delete only if present". `GATE_MODE` was already absent — plan 02's operator window deleted it, and plan 04 confirmed the list empty before its retrigger.
- **Action:** The guard-then-act ran as specified: `gh variable list --json name --jq '[.[].name]'` returned `[]`, the exact-match test on `GATE_MODE` returned false, and **no delete command was issued**. No `|| true` appears anywhere in this plan. `variables-after.txt` records `guard-then-act result: absent-no-delete-needed` explicitly, so a reader cannot mistake "nothing to do" for "done".

### 4. [Rule 2 - Correctness] Artifacts and assertions beyond the plan's `<files>`

- **Found during:** Tasks 1 and 2
- **Issue:** Several claims had no artifact to rest on, and the "byte-identical" language in the plan's must-haves is stronger than a rule-type diff can support on its own.
- **Fix:** Added `put-response.json` and `put-stderr.txt` (so a 422 would have been reportable with its raw body without reconstruction — both captured even though the PUT succeeded), `restore-exit-code.txt`, `restore-transcript.txt` (the unabridged operator run), `main-head-after-restore.txt`, and the full-document equality assertion excluding `updated_at`. Also broadened the token scan from two prefixes to five.

### 5. [Disclosed, not a defect] Task 1's and Task 2's evidence landed in ONE commit

- **Found during:** the post-operator verification pass
- **Issue:** The orchestrator's instruction is to commit each task atomically. `72a2d9c` carries both
  tasks' artifacts. Task 1's staged inputs went in separately (`a146f3e`), but the restore read-backs
  and the Task 2 hygiene/variable artifacts did not.
- **Why:** both sets of values were produced by the *same* verification pass after the operator's
  single run — the variable check, the hygiene scans and the ruleset read-backs are all reads of one
  post-restore state, and splitting them would have created a commit asserting a restore that the
  following commit then had to re-assert. It is disclosed rather than corrected: unbundling now would
  require history rewriting, which this project's protocol treats as an irreversible action needing
  its own authorisation.

---

**Total deviations:** 5 (1 procedural, 1 Rule 1, 2 Rule 2, 1 disclosure)
**Impact on plan:** No scope creep, no objective changed, no guard bypassed, no evidence edited to satisfy an assertion. One acceptance criterion was found unsatisfiable as literally written and its comparison was scoped to the region that carries the measurement, with the scoping disclosed.

## Issues Encountered

None during the restore itself. The operator's run completed exit 0 on the first attempt with no fallback path taken: the branch-delete fallback did not fire, the no-PUT-needed branch did not fire, and no abort condition triggered.

One thing worth naming as a near-miss rather than an issue: had `set -e` been left active across `gh pr close`, a local-branch failure after a successful remote delete would have aborted the script with the pull request closed and the ruleset still carrying five required checks. That was designed out before the script ran, not discovered after.

## Verification

Every row is the agent's own read or its own command, run after the operator's script finished.

| Check | Result |
|---|---|
| `diff rules-before.txt rules-restored.txt` | **empty** — the phase gate |
| `diff rules-before.txt` vs agent's own independent fresh read | **empty** |
| Live six-key projection == `ruleset-before.json` projection | **True** |
| Live six-key projection == `rollback.json` | **True** |
| Full live document == capture, excluding `updated_at` | **True** |
| `required_status_checks` on the ruleset | **absent** |
| `pull_request` rule on the ruleset | **absent** |
| `bypass_actors` / `current_user_can_bypass` | `[]` / `never` |
| `rollback.json` top-level key count | **6**, exactly the PUT schema |
| `rollback.json` == `merged.json` minus the two added rules | **True** (checked before the PUT) |
| `restore-command.txt` written before the PUT | **yes** — and asserted by the script to match what it ran |
| PUT exit code | **0**; `put-stderr.txt` 0 bytes; no 422 |
| `pr-final.json` | `state: CLOSED`, `mergedAt: null` |
| `gh api repos/…/branches` | `["main"]` |
| `refs/heads/chore/phase-22-required-check-exercise` | **404 Not Found** |
| `diff main-head-before.txt` vs fresh `commits/main` | **empty** — `c490bed0…` |
| `gh variable list -R …` | **empty** |
| `variables-after.txt` marker-scoped diff vs before | **empty** |
| Token scan (5 prefixes) over the 56 files present at scan time | **no matches** |
| Unsettled-sentinel scan over the same 56 files | **no matches** |
| Plan's own hygiene verify line, verbatim, over all 57 committed files | **HYGIENE-OK** |
| `bash scripts/check-adoption-guide.sh` | **PASSED 15 / FAILED 0** |
| `bash -n 22-05-operator-restore.sh` | syntax OK |
| Executable bits under the phase directory | none — all `100644` |
| File deletions in this plan's commits | **none** |
| `22-poll-merge-state.sh`, `22-assert-verdicts.py`, `22-evidence/` committed | **yes**, all tracked |
| Scratchpad clone committed | **no** — untracked, session-scoped |
| `gh pr merge` **invoked** by anyone | **no** — `grep -nE '^[[:space:]]*gh pr merge'` on the script is empty; the one textual occurrence is the header comment disclaiming it (see above) |
| `--admin` / `--auto` **passed** to anything | **no** — one textual occurrence each, inside the script's own `closing (…)` echo, hence also in the transcript |
| Any write run by Claude against the target repository | **no** — all three staged for the operator |

## User Setup Required

None. The one operator action this plan needed has been run and verified.

## Next Phase Readiness

**The exposure window is closed, and plan 06 has no urgency constraint.** Everything it needs is on disk and the target repository is back to how it was found.

| Value plan 06 / ADR-019 needs | |
|---|---|
| Restore branch taken | **RESTORE** — the forward PUT happened and was reversed |
| Phase gate | `diff rules-before.txt rules-restored.txt` **empty**, verified twice |
| Ruleset now | `copilot_code_review,deletion,non_fast_forward` — identical to capture but `updated_at` |
| PR #14 | `CLOSED`, `mergedAt: null`, branch deleted, ref 404s |
| `main` HEAD | `c490bed09f43bae5440594db7e76011e8951f26c`, untouched throughout |
| Irreversible residues to disclose | 18 code-scanning analyses; the closed PR in history |
| VAL-02 | still **plan 06's to tick** |
| Provenance qualification to carry | plan 04's: the refusal was gh's client-side decline, not a server-side rejection |

---
*Phase: 22-branch-protection-apply-live-exercise-needs-explicit-target-*
*Completed: 2026-09-16*

## Self-Check: PASSED

All 14 claimed artifacts exist and are non-empty (`put-stderr.txt` is intentionally 0 bytes — the PUT emitted no stderr, and the empty file is itself the evidence of that). Both claimed commits (`a146f3e`, `72a2d9c`) resolve in `git log`. No executable bit anywhere under the phase directory (all `100644`), per the project's script-safety rule. This SUMMARY contains neither forbidden literal, so it does not trip the phase's own evidence gate.
