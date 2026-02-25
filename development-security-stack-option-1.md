# Code Security & Supply Chain Stack — Complete Reference

> For a single-developer AWS cloud practice using Terraform, CDK, CloudFormation, Python, TypeScript/JavaScript, Bash, Kubernetes/YAML, and Docker.
> **All tools are free, open-source, and require no sign-ups, logins, or authentication to any external service.**
> Everything runs locally or self-hosted on your Kubernetes cluster.

---

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          UPSTREAM REGISTRIES                               │
│  registry.npmjs.org · pypi.org · registry-1.docker.io · charts.helm.sh     │
│  registry.terraform.io · proxy.golang.org                                  │
└──────────────────────────────────┬─────────────────────────────────────────┘
                                   │ proxied & cached
                                   ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                         Developer Workstation                              │
│  IDE (VS Code) + Pre-commit Hooks (Tier 1 & 2) + CLI Tools                 │
│                                                                            │
│  Pre-commit Tier 1 — Quality & Linting (fast, every commit)                │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │  ShellCheck  │ │     Ruff     │ │   ESLint     │ │  hadolint    │       │
│  │  (sh/bash)   │ │   (Python)   │ │   (TS/JS)    │ │ (Dockerfile) │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │   yamllint   │ │ markdownlint │ │  npm audit   │ │  tf fmt/val  │       │
│  │  (K8s/YAML)  │ │    (.md)     │ │  (fast dep)  │ │  (Terraform) │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│                                                                            │
│  Pre-commit Tier 2 — Secrets Gate (before push)                            │
│  ┌──────────────┐                                                          │
│  │  Gitleaks    │  ← only secrets; SAST/IaC scanning moves to PR gate      │
│  │  (Secrets)   │                                                          │
│  └──────────────┘                                                          │
│                                                                            │
│  Manual / CLI (run on demand)                                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                        │
│  │    Trivy     │ │    Syft      │ │    Grype     │                        │
│  │ (Multi-scan) │ │   (SBOM)     │ │    (SCA)     │                        │
│  └──────────────┘ └──────────────┘ └──────────────┘                        │
│                                                                            │
│  Package managers point at Nexus:                                          │
│    npm install ──► Nexus npm proxy ──► registry.npmjs.org                  │
│    pip install ──► Nexus PyPI proxy ──► pypi.org                           │
│    docker pull ──► Nexus Docker proxy ──► Docker Hub                       │
│    helm install ──► Nexus Helm proxy ──► charts.helm.sh                    │
└────────────────────────────┬───────────────────────────────────────────────┘
                             │ git push
                             ▼
┌────────────────────────────────────────────────────────────────────────────┐
│        CI/CD — GitHub Actions (PR Gate + push to main safety net)          │
│                                                                            │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │ Semgrep CE   │ │   Checkov    │ │    Trivy     │ │  Gitleaks    │       │
│  │   (SAST)     │ │  (IaC Scan)  │ │ (Container)  │ │ (full hist.) │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│  ┌──────────────┐                                                          │
│  │ Syft + Grype │                                                          │
│  │   (SCA)      │                                                          │
│  └──────┬───────┘                                                          │
│         └──────── all output JSON / SARIF ─────────────────────┐           │
│                                                                │           │
│  Output Destinations:                                          │           │
│    • SARIF ──► GitHub Security Tab                             │           │
│    • JSON  ──► CI Artifacts (downloadable)                     │           │
│    • API   ──► DefectDojo (direct import)                      │           │
│    • Images ──► Nexus / Harbor registry                        │           │
└────────────────────────────────────────────────────────────────┼───────────┘
                                                                 │
                                                                 ▼
┌────────────────────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (Self-Hosted Services)                     │
│                                                                            │
│  ┌─────────── Security Dashboards ─────────────┐                           │
│  │                                             │                           │
│  │  ┌───────────────────────────────────────┐  │                           │
│  │  │       DefectDojo (Helm / Docker)      │  │                           │
│  │  │  Unified Dashboard · Deduplication    │  │                           │
│  │  │  Trending · SLA · Lifecycle · API     │  │                           │
│  │  │  Ingests: Semgrep, Checkov, Trivy,    │  │                           │
│  │  │  Grype, Gitleaks, SonarQube, + 200+   │  │                           │
│  │  └───────────────────────────────────────┘  │                           │
│  │                                             │                           │
│  │  ┌───────────────────────────────────────┐  │                           │
│  │  │  SonarQube Community Build [Optional] │  │                           │
│  │  │  Code Quality · Bugs · Smells · Debt  │  │                           │
│  │  │  Coverage · Quality Gates · SonarLint │  │                           │
│  │  └───────────────────────────────────────┘  │                           │
│  └─────────────────────────────────────────────┘                           │
│                                                                            │
│  ┌─────────── Artifact & Package Management ───┐                           │
│  │                                             │                           │
│  │  ┌───────────────────────────────────────┐  │                           │
│  │  │  Nexus Repository Community Edition   │  │                           │
│  │  │  npm · PyPI · Docker · Helm · Maven   │  │                           │
│  │  │  Go · NuGet · RubyGems · Apt · Yum    │  │                           │
│  │  │  Proxy + Cache + Private Hosting      │  │                           │
│  │  └───────────────────────────────────────┘  │                           │
│  │                                             │                           │
│  │  ┌───────────────────────────────────────┐  │                           │
│  │  │   Harbor (CNCF Graduated) [Optional]  │  │                           │
│  │  │  Container Registry · Scan-on-Push    │  │                           │
│  │  │  Image Signing · Tag Retention · RBAC │  │                           │
│  │  └───────────────────────────────────────┘  │                           │
│  └─────────────────────────────────────────────┘                           │
│                                                                            │
│  ┌─────────── Runtime Security ────────────────┐                           │
│  │                                             │                           │
│  │  ┌───────────────────────────────────────┐  │                           │
│  │  │         Trivy Operator (Helm)         │  │                           │
│  │  │  Continuous K8s workload scanning     │  │                           │
│  │  │  VulnerabilityReports · ConfigAudits  │  │                           │
│  │  └───────────────────────────────────────┘  │                           │
│  └─────────────────────────────────────────────┘                           │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Tool Selection Summary

| Category | Tool | License | Requires Account? | Replaces |
|---|---|---|---|---|
| **SAST** | **Semgrep CE** | LGPL-2.1 | No | Snyk Code, SonarQube (partial) |
| **IaC Scanning** | **Checkov** | Apache 2.0 | No | tfsec (legacy) |
| **IaC + Container + Secrets** | **Trivy** | Apache 2.0 | No | tfsec, Snyk Container |
| **SCA / Supply Chain** | **Syft** (SBOM) + **Grype** (vuln scan) | Apache 2.0 | No | Snyk Open Source, npm audit |
| **Secrets Detection** | **Gitleaks** | MIT | No | — |
| **K8s Runtime Scanning** | **Trivy Operator** | Apache 2.0 | No | — |
| **Unified Dashboard** | **DefectDojo** (open-source) | BSD-3 | No (self-hosted) | — |
| **Code Quality Dashboard** | **SonarQube Community Build** [Optional] | LGPL-3.0 | No (self-hosted) | — |
| **Artifact Registry** | **Nexus Repository CE** | EPL-1.0 | No (self-hosted) | JFrog Artifactory |
| **Container Registry** | **Harbor** [Optional] | Apache 2.0 | No (self-hosted) | Docker Hub, ECR |
| **Pre-commit Orchestration** | **pre-commit** | MIT | No | — |
| **Shell Linting** | **ShellCheck** | GPL-3.0 | No | — |
| **Python Linting/Formatting** | **Ruff** | MIT | No | flake8, black, isort |
| **JS/TS Linting** | **ESLint** | MIT | No | — |
| **Dockerfile Linting** | **hadolint** | GPL-3.0 | No | — |
| **YAML Linting** | **yamllint** | MIT | No | — |
| **Markdown Linting** | **markdownlint-cli** | MIT | No | — |
| **Fast npm SCA** | **npm audit** *(retained)* | — | No | — |

**Total cost: $0. Total external accounts: 0.**

---

## Tool Details

### 1. Semgrep CE — Static Application Security Testing (SAST)

**What is SAST?** Static Application Security Testing analyses source code without executing it. It looks for patterns that indicate security vulnerabilities — things like hardcoded credentials, injection-prone constructs, unsafe deserialization, insecure use of cryptographic functions, or AWS-specific misconfigurations in Terraform/CDK. It is a code-level scan, not a runtime or infrastructure scan.

**What is Semgrep CE specifically?** Semgrep Community Edition is a rule-based SAST engine. Rather than reasoning about code semantics, it matches code patterns defined in YAML rule files. This makes it fast, predictable, and easy to extend with custom rules. The Community Edition uses the public Semgrep Registry (thousands of community-maintained rules) and runs entirely locally with no account, no login, and no telemetry.

**Where it runs in this stack:** Semgrep CE runs as a Pull Request check in GitHub Actions — not as a pre-commit hook. Running a full-repo SAST scan on every commit is expensive and creates friction in feature branch development where code is intentionally in an intermediate state. The PR gate is the right enforcement point: code is checked before it enters a protected branch, results are visible in the GitHub Security tab via SARIF upload, and failures can be configured to block the merge.

**What it covers:** Python, JavaScript/TypeScript, Go, Java, Ruby, Bash (basic), HCL (Terraform), YAML, JSON, Dockerfile, and more.

**What you lose vs. the AppSec Platform:** No hosted dashboard (DefectDojo replaces this), no cross-file/inter-file dataflow analysis (CE is intra-file only), no "Pro rules." The CE engine is still very capable for pattern-based and single-file dataflow SAST.

**Setup:**

```bash
# Install
pip install semgrep --break-system-packages
# or
brew install semgrep

# Run with auto-config (fetches community rules, no login)
semgrep scan --config auto .

# Run with specific rulesets
semgrep scan --config p/python --config p/typescript --config p/terraform .

# Output JSON for DefectDojo ingestion
semgrep scan --config auto --json --output semgrep-results.json .

# Output SARIF for GitHub Code Scanning
semgrep scan --config auto --sarif --output semgrep-results.sarif .

# Offline: download rules once, use locally
semgrep --config auto --dump-config > rules.yaml
semgrep scan --config rules.yaml .
```

**Custom rules (YAML, no special language needed):**

```yaml
# .semgrep/custom-rules.yml
rules:
  - id: no-hardcoded-aws-region
    patterns:
      - pattern: region = "..."
    message: "Avoid hardcoding AWS regions; use variables instead"
    languages: [hcl]
    severity: WARNING
```

---

### 2. Checkov — Infrastructure as Code Scanning

Checkov is a fully open-source IaC scanner. No account, no network dependency beyond pip install. It has 1,000+ built-in policies with graph-based cross-resource relationship analysis.

**Where it runs in this stack:** Checkov runs as a Pull Request check in GitHub Actions — not as a pre-commit hook. A full Checkov scan traverses all IaC resources and evaluates cross-resource relationships, which is intentionally thorough but not suited to the commit loop. Feature branches are also expected to contain IaC that is not yet fully compliant. The PR gate catches issues before they merge, without penalising normal development flow. For existing projects with a high volume of pre-existing findings, the baseline workflow below lets you suppress known issues and focus only on new ones introduced by the PR.

**What it covers:** Terraform, Terraform Plan, CloudFormation, AWS CDK (synthesized CFN), Kubernetes manifests, Helm, Dockerfile, Serverless Framework, GitHub Actions workflows, Bicep, ARM.

**Setup:**

```bash
pip install checkov --break-system-packages

# Scan Terraform
checkov -d ./infrastructure/terraform

# Scan CDK (synthesize first, then scan the CloudFormation output)
cdk synth --output cdk.out
checkov -d ./cdk.out

# Scan Kubernetes manifests
checkov -d ./k8s/

# Scan Dockerfile
checkov -f Dockerfile

# Scan GitHub Actions workflows
checkov -d .github/workflows/

# Output JSON for DefectDojo
checkov -d . -o json > checkov-results.json

# Output SARIF for GitHub Code Scanning
checkov -d . -o sarif > checkov-results.sarif
```

**Baseline workflow (existing projects with many findings):**

```bash
# Generate baseline — only new findings flagged going forward
checkov -d . --create-baseline
# Subsequent runs ignore baselined findings
checkov -d . --baseline .checkov.baseline
```

---

### 3. Trivy — Container, Filesystem, IaC & Secrets Scanning

Trivy is a Swiss army knife scanner from Aqua Security. Fully open-source, runs locally, no account. It absorbed tfsec and provides container image vulnerability scanning, filesystem dependency scanning, IaC misconfiguration detection, secrets detection, and SBOM generation.

**Where Trivy overlaps with Checkov:** Both scan IaC (Terraform, CloudFormation, K8s, Dockerfile). Checkov has deeper graph-based analysis and more IaC-specific policies. Trivy adds container image scanning and dependency scanning that Checkov doesn't do. Use both — they catch different things.

**Setup:**

```bash
# Install
brew install trivy
# or
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin

# Scan a container image for vulnerabilities
trivy image my-app:latest

# Scan a container image — JSON output for DefectDojo
trivy image --format json --output trivy-image.json my-app:latest

# Scan filesystem for dependency vulnerabilities
trivy fs --scanners vuln .

# Scan IaC (Terraform, CloudFormation, K8s, Dockerfile)
trivy config ./infrastructure/

# Detect secrets in code
trivy fs --scanners secret .

# Scan your running Kubernetes cluster
trivy k8s --report summary cluster

# Generate SBOM (CycloneDX format)
trivy image --format cyclonedx --output sbom.json my-app:latest

# Fully offline mode (download DB once)
trivy image --download-db-only
trivy image --skip-db-update --offline-scan my-app:latest
```

---

### 4. Syft + Grype — Software Composition Analysis (SCA) & Supply Chain

This is your dedicated SCA pipeline, replacing Snyk Open Source and enhancing npm audit. Both tools are from Anchore, fully open-source (Apache 2.0), CLI-only, no account needed.

**Syft** generates Software Bills of Materials (SBOMs) from source directories, container images, and archives. **Grype** scans those SBOMs (or targets directly) for known vulnerabilities. Together they give you deep supply chain visibility.

**Why Syft+Grype in addition to Trivy?** Trivy does dependency scanning too, but Syft+Grype provide richer SBOM generation (SPDX, CycloneDX formats), more granular control over output, and a purpose-built SCA workflow. They also serve as a second opinion — different tools use different vulnerability databases and detection methods.

**Setup:**

```bash
# Install Syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
  | sh -s -- -b /usr/local/bin
# or
brew install syft

# Install Grype
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
  | sh -s -- -b /usr/local/bin
# or
brew install grype
```

**Usage:**

```bash
# Generate SBOM from a project directory
syft dir:. -o cyclonedx-json > sbom.json

# Generate SBOM from a container image
syft my-app:latest -o cyclonedx-json > sbom-image.json

# Generate SBOM in SPDX format (for compliance)
syft dir:. -o spdx-json > sbom-spdx.json

# Scan the SBOM for vulnerabilities
grype sbom:sbom.json

# Or scan directly (Grype generates its own SBOM internally)
grype dir:.
grype my-app:latest

# Output JSON for DefectDojo ingestion
grype dir:. -o json > grype-results.json

# Fail CI on high/critical severity
grype dir:. --fail-on high
```

**What this replaces:**

| Previous Tool | Syft+Grype Advantage |
|---|---|
| `npm audit` | Covers ALL ecosystems (Python/pip, npm, Go, Ruby, Rust, etc.) not just npm. Produces SBOMs. |
| Snyk Open Source | No scan limits, no account, richer SBOM output, supports container images |
| Manual dependency checks | Automated, CI-integrated, tracks transitive dependencies |

**DefectDojo integration:** DefectDojo has a native "Anchore Grype" parser, so you can import `grype-results.json` directly.

---

### 5. Gitleaks — Secrets Detection

Purpose-built secrets scanner. Scans current files and full git history. No account, CLI-only.

**Setup:**

```bash
brew install gitleaks

# Scan current files
gitleaks detect --source .

# Scan full git history (catches secrets in past commits)
gitleaks detect --source . --log-opts="--all"

# Output JSON for DefectDojo
gitleaks detect --source . --report-path gitleaks-report.json --report-format json

# Protect mode — scan only staged changes (for pre-commit)
gitleaks protect --staged
```

---

### 6. Nexus Repository Community Edition — Artifact & Package Management

Nexus Repository Community Edition (formerly "OSS") is the JFrog Artifactory equivalent. It's a universal artifact repository manager — free, self-hosted, no external account needed. As of version 3.77.0, the Community Edition gained access to previously Pro-only format support including Docker, npm, PyPI, and Kubernetes deployment via external PostgreSQL.

**What it does that no other tool in this stack provides:**

- **Proxies and caches upstream registries** — npm, PyPI, Docker Hub, Maven, Helm, Go, NuGet, RubyGems, Apt, Yum, and more. Your `npm install` and `pip install` commands pull through Nexus, which caches locally. Faster builds, protection against upstream outages, and a single audit point.
- **Hosts private packages** — internal npm modules, Python packages, or Terraform modules served with native package manager protocol.
- **Provides a single source of truth for all binaries** — Docker images, Helm charts, npm packages, Python wheels, and Terraform providers in one place with a web UI.
- **Controls what enters your supply chain** — configure Nexus to only serve vetted/approved packages.

**What Nexus does NOT do:** Vulnerability scanning. Nexus Community Edition is purely a repository manager. Scanning is handled by Grype and Trivy.

**Deploy to Kubernetes (Helm):**

```bash
helm repo add sonatype https://sonatype.github.io/helm3-charts/
helm repo update

helm install nexus sonatype/nexus-repository-manager \
  --namespace nexus \
  --create-namespace \
  --set nexus.resources.requests.memory=2Gi

kubectl port-forward -n nexus svc/nexus-nexus-repository-manager 8081:8081
# Access at http://localhost:8081
# Get initial admin password:
kubectl exec -n nexus deploy/nexus-nexus-repository-manager -- \
  cat /nexus-data/admin.password
```

**Or Docker (simplest):**

```bash
docker run -d -p 8081:8081 --name nexus \
  -v nexus-data:/nexus-data \
  sonatype/nexus3

# Wait 2-3 minutes for startup, then:
docker exec nexus cat /nexus-data/admin.password
# Access at http://localhost:8081
```

**Configure package managers to use Nexus:**

```bash
# npm — .npmrc
registry=http://localhost:8081/repository/npm-proxy/

# pip — ~/.config/pip/pip.conf
[global]
index-url = http://localhost:8081/repository/pypi-proxy/simple
trusted-host = localhost

# Docker — /etc/docker/daemon.json
{
  "registry-mirrors": ["http://localhost:8081"],
  "insecure-registries": ["localhost:8081"]
}

# Helm
helm repo add nexus-proxy http://localhost:8081/repository/helm-proxy/
```

**Creating proxy repositories via REST API:**

```bash
NEXUS_URL="http://localhost:8081"
NEXUS_AUTH="admin:your-password"

# npm proxy
curl -X POST "${NEXUS_URL}/service/rest/v1/repositories/npm/proxy" \
  -u "${NEXUS_AUTH}" -H "Content-Type: application/json" \
  -d '{
    "name": "npm-proxy", "online": true,
    "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
    "proxy": {"remoteUrl": "https://registry.npmjs.org", "contentMaxAge": -1, "metadataMaxAge": 1440},
    "negativeCache": {"enabled": true, "timeToLive": 1440},
    "httpClient": {"blocked": false, "autoBlock": true}
  }'

# PyPI proxy
curl -X POST "${NEXUS_URL}/service/rest/v1/repositories/pypi/proxy" \
  -u "${NEXUS_AUTH}" -H "Content-Type: application/json" \
  -d '{
    "name": "pypi-proxy", "online": true,
    "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
    "proxy": {"remoteUrl": "https://pypi.org", "contentMaxAge": -1, "metadataMaxAge": 1440},
    "negativeCache": {"enabled": true, "timeToLive": 1440},
    "httpClient": {"blocked": false, "autoBlock": true}
  }'

# Docker proxy
curl -X POST "${NEXUS_URL}/service/rest/v1/repositories/docker/proxy" \
  -u "${NEXUS_AUTH}" -H "Content-Type: application/json" \
  -d '{
    "name": "docker-proxy", "online": true,
    "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
    "proxy": {"remoteUrl": "https://registry-1.docker.io", "contentMaxAge": -1, "metadataMaxAge": 1440},
    "docker": {"v1Enabled": false, "forceBasicAuth": true, "httpPort": 8082},
    "dockerProxy": {"indexType": "HUB"},
    "negativeCache": {"enabled": true, "timeToLive": 1440},
    "httpClient": {"blocked": false, "autoBlock": true}
  }'

# Helm proxy
curl -X POST "${NEXUS_URL}/service/rest/v1/repositories/helm/proxy" \
  -u "${NEXUS_AUTH}" -H "Content-Type: application/json" \
  -d '{
    "name": "helm-proxy", "online": true,
    "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
    "proxy": {"remoteUrl": "https://charts.helm.sh/stable", "contentMaxAge": -1, "metadataMaxAge": 1440},
    "negativeCache": {"enabled": true, "timeToLive": 1440},
    "httpClient": {"blocked": false, "autoBlock": true}
  }'
```

**Supported repository formats (Community Edition):**

| Format | Proxy | Hosted | Group |
|---|---|---|---|
| npm | ✅ | ✅ | ✅ |
| PyPI | ✅ | ✅ | ✅ |
| Docker | ✅ | ✅ | ✅ |
| Helm | ✅ | ✅ | — |
| Maven | ✅ | ✅ | ✅ |
| Go | ✅ | — | ✅ |
| NuGet | ✅ | ✅ | ✅ |
| RubyGems | ✅ | ✅ | ✅ |
| Apt | ✅ | ✅ | — |
| Yum | ✅ | ✅ | ✅ |
| Conan | ✅ | ✅ | — |
| R | ✅ | ✅ | ✅ |
| Raw | ✅ | ✅ | ✅ |

---

### 7. Harbor — Container Registry [Optional]

Harbor is a CNCF Graduated project, fully open-source (Apache 2.0), purpose-built for container images and Helm charts.

**What Harbor adds beyond Nexus's Docker support:**

- **Built-in vulnerability scanning** via Trivy — scans every image on push, can block images with Critical CVEs
- **Image signing** via Cosign/Notation — cryptographic proof of integrity
- **Tag retention policies** — automatic cleanup of old images
- **Replication** — sync images between registries
- **Robot accounts** — purpose-built CI/CD credentials
- **Quota management** and **RBAC** per project

**Limitation:** Harbor only handles OCI artifacts (container images, Helm charts). It doesn't proxy npm, PyPI, or other non-container package types. It complements Nexus rather than replacing it.

**Deploy to Kubernetes (Helm):**

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update

helm install harbor harbor/harbor \
  --namespace harbor \
  --create-namespace \
  --set expose.type=nodePort \
  --set externalURL=https://harbor.local \
  --set harborAdminPassword=your-secure-password

kubectl port-forward -n harbor svc/harbor-portal 8443:443
# Access at https://localhost:8443
# Default login: admin / your-secure-password
```

**Or Docker Compose:**

```bash
wget https://github.com/goharbor/harbor/releases/download/v2.12.0/harbor-offline-installer-v2.12.0.tgz
tar xvf harbor-offline-installer-v2.12.0.tgz && cd harbor
cp harbor.yml.tmpl harbor.yml
# Edit harbor.yml: set hostname, HTTPS certs, admin password
./install.sh
```

---

### 8. DefectDojo — Unified Security Dashboard (Self-Hosted)

DefectDojo is your single pane of glass for all security findings. It ingests scan results from all your tools via REST API, deduplicates findings, tracks remediation status, and provides dashboards and reports. 200+ scanner integrations.

**Deploy to Kubernetes (Helm):**

```bash
helm repo add defectdojo \
  https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts
helm repo update

helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  --set django.ingress.enabled=true \
  --set host="defectdojo.local" \
  --set tag="latest"

kubectl get secret defectdojo -n defectdojo \
  -o jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 -d

kubectl port-forward -n defectdojo svc/defectdojo-django 8080:80
```

**Or Docker Compose:**

```bash
git clone https://github.com/DefectDojo/django-DefectDojo
cd django-DefectDojo
./docker/docker-compose-check.sh
docker compose up -d
docker compose logs initializer | grep "Admin password"
```

**Importing scan results:**

```bash
DD_URL="http://localhost:8080"
DD_TOKEN="your-api-token"

# Import Semgrep
curl -X POST "${DD_URL}/api/v2/import-scan/" \
  -H "Authorization: Token ${DD_TOKEN}" \
  -F "scan_type=Semgrep JSON Report" \
  -F "file=@semgrep-results.json" \
  -F "product_name=My App" \
  -F "engagement_name=CI Scan" \
  -F "auto_create_context=True"

# Import Checkov
curl -X POST "${DD_URL}/api/v2/import-scan/" \
  -H "Authorization: Token ${DD_TOKEN}" \
  -F "scan_type=Checkov Scan" \
  -F "file=@checkov-results.json" \
  -F "product_name=My App" \
  -F "engagement_name=CI Scan" \
  -F "auto_create_context=True"

# Import Trivy
curl -X POST "${DD_URL}/api/v2/import-scan/" \
  -H "Authorization: Token ${DD_TOKEN}" \
  -F "scan_type=Trivy Scan" \
  -F "file=@trivy-image.json" \
  -F "product_name=My App" \
  -F "engagement_name=CI Scan" \
  -F "auto_create_context=True"

# Import Grype
curl -X POST "${DD_URL}/api/v2/import-scan/" \
  -H "Authorization: Token ${DD_TOKEN}" \
  -F "scan_type=Anchore Grype" \
  -F "file=@grype-results.json" \
  -F "product_name=My App" \
  -F "engagement_name=CI Scan" \
  -F "auto_create_context=True"

# Import Gitleaks
curl -X POST "${DD_URL}/api/v2/import-scan/" \
  -H "Authorization: Token ${DD_TOKEN}" \
  -F "scan_type=Gitleaks Scan" \
  -F "file=@gitleaks-report.json" \
  -F "product_name=My App" \
  -F "engagement_name=CI Scan" \
  -F "auto_create_context=True"
```

**What DefectDojo gives you:** Consolidated view of all findings, automatic deduplication, finding lifecycle tracking (Open → Under Review → Mitigated → Closed), trending dashboards, per-product/engagement views, SLA tracking, and JIRA integration.

---

### 9. SonarQube Community Build — Code Quality + SAST Dashboard [Optional]

SonarQube Community Build is fully self-hosted, open-source (LGPL-3.0). It provides code quality metrics, bug detection, security vulnerability scanning, and code smell analysis.

**Why optional?** Semgrep CE + DefectDojo already cover SAST needs. SonarQube adds value for code quality metrics (duplication, complexity, maintainability, test coverage). Trade-off: heavier service to run.

**Limitations:** Single-branch analysis only, no PR decoration (paid only), no branch comparison.

**Deploy:**

```bash
# Kubernetes
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm install sonarqube sonarqube/sonarqube --namespace sonarqube --create-namespace
kubectl port-forward -n sonarqube svc/sonarqube-sonarqube 9000:9000

# Or Docker
docker run -d --name sonarqube -p 9000:9000 sonarqube:community
# Default login: admin / admin
```

**SonarQube results can be imported to DefectDojo** using the "SonarQube Scan" parser.

---

### 10. Trivy Operator — Kubernetes Runtime Scanning

Continuously scans running container images and K8s configurations in your cluster.

```bash
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system --create-namespace

kubectl get vulnerabilityreports -A
```

---

## DefectDojo vs SonarQube — When You Need Which

**SonarQube = scanner with a dashboard.** It runs its own analysis engine and displays its own findings.
**DefectDojo = dashboard without a scanner.** It ingests results from other tools and provides unified view.

### What SonarQube does that DefectDojo does NOT

| Capability | Detail |
|---|---|
| Own static analysis engine | 6,000+ built-in rules |
| Code quality metrics | Cyclomatic/cognitive complexity, duplication %, LOC, comment density |
| Technical debt tracking | Estimates hours to fix maintainability issues |
| Code smell detection | Structural problems hurting maintainability |
| Bug detection | Logic errors, null dereferences (separate from security) |
| Test coverage visualization | Fed by lcov, JaCoCo, etc. |
| Quality Gates | Pass/fail thresholds that can block merges |
| New code focus | Quality of recent changes vs. legacy |
| SonarLint IDE integration | Real-time feedback in VS Code / JetBrains |
| Per-file drill-down | Inline annotation on source code |

### What DefectDojo does that SonarQube does NOT

| Capability | Detail |
|---|---|
| Tool-agnostic aggregation | 200+ scanner parsers |
| Cross-tool deduplication | Same CVE from Trivy + Grype merged |
| Finding lifecycle | Open → Verified → Risk Accepted → Mitigated → False Positive |
| Portfolio modeling | Product → Engagement → Test hierarchy |
| SLA management | Remediation deadlines by severity |
| Full REST API | CI/CD import automation |
| JIRA integration | Ticket creation from findings |
| Cross-tool trending | Vulnerability count over time, all scanners |
| Multi-domain findings | Container, IaC, DAST, network, pentest |
| Re-import support | Track fixed vulnerabilities across scans |
| Risk acceptance workflows | Formally document accepted risks |
| Can ingest SonarQube results | As one of many scanner inputs |

**Recommendation:** DefectDojo is essential (aggregates all tools). SonarQube is optional (adds code quality metrics beyond security). If you run both, feed SonarQube results into DefectDojo for one unified dashboard.

---

## Shift-Left Linting Layer

The pre-commit hooks are split into two tiers. Tier 1 runs fast quality and linting checks on every commit — these give you immediate feedback and catch issues before they ever reach security scanners. Tier 2 is a lightweight secrets gate only. SAST (Semgrep CE) and IaC scanning (Checkov) are deliberately excluded from pre-commit and run instead as Pull Request checks in GitHub Actions.

**Why Semgrep CE and Checkov are not in pre-commit:**

Both tools perform full-repository analysis on every invocation — Semgrep CE scans all source files against its rule set, Checkov traverses all IaC resources and evaluates cross-resource relationships. Running either on every commit has two practical problems:

1. **Overhead**: Each run adds meaningful latency (seconds to minutes depending on codebase size) to what should be a fast commit cycle. Run dozens of times per day across a working session, this becomes a genuine friction point.
2. **Wrong gate for feature branches**: Developers working in development or feature branches are expected to push code that is not yet hardened — tests-in-progress, scaffolding, placeholder values, or intentionally incomplete configurations. Blocking or warning on every commit in that context creates noise that trains developers to ignore the tool. The meaningful enforcement point is the Pull Request, where code is asserting it is ready to enter a protected branch.

Secrets (Gitleaks) remain in pre-commit because a credential pushed to any branch — including a throwaway feature branch — is a potential exposure from the moment it touches a remote. Branch context does not reduce that risk.

```
COMMIT
  │
  ├─ Tier 1: Quality & Linting (fast, every commit)
  │    terraform fmt/validate · ShellCheck · Ruff · ESLint
  │    hadolint · yamllint · markdownlint · npm audit
  │
  └─ Tier 2: Secrets Gate (before push — Gitleaks only)

PULL REQUEST → GitHub Actions
       Semgrep CE (SAST) · Checkov (IaC) · Trivy · Grype · Gitleaks (full history)
```

### ShellCheck

Purpose-built static analysis for Bash and shell scripts. Catches syntax errors, deprecated constructs, quoting bugs, and unsafe patterns that would otherwise only surface at runtime.

```bash
# Install standalone
brew install shellcheck
# or
pip install shellcheck-py --break-system-packages

# Run manually
shellcheck scripts/*.sh

# Integrates with VS Code via the ShellCheck extension (vscode-shellcheck)
```

**Why it's in Tier 1 and not Semgrep:** Semgrep CE describes its Bash support as "basic" — ShellCheck is the authoritative tool for shell script correctness and covers an entirely different class of issues.

---

### Ruff — Python Linting & Formatting

Ruff is a modern Python linter and formatter written in Rust. It replaces flake8, black, isort, and pylint in a single tool, running 10–100x faster than any of them. It is the current community standard for Python quality tooling.

```bash
pip install ruff --break-system-packages

# Lint (with auto-fix)
ruff check --fix .

# Format
ruff format .

# Check without modifying
ruff check .
```

**Configuration (pyproject.toml or ruff.toml):**

```toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "UP", "S"]   # pep8, pyflakes, warnings, isort, upgrades, bandit-style
ignore = ["S101"]                            # allow assert in tests
```

---

### ESLint — TypeScript / JavaScript Linting

ESLint is the standard linter for TypeScript and JavaScript, including AWS CDK (TypeScript) projects. It catches type errors, unsafe patterns, and style violations before code is compiled or deployed.

```bash
# Install in project (local, not global)
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin

# Run
npx eslint . --ext .ts,.js

# Auto-fix
npx eslint . --ext .ts,.js --fix
```

**Minimal config for CDK TypeScript (eslint.config.mjs):**

```js
import tseslint from 'typescript-eslint';
export default tseslint.config(
  ...tseslint.configs.recommended,
  { rules: { '@typescript-eslint/no-explicit-any': 'warn' } }
);
```

---

### hadolint — Dockerfile Linting

hadolint is a Dockerfile linter that validates syntax and checks best practices against the official Docker recommendations and ShellCheck-powered `RUN` instruction analysis.

```bash
brew install hadolint

# Run
hadolint Dockerfile

# Ignore specific rules
hadolint --ignore DL3008 Dockerfile
```

Common rules it catches: unpinned base image tags, `apt-get install` without `--no-install-recommends`, `COPY` ordering for layer caching, and unsafe `RUN` patterns.

---

### yamllint — YAML / Kubernetes Manifest Linting

Validates YAML syntax and enforces style consistency across Kubernetes manifests, GitHub Actions workflows, Helm values files, and any other YAML.

```bash
pip install yamllint --break-system-packages

# Run
yamllint .

# Relaxed mode (less strict on line length and comments)
yamllint -d relaxed .
```

**Configuration (.yamllint.yml):**

```yaml
extends: relaxed
rules:
  line-length:
    max: 120
  truthy:
    allowed-values: ['true', 'false']
```

---

### markdownlint-cli — Markdown Linting

Enforces consistent Markdown style. Useful for documentation, README files, and any Markdown used in client-facing outputs.

```bash
npm install -g markdownlint-cli

# Run
markdownlint "**/*.md" --ignore node_modules
```

Configure exceptions via `.markdownlintrc` or inline `<!-- markdownlint-disable -->` comments for intentional deviations.

---

### npm audit — Retained as Lightweight Pre-commit SCA

`npm audit` is retained as a Tier 1 pre-commit check for a specific, lightweight purpose: catching known critical/high vulnerabilities in `package-lock.json` at the moment a dependency changes. It is not a replacement for Grype (which covers all ecosystems and produces SBOMs) — it is a fast, zero-setup first line of defence for npm-specific projects.

```bash
# Run manually
npm audit --audit-level=high

# Fix automatically where possible
npm audit fix
```

`npm audit` runs only when `package-lock.json` changes in the pre-commit hook, so it adds minimal friction.

---

## Pre-commit Configuration

```yaml
# .pre-commit-config.yaml

# ─────────────────────────────────────────────────────────────────────────────
# TIER 1: Quality & Linting
# Fast checks — run on every commit. Catch formatting, style, and syntax issues
# before they reach security scanners or CI.
# ─────────────────────────────────────────────────────────────────────────────
repos:

  # --- Terraform: formatting and validation ---
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate

  # --- Python: Ruff (replaces flake8, black, isort) ---
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  # --- Bash / Shell: ShellCheck ---
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0.1
    hooks:
      - id: shellcheck

  # --- Dockerfile: hadolint ---
  - repo: https://github.com/hadolint/hadolint
    rev: v2.12.0
    hooks:
      - id: hadolint-docker

  # --- YAML / Kubernetes manifests: yamllint ---
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        args: [-d, relaxed]

  # --- Markdown: markdownlint ---
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.43.0
    hooks:
      - id: markdownlint

  # --- TypeScript / JavaScript: ESLint (local — requires eslint in project) ---
  - repo: local
    hooks:
      - id: eslint
        name: eslint
        entry: npx eslint
        language: system
        files: \.(js|jsx|ts|tsx)$
        pass_filenames: true

  # --- npm: lightweight dependency audit (triggers on package-lock.json changes only) ---
  - repo: local
    hooks:
      - id: npm-audit
        name: npm audit
        entry: npm audit --audit-level=high
        language: system
        files: package-lock\.json$
        pass_filenames: false

# ─────────────────────────────────────────────────────────────────────────────
# TIER 2: Secrets Gate
# Secrets are the only pre-commit security check. A credential pushed to any
# branch is a potential exposure regardless of context. SAST (Semgrep CE) and
# IaC scanning (Checkov) run at the Pull Request gate in GitHub Actions instead.
# ─────────────────────────────────────────────────────────────────────────────

  # --- Secrets detection: Gitleaks ---
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

```bash
pip install pre-commit --break-system-packages
pre-commit install

# Run all hooks manually against all files (useful for first-time setup)
pre-commit run --all-files

# Run only Tier 1 hooks (by stage, if configured)
pre-commit run --all-files terraform_fmt ruff shellcheck hadolint-docker yamllint markdownlint eslint npm-audit
```

---

## Complete GitHub Actions Workflow

This workflow is the primary security gate. It runs on every Pull Request (all branches) and on direct pushes to `main`. The PR trigger is the critical one — it is where Semgrep CE, Checkov, Trivy, and Grype run for the first time on a given change, and where results are surfaced to the developer and reviewer before merge. Running the same jobs on push to `main` provides a safety net for anything merged without a PR.

Developers working in feature or development branches push freely — no security scans block their commit or push workflow. The pre-commit layer handles linting and secrets only. Security scan results only become visible (and optionally blocking) at the PR stage.

```yaml
# .github/workflows/security.yml
name: Security Scans

# Primary trigger: Pull Requests to any branch (the main enforcement gate).
# Secondary trigger: Direct pushes to main (safety net for non-PR merges).
on:
  pull_request:
  push:
    branches: [main]

jobs:
  sast:
    name: SAST — Semgrep CE
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install semgrep
      - run: semgrep scan --config auto --json --output semgrep-results.json .
        continue-on-error: true
      - if: always()
        run: semgrep scan --config auto --sarif --output semgrep.sarif . || true
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with: { sarif_file: semgrep.sarif }
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: semgrep-results, path: semgrep-results.json }

  iac:
    name: IaC — Checkov
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: bridgecrewio/checkov-action@v12
        with:
          directory: .
          output_format: cli,json,sarif
          output_file_path: console,checkov-results.json,checkov.sarif
          quiet: true
        continue-on-error: true
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with: { sarif_file: checkov.sarif }
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: checkov-results, path: checkov-results.json }

  sca:
    name: SCA — Grype
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
            | sh -s -- -b /usr/local/bin
      - run: grype dir:. -o json > grype-results.json
        continue-on-error: true
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: grype-results, path: grype-results.json }

  container:
    name: Container — Trivy
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t app:${{ github.sha }} .
      - uses: aquasecurity/trivy-action@master
        with: { image-ref: 'app:${{ github.sha }}', format: json, output: trivy-results.json }
      - uses: aquasecurity/trivy-action@master
        with: { image-ref: 'app:${{ github.sha }}', format: sarif, output: trivy.sarif }
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with: { sarif_file: trivy.sarif }
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: trivy-results, path: trivy-results.json }

  secrets:
    name: Secrets — Gitleaks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - run: |
          curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz \
            | tar xz -C /usr/local/bin gitleaks
      - run: gitleaks detect --source . --report-path gitleaks-results.json --report-format json
        continue-on-error: true
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: gitleaks-results, path: gitleaks-results.json }
```

**Import script for DefectDojo:**

```bash
#!/bin/bash
DD_URL="http://localhost:8080"
DD_TOKEN="your-token"
PRODUCT="My App"
ENGAGEMENT="CI-$(date +%Y%m%d)"

for scan in \
  "Semgrep JSON Report:semgrep-results.json" \
  "Checkov Scan:checkov-results.json" \
  "Anchore Grype:grype-results.json" \
  "Trivy Scan:trivy-results.json" \
  "Gitleaks Scan:gitleaks-results.json"; do
  TYPE="${scan%%:*}"; FILE="${scan##*:}"
  [ -f "$FILE" ] && curl -s -X POST "${DD_URL}/api/v2/import-scan/" \
    -H "Authorization: Token ${DD_TOKEN}" \
    -F "scan_type=${TYPE}" -F "file=@${FILE}" \
    -F "product_name=${PRODUCT}" -F "engagement_name=${ENGAGEMENT}" \
    -F "auto_create_context=True" && echo "✓ ${TYPE}"
done
```

---

## Viewing Results — Where to Look

| What | Where | Account Needed? |
|---|---|---|
| All findings unified | **DefectDojo** (self-hosted K8s) | No — local admin |
| SAST findings | DefectDojo + CLI output | No |
| SCA / dependency vulns | DefectDojo (Grype + Trivy imports) | No |
| IaC misconfigurations | DefectDojo (Checkov + Trivy imports) | No |
| Container image vulns | DefectDojo (Trivy import) | No |
| Secrets in code/history | DefectDojo (Gitleaks import) + CLI | No |
| Code quality metrics | SonarQube Community Build [optional] | No — local admin |
| Artifacts & packages | Nexus Repository CE (web UI) | No — local admin |
| Container images | Nexus Docker registry (or Harbor) | No — local admin |
| GitHub-native view | GitHub Security tab (SARIF upload) | Existing GitHub account |
| K8s runtime vulns | `kubectl get vulnerabilityreports` + DefectDojo | No |

---

## Cross-Platform CI Compatibility

| Tool | Install Method | Output Formats |
|---|---|---|
| Semgrep CE | `pip install semgrep` | JSON, SARIF, Text, JUnit, GitLab SAST |
| Checkov | `pip install checkov` or Docker | JSON, SARIF, JUnit, GitLab SAST |
| Trivy | curl installer or Docker | JSON, SARIF, Table, CycloneDX, SPDX |
| Grype | curl installer or Docker | JSON, Table, CycloneDX, SARIF |
| Syft | curl installer or Docker | CycloneDX, SPDX, JSON, Table |
| Gitleaks | curl/binary or Docker | JSON, SARIF, CSV |

**GitHub Actions is the primary CI/CD platform** — the complete workflow above is the reference implementation.

For **Azure DevOps** and **GitLab CI** (tertiary use, typically client repositories): all tools are CLI-based and install via `pip` or `curl` in any runner. Two lightweight integration approaches:

1. **Add to runner**: Install the relevant CLI tools in the pipeline script steps using the same commands as above. No special plugins needed.
2. **Export and import artifacts**: Generate JSON/SARIF output files as pipeline artifacts and import them to the client platform's security dashboard (Azure DevOps Security tab supports SARIF; GitLab CI natively consumes GitLab SAST JSON format, which Checkov and Semgrep output natively with `--output gitlab_sast`).

---

## Language / Framework Coverage Matrix

| Language / Framework | ShellCheck | Ruff | ESLint | hadolint | yamllint | Semgrep CE | Checkov | Trivy | Grype (SCA) | Gitleaks |
|---|---|---|---|---|---|---|---|---|---|---|
| Terraform (HCL) | — | — | — | — | — | ✅ | ✅ 1000+ | ✅ tfsec rules | — | ✅ |
| AWS CDK (TypeScript) | — | — | ✅ | — | — | ✅ TS rules | ✅ synth'd CFN | ✅ npm deps | ✅ npm deps | ✅ |
| CloudFormation | — | — | — | — | ✅ syntax | ✅ | ✅ | ✅ | — | ✅ |
| Python | — | ✅ lint+fmt | — | — | — | ✅ | — | ✅ pip/poetry | ✅ pip/poetry | ✅ |
| JavaScript / TypeScript | — | — | ✅ | — | — | ✅ | — | ✅ npm/yarn | ✅ npm/yarn | ✅ |
| Bash / Shell | ✅ full | — | — | — | — | ✅ basic | — | — | — | ✅ |
| Kubernetes YAML | — | — | — | — | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| Dockerfile | — | — | — | ✅ | — | ✅ | ✅ | ✅ image+cfg | ✅ layers | ✅ |
| Helm Charts | — | — | — | — | ✅ | — | ✅ | ✅ | — | ✅ |
| Container Images | — | — | — | — | — | — | — | ✅ full vuln | ✅ full vuln | — |
| Markdown | — | — | — | — | — | — | — | — | — | ✅ |

> **Note:** markdownlint-cli adds Markdown style/structure linting in the Tier 1 pre-commit layer. It is omitted from the matrix above as it is a style tool rather than a security or language analysis tool. npm audit supplements Grype for npm-specific projects as a fast pre-commit check.

---

## Data Flow Summary

```
1. DEVELOP: Write code in IDE (SonarLint gives real-time SAST feedback)
       │
2. COMMIT — Tier 1 (Quality & Linting, every commit, fast):
       │     ShellCheck (Bash) · Ruff (Python) · ESLint (TS/JS)
       │     hadolint (Dockerfile) · yamllint (K8s/YAML)
       │     markdownlint (Markdown) · terraform fmt/validate
       │     npm audit --audit-level=high (on package-lock.json changes)
       │
3. COMMIT — Tier 2 (Secrets Gate, before push):
       │     Gitleaks only — secrets are caught regardless of branch context
       │     SAST and IaC scanning do NOT run here (see step 5)
       │
4. PUSH: Code goes to GitHub feature/development branch freely
       │     No security scan gates on push — developers work without friction
       │     Azure DevOps / GitLab (tertiary): CLI tools on runners or
       │     JSON/SARIF artifacts exported to those platforms' dashboards
       │
5. PULL REQUEST → GitHub Actions (primary security gate):
       │     Semgrep CE (SAST — full repo scan)
       │     Checkov (IaC — full policy evaluation)
       │     Trivy (container images + filesystem + IaC)
       │     Grype + Syft (full SCA + SBOM generation)
       │     Gitleaks (full git history scan)
       │     Outputs: JSON artifacts + SARIF → GitHub Security tab
       │     Results visible to developer and reviewer before merge
       │     Built images pushed to Nexus Docker registry (or Harbor)
       │
6. IMPORT: Scan results imported to DefectDojo via REST API
       │     SonarQube scans separately and feeds into DefectDojo too
       │
7. REVIEW: DefectDojo dashboard shows unified findings
       │     Track lifecycle: Open → Verified → Mitigated → Closed
       │     SLA tracking, trending, deduplication
       │
8. RUNTIME: Trivy Operator continuously scans deployed K8s workloads
       │     Findings go to DefectDojo
       │
9. SUPPLY CHAIN: All packages flow through Nexus proxy/cache
              Grype + Trivy scan dependencies for known CVEs
              Syft generates SBOMs for compliance
```

---

## Cost Summary

| Tool | License | Cost | External Account |
|---|---|---|---|
| Semgrep CE | LGPL-2.1 | $0 | None |
| Checkov | Apache 2.0 | $0 | None |
| Trivy | Apache 2.0 | $0 | None |
| Trivy Operator | Apache 2.0 | $0 | None |
| Syft | Apache 2.0 | $0 | None |
| Grype | Apache 2.0 | $0 | None |
| Gitleaks | MIT | $0 | None |
| DefectDojo | BSD-3 | $0 | None (self-hosted) |
| SonarQube Community | LGPL-3.0 | $0 | None (self-hosted) |
| Nexus Repository CE | EPL-1.0 | $0 | None (self-hosted) |
| Harbor | Apache 2.0 | $0 | None (self-hosted) |
| pre-commit | MIT | $0 | None |
| ShellCheck | GPL-3.0 | $0 | None |
| Ruff | MIT | $0 | None |
| ESLint | MIT | $0 | None |
| hadolint | GPL-3.0 | $0 | None |
| yamllint | MIT | $0 | None |
| markdownlint-cli | MIT | $0 | None |
| npm audit | — (bundled with npm) | $0 | None |
| **Total** | | **$0** | **None** |

---

## What This Stack Replaces

| Previous Tool | Replaced By | Key Improvement |
|---|---|---|
| **JFrog Artifactory** | Nexus Repository CE (+ Harbor for containers) | Zero cost, self-hosted, same format support, no account |
| **SonarQube** (as sole SAST) | Semgrep CE + DefectDojo (+ optional SonarQube Community) | Faster/lighter for security; multi-tool aggregation |
| **Snyk** (all products) | Semgrep CE + Grype + Trivy | Zero accounts, no scan limits, no paid tier creep |
| **npm audit** | Grype + Trivy fs (CI) + npm audit retained (pre-commit Tier 1) | npm audit kept as a fast pre-commit check; Grype covers all ecosystems with SBOM support in CI |
| **Docker Hub** (private) | Nexus Docker proxy/hosted + Harbor | Self-hosted, no rate limits, scan-on-push, full control |
| **Checkov** | Checkov (keep it) | Already the best open-source IaC scanner |

---

## Kubernetes Self-Hosted Services Summary

| Service | Namespace | Helm Chart | Min Memory | Min CPU | Storage |
|---|---|---|---|---|---|
| DefectDojo | `defectdojo` | `defectdojo/defectdojo` | 2 Gi | 1 core | 10 Gi |
| Nexus Repository CE | `nexus` | `sonatype/nexus-repository-manager` | 2 Gi | 1 core | 50 Gi+ |
| SonarQube [Optional] | `sonarqube` | `sonarqube/sonarqube` | 2 Gi | 1 core | 10 Gi |
| Harbor [Optional] | `harbor` | `harbor/harbor` | 2 Gi | 1 core | 50 Gi+ |
| Trivy Operator | `trivy-system` | `aqua/trivy-operator` | 512 Mi | 0.5 core | Minimal |

**Core stack (DefectDojo + Nexus + Trivy Operator):** ~5 Gi RAM, 2.5 cores
**Full stack with all optional services:** ~10 Gi RAM, 4.5 cores

---

## Implementation Phases

The stack is organized into four phases. The first two phases require no infrastructure and deliver immediate value. Phases three and four build out the self-hosted K8s layer progressively.

---

### Phase 1 — Developer Workstation

**Goal:** Establish the shift-left foundation. Every developer machine has consistent linting, formatting, and secrets detection running on every commit. No infrastructure required.

**Components:** pre-commit, ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint-cli, npm audit, Gitleaks, and the full security CLI suite (available locally on demand).

**Deliverables at completion:**
- `.pre-commit-config.yaml` committed to each repository root
- All Tier 1 linting hooks passing cleanly (`pre-commit run --all-files`)
- Gitleaks secrets gate active on every push
- Semgrep CE, Checkov, Trivy, Grype, and Gitleaks available locally for on-demand scanning

```bash
# 1. Install linting tools
pip install pre-commit ruff yamllint shellcheck-py --break-system-packages
brew install shellcheck hadolint

# 2. Install per-project npm tooling (in each repo)
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
npm install -g markdownlint-cli

# 3. Install security CLI tools (on-demand use + CI preparation)
pip install semgrep checkov --break-system-packages
brew install trivy gitleaks syft grype

# 4. Activate pre-commit in each repository
cp .pre-commit-config.yaml <repo-root>/
pre-commit install
pre-commit run --all-files   # baseline run — fix any existing issues before going live
```

**Validation:** Make a test commit that introduces a secrets pattern (e.g., a dummy AWS key string). Gitleaks should block it. Introduce a shell script with an unquoted variable. ShellCheck should flag it.

---

### Phase 2 — CI/CD Security Gate (GitHub Actions)

**Goal:** Security scanning runs automatically on every Pull Request. Findings are visible in the GitHub Security tab before a merge can occur. No infrastructure required — GitHub-hosted runners execute everything.

**Components:** GitHub Actions security workflow, Semgrep CE, Checkov, Trivy, Grype + Syft, Gitleaks (full history), SARIF upload to GitHub Security tab.

**Deliverables at completion:**
- `.github/workflows/security.yml` committed to each repository
- All five scanners running on Pull Requests and direct pushes to `main`
- SARIF results appearing in the GitHub Security → Code Scanning tab
- JSON artifacts downloadable from each workflow run
- (Optional) Branch protection rule configured to require the workflow to pass before merge

```bash
# No installation required — all tools install within the GitHub Actions runner.
# Commit the workflow file from the "Complete GitHub Actions Workflow" section above
# to each repository at: .github/workflows/security.yml

# To verify locally before committing, run any scanner manually:
semgrep scan --config auto --sarif --output semgrep.sarif .
checkov -d . -o sarif > checkov.sarif
trivy fs --format sarif --output trivy.sarif .
grype dir:. -o json > grype-results.json
gitleaks detect --source . --log-opts="--all" --report-format json --report-path gitleaks.json
```

**Validation:** Open a Pull Request that contains a deliberate IaC misconfiguration (e.g., an S3 bucket with public access enabled in Terraform). Checkov should flag it in the PR checks. Confirm results appear in the Security tab.

---

### Phase 3 — Self-Hosted Infrastructure (Nexus + DefectDojo)

**Goal:** Establish the two core self-hosted services on the Kubernetes cluster. Nexus becomes the proxy and cache for all upstream package registries. DefectDojo becomes the unified dashboard aggregating all scan results from CI/CD.

Deploy Nexus first — once it is running, package managers can be pointed at it and subsequent K8s deployments will pull images through the local cache.

#### Phase 3a — Nexus Repository CE

```bash
helm repo add sonatype https://sonatype.github.io/helm3-charts/
helm repo update

helm install nexus sonatype/nexus-repository-manager \
  --namespace nexus \
  --create-namespace \
  --set nexus.resources.requests.memory=2Gi

# Retrieve initial admin password
kubectl exec -n nexus deploy/nexus-nexus-repository-manager -- \
  cat /nexus-data/admin.password

kubectl port-forward -n nexus svc/nexus-nexus-repository-manager 8081:8081
# Access at http://localhost:8081
```

After Nexus is healthy, create proxy repositories for npm, PyPI, Docker, and Helm (see the Nexus REST API commands in the Nexus section above), then update package manager configuration on all workstations and CI runners to route through Nexus.

#### Phase 3b — DefectDojo

```bash
helm repo add defectdojo \
  https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts
helm repo update

helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  --set django.ingress.enabled=true \
  --set host="defectdojo.local" \
  --set tag="latest"

kubectl get secret defectdojo -n defectdojo \
  -o jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 -d

kubectl port-forward -n defectdojo svc/defectdojo-django 8080:80
```

After DefectDojo is healthy, create a Product for each repository, then activate the API import script (from the DefectDojo section above) as a post-workflow step in GitHub Actions. From this point, every PR scan automatically populates the DefectDojo dashboard.

**Deliverables at completion:**
- Nexus proxying npm, PyPI, Docker Hub, and Helm
- All workstation package installs routing through Nexus cache
- DefectDojo running and accessible
- Products created per repository
- CI scan results importing to DefectDojo on every PR workflow run
- Unified finding dashboard operational with deduplication and lifecycle tracking

**Validation:** Run a full workflow against a PR. Confirm scan results appear in DefectDojo under the correct Product and Engagement. Confirm `npm install` and `pip install` show cache hits in Nexus after the first run.

---

### Phase 4 — Runtime Security and Optional Enhancements

**Goal:** Add continuous runtime scanning of the K8s cluster itself, and optionally extend the stack with code quality metrics and a dedicated container registry.

#### Trivy Operator — Kubernetes Runtime Scanning

Continuously scans all running container images and K8s workload configurations. Results feed into DefectDojo via the existing import pipeline.

```bash
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace

# Verify scanning is active
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
```

#### SonarQube Community Build [Optional]

Adds code quality metrics (complexity, duplication, maintainability, test coverage, quality gates) alongside the security findings already covered by Semgrep. Results can be imported into DefectDojo. Add only if code quality visibility beyond security is a priority.

```bash
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm install sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  --create-namespace

kubectl port-forward -n sonarqube svc/sonarqube-sonarqube 9000:9000
# Default login: admin / admin — change immediately
```

#### Harbor [Optional]

Adds container-specific registry features beyond what Nexus provides: scan-on-push via Trivy, image signing via Cosign/Notation, tag retention policies, and robot accounts for CI credentials. Complements Nexus rather than replacing it — Nexus handles all non-container package types; Harbor handles container images only.

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update

helm install harbor harbor/harbor \
  --namespace harbor \
  --create-namespace \
  --set expose.type=nodePort \
  --set externalURL=https://harbor.local \
  --set harborAdminPassword=your-secure-password

kubectl port-forward -n harbor svc/harbor-portal 8443:443
```

**Deliverables at completion:**
- Trivy Operator actively generating VulnerabilityReports for all cluster workloads
- (Optional) SonarQube running with quality gates configured per repository
- (Optional) Harbor serving as the container registry with scan-on-push active
- All optional service findings feeding into DefectDojo
