---
phase: 28-defectdojo-dedup-and-triage
plan: 08
subsystem: ci-publish
tags: [defectdojo, dedup, triage, merge, github]
requires:
  - phase: 28-07
    provides: open PR OttawaCloudConsulting/security-platform#23 (head c77e4f4) with green proof run 36261602015
provides:
  - PR #23 merged to security-platform main as merge commit c8027e6784ec631db128f45444c9a8092db9d0a1
  - evidence/28-08-post-merge.txt (verification read from origin/main)
  - merge SHA for ADR-026 (28-09)
affects: [28-09, 29]
tech-stack:
  added: []
  patterns: ["merge gate: operator approval, head SHA re-checked before gh pr merge --merge, verified from origin/main (27-12 pattern)"]
key-files:
  created:
    - .planning/phases/28-defectdojo-dedup-and-triage/evidence/28-08-post-merge.txt
  modified: []
key-decisions:
  - "PR #23 merged with gh pr merge --merge after the operator replied 'Approved — merge' with no rejected decision; merge commit c8027e6 has parents 917352c (main) and c77e4f4 (PR head)"
  - "No workflow, caller or required-checks change and no tag movement: v1 stays 917352c; the chart moves to 0.2.0; the feature branch was not deleted"
metrics:
  duration: ~5 min (Task 2)
  completed: 2026-09-26
---

# Phase 28 Plan 08: Merge Phase 28 PR and verify from origin/main Summary

The operator approved the merge and PR #23 was merged into security-platform main as merge commit c8027e6. Every check was read from origin/main after a fetch. origin/main has both D-20 guards, CHECK_COUNT=22, the configure script, the P-REPARENT and P-DISPOSITION proof ids, TRIAGE.md and chart version 0.2.0. The four workflow and required-check files are byte-identical to 917352c, and v1 still points at 917352c.

## Task 1 record (operator approval)

- Operator reply, verbatim: "Approved — merge"
- Rejected decisions: none (a–d presented: a. dedup OFF until operator runs scripts/defectdojo-configure.sh once with a superuser token, Phase 29 must include it, CI token not used; b. cross-tool SCA collapse not shipped — 3.3.200 cannot, measured; within-tool + cross-branch only (D-01); c. no security.yml/caller change, no v1.x tag, v1 stays 917352c, chart 0.2.0; d. merge to public main effectively irreversible)
- PR #23 https://github.com/OttawaCloudConsulting/security-platform/pull/23 at approval: OPEN, CLEAN, MERGEABLE, head c77e4f4d47e820c76914ca798a88be9b610fb130; proof run 36261602015 attempt 1 success, `PROOF PASS - 127 assertions`, `ALL PASS - 13 live check(s)`.

## Task 2 results

Just before the merge, `gh pr view 23` returned state OPEN, CLEAN, MERGEABLE, headRefOid c77e4f4d47e820c76914ca798a88be9b610fb130 (the approved head), and `git ls-remote origin refs/heads/main` returned 917352c00987023fa5ff1e6cdabc16987eb114dd. `gh pr merge 23 --merge` was run with no `--delete-branch`, `--admin` or `--auto`, and it exited 0.

| Item | Value (read from remote) |
|------|-------|
| PR state | MERGED, mergedAt 2026-09-26T18:55:24Z |
| Merge SHA | c8027e6784ec631db128f45444c9a8092db9d0a1 |
| Parents (`git rev-list --parents -n1 origin/main`) | 917352c00987023fa5ff1e6cdabc16987eb114dd (main) and c77e4f4d47e820c76914ca798a88be9b610fb130 (PR head) |
| values.yaml | line 119 `DD_DUPLICATE_CLUSTER_CASCADE_DELETE: "False"`; line 125 `DD_DEDUPLICATION_ALGORITHM_PER_PARSER` |
| check-defectdojo-chart.sh | line 553 `CHECK_COUNT=22` |
| defectdojo-configure.sh | present; `risk_acceptance_form_default_days` at lines 28, 107, 210 |
| defectdojo-import-proof.sh | P-REPARENT and P-DISPOSITION present |
| TRIAGE.md | present (`# DefectDojo Triage Runbook`) |
| Chart.yaml | `version: 0.2.0` |
| `git diff --quiet 917352c origin/main -- security.yml pr-security.yml scheduled-security.yml set-required-checks.sh` | exit 0 |
| `git diff --stat 917352c origin/main` | 8 files, +2007/-22; no security.yml, caller or set-required-checks change |
| v1 tag (`git ls-remote --tags origin v1 'v1^{}'`) | 917352c00987023fa5ff1e6cdabc16987eb114dd refs/tags/v1 (lightweight; matches 28-01) |
| Feature branch on remote | still present at c77e4f4 (not deleted) |

The plan's `<automated>` verify ran with exit 0. The token-pattern scrub grep matched nothing, so the file is clean.

## Commits

- 4b7388b: test(28-08): record Phase 28 merge verification from origin/main

## Deviations from Plan

None - plan executed exactly as written. `gsd-sdk query commit` refused the first commit attempt because the evidence file ended in a blank line (whitespace check). The trailing blank line was removed and the commit went through. The file content was not changed otherwise.

## Notes for 28-09

- ADR-026 merge reference: c8027e6784ec631db128f45444c9a8092db9d0a1 (PR #23).
- DDOJO-03/DDOJO-04 were not marked complete in REQUIREMENTS.md here; 28-09 owns that.
- The local repos/security-platform checkout was left on the feature branch, and nothing was verified from the local tree.

## Self-Check: PASSED

FOUND: 28-08-SUMMARY.md, evidence/28-08-post-merge.txt, commit 4b7388b, security-platform merge commit c8027e6.
