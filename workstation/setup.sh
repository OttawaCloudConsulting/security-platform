#!/usr/bin/env bash
set -euo pipefail

# setup.sh — Bootstrap a repository with the OCC security workstation stack
#
# Run from inside any git repository to:
#   1. Create versions.conf with latest tool versions (if not present)
#   2. Install all security CLI tools
#   3. Generate all configuration files (.pre-commit-config.yaml, linting configs, etc.)
#   4. Activate pre-commit hooks
#
# Usage:
#   bash setup.sh                     # full setup (install + configure + activate)
#   bash setup.sh install             # install CLI tools only
#   bash setup.sh configure           # generate config files only (no install)
#   bash setup.sh check               # show installed vs expected versions
#   bash setup.sh --verbose           # verbose output
#   bash setup.sh --help              # show help

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

INSTALL_DIR="$HOME/.local/bin"
VERBOSE=false
COMMAND="setup"
RESULTS=""
FAIL_COUNT=0
CONFIG_COUNT=0

GITHUB_API="https://api.github.com/repos"

# Tool GitHub repositories (for version resolution)
declare -A TOOL_REPOS=(
  [PRECOMMIT]="pre-commit/pre-commit"
  [TRIVY]="aquasecurity/trivy"
  [SYFT]="anchore/syft"
  [GRYPE]="anchore/grype"
  [GITLEAKS]="gitleaks/gitleaks"
  [HADOLINT]="hadolint/hadolint"
)

# Hook GitHub repositories (for pre-commit config version resolution)
declare -A HOOK_REPOS=(
  [PRECOMMIT_TERRAFORM]="antonbabenko/pre-commit-terraform"
  [RUFF]="astral-sh/ruff-pre-commit"
  [SHELLCHECK]="shellcheck-py/shellcheck-py"
  [HADOLINT_HOOK]="hadolint/hadolint"
  [YAMLLINT]="adrienverge/yamllint"
  [MARKDOWNLINT]="igorshubovych/markdownlint-cli"
  [GITLEAKS_HOOK]="gitleaks/gitleaks"
)

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

usage() {
  cat <<'USAGE'
Usage: bash setup.sh [COMMAND] [OPTIONS]

Bootstrap a repository with the OCC security workstation stack.
Run from inside any git repository.

Commands:
  setup       Full setup: install tools + generate configs + activate hooks (default)
  install     Install security CLI tools only
  configure   Generate configuration files only (skip tool installation)
  check       Show installed vs expected versions for all tools

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

info() {
  echo "==> $*"
}

err() {
  echo "ERROR: $*" >&2
}

warn() {
  echo "WARNING: $*" >&2
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
    warn "$FAIL_COUNT tool(s) failed to install"
  fi
}

# ---------------------------------------------------------------------------
# Prerequisites check
# ---------------------------------------------------------------------------

# shellcheck disable=SC2329  # invoked from main case statement
require_git_repo() {
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    err "Not inside a git repository. Run this from a repo root."
    exit 1
  fi
}

check_prerequisites() {
  local missing=()

  if ! command -v git > /dev/null 2>&1; then
    missing+=("git")
  fi
  if ! command -v curl > /dev/null 2>&1; then
    missing+=("curl")
  fi
  if ! command -v python3 > /dev/null 2>&1; then
    missing+=("python3")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing required tools: ${missing[*]}"
    err "Install them before running setup."
    exit 1
  fi

  log "Prerequisites satisfied: git, curl, python3"
}

# ---------------------------------------------------------------------------
# Version resolution
# ---------------------------------------------------------------------------

resolve_latest_version() {
  local repo="$1"
  local version

  # Try /releases/latest first (most repos)
  version=$(curl -sf "${GITHUB_API}/${repo}/releases/latest" 2>/dev/null \
    | grep -o '"tag_name": "[^"]*"' \
    | head -1 \
    | sed 's/"tag_name": "v\{0,1\}\(.*\)"/\1/')

  # Fall back to tags (some repos like shellcheck-py don't use releases)
  if [[ -z "$version" ]]; then
    version=$(curl -sf "${GITHUB_API}/${repo}/tags" 2>/dev/null \
      | grep -o '"name": "[^"]*"' \
      | head -1 \
      | sed 's/"name": "v\{0,1\}\(.*\)"/\1/')
  fi

  if [[ -z "$version" ]]; then
    err "Failed to resolve latest version for ${repo}"
    return 1
  fi

  echo "$version"
}

# ---------------------------------------------------------------------------
# versions.conf management
# ---------------------------------------------------------------------------

generate_versions_conf() {
  local target="$1"

  info "Resolving latest tool versions from GitHub..."

  local precommit_ver trivy_ver syft_ver grype_ver gitleaks_ver hadolint_ver
  precommit_ver=$(resolve_latest_version "${TOOL_REPOS[PRECOMMIT]}") || precommit_ver="4.2.0"
  trivy_ver=$(resolve_latest_version "${TOOL_REPOS[TRIVY]}") || trivy_ver="0.69.3"
  syft_ver=$(resolve_latest_version "${TOOL_REPOS[SYFT]}") || syft_ver="1.42.2"
  grype_ver=$(resolve_latest_version "${TOOL_REPOS[GRYPE]}") || grype_ver="0.109.1"
  gitleaks_ver=$(resolve_latest_version "${TOOL_REPOS[GITLEAKS]}") || gitleaks_ver="8.30.0"
  hadolint_ver=$(resolve_latest_version "${TOOL_REPOS[HADOLINT]}") || hadolint_ver="2.14.0"

  cat > "$target" <<VERSIONS
# versions.conf — Pinned security tool versions
# Generated by setup.sh on $(date -u +%Y-%m-%d)
# Edit versions here, then re-run: bash setup.sh install

# Tool versions
PRECOMMIT_VERSION="${precommit_ver}"
TRIVY_VERSION="${trivy_ver}"
SYFT_VERSION="${syft_ver}"
GRYPE_VERSION="${grype_ver}"
GITLEAKS_VERSION="${gitleaks_ver}"
HADOLINT_VERSION="${hadolint_ver}"

# Official install script URLs (Trivy, Syft, Grype)
TRIVY_INSTALL_URL="https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh"
SYFT_INSTALL_URL="https://raw.githubusercontent.com/anchore/syft/main/install.sh"
GRYPE_INSTALL_URL="https://raw.githubusercontent.com/anchore/grype/main/install.sh"

# Direct download URL templates — {VERSION}, {OS}, {ARCH} replaced at runtime
GITLEAKS_URL="https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/gitleaks_{VERSION}_{OS}_{ARCH}.tar.gz"
GITLEAKS_CHECKSUMS_URL="https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/gitleaks_{VERSION}_checksums.txt"
HADOLINT_URL="https://github.com/hadolint/hadolint/releases/download/v{VERSION}/hadolint-{OS}-{ARCH}"
HADOLINT_CHECKSUM_URL="https://github.com/hadolint/hadolint/releases/download/v{VERSION}/hadolint-{OS}-{ARCH}.sha256"
VERSIONS

  info "Created $target"
  log "  pre-commit=${precommit_ver} trivy=${trivy_ver} syft=${syft_ver}"
  log "  grype=${grype_ver} gitleaks=${gitleaks_ver} hadolint=${hadolint_ver}"
}

ensure_versions_conf() {
  local repo_root="$1"
  local versions_file="${repo_root}/versions.conf"

  if [[ -f "$versions_file" ]]; then
    log "Using existing ${versions_file}"
  else
    generate_versions_conf "$versions_file"
  fi

  # shellcheck source=/dev/null
  . "$versions_file"
}

# ---------------------------------------------------------------------------
# OS/Arch detection
# ---------------------------------------------------------------------------

# shellcheck disable=SC2329  # invoked by install functions
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "Darwin" ;;
    Linux)  echo "Linux" ;;
    *)      err "Unsupported OS: $(uname -s)"; exit 1 ;;
  esac
}

# shellcheck disable=SC2329  # invoked by install functions
detect_arch() {
  case "$(uname -m)" in
    x86_64)        echo "x86_64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)             err "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
}

# shellcheck disable=SC2329  # invoked by _install_gitleaks
get_gitleaks_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;; Linux) echo "linux" ;; *) echo "unsupported" ;;
  esac
}

# shellcheck disable=SC2329  # invoked by _install_gitleaks
get_gitleaks_arch() {
  case "$(uname -m)" in
    x86_64) echo "x64" ;; arm64|aarch64) echo "arm64" ;; *) echo "unsupported" ;;
  esac
}

# shellcheck disable=SC2329  # invoked by _install_hadolint
get_hadolint_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;; Linux) echo "linux" ;; *) echo "unsupported" ;;
  esac
}

# shellcheck disable=SC2329  # invoked by _install_hadolint
get_hadolint_arch() {
  case "$(uname -m)" in
    x86_64) echo "x86_64" ;; arm64|aarch64) echo "arm64" ;; *) echo "unsupported" ;;
  esac
}

# ---------------------------------------------------------------------------
# Version checking
# ---------------------------------------------------------------------------

is_installed() {
  local tool="$1"
  local expected_version="$2"

  if ! command -v "$tool" > /dev/null 2>&1; then
    return 1
  fi

  local installed_version
  if [[ "$tool" = "gitleaks" ]]; then
    installed_version="$(gitleaks version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  else
    installed_version="$("$tool" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  fi

  [[ "$installed_version" = "$expected_version" ]]
}

get_installed_version() {
  local tool="$1"

  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "(not found)"
    return
  fi

  local version
  if [[ "$tool" = "gitleaks" ]]; then
    version="$(gitleaks version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  else
    version="$("$tool" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  fi

  echo "${version:-(unknown)}"
}

# shellcheck disable=SC2329  # invoked by _install_gitleaks, _install_hadolint
verify_sha256() {
  local file="$1" expected="$2"
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
# pipx bootstrap
# ---------------------------------------------------------------------------

# shellcheck disable=SC2329  # invoked by _install_precommit
ensure_pipx() {
  if command -v pipx > /dev/null 2>&1; then
    log "pipx already installed"
    return
  fi

  log "Installing pipx via pip..."
  local pip_output
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

run_installer() {
  local name="$1" version="$2"
  shift 2

  if is_installed "$name" "$version"; then
    log "$name $version already installed"
    add_result "$name" "$version" "ok"
    return
  fi

  log "Installing $name $version..."
  if [[ "$VERBOSE" = true ]]; then
    if "$@"; then
      add_result "$name" "$version" "installed"
    else
      err "Failed to install $name $version"
      add_result "$name" "$version" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    if "$@" > /dev/null 2>&1; then
      add_result "$name" "$version" "installed"
    else
      err "Failed to install $name $version"
      add_result "$name" "$version" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
}

# shellcheck disable=SC2329  # invoked indirectly via run_installer
_install_precommit() {
  ensure_pipx
  pipx install "pre-commit==${PRECOMMIT_VERSION}"
}

# shellcheck disable=SC2329  # invoked indirectly via run_installer
_install_trivy() {
  curl -sfL "$TRIVY_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${TRIVY_VERSION}"
}

# shellcheck disable=SC2329  # invoked indirectly via run_installer
_install_syft() {
  curl -sSfL "$SYFT_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${SYFT_VERSION}"
}

# shellcheck disable=SC2329  # invoked indirectly via run_installer
_install_grype() {
  curl -sSfL "$GRYPE_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${GRYPE_VERSION}"
}

# shellcheck disable=SC2329  # invoked indirectly via run_installer
_install_gitleaks() {
  local os arch url checksums_url tmpdir expected_hash
  os="$(get_gitleaks_os)"
  arch="$(get_gitleaks_arch)"

  url="${GITLEAKS_URL//\{VERSION\}/$GITLEAKS_VERSION}"
  url="${url//\{OS\}/$os}"
  url="${url//\{ARCH\}/$arch}"

  checksums_url="${GITLEAKS_CHECKSUMS_URL//\{VERSION\}/$GITLEAKS_VERSION}"

  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/gitleaks.XXXXXX")"
  trap 'rm -rf "$tmpdir"' RETURN

  curl -sfL -o "$tmpdir/gitleaks.tar.gz" "$url"
  curl -sfL -o "$tmpdir/checksums.txt" "$checksums_url"

  expected_hash="$(grep "gitleaks_${GITLEAKS_VERSION}_${os}_${arch}.tar.gz" "$tmpdir/checksums.txt" | cut -d' ' -f1)"
  if [[ -z "$expected_hash" ]]; then
    err "Could not find checksum for gitleaks_${GITLEAKS_VERSION}_${os}_${arch}.tar.gz"
    return 1
  fi

  verify_sha256 "$tmpdir/gitleaks.tar.gz" "$expected_hash"
  tar -xzf "$tmpdir/gitleaks.tar.gz" -C "$tmpdir"
  mv "$tmpdir/gitleaks" "$INSTALL_DIR/gitleaks"
  chmod +x "$INSTALL_DIR/gitleaks"
}

# shellcheck disable=SC2329  # invoked indirectly via run_installer
_install_hadolint() {
  local os arch url checksum_url tmpdir expected_hash
  os="$(get_hadolint_os)"
  arch="$(get_hadolint_arch)"

  url="${HADOLINT_URL//\{VERSION\}/$HADOLINT_VERSION}"
  url="${url//\{OS\}/$os}"
  url="${url//\{ARCH\}/$arch}"

  checksum_url="${HADOLINT_CHECKSUM_URL//\{VERSION\}/$HADOLINT_VERSION}"
  checksum_url="${checksum_url//\{OS\}/$os}"
  checksum_url="${checksum_url//\{ARCH\}/$arch}"

  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/hadolint.XXXXXX")"
  trap 'rm -rf "$tmpdir"' RETURN

  curl -sfL -o "$tmpdir/hadolint" "$url"
  curl -sfL -o "$tmpdir/hadolint.sha256" "$checksum_url"

  expected_hash="$(cut -d' ' -f1 < "$tmpdir/hadolint.sha256")"
  if [[ -z "$expected_hash" ]]; then
    err "Could not read checksum for hadolint"
    return 1
  fi

  verify_sha256 "$tmpdir/hadolint" "$expected_hash"
  chmod +x "$tmpdir/hadolint"
  mv "$tmpdir/hadolint" "$INSTALL_DIR/hadolint"
}

install_all_tools() {
  mkdir -p "$INSTALL_DIR"
  export PATH="$INSTALL_DIR:$PATH"

  info "Installing security tools to $INSTALL_DIR"

  run_installer "pre-commit" "$PRECOMMIT_VERSION" _install_precommit
  run_installer "trivy"      "$TRIVY_VERSION"      _install_trivy
  run_installer "syft"       "$SYFT_VERSION"        _install_syft
  run_installer "grype"      "$GRYPE_VERSION"       _install_grype
  run_installer "gitleaks"   "$GITLEAKS_VERSION"    _install_gitleaks
  run_installer "hadolint"   "$HADOLINT_VERSION"    _install_hadolint

  # PATH verification
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *) warn "$INSTALL_DIR is not in your PATH. Add to your shell profile:" ;;
  esac
}

# ---------------------------------------------------------------------------
# Configuration file generation
# ---------------------------------------------------------------------------

write_config() {
  local target="$1" description="$2"

  if [[ -f "$target" ]]; then
    log "Exists, skipping: $target"
    return
  fi

  # Content is written by the caller via stdin
  cat > "$target"
  CONFIG_COUNT=$((CONFIG_COUNT + 1))
  log "Created: $target ($description)"
}

resolve_hook_versions() {
  info "Resolving latest hook versions from GitHub..."

  HOOK_VER_PRECOMMIT_TERRAFORM=$(resolve_latest_version "${HOOK_REPOS[PRECOMMIT_TERRAFORM]}") || HOOK_VER_PRECOMMIT_TERRAFORM="v1.105.0"
  HOOK_VER_RUFF=$(resolve_latest_version "${HOOK_REPOS[RUFF]}") || HOOK_VER_RUFF="v0.15.6"
  HOOK_VER_SHELLCHECK=$(resolve_latest_version "${HOOK_REPOS[SHELLCHECK]}") || HOOK_VER_SHELLCHECK="v0.11.0.1"
  HOOK_VER_HADOLINT=$(resolve_latest_version "${HOOK_REPOS[HADOLINT_HOOK]}") || HOOK_VER_HADOLINT="v2.14.0"
  HOOK_VER_YAMLLINT=$(resolve_latest_version "${HOOK_REPOS[YAMLLINT]}") || HOOK_VER_YAMLLINT="v1.38.0"
  HOOK_VER_MARKDOWNLINT=$(resolve_latest_version "${HOOK_REPOS[MARKDOWNLINT]}") || HOOK_VER_MARKDOWNLINT="v0.48.0"
  HOOK_VER_GITLEAKS=$(resolve_latest_version "${HOOK_REPOS[GITLEAKS_HOOK]}") || HOOK_VER_GITLEAKS="v8.30.0"

  # Ensure v prefix
  for var in HOOK_VER_PRECOMMIT_TERRAFORM HOOK_VER_RUFF HOOK_VER_SHELLCHECK \
             HOOK_VER_HADOLINT HOOK_VER_YAMLLINT HOOK_VER_MARKDOWNLINT HOOK_VER_GITLEAKS; do
    local val="${!var}"
    if [[ "$val" != v* ]]; then
      eval "$var=v${val}"
    fi
  done

  log "  pre-commit-terraform=${HOOK_VER_PRECOMMIT_TERRAFORM}"
  log "  ruff=${HOOK_VER_RUFF} shellcheck=${HOOK_VER_SHELLCHECK}"
  log "  hadolint=${HOOK_VER_HADOLINT} yamllint=${HOOK_VER_YAMLLINT}"
  log "  markdownlint=${HOOK_VER_MARKDOWNLINT} gitleaks=${HOOK_VER_GITLEAKS}"
}

generate_precommit_config() {
  local target="$1"

  if [[ -f "$target" ]]; then
    log "Exists, skipping: $target"
    return
  fi

  resolve_hook_versions

  cat > "$target" <<PRECOMMIT
# .pre-commit-config.yaml
# Generated by setup.sh on $(date -u +%Y-%m-%d)
# Update hook versions: pre-commit autoupdate
#
# Every hook has an explicit types: or files: filter so this universal config
# works across all repo types. Hooks auto-skip when no matching files are staged.

# ─────────────────────────────────────────────────────────────────────────────
# TIER 1: Quality & Linting
# Fast checks — run on every commit. Catch formatting, style, and syntax issues
# before they reach security scanners or CI.
# ─────────────────────────────────────────────────────────────────────────────
repos:

  # --- Terraform: formatting and validation ---
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: ${HOOK_VER_PRECOMMIT_TERRAFORM}
    hooks:
      - id: terraform_fmt
        types: [terraform]
      - id: terraform_validate
        types: [terraform]

  # --- Python: Ruff (replaces flake8, black, isort) ---
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: ${HOOK_VER_RUFF}
    hooks:
      - id: ruff
        args: [--fix]
        types_or: [python, pyi]
      - id: ruff-format
        types_or: [python, pyi]

  # --- Bash / Shell: ShellCheck ---
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: ${HOOK_VER_SHELLCHECK}
    hooks:
      - id: shellcheck
        types: [shell]

  # --- Dockerfile: hadolint ---
  - repo: https://github.com/hadolint/hadolint
    rev: ${HOOK_VER_HADOLINT}
    hooks:
      - id: hadolint
        types: [dockerfile]

  # --- YAML / Kubernetes manifests: yamllint ---
  - repo: https://github.com/adrienverge/yamllint
    rev: ${HOOK_VER_YAMLLINT}
    hooks:
      - id: yamllint
        args: [-d, relaxed]
        types: [yaml]

  # --- Markdown: markdownlint ---
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: ${HOOK_VER_MARKDOWNLINT}
    hooks:
      - id: markdownlint
        types: [markdown]

  # --- TypeScript / JavaScript: ESLint (local — requires eslint in project) ---
  - repo: local
    hooks:
      - id: eslint
        name: eslint
        entry: npx eslint
        language: system
        types_or: [javascript, jsx, ts, tsx]
        files: \\.(js|jsx|ts|tsx)\$
        pass_filenames: true

  # --- npm: lightweight dependency audit (triggers on package-lock.json changes only) ---
  - repo: local
    hooks:
      - id: npm-audit
        name: npm audit
        entry: npm audit --audit-level=high
        language: system
        files: package-lock\\.json\$
        pass_filenames: false

# ─────────────────────────────────────────────────────────────────────────────
# TIER 2: Secrets Gate
# Secrets are the only pre-commit security check. A credential pushed to any
# branch is a potential exposure regardless of context. SAST (Semgrep CE) and
# IaC scanning (Checkov) run at the Pull Request gate in GitHub Actions instead.
# ─────────────────────────────────────────────────────────────────────────────

  # --- Secrets detection: Gitleaks ---
  # Bypass: git push --no-verify skips this hook — CI is the compensating control
  # Runs on all file types (pass_filenames: false — scans git diff)
  - repo: https://github.com/gitleaks/gitleaks
    rev: ${HOOK_VER_GITLEAKS}
    hooks:
      - id: gitleaks
        stages: [pre-push]
PRECOMMIT

  CONFIG_COUNT=$((CONFIG_COUNT + 1))
  log "Created: $target (pre-commit configuration)"
}

generate_gitleaksignore() {
  local target="$1"

  write_config "$target" "Gitleaks suppressions" <<'GITLEAKSIGNORE'
# .gitleaksignore — Gitleaks false positive suppressions
# Format: fingerprint from gitleaks JSON output
# Generate: gitleaks detect --source . --report-format json
GITLEAKSIGNORE
}

generate_markdownlint_config() {
  local target="$1"

  write_config "$target" "markdownlint enforced rules" <<'MDLINT'
{
  "MD013": false,
  "MD024": false,
  "MD036": false,
  "MD040": false,
  "MD060": false,
  "line-length": false
}
MDLINT
}

generate_markdownlint_fix_config() {
  local target="$1"

  write_config "$target" "markdownlint auto-fix rules" <<'MDLINTFIX'
{
  "default": false,
  "MD013": false,
  "MD022": true,
  "MD031": true,
  "MD032": true,
  "MD047": true,
  "MD058": true
}
MDLINTFIX
}

generate_markdownlint_cli2_config() {
  local target="$1"

  write_config "$target" "markdownlint-cli2 configuration" <<'MDLINTCLI2'
# markdownlint-cli2 configuration

config:
  MD013: false
  MD022: false
  MD024: false
  MD029: false
  MD031: false
  MD032: false
  MD036: false
  MD040: false
  MD060: false
  MD018: false
MDLINTCLI2
}

generate_all_configs() {
  local repo_root="$1"

  info "Generating configuration files in ${repo_root}"

  generate_precommit_config       "${repo_root}/.pre-commit-config.yaml"
  generate_gitleaksignore          "${repo_root}/.gitleaksignore"
  generate_markdownlint_config     "${repo_root}/.markdownlint.jsonc"
  generate_markdownlint_fix_config "${repo_root}/.markdownlint-fix.markdownlint.jsonc"
  generate_markdownlint_cli2_config "${repo_root}/.markdownlint-cli2.yaml"

  if [[ "$CONFIG_COUNT" -eq 0 ]]; then
    info "All configuration files already exist — no changes made"
  else
    info "Created $CONFIG_COUNT configuration file(s)"
  fi
}

# ---------------------------------------------------------------------------
# Hook activation
# ---------------------------------------------------------------------------

activate_hooks() {
  local repo_root="$1"

  if ! command -v pre-commit > /dev/null 2>&1; then
    err "pre-commit not found on PATH. Run 'bash setup.sh install' first."
    return 1
  fi

  if [[ ! -f "${repo_root}/.pre-commit-config.yaml" ]]; then
    err ".pre-commit-config.yaml not found. Run 'bash setup.sh configure' first."
    return 1
  fi

  info "Activating pre-commit hooks..."

  cd "$repo_root"
  pre-commit install
  pre-commit install --hook-type pre-push

  info "Hooks activated (pre-commit + pre-push)"
}

# ---------------------------------------------------------------------------
# Check command
# ---------------------------------------------------------------------------

run_check() {
  echo ""
  echo "Security Tool Version Check"
  echo "----------------------------"
  printf "%-14s %-14s %-14s %s\n" "Tool" "Expected" "Installed" "Status"
  printf "%-14s %-14s %-14s %s\n" "----" "--------" "---------" "------"

  local tools=("pre-commit:$PRECOMMIT_VERSION" "trivy:$TRIVY_VERSION" "syft:$SYFT_VERSION"
               "grype:$GRYPE_VERSION" "gitleaks:$GITLEAKS_VERSION" "hadolint:$HADOLINT_VERSION")

  for entry in "${tools[@]}"; do
    local tool="${entry%%:*}"
    local expected="${entry##*:}"
    local installed
    installed="$(get_installed_version "$tool")"

    local status
    if [[ "$installed" = "(not found)" ]]; then
      status="MISSING"
    elif [[ "$installed" = "$expected" ]]; then
      status="ok"
    else
      status="MISMATCH"
    fi

    printf "%-14s %-14s %-14s %s\n" "$tool" "$expected" "$installed" "$status"
  done

  echo ""

  # Also check prerequisites
  echo "Prerequisites"
  echo "-------------"
  for prereq in git curl python3 node npm terraform; do
    if command -v "$prereq" > /dev/null 2>&1; then
      local ver
      ver="$("$prereq" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1)" || ver="(found)"
      printf "%-14s %s\n" "$prereq" "$ver"
    else
      printf "%-14s %s\n" "$prereq" "(not found)"
    fi
  done
  echo ""
}

# ---------------------------------------------------------------------------
# Main execution
# ---------------------------------------------------------------------------

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    install|configure|setup|check) COMMAND="$arg" ;;
    -v|--verbose) VERBOSE=true ;;
    -h|--help)    usage; exit 0 ;;
    *)            err "Unknown argument: $arg"; usage; exit 1 ;;
  esac
done

# Determine repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

check_prerequisites

# Ensure versions.conf exists (creates with latest versions if missing)
ensure_versions_conf "$REPO_ROOT"

case "$COMMAND" in
  install)
    install_all_tools
    print_summary
    ;;
  configure)
    generate_all_configs "$REPO_ROOT"
    ;;
  check)
    run_check
    ;;
  setup)
    install_all_tools
    print_summary
    generate_all_configs "$REPO_ROOT"
    activate_hooks "$REPO_ROOT"
    echo ""
    info "Setup complete. Run 'pre-commit run --all-files' to validate."
    ;;
esac

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
