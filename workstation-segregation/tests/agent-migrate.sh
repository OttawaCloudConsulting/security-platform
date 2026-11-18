#!/bin/bash
# bin/claude-migrate.sh and bin/codex-migrate.sh against disposable clients: gating,
# dry run, unset-then-apply of .envrc/settings/config/fragment, the resulting
# environment, idempotence, direnv approval, symlink refusal and removal.
# Never runs Claude, Codex or a real `direnv allow`.
set -Eeuo pipefail
kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/wsk-agent-migrate.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
trap 'rm -rf "$fixture"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
root="$fixture/clients"
mkdir -p "$fixture/home" "$fixture/bin" "$root"
command -v jq > /dev/null || fail 'jq is required for this suite'
# Stub direnv: records approvals instead of trusting anything.
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "%s/direnv.log"\n' "$fixture" > "$fixture/bin/direnv"
chmod 755 "$fixture/bin/direnv"

client() { # client <name> <envrc body>: an existing (adopted) client
  mkdir -p "$root/$1/.workstation/git" "$root/$1/.workstation/bash"
  printf 'export WORKSTATION_CLIENT=%s\n%s\n' "$1" "$2" > "$root/$1/.envrc"
}
conf() { printf 'CLIENT_ROOT=%s\nBIN_DIR=%s\nENABLE_AGENT_CLI_ISOLATION=%s\n' "$root" "$fixture/bin" "$1" > "$fixture/config"; }
mig() { # mig <claude|codex> args...
  local which="$1"; shift
  env HOME="$fixture/home" XDG_STATE_HOME="$fixture/home/state" XDG_CONFIG_HOME="$fixture/home/config" \
    /bin/bash "$kit/bin/$which-migrate.sh" --config "$fixture/config" "$@"
}
snapshot() { find "$root" \( -type f -o -type l -o -type d \) -print | sort | while read -r p; do
  if [ -f "$p" ] && [ ! -L "$p" ]; then printf '%s %s\n' "$p" "$(shasum < "$p")"; else printf '%s\n' "$p"; fi; done; }
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
baks() { find "$root" -name '*.bak.*' | wc -l | tr -d ' '; }
# Evaluate a client .envrc with direnv's stdlib stubbed; print selected variables.
envof() { # envof <client> <var>...
  ( cd "$root/$1"; shift
    # direnv stdlib stubs, called by the sourced .envrc
    # shellcheck disable=SC2329,SC1090
    expand_path() { printf '%s/%s\n' "$PWD" "$1"; }
    # shellcheck disable=SC2329
    watch_file() { :; }
    # shellcheck disable=SC2329
    PATH_add() { :; }
    # shellcheck disable=SC2329,SC1090
    dotenv() { set -a; . "$1"; set +a; }
    unset CLAUDE_CONFIG_DIR CODEX_HOME   # the caller may itself run inside a client
    export CODEX_SQLITE_HOME=inherited OPENAI_API_KEY=inherited OPENAI_BASE_URL=inherited CODEX_API_KEY=inherited
    # shellcheck disable=SC1091
    . ./.envrc
    for v in "$@"; do printf '%s=%s\n' "$v" "${!v-<unset>}"; done )
}
# shellcheck disable=SC2016  # literal .envrc content
tpl_claude='export CLAUDE_CONFIG_DIR="$(expand_path .workstation/claude)"'
# shellcheck disable=SC2016
tpl_codex='export CODEX_HOME="$(expand_path .workstation/codex)"'

# ---- fixtures -------------------------------------------------------------------
client disabled "# keep me
# $tpl_claude
# $tpl_codex
# unset CODEX_SQLITE_HOME"
client elsewhere "export CLAUDE_CONFIG_DIR=/elsewhere/claude
export CODEX_HOME=/elsewhere/codex
$(sed -n '/^for _openai_var/,/^fi$/p' "$kit/templates/client/envrc")"
client current "$tpl_claude
$tpl_codex
unset CODEX_SQLITE_HOME
$(sed -n '/^for _openai_var/,/^fi$/p' "$kit/templates/client/envrc")"
client fresh ""        # no .workstation/claude yet: settings come from the template
client linked ""
mkdir -p "$fixture/outside/codex" "$fixture/outside/claude"
ln -s "$fixture/outside/codex" "$root/linked/.workstation/codex"
ln -s "$fixture/outside/claude" "$root/linked/.workstation/claude"
mkdir -p "$root/plain"
# Stale Claude settings: old kit hook next to an unrelated hook and setting.
mkdir -p "$root/elsewhere/.workstation/claude" "$root/elsewhere/.workstation/codex" "$root/current/.workstation/claude"
cat > "$root/elsewhere/.workstation/claude/settings.json" <<'JSON'
{"model":"opus","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"/bin/bash /old/kit/hooks/direnv-session-env.sh"},{"type":"command","command":"echo mine"}]}]}}
JSON
jq -n --arg c "/bin/bash $kit/hooks/direnv-session-env.sh" '{hooks:{SessionStart:[{hooks:[{type:"command",command:$c}]}]}}' \
  > "$root/current/.workstation/claude/settings.json"
printf 'secret-login\n' > "$root/elsewhere/.workstation/claude/.credentials.json"
cat > "$root/elsewhere/.workstation/codex/config.toml" <<'TOML'
model = "custom"
cli_auth_credentials_store = "keyring"
cli_auth_credentials_store = "keyring"

[profiles.x]
forced_login_method = "api"
TOML
printf 'codex() { /old/kit/bin/codex-client.sh "$@"; }\n' > "$root/elsewhere/.workstation/bash/codex.sh"
printf 'auth\n' > "$root/elsewhere/.workstation/codex/auth.json"

# has_backup_of <file> <copy>: some <file>.bak.* is byte-identical to <copy>.
has_backup_of() { local b; for b in "$1".bak.*; do [ -f "$b" ] && cmp -s "$b" "$2" && return 0; done; return 1; }
cp "$root/disabled/.envrc" "$fixture/disabled.envrc.orig"

# ---- gating and argument checks ------------------------------------------------
conf 0
for m in claude codex; do
  if mig "$m" disabled > "$fixture/out" 2>&1; then fail "$m applied with isolation off"; fi
  grep -q 'ENABLE_AGENT_CLI_ISOLATION=1' "$fixture/out" || fail "$m gate message"
done
conf 1
if mig claude > /dev/null 2>&1; then fail 'ran without clients'; fi
if mig codex plain > /dev/null 2>&1; then fail 'accepted an unsegregated dir'; fi

# ---- dry run --------------------------------------------------------------------
snapshot > "$fixture/before"
mig claude --dry-run --all > "$fixture/dry" 2>&1 || true
mig codex --dry-run disabled elsewhere current >> "$fixture/dry" 2>&1
snapshot > "$fixture/after"
cmp -s "$fixture/before" "$fixture/after" || fail 'dry run changed files'
grep -q "^    +$tpl_claude" "$fixture/dry" || fail 'dry run shows no .envrc diff'
[ ! -e "$fixture/direnv.log" ] || fail 'dry run approved an .envrc'

# ---- claude apply ---------------------------------------------------------------
# --all keeps going past a refused client and fails at the end.
if mig claude --all > "$fixture/claude-all" 2>&1; then fail 'symlinked client accepted'; fi
grep -q 'not migrated: linked' "$fixture/claude-all" || fail 'linked client not reported'
grep -q "disabled: .envrc changed" "$fixture/claude-all" || fail 'no direnv allow reminder'
mig claude disabled elsewhere current fresh > "$fixture/claude" 2>&1 || fail 'claude apply failed'
has_backup_of "$root/disabled/.envrc" "$fixture/disabled.envrc.orig" || fail 'original .envrc not in a backup'
cp "$root/disabled/.envrc" "$fixture/disabled.envrc.claude"
[ -f "$root/fresh/.workstation/claude/settings.json" ] || fail 'settings not scaffolded'
if ls "$root/fresh/.workstation/claude/settings.json.bak."* > /dev/null 2>&1; then fail 'template settings rewritten'; fi
if ls "$root/current/.workstation/claude/settings.json.bak."* > /dev/null 2>&1; then fail 'current settings rewritten'; fi
for c in disabled elsewhere current; do
  [ "$(envof "$c" CLAUDE_CONFIG_DIR)" = "CLAUDE_CONFIG_DIR=$root/$c/.workstation/claude" ] || fail "$c: CLAUDE_CONFIG_DIR"
  [ "$(grep -c 'CLAUDE_CONFIG_DIR=' "$root/$c/.envrc")" = 1 ] || fail "$c: CLAUDE_CONFIG_DIR not unique"
  [ "$(mode_of "$root/$c/.workstation/claude")" = 700 ] || fail "$c: claude dir mode"
  hooks="$(jq -c '[.hooks.SessionStart[].hooks[].command]' "$root/$c/.workstation/claude/settings.json")"
  [ "$(printf '%s' "$hooks" | grep -o 'direnv-session-env.sh' | wc -l | tr -d ' ')" = 1 ] || fail "$c: kit hook count $hooks"
  printf '%s' "$hooks" | grep -qF "$kit/hooks/direnv-session-env.sh" || fail "$c: current hook missing"
done
grep -qx '# keep me' "$root/disabled/.envrc" || fail 'unrelated .envrc line lost'
jq -e '.model == "opus"' "$root/elsewhere/.workstation/claude/settings.json" > /dev/null || fail 'claude setting lost'
jq -e '[.hooks.SessionStart[].hooks[].command] | index("echo mine")' "$root/elsewhere/.workstation/claude/settings.json" > /dev/null || fail 'unrelated hook lost'
[ "$(cat "$root/elsewhere/.workstation/claude/.credentials.json")" = secret-login ] || fail 'claude login touched'
ls "$root/current/.envrc.bak."* > /dev/null 2>&1 && fail 'current .envrc was rewritten'
[ ! -e "$fixture/direnv.log" ] || fail 'approved without --allow'

# ---- codex apply ----------------------------------------------------------------
mig codex --allow disabled elsewhere current > "$fixture/codex" 2>&1 || fail 'codex apply failed'
# Two .envrc writes (codex, then openai block) in one second must not clobber the first backup.
has_backup_of "$root/disabled/.envrc" "$fixture/disabled.envrc.claude" || fail 'pre-codex .envrc not in a backup'
has_backup_of "$root/disabled/.envrc" "$fixture/disabled.envrc.orig" || fail 'original .envrc backup lost'
for c in disabled elsewhere current; do
  out="$(envof "$c" CODEX_HOME CODEX_SQLITE_HOME OPENAI_API_KEY OPENAI_BASE_URL CODEX_API_KEY)"
  [ "$out" = "CODEX_HOME=$root/$c/.workstation/codex
CODEX_SQLITE_HOME=<unset>
OPENAI_API_KEY=<unset>
OPENAI_BASE_URL=<unset>
CODEX_API_KEY=<unset>" ] || fail "$c: codex environment: $out"
  [ "$(grep -cE '^[[:space:]]*dotenv .workstation/openai/env' "$root/$c/.envrc")" = 1 ] || fail "$c: GPT API loader count"
  [ "$(mode_of "$root/$c/.workstation/codex/config.toml")" = 600 ] || fail "$c: config mode"
  grep -qx 'cli_auth_credentials_store = "file"' "$root/$c/.workstation/codex/config.toml" || fail "$c: credentials store"
  grep -qx 'forced_login_method = "chatgpt"' "$root/$c/.workstation/codex/config.toml" || fail "$c: login method"
  grep -qF "\"$kit/bin/codex-client.sh\"" "$root/$c/.workstation/bash/codex.sh" || fail "$c: wrapper"
  [ -f "$root/$c/.workstation/openai/env" ] || fail "$c: openai env missing"
done
cfg="$root/elsewhere/.workstation/codex/config.toml"
[ "$(grep -c '^cli_auth_credentials_store' "$cfg")" = 1 ] || fail 'duplicate credentials store kept'
grep -qx 'model = "custom"' "$cfg" || fail 'codex setting lost'
grep -qx 'forced_login_method = "api"' "$cfg" || fail 'table key rewritten'
[ "$(sed -n '/^\[profiles.x\]/,$p' "$cfg" | grep -c forced_login_method)" = 1 ] || fail 'top-level key added inside a table'
[ "$(head -1 "$cfg")" = 'forced_login_method = "chatgpt"' ] || fail 'missing top-level key not added first'
ls "$root/elsewhere/.workstation/bash/codex.sh.bak."* > /dev/null 2>&1 || fail 'stale wrapper not backed up'
[ "$(cat "$root/elsewhere/.workstation/codex/auth.json")" = auth ] || fail 'codex login touched'
grep -qx "allow $root/disabled" "$fixture/direnv.log" || fail '--allow did not approve a changed .envrc'
if grep -qx "allow $root/current" "$fixture/direnv.log"; then fail 'approved an unchanged .envrc'; fi
[ -z "$(find "$fixture/outside" -mindepth 2)" ] || fail 'wrote through a symlink'

# ---- repeat runs change nothing --------------------------------------------------
snapshot > "$fixture/before"; n="$(baks)"
mig claude disabled elsewhere current > /dev/null 2>&1 || fail 'claude repeat failed'
mig codex disabled elsewhere current > /dev/null 2>&1 || fail 'codex repeat failed'
snapshot > "$fixture/after"
cmp -s "$fixture/before" "$fixture/after" || fail 'repeat run changed files'
[ "$(baks)" = "$n" ] || fail 'repeat run made backups'

# ---- removal (rollback), allowed with isolation off --------------------------------
conf 0
mig claude --remove elsewhere > /dev/null 2>&1 || fail 'claude remove failed'
mig codex --remove elsewhere > /dev/null 2>&1 || fail 'codex remove failed'
[ "$(envof elsewhere CLAUDE_CONFIG_DIR CODEX_HOME)" = 'CLAUDE_CONFIG_DIR=<unset>
CODEX_HOME=<unset>' ] || fail 'removal left exports'
[ ! -e "$root/elsewhere/.workstation/bash/codex.sh" ] || fail 'wrapper not removed'
grep -qE '^[[:space:]]*dotenv .workstation/openai/env' "$root/elsewhere/.envrc" || fail 'removal dropped the GPT API block'
[ "$(cat "$root/elsewhere/.workstation/codex/auth.json")" = auth ] || fail 'removal touched codex login'
[ "$(cat "$root/elsewhere/.workstation/claude/.credentials.json")" = secret-login ] || fail 'removal touched claude login'

printf 'PASS: Claude/Codex migration gate, dry run, unset-then-apply, environment, idempotence, approval, symlinks and removal\n'
