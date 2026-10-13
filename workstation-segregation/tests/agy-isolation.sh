#!/bin/bash
# All launches and deployments are disposable offline fixtures.
set -Eeuo pipefail
KIT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export KIT_ROOT
fixture=$(mktemp -d /private/tmp/wsk-agy-client.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
. "$KIT_ROOT/lib/common.sh"
. "$KIT_ROOT/lib/scaffold.sh"
BIN_DIR="$fixture/bin"
mkdir -p "$BIN_DIR" "$fixture/clients"
export PATH="$BIN_DIR:$PATH" XDG_CONFIG_HOME="$fixture/config" XDG_STATE_HOME="$fixture/state" XDG_DATA_HOME="$fixture/data"
# Defaults stay disabled even when the live config has no AGY flag.
printf 'CLIENT_ROOT=%s/clients\nBIN_DIR=%s/bin\n' "$fixture" "$fixture" > "$fixture/config-file"
load_config "$fixture/config-file"
[ "$ENABLE_AGY_CLI_ISOLATION" = 0 ]
scaffold_client "$fixture/clients/default" > /dev/null
[ ! -e "$fixture/clients/default/.workstation/bash/agy.sh" ]
ENABLE_AGY_CLI_ISOLATION=1 ENABLE_AGENT_CLI_ISOLATION=0
scaffold_client "$fixture/clients/agent-disabled" > /dev/null
[ ! -e "$fixture/clients/agent-disabled/.workstation/bash/agy.sh" ]
ENABLE_AGENT_CLI_ISOLATION=1
for client in a b; do
  scaffold_client "$fixture/clients/$client" > /dev/null
  git config --file "$fixture/clients/$client/.workstation/git/config" user.name "Fixture $client"
  git config --file "$fixture/clients/$client/.workstation/git/config" user.email "$client@example.invalid"
done
cat > "$BIN_DIR/agy" <<'STUB'
#!/bin/bash
set -eu
[ "$HOME" = "$WORKSTATION_CLIENT_DIR/.workstation/agy/home" ]
[ "$TMPDIR" = "$WORKSTATION_CLIENT_DIR/.workstation/agy/tmp" ]
[ "$GH_CONFIG_DIR" = "$WORKSTATION_CLIENT_DIR/.workstation/gh" ]
[ "$AWS_CONFIG_FILE" = "$WORKSTATION_CLIENT_DIR/.aws/config" ]
[ "$AWS_SHARED_CREDENTIALS_FILE" = "$WORKSTATION_CLIENT_DIR/.aws/credentials" ]
[ "$KUBECONFIG" = "$WORKSTATION_CLIENT_DIR/.kube/config" ]
[ "$AWS_PROFILE" = fixture-cloud ]
for name in $(compgen -e); do
  case "$name" in GOOGLE_*|GEMINI_*|GCLOUD_*|CLOUDSDK_*|AGY_*|ANTIGRAVITY_*|VERTEX_*|XDG_*|BASH_ENV|ENV|GIT_CONFIG_COUNT|GIT_CONFIG_KEY_*|GIT_CONFIG_VALUE_*|GIT_CONFIG_PARAMETERS|GIT_CONFIG_SYSTEM|GIT_CONFIG) exit 90 ;; esac
done
client=$(basename "$WORKSTATION_CLIENT_DIR")
[ "$(git config user.email)" = "$client@example.invalid" ]
[ "$(git config user.useConfigOnly)" = true ]
[ "$(git config pull.ff)" = only ]
[ "$(git config core.sshCommand)" = "ssh -F $WORKSTATION_CLIENT_DIR/.workstation/ssh/config" ]
helper=$(git config --get-all credential.https://github.com.helper)
case "$helper" in *"GH_CONFIG_DIR=$WORKSTATION_CLIENT_DIR/.workstation/gh $FIXTURE/bin/gh auth git-credential"*) ;; *) exit 91 ;; esac
credentials=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill)
case "$credentials" in *"username=$WORKSTATION_CLIENT"*) ;; *) exit 92 ;; esac
[ "$(git config --global --get-all include.path)" = "$WORKSTATION_CLIENT_DIR/.workstation/git/config" ]
[ "$#" = 3 ] && [ "$1" = 'argument with spaces' ] && [ "$2" = '' ] && [ "$3" = '*' ]
exit 23
STUB
# _resolve_gh uses the available real binary when present; replace each fixture helper.
for client in a b; do
  git config --file "$fixture/clients/$client/.workstation/git/config" --replace-all credential.https://github.com.helper "!GH_CONFIG_DIR=$fixture/clients/$client/.workstation/gh $fixture/bin/gh auth git-credential" '^!'
done
cat > "$BIN_DIR/gh" <<'GH'
#!/bin/bash
set -eu
[ "$GH_CONFIG_DIR" = "$WORKSTATION_CLIENT_DIR/.workstation/gh" ]
[ "$1 $2" = 'auth git-credential' ]
printf 'username=%s\npassword=offline-fixture\n' "$WORKSTATION_CLIENT"
GH
printf '#!/bin/bash\nexit 0\n' > "$BIN_DIR/starship"
chmod 755 "$BIN_DIR/agy" "$BIN_DIR/starship" "$BIN_DIR/gh"
export FIXTURE="$fixture" AWS_PROFILE=fixture-cloud
export GOOGLE_API_KEY=outside GEMINI_CLI_HOME=outside ANTIGRAVITY_APP_DATA_DIR=outside
export GIT_CONFIG_GLOBAL=outside GIT_CONFIG_SYSTEM=outside GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=user.email GIT_CONFIG_VALUE_0=outside GIT_CONFIG_PARAMETERS="'user.email=outside'"
# Expansion happens in the deliberately unsourced hook.
# shellcheck disable=SC2016
printf 'touch "$FIXTURE/startup-hook-ran"\n' > "$fixture/startup-hook"
export BASH_ENV="$fixture/startup-hook" ENV="$fixture/startup-hook"
original_home=$HOME
for client in a b a; do
  export WORKSTATION_CLIENT_DIR="$fixture/clients/$client"
  WORKSTATION_CLIENT=$(printf '%s' "$client" | tr '[:lower:]' '[:upper:]')
  export WORKSTATION_CLIENT
  export GH_CONFIG_DIR="$WORKSTATION_CLIENT_DIR/.workstation/gh"
  export AWS_CONFIG_FILE="$WORKSTATION_CLIENT_DIR/.aws/config" AWS_SHARED_CREDENTIALS_FILE="$WORKSTATION_CLIENT_DIR/.aws/credentials" KUBECONFIG="$WORKSTATION_CLIENT_DIR/.kube/config"
  cd "$WORKSTATION_CLIENT_DIR"
  . .workstation/bash/agy.sh
  status=0
  agy 'argument with spaces' '' '*' || status=$?
  [ "$status" = 23 ]
  [ "$HOME" = "$original_home" ] && [ "$GOOGLE_API_KEY" = outside ] && [ "$GIT_CONFIG_GLOBAL" = outside ]
done
[ ! -e "$fixture/startup-hook-ran" ]
unset BASH_ENV ENV
export WORKSTATION_CLIENT=B
if agy > /dev/null 2>&1; then exit 1; fi
export WORKSTATION_CLIENT=A
cd "$fixture"
if agy > /dev/null 2>&1; then exit 1; fi
cd "$WORKSTATION_CLIENT_DIR"
mv .workstation/agy/gitconfig .workstation/agy/saved
if agy > /dev/null 2>&1; then exit 1; fi
mv .workstation/agy/saved .workstation/agy/gitconfig
mv .workstation/agy/home .workstation/agy/saved-home
ln -s saved-home .workstation/agy/home
if agy > /dev/null 2>&1; then exit 1; fi
rm .workstation/agy/home
mv .workstation/agy/saved-home .workstation/agy/home
unset GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_PARAMETERS
snapshot() { find "$1" -type f -exec shasum {} \; | sort; }
snapshot "$WORKSTATION_CLIENT_DIR" > "$fixture/before"
scaffold_client "$WORKSTATION_CLIENT_DIR" adopt > /dev/null
snapshot "$WORKSTATION_CLIENT_DIR" > "$fixture/after"
cmp -s "$fixture/before" "$fixture/after"
mkdir -p "$fixture/clients/adopt/.workstation/bash"
printf '# WORKSTATION_CLIENT keep existing\n' > "$fixture/clients/adopt/.envrc"
printf '# custom shell\n' > "$fixture/clients/adopt/.workstation/bash/custom.sh"
scaffold_client "$fixture/clients/adopt" adopt > /dev/null
[ ! -e "$fixture/clients/adopt/.workstation/bash/agy.sh" ]
grep -qx '# WORKSTATION_CLIENT keep existing' "$fixture/clients/adopt/.envrc"
DRY_RUN=1
scaffold_client "$fixture/clients/dry" > /dev/null
[ ! -e "$fixture/clients/dry" ]
DRY_RUN=0
/bin/bash --noprofile --norc -i <<'SHELL'
set -eu
export WORKSTATION_SEGREGATION_ROOT="$KIT_ROOT" WORKSTATION_SEGREGATION_BIN="$FIXTURE/bin"
. "$KIT_ROOT/shell/bashrc.sh"; PROMPT_COMMAND=''
for client in a b; do
  export WORKSTATION_CLIENT_DIR="$FIXTURE/clients/$client"
  _workstation_client_sync
  declare -F agy >/dev/null
done
unset WORKSTATION_CLIENT_DIR
_workstation_client_sync
if declare -F agy >/dev/null; then exit 1; fi
SHELL
python3 - "$fixture/clients/a/.workstation/agy" <<'PY'
import pathlib, stat, sys
p=pathlib.Path(sys.argv[1])
for d in [p, p/'home', p/'tmp']:
    assert stat.S_IMODE(d.stat().st_mode) == 0o700
assert stat.S_IMODE((p/'gitconfig').stat().st_mode) == 0o600
PY
printf 'PASS: AGY wrapper, Git routing, context validation, flags, adoption and lifecycle\n'
