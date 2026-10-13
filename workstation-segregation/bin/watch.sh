#!/bin/bash
# workstation-segregation watcher (cron entry). Scaffolds segregation for new top-level
# client directories in CLIENT_ROOT. Idempotent; safe to run at any time.
#
# Usage: watch.sh --config FILE [--verbose]
#   --verbose  log to stdout instead of $STATE_DIR/watch.log
set -Eeuo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG=""
VERBOSE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --config)  CONFIG="${2:?--config needs a file}"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    *) echo "usage: watch.sh --config FILE [--verbose]" >&2; exit 2 ;;
  esac
done
[ -n "$CONFIG" ] || { echo "watch.sh: --config is required" >&2; exit 2; }

# cron runs with a minimal environment.
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin"
export HOME="${HOME:?}"

# shellcheck source=/dev/null
. "$KIT_ROOT/lib/common.sh"
load_config "$CONFIG"
export PATH="$BIN_DIR:$PATH"
detect_platform
# shellcheck source=/dev/null
. "$KIT_ROOT/lib/scaffold.sh"

mkdir -p "$STATE_DIR"
if [ "$VERBOSE" != 1 ]; then
  exec >> "$STATE_DIR/watch.log" 2>&1
fi

# mkdir lock (flock does not exist on stock macOS); break locks older than 30 min.
LOCK="$STATE_DIR/watch.lock"
if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then
  warn "removing stale lock"
  rmdir "$LOCK" 2>/dev/null || true
fi
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

BASELINE="$STATE_DIR/baseline-dirs"
if [ ! -f "$BASELINE" ]; then
  die "baseline missing ($BASELINE); run deploy.sh first"
fi

check_client_root || exit 1

scaffolded=0
for d in "$CLIENT_ROOT"/*/; do
  d="${d%/}"
  [ -d "$d" ] || continue
  [ -L "$d" ] && continue
  name="$(basename "$d")"
  is_excluded "$name" && continue
  [ -e "$d/$MARKER_REL" ] && continue

  # Pre-existing, non-segregated dirs at deploy time are not clients unless
  # explicitly listed in ADOPT_DIRS.
  if grep -qxF "$name" "$BASELINE" && ! in_list "$name" "$ADOPT_DIRS"; then
    continue
  fi

  # Skip directories still being populated.
  if [ "$MIN_AGE_MIN" -gt 0 ] && [ -n "$(find "$d" -maxdepth 0 -mmin "-$MIN_AGE_MIN" 2>/dev/null)" ]; then
    log "'$name' modified within the last $MIN_AGE_MIN min; deferring"
    continue
  fi

  if scaffold_client "$d"; then
    scaffolded=$((scaffolded + 1))
    log "NEW CLIENT '$name' scaffolded: $(client_placeholder_status "$d") -- fill in REPLACE_ME values"
  fi
done

regen_gitconfig_clients
[ "$scaffolded" -eq 0 ] || log "scaffolded $scaffolded new client(s)"
exit 0
