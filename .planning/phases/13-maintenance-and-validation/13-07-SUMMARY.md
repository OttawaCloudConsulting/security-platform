---
phase: 13-maintenance-and-validation
plan: 07
subsystem: testing
tags: [bash, pipx, pre-commit, phase-gate, human-verify]

requires:
  - phase: 13-maintenance-and-validation (plans 01-06)
    provides: update/doctor subcommands, GitHub API layer, install/update primitives, docs
provides:
  - Human-witnessed proof that `pipx install --force` genuinely changes an already-installed
    pre-commit's version, in both directions, confirmed independently via `pipx list`
  - Confirmation that `doctor` reports a real six-tool environment correctly and degrades
    gracefully (printed report, exit=1) on a scrubbed PATH
affects: []

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - repos/security-platform/versions.conf (temporarily edited, restored via git checkout — no
      net change)

key-decisions:
  - "Treated the step 4/7 exit=1 divergence as a known, pre-existing cause (5 unrelated stale
    version pins) rather than a real implementation defect, per advisor consultation — the
    plan's own must_haves.truths never require exit=0, and 13-05's exit-code contract (nonzero on
    any MISMATCH) was already a settled decision. Did not touch check's exit-code contract or the
    machine's stale pins to force a green result."

patterns-established: []

requirements-completed: [MAINT-02, MAINT-03]

duration: ~25min
completed: 2026-09-09
---

# Phase 13: Maintenance and Validation Summary

**Human-witnessed pre-commit downgrade/upgrade round trip via `pipx install --force`, plus doctor sanity on healthy and scrubbed PATH — closing the one claim the offline test suite structurally cannot prove.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-09-09
- **Tasks:** 2/2 (1 automated baseline, 1 human-verify checkpoint)
- **Files modified:** 0 net (versions.conf temporarily edited, restored)

## Accomplishments
- Automated pre-checkpoint baseline recorded: `bash -n` clean, `shellcheck` clean, 143/143 tests
  passing, `doctor` exit=0 with all six tools OK, `--help` lists both `update` and `doctor`.
- Human verified `update pre-commit` genuinely moves the installed version **backwards**
  (4.5.1 → 4.5.0) and **forwards** again (4.5.0 → 4.5.1), each time independently confirmed by
  `pipx list`, not only by the script's own summary/check table.
- `doctor` confirmed accurate on a healthy six-tool machine (exit=0, all OK) and confirmed to
  degrade gracefully — printed report, `NOT_ON_PATH` for all six, exit=1 — on a scrubbed PATH
  rather than aborting.
- `versions.conf` restored to its exact original committed state; no `update-failures.log` left
  anywhere.

## Task Commits

Task 1 (automated baseline) and Task 2 (human-verify) made no source commits — `files_modified: []`
per plan frontmatter. `versions.conf` was edited as a temporary test fixture and restored via
`git -C repos/security-platform checkout -- versions.conf` (confirmed byte-identical via
`git status --porcelain` returning empty both mid-exercise and at the end).

**Plan metadata:** commit created alongside this SUMMARY.md in the documentation repo.

## Observed Results (verbatim, per plan's `<output>` requirement)

| Step | Command | Observed |
|------|---------|----------|
| 1 | `pipx list \| grep pre-commit` (start) | `pre-commit 4.5.1` |
| 1 | `grep PRECOMMIT_VERSION versions.conf` (start) | `4.5.1` |
| 2 | edit pin | `4.5.1` → `4.5.0` |
| 3 | `update pre-commit` (downgrade) | summary row `pre-commit 4.5.0 installed` |
| 4 | `check`, exit code | table shows `pre-commit 4.5.0/4.5.0 ok`; **exit=1** (see divergence below) |
| 5 | `pipx list` (independent witness) | `pre-commit 4.5.0` — matches step 4 table |
| 6 | `git checkout -- versions.conf` | pin restored to `4.5.1`, confirmed via grep |
| 7 | `update pre-commit` + `check` (upgrade) | summary row `pre-commit 4.5.1 installed`; table shows `4.5.1/4.5.1 ok`; **exit=1** (same divergence) |
| 7 | `pipx list` (independent witness) | `pre-commit 4.5.1` — matches step 7 table |
| 8 | `git status --porcelain` | empty (clean) |
| 8 | `find . -name update-failures.log` | empty (none found) |
| 9 | `doctor` (healthy) | all six tools `OK` with versions; `~/.local/bin` on PATH; exit=0 |
| 10 | `doctor` (scrubbed `PATH=/usr/bin:/bin`) | printed report, all six `NOT_ON_PATH`, PATH warning printed; exit=1 |
| 11 | (optional deliberate-failure path) | **skipped** — user did not request it |

## Files Created/Modified
- `repos/security-platform/versions.conf` — temporarily edited (`PRECOMMIT_VERSION` 4.5.1→4.5.0→4.5.1), restored via `git checkout`, net diff none

## Decisions Made
- **Exit-code divergence at steps 4 and 7:** plan text says "Expect: ... exit=0" for `check` after
  each round-trip leg. Actual observed exit was `1` both times. Root cause identified and confirmed
  identical at both observations: this machine's `versions.conf` has 5 pre-existing stale pins
  (trivy, syft, grype, gitleaks, hadolint — all MISMATCH, present identically in the Task 1
  baseline before any mutation occurred). `check`'s exit-code contract (nonzero on any MISMATCH row)
  was established and tested in plan 05; it is working exactly as designed. Pre-commit's own row
  was `ok` at both observations, and the MISMATCH set was byte-for-byte identical to baseline both
  times — the discriminating check the advisor specified for "known-cause vs. real divergence"
  passed. Consulted advisor before proceeding past this point; did not modify `check`'s exit
  contract or the machine's other tool pins to force a green result — both would be out-of-scope
  patches bolted onto a checkpoint, which the plan's own constraints forbid.
- User approved the gate with this divergence explicitly recorded (not silently passed over).

## Deviations from Plan

None requiring code changes. One recorded environmental divergence from the plan's literal
acceptance criteria (`exit=0` expected at steps 4/7, `exit=1` observed) — documented above with
root cause, not treated as a code defect, and not silently resolved.

**Total deviations:** 0 auto-fixed. 1 recorded environmental divergence (exit code only, root cause explained and reproducible).
**Impact on plan:** None on scope — the substantive claim under test (pre-commit's installed version genuinely changes in both directions, witnessed by an independent tool) passed cleanly at every step.

## Issues Encountered
Exit-code divergence at steps 4/7, described above. Resolved by root-causing to pre-existing unrelated tool drift rather than a defect in this phase's work, verified via the discriminating check (identical MISMATCH set at both observations), and confirmed with the user before closing the gate.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 13 (maintenance-and-validation) is now fully executed: sourceable `setup.sh` with a plain-bash
  test harness, a hardened GitHub API layer, fixed install primitives, a working `update` subcommand
  with two-attempt fallback, a `doctor` subcommand, documentation for both, and now a human-witnessed
  real-machine proof of the `update` round trip.
- MAINT-01 already marked complete (plan 06). MAINT-02 and MAINT-03 marked complete by this plan —
  it is their last-touching plan per each requirement's frontmatter.
- No blockers for phase completion / verification.

---
*Phase: 13-maintenance-and-validation*
*Completed: 2026-09-09*
