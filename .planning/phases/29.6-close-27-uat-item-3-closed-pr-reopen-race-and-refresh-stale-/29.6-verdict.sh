#!/usr/bin/env bash
set -euo pipefail

# 29.6-verdict.sh — offline per-attempt verdict and D-19 refusal classifier
# for the Phase 29.6 closed-PR reopen race (D-10 as amended by D-18, D-19).
#
# WHY. A race outcome must be judged by pre-committed code, not by eye. This
# script reads one attempt directory written by 29.6-race.sh and applies fixed
# rules; it was proven against synthetic fixtures for every outcome class
# (29.6-selftest.sh verdict) before any live attempt. It never calls gh.
#
# USAGE (no executable bit; always via bash):
#   bash 29.6-verdict.sh <attempt-dir>
#       reads meta.json, timeline.jsonl, merge-stdout.txt, merge-stderr.txt,
#       checkruns-final.json, runs.json, pr-after.json; writes
#       <attempt-dir>/verdict.json and prints it.
#   bash 29.6-verdict.sh --classify-stderr <file>
#       prints client-side | server-side | unclassified.
#
# Exit: 0 blocked, 9 lost, 1 invalid, 4 anomaly, 2 usage / missing or
# malformed input (including a missing pre-close / post-merge snap, or a
# missing pre-reopen snap in variant a).
#
# RULES (the 5 contexts are meta.contexts; "newest" = max_by(.id) per context):
#   precondition_red  pre-close snap: mergeStateStatus BLOCKED, all five newest
#                     completed, >= 1 newest conclusion "failure".
#   suite attribution SET DIFFERENCE, never timestamps (research Pitfalls 3/4):
#                     new suites = suites of the five contexts' runs in
#                     checkruns-final.json absent from every suite in the
#                     pre-close snap. close_suite = the new suite whose runs
#                     cover all five contexts and are all skipped/cancelled;
#                     reopen_suite = the other. Exactly two new suites with
#                     one of each kind, else anomaly. runs.json is
#                     corroboration only (agreement is noted in reason).
#   variant_a_precondition (variant a only) pre-reopen snap: every context's
#                     newest is in close_suite and completed. null in variant b.
#   merged            merge_rc == 0 OR pr-after.state == "MERGED".
#   refusal_source    only when not merged; from the verbatim stderr file.
#                     client-side: gh's own BLOCKED/BEHIND/DIRTY decline text
#                     (policy wording only, never the CLI flag-hint lines);
#                     server-side: GraphQL / HTTP 4xx / rule-violation /
#                     required-status-check wording (case-insensitive);
#                     otherwise unclassified. refusal_line = first matching
#                     line verbatim (null when unclassified).
#
# PRECEDENCE (first match wins; recorded in reason):
#   1 anomaly  merge_rc and PR state disagree (rc 0 but not MERGED, or rc != 0
#              but MERGED)
#   2 invalid  NOT precondition_red | gate_mode != "blocking" |
#              current_user_can_bypass != "never"
#   3 anomaly  suite attribution failed (new-suite count != 2 or kinds unclear)
#   4 invalid  variant a and NOT variant_a_precondition
#   5 merged:  lost when at the post-merge snap any context's newest is not in
#              reopen_suite or not completed (D-18); otherwise anomaly — the
#              merge landed after the reopen suite completed, an enforcement
#              failure (still STOP)
#   6 blocked  not merged and merge_rc != 0

CLIENT_RE='base branch policy prohibits the merge|is not up to date with the base branch|merge commit cannot be cleanly created'
SERVER_RE='GraphQL|HTTP 4[0-9][0-9]|Repository rule violation|required status check'

usage() {
  echo "usage: bash 29.6-verdict.sh <attempt-dir> | --classify-stderr <file>" >&2
  exit 2
}

classify_source() { # file -> client-side | server-side | unclassified
  if grep -Eq "$CLIENT_RE" "$1"; then
    echo "client-side"
  elif grep -Eiq "$SERVER_RE" "$1"; then
    echo "server-side"
  else
    echo "unclassified"
  fi
}

classify_line() { # file source -> first matching line verbatim, or empty
  case "$2" in
    client-side) grep -Em1 "$CLIENT_RE" "$1" ;;
    server-side) grep -Eim1 "$SERVER_RE" "$1" ;;
    *) printf '' ;;
  esac
}

if [ "$#" -eq 2 ] && [ "$1" = "--classify-stderr" ]; then
  [ -f "$2" ] || { echo "ABORT(2): no such file: $2" >&2; exit 2; }
  classify_source "$2"
  exit 0
fi
[ "$#" -eq 1 ] || usage
D="$1"
[ -d "$D" ] || { echo "ABORT(2): not a directory: $D" >&2; exit 2; }
for f in meta.json timeline.jsonl merge-stdout.txt merge-stderr.txt checkruns-final.json runs.json pr-after.json; do
  [ -f "${D}/${f}" ] || { echo "ABORT(2): missing ${D}/${f}" >&2; exit 2; }
done

# Required snaps must be present exactly once (else the attempt record is malformed).
VARIANT=$(jq -r '.variant' "${D}/meta.json")
case "$VARIANT" in a | b) : ;; *) echo "ABORT(2): meta.variant must be a or b, got '${VARIANT}'" >&2; exit 2 ;; esac
REQ='["pre-close","post-merge"]'
if [ "$VARIANT" = "a" ]; then REQ='["pre-close","pre-reopen","post-merge"]'; fi
if ! jq -se --argjson req "$REQ" 'all($req[] as $l | [.[] | select(.label == $l)] | length == 1; .)' "${D}/timeline.jsonl" >/dev/null; then
  echo "ABORT(2): timeline.jsonl must contain exactly one snap for each of ${REQ}" >&2
  exit 2
fi

# Refusal classification (only meaningful when not merged; jq decides that).
SRC=$(classify_source "${D}/merge-stderr.txt")
LINE=$(classify_line "${D}/merge-stderr.txt" "$SRC")

OUT=$(jq -n \
  --slurpfile meta "${D}/meta.json" \
  --slurpfile tl "${D}/timeline.jsonl" \
  --slurpfile fin "${D}/checkruns-final.json" \
  --slurpfile runs "${D}/runs.json" \
  --slurpfile after "${D}/pr-after.json" \
  --arg src "$SRC" --arg line "$LINE" '
  def newest($cr; $ctx):
    [ $ctx[] as $n
      | ([ $cr[] | select(.name == $n) ]
         | if length == 0 then {name: $n, missing: true} else max_by(.id) end) ];
  def inctx($ctx): .name as $n | any($ctx[]; . == $n);

  $meta[0] as $m | $fin[0] as $final | $runs[0] as $rs | $after[0] as $pa
  | $m.contexts as $ctx
  | ($tl | map(select(.label == "pre-close")) | .[0]) as $pre
  | ($tl | map(select(.label == "pre-reopen")) | .[0]) as $prer
  | ($tl | map(select(.label == "post-merge")) | .[0]) as $post

  | newest($pre.check_runs; $ctx) as $pn
  | ($pre.pr.mergeStateStatus == "BLOCKED"
     and ($pn | all(.[]; (.missing | not) and .status == "completed"))
     and ($pn | any(.[]; .conclusion == "failure"))) as $red

  | ([ $pre.check_runs[].suite ] | unique) as $presuites
  | ([ $final[] | select(inctx($ctx)) | .suite ] | unique
     | map(. as $s | select(any($presuites[]; . == $s) | not))) as $new
  | ($new | map(. as $s | {suite: $s, runs: [ $final[] | select(.suite == $s and inctx($ctx)) ]})) as $groups
  | ($groups | map(select(
        ([.runs[].name] | unique | length) == ($ctx | length)
        and (.runs | all(.[]; .conclusion == "skipped" or .conclusion == "cancelled"))))) as $closeg
  | ($groups | map(select(.suite as $s | any($closeg[]; .suite == $s) | not))) as $reopeng
  | (($new | length) == 2 and ($closeg | length) == 1 and ($reopeng | length) == 1) as $attr_ok
  | (if $attr_ok then $closeg[0].suite else null end) as $cs
  | (if $attr_ok then $reopeng[0].suite else null end) as $ros
  | (if $attr_ok then ($closeg[0].runs | sort_by(.name) | map({name, conclusion})) else null end) as $csc

  | (if $m.variant == "a" then
       ($cs != null and (newest($prer.check_runs; $ctx)
         | all(.[]; (.missing | not) and .suite == $cs and .status == "completed")))
     else null end) as $vap

  | (newest($post.check_runs; $ctx)
     | map({name, status: (.status // null), conclusion: (.conclusion // null), suite: (.suite // null)})) as $pm
  | ($ros != null and ($pm | all(.[]; .suite == $ros and .status == "completed"))) as $reopen_done

  | ($m.merge_rc == 0 or $pa.state == "MERGED") as $merged
  | ([ $rs[].check_suite_id ]) as $runsuites
  | (if $attr_ok then
       (if any($runsuites[]; . == $cs) and any($runsuites[]; . == $ros)
        then "runs.json agrees with the suite attribution"
        else "runs.json DISAGREES with the suite attribution (recorded, not used)" end)
     else "runs.json not compared (attribution failed)" end) as $corr

  | (if ($m.merge_rc == 0 and $pa.state != "MERGED") or ($m.merge_rc != 0 and $pa.state == "MERGED") then
       {verdict: "anomaly", reason: "merge_rc \($m.merge_rc) disagrees with PR state \($pa.state)"}
     elif ($red | not) then
       {verdict: "invalid", reason: "precondition not red at pre-close (mergeStateStatus \($pre.pr.mergeStateStatus), newest conclusions \([$pn[].conclusion])); D-18 green-prior attempts are non-discriminating"}
     elif $m.gate_mode != "blocking" then
       {verdict: "invalid", reason: "gate_mode is \($m.gate_mode), not blocking"}
     elif $m.current_user_can_bypass != "never" then
       {verdict: "invalid", reason: "current_user_can_bypass is \($m.current_user_can_bypass), not never"}
     elif ($attr_ok | not) then
       {verdict: "anomaly", reason: "suite attribution failed: \($new | length) new suite(s) \($new), \($closeg | length) close-like, \($reopeng | length) other"}
     elif $m.variant == "a" and ($vap | not) then
       {verdict: "invalid", reason: "variant a precondition failed: at pre-reopen not every context newest was a completed close-suite (\($cs)) run"}
     elif $merged then
       (if $reopen_done then
          {verdict: "anomaly", reason: "merge accepted after the reopen suite \($ros) had completed on every context: enforcement failure (STOP)"}
        else
          {verdict: "lost", reason: "merge accepted while at post-merge some context newest was not a completed reopen-suite (\($ros)) run: \([$pm[] | select(.suite != $ros or .status != "completed") | .name])"}
        end)
     elif $m.merge_rc != 0 then
       {verdict: "blocked", reason: "merge refused (rc \($m.merge_rc)), refusal \($src)"}
     else
       {verdict: "anomaly", reason: "unreachable rule state"}
     end) as $v

  | {
      label: $m.label, variant: $m.variant, pr: $m.pr, head_sha: $m.head_sha,
      precondition_red: $red, variant_a_precondition: $vap,
      gate_mode: $m.gate_mode, current_user_can_bypass: $m.current_user_can_bypass,
      merge_rc: $m.merge_rc, merged: $merged,
      refusal_source: (if $merged then null else $src end),
      refusal_line: (if $merged or $line == "" then null else $line end),
      close_suite: $cs, reopen_suite: $ros, close_suite_conclusions: $csc,
      reopen_contexts_at_post_merge: $pm, reopen_complete_at_post_merge: $reopen_done,
      verdict: $v.verdict, reason: ($v.reason + "; " + $corr)
    }')

printf '%s\n' "$OUT" | jq . >"${D}/verdict.json"
cat "${D}/verdict.json"

case "$(jq -r '.verdict' <<<"$OUT")" in
  blocked) exit 0 ;;
  lost) exit 9 ;;
  invalid) exit 1 ;;
  anomaly) exit 4 ;;
  *) echo "ABORT(2): unexpected verdict" >&2; exit 2 ;;
esac
