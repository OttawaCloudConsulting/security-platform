---
phase: 23-nexus-generic-chart
plan: 07
subsystem: infra
tags: [adr, documentation, nexus, helm, eula, supply-chain, renovate, scope]

# Dependency graph
requires:
  - phase: 23-nexus-generic-chart
    plan: 06
    provides: "the measured Checkov delta (14 -> 14, exit 1 -> 1, helm v3.22.0 inside checkov:3.3.17) and the second live-smoke green that ADR-020 cites instead of recalling"
  - phase: 23-nexus-generic-chart
    plan: 04
    provides: "the provisioning hook Job and the four 201/204 proxy upserts the ADR records as the NEXUS-01 evidence"
  - phase: 23-nexus-generic-chart
    plan: 03
    provides: "values.yaml — eula.accepted: false, the null rootPassword.secret, the null helm remoteUrl, and the storageClass-by-omission the ADR records as decisions"
provides:
  - "docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md — the phase's decision record: why no Sonatype-published chart was usable, why the community stevehipwell/nexus3 5.26.0 chart is wrapped, why the EULA is opt-in, and why the Helm proxy remote ships unset"
  - "The ONLY written disposition of 23-RESEARCH.md Open Question Q3 (Renovate vs Dependabot for subchart pin freshness): deferred as a repository-wide decision, Chart.lock is the control point"
  - "A `## What was NOT verified` section that carries A5 (docker pull through the proxy), A6 (ArgoCD hook mapping), A8 (ArgoCD subchart resolution), the A3 outcome (CI Checkov scans the chart ZERO times, 24 latent findings) and the unresolved provision.readiness.* knobs"
  - "CLAUDE.md §What This Repository Is now names security-platform as the host of K8s packages (`kubernetes/<service>/` Helm charts), not only the Phase 2 CI workflow (D-02)"
  - ".planning/phases/23-nexus-generic-chart/deferred-items.md — four out-of-scope items, including the stale 'ADR-001 through ADR-018' range this plan was forbidden to fix"
affects: [23-08, phase-24-nexus-hardening, phase-25-argocd]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "An ADR's `## What was NOT verified` opens with a what-WAS-measured sentence, so a later reader cannot mistake the absence of a claim for the absence of evidence (ADR-019's shape, reused)"
    - "A measured-zero scanner result is recorded as a named finding with its latent set quantified, never as 'clean'"
    - "A research Open Question that is deferred gets a named, greppable home in an accepted record (`**Tradeoff — subchart pin freshness.**`) rather than dying in the research file"

key-files:
  created:
    - "docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md"
    - ".planning/phases/23-nexus-generic-chart/deferred-items.md"
  modified:
    - "CLAUDE.md"
    - "docs/adr/README.md"

key-decisions:
  - "The CLAUDE.md edit is ONE line. §Project Structure gained no `kubernetes/` bullet — that section enumerates THIS repository's own directories and `kubernetes/` is not one of them. `git diff --numstat CLAUDE.md` is `1 1`."
  - "The stale `(ADR-001 through ADR-018)` range on CLAUDE.md line 10 was NOT fixed, despite being wrong before this plan started and more wrong after it. The plan's acceptance criterion asserts that no section other than §What This Repository Is is modified; fixing it would have failed that assertion. Logged in deferred-items.md instead."
  - "A3 is dispositioned BOTH ways the plan's text demanded: the measured half (the helm runner engages, Helm v3.22.0 ships in checkov:3.3.17, 14 -> 14 identical set, exit 1 -> 1 without --soft-fail) is named in the what-WAS-measured opener, and the half that REMAINS unverified (the chart's K8s posture as the pipeline sees it, which is nothing) is numbered item 1. The plan's action text said 'move it out of this section' and its acceptance criteria said the numbered list must cover 'the A3 outcome'; splitting the measured fact from the residual gap is the only reading that satisfies both, and it is ADR-019 item 1's own 'NARROWED, not closed' shape."
  - "No markdown table anywhere in ADR-020. The acceptance criterion forbids a table in `## Consequences`; ADR-019 uses none anywhere, and the three candidate charts compare more honestly in prose than in a grid that invites a reader to score columns."
  - "The ADR cites only numbers that appear in 23-06-SUMMARY.md or 23-RESEARCH.md's [VERIFIED] blocks — 403/192 bytes, 204, 318,961 bytes, 410, 201/400/204 on the proxy upserts, 14 -> 14, exit 1 -> 1, 24 latent findings (5 + 19), 40,000 / 100,000, 5.26.0, 3.96.0, 3.64.0. Nothing was recalled."
  - "A fifth `## Context` bullet was added beyond the plan's four, to carry the ADR-007 / ADR-010 references and to state in the record itself that neither file was edited. The plan required the references but did not say where; placing them in Context makes the append-only compliance part of the decision's own text rather than a commit-message claim."
  - "A fifth tradeoff paragraph (`**Tradeoff — the EULA opt-in means a default install downloads nothing.**`) was added beyond the plan's four named ones. The opt-in decision has a real cost — the exact 403 confusion the Context describes, now reached deliberately — and an ADR that records the decision without its cost is the kind of record this phase exists to avoid."
  - "requirements.mark-complete deliberately NOT invoked; requirements-completed: []. NEXUS-01 and NEXUS-03 are in this plan's frontmatter and are now both implemented and recorded, but 23-08 carries them and is the plan that marks them — the 23-01 through 23-06 precedent, recorded in every one of those summaries."

patterns-established:
  - "Before appending a row to an index table, check the file's trailing byte (`tail -c1 file | xxd`) — a missing final newline turns a 1-line append into a 1-added/1-removed diff and silently fails an exact-numstat acceptance criterion"
  - "Run the plan's own `<verify>` one-liner verbatim rather than retyping its greps: the literals it checks contain U+2014, and a hand-typed hyphen passes the eye and fails the file"

requirements-completed: []

# Metrics
duration: 25min
completed: 2026-09-18
---

# Phase 23 Plan 07: Decision Record and Scope Correction Summary

**The chart-base substitution, the EULA opt-in and the unset Helm remote are now an accepted record that cites only measured values — and the one question this phase deferred (Renovate for subchart pin freshness) has a written disposition instead of a silence.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-18T19:15:00Z
- **Completed:** 2026-09-18T19:40:00Z
- **Tasks:** 2 of 2
- **Files modified:** 4 (1 amended, 1 appended, 2 created)

## Accomplishments

- **ADR-020 exists, in ADR-019's house style**: bolded lead clause on every `## Context` and `## Decision` bullet, `## Consequences` as `**Improved:**` and `**Tradeoff — …**` paragraphs with no table, and a `## What was NOT verified` section that opens by naming what WAS measured before listing what was not.
- **23-RESEARCH.md Open Question Q3 is dispositioned** in the `**Tradeoff — subchart pin freshness.**` paragraph — the only place in the repository where it is answered. Dependabot has no Helm chart-dependency manager at all; Renovate's `helmv3` manager does; adopting a second bot is a repository-wide decision this phase has no mandate to make; the gap is **deferred, not dropped**, and `Chart.lock` is the control point until it is taken.
- **CLAUDE.md's scope statement is correct for the first time since Phase 23 started building a chart** — `security-platform` is named as the host of `kubernetes/<service>/` Helm charts as well as the Phase 2 workflows, in one amended sentence, with the two-clause shape and the literal `it does not ship them` intact.
- **The append-only rule held.** `git status --porcelain docs/adr/` reports exactly two entries — the new `adr020-*.md` and the modified `README.md`. ADR-007 and ADR-010 are referenced by number and were not opened for writing.

## Task Commits

1. **Task 1: Correct this repository's scope statement** — `e3e8ac3` (docs)
2. **Task 2: Write ADR-020 and add its index row** — `ba938ac` (docs)

## Files Created/Modified

- `CLAUDE.md` — §What This Repository Is, one sentence: the Phase 2 workflows clause now reads "…together with the K8s packages that implement its Kubernetes infrastructure layer (`kubernetes/<service>/` Helm charts, starting with `kubernetes/nexus/`), live in `OttawaCloudConsulting/security-platform`, not in this repository — this repository documents them, it does not ship them."
- `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md` — **new**, 47 content lines: 5 Context bullets, 6 Decision bullets, 2 `**Improved:**` and 5 `**Tradeoff — …**` paragraphs, 5 numbered `## What was NOT verified` items.
- `docs/adr/README.md` — exactly one appended index row for ADR-020.
- `.planning/phases/23-nexus-generic-chart/deferred-items.md` — **new**, 4 out-of-scope items.

## Verification Evidence

The plan's Task 2 `<verify>` one-liner was executed verbatim (not retyped — its `**Tradeoff — subchart pin freshness.**` literal carries U+2014):

```
VERIFY_RC=0
check-adoption-guide: PASSED 15 / FAILED 0
```

Acceptance criteria, each measured rather than asserted:

| Criterion | Command | Observed |
|---|---|---|
| H1 exact | `head -1` | `# ADR-020: Nexus Chart Base, EULA Opt-In and the Unset Helm Proxy Remote` |
| Context/Decision bullets all bolded | `awk` over the two sections for `^- ` not `^- **` | **0 matches** |
| `**Improved:**` paragraphs | `grep -c` | **2** (criterion: ≥1) |
| `**Tradeoff — ` paragraphs | `grep -c` | **5** (criterion: ≥4) |
| no markdown table | `grep -c '^|'` | **0** |
| freshness paragraph literals | `sed -n '38p' \| grep -cF` each | `Renovate=1 helmv3=1 Dependabot=1 Chart.lock=1 deferred=1` — all five in that one paragraph |
| measured literals | `grep -cF` each | `3.77.0=2 403=3 204=3 318,961=3 410=2 40,000=1 100,000=1 5.26.0=2` |
| numbered NOT-verified items | `grep -c '^[0-9]\. \*\*'` | **5** (A3 outcome, A5, A6, A8, `provision.readiness.*`) |
| ADR dir untouched elsewhere | `git status --porcelain docs/adr/ \| wc -l` | **2** |
| index row exact | `git diff --numstat docs/adr/README.md` | **`1 0`** |
| CLAUDE.md scope-only | `git diff --numstat CLAUDE.md` | **`1 1`**, and `grep -c '^- \`kubernetes/'` is **0** |
| markdownlint | `markdownlint-cli2` on both ADR files | **0 errors** |
| standing gate | `bash scripts/check-adoption-guide.sh` | **exit 0**, 15 passed |
| no accidental deletions | `git diff --diff-filter=D --name-only HEAD~1 HEAD` | empty on both commits |

The `docs/adr/README.md` trailing byte was checked before appending (`tail -c1 … | xxd` → `0a`), because a missing final newline would have produced a `1 1` numstat and failed the exact-`1 0` criterion for a reason invisible in the rendered file.

## Deviations from Plan

### Auto-fixed Issues

None. No bug, no missing critical functionality, no blocking issue. Both tasks' verify blocks passed on first execution.

### Divergences from the plan text (deliberate, with reasons)

**1. A3 is split across the `## What was NOT verified` opener and its numbered list, rather than placed wholly in one.** The plan's action text says "if it was measured, say so and move it out of this section"; its acceptance criteria say the numbered list must cover "the A3 outcome as recorded in `23-06-SUMMARY.md`". 23-06 closed A3 as **MEASURED-ZERO-WITH-A-NAMED-CAUSE** — which is simultaneously a measurement (the helm runner engages; delta is 14 → 14; exit 1 → 1) and a live gap (CI scans the chart zero times; 24 findings are latent). Writing only the measurement would have told a Phase 24 reader the chart is covered. The measurement is therefore named in the opener and the residual gap is numbered item 1, which is the same "NARROWED, not closed" construction ADR-019's own item 1 uses.

**2. Five `## Context` bullets and five `**Tradeoff — …**` paragraphs, where the plan named four of each.** The extra Context bullet carries the ADR-007 / ADR-010 references and states in the record that neither was edited — the plan required the references but left their placement open. The extra tradeoff is `**Tradeoff — the EULA opt-in means a default install downloads nothing.**`: the opt-in's cost is precisely the 403-with-everything-green confusion the Context documents, and recording the decision without it would understate what a consumer walks into. Both are additive; every element the plan named is present.

**3. The stale `(ADR-001 through ADR-018)` range in CLAUDE.md §Project Structure was left wrong.** It was already stale before this plan (ADR-019 landed 2026-09-16) and this plan makes it staler. Fixing it is a two-character edit — and it would have violated the plan's own acceptance criterion that `git diff CLAUDE.md` touches only §What This Repository Is, which exists to keep this edit auditable. Logged as deferred item 1 rather than taken. The same line already says "see `docs/adr/README.md` for index", which is the non-staling form.

**4. `requirements.mark-complete` was not invoked.** NEXUS-01 and NEXUS-03 are in this plan's frontmatter, but 23-08 carries both and is the plan that marks them. Every prior plan in this phase (23-01 through 23-06) withheld on the same grounds and said so. `requirements-completed: []` is withheld on purpose, not an omission.

## Observations Handed Forward

1. **Phase 24 now has a written mandate on the Checkov blind spot, not just a summary note.** ADR-020's item 1 names the three options (accept-and-document, a scanner values file, a committed rendered manifest) and states the one prohibition — do not weaken the `required` guard on `nexus3.rootPassword.secret` to buy coverage. An accepted ADR is a stronger carrier for that prohibition than a plan summary.
2. **The Renovate decision is now owed by the repository, not by this phase.** ADR-020 frames it as a `security-platform`-wide tooling decision. Whoever takes it should note that the same gap covers any future `kubernetes/<service>/` chart, not just Nexus, so the cost of a second bot amortises across the K8s layer rather than being charged to one chart.
3. **`docs/adr/` is now two records past what CLAUDE.md claims it holds.** Any agent that reads CLAUDE.md §Project Structure literally will look for eighteen ADRs and find twenty. The line's own "see `docs/adr/README.md` for index" clause is the correct source; the parenthetical range should be deleted the next time that file is legitimately open for editing.

## Self-Check: PASSED

- `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md` — FOUND
- `docs/adr/README.md` — FOUND, contains `adr020-nexus-chart-base-and-eula-opt-in.md`
- `CLAUDE.md` — FOUND, contains `kubernetes/` and `it does not ship them`
- `.planning/phases/23-nexus-generic-chart/deferred-items.md` — FOUND
- Commit `e3e8ac3` — FOUND in `git log`
- Commit `ba938ac` — FOUND in `git log`
