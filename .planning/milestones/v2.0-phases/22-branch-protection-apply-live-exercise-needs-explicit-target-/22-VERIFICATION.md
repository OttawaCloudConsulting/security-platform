---
phase: 22-branch-protection-apply-live-exercise-needs-explicit-target
verified: 2026-09-16T23:10:00Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
---

# Phase 22: branch-protection --apply live exercise Verification Report

**Phase Goal:** Witness GitHub refusing a merge because a required scan check is red — the one
end-to-end flow the v2.0 milestone audit lists as UNVERIFIED — by making the five
`security / ...` contexts required on `OttawaCloudConsulting/terraform-pipelines` for a bounded
window, capturing the refusal verbatim, and restoring the repository's ruleset byte-identically
afterwards.

**Verified:** 2026-09-16T23:10:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Method

ROADMAP.md carries a Goal statement but no `success_criteria` list, and the PLAN files carry no
`must_haves` frontmatter block, so truths were derived from the goal (Option C). Verification
combined (a) reading all six plan SUMMARYs and the phase VALIDATION.md, (b) spot-checking primary
evidence files in `22-evidence/` against SUMMARY claims rather than trusting the claims, (c)
independently re-running the phase's own offline assertion scripts (`22-assert-verdicts.py`) against
the evidence on disk, and (d) live, read-only `gh api`/`gh pr`/`gh variable` calls against the real
target repository to confirm its *current* state matches "restored," independent of anything any
SUMMARY says.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The five `security / …` contexts were made REQUIRED on `terraform-pipelines`' `main` via a live `--apply`, preserving all pre-existing rule types | ✓ VERIFIED | `22-evidence/rules-after.txt` = `copilot_code_review,deletion,non_fast_forward,pull_request,required_status_checks`; `22-evidence/merged.json` byte-identical to independent `20-10-evidence/merged.json`; operator transcript + Claude's own independent post-write `gh api` read-back agree |
| 2 | GitHub refused a merge on a red required check, and the refusal text is captured verbatim, unedited | ✓ VERIFIED | `22-evidence/merge-attempt.txt` read directly: `"the base branch policy prohibits the merge"`; `gh pr merge` exit code `1` (`merge-attempt-exit-code.txt`); no `--admin`/`--auto` passed (confirmed by re-running `22-assert-verdicts.py blocked` myself: 12/12 pass) |
| 3 | The refusal is attributable to the required-check mechanism specifically, isolated on one constant head SHA, not to any other rule (`copilot_code_review`, `pull_request`, review requirements) | ✓ VERIFIED | `merge-state-unstable.json` and `merge-state-blocked.json` share identical `headRefOid` `969dc2c8e12fc6c29f42cab1a9a0bde9eca686c7`; only variable that moved between the two readings was required-ness; a third `CLEAN` reading at a new commit (`34bf29cb…`) with contexts still required and all checks green isolates cause; `tree-hash-baseline.txt`/`tree-hash-blocking.txt`/`tree-hash-clean.txt` are byte-identical (`57a81e09…`) — confirmed by direct read, not just SUMMARY quote |
| 4 | The target repo's branch-protection ruleset was restored to its exact prior state afterward | ✓ VERIFIED | `diff rules-before.txt rules-restored.txt` → empty (re-run myself); `diff ruleset-before.json ruleset-restored.json` → exactly one differing line, the server-owned `updated_at` field, nothing else (re-run myself, not just SUMMARY's claim) |
| 5 | The target repo is *currently* in its restored state — no residue that could surprise a future user of that repository | ✓ VERIFIED | Live `gh api` calls run independently in this verification session (not sourced from any evidence file): `rules/branches/main` → `copilot_code_review,deletion,non_fast_forward` (no `required_status_checks`, no `pull_request`); zero open PRs; PR #14 `CLOSED`/`mergedAt: null`; exercise branch `chore/phase-22-required-check-exercise` → HTTP 404 (deleted); `gh variable list` → empty (no `GATE_MODE`); `main` HEAD still `c490bed09f43bae5440594db7e76011e8951f26c` |
| 6 | The exercise and its outcome are recorded in the project's decision-record system, and VAL-02 is closed | ✓ VERIFIED | `docs/adr/adr019-required-check-enforcement-live-exercise.md` exists, new file, 4 required headings (`Context`/`Decision`/`Consequences`/`What was NOT verified`); ADR-017/018 untouched — confirmed both by working-tree diff AND `git log --oneline c2d3095^..HEAD -- docs/adr/adr017-*.md docs/adr/adr018-*.md` (empty — no phase commit touched them, not just no uncommitted diff); `.planning/REQUIREMENTS.md` shows `- [x] **VAL-02**` and `| VAL-02 | Phase 22 | Complete |` |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `22-evidence/` (57 files) | Full evidence trail for the live exercise | ✓ VERIFIED | All files present, non-empty (except intentionally-empty `put-stderr.txt`, self-documented) |
| `22-evidence/rules-before.txt` / `rules-restored.txt` | Phase gate pair | ✓ VERIFIED | Read directly; `diff` empty |
| `22-evidence/merge-attempt.txt` | Verbatim GitHub refusal | ✓ VERIFIED | Read directly, matches quotes in SUMMARY and ADR-019 exactly |
| `22-assert-verdicts.py` | Offline verdict assertion helper | ✓ VERIFIED, WIRED | Re-executed independently in this verification: `blocked` mode 12/12 pass, `clean` mode 6/6 pass — not merely inherited from SUMMARY's claimed output |
| `22-poll-merge-state.sh` | Bounded settle-poll with 2-condition guard | ✓ VERIFIED | `bash -n` syntax check passes; source line `[ "$S" != "UNKNOWN" ] && [ "$S" != "$PREV" ]` present as claimed |
| `docs/adr/adr019-required-check-enforcement-live-exercise.md` | New ADR, append-only | ✓ VERIFIED | 4 headings present in order; explicitly hedges what was NOT verified (server-side merge endpoint, `require_extra_approval_for_unattributed_changes` semantics) rather than overclaiming |
| `.planning/REQUIREMENTS.md` | VAL-02 marked complete | ✓ VERIFIED | Checkbox + table row + coverage block (15/15/0) all consistent |
| `docs/adoption-guide.md` §8 | Measured-not-theoretical apply guidance | ✓ VERIFIED (not independently re-read line-by-line, but `bash scripts/check-adoption-guide.sh` gate re-run: 15/15 PASS) | |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Plan 01 baseline capture | Plan 05 restore | `diff rules-before.txt rules-restored.txt` | ✓ WIRED | File pair spans the whole phase; gate re-run independently, empty |
| Plan 03 forward PUT | Plan 04 refusal witness | shared head SHA `969dc2c8…`, shared tree hash | ✓ WIRED | `headRefOid` identical across control/blocked readings, confirmed by direct file read |
| Plan 06 ADR-019 | Live evidence | inline quoted values (SHAs, run ids, refusal text) | ✓ WIRED | Spot-checked several inline quotes (refusal text, tree hash, commit SHAs) against the underlying evidence files — match |
| Restored ruleset (disk evidence) | Live GitHub state | independent `gh api` read in this verification | ✓ WIRED, FLOWING | Live read matches `rules-restored.txt` exactly, taken hours after the phase's own last read — confirms durability, not just a point-in-time claim |

### Behavioral Spot-Checks (Step 7b)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| BLOCKED-verdict assertion bundle | `python3 22-assert-verdicts.py blocked` | `RESULT: PASSED — 12/12 assertions` | ✓ PASS |
| CLEAN-verdict assertion bundle | `python3 22-assert-verdicts.py clean` | `RESULT: PASSED — 6/6 assertions` | ✓ PASS |
| Standing doc gate | `bash scripts/check-adoption-guide.sh` | `PASSED 15 / FAILED 0` | ✓ PASS |
| Live target-repo rules read | `gh api repos/OttawaCloudConsulting/terraform-pipelines/rules/branches/main --jq '[.[].type]|sort|join(",")'` | `copilot_code_review,deletion,non_fast_forward` | ✓ PASS |
| Live open-PR count | `gh pr list -R OttawaCloudConsulting/terraform-pipelines --state open` | `[]` | ✓ PASS |
| Live PR #14 state | `gh pr view 14 -R … --json state,mergedAt,headRefName` | `CLOSED`, `mergedAt: null` | ✓ PASS |
| Live exercise-branch existence | `gh api repos/…/branches/chore/phase-22-required-check-exercise` | `404 Not Found` | ✓ PASS |
| Live Actions variables | `gh variable list -R OttawaCloudConsulting/terraform-pipelines` | empty | ✓ PASS |
| Live `main` HEAD | `gh api repos/…/commits/main --jq .sha` | `c490bed09f43bae5440594db7e76011e8951f26c` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| VAL-02 | 22-01 (registered), 22-06 (closed) | Required-check enforcement exercised live — a pull request with a red required check is observably refused by GitHub | ✓ SATISFIED | ADR-019 + evidence trail + live re-read; REQUIREMENTS.md marked Complete |

No orphaned requirements found for Phase 22 in `.planning/REQUIREMENTS.md`.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `22-PATTERNS.md:710`, `22-06-SUMMARY.md` (x3), `22-06-PLAN.md` (x3), `22-RESEARCH.md` (x2) | various | `TBD` string matches | ℹ️ Info | All are prose *negations* ("contains no TBD", "22-VALIDATION.md free of TBD", grep assertions checking absence) or historical description of a prior placeholder state, not live unresolved debt markers. Confirmed by reading each match in context. Not a blocker. |

No `FIXME` or `XXX` matches found. No stray `TODO`/`HACK`/`PLACEHOLDER` found in evidence or plan/summary files for this phase.

### Disclosed, Non-Blocking Residues (carried forward from ADR-019 / 22-05 SUMMARY — reported here for completeness, not gaps)

These are explicitly disclosed by the phase's own record as irreversible-but-low-impact and match the precedent already left by the Phase 20 pilots on the same repository:

1. **18 code-scanning analyses** attributable to the exercise branch / `refs/pull/14/merge` remain in `terraform-pipelines`' code-scanning tab (SARIF uploads from the workflow runs). Historical scan results on commits that no longer exist as a branch; not deleted, deletion not attempted.
2. **PR #14 remains in the repository's closed-PR history** with its full timeline (refusal, Copilot review comment, check runs). Same shape as pilot PRs #12/#13 left by Phase 20.
3. **The required-check exposure window was materially longer than the `GATE_MODE` blocking window.** The `GATE_MODE=blocking` window (plan 02) was 66 seconds, audited, one run inside it. The *required-check* window (ruleset had `required_status_checks`/`pull_request` live) ran from the plan 03 PUT (`updated_at` 19:20:36-04:00) to the plan 05 restore (`updated_at` 21:30:36-04:00) — **about 2 hours 10 minutes**, during which any other PR opened against `terraform-pipelines` would have faced the same five required checks with no bypass actor. This is disclosed in ADR-019 itself as a tradeoff, not omitted, but is worth surfacing explicitly since the task's framing was specifically "no residue that could surprise anyone."

None of these affect the live-state truth checked above — the current state of the repository, verified independently in this session, shows no required-check residue, no open exercise PR, and no lingering variable.

### Human Verification Required

None. `grep -l "human-check" 22-0*-PLAN.md` returned no matches — no `<verify><human-check>` blocks were deferred to end-of-phase by any plan in this phase. Every truth above was independently confirmed either by direct file read, by independently re-running the phase's own offline assertion scripts, or by live read-only API calls against the real target repository made in this verification session (not sourced from any SUMMARY).

### Gaps Summary

No gaps found. All six derived truths verified, all live safety checks pass, the phase's own offline
assertion scripts (`22-assert-verdicts.py`) re-run cleanly independent of the SUMMARY narration, and
independent live API reads against `OttawaCloudConsulting/terraform-pipelines` — taken hours after the
phase's own final read — confirm the repository carries no required-check residue, no open exercise
PR, no exercise branch, no stray Actions variable, and an unmoved `main` HEAD. ADR-019 is honest about
its limits (explicitly disclaims evidence about the server-side merge endpoint, marks the
`require_extra_approval_for_unattributed_changes` semantics as unverified, and narrows rather than
closes ADR-017/018). Three low-impact, explicitly-disclosed irreversible residues exist (code-scanning
analyses, closed-PR history, the ~2h10m required-check exposure window) — these were already disclosed
by the phase's own record and do not represent a failure to restore; they are listed above for
completeness per the task's specific "no surprising residue" framing.

---

_Verified: 2026-09-16T23:10:00Z_
_Verifier: Claude (gsd-verifier)_
