#!/bin/bash
# Argument and .env parsing. .env is data: only TOOL_GROUPS is read and values
# are never echoed.
ENV_FILE=""; ENV_FILE_EXPLICIT=0
GROUPS_ARG=""; GROUPS_ARG_SET=0
REQUESTED_FILE=""; INSTALLED_FILE=""
TOOL_VERSION_ARGS=()
ALLOW_BASE_REMOVAL=0
ENV_GROUPS=""

config_usage() {
  cat <<'USAGE'
Usage: setup-workstation.sh [options]
  --env-file PATH          project .env (default: ./.env); reads TOOL_GROUPS only
  --groups LIST            comma-separated groups; replaces the .env selection
  --requested-file PATH    requested versions (default: ./.workstation-tools-requested.json)
  --installed-file PATH    installed record (default: ~/.workstation-tools-installed.json)
  --tool-version TOOL=VER  pin a selected tool (repeatable)
  --allow-base-removal     honor removal flags on base tools (this run only)
  --dry-run                print the plan; change nothing
  --yes                    confirm removals non-interactively
  -h, --help               this help
Exit: 0 ok, 1 failure, 2 usage, 75 restart needed (new terminal)
USAGE
}

config_parse_args() {
  local need
  while [ $# -gt 0 ]; do
    need() { [ $# -ge 2 ] || usage_die "$1 needs a value"; }
    case "$1" in
      --env-file) need "$@"; ENV_FILE="$2"; ENV_FILE_EXPLICIT=1; shift 2 ;;
      --env-file=*) ENV_FILE="${1#*=}"; ENV_FILE_EXPLICIT=1; shift ;;
      --groups) need "$@"; GROUPS_ARG="$2"; GROUPS_ARG_SET=1; shift 2 ;;
      --groups=*) GROUPS_ARG="${1#*=}"; GROUPS_ARG_SET=1; shift ;;
      --requested-file) need "$@"; REQUESTED_FILE="$2"; shift 2 ;;
      --requested-file=*) REQUESTED_FILE="${1#*=}"; shift ;;
      --installed-file) need "$@"; INSTALLED_FILE="$2"; shift 2 ;;
      --installed-file=*) INSTALLED_FILE="${1#*=}"; shift ;;
      --tool-version) need "$@"; TOOL_VERSION_ARGS+=("$2"); shift 2 ;;
      --tool-version=*) TOOL_VERSION_ARGS+=("${1#*=}"); shift ;;
      --allow-base-removal) ALLOW_BASE_REMOVAL=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --yes|-y) ASSUME_YES=1; shift ;;
      -h|--help) config_usage; exit 0 ;;
      *) usage_die "unknown argument: $1" ;;
    esac
  done
  : "${WST_PROJECT_DIR:=$PWD}"
  [ -n "$ENV_FILE" ] || ENV_FILE="$WST_PROJECT_DIR/.env"
  [ -n "$REQUESTED_FILE" ] || REQUESTED_FILE="$WST_PROJECT_DIR/.workstation-tools-requested.json"
  [ -n "$INSTALLED_FILE" ] || INSTALLED_FILE="$HOME/.workstation-tools-installed.json"
}

# config_read_env: sets ENV_GROUPS from TOOL_GROUPS= (data parse, no sourcing).
config_read_env() {
  local line key val
  ENV_GROUPS=""
  if [ ! -r "$ENV_FILE" ]; then
    [ "$ENV_FILE_EXPLICIT" = 1 ] && die "cannot read env file: $ENV_FILE"
    return 0
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in ''|'#'*) continue ;; esac
    line="${line#export }"; line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in *=*) ;; *) continue ;; esac
    key="${line%%=*}"; val="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"
    [ "$key" = TOOL_GROUPS ] || continue
    val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
    case "$val" in
      \"*\") val="${val#\"}"; val="${val%\"}" ;;
      \'*\') val="${val#\'}"; val="${val%\'}" ;;
      *) val="${val%%[[:space:]]#*}"; val="${val%"${val##*[![:space:]]}"}" ;;
    esac
    ENV_GROUPS="$val"
  done < "$ENV_FILE"
}

config_select_groups() {
  config_read_env
  if [ "$GROUPS_ARG_SET" = 1 ]; then groups_parse "$GROUPS_ARG"; else groups_parse "$ENV_GROUPS"; fi
  groups_resolve
  tools_select
}
