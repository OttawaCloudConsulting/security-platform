---
phase: 10-cross-platform-install-script
plan: 02
subsystem: infra
tags: [bash, trivy, syft, grype, gitleaks, hadolint, binary-download, checksum]

# Dependency graph
requires:
  - phase: 10-01
    provides: install.sh framework with stubs, versions.conf, helper functions
provides:
  - Complete install.sh with all 6 tool installers (pre-commit, Trivy, Syft, Grype, Gitleaks, hadolint)
  - Checksum-verified binary downloads for Gitleaks and hadolint
  - Updated ROADMAP reflecting 6-tool scope
affects: [phase-12-repo-setup-script, phase-13-maintenance-and-validation]

# Tech tracking
tech-stack:
  added: []
  patterns: [official-install-script-pattern, direct-binary-download-with-checksum, url-template-substitution]

key-files:
  created: []
  modified:
    - dist/install.sh
    - .planning/ROADMAP.md

key-decisions:
  - "Trivy/Syft/Grype use official curl-pipe install scripts with -b flag for install dir"
  - "Gitleaks uses tarball download with checksums.txt SHA-256 verification"
  - "hadolint uses direct binary download with per-file .sha256 verification"
  - "Verbose mode conditionally suppresses or shows official script output"

patterns-established:
  - "Official install script pattern: curl | sh -s -- -b $INSTALL_DIR v$VERSION with verbose toggle"
  - "Direct download pattern: tmpdir, download, checksum verify, extract/move, cleanup"
  - "Graceful failure: each installer catches errors, records FAILED, increments FAIL_COUNT, continues"

requirements-completed: [INST-01, INST-02, INST-06, INST-07]

# Metrics
duration: 2min
completed: 2026-03-18
---

# Phase 10 Plan 02: Binary Tool Installers Summary

**5 binary tool installers (Trivy, Syft, Grype via official scripts; Gitleaks, hadolint via checksum-verified binary download) replacing stubs in install.sh**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-18T00:40:49Z
- **Completed:** 2026-03-18T00:42:49Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Replaced all 5 stub functions with full idempotent installers
- Trivy/Syft/Grype use official install scripts with checksum verification built in
- Gitleaks and hadolint use direct download with SHA-256 checksum verification
- ROADMAP Phase 10 success criteria updated from 8 tools to 6 (Semgrep/Checkov deferred to CI)
- install.sh is now 494 lines, complete and functional for all 6 security tools

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement binary tool installers in install.sh** - `5ae75dd` (feat)
2. **Task 2: Update ROADMAP success criteria for 6 tools** - `1ae5522` (docs)

## Files Created/Modified
- `dist/install.sh` - Complete installer with all 6 tool functions (494 lines)
- `.planning/ROADMAP.md` - Phase 10 success criteria updated to reflect 6-tool scope

## Decisions Made
- Used conditional verbose/quiet output for official install scripts (if/else around redirect)
- Gitleaks checksum: grep specific filename from checksums.txt to extract expected hash
- hadolint checksum: cut first field from .sha256 file (handles both hash-only and hash+filename formats)
- All installers wrap download/verify in if-blocks to prevent set -e from aborting on single tool failure

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- dist/install.sh is complete for Phase 10 scope (6 tools)
- Ready for Phase 11 (file-pattern hook configuration) and Phase 12 (repo setup script)
- Phase 13 (maintenance) will add --check/--update/--doctor commands to this script

---
*Phase: 10-cross-platform-install-script*
*Completed: 2026-03-18*
