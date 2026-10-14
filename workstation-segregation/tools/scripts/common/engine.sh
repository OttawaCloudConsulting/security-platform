#!/bin/bash
# Execution: removals (reverse topological), installs (topological), validation,
# per-tool record writes, and the final report.
RINTEGRITY=""; RPATH=""; RPKG=""; RSRC=""
FAILED_COUNT=0

_result_get() { # _result_get <file> <key>
  local line
  while IFS= read -r line; do
    case "$line" in "$2="*) printf '%s\n' "${line#*=}"; return 0 ;; esac
  done < "$1"
  return 0
}

_dep_failed() { # first failed/blocked dependency of $1, or empty
  local d
  for d in ${T_DEPENDS[$1]}; do
    case "${RES[$d]:-}" in failed|blocked) printf '%s\n' "$d"; return 0 ;; esac
  done
  return 0
}

_fail_tool() { # _fail_tool <id> <message> [status-for-record]
  RES[$1]=failed; RES_MSG[$1]="$2"
  FAILED_COUNT=$((FAILED_COUNT + 1))
  warn "$1: $2"
  inst_mark "$1" "${3:-failed}"
}

# validate_tool <id> <action>: re-probe, run the tool's check, compare versions.
# Sets NEW_VER, NEW_PATH, NEW_PKG, NEW_SRC on success.
validate_tool() {
  local id="$1" p sys
  if is_follow "$id"; then
    p="${T_DEPENDS[$id]}"
    if fn_exists "$id" validate; then
      fn_call "$id" validate >/dev/null 2>&1 || { VALIDATE_MSG="validation command failed"; return 1; }
    else
      command -v "$id" >/dev/null 2>&1 || { VALIDATE_MSG="$id is not on PATH"; return 1; }
    fi
    NEW_VER[$id]="${NEW_VER[$p]:-}"
    NEW_PATH="$(command -v "$id" 2>/dev/null || true)"; NEW_PKG=""; NEW_SRC="${NEW_SRC_OF[$p]:-}"
    return 0
  fi
  probe_tool "$id"; probe_active "$id"
  if [ -z "$AV$AP" ]; then VALIDATE_MSG="not found after install"; return 1; fi
  if fn_exists "$id" validate; then
    fn_call "$id" validate >/dev/null 2>&1 || { VALIDATE_MSG="validation command failed"; return 1; }
  fi
  sys="$(cmp_system "$AS")"
  if [ "${KIND[$id]:-bin}" != os ] && ! ver_matches "$sys" "$AV" "${TARGET[$id]}"; then
    VALIDATE_MSG="observed version $AV does not match target ${TARGET[$id]}"; return 1
  fi
  NEW_VER[$id]="$AV"; NEW_PATH="$AP"; NEW_PKG="$AK"; NEW_SRC="$AS"
  NEW_SRC_OF[$id]="$AS"
  return 0
}
declare -A NEW_SRC_OF=()
NEW_PATH=""; NEW_PKG=""; NEW_SRC=""; VALIDATE_MSG=""

_run_install() { # in subshell: run the handler's install
  local id="$1" tgt="$2" result="$3"
  ( set -e; fn_call "$id" install "$tgt" "$result" )
}

install_one() {
  local id="$1" act="${ACTION[$1]}" dep owner integ rc msg
  dep="$(_dep_failed "$id")"
  if [ -n "$dep" ]; then
    RES[$id]=blocked; RES_MSG[$id]="blocked: dependency $dep did not complete"
    FAILED_COUNT=$((FAILED_COUNT + 1)); inst_mark "$id" stale; return 0
  fi
  case "$act" in
    fail|conflict|blocked)
      if [ "$act" = blocked ]; then RES[$id]=blocked; else RES[$id]=failed; fi
      RES_MSG[$id]="${REASON[$id]:-$act}"; FAILED_COUNT=$((FAILED_COUNT + 1))
      warn "$id: ${RES_MSG[$id]}"
      inst_mark "$id" stale
      return 0 ;;
  esac
  integ="${INTEGRITY[$id]:-}"
  if [ "$act" = install ] || [ "$act" = upgrade ] || [ "$act" = pin ]; then
    log "$act $id -> ${TARGET[$id]}"
    TOOL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/wst-tool.XXXXXX")"; export TOOL_TMP
    : > "$TOOL_TMP/result"
    trace "install $id ${TARGET[$id]}"
    set +e
    _run_install "$id" "${TARGET[$id]}" "$TOOL_TMP/result"
    rc=$?
    set -e
    wst_barrier after-install
    integ="$(_result_get "$TOOL_TMP/result" integrity)"
    rm -rf "$TOOL_TMP"
    if [ "$rc" != 0 ]; then _fail_tool "$id" "install failed (exit $rc)"; return 0; fi
    if [ "${T_CHECKSUM[$id]}" = yes ] && [ "$integ" != verified ]; then
      _fail_tool "$id" "integrity not verified (${integ:-no status reported})"; return 0
    fi
    [ -n "$integ" ] || integ="package-manager"
  fi
  if ! validate_tool "$id"; then _fail_tool "$id" "$VALIDATE_MSG"; return 0; fi
  case "$act" in
    install|upgrade|pin) owner=workstation-tools ;;
    follow) owner="$(inst_get "${T_DEPENDS[$id]}" owner)"; owner="${owner:-external}"
            integ="n/a" ;;
    *)
      owner=external
      if [ "$(inst_get "$id" owner)" = workstation-tools ] && [ "$(inst_get "$id" path)" = "$NEW_PATH" ]; then
        owner=workstation-tools
        integ="$(inst_get "$id" integrity)"
      fi
      [ -n "$integ" ] || integ="existing" ;;
  esac
  [ "${KIND[$id]:-bin}" = os ] && owner=external
  INTEGRITY[$id]="$integ"; OWNER[$id]="$owner"
  inst_record "$id" "${REQ[$id]}" "${LATEST[$id]:-}" "${TARGET[$id]}" "${NEW_VER[$id]}" \
    "$NEW_PATH" "$NEW_PKG" "$NEW_SRC" "$integ" "$owner" installed
  RES[$id]=ok
  case "$act" in install) msg=installed ;; upgrade) msg="upgraded from ${PREV[$id]}" ;; pin) msg="changed from ${PREV[$id]}" ;; *) msg=reused ;; esac
  RES_MSG[$id]="$msg"
}

run_installs() {
  local t
  for t in "${INSTALL_SET[@]}"; do install_one "$t"; done
}

# absent_after <id>: true when no probe line matches the installed record.
absent_after() {
  probe_tool "$1"
  ! probe_matches_record "$1"
}

_record_removed() {
  local id="$1"
  inst_record "$id" "${REQ[$id]}" "" "" "$(inst_get "$id" version)" "$(inst_get "$id" path)" \
    "$(inst_get "$id" package_id)" "$(inst_get "$id" source)" "$(inst_get "$id" integrity)" \
    "$(inst_get "$id" owner)" removed
}

remove_one() {
  local id="$1" rc
  case "${ACTION[$id]}" in
    absent)
      RES[$id]=absent; RES_MSG[$id]="already absent"
      [ -n "$(inst_get "$id" status)" ] && [ "$(inst_get "$id" status)" != removed ] && _record_removed "$id"
      return 0 ;;
    remove) ;;
    *) return 0 ;;
  esac
  if is_follow "$id"; then return 0; fi   # verified after its provider is gone
  log "remove $id"
  trace "remove $id"
  set +e
  ( set -e; fn_call "$id" remove )
  rc=$?
  set -e
  if [ "$rc" != 0 ]; then _fail_tool "$id" "removal failed (exit $rc)"; return 0; fi
  if absent_after "$id"; then
    _record_removed "$id"; RES[$id]=removed; RES_MSG[$id]="removed"
  else
    _fail_tool "$id" "still present after removal (partial removal)"
  fi
}

run_removals() {
  local i id
  for ((i = ${#REMOVE_SET[@]} - 1; i >= 0; i--)); do remove_one "${REMOVE_SET[$i]}"; done
  # bundled commands leave with their provider: verify afterwards
  for id in "${REMOVE_SET[@]}"; do
    is_follow "$id" && [ "${ACTION[$id]}" = remove ] || continue
    probe_tool "$id"; probe_active "$id"
    if [ -z "$AV$AP" ]; then
      [ -n "$(inst_get "$id" status)" ] && _record_removed "$id"
      RES[$id]=removed; RES_MSG[$id]="removed with provider"
    else
      _fail_tool "$id" "still present after its provider was removed"
    fi
  done
}

report() {
  local t integ res
  printf '\n== Summary ==\n'
  [ -n "${WST_PREREQ_REPORT:-}" ] && printf 'Prerequisites:\n%s\n' "$WST_PREREQ_REPORT"
  printf '%-26s %-10s %-14s %-14s %-14s %-16s %s\n' TOOL REQUESTED LATEST PREVIOUS TARGET INTEGRITY RESULT
  for t in "${INSTALL_SET[@]}" "${REMOVE_SET[@]}"; do
    integ="${INTEGRITY[$t]:--}"; res="${RES[$t]:-skipped}"
    printf '%-26s %-10s %-14s %-14s %-14s %-16s %s%s\n' "$t" "${REQ[$t]:-latest}" "${LATEST[$t]:--}" \
      "${PREV[$t]:--}" "${TARGET[$t]:--}" "$integ" "$res" "${RES_MSG[$t]:+ ($(printf '%s' "${RES_MSG[$t]}" | cut -c1-100))}"
  done
  for t in "${REDUCED_GROUPS[@]}"; do
    printf 'reduced by request: %s (groups: %s)\n' "${t%%:*}" "${t#*:}"
  done
  for t in "${INSTALL_SET[@]}"; do
    [ "${RES[$t]:-}" = blocked ] && printf 'blocked: %s -- %s\n' "$t" "${RES_MSG[$t]}"
  done
  if [ "$FAILED_COUNT" -gt 0 ]; then printf '%s tool(s) failed or were blocked.\n' "$FAILED_COUNT"; fi
}
