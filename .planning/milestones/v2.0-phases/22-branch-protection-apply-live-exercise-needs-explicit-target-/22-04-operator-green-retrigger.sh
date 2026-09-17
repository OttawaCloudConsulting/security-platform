#!/usr/bin/env bash
set -euo pipefail

# 22-04-operator-green-retrigger.sh — Phase 22 plan 04, Task 2: push the empty
# commit that produces the THIRD verdict (green checks, still required).
#
# NEVER set this file's executable bit. Run it as:
#
#   bash /Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-04-operator-green-retrigger.sh
#
# RUN THIS SECOND. 22-04-operator-merge-attempt.sh runs FIRST, and the
# interlock below enforces that mechanically rather than by instruction: this
# script refuses to run until merge-attempt.txt exists. The order is not
# cosmetic. This push turns the two red checks green, which makes PR #14
# mergeable; running it before the merge attempt would destroy the BLOCKED
# precondition the attempt depends on and leave the phase with no refusal to
# witness.
#
# WHY THE OPERATOR RUNS THIS. The executor's auto-mode Bash classifier denies
# writes against this repository — measured four times now (20-07, 20-10,
# 22-01 Task 4, 22-02 Task 1, and 22-04 Task 1's merge attempt). Per the
# project's anti-slop protocol the executor stops rather than working around it.
#
# WHAT IT WRITES: exactly one empty commit, pushed to an existing exercise
# branch. No ruleset write, no variable, no merge, no branch deletion. The
# measurement that follows (run wait, check-run capture, ruleset re-read,
# merge-state settle-poll) is done by the agent from its own reads — the
# "human writes, Claude measures" split this phase has used throughout.
#
# WHY AN EMPTY COMMIT AND NOT `gh run rerun`: upload-artifact v4 requires
# unique artifact names per run id, and a rerun REUSES the run id. A 409 would
# turn jobs red for a reason unrelated to the gate and poison a verdict that
# requires all five green (18-05's measured reason).
#
# EXIT CODES:
#   0  empty commit pushed, tree-hash invariant holds
#   2  a precondition failed — NOTHING was pushed

REPO="OttawaCloudConsulting/terraform-pipelines"
PR=14
BRANCH="chore/phase-22-required-check-exercise"
BLOCKING_SHA="969dc2c8e12fc6c29f42cab1a9a0bde9eca686c7"
CLONE="/private/tmp/claude-501/-Users-christian-git-repos-OCC-github-development-environment-security-solution/8588a375-6645-4b32-a044-a40cd3f58f79/scratchpad/22-exercise-clone"
PHASE_DIR="/Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-"
E="${PHASE_DIR}/22-evidence"

say() { printf '\n=== %s ===\n' "$*"; }

say "Preconditions (nothing is pushed until all of these pass)"

# ---- Interlock: the merge attempt must already have happened ---------------
test -s "${E}/merge-attempt.txt" \
  || { echo "ABORT(2): ${E}/merge-attempt.txt is missing or empty." >&2
       echo "          Run 22-04-operator-merge-attempt.sh FIRST. This push turns the" >&2
       echo "          checks green, which would destroy the BLOCKED precondition the" >&2
       echo "          merge attempt depends on. Order is enforced, not advised." >&2
       exit 2; }
echo "ok: merge attempt already captured ($(wc -c < "${E}/merge-attempt.txt") bytes)"

# ---- Nothing was merged by it ----------------------------------------------
# The interlock couples to A's FILES, not to A's exit code, so guard the second
# artifact explicitly: without this, a half-finished A would kill this script
# with a Python traceback instead of a readable ABORT(2), and a traceback is
# easy to misread as a classifier denial.
test -s "${E}/pr-after-attempt.json" \
  || { echo "ABORT(2): ${E}/pr-after-attempt.json is missing or empty." >&2
       echo "          merge-attempt.txt exists but the post-attempt read does not, so" >&2
       echo "          22-04-operator-merge-attempt.sh did not finish. Run this script only" >&2
       echo "          if that one exited 0." >&2
       exit 2; }
STATE_AFTER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["state"])' "${E}/pr-after-attempt.json")
MERGED_AT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mergedAt"])' "${E}/pr-after-attempt.json")
[ "$STATE_AFTER" = "OPEN" ] && [ "$MERGED_AT" = "None" ] \
  || { echo "ABORT(2): PR is state=${STATE_AFTER} mergedAt=${MERGED_AT}; expected OPEN/null." >&2; exit 2; }
echo "ok: PR #${PR} still OPEN and unmerged"

# ---- The requirement must still be in force --------------------------------
RULES_NOW=$(gh api "repos/${REPO}/rules/branches/main" --jq '[.[].type]|sort|join(",")')
case "$RULES_NOW" in
  *required_status_checks*) echo "ok: required_status_checks still in force (${RULES_NOW})" ;;
  *) echo "ABORT(2): required_status_checks is gone (${RULES_NOW}). The third verdict's whole" >&2
     echo "          point is that the requirement did NOT go away, only the redness did." >&2
     exit 2 ;;
esac

# ---- No GATE_MODE: the green run is what an ABSENT variable produces -------
if gh variable list -R "$REPO" --json name --jq '.[].name' | grep -qx GATE_MODE; then
  echo "ABORT(2): GATE_MODE is set on ${REPO}. The third verdict requires the variable to be" >&2
  echo "          ABSENT — that is what makes the checks green. Do not set it to report-only;" >&2
  echo "          18-05 proved deletion is what restores green." >&2
  exit 2
fi
echo "ok: no GATE_MODE — the callee default (report-only) will apply"

# ---- The clone ------------------------------------------------------------
test -d "${CLONE}/.git" || { echo "ABORT(2): exercise clone missing at ${CLONE}" >&2; exit 2; }
CLONE_HEAD=$(git -C "$CLONE" rev-parse HEAD)
[ "$CLONE_HEAD" = "$BLOCKING_SHA" ] \
  || { echo "ABORT(2): clone HEAD is ${CLONE_HEAD}, expected ${BLOCKING_SHA}" >&2; exit 2; }
CLONE_BRANCH=$(git -C "$CLONE" rev-parse --abbrev-ref HEAD)
[ "$CLONE_BRANCH" = "$BRANCH" ] \
  || { echo "ABORT(2): clone is on '${CLONE_BRANCH}', expected '${BRANCH}'" >&2; exit 2; }
[ -z "$(git -C "$CLONE" status --porcelain)" ] \
  || { echo "ABORT(2): clone has uncommitted changes — an empty commit must be EMPTY." >&2
       git -C "$CLONE" status --short >&2; exit 2; }
echo "ok: clone on ${BRANCH} at ${BLOCKING_SHA}, working tree clean"

# ------------------------------------------------------------- the empty commit
say "Empty commit (NOT gh run rerun)"
git -C "$CLONE" commit --allow-empty -m "chore: empty commit to re-trigger with GATE_MODE absent

Phase 22 plan 04 Task 2 — the third merge verdict. No file changes: the tree
hash is byte-identical to ${BLOCKING_SHA} and to the plan-01 baseline, so across
all three verdicts the only things that moved are the head SHA (unavoidable),
the check conclusions, and — between verdicts one and two — the ruleset.

With GATE_MODE absent the callee defaults to report-only and all five
\`security / …\` checks go green, while the five contexts remain REQUIRED. A
CLEAN verdict here isolates the red required check as the sole cause of the
refusal captured in merge-attempt.txt.

Not \`gh run rerun\`: upload-artifact v4 requires unique artifact names per run
id and a rerun reuses the run id (18-05-SUMMARY).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FKhf6VmaBFhZGJK9WcLawZ"

NEWSHA=$(git -C "$CLONE" rev-parse HEAD)
git -C "$CLONE" rev-parse 'HEAD^{tree}' > "${E}/tree-hash-clean.txt"

say "Tree-hash invariant — three commits, ONE tree"
if ! diff "${E}/tree-hash-baseline.txt" "${E}/tree-hash-clean.txt"; then
  echo "ABORT(2): tree hash differs from the baseline. Something other than an empty commit" >&2
  echo "          is staged. NOTHING HAS BEEN PUSHED; the commit is local only." >&2
  exit 2
fi
if ! diff "${E}/tree-hash-blocking.txt" "${E}/tree-hash-clean.txt"; then
  echo "ABORT(2): tree hash differs from the blocking capture. NOTHING HAS BEEN PUSHED." >&2
  exit 2
fi
echo "ok: tree hash byte-identical across all three ($(cat "${E}/tree-hash-clean.txt"))"
echo "    head SHA ${BLOCKING_SHA} -> ${NEWSHA}"

say "Pushing"
git -C "$CLONE" push origin "$BRANCH"

printf '%s\n' "$NEWSHA" > "${E}/head-sha-clean.txt"

say "Done — pushed ${NEWSHA}"
echo "The agent takes it from here: it waits for the run, captures the five check"
echo "conclusions, re-reads the ruleset to confirm the contexts are STILL required,"
echo "and settle-polls the merge state. Those are all reads."
echo
echo "Do NOT merge the pull request. It is about to become mergeable, and plan 05"
echo "closes it UNMERGED and deletes the branch."
exit 0
