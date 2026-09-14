---
phase: 20-template-packaging-and-adoption-docs
plan: 13
subsystem: docs
status: checkpoint
tags: [adr, requirements-closure, roadmap, pilot-pr-fate, phase-close-out]

# Dependency graph
requires:
  - phase: 20-10
    provides: "Live pilot proof on terraform-pipelines (Mode A PR #12 / Mode B PR #13), the SC1/SC2 evidence and branch-protection dry run this ADR cites"
  - phase: 20-11
    provides: "Live pilot proof on aws-zabbix-monitoring-solution (PR #8, private), the private-repo capability guard confirmation this ADR cites"
  - phase: 20-12
    provides: "Corrected docs/adoption-guide.md and retitled blueprint section this ADR references as evidence"
provides:
  - "ADR-018 (Accepted): records the D-01 amendment (OttawaCloudConsulting/security-platform is the canonical host), the D-04 portability-premise correction, dual-tag versioning rationale, the private-repo capability guard, and an eight-item What-was-NOT-verified list"
  - "docs/adr/README.md gained exactly one row for ADR-018"
  - "ROADMAP.md Phase 20 and REQUIREMENTS.md DIST-07 corrected: the org identifier that never existed is gone, replaced with OttawaCloudConsulting/security-platform and the correction's authority (D-01 amendment / RESEARCH C-1)"
  - "DIST-06, DIST-07, DIST-08 marked Complete (checkbox and Traceability row, both grep-verified) via requirements.mark-complete invoked exactly once"
  - "ROADMAP Phase 20 entry finalised: all 13 plans checked off, four success criteria annotated with PR/run/file evidence, progress table at 13/13 Complete"
  - "Task 3 (pilot PR fate + requirement sign-off) presented to the operator and AWAITING REPLY — not resolved in this session"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md
  modified:
    - docs/adr/README.md
    - CLAUDE.md
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md

key-decisions:
  - "ADR-018's guard-compounding count corrected from the plan text's 'six downstream steps' to the measured eight occurrences (build step plus seven always()-guarded steps) per 20-03-SUMMARY.md's own count — evidence outranks plan text, per this project's own ADR-017/ADR-018 precedent."
  - "DIST-07's checkbox was transiently set to [x] by hand while drafting the wording fix, then reverted to [ ] before commit so requirements.mark-complete was the only actor that flipped it — avoiding a second, uncoordinated write to the same state."
  - "Task 3 is NOT resolved in this session. Per the plan's own gate='blocking' checkpoint and this plan's explicit parallel_execution instruction, the three pilot PRs' fate is presented below with live-reverified state, and this SUMMARY records AWAITING OPERATOR, not a decision."

requirements-completed: [DIST-06, DIST-07, DIST-08]  # Invoked via requirements.mark-complete in Task 2 of this plan — see Task Commits and the JSON output quoted below

# Metrics
duration: "~55min (Tasks 1-2 through this checkpoint; Task 3 unresolved)"
completed: 2026-09-14
---

# Phase 20 Plan 13: ADR-018, Requirements Closure, and Phase Close-Out Summary

**ADR-018 (Accepted) records the phase's decisions and corrections — the D-01 amendment naming
`OttawaCloudConsulting/security-platform` as the canonical host, the D-04 portability-premise
correction, dual-tag versioning, the private-repo capability guard, and an eight-item
not-verified list. `docs/adr/README.md` gained one row. The dead `OCC-github` path is gone from
`ROADMAP.md` and `REQUIREMENTS.md`, replaced with the real host and the correction's authority.
`requirements.mark-complete` was invoked exactly once, marking DIST-06/07/08 complete with both
representations grep-verified. Task 3 — the fate of three still-OPEN pilot pull requests and
operator sign-off on the three completions — is presented below and AWAITING REPLY; no PR was
merged or closed in this session.**

## Worktree Setup

This worktree's HEAD (`b4cb207`) shared no common ancestor with the plan's expected base
`5ea684c308505880c5ac9ffa796a09c017c151d7` — `git merge-base` returned exit 1 with no output, the
same disjoint-history condition recorded by every prior plan in this phase. `b4cb207`'s root
commit ("chore: initialize repository") and the expected base's root ("init") are two genuinely
unrelated histories (63 commits vs. 332). Before resetting: `git status --short` was confirmed
clean, and `git for-each-ref --contains b4cb207` confirmed `b4cb207` remains reachable via
`refs/remotes/origin/main` and `refs/remotes/origin/HEAD` — no data loss from moving the
worktree-agent branch pointer. HEAD/namespace assertions passed first (branch
`worktree-agent-af54eb2921a1171c6`, matching the `worktree-agent-*` allow-list, not on any
protected ref), so the sanctioned `git reset --hard 5ea684c308505880c5ac9ffa796a09c017c151d7` was
applied. `git rev-parse HEAD` confirmed the match; `.planning/phases/20-template-packaging-and-adoption-docs/`
then showed 20-01 through 20-13's plan/summary files as expected.

## Task 1 — Write ADR-018 and append its index row: COMPLETE

Wrote `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md` using ADR-017's exact
four-heading skeleton (`## Context`, `## Decision`, `## Consequences`, `## What was NOT
verified`), header block `**Status:** Accepted`, `**Date:** 2026-09-14`, `**Addresses:** DIST-06,
DIST-07, DIST-08`.

Read `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` in full for the skeleton and
prose conventions, `docs/adr/README.md` for the index format, `20-01/20-03/20-04/20-05/20-06/20-07/20-10/20-11/20-12-SUMMARY.md`
for the measured evidence behind each decision, and `20-RESEARCH.md`'s Assumptions Log / Open
Questions for the not-verified list source.

Three `**Correction to …**` bullets (exceeds the plan's minimum of two): the D-01 amendment
(`OCC-github` returns a 404 as both org and user lookup; this repository's own history is disjoint
from any remote it could safely become public through — RESEARCH C-1's `gitleaks git .` measurement
of 16 findings across 320 commits), the D-04 portability-premise correction (no Dockerfile
auto-detection existed before plan 03), and the inherited-but-cited D-06 five-not-six
required-check correction from ADR-017.

Every decision bullet with a rejected alternative names it inline: RESEARCH Q1 Option A (rejected
for the canonical-host decision), a checked-in template copy (rejected for the packaging decision),
an annotated moving tag (rejected for versioning), an `expect_code_scanning` input (rejected as a
second substitution point), a placeholder-token substitution scheme (rejected for `gate_mode`).

`## What was NOT verified` opens with the what-WAS-measured fence, then eight numbered items
including A3 (fork PR `vars` access, one non-docs source), A5 (the account's plan tier unknown),
and the `Containerfile` pathspec gap, plus the required-check-adoption deferral and the
`upload-artifact`-on-fork-runs open item inherited from ADR-016/017.

**Self-review correction (before the checkpoint, not before Task 1's own commit):** re-reading
20-03-SUMMARY.md's own invariant table against a first-draft claim of "six downstream steps"
found the actual measured count is eight (the build step plus seven `always() &&`-guarded steps).
Corrected in a follow-up commit, along with a misattributed subject ("this repository has no
`docs/` tree in `security-platform`" — `security_solution` does have `docs/`; the host,
`security-platform`, does not) and a stray literal placeholder left over from drafting
(`(D-... in ADR-017)`). Evidence outranks a first draft, per this project's own documented
verification discipline.

**Verification (plan's exact automated check, re-run after the follow-up commit):**

```
markdownlint-cli2 [ADR-018, README.md, CLAUDE.md]: 0 errors
grep -c "^## " ADR-018 == 4
Addresses: DIST-06, DIST-07, DIST-08 present
grep -c "ADR-018" docs/adr/README.md == 1
grep -c "Correction to" ADR-018 >= 2  (actual: 3)
```

`git diff docs/adr/README.md` shows exactly one insertion (`+| [ADR-018](...) | ... | Accepted |`),
zero other lines changed. `OCC-github` appears in the ADR only inside the Context and Decision
bullets explaining that the identifier never existed.

## Task 2 — Correct the dead repository path, finalise ROADMAP, mark requirements complete: COMPLETE

Corrected DIST-07 in `.planning/REQUIREMENTS.md` to `uses:
OttawaCloudConsulting/security-platform/.github/workflows/security.yml@<ref>`, with a parenthetical
naming the correction's authority (the D-01 amendment and RESEARCH C-1) without reproducing the
dead identifier itself (the verify script asserts zero occurrences of the literal string anywhere
in the file). Applied the identical correction to ROADMAP Phase 20 success criterion 2. No other
requirement or criterion's substance changed — `git diff .planning/REQUIREMENTS.md` touches only
the three DIST-0N lines and their three Traceability rows.

**Self-caught collision:** ROADMAP's own plan-list line for this plan (line 210, describing plan
13's own task) originally read "correct the dead `OCC-github` path" — a self-referential grep
collision, the same category 20-03/20-04/20-12 each hit and fixed the same way. Reworded to
"correct the dead org-path text" before the final `! grep -q "OCC-github"` check was run.

Finalised the ROADMAP Phase 20 entry: all 13 plan-list checkboxes flipped to `[x]`, the four
success criteria each annotated with PR numbers, run ids, or file paths (SC1: PR #12/run
`34884582425`; SC2: PR #13/run `34885287142` plus the resolved commit SHA; SC3: the adoption
guide's 15/15 standing-gate pass; SC4: the applicability matrix and the four measured `SKIP:`/
`FOUND` lines), the top-level phase checklist entry and the Progress table row both updated to
Complete/13/13/2026-09-14.

**`requirements.mark-complete` invoked exactly once, in this plan** (confirmed: no other plan in
this phase's SUMMARYs invoked it — every one of 20-01 through 20-12 explicitly recorded
`requirements-completed: []` and deferred to this plan, per the 17-01/19-01 precedent already
established in `STATE.md`). Read the SDK handler's argv shape from
`get-shit-done-cc/agents/gsd-executor.md` and `command-manifest.non-family.ts` before calling it
(space-separated positional IDs, not a comma-joined string or a flag), rather than assuming:

```
$ gsd-sdk query requirements.mark-complete DIST-06 DIST-07 DIST-08
{
  "updated": true,
  "marked_complete": ["DIST-06", "DIST-07", "DIST-08"],
  "already_complete": [],
  "not_found": [],
  "total": 3
}
```

Verified BOTH representations directly by grep, not by the command's exit code:

```
grep -cE "^- \[x\] \*\*DIST-0[678]\*\*" .planning/REQUIREMENTS.md  -> 3
grep -cE "^\| DIST-0[678] \| Phase 20 \| Complete" .planning/REQUIREMENTS.md  -> 3
```

**Verification (plan's exact automated check):**

```
! grep -q "OCC-github" .planning/ROADMAP.md         -> passes (0 occurrences)
! grep -q "OCC-github" .planning/REQUIREMENTS.md     -> passes (0 occurrences)
DIST checkboxes == 3                                  -> passes
DIST Traceability rows == 3                           -> passes
no "**Plans**: TBD" in ROADMAP.md                     -> passes (was never TBD; already "13 plans")
OK
```

## Task 3 — Phase close-out: pilot pull request fate and requirement sign-off — AWAITING OPERATOR

**This task is NOT resolved.** Per this plan's own `type="checkpoint:human-verify" gate="blocking"`
and the explicit `parallel_execution` instruction governing this session ("If closing/merging any
of these PRs … is ambiguous or requires a judgment call the plan doesn't fully specify, STOP and
report as a blocking checkpoint rather than guessing. Do not delete or merge these PRs without
explicit confirmation of intent"), no PR was merged, closed, or otherwise modified in this session.
The word **confirmed** in this section is deliberately used only in the negative: operator
confirmation of the three requirement completions has **NOT** been received, and no per-pull-request
decision (merge / close / leave open) has been recorded.

### The three pilot pull requests — LIVE STATE RE-VERIFIED THIS SESSION (not read from the prior SUMMARYs alone)

| # | Repository | Head SHA | State (re-checked live, this session) | Mode / Evidence |
|---|---|---|---|---|
| [#12](https://github.com/OttawaCloudConsulting/terraform-pipelines/pull/12) | `terraform-pipelines` (public) | `6e8975f22232659c1403de452d559d6c97ebb1eb` | **OPEN**, `mergedAt: null` | Mode A copy-paste, run `34884582425`, five checks `success` (SC1) — 20-10-SUMMARY.md |
| [#13](https://github.com/OttawaCloudConsulting/terraform-pipelines/pull/13) | `terraform-pipelines` (public) | `44b9d56a3d97ea1ca108f5df167cb246de47bb25` | **OPEN**, `mergedAt: null` | Mode B `uses:` reference, run `34885287142`, five checks `success` (SC2) — 20-10-SUMMARY.md |
| [#8](https://github.com/OttawaCloudConsulting/aws-zabbix-monitoring-solution/pull/8) | `aws-zabbix-monitoring-solution` (private) | `fbd5c847a32e2eca5c2cb372661ca537a8af9db4` | **OPEN**, `mergedAt: null` | Mode A copy-paste, run `34887388960`, five checks `success`, six SARIF verifies skipped cleanly — 20-11-SUMMARY.md |

Re-verified via `gh pr view <n> -R <repo> --json state,mergedAt,headRefOid` immediately before
writing this section — all three head SHAs match the prior SUMMARYs exactly, confirming no drift
occurred between 20-10/20-11 and this plan's execution (STATE.md and 20-06-SUMMARY.md both record
a precedent of operators merging pilot PRs out of band before a later plan ran, so this re-check
was not skipped as redundant).

**Decision required for each, per the plan's own three-way table:** merge (adopts the pipeline in
that repository now), close (defers adoption), or leave open (no decision yet). Adopting is a real
change to another project's CI, which is why no plan in this phase merged any of them.

### The three requirement completions — evidence to confirm or correct

- **DIST-06** (copy-paste template): PR #12 (Mode A) proves a dropped-in copy produces a working
  scan run — five `security / …` checks `success`, run `34884582425`.
- **DIST-07** (reusable `workflow_call` reference against a stable ref): PR #13 (Mode B) — the
  `uses:` reference resolved to `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`, the exact commit both
  `v1` and `v1.0.0` point to, run `34885287142`.
- **DIST-08** (adoption docs covering both modes): `docs/adoption-guide.md` sections 1-13,
  corrected against all three pilot runs in plan 12, standing gate `bash
  scripts/check-adoption-guide.sh` at 15/15 PASS.

`requirements.mark-complete` was invoked exactly once, in this plan (Task 2 above) — this is
stated here per the plan's own acceptance criterion for Task 3.

### ADR-018's `## What was NOT verified` list — presented for operator review

Eight items (fork-PR `vars` access; the account's unknown plan tier; the two `if:`/`with:`
context fields never exercised; whether a GHAS-bearing organisation consumer behaves differently;
the `Containerfile` pathspec gap; whether the `cicd/` Azure DevOps/GitLab members were ever built
or validated; whether any repository has required checks actually enabled — deferred since
ADR-017/18-05, reaffirmed at 19-07; and whether `upload-artifact` succeeds on fork/Dependabot
runs). None of these were measured in this phase; the operator should confirm none should have
been measured here instead of deferred, in particular whether required-check adoption should stay
deferred.

### What the operator needs to reply with (per this plan's own resume-signal)

1. A decision for **each** of the three pull requests: merge / close / leave open.
2. `confirmed` for the three requirement completions (or a correction, if the evidence above does
   not hold up under review).
3. Confirmation (or correction) that ADR-018's not-verified list correctly defers everything it
   defers — in particular required-check adoption.

**No merge, close, or ruleset action will be taken until that reply arrives in a continuation
session.**

## Task Commits

1. **Task 1: Write ADR-018 and append its index row** — `02c7892`
   (`docs(20-13): add ADR-018 and append index row`)
2. **Task 2: Correct the dead repository path, finalise ROADMAP, mark requirements complete** —
   `55c7386` (`docs(20-13): correct dead org path, finalize ROADMAP Phase 20, mark DIST-06/07/08
   complete`)
3. **Self-review follow-up: correct ADR-018 accuracy defects found before returning** — `f578d7d`
   (`docs(20-13): correct accuracy defects in ADR-018 found at self-review`)
4. **Task 3: checkpoint by design** — no file-changing commit; this SUMMARY (committed with the
   plan's closing metadata commit) records the presented evidence and the AWAITING OPERATOR
   status.

## Files Created/Modified

- `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md` — new, Accepted.
- `docs/adr/README.md` — one row appended after ADR-017.
- `CLAUDE.md` — ADR range extended from "ADR-001 through ADR-017" to "ADR-001 through ADR-018".
- `.planning/ROADMAP.md` — DIST-07/SC2 dead-path correction, Phase 20 entry finalised (13 plans
  checked, four success criteria annotated with evidence, progress table row updated, top-level
  checklist entry updated).
- `.planning/REQUIREMENTS.md` — DIST-07 path corrected, DIST-06/07/08 checkboxes and Traceability
  rows marked Complete.
- `.planning/phases/20-template-packaging-and-adoption-docs/20-13-SUMMARY.md` — this record.

## Decisions Made

See `key-decisions` in frontmatter. Summary: (1) ADR-018's guard-compounding count corrected to
match 20-03's own measurement (eight, not six) rather than the plan text's unverified figure; (2)
DIST-07's checkbox was transiently hand-set then reverted so `requirements.mark-complete` was the
sole actor flipping it; (3) Task 3 is explicitly NOT resolved — the three pilot PRs' fate and the
requirement-completion sign-off are presented for the operator, per this plan's own blocking
checkpoint and the parallel_execution instruction governing this session.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, self-caught before the checkpoint] ADR-018 first draft misstated the
guard-compounding count and misattributed a `docs/` tree**
- **Found during:** Self-review before returning, after Task 1's own commit
- **Issue:** (a) The draft stated the Dockerfile-guard output was "compounded onto six downstream
  steps," but 20-03-SUMMARY.md's own invariant table measures eight occurrences (the build step
  plus seven `always() &&`-guarded steps). (b) A context bullet read "This repository has no
  `docs/` tree in `security-platform`" — `security_solution` (this repository) does have a
  `docs/` tree; the host, `security-platform`, is the one without.
- **Fix:** Corrected both in a follow-up commit (`f578d7d`), citing the measured count directly
  and correcting the misattributed subject. Also removed a stray literal placeholder
  (`(D-... in ADR-017)`) left over from drafting.
- **Files modified:** `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md`
- **Verification:** Re-ran the plan's exact Task 1 verify script after the fix — still 4 headings,
  `Addresses:` line present, 1 ADR-018 row in README.md, 3 `Correction to` bullets, zero
  markdownlint violations.
- **Committed in:** `f578d7d`

**2. [Rule 1 - Bug, self-referential grep collision] ROADMAP's own plan-list description for this
plan contained the literal dead-path substring it was correcting**
- **Found during:** Task 2, before running the final `! grep -q "OCC-github"` verify check
- **Issue:** ROADMAP.md line 210 (the plan-list entry describing plan 13's own task) originally
  read "correct the dead `OCC-github` path in ROADMAP/REQUIREMENTS" — a self-referential
  collision, the same category 20-03/20-04/20-12 each hit and fixed by rewording, not by
  weakening the check.
- **Fix:** Reworded to "correct the dead org-path text in ROADMAP/REQUIREMENTS."
- **Files modified:** `.planning/ROADMAP.md`
- **Verification:** `grep -c "OCC-github" .planning/ROADMAP.md` returns 0.
- **Committed in:** `55c7386`

**3. [Rule 1 - Bug, same category] REQUIREMENTS DIST-07's correction text initially reproduced the
dead identifier as part of explaining that it was dead**
- **Found during:** Task 2, drafting the DIST-07 correction
- **Issue:** A first-draft correction parenthetical explained the fix by naming the literal
  dead org identifier — which would have kept the substring present in the very file the verify
  script asserts contains zero occurrences of it.
- **Fix:** Reworded to describe the correction ("the org identifier this requirement originally
  named was never a real GitHub account, org or user lookup both 404") without reproducing the
  identifier itself.
- **Files modified:** `.planning/REQUIREMENTS.md`
- **Verification:** `grep -c "OCC-github" .planning/REQUIREMENTS.md` returns 0.
- **Committed in:** `55c7386`

---

**Total deviations:** 3 auto-fixed (2 self-caught accuracy/attribution bugs in ADR-018, 1
self-referential grep collision identical in kind to three prior plans in this phase).
**Impact on plan:** All three were necessary to satisfy this plan's own acceptance criteria and
this project's evidence-over-draft-text discipline. No scope creep — no file outside this plan's
declared `files_modified` list was touched, and no pilot pull request was merged, closed, or
otherwise modified.

## Issues Encountered

- Worktree HEAD (`b4cb207`) shared no common ancestor with the plan's expected base — the same
  disjoint-history condition every prior plan in this phase has recorded, this time confirmed to
  be two genuinely unrelated root histories (63 commits vs. 332), not merely an ancestry gap.
  Resolved via the sanctioned `git reset --hard` after confirming `b4cb207` remains reachable via
  `origin/main`/`origin/HEAD` (zero data loss) and HEAD/namespace assertions passed.
- Compound `sed`-with-runtime-variable and multi-file `for`-loop `git`/`gh` invocations were
  rejected by the worktree isolation guard as "too complex to verify [stays inside the worktree]"
  — resolved by reading files individually via the Read tool and running single, literal `gh`/
  `grep` commands, consistent with every prior plan in this phase.

## User Setup Required

None — no external service configuration required by this plan's own deliverables. Task 3 requires
an **operator decision**, not a service-configuration step; see the "What the operator needs to
reply with" section above.

## Next Phase Readiness

This is the final plan of Phase 20 and of the v2.0 milestone's currently-planned scope. Tasks 1
and 2 are fully complete and committed. **Task 3 remains open** — a continuation session must
receive the operator's reply (per-PR decision for #12/#13/#8, plus `confirmed` or a correction for
the three requirement completions) before this plan, this phase, and the v2.0 milestone can be
declared closed. STATE.md and ROADMAP.md milestone-level status are explicitly NOT updated by this
worktree agent per the orchestrator's instruction — that update is the orchestrator's
responsibility after this plan's Task 3 resolves.

## Self-Check: PASSED

- `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md` — FOUND, 4 `## ` headings,
  `Addresses: DIST-06, DIST-07, DIST-08` present, 3 `Correction to` bullets, 8 numbered
  not-verified items
- `docs/adr/README.md` — FOUND, exactly one new row (`git diff` shows 1 insertion)
- `CLAUDE.md` — FOUND, ADR range now "ADR-001 through ADR-018"
- `.planning/ROADMAP.md` — FOUND, zero `OCC-github` occurrences, Phase 20 entry shows 13/13
  complete with four annotated success criteria
- `.planning/REQUIREMENTS.md` — FOUND, zero `OCC-github` occurrences, three `[x]` DIST checkboxes,
  three `Complete` Traceability rows
- Commit `02c7892` — FOUND in `git log --oneline`
- Commit `55c7386` — FOUND in `git log --oneline`
- Commit `f578d7d` — FOUND in `git log --oneline`
- `gsd-sdk query requirements.mark-complete DIST-06 DIST-07 DIST-08` — CONFIRMED via its own JSON
  output (`updated: true`, all three in `marked_complete`, `not_found: []`)
- PR #12, #13, #8 — CONFIRMED live `OPEN` state and head SHAs via `gh pr view` immediately before
  writing this SUMMARY, matching 20-10/20-11-SUMMARY.md exactly (no drift)
- Worktree base correction — CONFIRMED `b4cb207` reachable via `origin/main`/`origin/HEAD` before
  the reset; `git rev-parse HEAD` == `5ea684c308505880c5ac9ffa796a09c017c151d7` after

---
*Phase: 20-template-packaging-and-adoption-docs*
*Status: CHECKPOINT — Tasks 1-2 complete and committed; Task 3 (pilot PR fate, requirement sign-off) AWAITING OPERATOR REPLY*
