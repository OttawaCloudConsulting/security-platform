# Milestone 6: Runtime Security

## Goal

The Kubernetes cluster has continuous runtime security: vulnerability scanning of all running workloads, kernel-level anomaly detection, image integrity verification via keyless signing, and admission control that rejects unsigned images.

## Prerequisites

- M4 complete (DefectDojo running — runtime findings feed into it)
- M5 complete (NetworkPolicy, TLS, and monitoring in place — runtime security tools need a hardened foundation)
- Kubernetes cluster with eBPF support (for Falco; falls back to kernel module if unavailable)

## Features

| ID | Feature | Components |
|----|---------|------------|
| M6-F1 | Trivy Operator deployment | Helm chart `aqua/trivy-operator`, VulnerabilityReports, ConfigAuditReports |
| M6-F2 | Falco CE + FalcoSidekick deployment | Helm chart `falco/falco`, eBPF driver, custom rules, FalcoSidekick UI |
| M6-F3 | Cosign keyless image signing in CI | `sign` job in security workflow, Sigstore Fulcio CA, Rekor transparency log |
| M6-F4 | Kyverno admission control | ClusterPolicy requiring signed images in production/staging namespaces |

---

### M6-F1: Trivy Operator Deployment

**Delivers:** Continuous scanning of all running container images and Kubernetes workload configurations. Findings are available as Kubernetes custom resources and can feed into DefectDojo.

**Key Components:**

- Helm chart: `aqua/trivy-operator`
- Namespace: `trivy-system`
- VulnerabilityReports (per workload — image CVEs)
- ConfigAuditReports (per workload — K8s misconfiguration)
- Resource requirements: 512 Mi RAM, 0.5 core

**Done Criteria:**

- `kubectl get pods -n trivy-system` shows the Trivy Operator pod in `Running` state
- `kubectl get vulnerabilityreports -A` returns reports for running workloads (may take a few minutes after deployment)
- `kubectl get configauditreports -A` returns audit reports
- A workload running a known-vulnerable image shows CVEs in its VulnerabilityReport
- Trivy Operator database is not stale (verify with monitoring from M5-F4)

**Dependencies:** K8s cluster, M5-F4 (monitoring to detect DB staleness).

---

### M6-F2: Falco CE + FalcoSidekick Deployment

**Delivers:** Kernel-level runtime anomaly detection — detects unexpected processes, privilege escalation, container escapes, and unauthorized access to security namespace pods.

**Key Components:**

- Helm chart: `falco/falco` with `falco-values.yaml`
- eBPF driver (preferred; kernel module fallback)
- DaemonSet: one Falco pod per node
- FalcoSidekick: alert routing to Slack, webhook, or other destinations
- FalcoSidekick web UI (port 2802)
- Custom rules targeting this stack:
  - Shell spawned in security namespace pod
  - `kubectl exec` into security namespace
  - Unexpected outbound connection from security namespace
  - Write to `/etc` in any container

**Done Criteria:**

- `kubectl get pods -n falco-system -o wide` shows a Falco pod running on every node
- `kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=20` shows Falco is processing events (no error loops)
- Test alert: `kubectl exec` into a test pod and run `ls /etc` — Falco logs show the "Write to /etc in Container" rule firing
- FalcoSidekick UI accessible at `http://localhost:2802` via port-forward, showing recent alerts
- `falco-values.yaml` committed to infrastructure repository with custom rules
- Alert routing configured (Slack webhook, generic webhook, or at minimum the FalcoSidekick UI)
- Kubernetes audit log plugin enabled (required for `kubectl exec` detection rules using `k8s_audit` source)

**Dependencies:** K8s cluster, M5-F1 (NetworkPolicy should include `falco-system` namespace).

---

### M6-F3: Cosign Keyless Image Signing in CI

**Delivers:** Every container image pushed to the registry from the CI pipeline is cryptographically signed using GitHub Actions OIDC — no private keys to manage.

**Key Components:**

- `sign` job in `.github/workflows/security.yml` (runs after `container` job, only on push to `main`)
- `sigstore/cosign-installer` action (SHA-pinned)
- Cosign keyless signing using GitHub OIDC token
- Sigstore Fulcio CA for ephemeral certificates
- Rekor transparency log for signature recording
- SLSA Level 2 provenance via `slsa-github-generator` (optional but included in reference)
- Permissions: `id-token: write`, `packages: write`, `actions: read`

**Done Criteria:**

- The `sign` job exists in `.github/workflows/security.yml` and runs on push to `main`
- After a push to `main`, the built image has a Cosign signature:

  ```
  cosign verify \
    --certificate-identity-regexp "https://github.com/<org>/<repo>/\.github/workflows/security\.yml@refs/heads/main" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    ghcr.io/<org>/<repo>:<sha>
  ```

  returns verification success
- `REGISTRY_PASSWORD` configured as a GitHub Actions secret
- No private signing keys exist anywhere — signing is fully keyless via OIDC

**Dependencies:** M2-F1 (CI workflow must exist), container registry accessible from CI (GHCR, Nexus, or Harbor).

---

### M6-F4: Kyverno Admission Control

**Delivers:** Kubernetes admission policy that rejects unsigned container images in production and staging namespaces — only images signed by the CI pipeline can run.

**Key Components:**

- Helm chart: `kyverno/kyverno`
- Namespace: `kyverno`
- ClusterPolicy: `require-signed-images`
- `verifyImages` rule matching `ghcr.io/<org>/*` with keyless attestor (GitHub OIDC issuer)
- Initial deployment in `Audit` mode, then switch to `Enforce` after validation
- Resource requirements: 512 Mi RAM, 0.5 core

**Done Criteria:**

- `kubectl get pods -n kyverno` shows Kyverno pods running
- ClusterPolicy `require-signed-images` is applied:

  ```
  kubectl get clusterpolicy require-signed-images
  ```

- **Audit mode validation:** Deploy an unsigned image to `production` namespace — `kubectl get policyreport -A` shows a violation
- **Enforce mode validation:** Switch to `Enforce` — `kubectl run unsigned-test --image=alpine:latest -n production` is rejected by the admission webhook
- A signed image from the CI pipeline deploys successfully to `production`
- `kyverno-values.yaml` and `kyverno-require-signed-images.yaml` committed to infrastructure repository

**Dependencies:** M6-F3 (signed images must exist to test admission), M5-F1 (NetworkPolicy should include `kyverno` namespace).

---

## Milestone Verification

Run these checks to confirm M6 is complete:

1. **Trivy Operator active:** `kubectl get vulnerabilityreports -A` returns reports for all running workloads
2. **Falco detecting:** Exec into a test pod and confirm Falco generates an alert
3. **Image signing working:** `cosign verify` succeeds for an image built by CI
4. **Admission control enforcing:** An unsigned image is rejected in the `production` namespace; a signed image is admitted
5. **All values files committed:** `falco-values.yaml`, `kyverno-values.yaml`, and `kyverno-require-signed-images.yaml` in VCS

## Reference

- Main document: Tool Details — Section 10 (Trivy Operator, line ~765)
- Main document: Tool Details — Section 11 (Falco CE + FalcoSidekick, line ~777)
- Main document: Tool Details — Section 12 (Cosign + SLSA + Kyverno, line ~896)
- Main document: Phase 4 — Runtime Security (line ~2116)
- [ADR-013: Add Falco CE + FalcoSidekick for Kubernetes Runtime Anomaly Detection](../adr/adr013-falco-runtime-detection.md)
- [ADR-014: Add Cosign Keyless Signing + SLSA Provenance + Kyverno Admission Control](../adr/adr014-cosign-slsa-kyverno.md)
