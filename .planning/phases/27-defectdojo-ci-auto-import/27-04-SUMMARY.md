---
phase: 27-defectdojo-ci-auto-import
plan: 04
subsystem: ci-workflow
tags: [defectdojo, github-actions, workflow_call, schedule, static-gate]
requires:
  - "27-01 side-channel gate contract (check-workflow-uploads.sh, 16 checks)"
  - "27-02 security.yml optional DEFECTDOJO_API_TOKEN secret + closed-skip on scan jobs"
  - "27-03 defectdojo-cleanup job (fires on pull_request closed)"
provides:
  - "pr-security.yml: types [opened, synchronize, reopened, closed] + explicit DEFECTDOJO_API_TOKEN secret pass"
  - "scheduled-security.yml: optional daily 06:00 America/Toronto caller + workflow_dispatch"
  - "check-workflow-uploads.sh final form: 18 checks, no vacuous pass, SCAN-JOB-CLOSED-SKIP + CALLER-WIRING"
affects: [27-05, 27-06, 27-07, 27-09, 27-10]
tech-stack:
  added: []
  patterns:
    - "Explicit single-secret pass from caller to reusable workflow (never secrets: inherit)"
    - "GitHub IANA on.schedule timezone key for DST-safe daily schedule"
    - "Gate reads trigger via trigger_of(doc) = doc.get('on', doc.get(True))"
key-files:
  created:
    - repos/security-platform/.github/workflows/scheduled-security.yml
  modified:
    - repos/security-platform/.github/workflows/pr-security.yml
    - repos/security-platform/scripts/check-workflow-uploads.sh
key-decisions:
  - "OPTIONAL-SECRET is now unconditional: both callers pass the secret, so its declaration must exist whether or not the side-channel jobs do"
  - "A missing scheduled-security.yml is a labelled CALLER-WIRING failure, not a traceback (guarded with os.path.isfile)"
  - "CALLER-WIRING rejects any with: key on jobs.security (including with: {}), via 'with' in job"
requirements-completed: []  # DDOJO-02 partial (4 of 10 plans); marked complete by 27-10
duration: ~25min
completed: 2026-09-25
---

# Phase 27 Plan 04: Caller wiring and mandatory gate Summary

Both callers now pass `DEFECTDOJO_API_TOKEN` to `security.yml` explicitly, never through `secrets: inherit`. `pr-security.yml` also subscribes to `closed`, which fires the cleanup job. The new optional `scheduled-security.yml` scans and imports the default branch daily at 06:00 America/Toronto and can also be run by hand. `check-workflow-uploads.sh` now enforces every Phase 27 invariant (18 checks) and no longer passes any check vacuously.

## Tasks

| Task | Name | Commit | Repo |
|------|------|--------|------|
| 1 | Add closed + secret pass to pr-security.yml; create scheduled-security.yml | `602bfeb` (combined, as the plan specifies) | security-platform, branch `feature/phase-27-defectdojo-ci-auto-import` |
| 2 | Make side-channel checks mandatory; add SCAN-JOB-CLOSED-SKIP and CALLER-WIRING | `602bfeb` | security-platform |

## What changed

**pr-security.yml**
- `pull_request: {}` is now `pull_request: types: [opened, synchronize, reopened, closed]`. A WHY comment explains two things:
  - listing types replaces the default set, so the three defaults are restated (Pitfall 2);
  - `closed` exists only to fire the DefectDojo cleanup, and the scan jobs skip on it (D-10, D-15).
- A `secrets: { DEFECTDOJO_API_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }} }` block now follows `uses:`. Its comment covers explicit-not-inherit (D-12), the empty-string clean skip, and the Mode B two-edit requirement (Pitfall 13a).
- The "No `with:` block" comment gains one sentence: `DEFECTDOJO_*` vars are not passed because the callee reads the caller repo's `vars` directly.
- The job id, `name: security`, the permissions block and the `uses:` line are unchanged. `git diff main` shows no permission-value lines.
- Header: see the deviation below. The trigger note now says `pull_request` with no branch filter, instead of `pull_request: {}`.

**scheduled-security.yml (new)**
- `name: Scheduled Security`.
- Triggers: `on.schedule: [{cron: '0 6 * * *', timezone: "America/Toronto"}]` and `workflow_dispatch: {}`.
- Workflow permissions floor is `contents: read`. `jobs.security` has `name: security`, the same three-grant block, `uses: ./.github/workflows/security.yml` and the explicit secret pass. It has no `with:`.
- The ADOPTION header covers:
  - the file is optional;
  - Mode B changes only the `uses:` line to `...security.yml@v1`;
  - the IANA `timezone:` key handles DST (GA 2026-03-19), and 06:00 is never a skipped hour;
  - GitHub auto-disables schedules after 60 days of inactivity in public repos (Pitfall 12);
  - the reused job id `security` produces `security / ...` check runs on the default-branch commit, which never affect a PR's required checks.

**check-workflow-uploads.sh**
- SIDE-CHANNEL-SHAPE, NO-INTERPOLATION, IMPORT-VERIFY-PAIRING and INSECURE-WARNING: each vacuous NOTE branch is now `fail_absent()`, which names the missing job. The `notes` / `note_vacuous` machinery is removed.
- OPTIONAL-SECRET is now unconditional (see key-decisions).
- New helper `trigger_of(doc)` = `doc.get("on", doc.get(True))`, used by OPTIONAL-SECRET and CALLER-WIRING. The PyYAML `on:` note is updated to match.
- New check 17, SCAN-JOB-CLOSED-SKIP: the `if:` of each of the five scan jobs, after `.strip()`, must equal `github.event.action != 'closed'`.
- New check 18, CALLER-WIRING:
  - pr-security types must be exactly the four;
  - scheduled-security.yml must exist (a labelled failure if not);
  - in both callers, `jobs.security.secrets` must be a mapping (a string such as `inherit` fails) whose only key is `DEFECTDOJO_API_TOKEN`, mapped to exactly `${{ secrets.DEFECTDOJO_API_TOKEN }}`;
  - neither caller may have `with` on `jobs.security`;
  - the schedule needs an entry with cron `0 6 * * *` and timezone `America/Toronto`, plus a `workflow_dispatch` key.
- `CHECK_COUNT = 18`. The roll-call comment is updated.
- The header names ADR-024 and maps each check to the decision it guards:
  - D-01: JOB-SHAPE
  - D-03: SIDE-CHANNEL-NOT-REQUIRED, SIDE-CHANNEL-SHAPE, IMPORT-VERIFY-PAIRING
  - D-12: OPTIONAL-SECRET, CALLER-WIRING, NO-INTERPOLATION
  - D-15: SCAN-JOB-CLOSED-SKIP, CALLER-WIRING
  - D-18: INSECURE-WARNING

## Verification evidence

- `actionlint` exits 0 on all three workflow files (and on the whole tree).
- The yq acceptance queries give:
  - pr-security types = `["opened","synchronize","reopened","closed"]`;
  - both callers: name `security`, uses `./.github/workflows/security.yml`, secret `${{ secrets.DEFECTDOJO_API_TOKEN }}`, `with` = `null`;
  - scheduled: cron `0 6 * * *`, timezone `America/Toronto`, `has("workflow_dispatch")` = `true`.
- The count of non-comment `inherit` in pr-security.yml is 0.
- `bash scripts/check-workflow-uploads.sh` exits 0 with the last line `PASS - 18 checks, 0 failures` and no `vacuous` in its output.
- `check-detector-parity.sh` gives `PASSED 20 / FAILED 0`. `bash scripts/check-adoption-guide.sh` (doc repo) gives `PASSED 15 / FAILED 0`, run after the pr-security.yml edit.
- `shellcheck` passes, the file mode is 644, and `git diff --quiet main -- scripts/set-required-checks.sh` exits 0.
- `grep -c CALLER-WIRING` = 17 and `grep -c SCAN-JOB-CLOSED-SKIP` = 4.
- The pre-commit hooks (shellcheck, yamllint) passed on the commit.

### Behavior cases (real script, `WORKFLOWS_DIR` pointed at scratch copies; `$S` = scratch dir)

| Case | rc | Output (verbatim, first line omitted) |
|------|----|----------------------------------------|
| full tree | 0 | `PASS - 18 checks, 0 failures` |
| `defectdojo-cleanup` removed (yq del) | 1 | `FAIL: SIDE-CHANNEL-SHAPE: jobs.defectdojo-cleanup is absent from $S/nocleanup/security.yml — the Phase 27 side-channel job is mandatory (ADR-024)`, the same line for NO-INTERPOLATION, IMPORT-VERIFY-PAIRING and INSECURE-WARNING, then `FAILED - 4 check(s)` |
| pr-security `types: [closed]` | 1 | `FAIL: CALLER-WIRING: $S/closedonly/pr-security.yml on.pull_request.types must be exactly ['opened', 'synchronize', 'reopened', 'closed'], got ['closed']` / `FAILED - 1 check(s)` |
| scheduled `secrets: inherit` | 1 | `` FAIL: CALLER-WIRING: $S/inherit/scheduled-security.yml jobs.security.secrets is 'inherit' — pass DEFECTDOJO_API_TOKEN explicitly, never `secrets: inherit` (D-12) `` / `FAILED - 1 check(s)` |
| `if:` removed from `container` | 1 | `FAIL: SCAN-JOB-CLOSED-SKIP: jobs.container.if must be exactly "github.event.action != 'closed'", got ''` / `FAILED - 1 check(s)` |
| extra: scheduled-security.yml deleted | 1 | `FAIL: CALLER-WIRING: $S/nosched/scheduled-security.yml is missing — the daily default-branch caller is part of the Phase 27 bundle (D-14, D-15)` / `FAILED - 1 check(s)` |

Each fixture produced only its intended failure labels. The `yq -i` rewrite of security.yml in two fixtures introduced no other failures.

Nothing was contacted over the network, and no real DefectDojo was used. Whether GitHub actually fires `closed` and the scheduled run is not tested here. That is left to the live phases of this milestone.

## TDD Gate Compliance

Task 2 is marked `tdd="true"`, but the plan asks for one combined `feat(27-04)` commit, so there is no separate RED commit. RED evidence came from running the four plan cases against the **unmodified** 16-check gate:
- `nocleanup`: rc 0, 4 `vacuous` NOTE lines, then `PASS - 16 checks, 0 failures`.
- `closedonly`, `inherit`, `noif`: rc 0, `PASS - 16 checks, 0 failures` each.

All four passed when they should have failed. After the change (GREEN), all of them fail with their labels (table above).

## Deviations from Plan

**1. [Carry-forward from 27-02] Reworded the pr-security.yml ADOPTION header**
- **Found during:** Task 1
- **Issue:** Lines 6-7 said the file "has exactly ONE per-repo substitution point, `gate_mode`". That is stale now that the `DEFECTDOJO_*` vars and the optional secret exist.
- **Fix:** It now says "`gate_mode` is the only per-repo setting that changes gating". A new sentence says the opt-in DefectDojo import and cleanup (ADR-024) read the `DEFECTDOJO_*` vars and the `DEFECTDOJO_API_TOKEN` secret, and that none of them affects a required check. This matches security.yml's header from 27-02. No gate pins that text: a grep of both repos' `scripts/` found no pin, and check-adoption-guide.sh passed after the edit.
- **Files modified:** repos/security-platform/.github/workflows/pr-security.yml
- **Commit:** `602bfeb`

**2. [Rule 2] Added a fifth fixture (scheduled-security.yml missing)**
- The plan says the file's absence must fail CALLER-WIRING, but its four behavior cases do not cover that. I added a fixture, which shows a labelled failure rather than a Python traceback.

**3. Header comment updated beyond the ADR-024 mapping**
- The "reads pr-security.yml and security.yml by name" sentence now also names scheduled-security.yml, so it does not go stale.

## Known Stubs

None.

## Carry-forward for later plans

- `docs/adoption-guide.md` (this repo) still shows `pull_request: {}` in the Mode B caller block (around line 168). It has no `secrets:` pass and no scheduled caller. Lines 108 and 573 still say "one substitution point". This is 27-09's scope (Pitfall 13a), and the adoption gate passes today because it does not pin those lines.
- ADR-024 is still referenced forward (27-10).

## Threat Flags

None. The new surface (a scheduled trigger, and a secret crossing into the reusable workflow) is covered by T-27-14, T-27-15 and T-27-16 in the plan's threat model, and CALLER-WIRING enforces T-27-14 and T-27-15.

## Self-Check: PASSED
