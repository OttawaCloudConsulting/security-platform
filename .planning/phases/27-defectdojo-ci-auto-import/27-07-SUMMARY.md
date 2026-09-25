---
phase: 27-defectdojo-ci-auto-import
plan: 07
subsystem: publish-and-merge
tags: [defectdojo, github-actions, pull-request, merge, live-proof, security-platform]
requires:
  - "27-06 defectdojo-import-proof.yml + complete harness (local PROOF PASS - 85 assertions)"
  - "27-01..27-05 security.yml import/cleanup jobs, callers, offline gates"
provides:
  - "PR #21 merged into OttawaCloudConsulting/security-platform main (merge commit 0f7e4e1)"
  - "evidence/27-07-proof-run.log: GitHub Actions proof run 36156728300, prove-import success, PROOF PASS - 85 assertions"
  - "evidence/27-07-pr-checks.txt: verbatim PR checks and check-runs for head 7c47270"
affects: [27-08, 27-09, 27-10]
tech-stack:
  added: []
  patterns:
    - "Two separate operator approvals (push, then merge); approval scope does not carry over"
    - "Merged state verified from origin/main after git fetch, never from the local working tree"
key-files:
  created:
    - .planning/phases/27-defectdojo-ci-auto-import/evidence/27-07-proof-run.log
    - .planning/phases/27-defectdojo-ci-auto-import/evidence/27-07-pr-checks.txt
  modified: []
key-decisions:
  - "Operator accepted all public decisions a-g of PR #21 (Product Type default CI, DEFECTDOJO_CA_CERT, cleanup in security.yml, scheduled-security.yml job id security, is_staff token, known gaps to ADR-024, Mode B consumers edit their own caller)"
  - "PR #21 merged with --merge (merge commit, two parents); feature branch not deleted, no tag, v1 not moved, branch protection untouched"
requirements-completed: []  # DDOJO-02 partial (7 of 10 plans); marked complete by 27-10
duration: ~25min (across checkpoints)
completed: 2026-09-25
---

# Phase 27 Plan 07: Publish, prove on GitHub Actions, and merge the DefectDojo import bundle

The DefectDojo import bundle is now on public `OttawaCloudConsulting/security-platform` main. PR #21 ([link](https://github.com/OttawaCloudConsulting/security-platform/pull/21)) was merged with `--merge` as **`0f7e4e141d2a300d4be9a54efc137eb4510bb7ea`**, after the operator gave two separate approvals. D-19 is met: the path-filtered DefectDojo Import Proof run **36156728300** on the PR head passed (`prove-import` success, **PROOF PASS - 85 assertions**, smoke `ALL PASS - 13 live check(s)`).

## Tasks

| Task | Name | Commit | Repo |
|------|------|--------|------|
| 1 | Operator approval to push and open the PR | none (gate) | - |
| 2 | Push, open PR #21, record the proof run and PR checks | `34206aa` | this repo (evidence) |
| 3 | Operator approval to merge | none (gate) | - |
| 4 | Merge and verify from origin/main | merge `0f7e4e1` | security-platform (remote) |

## Operator approvals (verbatim)

- **Task 1 (push + PR creation):** "Approved — push"
- **Task 3 (merge):** "Approved — merge". The operator rejected none of decisions a-g, so all are accepted:
  - a. Product Type default `CI`, overridable by `DEFECTDOJO_PRODUCT_TYPE`
  - b. Optional variable `DEFECTDOJO_CA_CERT`; `DEFECTDOJO_INSECURE=true` wins if both are set, and both warnings fire
  - c. Cleanup lives in security.yml, gated on `github.event.action == 'closed'`, and deletes exact-name matches only inside the one exactly-named product
  - d. Scheduled caller file `scheduled-security.yml`, job id `security`
  - e. The token must belong to a DefectDojo `is_staff` user, not a superuser
  - f. Known gaps recorded for ADR-024, not fixed: schedule-skipped verify steps, skipped contexts on a closed PR's head, `npm-audit-N` title drift, tflint imported as SARIF
  - g. Mode B consumers must edit their own caller (`closed` type + `secrets:` pass); moving v1 alone does not enable import

The merge approval covered only `gh pr merge 21 --merge`. It did not cover squash/rebase, branch deletion, tags, moving v1 or branch-protection changes, and none of those were done.

## PR and proof run (Task 2)

- **PR:** #21, https://github.com/OttawaCloudConsulting/security-platform/pull/21, base `main`, head `feature/phase-27-defectdojo-ci-auto-import` @ `7c47270db60e7f6ef8dae89c42870ad06fd5e5d6`
- **PR commits (71a112e..7c47270):** 3adbfc9, 7126fa1, a7a7590, 602bfeb, 7e43593, bdbc34a, 7c47270 (7 files changed, 2635 insertions, 24 deletions)
- **Proof run:** https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728300. `prove-import` job 108143219234 concluded success, and so did the run. The "Live proof" step ran 2026-09-25T15:49:56Z to 15:55:14Z. The log contains `PROOF PASS - 85 assertions` and `ALL PASS - 13 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).`
- **PR Security run:** https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728417 (success)
- **Opt-out path proven on GitHub:** `security / DefectDojo Import` and `security / DefectDojo Cleanup` show `skipping` / `skipped`, because security-platform sets no `DEFECTDOJO_URL`. The five required `security / ...` contexts all passed.

### `gh pr checks 21` (verbatim from evidence/27-07-pr-checks.txt)

```
Checkov	pass	3s	https://github.com/OttawaCloudConsulting/security-platform/runs/108143109097
GitGuardian Security Checks	pass	1s	https://dashboard.gitguardian.com
Semgrep OSS	pass	5s	https://github.com/OttawaCloudConsulting/security-platform/runs/108143123496
Trivy	pass	4s	https://github.com/OttawaCloudConsulting/security-platform/runs/108143069818
gitleaks	pass	4s	https://github.com/OttawaCloudConsulting/security-platform/runs/108143030867
prove-import	pass	5m34s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728300/job/108143219234
scans / Container — Trivy Image	pass	32s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728300/job/108142965617
scans / IaC — Checkov	pass	33s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728300/job/108142965625
scans / SAST — Semgrep CE	pass	37s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728300/job/108142965649
security / DefectDojo Import	skipping	0	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728417/job/108143290076
security / Secrets — Gitleaks	pass	19s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728417/job/108142966181
scans / Secrets — Gitleaks	pass	18s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728300/job/108142965305
security / IaC — Checkov	pass	31s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728417/job/108142966260
tflint-errors	pass	4s	https://github.com/OttawaCloudConsulting/security-platform/runs/108143163831
security / SAST — Semgrep CE	pass	34s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728417/job/108142966394
security / Container — Trivy Image	pass	26s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728417/job/108142967266
tflint	pass	4s	https://github.com/OttawaCloudConsulting/security-platform/runs/108143162797
security / SCA — Trivy Filesystem	pass	52s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728417/job/108142966299
scans / SCA — Trivy Filesystem	pass	41s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728300/job/108142965380
security / DefectDojo Cleanup	skipping	0	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728417/job/108142967253
scans / DefectDojo Cleanup	skipping	0	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728300/job/108142967058
scans / DefectDojo Import	skipping	0	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36156728300/job/108143220309
```

The check-runs API listing (22 check-runs, all `completed`; the four DefectDojo Import/Cleanup runs `skipped`, the rest `success`) is in the same evidence file.

## Merge and remote verification (Task 4)

Prediction stated before the merge:

```
DOING: gh pr merge 21 --merge (head 7c47270)
EXPECT: state MERGED; merge commit on origin/main with two parents (prior main tip, 7c47270); branch not deleted
IF MATCH: git fetch origin, run Task 4 remote verifications
IF MISMATCH: stop, no revert/retry, report raw output
```

Pre-merge re-read: `state OPEN`, `headRefOid 7c47270db60e7f6ef8dae89c42870ad06fd5e5d6`, `mergeStateStatus CLEAN`, `mergeable MERGEABLE`.

`gh pr merge 21 --merge` exited 0. Then: `state MERGED`, `mergedAt 2026-09-25T16:08:32Z`, `mergeCommit 0f7e4e141d2a300d4be9a54efc137eb4510bb7ea`.

All checks below ran against `origin/main` after `git fetch origin` (`71a112e..0f7e4e1  main -> origin/main`):

| Check | Result |
|-------|--------|
| `git rev-parse origin/main` | `0f7e4e141d2a300d4be9a54efc137eb4510bb7ea` |
| `git rev-list --parents -n1 0f7e4e1` | `0f7e4e1… 71a112e02bf974f27d8d8778d045be2f89e1b018 7c47270db60e7f6ef8dae89c42870ad06fd5e5d6` (three SHAs, two parents) |
| `git ls-tree -r origin/main --name-only` | lists `.github/workflows/{security,pr-security,scheduled-security,defectdojo-import-proof}.yml`, `scripts/defectdojo-import-proof.sh`, `scripts/check-workflow-uploads.sh`, `scripts/set-required-checks.sh` |
| `origin/main:.github/workflows/security.yml` | `defectdojo-import:` at line 1259, `defectdojo-cleanup:` at line 1640 |
| `origin/main:.github/workflows/pr-security.yml` | `types: [opened, synchronize, reopened, closed]` (line 36) |
| `set-required-checks.sh` origin/main vs 71a112e | both shasum `aa71d79a9fd700abdff469d7c8101e240e969400`: byte-identical |
| `git diff --stat 7c47270 origin/main` | empty: the merged tree equals the approved PR head (so the extended `check-workflow-uploads.sh` is as reviewed) |
| `git ls-remote --heads origin feature/phase-27-defectdojo-ci-auto-import` | still present at 7c47270 (not deleted) |
| Plan `<verify>` automated command | `AUTOMATED_VERIFY_PASS` |

RESULT: every expectation observed. MATCH: yes.

As the plan requires, nothing else was changed: no tag (27-08), `v1` not moved, branch protection untouched, feature branch kept. The local `repos/security-platform` checkout was left on `feature/phase-27-defectdojo-ci-auto-import`. The plan does not ask for a local fast-forward of `main`.

## Deviations from Plan

**1. [Rule 3 - Blocking] Trailing tab stripped in evidence/27-07-pr-checks.txt**
- **Found during:** Task 2
- **Issue:** The parent repository's pre-commit hook rejects trailing whitespace. `gh pr checks` output ends each line with an empty description column, which is a trailing tab.
- **Fix:** Stripped only that trailing tab, and said so in the evidence file's section header ("verbatim except the empty trailing description column, a trailing tab, was stripped for the repo whitespace hook"). No other content changed, and the hook was not bypassed.
- **Commit:** `34206aa`

No other deviations.

## Threat model

- T-27-19 / T-27-23: the push and the merge each ran only after the operator's own reply. Both approvals are recorded verbatim above.
- T-27-10: `set-required-checks.sh` is byte-identical on origin/main, and the required contexts on PR #21 are unchanged.
- T-27-02: both evidence files were scrubbed before commit in Task 2, and no token or password appears in them.
- T-27-18: the proof workflow ran on `pull_request` with no secrets.

## Next

27-08 covers the v1.x release tag and moving `v1`, which needs its own separate operator approval. DDOJO-02 stays open until 27-10.

## Self-Check: PASSED

- FOUND: evidence/27-07-proof-run.log, evidence/27-07-pr-checks.txt
- FOUND: commit 34206aa (this repo); merge commit 0f7e4e1 on security-platform origin/main
