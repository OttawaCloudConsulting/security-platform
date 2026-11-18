#!/bin/bash
# Migrate EXISTING clients to per-client Claude Code configuration (deploy never edits
# an adopted client's .envrc, so CLAUDE_CONFIG_DIR is otherwise missing there).
#
#   bin/claude-migrate.sh [--config FILE] [--dry-run] [--allow] (--all | CLIENT...)
#   bin/claude-migrate.sh [--config FILE] [--dry-run] [--allow] --remove (--all | CLIENT...)
#
# Apply (default) unsets, then applies:
#   .envrc   every CLAUDE_CONFIG_DIR assignment (active or commented out) is replaced
#            by a managed block exporting "$(expand_path .workstation/claude)".
#   settings stale kit SessionStart hooks (direnv-session-env.sh from another kit path)
#            are removed from .workstation/claude/settings.json and the current one
#            added; other settings are kept. Missing files come from the adopt scaffold.
# Files that already match are left alone, so repeat runs change nothing; every
# changed file is backed up as *.bak.<timestamp>. A changed .envrc is blocked by
# direnv until approved: pass --allow to run `direnv allow` (it approves the WHOLE
# file, including edits made before this run), or review and run it yourself.
# --remove drops the export (managed block and active lines); .workstation/claude
# (login, history, settings) is kept. Requires ENABLE_AGENT_CLI_ISOLATION=1 to apply.
set -Eeuo pipefail
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KIT_ROOT
# shellcheck source=lib/migrate.sh
. "$KIT_ROOT/lib/migrate.sh"
migrate_init 2,19 "$@"
[ "$MIGRATE_ACTION" = remove ] || migrate_require_flags ENABLE_AGENT_CLI_ISOLATION=1

CLAUDE_ERE='^(export[[:space:]]+)?CLAUDE_CONFIG_DIR='
JQ="$(PATH="$BIN_DIR:$PATH" command -v jq 2>/dev/null || true)"
[ "$MIGRATE_ACTION" = remove ] || [ -n "$JQ" ] || die "jq is required (install it or run deploy.sh first)"

# _claude_hook <settings.json>: exactly one kit SessionStart hook, the current one.
_claude_hook() {
  local f="$1" cmd new="$MIGRATE_TMP/settings.$$"
  cmd="/bin/bash $KIT_ROOT/hooks/direnv-session-env.sh"
  # Already exactly the current hook: leave the file byte-for-byte alone.
  # shellcheck disable=SC2016  # jq programs, not shell
  if "$JQ" -e --arg cmd "$cmd" \
      '[.hooks.SessionStart[]?.hooks[]?.command | select(type == "string" and test("direnv-session-env\\.sh$"))] == [$cmd]' \
      "$f" > /dev/null 2>&1; then
    return 0
  fi
  # shellcheck disable=SC2016
  if ! "$JQ" --arg cmd "$cmd" '
      def kit: type == "string" and test("direnv-session-env\\.sh$");
      ([.hooks.SessionStart[]?.hooks[]?.command | select(kit)]) as $kit
      | if $kit == [$cmd] then .
        else .hooks.SessionStart = (
          ((.hooks.SessionStart // [])
            | map(.hooks = ((.hooks // []) | map(select(.command | kit | not))))
            | map(select((.hooks | length) > 0)))
          + [{"hooks": [{"type": "command", "command": $cmd}]}])
        end' "$f" > "$new"; then
    warn "$(basename "$R_DIR"): could not parse $f; fix it by hand"
    return 1
  fi
  cmp -s "$new" "$f" && return 0
  log "unset stale SessionStart hook(s) in $f; adding the current one"
  if [ "$DRY_RUN" = 1 ]; then log "DRY-RUN: update $f"; return 0; fi
  backup_file "$f"
  cat "$new" > "$f"
}

migrate_claude() { # migrate_claude <name> <dir>
  local name="$1" dir="$2" block="$MIGRATE_TMP/$1.claude"
  check_no_links "$dir" .envrc .workstation .workstation/claude .workstation/claude/settings.json || return 1
  if [ "$MIGRATE_ACTION" = remove ]; then
    envrc_remove "$dir/.envrc" claude "$CLAUDE_ERE"
    envrc_finish "$dir"
    return 0
  fi
  [ -f "$dir/.envrc" ] || { warn "$name: no .envrc"; return 1; }
  scaffold_client "$dir" adopt || return 1
  tighten_dirs "$dir" .workstation/claude
  # shellcheck disable=SC2016  # expand_path runs in direnv, not here
  printf 'export CLAUDE_CONFIG_DIR="$(expand_path .workstation/claude)"\n' > "$block"
  envrc_apply "$dir/.envrc" claude "$CLAUDE_ERE" "$block" || return 1
  envrc_finish "$dir"
  if [ -f "$dir/.workstation/claude/settings.json" ]; then
    _claude_hook "$dir/.workstation/claude/settings.json" || return 1
  fi
  tighten_files "$dir" .workstation/claude/settings.json
}

migrate_each migrate_claude
[ "$DRY_RUN" = 1 ] || [ "$MIGRATE_ACTION" = remove ] \
  || log "Run 'claude' inside each client and sign in with that client's account (/login)."
