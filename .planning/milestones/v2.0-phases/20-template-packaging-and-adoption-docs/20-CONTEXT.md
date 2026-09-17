# Phase 20: Template Packaging and Adoption Docs - Context

**Gathered:** 2026-09-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Package the already-built, already-validated (Phase 19) CI/CD security scanning pipeline for reuse by other
repos in the org. Two consumption modes: (1) a copy-paste workflow template with every per-repo substitution
clearly marked, and (2) a reusable workflow other repos call via
`uses: OCC-github/security_solution/.github/workflows/<name>.yml@<ref>`. Plus adoption docs covering both
modes end to end. This phase does NOT modify the pipeline's scanning behavior — it packages and documents
what Phases 14-19 already built and validated live against `OttawaCloudConsulting/security-platform`.

</domain>

<decisions>
## Implementation Decisions

### Reusable workflow location
- **D-01 (AMENDED 2026-09-14, post-RESEARCH.md Q1):** `OCC-github/security_solution` does not exist —
  `OCC-github` is not a real org (404), the real account is `OttawaCloudConsulting` (a User, not an Org),
  and this documentation repo's own git history is disjoint from any GitHub remote. `security-platform`
  is already public, already hosts the Phase 14-19 validated `security.yml`/`pr-security.yml`, and has no
  leaked-secret history to scrub (this repo's gitleaks scan found 16 findings across 320 commits — a real
  blocker to making *this* repo public). **Decision: `security-platform` is the canonical host repo.**
  `security-platform`'s existing `.github/workflows/security.yml` and `pr-security.yml` ARE the canonical
  files — no copy into `security_solution` is needed. DIST-07's `uses:` reference becomes
  `uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@<ref>`. This repo
  (`security_solution`) keeps only documentation (`docs/adoption-guide.md`) and the copy-paste template
  (referencing/embedding the same canonical YAML, kept in sync manually) — it does not host a second copy
  as source of truth. Update all D-02 tagging, the adoption doc's `uses:` examples, and any ADR text
  accordingly.

### Versioning / ref strategy
- **D-02:** Consumer repos pin to tagged releases (`@v1`, `@v2`, ...), not `@main` and not a raw SHA. Matches
  this project's existing pin-with-version-comment convention (Phase 14) applied at the repo-release level
  instead of the individual-action level. Planner/executor must establish a tagging/release mechanism
  (e.g. `git tag v1` on the commit that ships the reusable workflow) as part of this phase.

### Docs location
- **D-03:** Adoption docs go in a **new standalone file under `docs/`** (e.g. `docs/adoption-guide.md`),
  not appended to the already ~2,300-line `development-security-stack-option-1.md`. Keeps the main reference
  blueprint from growing further and gives other repos' maintainers a single focused doc to follow.

### Per-repo substitutions (copy-paste template)
- **D-04:** `gate_mode` (Phase 18's flag/var) is the ONLY per-repo substitution point. No other placeholders
  needed — the five scan jobs auto-detect what's in the repo (npm/pip/terraform/Dockerfile paths), and branch
  names are not hardcoded anywhere that needs per-repo substitution. SC4's "docs state which scan jobs apply
  to which repo types and how to disable the ones that do not apply" is a **documentation** concern (guidance
  on removing/commenting out job blocks for repo types that don't need them, e.g. a pure-frontend repo skipping
  Checkov/IaC) — not a templated substitution mechanism. Do not over-engineer a config-driven job-selection system.

### Claude's Discretion
- Exact mechanism for keeping `security-platform`'s workflow files in sync with the new `security_solution`
  canonical copies (manual copy, symlink note in docs, or `security-platform` switching to `uses:` its own
  org's new reusable workflow) — pick whatever is simplest and most maintainable; document the choice.
- Exact release/tagging automation (manual `git tag` + `gh release create`, or a lightweight GitHub Actions
  release workflow) — pick whatever fits the project's zero-cost, low-ceremony philosophy (see PROJECT.md
  "zero-cost, open-source... no external accounts").
- Adoption doc's internal structure (single doc vs a doc + quick-reference table) — pick whatever best serves
  SC3's "walk through both consumption modes end to end, covering gate-mode selection, branch protection
  setup, and Dependabot wiring."

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap and requirements
- `.planning/ROADMAP.md` §Phase 20 — goal, 4 success criteria, DIST-06/07/08 requirement mapping
- `.planning/REQUIREMENTS.md` — DIST-06 (copy-paste template), DIST-07 (reusable workflow via `uses:`),
  DIST-08 (adoption docs for both modes)

### Reference implementation (files to package/reference)
- `repos/security-platform/.github/workflows/security.yml` — the callable workflow with `gate_mode` input
  (Phase 18), five scan jobs, SARIF upload (Phase 17) — the source of truth to copy/adapt into
  `security_solution/.github/workflows/`
- `repos/security-platform/.github/workflows/pr-security.yml` — the `pull_request` caller; job named
  `security` is FROZEN (branch-protection required-check list depends on this exact name — see Phase 18
  D-06/D-07 below)
- `repos/security-platform/.github/dependabot.yml` — existing Dependabot config for Actions SHA-pin updates,
  reference for SC3's "Dependabot wiring" doc section

### Prior phase decisions this phase must stay consistent with
- `.planning/phases/18-configurable-gate-mode-and-branch-protection/18-CONTEXT.md` — D-01 through D-07:
  `gate_mode` is a single global flag (`"blocking"` | `"report-only"`), defaults to `report-only`, required-checks
  cover six frozen check-run names, and D-07's explicit adoption sequencing (checks appear green in report-only
  → THEN set blocking → THEN add as required in branch protection) — this sequencing is exactly what SC3's
  adoption docs must document
- `.planning/phases/18-configurable-gate-mode-and-branch-protection/18-CONTEXT.md` note (line 89): "Full
  template-packaging and copy-paste rollout guidance for other repos — explicitly Phase 20's job" — confirms
  this phase's scope boundary
- `.planning/phases/17-sarif-upload-and-artifact-retention/17-07-SUMMARY.md` — the twelve byte-exact check-run
  names (six job-level + six code-scanning-per-driver), frozen naming this phase's docs must reference correctly
- `.planning/phases/19-pipeline-validation-via-branch-target-prs/19-01-SUMMARY.md` through
  `19-07-SUMMARY.md` — live-measured evidence that the pipeline actually works end to end (SC1-SC4), useful
  as "proof it works" material for adoption docs, and the exact live repo (`OttawaCloudConsulting/security-platform`)
  where it was validated
- `.planning/phases/19-pipeline-validation-via-branch-target-prs/19-06-SUMMARY.md` — notes that `fixtures/`
  is permanent test content in `security-platform` specifically; adoption docs must NOT tell other repos to
  add anything resembling `fixtures/` — that was validation-only scaffolding local to `security-platform`

### Project structure / editing guidelines
- `./CLAUDE.md` — repository structure and editing guidelines (docs/adr/ append-only, preserve ASCII diagrams
  and 4-phase layered structure in the main blueprint doc)
- `docs/adr/README.md` — ADR index, if a new ADR is warranted for the packaging/versioning decisions above

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `repos/security-platform/.github/workflows/security.yml` and `pr-security.yml` are complete, validated,
  production-ready — Phase 20 packages/copies them, it does not rebuild scanning logic.
- SHA-pin-with-version-comment convention (`uses: <action>@<sha>  # vN`, established Phase 14) — preserve
  in any copied/adapted workflow files.

### Established Patterns
- `continue-on-error: true # D-04` on each scan step, conditioned on `gate_mode` (Phase 18) — this is the
  full blocking/report-only mechanism; nothing new needed here.
- `security` job name in `pr-security.yml` is FROZEN — required-check branch protection depends on it;
  adoption docs must instruct consumers not to rename it if they want required checks to keep working.

### Integration Points
- `security.yml`'s `workflow_call: {gate_mode: ...}` input is the reusable-workflow-mode wiring point —
  DIST-07's `uses:` consumers pass `gate_mode` here.
- Copy-paste mode: consumers copy both files wholesale into their own `.github/workflows/`, set
  `vars.gate_mode` (or leave unset for the `report-only` default per Phase 18 D-03).

</code_context>

<specifics>
## Specific Ideas

No specific UI/output format requirements beyond what's captured in Decisions above. The adoption doc should
be concrete and copy-paste-able (real YAML snippets, real `gh` commands for branch protection setup), matching
the project's existing "copy-pasteable configs" style (per CLAUDE.md's description of the main blueprint doc).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Note: several small tooling/doc-accuracy items were deferred
from Phase 19 to "Phase 20" in its deferred-items.md — D-19-B through D-19-E — but on inspection these are
GSD-tooling quirks (stale gsd-sdk positional-arg docs, a no-op pre-push Gitleaks hook config, a STATE.md
percent-field cosmetic mismatch), not Template Packaging / Adoption Docs domain items. They don't belong in
this phase's scope; flagging here so they aren't silently lost, but not folding them in.)

</deferred>

---

*Phase: 20-template-packaging-and-adoption-docs*
*Context gathered: 2026-09-14*
