# security-platform

Canonical security configuration and tooling for OttawaCloudConsulting repositories. Organized by deployment target — each subdirectory is a self-contained package for one layer of the security stack.

## Structure

```
security-platform/
├── workstation/          # Developer workstation security (Milestone 1)
│   ├── ARCHITECTURE.md   # Architecture, design decisions, tool model
│   ├── README.md         # Quick start and usage guide
│   ├── dist/             # Cross-platform tool installer
│   ├── cicd/             # CI helper scripts
│   └── (config files)    # Pre-commit, linting, and secrets configs
└── (future milestones)
    ├── cicd/             # M2: GitHub Actions security workflows
    ├── infrastructure/   # M3: Nexus, DefectDojo, Helm values
    └── runtime/          # M4: Trivy Operator, Falco, Kyverno
```

## Milestones

| Directory | Milestone | Status | Description |
|---|---|---|---|
| `workstation/` | M1 — Workstation Foundation | In progress | Pre-commit hooks, linting configs, CLI tool installer |
| `cicd/` | M2 — CI/CD Security Gate | Planned | GitHub Actions workflows for PR-level security scanning |
| `infrastructure/` | M3 — Self-Hosted Services | Planned | Nexus, DefectDojo, Helm values, K8s manifests |
| `runtime/` | M4 — Runtime Security | Planned | Trivy Operator, Falco, Cosign, Kyverno policies |

## Getting Started

See [`workstation/README.md`](workstation/README.md) for the developer workstation setup.
