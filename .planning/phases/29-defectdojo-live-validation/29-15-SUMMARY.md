---
phase: 29-defectdojo-live-validation
plan: 15
subsystem: ci-cd
tags: [defectdojo, arc, live-import, ci-main-baseline, d-06, d-10, d-12, ddojo-02, ddojo-05]
requires:
  - "29-14: DEFECTDOJO_API_TOKEN secret and DEFECTDOJO_RUNS_ON / DEFECTDOJO_URL variables on security-platform"
  - "29-04: scripts/defectdojo-lifecycle-assert.sh snapshot subcommand"
provides:
  - "First live import: ci/main engagement id 1 in product id 1 (OttawaCloudConsulting/security-platform), 155 findings, tests 1-8"
  - "evidence/main-baseline-snapshot.json, the ci/main originals for the 29-16 D-11 lifecycle"
  - "Job placement proof: DefectDojo Import on ARC occ-homelab-defectdojo, five scans on GitHub-hosted ubuntu-latest"
  - "D-10 proof-workflow side effect measured: routed to ARC, SKIP logged, nothing imported, count unchanged"
affects: [29-16, ADR-024, ADR-027]
tech-stack:
  added: []
  patterns:
    - "Job runner placement is read from gh api actions/runs/<id>/jobs; gh run view --json jobs returns null runnerName/labels"
    - "A job log from a still-running run is fetched with gh api --allow-escape-sequences actions/jobs/<id>/logs"
    - "Log extracts drop the step-script echo lines ([36;1m marker), so source-code literals such as FAIL are not taken for runtime output"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-15-baseline-run.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-15-baseline-import.log
    - .planning/phases/29-defectdojo-live-validation/evidence/main-baseline-snapshot.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-15-proof-run.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-15-proof-side-effect.txt
    - .planning/phases/29-defectdojo-live-validation/deferred-items.md
  modified: []
decisions:
  - "29-15: the live DefectDojo product name is OttawaCloudConsulting/security-platform (product_type CI), read from the run log product= line; product id 1, ci/main engagement id 1"
  - "29-15: the ci/main baseline holds 155 findings in tests 1-8; 29-16 uses evidence/main-baseline-snapshot.json as --main-snapshot"
  - "29-15: the plan's count_before/count_after backreference regex is not strict (155 vs 154 matches); use an anchored numeric equality check"
metrics:
  duration: "~14 min (2026-09-29T00:17:35Z to 00:31Z)"
  completed: 2026-09-29
  tasks: 2
  files: 6
---

# Phase 29 Plan 15: First live import, ci/main baseline and D-10 proof side effect Summary

security-platform imported into the live DefectDojo for the first time. The import ran on the ARC runner, as ci-importer, over system-verified TLS. The resulting `ci/main` baseline (155 findings) is snapshotted for 29-16. The proof workflow's D-10 side effect was measured exactly: it routed to ARC, logged SKIP, imported nothing, and the finding count stayed the same.

## Observed, not hidden

**The proof workflow run 36502717161 is red.** Its `prove-import` job (109197316267, ubuntu-latest) failed at `KIND-CELERY-PING: FAIL - celery -A dojo inspect ping exited 69 without pong`. That check runs inside the throwaway kind DefectDojo on the hosted runner, not against the live instance. Every earlier kind check passed. The same proof passed on 2026-09-27 (run 36350180923) at the code now on main. One run cannot tell a readiness race apart from a regression, and the plan did not ask for a rerun. The job is logged in `deferred-items.md`. `main` now shows a red "DefectDojo Import Proof" run.

## Task 1: live baseline import (commit 81d0a9d)

| Item | Value |
|---|---|
| Run | 36502430372, `workflow_dispatch` on `main` (head 2fda1ac), conclusion success, dispatched 00:18:22Z |
| DefectDojo Import job | 109196329353, runner `occ-homelab-defectdojo-qqrsp-runner-tbt47`, labels `["occ-homelab-defectdojo"]`, success |
| Scan jobs (5) | Gitleaks, Trivy Image, Trivy Filesystem, Checkov, Semgrep CE: all `GitHub Actions 10000012xx`, labels `["ubuntu-latest"]`, success |
| DefectDojo Cleanup | skipped (not a closed event), routed label `occ-homelab-defectdojo` |
| TLS | `TLS mode: verified-system` |
| Product (from log) | `product=OttawaCloudConsulting/security-platform product_type=CI engagement=ci/main` |
| Imports | 8 of 8 IMPORTED, http 201, test_ids 1-8; `attempted=8 skipped=0 failed=0`; dd-verify `DefectDojo import verified: 8 report(s) into OttawaCloudConsulting/security-platform / ci/main` |
| Snapshot | `evidence/main-baseline-snapshot.json`: product id 1, engagement `ci/main` id 1, count 155, test_ids [1..8], captured 00:20:46Z |

Cross-check: the per-test `after_total` values sum to 155 (7+14+6+59+18+2+46+3), which matches the snapshot count. The `gh api .../runs/36502430372/jobs` read-back confirms the ARC runner name. 29-13 could not give that evidence while minRunners was 0.

## Task 2: proof-workflow D-10 side effect (commit 6b536e8)

| Item | Value |
|---|---|
| Run | 36502717161, `workflow_dispatch` on `main`, dispatched 00:21:47Z, conclusion failure (prove-import only) |
| `scans / DefectDojo Import` | 109197273118, ran (not skipped), runner `occ-homelab-defectdojo-qqrsp-runner-ntr9z`, success; queued 00:22:37Z, started 00:22:42Z |
| Log | `SKIP: DEFECTDOJO_API_TOKEN is not available to this run (...) — nothing sent to DefectDojo`; 0 IMPORTED lines |
| Count | `count_before=155` (00:21:42Z) `count_after=155` (00:28:40Z), product 1 |
| Five scans | all on GitHub-hosted ubuntu-latest, success |
| prove-import | **failure**, KIND-CELERY-PING (see above) |

Filter guard: the filtered (`test__engagement__product=1`) and unfiltered finding counts were both 155, before and after. Product 1 is the only product and `ci/main` the only engagement. A filter the API silently ignored therefore could not have hidden a change.

## Deviations from Plan

**1. [Rule 3 - Blocking] `gh run view --json jobs` returns null `runnerName` and `labels`**
- Job placement came from `gh api repos/.../actions/runs/<id>/jobs` (`runner_name`, `runner_group_name`, `labels`), mapped to the plan's field names. The source is recorded in each run JSON's `jobs_source`. The plan's acceptance criterion already names this endpoint.

**2. [Rule 3 - Blocking] `*.log` is ignored by the user's global `~/.gitignore`**
- The plan requires `29-15-baseline-import.log`, so it was added with `git add -f`, following 29-08's precedent (commit a40c5a8).

**3. [Rule 3 - Blocking] ugrep 7.8.4 rejects the `\1` backreference under `-E`**
- The Task 2 verify ran with `/usr/bin/grep -Eq` (BSD) and passed.

**4. [Rule 1 - Bug] The plan's count-equality regex is not strict**
- A negative control, `count_before=155 count_after=154`, matched `count_before=([0-9]+).*count_after=\1`, because `\1` can bind the prefix `15`. An anchored numeric check (`sed` extract, then `awk $1==$2`) passes on the evidence and rejects the negative control. 29-16 should not reuse the loose pattern.

**5. [Rule 3 - Blocking] The pre-commit hook rejected trailing whitespace**
- The verbatim KIND-CELERY-PING log line ended in a space. Trailing whitespace was stripped in the evidence file. The content is otherwise unchanged.

**6. Log-extract filter**
- Step-script echo lines (those with the `[36;1m` marker) were excluded, since they contain source literals such as `FAIL`. The header wording also avoids that literal, so the "no FAIL line" check tests runtime output only.

**Working-tree note:** the local `repos/security-platform` clone was switched from `feature/phase-29-defectdojo-live-validation` (e8387a8, already merged) to `main` (2fda1ac, `git pull --ff-only`, already up to date) so the helper ran on main, as the plan requires. It was left on `main`. `repos/` is not tracked by this repository.

## Threat model

- T-29-03: only filtered log lines were saved. Every 40-hex string in the evidence is the public main commit SHA 2fda1ace…. No `Token ` string appears. The admin token was read into a 0600 header file in a trap-removed `mktemp -d`.
- T-29-08: `TLS mode: verified-system` is asserted, with no CA override.
- T-29-07: neither import job queued longer than 5 s, well inside the 10-minute threshold.

## Threat Flags

None. No new surface beyond the plan's threat model.

## Known Stubs

None.

## Self-Check: PASSED
- FOUND: the five evidence files, deferred-items.md and 29-15-SUMMARY.md
- FOUND commits: 81d0a9d, 6b536e8
- Plan verify for Task 1: passed. Task 2: passed with BSD grep and the strict equality check.
