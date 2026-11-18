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
CONFIG="$KIT_ROOT/workstation-segregation.conf"
DRY_RUN=0
ACTION=apply
ALL=0
CLIENTS=""

usage() { sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --config)  CONFIG="${2:?--config needs a file}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --remove)  ACTION=remove; shift ;;
    --all)     ALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)  CLIENTS="$CLIENTS $1"; shift ;;
  esac
done
export DRY_RUN

# shellcheck source=lib/common.sh
. "$KIT_ROOT/lib/common.sh"
load_config "$CONFIG"
detect_platform
# shellcheck source=lib/scaffold.sh
. "$KIT_ROOT/lib/scaffold.sh"

if [ "$ALL" = 1 ] && [ -n "$CLIENTS" ]; then die "use either --all or client names, not both"; fi
if [ "$ALL" = 0 ] && [ -z "$CLIENTS" ]; then usage >&2; exit 2; fi
if [ "$ACTION" = apply ]; then
  [ "$ENABLE_AGENT_CLI_ISOLATION" = 1 ] && [ "${ENABLE_AGY_CLI_ISOLATION:-0}" = 1 ] \
    || die "set ENABLE_AGENT_CLI_ISOLATION=1 and ENABLE_AGY_CLI_ISOLATION=1 in $CONFIG_FILE first"
fi
[ "$DRY_RUN" = 1 ] && log "dry run: no changes will be made"

if [ "$ALL" = 1 ]; then
  check_client_root || die "cannot read CLIENT_ROOT"
  for d in "$CLIENT_ROOT"/*/; do
    d="${d%/}"
    [ -d "$d" ] && [ ! -L "$d" ] || continue
    n="$(basename "$d")"
    is_excluded "$n" && continue
    is_segregated "$d" || continue
    CLIENTS="$CLIENTS $n"
  done
  [ -n "$CLIENTS" ] || { log "no segregated clients under $CLIENT_ROOT"; exit 0; }
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wsk-agy-migrate.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# _unset_if_stale <dest> <expected>: back up and delete dest unless it matches.
# Sets UNSET=1 when it removed (or, in a dry run, would remove) dest.
_unset_if_stale() {
  local dest="$1" expected="$2"
  UNSET=0
  if [ -L "$dest" ]; then
    UNSET=1
    log "unset $dest (symlink, moved aside)"
    run mv "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
    return 0
  fi
  [ -e "$dest" ] || return 0
  if [ -f "$dest" ] && cmp -s "$expected" "$dest"; then return 0; fi
  UNSET=1
  log "unset $dest (differs from the current kit)"
  backup_file "$dest"
  run rm -rf "$dest"
}

# GNU stat first: on Linux `stat -f` is a valid (filesystem) query and would not fail.
_mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

# Private directories AGY needs must be real directories inside the client.
_check_no_links() {
  local dir="$1" p
  for p in .workstation .workstation/bash .workstation/git .workstation/agy .workstation/agy/home .workstation/agy/tmp; do
    if [ -L "$dir/$p" ]; then
      warn "$(basename "$dir"): $p is a symlink; fix it by hand (agy-client.sh refuses redirected directories)"
      return 1
    fi
  done
}

_report_relocation_exports() {
  local dir="$1" f
  for f in "$dir/.envrc" "$dir"/.workstation/bash/*.sh; do
    [ -f "$f" ] || continue
    [ "$f" = "$dir/.workstation/bash/agy.sh" ] && continue
    if grep -nE '^[[:space:]]*(export[[:space:]]+)?(ANTIGRAVITY_APP_DATA_DIR|GEMINI_CLI_HOME)=' "$f" >/dev/null 2>&1; then
      warn "$(basename "$dir"): $f sets ANTIGRAVITY_APP_DATA_DIR/GEMINI_CLI_HOME; these were rejected as login isolation (see docs/AGY-LOGIN-ISOLATION.md). The wrapper clears them for AGY; remove them by hand if nothing else needs them."
    fi
  done
}

migrate_client() { # migrate_client <name>
  local name="$1" dir frag want_frag want_git frag_unset
  [[ "$name" =~ $CLIENT_NAME_RE ]] || { warn "skipping '$name': client names must match $CLIENT_NAME_RE"; return 1; }
  is_excluded "$name" && { warn "skipping '$name': excluded by EXCLUDE_DIRS"; return 1; }
  dir="$CLIENT_ROOT/$name"
  is_safe_path "$dir" || { warn "skipping '$name': unsupported characters in path"; return 1; }
  [ -d "$dir" ] && [ ! -L "$dir" ] || { warn "skipping '$name': $dir is not a directory"; return 1; }
  is_segregated "$dir" || { warn "skipping '$name': not a segregated client (no .workstation or WORKSTATION_CLIENT .envrc)"; return 1; }
  _check_no_links "$dir" || return 1
  frag="$dir/.workstation/bash/agy.sh"
  set_render_vars "$dir" "$name"

  if [ "$ACTION" = remove ]; then
    if [ -e "$frag" ] || [ -L "$frag" ]; then
      log "$name: removing the AGY wrapper fragment (private home kept)"
      backup_file "$frag"
      run rm -f "$frag"
    else
      log "$name: no AGY wrapper fragment"
    fi
    return 0
  fi

  # Unset: anything kit-managed that the current kit would render differently.
  want_frag="$TMP_DIR/$name.agy.sh"
  render_template "$KIT_ROOT/templates/client/agy-fragment.sh" > "$want_frag"
  _unset_if_stale "$frag" "$want_frag"
  frag_unset=$UNSET
  if [ -d "$dir/.workstation/agy" ]; then
    want_git="$TMP_DIR/$name.gitconfig"
    _write_agy_gitconfig "$want_git"
    _unset_if_stale "$dir/.workstation/agy/gitconfig" "$want_git"
  fi

  # Apply: create-if-missing scaffold (adds agy/{home,tmp} and gitconfig), then the wrapper.
  scaffold_client "$dir" adopt || return 1
  # Pre-existing private directories keep their mode under scaffold; tighten them here.
  for sub in agy agy/home agy/tmp; do
    if [ -d "$dir/.workstation/$sub" ] && [ "$(_mode_of "$dir/.workstation/$sub")" != 700 ]; then
      run chmod 700 "$dir/.workstation/$sub"
    fi
  done
  if [ "$DRY_RUN" = 1 ] && [ "$frag_unset" = 1 ]; then
    log "DRY-RUN: create $frag"
  else
    _install_tpl agy-fragment.sh .workstation/bash/agy.sh 644 || log "$name: AGY wrapper fragment is current"
  fi
  _report_relocation_exports "$dir"
  return 0
}

failed=""
for c in $CLIENTS; do
  migrate_client "$c" || failed="$failed $c"
done
[ -z "$failed" ] || die "not migrated:$failed"
if [ "$DRY_RUN" != 1 ]; then
  log "done. Leave and re-enter each client (or open a new terminal) so the shell loads the change."
  [ "$ACTION" = remove ] || log "Each client's first agy launch asks for that client's Google login."
fi
