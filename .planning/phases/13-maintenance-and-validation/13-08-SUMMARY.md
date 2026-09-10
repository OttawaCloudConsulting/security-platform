---
phase: 13-maintenance-and-validation
plan: 08
subsystem: testing
tags: [bash, setup.sh, path-warning, gap-closure, tdd]

# Dependency graph
requires:
  - phase: 13-maintenance-and-validation (plans 01-07)
    provides: setup.sh install/update/doctor/check subcommands and the plain-bash test harness (tests/run-tests.sh)
provides:
  - install_all_tools and update_all_tools now snapshot $PATH before exporting INSTALL_DIR onto it, so the "add this to your PATH" warning can actually fire
  - tests/test_path_warning.sh — 4 new assertions proving the warning fires/stays-silent for both functions
affects: [13-maintenance-and-validation (VERIFICATION.md, REVIEW.md WR-01 closure)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Snapshot-before-mutate: capture $PATH into a local var before exporting onto it, then test the snapshot — mirrors the pattern run_doctor already used by never exporting PATH at all"

key-files:
  created:
    - repos/security-platform/workstation/tests/test_path_warning.sh
  modified:
    - repos/security-platform/workstation/setup.sh

key-decisions:
  - "Inlined the two-line snapshot fix identically in both functions rather than extracting a shared helper, per plan scope constraint (two call sites, gap-closure scope)"
  - "install_all_tools tests also required the six pinned *_VERSION vars set (not just update_all_tools tests) because install_all_tools dereferences them directly as run_installer arguments, evaluated before the stub call runs, under inherited set -u — the plan's interface note said this preamble was unnecessary for install tests; empirically it was required (Rule 3 blocking-issue fix)"

patterns-established:
  - "Snapshot-before-mutate for PATH checks in setup.sh"

requirements-completed: [MAINT-02]

# Metrics
duration: 20min
completed: 2026-09-10
---

# Phase 13 Plan 08: PATH Warning Gap Closure Summary

**Fixed dead PATH-missing warning in install_all_tools/update_all_tools by snapshotting `$PATH` before exporting `$INSTALL_DIR` onto it, closing REVIEW.md WR-01 with 4 new TDD-proven assertions (147/147 suite passing).**

## Performance

- **Duration:** ~20 min
- **Tasks:** 2 completed
- **Files modified:** 2 (1 new test file, 1 modified script)

## Accomplishments
- Wrote 4 new behavioral assertions (`tests/test_path_warning.sh`) proving the "add this to your PATH" warning was unreachable pre-fix for both `install_all_tools` and `update_all_tools` (RED: 145 passed, 2 failed)
- Fixed `setup.sh` by snapshotting `$PATH` into `local orig_path` before the `export PATH="$INSTALL_DIR:$PATH"` line in both functions, and testing `orig_path` in the membership check instead of the post-export `$PATH` (GREEN: 147 passed, 0 failed)
- Confirmed `run_doctor` and the `check)` dispatcher branch were untouched (grep verified only 2 `local orig_path=` sites, both inside the two in-scope functions)

## Task Commits

Each task was committed atomically in `repos/security-platform`:

1. **Task 1: Write failing tests proving the PATH warning is unreachable** - `3c0e94c` (test)
2. **Task 2: Snapshot PATH before export in both functions; make tests pass** - `3d3ceda` (fix)

_TDD plan: RED (`3c0e94c`) then GREEN (`3d3ceda`); no REFACTOR commit needed — the fix was already minimal._

## Files Created/Modified
- `repos/security-platform/workstation/tests/test_path_warning.sh` - 4 new assertions (install/update x warns-when-absent/silent-when-present)
- `repos/security-platform/workstation/setup.sh` - `local orig_path="$PATH"` snapshot + `case ":$orig_path:" in` in `install_all_tools` (lines 839, 851) and `update_all_tools` (lines 871, 899)

## Decisions Made
- Inlined the fix identically at both call sites rather than extracting a shared helper (plan explicitly scoped this as a two-site inline fix, not a refactor)
- Extended the version-var preamble (all six pinned `*_VERSION` vars) to the install-path test subshells too, not just the update-path ones — required because `install_all_tools` evaluates `$PRECOMMIT_VERSION` etc. as `run_installer` arguments before the stub function body ever runs, and those vars are unbound under `set -u` in a bare sourced subshell

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] install_all_tools tests needed the six-version-var preamble too**
- **Found during:** Task 2 (making Task 1's tests pass)
- **Issue:** The plan's `<interfaces>` block stated "install_all_tools does not dereference the six version vars via a records array... so no additional version-var preamble is required for Tests 1-2." Running the RED-step tests before the fix appeared to pass this claim, but after applying the fix, Test 1 still failed — not on the PATH assertion, but with `setup.sh: line 844: PRECOMMIT_VERSION: unbound variable`. `install_all_tools` calls `run_installer "pre-commit" "$PRECOMMIT_VERSION" _install_precommit` — bash evaluates `$PRECOMMIT_VERSION` as an argument expression before `run_installer` (even when stubbed to a no-op) is invoked, so the stub cannot shield the caller from an unset var under inherited `set -u`.
- **Fix:** Added the same six-var preamble (`PRECOMMIT_VERSION`, `TRIVY_VERSION`, `SYFT_VERSION`, `GRYPE_VERSION`, `GITLEAKS_VERSION`, `HADOLINT_VERSION`, each with a matching `# shellcheck disable=SC2034` comment) to both install-path test subshells (Tests 1 and 2), matching the pattern already required for the update-path tests (Tests 3 and 4).
- **Files modified:** `repos/security-platform/workstation/tests/test_path_warning.sh`
- **Verification:** `bash tests/run-tests.sh` went from 146 passed/1 failed to 147 passed/0 failed after the fix; `shellcheck tests/test_path_warning.sh` clean (exit 0)
- **Committed in:** `3d3ceda` (part of Task 2 commit, since the RED commit in Task 1 already contained the (then-incomplete) test file and Task 2 is where the file was corrected to reach GREEN)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary correction to reach the plan's own stated GREEN target (147/147); no scope creep — still exactly the 4 assertions across the 2 functions the plan specified.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- REVIEW.md WR-01 is closed; the "PATH lacks the install dir" truth now holds for `install`, `setup`, and `update` (previously only `doctor` implemented this correctly)
- WR-02 (`run_installer` trusting installer exit code) and WR-03 (unpinned `curl | sh` installs for Trivy/Syft/Grype) remain open, explicitly out of scope per this plan's objective
- Full test suite: 147/147 passing, exit 0

## Self-Check: PASSED
- FOUND: repos/security-platform/workstation/tests/test_path_warning.sh
- FOUND: repos/security-platform/workstation/setup.sh
- FOUND: .planning/phases/13-maintenance-and-validation/13-08-SUMMARY.md
- FOUND: commit 3c0e94c (test, RED)
- FOUND: commit 3d3ceda (fix, GREEN)
