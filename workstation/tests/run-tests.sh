#!/usr/bin/env bash
set -uo pipefail

# run-tests.sh — Plain-bash test runner for workstation/setup.sh
#
# The only entry point for this test suite. Sources every tests/test_*.sh
# case file, runs its assertions, and prints a pass/fail summary.
#
# Usage:
#   bash tests/run-tests.sh
#
# Deliberately does NOT use `set -e`: a failing assertion inside a case file
# must be recorded by the counters below and the suite must keep running to
# report every failure, not just the first one.
#
# ---------------------------------------------------------------------------
# Test isolation contract
# ---------------------------------------------------------------------------
# Every test_*.sh case file added to this directory (this plan and all later
# plans in Phase 13) MUST follow these four rules:
#
#   Rule 1 — never call an assert helper inside a subshell. Counter increments
#   inside `( ... )` or `$( ... )` are discarded when the subshell exits. A
#   case that asserts inside a subshell prints FAIL lines while TESTS_FAILED
#   stays 0, and the suite exits 0 — a false green. Subshells emit, the
#   parent asserts.
#
#   Rule 2 — subshells communicate by echoing. Capture with:
#     out=$( ( source "$SETUP_SH"; set +e; <stubs>; <call>; echo "rc=$?"; echo "$SOME_VALUE" ) 2>&1 )
#   then run the assert helpers in the parent shell against "$out".
#
#   Rule 3 — `set +e` immediately after sourcing inside a test subshell.
#   Sourcing setup.sh imports its `set -euo pipefail`. Without `set +e`, a
#   function returning 1 (the expected outcome in most of these tests) kills
#   the subshell before it can echo anything.
#
#   Rule 4 — test `set -e` safety separately and explicitly. To prove a
#   function does not kill an errexit caller, run a self-contained snippet as
#   its own process:
#     /bin/bash -euo pipefail -c 'source "$SETUP_SH"; <stubs>; <call> || true; echo SURVIVED'
#   and assert the output contains SURVIVED. Do not try to prove this inside a
#   `set +e` subshell.
#
# Case files are sourced, not executed: they must not call `exit`, must not
# re-declare the helpers below, and must not use `set -e`.
#
# Counter names TESTS_PASSED / TESTS_FAILED are deliberately NOT the same as
# any global setup.sh declares in its own constants block — a case file that
# sources setup.sh would otherwise reset this runner's own counters to zero.

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSTATION_DIR="$(cd "$TESTS_DIR/.." && pwd)"
export SETUP_SH="$WORKSTATION_DIR/setup.sh"
export FIXTURES_DIR="$TESTS_DIR/fixtures"

TESTS_PASSED=0
TESTS_FAILED=0

# shellcheck disable=SC2329  # invoked from sourced tests/test_*.sh case files
pass() {
  echo "  pass  $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

# shellcheck disable=SC2329  # invoked from sourced tests/test_*.sh case files
fail() {
  echo "  FAIL  $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

# shellcheck disable=SC2329  # invoked from sourced tests/test_*.sh case files
describe() {
  echo ""
  echo "-- $1 --"
}

# shellcheck disable=SC2329  # invoked from sourced tests/test_*.sh case files
assert_eq() {
  local expected="$1" actual="$2" message="$3"
  if [[ "$expected" = "$actual" ]]; then
    pass "$message"
  else
    fail "$message (expected [$expected], got [$actual])"
  fi
}

# shellcheck disable=SC2329  # invoked from sourced tests/test_*.sh case files
assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) pass "$message" ;;
    *)           fail "$message (expected to find [$needle])" ;;
  esac
}

# shellcheck disable=SC2329  # invoked from sourced tests/test_*.sh case files
assert_not_contains() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) fail "$message (did not expect to find [$needle])" ;;
    *)           pass "$message" ;;
  esac
}

# shellcheck disable=SC2329  # invoked from sourced tests/test_*.sh case files
assert_status() {
  local expected_code="$1" actual_code="$2" message="$3"
  if [[ "$expected_code" = "$actual_code" ]]; then
    pass "$message"
  else
    fail "$message (expected exit $expected_code, got $actual_code)"
  fi
}

# Source every case file via a glob. Guarded against the no-match case so an
# empty tests/ directory does not error out on the literal glob string.
for case_file in "$TESTS_DIR"/test_*.sh; do
  [[ -e "$case_file" ]] || continue
  # shellcheck source=/dev/null
  source "$case_file"
done

echo ""
echo "Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"

if [[ "$TESTS_FAILED" -gt 0 ]]; then
  exit 1
fi

exit 0
