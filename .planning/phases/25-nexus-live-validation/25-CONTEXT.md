# Phase 25: Nexus Live Validation - Context

**Gathered:** 2026-09-20
**Status:** Ready for planning

<domain>
## Phase Boundary

NEXUS-05: The Nexus generic chart (Phase 23) with anonymous pull (Phase 24) is deployed to the operator's homelab cluster via the existing private ArgoCD overlay repo/pattern, and proxy pulls (npm/PyPI/Docker/Helm) — both anonymous and authenticated write-refusal — are proven live against that deployment.

</domain>

<decisions>
## Implementation Decisions

### Cluster and overlay access
- **D-01:** Claude gets direct kubeconfig access this session (via `KUBECONFIG` env var, defaulting to `~/.kube/config`) to run kubectl/helm against the homelab cluster live. Not user-relayed commands.
- **D-02:** Claude also gets git access to the private ArgoCD overlay repo (path/URL + credentials to be provided at execution time, not during this discussion) — clones it, writes the Application manifest + values, commits and pushes.
- **D-03:** ArgoCD and the private overlay repo pattern already exist on the homelab (other apps are already deployed this way). This phase is additive — add a new Application entry + values for Nexus, following the existing repo's established conventions. **Do not bootstrap ArgoCD or invent a new repo structure.**

### Validation depth
- **D-04:** Match the rigor of Phase 24's live gates (24-02, 24-05) — a real package pull through each of the 4 proxies (npm/PyPI/Docker/Helm), verified served/cached from Nexus rather than straight from upstream. Same depth, now against the homelab cluster instead of kind.
- **D-05:** Validate **both** anonymous pull (the NEXUS-02 live proof deferred from Phase 24) and authenticated-write-refusal (negative test — write/admin still requires auth), same shape as Phase 24's local write-refusal check.

### Claude's Discretion
- Exact Application manifest field values (sync policy, namespace naming, etc.) — follow whatever pattern the existing private overlay repo already uses for other apps; do not introduce a new convention.
- Order of proxy validation (npm/PyPI/Docker/Helm) — Claude's call.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 24 (anonymous access — being validated live here)
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-CONTEXT.md` — anonymous.enabled OFF-by-default decision; explicitly defers "live cluster validation of anonymous pull end-to-end" to this phase
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-RESEARCH.md` — REST call bodies, realm replace-not-append trap, Docker path shape (`HOST/<repo>/<image>`, no `/repository/` segment)
- `docs/adr/ADR-021*.md` — Phase 24 ADR

### Phase 23 (chart being deployed)
- `.planning/phases/23-nexus-generic-chart/` — chart structure, plans this phase deploys live
- `docs/adr/ADR-020*.md` — Phase 23 Nexus chart ADR

### Project-level architecture constraint
- `.planning/PROJECT.md` line ~144 — "generic-first, not private-then-strip" Key Decision: generic Helm chart in public repo is source of truth; private ArgoCD repo holds only a thin overlay (env values + Application manifest). This phase is the first live exercise of that decision.
- `.planning/REQUIREMENTS.md` — NEXUS-05 requirement text and Out-of-Scope table (Docker carve-out from Phase 24 applies here too)

No further external specs beyond these — private overlay repo path/URL/credentials to be supplied at execution time, not captured here.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 23 chart (`kubernetes/nexus/`) and Phase 24's live-gate scripts (24-02, 24-05 pattern) — same validation logic, retargeted at homelab context instead of kind.
- `workstation/nexus-setup.sh --verify` (24-07) — could double as part of live proof once pointed at the homelab Nexus URL.

### Established Patterns
- Live-gate checkpoint pattern from Phases 23/24 (live smoke script, measured assumptions, checkpoint commits before merge) — reuse for this phase's live cluster gate.

### Integration Points
- ArgoCD Application resource in the private overlay repo → this repo's public `kubernetes/nexus/` chart as the Helm source.

</code_context>

<specifics>
## Specific Ideas

No specific references beyond the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Phase 26-29 DefectDojo work is separately scoped and not part of this phase.)

</deferred>

---

*Phase: 25-nexus-live-validation*
*Context gathered: 2026-09-20*
