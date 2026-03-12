# ADR-003: Enable Container Scanning on Pull Request Events

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #3

## Context

The container scanning job in `security.yml` included an explicit event gate: `if: github.event_name == 'push'`. This meant the Trivy container scan ran only on direct pushes to `main` — never on pull requests. The job used `aquasecurity/trivy-action@master` against a freshly built image (`app:${{ github.sha }}`). The PR trigger, which the document explicitly described as "the primary security gate" where results are "surfaced to the developer and reviewer before merge," had a complete blind spot for container image vulnerabilities. A Dockerfile pulling a critically vulnerable base image would pass the PR with no container scan result presented to the reviewer. Container vulnerabilities were first surfaced post-merge, defeating the stated purpose of the PR gate.

## Decision

The `if: github.event_name == 'push'` condition is removed from the container job. The container scan now runs on both `pull_request` and `push` events, consistent with all other scanner jobs in the workflow.

## Consequences

**Improved:** PR reviewers see container vulnerability findings before approving a merge. Container security posture is part of the PR gate, not an after-the-fact post-merge discovery.

**Tradeoff:** PR build times increase slightly on repositories that have a Dockerfile present, due to the added `docker build` and Trivy scan step. Docker layer caching can mitigate this if build time becomes a concern.
