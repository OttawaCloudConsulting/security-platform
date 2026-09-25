---
phase: 27-defectdojo-ci-auto-import
plan: 06
subsystem: live-proof-harness
tags: [defectdojo, kind, live-proof, reimport, cleanup, hostile-input, tls, github-actions]
requires:
  - "27-05 defectdojo-import-proof.sh (entry, --extract-only, --hook, run-1 assertions) and the smoke post-hook"
  - "27-02 / 27-03 committed dd-import, dd-verify, dd-delete, dd-cleanup-verify bodies in security.yml"
  - "27-04 check-workflow-uploads.sh (18 checks; SHA-PIN walks every workflow file)"
provides:
  - "defectdojo-import-proof.sh: P-RUN2, P-SCHEDULE, P-HOSTILE, P-SCOPE, P-CLEANUP, P-REFUSE, P-NOMATCH, P-INSECURE and a final PROOF PASS/FAIL verdict"
  - ".github/workflows/defectdojo-import-proof.yml: scans (uses security.yml) + prove-import (kind harness), D-19/D-21"
  - "evidence/27-06-local-proof.log: full local end-to-end run, PROOF PASS - 85 assertions, smoke ALL PASS"
affects: [27-07, 27-10]
tech-stack:
  added: []
  patterns:
    - "Read-side lookups written once to $PROOF_DIR/read.py; inputs by env only, so a hostile engagement name never enters a shell string"
    - "Hostile head ref held as a single-quoted readonly literal and passed only as a quoted NAME=VALUE into run_body's export builtin"
    - "Two-job proof workflow: uses-job produces artifacts, second job runs the kind proof on its own runner"
key-files:
  created:
    - repos/security-platform/.github/workflows/defectdojo-import-proof.yml
    - .planning/phases/27-defectdojo-ci-auto-import/evidence/27-06-local-proof.log
  modified:
    - repos/security-platform/scripts/defectdojo-import-proof.sh
key-decisions:
  - "P-RUN2 iterates the run-2 attempted list and requires the same non-empty file set as run 1, so an empty run-1 record cannot pass vacuously; the hook aborts before run 2 if any run-1 assertion failed"
  - "P-INSECURE passes DD_CA_CERT empty so exactly one ::warning:: line is expected, and asserts tls_mode insecure, attempted=0, skipped=8 (all eight table rows) and exit 0"
  - "P-HOSTILE checks for a pwned file in the body cwd, the repo root and anywhere under DD_SMOKE_OUT"
  - "Evidence .log files are matched by the user's global ~/.gitignore (*.log); force-added by explicit path, as the Phase 25 .log evidence was"
requirements-completed: []  # DDOJO-02 partial (6 of 10 plans); marked complete by 27-10
duration: ~20min
completed: 2026-09-25
---

# Phase 27 Plan 06: Complete the proof harness, add the proof workflow, and run it locally

The harness now covers every D-20 assertion group. The groups are the run-2 in-place reimport, the schedule branch, a hostile branch name, product-scoped cleanup, the cleanup refusals and no-match no-op, and the insecure-TLS warning. `defectdojo-import-proof.yml` will run it on GitHub. A full local run against a real DefectDojo on kind passed: **PROOF PASS - 85 assertions**, and the smoke reported `ALL PASS - 13 live check(s)` including `POST-HOOK: PASS`.

## Tasks

| Task | Name | Commit | Repo |
|------|------|--------|------|
| 1 | Add the run-2, schedule, hostile-name, scope, cleanup, refuse, no-match and insecure-warning assertions | `7c47270` | security-platform (`feature/phase-27-defectdojo-ci-auto-import`) |
| 2 | Add the defectdojo-import-proof.yml workflow | `7c47270` | security-platform |
| 3 | Run the full harness locally against kind and record the evidence | `3227352` | this repo |

As the plan specified, Tasks 1 and 2 share one commit: `test(27-06): complete DefectDojo proof harness and add proof workflow`.

## Live run (Task 3)

- **Source reports:** the `*-results` artifacts of PR Security run **36088129070** (2026-09-25), copied flat into one directory. Eight table files were present: semgrep, checkov, trivy-fs, trivy-image, gitleaks, npm-audit-1, pip-audit-1 and tflint.sarif. The extra `*.sarif` files are ignored by the table.
- **Tool versions:** Docker server 28.3.2, kind v0.33.0, Helm v4.3.0+gbec5b06, kubectl client v1.37.1, curl 8.7.1, yq v4.53.6, jq-1.8.2, python 3.12.0.
- **Timing:** started 2026-09-25T15:20:08Z, finished 15:23:53Z, **225 s wall-clock**. That is well under the 15-30 min estimate, most likely because the images were already cached locally. Harness exit code: 0.
- **Teardown:** `kind get clusters` printed `No kind clusters found.` after the run.
- **Secret scrub:** grepping for `Token `, `password`, `aA1!` and long hex/alphanumeric runs found only narrative lines, with no values. Nothing needed redacting. The only change made to the log was stripping one trailing space from the header line I wrote myself; the commit hook required it.

**Run 1: raw count vs imported count**

| file | raw | imported | rule |
|------|-----|----------|------|
| semgrep | 7 | 7 | bounded |
| checkov | 14 | 14 | exact |
| trivy-fs | 6 | 6 | exact |
| trivy-image | 59 | 59 | exact |
| gitleaks | 18 | 18 | bounded |
| npm-audit-1 | 8 | 2 | bounded |
| pip-audit-1 | 46 | 46 | exact |
| tflint.sarif | 3 | 3 | bounded |

**Run 2:** for all 8 files, `delta.created.total.total` was 0, `after.total.total` matched run 1, and the `test_id` matched run 1. The engagement Test count stayed at 8.

**Other groups:**
- **P-SCHEDULE:** created `ci/main`.
- **P-HOSTILE:** created an engagement named literally `ci/@dd-proof/$(touch pwned)`, and no `pwned` file appeared anywhere checked.
- **P-SCOPE:** the twin engagement was created in `proof/other-product`.
- **P-CLEANUP:** deleted only the hostile engagement in `proof/security-platform`. The twin, `ci/proof/branch-a` (8 Tests) and `ci/main` all survived, and dd-cleanup-verify exited 0.
- **P-REFUSE:** both `main` and an empty head ref were refused.
- **P-NOMATCH:** returned nothing-to-delete, and the engagement count stayed at 3.
- **P-INSECURE:** printed the `::warning::` line and made no request (tls_mode insecure, 0 attempted, 8 skipped).

### 27-05 live-only facts, now observed

| Fact (RESEARCH-derived in 27-05) | Observed |
|---|---|
| The users API GET returns `is_staff` / `is_superuser` | Yes. `ci-importer` read back as `is_staff=true is_superuser=false` (P-USER PASS) |
| The tests API returns `title` / `scan_type` | Yes. All 8 tests matched the expected title and scan_type (P-TESTS PASS) |
| `api-token-auth` accepts `ci-importer` (no forced password reset) | Yes. It returned 200 with a token (P-IMPORTER-TOKEN PASS), and every body run used that token |
| Unauthenticated `GET /api/v2/` | Returns **403**. P-TLS asserts only curl exit 0, ssl_verify_result 0 and a non-000 code, so it passes |
| Reimport response carries `statistics.delta.created.total.total` | Yes, present for all 8 scan types at 3.3.200 |
| The staff, non-superuser token can DELETE an engagement | Yes. The hostile engagement was deleted by `ci-importer` |

## Verification (all run, all observed)

| Check | Result |
|-------|--------|
| `shellcheck scripts/defectdojo-import-proof.sh`; `bash -n` | exit 0 / exit 0 |
| `--extract-only` | `EXTRACT PASS`, 7 passed |
| All 8 new IDs present; `PROOF INCOMPLETE` count; `eval` count | present / 0 / 0 |
| `--insecure`, `/etc/hosts`, curl `-k`, `set -x` greps | all clean |
| File mode of the script | 644 |
| All 4 embedded Python heredocs compile (`py_compile`) | ok (106 / 53 / 225 / 75 lines) |
| Offline driver: hostile ref passed through `run_body` | body printed `GOT=@dd-proof/$(touch pwned)`, rc 0, no `pwned` file |
| `actionlint` on the new file and on all 4 workflows | exit 0 |
| `check-workflow-uploads.sh` | `PASS - 18 checks, 0 failures` |
| jobs keys; `scans.uses`; `scans.secrets`; `prove-import.needs`/`.if` | `prove-import scans` / `./.github/workflows/security.yml` / `null` / `scans` / `always()` |
| paths filter; `has("workflow_dispatch")` | all 7 paths / `true` |
| helm sha256, `sha256sum -c`, harness command present; `shell:`/`chmod`; `${{` in run bodies | 3 / 0 / 0 |
| Pre-commit hooks on the security-platform commit | shellcheck, yamllint Passed |
| Evidence verify line (PROOF PASS, ALL PASS, no token or password) | VERIFY-OK; a PASS line for each of the 15 required IDs |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The evidence log is gitignored by the user's global `~/.gitignore`**
- **Found during:** Task 3 commit
- **Issue:** `gsd-sdk query commit` refused, because `/Users/christian/.gitignore:18:*.log` matches the evidence file.
- **Fix:** `git add -f` on that single explicit path. This matches the Phase 25 precedent, where `.log` evidence files are tracked. No ignore file was changed.
- **Commit:** `3227352`

**2. [Rule 2 - Correctness] P-RUN2 cannot pass vacuously**
- **Found during:** Task 1
- **Issue:** Comparing only the files listed in `proof-run1.json` would pass if that list were empty.
- **Fix:** The hook aborts before run 2 if any run-1 assertion failed. P-RUN2 iterates the run-2 `attempted` list and requires the same non-empty file set. If `statistics.delta` is missing, the FAIL line prints the real statistics keys.
- **Commit:** `7c47270`

**3. [Rule 2 - Correctness] The body logs are echoed into stdout**
- **Found during:** Task 1
- **Issue:** The smoke's EXIT trap deletes `$DD_SMOKE_OUT`, so the body logs would not survive as evidence.
- **Fix:** Every new `run_body` call is followed by `sed 's/^/    | /' "$BODY_LOG"`, which copies its log into stdout.
- **Commit:** `7c47270`

**4. Harness-side additions within the specified assertions**
- P-RUN2 also runs dd-verify on the run-2 results.
- P-INSECURE also asserts exit 0 and `tls_mode insecure`, and passes `DD_CA_CERT` empty so that exactly one warning line is expected.
- P-HOSTILE also checks the repo root for a `pwned` file.

None of these loosen an assertion. The exact-count rules are unchanged.

## Notes for 27-07 (GitHub run)

- The `prove-import` job relies on `kind`, `kubectl`, `yq`, `jq` and `docker` being preinstalled on `ubuntu-latest`, as the plan's interfaces spec says. Only Helm is installed explicitly. If the image lacks kind, the harness preflight exits 2 and names the missing binary.
- security.yml's artifact uploads are `if: always()` with no pull_request-only condition, so `workflow_dispatch` runs also produce `*-results` artifacts.

## Known Stubs

None. The 27-05 `PROOF INCOMPLETE` stub is gone.

## Threat Flags

None beyond the plan's register. T-27-01 (P-HOSTILE), T-27-03 (P-CLEANUP, P-SCOPE, P-REFUSE, P-NOMATCH), T-27-04 (P-TLS, P-INSECURE), T-27-02 (pre-commit scrub), T-27-SC (sha256-verified Helm, SHA-pinned actions, the SHA-PIN gate) and T-27-18 (`pull_request`, no secrets, read-only job permissions) are each implemented and, where live, observed passing.

## Self-Check: PASSED

- FOUND: repos/security-platform/scripts/defectdojo-import-proof.sh
- FOUND: repos/security-platform/.github/workflows/defectdojo-import-proof.yml
- FOUND: .planning/phases/27-defectdojo-ci-auto-import/evidence/27-06-local-proof.log
- FOUND: commit 7c47270 in repos/security-platform
- FOUND: commit 3227352 in this repo
