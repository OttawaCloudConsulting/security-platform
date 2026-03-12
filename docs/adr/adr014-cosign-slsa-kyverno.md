# ADR-014: Add Cosign Keyless Signing + SLSA Provenance + Kyverno Admission Control

**Status:** Accepted
**Date:** 2026-02-26
**Addresses:** Known Gap — Code and Image Signing / SLSA Provenance

## Context

The previous red-team response documented "Code and Image Signing / SLSA Provenance" as a known gap with this rationale for exclusion: "Signing infrastructure requires a key management strategy — key generation, storage, rotation, and revocation. SLSA Level 2 and above require specific CI/CD build isolation guarantees that involve significant pipeline restructuring."

This rationale was accurate for traditional key-based signing. It does not apply to Sigstore keyless signing, which was explicitly mentioned as a "free option for future consideration."

Keyless Cosign signing (Sigstore Fulcio CA + Rekor transparency log) eliminates the key management objection entirely:

- No private key is generated or stored
- The signing identity is the GitHub Actions OIDC token — ephemeral, scoped to a single job, cryptographically bound to the workflow URL
- No key rotation schedule, no key storage infrastructure, no revocation procedures
- The entire signing workflow is three lines added to an existing GitHub Actions job

The SLSA pipeline restructuring objection was also overstated for Level 2: `slsa-github-generator` implements SLSA Level 2 provenance as a reusable workflow — it requires no structural changes to the existing pipeline, only an additional job declaration.

The remaining gap was admission control: signing images is only useful if unsigned images are blocked from running. Kyverno (mentioned in the "Kubernetes RBAC Hardening" Known Gap section as a future consideration) provides this with its native `verifyImages` rule type — no Rego required, first-class Cosign integration, CNCF Graduated.

## Decision

Three components are added to the stack as required Phase 4 components:

1. **Cosign keyless signing** — A `sign` job is added to `security.yml`, depending on the `container` job. The job runs only on push to `main` (not on PRs, since no image is pushed during PR builds). It uses the GitHub OIDC token via `sigstore/cosign-installer` to sign the pushed image against the Rekor transparency log. No secrets are required beyond the existing `REGISTRY_PASSWORD`.

2. **SLSA Level 2 provenance** — `slsa-framework/slsa-github-generator` generates a signed provenance attestation for each signed image. The attestation links the deployed artifact to a specific commit SHA, repository, and CI workflow run. An image built outside the CI pipeline lacks this attestation and can be blocked by Kyverno.

3. **Kyverno admission controller** — Installed via Helm in the `kyverno` namespace. A `ClusterPolicy` with `verifyImages` rules requires all pods in production and staging namespaces to use images with a valid Cosign attestation matching the GitHub Actions OIDC issuer (`https://token.actions.githubusercontent.com`) and the specific workflow subject. The policy is deployed in `Audit` mode initially; `kubectl get policyreport -A` surfaces violations before switching to `Enforce`.

Optional: commit-level signing via Git SSH signing keys (simpler than GPG, no keyserver infrastructure).

**Why Kyverno over OPA/Gatekeeper:** Kyverno has a native `verifyImages` rule type with first-class Cosign integration. OPA/Gatekeeper requires custom Rego for equivalent functionality. Kyverno is CNCF Graduated. Both are valid choices; Kyverno requires less policy authoring complexity for image verification specifically.

**Why keyless over key-based:** Key-based signing (GPG or long-lived Cosign private keys) requires: key generation, secure storage (e.g., Vault, AWS KMS), rotation procedures, and revocation infrastructure. For a single-developer practice without a secrets management tier in place, this overhead exceeds the benefit. Keyless signing provides equivalent verification guarantees (the signature is tied to a verifiable OIDC identity) without any key management burden.

## Consequences

**Improved:** Every image deployed to production namespaces is verifiably built from a specific commit by the CI pipeline. An attacker who builds a malicious image locally and attempts to deploy it in the cluster will be blocked by Kyverno before the pod starts. SLSA provenance attestations make the build-deploy chain auditable.

**Tradeoff:** The `sign` job adds ~2-3 minutes to the push-to-main workflow (image build, push, sign, SLSA attestation). This is acceptable overhead for a post-merge workflow. Kyverno adds ~512Mi cluster overhead. The `validationFailureAction: Enforce` switch requires an audit period first — applying `Enforce` without auditing will block legitimate workloads if any unsigned images are already in use in production/staging namespaces.
