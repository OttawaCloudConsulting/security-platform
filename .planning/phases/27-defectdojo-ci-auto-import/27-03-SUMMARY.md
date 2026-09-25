---
phase: 27-defectdojo-ci-auto-import
plan: 03
subsystem: ci-workflow
tags: [defectdojo, github-actions, engagement-delete, side-channel, pr-close]
requires:
  - "27-01 side-channel gate contract (check-workflow-uploads.sh, 16 checks)"
  - "27-02 defectdojo-import job (dd-gate step, header-file and TLS handling reused)"
provides:
  - "defectdojo-cleanup job: dd-gate, dd-delete, dd-cleanup-verify (env-only run bodies, extractable by the 27-06 harness)"
  - "dd-cleanup-result.json schema: outcome deleted | nothing-to-delete | refused, target, product_name, product_id, deleted_ids"
affects: [27-04, 27-06, 27-09, 27-10]
tech-stack:
  added: []
  patterns:
    - "Irreversible DELETE guarded by exact product (name_exact + client ==), exact engagement (name + product id), default-branch refusal, no-match no-op, re-GET confirmation"
    - "Every exit-0 path writes the result file, so a legitimate no-op stays green"
key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml
key-decisions:
  - "An empty DD_DEFAULT_BRANCH gets its own REFUSE line ('the default branch is unknown'); an empty or default head uses the contract line verbatim"
  - "A paginated lookup response (non-null next) is treated as FAILED 'refusing to guess' rather than silently reading only page 1"
  - "The first ::warning:: line says 'cleanup request' instead of 'findings', because the delete sends no findings; the gate marker and the second warning are unchanged"
requirements-completed: []  # DDOJO-02 partial (3 of 10 plans); marked complete by 27-10
duration: ~25min
completed: 2026-09-25
---

# Phase 27 Plan 03: DefectDojo PR-close cleanup job Summary

`security.yml` now has a `defectdojo-cleanup` job. It runs only on `pull_request` `closed` and uses the same opt-in gate as the import job. It deletes exactly that PR's `ci/<head-branch>` engagement inside the one product whose name matches exactly. Before deleting, it refuses an empty head ref or the default branch, and it does nothing when there is no match. After deleting, it re-reads to confirm the engagement is gone. A red verify step checks the result.

## Tasks

| Task | Name | Commit | Repo |
|------|------|--------|------|
| 1 | Add the defectdojo-cleanup job with the exact-name delete guard | `a7a7590` | security-platform, branch `feature/phase-27-defectdojo-ci-auto-import` |

## What changed (security.yml, +310)

- The banner comment explains four things:
  - why the job lives in `security.yml`, gated on `closed` (D-15);
  - why merged and abandoned PRs take the same path;
  - why the delete is irreversible and therefore guarded (D-10);
  - why every exact match is deleted (RESEARCH OQ1).
  It also notes that the token must belong to an `is_staff` user.
- Job fields follow the contract:
  - `if: github.event_name == 'pull_request' && github.event.action == 'closed' && vars.DEFECTDOJO_URL != ''`;
  - no `needs:`, `timeout-minutes: 10`, `contents: read` only;
  - the same concurrency group as the import job, with `cancel-in-progress: false`;
  - no job-level env and no `shell:`.
- `dd-gate`: the name, env and run are byte-identical to the import job's gate step.
- `dd-delete`: a `continue-on-error` step with exactly the seven contract env keys. The head ref comes from the runner's `GITHUB_HEAD_REF`. The body is a stdlib `python3` heredoc using `.format()` and follows decision steps 1-8. Every query is built with `urlencode`, and every request is checked:
  - each GET must return 200 with a `results` list;
  - each DELETE must return 204;
  - anything else prints `FAILED: <method> <path> http=<code>`.
  The header-file and TLS handling are reused from dd-import, including both `::warning::` lines. The temporary directory is removed in `finally`.
- `dd-cleanup-verify`: has no continue-on-error and reads `DD_DELETE_OUTCOME: ${{ steps.dd-delete.outcome }}` from its env. It fails red when the outcome is not `success`, when the result file is missing, or when the outcome value is unknown.

## Verification evidence

- `actionlint` exits 0.
- `check-workflow-uploads.sh` prints `PASS - 16 checks, 0 failures` with 0 `vacuous` NOTE lines, so every side-channel check is now enforced on both jobs.
- `check-detector-parity.sh` exits 0.
- `bash scripts/check-adoption-guide.sh` in the doc repo prints `PASSED 15 / FAILED 0`.
- `git diff --quiet main -- scripts/set-required-checks.sh` exits 0.
- yq queries:
  - the step ids are `dd-gate`, `dd-delete`, `dd-cleanup-verify`, in that order;
  - `needs` and job `env` are both `null`;
  - the `${{` count across the run bodies is 0;
  - the two dd-gate run bodies are identical.
- The dd-delete body contains all nine required strings. The count of `products/?name=` is 0.

### Behavioral test: extracted bodies against a local stdlib mock (scratchpad, deleted afterwards)

No request went to a real DefectDojo. The mock implemented products GET, engagements GET and engagements DELETE, and logged every request.

| Case | rc | Result |
|------|----|--------|
| Happy path (`feat-x`, product `org/repo`) | 0 | Four requests: products `?name_exact=org%2Frepo`, engagements `?product=7&name=ci%2Ffeat-x`, DELETE 101, re-GET. Only 101 was removed. `ci/feat-x` in another product, `ci/feat-x-2` and `CI/feat-x` all survived. Outcome `deleted`, ids [101]. Verify rc 0. |
| Sloppy server (the engagements filter returns every engagement) | 0 | The client-side `==` plus product-id check still deleted only 101. |
| Duplicate from a race (101 and 106 both `ci/feat-x` in product 7) | 0 | Both were deleted and logged. The re-GET was empty. |
| Empty head / head == `main` / empty default branch | 0 | `REFUSE:` line, zero HTTP requests, outcome `refused`. Verify rc 0. |
| No such product / case-only product match (`ORG/REPO`) | 0 | `NOTHING TO DELETE: no product named …`, outcome `nothing-to-delete`. |
| No such engagement | 0 | `NOTHING TO DELETE: no engagement 'ci/feat-y' in product 7`. |
| Head `%` | 0 | Sent as `ci%2F%25`, matched nothing, deleted nothing. |
| Two products exactly named `org/repo` | 1 | `FAILED: 2 products exactly named 'org/repo' — refusing to guess`. Nothing deleted. Verify rc 1. |
| DELETE returns 403 | 1 | `FAILED: DELETE /api/v2/engagements/101/ http=403 …`. Verify rc 1. |
| Engagement still present on the re-GET | 1 | `FAILED: 1 engagement(s) named 'ci/feat-x' still exist …`. Verify rc 1. |
| Engagements GET returns 500 | 1 | `FAILED: GET … http=500`. Nothing deleted. |
| `DD_INSECURE=true` + `DD_CA_CERT` | 0 | Both `::warning::` lines print, then `TLS mode: insecure`. |
| Verify run alone: result file missing / outcome `bogus` / delete outcome `skipped` | 1 | Each prints its specific message. |

The token reached the mock only as the `Authorization: Token …` header, read from the header file. The temporary directory had 0 leftover entries after every case.

The step-5 check (refusing `ci/<default>`) cannot be reached through the mock. Step 1 already refuses the default branch, and step 4 keeps only `name == "ci/" + head`. It is defence in depth, as the plan specifies.

Behavior against a live DefectDojo was **not** tested here. That includes real 204s, cascade deletion, and the staff-permission requirement. It belongs to the 27-06 proof harness (P-CLEANUP / P-SCOPE).

## Deviations from Plan

None in substance. Three small choices stay within the contract (see key-decisions):
- An empty `DD_DEFAULT_BRANCH` prints its own `REFUSE:` line. It still writes outcome `refused` and sends nothing.
- A lookup response with a non-null `next` (more than 100 results) fails with "refusing to guess". Otherwise a match on page 2 could be missed silently.
- The first `::warning::` line was reworded from "this run's findings were sent" to "this run's cleanup request was sent", which is accurate for a delete. The plan said to reuse the warnings verbatim. The gate's INSECURE-WARNING check still passes, and the second warning line is unchanged.

## Known Stubs

None. The comments refer to ADR-024 (27-10) and the adoption guide's DefectDojo section (27-09). Both are forward references by design, as in 27-02.

## Threat Flags

None. The new surface (a DELETE with a staff token) is covered by T-27-03, T-27-05 and T-27-13 in the plan's threat model.

## Next Phase Readiness

- 27-04 can make the side-channel checks mandatory: both jobs are present and none of those checks is vacuous any more.
- 27-06 can extract `dd-delete` and `dd-cleanup-verify` by step id. The bodies read only env and `GITHUB_HEAD_REF`, and curl carries no `-q`.

## Self-Check: PASSED
