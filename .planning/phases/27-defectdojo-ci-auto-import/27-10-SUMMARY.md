---
phase: 27-defectdojo-ci-auto-import
plan: 10
subsystem: records
tags: [defectdojo, adr, requirements, validation, sign-off]
requires:
  - "27-07 PR #21 merge 0f7e4e1 and proof run 36156728300"
  - "27-08 v1.1.0 (tag object 414fd3b) and v1 at 0f7e4e1; dispatch runs 36159160216 (flake) and 36160366711 (pass)"
  - "27-09 adoption guide section 14 link to adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md"
provides:
  - "ADR-024 (Accepted) with Context, Decision, Measured evidence, Consequences and What was NOT verified"
  - "ADR index row for ADR-024"
  - "DDOJO-02 Complete in REQUIREMENTS.md (checklist and traceability)"
  - "27-VALIDATION.md signed off (status approved, nyquist_compliant true, wave_0_complete true)"
affects: [28, 29]
tech-stack:
  added: []
  patterns:
    - "Requirement closed only after re-reading the release refs from the GitHub API, not from a SUMMARY"
key-files:
  created:
    - docs/adr/adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md
    - .planning/phases/27-defectdojo-ci-auto-import/27-10-SUMMARY.md
  modified:
    - docs/adr/README.md
    - .planning/REQUIREMENTS.md
    - .planning/phases/27-defectdojo-ci-auto-import/27-VALIDATION.md
key-decisions:
  - "ADR-018's 'gate_mode is the only substitution point' is narrowed in ADR-024 (gate_mode stays the only setting that changes gating; DEFECTDOJO_* are opt-in side channels); ADR-018 not edited"
  - "Adoption guide section 8 'five contexts' wording vs seven security / ... check runs recorded as a follow-up in ADR-024, not edited (outside this plan's files)"
requirements-completed: [DDOJO-02]
duration: ~25min
completed: 2026-09-25
---

# Phase 27 Plan 10: ADR-024, DDOJO-02 closure and validation sign-off Summary

ADR-024 records the opt-in DefectDojo CI import as shipped in `v1.1.0`: one `defectdojo-import` job after the five scans, `ci/<branch>` reimport with `auto_create_context`, exact-name engagement delete on PR close, an optional declared secret, TLS verified by default, and the 85-assertion kind proof. It quotes only measured values and ends with nine unverified items. DDOJO-02 is marked Complete, and 27-VALIDATION.md is signed off.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write ADR-024 and append its index row | `854f9ba` | docs/adr/adr024-...md, docs/adr/README.md |
| 2 | Mark DDOJO-02 Complete, sign off VALIDATION | `854f9ba` (one combined commit, as the plan specifies) | .planning/REQUIREMENTS.md, 27-VALIDATION.md |

## Pre-conditions checked before any status change

- **Remote release (queried in this plan through the GitHub API):**
  - `git/ref/tags/v1` gave `0f7e4e141d2a300d4be9a54efc137eb4510bb7ea`, which equals the 27-07 merge SHA.
  - `v1.1.0` is `tag 414fd3beb5a6d79d52316150a192803a4b0ece78`, which dereferences to `0f7e4e1…`.
  - `releases/latest` is `v1.1.0`.
- **Proof logs:**
  - `evidence/27-06-local-proof.log:272` reads `PROOF PASS - 85 assertions`.
  - `evidence/27-07-proof-run.log:284` reads `PROOF PASS - 85 assertions`.
- **GitHub-run counts:** the P-COUNTS lines in the 27-07 log match the 27-06 local run's per-file numbers (7, 14, 6, 59, 18, 2 of 8, 46, 3). The ADR attributes the table to both runs.
- **Quick-run latency:** the three static gates took **1.44 s** real time, measured in this plan with `time`. This is the evidence for the "< 10s" sign-off item.

## Verification (observed)

- Task 1 `<verify>` passed: the file exists, it has `## What was NOT verified`, the index row is present, ADR-001/017/018/023 are unchanged against HEAD, and `markdownlint-cli2` reports 0 errors on both files.
- Task 2 `<verify>` passed, and `check-adoption-guide.sh` gives `PASSED 16 / FAILED 0`. The section 14 link to ADR-024 now resolves to a file.
- Acceptance greps passed:
  - D-01 through D-22 are all present.
  - `**Status:** Accepted`, `is_staff`, `Phase 28`, `Phase 29`, `SARIF`, `schedule`, `0f7e4e1`, `36156728300`, `36160366711` and `v1.1.0` are all present.
  - No IPv4 address appears.
- `git status --short docs/adr` before the commit listed only the new ADR and `README.md`.
- REQUIREMENTS.md changed in exactly 2 lines. DDOJO-03, DDOJO-04 and DDOJO-05 are still Pending.
- `git diff --check` is clean on all four files.

## Validation sign-off detail

- **Frontmatter:** `status: approved`, `nyquist_compliant: true`, `wave_0_complete: true`.
- **Wave 0 items:** all 5 ticked. Each names the plan that delivered it: 27-01, 27-04, 27-05, 27-06.
- **Per-task map:** all 12 rows flipped to ✅. Each cites the gate output or the proof run id that supports it.
- **Sign-off checklist:** all 6 items ticked, with these grounds:
  - Every task in 27-01 to 27-10 has an `<automated>` block, counted per plan. This includes the 27-07 and 27-08 checkpoint tasks.
  - The latency item cites the measured 1.44 s.
  - I read "no watch-mode flags" as holding. `gh run watch --exit-status` blocks until one run finishes and does not loop, and I annotated the item to say so.
- **Manual-only rows:**
  - The closed-PR row is annotated as observed in 27-08 (run 36158851741). The reopen window itself was not exercised.
  - The 06:00 scheduled-run row is annotated **not yet observed**.
- **Approval line:** `approved 2026-09-25`, citing runs 36156728300 and 36160366711 and the 27-06 local proof.

## Deviations from Plan

1. **[Wording] ADR-024 has an extra "Measured evidence" subsection under Decision.** The plan lists four sections. The run ids, counts and SHAs are grouped under `### Measured evidence` inside Decision, so each Decision bullet stays short. The four required sections are all present and in order.
2. **[Rule 2 - Correctness] The staff-token Consequence was corrected before commit.** The first draft said a narrower identity "cannot create a new Product Type". 27-RESEARCH says it can, if it holds the Django permission `dojo.add_product_type`. The text now says that, and says the narrower set was not built or tested.
3. **[Mechanics] The commit used `git commit` with explicit `git add` paths**, not `gsd-sdk query commit`. The files and the message are as the plan specifies, and the hooks ran.

## Open concerns carried forward (recorded in ADR-024)

- A stray public `v2.0` tag exists. The operator said to leave it for now.
- The parent repository's `origin` is the public repo. It must never be pushed.
- The `KIND-CELERY-PING` smoke check is single-shot and should be retried (see 36159160216).
- Adoption guide section 8 still says "five contexts". Seven `security / ...` check runs now appear. I recorded this as a follow-up and did not edit the guide.
- No consumer has enabled the import yet. The first scheduled run has not been observed.

## Known Stubs

None.

## Threat Flags

None. T-27-21: the ADR contains no homelab host, IP, token or product name. The only hostnames are the RFC 2606 and `.invalid`/`.test` harness names. T-27-22: only the new ADR and the README changed under `docs/adr/`.

## Self-Check: PASSED

- FOUND: docs/adr/adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md
- FOUND: docs/adr/README.md ADR-024 row (last table row)
- FOUND: commit 854f9ba
