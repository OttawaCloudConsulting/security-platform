# External Integrations

**Analysis Date:** 2026-03-15

## APIs & External Services

**Upstream Registries (Proxied via Nexus):**
- `registry.npmjs.org` (npm packages) - Proxied through Nexus npm repository
- `pypi.org` (Python packages) - Proxied through Nexus PyPI repository
- `registry-1.docker.io` (Docker Hub) - Proxied through Nexus Docker repository
- `charts.helm.sh` (Helm charts) - Proxied through Nexus Helm repository
- `registry.terraform.io` (Terraform providers) - Proxied through Nexus Terraform provider repository
- `proxy.golang.org` (Go modules) - Proxied through Nexus Go proxy repository
- Maven Central, NuGet, RubyGems, Apt, Yum - Available via Nexus proxying

**GitHub Integration:**
- GitHub Actions - CI/CD platform for `.github/workflows/security.yml` execution
- GitHub Security Tab - SARIF upload destination for code scanning results
- GitHub Repository Settings - Branch protection rules, required status checks
- GitHub Secrets - Storage for `DEFECTDOJO_API_TOKEN` and other credentials
- GitHub OIDC Provider - Keyless Cosign signing integration (`https://token.actions.githubusercontent.com`)

**Cloud Platform:**
- AWS - Target infrastructure for Terraform/CDK deployment (though this is a documentation project)
  - EC2, S3, IAM, CloudFormation, CDK support documented
  - Optional: AWS WAF for ModSecurity integration

## Data Storage

**Databases:**
- PostgreSQL - Required for DefectDojo and optional for SonarQube/Harbor
  - Connection: Kubernetes StatefulSet or external managed database
  - Client: Native PostgreSQL tools (`psql`, `pg_dump` for backups)
  - Critical data: All vulnerability findings, lifecycle state, deduplication rules, SLA tracking
  - Backup mechanism: `pg_dump` via CronJob, stored as PVCs or external storage

**Package/Artifact Storage:**
- Nexus Repository blob store (`/nexus-data` PVC) - Caches all upstream packages
  - Formats: npm, PyPI, Docker, Helm, Maven, Go, NuGet, RubyGems, Apt, Yum
  - PersistentVolume required for caching; loss triggers re-download from upstream
  - Backup via VolumeSnapshot API or `pg_dump` for metadata

**Container Registry Storage:**
- Harbor registry blob storage (optional, PVC-based)
  - Stores container images with scan-on-push and signing features
  - Metadata in PostgreSQL backend
- Nexus Docker storage - Alternative if Harbor not deployed

**Scanning Output Storage:**
- GitHub Artifacts - JSON and SARIF scan results from CI workflows
- DefectDojo database - Centralized finding aggregation via API import

**File Storage:**
- Kubernetes PersistentVolumeClaims (PVCs) - Persistent storage for all services
  - Nexus `/nexus-data` - Package cache
  - DefectDojo PostgreSQL data directory
  - Optional: SonarQube Elasticsearch data
  - Optional: Harbor PostgreSQL and registry storage

**Caching:**
- Nexus Repository caching - In-cluster caching of all upstream packages
  - `contentMaxAge: -1` (indefinite caching for reproducibility)
  - `metadataMaxAge: 1440` (24-hour metadata refresh)
- Docker layer caching - Local image cache during CI/CD builds

## Authentication & Identity

**Auth Provider:**
- Custom/None - All security tools run without external authentication
- GitHub Actions - Uses GitHub's built-in OIDC for Cosign keyless signing
  - OIDC Issuer: `https://token.actions.githubusercontent.com`
  - Certificate identity: Workflow identity via `github.com/<org>/<repo>/.github/workflows/security.yml@refs/heads/main`

**Internal Service Authentication:**
- Kubernetes Secrets - Stored credentials for service-to-service communication
  - `DEFECTDOJO_API_TOKEN` - DefectDojo API key for CI import
  - `NEXUS_USERNAME` / `NEXUS_PASSWORD` - Repository credentials
  - `SONARQUBE_TOKEN` (optional)
  - `HARBOR_ROBOT_ACCOUNT` (optional)

**Workstation Authentication:**
- Git SSH keys or GitHub token (for git operations)
- Kubeconfig for kubectl access to Kubernetes cluster
- Docker login credentials (if using private registries)

## CI/CD & Deployment

**Hosting:**
- GitHub Actions - CI/CD platform (free GitHub-hosted runners)
- Kubernetes cluster (self-hosted) - Runtime platform for security services
- AWS (documented as target IaC deployment) - Infrastructure endpoint

**CI Pipeline:**
- GitHub Actions (primary)
  - `.github/workflows/security.yml` - Main security workflow
  - Triggered on: `pull_request` and `push` to protected branches
  - Jobs: `sast` (Semgrep), `iac` (Checkov), `sca` (Syft+Grype), `container` (Trivy), `secrets` (Gitleaks)
  - Outputs: SARIF to GitHub Security tab, JSON to artifacts, API import to DefectDojo
  - Image signing job: Cosign keyless signing post-container scan success
- Pre-commit hooks (local, Tiers 1 & 2)
  - Tier 1 (every commit): ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint, npm audit, tf fmt/val
  - Tier 2 (pre-push): Gitleaks secrets detection

**Deployment Mechanism:**
- Helm + kubectl for Kubernetes service deployments
  - DefectDojo Helm chart: `defectdojo/defectdojo`
  - Nexus Helm chart: `sonatype/nexus-repository-manager`
  - Trivy Operator Helm chart: `aqua/trivy-operator`
  - Falco Helm chart: `falco/falco`
  - SonarQube Helm chart: `sonarqube/sonarqube` (optional)
  - Harbor Helm chart: `harbor/harbor` (optional)
  - Kyverno Helm chart: `kyverno/kyverno`
  - kube-prometheus-stack: `prometheus-community/kube-prometheus-stack` (optional)

## Environment Configuration

**Required env vars:**
- `DEFECTDOJO_API_TOKEN` - DefectDojo API authentication token
- `NEXUS_URL` - Nexus repository URL (e.g., `http://nexus-service:8081`)
- `NEXUS_USERNAME` / `NEXUS_PASSWORD` - Repository manager credentials
- `SEMGREP_CONFIG` - Semgrep rule configuration (default: `auto` for public registry)
- `GITHUB_TOKEN` - (auto-provided by Actions) for SARIF upload and API calls
- `COSIGN_EXPERIMENTAL=1` - Enable keyless Cosign signing with GitHub OIDC

**Optional env vars:**
- `SONARQUBE_HOST_URL` - SonarQube instance URL
- `SONARQUBE_TOKEN` - SonarQube authentication
- `HARBOR_URL` - Harbor registry URL
- `HARBOR_USERNAME` / `HARBOR_PASSWORD` - Harbor credentials
- `FALCO_ALERT_CHANNEL` - FalcoSidekick alert destination (Slack, email, etc.)

**Secrets location:**
- GitHub Secrets (for CI workflows) - `Settings → Secrets and variables → Actions`
- Kubernetes Secrets - `kubectl create secret generic` in appropriate namespaces
- `.env` files (local development, NOT committed to git)
- Kubeconfig (local development)

## Webhooks & Callbacks

**Incoming:**
- GitHub Actions webhook - Triggered by push/pull_request events to repositories
- Kubernetes Operator webhooks - ValidatingWebhookConfiguration for Kyverno admission control

**Outgoing:**
- GitHub Security Tab SARIF upload - Scan results from CI workflow
- DefectDojo API (`/api/v2/import-scan/`) - JSON/SARIF import from GitHub Actions
- Slack/Email/PagerDuty - Via Alertmanager (optional, if kube-prometheus-stack deployed)
- FalcoSidekick - Falco alerts routed to external systems (optional)

**Data Flow:**
1. Developer commits/pushes code to GitHub
2. Pre-commit hooks (local) catch Tier 1 & 2 issues
3. GitHub Actions triggered → Semgrep, Checkov, Trivy, Grype, Gitleaks scan in parallel
4. Results:
   - SARIF uploaded to GitHub Security Tab (GitHub Code Scanning)
   - JSON artifacts stored in Actions artifacts
   - DefectDojo API receives results via `curl` POST from workflow
5. DefectDojo deduplicates findings and tracks lifecycle
6. Optional: Prometheus scrapes metrics, Alertmanager notifies on failures
7. Container image signed via Cosign (keyless) post-scan
8. Kyverno admission controller verifies image signatures on pod creation

## Network & TLS

**Internal Communication:**
- All in-cluster service communication currently plaintext HTTP
- Recommended: TLS via cert-manager for production
- NetworkPolicy: Default-deny ingress, explicit allow rules per service
  - DefectDojo accessible to CI runners only
  - Nexus accessible to developer workstations and CI
  - Harbor accessible to deployment pipelines only
  - SonarQube accessible to CI and authorized developers

**Package Manager Security:**
- `insecure-registries` (Docker) - Bootstrap only, should be replaced with TLS
- `trusted-host` (pip) - Bootstrap only, should be replaced with TLS
- Dependency confusion attack mitigation: Group repository ordering (hosted before proxy)

## Integration Patterns

**Artifact Flow:**
```
Source → Pre-commit (local) → Git push → GitHub Actions → Nexus cache
                                              ↓
                                    Scanning (parallel) → SARIF/JSON
                                              ↓
                               GitHub Security Tab + DefectDojo API
```

**Container Image Flow:**
```
Dockerfile → Docker build → Trivy scan → Image sign (Cosign) → Push to registry
                                              ↓
                                        SARIF to GitHub/DefectDojo
                                              ↓
                                    Kyverno admission control (on deploy)
```

**Dependency Management:**
```
Source code → Syft/Trivy (filesystem scan) → Generate SBOM → Grype (vulnerability check)
                                                      ↓
                                              DefectDojo aggregation
                                                      ↓
                                         Package update recommendations
```

---

*Integration audit: 2026-03-15*
