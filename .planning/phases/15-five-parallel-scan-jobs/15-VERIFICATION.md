---
phase: 15-five-parallel-scan-jobs
verified: 2026-09-11T01:30:00Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
---

# Phase 15: Five Parallel Scan Jobs Verification Report

**Phase Goal:** Replace the Phase 14 placeholder job with five real, parallel, report-only scan jobs (SAST/Semgrep, IaC/Checkov, SCA/Trivy-fs, Container/Trivy-image, Secrets/Gitleaks), backed by real vulnerable fixtures, proven locally via smoke script and on live CI via a merged PR.
**Verified:** 2026-09-11T01:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `security.yml` defines exactly 5 independent jobs, no `needs:` | ✓ VERIFIED | `repos/security-platform/.github/workflows/security.yml` has 5 job blocks (sast, iac, sca, container, secrets); `grep -n "needs:"` returns no matches |
| 2 | Each job runs a real scanner with `continue-on-error: true` (report-only) | ✓ VERIFIED | Every scan step has `continue-on-error: true`; steps use pinned Semgrep 1.177.0, Checkov 3.3.17, Trivy v0.74.0 (fs + image), Gitleaks 8.30.1 |
| 3 | Actions are SHA-pinned (ADR-004) | ✓ VERIFIED | All `uses:` lines reference full commit SHAs with version comments (e.g. `actions/checkout@3d3c42e5...` `# v7.0.1`) |
| 4 | Real vulnerable fixtures exist for IaC/container/SCA scanners | ✓ VERIFIED | `repos/security-platform/fixtures/{main.tf,Dockerfile,package.json,package-lock.json,README.md}` present; `main.tf` has misconfigured `aws_s3_bucket`/`aws_security_group`; Dockerfile pins `debian:12-slim` by digest (documented 222 vulns) |
| 5 | Local smoke script wraps all 5 scanners, fails if any produces zero findings | ✓ VERIFIED | `scripts/smoke-scans.sh` exists (non-executable, `-rw-r--r--`), contains `run_scan()` helper that treats exit 0 (no findings) as FAIL and exit 1 (findings) as PASS, for all 5 tools |
| 6 | Live CI run on PR shows 5 concurrent `security / *` checks | ✓ VERIFIED | `gh pr view 6` statusCheckRollup shows 5 `security / *` check runs (SAST, IaC, SCA, Container, Secrets), all `startedAt: 2026-09-11T00:31:27Z` (same second — true parallelism, no sequential `needs` chain) |
| 7 | Live CI checks produce real non-empty findings, not empty/stub output | ✓ VERIFIED | Job logs (`gh run view 34546843396 --log`) show all 5 scanners wrote substantial report files: semgrep-results.json 12.5KB/sarif 2.1MB, checkov-results.json 18.3KB/sarif 13.3KB, trivy-fs.json 24.2KB/sarif 15.5KB, trivy-image.json 522KB/sarif 102KB, gitleaks-results.json 10.7KB/sarif 59.6KB |
| 8 | PR merged to `main`; fixtures/workflow/smoke script land on target repo main | ✓ VERIFIED | `gh pr view 6` shows `state: MERGED`, `mergedAt: 2026-09-11T00:50:35Z`; local `repos/security-platform` HEAD = `e8e1009` (merge commit) which matches `origin/main` HEAD exactly (`git log origin/main` shows same commit) |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/security.yml` | 5 parallel report-only jobs | ✓ VERIFIED | Present, 5 jobs, no `needs:`, `continue-on-error` per scan step |
| `fixtures/{main.tf,Dockerfile,package.json,package-lock.json,README.md}` | Real vulnerable scan targets | ✓ VERIFIED | All present with content designed to trigger real findings |
| `.pre-commit-config.yaml` exclude entries | 4x `exclude: ^fixtures/` on terraform_fmt/terraform_validate/hadolint/npm-audit | ✓ VERIFIED | `grep -n exclude` shows exactly 4 matches, Gitleaks untouched |
| `scripts/smoke-scans.sh` | Non-executable wrapper script for local 5-scanner smoke test | ✓ VERIFIED | Present, `-rw-r--r--` (no exec bit), `set -euo pipefail`, per-scanner PASS/FAIL logic |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| PR #6 branch | `security-platform` main | `gh pr merge` | WIRED | Merge commit `e8e1009` on `main`, confirmed via `git log origin/main` |
| `pr-security.yml` caller | `security.yml` reusable workflow | `uses: ./.github/workflows/security.yml` | WIRED | Confirmed present; live check-run names (`security / <job>`) match reusable-workflow naming convention from Phase 14 |
| Fixtures | Scanner steps | `directory: .` / `docker build -f fixtures/Dockerfile` | WIRED | Live run logs confirm each scanner ran against repo content including fixtures and produced non-trivial output sizes |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 5 jobs, no needs | `grep -c "^  [a-z_]*:$" security.yml` / `grep needs:` | 5 jobs, 0 needs matches | ✓ PASS |
| Live PR check-runs | `gh pr view 6 --json statusCheckRollup` | 5 `security / *` runs, all SUCCESS, started within 1s of each other | ✓ PASS |
| Live run produced real report files | `gh run view <id> --log` | All 5 scanners wrote non-empty JSON+SARIF (10KB–2MB range) | ✓ PASS |
| Repo main matches merged PR | `git log origin/main` vs local checkout HEAD | Both at `e8e1009` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CICD-01 | 15-01..05 | 5 parallel scan jobs on PRs | ✓ SATISFIED | 5-job workflow live and merged, confirmed via check-run timestamps |
| SCA-04 | 15-01, 15-02 | Generic Trivy filesystem SCA sweep (no per-ecosystem config) | ✓ SATISFIED | `sca` job runs `trivy fs . --scanners vuln` against whole repo, no per-ecosystem plugin, produced real findings live |

### Anti-Patterns Found

None found in the workflow, fixtures, or smoke script. No TBD/FIXME/XXX markers, no empty-return stubs, no hardcoded pass conditions. `continue-on-error: true` is intentional per-design (report-only phase, documented in workflow header comment and ROADMAP), not a masking anti-pattern.

### Human Verification Required

None. All must-haves resolved via static inspection, local file evidence, and live GitHub API/log evidence (already gathered by this verifier — no further human action needed).

### Gaps Summary

No gaps found. All 8 observable truths verified against actual codebase and live CI state — not SUMMARY.md claims alone. Live PR #6 evidence (5 concurrent check-runs, all SUCCESS, real non-empty scan output files, merge commit `e8e1009` confirmed on `origin/main`) independently corroborates the SUMMARY narrative rather than merely repeating it.

---

*Verified: 2026-09-11T01:30:00Z*
*Verifier: Claude (gsd-verifier)*
