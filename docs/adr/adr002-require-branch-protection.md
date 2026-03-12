# ADR-002: Make Branch Protection a Required Phase 2 Deliverable

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #2

## Context

The original document listed branch protection as `(Optional)` in the Phase 2 deliverables section: "Branch protection rule configured to require the workflow to pass before merge." Without branch protection, any developer with write access can run `git push origin main` directly, bypassing all PR-triggered scanning entirely. Furthermore, ADR-001's removal of `continue-on-error: true` from scanner steps has no enforcement effect whatsoever without branch protection — a developer can push directly to `main` and the post-push safety-net workflow has no power to prevent the code from landing. Agent 1 identified direct push bypass as a complete circumvention of the PR-based security gate. Agent 3 characterized the combination of optional branch protection and always-green scanner steps as a structural deficiency in which the architecture contained no real enforcement points.

## Decision

Branch protection is promoted from an optional Phase 2 deliverable to a required one. The document now includes explicit GitHub repository settings instructions: require pull requests before merging to `main`, require the security workflow as a passing status check, and block direct pushes to `main`. A warning explains that skipping this step renders the entire CI security gate advisory-only regardless of scanner configuration.

## Consequences

**Improved:** Direct-push bypass is eliminated. Combined with ADR-001, the CI gate now has actual enforcement authority — findings that fail the workflow will block the merge path.

**Tradeoff:** Developers must now open PRs for all changes to `main`; the direct-push shortcut is no longer available. This is a minor workflow change appropriate for any branch that security scanning is intended to protect.
