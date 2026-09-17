---
phase: 21-docs-cleanup-close-remaining-phase-20-deferred-items
plan: 01
subsystem: docs
tags: [milestone-plan, security.yml, trivy, defectdojo, markdownlint]

requires:
  - phase: 17
    provides: deferred item #4 (Grype references in milestone-2-cicd-gate.md left stale after Grype removal)
  - phase: 20
    provides: ground-truth findings that milestone doc still named Grype and wrong JSON filenames
provides:
  - milestone-2-cicd-gate.md reconciled to the live security.yml (5 jobs, real artifact filenames)
  - DefectDojo parser row naming real, job-qualified parser strings
affects: [milestone-plan, adoption-guide]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - docs/milestone-plan/milestone-2-cicd-gate.md

key-decisions:
  - "Amended D-03: sca-results is an artifact name, not a filename — never write sca-results.json; the SCA job's real JSON outputs are trivy-fs.json, npm-audit-<N>.json, pip-audit-<N>.json"
  - "Amended D-04: both Trivy Scan DefectDojo parser slots qualified with parenthetical (SCA filesystem vs. container image) rather than left as a bare duplicated string"
  - "L78 second filename fix approved in scope: trivy-results.json corrected to trivy-image.json"
  - "Anchore Grype remains a valid DefectDojo parser in general — the fix removes it because the pipeline no longer produces input for it, not because the parser itself is wrong"

patterns-established: []

requirements-completed: [DIST-06, DIST-08]

duration: 3min
completed: 2026-09-15
---

# Phase 21 Plan 01: Reconcile milestone-2-cicd-gate.md to live security.yml Summary

**Removed all five Grype references from docs/milestone-plan/milestone-2-cicd-gate.md and corrected the M2-F3 JSON filename list and DefectDojo parser row to match the live security.yml (5 jobs: sast, iac, sca, container, secrets).**

## Performance

- **Duration:** 3 min
- **Started:** 2026-09-15T19:27:00Z
- **Completed:** 2026-09-15T19:30:08Z
- **Tasks:** 2 completed
- **Files modified:** 1

## Accomplishments

- M2-F1 feature table cell, the Grype/Trivy bullet pair, and the vulnerable-dependency done-criteria bullet now name only live scanners (Semgrep CE, Checkov, Trivy filesystem + npm audit/pip-audit/tflint, Trivy image, Gitleaks)
- M2-F3's JSON output line now lists the five real filenames the workflow writes: `semgrep-results.json`, `checkov-results.json`, `trivy-fs.json` (+ `npm-audit-<N>.json` / `pip-audit-<N>.json` where those sub-scans fire), `trivy-image.json`, `gitleaks-results.json`
- M2-F3's DefectDojo parser row replaces `Anchore Grype` and the bare `Trivy Scan` with job-qualified parsers: `Trivy Scan (SCA filesystem — plus NPM Audit v7+ Scan and pip-audit Scan ...)`, `Trivy Scan (container image)`
- `grep -c -i grype docs/milestone-plan/milestone-2-cicd-gate.md`: measured 5 at pre-plan commit `cdf3a53`, 0 at current HEAD `354cd52` (both measured via `git show <rev>:<path> | grep`, not inferred)
- `markdownlint-cli2`: `Summary: 0 error(s)` measured against both the pre-plan revision (`git show cdf3a53:...` piped to a scratch file) and the current file at HEAD (baseline preserved)

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace the three Grype prose sites in M2-F1 and disambiguate the Trivy image bullet** - `e664cba` (docs)
2. **Task 2: Correct the M2-F3 JSON filename list and DefectDojo parser row** - originally committed as `625a1c9`, later dropped from branch history by a concurrent process's `git reset` (see Issues Encountered). The identical content was re-created by a concurrent process as `dad6b41`, which also bundles an unrelated `docs/milestone-plan/milestone-4-defectdojo.md` edit that belongs to plan 21-02 (attribution correction below). Task 2's content is verified present and correct at current HEAD (`354cd52`, see verification commands below).

**No final plan-metadata commit (STATE.md/ROADMAP.md/REQUIREMENTS.md) was made for this plan.** This checkout is shared, unisolated, across at least three concurrently-running Phase 21 executor agents (21-01, 21-02, 21-03 observed in the same branch's reflog within minutes of each other). Running `state.advance-plan` / `roadmap.update-plan-progress` / `requirements.mark-complete` here risks double-advancing or blending state with the other agents' concurrent runs. State updates are deferred to a checkpoint — see the executor's final message for details.

## Files Created/Modified

- `docs/milestone-plan/milestone-2-cicd-gate.md` - Grype removed from M2-F1 prose (feature table, scanner bullets, done-criteria bullet); M2-F3 JSON filename list and DefectDojo parser row corrected to the live security.yml's five jobs and real artifact filenames

## Decisions Made

- `sca-results.json` does not exist and was never written; `sca-results` is only the `actions/upload-artifact` artifact name on the SCA job. The SCA job's real JSON outputs are `trivy-fs.json`, `npm-audit-<N>.json`, `pip-audit-<N>.json` (tflint emits SARIF only, contributing no JSON).
- Both `Trivy Scan` occurrences in the DefectDojo parser row are now job-qualified (`(SCA filesystem — ...)` / `(container image)`) to avoid a bare copy-paste-looking duplicate on one line.
- `trivy-results.json` (the container job's wrong filename) corrected to `trivy-image.json` in the same pass as the SCA filename fix, per the plan's approved L78 scope.
- `Anchore Grype` is documented in the SUMMARY as still a legitimate DefectDojo parser in general — this plan removed it from the doc because the live pipeline no longer produces input for that parser (Grype was removed from the pipeline in Phases 15/16), not because the parser name itself was ever wrong.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' Edit-tool replacements matched the plan's specified old/new strings verbatim; all acceptance criteria and the plan-level verification block passed on the first attempt.

## Issues Encountered

**This checkout is shared and unisolated across multiple concurrently-running Phase 21 executor agents.** This is an environment condition, not a plan defect, but it materially affected commit history for this plan and must be reported.

Evidence (branch `feature/phase-12-repo-setup-script`, reflog):

1. Task 1 committed cleanly as `e664cba`.
2. Task 2 committed cleanly as `625a1c9` — verified present via `git log --oneline -1` immediately after the commit.
3. Before this plan's SUMMARY/state-update work began, `git log --oneline -1` showed `78534f5 docs(21-03): add SARIF upload limits subsection to adoption guide §6` at HEAD, with `625a1c9` no longer reachable. Reflog confirmed: `78534f5 HEAD@{0}: reset: moving to HEAD~1` — a `git reset` (not authored by this executor) moved HEAD back one commit on the shared branch, dropping `625a1c9` from history. Working-tree content survived (the reset preserved file contents), so no data was lost, only the commit object's reachability.
4. This executor re-staged and attempted to re-commit the identical Task 2 content. The first attempt failed with a bash heredoc parse error (backticks inside the message body were evaluated as command substitution by the outer double-quoted `-m "$(...)"` construct — a scripting bug in this executor's own command, not an environment issue). Before a corrected retry could run, a concurrent process created `dad6b41`, byte-identical in message body to this executor's originally-composed Task 2 message, but bundling an additional 4-line edit to `docs/milestone-plan/milestone-4-defectdojo.md` that this executor never authored and that belongs to plan 21-02's scope (confirmed via `grep -l milestone-4 .planning/phases/21-*/21-0*-PLAN.md` → `21-02-PLAN.md`, `21-04-PLAN.md`). This executor did not create `dad6b41` and does not know the exact mechanism (most likely another agent staged its own file, then reused this plan's already-staged content and/or commit message via `-C`/`--reuse-message`).
5. Plan 21-02's executor continued on top of `dad6b41` with two further commits (`247312c`, `354cd52`), so the bundled milestone-4 edit was not lost or orphaned — it became the starting point for 21-02's own subsequent work. No destructive action (revert, reset, amend) was taken on `dad6b41` by this executor, per the project's prohibition on rewriting history that isn't this executor's to rewrite.
6. Task 2's actual content (this plan's sole concern, `docs/milestone-plan/milestone-2-cicd-gate.md`) was verified present and correct at current HEAD `354cd52` via `git show HEAD:docs/milestone-plan/milestone-2-cicd-gate.md | grep`, independent of which commit object introduced it.

**Net effect on this plan's deliverable: none.** Both tasks' content is durably present at HEAD and independently verified. The effect is entirely on commit-history cleanliness and attribution (Task 2's content is not cleanly isolated in its own commit under this plan's authorship) and on this executor's ability to safely perform shared-state updates (STATE.md/ROADMAP.md/REQUIREMENTS.md) without risking collision with the other active agents.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The doc-level goal is met: DIST-06 and DIST-08's described end state (grype absent, real filenames present, lint clean) is verifiably true at current HEAD. The milestone-2 doc no longer contradicts M2-F4 (line ~92), which already named `SCA — Trivy Filesystem` correctly.
- **Blocker for this plan's own completion bookkeeping:** requirement mark-complete and STATE/ROADMAP updates were deliberately withheld (see Issues Encountered) because this checkout is shared, unisolated, with other Phase 21 agents actively committing/resetting at the same time. A human or orchestrator should confirm the other Phase 21 agents (21-02 confirmed complete at `354cd52`; 21-03, 21-04 status unknown from this executor's vantage point) have finished before anyone runs `state.advance-plan` / `roadmap.update-plan-progress` / `requirements.mark-complete` for 21-01, to avoid colliding with a concurrent agent's own state writes.
- No blocker on the document content itself for subsequent Phase 21 plans.

## Self-Check: PASSED

- `docs/milestone-plan/milestone-2-cicd-gate.md` exists: FOUND
- `.planning/phases/21-docs-cleanup-close-remaining-phase-20-deferred-items/21-01-SUMMARY.md` exists: FOUND
- Commit `e664cba` (Task 1): FOUND in `git log --oneline --all`
- Commit `625a1c9` (Task 2, original): confirmed created, then confirmed no longer reachable from HEAD after a concurrent `git reset` (see Issues Encountered) — this is disclosed, not hidden
- Task 2's content verified present and correct at current HEAD `354cd52` via `git show HEAD:docs/milestone-plan/milestone-2-cicd-gate.md | grep -c -i grype` → `0`, plus `trivy-fs.json`, `trivy-image.json`, and `Trivy Scan (container image)` all present in that same revision
- Pre-plan baseline independently measured (not inferred) at `cdf3a53`: `grype` count 5, markdownlint 0 errors

---
*Phase: 21-docs-cleanup-close-remaining-phase-20-deferred-items*
*Completed: 2026-09-15*
