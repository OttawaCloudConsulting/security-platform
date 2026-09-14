---
phase: 20-template-packaging-and-adoption-docs
plan: 01
subsystem: ci-cd
tags: [github-actions, sarif, code-scanning, pilot-selection]

# Dependency graph
requires:
  - phase: 19-pipeline-validation-via-branch-target-prs
    provides: fully validated blocking/report-only gate behavior on OttawaCloudConsulting/security-platform
provides:
  - Nothing yet — plan is paused at Task 1's blocking decision checkpoint before any work executes
affects: [20-04-canonical-workflow-guard, 20-08-adoption-guide, 20-09-adoption-guide, 20-10-pilot-prs]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: [.planning/phases/20-template-packaging-and-adoption-docs/20-01-SUMMARY.md]
  modified: []

key-decisions:
  - "None yet — Task 1's pilot-repository decision is unresolved; nothing in this plan can proceed until it is answered"

patterns-established: []

requirements-completed: []  # Deliberately empty — DIST-06/07 are marked complete only by plan 12 per 17-01/19-01 precedent, and no task has completed here yet.

# Metrics
duration: 0min (paused before first task completed)
completed: PENDING
---

# Phase 20 Plan 01: Settle A1/Q4/Q2 (Pilot Repos and SARIF Capability) Summary

**PAUSED at Task 1 — a blocking `checkpoint:decision` requires the operator to name the pilot repositories before any measurement or file changes can happen.**

## Performance

- **Duration so far:** 0 min of executed work (checkpoint hit immediately on Task 1, the plan's first task)
- **Started:** 2026-09-14T03:23:19Z
- **Completed:** N/A — plan not complete
- **Tasks:** 0 of 3 completed
- **Files modified:** 0 (no tracked file in `security_solution` or `repos/security-platform` was touched, per plan constraint)

## Accomplishments

- Read and understood the plan's objective, threat model, and acceptance criteria.
- Verified worktree branch/base integrity before any action (per `worktree_branch_check`).
- Confirmed this plan is explicitly marked `autonomous: false` and its Task 1 is `type="checkpoint:decision" gate="blocking"` — execution correctly halts here rather than guessing an answer to an open design question.

## Task Commits

No task commits — Task 1 is a decision checkpoint and by design executes no file changes and produces no commit. Only this SUMMARY is committed (metadata-only commit, per worktree-mode protocol).

## Files Created/Modified

- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-SUMMARY.md` — this checkpoint-status record.

## Decisions Made

None — the plan's Task 1 explicitly withholds any executor decision. See CHECKPOINT REACHED section below for the exact question and options that need an operator reply.

## Deviations from Plan

None — plan executed exactly as written up to the point where it requires a human decision. No auto-fix, no bug, no missing functionality was found; the halt is intentional per Task 1's own `<action>`: "Present the decision... then STOP and wait. Do not pick an option, do not proceed to Task 2, and do not touch any pilot repository before the reply arrives."

## Issues Encountered

None — this is the expected first-task outcome for a `checkpoint:decision` gated plan with no completed_tasks context supplied.

## User Setup Required

None — no external service configuration required. This checkpoint requires an operator decision, not environment setup.

## Next Phase Readiness

Not ready. Task 2 (the A1 SARIF-upload-capability measurement) and Task 3 (the Q2 disposition confirmation) both depend directly on Task 1's answer:

- If **option-a** (RESEARCH's default: `terraform-pipelines` public / `aws-zabbix-monitoring-solution` private) or **option-b** (a different named pair) is chosen, Task 2 measures A1 live against the named private pilot.
- If **option-c** is chosen, Task 2 is SKIPPED entirely, A1 stays UNMEASURED, and Task 3's disposition becomes RESEARCH mitigation (c) — scope SC2 to public consumers, and the adoption guide's private-repo section must be labelled as inferred rather than measured.

No downstream plan in this phase (04, 08, 09, 10) can proceed with certainty about the guard expression or the pilot repository names until this checkpoint is answered.

---

## CHECKPOINT REACHED

**Type:** decision
**Plan:** 20-01
**Progress:** 0/3 tasks complete

### Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| — | none completed | — | — |

### Current Task

**Task 1:** Confirm the pilot repositories and authorise live activity in them (Q4)
**Status:** awaiting decision
**Blocked by:** operator has not yet named the pilot repositories

### Checkpoint Details

**Decision:** Which repositories does this phase touch for its live proofs, and is branch/PR/workflow-run activity in them authorised?

**Context:** Every live criterion in this phase (SC1 copy-paste proof, SC2 `uses:` proof, and the A1/Q2 private-repo measurement in Task 2) requires opening a branch and running GitHub Actions inside a repository that is NOT one of this phase's two owned repos (`security_solution`, `repos/security-platform`). RESEARCH already probed two candidates live: both are cloned under `repos/`, neither has a `.github/` directory, and their measured shapes differ usefully:
- `terraform-pipelines` — PUBLIC, 36 `.tf` files, zero `package-lock.json`/`requirements*.txt`/Dockerfiles (exercises the public/SARIF path, tflint findings, three clean ecosystem skips).
- `aws-zabbix-monitoring-solution` — PRIVATE, one `package-lock.json` (exercises the private 403 path).

Branch protection is explicitly OUT OF SCOPE for these pilots — no ruleset write, no `gh variable set` is authorised by this checkpoint for any pilot.

**Options:**

| Option | Name | Pros | Cons |
|--------|------|------|------|
| option-a | RESEARCH Q4 recommendation (default) | Both already cloned and probed; public/private split covers every measured failure mode; no new repo needed; `terraform-pipelines` carries an existing ruleset to read (never write) | Two of the operator's real repositories carry a probe branch and one or two pull requests until closed |
| option-b | Different pilot(s) named by the operator | Operator may prefer a lower-traffic or throwaway repo | Needs re-probing (visibility, ruleset state, ecosystems present) before plan 10 can assert anything; RESEARCH's measured facts would not transfer |
| option-c | Public pilot only — skip the private measurement | Nothing is run inside a private repo | A1 stays unmeasured, so Q2 can only be answered by RESEARCH's mitigation (c) ("scope SC2 to public consumers, record private adoption as a follow-up"); the adoption guide's private-repo section ships as an unverified inference; 37 of the account's 60 repos are private |

### Awaiting

Operator reply naming:
1. The repository used for the SC1/SC2 proofs.
2. The repository (or explicitly "none") used for the A1 private-repo probe.
3. Which option (`option-a`, `option-b` + names, or `option-c`) this corresponds to.

**Resume-signal (from plan):** Reply with `option-a`, `option-b` plus the repository names, or `option-c`.

Once the reply arrives, a continuation agent should:
1. Quote the operator's reply verbatim into this SUMMARY.
2. Record the confirmed pilot repositories.
3. Proceed to Task 2 (or record the Task 2 SKIP if option-c) and then Task 3, updating this SUMMARY's frontmatter, decisions, and completion fields accordingly.

---
*Phase: 20-template-packaging-and-adoption-docs*
*Status: PAUSED at Task 1 checkpoint:decision — awaiting operator reply*
