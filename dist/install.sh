#!/usr/bin/env bash
set -euo pipefail

# install.sh -- Install security CLI tools (macOS and Linux)
# Usage: bash install.sh [-v|--verbose] [-h|--help]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERBOSE=false
INSTALL_DIR="$HOME/.local/bin"
RESULTS=""
FAIL_COUNT=0

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

usage() {
  cat <<USAGE
Usage: bash install.sh [OPTIONS]

Install security CLI tools (macOS and Linux).

Options:
  -v, --verbose    Show detailed progress output
  -h, --help       Show this help message and exit
USAGE
}

log() {
  if [[ "$VERBOSE" = true ]]; then
    echo "==> $*"
  fi
}

err() {
  echo "ERROR: $*" >&2
}

add_result() {
  local tool="$1" version="$2" status="$3"
  RESULTS="${RESULTS}${tool}|${version}|${status}\n"
}

print_summary() {
  echo ""
  echo "Security Tool Installation Summary"
  echo "-----------------------------------"
  printf "%-14s %-12s %s\n" "Tool" "Version" "Status"
  printf "%-14s %-12s %s\n" "----" "-------" "------"
  printf "%b" "$RESULTS" | while IFS='|' read -r tool version status; do
    [[ -z "$tool" ]] && continue
    printf "%-14s %-12s %s\n" "$tool" "$version" "$status"
  done
  echo ""
  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "WARNING: $FAIL_COUNT tool(s) failed to install" >&2
  fi
}

is_installed() {
  local tool="$1"
  local expected_version="$2"

  if ! command -v "$tool" > /dev/null 2>&1; then
    return 1
  fi

  local installed_version
  # gitleaks uses "gitleaks version" (no --), others use --version
  if [[ "$tool" = "gitleaks" ]]; then
    installed_version="$(gitleaks version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  else
    installed_version="$("$tool" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  fi

  if [[ "$installed_version" = "$expected_version" ]]; then
    return 0
  fi

  return 1
}

verify_sha256() {
  local file="$1"
  local expected="$2"

  local actual
  if command -v sha256sum > /dev/null 2>&1; then
    actual="$(sha256sum "$file" | cut -d' ' -f1)"
  elif command -v shasum > /dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  else
    err "No sha256sum or shasum found; cannot verify checksum"
    return 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    err "Checksum mismatch for $file"
    err "  Expected: $expected"
    err "  Actual:   $actual"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# OS/Arch detection
# ---------------------------------------------------------------------------

detect_os() {
  local os
  os="$(uname -s)"
  case "$os" in
    Darwin) echo "Darwin" ;;
    Linux)  echo "Linux" ;;
    *)
      err "Unsupported operating system: $os"
      exit 1
      ;;
  esac
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64)        echo "x86_64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)
      err "Unsupported architecture: $arch"
      exit 1
      ;;
  esac
}

# Per-tool OS/arch normalization (Gitleaks and hadolint use non-standard naming)

get_gitleaks_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "linux" ;;
    *)      echo "unsupported" ;;
  esac
}

get_gitleaks_arch() {
  case "$(uname -m)" in
    x86_64)        echo "x64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)             echo "unsupported" ;;
  esac
}

get_hadolint_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unsupported" ;;
  esac
}

get_hadolint_arch() {
  case "$(uname -m)" in
    x86_64)        echo "x86_64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)             echo "unsupported" ;;
  esac
}

# ---------------------------------------------------------------------------
# pipx bootstrap
# ---------------------------------------------------------------------------

ensure_pipx() {
  if command -v pipx > /dev/null 2>&1; then
    log "pipx already installed"
    return
  fi

  if ! command -v python3 > /dev/null 2>&1; then
    err "python3 is required but not found"
    exit 1
  fi

  log "Installing pipx via pip..."
  local pip_output  # captures output to suppress it
  # shellcheck disable=SC2034
  if pip_output="$(python3 -m pip install --user pipx 2>&1)"; then
    log "pipx installed successfully"
  else
    log "pip install failed (possibly PEP 668), retrying with --break-system-packages..."
    if pip_output="$(python3 -m pip install --user --break-system-packages pipx 2>&1)"; then
      log "pipx installed with --break-system-packages"
    else
      err "Failed to install pipx. Install manually: https://pipx.pypa.io/stable/installation/"
      exit 1
    fi
  fi

  python3 -m pipx ensurepath > /dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Tool installers
# ---------------------------------------------------------------------------

install_precommit() {
  if is_installed pre-commit "$PRECOMMIT_VERSION"; then
    log "pre-commit $PRECOMMIT_VERSION already installed"
    add_result "pre-commit" "$PRECOMMIT_VERSION" "skipped"
    return
  fi

  ensure_pipx

  log "Installing pre-commit $PRECOMMIT_VERSION via pipx..."
  if [[ "$VERBOSE" = true ]]; then
    if pipx install "pre-commit==$PRECOMMIT_VERSION"; then
      add_result "pre-commit" "$PRECOMMIT_VERSION" "installed"
    else
      err "Failed to install pre-commit"
      add_result "pre-commit" "$PRECOMMIT_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    if pipx install "pre-commit==$PRECOMMIT_VERSION" > /dev/null 2>&1; then
      add_result "pre-commit" "$PRECOMMIT_VERSION" "installed"
    else
      err "Failed to install pre-commit"
      add_result "pre-commit" "$PRECOMMIT_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
}

install_trivy() {
  if is_installed trivy "$TRIVY_VERSION"; then
    log "trivy $TRIVY_VERSION already installed"
    add_result "trivy" "$TRIVY_VERSION" "skipped"
    return
  fi

  log "Installing trivy $TRIVY_VERSION via official script..."
  if [[ "$VERBOSE" = true ]]; then
    if curl -sfL "$TRIVY_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${TRIVY_VERSION}"; then
      add_result "trivy" "$TRIVY_VERSION" "installed"
    else
      err "Failed to install trivy $TRIVY_VERSION"
      add_result "trivy" "$TRIVY_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    if curl -sfL "$TRIVY_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${TRIVY_VERSION}" > /dev/null 2>&1; then
      add_result "trivy" "$TRIVY_VERSION" "installed"
    else
      err "Failed to install trivy $TRIVY_VERSION"
      add_result "trivy" "$TRIVY_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
}

install_syft() {
  if is_installed syft "$SYFT_VERSION"; then
    log "syft $SYFT_VERSION already installed"
    add_result "syft" "$SYFT_VERSION" "skipped"
    return
  fi

  log "Installing syft $SYFT_VERSION via official script..."
  if [[ "$VERBOSE" = true ]]; then
    if curl -sSfL "$SYFT_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${SYFT_VERSION}"; then
      add_result "syft" "$SYFT_VERSION" "installed"
    else
      err "Failed to install syft $SYFT_VERSION"
      add_result "syft" "$SYFT_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    if curl -sSfL "$SYFT_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${SYFT_VERSION}" > /dev/null 2>&1; then
      add_result "syft" "$SYFT_VERSION" "installed"
    else
      err "Failed to install syft $SYFT_VERSION"
      add_result "syft" "$SYFT_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
}

install_grype() {
  if is_installed grype "$GRYPE_VERSION"; then
    log "grype $GRYPE_VERSION already installed"
    add_result "grype" "$GRYPE_VERSION" "skipped"
    return
  fi

  log "Installing grype $GRYPE_VERSION via official script..."
  if [[ "$VERBOSE" = true ]]; then
    if curl -sSfL "$GRYPE_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${GRYPE_VERSION}"; then
      add_result "grype" "$GRYPE_VERSION" "installed"
    else
      err "Failed to install grype $GRYPE_VERSION"
      add_result "grype" "$GRYPE_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    if curl -sSfL "$GRYPE_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${GRYPE_VERSION}" > /dev/null 2>&1; then
      add_result "grype" "$GRYPE_VERSION" "installed"
    else
      err "Failed to install grype $GRYPE_VERSION"
      add_result "grype" "$GRYPE_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
}

install_gitleaks() {
  if is_installed gitleaks "$GITLEAKS_VERSION"; then
    log "gitleaks $GITLEAKS_VERSION already installed"
    add_result "gitleaks" "$GITLEAKS_VERSION" "skipped"
    return
  fi

  local os arch url checksums_url tmpdir expected_hash
  os="$(get_gitleaks_os)"
  arch="$(get_gitleaks_arch)"

  url="$GITLEAKS_URL"
  url="${url//\{VERSION\}/$GITLEAKS_VERSION}"
  url="${url//\{OS\}/$os}"
  url="${url//\{ARCH\}/$arch}"

  checksums_url="$GITLEAKS_CHECKSUMS_URL"
  checksums_url="${checksums_url//\{VERSION\}/$GITLEAKS_VERSION}"

  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/gitleaks.XXXXXX")"

  log "Installing gitleaks $GITLEAKS_VERSION (${os}/${arch})..."
  if curl -sfL -o "$tmpdir/gitleaks.tar.gz" "$url" && \
     curl -sfL -o "$tmpdir/checksums.txt" "$checksums_url"; then

    expected_hash="$(grep "gitleaks_${GITLEAKS_VERSION}_${os}_${arch}.tar.gz" "$tmpdir/checksums.txt" | cut -d' ' -f1)"
    if [[ -z "$expected_hash" ]]; then
      err "Could not find checksum for gitleaks_${GITLEAKS_VERSION}_${os}_${arch}.tar.gz"
      add_result "gitleaks" "$GITLEAKS_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      rm -rf "$tmpdir"
      return
    fi

    if verify_sha256 "$tmpdir/gitleaks.tar.gz" "$expected_hash"; then
      tar -xzf "$tmpdir/gitleaks.tar.gz" -C "$tmpdir"
      mv "$tmpdir/gitleaks" "$INSTALL_DIR/gitleaks"
      chmod +x "$INSTALL_DIR/gitleaks"
      add_result "gitleaks" "$GITLEAKS_VERSION" "installed"
    else
      add_result "gitleaks" "$GITLEAKS_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    err "Failed to download gitleaks $GITLEAKS_VERSION"
    add_result "gitleaks" "$GITLEAKS_VERSION" "FAILED"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  rm -rf "$tmpdir"
}

install_hadolint() {
  if is_installed hadolint "$HADOLINT_VERSION"; then
    log "hadolint $HADOLINT_VERSION already installed"
    add_result "hadolint" "$HADOLINT_VERSION" "skipped"
    return
  fi

  local os arch url checksum_url tmpdir expected_hash
  os="$(get_hadolint_os)"
  arch="$(get_hadolint_arch)"

  url="$HADOLINT_URL"
  url="${url//\{VERSION\}/$HADOLINT_VERSION}"
  url="${url//\{OS\}/$os}"
  url="${url//\{ARCH\}/$arch}"

  checksum_url="$HADOLINT_CHECKSUM_URL"
  checksum_url="${checksum_url//\{VERSION\}/$HADOLINT_VERSION}"
  checksum_url="${checksum_url//\{OS\}/$os}"
  checksum_url="${checksum_url//\{ARCH\}/$arch}"

  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/hadolint.XXXXXX")"

  log "Installing hadolint $HADOLINT_VERSION (${os}/${arch})..."
  if curl -sfL -o "$tmpdir/hadolint" "$url" && \
     curl -sfL -o "$tmpdir/hadolint.sha256" "$checksum_url"; then

    expected_hash="$(cut -d' ' -f1 < "$tmpdir/hadolint.sha256")"
    if [[ -z "$expected_hash" ]]; then
      err "Could not read checksum for hadolint"
      add_result "hadolint" "$HADOLINT_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      rm -rf "$tmpdir"
      return
    fi

    if verify_sha256 "$tmpdir/hadolint" "$expected_hash"; then
      chmod +x "$tmpdir/hadolint"
      mv "$tmpdir/hadolint" "$INSTALL_DIR/hadolint"
      add_result "hadolint" "$HADOLINT_VERSION" "installed"
    else
      add_result "hadolint" "$HADOLINT_VERSION" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    err "Failed to download hadolint $HADOLINT_VERSION"
    add_result "hadolint" "$HADOLINT_VERSION" "FAILED"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  rm -rf "$tmpdir"
}

# ---------------------------------------------------------------------------
# PATH verification
# ---------------------------------------------------------------------------

verify_path() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
      echo "WARNING: $INSTALL_DIR is not in your PATH. Add it to your shell profile or run:" >&2
      echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
      ;;
  esac

  local tool
  for tool in pre-commit trivy syft grype gitleaks hadolint; do
    if ! command -v "$tool" > /dev/null 2>&1; then
      echo "WARNING: $tool not found on PATH" >&2
    fi
  done
}

# ---------------------------------------------------------------------------
# Main execution
# ---------------------------------------------------------------------------

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=true ;;
    -h|--help)    usage; exit 0 ;;
    *)
      err "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# Source version manifest
if [[ -f "$SCRIPT_DIR/versions.conf" ]]; then
  # shellcheck source=versions.conf
  . "$SCRIPT_DIR/versions.conf"
else
  err "versions.conf not found in $SCRIPT_DIR"
  exit 1
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Add to PATH for this session
export PATH="$INSTALL_DIR:$PATH"

log "Installing security tools to $INSTALL_DIR"

# Install tools
install_precommit
install_trivy
install_syft
install_grype
install_gitleaks
install_hadolint

# Verify PATH setup
verify_path

# Print summary
print_summary

# Exit with failure if any tool failed
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
