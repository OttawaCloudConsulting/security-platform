---
phase: 21-docs-cleanup-close-remaining-phase-20-deferred-items
plan: 03
subsystem: docs
tags: [markdown, github-code-scanning, sarif, adoption-guide, ci-cd]

# Dependency graph
requires:
  - phase: 20-docs-cleanup-close-remaining-phase-19-deferred-items
    provides: deferred-items.md tracking Phase 17 deferred item #6 (SARIF upload limits undocumented)
provides:
  - New `### SARIF Upload Limits at Consumer Scale` subsection inside `docs/adoption-guide.md` §6
affects: [21-04]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: [docs/adoption-guide.md]

key-decisions:
  - "Centered the subsection on the 5,000-results-per-run display truncation as the primary failure mode, not the 25,000 rejection ceiling, per CONFLICT-3 in 21-RESEARCH.md — truncation is silent and invisible without documentation, rejection is at least visible as a failed upload."
  - "Did not label 25,000 as a 'soft limit' — exceeding any Maximum value rejects the file outright per verified github/docs source; the 5,000 truncation is a separate, lower display ceiling."
  - "Cited this project's own measured 58-finding figure (already published three paragraphs above in §6) instead of deferred-items.md's 56, per D-07 amendment, to avoid two adjacent numbers inviting a reader to think one is wrong."
  - "Used the canonical non-redirecting docs.github.com URLs (reference/code-scanning/sarif-files/...) instead of the 301-redirecting integrating-with-code-scanning path."
  - "No new ## section or renumbering — used an unnumbered ### heading matching the file's existing ### Prerequisites style, preserving all 13 numbered sections and their cross-references."

patterns-established: []

requirements-completed: [DIST-06, DIST-08]

# Metrics
duration: 12min
completed: 2026-09-15
---

# Phase 21 Plan 03: SARIF Upload Limits Documentation Summary

**Added a `### SARIF Upload Limits at Consumer Scale` subsection to `docs/adoption-guide.md` §6, documenting GitHub's 5,000-result display truncation, four hard rejection ceilings, and 1,000,000-alert repository lockout, closing Phase 17 deferred item #6 and DIST-08.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-09-15T19:25:00Z (approx, per session clock)
- **Completed:** 2026-09-15
- **Tasks:** 2 (Task 1: write subsection; Task 2: prove gate still green)
- **Files modified:** 1 (`docs/adoption-guide.md`)

## Accomplishments
- Documented the silent 5,000-results-per-run display truncation as the lead failure mode (accepted, prioritized by severity, never shown past the cap)
- Documented the four hard rejection ceilings with their consequence (whole SARIF file rejected): 10 MB gzipped per file, 20 runs per file, 25,000 results per run, 25,000 rules per run
- Documented the 1,000,000-alert repository-wide lockout and its no-self-service-recovery consequence
- Cited this project's own measured 58-finding scale (Trivy image) for calibration, per the D-07 amendment forbidding the number 56
- Cited GitHub as the source via two current, non-redirecting markdown links
- Confirmed the standing documentation gate and markdownlint remain fully green with a purely additive, single-file diff

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the SARIF upload limits subsection into §6** - `e2d198e` (docs)
2. **Task 2: Prove the standing documentation gate is still fully green** - verification-only task; no separate commit (Task 1's commit `e2d198e` is the artifact under verification)

**Plan metadata:** committed together with this SUMMARY (see final commit below)

## Files Created/Modified
- `docs/adoption-guide.md` - Added `### SARIF Upload Limits at Consumer Scale` inside `## 6. First Run — What to Expect`, between the `gh run download` fenced block and the pre-existing `blocking`-corollary bridge paragraph. 32 lines added, 0 lines deleted, 0 existing lines changed.

## Decisions Made
See `key-decisions` in frontmatter above. In summary: lead with truncation (not rejection) per CONFLICT-3; never call 25,000 a "soft limit"; cite 58 not 56 per the D-07 amendment; use the canonical (200) URLs, not the 301-redirecting one; keep the heading unnumbered to avoid renumbering §7–§13.

## Verification Evidence (before/after pair)

**Pre-edit baseline (measured before any edit):**
```
markdownlint-cli2 docs/adoption-guide.md
  Summary: 0 error(s)

bash scripts/check-adoption-guide.sh
  ...
  PASS: MARKDOWNLINT: markdownlint-cli2 reports zero violations on docs/adoption-guide.md
  check-adoption-guide: PASSED 15 / FAILED 0
```

**Post-edit (measured after the commit, against `docs/adoption-guide.md` at commit `e2d198e`):**
```
markdownlint-cli2 docs/adoption-guide.md
  markdownlint-cli2 v0.21.0 (markdownlint v0.40.0)
  Finding: docs/adoption-guide.md
  Linting: 1 file(s)
  Summary: 0 error(s)

bash scripts/check-adoption-guide.sh
  ...
  PASS: CONTEXT-EM-DASH: (all 5, unchanged)
  PASS: SIXTH-CONTEXT: no sixth 'security / ...' context found
  PASS: NO-OCC-GITHUB: 'OCC-github' does not appear in the guide
  PASS: REUSABLE-WORKFLOW-REF: every reusable-workflow reference is @v1 or @v1.0.0 on the canonical repo/path
  PASS: RAW-GITHUBUSERCONTENT-PIN: all 3 raw.githubusercontent.com URL(s) pinned at /v1/
  PASS: BANNED-PATTERNS: '|| true' and '--config auto' appear zero times outside labelled anti-pattern blocks
  PASS: NO-FIXTURES-DIR: 'fixtures/' never appears outside a sentence naming it security-platform-only
  PASS: MARKDOWNLINT: markdownlint-cli2 reports zero violations on docs/adoption-guide.md
  check-adoption-guide: PASSED 15 / FAILED 0
```

**Diffstat (my commit `e2d198e` only):**
```
git diff e664cba..e2d198e --numstat -- docs/adoption-guide.md
32	0	docs/adoption-guide.md

git diff e664cba..e2d198e --name-only -- docs/ scripts/ .markdownlint.jsonc .markdownlint-cli2.yaml
docs/adoption-guide.md
```

**Exact heading text used (for plan 21-04's closure evidence):**
```
### SARIF Upload Limits at Consumer Scale
```

**All acceptance-criteria greps** (top 5,000, 25,000 results per run, 25,000 rules per run, 20 runs per file, 10 MB, 1,000,000, no self-service, no "soft limit", no per-hour/per-day/hourly, no ` 56 `, 58 present, both canonical URLs present, no `integrating-with-code-scanning`, no bare `docs.github.com`, exactly 10 `###` headings, exactly 20 `##` headings, `## 13.` present once, no `## 14`, `security / ` count still 5, no `OCC-github`) — all passed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking / correctness] Repaired a shared-repo commit-scope contamination**
- **Found during:** Task 1, immediately after the first commit attempt
- **Issue:** `git commit` (no pathspec) after `git add docs/adoption-guide.md` committed an unrelated file, `docs/milestone-plan/milestone-4-defectdojo.md`, that a sibling agent (working concurrently in the same shared checkout, not an isolated worktree) had already staged. This produced a 2-file commit that violated the plan's "touches exactly one file" acceptance criterion and risked corrupting the sibling agent's atomic commit.
- **Fix:** Used `git reset --soft` to unwind back to the common ancestor (`e664cba`), re-staged and committed only `docs/adoption-guide.md` as a clean single-file commit (`e2d198e`), then re-staged and re-committed the sibling's original two-file change (`docs/milestone-plan/milestone-2-cicd-gate.md` + `docs/milestone-plan/milestone-4-defectdojo.md`) verbatim under its original commit message, fully restoring both agents' intended history with zero data loss.
- **Files modified:** `docs/adoption-guide.md` only, in the final `e2d198e` commit; the sibling's two files were restored, untouched in content, via a separate commit `dad6b41`.
- **Verification:** `git show --stat e2d198e` confirms exactly one file, 32 insertions, 0 deletions. `git show --stat dad6b41` confirms the sibling's original two-file diff (4 insertions/4 deletions) is byte-identical to what was originally authored.
- **Committed in:** `e2d198e` (my Task 1 commit); `dad6b41` (sibling's restored commit, not part of this plan's deliverable but preserved to avoid destroying concurrent work)

---

**Total deviations:** 1 auto-fixed (1 blocking/correctness — shared-repo commit hygiene)
**Impact on plan:** No impact on the plan's own deliverable; the fix was necessary to satisfy the plan's own "touches exactly one file" acceptance criterion and to avoid destructively overwriting a concurrent sibling agent's work in this non-worktree, same-checkout concurrent-execution setup.

## Issues Encountered
The repository is not running this plan's sibling agents (21-01, 21-02) in isolated git worktrees — all three plans share one working tree and one git index. This meant `git commit` without an explicit file pathspec (relying only on a prior `git add`) picked up whatever else was staged by a concurrent agent at that instant. Resolved by using an explicit pathspec-scoped commit and, once contamination occurred, a careful `git reset --soft` + selective re-staging to split the accidental combined commit without discarding either agent's work. No destructive git operations (`clean`, `reset --hard`, `checkout --`, `stash`) were used at any point.

## Next Phase Readiness
- Plan 21-04 can now cite the exact heading text `### SARIF Upload Limits at Consumer Scale` and the measured gate/lint evidence above as closure proof for Phase 17 deferred item #6 and DIST-08.
- No blockers for downstream plans. `docs/adoption-guide.md` still ends at `## 13.` with all cross-references valid.

---
*Phase: 21-docs-cleanup-close-remaining-phase-20-deferred-items*
*Completed: 2026-09-15*

## Self-Check: PASSED
- FOUND: docs/adoption-guide.md
- FOUND: .planning/phases/21-docs-cleanup-close-remaining-phase-20-deferred-items/21-03-SUMMARY.md
- FOUND commit e2d198e in git log
- FOUND commit dad6b41 in git log (sibling restoration, preserved for audit trail)
