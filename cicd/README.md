# CI/CD Security Gate

Security scanning pipelines for OttawaCloudConsulting repositories. This is Milestone 2 of the security stack — the server-side enforcement layer that cannot be bypassed from a developer workstation.

Pipeline configurations are provided for **GitHub Actions**, **Azure DevOps**, and **GitLab CI/CD**. All three run the same five scanners using the same CLI tools.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design, data flow, scanner coverage matrix, and enforcement model.

## What This Delivers

Five parallel security scanners running on every Pull Request and push to `main`:

| Job | Scanner | What it catches | Failure threshold |
|-----|---------|-----------------|-------------------|
| `sast` | Semgrep CE | Code-level vulnerabilities, injection patterns, unsafe constructs | Any finding |
| `iac` | Checkov | IaC misconfigurations across Terraform, CloudFormation, K8s, Dockerfile | Any policy violation |
| `sca` | Grype | Known dependency vulnerabilities across all ecosystems | HIGH or CRITICAL |
| `container` | Trivy | Container image vulnerabilities and misconfigurations | HIGH or CRITICAL |
| `secrets` | Gitleaks | Hardcoded secrets and credentials in full git history | Any finding |

All scanners install via `pip` or `curl` on each run. No marketplace extensions or external services required.

## Requirements

| ID | Requirement | Status |
|---|---|---|
| CICD-01 | Security pipeline with 5 parallel scan jobs | Planned |
| CICD-02 | SARIF upload to platform security dashboard (where supported) | Planned |
| CICD-03 | JSON artifact retention for DefectDojo import | Planned |
| CICD-04 | Branch protection enforcement | Planned |
| CICD-05 | Renovate for Actions SHA updates (GitHub) | Planned |

## Deployment

### GitHub Actions

Deploy to the target repository:

```bash
cp -r cicd/.github/ <target-repo>/.github/
cp cicd/renovate.json <target-repo>/renovate.json
```

**Files deployed:**

| File | Location in target repo | Description |
|------|------------------------|-------------|
| `.github/workflows/security.yml` | `.github/workflows/security.yml` | Security scanning workflow |
| `renovate.json` | `renovate.json` | Automated SHA digest updates |

**Platform-specific features:**

- All actions SHA-pinned to immutable digests
- SARIF upload to GitHub Security → Code Scanning tab (Semgrep, Checkov, Trivy)
- JSON artifacts downloadable from workflow run page
- Renovate keeps SHA digests current via weekly PRs

**Renovate** can be enabled via:

- **Mend Renovate App** (free hosted) — install from the [GitHub Marketplace](https://github.com/apps/renovate)
- **Self-hosted Renovate** — run via `renovatebot/github-action` in a scheduled workflow

### Azure DevOps

Deploy to the target repository:

```bash
cp cicd/azure-pipelines/azure-pipelines.yml <target-repo>/azure-pipelines.yml
```

**Files deployed:**

| File | Location in target repo | Description |
|------|------------------------|-------------|
| `azure-pipelines.yml` | `azure-pipelines.yml` (repo root) | Security scanning pipeline |

**Platform-specific features:**

- Pipeline triggers on PR to any branch and push to `main`
- SARIF files published as pipeline artifacts (uploadable to Azure DevOps Security tab via extensions)
- JSON artifacts published as pipeline artifacts
- Container job sets a variable to gracefully skip when no Dockerfile is present

**Branch policy:** Configure in Azure DevOps: **Repos → Branches → main → Branch policies**

- Require a minimum number of reviewers
- Check for linked work items
- Build validation: add the security pipeline as a required build

### GitLab CI/CD

Deploy to the target repository:

```bash
cp cicd/gitlab-ci/.gitlab-ci.yml <target-repo>/.gitlab-ci.yml
```

**Files deployed:**

| File | Location in target repo | Description |
|------|------------------------|-------------|
| `.gitlab-ci.yml` | `.gitlab-ci.yml` (repo root) | Security scanning pipeline |

**Platform-specific features:**

- Pipeline triggers on merge request events and pushes to the default branch
- Semgrep outputs native GitLab SAST format (`gl-sast-report.json`) for the Security Dashboard
- JSON and SARIF artifacts retained per pipeline
- Container job uses Docker-in-Docker (`docker:dind`) service
- Full git history fetched for Gitleaks via `GIT_DEPTH: 0`

**Branch protection:** Configure in GitLab: **Settings → Repository → Protected branches**

- Protect `main`: set allowed to merge and allowed to push
- **Settings → Merge requests**: require pipeline to succeed before merging

### Branch Protection (All Platforms)

Without branch protection, scanner failures are advisory-only. The specific settings per platform:

| Platform | Setting location | Key settings |
|----------|-----------------|--------------|
| **GitHub** | Settings → Branches → Branch protection rules | Require status checks (`sast`, `iac`, `sca`, `container`, `secrets`); require PR; do not allow bypassing |
| **Azure DevOps** | Repos → Branches → main → Branch policies | Build validation (add security pipeline); minimum reviewers |
| **GitLab** | Settings → Repository → Protected branches + Merge requests | Protect `main`; require pipeline to succeed |

## Output Formats by Platform

| Output | GitHub | Azure DevOps | GitLab |
|--------|--------|--------------|--------|
| **SARIF → Security Dashboard** | ✅ Code Scanning tab | Via extensions | Not native (SARIF is artifact-only) |
| **Native SAST report** | N/A | N/A | ✅ GitLab SAST format (Semgrep) |
| **JSON artifacts** | ✅ Workflow artifacts | ✅ Pipeline artifacts | ✅ Job artifacts |
| **DefectDojo import** | ✅ JSON artifacts | ✅ JSON artifacts | ✅ JSON artifacts |

## Scanner Details

### Semgrep CE (SAST)

Runs with `--config auto` which fetches community rules from the Semgrep Registry. Covers Python, JavaScript/TypeScript, Go, Java, Ruby, Terraform, YAML, Dockerfile, and more.

- Failure mode: `--error` flag — any finding fails the job
- Outputs: JSON + SARIF + GitLab SAST (platform-dependent)

### Checkov (IaC)

1,000+ built-in policies with graph-based cross-resource relationship analysis. Scans Terraform, CloudFormation, CDK (synthesized), Kubernetes manifests, Helm, Dockerfile, GitHub Actions workflows.

- Failure mode: `soft_fail: false` — any policy violation fails the job
- Outputs: CLI + JSON + SARIF
- Baseline support: existing projects can generate `.checkov.baseline` to suppress known findings

### Grype (SCA)

Scans all dependency ecosystems (npm, pip, Go, Ruby, Rust, Java, .NET). Uses the Anchore vulnerability database.

- Failure mode: `--fail-on high` — HIGH or CRITICAL findings fail the job
- Outputs: JSON

### Trivy (Container)

Scans built container images for OS package and language-specific dependency vulnerabilities.

- Failure mode: `exit-code 1` with `severity HIGH,CRITICAL`
- Outputs: JSON + SARIF
- Gracefully skips if no Dockerfile is present

### Gitleaks (Secrets)

Scans the complete git history for secrets. Requires full history checkout (`fetch-depth: 0` / `GIT_DEPTH: 0`).

- Failure mode: any secret found fails the job
- Outputs: JSON
- Compensating control for the bypassable pre-push hook in M1

## Validation Checklist

After deploying to a repository (any platform):

- [ ] Open a PR/MR with a deliberate IaC misconfiguration. Verify Checkov flags it.
- [ ] Open a PR/MR with a test secret pattern (e.g., `AKIAIOSFODNN7EXAMPLE`). Verify Gitleaks flags it.
- [ ] Confirm JSON artifacts are downloadable from the pipeline run.
- [ ] Confirm scanner failures block the merge (requires branch protection).
- [ ] Attempt a direct push to `main` without a PR/MR. Verify branch protection rejects it.
- [ ] (GitHub only) Confirm SARIF results appear in Security → Code Scanning tab.
- [ ] (GitLab only) Confirm SAST results appear in the Security Dashboard.
- [ ] (GitHub only) Confirm Renovate opens a PR updating action SHAs.

## Contents

| File | Description |
|------|-------------|
| `ARCHITECTURE.md` | Architecture, design decisions, data flow, enforcement model |
| `README.md` | This document — deployment guide and scanner reference |
| `renovate.json` | Renovate config for GitHub Actions SHA updates (deploy to target repo root) |
| `.github/workflows/security.yml` | GitHub Actions security workflow |
| `azure-pipelines/azure-pipelines.yml` | Azure DevOps security pipeline |
| `gitlab-ci/.gitlab-ci.yml` | GitLab CI/CD security pipeline |
