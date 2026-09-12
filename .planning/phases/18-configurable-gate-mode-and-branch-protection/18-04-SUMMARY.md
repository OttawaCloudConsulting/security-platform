---
phase: 18-configurable-gate-mode-and-branch-protection
plan: "04"
subsystem: infra
tags: [github-actions, gate-mode, live-run, pull-request, evidence, report-only]

# Dependency graph
requires:
  - phase: 18-configurable-gate-mode-and-branch-protection
    plan: "03"
    provides: "eleven fail-closed scan-step tolerances plus three always()-guarded SCA conditions on feature/phase-18-configurable-gate-mode-and-branch-protection @ 31dbb0d, plus the non-destructive required-checks ruleset helper"
provides:
  - "PR #9 open against OttawaCloudConsulting/security-platform main, unmerged, with run 34668611172 completed green"
  - "Live evidence: five `security / …` checks all `success`, byte-exact against the frozen five, no bare `security` check"
  - "Live evidence: five `gate_mode=report-only` log lines (job-attributed), zero `gate_mode=blocking`"
  - "Live evidence: five artifacts, one shared expiry, 90 days exactly after run creation"
  - "Live evidence: seven code-scanning analyses across six categories on the PR merge ref, matching 17-05's set"
  - "Live evidence: eleven upload-verify assertions green, none skipped"
  - "Live evidence: GATE_MODE variable absent before and after; rules/branches/main unchanged before and after"
  - "Live evidence: continue-on-error genuinely tolerated non-zero scanner exits (Trivy fs, Trivy image, Semgrep, Gitleaks) while every job stayed green"
affects: [18-05, 18-06, 18-07, 18-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Read the effective mode from the run log (gate_mode=<value> per job), never inferred from the YAML"
    - "Compare a live check-run name list against the frozen list byte-for-byte with `diff`, not by eyeballing"

key-files:
  created: []
  modified: []

key-decisions:
  - "Task 1 executed to completion; Task 2 (checkpoint:human-verify, gate=blocking) is NOT resolved by this agent per the plan's own instruction and the executor's operating constraints — the evidence table is returned to the orchestrator/user instead"
  - "Worktree HEAD assertion: the `297905f` base was NOT found by an unqualified `git log --oneline | grep`, because that command defaults to the current branch's history and this worktree's checked-out branch had drifted to security-platform's history. Re-ran with `git log --oneline --all | grep 297905f`, found it, proved it was the correct docs-repo commit via `git cat-file -e 297905f:.planning/phases/18-configurable-gate-mode-and-branch-protection/18-04-PLAN.md`, then ran the sanctioned `git reset --hard 297905f` on the worktree branch. The nested `repos/security-platform` clone has its own `.git` directory and was unaffected."
  - "PR opened as #9 (not part of #8) since this phase makes independent live changes and 17-05's PR #8 was already merged (visible as the merge commit 8fbea7d at the branch's base)"

patterns-established:
  - "Pattern: when a worktree's HEAD assertion probe fails with an unqualified `git log`, retry with `--all` before concluding the target commit doesn't exist — refs from the orchestrator's branch are present in the shared object store but not reachable from the currently checked-out branch's default log view"

requirements-completed: [CICD-06]

# Metrics
duration: ~25min (Task 1 only; Task 2 is a pending checkpoint)
completed: 2026-09-12
---

# Phase 18 Plan 04: The Report-Only Baseline — Live Evidence, Task 1 Only

**PR #9 and run 34668611172 turned the report-only default from static YAML into measured fact: five `security / …` checks all green, five `gate_mode=report-only` log lines, seven code-scanning analyses across six categories, five artifacts at a single 90-day expiry, and eleven upload-verify assertions green with none skipped — with `GATE_MODE` confirmed absent before and after, and the branch ruleset confirmed unchanged.**

**Task 2 (the operator checkpoint) is intentionally NOT resolved in this document — see "Checkpoint Handoff" below.**

## Performance

- **Duration:** ~25 min (Task 1 only)
- **Completed:** 2026-09-12
- **Tasks:** 1 of 2 (Task 2 is `checkpoint:human-verify`, `gate="blocking"` — returned to orchestrator, not executed)
- **Files modified:** 0 (this task's `<files>` is empty by design; its deliverable is the live PR and run)

## Accomplishments

- **The default path is proven live.** With no `with:` block on the caller and no `GATE_MODE` repository variable, all eleven scan-step tolerances resolved to report-only and every one of the five `security / …` jobs concluded `success`.
- **The mode was read from the log, not inferred.** All five `Validate gate_mode` steps printed `gate_mode=report-only`; zero printed `gate_mode=blocking`.
- **No sixth `security` check exists.** The full twelve-check listing on the head SHA matches 17-05's set exactly (five `security / …` + six `github-advanced-security` + one GitGuardian), and a scripted assertion confirms no check is named bare `security`.
- **Phase 17's SARIF/artifact guarantees survive the gate rewiring.** Five artifacts, one 90-day expiry, seven analyses across six categories, eleven upload-verify assertions all green — all matching 17-05's shape.
- **One real, expected difference from 17-05, verified rather than assumed:** the `Checkov` code-scanning check (app 57789) concluded `success` here vs `failure` in 17-05. Confirmed by reading its annotations directly: `GET check-runs/{id}/annotations` returns `[]` on this run (17-05 had two `failure`-level annotations on `fixtures/main.tf` line 38). This PR's diff touches only `.github/workflows/*.yml` and `scripts/set-required-checks.sh` — no fixture lines — so no error-severity Checkov alert lands on a changed line. Results counts across all six categories are otherwise identical to 17-05 (checkov 14, trivy-image 56, semgrep 3, gitleaks 9, tflint 3, trivy-fs 6).
- **`continue-on-error` was observed actually tolerating failures, not just configured to.** The run log shows `Process completed with exit code 1` on the Trivy filesystem scan (both JSON and SARIF invocations), the Trivy image scan, the Semgrep step, and both Gitleaks invocations (SARIF + JSON) — every one of those five jobs nonetheless concluded `success`. This is the live proof the plan's objective paragraph asks for: 18-05's blocking run should turn these same steps red.

## Task Commits

1. **Task 1: Push the branch, open the PR, and measure the report-only baseline** — no commit; `<files></files>` in the plan by design (same shape as 17-05's Task 2). Deliverable is PR #9, run 34668611172, and the evidence recorded below.

Branch `feature/phase-18-configurable-gate-mode-and-branch-protection` was already at `origin` head `31dbb0d` (18-03's commit) — nothing new was pushed to the nested repo by this task; `git push -u` returned "Everything up-to-date".

**Plan metadata (this repo):** committed separately per the parallel-executor final-commit step below.

## Files Created/Modified

None in `repos/security-platform` — this task opens a PR and measures a run; it makes no code change.

## Required Output: Observed Evidence

### 0. Preflight (before the run)

| Check | Result |
|---|---|
| `gh variable list -R OttawaCloudConsulting/security-platform` | empty — no `GATE_MODE` |
| `gh api repos/OttawaCloudConsulting/security-platform/rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` |
| Branch head before push | `31dbb0d` (18-03's commit; matched 18-03-SUMMARY's recorded end state) |

### 1. PR and run identifiers

| Item | This run (PR #9 / run 34668611172) | Phase 17 (PR #8 / run 34638828775) |
|---|---|---|
| PR | **#9** — `https://github.com/OttawaCloudConsulting/security-platform/pull/9` | #8 |
| Run | **34668611172**, event `pull_request`, conclusion `success` | 34638828775, `success` |
| Head SHA | `31dbb0d76749900b82f59fd4e2e4601dec485289` | `fbe0071d6934d19524f5bf9345e91396080fa882` |
| PR state | `OPEN`, `MERGEABLE` — **nothing merged** | `OPEN`, `MERGEABLE` (later merged by 17-07) |
| Run created_at | `2026-09-12T02:47:10Z` | — |

### 2. The five `security / …` checks (app.id 15368) — byte-exact, all `success`

| Check name | Conclusion | Matches frozen list in `scripts/set-required-checks.sh`? |
|---|---|---|
| `security / SAST — Semgrep CE` | success | yes |
| `security / IaC — Checkov` | success | yes |
| `security / SCA — Trivy Filesystem` | success | yes |
| `security / Container — Trivy Image` | success | yes |
| `security / Secrets — Gitleaks` | success | yes |

`diff` between the live sorted name list and the sorted name list extracted from `scripts/set-required-checks.sh` (18-03's codepoint-verified frozen list) returned **exit 0** — zero differences, byte-for-byte.

Assertion output: `{"all_success": true, "bare_security": false, "count": 5, "names": [...]}`.

### 3. The complete twelve-check listing (app ids)

| App id | Check name | Conclusion |
|---|---|---|
| 15368 | `security / Container — Trivy Image` | success |
| 15368 | `security / IaC — Checkov` | success |
| 15368 | `security / SAST — Semgrep CE` | success |
| 15368 | `security / SCA — Trivy Filesystem` | success |
| 15368 | `security / Secrets — Gitleaks` | success |
| 46505 | `GitGuardian Security Checks` | success |
| 57789 | `Checkov` | **success** (17-05: failure — see Accomplishments) |
| 57789 | `gitleaks` | success |
| 57789 | `Semgrep OSS` | success |
| 57789 | `tflint` | success |
| 57789 | `tflint-errors` | success |
| 57789 | `Trivy` | success |

**Total: 12.** Matches 17-05's set exactly (five job checks + six `github-advanced-security` + one GitGuardian). **No check run named bare `security` exists** — confirmed by the scripted `bare_security: false` assertion above. This is the live evidence for the D-06 five-not-six correction.

### 4. The five `gate_mode=` log lines, job-attributed

`gh run view 34668611172 --log | grep 'gate_mode=report-only$'` — anchored count **5**; unanchored count **5** (identical, no discrepancy to explain); `gate_mode=blocking` count **0**.

| Job | Log line |
|---|---|
| `security / IaC — Checkov` | `gate_mode=report-only` |
| `security / SCA — Trivy Filesystem` | `gate_mode=report-only` |
| `security / Container — Trivy Image` | `gate_mode=report-only` |
| `security / SAST — Semgrep CE` | `gate_mode=report-only` |
| `security / Secrets — Gitleaks` | `gate_mode=report-only` |

Spot-checked per the Task 2 how-to-verify: `security / IaC — Checkov`'s first substantive step (`Validate gate_mode`) prints `gate_mode=report-only`, and the job still shows the Checkov step green despite findings.

### 5. Artifacts — five, one shared expiry, 90 days exact

`gh api repos/.../actions/runs/34668611172/artifacts`

| Artifact | Present |
|---|---|
| `semgrep-results` | yes |
| `checkov-results` | yes |
| `sca-results` | yes |
| `trivy-image-results` | yes |
| `gitleaks-results` | yes |

`total_count: 5`. Single distinct `expires_at`: `2026-12-11T02:47:10Z`. Run `created_at`: `2026-09-12T02:47:10Z`. Arithmetic verified: `2026-12-11T02:47:10Z` − `2026-09-12T02:47:10Z` = **90 days exactly** (18 remaining days of September + 31 October + 30 November + 11 December). Names match 17-05's five exactly.

### 6. Code-scanning analyses on the PR merge ref — six categories, matching 17-05

`gh api repos/.../code-scanning/analyses?ref=refs/pull/9/merge`

| Category | Tool | Results | vs 17-05 |
|---|---|---|---|
| `tflint` | `tflint-errors` | 0 | identical |
| `tflint` | `tflint` | 3 | identical |
| `semgrep` | `Semgrep OSS` | 3 | identical |
| `trivy-fs` | `Trivy` | 6 | identical |
| `checkov` | `checkov` | 14 | identical |
| `trivy-image` | `Trivy` | 56 | identical |
| `gitleaks` | `Gitleaks` | 9 | identical |

Seven analyses, six distinct categories: `checkov, gitleaks, semgrep, tflint, trivy-fs, trivy-image` — matches 17-05 exactly, including the tflint dual-driver artifact (7 analyses / 6 categories, not 6/6).

**Difference from 17-05, explained (see Accomplishments #6):** the `Checkov` app-check concluded `success` here (17-05: `failure`) because this PR's diff carries no fixture-line changes, so zero Checkov annotations render on a changed line (verified: `GET check-runs/{checkov_id}/annotations` → `[]`; 17-05 had two). Result counts are unaffected — only the diff-annotation-driven check conclusion differs, which is consistent with GitHub's code-scanning check behaviour (fails on error-severity alerts attributable to the diff, not on total analysis results).

### 7. Eleven upload-verify assertions — all green, none skipped

Read from `gh run view 34668611172 --json jobs`:

| # | Job | Assertion step | Conclusion |
|---|---|---|---|
| 1 | SAST | Verify Semgrep SARIF upload landed | success |
| 2 | IaC | Verify Checkov SARIF upload landed | success |
| 3 | SCA | Verify Trivy filesystem SARIF upload landed | success |
| 4 | SCA | Verify tflint SARIF upload landed | success |
| 5 | Container | Verify Trivy image SARIF upload landed | success |
| 6 | Secrets | Verify Gitleaks SARIF upload landed | success |
| 7 | SAST | Verify SAST artifact upload landed | success |
| 8 | IaC | Verify IaC artifact upload landed | success |
| 9 | SCA | Verify SCA artifact upload landed | success |
| 10 | Container | Verify container artifact upload landed | success |
| 11 | Secrets | Verify secrets artifact upload landed | success |

Zero skips — the same-repo, non-Dependabot PR condition held (branch pushed to origin, no fork used), so every assertion actually proved something.

### 8. Live proof `continue-on-error` tolerated real failures

`Process completed with exit code 1` (or equivalent non-zero) observed in the run log, job still concluding `success`:

| Job | Step(s) that exited non-zero |
|---|---|
| `security / SCA — Trivy Filesystem` | Trivy filesystem scan (JSON for retention), Trivy filesystem scan (SARIF for code scanning) |
| `security / Container — Trivy Image` | Run Trivy image scan |
| `security / SAST — Semgrep CE` | Run Semgrep |
| `security / Secrets — Gitleaks` | Run Gitleaks (SARIF), Run Gitleaks (JSON) |

Every one of these jobs concluded `success` overall — this is the live mechanism the objective paragraph asks to be observed, not just configured. 18-05's blocking run is expected to turn these same steps (and jobs) red.

### 9. Postflight (after the run) — no repository configuration changed

| Check | Before | After |
|---|---|---|
| `gh variable list -R OttawaCloudConsulting/security-platform` | empty | empty — still no `GATE_MODE` |
| `gh api repos/.../rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` | `deletion`, `non_fast_forward` — unchanged |
| PR #9 state | (opened during this task) | `OPEN`, `MERGEABLE` |

No merge occurred. No variable was set. No ruleset was modified.

## Decisions Made

See `key-decisions` in frontmatter. Most load-bearing: this document stops at Task 1. Task 2 is a `checkpoint:human-verify` with `gate="blocking"` — per the executor's own protocol, that checkpoint is returned to the orchestrator/user rather than resolved by this agent, since this agent has no channel to ask the human directly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing local checkout of the target repo (same as 18-01/18-02/18-03)**
- **Found during:** start of Task 1, before any gh command
- **Issue:** This worktree does not carry the gitignored `repos/` directory.
- **Fix:** Cloned `OttawaCloudConsulting/security-platform` fresh into this worktree's `repos/security-platform`, fetched and checked out `feature/phase-18-configurable-gate-mode-and-branch-protection` from `origin`, and verified the branch head (`31dbb0d`) matched 18-03-SUMMARY's recorded end state before doing anything.
- **Files modified:** none beyond repo-provisioning.
- **Verification:** `git log --oneline -8` in the nested clone matched 18-03-SUMMARY's recorded commit sequence exactly.
- **Committed in:** N/A (clone/checkout only).

**2. [Rule 3 - Blocking] Outer worktree HEAD assertion probe initially failed to find the docs-repo base commit**
- **Found during:** the mandated `<worktree_branch_check>` step, before any file was read
- **Issue:** `git log --oneline | grep 297905f` returned nothing, because this worktree's currently-checked-out branch (`worktree-agent-a5ccc54a58d3be21a`) had somehow ended up pointed at security-platform commit history (`8fbea7d`, `fbe0071`) rather than docs-repo history, and an unqualified `git log --oneline` only walks the current branch's own history.
- **Fix:** Re-ran with `git log --oneline --all | grep 297905f`, which found the commit (reachable via the orchestrator's `feature/phase-12-repo-setup-script` branch, sharing the same object store). Proved it was the correct docs-repo commit via `git cat-file -e 297905f:.planning/phases/18-configurable-gate-mode-and-branch-protection/18-04-PLAN.md` (exit 0). Then ran the sanctioned worktree-branch-check exception `git reset --hard 297905f`. `git status --short` was clean before the reset (only the gitignored `repos/` directory untracked); the nested `repos/security-platform` clone was unaffected (separate `.git`).
- **Files modified:** none (this is a ref move on the worktree branch, not a content edit).
- **Verification:** post-reset, `.planning/phases/18-configurable-gate-mode-and-branch-protection/` is populated with all expected plan/summary files; `git status --short` remained clean apart from `repos/` (unchanged, gitignored).
- **Committed in:** N/A (HEAD-position correction, not a tracked change).

**Total deviations:** 2 auto-fixed (both Rule 3, environment/HEAD-position correction; no scope or behaviour deviation from the plan's specified actions).
**Impact on plan:** None. All evidence collection and the PR itself follow the plan exactly.

## Issues Encountered

None beyond the two deviations above, both resolved before any evidence-affecting action.

## User Setup Required

None for Task 1. **Task 2 requires a human operator decision** — see "Checkpoint Handoff" below.

## Checkpoint Handoff — Task 2 (NOT resolved by this agent)

**Task 2 is `type="checkpoint:human-verify"` with `gate="blocking"`.** This plan's own instructions state a fresh agent is never resumed for a checkpoint by the same executor without an explicit resume signal, and this agent has no channel to ask a human directly mid-session. Per the objective given to this agent, Task 2 is **returned to the orchestrator/user as a checkpoint**, not resolved here.

**Do NOT merge PR #9. Do NOT set `GATE_MODE`. Do NOT modify the ruleset.** All three remain untouched as of the end of this document.

The full evidence table above (sections 0-9) is what Task 2 asks to be presented to the operator before asking for confirmation. See the executor's final response for the compact comparison table against Phase 17's numbers.

## Next Phase Readiness

- PR #9 is open, unmerged, mergeable, at `https://github.com/OttawaCloudConsulting/security-platform/pull/9`, running the rewired workflow with nothing set anywhere — the report-only baseline this phase's Success Criterion 1 needs.
- 18-05 can re-run on this same PR by setting the `GATE_MODE` repository variable to `blocking` (no YAML edit) and comparing the same eleven scan-step outcomes — this plan's §8 (five tolerated non-zero exits, spread across four jobs) is the direct prediction for what should turn red.
- 18-08 owns the eventual merge, gated on both 18-04's and 18-05's evidence being confirmed by the operator.
- **Blocker for phase progression:** Task 2's operator confirmation has not occurred. 18-05 should not begin until "approved" (or a described mismatch) is received for this plan's Task 2.

---
*Phase: 18-configurable-gate-mode-and-branch-protection*
*Completed: 2026-09-12 (Task 1 only; Task 2 pending)*
