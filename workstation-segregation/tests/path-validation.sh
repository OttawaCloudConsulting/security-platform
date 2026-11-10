#!/bin/bash
# Paths interpolated into Git credential helpers must be shell-safe.
set -Eeuo pipefail
kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/wsk-pathval.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home" "$fixture/clients/good" "$fixture/clients/bad;name" "$fixture/bin"
cat > "$fixture/bin/crontab" <<'STUB'
#!/bin/bash
case "${1:-}" in
  -l) [ -f "$HOME/stub-crontab" ] && cat "$HOME/stub-crontab" || exit 1 ;;
  -) cat > "$HOME/stub-crontab" ;;
  -r) rm -f "$HOME/stub-crontab" ;;
  *) exit 2 ;;
esac
STUB
chmod 755 "$fixture/bin/crontab"
: > "$fixture/gitconfig-fixture"

run_deploy() { # run_deploy <kit dir> <config> [args]
  local k="$1" cfg="$2"; shift 2
  # Isolate from the caller's Git config and run from the fixture, not the kit repo.
  (cd "$fixture" && env -u GIT_CONFIG_COUNT -u GIT_CONFIG_PARAMETERS \
    GIT_CONFIG_GLOBAL="$fixture/gitconfig-fixture" GIT_CONFIG_NOSYSTEM=1 \
    HOME="$fixture/home" SHELL=/bin/bash PATH="$fixture/bin:$PATH" \
    XDG_CONFIG_HOME="$fixture/home/config" XDG_STATE_HOME="$fixture/home/state" \
    XDG_DATA_HOME="$fixture/home/data" \
    /bin/bash "$k/deploy.sh" --config "$cfg" --skip-tools "$@")
}
snapshot() {
  { find "$fixture/home" "$fixture/clients" "$fixture/kitcopy" -print 2>/dev/null || true; } | sort
  { find "$fixture/home" "$fixture/clients" "$fixture/kitcopy" -type f -exec shasum {} \; 2>/dev/null || true; } | sort
}
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# expect_rejected <label> <kit dir> <config> <variable name>
expect_rejected() {
  local label="$1" k="$2" cfg="$3" var="$4" rc=0 before after
  before="$(snapshot)"
  run_deploy "$k" "$cfg" > "$fixture/out.log" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] || fail "$label: deploy succeeded"
  grep -q "$var contains unsupported characters\|$var (kit location) contains unsupported" "$fixture/out.log" \
    || { cat "$fixture/out.log" >&2; fail "$label: missing message naming $var"; }
  after="$(snapshot)"
  [ "$before" = "$after" ] || fail "$label: files were written"
}

# shellcheck disable=SC1003
bad_chars=('$' ';' '`' '&' "'" '"' '*' ' ' '|' '(' '<' '\' '!' '#')
for c in "${bad_chars[@]}"; do
  printf 'CLIENT_ROOT=%q\nBIN_DIR=%q\n' "$fixture/clients/x${c}y" "$fixture/bin" > "$fixture/cfg-root"
  expect_rejected "CLIENT_ROOT with '$c'" "$kit" "$fixture/cfg-root" CLIENT_ROOT
  printf 'CLIENT_ROOT=%q\nBIN_DIR=%q\n' "$fixture/clients" "$fixture/bin/x${c}y" > "$fixture/cfg-bin"
  expect_rejected "BIN_DIR with '$c'" "$kit" "$fixture/cfg-bin" BIN_DIR
done

# KIT_ROOT with a metacharacter: run a copy of the kit from such a directory.
# shellcheck disable=SC2016
for name in 'kit$x' 'kit;x'; do
  rm -rf "$fixture/kitcopy"
  mkdir -p "$fixture/kitcopy/$name"
  (cd "$kit" && tar --exclude=.git -cf - .) | (cd "$fixture/kitcopy/$name" && tar -xf -)
  printf 'CLIENT_ROOT=%s/clients\nBIN_DIR=%s/bin\n' "$fixture" "$fixture" > "$fixture/cfg-ok"
  expect_rejected "KIT_ROOT '$name'" "$fixture/kitcopy/$name" "$fixture/cfg-ok" KIT_ROOT
done
rm -rf "$fixture/kitcopy"

# Safe config deploys; an unsafe client directory name is skipped with a warning.
mkdir -p "$fixture/clients/line1
\$(x)"
printf 'CLIENT_ROOT=%s/clients\nBIN_DIR=%s/bin\nADOPT_DIRS="good"\n' "$fixture" "$fixture" > "$fixture/cfg-ok"
run_deploy "$kit" "$fixture/cfg-ok" > "$fixture/ok.log" 2>&1 || { cat "$fixture/ok.log" >&2; fail "safe deploy failed"; }
[ -d "$fixture/clients/good/.workstation" ] || fail "good client not scaffolded"

# Unsafe dirs that are explicitly adopted must be skipped with a warning, not abort.
mkdir -p "$fixture/clients/bad;name/.workstation/git" "$fixture/clients/sp ace/.workstation"
printf '[user]\n\tname = seeded\n' > "$fixture/clients/bad;name/.workstation/git/config"
nl_dir="$fixture/clients/nlonly"$'\n'
mkdir -p "$nl_dir/.workstation"
printf 'ADOPT_DIRS="good bad;name nlonly"\n' >> "$fixture/cfg-ok"
run_deploy "$kit" "$fixture/cfg-ok" > "$fixture/ok2.log" 2>&1 || { cat "$fixture/ok2.log" >&2; fail "deploy with bad client dir failed"; }
grep -q "skipping '.*bad;name'" "$fixture/ok2.log" || fail "no skip warning for bad;name"
[ ! -e "$fixture/clients/bad;name/.envrc" ] || fail "bad;name was scaffolded"
[ "$(cat "$fixture/clients/bad;name/.workstation/git/config")" = "$(printf '[user]\n\tname = seeded')" ] || fail "bad;name git config was rewritten"
[ ! -e "$fixture/clients/bad;name/.workstation/bash" ] || fail "bad;name was scaffolded"
grep -q "skipping '$fixture/clients/nlonly" "$fixture/ok2.log" || fail "no skip warning for trailing-newline dir"
[ ! -e "$fixture/clients/nlonly" ] || fail "trailing-newline dir created a nlonly client"
[ ! -e "$nl_dir/.envrc" ] && [ ! -e "$nl_dir/.workstation/git" ] || fail "trailing-newline dir was scaffolded"
grep -q 'bad;name' "$fixture/home/config/workstation-segregation/gitconfig-clients" && fail "bad;name leaked into gitconfig-clients"
grep -q "not including '.*bad;name' in the generated Git includes" "$fixture/ok2.log" || fail "no warning that bad;name was left out of the Git includes"
grep -q "$fixture/clients/good" "$fixture/home/config/workstation-segregation/gitconfig-clients" || fail "good missing from gitconfig-clients"
run_deploy "$kit" "$fixture/cfg-ok" --dry-run > /dev/null 2>&1 || fail "dry-run failed"

# Uninstall must still work when the config's paths fail the new allowlist.
[ -f "$fixture/home/stub-crontab" ] || fail "no crontab entry after deploy (test setup)"
printf 'CLIENT_ROOT=%s/clients+old\nBIN_DIR=%s/bin\n' "$fixture" "$fixture" > "$fixture/cfg-plus"
rc=0; run_deploy "$kit" "$fixture/cfg-plus" > "$fixture/plus.log" 2>&1 || rc=$?
[ "$rc" -ne 0 ] || fail "normal deploy with unsafe CLIENT_ROOT succeeded"
grep -q 'CLIENT_ROOT contains unsupported characters' "$fixture/plus.log" || fail "normal deploy: missing CLIENT_ROOT message"
grep -q 'workstation-segregation' "$fixture/home/stub-crontab" || fail "crontab entry missing before uninstall (test setup)"
grep -q '>>> workstation-segregation:' "$fixture/home/.gitconfig" "$fixture/home/.bashrc" || fail "managed blocks missing before uninstall (test setup)"
run_deploy "$kit" "$fixture/cfg-plus" --uninstall > "$fixture/un.log" 2>&1 || { cat "$fixture/un.log" >&2; fail "uninstall with unsafe CLIENT_ROOT failed"; }
grep -q 'CLIENT_ROOT contains unsupported characters' "$fixture/un.log" || fail "uninstall: missing warning"
if [ -f "$fixture/home/stub-crontab" ] && grep -q 'workstation-segregation' "$fixture/home/stub-crontab"; then fail "crontab entry not removed"; fi
if grep -qs '>>> workstation-segregation:' "$fixture/home/.gitconfig" "$fixture/home/.bashrc" "$fixture/home/.bash_profile"; then fail "managed blocks not removed"; fi

printf 'PASS: shell-unsafe CLIENT_ROOT/BIN_DIR/KIT_ROOT rejected without writes; unsafe client names skipped; safe config deploys\n'
