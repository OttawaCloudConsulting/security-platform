---
phase: 13-maintenance-and-validation
plan: 05
subsystem: workstation/doctor-command
tags: [bash, tdd, installer, doctor, health-check, exit-codes]

requires:
  - phase: 13-maintenance-and-validation plan 01
    provides: "sourceable setup.sh (main-guard), tests/run-tests.sh runner, test isolation contract"
  - phase: 13-maintenance-and-validation plan 03
    provides: "PROBLEM_COUNT constant declared (unpopulated)"
  - phase: 13-maintenance-and-validation plan 04
    provides: "update dispatcher branch and its deliberate non-mapping of PROBLEM_COUNT into FAIL_COUNT"
provides:
  - "tool_health(tool) — pipe-delimited STATUS|DETAIL|VALUE record distinguishing NOT_ON_PATH/BROKEN/UNPARSEABLE/OK by capturing the version command's own exit status"
  - "run_doctor() — offline health-check table (tool health, PATH health, prerequisites) with zero network calls"
  - "bash setup.sh doctor — first-class subcommand with a real exit code, documented in usage() and the file header"
  - "PROBLEM_COUNT wired into run_check (once per MISSING/MISMATCH) and run_doctor (once per non-OK finding), mapped into FAIL_COUNT only at the check)/doctor) dispatcher branches"
  - "check now exports INSTALL_DIR onto PATH and exits non-zero on MISSING/MISMATCH (behaviour change to an existing command)"
affects: ["13-06 (.gitignore/documentation follow-up)", "13-07 (final validation pass covering MAINT-01/02/03)"]

tech-stack:
  added: []
  patterns:
    - "tool_health() captures a version command's exit status via if/else around the substitution (never a set +e/set -e bracket), mirroring ensure_pipx's existing set -e-safe idiom, then parses afterward with head/grep guarded by || — the anti-pattern get_installed_version's || true collapses is exactly what this function exists to avoid"
    - "PROBLEM_COUNT is incremented inside run_check/run_doctor but never mapped into FAIL_COUNT there — the dispatcher (check)/doctor) branches only) decides whether to map it, which is what keeps update's post-recheck from flipping a successful fallback into a failed run"
    - "doctor deliberately never exports INSTALL_DIR onto PATH (unlike check, which now does) — doctor answers 'does my environment work' using the user's real PATH; exporting would mask the exact failure MAINT-03 exists to detect"

key-files:
  created: []
  modified:
    - repos/security-platform/workstation/setup.sh
    - repos/security-platform/workstation/tests/test_doctor.sh

key-decisions:
  - "doctor is a distinct subcommand with its own status vocabulary (NOT_ON_PATH/BROKEN/UNPARSEABLE/OK), not a column bolted onto check's table (MISSING/ok/MISMATCH) — get_installed_version's `|| true` structurally cannot answer MAINT-03's exit-status question."
  - "check_prerequisites is skipped only for doctor (guarded by `if [[ \"$COMMAND\" != \"doctor\" ]]`); doctor reports prerequisite status in its own table instead of hard-exiting before printing anything."
  - "check) now exports INSTALL_DIR onto PATH before run_check, matching what update's post-run recheck already does on the same machine (Pitfall 5). doctor) deliberately does not, and run_doctor's own comment says so explicitly so a future reader does not 'fix' it."
  - "gitleaks's tool_health probe test used a /bin/bash symlink (not a chmod'd custom script, which the plan forbids for test stubs): `bash version` fails (treats 'version' as a script filename) while `bash --version` succeeds, inverting real gitleaks's behaviour in a way that still proves the correct arg ('version', not '--version') is used — a regression to '--version' would flip the stub's expected BROKEN result to OK."
  - "Did not run requirements.mark-complete for MAINT-01 or MAINT-03 despite both being listed in this plan's frontmatter — 13-06-PLAN.md and 13-07-PLAN.md both still list MAINT-01/03 (MAINT-03 in particular), so per the plan-04-established convention only the last plan touching a requirement marks it complete."

requirements-completed: []

duration: ~35min
completed: 2026-09-09
---

# Phase 13 Plan 05: The `doctor` Subcommand and the check/doctor Exit-Code Contract Summary

Added `bash setup.sh doctor` — a fully offline health check that distinguishes "absent", "present but broken", "present but unparseable", and "healthy" tools by capturing each version command's own exit status (something `get_installed_version`'s `|| true` structurally cannot do) — and settled the exit-code contract so `check` and `doctor` both exit non-zero on real problems while `update`'s post-recheck exit status stays unaffected by what it finds.

## Performance

- **Duration:** ~35 min
- **Started:** 2026-09-09
- **Completed:** 2026-09-09
- **Tasks:** 3 completed, all `tdd="true"` (one combined RED test file, then one GREEN implementation commit covering all three tasks' behavior)
- **Files modified:** 2 (both in `repos/security-platform`)

## Accomplishments

- **`tool_health(tool)`:** echoes a single `STATUS|DETAIL|VALUE` record. Probes with `command -v` first (`NOT_ON_PATH` if absent), then runs the version command via an `if out="$(...)"; then rc=0; else rc=$?; fi` capture (the codebase's existing `ensure_pipx`-style `set -e`-safe idiom, never a `set +e`/`set -e` bracket) so the captured exit status is the tool's own, taken *before* any pipe into `head`/`grep`. Non-zero exit -> `BROKEN` carrying the exit code and a sanitised, truncated first line of output. Zero exit but no parseable `N.N.N` -> `UNPARSEABLE` carrying the raw first line. Otherwise -> `OK` carrying the parsed version. Reproduces the `gitleaks version` (not `--version`) special case. Does not fork `is_installed`/`get_installed_version`, which remain byte-for-byte unchanged from their plan-04 state.
- **`run_doctor()`:** three sections — a per-tool health table (hardcoded six tool names, never calls `ensure_versions_conf`, which would fire six GitHub API calls when `versions.conf` is absent), a PATH-health section (reports whether `$INSTALL_DIR` exists and is on `PATH`, deliberately without exporting it there), and a prerequisites section (`git`/`curl`/`python3`, reported rather than gating). Increments `PROBLEM_COUNT` once per non-OK finding across all three sections; never touches `FAIL_COUNT`.
- **`PROBLEM_COUNT` wiring:** `run_check` now increments it once per `MISSING`/`MISMATCH` row (its printed table format is otherwise unchanged). Both `run_check` and `run_doctor` leave `FAIL_COUNT` untouched — only the `check)` and `doctor)` dispatcher branches map `PROBLEM_COUNT` into `FAIL_COUNT` (`FAIL_COUNT=$((FAIL_COUNT + PROBLEM_COUNT))`, appearing in exactly those two places). This is what keeps `update`'s post-update recheck (which also calls `run_check`) from flipping a successful same-major fallback into a failed run.
- **Dispatcher wiring:** `doctor` recognised as a subcommand; `check_prerequisites` is now called conditionally (`if [[ "$COMMAND" != "doctor" ]]`) so `doctor` reports missing prerequisites in its own table instead of aborting before printing anything. New `doctor)` branch: `run_doctor` then the `PROBLEM_COUNT` mapping, no `REPO_ROOT`, no `ensure_versions_conf`, no `exit`. `check)` branch gained `export PATH="$INSTALL_DIR:$PATH"` before `run_check` (see Behaviour Changes below) and the same `PROBLEM_COUNT` mapping. `update)` branch's existing non-mapping of `PROBLEM_COUNT` (and its explanatory comment from plan 04) is unchanged.
- **Documentation:** `doctor` added to both the `usage()` heredoc `Commands:` list and the file-header comment block.
- 40 new assertions in `tests/test_doctor.sh`: 7 for `tool_health`'s four statuses (including a `set -euo pipefail` survival test and an exit-code-carrying test), 6 for `run_doctor`/`run_check`'s `PROBLEM_COUNT` wiring and offline guarantee, and process-level/sourced-function tests for the dispatcher's `check_prerequisites` skip, the check/doctor/update exit contracts, `--help`, and per-tool-targeting rejection. Full suite: 113 (plan 04 baseline) -> 143 passed, 0 failed.

## Behaviour Changes to Existing Commands (flagged per plan instructions)

**`bash setup.sh check` now exports `$INSTALL_DIR` onto `PATH` before running its table, and exits non-zero when any tool is `MISSING` or `MISMATCH`.** Previously it always exited 0 regardless of findings, and looked only at whatever `PATH` the caller already had (so a user whose shell profile lacked `~/.local/bin` saw an all-`MISSING` table that nonetheless exited 0). Verified live on this machine: `versions.conf` in `repos/security-platform` pins older versions than what is actually installed (e.g. `trivy 0.69.3` pinned vs `0.74.0` installed), so `check` now legitimately exits 1 there — this is the new contract working as intended, not a regression, and was not "fixed" by editing `versions.conf` (out of this plan's scope).

## Task Commits

All in `repos/security-platform`:

1. **RED — tests for all three tasks (tool_health, run_doctor/PROBLEM_COUNT, doctor dispatcher)**
   - `27a06cf` (test) — 18 new failing assertions (17 genuine + one exit-code assertion later confirmed already covered by sibling assertions in the same block; see Deviations)

2. **GREEN — tool_health(), run_doctor(), PROBLEM_COUNT wiring, doctor dispatcher, docs**
   - `979c523` (feat) — all previously-failing assertions pass (143 passed, 0 failed)

**Plan metadata:** committed separately in the documentation repo (this SUMMARY.md, STATE.md, ROADMAP.md, REQUIREMENTS.md).

_Note: unlike plans 03/04's per-task RED/GREEN pairs, this plan's three tasks share one combined test file (`test_doctor.sh`, required by the plan's own task-3 action even though Task 1 exercises functions the file must already contain) and were driven through one combined RED commit and one combined GREEN commit. All RED/GREEN gate requirements (a `test(...)` commit before a `feat(...)` commit) are satisfied; see TDD Gate Compliance below._

## Files Created/Modified

- `repos/security-platform/workstation/setup.sh` — added `tool_health()` (Version checking section, after `get_installed_version`); added `run_doctor()` (Check command section, after `run_check`); wired `PROBLEM_COUNT` into `run_check`'s status assignment; extended `main()`'s argument parser (`doctor` recognised), made `check_prerequisites` conditional, added the `doctor)` dispatcher branch, added `export PATH`/`PROBLEM_COUNT` mapping to the `check)` branch; extended `usage()` and the file-header comment block
- `repos/security-platform/workstation/tests/test_doctor.sh` — new fixture-free test case file (sourced automatically by plan-01's runner glob), 40 assertions

## Decisions Made

See `key-decisions` in the frontmatter above (subcommand vs. column, `check_prerequisites` skip, `check`'s new PATH export, the gitleaks stub design, and the MAINT-01/03 requirement-marking deferral).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test file's own header comment defeated its sibling `chmod`/executable-bit hygiene check**
- **Found during:** RED authoring, before the RED commit
- **Issue:** `test_doctor.sh`'s own prose (explaining the zero-chmod guarantee, and a code comment justifying the gitleaks stub design) contained the literal word the plan's own acceptance criterion greps for (`grep -rn 'chmod' tests/` expected to return nothing), the same false-positive shape plan 03's SUMMARY documented for a different literal string.
- **Fix:** Reworded both comments to describe the guarantee without using the literal grepped word.
- **Files modified:** `repos/security-platform/workstation/tests/test_doctor.sh`
- **Verification:** `grep -rn 'chmod' repos/security-platform/workstation/tests/` returns nothing; `find repos/security-platform/workstation/tests -type f -perm -u+x` returns nothing.
- **Committed in:** `27a06cf` (RED commit already reflects the corrected wording)

**2. [Rule 1 - Bug] Three RED assertions passed unexpectedly before implementation (fail-fast rule)**
- **Found during:** RED authoring, before the RED commit
- **Issue:** Calling `main doctor` pre-implementation hits the existing unknown-argument catch-all (`doctor` not yet a recognised subcommand), which also exits 1 and also never reaches `check_prerequisites` — coincidentally matching three assertions' expected outcomes (`check_prerequisites` not called; doctor exits 1 with `PROBLEM_COUNT=3`; `bash setup.sh doctor` exits 1 with a broken stub) for the wrong reason. Per the plan's own fail-fast rule, a test passing unexpectedly during RED signals an insufficiently specific test, not a working feature.
- **Fix:** Added `assert_not_contains "$out" "Unknown argument"` alongside each of the affected assertions, which correctly fails pre-implementation (the catch-all *does* say "Unknown argument: doctor") and passes post-implementation.
- **Files modified:** `repos/security-platform/workstation/tests/test_doctor.sh`
- **Verification:** RED run showed 18 failures (16 originally-identified + 2 newly-added strengthened assertions, net of the one pre-existing intentional self-test failure that is not a new failure); GREEN run showed 0.
- **Committed in:** `27a06cf` (RED commit already reflects the strengthened assertions)

**3. [Rule 1 - Bug] `main()`'s explicit `exit` made an inner `echo "rc=$?"` dead code in three sourced-function tests**
- **Found during:** RED authoring, before the RED commit
- **Issue:** Three tests called `main doctor`/`main update` inside a `$( ( ... ) )` subshell and then tried to `echo "rc=$?"` on the next line *inside the same subshell* to capture the exit status. Because `main()` always ends in a literal `exit 0`/`exit 1` (not `return`), that exit terminates the enclosing subshell immediately — the inner `echo` line never executes, so the intended `rc=` marker never appears in captured output.
- **Fix:** Moved the exit-status capture to the parent shell, immediately after the `out=$(...)` assignment (`rc=$?`), and asserted with `assert_status` instead of `assert_contains "$out" "rc=..."`.
- **Files modified:** `repos/security-platform/workstation/tests/test_doctor.sh`
- **Verification:** All three tests correctly show RED before implementation and GREEN after.
- **Committed in:** `27a06cf` (RED commit already reflects the corrected pattern)

**4. [Rule 1 - Bug] Custom gitleaks/exit-code test stubs initially violated the "symlinks only" constraint**
- **Found during:** RED authoring, before the RED commit
- **Issue:** The first draft of the "gitleaks probed with `version` not `--version`" and "BROKEN record carries the tool's own exit code" tests used heredoc-written custom scripts with `chmod +x`, which this plan's constraints explicitly forbid for test stubs (`grep -rn 'chmod' tests/` and `find tests -perm -u+x` are both acceptance criteria).
- **Fix:** Replaced both with symlink-only stubs: `/usr/bin/false` for the exit-code test (asserting the record contains `1`, `/usr/bin/false`'s own exit status), and `/bin/bash` for the gitleaks test (exploiting the fact that `bash version` fails, as `version` is interpreted as a script filename, while `bash --version` succeeds — the inverse of real gitleaks's behaviour, but sufficient to prove the correct argument is used, since a regression to `--version` would flip the observed status from `BROKEN` to `OK`).
- **Files modified:** `repos/security-platform/workstation/tests/test_doctor.sh`
- **Verification:** `grep -rn 'chmod' repos/security-platform/workstation/tests/` returns nothing; both tests correctly show RED before implementation and GREEN after.
- **Committed in:** `27a06cf` (RED commit already reflects the symlink-only stubs)

---

**Total deviations:** 4 auto-fixed, all bugs in this plan's own new test code caught and corrected before the RED commit landed. No production-code deviations; `setup.sh` matches the plan's `<action>` sections. No scope creep — all fixes were required for the plan's own stated constraints and acceptance criteria to hold.

## Known Stubs

None. `tool_health()` and `run_doctor()` have a real call site (the `doctor` dispatcher branch) from the moment they're introduced.

## Threat Flags

None — this plan's threat register (`T-13-07`, `T-13-18` through `T-13-21`, `T-13-05`, `T-13-08`, `T-13-SC`) fully covers the new surface (`tool_health`, `run_doctor`, the `doctor` dispatcher branch, the `check_prerequisites` skip, `check`'s new PATH export). No new network endpoints, auth paths, or schema changes were introduced; `tool_health` executes only `--version`/`version` against whatever is already on the user's PATH, and `run_doctor` makes zero network calls (verified by a dedicated test and by a literal-absence check for `curl`/`gh_api_get` in its body).

## User Setup Required

None — no external service configuration required. Users who previously relied on `check` always exiting 0 should note the behaviour change documented above.

## Next Phase Readiness

- `doctor` and the `check`/`doctor` exit contract are fully wired and tested; no dangling primitives remain.
- `versions.conf` in `repos/security-platform` is now behind what's actually installed on this development machine (a pre-existing condition, not introduced by this plan) — `check` will report `MISMATCH`/exit 1 there until the pins are updated, which is out of this plan's scope.
- `update-failures.log`'s `.gitignore` handling remains deferred to plan 06 (unchanged from plans 03/04).
- No blockers for 13-06/13-07.

## Self-Check: PASSED

- FOUND: repos/security-platform/workstation/setup.sh (modified — `tool_health`, `run_doctor`, `PROBLEM_COUNT` wiring, `doctor` dispatcher branch, `usage()`/header updates)
- FOUND: repos/security-platform/workstation/tests/test_doctor.sh
- FOUND commit 27a06cf (test(13-05): add failing tests for tool_health(), run_doctor(), and the doctor exit contract) in repos/security-platform
- FOUND commit 979c523 (feat(13-05): add doctor subcommand, tool_health(), and the check/doctor exit contract) in repos/security-platform

---
*Phase: 13-maintenance-and-validation*
*Completed: 2026-09-09*
