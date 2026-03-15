# Feature Research

**Domain:** Developer Security Toolchain (zero-cost, self-hosted, single-developer)
**Researched:** 2026-03-15
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features that any credible developer security program must have. Missing these means the stack is incomplete and provides false confidence.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Pre-commit linting (language-specific) | Immediate feedback on syntax, style, and formatting errors. Developers expect fast local validation before code leaves the workstation. Industry standard since 2018+. | LOW | 8 linters for the language coverage needed (ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint, tf fmt/validate, npm audit). Use `pre-commit` framework for orchestration. |
| Secrets detection (pre-push + CI) | Credentials in version history are the single highest-risk class of findings. Every security maturity framework lists this as baseline. Gitleaks is the community standard for git-aware secrets scanning. | LOW | Two enforcement points: pre-push hook (fast inner loop) and CI full-history scan (compensating control for `--no-verify` bypass). |
| Static Application Security Testing (SAST) in CI | Pattern-based code analysis for injection, hardcoded credentials, unsafe deserialization, etc. Part of every DevSecOps pipeline guide published 2020-2026. Required by SOC 2, ISO 27001, and similar frameworks. | MEDIUM | Semgrep CE is the clear choice for zero-cost. Runs in CI (not pre-commit) because full-repo SAST on every commit creates friction without proportional value. |
| Infrastructure-as-Code (IaC) scanning in CI | Terraform/CloudFormation/K8s misconfiguration is how cloud breaches happen. IaC scanning catches public S3 buckets, overly permissive IAM, missing encryption. Table stakes for any AWS practice. | MEDIUM | Checkov is the standard (Apache 2.0, no account required). Requires baseline workflow for existing repos to avoid alert fatigue from pre-existing findings. |
| Software Composition Analysis (SCA) | 70-90% of modern applications are open-source dependencies. Known CVEs in dependencies are the lowest-hanging attack vector. SCA is the most basic supply chain control. | MEDIUM | Syft (SBOM generation) + Grype (vulnerability matching) as a pair. Separate from npm audit, which is a lightweight first-pass only. |
| Container image scanning | Container images ship OS-level and application-level vulnerabilities. Scanning before deployment is baseline for any containerized practice. | MEDIUM | Trivy covers this plus IaC plus secrets in one tool. Runs in CI on every PR. |
| CI pipeline security enforcement | Scans that do not block deployment are advisory, not enforcement. Branch protection + required status checks is the mechanism that makes scanning matter. | LOW | GitHub branch protection with 5 required checks. Without this, the entire scanning pipeline is decoration. |
| Scan result aggregation and deduplication | Multiple scanners produce overlapping findings. Without aggregation, same CVE appears 2-3 times across tools. Without dedup, finding volume makes triage impossible. | HIGH | DefectDojo is the only credible zero-cost option for multi-scanner aggregation. 200+ parser support. Essential for making the stack sustainable. |
| SBOM generation | SBOMs are increasingly required by regulation (EO 14028, EU Cyber Resilience Act). Even without regulatory pressure, knowing what is in your software is foundational to supply chain security. | LOW | Syft generates CycloneDX and SPDX formats. Run in CI alongside SCA. |
| Automated CI scan pipeline | Manual scanning does not scale even for a single developer with 6+ repos. Automation is the only way to guarantee every PR gets scanned. | MEDIUM | GitHub Actions with 5 parallel scan jobs. SHA-pinned actions to prevent supply chain attacks on the CI pipeline itself. |
| SARIF integration with code review | Findings must appear where developers work -- in the PR, not in a separate dashboard. GitHub Security tab via SARIF upload puts findings in the review flow. | LOW | Free with GitHub public repos. SARIF upload is a standard GitHub Actions pattern. |

### Differentiators (Competitive Advantage)

Features that elevate this stack from "basic scanning" to "security program." Not expected in every DevSecOps guide, but high-value for a solo practitioner managing real infrastructure.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Supply chain proxy (Nexus) | Cache all upstream packages locally. Protects against dependency confusion attacks (group repo ordering), upstream outages, and provides an audit point for everything installed. Most single-developer setups skip this entirely. | HIGH | Nexus Repository CE on K8s. Requires proxy setup for npm, PyPI, Docker, Helm. High value but high initial effort. |
| Finding lifecycle management | Open -> Under Review -> Mitigated -> Closed workflow with SLA tracking. Transforms a "dashboard" into a "security program." Most solo developers never get past "scan and ignore." | MEDIUM | DefectDojo provides this out of the box. The differentiator is actually configuring and using it -- written triage SOP, weekly 30-min cadence, severity-based auto-close. |
| Runtime workload scanning (Trivy Operator) | Continuous scanning of running K8s workloads catches drift between what was scanned in CI and what is actually deployed. Most DevSecOps stacks stop at CI. | MEDIUM | Trivy Operator as K8s custom resources (VulnerabilityReports, ConfigAuditReports). Catches images that were never scanned in CI or have developed new CVEs since deployment. |
| Kernel-level runtime anomaly detection (Falco) | Detects post-exploitation behavior that static scanning cannot: shell spawning in containers, privilege escalation, unexpected outbound connections, kubectl exec into security namespaces. This is "defense in depth" that most solo developers never implement. | HIGH | Falco CE with eBPF driver + FalcoSidekick for alert routing. Requires custom rules targeting this specific stack. K8s audit log plugin needed for kubectl exec detection. |
| Keyless image signing + admission control | Cosign keyless signing (no private keys to manage) + Kyverno admission policy rejecting unsigned images. Proves cryptographic provenance of every deployed container. Beyond what most teams implement, let alone solo developers. | HIGH | Cosign via GitHub OIDC + Kyverno ClusterPolicy. Initial deployment in Audit mode, then Enforce. This is SLSA Level 2+ territory. |
| Checkov baseline for existing repos | Suppresses pre-existing IaC findings so CI only flags new issues per PR. Without this, initial Checkov runs on established repos generate hundreds of findings that bury real issues in noise. | LOW | `checkov --create-baseline` per repo. Critical for adoption -- without it, developers disable the scanner rather than triage hundreds of inherited findings. |
| Network isolation for security services | NetworkPolicy default-deny per security namespace. Prevents a compromised application workload from reaching DefectDojo, Nexus, or other security infrastructure. | MEDIUM | Requires CNI plugin that supports NetworkPolicy (Calico, Cilium). Most self-hosted K8s stacks skip namespace isolation entirely. |
| TLS for all internal service communication | Removes the `insecure-registries` and `trusted-host` workarounds. All service-to-service traffic encrypted. Proper cert-manager deployment. | MEDIUM | cert-manager + Ingress TLS termination. Eliminates the "temporary" insecure configuration that becomes permanent in most setups. |
| Automated backup for stateful services | CronJob pg_dump for DefectDojo PostgreSQL, PVC snapshots for Nexus. Without this, a single disk failure loses all finding history and cached packages. | MEDIUM | Most self-hosted K8s deployments skip backups entirely until they lose data. Documented restore procedure is the real deliverable. |
| Monitoring and alerting for security services | Prometheus + Grafana + Alertmanager detecting silent failures: stale Trivy DB, failed DefectDojo imports, Nexus disk full, CrashLoopBackOff in security namespaces. | HIGH | kube-prometheus-stack Helm chart. Without this, security tools can silently stop working and create a false sense of coverage. |
| SHA-pinned CI actions + Dependabot updates | Pin GitHub Actions to SHA digests instead of mutable version tags. Prevents supply chain attacks on the CI pipeline itself. Dependabot automates update PRs. | LOW | High security value for very low effort. Most developers use `@v3` tags which can be silently mutated. |
| Dependency update automation | Dependabot/Renovate for automated dependency update PRs + pre-commit autoupdate + Helm chart version tracking. Sustainable maintenance without manual checking. | LOW | Monthly cadence. The documented process (maintenance checklist) is more valuable than any individual tool update. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem valuable but create more problems than they solve in this context.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| SAST/IaC scanning in pre-commit hooks | "Catch everything earlier" | Semgrep and Checkov do full-repo analysis on every invocation. Adds seconds-to-minutes per commit. On feature branches, code is intentionally incomplete -- false positives train developers to ignore the tool or use `--no-verify`. The PR gate is the correct enforcement point. | Run SAST/IaC in CI only. Keep pre-commit to fast linters + secrets detection. |
| DAST (Dynamic Application Security Testing) | "Test the running application" | Requires a running, accessible application instance. Generates high false-positive rates. Needs significant configuration per endpoint. Inappropriate for an infrastructure-focused practice that is not deploying web applications. | If needed later, OWASP ZAP as a one-off rather than automated pipeline step. Out of scope for this stack. |
| SonarQube as a core component | "Code quality metrics" | Heavy resource footprint (2 Gi RAM, dedicated PostgreSQL). Community Build is single-branch only (no PR decoration). Semgrep CE + DefectDojo already cover SAST. Adds operational burden without proportional security value. | Keep as M7 optional. Only deploy if code quality metrics (complexity, duplication, coverage) are specifically needed. |
| Harbor as a core component | "Purpose-built container registry" | Nexus already handles Docker proxy/cache. Harbor adds scan-on-push (Trivy already does this in CI), tag retention, and robot accounts. Significant resource overhead for features that are mostly redundant with existing tooling. | Keep as M7 optional. Only deploy if tag retention policies or replication to multiple registries is needed. |
| Multi-developer RBAC / team access controls | "Prepare for team growth" | Single-developer practice. Adding RBAC, SSO, team permissions adds configuration complexity for zero current users. Premature optimization for a scaling event that may never happen. | Defer entirely. Add RBAC when a second developer actually joins. |
| Paid/SaaS security tools | "Better coverage with Snyk/Veracode/etc." | Violates the zero-cost constraint. Creates vendor dependency. For a single-developer practice, the open-source stack provides equivalent coverage. The gap is in inter-file dataflow analysis (Semgrep CE is intra-file only), which is a real but narrow limitation. | Accept the intra-file SAST limitation. Semgrep CE community rules cover the vast majority of practical vulnerabilities. |
| "Scan everything everywhere" approach | "Maximum coverage" | Running all scanners at all stages (pre-commit, CI, runtime) creates massive alert volume. Per OWASP 2025 data, 70%+ of alerts in mature pipelines are false/irrelevant. Each additional scan point multiplies noise without proportional signal. | Tiered approach: fast linting at commit, secrets at push, full scanning at PR, runtime scanning in K8s. Each tier has a specific purpose. |
| Real-time alerting on every finding | "Immediate response" | A single developer cannot respond to every finding in real time. Creates notification fatigue that trains the developer to ignore alerts. Findings accumulate faster than one person can triage. | Weekly 30-min triage cadence. Batch Critical/High findings. Auto-suppress Info/Low. Only alert on infrastructure failures (pod crashes, DB staleness), not individual findings. |
| Commit signing as a core requirement | "Cryptographic commit integrity" | Adds signing ceremony to every commit. For a single-developer practice, you are the only committer -- commit signing proves nothing about trust that SSH authentication does not already prove. Value is for multi-contributor repos. | Keep as M7 optional. Adopt when contributing to shared repos or when compliance requires it. |
| Custom Semgrep rule library | "Tailored security rules" | Writing and maintaining custom SAST rules requires deep security expertise and ongoing tuning. For a single developer, the community rule registry (thousands of rules) is sufficient. Custom rules are a maintenance burden. | Use `--config auto` (community rules). Add 1-2 custom rules only for patterns specific to your codebase (e.g., hardcoded AWS regions). Do not build a rule library. |

## Feature Dependencies

```
[Pre-commit framework (M1-F1)]
    |-- requires --> [nothing - starting point]
    |
    +-- enables --> [Secrets gate (M1-F2)]
    +-- enables --> [CI workflow (M2-F1)]

[Security CLI tools (M1-F3)]
    |-- requires --> [nothing - parallel with M1-F1]
    |
    +-- enables --> [CI workflow (M2-F1)] (familiarity with tool output)

[CI security workflow (M2-F1)]
    |-- requires --> [M1-F1, M1-F3]
    |
    +-- enables --> [SARIF upload (M2-F2)]
    +-- enables --> [JSON artifacts (M2-F3)]
    +-- enables --> [Branch protection (M2-F4)]
    +-- enables --> [Dependabot (M2-F5)]
    +-- enables --> [CI-to-DefectDojo import (M4-F3)]
    +-- enables --> [Cosign signing (M6-F3)]

[Nexus deployment (M3-F1)]
    |-- requires --> [K8s cluster only - parallel with M1/M2]
    |
    +-- enables --> [Proxy repos (M3-F2)]
    +-- enables --> [DefectDojo deployment (M4-F1)] (proves cluster works)

[DefectDojo deployment (M4-F1)]
    |-- requires --> [K8s cluster, M3 complete]
    |
    +-- enables --> [Product config (M4-F2)]
    +-- enables --> [Import automation (M4-F3)]
    +-- enables --> [Dedup/triage (M4-F4)]

[NetworkPolicy (M5-F1)] -- requires --> [M3-F1, M4-F1]
[TLS (M5-F2)] -- requires --> [M3-F3, M4-F1]
[Backups (M5-F3)] -- requires --> [M3-F1, M4-F1]
[Monitoring (M5-F4)] -- requires --> [M3-F1, M4-F1]

[Trivy Operator (M6-F1)] -- requires --> [K8s, M5-F4 for staleness detection]
[Falco (M6-F2)] -- requires --> [K8s, M5-F1 for namespace policy]
[Cosign signing (M6-F3)] -- requires --> [M2-F1]
[Kyverno (M6-F4)] -- requires --> [M6-F3, M5-F1]
```

### Dependency Notes

- **M1 (Workstation) has no dependencies:** This is the correct starting point. Zero infrastructure required.
- **M2 (CI/CD) requires M1:** Familiarity with tool output from local testing informs CI workflow construction.
- **M3 (Nexus) is parallel with M1/M2:** Only needs a running K8s cluster. Can begin as soon as cluster is available.
- **M4 (DefectDojo) requires M2 and M3:** Needs CI producing artifacts to import, and proves K8s is working via Nexus.
- **M5 (Hardening) requires M3 and M4:** Must have services running to harden them.
- **M6 (Runtime) requires M5:** Runtime security tools should deploy into a hardened environment.
- **M7 (Optional) is independently deployable:** Any feature can be added if needed.
- **Checkov baseline (M4-F5) has a soft dependency on M2-F1 and M4-F3:** Baseline is most effective when CI is running and DefectDojo shows the volume reduction.

## MVP Definition

### Launch With (v1 -- Milestones 1-2)

Minimum viable security program. Provides local quality gates and CI enforcement with zero infrastructure.

- [x] Pre-commit Tier 1 linting (8 language-specific linters) -- immediate developer feedback
- [x] Pre-commit Tier 2 secrets detection (Gitleaks) -- prevents credential exposure
- [x] Security CLI tool suite installed locally -- on-demand scanning capability
- [x] GitHub Actions 5-job security workflow -- automated scanning on every PR
- [x] SARIF upload to GitHub Security tab -- findings visible in code review
- [x] JSON artifact retention -- foundation for later DefectDojo import
- [x] Branch protection enforcement -- makes CI gate mandatory, not advisory
- [x] Dependabot for Actions SHA updates -- keeps CI supply chain current

**Why this is MVP:** A developer with M1+M2 has secrets detection on every push, linting on every commit, 5 parallel security scans on every PR, and branch protection preventing bypass. This covers SAST, IaC, SCA, container scanning, and secrets detection. No infrastructure required beyond GitHub.

### Add After Validation (v1.x -- Milestones 3-5)

Features to add once M1+M2 are working across all repos.

- [ ] Nexus package proxy -- add when upstream outages or dependency confusion are concerns
- [ ] DefectDojo unified dashboard -- add when finding volume across 6+ repos exceeds manual tracking
- [ ] CI-to-DefectDojo import automation -- add with DefectDojo
- [ ] Deduplication and triage workflow -- add with DefectDojo; this is what makes scanning sustainable
- [ ] Checkov baseline -- add when existing-repo IaC findings drown out new findings
- [ ] NetworkPolicy, TLS, backups, monitoring -- add when security services are running on K8s
- [ ] Version update process -- add when tool maintenance becomes a recurring concern

### Future Consideration (v2+ -- Milestones 6-7)

Features to defer until the core pipeline is battle-tested.

- [ ] Trivy Operator runtime scanning -- defer until K8s hardening (M5) is complete
- [ ] Falco runtime anomaly detection -- defer; highest complexity, requires eBPF support and custom rules
- [ ] Cosign keyless signing + Kyverno admission -- defer; requires container registry workflow to be established
- [ ] SonarQube -- defer; optional code quality metrics, not security-critical
- [ ] Harbor -- defer; optional if Nexus Docker proxy is sufficient
- [ ] Commit signing -- defer; minimal value for single-developer practice

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Pre-commit linting (Tier 1) | HIGH | LOW | P1 |
| Secrets detection (Gitleaks) | HIGH | LOW | P1 |
| CI security workflow (5 jobs) | HIGH | MEDIUM | P1 |
| SARIF upload | MEDIUM | LOW | P1 |
| Branch protection | HIGH | LOW | P1 |
| Security CLI tools | MEDIUM | LOW | P1 |
| JSON artifact retention | MEDIUM | LOW | P1 |
| SHA-pinned actions + Dependabot | MEDIUM | LOW | P1 |
| DefectDojo deployment | HIGH | HIGH | P2 |
| CI-to-DefectDojo import | HIGH | MEDIUM | P2 |
| Dedup + triage workflow | HIGH | MEDIUM | P2 |
| Checkov baseline | HIGH | LOW | P2 |
| Nexus package proxy | MEDIUM | HIGH | P2 |
| NetworkPolicy isolation | MEDIUM | MEDIUM | P2 |
| TLS (cert-manager) | MEDIUM | MEDIUM | P2 |
| Backup automation | MEDIUM | MEDIUM | P2 |
| Monitoring + alerting | HIGH | HIGH | P2 |
| Version update process | MEDIUM | LOW | P2 |
| Trivy Operator (runtime) | MEDIUM | MEDIUM | P3 |
| Falco (runtime anomaly) | MEDIUM | HIGH | P3 |
| Cosign + Kyverno (signing) | LOW | HIGH | P3 |
| SonarQube [optional] | LOW | HIGH | P3 |
| Harbor [optional] | LOW | HIGH | P3 |
| Commit signing [optional] | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for launch -- M1+M2 features. Provides usable security scanning with zero infrastructure.
- P2: Should have, add after M1+M2 validated -- M3+M4+M5 features. Transforms scanning into a security program.
- P3: Nice to have, future consideration -- M6+M7 features. Defense-in-depth and optional enhancements.

## Competitor Feature Analysis

| Feature | GitHub Advanced Security (paid) | Snyk (paid) | GitLab Ultimate (paid) | This Stack (zero-cost) |
|---------|-------------------------------|-------------|----------------------|----------------------|
| SAST | CodeQL (inter-file dataflow) | Snyk Code (AI-powered) | Built-in SAST | Semgrep CE (intra-file, pattern-based) |
| SCA | Dependabot alerts | Snyk Open Source | Built-in SCA | Syft + Grype |
| Secrets detection | Secret scanning | Snyk secrets | Built-in secrets | Gitleaks |
| IaC scanning | Not built-in | Snyk IaC | Built-in IaC | Checkov |
| Container scanning | Not built-in | Snyk Container | Built-in container | Trivy |
| SBOM generation | Dependency graph | Snyk SBOM | CycloneDX export | Syft |
| Finding aggregation | Security tab only | Snyk dashboard | GitLab dashboard | DefectDojo (200+ parsers) |
| Runtime scanning | Not included | Snyk Runtime | Not included | Trivy Operator + Falco |
| Image signing | Not included | Not included | Not included | Cosign keyless + Kyverno |
| Supply chain proxy | Not included | Not included | Not included | Nexus Repository CE |
| Cost | $49/user/month | $25+/user/month | $99/user/month | $0 |
| Account required | Yes (GitHub) | Yes (Snyk) | Yes (GitLab) | No external accounts |

**Key gap vs. paid tools:** Inter-file dataflow SAST analysis. CodeQL and Snyk Code can trace tainted data across function and file boundaries. Semgrep CE is limited to intra-file analysis. This is a real but narrow limitation -- the vast majority of SAST findings come from single-file pattern matching.

**Key advantage vs. paid tools:** Supply chain proxy (Nexus), runtime anomaly detection (Falco), and image signing (Cosign + Kyverno) are features that most paid tools do not include. DefectDojo's 200+ parser support aggregates across more scanner types than any single-vendor dashboard.

## Sources

- Project reference document: `docs/development-security-stack-option-1.md` (primary source for tool coverage and architecture)
- Milestone plans: `docs/milestone-plan/milestone-1-workstation.md` through `milestone-7-optional.md`
- [DevSecOps in 2025: Principles, Technologies & Best Practices](https://www.oligo.security/academy/devsecops-in-2025-principles-technologies-best-practices)
- [DevSecOps Trends 2026 -- Practical DevSecOps](https://www.practical-devsecops.com/devsecops-trends-2026/)
- [Top 13 Open-Source DevSecOps Tools for 2025](https://www.upwind.io/glossary/13-best-devsecops-tools-2025s-best-open-source-options-sorted-by-use-case)
- [The Ultimate Guide to DevSecOps Tools in 2026 -- DefectDojo](https://defectdojo.com/blog/the-ultimate-guide-to-devsecops-tools-in-2026-from-chaos-to-orchestration)
- [2025 Minimum Elements for SBOM -- CISA](https://www.cisa.gov/resources-tools/resources/2025-minimum-elements-software-bill-materials-sbom)
- [Five DevSecOps Anti-Patterns to Avoid](https://www.opcito.com/blogs/five-devsecops-anti-patterns-to-avoid)
- [Why Application Security Tools Fail -- GitHub Resources](https://resources.github.com/application-security-tools-devsecops-fixes-security-debt/)

---
*Feature research for: Developer Security Toolchain (zero-cost, self-hosted, single-developer)*
*Researched: 2026-03-15*
