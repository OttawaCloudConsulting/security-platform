# Phase 24: Nexus Anonymous Access and Workstation Script - Context

**Gathered:** 2026-09-19
**Status:** Ready for planning
**Source:** Inline Q&A during /gsd:plan-phase (post-research open questions), not full discuss-phase

<domain>
## Phase Boundary

NEXUS-02: enable anonymous pull on Nexus proxy repos (npm/PyPI/Docker/Helm) without exposing write/admin.
NEXUS-04: workstation install script points a target repo's package-manager config at a given Nexus instance.

</domain>

<decisions>
## Implementation Decisions

### Chart default for anonymous access
- `anonymous.enabled` ships **OFF (opt-in)** by default in the Helm chart values. Consumers must explicitly set it to `true` to enable anonymous pull. Document this clearly — safer default than open-by-default.

### Docker scope in the workstation script
- Docker has no per-repo config mechanism (global daemon/registry config only), unlike npm (`.npmrc`, project-scoped), pip (`PIP_CONFIG_FILE`), and Helm (`HELM_REPOSITORY_CONFIG`).
- Script still writes the Docker global config (`~/.docker/daemon.json`), with an explicit warning/doc callout that this change is global and affects all repos on the workstation, not scoped to the target repo like the other three package managers.
- **REQUIREMENTS.md Out-of-Scope row amended** to carve out this Docker exception (previously read "not global workstation defaults" with no exception) — see `.planning/REQUIREMENTS.md` Out of Scope table.
- **Unmeasured (Assumption A3, per PATTERNS.md):** whether a path-routed Nexus Docker proxy repo is even usable as a `registry-mirrors` target in `daemon.json` has not been tested. If it isn't, this decision needs revisiting — flag this to the planner as a task that must validate the mechanism works before committing to the daemon.json approach, and reference ADR-009 for the mandatory warning wording.

### Carried forward from research (RESEARCH.md) — do not re-derive
- Anonymous access requires **two** REST calls: `PUT /service/rest/v1/security/anonymous` (200, idempotent) for npm/PyPI/Helm, PLUS appending `DockerToken` to the active realms list for Docker.
- Realms `PUT` **replaces the whole list** — never omit `NexusAuthenticatingRealm` (locks out admin) and never blind-append without de-duplicating first (API stores duplicate realm entries silently).
- Docker registry path with `pathEnabled: true` is `HOST/<repo>/<image>` — **no `/repository/` segment** (Docker is the only one of the four proxies where this differs).
- Eight existing artefacts assert anonymous access is closed (two are executable gates) — plan must inventory and update these, not just flip the Nexus-side switch.

### Claude's Discretion
- Deferred-item dispositions handed from Phase 23 (readiness knobs, Checkov zero-coverage) — wire through readiness knobs; accept and document Checkov gap.
- ArgoCD overlay value and gitignoring of generated per-repo config files — follow existing repo conventions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research and prior phase
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-RESEARCH.md` — full research findings, confidence table, all 5 open questions
- `docs/adr/ADR-020*.md` — Phase 23 Nexus chart ADR (anonymous-access item flagged "not verified")
- `.planning/phases/23-nexus-generic-chart/` — Phase 23 plans, chart structure this phase extends

</canonical_refs>

<specifics>
## Specific Ideas

None beyond the decisions above — see RESEARCH.md for REST call bodies, status codes, and measured traps.

</specifics>

<deferred>
## Deferred Ideas

- Live cluster validation of anonymous pull end-to-end — that's Phase 25 (Nexus Live Validation), not this phase.

</deferred>

---

*Phase: 24-nexus-anonymous-access-and-workstation-script*
*Context gathered: 2026-09-19 via inline Q&A*
