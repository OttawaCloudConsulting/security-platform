# ADR-010: Correct Nexus Supply Chain Control Framing

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #7

## Context

The original Nexus section included the following bullet point describing Nexus capabilities: "Controls what enters your supply chain — configure Nexus to only serve vetted/approved packages." The actual configuration provided in the document is a transparent caching proxy: proxy repositories for npm, PyPI, Docker, and Helm that pass all upstream traffic through to the package manager client, caching results locally. No content selector configuration was described. No allowlist or blocklist was configured. No scanning was performed by Nexus itself (scanning is handled by Grype and Trivy). The `contentMaxAge: -1` setting cached packages indefinitely. Group repository ordering — which determines whether a hosted (internal) repository is checked before a public proxy repository, a critical dependency confusion protection — was not addressed. Agent 1 and Agent 3 both identified the "Controls what enters your supply chain" claim as creating false confidence: a compromised upstream package flows through Nexus unmodified, gets cached indefinitely, and is served to all developers who install that dependency.

## Decision

The "Controls what enters your supply chain" bullet is replaced with accurate framing: Nexus provides a single audit and caching point, but does not scan content by default — scanning is handled by Grype and Trivy at the CI/CD layer. An explicit note is added that content control (allowlisting, blocklisting) requires additional Nexus content selector and repository blocking configuration beyond the defaults described in this blueprint. Group repository ordering guidance is added explaining that hosted (internal) repositories must be ordered before proxy repositories in any group repository configuration to protect against dependency confusion attacks.

## Consequences

**Improved:** The document no longer creates false confidence that Nexus enforces supply chain policy out of the box. Implementers understand what they actually have (a caching proxy with a single audit point) versus what they would need to add (content policies) to enforce supply chain control.

**Tradeoff:** The Nexus section is less compelling as a marketing description of the tool's potential. This is the correct tradeoff: accurate documentation of what is configured matters more than aspirational capability descriptions.
