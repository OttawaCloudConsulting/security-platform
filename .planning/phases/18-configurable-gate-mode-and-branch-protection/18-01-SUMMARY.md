---
phase: 18-configurable-gate-mode-and-branch-protection
plan: "01"
subsystem: infra
tags: [github-actions, workflow_call, gate-mode, actionlint, yamllint]

# Dependency graph
requires:
  - phase: 17-sarif-upload-and-artifact-retention
    provides: five parallel scan jobs (sast, iac, sca, container, secrets) each with SARIF upload and artifact retention, on a merged origin/main at commit 8fbea7d
provides:
  - "on.workflow_call.inputs.gate_mode: typed, required false, no default, describing blocking/report-only fallback"
  - "workflow-level env.GATE_MODE resolving inputs.gate_mode -> vars.GATE_MODE -> 'report-only' in exactly one place"
  - "a Validate gate_mode step as steps[0] in all five scan jobs, rejecting any value outside blocking|report-only including the empty string"
  - "feature/phase-18-configurable-gate-mode-and-branch-protection pushed to origin, cut from origin/main @ 8fbea7d"
affects: [18-02, 18-03, 18-04, 18-05, branch-protection-plans]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "workflow-level env is the single resolution point for a value that must be visible to both inputs and vars"
    - "per-job intolerant case-block validation step instead of a validation job, to avoid changing the frozen 5-job/5-check-run shape"

key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml

key-decisions:
  - "Cloned security-platform fresh into the worktree's gitignored repos/ dir instead of relying on the main checkout, because git worktrees do not carry gitignored/untracked directories; the main checkout's repos/security-platform was left untouched"
  - "Phase branch pushed to origin immediately after Task 2 so wave-2 worktree agents (18-02+) can pull it — a branch that only exists in this disposable worktree's clone would vanish when the worktree is removed"
  - "No default: on the gate_mode input, per plan/RESEARCH Pattern 1, so an omitted input stays falsy and the || chain reaches vars.GATE_MODE"
  - "Validation step placed before checkout in all five jobs (not after), per plan's explicit sequencing decision — an invalid gate_mode fails the job before any scan runs; trailing always() steps then also fail on missing files, but the first failure in the log is the legible one"

patterns-established:
  - "Pattern: resolve a value needed by both workflow_call inputs and caller vars exactly once, at workflow-level env, rather than repeating a fallback expression per consumption point"

requirements-completed: [CICD-06]

# Metrics
duration: 45min
completed: 2026-09-11
---

# Phase 18 Plan 01: Gate-Mode Contract and Enum Validation Summary

**Declared a typed `gate_mode` workflow_call input, resolved it once at workflow level into `env.GATE_MODE` (input -> caller repo variable -> `report-only`), and added an intolerant per-job enum-validation step to all five scan jobs — with no pass/fail behavior change yet (the eleven `# D-04` lines still read literal `true`).**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-09-11T~21:20Z (approx, no PLAN_START_TIME captured before the environment blocker was resolved)
- **Completed:** 2026-09-12T02:08:35Z
- **Tasks:** 2
- **Files modified:** 1 (`repos/security-platform/.github/workflows/security.yml`)

## Accomplishments

- `security.yml` now declares `on.workflow_call.inputs.gate_mode` (type `string`, `required: false`, no `default:`, description naming both `blocking` and `report-only`)
- A single workflow-level `env.GATE_MODE: ${{ inputs.gate_mode || vars.GATE_MODE || 'report-only' }}` resolves the mode for every consumer, commented with the three load-bearing facts (env sees inputs+vars, vars resolves to the caller repo, no default keeps the input falsy)
- Stale `Phase 15 / Gate mode is Phase 18` header sentence replaced with a description of the live contract
- All five jobs (`sast`, `iac`, `sca`, `container`, `secrets`) now open with an intolerant `Validate gate_mode` step, before `actions/checkout`, that accepts `blocking|report-only` and exits 1 (naming the offending value) on anything else including the empty string
- Phase branch `feature/phase-18-configurable-gate-mode-and-branch-protection` cut from `origin/main` at `8fbea7d` and pushed to `origin`

## Task Commits

Both commits are in the **nested `repos/security-platform` repository**, not this docs repo:

1. **Task 1: Cut the phase branch and declare the gate_mode contract** - `54fc470` (feat)
2. **Task 2: Add the per-job gate_mode validation step to all five jobs** - `3f21926` (feat)

Branch head after both commits: `3f219269d41bd1d768138215f5432a12af7f2481` (identical on local and `origin/feature/phase-18-configurable-gate-mode-and-branch-protection`).

**Plan metadata (this repo):** committed separately per the parallel-executor final-commit step below.

## Files Created/Modified

- `repos/security-platform/.github/workflows/security.yml` - added the `gate_mode` workflow_call input, workflow-level `env.GATE_MODE` resolution, rewritten header comment, and one `Validate gate_mode` step per scan job (5 insertions). File grew from 962 to 1058 lines.

## Decisions Made

- **Environment gap, resolved by fresh clone (Rule 3 — missing referenced file):** this worktree does not carry `repos/` (gitignored, so `git worktree add` never populated it). Cloned `https://github.com/OttawaCloudConsulting/security-platform.git` fresh into the worktree's own `repos/security-platform`, verified `origin/main` resolved to the exact commit (`8fbea7d`) and line count (962) the plan's `<interfaces>` block measured against, and re-verified the D-04/ADR-001 counts (11/11) before making any edit. The main checkout's `repos/security-platform` was read once (`ls`) to confirm it exists there and was otherwise never touched.
- **Pushed the phase branch to origin** immediately after Task 2, because this worktree (and its gitignored clone) is disposable — wave-2 plans (18-02 onward) run in their own worktrees and can only continue the branch via `origin`, not via this worktree's local clone.
- Followed the plan's exact YAML shapes (Pattern 1 for the input/env, Pattern 5 for the validation case block) with no deviation from the specified wording, comment voice, or sequencing.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing local checkout of the target repo**
- **Found during:** Task 1, before any edit
- **Issue:** The plan's Task 1 action assumes `repos/security-platform` already exists as a local checkout (per the plan's `<interfaces>` block, measured against the main tree's checkout). This worktree, being a fresh git worktree, does not carry the gitignored `repos/` directory at all — `ls repos/security-platform` returned "No such file or directory."
- **Fix:** Cloned `OttawaCloudConsulting/security-platform` (public, no auth needed) fresh into this worktree's own `repos/security-platform`, then re-verified every invariant the plan's `<interfaces>` block asserts (origin/main SHA, 962-line baseline, D-04 count 11, ADR-001 count 11, `check-workflow-uploads.sh` exit 0) before editing, since a fresh clone could in principle diverge from what the plan measured. All invariants matched.
- **Files modified:** none beyond the plan's own target file; this is a repo-provisioning step, not a code change
- **Verification:** `git -C repos/security-platform rev-parse origin/main` == `8fbea7d`; `wc -l` == 962; both grep counts == 11; `bash scripts/check-workflow-uploads.sh` exited 0 pre-edit
- **Committed in:** N/A (the clone itself is not a git-tracked artifact of this repo; it lives in the gitignored `repos/` directory)

**2. [Rule 3 - Blocking] Phase branch would not survive worktree teardown**
- **Found during:** end of Task 2, before returning
- **Issue:** The two `feat(18-01)` commits existed only in a gitignored clone inside this disposable worktree. When the worktree is merged back into the docs repo and removed, that clone disappears — wave-2 executors (18-02+), running in their own fresh worktrees, would have no way to obtain the branch.
- **Fix:** `git push -u origin feature/phase-18-configurable-gate-mode-and-branch-protection` from the nested clone. Push succeeded with no auth prompt (public repo, existing `gh`/git credentials already usable).
- **Files modified:** none (push only)
- **Verification:** local HEAD and `origin/feature/phase-18-configurable-gate-mode-and-branch-protection` both resolve to `3f219269d41bd1d768138215f5432a12af7f2481`
- **Committed in:** N/A (push, not a commit)

---

**Total deviations:** 2 auto-fixed (both Rule 3 — blocking, environment-provisioning; no code/behavior deviation from the plan's specified YAML)
**Impact on plan:** No scope creep. The plan's YAML content, comment wording, and sequencing were followed exactly; the two deviations are entirely about how to reach a git state the plan assumed already existed in a shared checkout, which does not exist in an isolated worktree.

## Issues Encountered

- The outer docs-repo worktree's HEAD started at `8fbea7d` (security-platform's Phase 17 merge commit), not at the expected `18-01-PLAN.md`-authoring commit `a6f6a1a` on `feature/phase-12-repo-setup-script` — `git merge-base` between the two returned no common ancestor (disjoint root histories: `a6f6a1a`'s lineage traces to an `init` commit unrelated to `8fbea7d`'s). The mandated `<worktree_branch_check>` protocol's `git reset --hard $EXPECTED_BASE` handled this correctly (working tree was clean beforehand); recorded here only so a later reader is not surprised that this worktree's HEAD moved once at startup.
- The plan's `<interfaces>` block describes the **main checkout's** local branch state (`local HEAD = feature/phase-17-... @ fbe0071`, `local main = 40682ce STALE`). That description is moot for this worktree's fresh clone, which only ever had `origin/main` at `8fbea7d` — a strict improvement since the task explicitly says to cut from `origin/main`, never from a possibly-stale local `main`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `feature/phase-18-configurable-gate-mode-and-branch-protection` exists on `origin` at `OttawaCloudConsulting/security-platform`, head commit `3f219269d41bd1d768138215f5432a12af7f2481`, containing both this plan's commits.
- 18-02 (and later plans in this phase) must fetch/checkout that branch from `origin` in their own worktree's fresh clone of `repos/security-platform` — they cannot assume this worktree's clone still exists.
- No pass/fail behavior has changed: all eleven `# D-04` `continue-on-error: true` lines are still literal `true`; `env.GATE_MODE` is computed but not yet consumed by any flip point. That consumption is 18-02's job.
- `actionlint`, `yamllint -d relaxed`, and `bash scripts/check-workflow-uploads.sh` all exit 0 on the final state of `security.yml`.
- Measured case-block exit codes for 18-04/18-05 to rely on: `blocking`=0, `report-only`=0, `nonsense`=1, empty string=1. The accepted branch echoes `gate_mode=<value>` verbatim, which those plans grep from the live run log.

---
*Phase: 18-configurable-gate-mode-and-branch-protection*
*Completed: 2026-09-11*

## Self-Check: PASSED

- FOUND: .planning/phases/18-configurable-gate-mode-and-branch-protection/18-01-SUMMARY.md
- FOUND (nested repos/security-platform): commit 54fc470
- FOUND (nested repos/security-platform): commit 3f21926
