---
phase: 29-defectdojo-live-validation
plan: 04
subsystem: live-validation
tags: [defectdojo, d-11, pr-lifecycle, dedup, dispositions, api-assertions, bash]
requires:
  - "29-01 (the security-platform phase branch and the homelab-validate accounting core)"
provides:
  - "repos/security-platform/scripts/defectdojo-lifecycle-assert.sh (subcommands snapshot, assert-pr-duplicates, disposition, assert-dispositions, assert-closed)"
affects: [29-15, 29-16]
tech-stack:
  added: []
  patterns:
    - "The pass/fail/NOTHING RAN accounting core copied from defectdojo-homelab-validate.sh, with abort = fail + SKIPPED for dependents + summary"
    - "Offset paging (limit=250&offset=N until count rows, count stable) that never follows DRF's next URL"
    - "Client-side filter guards: products by name_exact plus exact name, engagements by exact name and product, findings checked against the engagement's Test ids, Under Review rows re-checked field by field"
key-files:
  created:
    - repos/security-platform/scripts/defectdojo-lifecycle-assert.sh
  modified: []
decisions:
  - "List reads never follow DRF's next link. Behind the L4 TLS proxy, DRF builds next as http://, and the --proto =https pin would refuse it. The script uses the import-proof offset loop instead. This deviates from the plan's wording, which said to follow next."
  - "D11-STEP5-ENGAGEMENT-GONE asserts that the set of engagements with exactly the name ci/<branch> is empty, and records the API's raw count beside it. The engagement name filter is not proven exact."
  - "D11-STEP5-NO-DANGLING-DUPLICATE also counts duplicate=true with a null duplicate_finding as dangling, because that is the shape an on-delete SET_NULL would leave. It reads the whole product by enumerating its engagements and reading each with test__engagement, not through an unproven product-level finding filter."
  - "An empty set of other findings in step 2 is a FAIL, not a pass. D-11 step 2 needs pre-existing duplicates, so an empty set would make the check pass without testing anything."
  - "disposition re-reads each of the three findings live (active, non-duplicate, in a snapshot Test) after the snapshot pre-validation and before any write (T-29-12). It refuses to run when <out>/dispositions.json already exists."
  - "The assert-closed snapshot must be taken after the step-4 reimport and immediately before the PR is closed. This is stated in the usage text and the header."
  - "DDOJO-05 is not marked complete. The helper has not run against the live instance yet (plans 29-15 and 29-16 run it)."
metrics:
  duration: "389min wall clock (13:41Z to 20:11Z, including idle time)"
  completed: 2026-09-27
  tasks: 2
  files: 1
---

# Phase 29 Plan 04: DefectDojo PR-lifecycle API assertion helper Summary

This plan adds `defectdojo-lifecycle-assert.sh`, the Wave 0 helper for the D-11 API assertions. It asserts the real PR lifecycle from API state and writes an evidence JSON file for each subcommand. The Under Review filter is copied verbatim from TRIAGE.md, and the disposition tuples come from the import proof. Step 5 follows the amended D-11, so re-parenting is not asserted.

The helper is committed on the security-platform branch `feature/phase-29-defectdojo-live-validation` at `32da9f55b815a7b9a17d8bb69d1a707dd3e29892`, with mode 100644. It is not pushed; plan 29-06 pushes. `git log origin/main..HEAD` now lists exactly 2 commits: 29-01 (`9726b35`) and 29-04 (`32da9f5`).

## Final CLI usage

```
DEFECTDOJO_URL=https://<host> DEFECTDOJO_ADMIN_TOKEN_FILE=<0600 file, bare admin token> \
  bash scripts/defectdojo-lifecycle-assert.sh <subcommand> --product <name> --out <evidence-dir> [flags]

  snapshot             --engagement <name> --label <label>                        -> <out>/<label>-snapshot.json
  assert-pr-duplicates --branch <b> --main-snapshot <file> --fixture-path <path>  -> <out>/step2-assert.json
  disposition          --main-snapshot <file> --fp <id> --oos <id> --ra <id>      -> <out>/dispositions.json
  assert-dispositions  --dispositions <file>                                      -> <out>/step4-assert.json
  assert-closed        --branch <b> --main-snapshot <file> --dispositions <file>  -> <out>/step5-assert.json

Exit codes: 0 ALL PASS (or NOTHING RAN; snapshot: file written), 1 FAIL, 2 usage or preflight error.
```

The D-11 order for plans 29-15 and 29-16:
1. `snapshot --engagement ci/main --label base`
2. `assert-pr-duplicates`
3. `disposition`
4. The reimport, then `assert-dispositions`
5. `snapshot --engagement ci/main --label preclose`, then close the PR, then `assert-closed --main-snapshot <preclose>`

`--branch` takes the bare branch name, and the engagement name `ci/<b>` is derived from it. A value that starts with `ci/` is refused.

## Assertion IDs

- **Step 2:** `D11-STEP2-ENGAGEMENT`, `D11-STEP2-UNTRIAGED-EQ-FIXTURE` and `D11-STEP2-DUPLICATES-POINT-TO-MAIN`.
- **Step 3:** `D11-STEP3-PREVALIDATE`, `D11-STEP3-RA-OWNER`, `D11-STEP3-WRITE`, then the read-backs `D11-STEP3-FP`, `D11-STEP3-OOS` and `D11-STEP3-RA` (the flag is true and active=false, as in import-proof stage 0).
- **Step 4:** `D11-STEP4-FP`, `D11-STEP4-OOS` and `D11-STEP4-RA`, each an exact tuple from P-DISPOSITION, plus `D11-STEP4-RA-EXPIRY`. The RA-EXPIRY check requires that the risk acceptance still exists, keeps the same expiry date, has a non-empty decision_details and still holds the ra finding.
- **Step 5:** `D11-STEP5-ENGAGEMENT-GONE`, `D11-STEP5-MAIN-COUNT-UNCHANGED` (same engagement id and name, count equal, with added and removed ids on a failure), `D11-STEP5-DISPOSITIONS-UNCHANGED` (the step-4 comparisons re-run) and `D11-STEP5-NO-DANGLING-DUPLICATE` (for up to 10 offenders, it records the HTTP status of the referenced id).
- The `INFO: re-parenting NOT asserted (D-11 amended 2026-09-26)` line is printed on every assert-closed run.

## Verification

**Plan checks:**
- The Task 1 and Task 2 automated verify commands both passed. shellcheck 0.11.0 is clean.
- Running with no arguments exits 2. An `http://` URL exits 2 before the token file is read.
- The acceptance greps gave these results:
  - `set -x` in non-comment lines: 0
  - lines that echo a token variable: none
  - `--proto =https`: 3
  - ` -k |--insecure`: 0
  - `days=90`: 1
  - `decision.{0,4}"A"`: 1
  - `risk_acceptance`: 15
  - `re-parenting NOT asserted`: 1
  - every D11 ID is present as a literal
- The security-platform pre-commit hooks passed on the commit, including shellcheck.

**Offline end-to-end test (beyond the plan):** I ran all five subcommands against a local mock DefectDojo over TLS in the session scratchpad. The mock used a self-signed certificate, supplied to curl through a `CURL_HOME` curlrc, and capped pages at 2 rows so that paging was exercised.
- **Happy path:** snapshot (4 findings over 2 pages), then step 2 (3/3 PASS), step 3 (5/5 PASS), step 4 (4/4 PASS), then the simulated PR close and step 5 (4/4 PASS). The mock's engagement name filter is a contains filter, and the exact-name selection handled it correctly.
- **Negative cases:**

  | Case | Result |
  |------|--------|
  | Wrong fixture path | UNTRIAGED-EQ-FIXTURE and DUPLICATES-POINT-TO-MAIN FAIL, exit 1 |
  | Missing branch | ENGAGEMENT FAIL, the others SKIPPED, exit 1 |
  | Running disposition again on dispositioned findings | refused by the live re-read, nothing written, exit 1 |
  | Non-distinct ids | refused before any API call |
  | Reactivated FP, an extra ci/main finding and a duplicate pointing at a deleted id | DISPOSITIONS-UNCHANGED, MAIN-COUNT-UNCHANGED and NO-DANGLING-DUPLICATE FAIL (the referenced id returned 404), exit 1 |
  | Token file with mode 644 | exit 2 |
  | Flag that does not belong to the subcommand | exit 2 |
  | Wrong token (401) | FAIL with the path and code and no token, exit 1 |

- **No token leak:** the token string does not appear in any evidence file, and the evidence files are mode 0600.

**Not verified:** the script has not run against the live DefectDojo 3.3.200 API. The field names, the `name_exact` and `username` filters and the risk_acceptance shape come from the Phase 28 proof, not from a live run by this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Pagination does not follow `next`**
- **Found during:** Task 1
- **Issue:** The plan said to follow the `next` pagination links. Behind the L4 TLS proxy, DRF builds `next` as `http://`, so the `--proto =https` pin would refuse the second page. The import-proof reader avoids `next` for the same reason.
- **Fix:** The script pages with `limit=250&offset=N` until it holds `count` rows, fails if `count` changes while paging, and fails on an empty page before `count` is reached.
- **Files modified:** scripts/defectdojo-lifecycle-assert.sh
- **Commit:** 32da9f5

**2. [Rule 1 - Bug] Two jq defects found by the offline mock test, before the commit**
- **Found during:** Task 2 verification
- **Issue:** The field-presence check in `slim` evaluated `has(.)` against the finding object, not the key, and failed at runtime. The step-2 filter-violation `select` had a misplaced parenthesis and did not compile.
- **Fix:** Bound the key (`. as $k | ... has($k)`) and corrected the parenthesis. Both fixes were re-tested on the mock.
- **Files modified:** scripts/defectdojo-lifecycle-assert.sh
- **Commit:** 32da9f5 (both fixed before the single commit)

**3. [Rule 2 - Critical] Additional guards (T-29-12 and the "never assumed" rule)**
- **Added:**
  - a live re-read of the disposition targets before any write;
  - a refusal to disposition twice into one evidence dir;
  - an input check that the product of the snapshot and the dispositions file matches `--product`;
  - client-side re-checks of the Under Review rows;
  - a FAIL when the step-2 set of other findings is empty;
  - null `duplicate_finding` counted as dangling;
  - the Trivy `verified=true` caveat in the header and in the step-2 failure detail.
- **Commit:** 32da9f5

**4. Commit shape.** Tasks 1 and 2 edit one file, and Task 2's acceptance requires exactly 2 commits on `origin/main..HEAD` (29-01 and 29-04). The work was therefore committed once, as the `feat(29-04)` commit the plan names, with no separate Task 1 commit.

## Known Stubs

None.

## Threat Flags

None. The only surface is the workstation-to-DefectDojo API boundary that the plan's threat model already covers (T-29-03, T-29-08, T-29-12).

## Self-Check: PASSED

- FOUND: repos/security-platform/scripts/defectdojo-lifecycle-assert.sh (mode 100644 in the index)
- FOUND: security-platform commit 32da9f5 on feature/phase-29-defectdojo-live-validation
