# Requirements: Security & Supply Chain Scanning Stack — M1

**Defined:** 2026-03-15
**Core Value:** Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production — with zero ongoing cost and zero vendor lock-in.

## v1 Requirements

### Pre-commit Framework

- [x] **PCOM-01**: Developer can install pre-commit framework via `pip install pre-commit` or `brew install pre-commit`
- [x] **PCOM-02**: `.pre-commit-config.yaml` is committed to the target repository root with all Tier 1 and Tier 2 hooks configured
- [x] **PCOM-03**: `pre-commit install` activates hooks in the target repository
- [ ] **PCOM-04**: `pre-commit run --all-files` passes cleanly (all existing issues resolved or suppressed)

### Tier 1 — Quality & Linting Hooks

- [x] **LINT-01**: ShellCheck hook catches unquoted variables and shell script issues on every commit
- [x] **LINT-02**: Ruff hook auto-fixes Python formatting violations and flags linting errors on every commit
- [x] **LINT-03**: ESLint hook flags TypeScript/JavaScript linting issues on every commit
- [x] **LINT-04**: hadolint hook flags Dockerfile best practice violations on every commit
- [x] **LINT-05**: yamllint hook flags YAML/Kubernetes manifest formatting issues on every commit
- [x] **LINT-06**: markdownlint hook flags Markdown style issues on every commit
- [x] **LINT-07**: npm audit hook runs lightweight dependency audit when package-lock.json changes
- [x] **LINT-08**: terraform fmt hook auto-formats HCL files on every commit
- [x] **LINT-09**: terraform validate hook checks HCL syntax on every commit

### Tier 2 — Secrets Gate

- [x] **SECR-01**: Gitleaks hook runs in `protect --staged` mode on every push (pre-push hook)
- [x] **SECR-02**: A commit containing a dummy AWS key pattern (e.g., `AKIAIOSFODNN7EXAMPLE`) is blocked by Gitleaks
- [x] **SECR-03**: Developer understands `--no-verify` bypass and that CI is the compensating control (per ADR-011)

### Security CLI Tools

- [ ] **TOOL-01**: Trivy is installed and on `$PATH` (`trivy --version` succeeds), version >= 0.69.2
- [ ] **TOOL-02**: Syft is installed and on `$PATH` (`syft version` succeeds)
- [ ] **TOOL-03**: Grype is installed and on `$PATH` (`grype version` succeeds), version >= 0.88.0
- [ ] **TOOL-04**: Semgrep CE is installed and on `$PATH` (`semgrep --version` succeeds)
- [ ] **TOOL-05**: Checkov is installed and on `$PATH` (`checkov --version` succeeds)
- [ ] **TOOL-06**: Gitleaks is installed and on `$PATH` (`gitleaks version` succeeds)
- [ ] **TOOL-07**: Each tool can run a basic scan against the local repository without errors
- [ ] **TOOL-08**: Each tool can generate a JSON report (needed for M2 CI and M4 DefectDojo import)

## v2 Requirements

### CI/CD Security Gate (M2)

- **CICD-01**: GitHub Actions security workflow with 5 parallel scan jobs
- **CICD-02**: SARIF upload to GitHub Security tab
- **CICD-03**: JSON artifact retention for DefectDojo import
- **CICD-04**: Branch protection enforcement
- **CICD-05**: Dependabot for Actions SHA updates

### Nexus Repository (M3)

- **NEXS-01**: Nexus deployment on Kubernetes
- **NEXS-02**: Proxy repository creation (npm, PyPI, Docker, Helm)
- **NEXS-03**: Workstation package manager configuration

### DefectDojo (M4)

- **DOJO-01**: DefectDojo deployment on Kubernetes
- **DOJO-02**: Product and engagement configuration
- **DOJO-03**: CI-to-DefectDojo import automation
- **DOJO-04**: Deduplication and triage configuration
- **DOJO-05**: Checkov baseline for existing repos

### Infrastructure Hardening (M5)

- **HARD-01**: NetworkPolicy isolation
- **HARD-02**: TLS via cert-manager
- **HARD-03**: Backup automation
- **HARD-04**: Monitoring and alerting
- **HARD-05**: Version update process

### Runtime Security (M6)

- **RUNT-01**: Trivy Operator deployment
- **RUNT-02**: Falco CE + FalcoSidekick deployment
- **RUNT-03**: Cosign keyless image signing in CI
- **RUNT-04**: Kyverno admission control

### Optional Enhancements (M7)

- **OPTL-01**: SonarQube Community Build
- **OPTL-02**: Harbor Container Registry
- **OPTL-03**: Commit signing

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-repo rollout automation | M1 targets one repo; rollout is a follow-up task after validation |
| SAST/IaC scanning in pre-commit | Creates friction without proportional value; CI is the right layer (per project architecture) |
| Paid tools or SaaS dependencies | Zero-cost constraint — all tools must be free and open-source |
| Custom Semgrep rules | Default rulesets are sufficient for M1; custom rules can be added later |
| IDE integration (SonarLint, etc.) | Deferred to M7 (SonarQube optional enhancement) |
| Inter-file dataflow SAST (CodeQL) | Semgrep CE covers single-file patterns; CodeQL is free for public repos but adds complexity |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PCOM-01 | Phase 1 | Complete |
| PCOM-02 | Phase 1 | Complete |
| PCOM-03 | Phase 1 | Complete |
| PCOM-04 | Phase 9 | Pending |
| LINT-01 | Phase 2 | Complete |
| LINT-02 | Phase 2 | Complete |
| LINT-03 | Phase 3 | Complete |
| LINT-04 | Phase 3 | Complete |
| LINT-05 | Phase 3 | Complete |
| LINT-06 | Phase 3 | Complete |
| LINT-07 | Phase 4 | Complete |
| LINT-08 | Phase 4 | Complete |
| LINT-09 | Phase 4 | Complete |
| SECR-01 | Phase 5 | Complete |
| SECR-02 | Phase 5 | Complete |
| SECR-03 | Phase 5 | Complete |
| TOOL-01 | Phase 6 | Pending |
| TOOL-02 | Phase 6 | Pending |
| TOOL-03 | Phase 6 | Pending |
| TOOL-04 | Phase 7 | Pending |
| TOOL-05 | Phase 7 | Pending |
| TOOL-06 | Phase 7 | Pending |
| TOOL-07 | Phase 8 | Pending |
| TOOL-08 | Phase 8 | Pending |

**Coverage:**
- v1 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0

---
*Requirements defined: 2026-03-15*
*Last updated: 2026-03-15 after roadmap creation*
