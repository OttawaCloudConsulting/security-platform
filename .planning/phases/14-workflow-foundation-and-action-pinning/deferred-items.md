# Phase 14 — Deferred Items

Out-of-scope discoveries logged during execution. Not fixed here per the executor scope boundary.

## gsd-sdk state handler defects (observed during 14-02 execution, 2026-09-10)

Four real defects in `gsd-sdk query state.*`. Each was worked around by hand; none were fixed
(SDK source is outside this phase's scope). The next executor will hit them again.

1. **`state.record-metric` rejects the documented positional form.**
   `gsd-sdk query state.record-metric "14" "02" "7min" "2" "1"` → `{"error":"phase, plan, and duration required"}`.
   Only the named form works: `--phase 14 --plan 02 --duration 7min --tasks 2 --files 1`.
   The executor agent definition documents the positional form.

2. **`state.add-decision` rejects a positional summary and then double-prefixes.**
   Positional → `{"error":"summary required"}`; `--summary "<text>"` works but writes
   `- [Phase ?]: <text>`, producing `- [Phase ?]: [Phase 14-02]: …` when the text already
   carries its own phase tag. Removed the `[Phase ?]: ` artifact with `sed`.

3. **`state.record-session` corrupts two frontmatter fields.**
   It reset `progress.percent` from `33` to `0` and truncated `last_activity` from its full
   descriptive string to a bare date. Hand-patched back to `67` and a full description.

4. **`state.update-progress` does not rewrite frontmatter `percent`.**
   It correctly recalculates and writes the body `Progress:` bar (`[███████░░░] 67%`) but leaves
   `progress.percent:` in the frontmatter untouched — so it cannot repair defect 3. Running
   `update-progress` after `record-session` still left `percent: 0` in the frontmatter.

**Ordering consequence:** run `state.record-session` BEFORE `state.update-progress`, and verify
the frontmatter `percent` by eye regardless — neither ordering fully repairs the field today.

## STATE.md metric rows land in the wrong table (pre-existing)

`state.record-metric` appends `| Phase 14 P02 | 7min | 2 tasks | 1 files |` to the end of the
"Carried forward from v1.1 close" issues table rather than to the "Performance Metrics" section.
Column semantics do not match that table's header. Pre-existing — Plan 01's `Phase 14 P01` row
sits in the same wrong place, so this is not a 14-02 regression. Left consistent rather than
half-corrected.
