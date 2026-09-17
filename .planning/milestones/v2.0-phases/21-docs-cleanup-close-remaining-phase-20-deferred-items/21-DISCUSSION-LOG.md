# Phase 21: Docs cleanup — close remaining Phase 20 deferred items - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-15
**Phase:** 21-docs-cleanup-close-remaining-phase-20-deferred-items
**Areas discussed:** Roadmap goal accuracy (# v4 item), Grype fix scope, Grype replacement wording, SARIF ceiling placement, SARIF ceiling number verification

---

## Roadmap goal accuracy — "7 stale # v4" item

Verified against live `docs/development-security-stack-option-1.md` before presenting options:
the 7 `actions/checkout@<SHA> # v4` comments cited by ROADMAP.md's Phase 21 goal were already
fixed to `# v7` in Phase 20.1 (deferred-items.md item #7, CLOSED). Only 3 `# v4` comments remain,
on `github/codeql-action/upload-sarif`, matching the live pin (`v4.38.0`) — not stale.

| Option | Description | Selected |
|--------|-------------|----------|
| Drop it | Treat as already fixed; Phase 21 covers only the Grype and SARIF-limits items | ✓ |
| Repurpose | Redefine as normalizing codeql-action `# v4` → `# v4.38.0` granularity per ADR-004 | |
| Investigate further | Defer decision to research phase re-verification | |

**User's choice:** Drop it.
**Notes:** No code/doc change needed for this item; recorded in CONTEXT.md `<domain>` so downstream
agents don't re-open it.

---

## Grype fix scope (milestone-2-cicd-gate.md)

| Option | Description | Selected |
|--------|-------------|----------|
| All 5 occurrences | Fix L16, L33, L43, L78, L85 for full doc consistency | ✓ |
| Just L78 | Literal deferred-item citation only, leaves 4 other mentions inconsistent | |

**User's choice:** All 5 occurrences.

---

## Grype replacement wording

| Option | Description | Selected |
|--------|-------------|----------|
| Match live job exactly | "Trivy filesystem, npm audit, pip-audit, tflint"; `sca-results.json`; drop "Anchore Grype" from DefectDojo row | ✓ |
| Generic "SCA" label | Replace with generic "SCA scan" wording, less precise | |

**User's choice:** Match live job exactly.

---

## SARIF size/result ceiling doc placement

| Option | Description | Selected |
|--------|-------------|----------|
| New subsection near §6 First Run | Add where SARIF/artifact counts are already discussed | ✓ |
| §12 Troubleshooting | Frame as a thing to watch for at scale | |
| Both | Short mention in §6 plus troubleshooting entry in §12 | |

**User's choice:** New subsection near §6 First Run.

---

## SARIF limit numbers verification

deferred-items.md #6 cites 10 MB gzipped/file, 20 runs/file, 25,000 results/run, 25,000 rules/run
with no live citation.

| Option | Description | Selected |
|--------|-------------|----------|
| Verify via research phase | Flag for gsd-phase-researcher to confirm against current GitHub docs | ✓ |
| Use as-is | Trust deferred-items.md numbers, write directly | |

**User's choice:** Verify via research phase.

---

## Claude's Discretion

- Exact wording/formatting of the new adoption-guide.md subsection (heading level, list vs. prose).
- Whether the milestone-plan M2-F1 feature-table cell needs rewording beyond the tool-list swap.

## Deferred Ideas

- Blueprint's own Grype-based SCA job example (`docs/development-security-stack-option-1.md`,
  multiple locations) — deferred-items.md #2, explicitly out of scope (unbounded blueprint change).
- Blueprint's `push: branches: [main]` trigger divergence — deferred-items.md #3, no current owner.
- Broken relative ADR links in the blueprint doc — carried forward from Phase 16/17, no owner.
