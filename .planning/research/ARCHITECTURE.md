# Architecture Research

**Domain:** Self-hosted developer security and supply chain scanning stack
**Researched:** 2026-03-15
**Confidence:** HIGH (derived from the project's own 2,300-line reference document, 14 ADRs, and three-agent red-team analysis)

## Standard Architecture

### System Overview

The stack follows a 4-layer defense-in-depth model. Each layer operates independently so that failure in a downstream layer does not disable upstream protection.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 1: Developer Workstation                    │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐    │
│  │ pre-commit │  │  Linters   │  │  Gitleaks  │  │  CLI Tools │    │
│  │ (orchestr) │  │ (Tier 1)   │  │  (Tier 2)  │  │ (on-demand)│    │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └────────────┘    │
│        │               │               │                            │
│        └───────────────┴───────────────┘                            │
│                        │ git push                                   │
├────────────────────────┼────────────────────────────────────────────┤
│                    LAYER 2: CI/CD Gate                               │
│                        ▼                                            │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐    │
│  │ Semgrep CE │  │  Checkov   │  │   Trivy    │  │  Gitleaks  │    │
│  │   (SAST)   │  │   (IaC)    │  │(Container) │  │(full hist) │    │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘    │
│  ┌─────┴──────┐        │               │               │           │
│  │ Syft+Grype │        │               │               │           │
│  │   (SCA)    │        │               │               │           │
│  └─────┬──────┘        │               │               │           │
│        └───────────────┴───────────────┴───────────────┘           │
│                        │ SARIF + JSON + API                         │
│               ┌────────┴────────┐                                   │
│               │ GitHub Security │ (SARIF upload)                    │
│               │      Tab        │                                   │
│               └─────────────────┘                                   │
├────────────────────────┼────────────────────────────────────────────┤
│                    LAYER 3: K8s Infrastructure                       │
│                        ▼                                            │
│  ┌──── Dashboards ──────────────┐  ┌── Artifact Management ──────┐ │
│  │  ┌────────────────────────┐  │  │  ┌────────────────────────┐ │ │
│  │  │     DefectDojo         │  │  │  │  Nexus Repository CE   │ │ │
│  │  │  (unified findings DB) │  │  │  │  (pkg proxy + cache)   │ │ │
│  │  └────────────────────────┘  │  │  └────────────────────────┘ │ │
│  └──────────────────────────────┘  └─────────────────────────────┘ │
│                                                                     │
│  ┌── Hardening ──────────────────────────────────────────────────┐  │
│  │  NetworkPolicy  ·  cert-manager (TLS)  ·  Backups (CronJob)  │  │
│  │  kube-prometheus-stack (monitoring)  ·  Version update SOP    │  │
│  └──────────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────────┤
│                    LAYER 4: Runtime Security                        │
│  ┌────────────┐  ┌────────────────┐  ┌──────────┐  ┌───────────┐  │
│  │   Trivy    │  │ Falco CE +     │  │  Cosign  │  │  Kyverno  │  │
│  │  Operator  │  │ FalcoSidekick  │  │ (signing)│  │(admission)│  │
│  │(continuous │  │ (anomaly       │  │          │  │           │  │
│  │ scanning)  │  │  detection)    │  │          │  │           │  │
│  └────────────┘  └────────────────┘  └──────────┘  └───────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Layer | Typical Implementation |
|-----------|----------------|-------|------------------------|
| pre-commit framework | Orchestrates git hook execution on commit/push | L1 Workstation | `pre-commit` Python package with `.pre-commit-config.yaml` per repo |
| Tier 1 linters (ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint, npm audit, tf fmt) | Fast quality/formatting checks on every commit | L1 Workstation | Hooks managed by pre-commit; language-specific linters |
| Gitleaks (Tier 2) | Secrets detection gate before push | L1 Workstation | pre-push hook; blocks pushes containing secrets patterns |
| CLI tool suite (Trivy, Syft, Grype, Semgrep, Checkov) | On-demand local scanning for developers | L1 Workstation | Homebrew/pip installed binaries, run manually |
| GitHub Actions workflow | Automated 5-scanner parallel gate on every PR | L2 CI/CD | `.github/workflows/security.yml` with SAST, IaC, SCA, container, secrets jobs |
| SARIF upload | PR-visible findings in GitHub Security tab | L2 CI/CD | `github/codeql-action/upload-sarif` action |
| Branch protection | Enforcement mechanism -- makes CI gate blocking | L2 CI/CD | GitHub repo settings; required status checks |
| Nexus Repository CE | Caching proxy for all upstream package registries | L3 K8s | Helm chart in `nexus` namespace; npm, PyPI, Docker, Helm proxies |
| DefectDojo | Unified vulnerability dashboard, lifecycle tracking, dedup | L3 K8s | Helm chart in `defectdojo` namespace; PostgreSQL backend |
| NetworkPolicy | Namespace isolation for security services | L3 K8s | Default-deny ingress per namespace + explicit allow rules |
| cert-manager | TLS certificate provisioning for internal services | L3 K8s | Helm chart; issues certs for Ingress resources |
| kube-prometheus-stack | Monitoring and alerting for the security stack itself | L3 K8s | Prometheus + Grafana + Alertmanager Helm release |
| Backup CronJobs | Data protection for DefectDojo PG and Nexus PVC | L3 K8s | `pg_dump` CronJob + VolumeSnapshot |
| Trivy Operator | Continuous vulnerability scanning of running K8s workloads | L4 Runtime | Helm chart in `trivy-system`; generates VulnerabilityReports |
| Falco CE + FalcoSidekick | Runtime anomaly detection (unexpected processes, privesc) | L4 Runtime | DaemonSet on every node; alerts via webhook/Slack |
| Cosign (keyless) | Image signing in CI using GitHub OIDC | L4 Runtime | CI workflow job; no key management required |
| Kyverno | Admission control rejecting unsigned images | L4 Runtime | ClusterPolicy; starts in Audit mode, then Enforce |

## Data Flow

### Primary Security Data Flow

```
Developer writes code
    |
    v
[COMMIT] --> Tier 1 linters (fast, local) --> pass/fail
    |
    v
[PUSH] --> Gitleaks secrets gate (local) --> pass/fail
    |
    v
[PULL REQUEST] --> GitHub Actions (5 parallel scanner jobs)
    |                   |
    |                   +--> SARIF --> GitHub Security Tab (PR visibility)
    |                   +--> JSON  --> CI Artifacts (downloadable)
    |                   +--> API   --> DefectDojo (import via REST)
    |
    v
[DefectDojo] --> Unified dashboard
    |               Deduplication
    |               Lifecycle: Open -> Verified -> Mitigated -> Closed
    |               SLA tracking + trending
    |
    v
[Developer reviews] --> Triage weekly, severity-based auto-close for INFO/LOW
```

### Supply Chain Data Flow

```
npm install / pip install / docker pull / helm install
    |
    v
[Nexus Proxy] --> Cache hit? --> Return cached artifact
    |                  |
    |                  No
    |                  |
    |                  v
    |           [Upstream Registry] --> Download --> Cache --> Return
    |
    v
[CI SCA scanners] --> Grype + Trivy scan dependencies for CVEs
    |
    v
[Syft] --> SBOM generation for compliance
```

### Runtime Security Data Flow

```
[K8s Workloads running]
    |
    +---> Trivy Operator (continuous image + config scan)
    |         |
    |         +--> VulnerabilityReports (K8s CRDs)
    |         +--> Findings --> DefectDojo
    |
    +---> Falco DaemonSet (syscall monitoring per node)
    |         |
    |         +--> FalcoSidekick --> Slack/webhook alerts
    |         +--> FalcoSidekick UI (web dashboard)
    |
    +---> Kyverno admission controller
              |
              +--> Reject unsigned images at admission time
              +--> PolicyReports for audit trail
```

### Cross-Layer Communication Map

| Source | Destination | Protocol | Data | Direction |
|--------|------------|----------|------|-----------|
| Workstation pkg managers | Nexus | HTTP(S) | Package requests/responses | Bidirectional |
| GitHub Actions | GitHub Security Tab | SARIF upload | Scan findings | Push |
| GitHub Actions | DefectDojo API | HTTP(S) REST | JSON scan results | Push |
| GitHub Actions | Nexus Docker | HTTP(S) | Container image push | Push |
| Trivy Operator | DefectDojo API | HTTP(S) REST | VulnerabilityReport JSON | Push |
| Falco | FalcoSidekick | gRPC | Runtime alerts | Push |
| FalcoSidekick | Slack/webhook | HTTPS | Alert notifications | Push |
| Prometheus | All K8s services | HTTP scrape | Metrics | Pull |
| Cosign (CI) | Sigstore/Rekor | HTTPS | Keyless signatures | Push |
| Kyverno | Sigstore/Rekor | HTTPS | Signature verification | Pull |

## Recommended Project Structure

This is a documentation/configuration project, not application code. The repo structure organizes configs that get deployed to different layers.

```
security-stack/
├── docs/
│   ├── development-security-stack-option-1.md   # Primary reference document
│   ├── adr/                                     # Architectural Decision Records
│   │   ├── README.md                            # ADR index
│   │   └── ADR-001..014.md                      # Individual decisions
│   ├── milestone-plan/                          # Implementation milestones
│   │   ├── README.md                            # Dependency graph
│   │   └── milestone-1..7-*.md                  # Per-milestone plans
│   └── ARCHITECTURE_AND_DESIGN.md               # Design constraints
├── pre-commit/
│   └── .pre-commit-config.yaml                  # Template for all repos
├── workflows/
│   └── security.yml                             # GitHub Actions template
├── helm-values/
│   ├── defectdojo-values.yaml                   # Version-controlled Helm config
│   ├── nexus-values.yaml
│   ├── trivy-operator-values.yaml
│   ├── falco-values.yaml
│   └── kyverno-values.yaml
├── k8s/
│   ├── networkpolicies/                         # Per-namespace NetworkPolicies
│   ├── backups/                                 # CronJob manifests
│   └── monitoring/                              # Prometheus alerting rules
├── scripts/
│   └── defectdojo-import.sh                     # CI-to-DefectDojo import script
└── red-team/                                    # Red-team analysis findings
```

### Structure Rationale

- **helm-values/:** All Helm values version-controlled, not inline `--set` flags. Critical for reproducibility (ADR finding).
- **k8s/:** Infrastructure hardening configs separated from application Helm values because they are cluster-wide concerns, not per-service.
- **workflows/:** Template workflow that gets copied to each repo's `.github/workflows/`. Single source of truth for scanner configuration.
- **pre-commit/:** Template config for rollout to 6+ repos.

## Architectural Patterns

### Pattern 1: Defense in Depth with Independent Layers

**What:** Each layer (workstation, CI/CD, K8s infrastructure, runtime) provides security value independently. A failure at one layer does not cascade.

**When to use:** Always. This is the fundamental design principle.

**Trade-offs:**
- Pro: Resilient -- if pre-commit hooks are bypassed (`--no-verify`), CI catches it. If CI is skipped (direct push), branch protection blocks it.
- Pro: Incremental deployment -- Layer 1 + 2 provide value before any K8s infrastructure exists.
- Con: Some redundancy (Gitleaks runs both at push and in CI), but this is intentional overlap, not waste.

### Pattern 2: Pull Request as Primary Security Gate

**What:** The PR is where all automated security enforcement happens. Branch protection makes scanner status checks required for merge. Everything before the PR (pre-commit) is defense-in-depth convenience. Everything after the PR (DefectDojo, runtime) is visibility and monitoring.

**When to use:** Always for code-level security scanning.

**Trade-offs:**
- Pro: Server-side enforcement cannot be bypassed by the developer.
- Pro: Findings are visible to the reviewer in the PR diff context.
- Con: Requires branch protection configuration -- without it, the gate is purely advisory (a critical pitfall identified by red-team).

### Pattern 3: Centralized Findings Aggregation

**What:** All scan results from all tools and all repositories flow into a single DefectDojo instance. No tool's output is the source of truth -- DefectDojo is.

**When to use:** Once you have more than one scanner or more than one repository.

**Trade-offs:**
- Pro: Single view across tools, deduplication eliminates double-counting from overlapping scanners.
- Pro: Lifecycle tracking (Open -> Mitigated -> Closed) persists across scan runs.
- Con: DefectDojo becomes a critical dependency for vulnerability management visibility.
- Con: PostgreSQL database must be backed up -- data loss destroys the entire vulnerability history.

### Pattern 4: Transparent Proxy for Supply Chain Visibility

**What:** Nexus sits between all package managers and upstream registries. It caches artifacts and provides a single audit point for what enters the build environment.

**When to use:** When you need offline build capability, faster builds (cache hits), or a choke point for supply chain auditing.

**Trade-offs:**
- Pro: Faster subsequent installs, offline capability, single point of observation.
- Con: Nexus does NOT scan or filter content -- it is a caching proxy, not a security gate. Grype and Trivy handle the actual vulnerability scanning. This distinction matters (red-team finding).
- Con: Group repository ordering must be configured correctly (hosted before proxy) to prevent dependency confusion attacks.

### Pattern 5: Audit-Then-Enforce for Admission Control

**What:** Kyverno policies start in `Audit` mode (log violations without blocking) before switching to `Enforce` mode. This prevents breaking existing workloads on day one.

**When to use:** Any admission controller or policy engine deployment.

**Trade-offs:**
- Pro: Discover what would break before it breaks.
- Pro: PolicyReports give visibility into unsigned image usage.
- Con: Audit mode provides zero enforcement -- it must be transitioned to Enforce after review.

## Scaling Considerations

This stack is designed for a single developer with 6+ repositories. Scaling concerns are about resource consumption, not request throughput.

| Concern | At 6 repos | At 20 repos | At 50+ repos |
|---------|-----------|-------------|-------------|
| CI runner time | 5 parallel jobs, ~3-5 min per PR | Same per PR, but more PRs | Consider self-hosted runners for cost |
| DefectDojo finding volume | 125-750 findings per repo first run | Triage SOP is critical; auto-close INFO/LOW | Need team triage or finding volume becomes unmanageable |
| Nexus disk | 50 Gi sufficient | 50 Gi may need expansion | Monitor blob store usage; alert at 80% |
| K8s cluster resources | ~6.5 Gi RAM, 3.5 cores (core stack) | Same -- services scale by data, not repos | Same unless adding optional services |
| Falco overhead | 512 Mi per node | Same (DaemonSet) | Same per node |

### Scaling Priorities

1. **First bottleneck: Finding volume triage.** The red-team analysis estimated 125-750 findings per repo on first scan. At 6 repos, that is 750-4,500 findings. Without `checkov --create-baseline`, severity-based auto-close, and a weekly time-boxed triage cadence, the developer abandons DefectDojo within weeks. This is the most likely failure mode of the entire stack.

2. **Second bottleneck: Nexus disk.** Nexus caches every package version ever pulled. With Docker images, this grows fast. Set up Prometheus alerting on disk usage before it becomes a crisis.

## Anti-Patterns

### Anti-Pattern 1: Advisory-Only Security Gates

**What people do:** Set up CI scanners but leave `continue-on-error: true` on all steps, or skip branch protection configuration.
**Why it's wrong:** Every scan "passes" regardless of findings. The gate is decorative. Developers learn to ignore it. The PR reviewer sees green checks on PRs with 200 critical vulnerabilities.
**Do this instead:** Remove `continue-on-error` from scanner steps (keep it only on upload steps). Configure branch protection with scanner jobs as required status checks. Test that a failing scan actually blocks merge.

### Anti-Pattern 2: Treating Nexus as a Security Control

**What people do:** Deploy Nexus and claim "supply chain is secured" because packages flow through it.
**Why it's wrong:** Nexus in proxy mode is a transparent cache. It does not scan, filter, or block malicious packages. A compromised npm package passes through Nexus identically to a clean one.
**Do this instead:** Acknowledge Nexus as an audit point and cache. Rely on Grype, Trivy, and Syft for actual supply chain vulnerability detection. Configure group repository ordering (hosted before proxy) to prevent dependency confusion.

### Anti-Pattern 3: Unmonitored Security Infrastructure

**What people do:** Deploy the security stack and assume it is working because no alerts fire.
**Why it's wrong:** If Trivy Operator stops scanning, the dashboard shows the last known state as if current. If DefectDojo import fails, findings stop flowing in silently. Absence of alerts looks identical to a clean environment.
**Do this instead:** Deploy kube-prometheus-stack. Alert on: Nexus disk usage > 80%, DefectDojo import failures, Trivy Operator DB staleness, pod CrashLoopBackOff in security namespaces.

### Anti-Pattern 4: `tag="latest"` for Stateful Services

**What people do:** Deploy DefectDojo or Nexus with `tag="latest"` in Helm values.
**Why it's wrong:** A pod restart silently pulls a new major version with breaking schema migrations. The security dashboard disappears or corrupts its database without warning.
**Do this instead:** Pin to specific versions in version-controlled `values.yaml` files. Upgrade deliberately with backup taken first.

### Anti-Pattern 5: Plaintext Tokens in Documentation and Workflows

**What people do:** Copy `DD_TOKEN="your-token"` from documentation into real workflows.
**Why it's wrong:** A compromised DefectDojo API token grants read/write to the complete vulnerability inventory -- the most sensitive output of the entire stack.
**Do this instead:** Use `${{ secrets.DEFECTDOJO_API_TOKEN }}` in workflows and `${DEFECTDOJO_API_TOKEN}` environment variables in scripts. Never hardcode tokens.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| GitHub (repos) | Git push/PR triggers | Primary code hosting; branch protection is the enforcement mechanism |
| GitHub Actions | Workflow execution | GitHub-hosted runners; no self-hosted runner infrastructure needed |
| GitHub Security Tab | SARIF upload via Action | Read-only visibility; not an enforcement point |
| Upstream registries (npmjs, PyPI, Docker Hub, Helm) | Proxied through Nexus | Nexus caches; direct upstream access remains as fallback |
| Sigstore/Rekor | Cosign keyless signing + Kyverno verification | Public transparency log; no account needed |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| CI -> DefectDojo | REST API (HTTP/HTTPS) | API token via GitHub Secrets; import script in workflow post-step |
| CI -> Nexus Docker | Docker push (HTTP/HTTPS) | Container images pushed after build |
| Workstation -> Nexus | Package manager config (HTTP/HTTPS) | npm, pip, docker, helm all configured to point at Nexus |
| Trivy Operator -> DefectDojo | REST API (HTTP/HTTPS) | Exports VulnerabilityReport CRDs as JSON for import |
| Falco -> FalcoSidekick | gRPC (internal) | DaemonSet to centralized forwarder |
| Prometheus -> All services | HTTP scrape (pull) | Per-service /metrics endpoints; Nexus has native Prometheus support |
| Kyverno -> K8s API | Admission webhook | Intercepts pod creation to verify image signatures |

## Build Order (Dependency-Driven)

The build order follows the milestone dependency graph. Two independent tracks converge at M4.

```
Track A (no infra required):     Track B (requires K8s):
  M1: Workstation Foundation       M3: Nexus Repository
       |                                |
  M2: CI/CD Security Gate              |
       |                                |
       +----------------+--------------+
                         |
                    M4: DefectDojo
                         |
                    M5: Hardening
                         |
                    +----+----+
                    |         |
               M6: Runtime  M7: Optional
```

**Why this order:**

1. **M1 first** because it requires zero infrastructure, delivers immediate value (secrets detection on every push), and validates tool installation that CI will reuse.
2. **M2 second** because it turns workstation tools into an enforced server-side gate. Still no infrastructure needed -- GitHub-hosted runners do everything.
3. **M3 can start anytime** once K8s is available. It is independent of M1/M2 and can run in parallel.
4. **M4 requires both M2 and M3** because it ingests CI scan results (needs M2 working) and runs on K8s alongside Nexus (needs M3 to validate K8s deployment patterns).
5. **M5 after M4** because hardening (NetworkPolicy, TLS, monitoring, backups) applies to the services deployed in M3 and M4. You cannot harden what does not exist yet.
6. **M6 and M7 after M5** because runtime security (Falco, Kyverno) depends on a hardened cluster foundation. Admission control (Kyverno) should not be deployed before NetworkPolicies and TLS are in place.

**Critical path:** M1 -> M2 -> M4 -> M5 -> M6 (serial, each builds on the last).

**Parallel opportunity:** M3 runs alongside M1+M2 on the K8s track. M6 and M7 are independent of each other after M5.

## Sources

- Primary reference document: `docs/development-security-stack-option-1.md` (2,300 lines, includes all architecture diagrams, data flows, tool configs, and implementation phases)
- Architecture and design constraints: `docs/ARCHITECTURE_AND_DESIGN.md` (red-team response, 12 design decisions)
- Milestone dependency graph: `docs/milestone-plan/README.md` (7 milestones, 28 features)
- 14 Architectural Decision Records: `docs/adr/ADR-001..014.md`
- Three-agent red-team analysis: `red-team/00-consolidated-findings.md` (15 convergent findings)

---
*Architecture research for: zero-cost developer security and supply chain scanning stack*
*Researched: 2026-03-15*
