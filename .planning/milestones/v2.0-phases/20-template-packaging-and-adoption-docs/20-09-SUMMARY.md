---
phase: 20-template-packaging-and-adoption-docs
plan: 09
subsystem: docs
tags: [adoption-guide, branch-protection, rulesets, dependabot, gate-mode, markdownlint]

# Dependency graph
requires:
  - phase: 20-08
    provides: "docs/adoption-guide.md sections 1-6 (audience, preflight, mode decision, Mode A, Mode B, first run); the guide gate failing with exactly the five predicted CONTEXT-PRESENCE failures"
  - phase: 20-01
    provides: "Measured private-repo A1 result (run 34802848411, upload-sarif fails with 'Code scanning is not enabled')"
  - phase: 20-04
    provides: "The applied private-repo capability guard verbatim (&& github.event.repository.private == false, six SARIF verify steps)"
provides:
  - "docs/adoption-guide.md sections 7-13 complete: gate-mode selection, the D-07 branch-protection sequence, Dependabot wiring, the SC4 applicability matrix and removal recipe, private-repository documentation, eight troubleshooting subsections, and cross-references (blueprint Phase 2, ADR-016, ADR-017, and a forward reference to adr018 for plan 12)"
  - "scripts/check-adoption-guide.sh now exits 0 (15/15 PASSED) — the guide's own standing gate is green"
affects: [20-10-mode-a-live-pilot-pr, 20-11-mode-b-live-pilot-pr, 20-12-blueprint-and-claude-md-corrections, 20-13-adr018]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Physical-line co-location for the NO-FIXTURES-DIR gate check: any prose sentence naming 'fixtures/' must carry the word 'security-platform' (or 'validation') on the SAME physical (wrapped) markdown line, not just nearby in the paragraph — the gate script checks line-by-line, and markdown's soft-wrap means a multi-sentence paragraph can visually associate the two words while the check still fails on the specific wrapped line containing 'fixtures/' alone"
    - "SIXTH-CONTEXT literal-substring avoidance for illustrative refs: an example `uses:` string like 'OWNER/REPO/.github/workflows/x.yml@v1' collides with the guide gate's REUSABLE-WORKFLOW-REF regex (which accepts only the two canonical @v1/@v1.0.0 refs); rewritten with a placeholder segment containing angle brackets ('<workflow>') that the regex's character class cannot match, preserving the illustration without tripping the gate"

key-files:
  created: []
  modified:
    - docs/adoption-guide.md

key-decisions:
  - "Derived the five byte-exact check-run contexts and their prefix rule directly from the cloned repos/security-platform's scripts/set-required-checks.sh header (which itself states they were read once from the live check-runs endpoint), rather than re-deriving from security.yml/pr-security.yml a second time — both sources agree and the script's header already documents the em-dash provenance and the SHA they were verified against, so citing it avoided retracing ground already covered by that script"
  - "Task 1's edit already left the file gate-clean (bash scripts/check-adoption-guide.sh exited 0 with 13/15 before sections 10-13 existed) — Task 2's own two self-inflicted gate collisions (REUSABLE-WORKFLOW-REF, NO-FIXTURES-DIR) were caught during Task 1's own verification pass and fixed there under Rule 1, so Task 2 introduced its own instance of the identical NO-FIXTURES-DIR class of collision independently and fixed it the same way before committing"
  - "requirements.mark-complete was NOT invoked for DIST-08, per this plan's own <output> instruction — plan 12 owns that closure, consistent with the 17-01/19-01/20-04/20-06/20-07/20-08 precedent"

patterns-established:
  - "Troubleshooting subsections use '### <symptom-phrase>' headings, matching the greppable convention already established in INSTALLATION_GUIDE.md, each followed by exactly three labelled lines: Symptom, Cause, Action"

requirements-completed: []  # Deliberately NOT invoked — DIST-08 is marked complete only by plan 12, per this plan's own <output> instruction.

# Metrics
duration: ~55min
completed: 2026-09-14
---

# Phase 20 Plan 09: Adoption Guide Sections 7-13 (Branch Protection, Dependabot, Applicability, Private Repos, Troubleshooting) Summary

**Completed `docs/adoption-guide.md` (216 to 534 lines): the D-07 branch-protection sequence with all four `set-required-checks.sh` refusal exit codes, the SC4 applicability matrix with its two-warning removal recipe, plan 01's measured private-repo result, and eight troubleshooting subsections — the guide's own standing gate (`scripts/check-adoption-guide.sh`) now exits 0 with 15/15 checks passed.**

## Performance

- **Duration:** ~55 min
- **Started:** 2026-09-14 (after worktree base correction)
- **Completed:** 2026-09-14
- **Tasks:** 2 of 2 completed
- **Files modified:** 1 (`docs/adoption-guide.md`)

## Setup Deviation (before any task)

This worktree's HEAD (`b4cb207`, the Phase 19 gate-mode-proof merge lineage) had no common ancestor
with the plan's expected base `74b1cfdd4e01d3d4effede5509667d01805b96d0` — `git merge-base` returned
exit 1 with no output, the same disjoint-history condition recorded in every prior plan of this
phase (20-01, 20-04, 20-08). Corrected via the sanctioned `git reset --hard
74b1cfdd4e01d3d4effede5509667d01805b96d0` after HEAD/namespace assertions passed (branch
`worktree-agent-ae29a576685a38f22`, matching the `worktree-agent-*` allow-list). Confirmed via
`git rev-parse HEAD` matching exactly and `20-08-PLAN.md`/`20-08-SUMMARY.md` present immediately
after; `git status --short` was clean before the reset (no uncommitted work at risk).

`repos/security-platform` did not exist in this worktree — cloned fresh (read-only, gitignored,
`git clone https://github.com/OttawaCloudConsulting/security-platform.git repos/security-platform`)
per this phase's established pattern (20-01/20-04/20-08). `origin/main` there resolved to `cdf2c21`,
the same commit 20-08 used (post-Phase-20-plan-04/05 merge state), so the clone already carried the
private-repo capability guard and the portability-pass detector inlining this plan's sections rely
on.

## Task 1 — Sections 7-9: gate-mode selection, branch protection, Dependabot wiring

Section 7 states the `gate_mode` enum (`blocking`/`report-only`), the `gh variable set GATE_MODE`
one-command switch with 18-05/19-05's measured proof (identical tree hash, 5 green under
report-only, 5 red under blocking), the fail-closed `case` validation, the severity-agnostic
caveat, and the fork-variables caveat explicitly labelled UNVERIFIED with its single January-2023
forum-post provenance.

Section 8 presents the D-07 sequence as three numbered steps (never as advice), with ADR-017's
correction that step 1 cannot observe red. It gives the `check-runs` command with the five contexts
as its `## Expected:` block (derived, not retyped, sourced from
`repos/security-platform/scripts/set-required-checks.sh`'s own header), states why the check-runs
endpoint is authoritative over the analyses endpoint (case disagreement on two of five tool names),
documents both ruleset paths (existing ruleset read-modify-write vs. the `POST /rulesets` create
path the script does not implement), all four of the script's refusal exit codes (3/4/5/6) framed
as features, the whole-document-`PUT` deletion hazard, the `bypass_actors`-verbatim requirement, the
`rules/branches/main` read-back path (never the classic 404 endpoint), and the self-lockout warning
with the measured `bypass_actors: []` / `current_user_can_bypass: "never"` evidence.

Section 9 states both halves of the local-versus-external Dependabot rule (`./` refs never
proposed; external `@ref`s supported since 2023-03-13), the `directory: "/"` requirement, the
per-mode difference (Mode A ~8 SHAs vs. Mode B one `@v1` ref), and the read-only-token consequence
for Dependabot PRs (SARIF verify steps skip by design, 17-03).

**Verification:** `markdownlint-cli2` — 0 violations. All five targeted greps (`app.id == 15368`,
`rules/branches/main`, `gh variable set GATE_MODE`, `yes-i-understand-lockout`, `2023-03-13`) ≥1.
Python codepoint count of the literal substring `security / ` — exactly 5 (all five contexts, no
sixth). Running the full `bash scripts/check-adoption-guide.sh` at this point (sections 10-13 not
yet written) surfaced two self-inflicted collisions, both fixed under Rule 1 before commit (see
Deviations): `REUSABLE-WORKFLOW-REF` (an illustrative `uses:` string matched the gate's canonical-ref
regex) and `NO-FIXTURES-DIR` (a `fixtures/` mention on a physical line that did not itself carry
`security-platform`/`validation`). After both fixes, the full gate exited 0 with 15/15 PASSED even
before Task 2 added its own content.

## Task 2 — Sections 10-13: applicability matrix, private repositories, troubleshooting, cross-references

Section 10 opens with the Phase-20-portability-pass consequence stated up front — an absent
ecosystem now skips cleanly in both modes, quoting all four byte-exact `SKIP:` strings verbatim
from `repos/security-platform/.github/workflows/security.yml` — then gives Pattern 7's matrix (five
repository types × five jobs) and the removal recipe with both mandatory warnings (ruleset-first;
never-rename).

Section 11 states plan 01's measured result verbatim (run id `34802848411`, the
"Code scanning is not enabled" failure text), plan 04's applied guard expression verbatim
(`&& github.event.repository.private == false`), explicitly states no verify step is deleted, what
a private consumer actually sees today, and the GHAS/User-account limitation with the correct
(not-built) evolution path named.

Section 12 gives eight `### ` troubleshooting subsections — one per pitfall — each with Symptom/
Cause/Action: private-repo SARIF skip, a permanently-pending required check, a ruleset losing rule
types, self-lockout under blocking, frozen action SHAs from a skipped `dependabot.yml`, a
fork/Dependabot PR with no annotations, a false-positive `SKIP:` line from an untracked manifest,
and a red job with a green scan step above it (quoting the verify step's own failure text verbatim).

Section 13 cross-references the blueprint's §Phase 2, ADR-016, ADR-017, and a forward reference to
`docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md` (the exact filename plan 13
will create, read from that plan's own frontmatter so plan 12/13 only has to create the target — no
guessed filename), a four-item validation checklist adapted from `cicd/README.md`'s shape, and the
explicit `fixtures/` non-instruction.

**Verification:** `markdownlint-cli2` — 0 violations. `bash scripts/check-adoption-guide.sh` — exit
0, 15/15 PASSED (all five CONTEXT-PRESENCE, all five CONTEXT-EM-DASH, DERIVE-CONTEXTS, GUIDE-EXISTS,
SIXTH-CONTEXT, NO-OCC-GITHUB, REUSABLE-WORKFLOW-REF, RAW-GITHUBUSERCONTENT-PIN, BANNED-PATTERNS,
NO-FIXTURES-DIR, MARKDOWNLINT). `grep -c "^### "` — 9 (the pre-existing "Prerequisites" heading from
section 2 plus 8 new troubleshooting subsections; ≥8 satisfied). `grep -c "adr018"` — 1. `git status
--porcelain` shows nothing under `repos/` (confirmed gitignored, untouched beyond the read-only
clone). Final guide: 534 lines (well above the plan's 320-line minimum).

## Task Commits

1. **Task 1: Sections 7-9 — gate-mode selection, branch protection, Dependabot wiring** — `0e9df35`
   (`docs(20-09): adoption guide sections 7-9 -- gate mode, branch protection, Dependabot`)
2. **Task 2: Sections 10-13 — applicability matrix, private repositories, troubleshooting,
   cross-references** — `68ce136`
   (`docs(20-09): adoption guide sections 10-13 -- applicability matrix, private repos,
   troubleshooting, cross-refs`)

**Plan metadata:** this SUMMARY is committed separately per the standard `<output>` protocol.

## Files Created/Modified

- `docs/adoption-guide.md` — extended from 216 to 534 lines; sections 7-13 of the adoption guide.

## Decisions Made

See `key-decisions` in frontmatter. Summary: (1) sourced the five byte-exact contexts from
`set-required-checks.sh`'s own header rather than re-deriving a second time from the two workflow
YAMLs, since the script already documents the same provenance; (2) ran the full guide gate at the
end of Task 1 (before Task 2 existed) as an early-warning check, catching and fixing two
self-inflicted gate collisions under Rule 1 before either task commit; (3) withheld
`requirements.mark-complete` for DIST-08 per this plan's explicit `<output>` instruction — plan 12
owns that closure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, self-inflicted gate collision] Illustrative Dependabot `uses:` string matched the guide gate's canonical-reference regex**
- **Found during:** Task 1, full-gate verification pass (run ahead of schedule, before Task 2 existed)
- **Issue:** Section 9's illustrative external-reference example, `uses: OWNER/REPO/.github/workflows/x.yml@v1`, matches `check-adoption-guide.sh`'s `REUSABLE-WORKFLOW-REF` regex, which only accepts the two canonical refs (`OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1` or `@v1.0.0`). The illustrative string is not itself a real reusable-workflow reference this project ships, but the regex cannot distinguish "example" from "real."
- **Fix:** Reworded the placeholder segment from a bare `x` to `<workflow>` (angle brackets), which the regex's `[A-Za-z0-9_.-]+` character class cannot match, breaking the false match while preserving the illustration.
- **Files modified:** `docs/adoption-guide.md`
- **Verification:** `bash scripts/check-adoption-guide.sh` — `REUSABLE-WORKFLOW-REF` now PASSES.
- **Committed in:** `0e9df35` (fixed before the Task 1 commit, not as a follow-up)

**2. [Rule 1 - Bug, self-inflicted gate collision] A `fixtures/` mention's context-word was on the wrong physical line (twice, in two different sections)**
- **Found during:** Task 1 (section 8's self-lockout warning) and again independently in Task 2 (section 13's non-instruction), both during their respective full-gate verification passes
- **Issue:** `check-adoption-guide.sh`'s `NO-FIXTURES-DIR` check evaluates one physical (wrapped) markdown line at a time; a prose sentence spanning two wrapped lines can visually associate "fixtures/" with "security-platform" for a human reader while the specific line containing "fixtures/" carries neither word, failing the check even though the paragraph as a whole is accurate and unambiguous.
- **Fix:** In both places, reworded the sentence so the word "security-platform" (or "validation") appears on the identical physical line as "fixtures/" — e.g., "`security-platform`'s validation-only `fixtures/` tree" instead of a sentence structure that separated the two across a line wrap.
- **Files modified:** `docs/adoption-guide.md`
- **Verification:** `bash scripts/check-adoption-guide.sh` — `NO-FIXTURES-DIR` PASSES in both commits.
- **Committed in:** `0e9df35` (section 8 instance) and `68ce136` (section 13 instance), each fixed before its own commit.

---

**Total deviations:** 3 (all self-caught wording fixes before commit, same category as 20-08's two
prior fixes of this kind — self-referential grep/regex collisions between the guide's own
required prose and the guide gate script's assertions).
**Impact on plan:** All three deviations were wording-only and necessary to satisfy the guide's own
standing gate without weakening or removing any explanatory content. No scope creep — only
`docs/adoption-guide.md` was modified.

## Issues Encountered

- The worktree's initial HEAD was on the same disjoint-history condition every prior plan in this
  phase has hit (`git merge-base` exit 1, no common ancestor). Resolved via the sanctioned
  `git reset --hard` after HEAD/namespace assertions passed; documented above under Setup Deviation.
- Several compound Bash commands (variable-driven `python3 -c` invocations, a `cd repos/... && git
  -C ...` compound, and one command containing the string "not to be git" in its own description)
  were rejected by the worktree-isolation guard as "too complex to verify" or "names git in a form
  too complex to verify." Resolved by using the `Read` tool directly against absolute paths inside
  the worktree for file inspection, and splitting any remaining Bash invocations into single-purpose
  commands — consistent with every prior plan in this phase.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `docs/adoption-guide.md` is complete (sections 1-13), markdownlint-clean, 534 lines, and its own
  standing gate (`scripts/check-adoption-guide.sh`) exits 0 with 15/15 checks passed.
- Plan 10 (Mode A live pilot PR) and plan 11 (Mode B live pilot PR) can execute every command in
  sections 4/5/6/7/8/9 of this guide verbatim, including the `gh variable set GATE_MODE`,
  `gh api .../check-runs`, and `bash scripts/set-required-checks.sh` invocations.
- Section 13 already names and links `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md`
  by its exact filename — plan 12/13 only needs to create that file at the path already referenced
  here; no filename reconciliation needed downstream.
- `requirements.mark-complete` deliberately NOT invoked for DIST-08 — plan 12 owns that closure per
  the 17-01/19-01/20-04/20-06/20-07/20-08 precedent already recorded in STATE.md.

## Self-Check: PASSED

- `docs/adoption-guide.md` — FOUND, 534 lines
- Commit `0e9df35` — FOUND in `git log --oneline`
- Commit `68ce136` — FOUND in `git log --oneline`
- `markdownlint-cli2 docs/adoption-guide.md` — 0 violations, confirmed after both task commits
- `bash scripts/check-adoption-guide.sh` — exit 0, 15/15 PASSED, confirmed after Task 2's commit
- `grep -c "^### "` — 9 (≥8 required)
- `grep -c "adr018"` — 1 (≥1 required)
- `git status --porcelain` — clean except this SUMMARY file at write time; nothing under `repos/`
- `repos/security-platform` — confirmed gitignored (`.gitignore` contains `repos/`), untouched by
  this plan beyond the read-only clone

---
*Phase: 20-template-packaging-and-adoption-docs*
*Completed: 2026-09-14*
