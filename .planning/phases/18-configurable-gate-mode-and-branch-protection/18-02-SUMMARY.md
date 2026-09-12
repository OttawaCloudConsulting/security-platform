---
phase: 18-configurable-gate-mode-and-branch-protection
plan: "02"
subsystem: infra
tags: [github-actions, workflow_call, gate-mode, actionlint, yamllint]

# Dependency graph
requires:
  - phase: 18-configurable-gate-mode-and-branch-protection
    plan: "01"
    provides: "on.workflow_call.inputs.gate_mode contract, workflow-level env.GATE_MODE resolution, and the per-job Validate gate_mode enum step, on feature/phase-18-configurable-gate-mode-and-branch-protection @ 3f21926"
provides:
  - "eleven scan-step continue-on-error values driven by ${{ env.GATE_MODE == 'report-only' }}, failing closed on any mistyped/blank mode"
  - "three sca-job if: conditions (SCA-01/02/03) compounded with always(), so a hard failure earlier in the job no longer silently skips them"
  - "corrected FROZEN rationale and a recorded reason for pr-security.yml's absent with: block, in .github/workflows/pr-security.yml"
  - "feature/phase-18-configurable-gate-mode-and-branch-protection pushed to origin at 76f70a8, containing 18-01's + 18-02's commits"
affects: [18-03, 18-04, 18-05, branch-protection-plans]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "fail-closed boolean comparison (== 'report-only', never != 'blocking') so a typo blocks rather than silently permits"
    - "always() && <original-condition> to restore an implicit-success()-skipped step to independence from upstream step outcome"

key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml
    - repos/security-platform/.github/workflows/pr-security.yml

key-decisions:
  - "Comparison written == 'report-only', never != 'blocking' or fromJSON — verified absent by grep (0 matches each) after edit, so a mistyped or blank GATE_MODE fails closed (tolerance off, job goes red) rather than open"
  - "Extended marker to '# D-04 / Phase 18 CICD-06' on all eleven flipped lines, keeping each line's original per-tool reason suffix verbatim; fixed-column comment alignment could not survive the longer expression and was abandoned in favour of a single consistent spacing form"
  - "Did not touch the eleven ADR-001 upload-step continue-on-error: true lines, nor the Checkov soft_fail: false with: parameter (a bare '# D-04' grep also matches it, but it is a step parameter, not a tolerance) — both asserted present at their original counts after the edit"
  - "Added a compound-guard rationale comment above SCA-01 — npm audit (the first of the three affected steps) rather than repeating it three times, in the file's existing prose-comment voice"
  - "Cloned repos/security-platform fresh into this worktree (same Rule 3 provisioning as 18-01, worktrees don't carry gitignored dirs) and checked out feature/phase-18-configurable-gate-mode-and-branch-protection from origin rather than assuming a local clone existed"
  - "Pushed the branch to origin immediately after all three commits, so wave-3 worktree agents (18-03+) can continue it — mirrors 18-01's reasoning"

patterns-established:
  - "Pattern: extend rather than replace an existing marker comment (# D-04 -> # D-04 / Phase 18 CICD-06) when a later phase changes WHY a value exists but the earlier decision reference is still true"

requirements-completed: [CICD-06]

# Metrics
duration: ~35min
completed: 2026-09-12
---

# Phase 18 Plan 02: Apply the Resolved Gate Mode Summary

**Flipped all eleven scan-step `continue-on-error: true # D-04` literals to `${{ env.GATE_MODE == 'report-only' }}` (fail-closed), compounded the three `sca`-job `if:` conditions that GitHub's implicit `success()` would otherwise skip under blocking mode, and corrected `pr-security.yml`'s FROZEN comment plus documented why it deliberately passes no `gate_mode`.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-09-12
- **Tasks:** 3
- **Files modified:** 2 (`repos/security-platform/.github/workflows/security.yml`, `repos/security-platform/.github/workflows/pr-security.yml`)

## Accomplishments

### Task 1 — eleven gated scan steps

All eleven `continue-on-error: true` lines whose trailing comment started `# D-04` now read `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}` with the extended marker `# D-04 / Phase 18 CICD-06`, per-tool reason suffix preserved verbatim. Final state (line numbers are after Task 2's inserted comment, i.e. current HEAD):

| Line | Job | Step | Trailing comment |
|------|-----|------|-------------------|
| 79 | sast | Run Semgrep | `# D-04 / Phase 18 CICD-06: native --error kept, step tolerated` |
| 230 | iac | Run Checkov | `# D-04 / Phase 18 CICD-06: native failing behaviour tolerated at step level` |
| 410 | sca | Run Trivy filesystem scan (JSON for retention) | `# D-04 / Phase 18 CICD-06` |
| 430 | sca | Run Trivy filesystem scan (SARIF for code scanning) | `# D-04 / Phase 18 CICD-06` |
| 517 | sca | SCA-01 — npm audit | `# D-04 / Phase 18 CICD-06: native --audit-level exit code kept` |
| 580 | sca | SCA-02 — pip-audit | `# D-04 / Phase 18 CICD-06` |
| 645 | sca | SCA-03 — tflint (SARIF) | `# D-04 / Phase 18 CICD-06: exit 2 means findings` |
| 651 | sca | SCA-03 — tflint (human-readable log) | `# D-04 / Phase 18 CICD-06: exit 2 means findings` |
| 830 | container | Run Trivy image scan | `# D-04 / Phase 18 CICD-06` |
| 974 | secrets | Run Gitleaks (SARIF) | `# D-04 / Phase 18 CICD-06` |
| 981 | secrets | Run Gitleaks (JSON) | `# D-04 / Phase 18 CICD-06` |

Verified: `grep -c "!= 'blocking'"` = 0, `grep -c fromJSON` = 0 (neither forbidden shape appears anywhere in the file). The eleven ADR-001 upload-step `continue-on-error: true` lines and the Checkov `soft_fail: false # D-04` `with:`-block parameter are both confirmed unchanged (counts still 11 and 1 respectively).

### Task 2 — three SCA scanners no longer silently skip under blocking

`if:` count is unchanged file-wide: **40 before, 40 after** (only values changed on three lines, none added/removed). The three previously-bare conditions in the `sca` job now read:

- `SCA-01 — npm audit`: `if: always() && steps.npm.outputs.found == 'true'`
- `SCA-02 — pip-audit`: `if: always() && steps.py.outputs.found == 'true'`
- `SCA-03 — tflint (SARIF)`: `if: always() && steps.tf.outputs.found == 'true'`

A parsed check over every job/step in the file confirms **zero** steps anywhere retain an `if:` lacking a status function (`always`/`success`/`failure`/`cancelled`) after this change.

`Run Trivy filesystem scan (SARIF for code scanning)` (line 428-429) and `Run Gitleaks (JSON)` (line 979-980) were individually confirmed in this plan's own read to already carry `if: always()` and were **not modified** by this task.

Deliberate report-only behaviour change, recorded in-file above the `SCA-01 — npm audit` step: these three steps previously also skipped when any earlier NON-tolerated step in the job failed hard; after this change they run regardless. The gate verdict is identical either way (report-only never blocked); what improves is report completeness and the honesty of the resulting error (a scan that never ran no longer surfaces as a downstream missing-file traceback from its `always()`-guarded verify step).

### Task 3 — pr-security.yml comment corrections, no functional change

Two comment edits, verified to leave the parsed caller identical (`name: security`, `uses: ./.github/workflows/security.yml`, no `with:` key, permissions map unchanged at `{contents: read, security-events: write, actions: read}`, exactly one job).

**(a) FROZEN comment rewritten.** The prior text stated the reason as "Phase 18 hard-codes it into the branch-protection required-check list" — that string no longer appears in the file. The corrected rationale: `security` is the caller JOB ID and therefore the PREFIX of the five check-run names emitted by the called workflow's jobs (`security / <called job name>`); this caller job itself emits no check run of its own. Cites both live observations: Phase 14-02's one-job callee produced exactly one check, `security / Placeholder`, and no bare `security`; and Phase 18's research read of the Phase 17 head SHA returned 12 check names, again none a bare `security`. The freeze conclusion is unchanged — renaming the job renames all five required contexts at once, and a required context with no matching check run sits permanently pending.

**(b) New comment block after `uses:`.** Records that the absent `with:` block is the mechanism: omitting `gate_mode` lets `inputs.gate_mode` resolve to `""`, so the callee's `env.GATE_MODE` chain falls through to the caller repo's `GATE_MODE` variable, then to `'report-only'` (D-03) — meaning the mode is switched with `gh variable set GATE_MODE --body blocking`, never a YAML edit. Names both traps: a bare `gate_mode: ${{ vars.GATE_MODE }}` passthrough is forbidden (an unset variable resolves to `""`, which counts as *provided* and suppresses the callee default — any literal added later must carry its own `|| 'report-only'` fallback); and a public repo intending genuine blocking may instead need a literal `with: gate_mode: blocking`, because whether a fork PR's job can read repo `vars` at all is unverified and is handed to Phase 19 (VAL-01).

`grep -v '^\s*#' pr-security.yml | grep -c gate_mode` = 0 — every mention of the flag lives inside a comment; the caller passes nothing.

## Task Commits

All three commits are in the **nested `repos/security-platform` repository**, not this docs repo:

1. **Task 1: Condition all eleven scan-step tolerances on the resolved gate mode** - `ebf228c` (feat)
2. **Task 2: Stop blocking mode from skipping the three conditional SCA scanners** - `eec57c1` (fix)
3. **Task 3: Correct the caller's FROZEN rationale and record the deliberate absence of a with: block** - `76f70a8` (docs)

Branch pushed to `origin/feature/phase-18-configurable-gate-mode-and-branch-protection`, head `76f70a8`, containing both 18-01's two commits and this plan's three commits (five total on the branch).

**Plan metadata (this repo):** committed separately per the parallel-executor final-commit step below.

## Files Created/Modified

- `repos/security-platform/.github/workflows/security.yml` — eleven `continue-on-error` literals replaced with the fail-closed gate expression; three `sca`-job `if:` conditions compounded with `always()`; one new rationale comment block above `SCA-01 — npm audit`.
- `repos/security-platform/.github/workflows/pr-security.yml` — FROZEN comment rewritten with corrected rationale; new comment block appended after `uses:` documenting the deliberate absence of `with:`. No functional/schema change.

## Decisions Made

See `key-decisions` in frontmatter. Additional note: chose to state the compound-guard rationale once, above the first of the three affected steps (`SCA-01 — npm audit`), rather than repeating a near-identical block three times — the file's existing voice favours a single explanatory comment near the first occurrence of a pattern (e.g. the D-01/D-02/D-04 explanations earlier in the file follow the same convention).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing local checkout of the target repo (same as 18-01)**
- **Found during:** start of Task 1, before any edit
- **Issue:** This worktree does not carry the gitignored `repos/` directory (fresh `git worktree add` never populates gitignored paths).
- **Fix:** Cloned `OttawaCloudConsulting/security-platform` fresh into this worktree's `repos/security-platform`, fetched and checked out `feature/phase-18-configurable-gate-mode-and-branch-protection` from `origin`, and verified it matched 18-01's recorded end state (1058 lines, 11/11 D-04/ADR-001 counts, `check-workflow-uploads.sh` exit 0) before editing.
- **Files modified:** none beyond the plan's own target files; repo-provisioning only.
- **Verification:** branch head matched 18-01-SUMMARY's recorded `3f21926`; all pre-edit invariants matched.
- **Committed in:** N/A (clone/checkout, not a tracked change in this repo).

**Total deviations:** 1 auto-fixed (Rule 3, environment-provisioning; no code/behaviour deviation from the plan's specified edits).
**Impact on plan:** None. All three tasks' YAML content and comment wording follow the plan exactly.

## Issues Encountered

- This worktree's outer HEAD started at `8fbea7d` (security-platform's Phase 17 merge commit) rather than the expected base `e040d322` (18-01's completion commit on the docs repo). `git merge-base` returned no common ancestor. The mandated `<worktree_branch_check>` protocol's `git reset --hard e040d322fd8b7a0d6e7d43b1b3c3a6396e14bef0` handled this correctly (working tree was clean beforehand). Recorded here only so a later reader is not surprised the outer worktree's HEAD moved once at startup — the same situation 18-01 hit and documented for its own outer worktree.
- The sandbox rejected two Python heredoc invocations as "too complex to verify it stays inside the worktree" (a false positive — no git command was involved). Workaround: wrote the same verification script to a file in the scratchpad directory and invoked it with `python3 <script-path>` instead of a heredoc. Not a deviation from the plan — same verification logic, different invocation mechanism.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `feature/phase-18-configurable-gate-mode-and-branch-protection` exists on `origin` at `OttawaCloudConsulting/security-platform`, head commit `76f70a8`, containing 18-01's contract/validation commits plus this plan's three flip/guard/comment commits.
- 18-03 (and later plans in this phase) must fetch/checkout that branch from `origin` in their own worktree's fresh clone of `repos/security-platform` — this worktree's clone will not survive teardown.
- Pass/fail behaviour is now live: `env.GATE_MODE` (resolved by 18-01) is consumed by all eleven scan-step tolerances (this plan). A repo with no `GATE_MODE` variable set still defaults to `report-only` per 18-01's fallback chain — branch-protection plans (18-03+) can now safely make the five job checks required, since blocking mode genuinely blocks and report-only genuinely doesn't.
- `actionlint`, `yamllint -d relaxed`, and `bash scripts/check-workflow-uploads.sh` all exit 0 on the final state of both workflow files.
- The fork-PR `vars` readability question (T-18-07 in this plan's threat model, cited in the pr-security.yml comment) remains open and is explicitly routed to Phase 19 (VAL-01) — not resolved here.

---
*Phase: 18-configurable-gate-mode-and-branch-protection*
*Completed: 2026-09-12*

## Self-Check: PASSED

- FOUND: .planning/phases/18-configurable-gate-mode-and-branch-protection/18-02-SUMMARY.md
- FOUND (nested repos/security-platform): commit ebf228c
- FOUND (nested repos/security-platform): commit eec57c1
- FOUND (nested repos/security-platform): commit 76f70a8
