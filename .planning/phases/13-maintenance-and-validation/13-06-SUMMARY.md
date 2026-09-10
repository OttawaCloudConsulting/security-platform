---
phase: 13-maintenance-and-validation
plan: 06
subsystem: workstation/documentation
tags: [documentation, bash, installer, update, doctor, gitignore]

requires:
  - phase: 13-maintenance-and-validation plan 03
    provides: "update-failures.log writer (log_update_failure), D-07 plain-text log at $REPO_ROOT"
  - phase: 13-maintenance-and-validation plan 04
    provides: "update_one_tool()/update_all_tools(), the update dispatcher branch, fallback status semantics"
  - phase: 13-maintenance-and-validation plan 05
    provides: "tool_health()/run_doctor(), the doctor dispatcher branch, the check/doctor exit-code contract"
provides:
  - "README.md Maintenance section documenting update/doctor for a developer who never reads setup.sh"
  - "ARCHITECTURE.md Version Resolution / File Structure / Design Decisions sections matching the shipped gh_api_get, resolve_latest_in_major, and tests/ layout"
  - "repos/security-platform/.gitignore entry for update-failures.log"
affects: ["13-07 (final validation pass covering MAINT-02/03)"]

tech-stack:
  added: []
  patterns:
    - "Documentation-only plan: no setup.sh changes, verified by re-running the existing 143-assertion suite unchanged after both tasks"

key-files:
  created: []
  modified:
    - repos/security-platform/workstation/README.md
    - repos/security-platform/workstation/ARCHITECTURE.md
    - repos/security-platform/.gitignore

key-decisions:
  - "Version Pinning Strategy table's update-method cell (not named in this plan's <action> list but flagged by its own read_first) updated to list `bash setup.sh update` as the preferred method — the plan's own constraint requires docs to describe shipped behaviour, and leaving that cell as 'delete and re-run install' would contradict the new README Maintenance section it sits beside."
  - "update-failures.log's .gitignore entry uses a `# setup.sh update` header comment rather than any header containing the literal filename, so the acceptance criterion (`grep -c 'update-failures.log' .gitignore` returns exactly 1) holds."
  - "Marked MAINT-01 complete via requirements.mark-complete. MAINT-02 and MAINT-03 are NOT marked — checked 13-07-PLAN.md's frontmatter (`requirements: [MAINT-02, MAINT-03]`) and confirmed both are still claimed there, so per the plan-04/05-established convention only the last plan touching a requirement marks it complete. MAINT-01 does not appear in 13-07's frontmatter, so this plan is its last touch."

requirements-completed: [MAINT-01]

duration: ~30min
completed: 2026-09-09
---

# Phase 13 Plan 06: Document `update`/`doctor` and Ignore the Failure Log Summary

Closed the documentation gap left by plans 03-05: README.md's Quick Start and a new Maintenance
section now teach a developer who never reads `setup.sh` how `update` and `doctor` work — including
the two-attempt fallback, all four result statuses, the failure log, the exit-code contract, and
`GITHUB_TOKEN` — and ARCHITECTURE.md's Version Resolution, File Structure, and Design Decisions
sections now describe `gh_api_get`, `resolve_latest_in_major`, the `tests/` directory, and why
`doctor` is a distinct subcommand. `update-failures.log` is now git-ignored in the security-platform
checkout so it can never appear as an untracked file there.

## Performance

- **Duration:** ~30 min
- **Started:** 2026-09-09
- **Completed:** 2026-09-09
- **Tasks:** 2 completed, both `type="auto"` (documentation, no TDD)
- **Files modified:** 3 (all in `repos/security-platform`)

## Accomplishments

- **README.md Quick Start:** added `bash setup.sh update`, `bash setup.sh update trivy`, and
  `bash setup.sh doctor` to the existing "Or run individual steps" block, plus a note on the
  order-sensitivity of `update <tool>`.
- **README.md Maintenance section** (new, placed after Version Management): covers `check`'s
  version-currency question and its `~/.local/bin` search rationale; `update`'s two-attempt
  sequence, the downgrade guard, and the never-rewrites-`versions.conf` rule; all four result
  statuses (`ok`, `installed`, `fallback`, `FAILED`) in a table; the manual remediation step for a
  `fallback`; `update-failures.log`'s location, content (timestamp, tool, pinned, fallback,
  installed — no credentials), and the recommended `.gitignore` line for other repos; a
  check/update/doctor exit-code table; `doctor`'s four-status vocabulary (`OK`, `NOT_ON_PATH`,
  `BROKEN`, `UNPARSEABLE`) and its deliberate real-`PATH` behaviour; and `GITHUB_TOKEN`/`GH_TOKEN`
  guidance naming the three call sites (`versions.conf` generation, hook version resolution, update
  fallback) and the 60 -> 5000 req/hr figure.
- **README.md Version Management / Contents:** added `bash setup.sh update` as the third,
  preferred way to update `versions.conf`-pinned tools, cross-referenced to Maintenance; added a
  `tests/` row to the Contents table.
- **ARCHITECTURE.md Version Resolution:** extended with `gh_api_get`'s header handling and lazy
  token resolution, the whitespace-tolerant JSON parsing rationale (compact vs. spaced GitHub
  responses), and `resolve_latest_in_major`'s strict `^major.N.N$` filter framed as a security
  control (prevents an arbitrary tag string reaching a download URL or `pipx install` spec) that
  fires only on the update fallback path.
- **ARCHITECTURE.md new `### check / update / doctor Split` subsection** under Design Decisions:
  three recorded decisions — `doctor` as a distinct subcommand (because `get_installed_version`'s
  `|| true` cannot report exit status, plus the `npm doctor`/`brew doctor` convention parallel),
  update success determined by re-probing rather than trusting the installer's exit code (`pipx
  install` on an already-present package exits 0 and does nothing), and a successful fallback never
  rewriting `versions.conf` (keeps the pin manifest user-owned).
- **ARCHITECTURE.md File Structure:** added the `tests/` subtree (`run-tests.sh`, `test_*.sh`,
  `fixtures/` with both compact and spaced JSON fixture files), noting the runner's glob-sourcing.
- **ARCHITECTURE.md Version Pinning Strategy:** updated the `versions.conf` update-method cell to
  list `bash setup.sh update` first (see Deviations).
- **`.gitignore`:** appended a `# setup.sh update` header and `update-failures.log`, placed after
  the existing `# pre-commit` section.

## Task Commits

Both in `repos/security-platform`:

1. **Task 1: README.md Maintenance section**
   - `8649ddd` (docs) — Quick Start additions, Maintenance section, Version Management
     cross-reference, Contents `tests/` row

2. **Task 2: ARCHITECTURE.md + .gitignore**
   - `13c1c3c` (docs) — Version Resolution extension, new Design Decisions subsection, File
     Structure `tests/` entry, Version Pinning Strategy update-method cell, `.gitignore` entry

**Plan metadata:** committed separately in the documentation repo (this SUMMARY.md, STATE.md,
ROADMAP.md, REQUIREMENTS.md).

## Files Created/Modified

- `repos/security-platform/workstation/README.md` — Quick Start, new Maintenance section, Version
  Management cross-reference, Contents table row
- `repos/security-platform/workstation/ARCHITECTURE.md` — Version Resolution extension, new `###
  check / update / doctor Split` subsection, File Structure `tests/` entry, Version Pinning
  Strategy update-method cell
- `repos/security-platform/.gitignore` — `update-failures.log` ignore rule

## Decisions Made

See `key-decisions` in the frontmatter above (Version Pinning Strategy cell update, `.gitignore`
header wording to keep the grep-count criterion exact, and the MAINT-01 requirement-marking call).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Version Pinning Strategy table left inconsistent
with the new README Maintenance section**
- **Found during:** Task 2, reading ARCHITECTURE.md's Version Pinning Strategy section (named in
  this task's own `read_first` list but not explicitly listed in the `<action>` bullets)
- **Issue:** The table's `versions.conf` row said the only update methods were "delete and re-run
  install" or "edit manually" — the same gap the plan's own objective describes for the README,
  now left standing in ARCHITECTURE.md after Task 1 fixed the README's equivalent list.
- **Fix:** Added `bash setup.sh update` as the first (preferred) method in that cell, without
  restructuring the table or the surrounding section.
- **Files modified:** `repos/security-platform/workstation/ARCHITECTURE.md`
- **Verification:** Diff confined to one table cell; `bash workstation/tests/run-tests.sh` still
  143 passed, 0 failed (no source touched).
- **Committed in:** `13c1c3c`

---

**Total deviations:** 1 auto-fixed (documentation consistency, no source-code changes). No scope
creep — the fix is required for the plan's own constraint that "Documentation must describe what
actually shipped" to hold across both documents consistently.

## Known Stubs

None. This plan modifies only prose and one ignore rule; no code paths, no data flow.

## Threat Flags

None — this plan introduces no new network endpoints, auth paths, file-access patterns, or schema
changes. The threat register's `T-13-06`, `T-13-03`, `T-13-22`, and `T-13-08` entries are addressed
directly: the `.gitignore` rule is verified with `git check-ignore`, `GITHUB_TOKEN` guidance
specifies environment/`gh auth login` only and states the header-only, never-logged behavior, README
command descriptions were compared against the shipped `usage()` heredoc before writing, and every
documented invocation uses `bash setup.sh ...` (`grep -c '\./setup\.sh'` returns 0 in both files).

## User Setup Required

None. Optional: set `GITHUB_TOKEN`/`GH_TOKEN` or run `gh auth login` to raise the GitHub API limit
from 60 to 5000 requests/hour for `versions.conf` generation, hook version resolution, and `update`'s
fallback resolution — now documented in the README.

## Next Phase Readiness

- README and ARCHITECTURE.md fully reflect the `update`/`doctor` behaviour shipped in plans 03-05;
  no documentation gap remains for MAINT-01/02/03's user-facing surface.
- `update-failures.log` is git-ignored in `repos/security-platform`; verified live with
  `git check-ignore -q update-failures.log`.
- The ASCII architecture diagram (L16-65) is unchanged — verified by reading `git diff` hunk headers,
  none of which fall inside that range.
- No blockers for 13-07 (final validation pass covering MAINT-02/03).

## Self-Check: PASSED

- FOUND: repos/security-platform/workstation/README.md (modified — Quick Start, Maintenance
  section, Version Management cross-reference, Contents row)
- FOUND: repos/security-platform/workstation/ARCHITECTURE.md (modified — Version Resolution, new
  Design Decisions subsection, File Structure, Version Pinning Strategy)
- FOUND: repos/security-platform/.gitignore (modified — update-failures.log entry)
- FOUND commit 8649ddd (docs(13-06): document update and doctor subcommands in README) in
  repos/security-platform
- FOUND commit 13c1c3c (docs(13-06): document update/doctor internals in ARCHITECTURE, ignore
  failure log) in repos/security-platform

---
*Phase: 13-maintenance-and-validation*
*Completed: 2026-09-09*
