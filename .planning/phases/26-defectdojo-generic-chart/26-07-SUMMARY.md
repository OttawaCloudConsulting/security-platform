---
phase: 26-defectdojo-generic-chart
plan: 07
subsystem: docs/adr (ADR-023) and requirements traceability
tags: [adr, defectdojo, decision-record, requirements, append-only]
requires:
  - "26-03: chart shape, guard cases, tarball sha256"
  - "26-05: offline gate, live smoke, Checkov measurements"
  - "26-06: PR #19 merge (e097381), operator reply"
  - "Post-merge (orchestrator): PR #20 helm repo add fix (71a112e)"
provides:
  - "ADR-023 (Accepted): DefectDojo chart base, cert-manager issuer guard, pinned version"
  - "ADR index row for ADR-023"
  - "DDOJO-01 Complete in REQUIREMENTS.md"
affects: [27, 29]
tech-stack:
  added: []
  patterns:
    - "ADR with an explicit what-WAS-measured sentence, then numbered NOT-verified items; every number attributed to a SUMMARY, evidence file, RESEARCH [VERIFIED] statement, or labelled as orchestrator-recorded"
key-files:
  created:
    - docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md
    - .planning/phases/26-defectdojo-generic-chart/26-07-SUMMARY.md
  modified:
    - docs/adr/README.md
    - .planning/REQUIREMENTS.md
decisions:
  - "ADR-023 records Phase 26 decisions D-01..D-15 plus the PR #20 install fix; accepted ADRs 006/009/020/021/022 cited, not edited"
  - "PR #17 is recorded as MERGED (measured 2026-09-25T02:46:50Z, 785d807), correcting the orchestrator's 'still open' statement; CI Checkov container is now 3.3.19 per 26-06's description of #17, and 26-05's 3.3.17 CI-equivalent measurement was not repeated"
  - "Nexus README build-only install instruction recorded as a follow-up (likely same gap, not reproduced)"
metrics:
  duration: "~20 min"
  completed: 2026-09-24
  tasks: 2
  files: 3
# backfilled Phase 29.7 (v3.0 audit item 7); closure first recorded under provides
requirements-completed: [DDOJO-01]
---

# Phase 26 Plan 07: ADR-023 and DDOJO-01 Summary

ADR-023 is now in the ADR index as Accepted. It records the DefectDojo chart decisions:

- the wrapper around the official 1.9.53 chart
- the 3.3.200 tag pin with its IMAGE-PIN check
- the `fail` guard for the cert-manager issuer, where the annotation key selects the issuer kind
- pre-created Secrets
- uwsgi sizing
- media left on `emptyDir`

It cites PR #19 (`e097381`) and the follow-up PR #20 (`71a112e`), which fixed the missing `helm repo add`. It lists eight NOT-verified items. DDOJO-01 is now Complete.

Dates use the local clock (EDT), which read 2026-09-24. UTC was already 2026-09-25, the date used in the 26-05 and 26-06 SUMMARYs. The ADR `**Date:**`, the index row and the REQUIREMENTS footer all use 2026-09-24.

## Tasks

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Write ADR-023 | `faebdb1` (combined, see Deviations) | docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md |
| 2 | ADR index row, DDOJO-01 Complete | `faebdb1` | docs/adr/README.md, .planning/REQUIREMENTS.md |

## Verification (measured)

- Task 1 `<automated>` printed `VERIFY1_OK`:
  - Status Accepted, the NOT-verified section present
  - `backup|pg_dump` = 0, `^|` = 0, homelab identifiers = 0
  - `git diff --quiet` clean over ADR-006/009/020/021/022
- The ADR is 215 lines. Acceptance literals it contains: `1.9.53`, `3.3.200`, `cert-manager.io/cluster-issuer`, `existingSecret`, `maxFd`, `emptyDir`, `e097381`, `PR #19`, `PR #20`, `71a112e`. No trailing whitespace (`git diff --cached --check` clean).
- Task 2 checks:
  - `git show --numstat HEAD -- docs/adr/README.md` gives `1	0`.
  - `grep -c 'ADR-023' docs/adr/README.md` gives `1`.
  - DDOJO-01 is `[x]` and `Complete`. DDOJO-02..05 are unchanged (`[ ]` / `Pending`).
- The commit contains exactly the ADR, `docs/adr/README.md` and `.planning/REQUIREMENTS.md` (`git show --name-only`).

### Post-merge facts checked before citing them

- `gh pr view 20`: MERGED at 2026-09-25T02:56:57Z, merge commit `71a112e02bf974f27d8d8778d045be2f89e1b018`. Its parents are `db1adf8` and `e07926f`.
- `git diff --stat e097381 71a112e` changed three files: `.github/workflows/security.yml` (PR #17/#18), `kubernetes/defectdojo/README.md` and `scripts/defectdojo-live-smoke.sh`. There was no change to Chart.yaml, values.yaml or Chart.lock.
- On `origin/main`, the smoke sets `HELM_REPOSITORY_CONFIG` / `HELM_REPOSITORY_CACHE` under `${OUT}` and runs `helm repo add defectdojo`. The README has `helm repo add defectdojo https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts`.
- `origin/main:kubernetes/nexus/README.md` line 144 has `helm dependency build kubernetes/nexus`, with no `helm repo add` in that file. The ADR records this as a follow-up and does not call it verified.
- I did not re-run anything from PR #20's verification: the fresh-copy download, the clean-worktree smoke and the 12/12 CI checks. The ADR attributes those results to the orchestrator.

## Deviations from Plan

1. **[Orchestrator fact corrected by measurement] PR #17 is merged, not open.** The orchestrator said PR #17 was still open. `gh pr view 17` shows state MERGED, mergedAt 2026-09-25T02:46:50Z, merge commit `785d807`. PR #18 merged at 02:47:22Z (`db1adf8`). Both are on `origin/main` before PR #20. The ADR records the measured state:
   - the CI Checkov container moved from 3.3.17 to 3.3.19, as 26-06 describes #17
   - 26-05's CI-equivalent measurement has not been repeated on 3.3.19
   - The workflow comment on `origin/main` line 244 still reads `checkov:3.3.17`, while the action pin is v12.3125.0. I did not measure which container PR #20's CI actually pulled.
2. **[Acceptance extended] PR #20 cited alongside PR #19.** The plan's criteria assumed only PR #19. ADR-023 Decision 11 also cites PR #20: commit `e07926f`, merge `71a112e`, the error text, what changed, and the orchestrator-recorded verification. The PR #19 number and SHA are still present, as required.
3. **[Verify-command defect] `git show --stat HEAD | grep -q adr023` fails even though the ADR is in the commit.** Git shortens the long path to `...ectdojo-chart-base-tls-guard-and-version-pin.md`, so the literal `adr023` is not in the output. `git show --stat=300 HEAD | grep -c adr023` gives `1`, and `git show --name-only` lists the file. The other four checks in that verify passed. I did not change the plan.
4. **[Protocol] One commit for both tasks.** Task 2's verify requires the ADR, the index and REQUIREMENTS in the same HEAD commit, as in the 25-07 precedent. So Task 1 got no separate commit.

## Known Stubs

None.

## Follow-ups

- Nexus chart README install step: add `helm repo add` before `helm dependency build`. Likely the same gap; not reproduced.
- Re-run the CI-equivalent Checkov measurement on the 3.3.19 container, if coverage matters before Phase 29.
- Phase 29: CSRF re-check, live IngressClass/ClusterIssuer check, `initializer.staticName` / resync, Postgres NetworkPolicy on Cilium (ADR-023 NOT-verified items 1-5).

## Self-Check: PASSED

- FOUND: docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md
- FOUND: faebdb1 (docs(26-07): record ADR-023 and close DDOJO-01)
- FOUND: ADR-023 row in docs/adr/README.md; DDOJO-01 `[x]` and `Complete` in .planning/REQUIREMENTS.md
