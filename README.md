# security-platform

Canonical security configuration and tooling for OttawaCloudConsulting repositories. Organized by deployment target — each subdirectory is a self-contained package for one layer of the security stack.

## Structure

```
security-platform/
├── workstation/          # Developer workstation security (Milestone 1)
│   ├── ARCHITECTURE.md   # Architecture, design decisions, tool model
│   ├── README.md         # Quick start and usage guide
│   ├── setup.sh          # Workstation bootstrap script
│   └── cicd/             # CI helper scripts (markdown linting)
├── cicd/                 # CI/CD security gate (Milestone 2)
│   ├── ARCHITECTURE.md   # Architecture, data flow, enforcement model
│   └── README.md         # Deployment guide and scanner reference
└── (future milestones)
    ├── infrastructure/   # M3: Nexus, DefectDojo, Helm values
    └── runtime/          # M4: Trivy Operator, Falco, Kyverno
```

## Milestones

| Directory | Milestone | Status | Description |
|---|---|---|---|
| `workstation/` | M1 — Workstation Foundation | Complete | Pre-commit hooks, linting configs, CLI tool installer |
| `cicd/` | M2 — CI/CD Security Gate | In progress | GitHub Actions workflows for PR-level security scanning |
| `infrastructure/` | M3 — Self-Hosted Services | Planned | Nexus, DefectDojo, Helm values, K8s manifests |
| `runtime/` | M4 — Runtime Security | Planned | Trivy Operator, Falco, Cosign, Kyverno policies |

## Getting Started

From inside any git repository, run the workstation setup:

```bash
bash path/to/security-platform/workstation/setup.sh
```

See [`workstation/README.md`](workstation/README.md) for the full guide.

Every pull request against `main` runs the CI security pipeline — five parallel scan jobs covering SAST, IaC, SCA, container images and secrets. The pipeline runs in report-only mode: each job publishes its findings to the repository Security tab and retains them as build artifacts, and reports them without blocking the merge.
