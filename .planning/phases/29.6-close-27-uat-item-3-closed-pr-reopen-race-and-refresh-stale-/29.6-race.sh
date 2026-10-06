#!/usr/bin/env bash
set -euo pipefail
set -E

# 29.6-race.sh — Phase 29.6 plan 04: the operator-run closed-PR reopen race
# driver (D-07, D-08, D-09, D-18, D-19).
#
# NEVER set this file's executable bit. Run it as one absolute-path command:
#
#   bash /Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-/29.6-race.sh --variant a|b --attempt LABEL:PR [--attempt LABEL:PR ...] [--dry-run]
#
# One absolute-path invocation, deliberately (the 22-04 lesson): a pasted
# multi-line continuation can fail to parse and return 127, so the script
# never runs. A single token cannot line-wrap.
#
# WHY THIS IS AN OPERATOR-RUN SCRIPT AND NOT PASTED COMMANDS.
# The race window being measured is seconds wide: a closed pull request is
# reopened and a merge is attempted while the reopen run's required checks
# are still queued or in progress, and the newest check run on every
# required context is the close run's `skipped`. Typing close, reopen and
# merge by hand would add operator timing as an uncontrolled variable.
# `gh pr merge` is also a WRITE with no dry-run (22-RESEARCH Pitfall 7), so
# the guards that make each attempt valid must travel in the same execution
# as the writes. This script runs close, reopen and merge back to back,
# logs an ISO-ms timestamp, mergeStateStatus/mergeable and the head SHA's
# check runs at each step, and hands the attempt directory to the
# pre-committed offline verdict (29.6-verdict.sh).
#
# VARIANTS (D-08):
#   a  close; wait (poll every 2 s, cap 120 s) until close_run_detect shows
#      the close run completed and owning every context's newest check run;
#      snap pre-reopen; then reopen and merge immediately.
#   b  close, reopen and merge with no wait and no snap in between.
# Up to three --attempt LABEL:PR pairs (D-09), one fresh PR each, run in
# argument order. The script stops at the first attempt whose verdict exit is
# non-zero.
#
# MITIGATIONS (numbered, the 22-04 shape):
#   1. D-18 PRE-CLOSE GUARD, all reads, exit 1 with nothing written to GitHub
#      when any fails: evidence/29.6-race-target.json has proceed == true and
#      names the ruleset file; GATE_MODE is blocking; required_status_checks
#      is in force on main; the ruleset has bypass_actors [] and
#      current_user_can_bypass never; the PR is OPEN; all five newest check
#      runs are completed with at least one failure; the settled
#      mergeStateStatus is BLOCKED.
#   2. THE 22-04 GUARD IS INVERTED. 22-04 asserted BLOCKED immediately before
#      its merge. Here BLOCKED is asserted only BEFORE `gh pr close`. Nothing
#      asserts state between reopen and merge, because the post-reopen
#      unsettled state is exactly what is being measured.
#   3. D-19 (overrides research Pattern 5's "no read between reopen and
#      merge"): exactly ONE `gh pr view` read of mergeStateStatus, mergeable
#      and headRefOid sits between reopen and merge, timestamped on both
#      sides. It is recorded, never asserted.
#   4. DELIBERATE D-07 DEVIATION (ADR-033 cites this): there is NO check-runs
#      read between reopen and merge, only the single D-19 state read, to
#      keep the window narrow. The check runs are read in the post-merge snap.
#   5. The merge is `gh pr merge --squash --match-head-commit <head SHA>`
#      only. The match-head-commit pin means the merge cannot land a head
#      that moved after the guard. The admin-bypass flag, the auto-merge flag
#      and the delete-branch flag are NEVER passed; the flag literals are
#      deliberately absent from this file. gh's refusal text may suggest the
#      auto-merge flag: DO NOT follow that hint. It would queue the PR to
#      merge on its own later.
#   6. stdout and stderr of the merge are captured to separate files
#      (merge-stdout.txt, merge-stderr.txt); the verdict classifies the
#      refusal from stderr verbatim (client-side vs server-side, D-19).
#   7. No silent fallbacks: any unexpected gh/jq failure exits 2 through the
#      ERR trap. errexit and the ERR trap are lifted only across commands that
#      are expected to return non-zero, and their rc is captured explicitly.
#      Timestamps come only from python3 (iso_now), never from the shell's
#      date utility.
#   8. Evidence is never overwritten: an existing attempt directory refuses
#      the attempt (exit 1). A retry needs a new label.
#   9. --dry-run makes no GitHub call at all (gh is replaced by a tripwire
#      function that exits 2), creates no attempt directory, and does not open
#      evidence/29.6-05-contexts.json, evidence/29.6-race-target.json or any
#      29.6-07-ruleset-created*.json. It prints every write as `DRY-RUN:` with
#      the placeholders <HEAD_SHA>, <RULESET_ID> and <CONTEXT_1>..<CONTEXT_5>.
#
# ATTEMPT DIRECTORY (plan 03 contract, read by 29.6-verdict.sh):
#   evidence/29.6-race-<label>/ meta.json timeline.jsonl merge-stdout.txt
#   merge-stderr.txt checkruns-final.json runs.json pr-after.json
#   pr-timeline.json, then verdict.json written by the verdict.
#   The directory is created only after every pre-close guard passed, so an
#   exit 1 leaves nothing on disk and the label stays usable.
#
# ENVIRONMENT (optional overrides):
#   POLL_DETECT_ITERATIONS (60) POLL_DETECT_SLEEP (2)   variant a detector wait
#   SETTLE_ITERATIONS (120)     SETTLE_SLEEP (3)        post-merge settle snaps
#   POLL_ITERATIONS / POLL_SLEEP                        29.6-snap.sh pre-close settle
#
# Exit codes:
#   0  every attempt was BLOCKED (verdict exit 0) — the expected path
#   1  a precondition failed (that attempt's PR untouched), or the verdict
#      ruled the attempt invalid
#   2  usage error or gh/jq infrastructure failure (state may be partial;
#      read the attempt directory and the PR before doing anything else)
#   3  variant (a) detector timeout. The PR is LEFT CLOSED and was NOT
#      reopened. Report it; do not reopen it blindly.
#   4  anomaly (verdict exit 4)
#   9  THE MERGE WAS ACCEPTED = RACE LOST = D-11 STOP. See the banner.

R="OttawaCloudConsulting/sp-reopen-race-scratch"
PLANNING_ROOT="/Users/christian/git-repos/OCC-github/development_environment/security_solution"
PD="${PLANNING_ROOT}/.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-"
E="${PD}/evidence"

on_err() {
  echo "INFRA FAILURE(2): command failed at line $1 of 29.6-race.sh. State may be partial;" >&2
  echo "                  read the attempt directory and the PR state before doing anything else." >&2
  exit 2
}
trap 'on_err $LINENO' ERR

usage() {
  echo "usage: bash ${PD}/29.6-race.sh --variant a|b --attempt LABEL:PR [--attempt LABEL:PR ...] [--dry-run]" >&2
  echo "       up to three --attempt pairs; LABEL matches [A-Za-z0-9._-]+, PR is a positive integer" >&2
  exit 2
}

# ---- argument parsing: total before anything else runs ----------------------
VARIANT=""
DRY_RUN=0
ATTEMPTS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --variant) [ "$#" -ge 2 ] || usage; VARIANT="$2"; shift 2 ;;
    --attempt) [ "$#" -ge 2 ] || usage; ATTEMPTS+=("$2"); shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) usage ;;
  esac
done

case "$VARIANT" in
  a | b) : ;;
  *) echo "usage(2): --variant must be a or b; got '${VARIANT}'" >&2; usage ;;
esac
if [ "${#ATTEMPTS[@]}" -lt 1 ] || [ "${#ATTEMPTS[@]}" -gt 3 ]; then
  echo "usage(2): between one and three --attempt LABEL:PR pairs are required (D-09); got ${#ATTEMPTS[@]}" >&2
  usage
fi

LABELS=()
PRNUMS=()
for pair in "${ATTEMPTS[@]}"; do
  case "$pair" in
    *:*) : ;;
    *) echo "usage(2): --attempt must be LABEL:PR; got '${pair}'" >&2; usage ;;
  esac
  lbl="${pair%%:*}"
  num="${pair#*:}"
  case "$lbl" in
    "" | *[!A-Za-z0-9._-]*) echo "usage(2): LABEL must match [A-Za-z0-9._-]+ (it becomes a directory name); got '${lbl}'" >&2; usage ;;
  esac
  case "$num" in
    "" | *[!0-9]* | 0*) echo "usage(2): PR must be a positive integer; got '${num}'" >&2; usage ;;
  esac
  for seen in "${LABELS[@]+"${LABELS[@]}"}"; do
    if [ "$seen" = "$lbl" ]; then
      echo "usage(2): label '${lbl}' given twice" >&2
      usage
    fi
  done
  for seen in "${PRNUMS[@]+"${PRNUMS[@]}"}"; do
    if [ "$seen" = "$num" ]; then
      echo "usage(2): PR ${num} given twice; each attempt needs its own fresh PR (D-09)" >&2
      usage
    fi
  done
  LABELS+=("$lbl")
  PRNUMS+=("$num")
done

# shellcheck source=29.6-snap.sh
source "${PD}/29.6-snap.sh"

# ---- shared helpers ---------------------------------------------------------
abort1() {
  echo "ABORT(1): $*"
  echo "          Nothing was written to GitHub for this attempt; its PR is untouched."
  exit 1
}

DETECT_N="${POLL_DETECT_ITERATIONS:-60}"
DETECT_S="${POLL_DETECT_SLEEP:-2}"
SETTLE_N="${SETTLE_ITERATIONS:-120}"
SETTLE_S="${SETTLE_SLEEP:-3}"
for v in "$DETECT_N" "$DETECT_S" "$SETTLE_N" "$SETTLE_S"; do
  case "$v" in "" | *[!0-9]*) echo "usage(2): POLL_DETECT_*/SETTLE_* must be non-negative integers; got '${v}'" >&2; exit 2 ;; esac
done

# ---- DRY-RUN ----------------------------------------------------------------
dry_run_attempt() { # LABEL PR
  local lbl="$1" n="$2" dir ctx
  dir="${E}/29.6-race-${lbl}"
  ctx='["<CONTEXT_1>","<CONTEXT_2>","<CONTEXT_3>","<CONTEXT_4>","<CONTEXT_5>"]'
  echo
  echo "=== 29.6-race DRY-RUN: variant ${VARIANT}, attempt ${lbl}, PR #${n} ==="
  if [ -e "$dir" ]; then
    echo "ABORT(1): ${dir} already exists. Refusing to overwrite evidence; use a new label."
    exit 1
  fi
  echo "  ok: attempt dir ${dir} does not exist (it is NOT created under --dry-run)"
  echo "  pre-close guard the live run checks, in order (reads only; exit 1 on any failure, nothing written):"
  echo "    P1 ${E}/29.6-race-target.json exists and .proceed == true (D-04/D-20)"
  echo "    P2 RULESET_ID = .id of evidence/<.ruleset_created_file>, which must be 29.6-07-ruleset-created.json or 29.6-07-ruleset-created-public.json -> <RULESET_ID>"
  echo "    P3 CONTEXTS_JSON = ${E}/29.6-05-contexts.json, exactly five names -> ${ctx}"
  echo "    P4 gh variable get GATE_MODE -R ${R}  == blocking"
  echo "    P5 gh api repos/${R}/rules/branches/main --jq '[.[].type]'  contains required_status_checks"
  echo "    P6 gh api repos/${R}/rulesets/<RULESET_ID>  bypass_actors == [] and current_user_can_bypass == never"
  echo "    P7 pr_state ${R} ${n}  state OPEN; SHA := headRefOid -> <HEAD_SHA>"
  echo "    P8 newest_per_context ${R} <HEAD_SHA> CONTEXTS_JSON  five completed, none missing, >= 1 failure"
  echo "    P9 settle_merge_state ${R} ${n} \"\"  == BLOCKED  (pre-close only: the 22-04 guard inverted)"
  echo "  then: mkdir attempt dir; meta.json; snap pre-close -> timeline.jsonl; PRE_SUITES := pre-close suite ids"
  echo "DRY-RUN: gh pr close ${n} -R ${R}"
  if [ "$VARIANT" = "a" ]; then
    echo "DRY-RUN: wait close_run_detect ${R} <HEAD_SHA> <PRE_SUITES> ${ctx} (every ${DETECT_S} s, up to ${DETECT_N} reads; timeout -> exit 3, PR left CLOSED)"
    echo "  then: snap pre-reopen -> timeline.jsonl"
  fi
  echo "DRY-RUN: gh pr reopen ${n} -R ${R}"
  echo "DRY-RUN: gh pr view ${n} -R ${R} --json mergeStateStatus,mergeable,headRefOid   (D-19: the single read between reopen and merge; recorded, not asserted)"
  echo "DRY-RUN: gh pr merge ${n} -R ${R} --squash --match-head-commit <HEAD_SHA> >${dir}/merge-stdout.txt 2>${dir}/merge-stderr.txt"
  echo "  then: snap post-merge; gh pr view ${n} -R ${R} --json state,mergedAt,mergeCommit,headRefOid >pr-after.json"
  echo "  then: snap settle-<n> every ${SETTLE_S} s up to ${SETTLE_N} times until the reopen suite completes; snap final"
  echo "  then: checkruns-final.json, runs.json, pr-timeline.json (gh api repos/${R}/issues/${n}/timeline --paginate --slurp), meta.json"
  echo "DRY-RUN: bash ${PD}/29.6-verdict.sh ${dir}"
  echo "  then: verdict exit 0 -> next attempt; 9 -> RACE LOST banner, exit 9; other non-zero -> stop with that code"
}

if [ "$DRY_RUN" -eq 1 ]; then
  # Tripwire: under --dry-run nothing may reach GitHub. Any gh call is a bug.
  gh() {
    echo "TRIPWIRE(2): gh was invoked under --dry-run (gh $*). This is a bug in 29.6-race.sh." >&2
    exit 2
  }
  echo "=== 29.6-race.sh DRY-RUN: variant ${VARIANT}, ${#LABELS[@]} attempt(s), repo ${R} ==="
  echo "no GitHub reads or writes; no attempt directory; live-input files are not opened"
  for i in "${!LABELS[@]}"; do
    dry_run_attempt "${LABELS[$i]}" "${PRNUMS[$i]}"
  done
  echo
  echo "=== dry-run complete; nothing was read from or written to GitHub ==="
  exit 0
fi

# ---- LIVE -------------------------------------------------------------------
ATT_DIR=""
META='{}'

meta_write() {
  printf '%s\n' "$META" | jq . >"${ATT_DIR}/meta.json"
}

meta_json() { # key json-value
  META=$(jq -c --arg k "$1" --argjson v "$2" '.[$k] = $v' <<<"$META")
  meta_write
}

meta_str() { # key string-value
  META=$(jq -c --arg k "$1" --arg v "$2" '.[$k] = $v' <<<"$META")
  meta_write
}

append_snap() { # label -> appends one line to timeline.jsonl, echoes it on stdout
  local line
  line=$(snap "$1")
  printf '%s\n' "$line" >>"${ATT_DIR}/timeline.jsonl"
  printf '%s\n' "$line"
}

read_live_inputs() { # sets RULESET_FILE RULESET_ID CONTEXTS_JSON
  local target="${E}/29.6-race-target.json" cf="${E}/29.6-05-contexts.json"
  [ -f "$target" ] || abort1 "${target} does not exist. Plan 15 has not written the race target (D-04/D-20)."
  if ! jq -e '.proceed == true' "$target" >/dev/null; then
    abort1 "${target} does not have .proceed == true. The race may not start (D-04/D-20)."
  fi
  RULESET_FILE=$(jq -r '.ruleset_created_file' "$target")
  case "$RULESET_FILE" in
    29.6-07-ruleset-created.json | 29.6-07-ruleset-created-public.json) : ;;
    *) abort1 "race target names ruleset_created_file '${RULESET_FILE}', not a 29.6-07-ruleset-created*.json file." ;;
  esac
  [ -f "${E}/${RULESET_FILE}" ] || abort1 "${E}/${RULESET_FILE} does not exist."
  RULESET_ID=$(jq -r '.id' "${E}/${RULESET_FILE}")
  case "$RULESET_ID" in
    "" | *[!0-9]*) abort1 "ruleset id read from ${RULESET_FILE} is '${RULESET_ID}', not numeric." ;;
  esac
  [ -f "$cf" ] || abort1 "${cf} does not exist. Plan 05 has not derived the five contexts (D-01)."
  if ! jq -e 'type == "array" and length == 5 and all(.[]; type == "string")' "$cf" >/dev/null; then
    abort1 "${cf} is not a JSON array of exactly five strings."
  fi
  CONTEXTS_JSON=$(jq -c '.' "$cf")
}

run_attempt() { # LABEL PR
  LABEL="$1"
  PR="$2"
  SHA=""
  ATT_DIR="${E}/29.6-race-${LABEL}"
  local tmpf

  echo
  echo "=== 29.6-race: variant ${VARIANT}, attempt ${LABEL}, PR #${PR} — pre-close guard (D-18) ==="
  if [ -e "$ATT_DIR" ]; then
    echo "ABORT(1): ${ATT_DIR} already exists. Refusing to overwrite evidence; use a new label."
    exit 1
  fi

  read_live_inputs
  echo "  ok: race target proceed == true; ruleset ${RULESET_ID} (${RULESET_FILE})"
  echo "  ok: contexts ${CONTEXTS_JSON}"

  local gate_mode rule_types rs bypass_actors cucb prs pr_st newest mss pre_line pre_suites
  gate_mode=$(gh variable get GATE_MODE -R "$R")
  [ "$gate_mode" = "blocking" ] || abort1 "GATE_MODE is '${gate_mode}', not blocking."
  echo "  ok: GATE_MODE = blocking"

  rule_types=$(gh api "repos/${R}/rules/branches/main" --jq '[.[].type]')
  echo "  rule types on main: ${rule_types}"
  if ! jq -e 'any(.[]; . == "required_status_checks")' <<<"$rule_types" >/dev/null; then
    abort1 "required_status_checks is NOT on main. Nothing to race; the merge would simply succeed."
  fi
  echo "  ok: required_status_checks is in force on main"

  rs=$(gh api "repos/${R}/rulesets/${RULESET_ID}")
  bypass_actors=$(jq -c '.bypass_actors' <<<"$rs")
  cucb=$(jq -r '.current_user_can_bypass // "absent"' <<<"$rs")
  echo "  ruleset ${RULESET_ID}: bypass_actors=${bypass_actors} current_user_can_bypass=${cucb}"
  [ "$bypass_actors" = "[]" ] || abort1 "ruleset ${RULESET_ID} bypass_actors is ${bypass_actors}, not []."
  [ "$cucb" = "never" ] || abort1 "current_user_can_bypass is '${cucb}', not never. An accepted merge would prove nothing."
  echo "  ok: no bypass (bypass_actors [] and current_user_can_bypass never)"

  prs=$(pr_state "$R" "$PR")
  echo "  PR #${PR}: ${prs}"
  pr_st=$(jq -r '.state' <<<"$prs")
  [ "$pr_st" = "OPEN" ] || abort1 "PR #${PR} is ${pr_st}, not OPEN."
  SHA=$(jq -r '.headRefOid' <<<"$prs")
  case "$SHA" in
    *[!0-9a-f]*) abort1 "headRefOid '${SHA}' is not lowercase hex." ;;
  esac
  [ "${#SHA}" -eq 40 ] || abort1 "headRefOid '${SHA}' is not 40 characters."
  echo "  ok: PR #${PR} OPEN, head ${SHA}"

  newest=$(newest_per_context "$R" "$SHA" "$CONTEXTS_JSON")
  echo "  newest per context: $(jq -c 'map({name, status, conclusion, suite})' <<<"$newest")"
  if ! jq -e 'length == 5 and all(.[]; (.missing | not) and .status == "completed") and any(.[]; .conclusion == "failure")' <<<"$newest" >/dev/null; then
    abort1 "head ${SHA} is not red: all five newest must be completed with >= 1 failure (D-18). A green-prior attempt is non-discriminating."
  fi
  echo "  ok: five newest completed, >= 1 failure (red head SHA)"

  tmpf=$(mktemp)
  if settle_merge_state "$R" "$PR" "" >"$tmpf"; then
    mss=$(cat "$tmpf")
    rm -f "$tmpf"
  else
    rm -f "$tmpf"
    abort1 "mergeStateStatus did not settle (settle_merge_state returned non-zero)."
  fi
  [ "$mss" = "BLOCKED" ] || abort1 "settled mergeStateStatus is '${mss}', not BLOCKED. Refusing to close."
  echo "  ok: settled mergeStateStatus BLOCKED (the pre-close guard; nothing asserts state after the close)"

  # Every guard passed. Only now create the attempt directory.
  mkdir "$ATT_DIR"
  META=$(jq -cn \
    --arg label "$LABEL" --arg variant "$VARIANT" --arg repo "$R" --argjson pr "$PR" \
    --arg sha "$SHA" --argjson contexts "$CONTEXTS_JSON" --arg gate "$gate_mode" \
    --arg cucb "$cucb" --argjson ba "$bypass_actors" --argjson rsid "$RULESET_ID" \
    --arg rsf "$RULESET_FILE" --argjson rt "$rule_types" --arg mss "$mss" \
    '{label: $label, variant: $variant, repo: $repo, pr: $pr, head_sha: $sha, contexts: $contexts,
      gate_mode: $gate, current_user_can_bypass: $cucb, bypass_actors: $ba,
      ruleset_id: $rsid, ruleset_created_file: $rsf, rule_types_main: $rt,
      pre_close_settled_merge_state: $mss}')
  meta_write

  pre_line=$(append_snap pre-close)
  pre_suites=$(jq -c '[.check_runs[].suite] | unique' <<<"$pre_line")
  meta_json pre_suites "$pre_suites"
  echo "  snap pre-close written; pre-close suites ${pre_suites}"

  # ---- the race ------------------------------------------------------------
  local t_close close_rc t_detect="" detect_json="" close_suite="" i detected
  local t_reopen_start t_reopen_end reopen_rc t_premerge_read premerge t_premerge_read_end
  local t_merge_start t_merge_end merge_rc

  echo
  echo "=== RACE: variant ${VARIANT}, PR #${PR} ==="
  t_close=$(iso_now)
  echo "+ ${t_close} gh pr close ${PR} -R ${R}"
  trap - ERR
  set +e
  gh pr close "$PR" -R "$R"
  close_rc=$?
  set -e
  trap 'on_err $LINENO' ERR
  if [ "$close_rc" -ne 0 ]; then
    meta_str t_close "$t_close"
    meta_json close_rc "$close_rc"
    echo "INFRA FAILURE(2): gh pr close returned ${close_rc}. Check PR #${PR} state by hand before anything else."
    exit 2
  fi

  if [ "$VARIANT" = "a" ]; then
    meta_str t_close "$t_close"
    meta_json close_rc "$close_rc"
    detected=0
    tmpf=$(mktemp)
    for ((i = 1; i <= DETECT_N; i++)); do
      if close_run_detect "$R" "$SHA" "$pre_suites" "$CONTEXTS_JSON" >"$tmpf"; then
        detected=1
        break
      fi
      echo "  detector read ${i}/${DETECT_N}: not yet ($(jq -c '{run_id, run_status, run_conclusion}' "$tmpf"))"
      if [ "$i" -lt "$DETECT_N" ]; then sleep "$DETECT_S"; fi
    done
    detect_json=$(jq -c '.' "$tmpf")
    rm -f "$tmpf"
    meta_json detect "$detect_json"
    if [ "$detected" -ne 1 ]; then
      meta_json detect_timeout true
      echo
      echo "DETECTOR TIMEOUT(3): the close run was not detected after ${DETECT_N} reads."
      echo "                     PR #${PR} is LEFT CLOSED. It was NOT reopened."
      echo "                     Report this; do not reopen it blindly. meta.json is in ${ATT_DIR}."
      exit 3
    fi
    t_detect=$(iso_now)
    close_suite=$(jq -r '.suite' <<<"$detect_json")
    meta_str t_detect "$t_detect"
    echo "  ${t_detect} close run detected: $(jq -c '{run_id, suite, run_conclusion}' <<<"$detect_json")"
    append_snap pre-reopen >/dev/null
    echo "  snap pre-reopen written"
  fi

  # Window: reopen -> one D-19 state read -> merge. No meta writes, no
  # check-runs read in here.
  t_reopen_start=$(iso_now)
  trap - ERR
  set +e
  gh pr reopen "$PR" -R "$R"
  reopen_rc=$?
  set -e
  trap 'on_err $LINENO' ERR
  t_reopen_end=$(iso_now)
  if [ "$reopen_rc" -ne 0 ]; then
    meta_str t_close "$t_close"
    meta_json close_rc "$close_rc"
    meta_str t_reopen_start "$t_reopen_start"
    meta_str t_reopen_end "$t_reopen_end"
    meta_json reopen_rc "$reopen_rc"
    echo "INFRA FAILURE(2): gh pr reopen returned ${reopen_rc}. No merge was attempted. PR #${PR} may be CLOSED."
    exit 2
  fi

  t_premerge_read=$(iso_now)
  premerge=$(gh pr view "$PR" -R "$R" --json mergeStateStatus,mergeable,headRefOid)
  t_premerge_read_end=$(iso_now)

  t_merge_start=$(iso_now)
  trap - ERR
  set +e
  gh pr merge "$PR" -R "$R" --squash --match-head-commit "$SHA" >"${ATT_DIR}/merge-stdout.txt" 2>"${ATT_DIR}/merge-stderr.txt"
  merge_rc=$?
  set -e
  trap 'on_err $LINENO' ERR
  t_merge_end=$(iso_now)

  META=$(jq -c \
    --arg t_close "$t_close" --argjson close_rc "$close_rc" \
    --arg t_reopen_start "$t_reopen_start" --arg t_reopen_end "$t_reopen_end" --argjson reopen_rc "$reopen_rc" \
    --arg t_pr "$t_premerge_read" --arg t_pre "$t_premerge_read_end" --argjson pm "$premerge" \
    --arg t_ms "$t_merge_start" --arg t_me "$t_merge_end" --argjson merge_rc "$merge_rc" \
    '. + {t_close: $t_close, close_rc: $close_rc,
          t_reopen_start: $t_reopen_start, t_reopen_end: $t_reopen_end, reopen_rc: $reopen_rc,
          t_premerge_read: $t_pr, t_premerge_read_end: $t_pre,
          premerge_state: ($pm | {mergeStateStatus, mergeable, headRefOid}),
          t_merge_start: $t_ms, t_merge_end: $t_me, merge_rc: $merge_rc}' <<<"$META")
  meta_write

  echo "  ${t_reopen_start} .. ${t_reopen_end} reopen rc ${reopen_rc}"
  echo "  ${t_premerge_read} .. ${t_premerge_read_end} D-19 pre-merge state: ${premerge}"
  echo "  ${t_merge_start} .. ${t_merge_end} gh pr merge ${PR} -R ${R} --squash --match-head-commit ${SHA}  rc ${merge_rc}"
  echo "--- merge-stdout.txt ---"
  cat "${ATT_DIR}/merge-stdout.txt"
  echo "--- merge-stderr.txt ---"
  cat "${ATT_DIR}/merge-stderr.txt"
  echo "------------------------"

  append_snap post-merge >/dev/null
  gh pr view "$PR" -R "$R" --json state,mergedAt,mergeCommit,headRefOid >"${ATT_DIR}/pr-after.json"
  echo "  snap post-merge written; pr-after: $(jq -c '.' "${ATT_DIR}/pr-after.json")"

  # ---- settle: wait for the reopen suite to complete on every context -------
  local n settled line jrc
  settled=0
  for ((n = 1; n <= SETTLE_N; n++)); do
    line=$(append_snap "settle-${n}")
    jrc=0
    jq -e --argjson pre "$pre_suites" --arg cs "$close_suite" '
      .newest as $nw
      | ($nw | all(.[]; (.missing | not) and .status == "completed"
                        and (.suite as $s | any($pre[]; . == $s) | not)))
        and (([$nw[].suite] | unique | length) == 1)
        and (if $cs != "" then (($nw[0].suite | tostring) != $cs)
             else ($nw | any(.[]; .conclusion != "skipped" and .conclusion != "cancelled")) end)' \
      <<<"$line" >/dev/null || jrc=$?
    case "$jrc" in
      0) settled=1; break ;;
      1) : ;;
      *) echo "INFRA FAILURE(2): jq rc ${jrc} evaluating settle-${n}" >&2; exit 2 ;;
    esac
    echo "  settle ${n}/${SETTLE_N}: $(jq -c '[.newest[] | {status, conclusion, suite}]' <<<"$line")"
    if [ "$n" -lt "$SETTLE_N" ]; then sleep "$SETTLE_S"; fi
  done
  if [ "$settled" -eq 1 ]; then
    meta_json settle_timeout false
    echo "  settled after ${n} snap(s): reopen suite complete on every context"
  else
    meta_json settle_timeout true
    echo "  SETTLE TIMEOUT after ${SETTLE_N} snaps (recorded; the verdict uses the post-merge snap)"
  fi

  append_snap final >/dev/null
  local cr runs tl
  cr=$(checkruns_all "$R" "$SHA")
  printf '%s\n' "$cr" | jq . >"${ATT_DIR}/checkruns-final.json"
  runs=$(runs_for_sha "$R" "$SHA")
  printf '%s\n' "$runs" | jq . >"${ATT_DIR}/runs.json"
  tl=$(gh api "repos/${R}/issues/${PR}/timeline" --paginate --slurp)
  jq 'add' <<<"$tl" >"${ATT_DIR}/pr-timeline.json"
  meta_str t_final_dumps "$(iso_now)"
  echo "  snap final; checkruns-final.json, runs.json, pr-timeline.json, meta.json written"

  # ---- verdict -------------------------------------------------------------
  local vrc
  echo
  echo "=== verdict: bash ${PD}/29.6-verdict.sh ${ATT_DIR} ==="
  trap - ERR
  set +e
  bash "${PD}/29.6-verdict.sh" "$ATT_DIR"
  vrc=$?
  set -e
  trap 'on_err $LINENO' ERR

  case "$vrc" in
    0)
      echo "=== attempt ${LABEL}: BLOCKED (verdict exit 0) ==="
      ;;
    9)
      echo
      echo "########################################################################"
      echo "## RACE LOST. THE MERGE WAS ACCEPTED ON A RED HEAD SHA.               ##"
      echo "## D-11: STOP. Run nothing else. Report to the operator.              ##"
      echo "## attempt ${LABEL}, PR #${PR}, head ${SHA}"
      echo "## evidence: ${ATT_DIR}"
      echo "########################################################################"
      exit 9
      ;;
    *)
      echo "=== attempt ${LABEL}: verdict exit ${vrc}. STOP; no further attempts. ==="
      exit "$vrc"
      ;;
  esac
}

echo "=== 29.6-race.sh LIVE: variant ${VARIANT}, ${#LABELS[@]} attempt(s), repo ${R} ==="
for i in "${!LABELS[@]}"; do
  run_attempt "${LABELS[$i]}" "${PRNUMS[$i]}"
done
echo
echo "=== all ${#LABELS[@]} attempt(s) BLOCKED. exit 0 ==="
exit 0
