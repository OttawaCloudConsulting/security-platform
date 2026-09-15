# Milestone 4: DefectDojo (Unified Dashboard)

## Goal

All scan results from CI/CD flow into a single DefectDojo instance that provides unified finding visibility, cross-tool deduplication, finding lifecycle tracking, and a sustainable triage process. DefectDojo becomes the single pane of glass for the security program.

## Prerequisites

- M2 complete (CI/CD security workflow producing JSON artifacts)
- M3 complete (Nexus running on K8s — proves the cluster works and provides package caching for the DefectDojo deployment)
- Kubernetes cluster with sufficient resources (2 Gi RAM, 1 core, 10 Gi storage for DefectDojo)

## Features

| ID | Feature | Components |
|----|---------|------------|
| M4-F1 | DefectDojo deployment on Kubernetes | Helm chart `defectdojo/defectdojo`, version-pinned, values file |
| M4-F2 | Product and engagement configuration | Products per repository, engagement naming convention |
| M4-F3 | CI-to-DefectDojo import automation | Import script, GitHub Actions secret for API token, scanner parsers |
| M4-F4 | Deduplication and triage configuration | Dedup algorithm, severity auto-close, weekly triage cadence |
| M4-F5 | Checkov baseline for existing repos | `checkov --create-baseline` per repository |

---

### M4-F1: DefectDojo Deployment on Kubernetes

**Delivers:** DefectDojo running in the `defectdojo` namespace, accessible via port-forward, with admin credentials secured and version pinned.

**Key Components:**

- Helm chart: `defectdojo/defectdojo`
- Namespace: `defectdojo`
- `defectdojo-values.yaml` version-controlled with pinned `tag` (not `latest`)
- PostgreSQL database (included in Helm chart)

**Done Criteria:**

- `kubectl get pods -n defectdojo` shows all pods in `Running` state
- DefectDojo web UI accessible at `http://localhost:8080` via port-forward
- Admin password retrieved and login confirmed
- `defectdojo-values.yaml` committed to infrastructure repository with a specific version tag (e.g., `tag: "2.x.y"`)
- Upgrade procedure documented: backup DB first, update tag, `helm upgrade`

**Dependencies:** K8s cluster.

---

### M4-F2: Product and Engagement Configuration

**Delivers:** DefectDojo organized with a Product per repository and a consistent engagement naming convention for CI imports.

**Key Components:**

- One DefectDojo Product per target repository
- Engagement naming convention: `CI-YYYYMMDD` (auto-created by import script)
- Product type configured (e.g., "Web Application", "Infrastructure")

**Done Criteria:**

- At least one Product exists in DefectDojo matching a real repository name
- A manual test import creates an Engagement under the correct Product
- The Product hierarchy is visible: Product > Engagement > Test > Findings

**Dependencies:** M4-F1.

---

### M4-F3: CI-to-DefectDojo Import Automation

**Delivers:** Every CI workflow run automatically imports scan results into DefectDojo via the REST API.

**Key Components:**

- Import script using `curl` and the DefectDojo `/api/v2/import-scan/` endpoint
- Scanner parsers, one import call per JSON artifact: `Semgrep JSON Report`, `Checkov Scan`, `Trivy Scan` (SCA filesystem — plus `NPM Audit v7+ Scan` and `pip-audit Scan` where the ecosystem sub-scans fire), `Trivy Scan` (container image), `Gitleaks Scan`
- `DEFECTDOJO_API_TOKEN` stored as a GitHub Actions repository secret
- `auto_create_context=True` for automatic Product/Engagement creation
- Import script added as a post-scan step in `.github/workflows/security.yml` or as a separate job

**Done Criteria:**

- `DEFECTDOJO_API_TOKEN` configured in GitHub repository Settings > Secrets
- A PR workflow run triggers import of all 5 scan result files to DefectDojo
- Findings appear in DefectDojo under the correct Product and Engagement
- Import failures are logged but do not block the CI workflow
- No plaintext API tokens exist in any committed file (per ADR-005)

**Dependencies:** M4-F1, M4-F2, M2-F1, M2-F3.

---

### M4-F4: Deduplication and Triage Configuration

**Delivers:** DefectDojo deduplicates identical findings across scanners and provides a manageable triage workflow.

**Key Components:**

- Deduplication algorithm configured per Product (typically "Legacy" for general use)
- Severity-based auto-close rules: Info and Low findings suppressed on initial triage pass
- Weekly 30-minute triage cadence targeting Critical and High findings
- Finding lifecycle: Open -> Under Review -> Mitigated -> Closed

**Done Criteria:**

- Deduplication enabled: import the same CVE from both Trivy and Grype — DefectDojo merges them into a single finding
- Auto-close configured: Info-severity findings from a test import are automatically closed or suppressed
- A written triage process exists (even a short checklist): what to review, when, and what actions to take
- DefectDojo finding counts reflect deduplication (not raw scanner output counts)

**Dependencies:** M4-F3 (requires imported findings to configure and test dedup).

---

### M4-F5: Checkov Baseline for Existing Repos

**Delivers:** Pre-existing IaC findings are baselined so that CI only flags new findings introduced by each PR.

**Key Components:**

- `checkov -d . --create-baseline` run once per repository
- `.checkov.baseline` file committed to each repository root
- CI workflow updated: `checkov -d . --baseline .checkov.baseline`

**Done Criteria:**

- `.checkov.baseline` committed to each target repository
- A CI run against a PR that introduces no new IaC issues passes the Checkov job (pre-existing findings suppressed)
- A CI run against a PR that introduces a new IaC misconfiguration fails the Checkov job (new finding not in baseline)
- Finding volume in DefectDojo reflects only new/delta findings, not the full pre-existing backlog

**Dependencies:** M2-F1 (CI workflow must exist), M4-F3 (DefectDojo import should be active to observe the volume reduction).

---

## Milestone Verification

Run these checks to confirm M4 is complete:

1. **DefectDojo healthy:** All pods running, UI accessible, admin login works
2. **Import pipeline working:** Push a PR, wait for workflow to complete — findings appear in DefectDojo within minutes
3. **Dedup active:** Same CVE from two scanners shows as 1 finding, not 2
4. **Baseline effective:** Checkov job passes on a repo with many pre-existing IaC findings (baseline suppresses them)
5. **Triage process defined:** A written checklist or SOP exists describing the weekly triage cadence
6. **Security complete:** No plaintext tokens in any committed workflow or script file

## Reference

- Main document: Tool Details — Section 8 (DefectDojo, line ~588)
- Main document: Phase 3b — DefectDojo (line ~1999)
- Main document: Managing Finding Volume (line ~713)
- Main document: Import script for DefectDojo (line ~1602)
- [ADR-005: Replace Plaintext Tokens with Environment Variables and GitHub Secrets](../adr/adr005-replace-plaintext-tokens.md)
- [ADR-006: Pin DefectDojo to Specific Version Tag](../adr/adr006-pin-defectdojo-version.md)
- [ADR-007: Externalize Helm Values to Version-Controlled Files](../adr/adr007-externalize-helm-values.md)
