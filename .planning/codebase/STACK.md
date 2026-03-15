# Technology Stack

**Analysis Date:** 2026-03-15

## Languages

**Primary:**
- Python - Used for security scanning tools (Semgrep, Checkov, Trivy, Syft, Grype, Ruff)
- Bash/Shell - Infrastructure scripts, CI/CD orchestration
- TypeScript/JavaScript - Application development and linting (ESLint)
- Terraform/HCL - Infrastructure as Code for AWS cloud practice
- YAML - Kubernetes manifests, Helm values, GitHub Actions workflows
- Dockerfile - Container image definitions

**Secondary:**
- Go - For go modules scanning and Terraform provider proxying
- Markdown - Documentation (primary artifact is `docs/development-security-stack-option-1.md`)
- JSON/SARIF - Output formats for security scanning tools

## Runtime

**Environment:**
- Kubernetes (self-hosted cluster) - Primary deployment target for security services
- GitHub Actions - CI/CD execution environment (free GitHub-hosted runners)
- Docker - Containerization for all services (Nexus, DefectDojo, SonarQube, Harbor, Trivy Operator, Falco, Cosign)

**Package Managers:**
- `pip` - Python package management (points to Nexus PyPI proxy)
- `npm` - JavaScript/Node.js package management (points to Nexus npm proxy)
- `helm` - Kubernetes package manager for service deployments
- `docker` - Container image registry (points to Nexus Docker proxy)
- `go get` - Go module management (points to Nexus Go proxy)

**Lockfiles:**
- `package.json`/`package-lock.json` or equivalent for npm projects
- Python `requirements.txt` or `pyproject.toml` for pip projects
- Helm `Chart.yaml` and `values.yaml` for Kubernetes services
- Git `git-crypt` or similar for secrets management (if needed)

## Frameworks

**Core Runtime:**
- Kubernetes (K8s 1.25+) with YAML manifests - Container orchestration and workload management
- Helm 3+ - Kubernetes package management and service deployment

**Security/Scanning Frameworks:**
- Semgrep CE - SAST (Static Application Security Testing) pattern-based engine
- Checkov - Infrastructure as Code scanning with 1,000+ policies
- Trivy - Multi-scanner (container images, IaC, filesystems, secrets, SBOM)
- Syft - SBOM generation (CycloneDX and SPDX formats)
- Grype - Vulnerability scanning of SBOMs and source
- Gitleaks - Secrets detection and prevention
- Trivy Operator - Kubernetes-native runtime vulnerability scanning
- Falco CE - Kubernetes runtime anomaly detection
- Cosign - Container image signing and verification (keyless with GitHub OIDC)

**Infrastructure Management:**
- Terraform - IaC for AWS deployments
- AWS CDK - Alternative IaC for CloudFormation synthesis
- CloudFormation - AWS infrastructure templates
- pre-commit - Git hook framework for Tier 1 & 2 validation

**Linting & Formatting:**
- ShellCheck - Bash/shell script linting
- Ruff - Python linting and formatting (replaces flake8, black, isort)
- ESLint - JavaScript/TypeScript linting
- hadolint - Dockerfile linting
- yamllint - YAML/Kubernetes manifest linting
- markdownlint - Markdown documentation linting
- Terraform fmt/validate - Built-in Terraform formatting and validation

**Dashboard & Aggregation:**
- DefectDojo - Unified vulnerability management dashboard with API ingestion
- SonarQube Community Build (optional) - Code quality metrics and quality gates
- Prometheus + Grafana (optional via kube-prometheus-stack) - Metrics and monitoring

**Package & Artifact Management:**
- Nexus Repository Community Edition 3.77.0+ - Universal package repository (npm, PyPI, Docker, Helm, Maven, Go, NuGet, RubyGems, Apt, Yum)
- Harbor (CNCF, optional) - Container-specific registry with scan-on-push and image signing

## Key Dependencies

**Critical Infrastructure:**
- `docker` (client + daemon) - Container runtime for local scanning and service execution
- `kubectl` - Kubernetes client for cluster management
- `helm 3+` - Kubernetes package manager
- `git` + `pre-commit` - Version control and hook orchestration
- `postgresql` - Database backend for DefectDojo and optional SonarQube/Harbor

**Scanning & Security Tools:**
- `semgrep` - SAST scanning (pip install semgrep or brew install semgrep)
- `checkov` - IaC scanning (pip install checkov)
- `trivy` - Multi-scanner (brew install trivy or curl-based binary install)
- `syft` - SBOM generation (curl-based binary install or brew)
- `grype` - Vulnerability scanning (curl-based binary install or brew)
- `gitleaks` - Secrets detection (pre-commit framework integration)
- `kyverno` - Kubernetes policy as code and admission control (Helm)
- `slsa-github-generator` - SLSA Level 2 provenance attestations (GitHub Actions)

**Build & Development Tools:**
- `aws-cdk` or `terraform` - Infrastructure provisioning
- `npm audit` - Fast JavaScript dependency scanning
- Node.js + npm (for JavaScript/TypeScript projects)
- Python 3.9+ (for Python scanning tools and projects)

**Monitoring & Observability (Optional):**
- `prometheus-operator` via `kube-prometheus-stack` - Metrics collection and alerting
- `prometheus` - Metrics server
- `grafana` - Metrics visualization
- `alertmanager` - Alert routing

## Configuration

**Environment:**
- GitHub Secrets for sensitive configuration:
  - `DEFECTDOJO_API_TOKEN` - DefectDojo API authentication
  - Other service credentials (Nexus, Harbor, SonarQube)
- Kubernetes Secrets for in-cluster service authentication
- Environment variables for configuration flags (e.g., `SEMGREP_CONFIG`, scan filters)

**Build Configuration:**
- `.github/workflows/security.yml` - Primary GitHub Actions security workflow
- `.pre-commit-config.yaml` - Pre-commit hook definitions (Tier 1 & 2)
- `helm/values.yaml` (per service) - Helm deployment configuration
  - `defectdojo-values.yaml`
  - `nexus-values.yaml`
  - `sonarqube-values.yaml` (optional)
  - `harbor-values.yaml` (optional)
  - `trivy-operator-values.yaml`
  - `falco-values.yaml`
  - `kyverno-values.yaml`
- `docker-compose.yml` or Kubernetes YAML for local service deployments
- `.semgrep/custom-rules.yml` - Custom SAST rules (optional)
- `.checkov.baseline` - Checkov baseline for suppressing known findings (optional)

**Package Manager Configs:**
- `.npmrc` - npm registry configuration (points to Nexus)
- `~/.config/pip/pip.conf` - pip registry configuration (points to Nexus)
- `/etc/docker/daemon.json` - Docker daemon configuration (insecure-registries for Nexus during bootstrap)
- `.gitignore` - Excludes scanning artifacts from git

## Platform Requirements

**Development:**
- Linux, macOS, or Windows (WSL2) workstation
- 8GB+ RAM (for container runtime and services)
- 50GB+ disk space (for cached packages in Nexus)
- Docker Desktop or Docker Engine
- kubectl and helm installed
- Git client with pre-commit framework
- Python 3.9+ (for pip install scanning tools)
- Bash/shell environment

**Production (Kubernetes Cluster):**
- Kubernetes 1.25+ cluster (self-hosted or managed)
- Persistent storage (PVC) for:
  - Nexus blob store (`/nexus-data`)
  - DefectDojo PostgreSQL data
  - SonarQube data (optional)
  - Harbor registry storage (optional)
- Load balancer or Ingress controller for service access
- Egress access to upstream registries:
  - `registry.npmjs.org` (npm)
  - `pypi.org` (Python)
  - `registry-1.docker.io` (Docker Hub)
  - `charts.helm.sh` (Helm)
  - `registry.terraform.io` (Terraform)
  - `proxy.golang.org` (Go modules)
- OIDC integration with GitHub (for Cosign keyless signing)
- TLS certificates (recommended via cert-manager)

**CI/CD:**
- GitHub repository with GitHub Actions enabled
- GitHub Advanced Security (optional, for native CodeQL on private repos)
- Ability to configure branch protection rules

## Deployment Model

**Zero-Cost, Zero-External-Accounts:**
- All tools are open-source and free
- No SaaS subscriptions or third-party accounts required
- All services run self-hosted on Kubernetes or locally
- GitHub Actions runs on free GitHub-hosted runners

**Architecture Tiers:**
1. **Workstation (Tier 1 & 2 pre-commit)** - ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint, npm audit, tf fmt/val, Gitleaks
2. **CI/CD (GitHub Actions PR Gate)** - Semgrep, Checkov, Trivy, Syft+Grype, Gitleaks (full history), SARIF upload
3. **Kubernetes Infrastructure (Self-Hosted Services)** - Nexus, DefectDojo, SonarQube, Harbor, Trivy Operator, Falco, Kyverno
4. **Runtime (K8s Workloads)** - Signed container images, Pod Security policies, Falco anomaly detection

---

*Stack analysis: 2026-03-15*
