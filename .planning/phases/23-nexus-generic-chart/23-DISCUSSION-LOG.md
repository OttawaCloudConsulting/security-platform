# Phase 23: Nexus Generic Chart - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-17
**Phase:** 23-Nexus Generic Chart
**Areas discussed:** Chart base, Repo location, Proxy repo provisioning, Values schema

---

## Chart base

| Option | Description | Selected |
|--------|-------------|----------|
| Wrap upstream nexus3 | Add sonatype/nexus3 as subchart dependency, override values | ✓ |
| Author from scratch | Full custom templates | |
| Vendor/fork upstream chart | Copy upstream templates into this repo | |

**User's choice:** Wrap upstream nexus3 (recommended)
**Notes:** None.

---

## Repo location

| Option | Description | Selected |
|--------|-------------|----------|
| New repo: nexus-helm-chart | Dedicated public repo | |
| Inside security-platform repo | Add charts/ dir to existing security-platform | (initial framing, later refined) |
| New repo: k8s-charts (shared) | One repo for all v3.0 K8s packages | |
| security-platform, kubernetes/ layout | kubernetes/nexus/, kubernetes/defectdojo/ subdirs in security-platform | ✓ |

**User's choice:** security-platform repo, with a top-level `kubernetes/` directory holding well-named subdirectories (`kubernetes/nexus/` for this phase).
**Notes:** User's first answer ("everything kubernetes related in a kubernetes/ directory, placed into well-named sub-directories") didn't specify which repo — follow-up question resolved it to security-platform.

---

## Proxy repo provisioning

| Option | Description | Selected |
|--------|-------------|----------|
| Helm post-install Job | REST API call after pod ready, idempotent | ✓ |
| Groovy script via ConfigMap | Nexus scripting API (deprecated upstream) | |
| Manual doc step | README instructs manual UI steps | |

**User's choice:** Helm post-install Job (recommended)
**Notes:** Follow-up on upstream URL handling — hardcoded public-registry defaults, but overridable via values.yaml (not fixed, not left blank).

---

## Values schema

| Option | Description | Selected |
|--------|-------------|----------|
| Omit storageClass key by default | Falls back to cluster default automatically | ✓ |
| Explicit empty string "" | Same runtime behavior, more explicit | |

**User's choice:** Omit storageClass key by default (recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Storage size + resources overridable, image tag pinned | Sane defaults, reproducible pin | |
| Everything upstream exposes, nothing pinned | Full pass-through, floating image tag | ✓ |
| Minimal surface — only StorageClass override | Defer tuning to later phase | |

**User's choice:** Everything upstream exposes, nothing pinned
**Notes:** User explicitly chose not to pin the image tag despite the reproducibility tradeoff — captured in CONTEXT.md as D-08 with a flag for researcher/planner to revisit if drift becomes an issue.

---

## Claude's Discretion

None — all four areas resolved to explicit user choices.

## Deferred Ideas

None — discussion stayed within phase scope.
