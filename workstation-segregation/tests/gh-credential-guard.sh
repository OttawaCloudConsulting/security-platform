#!/bin/bash
# The client Git credential helper must not fall back to gh's shared Keychain
# slot when the client has no gh login, and must drop inherited token variables.
# Offline: stub gh, fixture HOME, no network, no real Keychain or ~/.gitconfig.
set -Eeuo pipefail
KIT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export KIT_ROOT
fixture="$(mktemp -d "${TMPDIR:-/tmp}/wsk-gh-guard.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
trap 'rm -rf "$fixture"' EXIT
. "$KIT_ROOT/lib/common.sh"
. "$KIT_ROOT/lib/scaffold.sh"
BIN_DIR="$fixture/bin"
mkdir -p "$BIN_DIR" "$fixture/clients" "$fixture/home"
export HOME="$fixture/home" PATH="$BIN_DIR:$PATH"
export XDG_CONFIG_HOME="$fixture/config" XDG_STATE_HOME="$fixture/state" XDG_DATA_HOME="$fixture/data"
printf 'CLIENT_ROOT=%s/clients\nBIN_DIR=%s\n' "$fixture" "$BIN_DIR" > "$fixture/config-file"
load_config "$fixture/config-file"

# Stub gh: log argv and any token variables it sees; answer credential get.
cat > "$BIN_DIR/gh" <<'GH'
#!/bin/bash
{
  printf 'argv:%s\n' "$*"
  printf 'config_dir:%s\n' "${GH_CONFIG_DIR-<unset>}"
  for v in GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN; do
    [ -z "${!v+x}" ] || printf 'env:%s\n' "$v"
  done
} >> "$STUB_LOG"
if [ "${GH_CONFIG_DIR-}" != "${EXPECT_GH_CONFIG_DIR:-<no-expectation>}" ]; then
  printf 'reject:wrong GH_CONFIG_DIR\n' >> "$STUB_LOG"
  cat > /dev/null
  exit 1
fi
if [ "$1 $2 ${3:-}" = 'auth git-credential get' ]; then
  cat > /dev/null
  printf 'username=stub\npassword=stub-token\n'
fi
GH
chmod 755 "$BIN_DIR/gh"

scaffold_client "$fixture/clients/c1" > /dev/null
client="$fixture/clients/c1"
rendered="$client/.workstation/git/config"
gh_dir="$client/.workstation/gh"
mkdir -p "$gh_dir"
rm -f "$gh_dir/hosts.yml"

export STUB_LOG="$fixture/stub.log"
export EXPECT_GH_CONFIG_DIR="$client/.workstation/gh"
printf '[include]\n\tpath = %s\n' "$rendered" > "$fixture/gitconfig"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
redact() { sed 's/^password=.*/password=<redacted>/'; }
reset_log() { : > "$STUB_LOG"; }
stub_calls() { grep -c '^argv:' "$STUB_LOG" || true; }

# git with every ambient config/prompt source neutralised.
# Runs with the fixture as cwd (never the kit's own Git repo) and fixture HOME.
g() {
  local unset_args=() v
  for v in GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_DIR GIT_WORK_TREE \
    $(compgen -e | grep -E '^GIT_CONFIG_(KEY|VALUE)_' || true); do
    unset_args+=(-u "$v")
  done
  (
    cd "$fixture" &&
      env ${unset_args[@]+"${unset_args[@]}"} HOME="$fixture/home" \
        GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$fixture/gitconfig" \
        GIT_TERMINAL_PROMPT=0 GIT_ASKPASS= SSH_ASKPASS= "$@"
  )
}
req() { printf 'protocol=https\nhost=github.com\n\n'; }
fill() { req | g git credential fill 2> "$fixture/fill.err"; }

# 4. Rendered config parses: empty reset first, then the guarded helper.
helpers="$(g git config --file "$rendered" --get-all credential.https://github.com.helper)"
[ "$(printf '%s\n' "$helpers" | wc -l | tr -d ' ')" = 2 ] || fail "expected two helper values"
[ -z "$(printf '%s\n' "$helpers" | sed -n 1p)" ] || fail "first helper value must be empty"
printf '%s\n' "$helpers" | sed -n 2p | grep -q 'hosts.yml' || fail "second helper lacks the hosts.yml guard"
printf '%s\n' "$helpers" | sed -n 2p | grep -qF "$BIN_DIR/gh" || fail "second helper does not embed the stub gh path $BIN_DIR/gh"

# 1. No hosts.yml, then zero-byte hosts.yml: no credential, stub untouched.
for state in missing empty; do
  rm -f "$gh_dir/hosts.yml"
  [ "$state" = empty ] && : > "$gh_dir/hosts.yml"
  reset_log
  out=""
  if out="$(fill)"; then fail "fill succeeded with $state hosts.yml"; fi
  case "$out" in *password=*) fail "password returned with $state hosts.yml: $(printf '%s' "$out" | redact)" ;; esac
  [ "$(stub_calls)" = 0 ] || fail "stub gh called with $state hosts.yml"
done

# 3a. approve/reject without a login: succeed, stub untouched.
reset_log
printf 'protocol=https\nhost=github.com\nusername=stub\npassword=stub-token\n\n' | g git credential approve || fail "approve failed without login"
printf 'protocol=https\nhost=github.com\nusername=stub\npassword=stub-token\n\n' | g git credential reject || fail "reject failed without login"
[ "$(stub_calls)" = 0 ] || fail "stub gh called by approve/reject without login"

# 2. Non-empty hosts.yml: stub reached, credential returned.
printf 'github.com:\n  user: stub\n' > "$gh_dir/hosts.yml"
reset_log
out="$(fill)" || fail "fill failed with login: $(redact < "$fixture/fill.err")"
case "$out" in *password=stub-token*) ;; *) fail "credential not returned: $(printf '%s' "$out" | redact)" ;; esac
grep -qx 'argv:auth git-credential get' "$STUB_LOG" || fail "stub not called with 'auth git-credential get'"

# 3b. approve/reject with a login pass store/erase through.
reset_log
printf 'protocol=https\nhost=github.com\nusername=stub\npassword=stub-token\n\n' | g git credential approve || fail "approve failed with login"
printf 'protocol=https\nhost=github.com\nusername=stub\npassword=stub-token\n\n' | g git credential reject || fail "reject failed with login"
grep -qx 'argv:auth git-credential store' "$STUB_LOG" || fail "store not passed to stub"
grep -qx 'argv:auth git-credential erase' "$STUB_LOG" || fail "erase not passed to stub"

# 5. Inherited token variables never reach gh.
reset_log
out="$(GH_TOKEN=s1 GITHUB_TOKEN=s2 GH_ENTERPRISE_TOKEN=s3 GITHUB_ENTERPRISE_TOKEN=s4 fill)" || fail "fill failed with tokens exported"
case "$out" in *password=stub-token*) ;; *) fail "credential not returned with tokens exported" ;; esac
[ "$(stub_calls)" -ge 1 ] || fail "stub not called in token test"
if grep -q '^env:' "$STUB_LOG"; then fail "stub saw token variables: $(grep '^env:' "$STUB_LOG" | tr '\n' ' ')"; fi

# 6. Rendered .envrc also unsets GH_HOST.
grep -Eq '^unset .*\bGH_HOST\b' "$client/.envrc" || fail ".envrc does not unset GH_HOST"

printf 'PASS: gh credential guard (no login, empty hosts.yml, login, approve/reject, token scrub, GH_HOST)\n'
