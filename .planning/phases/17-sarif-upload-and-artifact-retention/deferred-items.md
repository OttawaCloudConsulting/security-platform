# Phase 17 — Deferred Items

## Deferred (logged 2026-09-11 during 17-06 execution)

Documentation surfaces this phase deliberately left stale, each with an owner. Where the plan named an
owning phase, it is marked **(plan)**; where it did not, the owner was **assigned by 17-06** from
`.planning/ROADMAP.md` Phase 19/20 scope and should not be read as a prior decision.

| # | Deferred item | Why it is not fixed here | Owner |
|---|---|---|---|
| 1 | `repos/security-platform/cicd/.github/workflows/security.yml` — the mirror/template copy of the scanning workflow, stale since 16-04 | Phase 17 touched only the live root `.github/` workflows. Note it already carries a `security-events: write` line at L17 that the live workflow was missing until 17-01 — the template drifted *ahead* in one place and behind in others, so reconciling it is a rewrite, not a patch | Phase 20 / DIST-06 **(plan)** |
| 2 | The blueprint's Grype-based `sca:` job example in `docs/development-security-stack-option-1.md` | Pre-existing drift: the live pipeline's SCA job runs Trivy filesystem plus npm audit, pip-audit and tflint, and emits `sca-results`, not `grype-results`. Rewriting the example is an unbounded blueprint change and this plan's stated failure mode | Phase 20 / DIST-06 — assigned by 17-06 |
| 3 | The blueprint example's own `push: branches: [main]` trigger | It diverges from the live workflow's D-02 `pull_request`-only policy. Flagged, **not changed**: D-02 governs the live workflow, and the blueprint's safety-net rationale is a separate editorial decision. Revisiting the trigger is already deferred to Phase 19 by ADR-016 | Phase 19 / VAL-01 — assigned by 17-06 |
| 4 | `docs/milestone-plan/milestone-2-cicd-gate.md` M2-F3, line 78 — lists `grype-results.json` among the JSON outputs | Same drift as #2, on a different surface. Out of this plan's file scope | Phase 20 / DIST-06 — assigned by 17-06 |
| 5 | The private-repo GitHub Code Security licence limitation | Code scanning SARIF upload is free on this **public** repo; a private consumer repo needs a paid licence or must fall back to the artifact set alone. Recorded in ADR-016's Consequences, but adoption docs must say it before a consumer commits | Phase 20 / DIST-08 **(plan)** |
| 6 | SARIF size and result limits at consumer scale — 10 MB gzipped per file, 20 runs per file, 25,000 results per run, 25,000 rules per run | Fixture-scale here (largest run: 56 results). A consumer repo running Semgrep `p/default` or a large image scan can plausibly exceed 25,000 results, and the upload would be rejected | Phase 20 **(plan)** |
| 7 | The blueprint's seven `actions/checkout@<SHA>  # v4` version comments | The product repo pinned checkout v7.0.0 in Phase 14. 17-06's scope was the `upload-sarif` and `upload-artifact` comments (the two actions this phase actually changed); sweeping every action comment is a separate docs-hygiene pass | Phase 20 / DIST-06 — assigned by 17-06 |

## Carried forward from Phase 16, still open

- **Broken relative links in `docs/development-security-stack-option-1.md`** — the ADR-011 link at ~L1427
  reads `docs/adr/adr011-…`, which resolves to `docs/docs/adr/…` because the blueprint itself lives under
  `docs/`. 17-06's new ADR-016 link uses the working form `adr/adr016-…md`, matching 16-06's precedent
  rather than copying the stale style. A docs-hygiene sweep of all relative links is still owed, along with
  CLAUDE.md's description of the blueprint as living at the repo root.

## Observed, not caused by this phase

- The outer repo's working tree carries uncommitted modifications across `.claude/` (agents, commands,
  `get-shit-done/` and hooks) from a GSD tooling update that predates this phase — visible in `git status`
  at the start of 17-06 and untouched by it. Both 17-06 commits were staged file-by-file so none of it was
  swept in. Committing or reverting that tooling change is a maintenance decision for the user, not a
  phase deliverable.
