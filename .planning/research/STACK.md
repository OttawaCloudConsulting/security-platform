# Stack Research

**Domain:** Zero-cost, self-hosted developer security and supply chain scanning toolchain
**Researched:** 2026-03-15
**Confidence:** HIGH

## Recommended Stack

The reference document (`docs/development-security-stack-option-1.md`) already contains well-researched, opinionated tool selections. This research validates those choices against current 2026 ecosystem state, confirms versions, and flags any changes since the document was written.

### Core Security Scanners

| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| **Semgrep CE** | 1.155.0 | SAST (static application security testing) | Pattern-based, fast, 3x faster with multicore (Fall 2025 release). LGPL-2.1, no account needed. Covers Python, TS/JS, HCL, YAML, Dockerfile. Intra-file dataflow analysis is sufficient for single-dev practice. | HIGH |
| **Checkov** | 3.2.508 | IaC scanning (Terraform, CFN, CDK, K8s, Dockerfile, GHA workflows) | 1,000+ built-in policies with graph-based cross-resource analysis. Apache 2.0. Baseline workflow suppresses pre-existing findings. Owned by Palo Alto/Prisma Cloud but remains fully open-source. | HIGH |
| **Trivy** | 0.69.3 | Container image scanning, filesystem vuln scanning, IaC misconfiguration, secrets, SBOM generation | Swiss army knife from Aqua Security. Absorbed tfsec. Apache 2.0. Single binary covers container + filesystem + IaC + secrets. Offline mode available. | HIGH |
| **Syft** | 1.42.2 | SBOM generation (CycloneDX, SPDX) | Purpose-built SBOM generator from Anchore. Covers 30+ packaging ecosystems. Apache 2.0. Richer SBOM output than Trivy alone. | HIGH |
| **Grype** | 0.109.1 | SCA vulnerability scanning | Scans SBOMs or targets directly. Now includes CISA KEV and EPSS data for prioritization. DB schema v6 (v5 EOL was March 6, 2026 -- must use Grype >= 0.88.0). Apache 2.0. | HIGH |
| **Gitleaks** | 8.24+ | Secrets detection (current files + full git history) | MIT. Purpose-built, fast. v8.28+ adds composite rules for better accuracy. Runs as pre-push hook and in CI. | HIGH |

### Kubernetes-Hosted Services

| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| **DefectDojo** | 2.x (latest stable) | Unified vulnerability management dashboard | 200+ scanner parsers, cross-tool deduplication, finding lifecycle, SLA tracking, REST API for CI import. BSD-3. The aggregation layer that makes multi-scanner output actionable. | HIGH |
| **Nexus Repository CE** | 3.90.x | Universal artifact proxy/cache (npm, PyPI, Docker, Helm) | EPL-1.0. Since v3.77.0, CE gained Docker/npm/PyPI format support and K8s PostgreSQL deployment. Single audit point for all upstream package traffic. Note: CE has 40K component / 100K request daily limits -- sufficient for single-dev. | HIGH |
| **Trivy Operator** | 0.32.x (Helm chart) | Continuous K8s workload vulnerability scanning | Produces VulnerabilityReports and ConfigAuditReports as K8s CRDs. Results exportable to DefectDojo. Apache 2.0. | HIGH |
| **Falco CE** | 0.43.0 | Runtime anomaly detection (eBPF-based syscall monitoring) | CNCF Graduated. Detects container escapes, unexpected process execution, privilege escalation. Legacy eBPF probe deprecated in 0.43 -- use modern eBPF driver. Apache 2.0. | HIGH |
| **FalcoSidekick** | latest | Alert routing for Falco (Slack, webhook, web UI) | Decouples Falco detection from alerting. Web UI at port 2802 for visual review. Deployed via Falco Helm chart. | HIGH |
| **Kyverno** | 1.17.1 | Kubernetes admission control (image signature verification) | CNCF project. CEL engine promoted to v1 in 1.17. ClusterPolicy deprecated (still functional) in favor of CEL-based policies. Enforces Cosign-signed images. Apache 2.0. | HIGH |

### Infrastructure Support

| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| **cert-manager** | 1.20.0 | Automated TLS certificate management in K8s | CNCF project. Automates Let's Encrypt or self-signed CA cert issuance. Required for TLS between security services. | HIGH |
| **kube-prometheus-stack** | 82.10.x (Helm) | Monitoring and alerting (Prometheus + Grafana + Alertmanager) | Community Helm chart. Includes Grafana dashboards, Prometheus rules, and Alertmanager. The standard K8s monitoring stack. | HIGH |
| **Cosign** | 3.0.5 | Keyless container image signing (Sigstore) | v3 makes standardized bundle format and OCI 1.1 referring artifacts default. Keyless via GitHub OIDC -- no key management. Apache 2.0. | HIGH |

### Pre-commit Linting Layer

| Tool | Version | Purpose | Why Recommended | Confidence |
|------|---------|---------|-----------------|------------|
| **pre-commit** | 4.5.x | Hook orchestration framework | Python-based, multi-language hook runner. MIT. Dependabot now supports pre-commit hooks (March 2026). | HIGH |
| **Ruff** | 0.15.x | Python linting + formatting | Replaces flake8, black, isort, pylint. 10-100x faster (Rust). 800+ rules. 2026 style guide support in 0.15.0. MIT. | HIGH |
| **ESLint** | 9.x | TypeScript/JavaScript linting | Flat config format (eslint.config.mjs) is now the default. Used for CDK TypeScript projects. MIT. | HIGH |
| **ShellCheck** | 0.10.x | Bash/shell script static analysis | The authoritative shell linter. GPL-3.0. Covers quoting bugs, deprecated constructs, unsafe patterns. | HIGH |
| **hadolint** | 2.12.0 | Dockerfile linting | ShellCheck-powered RUN instruction analysis + Docker best practices. GPL-3.0. | MEDIUM |
| **yamllint** | 1.35.x | YAML syntax and style validation | Covers K8s manifests, Helm values, GHA workflows. MIT. | HIGH |
| **markdownlint-cli** | 0.43.x | Markdown style linting | MIT. Style tool, not security. | HIGH |

### CI/CD Platform

| Technology | Purpose | Why Recommended | Confidence |
|------------|---------|-----------------|------------|
| **GitHub Actions** | Primary CI/CD runner | 5 parallel scan jobs (SAST, IaC, SCA, container, secrets). SARIF upload to Security tab. SHA-pinned actions with Dependabot updates. Free tier sufficient for single-dev. | HIGH |
| **Dependabot** | GitHub Actions SHA digest updates | Automates keeping pinned action SHAs current. Monthly schedule. | HIGH |

## Installation

```bash
# === Workstation CLI Tools (macOS via Homebrew) ===
brew install trivy syft grype gitleaks shellcheck hadolint cosign

# Python tools
pip install semgrep checkov ruff yamllint pre-commit --break-system-packages

# Node tools (project-local)
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
npm install -g markdownlint-cli

# Pre-commit setup
pre-commit install
pre-commit run --all-files

# === Kubernetes Services (Helm) ===
# Add chart repos
helm repo add defectdojo https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts
helm repo add sonatype https://sonatype.github.io/helm3-charts/
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo add falco https://falcosecurity.github.io/charts
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install services (each into its own namespace)
helm install nexus sonatype/nexus-repository-manager --namespace nexus --create-namespace
helm install defectdojo defectdojo/defectdojo --namespace defectdojo --create-namespace -f defectdojo-values.yaml
helm install trivy-operator aqua/trivy-operator --namespace trivy-system --create-namespace
helm install falco falco/falco --namespace falco-system --create-namespace -f falco-values.yaml
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace -f kyverno-values.yaml
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Semgrep CE | CodeQL | CodeQL is more powerful for deep dataflow analysis but requires GitHub Advanced Security (paid for private repos) or complex self-hosted setup. Use CodeQL if you later need inter-file taint tracking. |
| Checkov | tfsec | tfsec was absorbed into Trivy. Checkov has deeper graph-based analysis. No reason to use standalone tfsec in 2026. |
| Grype + Syft | Snyk Open Source | Snyk has scan limits on free tier and requires account. Grype now includes KEV + EPSS data. Use Snyk only if mandated by client compliance. |
| Gitleaks | TruffleHog | TruffleHog CE is viable but Gitleaks has simpler pre-commit integration and MIT license. TruffleHog has stronger verified secrets feature in paid tier. |
| DefectDojo | Dependency-Track | Dependency-Track is SCA-focused only (SBOM ingestion). DefectDojo aggregates all scanner types (200+ parsers). Use Dependency-Track only if you need SBOM-centric workflow exclusively. |
| Nexus CE | JFrog Artifactory OSS | Artifactory OSS supports fewer formats. Nexus CE since v3.77.0 covers Docker/npm/PyPI. Use Artifactory only if you need Maven-centric advanced features. |
| Falco | Tetragon | Tetragon (Cilium/Isovalent) is eBPF-based like Falco but more network-flow focused. Falco is CNCF Graduated with richer syscall rule ecosystem. Use Tetragon if already running Cilium CNI. |
| Kyverno | OPA Gatekeeper | Gatekeeper uses Rego (steeper learning curve). Kyverno uses YAML/CEL policies (simpler). Kyverno 1.17 CEL engine is production-ready. Use Gatekeeper only if you already have Rego policies. |
| Cosign (keyless) | Notation (CNCF) | Notation is the CNCF signing standard but has less ecosystem adoption than Sigstore/Cosign. Kyverno supports both. Use Notation if mandated by enterprise policy. |
| kube-prometheus-stack | Datadog/New Relic | Paid SaaS -- violates zero-cost constraint. kube-prometheus-stack is the community standard for self-hosted K8s monitoring. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **tfsec (standalone)** | Absorbed into Trivy in 2024. No longer maintained separately. | Checkov (primary IaC) + Trivy config (secondary) |
| **Snyk (free tier)** | Requires account, has scan limits, telemetry. Paid tier creep. Violates zero-cost/no-account constraint. | Semgrep CE + Grype + Trivy |
| **flake8 / black / isort** | Ruff replaces all three in a single tool, 10-100x faster. | Ruff |
| **pylint** | Slow, complex configuration. Ruff covers most pylint rules. | Ruff with `select = ["PL"]` |
| **Grype < 0.88.0** | DB schema v5 reached EOL on March 6, 2026. No more vulnerability database updates. | Grype >= 0.88.0 (current: 0.109.1) |
| **SonarQube (as sole SAST)** | Heavy service (2Gi+ RAM). Community Build is single-branch only, no PR decoration. | Semgrep CE for SAST + DefectDojo for aggregation. SonarQube optional for code quality metrics only. |
| **Harbor (as primary registry)** | OCI-only -- no npm/PyPI/Helm proxy. Heavy resource footprint. | Nexus CE for universal proxy. Harbor optional for scan-on-push container workflow (M7). |
| **Kyverno ClusterPolicy (YAML-based)** | Deprecated in v1.17. Still functional but removal scheduled. | Kyverno CEL-based ValidatingPolicy (v1 in 1.17) |
| **Falco kernel module driver** | Legacy eBPF probe deprecated in 0.43. Kernel module requires host-level privileges. | Falco modern eBPF driver (`driver.kind: modern_ebpf`) |
| **Docker Compose for K8s services** | Reference document includes Docker Compose as fallback, but all services target K8s. Docker Compose adds operational divergence. | Helm charts for all K8s services -- single deployment method. |

## Stack Patterns by Variant

**If deploying to a resource-constrained cluster (< 8 Gi RAM):**
- Deploy Nexus + DefectDojo first (M3, M4) -- they are the highest-value K8s services
- Defer Falco (DaemonSet overhead per node) and kube-prometheus-stack to M5/M6
- Use Trivy Operator with `--set operator.scanJobTTL=5m` to limit concurrent scan pod memory

**If Nexus CE hits the 40K component limit:**
- This is unlikely for a single-dev practice with < 10 repositories
- If hit, Nexus CE pauses new component additions but continues serving cached content
- Mitigation: prune old cached components via Nexus cleanup policies (Admin > System > Cleanup Policies)
- Escalation: Nexus Pro or switch container proxy to Harbor (which has no component limit for OCI artifacts)

**If the K8s cluster uses Cilium CNI:**
- Kyverno still works normally alongside Cilium
- Consider Tetragon for runtime security instead of Falco (same eBPF foundation, tighter Cilium integration)
- NetworkPolicies should use CiliumNetworkPolicy CRDs for L7 filtering

**If you later need multi-repo rollout (6+ repos):**
- Pre-commit config: create a shared `.pre-commit-config.yaml` in a template repo, then symlink or copy
- GHA workflow: use a reusable workflow in a `.github` org-level repo
- DefectDojo: one Product per repo, one Engagement per CI run, auto-create via API

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Grype >= 0.88.0 | DB schema v6 | v5 EOL was 2026-03-06. Older Grype versions stop receiving vuln DB updates. |
| Kyverno 1.17.x | Cosign v2 and v3 attestations | Cosign v3 support coming in next Kyverno release; v2 keyless works now. |
| Trivy 0.69.x | Trivy Operator 0.32.x | Operator embeds Trivy scanner. Operator version must match or trail Trivy version. |
| Checkov 3.x | checkov-action v12 | GHA action wraps pip-installed Checkov. Pin action to specific SHA. |
| Semgrep 1.155.x | Pre-commit via pip | Semgrep pre-commit hook exists but is deliberately NOT used (runs in CI instead). |
| Falco 0.43.x | FalcoSidekick (bundled in Helm) | Use `falcosidekick.enabled: true` in Falco Helm values. |
| cert-manager 1.20.x | Kubernetes 1.26+ | Check cert-manager supported K8s version matrix before upgrading. |
| kube-prometheus-stack 82.x | Kubernetes 1.26+ | Includes Prometheus 3.x, Grafana 11.x, Alertmanager 0.28.x. |
| pre-commit 4.5.x | Python 3.9+ | Requires Python 3.9+. Uses `pre-commit autoupdate` for hook version bumps. |

## Key Version Warnings

1. **Grype DB v5 EOL (2026-03-06):** If any CI runner or workstation has Grype < 0.88.0, it silently stops receiving vulnerability updates. Update immediately.
2. **Kyverno ClusterPolicy deprecation (1.17):** Existing YAML-based ClusterPolicies still work but plan migration to CEL-based ValidatingPolicy before Kyverno 1.18+.
3. **Trivy security incident (2026-03-01):** GitHub Actions supply chain attack affected Trivy. Resolved in v0.69.2+. Pin to v0.69.3 or later. Always SHA-pin the `aquasecurity/trivy-action` in workflows.
4. **Nexus CE component limits:** 40K components / 100K daily requests. Monitor usage via Nexus System > Status. Sufficient for single-dev but worth knowing.

## Sources

- [Trivy GitHub Releases](https://github.com/aquasecurity/trivy/releases) -- v0.69.3 confirmed, security incident noted (HIGH confidence)
- [Semgrep PyPI](https://pypi.org/project/semgrep/) -- v1.155.0 confirmed (HIGH confidence)
- [Semgrep CE Fall 2025 Release](https://semgrep.dev/blog/2025/semgrep-community-edition-fall-release-2025/) -- multicore support, Windows native (HIGH confidence)
- [Checkov GitHub Releases](https://github.com/bridgecrewio/checkov/releases) -- v3.2.508 confirmed (HIGH confidence)
- [Grype GitHub Releases](https://github.com/anchore/grype/releases) -- v0.109.1 confirmed, DB v5 EOL noted (HIGH confidence)
- [Grype DB Schema EOL Announcement](https://anchorecommunity.discourse.group/t/grype-db-schema-v5-will-be-eol-on-march-6-2026/591) -- v5 EOL 2026-03-06 (HIGH confidence)
- [Syft GitHub Releases](https://github.com/anchore/syft/releases) -- v1.42.2 confirmed (HIGH confidence)
- [Gitleaks GitHub Releases](https://github.com/gitleaks/gitleaks/releases) -- v8.24+ confirmed, composite rules in v8.28 (MEDIUM confidence)
- [DefectDojo GitHub](https://github.com/DefectDojo/django-DefectDojo/releases) -- active development, MCP support added (HIGH confidence)
- [Nexus Repository CE](https://help.sonatype.com/en/download.html) -- v3.90.x confirmed, CE limits documented (HIGH confidence)
- [Kyverno 1.17 Release Blog](https://kyverno.io/blog/2026/02/02/announcing-kyverno-release-1.17/) -- CEL v1, ClusterPolicy deprecated (HIGH confidence)
- [Falco GitHub Releases](https://github.com/falcosecurity/falco/releases) -- v0.43.0 confirmed (HIGH confidence)
- [Cosign GitHub Releases](https://github.com/sigstore/cosign/releases) -- v3.0.5 confirmed (HIGH confidence)
- [cert-manager Releases](https://github.com/cert-manager/cert-manager/releases) -- v1.20.0 confirmed (HIGH confidence)
- [kube-prometheus-stack ArtifactHub](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) -- v82.10.3 confirmed (HIGH confidence)
- [Trivy Operator Releases](https://github.com/aquasecurity/trivy-operator/releases) -- v0.32.x confirmed (HIGH confidence)
- [Ruff GitHub Releases](https://github.com/astral-sh/ruff/releases) -- v0.15.x confirmed, 2026 style guide (HIGH confidence)
- [pre-commit PyPI](https://pypi.org/project/pre-commit/) -- v4.5.x confirmed, Dependabot support added 2026-03-10 (HIGH confidence)

---
*Stack research for: zero-cost developer security and supply chain scanning toolchain*
*Researched: 2026-03-15*
