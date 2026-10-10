#!/usr/bin/env bash
# 29.7-ledger-retest.sh -- Phase 29.7 D-12 re-test of gsd-sdk defects L-01..L-16 on gsd-sdk v1.42.3.
#
# Purpose
#   Re-run every defect in the Phase 29.7 ledger scope (L-01..L-16, see 29.7-RESEARCH.md
#   "Ledger Inventory") against the installed gsd-sdk and save the literal command, exit
#   code and output per defect to evidence/29.7-ledger-LNN.txt. Plan 06 builds
#   .planning/GSD-SDK-DEFECTS.md from these files.
#
# Safety contract (D-12, threat T-29.7-01)
#   - Read-only handlers (frontmatter.get, verify.key-links, verify.artifacts, summary-extract)
#     run against the real repo. None of them is in the SDK's QUERY_MUTATION_COMMANDS set.
#   - Mutating handlers run ONLY in a mktemp scratch copy named .planning, in a directory
#     proven to be outside any git repo, with cwd = the scratch root, --project-dir = the
#     scratch root and GSD_WORKSTREAM unset. --ws is never passed.
#   - The scratch copy overlays ROADMAP.md, STATE.md and REQUIREMENTS.md from the pinned
#     fixture commit dbeabd7 (layout A ROADMAP, 7/7/75/133/100 STATE frontmatter), so the
#     layout-dependent results are reproducible whatever the live records look like.
#   - After every scratch run a guard checks the real tree: (a) the run marker is absent,
#     (b) per-defect leak signatures are absent, (c) shasums of the real ROADMAP/STATE/
#     REQUIREMENTS are compared (informational; a change is logged with its git diff).
#
# Usage
#   bash .planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/29.7-ledger-retest.sh
#   (works from any directory; never needs the executable bit)
#
# Exit contract
#   0 = every test ran and every guard passed
#   1 = a guard failed (a "GUARD FAIL" line is written to stdout and to evidence/29.7-03-guard.txt;
#       the scratch dir of the failing test is kept and its path printed)
#   2 = preflight failure (missing tool, wrong gsd-sdk version, missing fixture)
#   Any exit 1 WITHOUT a "GUARD FAIL" line in the guard file is a harness bug, not a guard result.
#
# Output normalization
#   Trailing whitespace is stripped from every recorded line, because the repo pre-commit hook
#   (git diff-index --check) rejects it. gsd-sdk JSON output carries none; the only lines affected
#   are blank context lines of diff -u (a lone space) and source lines quoted by readbacks.
#   The recorded output is otherwise verbatim.

set -u

strip() { sed -e 's/[[:space:]]*$//'; }

# ---------------------------------------------------------------- preflight
for tool in gsd-sdk git jq shasum diff mktemp awk; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "PREFLIGHT FAIL: $tool not on PATH" >&2
    exit 2
  fi
done

PD=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PDB=$(basename "$PD")
REAL=$(cd "$PD/../../.." && pwd)
EV="$PD/evidence"
GUARD="$EV/29.7-03-guard.txt"
FIXTURE=dbeabd7
FIXTURE_FILES="ROADMAP.md STATE.md REQUIREMENTS.md"

if [ ! -d "$REAL/.planning" ] || [ "$(basename "$PD")" != "29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm" ]; then
  echo "PREFLIGHT FAIL: repo root not resolved (REAL=$REAL, PD=$PD)" >&2
  exit 2
fi

VERSION=$(gsd-sdk --version 2>&1)
case "$VERSION" in
  *1.42.3*) ;;
  *) echo "PREFLIGHT FAIL: gsd-sdk --version is '$VERSION'; this ledger is scoped to 1.42.3" >&2
     exit 2 ;;
esac

for f in $FIXTURE_FILES; do
  if ! git -C "$REAL" cat-file -e "$FIXTURE:.planning/$f" 2>/dev/null; then
    echo "PREFLIGHT FAIL: fixture $FIXTURE:.planning/$f not found" >&2
    exit 2
  fi
done

RUN_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HEAD_SHA=$(git -C "$REAL" rev-parse --short HEAD)
MARKER="SCRATCH-29.7-$$-$RANDOM"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/gsd297work.XXXXXX")

mkdir -p "$EV"
{
  echo "# 29.7-03 guard log (D-12, T-29.7-01)"
  echo "gsd-sdk version: $VERSION"
  echo "Date (UTC): $RUN_DATE"
  echo "HEAD: $HEAD_SHA"
  echo "Fixture: $FIXTURE (layout A)"
  echo "Marker: $MARKER"
  echo "Real repo: $REAL"
  echo
  echo "## git status --porcelain .planning (before run, informational)"
  git -C "$REAL" status --porcelain .planning
  echo
} | strip > "$GUARD"

# ---------------------------------------------------------------- helpers
EVF=""          # current evidence file
P_CMD=""        # paste-block command (primary command of the current test)
P_OUT=""        # file holding the primary command output
P_SET=0

flatten() { tr '\n' ' ' < "$1" | tr -s ' ' | sed -e 's/^ //' -e 's/ $//' | cut -c1-400 | strip; }

ev_open() {     # ev_open <LNN> <title> <mode>
  EVF="$EV/29.7-ledger-$1.txt"
  P_CMD=""; P_OUT=""; P_SET=0
  {
    echo "# $1: $2"
    echo "gsd-sdk version: $VERSION"
    echo "Date (UTC): $RUN_DATE"
    echo "HEAD: $HEAD_SHA"
    echo "Mode: $3"
    echo
  } | strip > "$EVF"
}

set_primary() { # set_primary <literal command string> <output file>
  if [ "$P_SET" -eq 0 ]; then
    P_CMD="$1"; P_OUT="$WORK/primary.$(basename "$EVF")"
    cp "$2" "$P_OUT"; P_SET=1
  fi
}

run_ro() {      # run_ro <args...>  -- read-only gsd-sdk call from the real repo root
  local out="$WORK/ro.out" ec lit
  lit=$(printf '%q ' gsd-sdk query "$@"); lit=${lit% }
  ( cd "$REAL" && gsd-sdk query "$@" ) > "$out" 2>&1
  ec=$?
  {
    echo "Command: $lit"
    echo "Cwd: $REAL"
    echo "Exit: $ec"
    echo "Actual:"
    cat "$out"
    echo
  } | strip >> "$EVF"
  set_primary "$lit" "$out"
  cp "$out" "$WORK/last.out"
}

readback() {    # readback <label> <shell command string, evaluated>
  {
    echo "Readback: $1"
    echo "\$ $2"
    eval "$2" 2>&1
    echo "(exit ${PIPESTATUS[0]:-?})"
    echo
  } | strip >> "$EVF"
}

paste_block() { # paste_block <expected>
  {
    echo "---- paste-ready repro (D-13) ----"
    echo "gsd-sdk version: $VERSION"
    echo "Command:  $P_CMD"
    echo "Expected: $1"
    echo "Actual:   $(flatten "$P_OUT")"
  } | strip >> "$EVF"
}

# --- scratch lifecycle
S=""
PRE_SHA=""
PRE_CP=""
scratch_new() {
  S=$(mktemp -d "${TMPDIR:-/tmp}/gsd297.XXXXXX")
  if git -C "$S" rev-parse --git-dir >/dev/null 2>&1; then
    echo "GUARD FAIL (scratch-inside-git) $S" | tee -a "$GUARD"
    exit 1
  fi
  cp -R "$REAL/.planning" "$S/.planning"
  mkdir -p "$S/fixture"
  for f in $FIXTURE_FILES; do
    git -C "$REAL" show "$FIXTURE:.planning/$f" > "$S/.planning/$f"
    cp "$S/.planning/$f" "$S/fixture/$f"
  done
  PRE_SHA=$( cd "$REAL" && shasum .planning/ROADMAP.md .planning/STATE.md .planning/REQUIREMENTS.md )
  PRE_CP=$(awk 'NR<=15 && /^  completed_plans:/ {print $2}' "$REAL/.planning/STATE.md")
}

scratch_exec() { # scratch_exec <evidence-file> <args...> -- mutator call inside $S only
  local evf="$1"; shift
  local out="$WORK/sc.out" ec lit
  lit=$(printf '%q ' gsd-sdk query "$@" --project-dir "$S"); lit=${lit% }
  ( cd "$S" && env -u GSD_WORKSTREAM gsd-sdk query "$@" --project-dir "$S" ) > "$out" 2>&1
  ec=$?
  {
    echo "Command: ( cd \"$S\" && env -u GSD_WORKSTREAM $lit )"
    echo "Cwd: $S (scratch copy named .planning; outside any git repo)"
    echo "Fixture: $FIXTURE (layout A)"
    echo "Exit: $ec"
    echo "Actual:"
    cat "$out"
    echo
  } | strip >> "$evf"
  cp "$out" "$WORK/last.out"
  SC_LIT=$(printf '%q ' gsd-sdk query "$@"); SC_LIT="${SC_LIT% } --project-dir <scratch-root>"
}

scratch_diffs() { # scratch_diffs <evidence-file>
  local evf="$1" f
  {
    echo "STATE.md frontmatter (lines 1-15) diff, fixture vs scratch:"
    diff -u --label "fixture/STATE.md:1-15" --label "scratch/STATE.md:1-15" \
      <(sed -n '1,15p' "$S/fixture/STATE.md") <(sed -n '1,15p' "$S/.planning/STATE.md") || true
    echo "(end frontmatter diff)"
    echo
    for f in $FIXTURE_FILES; do
      echo "Full diff, fixture vs scratch: $f"
      diff -u --label "fixture/$f" --label "scratch/$f" "$S/fixture/$f" "$S/.planning/$f" || true
      echo "(end diff $f)"
      echo
    done
  } | strip >> "$evf"
}

guard() {        # guard <test id>
  local id="$1" hits ec fail="" post_sha post_cp f
  echo "## $id" >> "$GUARD"
  # (a) marker: primary, concurrency-safe. PD excluded: this plan's own evidence records the marker.
  hits=$(grep -rlF --exclude-dir="$PDB" -- "$MARKER" "$REAL/.planning" 2>&1); ec=$?
  if [ -n "$hits" ] || [ "$ec" -eq 2 ]; then
    echo "GUARD FAIL (marker) $id: $hits" | tee -a "$GUARD"; fail=1
  else
    echo "marker absent from real .planning (excluding $PDB)" >> "$GUARD"
  fi
  # (b) leak signatures (checked after every scratch run, superset of the per-test plan list)
  if grep -qE 'Phase 29\.7 P01 .*5min' "$REAL/.planning/STATE.md"; then
    echo "GUARD FAIL (signature) $id: 'Phase 29.7 P01 .*5min' metric row in real STATE.md" | tee -a "$GUARD"; fail=1
  fi
  post_cp=$(awk 'NR<=15 && /^  completed_plans:/ {print $2}' "$REAL/.planning/STATE.md")
  if [ "$post_cp" != "$PRE_CP" ]; then
    echo "GUARD FAIL (signature) $id: real STATE completed_plans $PRE_CP -> $post_cp" | tee -a "$GUARD"; fail=1
  fi
  if ! grep -F '| 26. ' "$REAL/.planning/ROADMAP.md" | grep -qF '2026-09-25'; then
    echo "GUARD FAIL (signature) $id: real ROADMAP '| 26. ' row lost 2026-09-25" | tee -a "$GUARD"; fail=1
  fi
  if ! awk '/^### Phase 29\.1:/{b=1;next} b&&/^### /{b=0} b' "$REAL/.planning/ROADMAP.md" \
       | grep -qF '**Plans:** 2/2 plans complete'; then
    echo "GUARD FAIL (signature) $id: real ROADMAP 29.1 block lacks '**Plans:** 2/2 plans complete'" | tee -a "$GUARD"; fail=1
  fi
  echo "signatures checked: no 'Phase 29.7 P01 .*5min' row; completed_plans $PRE_CP -> $post_cp; 26 row has 2026-09-25; 29.1 block has 2/2" >> "$GUARD"
  # (c) shasum: secondary, informational
  post_sha=$( cd "$REAL" && shasum .planning/ROADMAP.md .planning/STATE.md .planning/REQUIREMENTS.md )
  if [ "$post_sha" != "$PRE_SHA" ]; then
    for f in ROADMAP.md STATE.md REQUIREMENTS.md; do
      if [ "$(echo "$PRE_SHA" | grep -F ".planning/$f")" != "$(echo "$post_sha" | grep -F ".planning/$f")" ]; then
        echo "GUARD NOTE (shasum changed) $id .planning/$f" | tee -a "$GUARD"
        git -C "$REAL" diff -U0 -- ".planning/$f" | strip >> "$GUARD"
      fi
    done
  else
    echo "shasums unchanged: ROADMAP.md STATE.md REQUIREMENTS.md" >> "$GUARD"
  fi
  if [ -n "$fail" ]; then
    echo "Scratch kept for inspection: $S" | tee -a "$GUARD"
    exit 1
  fi
  echo "REAL-UNCHANGED $id" | tee -a "$GUARD"
  echo >> "$GUARD"
  rm -rf "$S"; S=""
}

RAD="$REAL/.planning"
P23="$RAD/phases/23-nexus-generic-chart"
P23R=".planning/phases/23-nexus-generic-chart"
S2410=".planning/phases/24-nexus-anonymous-access-and-workstation-script/24-10-SUMMARY.md"

# ================================================================ read-only tests (real repo)

# ---- L-01
ev_open L01 "frontmatter.get --field reads '--field' as the field name; positional form nests" "R/O (real repo)"
run_ro frontmatter.get "$P23R/23-01-PLAN.md" --field must_haves
run_ro frontmatter.get "$P23R/23-01-PLAN.md" must_haves
readback "positional output: top-level keys" "jq -c 'keys' '$WORK/last.out'"
readback "positional output: .truths length (naive read)" "jq '.truths | length' '$WORK/last.out'"
readback "positional output: .must_haves.truths length" "jq '.must_haves.truths | length' '$WORK/last.out'"
paste_block '{"error":"Field not found","field":"--field"}; the positional form nests the value under must_haves (.truths length 0, .must_haves.truths length 4)'

# ---- L-02
ev_open L02 "verify.key-links false negatives on double-escaped patterns" "R/O (real repo)"
run_ro verify.key-links "$P23R/23-02-PLAN.md"
run_ro verify.key-links "$P23R/23-03-PLAN.md"
run_ro verify.key-links "$P23R/23-07-PLAN.md"
paste_block '23-02 1/2, 23-03 1/2, 23-07 0/1, each failing link "Pattern ... not found in source or target" on a double-escaped pattern (e.g. provision\\.sh)'

# ---- L-03
ev_open L03 "verify.key-links reports 'Source file not found' for branch-to-branch links" "R/O (real repo)"
run_ro verify.key-links "$P23R/23-08-PLAN.md"
paste_block '0/1, "Source file not found" for the branch source feature/phase-23-nexus-generic-chart'

# ---- L-04
ev_open L04 "verify.artifacts min_lines counts physical lines (+1)" "R/O (real repo)"
run_ro verify.artifacts "$P23R/23-07-PLAN.md"
readback "wc -l of the ADR-020 artifact" "( cd '$REAL' && wc -l docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md )"
paste_block '2/3, "Only 49 lines, need 60" on ADR-020 while wc -l reports 48'

# ---- L-05
ev_open L05 "verify.artifacts errors instead of reporting 0/0 when a plan has no artifacts" "R/O (real repo)"
run_ro verify.artifacts "$P23R/23-06-PLAN.md"
run_ro verify.artifacts "$P23R/23-08-PLAN.md"
paste_block '{"error":"No must_haves.artifacts found in frontmatter",...} for both 23-06 and 23-08'

# ---- L-16
ev_open L16 "frontmatter parser keeps YAML trailing comments inside the value" "R/O (real repo)"
run_ro frontmatter.get "$S2410" requirements-completed
run_ro summary-extract "$S2410" --fields requirements_completed --pick requirements_completed
readback "raw line in the file" "grep -nF 'requirements-completed' '$REAL/$S2410'"
paste_block 'the trailing "# Marked only after ..." comment is kept inside the value (frontmatter.get) and summary-extract returns it as a single string element'

# ================================================================ scratch tests (mutators)

# ---- L-06 (positional, then flag form in a fresh copy)
ev_open L06 "state.record-metric rejects the positional form" "scratch (2 runs, fresh copy each)"
scratch_new
echo "Marker: $MARKER" >> "$EVF"
scratch_exec "$EVF" state.record-metric "29.7" "01" "5min" "2" "1"
P_CMD="$SC_LIT"; P_OUT="$WORK/p.L06"; cp "$WORK/last.out" "$P_OUT"; P_SET=1
scratch_diffs "$EVF"
guard "L06-positional"
scratch_new
scratch_exec "$EVF" state.record-metric --phase 29.7 --plan 01 --duration 5min --tasks 2 --files 1
scratch_diffs "$EVF"
guard "L06-flag"
paste_block 'positional: {"error":"phase, plan, and duration required"}; flag form: recorded:true'

# ---- L-07
ev_open L07 "record-metric row lands under ## Deferred Items, not ## Performance Metrics" "scratch"
scratch_new
scratch_exec "$EVF" state.record-metric --phase 29.7 --plan 01 --duration 5min --tasks 2 --files 1
P_CMD="$SC_LIT"; P_OUT="$WORK/p.L07"; cp "$WORK/last.out" "$P_OUT"; P_SET=1
readback "new metric row in scratch STATE.md" "grep -nF '| Phase 29.7 P01 |' '$S/.planning/STATE.md'"
readback "## Performance Metrics heading" "grep -nF '## Performance Metrics' '$S/.planning/STATE.md'"
readback "## Deferred Items heading" "grep -nF '## Deferred Items' '$S/.planning/STATE.md'"
readback "all level-2 headings (to locate the section holding the row)" "grep -nE '^## ' '$S/.planning/STATE.md'"
scratch_diffs "$EVF"
guard "L07"
paste_block 'the new "| Phase 29.7 P01 |" row lands below ## Deferred Items, not under ## Performance Metrics'

# ---- L-08
ev_open L08 "state.add-decision rejects the positional form" "scratch"
scratch_new
echo "Marker: $MARKER" >> "$EVF"
scratch_exec "$EVF" state.add-decision "$MARKER positional decision"
P_CMD="$SC_LIT"; P_OUT="$WORK/p.L08"; cp "$WORK/last.out" "$P_OUT"; P_SET=1
readback "marker lines in scratch STATE.md (expect none)" "grep -nF '$MARKER' '$S/.planning/STATE.md'"
scratch_diffs "$EVF"
guard "L08"
paste_block '{"error":"summary required"}'

# ---- L-09 (without --phase, then with --phase in a fresh copy)
ev_open L09 "state.add-decision writes [Phase ?] without --phase" "scratch (2 runs, fresh copy each)"
echo "Marker: $MARKER" >> "$EVF"
scratch_new
scratch_exec "$EVF" state.add-decision --summary "$MARKER flag decision"
P_CMD="$SC_LIT"; P_OUT="$WORK/p.L09"; cp "$WORK/last.out" "$P_OUT"; P_SET=1
readback "decision line written (no --phase)" "grep -nF '$MARKER' '$S/.planning/STATE.md'"
scratch_diffs "$EVF"
guard "L09-no-phase"
scratch_new
scratch_exec "$EVF" state.add-decision --phase 29.7 --summary "$MARKER flag decision with phase"
readback "decision line written (--phase 29.7)" "grep -nF '$MARKER' '$S/.planning/STATE.md'"
scratch_diffs "$EVF"
guard "L09-with-phase"
paste_block 'without --phase: "- [Phase ?]: <text>"; with --phase 29.7: "- [Phase 29.7]: <text>"'

# ---- L-10
ev_open L10 "state.record-session positional form drops Stopped At yet reports recorded:true" "scratch"
echo "Marker: $MARKER" >> "$EVF"
scratch_new
scratch_exec "$EVF" state.record-session "" "$MARKER positional stopped-at" "None"
P_CMD="$SC_LIT"; P_OUT="$WORK/p.L10"; cp "$WORK/last.out" "$P_OUT"; P_SET=1
readback "fixture 'Stopped at' body line" "grep -nF 'Stopped at:' '$S/fixture/STATE.md'"
readback "scratch 'Stopped at' body line" "grep -nF 'Stopped at:' '$S/.planning/STATE.md'"
readback "marker lines in scratch STATE.md" "grep -nF '$MARKER' '$S/.planning/STATE.md'"
scratch_diffs "$EVF"
guard "L10"
paste_block 'recorded:true, "updated" lacks "Stopped At", and the STATE "Stopped at" body line is unchanged'

# ---- L-11
ev_open L11 "STATE mutators rewrite frontmatter status/progress without reporting it (incl. flag-form record-session, 2026-10-08)" "scratch"
echo "Marker: $MARKER" >> "$EVF"
echo "Cross-reference: the STATE.md lines 1-15 diff is also captured in L06 (flag run), L07, L08, L09 (both runs), L10 and L12." >> "$EVF"
echo >> "$EVF"
scratch_new
scratch_exec "$EVF" state.record-session --stopped-at "$MARKER" --resume-file None
P_CMD="$SC_LIT"; P_OUT="$WORK/p.L11"; cp "$WORK/last.out" "$P_OUT"; P_SET=1
readback "scratch 'Stopped at' body line" "grep -nF 'Stopped at:' '$S/.planning/STATE.md'"
scratch_diffs "$EVF"
guard "L11"
paste_block 'updated:["Last session","Stopped At","Resume File"] AND an unreported frontmatter rewrite (status: ready_to_plan -> planning, completed_plans: 133 -> 75)'

# ---- L-12
ev_open L12 "state.update-progress no-ops yet still rewrites the frontmatter" "scratch"
scratch_new
scratch_exec "$EVF" state.update-progress
P_CMD="$SC_LIT"; P_OUT="$WORK/p.L12"; cp "$WORK/last.out" "$P_OUT"; P_SET=1
scratch_diffs "$EVF"
guard "L12"
paste_block '{"updated":false,"reason":"Progress field not found in STATE.md"} and still a frontmatter rewrite'

# ---- L-13 / L-14 (one shared scratch run, two evidence files)
ev_open L14 "update-plan-progress re-stamps the completion date of an already-complete row" "scratch (run shared with L13)"
EVF14="$EVF"
ev_open L13 "roadmap.update-plan-progress does not tick the milestone checklist line (layout A)" "scratch (run shared with L14)"
EVF13="$EVF"
scratch_new
readback "BEFORE: checklist line 'Phase 26:' (scratch, fixture layout A)" "grep -nF 'Phase 26:' '$S/.planning/ROADMAP.md'"
EVF="$EVF14"
readback "BEFORE: '| 26. ' progress row (scratch, fixture layout A)" "grep -nF '| 26. ' '$S/.planning/ROADMAP.md'"
EVF="$EVF13"
scratch_exec "$EVF13" roadmap.update-plan-progress 26
cp "$WORK/last.out" "$WORK/p.L13"
{
  echo "(The same run is recorded in 29.7-ledger-L14.txt.)"
  echo
} | strip >> "$EVF13"
{
  echo "Command: (shared run, see 29.7-ledger-L13.txt) $SC_LIT"
  echo "Exit: see L13 (same run)"
  echo "Actual:"
  cat "$WORK/p.L13"
  echo
} | strip >> "$EVF14"
readback "AFTER: checklist line 'Phase 26:'" "grep -nF 'Phase 26:' '$S/.planning/ROADMAP.md'"
readback "AFTER: checklist line -- is the milestone checklist entry ticked?" "grep -nE '^- \\[[ x]\\] \\*\\*Phase 26:' '$S/.planning/ROADMAP.md'"
scratch_diffs "$EVF13"
EVF="$EVF14"
readback "AFTER: '| 26. ' progress row" "grep -nF '| 26. ' '$S/.planning/ROADMAP.md'"
readback "run date (UTC)" "date -u +%Y-%m-%d"
readback "ROADMAP diff fixture vs scratch" "diff -u --label fixture/ROADMAP.md --label scratch/ROADMAP.md '$S/fixture/ROADMAP.md' '$S/.planning/ROADMAP.md'"
guard "L13/L14"
EVF="$EVF13"; P_CMD="$SC_LIT"; P_OUT="$WORK/p.L13"
paste_block 'the milestone checklist line "- [ ] **Phase 26:" stays unticked (layout A)'
EVF="$EVF14"; P_CMD="$SC_LIT"; P_OUT="$WORK/p.L13"
paste_block 'the "| 26. DefectDojo Generic Chart |" row date changes from 2026-09-25 to the run date'

# ---- L-15
ev_open L15 "phase.complete **Plans:** regex prefix-matches decimal phases" "scratch"
scratch_new
readback "BEFORE: 29.1 block (scratch, fixture layout A)" "grep -n -A4 -F '### Phase 29.1:' '$S/.planning/ROADMAP.md'"
scratch_exec "$EVF" phase.complete 29
P_CMD="$SC_LIT"; P_OUT="$WORK/p.L15"; cp "$WORK/last.out" "$P_OUT"; P_SET=1
readback "AFTER: 29.1 block" "grep -n -A4 -F '### Phase 29.1:' '$S/.planning/ROADMAP.md'"
readback "AFTER: Phase 29 block Plans line" "grep -n -A4 -E '^### Phase 29:' '$S/.planning/ROADMAP.md'"
scratch_diffs "$EVF"
guard "L15"
paste_block 'the 29.1 block "**Plans:** 2/2 plans complete" becomes "**Plans:** 20/20 plans complete"'

# ---------------------------------------------------------------- done
{
  echo "## git status --porcelain .planning (after run, informational)"
  git -C "$REAL" status --porcelain .planning
  echo
  echo "All scratch runs guarded; harness exit 0."
} | strip >> "$GUARD"
rm -rf "$WORK"
echo "29.7-ledger-retest: all tests ran, every guard passed (marker $MARKER)"
exit 0
