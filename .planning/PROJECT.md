# Security & Supply Chain Scanning Stack

## What This Is

A zero-cost, open-source security and supply chain scanning stack for a single-developer AWS cloud practice. Covers the full development lifecycle — workstation linting and secrets detection, CI/CD security gates, Kubernetes-hosted artifact management and vulnerability dashboards, infrastructure hardening, and runtime security. All tools are free, self-hosted, and require no external accounts or logins.

## Core Value

Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production — with zero ongoing cost and zero vendor lock-in.

## Requirements

### Validated

- [x] Pre-commit Tier 1: quality and linting hooks (ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint, npm audit, terraform fmt/validate) on every commit
- [x] Pre-commit Tier 2: Gitleaks secrets detection on every push
- [x] Security CLI tool suite: Trivy, Syft, Grype, Semgrep CE, Checkov, Gitleaks installed and functional

### Active

(None yet — define for next milestone via `/gsd:new-milestone`)

### Validated (v1.1)

- [x] Cross-platform tool installation script (replaces Homebrew with pipx/binary downloads)
- [x] Distribution package: setup.sh command for fresh git repos (install + configure + activate)
- [x] Distribution drops all config files (pre-commit, linting, secrets detection)
- [x] Hooks use file-pattern matching for selective execution (universal config, language-aware)
- [x] Setup script is idempotent and bash 3.2 compatible (macOS stock bash)
- [x] Version check and update capability (`check`, `update`, `doctor` subcommands) — v1.1

### Future (M2+)

- [ ] GitHub Actions security workflow: 5 parallel scan jobs (SAST, IaC, SCA, container, secrets) on every PR
- [ ] SARIF upload to GitHub Security tab for PR visibility
- [ ] JSON artifact retention for downstream DefectDojo import
- [ ] Branch protection enforcement: failing scans block merge, direct pushes blocked
- [ ] Dependabot for GitHub Actions SHA digest updates
- [ ] Nexus Repository proxy deployment on Kubernetes (npm, PyPI, Docker, Helm)
- [ ] Workstation package managers routed through Nexus
- [ ] DefectDojo unified security dashboard on Kubernetes
- [ ] CI-to-DefectDojo automated import pipeline
- [ ] Deduplication and triage workflow configuration
- [ ] Checkov baseline for existing repos (only new findings flagged)
- [ ] NetworkPolicy namespace isolation for all security services
- [ ] TLS via cert-manager for all internal service communication
- [ ] Backup automation for stateful services (DefectDojo PostgreSQL, Nexus PVC)
- [ ] Monitoring and alerting via kube-prometheus-stack
- [ ] Version update process for all tools and Helm charts
- [ ] Trivy Operator for continuous K8s workload scanning
- [ ] Falco CE + FalcoSidekick for runtime anomaly detection
- [ ] Cosign keyless image signing in CI
- [ ] Kyverno admission control rejecting unsigned images

### Out of Scope

- SonarQube Community Build — optional enhancement, deferred to M7 if desired
- Harbor Container Registry — optional enhancement, deferred to M7 if desired
- Commit signing — optional enhancement, deferred to M7 if desired
- Multi-developer RBAC or team access controls — single-developer practice
- Paid tools or SaaS subscriptions — zero-cost constraint
- Production Kubernetes workload deployment — this stack secures the development pipeline, not the application runtime

## Current State

**Shipped: v1.1 Distribution Packaging** (2026-09-10) — Phases 10-13, 12 plans, 15/15 requirements.

Cross-platform install + setup + maintenance tooling now replaces the Homebrew-only M1 workflow: `workstation/setup.sh` bootstraps any git repo (install tools, generate configs, activate hooks) and supports `check`/`update`/`doctor` subcommands for ongoing maintenance. Version manifest pins 6 tools (pre-commit, Trivy, Syft, Grype, Gitleaks, hadolint); pre-commit and Semgrep/Checkov via pipx are still deferred to CI (M2) per INST-05 scope decision.

## Next Milestone Goals

No milestone currently in progress. Candidates from Future (M2+) below — GitHub Actions security workflow (SAST/IaC/SCA/container/secrets scan jobs) is the natural next step per the M1→M2 critical path. Run `/gsd:new-milestone` to define scope.

## Context

- **Deployment model:** Single developer, personal AWS cloud practice with 6+ GitHub repositories
- **Existing infrastructure:** Kubernetes cluster already running (non-EKS), kubectl configured
- **Current security tooling:** v1.1 complete — `workstation/setup.sh` (security-platform repo) is the single onboarding entrypoint; `dist/install.sh` from M1/early v1.1 is retired (superseded 2026-03-20, commit 828f048)
- **Rollout strategy:** v1.1 produced the distribution package; remaining repos onboard via `setup.sh`
- **Reference document:** `docs/development-security-stack-option-1.md` (~2,300 lines) contains all tool configs, architecture diagrams, and copy-pasteable configurations
- **Milestone plans:** `docs/milestone-plan/` contains 7 detailed milestone documents with 28 features, done criteria, and verification checks
- **ADRs:** `docs/adr/` contains 14 architectural decision records (ADR-001 through ADR-014)
- **Languages covered:** Terraform, CDK, CloudFormation, Python, TypeScript/JavaScript, Bash, Kubernetes/YAML, Docker
- **GSD approach:** One GSD milestone at a time
- **Known issues (deferred, out of scope for v1.1):**
  - `aws-zabbix-monitoring-solution` package-lock.json has 16 real npm vulnerabilities (1 critical: handlebars, 10 high) as of 2026-09-10 — npm-audit hook correctly blocks commits until fixed; target-repo remediation is out of scope (tooling-focused milestone)
  - ESLint hook in `.pre-commit-config.yaml` uses `language: system` — if eslint is absent (it is, in aws-zabbix) and a `.js`/`.ts` file is ever staged, the hook errors with "command not found" rather than skipping silently. Accepted as known gap, not fixed.

## Constraints

- **Cost:** $0 — all tools must be free and open-source with no external account requirements
- **Self-hosted:** Everything runs locally or on the developer's own Kubernetes cluster
- **Single developer:** No team coordination overhead; tooling optimized for solo workflow
- **Milestone ordering:** M1 -> M2 -> M4 -> M5 -> M6 is the critical path; M3 (Nexus) can run in parallel with M1/M2 once K8s is available

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| One GSD milestone per implementation milestone | Keeps focus tight; each milestone produces a usable capability increment | Validated (M1 complete) |
| Start with one repo, then roll out | Validate the tooling works before applying to all repos | Validated (M1 complete) |
| Milestone verification checks as done criteria | The milestone docs already have thorough verification sections | Validated (M1 complete) |
| M7 features (SonarQube, Harbor, commit signing) deferred | Optional enhancements, not required for core security program | -- Pending |
| Replace Homebrew with cross-platform install methods | Portability across macOS and Linux; single install path | Validated (Phase 10) |
| Distribution package for repo onboarding | Low-touch rollout to remaining 4+ repos | Validated (Phase 12) |
| Explicit type/file filters on all hooks | Universal config works across all repo types | Validated (Phase 11) |
| Bash 3.2 compatibility | macOS ships bash 3.2 permanently (GPLv3 licensing) | Validated (Phase 12) |
| Replace `dist/install.sh` with `workstation/setup.sh` bootstrapper | Standalone installer too narrow; repos need config generation + hook activation too, not just tool install | Validated (Phase 12, commit 828f048) |
| INST-05 scope: only pre-commit installs via pipx; Semgrep/Checkov deferred to CI-only | Avoid duplicating CI-only tools on the workstation; requirement text left unnarrowed by deliberate choice | Validated (Phase 10, reconfirmed at v1.1 close) |
| `trap ... RETURN` in installer helpers must self-clear (`trap - RETURN` inside the handler) | Bash RETURN traps aren't function-scoped — they re-fire on the caller's return, crashing on an out-of-scope local under `set -u`. Found live-testing `setup.sh install` at v1.1 close | Validated (security-platform commit 2a70c97) |
| npm-audit / ESLint gaps found in aws-zabbix at v1.1 close are target-repo issues, not tooling bugs | Milestone scope is the distribution tooling, not remediating individual repos | Accepted as deferred — ⚠️ Revisit if aws-zabbix work resumes |

---
*Last updated: 2026-09-10 after v1.1 milestone*
