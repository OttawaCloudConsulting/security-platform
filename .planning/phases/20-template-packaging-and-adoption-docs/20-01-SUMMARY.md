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
  - Task 2 resolved — A1 measured CONFIRMED (upload-sarif fails on this private repo; root cause is code-scanning-not-enabled, not a generic token-scope 403); evidence committed under 20-01-evidence/
  - Task 3 resolved — Q2 disposition operator-approved verbatim; guard expression and step list finalized for plan 04 to apply
affects: [20-04-canonical-workflow-guard, 20-08-adoption-guide, 20-09-adoption-guide, 20-10-pilot-prs]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: [.planning/phases/20-template-packaging-and-adoption-docs/20-01-SUMMARY.md, .planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/probe-run.log.txt, .planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/analyses-after.txt, .planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/analyses-after-with-headers.txt]
  modified: []

key-decisions:
  - "Task 1 (Q4): option-a confirmed — terraform-pipelines (public) and aws-zabbix-monitoring-solution (private) are the pilots for SC1/SC2 and the A1 probe; branch protection changes remain unauthorized"
  - "Task 2 (A1): CONFIRMED — upload-sarif fails on the private pilot with 'Code scanning is not enabled for this repository' (GHAS licensing gate), measured via run 34802848411; both the tolerant upload step and an in-workflow GITHUB_TOKEN read hit the identical error, ruling out the ii/iii ambiguity"
  - "Task 3 (Q2): operator-approved disposition — plan 04 compounds '&& github.event.repository.private == false' onto the six SARIF verify steps only (semgrep, checkov, trivy-fs, tflint, trivy-image, gitleaks); the five artifact verify steps stay untouched"

patterns-established: []

requirements-completed: []  # Deliberately empty — DIST-06/07 are marked complete only by plan 12 per 17-01/19-01 precedent.

# Metrics
duration: ~35min
completed: 2026-09-14
---

# Phase 20 Plan 01: Settle A1/Q4/Q2 (Pilot Repos and SARIF Capability) Summary

**A1 measured CONFIRMED live on a private pilot — `upload-sarif` fails with "Code scanning is not enabled for this repository" (a GHAS licensing gate, not a token-scope 403) — and the operator approved the resulting Q2 disposition: guard the six SARIF verify steps only, leave the five artifact verify steps untouched.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-09-14T03:23:19Z
- **Completed:** 2026-09-14 (Task 3 approved)
- **Tasks:** 3 of 3 completed
- **Files modified:** 0 tracked files in `security_solution` or `repos/security-platform` (per plan constraint); 3 evidence files under `.planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/`

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

## Task 2: A1 Measurement — RESULT: A1 CONFIRMED (upload outcome=failure)

**Method:** Cloned `OttawaCloudConsulting/aws-zabbix-monitoring-solution` into the session scratchpad (never into `repos/`, never into this repo's tree). Cut throwaway branch `chore/phase-20-sarif-capability-probe` from `origin/main`. Added one workflow file, `.github/workflows/sarif-capability-probe.yml`, triggered `on: push` to that exact branch, job-level permissions `contents: read`, `security-events: write`, `actions: read`. Steps: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`; write a synthetic SARIF 2.1.0 document with exactly one result from driver `phase20-probe` pointing at `README.md:1`, no repository content copied; upload via `github/codeql-action/upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63 # v4.38.0` with `id: up`, `continue-on-error: true`, `category: phase20-probe`; print `upload outcome=${{ steps.up.outcome }}`.

**[Rule 2 — missing critical functionality] Added one extra step beyond the plan's literal text:** an in-workflow read of `repos/${{ github.repository }}/code-scanning/analyses?ref=${{ github.ref }}` using `GH_TOKEN: ${{ github.token }}`, run `if: always()`. Reason: the local CLI token lacks `security_events` scope and is confirmed (17-05 precedent) to 403 on this exact private repo's code-scanning reads regardless of upload outcome — so a local-only before/after read cannot discriminate the plan's outcome (ii) "success + analysis present" from outcome (iii) "success + no analysis" (both would show 403 from the local token). The in-workflow `GITHUB_TOKEN` with `security-events: write` is the only token in this measurement with a chance of reading its own upload back. This is a read-only addition; it does not touch any tracked file in `security_solution` or `security-platform`, is scoped entirely to the throwaway probe workflow, and was deleted with the branch at task end.

**Evidence captured (raw, not transcribed) and committed under `.planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/`:**
- `probe-run.log.txt` — full `gh run view --log` output, run id `34802848411`, conclusion `success` (the JOB succeeded because `continue-on-error: true` tolerates the upload failure; the upload STEP itself failed).
- `analyses-after.txt` / `analyses-after-with-headers.txt` — local (session) `gh api repos/OttawaCloudConsulting/aws-zabbix-monitoring-solution/code-scanning/analyses` response, captured AFTER the run: `HTTP/2.0 403 Forbidden`, body `{"message":"Code scanning is not enabled for this repository. Please enable code scanning in the repository settings.","status":"403"}`.

**The literal `upload outcome=` line (from `probe-run.log.txt`):**
```
upload outcome=failure
```

**In-workflow analyses read (the `GITHUB_TOKEN` with `security-events: write`, from `probe-run.log.txt`), same run:**
```
gh: Code scanning is not enabled for this repository. Please enable code scanning in the repository settings. (HTTP 403)
{"message":"Code scanning is not enabled for this repository. Please enable code scanning in the repository settings.","documentation_url":"...","status":"403"}
```

**Result classification (one of the plan's three enumerated outcomes):** **(i) upload `failure` — A1 CONFIRMED.** The upload-sarif step's own log shows the underlying cause precisely: `##[error]Please verify that the necessary features are enabled: Code scanning is not enabled for this repository.` This is a MORE PRECISE mechanism than RESEARCH's Pitfall 1 inference (a generic permission/403 on the read endpoint) — the actual blocker is that GitHub code scanning (SARIF ingestion) requires GitHub Advanced Security to be enabled on a private repository, and it is not enabled here, independent of the workflow's own `security-events: write` grant. Both the tolerant upload step AND the intolerant in-workflow `GITHUB_TOKEN` read got the identical 403/"not enabled" response — there is no ambiguity between outcomes (ii) and (iii): the upload never had anywhere to land.

**Cleanup:**
- Remote branch `chore/phase-20-sarif-capability-probe` deleted via `gh api -X DELETE repos/OttawaCloudConsulting/aws-zabbix-monitoring-solution/git/refs/heads/chore/phase-20-sarif-capability-probe` (first call succeeded silently; a verification retry correctly returned `422 Reference does not exist`).
- `gh api repos/OttawaCloudConsulting/aws-zabbix-monitoring-solution/branches/chore/phase-20-sarif-capability-probe` returns `404 Branch not found` — acceptance criterion met.
- No analysis ever landed (upload failed outright), so the plan's conditional `DELETE .../code-scanning/analyses/<id>` step is N/A — nothing to delete. No probe content persists on GitHub beyond standard Actions run-log retention (T-20-10 mitigated: the synthetic SARIF contained no repository content).
- Scratchpad clone `aws-zabbix-monitoring-solution/` removed (`rm -rf`) after evidence was copied out.
- No file under `repos/` and no file tracked by `security_solution` or `security-platform` was created or modified by this task.

## Task 3: Q2 Disposition Confirmation — RESOLVED (approved)

**Operator reply, quoted verbatim (relayed via the coordinator):**

> Approved. Disposition confirmed: add `&& github.event.repository.private == false` guard to the six SARIF verify steps only (semgrep, checkov, trivy-fs, tflint, trivy-image, gitleaks); leave the five artifact verify steps untouched. Complete Task 3, commit, finish SUMMARY.md, then return.

**Confirmed disposition (unchanged from what was presented at the checkpoint, per the plan's own three-way table given A1 CONFIRMED):**
- **Guard expression:** `&& github.event.repository.private == false`
- **Applies to (six SARIF verify steps only):** `Verify Semgrep SARIF upload landed`, `Verify Checkov SARIF upload landed`, `Verify Trivy Filesystem SARIF upload landed`, `Verify tflint SARIF upload landed`, `Verify Trivy Image SARIF upload landed`, `Verify Gitleaks SARIF upload landed` — in `repos/security-platform/.github/workflows/security.yml`.
- **Does NOT apply to (five artifact verify steps, left untouched):** the five `Verify … artifact` steps — artifact upload authenticates via `ACTIONS_RUNTIME_TOKEN`, not `GITHUB_TOKEN`, and is unaffected by code-scanning/GHAS availability.
- **No verify step is deleted.** The guard skips an assertion that cannot pass on a private repo (T-20-05 mitigated — deleting an assertion was explicitly excluded by this task's own acceptance criteria).
- **`requirements.mark-complete` deliberately NOT invoked** by this plan. DIST-06/DIST-07 remain the responsibility of plan 12, per the 17-01/19-01 precedent already recorded in STATE.md.

**Ownership boundary respected:** No workflow file was edited by this plan. `repos/security-platform/.github/workflows/security.yml` is plan 04's deliverable to modify; this plan only hands plan 04 the exact expression and step list, backed by live measurement (Task 2) rather than inference.

## Task Commits

1. **Task 1: Confirm pilot repositories (Q4)** — no file-changing commit (decision checkpoint by design); recorded in commit `4440bca` (`docs(20-01): record option-a pilot decision`).
2. **Task 2: A1 measurement** — evidence files + SUMMARY update committed in `e6ab3a7` (`docs(20-01): measure A1 CONFIRMED`).
3. **Task 3: Q2 disposition confirmation** — no file-changing commit outside `.planning/` (checkpoint by design); this final SUMMARY update committed as `docs(20-01)` (hash recorded after save).

**Plan metadata:** all three task commits above ARE the plan's metadata commits — this plan produces no tracked change to `security_solution` or `security-platform` source, per its own `<verification>` constraint.

## Files Created/Modified

- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-SUMMARY.md` — this record, updated per task.
- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/probe-run.log.txt` — full run log for run 34802848411.
- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/analyses-after.txt` — local post-run code-scanning analyses read (403, body only).
- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/analyses-after-with-headers.txt` — same read with HTTP status line and headers.

## Decisions Made

- Task 1 (Q4): option-a — `terraform-pipelines` (public) + `aws-zabbix-monitoring-solution` (private) confirmed as pilots; branch protection changes remain unauthorized.
- Task 2 (A1): CONFIRMED by live measurement — `upload-sarif` fails on this private repository. Root cause is "code scanning not enabled" (GHAS licensing gate on private repos), not merely a token-scope 403 as RESEARCH's Pitfall 1 inferred. Both the upload step and an in-workflow `GITHUB_TOKEN` read (with `security-events: write`) hit the identical error, closing off any ambiguity between "silently dropped" and "confirmed absent."
- Task 3 (Q2): operator approved the disposition as presented — guard the six SARIF verify steps with `&& github.event.repository.private == false`; leave the five artifact verify steps untouched; no verify step deleted; `requirements.mark-complete` withheld for plan 12.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added an in-workflow code-scanning analyses read to the probe workflow**
- **Found during:** Task 2 (A1 measurement)
- **Issue:** The plan's literal text captures the analyses response only via the local CLI (`gh api ... code-scanning/analyses`), but the local token lacks `security_events` scope and (per 17-05 precedent) 403s on this exact private repo regardless of what the in-workflow upload actually did — making it structurally impossible to distinguish the plan's outcome (ii) "success + analysis landed" from outcome (iii) "success + silently dropped" using only the local token.
- **Fix:** Added one more step to the probe workflow, `Read code-scanning analyses in-workflow`, using `GH_TOKEN: ${{ github.token }}` (the same `GITHUB_TOKEN` granted `security-events: write` for the upload) to query `code-scanning/analyses?ref=${{ github.ref }}` and print the raw response.
- **Files modified:** none tracked — the addition lives entirely in the throwaway probe workflow file in the pilot repo's scratchpad clone, deleted with the branch at task end.
- **Verification:** The in-workflow step ran (`if: always()`) and its output is captured verbatim in `20-01-evidence/probe-run.log.txt`.
- **Committed in:** N/A (no tracked file changed) — documented here per Rule 2 transparency requirement.

---

**Total deviations:** 1 auto-fixed (1 missing critical — measurement completeness)
**Impact on plan:** Necessary to make Task 2's own acceptance criteria satisfiable (distinguishing outcomes ii/iii). No scope creep — the addition is read-only, inside the throwaway probe, and deleted with everything else.

## Issues Encountered

None — the measurement produced an unambiguous result on the first run; no retry, no scope escalation, no second workflow run was needed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

All three tasks resolved with operator sign-off at every gate. Plan 04 can now compound the guard expression onto the six SARIF verify steps in `repos/security-platform/.github/workflows/security.yml` without any further judgement call, and plan 10 knows `terraform-pipelines` (public) and `aws-zabbix-monitoring-solution` (private) are the authorised pilots for its live PRs. No downstream plan in this phase is blocked by an open question from this plan.

## Self-Check: PASSED

- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-SUMMARY.md` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/probe-run.log.txt` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/analyses-after.txt` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-01-evidence/analyses-after-with-headers.txt` — FOUND
- Commit `0d88ffb` (checkpoint pause record) — FOUND in `git log --oneline --all`
- Commit `4440bca` (Task 1 close-out) — FOUND in `git log --oneline --all`
- Commit `e6ab3a7` (Task 2 measurement) — FOUND in `git log --oneline --all`
- `git status --porcelain` shows no change outside `.planning/` — CONFIRMED
- `repos/security-platform` untouched: no local clone exists in this worktree, no branch/commit/file created there by this plan — CONFIRMED (only `gh api` reads were used against it)
- Probe branch `chore/phase-20-sarif-capability-probe` on `aws-zabbix-monitoring-solution`: `gh api .../branches/...` returns 404 — CONFIRMED deleted

---
*Phase: 20-template-packaging-and-adoption-docs*
*Status: COMPLETE — all three tasks resolved, operator-approved at both checkpoints*
