#!/bin/bash
# Planning: handler loading, discovery, probing, classification, removal rules.
# Actions: reuse install upgrade pin follow remove absent | fail conflict reject blocked
declare -A LATEST=() TARGET=() DISC_FAIL=() PROBE=() ACTION=() REASON=() RES=() RES_MSG=()
declare -A INTEGRITY=() OWNER=() PREV=() NEW_VER=() KIND=() MSRC=() LOADED_GROUPS=()
PLAN_ERRORS=()
INSTALL_SET=()    # topological
REMOVE_SET=()     # topological (installs order); executed reversed
REDUCED_GROUPS=() # "tool: groups"

trace() { [ -n "${WST_TRACE_FILE:-}" ] && printf '%s\n' "$*" >> "$WST_TRACE_FILE"; return 0; }

# ---- handlers ----------------------------------------------------------------
load_group_script() {
  local g="$1" f
  [ -n "${LOADED_GROUPS[$g]+x}" ] && return 0
  f="${WST_PLATFORM_DIR:-$WST_ROOT/scripts/$WST_OS}/groups/$g.sh"
  [ -f "$f" ] || die "no $WST_OS installer script for group '$g' (not implemented yet): $f"
  # shellcheck source=/dev/null
  . "$f"
  LOADED_GROUPS[$g]=1
}

# Resolved groups plus the home group of every removal-flagged tool.
load_handlers() {
  local g t
  for g in "${RESOLVED_GROUPS[@]}"; do load_group_script "$g"; done
  for t in "${!REQ[@]}"; do
    is_removal "$t" && load_group_script "$(tool_home_group "$t")"
  done
  return 0
}

is_follow() { # bundled command without its own handlers follows its provider
  [ "${T_REL[$1]}" = bundled ] && ! fn_exists "$1" latest
}

tool_kind() { if fn_exists "$1" kind; then fn_call "$1" kind; else echo bin; fi; }
tool_msrc() { if fn_exists "$1" source; then fn_call "$1" source; else echo ""; fi; }

# system label for version comparison: apt, brew, or release (sort -V)
cmp_system() { case "$1" in apt|brew|os) echo "$1" ;; *) echo release ;; esac; }

# ---- probes -------------------------------------------------------------------
probe_tool() { # fills PROBE[id]
  trace "probe $1"
  PROBE[$1]="$(fn_call "$1" probe 2>/dev/null || true)"
}

# probe_split <line>: version<TAB>path<TAB>source<TAB>package_id; "-" is empty.
probe_split() {
  IFS=$'\t' read -r AV AP AS AK <<< "$1"
  [ "$AV" = - ] && AV=""; [ "$AP" = - ] && AP=""; [ "$AS" = - ] && AS=""; [ "$AK" = - ] && AK=""
  return 0
}

# probe_active <id>: sets AV AP AS AK from the first probe line
probe_active() {
  local line="${PROBE[$1]%%$'\n'*}"
  AV=""; AP=""; AS=""; AK=""
  [ -n "${PROBE[$1]}" ] && probe_split "$line"
  return 0
}

# probe_has_record <id>: does any probe line match the installed record?
probe_matches_record() {
  local id="$1" rpath rpkg line
  rpath="$(inst_get "$id" path)"; rpkg="$(inst_get "$id" package_id)"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    probe_split "$line"
    if [ -n "$rpath" ] && [ "$AP" = "$rpath" ]; then return 0; fi
    if [ -z "$rpath" ] && [ -n "$rpkg" ] && [ "$AK" = "$rpkg" ]; then return 0; fi
  done <<< "${PROBE[$id]}"
  return 1
}

# ---- removal rules --------------------------------------------------------------
REMOVAL_ACCEPTED=()
# removal_check_static: rules 1-5, collecting every rejection.
removal_check_static() {
  local t x remaining=" " dep msg
  REMOVAL_ACCEPTED=()
  for x in "${SELECTED_TOOLS[@]}"; do is_removal "$x" || remaining="$remaining$x "; done
  for t in "${TOOL_IDS[@]}"; do
    is_removal "$t" || continue
    # 1/2: unknown identifiers and prerequisites are rejected when the file loads.
    if [ "${T_REMOVAL[$t]}" = never ]; then
      PLAN_ERRORS+=("$t: removal rejected: ${T_DISPLAY[$t]} is never removed by this installer (jq, yq, direnv, starship and the installer's own runtime tools are never removed)")
      continue
    fi
    if [ "${T_REMOVAL[$t]}" = base ] && [ "$ALLOW_BASE_REMOVAL" != 1 ]; then
      PLAN_ERRORS+=("$t: removal rejected: $t is a base tool; rerun with --allow-base-removal (required on every run)")
      continue
    fi
    msg=""
    if [ "${T_REL[$t]}" = bundled ]; then
      dep="${T_DEPENDS[$t]}"
      case "$remaining" in *" $dep "*) msg="$t is a bundled command of $dep, which remains selected" ;; esac
    fi
    for x in $remaining; do
      if tool_depends_on "$x" "$t"; then msg="$t is required by $x (${T_REL[$x]}), which remains selected"; break; fi
    done
    if [ -n "$msg" ]; then PLAN_ERRORS+=("$t: removal rejected: $msg"); continue; fi
    REMOVAL_ACCEPTED+=("$t")
  done
  tools_topo_sort "${REMOVAL_ACCEPTED[@]}"
  REMOVE_SET=()
  for t in "${_TOPO[@]}"; do is_removal "$t" && REMOVE_SET+=("$t"); done
  return 0
}

# reduced groups: accepted removals that belong to a resolved group
removal_reduced_groups() {
  local t g out
  REDUCED_GROUPS=()
  for t in "${REMOVE_SET[@]}"; do
    out=""
    for g in "${RESOLVED_GROUPS[@]}"; do
      case " ${T_GROUPS[$t]} " in *" $g "*) out="$out $g" ;; esac
    done
    [ -n "$out" ] && REDUCED_GROUPS+=("$t:${out# }")
  done
  return 0
}

# ---- discovery -------------------------------------------------------------------
discover_all() {
  local t out
  for t in "${INSTALL_SET[@]}"; do
    is_follow "$t" && continue
    if ! fn_exists "$t" latest; then
      DISC_FAIL[$t]="no installer defined for $t on $WST_OS"; continue
    fi
    trace "latest $t"
    if out="$(fn_call "$t" latest 2>&1)" && [ -n "$out" ]; then
      LATEST[$t]="${out##*$'\n'}"
    else
      DISC_FAIL[$t]="latest-version discovery failed: ${out##*$'\n'}"
    fi
  done
  return 0
}

# ---- classification -----------------------------------------------------------------
classify_install() {
  local id="$1" req="${REQ[$1]}" tgt kind msrc sys managed cmp
  if is_follow "$id"; then
    ACTION[$id]=follow; return 0
  fi
  if [ -n "${DISC_FAIL[$id]+x}" ]; then
    ACTION[$id]=fail; REASON[$id]="${DISC_FAIL[$id]}"; return 0
  fi
  kind="$(tool_kind "$id")"; KIND[$id]="$kind"; msrc="$(tool_msrc "$id")"; MSRC[$id]="$msrc"
  if [ "$req" = latest ]; then tgt="${LATEST[$id]}"; else tgt="$req"; fi
  TARGET[$id]="$tgt"
  if [ "$req" != latest ] && fn_exists "$id" pin_ok; then
    if ! fn_call "$id" pin_ok "$req" >/dev/null 2>&1; then
      ACTION[$id]=fail; REASON[$id]="pinned version $req is unavailable from this source"; return 0
    fi
  fi
  probe_tool "$id"
  probe_active "$id"
  PREV[$id]="$AV"
  if [ -z "$AV" ] && [ -z "$AP" ]; then
    if [ "$kind" = os ]; then
      ACTION[$id]=fail; REASON[$id]="platform-provided tool not found"
    else
      ACTION[$id]=install
    fi
    return 0
  fi
  if [ "$kind" = os ]; then
    if [ "$req" != latest ]; then
      ACTION[$id]=fail; REASON[$id]="platform-provided by the OS; pins are not supported"
    else
      TARGET[$id]="$AV"; ACTION[$id]=reuse
    fi
    return 0
  fi
  sys="$(cmp_system "$AS")"
  managed=0
  { [ -z "$msrc" ] || [ "$AS" = "$msrc" ]; } && managed=1
  if ver_matches "$sys" "$AV" "$tgt"; then
    ACTION[$id]=reuse; return 0
  fi
  if [ "$managed" = 1 ]; then
    cmp="$(ver_cmp "$sys" "$AV" "$tgt")"
    if [ "$req" = latest ] && [ "$cmp" = lt ]; then ACTION[$id]=upgrade; else ACTION[$id]=pin; fi
    return 0
  fi
  ACTION[$id]=conflict
  REASON[$id]="$id $AV is active at $AP (source: $AS), not at the managed location; remove it manually, then rerun to let the installer manage it"
}

propagate_blocked() {
  local t d bad
  for t in "${INSTALL_SET[@]}"; do
    bad=""
    for d in ${T_DEPENDS[$t]}; do
      case "${ACTION[$d]:-}" in fail|conflict|reject|blocked) bad="$d"; break ;; esac
    done
    if [ -n "$bad" ]; then
      case "${ACTION[$t]:-}" in fail|conflict|reject|blocked) ;; *)
        ACTION[$t]=blocked; REASON[$t]="blocked: dependency $bad did not complete" ;;
      esac
    fi
  done
  return 0
}

# classify_removal <id>: rule 6, ownership
classify_removal() {
  local id="$1" owner status msrc
  probe_tool "$id"; probe_active "$id"
  PREV[$id]="$AV"
  if is_follow "$id"; then
    # bundled command: removed together with its provider
    if [ -z "$AV$AP" ]; then ACTION[$id]=absent; else ACTION[$id]=remove; fi
    return 0
  fi
  if [ -z "$AV$AP" ]; then ACTION[$id]=absent; return 0; fi
  owner="$(inst_get "$id" owner)"; status="$(inst_get "$id" status)"
  msrc="$(tool_msrc "$id")"
  if [ "$owner" = workstation-tools ] && [ "$status" != removed ] && probe_matches_record "$id"; then
    ACTION[$id]=remove; return 0
  fi
  ACTION[$id]=reject
  PLAN_ERRORS+=("$id: removal rejected: the $id found at ${AP:-$AK} (source: ${AS:-unknown}) was not installed by this installer; remove ${AP:-$AK} manually, then rerun to let the installer manage it")
}

# plan_build: discovery, probes and classification. Fills PLAN_ERRORS.
plan_build() {
  local t
  INSTALL_SET=()
  for t in "${SELECTED_TOOLS[@]}"; do is_removal "$t" || INSTALL_SET+=("$t"); done
  discover_all
  for t in "${INSTALL_SET[@]}"; do classify_install "$t"; done
  # follow tools take the provider's numbers
  for t in "${INSTALL_SET[@]}"; do
    if [ "${ACTION[$t]}" = follow ]; then
      local p="${T_DEPENDS[$t]}"
      LATEST[$t]="${LATEST[$p]:-}"; TARGET[$t]="${TARGET[$p]:-}"; PREV[$t]="${PREV[$p]:-}"
      [ -n "${DISC_FAIL[$p]+x}" ] && ACTION[$t]=blocked
    fi
  done
  propagate_blocked
  for t in "${REMOVE_SET[@]}"; do classify_removal "$t"; done
  return 0
}

has_removals() { local t; for t in "${REMOVE_SET[@]}"; do [ "${ACTION[$t]:-}" = remove ] && return 0; done; return 1; }

plan_print() {
  local t
  printf '\n%-26s %-10s %-14s %-14s %-14s %s\n' TOOL REQUESTED LATEST INSTALLED TARGET ACTION
  for t in "${INSTALL_SET[@]}" "${REMOVE_SET[@]}"; do
    printf '%-26s %-10s %-14s %-14s %-14s %s%s\n' "$t" "${REQ[$t]:-latest}" "${LATEST[$t]:--}" \
      "${PREV[$t]:--}" "${TARGET[$t]:--}" "${ACTION[$t]:-?}" "${REASON[$t]:+  ($(printf '%s' "${REASON[$t]}" | cut -c1-90))}"
  done
  for t in "${REDUCED_GROUPS[@]}"; do
    printf 'reduced by request: %s (groups: %s)\n' "${t%%:*}" "${t#*:}"
  done
  printf '\n'
}
