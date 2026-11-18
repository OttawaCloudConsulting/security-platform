#!/bin/bash
# Shared helpers for the operator-run bin/*-migrate.sh scripts, which bring EXISTING
# (adopted) clients up to what the current kit gives new clients: unset stale
# kit-managed state, then apply. Source after KIT_ROOT is set; bash 3.2-safe.

MIGRATE_ACTION=apply
MIGRATE_ALL=0
MIGRATE_ALLOW=0
MIGRATE_CLIENTS=""

# migrate_init <usage-line-range> "$@": parse options, load config and libraries,
# and resolve --all into MIGRATE_CLIENTS. The caller checks its own flags afterwards.
migrate_init() {
  local range="$1" config="$KIT_ROOT/workstation-segregation.conf" d n
  shift
  DRY_RUN=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --config)  config="${2:?--config needs a file}"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      --remove)  MIGRATE_ACTION=remove; shift ;;
      --all)     MIGRATE_ALL=1; shift ;;
      --allow)   MIGRATE_ALLOW=1; shift ;;
      -h|--help) _migrate_usage "$range"; exit 0 ;;
      -*) echo "unknown option: $1" >&2; _migrate_usage "$range" >&2; exit 2 ;;
      *)  MIGRATE_CLIENTS="$MIGRATE_CLIENTS $1"; shift ;;
    esac
  done
  export DRY_RUN
  # shellcheck source=lib/common.sh
  . "$KIT_ROOT/lib/common.sh"
  load_config "$config"
  detect_platform
  # shellcheck source=lib/scaffold.sh
  . "$KIT_ROOT/lib/scaffold.sh"
  # One run can rewrite a file twice within a second (.envrc gets the codex, then the
  # openai block), and common.sh's backup_file would then overwrite the first backup,
  # losing the original. Within the migrate scripts, backups never overwrite.
  # shellcheck disable=SC2329  # called by common.sh helpers and the migrate scripts
  backup_file() {
    [ -e "$1" ] || [ -L "$1" ] || return 0
    if [ "$DRY_RUN" = 1 ]; then log "DRY-RUN: backup $1"; return 0; fi
    cp -pP "$1" "$(backup_name "$1")"
  }
  if [ "$MIGRATE_ALL" = 1 ] && [ -n "$MIGRATE_CLIENTS" ]; then die "use either --all or client names, not both"; fi
  if [ "$MIGRATE_ALL" = 0 ] && [ -z "$MIGRATE_CLIENTS" ]; then _migrate_usage "$range" >&2; exit 2; fi
  [ "$DRY_RUN" = 1 ] && log "dry run: no changes will be made"
  if [ "$MIGRATE_ALL" = 1 ]; then
    check_client_root || die "cannot read CLIENT_ROOT"
    for d in "$CLIENT_ROOT"/*/; do
      d="${d%/}"
      [ -d "$d" ] && [ ! -L "$d" ] || continue
      n="$(basename "$d")"
      is_excluded "$n" && continue
      is_segregated "$d" || continue
      MIGRATE_CLIENTS="$MIGRATE_CLIENTS $n"
    done
  fi
  MIGRATE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/wsk-migrate.XXXXXX")"
  trap 'rm -rf "$MIGRATE_TMP"' EXIT
}

_migrate_usage() { sed -n "$1p" "$0" | sed 's/^# \{0,1\}//'; }

# migrate_require_flags <name=value>...: die unless each config flag has that value.
migrate_require_flags() {
  local kv
  for kv in "$@"; do
    [ "$(eval "printf '%s' \"\${${kv%%=*}:-}\"")" = "${kv#*=}" ] \
      || die "set ${kv} in $CONFIG_FILE first"
  done
}

# migrate_each <function>: run <function> <name> <dir> for every requested client.
migrate_each() {
  local fn="$1" c failed=""
  [ -n "$MIGRATE_CLIENTS" ] || { log "no segregated clients under $CLIENT_ROOT"; return 0; }
  for c in $MIGRATE_CLIENTS; do
    if migrate_resolve "$c"; then
      set_render_vars "$M_DIR" "$c"
      "$fn" "$c" "$M_DIR" || failed="$failed $c"
    else
      failed="$failed $c"
    fi
  done
  [ -z "$failed" ] || die "not migrated:$failed"
  [ "$DRY_RUN" = 1 ] || log "done. Leave and re-enter each client (or open a new terminal) so the shell loads the change."
}

# migrate_resolve <name>: validate an existing segregated client; sets M_DIR.
migrate_resolve() {
  local name="$1"
  M_DIR=""
  [[ "$name" =~ $CLIENT_NAME_RE ]] || { warn "skipping '$name': client names must match $CLIENT_NAME_RE"; return 1; }
  is_excluded "$name" && { warn "skipping '$name': excluded by EXCLUDE_DIRS"; return 1; }
  is_safe_path "$CLIENT_ROOT/$name" || { warn "skipping '$name': unsupported characters in path"; return 1; }
  [ -d "$CLIENT_ROOT/$name" ] && [ ! -L "$CLIENT_ROOT/$name" ] || { warn "skipping '$name': $CLIENT_ROOT/$name is not a directory"; return 1; }
  is_segregated "$CLIENT_ROOT/$name" || { warn "skipping '$name': not a segregated client (no .workstation or WORKSTATION_CLIENT .envrc)"; return 1; }
  M_DIR="$CLIENT_ROOT/$name"
}

# backup_name <file>: <file>.bak.<timestamp>[.<n>], never an existing name.
backup_name() {
  local base n=1
  base="$1.bak.$(date +%Y%m%d%H%M%S)"
  [ -e "$base" ] || [ -L "$base" ] || { printf '%s\n' "$base"; return; }
  while [ -e "$base.$n" ] || [ -L "$base.$n" ]; do n=$((n + 1)); done
  printf '%s\n' "$base.$n"
}

# GNU stat first: on Linux `stat -f` is a valid (filesystem) query and would not fail.
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

# check_no_links <dir> <rel>...: refuse redirected private paths.
check_no_links() {
  local dir="$1" p
  shift
  for p in "$@"; do
    if [ -L "$dir/$p" ]; then
      warn "$(basename "$dir"): $p is a symlink; fix it by hand (the kit refuses redirected private paths)"
      return 1
    fi
  done
}

# tighten_dirs <dir> <rel>...: existing private directories to mode 700.
tighten_dirs() {
  local dir="$1" p
  shift
  for p in "$@"; do
    if [ -d "$dir/$p" ] && [ "$(mode_of "$dir/$p")" != 700 ]; then run chmod 700 "$dir/$p"; fi
  done
}

# tighten_files <dir> <rel>...: existing private files to mode 600.
tighten_files() {
  local dir="$1" p
  shift
  for p in "$@"; do
    if [ -f "$dir/$p" ] && [ ! -L "$dir/$p" ] && [ "$(mode_of "$dir/$p")" != 600 ]; then run chmod 600 "$dir/$p"; fi
  done
}

# unset_if_stale <dest> <expected>: back up and delete dest unless it matches.
# Sets UNSET=1 when it removed (or, in a dry run, would remove) dest.
unset_if_stale() {
  local dest="$1" expected="$2"
  UNSET=0
  if [ -L "$dest" ]; then
    UNSET=1
    log "unset $dest (symlink, moved aside)"
    run mv "$dest" "$(backup_name "$dest")"
    return 0
  fi
  [ -e "$dest" ] || return 0
  if [ -f "$dest" ] && cmp -s "$expected" "$dest"; then return 0; fi
  UNSET=1
  log "unset $dest (differs from the current kit)"
  backup_file "$dest"
  run rm -rf "$dest"
}

# replace_fragment <template> <rel dest>: unset a stale shell fragment, then install it.
replace_fragment() {
  local tpl="$1" rel="$2" want="$MIGRATE_TMP/fragment.$$"
  render_template "$KIT_ROOT/templates/client/$tpl" > "$want"
  unset_if_stale "$R_DIR/$rel" "$want"
  if [ "$DRY_RUN" = 1 ] && [ "$UNSET" = 1 ]; then
    log "DRY-RUN: create $R_DIR/$rel"
  else
    _install_tpl "$tpl" "$rel" 644 || log "$R_CLIENT: $rel is current"
  fi
}

remove_file() { # remove_file <path>: back up and delete (rollback)
  if [ -e "$1" ] || [ -L "$1" ]; then
    backup_file "$1"
    run rm -f "$1"
    log "removed $1"
  fi
}

# --- .envrc --------------------------------------------------------------------
# Lines are matched after stripping indentation; <ere> selects the lines this
# migration owns (e.g. '^(export[[:space:]]+)?CLAUDE_CONFIG_DIR='). Commented
# copies are treated as owned too, so `# export X=...` from a disabled scaffold
# is replaced instead of left behind.

_envrc_owned() { # _envrc_owned <ere>: active owned lines of stdin, unindented
  awk -v ere="$1" '{ l=$0; sub(/^[ \t]+/, "", l); if (l !~ /^#/ && l ~ ere) print l }'
}

_envrc_write() { # _envrc_write <file> <new>: back up, show the diff, replace
  local f="$1" new="$2"
  ENVRC_CHANGED=1
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: update $f:"
    diff -u "$f" "$new" | sed -n '3,$p' | sed 's/^/    /' || true
    return 0
  fi
  backup_file "$f"
  cat "$new" > "$f"
  log "updated $f"
}

# envrc_apply <file> <id> <ere> <block file>: the owned lines must be exactly the
# block's (active, once each). Otherwise drop every owned line, active or commented,
# and the managed block <id>, then append the block. No change when already current.
envrc_apply() { # every block line must itself match <ere>
  local f="$1" id="$2" ere="$3" block="$4" new="$MIGRATE_TMP/envrc.$$"
  [ -f "$f" ] && [ ! -L "$f" ] || { warn "$f is missing or a symlink"; return 1; }
  if [ "$(_envrc_owned "$ere" < "$f" | sort)" = "$(_envrc_owned "$ere" < "$block" | sort)" ]; then
    return 0
  fi
  _block_strip "$f" "$id" | awk -v ere="$ere" '{
      l=$0; sub(/^[ \t]+/, "", l); sub(/^#[ \t]*/, "", l)
      if (l ~ ere) next; print }' > "$new"
  if [ -s "$new" ] && [ "$(tail -c1 "$new" | wc -l | tr -d ' ')" = 0 ]; then printf '\n' >> "$new"; fi
  { _block_begin "$id"; printf '\n'; cat "$block"; _block_end "$id"; printf '\n'; } >> "$new"
  _envrc_write "$f" "$new"
}

# envrc_remove <file> <id> <ere>: drop the managed block and active owned lines.
envrc_remove() {
  local f="$1" id="$2" ere="$3" new="$MIGRATE_TMP/envrc.$$"
  [ -f "$f" ] || return 0
  _block_strip "$f" "$id" | awk -v ere="$ere" '{
      l=$0; sub(/^[ \t]+/, "", l)
      if (l !~ /^#/ && l ~ ere) next; print }' > "$new"
  cmp -s "$new" "$f" || _envrc_write "$f" "$new"
}

# envrc_finish <dir>: re-approve only on --allow; a changed .envrc is otherwise blocked
# by direnv until the operator reviews it and runs `direnv allow`.
envrc_finish() {
  local dir="$1"
  [ "${ENVRC_CHANGED:-0}" = 1 ] || return 0
  ENVRC_CHANGED=0
  [ "$DRY_RUN" = 1 ] && return 0
  if [ "$MIGRATE_ALLOW" = 1 ]; then
    if PATH="$BIN_DIR:$PATH" direnv allow "$dir" >/dev/null 2>&1; then
      log "direnv allow: $dir"
    else
      warn "direnv allow failed for $dir; run it there yourself"
    fi
  else
    warn "$(basename "$dir"): .envrc changed (backup kept); review it, then run 'direnv allow' in $dir"
  fi
}

# report_exports <dir> <ere> <message>: warn about matches in .envrc or shell fragments.
report_exports() {
  local dir="$1" ere="$2" msg="$3" f
  for f in "$dir/.envrc" "$dir"/.workstation/bash/*.sh; do
    [ -f "$f" ] || continue
    grep -qE "$ere" "$f" 2>/dev/null && warn "$(basename "$dir"): $f $msg"
  done
  return 0
}
