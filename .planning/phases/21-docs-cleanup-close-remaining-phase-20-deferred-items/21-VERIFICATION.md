---
phase: 21-docs-cleanup-close-remaining-phase-20-deferred-items
verified: 2026-09-17T00:00:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
---

# Phase 21: Docs cleanup — close remaining Phase 20 deferred items Verification Report

**Phase Goal (ROADMAP.md):** Fix the three Phase 20 deferred doc items never picked up: stale Grype
reference in `docs/milestone-plan/milestone-2-cicd-gate.md` (L78), missing SARIF size/result ceiling
documentation in `docs/adoption-guide.md`, and 7 stale `# v4` action-version comments in the blueprint.
**Requirements:** DIST-06, DIST-08
**Verified:** 2026-09-17 (retroactive; live repo state re-read this session, ~2 days after Phase 21 closed
2026-09-15)
**Status:** passed
**Re-verification:** No — initial verification (retroactive)

## Method

`.planning/ROADMAP.md`'s Phase 21 entry carries a `Goal:` sentence and `Requirements:` line but **no
`success_criteria` array** (unlike Phase 20.1's entry, which does). Per the parent task's instruction, this
report scores against the four completed plans' (21-01 through 21-04) own delivered acceptance criteria —
not against the full, partly-stale ROADMAP goal sentence — because that sentence's third clause (the "7
stale `# v4`" item) was already closed by Phase 20.1 before Phase 21 ran, and the user explicitly dropped it
from Phase 21's scope (recorded in `21-CONTEXT.md` and re-confirmed in `21-04-SUMMARY.md`'s "Note for the
Verifier"). Re-litigating a sentence the user already narrowed would misattribute an already-closed,
out-of-scope item as a Phase 21 gap.

This report does not trust SUMMARY.md narrative. Every claim below was independently re-run live in this
session — `grep`, `markdownlint-cli2`, `bash scripts/check-adoption-guide.sh`, and `git show --stat` against
current HEAD and named commits — not copied from the SUMMARYs' own "Verification Evidence" sections. Where a
SUMMARY's self-report did *not* reproduce under independent live re-grep (21-03's claim that all its
acceptance-criteria greps passed), that discrepancy is surfaced explicitly below rather than silently
accepted, consistent with this phase's own internal practice (21-04 caught and fixed the same discrepancy
before this report was written — see Gaps Summary).

**Read-only scope:** no destructive git operations were run. Only `grep`, `markdownlint-cli2`, `bash
scripts/check-adoption-guide.sh`, `git show --stat`, `git log`, `git status --porcelain`, and file reads were
used.

## Goal Achievement

### Observable Truths (derived from the 4 plans' delivered acceptance criteria)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | `docs/milestone-plan/milestone-2-cicd-gate.md` no longer references Grype anywhere, and its M2-F3 JSON filename list / DefectDojo parser row match the live `security.yml`'s five jobs (21-01) | ✓ VERIFIED | Live this session: `grep -c -i grype docs/milestone-plan/milestone-2-cicd-gate.md` → `0`. Positive check: line 78 lists `trivy-fs.json`, `trivy-image.json`; line 85 names `Trivy Scan (container image)` explicitly (job-qualified, not a bare duplicate). `grep -c 'sca-results.json'` → `0` (the non-existent artifact-vs-filename confusion the plan fixed is gone). `markdownlint-cli2 docs/milestone-plan/milestone-2-cicd-gate.md` → `Summary: 0 error(s)` (re-run live; not previously independently confirmed — 21-01-SUMMARY asserted this but did not reproduce it in this session's terms). |
| 2 | `docs/milestone-plan/milestone-4-defectdojo.md` (SE-1, user-approved scope addition) no longer references Grype, and its parser list/dedup example match the live SCA tool set (21-02) | ✓ VERIFIED | Live this session: `grep -c -i grype docs/milestone-plan/milestone-4-defectdojo.md` → `0`. `grep -c '5 scanner parsers'` → `0` (the stale numeric count 21-02 found and fixed alongside its named line-75 target is confirmed gone file-wide). `markdownlint-cli2` on this file → `Summary: 0 error(s)` (re-run live, both milestone docs linted together, 0 errors for 2 files). |
| 3 | `docs/adoption-guide.md` §6 documents the SARIF upload/display ceilings (5,000 display truncation, 10 MB/20 runs/25,000 results/25,000 rules rejection ceilings, 1,000,000-alert lockout) (21-03) | ✓ VERIFIED | Live this session: `### SARIF Upload Limits at Consumer Scale` present at line 259. All five numeric ceilings present and readable as contiguous phrases: `top 5,000 results` (line 262), `10 MB`, `20 runs per file`, `25,000 results per run`, `25,000 rules per run` (lines 269-270, confirmed **not** split across a line-wrap — see Gaps Summary for why this needed a second live check), `1,000,000` alert lockout with `no self-service` recovery (lines 274-276). Negative check: `grep -c -i "soft limit" docs/adoption-guide.md` → `0` (confirmed reworded, not merely negated-but-still-matching — see Gaps Summary). |
| 4 | The standing documentation gate (`scripts/check-adoption-guide.sh`, Phase 21's own regression gate per 21-03/21-04) passes with 0 failures against the edited `adoption-guide.md` (21-03, 21-04) | ✓ VERIFIED | Live this session: `bash scripts/check-adoption-guide.sh` → `check-adoption-guide: PASSED 15 / FAILED 0`, exit 0. All 15 named sub-checks (`DERIVE-CONTEXTS`, `CONTEXT-EM-DASH` ×5, `CONTEXT-PRESENCE`, `SIXTH-CONTEXT`, `NO-OCC-GITHUB`, `REUSABLE-WORKFLOW-REF`, `RAW-GITHUBUSERCONTENT-PIN`, `BANNED-PATTERNS`, `NO-FIXTURES-DIR`, `MARKDOWNLINT`) reported `PASS`. |
| 5 | Phase 17's `deferred-items.md` accurately records items #4 and #6 (plus SE-1) as CLOSED with reproducible evidence, and item #7 is correctly attributed to Phase 20.1 rather than Phase 21 (21-04) | ✓ VERIFIED | Live this session: `## Status re-check 2026-09-15 (Phase 21)` section present in `.planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md`; its table marks #4 CLOSED, #6 CLOSED, SE-1 CLOSED, #7 "CLOSED by Phase 20.1 — re-confirmed, dropped from Phase 21 scope", #2 OPEN. Independently re-confirmed item #7's underlying claim live: `grep -n '# v4' docs/development-security-stack-option-1.md` → exactly 3 hits, all three on `github/codeql-action/upload-sarif` (lines 1548, 1572, 1619) — zero on `actions/checkout`, matching the deferred-items.md claim exactly. Independently re-confirmed item #2 is still open: `grep -n -i grype docs/development-security-stack-option-1.md` → 30+ hits, including the still-present `### 4. Syft + Grype` SCA section (line 304) and its `sca:` job example (line 1582 `name: SCA — Grype`) — the blueprint was never touched by any Phase 21 plan, confirming #2's OPEN status is accurate, not an oversight. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `docs/milestone-plan/milestone-2-cicd-gate.md` | Grype-free, real filenames/parsers | ✓ VERIFIED | `grype` count 0, lint 0 errors, positive filename/parser checks pass |
| `docs/milestone-plan/milestone-4-defectdojo.md` | Grype-free, corrected parser list/dedup example | ✓ VERIFIED | `grype` count 0, `5 scanner parsers` count 0, lint 0 errors |
| `docs/adoption-guide.md` §6 | New SARIF limits subsection | ✓ VERIFIED | Heading present, all 5 ceilings documented, gate passes 15/15 |
| `.planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md` | Phase 21 status re-check section | ✓ VERIFIED | Section present, items #4/#6/SE-1 marked CLOSED with grep-reproducible evidence |
| `.planning/REQUIREMENTS.md` DIST-06/DIST-08 | Marked complete | ✓ VERIFIED (pre-existing) | Live grep this session: line 26 `[x] **DIST-06**`, line 28 `[x] **DIST-08**`, traceability rows 70/72 both `Complete`. Per the parent task's instruction, this status is **not re-derived** here — `20-VERIFICATION.md` (lines 76, 78) already independently satisfied both requirements in Phase 20, citing 20-04/20-05/20-08/20-09/20-12/20-13. 21-01 through 21-04's frontmatter each idempotently re-list `requirements-completed: [DIST-06, DIST-08]`, which is consistent re-affirmation of an already-satisfied requirement, not a new/conflicting claim. |

### Key Link Verification

Not applicable in the code-wiring sense — this is a documentation-only phase with no component/API/data
links to trace. The equivalent "links" are grep-evidence-to-live-file-state pairs, verified above under
Observable Truths and Required Artifacts.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| DIST-06 | Satisfied in Phase 20 (20-04/20-05/20-13); re-affirmed idempotently by 21-01–21-04 | Copy-paste workflow template packaged for manual adoption | ✓ SATISFIED (pre-existing) | `20-VERIFICATION.md:76`; unchanged by Phase 21 — no plan in this phase touches the packaged template |
| DIST-08 | Satisfied in Phase 20 (20-08/20-09/20-12/20-13); directly strengthened by Phase 21 | Adoption docs cover both consumption modes | ✓ SATISFIED, strengthened | `20-VERIFICATION.md:78`; Phase 21's 21-03/21-04 work (SARIF limits subsection) is itself an accuracy improvement to the same adoption-guide.md this requirement already covers — live-confirmed above |

No orphaned requirements: `.planning/REQUIREMENTS.md`'s Phase 21 ROADMAP entry maps only DIST-06/DIST-08,
both already covered.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers found in any of the four Phase-21-modified files (re-grepped live this session: `milestone-2-cicd-gate.md`, `milestone-4-defectdojo.md`, `adoption-guide.md`, Phase 17's `deferred-items.md`) | — | — |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Grype fully removed, milestone-2 | `grep -c -i grype docs/milestone-plan/milestone-2-cicd-gate.md` | `0` | ✓ PASS |
| Grype fully removed, milestone-4 | `grep -c -i grype docs/milestone-plan/milestone-4-defectdojo.md` | `0` | ✓ PASS |
| SARIF limits subsection present | `grep -n 'SARIF Upload Limits at Consumer Scale' docs/adoption-guide.md` | line 259 | ✓ PASS |
| Standing adoption-guide gate | `bash scripts/check-adoption-guide.sh` | `PASSED 15 / FAILED 0`, exit 0 | ✓ PASS |
| Phase 17 deferred-items Phase 21 re-check table | `sed -n '/Status re-check 2026-09-15 (Phase 21)/,$p' .../17-.../deferred-items.md` | #4 CLOSED, #6 CLOSED, SE-1 CLOSED, #7 CLOSED-by-20.1, #2 OPEN | ✓ PASS |
| Milestone docs markdownlint | `markdownlint-cli2 milestone-2-cicd-gate.md milestone-4-defectdojo.md` | `Summary: 0 error(s)` (2 files) | ✓ PASS |
| Line-wrap regression re-check | `grep -qF '25,000 results per run' docs/adoption-guide.md` | match found, phrase contiguous | ✓ PASS |
| "soft limit" negative-grep re-check | `grep -c -i "soft limit" docs/adoption-guide.md` | `0` | ✓ PASS |
| Blueprint `# v4` attribution (item #7) | `grep -n '# v4' docs/development-security-stack-option-1.md` | 3 hits, all `github/codeql-action/upload-sarif`, zero `actions/checkout` | ✓ PASS |
| Blueprint Grype still present (item #2, expected OPEN) | `grep -n -i grype docs/development-security-stack-option-1.md` | 30+ hits including the `### 4. Syft + Grype` section | ✓ PASS (confirms correctly-scoped non-fix) |
| Working tree clean for phase-touched paths | `git status --porcelain -- docs/ .../17-.../ .../21-.../` | empty | ✓ PASS |
| No probe scripts declared for this phase | `find scripts -path '*/tests/probe-*.sh'` | no hits | ✓ PASS (N/A — doc-only phase) |

### Probe Execution

No probes declared by any 21-0N-PLAN.md and no `scripts/*/tests/probe-*.sh` files exist in this repository
(`find scripts -path '*/tests/probe-*.sh' -type f` returns nothing, re-run live this session). This phase is
verified via `grep`/`markdownlint-cli2`/the standing `check-adoption-guide.sh` gate, not runnable probes.

### Human Verification Required

None. This is a documentation-only phase (prose corrections, one new subsection, one tracking-file append).
All claims are grep-verifiable and were independently re-run live in this session.

### Commit Attribution Note (informational, zero content impact)

21-01/21-02/21-03's SUMMARYs each report contradictory commit-hash histories for the same content, caused by
running three Phase 21 plans concurrently in one **shared, non-worktree checkout** (not isolated worktrees)
on branch `feature/phase-12-repo-setup-script`. Live `git show --stat` this session pins the actual, current
attribution:

| Commit | Files | Content |
|---|---|---|
| `e664cba` | `milestone-2-cicd-gate.md` (4+/4-) | 21-01 Task 1 (Grype removed from M2-F1 prose) |
| `e2d198e` | `adoption-guide.md` (32+/0-) | 21-03 Task 1 (SARIF limits subsection) — confirmed single-file at this commit, contra 21-02-SUMMARY's claim that its own Task 1 content also landed here |
| `dad6b41` | `milestone-2-cicd-gate.md` + `milestone-4-defectdojo.md` (4+/4- each) | 21-01 Task 2 + 21-02 Task 1, combined (the sibling-checkout sweep both 21-01-SUMMARY and 21-03-SUMMARY describe) |
| `247312c` | `milestone-4-defectdojo.md` (1+/1-) | 21-02 Task 2 (Trivy-vs-Grype dedup fix) |
| `65344c4` | `deferred-items.md` (19+/0-) | 21-04 Task 1 |
| `9372257` | `adoption-guide.md` (2+/2-) | 21-04 line-wrap fix |
| `0d5a31e` | `adoption-guide.md` (1+/1-) | 21-04 "soft limit" reword |

Net effect: every plan's intended content is present, correctly scoped, and byte-identical to what each plan
describes — confirmed by the live greps above, independent of which commit object carries which file. This
is a commit-hygiene/attribution artifact of unisolated concurrent execution, not a content defect, and does
not affect this report's score.

### Gaps Summary

No gaps against the 4 plans' delivered acceptance criteria, and no gaps against DIST-06/DIST-08 (both
already satisfied pre-Phase-21, unaffected or strengthened by this phase's edits).

Two items worth surfacing as resolved informational findings, not open gaps:

1. **21-03-SUMMARY's self-reported "all acceptance-criteria greps... all passed" did not reproduce
   unmodified.** Independently re-run in this session (and, per 21-04-SUMMARY, already caught and fixed
   within the phase itself): the phrase `25,000 results per run` was originally hard-line-wrapped across
   two lines in `docs/adoption-guide.md`, and the sentence "None of these is a soft limit" originally
   contained the literal substring `soft limit`, both of which would have failed a literal `grep -qF` re-run
   at the state 21-03 left the file in. 21-04 discovered and fixed both (commits `9372257`, `0d5a31e`)
   *before* closing the phase. This report's own live re-grep, run independently in this session against
   current HEAD, confirms both fixes hold: the phrase is contiguous and `soft limit` no longer appears.
   Surfacing this because a phase whose entire purpose is closing doc-vs-reality drift should not let its
   own plan's self-report go unchecked — but the drift was caught and closed within the phase, not left for
   this report to discover fresh.
2. **Commit-hash churn from unisolated concurrent execution** (see attribution table above) — zero content
   impact, fully resolved by the live grep evidence in this report.

Neither item blocks the phase goal or DIST-06/DIST-08. The ROADMAP goal sentence's stale third clause (the
`# v4` item, closed by Phase 20.1, dropped from Phase 21 scope by the user) is documented above under Truth
#5 and is not counted as a gap, per the parent task's explicit instruction.

---

*Verified: 2026-09-17*
*Verifier: Claude (gsd-verifier)*
