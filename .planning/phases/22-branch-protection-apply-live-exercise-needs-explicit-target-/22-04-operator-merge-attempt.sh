#!/usr/bin/env bash
set -euo pipefail

# 22-04-operator-merge-attempt.sh — Phase 22 plan 04, Task 1: attempt the merge
# and capture GitHub's refusal verbatim.
#
# NEVER set this file's executable bit. Run it as:
#
#   bash /Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-04-operator-merge-attempt.sh
#
# One absolute-path invocation, deliberately: plan 03's command 2 was first
# pasted as a multi-line continuation, the shell failed to parse the wrap and
# returned 127, and the script never ran. A single token cannot line-wrap.
#
# WHY THIS IS A SCRIPT AND NOT A PASTED COMMAND.
# `gh pr merge` is a WRITE with no dry-run mode (22-RESEARCH.md Pitfall 7).
# There is no way to ask GitHub "would this be refused?" — you can only ask for
# the merge state and then attempt it. If that state is stale or wrong, the
# command does not probe the gate: it merges PR #14 and lands security.yml on a
# real repository's default branch. The fresh-read precondition below is what
# makes the attempt a probe, and it MUST travel in the same execution as the
# attempt itself. Handing over a bare `gh pr merge` would separate them.
#
# The four Pitfall 7 mitigations, all present here:
#   1. a FRESH single read immediately before the attempt, hard-aborting unless
#      the value is exactly BLOCKED
#   2. an explicit merge method that repo-config-before.json shows is enabled
#      (allow_squash_merge: true), so the command cannot hang on a TTY prompt
#   3. --admin is NEVER passed (it exists to bypass the very gate being
#      witnessed); neither is --auto, see the warning below
#   4. stderr redirected into stdout and tee'd — the refusal arrives on stderr
#      and it IS the deliverable
#
# WARNING TO THE OPERATOR — the --auto hint.
# gh's refusal on a blocked pull request is expected to suggest re-running with
# `--auto`. DO NOT. `--auto` queues the pull request to merge automatically the
# moment its checks turn green, and plan 04 Task 2 deliberately turns them
# green. That would merge the exercise branch into main without a further
# prompt. The hint is expected; ignoring it is correct. (allow_auto_merge is
# false on this repository, so it should error — but the instruction does not
# rest on that.)
#
# Exit codes:
#   0  the merge was REFUSED and every post-assertion held — the expected path
#   1  a precondition failed; nothing was attempted
#   9  THE MERGE SUCCEEDED — see the banner this prints. Not recoverable here.

REPO="OttawaCloudConsulting/terraform-pipelines"
PR=14
PHASE_DIR="/Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-"
E="${PHASE_DIR}/22-evidence"

ATT="${E}/merge-attempt.txt"
RCF="${E}/merge-attempt-exit-code.txt"
PRAFTER="${E}/pr-after-attempt.json"
HEADAFTER="${E}/main-head-after-attempt.txt"

cd "$PHASE_DIR"   # explicitly NOT the exercise clone; every call is -R scoped

echo "=== 22-04 merge attempt — preconditions ==="

# ---- Precondition A: the ruleset still carries the required checks ----------
RULES=$(gh api "repos/${REPO}/rules/branches/main" --jq '[.[].type]|sort|join(",")')
echo "rule types on main: ${RULES}"
case "$RULES" in
  *required_status_checks*) echo "  ok: required_status_checks is still in force" ;;
  *) echo "ABORT(1): required_status_checks is NOT on main. The gate is not applied;"
     echo "          there is nothing to witness and the merge would SUCCEED."
     exit 1 ;;
esac

# ---- Precondition B: main has not moved from the plan-01 capture ------------
HEAD_BEFORE=$(cat "${E}/main-head-before.txt")
HEAD_NOW=$(gh api "repos/${REPO}/commits/main" --jq .sha)
echo "main HEAD expected: ${HEAD_BEFORE}"
echo "main HEAD actual  : ${HEAD_NOW}"
if [ "$HEAD_BEFORE" != "$HEAD_NOW" ]; then
  echo "ABORT(1): main has moved since plan 01. Something landed that this phase did not"
  echo "          account for. Stop and investigate before attempting any merge."
  exit 1
fi
echo "  ok: main unchanged"

# ---- Precondition C: THE FRESH READ ----------------------------------------
# Not the polled value from a minute ago. A new one, taken here, in this
# execution, immediately before the attempt.
S=$(gh pr view "$PR" -R "$REPO" --json mergeStateStatus --jq .mergeStateStatus)
echo "FRESH mergeStateStatus: ${S}"
if [ "$S" != "BLOCKED" ]; then
  echo "ABORT(1): mergeStateStatus is '${S}', not BLOCKED — refusing to run gh pr merge."
  echo "          The attempt's entire safety rests on this value. On anything else the"
  echo "          command would not probe the gate, it would merge the pull request."
  exit 1
fi
echo "  ok: BLOCKED — the attempt is a probe, not a merge"

# ---- The attempt -----------------------------------------------------------
echo
echo "=== attempting: gh pr merge ${PR} -R ${REPO} --squash   (no --admin, no --auto) ==="
echo

# errexit is lifted only across the attempt, which is EXPECTED to exit
# non-zero. The exit code is captured explicitly and asserted below; it is not
# swallowed, and no `|| true` appears anywhere in this phase's work.
set +e
gh pr merge "$PR" -R "$REPO" --squash 2>&1 | tee "$ATT"
RC=${PIPESTATUS[0]}
set -e

printf '%s\n' "$RC" > "$RCF"
echo
echo "gh pr merge exit code: ${RC}   (recorded in $(basename "$RCF"))"

# ---- Post-assertions, from FRESH reads, not from the command's output ------
echo
echo "=== post-assertions ==="

gh pr view "$PR" -R "$REPO" --json state,mergedAt > "$PRAFTER"
echo "pr-after-attempt.json: $(cat "$PRAFTER")"

gh api "repos/${REPO}/commits/main" --jq .sha > "$HEADAFTER"
echo "main-head-after-attempt.txt: $(cat "$HEADAFTER")"

STATE_AFTER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["state"])' "$PRAFTER")
MERGED_AT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mergedAt"])' "$PRAFTER")

if [ "$STATE_AFTER" = "MERGED" ] || [ "$MERGED_AT" != "None" ]; then
  echo
  echo "########################################################################"
  echo "## THE MERGE SUCCEEDED. THE GATE DID NOT HOLD.                        ##"
  echo "## state=${STATE_AFTER} mergedAt=${MERGED_AT}                          "
  echo "## main is now $(cat "$HEADAFTER")"
  echo "## STOP. Do not run anything else. Report this immediately.           ##"
  echo "########################################################################"
  exit 9
fi

if ! diff "${E}/main-head-before.txt" "$HEADAFTER" > /dev/null; then
  echo "ABORT: main HEAD MOVED during the attempt — before=$(cat "${E}/main-head-before.txt") after=$(cat "$HEADAFTER")"
  exit 9
fi

echo "  ok: pull request still ${STATE_AFTER}, mergedAt ${MERGED_AT}"
echo "  ok: diff main-head-before.txt main-head-after-attempt.txt — empty; nothing landed"

if [ "$RC" -eq 0 ]; then
  echo
  echo "ABORT: gh pr merge returned 0 but nothing merged. Unexpected — report, do not re-run."
  exit 9
fi

echo
echo "=== REFUSED as expected. exit ${RC}. The text above is in $(basename "$ATT"). ==="
exit 0
