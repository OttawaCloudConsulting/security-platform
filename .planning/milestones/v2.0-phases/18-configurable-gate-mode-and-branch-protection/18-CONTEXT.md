# Phase 18: Configurable Gate Mode and Branch Protection - Context

**Gathered:** 2026-09-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the existing five report-only scan jobs (`security.yml`) toggle between blocking and report-only per consuming repo, without editing workflow YAML — via one flag readable in both consumption modes (`workflow_call` input; repo-level `vars.*`/env for copy-paste). Also write branch-protection configuration/guidance for promoting the six job-level checks to required checks once a repo goes blocking. Severity-level gating, code-scanning-check requirement, and per-job flags are explicitly out of scope (see decisions below).

</domain>

<decisions>
## Implementation Decisions

### Flag shape
- **D-01:** Single global flag, `gate_mode`, controls all five scan jobs uniformly (sast, iac, sca, container, secrets) — not per-job flags. Matches roadmap wording ("the gate flag").
- **D-02:** `gate_mode` is a string enum: `"blocking"` | `"report-only"` — not a boolean. Reads naturally as a `workflow_call` input and self-documents as a repo-level `vars.gate_mode` value (repo vars are strings anyway); leaves room for a future third mode without a type change.
- **D-03:** Default when unset (no input passed, no repo variable set) is `"report-only"` — matches current Phase 15–17 behavior. A repo adopting this workflow for the first time is never silently broken by an un-set flag.

### Severity semantics
- **D-04:** `gate_mode: blocking` fails a job on ANY finding — severity-agnostic. This is achieved by flipping `continue-on-error: false` on the scan steps that today carry D-04 (Phase 15)'s `continue-on-error: true`; each tool's already-strict native exit-code behavior (Semgrep `--error`, Checkov `soft_fail: false`, Trivy/Grype `--fail-on`/exit-code, tflint exit 2 on findings) decides pass/fail. No separate severity-cutoff input. This is required for uniformity: pip-audit's JSON has no severity field to threshold on (confirmed Phase 17), so a severity-cutoff flag could not apply consistently across all five jobs.
- **D-05:** Branch-protection guidance's "which severity threshold triggers a failure" (Success Criteria #4) is answered as "any finding, per each tool's existing native detection configuration" — not a new configurable severity knob.

### Branch protection scope
- **D-06:** Required-checks guidance covers the six job-level checks only — `security / SAST — Semgrep CE`, `security / IaC — Checkov`, `security / SCA — Trivy Filesystem`, `security / Container — Trivy Image`, `security / Secrets — Gitleaks`, and the `security` wrapper job in `pr-security.yml` (exact names frozen per 17-07-SUMMARY.md's "twelve byte-exact check-run names" — the six job-level ones, not the six code-scanning-per-driver ones). Code-scanning-per-driver checks are informational (SARIF/Security-tab) only; Phase 17 left the Security tab's UI visibility unconfirmed, so requiring those checks is deferred.

### Rollout safety
- **D-07:** The written guidance sequences adoption explicitly: (1) confirm job-level checks appear (green when clean, red when seeded) in PR runs while still in report-only, (2) THEN set `gate_mode: blocking`, (3) THEN add the job-level checks as required in branch protection settings. State plainly that doing step 3 before step 2 leaves merges un-gated even though the workflow is configured to block.

### Claude's Discretion
- Exact GitHub Actions expression syntax for conditionally setting `continue-on-error` per scan step based on `gate_mode` (e.g. `${{ inputs.gate_mode == 'report-only' }}` vs a computed job output) — pick whatever composes cleanly with the existing `continue-on-error: true # D-04` lines across all five jobs' scan steps.
- How the copy-paste consumption mode reads `gate_mode` from a repo variable/env (`vars.gate_mode` vs `env:` block) — pick whichever is simpler to document consistently with existing copy-paste guidance (Phase 20 is the full template-packaging phase; Phase 18 just needs the flag wired and documented for this repo).
- Exact wording/location of the new branch-protection doc (new file under `docs/`, an ADR, or a section appended to `development-security-stack-option-1.md`) — pick whatever fits the existing doc structure per CLAUDE.md's editing guidelines.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap and requirements
- `.planning/ROADMAP.md` §Phase 18 — goal, 4 success criteria, CICD-04/CICD-06 requirement mapping
- `.planning/REQUIREMENTS.md` — CICD-04 (branch protection config/guidance so scan checks can be made required), CICD-06 (gate mode configurable per consuming repo via flag/input, not hardcoded)
- `.planning/STATE.md` §Operator Next Steps — "Phase 18 inherits the frozen check-run name `security / SCA — Trivy Filesystem` (em dash U+2014, re-read from `origin/main`) and must express any gate per tool — tflint signals findings with exit 2, the others with exit 1, and pip-audit has no severity field to threshold on" — the exact constraint D-04 resolves

### Prior phase context
- `.planning/phases/15-five-parallel-scan-jobs/15-CONTEXT.md` D-04 — established the `continue-on-error: true` per-scan-step pattern this phase flips conditionally; explicitly named gate mode as "Phase 18's job"
- `.planning/phases/17-sarif-upload-and-artifact-retention/17-07-SUMMARY.md` — "the twelve byte-exact check-run names", the empty required-check list Phase 18 is "free to populate deliberately", the red Checkov check that merges without blocking today, and the unresolved Security-tab UI visibility question that informs D-06

### Reference implementation (files to modify)
- `repos/security-platform/.github/workflows/security.yml` — the callable workflow; every scan job's `continue-on-error: true # D-04` line on the tool-invocation step is the flip point for `gate_mode`
- `repos/security-platform/.github/workflows/pr-security.yml` — the `pull_request` caller; job named `security` is FROZEN (comment: "Phase 18 hard-codes it into the branch-protection required-check list. Renaming this job would leave branch protection pointing at a check that no longer exists.") — this is where a `workflow_call` input would need to be threaded through if using that mechanism
- `docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md` — SARIF/check-run naming decisions this phase must stay consistent with
- `docs/development-security-stack-option-1.md` — ~2,300-line reference blueprint; branch-protection guidance likely belongs here or as a new file per CLAUDE.md structure

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Every one of the five scan jobs already has a `continue-on-error: true # D-04` comment on its tool-invocation step(s) — these are the exact lines the gate flag needs to condition on. SCA job has four such steps (Trivy fs, npm audit, pip-audit, tflint) sharing one job-level check name.

### Established Patterns
- SHA-pin with trailing version comment (`uses: <action>@<sha>  # vN`) — established Phase 14, must be preserved on any new actions this phase adds (e.g. branch-protection automation, if any).
- `continue-on-error: true` is the sole mechanism separating report-only from blocking today (D-04, Phase 15) — Phase 18 makes this conditional rather than introducing a new mechanism.

### Integration Points
- `pr-security.yml`'s `security` job name is the check-run prefix for all six required checks — frozen, do not rename.
- `security.yml` currently takes `workflow_call: {}` with no inputs — adding `gate_mode` as an input here is the reusable-workflow-mode wiring point.

</code_context>

<specifics>
## Specific Ideas

No additional specific UI/behavior requirements beyond D-01 through D-07 above — this is a CI wiring and documentation phase, decisions are the specifics.

</specifics>

<deferred>
## Deferred Ideas

- Severity-cutoff gating (e.g. `gate_mode=blocking` + a severity floor) — deferred, not ruled out, per D-04/D-05. Would require inconsistent per-tool wiring since pip-audit has no severity field.
- Requiring the six code-scanning-per-driver checks (in addition to the six job-level checks) — deferred per D-06 until Phase 17's open Security-tab UI visibility question is resolved.
- Per-job gate flags (independent blocking/report-only per scan job) — deferred per D-01; roadmap and success criteria describe one flag.
- Full template-packaging and copy-paste rollout guidance for other repos — explicitly Phase 20's job; Phase 18 only needs `gate_mode` wired and documented for this repo's two consumption mechanisms.

None else — discussion stayed within phase scope.

</deferred>

---

*Phase: 18-Configurable Gate Mode and Branch Protection*
*Context gathered: 2026-09-11*
