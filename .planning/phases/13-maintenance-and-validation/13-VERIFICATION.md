---
phase: 13-maintenance-and-validation
verified: 2026-09-09T00:00:00Z
status: gaps_found
score: 38/39 must-haves verified
overrides_applied: 0
gaps:
  - truth: "A user whose PATH lacks the install dir is told exactly what line to add (13-03-PLAN.md, install/update paths)"
    status: failed
    reason: >
      REVIEW.md WR-01 (confirmed by direct code read) shows the PATH-missing warning in
      install_all_tools() and update_all_tools() is unreachable dead code. Both functions do
      `export PATH="$INSTALL_DIR:$PATH"` immediately before the `case ":$PATH:" in *":$INSTALL_DIR:"*)`
      check, so the check always matches and the warning branch can never execute — a user whose
      shell profile genuinely lacks ~/.local/bin gets no warning from `install`, `setup`, or `update`.
      13-03's own SUMMARY confirms the warning *message* was improved to include the exact export
      line, but no test asserts the warning ever fires (confirmed: no test in
      test_update_fallback.sh or elsewhere exercises this branch with a PATH that excludes
      INSTALL_DIR before the export). The message content is correct; the trigger condition is not.
    artifacts:
      - path: "repos/security-platform/workstation/setup.sh"
        issue: "Lines ~837-858 (install_all_tools) and ~868-906 (update_all_tools): PATH check runs after PATH is mutated, so it is always true"
    missing:
      - "Snapshot $PATH before exporting INSTALL_DIR onto it, and test the snapshot (not the mutated PATH) in both install_all_tools and update_all_tools"
      - "A test that sets PATH to exclude INSTALL_DIR before calling install_all_tools/update_all_tools and asserts the warning is printed"
---

# Phase 13: Maintenance and Validation Verification Report

**Phase Goal:** Developer can check tool health, compare installed versions against expected
versions, and update outdated tools.
**Verified:** 2026-09-09
**Status:** gaps_found (one plan-level truth failed; all three roadmap Success Criteria are
independently VERIFIED and unaffected by this gap — see Gap Impact Assessment below)
**Re-verification:** No — initial verification

## Goal Achievement

### Roadmap Success Criteria (the phase contract)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `check` shows table of installed vs expected, highlights mismatches, exits non-zero on any missing/mismatched tool | ✓ VERIFIED | Code read (`run_check`, setup.sh:1191-1236; dispatcher `FAIL_COUNT=$((FAIL_COUNT + PROBLEM_COUNT))` at :1380). Live run on real machine: `bash setup.sh check` printed the table with 5 MISMATCH rows and `pre-commit ok`, **exit=1**. Test suite: "run_check: increments PROBLEM_COUNT once per MISSING/MISMATCH row" passes. |
| 2 | `update` upgrades outdated tools to pins, continues past failures, falls back to latest release within pinned major when exact pin unavailable, logs what it couldn't fix, exits non-zero only when a tool failed both attempts | ✓ VERIFIED | Code read (`update_one_tool`/`update_all_tools`, setup.sh:774-906): two-attempt sequence, `resolve_latest_in_major` fallback, downgrade guard (numeric sort, not lexical), `|| true` continue-on-failure loop, `log_update_failure` appends plain-text line with `installed=`/`pinned=`/`fallback=` fields, no credentials. Dispatcher deliberately does not map the post-update recheck's PROBLEM_COUNT into FAIL_COUNT (setup.sh:1400-1401), so exit reflects only double-failures. 13-07-SUMMARY.md: human-witnessed real pipx downgrade (4.5.1→4.5.0) and upgrade (4.5.0→4.5.1) round trip, independently confirmed via `pipx list` both times. Test suite: 30+ passing assertions across `test_update_primitives.sh`/`test_update_fallback.sh` cover already-current skip, attempt-1 success, fallback success, downgrade rejection, identical-fallback skip, both-fail logging, continue-past-failure, selective per-tool targeting. |
| 3 | `doctor` verifies every tool on PATH and can execute its version command, reports OK/NOT_ON_PATH/BROKEN/UNPARSEABLE plus PATH and prerequisite health, exits non-zero on any problem | ✓ VERIFIED | Code read (`tool_health`/`run_doctor`, setup.sh:460-521, 1254-1321): exact four-state vocabulary, does not export PATH before probing (sees real environment), reports PATH-exists/on-PATH and git/curl/python3 prerequisite rows. Live run: all six tools OK with parsed versions, PATH section correct, exit=0. 13-07-SUMMARY.md: human-witnessed doctor correct on a healthy 6-tool machine (exit=0) and correctly degrading on a scrubbed PATH (all NOT_ON_PATH, exit=1, no abort). Test suite: `tool_health` state-machine tests (NOT_ON_PATH/BROKEN/UNPARSEABLE/OK), gitleaks `version` vs `--version` probe distinction, doctor process tests (exits 1 on broken stub, `--help` lists doctor, per-tool targeting rejected for doctor). |

**Score:** 3/3 roadmap Success Criteria VERIFIED.

### Plan-Level Truths (39 total, merged from all 7 plans' must_haves.truths)

All 39 plan-level truths were checked against the actual test suite (143/143 passing, run live in
this session) and direct code reads. 38 map cleanly to a passing test case or a directly-read code
path; one FAILED (listed in the Gaps section above and the table below).

| # | Truth (plan) | Status | Evidence |
|---|---|---|---|
| 1-6 (13-01) | Sourceable setup.sh, test harness, isolation, both JSON fixtures | ✓ VERIFIED | "setup.sh syntax and sourceability" test block (4/4 pass); `tests/run-tests.sh` exists, 130 lines; both fixture files present and non-empty |
| 7-11 (13-02) | Compact/spaced JSON resolution, single-call major resolution, prerelease exclusion, token never in URL, visible warning on empty body | ✓ VERIFIED | "resolve_latest_version" and "resolve_latest_in_major" test blocks (all pass, incl. "never returns a prerelease tag", "token argument stays out of the URL argument") |
| 12 (13-03) | pipx replaces already-installed pre-commit | ✓ VERIFIED | `_install_precommit` uses `pipx install --force` (confirmed via grep in setup.sh); 13-07 human-verified a real downgrade/upgrade round trip |
| 13 (13-03) | pipx bootstrap failure records rather than terminates | ✓ VERIFIED | `ensure_pipx` returns instead of calling exit (13-03-SUMMARY commit 75fa6b5, confirmed by code read) |
| 14 (13-03) | Success decided by verifying installed version, not exit code | ✓ VERIFIED | `attempt_install` test: "returns 1 when the tool is NOT at the requested version, even though the installer returned 0" |
| 15 (13-03) | Failed tool logged as one plain-text line, no credentials | ✓ VERIFIED | `log_update_failure` tests: "the log's first character is not {", "contains no JSON key:value pair", "does not contain...Authorization" |
| 16 (13-03) | User whose PATH lacks install dir told exact line to add | ✗ FAILED | See Gaps section — warning message content is correct but unreachable in install/update paths (WR-01) |
| 17-24 (13-04) | update upgrades outdated, skips current, fallback reported not failed, downgrade rejected, continue-past-failure, post-update recheck shown, exit contract, per-tool targeting | ✓ VERIFIED | `update_one_tool`/`update_all_tools` test blocks, all passing (already-current, attempt-1, fallback-succeeds, downgrade-guard, empty-fallback, identical-fallback, both-fail, selective targeting, continue-past-failure) |
| 25-31 (13-05) | doctor per-tool PATH/execute/parseable report, BROKEN distinct from absent, real PATH untouched, report despite missing prerequisite, check/doctor exit contracts, update exit unaffected by recheck | ✓ VERIFIED | `tool_health`/`run_doctor` test blocks and dispatcher exit-contract tests, all passing; live doctor/check runs corroborate |
| 32-37 (13-06) | README documents update/doctor, fallback behaviour, exit-code contract, GITHUB_TOKEN; ARCHITECTURE.md updated; failure log gitignored | ✓ VERIFIED | grep confirms README.md:198-278 covers update/doctor sections, exit-code table, GITHUB_TOKEN section (line 270); ARCHITECTURE.md contains `resolve_latest_in_major`; `.gitignore` contains `update-failures.log` |
| 38-39+ (13-07) | Real-machine round trip changes installed version both directions; doctor correct on real environment; versions.conf restored | ✓ VERIFIED | 13-07-SUMMARY.md observed-results table (steps 1-10), cross-checked live in this session: `bash setup.sh check` reproduces the identical 5-tool MISMATCH set (trivy/syft/grype/gitleaks/hadolint) described as pre-existing/unrelated, with pre-commit `ok`, confirming the SUMMARY's account is consistent with actual code, not merely narrated |

**Score:** 38/39 plan-level truths verified (1 failed, see Gaps).

### Gap Impact Assessment

The one failed truth (PATH-missing warning is dead code in `install_all_tools`/`update_all_tools`)
does **not** affect any of the three roadmap Success Criteria:

- SC1 (`check`) does not touch this code path at all.
- SC2 (`update`) is unaffected in substance — `update_all_tools` still updates tools correctly; only
  its own PATH-warning branch (a secondary UX nicety, not a version-management behavior) never fires.
- SC3 (`doctor`) already implements the *correct* version of this exact capability: `run_doctor`
  deliberately does not export PATH before checking it (setup.sh:1254 comment block), so `doctor`
  is the tool a user actually needs to discover a PATH problem, and it works as designed (verified
  live and by test).

This is a real, reviewer-identified defect (REVIEW.md WR-01) in a plan-level must-have that duplicates
functionality `doctor` already delivers correctly. It should be fixed or explicitly waived, but it is
not a blocker to the phase goal as stated in ROADMAP.md.

**This looks like it may be intentional/acceptable given doctor's coverage.** To accept this
deviation instead of filing a follow-up plan, add to this file's frontmatter:

```yaml
overrides:
  - must_have: "A user whose PATH lacks the install dir is told exactly what line to add"
    reason: "install/update's PATH-missing warning is unreachable dead code (WR-01), but doctor
      already correctly detects and reports this condition without exporting PATH first, which is
      the tool a user needs for this exact question. Accepted as covered by doctor rather than
      fixed in install/update."
    accepted_by: "{name}"
    accepted_at: "{ISO timestamp}"
```

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `setup.sh` | main-guard, sourceable | ✓ VERIFIED | `BASH_SOURCE` guard at EOF; sourcing test passes |
| `tests/run-tests.sh` | test runner, min 60 lines | ✓ VERIFIED | 130 lines, glob-sources `test_*.sh`, TESTS_PASSED/TESTS_FAILED counters |
| `tests/test_smoke.sh`, `test_version_resolution.sh`, `test_update_primitives.sh`, `test_update_fallback.sh`, `test_doctor.sh` | test suites for each plan's surface | ✓ VERIFIED | All present, all pass (143/143 total) |
| `tests/fixtures/hadolint-releases-compact.json`, `gitleaks-releases-spaced.json` | JSON fixtures | ✓ VERIFIED | Both present, non-empty, referenced by tests |
| `setup.sh` — `gh_api_get`, `resolve_latest_in_major`, hardened `resolve_latest_version` | GitHub API layer | ✓ VERIFIED | Present, tested, token never in URL |
| `setup.sh` — `attempt_install`, `log_update_failure`, constants | update primitives | ✓ VERIFIED | Present, tested |
| `setup.sh` — `update_one_tool`, `update_all_tools`, dispatcher branch | update subcommand | ✓ VERIFIED | Present, wired into `main()`, tested end-to-end (offline) and on a real machine (13-07) |
| `setup.sh` — `tool_health`, `run_doctor`, dispatcher branch | doctor subcommand | ✓ VERIFIED | Present, wired into `main()`, tested, live-run confirmed |
| `README.md`, `ARCHITECTURE.md` | documentation of update/doctor | ✓ VERIFIED | Both updated; grep-confirmed content |
| `repos/security-platform/.gitignore` | `update-failures.log` ignored | ✓ VERIFIED | Line 24 |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `update` dispatcher | `update_all_tools` | case branch | ✓ WIRED | setup.sh:1396 |
| `update` dispatcher | `run_check` (post-update recheck) | automatic call | ✓ WIRED | setup.sh:1398, PROBLEM_COUNT deliberately not remapped (setup.sh:1400-1401) |
| `update_one_tool` | `resolve_latest_in_major` | failure-path fallback | ✓ WIRED | setup.sh: attempt-2 resolution block |
| `update_one_tool` | `log_update_failure` | on double failure | ✓ WIRED | setup.sh:832 area |
| `doctor` dispatcher | `run_doctor` | case branch, skips `ensure_versions_conf`, no PATH export | ✓ WIRED | setup.sh:1385-1388 |
| `run_doctor` | `tool_health` | per-tool probe | ✓ WIRED | setup.sh:1265 |
| `check`/`doctor` dispatcher branches | `FAIL_COUNT` | `PROBLEM_COUNT` mapped at dispatcher, not inside run_check/run_doctor | ✓ WIRED | setup.sh:1380, 1388 |

### Behavioral Spot-Checks (live, real machine)

| Behavior | Command | Result | Status |
|---|---|---|---|
| `check` shows mismatches, exits non-zero | `bash setup.sh check` | Table printed, 5 MISMATCH rows, `exit=1` | ✓ PASS (matches 13-07's documented, root-caused divergence — pre-existing stale pins unrelated to this phase's code) |
| `doctor` reports healthy environment | `bash setup.sh doctor` | All 6 tools OK, PATH section correct, `exit=0` | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist in this project (`find ... -path '*/tests/probe-*.sh'`
returned empty), and no plan declares a probe path. The phase's actual runnable-verification
mechanism is `bash tests/run-tests.sh`, executed directly in this session:

```
Results: 143 passed, 0 failed
EXIT: 0
```

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| MAINT-01 | 13-01, 13-02, 13-05, 13-06 | Developer can run a check command to see installed vs expected versions | ✓ SATISFIED | SC1 verified above |
| MAINT-02 | 13-01, 13-02, 13-03, 13-04, 13-06, 13-07 | Check command can update outdated tools to the pinned version | ✓ SATISFIED | SC2 verified above; one plan-level truth (PATH warning) failed but does not affect this requirement's substance |
| MAINT-03 | 13-01, 13-05, 13-06, 13-07 | Health check verifies all tools are on PATH and can execute their version command | ✓ SATISFIED | SC3 verified above |

No orphaned requirements: REQUIREMENTS.md maps only MAINT-01/02/03 to Phase 13, and all three appear
in at least one plan's `requirements:` frontmatter.

### Anti-Patterns Found

Carried forward from 13-REVIEW.md (0 critical, 8 warning, 3 info) — none are new findings from this
verification pass, and none block the phase goal. Listed here for completeness per Step 7:

| File | Pattern | Severity | Impact |
|---|---|---|---|
| setup.sh:837-906 | PATH-missing warning unreachable (WR-01) | Warning | See Gaps section above — this is the one item elevated to a gap in this verification |
| setup.sh:578-606 vs 690-724 | `install`/`setup` trust installer exit code; `update` does not, for identical installers (WR-02) | Warning | Out of scope for Phase 13's goal (install/setup path, not update/check/doctor) |
| setup.sh:340-342, 615-627 | trivy/syft/grype installed via unpinned `curl \| sh` from `main`, no checksum (WR-03) | Warning | Pre-existing security asymmetry, out of scope for this phase's goal |
| setup.sh:356-368 | `versions.conf` sourced as executable shell, unvalidated (WR-04) | Warning | Pre-existing, out of scope |
| setup.sh:222-242 | No timeout on GitHub API calls (WR-05) | Warning | Pre-existing, out of scope |
| setup.sh:1191-1416 | Hand-edited `versions.conf` missing a var crashes with raw `set -u` error (WR-06) | Warning | Pre-existing, out of scope |
| setup.sh:374-390 | Dead code `detect_os`/`detect_arch` with false justification comment (WR-07) | Warning | Cosmetic, out of scope |
| tests/test_doctor.sh:68-99 | Hardcodes macOS bash version `3.2.57`, will false-fail on Linux (WR-08) | Warning | Test portability, does not affect this verification (tests ran and passed on this machine, which is macOS) |
| Various | TBD/FIXME/XXX debt markers | — | None found — the only `XXX` matches are `mktemp ... .XXXXXX` template characters, not debt markers |

No unresolved TBD/FIXME/XXX debt markers exist in any file modified by this phase.

### Human Verification Required

None. The one truth requiring a real machine ("update genuinely changes an installed tool's
version") was already discharged by the 13-07 human-verify checkpoint (autonomous: false), which
this verification cross-checked by independently re-running `check`/`doctor` live and confirming
the exact same pre-existing 5-tool MISMATCH pattern the SUMMARY described, with pre-commit `ok` —
consistent with the SUMMARY's account, not merely trusting its narration.

### Gaps Summary

Of 3 roadmap Success Criteria and 39 merged plan-level truths, 3/3 SCs and 38/39 truths are
VERIFIED against actual code, live execution, and a 143/143-passing offline test suite. The one
FAILED truth — "a user whose PATH lacks the install dir is told exactly what line to add," scoped
to `install_all_tools`/`update_all_tools` — is real (confirmed by direct code read: the PATH check
runs after `$INSTALL_DIR` is already exported onto `$PATH`, so the warning branch is unreachable)
but does not undermine any of the three roadmap Success Criteria, because `doctor` (the tool
MAINT-03 specifically asks for) already implements this exact detection correctly by design. This
is recorded as a gap rather than silently passed, with an override suggestion for the developer to
accept if `doctor`'s coverage is judged sufficient, or a two-line fix (snapshot PATH before
exporting) if not.

---

_Verified: 2026-09-09_
_Verifier: Claude (gsd-verifier)_
