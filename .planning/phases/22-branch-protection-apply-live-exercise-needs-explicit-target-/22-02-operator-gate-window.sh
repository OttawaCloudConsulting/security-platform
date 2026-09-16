#!/usr/bin/env bash
# 22-02-operator-gate-window.sh — OPERATOR-RUN. Phase 22 plan 02 Task 1.
#
# WHY THE OPERATOR RUNS THIS. The executor session's auto-mode Bash classifier
# denied `gh variable set GATE_MODE --body blocking -R
# OttawaCloudConsulting/terraform-pipelines` (the same denial shape 20-07, 20-10
# and 22-01 Task 4 all hit). Per the project's anti-slop protocol the executor
# stopped rather than working around it.
#
# WHY IT IS ONE SCRIPT AND NOT "operator sets, Claude measures, operator deletes".
# GATE_MODE is REPOSITORY-WIDE (ADR-017's accepted structural tradeoff): while it
# is set it governs every workflow run on terraform-pipelines, not just PR #14.
# Plan 02's must_haves require the window be bounded "to minutes and not to the
# length of a human checkpoint". If the operator only ran the `set`, the window
# would stay open across a human round-trip AND the closing `delete` would face
# the same classifier denial — leaving the repository blocking indefinitely.
# So set, measure and delete all happen inside one machine-bounded run, with an
# EXIT trap that closes the window on EVERY path including failure.
#
# This script makes NO ruleset write. It touches exactly one repository variable
# and pushes one empty commit to an existing exercise branch.
#
# USAGE (never chmod +x — project rule):
#   bash /private/tmp/claude-501/-Users-christian-git-repos-OCC-github-development-environment-security-solution/8588a375-6645-4b32-a044-a40cd3f58f79/scratchpad/22-02-operator-gate-window.sh
#
# Run it from the security_solution repo root (it writes into .planning/...).
# Expected duration: ~3-6 minutes, almost all of it waiting for the workflow run.
#
# EXIT CODES:
#   0  window opened, one red check measured, window closed
#   1  an assertion failed — the window is CLOSED by the trap before exit
#   2  a precondition failed BEFORE the window was ever opened

set -euo pipefail

REPO="OttawaCloudConsulting/terraform-pipelines"
PR=14
BRANCH="chore/phase-22-required-check-exercise"
BASELINE_SHA="a792e1a8b1054c99ae9406993b5d91d223dbe02f"
BASELINE_RUN=35144256399
APP_ID=15368
CLONE="/private/tmp/claude-501/-Users-christian-git-repos-OCC-github-development-environment-security-solution/8588a375-6645-4b32-a044-a40cd3f58f79/scratchpad/22-exercise-clone"
P=".planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-"
E="${P}/22-evidence"
# Temp files live in the session scratchpad, never /tmp (project rule).
SCRATCH="/private/tmp/claude-501/-Users-christian-git-repos-OCC-github-development-environment-security-solution/8588a375-6645-4b32-a044-a40cd3f58f79/scratchpad"
RUNLOG="${SCRATCH}/22-02-run.log"
POSTDEL="${SCRATCH}/22-02-postdelete.json"

say() { printf '\n=== %s ===\n' "$*"; }

# ---------------------------------------------------------------- preconditions
say "Preconditions (nothing is written until all of these pass)"

test -d "$E" || { echo "ABORT(2): $E not found — run from the security_solution repo root." >&2; exit 2; }

grep -qE '^proceed\b' "${E}/go-decision.txt" \
  || { echo "ABORT(2): go-decision.txt absent or does not start with 'proceed'. The operator's" >&2
       echo "          execution-time authorisation is missing; refusing to write." >&2; exit 2; }
echo "ok: operator authorisation on disk (go-decision.txt -> proceed)"

test -d "${CLONE}/.git" || { echo "ABORT(2): exercise clone missing at ${CLONE}" >&2; exit 2; }
CLONE_HEAD=$(git -C "$CLONE" rev-parse HEAD)
[ "$CLONE_HEAD" = "$BASELINE_SHA" ] \
  || { echo "ABORT(2): clone HEAD is ${CLONE_HEAD}, expected ${BASELINE_SHA}" >&2; exit 2; }
[ -z "$(git -C "$CLONE" status --porcelain)" ] \
  || { echo "ABORT(2): exercise clone has uncommitted changes — an empty commit must be EMPTY." >&2
       git -C "$CLONE" status --short >&2; exit 2; }
echo "ok: clone at ${BASELINE_SHA}, working tree clean"

# The window must not already be open, or the timestamps would be meaningless.
if gh variable list -R "$REPO" --json name --jq '.[].name' | grep -qx GATE_MODE; then
  echo "ABORT(2): GATE_MODE is ALREADY set on ${REPO}. A previous window was left open." >&2
  echo "          Investigate before proceeding; do not blindly overwrite." >&2
  exit 2
fi
echo "ok: no GATE_MODE set — window is currently closed"

RULES_NOW=$(gh api "repos/${REPO}/rules/branches/main" --jq '[.[].type]|sort|join(",")')
[ "$RULES_NOW" = "copilot_code_review,deletion,non_fast_forward" ] \
  || { echo "ABORT(2): ruleset already differs: '${RULES_NOW}'" >&2; exit 2; }
echo "ok: ruleset unchanged (${RULES_NOW})"

# ---------------------------------------------------------- the closing trap
# Guard-then-act (22-PATTERNS Shared Pattern 7), never `|| true`. This runs on
# EVERY exit path, so a mid-script failure cannot leave the repository blocking.
WINDOW_CLOSED=0
close_window() {
  if [ "$WINDOW_CLOSED" -eq 1 ]; then return 0; fi
  say "Closing the blocking window"
  if gh variable list -R "$REPO" --json name --jq '.[].name' | grep -qx GATE_MODE; then
    if gh variable delete GATE_MODE -R "$REPO"; then
      echo "GATE_MODE deleted."
    else
      echo "!!! GATE_MODE DELETE FAILED. THE REPOSITORY IS STILL BLOCKING. !!!" >&2
      echo "!!! Run manually: gh variable delete GATE_MODE -R ${REPO}      !!!" >&2
      return 0
    fi
  else
    echo "GATE_MODE already absent."
  fi
  WINDOW_CLOSED=1
  END_LOCAL=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  END_EPOCH=$(date -u +%s)
  {
    echo ""
    echo "WINDOW END   (executor clock, recorded AFTER the delete): ${END_LOCAL}"
    if [ -n "${START_EPOCH:-}" ]; then
      echo "DURATION: $(( END_EPOCH - START_EPOCH )) seconds"
    fi
    echo "Closed by: gh variable delete GATE_MODE (DELETED, never set to report-only —"
    echo "18-05 proved deletion restores green)."
    echo ""
    echo "gh variable list -R ${REPO} at close:"
    echo "--- begin output ---"
    gh variable list -R "$REPO"
    echo "--- end output (empty above means no Actions variables remain) ---"
  } >> "${E}/gate-window.txt"
  echo "window end recorded: ${END_LOCAL}"
}
trap close_window EXIT

# ------------------------------------------------------------- open the window
say "Opening the blocking window"
START_LOCAL=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START_EPOCH=$(date -u +%s)
{
  echo "GATE_MODE blocking window on ${REPO}"
  echo "Phase 22 plan 02 Task 1. GATE_MODE is repository-wide (ADR-017 accepted"
  echo "tradeoff), so the window is opened and closed inside this one script run."
  echo "Opened by the OPERATOR because the executor's Bash classifier denied the write."
  echo ""
  echo "WINDOW START (executor clock, recorded BEFORE the flip): ${START_LOCAL}"
} > "${E}/gate-window.txt"

gh variable set GATE_MODE --body blocking -R "$REPO"

# Server-side truth for the start, independent of any local clock.
VAR_CREATED=$(gh api "repos/${REPO}/actions/variables/GATE_MODE" --jq '.created_at')
VAR_VALUE=$(gh api "repos/${REPO}/actions/variables/GATE_MODE" --jq '.value')
[ "$VAR_VALUE" = "blocking" ] || { echo "ABORT(1): GATE_MODE reads '${VAR_VALUE}', expected 'blocking'" >&2; exit 1; }
{
  echo "WINDOW START (GitHub server, actions/variables/GATE_MODE .created_at): ${VAR_CREATED}"
  echo "GATE_MODE value read back from the API: ${VAR_VALUE}"
} >> "${E}/gate-window.txt"
echo "GATE_MODE=blocking is live (server created_at ${VAR_CREATED})"

# -------------------------------------------- retrigger on an identical tree
say "Empty commit (NOT gh run rerun — 18-05 rejected rerun on measured grounds)"
git -C "$CLONE" commit --allow-empty -m "chore: empty commit to re-trigger under GATE_MODE=blocking

Phase 22 plan 02. No file changes: the tree hash is byte-identical to
${BASELINE_SHA}, so the only variable that moved between the two runs is the
repository variable GATE_MODE.

Not \`gh run rerun\`: upload-artifact v4 requires unique artifact names per run
id and a rerun reuses the run id, risking a 409 that would turn jobs red for a
reason unrelated to the gate (18-05-SUMMARY).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FKhf6VmaBFhZGJK9WcLawZ"

git -C "$CLONE" push origin "$BRANCH"
NEWSHA=$(git -C "$CLONE" rev-parse HEAD)
git -C "$CLONE" rev-parse 'HEAD^{tree}' > "${E}/tree-hash-blocking.txt"

say "Tree-hash invariant"
if ! diff "${E}/tree-hash-baseline.txt" "${E}/tree-hash-blocking.txt"; then
  echo "ABORT(1): tree hash CHANGED. Something other than an empty commit landed;" >&2
  echo "          the baseline/blocking comparison is void." >&2
  exit 1
fi
echo "ok: tree hash byte-identical to baseline ($(cat "${E}/tree-hash-blocking.txt"))"
echo "    head SHA moved ${BASELINE_SHA} -> ${NEWSHA} (accepted: the invariant is the TREE)"

# ------------------------------------------------------------ wait for the run
say "Waiting for the new run (bounded; NOT 'gh run watch --exit-status' — this run is EXPECTED to fail)"
RUNID=""
for i in $(seq 1 30); do
  RUNID=$(gh run list -R "$REPO" --branch "$BRANCH" \
            --json databaseId,status,conclusion,headSha \
            --jq "[.[] | select(.headSha == \"${NEWSHA}\") | select(.databaseId != ${BASELINE_RUN})] | first | .databaseId // empty")
  if [ -n "$RUNID" ]; then echo "run appeared: ${RUNID} (poll ${i}/30)"; break; fi
  echo "poll ${i}/30: no run yet for ${NEWSHA}"
  sleep 5
done
[ -n "$RUNID" ] || { echo "ABORT(1): no workflow run appeared for ${NEWSHA} after ~145s." >&2; exit 1; }

RSTATUS=""; RCONC=""
for i in $(seq 1 60); do
  read -r RSTATUS RCONC <<<"$(gh run view "$RUNID" -R "$REPO" --json status,conclusion --jq '"\(.status) \(.conclusion // "-")"')"
  echo "poll ${i}/60: run ${RUNID} status=${RSTATUS} conclusion=${RCONC}"
  [ "$RSTATUS" = "completed" ] && break
  sleep 10
done
[ "$RSTATUS" = "completed" ] || { echo "ABORT(1): run ${RUNID} never completed after ~10min." >&2; exit 1; }

# --------------------------------------------------------------- the evidence
say "Check runs at ${NEWSHA} (app.id == ${APP_ID} only — 11+ exist at this SHA, only 5 are ours)"
gh api "repos/${REPO}/commits/${NEWSHA}/check-runs" \
  --jq "[.check_runs[] | select(.app.id == ${APP_ID}) | {name, conclusion, status}]" \
  > "${E}/check-runs-unstable.json"
python3 -m json.tool "${E}/check-runs-unstable.json"

say "Proving the mode from the run's OWN logs (assumption A10 — never inferred from conclusions)"
LOGOK=0
for i in $(seq 1 6); do
  if gh run view "$RUNID" -R "$REPO" --log > "$RUNLOG" 2>/dev/null; then LOGOK=1; break; fi
  echo "poll ${i}/6: logs not available yet"
  sleep 10
done
[ "$LOGOK" -eq 1 ] || { echo "ABORT(1): could not fetch logs for run ${RUNID}." >&2; exit 1; }
# Only the gate_mode= lines land in evidence — never the full log.
# NOTE: a no-match grep exits 1, which under `set -e`/`pipefail` would kill the
# script with no diagnosis, so the failure is caught and named explicitly.
if ! grep -h 'gate_mode=' "$RUNLOG" > "${E}/gate-mode-loglines.raw"; then
  echo "ABORT(1): run ${RUNID}'s log contains NO 'gate_mode=' line at all." >&2
  echo "          The mode cannot be proven from the run's own output (assumption A10)." >&2
  rm -f "$RUNLOG" "${E}/gate-mode-loglines.raw"
  exit 1
fi
sed 's/[[:space:]]\{2,\}/ /g' "${E}/gate-mode-loglines.raw" | sort -u > "${E}/gate-mode-loglines.txt"
rm -f "$RUNLOG" "${E}/gate-mode-loglines.raw"
cat "${E}/gate-mode-loglines.txt"
grep -q 'gate_mode=blocking' "${E}/gate-mode-loglines.txt" \
  || { echo "ABORT(1): no 'gate_mode=blocking' line in run ${RUNID}'s own output." >&2; exit 1; }
echo "ok: gate_mode=blocking proven from the run's own log output"

# ---------------------------------------------------- close the window NOW
close_window
trap - EXIT

# ------------------------------------------- audit the window and persistence
say "Runs that started inside the window"
{
  echo ""
  echo "Blocking run id: ${RUNID}  (conclusion: ${RCONC})"
  echo "Head SHA under blocking: ${NEWSHA}"
  echo "Baseline head SHA:       ${BASELINE_SHA}"
  echo "Tree hash (both):        $(cat "${E}/tree-hash-blocking.txt")"
  echo ""
  echo "gh run list -R ${REPO} --json databaseId,createdAt,headBranch,workflowName --limit 30"
  echo "--- begin output ---"
  gh run list -R "$REPO" --json databaseId,createdAt,headBranch,workflowName --limit 30 \
    --jq '.[] | "\(.createdAt)  \(.databaseId)  \(.headBranch)  \(.workflowName)"'
  echo "--- end output ---"
  echo ""
  echo "Runs whose createdAt falls inside [${VAR_CREATED}, window end] are the exposed set."
  echo "Exactly one — this exercise's run ${RUNID} — is expected (Pitfall 5 / T-22-06)."
} >> "${E}/gate-window.txt"

say "Persistence: the red conclusion outlives the variable"
gh api "repos/${REPO}/commits/${NEWSHA}/check-runs" \
  --jq "[.check_runs[] | select(.app.id == ${APP_ID}) | {name, conclusion, status}]" \
  > "$POSTDEL"
cp "$POSTDEL" "${E}/check-runs-after-variable-deleted.json"
if diff "${E}/check-runs-unstable.json" "${E}/check-runs-after-variable-deleted.json"; then
  echo "ok: check runs identical AFTER GATE_MODE was deleted — measured, not asserted"
else
  echo "NOTE: check runs differ after delete; both captures retained for the SUMMARY." >&2
fi
rm -f "$POSTDEL"

say "Final assertions"
python3 - "$E" <<'PY'
import json, sys
E = sys.argv[1]
d = json.load(open(f"{E}/check-runs-unstable.json"))
assert len(d) == 5, f"expected 5 check runs, got {len(d)}"
f = [x for x in d if x["conclusion"] == "failure"]
if not f:
    print("!! ALL FIVE GREEN under blocking — assumption A4 is FALSIFIED.")
    print("!! The variable has already been deleted. Report to the operator; do NOT seed a finding.")
    sys.exit(1)
print("red:", [x["name"] for x in f])
PY
[ -z "$(gh variable list -R "$REPO")" ] || { echo "ABORT(1): variables still present" >&2; exit 1; }
RULES_END=$(gh api "repos/${REPO}/rules/branches/main" --jq '[.[].type]|sort|join(",")')
[ "$RULES_END" = "copilot_code_review,deletion,non_fast_forward" ] \
  || { echo "ABORT(1): ruleset changed to '${RULES_END}' — this plan writes no ruleset." >&2; exit 1; }
echo "ok: no variables remain; ruleset still ${RULES_END}"

say "DONE — hand these back to the executor"
echo "NEWSHA=${NEWSHA}"
echo "RUNID=${RUNID}  conclusion=${RCONC}"
echo "window: ${VAR_CREATED} -> see ${E}/gate-window.txt"
