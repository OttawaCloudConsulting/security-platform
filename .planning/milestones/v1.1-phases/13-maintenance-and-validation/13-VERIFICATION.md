---
phase: 13-maintenance-and-validation
verified: 2026-09-10T00:00:00Z
status: passed
score: 3/3 roadmap SCs verified; 41/41 merged plan-level truths verified (39 original + 2 from 13-08, deduplicated against truth #16)
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 38/39 plan-level truths (3/3 roadmap SCs already passed)
  gaps_closed:
    - "A user whose PATH lacks the install dir is told exactly what line to add (13-03-PLAN.md, install/update paths) — closed by 13-08"
  gaps_remaining: []
  regressions: []
---

# Phase 13: Maintenance and Validation Verification Report (Re-verification after 13-08 gap closure)

**Phase Goal:** Developer can check tool health, compare installed versions against expected
versions, and update outdated tools.
**Verified:** 2026-09-10
**Status:** passed
**Re-verification:** Yes — after gap closure (plan 13-08 closed the sole open gap from the
2026-09-09 initial verification: WR-01, the unreachable PATH-missing warning in
`install_all_tools`/`update_all_tools`)

## Goal Achievement

### Roadmap Success Criteria (the phase contract)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `check` shows table of installed vs expected, highlights mismatches, exits non-zero on any missing/mismatched tool | ✓ VERIFIED | Unchanged since prior verification. Live re-run this session: `bash setup.sh check` printed the table, 5 MISMATCH rows (trivy/syft/grype/gitleaks/hadolint) + pre-commit `ok`, **exit=1** — identical pattern to prior verification and 13-07, confirming no regression. |
| 2 | `update` upgrades outdated tools to pins, continues past failures, falls back to latest release within pinned major, logs what it couldn't fix, exits non-zero only when a tool failed both attempts | ✓ VERIFIED | Unchanged core logic. `update_all_tools` now additionally snapshots `$PATH` before export (13-08 fix) — does not touch the update/fallback/logging control flow at all (grep-confirmed: only `local orig_path="$PATH"` line added plus `case ":$orig_path:"` substitution). |
| 3 | `doctor` verifies every tool on PATH and can execute its version command, reports OK/NOT_ON_PATH/BROKEN/UNPARSEABLE plus PATH and prerequisite health, exits non-zero on any problem | ✓ VERIFIED | `run_doctor` untouched by 13-08 (confirmed: no `orig_path` occurrences outside `install_all_tools`/`update_all_tools`; `run_doctor` at setup.sh:1254 still never exports PATH). Live re-run this session: all six tools OK, PATH section correct, `exit=0`. |

**Score:** 3/3 roadmap Success Criteria VERIFIED (unchanged from prior verification; 13-08 did not
touch any SC-relevant code path outside the PATH-warning fix itself, which was never part of an SC
— it duplicated `doctor`'s already-correct MAINT-03 behavior for `install`/`update`).

### Gap Closure: 13-08 (WR-01)

The single gap from the 2026-09-09 initial verification is now closed.

| # | Truth | Status | Evidence |
|---|---|---|---|
| 16 (13-03, re-verified) | A user whose PATH lacks the install dir is told exactly what line to add, for `install`, `setup`, and `update` | ✓ VERIFIED (was ✗ FAILED) | Direct code read of `install_all_tools` (setup.sh:837-859) and `update_all_tools` (setup.sh:868-907): both now execute `local orig_path="$PATH"` immediately before `export PATH="$INSTALL_DIR:$PATH"`, and the trailing membership check is `case ":$orig_path:" in *":$INSTALL_DIR:"*)`, testing the pre-export value. This makes the warning branch reachable when `INSTALL_DIR` was genuinely absent from the invoking shell's PATH. |
| 40 (13-08, new) | A user whose PATH already includes the install dir sees no spurious PATH warning from install or update | ✓ VERIFIED | Same code read; positive-path branch of the `case` is empty (`;;`), matching pre-fix behavior for the already-on-PATH case. |
| 41 (13-08, new) | The full test suite (143 pre-existing + new PATH-warning tests) passes | ✓ VERIFIED | Live run this session: `bash tests/run-tests.sh` → `Results: 147 passed, 0 failed`, exit 0. |

**Fix verified at three levels:**
- **Exists:** `repos/security-platform/workstation/tests/test_path_warning.sh` present, 136 lines, 4 `describe` blocks / 4 assertions (install×{warn,silent}, update×{warn,silent}).
- **Substantive:** Not a stub — each subshell sources real `setup.sh`, sets a scrubbed or populated `PATH`, stubs only the network-touching leaf functions (`run_installer`, `update_one_tool`), and asserts on captured stderr via `assert_contains`/`assert_not_contains`.
- **Wired:** `grep -n 'local orig_path=' setup.sh` → exactly 2 matches, at setup.sh:839 (`install_all_tools`) and setup.sh:871 (`update_all_tools`), both immediately preceding their respective `export PATH=` lines and consumed by `case ":$orig_path:" in` two lines before each function's closing brace. `bash -n setup.sh` exits 0 (no syntax regression).
- **Live behavioral confirmation (not just the offline suite):** re-ran `bash setup.sh doctor` and `bash setup.sh check` this session — both reproduce the exact same output/exit codes as the prior verification's live spot-checks (doctor: 6/6 OK, exit=0; check: same 5-tool MISMATCH set, pre-commit ok, exit=1), confirming 13-08 introduced no regression to either subcommand it was explicitly scoped not to touch.

**Commits verified:** `git -C repos/security-platform log` shows `3c0e94c` (test, RED — "add failing tests proving PATH warning is unreachable") and `3d3ceda` (fix, GREEN — "snapshot PATH before export in install_all_tools/update_all_tools"), both authored by the project's git user, both touching only `workstation/setup.sh` and `workstation/tests/test_path_warning.sh` per `git show --stat`.

### Test-Quality Notes (Info — does not affect goal achievement)

- Tests 2 and 4 (the "silent when already on PATH" assertions) use `assert_not_contains` with no positive completion sentinel inside the subshell. In principle a vacuous pass (function aborting before reaching the PATH check) would look identical to a genuine pass. The SUMMARY's own documented RED-step deviation confirms this exact failure mode occurred mid-development (Test 1 initially failed on an unrelated `PRECOMMIT_VERSION: unbound variable` crash, at which point Test 2 was "passing" vacuously). This was fixed before GREEN, and Tests 1/3 (identical setup, only PATH differs) now demonstrably reach the `case` block, corroborating that Tests 2/4 do too — but the test file itself doesn't self-verify this. Recommended hardening (not required for this phase): add an explicit "reached the case block" sentinel to the positive-path assertions.
- `trap 'rm -rf "$INSTALL_DIR"' RETURN` inside a bare `( ... )` subshell does not fire (`RETURN` traps apply to shell functions and sourced files, not subshells), so each test run leaks one `mktemp -d` temp directory per positive/negative pair. Cosmetic — does not affect assertion correctness or CI reliability, only leaves empty temp dirs behind (system temp cleanup handles this).

Neither note changes the verification outcome: the underlying fix was independently confirmed by direct code read (not just by trusting the test suite), and the live doctor/check spot-checks provide an additional non-test-suite confirmation channel.

### Plan-Level Truths (41 total, merged across all 8 plans' must_haves.truths)

All truths from the prior verification (1-39, see 2026-09-09 report retained in git history)
remain VERIFIED and were spot-checked for regression this session via the live test suite
(147/147, superset of the prior 143/143) and the two live doctor/check runs above, which are
identical in behavior to the prior verification's live runs. No regressions found. Truth #16 is
now VERIFIED (was FAILED); two new truths from 13-08 are VERIFIED (see Gap Closure table above).

**Score:** 41/41 plan-level truths verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `setup.sh` | main-guard, sourceable, `install_all_tools`/`update_all_tools` snapshot PATH before export | ✓ VERIFIED | `orig_path` pattern present at both call sites (setup.sh:839, 871); `bash -n setup.sh` exits 0 |
| `tests/test_path_warning.sh` | 4 behavioral assertions proving warn-fires/stays-silent for both functions | ✓ VERIFIED | 136 lines, 4 `describe`/assert pairs, non-network (stubbed installers), present and glob-picked-up by `run-tests.sh` with no runner edit |
| All artifacts from plans 13-01 through 13-07 | (see 2026-09-09 report) | ✓ VERIFIED (carried forward, unaffected by 13-08's scope) | No files outside `setup.sh` and the new test file were touched per plan's stated scope and `git show --stat` confirmation |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `tests/test_path_warning.sh` | `install_all_tools` | sourced call in PATH-scrubbed/PATH-populated subshell, asserting on `warn()` output | ✓ WIRED | Tests 1-2, both pass |
| `tests/test_path_warning.sh` | `update_all_tools` | sourced call in PATH-scrubbed/PATH-populated subshell, asserting on `warn()` output | ✓ WIRED | Tests 3-4, both pass |
| `install_all_tools`/`update_all_tools` `orig_path` snapshot | trailing `case` membership check | direct variable reference | ✓ WIRED | `case ":$orig_path:" in` at both sites, confirmed by code read, not just test pass |
| All key links from 13-01 through 13-07 | — | — | ✓ WIRED (carried forward, unaffected) | `run_doctor`, dispatcher branches, `update_one_tool`→`resolve_latest_in_major`, etc. — none touched by 13-08 |

### Behavioral Spot-Checks (live, real machine, this session)

| Behavior | Command | Result | Status |
|---|---|---|---|
| `doctor` reports healthy environment, no regression from PATH fix | `bash setup.sh doctor` | All 6 tools OK, PATH section correct (`/Users/christian/.local/bin exists`, `on PATH yes`), `exit=0` | ✓ PASS — matches prior verification exactly |
| `check` shows mismatches, exits non-zero, no regression from PATH fix | `bash setup.sh check` | Table printed, 5 MISMATCH rows (trivy/syft/grype/gitleaks/hadolint), pre-commit `ok`, `exit=1` | ✓ PASS — matches prior verification exactly (same pre-existing stale-pin pattern, unrelated to this phase) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist in this project. The phase's runnable-verification
mechanism is `bash tests/run-tests.sh`, executed live this session:

```
Results: 147 passed, 0 failed
EXIT: 0
```

(Up from 143/143 at initial verification — 4 new assertions from 13-08, all passing.)

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| MAINT-01 | 13-01, 13-02, 13-05, 13-06 | Developer can run a check command to see installed vs expected versions | ✓ SATISFIED | SC1 verified above, unchanged |
| MAINT-02 | 13-01, 13-02, 13-03, 13-04, 13-06, 13-07, 13-08 | Check command can update outdated tools to the pinned version | ✓ SATISFIED | SC2 verified above; the one previously-failed plan-level truth (PATH warning unreachable in update path) is now closed by 13-08 |
| MAINT-03 | 13-01, 13-05, 13-06, 13-07 | Health check verifies all tools are on PATH and can execute their version command | ✓ SATISFIED | SC3 verified above, unchanged — `doctor` untouched by 13-08 |

No orphaned requirements. MAINT-01/02/03 all appear in plan `requirements:` frontmatter across the
8 plans; 13-08 declares `requirements: [MAINT-02]`, consistent with REQUIREMENTS.md's mapping.

### Anti-Patterns Found

No new anti-patterns introduced by 13-08. `grep -n "TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER"` against
`setup.sh` and `tests/test_path_warning.sh` returns no matches (excluding `mktemp ... XXXXXX`
template characters, which are not debt markers).

Carried forward from 13-REVIEW.md / prior verification (unaffected by this gap closure):

| File | Pattern | Severity | Impact |
|---|---|---|---|
| setup.sh:578-606 vs 690-724 | `install`/`setup` trust installer exit code; `update` does not (WR-02) | Warning | Out of scope for Phase 13, explicitly deferred by 13-08's objective |
| setup.sh:340-342, 615-627 | trivy/syft/grype installed via unpinned `curl \| sh`, no checksum (WR-03) | Warning | Out of scope for Phase 13, explicitly deferred by 13-08's objective |
| setup.sh:356-368 | `versions.conf` sourced as executable shell, unvalidated (WR-04) | Warning | Pre-existing, out of scope |
| setup.sh:222-242 | No timeout on GitHub API calls (WR-05) | Warning | Pre-existing, out of scope |
| setup.sh:1191-1416 | Hand-edited `versions.conf` missing a var crashes with raw `set -u` error (WR-06) | Warning | Pre-existing, out of scope |
| setup.sh:374-390 | Dead code `detect_os`/`detect_arch` with false justification comment (WR-07) | Warning | Cosmetic, out of scope |
| tests/test_doctor.sh:68-99 | Hardcodes macOS bash version `3.2.57` (WR-08) | Warning | Test portability, out of scope |
| tests/test_path_warning.sh (new, this phase) | Positive-path assertions lack a reached-the-case-block sentinel; unused `RETURN` trap in bare subshells leaks temp dirs | Info | Does not affect correctness of the verified fix (corroborated by independent code read and live doctor/check runs); see Test-Quality Notes above |

WR-01 is now **closed**. WR-02 through WR-08 remain open and out of scope, unchanged from prior
verification.

### Human Verification Required

None. 13-08 is fully offline-testable (no `<human-check>` blocks in its PLAN — it is `autonomous:
true` with `gap_closure: true`), and the live doctor/check re-runs performed in this session serve
as the non-test-suite confirmation channel in place of a human-verify checkpoint.

### Gaps Summary

None. The single gap from the 2026-09-09 initial verification (WR-01: PATH-missing warning
unreachable in `install_all_tools`/`update_all_tools`) is closed, confirmed by direct code read
(not SUMMARY narration), a passing 147/147 test suite run live in this session, and two live
doctor/check spot-checks that reproduce the prior verification's exact output with no regression.
All 3 roadmap Success Criteria and all 41 merged plan-level truths are VERIFIED. Phase 13 goal
("Developer can check tool health, compare installed versions against expected versions, and
update outdated tools") is achieved with no open gaps.

---

_Verified: 2026-09-10_
_Verifier: Claude (gsd-verifier)_
