#!/bin/bash
# Group resolution and tool ordering.
RESOLVED_GROUPS=()
SELECTED_TOOLS=()

# groups_parse "a, b,a" -> REQUESTED_GROUPS (deduplicated; unknown ids rejected)
REQUESTED_GROUPS=()
groups_parse() {
  local raw="$1" g seen=" "
  REQUESTED_GROUPS=()
  IFS=',' read -r -a parts <<< "$raw"
  for g in "${parts[@]}"; do
    g="${g#"${g%%[![:space:]]*}"}"; g="${g%"${g##*[![:space:]]}"}"
    [ -z "$g" ] && continue
    is_group "$g" || usage_die "unknown group: $g"
    case "$seen" in *" $g "*) continue ;; esac
    seen="$seen$g "; REQUESTED_GROUPS+=("$g")
  done
}

declare -A _GSTATE=()
_group_visit() {
  local g="$1" d
  case "${_GSTATE[$g]:-}" in
    done) return 0 ;;
    visiting) usage_die "group dependency cycle at: $g" ;;
  esac
  _GSTATE[$g]=visiting
  for d in ${G_DEPENDS[$g]}; do
    is_group "$d" || usage_die "group $g depends on unknown group: $d"
    _group_visit "$d"
  done
  _GSTATE[$g]="done"
  RESOLVED_GROUPS+=("$g")
}

# groups_resolve: base plus REQUESTED_GROUPS plus dependencies, topological.
groups_resolve() {
  local g
  RESOLVED_GROUPS=(); _GSTATE=()
  _group_visit base
  for g in "${REQUESTED_GROUPS[@]}"; do _group_visit "$g"; done
}

declare -A _TSTATE=()
_TOPO=()
_tool_visit() {
  local t="$1" d
  case "${_TSTATE[$t]:-}" in
    done) return 0 ;;
    visiting) die "tool dependency cycle at: $t" ;;
  esac
  _TSTATE[$t]=visiting
  for d in ${T_DEPENDS[$t]}; do
    is_tool "$d" || die "tool $t depends on unknown tool: $d"
    _tool_visit "$d"
  done
  _TSTATE[$t]="done"
  _TOPO+=("$t")
}

# tools_topo_sort id...: result in _TOPO, dependencies first, with dependencies
# that were not listed pulled in.
tools_topo_sort() {
  local t
  _TOPO=(); _TSTATE=()
  for t in "$@"; do _tool_visit "$t"; done
}

# tools_select: SELECTED_TOOLS = tools of every resolved group + their
# tool-level dependencies, dependencies first.
tools_select() {
  local t g want=()
  for t in "${TOOL_IDS[@]}"; do
    for g in "${RESOLVED_GROUPS[@]}"; do
      case " ${T_GROUPS[$t]} " in *" $g "*) want+=("$t"); break ;; esac
    done
  done
  tools_topo_sort "${want[@]}"
  SELECTED_TOOLS=("${_TOPO[@]}")
}
