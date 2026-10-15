#!/bin/bash
# Dry-run mutates nothing; interruptions leave no false success or malformed JSON.
. "$(dirname "$0")/helpers.sh"
new_fixture; set_latest_all
trap cleanup_fixture EXIT

# dry-run on a fresh workstation
before="$(snapshot "$FX")"
run_engine --dry-run
assert_rc "$RC" 0 "dry-run"
if [ "$(snapshot "$FX" | grep -v trace)" = "$(echo "$before" | grep -v trace)" ]; then ok; else fail "fresh dry-run mutates nothing"; fi
assert_no_file "$FX/project/.workstation-tools-requested.json"
assert_no_file "$HOME/.workstation-tools-installed.json"
assert_no_file "$FX/home/state/workstation-tools/lock"

# dry-run with pending changes
run_engine
set_latest ripgrep 2.0.0
before="$(snapshot "$FX" | grep -v trace)"
run_engine --dry-run
if [ "$(snapshot "$FX" | grep -v trace)" = "$before" ]; then ok; else fail "pending-change dry-run mutates nothing"; fi
assert_contains "$OUT" "upgrade" "plan shows upgrade"

# shellcheck disable=SC2044
json_ok() { # every json file under the fixture parses
  local f
  for f in $(find "$FX/home" "$FX/project" -name '*.json' 2>/dev/null); do
    "$JQ" -e . "$f" >/dev/null 2>&1 || { fail "malformed JSON: $f"; return; }
  done
  ok
}

crash_run() { # crash_run <barrier>: run with a crash barrier, then recover
  WST_TEST_ABORT_AT="$1" run_engine
  assert_rc "$RC" 137 "crash at $1"
}
# shellcheck disable=SC2120
recover() { sleep 1; WST_LOCK_STALE_SECS=0 run_engine "$@"; }

# crash after the lock mkdir, before the pid file
cleanup_fixture; new_fixture; set_latest_all
crash_run lock-mkdir
assert_file "$FX/home/state/workstation-tools/lock"
assert_no_file "$FX/home/state/workstation-tools/lock/pid"
json_ok
run_engine
assert_rc "$RC" 1 "fresh initializing lock blocks"
recover
assert_rc "$RC" 0 "recovered after lock crash"
assert_no_file "$FX/home/state/workstation-tools/lock"

# crash around the state rename
cleanup_fixture; new_fixture; set_latest_all
crash_run state-before-rename
assert_no_file "$FX/project/.workstation-tools-requested.json"
json_ok
recover
assert_rc "$RC" 0 "recovered after rename crash"
json_ok
cleanup_fixture; new_fixture; set_latest_all
crash_run state-after-rename
json_ok
recover
assert_rc "$RC" 0 "recovered after post-rename crash"

# crash after install, before the record: no false success
cleanup_fixture; new_fixture; set_latest_all
run_engine --groups github   # create requested/installed files
set_latest ripgrep 2.0.0
WST_TEST_ABORT_AT=after-install run_engine
assert_rc "$RC" 137 "crash after install"
json_ok
assert_eq "$(installed_field ripgrep version)" "1.0.0" "no false success for upgrade"
recover
assert_rc "$RC" 0 "recovered after install crash"
assert_eq "$(installed_field ripgrep version)" "2.0.0" "converged"

# two-process contention
cleanup_fixture; new_fixture; set_latest_all
( FAKE_SLEEP=1 run_engine --groups github; echo "$RC" > "$FX/rc.a" ) &
bg=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$FX/home/state/workstation-tools/lock/pid" ] && break; sleep 0.3; done
run_engine --groups github
assert_rc "$RC" 1 "second run refused"
assert_contains "$OUT" "in progress" "contention message"
wait "$bg"
assert_eq "$(cat "$FX/rc.a")" 0 "first run completes"
assert_no_file "$FX/home/state/workstation-tools/lock"
json_ok
finish
