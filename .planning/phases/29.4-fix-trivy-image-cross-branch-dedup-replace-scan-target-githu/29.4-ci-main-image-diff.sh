#!/usr/bin/env bash
set -euo pipefail

# 29.4-ci-main-image-diff.sh — compare the ci/main trivy-image Test between two
# `defectdojo-lifecycle-assert.sh snapshot --engagement ci/main` files
# (Phase 29.4 D-14.1 and D-11 measurement tool, offline, jq only).
#
# WHY. Phase 29.4 changes the scanned image tag from scan-target:<github.sha>
# to scan-target:ci. Two live facts must be MEASURED from DefectDojo state, not
# inferred from a green run:
#   mode upgrade (D-14.1) — the first ci/main reimport after the change must
#     mitigate the old SHA-path set (close_old_findings) and create a new
#     scan-target:ci set. If the old findings stay active, stop. A new finding
#     that is a duplicate means a PR engagement became its original (RESEARCH
#     Pitfall 2).
#   mode persist (D-11, D-21 rule) — a later ci/main reimport on a new main SHA
#     must keep the same finding ids. A title closed and re-created under a new
#     id is a FAIL (both hash_code values printed: a different hash means a
#     hashed field still varies). Titles only dropped or only added are Trivy
#     DB drift: measured, not failed.
# Both snapshots must carry the additive `tests` array (Phase 29.4) with
# exactly one Test titled trivy-image with scan_type Trivy Scan, and must be of
# the same engagement. The image Test id must be equal on both sides.
#
# Usage (no executable bit; always via bash):
#   bash 29.4-ci-main-image-diff.sh --mode upgrade|persist \
#     --before <snapshot.json> --after <snapshot.json> --out <result.json>
#
# Output: the result JSON {mode, verdict, image_test_id, counts, failures,
# drift, ...} is written to --out and printed on stdout.
# Exit: 0 PASS; 1 FAIL; 2 usage error or an input that is not a usable
# snapshot.

usage() {
  echo "usage: bash 29.4-ci-main-image-diff.sh --mode upgrade|persist --before <snapshot> --after <snapshot> --out <json>" >&2
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
[[ "$MODE" == "upgrade" || "$MODE" == "persist" ]] || usage
[[ -n "$BEFORE" && -n "$AFTER" && -n "$OUT" ]] || usage

# image_test FILE: the id of the one trivy-image Test, or exit 2.
image_test() {
  local n
  if ! n="$(jq -r 'if (.tests | type) != "array" or (.findings | type) != "array" then "no-tests"
      else [.tests[] | select(.scan_type == "Trivy Scan" and .title == "trivy-image")] | length | tostring end' "$1" 2> /dev/null)"; then
    echo "ERROR: ${1} is not readable JSON" >&2
    exit 2
  fi
  if [[ "$n" == "no-tests" ]]; then
    echo "ERROR: ${1} lacks a tests array or a findings array (take the snapshot with the Phase 29.4 lifecycle-assert)" >&2
    exit 2
  fi
  if [[ "$n" != "1" ]]; then
    echo "ERROR: ${1} has ${n} Tests titled trivy-image with scan_type Trivy Scan, expected 1" >&2
    exit 2
  fi
  jq '[.tests[] | select(.scan_type == "Trivy Scan" and .title == "trivy-image")][0].id' "$1"
}

for f in "$BEFORE" "$AFTER"; do
  [[ -r "$f" ]] || { echo "ERROR: cannot read ${f}" >&2; exit 2; }
done
BT="$(image_test "$BEFORE")"
AT="$(image_test "$AFTER")"
if [[ "$(jq '.engagement_id' "$BEFORE")" != "$(jq '.engagement_id' "$AFTER")" ]]; then
  echo "ERROR: --before engagement_id $(jq '.engagement_id' "$BEFORE") differs from --after engagement_id $(jq '.engagement_id' "$AFTER")" >&2
  exit 2
fi

# shellcheck disable=SC2016
COMMON='
def live: .active == true and .is_mitigated != true and .duplicate != true;
def stats: {total: length,
            active: map(select(.active == true)) | length,
            mitigated: map(select(.is_mitigated == true)) | length,
            duplicate: map(select(.duplicate == true)) | length};
($b[0].findings | map(select(.test == $bt))) as $ib
| ($a[0].findings | map(select(.test == $at))) as $ia
| ($b[0].findings | map(.id)) as $bids_all
| ($ia | map({key: (.id | tostring), value: .}) | from_entries) as $abyid
| [ if $bt != $at then {code: "image_test_id_changed", detail: "before Test \($bt), after Test \($at)"} else empty end ] as $f0
'

# shellcheck disable=SC2016
UPGRADE='
($ib | map(select(live))) as $old
| [$old[] | select($abyid[.id | tostring] == null) | .id] as $old_missing
| [$old[] | select($abyid[.id | tostring] != null and $abyid[.id | tostring].is_mitigated != true) | .id] as $old_left
| ($ia | map(select((.id | IN($bids_all[])) | not))) as $new_all
| ($new_all | map(select(.active == true and .is_mitigated != true))) as $new
| [$new_all[] | select(.duplicate == true) | {id, title, duplicate_finding}] as $new_dup
| [$new_all[] | select(((.file_path // "") | startswith("scan-target:")) and ((.file_path | startswith("scan-target:ci")) | not))
    | {id, title, file_path}] as $new_bad_fp
| ($old | map(.title) | unique) as $ot
| ($new | map(.title) | unique) as $nt
| ($f0
   + (if ($old_left | length) > 0 then [{code: "old_left_active", detail: "old SHA-path finding(s) not mitigated after the reimport", ids: $old_left}] else [] end)
   + (if ($old_missing | length) > 0 then [{code: "old_missing", detail: "old finding(s) absent from the after snapshot (deleted, not mitigated)", ids: $old_missing}] else [] end)
   + (if ($new | length) == 0 then [{code: "no_new_set", detail: "no new active, non-mitigated finding in the after image Test"}] else [] end)
   + (if ($new_dup | length) > 0 then [{code: "new_is_duplicate", detail: "new finding(s) are duplicates (a PR engagement may be their original)", findings: $new_dup}] else [] end)
   + (if ($new_bad_fp | length) > 0 then [{code: "new_file_path_not_scan_target_ci", findings: $new_bad_fp}] else [] end)
  ) as $failures
| {
    mode: "upgrade",
    verdict: (if ($failures | length) == 0 then "PASS" else "FAIL" end),
    image_test_id: {before: $bt, after: $at},
    counts: {before: ($ib | stats), after: ($ia | stats), old: ($old | length),
             new_all: ($new_all | length), new_active: ($new | length)},
    title_overlap: {common: ([$ot[] | select(IN($nt[]))] | length),
                    old_only: ([$ot[] | select(IN($nt[]) | not)] | length),
                    new_only: ([$nt[] | select(IN($ot[]) | not)] | length)},
    new_file_paths: ($new | map(.file_path) | unique),
    failures: $failures
  }
'

# shellcheck disable=SC2016
PERSIST='
($ib | map(select(live))) as $A
| ($ia | map(select(live))) as $B
| ($A | map(.id)) as $aids
| ($B | map(.id)) as $bids
| [$A[] | select(.id | IN($bids[]))] as $persisted
| [$A[] | select((.id | IN($bids[])) | not)] as $removed
| [$B[] | select((.id | IN($aids[])) | not)] as $added
| ($removed | map(.title) | unique) as $rt
| ($added | map(.title) | unique) as $at2
| [$rt[] | select(IN($at2[])) as $t | $t
    | {title: $t,
       removed: [$removed[] | select(.title == $t) | {id, file_path, hash_code}],
       added: [$added[] | select(.title == $t) | {id, file_path, hash_code}]}] as $recreated
| ($f0
   + (if ($persisted | length) == 0 then [{code: "vacuous", detail: "no ci/main trivy-image finding id persisted (empty before set or full replacement)"}] else [] end)
   + (if ($recreated | length) > 0 then [{code: "recreated", detail: "title(s) closed and re-created under a new id; compare the hash_code values", entries: $recreated}] else [] end)
  ) as $failures
| {
    mode: "persist",
    verdict: (if ($failures | length) == 0 then "PASS" else "FAIL" end),
    image_test_id: {before: $bt, after: $at},
    counts: {before: ($ib | stats), after: ($ia | stats), A: ($A | length), B: ($B | length),
             persisted: ($persisted | length), removed: ($removed | length), added: ($added | length),
             recreated: ($recreated | length)},
    recreated: $recreated,
    drift: {drift_dropped: [$rt[] | select(IN($at2[]) | not)], drift_added: [$at2[] | select(IN($rt[]) | not)]},
    failures: $failures
  }
'

if [[ "$MODE" == "upgrade" ]]; then PROG="${COMMON}| ${UPGRADE}"; else PROG="${COMMON}| ${PERSIST}"; fi
jq -n --slurpfile b "$BEFORE" --slurpfile a "$AFTER" --argjson bt "$BT" --argjson at "$AT" "$PROG" > "$OUT"
cat "$OUT"
[[ "$(jq -r '.verdict' "$OUT")" == "PASS" ]]
