---
phase: 13-maintenance-and-validation
plan: 01
subsystem: workstation/testing
tags: [bash, test-harness, shellcheck, main-guard, tdd-scaffolding]
dependency-graph:
  requires: []
  provides:
    - "sourceable setup.sh (main-guard around dispatcher)"
    - "tests/run-tests.sh glob-sourcing test runner"
    - "tests/test_smoke.sh baseline assertions"
    - "GitHub releases JSON fixtures (compact + spaced formatting)"
  affects:
    - "13-02 through 13-05 (all source setup.sh and add test_*.sh files)"
tech-stack:
  added: []
  patterns:
    - "main() function + BASH_SOURCE if-guard for sourceable bash entrypoints"
    - "plain-bash TESTS_PASSED/TESTS_FAILED counter test runner (no bats dependency)"
    - "subshell-emits/parent-asserts isolation pattern for testing set -euo pipefail code"
key-files:
  created:
    - repos/security-platform/workstation/tests/run-tests.sh
    - repos/security-platform/workstation/tests/test_smoke.sh
    - repos/security-platform/workstation/tests/fixtures/hadolint-releases-compact.json
    - repos/security-platform/workstation/tests/fixtures/gitleaks-releases-spaced.json
  modified:
    - repos/security-platform/workstation/setup.sh
decisions:
  - "Plain bash test runner, not bats — no bats dependency exists anywhere in the codebase; the only prior shell harness (terraform-pipelines/tests/test-terraform.sh) is plain bash"
  - "if-form BASH_SOURCE guard, not && form — the && form would make sourcing exit non-zero under set -e, breaking the plan's own zero-exit acceptance criterion"
  - "Counter names TESTS_PASSED/TESTS_FAILED chosen specifically to avoid colliding with setup.sh's own FAIL_COUNT/RESULTS globals sourced into test subshells"
metrics:
  duration: "~25 minutes"
  completed: 2026-09-09
---

# Phase 13 Plan 01: Sourceable setup.sh + Test Harness Scaffolding Summary

Wrapped `setup.sh`'s dispatcher in a `main()` function guarded by `BASH_SOURCE`/`$0` comparison so the script is sourceable for unit testing with zero output and zero side effects, then stood up a plain-bash `tests/` harness (glob-sourcing runner, assert helpers, documented four-rule subshell isolation contract, baseline smoke assertions, and two GitHub JSON fixtures capturing both compact and spaced release-metadata formatting) that every later Phase 13 plan extends.

## What Was Built

**Task 1 — Main-guard in `setup.sh`:** Moved the argument-parsing loop, `check_prerequisites` call, `case "$COMMAND"` dispatch, and the `exit 1`/`exit 0` gate into a `main()` function. Added:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

at the end of the file. Used the `if` form (not `[[ ... ]] && main "$@"`) specifically because the `&&` form evaluates false when sourced, which under `set -e` would make the *sourcing* shell exit non-zero — breaking the acceptance criterion that `source setup.sh` exits 0.

**Task 2 — `tests/` harness:**
- `tests/run-tests.sh`: entry point that computes `SETUP_SH`/`FIXTURES_DIR` paths (via the `cicd/lint-markdown.sh` `dirname "$0"` idiom), declares `pass`/`fail`/`describe`/`assert_eq`/`assert_contains`/`assert_not_contains`/`assert_status` helpers backed by `TESTS_PASSED`/`TESTS_FAILED` counters, documents the four-rule test isolation contract in its header comment, glob-sources every `tests/test_*.sh` case file, and prints `Results: N passed, M failed` before exiting 1 if any failed.
- `tests/test_smoke.sh`: baseline assertions — syntax check, sourceability (no output, exit 0), `--help`/unknown-arg behavior, conditional shellcheck, fixture existence, and a self-test that deliberately calls `fail()` once and verifies the counter incremented (then restores it) to guard against the false-green failure mode where a broken counter is indistinguishable from a passing suite.
- `tests/fixtures/hadolint-releases-compact.json`: 6 fabricated release objects in hadolint's real compact-JSON style (`"tag_name":"v..."`, no space after colon), including a prerelease tag (`v2.12.1-beta`) to exercise prerelease exclusion.
- `tests/fixtures/gitleaks-releases-spaced.json`: 5 fabricated release objects in spaced-JSON style (`"tag_name": "v..."`), including versions that require numeric (not lexical) semver ordering (`v8.2.0` vs `v8.10.0`).

## Verification Performed

- `bash -n setup.sh` and `shellcheck setup.sh` clean (baseline was also clean — no new findings)
- `source setup.sh` in isolation: empty stdout+stderr, exit 0
- All four subcommands (`install`/`configure`/`setup`/`check`), `--help`, and the unknown-arg path behave identically to pre-change baseline
- `bash tests/run-tests.sh` exits 0, reports `Results: 12 passed, 0 failed`
- Negative control: appending a case file with a single `fail "deliberate"` call made the suite exit 1 and report `1 failed`; removing it restored exit 0
- Probe file: adding `tests/test_zzz_probe.sh` with `pass "probe"` raised the passed count with zero edits to `run-tests.sh`
- `shellcheck tests/run-tests.sh tests/test_smoke.sh` clean
- `gitleaks detect` against `tests/` found no leaks
- No executable bits on any created file (`find tests -type f -perm -u+x` empty)
- No bash 3.2-incompatible constructs (`declare -A`, `local -n`, `mapfile`, `readarray`) in `tests/`
- `(cd repos/security-platform && bash workstation/setup.sh check)` still prints `Security Tool Version Check`
- No stray `versions.conf` left in either repo's working tree

## Deviations from Plan

Plan tasks executed exactly as written. Three adjustments made during self-verification and state-update:

1. **[Rule 1 - Bug] Fixture JSON was single-line, breaking `grep -c` line-count acceptance criteria.** The plan's acceptance criteria (`grep -c '"tag_name":"'` returning 4+) assumes one match per line; my first draft of `hadolint-releases-compact.json` was a single JSON line, so `grep -c` counted 1 line instead of 6 occurrences. Fixed by placing each release object on its own line (still compact style, no space after colons) — commit `e022bc0`.
2. **[Rule 1 - Bug] Header comments in `run-tests.sh` literally contained the strings `RESULTS` and `FAIL_COUNT`** (as illustrative examples of setup.sh's own globals), which caused the acceptance criterion `grep -cw 'FAIL_COUNT\|PASS_COUNT\|RESULTS'` to return 2 instead of the required 0. Reworded the comments to describe the collision risk generically instead of naming the exact identifiers — commit `e022bc0`.
3. **[State-update correction, not a plan deviation] Did not mark MAINT-01/02/03 complete in REQUIREMENTS.md**, despite this plan's frontmatter listing them under `requirements:`. Checking the other six plans in this phase (`13-02` through `13-07`) shows each also lists a subset of MAINT-01/02/03 — the field means "this plan contributes to this requirement," not "this plan completes it." No `--check`/`--update`/`--doctor` functionality exists yet (that's plans 02-05). Running `requirements.mark-complete` here would have written false completion state for the verifier and later executors to read. Reverted the SDK's initial mark-complete call (`git checkout -- .planning/REQUIREMENTS.md`) and documented the correct completion trigger (last plan touching each requirement) in `STATE.md` under Blockers/Concerns.

### Environmental notes (SDK behavior, not plan or code deviations)

- `gsd-sdk query state.advance-plan` computed against a stale Current Position (it still read "Phase 12 of 13, 1 of 1 plan," which predated this plan's execution), returning `reason: "last_plan"` and an incorrect `status: verifying`. Corrected manually to `status: executing`, `Phase 13 of 13, Plan 1 of 7`, `Resume file: 13-02-PLAN.md`.
- `gsd-sdk query state.record-metric` returned `"Performance Metrics section not found"` because STATE.md's Performance Metrics section uses a narrative Velocity/Recent-Trend format, not the table format the handler pattern-matches. Added the Phase 13 P01 duration to the existing "Recent Trend" list manually instead.

## Known Stubs

None.

## Threat Flags

None — this plan's threat register (`T-13-01`, `T-13-06`, `T-13-08`, `T-13-09`, `T-13-23`, `T-13-05`, `T-13-SC`) fully covers the new surface (fixture files, test scripts, main-guard change). No additional network endpoints, auth paths, or schema changes were introduced.

## Self-Check: PASSED

- FOUND: repos/security-platform/workstation/setup.sh (modified, main-guard present)
- FOUND: repos/security-platform/workstation/tests/run-tests.sh
- FOUND: repos/security-platform/workstation/tests/test_smoke.sh
- FOUND: repos/security-platform/workstation/tests/fixtures/hadolint-releases-compact.json
- FOUND: repos/security-platform/workstation/tests/fixtures/gitleaks-releases-spaced.json
- FOUND commit 5a09c87 (feat(13-01): add main-guard to setup.sh for sourceability) in repos/security-platform
- FOUND commit e022bc0 (test(13-01): add plain-bash test harness with isolation contract and JSON fixtures) in repos/security-platform
