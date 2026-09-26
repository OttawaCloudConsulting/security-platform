---
phase: 28-defectdojo-dedup-and-triage
plan: 07
subsystem: ci-publish
tags: [defectdojo, dedup, triage, pr, github-actions, proof]
requires:
  - phase: 28-06
    provides: complete local Phase 28 branch (chart guards, configure script, proof block, TRIAGE.md) with green offline gates
  - phase: 28-05
    provides: local kind proof (127 assertions, 281 s wall-clock) used as the push-gate baseline
provides:
  - open PR OttawaCloudConsulting/security-platform#23 for the Phase 28 branch
  - real GitHub Actions proof run 36261602015 (prove-import success, PROOF PASS - 127 assertions) - D-12 GitHub half
  - evidence/28-07-proof-run.log and evidence/28-07-pr-checks.txt
affects: [28-08, 28-09]
tech-stack:
  added: []
  patterns: ["publish gate: operator approval of an exact HEAD SHA, re-checked before push (27-12 pattern)"]
key-files:
  created:
    - .planning/phases/28-defectdojo-dedup-and-triage/evidence/28-07-proof-run.log
    - .planning/phases/28-defectdojo-dedup-and-triage/evidence/28-07-pr-checks.txt
  modified: []
key-decisions:
  - "PR #23 opened for the approved HEAD c77e4f4; not merged (merge is a separate approval in 28-08)"
  - "GitHub proof measured the same 127 assertions as the local kind run, 35 of them in the Phase 28 block, on attempt 1 with no rerun"
metrics:
  duration: ~15 min (Task 2)
  completed: 2026-09-26
---

# Phase 28 Plan 07: Publish Phase 28 branch and GitHub proof run Summary

The Phase 28 branch was pushed after the operator's approval and opened as PR #23. The DefectDojo Import Proof run on the PR passed on the first attempt: prove-import success, `PROOF PASS - 127 assertions`, and every Phase 28 assertion id passed. The five `security / ...` contexts were green and DefectDojo Import and Cleanup were skipped.

## Task 1 record (operator approval)

- Operator reply, verbatim: "Approved — push"
- Approved HEAD SHA: c77e4f4d47e820c76914ca798a88be9b610fb130 (repos/security-platform, branch feature/phase-28-defectdojo-dedup-and-triage, clean tree, 13 commits ahead of origin/main)
- Gate lines at approval: chart `PASS - 22 checks, 0 failures`; uploads `PASS - 19 checks, 0 failures`; parity `check-detector-parity: PASSED 20 / FAILED 0`; actionlint rc=0; `EXTRACT PASS - .github/workflows/security.yml`; `PROOF PASS - 7 assertions` (--scheme-only); `check-adoption-guide: PASSED 16 / FAILED 0`; workflow/caller/set-required-checks diff rc=0; v1 -> 917352c00987023fa5ff1e6cdabc16987eb114dd (matches 28-01); remote branch absent before push.

## Task 2 results

Before the push: tree clean, branch `feature/phase-28-defectdojo-dedup-and-triage`, `git rev-parse HEAD` = c77e4f4d47e820c76914ca798a88be9b610fb130 (the approved SHA), `git ls-remote --heads` for the branch empty. Local pre-push hooks passed.

| Item | Value |
|------|-------|
| PR | #23, https://github.com/OttawaCloudConsulting/security-platform/pull/23 (state OPEN, mergeStateStatus CLEAN) |
| PR title | feat: DefectDojo dedup guards, settings bootstrap and triage runbook (DDOJO-03, DDOJO-04) |
| Head SHA | c77e4f4d47e820c76914ca798a88be9b610fb130 |
| Proof run | 36261602015, attempt 1, https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36261602015 |
| prove-import job | 108458517558, conclusion success |
| prove-import duration | 7m08s (18:11:23Z to 18:18:31Z), against the 60-minute timeout. Local 28-05 wall-clock was 281 s |
| Assertion count | `PROOF PASS - 127 assertions` (Phase 27 had 88; 35 PROOF PASS lines are in the Phase 28 block, matching 28-05) |
| Live checks | `ALL PASS - 13 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).` |
| Reruns | none. KIND-CELERY-PING did not fail |

PASS line counts per Phase 28 id in the GitHub log (0 FAIL lines for any): P-CONFIGURE 4, P-IDEMPOTENT 1, P-DEDUP-BRANCH 4, P-CROSSTOOL 3, P-DISPOSITION 14, P-SUPPRESS 4, P-REPARENT 4, P-HTTP 5.

The GitHub run measured the same values as the local run:
- configure run 1 `CHANGED: enable_deduplication, risk_acceptance_form_default_days`, run 2 `NO CHANGE: all 5 settings already match`
- P-DEDUP-BRANCH: 155 PR findings, exactly one non-duplicate (the CVE-2020-8203 lodash delta)
- P-CROSSTOOL: `23 duplicate link(s) touch an SCA finding in ci/main; 0 cross scan types`
- P-SUPPRESS: #540-#542 dup_of 231-233, 154 findings, 0 active
- P-REPARENT: K=6, all re-parented immediately after the DELETE, read 1 s later

PR checks (evidence/28-07-pr-checks.txt, check-runs API):
- `security / SAST — Semgrep CE`, `security / SCA — Trivy Filesystem`, `security / Secrets — Gitleaks`, `security / IaC — Checkov`, `security / Container — Trivy Image`: success
- `security / DefectDojo Import`, `security / DefectDojo Cleanup`: skipped
- `prove-import` and the five `scans / ...` jobs: success. `scans / DefectDojo Import` and `scans / DefectDojo Cleanup`: skipped
- Code-scanning checks (Checkov, Semgrep OSS, Trivy, gitleaks, tflint, tflint-errors) and GitGuardian: success. This run had no Checkov code-scanning FAILURE

Scrub (T-28-28): `Authorization: Token|aA1!` grep over the raw run log (4612 lines) and both evidence files returned 0 hits. Nothing was redacted.

Commit: e57bc45 `test(28-07): record Phase 28 PR proof run and checks` (outer repo).

The PR was not merged.

## Deviations from Plan

**1. [Rule 3 - Blocking] Evidence commit made with plain git instead of `gsd-sdk query commit`.** `gsd-sdk query commit` refused because `28-07-proof-run.log` matches the global `*.log` gitignore. The log was staged with `git add -f`, following the Phase 27 and 28-05 precedent.

**2. [Rule 3 - Blocking] Stripped trailing whitespace in 28-07-pr-checks.txt.** `gh pr checks` ends each row with a tab, and the pre-commit whitespace hook rejected the file. The tabs were stripped, which matches the 27-12 file (0 trailing tabs), and the file header records this. No field content changed.

**3. PR body wording on cross-tool collapse.** The first draft said the tools "share no vulnerability ids or hash inputs". Before creating the PR it was narrowed to only what 28-05 measured: disjoint CVE/PYSEC ids for `requests`, npm audit findings without ids or component versions, and 0 cross-scan-type duplicate links.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: evidence/28-07-proof-run.log (478 lines; header with run id, attempt, URLs, head SHA, `prove-import conclusion: success`)
- FOUND: evidence/28-07-pr-checks.txt (48 lines)
- FOUND: commit e57bc45
- Plan `<verify>` automated block: VERIFY-OK (run before the commit, re-checked on the committed files)
