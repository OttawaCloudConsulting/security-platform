---
phase: 29-defectdojo-live-validation
plan: 03
subsystem: documentation
tags: [defectdojo, adoption-guide, self-hosted-runner, arc, docs-gate]
requires: []
provides:
  - "docs/adoption-guide.md section 12: DEFECTDOJO_RUNS_ON setting, self-hosted reachability route, queue-not-fail behaviour, per-repo scale set / fork-approval / runner-update caveats"
  - "scripts/check-adoption-guide.sh DD_REQUIRED: 16 strings (adds DEFECTDOJO_RUNS_ON, all_external_contributors, queue)"
affects: [29-19]
tech-stack:
  added: []
  patterns:
    - "gh variable set NAME --body ... -R OWNER/REPO line followed by ## comment lines, same as the existing Settings block"
key-files:
  created: []
  modified:
    - docs/adoption-guide.md
    - scripts/check-adoption-guide.sh
decisions:
  - "Both files were committed in one commit, as the plan's Task 2 action directs, rather than one commit per task. Task 1 has no separate commit."
  - "The 'None of these commands was executed against any pilot repository' line stays unchanged; plan 29-19 revisits it after the live proof."
  - "What You Will See also records that a cancelled cleanup orphans the ci/<branch> engagement and how to recover (RESEARCH Pitfall 8). This goes slightly beyond the plan's text."
  - "DDOJO-05 is not marked complete; plan 29-19 does that."
metrics:
  duration: "~10min"
  completed: 2026-09-27
  tasks: 2
  files: 2
---

# Phase 29 Plan 03: Adoption guide DEFECTDOJO_RUNS_ON Summary

Section 12 of the adoption guide now documents the optional `DEFECTDOJO_RUNS_ON` routing variable. Unset, both DefectDojo jobs keep `ubuntu-latest`; the variable is available from v1.2.0. The section also documents the self-hosted runner reachability route and replaces the old "belongs to Phase 29" prerequisite. The standing gate now requires the new strings and passes: 16/16 checks, and the DEFECTDOJO-SECTION check carries 16 required strings.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Rewrite section 12 Prerequisites; add DEFECTDOJO_RUNS_ON to Settings, What You Will See, Caveats | 3550de0 | docs/adoption-guide.md |
| 2 | Extend DD_REQUIRED and run the gate green | 3550de0 | scripts/check-adoption-guide.sh |

## What changed

- **Prerequisites:** the paragraph was rewritten. It keeps the reachable-from-the-runner sentence, then lists two routes: a public URL on GitHub-hosted runners, or a private instance reached through an ARC runner scale set named in `DEFECTDOJO_RUNS_ON`. Only the Import and Cleanup jobs move to that runner; the five scan jobs stay on `ubuntu-latest`. The sentences "is not covered by this guide" and "belongs to a later phase" were removed. "An unreachable URL does not break your pipeline" was kept.
- **Settings:** a `gh variable set DEFECTDOJO_RUNS_ON --body <runner-scale-set-name> -R OWNER/REPO` line was added, with comments: optional, unset means ubuntu-latest, the value is the scale set name used as the runs-on label, it is read from the caller repository like `DEFECTDOJO_URL`, and it is available from v1.2.0.
- **What You Will See:** a paragraph was added. An offline runner, or one 30 days without an update, makes the job queue rather than fail. GitHub cancels a job queued for about 24 hours. Merge is unaffected because the job is not a required check, and it must never be made one.
- **Caveats:** three bullets were added: per-repository scale sets, with the fine-grained PAT and its Administration RW breadth; fork PR approval set to `all_external_contributors` before the variable is set; and keeping the runner image current (the 30-day rule).

## Verification (observed)

- Task 1 automated check: PASS. Section 12 contains `DEFECTDOJO_RUNS_ON` 4 times, `24 hours` once and `is not covered by this guide` 0 times. The homelab-literal grep returns no matches.
- `bash scripts/check-adoption-guide.sh`: exit 0, `PASSED 16 / FAILED 0`. DEFECTDOJO-SECTION reports lines 599-867 carrying all 16 strings. MARKDOWNLINT reports zero violations.
- `grep -c '"DEFECTDOJO_RUNS_ON"' scripts/check-adoption-guide.sh` returns 1. No removed lines in the gate diff.

## Deviations from Plan

- The plan's task commit protocol calls for one commit per task. The plan's own Task 2 action instead directs a single commit of both files with a fixed message, and that was followed. This is recorded as a decision, not a Rule 1-3 fix.
- The orphaned-engagement recovery sentence in What You Will See is an addition sourced from RESEARCH Pitfall 8.

## Known Stubs

None.

## Self-Check: PASSED

- docs/adoption-guide.md and scripts/check-adoption-guide.sh modified: FOUND
- Commit 3550de0: FOUND
