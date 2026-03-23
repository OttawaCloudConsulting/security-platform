# Security & Supply Chain Scanning Stack

## What This Is

A zero-cost, open-source security and supply chain scanning stack for a single-developer AWS cloud practice. Covers the full development lifecycle — workstation linting and secrets detection, CI/CD security gates, Kubernetes-hosted artifact management and vulnerability dashboards, infrastructure hardening, and runtime security. All tools are free, self-hosted, and require no external accounts or logins.

## Core Value

Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production — with zero ongoing cost and zero vendor lock-in.

## Requirements

### Validated

- [x] Pre-commit Tier 1: quality and linting hooks (ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint, npm audit, terraform fmt/validate) on every commit
- [x] Pre-commit Tier 2: Gitleaks secrets detection on every push
- [x] Security CLI tool suite: Trivy, Syft, Grype, Semgrep CE, Checkov, Gitleaks installed and functional

### Active

- [ ] Version check and update capability (`--check`, `--update`, `--doctor` commands)

### Validated (v1.1)

- [x] Cross-platform tool installation script (replaces Homebrew with pipx/binary downloads)
- [x] Distribution package: setup.sh command for fresh git repos (install + configure + activate)
- [x] Distribution drops all config files (pre-commit, linting, secrets detection)
- [x] Hooks use file-pattern matching for selective execution (universal config, language-aware)
- [x] Setup script is idempotent and bash 3.2 compatible (macOS stock bash)

### Future (M2+)

- [ ] GitHub Actions security workflow: 5 parallel scan jobs (SAST, IaC, SCA, container, secrets) on every PR
- [ ] SARIF upload to GitHub Security tab for PR visibility
- [ ] JSON artifact retention for downstream DefectDojo import
- [ ] Branch protection enforcement: failing scans block merge, direct pushes blocked
- [ ] Dependabot for GitHub Actions SHA digest updates
- [ ] Nexus Repository proxy deployment on Kubernetes (npm, PyPI, Docker, Helm)
- [ ] Workstation package managers routed through Nexus
- [ ] DefectDojo unified security dashboard on Kubernetes
- [ ] CI-to-DefectDojo automated import pipeline
- [ ] Deduplication and triage workflow configuration
- [ ] Checkov baseline for existing repos (only new findings flagged)
- [ ] NetworkPolicy namespace isolation for all security services
- [ ] TLS via cert-manager for all internal service communication
- [ ] Backup automation for stateful services (DefectDojo PostgreSQL, Nexus PVC)
- [ ] Monitoring and alerting via kube-prometheus-stack
- [ ] Version update process for all tools and Helm charts
- [ ] Trivy Operator for continuous K8s workload scanning
- [ ] Falco CE + FalcoSidekick for runtime anomaly detection
- [ ] Cosign keyless image signing in CI
- [ ] Kyverno admission control rejecting unsigned images

### Out of Scope

- SonarQube Community Build — optional enhancement, deferred to M7 if desired
- Harbor Container Registry — optional enhancement, deferred to M7 if desired
- Commit signing — optional enhancement, deferred to M7 if desired
- Multi-developer RBAC or team access controls — single-developer practice
- Paid tools or SaaS subscriptions — zero-cost constraint
- Production Kubernetes workload deployment — this stack secures the development pipeline, not the application runtime

## Current Milestone: v1.1 Distribution Packaging

**Goal:** Replace Homebrew-based tool installation with cross-platform methods (pip/npm/binary) and create a distribution package that sets up security tooling in any fresh git repo with a single command.

**Status:** 75% complete (3 of 4 phases done)

**Completed:**
- [x] Cross-platform install script — macOS + Linux, no Homebrew, version-pinned via manifest
- [x] File-pattern hook configuration — explicit `types:`/`files:` filters on every hook for universal config
- [x] Repo setup script — `setup.sh` copies configs + wires hooks in any git repo, idempotent, bash 3.2 compatible

**Remaining:**
- [ ] Maintenance and validation — `--check`, `--update`, and `--doctor` commands for installed tools

## Context

- **Deployment model:** Single developer, personal AWS cloud practice with 6+ GitHub repositories
- **Existing infrastructure:** Kubernetes cluster already running (non-EKS), kubectl configured
- **Current security tooling:** M1 complete — pre-commit hooks and CLI tools working on 2 repos via Homebrew
- **Rollout strategy:** v1.1 produces the distribution package; remaining repos onboard via that package
- **Reference document:** `docs/development-security-stack-option-1.md` (~2,300 lines) contains all tool configs, architecture diagrams, and copy-pasteable configurations
- **Milestone plans:** `docs/milestone-plan/` contains 7 detailed milestone documents with 28 features, done criteria, and verification checks
- **ADRs:** `docs/adr/` contains 14 architectural decision records (ADR-001 through ADR-014)
- **Languages covered:** Terraform, CDK, CloudFormation, Python, TypeScript/JavaScript, Bash, Kubernetes/YAML, Docker
- **GSD approach:** One GSD milestone at a time

## Constraints

- **Cost:** $0 — all tools must be free and open-source with no external account requirements
- **Self-hosted:** Everything runs locally or on the developer's own Kubernetes cluster
- **Single developer:** No team coordination overhead; tooling optimized for solo workflow
- **Milestone ordering:** M1 -> M2 -> M4 -> M5 -> M6 is the critical path; M3 (Nexus) can run in parallel with M1/M2 once K8s is available

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| One GSD milestone per implementation milestone | Keeps focus tight; each milestone produces a usable capability increment | Validated (M1 complete) |
| Start with one repo, then roll out | Validate the tooling works before applying to all repos | Validated (M1 complete) |
| Milestone verification checks as done criteria | The milestone docs already have thorough verification sections | Validated (M1 complete) |
| M7 features (SonarQube, Harbor, commit signing) deferred | Optional enhancements, not required for core security program | -- Pending |
| Replace Homebrew with cross-platform install methods | Portability across macOS and Linux; single install path | Validated (Phase 10) |
| Distribution package for repo onboarding | Low-touch rollout to remaining 4+ repos | Validated (Phase 12) |
| Explicit type/file filters on all hooks | Universal config works across all repo types | Validated (Phase 11) |
| Bash 3.2 compatibility | macOS ships bash 3.2 permanently (GPLv3 licensing) | Validated (Phase 12) |

---
*Last updated: 2026-03-22 after Phase 12 completion*
