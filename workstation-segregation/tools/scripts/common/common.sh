#!/bin/bash
# Engine common helpers (Bash 5). Logging, run, lock and barrier helpers are
# shared with the orchestrator.
: "${WST_ROOT:?WST_ROOT must be set}"
# shellcheck source=../orchestrator/common.sh
. "$WST_ROOT/scripts/orchestrator/common.sh"

now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# bin_dir: where managed release binaries live.
bin_dir() { printf '%s\n' "${WST_BIN_DIR:-$HOME/.local/bin}"; }

# Handler function name for a tool id: kubectx-foo -> tool_kubectx_foo_<suffix>
fn_name() { local id="${1//-/_}"; printf 'tool_%s_%s\n' "$id" "$2"; }
fn_exists() { declare -F "$(fn_name "$1" "$2")" >/dev/null; }
fn_call() { local id="$1" suffix="$2"; shift 2; "$(fn_name "$id" "$suffix")" "$@"; }
