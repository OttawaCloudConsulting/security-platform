# ADR-009: Add TLS Guidance; Warn on `insecure-registries` and `trusted-host`

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #6

## Context

All internal services in the original document were configured for plaintext HTTP. The pip configuration example set `index-url = http://localhost:8081/repository/pypi-proxy/simple` and `trusted-host = localhost`. The Docker daemon configuration included `"insecure-registries": ["localhost:8081"]`. These directives exist because the services run without TLS, and package managers refuse to communicate with registries over HTTP by default. The `trusted-host` pip directive does not merely permit HTTP — it disables certificate verification entirely for that host. The `insecure-registries` Docker directive similarly bypasses TLS for the specified registry. Agent 1 identified these as enabling MITM package substitution. Agent 2 noted that DefectDojo (which stores API tokens and all vulnerability data) was running over plaintext HTTP. Agent 3 pointed out that in a Kubernetes cluster, any pod with network access can intercept credentials and scan results transmitted in plaintext.

## Decision

A TLS guidance subsection is added alongside the NetworkPolicy guidance in the Phase 3 documentation. It describes cert-manager as the recommended approach for provisioning and renewing certificates for internal services, and links to the cert-manager documentation. The existing `trusted-host` and `insecure-registries` configuration examples are annotated with explicit security warnings explaining what these directives do and stating that they must be removed once TLS is configured on the corresponding service. Full cert-manager installation and per-service TLS configuration is not provided — it is too cluster-specific for a generic blueprint.

## Consequences

**Improved:** Readers are explicitly informed of the security implications of the HTTP-only configuration examples. The document no longer presents `trusted-host` and `insecure-registries` as neutral operational choices. A clear path to remediation (cert-manager) is identified.

**Tradeoff:** Full TLS setup remains the implementer's responsibility. The approach is described and linked, but a complete working configuration is out of scope for this blueprint because it requires cluster-specific CA configuration, ingress controller details, and DNS setup.
