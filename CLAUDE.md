# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

This is a **reference documentation project** — not a buildable software project. It contains a single comprehensive Markdown document (`development-security-stack-option-1.md`) that serves as a complete blueprint for implementing a zero-cost, open-source security and supply chain scanning stack.

The target audience is a single-developer AWS cloud practice using Terraform, CDK, CloudFormation, Python, TypeScript/JavaScript, Bash, Kubernetes/YAML, and Docker.

## Architecture (Layered Security Stack)

The document describes a 4-phase implementation:

1. **Developer Workstation** — Pre-commit hooks (two tiers) + CLI tools. Tier 1 runs linters on every commit (ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint, terraform fmt/validate, npm audit). Tier 2 runs Gitleaks secrets detection before push. Trivy, Syft, and Grype are available on-demand via CLI.
2. **CI/CD Gate (GitHub Actions)** — PR-level scanning: Semgrep CE (SAST), Checkov (IaC), Trivy (containers), Grype+Syft (SCA), Gitleaks (full history). Outputs SARIF to GitHub Security tab and JSON for DefectDojo import.
3. **Self-Hosted K8s Infrastructure** — Nexus Repository CE (universal package proxy for npm, PyPI, Docker, Helm, Maven, Go, etc.) and DefectDojo (unified security dashboard with deduplication and lifecycle tracking).
4. **Runtime & Optional Enhancements** — Trivy Operator (continuous K8s scanning), SonarQube Community (code quality), Harbor (container registry with scan-on-push).

Key design decisions:
- SAST/IaC scanning intentionally deferred to CI/CD (not pre-commit) to reduce developer friction
- Gitleaks is the only security scanner in pre-commit (Tier 2)
- All 22+ tools are open-source, free, require no external accounts

## Working With This Document

The Markdown file (~1,500 lines) contains complete, copy-pasteable configurations including:
- `.pre-commit-config.yaml` template
- `.github/workflows/security.yml` GitHub Actions workflow
- DefectDojo import scripts
- Tool installation commands for all platforms
- Kubernetes/Helm deployment specs with CPU/memory estimates

When editing, preserve the ASCII architecture diagrams and the document's phased structure. Tool coverage matrices and the security tools comparison table are key reference sections.
