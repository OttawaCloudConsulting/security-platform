---
phase: 18-configurable-gate-mode-and-branch-protection
plan: "05"
subsystem: infra
tags: [github-actions, gate-mode, live-run, pull-request, evidence, blocking, report-only, empty-commit]

# Dependency graph
requires:
  - phase: 18-configurable-gate-mode-and-branch-protection
    plan: "04"
    provides: "PR #9 open at head 31dbb0d, report-only baseline (run 34668611172): five success conclusions, five gate_mode=report-only log lines, five artifacts, seven analyses across six categories, eleven upload-verify assertions green"
provides:
  - "Live blocking-mode measurement: same PR (#9), same tree (ce7ec65...), one repository variable flip, five failure conclusions"
  - "Live proof of Criterion 3 by construction: three commits (31dbb0d, 5973e8e, 835c43e) share tree hash ce7ec652e09d07f9cee035410bbc05d47e0a79a8; git diff between the report-only and blocking commits produces no output"
  - "Live proof the reporting guarantees survive blocking: 5 artifacts, same 6 categories, all 11 upload-verify assertions green, none skipped, under a run where all 5 jobs concluded failure"
  - "Resolved 18-04's open question: the Checkov container action's 'Run Checkov' step DOES turn its job red under gate_mode: blocking, uniformly with the other four scan steps"
  - "Repository restored to report-only: GATE_MODE deleted and confirmed absent; a second empty commit (835c43e) re-measured 5 success conclusions and 5 gate_mode=report-only lines, re-proving D-03's fallback after the variable existed and was removed"
  - "rules/branches/main confirmed unchanged (deletion, non_fast_forward) before, during, and after"
  - "Task 2 (checkpoint:human-verify) and Task 3 (checkpoint:decision) NOT resolved by this agent — returned to the orchestrator with full evidence, per this plan's own instruction"
affects: [18-06, 18-07, 18-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Flip a repo-wide gate with `gh variable set`/`gh variable delete` and re-run via an EMPTY commit (never `gh run rerun`), so each measured run gets a fresh artifact namespace while the tree hash stays byte-identical to the prior commit — the strongest available proof that no YAML changed"
    - "Never infer post-scan-step behavior (uploads/artifacts/SARIF) from a report-only run; re-measure it explicitly once continue-on-error is toggled off, because a hard failure changes which steps a job runs"

key-files:
  created: []
  modified: []

key-decisions:
  - "The blocking run was triggered by an empty commit (5973e8e), not `gh run rerun` — v4 upload-artifact names must be unique per run id, and a re-run reuses the same run id, risking a 409 unrelated to gate mode. An empty commit produces a new run id on an unchanged tree."
  - "GATE_MODE was deleted unconditionally and immediately after the blocking measurement completed, per the plan's explicit safety instruction and this agent's own operating constraint — the window was 2026-09-12T03:06:56Z to 2026-09-12T03:09:26Z, roughly 2.5 minutes, and no unrelated run (e.g. Dependabot) executed inside it (checked against the full run list for that window)."
  - "Task 1 executed to completion; Tasks 2 (checkpoint:human-verify, gate=blocking) and 3 (checkpoint:decision, gate=blocking) are NOT resolved by this agent — both require a human decision this agent has no channel to obtain, and the plan and prompt both explicitly instruct against resolving them autonomously. Full evidence is returned to the orchestrator instead."
  - "Worktree HEAD assertion: docs-repo commit d1eebed was found only via `git log --oneline --all` — the worktree branch (worktree-agent-aafdce76b05741452) had drifted to security-platform's history (HEAD at 8fbea7d, the Phase 17 merge commit), not docs-repo history. Verified d1eebed was the correct docs-repo commit via `git cat-file -e d1eebed:.planning/phases/18-configurable-gate-mode-and-branch-protection/18-04-SUMMARY.md` (exit 0), confirmed a clean `git status --short` (only the gitignored `repos/` untracked), then ran the sanctioned `git reset --hard d1eebed`. The nested `repos/security-platform` clone has its own `.git` and was unaffected by the reset."
  - "repos/security-platform was gitignored and absent in this worktree (same as every prior 18-0x plan) — cloned fresh, checked out feature/phase-18-configurable-gate-mode-and-branch-protection from origin, and verified HEAD matched 18-04's recorded SHA (31dbb0d76749900b82f59fd4e2e4601dec485289) before any gh command was issued."

patterns-established:
  - "Pattern: when comparing a flipped-mode run to a baseline, capture BOTH the tree-hash identity (git rev-parse <sha>^{tree}) and an explicit empty git diff — either alone is suggestive, but showing both together is what a checkpoint reviewer needs to accept 'nothing was edited' without re-deriving it themselves."
  - "Pattern (recurring across 18-01 through 18-05): when a worktree's HEAD assertion probe fails with an unqualified `git log`, retry with `--all` before concluding the target commit doesn't exist — refs from the orchestrator's branch are present in the shared object store but not reachable from the currently checked-out branch's default log view."

requirements-completed: [CICD-06, CICD-04]

# Metrics
duration: ~20min (Task 1 only; Tasks 2 and 3 are pending checkpoints)
completed: 2026-09-12
---

# Phase 18 Plan 05: Blocking-Mode Live Measurement and Restore — Task 1 Only

**One `gh variable set GATE_MODE=blocking` flip, followed by an empty commit, turned PR #9's five `security / …` checks from `success` to `failure` on a byte-identical tree (hash `ce7ec652e09d07f9cee035410bbc05d47e0a79a8`), with all five artifacts, all six SARIF categories, and all eleven upload-verify assertions still landing — then `gh variable delete` and a second empty commit restored the same five checks to `success` with zero YAML ever touched.**

**Tasks 2 and 3 (both `checkpoint:*`, `gate="blocking"`) are intentionally NOT resolved in this document — see "Checkpoint Handoff" below.**

## Performance

- **Duration:** ~20 min (Task 1 only)
- **Started:** 2026-09-12T03:06:37Z
- **Completed:** 2026-09-12T03:11:37Z (restore run trigger)
- **Tasks:** 1 of 3 (Tasks 2 and 3 are checkpoints — returned to orchestrator, not executed)
- **Files modified:** 0 (this task's `<files>` is empty by design; its deliverable is the live repository variable flip and the two empty commits)

## Accomplishments

- **Criterion 1 fully evidenced, live.** The same pull request (#9) failed all five `security / …` checks under `GATE_MODE=blocking`, then passed all five under report-only — no code change between the two states.
- **Criterion 3 evidenced by construction, in its strongest form.** Three commits — `31dbb0d` (18-04's report-only baseline), `5973e8e` (this plan's blocking trigger), `835c43e` (this plan's restore trigger) — all resolve to the identical tree hash `ce7ec652e09d07f9cee035410bbc05d47e0a79a8`. `git diff 31dbb0d 835c43e` produces no output at all. Two different verdicts (and a third confirming the return), one unchanged tree.
- **18-04's open question is resolved.** 18-04 flagged that `Run Checkov`'s container-action step never printed a `Process completed with exit code N` line even under report-only with 14 findings, leaving it unconfirmed whether the step would visibly fail under blocking. It does: `security / IaC — Checkov`'s first (and only) failing step under this run is `Run Checkov` (step 5), exactly matching the other four jobs' scan-step-fails-first pattern.
- **P-04's warning was honored — nothing about upload survival was inferred from 18-04.** Under blocking, `artifacts.total_count` is still 5 with the same five names (`gitleaks-results`, `checkov-results`, `trivy-image-results`, `semgrep-results`, `sca-results`); the code-scanning category set is still the same six (`checkov`, `gitleaks`, `semgrep`, `tflint`, `trivy-fs`, `trivy-image`); and all eleven upload-verify assertions are green, none skipped — all measured fresh against run 34669534855, not carried over from 34668611172.
- **The repository-wide window was kept short and nothing else ran inside it.** `GATE_MODE` was set at 2026-09-12T03:06:56Z and deleted at 2026-09-12T03:09:26Z (~2.5 minutes). Querying every run created in that interval across the whole repository returns exactly one run: this plan's own blocking measurement (34669534855). No Dependabot or unrelated PR executed under blocking.
- **The restore re-proves D-03's fallback after a variable existed and was removed**, not just after it was never set: run 34669700643 (commit `835c43e`, GATE_MODE absent) shows five `gate_mode=report-only` log lines, zero `gate_mode=blocking`, and all five checks `success`.

## Task Commits

Commits live in the **nested `repos/security-platform` repository**, not this docs repo:

1. **Task 1a: Trigger the blocking run** — `5973e8e` (chore) — empty commit, tree unchanged from `31dbb0d`
2. **Task 1b: Restore report-only** — `835c43e` (chore) — empty commit, tree unchanged from `5973e8e`/`31dbb0d`

No YAML, script, or workflow file was edited in either commit — both are `git commit --allow-empty`.

**Plan metadata (this repo):** committed separately per the parallel-executor final-commit step below.

## Files Created/Modified

None in `repos/security-platform` beyond the two empty commits — this task flips a repository variable and re-runs an unchanged tree; it makes no code change.

## Required Output: Observed Evidence

### 0. Preflight (before the flip)

| Check | Result |
|---|---|
| `gh variable list -R OttawaCloudConsulting/security-platform` | empty — no `GATE_MODE` |
| `gh api rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` |
| PR #9 state | `OPEN`, `MERGEABLE`, head `31dbb0d76749900b82f59fd4e2e4601dec485289` |
| `.github/workflows/security.yml` `always()` guard count | 48 (unchanged, read only) |
| Scan-step `continue-on-error` expression, all five jobs | `${{ env.GATE_MODE == 'report-only' }}` — confirmed present on every scan step before flipping |

### 1. The variable flip and window

| Event | Timestamp |
|---|---|
| `gh variable set GATE_MODE --body blocking` | `2026-09-12T03:06:56Z` (read back via `gh variable list`) |
| `gh variable delete GATE_MODE` | `2026-09-12T03:09:26Z` |
| **Window length** | **~2.5 minutes** |
| Other runs (any branch/repo) inside the window | **None** — queried the full run list filtered to `createdAt` between the two timestamps; only this plan's own blocking run (34669534855) appears |

`GATE_MODE` is repository-wide, not PR-scoped, per the plan's own warning — the short window and the explicit collateral-run check are the mitigation, and both are satisfied.

### 2. Run identifiers

| Item | Report-only baseline (18-04) | Blocking (this plan) | Restore (this plan) |
|---|---|---|---|
| Commit | `31dbb0d76749900b82f59fd4e2e4601dec485289` | `5973e8e292b9616d4772264e50a40fcd0c0fb9f3` | `835c43e8e8d7cad5276120b925ca5650a3bcda50` |
| Run id | 34668611172 | 34669534855 | 34669700643 |
| Conclusion | `success` | `failure` | `success` |
| Tree hash | `ce7ec652e09d07f9cee035410bbc05d47e0a79a8` | `ce7ec652e09d07f9cee035410bbc05d47e0a79a8` | `ce7ec652e09d07f9cee035410bbc05d47e0a79a8` |

**All three tree hashes are identical.** `git diff 31dbb0d76749900b82f59fd4e2e4601dec485289 835c43e8e8d7cad5276120b925ca5650a3bcda50` produced **no output** — confirmed directly, not inferred from the tree-hash match alone.

### 3. The five `security / …` checks (app.id 15368) under blocking — all `failure`

| Check name | Conclusion |
|---|---|
| `security / SAST — Semgrep CE` | failure |
| `security / IaC — Checkov` | failure |
| `security / SCA — Trivy Filesystem` | failure |
| `security / Container — Trivy Image` | failure |
| `security / Secrets — Gitleaks` | failure |

Same five frozen names as 18-04's baseline, byte-identical, all now `failure`.

### 4. The five `gate_mode=` log lines under blocking

`gh run view 34669534855 --log | grep 'gate_mode=blocking$'` — anchored count **5**; `gate_mode=report-only$` count **0**.

| Job | Log line |
|---|---|
| `security / Container — Trivy Image` | `gate_mode=blocking` |
| `security / IaC — Checkov` | `gate_mode=blocking` |
| `security / SAST — Semgrep CE` | `gate_mode=blocking` |
| `security / SCA — Trivy Filesystem` | `gate_mode=blocking` |
| `security / Secrets — Gitleaks` | `gate_mode=blocking` |

### 5. First failing step per job under blocking

| Job | First (and, except SCA, only) failing step | Step number |
|---|---|---|
| `security / SAST — Semgrep CE` | `Run Semgrep` | 5 |
| `security / IaC — Checkov` | `Run Checkov` | 5 |
| `security / SCA — Trivy Filesystem` | `Run Trivy filesystem scan (JSON for retention)` (first of six failing steps in this job — Trivy fs x2, npm audit, pip-audit, tflint x2) | 10 |
| `security / Container — Trivy Image` | `Run Trivy image scan` | 6 |
| `security / Secrets — Gitleaks` | `Run Gitleaks (SARIF)` (also `Run Gitleaks (JSON)`) | 5 |

Every first failure is a scan step, never a verify step and never `Validate gate_mode` — the acceptance criterion. **This resolves 18-04's open question about `Run Checkov`**: despite producing no `Process completed with exit code N` line under report-only (18-04 §8), the same container action's step visibly fails the job under blocking, uniformly with the other four scan mechanisms.

### 6. Artifacts under blocking — five, same names as baseline

`gh api actions/runs/34669534855/artifacts` → `total_count: 5`, names: `gitleaks-results`, `checkov-results`, `trivy-image-results`, `semgrep-results`, `sca-results` — identical set to 18-04's baseline (order differs, set does not).

### 7. Code-scanning categories under blocking — same six as baseline

`gh api code-scanning/analyses?ref=refs/pull/9/merge` (all analyses for this PR ref, includes both the baseline and blocking commit's contributions since ref-based queries aggregate history):

| Category | Tool | Results |
|---|---|---|
| `checkov` | `checkov` | 14 |
| `gitleaks` | `Gitleaks` | 9 |
| `semgrep` | `Semgrep OSS` | 3 |
| `tflint` | `tflint` | 3 |
| `tflint` | `tflint-errors` | 0 |
| `trivy-fs` | `Trivy` | 6 |
| `trivy-image` | `Trivy` | 56 |

Six distinct categories, same finding counts as 18-04 — unchanged, as expected on an unchanged tree.

### 8. Eleven upload-verify assertions under blocking — all green, none skipped

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

All eleven green under a run where all five jobs concluded `failure` — the reporting guarantees survive the gate, re-measured rather than inherited from 18-04, per P-04.

### 9. Restore — five `success`, five `gate_mode=report-only`

| Check name | Conclusion |
|---|---|
| `security / SAST — Semgrep CE` | success |
| `security / IaC — Checkov` | success |
| `security / SCA — Trivy Filesystem` | success |
| `security / Container — Trivy Image` | success |
| `security / Secrets — Gitleaks` | success |

`gh run view 34669700643 --log`: `gate_mode=report-only$` count **5**, `gate_mode=blocking$` count **0**. Artifacts: `total_count: 5`, same five names. PR #9: `OPEN`, `MERGEABLE`, head `835c43e8e8d7cad5276120b925ca5650a3bcda50`.

### 10. Postflight (after the restore) — no repository configuration left changed

| Check | Before | After |
|---|---|---|
| `gh variable list -R OttawaCloudConsulting/security-platform` | empty | **empty — confirmed absent** |
| `gh api rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` | `deletion`, `non_fast_forward` — **unchanged** |
| PR #9 state | `OPEN`, `MERGEABLE` | `OPEN`, `MERGEABLE` — nothing merged |

## Decisions Made

See `key-decisions` in frontmatter. Most load-bearing: this document stops at Task 1. Tasks 2 (`checkpoint:human-verify`, `gate="blocking"`) and 3 (`checkpoint:decision`, `gate="blocking"`) are returned to the orchestrator/user rather than resolved by this agent, per the plan's own text, the executor's protocol, and the explicit instruction in this agent's prompt not to touch either checkpoint or run `scripts/set-required-checks.sh --apply` under any circumstance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing local checkout of the target repo (same as every prior 18-0x plan)**
- **Found during:** start of Task 1, before any `gh` command
- **Issue:** This worktree does not carry the gitignored `repos/` directory.
- **Fix:** Cloned `OttawaCloudConsulting/security-platform` fresh into this worktree's `repos/security-platform`, fetched and checked out `feature/phase-18-configurable-gate-mode-and-branch-protection` from `origin`, and verified the branch head (`31dbb0d76749900b82f59fd4e2e4601dec485289`) matched 18-04-SUMMARY's recorded end state before issuing any `gh` command.
- **Files modified:** none beyond repo-provisioning.
- **Verification:** `git log --oneline -8` matched 18-04-SUMMARY's recorded commit sequence exactly; `git rev-parse HEAD` matched the recorded SHA.
- **Committed in:** N/A (clone/checkout only).

**2. [Rule 3 - Blocking] Outer worktree HEAD assertion probe initially failed to find the docs-repo base commit**
- **Found during:** the mandated `<worktree_branch_check>` step and later, before writing this SUMMARY
- **Issue:** `git log --oneline | grep d1eebed` returned nothing, because this worktree's currently-checked-out branch (`worktree-agent-aafdce76b05741452`) was pointed at security-platform commit history (`8fbea7d`) rather than docs-repo history, and an unqualified `git log --oneline` only walks the current branch's own history. This was masked at the very start because `git log --oneline --all | grep d1eebed` DID find the commit (reachable via the shared object store), so the initial branch-check step passed without flagging that the worktree's own checked-out tree lacked `.planning/`. The drift surfaced only when the `Write` tool refused to create the SUMMARY at the main-repo path and the `.planning/` directory was found absent from the worktree's own file tree.
- **Fix:** Proved `d1eebed` was the correct docs-repo commit via `git cat-file -e d1eebed:.planning/phases/18-configurable-gate-mode-and-branch-protection/18-04-SUMMARY.md` (exit 0), confirmed `git status --short` was clean (only the gitignored `repos/` untracked), then ran the sanctioned `git reset --hard d1eebed` on the worktree branch.
- **Files modified:** none (ref move on the worktree branch, not a content edit). The nested `repos/security-platform` clone has its own `.git` directory and was unaffected.
- **Verification:** post-reset, `.planning/phases/18-configurable-gate-mode-and-branch-protection/` is populated with all expected plan/summary files; `git status --short` remained clean apart from `repos/` (unchanged, gitignored); `repos/security-platform`'s own checkout and its two empty commits were untouched by the reset.
- **Committed in:** N/A (HEAD-position correction, not a tracked change).

**Total deviations:** 2 auto-fixed (both Rule 3, environment/HEAD-position correction; no scope or behaviour deviation from the plan's specified actions).
**Impact on plan:** None. All evidence collection, the variable flip, and both empty commits follow the plan exactly.

## Issues Encountered

None beyond the two deviations above, both resolved before any evidence-affecting action. The sandbox flagged several multi-line `git rev-parse`/`git diff`/loop shell constructs as "too complex to verify it stays inside the worktree" mid-execution (not a git-safety concern — no destructive operation was attempted); each was split into separate single-purpose commands and re-run successfully.

## User Setup Required

None for Task 1. **Tasks 2 and 3 require a human operator** — see "Checkpoint Handoff" below.

## Checkpoint Handoff — Tasks 2 and 3 (NOT resolved by this agent)

**Task 2 is `type="checkpoint:human-verify"`, `gate="blocking"`.** **Task 3 is `type="checkpoint:decision"`, `gate="blocking"`.** Per this plan's own text and this agent's explicit operating instructions, neither is resolved here — this agent has no channel to ask a human directly mid-session, and the prompt explicitly forbids attempting to resolve either or running `scripts/set-required-checks.sh --apply` under any circumstance.

**Do NOT merge PR #9. `GATE_MODE` has been deleted and confirmed absent. No ruleset write occurred.** All three hold true as of the end of this document.

### What Task 2 needs the operator to confirm (evidence above)

The paired evidence: the shared tree hash `ce7ec652e09d07f9cee035410bbc05d47e0a79a8` across all three commits, the empty `git diff`, the three runs' conclusions (success → failure → success), the `gate_mode=` line counts per attempt (5×report-only, then 5×blocking, then 5×report-only), the artifact count (5, same names) and category set (6, same set) under blocking, the first failing step per job (§5 above — including the now-resolved Checkov question), and the final `gh variable list` output showing `GATE_MODE` gone.

### What Task 3 needs the operator to decide

Whether to run `bash scripts/set-required-checks.sh --apply` against ruleset `14243983`, making the five `security / …` contexts required on `main`. The plan's recommended answer is `leave-unrequired`, given the measured hazard: `fixtures/` fires every scanner (Checkov 14, Trivy image 56, Semgrep 3, gitleaks 9, tflint 3), the live ruleset reports `bypass_actors: []` and `current_user_can_bypass: "never"`, and rulesets do not auto-exempt repo admins — so requiring these checks while blocking is on would lock `main` against every PR, including the revert. This agent did not run `--apply` and will not, per explicit instruction.

## Next Phase Readiness

- PR #9 is open, unmerged, mergeable, at `https://github.com/OttawaCloudConsulting/security-platform/pull/9`, currently `success` on all five checks at head `835c43e8e8d7cad5276120b925ca5650a3bcda50` — the repository is back in report-only exactly as it started.
- **Blocker for phase progression:** Task 2's operator confirmation and Task 3's operator decision have not occurred. 18-06/18-07 (documentation plans) and 18-08 (the eventual merge) should not proceed until both are resolved.
- The full evidence table above (sections 0-10) is what Task 2 asks to be presented to the operator, and what Task 3's decision context depends on.

---
*Phase: 18-configurable-gate-mode-and-branch-protection*
*Completed: 2026-09-12*

## Self-Check: PASSED

- FOUND: .planning/phases/18-configurable-gate-mode-and-branch-protection/18-05-SUMMARY.md (this file)
- FOUND (live GitHub state): PR #9 at `https://github.com/OttawaCloudConsulting/security-platform/pull/9`, OPEN, MERGEABLE, head `835c43e8e8d7cad5276120b925ca5650a3bcda50`
- FOUND (live GitHub state): commit `5973e8e292b9616d4772264e50a40fcd0c0fb9f3`, run 34669534855, conclusion `failure`
- FOUND (live GitHub state): commit `835c43e8e8d7cad5276120b925ca5650a3bcda50`, run 34669700643, conclusion `success`
- FOUND (live GitHub state): `gh variable list -R OttawaCloudConsulting/security-platform` returns empty
- FOUND (live GitHub state): `gh api rules/branches/main --jq '.[].type'` returns `deletion`, `non_fast_forward`
