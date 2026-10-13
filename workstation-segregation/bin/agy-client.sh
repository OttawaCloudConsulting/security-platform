#!/bin/bash
# HOME is private to this process; this is segregation, not a sandbox.
set -Eeuo pipefail
fail() { printf 'agy-client: %s\n' "$*" >&2; exit 1; }
client_dir=${WORKSTATION_CLIENT_DIR:-}
[ -n "$client_dir" ] && [ -n "${WORKSTATION_CLIENT:-}" ] || fail 'enter an isolated client directory first'
case "$client_dir" in /*) ;; *) fail 'client directory must be absolute' ;; esac
[ -d "$client_dir" ] && [ -f "$client_dir/.envrc" ] && [ ! -L "$client_dir/.envrc" ] || fail 'client directory or .envrc is missing'
client_name=$(basename "$client_dir")
[[ "$client_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'invalid client name'
[ "$WORKSTATION_CLIENT" = "$(printf '%s' "$client_name" | tr 'a-z.-' 'A-Z__')" ] || fail 'active client label does not match its directory'
client_real=$(cd -P "$client_dir" && pwd)
case "$(pwd -P)/" in "$client_real/"*) ;; *) fail 'current directory is outside the active client' ;; esac
private="$client_dir/.workstation/agy"
for dir in "$client_dir/.workstation/git" "$private" "$private/home" "$private/tmp"; do
  [ -d "$dir" ] && [ ! -L "$dir" ] && [ "$(cd -P "$dir" && pwd)" = "$client_real${dir#"$client_dir"}" ] || fail 'private directories are missing or redirected'
done
for file in "$private/gitconfig" "$client_dir/.workstation/git/config"; do
  [ -f "$file" ] && [ -r "$file" ] && [ ! -L "$file" ] || fail 'required private Git configuration is missing or linked'
done
# Resolve before replacing HOME; relative PATH entries must stay usable.
agy_bin=$(type -P agy || true)
[ -n "$agy_bin" ] && [ -f "$agy_bin" ] && [ -x "$agy_bin" ] || fail 'AGY is not installed or is missing from PATH'
agy_bin="$(cd -P "$(dirname "$agy_bin")" && pwd)/$(basename "$agy_bin")"
for name in $(compgen -e); do
  case "$name" in
    GOOGLE_*|GEMINI_*|GCLOUD_*|CLOUDSDK_*|AGY_*|ANTIGRAVITY_*|VERTEX_*|XDG_*|BASH_ENV|ENV|GIT_CONFIG*) unset "$name" ;;
  esac
done
export HOME="$private/home" TMPDIR="$private/tmp"
export GIT_CONFIG_GLOBAL="$private/gitconfig" GIT_CONFIG_NOSYSTEM=1
exec "$agy_bin" "$@"
