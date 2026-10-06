#!/usr/bin/env bash
set -euo pipefail
# errtrace: the ERR trap below (exit 2) must also fire inside functions.
set -E

# 29.6-pr.sh — Phase 29.6 plan 02: the non-race pull-request writes against the
# throwaway scratch repository: open | empty-commit | merge-attempt.
#
# NEVER set this file's executable bit. Run it as:
#
#   bash /Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-/29.6-pr.sh <subcommand> [args] [--dry-run]
#
# Subcommands (contract consumed by plans 05-10):
#   open          --clone-dir DIR --label L [--dry-run]
#   empty-commit  --clone-dir DIR --label L [--dry-run]
#   merge-attempt --pr N --sha S --out-prefix P [--dry-run]
#
# WHY THE OPERATOR RUNS THIS AND NOT THE AGENT.
# ADR-019 measured that the agent's permission classifier denies `gh pr create`,
# `gh pr merge`, `gh variable set` and `git push`. Every outward write in Phase
# 29.6 therefore lives in an operator-run script (D-07 style); the agent only
# verifies afterwards, by reads.
#
# Safety properties:
#   - every subcommand that pushes first asserts the clone's realpath is OUTSIDE
#     the planning repo and that its origin is exactly the scratch repo URL, so
#     the planning repository is never pushed (T-29.6-04)
#   - merge-attempt pins the head with --match-head-commit and NEVER passes the
#     admin-bypass flag, the auto-merge flag or the delete-branch flag
#     (T-29.6-05). gh's refusal text may suggest the auto-merge flag; ignore it —
#     it would queue the PR to merge the moment checks go green.
#   - merge-attempt captures stdout and stderr to SEPARATE files (D-19) and
#     refuses to overwrite an existing capture.
#
# Exit codes:
#   0  ok (merge-attempt: refused and the PR is still OPEN — the expected path)
#   1  a precondition failed; nothing was written
#   2  usage error, or a gh/git infrastructure failure
#   4  anomaly (merge-attempt: gh's rc and the PR state disagree)
#   9  THE MERGE WAS ACCEPTED (merge-attempt only) — see the banner it prints

REPO="OttawaCloudConsulting/sp-reopen-race-scratch"
REPO_URL="https://github.com/OttawaCloudConsulting/sp-reopen-race-scratch.git"
PLANNING_ROOT="/Users/christian/git-repos/OCC-github/development_environment/security_solution"
PD="${PLANNING_ROOT}/.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-"
E="${PD}/evidence"
PRS_LOG="${E}/29.6-prs.jsonl"

on_err() {
  echo "INFRA FAILURE(2): command failed at line $1 of 29.6-pr.sh. State may be partial." >&2
  exit 2
}
trap 'on_err $LINENO' ERR

usage() {
  echo "usage: bash ${PD}/29.6-pr.sh open          --clone-dir DIR --label L [--dry-run]" >&2
  echo "       bash ${PD}/29.6-pr.sh empty-commit  --clone-dir DIR --label L [--dry-run]" >&2
  echo "       bash ${PD}/29.6-pr.sh merge-attempt --pr N --sha S --out-prefix P [--dry-run]" >&2
  exit 2
}

realpath_py() {
  python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1"
}

# BSD date prints %3N literally; python is the only timestamp source.
now_ms() {
  python3 -c 'import datetime;print(datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="milliseconds"))'
}

# json_line KEY=VALUE ... -> one compact JSON object (values are strings,
# except "pr" which is emitted as an integer).
json_line() {
  python3 -c '
import json, sys
d = {}
for kv in sys.argv[1:]:
    k, v = kv.split("=", 1)
    d[k] = int(v) if k == "pr" else v
print(json.dumps(d, separators=(",", ":")))
' "$@"
}

run_write() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: $*"
  else
    echo "+ $*"
    "$@"
  fi
}

# Guard for every subcommand that touches a clone: outside planning repo, is a
# git work tree, origin is exactly the scratch repo.
assert_clone() {
  local dir="$1"
  local planning_real clone_real origin
  planning_real=$(realpath_py "$PLANNING_ROOT")
  clone_real=$(realpath_py "$dir")
  case "$clone_real" in
    "$planning_real"*)
      echo "ABORT(1): clone dir ${clone_real} is inside the planning repo (${planning_real})."
      exit 1 ;;
  esac
  if [ ! -d "${dir}/.git" ]; then
    echo "ABORT(1): ${dir} is not a git clone (no .git directory)."
    exit 1
  fi
  origin=$(git -C "$dir" remote get-url origin)
  if [ "$origin" != "$REPO_URL" ]; then
    echo "ABORT(1): origin of ${dir} is '${origin}', not '${REPO_URL}'. Refusing to push."
    exit 1
  fi
  echo "  ok: clone ${clone_real} is outside the planning repo; origin = ${origin}"
}

validate_label() {
  case "$1" in
    ""|*[!A-Za-z0-9._-]*)
      echo "usage(2): --label must match [A-Za-z0-9._-]+ (it becomes a branch and a filename); got '$1'" >&2
      exit 2 ;;
  esac
}

[ "$#" -ge 1 ] || usage
SUB="$1"; shift

CLONE_DIR=""; LABEL=""; PR=""; SHA=""; OUT_PREFIX=""; DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --clone-dir)  [ "$#" -ge 2 ] || usage; CLONE_DIR="$2"; shift 2 ;;
    --label)      [ "$#" -ge 2 ] || usage; LABEL="$2"; shift 2 ;;
    --pr)         [ "$#" -ge 2 ] || usage; PR="$2"; shift 2 ;;
    --sha)        [ "$#" -ge 2 ] || usage; SHA="$2"; shift 2 ;;
    --out-prefix) [ "$#" -ge 2 ] || usage; OUT_PREFIX="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=1; shift ;;
    *)            usage ;;
  esac
done

# =============================================================================
cmd_open() {
  [ -n "$CLONE_DIR" ] && [ -n "$LABEL" ] || usage
  validate_label "$LABEL"
  local branch="race/${LABEL}"
  echo "=== 29.6-pr open — label ${LABEL} ==="
  assert_clone "$CLONE_DIR"

  local ts
  ts=$(now_ms)
  run_write git -C "$CLONE_DIR" fetch origin
  run_write git -C "$CLONE_DIR" checkout -b "$branch" origin/main
  run_write mkdir -p "${CLONE_DIR}/attempts"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: write ${CLONE_DIR}/attempts/${LABEL}.txt <- '${LABEL} ${ts}'"
  else
    printf '%s %s\n' "$LABEL" "$ts" > "${CLONE_DIR}/attempts/${LABEL}.txt"
  fi
  run_write git -C "$CLONE_DIR" add "attempts/${LABEL}.txt"
  run_write git -C "$CLONE_DIR" commit -m "29.6 attempt ${LABEL}"
  run_write git -C "$CLONE_DIR" push -u origin "$branch"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: gh pr create -R ${REPO} --base main --head ${branch} --title \"29.6 race ${LABEL}\" --body \"Phase 29.6 throwaway PR ${LABEL}\""
    echo "DRY-RUN: append {label,pr,branch,head_sha,ts,action:open} to ${PRS_LOG}"
    return 0
  fi

  local url pr head line
  url=$(gh pr create -R "$REPO" --base main --head "$branch" --title "29.6 race ${LABEL}" --body "Phase 29.6 throwaway PR ${LABEL}")
  echo "PR URL: ${url}"
  pr="${url##*/}"
  case "$pr" in
    ""|*[!0-9]*)
      echo "ANOMALY(4): could not parse a PR number from '${url}'. The PR may exist; check before re-running."
      exit 4 ;;
  esac
  head=$(git -C "$CLONE_DIR" rev-parse HEAD)
  line=$(json_line "label=${LABEL}" "pr=${pr}" "branch=${branch}" "head_sha=${head}" "ts=$(now_ms)" "action=open")
  printf '%s\n' "$line" >> "$PRS_LOG"
  printf '%s\n' "$line"
}

# =============================================================================
cmd_empty_commit() {
  [ -n "$CLONE_DIR" ] && [ -n "$LABEL" ] || usage
  validate_label "$LABEL"
  local branch="race/${LABEL}"
  echo "=== 29.6-pr empty-commit — label ${LABEL} ==="
  assert_clone "$CLONE_DIR"

  run_write git -C "$CLONE_DIR" checkout "$branch"
  run_write git -C "$CLONE_DIR" pull --ff-only

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: prev_sha=\$(git -C ${CLONE_DIR} rev-parse HEAD)"
    echo "DRY-RUN: git -C ${CLONE_DIR} commit --allow-empty -m \"29.6 retrigger ${LABEL}\""
    echo "DRY-RUN: git -C ${CLONE_DIR} push"
    echo "DRY-RUN: append {label,branch,head_sha,prev_sha,ts,action:empty-commit} to ${PRS_LOG}"
    return 0
  fi

  local prev head line
  prev=$(git -C "$CLONE_DIR" rev-parse HEAD)
  run_write git -C "$CLONE_DIR" commit --allow-empty -m "29.6 retrigger ${LABEL}"
  run_write git -C "$CLONE_DIR" push
  head=$(git -C "$CLONE_DIR" rev-parse HEAD)
  if [ "$head" = "$prev" ]; then
    echo "ANOMALY(4): HEAD did not move (${head}) after the empty commit."
    exit 4
  fi
  line=$(json_line "label=${LABEL}" "branch=${branch}" "head_sha=${head}" "prev_sha=${prev}" "ts=$(now_ms)" "action=empty-commit")
  printf '%s\n' "$line" >> "$PRS_LOG"
  printf '%s\n' "$line"
}

# =============================================================================
cmd_merge_attempt() {
  [ -n "$PR" ] && [ -n "$SHA" ] && [ -n "$OUT_PREFIX" ] || usage
  case "$PR" in ""|*[!0-9]*) echo "usage(2): --pr must be numeric; got '${PR}'" >&2; exit 2 ;; esac
  case "$SHA" in
    *[!0-9a-f]*) echo "usage(2): --sha must be lowercase hex; got '${SHA}'" >&2; exit 2 ;;
  esac
  if [ "${#SHA}" -lt 7 ] || [ "${#SHA}" -gt 40 ]; then
    echo "usage(2): --sha must be 7-40 hex chars; got ${#SHA}" >&2
    exit 2
  fi

  local f_out="${OUT_PREFIX}-stdout.txt" f_err="${OUT_PREFIX}-stderr.txt"
  local f_rc="${OUT_PREFIX}-rc.txt" f_after="${OUT_PREFIX}-pr-after.json"

  echo "=== 29.6-pr merge-attempt — PR #${PR} head ${SHA} ==="
  if [ ! -d "$(dirname "$OUT_PREFIX")" ]; then
    echo "ABORT(1): output directory $(dirname "$OUT_PREFIX") does not exist."
    exit 1
  fi
  for f in "$f_out" "$f_err" "$f_rc" "$f_after"; do
    if [ -e "$f" ]; then
      echo "ABORT(1): ${f} already exists. Refusing to overwrite evidence; choose a new --out-prefix."
      exit 1
    fi
  done

  # Dry-run makes zero gh calls.
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: gh pr merge ${PR} -R ${REPO} --squash --match-head-commit ${SHA} >${f_out} 2>${f_err}"
    echo "DRY-RUN: echo \$? >${f_rc}"
    echo "DRY-RUN: gh pr view ${PR} -R ${REPO} --json state,mergedAt,mergeCommit,headRefOid >${f_after}"
    echo "=== dry-run complete; nothing was written ==="
    return 0
  fi

  # The attempt is EXPECTED to exit non-zero. errexit and the ERR trap are lifted
  # only across it; the rc is captured explicitly and asserted below.
  local rc
  trap - ERR
  set +e
  gh pr merge "$PR" -R "$REPO" --squash --match-head-commit "$SHA" >"$f_out" 2>"$f_err"
  rc=$?
  set -e
  trap 'on_err $LINENO' ERR
  printf '%s\n' "$rc" > "$f_rc"
  echo "gh pr merge rc: ${rc}"
  echo "--- stdout ($(basename "$f_out")) ---"; cat "$f_out"
  echo "--- stderr ($(basename "$f_err")) ---"; cat "$f_err"

  # Post-read, fresh, not from the command's own output.
  gh pr view "$PR" -R "$REPO" --json state,mergedAt,mergeCommit,headRefOid > "$f_after"
  echo "pr-after: $(cat "$f_after")"
  local state
  state=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["state"])' "$f_after")

  if [ "$state" = "MERGED" ]; then
    echo
    echo "########################################################################"
    echo "## THE MERGE SUCCEEDED. THE GATE DID NOT HOLD. STOP.                  ##"
    echo "## PR #${PR} state=${state} (gh rc=${rc})"
    echo "## Do not run anything else. Report this immediately.                ##"
    echo "########################################################################"
    exit 9
  fi
  if [ "$rc" -eq 0 ]; then
    echo "ANOMALY(4): gh pr merge returned 0 but PR #${PR} is ${state}, not MERGED."
    exit 4
  fi
  if [ "$state" != "OPEN" ]; then
    echo "ANOMALY(4): merge refused (rc ${rc}) but PR #${PR} is ${state}, not OPEN."
    exit 4
  fi
  echo "=== REFUSED as expected (rc ${rc}); PR #${PR} still OPEN ==="
  return 0
}

case "$SUB" in
  open)          cmd_open ;;
  empty-commit)  cmd_empty_commit ;;
  merge-attempt) cmd_merge_attempt ;;
  *)             usage ;;
esac
exit 0
