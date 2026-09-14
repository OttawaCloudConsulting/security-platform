# security-platform

Canonical security configuration and tooling for OttawaCloudConsulting repositories. Organized by deployment target — each subdirectory is a self-contained package for one layer of the security stack.

This repository is also the **canonical host for the reusable CI/CD security-scanning workflow** (Milestone 2). Other repositories adopt it either by referencing it directly with
`uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1`
or by copying its three files (`.github/workflows/security.yml`, `.github/workflows/pr-security.yml`, `.github/dependabot.yml`). The procedure of record for both consumption modes — including `gate_mode` selection, branch protection setup, and Dependabot wiring — is
[`docs/adoption-guide.md`](https://github.com/OttawaCloudConsulting/security_solution/blob/main/docs/adoption-guide.md)
in the `security_solution` documentation repository. No trailing version comment is added beside the `@v1` reference above: `v1` is a moving tag, and a hand-written `# v1.0.0` beside it would rot silently — Dependabot maintains version comments on SHA pins, not on tag refs.

Every pull request against `main` runs the CI security pipeline — five parallel scan jobs covering SAST, IaC, SCA, container images and secrets. The pipeline runs in report-only mode: each job publishes its findings to the repository Security tab and retains them as build artifacts, and reports them without blocking the merge.

## Structure

```
security-platform/
├── .github/              # Canonical CI/CD security-scanning workflow (Milestone 2)
│   ├── workflows/security.yml       # Callable workflow — the canonical copy a consumer adopts
│   ├── workflows/pr-security.yml    # Local pull_request caller
│   └── dependabot.yml               # Actions SHA-pin update config
├── workstation/          # Developer workstation security (Milestone 1)
│   ├── ARCHITECTURE.md   # Architecture, design decisions, tool model
│   ├── README.md         # Quick start and usage guide
│   ├── setup.sh          # Workstation bootstrap script
│   └── cicd/             # CI helper scripts (markdown linting)
├── cicd/                 # CI/CD security gate design package (Milestone 2)
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
| `cicd/` | M2 — CI/CD Security Gate | Complete (GitHub Actions) | GitHub Actions pipeline live-validated (Phases 14-19); Azure DevOps and GitLab members are unvalidated drafts |
| `infrastructure/` | M3 — Self-Hosted Services | Planned | Nexus, DefectDojo, Helm values, K8s manifests |
| `runtime/` | M4 — Runtime Security | Planned | Trivy Operator, Falco, Cosign, Kyverno policies |

## Getting Started

From inside any git repository, run the workstation setup:

```bash
bash path/to/security-platform/workstation/setup.sh
```

See [`workstation/README.md`](workstation/README.md) for the full guide.
