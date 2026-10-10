---
phase: 29-defectdojo-live-validation
plan: 19
subsystem: documentation
tags: [defectdojo, adr, arc, ddojo-05, records, d-12, d-17, d-20]
requires:
  - "29-01..29-18 SUMMARYs, deferred-items.md and evidence/ (sources of truth for every measured value)"
  - "29-18: security-platform PR #26 merged as fdabac9, v1.2.0 cut, v1 moved"
provides:
  - "docs/adr/adr027-defectdojo-homelab-live-validation.md: the Phase 29 decision and evidence record"
  - "docs/adr/adr028-repo-scoped-arc-runner-for-private-defectdojo-import.md: the ARC runner decision record"
  - "ADR index rows for ADR-027 and ADR-028"
  - "DDOJO-05 Complete in both REQUIREMENTS.md sites"
  - "D-12 cron observation: schedule run 36553070357 (success, import on ARC)"
affects: [phase-29-verification, milestone-v3.0-close]
tech-stack:
  added: []
  patterns:
    - "ADR citations checked mechanically: every evidence/<file> named in an ADR must exist at the commit that adds the ADR"
    - "D-20 hygiene checked twice: the plan's grep plus a wider grep for any dotted-quad IP, node, context or VLAN pool name"
key-files:
  created:
    - docs/adr/adr027-defectdojo-homelab-live-validation.md
    - docs/adr/adr028-repo-scoped-arc-runner-for-private-defectdojo-import.md
    - .planning/phases/29-defectdojo-live-validation/evidence/29-19-scheduled-runs.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-19-cron-run-jobs.json
  modified:
    - docs/adr/README.md
    - .planning/REQUIREMENTS.md
    - docs/adoption-guide.md
decisions:
  - "29-19: ADR-027 records the ghostunnel exposure as deployed (native sidecar via overlay values, operator decision B1), not the plan's stale 'standalone Deployment' wording, per the plan's own 29-08a context note"
  - "29-19: D-12 cron-fired run observed: 36553070357 (schedule, 2026-09-29T10:02:41Z, success, head 2fda1ac), DefectDojo Import on ARC runner occ-homelab-defectdojo-qqrsp-runner-hqpfs; ADR-027 NOT-verified item 6 says observed"
  - "29-19: ADR-027 records KIND-CELERY-PING as a known flake of the kind proof, using every red recorded in 29-06 and deferred-items (PR #24 run 36350180923 attempt 1, main run 36159160216, run 36502717161 attempt 1), not only the single 29-15 instance"
  - "29-19: DDOJO-05 marked Complete (checklist and traceability); the phase itself is NOT marked complete here (the orchestrator runs verification and phase.complete)"
metrics:
  duration: "~15min (2026-09-29T22:12Z to 22:27Z)"
  completed: 2026-09-29
  tasks: 3
  files: 7
# backfilled Phase 29.7 (v3.0 audit item 7); closure first recorded under provides
requirements-completed: [DDOJO-05]
---

# Phase 29 Plan 19: ADR-027, ADR-028 and DDOJO-05 closure Summary

This plan writes Phase 29's records from evidence. ADR-027 records the DefectDojo homelab live validation: exposure through an L2 VIP and a ghostunnel native sidecar, the CSRF Origin mechanism, `DEFECTDOJO_RUNS_ON`, and the D-11, second-sync and NetworkPolicy results. It also records the queue-not-fail behaviour, every accepted risk, and the trivy-image cross-branch dedup gap with its step-2 amendment. ADR-028 records the repository-scoped ARC scale set that the personal account type forced. DDOJO-05 is Complete in both REQUIREMENTS.md sites. A cron-fired scheduled run was observed and is recorded with its run ID.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | ADR-027, with the D-12 cron evidence | `f6a05ea` | docs/adr/adr027-defectdojo-homelab-live-validation.md, evidence/29-19-scheduled-runs.json, evidence/29-19-cron-run-jobs.json |
| 2 | ADR-028 and both index rows | `1d4b590` | docs/adr/adr028-repo-scoped-arc-runner-for-private-defectdojo-import.md, docs/adr/README.md |
| 3 | DDOJO-05 closure, adoption-guide note, gate | `1416b4a` | .planning/REQUIREMENTS.md, docs/adoption-guide.md |

## Verification (observed)

- Task 1 verify: `TASK1-VERIFY-OK`. ADR-027 is 375 lines and has `## Context`, `## Decision`, `### Measured evidence`, `## Consequences` and `## What was NOT verified`. It names the queue-not-fail behaviour and the never-a-required-check rule.
- Task 2 verify: `TASK2-VERIFY-OK`. ADR-028 is 202 lines and contains `Administration`. `git diff docs/adr/README.md | grep '^-' | grep -v '^---'` returned nothing, so no existing row changed.
- Task 3 verify: `TASK3-VERIFY-OK`. `bash scripts/check-adoption-guide.sh` printed `PASSED 16 / FAILED 0`, and markdownlint reported zero violations.
- D-20: the plan's grep (`10\.40\.|10\.30\.|ottawacloudconsulting\.com|admin@occ|worker0|k8w0`) returns 0 on both ADRs. A wider grep for any dotted-quad address, `occ-cs-`, `occ-new`, `vlan4N`, `.infra.`/`.home.` FQDN fragments and `~/.config/` paths also returns 0 on both.
- Citation check: every `evidence/<file>` named in either ADR exists, 38 files for ADR-027.
- Append-only: `git diff --name-only HEAD~3 HEAD -- docs/adr/adr02[2-6]*` is empty, so ADR-022 to ADR-026 are untouched.
- REQUIREMENTS diff: exactly three lines changed: the checkbox, the traceability row, and the footer, now `*Last updated: 2026-09-29 after Phase 29*`.

## D-12 cron observation

`gh run list -w scheduled-security.yml` (`evidence/29-19-scheduled-runs.json`) shows `schedule` run **36553070357**. It was created at `2026-09-29T10:02:41Z` with conclusion `success`, after the 29-14 settings time of 2026-09-29T00:14:10Z. The job read-back (`evidence/29-19-cron-run-jobs.json`) shows `security / DefectDojo Import` succeeding on runner `occ-homelab-defectdojo-qqrsp-runner-hqpfs` with labels `["occ-homelab-defectdojo"]`, and the five scans on `ubuntu-latest`. The list also shows schedule run `36407382568` (2026-09-28, `failure`). It predates the settings and its cause was not investigated, so neither ADR describes it.

## Must-record items from the orchestrator: where each landed in ADR-027

| Item | Location |
|------|----------|
| Trivy image dedup gap (59 active in Test 12, 96 others duplicates; Phase 28 never exercised differing tags) | Consequences, "Tradeoff — trivy-image findings do not dedupe across branches"; Measured evidence, D-11 step 2 |
| Step-2 scope amendment (operator ruling 2026-09-29, 29-CONTEXT) | NOT verified item 4, sub-bullet next to re-parenting |
| Fixes shipped in PR #26 `fdabac9`, `v1.2.0` | Same Tradeoff paragraph (commits `71a388c`, `0f401f7`); Decision 5 for the tag |
| Follow-up (b) open, hash field unverified | NOT verified item 4, sub-bullet |
| 29-17 second sync and the accepted 10h41m gap | Measured evidence, "Second sync over real data", with the post-gap readback |
| KIND-CELERY-PING known flake | Consequences, "Known flake" |
| 29-18 accepted 429 red check | Consequences, "Accepted red check" |
| 29-14 `email` field, wrong token-check endpoint, user id 2 deleted, final id 3 | Consequences, "Process record" |

**Flake count: I followed the evidence, not the brief.** The brief said the ping "flaked once (run 36502717161 attempt 1)". 29-06 also records the same KIND-CELERY-PING red on PR #24 (run `36350180923` attempt 1, green on rerun) and on `main` (run `36159160216`, followed by green run `36160366711`). ADR-027 lists all three and the PR #26 pass. It calls the failure a known flake of the kind proof, and it calls the readiness-race explanation an inference.

## Deviations from Plan

**1. [Orchestrator directive] Per-task commits instead of one Task 3 commit.** The plan's Task 3 says to commit all Task 1-3 files in one commit. The orchestrator requires one commit per task, so there are three. The Task 3 commit uses the plan's message, `docs(29-19): ADR-027, ADR-028 and DDOJO-05 closure`.

**2. [Plan context note] ADR-027 Decision 1 describes the native sidecar.** Task 1 point 1 still says "a standalone ghostunnel Deployment". The plan's own `<context>` note (added in 29-08a) says to change that wording. Decision 1 records the first-built standalone Deployment, the CrashLoopBackOff, the operator's `B1: overlay values` ruling and the deployed sidecar. The arg-semantics lesson is in Consequences.

**3. [Rule 2 - Evidence completeness] Added `evidence/29-19-cron-run-jobs.json`, which is outside `files_modified`.** ADR-027 claims the cron run imported on ARC. The run list alone does not show job placement, so the `gh api .../runs/36553070357/jobs` read-back was saved so that the claim cites a file.

**4. [Ordering] The D-12 evidence was captured and committed with Task 1, not Task 3.** ADR-027 item 6 depends on it. Committing it with the ADR means the citation resolves at the commit that makes it. Task 3's "edit ADR-027 only to fill in item 6" was therefore not needed as a separate edit.

**5. [Placement] Adoption-guide note.** The honesty line sits inside a fenced bash block as a `##` comment. The new sentence was added as three `##` comment lines directly after it, and it keeps the original meaning for the other commands.

**6. [Numbering] Trivy-image gap as a sub-bullet of NOT-verified item 4.** This keeps the plan's item numbers, with item 6 as the cron status, and places the gap "next to the re-parenting item", as deferred-items asks.

## Operator notes (action is the operator's call)

- **The admin token file still exists:** `~/.config/defectdojo/homelab-admin.token`. As read (mode and size only, never the contents), it is mode 600 and 41 bytes. Deleting or rotating it is the operator's call; Claude has not deleted it (T-29-18).
- **GitGuardian incident 37678807** ("Django Secret Key" on SealedSecret ciphertext) is still an open false positive to dismiss (29-07).
- **Remote branches not deleted:** occ-k8s-app-config `fix/defectdojo-ghostunnel-native-sidecar`, `feat/arc-systems` and `feat/arc-runners`; occ-k8s-cluster-config `docs/vlan43-vip-inventory-refresh`. Delete them on request.
- **Follow-up (b)**, a fixed scan-image tag for trivy-image dedup, is OPEN (deferred-items).

## Threat model

- T-29-09 (homelab literals): mitigated. Both D-20 greps return 0, and so does the wider IP, node, context and pool grep.
- T-29-25 (accepted risks recorded silently): mitigated. Each accepted risk has an explicit Tradeoff paragraph across the two ADRs: the public-repo runner, PAT breadth, no egress policy, plaintext :80, no backup, the queue behaviour and the proof-workflow stall. Operator rulings are quoted verbatim.
- T-29-18 (lingering superuser token): accepted, and reported above.
- T-29-SC: no installs.

## Known Stubs

None.

## Threat Flags

None. This plan adds documentation and two read-only evidence files only.

## Self-Check: PASSED

- FOUND: docs/adr/adr027-defectdojo-homelab-live-validation.md, docs/adr/adr028-repo-scoped-arc-runner-for-private-defectdojo-import.md, evidence/29-19-scheduled-runs.json, evidence/29-19-cron-run-jobs.json
- FOUND commits: f6a05ea, 1d4b590, 1416b4a
