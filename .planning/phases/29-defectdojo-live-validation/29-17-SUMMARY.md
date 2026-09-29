---
phase: 29-defectdojo-live-validation
plan: 17
subsystem: k8s-infrastructure
tags: [defectdojo, argocd, second-sync, idempotency, staticName, sync-hook, pitfall-4, d-14, ddojo-05]
requires:
  - "29-16: ci/main engagement 1 at 155 findings, with dispositions FP 3, OOS 10, RA 22 (evidence/main-after-reimport-snapshot.json)"
  - "29-01: security-platform scripts/defectdojo-homelab-validate.sh (--write-state / --sync-pass second / SECOND-SYNC-IDEMPOTENT)"
  - "29-08/29-08a: the previous initializer run at history id 1 (evidence/29-08-initializer-postfix.log)"
provides:
  - "D-14 second-sync idempotency measured live over real data: SECOND-SYNC-IDEMPOTENT PASS, gate ALL PASS with 8 checks and 0 skipped"
  - "10-minute no-drift observation at a fixed revision with real data present (Pitfall 4 falsifier not observed)"
  - "initializer.staticName plus the Sync-hook/BeforeHookCreation choice validated by measurement"
affects: [29-18, 29-19, ADR-023, DDOJO-05]
tech-stack:
  added: []
  patterns:
    - "Before triggering a same-revision sync on a multi-source Application, check with git ls-remote that the tracking-branch source has not moved"
    - "Show counts were preserved by finding-id identity (same id set, no id above the prior max), not by cardinality alone"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-17-pre-state.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-17-drift-watch.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-17-second-sync-application.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-17-initializer-second.log
    - .planning/phases/29-defectdojo-live-validation/evidence/29-17-homelab-validate-second.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-17-post-gap-readback.json
  modified: []
decisions:
  - "29-17: the initializer.staticName plus Sync-hook (BeforeHookCreation) choice is kept. A same-revision second sync over real data (155 findings) re-created the Job and the PreSync ServiceAccount with new UIDs, took the idempotent path, preserved every finding id and disposition, and 10 minutes at a fixed revision showed no drift"
  - "29-17: a scheduled reimport (run 36553070357, about 10:03Z) fell inside the 02:41Z-13:22Z gap between the second sync and the second-pass gate. It is accepted as non-confounding, because a readback shows the same 155 finding ids (max id 155) and identical disposition flags. A rerun in a clean window is left to the operator"
metrics:
  duration: "~11h wall clock (about 20 min active; the session paused about 10h41m between Task 1 and Task 2)"
  completed: 2026-09-29
---

# Phase 29 Plan 17: Second-sync idempotency over real data Summary

With real data present (1 product, 155 findings, 3 dispositions), a same-revision second Argo CD sync re-created the `defectdojo-initializer` Job and the PreSync `defectdojo` ServiceAccount with new UIDs. The initializer took the idempotent path, with the admin-exists marker, no migrations and no first-boot step. The product and finding counts, the finding ids and the dispositions were all unchanged. The Application also showed no drift for 10 minutes before the sync. `SECOND-SYNC-IDEMPOTENT` PASSed, and the gate reported `ALL PASS - 8 live check(s) executed and passed; 0 sub-check(s) skipped`.

## Measurements

| Item | Before (pre-state 02:30:16Z) | After (second sync 02:41:33Z, gate 13:22Z) |
|------|------------------------------|--------------------------------------------|
| Job defectdojo-initializer UID | `e43a2dcf-7c4c-4415-931d-f5f5952c1482` (created 2026-09-28T12:18:15Z) | `7b2753fd-ca89-4e1d-a4e8-576b885fadee` (created 2026-09-29T02:41:17Z) |
| ServiceAccount defectdojo UID | `d163032c-3542-4d63-9538-d556fb8c5c22` (created 2026-09-28T12:18:11Z) | `84144fe3-224f-4fb9-8026-361c936f8be0` (created 2026-09-29T02:41:14Z) |
| app_revision (`.status.sync.revisions`) | `[c8027e6…, 11e6614…]` | `[c8027e6…, 11e6614…]` |
| product_count | 1 | 1 |
| finding_count | 155 | 155 |
| Argo history last id | 1 | 2 (the second sync), and still 2 at 13:22Z |

Second sync (`argocd app sync defectdojo --timeout 900`, 02:41:11Z to 02:41:34Z, rc 0): the operation reached `Succeeded` in 21s with "successfully synced (no more tasks)". In `syncResult.resources`, ServiceAccount `defectdojo` shows hookType PreSync, hookPhase Succeeded, "defectdojo created", and Job `defectdojo-initializer` shows hookType Sync, hookPhase Succeeded. `operationState.syncResult.revisions` equals the pre-state revisions.

The pre-state gate run (`--sync-pass first --write-state`) exited 0: 7 checks passed, with the expected SECOND-SYNC SKIP on a first pass and 0 FAIL. `git ls-remote` on `occ-k8s-app-config` `main` returned `11e6614` both before the pre-state and right before the sync, so the tracking-branch source did not move.

## Drift watch (evidence/29-17-drift-watch.txt)

11 samples at 60s intervals, from 02:30:23Z to 02:40:25Z (a span of 10m02s). Every sample is `Synced Healthy`, with revisions `[c8027e6…, 11e6614…]` and history id `1`. There was no OutOfSync sample and no new history id, so the Pitfall 4 drift falsifier was not observed. Separately, and not sampled, history stayed at id 2 from 02:41:33Z until at least 13:22Z.

## Revision each initializer run belongs to

- First run: `evidence/29-08-initializer-first.log` (history id 0, overlay `cc7fbc9`). This is the only first-boot log.
- Previous run: `evidence/29-08-initializer-postfix.log` (history id 1, 2026-09-28T12:19:11Z, revisions `[c8027e6, 08ce26b]`).
- This run: `evidence/29-17-initializer-second.log` (history id 2, 2026-09-29T02:41:33Z, revisions `[c8027e6, 11e6614]`).

The overlay moved from `08ce26b` to `11e6614` between history 1 and the pre-state. The GitHub compare shows 14 commits (ARC controller/runners and LightRAG work) and no file under `application-sets/platform/defectdojo/`. The rendered manifests are therefore the same, which is why Argo stayed Synced without a new operation. This run is at the same revision as the pre-state, not at the git revision of the previous run.

## Initializer log diff notes

- `29-17-initializer-second.log` compared with `29-08-initializer-postfix.log`: after stripping the header line, the `[dd/Mon/yyyy hh:mm:ss]` timestamps and the wait-for-it seconds, both logs are 90 lines and `diff` exits 0 (identical). Both logs contain `  No migrations to apply.` (line 86) and `Admin user already exists; skipping first-boot setup` (line 88).
- Compared with `29-08-initializer-first.log` (474 lines): the first log has 274 `  Applying <app>.<NNNN>` lines, a `JIRA Webhook Secret:` line (already redacted in that file) and `Running first boot setup`. None of these appear in the second log. `grep -c 'JIRA Webhook Secret'` on the second log returns 0, so there was nothing to redact.

## Deviations from Plan

### Measurement-window gap (session pause)

- **Found during:** Task 2
- **What happened:** the initializer log and the Application JSON were captured at 02:41Z, right after the sync. The second-pass gate then ran at 13:22Z, because the session paused for about 10h41m. The CSRF log line in the gate output (`29/Sep/2026 13:22:10`) matches the gate time, and the workstation and pod clocks agreed (13:22:23Z).
- **Concurrent writer:** Scheduled Security run `36553070357` (event schedule, headSha `2fda1ac`, the same main SHA as the 29-16 reimport) ran `DefectDojo Import` successfully in the gap. All 8 ci/main tests show `updated` between 10:03:34Z and 10:03:38Z.
- **Exposure per sub-assertion:** the UIDs, the initializer log and the revision were captured before the gap and were unchanged at 13:22Z (same Job UID, history still 2), so the gap does not affect them. Only the counts were exposed.
- **Compensating check (added artifact `evidence/29-17-post-gap-readback.json`):** an admin API readback of engagement 1 shows 155 findings with ids exactly equal to `main-after-reimport-snapshot.json` (02:01:11Z, before the pre-state), max id 155, and identical `active/false_p/out_of_scope/risk_accepted/is_mitigated/duplicate` flags (FP 3, OOS 10, RA 22). The reimport updated existing findings and created none. If the sync had wiped data and the reimport had refilled it, there would be new ids above 155, so the preserved counts are supported by id identity.
- **Not done:** a third sync to re-measure in a clean window. That would create hook resources beyond what the plan specifies, so the operator decides whether to run it.

## Known Stubs

None.

## Threat Flags

None. Mitigations: the argocd token was read inline into an env var and never echoed (T-29-03). The admin token was used by path through the gate and through a 0600 header file in the scratchpad, deleted after use. All six evidence files were scanned with `grep -qF -f` against both token files, with no match. The revision was asserted equal (T-29-24). Counts and ids were asserted equal, and the PVC was not touched (T-29-13).

## Commits

- `75bce2a` docs(29-17): capture pre-state, 10-minute drift watch and same-revision second sync
- `4c7e85c` docs(29-17): prove second-sync idempotency live (SECOND-SYNC-IDEMPOTENT PASS, ALL PASS 0 skipped)

## Self-Check: PASSED

All six evidence files exist and are tracked; commits 75bce2a and 4c7e85c exist; repos/security-platform is on main.
