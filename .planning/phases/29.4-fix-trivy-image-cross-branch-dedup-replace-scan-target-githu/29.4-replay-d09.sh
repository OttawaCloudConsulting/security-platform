#!/usr/bin/env bash
set -euo pipefail

# 29.4-replay-d09.sh — offline replay of the D-08/D-21 trivy-image verdict
# (Phase 29.4 D-09).
#
# WHY. security-platform scripts/defectdojo-lifecycle-assert.sh
# assert-pr-duplicates judges the trivy-image Test with one pure jq program,
# TRIVY_IMAGE_VERDICT, held between `# BEGIN TRIVY_IMAGE_VERDICT` and
# `# END TRIVY_IMAGE_VERDICT`. This script EXTRACTS that committed text (it
# never carries a copy, so the replay cannot drift from the live code,
# T-29.4-05) and runs it offline against the 29-16 evidence snapshots and
# synthetic variants of them:
#   R1 negative   the real 29-16 data (PR image Test 12, ci/main image Test 4):
#                 FAIL, 59 matched, 59 bad, no drift, hash not compared
#   R2 positive   R1 with every PR image finding rewritten to a correct
#                 duplicate of its title counterpart under scan-target:ci: PASS
#   R3 vacuous    R2 with every PR image title suffixed (no overlap): FAIL,
#                 0 matched, 59 drift
#   R4 D-21       R2 with equal hash_code on both sides, then one PR hash
#                 changed: FAIL, 1 bad, reason hash_code_differs, both hashes
# Synthetic inputs are built in a private mktemp -d directory; the 29-16
# evidence files are only read.
#
# Usage (no executable bit; always via bash, from anywhere):
#   bash 29.4-replay-d09.sh
#
# Output: one JSON line per case on stdout ({case, expect_ok, result}).
# Exit: 0 every case met its expectation; 1 a case did not; 2 the program could
# not be extracted or does not compile, or an input file is missing.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"
ASSERT="${ROOT}/repos/security-platform/scripts/defectdojo-lifecycle-assert.sh"
EVD="${ROOT}/.planning/phases/29-defectdojo-live-validation/evidence"
PR_SNAP="${EVD}/pr-branch-snapshot.json"
MAIN_SNAP="${EVD}/main-before-reimport-snapshot.json"
PRTID=12
MTID=4

if [[ $# -ne 0 ]]; then
  echo "usage: bash 29.4-replay-d09.sh (no arguments)" >&2
  exit 2
fi
for f in "$ASSERT" "$PR_SNAP" "$MAIN_SNAP"; do
  [[ -r "$f" ]] || { echo "ERROR: cannot read ${f}" >&2; exit 2; }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Extract: inside the BEGIN/END range, the lines strictly between the
# assignment line TRIVY_IMAGE_VERDICT=' and the closing ' line.
PROG="$(sed -n "/^# BEGIN TRIVY_IMAGE_VERDICT\$/,/^# END TRIVY_IMAGE_VERDICT\$/p" "$ASSERT" \
  | sed -n "/^TRIVY_IMAGE_VERDICT='\$/,/^'\$/p" | sed '1d;$d')"
if [[ -z "${PROG//[[:space:]]/}" ]]; then
  echo "ERROR: no TRIVY_IMAGE_VERDICT program found between the markers in ${ASSERT}" >&2
  exit 2
fi
# Compile check: run the program once on empty finding lists; any jq error
# (compile or runtime) is fatal.
echo '{"findings": []}' > "${TMP}/empty.json"
if ! jq -n --slurpfile pr "${TMP}/empty.json" --argjson prtid 0 --slurpfile main "${TMP}/empty.json" \
  --argjson mtid 0 "$PROG" > /dev/null 2> "${TMP}/compile.err"; then
  echo "ERROR: the extracted program does not run: $(head -c 300 "${TMP}/compile.err")" >&2
  exit 2
fi

run() { # PR_FILE MAIN_FILE
  jq -nc --slurpfile pr "$1" --argjson prtid "$PRTID" --slurpfile main "$2" --argjson mtid "$MTID" "$PROG"
}

ALL_OK=0
report() { # CASE RESULT_JSON JQ_EXPECTATION
  local ok
  ok="$(jq -c "$3" <<< "$2")"
  jq -nc --arg c "$1" --argjson ok "$ok" --argjson r "$2" '{case: $c, expect_ok: $ok, result: $r}'
  [[ "$ok" == "true" ]] || ALL_OK=1
}

# R2 input: every PR image finding a correct duplicate of its title counterpart.
jq --slurpfile m "$MAIN_SNAP" --argjson prtid "$PRTID" --argjson mtid "$MTID" '
  ([$m[0].findings[] | select(.test == $mtid and .is_mitigated != true and .duplicate != true)]
   | map({key: .title, value: .id}) | from_entries) as $cp
  | .findings |= map(if .test == $prtid
      then .duplicate = true | .duplicate_finding = $cp[.title] | .file_path = "scan-target:ci (debian 12.15)"
      else . end)' "$PR_SNAP" > "${TMP}/r2-pr.json"
# R3 input: no title overlap.
jq --argjson prtid "$PRTID" '.findings |= map(if .test == $prtid then .title += " NO-OVERLAP" else . end)' \
  "${TMP}/r2-pr.json" > "${TMP}/r3-pr.json"
# R4 inputs: equal hash_code per title on both sides, then one PR hash changed.
jq '.findings |= map(.hash_code = ("h-" + (.title | @base64)))' "$MAIN_SNAP" > "${TMP}/r4-main.json"
jq --argjson prtid "$PRTID" '
  .findings |= map(.hash_code = ("h-" + (.title | @base64)))
  | ([.findings[] | select(.test == $prtid) | .id] | min) as $victim
  | .findings |= map(if .id == $victim then .hash_code = "h-CHANGED" else . end)' \
  "${TMP}/r2-pr.json" > "${TMP}/r4-pr.json"

report R1-negative-29-16 "$(run "$PR_SNAP" "$MAIN_SNAP")" \
  '.verdict == "FAIL" and .matched_count == 59 and .bad_count == 59 and .drift.count == 0 and .hash_compared == false'
report R2-synthetic-positive "$(run "${TMP}/r2-pr.json" "$MAIN_SNAP")" \
  '.verdict == "PASS" and .matched_count == 59 and .bad_count == 0'
report R3-zero-overlap "$(run "${TMP}/r3-pr.json" "$MAIN_SNAP")" \
  '.verdict == "FAIL" and .matched_count == 0 and .drift.count == 59'
report R4-hash-differs "$(run "${TMP}/r4-pr.json" "${TMP}/r4-main.json")" \
  '.verdict == "FAIL" and .bad_count == 1 and .hash_compared == true
   and (.bad[0].reasons == ["hash_code_differs"])
   and .bad[0].pr_hash_code == "h-CHANGED" and (.bad[0].main_hash_codes | length) >= 1
   and (.bad[0].main_hash_codes | all(. != null and . != "h-CHANGED"))'

exit "$ALL_OK"
