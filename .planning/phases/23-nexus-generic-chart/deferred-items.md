# Phase 23 — Deferred Items

Out-of-scope discoveries logged during execution. Nothing here was fixed in this phase.

## From 23-07 (documentation repository, `security_solution`)

1. **`CLAUDE.md` §Project Structure says `docs/adr/` holds "ADR-001 through ADR-018".**
   That range was already stale before this plan (ADR-019 landed 2026-09-16) and is now
   two records behind after ADR-020. The fix is a one-word range bump, but 23-07's
   acceptance criteria confine the CLAUDE.md edit to §What This Repository Is and assert
   that `git diff CLAUDE.md` touches no other section, so it was deliberately not made
   here. Whoever next edits CLAUDE.md for an unrelated reason should correct it — or
   better, replace the hard-coded range with "see `docs/adr/README.md` for the index",
   which it already says on the same line and which does not go stale.

2. **`provision.readiness.attempts` / `provision.readiness.intervalSeconds` are still
   dead knobs in `repos/security-platform/kubernetes/nexus/values.yaml`.**
   Handed forward by 23-04, documented as present-but-not-read by 23-05, untouched by
   23-06 (whose `files_modified` listed `values.yaml` but whose tasks did not instruct
   an edit), and unreachable from 23-07, which is a documentation-repository plan and
   cannot modify chart files. Recorded as item 5 of ADR-020's `## What was NOT verified`.
   Resolving it means either wiring them through 23-02's four-variable env contract and
   `scripts/nexus-live-smoke.sh`, or deleting them and updating the chart README's values
   table and limitations bullet together. Phase 24 owns the choice.

3. **CI's Checkov provides zero coverage of `kubernetes/nexus`.**
   Measured by 23-06 and recorded as item 1 of ADR-020's `## What was NOT verified`: the
   pinned `ghcr.io/bridgecrewio/checkov:3.3.17` container's helm runner engages and then
   fails at `helm template` on the chart's own `required` credential guard, logged at
   WARNI. 24 kubernetes-framework findings exist latently (5 wrapper, 19 subchart) and
   none reach the pipeline. Phase 24 must pick between accepting it, a scanner-only
   values file, or a committed rendered manifest. **Not** by weakening the guard.

4. **Subchart pin freshness has no automation.**
   `Chart.lock` pins `stevehipwell/nexus3` at 5.26.0 and neither Dependabot (no Helm
   chart-dependency manager) nor any existing bot will bump it. Renovate's `helmv3`
   manager would, but adopting a second bot is a repository-wide decision. Dispositioned
   as deferred in ADR-020's `**Tradeoff — subchart pin freshness.**` paragraph; it is a
   decision for `security-platform` as a whole, not for this phase.

5. **Two pre-existing uncommitted changes in `.planning/`, untouched by 23-08 Task 3.**
   Noticed while staging the Task 3 closeout commit and deliberately NOT staged, per the
   executor's scope boundary (only fix what the current task caused):
   - `.planning/config.json` — modified, a trailing-newline-only change (`\ No newline at
     end of file` → newline). Working-tree mtime `2026-09-18T08:01Z`, a full day before
     this run started (`2026-09-19T11:45Z`), so no verb in this run produced it.
   - `.planning/v2.0-MILESTONE-AUDIT.md` — **deleted** from the working tree (83 lines),
     last committed in `c6ccf48 docs(v2.0): close phase 21 …`. Also pre-existing.
   Neither belongs to Phase 23. Whoever picks these up should decide whether the audit
   file's deletion was intentional (v2.0 shipped 2026-09-17, so it may be) before
   committing it, rather than sweeping it in with a `git add -A`.

6. **`gsd-sdk query state.update-progress` does not work against this STATE.md.**
   It returned `{"updated": false, "reason": "Progress field not found in STATE.md"}`.
   This STATE.md carries progress as a YAML map in frontmatter (`progress:` with
   `total_phases` / `completed_plans` / `percent`), not as the flat field the handler
   looks for. Harmless here — `state.advance-plan` recalculated the same counters
   correctly (7→8 plans, 0→1 phases, 0→100%) — but any workflow that relies on
   `update-progress` alone on this project will silently no-op.

7. **`gsd-sdk query state.record-metric` rejects positional arguments.**
   The executor workflow documents a positional form (`state.record-metric "$PHASE"
   "$PLAN" "$DURATION" …`) and `key=value` also fails; both return
   `{"error": "phase, plan, and duration required"}`. Only the flag form works:
   `--phase 23 --plan 08 --duration 18min --tasks 3 --files 0`. Same for
   `state.add-decision`, which needs `--summary`, not `--decision`.

8. **`roadmap.update-plan-progress` does not flip the milestone checklist line.**
   It correctly flipped `- [ ] 23-08-PLAN.md` → `[x]` and the progress table row to
   `8/8 | Complete | 2026-09-19`, but left line 15's
   `- [ ] **Phase 23: Nexus Generic Chart** …` unchecked. Hand-edited to `[x]` with a
   `(completed 2026-09-19)` suffix to match how Phases 20/21/22 are recorded.
