#!/bin/bash
# Workstation tool installer entry point. Runs under the system shell (Bash 3.2
# on macOS), prepares the prerequisites, then hands off to the Bash 5 engine.
# Exit codes: 0 ok, 1 failure, 2 usage, 75 restart needed (new terminal).
set -Eeuo pipefail

WST_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
WST_PROJECT_DIR="$PWD"
export WST_ROOT WST_PROJECT_DIR
# shellcheck source=scripts/orchestrator/common.sh
. "$WST_ROOT/scripts/orchestrator/common.sh"
# shellcheck source=scripts/common/versions.sh
. "$WST_ROOT/scripts/common/versions.sh"
# shellcheck source=scripts/common/download.sh
. "$WST_ROOT/scripts/common/download.sh"

BASH5=""; BASH_CHANGED=0; SHELL_CHANGED=0; BREW=""; SUDO=""; PREREQ_STOP=0
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"; export NVM_DIR
BOOTSTRAP_DIR="${WST_BOOTSTRAP_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/workstation-tools/bootstrap}"

wst_bash_version() { # version of a bash binary, or empty
  [ -x "$1" ] || return 0
  "$1" -c 'printf "%s.%s.%s" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" "${BASH_VERSINFO[2]}"' 2>/dev/null || true
}

# Only these flags matter here; everything is forwarded unchanged.
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help) cat <<'USAGE'
Usage: setup-workstation.sh [--env-file PATH] [--groups LIST] [--requested-file PATH]
       [--installed-file PATH] [--tool-version TOOL=VER]... [--allow-base-removal]
       [--dry-run] [--yes]
Exit: 0 ok, 1 failure, 2 usage, 75 restart needed (open a new terminal and rerun)
USAGE
      exit 0 ;;
  esac
done
export DRY_RUN ASSUME_YES

[ -n "${WST_OS:-}" ] && [ -n "${WST_ARCH:-}" ] || wst_detect_os
export WST_OS WST_ARCH
# shellcheck source=/dev/null
. "$WST_ROOT/scripts/orchestrator/$WST_OS.sh"

setup_privilege() {
  if [ "$(id -u)" = 0 ]; then
    SUDO=""
  else
    command -v sudo >/dev/null 2>&1 || die "sudo is required when not running as root"
    SUDO="sudo"
    [ "$DRY_RUN" = 1 ] || sudo -v || die "sudo authentication failed"
  fi
}

login_shell_step() {
  local cur
  [ -n "$BASH5" ] && [ -x "$BASH5" ] || return 0
  if ! grep -qxF "$BASH5" /etc/shells 2>/dev/null; then
    if [ "$DRY_RUN" = 1 ]; then
      log "DRY-RUN: add $BASH5 to /etc/shells"
    else
      printf '%s\n' "$BASH5" | $SUDO tee -a /etc/shells >/dev/null || die "could not update /etc/shells"
    fi
  fi
  cur="$(os_login_shell)"
  if [ "$cur" != "$BASH5" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      log "DRY-RUN: chsh -s $BASH5 $(id -un) (current: ${cur:-unknown})"
    elif chsh -s "$BASH5" "$(id -un)"; then
      SHELL_CHANGED=1
    else
      warn "could not change the login shell to $BASH5 (run: chsh -s $BASH5)"
    fi
  fi
}

nvm_step() {
  local tag tmp
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: install/update nvm, Node.js LTS and the latest npm"
    return 0
  fi
  tag="$(gh_latest_tag nvm-sh/nvm)" || die "could not discover the latest nvm release"
  log "nvm $tag (integrity: unverified, official installer)"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wst-nvm.XXXXXX")"
  _curl -o "$tmp/install.sh" "https://raw.githubusercontent.com/nvm-sh/nvm/$tag/install.sh" \
    || die "could not download the nvm installer"
  /bin/bash "$tmp/install.sh" || die "nvm install failed"
  rm -rf "$tmp"
  set +eu
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  nvm install --lts --latest-npm && nvm alias default 'lts/*' >/dev/null
  rc=$?
  set -eu
  [ "$rc" = 0 ] || die "nvm could not install the Node.js LTS release"
}

jq_asset() {
  case "$WST_OS" in macos) printf 'jq-macos-%s\n' "$WST_ARCH" ;; *) printf 'jq-linux-%s\n' "$WST_ARCH" ;; esac
}

bootstrap_jq() {
  local tag asset dir bin url tmp
  tag="$(gh_latest_tag jqlang/jq)" || die "could not discover the latest jq release"
  asset="$(jq_asset)"
  dir="$BOOTSTRAP_DIR/bin"; bin="$dir/jq"
  if [ -x "$bin" ] && [ "$("$bin" --version 2>/dev/null)" = "$tag" ]; then
    WST_JQ="$bin"; return 0
  fi
  url="https://github.com/jqlang/jq/releases/download/$tag"
  if [ "$DRY_RUN" = 1 ]; then
    dir="$(mktemp -d "${TMPDIR:-/tmp}/wst-jq.XXXXXX")"; bin="$dir/jq"
    log "DRY-RUN: bootstrap jq $tag into a temporary directory"
  else
    mkdir -p "$dir"
  fi
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wst-jqdl.XXXXXX")"
  dl_fetch "$url/$asset" "$tmp/$asset" || die "could not download jq $tag"
  if ! dl_verify "$tmp/$asset" "$asset" yes "$url/sha256sum.txt"; then
    rm -rf "$tmp"
    die "$(dl_fail_message "$DL_STATUS" "$asset")"
  fi
  install -m 0755 "$tmp/$asset" "$bin.new" && mv -f "$bin.new" "$bin"
  rm -rf "$tmp"
  WST_JQ="$bin"
}

prereq_report() {
  local nv
  WST_PREREQ_REPORT="  bash $(wst_bash_version "$BASH5")"
  WST_PREREQ_REPORT="$WST_PREREQ_REPORT
$(os_prereq_versions)"
  if [ -s "$NVM_DIR/nvm.sh" ] && [ "$DRY_RUN" != 1 ]; then
    # shellcheck source=/dev/null
    nv="$(set +eu; . "$NVM_DIR/nvm.sh" >/dev/null 2>&1; printf 'nvm %s, node %s, npm %s' "$(nvm --version)" "$(node --version)" "$(npm --version)")"
    WST_PREREQ_REPORT="$WST_PREREQ_REPORT
  $nv"
  fi
  [ -n "${WST_JQ:-}" ] && WST_PREREQ_REPORT="$WST_PREREQ_REPORT
  bootstrap $("$WST_JQ" --version 2>/dev/null || echo jq)"
  export WST_PREREQ_REPORT
}

main() {
  setup_privilege
  # A dry-run changes nothing, so it takes no lock.
  [ "$DRY_RUN" = 1 ] || wst_lock_acquire
  os_prepare
  login_shell_step
  if [ "$BASH_CHANGED" = 1 ] || [ "$SHELL_CHANGED" = 1 ]; then
    log "Bash was installed/upgraded or the login shell changed."
    log "Open a NEW terminal so the updated shell is in effect, then rerun this script."
    exit 75
  fi
  if [ -z "$BASH5" ] || [ "$(wst_bash_version "$BASH5")" = "" ] \
     || ! "$BASH5" -c '[ "${BASH_VERSINFO[0]}" -ge 5 ]' 2>/dev/null; then
    if [ "$DRY_RUN" = 1 ]; then
      log "DRY-RUN: Bash 5 is not installed yet; the full plan needs Bash 5."
      log "DRY-RUN: install prerequisites with a real run, then rerun --dry-run for the full plan."
      exit 0
    fi
    die "Bash 5 is not available at ${BASH5:-<unknown>}"
  fi
  nvm_step
  bootstrap_jq
  prereq_report
  export WST_JQ BASH5 SUDO
  shopt -s execfail
  exec "$BASH5" "$WST_ROOT/scripts/common/main.sh" "$@" || die "could not exec $BASH5"
}

main "$@"
