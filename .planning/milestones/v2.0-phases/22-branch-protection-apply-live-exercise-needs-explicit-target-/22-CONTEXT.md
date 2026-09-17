# Phase 22: branch-protection --apply live exercise - Context

**Gathered:** 2026-09-16
**Status:** Ready for planning
**Source:** Operator decisions captured directly in orchestrator session (discuss-phase was explicitly skipped by operator; these decisions were made via AskUserQuestion prompts during /gsd:plan-phase 22 itself, before the planner ran)

<domain>
## Phase Boundary

Perform one live, irreversible-ish exercise of `branch-protection --apply` against a real target
repository to produce the phase's outstanding evidence: a witnessed `mergeStateStatus` transition
(`UNSTABLE` → `BLOCKED` → `CLEAN`) on one constant head SHA, proving a red required check blocks
merge and a restored/green state unblocks it. Restore the target repo's branch-protection ruleset
to its exact prior state afterward.

</domain>

<decisions>
## Implementation Decisions

### Target repository
- **Locked:** `terraform-pipelines` (full: `OttawaCloudConsulting/terraform-pipelines`).
- Rejected: `aws-zabbix-monitoring-solution` — ruled out mechanically by research (rulesets API
  returns `[]`, script has no POST create path). Not viable.
- Rejected: naming a fresh/different repo — operator did not choose this option.
- Rationale (from 22-RESEARCH.md): `terraform-pipelines` has a natural red check (Semgrep: 6
  findings measured this session) so the blocking gate trips for real without seeding anything.
  Its `main` branch has zero `.github/workflows/` — this is why the end-state decision below
  (restore, not keep) is mandatory rather than optional.

### End state after the live exercise
- **Locked:** Restore the branch-protection ruleset to its exact prior state after evidence is
  captured (PUT the original six-key projection back).
- Rejected: leaving required checks in place — only safe if the target repo has real CI on `main`,
  which `terraform-pipelines` does not. Leaving required checks would cause indefinite PR lockout
  for any future PR against that repo.
- This restore is the phase's non-negotiable gate: `diff rules-before.txt rules-restored.txt`
  must be empty before the phase can be marked done.

### Requirement ID
- **Locked:** `VAL-02`. Proposed by research as `[ASSUMED]` (every other v2.0 requirement ID was
  already marked complete); operator explicitly confirmed using `VAL-02` for this phase via
  AskUserQuestion.

### Claude's Discretion
- Exact task/wave breakdown, evidence directory layout, settle-poll implementation, and ADR-019
  content are left to the planner and researcher's findings (22-RESEARCH.md, 22-PATTERNS.md).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase research and patterns
- `.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-RESEARCH.md` — live-state findings, target-repo decision matrix, 9 pitfalls, validation architecture
- `.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-PATTERNS.md` — analog files, code excerpts, two flagged contradictions with RESEARCH.md (gh run rerun; settle-poll post-loop guard defect) and their resolutions
- `.planning/phases/22-branch-protection-apply-live-exercise-needs-explicit-target-/22-VALIDATION.md` — per-task verification map

### Project rules
- `CLAUDE.md` — `docs/adr/` is append-only; ADR-019 must be a new file, not an edit to ADR-017/ADR-018
- `.claude/rules/defensive-protocol-v2-session-management.md` — irreversible actions require explicit human confirmation before proceeding

</canonical_refs>

<specifics>
## Specific Ideas

None beyond the locked decisions above — see 22-RESEARCH.md for the concrete command sequences,
jq expressions, and evidence-directory conventions the planner should follow.

</specifics>

<deferred>
## Deferred Ideas

None — phase scope is fully captured by the locked decisions above.

</deferred>

---

*Phase: 22-branch-protection-apply-live-exercise-needs-explicit-target-*
*Context gathered: 2026-09-16 via orchestrator-session AskUserQuestion capture (post-hoc, pre-planning)*
