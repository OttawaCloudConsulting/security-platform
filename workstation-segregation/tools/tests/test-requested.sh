#!/bin/bash
# Requested file: create, preserve, pins, remove synonyms, --tool-version, conflicts.
. "$(dirname "$0")/helpers.sh"
new_fixture; set_latest_all
trap cleanup_fixture EXIT
R="$FX/project/.workstation-tools-requested.json"

run_engine --groups github
assert_rc "$RC" 0 "first run"
assert_eq "$(requested_value jq)" latest "jq latest created"
assert_eq "$(requested_value gh)" latest "gh latest created"

# preserve a pin and outside entries; latest stays latest after resolution
"$JQ" '.tools.jq="1.0.0" | .tools.k9s="delete" | .tools["kubectl"]="1.2.3"' "$R" > "$R.n" && mv "$R.n" "$R"
run_engine --groups github --dry-run
assert_rc "$RC" 0 "rerun with unselected removal"
run_engine --groups github
assert_eq "$(requested_value jq)" "1.0.0" "pin preserved"
assert_eq "$(requested_value kubectl)" "1.2.3" "unselected entry preserved"
assert_eq "$(requested_value k9s)" "delete" "delete synonym preserved"
assert_eq "$(requested_value gh)" latest "latest kept"

# --tool-version persists
run_engine --groups github --tool-version gh=2.0.0
assert_eq "$(requested_value gh)" "2.0.0" "tool-version persisted"

# --tool-version for unknown / unselected / removal-flagged
run_engine --groups github --tool-version nope=1
assert_rc "$RC" 1 "unknown tool-version"
run_engine --groups github --tool-version terraform=1.9.8
assert_rc "$RC" 1 "unselected tool-version"
"$JQ" '.tools.gh="remove"' "$R" > "$R.n" && mv "$R.n" "$R"
run_engine --groups github --tool-version gh=2.0.0
assert_rc "$RC" 1 "tool-version vs removal flag"
assert_contains "$OUT" "conflicts with the removal flag" "message"
"$JQ" '.tools.gh="latest"' "$R" > "$R.n" && mv "$R.n" "$R"

# bundled pin rejected; prerequisite rejected
run_engine --tool-version uvx=0.1.0
assert_rc "$RC" 1 "bundled pin"
assert_contains "$OUT" "pin uv instead of uvx" "bundled pin message"
"$JQ" '.tools.bash="latest"' "$R" > "$R.n" && mv "$R.n" "$R"
run_engine --groups github
assert_rc "$RC" 1 "prerequisite in file"
assert_contains "$OUT" "orchestrator prerequisites" "prereq message"

# malformed file and failed validation leave the file untouched
printf '{broken' > "$R"
before="$(shasum "$R")"
run_engine --groups github
assert_rc "$RC" 1 "malformed"
assert_eq "$(shasum "$R")" "$before" "file untouched"
printf '{"schema_version":1,"tools":{"gh":"v 1 2"}}' > "$R"
run_engine --groups github
assert_rc "$RC" 1 "bad version syntax"
finish
