#!/bin/bash
# Isolated fixtures only; no credentials, network, or workstation deployment.
set -Eeuo pipefail
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/wsk-codex.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
trap 'rm -rf "$fixture"' EXIT
export KIT_ROOT
. "$KIT_ROOT/lib/common.sh"
. "$KIT_ROOT/lib/scaffold.sh"
BIN_DIR="$fixture/bin"
mkdir -p "$BIN_DIR" "$fixture/clients"
export XDG_CONFIG_HOME="$fixture/config" XDG_STATE_HOME="$fixture/state" XDG_DATA_HOME="$fixture/data"
export DIRENV_LOG_FORMAT=''
export PATH="$BIN_DIR:$PATH"
command -v direnv >/dev/null || die 'tests require direnv'
ENABLE_AGENT_CLI_ISOLATION=1
assert() { "$@" || die "assertion failed: $*"; }
mode_of() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"; }

cat > "$BIN_DIR/codex" <<'STUB'
#!/bin/bash
set -eu
for name in $(compgen -e); do
  case "$name" in OPENAI_*|CODEX_API_KEY|CODEX_ACCESS_TOKEN|CODEX_SQLITE_HOME) exit 90 ;; esac
done
[ "$AWS_PROFILE" = client-cloud ] && [ "$GH_CONFIG_DIR" = "$WORKSTATION_CLIENT_DIR/.workstation/gh" ]
[ "$CODEX_HOME" = "$WORKSTATION_CLIENT_DIR/.workstation/codex" ]
[ "$#" = 3 ] && [ "$1" = 'argument with spaces' ] && [ "$2" = '' ] && [ "$3" = '*' ]
# Explicit API access works from the scrubbed Codex subprocess itself.
direnv exec "$WORKSTATION_CLIENT_DIR" /bin/bash -c '[ "$OPENAI_API_KEY" = fixture-a ] && [ "$OPENAI_PROJECT_ID" = project-a ]'
exit 23
STUB
chmod 755 "$BIN_DIR/codex"
# Avoid initializing the user's installed prompt in the interactive fixture.
printf '#!/bin/bash\nexit 0\n' > "$BIN_DIR/starship"
chmod 755 "$BIN_DIR/starship"
for client in a b empty; do scaffold_client "$fixture/clients/$client" > /dev/null; done
a="$fixture/clients/a"
b="$fixture/clients/b"
empty="$fixture/clients/empty"
assert test "$(mode_of "$a/.workstation/openai")" = 700
assert test "$(mode_of "$a/.workstation/openai/env")" = 600
assert test "$(mode_of "$a/.workstation/codex/config.toml")" = 600
assert grep -qx 'forced_login_method = "chatgpt"' "$a/.workstation/codex/config.toml"
cat > "$a/.workstation/openai/env" <<'ENV'
OPENAI_API_KEY=fixture-a
OPENAI_PROJECT_ID=project-a
OPENAI_ORG_ID=org-a
OPENAI_BASE_URL=https://a.example.invalid/v1
ENV
cat > "$b/.workstation/openai/env" <<'ENV'
OPENAI_API_KEY=fixture-b
OPENAI_PROJECT_ID=project-b
ENV

# A repeat scaffold/adoption must preserve bytes, permissions, and fragments.
snapshot() { find "$1" -type f -exec shasum {} \; | sort; }
snapshot "$a" > "$fixture/before"
scaffold_client "$a" adopt > /dev/null
snapshot "$a" > "$fixture/after"
assert cmp -s "$fixture/before" "$fixture/after"
mkdir -p "$fixture/clients/adopt/.workstation/bash"
printf '# WORKSTATION_CLIENT: preserve existing environment\n' > "$fixture/clients/adopt/.envrc"
printf '# custom shell\n' > "$fixture/clients/adopt/.workstation/bash/custom.sh"
scaffold_client "$fixture/clients/adopt" adopt > /dev/null
assert test ! -e "$fixture/clients/adopt/.workstation/bash/codex.sh"
assert grep -qx '# WORKSTATION_CLIENT: preserve existing environment' "$fixture/clients/adopt/.envrc"
assert test -f "$fixture/clients/adopt/.workstation/codex/config.toml"
assert test -f "$fixture/clients/adopt/.workstation/openai/env"
ENABLE_AGENT_CLI_ISOLATION=0
scaffold_client "$fixture/clients/disabled" > /dev/null
assert test ! -f "$fixture/clients/disabled/.workstation/bash/codex.sh"
assert grep -q '^# export CODEX_HOME=' "$fixture/clients/disabled/.envrc"
assert grep -q '^# unset CODEX_SQLITE_HOME' "$fixture/clients/disabled/.envrc"
ENABLE_AGENT_CLI_ISOLATION=1
DRY_RUN=1
scaffold_client "$fixture/clients/dry" > /dev/null
assert test ! -e "$fixture/clients/dry"
DRY_RUN=0

# Evaluate real direnv exports as a shell would at each prompt.
unset DIRENV_DIFF DIRENV_DIR DIRENV_WATCHES
export OPENAI_API_KEY=outside OPENAI_PROJECT_ID=outside-project OPENAI_ORG_ID=outside-org
export OPENAI_BASE_URL=https://outside.example.invalid OPENAI_FUTURE_OPTION=outside-option
export CODEX_API_KEY=outside-codex CODEX_ACCESS_TOKEN=outside-token
export CODEX_SQLITE_HOME="$fixture/outside-sqlite" CODEX_HOME="$fixture/outside-codex"
export AWS_PROFILE=client-cloud
cd "$a"
eval "$(direnv export bash)"
assert test "$OPENAI_API_KEY" = fixture-a
assert test "$OPENAI_PROJECT_ID" = project-a
assert test "$OPENAI_ORG_ID" = org-a
assert test "$OPENAI_BASE_URL" = https://a.example.invalid/v1
assert test -z "${OPENAI_FUTURE_OPTION+x}${CODEX_API_KEY+x}${CODEX_ACCESS_TOKEN+x}${CODEX_SQLITE_HOME+x}"
. "$a/.workstation/bash/codex.sh"
# Reintroduce overrides after loading: launcher must still scrub them.
export CODEX_API_KEY=late CODEX_ACCESS_TOKEN=late CODEX_SQLITE_HOME=late OPENAI_FUTURE_OPTION=late
status=0
codex 'argument with spaces' '' '*' || status=$?
assert test "$status" = 23
assert test "$OPENAI_API_KEY" = fixture-a
assert test "$CODEX_ACCESS_TOKEN" = late
unset CODEX_API_KEY CODEX_ACCESS_TOKEN CODEX_SQLITE_HOME OPENAI_FUTURE_OPTION
direnv exec "$a" /bin/bash -c '[ "$OPENAI_API_KEY" = fixture-a ] && [ "$OPENAI_PROJECT_ID" = project-a ]'
# Editing the watched API file reloads it without re-approving .envrc.
printf 'OPENAI_API_KEY=fixture-a-updated\nOPENAI_PROJECT_ID=project-a\n' > "$a/.workstation/openai/env"
eval "$(direnv export bash)"
assert test "$OPENAI_API_KEY" = fixture-a-updated
assert test -z "${OPENAI_ORG_ID+x}${OPENAI_BASE_URL+x}"
cd "$b"
eval "$(direnv export bash)"
assert test "$OPENAI_API_KEY" = fixture-b
assert test "$OPENAI_PROJECT_ID" = project-b
assert test -z "${OPENAI_ORG_ID+x}${OPENAI_BASE_URL+x}"
direnv exec "$b" /bin/bash -c '[ "$OPENAI_API_KEY" = fixture-b ] && [ -z "${OPENAI_ORG_ID+x}${OPENAI_BASE_URL+x}${CODEX_API_KEY+x}${CODEX_ACCESS_TOKEN+x}" ]'
cd "$empty"
eval "$(direnv export bash)"
assert test -z "${OPENAI_API_KEY+x}${OPENAI_PROJECT_ID+x}${OPENAI_ORG_ID+x}${OPENAI_BASE_URL+x}"
direnv exec "$empty" /bin/bash -c '[ -z "${OPENAI_API_KEY+x}${OPENAI_PROJECT_ID+x}" ]'
cd "$fixture"
eval "$(direnv export bash)"
assert test "$OPENAI_API_KEY" = outside
assert test "$OPENAI_PROJECT_ID" = outside-project
assert test "$OPENAI_ORG_ID" = outside-org
assert test "$OPENAI_FUTURE_OPTION" = outside-option
assert test "$CODEX_API_KEY" = outside-codex
assert test "$CODEX_ACCESS_TOKEN" = outside-token
assert test "$CODEX_SQLITE_HOME" = "$fixture/outside-sqlite"
assert test "$CODEX_HOME" = "$fixture/outside-codex"

# Invalid/missing active context and a stale client environment fail closed.
if /bin/bash "$KIT_ROOT/bin/codex-client.sh" > /dev/null 2>&1; then die 'outside launch accepted'; fi
cd "$a"
eval "$(direnv export bash)"
saved_home="$CODEX_HOME"
export CODEX_HOME="$fixture/wrong"
if codex > /dev/null 2>&1; then die 'wrong CODEX_HOME accepted'; fi
export CODEX_HOME="$saved_home"
export WORKSTATION_CLIENT=B
if codex > /dev/null 2>&1; then die 'wrong client label accepted'; fi
export WORKSTATION_CLIENT=A
cd "$b"
if codex > /dev/null 2>&1; then die 'stale client accepted'; fi

# The actual interactive fragment hook removes the wrapper on leaving.
export FIXTURE="$fixture"
/bin/bash --noprofile --norc -i <<'SHELL'
set -eu
export WORKSTATION_SEGREGATION_ROOT="$KIT_ROOT"
export WORKSTATION_SEGREGATION_BIN="$FIXTURE/bin"
. "$KIT_ROOT/shell/bashrc.sh"; PROMPT_COMMAND=''
export WORKSTATION_CLIENT_DIR="$FIXTURE/clients/a"
_workstation_client_sync
declare -F codex >/dev/null
export WORKSTATION_CLIENT_DIR="$FIXTURE/clients/b"
_workstation_client_sync
declare -F codex >/dev/null
unset WORKSTATION_CLIENT_DIR
_workstation_client_sync
if declare -F codex >/dev/null; then exit 1; fi
SHELL
printf 'PASS: Codex/API isolation, transitions, launcher, scaffolding and shell lifecycle\n'
