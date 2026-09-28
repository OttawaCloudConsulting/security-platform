---
phase: 29-defectdojo-live-validation
plan: 08
subsystem: k8s-infrastructure
tags: [defectdojo, argocd, live-validation, tls, csrf, celery, d-14, ddojo-05]
requires:
  - "29-01: defectdojo-homelab-validate.sh (security-platform 9726b35, on main)"
  - "29-07: overlay live, Application defectdojo exists"
  - "29-08a: ghostunnel native sidecar (overlay 08ce26b), Application Synced/Healthy since 2026-09-28T12:19:11Z"
provides:
  - "Post-fix Application, cluster, image-pull and initializer evidence (later sync, revisions [c8027e6 pin, 08ce26b])"
  - "First-pass live gate: 7 PASS, SECOND-SYNC-IDEMPOTENT skipped, exit 0, on both hostnames"
affects: [29-10, 29-11, 29-17, 29-18]
tech-stack:
  added: []
  patterns:
    - "Resume after a gap-closure plan: earlier-run evidence stays frozen (git diff --quiet against its commit); the later-run capture goes to a new file with a header that names its revision"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08-first-sync-application.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08-first-sync-cluster.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08-image-pulls.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08-initializer-postfix.log
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08-homelab-validate-first.txt
  modified: []
decisions:
  - "29-08: the Application/cluster evidence describes the later sync (op finished 2026-09-28T12:19:11Z on [c8027e6, 08ce26b]), not the first; the first-run initializer baseline stays 29-08-initializer-first.log (a40c5a8, unchanged)"
  - "29-08: D-14 for postgresql/valkey/celery uses the live imageIDs plus 29-08-image-pulls.pre-ghostunnel-fix.txt, because those pods are 11h old and their Pulled events have aged out; django and initializer Pulled events are still live"
  - "29-08: the gate ran without --write-state (not in the plan's flags or files_modified), so plan 29-17 must capture its own pre-state"
  - "29-08: DDOJO-05 is not marked complete; later plans (29-10 onward) still own the token, import and second-sync proofs"
metrics:
  duration: "~10min (resume session 13:08Z-13:18Z)"
  completed: 2026-09-28
  tasks: 2
  files: 5
---

# Phase 29 Plan 08: DefectDojo first-sync evidence and live gate first pass Summary

DefectDojo is live on the homelab and measured green. The Application is Synced, Healthy and Succeeded at the pinned security-platform SHA. The first pass of `defectdojo-homelab-validate.sh` gave 7 PASS, 1 expected SKIP (`SECOND-SYNC-IDEMPOTENT`) and exit 0 on both hostnames. That run covers TLS against the system trust store with both SANs, the Origin login (302, then `/dashboard` 200) on both hosts, the foreign-Origin 403, which the uwsgi `django.security.csrf` log attributes to the Origin check, and a Celery pong.

## Which sync this evidence describes

The plan was resumed after gap-closure plan 29-08a. The Application JSON, the cluster file and the postfix initializer log all describe the **later** sync. That operation finished at `2026-09-28T12:19:11Z` on revisions `[c8027e6784ec631db128f45444c9a8092db9d0a1, 08ce26bf751b93f7aa9193d6412907bec710b63f]`. It is not the first sync. `revisions[0]` still equals the pin, so that assertion holds unchanged. The `hookPhase Succeeded` for the initializer Sync hook in `syncResult` belongs to the later run (pod `defectdojo-initializer-552xn`).

The first-run evidence is still what `a40c5a8` committed, and none of it was modified. `git diff --quiet a40c5a8 --` passed on `29-08-initializer-first.log`, `29-08-first-sync-application.pre-ghostunnel-fix.json` and `29-08-image-pulls.pre-ghostunnel-fix.txt`.

## Task 1: measured values

| Item | Measured |
|------|----------|
| Application read | Captured at `2026-09-28T13:10:44Z`. The stop condition held on the first read, so no poll loop was needed |
| sync / health / operation | `Synced` / `Healthy` / `Succeeded` |
| `revisions[0]` | `c8027e6784ec631db128f45444c9a8092db9d0a1`, equal to the 29-05 pin (explicit string compare) |
| `revisions[1]` | `08ce26bf751b93f7aa9193d6412907bec710b63f`, the 29-08a overlay merge |
| conditions | none, so there is no ComparisonError |
| hooks in syncResult | `Job/defectdojo-initializer` Sync Succeeded, and `ServiceAccount/defectdojo` PreSync Succeeded (RESEARCH Pitfall 4, expected) |
| LB VIP (`svc/defectdojo-ghostunnel`) | `10.40.3.65` |
| Certificate `defectdojo-tls` Ready | `True` (issuer `letsencrypt-dns01-prod`) |
| PVC `data-defectdojo-postgresql-0` | `Bound`, StorageClass `default`, UID `76aa54bc-51bf-487c-9ed9-dd3f9115f4f2` (same as the 29-08a baseline) |
| SealedSecrets | the 3 SealedSecrets are Synced True; there are 4 Secrets |
| Pods | celery-beat, celery-worker, postgresql-0 and valkey-0 have been Running for 11h. django `7bd88b9f6b-grm9j` is 3/3 (ghostunnel `tls` sidecar included). The initializer is Completed. All show 0 restarts |

### Image pulls (D-14)

| Image | imageID digest | Source used |
|-------|----------------|-------------|
| `us-docker.pkg.dev/os-public-container-registry/defectdojo/bitnami/postgresql:17.6.0-debian-12-r4` (GAR) | `sha256:926356130b77…a710a8d` | live imageID, plus the Pulled event in `29-08-image-pulls.pre-ghostunnel-fix.txt` (event aged out live) |
| `docker.io/defectdojo/defectdojo-django:3.3.200` | `sha256:1cee5281e176…c37c1ed` | live Pulled events (django and initializer pods) and imageIDs |
| `docker.io/defectdojo/defectdojo-nginx:3.3.200` | `sha256:825d9ad8abaf…70c6e5f9` | live Pulled event and imageID |
| `docker.io/valkey/valkey:9.1.0-alpine3.23@sha256:c9b7…` | `sha256:c9b77919daeb…f405daf9e02` | live imageID plus the pre-fix file |
| `docker.io/ghostunnel/ghostunnel:v1.11.3-distroless` (`tls` init container) | `sha256:51fa619294ac…f43f4faf` | live imageID ("already present on machine") |

The live event list still holds one aged event for the pruned `defectdojo-ghostunnel-6688884646-crddv` pod. The file records it as-is.

### Postfix initializer log

`29-08-initializer-postfix.log` has 91 lines and a header that names both revisions. It shows the idempotent path: `No migrations to apply.` and `Admin user already exists; skipping first-boot setup`. It contains 0 `  Applying <app>.<NNNN>` lines and 0 `JIRA Webhook Secret` lines, so nothing needed redacting, and 0 password values.

## Task 2: gate verdict table (evidence/29-08-homelab-validate-first.txt)

The command was run from `repos/security-platform` on branch `feature/phase-29-defectdojo-live-validation` (HEAD `e8387a8`). There, `git diff HEAD origin/main -- scripts/defectdojo-homelab-validate.sh` is empty, so the script is the merged `9726b35` version. The flags were exactly as the plan gives them: `--context admin@occ-new --namespace defectdojo --app defectdojo --sync-pass first`, with no `--token-file` and no `--write-state`.

| Check | Verdict | Measured |
|-------|---------|----------|
| HOMELAB-TLS-INFRA | PASS | `/login` returned 200, ssl_verify_result 0, and both SANs were served |
| HOMELAB-TLS-HOME | PASS | `/login` returned 200, ssl_verify_result 0, and both SANs were served |
| HOMELAB-LOGIN-ORIGIN-INFRA | PASS | POST with `Origin: https://defectdojo.infra...` returned 302, then `/dashboard` returned 200 |
| HOMELAB-LOGIN-ORIGIN-HOME | PASS | POST with `Origin: https://defectdojo.home...` returned 302, then `/dashboard` returned 200 |
| HOMELAB-CSRF-FOREIGN-403 | PASS | 403 `CSRF verification failed`. The uwsgi log line was `WARNING [django.security.csrf:253] Forbidden (Origin checking failed - https://evil.example does not match any trusted origins.): /login` |
| HOMELAB-CELERY-PING | PASS | `celery -A dojo inspect ping` in `defectdojo-celery-worker/celery` exited 0 with pong |
| ARGOCD-HOOK-PHASE | PASS | The initializer Sync hook Succeeded, the Application was Synced and Healthy, and there was no ComparisonError |
| SECOND-SYNC-IDEMPOTENT | SKIPPED (expected) | `--sync-pass first` |

Summary line: `ALL PASS - 7 live check(s) executed and passed; 1 sub-check(s) skipped (not passed).` The gate exit code was 0. `NOTHING RAN` does not appear.

Gate section 6 (state measurement) prints only with `--write-state` or `--sync-pass second`, so it is absent by design.

The gate does not reference the pruned standalone ghostunnel Deployment. It uses `deploy/defectdojo-django -c uwsgi` and `deploy/defectdojo-celery-worker -c celery`, and both match the live objects. No gate bug was found for 29-18.

## Credentials

No credential was handled by hand. The gate reads `DD_ADMIN_PASSWORD` from Secret `defectdojo/defectdojo` into its own 0600 temp file, and its EXIT trap removes it. No scratchpad credential file was created, so there was nothing to delete. On every evidence file, the hygiene greps (`github_pat_|ghp_|Authorization: Token ...` across `evidence/`, and `DD_ADMIN_PASSWORD=|Token <20+ chars>` on the gate file) return 0.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| 1 | `01fcf6b` | 29-08-first-sync-application.json, 29-08-first-sync-cluster.txt, 29-08-image-pulls.txt, 29-08-initializer-postfix.log (force-added because of the global `*.log` ignore) |
| 2 | `31e7666` | 29-08-homelab-validate-first.txt |
| (prior partial run) | `a40c5a8` | 29-08-initializer-first.log, *.pre-ghostunnel-fix.* (unchanged) |

## Deviations from Plan

1. **No poll loop.** The stop condition (Synced, Healthy, Succeeded) already held on the first read, so the 20-minute poll was not needed.
2. **`sealedsecrets.bitnami.com` instead of bare `sealedsecret`** in the cluster listing, following the same fully-qualified-resource rule as `certificates.cert-manager.io`. The output is the same.
3. **Image-pull capture includes init containers.** ghostunnel is now the `tls` init container, so the listing covers `initContainerStatuses` as well as `containerStatuses`. A per-pod spec image listing and a D-14 source note were added.
4. **Pin compare is stricter than the automated verify.** The verify only checks that `revisions[0]` is 40 hex characters. This run also compared it for equality with the pin.

## Notes for later plans

- 29-17: this run did not write a `--write-state` file. Capture the pre-state (with the token from 29-10) before the second sync. The first-run baseline log for the comparison is still `29-08-initializer-first.log`. The postfix log already shows the idempotent markers for a re-run.
- DDOJO-05 is not marked complete.

## Known Stubs

None.

## Self-Check: PASSED

- All five 29-08 evidence files named in the table and this SUMMARY exist.
- Commits 01fcf6b, 31e7666 and a40c5a8 exist.
