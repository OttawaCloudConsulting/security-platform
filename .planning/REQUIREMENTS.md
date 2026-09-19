# Requirements: Security & Supply Chain Scanning Stack — v3.0

**Defined:** 2026-09-17
**Core Value:** Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production — with zero ongoing cost and zero vendor lock-in.

## v3.0 Requirements

Requirements for the K8s Infra & Dashboards milestone. Each maps to roadmap phases.

Architecture constraint (Key Decision, see PROJECT.md): generic Helm charts are the source of truth in the public repo; environment-specific values (hostnames, StorageClass overrides, ClusterIssuer names, IPs) live only in a private ArgoCD overlay repo, never in the public package.

### Nexus

- [x] **NEXUS-01**: Public Helm chart deploys Nexus Repository with npm, PyPI, Docker, and Helm proxy repos configured
- [ ] **NEXUS-02**: Proxy repos allow anonymous pull (no auth required for read/proxy access)
- [x] **NEXUS-03**: Chart uses the cluster's default StorageClass unless overridden by the consumer
- [ ] **NEXUS-04**: Workstation install script configures a target repo's package manager files (`.npmrc`, `pip.conf`, Docker/Helm registry config) to route through a given Nexus instance
- [ ] **NEXUS-05**: Nexus chart validated live via private ArgoCD overlay deploy to the operator's homelab cluster

### DefectDojo

- [ ] **DDOJO-01**: Public Helm chart deploys DefectDojo with external ingress and cert-manager-issued TLS
- [ ] **DDOJO-02**: `security-platform` CI scan jobs automatically import SARIF/JSON findings into DefectDojo after each run
- [ ] **DDOJO-03**: Deduplication rules configured so repeated findings across scans/tools collapse rather than duplicate
- [ ] **DDOJO-04**: Triage workflow documented/configured for reviewing and dispositioning findings in DefectDojo
- [ ] **DDOJO-05**: DefectDojo chart validated live via private ArgoCD overlay deploy to the operator's homelab cluster

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Nexus authenticated push/publish | Anonymous pull only for v3.0; authenticated publish deferred |
| NetworkPolicy namespace isolation for Nexus/DefectDojo | Hardening bucket, separate from this milestone's Infra & Dashboards scope |
| Backup automation (DefectDojo PostgreSQL, Nexus PVC) | Hardening bucket, deferred |
| Monitoring/alerting via kube-prometheus-stack | Hardening bucket, deferred |
| Workstation pkg managers routed through Nexus outside the per-repo config, **except Docker** | Per-repo config + install script only, not global workstation defaults — Docker has no per-repo registry-routing mechanism, so NEXUS-04's install script writes a global `~/.docker/daemon.json` entry for Docker only, with an explicit warning that this one ecosystem is global-scoped unlike npm/pip/Helm (decided Phase 24) |
| De-identification of a privately-built deployment | Superseded — generic-first architecture means nothing private needs stripping |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| NEXUS-01 | Phase 23 | Complete |
| NEXUS-03 | Phase 23 | Complete |
| NEXUS-02 | Phase 24 | Pending |
| NEXUS-04 | Phase 24 | Pending |
| NEXUS-05 | Phase 25 | Pending |
| DDOJO-01 | Phase 26 | Pending |
| DDOJO-02 | Phase 27 | Pending |
| DDOJO-03 | Phase 28 | Pending |
| DDOJO-04 | Phase 28 | Pending |
| DDOJO-05 | Phase 29 | Pending |

**Coverage:**
- v3.0 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-17*
*Last updated: 2026-09-17 after initial v3.0 definition*
