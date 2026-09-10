# shellcheck shell=bash
# shellcheck disable=SC1090  # SETUP_SH is exported by run-tests.sh at a known path
# test_update_primitives.sh — Fixture-free, offline unit tests for
# attempt_install() and log_update_failure(), the two primitives the D-04
# update loop is composed from.
#
# Sourced by run-tests.sh — do not `exit`, do not re-declare helpers, do not
# `set -e` in this file (see the isolation contract in run-tests.sh).
#
# Zero-network / zero-install guarantee: every subshell below redefines the
# installer boundary with a fake function that never shells out, and never
# calls pipx, curl, or api.github.com.

describe "attempt_install: success decided solely by is_installed, not installer exit code"

# Installer returns 1 (failure) but is_installed reports the version present
# (e.g. it was already installed by a prior step) -> attempt_install must
# return 0. This is the mirror of the pipx no-op case below.
out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_INSTALLED_VERSION="9.9.9"
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2329  # fake installer: reports failure on purpose
    _install_stub() { return 1; }
    # shellcheck disable=SC2329  # controllable verifier stub
    is_installed() { [[ "$2" = "$STUB_INSTALLED_VERSION" ]]; }
    attempt_install "stub" "$STUB_INSTALLED_VERSION" "STUB_VERSION" "_install_stub"
    echo "rc=$?"
  ) 2>&1
)
assert_contains "$out" "rc=0" "attempt_install returns 0 when the tool is at the requested version, even though the installer returned non-zero"

# Installer returns 0 (success) but is_installed reports the version absent
# -- this is the verified pipx exit-0-no-op regression case. attempt_install
# must return 1.
out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2329  # fake installer: reports success but changes nothing (pipx no-op)
    _install_stub_ok() { return 0; }
    # shellcheck disable=SC2329  # controllable verifier stub: always reports absent
    is_installed() { return 1; }
    attempt_install "stub" "9.9.9" "STUB_VERSION" "_install_stub_ok"
    echo "rc=$?"
  ) 2>&1
)
assert_contains "$out" "rc=1" "attempt_install returns 1 when the tool is NOT at the requested version, even though the installer returned 0 (pipx no-op regression guard)"

describe "attempt_install: survives a failing installer under set -e"

out=$(
  /bin/bash -euo pipefail -c '
    source "'"$SETUP_SH"'"
    STUB_VERSION="0.0.0"
    _install_stub() { return 1; }
    is_installed() { return 1; }
    attempt_install "stub" "9.9.9" "STUB_VERSION" "_install_stub" || true
    echo "SURVIVED"
  ' 2>&1
)
assert_contains "$out" "SURVIVED" "a non-zero installer exit does not terminate the calling shell under set -euo pipefail"

describe "attempt_install: version global is overridden during the attempt and restored after"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2329  # fake installer: records the version global visible during the attempt
    _install_stub_capture() { echo "SEEN:$STUB_VERSION"; return 0; }
    # shellcheck disable=SC2329  # controllable verifier stub: always reports present
    is_installed() { return 0; }
    attempt_install "stub" "9.9.9" "STUB_VERSION" "_install_stub_capture" > /tmp/attempt_install_capture.$$ 2>&1
    cat /tmp/attempt_install_capture.$$
    rm -f /tmp/attempt_install_capture.$$
    echo "AFTER:$STUB_VERSION"
  ) 2>&1
)
assert_contains "$out" "SEEN:9.9.9" "the version global is visible to the installer during the attempt"
assert_contains "$out" "AFTER:0.0.0" "the version global is restored to its previous value after the attempt"

describe "attempt_install: installer output is suppressed unless VERBOSE is true"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2034  # read by attempt_install() in the sourced setup.sh
    VERBOSE=false
    # shellcheck disable=SC2329  # fake installer: echoes a marker to prove output suppression
    _install_stub_marker() { echo "MARKER_OUTPUT"; return 0; }
    # shellcheck disable=SC2329  # controllable verifier stub: always reports present
    is_installed() { return 0; }
    attempt_install "stub" "9.9.9" "STUB_VERSION" "_install_stub_marker"
    echo "DONE"
  ) 2>&1
)
assert_not_contains "$out" "MARKER_OUTPUT" "installer output is suppressed when VERBOSE is false"

out=$(
  (
    source "$SETUP_SH"
    set +e
    STUB_VERSION="0.0.0"
    # shellcheck disable=SC2034  # read by attempt_install() in the sourced setup.sh
    VERBOSE=true
    # shellcheck disable=SC2329  # fake installer: echoes a marker to prove output is not suppressed
    _install_stub_marker() { echo "MARKER_OUTPUT"; return 0; }
    # shellcheck disable=SC2329  # controllable verifier stub: always reports present
    is_installed() { return 0; }
    attempt_install "stub" "9.9.9" "STUB_VERSION" "_install_stub_marker"
  ) 2>&1
)
assert_contains "$out" "MARKER_OUTPUT" "installer output appears when VERBOSE is true"
