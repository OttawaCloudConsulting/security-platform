---
phase: 13-maintenance-and-validation
plan: 02
subsystem: workstation/version-resolution
tags: [bash, github-api, curl, semver, tdd, fixture-tests]

requires:
  - phase: 13-maintenance-and-validation plan 01
    provides: "sourceable setup.sh (main-guard), tests/run-tests.sh runner, tests/test_smoke.sh, GitHub JSON fixtures"
provides:
  - "gh_api_get() — single authenticated GitHub REST wrapper (lazy token resolution, header-only auth, never in URL/logs)"
  - "hardened resolve_latest_version() — whitespace-tolerant tag_name/name extraction, explicit || version=\"\" guard, actionable rate-limit warning"
  - "resolve_latest_in_major(owner/repo, major) — single-call, numerically-sorted, prerelease-excluded resolver for the D-04 update fallback"
  - "tests/test_version_resolution.sh — 20 fixture-driven, zero-network assertions covering both JSON styles, token hygiene, and set -e safety"
affects: ["13-03 through 13-07 (update/doctor commands built in later plans call resolve_latest_in_major and gh_api_get)"]

tech-stack:
  added: []
  patterns:
    - "gh_api_get() as the single choke point for all GitHub-touching calls — token resolved lazily on first call, sent as Authorization: Bearer header only"
    - "curl/gh stub + marker-file pattern for testing subshell-scoped call counts (plain variable increments inside a $( ) do not propagate to the parent shell)"
    - "sort -t. -k1,1n -k2,2n -k3,3n | tail -1 for numeric semver ordering on bash 3.2 (not sort -V, not head -1 which SIGPIPEs under set -euo pipefail)"

key-files:
  created:
    - repos/security-platform/workstation/tests/test_version_resolution.sh
  modified:
    - repos/security-platform/workstation/setup.sh
    - repos/security-platform/workstation/tests/fixtures/hadolint-releases-compact.json
    - repos/security-platform/workstation/tests/fixtures/gitleaks-releases-spaced.json

key-decisions:
  - "Token resolved lazily inside gh_api_get() on first call only, not at file scope — preserves plan-01's sourcing-has-no-side-effects acceptance criterion"
  - "resolve_latest_in_major terminates its pipeline with sort | tail -1, not head -1 — head triggers SIGPIPE 141 under set -euo pipefail on bash 3.2.57"
  - "Empty API body and major-absent-from-body are distinct failure paths: empty body warns about rate limiting, major-absent returns silently (correct D-04 step-3 outcome, not a rate-limit condition)"

requirements-completed: [MAINT-01, MAINT-02]

duration: ~35min
completed: 2026-09-09
---

# Phase 13 Plan 02: GitHub API Layer for Version Resolution Summary

Built the authenticated GitHub API wrapper `gh_api_get()`, hardened `resolve_latest_version()` to be whitespace-tolerant (fixing the hadolint compact-JSON bug) and never silently fatal, and added `resolve_latest_in_major()` — the single-call, numerically-sorted resolver the D-04 update fallback path will use — backed by 20 new fixture-driven tests that make zero network calls.

## Performance

- **Duration:** ~35 min
- **Started:** 2026-09-09
- **Completed:** 2026-09-09
- **Tasks:** 2 completed (both TDD: RED then GREEN)
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- `gh_api_get()`: resolves a GitHub token lazily from `GITHUB_TOKEN` → `GH_TOKEN` → `gh auth token`, sends it as an `Authorization: Bearer` header only (never in a URL, never logged), and is the single choke point every GitHub-touching call in the script now routes through.
- Hardened `resolve_latest_version()`: replaced the space-dependent `'"tag_name": "..."'` grep/sed (which silently returned empty for hadolint's compact JSON) with a whitespace-tolerant pattern, added `|| version=""` guards on both command substitutions, and paired the existing `err` with a new `warn` naming the 60/hr rate limit — no more silent fallback.
- New `resolve_latest_in_major(owner/repo, major)`: one API call (`releases?per_page=100`), strict `^${major}\.[0-9]+\.[0-9]+$` semver anchor (a security control preventing an arbitrary `tag_name` from reaching a download URL or `pipx install` spec), numeric `sort -t. -k1,1n -k2,2n -k3,3n | tail -1` ordering, and the same actionable rate-limit warning on an empty body.
- 20 new assertions in `tests/test_version_resolution.sh`, all offline: token-header presence/absence, token-never-in-URL, compact vs. spaced JSON extraction, numeric-not-lexical ordering (`8.2.0`/`8.10.0`/`8.30.1`), prerelease exclusion, empty-body and major-absent failure paths, a bare (unguarded) `set -e` survival test, and a single-API-call-per-invocation guard.
- Full suite: 42 passed, 0 failed, deterministic across two consecutive runs.

## Task Commits

Each task followed the RED → GREEN TDD cycle with separate commits, all in `repos/security-platform`:

1. **Task 1: gh_api_get() + hardened resolve_latest_version()**
   - `ea1a574` (test) — failing tests for token handling and hardened resolution (7 assertions fail against old code)
   - `76fd287` (feat) — implementation; all 7 previously-failing assertions pass
2. **Task 2: resolve_latest_in_major()**
   - `d2cec00` (test) — failing tests for the new resolver (5 assertions fail — function doesn't exist)
   - `edd6cd7` (feat) — implementation; all 5 previously-failing assertions pass, plus a test-bug fix found during GREEN verification

**Plan metadata:** committed separately in the documentation repo (this SUMMARY.md, STATE.md, ROADMAP.md, REQUIREMENTS.md).

_Note: this is a `tdd="true"` plan — every task has a `test(...)` commit before its `feat(...)` commit, satisfying the RED/GREEN gate sequence._

## Files Created/Modified

- `repos/security-platform/workstation/setup.sh` — added `GITHUB_TOKEN_VALUE`/`GITHUB_TOKEN_RESOLVED` constants, `gh_api_get()`, hardened `resolve_latest_version()`, new `resolve_latest_in_major()`
- `repos/security-platform/workstation/tests/test_version_resolution.sh` — new fixture-driven test case file (sourced automatically by plan-01's runner glob)
- `repos/security-platform/workstation/tests/fixtures/hadolint-releases-compact.json` — pre-existing plan-01 fixture; `url` field hostname changed from `api.github.com` to `example.invalid` (see deviations)
- `repos/security-platform/workstation/tests/fixtures/gitleaks-releases-spaced.json` — same hostname fix

## Decisions Made

- Token resolution is lazy (inside `gh_api_get()`, on first call), not at file scope, so sourcing `setup.sh` for tests still has zero side effects — this was a hard constraint carried over from plan 01's acceptance criterion.
- `resolve_latest_in_major` distinguishes two failure modes that the plan's acceptance criteria treat differently: an **empty body** (likely rate-limited) gets the actionable `warn`; a **non-empty body with no matching major** (D-04 step-3's "more than 100 releases behind" case) returns 1 silently, since that is the expected/correct outcome, not an error condition.
- Used a marker-file pattern (not a plain variable) to count `gh_api_get` invocations in the "single API call" test, because a `$( )` command substitution forks its own subshell and variable increments made there don't propagate back to the parent test subshell — see Deviations.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Pre-existing fixture files leaked a real GitHub hostname, breaking this plan's own acceptance criterion**
- **Found during:** Task 1 setup, before writing any test assertions
- **Issue:** Plan 01's `tests/fixtures/hadolint-releases-compact.json` and `gitleaks-releases-spaced.json` include a `"url"` field pointing at `https://api.github.com/repos/...`. This plan's acceptance criterion `grep -rn 'api.github.com' repos/security-platform/workstation/tests/` returning nothing would fail on day one of this plan, entirely because of unrelated data in a field no code ever parses.
- **Fix:** Replaced `api.github.com` with `example.invalid` in the `url` field of both fixtures. No test or production code reads that field; only `tag_name`/`name` are parsed.
- **Files modified:** `repos/security-platform/workstation/tests/fixtures/hadolint-releases-compact.json`, `repos/security-platform/workstation/tests/fixtures/gitleaks-releases-spaced.json`
- **Verification:** `grep -rn 'api.github.com' repos/security-platform/workstation/tests/` returns nothing (exit 1); full suite still passes with the corrected fixtures.
- **Committed in:** `ea1a574` (part of the task 1 RED commit)

**2. [Rule 1 - Bug] Test's own call-count assertion was structurally incapable of measuring what it claimed to measure**
- **Found during:** Task 2 GREEN verification (after implementing `resolve_latest_in_major`, one assertion still failed)
- **Issue:** The "single API call per invocation" test incremented a plain `call_count` variable inside the `gh_api_get` stub, but `gh_api_get` is invoked via `body=$(gh_api_get ...)` inside `resolve_latest_in_major` — a `$( )` command substitution forks its own subshell, so the increment never reached the parent test subshell. The test would have reported `calls=0` regardless of how many times the real function was called, making it a false negative (and, if inverted, a potential false positive) rather than a real assertion.
- **Fix:** Switched to a marker-file counter (`echo "x" >> "$call_marker"`, then `wc -l` after the subshell exits) — file writes survive subshell boundaries, plain variable writes do not.
- **Files modified:** `repos/security-platform/workstation/tests/test_version_resolution.sh`
- **Verification:** Test now correctly reports `calls=1`; suite is 42 passed, 0 failed, deterministic across two consecutive runs.
- **Committed in:** `edd6cd7` (part of the task 2 GREEN commit)

---

**Total deviations:** 2 auto-fixed (2 bugs — one in inherited test data, one in this plan's own new test code)
**Impact on plan:** Both fixes were required for the plan's stated acceptance criteria to be verifiable at all; neither changed production `setup.sh` behavior beyond what the plan specified. No scope creep.

## Issues Encountered

- An early draft of the test file put `case`/`esac` blocks with unquoted `)` characters inside `$( ( ... ) )` nested command substitutions, which confused bash's paren-counting parser and produced "unexpected end of file" / "unexpected token `)`" syntax errors that pointed at the wrong line. Resolved by replacing the `case` statements inside those specific subshells with `[[ ... == pattern* ]]` glob tests (top-level `case`/`esac` outside a `$( )` context was unaffected and left as-is).
- `${*: -1}` (bash 4+ negative-offset substring on positional/array params) caused a similar parse failure; replaced with a portable last-argument-tracking loop compatible with bash 3.2.

## User Setup Required

None — no external service configuration required. (Optional: setting `GITHUB_TOKEN` or `GH_TOKEN` in the environment raises the unauthenticated 60/hr GitHub API limit to 5000/hr, but this is a convenience, not a requirement — `gh_api_get()` works correctly with no token present.)

## Next Phase Readiness

- `gh_api_get()` and `resolve_latest_in_major()` are ready for plan 13-04's `update` command to call, per the plan's D-04 dependency note ("the loop that calls it is plan 04").
- Both are asserted `set -e`-safe at every call site convention (`x=$(fn ...) || x=""`), so plan 04 can adopt the same pattern without re-deriving it.
- `resolve_latest_version`'s 13 existing call sites (`generate_versions_conf`, `resolve_hook_versions`) are unchanged in behavior — verified via `(cd repos/security-platform && /bin/bash workstation/setup.sh check)` still printing both tables correctly.
- No blockers for 13-03 through 13-07.

## Self-Check: PASSED

- FOUND: repos/security-platform/workstation/tests/test_version_resolution.sh
- FOUND: repos/security-platform/workstation/setup.sh (modified)
- FOUND commit ea1a574 (test(13-02): add failing tests for gh_api_get and hardened resolve_latest_version) in repos/security-platform
- FOUND commit 76fd287 (feat(13-02): add gh_api_get() and harden resolve_latest_version()) in repos/security-platform
- FOUND commit d2cec00 (test(13-02): add failing tests for resolve_latest_in_major()) in repos/security-platform
- FOUND commit edd6cd7 (feat(13-02): add resolve_latest_in_major() for D-04 fallback resolution) in repos/security-platform

---
*Phase: 13-maintenance-and-validation*
*Completed: 2026-09-09*
