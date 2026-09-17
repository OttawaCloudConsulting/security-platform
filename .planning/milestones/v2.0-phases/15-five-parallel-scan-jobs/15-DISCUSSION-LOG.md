# Phase 15: Five Parallel Scan Jobs - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-10
**Phase:** 15-Five Parallel Scan Jobs
**Areas discussed:** Fixture strategy, Report-only conversion, SCA tool choice, Container job trigger

---

## Fixture strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated fixtures/ dir | New top-level fixtures/ dir, NOT gitignored, minimal real Dockerfile + package-lock.json + .tf file. Scoped .gitleaksignore / hook exclude: for that dir only. | ✓ |
| Reuse repos/security-platform tree | Un-gitignore repos/security-platform specifically, add fixtures there instead of new top-level dir. | |
| You decide | Claude picks based on codebase conventions during planning. | |

**User's choice:** Dedicated fixtures/ dir (Recommended)
**Notes:** —

| Option | Description | Selected |
|--------|-------------|----------|
| Deliberately vulnerable | Pin an old lodash/handlebars-style npm dep, old Terraform provider, Dockerfile FROM an old base image — guarantees each tool finds a real, reportable result. | ✓ |
| Minimal valid, not necessarily vulnerable | Just enough files to parse; tools may report zero findings. | |

**User's choice:** Deliberately vulnerable (Recommended)
**Notes:** —

---

## Report-only conversion

| Option | Description | Selected |
|--------|-------------|----------|
| continue-on-error: true on tool step | Keep native exit-code/fail-on behavior per tool, mark the step continue-on-error:true — job shows failed-but-continued, overall check passes. | ✓ |
| Flip tool flags to non-blocking natively | soft_fail:true (Checkov), drop --fail-on/--error/exit-code flags — job exits 0 cleanly. | |
| You decide | Claude picks during planning. | |

**User's choice:** continue-on-error: true on tool step (Recommended)
**Notes:** —

---

## SCA tool choice

| Option | Description | Selected |
|--------|-------------|----------|
| Trivy only | trivy fs . scans filesystem across ecosystems, single tool/output. Grype reserved for container scanning if ever needed. | ✓ |
| Grype only | grype dir:. matches the reference workflow's existing SCA job pattern verbatim. | |
| Both, as separate steps in one job | Run trivy fs and grype dir: sequentially — belt-and-suspenders per SCA-04 wording. | |

**User's choice:** Trivy only (Recommended)
**Notes:** —

---

## Container job trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — fixture Dockerfile in fixtures/ | fixtures/Dockerfile FROM a deliberately old base image with known CVEs. Container job always builds+scans it — no conditional skip logic. | ✓ |
| Keep conditional Dockerfile check | Job checks repo root, skips cleanly if absent — matches reference pattern. | |

**User's choice:** Yes — fixture Dockerfile in fixtures/ (Recommended)
**Notes:** —

---

## Claude's Discretion

- Exact fixture file contents (specific old npm package/version, Terraform provider/version, Docker base image tag) — pick something clearly vulnerable and well-documented.
- Exact `.gitleaksignore` / pre-commit `exclude:` regex syntax for scoping the fixtures exemption.
- Job/step naming and ordering within `security.yml` beyond what's already implied by the reference workflow.

## Deferred Ideas

- Per-ecosystem SCA coverage (npm-audit, pip-audit, Terraform pin checks) — Phase 16 (SCA-01/02/03).
- SARIF upload to GitHub Security tab and JSON artifact retention with explicit retention periods — Phase 17 (CICD-02/03).
- Configurable gate mode (block vs report-only via flag/input) and branch protection guidance — Phase 18 (CICD-06/CICD-04).
- Grype as a second SCA tool alongside Trivy — deferred, not ruled out.
