---
phase: 15-five-parallel-scan-jobs
plan: 01
subsystem: infra
tags: [checkov, trivy, pre-commit, terraform, docker, npm, gitleaks]

# Dependency graph
requires:
  - phase: 14-workflow-foundation-and-action-pinning
    provides: security-platform repo on main, clean tree, PRs #4/#5 merged
provides:
  - "repos/security-platform feature/phase-15-five-parallel-scan-jobs branch, cut from origin/main"
  - "fixtures/ tree with real, non-zero findings for the IaC, container and SCA scan jobs (Plans 03-05)"
  - "Four ^fixtures/-anchored pre-commit hook exclusions (terraform_fmt, terraform_validate, hadolint, npm-audit)"
affects: [15-02, 15-03, 15-04, 15-05, 16, 19]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Scanner fixture pattern: intentionally vulnerable, digest-pinned, README-declared, path-anchored pre-commit exclusions instead of blanket SKIP=/--no-verify"

key-files:
  created:
    - repos/security-platform/fixtures/README.md
    - repos/security-platform/fixtures/Dockerfile
    - repos/security-platform/fixtures/main.tf
    - repos/security-platform/fixtures/package.json
    - repos/security-platform/fixtures/package-lock.json
  modified:
    - repos/security-platform/.pre-commit-config.yaml

key-decisions:
  - "D-02 corrected: used a currently-supported debian:12-slim digest pin (not an EOL distro) so Trivy reports real, non-decreasing CVE counts instead of '0 vulnerabilities / no longer supported'"
  - "D-02 corrected: Checkov findings for main.tf come from misconfigured aws_s3_bucket/aws_security_group resources, not the old provider pin (which produces zero findings on its own)"
  - "D-03 corrected: made no Gitleaks or .gitleaksignore change — no fixture contains a secret, and .gitleaksignore takes fingerprints not path globs; D-03's scoping intent is satisfied entirely by the four exclude: ^fixtures/ hook entries"
  - "versions.conf (workstation Trivy 0.69.3 / Gitleaks 8.30.0) vs CI pins (Trivy v0.74.0 / Gitleaks 8.30.1, per Plan 03) intentionally left split — out of scope for this plan, noted for a later-phase decision"

patterns-established:
  - "Fixture-scoped exclude: ^fixtures/ on exactly the hooks that would otherwise block a deliberately-vulnerable commit, leaving all other repo-wide gating (including Gitleaks) untouched"

requirements-completed: [CICD-01, SCA-04]

# Metrics
duration: 20min
completed: 2026-09-10
---

# Phase 15 Plan 01: Scan Fixtures Summary

**Cut the Phase 15 branch in `repos/security-platform` and authored a `fixtures/` tree (digest-pinned Dockerfile, misconfigured Terraform, generated npm lockfile) that gives the IaC, container and SCA scan jobs real, measured, non-zero findings for the first time.**

## Performance

- **Duration:** ~20 min (branch cut 18:11 → second commit 18:25:52 local time)
- **Started:** 2026-09-10T18:11:00-04:00 (approx, preflight fetch)
- **Completed:** 2026-09-10T18:25:52-04:00
- **Tasks:** 2
- **Files modified:** 6 (1 modified, 5 created)

## Accomplishments
- Cut `feature/phase-15-five-parallel-scan-jobs` from `origin/main` in the target repo (`repos/security-platform`), ancestor-verified
- Scoped exactly four pre-commit hooks (`terraform_fmt`, `terraform_validate`, `hadolint`, `npm-audit`) away from `fixtures/` with `exclude: ^fixtures/`, leaving Gitleaks byte-identical
- Authored `fixtures/{README.md,Dockerfile,main.tf,package.json,package-lock.json}` and proved each yields real scanner findings against CI-shaped commands
- Landed both commits through the target repo's own pre-commit hooks with zero `SKIP=` / `--no-verify` bypass

## Task Commits

Each task was committed atomically in `repos/security-platform`:

1. **Task 1: Cut the Phase 15 branch and scope four pre-commit hooks away from fixtures/** - `c7e6db1` (chore)
2. **Task 2: Author the fixtures/ tree and prove each fixture yields real findings** - `1d8a103` (test)

**Plan metadata:** committed in the outer documentation repo (this commit)

## Files Created/Modified
- `repos/security-platform/.pre-commit-config.yaml` - Added `exclude: ^fixtures/` to `terraform_fmt`, `terraform_validate`, `hadolint`, `npm-audit`; Gitleaks block untouched
- `repos/security-platform/fixtures/Dockerfile` - Digest-pinned `debian:12-slim`, measured 222 vulnerabilities (4 CRITICAL, 52 HIGH) at fixture-authoring time; local Trivy image run this session found 56 HIGH/CRITICAL
- `repos/security-platform/fixtures/main.tf` - Old `hashicorp/aws 3.74.0` pin (seeds Phase 16/SCA-03) plus an unencrypted/unversioned/unlogged `aws_s3_bucket` and an `aws_security_group` open to `0.0.0.0/0` on port 22
- `repos/security-platform/fixtures/package.json` - `lodash@4.17.15`, `minimist@1.2.0`, `"private": true`
- `repos/security-platform/fixtures/package-lock.json` - Generated via `npm install --package-lock-only --ignore-scripts --no-audit --no-fund`; no tarball fetched, no `node_modules` created
- `repos/security-platform/fixtures/README.md` - Intent declaration (`INTENTIONALLY VULNERABLE`), fixture-to-job mapping table, pre-commit exclusion list

## Decisions Made
- Applied the RESEARCH-driven corrections to D-02 and D-03 as directed by the plan's `<notes>` (see `key-decisions` above) — literal CONTEXT wording superseded by measured, falsifying evidence
- Left `versions.conf`'s workstation-vs-CI tool version split unresolved; out of scope for this plan

## Deviations from Plan

None - plan executed exactly as written, including the pre-authorized RESEARCH corrections to D-02 and D-03 that the plan itself calls out as binding.

## Measured Findings (this session)

| Check | Command | Exit | Result |
|---|---|---|---|
| Checkov | `checkov -d repos/security-platform --quiet --compact --output cli,json,sarif ...` | 1 | 10 failed terraform checks + 2 failed dockerfile checks = 12 total |
| Trivy fs (filtered) | `trivy fs repos/security-platform --scanners vuln --severity HIGH,CRITICAL --exit-code 1` | 1 | 5 vulnerabilities on `fixtures/package-lock.json` |
| Trivy fs (unfiltered) | `trivy fs repos/security-platform --scanners vuln` | 0 | 9 vulnerabilities total on `fixtures/package-lock.json` |
| Docker build | `docker build -f fixtures/Dockerfile ...` | 0 | Image built, debian 12.15 detected |
| Trivy image (filtered) | `trivy image scan-fixture:local --scanners vuln --severity HIGH,CRITICAL --exit-code 1` | 1 | 56 HIGH/CRITICAL vulnerabilities, no EOL warning |
| pre-commit run --all-files | (inside `repos/security-platform`) | 0 | markdownlint passed on fixtures/README.md; the four excluded hooks correctly skipped (no files to check) |

CVE/finding counts for a live, non-EOL distro and actively-scanned npm packages are expected to drift upward over time — this is by design (see fixtures/README.md).

## Issues Encountered
- `docker build` initially exceeded the foreground Bash timeout (120s/180s) pulling the base layer; re-run with `run_in_background` completed cleanly at exit 0 with no functional issue.

## User Setup Required

None - no external service configuration required. Nothing was pushed; both commits exist only on the local `feature/phase-15-five-parallel-scan-jobs` branch in `repos/security-platform`.

## Next Phase Readiness
- Plans 03-05 (IaC, container, SCA jobs) now have a real, non-empty CI checkout target satisfying Success Criteria #2 (no skipped/stubbed step)
- Phase 16 can build on the `hashicorp/aws 3.74.0` provider pin already seeded in `fixtures/main.tf` for SCA-03 provider-pinning checks
- Phase 19 inherits the same fixtures without needing to rediscover the fixture strategy
- No blockers. The branch is local-only; a later plan in Phase 15 (or the operator) will push and open the PR, per the same pattern as Phase 14.

---
*Phase: 15-five-parallel-scan-jobs*
*Completed: 2026-09-10*

## Self-Check: PASSED

All 5 fixture files, the SUMMARY.md, and both task commits (`c7e6db1`, `1d8a103`) were verified to exist.
