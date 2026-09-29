# Phase 29 Deferred Items

## From 29-15

### prove-import red on workflow_dispatch run 36502717161 (KIND-CELERY-PING)

- **Observed:** 2026-09-29T00:27:32Z, `prove-import` job 109197316267 (ubuntu-latest) failed with
  `KIND-CELERY-PING: FAIL - celery -A dojo inspect ping exited 69 without pong (broker unreachable or worker not replying)`.
  All earlier kind checks passed: cluster, cert-manager, ingress, CA issuer, install, deployments ready, PVC bound, cert ready, TLS login 200 and admin login.
- **Scope:** this is the ephemeral kind DefectDojo on a GitHub-hosted runner, not the live homelab instance. The live-side D-10 assertions for 29-15 all passed.
- **Prior state:** DefectDojo Import Proof passed on 2026-09-27 in run 36350180923 (pull_request, the PR later merged to main as 2fda1ac). The code under test is the same.
- **Unknown:** a single run cannot tell a transient Celery worker readiness race apart from a regression. It was not re-dispatched (29-15 did not ask for a rerun).
- **Operator-visible effect:** `main` now has a red "DefectDojo Import Proof" run.
- **Suggested next step:** re-dispatch `defectdojo-import-proof.yml` once. If KIND-CELERY-PING fails again, investigate worker readiness and the ping timeout in `scripts/defectdojo-live-smoke.sh`.
- **Rerun (2026-09-29, operator-approved):** `gh run rerun 36502717161 --failed` created attempt 2. Its `prove-import` job 109200085064 started at 00:33:22Z and passed, including KIND-CELERY-PING, and run 36502717161 now concludes `success`. The unchanged code passed on rerun, so the first failure was most likely a transient Celery worker readiness race rather than a regression. That is an inference from one pass after one fail, not a root cause.
- **Status:** not blocking. The ping has flaked once in two attempts at the same code. If it flakes again, harden worker readiness or the ping retry in `scripts/defectdojo-live-smoke.sh`. Re-check at 29-18, before the `v1.2.0` tag.
- **Re-check at 29-18 (2026-09-29):** before the `v1.2.0` tag, PR #26's DefectDojo Import Proof run 36600468850 `prove-import` job 109516595106 passed, including `KIND-CELERY-PING: PASS`. No new flake was observed. Still one flake in three observed attempts; hardening stays optional.

## From 29-16

### 29-18 PR B: correct the TRIAGE.md dedup claim (trivy-image does not dedupe across branches)

- **Where:** `kubernetes/defectdojo/TRIAGE.md` in `OttawaCloudConsulting/security-platform`, section "Before you triage", bullet "**Dedup is product-wide.**" (line 14 at 2fda1ac). This file lives only in security-platform, so it is not edited here. It is not pushed to `main` and not added to PR #25, the fixture PR that must never merge.
- **Live evidence (29-16, PR #25, engagement 2):** 156 findings. 96 pre-existing non-trivy-image findings were all inactive duplicates of `ci/main` originals. All 59 trivy-image findings (Test `trivy-image`, scan_type `Trivy Scan`) were active non-duplicates: their `file_path` is `scan-target:17fd99dc… (debian 12.15)` on the PR against `scan-target:2fda1ac… (debian 12.15)` on `ci/main`. See `evidence/step2-assert.json` (original FAIL) and `evidence/step2-amended-assert.json`.
- **Replace the bullet with exactly this text:**

  > - **Dedup is product-wide, except for container-image findings.** A repository's product holds one engagement per branch: `ci/<default>` for the default branch and `ci/<pr-branch>` for each open PR. A finding on a PR engagement that already exists on the default-branch engagement is marked as an inactive duplicate of the default-branch finding. This does not hold for the `trivy-image` Test: `security.yml` tags the scanned image `scan-target:${{ github.sha }}`, the tag appears in each finding's file path, and a PR's merge commit never has the default branch's SHA. Trivy image findings therefore never dedupe across branches and appear as active findings on every PR engagement, even when the image content is unchanged. A PR engagement's active list shows what that PR introduces plus the full `trivy-image` result. Measured live (Phase 29): a PR engagement holding 156 findings showed all 96 pre-existing non-image findings as duplicates, the one new finding as active, and all 59 `trivy-image` findings as active non-duplicates. The Phase 28 kind proof, which measured "154 duplicates, one new", never exercised differing image tags, because both of its engagements were imported from the same report.

- **Same PR B, the helper:** `scripts/defectdojo-lifecycle-assert.sh assert-pr-duplicates` still requires every non-fixture finding to be a duplicate and FAILs on the trivy-image Test. Port the 2026-09-29 exclusion (the live key is scan_type `Trivy Scan` plus test_title `trivy-image`, exactly one Test, and the excluded set is recorded as measured) from `.planning/phases/29-defectdojo-live-validation/29-16-step2-amended.sh`. Otherwise the canonical script fails again on the next run.
- **Status:** RESOLVED in 29-18 by PR B, [security-platform#26](https://github.com/OttawaCloudConsulting/security-platform/pull/26), merged 2026-09-29 as `fdabac9` and released in `v1.2.0` (annotated tag object `b8ae59d`, which dereferences to `fdabac9`; `v1` was moved to `fdabac9`).
  - TRIAGE.md dedup bullet corrected (commit `71a388c`), with the "disposition covers future PRs" bullet also corrected.
  - `assert-pr-duplicates` trivy-image exclusion ported with the `D11-STEP2-EXCLUSION-KEY` check (commit `0f401f7`). The offline replay PASSes and the negative control reproduces the original FAIL.

### Follow-up (b): a fixed scan-image tag would let trivy-image dedupe across branches

- **Proposal:** in `security.yml`, the container job at `-t scan-target:${{ github.sha }}` and `trivy image scan-target:${{ github.sha }}` (lines 988 and 994 at 2fda1ac) would use a fixed tag, for example `scan-target:ci`, so identical image content produces identical findings on every branch.
- **Verify first:** which DefectDojo field carries the SHA into the dedup key for the `Trivy Scan` parser at 3.3.200: `file_path` (measured to hold it) or `description` (it may also embed the target), and which fields the `Trivy Scan` hash-code config actually uses. Confirm with a kind proof that two imports differing only in the tag dedupe after the change. Also check that SARIF `category: trivy-image` and the artifact names are unaffected.
- **Status:** OPEN. Not done in 29-16 and not in 29-18 PR B (#26). Still a candidate for a later phase. It changes `security.yml`, so it needs a `v1` consumer impact check.

### 29-19: ADR-027 must record the trivy-image dedup gap and the step-2 scope amendment

- ADR-027 must record two things. First, the live finding that trivy-image findings do not dedupe across branches, because the `scan-target:<github.sha>` tag changes per commit. Second, the D-11 step 2 scope amendment (operator ruling 2026-09-29, 29-CONTEXT.md), which excludes the trivy-image Test from the duplicates assertion. It must list both next to the re-parenting-not-exercised-live item, and point to follow-up (b).
