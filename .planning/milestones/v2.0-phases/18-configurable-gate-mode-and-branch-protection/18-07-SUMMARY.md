---
phase: 18-configurable-gate-mode-and-branch-protection
plan: "07"
subsystem: docs
tags: [adr, documentation, gate-mode, branch-protection, required-checks]

# Dependency graph
requires:
  - phase: 18-configurable-gate-mode-and-branch-protection
    plan: "04"
    provides: "live report-only baseline measurement (PR #9, run 34668611172): five success conclusions, five gate_mode=report-only log lines"
  - phase: 18-configurable-gate-mode-and-branch-protection
    plan: "05"
    provides: "live blocking-mode measurement (run 34669534855): five failure conclusions on the identical tree, restore run 34669700643, and the closed leave-unrequired decision (Task 3)"
  - phase: 18-configurable-gate-mode-and-branch-protection
    plan: "06"
    provides: "corrected blueprint and milestone-plan branch-protection passages with the five byte-exact contexts"
provides:
  - "ADR-017 (Accepted): the decision record for CICD-04/CICD-06 — gate_mode enum, five required contexts, D-06 five-not-six correction, D-07 step 1 unobservable-red correction, leave-unrequired for this repo's own main"
  - "ADR-017 indexed in docs/adr/README.md directly after ADR-016"
  - "Live byte-exact cross-check of the five required contexts against ADR-017 and the blueprint, re-read fresh from the check-runs API rather than carried over from 18-04/18-05"
affects: [18-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Byte-compare documented context strings against a live check-runs API read with a UTF-8 byte dump, not a rendered-text eyeball comparison — the frozen five contexts all carry an em dash (U+2014), and a hyphen substitution would be invisible in most renderers"

key-files:
  created:
    - docs/adr/adr017-configurable-gate-mode-and-required-checks.md
  modified:
    - docs/adr/README.md

key-decisions:
  - "ADR-017 records D-06's five-not-six correction and D-07 step 1's unobservable-red correction as their own explicit Decision bullets with cited evidence, per the plan's must_haves — the first draft covered both facts narratively but not as named correction bullets, and was revised before commit to satisfy the acceptance criteria literally"
  - "ADR-001 and ADR-002 confirmed untouched: git log --oneline shows no commit from this phase (or any commit since 2026-02-24) touching either file"

requirements-completed: [CICD-04, CICD-06]

# Metrics
duration: ~35min
completed: 2026-09-12
---

# Phase 18 Plan 07: ADR-017 — Configurable Gate Mode and Required Checks Summary

**ADR-017 is Accepted and indexed: a 58-line decision record for CICD-04/CICD-06 carrying the gate_mode enum design, the five byte-exact required contexts pinned to integration_id 15368, both corrections to the phase's own prior inputs (D-06's five-not-six, D-07 step 1's unobservable red), the operator's leave-unrequired decision for this repository's own `main`, and a `## What was NOT verified` section naming four open items including the fork-variable question routed to Phase 19.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-09-12
- **Tasks:** 2 of 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- **ADR-017 authored in ADR-016's shape**: header block (`**Status:** Accepted`, `**Date:** 2026-09-12`, `**Addresses:** CICD-04, CICD-06`), Context (six bold-lead constraint-plus-consequence bullets), Decision (thirteen bold-lead bullets including the two correction bullets, with five named rejected alternatives each carrying its own rejection reason), Consequences (`**Improved:**` opening with the measured three-commit/three-run before/after, followed by five `**Tradeoff — …**` paragraphs), and `## What was NOT verified` (what was measured and must not be re-litigated, then four numbered open items).
- **D-06's five-not-six correction recorded as its own Decision bullet**, citing all three observations by identifier: 14-02's single-job `security / Placeholder` check, the Phase 18 research read of the Phase 17 head SHA `fbe0071d6934d19524f5bf9345e91396080fa882` (twelve names, no bare `security`), and this phase's own run `34668611172` (18-04) with its `bare_security: false` assertion.
- **D-07 step 1's unobservable-red correction recorded as its own Decision bullet**, with the corrected three-step ordering: step 1 (18-04) confirms green in report-only; step 2 (18-05) flips to blocking on the identical tree and confirms red; step 3 (18-05) flips back and confirms green returns.
- **The ADR-016 Dependabot `security-events: write` hand-off is acknowledged, not dropped** — named explicitly in `## What was NOT verified` item 2 as unresolved by this phase either.
- **ADR-017 indexed** in `docs/adr/README.md` directly after ADR-016 — one line added, nothing else in the file changed.
- **Live byte-exact cross-check performed and passed**, re-reading the five required contexts fresh from the check-runs API (not carried over from 18-04/18-05's tables) and comparing them byte-for-byte, with the UTF-8 byte dump recorded below, against both ADR-017 and `docs/development-security-stack-option-1.md`.
- **Live `rules/branches/main` read and confirmed matching** ADR-017's record: `deletion`, `non_fast_forward` only — no `required_status_checks` or `pull_request` rule present, consistent with the `leave-unrequired` decision.
- **ADR-001 and ADR-002 confirmed untouched**: `git log --oneline` on both files shows their last commit predates this phase (2026-02-24; the most recent touch to either tracked file anywhere in history is an unrelated `cleanup and restructure` commit `4283789`, not from this phase).

## Task Commits

1. **Task 1: Author ADR-017** — `7022725` (docs) — `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` created, 58 lines
2. **Task 2: Index ADR-017 and cross-check the record against live state** — `e6fcdd4` (docs) — `docs/adr/README.md`, one line added

`git diff HEAD~1 HEAD --name-only` on each commit confirmed exactly one file per commit.

## Files Created/Modified

- `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` (created, 58 lines) — the accepted decision record for CICD-04/CICD-06
- `docs/adr/README.md` (modified, +1 line) — ADR-017 index row appended after ADR-016

## Required Output

### ADR section inventory and line count

58 lines. Sections in ADR-016's order: header block (4 lines: title, Status, Date, Addresses), `## Context` (6 bullets), `## Decision` (13 bullets, including the two correction bullets and five named-and-rejected alternatives), `## Consequences` (`**Improved:**` paragraph plus 5 `**Tradeoff — …**` paragraphs), `## What was NOT verified` (a "must not be re-litigated" paragraph plus a 4-item numbered list).

### The two corrections, as written

1. **D-06 five-not-six** — Decision bullet: "the required-check set is FIVE contexts, not the six D-06 originally stated, because the `security` caller job emits no check run of its own," citing 14-02, the Phase 17 head SHA research read (`fbe0071d…`), and this phase's own run `34668611172` (18-04).
2. **D-07 step 1 unobservable red** — Decision bullet: "'confirm the checks appear green when clean, red when seeded, while still in report-only' describes an unobservable state, because red-on-findings cannot occur in report-only by D-04's own definition," with the corrected three-step ordering (18-04 green, 18-05 blocking-red, 18-05 restore-green).

### Rejected alternatives (five, each with its reason)

1. A boolean flag instead of a string enum — rejected: forces every future third mode into a breaking rename.
2. Per-step expressions repeated on all eleven lines individually — rejected: repeats fallback semantics eleven times, leaves no single place for the resolution chain to plug in.
3. A terminal per-job gate step reading `steps.*.outcome` — rejected: would avoid the skipped-step problem but contradicts locked D-04; a decision-grounds rejection, not a technical one.
4. Classic branch protection — rejected: the repository is ruleset-governed; the classic endpoint 404s by design (false negative, not evidence).
5. A severity-cutoff knob on the required-check list — rejected: pip-audit's JSON has no severity field, so no cutoff applies uniformly across the five jobs.
6. Requiring the six per-driver code-scanning checks in addition to the five job checks — rejected: 17-05 observed the `Checkov` code-scanning check (app 57789) conclude `failure` on a PR that stayed mergeable and later merged; requiring it would have blocked that PR.

(Six listed; the plan named five explicitly in its action block and the sixth — the boolean-vs-enum rejection — was included because it is the first Decision bullet's own explicit "considered and rejected" clause, matching ADR-015's precedent that a decision bullet carries its own rejected alternative inline.)

### The four items in `## What was NOT verified`

1. Whether a fork PR can read repository `vars` at all — routed to Phase 19 (VAL-01); consequence stated: a public repo running blocking via the repo variable could see a fork PR degrade to report-only while required checks still report green.
2. ADR-016's Dependabot `security-events: write` question — not resolved by this phase either.
3. Whether `actions/upload-artifact` succeeds on fork/Dependabot runs — inherited from 17-04, still an observation, not a measurement.
4. The exact `pull_request` rule parameter set GitHub requires on `PUT /repos/{o}/{r}/rulesets/{id}` — exercised only against a local dry run; `scripts/set-required-checks.sh --apply` has never been run against this repository's own ruleset (operator decision: `leave-unrequired`).

### The index row as appended

```
| [ADR-017](adr017-configurable-gate-mode-and-required-checks.md) | Configurable Gate Mode and Required Checks | 2026-09-12 | Accepted |
```

Positioned directly after the ADR-016 row; same four columns; `git diff docs/adr/README.md` shows exactly this one added line.

### Live five-context read, UTF-8 byte dump, and comparison result

**Source SHA used:** `835c43e8e8d7cad5276120b925ca5650a3bcda50` — PR #9's head commit, read via `commits/{sha}/check-runs`. (Note: the merge commit `2e290042a775ff1c442bac75757ef8d0106d7dc3` on `main` itself returns **zero** `app.id == 15368` check runs — expected and consistent with ADR-016 D-02's `pull_request`-only trigger; `main` is never directly analysed.)

```
security / Container — Trivy Image
security / IaC — Checkov
security / SAST — Semgrep CE
security / SCA — Trivy Filesystem
security / Secrets — Gitleaks
```

Count: **5**. UTF-8 byte dump (each name confirmed to carry U+2014 EM DASH, `\xe2\x80\x94`, not a hyphen or en dash):

```
bytes: b'security / Container \xe2\x80\x94 Trivy Image'
bytes: b'security / IaC \xe2\x80\x94 Checkov'
bytes: b'security / SAST \xe2\x80\x94 Semgrep CE'
bytes: b'security / SCA \xe2\x80\x94 Trivy Filesystem'
bytes: b'security / Secrets \xe2\x80\x94 Gitleaks'
```

**Comparison result:** all five strings present byte-exactly in both `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` and `docs/development-security-stack-option-1.md`. No mismatch found.

### Live `rules/branches/main` read

```
deletion
non_fast_forward
```

Unchanged from every prior read in this phase (18-04 preflight/postflight, 18-05 preflight/postflight). No `required_status_checks` or `pull_request` rule present — matches ADR-017's record of the operator's `leave-unrequired` decision for this repository's own `main`.

## Decisions Made

See `key-decisions` in frontmatter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] First draft of ADR-017 stated both corrections narratively but not as separately identifiable Decision bullets**
- **Found during:** Task 1 verification, self-review against the plan's `must_haves` and acceptance criteria before running the automated checks
- **Issue:** The initial Decision section wove the five-not-six fact into the required-check-list bullet and did not carry a D-07-step-1 correction bullet at all — both are must-have truths per the plan's frontmatter (`"The five-not-six correction to D-06 is recorded with its evidence, so it cannot resurface as a discrepancy"`).
- **Fix:** Added two explicit Decision bullets, each opening with "Correction to D-06 …" / "Correction to D-07 step 1 …", each carrying its cited evidence inline.
- **Files modified:** `docs/adr/adr017-configurable-gate-mode-and-required-checks.md`
- **Verification:** Re-ran the plan's structural assertion script; all checks passed.
- **Committed in:** `7022725` (the correction was made before the first and only commit of this file — no separate fix commit needed).

**Total deviations:** 1 auto-fixed (Rule 3, structural completeness caught by self-review before the automated verify ran; no scope change).
**Impact on plan:** None — the committed file carries both corrections as named, cited Decision bullets exactly as the plan's must_haves and acceptance criteria require.

## Issues Encountered

**Observation, not a defect in this plan's own work:** PR #9 (`OttawaCloudConsulting/security-platform`) was found **already merged** (`mergedAt: 2026-09-12T12:48:34Z`, merge commit `2e290042a775ff1c442bac75757ef8d0106d7dc3`) when this plan began its Task 2 live cross-check — before this executor touched anything. 18-05's SUMMARY records PR #9 as `OPEN`, `MERGEABLE` at that plan's end; the merge therefore happened after 18-05 and before this plan's execution, outside any plan this executor has visibility into. This plan's own five required-check contexts were still read successfully from the PR's head SHA (`835c43e`, the last commit `pull_request`-analysed before merge) and matched both documents byte-exactly, so Task 2's acceptance criteria are unaffected. **This is handed to 18-08 as a fact to reconcile, not resolved here** — 18-08's stated purpose was "owns the eventual merge," and that merge appears to have already occurred by some other actor or process.

## User Setup Required

None. Both tasks are documentation-only plus read-only `gh api` calls.

## Next Phase Readiness

- ADR-017 is Accepted, indexed, and its most load-bearing strings are proven byte-identical to live state — Phase 19 and 20 have a decision record they can build on without re-deriving these facts.
- **18-08 must reconcile PR #9's already-merged state** before attempting any merge action of its own — see "Issues Encountered" above.
- The fork-`vars` question (routed to Phase 19 / VAL-01) and ADR-016's Dependabot hand-off remain open and are now permanently recorded as open, not just noted in a summary.

---
*Phase: 18-configurable-gate-mode-and-branch-protection*
*Completed: 2026-09-12*

## Self-Check: PASSED

- FOUND: docs/adr/adr017-configurable-gate-mode-and-required-checks.md
- FOUND: ADR-017 row in docs/adr/README.md
- FOUND: .planning/phases/18-configurable-gate-mode-and-branch-protection/18-07-SUMMARY.md (this file)
- FOUND: commit 7022725 (Task 1)
- FOUND: commit e6fcdd4 (Task 2)
