#!/bin/bash
# workstation-segregation deploy: the single entry point.
#
#   ./deploy.sh [--config FILE] [--dry-run] [--skip-tools] [--update-tools] [--yes]
#   ./deploy.sh --uninstall [--config FILE] [--dry-run]
#
# Installs tools (release binaries, no package manager), writes the managed
# shell/git/Claude configuration, adopts already-segregated client dirs, and
# installs the cron watcher that scaffolds new client dirs.
# Runs on stock bash 3.2 (macOS) and bash 5 (Linux).
set -Eeuo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export KIT_ROOT
CONFIG="$KIT_ROOT/workstation-segregation.conf"
DRY_RUN=0
UNINSTALL=0
SKIP_TOOLS=0
ASSUME_YES=0
UPDATE_TOOLS=0

usage() { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --config)       CONFIG="${2:?--config needs a file}"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --uninstall)    UNINSTALL=1; shift ;;
    --skip-tools)   SKIP_TOOLS=1; shift ;;
    --update-tools) UPDATE_TOOLS=1; shift ;;
    --yes|-y)       ASSUME_YES=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
export DRY_RUN UPDATE_TOOLS

# shellcheck source=lib/common.sh
. "$KIT_ROOT/lib/common.sh"

if [ ! -f "$CONFIG" ]; then
  if [ "$UNINSTALL" = 1 ]; then
    CONFIG="$KIT_ROOT/workstation-segregation.conf.example"
  else
    cp "$KIT_ROOT/workstation-segregation.conf.example" "$CONFIG"
    log "created $CONFIG from the example."
    log "Review it (especially CLIENT_ROOT), then re-run ./deploy.sh"
    exit 1
  fi
fi
load_config "$CONFIG"
detect_platform
# shellcheck source=lib/tools.sh
. "$KIT_ROOT/lib/tools.sh"
# shellcheck source=lib/global.sh
. "$KIT_ROOT/lib/global.sh"
# shellcheck source=lib/scaffold.sh
. "$KIT_ROOT/lib/scaffold.sh"
export CONFIG_FILE STATE_DIR CLIENT_ROOT WATCH_INTERVAL_MIN

[ "$DRY_RUN" = 1 ] && log "dry run: no changes will be made"

# --- uninstall ---------------------------------------------------------------
if [ "$UNINSTALL" = 1 ]; then
  log "uninstalling workstation-segregation (client directories are never touched)"
  /bin/bash "$KIT_ROOT/scheduler/install.sh" remove
  global_uninstall
  uninstall_tools
  run rm -rf "$STATE_DIR"
  log "done. Per-client files (.envrc, .workstation/) were left in place."
  exit 0
fi

# --- prerequisites -----------------------------------------------------------
check_prereqs() {
  local missing="" c pkgs=""
  for c in curl tar unzip git; do
    command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
  done
  command -v crontab >/dev/null 2>&1 || missing="$missing cron"
  [ -z "$missing" ] && return 0

  if [ "$KIT_OS" = darwin ]; then
    die "missing prerequisites:$missing (install Xcode Command Line Tools: xcode-select --install)"
  fi
  if ! grep -qiE 'debian|ubuntu' /etc/os-release 2>/dev/null; then
    die "missing prerequisites:$missing (install them with your package manager; only Ubuntu/Debian is auto-handled)"
  fi
  for c in $missing; do pkgs="$pkgs $c"; done
  log "missing prerequisites:$pkgs"
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: sudo apt-get install -y$pkgs"
    return 0
  fi
  if [ "$ASSUME_YES" != 1 ]; then
    [ -t 0 ] || die "run interactively or pass --yes to apt-get install:$pkgs"
    printf '[segregation] apt-get install%s with sudo? [y/N] ' "$pkgs"
    read -r ans
    case "$ans" in y|Y|yes) ;; *) die "prerequisites required" ;; esac
  fi
  sudo apt-get update -qq
  # shellcheck disable=SC2086
  sudo apt-get install -y $pkgs
}

log "platform: $KIT_OS/$KIT_ARCH   client root: $CLIENT_ROOT   config: $CONFIG_FILE"
check_prereqs

# --- tools -------------------------------------------------------------------
if [ "$SKIP_TOOLS" = 1 ]; then
  log "skipping tool installation (--skip-tools)"
else
  install_tools
fi
export PATH="$BIN_DIR:$PATH"

# --- global configuration ----------------------------------------------------
run mkdir -p "$STATE_DIR" "$KIT_CONFIG_DIR"
global_install

# --- clients -----------------------------------------------------------------
if [ ! -d "$CLIENT_ROOT" ]; then
  warn "CLIENT_ROOT does not exist yet: $CLIENT_ROOT (creating)"
  run mkdir -p "$CLIENT_ROOT"
fi

# Baseline: every top-level dir present at first deploy. The watcher only acts
# on dirs created afterwards (or listed in ADOPT_DIRS).
BASELINE="$STATE_DIR/baseline-dirs"
if [ ! -f "$BASELINE" ] && [ "$DRY_RUN" != 1 ]; then
  check_client_root || die "cannot read CLIENT_ROOT"
  for d in "$CLIENT_ROOT"/*/; do
    [ -d "$d" ] || continue
    basename "${d%/}"
  done > "$BASELINE"
  log "recorded baseline of $(wc -l < "$BASELINE" | tr -d ' ') existing directories"
fi

adopted=""
ignored=""
for d in "$CLIENT_ROOT"/*/; do
  d="${d%/}"
  [ -d "$d" ] && [ ! -L "$d" ] || continue
  name="$(basename "$d")"
  is_excluded "$name" && continue
  if is_segregated "$d"; then
    if scaffold_client "$d" adopt; then adopted="$adopted $name"; fi
  elif in_list "$name" "$ADOPT_DIRS"; then
    if scaffold_client "$d"; then adopted="$adopted $name"; fi
  elif [ -f "$BASELINE" ] && grep -qxF "$name" "$BASELINE"; then
    ignored="$ignored $name"
  fi
done
if [ "$DRY_RUN" != 1 ]; then regen_gitconfig_clients; fi

# --- scheduler ---------------------------------------------------------------
/bin/bash "$KIT_ROOT/scheduler/install.sh" install

# --- summary -----------------------------------------------------------------
log "------------------------------------------------------------"
log "adopted existing clients:${adopted:- (none)}"
log "  (adopted clients keep their existing .envrc/git config: they do NOT get core.sshCommand or"
log "   agent-CLI isolation until you add them by hand; see templates/client/git-config and envrc)"
[ -z "$ignored" ] || log "existing dirs NOT treated as clients:$ignored (add to ADOPT_DIRS in the config to include)"
if [ "$DRY_RUN" != 1 ]; then
  for d in "$CLIENT_ROOT"/*/; do
    d="${d%/}"
    [ -f "$d/$MARKER_REL" ] || continue
    log "  $(basename "$d"): $(client_placeholder_status "$d")"
  done
fi
log "Open a NEW terminal for the shell integration. New client dirs in $CLIENT_ROOT"
log "are scaffolded by the watcher within ~$((WATCH_INTERVAL_MIN + MIN_AGE_MIN)) min; log: $STATE_DIR/watch.log"
