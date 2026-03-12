# ADR-004: Pin GitHub Actions to SHA Digest Placeholder Pattern

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #11

## Context

The original `security.yml` workflow pinned GitHub Actions to mutable references: `aquasecurity/trivy-action@master` (a mutable branch tip), `bridgecrewio/checkov-action@v12` (a mutable semver tag), `github/codeql-action/upload-sarif@v3` (a mutable semver tag), and `actions/checkout@v4` (a mutable semver tag). Mutable tags can be reassigned by the upstream action author at any time. A compromised action repository, or a maintainer with malicious intent, can push new code to an existing tag and every workflow using that tag will execute the new code on the next run — with access to the repository source, the `GITHUB_TOKEN`, and any secrets the workflow uses (including DefectDojo API tokens). Agent 1 rated this as a supply chain attack vector. Agent 2 noted that a breaking change to `@master` would silently break container scanning and be masked by `continue-on-error: true` (a compounding interaction between two findings).

## Decision

The workflow is updated to show the SHA-pinning pattern with a version comment for readability (e.g., `uses: actions/checkout@<SHA> # v4.x.y`). Because live SHAs go stale as new patch releases are published, the document instructs the reader to look up the current SHA for each action at time of adoption, and to configure Dependabot or Renovate to automate SHA updates going forward. The pattern rather than a specific frozen SHA is documented to remain correct across future versions of the blueprint.

## Consequences

**Improved:** Action pinning to SHA digests makes the workflow immutable to upstream tag reassignment. A compromised action release cannot affect a workflow that pins to the pre-compromise SHA.

**Tradeoff:** SHA references are opaque without the accompanying version comment. Keeping SHAs current requires automation (Dependabot/Renovate) or a monthly manual review cadence. Initial adoption requires a one-time lookup of current SHAs for each action used.
