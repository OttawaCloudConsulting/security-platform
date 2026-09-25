---
phase: 27-defectdojo-ci-auto-import
plan: 08
subsystem: release-tagging
tags: [defectdojo, github-actions, release, tags, adr-018, security-platform]
requires:
  - "27-07 PR #21 merged to security-platform main as 0f7e4e141d2a300d4be9a54efc137eb4510bb7ea"
provides:
  - "Closed-event run 36158851741: all seven 'security / ...' jobs skipped (D-10, D-15 observed)"
  - "workflow_dispatch proof run on main 36160366711: prove-import success, PROOF PASS - 85 assertions (D-19, D-21)"
  - "Annotated v1.1.0 (tag object 414fd3b) and lightweight v1, both at 0f7e4e1; release v1.1.0 is Latest (D-16, ADR-018)"
  - "evidence/27-08-post-merge.txt sections 1-5 with verbatim API readbacks"
affects: [27-09, 27-10]
tech-stack:
  added: []
  patterns:
    - "Tag writes use explicit refspecs only (refs/tags/v1.1.0, refs/tags/v1), never --tags or --mirror"
    - "Moving-tag push uses --force-with-lease pinned to the pre-checked remote SHA (narrower than the approved --force)"
    - "Every remote write is followed by a GitHub API readback before the next write"
key-files:
  created:
    - .planning/phases/27-defectdojo-ci-auto-import/evidence/27-08-post-merge.txt
  modified: []
key-decisions:
  - "Operator, after dispatch run 36159160216 failed at KIND-CELERY-PING: \"Re-dispatch once\""
  - "Operator, on the stray public v2.0 tag: \"Leave for now, note it\""
  - "Operator, at the Task 2 release gate: \"Approved — tag v1.1.0 and move v1\""
  - "Run 36159160216 failure classified as a transient harness flake (single-shot celery ping, 5s timeout), not an import regression; harness unchanged"
requirements-completed: []  # DDOJO-02 partial (8 of 10 plans); marked complete by 27-10
duration: ~40min (across checkpoints)
completed: 2026-09-25
---

# Phase 27 Plan 08: Post-merge proof on main and the v1.1.0 / v1 release

The DefectDojo import is now released additively on `v1` as ADR-018 requires. An annotated **`v1.1.0`** (tag object `414fd3beb5a6d79d52316150a192803a4b0ece78`) and the lightweight moving **`v1`** both point at the PR #21 merge commit **`0f7e4e141d2a300d4be9a54efc137eb4510bb7ea`**. `v1.0.0` still dereferences to `cdf2c21`, and the stray `v2.0` tag is untouched. The release https://github.com/OttawaCloudConsulting/security-platform/releases/tag/v1.1.0 is published and marked Latest. Before tagging, the executor observed two things on GitHub. First, the merge's closed event did not rescan. Second, the proof passed from `main` by dispatch, on the second of two operator-sanctioned attempts.

## Tasks

| Task | Name | Commit | Repo |
|------|------|--------|------|
| 1 | Record the closed-event run and a workflow_dispatch proof run on main | `e2b1e3a`, `a0b9886` | this repo (evidence) |
| 2 | Operator approval to tag v1.1.0 and move v1 | none (gate) | - |
| 3 | Tag v1.1.0, move v1, publish the release, verify through the API | `56b1b00` (evidence); tags and release on the remote | security-platform (remote) + this repo |

## Operator decisions (verbatim)

1. After the first dispatch run failed: **"Re-dispatch once"**. Exactly one re-dispatch was made, and the failed run was not rerun.
2. On the public `v2.0` tag: **"Leave for now, note it"**. Nothing was changed.
3. Task 2 release gate: **"Approved — tag v1.1.0 and move v1"**.

## Runs on GitHub

| Run | Event | Head | Result |
|-----|-------|------|--------|
| 36158851741 | pull_request (closed, 4s after merge) | 7c47270 | `skipped`: all 5 scan jobs plus DefectDojo Import and Cleanup skipped. D-15 held, with no rescan. Cleanup was skipped because security-platform sets no `DEFECTDOJO_URL`. |
| 36159160216 | workflow_dispatch | main 0f7e4e1 | **failure**: `prove-import` failed at `KIND-CELERY-PING` (`celery -A dojo inspect ping` exit 69, no nodes replied). The import assertions never ran. |
| 36160366711 | workflow_dispatch (re-dispatch) | main 0f7e4e1 | **success**: `prove-import` success, **PROOF PASS - 85 assertions**, smoke `ALL PASS - 13 live check(s)` |

The same tree passed `KIND-CELERY-PING` in PR run 36156728300 (27-07) and in 36160366711. Only 36159160216 failed. That points to a flaky harness check, not a code defect. The ping runs once with a 5s timeout, immediately after the Deployments report Available.

Check runs on the PR head 7c47270 (RESEARCH A2 / Pitfall 8): every `security / ...` context now has two check-runs. One is `success` from run 36156728417, and the newer one is `skipped` from the closed-event run 36158851741. PR #21 is merged, so this blocks nothing. It is the accepted reopen-window residual, T-27-11, recorded for ADR-024.

## Tags and release (Task 3)

| Ref | Before | After (API readback) |
|-----|--------|----------------------|
| `v1` | commit `cdf2c21` (lightweight) | `object.type` **commit**, `0f7e4e1` |
| `v1.1.0` | absent | `object.type` **tag** `414fd3b`, which dereferences to `0f7e4e1`. Message: `v1.1.0: opt-in DefectDojo import (DDOJO-02)` |
| `v1.0.0` | tag `fabc3e3` -> `cdf2c21` | unchanged |
| `v2.0` | tag `8d47cf9` -> `c6395e1` | unchanged |

- Pre-checks passed before any write. `origin/main` = `0f7e4e1`, remote `v1` = `cdf2c21`, and `v1.1.0` was absent.
- Pushes used only the explicit refspecs `refs/tags/v1.1.0` and `refs/tags/v1`. The `v1` push used `--force-with-lease=refs/tags/v1:cdf2c21...`, which the host's pre-push hook passed. The result was `+ cdf2c21...0f7e4e1 v1 -> v1 (forced update)`.
- The release was created with `gh release create v1.1.0 --verify-tag` and its notes passed inline (no `--notes-file`). The notes cover the opt-in import, the secret `DEFECTDOJO_API_TOKEN` and the variables `DEFECTDOJO_URL` / `_PRODUCT` / `_PRODUCT_TYPE` / `_CA_CERT` / `_INSECURE`, closed-event skip and cleanup, `scheduled-security.yml`, the `is_staff` token, unchanged required contexts, and the Mode B `closed` + `secrets:` edits. They end with the attribution lines, and the body contains no local paths (checked: 0 hits). `releases/latest` returns v1.1.0.
- `raw.githubusercontent.com/.../v1/.github/workflows/scheduled-security.yml` returned **HTTP 200** (3459 bytes) on attempt 1 of 3, so no retries were needed. The contents API blob `d2e1dbac` matches `origin/main`.
- The plan's `<verify>` command passed: `PLAN VERIFY: PASS (M=0f7e4e1...)`.

**v1 blast radius:** moving `v1` from `cdf2c21` to `0f7e4e1` publishes **62 commits**, measured with `git rev-list --count` (54 non-merge plus 8 merges). They span PRs #14-#21: Phase 23 (#14), Phase 24 (#15), Phase 25 (#16), Phase 26 (#19), the DefectDojo helm repo fix (#20), Phase 27 (#21), and two Dependabot action bumps (#17 codeql upload-sarif 4.38.1, #18 checkov-action 12.3125.0). The workflow diff is `4 files changed, 943 insertions(+), 15 deletions(-)`. The orchestrator's brief said 70 commits for Phases 23-27. The measurement here gives 62 for the same range. **The count of 62 is measured. The source of 70 was not found in any planning file.**

## Deviations from Plan

1. **[Process] Early evidence commits.** Task 1 said "Do not commit yet". The Task 1 evidence was committed anyway, at the checkpoints (`e2b1e3a` after the failed dispatch, `a0b9886` after the green re-dispatch), so it would survive the checkpoint agent handoff. Those commits used the `test(27-08)` type. Task 3 then committed the Tags section separately (`56b1b00`), using the plan's commit message. No content was lost or rewritten.
2. **[Adapted verify] Two dispatch runs.** The plan assumed a single dispatch run. The first (36159160216) failed at a pre-assertion smoke check. The executor stopped, and the operator chose "Re-dispatch once". Task 1's acceptance criterion ("dispatch proof run on main with prove-import success and PROOF PASS") is met by 36160366711. Both runs are recorded in evidence sections 4 and 4b.
3. **[Rule 2 - narrower write] `--force-with-lease` instead of plain `--force` for `v1`.** The lease pins the pre-checked remote value. It is strictly within the approved scope, and it would have refused to push if the remote had moved.
4. **[Readback tooling] `gh release view --json isLatest`.** This installed gh version rejects that field. The release had already been created. Latest was confirmed through `gh api .../releases/latest` and `gh release list`.

## Open concerns

- **Stray public `v2.0` tag** on OttawaCloudConsulting/security-platform (tag object `8d47cf9`, pointing at `c6395e1`). The operator chose "Leave for now, note it", so it remains untouched. It has no GitHub release, so it did not keep `v1.1.0` from becoming Latest. It is still a semver-higher public tag that a consumer might pin by mistake.
- **The parent planning repository's `origin` is the public security-platform repository.** Nobody should run `git push` from the parent. Pushing would publish planning history, and could move refs, on the public repo.
- **Recommended Phase 26 harness follow-up:** make `KIND-CELERY-PING` retry with a bounded budget (for example, several attempts over about 60s) instead of a single 5s-timeout attempt. That would stop a worker that is not yet registered from failing a whole proof run (see 36159160216).
- **Blast-radius count discrepancy (62 measured vs 70 in the brief):** see above.

## Threat model

- **T-27-09** (moving v1): mitigated. The operator saw the full `v1..origin/main` log and workflow diff stat at the blocking gate before any force-push. The push itself used a lease. `v1.0.0` remains the escape hatch. Both tags were read back through the API.
- **T-27-20** (release provenance): mitigated. `v1.1.0` is an annotated tag with a message, the release notes are inline, and every SHA is in the evidence.
- No new security surface was introduced outside the threat model.

## Self-Check: PASSED

- FOUND: .planning/phases/27-defectdojo-ci-auto-import/evidence/27-08-post-merge.txt
- FOUND commits: e2b1e3a, a0b9886, 56b1b00
- Remote: v1 commit 0f7e4e1; v1.1.0 tag 414fd3b -> 0f7e4e1; v1.0.0 -> cdf2c21; v2.0 -> c6395e1; release v1.1.0 Latest
