---
phase: 17-sarif-upload-and-artifact-retention
plan: 03
subsystem: infra
tags: [github-actions, sarif, code-scanning, upload-sarif, codeql-action, categories, fork-prs, dependabot]

# Dependency graph
requires:
  - phase: 15-five-parallel-scan-jobs
    provides: "the five parallel scan jobs and their `Show scan output files` steps"
  - phase: 16-sca-ecosystem-coverage
    provides: "the sca job's tflint pair and its steps.tf.outputs.found ecosystem guard, plus the guarded-scan/intolerant-verify idiom"
  - phase: 17-sarif-upload-and-artifact-retention
    provides: "17-01: security-events: write on both sides of the workflow_call boundary and scripts/check-workflow-uploads.sh (SARIF-CATEGORY + UPLOAD-VERIFY-PAIRING); 17-02: a correctly-based trivy-fs.sarif"
provides:
  - "Six SHA-pinned github/codeql-action/upload-sarif steps — one per SARIF file this stack produces — each with a unique category so GitHub keys the six analyses separately"
  - "Six intolerant verification steps that read steps.<id>.outcome, so ADR-001's continue-on-error on the upload can no longer hide a 403 or a wait-for-processing rejection"
  - "Five of the six verifies also print the SARIF's run count, per-run tool.driver.name and result count into the job log — the per-tool attribution evidence Criterion 1 and Phase 18 need"
  - "A fork-PR / Dependabot skip on the verify steps only, never on the upload steps"
affects: [17-04, 17-05, 17-06, 17-07, 18-gate-mode-and-branch-protection, 20-distribution]

# Tech tracking
tech-stack:
  added:
    - "github/codeql-action/upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63 (v4.38.0) — first use of this action in the repo"
  patterns:
    - "Tolerated action step (ADR-001 continue-on-error) + intolerant outcome assertion in the same job: `if [ \"${{ steps.<id>.outcome }}\" != \"success\" ]; then … exit 1; fi`. First occurrence of steps.<id>.outcome anywhere in this repo; 17-01's static gate (UPLOAD-VERIFY-PAIRING) makes the pairing permanent."
    - "Environment guards go on the ASSERTION, never on the action: a fork PR and a Dependabot PR both get a read-only GITHUB_TOKEN regardless of the `permissions` key, so the upload is left unconditional and only the check is skipped."
    - "Ecosystem guards compose with environment guards: a conditional upload and its verify carry the SAME steps.tf.outputs.found condition, so a repo without Terraform skips cleanly instead of going red."

key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml

key-decisions:
  - "One guard expression on all six verify steps, resolving 17-PATTERNS' flagged disagreement between RESEARCH Pitfall 5 (fork != true && actor != dependabot) and RESEARCH Code Examples (same-repo test only): `always() && github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'`. The same-repo form reads correctly even when the consumer repo is itself a fork; the Dependabot clause is kept because Q3/A8 is UNCONFIRMED and Phase 14 deliberately guarantees a Dependabot PR will appear."
  - "`if:` written as a single line, not a folded `>-` scalar, even at 130 characters. The file already carries 60+ over-80 lines and `yamllint -d relaxed` (the repo's chosen config, warning-level line-length) exits 0; folding would have added a second parse form of the phase's most-asserted string for zero gain."
  - "The tflint verify asserts the OUTCOME only and parses nothing. `Verify tflint SARIF` (16-04) already loads tflint.sarif and prints its rule ids; a second parse would be a second place to maintain the same assertion. A comment records that tflint.sarif carries TWO runs (`tflint`, `tflint-errors`) so no assertion anywhere may require len(runs) == 1."
  - "wait-for-processing is set nowhere — asserted absent as a key from all six `with:` blocks in the committed file. Its default of true is exactly what turns an async ingestion rejection into a step failure the outcome assertion can see."
  - "The evidence parse runs BEFORE the outcome assertion in each verify step (plan-mandated order). Consequence for 17-05: if a scanner never writes its SARIF at all, the step dies on a FileNotFoundError traceback rather than reaching the 'upload did not land' diagnosis. The job is red either way, and the job's own `Show scan output files` step reddens first with a clearer ls error."

patterns-established:
  - "Assert the CATEGORY set, not the category count: the six uploads are checked by parsing the YAML and comparing sorted(categories) to the exact expected set, because two of the six files share tool.driver.name = `Trivy` and a duplicated category would fail the second upload at run time, not at parse time."
  - "Negative-test a bash-embedded python assertion by extracting the heredoc body from the PARSED workflow (yaml.safe_load strips the block-scalar indent for you — do not dedent again) and running it against crafted fixtures."

requirements-completed: [CICD-02]

# Metrics
duration: 12min
completed: 2026-09-11
---

# Phase 17 Plan 03: Six Attributed SARIF Uploads, Six Assertions That Cannot Be Swallowed

**Every SARIF file the five scan jobs produce now has its own SHA-pinned `upload-sarif` step under a unique category, and every one of those tolerated uploads is read back by an intolerant step in the same job — so ADR-001's `continue-on-error` can no longer turn a 403 into a green check.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-09-11T18:45Z
- **Completed:** 2026-09-11T18:57Z
- **Tasks:** 2
- **Files modified:** 1 (0 created, 1 modified)

## Accomplishments

- **Twelve steps, five jobs, zero new jobs.** CICD-01's "5 parallel jobs" and Phase 18's required-check
  list are untouched; the five `name:` values still parse byte-identical, em dash included.
- **The `Trivy` collision is closed structurally.** `trivy-fs.sarif` and `trivy-image.sarif` carry the
  identical `tool.driver.name`; they now go up under `trivy-fs` and `trivy-image`, and 17-01's gate fails
  permanently on any future duplicate category.
- **The anti-slop / ADR-001 conflict is reconciled rather than traded off.** The upload stays tolerated;
  the assertion is not. `steps.<id>.outcome` did not appear anywhere in this repo before this plan.
- **A clean ecosystem skip still passes.** Both tflint steps carry `steps.tf.outputs.found == 'true'`, so a
  repo with no Terraform skips the upload and the verify together instead of failing on a missing file.
- **The embedded evidence parser was run, not assumed.** Extracted from the parsed workflow and driven
  against fixtures: exit 0 on a good SARIF (printing `tool.driver.name=Semgrep OSS results=2`), exit 1 with
  `SARIF has no runs key` on a SARIF without `runs`, exit 1 on a missing file.

## Task Commits

1. **Task 1: Upload and verify the four unconditional SARIF files (sast, iac, container, secrets)** — `7525ad2` (feat)
2. **Task 2: Upload and verify the two SCA SARIF files, one of them ecosystem-guarded** — `9692fa7` (feat)

Both commits are on `feature/phase-17-sarif-upload-and-artifact-retention` in the nested product repo
`repos/security-platform`, continuing 17-01/17-02's branch (`34cd158`, `66a18ad`, `a3f9dac`, `f3e6dec`).
Committed with hooks (yamllint Passed on both). **Nothing pushed, no live run — that is 17-05.**

## Files Created/Modified

- `repos/security-platform/.github/workflows/security.yml` — twelve steps added across the five jobs
  (+194 in Task 1, +93 in Task 2, 0 deletions). No existing step was modified, renamed or reordered.

## Required Output: Observed Evidence

All three items below are parsed from the **committed** file
(`git show HEAD:.github/workflows/security.yml`), not the working tree.

### 1. The six category strings, as parsed from the committed file

| Job | Step id | `sarif_file` | `category` | Upload guard |
|-----|---------|--------------|------------|--------------|
| `sast` | `sarif-semgrep` | `semgrep.sarif` | `semgrep` | `always()` |
| `iac` | `sarif-checkov` | `checkov.sarif` | `checkov` | `always()` |
| `sca` | `sarif-trivy-fs` | `trivy-fs.sarif` | `trivy-fs` | `always()` |
| `sca` | `sarif-tflint` | `tflint.sarif` | `tflint` | `always() && steps.tf.outputs.found == 'true'` |
| `container` | `sarif-trivy-image` | `trivy-image.sarif` | `trivy-image` | `always()` |
| `secrets` | `sarif-gitleaks` | `gitleaks.sarif` | `gitleaks` | `always()` |

`sorted(categories) == ['checkov', 'gitleaks', 'semgrep', 'tflint', 'trivy-fs', 'trivy-image']` — six
values, six distinct, six distinct step ids. All six pinned to
`github/codeql-action/upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63  # v4.38.0`; a comment-filtered
`grep -c` of that pin returns exactly **6**, and the stale v3 SHA `ebcb5b36…` appears nowhere in the file.

### 2. The exact guard expression on the verify steps

Five of the six, verbatim:

```
always() && github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'
```

The tflint one, verbatim — the ecosystem guard ANDed in ahead of the environment guard:

```
always() && steps.tf.outputs.found == 'true' && github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'
```

No `continue-on-error` key exists on any of the six verify steps, and no fork/Dependabot condition exists
on any of the six upload steps.

### 3. `wait-for-processing` was set nowhere

Parsed assertion over all six `with:` blocks in the committed file:
`any('wait-for-processing' in w for w in with_blocks)` → **False**. The default of `true` stands, which is
what makes an async ingestion rejection visible to the outcome assertion. (Two upload steps carry a
*comment* naming the key and saying it is deliberately unset — the assertion is on keys, not text.)

## Other Verification

| Check | Result |
|---|---|
| Task 1 inline YAML parse (4 jobs: pin, id, category, sarif_file, `always()`, continue-on-error, placement after `Show scan output files`, exactly 1 paired intolerant verify each) | all pass |
| Task 2 inline YAML parse (6 uploads, 6 unique categories, 6 unique ids, 6 paired intolerant verifies, tflint guarded on both steps) | all pass |
| `bash scripts/check-workflow-uploads.sh` | exit 0 — `PASS - 10 checks, 0 failures` (checks 5 SARIF-CATEGORY and 8 UPLOAD-VERIFY-PAIRING now have real subjects for the first time) |
| `yamllint -d relaxed .github/workflows/security.yml` | exit 0 (line-length warnings only, as before) |
| Five job `name:` values | `['SAST — Semgrep CE', 'IaC — Checkov', 'SCA — Trivy Filesystem', 'Container — Trivy Image', 'Secrets — Gitleaks']` — byte-identical |
| Job shape | 5 jobs, zero `needs:` |
| `--redact` count, comments filtered | exactly 2 (both Gitleaks invocations; the new Gitleaks verify step echoes no `--redact`) |
| Embedded evidence parser, extracted and executed | rc 0 on a good SARIF, rc 1 + `SARIF has no runs key` on one without `runs`, rc 1 on a missing file |
| Pre-commit hooks on both commits | yamllint Passed; no `--no-verify` used |

## Decisions Made

See `key-decisions` in the frontmatter. The two a later reader is most likely to "correct" wrongly:

**The Dependabot clause is not redundant with the same-repo test.** A Dependabot PR is raised on a branch
in the *same* repository, so `head.repo.full_name == github.repository` is TRUE for it while its token is
still read-only. Dropping `github.actor != 'dependabot[bot]'` would fail every Dependabot PR — and Phase 14
pinned `actions/checkout` one patch behind specifically to guarantee one appears.

**The tflint verify's missing parse block is deliberate, not an oversight.** It is the only one of the six
without an evidence block, because `Verify tflint SARIF` (16-04) already parses that exact file.

## Deviations from Plan

None. Both tasks were executed as written: the step names, ids, categories, key order, guard expressions,
comment placement and commit messages all follow the plan text, and every acceptance criterion was checked
before its commit.

One plan instruction was interpreted rather than copied literally: "Write the comment once in full on the
first pair and reference it briefly on the other three." The full eleven-line rationale is on
`Verify Semgrep SARIF upload landed` in the `sast` job; the other five (including both Task 2 pairs) carry
a four-line comment naming that step as the contract, with the tflint pair adding its own
guard-composition and two-runs notes.

## Issues Encountered

**1. A scratchpad extraction bug, caught and corrected before it could mislead.** The first attempt to
negative-test the embedded python dedented the heredoc body by 10 columns after `yaml.safe_load` had
already stripped the block-scalar indent, producing a `SyntaxError` that looked like a defect in the
committed workflow. Re-extracting without the double dedent showed the block is correct. Recorded because
the same trap will appear in 17-04/17-05: **the parsed `run:` string is already dedented.**

**2. `roadmap.update-plan-progress` was run twice** — once before SUMMARY.md existed (reporting
`summary_count: 2`) and again after it was written, since the counter reads SUMMARY files from disk.

No unresolved issues.

## User Setup Required

None. Nothing was pushed and no PR was opened; the phase branch is local to `repos/security-platform` and
merges in 17-07 after human sign-off.

## Next Phase Readiness

- **Ready for 17-04 (artifact retention).** It inherits the same two gate invariants that now have real
  subjects: UPLOAD-VERIFY-PAIRING (every `actions/upload-artifact` step needs an `id:` and a later same-job
  step reading `steps.<id>.outcome`) and ARTIFACT-PATH-SAFETY (bare-basename `*.json` / `*.sarif` globs
  only — 16-04's numbered reports must be globbed as `npm-audit-*.json` / `pip-audit-*.json`, never named).
  The tolerated-step/intolerant-assertion shape to copy is now in this file six times.
- **17-05 (live run) is the only thing standing between CICD-02 and observed evidence.** This plan makes
  CICD-02 *statically* complete — six uploads, six categories, six assertions — and it is marked Complete
  in `.planning/REQUIREMENTS.md` accordingly. Nothing has yet been uploaded to code scanning; 17-05 is what
  produces the Security-tab evidence and, per the guard above, it must run on a **same-repo, non-Dependabot
  PR** or every verify step will skip rather than prove anything.
- **CICD-03 remains Pending**, as 17-01 and 17-02 both recorded. 17-04 marks it.
- **Phase 18 will see `Semgrep OSS`, not `Semgrep`**, as the code-scanning tool name for the `semgrep`
  category (17-RESEARCH Pattern 3, measured). The six category strings above are the other half of what its
  filters key on.
- **No blockers.**

---
*Phase: 17-sarif-upload-and-artifact-retention*
*Completed: 2026-09-11*
