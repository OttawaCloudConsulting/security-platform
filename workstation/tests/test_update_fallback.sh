# shellcheck shell=bash
# shellcheck disable=SC1090  # SETUP_SH is exported by run-tests.sh at a known path
# test_update_fallback.sh — Fixture-free, offline unit tests for the `update`
# subcommand's state machine: update_one_tool(), update_all_tools(), and the
# dispatcher/usage wiring around them.
#
# Sourced by run-tests.sh — do not `exit`, do not re-declare helpers, do not
# `set -e` in this file (see the isolation contract in run-tests.sh).
#
# Zero-network / zero-install guarantee: every subshell below redefines
# resolve_latest_in_major(), is_installed(), and the installer functions with
# fakes that never shell out and never reach a real package manager or
# remote host. REPO_ROOT and INSTALL_DIR are always mktemp sandboxes.

describe "update_one_tool: already-current short-circuit"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="1.0.0"
    # shellcheck disable=SC2034  # read via indirect expansion inside update_one_tool
    STUB_REPO="fake/stub"
    STUB_CALLS=0
    RESULTS=""
    FAIL_COUNT=0
    # shellcheck disable=SC2329  # fake installer: must never be called when already current
    _install_stub() { STUB_CALLS=$((STUB_CALLS + 1)); return 0; }
    # shellcheck disable=SC2329  # controllable verifier stub: always reports the pin present
    is_installed() { [[ "$2" = "1.0.0" ]]; }
    update_one_tool "stub" "1.0.0" "STUB_VERSION" "STUB_REPO" "_install_stub"
    echo "rc=$?"
    echo "RESULTS:$RESULTS"
    echo "FAIL_COUNT:$FAIL_COUNT"
    echo "CALLS:$STUB_CALLS"
  ) 2>&1
)
assert_contains "$out" "rc=0" "already-current: update_one_tool returns 0"
assert_contains "$out" "|1.0.0|ok" "already-current: status is ok"
assert_contains "$out" "FAIL_COUNT:0" "already-current: FAIL_COUNT stays 0"
assert_contains "$out" "CALLS:0" "already-current: installer is never invoked"

describe "update_one_tool: attempt 1 succeeds"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2034  # read via indirect expansion inside update_one_tool
    STUB_REPO="fake/stub"
    INSTALLED_NOW=false
    RESULTS=""
    FAIL_COUNT=0
    # shellcheck disable=SC2329  # fake installer: succeeds on the exact pin
    _install_stub() { INSTALLED_NOW=true; return 0; }
    # shellcheck disable=SC2329  # controllable verifier stub
    is_installed() { [[ "$INSTALLED_NOW" = true && "$2" = "1.0.0" ]]; }
    update_one_tool "stub" "1.0.0" "STUB_VERSION" "STUB_REPO" "_install_stub"
    echo "rc=$?"
    echo "RESULTS:$RESULTS"
    echo "FAIL_COUNT:$FAIL_COUNT"
  ) 2>&1
)
assert_contains "$out" "rc=0" "attempt-1-succeeds: update_one_tool returns 0"
assert_contains "$out" "|1.0.0|installed" "attempt-1-succeeds: status is installed"
assert_contains "$out" "FAIL_COUNT:0" "attempt-1-succeeds: FAIL_COUNT stays 0"

describe "update_one_tool: attempt 1 fails, fallback higher, attempt 2 succeeds"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2034  # read via indirect expansion inside update_one_tool
    STUB_REPO="fake/stub"
    INSTALLED_NOW=false
    RESULTS=""
    FAIL_COUNT=0
    FALLBACK_NOTES=""
    REPO_ROOT="$(mktemp -d)"
    trap 'rm -rf "$REPO_ROOT"' RETURN
    # shellcheck disable=SC2329  # fake installer: fails on the pin, succeeds on the fallback
    _install_stub() {
      if [[ "$STUB_VERSION" = "1.0.0" ]]; then
        return 1
      fi
      INSTALLED_NOW=true
      return 0
    }
    # shellcheck disable=SC2329  # controllable verifier stub
    is_installed() { [[ "$INSTALLED_NOW" = true && "$2" = "1.1.0" ]]; }
    # shellcheck disable=SC2329  # stub: never touches the network
    resolve_latest_in_major() { echo "1.1.0"; }
    update_one_tool "stub" "1.0.0" "STUB_VERSION" "STUB_REPO" "_install_stub"
    echo "rc=$?"
    echo "RESULTS:$RESULTS"
    echo "FAIL_COUNT:$FAIL_COUNT"
    if [[ -n "$FALLBACK_NOTES" ]]; then
      echo "NOTES_NONEMPTY:yes"
    else
      echo "NOTES_NONEMPTY:no"
    fi
    if [[ -f "${REPO_ROOT}/${UPDATE_LOG_NAME}" ]]; then
      echo "LOGEXISTS:yes"
    else
      echo "LOGEXISTS:no"
    fi
  ) 2>&1
)
assert_contains "$out" "rc=0" "fallback-succeeds: update_one_tool returns 0"
assert_contains "$out" "|1.1.0|fallback" "fallback-succeeds: status is fallback"
assert_contains "$out" "FAIL_COUNT:0" "fallback-succeeds: FAIL_COUNT is NOT incremented"
assert_contains "$out" "NOTES_NONEMPTY:yes" "fallback-succeeds: FALLBACK_NOTES is non-empty"
assert_contains "$out" "LOGEXISTS:no" "fallback-succeeds: no failure log is written"

describe "update_one_tool: fallback resolves lower than the pin (downgrade guard)"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2034  # read via indirect expansion inside update_one_tool
    STUB_REPO="fake/stub"
    RESULTS=""
    FAIL_COUNT=0
    STUB_ATTEMPT2_CALLS=0
    REPO_ROOT="$(mktemp -d)"
    trap 'rm -rf "$REPO_ROOT"' RETURN
    # shellcheck disable=SC2329  # fake installer: counts any call made at a non-pinned version
    _install_stub() {
      if [[ "$STUB_VERSION" != "0.69.3" ]]; then
        STUB_ATTEMPT2_CALLS=$((STUB_ATTEMPT2_CALLS + 1))
      fi
      return 0
    }
    # shellcheck disable=SC2329  # controllable verifier stub: never reports installed
    is_installed() { return 1; }
    # shellcheck disable=SC2329  # stub: returns a version below the pin's major.minor.patch
    resolve_latest_in_major() { echo "0.68.9"; }
    update_one_tool "trivy" "0.69.3" "STUB_VERSION" "STUB_REPO" "_install_stub"
    echo "rc=$?"
    echo "RESULTS:$RESULTS"
    echo "FAIL_COUNT:$FAIL_COUNT"
    echo "ATTEMPT2_CALLS:$STUB_ATTEMPT2_CALLS"
  ) 2>&1
)
assert_contains "$out" "rc=1" "downgrade-guard: update_one_tool returns 1"
assert_contains "$out" "|0.69.3|FAILED" "downgrade-guard: status is FAILED"
assert_contains "$out" "FAIL_COUNT:1" "downgrade-guard: FAIL_COUNT is incremented"
assert_contains "$out" "ATTEMPT2_CALLS:0" "downgrade-guard: attempt 2 is never made"
assert_contains "$out" "downgrade" "downgrade-guard: a downgrade warning is printed"

describe "update_one_tool: fallback resolution returns empty"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2034  # read via indirect expansion inside update_one_tool
    STUB_REPO="fake/stub"
    RESULTS=""
    FAIL_COUNT=0
    REPO_ROOT="$(mktemp -d)"
    trap 'rm -rf "$REPO_ROOT"' RETURN
    # shellcheck disable=SC2329  # fake installer: always fails
    _install_stub() { return 1; }
    # shellcheck disable=SC2329  # controllable verifier stub: never reports installed
    is_installed() { return 1; }
    # shellcheck disable=SC2329  # stub: simulates an unresolvable fallback (e.g. rate-limited)
    resolve_latest_in_major() { return 1; }
    update_one_tool "stub" "1.0.0" "STUB_VERSION" "STUB_REPO" "_install_stub"
    echo "rc=$?"
    echo "RESULTS:$RESULTS"
    echo "FAIL_COUNT:$FAIL_COUNT"
    echo "LOGLINES:$(wc -l < "${REPO_ROOT}/${UPDATE_LOG_NAME}" | tr -d ' ')"
  ) 2>&1
)
assert_contains "$out" "rc=1" "empty-fallback: update_one_tool returns 1"
assert_contains "$out" "|1.0.0|FAILED" "empty-fallback: status is FAILED"
assert_contains "$out" "FAIL_COUNT:1" "empty-fallback: FAIL_COUNT is incremented"
assert_contains "$out" "LOGLINES:1" "empty-fallback: exactly one log line is written"
assert_contains "$out" "rate limit" "empty-fallback: the warning mentions the rate limit"

describe "update_one_tool: fallback resolves to the same version as the pin"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2034  # read via indirect expansion inside update_one_tool
    STUB_REPO="fake/stub"
    RESULTS=""
    FAIL_COUNT=0
    STUB_CALLS=0
    REPO_ROOT="$(mktemp -d)"
    trap 'rm -rf "$REPO_ROOT"' RETURN
    # shellcheck disable=SC2329  # fake installer: always fails, counts every call
    _install_stub() { STUB_CALLS=$((STUB_CALLS + 1)); return 1; }
    # shellcheck disable=SC2329  # controllable verifier stub: never reports installed
    is_installed() { return 1; }
    # shellcheck disable=SC2329  # stub: resolves to the same version as the pin
    resolve_latest_in_major() { echo "0.69.3"; }
    update_one_tool "trivy" "0.69.3" "STUB_VERSION" "STUB_REPO" "_install_stub"
    echo "rc=$?"
    echo "RESULTS:$RESULTS"
    echo "CALLS:$STUB_CALLS"
  ) 2>&1
)
assert_contains "$out" "rc=1" "identical-fallback: update_one_tool returns 1"
assert_contains "$out" "|0.69.3|FAILED" "identical-fallback: status is FAILED"
assert_contains "$out" "CALLS:1" "identical-fallback: attempt 2 is not made (installer called exactly once, for attempt 1)"

describe "update_one_tool: attempt 1 and attempt 2 both fail"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2034  # read via indirect expansion inside update_one_tool
    STUB_REPO="fake/stub"
    RESULTS=""
    FAIL_COUNT=0
    REPO_ROOT="$(mktemp -d)"
    trap 'rm -rf "$REPO_ROOT"' RETURN
    # shellcheck disable=SC2329  # fake installer: always fails
    _install_stub() { return 1; }
    # shellcheck disable=SC2329  # controllable verifier stub: never reports installed
    is_installed() { return 1; }
    # shellcheck disable=SC2329  # stub: resolves a higher fallback that also fails to install
    resolve_latest_in_major() { echo "1.1.0"; }
    update_one_tool "stub" "1.0.0" "STUB_VERSION" "STUB_REPO" "_install_stub"
    echo "rc=$?"
    echo "RESULTS:$RESULTS"
    echo "FAIL_COUNT:$FAIL_COUNT"
    echo "LOGLINES:$(wc -l < "${REPO_ROOT}/${UPDATE_LOG_NAME}" | tr -d ' ')"
  ) 2>&1
)
assert_contains "$out" "rc=1" "both-fail: update_one_tool returns 1"
assert_contains "$out" "|1.0.0|FAILED" "both-fail: status is FAILED"
assert_contains "$out" "FAIL_COUNT:1" "both-fail: FAIL_COUNT is incremented"
assert_contains "$out" "LOGLINES:1" "both-fail: exactly one log line is written"

describe "update_one_tool: survives under set -e (never terminates the caller)"

out=$(
  /bin/bash -euo pipefail -c '
    source "'"$SETUP_SH"'"
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2034  # read via indirect expansion inside update_one_tool
    STUB_REPO="fake/stub"
    REPO_ROOT="$(mktemp -d)"
    _install_stub() { return 1; }
    is_installed() { return 1; }
    resolve_latest_in_major() { return 1; }
    update_one_tool "stub" "1.0.0" "STUB_VERSION" "STUB_REPO" "_install_stub" || true
    rm -rf "$REPO_ROOT"
    echo "SURVIVED"
  ' 2>&1
)
assert_contains "$out" "SURVIVED" "a fully-failed update_one_tool does not terminate the calling shell under set -euo pipefail"
