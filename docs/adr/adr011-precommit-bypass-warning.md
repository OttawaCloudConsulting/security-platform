# ADR-011: Add Pre-commit Bypass Warning

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #12

## Context

The original pre-commit section described Gitleaks as the Tier 2 secrets gate running before every push, framed as a meaningful security control for preventing secrets from reaching a remote repository. The document did not acknowledge that `git commit --no-verify` and `git push --no-verify` bypass all pre-commit and pre-push hooks entirely, including Gitleaks, with a single command-line flag requiring no special permissions. The entire pre-commit framework runs on the developer's workstation with no server-side component. Agent 1 identified this as a complete bypass of the pre-commit secrets gate. Agent 3 noted that the Developer Workstation trust zone was fully trusted with zero enforcement points — the architecture had no server-side mechanism to compensate for client-side bypass.

## Decision

An explicit bypass warning is added to the pre-commit section noting that `git commit --no-verify` and `git push --no-verify` bypass all hooks, including Gitleaks. The CI/CD layer (Phase 2) is explicitly identified as the compensating server-side control: Gitleaks also runs in the GitHub Actions workflow against the full git history on every PR and push, and this execution cannot be bypassed from the client side. The warning frames pre-commit as defense-in-depth that catches secrets before they reach the remote, not as the sole secrets enforcement mechanism. Branch protection combined with required CI status checks is identified as the only mechanism that cannot be bypassed client-side.

## Consequences

**Improved:** Readers have an accurate mental model of the pre-commit layer's security properties and its limitations. The CI/CD layer's role as the non-bypassable compensating control is made explicit.

**Tradeoff:** None. The warning adds accurate context without changing any tooling, removing any capability, or increasing operational burden.
