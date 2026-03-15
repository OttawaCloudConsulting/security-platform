# Implementation Roadmap

> Milestone-based deployment plan for the zero-cost, open-source security and supply chain scanning stack described in [`development-security-stack-option-1.md`](../development-security-stack-option-1.md).

This roadmap decomposes the reference document into 7 implementable milestones containing 28 features total. Each milestone produces a usable capability increment — no milestone depends on completing a later one.

---

## Milestone Summary

| Milestone | Theme | Features | Prerequisites | Infrastructure Required |
|-----------|-------|----------|---------------|------------------------|
| [M1](milestone-1-workstation.md) | Developer Workstation Foundation | 3 | None | None |
| [M2](milestone-2-cicd-gate.md) | CI/CD Security Gate | 5 | M1 | None (GitHub-hosted runners) |
| [M3](milestone-3-nexus.md) | Nexus Repository (Package Proxy) | 3 | K8s cluster | Kubernetes cluster |
| [M4](milestone-4-defectdojo.md) | DefectDojo (Unified Dashboard) | 5 | M2, M3 | Kubernetes cluster |
| [M5](milestone-5-hardening.md) | Infrastructure Hardening | 5 | M3, M4 | Kubernetes cluster |
| [M6](milestone-6-runtime.md) | Runtime Security | 4 | M4, M5 | Kubernetes cluster |
| [M7](milestone-7-optional.md) | Optional Enhancements | 3 | M4, M5 | Kubernetes cluster |

**Total: 7 milestones, 28 features.**

---

## Dependency Graph

```
M1 (Workstation) --> M2 (CI/CD) --------+
                                         |
           K8s cluster --> M3 (Nexus) --+
                                         |
                                         v
                                    M4 (DefectDojo)
                                         |
                                         v
                                    M5 (Hardening)
                                         |
                                    +----+----+
                                    v         v
                              M6 (Runtime)  M7 (Optional)
```

**Critical path:** M1 -> M2 -> M4 -> M5 -> M6/M7 (serial, each builds on the last).

**Parallel track:** M3 (Nexus) can proceed independently as soon as a K8s cluster is available, and runs in parallel with M1/M2. M6 and M7 are independent of each other and can run in parallel after M5.

---

## Feature Index

| ID | Feature | Milestone |
|----|---------|-----------|
| M1-F1 | Pre-commit Tier 1 (quality/linting hooks) | [M1](milestone-1-workstation.md) |
| M1-F2 | Pre-commit Tier 2 (Gitleaks secrets gate) | [M1](milestone-1-workstation.md) |
| M1-F3 | Security CLI tool suite installation | [M1](milestone-1-workstation.md) |
| M2-F1 | GitHub Actions security workflow | [M2](milestone-2-cicd-gate.md) |
| M2-F2 | SARIF upload to GitHub Security tab | [M2](milestone-2-cicd-gate.md) |
| M2-F3 | JSON artifact retention for DefectDojo | [M2](milestone-2-cicd-gate.md) |
| M2-F4 | Branch protection enforcement | [M2](milestone-2-cicd-gate.md) |
| M2-F5 | Dependabot for Actions SHA updates | [M2](milestone-2-cicd-gate.md) |
| M3-F1 | Nexus deployment on Kubernetes | [M3](milestone-3-nexus.md) |
| M3-F2 | Proxy repository creation (npm, PyPI, Docker, Helm) | [M3](milestone-3-nexus.md) |
| M3-F3 | Workstation package manager configuration | [M3](milestone-3-nexus.md) |
| M4-F1 | DefectDojo deployment on Kubernetes | [M4](milestone-4-defectdojo.md) |
| M4-F2 | Product and engagement configuration | [M4](milestone-4-defectdojo.md) |
| M4-F3 | CI-to-DefectDojo import automation | [M4](milestone-4-defectdojo.md) |
| M4-F4 | Deduplication and triage configuration | [M4](milestone-4-defectdojo.md) |
| M4-F5 | Checkov baseline for existing repos | [M4](milestone-4-defectdojo.md) |
| M5-F1 | NetworkPolicy isolation | [M5](milestone-5-hardening.md) |
| M5-F2 | TLS via cert-manager | [M5](milestone-5-hardening.md) |
| M5-F3 | Backup automation | [M5](milestone-5-hardening.md) |
| M5-F4 | Monitoring and alerting (kube-prometheus-stack) | [M5](milestone-5-hardening.md) |
| M5-F5 | Version update process | [M5](milestone-5-hardening.md) |
| M6-F1 | Trivy Operator deployment | [M6](milestone-6-runtime.md) |
| M6-F2 | Falco CE + FalcoSidekick deployment | [M6](milestone-6-runtime.md) |
| M6-F3 | Cosign keyless image signing in CI | [M6](milestone-6-runtime.md) |
| M6-F4 | Kyverno admission control | [M6](milestone-6-runtime.md) |
| M7-F1 | SonarQube Community Build | [M7](milestone-7-optional.md) |
| M7-F2 | Harbor Container Registry | [M7](milestone-7-optional.md) |
| M7-F3 | Commit signing | [M7](milestone-7-optional.md) |

---

## Reference Documents

| Document | Purpose |
|----------|---------|
| [`development-security-stack-option-1.md`](../development-security-stack-option-1.md) | Primary reference — all tool configs, phases, and architecture |
| [`adr/README.md`](../adr/README.md) | ADR index (ADR-001 through ADR-014) |
| [`ARCHITECTURE_AND_DESIGN.md`](../ARCHITECTURE_AND_DESIGN.md) | Design constraints and change rationale |
