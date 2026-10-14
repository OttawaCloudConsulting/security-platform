#!/bin/bash
# macOS prerequisites: Command Line Tools, Homebrew, Bash. Bash 3.2-safe.

wst_with_timeout() { # wst_with_timeout <secs> cmd... ; 124 on timeout
  local secs="$1" pid waited=0
  shift
  "$@" &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$secs" ]; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 2; waited=$((waited + 2))
  done
  wait "$pid"
}

macos_clt() {
  local marker="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress" label
  if xcode-select -p >/dev/null 2>&1 && /usr/bin/git --version >/dev/null 2>&1; then
    log "Xcode Command Line Tools present"
    return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: install Xcode Command Line Tools (softwareupdate)"
    return 0
  fi
  log "installing Xcode Command Line Tools (this can take a while)"
  touch "$marker"
  label="$(softwareupdate -l 2>/dev/null \
    | sed -n 's/^[[:space:]]*\*[[:space:]]*\(Label: \)\{0,1\}\(Command Line Tools.*\)$/\2/p' | sort -V | tail -n1)"
  if [ -z "$label" ]; then
    rm -f "$marker"
    die "no Command Line Tools update found; run 'xcode-select --install', then rerun"
  fi
  # shellcheck disable=SC2086
  if ! wst_with_timeout "${WST_CLT_TIMEOUT:-3600}" $SUDO softwareupdate -i "$label"; then
    rm -f "$marker"
    die "Command Line Tools install failed or timed out; run 'xcode-select --install', then rerun"
  fi
  rm -f "$marker"
  if ! { xcode-select -p >/dev/null 2>&1 && /usr/bin/git --version >/dev/null 2>&1; }; then
    die "Command Line Tools not usable after install; run 'xcode-select --install', then rerun"
  fi
}

macos_find_brew() {
  local b
  if [ -n "${WST_BREW:-}" ] && [ -x "$WST_BREW" ]; then BREW="$WST_BREW"; return 0; fi
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && { BREW="$b"; return 0; }
  done
  BREW="$(command -v brew 2>/dev/null || true)"
  [ -n "$BREW" ]
}

macos_brew() {
  local tmp
  if ! macos_find_brew; then
    if [ "$DRY_RUN" = 1 ]; then
      log "DRY-RUN: install Homebrew (integrity: unverified, official installer)"
      return 0
    fi
    log "installing Homebrew (integrity: unverified, official installer)"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/wst-brew.XXXXXX")"
    curl -fsSL -o "$tmp/install.sh" https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
      || die "could not download the Homebrew installer"
    NONINTERACTIVE=1 /bin/bash "$tmp/install.sh" || die "Homebrew install failed"
    rm -rf "$tmp"
    macos_find_brew || die "Homebrew not found after install"
  fi
  eval "$("$BREW" shellenv)"
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: brew update"
  else
    "$BREW" update || die "brew update failed"
  fi
  # freeze targets for the rest of the run
  HOMEBREW_NO_AUTO_UPDATE=1; export HOMEBREW_NO_AUTO_UPDATE
}

# macos_bash: sets BASH5 and BASH_CHANGED
macos_bash() {
  local prefix before after
  if [ -z "${BREW:-}" ] && ! macos_find_brew; then BASH5=""; return 0; fi
  prefix="$("$BREW" --prefix)"
  BASH5="$prefix/bin/bash"
  before="$(wst_bash_version "$BASH5")"
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: brew install/upgrade bash (current: ${before:-none})"
    return 0
  fi
  if "$BREW" list --formula bash >/dev/null 2>&1; then
    "$BREW" upgrade bash || die "brew upgrade bash failed"
  else
    "$BREW" install bash || die "brew install bash failed"
  fi
  after="$(wst_bash_version "$BASH5")"
  [ "$before" = "$after" ] || BASH_CHANGED=1
}

os_prepare() {
  macos_clt
  macos_brew
  macos_bash
}

os_login_shell() { dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}'; }

os_prereq_versions() {
  local v
  v="$("$BREW" --version 2>/dev/null | head -n1 || true)"; [ -n "$v" ] && printf '  %s\n' "$v"
  v="$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | awk '/^version:/{print $2}')"
  printf '  Xcode Command Line Tools %s\n' "${v:-present}"
}
