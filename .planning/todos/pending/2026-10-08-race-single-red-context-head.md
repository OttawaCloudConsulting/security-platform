---
title: Race a closed-PR reopen on a head red on exactly one required context
created: 2026-10-08
source: Phase 29.6 code review (CR-01) and operator ruling amend-keep-pass
priority: high
area: ci-enforcement
---

# Race a closed-PR reopen on a head red on exactly one required context

## Why

Phase 29.6 measured six closed-PR reopen race attempts (variants a and b). All six were refused, so 27-HUMAN-UAT item 3 stays closed (operator ruling `amend-keep-pass`, `evidence/29.6-review-ruling.txt`). Two data from that phase leave a gap:

- **CR-01:** in b1 (Checkov) and b3 (Semgrep) the close run's `skipped` check run became, and stayed, the newest run on a red required context. Those PRs stayed BLOCKED only because each head was red on two contexts and the other red context's newest run was a reopen `failure`.
- **CLOSED/CLEAN:** in a1–a3 the closed PR read `CLOSED` / `CLEAN` / `MERGEABLE` on a red head while the close run's `skipped` runs were newest on all five contexts. The evidence cannot distinguish "newer skipped overrides older failure" from "closed PRs are not evaluated".

A head red on exactly one required context, with the close-suite `skipped` run newest on that context, was never tested. Under the first reading it could merge.

## What to do

- Stand up a new throwaway scratch repo (29.6's was deleted; reuse 29.6-bootstrap.sh / 29.6-pr.sh / 29.6-race.sh / 29.6-verdict.sh).
- Seed a head that is red on exactly one required context (for example a Dockerfile change that trips only Checkov).
- Race variants (a) and (b). For (a), also attempt a merge while the PR reads CLEAN after the close run's skips land, if the API allows a merge request against that state.
- Extend `29.6-verdict.sh` to flag a close-suite `skipped` run that is newest on a red required context (the detection gap CR-01 named).
- Record the outcome as an ADR that supersedes or amends ADR-033's NOT-verified item 12.

## References

- `docs/adr/adr033-closed-pr-reopen-race-does-not-merge-on-skipped-checks.md` (NOT-verified items 5, 6, 12; "Check-run ordering under variant (b)")
- `.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-/29.6-REVIEW.md` (CR-01, Resolution)
- `.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-/evidence/29.6-race-b1/checkruns-final.json`, `29.6-race-b3/checkruns-final.json`, `29.6-race-a*/timeline.jsonl`
