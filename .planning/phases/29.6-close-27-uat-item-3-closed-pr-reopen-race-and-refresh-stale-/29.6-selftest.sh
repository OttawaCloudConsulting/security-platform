#!/usr/bin/env bash
set -uo pipefail

# 29.6-selftest.sh — self-test of the Phase 29.6 measurement layer
# (29.6-snap.sh and 29.6-verdict.sh, plan 29.6-03).
#
# WHY. The race verdict must be judged by pre-committed code, not by eye. This
# script proves that code before any live race attempt:
#   live-snap  runs the read-only logger and the variant (a) close-run detector
#              LIVE against the precedent on OttawaCloudConsulting/security-platform
#              PR #21 (head 7c47270, opened run 36156728417, close run
#              36158851741). GitHub reads only (GET). It also doubles as the
#              research A8 check: runs_for_sha must find the close run.
#   verdict    runs 29.6-verdict.sh over the synthetic attempt directories in
#              29.6-fixtures/ (one per outcome class) and the D-19 classifier.
#              Offline: no gh call.
#   all        live-snap then verdict; the last line is `SELFTEST PASS` only
#              when every case passed and the case counts are exactly 5 and 8.
#
# The context names are never typed here (D-01): they are read live from the
# opened run's check runs and written to a scratch file.
#
# Usage (no executable bit; always via bash):
#   bash 29.6-selftest.sh live-snap|verdict|all
#   SELFTEST_SCRATCH=<dir>  where the live context-name file is written
#                           (default: a fresh mktemp -d)
#
# Output: one `CASE <name> PASS|FAIL <detail>` line per case on stdout.
# Exit: 0 every case passed; 1 a case failed; 2 usage.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAP="${HERE}/29.6-snap.sh"
VERDICT="${HERE}/29.6-verdict.sh"
FIX="${HERE}/29.6-fixtures"

R="OttawaCloudConsulting/security-platform"
PRN=21
OPENED_RUN=36156728417
CLOSE_RUN=36158851741

FAILS=0
CASES=0

report() { # $1 name, $2 PASS|FAIL, $3 detail
  CASES=$((CASES + 1))
  if [ "$2" != "PASS" ]; then FAILS=$((FAILS + 1)); fi
  printf 'CASE %s %s %s\n' "$1" "$2" "$3"
}

live_snap() {
  local scratch sha rc out ctx_file pre_open close_suite open_suite
  scratch="${SELFTEST_SCRATCH:-$(mktemp -d)}"
  mkdir -p "$scratch"
  ctx_file="${scratch}/29.6-03-contexts.json"

  if ! sha=$(gh pr view "$PRN" -R "$R" --json headRefOid --jq .headRefOid); then
    echo "ABORT(2): could not resolve PR #${PRN} head SHA" >&2
    exit 2
  fi
  case "$sha" in
    7c47270*) : ;;
    *) echo "ABORT(2): PR #${PRN} head is ${sha}, expected 7c47270..." >&2; exit 2 ;;
  esac

  # 1. checkruns_all
  rc=0; out=$(bash "$SNAP" checkruns_all "$R" "$sha") || rc=$?
  if [ "$rc" -eq 0 ] && jq -e 'length >= 10 and all(.[]; (.id|type)=="number" and (.suite|type)=="number" and (.run|type)=="number")' <<<"$out" >/dev/null 2>&1; then
    report checkruns_all PASS "rc=0 entries=$(jq length <<<"$out")"
  else
    report checkruns_all FAIL "rc=${rc}"
    out='[]'
  fi

  # Context names, read live: the opened run's check runs, minus DefectDojo.
  jq -c --argjson run "$OPENED_RUN" \
    '[.[] | select(.run == $run and (.name | test("DefectDojo") | not)) | .name] | unique' \
    <<<"$out" >"$ctx_file"

  # 2. newest_per_context
  rc=0; out=$(bash "$SNAP" newest_per_context "$R" "$sha" "$(cat "$ctx_file")") || rc=$?
  if [ "$rc" -eq 0 ] && jq -e 'length == 5 and all(.[]; (.missing|not) and .conclusion == "skipped") and ([.[].suite] | unique | length) == 1' <<<"$out" >/dev/null 2>&1; then
    report newest_per_context PASS "rc=0 contexts=5 all skipped suite=$(jq -r '.[0].suite' <<<"$out")"
  else
    report newest_per_context FAIL "rc=${rc} contexts_file=$(cat "$ctx_file")"
  fi

  # Suite ids of the opened and close runs, from runs_for_sha (also the A8 check).
  rc=0; out=$(bash "$SNAP" runs_for_sha "$R" "$sha") || rc=$?
  open_suite=$(jq -r --argjson id "$OPENED_RUN" '.[] | select(.id == $id) | .check_suite_id' <<<"$out" 2>/dev/null)
  close_suite=$(jq -r --argjson id "$CLOSE_RUN" '.[] | select(.id == $id) | .check_suite_id' <<<"$out" 2>/dev/null)
  : "${open_suite:=missing}" "${close_suite:=missing}"

  # 3. close_run_detect, positive: only the opened suite was present before the close.
  pre_open="[${open_suite}]"
  rc=0; out=$(bash "$SNAP" close_run_detect "$R" "$sha" "$pre_open" "$(cat "$ctx_file")") || rc=$?
  if [ "$rc" -eq 0 ] && jq -e --argjson id "$CLOSE_RUN" --argjson s "$close_suite" \
      '.detected == true and .run_id == $id and .suite == $s and .run_conclusion == "skipped"' <<<"$out" >/dev/null 2>&1; then
    report close_run_detect_positive PASS "rc=0 run_id=${CLOSE_RUN} suite=${close_suite} (A8: runs_for_sha found the close run)"
  else
    report close_run_detect_positive FAIL "rc=${rc} open_suite=${open_suite} close_suite=${close_suite}"
  fi

  # 4. close_run_detect, negative: both suites already present before the close.
  rc=0; out=$(bash "$SNAP" close_run_detect "$R" "$sha" "[${open_suite},${close_suite}]" "$(cat "$ctx_file")") || rc=$?
  if [ "$rc" -eq 1 ] && jq -e '.detected == false' <<<"$out" >/dev/null 2>&1; then
    report close_run_detect_negative PASS "rc=1 detected=false"
  else
    report close_run_detect_negative FAIL "rc=${rc}"
  fi

  # 5. settle_merge_state on a closed (merged) PR, one read, no sleep.
  rc=0; out=$(POLL_ITERATIONS=1 POLL_SLEEP=0 bash "$SNAP" settle_merge_state "$R" "$PRN" "") || rc=$?
  if { [ "$rc" -eq 0 ] && [ -n "$out" ] && [ "$out" != "UNKNOWN" ]; } || { [ "$rc" -eq 3 ] && [ -z "$out" ]; }; then
    report settle_merge_state PASS "rc=${rc} stdout='${out}' (no fallback value)"
  else
    report settle_merge_state FAIL "rc=${rc} stdout='${out}'"
  fi
}

run_fixture() { # $1 fixture name; sets VRC and VOUT. Runs on a private copy so
  # the committed fixture directory never gains a verdict.json.
  local work
  work="$(mktemp -d)/$1"
  cp -R "${FIX}/$1" "$work"
  VRC=0
  VOUT=$(bash "$VERDICT" "$work" 2>/dev/null) || VRC=$?
  rm -rf "$(dirname "$work")"
}

expect_fixture() { # $1 case, $2 fixture, $3 expected rc, $4 jq predicate
  run_fixture "$2"
  if [ "$VRC" -eq "$3" ] && jq -e "$4" <<<"$VOUT" >/dev/null 2>&1; then
    report "$1" PASS "rc=${VRC} verdict=$(jq -r .verdict <<<"$VOUT") refusal_source=$(jq -r .refusal_source <<<"$VOUT")"
  else
    report "$1" FAIL "rc=${VRC} expected_rc=$3 out=$(jq -c '{verdict,reason,refusal_source}' <<<"$VOUT" 2>/dev/null || printf '%s' "$VOUT")"
  fi
}

verdict_cases() {
  local close_s reopen_s skew out rc
  expect_fixture blocked_client blocked-client 0 \
    '.verdict == "blocked" and .refusal_source == "client-side" and .precondition_red == true and (.refusal_line | test("base branch policy prohibits the merge"))'
  expect_fixture blocked_server blocked-server 0 \
    '.verdict == "blocked" and .refusal_source == "server-side" and .variant_a_precondition == true'
  expect_fixture lost lost 9 \
    '.verdict == "lost" and .merged == true and .reopen_complete_at_post_merge == false and .refusal_source == null'

  # Attribution under simulated clock skew: t_close is later than the close
  # run's created_at; suites must still be attributed by set difference.
  close_s=$(jq -r '.[] | select(.conclusion == "skipped") | .check_suite_id' "${FIX}/lost/runs.json")
  reopen_s=$(jq -r '[.[] | select(.conclusion != "skipped")] | max_by(.id) | .check_suite_id' "${FIX}/lost/runs.json")
  skew=$(jq -n --slurpfile m "${FIX}/lost/meta.json" --slurpfile r "${FIX}/lost/runs.json" \
    '$m[0].t_close > ($r[0][] | select(.conclusion == "skipped") | .created_at)')
  run_fixture lost
  if [ "$skew" = "true" ] && jq -e --argjson c "$close_s" --argjson o "$reopen_s" \
      '.close_suite == $c and .reopen_suite == $o' <<<"$VOUT" >/dev/null 2>&1; then
    report attribution_clock_skew PASS "t_close>close created_at; close_suite=${close_s} reopen_suite=${reopen_s}"
  else
    report attribution_clock_skew FAIL "skew=${skew} expected close=${close_s} reopen=${reopen_s} got=$(jq -c '{close_suite,reopen_suite}' <<<"$VOUT" 2>/dev/null)"
  fi

  expect_fixture invalid_green invalid-green 1 \
    '.verdict == "invalid" and .precondition_red == false and .merged == true'
  expect_fixture anomaly anomaly 4 \
    '.verdict == "anomaly" and .merge_rc == 0'
  expect_fixture unclassified unclassified 0 \
    '.verdict == "blocked" and .refusal_source == "unclassified" and .refusal_line == null'

  rc=0; out=$(bash "$VERDICT" --classify-stderr "${FIX}/flag-hint-only-stderr.txt" 2>/dev/null) || rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "unclassified" ]; then
    report classify_flag_hints_only PASS "rc=0 -> unclassified"
  else
    report classify_flag_hints_only FAIL "rc=${rc} out='${out}'"
  fi
}

case "${1:-}" in
  live-snap)
    live_snap
    [ "$FAILS" -eq 0 ] && [ "$CASES" -eq 5 ] || exit 1
    ;;
  verdict)
    verdict_cases
    [ "$FAILS" -eq 0 ] && [ "$CASES" -eq 8 ] || exit 1
    ;;
  all)
    live_snap
    LIVE_CASES=$CASES
    vrc=0; verdict_cases || vrc=$?
    VERDICT_CASES=$((CASES - LIVE_CASES))
    if [ "$vrc" -eq 0 ] && [ "$FAILS" -eq 0 ] && [ "$LIVE_CASES" -eq 5 ] && [ "$VERDICT_CASES" -eq 8 ]; then
      echo "SELFTEST PASS"
      exit 0
    fi
    echo "SELFTEST FAIL fails=${FAILS} live_cases=${LIVE_CASES} verdict_cases=${VERDICT_CASES}"
    exit 1
    ;;
  *)
    echo "usage: bash 29.6-selftest.sh live-snap|verdict|all" >&2
    exit 2
    ;;
esac
