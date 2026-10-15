#!/bin/bash
# download.sh: all five statuses; artifact deleted on failure.
. "$(dirname "$0")/helpers.sh"
FX="$(mktemp -d "${TMPDIR:-/tmp}/wst-integ.XXXXXX")"; trap 'rm -rf "$FX"' EXIT
export WST_ROOT="$TOOLS_DIR"
# shellcheck source=/dev/null
. "$TOOLS_DIR/scripts/orchestrator/common.sh"; . "$TOOLS_DIR/scripts/common/versions.sh"; . "$TOOLS_DIR/scripts/common/download.sh"

mkart() { printf 'payload' > "$FX/art"; }
good="$(sha256_of <(printf payload) 2>/dev/null || printf payload | shasum -a 256 | cut -d' ' -f1)"
good="$(printf payload | shasum -a 256 | cut -d' ' -f1)"

mkart; printf '%s  art\n' "$good" > "$FX/sums"
dl_verify "$FX/art" art yes "file://$FX/sums"; rc=$?
assert_eq "$DL_STATUS" verified "verified"; assert_rc "$rc" 0 "verified rc"; assert_file "$FX/art"

mkart; printf '%s *art\n' "$good" > "$FX/sums"
dl_verify "$FX/art" art yes "file://$FX/missing" "file://$FX/sums"
assert_eq "$DL_STATUS" verified "second url used"

mkart
dl_verify "$FX/art" art yes "file://$FX/missing" || true
assert_eq "$DL_STATUS" fetch-failed "fetch-failed"; assert_no_file "$FX/art"

mkart; printf 'nothing useful\n' > "$FX/sums"
dl_verify "$FX/art" art yes "file://$FX/sums" || true
assert_eq "$DL_STATUS" malformed "malformed (no entry)"; assert_no_file "$FX/art"

mkart; printf 'zzzz  art\n' > "$FX/sums"
dl_verify "$FX/art" art yes "file://$FX/sums" || true
assert_eq "$DL_STATUS" malformed "malformed (bad hash)"; assert_no_file "$FX/art"

mkart; printf '%064d  art\n' 0 > "$FX/sums"
dl_verify "$FX/art" art yes "file://$FX/sums" || true
assert_eq "$DL_STATUS" mismatch "mismatch"; assert_no_file "$FX/art"

mkart
dl_verify "$FX/art" art no; rc=$?
assert_eq "$DL_STATUS" unverified "unverified (declared no)"; assert_rc "$rc" 0 "unverified rc"; assert_file "$FX/art"

# BSD style and single-hash files
mkart; printf 'SHA256 (art) = %s\n' "$good" > "$FX/sums"
dl_verify "$FX/art" art yes "file://$FX/sums"; assert_eq "$DL_STATUS" verified "bsd style"
mkart; printf '%s\n' "$good" > "$FX/sums"
dl_verify "$FX/art" art yes "file://$FX/sums"; assert_eq "$DL_STATUS" verified "single hash"
finish
