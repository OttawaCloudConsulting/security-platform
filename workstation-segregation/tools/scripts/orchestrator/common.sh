#!/bin/bash
# Shared helpers for the orchestrator AND the Bash 5 engine. Source only; must
# stay bash 3.2-safe (no declare -A, mapfile, ${v,,}, [[ -v ]], |&, &>>,
# local -n, globstar).

# shellcheck disable=SC2034
: "${DRY_RUN:=0}"
: "${ASSUME_YES:=0}"

_ts() { date '+%Y-%m-%dT%H:%M:%S'; }
log()  { printf '%s [workstation-tools] %s\n' "$(_ts)" "$*"; }
warn() { printf '%s [workstation-tools] WARN: %s\n' "$(_ts)" "$*" >&2; }
die()  { printf '%s [workstation-tools] ERROR: %s\n' "$(_ts)" "$*" >&2; exit 1; }
usage_die() { printf '%s [workstation-tools] USAGE: %s\n' "$(_ts)" "$*" >&2; exit 2; }

# Run a mutating command, or only print it under --dry-run.
run() {
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: $*"
  else
    "$@"
  fi
}

# Crash simulation for tests: WST_TEST_ABORT_AT=<name> kills the process
# without running traps when execution reaches that barrier.
wst_barrier() {
  if [ "${WST_TEST_ABORT_AT:-}" = "$1" ]; then
    kill -9 "$$" 2>/dev/null
    # inside a pipeline subshell $$ is the parent: take this process down too
    kill -9 "${BASHPID:-$$}"
  fi
}

wst_detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  WST_ARCH=amd64 ;;
    arm64|aarch64) WST_ARCH=arm64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac
}

wst_detect_os() {
  case "$(uname -s)" in
    Darwin) WST_OS=macos ;;
    Linux)
      if grep -qiE '^ID(_LIKE)?=.*(ubuntu|debian)' /etc/os-release 2>/dev/null; then
        WST_OS=ubuntu
      else
        die "unsupported Linux distribution (only Ubuntu is supported)"
      fi
      ;;
    *) die "unsupported OS: $(uname -s)" ;;
  esac
  wst_detect_arch
}

wst_mtime() { # epoch mtime of a path, portable
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# Ask a [y/N] question; ASSUME_YES answers yes; no TTY and no --yes is an error.
wst_confirm() {
  local what="$1" ans
  [ "$ASSUME_YES" = 1 ] && return 0
  [ -t 0 ] || die "$what requires confirmation: run interactively or pass --yes"
  printf '[workstation-tools] %s [y/N] ' "$what"
  read -r ans
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ---- lock: mkdir lock with a pid file -------------------------------------
wst_lock_default() {
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/workstation-tools/lock"
}

# 0 when the lock is stale. A live pid (including EPERM) is never stale; a dead
# pid is stale once its pid file is older than the threshold; a lock with no pid
# file is initializing until the directory is older than the threshold.
wst_lock_is_stale() {
  local lock="$1" stale="${WST_LOCK_STALE_SECS:-300}" pid err ref now
  now="$(date +%s)"
  if [ -f "$lock/pid" ]; then
    pid="$(cat "$lock/pid" 2>/dev/null || true)"
    if [ -n "$pid" ]; then
      if err="$(kill -0 "$pid" 2>&1)"; then return 1; fi
      case "$err" in *[Nn]ot\ permitted*|*EPERM*) return 1 ;; esac
    fi
    ref="$lock/pid"
  else
    ref="$lock"
  fi
  [ $((now - $(wst_mtime "$ref"))) -gt "$stale" ]
}

wst_lock_arm() {
  # shellcheck disable=SC2064
  trap 'wst_lock_release' EXIT
}

wst_lock_release() {
  if [ -n "${WST_LOCK:-}" ] && [ -f "$WST_LOCK/pid" ] \
     && [ "$(cat "$WST_LOCK/pid" 2>/dev/null)" = "$$" ]; then
    rm -rf "$WST_LOCK"
  fi
}

wst_lock_acquire() {
  local lock="${1:-$(wst_lock_default)}"
  mkdir -p "$(dirname "$lock")"
  if ! mkdir "$lock" 2>/dev/null; then
    if wst_lock_is_stale "$lock"; then
      warn "removing stale lock $lock"
      rm -rf "$lock"
      mkdir "$lock" 2>/dev/null || die "another workstation-tools run holds the lock: $lock"
    else
      die "another workstation-tools run is in progress (lock: $lock)"
    fi
  fi
  wst_barrier lock-mkdir
  printf '%s\n' "$$" > "$lock/pid"
  WST_LOCK="$lock"
  export WST_LOCK
  wst_lock_arm
}

# After exec the PID is unchanged: re-arm the trap on a lock we already own,
# otherwise take the lock (direct invocations, tests).
wst_lock_adopt_or_acquire() {
  if [ -n "${WST_LOCK:-}" ] && [ -f "$WST_LOCK/pid" ] \
     && [ "$(cat "$WST_LOCK/pid" 2>/dev/null)" = "$$" ]; then
    wst_lock_arm
  else
    WST_LOCK=""
    wst_lock_acquire
  fi
}
