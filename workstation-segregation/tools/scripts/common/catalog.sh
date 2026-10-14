#!/bin/bash
# Loads catalog/groups.tsv and catalog/tools.tsv into associative arrays.
CATALOG_DIR="${WST_CATALOG_DIR:-$WST_ROOT/scripts/common/catalog}"

declare -A G_DEPENDS=() T_DISPLAY=() T_GROUPS=() T_DEPENDS=() T_REL=() T_REMOVAL=() T_CHECKSUM=()
GROUP_IDS=()
TOOL_IDS=()

# Names that belong to the orchestrator, not to any group.
PREREQ_IDS="bash homebrew brew xcode-clt xcode-command-line-tools clt nvm node nodejs npm"

is_prereq() { local p; for p in $PREREQ_IDS; do [ "$p" = "$1" ] && return 0; done; return 1; }

catalog_load() {
  local id display groups depends rel removal checksum g
  GROUP_IDS=(); TOOL_IDS=()
  G_DEPENDS=(); T_DISPLAY=(); T_GROUPS=(); T_DEPENDS=(); T_REL=(); T_REMOVAL=(); T_CHECKSUM=()
  [ -f "$CATALOG_DIR/groups.tsv" ] || die "catalog missing: $CATALOG_DIR/groups.tsv"
  [ -f "$CATALOG_DIR/tools.tsv" ] || die "catalog missing: $CATALOG_DIR/tools.tsv"
  while IFS=$'\t' read -r g depends; do
    case "$g" in ''|'#'*) continue ;; esac
    [ "$depends" = - ] && depends=""
    GROUP_IDS+=("$g"); G_DEPENDS[$g]="${depends//,/ }"
  done < "$CATALOG_DIR/groups.tsv"
  while IFS=$'\t' read -r id display groups depends rel removal checksum; do
    case "$id" in ''|'#'*) continue ;; esac
    [ "$depends" = - ] && depends=""
    [ "$rel" = - ] && rel=""
    TOOL_IDS+=("$id")
    T_DISPLAY[$id]="$display"; T_GROUPS[$id]="${groups//,/ }"; T_DEPENDS[$id]="${depends//,/ }"
    T_REL[$id]="$rel"; T_REMOVAL[$id]="${removal:-normal}"; T_CHECKSUM[$id]="${checksum:-n/a}"
  done < "$CATALOG_DIR/tools.tsv"
}

is_group() { [ -n "${G_DEPENDS[$1]+x}" ]; }
is_tool() { [ -n "${T_DISPLAY[$1]+x}" ]; }

# Group whose script defines the tool's handlers: the first listed group, or
# base for implicit provider tools (groups "-").
tool_home_group() {
  local g="${T_GROUPS[$1]%% *}"
  case "$g" in ''|-) printf 'base\n' ;; *) printf '%s\n' "$g" ;; esac
}

# True when $1 (tool) has $2 (tool) as a dependency, directly.
tool_depends_on() { local d; for d in ${T_DEPENDS[$1]}; do [ "$d" = "$2" ] && return 0; done; return 1; }
