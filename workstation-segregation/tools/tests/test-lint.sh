#!/bin/bash
# bash -n, shellcheck, and the Bash 3.2 forbidden-construct grep (DEVELOPER-GUIDE).
. "$(dirname "$0")/helpers.sh"
cd "$TOOLS_DIR" || exit 1
files="$(find setup-workstation.sh scripts tests -name '*.sh' -type f | sort)"

for f in $files; do
  if "$BASH5" -n "$f" 2>/dev/null; then ok; else fail "syntax: $f"; fi
done

if command -v shellcheck >/dev/null 2>&1; then
  # shellcheck disable=SC2086
  out="$(shellcheck -P SCRIPTDIR -S warning -s bash -x -e SC2034,SC2154,SC2016,SC2004,SC1091,SC2155 $files 2>&1)" \
    && ok || fail "shellcheck:
$out"
else
  printf 'SKIP: shellcheck not installed\n'
fi

# Orchestrator files (and the two engine libs it sources) must stay Bash 3.2-safe.
bad="$(grep -nE 'declare -A|declare -n|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|\[\[ -v |\|&|&>>|local -n|globstar' \
  setup-workstation.sh scripts/orchestrator/*.sh scripts/common/versions.sh scripts/common/download.sh \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)"
if [ -z "$bad" ]; then ok; else fail "Bash 3.2-forbidden construct:
$bad"; fi
finish
