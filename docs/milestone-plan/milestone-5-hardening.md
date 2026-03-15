# Milestone 5: Infrastructure Hardening

## Goal

The self-hosted Kubernetes services (Nexus, DefectDojo, and all future services) are hardened with network isolation, TLS encryption, automated backups, monitoring, and a sustainable version update process. The stack moves from development-grade to production-grade.

## Prerequisites

- M3 complete (Nexus running on K8s)
- M4 complete (DefectDojo running on K8s)
- CNI plugin that supports NetworkPolicy (e.g., Calico, Cilium) — verify before starting M5-F1

## Features

| ID | Feature | Components |
|----|---------|------------|
| M5-F1 | NetworkPolicy isolation | Default-deny ingress per namespace, explicit allow rules |
| M5-F2 | TLS via cert-manager | cert-manager, Ingress TLS termination, removal of `insecure-registries` |
| M5-F3 | Backup automation | DefectDojo `pg_dump` CronJob, Nexus PVC snapshots, Helm values in VCS |
| M5-F4 | Monitoring and alerting (kube-prometheus-stack) | Prometheus, Grafana, Alertmanager |
| M5-F5 | Version update process | `pre-commit autoupdate`, Dependabot, Helm chart update cadence |

---

### M5-F1: NetworkPolicy Isolation

**Delivers:** Each security service namespace is isolated from application workloads — only explicitly allowed traffic can reach service APIs.

**Key Components:**

- Default-deny ingress NetworkPolicy applied to: `defectdojo`, `nexus`, `trivy-system` (and future namespaces: `sonarqube`, `harbor`, `falco-system`, `kyverno`)
- Explicit allow rules for required traffic (e.g., CI runner pods to DefectDojo API on port 80)
- CNI plugin verification (Kubenet silently ignores NetworkPolicy objects)

**Done Criteria:**

- `kubectl get networkpolicy -n defectdojo` and `-n nexus` both show a `default-deny-ingress` policy
- A test pod in a non-allowed namespace cannot reach the DefectDojo API: `kubectl run test --image=alpine --restart=Never -- wget -qO- http://defectdojo-django.defectdojo:80` — connection times out or is refused
- Authorized traffic still works: CI import to DefectDojo succeeds, workstation package installs through Nexus succeed
- CNI plugin confirmed: `kubectl get pods -n kube-system | grep -E 'calico|cilium|weave'` returns a result

**Dependencies:** M3-F1, M4-F1 (services must be running to apply and test policies).

---

### M5-F2: TLS via cert-manager

**Delivers:** All internal service communication uses HTTPS. The temporary `insecure-registries` and `trusted-host` workarounds from M3 are removed.

**Key Components:**

- cert-manager deployed to the cluster
- Certificate Issuer configured (self-signed for internal-only, or Let's Encrypt if DNS is available)
- Ingress TLS termination for DefectDojo, Nexus, and all future services
- Removal of `insecure-registries` from Docker daemon config
- Removal of `trusted-host` from pip config
- All service URLs updated from `http://` to `https://`

**Done Criteria:**

- `kubectl get pods -n cert-manager` — cert-manager pods running
- `kubectl get certificate -A` — certificates issued for DefectDojo and Nexus Ingress resources
- `curl -I https://defectdojo.local` returns a valid TLS response (self-signed or CA-issued)
- Docker daemon config no longer contains `insecure-registries` for Nexus
- pip config no longer contains `trusted-host = localhost`
- CI import script uses `https://` URL for DefectDojo API
- `npm install` and `pip install` work over HTTPS through Nexus

**Dependencies:** M3-F3 (package manager configs must exist to update), M4-F1 (DefectDojo must be running).

---

### M5-F3: Backup Automation

**Delivers:** Automated backups for all stateful services — no manual intervention required for routine backups.

**Key Components:**

- DefectDojo PostgreSQL: Kubernetes CronJob running `pg_dump` on a schedule (daily recommended)
- Nexus `/nexus-data` PVC: VolumeSnapshot (if CSI driver supports it) or backup pod copying to object storage
- Helm values files: confirmed committed to version control (`defectdojo-values.yaml`, `nexus-values.yaml`)
- Restore procedure documented and tested

**Done Criteria:**

- `kubectl get cronjob -n defectdojo` shows a `pg_dump` CronJob with a recent successful run
- A DefectDojo database backup file exists and can be restored to a test instance: `psql -U defectdojo defectdojo < backup.sql`
- Nexus PVC snapshot or backup exists: `kubectl get volumesnapshot -n nexus` or backup file in object storage
- All Helm values files are committed to the infrastructure repository
- Restore procedure documented: a new engineer could rebuild from backups without tribal knowledge

**Dependencies:** M3-F1, M4-F1 (services must be running to back up).

---

### M5-F4: Monitoring and Alerting (kube-prometheus-stack)

**Delivers:** The security stack is monitored — silent failures trigger alerts instead of creating a false sense of coverage.

**Key Components:**

- `kube-prometheus-stack` Helm chart (Prometheus + Grafana + Alertmanager)
- Alert rules for the 4 minimum conditions:
  1. Nexus disk usage above threshold
  2. DefectDojo import failures (stale last-import timestamp)
  3. Trivy Operator vulnerability database staleness
  4. Pod `CrashLoopBackOff` in any security namespace (`defectdojo`, `nexus`, `trivy-system`, `falco-system`, `kyverno`)
- Alert routing to Slack, email, or webhook

**Done Criteria:**

- `kubectl get pods -n monitoring` shows Prometheus, Grafana, and Alertmanager pods running
- Grafana dashboard accessible via port-forward, showing Kubernetes pod metrics for security namespaces
- At least one test alert fires and routes to the configured destination (e.g., kill a security pod and confirm the alert arrives)
- Nexus Prometheus metrics endpoint enabled (`/service/metrics/prometheus`) and scraped by Prometheus
- Alertmanager configuration committed to version control

**Dependencies:** M3-F1, M4-F1 (services must be running to monitor).

---

### M5-F5: Version Update Process

**Delivers:** A sustainable process for keeping all security tools, pre-commit hooks, GitHub Actions, and Helm charts current.

**Key Components:**

- `pre-commit autoupdate` — monthly, updates all `rev:` entries in `.pre-commit-config.yaml`
- Dependabot or Renovate — monthly, updates GitHub Actions SHA digests (configured in M2-F5)
- Helm chart updates — monthly review of upstream release notes for DefectDojo, Nexus, and all deployed charts
- Documented cadence: monthly 30-minute maintenance window covering all of the above

**Done Criteria:**

- `pre-commit autoupdate` runs successfully and produces updated `rev:` entries
- `pre-commit run --all-files` passes after update (no breakage from new hook versions)
- A written maintenance checklist exists covering:
  - `pre-commit autoupdate` + test
  - Review and merge Dependabot PRs for GitHub Actions
  - Check Helm chart release notes for DefectDojo, Nexus, and other deployed charts
  - Update Helm chart versions in values files and run `helm upgrade` (with pre-upgrade backup per M5-F3)
- The process is documented as a recurring calendar item or task

**Dependencies:** M1-F1 (pre-commit), M2-F5 (Dependabot), M4-F1 (DefectDojo Helm chart).

---

## Milestone Verification

Run these checks to confirm M5 is complete:

1. **Network isolation:** A pod in a non-allowed namespace cannot reach DefectDojo or Nexus APIs
2. **TLS active:** All service URLs are `https://`, no `insecure-registries` or `trusted-host` directives remain
3. **Backups working:** CronJob has a recent successful run; a test restore completes without errors
4. **Monitoring active:** Kill a security namespace pod — confirm an alert fires within the configured interval
5. **Update process documented:** A written checklist exists and has been executed at least once

## Reference

- Main document: Network Security — Kubernetes NetworkPolicies (line ~1793)
- Main document: TLS / Internal Communication (line ~1841)
- Main document: Backup Considerations (line ~2029)
- Main document: Monitoring the Security Stack (line ~1863)
- Main document: Keeping Hooks Current (line ~1383)
- [ADR-008: Add NetworkPolicy Guidance](../adr/adr008-networkpolicy-guidance.md)
- [ADR-009: TLS Guidance](../adr/adr009-tls-guidance.md)
- [ADR-012: Add Backup Guidance for Stateful Services](../adr/adr012-backup-guidance.md)
