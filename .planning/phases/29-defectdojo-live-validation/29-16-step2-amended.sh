#!/usr/bin/env bash
set -euo pipefail

# 29-16-step2-amended.sh — D-11 step 2 duplicates assertion under the scope
# amendment of 2026-09-29 (29-CONTEXT.md D-11 step 2).
#
# WHY. The canonical helper (security-platform
# scripts/defectdojo-lifecycle-assert.sh assert-pr-duplicates) requires EVERY
# non-fixture finding on ci/<branch> to be a duplicate of a ci/main original.
# Live, the 59 trivy-image findings are never duplicates across branches: their
# file_path is `scan-target:<github.sha>`, and github.sha differs between the PR
# merge commit and main. The operator ruled on 2026-09-29 to exclude the
# trivy-image Test (scan_type "Trivy Scan", test_title "trivy-image") from that
# assertion. Every other non-fixture finding must still be a duplicate of a
# ci/main finding. The helper itself is unchanged (29-18 PR B carries it).
#
# The exclusion key is read LIVE from the Test objects of the PR engagement,
# never passed in by id. Exactly one Test must match it.
#
# Usage (no executable bit; always via bash):
#   DEFECTDOJO_URL=https://... DEFECTDOJO_ADMIN_TOKEN_FILE=<0600 file> \
#   bash 29-16-step2-amended.sh --engagement-id <id> --engagement-name <name> \
#     --main-snapshot <file> --fixture-path <path> --out <json>
#
# TOKEN HANDLING mirrors the helper (T-29-03): https checked before the token
# is read; the token file must be mode 600; the token goes once into a 0600
# header file in a private mktemp -d directory and is sent only as -H @file;
# the EXIT trap removes the directory. TLS is always verified.
#
# Exit: 0 all checks PASS; 1 a check failed or an API read failed; 2 usage.

EID="" ENAME="" MAIN="" FX="" OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --engagement-id) EID="$2"; shift 2 ;;
    --engagement-name) ENAME="$2"; shift 2 ;;
    --main-snapshot) MAIN="$2"; shift 2 ;;
    --fixture-path) FX="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument $1" >&2; exit 2 ;;
  esac
done
for v in EID ENAME MAIN FX OUT; do
  [[ -n "${!v}" ]] || { echo "ERROR: missing ${v}" >&2; exit 2; }
done
[[ "$EID" =~ ^[0-9]+$ ]] || { echo "ERROR: --engagement-id must be numeric" >&2; exit 2; }
[[ -r "$MAIN" ]] || { echo "ERROR: --main-snapshot unreadable" >&2; exit 2; }
BASE="${DEFECTDOJO_URL:-}"
[[ "$BASE" == https://* ]] || { echo "ERROR: DEFECTDOJO_URL must be https://" >&2; exit 2; }
BASE="${BASE%/}"
TF="${DEFECTDOJO_ADMIN_TOKEN_FILE:-}"
[[ -s "$TF" ]] || { echo "ERROR: DEFECTDOJO_ADMIN_TOKEN_FILE missing or empty" >&2; exit 2; }
mode="$(stat -f '%Lp' "$TF" 2> /dev/null || stat -c '%a' "$TF")"
[[ "$mode" == "600" || "$mode" == "400" ]] || { echo "ERROR: token file mode ${mode}, expected 600" >&2; exit 2; }

umask 077
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" || true' EXIT
HDR="${WORK}/auth-header"
set -o noclobber
printf 'Authorization: Token %s\n' "$(tr -d '[:space:]' < "$TF")" > "$HDR"
set +o noclobber

# get PATH OUTFILE: one verified-TLS GET, HTTP 200 required.
get() {
  local code rc=0
  code="$(curl -sS --proto =https --proto-redir =https -H @"$HDR" -o "$2" -w '%{http_code}' "${BASE}$1")" || rc=$?
  if [[ "$rc" -ne 0 || "$code" != "200" ]]; then
    echo "==> D11-STEP2A-READ: FAIL - GET $1: curl exit ${rc}, http ${code:-none}"
    exit 1
  fi
}
# get_all PATH OUTFILE: one page of 250; fails unless it holds every row.
get_all() {
  get "$1&limit=250&offset=0" "$2"
  if [[ "$(jq '.count == (.results | length)' "$2")" != "true" ]]; then
    echo "==> D11-STEP2A-READ: FAIL - GET $1: count $(jq .count "$2") exceeds one page; extend paging"
    exit 1
  fi
}

get "/api/v2/engagements/${EID}/" "${WORK}/eng.json"
get_all "/api/v2/tests/?engagement=${EID}" "${WORK}/tests.json"
get_all "/api/v2/findings/?test__engagement=${EID}" "${WORK}/findings.json"

jq -n --slurpfile e "${WORK}/eng.json" --slurpfile t "${WORK}/tests.json" \
  --slurpfile f "${WORK}/findings.json" --slurpfile m "$MAIN" \
  --arg name "$ENAME" --arg fx "$FX" --argjson eid "$EID" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  ($t[0].results) as $tests
  | ($tests | map(.id)) as $tids
  | ($f[0].results) as $fs
  | ($m[0].findings | map(.id)) as $mids
  | ($m[0].findings | map(select(.duplicate != true)) | map(.id)) as $morig
  | [$tests[] | select(.engagement != $eid) | .id] as $foreign_tests
  | [$fs[] | select((.test | IN($tids[])) | not) | .id] as $foreign_findings
  | [$tests[] | select(.title == "trivy-image" and .scan_type == "Trivy Scan")] as $excl_tests
  | ($excl_tests | map(.id)) as $xids
  | ($fs | map(select((.file_path // "") | contains($fx)))) as $fixture
  | ($fixture | map(.id)) as $fxids
  | ($fs | map(select(((.id | IN($fxids[])) | not) and (.test | IN($xids[]))))) as $excluded
  | ($fs | map(select(((.id | IN($fxids[])) | not) and ((.test | IN($xids[])) | not)))) as $others
  | [$others[] | select(.duplicate != true or ((.duplicate_finding // -1) | IN($mids[]) | not))
      | {id, test, title, file_path, duplicate, duplicate_finding}] as $bad
  | {
      captured_at: $at,
      rule: "D-11 step 2 as amended 2026-09-29: every non-fixture finding outside the trivy-image Test (scan_type Trivy Scan, test_title trivy-image) must be a duplicate of a ci/main snapshot finding",
      engagement: {id: $e[0].id, name: $e[0].name, product: $e[0].product,
                   ok: ($e[0].id == $eid and $e[0].name == $name and $e[0].product == $m[0].product_id and $eid != $m[0].engagement_id)},
      read_guard: {foreign_tests: $foreign_tests, foreign_findings: $foreign_findings,
                   ok: (($foreign_tests | length) == 0 and ($foreign_findings | length) == 0)},
      tests: ($tests | map({id, title, scan_type})),
      exclusion_key: {tests: ($excl_tests | map({id, title, scan_type})), ok: (($xids | length) == 1)},
      branch_finding_count: ($fs | length),
      fixture: {count: ($fxids | length), ids: $fxids},
      excluded_measured: {
        count: ($excluded | length),
        ids: ($excluded | map(.id)),
        duplicate_count: ($excluded | map(select(.duplicate == true)) | length),
        file_paths: ($excluded | map(.file_path) | unique),
        main_trivy_image_file_paths: ($m[0].findings | map(.file_path // "" | select(startswith("scan-target:"))) | unique)
      },
      others: {count: ($others | length), ids: ($others | map(.id)),
               duplicate_targets: ($others | map(.duplicate_finding) | unique)},
      others_not_duplicate_of_main: $bad,
      duplicate_targets_are_main_originals: ([$others[] | .duplicate_finding | IN($morig[])] | all),
      duplicates_point_to_main_amended: (($others | length) > 0 and ($bad | length) == 0)
    }' > "$OUT"

rc=0
pass() { echo "==> $1: PASS - $2"; }
fail() { echo "==> $1: FAIL - $2"; rc=1; }
chk() { [[ "$(jq "$1" "$OUT")" == "true" ]]; }

if chk '.engagement.ok'; then pass "D11-STEP2A-ENGAGEMENT" "engagement ${EID} is '${ENAME}' in product $(jq '.engagement.product' "$OUT"), not the ci/main engagement"; else fail "D11-STEP2A-ENGAGEMENT" "$(jq -c '.engagement' "$OUT")"; fi
if chk '.read_guard.ok'; then pass "D11-STEP2A-READ-GUARD" "$(jq '.tests | length' "$OUT") tests and $(jq '.branch_finding_count' "$OUT") findings all belong to engagement ${EID}"; else fail "D11-STEP2A-READ-GUARD" "$(jq -c '.read_guard' "$OUT")"; fi
if chk '.exclusion_key.ok'; then pass "D11-STEP2A-EXCLUSION-KEY" "exactly one Test matches scan_type 'Trivy Scan' + title 'trivy-image': $(jq -c '.exclusion_key.tests' "$OUT")"; else fail "D11-STEP2A-EXCLUSION-KEY" "expected exactly 1 matching Test, got $(jq -c '.exclusion_key.tests' "$OUT")"; fi
echo "    INFO: excluded (measured, not asserted): $(jq '.excluded_measured.count' "$OUT") trivy-image finding(s), $(jq '.excluded_measured.duplicate_count' "$OUT") of them duplicates; PR file_paths $(jq -c '.excluded_measured.file_paths' "$OUT"); ci/main file_paths $(jq -c '.excluded_measured.main_trivy_image_file_paths' "$OUT")"
if chk '.duplicates_point_to_main_amended'; then
  pass "D11-STEP2-DUPLICATES-POINT-TO-MAIN (amended 2026-09-29)" "all $(jq '.others.count' "$OUT") non-fixture, non-trivy-image finding(s) on ${ENAME} are duplicates of ci/main snapshot findings"
elif [[ "$(jq '.others.count' "$OUT")" == "0" ]]; then
  fail "D11-STEP2-DUPLICATES-POINT-TO-MAIN (amended 2026-09-29)" "no findings remain after the exclusion; the assertion would be vacuous"
else
  fail "D11-STEP2-DUPLICATES-POINT-TO-MAIN (amended 2026-09-29)" "$(jq '.others_not_duplicate_of_main | length' "$OUT") of $(jq '.others.count' "$OUT") are not duplicates of a ci/main finding: $(jq -c '.others_not_duplicate_of_main[:10]' "$OUT")"
fi
echo "    INFO: every duplicate_finding target is a non-duplicate ci/main original: $(jq '.duplicate_targets_are_main_originals' "$OUT")"
echo "    evidence: ${OUT}"
if [[ "$rc" -eq 0 ]]; then echo "ALL PASS"; else echo "FAILED"; fi
exit "$rc"
