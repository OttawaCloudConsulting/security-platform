#!/bin/bash
# Offline verifier. Never invokes the installed AGY, a browser, or a keyring.
set -euo pipefail
umask 077
kit=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/wsk-agy-stub.XXXXXX")
fixture=$(cd -P "$fixture" && pwd)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/parent-home" "$fixture/runs"
mode_of() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"; }
export STUB_FIXTURE="$fixture"
export HOME="$fixture/parent-home" TMPDIR="$fixture/runs"
export GEMINI_API_KEY=secret GOOGLE_API_KEY=secret GOOGLE_APPLICATION_CREDENTIALS=secret
export GEMINI_CLI_HOME=parent-gemini ANTIGRAVITY_APP_DATA_DIR=parent-agy
export GOOGLE_GENAI_USE_VERTEXAI=true GOOGLE_GENAI_USE_GCA=true
export GCLOUD_ACCESS_TOKEN=secret CLOUDSDK_CONFIG=secret AGY_AUTH_TOKEN=secret
export ANTIGRAVITY_AUTH_TOKEN=secret VERTEX_API_KEY=secret
export XDG_CONFIG_HOME=parent-config XDG_DATA_HOME=parent-data XDG_STATE_HOME=parent-state
export WORKSTATION_CLIENT=parent DIRENV_DIFF=parent
cat > "$fixture/bin/agy" <<'STUB'
#!/bin/bash
set -euo pipefail
fail() { printf 'Stub assertion failed: %s\n' "$1" >&2; exit 90; }
mode_of() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"; }
for name in $(compgen -e); do
  case "$name" in
    GEMINI_CLI_HOME|ANTIGRAVITY_APP_DATA_DIR) ;;
    GOOGLE_*|GEMINI_*|GCLOUD_*|CLOUDSDK_*|AGY_*|ANTIGRAVITY_*|VERTEX_*|XDG_*|WORKSTATION_*|DIRENV_*) fail "inherited $name" ;;
  esac
done
context=$(dirname "$PWD")
[ "$PWD" = "$context/workspace" ] || fail workspace
[ -z "$(ls -A "$PWD")" ] || fail 'workspace not empty'
[ "$TMPDIR" = "$context/tmp" ] || fail TMPDIR
for dir in "$context" "$context/workspace" "$context/home" "$context/state" "$context/tmp"; do
  [ -d "$dir" ] && [ "$(mode_of "$dir")" = 700 ] || fail permissions
done
case "$context" in
  */version)
    [ "$HOME" = "$context/home" ] || fail 'version HOME'
    [ -z "${GEMINI_CLI_HOME+x}${ANTIGRAVITY_APP_DATA_DIR+x}" ] || fail 'version overrides'
    [ "$#" = 1 ] && [ "$1" = --version ] || fail 'version arguments'
    printf 'agy stub 1.0\n'; exit 0 ;;
  */GEMINI_CLI_HOME/*)
    [ "$GEMINI_CLI_HOME" = "$context/state" ] || fail GEMINI_CLI_HOME
    [ -z "${ANTIGRAVITY_APP_DATA_DIR+x}" ] || fail 'competing AGY override'
    [ "$HOME" = "$STUB_FIXTURE/parent-home" ] || fail 'original HOME' ;;
  */HOME/*)
    [ "$HOME" = "$context/home" ] || fail 'isolated HOME'
    [ -z "${GEMINI_CLI_HOME+x}${ANTIGRAVITY_APP_DATA_DIR+x}" ] || fail 'competing overrides' ;;
  */ANTIGRAVITY_APP_DATA_DIR/*)
    [ "$ANTIGRAVITY_APP_DATA_DIR" = "$context/state" ] || fail ANTIGRAVITY_APP_DATA_DIR
    [ -z "${GEMINI_CLI_HOME+x}" ] || fail 'competing Gemini override'
    [ "$HOME" = "$STUB_FIXTURE/parent-home" ] || fail 'original HOME' ;;
  *) fail context ;;
esac
[ "$#" = 3 ] && [ "$1" = 'argument with spaces' ] && [ "$2" = '' ] && [ "$3" = '*' ] || fail 'argument forwarding'
printf 'do-not-record-credential-content\n' > "$context/state/stub-created"
[ "$(mode_of "$context/state/stub-created")" = 600 ] || fail 'file permissions'
# Store only context paths in this disposable verification fixture.
printf '%s\n' "$context" >> "$STUB_FIXTURE/launches"
exit "${STUB_EXIT:-0}"
STUB
chmod 700 "$fixture/bin/agy"
probe() {
  AGY_PROBE_STUB_TEST=1 /bin/bash "$kit/tests/agy-login-isolation.sh" \
    --binary "$fixture/bin/agy" -- 'argument with spaces' '' '*'
}
# Mixed classifications, all candidates A/B, inventories and cleanup.
printf 'yes\nrun\nsignin\ninside\nrun\nsignin\ninside\nrun\nreuse\nnone\nrun\nsignin\ninside\nrun\nfailed\nnone\nrun\nunknown\nunknown\n' | probe > "$fixture/output"
report=$(sed -n 's/^Report retained at //p' "$fixture/output")
[ -f "$report" ] && [ "$(mode_of "$report")" = 600 ]
[ "$(mode_of "$(dirname "$report")")" = 700 ]
grep -q 'No reuse observed:' "$report"
grep -q 'Login reuse detected: FAIL' "$report"
grep -q 'Result: Inconclusive' "$report"
[ "$(wc -l < "$fixture/launches" | tr -d ' ')" = 6 ]
[ "$(sort -u "$fixture/launches" | wc -l | tr -d ' ')" = 6 ]
for paths in "$(dirname "$report")"/*-paths.txt; do
  grep -qx './state/stub-created' "$paths"
  [ "$(mode_of "$paths")" = 600 ]
done
if grep -R -q 'do-not-record-credential-content' "$(dirname "$report")"; then
  printf 'Credential contents leaked into retained reports\n' >&2; exit 1
fi
[ ! -e "$(dirname "$report")/contexts" ]
grep -qx 'agy stub 1.0' "$(dirname "$report")/version.txt"
# Parent exports remain untouched, with no writes to the parent home.
[ "$GEMINI_API_KEY" = secret ] && [ "$GOOGLE_API_KEY" = secret ]
[ "$GEMINI_CLI_HOME" = parent-gemini ] && [ "$ANTIGRAVITY_APP_DATA_DIR" = parent-agy ]
[ "$HOME" = "$fixture/parent-home" ] && [ "$XDG_CONFIG_HOME" = parent-config ]
[ -z "$(ls -A "$HOME")" ]
# Unconfirmed baseline must stop, without any interactive stub launches.
for baseline in no unknown; do
  printf '%s\n' "$baseline" | probe > "$fixture/output"
  report=$(sed -n 's/^Report retained at //p' "$fixture/output")
  grep -q 'Overall: Inconclusive' "$report"
  [ "$(wc -l < "$fixture/launches" | tr -d ' ')" = 6 ]
done
# A nonzero startup failure cannot become a no-reuse result; skips also count
# as inconclusive. Input EOF retains the partial report and cleans up state.
export STUB_EXIT=23
printf 'yes\nrun\nsignin\nnone\nrun\nsignin\nnone\nskip\nnone\nskip\nnone\nskip\nnone\nskip\nnone\n' | probe > "$fixture/output"
report=$(sed -n 's/^Report retained at //p' "$fixture/output")
if grep -q 'No reuse observed:' "$report"; then
  printf 'Startup failure incorrectly classified as no reuse\n' >&2; exit 1
fi
[ "$(grep -c 'Result: Inconclusive' "$report")" = 3 ]
status=0
printf 'yes\n' | probe > "$fixture/output" 2>/dev/null || status=$?
[ "$status" = 2 ]
report=$(sed -n 's/^Report retained at //p' "$fixture/output")
grep -q 'run is incomplete' "$report"
[ ! -e "$(dirname "$report")/contexts" ]
printf 'PASS: AGY probe environment, arguments, permissions, observations and cleanup\n'
