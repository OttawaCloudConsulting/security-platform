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

# --- Linux without ~/.bash_profile: deploy must put the bootstrap into ~/.profile ---------
# A uname stub makes deploy.sh behave as on Linux. Bash then reads ~/.profile for login
# shells; installing it only into ~/.bash_profile would leave this layout without the refresh.
lhome="$fixture/linux-home"
mkdir -p "$lhome/.config" "$lhome/.local/share" "$fixture/linux-bin" "$fixture/linux-clients/lc"
# shellcheck disable=SC2016  # expanded by the shell under test
printf '# distro default profile\n[ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' > "$lhome/.profile"
printf 'export WSK_TEST_CLIENT=lc\n' > "$fixture/linux-clients/lc/.envrc"
cat > "$fixture/linux-bin/uname" <<'STUB'
#!/bin/bash
[ "${1:-}" = -s ] && { echo Linux; exit 0; }
exec /usr/bin/uname "$@"
STUB
cat > "$fixture/linux-bin/crontab" <<'STUB'
#!/bin/bash
case "${1:-}" in
  -l) [ -f "$HOME/stub-crontab" ] && cat "$HOME/stub-crontab" || exit 1 ;;
  -) cat > "$HOME/stub-crontab" ;;
  -r) rm -f "$HOME/stub-crontab" ;;
  *) exit 2 ;;
esac
STUB
chmod 755 "$fixture/linux-bin/uname" "$fixture/linux-bin/crontab"
printf 'CLIENT_ROOT=%s/linux-clients\nBIN_DIR=%s/linux-bin\n' "$fixture" "$fixture" > "$fixture/linux.conf"
ldr() { env -i HOME="$lhome" TMPDIR="$fixture" PATH="$fixture/linux-bin:$direnv_dir:/usr/bin:/bin" SHELL=/bin/bash \
  XDG_CONFIG_HOME="$lhome/.config" XDG_STATE_HOME="$lhome/.local/state" XDG_DATA_HOME="$lhome/.local/share" "$@"; }
ldr /bin/bash "$kit/deploy.sh" --config "$fixture/linux.conf" --skip-tools >"$fixture/linux-deploy.log" 2>&1 \
  || fail "linux-style deploy failed: $(tail -5 "$fixture/linux-deploy.log")"
[ ! -e "$lhome/.bash_profile" ] || fail "deploy created ~/.bash_profile on Linux, shadowing ~/.profile"
grep -q 'workstation-segregation:shell' "$lhome/.profile" || fail "bootstrap not installed in ~/.profile"
ldr direnv allow "$fixture/linux-clients/lc" >/dev/null 2>&1
out="$( cd "$fixture/linux-clients/lc" && ldr /bin/bash -l -c "$show_client" 2>/dev/null )"
[ "$out" = lc ] || fail "Linux ~/.profile layout: login shell got '${out}', expected lc"
out="$( cd "$fixture/outside" && ldr /bin/bash -l -c "$show_client" 2>/dev/null )"
[ -z "$out" ] || fail "Linux ~/.profile layout: environment set outside any client: '$out'"
# A non-bash POSIX shell reading the same ~/.profile must not run the bash bootstrap. Only
# checkable where sh is not bash itself (macOS /bin/sh is bash in POSIX mode).
if [ -z "$(/bin/sh -c 'printf %s "${BASH_VERSION:-}"')" ]; then
  out="$( cd "$fixture/linux-clients/lc" && ldr /bin/sh -c ". \"$lhome/.profile\"; $show_client" 2>/dev/null || true )"
  [ -z "$out" ] || fail "non-bash shell ran the bootstrap from ~/.profile: '$out'"
fi
ldr /bin/bash "$kit/deploy.sh" --config "$fixture/linux.conf" --skip-tools --uninstall >/dev/null 2>&1 \
  || fail "linux-style uninstall failed"
! grep -q 'workstation-segregation:shell' "$lhome/.profile" || fail "uninstall left the ~/.profile block"

echo "PASS: non-interactive login shells load only the approved client and replace a previous one"
