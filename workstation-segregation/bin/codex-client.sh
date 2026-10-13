#!/bin/bash
# Launch the installed Codex with the active client's ChatGPT configuration.
# API access inside Codex requires an explicit direnv exec command.
set -Eeuo pipefail

fail() { printf 'codex-client: %s\n' "$*" >&2; exit 1; }

client_dir="${WORKSTATION_CLIENT_DIR:-}"
[ -n "$client_dir" ] && [ -n "${WORKSTATION_CLIENT:-}" ] \
  || fail 'enter an isolated client directory first'
case "$client_dir" in /*) ;; *) fail 'client directory must be absolute' ;; esac
[ -f "$client_dir/.envrc" ] || fail 'client .envrc is missing'
client_name="$(basename "$client_dir")"
[[ "$client_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'invalid client name'
[ "$WORKSTATION_CLIENT" = "$(printf '%s' "$client_name" | tr 'a-z.-' 'A-Z__')" ] \
  || fail 'active client label does not match its directory'
[ "${CODEX_HOME:-}" = "$client_dir/.workstation/codex" ] \
  || fail 'CODEX_HOME must point to the active client .workstation/codex'
[ -d "$CODEX_HOME" ] || fail 'client CODEX_HOME is missing'
client_real="$(cd -P "$client_dir" && pwd)"
case "$(pwd -P)/" in "$client_real/"*) ;; *) fail 'current directory is outside the active client' ;; esac

# Only this subprocess is scrubbed; the parent shell retains its API settings.
for exported_name in $(compgen -e); do
  case "$exported_name" in OPENAI_*) unset "$exported_name" ;; esac
done
unset CODEX_API_KEY CODEX_ACCESS_TOKEN CODEX_SQLITE_HOME
codex_bin="$(type -P codex || true)"
[ -n "$codex_bin" ] || fail 'Codex is not installed or is missing from PATH'
exec "$codex_bin" "$@"
