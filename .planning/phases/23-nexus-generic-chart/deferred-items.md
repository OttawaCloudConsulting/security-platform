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
