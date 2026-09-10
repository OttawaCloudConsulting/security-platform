# shellcheck shell=bash
# shellcheck disable=SC1090  # SETUP_SH is exported by run-tests.sh at a known path
# test_os_arch_detection.sh — Offline unit tests for detect_os(), detect_arch(),
# get_gitleaks_os(), get_gitleaks_arch(), get_hadolint_os(), get_hadolint_arch().
#
# Sourced by run-tests.sh — do not `exit`, do not re-declare helpers, do not
# `set -e` in this file (see the isolation contract in run-tests.sh).
#
# `uname` is stubbed per-subshell so this suite never depends on (or is
# skewed by) the actual host OS/architecture it happens to run on.

describe "detect_os / detect_arch: macOS arm64 (Darwin/arm64)"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines detect_os/detect_arch's uname dependency
    uname() { case "$1" in -s) echo "Darwin" ;; -m) echo "arm64" ;; esac; }
    os=$(detect_os); echo "os=$os"
    arch=$(detect_arch); echo "arch=$arch"
  ) 2>&1
)
assert_contains "$out" "os=Darwin" "detect_os reports Darwin on macOS"
assert_contains "$out" "arch=arm64" "detect_arch reports arm64 for uname -m=arm64"

describe "detect_os / detect_arch: macOS x86_64 (Darwin/x86_64)"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines detect_os/detect_arch's uname dependency
    uname() { case "$1" in -s) echo "Darwin" ;; -m) echo "x86_64" ;; esac; }
    os=$(detect_os); echo "os=$os"
    arch=$(detect_arch); echo "arch=$arch"
  ) 2>&1
)
assert_contains "$out" "os=Darwin" "detect_os reports Darwin on macOS (x86_64 host)"
assert_contains "$out" "arch=x86_64" "detect_arch reports x86_64 for uname -m=x86_64"

describe "detect_os / detect_arch: Linux x86_64"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines detect_os/detect_arch's uname dependency
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "x86_64" ;; esac; }
    os=$(detect_os); echo "os=$os"
    arch=$(detect_arch); echo "arch=$arch"
  ) 2>&1
)
assert_contains "$out" "os=Linux" "detect_os reports Linux"
assert_contains "$out" "arch=x86_64" "detect_arch reports x86_64 on Linux x86_64"

describe "detect_os / detect_arch: Linux aarch64 normalizes to arm64"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines detect_os/detect_arch's uname dependency
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "aarch64" ;; esac; }
    os=$(detect_os); echo "os=$os"
    arch=$(detect_arch); echo "arch=$arch"
  ) 2>&1
)
assert_contains "$out" "os=Linux" "detect_os reports Linux (aarch64 host)"
assert_contains "$out" "arch=arm64" "detect_arch normalizes uname -m=aarch64 to arm64"

describe "detect_os: unsupported OS errors and does not kill the calling shell"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines detect_os's uname dependency
    uname() { case "$1" in -s) echo "SunOS" ;; -m) echo "x86_64" ;; esac; }
    # detect_os calls `exit 1` (not `return 1`) on an unsupported OS. Called
    # bare, that exit would kill this whole test subshell before SURVIVED is
    # echoed. Wrapping the call in its own $( ) confines the exit to that
    # inner subshell, letting this outer subshell observe the aftermath —
    # exactly how detect_os is actually invoked in setup.sh (os=$(detect_os)).
    msg=$(detect_os 2>&1)
    rc=$?
    echo "$msg"
    echo "rc=$rc"
    echo "SURVIVED"
  ) 2>&1
)
assert_contains "$out" "Unsupported OS" "detect_os reports an error for an unrecognized uname -s"
assert_contains "$out" "SURVIVED" "the calling subshell survives detect_os's internal exit (function runs in its own $( ) substitution)"

describe "detect_arch: unsupported architecture errors and does not kill the calling shell"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines detect_arch's uname dependency
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "riscv64" ;; esac; }
    # See the detect_os unsupported-OS case above for why the call is wrapped
    # in its own $( ) rather than invoked bare.
    msg=$(detect_arch 2>&1)
    rc=$?
    echo "$msg"
    echo "rc=$rc"
    echo "SURVIVED"
  ) 2>&1
)
assert_contains "$out" "Unsupported architecture" "detect_arch reports an error for an unrecognized uname -m"
assert_contains "$out" "SURVIVED" "the calling subshell survives detect_arch's internal exit (function runs in its own $( ) substitution)"

describe "get_gitleaks_os / get_gitleaks_arch: gitleaks release-asset naming"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines get_gitleaks_os/get_gitleaks_arch's uname dependency
    uname() { case "$1" in -s) echo "Darwin" ;; -m) echo "arm64" ;; esac; }
    echo "os=$(get_gitleaks_os)"
    echo "arch=$(get_gitleaks_arch)"
  ) 2>&1
)
assert_contains "$out" "os=darwin" "get_gitleaks_os maps Darwin to lowercase 'darwin'"
assert_contains "$out" "arch=arm64" "get_gitleaks_arch maps arm64 to 'arm64'"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines get_gitleaks_os/get_gitleaks_arch's uname dependency
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "x86_64" ;; esac; }
    echo "os=$(get_gitleaks_os)"
    echo "arch=$(get_gitleaks_arch)"
  ) 2>&1
)
assert_contains "$out" "os=linux" "get_gitleaks_os maps Linux to lowercase 'linux'"
assert_contains "$out" "arch=x64" "get_gitleaks_arch maps x86_64 to gitleaks-specific 'x64' (not 'x86_64')"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines get_gitleaks_arch's uname dependency
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "aarch64" ;; esac; }
    echo "arch=$(get_gitleaks_arch)"
  ) 2>&1
)
assert_contains "$out" "arch=arm64" "get_gitleaks_arch normalizes aarch64 to arm64"

describe "get_hadolint_os / get_hadolint_arch: hadolint release-asset naming"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines get_hadolint_os/get_hadolint_arch's uname dependency
    uname() { case "$1" in -s) echo "Darwin" ;; -m) echo "arm64" ;; esac; }
    echo "os=$(get_hadolint_os)"
    echo "arch=$(get_hadolint_arch)"
  ) 2>&1
)
assert_contains "$out" "os=macos" "get_hadolint_os maps Darwin to 'macos' (not 'darwin')"
assert_contains "$out" "arch=arm64" "get_hadolint_arch maps arm64 to 'arm64'"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines get_hadolint_os/get_hadolint_arch's uname dependency
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "x86_64" ;; esac; }
    echo "os=$(get_hadolint_os)"
    echo "arch=$(get_hadolint_arch)"
  ) 2>&1
)
assert_contains "$out" "os=linux" "get_hadolint_os maps Linux to 'linux'"
assert_contains "$out" "arch=x86_64" "get_hadolint_arch maps x86_64 to 'x86_64' (unlike gitleaks's 'x64')"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines get_hadolint_arch's uname dependency
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "aarch64" ;; esac; }
    echo "arch=$(get_hadolint_arch)"
  ) 2>&1
)
assert_contains "$out" "arch=arm64" "get_hadolint_arch normalizes aarch64 to arm64"

describe "get_gitleaks_os / get_hadolint_os: unsupported OS returns 'unsupported' without killing the caller"

out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329  # stub redefines get_gitleaks_os/get_hadolint_os's uname dependency
    uname() { case "$1" in -s) echo "FreeBSD" ;; -m) echo "x86_64" ;; esac; }
    echo "gitleaks_os=$(get_gitleaks_os)"
    echo "hadolint_os=$(get_hadolint_os)"
    echo "SURVIVED"
  ) 2>&1
)
assert_contains "$out" "gitleaks_os=unsupported" "get_gitleaks_os returns 'unsupported' (not a fatal exit) for an unrecognized OS"
assert_contains "$out" "hadolint_os=unsupported" "get_hadolint_os returns 'unsupported' (not a fatal exit) for an unrecognized OS"
assert_contains "$out" "SURVIVED" "get_gitleaks_os/get_hadolint_os never call exit on an unsupported OS"
