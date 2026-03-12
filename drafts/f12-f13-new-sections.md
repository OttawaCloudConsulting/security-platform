# Draft Agent D — Features 12, 13

---
## FEATURE 12: APPEND — Security Hardening Notes
<!-- ANCHOR: append after the last existing section, before Feature 13 -->

---

## Security Hardening Notes

This document was updated following a three-agent independent red-team analysis conducted in February 2026. The analysis identified 15 convergent findings — issues raised independently by two or more agents from distinct analytical perspectives (attacker, operator, and architect). All 15 convergent findings are addressed in this document. The full analysis is at `red-team/00-consolidated-findings.md`.

The table below maps each change to the finding it addresses and explains the rationale concisely.

| Change | Addresses | Rationale |
|--------|-----------|-----------|
| Removed `continue-on-error: true` from scanner execution steps; added severity-based failure thresholds (`grype --fail-on high`, `semgrep --error`); retained `continue-on-error` only on SARIF and artifact upload steps | Finding #1 | Every scanner step reported "passed" regardless of findings. The CI/CD gate was entirely advisory — a workflow with 200 critical findings was indistinguishable from a clean one. |
| Enabled container scanning on `pull_request` events (removed `if: github.event_name == 'push'` gate) | Finding #3 | Container vulnerabilities were only discovered post-merge. A Dockerfile pulling a known-vulnerable base image passed the PR gate with no scan. The PR reviewer never saw container findings before approving. |
| Pinned all GitHub Actions to full SHA digest placeholders; added Dependabot note for automated SHA updates | Finding #11 | Semver tags (`@master`, `@v4`) are mutable — an upstream maintainer or a compromised repository can change what those tags point to. A tampered action executes with access to source code, repository secrets, and the DefectDojo API token. SHA pinning is the only immutable reference. |
| Promoted branch protection to a required Phase 2 deliverable with explicit setup instructions; added warning that without it the CI gate has zero enforcement effect | Finding #2 | Without mandatory branch protection, developers can push directly to `main`, bypassing all PR-based scanning. The `continue-on-error` fix in Finding #1 has no enforcement effect without branch protection — a required status check is the mechanism that converts the gate from advisory to blocking. |
| Replaced plaintext API tokens with environment variable references (`${DEFECTDOJO_API_TOKEN}`) in scripts and `${{ secrets.DEFECTDOJO_API_TOKEN }}` in workflow examples; added secrets setup instructions | Finding #14 | Plaintext tokens in reference documentation get copied verbatim into real workflows. A compromised DefectDojo API token gives an attacker read/write access to the complete vulnerability inventory — the most sensitive output of this entire stack. |
| Pinned DefectDojo Helm installation to a specific version tag; added `defectdojo-values.yaml` example for version-controlled Helm values; added upgrade procedure note | Finding #8 | `tag="latest"` means any pod restart or `helm upgrade` can pull a new major version with breaking schema migrations. Security infrastructure must be reproducible. Uncontrolled upgrades can break the import pipeline and corrupt the findings database. |
| Added backup guidance for DefectDojo PostgreSQL (`pg_dump` CronJob skeleton) and Nexus (`/nexus-data` PVC snapshots); documented what is lost without backup | Finding #4 | No backup means rebuilding the entire vulnerability history from scratch on any data loss event. Loss of Nexus blob storage triggers re-download of all cached packages from upstream registries — the opposite of supply chain control. |
| Added NetworkPolicy guidance with a default-deny ingress pattern; noted each service namespace should be isolated from application namespaces | Finding #5 | Default Kubernetes allows all pod-to-pod traffic across all namespaces. A compromised application workload can reach the DefectDojo API (read, modify, or delete all findings), the Nexus API (upload malicious packages into the cache), and the Harbor API (push malicious images). |
| Added TLS guidance recommending cert-manager for all internal services; added security warnings on `insecure-registries` and `trusted-host` directives | Finding #6 | All internal service communication was plaintext HTTP. DefectDojo API tokens, Nexus credentials, and scan results were transmitted unencrypted. The `trusted-host` pip directive and `insecure-registries` Docker directive disable certificate verification entirely — appropriate only as a temporary bootstrap measure, not a production configuration. |
| Corrected Nexus "Controls what enters your supply chain" framing to accurately describe it as a caching proxy and single audit point; added group repository ordering guidance (hosted before proxy) to address dependency confusion risk; explained `contentMaxAge: -1` tradeoff | Finding #7 | Nexus does not scan content by default — that is handled by Grype and Trivy. Claiming supply chain control without a content policy or repository ordering is inaccurate. Dependency confusion attacks exploit group repositories where a proxy repo takes precedence over a hosted repo. |
| Added `--no-verify` bypass warning to the pre-commit section; clarified that the CI/CD gate is the compensating server-side control; framed pre-commit as defense-in-depth, not the enforcement layer | Finding #12 | `git commit --no-verify` and `git push --no-verify` bypass all pre-commit hooks, including Gitleaks. The document acknowledged secrets risk at push but relied on client-side enforcement only. This framing is corrected: pre-commit is a convenience layer; branch protection plus required CI checks is the enforcement layer. |
| Added version update process guidance: `pre-commit autoupdate` for hook versions, Dependabot or Renovate for GitHub Actions SHA updates, recommended monthly review cadence | Finding #10 | Pinned versions accumulate unpatched vulnerabilities in the security tools themselves and miss detection rules for newly discovered vulnerability patterns. A single developer tracking 30-40 independently versioned components without an automated update process will fall months behind within a year. |
| Added "Managing Finding Volume" subsection in Phase 3 covering `checkov --create-baseline`, DefectDojo deduplication rules, severity-based auto-close for INFO/LOW findings, and a weekly time-boxed triage cadence | Finding #15 | First-run estimates from the red-team analysis: 125-750 findings per repository. Without a triage SOP, DefectDojo becomes a write-only database. The most likely long-term failure mode of this stack is not a tool failure — it is the developer abandoning triage because the volume is unmanageable. |
| Added "Monitoring the Security Stack" note identifying minimum alerting targets (Nexus disk usage, DefectDojo import failures, Trivy Operator database staleness, pod CrashLoopBackOff); recommended Prometheus + Alertmanager via kube-prometheus-stack | Finding #9 | Security tools that silently fail provide a dangerous illusion of coverage. If Trivy Operator stops scanning or the DefectDojo import pipeline breaks, there is no notification. The absence of an alert looks identical to a clean environment. |

---
## FEATURE 13: APPEND — Known Gaps and Out-of-Scope
<!-- ANCHOR: append as the final section of the document -->

---

## Known Gaps and Out-of-Scope

No security stack covers everything, especially under a zero-cost, single-developer-sustainability constraint. These gaps are documented so implementers can make informed risk decisions rather than assuming coverage that does not exist.

### Dynamic Application Security Testing (DAST)

This stack is entirely static analysis. No tool tests a running application.

**What is missing:** Authentication bypass, session management flaws, business logic vulnerabilities, runtime injection paths, CORS and CSP misconfiguration, HTTP security header issues, and SSRF. These vulnerability classes are structurally invisible to any form of static analysis — they only manifest in a running system under test.

**Why out of scope:** DAST requires a deployed test environment with realistic configuration. This stack makes no assumptions about deployment targets or test environment availability.

**Free option for future consideration:** OWASP ZAP can run in CI in headless mode against a test deployment. When a test environment exists, adding a ZAP active scan as an additional CI job is a zero-cost extension. The `zap-baseline` scan provides a low-friction starting point.

---

### Runtime Application Protection (RASP / WAF)

Nothing in this stack detects or blocks active exploitation of deployed vulnerabilities. Scanning finds vulnerabilities before deployment; it does not respond to attacks after deployment.

**What is missing:** A web application firewall or runtime protection agent that can detect and block exploitation attempts, abnormal request patterns, and known attack payloads targeting deployed services.

**Why out of scope:** WAF configuration is highly application-specific — rules must be tuned to each application's normal traffic patterns to avoid excessive false positives. The complexity is disproportionate to a single-developer practice without a dedicated security operations function.

**Free options for future consideration:** ModSecurity (open-source WAF, integrates with nginx and Apache). If already on AWS, AWS WAF has a limited free tier through the standard AWS account.

---

### Security Logging, Monitoring, and SIEM

The "Monitoring the Security Stack" section (added in response to Finding #9) covers operational health of the security tooling itself. That is not a SIEM.

**What is missing:** Centralized security event logging, detection of anomalous behavior (unexpected API calls, unusual authentication patterns, privilege escalation), audit trails for security service APIs, and correlation of events across services. Falco, for example, detects container runtime anomalies that none of the static tools can surface.

**Why out of scope:** A SIEM at any meaningful fidelity requires dedicated infrastructure, significant initial tuning, and ongoing rule maintenance. That is a second full-time workload, not a single-developer addition.

**Free option for future consideration:** Wazuh is a self-hosted, open-source SIEM that integrates with Kubernetes and covers log analysis, file integrity monitoring, and vulnerability detection. It is a substantial deployment but requires no external accounts or licensing.

---

### Incident Response Procedures

This document is a tooling reference. It specifies no process for responding to findings the tools surface.

**What is missing:** A defined procedure for secret rotation after Gitleaks detects a committed credential, a supply chain compromise response runbook when a malicious package is found in Nexus, rollback procedures when a compromised image reaches production, SLA targets for remediating high and critical findings, and escalation paths.

**Why out of scope:** Incident response is process documentation, not tooling. The appropriate output is a separate runbook document, not an addition to a tooling reference.

**Note:** These procedures should be documented before treating this stack as production-grade. The tools generate the signal; without a response process, that signal goes unacted on. At minimum, define what to do when Gitleaks fires.

---

### Code and Image Signing / SLSA Provenance

Nothing in this stack verifies that code, artifacts, or container images have not been tampered with between build and deployment.

**What is missing:** Commit signing (GPG or SSH keys) to verify author identity, container image signing (Cosign or Notation) to verify that the image deployed matches the image built in CI, SLSA provenance attestations linking a deployed artifact to its source commit and build pipeline, and an admission controller (OPA Gatekeeper, Kyverno) that rejects unsigned images before they run in the cluster.

**Why out of scope:** Signing infrastructure requires a key management strategy — key generation, storage, rotation, and revocation. SLSA Level 2 and above require specific CI/CD build isolation guarantees that involve significant pipeline restructuring. This is a meaningful architectural investment, not a configuration addition.

**Free options for future consideration:** Sigstore/Cosign (CNCF project, free and open-source) for container image signing; GitHub's built-in commit signing for commits. Both integrate with the existing GitHub Actions and Kubernetes setup described in this document.

---

### Kubernetes RBAC Hardening and Pod Security

The K8s deployment sections in this document focus on getting services running. No workload hardening is configured.

**What is missing:** Pod Security Standards enforcement (blocking privileged containers, host network access, host path mounts), service account restrictions (default service accounts have more permissions than necessary), RBAC policies limiting who can `kubectl exec` into security tool pods, and an admission controller to enforce policies before workloads are scheduled.

**Why out of scope:** RBAC and Pod Security hardening are highly cluster-specific — they require an audit of every workload currently running. Providing generic policies without that audit creates a high risk of breaking existing workloads. This is not addressable in a generic reference document.

**Free options for future consideration:** Kyverno (CNCF project, open-source) for policy-as-code enforcement. Pod Security Admission is built into Kubernetes 1.25+ and requires no additional tooling — it enforces the three Pod Security Standard profiles (privileged, baseline, restricted) at the namespace level.

---

### Cross-File Dataflow SAST

Semgrep Community Edition performs intra-file pattern matching. It does not trace data across function or file boundaries.

**What is missing:** Most real-world injection vulnerabilities involve data that enters at one boundary (an HTTP request handler), passes through several functions across multiple files, and reaches a sink (a database query, a shell command, an HTML render) somewhere else entirely. These multi-hop taint flows are structurally invisible to CE pattern matching. Semgrep CE will not detect SQL injection where the user input is validated in one file and used unsanitized in another.

**Why out of scope:** Cross-file dataflow analysis requires Semgrep Pro (commercial) or CodeQL. Both require either a paid license or a specific repository configuration.

**Note:** GitHub's native CodeQL scanning is free for public repositories. For private repositories it requires GitHub Advanced Security, which is a paid feature. CodeQL provides deep cross-file dataflow analysis for Python, JavaScript, TypeScript, Go, Java, and C/C++. If repositories ever become public, enabling the default CodeQL workflow is a zero-cost upgrade to this stack's SAST coverage.

---

### License Compliance Scanning

Syft generates SBOMs containing license metadata for every dependency. No tool in this stack evaluates whether those licenses are compatible with each other or with the project's intended distribution.

**What is missing:** Detection of GPL or AGPL licensed dependencies in projects that cannot satisfy copyleft requirements, flagging of dual-licensed packages where the open-source version has usage restrictions, and policy enforcement that blocks dependencies with prohibited license types from entering the stack.

**Why out of scope:** License compliance policy is organization-specific — the same dependency may be acceptable in one context and prohibited in another. Configuring a license scanner without a defined policy produces noise, not signal. The tooling question is secondary to the policy question.

**Free options for future consideration:** Trivy has a `--scanners license` mode that can flag licenses against a configurable allow/deny list — it is available in the existing Trivy installation but is not enabled in the CI workflow. FOSSA Community edition (free tier) provides more structured license policy management for future consideration.
