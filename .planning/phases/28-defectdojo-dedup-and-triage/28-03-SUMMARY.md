---
phase: 28-defectdojo-dedup-and-triage
plan: 03
subsystem: DefectDojo live proof, Phase 28 block part 1 (security-platform)
tags: [defectdojo, deduplication, proof, kind, DDOJO-03]
requires:
  - "28-02: scripts/defectdojo-configure.sh (bare-token file contract; NO CHANGE / CHANGED: / VERIFIED: output)"
provides:
  - "prove_dedup_triage in scripts/defectdojo-import-proof.sh, called from mode_hook after prove_http_refusal and before proof_finish"
  - "Helpers for 28-04: write_dedup_py (settings / snapshot / findings-by-id), snapshot_engagement, read_settings, import_as_branch, wait_dedup_settled, print_masked, snippet, read_contact_info"
  - "Phase 28 identities: PROOF_DEDUP_PRODUCT, PROOF_REPARENT_PRODUCT, PROOF_DEDUP_PR, PROOF_SUPPRESS_PR, PROOF_REPARENT_PR"
  - "Run-time artifacts for 28-04: ${PROOF_DIR}/reports-main-trimmed, reports-trivy-only, delta.json, dedup-main.json, dedup-pr.json"
  - "Assertions P-CONFIGURE, P-IDEMPOTENT, P-DEDUP-MODE, P-DEDUP-BRANCH, P-CROSSTOOL plus CROSSTOOL: evidence lines"
affects: [28-04, 28-05, 28-06]
tech-stack:
  added: []
  patterns: ["env-only python3 heredoc read side with say() + tally_assert_log", "explicit limit/offset paging that never follows next", "client-side row selection instead of trusting API filters", "secret masking with bash builtins only (no argv exposure)"]
key-files:
  created: []
  modified:
    - repos/security-platform/scripts/defectdojo-import-proof.sh
decisions:
  - "The admin token is masked with a bash read/printf loop and checked with grep -F -f <file>, so the real superuser token never reaches any argv (the plan said sed replace; the sed idiom puts the token on sed's argv)"
  - "snapshot verifies every finding from ?test__engagement= belongs to a Test of the engagement, and user_contact_infos rows are selected client-side by .user: an ignored filter would otherwise return instance-wide rows silently"
  - "findings-by-id also returns the test's scan_type and title, so P-CROSSTOOL can type out-of-engagement originals"
  - "P-CROSSTOOL flags a cross-type link in either direction (an SCA duplicate of a non-SCA original, or the reverse), and compares component names case-insensitively for the Trivy/pip-audit overlap"
metrics:
  duration: ~35 min
  completed: 2026-09-26
  tasks: 2
  files: 1
---

# Phase 28 Plan 03: Phase 28 proof block, part 1 Summary

The live proof now has a Phase 28 block, `prove_dedup_triage`. It runs after every unchanged Phase 27 assertion, in the fresh product `proof/dedup`, and does five things:

- **P-CONFIGURE.** Runs the committed `scripts/defectdojo-configure.sh` with the admin token and checks the settings it leaves behind.
- **P-IDEMPOTENT.** Runs the script a second time and checks that nothing changes.
- **P-DEDUP-MODE.** Switches `ci-importer` to `async_wait`, in the harness only.
- **P-DEDUP-BRANCH.** Imports `ci/main` from reports with one trivy-fs vulnerability removed, then imports a PR from the full reports, and asserts that only that one finding stays active on the PR.
- **P-CROSSTOOL.** Measures the cross-tool SCA gap and prints it as `CROSSTOOL:` lines.

Every import goes through the committed dd-import body with the ci-importer token.

## Tasks

| Task | Name | Commit (security-platform) | Files |
| ---- | ---- | ------ | ----- |
| 1 | Block scaffold, helpers, P-CONFIGURE, P-IDEMPOTENT, P-DEDUP-MODE | 150abb3 | scripts/defectdojo-import-proof.sh |
| 2 | P-DEDUP-BRANCH with a unique delta, P-CROSSTOOL measurement | 76ce9cf | scripts/defectdojo-import-proof.sh |

Both commits are local on `feature/phase-28-defectdojo-dedup-and-triage`. Nothing was pushed.

## What the block asserts

- **P-CONFIGURE** emits 4 lines, and a failed run aborts the proof:
  - Run 1 exits 0 and prints a `CHANGED:` line that names enable_deduplication, plus a `VERIFIED:` line.
  - The read-back holds the 5 desired values. jq `==` compares types too.
  - `enable_finding_sla` is present and unchanged.
  - The token string does not appear in the log.
- **P-IDEMPOTENT** passes when run 2 exits 0, prints `NO CHANGE` and no `CHANGED:` line, and the `jq -S` settings snapshots are byte-equal (`cmp -s`). The bare-token file is removed afterwards, and also on every abort path before that.
- **P-DEDUP-MODE** GETs the importer's `user_contact_infos` row. If there is none it POSTs one (expect 201); if there is one it PATCHes it (expect 200). It then reads the row back and requires `async_wait`.
- **Delta.** The delta is the first trivy-fs `(VulnerabilityID, PkgName, InstalledVersion)` triple that occurs exactly once in trivy-fs.json and does not occur in trivy-image.json. It is recorded in `delta.json`. If no such triple exists, the proof aborts. `reports-trivy-only/` holds the untrimmed trivy-fs.json for 28-04.
- **P-DEDUP-BRANCH** emits 4 lines:
  - The PR holds at least 10 findings.
  - Exactly one PR finding is not a duplicate, and it is the active delta.
  - Every other PR finding is `duplicate=true`, `active=false`, and its original is in ci/main. An original outside ci/main is resolved and its engagement is reported.
  - No ci/main finding points into the PR.

  A counts line follows. The import is followed by `wait_dedup_settled`, which polls for at most 120 s.
- **P-CROSSTOOL** emits 3 lines:
  - All three SCA parsers are present in ci/main.
  - At least one package appears in both Trivy and pip-audit findings.
  - No duplicate link that touches an SCA finding crosses scan types.

  It then prints the `CROSSTOOL:` per-parser table and, for each overlapping package, the two id sets and their intersection.

## Evidence

- **Static gates.** `bash -n` and `shellcheck` are clean, both when run directly and through the pre-commit hook on both commits. The file mode is `-rw-r--r--`. `--extract-only` prints `EXTRACT PASS`. `--scheme-only` still ends `PROOF PASS - 7 assertions`, the same count as after 28-02. The block is `--hook` only. `check-defectdojo-chart.sh` prints `PASS - 22 checks, 0 failures`. Both plan `<automated>` verify commands passed, including the clean-tree check after commit 2.
- **Mock HTTPS DefectDojo run.** This went beyond the plan. It used a scratchpad server with a self-signed CA and a stub dd-import body; the functions were sourced from the committed script, and the real configure script was used.
  - Happy path: `PROOF PASS - 13 assertions`. The configure run printed `CHANGED: enable_deduplication, false_positive_history, risk_acceptance_form_default_days`, and the rerun printed `NO CHANGE`. The token string appeared 0 times in the output. The delta rule skipped a CVE that is also in trivy-image and picked the next unique triple. Paging over 600 findings (3 pages of 250) returned all rows.
  - Mutation run: the POST contact-info path passed. The proof reported FAIL for an extra non-duplicate PR finding, for a duplicate whose original is in another engagement (resolved through findings-by-id), and for a pip-audit to Trivy cross link. It ended `PROOF FAIL - 3 of 13`.
  - A missing `mitigated` key made the snapshot exit non-zero, naming the missing and present keys, and the proof aborted. Reports with no unique triple gave the `no unique trivy-fs vulnerability` abort.
- **Not yet run live.** The live kind run is 28-05.

## Deviations from Plan

**1. [Rule 2 - Security, T-28-11] Token masking without argv exposure.**
- **Found during:** Task 1
- **Issue:** The plan said to mask with "sed replace of the token file content". That puts the real superuser token on sed's argv, where `ps` can see it, and the script header says credentials are never placed on any argv.
- **Fix:** `print_masked` uses bash `read`, `printf` and `${line//"$tok"/<admin-token>}`. The absence check is `grep -qF -f <bare-token-file>`, which reads the pattern from the file. The bare file is checked to hold exactly one non-empty line before use, because an empty pattern line would match everything.
- **Commit:** 150abb3

**2. [Rule 2 - Correctness] Filters are not trusted.**
- **Found during:** Task 1
- **Issue:** Django-filter ignores unknown query parameters. If `test__engagement` or `user` were not honoured, the proof would silently read instance-wide rows.
- **Fix:** `snapshot` exits non-zero when a returned finding's test is not in the engagement's Test set, or when a Test belongs to another engagement. `read_contact_info` selects rows by `.user` on the client side and refuses a paged response.
- **Commit:** 150abb3

**3. [Rule 1 - Bug prevention] set -e safe error details.**
- **Found during:** Task 1
- **Issue:** Under `set -e`, a failing `$(head …)`, `$(cat …)` or `$(diff …)` inside an assignment would kill the script without printing a PROOF line.
- **Fix:** A `snippet` helper that never fails, and `|| true` on the diff pipeline.
- **Commit:** 150abb3

**4. [Interim lint] SC2329 in Task 1.**
- **Found during:** Task 1
- **Issue:** `snapshot_engagement`, `import_as_branch` and `wait_dedup_settled` had no caller until Task 2, so shellcheck reported SC2329.
- **Fix:** Task 1 carried per-function `# shellcheck disable=SC2329` comments, and Task 2 removed them. None remain.
- **Commits:** 150abb3, 76ce9cf

Additions within spec that are not deviations:
- `read_settings`, `snapshot_engagement`, `read_contact_info`, `snippet` and `print_masked` are small helpers.
- The settle poll compares duplicate and total counts, not only the duplicate count.
- The header's "Assertion groups" list now names the Phase 28 IDs.

## Known Stubs

None.

## Threat Flags

None. No new network surface: the block reads and writes only the throwaway kind DefectDojo, through the existing verified-TLS transport. The threat register is covered as follows:

- **T-28-11:** the token sits in a 0600 file, is passed by path, masked with builtins, removed afterwards, and its absence from the log is asserted.
- **T-28-12:** all imports go through `import_as_branch`, which runs the extracted committed body, and the configure script is run from the repository path.
- **T-28-13:** vacuous passes are blocked by the unique delta, the at-least-10 check, the parser-presence check and the overlap check.
- **T-28-14:** `async_wait` is set only on the harness user, and security.yml is untouched.

## Self-Check: PASSED

- `repos/security-platform/scripts/defectdojo-import-proof.sh` contains `prove_dedup_triage`, `write_dedup_py`, `import_as_branch` and `wait_dedup_settled`.
- Commits 150abb3 and 76ce9cf are present in the security-platform `git log`.
