# Architecture

**Analysis Date:** 2026-03-15

## Pattern Overview

**Overall:** Documentation-driven reference architecture for a zero-cost, open-source security and supply chain scanning stack.

**Key Characteristics:**
- Single primary reference document (`development-security-stack-option-1.md`) containing complete blueprint, copy-pasteable configs, and ASCII architecture diagrams
- 4-phase layered security architecture: Workstation → CI/CD → Kubernetes Infrastructure → Runtime
- Append-only ADR (Architectural Decision Records) pattern for documenting changed decisions
- Milestone-based implementation roadmap decomposing the reference into 7 implementable stages with 28 total features
- All tools are free, open-source, locally-runnable or self-hosted; zero external accounts required

## Layers

**Workstation Layer:**
- Purpose: Developer machine with pre-commit hooks, linting, and secrets detection gates
- Location: `docs/development-security-stack-option-1.md` (sections: "Shift-Left Linting Layer", "Pre-commit Configuration")
- Contains: Pre-commit framework configuration, Tier 1 linting hooks (ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint), Tier 2 secrets detection (Gitleaks), CLI tools for on-demand scanning
- Depends on: None (starting milestone M1)
- Used by: Individual developers; feeds into CI/CD gate

**CI/CD Gate Layer (GitHub Actions):**
- Purpose: Enforce security scanning on every PR and push as blocking gates
- Location: `docs/development-security-stack-option-1.md` (sections: "Complete GitHub Actions Workflow", "Implementation Phases" → Phase 2)
- Contains: GitHub Actions workflow definitions for SAST (Semgrep), IaC scanning (Checkov), Container scanning (Trivy), SCA (Syft + Grype), Secrets scanning (Gitleaks), output to SARIF and JSON artifacts
- Depends on: Workstation layer (M1)
- Used by: Pull request checks, branch protection enforcement, blocking merges on security findings

**Kubernetes Infrastructure Layer (Self-Hosted Services):**
- Purpose: Run unified security dashboards, artifact/package management, and runtime scanning in Kubernetes
- Location: `docs/development-security-stack-option-1.md` (sections: "Kubernetes Self-Hosted Services Summary", "Implementation Phases" → Phases 3–6)
- Contains: DefectDojo (unified dashboard), Nexus Repository (package proxy/cache), Trivy Operator (K8s workload scanning), optional SonarQube and Harbor, networking/TLS/backup infrastructure
- Depends on: K8s cluster availability; CI/CD gate (M2) for data ingest
- Used by: Security teams and architects reviewing findings, developers checking artifact quality

**Runtime Security Layer:**
- Purpose: Detect and respond to runtime anomalies in the cluster
- Location: `docs/development-security-stack-option-1.md` (sections: "Implementation Phases" → Phase 6: "Runtime Security"), `docs/adr/adr013-falco-runtime-detection.md`, `docs/adr/adr014-cosign-slsa-kyverno.md`
- Contains: Falco CE + FalcoSidekick (runtime anomaly detection), Cosign keyless image signing, SLSA provenance, Kyverno admission control
- Depends on: Kubernetes infrastructure (M3–M5)
- Used by: Cluster admins and incident response teams

## Data Flow

**Code Commit to Merge Workflow:**

1. Developer commits code to feature branch (Workstation layer: pre-commit hooks block secrets, syntax errors, style violations)
2. Developer pushes to GitHub
3. GitHub Actions workflow triggers on PR (CI/CD gate layer: Semgrep, Checkov, Trivy, Syft+Grype, Gitleaks all run)
4. Scan results output to:
   - SARIF → GitHub Security tab (visible in PR, requires remediation or risk acceptance)
   - JSON artifacts → CI artifact storage (downloadable for local review)
   - DefectDojo API → Ingested directly into unified dashboard (Kubernetes layer)
5. Branch protection enforces: status checks pass + 1+ reviewer approval + dismiss stale PR approvals
6. Merge to main triggers post-merge scanning (safety net, via same workflow on push event)

**Unified Dashboard Workflow (DefectDojo):**

1. CI/CD produces scan results (SARIF, JSON) from Semgrep, Checkov, Trivy, Grype, Gitleaks
2. DefectDojo ingests results via API (M4-F3: "CI-to-DefectDojo import automation")
3. DefectDojo deduplicates, correlates, and assigns findings to engagements (products/projects)
4. Security team views trends, SLAs, remediation status in unified interface
5. Optional: SonarQube Community Build ingests code quality findings (OWASP Top 10, tech debt, metrics)

**Package Flow (Nexus Repository):**

1. Developer workstation configured to point npm, pip, docker, helm at Nexus proxy repositories
2. First install: Nexus caches package from upstream (npmjs, PyPI, Docker Hub, Helm Charts) on demand
3. Subsequent installs: served from cache (fast, consistent)
4. Nexus repositories are grouped in order: internal private repos first, then public proxies (mitigates dependency confusion)

**Container Image Signing & Admission Control (Runtime layer):**

1. CI builds container image, pushes to registry
2. Cosign signs image keylessly (OIDC token from GitHub Actions)
3. slsa-github-generator creates SLSA provenance (linking image to source commit)
4. Kyverno admission controller on cluster enforces: all runtime images must be signed by known keys
5. Runtime: Falco detects anomalous process execution, syscalls; alerts via FalcoSidekick

**State Management:**

- **Mutable state (Kubernetes cluster):** DefectDojo database (PostgreSQL-backed), Nexus database (backing artifact cache), Prometheus metrics (kube-prometheus-stack optional in M5-F4), Falco event stream
- **Immutable state (Git repository):** `.pre-commit-config.yaml`, GitHub Actions workflow definitions, Helm values files, Kubernetes manifests, configuration code as checked into version control
- **CI artifacts (ephemeral):** JSON scan results in GitHub Actions artifact storage (retention configurable per GH settings)

## Key Abstractions

**Security Tool Abstraction:**
- Purpose: Standardize scanner output to SARIF (OASIS format) for GitHub integration and JSON for DefectDojo/archive
- Examples: `docs/development-security-stack-option-1.md` sections "Complete GitHub Actions Workflow" and "Viewing Results — Where to Look"
- Pattern: Each scanner (Semgrep, Checkov, Trivy, Grype) is run with `--json` and `--sarif` output flags; results are uploaded to GitHub Code Scanning API and DefectDojo API independently

**IaC Abstraction (4-Phase Model):**
- Purpose: Organize security scanning by infrastructure layer (developer machine, CI/CD, K8s infrastructure, runtime)
- Examples: ADR records in `docs/adr/` document decisions per layer; milestones in `docs/milestone-plan/` organize work by phase
- Pattern: Each phase has prerequisite scanner coverage and infrastructure requirements; phases can run in parallel where dependencies allow

**Milestone Abstraction:**
- Purpose: Decompose the full reference blueprint into 7 independently-useful implementation stages
- Examples: Milestones M1–M7 in `docs/milestone-plan/`
- Pattern: Each milestone produces a usable capability increment; dependencies are explicitly documented in a directed graph (M1 → M2 → M4 → M5 → M6/M7 in critical path; M3 runs in parallel)

**ADR (Architectural Decision Record) Abstraction:**
- Purpose: Document and version-control decisions to change the architecture (e.g., removing `continue-on-error` from workflows)
- Examples: `docs/adr/adr001-remove-continue-on-error.md` through `adr014-cosign-slsa-kyverno.md`
- Pattern: Append-only; one file per decision; status (Accepted/Superseded/Deprecated); immutable history

## Entry Points

**Reference Document Entry Point:**
- Location: `docs/development-security-stack-option-1.md`
- Triggers: When a developer needs to understand the full stack architecture, tool selection, or copy-paste configs
- Responsibilities: Complete blueprint covering all 4 layers, tool selection rationale, copy-pasteable YAML/configs, cost summary, coverage matrix, known gaps

**Implementation Roadmap Entry Point:**
- Location: `docs/milestone-plan/README.md`
- Triggers: When deciding what to implement first and in what order
- Responsibilities: Break down the reference document into 7 milestones; clarify prerequisites and dependencies; list 28 features with completion criteria

**Architectural Decision Entry Point:**
- Location: `docs/adr/README.md` (index) + individual `docs/adr/adr00X-*.md` files
- Triggers: When justifying a change to the architecture or understanding why a decision was made
- Responsibilities: One ADR per decision; immutable history; context + decision + consequences for each change

**CICD Automation Entry Point:**
- Location: `cicd/lint-markdown.sh`, `cicd/pre-commit.sh`
- Triggers: When adding markdown files or setting up pre-commit hooks locally
- Responsibilities: Automated linting of markdown files (auto-fix safe violations, report errors); integration with pre-commit framework

## Error Handling

**Strategy:** Fail-fast on security gates; document gaps honestly.

**Patterns:**

- **Pre-commit hooks (Workstation):** If a hook fails (e.g., Gitleaks finds a secret), the commit is blocked and the developer must fix the issue or use `--no-verify` (with documentation that this bypasses the gate; see ADR-011)
- **CI/CD scanners (GitHub Actions):** Scanners are run with severity flags (e.g., `--fail-on high` for Grype, `--error` for Semgrep); if findings exceed the threshold, the workflow fails and blocks the merge unless explicitly overridden via branch protection bypass or risk acceptance (documented in PR comments)
- **Missing tools:** If a tool is unavailable locally (e.g., markdownlint-cli2), the lint script gracefully falls back to `npx --yes markdownlint-cli2@0.21.0` (just-in-time install via npm)
- **Known gaps:** Rather than adding incomplete tool coverage, gaps are explicitly documented in `docs/development-security-stack-option-1.md` under "Known Gaps and Out-of-Scope" (e.g., DAST / OWASP ZAP acknowledged but not included due to lack of test environment)

## Cross-Cutting Concerns

**Logging:** Not centralized in this reference architecture. Logs exist at each layer:
- Workstation: stdout/stderr from pre-commit hooks and CLI tools
- CI/CD: GitHub Actions job logs (visible in GitHub UI); SARIF and JSON artifacts stored in CI
- Kubernetes: Application logs in container stdout/stderr (viewable via `kubectl logs`); optional kube-prometheus-stack for metrics (M5-F4)
- Runtime: Falco event stream via FalcoSidekick (M6-F2)

**Validation:**
- Workstation: pre-commit hooks validate syntax (ShellCheck, `terraform fmt`, `eslint`) and catch secrets (Gitleaks)
- CI/CD: GitHub Actions workflow validates that all scanners complete; branch protection validates that security status checks pass
- Kubernetes: Kyverno admission control validates that runtime images are signed and conform to policies
- Configuration: Helm values are externalized and version-controlled (ADR-007); Kubernetes manifests are linted via yamllint (M1-F1)

**Authentication:**
- GitHub Actions: Uses GitHub-provided OIDC token for Cosign keyless signing (M6-F3); no credential files needed
- Kubernetes: Service accounts with role-based access control (RBAC) for DefectDojo, Nexus, Falco, Kyverno deployments
- Secrets: Stored in GitHub Secrets (Actions environment variables), not hardcoded; environment variable patterns documented in ADR-005
- Nexus, DefectDojo, Harbor: Deployed self-hosted in Kubernetes with internal authentication (no external accounts)

---

*Architecture analysis: 2026-03-15*
