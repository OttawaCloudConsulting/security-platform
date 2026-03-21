# CI/CD Security Gate

GitHub Actions security scanning workflow for OttawaCloudConsulting repositories. This is Milestone 2 of the security stack — the server-side enforcement layer that cannot be bypassed from a developer workstation.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design, data flow, scanner coverage matrix, and enforcement model.

## What This Delivers

Five parallel security scanners running on every Pull Request and push to `main`:

| Job | Scanner | What it catches | Output |
|-----|---------|-----------------|--------|
| `sast` | Semgrep CE | Code-level vulnerabilities, injection patterns, unsafe constructs | SARIF + JSON |
| `iac` | Checkov | IaC misconfigurations across Terraform, CloudFormation, K8s, Dockerfile | SARIF + JSON |
| `sca` | Grype | Known dependency vulnerabilities across all ecosystems | JSON |
| `container` | Trivy | Container image vulnerabilities and misconfigurations | SARIF + JSON |
| `secrets` | Gitleaks | Hardcoded secrets and credentials in full git history | JSON |

All scanners execute on GitHub-hosted runners. No infrastructure, accounts, or external services required.

## Requirements

| ID | Requirement | Status |
|---|---|---|
| CICD-01 | GitHub Actions security workflow with 5 parallel scan jobs | Planned |
| CICD-02 | SARIF upload to GitHub Security tab | Planned |
| CICD-03 | JSON artifact retention for DefectDojo import | Planned |
| CICD-04 | Branch protection enforcement | Planned |
| CICD-05 | Dependabot for Actions SHA updates | Planned |

## Deployment

### 1. Security Workflow

Deploy `.github/workflows/security.yml` to each target repository. The workflow:

- Triggers on `pull_request` (all branches) and `push` to `main`
- Runs all five scanners in parallel
- Uploads SARIF to GitHub Security → Code Scanning tab
- Stores JSON results as downloadable workflow artifacts
- Fails the PR check if any scanner finds issues above the configured threshold

All GitHub Actions are pinned to immutable SHA digests. Dependabot automates monthly updates.

### 2. Dependabot Configuration

Deploy `.github/dependabot.yml` to each target repository. This creates monthly PRs to update action SHA digests when new versions are released.

### 3. Branch Protection

Configure in GitHub: **Settings → Branches → Branch protection rules → Add rule**

| Setting | Value |
|---------|-------|
| Branch name pattern | `main` |
| Require a pull request before merging | ✅ |
| Require status checks to pass before merging | ✅ — add: `sast`, `iac`, `sca`, `container`, `secrets` |
| Do not allow bypassing the above settings | ✅ |
| Restrict who can push to matching branches | ✅ |

**Without branch protection, the entire CI security gate is advisory-only.** Scanner failures would not prevent merges.

## Output Destinations

| Format | Destination | When available |
|--------|-------------|----------------|
| **SARIF** | GitHub Security → Code Scanning tab | Immediately after workflow completes |
| **JSON artifacts** | Actions → Workflow run → Artifacts | Downloadable for 90 days (default retention) |
| **JSON → DefectDojo** | DefectDojo API import | After M3 deployment (automated import script) |

## Scanner Details

### Semgrep CE (SAST)

Runs with `--config auto` which fetches community rules from the Semgrep Registry. Covers Python, JavaScript/TypeScript, Go, Java, Ruby, Terraform, YAML, Dockerfile, and more. Intra-file dataflow analysis only (cross-file requires the paid platform).

- Failure mode: `--error` flag — any finding fails the job
- Outputs: JSON (for DefectDojo) + SARIF (for GitHub)

### Checkov (IaC)

1,000+ built-in policies with graph-based cross-resource relationship analysis. Scans Terraform, CloudFormation, CDK (synthesized), Kubernetes manifests, Helm, Dockerfile, GitHub Actions workflows.

- Failure mode: `soft_fail: false` — any policy violation fails the job
- Outputs: CLI + JSON (for DefectDojo) + SARIF (for GitHub)
- Baseline support: existing projects can generate `.checkov.baseline` to suppress known findings

### Grype (SCA)

Scans all dependency ecosystems (npm, pip, Go, Ruby, Rust, Java, .NET). Uses the Anchore vulnerability database.

- Failure mode: `--fail-on high` — HIGH or CRITICAL findings fail the job
- Outputs: JSON (for DefectDojo)
- Complements npm audit (which only covers npm and runs locally in pre-commit)

### Trivy (Container)

Scans built container images for OS package and language-specific dependency vulnerabilities. Also detects misconfigurations in the image.

- Failure mode: `exit-code: 1` with `severity: HIGH,CRITICAL`
- Outputs: JSON (for DefectDojo) + SARIF (for GitHub)
- Requires a `Dockerfile` in the repository; builds the image during the workflow

### Gitleaks (Secrets)

Scans the complete git history (all commits, all branches) for secrets. Uses `fetch-depth: 0` to ensure full history is available.

- Failure mode: any secret found fails the job
- Outputs: JSON (for DefectDojo)
- Compensating control for the bypassable pre-push hook in M1

## Validation Checklist

After deploying to a repository:

- [ ] Open a PR with a deliberate IaC misconfiguration (e.g., S3 bucket with public access). Verify Checkov flags it.
- [ ] Open a PR with a test secret pattern (e.g., `AKIAIOSFODNN7EXAMPLE`). Verify Gitleaks flags it.
- [ ] Confirm SARIF results appear in GitHub Security → Code Scanning tab after the workflow completes.
- [ ] Confirm JSON artifacts are downloadable from the workflow run page.
- [ ] Attempt `git push origin main` directly without a PR. Verify branch protection rejects the push.
- [ ] Open a PR with a failing required status check. Verify the merge button is blocked.
- [ ] Confirm Dependabot creates a PR updating action SHAs within the configured schedule.

## Cross-Platform CI Compatibility

The primary CI platform is **GitHub Actions**. For repositories hosted on other platforms:

| Platform | Approach |
|----------|----------|
| **Azure DevOps** | Install CLI tools via `pip`/`curl` in pipeline steps. Upload SARIF to Azure DevOps Security tab. |
| **GitLab CI** | Install CLI tools via `pip`/`curl` in pipeline steps. Use `--output gitlab_sast` for native GitLab SAST format (Semgrep, Checkov). |

All scanners are CLI-based and install via `pip` or `curl` in any runner — no GitHub-specific plugins are required for the scanning itself. The GitHub-specific parts are SARIF upload (`codeql-action/upload-sarif`) and branch protection configuration.

## Contents

| File | Description |
|------|-------------|
| `ARCHITECTURE.md` | Architecture, design decisions, data flow, enforcement model |
| `README.md` | This document — deployment guide and scanner reference |
| `.github/workflows/security.yml` | Security scanning workflow (deploy to target repo root) |
| `.github/dependabot.yml` | Monthly GitHub Actions SHA digest updates (deploy to target repo root) |
