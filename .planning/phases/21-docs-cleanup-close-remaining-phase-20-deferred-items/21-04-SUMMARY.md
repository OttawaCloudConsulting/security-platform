---
phase: 21-docs-cleanup-close-remaining-phase-20-deferred-items
plan: 04
subsystem: docs
tags: [deferred-items, tracking, sarif, defectdojo, grype-removal, verification-suite]

requires:
  - phase: 21-01
    provides: "milestone-2-cicd-gate.md reconciled to live security.yml (item #4 closure evidence)"
  - phase: 21-02
    provides: "milestone-4-defectdojo.md parser list corrected (SE-1 closure evidence)"
  - phase: 21-03
    provides: "SARIF Upload Limits at Consumer Scale subsection in adoption-guide.md (item #6 closure evidence)"
provides:
  - "Phase 17 deferred-items.md status re-check section closing items #4, #6 and SE-1 with reproducible grep evidence"
  - "Full-suite verification confirming all three phase-edited documents are lint-clean and gate-passing"
affects: []

tech-stack:
  added: []
  patterns: ["append-only status re-check sections in deferred-items.md, following the Phase 20.1 precedent"]

key-files:
  created: []
  modified:
    - .planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md
    - docs/adoption-guide.md

key-decisions:
  - "Paraphrased rather than quoted the 2026-09-14 entry's inaccurate 'all 5 filenames diverge' claim, to avoid the correction being mistaken for a duplicate of the original row (only grype-results.json and trivy-results.json actually diverged; 3 of 5 matched live)"
  - "Did not cite commit hashes for item #4/#6/SE-1 evidence — sibling plans 21-01/21-02/21-03's SUMMARYs record conflicting hashes for the same content due to a shared-checkout history-rewrite event during their concurrent execution; grep-based reproducible evidence is unambiguous regardless of which commit introduced it"
  - "[Rule 3 - blocking] Fixed a line-wrap defect in docs/adoption-guide.md discovered during Task 2's full-suite verification: the phrase '25,000 results per run' was split across a hard line break, failing this plan's own literal grep -qF acceptance check. Reflowed only the line-break position, not the wording."

requirements-completed: [DIST-06, DIST-08]

duration: 18min
completed: 2026-09-15
---

# Phase 21 Plan 04: Close Phase 17 Deferred Items #4, #6 (Status Re-check) Summary

**Appended a Phase 21 status re-check section to Phase 17's deferred-items.md closing items #4, #6 and SE-1 with reproducible grep evidence, corrected an inaccurate 2026-09-14 claim about item #4, and ran the full phase verification suite across all three documents this phase edited — all green.**

## Performance

- **Duration:** ~18 min
- **Tasks:** 2 completed
- **Files modified:** 2 (`deferred-items.md`, plus a Task-2-discovered fix in `docs/adoption-guide.md`)

## Accomplishments

- Appended `## Status re-check 2026-09-15 (Phase 21)` to `.planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md`, purely additive (19 insertions, 0 deletions) — every earlier row, including the 2026-09-14 section, left byte-unchanged
- Closed item #4 (milestone-2 Grype/filename drift): `grep -c -i grype docs/milestone-plan/milestone-2-cicd-gate.md` returns `0`
- Closed item #6 (SARIF upload limits undocumented): `docs/adoption-guide.md` §6 carries `### SARIF Upload Limits at Consumer Scale`; `bash scripts/check-adoption-guide.sh` reports `PASSED 15 / FAILED 0`
- Closed SE-1 (milestone-4 parser list, closed in-phase under 21-02, not a new deferred item): `grep -c -i grype docs/milestone-plan/milestone-4-defectdojo.md` returns `0`
- Corrected the 2026-09-14 entry's inaccurate claim that L78 named "5 filenames that all diverge from the live artifact names" — only `grype-results.json` and `trivy-results.json` actually diverged; `semgrep-results.json`, `checkov-results.json` and `gitleaks-results.json` matched live exactly. The correction is stated in the new section without editing or quoting the earlier row verbatim.
- Re-confirmed item #7 (checkout `# v4` comments) as closed by Phase 20.1 and dropped from Phase 21 scope by user decision, and re-confirmed item #2 (blueprint Grype SCA example) as still OPEN and out of scope
- Ran the full phase verification suite (six steps) across `milestone-2-cicd-gate.md`, `milestone-4-defectdojo.md` and `adoption-guide.md` — all passed
- **[Rule 3 auto-fix]** Discovered and fixed a line-wrap defect in `docs/adoption-guide.md` (introduced by sibling plan 21-03) where "25,000 results per run" was split across a hard line break, causing this plan's own literal-string verification to fail; reflowed the line break only, wording unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Append the Phase 21 status re-check section to deferred-items.md** — `65344c4` (docs(21-04): close Phase 17 deferred items #4, #6, SE-1)
2. **Task 2: Run the full phase verification suite and record the measured output** — no separate commit expected per plan (verification-only); the one fix discovered during this step landed as `9372257` (fix(21-04): rewrap SARIF limits paragraph so '25,000 results per run' is contiguous)

## Files Created/Modified

- `.planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md` — appended `## Status re-check 2026-09-15 (Phase 21)` section
- `docs/adoption-guide.md` — reflowed one paragraph's line-break position (no wording change) to fix a verification-blocking line-wrap defect

## Measured Verification Suite Output (Task 2, all six steps)

1. `grep -c -i grype docs/milestone-plan/milestone-2-cicd-gate.md` → `0`
2. `grep -c -i grype docs/milestone-plan/milestone-4-defectdojo.md` → `0`
3. `markdownlint-cli2 docs/milestone-plan/milestone-2-cicd-gate.md docs/milestone-plan/milestone-4-defectdojo.md docs/adoption-guide.md` → `Summary: 0 error(s)` (3 files), exit 0
4. `bash scripts/check-adoption-guide.sh` → `check-adoption-guide: PASSED 15 / FAILED 0`, exit 0
5. Content assertions on `docs/adoption-guide.md`: `top 5,000`, `25,000 results per run`, `25,000 rules per run`, `20 runs per file`, `10 MB`, `1,000,000` all present; `integrating-with-code-scanning` (0 hits) and `sca-results.json` (0 hits across all three edited files) both absent; `soft limit` appears once, in the sentence explicitly stating "None of these is a soft limit" (a negation, not a mislabel — this is the correct, intentional usage and was not flagged as a violation)
6. `git status --porcelain` scoped to `docs/ scripts/ .planning/phases/17-sarif-upload-and-artifact-retention .planning/phases/21-docs-cleanup-close-remaining-phase-20-deferred-items` → clean at the end of the plan (both this plan's commits landed). Collateral-damage check confirmed `scripts/check-adoption-guide.sh`, `.markdownlint.jsonc`, `.markdownlint-cli2.yaml`, `docs/development-security-stack-option-1.md`, `docs/milestone-plan/milestone-1-workstation.md`, `docs/milestone-1-workstation/*` and `docs/adr/*` all unmodified. M1 workstation Grype references confirmed still intact: `grep -rc -i grype docs/milestone-1-workstation/` shows 3 files with hits (unchanged, intentional — Grype is a genuinely installed workstation tool there).

## Decisions Made

- Paraphrased (never quoted) the 2026-09-14 entry's inaccurate "5 filenames that all diverge" claim in the new section, so the correction cannot be mistaken for a second copy of the original row — matches the plan's explicit instruction.
- Omitted commit hashes from the new section's evidence rows. 21-01/21-02/21-03's SUMMARYs record contradictory hashes for the same content (a shared, non-worktree checkout with three concurrently-running executor agents produced observed history churn — see those SUMMARYs' "Concurrency Event" sections). Grep-based, reproducible evidence sidesteps the ambiguity entirely and matches the plan's own evidence style (`grep -c -i grype` commands, not hash citations).
- Treated the adoption-guide.md line-wrap fix as Rule 3 (auto-fix blocking issue), not Rule 4 (architectural) or an out-of-scope deferral: it directly blocked this plan's own Task 2 verification gate, the fix is a two-line reflow with zero wording change, and it does not touch any gate script, lint config, or summary file (the explicit prohibitions in the plan's failure-handling instructions).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed line-wrap defect in docs/adoption-guide.md splitting "25,000 results per run" across a line break**
- **Found during:** Task 2, content-assertion step (step 5)
- **Issue:** The phrase "25,000 results per run" (added by sibling plan 21-03) was hard-wrapped across lines 269–270 of `docs/adoption-guide.md`, so this plan's own `grep -qF '25,000 results per run'` acceptance check failed even though the semantic content (which renders as one continuous sentence in HTML) was always correct.
- **Fix:** Moved the line-break position within the same paragraph so the phrase reads on one line. No wording changed.
- **Files modified:** `docs/adoption-guide.md`
- **Verification:** `grep -qF '25,000 results per run' docs/adoption-guide.md` now passes; `markdownlint-cli2` still reports 0 errors; `bash scripts/check-adoption-guide.sh` still reports `PASSED 15 / FAILED 0`.
- **Committed in:** `9372257`

---

**Total deviations:** 1 auto-fixed (Rule 3)
**Impact on plan:** No impact on this plan's own deliverable (the `deferred-items.md` closure). The fix was necessary and sufficient to make Task 2's own verification gate pass; it does not touch the gate script or any lint config, per the plan's explicit prohibition.

## Issues Encountered

None beyond the Rule 3 fix documented above. No sibling agents were running concurrently during this plan's execution (Wave 1 plans 21-01/21-02/21-03 had already landed and the working tree was clean at the start), so none of the shared-checkout history-churn behavior observed in 21-01/21-02/21-03's SUMMARYs recurred here.

## Note for the Verifier

`.planning/ROADMAP.md`'s Phase 21 goal sentence still names "7 stale `# v4` action-version comments in the blueprint" as in-scope work. That item was closed earlier by Phase 20.1 (all 7 `actions/checkout` comments already corrected to `# v7`) and was explicitly dropped from Phase 21's scope by the user (per `21-CONTEXT.md` `<domain>`). It is not an unfixed gap — the roadmap goal sentence itself was intentionally left unedited by this plan (out of scope per the plan's own instructions), not missed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 17's `deferred-items.md` now accurately reflects live repository state for items #4, #6 and SE-1 (all CLOSED), with #2 and #3 (plus the broken relative ADR links) correctly recorded as still OPEN.
- All four Phase 21 plans (21-01 through 21-04) are complete. Phase 21's stated goal — closing the remaining Phase 20 deferred items via documentation-only edits — is achieved.

---
*Phase: 21-docs-cleanup-close-remaining-phase-20-deferred-items*
*Completed: 2026-09-15*

## Self-Check: PASSED

- FOUND: `.planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md`
- FOUND: `docs/adoption-guide.md`
- FOUND: commit `65344c4` in `git log --oneline --all`
- FOUND: commit `9372257` in `git log --oneline --all`
- Verified `grep -qF '25,000 results per run' docs/adoption-guide.md` passes at current HEAD
- Verified `bash scripts/check-adoption-guide.sh` reports `PASSED 15 / FAILED 0` at current HEAD
