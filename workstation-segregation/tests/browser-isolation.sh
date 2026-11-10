#!/bin/bash
# Isolated fixtures only: stub browsers, fake profile data, no network, no real
# browser launch, no workstation deployment.
set -Eeuo pipefail
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/wsk-browser.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
trap 'rm -rf "$fixture"' EXIT
export KIT_ROOT
. "$KIT_ROOT/lib/common.sh"
. "$KIT_ROOT/lib/scaffold.sh"
BIN_DIR="$fixture/bin"
mkdir -p "$BIN_DIR" "$fixture/clients" "$fixture/stubs" "$fixture/empty-apps"
export XDG_CONFIG_HOME="$fixture/config" XDG_STATE_HOME="$fixture/state" XDG_DATA_HOME="$fixture/data"
export DIRENV_LOG_FORMAT=''
export PATH="$BIN_DIR:$PATH"
command -v direnv >/dev/null || die 'tests require direnv'
command -v jq >/dev/null || die 'tests require jq'
ENABLE_AGENT_CLI_ISOLATION=1
# ENABLE_BROWSER_ISOLATION is deliberately unset here: scaffold must default it to off.
assert() { "$@" || die "assertion failed: $*"; }
refute() { if "$@"; then die "assertion failed (expected failure): $*"; fi; }

# --- fixtures ----------------------------------------------------------------
rec="$fixture/stubs/rec"
envdump="$fixture/stubs/env"
for name in chrome-stub firefox-stub; do
  # The launcher scrubs the environment, so stubs record next to themselves.
  cat > "$fixture/stubs/$name" <<'STUB'
#!/bin/bash
d="$(dirname "$0")"
env > "$d/env"
printf '%s\n' "${0##*/}" "$@" > "$d/rec"
STUB
  chmod 755 "$fixture/stubs/$name"
done

chrome_data="$fixture/chrome"
firefox_data="$fixture/firefox"
mkdir -p "$chrome_data/Default" "$chrome_data/Profile 2" "$chrome_data/Profile 3" \
  "$chrome_data/Profile 4" "$chrome_data/Profile 6" "$firefox_data"
cat > "$chrome_data/Local State" <<'JSON'
{"profile":{"info_cache":{
  "Default":{"name":"Person 1"},
  "Profile 2":{"name":"ClientA"},
  "Profile 3":{"name":"dup"},
  "Profile 4":{"name":"Dup"},
  "Profile 5":{"name":"stale"},
  "Profile 6":{"name":"client-b"}
}}}
JSON
cat > "$firefox_data/profiles.ini" <<'INI'
[Install4F96D1932A9F858E]
Default=Profiles/abc.default
Locked=1

[Profile1]
Name=ClientA
IsRelative=1
Path=Profiles/def.clienta

[Profile0]
Name=default
IsRelative=1
Path=Profiles/abc.default
Default=1

[General]
StartWithLastProfile=1
Version=2
INI

export WORKSTATION_BROWSER_FOREGROUND=1
export WORKSTATION_BROWSER_BIN_CHROME="$fixture/stubs/chrome-stub"
export WORKSTATION_BROWSER_BIN_FIREFOX="$fixture/stubs/firefox-stub"
export WORKSTATION_CHROME_DATA_DIR="$chrome_data" WORKSTATION_FIREFOX_DATA_DIR="$firefox_data"

# Default (variable unset) is off: the browser block is rendered commented out.
scaffold_client "$fixture/clients/default" > /dev/null
refute grep -q '^export BROWSER=' "$fixture/clients/default/.envrc"
refute grep -q '^PATH_add' "$fixture/clients/default/.envrc"
assert grep -qx '# export BROWSER="'"$KIT_ROOT"'/shims/browser/browser"' "$fixture/clients/default/.envrc"
refute grep -q '{{' "$fixture/clients/default/.envrc"
ENABLE_BROWSER_ISOLATION=1
for client in a b; do scaffold_client "$fixture/clients/$client" > /dev/null; done
a="$fixture/clients/a"
b="$fixture/clients/b"
mkdir -p "$a/sub/deeper"

# run_shim <cwd> <client dir> <shim> [args...]; profile selection from P_* globals.
P_CHROME='' P_FIREFOX='' P_BROWSER=''
run_shim() {
  local cwd="$1" cdir="$2" shim="$3" label
  shift 3
  label="$(printf '%s' "$(basename "$cdir")" | tr 'a-z.-' 'A-Z__')"
  rm -f "$rec" "$envdump"
  (
    cd "$cwd"
    # Client-style variables the browser must NOT inherit.
    export OPENAI_API_KEY=leak-check AWS_CONFIG_FILE=/leak/aws KUBECONFIG=/leak/kube \
      CLAUDE_CONFIG_DIR=/leak/claude GH_CONFIG_DIR=/leak/gh \
      BROWSER="$KIT_ROOT/shims/browser/browser" GH_BROWSER="$KIT_ROOT/shims/browser/browser"
    export PATH="$KIT_ROOT/shims/browser:$PATH"
    export WORKSTATION_CLIENT="$label" WORKSTATION_CLIENT_DIR="$cdir"
    export WORKSTATION_CHROME_PROFILE="$P_CHROME" WORKSTATION_FIREFOX_PROFILE="$P_FIREFOX"
    if [ -n "$P_BROWSER" ]; then export WORKSTATION_BROWSER="$P_BROWSER"; fi
    "$KIT_ROOT/shims/browser/$shim" "$@"
  ) > "$fixture/out" 2> "$fixture/err"
}
# expect <rc> <description> -- runs run_shim with the remaining args.
expect_rc() {
  local want="$1" rc=0
  shift
  run_shim "$@" || rc=$?
  [ "$rc" = "$want" ] || die "expected exit $want, got $rc: $* ($(cat "$fixture/err"))"
}
rec_line() { sed -n "${1}p" "$rec"; }

# --- Chrome name mapping ------------------------------------------------------
P_CHROME=clienta
expect_rc 0 "$a" "$a" chrome 'https://example.test/'
assert test "$(rec_line 1)" = chrome-stub
assert test "$(rec_line 2)" = '--profile-directory=Profile 2'
assert test "$(rec_line 3)" = 'https://example.test/'
# The browser runs with a scrubbed environment: no client state, no shim on PATH.
assert test -s "$envdump"
refute grep -Eq '^(WORKSTATION_|OPENAI_|AWS_|KUBECONFIG=|CLAUDE_CONFIG_DIR=|GH_CONFIG_DIR=|BROWSER=|GH_BROWSER=)' "$envdump"
refute grep -q 'shims/browser' "$envdump"
assert grep -qx "HOME=$HOME" "$envdump"
assert grep -qx 'PATH=/usr/bin:/bin:/usr/sbin:/sbin' "$envdump"
P_CHROME='Profile 6'            # directory name passes through
expect_rc 0 "$a" "$a" chrome
assert test "$(rec_line 2)" = '--profile-directory=Profile 6'
P_CHROME=CLIENT-B                  # case-insensitive display name
expect_rc 0 "$a" "$a" chrome
assert test "$(rec_line 2)" = '--profile-directory=Profile 6'
P_CHROME=dup                    # two existing dirs share a name
expect_rc 1 "$a" "$a" chrome
assert grep -q 'ambiguous' "$fixture/err"
assert test ! -e "$rec"
P_CHROME=stale                  # info_cache entry whose directory is gone
expect_rc 1 "$a" "$a" chrome
assert grep -q 'not found' "$fixture/err"
P_CHROME=nope
expect_rc 1 "$a" "$a" chrome
assert test ! -e "$rec"
P_CHROME='../etc'               # no path traversal out of the data dir
expect_rc 1 "$a" "$a" chrome
assert test ! -e "$rec"

# --- Firefox exact stored Name -------------------------------------------------
P_FIREFOX=clienta
expect_rc 0 "$a" "$a" firefox 'https://example.test/'
assert test "$(rec_line 1)" = firefox-stub
assert test "$(rec_line 2)" = -P
assert test "$(rec_line 3)" = ClientA
assert test "$(rec_line 4)" = 'https://example.test/'
P_FIREFOX='Profiles/abc.default' # [Install*] Default= is not a profile name
expect_rc 1 "$a" "$a" firefox
assert test ! -e "$rec"

# --- REPLACE_ME / unset: exit 1 directly, exit 0 + nothing via BROWSER ---------
P_CHROME=REPLACE_ME P_FIREFOX=REPLACE_ME
expect_rc 1 "$a" "$a" chrome
expect_rc 1 "$a" "$a" firefox
assert test ! -e "$rec"
expect_rc 0 "$a" "$a" browser 'https://example.test/'
assert test ! -e "$rec"
assert grep -q 'no browser opened' "$fixture/err"
P_CHROME='' P_FIREFOX=''
expect_rc 1 "$a" "$a" chrome

# --- default target follows WORKSTATION_BROWSER --------------------------------
P_CHROME=clienta P_FIREFOX=clienta
expect_rc 0 "$a" "$a" browser 'https://example.test/'
assert test "$(rec_line 1)" = chrome-stub
P_BROWSER=firefox
expect_rc 0 "$a" "$a" browser 'https://example.test/'
assert test "$(rec_line 1)" = firefox-stub
P_BROWSER=lynx
expect_rc 0 "$a" "$a" browser 'https://example.test/'
assert test ! -e "$rec"
P_BROWSER=''

# --- cwd rules ------------------------------------------------------------------
expect_rc 0 "$a/sub/deeper" "$a" chrome            # subdirectory is fine
assert test -e "$rec"
expect_rc 1 "$fixture" "$a" chrome                 # outside any client
assert test ! -e "$rec"
expect_rc 1 "$b" "$a" chrome                       # stale client A vars inside client B
assert test ! -e "$rec"
expect_rc 0 "$b" "$a" browser 'https://example.test/'
assert test ! -e "$rec"
rc=0
( cd "$a" && env -u WORKSTATION_CLIENT -u WORKSTATION_CLIENT_DIR "$KIT_ROOT/shims/browser/chrome" ) 2>/dev/null || rc=$?
assert test "$rc" = 1

# --- URL passthrough: one unchanged argument ------------------------------------
url='https://example.test/a b&c=%20d?x=$HOME;y=`id`'
expect_rc 0 "$a" "$a" chrome "$url"
assert test "$(rec_line 3)" = "$url"
assert test "$(wc -l < "$rec" | tr -d ' ')" = 3

# --- --list works anywhere, before any validation --------------------------------
P_CHROME=REPLACE_ME
expect_rc 0 "$fixture" "$a" browser --list
assert grep -q 'Profile 2	ClientA' "$fixture/out"
assert grep -q '^  ClientA$' "$fixture/out"
assert test ! -e "$rec"
# A missing data dir is reported, not shown as an empty list.
rc=0
(cd "$fixture" && WORKSTATION_CHROME_DATA_DIR="$fixture/none" WORKSTATION_FIREFOX_DATA_DIR="$fixture/none" \
  "$KIT_ROOT/shims/browser/browser" --list) > "$fixture/out" 2>&1 || rc=$?
assert test "$rc" = 0
assert test "$(grep -c 'no profile data found' "$fixture/out")" = 2

# --- PATH lookup must not find our own shim ---------------------------------------
mkdir -p "$fixture/pathstub"
cp "$fixture/stubs/firefox-stub" "$fixture/pathstub/firefox"
guard_rc=0
(
  cd "$a"
  unset WORKSTATION_BROWSER_BIN_FIREFOX
  export WORKSTATION_CLIENT=A WORKSTATION_CLIENT_DIR="$a" WORKSTATION_FIREFOX_PROFILE=clienta
  export WORKSTATION_BROWSER_APPS_DIR="$fixture/empty-apps"
  export PATH="$KIT_ROOT/shims/browser:$fixture/pathstub:$PATH"
  rm -f "$fixture/pathstub/rec"
  firefox 'https://example.test/' > "$fixture/out" 2> "$fixture/err" &
  pid=$!
  i=0
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null || true; exit 99; fi
  wait "$pid"
) || guard_rc=$?
assert test "$guard_rc" = 0
assert test "$(sed -n 1p "$fixture/pathstub/rec")" = firefox
assert test "$(sed -n 2p "$fixture/pathstub/rec")" = -P

# --- .envrc rendering ----------------------------------------------------------------
assert grep -qx "export BROWSER=\"$KIT_ROOT/shims/browser/browser\"" "$a/.envrc"
assert grep -qx 'export GH_BROWSER="$BROWSER"' "$a/.envrc"
assert grep -qx "PATH_add \"$KIT_ROOT/shims/browser\"" "$a/.envrc"
assert grep -qx 'export WORKSTATION_CHROME_PROFILE=REPLACE_ME' "$a/.envrc"
refute grep -q '{{' "$a/.envrc"

ENABLE_BROWSER_ISOLATION=0
scaffold_client "$fixture/clients/off" > /dev/null
off="$fixture/clients/off"
refute grep -q '^export BROWSER=' "$off/.envrc"
refute grep -q '^export GH_BROWSER=' "$off/.envrc"
refute grep -q '^PATH_add' "$off/.envrc"
refute grep -q '^if \[ "\${WORKSTATION_CHROME_PROFILE' "$off/.envrc"
assert grep -qx '# export BROWSER="'"$KIT_ROOT"'/shims/browser/browser"' "$off/.envrc"
refute grep -q '{{' "$off/.envrc"
ENABLE_BROWSER_ISOLATION=1

# --- direnv integration ---------------------------------------------------------------
# Unfilled placeholder is reported when the .envrc loads.
warn_out="$(cd "$b" && env DIRENV_LOG_FORMAT='%s' direnv export bash 2>&1 >/dev/null || true)"
case "$warn_out" in *'browser profile not set'*) ;; *) die "missing browser placeholder warning: $warn_out" ;; esac
# Client A sets real values; BROWSER/GH_BROWSER/PATH come from direnv, not the test env.
printf '\nexport WORKSTATION_CHROME_PROFILE=clienta\nexport WORKSTATION_FIREFOX_PROFILE=clienta\n' >> "$a/.envrc"
direnv allow "$a"
got="$(cd "$a/sub" && direnv exec "$a" /bin/bash -c 'printf "%s|%s|%s" "$BROWSER" "$GH_BROWSER" "$(command -v chrome)"')"
assert test "$got" = "$KIT_ROOT/shims/browser/browser|$KIT_ROOT/shims/browser/browser|$KIT_ROOT/shims/browser/chrome"
rm -f "$rec"
(cd "$a/sub" && direnv exec "$a" /bin/bash -c '"$BROWSER" "https://example.test/x"')
assert test "$(rec_line 1)" = chrome-stub
assert test "$(rec_line 2)" = '--profile-directory=Profile 2'
assert test "$(rec_line 3)" = 'https://example.test/x'

printf 'PASS: browser profile launcher, name mapping, failure semantics, cwd rules and .envrc rendering\n'
