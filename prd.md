# PRD: Security Stack Red-Team Response

## Summary

Update `development-security-stack-option-1.md` to address all 15 convergent findings from the independent red-team analysis (`red-team/00-consolidated-findings.md`). The document is a reference blueprint for a zero-cost, open-source security stack targeting a single-developer AWS cloud practice. Updates make inline fixes to configurations, add a "Security Hardening Notes" section with rationale for key changes, and introduce a Known Gaps section documenting out-of-scope security domains.

A companion `ADR.md` records Architectural Decision Records for each decision that changed as a result of the red-team findings, using standard ADR format (Context / Decision / Consequences).

## Goals

- Address all 15 convergent red-team findings in the document
- Make inline fixes to configurations, commands, and deployment specs
- Append a "Security Hardening Notes" section explaining the rationale for key changes
- Append a "Known Gaps and Out-of-Scope" section documenting uncovered security domains
- Create `ADR.md` capturing decisions that changed (and what replaced them), one record per changed decision
- Preserve the document's zero-cost, self-hosted, no-external-accounts constraint
- Maintain single-developer sustainability — no changes that create unsustainable operational burden

## Non-Goals

- Adding DAST tooling (OWASP ZAP or otherwise) — acknowledged in Known Gaps section instead
- Full working Kubernetes YAML for cert-manager TLS or NetworkPolicies — describe approach and link to upstream docs
- Enforcing GitHub repository settings (branch protection) programmatically — document as required with clear instructions
- Addressing findings unique to a single red-team agent (only convergent findings are in scope)
- Changing the fundamental architecture (4-phase structure, tool selection, zero-cost constraint)

## Constraints

- All changes remain zero-cost and require no external accounts
- The document is a reference/blueprint — cannot enforce tooling choices, only describe best practice configurations
- Single-developer sustainability must be maintained throughout

---

## Features

### Feature 1: GitHub Actions Workflow Hardening

Fix the CI/CD workflow (`security.yml`) to address the four convergent findings it contains.

**Changes:**
- Remove `continue-on-error: true` from scanner execution steps; add severity-based failure thresholds (e.g., `grype dir:. --fail-on high`, `semgrep --error`)
- Keep `continue-on-error: true` only on SARIF upload and artifact upload steps (these should not fail the build)
- Fix container job to run on both `pull_request` and `push` events (remove `if: github.event_name == 'push'` gate)
- Pin all GitHub Actions to full SHA digests instead of mutable tags (`@master`, `@v4`, `@v12`)
- Replace all plaintext API tokens with GitHub Actions secrets syntax (`${{ secrets.DEFECTDOJO_API_TOKEN }}`)
- Add note explaining how to configure secrets in GitHub repository settings

**Acceptance Criteria:**
- `continue-on-error: true` appears only on upload steps, not scanner steps
- Container scan job trigger includes `pull_request`
- All `uses:` lines reference SHA digests, with version comments for readability
- No plaintext tokens in any workflow or script example
- A Dependabot/Renovate note is added explaining how to automate SHA updates

**Addresses:** Convergent Findings #1, #3, #11, #14

---

### Feature 2: Branch Protection Promoted to Required

Move branch protection from "Optional" to a required Phase 2 deliverable.

**Changes:**
- In the Phase 2 section, change branch protection from `(Optional)` to a required deliverable with explicit setup instructions
- Add the specific GitHub settings to configure: require PRs, require the security workflow as a passing status check, block direct pushes to `main`
- Add a warning explaining the security consequence of skipping this: the entire CI security gate is advisory-only

**Acceptance Criteria:**
- Phase 2 deliverables list includes branch protection as required (not optional)
- Step-by-step instructions for GitHub branch protection settings are provided
- Document explains that without this, `continue-on-error` changes in Feature 1 have no enforcement effect

**Addresses:** Convergent Finding #2

---

### Feature 3: DefectDojo Deployment Hardening

Fix the DefectDojo Helm installation command and add operational guidance.

**Changes:**
- Replace `--set tag="latest"` with a pinned version (e.g., `--set tag="2.x.y"`) with a note to check the DefectDojo releases page for the current stable version
- Add instruction to save Helm values to a version-controlled `values.yaml` file rather than inline `--set` flags
- Add note describing upgrade procedure (check release notes, backup first, then `helm upgrade`)

**Acceptance Criteria:**
- Helm install command uses a pinned version tag (with a comment indicating the reader should substitute the current release)
- A `defectdojo-values.yaml` example snippet is provided showing how to store settings durably
- Upgrade guidance is present

**Addresses:** Convergent Finding #8

---

### Feature 4: Backup Guidance for Stateful Services

Add a "Backup and Recovery" subsection to the Phase 3 section covering the two core stateful services.

**Changes:**
- DefectDojo: Add a `pg_dump` CronJob example (approach-level, not full production config) for the PostgreSQL database
- Nexus: Add guidance to snapshot the `/nexus-data` PVC regularly, and note that loss of blob storage triggers massive upstream re-downloads
- Add note to store Helm values files in version control so services can be rebuilt from scratch
- For Harbor and SonarQube (optional services): note they also require backup if deployed

**Acceptance Criteria:**
- Phase 3 includes a "Backup Considerations" section covering DefectDojo and Nexus
- A `pg_dump` command or CronJob skeleton is shown for DefectDojo PostgreSQL
- Document states explicitly what is lost if backup is absent
- Helm values version control is mentioned

**Addresses:** Convergent Finding #4

---

### Feature 5: Network Security Guidance

Add a "Network Security" subsection to the Phase 3/K8s section covering the two network convergent findings.

**Changes for NetworkPolicies:**
- Add guidance that default K8s allows all pod-to-pod traffic and that NetworkPolicies are required
- Describe the intent: each namespace (defectdojo, nexus, sonarqube, harbor, trivy-system) should be isolated from application namespaces
- Provide a representative NetworkPolicy snippet (default-deny-ingress pattern) and link to Kubernetes NetworkPolicy docs
- Do NOT expand to full production configs for each service

**Changes for TLS:**
- Add guidance that all services currently use plaintext HTTP; describe cert-manager as the recommended approach
- Note that `trusted-host` and `insecure-registries` directives should be removed once TLS is configured
- Link to cert-manager docs
- Add a note that at minimum, HTTPS should be enforced at the ingress layer

**Acceptance Criteria:**
- A "Network Security" section exists in the Phase 3 or K8s infrastructure section
- Default-deny NetworkPolicy snippet is shown as a starting pattern
- TLS guidance describes the approach and what to configure (not a complete cert-manager installation)
- `insecure-registries` and `trusted-host` configuration notes include a warning about their security implications

**Addresses:** Convergent Findings #5, #6

---

### Feature 6: Monitoring and Alerting Guidance

Add a brief "Operational Monitoring" subsection noting what the security stack itself needs monitored.

**Changes:**
- Add a section noting that the security infrastructure itself is unmonitored by default
- List the minimum alerting targets: Nexus disk usage, DefectDojo import failures, Trivy Operator database staleness, pod CrashLoopBackOff
- Recommend Prometheus + Alertmanager (available via kube-prometheus-stack Helm chart, free/open-source) as the monitoring layer
- Note this is a gap — not part of Phase 1-4, but should be addressed before treating the stack as production-grade

**Acceptance Criteria:**
- A "Monitoring the Security Stack" note exists
- Specific alerting targets are listed (disk, import failures, pod health)
- At least one free/open-source monitoring option is mentioned

**Addresses:** Convergent Finding #9

---

### Feature 7: Version Update Process

Add guidance on keeping tool versions current across pre-commit and GitHub Actions.

**Changes:**
- Add a note after the `.pre-commit-config.yaml` template explaining that pinned versions require a maintenance process
- Recommend `pre-commit autoupdate` (built-in command) as the mechanism for updating hook versions
- Recommend Dependabot or Renovate for automating GitHub Actions SHA updates
- Add a recommended cadence (e.g., monthly review)

**Acceptance Criteria:**
- `pre-commit autoupdate` is mentioned with its purpose explained
- Dependabot or Renovate is mentioned for GitHub Actions
- A maintenance cadence recommendation is present

**Addresses:** Convergent Finding #10

---

### Feature 8: Nexus Configuration Honesty

Update the Nexus section to accurately reflect what the configuration does and does not do.

**Changes:**
- Replace "Controls what enters your supply chain" with accurate framing: Nexus provides a single audit point and caching layer, but does not scan content by default — scanning is handled by Grype and Trivy
- Add a note about `contentMaxAge: -1` — this caches packages indefinitely; document the tradeoff (stable builds vs. stale packages)
- Add a note on dependency confusion risk: when using group repositories, order matters (hosted before proxy); add explicit ordering guidance

**Acceptance Criteria:**
- The "Controls what enters your supply chain" claim is corrected or qualified
- `contentMaxAge: -1` is explained with its tradeoff
- Group repository ordering guidance is present (hosted before proxy for dependency confusion protection)

**Addresses:** Convergent Finding #7

---

### Feature 9: Pre-commit Bypass Warning

Add a warning to the pre-commit section about client-side enforcement limitations.

**Changes:**
- Add a note that `git commit --no-verify` and `git push --no-verify` bypass all pre-commit hooks including Gitleaks
- Clarify that the CI/CD gate (Phase 2) is the compensating control — Gitleaks also runs in CI against full history
- Add note that server-side enforcement (branch protection + required CI checks) is the only mechanism that cannot be bypassed by the developer

**Acceptance Criteria:**
- A bypass warning is present in the pre-commit section
- The CI/CD layer is explicitly identified as the compensating control
- The note does not discourage use of pre-commit — frames it correctly as defense in depth

**Addresses:** Convergent Finding #12

---

### Feature 10: DefectDojo API Token Security

Update all DefectDojo import script examples to use environment variables and GitHub Secrets syntax.

**Changes:**
- Replace `DD_TOKEN="your-token"` with `DD_TOKEN="${DEFECTDOJO_API_TOKEN}"` in bash script examples
- In the GitHub Actions workflow sections, replace any plaintext token references with `${{ secrets.DEFECTDOJO_API_TOKEN }}`
- Add a setup note: "Store your DefectDojo API token as a GitHub Actions secret named `DEFECTDOJO_API_TOKEN`" with brief instructions
- Apply the same treatment to Nexus credentials in the REST API setup examples (`NEXUS_AUTH`)

**Acceptance Criteria:**
- No plaintext token values appear in any script or workflow example
- GitHub Secrets syntax is used in all workflow examples
- Environment variable names are consistent across all examples
- A secrets setup instruction is present

**Addresses:** Convergent Finding #14

---

### Feature 11: Alert Fatigue and Triage Guidance

Add practical guidance on managing finding volume for a single developer.

**Changes:**
- Add a "Managing Finding Volume" subsection in Phase 3 (DefectDojo setup)
- Recommend using `checkov --create-baseline` to suppress pre-existing IaC findings on first run
- Recommend configuring DefectDojo deduplication rules explicitly
- Recommend setting a weekly time-boxed triage cadence rather than triaging every finding immediately
- Note that INFO/LOW severity auto-close rules reduce noise
- Frame this as: the stack generates findings faster than it can be triaged; a triage SOP is required for sustainability

**Acceptance Criteria:**
- A "Managing Finding Volume" section exists in Phase 3
- `checkov --create-baseline` workflow is mentioned (it already exists in the doc — ensure it's prominent)
- DefectDojo deduplication and severity filtering guidance is present
- Triage cadence recommendation is present

**Addresses:** Convergent Finding #15

---

### Feature 12: Security Hardening Notes Section

Add a new section at the end of the document summarizing all changes made in response to the red-team findings.

**Format:**
- Brief intro: "This document was updated following an independent red-team analysis..."
- A table or list of changes made, with a one-line rationale for each
- Reference to `red-team/00-consolidated-findings.md` for full analysis

**Acceptance Criteria:**
- Section exists and is clearly marked as post-red-team additions
- All 11 feature changes are represented
- Rationale is brief and actionable (not a repeat of the red-team reports)

---

### Feature 13: Known Gaps and Out-of-Scope Section

Add a section documenting security domains not covered by this stack.

**Domains to document:**
- DAST (no dynamic testing of running applications)
- RASP/WAF (no runtime protection or web application firewall)
- Logging, monitoring, and alerting for the security stack itself (partially addressed by Feature 6, but a full SIEM is out of scope)
- Incident response procedures
- Code and image signing / SLSA provenance
- Full Kubernetes RBAC hardening and Pod Security Standards
- Cross-file dataflow SAST (Semgrep CE limitation)
- License compliance scanning (Trivy has `--scanners license` but it is not configured)

**For each gap, briefly note:** what the gap is, why it is out of scope (cost, complexity, single-developer sustainability), and whether a free option exists that could be added later.

**Acceptance Criteria:**
- Section exists with all 8 domains listed
- Each entry has a one-line "why out of scope" rationale
- At least 3 entries note a free option for future consideration

---

### Feature 14: ADR.md — Architectural Decision Records

Create `ADR.md` at the project root documenting decisions that changed as a result of the red-team findings.

**ADR format per record:**
```
## ADR-NNN: [Title]
**Status:** Superseded / Accepted / Deprecated
**Date:** YYYY-MM-DD
**Context:** What the original decision was and why it was made
**Decision:** What changed and why
**Consequences:** What the change improves, what tradeoffs are accepted
```

**ADRs to write (one per changed decision):**
1. Remove `continue-on-error: true` from scanner steps
2. Make branch protection a required Phase 2 deliverable
3. Enable container scanning on pull_request events
4. Pin GitHub Actions to SHA digests
5. Replace plaintext tokens with GitHub Secrets
6. Pin DefectDojo to a specific version tag
7. Store Helm values in version-controlled files
8. Add NetworkPolicy guidance to K8s deployment
9. Add TLS guidance to K8s deployment
10. Correct Nexus "controls supply chain" framing
11. Add pre-commit bypass warning
12. Add backup guidance for stateful services

**Acceptance Criteria:**
- `ADR.md` exists at project root
- One ADR record per decision listed above
- Each ADR has all four fields populated (Context, Decision, Consequences)
- ADRs are numbered sequentially (ADR-001 through ADR-012)

---

## Summary

| # | Feature | Findings Addressed |
|---|---------|-------------------|
| 1 | GitHub Actions Workflow Hardening | #1, #3, #11, #14 |
| 2 | Branch Protection Required | #2 |
| 3 | DefectDojo Deployment Hardening | #8 |
| 4 | Backup Guidance | #4 |
| 5 | Network Security Guidance | #5, #6 |
| 6 | Monitoring Guidance | #9 |
| 7 | Version Update Process | #10 |
| 8 | Nexus Configuration Honesty | #7 |
| 9 | Pre-commit Bypass Warning | #12 |
| 10 | DefectDojo Token Security | #14 (shared with F1) |
| 11 | Alert Fatigue / Triage Guidance | #15 |
| 12 | Security Hardening Notes Section | — |
| 13 | Known Gaps Section | #13 (DAST) + others |
| 14 | ADR.md | All changed decisions |

**Total convergent findings addressed: 15/15**
