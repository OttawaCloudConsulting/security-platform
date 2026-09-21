# Phase 25: Nexus Live Validation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-20
**Phase:** 25-nexus-live-validation
**Areas discussed:** Cluster/overlay access model, Overlay content ownership, Validation scope per proxy, Anonymous vs authenticated pull on homelab

---

## Cluster/Overlay Access Model

| Option | Description | Selected |
|--------|-------------|----------|
| You run it, I script it | Claude writes overlay diff/commands; user pastes kubeconfig-gated commands into own terminal at checkpoint gates | |
| Claude gets kubeconfig access | User provides kubeconfig this session can use directly via kubectl/helm | ✓ |
| Hybrid | User handles private overlay push; Claude verifies via kubeconfig or pasted output | |

**User's choice:** Claude gets kubeconfig access — KUBECONFIG env var / default `~/.kube/config`.
**Notes:** Follow-up confirmed kubeconfig source is the standard env var / default path, already set up on this workstation.

---

## Overlay Content Ownership

| Option | Description | Selected |
|--------|-------------|----------|
| Claude gets repo access too | User gives path/URL + credentials for the private overlay repo; Claude clones, writes Application manifest + values, commits/pushes | ✓ |
| You handle the private repo | This repo only produces template/example overlay content; user copies it manually | |

**User's choice:** Claude gets repo access too — path/URL + credentials to be provided at execution time, not during discuss.

**Follow-up — ArgoCD/repo bootstrap status:**

| Option | Description | Selected |
|--------|-------------|----------|
| ArgoCD + private repo already exist | Homelab already runs ArgoCD with an established private overlay pattern; Phase 25 adds a new Application entry + values | ✓ |
| Bootstrapping from scratch | No ArgoCD instance or private repo exists yet; Phase 25 stands these up | |

**User's choice:** Already exist — phase is additive only, follow existing conventions, do not bootstrap.

---

## Validation Scope Per Proxy

| Option | Description | Selected |
|--------|-------------|----------|
| Same as Phase 24's live gates | Real package pull through each proxy + cache-hit verification, matching 24-02/24-05 rigor, now against homelab | ✓ |
| Lighter: one real pull per proxy | Prove each proxy serves a real package once; skip cache-hit re-verification | |

**User's choice:** Same as Phase 24's live gates.

---

## Anonymous vs Authenticated Pull on Homelab

| Option | Description | Selected |
|--------|-------------|----------|
| Anonymous only | Validate NEXUS-02's live proof only; overlay ships anonymous.enabled=true | |
| Both anonymous and authenticated | Validate anonymous pull works AND write/admin still requires auth (negative test) | ✓ |

**User's choice:** Both.

---

## Claude's Discretion

- Exact Application manifest field values (sync policy, namespace naming, etc.) — follow the existing private overlay repo's established pattern for other apps.
- Order of proxy validation (npm/PyPI/Docker/Helm).

## Deferred Ideas

None — discussion stayed within phase scope.
