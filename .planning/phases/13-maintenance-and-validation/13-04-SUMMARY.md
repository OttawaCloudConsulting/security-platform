---
phase: 13-maintenance-and-validation
plan: 04
subsystem: workstation/update-command
tags: [bash, tdd, installer, update, fallback, dispatcher]

requires:
  - phase: 13-maintenance-and-validation plan 01
    provides: "sourceable setup.sh (main-guard), tests/run-tests.sh runner, test isolation contract"
  - phase: 13-maintenance-and-validation plan 02
    provides: "resolve_latest_in_major() for same-major fallback resolution"
  - phase: 13-maintenance-and-validation plan 03
    provides: "attempt_install(), log_update_failure(), pipx --force fix, ensure_pipx return-not-exit"
provides:
  - "update_one_tool() — per-tool two-attempt sequence (exact pin, then same-major fallback, then give up)"
  - "update_all_tools() — loops all six tools (or a UPDATE_TARGETS subset) through update_one_tool, continue-on-failure"
  - "bash setup.sh update [tool] — first-class subcommand, documented in usage() and the file header"
  - "print_summary(noun, verb) — parameterized so update/install/setup share one summary implementation"
  - "print_fallback_notes() — explains post-update MISMATCH rows caused by an accepted same-major fallback"
affects: ["13-05 (doctor reads PROBLEM_COUNT from run_check, must not let update)'s omission of that mapping regress)", "13-06 (.gitignore handling for update-failures.log)"]

tech-stack:
  added: []
  patterns:
    - "Three guards (empty/identical/downgrade) converge into a single give-up path so FAIL_COUNT increments and the FAILED result are recorded exactly once, never duplicated per guard"
    - "attempt_install stubbed directly (not the real _install_* functions) as the network boundary in update_all_tools tests — cleanest boundary since it's already unit-tested in plan 03"
    - "5-field flat record array + IFS=':' read -r herestring split, bash 3.2-safe, no declare -A"

key-files:
  created: []
  modified:
    - repos/security-platform/workstation/setup.sh
    - repos/security-platform/workstation/tests/test_update_fallback.sh

key-decisions:
  - "A successful attempt-2 fallback is reported as a distinct 'fallback' status: does not increment FAIL_COUNT, does not rewrite versions.conf. FALLBACK_NOTES accumulates a NOTE printed after the post-update run_check so the resulting MISMATCH row is self-explanatory."
  - "Downgrade guard (T-13-04): a resolved fallback is only installed when it sorts >= the pin via numeric field sort (sort -t. -k1,1n -k2,2n -k3,3n), never lexical comparison. A downgrading fallback is refused and the tool is FAILED."
  - "Selective per-tool update via bash setup.sh update <tool> — costs one API call instead of six against the 60/hr budget on a retry."
  - "update)'s dispatcher branch deliberately does not map the future PROBLEM_COUNT (plan 05) into FAIL_COUNT — mapping it would flip a successful fallback update to a non-zero exit. Commented in place so a future reader does not 'fix' it."
  - "print_summary gained optional noun/verb args defaulting to the original 'Installation'/'install' wording rather than a second parallel summary function, per the plan's explicit reuse requirement."

requirements-completed: []

duration: ~40min
completed: 2026-09-09
---

# Phase 13 Plan 04: The `update` Subcommand (Two-Attempt Fallback, Continue-on-Failure) Summary

Built `bash setup.sh update [tool]` — the largest net-new capability in Phase 13 — by composing the primitives from plans 02-03 (`resolve_latest_in_major`, `attempt_install`, `log_update_failure`) into a per-tool two-attempt state machine (`update_one_tool`) and a continue-on-failure loop (`update_all_tools`), wired into the dispatcher with selective per-tool targeting and locked by 39 new offline, stub-driven tests.

## Performance

- **Duration:** ~40 min
- **Started:** 2026-09-09
- **Completed:** 2026-09-09
- **Tasks:** 3 completed, all `tdd="true"` (RED then GREEN for each)
- **Files modified:** 2 (both in `repos/security-platform`)

## Accomplishments

- **`update_one_tool(tool, pinned, version_var, repo_var, installer_fn)`:** already-current short-circuit (mirrors `run_installer`'s L387-391 guard — a fully current machine makes zero API calls and zero installer invocations); attempt 1 at the exact pin via `attempt_install`; on failure, resolves a same-major fallback via `resolve_latest_in_major` (the only API call, only on this path); three guards (empty resolution, fallback identical to the pin, fallback below the pin) that all converge on one shared give-up path so `FAIL_COUNT` and the `FAILED` result are recorded exactly once regardless of which guard tripped; attempt 2 at the fallback; a distinct `fallback` status on success that leaves `FAIL_COUNT` untouched and never rewrites `versions.conf`; `log_update_failure` on the final give-up path only. Returns 1, never calls `exit`.
- **`update_all_tools()`:** a bash-3.2-safe 5-field record array (`tool:pinned:VERSION_VAR:REPO_VAR:installer_fn`) for all six tools, split via `IFS=':' read -r <<< "$entry"`, in the same order `install_all_tools` uses. Honors `UPDATE_TARGETS` (space-separated, word-boundary matched via `case " $UPDATE_TARGETS " in *" $tool "*)`) for `bash setup.sh update <tool>`. Exports `INSTALL_DIR` onto `PATH` for the duration of the loop (mandatory — without it every post-install `is_installed` check for tools in `~/.local/bin` fails, sending all six down the costly attempt-2 path). Calls `update_one_tool ... || true` so one tool's failure never aborts the loop under `set -e`.
- **`print_summary(noun, verb)`:** parameterized (defaults `"Installation"`/`"install"`, matching the original hardcoded wording exactly) so the update branch can pass `"Update"`/`"update"` without a second parallel summary implementation. All four existing install/setup call sites are unchanged.
- **`print_fallback_notes()`:** prints one `NOTE:` line per `FALLBACK_NOTES` entry naming the tool, installed fallback version, and pinned version, telling the user to edit `versions.conf` to adopt it deliberately. Prints nothing when empty.
- **Dispatcher wiring:** `update` added to the recognised-subcommand case; the `*)` catch-all now accepts a known tool name (`pre-commit`/`trivy`/`syft`/`grype`/`gitleaks`/`hadolint`) into `UPDATE_TARGETS` only when `COMMAND` is already `update` (order-sensitive — the tool name must follow the `update` keyword), otherwise it still errors and exits 1 naming the exact bad token. The `update)` branch resolves `REPO_ROOT` with `check`'s tolerant form (works outside a git repo too), then runs `ensure_versions_conf -> update_all_tools -> print_summary("Update","update") -> run_check -> print_fallback_notes` in that order, never calling `exit`. A comment documents that `PROBLEM_COUNT` (added in plan 05) is deliberately not mapped into `FAIL_COUNT`, since a successful fallback legitimately shows `MISMATCH` in the recheck without the run having failed.
- **Documentation:** `update [tool]` added to both the `usage()` heredoc (with its own `update <tool>` sub-entry explaining the ordering requirement) and the file-header comment block, every invocation prefixed `bash setup.sh`.
- 39 new assertions across three RED/GREEN cycles in `tests/test_update_fallback.sh` (22 for `update_one_tool`, 13 for `update_all_tools`/`print_summary`/`print_fallback_notes`, and 2 process-level cases for the dispatcher/usage), plus 13 pre-existing assertions retained from earlier drafting iterations that remained green throughout — full suite: 61 (plan 03 baseline) -> 113 passed, 0 failed.

## TDD Gate Compliance

All three tasks are `tdd="true"`. Each has a verified `test(...)` commit (RED, showing new failures) followed by a `feat(...)` commit (GREEN, showing `0 failed`):

1. `617b4a1` test (RED: 22 new failures) -> `eba0c1d` feat (GREEN: 91 passed, 0 failed)
2. `3db8ec0` test (RED: 14 new failures, includes 1 pre-existing intentional self-test failure) -> `b968987` feat (GREEN: 107 passed, 0 failed)
3. `fe1eb27` test (RED: 2 new failures, made assertion-specific per the fail-fast rule — see Deviations) -> `17eaa1e` feat (GREEN: 113 passed, 0 failed)

No RED commit showed a test passing unexpectedly before implementation once corrected (see Deviations #1 below for the one case that needed a fix during RED authoring, caught before the RED commit landed).

## Task Commits

All in `repos/security-platform`:

1. **Task 1: `update_one_tool()` (TDD)**
   - `617b4a1` (test) — 22 failing offline assertions for the two-attempt sequence
   - `eba0c1d` (feat) — implementation; all 22 previously-failing assertions pass (91 passed, 0 failed)

2. **Task 2: `update_all_tools()` + update-aware summary (TDD)**
   - `3db8ec0` (test) — 14 failing offline assertions (all-six order, selective targeting, continue-on-failure, PATH export, `print_summary` noun/verb, `print_fallback_notes`)
   - `b968987` (feat) — implementation; all previously-failing assertions pass (107 passed, 0 failed)

3. **Task 3: dispatcher, usage, argument parsing (TDD)**
   - `fe1eb27` (test) — 2 failing process-level assertions (`--help` lists `update`; `update bogus-tool` reports the exact bad token)
   - `17eaa1e` (feat) — implementation; all previously-failing assertions pass (113 passed, 0 failed)

**Plan metadata:** committed separately in the documentation repo (this SUMMARY.md, STATE.md, ROADMAP.md, REQUIREMENTS.md).

## Files Created/Modified

- `repos/security-platform/workstation/setup.sh` — added `UPDATE_TARGETS=""` constant; `update_one_tool()`, `update_all_tools()`, `print_fallback_notes()`; parameterized `print_summary(noun, verb)`; extended `main()`'s argument parser (`update` recognised, tool names accepted only after `update`) and the `case "$COMMAND"` dispatcher (`update)` branch); extended `usage()` and the file-header comment block
- `repos/security-platform/workstation/tests/test_update_fallback.sh` — new fixture-free test case file (sourced automatically by plan-01's runner glob), 39 new assertions across the three RED/GREEN cycles

## Decisions Made

- Guard convergence: rather than incrementing `FAIL_COUNT`/writing `add_result ... FAILED` separately in each of the three pre-attempt-2 guards (empty fallback, identical-to-pin, downgrade), all three set a local `attempt2_ok=false` flag and fall through to one shared give-up block. This was required by the plan's own acceptance criterion ("`FAIL_COUNT=$((FAIL_COUNT + 1))` appears exactly once... in the same branch as `add_result ... FAILED`") and is also just correct: three failure reasons should produce one failure record, not up to three.
- `attempt_install` (not the real `_install_*` functions) is the stubbed network boundary in every `update_all_tools` test, per the risk the planner flagged: the record array hardcodes real installer function names, and stubbing at the `attempt_install` layer (already unit-tested in plan 03) guarantees zero curl/pipx/network calls regardless of what the array contains.
- All six `*_VERSION` globals are set explicitly inside `update_all_tools` test subshells rather than relaxing `set -u`, since sourcing `setup.sh` does not source a real `versions.conf` and the inherited `set -euo pipefail` would otherwise kill the subshell on the record array's first reference.
- Did not run `requirements.mark-complete` for MAINT-02. Checked `.planning/phases/13-maintenance-and-validation/13-0[5-7]-PLAN.md` and confirmed 13-06 and 13-07 also list MAINT-02 in their frontmatter — per the STATE.md blocker note carried from plan 01, only the last plan touching a requirement marks it complete.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rate-limit warning wording mismatch caught by the plan's own test**
- **Found during:** Task 1 GREEN verification
- **Issue:** The empty-fallback-resolution warning used the phrase "GitHub rate-limited" (matching `resolve_latest_in_major`'s own internal wording), but the test asserted the substring "rate limit" (with a space), which "rate-limited" does not contain.
- **Fix:** Reworded to "hitting the GitHub rate limit", satisfying both the test and the plan's acceptance criterion, and remaining consistent with `resolve_latest_in_major`'s guidance about `GITHUB_TOKEN`/`GH_TOKEN`.
- **Files modified:** `repos/security-platform/workstation/setup.sh`
- **Verification:** Full suite green (91 passed, 0 failed at end of task 1).
- **Committed in:** `eba0c1d` (part of the task 1 GREEN commit)

**2. [Rule 1 - Bug] Task 1's first draft violated its own acceptance criterion on FAIL_COUNT uniqueness**
- **Found during:** Task 1 GREEN verification, before committing
- **Issue:** The first implementation increment placed a separate `add_result ... FAILED` / `FAIL_COUNT=$((FAIL_COUNT + 1))` / `log_update_failure` triple in each of the three pre-attempt-2 guard branches (empty fallback, identical-to-pin, downgrade), duplicating the give-up logic three times instead of the single occurrence the plan's acceptance criteria require.
- **Fix:** Restructured with an `attempt2_ok` flag so all three guards fall through to one shared give-up block at the end of the function, matching the plan's literal acceptance criterion and its D-04/D-08 intent.
- **Files modified:** `repos/security-platform/workstation/setup.sh`
- **Verification:** `awk '/^update_one_tool\(\) \{/,/^\}/' setup.sh | grep -c 'FAIL_COUNT=\$((FAIL_COUNT + 1))'` returns 1; full suite still green.
- **Committed in:** `eba0c1d` (this was resolved before the GREEN commit, so the committed code already reflects the fix — no separate commit needed)

**3. [Rule 1 - Bug] Task 3's RED test needed a fail-fast-safe assertion, caught before the RED commit landed**
- **Found during:** Task 3 RED authoring
- **Issue:** An assertion asserting only `assert_status 1` plus a generic "Unknown argument" substring on `update bogus-tool` would have passed pre-implementation, since `update` (unrecognised as of task 2's end state) itself triggers "Unknown argument: update" and exit 1 — a false-green RED phase that the plan's own fail-fast rule (a test passing unexpectedly during RED signals a bad test, not a working feature) explicitly warns against.
- **Fix:** Asserted the exact string `"Unknown argument: bogus-tool"` (the plan's own acceptance-criterion wording), which does correctly fail before task 3's implementation (message says `update`, not `bogus-tool`) and pass after.
- **Files modified:** `repos/security-platform/workstation/tests/test_update_fallback.sh`
- **Verification:** RED run showed 2 new failures (not 0); GREEN run showed 0.
- **Committed in:** `fe1eb27` (RED commit already reflects the corrected assertion)

**4. [Rule 1 - Bug] Nested `case`/`esac` inside a `$( ( ... ) )` subshell broke the bash parser (recurrence of a plan-02 pitfall)**
- **Found during:** Task 2 RED authoring, before the RED commit
- **Issue:** A `case ":$PATH:" in *":$INSTALL_DIR:"*) ... ;; *) ... ;; esac` block written inside a `$( ( ... ) )` nested command substitution produced `unexpected token \`;;'`, the same paren-counting confusion documented in plan 02's SUMMARY.
- **Fix:** Replaced with an `if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then ... else ... fi` test, avoiding `case`/`esac` inside the subshell entirely (top-level `case` blocks outside a `$( )` context are unaffected).
- **Files modified:** `repos/security-platform/workstation/tests/test_update_fallback.sh`
- **Verification:** `bash -n` and full suite pass.
- **Committed in:** `3db8ec0` (part of the task 2 RED commit — fixed before it landed)

---

**Total deviations:** 4 auto-fixed (2 bugs in this plan's own new test code, 2 correctness bugs caught during GREEN verification before their respective commits landed). No deviation shipped in a "fix-it-later" state; every fix is already reflected in the commit it's attributed to. No scope creep — all fixes were required for the plan's own stated acceptance criteria to hold.

## Known Stubs

None. `update_one_tool`/`update_all_tools` have real call sites now (the `update)` dispatcher branch), closing the gap plan 03's SUMMARY explicitly flagged ("no call sites yet").

## Threat Flags

None — this plan's threat register (`T-13-01`, `T-13-02`, `T-13-04`, `T-13-05`, `T-13-12`, `T-13-15`, `T-13-16`, `T-13-17`, `T-13-SC`) fully covers the new surface (`update_one_tool`, `update_all_tools`, the `update` dispatcher branch, `UPDATE_TARGETS` argv handling). No new network endpoints, auth paths, or schema changes were introduced; `update_one_tool` installs only through the existing `_install_*` functions via `attempt_install`, inheriting their existing `verify_sha256` checks, and the downgrade guard (T-13-04) is covered by a dedicated pin-`0.69.3`/fallback-`0.68.9` test.

## User Setup Required

None — no external service configuration required. (Optional: `GITHUB_TOKEN`/`GH_TOKEN` raises the unauthenticated 60/hr GitHub API rate limit to 5000/hr for the fallback-resolution path, as before.)

## Next Phase Readiness

- `update_one_tool()` and `update_all_tools()` are fully wired and tested; no dangling primitives remain from plan 03.
- `PROBLEM_COUNT` is still declared but not yet populated anywhere — plan 05's `doctor`/hardened `run_check` job, per the planner's dependency note. The `update)` branch's comment explicitly warns against mapping it into `FAIL_COUNT`.
- `update-failures.log`'s `.gitignore` handling remains deferred to plan 06 (Open Q4, unchanged from plan 03).
- No blockers for 13-05 through 13-07.

## Self-Check: PASSED

- FOUND: repos/security-platform/workstation/setup.sh (modified — `update_one_tool`, `update_all_tools`, `print_fallback_notes`, parameterized `print_summary`, dispatcher `update)` branch, `usage()`/header updates, `UPDATE_TARGETS` constant)
- FOUND: repos/security-platform/workstation/tests/test_update_fallback.sh
- FOUND commit 617b4a1 (test(13-04): add failing tests for update_one_tool()) in repos/security-platform
- FOUND commit eba0c1d (feat(13-04): add update_one_tool() with two-attempt fallback sequence) in repos/security-platform
- FOUND commit 3db8ec0 (test(13-04): add failing tests for update_all_tools() and update-aware summary) in repos/security-platform
- FOUND commit b968987 (feat(13-04): add update_all_tools() and update-aware summary output) in repos/security-platform
- FOUND commit fe1eb27 (test(13-04): add failing process-level tests for the update dispatcher) in repos/security-platform
- FOUND commit 17eaa1e (feat(13-04): wire the update subcommand into the dispatcher and usage) in repos/security-platform

---
*Phase: 13-maintenance-and-validation*
*Completed: 2026-09-09*
