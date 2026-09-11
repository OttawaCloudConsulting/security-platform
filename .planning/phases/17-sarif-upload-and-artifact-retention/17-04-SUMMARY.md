---
phase: 17-sarif-upload-and-artifact-retention
plan: 04
subsystem: infra
tags: [github-actions, upload-artifact, retention, defectdojo, sca, globs, artifact-retention]

# Dependency graph
requires:
  - phase: 15-five-parallel-scan-jobs
    provides: "the five parallel scan jobs and the report filenames each writes"
  - phase: 16-sca-ecosystem-coverage
    provides: "the sca job's npm/pip/tflint sub-scans, whose npm and pip reports are NUMBERED per input and therefore must be globbed"
  - phase: 17-sarif-upload-and-artifact-retention
    provides: "17-01: scripts/check-workflow-uploads.sh, whose ARTIFACT-RETENTION, ARTIFACT-PATH-SAFETY and UPLOAD-VERIFY-PAIRING checks were vacuous until this plan; 17-02: trivy-fs.sarif; 17-03: the six SARIF upload/verify pairs whose shape this plan copies"
provides:
  - "Five SHA-pinned actions/upload-artifact steps — one per scan job — with five names unique across the run, explicit retention-days: 90, and an explicit if-no-files-found per job"
  - "A glob-based SCA artifact (npm-audit-*.json, pip-audit-*.json) that survives a consumer repo missing an ecosystem instead of turning the job red"
  - "Five intolerant artifact landing assertions reading steps.<id>.outcome, so ADR-001's continue-on-error on the upload can no longer retain nothing silently"
  - "A reworded container-job security comment that no longer claims github.sha is the only context interpolation in the file"
affects: [17-05, 17-06, 17-07, 18-gate-mode-and-branch-protection, 20-distribution, DEFECT-01]

# Tech tracking
tech-stack:
  added:
    - "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a (v7.0.1) — first use of this action in the product repo"
  patterns:
    - "Artifact retention in each tool's NATIVE format, unnormalised: DefectDojo's dojo/tools/ already ships checkov, gitleaks, npm_audit_7_plus, pip_audit, sarif, semgrep, tflint and trivy parsers, so a common-schema layer would destroy import fidelity for DEFECT-01."
    - "Comments that document a `path: |` block scalar go ABOVE the key, never on its lines: a literal block scalar has no comment syntax and a trailing `#` becomes part of the path string — which would fail both this plan's inline assertion and 17-01's ARTIFACT-PATH-SAFETY gate."
    - "if-no-files-found is chosen per job from whether its reports are unconditional (error) or ecosystem-conditional (warn), never set globally."

key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml

key-decisions:
  - "The Phase 16 hand-forward glob note could NOT be written as a trailing comment on the npm/pip path lines as the plan text instructs. YAML literal block scalars have no comment syntax, so `npm-audit-*.json   # GLOB …` parses as one path string containing the comment. It was placed as YAML comment lines immediately above `path: |`, naming both glob lines explicitly, and the reason for that placement is itself recorded in the file."
  - "`bash scripts/check-workflow-uploads.sh` CANNOT exit 0 after Task 1 alone, contradicting Task 1's own acceptance criterion. Task 1 mandates `id: artifact-*` on all five uploads and check 8 (UPLOAD-VERIFY-PAIRING) fires on every id'd upload with no later `steps.<id>.outcome` reader — the readers are Task 2's deliverable. Task 1 was committed with the gate at exit 1 showing exactly 5 failures, all UPLOAD-VERIFY-PAIRING, one per artifact id, and nothing else; the gate returns to exit 0 at Task 2. The gate is not a pre-commit hook (verified), so no `--no-verify` was needed and the two-commit structure was preserved."
  - "The fork/Dependabot guard on the five ARTIFACT verify steps is applied for UNIFORMITY with 17-03's six SARIF verify steps, not because it was measured. upload-artifact authenticates with ACTIONS_RUNTIME_TOKEN rather than GITHUB_TOKEN, so it may well succeed on fork and Dependabot runs where a SARIF upload cannot. The file states this as an open observation handed to Phase 18, not as a fact."
  - "The container job's stale comment at the `Build fixture image` step (17-03-SUMMARY issue #3) was reworded inside Task 2's commit rather than in a third commit, because Task 2 is what adds twenty more step-outcome/artifact-id interpolations to that same file. The security CLAIM was already true and is unchanged; only the count was wrong."
  - "`overwrite`, `include-hidden-files` and `archive` are absent from all five `with:` blocks, asserted. Each default is load-bearing: overwrite: true would MASK a name collision, include-hidden-files: true would sweep dotfiles into a world-downloadable archive on this PUBLIC repo, and archive: false ignores `name` and fails on a multi-file glob."

patterns-established:
  - "A tolerated upload's landing assertion echoes the server-generated identifiers (artifact-id, artifact-url) into the job log, so a later live-verification plan has a run-local record to cross-check against the `gh api` listing rather than trusting the API alone."
  - "When a plan's own acceptance criterion is unsatisfiable at the commit boundary it mandates, verify the FAILURE SHAPE rather than skipping the check: predict the exact failing check names and count, run it, and commit only if the observed failures match the prediction exactly."

requirements-completed: [CICD-03]

# Metrics
duration: 14min
completed: 2026-09-11
---

# Phase 17 Plan 04: Five Artifacts, Five Names, An Explicit Expiry, And No Way To Lose One Quietly

**Every scan job now ends by uploading its native JSON and SARIF reports as one uniquely-named artifact with a stated 90-day expiry — the SCA one globbing 16-04's numbered npm and pip reports — and each of those tolerated uploads is read back by an intolerant step, so CICD-03 cannot retain nothing on a green run.**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-09-11T19:07:59Z
- **Completed:** 2026-09-11T19:22Z
- **Tasks:** 2
- **Files modified:** 1 (0 created, 1 modified)

## Accomplishments

- **Five artifacts, five distinct names, zero new jobs.** `upload-artifact` v7.0.1 defaults `overwrite` to
  false and fails on a duplicate name, so five parallel jobs genuinely require five names; the job count,
  the five frozen check-run names and the zero-`needs:` shape are all unchanged.
- **The SCA globs are the whole point of the plan and they survive a missing ecosystem.** `npm-audit-*.json`
  and `pip-audit-*.json` carry 16-04's per-input numbering, and `if-no-files-found: warn` on that job alone
  means a consumer repo with no `package-lock.json` still produces an `sca-results` artifact instead of a
  red job. `trivy-fs.json` is unconditional, so the artifact is never empty.
- **17-01's gate stopped being vacuous.** ARTIFACT-RETENTION, ARTIFACT-PATH-SAFETY and the artifact half of
  UPLOAD-VERIFY-PAIRING had no subjects until this plan. The gate was observed FAILING with exactly the
  five predicted pairing failures after Task 1, and back at `PASS - 10 checks, 0 failures` after Task 2.
- **The stale security comment 17-03 flagged is fixed.** It no longer claims `github.sha` is the only
  context interpolation in any `run:` block — a claim that stopped being true at 17-03 and would have been
  twenty interpolations further from true after this plan.
- **No regression in what the scanners find.** The full local gate reproduced 17-02's baseline exactly.

## Task Commits

1. **Task 1: Add the five per-job artifact uploads with explicit retention** — `4355f10` (feat)
2. **Task 2: Pair each artifact upload with an intolerant landing assertion and run the full local gate** — `803f988` (feat)

Both commits are on `feature/phase-17-sarif-upload-and-artifact-retention` in the nested product repo
`repos/security-platform`, continuing 17-01/17-02/17-03's branch (`34cd158`, `66a18ad`, `a3f9dac`,
`f3e6dec`, `7525ad2`, `9692fa7`). Committed with hooks (yamllint Passed on both); `--no-verify` was not
used. **Nothing pushed, no live run — that is 17-05.**

## Files Created/Modified

- `repos/security-platform/.github/workflows/security.yml` — ten steps added across the five jobs
  (+126 in Task 1, +106/−2 in Task 2; the two deletions are the reworded comment lines). No existing step
  was modified, renamed or reordered. File is now 962 lines.

## Required Output: Observed Evidence

Every value below is parsed from the **committed** file (`git show HEAD:.github/workflows/security.yml`),
not the working tree.

### 1. The five artifact names and their exact path lists

| Job | Step id | Artifact `name` | `path` lines, in order | `if-no-files-found` | `retention-days` |
|-----|---------|-----------------|------------------------|---------------------|------------------|
| `sast` | `artifact-sast` | `semgrep-results` | `semgrep-results.json`, `semgrep.sarif` | `error` | `90` (int) |
| `iac` | `artifact-iac` | `checkov-results` | `checkov-results.json`, `checkov.sarif` | `error` | `90` (int) |
| `sca` | `artifact-sca` | `sca-results` | `trivy-fs.json`, `trivy-fs.sarif`, `npm-audit-*.json`, `pip-audit-*.json`, `tflint.sarif` | **`warn`** | `90` (int) |
| `container` | `artifact-container` | `trivy-image-results` | `trivy-image.json`, `trivy-image.sarif` | `error` | `90` (int) |
| `secrets` | `artifact-secrets` | `gitleaks-results` | `gitleaks-results.json`, `gitleaks.sarif` | `error` | `90` (int) |

Five names, five distinct values, five distinct step ids. Every path line matches
`^[A-Za-z0-9_.*-]+\.(json|sarif)$` — no directory component, no `**`, no bare `.`. All five pinned to
`actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1`; a grep of that exact
pin-plus-comment string returns **5**, and the stale v4 SHA appears **0** times. `retention-days` is a
YAML integer in every case, not the string `"90"` — the gate's `type(retention) is not int` check exists
because `bool` subclasses `int` and would otherwise let `retention-days: true` read as 1.

`overwrite`, `include-hidden-files` and `archive` are absent from all five `with:` blocks.

### 2. `if-no-files-found` per job, and why `sca` differs

`error` on `sast`, `iac`, `container` and `secrets`: each of those jobs writes both of its files
unconditionally, so a missing one is a real failure that must not pass quietly.

`warn` on `sca` and **only** on `sca`: three of its five entries (`npm-audit-*.json`, `pip-audit-*.json`,
`tflint.sarif`) are ecosystem-conditional. In a consumer repo without a `package-lock.json` the npm glob
matches nothing, and `error` there would turn a clean, correct skip red — re-breaking the Criterion 4 skip
behaviour Phase 16 spent a plan proving. `trivy-fs.json` is unconditional, so the artifact is never empty.

### 3. The `ALL PASS` gated-run count from the regression run

```
ALL PASS - 10 gated scan run(s) produced real, non-empty findings; 0 sub-check(s) skipped (not passed).
```

**10 gated runs, 0 skipped — identical to the baseline `17-02-SUMMARY.md` recorded.** Nothing in 17-03 or
17-04 changed what the scanners find, which is what this run was spent to confirm. The Criterion 4
clean-skip negative test also still passes on all three ecosystems (`skip-npm`, `skip-python`,
`skip-terraform`, each rc=0 with a `SKIP:` line and no list file written).

## Other Verification

| Check | Result |
|---|---|
| Task 1 inline YAML parse (5 uploads: pin, id, name, `always()`, continue-on-error, retention 90, if-no-files-found, exact path list, safe-path regex, forbidden keys absent, step last in job, names unique, 5 jobs / 0 needs) | all pass |
| Task 2 inline YAML parse (5 paired intolerant verifies, guard clauses, artifact-id echoed, verify last in job; whole-file 11 uploads and 11 intolerant `.outcome` assertions) | all pass |
| `bash scripts/check-workflow-uploads.sh` after Task 1 | **exit 1, 5 failures, all UPLOAD-VERIFY-PAIRING** — exactly as predicted; see Deviations |
| `bash scripts/check-workflow-uploads.sh` after Task 2 | exit 0 — `PASS - 10 checks, 0 failures` |
| `yamllint -d relaxed .github/workflows/security.yml` | exit 0 (line-length warnings only, as before) |
| Stale v4 SHA `ea165f8d…` | 0 occurrences |
| `--redact` count, full-line comments filtered | exactly 2 (both Gitleaks invocations) |
| Five job `name:` values | `['SAST — Semgrep CE', 'IaC — Checkov', 'SCA — Trivy Filesystem', 'Container — Trivy Image', 'Secrets — Gitleaks']` — byte-identical, em dash intact |
| Job shape | 5 jobs, zero `needs:` |
| `outputs.artifact-url` echoes | 5 (one per verify step) |
| `bash scripts/smoke-scans.sh` | `ALL PASS - 10 gated scan run(s) … 0 sub-check(s) skipped` |
| Pre-commit hooks on both commits | yamllint Passed; no `--no-verify` used |

## Decisions Made

See `key-decisions` in the frontmatter. The two a later reader is most likely to "correct" wrongly:

**The glob comment is above `path:`, not on the glob lines, and that is not sloppiness.** The plan text,
17-RESEARCH's Code Examples and 17-PATTERNS' target shape all show `npm-audit-*.json            # GLOB —
Phase 16 hand-forward #1` as a trailing comment inside the block scalar. YAML literal block scalars have
no comment syntax: that line parses as the single path string
`npm-audit-*.json            # GLOB — Phase 16 hand-forward #1`, which fails this plan's own `got == paths`
assertion, fails its `^[A-Za-z0-9_.*-]+\.(json|sarif)$` safe-path assertion, and fails 17-01's
ARTIFACT-PATH-SAFETY gate check. Moving those comments onto the path lines would break the build.

**`if-no-files-found: warn` on `sca` is not an inconsistency to tidy up.** It is the only correct value
there, for the reason in section 2 above. Setting it to `error` for uniformity re-breaks Criterion 4.

## Deviations from Plan

**1. The glob comments were placed above `path: |` rather than on the glob lines.** Forced by YAML — see
Decisions Made. The substance the plan asked for (Phase 16 hand-forward #1: numbered per input, glob and
never name) is recorded in full, explicitly naming both glob lines, and the placement reason is recorded
in the file so the next reader does not "fix" it back.

**2. Task 1's acceptance criterion "`bash scripts/check-workflow-uploads.sh` exits 0" was unsatisfiable at
Task 1's commit boundary, and was replaced with a failure-shape assertion.** Task 1 mandates `id:` on all
five uploads; gate check 8 fires on every id'd `actions/upload-artifact` step with no later
`steps.<id>.outcome` reader in the same job, and those readers are Task 2's deliverable. This is a
plan-internal contradiction, not a defect in the workflow or the gate — and it is the same class of issue
17-01 anticipated when it recorded that the gate "deliberately asserts NO counts … so it passes at every
intermediate commit of the phase". Check 8 is the one check that cannot honour that intent across a
split-task plan. 17-03 never hit it because it added each upload and its verify in the same task.

Handled as follows, before committing anything: `.pre-commit-config.yaml` was grepped and confirmed NOT to
run this gate (only yamllint, gitleaks and eight file-type hooks), so no `--no-verify` was ever in play and
merging the two tasks — which would have broken the plan's "two `feat(17-04):` commits" requirement — was
unnecessary. The gate was then run with an explicit prediction: exit 1, exactly five failures, all
`UPLOAD-VERIFY-PAIRING`, one per `artifact-*` id, and nothing from ARTIFACT-RETENTION or
ARTIFACT-PATH-SAFETY. That is precisely what was observed. Every other Task 1 acceptance criterion passed
before the commit, and the gate returned to exit 0 at Task 2 as designed.

**3. The stale container-job comment was reworded (17-03-SUMMARY issue #3).** Not in this plan's task text;
carried in on the orchestrator's instruction and folded into Task 2's commit rather than a third commit, so
the plan's "two commits, both `feat(17-04):`" verification still holds. The commit body names it.

## Issues Encountered

**1. The `path: |` comment trap, caught before the first commit.** Described in Deviations #1. Worth
recording for 17-06 and Phase 20: any future edit that "restores" the canonical RESEARCH snippet verbatim
will break the workflow, and the gate will catch it — the failure message will complain about a path line
containing a `#`, which reads as a mystery until you know this.

**2. The gate-cannot-pass-mid-plan contradiction.** Described in Deviations #2. **Hand-forward:** if a
future plan splits an upload from its verify across tasks again, it must either predict the pairing
failure the same way or accept merging the tasks. 17-01's scope note ("do not 'complete' this script by
adding a count") should be read alongside this: check 8 already behaves like a count in the one case where
an upload exists without its reader.

**3. Not a defect — an open observation for Phase 18, also written into the file.** The fork/Dependabot
guard on the five artifact verify steps is unmeasured. `actions/upload-artifact` uploads via
`ACTIONS_RUNTIME_TOKEN`, not `GITHUB_TOKEN`, so unlike a SARIF upload it may well succeed on a fork PR or a
Dependabot PR. If it does, these five assertions are skipping on runs where they could be proving
something. Measuring that is a Phase 18 question; guessing at it in this plan would have meant a verify
step failing on an unverified assumption, which is worse than one that skips.

**4. Carried forward from 17-03 and still true.** `github.event.pull_request.head.repo.full_name` is empty
on a `push` or `workflow_dispatch` caller, so all eleven verify steps skip silently there. Correct under
D-02, but a Phase 20 consumer wiring this reusable workflow into a `push` trigger would reopen ADR-001's
blind spot for artifacts as well as SARIF. Worth naming in the adoption docs.

No unresolved issues.

## User Setup Required

None. Nothing was pushed and no PR was opened; the phase branch is local to `repos/security-platform` and
merges in 17-07 after human sign-off.

## Next Phase Readiness

- **CICD-03 is now statically complete and marked Complete in `.planning/REQUIREMENTS.md`.** Five jobs,
  five uniquely-named artifacts, an explicit 90-day expiry on every one, and five intolerant assertions
  that the uploads landed. Nothing has actually been uploaded yet.
- **17-05 (live run) is what turns both CICD-02 and CICD-03 into observed evidence.** It must run on a
  **same-repo, non-Dependabot PR** or all eleven verify steps skip rather than prove anything. Cross-check
  the five `artifact-id` / `artifact-url` values echoed into the job logs against
  `gh api /repos/{owner}/{repo}/actions/runs/{id}/artifacts` — the log values are the run-local record
  those five echoes exist to provide, and the listing should show exactly five artifacts with `expired:
  false` and a 90-day `expires_at`.
- **17-06 (ADR-016) inherits the DefectDojo parser rationale intact:** native formats, unnormalised, with
  `npm_audit_7_plus` (not the legacy `npm_audit`) as the applicable npm parser because the runner ships
  npm 10.x. That, plus 17-02's note that the container job's `trivy convert` is the only surviving
  conversion step, is what ADR-016 records.
- **Phase 18** is handed one genuinely open question by this plan (issue #3 above) and inherits the same
  frozen five check-run names, unchanged.
- **No blockers.**

---
*Phase: 17-sarif-upload-and-artifact-retention*
*Completed: 2026-09-11*
