---
phase: 29-defectdojo-live-validation
plan: 06
subsystem: ci-workflows
tags: [defectdojo, github-actions, reusable-workflow, runs-on, arc, security-platform, ddojo-05]
requires:
  - "29-04: DefectDojo PR-lifecycle assertion helper committed on the phase branch"
  - "29-01: homelab live-validation gate committed on the phase branch"
provides:
  - "security-platform main 2fda1ace44fdff510afa7c25b43e23dbe1dc4e2d: jobs defectdojo-import and defectdojo-cleanup use runs-on ${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}"
  - "Standing offline gate: check-workflow-uploads.sh asserts the DefectDojo runs-on shape and that every scan job stays ubuntu-latest"
  - "Corrected defectdojo-import-proof.yml comments (D-10 effect: import runs on ARC, logs SKIP, nothing imported; prove-import can stall if ARC is offline)"
affects: [29-07, 29-12, 29-14, 29-18]
tech-stack:
  added: []
  patterns:
    - "Caller-scoped runner routing: vars.* in a called workflow resolves to the caller repository, with an ubuntu-latest fallback when unset"
    - "Count ${{ expressions with grep -F; ugrep 7.8.4 treats ${{ as a regex interval"
key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml
    - repos/security-platform/.github/workflows/defectdojo-import-proof.yml
    - repos/security-platform/scripts/check-workflow-uploads.sh
decisions:
  - "29-06: PR #24 (PR A) merged to security-platform main as 2fda1ace44fdff510afa7c25b43e23dbe1dc4e2d on 2026-09-27 21:18:28 UTC, head e8387a8, --merge, pinned with --match-head-commit"
  - "29-06: operator decision recorded verbatim: \"Rerun, then merge if green\""
  - "29-06: live main has zero required status checks (ruleset 14243983 rules [deletion, non_fast_forward]); the plan's five required contexts are not live, and frozen job names are enforced offline by FROZEN_JOB_NAMES"
  - "29-06: no tag moved; v1.2.0 and the v1 move stay with plan 29-18 after the live proof"
metrics:
  duration: "~45min (across executor sessions, including the prove-import rerun)"
  completed: 2026-09-27
  tasks: 3
  files: 3
---

# Phase 29 Plan 06: DefectDojo runs-on routing (PR A) Summary

`security.yml` now routes only the two DefectDojo jobs through an optional caller variable, `runs-on: ${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}`. An offline shape assertion guards the change, and it is merged to `security-platform` `main` as `2fda1ace44fdff510afa7c25b43e23dbe1dc4e2d` (PR #24). With the variable unset, which it still is, behaviour is identical to before.

## Tasks

| Task | Name | Commit (security-platform) | Files |
| --- | --- | --- | --- |
| 1 (RED) | Assert DefectDojo runs-on routing shape | `367b315` test(29-06) | scripts/check-workflow-uploads.sh |
| 1 (GREEN) | Route DefectDojo import/cleanup via optional DEFECTDOJO_RUNS_ON | `e8387a8` feat(29-06) | .github/workflows/security.yml, .github/workflows/defectdojo-import-proof.yml |
| 2 | Push branch, open PR A | push only | PR https://github.com/OttawaCloudConsulting/security-platform/pull/24, head `e8387a896ec8eb2125348180b83be5c3392dc2e3` |
| 3 | Operator merge gate, merge, confirm main | merge `2fda1ac` | none (merge only) |

The PR A diff `origin/main...HEAD` before the merge: 5 files, +1966/-14. It also carries the plan 29-01 (`9726b35`) and 29-04 (`32da9f5`) commits.

## RED output (Task 1, unchanged security.yml, rc=1)

```
FAIL: SIDE-CHANNEL-SHAPE: jobs.defectdojo-import.runs-on must be exactly "${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}" (Phase 29 D-09), got 'ubuntu-latest'
FAIL: SIDE-CHANNEL-SHAPE: jobs.defectdojo-cleanup.runs-on must be exactly "${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}" (Phase 29 D-09), got 'ubuntu-latest'
FAILED - 2 check(s)
```

GREEN: actionlint was clean on both workflows, `check-workflow-uploads.sh` gave PASS 19 and `check-defectdojo-chart.sh` gave PASS 22. The negative test used a scratch `WORKFLOWS_DIR` with `jobs.sast.runs-on: self-hosted`, and the JOB-SHAPE check failed with rc=1. Acceptance checks: 2 non-comment expression lines (security.yml lines 1282 and 1677), 5 `runs-on: ubuntu-latest`, no job `name:` changed, empty non-comment diff on the proof file, and `SKIP: DEFECTDOJO_API_TOKEN` appears once, matching security.yml lines 1316 and 1703.

## Proof pre-state

- Run `36350180923` (PR #24): `scans / DefectDojo Import` skipped.
- `gh variable list` returned `[]`, so `DEFECTDOJO_URL` and `DEFECTDOJO_RUNS_ON` are unset. The routing change reached main before either variable was set, which is the ordering this plan requires.

## Merge gate (Task 3)

The operator was shown PR #24: the diff summary, a red `prove-import` at KIND-CELERY-PING exit 69, the earlier identical flake on main (run `36159160216`, followed by the green run `36160366711`), and zero required contexts on main. Operator reply, verbatim:

> Rerun, then merge if green

- The orchestrator ran `gh run rerun 36350180923 --failed`. Attempt 2 completed with conclusion `success`, and `prove-import` passed in 7m26s.
- `gh pr checks 24` showed every check as pass or skipping. Skipping covered only the four DefectDojo Import/Cleanup jobs, which were gated off because the variables are unset. Head was still `e8387a896ec8eb2125348180b83be5c3392dc2e3` and mergeStateStatus was `CLEAN`.
- The merge ran `gh pr merge 24 --merge --match-head-commit e8387a8...`. The merge commit is **`2fda1ace44fdff510afa7c25b43e23dbe1dc4e2d`**, at 2026-09-27T21:18:28Z.

## Post-merge verification

| Check | Result |
| --- | --- |
| `git show origin/main:.github/workflows/security.yml \| grep -nF "${{ vars.DEFECTDOJO_RUNS_ON \|\| 'ubuntu-latest' }}"` | lines 1282 and 1677, 2 non-comment |
| Plan verify (contents API `?ref=main`, comments stripped, `grep -cF "runs-on: ${{ vars.DEFECTDOJO_RUNS_ON \|\| 'ubuntu-latest' }}"`) | `2` |
| `runs-on: ubuntu-latest` on main | `5` (scan jobs unchanged) |
| `origin/main` after fetch | `2fda1ac` |

## Required contexts before and after

| When | Endpoint | Result |
| --- | --- | --- |
| Before | `rules/branches/main` | ruleset 14243983 "Default", rules `[deletion, non_fast_forward]`, 0 `required_status_checks` |
| Before | `branches/main/protection` | 404 "Branch not protected" (expected per set-required-checks.sh lines 62-65) |
| After | `rules/branches/main` | `[deletion, non_fast_forward]`, 0 `required_status_checks` |

The after-state equals the before-state.

## Deviations from Plan

1. **[Rule 1 - plan premise] No live required contexts.** The plan assumed five live required contexts. The live state has none, which matches ADR-017 line 33 (leave unrequired). The acceptance check was reinterpreted as "after equals before", and it holds. The frozen job names are enforced offline by `FROZEN_JOB_NAMES` in `check-workflow-uploads.sh`.
2. **[Rule 3 - tooling] Counts use `grep -F`.** The plan's verify command uses `grep -c` with a `${{` pattern. The local `grep` is ugrep 7.8.4, which parses `${{` as a regex interval, so every count used `grep -F`.
3. **[Operator gate] prove-import flake.** The first `prove-import` run went red at KIND-CELERY-PING (exit 69), the same flake seen earlier on main. The operator chose to rerun and merge if green. The rerun passed.

## Threat model

- T-29-15 (interface tampering): mitigated. The change is additive with an unset fallback, guarded by the offline shape assertion, and merged only after operator approval. No tag moved.
- T-29-01 (self-hosted label reachability): inert. `DEFECTDOJO_RUNS_ON` is unset, and the fork approval policy is raised before it is set (plans 29-12 and 29-14).
- No new surface beyond the threat register.

## Known Stubs

None.

## Next

The security-platform clone stays on `feature/phase-29-defectdojo-live-validation`, fetched and tracking origin, for the plan 29-18 PR B commits. The remote branch was not deleted. The next plan is 29-07.

## Self-Check: PASSED

- The commits `367b315`, `e8387a8` and `2fda1ac` are present on `origin/main` of security-platform (git log verified).
- PR #24 state is MERGED (gh pr view verified).
