#!/bin/bash
# Requested and installed JSON dotfiles. All reads/writes use $WST_JQ; writes go
# to a temp file in the same directory followed by mv. The caller holds the run
# lock, so every read-modify-write is serialized.
declare -A REQ=()
REQ_ERRORS=()
INST_STATUS_OK="installed"

state_init() {
  : "${WST_JQ:=$(command -v jq || true)}"
  [ -n "$WST_JQ" ] && [ -x "$WST_JQ" ] || die "private jq not available (WST_JQ)"
}

_atomic_write() { # _atomic_write <dest> (content on stdin)
  local dest="$1" tmp
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp "$dest.tmp.XXXXXX")"
  if cat > "$tmp"; then
    wst_barrier state-before-rename
    mv -f "$tmp" "$dest"
    wst_barrier state-after-rename
  else
    rm -f "$tmp"; return 1
  fi
}

# req_load: parse and validate the requested file. Errors are collected in
# REQ_ERRORS; nothing is changed on disk.
req_load() {
  local id val
  REQ=(); REQ_ERRORS=()
  [ -f "$REQUESTED_FILE" ] || return 0
  if ! "$WST_JQ" -e '.schema_version == 1 and (.tools | type == "object") and ([.tools[] | type == "string"] | all)' \
        "$REQUESTED_FILE" >/dev/null 2>&1; then
    REQ_ERRORS+=("$REQUESTED_FILE: invalid format (need schema_version 1 and a tools object of strings)")
    return 1
  fi
  while IFS=$'\t' read -r id val; do
    [ -n "$id" ] || continue
    if is_prereq "$id"; then
      REQ_ERRORS+=("$id: orchestrator prerequisites cannot appear in the requested file")
      continue
    fi
    if ! is_tool "$id"; then REQ_ERRORS+=("$id: unknown tool identifier"); continue; fi
    case "$val" in
      latest|remove|delete) ;;
      *) ver_valid_syntax "$val" || { REQ_ERRORS+=("$id: invalid requested version '$val'"); continue; } ;;
    esac
    REQ[$id]="$val"
  done < <("$WST_JQ" -r '.tools | to_entries[] | [.key, .value] | @tsv' "$REQUESTED_FILE")
  [ ${#REQ_ERRORS[@]} -eq 0 ]
}

is_removal() { case "${REQ[$1]:-}" in remove|delete) return 0 ;; *) return 1 ;; esac; }

# req_apply: add selected tools missing from REQ as latest, apply --tool-version
# overrides, and check pin conflicts. Collects errors; the caller persists only
# when none were found.
req_apply() {
  local t kv id ver sel=" " p
  for t in "${SELECTED_TOOLS[@]}"; do sel="$sel$t "; done
  for kv in "${TOOL_VERSION_ARGS[@]}"; do
    case "$kv" in *=*) ;; *) REQ_ERRORS+=("--tool-version expects TOOL=VERSION: $kv"); continue ;; esac
    id="${kv%%=*}"; ver="${kv#*=}"
    if is_prereq "$id"; then REQ_ERRORS+=("$id: orchestrator prerequisites cannot be pinned"); continue; fi
    if ! is_tool "$id"; then REQ_ERRORS+=("--tool-version: unknown tool $id"); continue; fi
    case "$sel" in *" $id "*) ;; *) REQ_ERRORS+=("--tool-version: $id is not in the selected groups"); continue ;; esac
    if is_removal "$id"; then REQ_ERRORS+=("--tool-version $kv conflicts with the removal flag for $id in $REQUESTED_FILE"); continue; fi
    case "$ver" in
      latest) ;;
      remove|delete) REQ_ERRORS+=("--tool-version cannot request removal for $id; edit $REQUESTED_FILE"); continue ;;
      *) ver_valid_syntax "$ver" || { REQ_ERRORS+=("$id: invalid version '$ver'"); continue; } ;;
    esac
    REQ[$id]="$ver"
  done
  for t in "${SELECTED_TOOLS[@]}"; do
    [ -n "${REQ[$t]+x}" ] || REQ[$t]=latest
  done
  # A bundled command follows its provider: it cannot carry its own pin.
  for t in "${!REQ[@]}"; do
    case "${REQ[$t]}" in latest|remove|delete) continue ;; esac
    if [ "${T_REL[$t]}" = bundled ]; then
      p="${T_DEPENDS[$t]}"
      REQ_ERRORS+=("$t is a bundled command of $p; pin $p instead of $t")
    fi
  done
  [ ${#REQ_ERRORS[@]} -eq 0 ]
}

req_write() {
  local t
  [ "$DRY_RUN" = 1 ] && return 0
  for t in $(printf '%s\n' "${!REQ[@]}" | sort); do
    printf '%s\t%s\n' "$t" "${REQ[$t]}"
  done | "$WST_JQ" -Rn -S '[inputs | split("\t") | {(.[0]): .[1]}] | add // {} | {schema_version: 1, tools: .}' \
    | _atomic_write "$REQUESTED_FILE"
}

# ---- installed record -----------------------------------------------------
inst_valid() {
  [ ! -f "$INSTALLED_FILE" ] && return 0
  "$WST_JQ" -e '.schema_version == 1 and (.tools | type == "object")' "$INSTALLED_FILE" >/dev/null 2>&1
}

inst_get() { # inst_get <id> <field> -> value or empty
  [ -f "$INSTALLED_FILE" ] || return 0
  "$WST_JQ" -r --arg id "$1" --arg f "$2" '.tools[$id][$f] // empty' "$INSTALLED_FILE" 2>/dev/null || true
}

_inst_update() { # _inst_update <jq filter> [jq args...]
  local filter="$1" cur
  shift
  [ "$DRY_RUN" = 1 ] && return 0
  if [ -f "$INSTALLED_FILE" ]; then cur="$INSTALLED_FILE"; else cur=/dev/null; fi
  if [ "$cur" = /dev/null ]; then
    printf '{"schema_version":1,"tools":{}}' | "$WST_JQ" -S "$@" "$filter" | _atomic_write "$INSTALLED_FILE"
  else
    "$WST_JQ" -S "$@" "$filter" "$cur" | _atomic_write "$INSTALLED_FILE"
  fi
}

# inst_record <id> <requested> <latest> <target> <version> <path> <package_id>
#             <source> <integrity> <owner> <status>
inst_record() {
  _inst_update '.tools[$id] = {requested:$req, latest:$lat, target:$tgt, version:$ver, path:$path,
      package_id:$pkg, source:$src, integrity:$int, owner:$own, status:$st,
      os:$os, arch:$arch, verified_at:$ts}' \
    --arg id "$1" --arg req "$2" --arg lat "$3" --arg tgt "$4" --arg ver "$5" --arg path "$6" \
    --arg pkg "$7" --arg src "$8" --arg int "$9" --arg own "${10}" --arg st "${11}" \
    --arg os "$WST_OS" --arg arch "$WST_ARCH" --arg ts "$(now_utc)"
}

# inst_mark <id> <status>: change the status of an existing record only.
inst_mark() {
  [ -n "$(inst_get "$1" status)" ] || return 0
  _inst_update '.tools[$id].status = $st' --arg id "$1" --arg st "$2"
}
