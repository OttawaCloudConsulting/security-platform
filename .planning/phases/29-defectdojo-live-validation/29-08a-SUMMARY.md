---
phase: 29-defectdojo-live-validation
plan: 08a
subsystem: k8s-infrastructure
tags: [defectdojo, argocd, overlay, ghostunnel, native-sidecar, lb-vip, tls, ddojo-05, gap-closure]
requires:
  - "29-07: occ-k8s-app-config main cc7fbc9 with application-sets/platform/defectdojo/** live; Argo Application defectdojo exists"
  - "29-08 (paused): pre-fix snapshots and first-sync initializer log preserved (a40c5a8)"
provides:
  - "occ-k8s-app-config main 08ce26bf751b93f7aa9193d6412907bec710b63f: PR #249 merged; ghostunnel runs as a native sidecar (init container tls, restartPolicy Always) in the defectdojo-django pod, targeting 127.0.0.1:8080"
  - "Standalone Deployment defectdojo-ghostunnel pruned; LB Service defectdojo-ghostunnel keeps 10.40.3.65 and now selects the django pod on targetPort 8443"
  - "Verified HTTPS (system trust store, ssl_verify_result 0) on defectdojo.infra and defectdojo.home through 10.40.3.65; Argo Application Synced/Healthy/Succeeded"
  - "Plan 29-08 can resume from its Task 1"
affects: [29-08, 29-09, 29-12, 29-14, ADR-027]
tech-stack:
  added: []
  patterns:
    - "Kubernetes native sidecar added purely through chart values (django.extraInitContainers + django.extraVolumes), leaving the public chart and its pin untouched"
    - "Pre-merge runtime arg check: run the pinned image with the exact rendered args, plus a negative control that must fail, because helm template and kubectl dry-run do not validate arg semantics"
    - "Numeric Service targetPort when the target port is declared on an init container (sidecar)"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-argo-op-before.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-render-assertions.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-runtime-arg-check.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-application-after.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-live-after.txt
  modified:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/argocd-overrides.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/service.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/certificate.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/Chart.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/README.md
  deleted:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/ghostunnel-deployment.yaml
decisions:
  - "29-08a: operator decision verbatim \"B1: overlay values\" (2026-09-28): ghostunnel moves into the django pod as a native sidecar via overlay values, instead of adding --unsafe-target to the standalone Deployment. This supersedes 29-CONTEXT D-02 (standalone ghostunnel Deployment in front of the django Service)."
  - "29-08a: operator Task 2 reply verbatim: \"approve terminate-op\". Merge approved at head b2cacd0562c49d84378c464c76b9ec33f6339038, and terminate-op authorised only if a stale operation on cc7fbc9 was still Running 5 minutes after merge."
  - "29-08a: PR #249 merged as 08ce26bf751b93f7aa9193d6412907bec710b63f at 2026-09-28T12:14:31Z (parents cc7fbc9, b2cacd0), --merge pinned by --match-head-commit b2cacd0562c49d84378c464c76b9ec33f6339038."
  - "29-08a: terminate-op was NOT used. The pre-merge operation was already Succeeded, and automated sync started a new operation on [c8027e6, 08ce26b] at 12:18:09Z that finished Succeeded at 12:19:11Z. No refresh or manual sync was issued."
  - "29-08a (ADR-027 lesson): the 29-05 gates (helm template, kubectl client and server dry-run) validate structure and admission, not container arg semantics; that is how the standalone ghostunnel --target=<service DNS> CrashLoopBackOff got through. A runtime arg check with a negative control is now the pattern for any container whose args encode policy."
  - "29-08a: DDOJO-05 not marked complete. The HTTPS path is fixed, but the full homelab validation (defectdojo-homelab-validate.sh) belongs to 29-08 Task 2 and later plans."
metrics:
  duration: "~9.5h wall clock across executor sessions (Task 1 02:49Z-~03:10Z, operator gate, Task 3 12:14Z-12:25Z)"
  completed: 2026-09-28
  tasks: 3
  files: 11
---

# Phase 29 Plan 08a: ghostunnel native sidecar for DefectDojo Summary

ghostunnel now runs as a Kubernetes native sidecar (init container `tls`, `restartPolicy: Always`, `--target=127.0.0.1:8080`) inside the `defectdojo-django` pod. The change was made purely through overlay values in `occ-k8s-app-config` PR #249, merged as `08ce26b`. That removed the `--target must be unix:PATH or localhost:PORT` CrashLoopBackOff without `--unsafe-target`. Argo pruned the standalone Deployment. HTTPS on both DefectDojo hostnames through 10.40.3.65 verifies against the system trust store.

## Operator replies (verbatim)

- Design decision (before this plan): `B1: overlay values`
- Task 2: `approve terminate-op`. The operator was shown PR #249 (diff, gates, runtime arg check positive and negative, Argo op Succeeded not Running, B1 coupling costs, forward-fix-only rollback, likely two-sync gap).

## Identifiers

| Item | Value |
|------|-------|
| Worktree base (origin/main) | `cc7fbc958c7928d1d640c2f9ec20a44b78a7fcfd` |
| Branch | `fix/defectdojo-ghostunnel-native-sidecar` (remote branch kept; delete only on operator request) |
| PR | https://github.com/OttawaCloudConsulting/occ-k8s-app-config/pull/249 |
| Approved head | `b2cacd0562c49d84378c464c76b9ec33f6339038` |
| Merge SHA | `08ce26bf751b93f7aa9193d6412907bec710b63f` (2026-09-28T12:14:31Z) |
| security-platform pin (unchanged) | `c8027e6784ec631db128f45444c9a8092db9d0a1` |

## Task results

| Task | Result | Commit |
|------|--------|--------|
| 1 | Sidecar added through `valuesObject.defectdojo.django.extraInitContainers` + `extraVolumes`; Service re-pointed at the django pod (three labels, numeric targetPort 8443); standalone Deployment template deleted; Chart 0.1.1; README updated. All gates passed; runtime arg check positive and negative passed; PR #249 opened. | overlay `b2cacd0`, docs `1339c65` |
| 2 | Operator gate: `approve terminate-op`. | n/a |
| 3 | Re-checked head == `b2cacd0` and `conformance` SUCCESS, then merged. Automated sync picked up `08ce26b` about 3.5 min after merge in a single operation that already carried the sidecar valuesObject. Live proof passed on all 8 sections. Worktree removed; shared tree received only `fetch`. | merge `08ce26b`, docs (this commit) |

## Gate table (Task 1, evidence/29-08a-render-assertions.txt)

| Gate | Result |
|------|--------|
| 1 conformance: `c1.py` (0 violations, 21 files) and `check_appconfig.py --base origin/main` (22 apps) | PASS |
| 2 scoped yamllint `application-sets/platform/defectdojo` | PASS |
| 3 `helm dependency update` no-op + source-2 render (Deployment count 0; Service selector three labels, targetPort 8443, VIP annotation) | PASS |
| 4 source-1 render at pin: (a) initContainers[0]=tls Always, (b) eight exact args, none contain `unsafe`, (c) tls volume -> secret defectdojo-tls, (d/d') uwsgi and nginx have no tls mount, (e/e') nginx 8080 and no port collision, no startupProbe on sidecar, securityContext carried, (f) exactly one workload matches the Service selector, 29-05 (a)-(e) regressions | PASS |
| 5 kubectl client dry-run on each remaining template | PASS |
| 6 server-side dry-run (live admission: namespace-boundary, L2 etp) | PASS |
| 7a/7b gitleaks scoped and CI form on `b2cacd0` | PASS |
| pre-commit hooks on `b2cacd0` (yamllint, markdownlint, c1, check_appconfig) | PASS |
| PR checks: `conformance`, GitGuardian | SUCCESS, SUCCESS |

## Runtime arg check (Task 1, evidence/29-08a-runtime-arg-check.txt)

- Positive: the pinned image `ghostunnel@sha256:51fa6192…4faf`, run with the eight rendered args verbatim, was still running after 10s with `restarts=0`. `/_status` returned 503 with backend `127.0.0.1:8080` refused, which is expected because no nginx runs in the test. The logs had no `--target must be`.
- Negative control: the same run with only `--target=defectdojo-django.defectdojo.svc.cluster.local:80` exited with rc=1 and printed `error: --target must be unix:PATH or localhost:PORT (unless --unsafe-target is set)`.

## Argo operation branch

The normal automated sync ran and terminate-op was not used. Before the merge, the operation was `Succeeded` on `[c8027e6, cc7fbc9]` with health Degraded. After the merge at 12:14:31Z, the poll saw no change until 12:18:19Z. At that point an operation was `Running` on `[c8027e6, 08ce26b]`, and both `.spec.sources[0]` and `syncResult.sources[0]` already carried the `tls` sidecar. It finished `Succeeded` at 12:19:11Z (Synced/Healthy). The expected two-sync gap did not occur. `revisions[0]` is still the pin. The initializer Sync hook re-ran (Job `defectdojo-initializer`, pod `defectdojo-initializer-552xn` Completed). `syncResult` shows `Deployment/defectdojo-ghostunnel` as `Pruned`.

## Live proof (evidence/29-08a-live-after.txt, captured 2026-09-28T12:20:07Z)

| # | Check | Value |
|---|-------|-------|
| 1 | `get deploy defectdojo-ghostunnel` | `NotFound`; 0 `defectdojo-ghostunnel-*` pods |
| 2 | django pod `defectdojo-django-7bd88b9f6b-grm9j` | `tls` ready=true, started=true, restartCount=0, restartPolicy=Always, image digest `sha256:51fa6192…4faf`; uwsgi and nginx ready, no tls mount; db-migration-checker terminated Completed (exit 0) |
| 3 | EndpointSlice `defectdojo-ghostunnel-g82lh` | exactly one endpoint, 10.0.1.46 (= pod IP), ready=true, port 8443 |
| 4 | Service VIP | `10.40.3.65` |
| 5 | Certificate `defectdojo-tls` | Ready True, notAfter 2026-12-27T00:59:37Z, both dnsNames |
| 6 | PVC `data-defectdojo-postgresql-0` | Bound, UID `76aa54bc-51bf-487c-9ed9-dd3f9115f4f2` (= baseline) |
| 7 | infra and home hostnames | both SANs present; `/` -> `302 0` (ssl_verify_result 0); `/login` -> `200` on both |
| 8 | sidecar logs | `using target address 127.0.0.1:8080`, `listening for connections on :8443`, pipes to 127.0.0.1:8080; 0 `--target must be` |

The sidecar logs `error on TLS handshake from 10.0.1.218: EOF` every 20s. This comes from the sidecar's own `livenessProbe` (tcpSocket on `https`, periodSeconds 20), connecting from the node's cilium_host IP (CiliumNode occ-cs-k8worker01 addresses 10.40.4.31, 10.0.1.218). It is a plain TCP connect and close, not a TLS load error.

Evidence hygiene: the plan's token, PAT and webhook-secret grep returns 0 on both new evidence files.

## ADR-027 inputs

- B1 supersedes D-02. TLS for DefectDojo terminates in a ghostunnel native sidecar inside the django pod, added through `django.extraInitContainers`/`extraVolumes`. There is no standalone ghostunnel Deployment and no `--unsafe-target`. The plaintext hop is now pod loopback only. B1's coupling cost is that the sidecar depends on the chart's `extraInitContainers` ordering (tls before db-migration-checker) and on the django pod labels. Rollback is forward-fix only.
- Lesson: `helm template` and `kubectl --dry-run` (client and server) validate structure and admission, not container arg semantics. For containers whose args encode policy, the pattern is a runtime arg check with a negative control.

## Stale docs (not edited here)

- `29-CONTEXT.md` D-02: still describes the standalone ghostunnel Deployment in front of the django Service.
- `29-RESEARCH.md` Pattern 2: still describes the standalone ghostunnel Deployment pattern with `--target=<service DNS>`.

## Deviations from Plan

1. **Sixth overlay file (Task 1).** `templates/certificate.yaml` was modified, but only its comments changed, to describe the sidecar consumer. The plan listed five files. The PR has 6 files: 5 modified and 1 deleted.
2. **Per-task evidence commit (Task 1).** Task 1 evidence was committed on its own as docs `1339c65`. The plan's Task 3 docs commit had expected to stage all five `evidence/29-08a-*` files together. The Task 3 commit therefore stages only the two new evidence files, SUMMARY, STATE.md and ROADMAP.md.
3. **Trailing-whitespace recommit (Task 1).** The docs-repo trailing-whitespace hook rejected tab-trailing lines copied from `gh` output. Those lines were stripped and the commit was redone. `--no-verify` was not used. The same stripping was applied to `29-08a-live-after.txt` before this commit.
4. **Argo op was Succeeded, not Running (Task 1/2).** The plan expected a stale `Running` retry loop on `[c8027e6, cc7fbc9]`. It had already ended as `Succeeded` (Degraded), so the terminate-op branch never applied.
5. **No two-sync gap (Task 3).** The first operation on `08ce26b` already had the new valuesObject. The plan's guard against an intermediate sync with the old spec was not needed.
6. **Shared overlay tree HEAD moved externally (Task 3).** HEAD went from `cc7fbc9` to `08ce26b` via `pull --ff-only origin main` at 2026-09-28T12:18:30Z (reflog). This executor did not run it: it issued only `worktree remove` and `fetch`, at about 12:20:50Z. It is attributed to another session. The branch (`main`) and the worktree list (minus `wt-29-08a`) match the baseline. Per instructions, it is recorded and was not touched. The plan's acceptance criterion "HEAD equals the Step A baseline" therefore does not hold literally, but the tree is at the merge SHA and is clean for this plan.
7. **Evidence-hygiene self-match (Task 3).** The first draft of `29-08a-live-after.txt` echoed the hygiene grep's pattern text, and that text matched itself (1 hit). The line was reworded to describe the grep without the pattern text. The re-run gives 0.

## Known Stubs

None.

## Next

- Plan 29-09 (wave 4), then plan 29-08 (wave 5), which resumes from its Task 1 with the resume note applied. Full `defectdojo-homelab-validate.sh` pass is 29-08 Task 2.
- Operator: remote branch `fix/defectdojo-ghostunnel-native-sidecar` still exists; delete on request. GitGuardian incident 37678807 remains the known false positive.

## Self-Check: PASSED

- All five evidence/29-08a-* files and this SUMMARY exist.
- Docs commits 1339c65 and 783c233 exist; overlay commits b2cacd0 (PR head) and 08ce26b (merge) exist in occ-k8s-app-config.
- Plan Task 3 automated verify printed PLAN_VERIFY_PASS against the committed evidence.
