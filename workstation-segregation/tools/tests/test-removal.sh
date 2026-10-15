#!/bin/bash
# Removal rules 1-6, confirmation, idempotence, partial removal.
. "$(dirname "$0")/helpers.sh"
new_fixture; set_latest_all
trap cleanup_fixture EXIT
R="$FX/project/.workstation-tools-requested.json"
setreq() { "$JQ" --arg k "$1" --arg v "$2" '.tools[$k]=$v' "$R" > "$R.n" && mv "$R.n" "$R"; }

run_engine
assert_rc "$RC" 0 "baseline install"

# base tool without override: rejected, nothing changes
setreq tree remove
run_engine --yes
assert_rc "$RC" 1 "base removal rejected"
assert_contains "$OUT" "--allow-base-removal" "base message"
assert_file "$FX/world/installed/tree"

# never class rejected even with override
setreq tree latest; setreq jq remove
run_engine --yes --allow-base-removal
assert_rc "$RC" 1 "never rejected"
assert_contains "$OUT" "never removed" "never message"
setreq jq latest

# bundled command whose provider remains
setreq uvx remove
run_engine --yes --allow-base-removal
assert_rc "$RC" 1 "bundled with provider"
assert_contains "$OUT" "bundled command of uv" "bundled message"
setreq uvx latest

# every rejection is collected
setreq uvx remove; setreq git remove
run_engine --yes --allow-base-removal
assert_contains "$OUT" "git: removal rejected" "collected 1"
assert_contains "$OUT" "uvx: removal rejected" "collected 2"
setreq uvx latest; setreq git latest

# confirmation: no TTY and no --yes
setreq tree remove
run_engine --allow-base-removal
assert_rc "$RC" 1 "no confirmation"
assert_contains "$OUT" "requires confirmation" "confirmation message"
assert_file "$FX/world/installed/tree"

# dry-run reports without removing
run_engine --allow-base-removal --dry-run
assert_rc "$RC" 0 "dry-run removal"
assert_contains "$OUT" "tree" "plan shows tree"
assert_file "$FX/world/installed/tree"

# real removal
run_engine --allow-base-removal --yes
assert_rc "$RC" 0 "removal"
assert_no_file "$FX/world/installed/tree"
assert_eq "$(installed_field tree status)" removed "recorded removed"
assert_eq "$(requested_value tree)" remove "flag kept"
assert_contains "$OUT" "reduced by request: tree" "reduced report"

# idempotent rerun: nothing removed or installed again
: > "$WST_TRACE_FILE"
run_engine --allow-base-removal --yes
assert_rc "$RC" 0 "idempotent rerun"
assert_not_contains "$(cat "$WST_TRACE_FILE")" "remove tree" "no second removal"
assert_not_contains "$(cat "$WST_TRACE_FILE")" "install tree" "not reinstalled"

# provider + all bundled commands together
setreq uv remove; setreq uvx remove; setreq gemini-notebook-mcp-cli remove; setreq tree latest
run_engine --allow-base-removal --yes
assert_rc "$RC" 0 "provider with bundled"
assert_eq "$(installed_field uv status)" removed "uv removed"
assert_eq "$(installed_field uvx status)" removed "uvx removed with provider"
setreq uv latest; setreq uvx latest; setreq gemini-notebook-mcp-cli latest

# not owned: foreign install, no record -> rejected with manual-removal message
cleanup_fixture; new_fixture; set_latest_all
R="$FX/project/.workstation-tools-requested.json"
printf '{"schema_version":1,"tools":{"k9s":"remove"}}' > "$R"
set_installed k9s 0.9.0 other /opt/k9s/bin/k9s
run_engine --yes
assert_rc "$RC" 1 "unowned"
assert_contains "$OUT" "remove /opt/k9s/bin/k9s manually, then rerun" "ownership message"
assert_file "$FX/world/installed/k9s"

# deselected group's tool is still removed when flagged, and its handlers load
cleanup_fixture; new_fixture; set_latest_all
run_engine --groups kubernetes
assert_rc "$RC" 0 "kubernetes install"
R="$FX/project/.workstation-tools-requested.json"
setreq k9s delete
run_engine --yes
assert_rc "$RC" 0 "deselected removal"
assert_no_file "$FX/world/installed/k9s"
assert_file "$FX/world/installed/kubectl"
assert_eq "$(installed_field k9s status)" removed "k9s removed"

# hard dependency: docker while kind remains
setreq k9s latest; setreq docker remove
run_engine --groups kubernetes --yes
assert_rc "$RC" 1 "hard dependency"
assert_contains "$OUT" "required by kind" "dependency message"
setreq docker latest

# partial removal is recorded failed
setreq stern remove; flag noremove stern
run_engine --groups kubernetes --yes
assert_rc "$RC" 1 "partial removal"
assert_eq "$(installed_field stern status)" failed "failed, not removed"

# removal does not need discovery
cleanup_fixture; new_fixture; set_latest_all
run_engine --groups kubernetes
R="$FX/project/.workstation-tools-requested.json"
setreq k9s remove; set_latest k9s FAIL; set_latest stern FAIL
run_engine --groups kubernetes --yes
assert_eq "$(installed_field k9s status)" removed "removal despite discovery failure"
assert_eq "$RC" 1 "stern discovery failure still fails run"
finish
