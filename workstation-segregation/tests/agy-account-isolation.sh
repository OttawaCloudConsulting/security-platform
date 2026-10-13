#!/bin/bash
# Operator-run authentication test. Never capture a terminal or read credentials.
set -Eeuo pipefail
umask 077
usage() { printf 'Usage: agy-account-isolation.sh --state-dir ABSOLUTE_PATH [--binary PATH] [--accounts one|two]\n'; }
fail() { printf 'agy-account-isolation: %s\n' "$*" >&2; exit 2; }
root='' binary='' accounts=one
while [ "$#" -gt 0 ]; do
  case "$1" in
    --state-dir|--binary|--accounts)
      [ "$#" -ge 2 ] || fail 'option needs a value'
      case "$1" in --state-dir) root=$2 ;; --binary) binary=$2 ;; --accounts) accounts=$2 ;; esac
      shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
case "$accounts" in one|two) ;; *) fail 'accounts must be one or two' ;; esac
case "$root" in /*) ;; *) fail 'state directory must be absolute' ;; esac
root=${root%/}
[ -n "$root" ] || fail 'cannot use filesystem root'
# Reject symlink ancestors and ambiguous paths before writing anything.
check_path() {
  local path=$1
  case "$path/" in *'/../'*|*'/./'*|*'//'*) fail 'ambiguous state path' ;; esac
  while [ "$path" != / ]; do
    [ ! -L "$path" ] || fail 'symlinked state path'
    path=$(dirname "$path")
  done
}
check_path "$root"
if [ -z "$binary" ]; then binary=$(type -P agy || true); fi
[ -n "$binary" ] && [ -f "$binary" ] && [ -x "$binary" ] || fail 'AGY executable not found'
binary="$(cd -P "$(dirname "$binary")" && pwd)/$(basename "$binary")"
if [ -t 0 ] && [ -t 1 ]; then exec 3</dev/tty
elif [ "${AGY_ACCOUNT_STUB_TEST:-}" = 1 ]; then exec 3<&0
else fail 'run the real harness in an interactive terminal'; fi
fresh=yes
if [ -e "$root" ]; then
  [ -d "$root" ] && [ -f "$root/.agy-account-harness" ] && [ ! -L "$root/.agy-account-harness" ] || fail 'unrelated existing state directory'
  [ "$(cat "$root/.agy-account-harness")" = agy-account-harness-v1 ] || fail 'invalid harness marker'
  fresh=no
else
  mkdir -p "$root"
  printf 'agy-account-harness-v1\n' > "$root/.agy-account-harness"
fi
for context in A B ordinary version; do
  for sub in '' /home /workspace /tmp; do
    check_path "$root/$context$sub"
    [ ! -e "$root/$context$sub" ] || [ -d "$root/$context$sub" ] || fail 'invalid context directory'
    mkdir -p "$root/$context$sub"
    chmod 700 "$root/$context$sub"
  done
done
check_path "$root/reports"
mkdir -p "$root/reports"
chmod 700 "$root" "$root/reports"
# No stale lock recovery by deletion: operator must confirm a process has ended.
mkdir "$root/.run-lock" 2>/dev/null || fail 'run lock exists; confirm no harness is running before removing .run-lock'
report=$(mktemp "$root/reports/run.XXXXXX")
chmod 600 "$report"
finish() { printf 'Finished UTC: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$report"; rmdir "$root/.run-lock"; printf '\nReport: %s\nHomes retained: %s\n' "$report" "$root"; }
trap finish EXIT
trap 'printf "Overall: pending (interrupted)\n" >> "$report"; exit 130' INT
trap 'printf "Overall: pending (interrupted)\n" >> "$report"; exit 143' TERM
printf 'Binary: %s\nUTC: %s\nAccounts: %s\nFresh root: %s\n' "$binary" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$accounts" "$fresh" > "$report"
choose() {
  local answer
  while :; do
    printf '%s [%s] ' "$1" "$2" >&2
    if ! IFS= read -r answer <&3; then printf 'Overall: pending (input ended)\n' >> "$report"; exit 2; fi
    case " $2 " in *" $answer "*) [ -n "$answer" ] && { choice=$answer; return; } ;; esac
  done
}
launch() (
  context=$1; shift
  for name in $(compgen -e); do
    case "$name" in GOOGLE_*|GEMINI_*|GCLOUD_*|CLOUDSDK_*|AGY_*|ANTIGRAVITY_*|VERTEX_*|WORKSTATION_*|DIRENV_*|XDG_*|BASH_ENV|ENV) unset "$name" ;; esac
  done
  export TMPDIR="$root/$context/tmp"
  [ "$context" = ordinary ] || export HOME="$root/$context/home"
  cd "$root/$context/workspace"
  # Workspaces must remain empty; don't silently delete application files.
  [ -z "$(ls -A .)" ] || exit 125
  exec 3<&-
  exec "$binary" "$@"
)
version_status=0
version=$(launch version --version 2>/dev/null) || version_status=$?
# Retain only a version number, never arbitrary command output.
version=$(printf '%s\n' "$version" | sed -nE 's/^(AGY |agy |v)?([0-9]+\.[0-9]+\.[0-9]+)$/\2/p' | head -1)
printf 'Version: %s\nVersion exit: %s\n' "${version:-unknown}" "$version_status" >> "$report"
printf 'Observe identity only; no email addresses in responses. No logout, model prompts, token copying or keyring changes.\n'
printf 'Label the ordinary account mentally, then A; two-account mode requires a distinct B.\n'
step() {
  local label=$1 context=$2 expected=$3 status=skipped observation=unknown
  printf '\n%s\n' "$label"
  choose 'Launch then exit AGY' 'run skip'
  if [ "$choice" = run ]; then
    status=0
    launch "$context" || status=$?
    choose 'Account match (expected means the account assigned to this context)' 'expected other signin failed unknown'
    observation=$choice
  fi
  printf 'Step: %s; exit: %s; observation: %s; UTC: %s\n' "$label" "$status" "$observation" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$report"
  if [ "$observation" = other ] || { [ "$expected" = signin ] && [ "$observation" = expected ]; } || { [ "$expected" = expected ] && [ "$observation" = signin ]; }; then
    printf 'Overall: fail (account mismatch)\n' >> "$report"; exit 1
  fi
  case "$status" in 0|130) ;; *) observation=failed ;; esac
  if [ "$observation" != "$expected" ]; then printf 'Overall: pending (unconfirmed step)\n' >> "$report"; exit 0; fi
}
step 'ordinary-before: observe without changing the ordinary account' ordinary expected
if [ "$fresh" = yes ]; then
  step 'A-fresh: confirm sign-in required; exit BEFORE authentication' A signin
  step 'A-authenticate: operator signs in with account A and exits' A expected
fi
step 'A-reopen: confirm account A persists' A expected
if [ "$fresh" = yes ]; then
  step 'B-untouched: confirm sign-in required; exit BEFORE authentication' B signin
fi
step 'ordinary-after-A: confirm ordinary account unchanged' ordinary expected
if [ "$accounts" = two ]; then
  choose 'Are A and B distinct Google accounts? (no identifiers)' 'yes no unknown'
  printf 'Distinct accounts: %s\n' "$choice" >> "$report"
  if [ "$choice" != yes ]; then printf 'Overall: pending (distinct accounts unconfirmed)\n' >> "$report"; exit 0; fi
  if [ "$fresh" = yes ]; then
    step 'B-authenticate: operator signs in with distinct account B and exits' B expected
  fi
  step 'A-after-B: confirm account A' A expected
  step 'B-reopen: confirm account B' B expected
  step 'A-final: confirm account A again' A expected
  step 'ordinary-after-B: confirm ordinary account unchanged' ordinary expected
fi
choose 'File relocation (independent of account matches)' 'inside outside both none unknown'
printf 'File relocation: %s\n' "$choice" >> "$report"
if [ "$accounts" = two ] && [ "$fresh" = yes ] && [ -n "$version" ] && [ "$version_status" = 0 ]; then
  printf 'Overall: pass (standalone HOME account test; integration acceptance still required)\n' >> "$report"
else
  printf 'Overall: pending (one account, reused root, or version unknown)\n' >> "$report"
fi
