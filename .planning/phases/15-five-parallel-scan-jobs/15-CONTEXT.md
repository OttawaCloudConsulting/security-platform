# Phase 15: Five Parallel Scan Jobs - Context

**Gathered:** 2026-09-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the `placeholder` job in `repos/security-platform/.github/workflows/security.yml` with five real, parallel scan jobs — SAST (Semgrep), IaC (Checkov), SCA (generic Trivy filesystem sweep), container (Trivy image scan), secrets (Gitleaks) — each writing SARIF/JSON output to the runner, none blocking the merge (report-only). Gate-mode configurability, SARIF upload to GitHub, and per-ecosystem SCA coverage (npm/Python/Terraform) are later phases (17, 18, 16) — this phase only proves five tools run concurrently against real files and produce real, non-blocking results.

</domain>

<decisions>
## Implementation Decisions

### Fixture strategy
- **D-01:** New top-level `fixtures/` directory, NOT gitignored (distinct from the gitignored `repos/` tree), containing a minimal Dockerfile, `package-lock.json`, and `.tf` file so IaC/container/SCA jobs have real files in the checkout.
- **D-02:** Fixture content is deliberately vulnerable, not just structurally valid — an old/vulnerable npm dependency pin, an unpinned/old Terraform provider version, and a Dockerfile `FROM` an old base image with known CVEs. Guarantees each tool finds a real, reportable result (Phase 15 Success Criteria #2).
- **D-03:** This repo's own Gitleaks pre-push and npm-audit pre-commit hooks will reject this content by default — scope a `.gitleaksignore` entry / hook `exclude:` pattern to the `fixtures/` path specifically (not a blanket bypass) so the repo's own protection stays intact elsewhere.

### Report-only conversion
- **D-04:** Each scan job keeps the tool's native fail/exit-code behavior (Semgrep `--error`, Checkov `soft_fail: false`, Grype/Trivy `--fail-on`/`exit-code`), but the step invoking the tool is marked `continue-on-error: true`. The step (and job) shows the finding in logs but the overall PR check still passes. Do not flip tool flags to soft-fail/non-blocking natively — keep native severity semantics intact for when gate mode (Phase 18) turns blocking back on.

### SCA tool choice
- **D-05:** SCA-04's "generic Trivy/Grype filesystem scan" is satisfied with Trivy only: `trivy fs .`. Single tool, single SARIF+JSON output for the generic sweep. Grype is not used in this phase — reserved as a future option, not run redundantly alongside Trivy.

### Container job trigger
- **D-06:** No conditional "check for Dockerfile, skip if absent" logic. The container job always builds and scans `fixtures/Dockerfile` (see D-01/D-02 — deliberately old base image with known CVEs). Satisfies Success Criteria #2 (real result, not skipped/stubbed) unconditionally, with no branch logic to get wrong.

### Claude's Discretion
- Exact fixture file contents (which specific old npm package/version, which Terraform provider/version, which Docker base image tag) — pick something clearly vulnerable and well-documented (e.g. an old `lodash`/`handlebars` version, an old `alpine`/`node` tag) during planning/research.
- Exact `.gitleaksignore` / pre-commit `exclude:` regex syntax for scoping the fixtures exemption.
- Job/step naming and ordering within `security.yml` beyond what's already implied by the reference workflow.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap and requirements
- `.planning/ROADMAP.md` §Phase 15 — goal, 5 success criteria, CICD-01/SCA-04 requirement mapping
- `.planning/REQUIREMENTS.md` — CICD-01 (5 parallel scan jobs on PR), SCA-04 (generic Trivy/Grype filesystem scan)
- `.planning/STATE.md` §Blockers/Concerns — "Scan fixtures are needed from Phase 15, not just Phase 19" and "This repo's own hooks will block committing those fixtures" — the exact concern D-01/D-02/D-03 resolve
- `.planning/phases/14-workflow-foundation-and-action-pinning/14-CONTEXT.md` — D-01 there: the callable workflow's placeholder job is `actions/checkout` only, explicitly deferring the 5 real jobs to this phase

### Reference implementation (pattern to follow, adapt to workflow_call + report-only)
- `repos/security-platform/cicd/.github/workflows/security.yml` — existing 5-job implementation (SAST/Semgrep, IaC/Checkov, SCA/Grype, container/Trivy, secrets/Gitleaks) with SHA-pin comment convention and SARIF/artifact upload step shapes. This is the direct content source for the 5 jobs — currently blocking (`soft_fail: false`, `exit-code: 1`, `fail-on high`) and uses `pull_request`/`push` triggers + Renovate; Phase 15 adapts it into the `workflow_call`-based `security.yml`, converts to report-only per D-04, and swaps Grype→Trivy for the SCA job per D-05.
- `repos/security-platform/.github/workflows/security.yml` — current state: `workflow_call` skeleton with single `placeholder` job (`actions/checkout` pinned) from Phase 14. This is the file to modify — replace `placeholder` with the 5 real jobs.
- `repos/security-platform/.github/workflows/pr-security.yml` — thin `pull_request` caller from Phase 14, unchanged this phase.
- `docs/development-security-stack-option-1.md` — ~2,300-line reference blueprint with tool configs and copy-pasteable configurations for the full stack.
- `docs/adr/` (ADR-001 through ADR-014, esp. ADR-004 referenced in security.yml header re: SHA pinning) — architectural decisions this phase must stay consistent with.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `repos/security-platform/cicd/.github/workflows/security.yml`: all 5 job definitions (steps, actions, SHA pins) can be adapted almost verbatim — main changes are trigger removal (workflow_call takes no `on:`), report-only conversion (D-04), and SCA tool swap (D-05).

### Established Patterns
- SHA-pin with trailing version comment (`uses: <action>@<sha>  # vN`) — established in Phase 14, reused here for every new `uses:` line.
- SARIF upload via `github/codeql-action/upload-sarif`, JSON via `actions/upload-artifact`, both `continue-on-error: true` already in the reference — extend this same `continue-on-error` pattern to the scan step itself per D-04.

### Integration Points
- `repos/` is gitignored (`.gitignore:1`) — confirmed empty of Dockerfiles/lockfiles/.tf files in a CI checkout. `fixtures/` (D-01) must NOT be gitignored, and lives outside `repos/`.
- Existing pre-commit/pre-push hooks (Gitleaks, npm-audit) from v1.0/v1.1 will intercept fixture commits — D-03 scopes the exemption.

</code_context>

<specifics>
## Specific Ideas

No additional specific UI/behavior requirements beyond D-01 through D-06 above — this is a CI wiring phase, decisions are the specifics.

</specifics>

<deferred>
## Deferred Ideas

- Per-ecosystem SCA coverage (npm-audit, pip-audit, Terraform pin checks) — explicitly Phase 16 (SCA-01/02/03).
- SARIF upload to GitHub Security tab and JSON artifact retention with explicit retention periods — explicitly Phase 17 (CICD-02/03). Phase 15 jobs still write the files, per Success Criteria #4, but upload/retention polish is deferred.
- Configurable gate mode (block vs report-only via flag/input) and branch protection guidance — explicitly Phase 18 (CICD-06/CICD-04). Phase 15 hardcodes report-only via D-04; making it a flag is Phase 18's job.
- Grype as a second SCA tool alongside Trivy — deferred, not ruled out, per D-05.

None else — discussion stayed within phase scope.

</deferred>

---

*Phase: 15-Five Parallel Scan Jobs*
*Context gathered: 2026-09-10*
