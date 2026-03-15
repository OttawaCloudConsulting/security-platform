# Project Research Summary

**Project:** Zero-Cost Developer Security and Supply Chain Scanning Stack
**Domain:** Self-hosted DevSecOps toolchain for a single-developer AWS cloud practice
**Researched:** 2026-03-15
**Confidence:** HIGH

## Executive Summary

This project is a documentation and configuration reference for a production-grade, zero-cost security scanning stack targeting a single developer managing multiple AWS cloud repositories. Research confirms the 4-layer defense-in-depth model (Workstation -> CI/CD -> K8s Infrastructure -> Runtime) is the correct architecture for this context: each layer provides independent value, failures do not cascade, and the first two layers deliver a usable security program with no infrastructure cost before any Kubernetes services are deployed. The recommended stack is fully validated against 2026 ecosystem state — all 18 tools are confirmed at current stable versions with appropriate license and cost constraints.

The most important implementation insight across all research areas is that the threat model is not primarily technical: it is operational. The stack can be deployed correctly and still fail when CI gates are advisory-only, branch protection is not configured, finding volume overwhelms the solo developer, or monitoring is deferred until tools silently stop working. Three independent red-team agents converged on the same set of 15 pitfalls, all of which are operational in nature rather than architectural. The tools are sound; the risk is in how they are wired together and operated.

The recommended delivery sequence is two phases of no-infrastructure work (Workstation Foundation, CI/CD Gate) followed by five phases that progressively build and harden Kubernetes-hosted services. M1+M2 constitute a complete, minimal viable security program on their own. M3 through M7 extend that program into supply chain visibility, unified vulnerability management, and runtime security. The single most impactful thing the implementation plan can do is treat branch protection and CI gate enforcement as hard deliverables in M2, not afterthoughts.

## Key Findings

### Recommended Stack

All tools are open-source, zero-cost, and require no external accounts. The stack is fully current for March 2026, with two critical version warnings: Grype must be >= 0.88.0 (DB schema v5 reached EOL on 2026-03-06) and Trivy must be >= 0.69.2 (security incident resolved). The Kyverno `ClusterPolicy` YAML API is deprecated in 1.17 in favor of CEL-based `ValidatingPolicy` — migrations should be planned but existing policies continue to function. The Falco legacy eBPF probe was deprecated in 0.43; the modern eBPF driver (`driver.kind: modern_ebpf`) must be used.

**Core technologies:**
- **Semgrep CE 1.155.0:** SAST (intra-file, pattern-based) — fastest zero-cost SAST with no account required; multicore in Fall 2025 release
- **Checkov 3.2.508:** IaC scanning (Terraform, CloudFormation, CDK, K8s, GHA workflows) — 1,000+ built-in policies, graph-based cross-resource analysis, Apache 2.0
- **Trivy 0.69.3:** Container scanning + IaC + secrets + SBOM — single binary covering multiple scan types; Swiss army knife from Aqua Security
- **Syft 1.42.2 + Grype 0.109.1:** SBOM generation + SCA vulnerability matching — Grype now includes CISA KEV and EPSS data for prioritization
- **Gitleaks 8.24+:** Secrets detection in git history and pre-push — MIT, purpose-built, fast; composite rules in v8.28 for accuracy
- **DefectDojo 2.x:** Unified vulnerability management dashboard — 200+ scanner parsers, finding lifecycle, SLA tracking; the aggregation layer that makes multi-scanner output actionable
- **Nexus Repository CE 3.90.x:** Universal artifact proxy (npm, PyPI, Docker, Helm) — CE gained Docker/npm/PyPI support in v3.77.0; single audit point for upstream package traffic; 40K component limit is sufficient for single-dev
- **Trivy Operator 0.32.x:** Continuous K8s workload scanning — produces VulnerabilityReports and ConfigAuditReports as K8s CRDs
- **Falco CE 0.43.0 + FalcoSidekick:** Runtime anomaly detection — CNCF Graduated; eBPF-based syscall monitoring; modern eBPF driver required
- **Cosign 3.0.5 + Kyverno 1.17.1:** Keyless image signing + admission control — no key management via GitHub OIDC; Kyverno CEL engine promoted to v1 in 1.17
- **kube-prometheus-stack 82.10.x:** Monitoring and alerting for the security stack itself — Prometheus + Grafana + Alertmanager
- **pre-commit 4.5.x:** Hook orchestration (8 language-specific linters + Gitleaks) — Dependabot now supports pre-commit hook updates (March 2026)

### Expected Features

Research identifies a clear three-tier feature model corresponding directly to the M1-M2 / M3-M5 / M6-M7 phase structure.

**Must have (table stakes — M1+M2):**
- Pre-commit linting for all language types (ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint) — immediate commit-level feedback
- Secrets detection at push (Gitleaks pre-push hook) AND in CI (compensating control for `--no-verify` bypass)
- SAST in CI (Semgrep CE) — do NOT run in pre-commit; full-repo analysis creates friction without proportional value
- IaC scanning in CI (Checkov) with baseline for existing repos — without baseline, first run generates hundreds of findings that kill adoption
- SCA via Syft+Grype — SBOM generation is increasingly regulatory-required (EO 14028, EU CRA)
- Container image scanning (Trivy) in CI
- 5-job parallel CI pipeline (SARIF upload + JSON artifacts + branch protection) — without branch protection, every gate is advisory only

**Should have (differentiators — M3-M5):**
- Supply chain proxy (Nexus) — protects against dependency confusion, provides audit point; most single-dev setups skip this entirely
- Unified findings aggregation (DefectDojo) with deduplication and lifecycle tracking — transforms dashboard into security program
- CI-to-DefectDojo import automation
- Checkov baseline for existing repos
- NetworkPolicy default-deny isolation for security namespaces
- TLS for all internal service communication (cert-manager)
- Backup automation for DefectDojo PostgreSQL and Nexus PVC
- Monitoring and alerting (kube-prometheus-stack) — without this, security tools fail silently

**Defer (v2+ — M6-M7):**
- Trivy Operator runtime scanning — requires hardened K8s (M5) as prerequisite
- Falco runtime anomaly detection — highest complexity, requires custom rule tuning
- Cosign keyless signing + Kyverno admission control — requires established container registry workflow
- SonarQube — optional code quality metrics, not security-critical
- Harbor — optional if Nexus Docker proxy is sufficient
- Commit signing — minimal value for single-developer practice

**Explicitly excluded anti-features:** SAST/IaC in pre-commit, DAST, SonarQube as core component, multi-developer RBAC, paid/SaaS tools, real-time alerting on every finding.

### Architecture Approach

The stack follows a 4-layer defense-in-depth model where each layer provides independent security value. The key architectural insight is that the PR is the primary enforcement boundary — everything before it (pre-commit) is convenience, and everything after it (DefectDojo, runtime tools) is visibility and monitoring. All scan results from all tools and all repositories flow into a single DefectDojo instance as the authoritative findings source of truth. Nexus is a caching proxy and audit point, not a security gate — Grype and Trivy provide the actual supply chain vulnerability detection. Kyverno policies must start in Audit mode before Enforce to avoid blocking all workloads.

**Major components:**
1. **Pre-commit framework (L1)** — orchestrates 8 language-specific linters on commit, Gitleaks on push; client-side, bypassable, defense-in-depth only
2. **GitHub Actions 5-job parallel pipeline (L2)** — the actual enforcement layer; SARIF to GitHub Security tab, JSON to DefectDojo; branch protection makes it mandatory
3. **Nexus Repository CE (L3)** — caching proxy for npm/PyPI/Docker/Helm; hosted repo must be ordered before proxy repo (dependency confusion prevention)
4. **DefectDojo (L3)** — unified vulnerability database; all scanner outputs aggregate here; finding lifecycle and SLA tracking
5. **NetworkPolicy + cert-manager + kube-prometheus-stack (L3 hardening)** — namespace isolation, TLS, monitoring for security infrastructure itself
6. **Trivy Operator + Falco + Cosign + Kyverno (L4)** — runtime continuous scanning, anomaly detection, image provenance enforcement

### Critical Pitfalls

All 11 pitfalls are drawn from 15 convergent red-team findings. The top 5 most impactful:

1. **Advisory-only CI gates** — `continue-on-error: true` on scanner steps makes all checks always green. Remove from day one; keep only on upload steps. Validate by deliberately introducing a known vulnerability.
2. **Missing branch protection** — CI gate runs only on PRs; without branch protection, direct pushes to `main` bypass everything. Configure as a hard M2 deliverable, not a follow-up task.
3. **Finding volume overwhelm** — 125-750 findings per repo on first scan. Run `checkov --create-baseline` before enabling CI; configure DefectDojo dedup and auto-close for INFO/LOW; weekly 30-min time-boxed triage cadence.
4. **Silent security tool failures** — stale Trivy DB, failed DefectDojo imports, Nexus disk full are all invisible without monitoring. kube-prometheus-stack in M5 is a hard requirement, not optional.
5. **Plaintext credentials** — DefectDojo API tokens in scripts/workflows; use `${{ secrets.DEFECTDOJO_API_TOKEN }}` in GHA and `${DEFECTDOJO_API_TOKEN}` in scripts; Gitleaks catches these but can be bypassed.

Additional critical pitfalls: unpinned GitHub Actions (SHA-pin from day one, Dependabot for updates), Nexus blob store disk exhaustion (cleanup policies + monitoring), NetworkPolicy silently ignored if CNI does not support it (verify with Calico/Cilium before M5), Kyverno Enforce before Audit (always Audit first), Falco default rules generating 50+ alerts/day (custom rules + exceptions required).

## Implications for Roadmap

Based on research, 7 milestones are the correct structure. The architecture file contains a validated dependency graph. The two delivery tracks (no-infra vs K8s) converge at M4 (DefectDojo).

### Phase 1: Workstation Foundation (M1)
**Rationale:** Zero infrastructure dependencies; delivers immediate value on day one; validates tool installation before CI reuses the same tools; mental model of tool output is required before writing CI workflow
**Delivers:** pre-commit framework with 8 language linters (Tier 1) + Gitleaks (Tier 2); security CLI tool suite installed locally (Trivy, Syft, Grype, Semgrep, Checkov)
**Addresses:** Table-stakes features: pre-commit linting, secrets detection (push-level), on-demand CLI scanning
**Avoids:** Pre-commit-as-enforcement pitfall — frame hooks as defense-in-depth from the start, not enforcement

### Phase 2: CI/CD Security Gate (M2)
**Rationale:** Turns workstation tools into server-side enforcement; still zero infrastructure (GitHub-hosted runners); the most important phase for actual security enforcement
**Delivers:** 5-job parallel GitHub Actions workflow (SAST, IaC, SCA, container, secrets); SARIF upload to GitHub Security tab; JSON artifact retention; branch protection; Dependabot for SHA-pinned actions; Checkov baseline for existing repos
**Addresses:** CI pipeline security enforcement (table stakes); SARIF integration; SHA-pinned actions
**Avoids:** Advisory-only CI gates (remove `continue-on-error` from scanner steps); missing branch protection (hard deliverable); plaintext credentials (secrets scanning must catch them); unpinned GitHub Actions (SHA-pin from day one)
**Research flag:** Standard patterns — GitHub Actions security workflow is well-documented. Checkov baseline workflow is specific to this stack and documented in the reference document.

### Phase 3: Nexus Package Proxy (M3)
**Rationale:** Independent of M1/M2; can run in parallel on the K8s track; proves K8s deployment patterns before deploying the more complex DefectDojo; supplies cached artifact infrastructure that M6 Cosign workflow depends on
**Delivers:** Nexus Repository CE on K8s; npm, PyPI, Docker, Helm proxy repos configured; workstation package managers pointed at Nexus; hosted-before-proxy group ordering (dependency confusion protection)
**Addresses:** Supply chain proxy differentiator feature
**Avoids:** Nexus blob store disk exhaustion (cleanup policies from day one); dependency confusion (group repo ordering); `insecure-registries` technical debt (temporary only, removed in M5)
**Research flag:** Nexus CE Kubernetes deployment has known operational pitfalls (blob store corruption after disk full); standard patterns for Helm deployment but cleanup policy configuration needs explicit attention.

### Phase 4: DefectDojo Unified Dashboard (M4)
**Rationale:** Requires M2 (needs CI producing scan artifacts to import) and M3 (proves K8s deployment works); the aggregation layer that transforms parallel CI scans into a manageable security program
**Delivers:** DefectDojo on K8s; one Product per repo; CI-to-DefectDojo import automation (post-step in GHA workflow); deduplication rules; severity-based auto-close for INFO/LOW; triage workflow SOP (written process); Checkov baseline retroactively for any repos not done in M2
**Addresses:** Finding aggregation (table stakes); finding lifecycle management (differentiator); deduplication
**Avoids:** Finding volume overwhelm (dedup + auto-close + triage SOP must be configured, not deferred); plaintext API token (GitHub Secrets); unpinned Helm chart (`tag="latest"` — pin to specific version from day one)
**Research flag:** DefectDojo import automation requires internal cluster URL (`defectdojo-django.defectdojo.svc.cluster.local`) not external URL — common integration mistake. Needs specific attention during planning.

### Phase 5: Infrastructure Hardening (M5)
**Rationale:** Must harden services that exist (M3+M4) before adding runtime security on top; monitoring is non-negotiable before M6 runtime tools because silent failures are the dominant failure mode
**Delivers:** NetworkPolicy default-deny per security namespace; cert-manager TLS (removes `insecure-registries` and `trusted-host` workarounds); backup automation (pg_dump CronJob for DefectDojo + PVC snapshot for Nexus with tested restore procedure); kube-prometheus-stack (Prometheus + Grafana + Alertmanager); four minimum alert conditions (Nexus disk, DefectDojo import staleness, Trivy DB staleness, pod CrashLoopBackOff); version update maintenance process (Dependabot + pre-commit autoupdate + Helm version tracking)
**Addresses:** NetworkPolicy isolation, TLS, backup automation, monitoring and alerting, dependency update automation (all differentiator features)
**Avoids:** Silent security tool failures (monitoring is the fix); NetworkPolicy silently ignored by CNI (verify CNI supports NetworkPolicy before applying); unmonitored security infrastructure
**Research flag:** CNI verification is a hard prerequisite for NetworkPolicy — must validate Calico or Cilium is present before claiming network isolation. Standard patterns otherwise.

### Phase 6: Runtime Security (M6)
**Rationale:** Requires hardened cluster (M5) as foundation; Falco and Kyverno must deploy into isolated, monitored infrastructure; Cosign signing must be working before Kyverno switches to Enforce
**Delivers:** Trivy Operator (continuous workload scanning, VulnerabilityReports as K8s CRDs); Falco CE + FalcoSidekick (custom rules tuned to this stack, start at DEBUG priority, add exceptions for known-good processes); Cosign keyless signing in CI (GitHub OIDC, no key material); Kyverno admission control (Audit mode first, Enforce after all images are signed and policyreport is clean)
**Addresses:** Runtime workload scanning, kernel-level anomaly detection, keyless image signing + admission control (all differentiator/P3 features)
**Avoids:** Kyverno Enforce before Audit (sequential deployment is mandatory); Falco alert noise (custom rules + exceptions + start at DEBUG); Falco rules triggered by security tool pods (add exceptions for DefectDojo, Nexus, cert-manager operations)
**Research flag:** This phase has the highest operational complexity and the most pitfalls. Needs careful phase planning. Falco rule tuning in particular is poorly documented for this specific stack configuration.

### Phase 7: Optional Enhancements (M7)
**Rationale:** Independent of each other after M5/M6; only deploy when a specific need arises
**Delivers:** SonarQube (code quality metrics only, not security-critical), Harbor (tag retention + replication if Nexus Docker proxy is insufficient), commit signing (when contributing to shared repos or compliance requires it)
**Addresses:** Optional features that are anti-features in the core stack context
**Avoids:** Scope creep into features that add operational burden without proportional value for a single-developer practice

### Phase Ordering Rationale

- **M1 before M2:** Tool familiarity from local installation informs CI workflow construction; workstation is the only dependency-free starting point
- **M3 parallel with M1+M2:** Only requires K8s cluster; builds confidence in cluster deployment before tackling DefectDojo
- **M4 after both M2 and M3:** Needs scan artifacts from CI to import (M2) and a validated K8s deployment (M3); DefectDojo without import automation delivers no value
- **M5 after M3+M4:** Cannot harden services that do not exist; monitoring must precede runtime security tools
- **M6 after M5:** Runtime security tools (Falco DaemonSet, Kyverno admission webhook) must deploy into a monitored, isolated cluster; Kyverno Enforce mode requires all images signed which requires CI signing pipeline

### Research Flags

Phases needing deeper research during planning:
- **Phase 4 (DefectDojo):** CI-to-DefectDojo import automation has a specific internal cluster URL requirement and API token handling that needs explicit implementation planning
- **Phase 6 (Runtime):** Falco rule tuning for this specific stack is not well-documented; custom rules for security-stack namespaces will need to be written; Kyverno CEL-based `ValidatingPolicy` is new in 1.17 and patterns are still emerging

Phases with standard patterns (skip research-phase):
- **Phase 1 (Workstation):** All tool installation patterns are documented; pre-commit hook configuration is well-established
- **Phase 2 (CI/CD):** GitHub Actions security workflow patterns are extensively documented; branch protection configuration is straightforward
- **Phase 3 (Nexus):** Helm deployment is standard; main risk is operational (cleanup policies, disk sizing), not architectural
- **Phase 5 (Hardening):** cert-manager, NetworkPolicy, kube-prometheus-stack are all CNCF-standard with extensive documentation

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All 18 tools verified at current versions from official release channels; two critical version warnings identified (Grype DB v5 EOL, Trivy security incident) |
| Features | HIGH | Feature classification validated against DevSecOps industry sources and the project's 7 existing milestone plans; anti-features explicitly researched |
| Architecture | HIGH | Derived from the project's own 2,300-line reference document, 14 ADRs, and three-agent red-team analysis; dependency graph is fully validated |
| Pitfalls | HIGH | Primary source is 15 convergent red-team findings from three independent agents; supplemented by community sources for operational issues |

**Overall confidence:** HIGH

### Gaps to Address

- **Falco custom rule library for this specific stack:** The reference document includes example rules but no community has validated rules tailored to DefectDojo/Nexus/cert-manager behavior in the same cluster. Rule tuning in M6 will require empirical iteration.
- **Grype DB v5 EOL impact assessment:** Any existing installation with Grype < 0.88.0 has already stopped receiving vulnerability updates as of 2026-03-06. Implementation checklist must include explicit version check before beginning M1.
- **Kyverno CEL-based ValidatingPolicy patterns:** The CEL policy API was promoted to v1 in Kyverno 1.17 but community adoption examples are sparse; implementation may need to use YAML-based ClusterPolicy initially with planned migration.
- **Nexus CE component limit monitoring:** The 40K component / 100K daily request limits are sufficient for single-dev but need a Prometheus alert threshold defined before M5 completes.

## Sources

### Primary (HIGH confidence)

- `docs/development-security-stack-option-1.md` — 2,300-line primary reference document (all architecture, tool configurations, implementation phases)
- `docs/adr/ADR-001..014.md` — 14 Architectural Decision Records (enforcement, security, operational decisions)
- `docs/milestone-plan/README.md` and `milestone-1..7-*.md` — 7 milestone plans with dependency graph
- `red-team/00-consolidated-findings.md` — 15 convergent findings from three-agent red-team analysis
- `docs/ARCHITECTURE_AND_DESIGN.md` — design constraints and red-team response
- [Trivy GitHub Releases](https://github.com/aquasecurity/trivy/releases) — v0.69.3 confirmed, security incident
- [Semgrep PyPI](https://pypi.org/project/semgrep/) — v1.155.0 confirmed
- [Grype DB Schema EOL Announcement](https://anchorecommunity.discourse.group/t/grype-db-schema-v5-will-be-eol-on-march-6-2026/591) — v5 EOL 2026-03-06
- [Kyverno 1.17 Release Blog](https://kyverno.io/blog/2026/02/02/announcing-kyverno-release-1.17/) — CEL v1, ClusterPolicy deprecated
- [Falco GitHub Releases](https://github.com/falcosecurity/falco/releases) — v0.43.0, modern eBPF required
- [Cosign GitHub Releases](https://github.com/sigstore/cosign/releases) — v3.0.5 confirmed
- [kube-prometheus-stack ArtifactHub](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) — v82.10.3 confirmed
- [Falco 0.41.1 false positives](https://github.com/falcosecurity/falco/issues/3610) — official issue tracker
- [DefectDojo Kubernetes README](https://github.com/DefectDojo/django-DefectDojo/blob/master/readme-docs/KUBERNETES.md) — official deployment guide

### Secondary (MEDIUM confidence)

- [DevSecOps in 2025: Principles, Technologies & Best Practices](https://www.oligo.security/academy/devsecops-in-2025-principles-technologies-best-practices) — feature prioritization context
- [DevSecOps Trends 2026 — Practical DevSecOps](https://www.practical-devsecops.com/devsecops-trends-2026/) — industry direction
- [Day 2 Falco Container Security - Tuning the Rules](https://www.sysdig.com/blog/day-2-falco-container-security-tuning-the-rules) — Falco rule tuning approach
- [Adventures with Nexus in Kubernetes](https://itnext.io/adventures-with-nexus-in-kubernetes-database-corruption-and-storage-management-c5c5118b5e86) — Nexus disk exhaustion and blob store corruption
- [Blob store in permanent Failed state](https://community.sonatype.com/t/blob-store-in-permanent-failed-state-after-running-out-of-disk-space/6882) — Nexus operational failure mode
- [Why Pre-Commit Hooks Fail at Stopping Secrets](https://xygeni.io/blog/why-pre-commit-hooks-fail-at-stopping-secrets/) — pre-commit bypass pitfall
- [Five DevSecOps Anti-Patterns to Avoid](https://www.opcito.com/blogs/five-devsecops-anti-patterns-to-avoid) — operational anti-patterns

---
*Research completed: 2026-03-15*
*Ready for roadmap: yes*
