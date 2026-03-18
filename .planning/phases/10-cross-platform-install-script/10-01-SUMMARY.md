---
phase: 10-cross-platform-install-script
plan: 01
subsystem: infra
tags: [bash, shell, pipx, pre-commit, installer, cross-platform]

# Dependency graph
requires: []
provides:
  - "dist/versions.conf -- version manifest with pinned versions and URL templates for all 6 security tools"
  - "dist/install.sh -- install script framework with pipx bootstrap, pre-commit installer, helper functions, and stub functions for binary tools"
affects: [10-02, 11-hook-configuration, 12-setup-script, 13-maintenance-commands]

# Tech tracking
tech-stack:
  added: [pipx, pre-commit]
  patterns: [bash-3.2-compatible, env-style-version-manifest, per-tool-arch-normalization]

key-files:
  created:
    - dist/versions.conf
    - dist/install.sh
  modified: []

key-decisions:
  - "pipx bootstrap uses pip install --user with PEP 668 fallback (--break-system-packages)"
  - "Per-tool OS/arch normalization functions instead of generic mapping table"
  - "Summary table uses pipe-delimited RESULTS variable parsed with printf %b and IFS read"

patterns-established:
  - "Version manifest: .env-style KEY=VALUE sourced by install.sh, URL templates with {VERSION}/{OS}/{ARCH} placeholders"
  - "Verbose/quiet output: VERBOSE=false default, log() checks flag, err() always to stderr"
  - "Idempotent install: is_installed() checks command existence and version match before installing"
  - "Cross-platform checksum: verify_sha256() tries sha256sum then shasum -a 256"

requirements-completed: [INST-01, INST-02, INST-03, INST-04, INST-05]

# Metrics
duration: 2min
completed: 2026-03-18
---

# Phase 10 Plan 01: Version Manifest and Install Script Framework Summary

**Version manifest with 6 pinned tool versions and install.sh framework with pipx bootstrap, pre-commit installer, and bash 3.2 compatible helpers**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-18T00:36:18Z
- **Completed:** 2026-03-18T00:38:34Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created dist/versions.conf with pinned versions for all 6 security tools and URL templates for direct-download tools
- Created dist/install.sh (315 lines) with full framework: argument parsing, logging, pipx bootstrap with PEP 668 fallback, pre-commit installer, OS/arch detection, cross-platform checksum verification, PATH verification, and summary table
- All code bash 3.2 compatible -- no associative arrays, no mapfile, no |&, no ${var,,}
- Script passes bash -n syntax check and shellcheck with no errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Create version manifest (dist/versions.conf)** - `439e863` (feat)
2. **Task 2: Create install.sh framework with pipx bootstrap and pre-commit installer** - `7bdfebc` (feat)

## Files Created/Modified
- `dist/versions.conf` - Version manifest with 6 tool versions, 3 install script URLs, and 4 URL templates
- `dist/install.sh` - Install script framework (315 lines) with pre-commit installer and binary tool stubs

## Decisions Made
- pipx bootstrap uses `python3 -m pip install --user pipx` with automatic fallback to `--break-system-packages` for PEP 668 systems
- Per-tool OS/arch normalization as separate functions (get_gitleaks_os, get_gitleaks_arch, get_hadolint_os, get_hadolint_arch) rather than a lookup table, for bash 3.2 compatibility
- Summary table uses pipe-delimited string variable with printf/IFS parsing instead of arrays
- gitleaks version detection uses `gitleaks version` (no --) as special case in is_installed()

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- dist/versions.conf and dist/install.sh framework are ready for Plan 02 to fill in the 5 binary tool installer functions (install_trivy, install_syft, install_grype, install_gitleaks, install_hadolint)
- All helper functions (detect_os, detect_arch, verify_sha256, per-tool normalization) are defined and ready for use

---
*Phase: 10-cross-platform-install-script*
*Completed: 2026-03-18*
