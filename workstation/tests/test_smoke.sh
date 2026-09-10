# shellcheck shell=bash
# shellcheck disable=SC1090  # SETUP_SH is exported by run-tests.sh at a known path
# test_smoke.sh — Baseline sanity assertions for setup.sh and the runner itself
#
# Sourced by run-tests.sh — do not `exit`, do not re-declare helpers, do not
# `set -e` in this file (see the isolation contract in run-tests.sh).

describe "setup.sh syntax and sourceability"

if /bin/bash -n "$SETUP_SH" 2>/dev/null; then
  pass "setup.sh passes bash -n syntax check"
else
  fail "setup.sh failed bash -n syntax check"
fi

# Rule 2 + Rule 3 demonstration: source setup.sh in a subshell with set +e,
# echo what we need, assert in the parent.
source_out=$( ( source "$SETUP_SH"; set +e; echo "SOURCED_OK" ) 2>&1 )
assert_eq "SOURCED_OK" "$source_out" "sourcing setup.sh in isolation produces only our own echo (no side output)"

# Directly confirm the acceptance criterion: sourcing produces zero combined
# output and exits 0, run as its own process (not nested in this subshell).
direct_out=$(/bin/bash -c "source '$SETUP_SH'" 2>&1)
direct_rc=$?
assert_eq "" "$direct_out" "sourcing setup.sh directly produces no stdout/stderr"
assert_status 0 "$direct_rc" "sourcing setup.sh directly exits 0"

describe "setup.sh CLI behavior (--help / unknown arg)"

help_out=$(/bin/bash "$SETUP_SH" --help 2>&1)
help_rc=$?
assert_status 0 "$help_rc" "--help exits 0"
assert_contains "$help_out" "Usage: bash setup.sh" "--help output contains usage line"

bogus_out=$(/bin/bash "$SETUP_SH" bogus-arg 2>&1)
bogus_rc=$?
assert_status 1 "$bogus_rc" "unknown argument exits 1"
assert_contains "$bogus_out" "Unknown argument" "unknown argument prints error message"

describe "shellcheck (skipped if not installed)"

if command -v shellcheck > /dev/null 2>&1; then
  if shellcheck "$SETUP_SH" > /dev/null 2>&1; then
    pass "shellcheck reports no findings on setup.sh"
  else
    fail "shellcheck reports findings on setup.sh"
  fi
else
  echo "  skip  shellcheck not installed (not in check_prerequisites)"
fi

describe "test fixtures exist and are non-empty"

if [[ -s "$FIXTURES_DIR/hadolint-releases-compact.json" ]]; then
  pass "hadolint-releases-compact.json exists and is non-empty"
else
  fail "hadolint-releases-compact.json missing or empty"
fi

if [[ -s "$FIXTURES_DIR/gitleaks-releases-spaced.json" ]]; then
  pass "gitleaks-releases-spaced.json exists and is non-empty"
else
  fail "gitleaks-releases-spaced.json missing or empty"
fi

describe "runner self-test: fail() actually increments TESTS_FAILED"

# Rule 1 in action: prove the counter works by deliberately failing once,
# then restoring the counter so the overall suite still ends green. Without
# this self-test, a broken counter (e.g. one reset by a sourced setup.sh)
# would be indistinguishable from a fully passing suite.
_saved_failed_count="$TESTS_FAILED"
fail "self-test: intentional deliberate failure (not a real bug)"
if [[ "$TESTS_FAILED" -eq $((_saved_failed_count + 1)) ]]; then
  pass "fail() incremented TESTS_FAILED as expected"
else
  fail "fail() did NOT increment TESTS_FAILED — counter is broken"
fi
TESTS_FAILED="$_saved_failed_count"
