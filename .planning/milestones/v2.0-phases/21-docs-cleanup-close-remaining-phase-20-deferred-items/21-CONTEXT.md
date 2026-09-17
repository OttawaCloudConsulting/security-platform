# Phase 21: Docs cleanup — close remaining Phase 20 deferred items - Context

**Gathered:** 2026-09-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix two real, still-open documentation drift items carried from Phase 17's deferred-items.md
(items #4 and #6, re-confirmed OPEN by the Phase 20.1 status re-check on 2026-09-14):

1. `docs/milestone-plan/milestone-2-cicd-gate.md` names Grype as the SCA tool in 5 places; the
   live pipeline's SCA job (since Phase 16) runs Trivy filesystem + npm audit + pip-audit + tflint.
2. `docs/adoption-guide.md` documents artifact/SARIF counts (§6 First Run) but never states
   GitHub's SARIF upload size/result ceilings, so a consumer repo that exceeds them at scale gets
   no warning.

**Dropped from the roadmap's original phase goal:** the "7 stale `# v4` action-version comments in
the blueprint" item. Verified against the live file (`docs/development-security-stack-option-1.md`):
those 7 `actions/checkout@<SHA> # v4` comments were already fixed to `# v7` in Phase 20.1
(deferred-items.md item #7, status CLOSED, `17-VERIFICATION.md`). The only remaining `# v4`
comments in that file (3, not 7) are on `github/codeql-action/upload-sarif` and match the live pin
(`v4.38.0`) — not stale. ROADMAP.md's phase description is out of date on this point; the user
confirmed dropping it rather than repurposing or re-investigating. No code/doc change needed for
this item.

</domain>

<decisions>
## Implementation Decisions

### Milestone doc Grype→SCA fix
- **D-01:** Fix all 5 Grype mentions in `docs/milestone-plan/milestone-2-cicd-gate.md` for full
  consistency, not just line 78 (the deferred-item's literal citation). Locations: L16 (feature
  table), L33 and L43 (Done Criteria examples), L78 (JSON output list), L85 (DefectDojo parser
  artifact-name row).
- **D-02:** Replace Grype with the live SCA tool set by name where the doc lists specific tools:
  "Trivy filesystem, npm audit, pip-audit, tflint" (matching how the live job/blueprint/adoption
  guide already describe it elsewhere) — not a generic "SCA scan" placeholder.
- **D-03:** JSON output filename becomes `sca-results.json` (the live artifact name), replacing
  `grype-results.json`.
- **D-04:** DefectDojo parser artifact-name row drops "Anchore Grype", becomes "Trivy Scan" (or
  the correct live artifact/parser name for the sca job — researcher to confirm exact wording
  against the live workflow/adoption-guide before planner locks the replacement text).

### SARIF size/result ceiling documentation
- **D-05:** Add a new subsection in `docs/adoption-guide.md` near §6 ("First Run — What to
  Expect"), where SARIF/artifact counts are already discussed, covering GitHub code-scanning
  SARIF upload limits.
- **D-06:** The specific numbers (candidates from deferred-items.md #6, UNVERIFIED against live
  GitHub docs: 10 MB gzipped per file, 20 runs per file, 25,000 results per run, 25,000 rules per
  run) must be re-verified by the research phase against GitHub's current published limits before
  the planner locks the text — do not copy them from deferred-items.md as-is.
- **D-07:** Note this repo's fixture scale never approached these limits (largest run: 56 results,
  per deferred-items.md #6) as context for why it wasn't caught here, and that a consumer repo
  running Semgrep `p/default` or a large image scan can plausibly exceed them.

### Claude's Discretion
- Exact wording/formatting of the new adoption-guide.md subsection (heading level, whether it's a
  bullet list or a short paragraph) — follow the existing style of §6.
- Whether the milestone-plan doc's M2-F1 feature-table cell needs rewording beyond substituting the
  tool list (e.g., cross-referencing the live job name) — keep changes minimal, consistency is the
  goal, not a rewrite.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Deferred-item source of truth
- `.planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md` — items #4 (Grype
  reference, milestone-plan doc) and #6 (SARIF size/result limits) are the two items this phase
  closes. Item #7 (blueprint `# v4` comments) is already CLOSED per this file's "Status re-check
  2026-09-14" table — do not re-open or re-count it.
- `.planning/phases/17-sarif-upload-and-artifact-retention/17-VERIFICATION.md` — evidence backing
  the status re-check above.

### Files to edit
- `docs/milestone-plan/milestone-2-cicd-gate.md` — lines 16, 33, 43, 78, 85 (Grype→live-SCA-tools
  fix, D-01 through D-04).
- `docs/adoption-guide.md` — new subsection near §6 "First Run — What to Expect" (line ~218 area)
  (D-05 through D-07).

### Live pipeline ground truth (for the Grype replacement text)
- `.planning/STATE.md` and Phase 16 SUMMARY files — confirm live SCA job = Trivy filesystem + npm
  audit + pip-audit + tflint, artifact name `sca-results`.
- `docs/adoption-guide.md` §1 and §6 already describe the live SCA tool set correctly — use as the
  wording reference for consistency, don't invent new phrasing.

### Roadmap
- `.planning/ROADMAP.md` Phase 21 entry (requirements DIST-06, DIST-08) — note its "7 stale # v4"
  bullet is stale per this CONTEXT.md's `<domain>` section; do not treat it as in-scope.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — this is a documentation-only phase, no code changes.

### Established Patterns
- Prior doc-fix passes (Phase 17-06, Phase 20.1) always re-verify the live pipeline state before
  editing prose, rather than trusting the deferred-item's original wording — carry that pattern
  forward (already applied above for the # v4 drop).

### Integration Points
- None.

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond the decisions above — open to standard approaches for wording and
formatting within the constraints captured in `<decisions>`.

</specifics>

<deferred>
## Deferred Ideas

- **Blueprint's own Grype-based SCA job example** (`docs/development-security-stack-option-1.md`
  lines 41, 61, 130, 304-366, 1580-1594, 2076) — deferred-items.md #2, explicitly flagged as "an
  unbounded blueprint change" and out of scope for this phase. Not touched here.
- **Blueprint's `push: branches: [main]` trigger divergence** — deferred-items.md #3, ownership gap
  (Phase 19/VAL-01 closed without touching it). Not this phase's problem; flagged for a future
  docs-hygiene pass, no current owner.
- **Broken relative ADR links in the blueprint doc** — carried forward from Phase 16/17, still
  open, no owner assigned. Not in this phase's scope (roadmap doesn't cite it).

### Reviewed Todos (not folded)
None — discussion stayed within phase scope; no pending todos matched this phase.

</deferred>

---

*Phase: 21-Docs cleanup — close remaining Phase 20 deferred items*
*Context gathered: 2026-09-15*
