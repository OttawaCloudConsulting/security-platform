# Red Team Consolidated Findings
**Synthesized from three independent red-team analyses of the Code Security & Supply Chain Stack**

**Date:** 2026-02-20

**Agents:**
- Agent 1 (Attacker): External attacker and malicious insider bypass analysis
- Agent 2 (Operator): Operational reliability, maintenance burden, and failure mode analysis
- Agent 3 (Architect): Security architecture, design flaws, and defense-in-depth analysis

---

## Convergent Findings

The following issues were independently identified by two or more agents. These represent the highest-confidence findings because they were surfaced from fundamentally different analytical perspectives.

### 1. `continue-on-error: true` Renders the CI/CD Gate Non-Blocking

**Flagged by:** All three agents

This was the single most consistently cited flaw across all reports. Every scanner step in the GitHub Actions workflow uses `continue-on-error: true`, which means the workflow always reports "passed" regardless of findings.

- **Agent 1 (Section 1.3):** Frames this as an attack enabler. An attacker merging a PR only needs reviewer approval since security jobs never fail the build. Rated **Critical**.
- **Agent 2 (Section 3.5):** Frames this as an operational masking problem. Scanner failures (broken tooling, missing databases, upstream action changes) are silently swallowed, producing false green checks with no scanning having occurred.
- **Agent 3 (Finding 8, Finding 11):** Frames this as an architectural flaw. Combined with optional branch protection, the entire architecture contains **zero enforcement points**. Every security tool operates in advisory/informational mode.

### 2. Branch Protection Is Optional, Not Mandatory

**Flagged by:** Agent 1 and Agent 3

The document lists branch protection as an optional Phase 2 deliverable. Without it, the CI/CD security gate provides zero enforcement.

- **Agent 1 (Section 1.5):** Notes that anyone with write access can `git push origin main` directly, bypassing all PR-based scanning. The push-triggered workflow runs post-facto.
- **Agent 3 (Findings 6, 7):** Identifies this as a structural deficiency. The push-to-main trigger is a "safety net" that runs after code is already on the protected branch. Branch protection should be a required deliverable, not optional.

### 3. Container Scanning Excluded from PR Gate

**Flagged by:** Agent 1 and Agent 3

The Trivy container scan job only runs on `push` events (`if: github.event_name == 'push'`), not on `pull_request` events.

- **Agent 1 (Section 1.4):** The PR gate -- described as the primary security gate -- has a complete blind spot for container image vulnerabilities. A Dockerfile pulling a known-vulnerable base image passes the PR with no container scan.
- **Agent 3 (Finding 5):** The PR reviewer never sees container vulnerability findings before approving a merge. Container vulnerabilities are discovered post-merge, defeating the purpose of a PR gate.

### 4. No Backup or Disaster Recovery for Stateful Services

**Flagged by:** Agent 2 and Agent 3

Neither report found any mention of backup, restore, or disaster recovery procedures for DefectDojo, Nexus, SonarQube, or Harbor.

- **Agent 2 (Section 6.1):** Identifies four specific data stores requiring backup (DefectDojo PostgreSQL, Nexus `/nexus-data`, SonarQube PostgreSQL + Elasticsearch, Harbor PostgreSQL + registry storage). Rated **Critical**. Also notes (Section 6.6) that Helm values used during installation are not stored in version control, making rebuild from scratch impossible.
- **Agent 3 (Finding 28):** Loss of DefectDojo's database means rebuilding the entire vulnerability management history from scratch. Loss of Nexus blob store triggers massive upstream re-downloads.

### 5. No Network Segmentation / Kubernetes NetworkPolicies

**Flagged by:** Agent 1 and Agent 3

All services run in separate namespaces but with no NetworkPolicies, meaning default Kubernetes behavior allows all pod-to-pod communication.

- **Agent 1 (Section 4.5):** A compromised pod in any namespace can reach DefectDojo API (read/write all findings), Nexus API (upload malicious packages), SonarQube API (disable rules), and Harbor API (push malicious images).
- **Agent 3 (Findings 20, 22):** DefectDojo contains a complete vulnerability inventory -- an attacker's roadmap. A compromised application workload could access DefectDojo and suppress findings, or access Nexus and poison the package cache.

### 6. No TLS for Internal Service Communication

**Flagged by:** Agent 1, Agent 2, and Agent 3

All internal services communicate over plaintext HTTP. Package manager configs use `http://localhost:8081`, `trusted-host = localhost`, and `insecure-registries`.

- **Agent 1 (Section 2.3):** HTTP between Nexus and clients enables MITM substitution of packages. The `trusted-host` pip directive disables certificate verification entirely.
- **Agent 2 (Section 6.3):** Notes the absence of TLS termination, certificate provisioning, and certificate renewal. Running DefectDojo (which stores API tokens) over plaintext HTTP is a security concern in a security stack.
- **Agent 3 (Findings 14, 24):** DefectDojo API tokens are transmitted in plain text. In a Kubernetes cluster network, any pod with network access can intercept credentials and scan results.

### 7. Nexus Configured as Transparent Cache, Not a Security Boundary

**Flagged by:** Agent 1 and Agent 3

The document claims Nexus "Controls what enters your supply chain," but the actual configuration is a transparent caching proxy with no content policy, no allowlisting, and no scanning.

- **Agent 1 (Sections 2.1, 2.4):** Nexus will cache and indefinitely serve compromised upstream packages (`contentMaxAge: -1`). No dependency confusion protections are configured. No repository ordering in group repositories is described.
- **Agent 3 (Finding 13):** A compromised upstream package flows through Nexus unmodified and unscanned. The "Controls what enters your supply chain" claim is aspirational, not implemented.

### 8. DefectDojo `tag: "latest"` Creates Uncontrolled Upgrades

**Flagged by:** Agent 2 and Agent 3

The Helm installation uses `--set tag="latest"` for DefectDojo.

- **Agent 2 (Section 6.4):** The next `helm upgrade` or pod restart will pull whatever version is currently tagged `latest`, potentially introducing breaking changes, schema migrations, or API incompatibilities that break import scripts.
- **Agent 3 (Finding 27):** Security infrastructure should be pinned to specific, tested versions. Deployments are not reproducible.

### 9. No Monitoring or Alerting for the Security Stack Itself

**Flagged by:** Agent 2 and Agent 3

No Prometheus, Grafana, Falco, or any alerting is configured for the security infrastructure.

- **Agent 2 (Section 6.2):** No alerting for Nexus running out of disk, DefectDojo import failures, Trivy Operator database staleness, or any pod in CrashLoopBackOff. "The security stack itself is unmonitored. The tools that are supposed to detect problems have no mechanism for detecting problems with themselves."
- **Agent 3 (Finding 19):** If Trivy Operator stops scanning, Nexus goes down, or DefectDojo's import pipeline breaks, nobody is notified. Security tools that silently fail provide a dangerous illusion of coverage.

### 10. Pinned Tool Versions Will Rot Without an Update Mechanism

**Flagged by:** Agent 2 and Agent 3

The `.pre-commit-config.yaml` and GitHub Actions workflow pin specific versions but no mechanism exists for keeping them current.

- **Agent 2 (Sections 1.1, 4.1):** A single developer must track roughly 30-40 independently versioned components. No Dependabot, Renovate, or scheduled update pipeline is described. After 6 months, hooks will be running versions with known bugs and missing rules.
- **Agent 3 (Finding 26):** Pinned versions will accumulate unpatched vulnerabilities in the security tools themselves and miss detection rules for newly discovered vulnerability patterns.

### 11. GitHub Actions Pinned to Mutable Tags, Not SHAs

**Flagged by:** Agent 1 and Agent 2

The Trivy action pins to `@master` (a mutable branch tag). Other actions use semver tags (`@v4`, `@v12`) which are also mutable.

- **Agent 1 (Section 5.6):** A compromised upstream action can execute arbitrary code with access to source code, GitHub tokens, and DefectDojo API tokens. Only SHA-pinning provides immutability.
- **Agent 2 (Section 3.5):** A breaking change to the Trivy action will silently break container scanning, masked by `continue-on-error: true`.

### 12. Pre-commit Hooks Are Client-Side and Bypassable

**Flagged by:** Agent 1 and Agent 3

The entire pre-commit framework runs on the developer workstation with no server-side enforcement.

- **Agent 1 (Section 1.2):** `git commit --no-verify` and `git push --no-verify` bypass all hooks, including the Gitleaks secrets gate. The document acknowledges secrets risk on push but relies on client-side enforcement only.
- **Agent 3 (Finding 11, Trust Boundary Map):** The Developer Workstation trust zone is fully trusted with zero enforcement points and two advisory points. The architecture has no server-side mechanism to compensate.

### 13. DAST Completely Absent

**Flagged by:** Agent 1 and Agent 3

The stack is entirely static analysis. No dynamic application security testing is included.

- **Agent 1 (Section 5.1):** Entire classes missed: authentication/session management flaws, business logic vulnerabilities, runtime configuration issues, SSRF, race conditions.
- **Agent 3 (Findings 3, 9):** DAST is the most significant gap. The stack validates code before deployment but never tests the running application. OWASP ZAP is free and can run in CI against a test deployment.

### 14. DefectDojo API Token and Nexus Credentials Exposed in Scripts

**Flagged by:** Agent 1 and Agent 2

Import scripts and configuration examples store API tokens and passwords in plaintext shell variables.

- **Agent 1 (Section 4.1):** Compromise of the DefectDojo API token allows an attacker to read, modify, delete, or fabricate all security findings. Rated **Critical**.
- **Agent 2 (Section 6.5):** No description of how to rotate tokens, where CI/CD credentials are stored, or what happens when a token expires.

### 15. Single-Developer Sustainability / Alert Fatigue

**Flagged by:** Agent 2 and Agent 3

The stack generates more operational and triage burden than a single developer can sustain.

- **Agent 2 (Sections 2.1-2.3):** Estimates 125-750 findings per repository on first run, leading to a "triage death spiral" where DefectDojo becomes a write-only database. Describes this as the most likely long-term failure mode.
- **Agent 3 (Finding 17):** The stack focuses on the Verification stream (security testing) while leaving Governance, Design, and Operations streams unaddressed -- tools find issues but there is no organizational process to prioritize or remediate them.

---

## Top 10 Priority Actions

Ranked by impact, addressing findings raised by multiple agents. All items are zero-cost changes.

| # | Action | Addresses | Effort | Agents |
|---|--------|-----------|--------|--------|
| 1 | **Remove `continue-on-error: true` from scanner steps.** Add a dedicated gate job with severity-based failure thresholds (e.g., `grype dir:. --fail-on high`, Semgrep `--error` on high/critical). Keep `continue-on-error` only on SARIF upload and artifact upload steps so reporting still works when a scanner legitimately finds nothing. | Convergent #1 | Config change (1-2 hours) | 1, 2, 3 |
| 2 | **Make branch protection mandatory.** Require PRs for all merges to `main`, require the security workflow as a status check, block direct pushes. Move this from "Optional" to a required Phase 2 deliverable. | Convergent #2 | Config change (30 minutes) | 1, 3 |
| 3 | **Enable container scanning on PR events.** Remove `if: github.event_name == 'push'` from the container job. If build time is a concern, use Docker layer caching. | Convergent #3 | Config change (30 minutes) | 1, 3 |
| 4 | **Pin all GitHub Actions to full SHA digests.** Replace `@master`, `@v4`, `@v12` with `@sha256:...` references. Add a Dependabot or Renovate config to automate SHA updates. | Convergent #11 | Half-day | 1, 2 |
| 5 | **Store all API tokens and credentials as GitHub encrypted secrets.** Remove plaintext tokens from import scripts. Add CODEOWNERS protection for `.github/workflows/` to prevent self-merge of workflow modifications. | Convergent #14, Agent 1 Section 5.8 | Half-day | 1, 2 |
| 6 | **Deploy Kubernetes NetworkPolicies** isolating each service namespace (defectdojo, nexus, sonarqube, harbor, trivy-system) from application namespaces and from each other. | Convergent #5 | Half-day to one day | 1, 3 |
| 7 | **Configure TLS for all internal services.** At minimum, use cert-manager with self-signed certificates for Nexus, DefectDojo, and Harbor. Remove `insecure-registries` and `trusted-host` directives from reference configurations. | Convergent #6 | One day | 1, 2, 3 |
| 8 | **Pin DefectDojo to a specific version tag.** Replace `--set tag="latest"` with a tested version. Store all Helm values in version-controlled `values.yaml` files rather than inline `--set` flags. Document upgrade procedures. | Convergent #8, Agent 2 Section 6.4 | Config change (1 hour) | 2, 3 |
| 9 | **Add backup CronJobs** for DefectDojo PostgreSQL (`pg_dump`) and Nexus data volume (PVC snapshot or volume backup). Document restore procedures. Add PVC usage monitoring/alerting at minimum. | Convergent #4 | One day | 2, 3 |
| 10 | **Define a realistic finding triage SOP.** Set severity thresholds for attention, auto-close rules for INFO/LOW findings, configure DefectDojo deduplication strategy explicitly, and establish a weekly time-boxed review cadence. Configure Checkov `--create-baseline` equivalent for all scanners. | Convergent #15, Agent 2 Section 2.3 | Half-day (process), multi-day (tuning) | 2, 3 |

---

## Coverage Gap Summary

All three agents agree these security domains are NOT covered by the current stack:

| Security Domain | Gap Description | Agents |
|---|---|---|
| **Dynamic Application Security Testing (DAST)** | No testing of running applications. Zero coverage for authentication bypass, business logic flaws, runtime injection, CORS/CSP/header misconfigurations. | 1, 3 |
| **Runtime application protection (RASP/WAF)** | No web application firewall or runtime protection. Nothing detects or blocks active exploitation of deployed vulnerabilities. | 1, 3 |
| **Logging, monitoring, and alerting** | No centralized logging, no security event monitoring (e.g., Falco), no alerting on scan failures or new critical findings, no audit logging for security service APIs. | 1, 2, 3 |
| **Incident response** | No defined process for secret rotation after Gitleaks detection, supply chain compromise via Nexus, or rollback of compromised deployments. No SLA targets configured. | 1, 2 |
| **Code/image signing and provenance** | No commit signing (GPG/SSH), no image signing (Cosign), no SLSA provenance attestation, no deployment admission control verifying signatures. | 1, 3 |
| **Kubernetes hardening** | No Pod Security Standards, no service account restrictions, no RBAC policies for `kubectl exec`, no admission controller (OPA/Gatekeeper/Kyverno). | 1, 3 |
| **Dependency confusion / typosquatting protection** | Nexus group repository ordering not configured. No namespace isolation or scoping guidance for internal packages. | 1, 3 |
| **License compliance** | Syft generates SBOMs but no tool evaluates license compatibility. Trivy `--scanners license` is available but not configured. | 3 |
| **Infrastructure drift detection** | No mechanism to detect when deployed infrastructure diverges from IaC definitions. | 3 |
| **Cross-file dataflow SAST** | Semgrep CE is intra-file only. Most real-world injection vulnerabilities span multiple files and are structurally invisible. No compensating tool configured. | 1, 3 |

---

## What the Stack Gets Right

The three reports collectively validate several sound decisions through explicit acknowledgment or absence of critique:

1. **Tool selection is strong.** All three agents accepted the tool choices as appropriate. The combination of Semgrep CE + Checkov + Trivy + Grype + Gitleaks covers SAST, IaC, container, SCA, and secrets scanning with genuine redundancy where it matters (e.g., Checkov + Trivy for IaC use different analysis approaches; Grype + Trivy for SCA use partially independent vulnerability databases). See Agent 3, Section 3.1.

2. **The phased implementation is pragmatic.** No agent challenged the four-phase rollout or suggested it was incorrectly ordered. Phases 1-2 deliver immediate value with no infrastructure cost. Phases 3-4 build incrementally.

3. **Zero-cost constraint is met without meaningful sacrifice.** The stack achieves coverage across SAST, SCA, IaC, secrets, container scanning, SBOM generation, and centralized findings management using only open-source tools requiring no external accounts.

4. **Gitleaks in pre-commit (Tier 2) is the correct design.** Agent 1 validated the reasoning: a secret pushed to any branch is an exposure from the moment it reaches a remote. Deferring SAST/IaC scanning to CI while keeping secrets detection in pre-commit is a sound tradeoff between friction and risk.

5. **Separating SAST/IaC from pre-commit is defensible.** Agent 3 acknowledged the friction argument is valid. The risk window it creates was critiqued, but the decision to defer full-repo scanning to the PR gate was not rejected -- the critique was about the lack of compensating controls (mandatory branch protection, enforcement at the gate).

6. **DefectDojo as the aggregation layer is well-chosen.** Agent 3 rated DefectDojo's defect management coverage as "Good" in the OWASP SAMM assessment. Its 200+ parser integrations, lifecycle tracking, and deduplication capabilities are the right choice for a unified dashboard.

7. **Genuine tool diversity exists where it matters.** Agent 3 noted that Checkov + Trivy for IaC scanning provides "high value" overlap because they use different analysis approaches (graph-based vs. pattern-based). The stack is not simply running the same tool at different stages.

---

*For full details on any finding, refer to the individual reports:*
- *Agent 1:* `01-attacker-perspective.md`
- *Agent 2:* `02-operator-perspective.md`
- *Agent 3:* `03-architect-perspective.md`
