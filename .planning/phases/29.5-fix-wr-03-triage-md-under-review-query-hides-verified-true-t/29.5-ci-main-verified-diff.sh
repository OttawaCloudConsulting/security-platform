#!/usr/bin/env bash
set -euo pipefail

# 29.5-ci-main-verified-diff.sh — compare the `verified` state of ci/main
# findings between two `defectdojo-lifecycle-assert.sh snapshot --engagement
# ci/main` files (Phase 29.5 D-12 readback and D-05 reset check, offline, jq
# only).
#
# WHY. Phase 29.5 makes the Trivy imports send verified=false. Only the
# ci/main readback is in scope (D-12). Two live facts must be MEASURED from
# DefectDojo state, not inferred from a green run:
#   mode fix (D-12) — before = ci/main before the fix, after = ci/main after
#     the first post-fix reimport. A NEW triage-open Trivy finding that reads
#     verified=true is the live failure of the fix. A non-Trivy finding whose
#     verified changed, or a Trivy finding open on both sides that went from
#     false to true, is a regression. The count of pre-fix Trivy ids that
#     still read verified=true (`still_true`, `reset_needed`) is a MEASUREMENT
#     that decides whether the one-time D-05 reset runs. It is never a pass or
#     a fail condition.
#   mode reset (D-05) — before = the after-fix snapshot, after = the snapshot
#     taken after the one-time reset. FAIL if any triage-open Trivy finding
#     still reads verified=true, or if the reset changed verified on any
#     non-Trivy finding or on any Trivy finding that was not triage-open in
#     before (scope check).
# "Trivy" = a finding whose test is one of the two Tests titled trivy-fs and
# trivy-image with scan_type Trivy Scan. "Triage-open" = active true,
# duplicate false, is_mitigated false, false_p false, out_of_scope false,
# risk_accepted false. Both snapshots must carry the `tests` array (Phase 29.4
# lifecycle-assert) with exactly one trivy-fs and one trivy-image Trivy Scan
# Test, with equal Test ids and an equal engagement_id on both sides.
#
# Usage (no executable bit; always via bash):
#   bash 29.5-ci-main-verified-diff.sh --mode fix|reset \
#     --before <snapshot.json> --after <snapshot.json> --out <result.json>
#
# Output: the result JSON {mode, verdict, counts, failures, ...} is written to
# --out and printed on stdout.
# Exit: 0 PASS; 1 FAIL; 2 usage error or an input that is not a usable
# snapshot.

usage() {
  echo "usage: bash 29.5-ci-main-verified-diff.sh --mode fix|reset --before <snapshot> --after <snapshot> --out <json>" >&2
  exit 2
}

MODE="" BEFORE="" AFTER="" OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) [[ $# -ge 2 ]] || usage; MODE="$2"; shift 2 ;;
    --before) [[ $# -ge 2 ]] || usage; BEFORE="$2"; shift 2 ;;
    --after) [[ $# -ge 2 ]] || usage; AFTER="$2"; shift 2 ;;
    --out) [[ $# -ge 2 ]] || usage; OUT="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument $1" >&2; usage ;;
  esac
done
[[ "$MODE" == "fix" || "$MODE" == "reset" ]] || usage
[[ -n "$BEFORE" && -n "$AFTER" && -n "$OUT" ]] || usage

# trivy_test FILE TITLE: the id of the one TITLE Trivy Scan Test, or exit 2.
trivy_test() {
  local n
  # shellcheck disable=SC2016
  if ! n="$(jq -r --arg t "$2" 'if (.tests | type) != "array" or (.findings | type) != "array" then "no-tests"
      else [.tests[] | select(.scan_type == "Trivy Scan" and .title == $t)] | length | tostring end' "$1" 2> /dev/null)"; then
    echo "ERROR: ${1} is not readable JSON" >&2
    exit 2
  fi
  if [[ "$n" == "no-tests" ]]; then
    echo "ERROR: ${1} lacks a tests array or a findings array (take the snapshot with the Phase 29.4 lifecycle-assert)" >&2
    exit 2
  fi
  if [[ "$n" != "1" ]]; then
    echo "ERROR: ${1} has ${n} Tests titled ${2} with scan_type Trivy Scan, expected 1" >&2
    exit 2
  fi
  # shellcheck disable=SC2016
  jq --arg t "$2" '[.tests[] | select(.scan_type == "Trivy Scan" and .title == $t)][0].id' "$1"
}

for f in "$BEFORE" "$AFTER"; do
  [[ -r "$f" ]] || { echo "ERROR: cannot read ${f}" >&2; exit 2; }
done
BFS="$(trivy_test "$BEFORE" trivy-fs)"
BIM="$(trivy_test "$BEFORE" trivy-image)"
AFS="$(trivy_test "$AFTER" trivy-fs)"
AIM="$(trivy_test "$AFTER" trivy-image)"
if [[ "$BFS" != "$AFS" ]]; then
  echo "ERROR: trivy-fs Test id differs: --before ${BFS}, --after ${AFS}" >&2
  exit 2
fi
if [[ "$BIM" != "$AIM" ]]; then
  echo "ERROR: trivy-image Test id differs: --before ${BIM}, --after ${AIM}" >&2
  exit 2
fi
if [[ "$(jq '.engagement_id' "$BEFORE")" != "$(jq '.engagement_id' "$AFTER")" ]]; then
  echo "ERROR: --before engagement_id $(jq '.engagement_id' "$BEFORE") differs from --after engagement_id $(jq '.engagement_id' "$AFTER")" >&2
  exit 2
fi

# shellcheck disable=SC2016
COMMON='
def open: .active == true and .duplicate != true and .is_mitigated != true
          and .false_p != true and .out_of_scope != true and .risk_accepted != true;
[$fs, $im] as $trivy_ids
| def trivy: (.test | IN($trivy_ids[]));
  ($b[0].findings) as $fb
| ($a[0].findings) as $fa
| ($fb | map({key: (.id | tostring), value: .}) | from_entries) as $bbyid
| ($fa | map({key: (.id | tostring), value: .}) | from_entries) as $abyid
| [$fb[] | select(trivy and open)] as $bopen
| [$fa[] | select(trivy and open)] as $aopen
| [$fb[] | select((trivy | not) and $abyid[.id | tostring] != null
                  and $abyid[.id | tostring].verified != .verified) | .id] | sort as $non_trivy_changed
'

# shellcheck disable=SC2016
FIX='
[$bopen[] | select(.verified == true)] as $bopen_true
| [$bopen[] | $abyid[.id | tostring] as $x | select($x != null and ($x | open) and $x.verified == true) | .id] | sort as $still_true
| [$bopen_true[] | $abyid[.id | tostring] as $x | select($x != null and $x.verified != true) | .id] | sort as $now_false
| [$bopen[] | $abyid[.id | tostring] as $x | select($x == null or (($x | open) | not)) | .id] | sort as $no_longer_open
| [$fa[] | select(trivy and $bbyid[.id | tostring] == null)] as $new_trivy
| [$new_trivy[] | select(open)] as $new_open
| [$new_open[] | select(.verified == true) | .id] | sort as $new_open_true
| [$bopen[] | select(.verified != true) | $abyid[.id | tostring] as $x
    | select($x != null and ($x | open) and $x.verified == true) | .id] | sort as $became_true
| ( (if ($new_open_true | length) > 0 then [{code: "NEW_TRIVY_VERIFIED", detail: "new triage-open Trivy finding(s) read verified=true after the fix (the import still verifies)", ids: $new_open_true}] else [] end)
  + (if ($non_trivy_changed | length) > 0 then [{code: "NON_TRIVY_VERIFIED_CHANGED", detail: "non-Trivy finding(s) whose verified changed", ids: $non_trivy_changed}] else [] end)
  + (if ($became_true | length) > 0 then [{code: "TRIVY_BECAME_VERIFIED", detail: "Trivy finding(s) open on both sides that went from verified=false to verified=true", ids: $became_true}] else [] end)
  ) as $failures
| {
    mode: "fix",
    verdict: (if ($failures | length) == 0 then "PASS" else "FAIL" end),
    engagement_id: $b[0].engagement_id,
    trivy_test_ids: {"trivy-fs": $fs, "trivy-image": $im},
    counts: {before_open_trivy: ($bopen | length),
             before_open_trivy_true: ($bopen_true | length),
             still_true: ($still_true | length),
             now_false: ($now_false | length),
             no_longer_open: ($no_longer_open | length),
             new_trivy: ($new_trivy | length),
             new_trivy_open: ($new_open | length),
             new_trivy_open_true: ($new_open_true | length),
             non_trivy_verified_changed: ($non_trivy_changed | length)},
    reset_needed: (($still_true | length) > 0),
    still_true_ids: $still_true,
    now_false_ids: $now_false,
    new_trivy: [$new_trivy[] | {id, test, verified, active, duplicate, is_mitigated}],
    failures: $failures
  }
'

# shellcheck disable=SC2016
RESET='
[$bopen[] | select(.verified == true)] as $bopen_true
| [$bopen_true[] | $abyid[.id | tostring] as $x | select($x != null and $x.verified != true) | .id] | sort as $reset_ids
| [$aopen[] | select(.verified == true) | .id] | sort as $after_open_true
| ($bopen | map(.id)) as $bopen_ids
| [$fb[] | select(trivy and ((.id | IN($bopen_ids[])) | not) and $abyid[.id | tostring] != null
                  and $abyid[.id | tostring].verified != .verified) | .id] | sort as $oos_trivy_changed
| ( (if ($after_open_true | length) > 0 then [{code: "RESET_INCOMPLETE", detail: "triage-open Trivy finding(s) still read verified=true after the reset", ids: $after_open_true}] else [] end)
  + (if ($non_trivy_changed | length) > 0 then [{code: "RESET_SCOPE_NON_TRIVY", detail: "the reset changed verified on non-Trivy finding(s)", ids: $non_trivy_changed}] else [] end)
  + (if ($oos_trivy_changed | length) > 0 then [{code: "RESET_SCOPE_TRIVY", detail: "the reset changed verified on Trivy finding(s) that were not triage-open before", ids: $oos_trivy_changed}] else [] end)
  ) as $failures
| {
    mode: "reset",
    verdict: (if ($failures | length) == 0 then "PASS" else "FAIL" end),
    engagement_id: $b[0].engagement_id,
    trivy_test_ids: {"trivy-fs": $fs, "trivy-image": $im},
    counts: {before_open_trivy_true: ($bopen_true | length),
             reset_count: ($reset_ids | length),
             after_open_trivy_true: ($after_open_true | length),
             non_trivy_verified_changed: ($non_trivy_changed | length),
             out_of_scope_trivy_changed: ($oos_trivy_changed | length)},
    reset_ids: $reset_ids,
    failures: $failures
  }
'

if [[ "$MODE" == "fix" ]]; then PROG="${COMMON}| ${FIX}"; else PROG="${COMMON}| ${RESET}"; fi
jq -n --slurpfile b "$BEFORE" --slurpfile a "$AFTER" --argjson fs "$BFS" --argjson im "$BIM" "$PROG" > "$OUT"
cat "$OUT"
[[ "$(jq -r '.verdict' "$OUT")" == "PASS" ]]
