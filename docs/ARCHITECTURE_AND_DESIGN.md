# Architecture and Design: Security Stack Red-Team Response

## Overview

This document governs the update of `development-security-stack-option-1.md` in response to 15 convergent findings from an independent three-agent red-team analysis. The work is purely documentary — no new software is built. All changes are to Markdown content, code examples, configuration snippets, and YAML within the existing blueprint document.

A companion `ADR.md` captures one record per changed architectural decision.

---

## File Inventory

| File | Change Type | Description |
|------|-------------|-------------|
| `development-security-stack-option-1.md` | Update (inline + append) | All 14 features applied here |
| `ADR.md` | Create | 12 ADR records, one per changed decision |
| `prd.md` | Create | This project's requirements (already created) |
| `docs/ARCHITECTURE_AND_DESIGN.md` | Create | This document |
| `progress.txt` | Create | Feature tracking |

---

## Document Change Strategy

### Inline Changes (Features 1–11)

Inline changes modify existing sections of `development-security-stack-option-1.md` directly. Each change is made in place — the reader sees the corrected configuration without needing to cross-reference an addendum.

**Inline change targets:**

| Section in Document | Change |
|--------------------|--------|
| GitHub Actions workflow (`security.yml`) | Remove `continue-on-error` from scanner steps; add failure thresholds; fix container job trigger; SHA-pin all actions; use `${{ secrets.* }}` |
| Phase 2 deliverables | Promote branch protection to required; add GitHub settings instructions |
| DefectDojo Helm install | Replace `tag="latest"` with pinned version; add `values.yaml` guidance |
| DefectDojo import scripts | Replace `DD_TOKEN="your-token"` with `${{ secrets.DEFECTDOJO_API_TOKEN }}` |
| Nexus section | Correct "Controls what enters your supply chain" claim; explain `contentMaxAge: -1`; add group repo ordering |
| Nexus package manager configs | Add security warning on `insecure-registries` and `trusted-host` |
| Pre-commit section | Add `--no-verify` bypass warning; mention `pre-commit autoupdate` |
| Post-`.pre-commit-config.yaml` | Add version update cadence guidance |

### Append Changes (Features 4–6, 12–13)

New sections appended to the document:

| New Section | Location |
|-------------|----------|
| Backup Considerations | After Phase 3b (DefectDojo) |
| Network Security | After K8s services summary table |
| Monitoring the Security Stack | After Network Security |
| Managing Finding Volume | After Phase 3b (DefectDojo) |
| Security Hardening Notes | End of document (second-to-last) |
| Known Gaps and Out-of-Scope | End of document (last) |

---

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | `continue-on-error: true` removed from scanner steps; retained on upload steps | Scanner failures must fail the workflow to enforce the security gate. Upload failures (SARIF, artifact) should not block merges — they are reporting, not enforcement. |
| 2 | Container job trigger changed to include `pull_request` | PRs are the primary security gate. Container scanning running only post-merge defeats the purpose of PR-level review. |
| 3 | GitHub Actions pinned to SHA placeholder pattern, not live SHAs | Live SHAs go stale. The document shows the pinning pattern with a comment directing the reader to look up the current SHA, plus guidance to use Dependabot/Renovate for automation. This approach stays correct indefinitely. |
| 4 | Branch protection promoted from optional to required | Without it, `continue-on-error` removal has no enforcement effect. A security gate that is always advisory is not a gate. |
| 5 | DefectDojo pinned to specific version, Helm values externalized | `tag="latest"` creates non-reproducible deployments. A pod restart or `helm upgrade` can silently pull a breaking schema change. |
| 6 | Nexus "controls supply chain" claim corrected | The configuration is a transparent caching proxy. Claiming control without content policy or scanning is inaccurate and creates false confidence. |
| 7 | NetworkPolicy and TLS: approach + pointer, not full config | Full production Kubernetes YAML for cert-manager and per-service NetworkPolicies would add 200+ lines of context-specific config that cannot be validated without a target cluster. Approach guidance is universally applicable; full config is not. |
| 8 | DAST: acknowledge only, do not add OWASP ZAP | Adding OWASP ZAP requires a running test environment, which the stack currently does not include. Premature addition would be a non-functional placeholder. Document the gap honestly. |
| 9 | All token examples use environment variables / GitHub Secrets | Plaintext token examples in documentation get copied into real workflows. The example must model secure practice even if it requires slightly more setup to follow. |
| 10 | `pre-commit autoupdate` added as maintenance mechanism | It is a first-party, zero-cost mechanism for keeping hook versions current. Not adding this guidance guarantees version rot. |
| 11 | Group repository ordering guidance added to Nexus | Dependency confusion attacks exploit group repo ordering that resolves public packages before internal ones. This is a configuration note, not a new tool. |
| 12 | Known Gaps section added, not expanded | Honest documentation of uncovered domains prevents false confidence. Adding tools to cover every gap would violate the single-developer sustainability constraint. |

---

## ADR Structure

Each record in `ADR.md` uses the following format:

```
## ADR-NNN: [Title]
**Status:** Accepted | Superseded | Deprecated
**Date:** 2026-02-24
**Context:** [Original decision and why it was made]
**Decision:** [What changed and why]
**Consequences:** [Improvements gained; tradeoffs accepted]
```

ADRs cover the 12 decisions listed in Feature 14 of the PRD, numbered ADR-001 through ADR-012.

---

## Constraint Verification

| Constraint | How Maintained |
|------------|---------------|
| Zero cost | No new tools added; all changes are configuration and documentation |
| No external accounts | GitHub Secrets and branch protection are GitHub repository settings — already in use |
| Self-hosted | No change to hosting model |
| Single-developer sustainability | No changes add maintenance overhead beyond `pre-commit autoupdate` + monthly review |

---

## Out of Scope

| Item | Rationale |
|------|-----------|
| DAST (OWASP ZAP) | Requires running test environment; gap documented instead |
| Full cert-manager TLS installation | Too cluster-specific for a generic blueprint |
| Full NetworkPolicy YAML per service | Same reason; approach guidance provided |
| Findings from individual agents only | Only convergent (multi-agent) findings are in scope |
| Architectural restructuring | 4-phase structure, tool selection, and zero-cost model are preserved |
