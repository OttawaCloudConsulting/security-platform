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
│  Pre-Push Tier 2 — Secrets Gate (before push)                              │
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
| **K8s Runtime Anomaly Detection** | **Falco CE** + **FalcoSidekick** | Apache 2.0 | No | — |
| **Image Signing / SLSA Provenance** | **Cosign** (keyless) + **slsa-github-generator** + **Kyverno** | Apache 2.0 | No | — |

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

# Protect mode — scan only staged changes (used by the pre-push hook)
gitleaks protect --staged
```

The `protect --staged` mode is what the pre-push hook runs (see the `.pre-commit-config.yaml` Tier 2 section). It scans only staged changes rather than the full history, keeping the hook fast.

---

### 6. Nexus Repository Community Edition — Artifact & Package Management

Nexus Repository Community Edition (formerly "OSS") is the JFrog Artifactory equivalent. It's a universal artifact repository manager — free, self-hosted, no external account needed. As of version 3.77.0, the Community Edition gained access to previously Pro-only format support including Docker, npm, PyPI, and Kubernetes deployment via external PostgreSQL.

**What it does that no other tool in this stack provides:**

- **Proxies and caches upstream registries** — npm, PyPI, Docker Hub, Maven, Helm, Go, NuGet, RubyGems, Apt, Yum, and more. Your `npm install` and `pip install` commands pull through Nexus, which caches locally. Faster builds, protection against upstream outages, and a single audit point.
- **Hosts private packages** — internal npm modules, Python packages, or Terraform modules served with native package manager protocol.
- **Provides a single source of truth for all binaries** — Docker images, Helm charts, npm packages, Python wheels, and Terraform providers in one place with a web UI.
- **Provides a single audit and caching point for all upstream package traffic** — every `npm install`, `pip install`, and `docker pull` flows through one place, creating a complete record of what was fetched and when. This is an audit point, not a security boundary.

  **What Nexus does NOT do by default:** Nexus Community Edition does not scan content for vulnerabilities. A compromised upstream package flows through Nexus to your build unmodified. Scanning is the responsibility of Grype and Trivy. Controlling what enters the supply chain beyond caching requires additional policy configuration: content selectors, repository blocking rules, or allowlist-only hosted repositories. The default proxy configuration described here provides visibility and caching, not content enforcement.

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
NEXUS_AUTH="admin:${NEXUS_PASSWORD:-your-password}"  # Set NEXUS_PASSWORD as an environment variable

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

> **`contentMaxAge: -1` tradeoff:** Setting `contentMaxAge` to `-1` means Nexus caches package content indefinitely without rechecking the upstream registry. This improves build reproducibility (the same package version always resolves to the same cached artifact) and protects against upstream outages. The downside: if an upstream package is compromised and later patched or yanked, the compromised version persists in the Nexus cache until it is manually purged. For each repository, you can set a shorter TTL (e.g., `86400` for 24 hours) to limit this exposure window, at the cost of additional upstream traffic and reduced reproducibility. The Grype and Trivy scans in CI are the primary mechanism for detecting compromised packages that have been cached.

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

#### Group Repository Ordering and Dependency Confusion Protection

When using Nexus group repositories (npm-group, pypi-group, etc.) that combine a hosted repository with a proxy repository, **repository ordering matters for dependency confusion protection**.

Dependency confusion is an attack where a maliciously named package on the public registry (npmjs.org, pypi.org) shares the name of an internal package. If the proxy repository is searched before the hosted repository, the upstream attacker-controlled package wins.

Always place hosted (internal) repositories **before** proxy (upstream) repositories in the group member list:

```
Correct order (internal-first):
  Group members: [my-internal-npm-hosted, npm-proxy]
  → A package found in the hosted repo is returned immediately; upstream is never consulted

Wrong order (upstream-first):
  Group members: [npm-proxy, my-internal-npm-hosted]
  → An attacker who publishes a higher-version package to npmjs.org under your internal package name wins
```

Configure group member ordering in the Nexus UI: Repository → your-group-repo → Group → Members → drag hosted repositories above proxy repositories. This does not affect packages that only exist upstream; it only matters when the same name exists in both locations.

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

# Replace 2.x.y with the current stable release from:
# https://github.com/DefectDojo/django-DefectDojo/releases
helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  --set django.ingress.enabled=true \
  --set host="defectdojo.local" \
  --set tag="2.x.y"

kubectl get secret defectdojo -n defectdojo \
  -o jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 -d

kubectl port-forward -n defectdojo svc/defectdojo-django 8080:80
```

#### Storing Helm Values

Store the install configuration in a version-controlled file instead of passing `--set` flags inline. This makes the deployment reproducible and is required before you can run `helm upgrade` reliably.

```yaml
# defectdojo-values.yaml — commit this to your infrastructure repository
django:
  ingress:
    enabled: true
host: "defectdojo.local"
tag: "2.x.y"  # Update this value when upgrading; check release notes first
```

Install or reinstall using the values file:

```bash
helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  -f defectdojo-values.yaml
```

**Upgrade procedure:**

1. Back up the DefectDojo PostgreSQL database before any upgrade: `kubectl exec -n defectdojo deploy/defectdojo-postgresql -- pg_dump -U defectdojo defectdojo > defectdojo-backup-$(date +%Y%m%d).sql`
2. Review the release notes at <https://github.com/DefectDojo/django-DefectDojo/releases> for breaking changes or migration steps
3. Update `tag` in `defectdojo-values.yaml` to the new version
4. Run: `helm upgrade defectdojo defectdojo/defectdojo --namespace defectdojo -f defectdojo-values.yaml`

**Or Docker Compose:**

```bash
git clone https://github.com/DefectDojo/django-DefectDojo
cd django-DefectDojo
./docker/docker-compose-check.sh
docker compose up -d
docker compose logs initializer | grep "Admin password"
```

> **Version pinning for Docker Compose:** The default `docker-compose.yml` may reference `latest` tags. Before deploying, edit the compose file to pin the DefectDojo image to a specific version tag (e.g., `defectdojo/defectdojo-django:2.x.y`). Check <https://github.com/DefectDojo/django-DefectDojo/releases> for the current stable version. Commit the modified compose file to version control alongside a record of which version is deployed.

**Importing scan results:**

```bash
DD_URL="http://localhost:8080"
DD_TOKEN="${DEFECTDOJO_API_TOKEN:-your-api-token}"  # Set via environment variable or GitHub Actions secret

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

> **Credentials:** Never hardcode API tokens in scripts or commit them to version control. In GitHub Actions, store the token as a repository secret:
> Settings → Secrets and variables → Actions → New repository secret
> Name it `DEFECTDOJO_API_TOKEN`. Reference it in workflows as `${{ secrets.DEFECTDOJO_API_TOKEN }}`.
> Retrieve your DefectDojo API token from the DefectDojo UI: Profile → API v2 Key.

**What DefectDojo gives you:** Consolidated view of all findings, automatic deduplication, finding lifecycle tracking (Open → Under Review → Mitigated → Closed), trending dashboards, per-product/engagement views, SLA tracking, and JIRA integration.

#### Managing Finding Volume

This stack generates findings faster than a single developer can triage on first run. Independent operational analysis estimates 125–750 findings per repository across all scanners combined, depending on codebase size, IaC complexity, and how many dependencies are in use. Without a triage process, DefectDojo quickly becomes a write-only database — findings accumulate, nothing gets closed, and the tool stops informing decisions.

The following practices make the stack sustainable:

**Suppress pre-existing IaC findings with a Checkov baseline.** On first run, the majority of Checkov findings will be pre-existing issues unrelated to the current PR. Use the baseline workflow (documented in the Checkov section above) to snapshot the current state and focus only on new findings going forward:

```bash
# Run once in each repository to establish the baseline
checkov -d . --create-baseline
# Commit .checkov.baseline to the repository
# Subsequent runs: checkov -d . --baseline .checkov.baseline
```

See the Checkov baseline workflow above for full details.

**Enable DefectDojo deduplication.** DefectDojo's deduplication engine merges identical findings from multiple scanners (e.g., the same CVE reported by both Trivy and Grype). Configure it per product: DefectDojo UI → Products → select product → Edit → Deduplication algorithm → select the algorithm appropriate for your scanner combination (typically "Legacy" for general use). Without deduplication enabled, the same vulnerability appears multiple times and inflates apparent finding volume.

**Filter by severity on first triage pass.** Configure DefectDojo to auto-close or suppress Info and Low severity findings initially. The first triage pass should focus exclusively on Critical and High findings. Medium findings are a second pass. Info/Low findings can be reviewed in bulk monthly or suppressed by rule if they are not actionable for this codebase. Severity auto-close rules: DefectDojo UI → System Settings → Finding Auto-Close.

**Establish a weekly time-boxed triage cadence.** Rather than triaging every finding as it arrives, reserve a fixed time window each week — 30 minutes is sufficient for steady-state once the initial backlog is addressed. Review new Critical/High findings from the past week, close or accept anything that is a known false positive, and mark duplicates. This cadence prevents the triage backlog from compounding while keeping the investment predictable and sustainable.

A written triage SOP — even a short checklist — is the difference between a security program and a security dashboard. Without it, DefectDojo becomes infrastructure that nobody looks at.

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

### 11. Falco CE + FalcoSidekick — Kubernetes Runtime Anomaly Detection

Falco is a CNCF Graduated kernel-level runtime security tool. It uses eBPF (or kernel module) syscall interception and the Kubernetes audit log plugin to detect anomalous behavior that static scanning cannot surface: unexpected processes spawning inside containers, privilege escalation attempts, container escapes, unexpected outbound connections from security namespaces, and `kubectl exec` access to sensitive pods.

**What Falco detects that static tools miss:**

- A compromised application container executing `/bin/sh` or running `curl` to exfiltrate data
- A process inside DefectDojo or Nexus spawning an unexpected child process (indicates post-exploitation)
- `kubectl exec` into any pod in the `defectdojo`, `nexus`, or `falco-system` namespaces
- Privilege escalation via `setuid` binaries or capability abuse inside containers
- File writes to read-only container filesystems

**Install Falco with FalcoSidekick (alert routing):**

```bash
helm repo add falco https://falcosecurity.github.io/charts
helm repo update

# falco-values.yaml — version-control this file
cat > falco-values.yaml <<'EOF'
driver:
  kind: ebpf  # preferred; falls back to kernel module if eBPF unavailable

falcosidekick:
  enabled: true
  config:
    slack:
      webhookurl: ""          # Set to your Slack incoming webhook URL, or leave blank
    webhook:
      address: ""             # Generic webhook endpoint (e.g. Alertmanager)
  webui:
    enabled: true             # FalcoSidekick web UI at port 2802

customRules:
  custom-stack-rules.yaml: |-
    # Shell spawned inside a security-stack pod
    - rule: Shell Spawned in Security Namespace Pod
      desc: A shell was spawned inside a pod running in a security-sensitive namespace
      condition: >
        spawned_process and
        container and
        proc.name in (shell_binaries) and
        k8s.ns.name in (defectdojo, nexus, falco-system, kyverno, trivy-system)
      output: >
        Shell spawned in security namespace (user=%user.name pod=%k8s.pod.name
        ns=%k8s.ns.name image=%container.image.repository:%container.image.tag
        cmd=%proc.cmdline)
      priority: WARNING
      tags: [security-stack, shell]

    # Unexpected exec into a security namespace pod via kubectl
    - rule: kubectl exec into Security Namespace
      desc: kubectl exec was used to access a pod in a security-sensitive namespace
      condition: >
        ka.verb=create and
        ka.target.resource=pods/exec and
        ka.target.namespace in (defectdojo, nexus, falco-system, kyverno, trivy-system)
      output: >
        kubectl exec into security namespace (user=%ka.user.name pod=%ka.target.name
        ns=%ka.target.namespace uri=%ka.uri)
      priority: WARNING
      source: k8s_audit
      tags: [security-stack, kubectl-exec]

    # Outbound network connection from a security namespace pod
    - rule: Unexpected Outbound Connection from Security Namespace
      desc: A security-stack pod made an unexpected outbound network connection
      condition: >
        outbound and
        container and
        k8s.ns.name in (defectdojo, nexus) and
        not fd.sip.name in (allowed_outbound_destinations_map)
      output: >
        Unexpected outbound connection (pod=%k8s.pod.name ns=%k8s.ns.name
        dst=%fd.rip:%fd.rport image=%container.image.repository)
      priority: WARNING
      tags: [security-stack, network]

    # Write to /etc inside any container (common post-exploitation step)
    - rule: Write to /etc in Container
      desc: A process wrote to /etc inside a container — unusual in immutable images
      condition: >
        open_write and
        container and
        fd.name startswith /etc
      output: >
        Write to /etc in container (pod=%k8s.pod.name ns=%k8s.ns.name
        file=%fd.name user=%user.name cmd=%proc.cmdline)
      priority: WARNING
      tags: [security-stack, filesystem]
EOF

helm install falco falco/falco \
  --namespace falco-system \
  --create-namespace \
  -f falco-values.yaml
```

**Enable Kubernetes audit log plugin** (required for the `kubectl exec` rule):

The Kubernetes audit log plugin sends API server audit events to Falco. Configuration is cluster-specific — consult your cluster provider's documentation for enabling audit log webhooks. For kubeadm clusters, add the webhook configuration to the kube-apiserver manifest.

**Verify Falco is running:**

```bash
kubectl get pods -n falco-system
kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=50

# Trigger a test alert — exec into a non-security pod to confirm rules fire
kubectl run test-pod --image=alpine --restart=Never -- sleep 60
kubectl exec test-pod -- ls /etc
# → Should appear in Falco logs as a write/exec event

# FalcoSidekick web UI (port-forward to view alert dashboard)
kubectl port-forward -n falco-system svc/falco-falcosidekick-ui 2802:2802
# → Open http://localhost:2802
```

---

### 12. Cosign (Keyless) + SLSA Provenance + Kyverno — Image Signing and Admission Control

This section implements the full artifact integrity chain:

1. **Cosign keyless signing** — images are signed in CI using the GitHub Actions OIDC token. No private keys are stored or managed. The signing identity is the GitHub Actions workflow URL.
2. **SLSA Level 2 provenance** — `slsa-github-generator` produces a signed provenance attestation linking each image to a specific commit, repository, and CI build. If an image is built outside the CI pipeline, the attestation will be missing.
3. **Kyverno admission control** — a ClusterPolicy requires all pods to use images with a valid Cosign attestation matching the GitHub Actions OIDC issuer. Unsigned images are rejected before they run.

**Why keyless?** Keyless Cosign signing (Sigstore Fulcio CA + Rekor transparency log) requires no GPG key generation, no key rotation schedule, and no key storage infrastructure. The signing credential is the ephemeral GitHub OIDC token — valid for the duration of the job, cryptographically bound to the workflow identity.

#### GitHub Actions `sign` Job

Add this job to `.github/workflows/security.yml` after the `container` job:

```yaml
  sign:
    name: Sign — Cosign Keyless + SLSA Provenance
    needs: [container]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write       # Required for keyless Cosign OIDC signing
      packages: write       # Required if pushing to GHCR or another registry
      actions: read         # Required by slsa-github-generator
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases

      - name: Install Cosign
        uses: sigstore/cosign-installer@<SHA>  # pin to current SHA: https://github.com/sigstore/cosign-installer/releases

      - name: Log in to registry
        run: |
          echo "${{ secrets.REGISTRY_PASSWORD }}" | \
            docker login ghcr.io -u "${{ github.actor }}" --password-stdin

      - name: Build and push image
        id: build
        run: |
          IMAGE="ghcr.io/${{ github.repository }}:${{ github.sha }}"
          docker build -t "${IMAGE}" .
          docker push "${IMAGE}"
          DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE}" | cut -d@ -f2)
          echo "image=${IMAGE}" >> "$GITHUB_OUTPUT"
          echo "digest=${DIGEST}" >> "$GITHUB_OUTPUT"

      - name: Sign image with Cosign (keyless — uses GitHub OIDC)
        env:
          IMAGE: ${{ steps.build.outputs.image }}
          DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          cosign sign --yes \
            --rekor-url https://rekor.sigstore.dev \
            "${IMAGE}@${DIGEST}"

      - name: Generate SLSA provenance
        uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@<SHA>
        # pin to current SHA: https://github.com/slsa-framework/slsa-github-generator/releases
        with:
          image: ${{ steps.build.outputs.image }}
          digest: ${{ steps.build.outputs.digest }}
          registry-username: ${{ github.actor }}
          registry-password: ${{ secrets.REGISTRY_PASSWORD }}
```

**Verification commands:**

```bash
# Verify image signature (keyless — GitHub OIDC issuer)
cosign verify \
  --certificate-identity-regexp "https://github.com/<org>/<repo>/\.github/workflows/security\.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/<org>/<repo>:<sha>

# Verify SLSA provenance attestation
cosign verify-attestation \
  --type slsaprovenance \
  --certificate-identity-regexp "https://github.com/slsa-framework/slsa-github-generator/\.github/workflows/.*@refs/tags/v.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/<org>/<repo>:<sha>
```

#### Kyverno Admission Controller

Kyverno enforces image signing as a Kubernetes admission policy. Unsigned images are rejected before scheduling.

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# kyverno-values.yaml — version-control this file
cat > kyverno-values.yaml <<'EOF'
replicaCount: 1            # Increase to 3 for production HA
EOF

helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  -f kyverno-values.yaml
```

**ClusterPolicy — require signed images in production namespaces:**

```yaml
# kyverno-require-signed-images.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
  annotations:
    policies.kyverno.io/title: Require Cosign Signed Images
    policies.kyverno.io/description: >
      All container images must be signed with Cosign using the GitHub Actions
      OIDC keyless signing workflow. Unsigned images are blocked before scheduling.
spec:
  validationFailureAction: Enforce  # Block unsigned images (use Audit during rollout)
  background: false
  rules:
    - name: check-image-signature
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces:
                - production
                - staging
      verifyImages:
        - imageReferences:
            - "ghcr.io/<org>/*"
          attestors:
            - count: 1
              entries:
                - keyless:
                    subject: "https://github.com/<org>/<repo>/.github/workflows/security.yml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

```bash
# Apply the policy
kubectl apply -f kyverno-require-signed-images.yaml

# Verify Kyverno is running
kubectl get pods -n kyverno

# Test enforcement — attempt to deploy an unsigned image (should be rejected)
kubectl run unsigned-test --image=alpine:latest -n production
# → Expected: admission webhook denied — image not signed

# Test with a signed image — should be admitted
kubectl run signed-test \
  --image=ghcr.io/<org>/<repo>:<signed-sha> \
  -n production
```

**Rollout recommendation:** Deploy Kyverno with `validationFailureAction: Audit` first. Audit mode logs policy violations without blocking. Review the audit findings (`kubectl get policyreport -A`) to confirm only expected images are in use before switching to `Enforce`.

#### Optional: Commit Signing (Git Level)

For commit-level integrity, configure Git to sign commits using an SSH key (simpler than GPG):

```bash
# Generate a dedicated signing key (separate from your authentication key)
ssh-keygen -t ed25519 -C "commit-signing-key" -f ~/.ssh/signing_key

# Configure Git to use SSH signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/signing_key.pub
git config --global commit.gpgsign true

# Add the public key to GitHub: Settings → SSH and GPG keys → New signing key
# (select "Signing Key" type — not "Authentication Key")

# Verify a signed commit
git verify-commit HEAD
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

> **Client-Side Enforcement Limitation:** Pre-commit hooks run entirely on the developer workstation and can be bypassed with `git commit --no-verify` or `git push --no-verify`, including the Gitleaks secrets gate. The Phase 2 GitHub Actions workflow is the compensating control — Gitleaks runs again in CI against the full repository history, and Semgrep/Checkov/Grype run at the PR gate regardless of what happened locally. The only mechanism that cannot be bypassed client-side is branch protection with required CI checks: without it, the CI gate is advisory. Use pre-commit as the fast inner loop it is designed to be; rely on the CI gate and branch protection for enforcement.

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
  # Bypass: git push --no-verify skips this hook — CI is the compensating control (see ADR-011)
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
        stages: [pre-push]
        args: [protect, --staged]
```

#### Bypass and Compensating Controls

> **Warning:** `git push --no-verify` bypasses the Gitleaks pre-push hook entirely. This is a Git feature — no special permissions required.

The pre-commit/pre-push framework is defense-in-depth: it catches secrets before they reach the remote, but it is not the sole enforcement mechanism. The CI/CD pipeline (Milestone 2) runs Gitleaks against the full git history on every pull request and push to protected branches. Because CI runs server-side in GitHub Actions, it cannot be bypassed from the developer workstation.

The enforcement chain:
1. **Pre-push hook (this section)** — client-side, bypassable with `--no-verify`
2. **CI/CD Gitleaks scan (M2)** — server-side, non-bypassable
3. **Branch protection + required status checks** — prevents merge without passing CI

See [ADR-011](docs/adr/adr011-precommit-bypass-warning.md) for the full rationale.

### Keeping Hooks Current

Pinned hook versions (`rev: v8.21.2`, `rev: v0.8.4`, etc.) provide reproducibility but require active maintenance — a version pinned today accumulates unpatched bugs and missing detection rules over time. Run `pre-commit autoupdate` monthly to bump all `rev:` entries to their latest upstream tags:

```bash
pre-commit autoupdate        # updates all rev: entries in .pre-commit-config.yaml
pre-commit run --all-files   # validate nothing broke after the update
```

Commit the resulting changes to `.pre-commit-config.yaml` as a routine maintenance commit. For GitHub Actions SHA digests, Dependabot or Renovate automates the equivalent process — configure either tool with a monthly schedule (see the SHA pinning note in the workflow file) so action versions track upstream releases without manual monitoring across 20+ components.

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

# ─────────────────────────────────────────────────────────────────────────────
# SHA PINNING NOTE
#
# All GitHub Actions below are pinned to immutable SHA digests rather than
# mutable version tags (e.g. @v4, @master). Mutable tags can be silently
# updated by the action maintainer — intentionally or after a supply-chain
# compromise — and your workflow will execute the changed code without notice.
# SHA pinning ensures you run exactly the code you reviewed.
#
# To keep SHAs current without manual tracking, enable Dependabot for
# GitHub Actions in your repository:
#
#   Create .github/dependabot.yml:
#     version: 2
#     updates:
#       - package-ecosystem: "github-actions"
#         directory: "/"
#         schedule:
#           interval: "monthly"
#
# Dependabot will open PRs updating SHA digests when new versions are
# released. Review the release notes before merging. Alternatively, Renovate
# Bot supports the same workflow with more configuration options.
#
# To find the current SHA for any action, run:
#   gh api repos/<owner>/<repo>/git/ref/tags/<version> --jq '.object.sha'
# or visit the action's releases page and copy the "full commit SHA" shown
# next to each release tag.
# ─────────────────────────────────────────────────────────────────────────────

jobs:
  sast:
    name: SAST — Semgrep CE
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
      - run: pip install semgrep
      - name: Run Semgrep (JSON output for DefectDojo)
        run: semgrep scan --config auto --error --json --output semgrep-results.json .
      - name: Run Semgrep (SARIF output for GitHub Security tab)
        if: always()
        run: semgrep scan --config auto --sarif --output semgrep.sarif . || true
      - uses: github/codeql-action/upload-sarif@<SHA>  # v3 — pin to current SHA: https://github.com/github/codeql-action/releases
        if: always()
        continue-on-error: true
        with: { sarif_file: semgrep.sarif }
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: semgrep-results, path: semgrep-results.json }

  iac:
    name: IaC — Checkov
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
      - uses: bridgecrewio/checkov-action@<SHA>  # v12 — pin to current SHA: https://github.com/bridgecrewio/checkov-action/releases
        with:
          directory: .
          output_format: cli,json,sarif
          output_file_path: console,checkov-results.json,checkov.sarif
          quiet: true
          soft_fail: false
      - uses: github/codeql-action/upload-sarif@<SHA>  # v3 — pin to current SHA: https://github.com/github/codeql-action/releases
        if: always()
        continue-on-error: true
        with: { sarif_file: checkov.sarif }
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: checkov-results, path: checkov-results.json }

  sca:
    name: SCA — Grype
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
      - run: |
          curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
            | sh -s -- -b /usr/local/bin
      - name: Run Grype (fails on high/critical findings)
        run: grype dir:. --fail-on high -o json > grype-results.json
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: grype-results, path: grype-results.json }

  container:
    name: Container — Trivy
    runs-on: ubuntu-latest
    # Runs on both pull_request and push events so container vulnerabilities
    # are visible to reviewers before merge, not only after.
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
      - run: docker build -t app:${{ github.sha }} .
      - name: Run Trivy (JSON output for DefectDojo)
        uses: aquasecurity/trivy-action@<SHA>  # pin to current SHA: https://github.com/aquasecurity/trivy-action/releases
        with:
          image-ref: 'app:${{ github.sha }}'
          format: json
          output: trivy-results.json
          exit-code: '1'
          severity: 'HIGH,CRITICAL'
      - name: Run Trivy (SARIF output for GitHub Security tab)
        if: always()
        uses: aquasecurity/trivy-action@<SHA>  # pin to current SHA: https://github.com/aquasecurity/trivy-action/releases
        with:
          image-ref: 'app:${{ github.sha }}'
          format: sarif
          output: trivy.sarif
      - uses: github/codeql-action/upload-sarif@<SHA>  # v3 — pin to current SHA: https://github.com/github/codeql-action/releases
        if: always()
        continue-on-error: true
        with: { sarif_file: trivy.sarif }
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: trivy-results, path: trivy-results.json }

  secrets:
    name: Secrets — Gitleaks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
        with: { fetch-depth: 0 }
      - run: |
          curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz \
            | tar xz -C /usr/local/bin gitleaks
      - name: Run Gitleaks (fails on any secret found)
        run: gitleaks detect --source . --report-path gitleaks-results.json --report-format json
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: gitleaks-results, path: gitleaks-results.json }

  sign:
    name: Sign — Cosign Keyless + SLSA Provenance
    # Only runs after container job passes — signs the same image Trivy scanned
    needs: [container]
    # Only sign on push to main (not on PRs — no image was pushed)
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write   # Required for keyless Cosign OIDC signing
      packages: write   # Required for pushing attestation to GHCR
      actions: read     # Required by slsa-github-generator
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases

      - name: Install Cosign
        uses: sigstore/cosign-installer@<SHA>  # pin to current SHA: https://github.com/sigstore/cosign-installer/releases

      - name: Log in to registry
        run: |
          echo "${{ secrets.REGISTRY_PASSWORD }}" | \
            docker login ghcr.io -u "${{ github.actor }}" --password-stdin

      - name: Build and push image
        id: build
        run: |
          IMAGE="ghcr.io/${{ github.repository }}:${{ github.sha }}"
          docker build -t "${IMAGE}" .
          docker push "${IMAGE}"
          DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE}" | cut -d@ -f2)
          echo "image=${IMAGE}" >> "$GITHUB_OUTPUT"
          echo "digest=${DIGEST}" >> "$GITHUB_OUTPUT"

      - name: Sign image with Cosign (keyless — uses GitHub OIDC)
        env:
          IMAGE: ${{ steps.build.outputs.image }}
          DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          cosign sign --yes \
            --rekor-url https://rekor.sigstore.dev \
            "${IMAGE}@${DIGEST}"
```

**Import script for DefectDojo:**

```bash
#!/bin/bash
# Set DEFECTDOJO_API_TOKEN as a GitHub Actions secret or export it locally:
#   export DEFECTDOJO_API_TOKEN="your-token-here"
# In GitHub Actions, reference it as: ${{ secrets.DEFECTDOJO_API_TOKEN }}
DD_URL="http://localhost:8080"
DD_TOKEN="${DEFECTDOJO_API_TOKEN}"
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
    -F "auto_create_context=True" && echo "Imported: ${TYPE}"
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
| Falco + FalcoSidekick | `falco-system` | `falco/falco` | 512 Mi per node (DaemonSet) | 0.5 core per node | Minimal |
| Kyverno | `kyverno` | `kyverno/kyverno` | 512 Mi | 0.5 core | None |

**Core stack (DefectDojo + Nexus + Trivy Operator + Falco + Kyverno):** ~6.5 Gi RAM, 3.5 cores (+Falco DaemonSet overhead per node)
**Full stack with all optional services:** ~11.5 Gi RAM, 5.5 cores

---

## Network Security

### Kubernetes NetworkPolicies

**By default, Kubernetes allows all pod-to-pod traffic across all namespaces.** A compromised pod in any application namespace can reach DefectDojo's API (read, modify, or delete all vulnerability findings), Nexus's API (upload malicious packages into the cache), SonarQube's API (disable quality rules), and Harbor's API (push malicious images). The security stack namespaces hold sensitive data and administrative surfaces — they must be isolated from application workload namespaces.

The starting pattern is a **default-deny ingress** NetworkPolicy applied to each security service namespace:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: defectdojo  # apply per namespace
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Apply this to each namespace: `defectdojo`, `nexus`, `sonarqube`, `harbor`, `trivy-system`. Then add explicit allow rules for required traffic. For example, to permit CI runner pods to reach the DefectDojo API:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ci-runner-ingress
  namespace: defectdojo
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: defectdojo
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ci-runners
      ports:
        - protocol: TCP
          port: 80
```

**Note:** NetworkPolicies are only enforced when the cluster has a CNI plugin that supports them (e.g., Calico, Cilium, Weave Net). Clusters using the default Kubenet CNI (common in some managed K8s offerings) silently ignore NetworkPolicy objects — verify your CNI before relying on these policies for isolation.

Reference: [Kubernetes NetworkPolicy documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

### TLS / Internal Communication

**All services in this stack currently communicate over plaintext HTTP.** The package manager configurations shown in this document use `insecure-registries` in the Docker daemon config and `trusted-host` in pip configuration — both of which disable certificate verification entirely for the configured host. This means:

- Packages transiting between Nexus and clients can be intercepted and replaced
- DefectDojo API tokens (used by the CI import script) are transmitted in cleartext
- Any pod with network access can observe credentials and scan results

The recommended approach is **cert-manager** for automated TLS certificate provisioning and renewal. cert-manager is free, open-source, and integrates with the Kubernetes Ingress layer.

Reference: [cert-manager documentation](https://cert-manager.io/docs/)

At minimum, enforce HTTPS at the **Ingress layer** for all services. Once TLS is operational:

- Remove `insecure-registries` from the Docker daemon configuration on all workstations and CI runners
- Remove `trusted-host = localhost` and `index-url = http://...` from pip configuration; replace with the HTTPS equivalent
- Update all service URLs in package manager configs from `http://` to `https://`

A full cert-manager installation guide is out of scope for this document. The upstream docs cover both self-signed certificates (sufficient for internal-only services) and Let's Encrypt issuers (suitable if services are reachable via a real DNS name).

---

## Monitoring the Security Stack

**The security stack itself is unmonitored by default.** Tools that silently fail provide a dangerous illusion of coverage — if Trivy Operator stops scanning, Nexus goes down, or DefectDojo's import pipeline breaks, nothing alerts. Scans stop running but the dashboard continues to show the last known state as if it were current.

**Minimum alerting targets:**

| Condition | Risk if undetected |
|---|---|
| Nexus disk usage above threshold | Blob store fills; builds start failing silently as packages cannot be cached |
| DefectDojo import failures | Scan results stop populating the dashboard; the security picture goes stale without indication |
| Trivy Operator vulnerability database staleness | Runtime scans run against an outdated DB; new CVEs go undetected |
| Pod `CrashLoopBackOff` in any security namespace | Service unavailable; no visibility into which tool is down or for how long |

**Recommended approach:** `kube-prometheus-stack` deploys Prometheus, Grafana, and Alertmanager as a single Helm release. All three are free and open-source.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

This installs cluster-wide scraping of pod metrics, a Grafana instance with pre-built Kubernetes dashboards, and Alertmanager for routing alerts to email, Slack, or PagerDuty. Nexus exposes Prometheus metrics natively on `/service/metrics/prometheus` when the Metrics capability is enabled. DefectDojo requires a sidecar or custom scrape config to surface application-level metrics.

**Full monitoring setup is out of scope for this document** — the above is sufficient to get started. The security stack should be considered development-grade until alerting is active on all four conditions above. A stack that can fail silently is not a security control.

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
- Branch protection configured on the `main` branch (required — without this, the CI security gate is advisory-only and provides zero enforcement)

  **Configure in GitHub:** Settings → Branches → Branch protection rules → Add rule
  - Branch name pattern: `main`
  - Enable: **Require a pull request before merging**
  - Enable: **Require status checks to pass before merging** — add each security workflow job as a required check: `sast`, `iac`, `sca`, `container`, `secrets`
  - Enable: **Do not allow bypassing the above settings**
  - Enable: **Restrict who can push to matching branches** (block direct pushes to `main`)

  Without branch protection, a developer can push directly to `main` (bypassing all PR-based scanning), and failing scanner jobs have no effect on merge eligibility. The `continue-on-error` changes described above only enforce quality gates when branch protection makes those status checks required.

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

Validate branch protection is active: attempt `git push origin main` directly from a local branch without opening a PR. GitHub should reject the push with a branch protection error. Confirm that a PR with a failing required status check cannot be merged (the merge button should be disabled or show a blocking status).

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

# Replace 2.x.y with the current stable release from:
# https://github.com/DefectDojo/django-DefectDojo/releases
# Use defectdojo-values.yaml (see Section 8 — DefectDojo) rather than --set flags
helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  -f defectdojo-values.yaml
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

### Backup Considerations

The Phase 3 services are stateful. Losing their data stores does not break the scanners — CI/CD continues running — but it destroys the operational history that makes the security stack useful: vulnerability lifecycle tracking, SLA data, engagement history, and the cached package store that keeps builds fast and offline-capable.

#### DefectDojo — PostgreSQL Database

**DefectDojo's PostgreSQL database is the critical data store.** It holds all findings, lifecycle state (Open → Mitigated → Risk Accepted), engagement history, SLA tracking, and deduplication records. Losing it means rebuilding the entire vulnerability management history from scratch — there is no recovery path from scan artifacts alone, because lifecycle state exists only in the database.

Back up with `pg_dump` targeting the PostgreSQL pod:

```bash
kubectl exec -n defectdojo deploy/defectdojo-postgresql -- \
  pg_dump -U defectdojo defectdojo > defectdojo-backup-$(date +%Y%m%d).sql
```

Wrap this in a Kubernetes **CronJob** to run automatically, or at minimum run it manually before every `helm upgrade`. A broken upgrade with no backup leaves the service unrecoverable without a full reinstall and data loss.

Restore with:

```bash
kubectl exec -i -n defectdojo deploy/defectdojo-postgresql -- \
  psql -U defectdojo defectdojo < defectdojo-backup-YYYYMMDD.sql
```

#### Nexus — `/nexus-data` PVC

**The `/nexus-data` PersistentVolumeClaim is the Nexus blob store.** It contains all packages cached from upstream registries (npm, PyPI, Docker Hub, Helm, Maven, Go modules). Losing it does not destroy any source code or findings, but it forces a full re-download of every cached package from upstream on the next build. For a project with many dependencies this is slow, expensive on metered connections, and fails entirely if any upstream registry is unavailable.

Identify the PVC:

```bash
kubectl get pvc -n nexus
```

Back up using your cluster's volume snapshot capability if available:

```bash
# Example using the Kubernetes VolumeSnapshot API (requires a CSI driver with snapshot support)
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: nexus-data-snapshot-$(date +%Y%m%d)
  namespace: nexus
spec:
  volumeSnapshotClassName: csi-snapshotter
  source:
    persistentVolumeClaimName: nexus-data
EOF
```

If your cluster does not support VolumeSnapshots, back up by copying the PVC contents to object storage (e.g., S3) via a backup pod, or scale Nexus to zero replicas before taking a volume-level snapshot via the underlying storage provider.

#### Helm Values — Version Control

**The `helm install` commands shown in this document use inline `--set` flags that are not persisted anywhere.** If Nexus or DefectDojo needs to be rebuilt from scratch, the original configuration must be reconstructed from memory or documentation. This is unnecessary operational risk.

Store all Helm values in version-controlled `values.yaml` files per service:

```bash
# Capture current values after initial install
helm get values defectdojo -n defectdojo > defectdojo-values.yaml
helm get values nexus -n nexus > nexus-values.yaml
```

Commit these files to a private infrastructure repository. Future installs and upgrades then use:

```bash
helm install defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  -f defectdojo-values.yaml

helm upgrade defectdojo defectdojo/defectdojo \
  --namespace defectdojo \
  -f defectdojo-values.yaml
```

#### Optional Services (Harbor, SonarQube)

If Harbor or SonarQube are deployed, both require backup if their data is considered durable:

- **Harbor:** PostgreSQL database (project metadata, user accounts, access logs) and registry blob storage (pushed images). The PostgreSQL backup pattern is identical to DefectDojo above. Registry storage is a PVC — apply the same snapshot approach as Nexus.
- **SonarQube:** PostgreSQL database (analysis history, quality gate results, issue lifecycle) and Elasticsearch data. Back up PostgreSQL via `pg_dump` targeting the SonarQube pod. The Elasticsearch index can be rebuilt from reanalysis if lost, but historical trending data cannot.

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

#### Falco + FalcoSidekick — Runtime Anomaly Detection

Detects container runtime anomalies (unexpected process execution, privilege escalation, unusual network connections) that static scanning cannot surface. Runs as a DaemonSet on every node.

```bash
helm repo add falco https://falcosecurity.github.io/charts
helm repo update

# Create falco-values.yaml (version-control this file — see Tool Details section 11)
helm install falco falco/falco \
  --namespace falco-system \
  --create-namespace \
  -f falco-values.yaml

# Verify DaemonSet is running on all nodes
kubectl get pods -n falco-system -o wide

# View live alerts
kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=50 -f

# FalcoSidekick web UI
kubectl port-forward -n falco-system svc/falco-falcosidekick-ui 2802:2802
```

See [Tool Details — Section 11](#11-falco-ce--falcosidekick--kubernetes-runtime-anomaly-detection) for the complete `falco-values.yaml` with custom rules targeting this stack.

#### Cosign + SLSA Provenance + Kyverno — Image Signing and Admission Control

Signs container images in CI using keyless Cosign (GitHub OIDC — no key management), generates SLSA Level 2 provenance attestations, and enforces admission control so only signed images can run in production namespaces.

```bash
# Install Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  -f kyverno-values.yaml  # see Tool Details section 12

# Apply image signing policy (start in Audit mode)
kubectl apply -f kyverno-require-signed-images.yaml

# View policy audit results before enforcing
kubectl get policyreport -A

# Verify a signed image
cosign verify \
  --certificate-identity-regexp "https://github.com/<org>/<repo>/\.github/workflows/security\.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/<org>/<repo>:<sha>
```

The `sign` job in `.github/workflows/security.yml` handles image signing automatically after the `container` job passes. See [Tool Details — Section 12](#12-cosign-keyless--slsa-provenance--kyverno--image-signing-and-admission-control) for the complete workflow job and Kyverno ClusterPolicy YAML.

**Deliverables at completion:**
- Trivy Operator actively generating VulnerabilityReports for all cluster workloads
- Falco DaemonSet running on all nodes with custom rules for security namespace anomalies
- FalcoSidekick routing alerts to Slack or webhook; web UI accessible
- Cosign keyless signing running in CI `sign` job on every push to `main`
- Kyverno ClusterPolicy requiring signed images in production/staging namespaces
- (Optional) SonarQube running with quality gates configured per repository
- (Optional) Harbor serving as the container registry with scan-on-push active
- All optional service findings feeding into DefectDojo

---

## Security Hardening Notes

This document was updated following a three-agent independent red-team analysis conducted in February 2026. The analysis identified 15 convergent findings — issues raised independently by two or more agents from distinct analytical perspectives (attacker, operator, and architect). All 15 convergent findings are addressed in this document. The full analysis is at `red-team/00-consolidated-findings.md`.

The table below maps each change to the finding it addresses and explains the rationale concisely.

| Change | Addresses | Rationale |
|--------|-----------|-----------|
| Removed `continue-on-error: true` from scanner execution steps; added severity-based failure thresholds (`grype --fail-on high`, `semgrep --error`); retained `continue-on-error` only on SARIF and artifact upload steps | Finding #1 | Every scanner step reported "passed" regardless of findings. The CI/CD gate was entirely advisory — a workflow with 200 critical findings was indistinguishable from a clean one. |
| Enabled container scanning on `pull_request` events (removed `if: github.event_name == 'push'` gate) | Finding #3 | Container vulnerabilities were only discovered post-merge. A Dockerfile pulling a known-vulnerable base image passed the PR gate with no scan. The PR reviewer never saw container findings before approving. |
| Pinned all GitHub Actions to full SHA digest placeholders; added Dependabot note for automated SHA updates | Finding #11 | Semver tags (`@master`, `@v4`) are mutable — an upstream maintainer or a compromised repository can change what those tags point to. A tampered action executes with access to source code, repository secrets, and the DefectDojo API token. SHA pinning is the only immutable reference. |
| Promoted branch protection to a required Phase 2 deliverable with explicit setup instructions; added warning that without it the CI gate has zero enforcement effect | Finding #2 | Without mandatory branch protection, developers can push directly to `main`, bypassing all PR-based scanning. The `continue-on-error` fix in Finding #1 has no enforcement effect without branch protection — a required status check is the mechanism that converts the gate from advisory to blocking. |
| Replaced plaintext API tokens with environment variable references (`${DEFECTDOJO_API_TOKEN}`) in scripts and `${{ secrets.DEFECTDOJO_API_TOKEN }}` in workflow examples; added secrets setup instructions | Finding #14 | Plaintext tokens in reference documentation get copied verbatim into real workflows. A compromised DefectDojo API token gives an attacker read/write access to the complete vulnerability inventory — the most sensitive output of this entire stack. |
| Pinned DefectDojo Helm installation to a specific version tag; added `defectdojo-values.yaml` example for version-controlled Helm values; added upgrade procedure note | Finding #8 | `tag="latest"` means any pod restart or `helm upgrade` can pull a new major version with breaking schema migrations. Security infrastructure must be reproducible. Uncontrolled upgrades can break the import pipeline and corrupt the findings database. |
| Added backup guidance for DefectDojo PostgreSQL (`pg_dump` CronJob skeleton) and Nexus (`/nexus-data` PVC snapshots); documented what is lost without backup | Finding #4 | No backup means rebuilding the entire vulnerability history from scratch on any data loss event. Loss of Nexus blob storage triggers re-download of all cached packages from upstream registries — the opposite of supply chain control. |
| Added NetworkPolicy guidance with a default-deny ingress pattern; noted each service namespace should be isolated from application namespaces | Finding #5 | Default Kubernetes allows all pod-to-pod traffic across all namespaces. A compromised application workload can reach the DefectDojo API (read, modify, or delete all findings), the Nexus API (upload malicious packages into the cache), and the Harbor API (push malicious images). |
| Added TLS guidance recommending cert-manager for all internal services; added security warnings on `insecure-registries` and `trusted-host` directives | Finding #6 | All internal service communication was plaintext HTTP. DefectDojo API tokens, Nexus credentials, and scan results were transmitted unencrypted. The `trusted-host` pip directive and `insecure-registries` Docker directive disable certificate verification entirely — appropriate only as a temporary bootstrap measure, not a production configuration. |
| Corrected Nexus "Controls what enters your supply chain" framing to accurately describe it as a caching proxy and single audit point; added group repository ordering guidance (hosted before proxy) to address dependency confusion risk; explained `contentMaxAge: -1` tradeoff | Finding #7 | Nexus does not scan content by default — that is handled by Grype and Trivy. Claiming supply chain control without a content policy or repository ordering is inaccurate. Dependency confusion attacks exploit group repositories where a proxy repo takes precedence over a hosted repo. |
| Added `--no-verify` bypass warning to the pre-commit section; clarified that the CI/CD gate is the compensating server-side control; framed pre-commit as defense-in-depth, not the enforcement layer | Finding #12 | `git commit --no-verify` and `git push --no-verify` bypass all pre-commit hooks, including Gitleaks. The document acknowledged secrets risk at push but relied on client-side enforcement only. This framing is corrected: pre-commit is a convenience layer; branch protection plus required CI checks is the enforcement layer. |
| Added version update process guidance: `pre-commit autoupdate` for hook versions, Dependabot or Renovate for GitHub Actions SHA updates, recommended monthly review cadence | Finding #10 | Pinned versions accumulate unpatched vulnerabilities in the security tools themselves and miss detection rules for newly discovered vulnerability patterns. A single developer tracking 30-40 independently versioned components without an automated update process will fall months behind within a year. |
| Added "Managing Finding Volume" subsection in Phase 3 covering `checkov --create-baseline`, DefectDojo deduplication rules, severity-based auto-close for INFO/LOW findings, and a weekly time-boxed triage cadence | Finding #15 | First-run estimates from the red-team analysis: 125-750 findings per repository. Without a triage SOP, DefectDojo becomes a write-only database. The most likely long-term failure mode of this stack is not a tool failure — it is the developer abandoning triage because the volume is unmanageable. |
| Added "Monitoring the Security Stack" note identifying minimum alerting targets (Nexus disk usage, DefectDojo import failures, Trivy Operator database staleness, pod CrashLoopBackOff); recommended Prometheus + Alertmanager via kube-prometheus-stack | Finding #9 | Security tools that silently fail provide a dangerous illusion of coverage. If Trivy Operator stops scanning or the DefectDojo import pipeline breaks, there is no notification. The absence of an alert looks identical to a clean environment. |

---

## Known Gaps and Out-of-Scope

No security stack covers everything, especially under a zero-cost, single-developer-sustainability constraint. These gaps are documented so implementers can make informed risk decisions rather than assuming coverage that does not exist.

### Dynamic Application Security Testing (DAST)

This stack is entirely static analysis. No tool tests a running application.

**What is missing:** Authentication bypass, session management flaws, business logic vulnerabilities, runtime injection paths, CORS and CSP misconfiguration, HTTP security header issues, and SSRF. These vulnerability classes are structurally invisible to any form of static analysis — they only manifest in a running system under test.

**Why out of scope:** DAST requires a deployed test environment with realistic configuration. This stack makes no assumptions about deployment targets or test environment availability.

**Free option for future consideration:** OWASP ZAP can run in CI in headless mode against a test deployment. When a test environment exists, adding a ZAP active scan as an additional CI job is a zero-cost extension. The `zap-baseline` scan provides a low-friction starting point.

---

### Runtime Application Protection (RASP / WAF)

Nothing in this stack detects or blocks active exploitation of deployed vulnerabilities. Scanning finds vulnerabilities before deployment; it does not respond to attacks after deployment.

**What is missing:** A web application firewall or runtime protection agent that can detect and block exploitation attempts, abnormal request patterns, and known attack payloads targeting deployed services.

**Why out of scope:** WAF configuration is highly application-specific — rules must be tuned to each application's normal traffic patterns to avoid excessive false positives. The complexity is disproportionate to a single-developer practice without a dedicated security operations function.

**Free options for future consideration:** ModSecurity (open-source WAF, integrates with nginx and Apache). If already on AWS, AWS WAF has a limited free tier through the standard AWS account.

---

### Incident Response Procedures

This document is a tooling reference. It specifies no process for responding to findings the tools surface.

**What is missing:** A defined procedure for secret rotation after Gitleaks detects a committed credential, a supply chain compromise response runbook when a malicious package is found in Nexus, rollback procedures when a compromised image reaches production, SLA targets for remediating high and critical findings, and escalation paths.

**Why out of scope:** Incident response is process documentation, not tooling. The appropriate output is a separate runbook document, not an addition to a tooling reference.

**Note:** These procedures should be documented before treating this stack as production-grade. The tools generate the signal; without a response process, that signal goes unacted on. At minimum, define what to do when Gitleaks fires.

---

### Kubernetes RBAC Hardening and Pod Security

The K8s deployment sections in this document focus on getting services running. No workload hardening is configured.

**What is missing:** Pod Security Standards enforcement (blocking privileged containers, host network access, host path mounts), service account restrictions (default service accounts have more permissions than necessary), RBAC policies limiting who can `kubectl exec` into security tool pods, and an admission controller to enforce policies before workloads are scheduled.

**Why out of scope:** RBAC and Pod Security hardening are highly cluster-specific — they require an audit of every workload currently running. Providing generic policies without that audit creates a high risk of breaking existing workloads. This is not addressable in a generic reference document.

**Free options for future consideration:** Kyverno (CNCF project, open-source) for policy-as-code enforcement. Pod Security Admission is built into Kubernetes 1.25+ and requires no additional tooling — it enforces the three Pod Security Standard profiles (privileged, baseline, restricted) at the namespace level.

---

### Cross-File Dataflow SAST

Semgrep Community Edition performs intra-file pattern matching. It does not trace data across function or file boundaries.

**What is missing:** Most real-world injection vulnerabilities involve data that enters at one boundary (an HTTP request handler), passes through several functions across multiple files, and reaches a sink (a database query, a shell command, an HTML render) somewhere else entirely. These multi-hop taint flows are structurally invisible to CE pattern matching. Semgrep CE will not detect SQL injection where the user input is validated in one file and used unsanitized in another.

**Why out of scope:** Cross-file dataflow analysis requires Semgrep Pro (commercial) or CodeQL. Both require either a paid license or a specific repository configuration.

**Note:** GitHub's native CodeQL scanning is free for public repositories. For private repositories it requires GitHub Advanced Security, which is a paid feature. CodeQL provides deep cross-file dataflow analysis for Python, JavaScript, TypeScript, Go, Java, and C/C++. If repositories ever become public, enabling the default CodeQL workflow is a zero-cost upgrade to this stack's SAST coverage.

---

### License Compliance Scanning

Syft generates SBOMs containing license metadata for every dependency. No tool in this stack evaluates whether those licenses are compatible with each other or with the project's intended distribution.

**What is missing:** Detection of GPL or AGPL licensed dependencies in projects that cannot satisfy copyleft requirements, flagging of dual-licensed packages where the open-source version has usage restrictions, and policy enforcement that blocks dependencies with prohibited license types from entering the stack.

**Why out of scope:** License compliance policy is organization-specific — the same dependency may be acceptable in one context and prohibited in another. Configuring a license scanner without a defined policy produces noise, not signal. The tooling question is secondary to the policy question.

**Free options for future consideration:** Trivy has a `--scanners license` mode that can flag licenses against a configurable allow/deny list — it is available in the existing Trivy installation but is not enabled in the CI workflow. FOSSA Community edition (free tier) provides more structured license policy management for future consideration.
