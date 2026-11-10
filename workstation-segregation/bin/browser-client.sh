#!/bin/bash
# Open a URL in the active client's existing named browser profile.
#
#   browser-client.sh <chrome|firefox|default> [--list | browser args...]
#
# Reached through shims/browser/{chrome,firefox,browser}. "default" is the
# $BROWSER / $GH_BROWSER target and picks WORKSTATION_BROWSER (default chrome).
#
# Failure policy (no silent fallback to the shared default profile):
#   chrome/firefox  error on stderr, exit 1
#   default         error on stderr, open nothing, exit 0. Callers such as Python's
#                   webbrowser treat a non-zero exit as "could not launch" and fall
#                   back to the system browser. gh and aws print the full URL; az
#                   hides its query string, so use `az login --use-device-code`.
# Success means "launch requested", not "profile opened". The browser is started
# with a scrubbed environment (see scrubbed() below).
#
# Test-only knobs: WORKSTATION_BROWSER_BIN_CHROME / _FIREFOX (binary override),
# WORKSTATION_BROWSER_APPS_DIR (macOS app dir), WORKSTATION_CHROME_DATA_DIR,
# WORKSTATION_FIREFOX_DATA_DIR, WORKSTATION_BROWSER_FOREGROUND=1 (no detach).
set -Eeuo pipefail

kind="${1:-}"
[ "$#" -gt 0 ] && shift
case "$kind" in chrome|firefox|default) ;; *) printf 'browser-client: usage: %s <chrome|firefox|default> [args]\n' "${0##*/}" >&2; exit 2 ;; esac

fail() {
  if [ "$kind" = default ]; then
    printf 'browser-client: %s (no browser opened; open the printed URL in the right profile by hand, for az use: az login --use-device-code)\n' "$*" >&2
    exit 0
  fi
  printf 'browser-client: %s\n' "$*" >&2
  exit 1
}

os="$(uname -s)"
apps_dir="${WORKSTATION_BROWSER_APPS_DIR:-/Applications}"
if [ "$os" = Darwin ]; then
  chrome_data="${WORKSTATION_CHROME_DATA_DIR:-$HOME/Library/Application Support/Google/Chrome}"
  firefox_data="${WORKSTATION_FIREFOX_DATA_DIR:-$HOME/Library/Application Support/Firefox}"
else
  chrome_data="${WORKSTATION_CHROME_DATA_DIR:-$HOME/.config/google-chrome}"
  firefox_data="${WORKSTATION_FIREFOX_DATA_DIR:-$HOME/.mozilla/firefox}"
fi
shim_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../shims/browser" 2>/dev/null && pwd || true)"

# --- profile discovery -------------------------------------------------------

# chrome_profiles: "<dir>\t<display name>" per Local State entry.
# shellcheck disable=SC2329  # called indirectly by list_profiles
chrome_profiles() {
  command -v jq >/dev/null 2>&1 || return 3
  [ -f "$chrome_data/Local State" ] || return 4
  jq -r '(.profile.info_cache // {}) | to_entries[] | "\(.key)\t\(.value.name // "")"' \
    "$chrome_data/Local State"
}

# firefox_profiles: Name= of every [Profile*] section ([Install*]/[General] skipped).
firefox_profiles() {
  [ -f "$firefox_data/profiles.ini" ] || return 4
  awk '
    /^\[/ { insec = ($0 ~ /^\[Profile/); next }
    insec && /^Name=/ { n = substr($0, 6); sub(/\r$/, "", n); print n }
  ' "$firefox_data/profiles.ini"
}

# list_profiles <label> <data dir> <function>: never silent about why a list is empty.
list_profiles() {
  local out rc=0
  printf '%s (%s):\n' "$1" "$2"
  out="$("$3" 2>&1)" || rc=$?
  case "$rc" in
    0) if [ -n "$out" ]; then printf '%s\n' "$out" | sed 's/^/  /'; else printf '  (no profiles)\n'; fi ;;
    3) printf '  (jq is not installed)\n' ;;
    4) printf '  (no profile data found)\n' ;;
    *) printf '  (cannot read profile data: %s)\n' "$out" ;;
  esac
}

if [ "${1:-}" = --list ]; then
  list_profiles chrome "$chrome_data" chrome_profiles
  list_profiles firefox "$firefox_data" firefox_profiles
  exit 0
fi

# --- client validation (modelled on bin/codex-client.sh) ---------------------

client_dir="${WORKSTATION_CLIENT_DIR:-}"
[ -n "$client_dir" ] && [ -n "${WORKSTATION_CLIENT:-}" ] \
  || fail 'enter an isolated client directory first'
case "$client_dir" in /*) ;; *) fail 'client directory must be absolute' ;; esac
[ -f "$client_dir/.envrc" ] || fail 'client .envrc is missing'
client_name="$(basename "$client_dir")"
[[ "$client_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'invalid client name'
[ "$WORKSTATION_CLIENT" = "$(printf '%s' "$client_name" | tr 'a-z.-' 'A-Z__')" ] \
  || fail 'active client label does not match its directory'
client_real="$(cd -P "$client_dir" 2>/dev/null && pwd || true)"
[ -n "$client_real" ] || fail 'client directory is missing'
case "$(pwd -P)/" in "$client_real/"*) ;; *) fail 'current directory is outside the active client' ;; esac

# --- pick browser and profile ------------------------------------------------

if [ "$kind" = default ]; then
  kind_real="${WORKSTATION_BROWSER:-chrome}"
  case "$kind_real" in chrome|firefox) ;; *) fail "WORKSTATION_BROWSER must be chrome or firefox (got '$kind_real')" ;; esac
else
  kind_real="$kind"
fi

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

resolve_chrome() { # sets profile_arg
  local want="${WORKSTATION_CHROME_PROFILE:-}" matches="" dir name count=0 rc=0 listing
  { [ -n "$want" ] && [ "$want" != REPLACE_ME ]; } \
    || fail 'WORKSTATION_CHROME_PROFILE is not set in the client .envrc (list profiles: browser --list)'
  case "$want" in */*|..) fail "invalid WORKSTATION_CHROME_PROFILE '$want'" ;; esac
  if [ -d "$chrome_data/$want" ]; then
    profile_arg="--profile-directory=$want"
    return 0
  fi
  command -v jq >/dev/null 2>&1 || fail 'jq is required to map a Chrome profile name to its directory'
  [ -f "$chrome_data/Local State" ] || fail "Chrome profile data not found: $chrome_data/Local State"
  listing="$(jq -r --arg n "$want" '
      (.profile.info_cache // {}) | to_entries[]
      | select(((.value.name // "") | ascii_downcase) == ($n | ascii_downcase)) | .key
    ' "$chrome_data/Local State")" || rc=$?
  [ "$rc" = 0 ] || fail "cannot read $chrome_data/Local State"
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    case "$dir" in */*|..) continue ;; esac
    [ -d "$chrome_data/$dir" ] || continue
    matches="${matches:+$matches }$dir"
    count=$((count + 1))
    name="$dir"
  done <<EOF
$listing
EOF
  case "$count" in
    1) profile_arg="--profile-directory=$name" ;;
    0) fail "Chrome profile '$want' not found (list profiles: browser --list)" ;;
    *) fail "Chrome profile '$want' is ambiguous; matching directories: $matches. Set WORKSTATION_CHROME_PROFILE to a directory name" ;;
  esac
}

resolve_firefox() { # sets profile_arg (value for -P)
  local want="${WORKSTATION_FIREFOX_PROFILE:-}" w name count=0 matches="" names rc=0
  { [ -n "$want" ] && [ "$want" != REPLACE_ME ]; } \
    || fail 'WORKSTATION_FIREFOX_PROFILE is not set in the client .envrc (list profiles: browser --list)'
  [ -f "$firefox_data/profiles.ini" ] || fail "Firefox profile data not found: $firefox_data/profiles.ini"
  names="$(firefox_profiles)" || rc=$?
  [ "$rc" = 0 ] || fail "cannot read $firefox_data/profiles.ini"
  w="$(lower "$want")"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ "$(lower "$name")" = "$w" ] || continue
    matches="${matches:+$matches, }'$name'"
    count=$((count + 1))
    profile_arg="$name"
  done <<EOF
$names
EOF
  case "$count" in
    1) ;;
    0) fail "Firefox profile '$want' not found (list profiles: browser --list)" ;;
    *) fail "Firefox profile '$want' is ambiguous: $matches" ;;
  esac
}

# Strip the shim directory from PATH so a PATH lookup cannot find our own shim.
clean_path() {
  local p out="" IFS=:
  for p in $PATH; do
    if [ -n "$shim_dir" ] && [ "$(cd -P "$p" 2>/dev/null && pwd || true)" = "$shim_dir" ]; then continue; fi
    out="${out:+$out:}$p"
  done
  printf '%s' "$out"
}

find_bin() { # find_bin <chrome|firefox>
  local override found name candidates
  if [ "$1" = chrome ]; then
    override="${WORKSTATION_BROWSER_BIN_CHROME:-}"
    candidates="google-chrome google-chrome-stable chromium chromium-browser"
  else
    override="${WORKSTATION_BROWSER_BIN_FIREFOX:-}"
    candidates="firefox"
  fi
  if [ -n "$override" ]; then printf '%s' "$override"; return 0; fi
  if [ "$os" = Darwin ]; then
    if [ "$1" = chrome ]; then found="$apps_dir/Google Chrome.app/Contents/MacOS/Google Chrome"
    else found="$apps_dir/Firefox.app/Contents/MacOS/firefox"; fi
    if [ -x "$found" ]; then printf '%s' "$found"; return 0; fi
  fi
  for name in $candidates; do
    found="$( PATH="$(clean_path)"; type -P "$name" || true )"
    if [ -n "$found" ]; then printf '%s' "$found"; return 0; fi
  done
  return 1
}

profile_arg=""
if [ "$kind_real" = chrome ]; then
  resolve_chrome
  set -- "$profile_arg" "$@"
else
  resolve_firefox
  set -- -P "$profile_arg" "$@"
fi

bin="$(find_bin "$kind_real")" || fail "$kind_real is not installed or is missing from PATH"
[ -x "$bin" ] || fail "$kind_real binary is not executable: $bin"

# The browser may outlive this call and then serves every profile (and spawns native
# messaging hosts), so it must not inherit the client's environment (AWS_*, KUBECONFIG,
# GH_CONFIG_DIR, CLAUDE_CONFIG_DIR, OPENAI_*, WORKSTATION_*, BROWSER, the shim PATH).
# Allowlist only what a GUI browser needs; the rest of the login session supplies it.
scrubbed() {
  env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    ${USER+"USER=$USER"} ${LOGNAME+"LOGNAME=$LOGNAME"} ${TMPDIR+"TMPDIR=$TMPDIR"} \
    ${LANG+"LANG=$LANG"} ${LC_ALL+"LC_ALL=$LC_ALL"} \
    ${__CF_USER_TEXT_ENCODING+"__CF_USER_TEXT_ENCODING=$__CF_USER_TEXT_ENCODING"} \
    ${DISPLAY+"DISPLAY=$DISPLAY"} ${WAYLAND_DISPLAY+"WAYLAND_DISPLAY=$WAYLAND_DISPLAY"} \
    ${XDG_RUNTIME_DIR+"XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"} ${XDG_SESSION_TYPE+"XDG_SESSION_TYPE=$XDG_SESSION_TYPE"} \
    ${DBUS_SESSION_BUS_ADDRESS+"DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"} \
    ${XAUTHORITY+"XAUTHORITY=$XAUTHORITY"} \
    "$@"
}

if [ "${WORKSTATION_BROWSER_FOREGROUND:-0}" = 1 ]; then
  scrubbed "$bin" "$@"
  exit $?
fi
scrubbed nohup "$bin" "$@" </dev/null >/dev/null 2>&1 &
exit 0
