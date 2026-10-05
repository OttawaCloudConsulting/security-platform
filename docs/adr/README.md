# Architectural Decision Records

Decisions made during the security stack red-team response and subsequent gap closure.

For the full findings that prompted ADR-001 through ADR-012, see [`red-team/00-consolidated-findings.md`](../../red-team/00-consolidated-findings.md).

## Index

| ADR | Title | Date | Status |
| --- | ----- | ---- | ------ |
| [ADR-001](adr001-remove-continue-on-error.md) | Remove `continue-on-error: true` from Scanner Steps | 2026-02-24 | Accepted |
| [ADR-002](adr002-require-branch-protection.md) | Make Branch Protection a Required Phase 2 Deliverable | 2026-02-24 | Accepted |
| [ADR-003](adr003-enable-container-scanning-on-pr.md) | Enable Container Scanning on Pull Request Events | 2026-02-24 | Accepted |
| [ADR-004](adr004-pin-actions-to-sha-digest.md) | Pin GitHub Actions to SHA Digest Placeholder Pattern | 2026-02-24 | Accepted |
| [ADR-005](adr005-replace-plaintext-tokens.md) | Replace Plaintext Tokens with Environment Variables and GitHub Secrets | 2026-02-24 | Accepted |
| [ADR-006](adr006-pin-defectdojo-version.md) | Pin DefectDojo to Specific Version Tag | 2026-02-24 | Accepted |
| [ADR-007](adr007-externalize-helm-values.md) | Externalize Helm Values to Version-Controlled Files | 2026-02-24 | Accepted |
| [ADR-008](adr008-networkpolicy-guidance.md) | Add NetworkPolicy Guidance to Kubernetes Deployment | 2026-02-24 | Accepted |
| [ADR-009](adr009-tls-guidance.md) | Add TLS Guidance; Warn on `insecure-registries` and `trusted-host` | 2026-02-24 | Accepted |
| [ADR-010](adr010-correct-nexus-framing.md) | Correct Nexus Supply Chain Control Framing | 2026-02-24 | Accepted |
| [ADR-011](adr011-precommit-bypass-warning.md) | Add Pre-commit Bypass Warning | 2026-02-24 | Accepted |
| [ADR-012](adr012-backup-guidance.md) | Add Backup Guidance for Stateful Services | 2026-02-24 | Accepted |
| [ADR-013](adr013-falco-runtime-detection.md) | Add Falco CE + FalcoSidekick for Kubernetes Runtime Anomaly Detection | 2026-02-26 | Accepted |
| [ADR-014](adr014-cosign-slsa-kyverno.md) | Add Cosign Keyless Signing + SLSA Provenance + Kyverno Admission Control | 2026-02-26 | Accepted |
| [ADR-015](adr015-tflint-terraform-pin-checking.md) | Adopt tflint for Terraform Provider and Module Pin Checking | 2026-09-11 | Accepted |
| [ADR-016](adr016-sarif-upload-attribution-and-artifact-retention.md) | SARIF Upload Attribution and Scan Artifact Retention | 2026-09-11 | Accepted |
| [ADR-017](adr017-configurable-gate-mode-and-required-checks.md) | Configurable Gate Mode and Required Checks | 2026-09-12 | Accepted |
| [ADR-018](adr018-workflow-packaging-canonical-host-and-versioning.md) | Workflow Packaging, Canonical Host, and Versioning | 2026-09-14 | Accepted |
| [ADR-019](adr019-required-check-enforcement-live-exercise.md) | Required-Check Enforcement, Live-Exercised | 2026-09-16 | Accepted |
| [ADR-020](adr020-nexus-chart-base-and-eula-opt-in.md) | Nexus Chart Base, EULA Opt-In and the Unset Helm Proxy Remote | 2026-09-18 | Accepted |
| [ADR-021](adr021-nexus-anonymous-read-and-workstation-routing.md) | Nexus Anonymous Read and Workstation Routing | 2026-09-20 | Accepted |
| [ADR-022](adr022-nexus-live-validation-via-argocd-overlay.md) | Nexus Live Validation via a Private ArgoCD Overlay | 2026-09-23 | Accepted |
| [ADR-023](adr023-defectdojo-chart-base-tls-guard-and-version-pin.md) | DefectDojo Chart Base, cert-manager Issuer Guard and Pinned Version | 2026-09-24 | Accepted |
| [ADR-024](adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md) | DefectDojo CI Import — Reimport per Branch, Delete on Close, Opt-In | 2026-09-25 | Accepted |
| [ADR-025](adr025-defectdojo-import-https-only.md) | DefectDojo CI Import Refuses Non-HTTPS URLs | 2026-09-25 | Accepted |
| [ADR-026](adr026-defectdojo-dedup-product-wide-and-triage-on-default-branch.md) | DefectDojo Dedup Is Product-Wide and Triage Happens on the Default Branch | 2026-09-26 | Accepted |
| [ADR-027](adr027-defectdojo-homelab-live-validation.md) | DefectDojo Validated Live on the Homelab via an ArgoCD Overlay, an L4 TLS Proxy and a Self-Hosted Import Runner | 2026-09-29 | Accepted |
| [ADR-028](adr028-repo-scoped-arc-runner-for-private-defectdojo-import.md) | A Repository-Scoped actions-runner-controller Scale Set Carries DefectDojo Import to a Private Instance | 2026-09-29 | Accepted |
| [ADR-029](adr029-defectdojo-api-clients-ignore-ambient-curl-config.md) | DefectDojo API Clients Ignore Ambient curl Configuration and Require a Verified TLS Result | 2026-09-30 | Accepted |
| [ADR-030](adr030-standing-chart-gates-fail-closed-and-run-in-ci.md) | Standing Chart Gates Fail Closed and Run in CI | 2026-10-01 | Accepted |
| [ADR-031](adr031-fixed-scan-image-tag-makes-trivy-image-findings-dedupe-across-branches.md) | A Fixed Scan Image Tag Makes trivy-image Findings Dedupe Across Branches and Main Commits | 2026-10-04 | Accepted |
| [ADR-032](adr032-defectdojo-import-sends-verified-false-so-trivy-findings-enter-under-review.md) | The DefectDojo Import Sends verified=false So Trivy Findings Enter Under Review | 2026-10-05 | Accepted |
