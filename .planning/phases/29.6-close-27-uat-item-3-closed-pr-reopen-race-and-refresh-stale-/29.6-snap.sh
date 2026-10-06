#!/usr/bin/env bash
# 29.6-snap.sh — read-only state logger and variant (a) close-run detector for
# the Phase 29.6 closed-PR reopen race (D-07, D-08(a)).
#
# WHY. A race outcome is only as trustworthy as the record of what GitHub
# showed at each step. Every step of an attempt is logged as one JSON line:
# an ISO-ms UTC timestamp, the PR's state/mergeStateStatus/mergeable, and every
# check run on the head SHA from the scanning app (name, id, status,
# conclusion, check_suite id, run id). Two rules from 29.6-RESEARCH.md hold
# throughout (Pattern 5, Pitfalls 3/4):
#   - check runs are ORDERED BY id and ATTRIBUTED to a run by check_suite.id;
#     started_at/completed_at are recorded but never used to order or
#     attribute (a completed run can report completion before its last check
#     run's started_at);
#   - the check-runs listing is always read with filter=all. The default
#     listing keeps only the most recent run per name, which hides exactly the
#     superseded runs this phase needs to see.
# The close-run detector uses a SET DIFFERENCE of check-suite ids (suites not
# present before the close), never a local timestamp compared with server
# time, so local clock skew cannot flip it.
#
# READ-ONLY. Every gh call in this file is a GET (`gh api <path>` with no
# method override, and `gh pr view`). Nothing here writes to GitHub.
#
# USAGE (never set the executable bit on this file — project rule):
#   source 29.6-snap.sh                 defines functions; runs nothing
#   bash 29.6-snap.sh <fn> <args...>    CLI: runs one function
#
# Functions (APP_ID 15368 = GitHub Actions):
#   iso_now                               ISO 8601 UTC, milliseconds (python3)
#   checkruns_all R SHA                   all app check runs on SHA, sorted by id
#   newest_per_context R SHA CTX_JSON     max_by(.id) per context name
#   pr_state R PR                         {state,mergeStateStatus,mergeable,headRefOid}
#   runs_for_sha R SHA                    pull_request workflow runs on SHA
#   settle_merge_state R PR PREV          bounded settle-poll of mergeStateStatus
#   close_run_detect R SHA PRE_SUITES_JSON CTX_JSON
#   snap LABEL                            env R, PR, SHA, CONTEXTS_JSON; one JSON line
#
# Exit/return codes:
#   0  success (close_run_detect: detected; settle: settled)
#   1  close_run_detect: not yet detected (returned, so a sourcing poll loop
#      is not terminated)
#   3  settle_merge_state: did not settle within the budget (returned)
#   2  a gh/jq/python3 failure or bad arguments. This EXITS (also when
#      sourced): there is deliberately no fallback value.
#
# Environment (settle_merge_state): POLL_ITERATIONS (default 20),
# POLL_SLEEP seconds (default 3).

SNAP_APP_ID=15368

_snap_die() { # message...
  echo "ABORT(2): $*" >&2
  exit 2
}

_snap_gh() { # gh args... ; stdout = gh stdout; on failure print gh stderr, exit 2
  local errf out
  errf=$(mktemp) || _snap_die "mktemp failed"
  if ! out=$(gh "$@" 2>"$errf"); then
    echo "ABORT(2): gh $* failed. gh stderr follows:" >&2
    cat "$errf" >&2
    rm -f "$errf"
    exit 2
  fi
  rm -f "$errf"
  printf '%s\n' "$out"
}

_snap_is_array() { # json
  jq -e 'type == "array"' <<<"$1" >/dev/null 2>&1
}

_snap_newest() { # CHECKRUNS_JSON CONTEXTS_JSON -> newest-by-id per context
  jq -c --argjson ctx "$2" '
    . as $cr
    | [ $ctx[] as $n
        | ([ $cr[] | select(.name == $n) ]
           | if length == 0 then {name: $n, missing: true} else max_by(.id) end) ]' <<<"$1" \
    || _snap_die "jq failed computing newest per context"
}

iso_now() {
  python3 -c 'import datetime;print(datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00","Z"))' \
    || _snap_die "python3 timestamp failed"
}

checkruns_all() { # R SHA
  [ "$#" -eq 2 ] || _snap_die "usage: checkruns_all <repo> <sha>"
  local raw total
  raw=$(_snap_gh api "repos/$1/commits/$2/check-runs?filter=all&per_page=100") || exit 2
  total=$(jq -r '.total_count' <<<"$raw") || _snap_die "jq failed reading total_count"
  if [ "$total" -gt 100 ]; then
    _snap_die "check-runs total_count=${total} > 100 on $2; one page would be incomplete"
  fi
  jq -c --argjson app "$SNAP_APP_ID" '
    [ .check_runs[] | select(.app.id == $app)
      | { name, id, status, conclusion,
          suite: .check_suite.id,
          run: (((.details_url // "") | capture("runs/(?<r>[0-9]+)").r | tonumber) // null),
          started_at, completed_at } ]
    | sort_by(.id)' <<<"$raw" || _snap_die "jq failed shaping check runs"
}

newest_per_context() { # R SHA CONTEXTS_JSON
  [ "$#" -eq 3 ] || _snap_die "usage: newest_per_context <repo> <sha> <contexts-json>"
  _snap_is_array "$3" || _snap_die "contexts argument is not a JSON array"
  local cr
  cr=$(checkruns_all "$1" "$2") || exit 2
  _snap_newest "$cr" "$3"
}

pr_state() { # R PR
  [ "$#" -eq 2 ] || _snap_die "usage: pr_state <repo> <pr>"
  local raw
  raw=$(_snap_gh pr view "$2" -R "$1" --json state,mergeStateStatus,mergeable,headRefOid) || exit 2
  jq -c '{state, mergeStateStatus, mergeable, headRefOid}' <<<"$raw" || _snap_die "jq failed shaping pr state"
}

runs_for_sha() { # R SHA
  [ "$#" -eq 2 ] || _snap_die "usage: runs_for_sha <repo> <sha>"
  local base raw total acc page n
  base="repos/$1/actions/runs?event=pull_request&head_sha=$2&per_page=100"
  raw=$(_snap_gh api "$base") || exit 2
  total=$(jq -r '.total_count' <<<"$raw") || _snap_die "jq failed reading total_count"
  # Filter client-side on head_sha as well (research A8): if the server ever
  # ignored head_sha, an unfiltered page would silently miss the run.
  if [ "$total" -le 100 ]; then
    acc=$(jq -c --arg sha "$2" '[.workflow_runs[] | select(.head_sha == $sha)]' <<<"$raw") \
      || _snap_die "jq failed filtering runs"
  else
    echo "runs_for_sha: total_count=${total} > 100; paging (cap 10 pages)" >&2
    acc='[]'
    page=1
    while :; do
      if [ "$page" -gt 10 ]; then
        _snap_die "runs_for_sha: more than 10 pages of runs; refusing to return a partial list"
      fi
      raw=$(_snap_gh api "${base}&page=${page}") || exit 2
      acc=$(jq -c --arg sha "$2" --argjson acc "$acc" '$acc + [.workflow_runs[] | select(.head_sha == $sha)]' <<<"$raw") \
        || _snap_die "jq failed filtering runs page ${page}"
      n=$(jq '.workflow_runs | length' <<<"$raw") || _snap_die "jq failed counting page ${page}"
      if [ "$n" -lt 100 ]; then break; fi
      page=$((page + 1))
    done
  fi
  jq -c '[ .[] | {id, created_at, status, conclusion, check_suite_id, event, run_attempt} ] | sort_by(.id)' <<<"$acc" \
    || _snap_die "jq failed shaping runs"
}

settle_merge_state() { # R PR PREV
  [ "$#" -eq 3 ] || _snap_die "usage: settle_merge_state <repo> <pr> <previous-state or \"\">"
  local iters sleep_s i st mss
  iters="${POLL_ITERATIONS:-20}"
  sleep_s="${POLL_SLEEP:-3}"
  for ((i = 1; i <= iters; i++)); do
    st=$(pr_state "$1" "$2") || exit 2
    mss=$(jq -r '.mergeStateStatus' <<<"$st") || _snap_die "jq failed reading mergeStateStatus"
    echo "settle read ${i}/${iters}: mergeStateStatus=${mss} (previous='${3}')" >&2
    if [ "$mss" != "UNKNOWN" ] && { [ -z "$3" ] || [ "$mss" != "$3" ]; }; then
      printf '%s\n' "$mss"
      return 0
    fi
    if [ "$i" -lt "$iters" ]; then sleep "$sleep_s"; fi
  done
  echo "NOT SETTLED(3): mergeStateStatus last '${mss:-}' after ${iters} reads (previous='${3}'). Not a verdict." >&2
  return 3
}

close_run_detect() { # R SHA PRE_SUITES_JSON CONTEXTS_JSON
  [ "$#" -eq 4 ] || _snap_die "usage: close_run_detect <repo> <sha> <pre-suites-json> <contexts-json>"
  _snap_is_array "$3" || _snap_die "pre-suites argument is not a JSON array"
  _snap_is_array "$4" || _snap_die "contexts argument is not a JSON array"
  local runs cr newest out
  runs=$(runs_for_sha "$1" "$2") || exit 2
  cr=$(checkruns_all "$1" "$2") || exit 2
  newest=$(_snap_newest "$cr" "$4") || exit 2
  # Candidates: runs whose suite was NOT present before the close, newest
  # first. Detected when a completed candidate owns every context's
  # newest-by-id check run and each of those is completed. Conclusions are
  # recorded as found (skipped expected; cancelled recorded, not asserted).
  out=$(jq -cn --argjson runs "$runs" --argjson pre "$3" --argjson newest "$newest" '
    ($runs | map(select(.check_suite_id as $s | any($pre[]; . == $s) | not)) | sort_by(.id) | reverse) as $cands
    | ([ $cands[] | select(.status == "completed") | . as $r
         | select($newest | all(.[]; (.missing | not) and .suite == $r.check_suite_id and .status == "completed")) ]
       | .[0]) as $hit
    | if $hit != null then
        {detected: true, run_id: $hit.id, suite: $hit.check_suite_id,
         run_status: $hit.status, run_conclusion: $hit.conclusion, newest: $newest}
      else
        {detected: false, run_id: ($cands[0].id // null), suite: ($cands[0].check_suite_id // null),
         run_status: ($cands[0].status // null), run_conclusion: ($cands[0].conclusion // null), newest: $newest}
      end') || _snap_die "jq failed evaluating the detector"
  printf '%s\n' "$out"
  if jq -e '.detected' <<<"$out" >/dev/null; then
    return 0
  fi
  return 1
}

snap() { # LABEL ; env R PR SHA CONTEXTS_JSON
  [ "$#" -eq 1 ] || _snap_die "usage: snap <label> (env R, PR, SHA, CONTEXTS_JSON)"
  [ -n "${R:-}" ] && [ -n "${PR:-}" ] && [ -n "${SHA:-}" ] && [ -n "${CONTEXTS_JSON:-}" ] \
    || _snap_die "snap needs env R, PR, SHA and CONTEXTS_JSON"
  _snap_is_array "$CONTEXTS_JSON" || _snap_die "CONTEXTS_JSON is not a JSON array"
  local ts prs cr newest
  ts=$(iso_now) || exit 2
  prs=$(pr_state "$R" "$PR") || exit 2
  cr=$(checkruns_all "$R" "$SHA") || exit 2
  newest=$(_snap_newest "$cr" "$CONTEXTS_JSON") || exit 2
  jq -cn --arg label "$1" --arg ts "$ts" --argjson pr "$prs" --argjson cr "$cr" --argjson newest "$newest" \
    '{label: $label, ts: $ts, pr: $pr, check_runs: $cr, newest: $newest}' || _snap_die "jq failed building snap line"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  if [ "$#" -lt 1 ]; then
    echo "usage: bash 29.6-snap.sh <iso_now|checkruns_all|newest_per_context|pr_state|runs_for_sha|settle_merge_state|close_run_detect|snap> <args...>" >&2
    exit 2
  fi
  fn="$1"
  shift
  case "$fn" in
    iso_now | checkruns_all | newest_per_context | pr_state | runs_for_sha | settle_merge_state | close_run_detect | snap)
      "$fn" "$@"
      ;;
    *)
      echo "ABORT(2): unknown function '${fn}'" >&2
      exit 2
      ;;
  esac
fi
