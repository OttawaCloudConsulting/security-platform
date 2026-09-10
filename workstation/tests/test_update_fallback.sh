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

# ---------------------------------------------------------------------------
# update_all_tools() and update-aware summary output
# ---------------------------------------------------------------------------
#
# attempt_install() (not the real _install_* functions) is stubbed directly
# in every test below — it is already unit-tested in plan 03, and it is the
# cleanest network boundary: update_one_tool calls it by name, so stubbing
# here guarantees zero curl/pipx/network calls no matter what the record
# array contains. All six pinned *_VERSION globals are set explicitly (not
# sourced from a real versions.conf) because sourcing setup.sh does not
# source versions.conf, and set -u (inherited from setup.sh) would otherwise
# kill the subshell on first reference.

describe "update_all_tools: default run processes all six tools in the install order"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2034  # PRECOMMIT_VERSION read by update_all_tools' record array in the sourced setup.sh
    PRECOMMIT_VERSION="4.2.0"
    # shellcheck disable=SC2034  # TRIVY_VERSION read by update_all_tools' record array in the sourced setup.sh
    TRIVY_VERSION="0.69.3"
    # shellcheck disable=SC2034  # SYFT_VERSION read by update_all_tools' record array in the sourced setup.sh
    SYFT_VERSION="1.42.2"
    # shellcheck disable=SC2034  # GRYPE_VERSION read by update_all_tools' record array in the sourced setup.sh
    GRYPE_VERSION="0.109.1"
    # shellcheck disable=SC2034  # GITLEAKS_VERSION read by update_all_tools' record array in the sourced setup.sh
    GITLEAKS_VERSION="8.30.0"
    # shellcheck disable=SC2034  # HADOLINT_VERSION read by update_all_tools' record array in the sourced setup.sh
    HADOLINT_VERSION="2.14.0"
    # shellcheck disable=SC2034  # read by update_all_tools in the sourced setup.sh
    UPDATE_TARGETS=""
    RESULTS=""
    FAIL_COUNT=0
    REPO_ROOT="$(mktemp -d)"
    INSTALL_DIR="$(mktemp -d)"
    trap 'rm -rf "$REPO_ROOT" "$INSTALL_DIR"' RETURN
    # shellcheck disable=SC2329  # controllable verifier stub: nothing pre-installed
    is_installed() { return 1; }
    # shellcheck disable=SC2329  # stub: every tool's attempt 1 succeeds, no network
    attempt_install() { return 0; }
    update_all_tools
    tool_order=$(printf "%b" "$RESULTS" | awk -F'|' 'NF{print $1}' | tr '\n' ',')
    echo "ORDER:$tool_order"
  ) 2>&1
)
assert_contains "$out" "ORDER:pre-commit,trivy,syft,grype,gitleaks,hadolint," "update_all_tools processes all six tools in install_all_tools order"

describe "update_all_tools: selective targeting via UPDATE_TARGETS"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2034  # PRECOMMIT_VERSION read by update_all_tools' record array in the sourced setup.sh
    PRECOMMIT_VERSION="4.2.0"
    # shellcheck disable=SC2034  # TRIVY_VERSION read by update_all_tools' record array in the sourced setup.sh
    TRIVY_VERSION="0.69.3"
    # shellcheck disable=SC2034  # SYFT_VERSION read by update_all_tools' record array in the sourced setup.sh
    SYFT_VERSION="1.42.2"
    # shellcheck disable=SC2034  # GRYPE_VERSION read by update_all_tools' record array in the sourced setup.sh
    GRYPE_VERSION="0.109.1"
    # shellcheck disable=SC2034  # GITLEAKS_VERSION read by update_all_tools' record array in the sourced setup.sh
    GITLEAKS_VERSION="8.30.0"
    # shellcheck disable=SC2034  # HADOLINT_VERSION read by update_all_tools' record array in the sourced setup.sh
    HADOLINT_VERSION="2.14.0"
    # shellcheck disable=SC2034  # read by update_all_tools in the sourced setup.sh
    UPDATE_TARGETS="trivy"
    RESULTS=""
    FAIL_COUNT=0
    REPO_ROOT="$(mktemp -d)"
    INSTALL_DIR="$(mktemp -d)"
    trap 'rm -rf "$REPO_ROOT" "$INSTALL_DIR"' RETURN
    # shellcheck disable=SC2329  # controllable verifier stub
    is_installed() { return 1; }
    # shellcheck disable=SC2329  # stub: no network
    attempt_install() { return 0; }
    update_all_tools
    tool_order=$(printf "%b" "$RESULTS" | awk -F'|' 'NF{print $1}' | tr '\n' ',')
    echo "ORDER:$tool_order"
  ) 2>&1
)
assert_contains "$out" "ORDER:trivy," "UPDATE_TARGETS=trivy processes only the trivy record, not the other five"

describe "update_all_tools: a failing tool does not stop later tools in the list"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2034  # PRECOMMIT_VERSION read by update_all_tools' record array in the sourced setup.sh
    PRECOMMIT_VERSION="4.2.0"
    # shellcheck disable=SC2034  # TRIVY_VERSION read by update_all_tools' record array in the sourced setup.sh
    TRIVY_VERSION="0.69.3"
    # shellcheck disable=SC2034  # SYFT_VERSION read by update_all_tools' record array in the sourced setup.sh
    SYFT_VERSION="1.42.2"
    # shellcheck disable=SC2034  # GRYPE_VERSION read by update_all_tools' record array in the sourced setup.sh
    GRYPE_VERSION="0.109.1"
    # shellcheck disable=SC2034  # GITLEAKS_VERSION read by update_all_tools' record array in the sourced setup.sh
    GITLEAKS_VERSION="8.30.0"
    # shellcheck disable=SC2034  # HADOLINT_VERSION read by update_all_tools' record array in the sourced setup.sh
    HADOLINT_VERSION="2.14.0"
    # shellcheck disable=SC2034  # read by update_all_tools in the sourced setup.sh
    UPDATE_TARGETS="trivy syft"
    RESULTS=""
    FAIL_COUNT=0
    REPO_ROOT="$(mktemp -d)"
    INSTALL_DIR="$(mktemp -d)"
    trap 'rm -rf "$REPO_ROOT" "$INSTALL_DIR"' RETURN
    # shellcheck disable=SC2329  # controllable verifier stub
    is_installed() { return 1; }
    # shellcheck disable=SC2329  # stub: trivy always fails (both attempts), syft always succeeds
    attempt_install() { [[ "$1" = "trivy" ]] && return 1; return 0; }
    # shellcheck disable=SC2329  # stub: valid same-major fallback for trivy, still rejected by the always-failing installer
    resolve_latest_in_major() { echo "0.69.4"; }
    update_all_tools
    echo "RESULTS:$RESULTS"
    echo "FAIL_COUNT:$FAIL_COUNT"
    tool_order=$(printf "%b" "$RESULTS" | awk -F'|' 'NF{print $1}' | tr '\n' ',')
    echo "ORDER:$tool_order"
  ) 2>&1
)
assert_contains "$out" "ORDER:trivy,syft," "both tools appear in RESULTS even though trivy failed"
assert_contains "$out" "trivy|0.69.3|FAILED" "trivy is recorded as FAILED"
assert_contains "$out" "syft|1.42.2|installed" "syft still updates after trivy's failure"
assert_contains "$out" "FAIL_COUNT:1" "only the one genuinely failing tool contributes to FAIL_COUNT"

describe "update_all_tools: exports INSTALL_DIR onto PATH for the duration of the loop"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2034  # PRECOMMIT_VERSION read by update_all_tools' record array in the sourced setup.sh
    PRECOMMIT_VERSION="4.2.0"
    # shellcheck disable=SC2034  # TRIVY_VERSION read by update_all_tools' record array in the sourced setup.sh
    TRIVY_VERSION="0.69.3"
    # shellcheck disable=SC2034  # SYFT_VERSION read by update_all_tools' record array in the sourced setup.sh
    SYFT_VERSION="1.42.2"
    # shellcheck disable=SC2034  # GRYPE_VERSION read by update_all_tools' record array in the sourced setup.sh
    GRYPE_VERSION="0.109.1"
    # shellcheck disable=SC2034  # GITLEAKS_VERSION read by update_all_tools' record array in the sourced setup.sh
    GITLEAKS_VERSION="8.30.0"
    # shellcheck disable=SC2034  # HADOLINT_VERSION read by update_all_tools' record array in the sourced setup.sh
    HADOLINT_VERSION="2.14.0"
    # shellcheck disable=SC2034  # read by update_all_tools in the sourced setup.sh
    UPDATE_TARGETS="trivy"
    RESULTS=""
    FAIL_COUNT=0
    REPO_ROOT="$(mktemp -d)"
    INSTALL_DIR="$(mktemp -d)"
    trap 'rm -rf "$REPO_ROOT" "$INSTALL_DIR"' RETURN
    # shellcheck disable=SC2329  # controllable verifier stub
    is_installed() { return 1; }
    # shellcheck disable=SC2329  # stub: no network
    attempt_install() { return 0; }
    update_all_tools
    if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
      echo "ONPATH:yes"
    else
      echo "ONPATH:no"
    fi
  ) 2>&1
)
assert_contains "$out" "ONPATH:yes" "update_all_tools exports INSTALL_DIR onto PATH"

describe "print_summary: optional noun/verb arguments default to existing install wording"

out=$(
  (
    source "$SETUP_SH"
    set +e
    RESULTS=""
    FAIL_COUNT=1
    add_result "stub" "1.0.0" "FAILED"
    print_summary
  ) 2>&1
)
assert_contains "$out" "Security Tool Installation Summary" "print_summary with no argument keeps the existing install-time title"
assert_contains "$out" "failed to install" "print_summary with no argument keeps the existing install-time warning wording"

out=$(
  (
    source "$SETUP_SH"
    set +e
    RESULTS=""
    FAIL_COUNT=1
    add_result "stub" "1.0.0" "FAILED"
    print_summary "Update" "update"
  ) 2>&1
)
assert_contains "$out" "Security Tool Update Summary" "print_summary accepts a custom noun for the update run"
assert_contains "$out" "failed to update" "print_summary accepts a custom verb for the update run"

describe "print_fallback_notes: prints one NOTE line per accumulated fallback, nothing when empty"

out=$(
  (
    source "$SETUP_SH"
    set +e
    FALLBACK_NOTES="trivy|0.70.0|0.69.3\n"
    print_fallback_notes
  ) 2>&1
)
assert_contains "$out" "NOTE:" "print_fallback_notes emits a NOTE: line when FALLBACK_NOTES is non-empty"
assert_contains "$out" "trivy" "print_fallback_notes names the tool"
assert_contains "$out" "0.70.0" "print_fallback_notes names the installed fallback version"
assert_contains "$out" "0.69.3" "print_fallback_notes names the pinned version"

out=$(
  (
    source "$SETUP_SH"
    set +e
    FALLBACK_NOTES=""
    print_fallback_notes
  ) 2>&1
)
assert_eq "" "$out" "print_fallback_notes prints nothing when FALLBACK_NOTES is empty"

# ---------------------------------------------------------------------------
# Dispatcher, usage(), and the update subcommand's argument parsing
# ---------------------------------------------------------------------------
#
# Process-level tests only — no stubs, no sourcing. These exercise the real
# main-guard entrypoint (`/bin/bash setup.sh ...`), never calling `update`
# without a bogus tool name so no real installer or network path is reached.

describe "update subcommand: dispatcher, usage, and argument parsing"

out=$(/bin/bash "$SETUP_SH" --help 2>&1)
assert_contains "$out" "update" "--help output lists the update command"

out=$(/bin/bash "$SETUP_SH" update bogus-tool 2>&1)
rc=$?
assert_status 1 "$rc" "update with an unrecognised tool name exits 1"
assert_contains "$out" "Unknown argument: bogus-tool" "update with an unrecognised tool name reports the exact bad token"

out=$(/bin/bash "$SETUP_SH" bogus-tool 2>&1)
rc=$?
assert_status 1 "$rc" "an unrecognised argument with no update command exits 1"
assert_contains "$out" "Unknown argument: bogus-tool" "an unrecognised argument with no update command reports the exact bad token"

out=$(/bin/bash "$SETUP_SH" --help 2>&1)
assert_not_contains "$out" './setup.sh' "help output never uses the ./setup.sh invocation form"
