#!/bin/bash
# Test helpers: assertions, disposable HOME, fake-platform runs.
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TOOLS_DIR="$(cd "$TESTS_DIR/.." && pwd -P)"
BASH5="$(command -v bash)"
case "$("$BASH5" -c 'echo ${BASH_VERSINFO[0]}')" in 5|6|7) ;; *)
  for c in /opt/homebrew/bin/bash /usr/local/bin/bash /bin/bash; do
    [ -x "$c" ] && [ "$("$c" -c 'echo ${BASH_VERSINFO[0]}')" -ge 5 ] && BASH5="$c" && break
  done ;;
esac
JQ="${WST_JQ:-$(command -v jq)}"
PASS=0; FAIL=0

fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }
ok()   { PASS=$((PASS + 1)); }
assert_eq() { if [ "$1" = "$2" ]; then ok; else fail "$3: expected '$2' got '$1'"; fi; }
assert_contains() { case "$1" in *"$2"*) ok ;; *) fail "$3: output lacks '$2'" ;; esac; }
assert_not_contains() { case "$1" in *"$2"*) fail "$3: output has '$2'" ;; *) ok ;; esac; }
assert_file() { if [ -e "$1" ]; then ok; else fail "missing file: $1"; fi; }
assert_no_file() { if [ ! -e "$1" ]; then ok; else fail "unexpected file: $1"; fi; }
assert_rc() { if [ "$1" = "$2" ]; then ok; else fail "$3: exit $1, expected $2"; fi; }

new_fixture() { # sets FX, HOME and the fake world
  FX="$(mktemp -d "${TMPDIR:-/tmp}/wst-test.XXXXXX")"
  mkdir -p "$FX/home" "$FX/project" "$FX/world/latest" "$FX/world/installed" "$FX/bin"
  FAKE_BIN="$FX/bin"
  export HOME="$FX/home" XDG_STATE_HOME="$FX/home/state" FAKE_WORLD="$FX/world" FAKE_BIN
  export WST_TRACE_FILE="$FX/trace"
  : > "$WST_TRACE_FILE"
  unset WST_TEST_ABORT_AT WST_LOCK
}
cleanup_fixture() { [ -n "${FX:-}" ] && rm -rf "$FX"; }

# set_latest id version ; set_installed id version [source]
set_latest() { printf '%s\n' "$2" > "$FX/world/latest/$1"; }
set_installed() { mkdir -p "$FX/world/installed"; printf '%s\t%s\t%s\t-\n' "$2" "${4:-$FX/bin/$1}" "${3:-release}" > "$FX/world/installed/$1"; }
flag() { mkdir -p "$FX/world/$1"; : > "$FX/world/$1/$2"; }
set_latest_all() { # every catalog tool gets latest 1.0.0
  local id
  while IFS=$'\t' read -r id _; do
    case "$id" in ''|'#'*) continue ;; esac
    set_latest "$id" 1.0.0
  done < "$TOOLS_DIR/scripts/common/catalog/tools.tsv"
}

# run_engine [args...]: drives main.sh against the fake platform. Output in $OUT, rc in $RC.
run_engine() {
  set +e
  OUT="$(cd "$FX/project" && env WST_ROOT="$TOOLS_DIR" WST_JQ="$JQ" WST_OS=ubuntu WST_ARCH=amd64 \
    WST_PLATFORM_DIR="$TESTS_DIR/fixtures/platform-fake" WST_CATALOG_DIR="${WST_CATALOG_DIR:-$TOOLS_DIR/scripts/common/catalog}" \
    WST_PROJECT_DIR="$FX/project" ASSUME_YES="${ASSUME_YES:-0}" \
    "$BASH5" "$TOOLS_DIR/scripts/common/main.sh" "$@" 2>&1 </dev/null)"
  RC=$?
  set -e
}

installed_field() { "$JQ" -r --arg i "$1" --arg f "$2" '.tools[$i][$f] // empty' "$HOME/.workstation-tools-installed.json"; }
requested_value() { "$JQ" -r --arg i "$1" '.tools[$i] // empty' "$FX/project/.workstation-tools-requested.json"; }

# snapshot of a directory tree including symlinks and modes
# shellcheck disable=SC2010
snapshot() { (cd "$1" && ls -lRa . | grep -v '^total' | grep -v ' \.\.$' | sed -E 's/ +[A-Z][a-z]{2} +[0-9]+ +[0-9:]+ / /'; find . -type f -exec shasum {} + | sort); }

finish() { printf '%s: %d passed, %d failed\n' "$(basename "$0")" "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]; }
