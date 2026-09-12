---
phase: 18-configurable-gate-mode-and-branch-protection
plan: "08"
subsystem: infra
tags: [github-actions, gate-mode, branch-protection, merge, remote-verification, phase-close]

# Dependency graph
requires:
  - phase: 18-configurable-gate-mode-and-branch-protection
    plan: "07"
    provides: "ADR-017 (Accepted, indexed) and the observation that PR #9 was found already merged (mergedAt 2026-09-12T12:48:34Z, merge commit 2e29004) before this plan began"
provides:
  - "Remote-verified confirmation that origin/main carries everything reviewed: eleven gate expressions, zero literal `# D-04` tolerances, eleven ADR-001 tolerances, five `Validate gate_mode` steps, five jobs, the `gate_mode` input, the exact env.GATE_MODE chain"
  - "Merge-commit second-parent tree hash (ce7ec652...) proven identical to 18-05's report-only-restore tree — what was reviewed is what shipped, not inferred"
  - "actionlint, yamllint -d relaxed, and check-workflow-uploads.sh all exit 0 against the merged state (origin/main), extracted via a detached worktree"
  - "gh variable list confirms no GATE_MODE; rules/branches/main confirmed unchanged (deletion, non_fast_forward) matching the operator's 18-05 leave-unrequired decision"
  - "Four ROADMAP Phase 18 criteria scored with verdicts and evidence, quoted verbatim"
  - "Local nested checkout hygiene: local main fast-forwarded to origin/main (40682ce -> 2e29004); phase branch confirmed deleted on the remote after merge (404); detached worktree used for gate extraction removed and pruned"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extract origin/main into a detached `git worktree` to run local linters/scripts against the merged state without disturbing the local checkout's own branch"
    - "grep -c on a literal string containing `${{ }}` needs -F (fixed-string) or the match silently returns 0 even though the substring is present — verify with awk or -F before trusting a 0 count"
    - "Tie a merge's second parent's tree hash back to the pre-merge measured tree hash (`git rev-parse <merge>^2^{tree}`) as the strongest available proof that what was reviewed is what shipped"

key-files:
  created:
    - .planning/phases/18-configurable-gate-mode-and-branch-protection/18-08-SUMMARY.md
  modified: []

key-decisions:
  - "Task 1's checkpoint is satisfied-by-fact: PR #9 was already MERGED by the human operator (OttawaCloudConsulting, is_bot=false) at mergedAt=2026-09-12T12:48:34Z, mergeCommit=2e290042a775ff1c442bac75757ef8d0106d7dc3, before this plan's execution began — confirmed via `gh pr view 9 --json state,mergedAt,mergedBy,mergeCommit`. The operator separately confirmed via the orchestrator that this was intentional. No `gh pr merge` command ran in this session. Task 1's own acceptance criteria (present evidence, then wait for literal approval) could not be satisfied in the original sense since there was nothing left to approve — the merge decision has already been made and acted on."
  - "REQUIREMENTS.md was NOT edited by this plan. CICD-04 and CICD-06 were already `[x]` in the checkbox list and already `Complete` in the traceability table, flipped by commit 1f19058 (18-06's plan-close commit, 2026-09-12T08:58:02-0400 = 12:58:02Z) via the generic `requirements.mark-complete` state-update step, triggered by 18-06's own frontmatter `requirements: [CICD-04, CICD-06]` field. That flip landed roughly 10 minutes AFTER the human merge (12:48:34Z) but BEFORE any post-merge remote verification — the exact ordering violation T-18-27 and this plan's own notes exist to prevent (the 17-01 precedent: 'flipped two requirements early and had to revert them'). This plan's independent post-merge verification (below) now confirms the marking is factually correct, so no revert is warranted, but the premature-marking is recorded here per 17-07's precedent: 'this plan reports it as confirmed, not as marked here.'"
  - "Local nested-repo `main` branch ref was fast-forwarded (`git branch -f main origin/main`, 40682ce -> 2e29004) without checking it out — the local checkout remains on `feature/phase-17-sarif-upload-and-artifact-retention` (fbe0071), unrelated to this plan's scope, and was left as found rather than switched."

requirements-completed: []

# Metrics
duration: ~25min
completed: 2026-09-12
---

# Phase 18 Plan 08: Phase Close — Merge Was Already Done, Verified From the Remote

**PR #9 was merged by the human operator outside this session (mergeCommit `2e29004`, mergedAt `2026-09-12T12:48:34Z`); this plan performed no merge action and instead verified from `origin/main` that everything reviewed across 18-01 through 18-07 actually shipped — eleven gate expressions, zero literal `# D-04` tolerances, the exact `env.GATE_MODE` fallback chain, the merge's second-parent tree hash matching 18-05's measured tree byte-for-byte, all three standing gates green, no leftover `GATE_MODE` variable, and `rules/branches/main` unchanged at the operator's `leave-unrequired` decision.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-09-12
- **Tasks:** 2 of 2 (Task 1 satisfied-by-fact per the objective's explicit instruction; Task 2 executed in full)
- **Files modified:** 0 in `.planning/REQUIREMENTS.md` (already correct — see key-decisions); this SUMMARY plus STATE.md/ROADMAP.md via the standard state-update step

## Task 1 — Human confirmation to merge (satisfied by an already-completed merge)

**Not re-asked.** Per the objective given to this executor, PR #9 was confirmed already `MERGED` before this plan's execution began:

```
gh pr view 9 -R OttawaCloudConsulting/security-platform --json state,mergedAt,mergedBy,mergeCommit,number
{
  "state": "MERGED",
  "mergedAt": "2026-09-12T12:48:34Z",
  "mergedBy": {"login": "OttawaCloudConsulting", "name": "OCC", "is_bot": false},
  "mergeCommit": {"oid": "2e290042a775ff1c442bac75757ef8d0106d7dc3"},
  "number": 9
}
```

`mergedBy` is the repository owner, a human account (`is_bot: false`), not a bot. The operator separately confirmed via the orchestrator that this merge was intentional. **No `gh pr merge` command was run in this session** — the merge predates this plan's execution entirely (18-07's SUMMARY already flagged the merge as an unresolved fact to hand forward, having discovered it mid-task while doing an unrelated live cross-check).

Task 1's original acceptance criteria (present live evidence, ask, wait for a literal resume phrase) do not apply in their original sense — there is no pending merge decision left to present. Task 2 proceeds directly to remote verification.

## Task 2 — Verify from the remote, run the standing gates, score the four criteria

### 0. Fetch and merge-commit identification

```
cd repos/security-platform && git fetch origin
git log --oneline -5 origin/main
2e29004 Merge pull request #9 from OttawaCloudConsulting/feature/phase-18-configurable-gate-mode-and-branch-protection
835c43e chore(18-05): restore report-only after the blocking measurement
5973e8e chore(18-05): trigger a blocking-mode run on an identical tree
31dbb0d feat(18-03): add a non-destructive required-checks ruleset helper
76f70a8 docs(18-02): correct the frozen-name rationale and record why the caller passes no gate_mode
```

**What-was-reviewed-is-what-shipped, proven, not inferred:** the merge commit's second parent and its tree hash match 18-05's measured, byte-identical tree exactly:

```
git rev-parse origin/main^2            -> 835c43e8e8d7cad5276120b925ca5650a3bcda50
git rev-parse origin/main^2^{tree}     -> ce7ec652e09d07f9cee035410bbc05d47e0a79a8
```

`ce7ec652e09d07f9cee035410bbc05d47e0a79a8` is the exact tree hash 18-05 recorded as shared across all three of its measured commits (`31dbb0d`, `5973e8e`, `835c43e`). The commit that got merged is the same commit 18-05 restored to report-only and measured green on.

### 1. Content assertions on `origin/main:.github/workflows/security.yml`

| Assertion | Result |
|---|---|
| Gate expressions (`continue-on-error: ${{ env.GATE_MODE == 'report-only' }}`) | **11** — first `grep -c` attempt (without `-F`) returned a false **0** because the pattern contains `${{ }}`; re-run with `grep -cF` (fixed-string) returned 11, cross-checked with an `awk` regex match returning 11 independently. Noted here so a future reader does not repeat the false negative. |
| Literal `continue-on-error: true.*# D-04` remnants | **0** |
| `continue-on-error: true .*ADR-001` tolerances | **11** |
| `name: Validate gate_mode` steps | **5** |
| Jobs (parsed via `yaml.safe_load`) | **5** — `['SAST — Semgrep CE', 'IaC — Checkov', 'SCA — Trivy Filesystem', 'Container — Trivy Image', 'Secrets — Gitleaks']` |
| `workflow_call.inputs` contains `gate_mode` | **yes** |
| `env.GATE_MODE` | `${{ inputs.gate_mode \|\| vars.GATE_MODE \|\| 'report-only' }}` — exact chain |

### 2. Caller and helper script on `origin/main`

- `git show origin/main:.github/workflows/pr-security.yml` parsed: job `security` has **no `with:` key** and **is still named `security`** — confirmed via `yaml.safe_load` assertion.
- `git show origin/main:scripts/set-required-checks.sh` is present. `grep -c 'security / '` returned **10**, not 5 — resolved: the script lists each context twice (once in a human-readable comment block, once in the JSON-shaped required-checks array), so 10 raw hits are **5 distinct contexts**, confirmed via `sort -u` and a UTF-8 byte dump matching 18-07's em-dash (`\xe2\x80\x94`) check byte-for-byte:

```
security / Container — Trivy Image
security / IaC — Checkov
security / SAST — Semgrep CE
security / SCA — Trivy Filesystem
security / Secrets — Gitleaks
```

### 3. Standing gates against the merged state

Extracted `origin/main` into a detached worktree (`git worktree add --detach /tmp/sp-main-check origin/main`) rather than checking out the local branch, so the local checkout's own branch (`feature/phase-17-sarif-upload-and-artifact-retention`) was never disturbed:

| Gate | Result |
|---|---|
| `actionlint` | exit **0**, no output |
| `yamllint -d relaxed .github/workflows/` | exit **0** — ~135 `line-length` **warnings** (lines >80 chars on `continue-on-error` lines carrying long D-04/ADR-001 comments), **zero errors**. Recorded precisely rather than rounded to "clean." |
| `bash scripts/check-workflow-uploads.sh` | exit **0** — `PASS - 10 checks, 0 failures` |

The worktree was removed and pruned after use (`git worktree remove --force` + `git worktree prune -v`); `git worktree list` afterward shows only the nested repo's own primary checkout.

### 4. Repository state confirmation

| Check | Result |
|---|---|
| `gh variable list -R OttawaCloudConsulting/security-platform` | **empty** — no `GATE_MODE` |
| `gh api repos/OttawaCloudConsulting/security-platform/rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` — **unchanged**, matches every preflight/postflight read across 18-04, 18-05 and 18-07, and matches the operator's `leave-unrequired` decision (18-05 Task 3) |

### 5. Local checkout hygiene

| Item | Before this plan | After this plan |
|---|---|---|
| Nested `repos/security-platform` local `main` | `40682ce` (stale, 19 behind `origin/main`) | fast-forwarded to `2e290042a775ff1c442bac75757ef8d0106d7dc3` via `git branch -f main origin/main` (ref move only, not checked out) |
| Nested repo's checked-out branch | `feature/phase-17-sarif-upload-and-artifact-retention` @ `fbe0071` | unchanged — left as found; not this plan's scope |
| Remote phase branch `feature/phase-18-configurable-gate-mode-and-branch-protection` | existed (head of PR #9) | **confirmed deleted** — `gh api repos/.../branches/feature/phase-18-...` returns 404; `git branch -r \| grep phase-18` returns nothing. PR #9 metadata confirms `headRefName` and `isCrossRepository: false`, consistent with a same-repo branch auto-deleted after merge. |
| Detached verification worktree `/tmp/sp-main-check` | n/a (created during this plan) | removed and pruned |
| This docs repo's own working branch (`feature/phase-12-repo-setup-script`) | unchanged throughout | unchanged — this plan's own commits land here, not on the nested repo |

## The four ROADMAP Phase 18 criteria — quoted verbatim, scored

### Criterion 1

> "With the gate flag set to blocking, a pull request carrying a seeded finding fails its check; with the flag set to report-only, the same pull request passes."

**MET.** 18-05 measured this live on PR #9's own commits: `31dbb0d` (report-only, run 34668611172, five `success`), `5973e8e` (blocking, run 34669534855, five `failure`), `835c43e` (restored report-only, run 34669700643, five `success`) — all three on the identical tree hash `ce7ec652e09d07f9cee035410bbc05d47e0a79a8`. This plan independently confirms that exact tree hash is the one that got merged (`origin/main^2^{tree}` = `ce7ec652...`), so the measured behavior is what shipped, not a stale measurement superseded before merge.

### Criterion 2

> "The flag is settable in both consumption modes — as a `workflow_call` input when the workflow is referenced remotely, and as a repo-level variable or env when the template is copy-pasted."

**PARTIALLY MET — two halves scored separately, per the plan's explicit instruction not to round up.**

- **Repo-variable path: MET, live-observed.** 18-05 flipped `GATE_MODE` via `gh variable set`/`gh variable delete` and measured the resulting mode change directly from run logs (5× `gate_mode=blocking`, then 5× `gate_mode=report-only`), with zero YAML edits.
- **`workflow_call` input path: NOT OBSERVED live.** This plan confirms (§1 above) that `origin/main`'s `security.yml` declares `gate_mode` as a `workflow_call` input, that `actionlint` validates the workflow with that input present (exit 0), and that 18-06's blueprint/milestone-plan text documents this consumption mode — but **no second repository or caller currently passes `with: gate_mode:`** to exercise this path on a live run. 18-07's ADR-017 records this as routed to Phase 20 (template packaging), consistent with this plan's own read. Static validation and documentation are confirmed; a live remote-caller exercise is explicitly NOT OBSERVED.

### Criterion 3

> "Switching a repo between blocking and report-only requires no change to workflow YAML."

**MET.** 18-05's evidence, re-confirmed by this plan's tree-hash check: three commits (`31dbb0d`, `5973e8e`, `835c43e`) all resolve to tree `ce7ec652e09d07f9cee035410bbc05d47e0a79a8` — an explicit `git diff` between the first and last of the three produced no output. Two verdicts (`success`/`failure`/`success`), one unchanged tree, one `gh variable set`/`delete` pair. This is now further confirmed to be exactly the tree that shipped to `main`.

### Criterion 4

> "Written branch-protection configuration and steps exist for promoting the scan checks to required checks, including which severity threshold triggers a failure."

**MET**, on the terms CICD-04 itself sets: its own wording is *"config/guidance provided so scan checks can be made required (block merge) once enabled"* — satisfied by the proven `scripts/set-required-checks.sh` helper (18-03, dry-run proven non-destructive, confirmed present on `origin/main` with the five byte-exact distinct contexts in §2 above) plus the corrected written guidance in the blueprint and milestone plan (18-06) plus ADR-017 (18-07). The severity threshold: **any finding fails**, per each tool's own native exit-code/finding behavior (D-05), with the documented pip-audit exception (no severity field in its JSON, so no per-severity cutoff applies uniformly). The operator's `leave-unrequired` decision (18-05 Task 3) means this repository's own `main` does not currently enforce these as required checks — `rules/branches/main` remains `deletion`, `non_fast_forward` only — but CICD-04 asks for config/guidance to exist so checks **can be** made required, not that this repository has turned that on for itself. That distinction is the basis for the MET verdict.

## Task Commits

No code-level task commit in the nested `repos/security-platform` repository — this plan is verification-only against an already-merged state; it authored no new commit there. This docs repo receives one final commit (per the required execution order: SUMMARY written first, then committed) recording the phase close, per the parallel-executor final-commit protocol below.

## Files Created/Modified

- `.planning/phases/18-configurable-gate-mode-and-branch-protection/18-08-SUMMARY.md` (created)
- `.planning/STATE.md`, `.planning/ROADMAP.md` (updated via the standard state-update step)
- `.planning/REQUIREMENTS.md` — **NOT edited.** CICD-04 and CICD-06 were already `[x]`/`Complete` in both the checkbox list and the traceability table (flipped by commit `1f19058`, 18-06's plan-close commit, per that plan's own `requirements: [CICD-04, CICD-06]` frontmatter triggering the generic mark-complete step). This plan's independent post-merge verification above confirms that state is factually correct; see key-decisions for the full timing analysis.

## Decisions Made

See `key-decisions` in frontmatter. Most load-bearing: the merge was already done by the human operator before this plan started (Task 1 satisfied-by-fact, no merge command run in this session), and REQUIREMENTS.md's CICD-04/CICD-06 marking — while premature relative to this plan's own intended ordering — is independently confirmed correct by this plan's remote verification, so it is reported as confirmed, not re-marked.

## Deviations from Plan

### Auto-fixed Issues

None. This plan performed read-only verification and one non-destructive local ref move (`git branch -f main origin/main` in the nested repo, not checked out); no code, workflow, or requirement content was altered.

### Process deviations discovered (not caused by this plan, documented per instruction)

**1. [Pre-existing, discovered during Task 2] REQUIREMENTS.md's CICD-04/CICD-06 marking preceded post-merge verification**
- **Found during:** the initial file read for this plan, before any verification command ran
- **Issue:** `.planning/REQUIREMENTS.md` already showed CICD-04 and CICD-06 as `[x]` Complete, in both the checkbox list and the traceability table, via commit `1f19058` — 18-06's plan-close commit. 18-06's own frontmatter carried `requirements: [CICD-04, CICD-06]`, which triggered the generic executor `requirements.mark-complete` state-update step at the end of that plan's execution, independent of this plan's (18-08's) explicit "mark only after Task 2's verification" instruction. Corrected timing (per advisor review): the flip landed at `1f19058`'s commit timestamp `2026-09-12T08:58:02-0400` = `12:58:02Z`, roughly 10 minutes **after** the human merge (`12:48:34Z`) but with **no remote verification performed at that time** — so the ordering violation is "marked before verification," not "marked before merge."
- **Resolution:** Not reverted — this plan's own post-merge remote verification (Tasks 2 §0-§4 above) is now complete and confirms the marked state is factually correct. Per 17-07's precedent for an analogous already-satisfied situation: "this plan reports it as confirmed, not as marked here." REQUIREMENTS.md was left untouched by this plan.
- **Files modified:** none by this plan.
- **Committed in:** N/A — this is a report of a prior commit's behavior, not a new change.

**Total deviations:** 0 auto-fixed; 1 pre-existing process deviation discovered and reported, not corrected (correction was unnecessary since the marked state is independently verified correct).
**Impact on plan:** None on this plan's own deliverable. The premature marking is now backed by a completed verification, closing the gap it left open.

## Issues Encountered

**Tooling pitfall, resolved during verification (see §1 above):** `grep -c` on a pattern containing literal `${{ }}` returned a false `0` without `-F` (fixed-string mode); `grep -cF` and an independent `awk` regex both confirmed the true count of 11. Documented in `patterns-established` so a future plan does not repeat the false negative.

## User Setup Required

None. All actions in this plan were read-only `git`/`gh` calls plus one non-destructive local ref move.

## Next Phase Readiness

- Phase 18 is closed: merged code on `origin/main`, all four ROADMAP criteria scored with evidence (three MET, one PARTIALLY MET with its unobserved half named), CICD-04 and CICD-06 confirmed complete, and the repository left in report-only with no leftover `GATE_MODE` variable and `rules/branches/main` unchanged at the operator's decision.
- **Handoff to Phase 19 (Pipeline Validation via Branch-Target PRs):** the `workflow_call` input path (Criterion 2's unobserved half) and the fork-`vars` question (ADR-017's open item 1, routed to VAL-01) remain open for that phase to close with a live remote-caller exercise.
- **Handoff to Phase 20 (Template Packaging):** ADR-017's open item 4 (the exact `pull_request` rule parameter set for `PUT /repos/{o}/{r}/rulesets/{id}`) is still only dry-run-proven, never applied against a real ruleset — Phase 20's adoption docs should carry this caveat forward.

---
*Phase: 18-configurable-gate-mode-and-branch-protection*
*Completed: 2026-09-12*
