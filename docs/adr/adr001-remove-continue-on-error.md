# ADR-001: Remove `continue-on-error: true` from Scanner Steps

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #1

## Context

Every scanner execution step in the original `security.yml` workflow carried `continue-on-error: true`. This applied to the Semgrep SAST run, the Checkov IaC scan, the Grype SCA scan, and the Gitleaks secrets scan — all four carried this flag. The consequence is that the GitHub Actions workflow always reported a green status check regardless of what scanners found or whether they succeeded at all. The document described this as "the primary security gate," but the gate was structurally incapable of blocking any merge. All three red-team agents identified this independently: Agent 1 framed it as an attack enabler (a PR only needed reviewer approval), Agent 2 framed it as an operational masking problem (scanner crashes and tooling failures were silently swallowed), and Agent 3 identified it as the reason the entire architecture contained zero enforcement points.

## Decision

`continue-on-error: true` is removed from all scanner execution steps. Severity-based failure flags are added to each scanner command (e.g., `grype dir:. --fail-on high`, `semgrep --error` for high/critical severity). `continue-on-error: true` is retained only on SARIF upload steps and artifact upload steps, where a failure should not block a merge — those steps are reporting infrastructure, not enforcement.

## Consequences

**Improved:** The CI security gate becomes blocking. PRs that introduce high-severity findings or trigger scanner errors will fail the workflow and require developer action or explicit risk acceptance before merge.

**Tradeoff:** PR pipelines can now fail on legitimate security findings. Developers must either remediate findings, configure a suppression baseline (e.g., `checkov --create-baseline`), or accept risk explicitly — the workflow no longer silently passes for them.
