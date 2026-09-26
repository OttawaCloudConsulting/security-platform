---
phase: 27-defectdojo-ci-auto-import
plan: 14
subsystem: docs-adr-adoption-guide
tags: [security, defectdojo, tls, cr-01, gap-closure, adr]
gap_closure: true
requires: ["27-13"]
provides:
  - "ADR-025 (Accepted): DefectDojo CI import refuses non-HTTPS URLs; supersedes ADR-024 decision 13 in prose for non-https URLs"
  - "ADR index row for ADR-025"
  - "Adoption guide section 12 states DEFECTDOJO_URL must be https://; section 14 cross-references ADR-025"
  - "check-adoption-guide.sh DEFECTDOJO-SECTION needle 'must be https://' (11 required strings)"
affects: ["Phase 28", "Phase 29"]
tech-stack:
  added: []
  patterns: ["append-only ADR supersede-in-prose (ADR-021 -> ADR-020 precedent)", "gate needle proven non-vacuous by pre-count 0 and scratch negative self-test"]
key-files:
  created:
    - docs/adr/adr025-defectdojo-import-https-only.md
  modified:
    - docs/adr/README.md
    - docs/adoption-guide.md
    - scripts/check-adoption-guide.sh
decisions:
  - "CR-01 recorded as new ADR-025 superseding ADR-024 decision 13 in prose for non-https URLs; ADR-024 byte-unchanged"
  - "Adoption guide gate DEFECTDOJO-SECTION now requires 'must be https://' (10 -> 11 required strings)"
metrics:
  completed: 2026-09-25
  tasks: 2
  files: 4
---

# Phase 27 Plan 14: ADR-025 https-only DefectDojo import, guide and gate Summary

The CR-01 fix is recorded append-only as ADR-025 (Accepted, 164 lines). The record supersedes ADR-024
decision 13 in prose for non-https URLs, updates ADR-024 decision 15's gate count from 18 to 19, and leaves
ADR-024 byte-unchanged. The adoption guide now says `DEFECTDOJO_URL` must be https and that since `v1.1.1`
any other scheme fails the import and cleanup jobs before any token is sent. The adoption-guide gate
requires that statement. This closes the last 27-VERIFICATION `missing:` item for CR-01.

## Commits

| Repo | SHA | Message |
|------|-----|---------|
| outer | 3751543 | docs(27-14): ADR-025 https-only DefectDojo import; guide and gate (CR-01) (exactly the four files) |

## Sources of the values ADR-025 cites

All values were copied from 27-11/27-12/27-13 SUMMARYs and `evidence/27-12-*`, `evidence/27-13-post-merge.txt`:
- PR #22, merge `917352c00987023fa5ff1e6cdabc16987eb114dd`, parents `0f7e4e1…` / `ba3683a…`
- Proof runs 36186258881 (attempt 2, job 108243485918) and 36188604648 (job 108248236695); `PROOF PASS - 88 assertions`
- v1.1.1 tag object `c1565b35e88de4e70e61d79292943c15b3fe67f6` -> `917352c…`; v1 moved from `0f7e4e1…` to `917352c…`
- SCHEME: 8 RED failures and `PASS - 19 checks, 0 failures` (27-11); `CHECK_COUNT = 19` on origin/main (27-12)

I checked two claims directly against `git show origin/main:.github/workflows/security.yml` in
repos/security-platform, because they are not in any SUMMARY:
- `security.yml` cites ADR-025 in comments at L1425 and L1795, which the provenance paragraph relies on.
- `-L` occurs 0 times, so both curl `cmd` lists (L1499, L1758) have no redirect following. This backs
  NOT-verified item 2.

## Verification

- Pre-change needle count in section 12: `sed -n '/^## 12\. Enable DefectDojo Import/,/^## 13\. /p' docs/adoption-guide.md | grep -c 'must be https://'` -> `0`
- Gate baseline before change: `check-adoption-guide: PASSED 16 / FAILED 0` (DEFECTDOJO-SECTION: 10 required strings)
- Gate after change (`bash scripts/check-adoption-guide.sh`, rc=0):
  ```
  PASS: DEFECTDOJO-SECTION: section at lines 599-819 carries all 11 required strings
  PASS: MARKDOWNLINT: markdownlint-cli2 reports zero violations on docs/adoption-guide.md
  check-adoption-guide: PASSED 16 / FAILED 0
  ```
- Negative self-test (scratch copy with the phrase removed via `sed ... > <scratchpad>/guide-neg.md`, rc=1):
  ```
  FAIL: DEFECTDOJO-SECTION: section at line 599 is missing required string(s): ['must be https://']
  check-adoption-guide: PASSED 14 / FAILED 2
  ```
  The second failure is MARKDOWNLINT on the scratch copy, which is outside the repo. That failure is not
  about this needle.
- Task 1 `<verify>` -> T1_OK. ADR-024 `git diff --quiet HEAD` passed, and no ADR file other than adr025 and README changed.
- Task 2 `<verify>` -> T2_OK.
- `@v1.1.1` appears 0 times in section 12. `v1.1.1` appears in prose only.
- `markdownlint-cli2` on ADR-025 -> `Summary: 0 error(s)`.

## Deviations from Plan

**1. [Process] Plain `git commit` instead of `gsd-sdk query commit`.** The orchestrator told me to use
plain `git commit` with trailers. It was still one commit with exactly the four files, as the plan requires.

**2. [Wording] Guide prose uses `` must be an `https://` URL ``.** The plan's suggested sentence had a
bare `https://` in the prose. I put the scheme in backticks to avoid any MD034 risk. The gate needle
`must be https://` is carried by the inline-code span `FAILED: DEFECTDOJO_URL must be https://`, as
the plan intended.

**3. [Scope addition] Extra ADR-025 NOT-verified items drawn from the SUMMARYs.** These are the
local-only `HTTPS://` case-insensitivity spot check (27-11), the still single-attempt KIND-CELERY-PING
(27-12/13 Deferred), and the release being created by the orchestrator with `--notes-file` (27-13
deviations). The plan explicitly allowed "anything the SUMMARYs record as unobserved".

## Threat Flags

None. These are documentation-only changes. T-27-29: ADR-025 has no homelab host, token or instance URL.
It uses only `defectdojo.example.com`, `127.0.0.1:9` and public GitHub URLs.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: docs/adr/adr025-defectdojo-import-https-only.md (164 lines, one `## What was NOT verified`)
- FOUND: ADR-025 row in docs/adr/README.md, directly after the ADR-024 row
- FOUND: `must be https://` in DD_REQUIRED and in guide section 12. The `adr025` link is in section 14.
- FOUND: commit 3751543
