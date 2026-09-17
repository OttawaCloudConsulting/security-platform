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

## Status re-check 2026-09-14 (Phase 20.1)

Re-checked by inspection only (inspection performed 2026-09-15) during Phase 20.1's retroactive
`14-VERIFICATION.md` authoring: the ledger, `.planning/STATE.md`, and later phases' own
`deferred-items.md`/`SUMMARY.md` files were read; no mutating `gsd-sdk` state handler was invoked
to "reproduce" these — a write would have polluted this phase's own bookkeeping. None of the five
items bear on CICD-05 or any of Phase 14's four ROADMAP success criteria; all are GSD
tooling/bookkeeping defects, not pipeline defects.

| # | Live status | Evidence |
|---|---|---|
| 1 | OPEN | `state.record-metric`'s positional form still fails: `.planning/phases/19-pipeline-validation-via-branch-target-prs/deferred-items.md:74` records `state.record-metric "19" "04" "11min" "2" "1"` → `{"error":"phase, plan, and duration required"}`, live-observed as recently as Phase 19 (2026-09-13/14), 3 days after Phase 14 closed. No fix landed in the interim. |
| 2 | OPEN | `state.add-decision`'s positional form still fails: same ledger, `:75` — `state.add-decision "<text>"` → `{"error":"summary required"}`, observed at Phase 19. |
| 3 | OPEN | `state.record-session` still corrupts a field, now a different one: same ledger, `:76` — reports `{"recorded":true}` while silently dropping `Stopped At` from its `updated` array (Phase 14 observed `percent`/`last_activity` corruption instead; the defect class persists across phases even as the specific symptom shifts). |
| 4 | OPEN | `state.update-progress` still does not repair frontmatter `percent`: same ledger, `:95-98` — Phase 19 observed frontmatter `percent: 71` frozen since Phase 18 close while the body bar correctly reads 92% (34/37 plans). Directly corroborates Phase 14's original finding. |
| 5 | OPEN | STATE.md metric-row placement issue persists: `.planning/STATE.md:181-182` (`Phase 14 P01`/`P02` rows) sit under the `## Deferred Items` heading (`STATE.md:173`, "Carried forward from v1.1 close" table), not `## Performance Metrics` (`STATE.md:35`) — live-grepped this session. The same misplacement continues through at least `Phase 16 P03` (`STATE.md` rows following P01/P02), confirming the issue was never corrected between Phase 14 and Phase 20.1. |

**Out of scope for CICD-05's verdict.** All four ROADMAP Phase 14 success criteria and CICD-05
are independently VERIFIED on live GitHub evidence in `14-VERIFICATION.md`, regardless of these
five items' status. None are handed to a future phase by this re-check; they remain exactly where
the original phase left them, for `gsd-sdk` tooling maintainers.
