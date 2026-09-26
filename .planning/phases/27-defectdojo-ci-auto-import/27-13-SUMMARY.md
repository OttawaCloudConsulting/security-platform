---
phase: 27-defectdojo-ci-auto-import
plan: 13
subsystem: ci-defectdojo-side-channel
tags: [security, defectdojo, tls, cr-01, gap-closure, release, tags]
gap_closure: true
requires: ["27-12"]
provides:
  - "Dispatch proof on main at 917352c: run 36188604648, PROOF PASS - 88 assertions with 3 P-HTTP PASS lines"
  - "Annotated v1.1.1 (tag object c1565b3) and lightweight v1, both at 917352c (CR-01 merge)"
  - "Release v1.1.1 published on security-platform"
affects: ["27-14 (ADR-025)", "every @v1 / /v1/ consumer", "Phase 29"]
tech-stack:
  added: []
  patterns: ["operator-gated public tag move", "force-with-lease pinned to pre-checked SHA", "API readback after every remote write"]
key-files:
  created:
    - .planning/phases/27-defectdojo-ci-auto-import/evidence/27-13-post-merge.txt
  modified: []
decisions:
  - "Operator approved the tag and v1 move: \"Approved — tag v1.1.1 and move v1\""
  - "Operator authorized the orchestrator to create the release after the executor's attempt was denied: \"Run it yourself, I give you permission to\""
  - "CR-01 released as patch v1.1.1 (security fix, no interface change, ADR-018)"
metrics:
  started: 2026-09-25T20:54Z
  completed: 2026-09-26T02:11Z
  duration: "~5h17m wall clock, mostly waiting on two operator gates"
  tasks: 3
  files: 1
---

# Phase 27 Plan 13: Release CR-01 as v1.1.1 and move v1 Summary

The CR-01 https-only fix is now what every `@v1` and `/v1/` consumer runs.
- The dispatch proof ran green on main at merge commit 917352c on its first attempt.
- Annotated `v1.1.1` and the lightweight moving `v1` both point to 917352c00987023fa5ff1e6cdabc16987eb114dd.
- Release v1.1.1 is published: https://github.com/OttawaCloudConsulting/security-platform/releases/tag/v1.1.1
- `v1.1.0`, `v1.0.0` and `v2.0` were not touched.

## Key facts

| Item | Value |
|------|-------|
| Dispatch proof | run 36188604648, attempt 1, `workflow_dispatch` on main, head 917352c. The run and the prove-import job (108248236695) both concluded success |
| Proof lines | `KIND-CELERY-PING: PASS`, `ALL PASS - 13 live check(s)`, P-HTTP PASS for import-http, import-noscheme and delete-http, `PROOF PASS - 88 assertions` |
| v1.1.1 | ref `object.type` tag, pointing to tag object c1565b35e88de4e70e61d79292943c15b3fe67f6, which points to 917352c00987023fa5ff1e6cdabc16987eb114dd |
| v1 | ref `object.type` commit at 917352c00987023fa5ff1e6cdabc16987eb114dd; previously 0f7e4e141d2a300d4be9a54efc137eb4510bb7ea |
| Unchanged | v1.1.0: 414fd3b, pointing to 0f7e4e1. v1.0.0: fabc3e3, pointing to cdf2c21. v2.0: 8d47cf9, pointing to c6395e1 |
| Raw /v1/ | `security.yml` contains `url.lower().startswith("https://")` 2 times, on attempt 1 |
| Release | v1.1.1, not a draft or prerelease, published 2026-09-26T02:10:39Z. Scanning the body for local paths found 0 hits |

## Operator replies (verbatim)

1. **Task 2, tag approval:** "Approved — tag v1.1.1 and move v1". Before replying, the operator saw:
   - `git log --oneline v1..origin/main`: only ba3683a and the 917352c merge. No commit other than CR-01 was in the range.
   - The workflow diff stat: `security.yml` 12+/2-.
   - The expected API readbacks.
   - The consumer impact: http:// `DEFECTDOJO_URL` consumers get red import and cleanup jobs on their next run.
2. **Release creation:** "Run it yourself, I give you permission to". The orchestrator relayed this reply after the permission system denied the executor's release command.

## Task results

**Task 1:**
- Fetched with `--tags` and confirmed `origin/main` = 917352c.
- Recorded the pre-tag refs verbatim; v1.1.1 returned 404.
- Dispatched the proof and it passed on the first attempt.
- The `<verify>` block passed.

**Task 2:** I showed the log and the diff stat, then stopped. No tag was written. The operator approved.

**Task 3:**
- Before any write, re-confirmed `origin/main` = 917352c and remote v1 = 0f7e4e1.
- Pushed v1.1.1 with the explicit refspec `refs/tags/v1.1.1` and read it back.
- Moved v1 with `--force-with-lease=refs/tags/v1:0f7e4e1...` using the explicit refspec `refs/tags/v1` (`+ 0f7e4e1...917352c (forced update)`) and read it back.
- The executor's `gh release create` was denied (see Deviations). The orchestrator created the release with the operator's authorization, and I read it back with `gh release view`.
- The raw /v1/ check passed.
- The `<verify>` block printed TASK3_VERIFY_OK.

## Commits

| Repo | SHA | Message |
|------|-----|---------|
| outer | 1a964a8 | docs(27-13): record CR-01 dispatch proof and v1.1.1 tag / v1 move |
| outer | e5a5237 | docs(27-13): record v1.1.1 release readback |
| security-platform | (refs only) | refs/tags/v1.1.1 created, refs/tags/v1 moved. No commits |

## Deviations from Plan

**1. [Permission gate] The executor did not create the release.**
- The Claude Code auto-mode classifier denied the executor's `gh release create v1.1.1 --verify-tag ...` with the reason "Create Public Surface". The command never ran, and the executor did not retry it or work around it.
- The orchestrator relayed that the operator's own earlier `!` attempt did not create the release.
- The operator then authorized the orchestrator ("Run it yourself, I give you permission to"), and the orchestrator created the release.

**2. [Process] `--notes-file` was used instead of the plan's inline `--notes`.**
- The orchestrator used `--notes-file <scratchpad>/v1.1.1-release-notes.md`.
- The plan asked for inline notes so that no local paths could leak into the release.
- The published body contains 0 local paths and matches the prepared notes, so that risk did not happen.

## Deferred

The KIND-CELERY-PING retry budget from 27-08 and 27-12 is still open. It passed this time on the first attempt.

## Threat Flags

None. T-27-09 was mitigated: blocking approval, a pinned lease, explicit refspecs and a readback after each write. T-27-24 was mitigated: the raw /v1/ file serves the fix.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: evidence/27-13-post-merge.txt (contains `v1.1.1`, `PROOF PASS - 88 assertions`, `P-HTTP PASS`)
- FOUND: 27-13-SUMMARY.md
- FOUND: outer commits 1a964a8 and e5a5237
- `ls-remote`: refs/tags/v1 -> 917352c; refs/tags/v1.1.1 -> c1565b3, which peels (`^{}`) to 917352c
- `gh release view v1.1.1` succeeds
