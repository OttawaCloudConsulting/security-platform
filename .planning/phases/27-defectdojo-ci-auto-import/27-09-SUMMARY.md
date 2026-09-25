---
phase: 27-defectdojo-ci-auto-import
plan: 09
subsystem: adoption-docs
tags: [defectdojo, adoption-guide, documentation-gate, mode-b, security-platform]
requires:
  - "27-08 v1.1.0 released and v1 moved to 0f7e4e1 (every /v1/ fetch URL and @v1 reference in the new section resolves to the released files)"
  - "27-07 proof run 36156728300 and 27-08 dispatch run 36160366711 (cited as measured)"
provides:
  - "docs/adoption-guide.md section 12 'Enable DefectDojo Import' (D-11, D-17, D-18, D-22)"
  - "scripts/check-adoption-guide.sh DEFECTDOJO-SECTION check (16 checks, was 15)"
  - "27-04 carry-forward fixed: Mode B caller shows closed type + secrets:, 'one substitution point' reworded"
affects: [27-10]
tech-stack:
  added: []
  patterns:
    - "Gate locates a guide section by numbered headings only (^## <n>. ), so column-0 '## ' comment lines inside fences cannot truncate it"
    - "Token minting example keeps password and token off argv: jq --rawfile | curl --data @- | jq -r .token | gh secret set (stdin)"
key-files:
  created: []
  modified:
    - docs/adoption-guide.md
    - scripts/check-adoption-guide.sh
key-decisions:
  - "New section inserted as 12; Troubleshooting renumbered 13 and Cross-References 14 (no in-guide numeric references to either existed)"
  - "D-04 'one substitution point' reworded to 'the one per-repo setting that changes gating'; DEFECTDOJO_* settings are documented as a side channel that changes no check"
  - "Section 6 First Run now states the two extra skipped, non-required check runs (import and cleanup) that appear from v1.1.0, measured in 27-07-pr-checks.txt"
  - "The Mode B caller in section 12 omits the column-0 '## Workflow-level FLOOR' comment so the '^## ' heading count rises by exactly one"
requirements-completed: []  # DDOJO-02 partial (9 of 10 plans); marked complete by 27-10
duration: ~20min
completed: 2026-09-25
---

# Phase 27 Plan 09: Enable DefectDojo Import section in the adoption guide, and its gate

The adoption guide now has a section 12, "Enable DefectDojo Import". From it alone, a consumer can switch on the opt-in import released in `v1.1.0` and understand its scope. A new DEFECTDOJO-SECTION check in `scripts/check-adoption-guide.sh` fails the gate if the section, or any of its security-critical strings, disappears.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write the "Enable DefectDojo Import" section | `72f47de` | docs/adoption-guide.md |
| 2 | Add the DEFECTDOJO-SECTION check to the adoption gate | `72f47de` (committed together with Task 1, as the plan specifies) | scripts/check-adoption-guide.sh |

## What the section covers

It follows the plan's order, 1-10:
1. What the import does: Product/Product Type defaults, `ci/<branch>`, one Test per report file, reimport in place, the engagement deleted on close, and it can never block a merge.
2. Reachability from the runner, deferred to Phase 29.
3. A dedicated user with `is_staff=true`, `is_superuser=false`. Staff is an instance-wide bypass, so the section recommends a dedicated user or instance. It includes a token-mint pipeline that keeps both the password and the token off argv.
4. The `gh secret set` / `gh variable set` settings, each with a "never executed against any pilot" note.
5. The full updated Mode B caller (`types: [opened, synchronize, reopened, closed]`, a `secrets:` block, `security.yml@v1`), and the statement that moving `@v1` alone does not enable Mode B.
6. `scheduled-security.yml`: the Mode A fetch pinned at `/v1/`, 06:00 America/Toronto, and the 60-day auto-disable.
7. TLS: verified by default, `DEFECTDOJO_CA_CERT`, and `DEFECTDOJO_INSECURE` with its per-run warning; INSECURE wins when both are set.
8. The verbatim dd-gate SKIP lines, plus `SKIP: <file> not in artifacts — <reason>`.
9. Caveats: Product Type drift gives HTTP 400, `npm-audit-N` titles drift, tflint imports as SARIF.
10. Measured: runs `36156728300` and `36160366711`, 85 assertions, and ADR-024.

Carry-forward edits outside section 12:
- Preamble "Proven in" parenthetical: now excludes the section 12 commands.
- Section 1: "nothing else is supplied unless you opt in ... one secret".
- Section 3 and section 11: "one substitution point" reworded.
- Section 5: Mode B fence gains the `types:` line and the `secrets:` block, plus a note that pre-v1.1.0 callers keep working without import.
- Section 6: the two extra skipped check runs.
- Section 14: an ADR-024 bullet linking `adr/adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md` (the filename 27-10-PLAN.md names).

## Verification (observed)

- `bash scripts/check-adoption-guide.sh`: exit 0, `PASS: DEFECTDOJO-SECTION: section at lines 599-813 carries all 10 required strings`, `PASSED 16 / FAILED 0`.
- `grep -c '^## ' docs/adoption-guide.md`: 23 before, 24 after. `## 12. Enable DefectDojo Import`, `## 13. Troubleshooting` and `## 14. Cross-References and Validation Checklist` are all present.
- `grep -c 'security / DefectDojo'` = 0, and `grep -c 'security.yml@v1.1'` = 0.
- Hostnames: the only one is `defectdojo.example.com`. No IP address and no token appear.
- `shellcheck scripts/check-adoption-guide.sh` exit 0. The script mode is `-rw-r--r--` (no execute bit).
- `git diff --check` on both files: clean.

## TDD Gate Compliance

The plan requires Tasks 1 and 2 in a single commit, so there are no separate `test(...)`/`feat(...)` commits. RED and GREEN were run and observed against scratch copies of the guide, passed as the script's positional argument. The plan text says "GUIDE_PATH env override", but the script reads `GUIDE_PATH` from `$1` only. Both copies were deleted afterwards.

| Case | Before the check (RED) | After the check (GREEN) |
|------|------------------------|-------------------------|
| heading renamed to `## 12. Something Else` | `PASSED 15 / FAILED 0`, rc=0 (not caught) | `FAIL: DEFECTDOJO-SECTION: no '## <n>. Enable DefectDojo Import' heading in .../no-heading.md`, `PASSED 15 / FAILED 1`, rc=1 |
| `is_staff` removed from the section | `PASSED 15 / FAILED 0`, rc=0 (not caught) | `FAIL: DEFECTDOJO-SECTION: section at line 599 is missing required string(s): ['is_staff']`, `PASSED 15 / FAILED 1`, rc=1 |
| real guide | n/a | `PASS: DEFECTDOJO-SECTION`, `PASSED 16 / FAILED 0`, rc=0 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The section locator uses numbered headings, not "the next `## ` heading"**
- **Found during:** Task 2
- **Issue:** The guide has column-0 `## ` comment lines inside fences, for example `## Workflow-level FLOOR` and `## Expected:`. A bare `^## ` end-marker could truncate a section at such a line.
- **Fix:** The start is located with `^## \d+\. Enable DefectDojo Import` and the end with the next `^## \d+\. `.
- **Commit:** `72f47de`

**2. [Rule 2 - Correctness] Stale claims elsewhere in the guide were corrected**
- **Found during:** Task 1
- **Issue:** Section 1 said nothing but `GITHUB_TOKEN` is ever supplied. The preamble said every command had been executed. Section 6 said the run shows five check runs. All three are no longer accurate once v1.1.0 and section 12 exist. The last one was measured: `27-07-pr-checks.txt` shows two skipped DefectDojo check runs.
- **Fix:** Added a one-clause qualification in each place.
- **Commit:** `72f47de`

**3. [Plan wording] GUIDE_PATH override is positional**
- The behavior cases ran as `bash scripts/check-adoption-guide.sh <copy>`, because the script does not read `GUIDE_PATH` from the environment.

## Known Stubs

None. The ADR-024 link target `docs/adr/adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md` does not exist yet. Plan 27-10 creates it with that exact filename. Until then the link is dangling, and no gate checks relative links.

## Self-Check: PASSED

- FOUND: docs/adoption-guide.md (section 12 at line 599)
- FOUND: scripts/check-adoption-guide.sh (DEFECTDOJO-SECTION)
- FOUND: commit 72f47de
