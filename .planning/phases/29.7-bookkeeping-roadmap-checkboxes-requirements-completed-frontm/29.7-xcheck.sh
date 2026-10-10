#!/usr/bin/env bash
set -u

# 29.7-xcheck.sh — read-only 3-source cross-check of the 10 v3.0 requirement
# IDs (Phase 29.7; D-07, v3.0 audit Tech Debt item 7).
#
# WHY. The v3.0 audit found requirement closures recorded only under a
# SUMMARY's `provides:` list, with no `requirements-completed` key. This
# script proves, per requirement ID, that all three closure sources agree:
#   1 VERIFICATION  the owning phase's NN-VERIFICATION.md names the ID
#                   (its frontmatter `.status` is shown)
#   2 SUMMARY       some SUMMARY in phases 23..29.x lists the ID under
#                   `requirements-completed` (yq --front-matter=extract; a grep
#                   fallback covers the yq-unparseable SUMMARYs 29.3-05,
#                   29.6-14, 29.6-15)
#   3 REQUIREMENTS  .planning/REQUIREMENTS.md has exactly one `- [x] **ID**`
#                   checklist line and a `| ID | Phase N | Complete |` row
#
# Read-only: nothing is written, moved or committed. The script uses `set -u`
# only, because the body depends on `grep -c` / `grep -q` returning non-zero
# without aborting the table.
#
# Usage (no executable bit; always via bash from PATH, from any directory):
#   bash .planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/29.7-xcheck.sh
#
# Output: a markdown table, one row per ID ending in PASS or FAIL, then the
# line `XCHECK: <n>/10 rows with all three sources`.
#
# Exit: 0 at 10/10; 1 if any row FAILs; 2 on preflight failure.

# ── 0. PREFLIGHT ─────────────────────────────────────────────────────────────
for bin in yq grep awk sed; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "PREFLIGHT FAIL: required binary '${bin}' is not on PATH"
    exit 2
  fi
done

# The script sits 3 directory levels below the repo root.
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "PREFLIGHT FAIL: cannot cd to repo root '${REPO_ROOT}'"; exit 2; }

# ── 1. CROSS-CHECK (body from 29.7-RESEARCH.md "D-07 3-source cross-check") ──
P=.planning/phases; REQ=.planning/REQUIREMENTS.md; fail=0
printf '| REQ-ID | Phase | VERIFICATION (file:status) | SUMMARY requirements-completed | REQUIREMENTS.md | Row |\n|---|---|---|---|---|---|\n'
for id in NEXUS-01 NEXUS-02 NEXUS-03 NEXUS-04 NEXUS-05 DDOJO-01 DDOJO-02 DDOJO-03 DDOJO-04 DDOJO-05; do
  ck=$(grep -cE "^- \[x\] \*\*${id}\*\*" "$REQ")
  row=$(grep -E "^\| ${id} \| Phase [0-9.]+ \| Complete \|" "$REQ")
  ph=$(printf '%s' "$row" | sed -E 's/^\| [A-Z]+-[0-9]+ \| Phase ([0-9.]+) \|.*/\1/')
  r3="checklist=$ck table=$([ -n "$row" ] && echo Complete || echo MISSING)"
  vf=$(ls "$P"/"$ph"-*/"$ph"-VERIFICATION.md 2>/dev/null | head -1)
  if [ -n "$vf" ] && grep -q "$id" "$vf"; then r1="$(basename "$vf"):$(yq --front-matter=extract '.status' "$vf" 2>/dev/null)"; else r1=MISSING; fi
  hits=""
  for s in "$P"/2[3-9]*/*-SUMMARY.md; do
    if v=$(yq --front-matter=extract '.requirements-completed // [] | .[]' "$s" 2>/dev/null); then
      printf '%s\n' "$v" | grep -qx "$id" && hits="$hits $(basename "$s" -SUMMARY.md)"
    else  # 3 SUMMARYs have unparseable frontmatter (29.3-05, 29.6-14, 29.6-15): grep fallback
      awk '/^---$/{n++; next} n==1' "$s" | grep -E '^requirements-completed:' | sed 's/#.*//' | grep -q "$id" && hits="$hits $(basename "$s" -SUMMARY.md)(grep)"
    fi
  done
  r2=${hits:-MISSING}; ok=PASS
  { [ "$ck" = 1 ] && [ -n "$row" ] && [ "$r1" != MISSING ] && [ "$r2" != MISSING ]; } || { ok=FAIL; fail=$((fail+1)); }
  printf '| %s | %s | %s | %s | %s | %s |\n' "$id" "$ph" "$r1" "$r2" "$r3" "$ok"
done
echo "XCHECK: $((10-fail))/10 rows with all three sources"; [ "$fail" -eq 0 ]
