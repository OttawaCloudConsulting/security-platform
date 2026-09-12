# Phase 19: Pipeline Validation via Branch-Target PRs - Context

**Gathered:** 2026-09-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove the complete `security.yml`/`pr-security.yml` pipeline end-to-end inside `repos/security-platform`, using deliberately seeded findings on branch-target pull requests — no second repo required. This phase does not change scan-job logic, gate-mode wiring, or branch-protection config (all Phase 18); it seeds the two fixture categories still missing (SAST, Secrets), runs and observes real PRs under both gate modes, traces one finding end-to-end, and confirms a clean PR stays green.

</domain>

<decisions>
## Implementation Decisions

### Fixture completion (SAST + Secrets)
- **D-01:** Add `fixtures/vulnerable.py` seeding a Semgrep CE `p/default`-flaggable pattern using `eval()`/`os.system()` on unsanitized input — matches the Python ecosystem already present via `fixtures/requirements.txt`.
- **D-02:** Add a new fixture file (e.g. `fixtures/secret.env`) containing a fake AWS access key ID + secret matching Gitleaks' built-in `aws-access-token` rule — a named, deterministic rule rather than a generic entropy match. Not a real credential.
- **D-03:** Both new fixtures follow the existing "INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT FIX" header convention (see `fixtures/main.tf`, `fixtures/Dockerfile`, `fixtures/requirements.txt`).
- **D-04:** After validation, both new fixtures join the permanent `fixtures/` set alongside the existing IaC/Container/SCA fixtures — not reverted. `fixtures/README.md`'s structure table and Fixture Reference table are updated to include them (new rows/columns for SAST and Secrets, consuming job, measured finding count).

### Validation PR lifecycle
- **D-05:** One long-lived branch-target validation PR carries all five seeded findings (the three existing fixtures + the two new ones from D-01/D-02) and stays open through the phase:
  1. Opened while `GATE_MODE` is `report-only` — observed producing a detection from each of the five jobs (SC1) and used as the SC3 trace source.
  2. `GATE_MODE` repo variable flipped to `blocking`; the SAME PR re-run (re-trigger, not a new PR) — observed failing its checks (SC2, first half).
  3. `GATE_MODE` flipped back to `report-only`; the SAME PR re-run again — observed passing (SC2, second half, and consistent with D-08 below).
- **D-06:** A second, separate PR with no seeded findings (clean branch, no fixture changes) proves SC4 — all five jobs green.
- **D-07:** Both PRs target `repos/security-platform`'s `main` via GitHub (real PRs, real Actions runs) — "witnessed, not inferred" per SC2 means actual run URLs/check results captured, not simulated.

### Trace target (SC3)
- **D-08:** The single finding traced end-to-end (source file → Security tab entry → retained JSON artifact) is the newly-seeded SAST finding from `fixtures/vulnerable.py` (D-01) — exercises the new fixture and closes the gap that Phase 17 never traced a SAST finding through to the Security tab.

### End state
- **D-09:** After the blocking-mode observation (D-05 step 2) is captured, `GATE_MODE` is reverted to `report-only` before the phase closes. This matches Phase 18 D-07's rollout sequencing: branch-protection required-checks were never set up as part of Phase 18/19, so leaving the repo in `blocking` would gate merges without the required-checks safety net that sequencing calls for. Phase 19 proves blocking works; it does not adopt it live.
- **D-10:** The validation PR itself (D-05) is closed/merged (not left open indefinitely) once all four success criteria are captured — exact merge-vs-close choice left to Claude's discretion at execution time, noted below.

### Claude's Discretion
- Whether the validation PR (D-05) is ultimately merged into `main` or closed without merging once observations are captured — either is fine since the new fixtures (D-04) must land on `main` regardless (via this PR or a follow-up), but the mechanics of GitHub PR re-triggering (re-push vs "Re-run all jobs" vs empty commit) are left to the executor.
- Exact wording/format of the `fixtures/README.md` updates for the two new fixture rows (D-04) — follow the existing table conventions in that file.
- How "witnessed, not inferred" (SC2) is captured as evidence for the phase's SUMMARY/VERIFICATION docs (e.g., pasted run URLs, `gh run view` output, screenshots) — pick whatever is most verifiable and lightweight.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap and requirements
- `.planning/ROADMAP.md` §Phase 19 — goal, 4 success criteria, VAL-01 requirement mapping
- `.planning/REQUIREMENTS.md` — VAL-01: "Full pipeline validated in this repo using branch-target PRs (no second repo required to prove it out)"

### Prior phase context (gate mode, fixtures, SARIF)
- `.planning/phases/18-configurable-gate-mode-and-branch-protection/18-CONTEXT.md` — D-01 through D-07: `GATE_MODE` is a single global string enum (`blocking`/`report-only`), default `report-only` (D-03), fails on ANY finding when blocking (D-04), and D-07's rollout sequencing (report-only confirmation BEFORE flipping to blocking BEFORE requiring checks) — Phase 19 executes steps 1–2 of that sequence and explicitly does NOT do step 3
- `.planning/phases/15-five-parallel-scan-jobs/15-CONTEXT.md` — origin of the `continue-on-error` per-scan-step pattern D-04 (Phase 18) conditions on
- `repos/security-platform/fixtures/README.md` — existing fixture conventions (header comment style, "DO NOT FIX" language, pre-commit exclusions, Fixture Reference table format) that D-01–D-04 must match exactly
- `repos/security-platform/docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md` (if present under `docs/adr/`) — SARIF category/check-run naming this phase's trace (D-08) must follow

### Files to read before planning (reference implementation)
- `repos/security-platform/.github/workflows/security.yml` — `GATE_MODE` env resolution (`inputs.gate_mode || vars.GATE_MODE || 'report-only'`), the `Validate gate_mode` step, and each job's `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}` lines
- `repos/security-platform/.github/workflows/pr-security.yml` — FROZEN `security` job name (check-run prefix for all required checks), `on: pull_request: {}` trigger (all branches)
- `repos/security-platform/fixtures/main.tf`, `fixtures/Dockerfile`, `fixtures/package.json`, `fixtures/requirements.txt` — existing fixture pattern D-01/D-02's new files must match
- `repos/security-platform/.gitleaksignore` — confirm the new AWS-key fixture (D-02) is NOT accidentally excluded here

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `fixtures/README.md`'s Fixture Reference table (file / consuming job / measured finding count) is the exact format to extend for the two new fixtures (D-04).
- `scripts/smoke-scans.sh` and `scripts/check-workflow-uploads.sh` (repo-local) already exercise these fixtures locally — check whether they need the two new fixture files added to their scan targets.

### Established Patterns
- Every fixture file opens with an `# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"` (or `DO NOT FIX OR INSTALL`) header comment, plus inline comments explaining exactly which rule/check the content trips and why (see `main.tf`'s per-block annotations). D-01/D-02 fixtures must follow this.
- `fixtures/` is excluded from 4 pre-commit hooks (`terraform_fmt`, `terraform_validate`, `hadolint`, `npm-audit`) but NOT from Gitleaks — the new secret fixture (D-02) will hit the repo's own pre-commit Gitleaks hook on commit, same as any other push; this is expected, not a bug, and the executor should not add fixtures/ to the Gitleaks exclusion.

### Integration Points
- `GATE_MODE` is read from the `repos/security-platform` repo's `vars.GATE_MODE` Actions variable (not a file) — flipping it (D-05 step 2) is a GitHub repo-settings/API action, not a code change.
- The validation PR (D-05) is a real PR against `OttawaCloudConsulting/security-platform` on GitHub — same mechanism used for Phases 14–18 (see `gh pr list` history), not a local-only simulation.

</code_context>

<specifics>
## Specific Ideas

- SAST fixture: Python, using `eval()` or `os.system()` on unsanitized input — chosen over a JS/Node pattern to match the existing Python SCA fixture's ecosystem.
- Secrets fixture: a fake AWS access key ID/secret pair, chosen over a generic high-entropy string for deterministic, version-stable Gitleaks detection.

</specifics>

<deferred>
## Deferred Ideas

- Branch-protection required-checks adoption (Phase 18 D-07 step 3) — explicitly deferred past this phase; Phase 19 ends with `GATE_MODE` back at `report-only` (D-09).
- Any changes to scan-job logic, SARIF categorization, or gate-mode wiring itself — all Phase 18/17/15 territory, out of scope here.
- Template packaging / other-repo rollout — Phase 20's job.

None else — discussion stayed within phase scope.

</deferred>

---

*Phase: 19-Pipeline Validation via Branch-Target PRs*
*Context gathered: 2026-09-12*
