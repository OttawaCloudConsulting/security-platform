---
phase: 20-template-packaging-and-adoption-docs
plan: 04
subsystem: ci-cd
tags: [github-actions, sarif, code-scanning, adoption-docs, dependabot]

# Dependency graph
requires:
  - phase: 20-01
    provides: "Operator-approved Q2 disposition — guard the six SARIF verify steps with `&& github.event.repository.private == false`, leave the five artifact verify steps untouched, no verify step deleted (live-measured on run 34802848411)"
  - phase: 20-03
    provides: "Portable canonical security.yml (inlined detectors, conditional container job) as the base this plan's guard and banners land on"
provides:
  - "The six SARIF verify steps in security.yml now skip cleanly on a private consumer repository instead of going red for a capability it cannot have; no assertion was deleted"
  - "A canonical-copy adoption banner on security.yml and a caller adoption banner on pr-security.yml, both naming `gate_mode` as the sole per-repo substitution point and the `gh variable set GATE_MODE` mechanism"
  - "Corrected two stale comments: pr-security.yml no longer hands the fork-variables question to Phase 19 (states the measured UNVERIFIED position instead); dependabot.yml states that an external `@v1` reusable-workflow reference IS updated, not just that a local `./` reference is ignored"
affects: [20-08-adoption-guide, 20-09-adoption-guide, 20-10-pilot-prs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Capability guard compounded onto the existing verify-step `if:`, never onto the upload step — skip a check that cannot pass, never delete a check that could"
    - "Adoption banner as a header-comment extension, not a placeholder token — `gate_mode` remains the only per-repo substitution point, set via `gh variable set`, never a YAML edit"

key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml
    - repos/security-platform/.github/workflows/pr-security.yml
    - repos/security-platform/.github/dependabot.yml

key-decisions:
  - "Applied 20-01's Q2 disposition verbatim: guard expression `&& github.event.repository.private == false`, applied only to the six SARIF verify steps (semgrep, checkov, trivy-filesystem, tflint, trivy-image, gitleaks), new clause ordered last, every pre-existing clause preserved"
  - "Reworded the explanatory comment to say 'a new workflow_call boolean input naming that expectation' instead of the literal string 'expect_code_scanning', because the plan's own acceptance criterion greps for that literal string and expects zero occurrences (including in comments) — same category of self-referential grep collision 20-03 hit and fixed the same way"
  - "Reworded the placeholder-absence sentence in pr-security.yml's banner to avoid using literal '<OWNER>/<REPO>/<BRANCH>' tokens, since the plan's own acceptance criterion greps for those exact literal strings and expects zero occurrences anywhere in the file, including in a sentence about their absence"

patterns-established:
  - "Self-referential acceptance-criterion greps that count comment text must be avoided by wording, not by omitting the required explanation — state the same fact without the collision string (established by 20-03, reapplied here twice)"

requirements-completed: []  # Deliberately empty — DIST-06/DIST-07 are marked complete only by plan 12, per 20-01's own note carrying forward the 17-01/19-01 precedent.

# Metrics
duration: ~45min
completed: 2026-09-14
---

# Phase 20 Plan 04: Canonical Workflow Guard and Adoption Banners Summary

**Compounded a private-repo capability guard onto the six SARIF verify steps in `security.yml` per plan 01's live measurement, and added adoption banners plus two corrected stale comments to the three files a consumer copies — `gate_mode` remains the template's only per-repo substitution point.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-09-14 (after worktree base correction)
- **Completed:** 2026-09-14
- **Tasks:** 2 of 2 completed
- **Files modified:** 3 (`repos/security-platform/.github/workflows/security.yml`, `repos/security-platform/.github/workflows/pr-security.yml`, `repos/security-platform/.github/dependabot.yml`)

## Setup Deviation (before any task)

This worktree's HEAD (`b4cb207`) was on the disjoint `main`-lineage history (`security-platform`'s
implementation-tracking branch pattern, root commit `c5b6100`) rather than the plan's expected base
`231311f14e8b82fdffa9e93258c515cc6696a342` (docs/`.planning` history, root commit `fdfac5e`). `git merge-base`
between the two returned exit 1 with no output — genuinely no common ancestor, not the "one commit behind,
ancestry-confirmed" case 20-03 hit. Corrected via the sanctioned `git reset --hard 231311f14e8b82fdffa9e93258c515cc6696a342`
per the `worktree_branch_check` step (HEAD/namespace assertions had already passed, making the reset the
sanctioned exception). Verified via `git rev-parse HEAD` matching the target exactly, and confirmed
`.planning/phases/20-template-packaging-and-adoption-docs/20-04-PLAN.md` was then present. No uncommitted
work existed at the old HEAD; `git status --short` was empty before the reset.

`repos/security-platform` did not exist in this worktree — cloned fresh per the plan's HOST PREFLIGHT,
checked out `feature/phase-20-template-packaging` (present on the remote from 20-02/20-03's pushes,
confirmed via `git log --oneline -5` showing commits `6cd5d07`, `3f6d343`, `42e204a`), and confirmed
`grep -c "bash scripts/detect-" .github/workflows/security.yml` returned 0 before starting Task 1.

## Task 1 — Apply the private-repo capability guard (Q2 disposition, operator-approved)

Compounded `&& github.event.repository.private == false` onto the existing `if:` expression of all six
SARIF verify steps, per 20-01-SUMMARY's operator-approved disposition (A1 CONFIRMED live, run `34802848411`:
`upload-sarif` failed with "Code scanning is not enabled for this repository" — a GHAS licensing gate on
this User-owned account, not a token-scope 403):

- `Verify Semgrep SARIF upload landed`
- `Verify Checkov SARIF upload landed`
- `Verify Trivy filesystem SARIF upload landed`
- `Verify tflint SARIF upload landed` (retained its `steps.tf.outputs.found == 'true'` clause)
- `Verify Trivy image SARIF upload landed` (retained its `steps.docker.outputs.found == 'true'` clause)
- `Verify Gitleaks SARIF upload landed`

Every pre-existing clause was preserved (`always()`, the same-repo clause, the `!= 'dependabot[bot]'`
clause), and the new clause was ordered last in each. None of the five artifact verify steps, and none of
the eleven `Upload …` steps, were touched. Added one explanatory comment above the first guarded step
(`Verify Semgrep SARIF upload landed`) stating the measurement (run id, the literal "not enabled" error),
the skip-not-delete distinction, and the correct future evolution (a new `workflow_call` boolean input,
described that way rather than by its hypothetical literal name — see Deviations).

**Verification:** `actionlint` exit 0; `yamllint -d relaxed` exit 0 (pre-existing line-length warnings only,
none introduced); `bash scripts/check-workflow-uploads.sh` — PASS, 10 checks, 0 failures; `bash
scripts/check-detector-parity.sh` — PASSED 20/0. Confirmed by direct grep: the guard clause appears exactly
6 times outside comments (once per SARIF verify step); `grep -c "expect_code_scanning"` returns 0;
`Verify … SARIF upload landed` / `Verify … artifact upload landed` name-line counts (11/9 including
pre-existing comment cross-references) are unchanged from the pre-Task-1 baseline (confirmed via `git show
42e204a:...`); no `continue-on-error` was added to any verify step; no `Upload … SARIF` step's `if:` changed.

## Task 2 — Adoption banners and stale-comment corrections

**`security.yml`:** extended the existing header comment into the canonical-copy banner. States that this
file IS the canonical source (a Mode A consumer fetches it byte-identical, edits nothing), and that
`gate_mode` is the one per-repo substitution point, set with `gh variable set GATE_MODE --body blocking -R
OWNER/REPO`, `report-only` needing no action.

**`pr-security.yml`:** added the matching caller-side banner naming the same substitution point and `gh`
command, stating `name: security` (the job id) must never be renamed because it prefixes all five
branch-protection required-context names, and spelling out the exact one-line Mode A/Mode B difference in
the `uses:` field (`./.github/workflows/security.yml` unchanged for Mode A;
`OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1` for Mode B, nothing else
copied). Corrected the stale `with:`-trap comment: removed "That question is handed to Phase 19 (VAL-01)"
and replaced it with the measured position — Phase 19 (19-07) deliberately did not test whether a fork PR
can read repository `vars`; the claim rests on one unresolved January 2023 GitHub staff forum answer, absent
from GitHub's documentation, so it remains UNVERIFIED by this project. The forbidden-passthrough trap above
it was left exactly as written.

**`dependabot.yml`:** kept the true half of the header (a local `./` reference is never proposed for
update, by design) and added the half a Mode B consumer needs — an external reusable-workflow reference
such as `OWNER/REPO/.github/workflows/security.yml@v1` IS supported and updated (GitHub changelog,
2023-03-13) — and restated that `directory: "/"` is required for `.github/workflows` discovery and must not
be "corrected." No key was changed in any of the three files — comments only.

**Verification:** `actionlint` on both workflow files exit 0; `yamllint -d relaxed` on all three exit 0
(pre-existing warnings only); `bash scripts/check-workflow-uploads.sh` exit 0; `bash
scripts/check-detector-parity.sh` — 20/0; PyYAML round-trip comparing `pr-security.yml` and `dependabot.yml`
before (`origin/main`) and after this task's edits — both dicts identical, confirming comment-only changes;
the `name: security` job in `pr-security.yml` and the five job `name:` values in `security.yml` are
byte-unchanged (confirmed by direct grep against both files, unaffected by any header-comment edit).

### Acceptance-criteria grep results (as specified in the plan)

- `grep -c "gh variable set GATE_MODE"` — `pr-security.yml`: 2, `security.yml`: 1 (both ≥1, satisfied)
- `grep -c "OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1" pr-security.yml` — 1
- `grep -rc "OCC-github" .github/` — 0 across the directory
- `grep -c "handed to Phase 19" pr-security.yml` — 0; `grep -c "UNVERIFIED" pr-security.yml` — 1
- `grep -c "2023-03-13" dependabot.yml` — 1; PyYAML parse matches `{version: 2, updates: [{package-ecosystem: github-actions, directory: "/", schedule: {interval: weekly}}]}`
- `grep -Ec "<OWNER>|<REPO>|<BRANCH>|<YOUR_"` — 0 for both `pr-security.yml` and `security.yml`

## Task Commits

Both commits land in `repos/security-platform` on `feature/phase-20-template-packaging`, pushed after each
task per the plan's HOST PREFLIGHT instruction.

1. **Task 1: Apply the private-repo capability guard** — `fbca578` (feat, in `repos/security-platform`, pushed)
2. **Task 2: Add adoption banners and correct two stale comments** — `7413825` (docs, in `repos/security-platform`, pushed)

_Note: per this plan's explicit host-repo-only scope, both content commits are in `repos/security-platform`,
not this repository. This SUMMARY is the only commit in `security_solution`, per the worktree
parallel-execution protocol._

## Files Created/Modified

- `repos/security-platform/.github/workflows/security.yml` — Task 1: +18/-6 lines (guard on six SARIF
  verify steps, explanatory comment). Task 2: +9/-1 lines (canonical-copy adoption banner).
- `repos/security-platform/.github/workflows/pr-security.yml` — Task 2: +21/-4 lines (caller adoption
  banner, corrected `with:`-trap comment).
- `repos/security-platform/.github/dependabot.yml` — Task 2: +9/-1 lines (corrected header comment).

## Decisions Made

See `key-decisions` in frontmatter. Summary: (1) applied 20-01's Q2 disposition verbatim, no substitute
change; (2) reworded the "correct future evolution" comment to avoid the literal string
`expect_code_scanning`, which the plan's own acceptance criterion greps for and expects at zero occurrences
including in comments; (3) reworded the placeholder-absence sentence in the pr-security.yml banner to avoid
literal `<OWNER>`/`<REPO>`/`<BRANCH>` tokens for the same self-referential-grep reason.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, self-inflicted acceptance-criterion collision] Reworded the "future evolution" comment to avoid the literal string `expect_code_scanning`**
- **Found during:** Task 1, post-edit verification
- **Issue:** The plan's action text instructs naming `expect_code_scanning` as an example future
  `workflow_call` input in the explanatory comment, but the plan's own acceptance criterion asserts
  `grep -c "expect_code_scanning" .github/workflows/security.yml` returns 0 — a bare grep counts comment
  text, so following the action text literally would fail the plan's own acceptance criterion.
- **Fix:** Reworded to "a new `workflow_call` boolean input naming that expectation" — preserves the
  explanatory content (a new input is the correct future evolution, not built speculatively) without the
  literal-string collision.
- **Files modified:** `repos/security-platform/.github/workflows/security.yml`
- **Verification:** `grep -c "expect_code_scanning" .github/workflows/security.yml` returns 0; the sentence
  still conveys the same guidance.
- **Committed in:** `fbca578` (Task 1 commit; the fix was made before the commit, not as a follow-up)

**2. [Rule 1 - Bug, self-inflicted acceptance-criterion collision] Reworded the placeholder-absence sentence to avoid literal `<OWNER>`/`<REPO>`/`<BRANCH>` tokens**
- **Found during:** Task 2, post-edit verification
- **Issue:** The first draft of the `pr-security.yml` banner included the sentence "No
  `<OWNER>`/`<REPO>`/`<BRANCH>` placeholder exists anywhere in this file" — using the literal placeholder
  tokens to state their absence. The plan's own acceptance criterion greps for those exact literal strings
  (`grep -Ec "<OWNER>|<REPO>|<BRANCH>|<YOUR_"`) and expects 0, so the sentence about their absence would
  itself have caused the criterion to fail.
- **Fix:** Reworded to "No owner-name, repo-name, or branch-name placeholder token exists anywhere in this
  file" — same meaning, no literal-token collision.
- **Files modified:** `repos/security-platform/.github/workflows/pr-security.yml`
- **Verification:** `grep -Ec "<OWNER>|<REPO>|<BRANCH>|<YOUR_" .github/workflows/pr-security.yml` returns 0.
- **Committed in:** `7413825` (Task 2 commit; the fix was made before the commit, not as a follow-up)

---

**Total deviations:** 2 (both self-caught comment-wording fixes before commit, same category as 20-03's
prior fix of this kind)
**Impact on plan:** Both deviations were necessary to satisfy the plan's own acceptance criteria without
weakening the explanatory content. No scope creep — only the three declared `files_modified` files were
touched, in `repos/security-platform`, and both fixes are wording-only.

## Issues Encountered

- The worktree's initial HEAD was on a genuinely disjoint history from the plan's expected base (`git
  merge-base` returned exit 1 with no output, confirmed via root-commit comparison to be two unrelated
  histories, not a fast-forward case). Resolved via the sanctioned `git reset --hard` in the
  `worktree_branch_check` step; documented above under Setup Deviation.
- Several compound Bash commands (a `python3 -c` invocation shelling out to `git show`, and a piped
  `bash ... | tail` with `${PIPESTATUS[0]}`) were rejected by the worktree-isolation guard as "too complex to
  verify" — consistent with 20-02/20-03's prior findings. Resolved by writing intermediate git-show output to
  a file first, then reading it with plain Python, and by running the parity script without a pipe.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `repos/security-platform` is at `7413825` on `feature/phase-20-template-packaging`, pushed to origin;
  later plans in this phase should continue building on it directly.
- Plans 08/09 (adoption guide authoring) can quote this plan's banner text verbatim rather than re-deriving
  it: the canonical-copy banner in `security.yml`, the caller banner in `pr-security.yml` (including the
  exact Mode A/Mode B `uses:` line difference), and the corrected `dependabot.yml` header.
- A private consumer's jobs no longer go red for a capability its repository cannot have, and no assertion
  was deleted to achieve that — the six SARIF verify steps skip cleanly; the five artifact verify steps and
  all upload steps are unaffected.
- `requirements.mark-complete` deliberately NOT invoked for DIST-06/DIST-07 — plan 12 owns that closure per
  20-01's carried-forward note.

## Self-Check: PASSED

- `.planning/phases/20-template-packaging-and-adoption-docs/20-04-SUMMARY.md` — FOUND
- Commit `fbca578` (Task 1, `repos/security-platform`) — FOUND in `git log --oneline --all` (repos/security-platform)
- Commit `7413825` (Task 2, `repos/security-platform`) — FOUND in `git log --oneline --all` (repos/security-platform)
- `repos/security-platform` pushed to `origin/feature/phase-20-template-packaging` — confirmed via `git push` output for both tasks
- All four gates (`actionlint`, `yamllint -d relaxed`, `check-workflow-uploads.sh`, `check-detector-parity.sh`) confirmed exit 0 after both tasks

---
*Phase: 20-template-packaging-and-adoption-docs*
*Completed: 2026-09-14*
