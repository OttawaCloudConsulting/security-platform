---
phase: 21-docs-cleanup-close-remaining-phase-20-deferred-items
plan: 02
subsystem: docs
tags: [defectdojo, sca, trivy, npm-audit, pip-audit, grype-removal, milestone-plan]

requires:
  - phase: 21-01
    provides: "milestone-2-cicd-gate.md corrected to the same live SCA parser set (landed concurrently, verified after the fact)"
provides:
  - "milestone-4-defectdojo.md M4-F3 parser list corrected to the live SCA tool set (Semgrep, Checkov, Trivy Scan x2 job-qualified, NPM Audit v7+ Scan, pip-audit Scan, Gitleaks)"
  - "milestone-4-defectdojo.md M4-F4 dedup example replaced with a scanner pair that actually co-occurs (Trivy filesystem + npm audit)"
  - "Zero Grype references remaining in milestone-4-defectdojo.md"
affects: [21-03, future-M4-implementation]

tech-stack:
  added: []
  patterns: ["milestone docs must state DefectDojo parser strings verbatim from dojo/tools/*/parser.py get_scan_types(), not composed/approximated"]

key-files:
  created: []
  modified:
    - docs/milestone-plan/milestone-4-defectdojo.md

key-decisions:
  - "Also corrected the Features summary table row (line 19, 'X scanner parsers' count) even though only line 75/105 were named in the plan's read_first — required by the plan's own whole-file grep -c '5 scanner parsers' -eq 0 acceptance gate, and leaving it stale would have reintroduced the exact doc-internal contradiction this plan exists to remove."

requirements-completed: [DIST-06, DIST-08]

duration: 6min
completed: 2026-09-15
---

# Phase 21 Plan 02: Milestone-4 DefectDojo Parser List Correction Summary

**Corrected milestone-4-defectdojo.md's M4-F3 parser list and M4-F4 dedup example to the live SCA tool set, closing SE-1 and eliminating milestone-2-vs-milestone-4 doc contradiction on the DefectDojo contract.**

## Performance

- **Duration:** ~6 min
- **Tasks:** 2 completed
- **Files modified:** 1 (`docs/milestone-plan/milestone-4-defectdojo.md`)

## Accomplishments

- Line 75 (M4-F3): replaced the stale "5 scanner parsers" list (which named `Anchore Grype`) with the live seven-parser set across five job artifacts: `Semgrep JSON Report`, `Checkov Scan`, `Trivy Scan` (SCA filesystem, plus `NPM Audit v7+ Scan` and `pip-audit Scan` where ecosystem sub-scans fire), `Trivy Scan` (container image), `Gitleaks Scan`.
- Line 19 (Features summary table): dropped the now-inaccurate literal "5 scanner parsers" count that would otherwise still contradict the corrected M4-F3 list.
- Line 105 (M4-F4): replaced the impossible "Trivy and Grype" dedup example (Grype no longer runs in the pipeline) with a pair that genuinely co-occurs — Trivy filesystem scan (`trivy-fs.json`) and npm audit (`npm-audit-<N>.json`) reporting the same CVE for the same npm package.
- Verified milestone-2-cicd-gate.md (landed via sibling plan 21-01, commit `dad6b41`) now names an identical parser set on its own line 85 — the two milestone docs no longer contradict each other on the DefectDojo contract.

## Measured Before/After

- `grep -c -i grype docs/milestone-plan/milestone-4-defectdojo.md`: before = 2 (line 75 `Anchore Grype`, line 105 "Trivy and Grype"), after = 0
- `markdownlint-cli2 docs/milestone-plan/milestone-4-defectdojo.md`: `Summary: 0 error(s)` (baseline preserved, no new violations)

## Task Commits

Each task was committed atomically:

1. **Task 1: Correct the M4-F3 DefectDojo parser list (line 75, plus line 19 summary table)** — `e2d198e` (docs) — originally landed as `78534f5`; the hash changed after this agent observed a sibling history-rewrite event on the shared branch (see Concurrency Event note below). Content re-verified identical at the new hash.
   - **Note:** this content landed folded into sibling plan 21-03's commit `docs(21-03): add SARIF upload limits subsection to adoption guide §6`, not a dedicated 21-02 commit message. See Deviations below for why.
2. **Task 2: Replace the impossible Trivy-vs-Grype deduplication example (line 105)** — `247312c` (docs(21-02): fix impossible Trivy-vs-Grype dedup example in M4-F4), committed with `git commit --only` to guarantee single-file scope.

**Plan metadata:** committed alongside this SUMMARY (see below).

## Files Created/Modified

- `docs/milestone-plan/milestone-4-defectdojo.md` - M4-F3 parser list, Features table parser count, M4-F4 dedup example, all corrected to live SCA tool set

## Decisions Made

- Corrected the line-19 Features-table "5 scanner parsers" count alongside line 75, even though the plan's `<read_first>` and `<action>` for Task 1 named only line 75. The plan's own Task 1 acceptance criterion (`grep -c '5 scanner parsers' -eq 0` against the whole file) fails otherwise — the summary table carried the identical stale count. Treated as Rule 1 (bug fix) since it's the same inaccuracy the task exists to remove, in the same file, directly required by the task's own verification gate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed stale "5 scanner parsers" count in Features summary table (line 19)**
- **Found during:** Task 1
- **Issue:** Line 75's parser list was corrected per plan, but line 19 (Features table, M4-F3 row) carried the same stale numeric count ("5 scanner parsers"), which would have left Task 1's own whole-file acceptance gate (`grep -c '5 scanner parsers' -eq 0`) failing.
- **Fix:** Changed line 19's Components cell from "...API token, 5 scanner parsers" to "...API token, scanner parsers" (dropped the now-inaccurate count rather than recount, since the live set spans a variable-width list depending on which ecosystem sub-scans fire).
- **Files modified:** `docs/milestone-plan/milestone-4-defectdojo.md`
- **Verification:** `grep -c '5 scanner parsers'` returns 0 file-wide; markdownlint still 0 errors.
- **Committed in:** `e2d198e` (originally `78534f5`; see concurrency note below)

### Concurrency Event (not a content defect, documentation deviation only)

This phase runs three sibling plans (21-01, 21-02, 21-03) concurrently in the **same non-worktree git checkout** on branch `feature/phase-12-repo-setup-script` — not isolated worktrees. `git commit` commits the whole index, not just explicitly-named files. Task 1's changes were staged via `git add docs/milestone-plan/milestone-4-defectdojo.md`, but before this agent's own `git commit` ran, the sibling 21-03 agent staged and committed its own file (`docs/adoption-guide.md`) — and because the shared index already contained this agent's staged file, it was swept into that commit (originally hash `78534f5`, message `docs(21-03): add SARIF upload limits subsection to adoption guide §6`). This agent's own commit attempt then found an empty index and failed with exit 1 ("no changes added to commit").

Content is unaffected and verified identical to the plan's specified replacement text (diff inspected directly against the commit). No history rewrite was performed by this agent (shared branch, other agents active, out of scope for auto-fix per destructive-git-prohibition). However, a second observation was made afterward: the commit hash for that same content changed from `78534f5` to `e2d198e` between this agent's Task 1 verification and its final self-check — same commit message, same file content, different SHA — indicating a sibling agent performed some form of history operation (e.g. rebase or amend) on the shared branch after this agent's Task 1 commit landed. This agent did not cause and did not attempt to fix that rewrite; it re-verified file content and lint status at the new hash and updated this SUMMARY's hash references accordingly. Content was confirmed unchanged at both hashes.

Task 2 was committed using `git commit --only <path>` specifically to reduce (not eliminate, given the observed rebase) the risk of a repeat sweep, and `git show --stat HEAD` was checked immediately after to confirm single-file, correctly-attributed scope at commit time.

**Flag for orchestrator:** running multiple GSD executor agents in one shared (non-worktree) checkout makes atomic per-task commit attribution unreliable and commit hashes unstable mid-execution (observed hash churn `78534f5` -> `e2d198e` for identical content, implying a sibling agent rewrote branch history after this agent's commit landed). Concurrent `STATE.md`/`ROADMAP.md` updates from multiple agents risk the same collision, and this agent's own final metadata commit below may also be subject to further hash churn from siblings still running. Recommend isolating concurrent phase-21 sub-plans in separate worktrees, or serializing them, for future multi-plan waves.

---

**Total deviations:** 1 auto-fixed (Rule 1), 1 concurrency/attribution event (no content impact)
**Impact on plan:** Content outcome matches the plan exactly; only the commit message attribution for Task 1 differs from what a dedicated 21-02 commit would have said. No scope creep.

## Issues Encountered

- See Concurrency Event above. Resolved by verifying content equivalence directly in the sibling commit's diff and switching to `git commit --only` for the remaining task.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SE-1 fully closed: milestone-2 and milestone-4 now name the identical live DefectDojo parser set, and no `Anchore Grype` reference remains in milestone-4-defectdojo.md.
- Any future phase-21 plan (e.g., 21-03) that also touches `docs/milestone-plan/` should re-verify current file state on disk before editing, given the concurrency behavior observed here.

---
*Phase: 21-docs-cleanup-close-remaining-phase-20-deferred-items*
*Completed: 2026-09-15*

## Self-Check: PASSED

- FOUND: `docs/milestone-plan/milestone-4-defectdojo.md`
- FOUND: `.planning/phases/21-docs-cleanup-close-remaining-phase-20-deferred-items/21-02-SUMMARY.md`
- FOUND: commit `e2d198e` (Task 1 content, current hash after sibling history event; originally `78534f5`)
- FOUND: commit `247312c` (Task 2, `git commit --only`, single-file scope confirmed)
