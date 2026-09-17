#!/usr/bin/env bash
set -euo pipefail

# 22-05-operator-restore.sh — Phase 22 plan 05, Task 1.
# THE PHASE'S NON-NEGOTIABLE SAFETY GATE. Closes the exercise pull request
# unmerged, deletes its branch, and puts OttawaCloudConsulting/terraform-pipelines'
# branch ruleset back exactly as plan 01 found it.
#
# NEVER set this file's executable bit. Run it as ONE absolute-path token:
#
#   bash /Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-05-operator-restore.sh
#
# A single token cannot line-wrap. Plan 03's command 2 was first pasted as a
# multi-line continuation, the shell failed to parse the wrap and returned 127,
# and the script never ran.
#
# WHY THIS IS A SCRIPT AND NOT THREE PASTED COMMANDS.
# Three writes must happen in a fixed order, each guarded by a fresh read taken
# in the SAME execution:
#   1. close PR #14 unmerged      2. delete its branch      3. PUT the ruleset back
# The pull request is currently CLEAN — every check green with the five contexts
# still required — so it is MERGEABLE right now. Closing it first removes the
# accidental-merge surface entirely, so nothing can land while the ruleset is in
# flux. Handing over a bare `gh api --method PUT` would restore protection while
# leaving a mergeable pull request armed against an unprotected main.
#
# WHY THERE IS NO EXIT TRAP.
# A trap that writes on the error path is a second incident waiting to happen.
# Every step below is instead GUARDED AND IDEMPOTENT: it checks the live state
# first and skips work already done. Re-running this script after a partial
# failure CONVERGES. It never double-writes and it never undoes.
#
# WHAT IT WILL NOT DO, under any circumstances:
#   - merge the pull request (no `gh pr merge` appears anywhere in this file)
#   - touch main, force-push, or delete any branch but the exercise branch
#   - hand-edit rollback.json or delete keys by trial and error if the PUT 422s
#   - use `|| true` on any security-relevant command
#
# Exit codes:
#   0  restored, and the phase gate diff came back empty
#   1  a precondition failed, or the PUT was rejected — read the banner
#   9  KLAXON: something merged, or main moved. Stop everything and report.

REPO="OttawaCloudConsulting/terraform-pipelines"
RID=12760793
PR=14
BRANCH="chore/phase-22-required-check-exercise"
PHASE_DIR="/Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-"
E="${PHASE_DIR}/22-evidence"

cd "$PHASE_DIR"   # explicitly NOT the exercise clone; every call is -R / repos/ scoped

# Full transcript on disk from the first line, so nothing has to be relayed by
# hand and abridged the way plan 03's apply output was.
exec > >(tee "${E}/restore-transcript.txt") 2>&1

echo "=== 22-05 restore — started $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo

# ---------------------------------------------------------------------------
# Preconditions. All reads. Nothing is written until every one of them passes.
# ---------------------------------------------------------------------------
echo "--- preconditions ---"

# A: main has not moved since plan 01.
HEAD_BEFORE=$(cat "${E}/main-head-before.txt")
HEAD_NOW=$(gh api "repos/${REPO}/commits/main" --jq .sha)
echo "main HEAD expected: ${HEAD_BEFORE}"
echo "main HEAD actual  : ${HEAD_NOW}"
if [ "$HEAD_BEFORE" != "$HEAD_NOW" ]; then
  echo "ABORT(9): main has MOVED. Something landed that this phase did not account for."
  echo "          Do not restore blind — investigate first."
  exit 9
fi
echo "  ok: main unchanged"

# B: the pull request has not been merged by anything.
PR_STATE=$(gh pr view "$PR" -R "$REPO" --json state --jq .state)
PR_MERGED=$(gh pr view "$PR" -R "$REPO" --json mergedAt --jq '.mergedAt // "null"')
echo "PR #${PR}: state=${PR_STATE} mergedAt=${PR_MERGED}"
if [ "$PR_STATE" = "MERGED" ] || [ "$PR_MERGED" != "null" ]; then
  echo "ABORT(9): the exercise pull request is MERGED. The gate did not hold."
  echo "          Stop. Report this before anything else is touched."
  exit 9
fi
echo "  ok: not merged"

# C: the rollback body exists and is exactly what it claims to be. Re-validated
#    here rather than trusted, because this is the document about to replace a
#    live access-control policy.
python3 - "${E}/rollback.json" "${E}/rules-before.txt" <<'PY'
import json, sys
body = json.load(open(sys.argv[1], encoding="utf-8"))
want = {"name", "target", "enforcement", "conditions", "bypass_actors", "rules"}
if set(body.keys()) != want:
    sys.exit("ABORT: rollback.json is not the six-key PUT body: %r" % sorted(body.keys()))
if body["bypass_actors"] != []:
    sys.exit("ABORT: rollback.json bypass_actors is not [] — refusing to grant merge bypass")
have = sorted(r["type"] for r in body["rules"])
want_types = sorted(open(sys.argv[2], encoding="utf-8").read().strip().split(","))
if have != want_types:
    sys.exit("ABORT: rollback rule types %r != captured %r" % (have, want_types))
print("  ok: rollback.json — six keys, bypass_actors [], rule types", have)
PY

# D: the pre-written escalation artifact matches what this script is about to
#    run, so the paste-able fallback and the execution cannot diverge.
grep -q "rulesets/${RID}" "${E}/restore-command.txt" \
  || { echo "ABORT(1): restore-command.txt does not name ruleset ${RID}"; exit 1; }
grep -q "${E}/rollback.json" "${E}/restore-command.txt" \
  || { echo "ABORT(1): restore-command.txt does not point at ${E}/rollback.json"; exit 1; }
echo "  ok: restore-command.txt agrees with this script"

RULES_NOW=$(gh api "repos/${REPO}/rules/branches/main" --jq '[.[].type]|sort|join(",")')
RULES_BEFORE=$(cat "${E}/rules-before.txt")
echo "rule types live now: ${RULES_NOW}"
echo

# ---------------------------------------------------------------------------
# STEP A — close the pull request unmerged, and delete its branch.
# This happens BEFORE the ruleset write, deliberately: the pull request is
# mergeable right now, and closing it first means nothing can land while
# protection is in flux.
# ---------------------------------------------------------------------------
echo "--- step A: close PR #${PR} unmerged, delete ${BRANCH} ---"

if [ "$PR_STATE" = "OPEN" ]; then
  echo "closing (no merge, no --admin, no --auto):"
  # errexit lifted across the close. `gh pr close --delete-branch` performs the
  # REMOTE delete first and can still exit non-zero afterwards over the LOCAL
  # branch — and this script runs from the documentation repository, which has
  # no such branch. Letting set -e act on that code would kill the script with
  # the pull request already closed and the ruleset still locked: exactly the
  # half-done state this design exists to prevent. The outcome is therefore
  # judged by the fresh read-backs below, not by this exit code.
  set +e
  gh pr close "$PR" -R "$REPO" --delete-branch --comment \
    "Closing unmerged. This pull request existed only to witness a required-status-check merge refusal (phase 22, VAL-02). The branch ruleset is being restored to its pre-exercise state in the same operation. Nothing from this branch is intended for main."
  CLOSE_RC=$?
  set -e
  echo "gh pr close exit code: ${CLOSE_RC} (informational — the read-backs decide)"
else
  echo "  skip: PR #${PR} is already ${PR_STATE} — nothing to close (idempotent re-run)"
fi

# Branch delete, verified rather than assumed. `gh pr close --delete-branch`
# deletes the remote head branch, but its local-clone behaviour varies, so the
# result is READ BACK and a direct ref delete is used as the fallback. The
# exercise branch is outside the ruleset's conditions.include (~DEFAULT_BRANCH
# and refs/heads/main only), so the `deletion` rule does not govern it.
BRANCHES=$(gh api "repos/${REPO}/branches" --jq '[.[].name]|sort|join(",")')
echo "branches after close: ${BRANCHES}"
if printf '%s' "$BRANCHES" | grep -q "$BRANCH"; then
  echo "  head branch survived the close — deleting the ref directly"
  gh api --method DELETE "repos/${REPO}/git/refs/heads/${BRANCH}"
  BRANCHES=$(gh api "repos/${REPO}/branches" --jq '[.[].name]|sort|join(",")')
  echo "branches after ref delete: ${BRANCHES}"
fi
if [ "$BRANCHES" != "main" ]; then
  echo "ABORT(1): branch list is '${BRANCHES}', expected 'main' only. Stop and report."
  exit 1
fi
echo "  ok: branch list is main only"

# pr-final.json carries state and mergedAt ONLY. mergeStateStatus is
# deliberately excluded: its enum includes the unsettled sentinel this phase's
# own evidence gate greps for and forbids across 22-evidence/.
gh pr view "$PR" -R "$REPO" --json number,state,mergedAt,headRefName,headRefOid > "${E}/pr-final.json"
echo "pr-final.json: $(cat "${E}/pr-final.json")"

FINAL_STATE=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["state"])' "${E}/pr-final.json")
FINAL_MERGED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["mergedAt"])' "${E}/pr-final.json")
if [ "$FINAL_STATE" != "CLOSED" ] || [ "$FINAL_MERGED" != "None" ]; then
  echo "ABORT(9): PR #${PR} is state=${FINAL_STATE} mergedAt=${FINAL_MERGED}, expected CLOSED / null."
  exit 9
fi
echo "  ok: CLOSED, unmerged"
echo

# ---------------------------------------------------------------------------
# STEP B — restore the ruleset.
# ---------------------------------------------------------------------------
echo "--- step B: restore ruleset ${RID} ---"

if [ "$RULES_NOW" = "$RULES_BEFORE" ]; then
  echo "  skip: rule types already equal the capture (${RULES_BEFORE})."
  echo "        Re-PUTting a byte-identical document would write a misleading"
  echo "        'restored' line into the evidence. No PUT performed."
  PUT_RAN=no
else
  echo "PUT repos/${REPO}/rulesets/${RID} --input ${E}/rollback.json"
  # errexit lifted only across the PUT so a rejection can be reported with its
  # raw body instead of killing the shell. The code is captured and asserted;
  # it is not swallowed, and no `|| true` appears anywhere in this file.
  set +e
  gh api --method PUT "repos/${REPO}/rulesets/${RID}" --input "${E}/rollback.json" \
    > "${E}/put-response.json" 2> "${E}/put-stderr.txt"
  RC=$?
  set -e
  printf '%s\n' "$RC" > "${E}/restore-exit-code.txt"
  PUT_RAN=yes
  echo "PUT exit code: ${RC}"
  if [ "$RC" -ne 0 ]; then
    echo
    echo "######################################################################"
    echo "## THE RESTORING PUT WAS REJECTED. THE REPOSITORY IS STILL LOCKED.  ##"
    echo "## Raw response body and stderr follow. DO NOT start deleting keys  ##"
    echo "## by trial and error against a live repository — that is how a      ##"
    echo "## clean rollback becomes a second incident. Report this as-is.      ##"
    echo "######################################################################"
    echo "--- put-response.json ---"; cat "${E}/put-response.json" || true
    echo "--- put-stderr.txt ---";    cat "${E}/put-stderr.txt"    || true
    echo "--- the paste-able command is in restore-command.txt ---"
    exit 1
  fi
  echo "  ok: PUT accepted"
fi
echo

# ---------------------------------------------------------------------------
# Read-backs. FRESH GETs against the authoritative endpoints — never the PUT's
# own response body. `branches/main/protection` is NOT used: it 404s by design
# on a ruleset-governed repository and that 404 is a false negative.
# ---------------------------------------------------------------------------
echo "--- read-back ---"

gh api "repos/${REPO}/rules/branches/main" --jq '[.[].type]|sort|join(",")' > "${E}/rules-restored.txt"
gh api "repos/${REPO}/rulesets/${RID}" > "${E}/ruleset-restored.json"

echo "rules-before.txt  : $(cat "${E}/rules-before.txt")"
echo "rules-restored.txt: $(cat "${E}/rules-restored.txt")"
echo
echo "THE PHASE GATE — diff rules-before.txt rules-restored.txt:"
if diff "${E}/rules-before.txt" "${E}/rules-restored.txt"; then
  echo "  (empty) — byte-identical to the pre-exercise capture"
else
  echo "ABORT(1): THE PHASE GATE FAILED. The ruleset is NOT what it was. Report immediately."
  exit 1
fi

python3 - "${E}/ruleset-restored.json" "${E}/rollback.json" <<'PY'
import json, sys
live = json.load(open(sys.argv[1], encoding="utf-8"))
body = json.load(open(sys.argv[2], encoding="utf-8"))
types = [r["type"] for r in live["rules"]]
if "required_status_checks" in types:
    sys.exit("ABORT: required_status_checks is STILL on the ruleset: %r" % types)
if "pull_request" in types:
    sys.exit("ABORT: a pull_request rule is STILL on the ruleset: %r" % types)
if live.get("bypass_actors") != []:
    sys.exit("ABORT: bypass_actors is %r, not [] — someone gained merge bypass on main"
             % live.get("bypass_actors"))
proj = {k: live[k] for k in ("name", "target", "enforcement", "conditions",
                             "bypass_actors", "rules")}
if proj != body:
    sys.exit("ABORT: the live six-key projection does not equal rollback.json")
print("  ok: no required_status_checks, no pull_request rule")
print("  ok: bypass_actors []")
print("  ok: live six-key projection EQUALS rollback.json — byte-identical, not asserted")
PY

HEAD_AFTER=$(gh api "repos/${REPO}/commits/main" --jq .sha)
printf '%s\n' "$HEAD_AFTER" > "${E}/main-head-after-restore.txt"
if [ "$HEAD_AFTER" != "$HEAD_BEFORE" ]; then
  echo "ABORT(9): main MOVED during the restore: ${HEAD_BEFORE} -> ${HEAD_AFTER}"
  exit 9
fi
echo "  ok: main still ${HEAD_AFTER}"

echo
echo "=== RESTORE COMPLETE (PUT performed: ${PUT_RAN}) ==="
echo "  pull request : CLOSED, unmerged, branch deleted"
echo "  ruleset      : ${RULES_BEFORE}"
echo "  main HEAD    : ${HEAD_AFTER}"
echo "  finished $(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 0
