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
  - Task 1 resolved — option-a confirmed, pilot repositories named and operator-authorised for live proofs
affects: [20-04-canonical-workflow-guard, 20-08-adoption-guide, 20-09-adoption-guide, 20-10-pilot-prs]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: [.planning/phases/20-template-packaging-and-adoption-docs/20-01-SUMMARY.md]
  modified: []

key-decisions:
  - "Task 1 (Q4): option-a confirmed — terraform-pipelines (public) and aws-zabbix-monitoring-solution (private) are the pilots for SC1/SC2 and the A1 probe; branch protection changes remain unauthorized"

patterns-established: []

requirements-completed: []  # Deliberately empty — DIST-06/07 are marked complete only by plan 12 per 17-01/19-01 precedent.

# Metrics
duration: IN PROGRESS
completed: PENDING
---

# Phase 20 Plan 01: Settle A1/Q4/Q2 (Pilot Repos and SARIF Capability) Summary

**Task 1 resolved (option-a); Task 2's live A1 measurement is now in progress against the confirmed pilots.**

## Performance

- **Duration so far:** IN PROGRESS
- **Started:** 2026-09-14T03:23:19Z
- **Completed:** N/A — plan not complete
- **Tasks:** 1 of 3 completed (Task 1 closed by operator decision)
- **Files modified:** 0 tracked files in `security_solution` or `repos/security-platform` (per plan constraint); evidence files will land under `.planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/`

## Accomplishments

- Read and understood the plan's objective, threat model, and acceptance criteria.
- Verified worktree branch/base integrity before any action (per `worktree_branch_check`).
- Confirmed this plan is explicitly marked `autonomous: false` and its Task 1 is `type="checkpoint:decision" gate="blocking"` — execution correctly halted there rather than guessing an answer to an open design question.
- Received the operator's decision (relayed by the coordinator) and closed out Task 1.

## Task 1: Operator Decision (Q4) — RESOLVED

**Operator reply, quoted verbatim (relayed via the coordinator):**

> Operator decision: option-a. Use terraform-pipelines (public) and aws-zabbix-monitoring-solution (private) as the pilot repos for live proofs. Branch protection changes remain unauthorized. Resume plan 20-01 from Task 1 with this decision and continue through remaining tasks, committing each atomically, updating SUMMARY.md, then return.

**Chosen option:** option-a (RESEARCH Q4 recommendation / default).

**Confirmed pilots:**
- SC1/SC2 proofs: `OttawaCloudConsulting/terraform-pipelines` (PUBLIC)
- A1 private-repo probe: `OttawaCloudConsulting/aws-zabbix-monitoring-solution` (PRIVATE)

**Authorization scope confirmed:** Branch, PR, and workflow-run activity in both named pilots is authorised for this phase's live proofs. Branch protection / ruleset writes and `gh variable set` remain explicitly UNAUTHORIZED in both repos, per Task 1's acceptance criteria.

**Preflight checks performed before touching the private pilot (all read-only):**
- `gh auth status`: authenticated as `OttawaCloudConsulting`, token scopes `gist, read:org, repo, workflow` (no `security_events` — consistent with 17-05's prior finding).
- `gh repo view OttawaCloudConsulting/aws-zabbix-monitoring-solution --json isPrivate,defaultBranchRef,name`: confirmed `isPrivate: true`, default branch `main`.
- `gh repo view OttawaCloudConsulting/terraform-pipelines --json isPrivate,defaultBranchRef,name`: confirmed `isPrivate: false`, default branch `main`.
- `gh api repos/OttawaCloudConsulting/aws-zabbix-monitoring-solution/actions/permissions`: `{"enabled":true,"allowed_actions":"all","sha_pinning_required":false}` — Actions is enabled, the probe run will not be silently blocked.
- Fetched `repos/security-platform` `.github/workflows/security.yml` via `gh api .../contents/... -H "Accept: application/vnd.github.raw"` (this worktree has no local `repos/` clone) and cross-checked both pinned SHAs against the plan's Task 2 instructions: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` and `github/codeql-action/upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63 # v4.38.0` — both match exactly, reused verbatim per the threat register (T-20-SC).

## Task Commits

1. **Task 1: Confirm pilot repositories (Q4)** — no file-changing commit (decision checkpoint by design); this SUMMARY update is committed as `docs(20-01)`.

(Task 2 and Task 3 commits recorded below as they land.)

## Files Created/Modified

- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-SUMMARY.md` — this record, updated per task.

## Decisions Made

- Task 1 (Q4): option-a — `terraform-pipelines` (public) + `aws-zabbix-monitoring-solution` (private) confirmed as pilots; branch protection changes remain unauthorized.

## Deviations from Plan

(updated as Task 2/3 proceed — see below)

## Issues Encountered

None so far.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Task 1 resolved. Task 2 (A1 live measurement) now proceeding against the confirmed private pilot `aws-zabbix-monitoring-solution`. Task 3 remains a blocking `checkpoint:human-verify` and will halt this execution again once Task 2's measurement is captured — the executor will present the disposition and await operator confirmation rather than fabricating an `approved`.

---
*Phase: 20-template-packaging-and-adoption-docs*
*Status: Task 1 resolved; Task 2 in progress*
