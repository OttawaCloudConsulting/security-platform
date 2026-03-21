# CI/CD Security Gate Architecture

Architecture and design reference for the CI/CD security gate layer (Milestone 2 / Phase 2 of the security stack blueprint).

## Overview

The CI/CD layer is the **server-side enforcement point** for code security. It runs five parallel security scanners on every Pull Request and on direct pushes to `main`, producing findings in the GitHub Security tab and downloadable JSON artifacts. Combined with branch protection, it is the mechanism that cannot be bypassed from a developer workstation.

No infrastructure is required — all scanners execute on GitHub-hosted runners. No accounts, logins, or external services are needed beyond the existing GitHub repository.

**Total cost: $0. External accounts required: 0.** (GitHub Actions free tier: 2,000 minutes/month for private repos, unlimited for public repos.)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Developer Workstation (M1)                           │
│  Pre-commit Tier 1 (linting) + Tier 2 (secrets gate)                   │
│  Bypassable: git commit/push --no-verify                               │
└────────────────────────────┬────────────────────────────────────────────┘
                             │ git push
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          GitHub Repository                              │
│                                                                         │
│  Pull Request opened or Push to main                                    │
│         │                                                               │
│         ▼                                                               │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │           GitHub Actions: security.yml                            │  │
│  │                                                                   │  │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │  │
│  │  │  SAST   │ │   IaC   │ │   SCA   │ │Container│ │ Secrets │   │  │
│  │  │ Semgrep │ │ Checkov │ │  Grype  │ │  Trivy  │ │Gitleaks │   │  │
│  │  │   CE    │ │         │ │         │ │         │ │         │   │  │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘   │  │
│  │       │           │           │           │           │         │  │
│  │       ▼           ▼           ▼           ▼           ▼         │  │
│  │  ┌─────────────────────────────────────────────────────────┐    │  │
│  │  │              Output Destinations                         │    │  │
│  │  │                                                         │    │  │
│  │  │  SARIF ──► GitHub Security Tab (Code Scanning)          │    │  │
│  │  │  JSON  ──► Workflow Artifacts (downloadable)            │    │  │
│  │  │  JSON  ──► DefectDojo API import (M3)                   │    │  │
│  │  └─────────────────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │           Branch Protection (required)                            │  │
│  │                                                                   │  │
│  │  Required status checks: sast, iac, sca, container, secrets       │  │
│  │  Require PR before merging                                        │  │
│  │  Do not allow bypassing                                           │  │
│  │  Restrict direct pushes to main                                   │  │
│  │                                                                   │  │
│  │  Without this, scanner failures are advisory-only.                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │           Dependabot (.github/dependabot.yml)                     │  │
│  │                                                                   │  │
│  │  Monthly PRs updating GitHub Actions SHA digests                  │  │
│  │  Prevents version rot in pinned action references                 │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Design Decisions

### Five Parallel Scanner Jobs

The workflow runs five independent jobs rather than a single sequential pipeline:

| Job | Scanner | What it finds | Failure threshold |
|-----|---------|---------------|-------------------|
| `sast` | Semgrep CE | Code-level vulnerabilities, injection patterns, unsafe constructs | Any finding (--error) |
| `iac` | Checkov | IaC misconfigurations, policy violations across Terraform/CFN/K8s | Any finding (soft_fail: false) |
| `sca` | Grype | Known vulnerabilities in dependencies (all ecosystems) | HIGH or CRITICAL (--fail-on high) |
| `container` | Trivy | Container image vulnerabilities + misconfigurations | HIGH or CRITICAL |
| `secrets` | Gitleaks | Hardcoded secrets, API keys, credentials in full git history | Any finding |

Parallel execution means a secret detection failure does not block or delay the SAST result. Each job is an independent required status check in branch protection, so all five must pass for a PR to be mergeable.

### Why Semgrep and Checkov Run Here, Not in Pre-commit

Both tools perform full-repository analysis on every invocation:

1. **Overhead** — each run adds seconds to minutes depending on codebase size, multiplied across dozens of commits per day.
2. **Wrong gate for feature branches** — developers working in feature branches push intentionally incomplete code. Blocking on every commit creates noise that trains developers to ignore the tool.

The Pull Request is the meaningful enforcement point — code is asserting it is ready to enter a protected branch. See the [workstation ARCHITECTURE.md](../workstation/ARCHITECTURE.md) for the full two-tier rationale.

### SHA Pinning for GitHub Actions

All actions are pinned to immutable SHA digests rather than mutable version tags (`@v4`, `@master`). Mutable tags can be silently updated by the action maintainer — intentionally or after a supply-chain compromise — and the workflow executes the changed code without notice.

SHA pinning ensures you run exactly the code you reviewed. Dependabot automates SHA updates via monthly PRs.

**To find the current SHA for any action:**

```bash
gh api repos/<owner>/<repo>/git/ref/tags/<version> --jq '.object.sha'
```

Related decision: [ADR-004](../../docs/adr/adr004-pin-actions-to-sha-digest.md)

### continue-on-error Strategy

`continue-on-error` is **removed from all scanner steps**. Scanner failures must fail the workflow to enforce the security gate. It is **retained on upload steps** (SARIF upload, artifact upload) — these are reporting mechanisms, and a transient GitHub API failure should not block a merge.

Related decision: [ADR-001](../../docs/adr/adr001-remove-continue-on-error.md)

### Branch Protection as a Required Deliverable

Branch protection is not optional. Without it:

- Developers can push directly to `main`, bypassing all PR-based scanning
- Failing scanner jobs have no effect on merge eligibility
- The entire CI security gate is advisory-only

Related decision: [ADR-002](../../docs/adr/adr002-require-branch-protection.md)

### Container Scanning on Pull Requests

The container job runs on both `pull_request` and `push` events. Container vulnerabilities must be visible to reviewers before merge, not only after code reaches `main`.

Related decision: [ADR-003](../../docs/adr/adr003-enable-container-scanning-on-pr.md)

### Dual Output Format (SARIF + JSON)

Each scanner produces two output formats:

| Format | Destination | Purpose |
|--------|-------------|---------|
| **SARIF** | GitHub Security → Code Scanning tab | Native GitHub integration; findings appear inline on PR diffs |
| **JSON** | Workflow artifacts (downloadable) | DefectDojo import (M3); offline analysis; audit trail |

SARIF upload uses `github/codeql-action/upload-sarif` with `continue-on-error: true` — a SARIF upload failure is a reporting issue, not a security gate failure.

### Secrets in Workflow Configuration

All tokens and credentials use `${{ secrets.* }}` references. No plaintext tokens appear in workflow files, even as placeholder examples.

Related decision: [ADR-005](../../docs/adr/adr005-replace-plaintext-tokens.md)

## Scanner Coverage Matrix

| Language / Framework | Semgrep CE | Checkov | Trivy | Grype | Gitleaks |
|---|---|---|---|---|---|
| Terraform (HCL) | ✅ | ✅ 1000+ policies | ✅ tfsec rules | — | ✅ |
| AWS CDK (TypeScript) | ✅ TS rules | ✅ synth'd CFN | ✅ npm deps | ✅ npm deps | ✅ |
| CloudFormation | ✅ | ✅ | ✅ | — | ✅ |
| Python | ✅ | — | ✅ pip/poetry | ✅ pip/poetry | ✅ |
| JavaScript / TypeScript | ✅ | — | ✅ npm/yarn | ✅ npm/yarn | ✅ |
| Bash / Shell | ✅ basic | — | — | — | ✅ |
| Kubernetes YAML | ✅ | ✅ | ✅ | — | ✅ |
| Dockerfile | ✅ | ✅ | ✅ image+cfg | ✅ layers | ✅ |
| Helm Charts | — | ✅ | ✅ | — | ✅ |
| Container Images | — | — | ✅ full vuln | ✅ full vuln | — |
| GitHub Actions workflows | — | ✅ | — | — | ✅ |

## Data Flow

```
Pull Request opened (or push to main)
        │
        ▼
GitHub Actions triggers security.yml
        │
        ├──► sast job:     Semgrep CE scans source code
        │                   → semgrep-results.json (artifact)
        │                   → semgrep.sarif → GitHub Security tab
        │
        ├──► iac job:      Checkov scans IaC (Terraform, CFN, K8s, Dockerfile)
        │                   → checkov-results.json (artifact)
        │                   → checkov.sarif → GitHub Security tab
        │
        ├──► sca job:      Grype scans dependencies (all ecosystems)
        │                   → grype-results.json (artifact)
        │
        ├──► container job: Trivy scans built container image
        │                   → trivy-results.json (artifact)
        │                   → trivy.sarif → GitHub Security tab
        │
        └──► secrets job:  Gitleaks scans full git history
                            → gitleaks-results.json (artifact)
        │
        ▼
All 5 jobs must pass (branch protection required status checks)
        │
        ├── Pass → PR is mergeable
        └── Fail → PR blocked; developer fixes findings
```

## Relationship to Other Milestones

| Milestone | Relationship |
|---|---|
| **M1 — Workstation Foundation** | Pre-commit hooks are the fast inner loop; CI is the enforcement guarantee. Gitleaks runs in both layers — client-side for fast feedback, server-side for non-bypassable scanning. |
| **M3 — Self-Hosted Infrastructure** | DefectDojo imports the JSON artifacts produced by each scanner job. The import script runs as a post-workflow step once DefectDojo is deployed. |
| **M4 — Runtime Security** | No direct CI interaction. Trivy Operator scans running workloads independently of the CI pipeline. |

## Enforcement Chain

The full enforcement model is defence-in-depth across three layers:

```
Layer 1: Pre-commit hooks (M1)
    ↓ client-side, bypassable with --no-verify
    ↓ catches: linting issues, formatting, secrets

Layer 2: CI/CD security workflow (M2) ← this milestone
    ↓ server-side, non-bypassable
    ↓ catches: SAST, IaC, SCA, container vulns, secrets (full history)

Layer 3: Branch protection
    ↓ prevents merge without passing CI
    ↓ prevents direct push to main
    ↓ makes the enforcement chain binding
```

Without Layer 3 (branch protection), Layers 1 and 2 are advisory. Branch protection is what transforms CI scan results into a mandatory gate.

## File Structure

```
cicd/
├── ARCHITECTURE.md                          # This document
├── README.md                                # Quick start and deployment guide
└── .github/
    ├── workflows/
    │   └── security.yml                     # Security scanning workflow
    └── dependabot.yml                       # Monthly SHA digest updates
```

To deploy, copy the `.github/` directory to each target repository root:

```bash
cp -r cicd/.github/ <target-repo>/.github/
```
