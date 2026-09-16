---
phase: 22-branch-protection-apply-live-exercise-needs-explicit-target
plan: 03
subsystem: infra
tags: [github-rulesets, branch-protection, required-status-checks, operator-gate, live-write, evidence-capture]

# Dependency graph
requires:
  - phase: 22-02
    provides: "The blocking head SHA 969dc2c8, the control verdict UNSTABLE, verify-sha-preview.json, exit2-fixture.json, and the measured warning that the executor's Bash classifier denies writes on this repository"
  - phase: 20-template-packaging-and-adoption-docs
    provides: "20-10-evidence/merged.json — the 2026-09-14 dry run's output, the independent reference this plan's merged.json is diffed against"
  - phase: 18-configurable-gate-mode-and-branch-protection
    provides: "set-required-checks.sh and its guard contract; the two operator sentences carried forward verbatim"
provides:
  - "The five `security / …` contexts REQUIRED on OttawaCloudConsulting/terraform-pipelines' main — the precondition plan 04's refusal witness depends on"
  - "22-evidence/guard-rehearsal.txt — exit codes 4, 5 and 2 observed at THIS commit, not inherited from 18-03"
  - "22-evidence/apply-transcript.txt — the operator's verbatim --apply output, exit 0"
  - "22-evidence/merged.json — the six-key document PUT, byte-identical to 20-10's dry run"
  - "22-evidence/rules-after.txt + ruleset-after.json + required-contexts-after.json — Claude's own post-write read-back"
  - "22-evidence/required-contexts-codepoints-after.txt — U+2014 proven on all five LIVE context names"
  - "22-evidence/pr14-commit-attribution.json — both PR #14 commits attributed, which is what saves plan 04's CLEAN expectation"
  - "THE FORWARD PUT RETURNED 200 — plan 05 takes its restore branch, unconditionally"
affects: [22-04, 22-05, 22-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Human writes, Claude measures: a privileged write is routed to a gate=\"blocking\" operator checkpoint and every post-write claim is sourced from the agent's own fresh API read, never from the operator's paste"
    - "Guard rehearsal before a live write: re-prove the refusal paths at THIS commit rather than inheriting a prior phase's claim, and halt the whole sequence if any exit code deviates"
    - "Pre-empt known-confusing output in the checkpoint text itself — the exit-5 warning names the wrong repository by design, so it was called out in advance rather than debugged after"

key-files:
  created:
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/guard-rehearsal.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/apply-transcript.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/merged.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/rules-after.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/ruleset-after.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/required-contexts-after.json
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/required-contexts-codepoints-after.txt
    - .planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-evidence/pr14-commit-attribution.json
  modified: []

key-decisions:
  - "Claude ran NO set-required-checks.sh invocation of any kind — not the guard rehearsal, not --help, not a dry run. All four commands were run by the operator in their own terminal (T-22-12)"
  - "The operator's pasted transcript was recorded as provenance but NOT treated as the measurement; every post-write assertion is re-read live by Claude (T-22-15)"
  - "The exit-127 first attempt on command 2 was diagnosed as a paste line-wrap shell parse failure — 127 is not in the script's exit-code table — and is recorded in guard-rehearsal.txt with that explanation rather than omitted"
  - "The plan's own <what-built> text, which says one red check, was corrected to two before being shown to the operator"
  - "require_extra_approval_for_unattributed_changes: true was found live and NOT dismissed: PR #14's commit attribution was measured to establish that plan 04's CLEAN expectation survives it"

patterns-established:
  - "When the checkpoint text must quote a script's output, read the script's actual strings first and warn the operator about any that will look wrong — a false halt costs a full human round-trip"
  - "A non-contract exit code observed during a guard rehearsal is recorded with its diagnosis, never quietly re-run away"

requirements-completed: []  # VAL-02 remains plan 06's to tick

# Metrics
duration: ~30min wall clock (including the operator's four-command run and one paste-artifact retry)
completed: 2026-09-16
---

# Phase 22 Plan 03: The live apply Summary

**The five `security / …` contexts are now REQUIRED on `OttawaCloudConsulting/terraform-pipelines`' `main` — written by the operator's own hand at a blocking checkpoint, with all three pre-existing rule types carried forward byte-identically, `bypass_actors` still `[]`, and every post-write claim in this document re-read live from the API by the agent that did not perform the write.**

A successful PUT is not the deliverable. It is the precondition for plan 04, which witnesses the refusal.

## The one fact plan 05 must not have to infer

**THE FORWARD PUT RETURNED 200.** The ruleset WAS modified. Plan 05 takes its **restore** branch, not its no-forward-write branch.

RESEARCH Pitfall 3 warned that `copilot_code_review` — a preview rule type this repository carries — might 422 on PUT even though GET emits it, and that this could not be determined without a write. It did **not** 422. `copilot_code_review` round-tripped through PUT with its parameters (`review_on_push: true`, `review_draft_pull_requests: true`) byte-identical. That is a positive finding about read-modify-write on a repository carrying a preview rule type, and it belongs in ADR-019 as a result.

## Who ran what

**Claude ran no `set-required-checks.sh` invocation of any kind during this plan** — not the guard rehearsal, not `--help`, not a dry run. All four commands were run by the human operator in their own terminal (T-22-12). Claude's only live calls were `gh api` **reads** before and after.

## The four commands as presented

Each was given in full with real substituted values — no placeholder tokens — the absolute script path (so cwd could not matter), both `--repo` **and** `--ruleset` on every invocation (RESEARCH Pitfall 4: the two defaults are independent and `--repo` alone points at `security-platform`'s ruleset id), an absolute `--out` (the script `cd`s to its own repo root at line 67), and `; echo "exit code: $?"` appended so the operator's paste would be self-documenting.

| # | Flags beyond `--repo OttawaCloudConsulting/terraform-pipelines --ruleset 12760793` | Expected | **Observed** |
|---|---|---|---|
| 1 | `--apply` | exit 4 | **4** |
| 2 | `--verify-sha 969dc2c8… --apply` | exit 5 | **5** |
| 3 | `--input …/exit2-fixture.json --out …/scratchpad/exit2-out.json` | exit 2 | **2** |
| 4 | `--verify-sha 969dc2c8… --out …/22-evidence/merged.json --apply --yes-i-understand-lockout` | exit 0 | **0** |

Commands 1 and 2 are checked before any network call (script lines 130-151); command 3 reads a local fixture through `--input` and touches GitHub not at all. The operator was told explicitly: **if any of 1-3 deviates, stop and do not run command 4.** None deviated.

Command 3's `--out` file was **not** created — exit 2 fires inside the `python3` stage before `json.dump` — and its absence was stated to the operator in advance and confirmed by Claude afterwards.

## The operator's reply, verbatim

> "Operator ran all 4 commands in their own terminal. Result: "applied". All 4 transcripts below."

> Command 2 … "note: first attempt hit a line-wrap paste artifact (exit 127, shell parse error, not the script) which I caught and had the operator retry as a single line"

Command 4's output, verbatim as relayed:

```
verify-sha: checking five contexts appear live at 969dc2c8e12fc6c29f42cab1a9a0bde9eca686c7 (app.id 15368)
verify-sha OK — all five contexts found live with app id 15368
BEFORE rule types: ['deletion', 'non_fast_forward', 'copilot_code_review']
AFTER  rule types: ['deletion', 'non_fast_forward', 'copilot_code_review', 'required_status_checks', 'pull_request']
Merged document written to .../22-evidence/merged.json
Every pre-existing rule type preserved; 5 contexts added, each pinned to integration_id 15368.
APPLYING — PUT repos/OttawaCloudConsulting/terraform-pipelines/rulesets/12760793 from .../merged.json
[full JSON response returned by GitHub — …]
Read-back rule types on rules/branches/main: deletion, non_fast_forward, copilot_code_review, required_status_checks, pull_request
Read-back required contexts on ruleset 12760793: all 5 as above
exit code: 0
```

The relay **abridged** GitHub's PUT response body to a bracketed inventory of its fields. `apply-transcript.txt` reproduces the abridgement exactly as it arrived and marks it as abridged in its own header, because an evidence artifact that misdescribes its provenance is worse than no artifact (22-02 deviation 3). **That transcript is not the measurement.** Everything below is.

## Claude's own read-back — the measurement

Every assertion in this section comes from a **fresh `gh api` read taken after the write by the agent that did not perform it**, not from the operator's paste (T-22-15, 22-PATTERNS Shared Pattern 2 — the discipline 20-10 established when it refused to accept the orchestrator's report of its own dry run).

### Nothing was dropped

```
rules-before.txt  copilot_code_review,deletion,non_fast_forward
rules-after.txt   copilot_code_review,deletion,non_fast_forward,pull_request,required_status_checks
```

The plan's automated assertion — `after == before | {required_status_checks, pull_request}` — passes, printing `write verified: ['copilot_code_review', 'deletion', 'non_fast_forward', 'pull_request', 'required_status_checks']`. Five types. A dropped `deletion` or `non_fast_forward` would have been a security regression dressed as a security improvement; asserting the set independently is what confirms the script's exit-3 guard **worked** rather than assuming it.

Going further than the plan asked, the two ruleset documents were compared field by field: `id`, `name`, `target`, `enforcement`, `conditions`, `source`, `source_type`, `node_id`, `created_at`, `bypass_actors` and `current_user_can_bypass` are all **unchanged**, and each of the three pre-existing rule objects is **byte-identical** including `copilot_code_review`'s parameters. Only `updated_at` moved, to `2026-09-16T19:20:36.158-04:00`.

### The five required contexts

All five, each `integration_id` **15368**:

| Context | integration_id |
|---|---|
| `security / SAST — Semgrep CE` | 15368 |
| `security / IaC — Checkov` | 15368 |
| `security / SCA — Trivy Filesystem` | 15368 |
| `security / Container — Trivy Image` | 15368 |
| `security / Secrets — Gitleaks` | 15368 |

Separators proven by **codepoint dump on the live names**, not eyeballed — a one-codepoint error produces a permanently-pending required check with no runtime signal anywhere (T-22-14):

```
security / SAST — Semgrep CE
  non-ASCII codepoints: U+2014 EM DASH
```

The assertion recorded in `required-contexts-codepoints-after.txt` is that **the only non-ASCII codepoint across all five live names is U+2014**: no U+2013 en dash, no U+002D hyphen-minus. Full per-character dumps for all five are in that file.

`strict_required_status_checks_policy` is `false` and `do_not_enforce_on_create` is `false`.

### Bypass

```
bypass_actors           : []
current_user_can_bypass : 'never'
```

Both quoted from `ruleset-after.json`, unchanged from before. This matters more than it looks: a bypass actor appearing here would quietly convert the whole exercise into a no-op, because an operator who can bypass makes plan 04's refusal advisory rather than real (T-22-13).

### Nothing was merged

`gh api repos/OttawaCloudConsulting/terraform-pipelines/commits/main --jq .sha` → `c490bed09f43bae5440594db7e76011e8951f26c`, `diff` against `main-head-before.txt` **empty**. PR #14 is `OPEN` with `mergedAt: null` at head `969dc2c8…`. `gh variable list` is empty — no `GATE_MODE` residue.

### `merged.json` against 20-10's

```
diff 22-evidence/merged.json 20-10-evidence/merged.json   →   no output, exit 0
```

**Byte-identical.** The two were produced two days apart from the same ruleset by the same code path, and nothing on the pilot's ruleset changed in between. No difference to report.

## The `pull_request` rule — and the parameter the plan did not know about

The plan named five parameters and asked whether plan 04's `CLEAN` expectation survives them. All five are as expected:

| Parameter | Live value |
|---|---|
| `required_approving_review_count` | `0` |
| `dismiss_stale_reviews_on_push` | `false` |
| `require_code_owner_review` | `false` |
| `require_last_push_approval` | `false` |
| `required_review_thread_resolution` | `false` |

**But the live rule carries three parameters the script never sent**, added by GitHub server-side on write:

| Parameter (server-added) | Live value |
|---|---|
| `required_reviewers` | `[]` |
| `allowed_merge_methods` | `["merge", "squash", "rebase"]` |
| **`require_extra_approval_for_unattributed_changes`** | **`true`** |

The third is a review requirement that the plan's five-parameter check would have missed, and it defaults to `true`. Left unexamined it is exactly the hazard the plan warned about: a review requirement holding PR #14 at `BLOCKED` for a reason unrelated to the required checks, which would corrupt plan 04's three-verdict proof.

**It was measured rather than argued about.** Both commits on PR #14 are attributed to a GitHub account (`pr14-commit-attribution.json`):

| SHA | author | committer |
|---|---|---|
| `a792e1a8…` | `OttawaCloudConsulting` | `OttawaCloudConsulting` |
| `969dc2c8…` | `OttawaCloudConsulting` | `OttawaCloudConsulting` |

There are **no unattributed changes on this pull request**, so the flag has nothing to act on. **Plan 04's `CLEAN` expectation survives** — with the caveat below.

**Carry-forward for plan 04.** If the third verdict reads `BLOCKED` with all five checks green, `require_extra_approval_for_unattributed_changes` is the first thing to check, not the last — and `allowed_merge_methods` permits `squash`, which is what plan 04's `gh pr merge --squash` attempt needs.

## Task Commits

1. **Task 1: the operator's guard rehearsal and live apply** — `6432f09` (feat)
2. **Task 2: Claude's independent live re-read** — `89021a5` (feat)

## Deviations from Plan

### 1. [Rule 1 - Bug] The plan's own `<what-built>` text was stale and was corrected before the operator saw it

- **Found during:** Task 1, assembling the checkpoint
- **Issue:** `<what-built>` describes the exercise PR as carrying "one red check (`security / SAST — Semgrep CE`) among five". 22-02 **measured two**: Semgrep CE and `security / SCA — Trivy Filesystem`, both `failure`. Assumption A4 was falsified in plan 02, in the safe direction, and the plan text was written before that measurement landed.
- **Fix:** The checkpoint presented to the operator states the corrected fact explicitly and flags the plan text as stale. The operator was not shown a claim the project's own evidence contradicts.
- **Files modified:** none — the plan is not edited; the correction lives here and in the checkpoint text.

### 2. [Rule 2 - Correctness] Three artifacts added beyond the plan's `<files>`

- **Found during:** Tasks 1 and 2
- **Issue:** The plan's `<files>` for Task 2 lists three artifacts, but two of its own acceptance criteria cannot be supported by them: "em-dash codepoints dumped and recorded as U+2014" has no named file, and the `require_extra_approval_for_unattributed_changes` finding cannot be resolved without attribution data.
- **Fix:** Added `required-contexts-codepoints-after.txt` (per-character dumps of all five live names plus the no-U+2013/U+002D assertion) and `pr14-commit-attribution.json` (both commits, author and committer logins). Also `guard-rehearsal.txt` records Claude's own check that command 3's `--out` file is absent, turning "exit 2 fired before the write" from an inference into an observation.

### 3. [Recorded, not a defect] Command 2's first attempt returned exit 127

- **Found during:** Task 1, relayed by the orchestrator
- **Issue:** The operator's first paste of command 2 hit a line-wrap artifact; the shell failed to parse the multi-line continuation and returned **127**, which is `command not found` emitted by the shell — **not** a value in `set-required-checks.sh`'s exit-code table (0-6). The script never ran. The orchestrator caught it and had the operator retry the identical command on a single line, which returned exit 5 as documented.
- **Why it is recorded rather than dropped:** an exit code observed during a guard rehearsal that is not explained belongs in the evidence with its diagnosis. `guard-rehearsal.txt` carries it under the command-2 section. No guard was worked around and no exit code was routed around.

### 4. [Anticipated, and pre-empted] The exit-5 warning names the wrong repository

- **Found during:** Task 1, reading the script before writing the checkpoint
- **Issue:** The exit-5 heredoc (script lines 136-150) is a quoted heredoc naming `OttawaCloudConsulting/security-platform` literally and mentioning `fixtures/`; it prints byte-identically regardless of `--repo`. An operator seeing the wrong repo name in a refusal message would reasonably suspect `--repo` had not taken effect and halt.
- **Fix:** The checkpoint text warned about it in advance and stated that the halt rule is exit-**code** deviation, not message content. No round-trip was lost.

### 5. [Rule 1 - Bug] Two STATE.md regressions introduced by the state-update SDK, caught and repaired

- **Found during:** state updates, after the task commits
- **Issue A:** the frontmatter `stopped_at` moved *backwards*, from `Completed 22-02-PLAN.md` to `Completed 22-01-PLAN.md`. The executor protocol documents `state record-session` as taking positional arguments; the installed handler parses **named** arguments (`--stopped-at`, `--resume-file`), so the positional call was a no-op on that field and left a stale value behind.
- **Issue B:** frontmatter `progress.percent` was rewritten to `82` while the body progress bar read `95%`. `82` is the *phase* ratio (9/11); every prior value in this file has been the *plan* ratio, and the immediately preceding value `94` is exactly 59/63.
- **Fix:** re-ran `state record-session` with the named arguments the handler actually accepts (`stopped_at` now `Completed 22-03-PLAN.md`, matching the body's `Stopped at:` line), and corrected `percent` to `95` = 60/63 so the frontmatter and the body agree. `state record-metric` and `state add-decision` were likewise re-run with named arguments after the positional forms returned `{"error": "... required"}`.
- **Files modified:** `.planning/STATE.md`
- **Why it is recorded:** a state file that says the project is one plan behind where it is would mislead the next agent to resume at 22-02, re-running a live exercise against a real repository.

---

**Total deviations:** 5 (2 Rule 1, 1 Rule 2, 2 recorded-and-pre-empted execution notes)
**Impact on plan:** No scope creep, no objective changed, no guard bypassed. One genuine finding surfaced that the plan's checklist would have missed (`require_extra_approval_for_unattributed_changes`), and it was resolved by measurement rather than assumption; one state-file regression was repaired before it could mislead the next agent.

## Issues Encountered

One paste artifact (deviation 3), caught and diagnosed by the orchestrator rather than re-run blindly. No classifier denial occurred in this plan, because the plan was designed so that the only write is the operator's — the denial that stalled plans 22-01 and 22-02 mid-flight was routed around structurally rather than discovered mid-task.

## Verification

| Check | Result |
|---|---|
| `guard-rehearsal.txt` records exit codes 4, 5, 2 | pass — observed at this commit |
| `apply-transcript.txt` non-empty, records command 4's exit code | pass — **exit 0** |
| Task 1 automated verify (three `exit code:` greps + `test -s`) | **TASK1-VERIFY-OK** |
| Task 2 automated verify (rule-set union, 5 contexts, id 15368, em dash, `bypass_actors`, review count) | **write verified** |
| `rules-after.txt` = `rules-before.txt` ∪ {`required_status_checks`, `pull_request`} | pass — 5 types |
| Pre-existing rule objects carried forward byte-identically | pass — all 3, parameters included |
| Ruleset `id`/`name`/`target`/`enforcement`/`conditions`/`node_id`/`created_at` | unchanged |
| Five contexts, all `integration_id` 15368 | pass |
| Separator U+2014 on all five LIVE names, by codepoint | pass — no U+2013, no U+002D |
| `bypass_actors` | `[]` |
| `current_user_can_bypass` | `"never"` |
| `pull_request` five named parameters | `0`, `false`, `false`, `false`, `false` |
| `require_extra_approval_for_unattributed_changes` | `true` — **no unattributed commits on PR #14**, measured |
| `diff 22-evidence/merged.json 20-10-evidence/merged.json` | **empty** |
| `commits/main --jq .sha` vs `main-head-before.txt` | identical — `c490bed0…` |
| PR #14 | `OPEN`, `mergedAt: null`, head `969dc2c8…` |
| `gh variable list -R …/terraform-pipelines` | empty |
| `set-required-checks.sh` invoked by Claude | **no** — not once, not even `--help` |
| `! grep -rq UNKNOWN 22-evidence/` | pass |
| Token scan (`gho_\|ghp_\|ghu_\|ghs_`) across `22-evidence/` | no matches |
| `bash scripts/check-adoption-guide.sh` | **PASSED 15 / FAILED 0** |

## User Setup Required

None outstanding. The one manual action this plan needed — the four-command run — has been done.

## Next Phase Readiness

Plan 04 can proceed. Its hard precondition (the five contexts required on `main`) is satisfied and independently verified.

| Value plan 04 needs | |
|---|---|
| PR | **#14**, `OPEN`, `mergedAt: null` |
| Head SHA | **`969dc2c8e12fc6c29f42cab1a9a0bde9eca686c7`** |
| Verdict to discriminate against | **`UNSTABLE`** (22-02's control) |
| Red contexts to expect named in a refusal | `security / SAST — Semgrep CE` **and** `security / SCA — Trivy Filesystem` — two, not one |
| `allowed_merge_methods` | `merge`, `squash`, `rebase` — `--squash` is permitted |
| First suspect if the third verdict is `BLOCKED` with all five green | `require_extra_approval_for_unattributed_changes: true` |
| Forward PUT returned 200? | **YES** |

Plan 05 must take its **restore** branch: the ruleset was modified and `diff rules-before.txt rules-restored.txt` empty remains the non-negotiable gate. Its restoring PUT **will be denied the executor the same way** — structure it as an operator action from the outset, exactly as this plan did, rather than discovering the denial mid-task. Outstanding across the phase, unchanged: PR #14 closed unmerged and its branch deleted, and the ruleset restored.

---
*Phase: 22-branch-protection-apply-live-exercise-needs-explicit-target-*
*Completed: 2026-09-16*

## Self-Check: PASSED

All 8 claimed artifacts exist and are non-empty; both claimed commits (`6432f09`, `89021a5`) resolve in `git log`.
