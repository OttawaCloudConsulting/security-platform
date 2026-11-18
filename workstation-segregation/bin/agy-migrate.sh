#!/bin/bash
# Migrate EXISTING clients to the AGY private-HOME wrapper (deploy never adds it to them).
#
#   bin/agy-migrate.sh [--config FILE] [--dry-run] (--all | CLIENT...)
#   bin/agy-migrate.sh [--config FILE] [--dry-run] --remove (--all | CLIENT...)
#
# Apply (default) first unsets the kit-managed AGY files that differ from what the
# current kit renders (.workstation/bash/agy.sh, .workstation/agy/gitconfig; each is
# backed up as *.bak.<timestamp>), then applies the adopt-mode scaffold (create-if-
# missing, including .workstation/agy/{home,tmp}) and installs the wrapper fragment.
# Files that already match are left alone, so repeat runs change nothing.
# --remove backs up and deletes only the wrapper fragment (rollback).
# Never touched: .workstation/agy/home contents (AGY login state), .envrc, the
# keyring. Exports of the rejected relocation variables are reported, not edited.
# Requires ENABLE_AGENT_CLI_ISOLATION=1 and ENABLE_AGY_CLI_ISOLATION=1 to apply.
set -Eeuo pipefail
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KIT_ROOT
# shellcheck source=lib/migrate.sh
. "$KIT_ROOT/lib/migrate.sh"
migrate_init 2,15 "$@"
[ "$MIGRATE_ACTION" = remove ] || migrate_require_flags ENABLE_AGENT_CLI_ISOLATION=1 ENABLE_AGY_CLI_ISOLATION=1

migrate_agy() { # migrate_agy <name> <dir>
  local name="$1" dir="$2" want
  check_no_links "$dir" .workstation .workstation/bash .workstation/git \
    .workstation/agy .workstation/agy/home .workstation/agy/tmp || return 1
  if [ "$MIGRATE_ACTION" = remove ]; then
    remove_file "$dir/.workstation/bash/agy.sh"
    return 0
  fi
  if [ -d "$dir/.workstation/agy" ]; then
    want="$MIGRATE_TMP/$name.gitconfig"
    _write_agy_gitconfig "$want"
    unset_if_stale "$dir/.workstation/agy/gitconfig" "$want"
  fi
  scaffold_client "$dir" adopt || return 1
  tighten_dirs "$dir" .workstation/agy .workstation/agy/home .workstation/agy/tmp
  replace_fragment agy-fragment.sh .workstation/bash/agy.sh
  report_exports "$dir" '^[[:space:]]*(export[[:space:]]+)?(ANTIGRAVITY_APP_DATA_DIR|GEMINI_CLI_HOME)=' \
    'sets ANTIGRAVITY_APP_DATA_DIR/GEMINI_CLI_HOME; these were rejected as login isolation (see docs/AGY-LOGIN-ISOLATION.md). The wrapper clears them for AGY; remove them by hand if nothing else needs them.'
}

migrate_each migrate_agy
[ "$DRY_RUN" = 1 ] || [ "$MIGRATE_ACTION" = remove ] || log "Each client's first agy launch asks for that client's Google login."
