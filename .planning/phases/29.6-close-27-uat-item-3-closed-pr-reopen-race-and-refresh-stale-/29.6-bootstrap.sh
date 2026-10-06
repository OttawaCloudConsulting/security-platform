#!/usr/bin/env bash
set -euo pipefail
# errtrace: the ERR trap below (exit 2) must also fire inside functions.
set -E

# 29.6-bootstrap.sh — Phase 29.6 plan 02: create the PRIVATE throwaway scratch
# repository and push the 29.6-seed/ content to its main branch.
#
# NEVER set this file's executable bit. Run it as:
#
#   bash /Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-/29.6-bootstrap.sh --clone-dir DIR [--dry-run]
#
# DIR must not exist and must lie OUTSIDE the planning repository (e.g.
# /private/tmp/sp-reopen-race-scratch). Rehearse with --dry-run first: it runs
# every read-only precondition and prints each write prefixed DRY-RUN:.
#
# WHY THE OPERATOR RUNS THIS AND NOT THE AGENT.
# ADR-019 measured that the agent's permission classifier denies `gh pr create`,
# `gh pr merge`, `gh variable set` and `git push`. Every outward write in Phase
# 29.6 therefore lives in an operator-run script (D-07 style); the agent only
# verifies afterwards, by reads. This script is the repo-create + first-push half
# of that split. It is fail-closed: every precondition is checked before the
# first write, and the push is preceded by an explicit assertion that the clone's
# origin is the scratch repo, so the planning repository is never pushed
# (T-29.6-04).
#
# Exit codes:
#   0  ok (or dry-run completed)
#   1  a precondition failed; nothing was written
#   2  usage error, or a gh/git infrastructure failure (state may be partial —
#      read the line number printed and inspect before re-running)

REPO="OttawaCloudConsulting/sp-reopen-race-scratch"
REPO_URL="https://github.com/OttawaCloudConsulting/sp-reopen-race-scratch.git"
EXPECTED_OWNER="OttawaCloudConsulting"
PLANNING_ROOT="/Users/christian/git-repos/OCC-github/development_environment/security_solution"
PD="${PLANNING_ROOT}/.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-"
SEED="${PD}/29.6-seed"

on_err() {
  echo "INFRA FAILURE(2): command failed at line $1 of 29.6-bootstrap.sh. State may be partial." >&2
  exit 2
}
trap 'on_err $LINENO' ERR

usage() {
  echo "usage: bash ${PD}/29.6-bootstrap.sh --clone-dir DIR [--dry-run]" >&2
  exit 2
}

realpath_py() {
  python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1"
}

# ---- argument parsing --------------------------------------------------------
CLONE_DIR=""
DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --clone-dir) [ "$#" -ge 2 ] || usage; CLONE_DIR="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    *)           usage ;;
  esac
done
[ -n "$CLONE_DIR" ] || usage

# run_write: execute a write, or print it under --dry-run.
run_write() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: $*"
  else
    echo "+ $*"
    "$@"
  fi
}

echo "=== 29.6-bootstrap — preconditions (nothing is written until all pass) ==="

# ---- Precondition 1 (offline): clone dir is NOT inside the planning repo -----
PLANNING_REAL=$(realpath_py "$PLANNING_ROOT")
CLONE_PARENT_REAL=$(realpath_py "$(dirname "$CLONE_DIR")")
CLONE_REAL=$(realpath_py "$CLONE_DIR")
echo "clone dir (realpath)       : ${CLONE_REAL}"
echo "clone parent (realpath)    : ${CLONE_PARENT_REAL}"
case "$CLONE_PARENT_REAL" in
  "$PLANNING_REAL"*)
    echo "ABORT(1): the clone dir's parent is inside the planning repo (${PLANNING_REAL})."
    echo "          A scratch clone there could push planning content. Choose a dir outside it."
    exit 1 ;;
esac
case "$CLONE_REAL" in
  "$PLANNING_REAL"*)
    echo "ABORT(1): the clone dir is inside the planning repo (${PLANNING_REAL})."
    exit 1 ;;
esac
echo "  ok: clone dir is outside the planning repo"

# ---- Precondition 2 (offline): clone dir does not exist ----------------------
if [ -e "$CLONE_DIR" ]; then
  echo "ABORT(1): ${CLONE_DIR} already exists. Refusing to reuse it."
  exit 1
fi
echo "  ok: clone dir does not exist"

# ---- Precondition 3 (offline): seed files present ----------------------------
for f in pr-security.yml Dockerfile README.md; do
  if [ ! -f "${SEED}/${f}" ]; then
    echo "ABORT(1): seed file missing: ${SEED}/${f}"
    exit 1
  fi
done
echo "  ok: seed files present in ${SEED}"

# ---- Precondition 4 (read): authenticated as the expected personal account ---
LOGIN=$(gh api user --jq .login)
OWNER_TYPE=$(gh api "users/${EXPECTED_OWNER}" --jq .type)
echo "gh login                   : ${LOGIN}"
echo "${EXPECTED_OWNER} type     : ${OWNER_TYPE}"
if [ "$LOGIN" != "$EXPECTED_OWNER" ]; then
  echo "ABORT(1): gh is authenticated as '${LOGIN}', not '${EXPECTED_OWNER}' (D-20)."
  exit 1
fi
if [ "$OWNER_TYPE" != "User" ]; then
  echo "ABORT(1): ${EXPECTED_OWNER} type is '${OWNER_TYPE}', expected 'User' (D-20)."
  exit 1
fi
echo "  ok: authenticated as ${LOGIN} (type User)"

# ---- Precondition 5 (read): the scratch repo does NOT exist yet (clean 404) --
# This read is EXPECTED to fail. errexit and the ERR trap are lifted only across
# it; the rc and the combined output are captured and asserted explicitly.
trap - ERR
set +e
PROBE_OUT=$(gh api "repos/${REPO}" 2>&1)
PROBE_RC=$?
set -e
trap 'on_err $LINENO' ERR
echo "gh api repos/${REPO} rc    : ${PROBE_RC}"
if [ "$PROBE_RC" -eq 0 ]; then
  echo "ABORT(1): ${REPO} already exists. Delete it (D-06) or investigate before re-running."
  exit 1
fi
case "$PROBE_OUT" in
  *"HTTP 404"*) echo "  ok: ${REPO} does not exist (HTTP 404)" ;;
  *)
    echo "INFRA FAILURE(2): the existence probe failed for a reason other than a clean 404:"
    echo "$PROBE_OUT"
    exit 2 ;;
esac

# ---- Act ---------------------------------------------------------------------
echo
echo "=== 29.6-bootstrap — writes ==="

# D-04: private first. Visibility is changed only by a later, separate step.
run_write gh repo create "$REPO" --private --description "Phase 29.6 throwaway; delete after evidence (D-06)"
run_write git init -b main "$CLONE_DIR"
run_write mkdir -p "${CLONE_DIR}/.github/workflows"
run_write cp "${SEED}/pr-security.yml" "${CLONE_DIR}/.github/workflows/pr-security.yml"
run_write cp "${SEED}/Dockerfile" "${CLONE_DIR}/Dockerfile"
run_write cp "${SEED}/README.md" "${CLONE_DIR}/README.md"
run_write git -C "$CLONE_DIR" add .github/workflows/pr-security.yml Dockerfile README.md
run_write git -C "$CLONE_DIR" commit -m "seed: Mode B caller + minimal Dockerfile"
run_write git -C "$CLONE_DIR" remote add origin "$REPO_URL"

# ---- Push guard: origin MUST be the scratch repo (T-29.6-04) -----------------
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY-RUN: assert \`git -C ${CLONE_DIR} remote get-url origin\` = ${REPO_URL}"
else
  ORIGIN=$(git -C "$CLONE_DIR" remote get-url origin)
  if [ "$ORIGIN" != "$REPO_URL" ]; then
    echo "ABORT(1): origin is '${ORIGIN}', not '${REPO_URL}'. Refusing to push."
    exit 1
  fi
  echo "  ok: origin = ${ORIGIN}"
fi
run_write git -C "$CLONE_DIR" push -u origin main

# ---- Readback ----------------------------------------------------------------
echo
echo "=== 29.6-bootstrap — readback ==="
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY-RUN: gh repo view ${REPO} --json visibility,owner,defaultBranchRef,isPrivate"
  echo "=== dry-run complete; nothing was written ==="
else
  gh repo view "$REPO" --json visibility,owner,defaultBranchRef,isPrivate
  echo "=== bootstrap complete ==="
fi
exit 0
