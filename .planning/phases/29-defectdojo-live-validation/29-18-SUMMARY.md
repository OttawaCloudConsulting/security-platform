---
phase: 29-defectdojo-live-validation
plan: 18
subsystem: k8s-infrastructure
tags: [defectdojo, release, v1.2.0, adr-018, dual-tagging, readme, triage, trivy-image, ddojo-05, d-09, d-17]
requires:
  - "29-16: live PR-lifecycle proof, including the trivy-image dedup finding and the step-2 amendment (deferred-items PR B items)"
  - "29-17: second-sync idempotency measured live (SECOND-SYNC-IDEMPOTENT PASS)"
  - "29-06: DEFECTDOJO_RUNS_ON routing merged to security-platform main as 2fda1ac"
provides:
  - "security-platform chart README: DDOJO-05 Complete (Phase 29), measured resync result with the staticName + Sync-hook recommendation, CSRF Origin mechanism"
  - "TRIAGE.md dedup exception for container-image (trivy-image) findings"
  - "assert-pr-duplicates excludes the trivy-image Test (D11-STEP2-EXCLUSION-KEY)"
  - "security-platform v1.2.0 (annotated tag b8ae59d -> fdabac9) and v1 moved to fdabac9, API-verified per ADR-018"
affects: [29-19, ADR-027, every @v1 consumer of security-platform]
tech-stack:
  added: []
  patterns:
    - "ADR-018 dual tagging: annotated vX.Y.Z plus lightweight v1 on the same merge commit, verified through gh api git/ref and git/tags"
    - "Record an accepted external-registry red check with its run and job ids, the error line and a same-SHA counter-evidence run, instead of rerunning it"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-18-tags.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-18-red-check-429.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-18-cleanup.txt
  modified:
    - .planning/phases/29-defectdojo-live-validation/deferred-items.md
    - repos/security-platform/kubernetes/defectdojo/README.md
    - repos/security-platform/kubernetes/defectdojo/TRIAGE.md
    - repos/security-platform/scripts/defectdojo-lifecycle-assert.sh
decisions:
  - "29-18: the PR #26 red check (security / Container — Trivy Image, run 36600468855 job 109516223383, public.ecr.aws 429 'toomanyrequests: Data limit exceeded' on the debian:12-slim base pull) is accepted by the operator as a known external registry 429 and not rerun. The same job at the same SHA passed in run 36600468850 (job 109516224085)"
  - "29-18: operator reply to Task 2 was 'approve'. PR #26 merged with --merge as fdabac9, v1.2.0 (annotated) cut on fdabac9, v1 (lightweight) moved from 917352c to fdabac9. Rollback: force v1 back to 917352c; v1.1.1 stays the immutable escape hatch"
  - "29-18: v1.2.0 also carries Phase 28 (dedup guards, system-settings bootstrap, triage runbook), which merged to main after v1.1.1 and was never tagged separately"
metrics:
  duration: "Task 1 in an earlier session; Task 3 continuation about 15 min (merge 22:03:51Z, tag verification 22:09:31Z)"
  completed: 2026-09-29
---

# Phase 29 Plan 18: security-platform close-out, PR B and v1.2.0 Summary

PR B ([security-platform#26](https://github.com/OttawaCloudConsulting/security-platform/pull/26)) merged as `fdabac9`. It records DDOJO-05 as Complete in the chart README, together with the measured resync and CSRF mechanisms, corrects the TRIAGE.md dedup claim for trivy-image findings, and ports the trivy-image exclusion into `assert-pr-duplicates`. `v1.2.0` was then cut as an annotated tag, and `v1` was moved to the same commit. Both were verified through the GitHub API per ADR-018.

## Operator reply (Task 2 checkpoint, verbatim)

> approve

Operator decision 1 (red check): "ACCEPT it as a known external registry 429. Do not rerun it."

## Release identity (evidence/29-18-tags.json, via gh api)

| Ref | Type | SHA | Dereferences to |
|-----|------|-----|-----------------|
| origin/main after merge | commit | `fdabac9464f2baaeaa276f8934dc8d353295b355` | parents `2fda1ac`, `0f401f7` |
| `v1` | commit (lightweight) | `fdabac9464f2baaeaa276f8934dc8d353295b355` | (was `917352c`) |
| `v1.2.0` | tag (annotated) | `b8ae59df7dcf6aec798dac699ca334d68812939d` | `fdabac9464f2baaeaa276f8934dc8d353295b355` |
| `v1.1.1` | tag (unchanged) | `c1565b35e88de4e70e61d79292943c15b3fe67f6` | `917352c00987023fa5ff1e6cdabc16987eb114dd` |

`v1.0.0` and `v1.1.0` are unchanged (ls-remote before and after). Only `refs/tags/v1` was force-pushed. Rollback: `git tag -f v1 917352c && git push -f origin refs/tags/v1`.

## Task results

| Task | Result | Commit(s) |
|------|--------|-----------|
| 1. README, script fixes, PR B | README: DDOJO-05 row Complete (Phase 29); resync bullet replaced (staticName: true, keepSeconds: 0, Sync hook + BeforeHookCreation, helm upgrade not exercised); CSRF caveat rewritten (Origin mechanism, no DD_SECURE_PROXY_SSL_HEADER behind a header-less proxy); no homelab literals. Gates: check-defectdojo-chart.sh PASS (22), check-workflow-uploads.sh PASS (19), shellcheck clean, PLAN-VERIFY-OK | security-platform `71a388c` (docs), `0f401f7` (fix) |
| 2. Checkpoint | Operator: "approve" | none |
| 3. Merge, tag, verify | PR #26 MERGED 2026-09-29T22:03:51Z as `fdabac9`; v1.2.0 pushed; v1 moved; API verification passed (jq acceptance true) | security-platform merge `fdabac9`; this repo `79d8623` |

## PR #26 checks and the accepted red check (evidence/29-18-red-check-429.txt)

Everything was green except `security / Container — Trivy Image` in PR Security run `36600468855`, job `109516223383`. That job failed in the docker build base-image pull, before any scan ran:

```
429 Too Many Requests - Server message: toomanyrequests: Data limit exceeded
(public.ecr.aws/docker/library/debian:12-slim@sha256:88200866...)
```

Counter-evidence: the same container job at the same head SHA `0f401f7` passed in DefectDojo Import Proof run `36600468850` (job `109516224085`, completed 16:49:32Z, 19s after the failing job ended). `prove-import` (job `109516595106`) passed in the same run, including `KIND-CELERY-PING: PASS`. The operator accepted the 429 without a rerun, and the merge was not refused by branch protection (no `--admin` was used).

## DefectDojo Cleanup after the merge (evidence/29-18-cleanup.txt)

The PR close started PR Security run `36637286444`. Its job `security / DefectDojo Cleanup` (`109640922581`) ran on ARC (label `occ-homelab-defectdojo`, runner `occ-homelab-defectdojo-qqrsp-runner-cs6wv`) and succeeded: `DELETED: engagement id=3 name='ci/feature/phase-29-defectdojo-closeout' product=1`, outcome `deleted`, deleted_ids `[3]`. That engagement had 7 of 8 reports, because the trivy-image report was lost to the 429. No manual cleanup was done.

## Local repo state

`repos/security-platform` is on `main` at `fdabac9` (fast-forwarded). The local branch `feature/phase-29-defectdojo-closeout` was deleted after the merge.

## Deviations from Plan

1. **[Scope, orchestrator-directed] TRIAGE.md edited outside files_modified.** `kubernetes/defectdojo/TRIAGE.md` was a PR B item in deferred-items.md (from 29-16, operator decision (d)). The dedup bullet was replaced with the deferred-items text. Commit `71a388c`.
2. **[Rule 1 - docs] Further stale statements corrected.** README around line 242, and the TRIAGE "disposition covers future PRs" bullet, contradicted the measured trivy-image behaviour, so both were corrected in the same commit (`71a388c`).
3. **[Commit split] docs + fix.** The plan named a single `docs(29-18)` commit. The helper behaviour change went into a separate `fix(29-18)` commit (`0f401f7`: the trivy-image exclusion in `assert-pr-duplicates` with the new `D11-STEP2-EXCLUSION-KEY` check), so the script change stays reviewable and revertible on its own. Evidence: `evidence/step2-assert.json` (original FAIL) and `evidence/step2-amended-assert.json`. The offline replay PASSes, and the negative control reproduces the original FAIL. `scripts/defectdojo-homelab-validate.sh` was not changed, because no defect in it was recorded live.
4. **[External] Red check accepted.** The plan says to STOP on any red check. The Task 1 executor stopped, and the operator accepted the trivy-image 429 as an external registry failure without a rerun (see above).

## Known Stubs

None.

## Next

29-19: ADR-027 must record the trivy-image dedup gap and the step-2 scope amendment (deferred-items). Follow-up (b), the fixed scan-image tag, stays open.

## Self-Check: PASSED

The four 29-18 files exist; commits 79d8623 (this repo) and 71a388c, 0f401f7, fdabac9 (security-platform) exist; the plan jq acceptance returns true; the README has the Complete (Phase 29) row; no homelab literals in the 29-18 evidence.
