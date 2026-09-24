# Phase 26: DefectDojo Generic Chart - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-24
**Phase:** 26-defectdojo-generic-chart
**Areas discussed:** Chart base and version pin, Database and Valkey sourcing, Ingress and TLS shape, Secrets and validation depth

Pre-discussion fix: `init.phase-op 26` returned `phase_found: false` because ROADMAP.md had no Phase 26–29 detail sections and STATE.md recorded v3.0 as complete after Phase 25. The operator approved adding the sections and correcting STATE.md (commit `9afbab4`) before the discussion began.

---

## Chart base and version pin

| Option | Description | Selected |
|--------|-------------|----------|
| Wrap official chart | Official DefectDojo chart as Chart.yaml dependency, overridden via values (Nexus precedent) | ✓ |
| Author own templates | Write Deployments/Celery/initializer ourselves | |
| Vendor a copy | Copy upstream chart source and modify | |

**User's choice:** Wrap official chart

| Option | Description | Selected |
|--------|-------------|----------|
| Pin chart + appVersion | Pin subchart and image tag; DB migrations make floating risky | ✓ |
| Pin chart only, float image | Matches Nexus D-08 | |
| Float everything | Latest chart and image | |

**User's choice:** Pin chart + appVersion

| Option | Description | Selected |
|--------|-------------|----------|
| Thin + small footprint | DDOJO-01 essentials plus single replicas / modest resources; rest passthrough | ✓ |
| Thin, upstream defaults | Essentials only, keep upstream replica/resource defaults | |
| Opinionated profile | Also tune Celery/uwsgi/probes | |

**User's choice:** Thin + small footprint

---

## Database and Valkey sourcing

| Option | Description | Selected |
|--------|-------------|----------|
| Bundled default, external override | Subcharts on; documented external DB/Valkey recipe | ✓ |
| Bundled only | Always in-cluster | |
| External required | Subcharts off by default | |

**User's choice:** Bundled default, external override

| Option | Description | Selected |
|--------|-------------|----------|
| Accept + document risk | README/ADR note, no code | |
| Accept silently | Nothing beyond the REQUIREMENTS row | ✓ |
| Add minimal pg_dump CronJob | Scope creep into hardening | |

**User's choice:** Accept silently

| Option | Description | Selected |
|--------|-------------|----------|
| Researcher verifies, then decide | Check image resolution, override only with evidence | |
| Always override to official images | postgres / valkey official images | |
| Take upstream as-is | Accept upstream pins, fix later if broken | ✓ |

**User's choice:** Take upstream as-is

| Option | Description | Selected |
|--------|-------------|----------|
| Postgres PVC on, Valkey ephemeral | Findings persist; broker ephemeral | ✓ |
| Both persistent | PVC for both | |
| Upstream defaults | Whatever subcharts ship | |

**User's choice:** Postgres PVC on, Valkey ephemeral

---

## Ingress and TLS shape

| Option | Description | Selected |
|--------|-------------|----------|
| Ingress on, host required | Render fails without host | |
| Ingress opt-in | Off by default | |
| Ingress on, placeholder host | Default like defectdojo.example.local | ✓ |

**User's choice:** Ingress on, placeholder host

| Option | Description | Selected |
|--------|-------------|----------|
| Issuer annotation, name required | cert-manager ingress-shim, no Certificate template | ✓ |
| Explicit Certificate template | Chart renders Certificate | |
| Both, selectable | Toggle between modes | |

**User's choice:** Issuer annotation, name required

| Option | Description | Selected |
|--------|-------------|----------|
| TLS on, issuer required | Bare install fails fast until issuer set | ✓ |
| TLS opt-in, issuer required when on | Plain HTTP by default | |
| TLS on, placeholder issuer | Renders; cert silently fails if issuer missing | |

**User's choice:** TLS on, issuer required
**Notes:** Asked as a follow-up because the placeholder host plus a required issuer interact: the operator accepted that a bare install fails until an issuer is supplied.

| Option | Description | Selected |
|--------|-------------|----------|
| Unset (cluster default class) | Same pattern as StorageClass | ✓ |
| Default nginx | Hardcode nginx | |
| Required value | Fail render until set | |

**User's choice:** Unset (cluster default class)

---

## Secrets and validation depth

| Option | Description | Selected |
|--------|-------------|----------|
| existingSecret default, generate opt-in | Pre-created (SealedSecret) by default; createSecret flags opt-in | ✓ |
| Generate by default, override allowed | upstream createSecret=true default | |
| existingSecret only | Never generate | |

**User's choice:** existingSecret default, generate opt-in

| Option | Description | Selected |
|--------|-------------|----------|
| Offline gate + kind TLS smoke | Lint/template gate plus kind with ingress-nginx + cert-manager self-signed | ✓ |
| Offline gate only | TLS path unproven until Phase 29 | |
| Kind smoke, no TLS | Pods + HTTP only | |

**User's choice:** Offline gate + kind TLS smoke

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, second helm upgrade pass | Assert secrets stable, initializer safe, login works | |
| No, first install only | Phase 29 covers second sync live | ✓ |

**User's choice:** No, first install only

---

## Claude's Discretion

- Script names, placeholder host string, README structure, small-footprint resource numbers
- `cluster-issuer` vs `issuer` annotation selection mechanism
- ADR-023 authoring and ADR index row

## Deferred Ideas

- Upgrade/resync idempotency pass — Phase 29
- CI Product/Engagement/API token bootstrap — Phase 27
- Homelab ingress controller / ClusterIssuer — Phase 29
- PostgreSQL backup automation — hardening bucket
- Gateway API (HTTPRoute) support — future
