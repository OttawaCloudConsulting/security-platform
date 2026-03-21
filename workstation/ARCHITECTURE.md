# Workstation Security Architecture

Architecture and design reference for the developer workstation security layer (Milestone 1 / Phase 1 of the security stack blueprint).

## Overview

The workstation layer is the first line of defence in a four-phase security stack. It establishes two categories of automated checks that run without any infrastructure:

1. **Pre-commit hooks** — automated quality and secrets gates wired into the git workflow
2. **CLI security tools** — on-demand scanners for vulnerabilities, SBOMs, and secrets

The workstation layer is designed for a single-developer AWS cloud practice working across Terraform, CDK, CloudFormation, Python, TypeScript/JavaScript, Bash, Kubernetes/YAML, and Docker.

**Total cost: $0. External accounts required: 0.**

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Developer Workstation                            │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Pre-commit Tier 1 — Quality & Linting (every commit)             │  │
│  │                                                                   │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │  │
│  │  │ ShellCheck │ │   Ruff     │ │  ESLint *  │ │  hadolint  │     │  │
│  │  │  (sh/bash) │ │  (Python)  │ │  (TS/JS)   │ │(Dockerfile)│     │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘     │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────────┐  │  │
│  │  │  yamllint  │ │markdown-   │ │ npm audit *│ │ tf fmt/val ^ │  │  │
│  │  │ (K8s/YAML) │ │  lint (.md)│ │ (fast dep) │ │ (Terraform)  │  │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └──────────────┘  │  │
│  │                                                                   │  │
│  │  * = local hook (requires system Node.js/npm)                     │  │
│  │  ^ = remote hook but delegates to system Terraform binary         │  │
│  │  All others = fully managed by pre-commit (isolated environments) │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Pre-push Tier 2 — Secrets Gate (before push)                     │  │
│  │                                                                   │  │
│  │  ┌────────────┐                                                   │  │
│  │  │  Gitleaks  │  Scans staged changes for credentials/secrets     │  │
│  │  │ (Secrets)  │  Bypassable: git push --no-verify                 │  │
│  │  └────────────┘  Compensating control: CI re-scans server-side    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ CLI Tools — On-Demand (installed by dist/install.sh)             │  │
│  │                                                                   │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐                    │  │
│  │  │   Trivy    │ │    Syft    │ │   Grype    │                    │  │
│  │  │(Multi-scan)│ │   (SBOM)   │ │   (SCA)    │                    │  │
│  │  └────────────┘ └────────────┘ └────────────┘                    │  │
│  │                                                                   │  │
│  │  Trivy: container, filesystem, IaC, and secrets scanning          │  │
│  │  Syft:  SBOM generation (CycloneDX, SPDX)                        │  │
│  │  Grype: dependency vulnerability scanning against SBOM or dir     │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  git push ──► CI/CD (Milestone 2: Semgrep, Checkov, Trivy, Grype,      │
│               Gitleaks full-history — runs server-side in GitHub Actions)│
└─────────────────────────────────────────────────────────────────────────┘
```

## Design Decisions

### Two-Tier Hook Architecture

Pre-commit hooks are split into two tiers with different trigger points:

| Tier | Trigger | Purpose | Speed |
|------|---------|---------|-------|
| **Tier 1** — Quality & Linting | Every `git commit` | Catch formatting, style, and syntax issues immediately | Fast (sub-second per hook) |
| **Tier 2** — Secrets Gate | Every `git push` | Block credentials before they reach any remote | Fast (scans staged changes only) |

**Why only secrets in Tier 2, not SAST or IaC scanning:**

Semgrep CE (SAST) and Checkov (IaC) perform full-repository analysis on every invocation. Running either on every commit has two problems:

1. **Overhead** — each run adds seconds to minutes depending on codebase size, compounding across dozens of commits per day.
2. **Wrong gate for feature branches** — developers working in feature branches push code that is intentionally incomplete. Blocking or warning on every commit creates noise that trains developers to ignore the tool.

The meaningful enforcement point is the Pull Request, where code asserts it is ready to enter a protected branch. Semgrep and Checkov run at the PR gate in GitHub Actions (Milestone 2).

Secrets are the exception because a credential pushed to **any** branch — including a throwaway feature branch — is an exposure from the moment it touches a remote. Branch context does not reduce that risk.

### Pre-commit Tool Isolation Model

The pre-commit framework manages tool installation in isolated environments. This is a deliberate design choice:

```
Hook type        Tool management             System dependency
─────────────    ─────────────────────────    ─────────────────
Remote hook  →   pre-commit clones repo,     None (self-contained)
                 installs tool in isolated
                 env under ~/.cache/
                 pre-commit/

Local hook   →   pre-commit runs command     Tool must exist on
                 directly on system PATH      developer's system

Remote hook  →   pre-commit clones repo,     Underlying binary
(delegating)     but hook script calls        must exist on PATH
                 system binary (e.g.          (e.g. terraform)
                 terraform)
```

**Hooks fully managed by pre-commit (no system install needed):**

- ShellCheck — `shellcheck-py` downloads platform-specific binary
- Ruff — `ruff-pre-commit` downloads platform-specific binary
- hadolint — `hadolint/hadolint` downloads platform-specific binary
- yamllint — installed into isolated Python virtualenv
- markdownlint — installed into isolated Node.js environment
- Gitleaks — downloads platform-specific binary

**Hooks requiring system dependencies:**

- ESLint — `local` hook runs `npx eslint`; requires Node.js + project-local ESLint
- npm audit — `local` hook runs `npm audit`; requires Node.js + npm
- terraform fmt/validate — remote hook delegates to `terraform` on PATH

### CLI Tool Installation Strategy

The `setup.sh` script uses three installation methods based on tool type:

| Method | Tools | Rationale |
|--------|-------|-----------|
| **pipx** | pre-commit | Python CLI tool; pipx provides dependency isolation without polluting the system Python |
| **Official install scripts** | Trivy, Syft, Grype | Anchore and Aqua Security maintain canonical install scripts that handle OS/arch detection |
| **Direct binary download + SHA-256 checksum** | Gitleaks, hadolint | Single static binaries; direct download is simplest and checksum verification ensures integrity |

All tools install to `~/.local/bin`. The installer is idempotent — re-running skips tools already at the pinned version.

**Why not Homebrew?** Homebrew is macOS-only and adds a dependency on Homebrew itself. The setup script supports both macOS and Linux with no package manager dependency beyond `curl` and `python3`.

### Version Resolution

On first run, `setup.sh` resolves the latest release version for each tool and hook from the GitHub Releases API. These versions are written to `versions.conf` (for CLI tools) and embedded in `.pre-commit-config.yaml` (for hook `rev:` fields). If `versions.conf` already exists, the script uses the pinned versions without re-resolving — giving the developer control over when to uptake new versions.

Fallback versions are hardcoded in the script for environments where the GitHub API is unreachable (e.g., air-gapped networks or rate-limited CI runners).

### What the Workstation Does NOT Install

| Tool | Where it runs | Rationale |
|------|--------------|-----------|
| **Semgrep CE** | CI/CD (GitHub Actions) | Full-repo SAST analysis is expensive; suited to PR gate, not commit loop |
| **Checkov** | CI/CD (GitHub Actions) | Full IaC traversal with cross-resource analysis; same rationale as Semgrep |

Both tools can be installed manually for ad-hoc local use (`pip install semgrep checkov`), but they are not part of the standard workstation setup because:

1. They are not wired into any pre-commit hook
2. Their primary enforcement point is the CI/CD pipeline
3. Adding them to the installer increases install time and maintenance surface without adding automated enforcement

## Tool Coverage Matrix

### Pre-commit Hooks (Automated on Every Commit/Push)

| Language / File Type | Hook | What it catches |
|---|---|---|
| Bash / Shell (`.sh`) | ShellCheck | Syntax errors, quoting bugs, unsafe patterns, deprecated constructs |
| Python (`.py`) | Ruff | PEP 8 violations, import sorting, type upgrades, security patterns (bandit-style), auto-formatting |
| TypeScript / JavaScript (`.ts`, `.js`, `.tsx`, `.jsx`) | ESLint | Type errors, unsafe patterns, style violations |
| Dockerfile | hadolint | Unpinned base images, missing `--no-install-recommends`, unsafe `RUN` patterns |
| YAML / Kubernetes manifests | yamllint | Syntax errors, formatting inconsistencies |
| Markdown (`.md`) | markdownlint | Heading structure, trailing whitespace, inconsistent list style |
| Terraform (`.tf`) | terraform fmt | Canonical formatting |
| Terraform (`.tf`) | terraform validate | Configuration validity, missing variables, type errors |
| `package-lock.json` | npm audit | Known critical/high npm dependency vulnerabilities |
| All files (pre-push) | Gitleaks | Hardcoded secrets, API keys, credentials |

### CLI Tools (On-Demand)

| Tool | Scan targets | Output formats |
|---|---|---|
| Trivy | Container images, filesystem deps, IaC, secrets | Table, JSON, SARIF, CycloneDX |
| Syft | Container images, directories, archives | CycloneDX-JSON, SPDX-JSON, Table |
| Grype | SBOMs, container images, directories | Table, JSON, CycloneDX |
| Gitleaks | Current files, full git history | Table, JSON, CSV |

## Data Flow

```
Developer writes code
        │
        ▼
   git commit
        │
        ├─► Tier 1 hooks fire (ShellCheck, Ruff, ESLint, hadolint,
        │   yamllint, markdownlint, npm audit, terraform fmt/validate)
        │
        ├─► Hooks pass → commit succeeds
        │   Hooks fail → commit blocked, developer fixes issues
        │
        ▼
   git push
        │
        ├─► Tier 2 hook fires (Gitleaks protect --staged)
        │
        ├─► No secrets found → push succeeds
        │   Secret found → push blocked, developer removes secret
        │
        ▼
   Code reaches remote
        │
        └─► CI/CD pipeline (Milestone 2) runs Semgrep, Checkov,
            Trivy, Grype, Gitleaks full-history scan
```

## Client-Side Enforcement Limitation

Pre-commit hooks run entirely on the developer workstation and can be bypassed:

- `git commit --no-verify` — skips all Tier 1 hooks
- `git push --no-verify` — skips the Gitleaks secrets gate

This is a fundamental property of client-side hooks, not a configuration gap. The enforcement model is defence-in-depth:

1. **Pre-commit/pre-push hooks** — fast inner loop, client-side, bypassable
2. **CI/CD security workflow** — server-side, non-bypassable (Milestone 2)
3. **Branch protection + required status checks** — prevents merge without passing CI

The workstation layer catches issues early and reduces CI feedback latency. The CI layer provides the actual enforcement guarantee.

## File Structure

```
workstation/
├── setup.sh                              # Bootstrap script — install, configure, activate
├── ARCHITECTURE.md                       # This document
├── README.md                             # Quick start and usage guide
└── cicd/
    ├── lint-markdown.sh                  # Three-tier markdown linting script
    └── pre-commit.sh                     # Pre-commit hook for staged .md files

Generated in each target repository by setup.sh:
├── versions.conf                         # Pinned tool versions (latest at time of generation)
├── .pre-commit-config.yaml               # Hook configuration (Tier 1 + Tier 2)
├── .gitleaksignore                       # Gitleaks false-positive suppressions
├── .markdownlint-cli2.yaml               # markdownlint-cli2 rule config
├── .markdownlint-fix.markdownlint.jsonc  # Auto-fixable rules
└── .markdownlint.jsonc                   # Enforced lint rules
```

## Version Pinning Strategy

All tools are pinned to exact versions for reproducible installations:

| Pinning mechanism | Scope | Update method |
|---|---|---|
| `versions.conf` (in repo root) | CLI tools installed by `setup.sh` | Delete and re-run `setup.sh install`, or edit manually |
| `rev:` fields in `.pre-commit-config.yaml` | Pre-commit hook tool versions | `pre-commit autoupdate` |

On first run, `setup.sh` resolves latest versions from GitHub. Subsequent runs use the existing `versions.conf` — delete it to force re-resolution.

Run `pre-commit autoupdate` monthly to bump hook versions, then `pre-commit run --all-files` to validate.

## Relationship to Other Milestones

| Milestone | Relationship to workstation |
|---|---|
| **M2 — CI/CD Security Gate** | Server-side enforcement; runs Semgrep, Checkov, Trivy, Grype, Gitleaks on every PR. Compensating control for client-side bypass. |
| **M3 — Self-Hosted Infrastructure** | Nexus proxy caches upstream packages; workstation package managers point at Nexus for audit and caching. |
| **M4 — Runtime Security** | No direct workstation interaction; Trivy Operator and Falco run in-cluster. |
