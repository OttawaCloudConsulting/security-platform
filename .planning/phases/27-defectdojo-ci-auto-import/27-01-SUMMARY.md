---
phase: 27-defectdojo-ci-auto-import
plan: 01
subsystem: ci-static-gates
tags: [defectdojo, github-actions, static-gate, required-checks, sha-pin]
requires: []
provides:
  - "check-workflow-uploads.sh side-channel contract (SCAN_JOB_IDS / SIDE_CHANNEL_JOB_IDS, 16 checks)"
  - "check-adoption-guide.sh DERIVE-CONTEXTS keyed on SCAN_JOB_IDS"
affects: [27-02, 27-03, 27-04, 27-09]
tech-stack:
  added: []
  patterns:
    - "Per-job vacuous checks that print 'NOTE: <LABEL> vacuous — <job> not present'"
    - "WORKFLOWS_DIR / REQUIRED_CHECKS_SCRIPT env overrides for scratch-copy self-tests"
key-files:
  created: []
  modified:
    - repos/security-platform/scripts/check-workflow-uploads.sh
    - scripts/check-adoption-guide.sh
key-decisions:
  - "Side-channel checks are per job and vacuous when the job is absent; OPTIONAL-SECRET is vacuous only when both side-channel jobs are absent"
  - "IMPORT-VERIFY-PAIRING reads the later red step's env: values, not its run: body, so it composes with NO-INTERPOLATION"
  - "SIDE-CHANNEL-NOT-REQUIRED is plain substring matching on set-required-checks.sh, so even a comment naming a DefectDojo job fails it"
requirements-completed: []  # DDOJO-02 partial (1 of 10 plans); not marked complete
duration: ~20min
completed: 2026-09-25
---

# Phase 27 Plan 01: Gate split into scan and side-channel jobs Summary

Both offline gates now know the five frozen scan jobs by id. `check-workflow-uploads.sh` allows only `defectdojo-import`/`defectdojo-cleanup` beside them and never lets either become a required check. It enforces their shape once they exist (16 checks) and pins actions in every workflow file. `check-adoption-guide.sh` builds its five contexts from the scan-job ids only.

## Tasks

| Task | Name | Commit | Repo |
|------|------|--------|------|
| 1 | Split JOB-SHAPE, glob all workflow files, add side-channel checks | `3adbfc9` | security-platform (branch `feature/phase-27-defectdojo-ci-auto-import`, created from `main` @ 71a112e) |
| 2 | Derive adoption-guide contexts from scan-job ids | `a58427c` | this repository |

## What changed

**check-workflow-uploads.sh (security-platform)**
- `WORKFLOWS_DIR` (default `.github/workflows`) and `REQUIRED_CHECKS_SCRIPT` (default `scripts/set-required-checks.sh`) are read from env inside the python block.
- `DOCS` is a sorted glob of `*.yml` and `*.yaml`, with each file loaded once. PERMISSIONS-FORBIDDEN, SHA-PIN and the step-level checks walk every file. The header comment and the header echo now say so.
- `SCAN_JOB_IDS` and `SIDE_CHANNEL_JOB_IDS` (plus `SIDE_CHANNEL_JOB_NAMES`) are new constants.
- JOB-SHAPE checks four things:
  - each scan id exists;
  - no scan job has `needs:`;
  - the scan jobs' names, read in id order, equal FROZEN_JOB_NAMES;
  - any other id must be on the side-channel allow-list.
- The new checks are SIDE-CHANNEL-NOT-REQUIRED (always active), SIDE-CHANNEL-SHAPE, OPTIONAL-SECRET, NO-INTERPOLATION, IMPORT-VERIFY-PAIRING and INSECURE-WARNING. `CHECK_COUNT = 16`.
- NOTE lines print before the final PASS/FAIL line.

**check-adoption-guide.sh (this repository)**
- DERIVE-CONTEXTS reads `callee_jobs[jid]["name"]` for each id in `SCAN_JOB_IDS` and fails with the id's name when a job or its `name:` is missing.
- The `!= 5` and caller `!= 1` assertions are unchanged, and a comment explains why the side-channel jobs are excluded.

## Verification evidence

- The gate on today's tree exits 0. It prints 9 NOTE lines, including `NOTE: SIDE-CHANNEL-SHAPE vacuous — defectdojo-import not present` and `NOTE: IMPORT-VERIFY-PAIRING vacuous — defectdojo-import not present`, and its last line is `PASS - 16 checks, 0 failures`.
- `git diff --quiet main -- scripts/set-required-checks.sh .github/workflows/` exits 0.
- `shellcheck` passes on both scripts. `stat -f '%Lp'` gives 644 for both.
- `check-detector-parity.sh` gives `PASSED 20 / FAILED 0`.
- `bash scripts/check-adoption-guide.sh` exits 0 with `PASSED 15 / FAILED 0` and these five contexts:
  - `security / SAST — Semgrep CE`
  - `security / IaC — Checkov`
  - `security / SCA — Trivy Filesystem`
  - `security / Container — Trivy Image`
  - `security / Secrets — Gitleaks`

### Behavior cases (after the change, real script with env overrides pointed at scratch copies)

| Case | rc | Output (scratch path shortened to `$S`) |
|------|----|------------------------------------------|
| today's tree | 0 | `PASS - 16 checks, 0 failures` |
| extra job `rogue:` | 1 | `FAIL: JOB-SHAPE: $S/cases/rogue/.github/workflows/security.yml declares job 'rogue', which is neither a scan job ['sast', 'iac', 'sca', 'container', 'secrets'] nor an allow-listed side-channel job ['defectdojo-import', 'defectdojo-cleanup']` |
| `sast` gains `needs: [iac]` | 1 | `FAIL: JOB-SHAPE: jobs.sast declares needs: — the scan jobs must stay fully parallel` |
| set-required-checks.sh contains `DefectDojo Import` | 1 | `FAIL: SIDE-CHANNEL-NOT-REQUIRED: $S/cases/reqcheck/scripts/set-required-checks.sh mentions 'DefectDojo Import' — a side-channel job must never be a required check (Phase 27 D-03)` |
| third file `extra.yml` with `actions/checkout@v7` | 1 | `FAIL: SHA-PIN: $S/cases/thirdfile/.github/workflows/extra.yml jobs.x.steps[0] is not pinned to a full 40-character lowercase hex SHA: actions/checkout@v7` |

I also ran two extra fixtures that were not in the plan. They exercise the present-job branches that 27-02 through 27-04 will rely on:
- A conforming import and cleanup pair, plus `DEFECTDOJO_API_TOKEN` declared with `required: false`, gives `PASS - 16 checks, 0 failures`.
- A violating pair gives rc 1 with five failures:
  - SIDE-CHANNEL-SHAPE: needs was `['sast']`;
  - OPTIONAL-SECRET: the secret was not declared;
  - NO-INTERPOLATION: dd-verify's run had `${{`;
  - IMPORT-VERIFY-PAIRING: no env read `steps.dd-import.outcome`;
  - INSECURE-WARNING: dd-delete had no `::warning::`.

### Adoption-gate fixture (Task 2)

The fixture was `security.yml` plus `defectdojo-import: {name: DefectDojo Import, runs-on: ubuntu-latest, steps: [{run: echo}]}`, run through a scratch copy of the script with only `HOST_SECURITY_YML` changed.
- New script, rc 0: `DERIVED contexts (5):`, the same five contexts, and `PASS: DERIVE-CONTEXTS: derived 5 contexts from $S/fixture-security.yml job name: values + caller job id 'security'`.
- Original (HEAD~) script on the same fixture: `FAIL: DERIVE-CONTEXTS: expected exactly 5 job name: values in $S/fixture-security.yml, found 6: [..., 'DefectDojo Import']`. This confirms Pitfall 1 was real.

All scratch copies were deleted afterwards.

## TDD Gate Compliance

Task 1 is marked `tdd="true"`, but the plan specifies a single `test(27-01): ...` commit and there is no separate test file. So there is no separate RED commit. Instead, RED evidence came from running the four crafted cases against the UNMODIFIED script, copied into fake repo roots:
- rogue: rc 1 (JOB-SHAPE `declares 6 job(s)`)
- needs: rc 1 (JOB-SHAPE needs)
- reqcheck: **rc 0, `PASS - 10 checks`** (wrongly passed)
- thirdfile: **rc 0, `PASS - 10 checks`** (wrongly passed)

After the change (GREEN), all four fail with the labels in the table above.

## Deviations from Plan

None in substance. Small additions within scope:
- Updated the file's header comment (L15 said "parses BOTH workflow files") as well as the header echo. It would otherwise have gone stale the same way.
- Added `SIDE_CHANNEL_JOB_NAMES` as a constant so SIDE-CHANNEL-NOT-REQUIRED does not repeat the name strings.
- Ran the two extra side-channel fixtures (conforming and violating) described above.

## Known Stubs

None.

## Next Phase Readiness

- 27-02 and 27-03 can add the jobs. The gate will enforce needs, if, secret optionality, no-interpolation, verify pairing and the insecure warning as soon as each job exists.
- 27-04 should make the checks mandatory by turning the vacuous NOTE branches into failures.

## Self-Check: PASSED
