# Red Team Report — Agent 3: The Architect
**Perspective:** Security architecture, design flaws, and defense-in-depth analysis

---

## Executive Summary

This security stack represents a thoughtful, cost-conscious approach to securing a single-developer AWS cloud practice. The tool selection is sound, and the phased implementation is pragmatic. However, the architecture contains several structural weaknesses that undermine its defense-in-depth claims. The most critical are: an entirely advisory enforcement model (nothing actually prevents vulnerable code from deploying), complete absence of DAST and runtime application protection, a trust model that collapses at the developer workstation, and self-hosted security infrastructure that lacks its own security hardening. This report identifies 28 specific findings across six analysis domains.

---

## 1. Defense-in-Depth Analysis

### 1.1 The Layers Are Not Independent

The document presents four layers: Developer Workstation, CI/CD Gate, Self-Hosted K8s Infrastructure, and Runtime. A true defense-in-depth architecture requires that each layer independently catches threats that slip through previous layers, using distinct detection methods.

In practice, the layers in this stack are not independent:

- **Workstation and CI/CD use the same tool (Gitleaks)** for secrets detection. If Gitleaks has a false negative for a particular secret pattern, it will miss it in both layers. The CI/CD layer runs Gitleaks with `--log-opts="--all"` (full history), which is additive, but the detection engine and rule set are identical. This is not defense-in-depth; it is the same defense applied twice.

- **Trivy appears in three layers** (CLI on workstation, CI/CD container scan, Trivy Operator in runtime). Again, the vulnerability database and detection logic are the same. A false negative in Trivy's vulnerability database propagates through all three layers. Genuine depth would require a second container scanner with an independent vulnerability database (e.g., Clair, or Grype applied to container images in CI — which the workflow does not do).

- **The K8s infrastructure layer (Nexus + DefectDojo) provides zero detection capability.** Nexus is explicitly described as not performing vulnerability scanning (Section 6: "What Nexus does NOT do: Vulnerability scanning"). DefectDojo is a dashboard that aggregates findings — it does not discover new ones. This layer is purely operational infrastructure, not a security detection layer.

**Finding 1:** The architecture has three detection layers (workstation, CI/CD, runtime), not four. The K8s infrastructure layer is a data aggregation and supply chain caching layer, not a security detection layer. The architecture diagram overstates the depth.

**Finding 2:** Two of the three actual detection layers share the same tool instances (Gitleaks, Trivy), meaning correlated false negatives propagate across layers. True depth requires diverse detection engines.

### 1.2 Vulnerability Classes That Pass Through ALL Layers Undetected

The following vulnerability classes have zero coverage across all four layers:

| Vulnerability Class | Workstation | CI/CD | K8s Infra | Runtime | Net Coverage |
|---|---|---|---|---|---|
| **Business logic flaws** | None | None | None | None | **ZERO** |
| **Authentication/authorization bypass** | None | None | None | None | **ZERO** |
| **SSRF, CSRF** | None | Semgrep (partial, pattern-only) | None | None | **Minimal** |
| **Insecure deserialization** | None | Semgrep (partial) | None | None | **Minimal** |
| **Runtime injection (SQLi, XSS, command injection)** | None | Semgrep (pattern-only, no dataflow in CE) | None | None | **Weak** |
| **API security (broken access control, mass assignment)** | None | None | None | None | **ZERO** |
| **Race conditions / TOCTOU** | None | None | None | None | **ZERO** |
| **Cryptographic misuse (weak ciphers, bad key management)** | None | Semgrep (partial) | None | None | **Minimal** |
| **Memory safety (if using native extensions)** | None | None | None | None | **ZERO** |
| **Denial of service (ReDoS, algorithmic complexity)** | None | Semgrep (limited) | None | None | **Minimal** |

**Finding 3:** The stack has strong coverage for known CVEs in dependencies (SCA) and infrastructure misconfigurations (IaC scanning), but near-zero coverage for application-level vulnerabilities that require dataflow analysis, dynamic testing, or semantic understanding of business logic.

**Finding 4:** Semgrep CE is described as "intra-file only" (Section 1: "no cross-file/inter-file dataflow analysis"). This means any vulnerability that spans multiple files — which includes most real-world injection vulnerabilities where user input flows through controllers, services, and data access layers — will not be detected. The document acknowledges this limitation but does not compensate for it with any other tool.

### 1.3 The Container Scanning Gap in PR Workflows

The GitHub Actions workflow (lines 1079-1095) only runs the Trivy container scan on `push` events, not on `pull_request` events:

```yaml
container:
  name: Container — Trivy
  runs-on: ubuntu-latest
  if: github.event_name == 'push'
```

**Finding 5:** Container image vulnerabilities are not scanned during the PR review process — only after code has already been merged to main. This means the PR reviewer never sees container vulnerability findings before approving a merge. The primary enforcement gate (the PR) is blind to container issues.

**Recommendation:** Run `docker build` and Trivy scan on PR events as well. If build time is a concern, cache the build layers. The current design means container vulnerabilities are discovered post-merge, which defeats the purpose of a PR gate.

---

## 2. The "Shift-Left" Tradeoff

### 2.1 The Risk Window Is Wider Than Acknowledged

The document argues that SAST and IaC scanning belong at the PR gate, not pre-commit, because "developers working in development or feature branches are expected to push code that is not yet hardened" (Section: Shift-Left Linting Layer). This reasoning is valid for developer friction, but the document does not quantify or acknowledge the resulting risk window.

**The risk window:** From the moment a developer writes vulnerable code to the moment a PR is opened, reviewed, and the security workflow completes, there is zero SAST or IaC coverage. In a single-developer practice, this could be hours, days, or weeks — the developer may push to a feature branch for days before opening a PR.

**Why this matters beyond the PR:**

- **Feature branches exist on the remote.** Code pushed to GitHub feature branches is accessible to anyone with repository read access. If the repository is not private, vulnerable code is publicly visible before any security scan runs.
- **Branch protection is described as optional.** The document states: "(Optional) Branch protection rule configured to require the workflow to pass before merge" (Phase 2 deliverables, line 1351). If branch protection is not configured, the entire CI/CD security gate is advisory — a developer can merge without waiting for scans.

**Finding 6:** The document treats branch protection as optional rather than mandatory. Without branch protection requiring the security workflow to pass, the CI/CD gate provides zero enforcement. The entire security architecture degrades to "advisory" mode. Branch protection should be listed as a required deliverable in Phase 2, not optional.

### 2.2 Direct Pushes to Main

The workflow triggers on `push: branches: [main]` as a "safety net for non-PR merges" (line 1013). But this safety net has a critical property: it runs AFTER the code is already on main.

**Finding 7:** Direct pushes to main bypass the PR gate entirely. The push-triggered workflow runs post-facto — the vulnerable code is already in the protected branch. Combined with the lack of mandatory branch protection, a single `git push origin main` bypasses every security scan in the architecture. The document should explicitly require branch protection rules that (a) block direct pushes to main, and (b) require the security workflow to pass before merge.

### 2.3 `continue-on-error: true` Undermines the Gate

Every scanner job in the GitHub Actions workflow uses `continue-on-error: true`:

```yaml
- run: semgrep scan --config auto --json --output semgrep-results.json .
  continue-on-error: true
```

**Finding 8:** With `continue-on-error: true`, the security workflow always reports as "passed" regardless of how many critical vulnerabilities are found. Even with branch protection enabled, the workflow will never block a merge. The scanning is purely informational. To function as a gate, at least the critical-severity findings should cause a non-zero exit code that is not suppressed. Consider a tiered approach: `continue-on-error: true` for informational scans but a separate mandatory job that fails on critical/high findings using `--fail-on` flags (e.g., `grype dir:. --fail-on high`).

---

## 3. Tool Overlap and Gaps

### 3.1 Genuine Redundancy (Valuable)

| Domain | Tool A | Tool B | Value of Overlap |
|---|---|---|---|
| IaC scanning | Checkov (graph-based, 1000+ policies) | Trivy config (absorbed tfsec rules) | **High value.** Different rule sets and analysis approaches. Checkov does cross-resource graph analysis; Trivy applies tfsec pattern rules. Complementary. |
| SCA / Dependencies | Grype (Anchore vuln DB) | Trivy fs (Aqua vuln DB) | **Moderate value.** Different vulnerability databases. However, both draw heavily from the NVD and GitHub Advisory Database, so overlap is significant. The marginal detection gain is real but small. |
| Secrets | Gitleaks (pre-commit) | Gitleaks (CI/CD full history) | **Low diversity value.** Same engine, same rules. Value is in scope expansion (staged files vs. full history), not in diverse detection. |

### 3.2 Missing Coverage Categories

| Category | Status | Impact |
|---|---|---|
| **DAST (Dynamic Application Security Testing)** | Completely absent | No testing of running applications for injection, authentication bypass, or API vulnerabilities. OWASP ZAP or Nuclei would fill this gap at zero cost. |
| **Fuzzing** | Completely absent | No coverage for input validation, crash-inducing inputs, or edge cases in parsers. |
| **API security testing** | Completely absent | No OpenAPI/Swagger validation, no API-specific vulnerability scanning. |
| **License compliance** | Partially covered | Syft generates SBOMs, but no tool evaluates license compatibility (e.g., GPL contamination in proprietary code). Trivy can do license scanning with `--scanners license` but this is not configured anywhere in the stack. |
| **Dependency confusion / typosquatting** | Not addressed | Nexus proxies upstream registries but has no policy to detect namespace confusion attacks (e.g., a public package with the same name as an internal one). |
| **Signed commits / provenance** | Not addressed | No requirement for GPG-signed commits, no SLSA provenance attestation, no build reproducibility. |
| **Infrastructure drift detection** | Not addressed | No mechanism to detect when deployed infrastructure diverges from IaC definitions. |

**Finding 9:** DAST is the most significant gap. The stack validates code before deployment but never tests the running application. This means the entire class of runtime-discoverable vulnerabilities (authentication bypass, authorization flaws, injection via unexpected input paths, CORS misconfigurations, header security issues) has zero coverage. OWASP ZAP is free, open-source, and can run in CI against a test deployment.

**Finding 10:** License compliance scanning is available in the existing toolchain (Trivy `--scanners license`, Syft SBOM output) but is not configured or mentioned. For an AWS practice that may deliver code to clients, GPL contamination in a proprietary deliverable is a business risk.

---

## 4. Trust Boundaries

### 4.1 Trust Boundary Map

```
┌─────────────────────────────────────────────────────────────────┐
│ TRUST ZONE 1: Developer Workstation (FULLY TRUSTED)            │
│                                                                 │
│  Pre-commit hooks: ADVISORY (can be skipped with --no-verify)  │
│  CLI tools: OPTIONAL (run on demand, no enforcement)           │
│  Package manager config: TRUSTING (points at Nexus over HTTP)  │
│                                                                 │
│  Enforcement points: ZERO                                       │
│  Advisory points: 2 (pre-commit Tier 1, pre-commit Tier 2)    │
└─────────────────────────────────┬───────────────────────────────┘
                                  │ git push (no signing required)
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ TRUST ZONE 2: GitHub (PARTIALLY TRUSTED)                       │
│                                                                 │
│  PR workflow: ADVISORY (continue-on-error: true on all jobs)   │
│  Branch protection: NOT CONFIGURED (listed as optional)         │
│  SARIF upload: INFORMATIONAL (no blocking policy)              │
│                                                                 │
│  Enforcement points: ZERO (as configured)                      │
│  Potential enforcement points: 1 (if branch protection +       │
│    continue-on-error removed)                                   │
│  Advisory points: 5 (Semgrep, Checkov, Trivy, Grype, Gitleaks)│
└─────────────────────────────────┬───────────────────────────────┘
                                  │ merge / deploy
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ TRUST ZONE 3: Kubernetes Cluster (TRUSTED INFRASTRUCTURE)      │
│                                                                 │
│  Nexus: PROXY ONLY (no scanning, no policy enforcement)        │
│  DefectDojo: DASHBOARD ONLY (no enforcement, no blocking)      │
│  Harbor (optional): PARTIAL ENFORCEMENT (can block images      │
│    with Critical CVEs on push — the ONLY enforcement point     │
│    in the entire architecture if deployed)                      │
│  Trivy Operator: ADVISORY (generates reports, does not block)  │
│                                                                 │
│  Enforcement points: 0 (without Harbor) or 1 (with Harbor)    │
│  Advisory points: 2 (DefectDojo dashboard, Trivy Operator)    │
└─────────────────────────────────────────────────────────────────┘
```

**Finding 11:** The entire architecture, as documented, contains ZERO enforcement points. Every security tool is configured in advisory/informational mode. Pre-commit hooks can be bypassed with `--no-verify`. The CI/CD workflow uses `continue-on-error: true`. Branch protection is optional. DefectDojo tracks findings but cannot block deployments. Trivy Operator generates reports but does not prevent workloads from running. The only potential enforcement point is Harbor's scan-on-push blocking, which is listed as optional.

**Finding 12:** There is no deployment gate. Even if CI/CD detects critical vulnerabilities, there is no mechanism to prevent that code from being deployed. The architecture lacks an admission controller (e.g., OPA/Gatekeeper, Kyverno) that could reject deployments based on security scan results, image signatures, or policy violations.

### 4.2 Nexus as a Trust Boundary Failure

Nexus is positioned as the supply chain control point: "Controls what enters your supply chain -- configure Nexus to only serve vetted/approved packages" (Section 6). However, the actual configuration shown is a transparent caching proxy with no policy:

- No content policy rules configured
- No vulnerability scanning on cached packages
- No allowlist/blocklist of packages
- No notification when a cached package is later found to be malicious
- Traffic is over HTTP (not HTTPS) — `registry=http://localhost:8081/repository/npm-proxy/` with `trusted-host = localhost`

**Finding 13:** Nexus is configured as a transparent cache, not a security boundary. It proxies whatever upstream registries serve without inspection. A compromised upstream package flows through Nexus unmodified and unscanned. The "Controls what enters your supply chain" claim in the document is aspirational, not implemented. To realize this claim, Nexus would need content policy rules, or packages flowing through Nexus would need to be scanned by Grype/Trivy before consumption.

**Finding 14:** Package manager configurations use HTTP, not HTTPS, and explicitly set `trusted-host = localhost` and `insecure-registries`. While this may be acceptable for localhost development, in a Kubernetes deployment where Nexus is accessed over the cluster network, this creates an unencrypted channel for all package downloads. A man-in-the-middle on the cluster network could serve malicious packages.

---

## 5. Missing Security Domains

### 5.1 NIST SSDF (Secure Software Development Framework) Coverage

| SSDF Practice Group | Coverage | Assessment |
|---|---|---|
| **PO (Prepare the Organization)** | Partial | Tool selection is documented. Security roles, policies, and training are absent. |
| **PS (Protect the Software)** | Weak | No commit signing, no SLSA provenance, no build reproducibility, no access control documentation. Source code protection relies entirely on GitHub's built-in controls (not documented here). |
| **PW (Produce Well-Secured Software)** | Moderate | SAST, SCA, IaC scanning, and secrets detection are covered. DAST, fuzzing, threat modeling, and secure design review are absent. |
| **RV (Respond to Vulnerabilities)** | Partial | DefectDojo provides finding tracking and lifecycle management. Incident response procedures, vulnerability disclosure, and patching SLAs are not defined beyond DefectDojo's SLA feature. |

**Finding 15:** The stack achieves approximately SSDF maturity Level 1 (ad hoc tooling in place) but not Level 2 (consistent processes across the organization) because it lacks defined policies, roles, training requirements, and incident response procedures.

### 5.2 SLSA (Supply-chain Levels for Software Artifacts) Assessment

| SLSA Level | Requirement | Met? |
|---|---|---|
| **Level 1** | Documentation of the build process, automated build | Partial — CI workflow exists but no provenance attestation |
| **Level 2** | Version control, hosted build service, provenance generation | Partial — GitHub Actions is hosted, but no provenance metadata is generated |
| **Level 3** | Hardened build platform, non-falsifiable provenance | No — no build isolation, no provenance signing, no hermetic builds |
| **Level 4** | Two-person review, reproducible builds | No |

**Finding 16:** The stack does not achieve SLSA Level 1. No build provenance attestation is generated. There is no `slsa-github-generator` or similar tool to create verifiable build provenance. For an AWS practice deploying infrastructure, SLSA provenance on Terraform modules and container images would provide meaningful supply chain integrity.

### 5.3 OWASP SAMM Assessment

| SAMM Practice | Coverage | Gap |
|---|---|---|
| **Governance: Strategy & Metrics** | Not addressed | No security strategy document, no KPIs beyond DefectDojo dashboards |
| **Governance: Policy & Compliance** | Not addressed | No security policies defined, no compliance mapping |
| **Governance: Education & Guidance** | Not addressed | No developer security training |
| **Design: Threat Assessment** | Not addressed | No threat modeling methodology or tooling |
| **Design: Security Requirements** | Not addressed | No security requirements process |
| **Design: Security Architecture** | Partial | This document is the security architecture, but it lacks threat model input |
| **Implementation: Secure Build** | Moderate | CI/CD scanning covers this partially |
| **Implementation: Secure Deployment** | Weak | No admission controllers, no deployment policy |
| **Implementation: Defect Management** | Good | DefectDojo covers this well |
| **Verification: Architecture Assessment** | Not addressed | No architecture review process |
| **Verification: Requirements Testing** | Not addressed | No security requirements to test against |
| **Verification: Security Testing** | Moderate | SAST and SCA covered; DAST and fuzzing absent |
| **Operations: Incident Management** | Not addressed | No IR plan, no runbooks |
| **Operations: Environment Management** | Weak | Self-hosted infra exists but hardening is not documented |
| **Operations: Operational Management** | Weak | No monitoring, alerting, or log aggregation for security events |

**Finding 17:** The stack focuses almost entirely on SAMM's "Verification" stream (security testing) while leaving Governance, Design, and Operations streams unaddressed. This is common in tool-centric security programs but results in a brittle posture — the tools find issues, but there is no organizational process to prioritize, remediate, or learn from them.

### 5.4 Conspicuously Absent Domains

**Finding 18: No audit logging.** None of the self-hosted services (Nexus, DefectDojo, SonarQube, Harbor) have audit logging configured or forwarded to a central log aggregation system. There is no way to detect if someone tampers with DefectDojo findings (e.g., marking critical vulnerabilities as "false positive" to suppress them), modifies Nexus proxy configurations, or accesses the admin interfaces.

**Finding 19: No monitoring or alerting.** No Prometheus, Grafana, or alerting is configured for any of the security infrastructure. If Trivy Operator stops scanning, Nexus goes down, or DefectDojo's import pipeline breaks, nobody is notified. Security tools that silently fail provide a dangerous illusion of coverage.

**Finding 20: No network segmentation.** All services run in the same Kubernetes cluster with no documented NetworkPolicies. DefectDojo (which contains all vulnerability data), Nexus (which serves packages), and application workloads are on the same flat network. A compromised application pod could access the DefectDojo API and suppress findings, or access Nexus and poison the package cache.

**Finding 21: No identity and access management beyond defaults.** The document shows default admin credentials for every service (`admin/admin` for SonarQube, initial password from file for Nexus, token-based auth for DefectDojo). There is no SSO integration, no MFA, no RBAC configuration, no service account hardening. For a single-developer practice this is low-risk, but the document should acknowledge this as a known limitation.

---

## 6. Architectural Anti-Patterns

### 6.1 Security Infrastructure Co-located with Production

The architecture diagram shows DefectDojo, Nexus, SonarQube, Harbor, and Trivy Operator all running on the same Kubernetes cluster as production workloads. This creates several problems:

**Finding 22: Compromise propagation.** If an application workload is compromised, the attacker has network access to all security infrastructure. DefectDojo contains a complete inventory of all known vulnerabilities — this is an attacker's roadmap. Nexus contains credentials for proxying upstream registries. Access to either service from a compromised workload pod is a significant escalation.

**Finding 23: Resource contention.** The security stack requires 5-10 Gi RAM and 2.5-4.5 cores (Section: Kubernetes Self-Hosted Services Summary). On a small cluster, security infrastructure competes with application workloads for resources. Under resource pressure, Kubernetes may evict security pods, silently halting scanning. No PodDisruptionBudgets or priority classes are configured.

**Recommendation:** At minimum, deploy NetworkPolicies to isolate security infrastructure namespaces (defectdojo, nexus, sonarqube, harbor, trivy-system) from application namespaces. Ideally, security infrastructure should run on a dedicated node pool or separate cluster.

### 6.2 No TLS Between Services

**Finding 24:** All internal service communication is over HTTP. The Nexus REST API configuration uses `http://localhost:8081`. DefectDojo import scripts use `http://localhost:8080`. The DefectDojo API token is transmitted in plain text over HTTP. In a Kubernetes cluster network, this means any pod with network access can intercept DefectDojo API tokens, Nexus admin credentials, and scan results. Service mesh (Istio, Linkerd) or pod-level TLS termination should be configured.

### 6.3 The `--break-system-packages` Pattern

The document uses `pip install --break-system-packages` throughout (lines 167, 999, 1319, etc.). This flag overrides pip's external-environment protection and installs packages directly into the system Python, which can break OS-level Python dependencies.

**Finding 25:** Installing security tools with `--break-system-packages` into the system Python is itself a security anti-pattern. It bypasses the isolation that protects system packages from supply chain attacks. If a compromised PyPI package is installed this way, it has system-level access. The document should recommend `pipx` for CLI tool installation or use virtual environments.

### 6.4 Pinned Versions Will Rot

The `.pre-commit-config.yaml` pins specific versions of every hook (e.g., `rev: v8.21.2` for Gitleaks, `rev: v0.10.0.1` for ShellCheck). This is good practice for reproducibility. However, the document does not include any mechanism for keeping these versions current.

**Finding 26:** Pinned tool versions will gradually fall behind, accumulating unpatched vulnerabilities in the security tools themselves and missing detection rules for newly discovered vulnerability patterns. The document should recommend `pre-commit autoupdate` on a regular schedule (e.g., monthly) or Dependabot/Renovate configuration for the `.pre-commit-config.yaml` file.

### 6.5 DefectDojo with `tag: "latest"`

The DefectDojo Helm installation specifies `--set tag="latest"` (line 1408). Using the `latest` tag for a security-critical service means:

**Finding 27:** DefectDojo deployments are not reproducible. A `helm upgrade` or pod restart could pull a different version with breaking changes, new vulnerabilities, or altered behavior. Security infrastructure should be pinned to specific, tested versions.

### 6.6 No Backup or Disaster Recovery

**Finding 28:** None of the self-hosted services have backup configurations documented. DefectDojo's PostgreSQL database contains the entire vulnerability management history. Nexus's blob store contains all cached packages and private artifacts. Loss of either would require rebuilding the security program's historical data from scratch. Persistent volume snapshots, database backups, and recovery procedures should be documented.

---

## Summary of Findings by Severity

### Critical (Architectural Flaws That Negate Security Claims)

| # | Finding | Recommendation |
|---|---|---|
| 8 | `continue-on-error: true` makes all CI scans non-blocking | Remove for at least one gate job; use `--fail-on critical` for Grype; remove `continue-on-error` from Semgrep |
| 11 | Zero enforcement points in the entire architecture | Implement mandatory branch protection, remove `continue-on-error` from critical scanners, add Kubernetes admission controller |
| 7 | Direct pushes to main bypass all scanning | Require branch protection rules blocking direct pushes to main |

### High (Significant Gaps in Coverage)

| # | Finding | Recommendation |
|---|---|---|
| 3 | Near-zero application-level vulnerability detection | Add DAST (OWASP ZAP) to CI/CD pipeline against a test deployment |
| 4 | Semgrep CE intra-file only; cross-file dataflow not covered | Acknowledge limitation explicitly; consider SonarQube (which does cross-file analysis) as less optional |
| 5 | Container scanning skipped during PR review | Remove `if: github.event_name == 'push'` condition from container job |
| 6 | Branch protection listed as optional | Make it a required Phase 2 deliverable |
| 9 | DAST completely absent | Add OWASP ZAP or Nuclei in CI/CD against staging environment |
| 12 | No deployment gate / admission controller | Add OPA/Gatekeeper or Kyverno to enforce image scanning and policy |
| 13 | Nexus is a transparent cache, not a security boundary | Configure content policies or add Grype scanning of cached packages |
| 20 | No network segmentation in K8s | Add NetworkPolicies isolating security infrastructure namespaces |

### Medium (Weaknesses That Reduce Effectiveness)

| # | Finding | Recommendation |
|---|---|---|
| 1 | K8s infra layer is not a detection layer | Correct the architecture description to reflect three detection layers |
| 2 | Correlated false negatives across layers (same tools) | Add at least one diverse scanner per domain (e.g., Clair for containers) |
| 10 | License compliance not configured | Add `trivy fs --scanners license .` to CI workflow |
| 14 | Package manager traffic over HTTP | Configure TLS for Nexus; remove `insecure-registries` in production |
| 16 | No SLSA provenance | Add `slsa-github-generator` to CI workflow |
| 18 | No audit logging | Configure audit logs for DefectDojo, Nexus; forward to central logging |
| 19 | No monitoring/alerting for security infra | Add Prometheus monitoring and alerting for all security services |
| 22 | Security infra co-located with production workloads | Isolate with NetworkPolicies; consider dedicated node pool |
| 24 | No TLS between internal services | Implement service mesh or per-service TLS |
| 25 | `--break-system-packages` is itself a security risk | Use `pipx` or virtual environments |
| 26 | No tool version update mechanism | Add Dependabot/Renovate for `.pre-commit-config.yaml` |
| 27 | DefectDojo uses `tag: "latest"` | Pin to a specific tested version |
| 28 | No backup/DR for security infrastructure | Document backup procedures for DefectDojo DB and Nexus blob store |

### Low (Refinements)

| # | Finding | Recommendation |
|---|---|---|
| 15 | SSDF maturity is Level 1 at best | Document security policies and roles to reach Level 2 |
| 17 | SAMM coverage limited to Verification stream | Expand to Governance and Operations over time |
| 21 | Default credentials, no SSO/MFA | Document as known limitation; plan SSO integration |
| 23 | Resource contention risk | Add PodDisruptionBudgets and priority classes for security pods |

---

## Conclusion

The stack is a strong starting point for tool-based application security. The tool selection is well-researched, the phased implementation is practical, and the zero-cost constraint is met without sacrificing essential capabilities. However, the architecture has a fundamental structural flaw: **it is entirely advisory.** No component in the stack, as configured, can prevent vulnerable code from reaching production. The path from a developer's editor to a production deployment encounters zero hard enforcement points.

Fixing this requires three changes that cost nothing:
1. Make branch protection mandatory (not optional) with required status checks.
2. Remove `continue-on-error: true` from at least the critical scanner jobs and configure severity-based failure thresholds.
3. Add a Kubernetes admission controller (OPA/Gatekeeper is free) that rejects unscanned or non-compliant workloads.

These three changes transform the architecture from a monitoring system into an enforcement system, which is what "security gate" implies but does not currently deliver.
