#!/bin/bash
# Migrate EXISTING clients to per-client Codex (the "Migrating an existing client"
# steps in docs/USER-GUIDE.md, automated; deploy never edits an adopted client).
#
#   bin/codex-migrate.sh [--config FILE] [--dry-run] [--allow] (--all | CLIENT...)
#   bin/codex-migrate.sh [--config FILE] [--dry-run] [--allow] --remove (--all | CLIENT...)
#
# Apply (default) unsets, then applies:
#   .envrc    every CODEX_HOME assignment and `unset CODEX_SQLITE_HOME` (active or
#             commented out) is replaced by a managed block with both; the GPT API
#             clearing/loading block is appended when .envrc does not load
#             .workstation/openai/env yet.
#   config    .workstation/codex/config.toml gets top-level
#             cli_auth_credentials_store = "file" and forced_login_method = "chatgpt";
#             other settings are kept. Missing files come from the adopt scaffold.
#   fragment  a .workstation/bash/codex.sh that differs from the current kit is
#             replaced by the rendered wrapper.
# Files that already match are left alone, so repeat runs change nothing; every
# changed file is backed up as *.bak.<timestamp>. A changed .envrc is blocked by
# direnv until approved: pass --allow to run `direnv allow` (it approves the WHOLE
# file, including edits made before this run), or review and run it yourself.
# --remove drops the CODEX_HOME block/lines and the wrapper; the GPT API block and
# .workstation/{codex,openai} (login, sessions, keys) are kept.
# Requires ENABLE_AGENT_CLI_ISOLATION=1 to apply.
set -Eeuo pipefail
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KIT_ROOT
# shellcheck source=lib/migrate.sh
. "$KIT_ROOT/lib/migrate.sh"
migrate_init 2,24 "$@"
[ "$MIGRATE_ACTION" = remove ] || migrate_require_flags ENABLE_AGENT_CLI_ISOLATION=1

CODEX_ERE='^(export[[:space:]]+)?CODEX_HOME=|^unset[[:space:]]+CODEX_SQLITE_HOME[[:space:]]*$'
OPENAI_LOADER='^[[:space:]]*dotenv[[:space:]]+\.workstation/openai/env'

# _codex_config <config.toml>: the required top-level keys. An existing top-level
# assignment (before the first [table]) is replaced in place, duplicates dropped;
# a missing key is added at the top. Everything else is kept verbatim.
_codex_config() {
  local f="$1" new="$MIGRATE_TMP/config.$$"
  awk '
    BEGIN { want["cli_auth_credentials_store"] = "\"file\""; want["forced_login_method"] = "\"chatgpt\"" }
    { line[++n] = $0 }
    END {
      for (i = 1; i <= n; i++) {
        if (line[i] ~ /^[ \t]*\[/) break
        for (k in want) if (line[i] ~ "^[ \t]*" k "[ \t]*=") found[k] = 1
      }
      for (k in want) if (!(k in found)) print k " = " want[k]
      intable = 0
      for (i = 1; i <= n; i++) {
        if (line[i] ~ /^[ \t]*\[/) intable = 1
        if (!intable) {
          hit = ""
          for (k in want) if (line[i] ~ "^[ \t]*" k "[ \t]*=") hit = k
          if (hit != "") { if (!(hit in done)) print hit " = " want[hit]; done[hit] = 1; continue }
        }
        print line[i]
      }
    }' "$f" > "$new"
  cmp -s "$new" "$f" && return 0
  log "unset/replace auth settings in $f"
  if [ "$DRY_RUN" = 1 ]; then
    diff -u "$f" "$new" | sed -n '3,$p' | sed 's/^/    /' || true
    return 0
  fi
  backup_file "$f"
  cat "$new" > "$f"
}

migrate_codex() { # migrate_codex <name> <dir>
  local name="$1" dir="$2" block="$MIGRATE_TMP/$1.codex"
  check_no_links "$dir" .envrc .workstation .workstation/bash .workstation/codex \
    .workstation/codex/config.toml .workstation/openai .workstation/openai/env || return 1
  if [ "$MIGRATE_ACTION" = remove ]; then
    envrc_remove "$dir/.envrc" codex "$CODEX_ERE"
    envrc_finish "$dir"
    remove_file "$dir/.workstation/bash/codex.sh"
    return 0
  fi
  [ -f "$dir/.envrc" ] || { warn "$name: no .envrc"; return 1; }
  scaffold_client "$dir" adopt || return 1
  tighten_dirs "$dir" .workstation/codex .workstation/openai
  # shellcheck disable=SC2016  # expand_path runs in direnv, not here
  printf 'export CODEX_HOME="$(expand_path .workstation/codex)"\nunset CODEX_SQLITE_HOME\n' > "$block"
  envrc_apply "$dir/.envrc" codex "$CODEX_ERE" "$block" || return 1
  if ! grep -qE "$OPENAI_LOADER" "$dir/.envrc"; then
    # The template's GPT API block: clear inherited OPENAI_*/Codex auth, load the private file.
    sed -n '/^for _openai_var/,/^fi$/p' "$KIT_ROOT/templates/client/envrc" > "$block.openai"
    grep -qE "$OPENAI_LOADER" "$block.openai" || die "GPT API block not found in templates/client/envrc"
    envrc_apply "$dir/.envrc" openai '^dotenv[[:space:]]+\.workstation/openai/env' "$block.openai" || return 1
  fi
  envrc_finish "$dir"
  [ -f "$dir/.workstation/codex/config.toml" ] && _codex_config "$dir/.workstation/codex/config.toml"
  tighten_files "$dir" .workstation/codex/config.toml .workstation/openai/env
  replace_fragment codex-fragment.sh .workstation/bash/codex.sh
}

migrate_each migrate_codex
[ "$DRY_RUN" = 1 ] || [ "$MIGRATE_ACTION" = remove ] \
  || log "In each client run 'codex login' and 'codex login status' with that client's ChatGPT account."
