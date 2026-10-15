#!/bin/bash
# Phase ordering and failure isolation, observed through the trace.
. "$(dirname "$0")/helpers.sh"
new_fixture; set_latest_all
trap cleanup_fixture EXIT

# discovery (incl. pinned tools) completes before any probe
printf '{"schema_version":1,"tools":{"jq":"1.0.0"}}' > "$FX/project/.workstation-tools-requested.json"
run_engine
assert_rc "$RC" 0 "first run"
last_latest="$(grep -n '^latest ' "$WST_TRACE_FILE" | tail -1 | cut -d: -f1)"
first_probe="$(grep -n '^probe ' "$WST_TRACE_FILE" | head -1 | cut -d: -f1)"
if [ "$last_latest" -lt "$first_probe" ]; then ok; else fail "all discovery must precede probing"; fi
assert_contains "$(cat "$WST_TRACE_FILE")" "latest jq" "pinned tool discovered"

# unchanged rerun installs nothing
: > "$WST_TRACE_FILE"
run_engine
assert_rc "$RC" 0 "rerun"
assert_not_contains "$(cat "$WST_TRACE_FILE")" "install " "unchanged rerun reinstalls nothing"

# a newer latest upgrades
set_latest ripgrep 2.0.0
: > "$WST_TRACE_FILE"
run_engine
assert_contains "$(cat "$WST_TRACE_FILE")" "install ripgrep 2.0.0" "upgrade"
assert_eq "$(installed_field ripgrep version)" "2.0.0" "record updated"
assert_eq "$(installed_field ripgrep requested)" latest "requested stays latest"
cleanup_fixture

# discovery failure fails only that tool; dependents blocked; independents recorded
new_fixture; set_latest_all
set_latest python3 FAIL
run_engine
assert_rc "$RC" 1 "discovery failure"
assert_contains "$OUT" "python3" "reports python3"
assert_eq "$(installed_field uv status)" installed "independent success recorded"
assert_eq "$(installed_field python3 status)" "" "failed tool not recorded"
assert_contains "$OUT" "blocked: pip3" "dependent blocked"
cleanup_fixture

# failed dependency blocks dependents but not independents
new_fixture; set_latest_all
flag failinstall docker-cli
run_engine --groups aws
assert_rc "$RC" 1 "failed dependency"
assert_contains "$OUT" "blocked: docker" "docker blocked"
assert_contains "$OUT" "blocked: aws-sam" "sam blocked"
assert_eq "$(installed_field awscli status)" installed "awscli unaffected"
assert_eq "$(installed_field docker-cli status)" "" "failed not recorded"
cleanup_fixture

# observed version mismatch fails validation and is not recorded
new_fixture; set_latest_all
mkdir -p "$FX/world/wrongversion"; echo 0.0.1 > "$FX/world/wrongversion/tree"
run_engine
assert_rc "$RC" 1 "mismatch"
assert_contains "$OUT" "does not match target" "mismatch message"
assert_eq "$(installed_field tree status)" "" "mismatch not recorded"
cleanup_fixture

# failed update marks existing record failed
new_fixture; set_latest_all
run_engine
set_latest tmux 2.0.0; flag failinstall tmux
run_engine
assert_rc "$RC" 1 "failed update"
assert_eq "$(installed_field tmux status)" failed "record marked failed"

# checksum-declared tool must report verified
cleanup_fixture; new_fixture; set_latest_all
mkdir -p "$FX/world/integrity"; echo unverified > "$FX/world/integrity/jq"
run_engine
assert_rc "$RC" 1 "unverified for checksum:yes tool"
assert_eq "$(installed_field jq status)" "" "not recorded"
cleanup_fixture; new_fixture; set_latest_all
mkdir -p "$FX/world/integrity"; echo unverified > "$FX/world/integrity/codex"
run_engine
assert_rc "$RC" 0 "unverified allowed for checksum:no"
assert_eq "$(installed_field codex integrity)" unverified "unverified recorded"

# pinned unavailable version / conflict
cleanup_fixture; new_fixture; set_latest_all
set_installed yq 9.9.9 other /usr/local/bin/yq
run_engine
assert_rc "$RC" 1 "foreign install, version differs"
assert_contains "$OUT" "remove it manually" "conflict message"
finish
