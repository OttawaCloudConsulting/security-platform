#!/bin/bash
# Guided observation only: no login/logout, model prompts, or terminal capture.
set -euo pipefail
umask 077

usage() {
  cat <<'HELP'
Usage: agy-login-isolation.sh [--binary PATH] [-- AGY_STARTUP_ARGUMENTS...]
Run from a terminal. Only pass startup arguments that cannot authenticate,
log out, submit prompts, resume sessions, or change account/configuration state.
Each launch uses a fresh empty workspace. Exit AGY before authenticating.
Results contain version metadata, fixed-choice observations and file paths only.
HELP
}
binary=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --binary) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; binary=$2; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    --) shift; break ;;
    *) usage >&2; exit 2 ;;
  esac
done
if [ -z "$binary" ]; then binary=$(type -P agy || true); fi
[ -n "$binary" ] && [ -f "$binary" ] && [ -x "$binary" ] || {
  printf 'AGY executable not found; use --binary PATH.\n' >&2; exit 2;
}
binary="$(cd -P "$(dirname "$binary")" && pwd)/$(basename "$binary")"

# Use a dedicated descriptor so AGY cannot consume the observation responses.
# Piped input is reserved for the offline stub verifier, never a real launch.
if [ -t 0 ] && [ -t 1 ]; then
  exec 3</dev/tty
elif [ "${AGY_PROBE_STUB_TEST:-}" = 1 ]; then
  exec 3<&0
else
  printf 'Run the real probe in an interactive terminal.\n' >&2; exit 2
fi
root=$(mktemp -d "${TMPDIR:-/tmp}/wsk-agy-login.XXXXXX")
root=$(cd -P "$root" && pwd)
report="$root/results.txt"
cleanup() {
  # Retain only reports and path inventories, never raw application state.
  rm -rf "$root/contexts"
  printf '\nReport retained at %s\n' "$report"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$root/contexts/version/workspace" "$root/contexts/version/home" \
  "$root/contexts/version/state" "$root/contexts/version/tmp"
printf 'AGY login isolation probe\nUTC: %s\nBinary: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$binary" > "$report"

choose() {
  local answer
  while :; do
    printf '%s ' "$1" >&2
    if ! IFS= read -r answer <&3; then
      printf '\nObservation input ended; run is incomplete.\n' >> "$report"
      exit 2
    fi
    case " $2 " in *" $answer "*)
      [ -n "$answer" ] && { choice=$answer; return; } ;;
    esac
    printf 'Choose one of: %s\n' "$2" >&2
  done
}

launch() (
  local candidate=$1 context=$2 name
  shift 2
  # Do not print values. Scrub only in this subprocess, including competing
  # relocation settings and direnv state from an active deployed client.
  for name in $(compgen -e); do
    case "$name" in
      GOOGLE_*|GEMINI_*|GCLOUD_*|CLOUDSDK_*|AGY_*|ANTIGRAVITY_*|VERTEX_*|\
      WORKSTATION_*|DIRENV_*|XDG_*|BASH_ENV|ENV)
        unset "$name" ;;
    esac
  done
  export TMPDIR="$context/tmp"
  case "$candidate" in
    GEMINI_CLI_HOME) export GEMINI_CLI_HOME="$context/state" ;;
    HOME) export HOME="$context/home" ;;
    ANTIGRAVITY_APP_DATA_DIR) export ANTIGRAVITY_APP_DATA_DIR="$context/state" ;;
  esac
  cd "$context/workspace"
  exec 3<&-
  exec "$binary" "$@"
)

# Version only, in its own throwaway context; no startup transcript is saved.
version_status=0
launch HOME "$root/contexts/version" --version > "$root/version.txt" 2>/dev/null || version_status=$?
printf 'Version command exit: %s\n' "$version_status" >> "$report"
printf 'Version metadata: version.txt\n' >> "$report"
printf '\nNo login/logout or prompts. Stop at sign-in, or observe the existing\naccount and exit. Do not select Google login or open a browser auth flow.\n'
choose 'Already known to have an existing AGY Google login? [yes/no/unknown]' 'yes no unknown'
baseline=$choice
printf 'Existing baseline login: %s (operator reported; no baseline launch)\n' "$baseline" >> "$report"
if [ "$baseline" != yes ]; then
  printf 'Overall: Inconclusive (no confirmed baseline account).\n' >> "$report"
  printf 'No confirmed baseline; no interactive probes launched.\n'
  exit 0
fi

for candidate in GEMINI_CLI_HOME HOME ANTIGRAVITY_APP_DATA_DIR; do
  printf '\nCandidate: %s (experimental; AGY support unverified)\n' "$candidate" | tee -a "$report"
  obs_a=unknown
  obs_b=unknown
  for client in A B; do
    context="$root/contexts/$candidate/$client"
    mkdir -p "$context/workspace" "$context/state" "$context/home" "$context/tmp"
    printf '\nClient %s: launch from an empty workspace; exit before signing in.\n' "$client"
    choose 'Launch now? [run/skip]' 'run skip'
    status=skipped
    observation=unknown
    if [ "$choice" = run ]; then
      status=0
      # Direct terminal I/O, no tee/script/log or credential reads.
      launch "$candidate" "$context" "$@" <&0 || status=$?
      choose 'Observed? [signin/reuse/failed/unknown] (no account identifiers)' 'signin reuse failed unknown'
      observation=$choice
      # Ctrl-C is a normal way to leave a TUI. Other errors cannot support
      # a no-reuse conclusion, even if a sign-in screen appeared first.
      case "$status" in 0|130) ;; *)
        [ "$observation" = reuse ] || observation=failed ;;
      esac
    fi
    printf '%s exit: %s; login observation: %s\n' "$client" "$status" "$observation" >> "$report"
    # Names only, within private probe directories; never follow symlinks.
    # Exclude the precreated scaffolding directories from this inventory.
    inventory="$root/$candidate-$client-paths.txt"
    (cd "$context"; find . ! -path . ! -path ./workspace ! -path ./state \
      ! -path ./home ! -path ./tmp -print) > "$inventory"
    printf '%s file paths: %s\n' "$client" "$(basename "$inventory")" >> "$report"
    printf '%s inventory origin: %s\n' "$client" "$context" >> "$report"
    choose 'File relocation observed? [inside/outside/both/none/unknown]' 'inside outside both none unknown'
    printf '%s file relocation: %s (operator reported)\n' "$client" "$choice" >> "$report"
    if [ "$client" = A ]; then obs_a=$observation; else obs_b=$observation; fi
  done
  result='Inconclusive (startup failed, skipped, or account state undetermined).'
  if [ "$obs_a" = reuse ] || [ "$obs_b" = reuse ]; then
    result='Login reuse detected: FAIL login isolation.'
  elif [ "$obs_a" = signin ] && [ "$obs_b" = signin ]; then
    result='No reuse observed: subsequent two-account test required; isolation NOT proven.'
  fi
  printf 'Result: %s\n' "$result" | tee -a "$report"
done
printf '\nFile relocation is independent of login reuse. Integration deferred.\n' >> "$report"
