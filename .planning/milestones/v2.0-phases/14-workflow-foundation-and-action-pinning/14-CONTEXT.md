# Phase 14: Workflow Foundation and Action Pinning - Context

**Gathered:** 2026-09-10
**Status:** Ready for planning

<domain>
## Phase Boundary

This repo gets a callable security-scanning workflow skeleton (`on: workflow_call`) plus a thin `pull_request` caller workflow that invokes it, all actions SHA-pinned with version comments, and Dependabot configured to keep those pins current. No real scan jobs yet (SAST/IaC/SCA/container/secrets land in Phase 15) — this phase proves the wiring: PR opens → workflow runs → doesn't block merge.

</domain>

<decisions>
## Implementation Decisions

### Placeholder job content
- **D-01:** The callable workflow's single placeholder job runs `actions/checkout` only (pinned SHA). Not a bare `echo` no-op, and not five pre-named stub jobs for sast/iac/sca/container/secrets — Phase 15 adds the real jobs from scratch.

### SHA-pin convention
- **D-02:** Reuse the existing convention from `repos/security-platform/cicd/.github/workflows/security.yml`: `uses: <action>@<full-sha>  # v<N>` — full commit SHA with a trailing human-readable version comment.

### Dependabot scope
- **D-03:** `.github/dependabot.yml` has a single `github-actions` ecosystem entry, weekly schedule. Do not add npm/pip/terraform ecosystem entries yet — those dependency types don't exist in this repo's workflows until later phases.

### Caller workflow trigger scope
- **D-04:** Thin caller workflow triggers on `pull_request` only, all branches (no branch filter, no `push` trigger). Matches ROADMAP success criteria #1 verbatim ("Opening a pull request... triggers a security workflow run"). Push-to-main trigger can be added in a later phase if needed.

### Claude's Discretion
- Exact file/directory naming under `.github/workflows/` (e.g. `security.yml` for the callable file, `pr-security.yml` or similar for the caller) — not discussed, pick sensible names consistent with the reusable-workflow convention (`uses: OCC-github/security_solution/.github/workflows/<name>.yml@ref` per DIST-07/ROADMAP).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap and requirements
- `.planning/ROADMAP.md` §Phase 14 — goal, success criteria, CICD-05 requirement mapping
- `.planning/REQUIREMENTS.md` — CICD-05 (Dependabot for Actions SHA pins); traceability table
- `.planning/PROJECT.md` §Key Decisions — "Scanning workflow is authored as `on: workflow_call`... invoked by a thin `pull_request` caller" (v2.0 roadmap decision, locks the two-file structure this phase builds)
- `.planning/STATE.md` §Blockers/Concerns — "No `.github/` directory exists yet" and fixture/gitignore concerns relevant to later phases (not this one, but context for why `.github/` is being created from scratch)

### Reference implementation (pattern to follow, not to copy wholesale)
- `repos/security-platform/cicd/.github/workflows/security.yml` — existing SHA-pin comment convention (`@<sha>  # vN`), SARIF/artifact upload step patterns Phase 15+ will reuse. Note: this file uses Renovate and hardcoded `pull_request`/`push` triggers — Phase 14 diverges by using Dependabot (per CICD-05) and `workflow_call`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `repos/security-platform/cicd/.github/workflows/security.yml`: SHA-pin comment style and upload-artifact/upload-sarif step shape can be copied verbatim in later phases (15/17), but is out of scope to reuse structurally here since it isn't `workflow_call`-based.

### Established Patterns
- SHA-pinning with trailing version comment is already the org convention — Phase 14 formalizes it into a Dependabot-tracked baseline.

### Integration Points
- No `.github/` directory exists in this repo yet — Phase 14 creates the tree from scratch (`.github/workflows/`, `.github/dependabot.yml`).

</code_context>

<specifics>
## Specific Ideas

No specific UI/behavior requirements — this is a CI wiring phase. Decisions above (D-01 through D-04) are the specific choices.

</specifics>

<deferred>
## Deferred Ideas

- Push-to-main trigger on the caller workflow — deferred, can be added later if needed (see D-04).
- Additional Dependabot ecosystems (npm, pip, terraform) — deferred until those dependency types actually appear in this repo's tree (see D-03).
- Real scan jobs (SAST, IaC, SCA, container, secrets) — explicitly Phase 15's scope, not touched here.

None — discussion stayed within phase scope otherwise.

</deferred>

---

*Phase: 14-Workflow Foundation and Action Pinning*
*Context gathered: 2026-09-10*
