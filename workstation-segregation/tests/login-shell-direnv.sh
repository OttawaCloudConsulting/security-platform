#!/bin/bash
# Non-interactive login shells (agent command shells draw no prompt, so the interactive
# PROMPT_COMMAND hook never runs) must still get the approved client environment, and
# only that: unapproved or no client means nothing, and a shell started in another
# client replaces the inherited environment. Uses real direnv; skips when it is absent.
set -Eeuo pipefail
kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v direnv >/dev/null 2>&1 || { echo "SKIP: direnv not found"; exit 0; }
direnv_dir="$(dirname "$(command -v direnv)")"

fixture="$(mktemp -d "${TMPDIR:-/tmp}/wsk-loginshell.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
trap 'rm -rf "$fixture"' EXIT
home="$fixture/home"
mkdir -p "$home/.config" "$home/.local/share" "$fixture/clients/a" "$fixture/clients/b" \
  "$fixture/clients/denied" "$fixture/outside"

# The same login-shell bootstrap the managed ~/.bash_profile block sources.
cat > "$home/.bash_profile" <<PROFILE
export WORKSTATION_SEGREGATION_ROOT="$kit"
. "$kit/shell/bash_profile.sh"
PROFILE
for c in a b denied; do
  printf 'export WSK_TEST_CLIENT=%s\n' "$c" > "$fixture/clients/$c/.envrc"
done

# Isolated direnv state; a stray outer client environment must not leak in.
dr() { env -i HOME="$home" PATH="$direnv_dir:/usr/bin:/bin" SHELL=/bin/bash \
  XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" "$@"; }
dr direnv allow "$fixture/clients/a" >/dev/null 2>&1
dr direnv allow "$fixture/clients/b" >/dev/null 2>&1

fail() { echo "FAIL: $*" >&2; exit 1; }
# Single-quoted on purpose: expanded by the shell under test, not by this script.
# shellcheck disable=SC2016
show_client='printf %s "${WSK_TEST_CLIENT-}"'
# login_value <shell> <start dir>: value of WSK_TEST_CLIENT seen by a non-interactive
# login shell started in <start dir>.
login_value() {
  local sh="$1" dir="$2" cmd="$show_client"
  ( cd "$dir" && dr "$sh" -l -c "$cmd" 2>/dev/null )
}

for sh in /bin/bash ${BASH_BIN:-}; do
  [ -x "$sh" ] || continue
  [ "$(login_value "$sh" "$fixture/clients/a")" = a ] || fail "$sh: approved client a not loaded"
  [ "$(login_value "$sh" "$fixture/clients/b")" = b ] || fail "$sh: approved client b not loaded"
  [ -z "$(login_value "$sh" "$fixture/clients/denied")" ] || fail "$sh: unapproved .envrc was loaded"
  [ -z "$(login_value "$sh" "$fixture/outside")" ] || fail "$sh: environment set outside any client"
  # An agent shell inherits the previous client's environment: a login shell started in
  # b (or outside) must replace it, not keep a's.
  out="$( cd "$fixture/clients/a" && dr "$sh" -l -c "cd '$fixture/clients/b' && $sh -l -c '$show_client'" 2>/dev/null )"
  [ "$out" = b ] || fail "$sh: switching a -> b gave '${out}'"
  out="$( cd "$fixture/clients/a" && dr "$sh" -l -c "cd '$fixture/outside' && $sh -l -c '$show_client'" 2>/dev/null )"
  [ -z "$out" ] || fail "$sh: leaving a for outside kept '${out}'"
done

# Interactive shells are unchanged: the bootstrap adds no direnv export for them.
out="$( cd "$fixture/clients/a" && dr /bin/bash -i -l -c "$show_client" 2>/dev/null </dev/null || true )"
[ -z "$out" ] || fail "interactive login shell exported at startup: '$out'"

echo "PASS: non-interactive login shells load only the approved client and replace a previous one"
