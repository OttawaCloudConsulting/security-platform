---
phase: 27-defectdojo-ci-auto-import
plan: 12
subsystem: ci-defectdojo-side-channel
tags: [security, defectdojo, tls, cr-01, gap-closure, publish]
gap_closure: true
requires: ["27-11"]
provides:
  - "CR-01 https-only fix merged to OttawaCloudConsulting/security-platform main (merge 917352c)"
  - "GitHub proof run with P-HTTP: PROOF PASS - 88 assertions"
affects: ["27-13 (v1.1.1 tag / v1 move)", "27-14 (ADR-025)", "Phase 29"]
tech-stack:
  added: []
  patterns: ["operator-gated push / rerun / merge", "verify merged state from origin/main"]
key-files:
  created:
    - .planning/phases/27-defectdojo-ci-auto-import/evidence/27-12-proof-run.log
    - .planning/phases/27-defectdojo-ci-auto-import/evidence/27-12-pr-checks.txt
  modified: []
decisions:
  - "Operator approved push of ba3683a and PR creation: \"Approved — push\""
  - "Operator approved one rerun of the failed KIND-CELERY-PING proof job: \"Option 1, then /investigate if it still fails\""
  - "Operator approved merge of PR #22 with decisions a-d all accepted: \"Approved — merge\""
  - "Proof assertion count is 88 (was 85): +3 P-HTTP sub-cases"
metrics:
  completed: 2026-09-25
  tasks: 4
  files: 2
---

# Phase 27 Plan 12: Publish the CR-01 https-only fix Summary

The CR-01 fix (both DefectDojo side-channel bodies refuse a non-https `DEFECTDOJO_URL`, and every curl call is pinned to https) is merged to public `security-platform` main as merge commit **917352c00987023fa5ff1e6cdabc16987eb114dd**. A real GitHub Actions run of `defectdojo-import-proof.yml` on the PR proved it with the three P-HTTP cases and `PROOF PASS - 88 assertions`. All verification below was read from `origin/main`.

## Key facts for 27-13

| Item | Value |
|------|-------|
| PR | #22 https://github.com/OttawaCloudConsulting/security-platform/pull/22 (MERGED, `--merge`) |
| PR head | ba3683aae86fefdfc004f158c6022a0ef38da5fe (the operator-approved SHA) |
| Merge SHA | **917352c00987023fa5ff1e6cdabc16987eb114dd** |
| Merge parents | 0f7e4e141d2a300d4be9a54efc137eb4510bb7ea (prior main), ba3683aae86fefdfc004f158c6022a0ef38da5fe (fix) |
| Proof run | 36186258881 **attempt 2**; prove-import job 108243485918 success; https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36186258881 |
| Measured assertions | `PROOF PASS - 88 assertions`; smoke `ALL PASS - 13 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).` |
| Tags after merge | untouched: `v1` -> 0f7e4e1, `v1.1.0` -> 0f7e4e1, `v1.0.0` -> cdf2c21. No v1.1.1 (27-13, separate approval) |

## Operator approvals (verbatim)

1. **Task 1, push and PR:** "Approved — push". Approved HEAD: ba3683aae86fefdfc004f158c6022a0ef38da5fe. Before replying, the operator was told three things: the merge would need a separate approval, the v1.1.1 tag and v1 move would need another (27-13), and http:// consumers' non-required import and cleanup jobs would turn red.
2. **Task 2, proof failure checkpoint (KIND-CELERY-PING):** "Option 1, then /investigate if it still fails". Option 1 was `gh run rerun 36186258881 --failed`, run exactly once.
3. **Task 3, merge:** "Approved — merge". None of decisions a–d was rejected:
   - a. An http:// or scheme-less URL now fails the non-required import and cleanup jobs red, with no token sent. There is no opt-out.
   - b. The refusal also runs first in dd-delete.
   - c. The assertion count changes from 85 to 88.
   - d. The merge is effectively irreversible. Tagging is a separate step (27-13).

## Task results

**Task 1 (approval gate).** The offline gates were green, as recorded in 27-11-SUMMARY. The operator approved.

**Task 2 (push, PR, proof, checks).**
- Before the push, HEAD was re-verified as ba3683a, the tree was clean and the remote branch was absent.
- `git push -u origin fix/phase-27-https-only` succeeded, with pre-push hooks passing.
- PR #22 was opened with the planned title. The body covers the defect, the fix, SCHEME 18->19, P-HTTP and `--scheme-only`, the unchanged required contexts, the http:// consumer impact, and the separate v1.1.1 approval, and it ends with the attribution lines.
- Proof run 36186258881 attempt 1 failed at the smoke stage, before any proof case ran (0 P-HTTP lines):
  `==> KIND-CELERY-PING: FAIL - celery -A dojo inspect ping exited 69 without pong (broker unreachable or worker not replying): Error: No nodes replied within time constraint command terminated with exit code 69`
  I stopped and asked the operator, who approved one rerun.
- Attempt 2 passed: `KIND-CELERY-PING: PASS`, then these P-HTTP lines:
  - `PROOF: P-HTTP PASS import-http: DD_URL=http://127.0.0.1:9 -> exit 1, refused before the TLS label, no request, no results file, token absent`
  - `PROOF: P-HTTP PASS import-noscheme: DD_URL=127.0.0.1:9 -> exit 1, refused before the TLS label, no request, no results file, token absent`
  - `PROOF: P-HTTP PASS delete-http: DD_URL=http://127.0.0.1:9 -> exit 1, refused before the TLS label, no request, no results file, token absent`
  - `PROOF PASS - 88 assertions`
- PR checks (evidence/27-12-pr-checks.txt): 18 pass, 4 skipped.
  - The five required contexts passed: `security / Secrets — Gitleaks`, `SAST — Semgrep CE`, `SCA — Trivy Filesystem`, `IaC — Checkov`, `Container — Trivy Image`.
  - `security / DefectDojo Import` and `security / DefectDojo Cleanup` were skipped, and so were the matching `scans / ...` jobs.
  - The five `scans / ...` scanners passed, `prove-import` succeeded, and Checkov, Semgrep OSS, Trivy, gitleaks, tflint, tflint-errors and GitGuardian all passed.
- The scrub for a token header or generated password found 0 hits in both evidence files. The plan's Task 2 `<verify>` passed.

**Task 3 (merge gate).** I presented the measured values and decisions a–d, and the operator approved.

**Task 4 (merge and verify from origin/main).**
- Before merging I re-confirmed the PR: OPEN, head ba3683a, merge state CLEAN, 18 pass and 4 skipped, and origin/main at 0f7e4e1.
- `gh pr merge 22 --merge` returned rc 0, and the PR state is MERGED.
- After `git fetch origin`, origin/main is 917352c. `git rev-list --parents -n1` printed three SHAs: 917352c, 0f7e4e1 and ba3683a.
- `git show origin/main:.github/workflows/security.yml | grep -c 'url.lower().startswith("https://")'` -> **2**
- `grep -c '"--proto-redir", "=https"'` on the same file -> **2**
- `git show origin/main:scripts/check-workflow-uploads.sh` contains `CHECK_COUNT = 19` (line 646).
- `git show origin/main:scripts/defectdojo-import-proof.sh` contains `P-HTTP` (10 lines).
- The `shasum` of `set-required-checks.sh` is `aa71d79a9fd700abdff469d7c8101e240e969400` on both origin/main and 0f7e4e1, so the file is byte-identical.
- The plan's Task 4 `<verify>` block passed.
- I did not delete the branch, create or move a tag, or touch branch protection.

## Commits

| Repo | SHA | Message |
|------|-----|---------|
| security-platform | ba3683a | fix(27-11): refuse non-https DEFECTDOJO_URL and pin curl to https (CR-01), pushed unchanged |
| security-platform | 917352c | merge commit of PR #22 (by `gh pr merge 22 --merge`) |
| outer repo | 76d2701 | test(27-12): record CR-01 fix PR proof run and checks |

## Deviations from Plan

**1. [Process] The proof needed two attempts.** Attempt 1 of run 36186258881 failed at KIND-CELERY-PING, the flake already known from 27-08. The executor stopped under step 6. With the operator's approval, it ran exactly one `gh run rerun --failed`, and attempt 2 passed. The evidence header records both attempts.

**2. [Rule 3 - Blocking] Global `*.log` ignore.** The user's global `~/.gitignore:18 *.log` made `gsd-sdk query commit` refuse `27-12-proof-run.log`. I force-added that one named file with `git add -f`, following the 27-06 and 27-07 `.log` evidence precedent, and committed with a normal `git commit` (hooks ran).

**3. [Rule 3 - Blocking] Trailing whitespace hook.** The whitespace hook rejected the tab at the end of each line of `gh pr checks` output. I stripped trailing whitespace only, since the 27-07 checks file has none either, and noted this on line 1 of the checks file. The content is otherwise verbatim.

## Deferred

`KIND-CELERY-PING` still makes one ping attempt with a 5s timeout. It has now flaked on two of four recent runs (36159160216 and 36186258881 attempt 1). The recommended follow-up from 27-08-SUMMARY (a retry with a bounded budget) is still open, and it is outside this plan's scope.

## Threat Flags

None. The published change removes network surface: it fails closed on http.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: evidence/27-12-proof-run.log (contains `P-HTTP PASS`, `PROOF PASS - 88 assertions`, `ALL PASS`)
- FOUND: evidence/27-12-pr-checks.txt (contains `security / SAST — Semgrep CE`, `DefectDojo Import ... skipped`)
- FOUND: outer commit 76d2701; security-platform commits ba3683a and 917352c on origin/main
- PR #22 state MERGED; the plan's Task 2 and Task 4 verify blocks passed
