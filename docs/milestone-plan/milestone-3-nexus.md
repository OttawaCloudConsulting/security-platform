# Milestone 3: Nexus Repository (Package Proxy)

## Goal

All upstream package traffic (npm, PyPI, Docker Hub, Helm) flows through a self-hosted Nexus proxy, providing a single caching and audit point for the software supply chain. Builds are faster, reproducible, and protected against upstream outages.

## Prerequisites

- A running Kubernetes cluster (any distribution — EKS, k3s, minikube, etc.)
- `helm` CLI installed
- `kubectl` configured for the target cluster
- Note: M3 can run in parallel with M1/M2 — it does not depend on them

## Features

| ID | Feature | Components |
|----|---------|------------|
| M3-F1 | Nexus deployment on Kubernetes | Helm chart `sonatype/nexus-repository-manager`, 2 Gi RAM, 50 Gi+ storage |
| M3-F2 | Proxy repository creation (npm, PyPI, Docker, Helm) | Nexus REST API, 4 proxy repositories |
| M3-F3 | Workstation package manager configuration | `.npmrc`, `pip.conf`, Docker `daemon.json`, Helm repo |

---

### M3-F1: Nexus Deployment on Kubernetes

**Delivers:** Nexus Repository Community Edition running in the `nexus` namespace, accessible via port-forward, with the initial admin password retrieved.

**Key Components:**

- Helm chart: `sonatype/nexus-repository-manager`
- Namespace: `nexus`
- Resource requests: 2 Gi memory minimum
- PersistentVolumeClaim: `/nexus-data` (50 Gi+ recommended)

**Done Criteria:**

- `kubectl get pods -n nexus` shows the Nexus pod in `Running` state
- `kubectl port-forward -n nexus svc/nexus-nexus-repository-manager 8081:8081` exposes the UI
- Nexus web UI is accessible at `http://localhost:8081`
- Initial admin password retrieved and admin account secured (password changed from default)
- Helm values exported to a version-controlled `nexus-values.yaml` file

**Dependencies:** None (only K8s cluster).

---

### M3-F2: Proxy Repository Creation

**Delivers:** Four proxy repositories configured in Nexus, caching packages from upstream registries.

**Key Components:**

- npm proxy -> `https://registry.npmjs.org`
- PyPI proxy -> `https://pypi.org`
- Docker proxy -> `https://registry-1.docker.io` (HTTP port 8082)
- Helm proxy -> `https://charts.helm.sh/stable`
- `contentMaxAge: -1` (cache indefinitely — tradeoff documented per ADR-010)
- Group repository ordering: hosted (internal) before proxy (upstream) for dependency confusion protection

**Done Criteria:**

- All 4 proxy repositories visible in Nexus UI under Repository > Repositories
- Each proxy repository shows `Online` status and successful connection to upstream
- A test `npm install <package>` through Nexus successfully fetches and caches a package
- Nexus browse UI shows the cached package artifact
- If group repositories are created, hosted repos are ordered before proxy repos in the member list

**Dependencies:** M3-F1.

---

### M3-F3: Workstation Package Manager Configuration

**Delivers:** All developer workstation package managers route through Nexus instead of directly to upstream registries.

**Key Components:**

- `.npmrc`: `registry=http://localhost:8081/repository/npm-proxy/`
- `~/.config/pip/pip.conf`: `index-url = http://localhost:8081/repository/pypi-proxy/simple` with `trusted-host = localhost`
- `/etc/docker/daemon.json`: `registry-mirrors` and `insecure-registries` pointing to Nexus (Docker port 8082)
- Helm: `helm repo add nexus-proxy http://localhost:8081/repository/helm-proxy/`

**Done Criteria:**

- `npm install <package>` routes through Nexus (verify in Nexus browse UI or proxy logs)
- `pip install <package>` routes through Nexus
- `docker pull` for a public image routes through Nexus Docker proxy
- `helm repo update` succeeds against the Nexus Helm proxy
- Developer understands the security implications: `insecure-registries` and `trusted-host` disable TLS verification and are temporary until M5-F2 (TLS via cert-manager) is complete

**Dependencies:** M3-F1, M3-F2.

---

## Milestone Verification

Run these checks to confirm M3 is complete:

1. **Nexus healthy:** `kubectl get pods -n nexus` — pod is `Running`, no restarts
2. **Proxy repos active:** Nexus UI > Repository > Repositories — all 4 proxies show `Online`
3. **Cache working:** Run `npm install lodash`, then check Nexus browse — `lodash` appears in `npm-proxy` cache
4. **PVC provisioned:** `kubectl get pvc -n nexus` — PVC is `Bound` with adequate capacity
5. **Values persisted:** `nexus-values.yaml` exists in the infrastructure repository and matches the running config

## Reference

- Main document: Tool Details — Section 6 (Nexus Repository CE, line ~382)
- Main document: Phase 3a — Nexus Repository CE (line ~1978)
- Main document: Group Repository Ordering and Dependency Confusion Protection (line ~521)
- [ADR-009: TLS Guidance; Warn on `insecure-registries` and `trusted-host`](../adr/adr009-tls-guidance.md)
- [ADR-010: Correct Nexus Supply Chain Control Framing](../adr/adr010-correct-nexus-framing.md)
