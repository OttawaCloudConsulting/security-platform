---
phase: 28-defectdojo-dedup-and-triage
plan: 09
subsystem: documentation records (ADR, adoption guide, gate, requirements, validation)
tags: [defectdojo, deduplication, triage, adr, adoption-guide, DDOJO-03, DDOJO-04]
requires:
  - phase: 28-08
    provides: PR #23 merged as c8027e6 (merge SHA for ADR-026; blob/main TRIAGE.md resolves)
  - phase: 28-07
    provides: GitHub proof run 36261602015 attempt 1, PROOF PASS - 127 assertions
  - phase: 28-05
    provides: measured local kind evidence (evidence/28-05-local-proof.log)
provides:
  - ADR-026 (docs/adr/adr026-defectdojo-dedup-product-wide-and-triage-on-default-branch.md) and its index row
  - adoption guide section 12 "Deduplication and Triage" with the blob/main TRIAGE.md link; section 14 ADR-026 bullet
  - check-adoption-guide.sh DD_REQUIRED needles for the runbook link and defectdojo-configure.sh
  - DDOJO-03 and DDOJO-04 marked Complete; 28-VALIDATION.md signed off (nyquist_compliant true)
affects: [29]
tech-stack:
  added: []
  patterns: ["gate needle added RED first, observed failing, then the guide edit turns it GREEN"]
key-files:
  created:
    - docs/adr/adr026-defectdojo-dedup-product-wide-and-triage-on-default-branch.md
  modified:
    - docs/adr/README.md
    - docs/adoption-guide.md
    - scripts/check-adoption-guide.sh
    - .planning/REQUIREMENTS.md
    - .planning/phases/28-defectdojo-dedup-and-triage/28-VALIDATION.md
key-decisions:
  - "ADR-026 records FP/OOS as reading Mitigated from the moment of disposition (measured, 28-06), not after the next scan as the plan text said"
  - "ADR-026 closes ADR-024's Phase 28 hand-forward in prose: D-01 keeps deduplication_on_engagement at its default, so the PATCH/re-create step ADR-024 anticipated never arises; ADR-024 untouched"
metrics:
  duration: ~20 min
  completed: 2026-09-26
  tasks: 3
  files: 6
# backfilled Phase 29.7 (v3.0 audit item 7); closure first recorded under provides
requirements-completed: [DDOJO-03, DDOJO-04]
---

# Phase 28 Plan 09: ADR-026, runbook link and requirement sign-off Summary

ADR-026 now records Phase 28 in this repository: product-wide dedup, the delete-time re-parent that made D-03 unnecessary, the measured cross-tool gap (D-07), the two chart guards and the superuser bootstrap, and triage on the default branch. It cites the local proof (127 assertions), GitHub run 36261602015 and merge c8027e6. The adoption guide links the `TRIAGE.md` runbook on `blob/main`, the adoption-guide gate now requires that link and the bootstrap script name, and DDOJO-03 and DDOJO-04 are marked Complete.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Write ADR-026 and append its index row | f14e104 | docs/adr/adr026-...md, docs/adr/README.md |
| 2 (RED) | Require the runbook link in the gate | 83f7c02 | scripts/check-adoption-guide.sh |
| 2 (GREEN) | Link the runbook and bootstrap from the guide | 139e435 | docs/adoption-guide.md |
| 3 | Mark DDOJO-03/04 complete, sign off validation | a48839e | .planning/REQUIREMENTS.md, 28-VALIDATION.md |

## Evidence

- **Task 1 verify:** VERIFY1-OK. ADR-023/024/025 show no diff against 49811ff, and `docs/adr/README.md` gained 1 insertion. markdownlint-cli2 reported 0 errors on ADR-026 and the index.
- **Task 2 RED:** after the needles were added, the gate failed as expected:
  ```
  FAIL: DEFECTDOJO-SECTION: section at line 599 is missing required string(s): ['blob/main/kubernetes/defectdojo/TRIAGE.md', 'defectdojo-configure.sh']
  check-adoption-guide: PASSED 15 / FAILED 1
  ```
- **Task 2 GREEN:** `PASS: DEFECTDOJO-SECTION: section at lines 599-842 carries all 13 required strings`, then `check-adoption-guide: PASSED 16 / FAILED 0`, with MARKDOWNLINT passing. The link resolves: `gh api repos/OttawaCloudConsulting/security-platform/contents/kubernetes/defectdojo/TRIAGE.md?ref=main --jq .path` printed `kubernetes/defectdojo/TRIAGE.md`. VERIFY2-OK.
- **Task 3:** VERIFY3-OK. DDOJO-05 is still `[ ]` and Pending. 28-VALIDATION.md has no `⬜ pending` left and shows `nyquist_compliant: true`. Its approval line cites run 36261602015. The Wave 0 items were confirmed on origin/main: the `paths:` entry for `scripts/defectdojo-configure.sh`, and `CHECK_COUNT=22` along with the "22 offline invariants" literals.

## Deviations from Plan

**1. [Rule 1 - Accuracy] FP/OOS Mitigated timing in ADR-026.** The plan's Consequences bullet said FP/OOS findings "display as Mitigated after the next scan". 28-06 recorded that the evidence log shows `is_mitigated=True` before any reimport, with the mitigated timestamp equal to the disposition time and unchanged across two reimports. TRIAGE.md on main says the same. The plan also says to cite only measured values, so ADR-026 states the measured behaviour. Commit f14e104.

**2. [Rule 1 - Verify correctness] Status legend in 28-VALIDATION.md.** The legend line `*Status: ⬜ pending · ✅ green · ...*` matched the verify's `! grep -q '⬜ pending'`. The legend was rewritten without that entry. Commit a48839e.

**3. Additional "What was NOT verified" items.** Besides the four the plan named, ADR-026 lists Pattern 3 Caveats B and C (source-derived only) and risk-acceptance expiry (not exercised). All three come from RESEARCH and 28-05.

**4. Task 3 commit trailer.** The commit was made with the plan's prescribed `gsd-sdk query commit` command, which adds no Co-Authored-By trailer. The other three commits carry it.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: docs/adr/adr026-defectdojo-dedup-product-wide-and-triage-on-default-branch.md
- FOUND commits: f14e104, 83f7c02, 139e435, a48839e
- `bash scripts/check-adoption-guide.sh`: PASSED 16 / FAILED 0
