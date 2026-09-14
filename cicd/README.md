# CI/CD Security Gate

Security scanning pipelines for OttawaCloudConsulting repositories. This is Milestone 2 of the security stack — the server-side enforcement layer that cannot be bypassed from a developer workstation.

Pipeline configurations are provided for **GitHub Actions**, **Azure DevOps**, and **GitLab CI/CD**. Only the GitHub Actions pipeline has been built and live-proven (Phases 14-19); the Azure DevOps and GitLab members below are unvalidated design drafts, authored before the GitHub pipeline existed, and are labelled as drafts throughout this document.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design, data flow, scanner coverage matrix, and enforcement model.

## What This Delivers

### GitHub Actions (built, live-validated)

Five parallel security scan jobs run on every Pull Request and push to `main`, callable as a reusable `workflow_call` workflow:

| Job | Tool(s) | What it catches | Failure semantics |
|-----|---------|-----------------|-------------------|
| SAST | Semgrep CE | Code-level vulnerabilities, injection patterns, unsafe constructs | Any finding fails (native `--error` exit) |
| IaC | Checkov | IaC misconfigurations across Terraform, CloudFormation, K8s, Dockerfile | Any policy violation fails (`soft_fail: false`) |
| SCA | Trivy filesystem, npm audit, pip-audit, tflint | Known dependency vulnerabilities and Terraform provider/module pinning gaps | Per-tool: Trivy and npm audit fail on HIGH/CRITICAL (exit 1); tflint signals findings with **exit 2**, not exit 1; pip-audit emits no severity field at all, so its gate is severity-agnostic — it fails on ANY finding |
| Container | Trivy image | Container image OS package and language-dependency vulnerabilities | HIGH or CRITICAL fails (exit 1); the job skips cleanly when no Dockerfile is discovered |
| Secrets | Gitleaks | Hardcoded secrets and credentials in full git history | Any finding fails |

`gate_mode` (`blocking` or `report-only`, default `report-only`) is the one per-repo substitution point across the whole bundle — see Deployment below.

### Azure DevOps and GitLab CI/CD (unvalidated drafts)

The Azure DevOps and GitLab members of this package describe the same five-scanner design but have never been built or run. Treat everything in their sections below as a starting point to implement and validate, not a proven deployment.

## Requirements

| ID | Requirement | Status |
|---|---|---|
| CICD-01 | Security pipeline with 5 parallel scan jobs | Complete (Phases 14-19) |
| CICD-02 | SARIF upload to platform security dashboard (where supported) | Complete (Phases 14-19) |
| CICD-03 | JSON artifact retention for DefectDojo import | Complete (Phases 14-19) |
| CICD-04 | Branch protection enforcement | Complete (Phases 14-19) |
| CICD-05 | Dependabot for Actions SHA updates (GitHub) | Complete (Phases 14-19) |
| CICD-06 | Configurable gate mode (`gate_mode`: blocking / report-only) | Complete (Phases 14-19) |

## Deployment

### GitHub Actions

The canonical, live-validated pipeline lives at the repository root of this host repo, not under `cicd/`:

- `.github/workflows/security.yml` — the callable scanning workflow (`workflow_call`)
- `.github/workflows/pr-security.yml` — the local `pull_request` caller
- `.github/dependabot.yml` — Dependabot config for Actions SHA updates

A consumer repository adopts these by one of two modes:

1. **Copy-paste** the three files above into the target repo, unmodified.
2. **Reference as a reusable workflow**: `uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1`.

The full walk-through for both modes — including `gate_mode` selection, branch protection setup, and Dependabot wiring — is the procedure of record: `docs/adoption-guide.md` in the `security_solution` documentation repository.

**Files deployed:**

| File | Location in target repo | Description |
|------|------------------------|-------------|
| `.github/workflows/security.yml` | `.github/workflows/security.yml` | Security scanning workflow |
| `.github/workflows/pr-security.yml` | `.github/workflows/pr-security.yml` | Pull-request caller |
| `.github/dependabot.yml` | `.github/dependabot.yml` | Actions SHA-pin update config |

**Platform-specific features:**

- All actions SHA-pinned to immutable digests, version comments maintained by Dependabot
- SARIF upload to GitHub Security → Code Scanning tab (Semgrep, Checkov, Trivy filesystem, Trivy image, tflint, Gitleaks)
- JSON artifacts downloadable from the workflow run page, 90-day retention
- Dependabot keeps SHA digests current via weekly PRs — no external account, no Marketplace app

### Azure DevOps (unvalidated draft)

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

### GitLab CI/CD (unvalidated draft)

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

### Branch Protection (GitHub Actions)

Enforcement runs through a repository **ruleset**, read and written via the `/rulesets` API (`rules/branches/main`) — not the classic branch-protection settings screen. The classic `branches/main/protection` endpoint 404s by design on a rulesets-only repository and must never be cited as evidence that gating is or is not in force.

The five required contexts (em dash U+2014, `security /` prefix — copy exactly, do not retype from a job id):

| Required status check |
|------------------------|
| `security / SAST — Semgrep CE` |
| `security / IaC — Checkov` |
| `security / SCA — Trivy Filesystem` |
| `security / Container — Trivy Image` |
| `security / Secrets — Gitleaks` |

This host repository's own `main` deliberately leaves these contexts unrequired (decided in Phase 18, re-confirmed in Phase 19) because `fixtures/` guarantees findings on every PR, which would otherwise permanently block merges here.

**Recommended adoption order for a consumer repository** (D-07):

1. Deploy with `gate_mode` at its default (`report-only`). Confirm the five checks above appear and conclude on a PR.
2. Set `gate_mode` to `blocking` (`gh variable set GATE_MODE --body blocking -R OWNER/REPO`). Confirm the checks now turn red on a tree with real findings.
3. Only then add the five checks as required status checks in the repository's ruleset.

| Platform | Setting location | Key settings |
|----------|-----------------|--------------|
| **GitHub** | Repository ruleset (`/rulesets`, `rules/branches/main`) | Require the five status checks above; require PR; do not allow bypassing |
| **Azure DevOps** (draft) | Repos → Branches → main → Branch policies | Build validation (add security pipeline); minimum reviewers |
| **GitLab** (draft) | Settings → Repository → Protected branches + Merge requests | Protect `main`; require pipeline to succeed |

## Output Formats by Platform

| Output | GitHub | Azure DevOps | GitLab |
|--------|--------|--------------|--------|
| **SARIF → Security Dashboard** | Code Scanning tab | Via extensions | Not native (SARIF is artifact-only) |
| **Native SAST report** | N/A | N/A | GitLab SAST format (Semgrep) |
| **JSON artifacts** | Workflow artifacts | Pipeline artifacts | Job artifacts |
| **DefectDojo import** | JSON artifacts | JSON artifacts | JSON artifacts |

## Scanner Details (GitHub Actions)

### Semgrep CE (SAST)

Runs with `--config p/default --metrics=off` — the community default ruleset. `--config auto` is a hard error when combined with `--metrics=off` and is not used.

- Failure mode: native `--error` flag — any finding fails the job
- Outputs: JSON + SARIF

### Checkov (IaC)

1,000+ built-in policies with graph-based cross-resource relationship analysis. Scans Terraform, CloudFormation, CDK (synthesized), Kubernetes manifests, Helm, Dockerfile, GitHub Actions workflows.

- Failure mode: `soft_fail: false` — any policy violation fails the job
- Outputs: CLI + JSON + SARIF

### Trivy filesystem, npm audit, pip-audit, tflint (SCA)

One job runs four tools: Trivy filesystem sweep (generic, ecosystem-agnostic), npm audit (only if a lockfile is discovered), pip-audit (only if a requirements file is discovered), and tflint (only if `.tf` files are discovered). Each ecosystem sub-scan skips cleanly, with an explicit `SKIP:` log line, when the corresponding manifest is absent.

- Trivy filesystem failure mode: `exit-code 1` with `severity HIGH,CRITICAL`
- npm audit failure mode: `--audit-level=high` gates the exit code only — it does not filter the retained report
- pip-audit failure mode: any finding fails; the JSON report carries no severity or CVSS field, so no severity threshold can be derived from it
- tflint failure mode: signals findings with **exit code 2**, reserving exit 1 for an application error — do not treat tflint's exit codes as interchangeable with the other three tools' exit 1

### Trivy image (Container)

Builds the discovered container image and scans it for OS package and language-specific dependency vulnerabilities.

- Failure mode: `exit-code 1` with `severity HIGH,CRITICAL`
- Outputs: JSON + SARIF
- Skips cleanly if no Dockerfile is discovered

### Gitleaks (Secrets)

Scans the complete git history for secrets. Requires full history checkout (`fetch-depth: 0`).

- Failure mode: any secret found fails the job
- Outputs: JSON + SARIF
- Compensating control for the bypassable pre-push hook in M1

## Validation Checklist

After deploying to a repository (any platform):

- [ ] Open a PR/MR with a deliberate IaC misconfiguration. Verify Checkov flags it.
- [ ] Open a PR/MR with a test secret pattern (e.g., `AKIAIOSFODNN7EXAMPLE`). Verify Gitleaks flags it.
- [ ] Confirm JSON artifacts are downloadable from the pipeline run.
- [ ] (GitHub) With `gate_mode` at its default, confirm the five checks appear and conclude on a PR — this is report-only tolerance, not a merge gate yet.
- [ ] (GitHub) Flip `gate_mode` to `blocking` and confirm the same checks now turn red on a tree with real findings.
- [ ] (GitHub) Only then add the five checks as required status checks in the repository ruleset, and confirm a failing PR is now actually blocked from merging.
- [ ] Attempt a direct push to `main` without a PR/MR. Verify branch protection rejects it.
- [ ] (GitHub only) Confirm SARIF results appear in Security → Code Scanning tab.
- [ ] (GitLab only) Confirm SAST results appear in the Security Dashboard.
- [ ] (GitHub only) Confirm Dependabot opens a PR updating action SHAs.

## Contents

| File | Description |
|------|-------------|
| `ARCHITECTURE.md` | Architecture, design decisions, data flow, enforcement model |
| `README.md` | This document — deployment guide and scanner reference |
| `azure-pipelines/azure-pipelines.yml` | Azure DevOps security pipeline (unvalidated draft) |
| `gitlab-ci/.gitlab-ci.yml` | GitLab CI/CD security pipeline (unvalidated draft) |
