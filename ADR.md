# Architectural Decision Records — Security Stack

This file records architectural decisions made during the security stack red-team response (2026-02-24).
Each record documents a decision that changed as a result of the independent three-agent red-team analysis.

For the full findings that prompted these decisions, see `red-team/00-consolidated-findings.md`.

---

## ADR-001: Remove `continue-on-error: true` from Scanner Steps

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #1

### Context
Every scanner execution step in the original `security.yml` workflow carried `continue-on-error: true`. This applied to the Semgrep SAST run, the Checkov IaC scan, the Grype SCA scan, and the Gitleaks secrets scan — all four carried this flag. The consequence is that the GitHub Actions workflow always reported a green status check regardless of what scanners found or whether they succeeded at all. The document described this as "the primary security gate," but the gate was structurally incapable of blocking any merge. All three red-team agents identified this independently: Agent 1 framed it as an attack enabler (a PR only needed reviewer approval), Agent 2 framed it as an operational masking problem (scanner crashes and tooling failures were silently swallowed), and Agent 3 identified it as the reason the entire architecture contained zero enforcement points.

### Decision
`continue-on-error: true` is removed from all scanner execution steps. Severity-based failure flags are added to each scanner command (e.g., `grype dir:. --fail-on high`, `semgrep --error` for high/critical severity). `continue-on-error: true` is retained only on SARIF upload steps and artifact upload steps, where a failure should not block a merge — those steps are reporting infrastructure, not enforcement.

### Consequences
**Improved:** The CI security gate becomes blocking. PRs that introduce high-severity findings or trigger scanner errors will fail the workflow and require developer action or explicit risk acceptance before merge.
**Tradeoff:** PR pipelines can now fail on legitimate security findings. Developers must either remediate findings, configure a suppression baseline (e.g., `checkov --create-baseline`), or accept risk explicitly — the workflow no longer silently passes for them.

---

## ADR-002: Make Branch Protection a Required Phase 2 Deliverable

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #2

### Context
The original document listed branch protection as `(Optional)` in the Phase 2 deliverables section: "Branch protection rule configured to require the workflow to pass before merge." Without branch protection, any developer with write access can run `git push origin main` directly, bypassing all PR-triggered scanning entirely. Furthermore, ADR-001's removal of `continue-on-error: true` from scanner steps has no enforcement effect whatsoever without branch protection — a developer can push directly to `main` and the post-push safety-net workflow has no power to prevent the code from landing. Agent 1 identified direct push bypass as a complete circumvention of the PR-based security gate. Agent 3 characterized the combination of optional branch protection and always-green scanner steps as a structural deficiency in which the architecture contained no real enforcement points.

### Decision
Branch protection is promoted from an optional Phase 2 deliverable to a required one. The document now includes explicit GitHub repository settings instructions: require pull requests before merging to `main`, require the security workflow as a passing status check, and block direct pushes to `main`. A warning explains that skipping this step renders the entire CI security gate advisory-only regardless of scanner configuration.

### Consequences
**Improved:** Direct-push bypass is eliminated. Combined with ADR-001, the CI gate now has actual enforcement authority — findings that fail the workflow will block the merge path.
**Tradeoff:** Developers must now open PRs for all changes to `main`; the direct-push shortcut is no longer available. This is a minor workflow change appropriate for any branch that security scanning is intended to protect.

---

## ADR-003: Enable Container Scanning on Pull Request Events

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #3

### Context
The container scanning job in `security.yml` included an explicit event gate: `if: github.event_name == 'push'`. This meant the Trivy container scan ran only on direct pushes to `main` — never on pull requests. The job used `aquasecurity/trivy-action@master` against a freshly built image (`app:${{ github.sha }}`). The PR trigger, which the document explicitly described as "the primary security gate" where results are "surfaced to the developer and reviewer before merge," had a complete blind spot for container image vulnerabilities. A Dockerfile pulling a critically vulnerable base image would pass the PR with no container scan result presented to the reviewer. Container vulnerabilities were first surfaced post-merge, defeating the stated purpose of the PR gate.

### Decision
The `if: github.event_name == 'push'` condition is removed from the container job. The container scan now runs on both `pull_request` and `push` events, consistent with all other scanner jobs in the workflow.

### Consequences
**Improved:** PR reviewers see container vulnerability findings before approving a merge. Container security posture is part of the PR gate, not an after-the-fact post-merge discovery.
**Tradeoff:** PR build times increase slightly on repositories that have a Dockerfile present, due to the added `docker build` and Trivy scan step. Docker layer caching can mitigate this if build time becomes a concern.

---

## ADR-004: Pin GitHub Actions to SHA Digest Placeholder Pattern

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #11

### Context
The original `security.yml` workflow pinned GitHub Actions to mutable references: `aquasecurity/trivy-action@master` (a mutable branch tip), `bridgecrewio/checkov-action@v12` (a mutable semver tag), `github/codeql-action/upload-sarif@v3` (a mutable semver tag), and `actions/checkout@v4` (a mutable semver tag). Mutable tags can be reassigned by the upstream action author at any time. A compromised action repository, or a maintainer with malicious intent, can push new code to an existing tag and every workflow using that tag will execute the new code on the next run — with access to the repository source, the `GITHUB_TOKEN`, and any secrets the workflow uses (including DefectDojo API tokens). Agent 1 rated this as a supply chain attack vector. Agent 2 noted that a breaking change to `@master` would silently break container scanning and be masked by `continue-on-error: true` (a compounding interaction between two findings).

### Decision
The workflow is updated to show the SHA-pinning pattern with a version comment for readability (e.g., `uses: actions/checkout@<SHA> # v4.x.y`). Because live SHAs go stale as new patch releases are published, the document instructs the reader to look up the current SHA for each action at time of adoption, and to configure Dependabot or Renovate to automate SHA updates going forward. The pattern rather than a specific frozen SHA is documented to remain correct across future versions of the blueprint.

### Consequences
**Improved:** Action pinning to SHA digests makes the workflow immutable to upstream tag reassignment. A compromised action release cannot affect a workflow that pins to the pre-compromise SHA.
**Tradeoff:** SHA references are opaque without the accompanying version comment. Keeping SHAs current requires automation (Dependabot/Renovate) or a monthly manual review cadence. Initial adoption requires a one-time lookup of current SHAs for each action used.

---

## ADR-005: Replace Plaintext Tokens with Environment Variables and GitHub Secrets

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #14

### Context
All DefectDojo import script examples in the original document used `DD_TOKEN="your-api-token"` as a literal inline shell variable assignment. All Nexus REST API setup examples used `NEXUS_AUTH="admin:your-password"`. A complete import script block assigned `DD_TOKEN="your-token"` at the top and used it across five separate `curl` calls importing Semgrep, Checkov, Trivy, Grype, and Gitleaks results. These are documentation examples that readers copy directly into real workflows. Credential examples that use literal placeholder strings get transcribed into scripts, committed to repositories, and exposed. Agent 1 rated this Critical: compromise of the DefectDojo API token allows an attacker to read, modify, delete, or fabricate all security findings — eliminating the entire value of the security stack. Agent 2 noted that no token rotation or storage guidance was provided.

### Decision
All DefectDojo token references in bash script examples are replaced with `${DEFECTDOJO_API_TOKEN}` environment variable syntax. All Nexus credential references are replaced with `${NEXUS_PASSWORD}` syntax. In GitHub Actions workflow sections, any token reference uses `${{ secrets.DEFECTDOJO_API_TOKEN }}` syntax. A setup note is added instructing the reader to store the token as a GitHub Actions secret named `DEFECTDOJO_API_TOKEN` via the repository Settings > Secrets and variables > Actions interface.

### Consequences
**Improved:** Script examples model secure credential handling. Tokens are never stored in the script files themselves, reducing the risk of accidental credential exposure through committed workflow files.
**Tradeoff:** One additional setup step is required before the import scripts are functional: the reader must create the GitHub secret and set the environment variable in their shell profile or CI environment. This is a minor and standard operational task.

---

## ADR-006: Pin DefectDojo to Specific Version Tag

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #8

### Context
The original Helm installation command for DefectDojo used `--set tag="latest"`, appearing in two locations in the document: the Phase 3 initial deployment section and the Phase 4 re-deployment section. The `latest` tag in a Helm chart is a floating reference — any pod restart, node replacement, or `helm upgrade` command will pull whatever Docker image is currently tagged `latest` in the DefectDojo image registry. DefectDojo versions can include breaking database schema migrations. A spontaneous upgrade during a pod restart could introduce schema incompatibilities that break the import pipeline scripts (which reference specific API endpoints and field names) or corrupt the vulnerability database. Agent 2 identified this as a silent operational risk. Agent 3 noted that security infrastructure must be pinned to specific tested versions for deployments to be reproducible.

### Decision
The Helm install command is updated to use `--set tag="2.x.y"` with a comment directing the reader to check the DefectDojo releases page (github.com/DefectDojo/django-DefectDojo/releases) for the current stable version at time of deployment. An upgrade procedure note is added: check release notes for breaking changes, run a database backup first, then execute `helm upgrade`.

### Consequences
**Improved:** DefectDojo deployments are reproducible and stable between explicit upgrade decisions. Pod restarts and Helm operations do not silently change the running software version or trigger unexpected schema migrations.
**Tradeoff:** The reader must actively look up the current stable version before deploying rather than relying on `latest`. The pinned version in any persisted `values.yaml` file must be updated when the reader chooses to upgrade.

---

## ADR-007: Externalize Helm Values to Version-Controlled Files

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #4

### Context
All Helm installation commands in the original document used inline `--set` flags exclusively. The DefectDojo deployment used `helm install defectdojo ... --set django.ingress.enabled=true --set host="defectdojo.local" --set tag="latest"`. The Nexus deployment and other services followed the same pattern. Inline `--set` flags are ephemeral: they exist only in shell history. If the Kubernetes cluster is lost, a node is replaced, or the Helm release is accidentally deleted, there is no record of the original configuration values. The service cannot be rebuilt from scratch without reconstructing configuration from memory or command history. Agent 2 flagged this alongside the backup finding: not only is the data at risk, but the configuration required to restore the service is also at risk.

### Decision
Helm install commands are shown alongside a corresponding `values.yaml` example for each service (e.g., `defectdojo-values.yaml`, `nexus-values.yaml`). Installation instructions use the `helm install -f values.yaml` form. The document instructs the reader to store these `values.yaml` files in version control alongside the rest of their infrastructure code.

### Consequences
**Improved:** Service configuration is durable and version-controlled. A complete cluster rebuild or service restore begins from the `values.yaml` file rather than from memory. Configuration drift is visible via git history.
**Tradeoff:** One additional file per deployed service must be created and maintained. This is a small and standard operational practice for any Helm-managed service.

---

## ADR-008: Add NetworkPolicy Guidance to Kubernetes Deployment

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #5

### Context
The original document provided no NetworkPolicy guidance. Default Kubernetes behavior allows unrestricted pod-to-pod communication across all namespaces — any pod can reach any service on any port. The stack deploys DefectDojo, Nexus, SonarQube, Harbor, and Trivy Operator in separate namespaces, but namespace separation alone does not restrict network traffic without explicit NetworkPolicy resources. Agent 1 demonstrated the blast radius of this gap: a compromised application workload pod can reach the DefectDojo API (read, write, delete, or fabricate all security findings), the Nexus API (upload malicious packages into the cache), and the Harbor API (push malicious images). Agent 3 noted that DefectDojo's vulnerability inventory is an attacker's reconnaissance asset — it contains the complete list of known weaknesses in the system.

### Decision
A "Network Security" guidance section is added to the Phase 3 Kubernetes infrastructure documentation. It explains that default Kubernetes allows all pod-to-pod traffic and that NetworkPolicies are required to isolate security-sensitive services. A representative default-deny-ingress NetworkPolicy pattern is provided as a starting point. The isolation intent for each namespace is described (defectdojo, nexus, sonarqube, harbor, trivy-system should not be reachable from arbitrary application namespaces). Kubernetes NetworkPolicy documentation is linked. Full per-service production NetworkPolicy YAML is explicitly not provided — it is too cluster-specific to be accurate in a generic blueprint.

### Consequences
**Improved:** Implementers are explicitly informed that network isolation requires active configuration, and are given a starting pattern and conceptual model for doing so. The security gap from unrestricted lateral movement is documented rather than silently present.
**Tradeoff:** The guidance is approach-level plus a starting pattern, not a complete working configuration. Implementers must adapt NetworkPolicy rules to their specific cluster topology, CNI plugin, and service ingress requirements.

---

## ADR-009: Add TLS Guidance; Warn on `insecure-registries` and `trusted-host`

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #6

### Context
All internal services in the original document were configured for plaintext HTTP. The pip configuration example set `index-url = http://localhost:8081/repository/pypi-proxy/simple` and `trusted-host = localhost`. The Docker daemon configuration included `"insecure-registries": ["localhost:8081"]`. These directives exist because the services run without TLS, and package managers refuse to communicate with registries over HTTP by default. The `trusted-host` pip directive does not merely permit HTTP — it disables certificate verification entirely for that host. The `insecure-registries` Docker directive similarly bypasses TLS for the specified registry. Agent 1 identified these as enabling MITM package substitution. Agent 2 noted that DefectDojo (which stores API tokens and all vulnerability data) was running over plaintext HTTP. Agent 3 pointed out that in a Kubernetes cluster, any pod with network access can intercept credentials and scan results transmitted in plaintext.

### Decision
A TLS guidance subsection is added alongside the NetworkPolicy guidance in the Phase 3 documentation. It describes cert-manager as the recommended approach for provisioning and renewing certificates for internal services, and links to the cert-manager documentation. The existing `trusted-host` and `insecure-registries` configuration examples are annotated with explicit security warnings explaining what these directives do and stating that they must be removed once TLS is configured on the corresponding service. Full cert-manager installation and per-service TLS configuration is not provided — it is too cluster-specific for a generic blueprint.

### Consequences
**Improved:** Readers are explicitly informed of the security implications of the HTTP-only configuration examples. The document no longer presents `trusted-host` and `insecure-registries` as neutral operational choices. A clear path to remediation (cert-manager) is identified.
**Tradeoff:** Full TLS setup remains the implementer's responsibility. The approach is described and linked, but a complete working configuration is out of scope for this blueprint because it requires cluster-specific CA configuration, ingress controller details, and DNS setup.

---

## ADR-010: Correct Nexus Supply Chain Control Framing

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #7

### Context
The original Nexus section included the following bullet point describing Nexus capabilities: "Controls what enters your supply chain — configure Nexus to only serve vetted/approved packages." The actual configuration provided in the document is a transparent caching proxy: proxy repositories for npm, PyPI, Docker, and Helm that pass all upstream traffic through to the package manager client, caching results locally. No content selector configuration was described. No allowlist or blocklist was configured. No scanning was performed by Nexus itself (scanning is handled by Grype and Trivy). The `contentMaxAge: -1` setting cached packages indefinitely. Group repository ordering — which determines whether a hosted (internal) repository is checked before a public proxy repository, a critical dependency confusion protection — was not addressed. Agent 1 and Agent 3 both identified the "Controls what enters your supply chain" claim as creating false confidence: a compromised upstream package flows through Nexus unmodified, gets cached indefinitely, and is served to all developers who install that dependency.

### Decision
The "Controls what enters your supply chain" bullet is replaced with accurate framing: Nexus provides a single audit and caching point, but does not scan content by default — scanning is handled by Grype and Trivy at the CI/CD layer. An explicit note is added that content control (allowlisting, blocklisting) requires additional Nexus content selector and repository blocking configuration beyond the defaults described in this blueprint. Group repository ordering guidance is added explaining that hosted (internal) repositories must be ordered before proxy repositories in any group repository configuration to protect against dependency confusion attacks.

### Consequences
**Improved:** The document no longer creates false confidence that Nexus enforces supply chain policy out of the box. Implementers understand what they actually have (a caching proxy with a single audit point) versus what they would need to add (content policies) to enforce supply chain control.
**Tradeoff:** The Nexus section is less compelling as a marketing description of the tool's potential. This is the correct tradeoff: accurate documentation of what is configured matters more than aspirational capability descriptions.

---

## ADR-011: Add Pre-commit Bypass Warning

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #12

### Context
The original pre-commit section described Gitleaks as the Tier 2 secrets gate running before every push, framed as a meaningful security control for preventing secrets from reaching a remote repository. The document did not acknowledge that `git commit --no-verify` and `git push --no-verify` bypass all pre-commit and pre-push hooks entirely, including Gitleaks, with a single command-line flag requiring no special permissions. The entire pre-commit framework runs on the developer's workstation with no server-side component. Agent 1 identified this as a complete bypass of the pre-commit secrets gate. Agent 3 noted that the Developer Workstation trust zone was fully trusted with zero enforcement points — the architecture had no server-side mechanism to compensate for client-side bypass.

### Decision
An explicit bypass warning is added to the pre-commit section noting that `git commit --no-verify` and `git push --no-verify` bypass all hooks, including Gitleaks. The CI/CD layer (Phase 2) is explicitly identified as the compensating server-side control: Gitleaks also runs in the GitHub Actions workflow against the full git history on every PR and push, and this execution cannot be bypassed from the client side. The warning frames pre-commit as defense-in-depth that catches secrets before they reach the remote, not as the sole secrets enforcement mechanism. Branch protection combined with required CI status checks is identified as the only mechanism that cannot be bypassed client-side.

### Consequences
**Improved:** Readers have an accurate mental model of the pre-commit layer's security properties and its limitations. The CI/CD layer's role as the non-bypassable compensating control is made explicit.
**Tradeoff:** None. The warning adds accurate context without changing any tooling, removing any capability, or increasing operational burden.

---

## ADR-012: Add Backup Guidance for Stateful Services

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #4

### Context
The original document contained no backup, restore, or disaster recovery guidance for any of the stateful services in the stack: DefectDojo (PostgreSQL database containing all vulnerability history, deduplication state, and SLA tracking), Nexus (blob store at `/nexus-data` containing all cached packages), SonarQube (PostgreSQL and Elasticsearch), and Harbor (PostgreSQL and registry storage). Agent 2 rated this Critical, identifying four specific data stores requiring backup and noting that Helm values used during installation were not stored in version control, making rebuild from scratch impossible even with intact data. Agent 3 described the specific consequences: loss of DefectDojo's PostgreSQL means rebuilding the entire vulnerability management history from scratch, and loss of Nexus blob store triggers re-downloading every cached package from upstream registries, which can take hours and stresses upstream bandwidth limits. The combination of no data backup and no configuration backup (inline `--set` flags with no persistence) created a complete recovery gap.

### Decision
A "Backup Considerations" section is added to the Phase 3 documentation. It covers: a `pg_dump` command for DefectDojo PostgreSQL with a CronJob skeleton showing how to schedule it; PVC snapshot guidance for the Nexus `/nexus-data` volume explaining what is lost if the blob store is not backed up; a cross-reference to ADR-007 (Helm values externalization) as the mechanism for preserving service configuration; and a note that Harbor and SonarQube also require backup if deployed. The guidance is approach-level — a complete production backup automation system is outside the scope of this blueprint, but the mechanism and consequence of not backing up each service is documented.

### Consequences
**Improved:** Implementers are informed of the backup requirement for each stateful service, the specific data that is at risk, and a concrete starting mechanism for each. The recovery gap from combining missing data backup with missing configuration backup is closed at the awareness level.
**Tradeoff:** Backup operations require cluster access and persistent storage for backup artifacts. Scheduling automation (Kubernetes CronJob for `pg_dump`) is described but left to the implementer to configure for their specific cluster and storage environment. Backup testing and restore verification procedures are not covered — these require a functioning restore target, which is cluster-specific.
