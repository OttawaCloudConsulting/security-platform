#!/usr/bin/env bash
set -euo pipefail

# 22-poll-merge-state.sh — bounded settle-poll for GitHub's asynchronously
# computed pull-request mergeStateStatus.
#
# WHY THIS EXISTS. GitHub does not compute mergeability synchronously: the
# first query KICKS OFF a background job and frequently returns `UNKNOWN`, or
# returns the value from before the change you are trying to observe. Phase 22
# exists to witness a mergeStateStatus TRANSITION (UNSTABLE -> BLOCKED ->
# CLEAN) on one constant head SHA, so every read in this phase is a read of a
# value that may not have settled yet. A stale read is worse than no read: a
# stale `BLOCKED` is what makes a later `gh pr merge` succeed and land the
# exercise branch on a real repository's `main` (22-RESEARCH.md Pitfall 7).
#
# Every mergeStateStatus read in this phase goes through this script. Nothing
# in this phase reads `gh pr view --json mergeStateStatus` directly.
#
# USAGE (never set the executable bit on this file — project rule):
#   bash .planning/phases/22-.../22-poll-merge-state.sh <repo-slug> <pr-number> <previous-state>
#
#   <previous-state> is the value recorded BEFORE the change being observed,
#   or the empty string "" for a first read. It must be passed explicitly;
#   three arguments are always required, the third may be empty.
#
# On success the settled value, and ONLY the settled value, is printed to
# stdout. Every diagnostic goes to stderr, so callers may capture stdout
# directly into an evidence file.
#
# Environment:
#   POLL_ITERATIONS  number of reads         (default 20)
#   POLL_SLEEP       seconds between reads   (default 5)
#   Both exist so the failure paths can be exercised cheaply in a negative
#   test rather than being taken on faith.
#
# Exit codes — deliberately three, not two:
#   0  settled: the value is neither UNKNOWN nor equal to <previous-state>.
#      The value is on stdout.
#   1  did NOT settle usefully. Two distinguishable sub-cases, and the message
#      says which, because they call for different responses:
#        "never settled"        — still UNKNOWN when the budget ran out;
#                                 GitHub has not finished computing. Retry.
#        "settled but unchanged" — a real value, but identical to the value
#                                 passed in as <previous-state>. The change
#                                 you are observing has NOT been reflected
#                                 yet. Proceeding on this value is the stale
#                                 read that arms Pitfall 7. NEVER treat it as
#                                 a measurement.
#   2  the `gh` call itself failed (auth, network, no such PR). An
#      INFRASTRUCTURE problem, not a merge-state verdict. The two must never
#      be conflated and there is deliberately no fallback value: a silent
#      fallback is exactly the failure mode this gate exists to prevent.
#
# DESIGN NOTE. 22-RESEARCH.md:595-603 publishes a loop whose post-loop guard
# tests only `[ "$S" != UNKNOWN ]`. That guard PASSES when every iteration
# returned a stale prior value, which is the precise condition it needs to
# catch. 22-PATTERNS.md flags this as a defect. The post-loop assertion below
# is the corrected two-condition form and is the reason this file exists as a
# script rather than as an inlined snippet per task.

if [ "$#" -ne 3 ]; then
  echo "ABORT(2): usage: bash 22-poll-merge-state.sh <repo-slug> <pr-number> <previous-state>" >&2
  echo "          three arguments are required; pass \"\" as <previous-state> for a first read" >&2
  exit 2
fi

REPO="$1"
PR="$2"
PREV="$3"

POLL_ITERATIONS="${POLL_ITERATIONS:-20}"
POLL_SLEEP="${POLL_SLEEP:-5}"

S=""
for i in $(seq 1 "$POLL_ITERATIONS"); do
  if ! S=$(gh pr view "$PR" -R "$REPO" --json mergeStateStatus --jq .mergeStateStatus 2>&1); then
    echo "ABORT(2): gh pr view failed for PR #${PR} on ${REPO} (read ${i}/${POLL_ITERATIONS})." >&2
    echo "          gh output: ${S}" >&2
    exit 2
  fi
  echo "read ${i}/${POLL_ITERATIONS}: mergeStateStatus=${S} (previous='${PREV}')" >&2
  if [ "$S" != "UNKNOWN" ] && [ "$S" != "$PREV" ]; then
    break
  fi
  if [ "$i" -lt "$POLL_ITERATIONS" ]; then
    sleep "$POLL_SLEEP"
  fi
done

# POST-LOOP ASSERTION — both conditions, never just the first one.
if [ "$S" != "UNKNOWN" ] && [ "$S" != "$PREV" ]; then
  printf '%s\n' "$S"
  exit 0
fi

BUDGET=$(( (POLL_ITERATIONS - 1) * POLL_SLEEP ))
if [ "$S" = "UNKNOWN" ]; then
  echo "ABORT(1): never settled — mergeStateStatus was still UNKNOWN after ${POLL_ITERATIONS} reads over ~${BUDGET}s." >&2
  echo "          last observed: '${S}'   previous value passed in: '${PREV}'" >&2
  echo "          GitHub has not finished computing mergeability. This is NOT a verdict." >&2
else
  echo "ABORT(1): settled but unchanged — mergeStateStatus settled on '${S}' after ${POLL_ITERATIONS} reads over ~${BUDGET}s," >&2
  echo "          but that is identical to the previous value passed in: '${PREV}'." >&2
  echo "          last observed: '${S}'   previous value passed in: '${PREV}'" >&2
  echo "          The change being observed is not reflected yet. Using this value would be a STALE READ." >&2
fi
exit 1
