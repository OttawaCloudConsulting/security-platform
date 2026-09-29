---
phase: 29-defectdojo-live-validation
plan: 16
subsystem: ci-cd
tags: [defectdojo, arc, d-11, dedup, triage, pr-lifecycle, trivy-image, scope-amendment, ddojo-05]
requires:
  - "29-15: evidence/main-baseline-snapshot.json (ci/main engagement 1, 155 findings), product OttawaCloudConsulting/security-platform id 1"
  - "29-04: security-platform scripts/defectdojo-lifecycle-assert.sh (assert-pr-duplicates, disposition, assert-dispositions, assert-closed)"
provides:
  - "D-11 steps 1-5 proven live through PR #25 on security-platform, all from API state; step 2 under the 2026-09-29 scope amendment"
  - "Live finding: trivy-image findings never dedupe across branches (file_path scan-target:<github.sha>)"
  - "evidence/dispositions.json: FP 3, OOS 10, RA 22, risk acceptance 1 expiring 2026-12-28, live on ci/main"
  - "29-16-step2-amended.sh: the amended step-2 check, exclusion key read live"
affects: [29-18, 29-19, ADR-026, ADR-027, TRIAGE.md]
tech-stack:
  added: []
  patterns:
    - "Re-run an evidence-writing helper into a separate --out subdirectory to keep the original FAIL file intact"
    - "Exclusion keys for assertions are read live from Test objects (scan_type + title) and asserted to match exactly one Test"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/29-16-step2-amended.sh
    - .planning/phases/29-defectdojo-live-validation/evidence/step2-amended-assert.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-16-step2-amended.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-16-step2-rerun/step2-assert.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-16-step2-rerun/helper-output.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/dispositions.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-16-step3.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-16-reimport-run.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-16-step4.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/step4-assert.json
    - .planning/phases/29-defectdojo-live-validation/evidence/main-before-reimport-snapshot.json
    - .planning/phases/29-defectdojo-live-validation/evidence/main-after-reimport-snapshot.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-16-cleanup-run.json
    - .planning/phases/29-defectdojo-live-validation/evidence/step5-assert.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-16-step5.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/main-after-close-snapshot.json
  modified:
    - .planning/phases/29-defectdojo-live-validation/29-CONTEXT.md
    - .planning/phases/29-defectdojo-live-validation/29-RESEARCH.md
    - .planning/phases/29-defectdojo-live-validation/deferred-items.md
decisions:
  - "29-16: D-11 step 2 amended 2026-09-29 by operator ruling (options a+d): the duplicates assertion excludes the trivy-image Test (scan_type Trivy Scan, title trivy-image); every other pre-existing PR finding must still duplicate a ci/main finding"
  - "29-16: trivy-image findings never dedupe across branches because security.yml tags the image scan-target:<github.sha>; the TRIAGE.md 'PR active list shows only what the PR introduces' claim is wrong for trivy-image; correction deferred to 29-18 PR B (TRIAGE.md lives only in security-platform)"
  - "29-16: dispositions set on ci/main originals FP 3 (semgrep), OOS 10 (checkov), RA 22 (trivy-fs), each with a PR duplicate; all survived a workflow_dispatch reimport and the PR close"
metrics:
  duration: "Task 1 in the prior session (PR run 01:03Z, halted 01:48Z); continuation ~35 min (2026-09-29T01:50Z to 02:25Z)"
  completed: 2026-09-29
  tasks: 3
  files: 19
---

# Phase 29 Plan 16: D-11 live PR lifecycle (dedup, dispositions, reimport, close) Summary

The full D-11 lifecycle ran live through security-platform PR #25 against the homelab DefectDojo. Every step was asserted from API state. The step-2 duplicates assertion failed as the plan originally wrote it, because trivy-image findings do not dedupe across branches. The operator amended the assertion's scope on 2026-09-29, and step 2 then passed. Dispositions on ci/main survived a reimport and the PR close, and the cleanup job deleted the PR engagement on ARC.

## The trivy-image dedup finding (the reason for the amendment)

- On the PR engagement (`ci/phase29/d11-lifecycle-fixture`, id 2, tests 9-16, 156 findings), all **59 trivy-image findings (Test 12) were active non-duplicates**. Their `file_path` was `scan-target:17fd99dc… (debian 12.15)`, against `scan-target:2fda1ac… (debian 12.15)` on ci/main.
- The cause: `security.yml` builds and scans `scan-target:${{ github.sha }}`. A PR's merge SHA never equals main's SHA, so these findings never match their ci/main copies, even when the image content is identical.
- The other **96 pre-existing findings were all inactive duplicates** of ci/main originals, and the fixture (id 163) was the only Under Review finding.
- **TRIAGE.md is wrong for trivy-image.** It says "154 duplicates, one new" and "a PR engagement's active list shows only what that PR introduces". The Phase 28 kind proof never exercised differing image tags, because both of its engagements were imported from the same report.

## Operator decision: (a) + (d), "scope + record"

- **(a) Scope amendment.** The D-11 step 2 duplicates assertion now excludes the trivy-image Test (scan_type "Trivy Scan", title "trivy-image"). It is recorded inline in `29-CONTEXT.md` D-11 step 2 as "(Amended 2026-09-29 by operator ruling: …)", in the same form as the 2026-09-26 step-5 amendment. The `29-RESEARCH.md` superseded pointer was updated to match. Step 2 was re-run under the amended rule against the existing engagement 2.
- **(d) Record the live behaviour.** TRIAGE.md lives only in `repos/security-platform/kubernetes/defectdojo/TRIAGE.md`. So its correction was not pushed to security-platform main and not added to PR #25. The exact replacement text for the "Dedup is product-wide" bullet is recorded in `deferred-items.md` as a **29-18 PR B** item. The same entry asks PR B to port the exclusion into the canonical helper.
- **(b) Follow-up, not done.** `deferred-items.md` records that a fixed scan-image tag in `security.yml` would let trivy-image findings dedupe across branches. Before that change, verify which hash field (`file_path` or `description`) carries the SHA. It is a candidate for 29-18 PR B or a later phase.
- **29-19 note.** ADR-027 must record the trivy-image dedup gap and the step-2 scope amendment.

## Results by step

| Step | Result | Evidence |
|------|--------|----------|
| 1. Fixture PR | PR #25, Semgrep `python.lang.security.deserialization.pickle.avoid-pickle` in `phase29-d11-fixture/unsafe_pickle.py` (rule absent from the baseline, not a secret). PR Security run **36506042988**: DefectDojo Import on ARC `occ-homelab-defectdojo`, success, 156 findings | `29-16-fixture-local-scan.txt`, `29-16-pr-run.json` |
| 2. Original rule | ENGAGEMENT PASS, UNTRIAGED-EQ-FIXTURE PASS (163), DUPLICATES-POINT-TO-MAIN **FAIL** (59 of 155). A fresh re-run of the unchanged helper gave the identical result. The original FAIL file was kept | `step2-assert.json`, `29-16-step2-rerun/` |
| 2. Amended rule | ENGAGEMENT, READ-GUARD, EXCLUSION-KEY (exactly Test 12) and DUPLICATES-POINT-TO-MAIN (amended 2026-09-29): **ALL PASS**. 96/96 others are duplicates of ci/main non-duplicate originals. 59 excluded, 0 of them duplicates (measured, not asserted) | `step2-amended-assert.json`, `29-16-step2-amended.txt` |
| 3. Dispositions | FP **3**, OOS **10**, RA **22**, risk acceptance **1**, expiry **2026-12-28** (90 days from the UTC run date 2026-09-29), admin token. All PASS | `dispositions.json`, `29-16-step3.txt` |
| 4. Reimport | `scheduled-security.yml` workflow_dispatch run **36510481745** on main 2fda1ac. Import on ARC, success. D11-STEP4-FP/OOS/RA/RA-EXPIRY all PASS | `29-16-reimport-run.json`, `29-16-step4.txt`, `step4-assert.json` |
| 5. Close | PR closed unmerged at 02:01:54Z. PR Security run **36510679451** (closed event): DefectDojo Cleanup on ARC, success, and the five scans plus the import were skipped. ENGAGEMENT-GONE, MAIN-COUNT-UNCHANGED, DISPOSITIONS-UNCHANGED and NO-DANGLING-DUPLICATE all PASS. The "re-parenting NOT asserted" INFO line was printed. Remote branch deleted | `29-16-cleanup-run.json`, `step5-assert.json`, `29-16-step5.txt` |

**ci/main counts:**

| Point | Findings | Notes |
|-------|----------|-------|
| Baseline | 155 | |
| Before reimport | 155 | |
| After reimport | 155 | identical id/test/title/path/duplicate set |
| After close | 155 | |

At every point, 23 of the findings are duplicates within ci/main. They were present at baseline too, so none came from the PR.

## Disposition choice (T-29-12)

Each chosen id is a non-trivy-image ci/main original (active, non-duplicate). Each has a PR copy that pointed to it as `duplicate_finding` in `pr-branch-snapshot.json`. The three come from three different tools:

| Disposition | ci/main id | Tool | Finding | PR copy |
|-------------|-----------|------|---------|---------|
| False Positive | 3 | Semgrep | AWS access key pattern in `fixtures/secret.env` (a deliberate test fixture) | 158 |
| Out of Scope | 10 | Checkov | module source commit hash in `/fixtures/main.tf` (fixture Terraform) | 166 |
| Risk Accepted | 22 | Trivy fs | CVE-2020-8203 Lodash in `fixtures/package-lock.json` (fixture lockfile) | 178 |

Trivy fs findings dedupe correctly, because their path does not carry the SHA. Picking one for RA also shows that the gap is specific to trivy-image.

## Deviations from Plan

### Operator-ruled scope change

**1. [Rule 4 - resolved by operator] D-11 step 2 duplicates assertion scope**
- **Found during:** Task 1 (prior session; the plan's STOP rule fired and a checkpoint was returned).
- **Issue:** 59 trivy-image findings were not duplicates (see above).
- **Resolution:** the operator chose (a)+(d). The amendment is in 29-CONTEXT.md. The amended check lives in `29-16-step2-amended.sh`, which has no executable bit and runs with bash. Its token handling mirrors the helper: an https pin, a 0600 header file inside `mktemp -d`, and `-H @file`. The fixture path argument was not changed.
- **Effect on the plan's Task 1 verify:** its last clause (`! grep -q '"FAIL"' step2-assert.json`) still fails on the kept original file, by design. Task 1 passes under the amended rule (`step2-amended-assert.json`), not under the plan's original verify.
- **Commits:** 4bfad6a, 428ad8b

### Other notes

- **Which `--main-snapshot` assert-closed got.** The helper's header says to pass the after-reimport snapshot, while the plan says to pass `main-baseline-snapshot.json`. `assert-closed` compares only the id set and count, and the two snapshots have identical id sets (155). The plan's baseline file was therefore used. The `main-after-reimport` and `main-after-close` snapshots were also captured.
- **Truncated log lines.** `29-16-step2-rerun/helper-output.txt` lines were cut at 400 characters. The full measured sets are in the `step2-assert.json` next to it.
- **Local branch kept.** The local `phase29/d11-lifecycle-fixture` branch still exists in the `repos/security-platform` clone. The remote branch is deleted, and the clone is checked out on `main`.

## Deferred

- **29-18 PR B:** replace the TRIAGE.md bullet (exact text is in `deferred-items.md`), and port the exclusion into `assert-pr-duplicates`.
- **Follow-up (b):** a fixed scan-image tag. Verify the SHA-carrying hash field first.
- **29-19:** ADR-027 records the trivy-image gap, the 2026-09-29 amendment, and that re-parenting was not exercised live.

## Known Stubs

None.

## Threat Flags

None. The admin token was used only through 0600 header files, and no token appears in any evidence file. The fixture is a benign `pickle` pattern, not a secret. The PR was closed unmerged, and its branch was deleted.

## Commits

| Commit | Scope |
|--------|-------|
| 7c60e96 | Task 1 (prior session): fixture, PR run, original step-2 FAIL |
| 4bfad6a | Task 1: scope amendment, amended check and PASS evidence |
| 428ad8b | Deferred items: TRIAGE.md correction (29-18 PR B), follow-up (b), ADR-027 note |
| 03ccc02 | Task 2: dispositions, reimport and step 4 |
| 6b623a4 | Task 3: close, cleanup and step 5 |

## Self-Check: PASSED

All 13 listed evidence files and the script exist; commits 7c60e96, 4bfad6a, 428ad8b, 03ccc02, 6b623a4 exist; the admin token string appears nowhere under the phase directory; the script has no executable bit.
