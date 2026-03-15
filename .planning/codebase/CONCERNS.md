# Codebase Concerns

**Analysis Date:** 2026-03-15

## Tech Debt

**CI/CD gate bypass via `continue-on-error: true`:**
- Issue: All scanner steps in GitHub Actions use `continue-on-error: true`, meaning the workflow always reports "passed" regardless of findings
- Why: Initial setup prioritized getting scanners running over enforcement
- Impact: Security scanners operate in advisory mode only — no enforcement points exist
- Fix approach: ADR-001 accepted — remove `continue-on-error: true` from scanner steps
- ADR: `docs/adr/adr001-remove-continue-on-error.md`

**Nexus framed as security boundary but configured as transparent cache:**
- Issue: Document claims Nexus "Controls what enters your supply chain" but actual config is a transparent caching proxy with no content policy, allowlisting, or scanning
- Why: Aspirational framing during initial documentation
- Impact: Compromised upstream packages flow through unmodified and unscanned; `contentMaxAge: -1` caches them indefinitely
- Fix approach: ADR-010 accepted — correct framing to reflect actual capability (caching proxy, not security boundary)
- ADR: `docs/adr/adr010-correct-nexus-framing.md`

**DefectDojo pinned to `tag: "latest"`:**
- Issue: Helm install uses `--set tag="latest"`, making deployments non-reproducible
- Why: Convenience during initial setup
- Impact: Pod restart or `helm upgrade` pulls arbitrary version, risking breaking changes or schema migrations
- Fix approach: ADR-006 accepted — pin to specific tested version
- ADR: `docs/adr/adr006-pin-defectdojo-version.md`

**Helm values not version-controlled:**
- Issue: Installation uses inline `--set` flags rather than externalized values files
- Why: Copy-paste convenience in documentation
- Impact: Rebuild from scratch impossible without manually reconstructing Helm parameters
- Fix approach: ADR-007 accepted — externalize to version-controlled values files
- ADR: `docs/adr/adr007-externalize-helm-values.md`

**Pre-commit bypass risk:**
- Issue: `git commit --no-verify` bypasses all pre-commit hooks with no audit trail
- Why: Git built-in behavior, cannot be disabled
- Impact: Developer can skip all security scanning silently
- Fix approach: ADR-011 accepted — add bypass warning documentation and push-event safety net
- ADR: `docs/adr/adr011-precommit-bypass-warning.md`

## Known Bugs

**Container scanning blind spot in PR gate:**
- Symptoms: Trivy container scan only runs on `push` events, not `pull_request`
- Trigger: Any PR with Dockerfile changes — container vulnerabilities not scanned before merge
- Workaround: Post-merge push event catches vulnerabilities (after code is already on main)
- Root cause: `if: github.event_name == 'push'` condition on container scan job
- ADR: `docs/adr/adr003-enable-container-scanning-on-pr.md`

**Mutable GitHub Action references:**
- Symptoms: Actions referenced by tag (e.g., `actions/checkout@v4`) can be force-pushed upstream
- Trigger: Upstream maintainer replaces tag content (supply chain attack vector)
- Workaround: None currently
- Root cause: Tags are mutable Git refs
- ADR: `docs/adr/adr004-pin-actions-to-sha-digest.md`

## Security Considerations

**Branch protection optional, not mandatory:**
- Risk: Anyone with write access can `git push origin main` directly, bypassing all PR-based scanning
- Current mitigation: Push-triggered workflow runs post-facto (after code is on main)
- Recommendations: ADR-002 — make branch protection a required Phase 2 deliverable
- ADR: `docs/adr/adr002-require-branch-protection.md`

**No network segmentation (Kubernetes NetworkPolicies):**
- Risk: Default K8s allows all pod-to-pod communication — compromised pod can reach DefectDojo (vulnerability inventory), Nexus (package cache), SonarQube, Harbor
- Current mitigation: Separate namespaces (no enforcement)
- Recommendations: ADR-008 — add NetworkPolicy guidance for each namespace
- ADR: `docs/adr/adr008-networkpolicy-guidance.md`

**No TLS for internal service communication:**
- Risk: Package manager configs use `http://localhost:8081`, `trusted-host`, `insecure-registries` — enables MITM, credential interception
- Current mitigation: None
- Recommendations: ADR-009 — add TLS guidance, warn on insecure directives
- ADR: `docs/adr/adr009-tls-guidance.md`

**No backup or disaster recovery:**
- Risk: Loss of DefectDojo PostgreSQL, Nexus blob store, SonarQube, or Harbor data with no recovery path
- Current mitigation: None — no backup procedures documented
- Recommendations: ADR-012 — add backup guidance for all stateful services
- ADR: `docs/adr/adr012-backup-guidance.md`

**Plaintext tokens in documentation:**
- Risk: API tokens and credentials shown in plaintext in config examples
- Current mitigation: None
- Recommendations: ADR-005 — replace with environment variables and GitHub Secrets references
- ADR: `docs/adr/adr005-replace-plaintext-tokens.md`

## Fragile Areas

**CI/CD gate logic:**
- Why fragile: Enforcement depends on correct combination of `continue-on-error`, branch protection, and event triggers — any one misconfigured and the gate is open
- Common failures: Silent pass on scanner failure, post-merge-only detection
- Safe modification: Change one scanner at a time, verify gate blocks a known-bad PR
- Related ADRs: ADR-001, ADR-002, ADR-003

**Kubernetes deployment configs:**
- Why fragile: Inline Helm `--set` flags, `latest` tags, no values files — changes are hard to track and reproduce
- Common failures: Unexpected version upgrades on pod restart, lost configuration
- Safe modification: Externalize to values files first (ADR-007), then modify values
- Related ADRs: ADR-006, ADR-007, ADR-008

**Supply chain management (Nexus):**
- Why fragile: Framed as security control but operating as transparent cache — false confidence
- Common failures: Caching and serving compromised packages indefinitely
- Safe modification: Update documentation framing first (ADR-010), then add actual controls
- Related ADR: ADR-010

## Scaling Limits

**Single-developer alert fatigue:**
- Current capacity: One developer managing 30-40 security components
- Limit: No automated triage or deduplication — every finding requires manual review
- Symptoms at limit: Findings ignored, dashboards unchecked, scanner failures unnoticed
- Scaling path: Milestone-plan phase 4 (DefectDojo triage workflows), automated alerting

**Tool version tracking burden:**
- Current capacity: Manual tracking of versions for all scanners, K8s components, Helm charts
- Limit: Version rot — tools fall behind, CVE databases go stale
- Symptoms at limit: False negatives from outdated scanners, compatibility breaks
- Scaling path: Dependabot/Renovate for action versions, pinned but tracked Helm chart versions

## Coverage Gaps

**DAST completely absent:**
- Problem: No dynamic application security testing in the stack
- Current workaround: None
- Blocks: Runtime vulnerability detection for web applications

**No runtime protection (RASP/WAF):**
- Problem: No Falco, no WAF, no runtime anomaly detection
- Current workaround: None
- Fix approach: ADR-013 accepted — add Falco CE + FalcoSidekick for K8s runtime detection
- ADR: `docs/adr/adr013-falco-runtime-detection.md`

**No code/image signing or provenance:**
- Problem: No cryptographic verification of artifacts
- Current workaround: None
- Fix approach: ADR-014 accepted — add Cosign keyless signing + SLSA provenance + Kyverno admission
- ADR: `docs/adr/adr014-cosign-slsa-kyverno.md`

**Semgrep CE limited to intra-file analysis:**
- Problem: Community Edition cannot perform cross-file or dataflow analysis
- Current workaround: SonarQube provides some cross-file analysis
- Blocks: Detecting taint flows across module boundaries

**No monitoring/alerting for security stack itself:**
- Problem: No Prometheus, Grafana, or alerting for security infrastructure health
- Current workaround: Manual checking
- Impact: Security tools that silently fail provide dangerous illusion of coverage

## Test Coverage Gaps

**CI/CD gate failure behavior untested:**
- What's not tested: Whether the gate actually blocks a known-bad PR
- Risk: Gate may silently pass malicious code (has been the case with `continue-on-error`)
- Priority: High
- Difficulty to test: Requires test PR with known vulnerabilities

**Disaster recovery untested:**
- What's not tested: Backup restore procedures for any stateful service
- Risk: Data loss with no recovery path
- Priority: High
- Difficulty to test: Requires backup infrastructure to exist first

**Supply chain compromise scenario untested:**
- What's not tested: Whether Nexus would detect/block a compromised upstream package
- Risk: Poisoned packages cached and served indefinitely
- Priority: High
- Difficulty to test: Need test scenario with known-bad package

---

*Concerns audit: 2026-03-15*
*Update as issues are fixed or new ones discovered*
