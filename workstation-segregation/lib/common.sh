#!/bin/bash
# workstation-segregation common helpers. Source only; must stay bash 3.2-safe
# (no declare -A, mapfile, ${v,,}, [[ -v ]], |&, &>>, local -n, globstar).

: "${DRY_RUN:=0}"
: "${KIT_ROOT:?KIT_ROOT must be set before sourcing common.sh}"

_ts() { date '+%Y-%m-%dT%H:%M:%S'; }
log()  { printf '%s [segregation] %s\n' "$(_ts)" "$*"; }
warn() { printf '%s [segregation] WARN: %s\n' "$(_ts)" "$*" >&2; }
die()  { printf '%s [segregation] ERROR: %s\n' "$(_ts)" "$*" >&2; exit 1; }

# Run a mutating command, or only print it under --dry-run.
run() {
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: $*"
  else
    "$@"
  fi
}

detect_platform() {
  case "$(uname -s)" in
    Darwin) KIT_OS=darwin ;;
    Linux)  KIT_OS=linux ;;
    *) die "unsupported OS: $(uname -s)" ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  KIT_ARCH=amd64 ;;
    arm64|aarch64) KIT_ARCH=arm64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac
}

expand_home() {
  case "$1" in
    "~")   printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${1#\~/}" ;;
    *)     printf '%s\n' "$1" ;;
  esac
}

# load_config <file>: defaults first, then the user's file, then versions.conf.
load_config() {
  local cfg="$1"
  [ -f "$cfg" ] || die "config not found: $cfg"
  CONFIG_FILE="$(cd "$(dirname "$cfg")" && pwd)/$(basename "$cfg")"

  CLIENT_ROOT="$HOME/Documents"
  EXCLUDE_DIRS="workstation workstation-segregation tools Codex Zoom"
  ADOPT_DIRS=""
  WATCH_INTERVAL_MIN=5
  MIN_AGE_MIN=2
  ENABLE_AGENT_CLI_ISOLATION=1
  INSTALL_TOOLS="jq yq direnv gh kubectl helm starship sops age terraform awscli"
  REQUIRE_CHECKSUMS=0
  BIN_DIR="$HOME/.local/bin"
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"
  if [ -f "$KIT_ROOT/versions.conf" ]; then
    # shellcheck source=/dev/null
    . "$KIT_ROOT/versions.conf"
  fi

  CLIENT_ROOT="$(expand_home "$CLIENT_ROOT")"
  CLIENT_ROOT="${CLIENT_ROOT%/}"
  BIN_DIR="$(expand_home "$BIN_DIR")"
  case "$CLIENT_ROOT" in /*) ;; *) die "CLIENT_ROOT must be an absolute path: $CLIENT_ROOT" ;; esac
  case "$CLIENT_ROOT$BIN_DIR$KIT_ROOT" in
    *[[:space:]]*) die "whitespace in CLIENT_ROOT, BIN_DIR or the kit path is not supported" ;;
  esac
  # Never treat the kit itself as a client, whatever it is named.
  if [ "$(dirname "$KIT_ROOT")" = "$CLIENT_ROOT" ]; then
    EXCLUDE_DIRS="$EXCLUDE_DIRS $(basename "$KIT_ROOT")"
  fi
  case "$WATCH_INTERVAL_MIN" in ''|*[!0-9]*) die "WATCH_INTERVAL_MIN must be a positive integer" ;; esac
  case "$MIN_AGE_MIN" in ''|*[!0-9]*) die "MIN_AGE_MIN must be a non-negative integer" ;; esac

  STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/workstation-segregation"
  KIT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/workstation-segregation"
}

# is_excluded <name>: dot-dirs and EXCLUDE_DIRS are never clients.
is_excluded() {
  local n="$1" x
  case "$n" in .*) return 0 ;; esac
  for x in $EXCLUDE_DIRS; do
    [ "$x" = "$n" ] && return 0
  done
  return 1
}

in_list() { # in_list <name> <space separated list>
  local n="$1" x
  shift
  for x in $*; do
    [ "$x" = "$n" ] && return 0
  done
  return 1
}

backup_file() {
  local f="$1"
  [ -e "$f" ] || return 0
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: backup $f"
    return 0
  fi
  cp -p "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"
}

sed_escape() { printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'; }

_block_begin() { printf '# >>> workstation-segregation:%s >>>' "$1"; }
_block_end()   { printf '# <<< workstation-segregation:%s <<<' "$1"; }

# _block_strip <file> <id>: print file without the managed block.
_block_strip() {
  awk -v b="$(_block_begin "$2")" -v e="$(_block_end "$2")" \
    '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$1"
}

# block_insert <file> <id>   (block content on stdin)
# The block is always (re)placed at the END of the file, which matters for
# ~/.gitconfig ordering. File is only touched (and backed up) when it changes.
block_insert() {
  local f="$1" id="$2" content tmp
  content="$(cat)"
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: write managed block '$id' to $f"
    return 0
  fi
  mkdir -p "$(dirname "$f")"
  [ -f "$f" ] || : > "$f"
  tmp="$(mktemp "${TMPDIR:-/tmp}/wsk-block.XXXXXX")"
  _block_strip "$f" "$id" > "$tmp"
  if [ -s "$tmp" ] && [ "$(tail -c1 "$tmp" | wc -l | tr -d ' ')" = 0 ]; then
    printf '\n' >> "$tmp"
  fi
  { _block_begin "$id"; printf '\n%s\n' "$content"; _block_end "$id"; printf '\n'; } >> "$tmp"
  if cmp -s "$tmp" "$f"; then
    log "unchanged: $f ($id)"
  else
    backup_file "$f"
    cat "$tmp" > "$f"
    log "updated: $f ($id)"
  fi
  rm -f "$tmp"
}

block_remove() { # block_remove <file> <id>
  local f="$1" id="$2" tmp
  [ -f "$f" ] || return 0
  grep -qF "$(_block_begin "$id")" "$f" || return 0
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: remove managed block '$id' from $f"
    return 0
  fi
  backup_file "$f"
  tmp="$(mktemp "${TMPDIR:-/tmp}/wsk-block.XXXXXX")"
  _block_strip "$f" "$id" > "$tmp"
  cat "$tmp" > "$f"
  rm -f "$tmp"
  log "removed block '$id' from $f"
}

# write_file_if_changed <dest> <mode>  (content on stdin)
write_file_if_changed() {
  local dest="$1" mode="${2:-644}" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/wsk-file.XXXXXX")"
  cat > "$tmp"
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: write $dest"
    rm -f "$tmp"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    return 0
  fi
  cat "$tmp" > "$dest"
  chmod "$mode" "$dest"
  rm -f "$tmp"
  log "wrote $dest"
}

# render_template <src>: substitute {{TOKENS}} from R_* variables.
render_template() {
  sed \
    -e "s|{{CLIENT}}|$(sed_escape "$R_CLIENT")|g" \
    -e "s|{{CLIENT_UC}}|$(sed_escape "$R_CLIENT_UC")|g" \
    -e "s|{{DIR}}|$(sed_escape "$R_DIR")|g" \
    -e "s|{{KIT}}|$(sed_escape "$KIT_ROOT")|g" \
    -e "s|{{GH}}|$(sed_escape "$R_GH")|g" \
    -e "s|{{HOME}}|$(sed_escape "$HOME")|g" \
    -e "s|{{AGENT_PREFIX}}|$(sed_escape "$R_AGENT_PREFIX")|g" \
    "$1"
}

# Directory listing that surfaces macOS TCC denials instead of silently
# yielding nothing. Returns 0 if CLIENT_ROOT is readable.
check_client_root() {
  local err
  [ -d "$CLIENT_ROOT" ] || { warn "CLIENT_ROOT does not exist: $CLIENT_ROOT"; return 1; }
  if ! err="$(ls -A "$CLIENT_ROOT" 2>&1 >/dev/null)"; then
    case "$err" in
      *"Operation not permitted"*)
        warn "macOS privacy (TCC) blocks access to $CLIENT_ROOT from this process."
        warn "Grant Full Disk Access to /usr/sbin/cron (System Settings > Privacy & Security > Full Disk Access), then retry."
        ;;
      *) warn "cannot read $CLIENT_ROOT: $err" ;;
    esac
    return 1
  fi
  return 0
}
