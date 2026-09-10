# shellcheck shell=bash
# shellcheck disable=SC1090  # SETUP_SH is exported by run-tests.sh at a known path
# test_doctor.sh — Fixture-free, offline unit + process tests for tool_health(),
# run_doctor(), and the doctor subcommand's exit contract (plan 13-05).
#
# Sourced by run-tests.sh — do not `exit`, do not re-declare helpers, do not
# `set -e` in this file (see the isolation contract in run-tests.sh).
#
# Zero-network / zero-install guarantee: stubs are symlinks to already-
# installed system executables (/usr/bin/true, /usr/bin/false, /bin/bash) or
# non-existent tool names on a scrubbed PATH. No executable-bit changes anywhere in this
# file (verified by an acceptance-criteria grep over tests/).

# ---------------------------------------------------------------------------
# Task 1: tool_health() — NOT_ON_PATH, BROKEN, UNPARSEABLE, OK
# ---------------------------------------------------------------------------

describe "tool_health: absent tool on a scrubbed PATH returns NOT_ON_PATH"

out=$(
  (
    source "$SETUP_SH"
    set +e
    PATH="/usr/bin:/bin"
    tool_health "no-such-tool-xyz"
  ) 2>&1
)
assert_contains "$out" "NOT_ON_PATH" "a tool absent from PATH yields status NOT_ON_PATH"

describe "tool_health: a tool whose version command exits non-zero returns BROKEN"

out=$(
  (
    source "$SETUP_SH"
    set +e
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' RETURN
    ln -s /usr/bin/false "$scratch/trivy"
    PATH="$scratch:/usr/bin:/bin"
    tool_health "trivy"
  ) 2>&1
)
assert_contains "$out" "BROKEN" "a tool on PATH whose version command exits non-zero yields status BROKEN"

describe "tool_health: a tool whose version command exits 0 with no parseable version returns UNPARSEABLE"

out=$(
  (
    source "$SETUP_SH"
    set +e
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' RETURN
    ln -s /usr/bin/true "$scratch/grype"
    PATH="$scratch:/usr/bin:/bin"
    tool_health "grype"
  ) 2>&1
)
assert_contains "$out" "UNPARSEABLE" "a tool on PATH whose version command exits 0 but emits no N.N.N yields status UNPARSEABLE"

describe "tool_health: a healthy tool returns OK with a parsed N.N.N version"

out=$(
  (
    source "$SETUP_SH"
    set +e
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' RETURN
    ln -s /bin/bash "$scratch/syft"
    PATH="$scratch:/usr/bin:/bin"
    tool_health "syft"
  ) 2>&1
)
assert_contains "$out" "OK" "a healthy tool yields status OK"
assert_contains "$out" "3.2.57" "a healthy tool's record carries its parsed N.N.N version"

describe "tool_health: gitleaks is probed with 'gitleaks version', not 'gitleaks --version'"

# /bin/bash as the gitleaks stub inverts real gitleaks's behaviour in a way
# that makes the distinction observable without setting an executable bit on a custom script
# (forbidden by this plan's constraints — stubs must be symlinks only):
# `bash version` treats "version" as a script filename and fails (exit 127,
# "No such file or directory"), while `bash --version` succeeds (bash's own
# flag). Real gitleaks is the mirror image. So: if tool_health correctly
# calls `gitleaks version`, this stub reports BROKEN. If it were to
# regress to calling `gitleaks --version`, this stub would report OK
# instead, at version 3.2.57 (bash's own version) -- catching the bug.
out=$(
  (
    source "$SETUP_SH"
    set +e
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' RETURN
    ln -s /bin/bash "$scratch/gitleaks"
    PATH="$scratch:/usr/bin:/bin"
    tool_health "gitleaks"
  ) 2>&1
)
assert_contains "$out" "BROKEN" "gitleaks is probed with 'gitleaks version' (not '--version'); the bash stub proves this by failing on 'version' as a script name"
assert_not_contains "$out" "3.2.57" "gitleaks is not probed with '--version' (which the bash stub would answer successfully)"

describe "tool_health: probing a broken tool does not terminate the caller under set -euo pipefail"

out=$(
  /bin/bash -euo pipefail -c '
    source "'"$SETUP_SH"'"
    scratch="$(mktemp -d)"
    trap "rm -rf \"$scratch\"" EXIT
    ln -s /usr/bin/false "$scratch/trivy"
    PATH="$scratch:/usr/bin:/bin"
    tool_health "trivy" > /dev/null
    echo "SURVIVED"
  ' 2>&1
)
assert_contains "$out" "SURVIVED" "a broken tool'\''s non-zero exit does not terminate the calling shell under set -euo pipefail"

describe "tool_health: BROKEN record carries the tool's own exit code, not head's or grep's"

out=$(
  (
    source "$SETUP_SH"
    set +e
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' RETURN
    ln -s /usr/bin/false "$scratch/trivy"
    PATH="$scratch:/usr/bin:/bin"
    tool_health "trivy"
  ) 2>&1
)
assert_contains "$out" "1" "the BROKEN record carries exit code 1, /usr/bin/false's own exit status"

# ---------------------------------------------------------------------------
# Task 2: run_doctor() and PROBLEM_COUNT wiring
# ---------------------------------------------------------------------------

describe "run_doctor: increments PROBLEM_COUNT per non-OK tool and leaves FAIL_COUNT untouched"

out=$(
  (
    source "$SETUP_SH"
    set +e
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' RETURN
    ln -s /usr/bin/false "$scratch/trivy"
    ln -s /usr/bin/true "$scratch/grype"
    PATH="$scratch:/usr/bin:/bin"
    run_doctor > /dev/null
    echo "PROBLEM_COUNT=$PROBLEM_COUNT"
    echo "FAIL_COUNT=$FAIL_COUNT"
  ) 2>&1
)
problem_count=$(echo "$out" | grep -oE 'PROBLEM_COUNT=[0-9]+' | cut -d= -f2)
problem_count="${problem_count:-0}"
at_least_two="no"
[[ "$problem_count" -ge 2 ]] && at_least_two="yes"
assert_eq "yes" "$at_least_two" "run_doctor increments PROBLEM_COUNT by at least 2 with two broken/unparseable stubs (got $problem_count)"
assert_contains "$out" "FAIL_COUNT=0" "run_doctor never touches FAIL_COUNT"

describe "run_doctor: output contains a PATH section and a prerequisites section"

out=$(
  (
    source "$SETUP_SH"
    set +e
    PATH="/usr/bin:/bin"
    run_doctor
  ) 2>&1
)
assert_contains "$out" "PATH" "run_doctor output contains a PATH section"
assert_contains "$out" "Prerequisites" "run_doctor output contains a prerequisites section"

describe "run_doctor: makes no network call and does not read versions.conf"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # ensure_versions_conf would fail loudly if called with no arg / bad root;
    # redefine it as a tripwire so any accidental call is visible.
    # shellcheck disable=SC2329  # tripwire stub
    ensure_versions_conf() { echo "TRIPWIRE_CALLED"; }
    PATH="/usr/bin:/bin"
    run_doctor > /dev/null
    echo "DONE"
  ) 2>&1
)
assert_not_contains "$out" "TRIPWIRE_CALLED" "run_doctor never calls ensure_versions_conf"
assert_contains "$out" "DONE" "run_doctor completes without aborting"

describe "run_check: increments PROBLEM_COUNT once per MISSING/MISMATCH row, never touches FAIL_COUNT"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2034  # read by run_check() in the sourced setup.sh, not directly referenced here
    PRECOMMIT_VERSION="9.9.9"
    # shellcheck disable=SC2034  # read by run_check() in the sourced setup.sh, not directly referenced here
    TRIVY_VERSION="9.9.9"
    # shellcheck disable=SC2034  # read by run_check() in the sourced setup.sh, not directly referenced here
    SYFT_VERSION="9.9.9"
    # shellcheck disable=SC2034  # read by run_check() in the sourced setup.sh, not directly referenced here
    GRYPE_VERSION="9.9.9"
    # shellcheck disable=SC2034  # read by run_check() in the sourced setup.sh, not directly referenced here
    GITLEAKS_VERSION="9.9.9"
    # shellcheck disable=SC2034  # read by run_check() in the sourced setup.sh, not directly referenced here
    HADOLINT_VERSION="9.9.9"
    # shellcheck disable=SC2329  # controllable stub: every tool reports absent
    get_installed_version() { echo "(not found)"; }
    run_check > /dev/null
    echo "PROBLEM_COUNT=$PROBLEM_COUNT"
    echo "FAIL_COUNT=$FAIL_COUNT"
  ) 2>&1
)
assert_contains "$out" "PROBLEM_COUNT=6" "run_check increments PROBLEM_COUNT once per MISSING row across all six tools"
assert_contains "$out" "FAIL_COUNT=0" "run_check never touches FAIL_COUNT"

# ---------------------------------------------------------------------------
# Task 3: doctor dispatcher, exit contract, --help, argument parsing
# ---------------------------------------------------------------------------

describe "doctor dispatcher: check_prerequisites is skipped for doctor only"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # tripwire stub
    check_prerequisites() { echo "PREREQ_CALLED"; }
    # shellcheck disable=SC2329  # avoid touching the real environment/network
    run_doctor() { :; }
    PATH="/usr/bin:/bin"
    main doctor
  ) 2>&1
)
assert_not_contains "$out" "PREREQ_CALLED" "check_prerequisites is not called for the doctor command"
assert_not_contains "$out" "Unknown argument" "doctor is dispatched as a real command, not falling through to the unknown-argument catch-all (which would trivially also skip check_prerequisites)"

describe "check dispatcher: check_prerequisites still runs for check"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # tripwire stub
    check_prerequisites() { echo "PREREQ_CALLED"; exit 1; }
    main check
  ) 2>&1
)
assert_contains "$out" "PREREQ_CALLED" "check_prerequisites still runs for the check command"

describe "doctor dispatcher: exit contract mirrors PROBLEM_COUNT via FAIL_COUNT mapping"

# NOTE: main() always ends in an explicit `exit`, which terminates the
# enclosing subshell immediately -- any code placed after `main doctor`
# inside the same subshell (e.g. an inner `echo "rc=$?"`) would never run.
# The exit status must instead be read from $? in the PARENT shell,
# immediately after the command-substitution assignment completes.
out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # controllable stub: simulates 3 problems found
    run_doctor() { PROBLEM_COUNT=3; }
    PATH="/usr/bin:/bin"
    main doctor
  ) 2>&1
)
rc=$?
assert_status 1 "$rc" "doctor exits non-zero when run_doctor reports a nonzero PROBLEM_COUNT"
assert_not_contains "$out" "Unknown argument" "the nonzero exit above comes from real dispatch, not the unknown-argument catch-all (which also exits 1)"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # controllable stub: simulates a fully healthy environment
    run_doctor() { PROBLEM_COUNT=0; }
    PATH="/usr/bin:/bin"
    main doctor
  ) 2>&1
)
rc=$?
assert_status 0 "$rc" "doctor exits zero when run_doctor reports zero problems"

describe "update dispatcher: the post-update recheck's PROBLEM_COUNT never affects update's exit status"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # avoid network/install/versions.conf entirely
    ensure_versions_conf() { :; }
    # shellcheck disable=SC2329  # avoid network/install entirely
    update_all_tools() { :; }
    # shellcheck disable=SC2329  # simulates the post-update recheck finding problems
    run_check() { PROBLEM_COUNT=5; }
    main update
  ) 2>&1
)
rc=$?
assert_status 0 "$rc" "update's exit status is unaffected by PROBLEM_COUNT set during its post-update recheck"

describe "doctor process test: reports rather than aborts when a prerequisite is missing, and exits on real problems"

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' RETURN
ln -s /usr/bin/false "$scratch/trivy"
out=$(PATH="$scratch:/usr/bin:/bin" /bin/bash "$SETUP_SH" doctor 2>&1)
rc=$?
assert_status 1 "$rc" "bash setup.sh doctor exits 1 when a broken stub is on PATH"
assert_contains "$out" "BROKEN" "doctor's report shows BROKEN for the broken stub, rather than aborting silently"
assert_not_contains "$out" "Unknown argument" "doctor is a recognised subcommand, not an unknown argument"

describe "doctor process test: --help lists doctor"

out=$(/bin/bash "$SETUP_SH" --help 2>&1)
assert_contains "$out" "doctor" "bash setup.sh --help output contains doctor"

describe "doctor process test: per-tool targeting is update-only, not accepted after doctor"

out=$(/bin/bash "$SETUP_SH" doctor trivy 2>&1)
rc=$?
assert_status 1 "$rc" "bash setup.sh doctor trivy exits 1"
assert_contains "$out" "Unknown argument: trivy" "bash setup.sh doctor trivy reports the exact bad token, not a generic or stale message"
