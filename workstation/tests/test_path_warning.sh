# shellcheck shell=bash
# shellcheck disable=SC1090  # SETUP_SH is exported by run-tests.sh at a known path
# tests/test_path_warning.sh — proves the "add this to your PATH" warning in
# install_all_tools/update_all_tools actually fires when INSTALL_DIR is
# absent from PATH, and stays silent when it is already present.
#
# Follows the isolation contract documented at the top of run-tests.sh:
# subshells emit via echo, the parent shell asserts against the captured
# string; `set +e` runs immediately after sourcing (sourcing setup.sh
# imports `set -euo pipefail`); no assert helper is ever called inside a
# subshell.

describe "install_all_tools: warns when INSTALL_DIR is absent from PATH"

out=$(
  (
    source "$SETUP_SH"
    set +e
    INSTALL_DIR="$(mktemp -d)"
    trap 'rm -rf "$INSTALL_DIR"' RETURN
    # shellcheck disable=SC2329  # stub: avoid network installers
    run_installer() { :; }
    PATH="/usr/bin:/bin"
    install_all_tools
  ) 2>&1
)
assert_contains "$out" "is not in your PATH" "install_all_tools warns when INSTALL_DIR was absent from the pre-export PATH"

describe "install_all_tools: silent when INSTALL_DIR already on PATH"

out=$(
  (
    source "$SETUP_SH"
    set +e
    INSTALL_DIR="$(mktemp -d)"
    trap 'rm -rf "$INSTALL_DIR"' RETURN
    # shellcheck disable=SC2329  # stub: avoid network installers
    run_installer() { :; }
    PATH="$INSTALL_DIR:/usr/bin:/bin"
    install_all_tools
  ) 2>&1
)
assert_not_contains "$out" "is not in your PATH" "install_all_tools stays silent when INSTALL_DIR was already on the pre-export PATH"

describe "update_all_tools: warns when INSTALL_DIR is absent from PATH"

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
    # shellcheck disable=SC2034  # read by update_all_tools in the sourced setup.sh
    RESULTS=""
    # shellcheck disable=SC2034  # read by update_all_tools in the sourced setup.sh
    FAIL_COUNT=0
    INSTALL_DIR="$(mktemp -d)"
    trap 'rm -rf "$INSTALL_DIR"' RETURN
    # shellcheck disable=SC2329  # stub: avoid network installers
    update_one_tool() { return 0; }
    PATH="/usr/bin:/bin"
    update_all_tools
  ) 2>&1
)
assert_contains "$out" "is not in your PATH" "update_all_tools warns when INSTALL_DIR was absent from the pre-export PATH"

describe "update_all_tools: silent when INSTALL_DIR already on PATH"

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
    # shellcheck disable=SC2034  # read by update_all_tools in the sourced setup.sh
    RESULTS=""
    # shellcheck disable=SC2034  # read by update_all_tools in the sourced setup.sh
    FAIL_COUNT=0
    INSTALL_DIR="$(mktemp -d)"
    trap 'rm -rf "$INSTALL_DIR"' RETURN
    # shellcheck disable=SC2329  # stub: avoid network installers
    update_one_tool() { return 0; }
    PATH="$INSTALL_DIR:/usr/bin:/bin"
    update_all_tools
  ) 2>&1
)
assert_not_contains "$out" "is not in your PATH" "update_all_tools stays silent when INSTALL_DIR was already on the pre-export PATH"
