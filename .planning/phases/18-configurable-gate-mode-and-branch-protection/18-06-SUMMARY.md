---
phase: 18-configurable-gate-mode-and-branch-protection
plan: "06"
subsystem: docs
tags: [documentation, branch-protection, rulesets, gate-mode, required-checks]

# Dependency graph
requires:
  - phase: 18-configurable-gate-mode-and-branch-protection
    plan: "04"
    provides: "live report-only baseline measurement (5 green checks, 5 gate_mode=report-only log lines)"
  - phase: 18-configurable-gate-mode-and-branch-protection
    plan: "05"
    provides: "live blocking-mode measurement (5 red checks, same tree, single GATE_MODE flip) and the closed leave-unrequired decision"
provides:
  - "Corrected Phase 2 branch-protection passage in development-security-stack-option-1.md: ruleset navigation with the classic-404 caveat, gate_mode documented in both consumption modes, the severity answer with its pip-audit reason, the five byte-exact required contexts with source endpoint and pending-check warning, the pull_request rule with the read-modify-write warning, the D-07 adoption order, and the strict-policy/fork-variable caveats"
  - "Corrected M2-F4 section in milestone-plan/milestone-2-cicd-gate.md: same ruleset path, same five byte-exact contexts, corrected Done Criteria pointing at rules/branches/main, a new Done Criteria line for the gate flag, and a pointer to the blueprint passage — while M2-F1's genuinely-correct job-id list (line 30) is untouched"
affects: [18-07, 18-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two documents describing the same procedure must both be corrected in the same plan and cross-referenced (milestone plan now points to the blueprint) rather than the fuller explanation being duplicated twice"

key-files:
  created: []
  modified:
    - docs/development-security-stack-option-1.md
    - docs/milestone-plan/milestone-2-cicd-gate.md

key-decisions:
  - "The milestone-plan's Done Criteria line for the classic-404 caveat could not literally contain the substring 'Settings > Branches' even as a negative example — the plan's own verify script asserts that substring is absent anywhere in the file. Reworded to 'the classic branch-protection settings screen' to preserve the caveat's meaning without tripping the check."
  - "L2028's pre-existing closing paragraph ('Without branch protection...') was kept verbatim at the end of the rewritten block per the plan's explicit instruction that it is correct and must survive."

requirements-completed: [CICD-04, CICD-06]

# Metrics
duration: ~15min
completed: 2026-09-12
---

# Phase 18 Plan 06: Corrected Branch-Protection Guidance Summary

**Rewrote the blueprint's and the milestone plan's Phase 2 / M2-F4 branch-protection passages so a reader ends up with the five byte-exact `security / …` check-run contexts and ruleset navigation instead of five job ids that sit permanently pending and a classic-protection screen that 404s.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-09-12
- **Completed:** 2026-09-12
- **Tasks:** 2 of 2
- **Files modified:** 2

## Accomplishments

- The blueprint's Phase 2 deliverable block (~L2019-2028) now carries all seven required elements: ruleset navigation with the classic-404 note, `gate_mode` documented as both a `workflow_call` input and the `GATE_MODE` repo variable (with the measured green-to-red flip), the severity answer (any finding fails, per-tool native detection, with the pip-audit no-severity-field reason), the five byte-exact contexts sourced from the check-runs API with the pending-not-failing warning, the `pull_request` rule with the read-modify-write ruleset-API warning, the D-07 adoption order (report-only confirm, then blocking confirm, then require), and the strict-policy/fork-variable caveats.
- L2028's pre-existing closing paragraph, confirmed correct by the plan, survives byte-identical at the end of the rewritten block.
- The three out-of-scope adjacent lines (`Grype + Syft` at L2012, `and direct pushes to \`main\`` at L2016, `grype dir:.` at L2039) are unchanged — confirmed present byte-identical after the edit.
- The milestone plan's M2-F4 section now matches the blueprint's corrected path (ruleset navigation, five byte-exact contexts, `rules/branches/main` as the authoritative read) in its own terse voice, with a pointer to the blueprint for the full procedure and a new Done Criteria line for the gate flag's report-only/blocking pair.
- M2-F1's line 30 job-id list (`sast`, `iac`, `sca`, `container`, `secrets`) — genuinely correct there, since those are the actual job ids in `security.yml` — is untouched.
- A `docs/`-wide grep for the defect string `Required status checks: \`sast\`` returns no matches anywhere.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite the blueprint's Phase 2 branch-protection passage** - `eb5666e` (docs)
2. **Task 2: Correct the same defect in the milestone plan's M2-F4 section** - `66b7e63` (docs)

`git diff HEAD~1 HEAD --name-only` for each commit confirmed exactly one file per commit.

## Files Created/Modified

- `docs/development-security-stack-option-1.md` — Phase 2 deliverable block (~L2019-2028) rewritten in place with the seven required elements; code-fence count unchanged (134 before and after); live 40-hex SHA count unchanged (0 before and after)
- `docs/milestone-plan/milestone-2-cicd-gate.md` — M2-F4's Key Components and Done Criteria corrected; M2-F1's line 30 (job ids, correct there) untouched

## Required Output: Before/After Text

### Blueprint (`docs/development-security-stack-option-1.md`, ~L2019-2028)

**Before:**
```
- Branch protection configured on the `main` branch (required — without this, the CI security gate is advisory-only and provides zero enforcement)

  **Configure in GitHub:** Settings → Branches → Branch protection rules → Add rule
  - Branch name pattern: `main`
  - Enable: **Require a pull request before merging**
  - Enable: **Require status checks to pass before merging** — add each security workflow job as a required check: `sast`, `iac`, `sca`, `container`, `secrets`
  - Enable: **Do not allow bypassing the above settings**
  - Enable: **Restrict who can push to matching branches** (block direct pushes to `main`)

  Without branch protection, a developer can push directly to `main` (bypassing all PR-based scanning), and failing scanner jobs have no effect on merge eligibility. The `continue-on-error` changes described above only enforce quality gates when branch protection makes those status checks required.
```

**After:** ruleset navigation with the classic-404 caveat; `gate_mode` in both consumption modes with the measured green-to-red flip; the severity answer with the per-tool mechanism table and the pip-audit reason; the five byte-exact `security / …` contexts with their check-runs API source and the pending-check warning; the `pull_request` rule with the read-modify-write ruleset-API warning; the D-07 adoption order; the strict-policy and fork-variable caveats; L2028's original closing paragraph retained verbatim. Full text is in the committed file at commit `eb5666e`.

### Milestone plan (`docs/milestone-plan/milestone-2-cicd-gate.md`, M2-F4)

**Before:**
```
**Key Components:**

- GitHub repository Settings > Branches > Branch protection rules
- Required status checks: `sast`, `iac`, `sca`, `container`, `secrets`
- Require PR before merging
- Do not allow bypassing the above settings
- Restrict direct pushes to `main`

**Done Criteria:**

- `git push origin main` from a local branch is rejected by GitHub with a branch protection error
- A PR with a failing required status check shows the merge button as disabled/blocked
- A PR with all 5 status checks passing can be merged
- Settings > Branches shows the protection rule active on `main` with all required checks listed
```

**After:**
```
**Key Components:**

- GitHub repository Settings > Rules > Rulesets (this stack governs `main` via a ruleset, not classic branch protection)
- Required status checks, byte-exact, read from the check-runs API: `security / SAST — Semgrep CE`, `security / IaC — Checkov`, `security / SCA — Trivy Filesystem`, `security / Container — Trivy Image`, `security / Secrets — Gitleaks` — sourced from `gh api repos/OWNER/REPO/commits/SHA/check-runs`; the caller job (`security`) contributes only the `<job> / <job>` prefix and emits no check run of its own, so this list is five contexts, not six
- Require PR before merging
- Do not allow bypassing the above settings
- Restrict direct pushes to `main`
- See the blueprint's Phase 2 branch-protection passage (`development-security-stack-option-1.md`) for the full adoption procedure, including the ruleset-API read-modify-write warning and the fork-variable caveat

**Done Criteria:**

- `git push origin main` from a local branch is rejected by GitHub with a branch protection error
- A PR with a failing required status check shows the merge button as disabled/blocked
- A PR with all 5 status checks passing can be merged
- `gh api repos/OWNER/REPO/rules/branches/main` shows the ruleset active on `main` with all five required contexts listed — not the classic branch-protection settings screen, which 404s on a ruleset-governed repository by design and is not evidence of anything
- The same PR observed `success` on all five checks in `report-only` and `failure` on all five in `blocking`, switched by the `GATE_MODE` repository variable alone with no YAML edit
```

## Verification Evidence

- **Code-fence count:** 134 before, 134 after (unchanged).
- **Live 40-hex SHA count:** 0 before, 0 after (unchanged) — ADR-004's placeholder convention preserved.
- **Out-of-scope lines confirmed unchanged:** `Grype + Syft` (L2012), `` and direct pushes to `main` `` (L2016), `` grype dir:. `` (L2039) — all present byte-identical after the edit.
- **Milestone plan `` `sast` `` survivor:** exactly one line still mentions `` `sast` `` — line 30, `` - `.github/workflows/security.yml` with 5 jobs: `sast`, `iac`, `sca`, `container`, `secrets` `` — which is M2-F1's genuinely-correct job-id list, untouched.
- **`docs/`-wide grep** for `` Required status checks: `sast` `` returns no matches — "no remaining occurrence of the defect anywhere under docs/".
- **Per-commit diffs:** `git diff HEAD~1 HEAD --name-only` on each commit lists exactly one file (`docs/development-security-stack-option-1.md` for Task 1, `docs/milestone-plan/milestone-2-cicd-gate.md` for Task 2). No deletions in either commit.

## Decisions Made

See `key-decisions` in frontmatter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Milestone-plan Done Criteria line tripped its own negative-grep verify check**
- **Found during:** Task 2 verification, first run of the automated check
- **Issue:** The plan's own verify script asserts `assert "Settings > Branches" not in src`. My first draft of the corrected Done Criteria line used the phrase "not `Settings > Branches`" as a negative example (to explain why the classic screen is not evidence), which itself contains the banned substring and failed the check.
- **Fix:** Reworded to "not the classic branch-protection settings screen" — same meaning, no longer contains the literal string the check bans.
- **Files modified:** `docs/milestone-plan/milestone-2-cicd-gate.md`
- **Verification:** Re-ran the automated verify script; all assertions passed.
- **Commit:** `66b7e63` (the reword landed in the same Task 2 commit, before it was made — no separate fix commit needed).

**Total deviations:** 1 auto-fixed (Rule 3, wording adjustment caught by the plan's own verification before commit; no scope change).
**Impact on plan:** None — both files carry exactly the content the plan specified, worded to satisfy the plan's own automated checks.

## Issues Encountered

None beyond the one deviation above, caught and fixed before either commit.

## User Setup Required

None. Both edits are documentation-only, no infrastructure or credential setup required.

## Next Phase Readiness

- CICD-04's guidance deliverable (the written branch-protection procedure) and CICD-06's flag documentation now have a correct written home in both user-facing documents.
- Success Criterion 4 (severity answer) and Success Criterion 2 (both consumption modes documented) are satisfied by this plan's text.
- 18-07 (ADR-017) and 18-08 (merge) can proceed; no blocking issues carried forward from this plan.

---
*Phase: 18-configurable-gate-mode-and-branch-protection*
*Completed: 2026-09-12*

## Self-Check: PASSED

- FOUND: docs/development-security-stack-option-1.md
- FOUND: docs/milestone-plan/milestone-2-cicd-gate.md
- FOUND: .planning/phases/18-configurable-gate-mode-and-branch-protection/18-06-SUMMARY.md (this file)
- FOUND: commit eb5666e (Task 1)
- FOUND: commit 66b7e63 (Task 2)
