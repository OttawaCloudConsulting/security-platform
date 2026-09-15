# Milestone 2: CI/CD Security Gate

## Goal

Security scanning runs automatically on every Pull Request. Findings are visible in the GitHub Security tab before merge. Branch protection makes the gate mandatory — failing scans block the merge. No infrastructure required beyond GitHub-hosted runners.

## Prerequisites

- M1 complete (tools validated locally; `.pre-commit-config.yaml` committed)
- GitHub repository with Actions enabled

## Features

| ID | Feature | Components |
|----|---------|------------|
| M2-F1 | GitHub Actions security workflow | 5 parallel scan jobs: Semgrep CE (SAST), Checkov (IaC), Trivy filesystem with npm audit, pip-audit and tflint (SCA), Trivy image (container), Gitleaks (secrets) |
| M2-F2 | SARIF upload to GitHub Security tab | `github/codeql-action/upload-sarif` for Semgrep, Checkov, Trivy |
| M2-F3 | JSON artifact retention for DefectDojo | `actions/upload-artifact` for all 5 scanners |
| M2-F4 | Branch protection enforcement | Required status checks, PR requirement, bypass prevention |
| M2-F5 | Dependabot for Actions SHA updates | `.github/dependabot.yml` with monthly schedule |

---

### M2-F1: GitHub Actions Security Workflow

**Delivers:** Five parallel security scan jobs running on every PR and push to `main` — SAST, IaC, SCA, container scanning, and secrets detection.

**Key Components:**

- `.github/workflows/security.yml` with 5 jobs: `sast`, `iac`, `sca`, `container`, `secrets`
- Semgrep CE with `--error` flag (fails on findings)
- Checkov with `soft_fail: false` (fails on findings)
- Trivy filesystem with `--scanners vuln --exit-code 1 --severity HIGH,CRITICAL`, plus the ecosystem sub-scans npm audit (`--audit-level=high`), pip-audit and tflint (SARIF only)
- Trivy image with `exit-code: '1'` and `severity: 'HIGH,CRITICAL'`
- Gitleaks with full history scan (`fetch-depth: 0`)
- All GitHub Actions pinned to SHA digests (not mutable version tags)

**Done Criteria:**

- `.github/workflows/security.yml` committed to each repository
- A PR triggers all 5 jobs and they run to completion
- A PR introducing a deliberate IaC misconfiguration (e.g., public S3 bucket) is flagged by Checkov and the job fails
- A PR introducing a known vulnerable dependency is flagged by the SCA job — Trivy filesystem, or npm audit / pip-audit when the advisory is ecosystem-specific
- Scanner steps fail the workflow on findings; only upload steps use `continue-on-error: true`

**Dependencies:** M1-F3 (familiarity with tool output formats from local testing).

---

### M2-F2: SARIF Upload to GitHub Security Tab

**Delivers:** Scan findings visible directly in the GitHub Security > Code Scanning tab for PR reviewers.

**Key Components:**

- `github/codeql-action/upload-sarif` action (SHA-pinned)
- SARIF output from Semgrep (`--sarif`), Checkov (`-o sarif`), and Trivy (`format: sarif`)
- `continue-on-error: true` on upload steps (upload failures should not block the workflow)
- `if: always()` to ensure uploads run even when scanner steps fail

**Done Criteria:**

- After a PR workflow run, navigate to Security > Code Scanning Alerts in the GitHub repository
- SARIF findings from Semgrep, Checkov, and Trivy appear with file locations and severity
- Upload failures do not cause the workflow to fail (confirmed by reviewing a run where upload is the only failure)

**Dependencies:** M2-F1.

---

### M2-F3: JSON Artifact Retention for DefectDojo

**Delivers:** JSON scan results stored as downloadable workflow artifacts for later import into DefectDojo (M4).

**Key Components:**

- `actions/upload-artifact` action (SHA-pinned) for each scanner
- JSON output: `semgrep-results.json`, `checkov-results.json`, `grype-results.json`, `trivy-results.json`, `gitleaks-results.json`
- `continue-on-error: true` on artifact upload steps
- `if: always()` to retain artifacts even when scanners find issues

**Done Criteria:**

- After a workflow run, all 5 JSON artifacts are downloadable from the Actions > workflow run > Artifacts section
- Artifact names match the expected DefectDojo parser input: Semgrep JSON Report, Checkov Scan, Anchore Grype, Trivy Scan, Gitleaks Scan
- Artifacts are retained for the repository's configured retention period

**Dependencies:** M2-F1.

---

### M2-F4: Branch Protection Enforcement

**Delivers:** The CI security gate becomes mandatory — PRs with failing security checks cannot be merged, and direct pushes to `main` are blocked.

**Key Components:**

- GitHub repository Settings > Rules > Rulesets (this stack governs `main` via a ruleset, not classic branch protection)
- Required status checks, byte-exact, read from the check-runs API: `security / SAST — Semgrep CE`, `security / IaC — Checkov`, `security / SCA — Trivy Filesystem`, `security / Container — Trivy Image`, `security / Secrets — Gitleaks` — sourced from `gh api repos/OWNER/REPO/commits/SHA/check-runs`; the caller job (`security`) contributes only the `<job> / <job>` prefix and emits no check run of its own, so this list is five contexts, not six
- Require PR before merging
- Do not allow bypassing the above settings
- Restrict direct pushes to `main`
- See the blueprint's Phase 2 branch-protection passage (`development-security-stack-option-1.md`) for the full adoption procedure, including the ruleset-API read-modify-write warning and the fork-variable caveat

**Done Criteria:**

- `git push origin main` from a local branch is rejected by GitHub with a branch protection error
- A PR with a failing required status check shows the merge button as disabled/blocked
- A PR with all 5 status checks passing can be merged
- `gh api repos/OWNER/REPO/rules/branches/main` shows the ruleset active on `main` with all five required contexts listed — not the classic branch-protection settings screen, which 404s on a ruleset-governed repository by design and is not evidence of anything
- The same PR observed `success` on all five checks in `report-only` and `failure` on all five in `blocking`, switched by the `GATE_MODE` repository variable alone with no YAML edit

**Dependencies:** M2-F1 (workflow must exist so status check names are available for selection).

---

### M2-F5: Dependabot for Actions SHA Updates

**Delivers:** Automated PRs to update SHA-pinned GitHub Actions when new versions are released.

**Key Components:**

- `.github/dependabot.yml` with `package-ecosystem: "github-actions"` and monthly schedule

**Done Criteria:**

- `.github/dependabot.yml` committed to the repository
- Within the next month (or after manual trigger), Dependabot opens PRs updating SHA digests in `.github/workflows/security.yml`
- PRs include release notes for review before merging

**Dependencies:** M2-F1 (SHA-pinned workflow must exist).

---

## Milestone Verification

Run these checks to confirm M2 is complete:

1. **Workflow runs on PR:** Open a test PR — confirm all 5 jobs appear and execute
2. **Scanner enforcement:** Introduce a deliberate finding (e.g., hardcoded `AKIA...` key in a test file) — confirm the `secrets` job fails and blocks merge
3. **SARIF in Security tab:** Navigate to Security > Code Scanning — confirm findings from at least Semgrep and Checkov appear
4. **Artifacts downloadable:** Download JSON artifacts from a completed workflow run — confirm all 5 are present
5. **Branch protection active:** Attempt `git push origin main` directly — confirm rejection; attempt merge with failing check — confirm blocked
6. **Dependabot configured:** Check `.github/dependabot.yml` exists and references `github-actions` ecosystem

## Reference

- Main document: Phase 2 — CI/CD Security Gate (line ~1931)
- Main document: Complete GitHub Actions Workflow (line ~1407)
- Main document: SHA Pinning Note (line ~1425)
- [ADR-001: Remove `continue-on-error: true` from Scanner Steps](../adr/adr001-remove-continue-on-error.md)
- [ADR-002: Make Branch Protection a Required Phase 2 Deliverable](../adr/adr002-require-branch-protection.md)
- [ADR-003: Enable Container Scanning on Pull Request Events](../adr/adr003-enable-container-scanning-on-pr.md)
- [ADR-004: Pin GitHub Actions to SHA Digest Placeholder Pattern](../adr/adr004-pin-actions-to-sha-digest.md)
- [ADR-005: Replace Plaintext Tokens with Environment Variables and GitHub Secrets](../adr/adr005-replace-plaintext-tokens.md)
