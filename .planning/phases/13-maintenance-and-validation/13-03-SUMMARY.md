---
phase: 13-maintenance-and-validation
plan: 03
subsystem: workstation/update-primitives
tags: [bash, pipx, tdd, installer, failure-logging]

requires:
  - phase: 13-maintenance-and-validation plan 01
    provides: "sourceable setup.sh (main-guard), tests/run-tests.sh runner, test isolation contract"
  - phase: 13-maintenance-and-validation plan 02
    provides: "gh_api_get(), hardened resolve_latest_version(), resolve_latest_in_major()"
provides:
  - "pipx install --force fix — pre-commit can actually be upgraded (was a silent exit-0 no-op)"
  - "ensure_pipx returns 1 instead of exit 1 — a pipx bootstrap failure no longer aborts the whole run"
  - "PATH warning now tells the user the exact export line to add"
  - "attempt_install() — decides success solely by re-probing is_installed(), never by the installer's exit code"
  - "log_update_failure() — append-only, plain-text, credential-free failure log at $REPO_ROOT/update-failures.log"
  - "UPDATE_LOG_NAME / PROBLEM_COUNT / FALLBACK_NOTES constants for plans 04-06"
affects: ["13-04 (update command orchestrator built on attempt_install/log_update_failure)", "13-05 (doctor, reads PROBLEM_COUNT)", "13-06 (.gitignore handling for update-failures.log)"]

tech-stack:
  added: []
  patterns:
    - "attempt_install: verify-not-exit-code as the sole success signal, mirroring is_installed's role for run_installer"
    - "assignment-prefix + eval for per-call, self-restoring override of a dynamically-named version global (bash 3.2, no declare -A)"
    - "log_update_failure append-only write, deliberately diverging from write_config's exists-skip guard"

key-files:
  created: []
  modified:
    - repos/security-platform/workstation/setup.sh
    - repos/security-platform/workstation/tests/test_update_primitives.sh

key-decisions:
  - "attempt_install discards the installer's exit code entirely and returns only what is_installed reports, per the verified pipx exit-0-no-op behaviour"
  - "Version-global override uses the assignment-prefix form via eval (dynamic variable name), which self-restores after the call completes — no manual save/restore needed"
  - "log_update_failure always appends (>>), never skips on an existing file — the one place it must diverge from write_config's established pattern"
  - "_UPDATE_LOG_WARNED module-scope flag ensures the 'see update-failures.log' notice prints once per run, not once per failed tool"

requirements-completed: []

duration: ~25min
completed: 2026-09-09
---

# Phase 13 Plan 03: Update Primitives (attempt_install, log_update_failure) and Installer Bug Fixes Summary

Fixed the two installer defects that made `update` structurally impossible (pipx's silent exit-0 no-op on already-installed pre-commit, and `ensure_pipx`'s hard `exit 1` abort), then built `attempt_install()` and `log_update_failure()` — the two primitives the `update` command (plan 04) will compose into its per-tool loop — locked by 14 new TDD-driven, offline unit tests.

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-09
- **Completed:** 2026-09-09
- **Tasks:** 3 completed (task 1 plain auto-fix; tasks 2 and 3 both TDD: RED then GREEN)
- **Files modified:** 2 (both in `repos/security-platform/`)

## Accomplishments

- **Fixed `_install_precommit`:** `pipx install "pre-commit==X"` on an already-installed pre-commit exits 0 and changes nothing (verified pipx 1.10.1) — the root defect that made upgrading pre-commit, and therefore `update`, impossible. Now `pipx install --force "pre-commit==${PRECOMMIT_VERSION}"`.
- **Fixed `ensure_pipx`:** its bootstrap-failure branch called `exit 1`, which would kill the entire `update`/`install` run from inside a single installer. Changed to `return 1`, propagated by `_install_precommit` via `ensure_pipx || return 1`, so a broken pipx bootstrap is now a recorded failure like every other tool, not a process abort.
- **Fixed the PATH warning:** it told the user to "Add to your shell profile:" and then said nothing — now it prints the literal `export PATH="$INSTALL_DIR:$PATH"` line.
- **`attempt_install(tool, version, version_var_name, installer_fn_name)`:** runs the installer once at a given version and decides success **solely** by re-probing `is_installed()` afterward — the installer's own exit status is discarded on purpose (with an explanatory comment), because that exit status is the exact signal pipx lies about. The tool's version global is overridden only for the installer call's duration via the assignment-prefix form (`VAR="$version" "$installer_fn"`, driven through `eval` because the variable *name* is dynamic), which self-restores after the call — verified non-persisting under bash 3.2.57, so no manual save/restore was needed. Reproduces `run_installer`'s VERBOSE quiet/loud split and appends `|| true` to the installer invocation so a failing installer under `set -euo pipefail` cannot terminate the script.
- **`log_update_failure(tool, pinned, [fallback])`:** appends one plain-text line to `$REPO_ROOT/update-failures.log` (the user's repo, never this checkout) with a UTC timestamp, tool name, `pinned=`, `fallback=`/`fallback=(unresolved)`, and `installed=` fields. Unlike `write_config`, it always appends and never skips on an existing file. Warns the user once per run, on the first write, naming the log path. Never references `GITHUB_TOKEN_VALUE`, an `Authorization` header, or a curl command.
- **New constants:** `UPDATE_LOG_NAME="update-failures.log"`, `PROBLEM_COUNT=0` (mirrors `CONFIG_COUNT`, consumed by check/doctor in plans 04-05), `FALLBACK_NOTES=""` (consumed by the update orchestrator in plan 04).
- 14 new assertions in `tests/test_update_primitives.sh`, all offline, all install-nothing/network-nothing: `attempt_install`'s pipx-no-op regression guard (installer 0 + absent → fail) and its mirror (installer 1 + present → success), `set -e` survival, version-global override/restore, VERBOSE-gated output; `log_update_failure`'s append-not-truncate-not-skip semantics, plain-text format (no `{`, no `":"`), unresolved-fallback marker, and token/curl/Authorization absence using the literal placeholder `NOT-A-REAL-TOKEN-TEST` (per CLAUDE.md's anti-slop guidance against realistic-looking test secrets).
- Full suite: 61 passed, 0 failed, deterministic.

## Behaviour Changes to Existing Commands (flagged per plan instructions)

1. **`bash setup.sh install` now genuinely reinstalls pre-commit when the pin differs.** Previously it silently no-opped and reported "installed" success while leaving the old version in place. This is a bug fix, but it changes observable behavior of an existing, already-shipped command.
2. **A pipx bootstrap failure during `install` (or `setup`) is now a recorded failure (`FAILED`, contributes to `FAIL_COUNT`) instead of a hard process abort.** Previously one broken pipx bootstrap would `exit 1` and prevent every other tool from being installed in the same run; now the run continues and reports which tool failed.

## Task Commits

All in `repos/security-platform`:

1. **Task 1: installer bug fixes (plain auto task, no TDD gate)**
   - `75fa6b5` (fix) — `pipx install --force`, `ensure_pipx` return-not-exit, PATH warning fix

2. **Task 2: `attempt_install()` + constants (TDD)**
   - `46f7ce9` (test) — failing tests for `attempt_install` (3 assertions fail — function doesn't exist)
   - `6583354` (feat) — implementation + constants; all 3 previously-failing assertions pass, plus a test-wording fix found during GREEN verification

3. **Task 3: `log_update_failure()` (TDD)**
   - `b754139` (test) — failing tests for `log_update_failure` (6 assertions fail — function doesn't exist)
   - `3867771` (feat) — implementation; all 6 previously-failing assertions pass

**Plan metadata:** committed separately in the documentation repo (this SUMMARY.md, STATE.md, ROADMAP.md, REQUIREMENTS.md).

_Note: tasks 2 and 3 are `tdd="true"` — each has a `test(...)` commit before its `feat(...)` commit, satisfying the RED/GREEN gate sequence. Task 1 is a plain `type="auto"` task with no TDD gate, verified instead by the existing suite plus targeted greps._

## Files Created/Modified

- `repos/security-platform/workstation/setup.sh` — `ensure_pipx` returns instead of exits; `_install_precommit` uses `pipx install --force` and propagates `ensure_pipx`'s failure; PATH warning gained a second line; three new constants (`UPDATE_LOG_NAME`, `PROBLEM_COUNT`, `FALLBACK_NOTES`); two new functions (`attempt_install`, `log_update_failure`) placed in the "Tool installers" section immediately before `install_all_tools`
- `repos/security-platform/workstation/tests/test_update_primitives.sh` — new fixture-free test case file (sourced automatically by plan-01's runner glob)

## Decisions Made

- `attempt_install`'s sole return value is `is_installed "$tool" "$version"` — the installer's exit code never appears in an `if`/`&&`/`||` decision anywhere inside the function. A comment on that line cites the verified pipx exit-0-no-op behaviour so a future reader does not "fix" it back to branching on the exit code.
- Used the assignment-prefix + `eval` form (not a manual save/restore of the version global) because the plan's own research verified that form self-restores under bash 3.2.57 — simpler and less error-prone than tracking a previous value.
- `log_update_failure` deliberately does NOT copy `write_config`'s "exists, skipping" guard — this is the one required divergence from that established pattern, per D-07.
- Left `requirements-completed` empty in this summary's frontmatter, per the STATE.md blocker note carried over from plan 01: MAINT-01/02/03 span plans 13-01 through 13-07, and this plan is not the last one touching MAINT-02 (plan 04's `update` command is what actually delivers the update capability MAINT-02 describes). Did not run `requirements.mark-complete` for MAINT-02.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test file's own docstring comment defeated its sibling acceptance-criterion grep**
- **Found during:** Task 2 GREEN verification
- **Issue:** `test_update_primitives.sh`'s header comment literally said "...calls pipx, curl, or api.github.com," which made the plan's own hygiene check (`grep -rn 'pipx install\|curl -sSfL\|api.github.com' tests/` expected to return nothing) return a false positive against the test file's prose, not its code.
- **Fix:** Reworded the comment to describe the guarantee without using the literal grepped substrings.
- **Files modified:** `repos/security-platform/workstation/tests/test_update_primitives.sh`
- **Verification:** `grep -rn 'pipx install\|curl -sSfL\|api.github.com' repos/security-platform/workstation/tests/` returns nothing; full suite still passes.
- **Committed in:** `6583354` (part of the task 2 GREEN commit)

**2. [Rule 1 - Bug] A test's own VERBOSE-suppression assumption hid the marker it was trying to prove was visible**
- **Found during:** Task 2 GREEN verification
- **Issue:** The "version global visible to the installer during the attempt" test never set `VERBOSE=true`, so `attempt_install`'s own quiet-mode `> /dev/null 2>&1` redirect (working exactly as designed) swallowed the installer's `echo "SEEN:..."` marker before the test could observe it. This wasn't a bug in `attempt_install` — verified standalone in a bare bash session that the override/restore mechanism itself was already correct — it was the test asserting the wrong precondition.
- **Fix:** Added `VERBOSE=true` (with a `# shellcheck disable=SC2034` justification, since shellcheck cannot see the sourced `setup.sh` function that reads it) to that specific test subshell only, leaving the VERBOSE=false suppression tests untouched.
- **Files modified:** `repos/security-platform/workstation/tests/test_update_primitives.sh`
- **Verification:** All 3 previously-failing assertions in that describe block now pass; suite is 49 passed, 0 failed at end of task 2.
- **Committed in:** `6583354` (part of the task 2 GREEN commit)

---

**Total deviations:** 2 auto-fixed (both bugs in this plan's own new test code, not in `setup.sh`). No production-code deviations; `setup.sh` matches the plan's `<action>` sections exactly.

## Acceptance-Criteria Note (not a deviation, documented per anti-slop evidence standards)

Two of the plan's acceptance-criteria greps assume `attempt_install`/`log_update_failure` will appear **2 or more times** in non-comment lines of `setup.sh`. As implemented, each function name appears exactly **once** in non-comment code — the function definition itself (`attempt_install() {` / `log_update_failure() {`) — because no call site exists yet; the loop that calls both primitives is plan 04's `update` orchestrator, which this plan explicitly does not build. All *other* acceptance criteria for both tasks pass, including the substantive ones (sole-decision-point via `is_installed`, append-not-skip, no `GITHUB_TOKEN_VALUE`/`Authorization`/`curl` in the log, no stray log file, full suite green, `shellcheck` clean, `bash -n` clean, `check` still prints both tables). This is flagged as evidence, not silently passed over — the two grep-count criteria were written assuming a call site that a later plan introduces.

## Known Stubs

None.

## Threat Flags

None — this plan's threat register (`T-13-02`, `T-13-03`, `T-13-06`, `T-13-12`, `T-13-13`, `T-13-14`, `T-13-SC`) fully covers the new surface (`attempt_install`, `log_update_failure`, the pipx `--force` reinstall, the return-not-exit change). No new network endpoints, auth paths, or schema changes were introduced; `attempt_install` invokes only the existing `_install_*` functions, inheriting their existing `verify_sha256` checks.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `attempt_install()` and `log_update_failure()` are ready for plan 13-04's `update` command to compose into its per-tool loop, per the plan's stated purpose.
- `PROBLEM_COUNT` and `FALLBACK_NOTES` are declared and initialised but not yet incremented/populated anywhere — that wiring is explicitly plans 04/05's job, not this plan's, per the planner's own decision note.
- `update-failures.log`'s `.gitignore` handling is explicitly deferred to plan 06, per Open Q4.
- No blockers for 13-04 through 13-07.

## Self-Check: PASSED

- FOUND: repos/security-platform/workstation/setup.sh (modified — attempt_install, log_update_failure, 3 new constants, pipx/ensure_pipx/PATH fixes present)
- FOUND: repos/security-platform/workstation/tests/test_update_primitives.sh
- FOUND commit 75fa6b5 (fix(13-03): fix pipx no-op upgrade, pipx bootstrap abort, and PATH warning) in repos/security-platform
- FOUND commit 46f7ce9 (test(13-03): add failing tests for attempt_install()) in repos/security-platform
- FOUND commit 6583354 (feat(13-03): add attempt_install() and update constants) in repos/security-platform
- FOUND commit b754139 (test(13-03): add failing tests for log_update_failure()) in repos/security-platform
- FOUND commit 3867771 (feat(13-03): add log_update_failure() writing the plain-text failure log) in repos/security-platform

---
*Phase: 13-maintenance-and-validation*
*Completed: 2026-09-09*
