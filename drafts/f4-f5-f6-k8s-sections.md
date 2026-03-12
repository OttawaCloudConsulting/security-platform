# Draft Agent B — Features 4, 5, 6

---
## FEATURE 4: NEW SECTION — Backup Considerations
<!-- ANCHOR: insert after Phase 3b (DefectDojo) section, before Phase 4 heading -->

## Backup Considerations

The Phase 3 services are stateful. Losing their data stores does not break the scanners — CI/CD continues running — but it destroys the operational history that makes the security stack useful: vulnerability lifecycle tracking, SLA data, engagement history, and the cached package store that keeps builds fast and offline-capable.

### DefectDojo — PostgreSQL Database

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

### Nexus — `/nexus-data` PVC

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

### Helm Values — Version Control

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

### Optional Services (Harbor, SonarQube)

If Harbor or SonarQube are deployed, both require backup if their data is considered durable:

- **Harbor:** PostgreSQL database (project metadata, user accounts, access logs) and registry blob storage (pushed images). The PostgreSQL backup pattern is identical to DefectDojo above. Registry storage is a PVC — apply the same snapshot approach as Nexus.
- **SonarQube:** PostgreSQL database (analysis history, quality gate results, issue lifecycle) and Elasticsearch data. Back up PostgreSQL via `pg_dump` targeting the SonarQube pod. The Elasticsearch index can be rebuilt from reanalysis if lost, but historical trending data cannot.

---
## FEATURE 5: NEW SECTION — Network Security
<!-- ANCHOR: insert after "Kubernetes Self-Hosted Services Summary" table, before "Implementation Phases" heading -->

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
## FEATURE 6: NEW SECTION — Monitoring the Security Stack
<!-- ANCHOR: insert immediately after Feature 5's Network Security section -->

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
