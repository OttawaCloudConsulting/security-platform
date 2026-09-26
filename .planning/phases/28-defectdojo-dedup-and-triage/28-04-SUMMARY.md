---
phase: 28-defectdojo-dedup-and-triage
plan: 04
subsystem: DefectDojo live proof, Phase 28 block part 2 (security-platform)
tags: [defectdojo, triage, risk-acceptance, deduplication, proof, kind, DDOJO-03, DDOJO-04]
requires:
  - "28-03: prove_dedup_triage, write_dedup_py (snapshot / findings-by-id), import_as_branch, wait_dedup_settled, snippet, reports-main-trimmed, reports-trivy-only, PROOF_SUPPRESS_PR, PROOF_REPARENT_PRODUCT, PROOF_REPARENT_PR"
provides:
  - "P-DISPOSITION: FP / OOS / RA on three unique ci/main trivy-fs findings, exact tuples after two in-place reimports, reactivated total 0, unchanged tuples and FP/OOS mitigated timestamps between reimports"
  - "P-SUPPRESS: one inactive PR duplicate per dispositioned original, zero active findings on ci/proof/pr-suppress"
  - "P-REPARENT (prove_reparent): delete-time re-parent in proof/dedup-reparent through the committed dd-delete body"
  - "Helpers findings_by_ids, disposition_write, assert_disposition; global DEDUP_B_DELETE"
  - "Header docstring: Phase 28 --hook scenarios, all nine Phase 28 ids, the configure-script admin-token exception"
affects: [28-05, 28-06]
tech-stack:
  added: []
  patterns: ["env-only python3 heredoc read side with say() + tally_assert_log (28-03 idiom)", "admin writes with -H @file and jq-built 0600 bodies removed after use", "skip-not-abort for a self-contained scenario via its own function and return 0"]
key-files:
  created: []
  modified:
    - repos/security-platform/scripts/defectdojo-import-proof.sh
decisions:
  - "Disposition selection also excludes any finding that a ci/main finding points at as its original, so a vulnerability trivy-image also reports cannot give P-SUPPRESS two PR copies of one original"
  - "The disposition tuples are asserted on all five flags (false_p, out_of_scope, risk_accepted, active, is_mitigated), not only the three the plan names per role"
  - "P-REPARENT is its own function (prove_reparent) called at the end of prove_dedup_triage, so a failed import or precondition skips the rest with return 0 instead of aborting the proof"
  - "The ci/main read after the delete happens before the outcome and engagement-gone checks, so nothing but the snapshot sits between the DELETE and the read"
metrics:
  duration: ~20 min
  completed: 2026-09-26
  tasks: 2
  files: 1
---

# Phase 28 Plan 04: Phase 28 proof block, part 2 Summary

The live proof now asserts the triage guarantees and the delete-time re-parent. All three run inside `prove_dedup_triage`, after P-CROSSTOOL, with the ci-importer token for every committed-body run.

- **P-DISPOSITION** sets three ci/main findings to False Positive, Out of Scope and Risk Accepted, reimports ci/main twice from the same trimmed reports, and asserts the exact state after each reimport.
- **P-SUPPRESS** imports a new PR from the same reports and asserts the dispositions keep its copies inactive.
- **P-REPARENT** deletes a PR engagement through the committed dd-delete body and asserts the default-branch findings become active originals again straight away.

## Tasks

| Task | Name | Commit (security-platform) | Files |
| ---- | ---- | ------ | ----- |
| 1 | P-DISPOSITION (two reimports, exact tuples) and P-SUPPRESS | 3a18625 | scripts/defectdojo-import-proof.sh |
| 2 | P-REPARENT and the header docstring | cf0f6c7 | scripts/defectdojo-import-proof.sh |

Both commits are local on `feature/phase-28-defectdojo-dedup-and-triage`. Nothing was pushed.

## What the block asserts

- **Selection.** A fresh ci/main snapshot must hold exactly one Test titled `trivy-fs`. From it the proof takes the three lowest-id findings that are active, non-duplicate, unverified and undispositioned, whose title occurs once in that Test, and that no ci/main finding points at as its original. It prints FP_ID, OOS_ID and RA_ID. Fewer than three is `proof_abort P-DISPOSITION`.
- **Dispositions.** Admin writes, with the header passed by path and jq-built 0600 bodies removed after use:
  - FP: `PATCH /api/v2/findings/<id>/ {false_p: true, active: false, verified: false}`, expect 200.
  - OOS: `PATCH {out_of_scope: true, active: false}`, expect 200.
  - RA: `POST /api/v2/risk_acceptance/`, expect 201. Owner is the admin user id, read by username and selected client-side. `expiration_date` is UTC today + 90 days, and `decision_details` is "P-DISPOSITION proof: reason recorded per TRIAGE.md".

  A wrong HTTP code aborts and prints up to 400 characters of the body. A read-back then emits 3 lines, each showing its flag true and active=false.
- **Two reimports.** Each goes to `ci/main` from `reports-main-trimmed`, with results in `results-disp-1.json` and `results-disp-2.json`. After each one the proof emits:
  - 1 line: exit 0 and the Test count unchanged.
  - 3 lines: the exact five-flag tuple for each id. FP is `false_p=T oos=F ra=F active=F is_mitigated=T`, OOS is `oos=T` with the rest the same pattern and `is_mitigated=T`, and RA is `ra=T active=F is_mitigated=F`.
  - 1 line: trivy-fs `statistics.delta.reactivated.total == 0`. The delta object is printed for 28-05. If the path is missing, the line fails and prints the statistics, delta and reactivated keys.

  After reimport 2, one more line asserts that the tuples and the FP/OOS `mitigated` timestamps equal those after reimport 1.
- **P-SUPPRESS.** PR `ci/proof/pr-suppress` is imported from the trimmed reports, followed by `wait_dedup_settled` and a snapshot. It emits:
  - 3 lines: for each dispositioned id, exactly one PR finding with `duplicate_finding` equal to it, and that finding is duplicate=true and active=false.
  - 1 line: the PR engagement has zero active findings, and is not empty.
- **P-REPARENT.** This runs in `proof/dedup-reparent`: `ci/proof/pr-first` is imported first, then `ci/main`, both from `reports-trivy-only`, followed by `wait_dedup_settled`.
  - Precondition line: K, the number of PR non-duplicates, is at least 1, all K are active, and every ci/main finding is a duplicate whose original is in the PR.
  - The delete runs through `$DEDUP_B_DELETE` with the P-CLEANUP env list (the reparent product, `GITHUB_HEAD_REF=proof/pr-first`).
  - ci/main is snapshotted immediately and the proof prints `P-REPARENT timing: read <n> s after the DELETE returned`.
  - 1 line: exit 0, outcome `deleted`, and the PR engagement is gone.
  - 2 lines: ci/main has exactly K findings with duplicate=false and active=true, and every remaining ci/main duplicate points inside ci/main.

  An import, snapshot or precondition failure is reported and the rest of P-REPARENT is skipped, without aborting.
- **Docstring.** The `--hook` description lists the Phase 28 scenarios. The assertion-group list names `P-CONFIGURE P-IDEMPOTENT P-DEDUP-MODE P-DEDUP-BRANCH P-CROSSTOOL P-DISPOSITION P-SUPPRESS P-REPARENT (28-03/28-04)`. The old "Every body run uses the ci-importer token." is replaced: every committed-body run uses ci-importer, and `scripts/defectdojo-configure.sh` is the one run made with the admin (superuser) token, because `/api/v2/system_settings/` is superuser-only (RESEARCH Pitfall 2). The least-privilege paragraph now points to the Phase 28 admin writes.

On a fully passing live run, this plan adds 22 PROOF lines to 28-03's 13, so the Phase 28 block emits 35:
- P-DISPOSITION: 3 + (1 + 3 + 1) × 2 + 1 = 14
- P-SUPPRESS: 4
- P-REPARENT: 1 + 1 + 2 = 4

The P-REPARENT timing line is evidence output, not a PROOF line.

## Evidence

- **Static gates.** `bash -n` and `shellcheck` are clean, both when run directly and through the pre-commit hook on both commits. The file mode is `-rw-r--r--`. `--extract-only` prints `EXTRACT PASS`. `--scheme-only` prints `PROOF PASS - 7 assertions`, unchanged because the block is `--hook` only. `check-defectdojo-chart.sh` prints `PASS - 22 checks, 0 failures`. `check-workflow-uploads.sh`, `check-detector-parity.sh` and `actionlint` are all green. Both plan `<automated>` verify commands passed, including the clean-tree check.
- **Synthetic unit runs.** These went beyond the plan. Every new Python heredoc was extracted from the committed script and run against scratchpad JSON:
  - `assert_disposition` stages 0-2 passed on correct tuples. They failed on a missing `delta` (printing `statistics keys: ['after', 'before']`) and on a re-stamped FP/OOS `mitigated`.
  - The selection skipped a repeated title and a finding that a trivy-image copy pointed at.
  - P-SUPPRESS passed on the expected shape.
  - The P-REPARENT precondition computed K=2. The post-delete check passed on a correct re-parent and failed, with both lines, on an un-re-parented set.
- **Not yet run live.** The tuples, the statistics path and the re-parent are source-derived. 28-05 is the live kind run.

## Deviations from Plan

**1. [Rule 1 - Bug prevention] Stricter disposition selection.**
- **Found during:** Task 1
- **Issue:** The plan's rule (a title unique in the trivy-fs Test) allows a vulnerability that trivy-image also reports. Both parsers are "Trivy Scan", so the trivy-image copy in ci/main is a duplicate of the trivy-fs finding. The PR import would then create two copies pointing at the same original, and P-SUPPRESS's "exactly one" would fail even though suppression works.
- **Fix:** The selection also requires that no ci/main finding has `duplicate_finding` equal to the candidate. This is the same concern 28-03 handled when it picked the delta.
- **Commit:** 3a18625

**2. [Structure] P-REPARENT is a called function.**
- **Found during:** Task 2
- **Issue:** The plan says to append P-REPARENT to `prove_dedup_triage` and to skip its remainder on an import or precondition failure.
- **Fix:** It lives in `prove_reparent`, called at the end of `prove_dedup_triage`, so `return 0` does the skip cleanly. The behaviour is the one the plan specifies.
- **Commit:** cf0f6c7

Additions within spec that are not deviations:
- `findings_by_ids`, `disposition_write` and `assert_disposition` are small helpers.
- The tuples are asserted on all five flags.
- The least-privilege docstring paragraph was updated because it said the admin token is used "only to create that user and for read-side assertions", which is no longer true.

## Known Stubs

None.

## Threat Flags

None. No new network surface: the block writes only to the throwaway kind DefectDojo, over the existing verified-TLS transport.

- **T-28-15:** covered by the exact tuples, reactivated total 0, and unchanged state across two reimports.
- **T-28-16:** P-SUPPRESS proves suppression from ci/main dispositions.
- **T-28-17:** P-REPARENT deletes through the committed dd-delete body and proves the re-parent.
- **T-28-18:** the admin header is sent only with `-H @file`, bodies are 0600 files removed after use, and the admin token is never placed on any argv.

## Self-Check: PASSED

- `repos/security-platform/scripts/defectdojo-import-proof.sh` contains P-DISPOSITION, P-SUPPRESS, P-REPARENT, `/api/v2/risk_acceptance/`, `results-disp-2.json` and `PROOF_REPARENT_PRODUCT`.
- Commits 3a18625 and cf0f6c7 are present in the security-platform `git log`.
