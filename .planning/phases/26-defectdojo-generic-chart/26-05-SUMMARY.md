---
phase: 26-defectdojo-generic-chart
plan: 05
subsystem: kubernetes/defectdojo verification (security-platform, measured from the docs repo)
tags: [verification, kind, defectdojo, cert-manager, tls, checkov, ci-parity, pre-commit, gitleaks, live-evidence]
requires:
  - "26-02: scripts/defectdojo-live-smoke.sh"
  - "26-03: kubernetes/defectdojo wrapper chart and validate-tls.yaml guard (gate green)"
  - "26-04: kubernetes/defectdojo/README.md"
provides:
  - "Verbatim evidence that the committed chart (security-platform 60205bd) passes the offline gate (20/20) and the live kind smoke (ALL PASS, 12 checks, 0 skipped, rc=0)"
  - "Checkov measured locally on the rendered chart (66 failed / 568 passed / 26 resources) and CI-equivalent (14 -> 14, identical set; chart covered zero times, named cause)"
  - "Repo hygiene evidence: pre-commit, pre-commit pre-push stage (gitleaks), shellcheck all exit 0; scripts 100644; no tarball tracked"
affects: [26-06, 26-07]
tech-stack:
  added: []
  patterns:
    - "Long live smoke run with run_in_background, rc appended to the log, evidence copied verbatim with a HEAD= header"
    - "CI-equivalent Checkov: git archive into scratch, pinned checkov:3.3.17 container, WRITABLE mount, no --soft-fail, set diff on check_id+file_path"
key-files:
  created:
    - .planning/phases/26-defectdojo-generic-chart/evidence/26-05-offline-gate.txt
    - .planning/phases/26-defectdojo-generic-chart/evidence/26-05-live-smoke.txt
    - .planning/phases/26-defectdojo-generic-chart/evidence/26-05-checkov.txt
    - .planning/phases/26-defectdojo-generic-chart/evidence/26-05-repo-hygiene.txt
  modified: []
decisions:
  - "CI Checkov coverage of kubernetes/defectdojo is recorded as MEASURED-ZERO-WITH-A-NAMED-CAUSE: the pinned helm runner engages, fetches defectdojo-1.9.53, and the bare render fails on the validate-tls.yaml issuer guard (WARNI, exit code unaffected). Guard not relaxed, no suppression added."
  - "KIND-CELERY-PING passed on the primary `celery -A dojo inspect ping` (pong); RESEARCH A7 is now measured. The log-grep fallback line has still never been observed."
metrics:
  duration: "~20 min"
  completed: 2026-09-25
  tasks: 2
  files: 4
---

# Phase 26 Plan 05: Live verification and Checkov measurement Summary

I ran both gates against the committed chart at security-platform `60205bd` and recorded the output verbatim. The offline gate printed `PASS - 20 checks, 0 failures`. The live kind smoke printed `ALL PASS - 12 live check(s) executed and passed; 0 sub-check(s) skipped` with `rc=0`. That includes a verified-TLS `/login` 200 (issuer `CN=smoke-ca`, SAN `DNS:defectdojo.smoke.test`, `ssl_verify_result 0`), a real admin login followed by `/dashboard` 200, and a Celery broker ping that returned pong.

Checkov found 66 failed / 568 passed over 26 resources on the rendered chart, identical to RESEARCH, with none on wrapper-owned resources. CI's Checkov covers the chart zero times for a named reason. No chart, value or script file was changed.

## Tasks

| # | Task | Commit (docs repo) | Files |
|---|------|--------|-------|
| 1 | Live kind smoke run to ALL PASS (+ offline gate) | `2b943a8` | `evidence/26-05-offline-gate.txt`, `evidence/26-05-live-smoke.txt` |
| 2 | Checkov (local + CI-equivalent) and repo hygiene | `4481cd7` | `evidence/26-05-checkov.txt`, `evidence/26-05-repo-hygiene.txt` |

security-platform: 0 commits, `git status --porcelain` empty before and after.

## Task 1: live smoke (measured)

- Kube context: `admin@occ-new` before the run and `admin@occ-new` after it. `kind get clusters` printed `No kind clusters found.` both before and after. I made no kubectl or helm call against the homelab context. My only kubectl call was `config current-context`; every helm call was `helm template`/`helm version`, which do not contact a cluster.
- Deployment names: I checked them against a real render with release name `defectdojo` before the run. They are `defectdojo-django` (uwsgi, nginx), `defectdojo-celery-worker` (celery), `defectdojo-celery-beat` (celery), plus the StatefulSets `defectdojo-postgresql` and `defectdojo-valkey`. They match the script's `DEPLOYMENTS` / `CELERY_DEPLOYMENT` / `CELERY_CONTAINER`.
- Tools: helm v4.3.0+gbec5b06, kind v0.33.0, Docker Desktop with 12 CPUs and 7.653 GiB.
- Wall-clock: **196 s** for the whole script, from cluster creation to teardown (started 2026-09-25T00:54:59Z).
- The script ran 12 checks. The 11 IDs the plan requires all PASS: KIND-CERT-MANAGER, KIND-INGRESS-NGINX, KIND-CA-ISSUER, KIND-INSTALL, KIND-DEPLOYMENTS-READY, KIND-PG-PVC-BOUND, KIND-CERT-READY, KIND-INGRESSCLASS-DEFAULTED, KIND-TLS-LOGIN-200, KIND-LOGIN and KIND-CELERY-PING. The twelfth is KIND-CLUSTER. 0 lines start with `FAIL`, and the log has no SKIPPED entries.
- KIND-CELERY-PING used the **primary** command: `celery -A dojo inspect ping in defectdojo-celery-worker/celery exited 0 with pong (broker round-trip)`. That closes RESEARCH A7, which had been UNMEASURED. The fallback line (`Connected to redis://|valkey://`) was not needed and **has still never been observed**.
- Credential grep (`password[=:] *[A-Za-z0-9]{12,}`) returned 0 for all four evidence files.

### Numbers compared with the README (26-04)

The README quotes a 101 s warm helm install and a uwsgi peak of 388-430 MiB. This run **neither confirms nor contradicts** either figure:

- The smoke does not time `helm install` separately.
- The smoke never measures uwsgi memory.

One derived bound, not a measurement: helm's `LAST DEPLOYED: 20:55:59 EDT` against the 00:54:59Z start puts the install start about 60 s into the run. So install plus the post-install checks plus teardown took at most about 136 s.

The whole run (196 s) was much faster than RESEARCH's "cold pulls add minutes" expectation. I recorded that and did not try to explain it.

**Follow-up for 26-06/26-07:** add an install timer and a uwsgi peak probe (or a manual `kubectl top` capture) if the README should cite numbers measured on the final chart. I did not edit the README.

## Task 2: Checkov and hygiene (measured)

**Local rendered measurement** (checkov 3.2.396, `--framework kubernetes`, gate values):

- **failed=66, passed=568, resource_count=26**, skipped 0, parsing errors 0. This is identical to RESEARCH Pitfall 5, which was measured on the prototype.
- Top failing IDs: CKV_K8S_40 ×7, CKV2_K8S_6 ×6, CKV_K8S_43 ×6, CKV_K8S_35 ×6, CKV_K8S_31 ×6.
- **Failures on wrapper-owned resources: 0.** All 20 rendered objects come from `charts/defectdojo`: 9 from the chart itself, 6 from its postgresql subchart and 5 from its valkey subchart. `templates/validate-tls.yaml` renders no object.
- Checkov reports 26 resources against 20 `# Source:` objects. The extra 6 are Checkov's Pod-template pseudo-resources (`Pod.<ns>.<workload>...`).
- 15 of the 66 failures fall on the upstream helm-test Pod `t-defectdojo-unit-tests`, which upstream renders into `default`.

**CI-equivalent measurement** (the 23-06 method):

- Image: `ghcr.io/bridgecrewio/checkov:3.3.17`, digest `sha256:41c4701c…` (the same digest 23-06 measured). The image ships helm v3.22.0.
- Trees: `git archive HEAD` (`60205bd`) and `git archive origin/main` (`61589d5`, which is also the merge base).
- Run: WRITABLE mount, no `--soft-fail`, which is the CI setting.
- Both trees exit 1 with **14 failed**. All 14 are in `fixtures/`. The check_id+file_path set diff is **NO DIFFERENCE**. Neither report has a helm or kubernetes section.
- The helm runner fetched `defectdojo-1.9.53.tgz` and then logged: `[WARNI] Failed processing helm chart defectdojo at dir: ./kubernetes/defectdojo ... execution error at (defectdojo/templates/validate-tls.yaml:39:8): defectdojo.django.ingress.activateTLS is true but no cert-manager issuer is set ...`. The stderr has 0 ERROR-level lines.
- Result: **MEASURED-ZERO-WITH-A-NAMED-CAUSE**. This is not "clean": the latent set is the 66 local findings above.
- `grep -rn checkov:skip kubernetes/defectdojo` finds nothing, and no `.checkov.y*ml` exists anywhere in the repository.

**Hygiene** (security-platform, HEAD `60205bd`):

- `pre-commit run --all-files` exit 0.
- `pre-commit run --all-files --hook-stage pre-push` exit 0, including "Detect hardcoded secrets...Passed".
- `shellcheck` on both scripts exit 0.
- Both scripts are `100644`.
- `git ls-files kubernetes/defectdojo/charts` is empty.
- `git status --porcelain` is empty.

## Deviations from Plan

**1. [Protocol] Per-task commits instead of one combined commit.** The plan's Task 2 asks for a single docs commit holding the four evidence files and the SUMMARY. I followed the executor protocol instead:

- Task 1 evidence is in `2b943a8`.
- Task 2 evidence is in `4481cd7`.
- The SUMMARY and state files go in the final metadata commit.

The content is the same; only the grouping differs.

**2. [Rule 3 - Blocking] Trailing whitespace in an evidence header.** The docs-repo pre-commit hook rejected the first Task 1 commit because the `docker info:` header line I composed (line 7 of `26-05-live-smoke.txt`) ended in a trailing space. I stripped that single header line. The verbatim log body below `----- verbatim log -----` is unchanged.

No chart, values, script or README file was changed. Every gate was green on first contact.

## Notes for later plans

- 26-06/26-07: README figures (101 s install, 388-430 MiB uwsgi peak) are still RESEARCH numbers. This run did not re-measure them; see "Numbers compared with the README" above.
- 26-07: DDOJO-01 is still Pending on purpose, and this plan did not mark it complete.
- CI Checkov gap: this is the same structural finding as Nexus 23-06 and has the same choice set (accept and document, a scanner values file, or a committed render). Do not close it by weakening the issuer guard.

## Known Stubs

None. This plan created only evidence files.

## Self-Check: PASSED

- FOUND: evidence/26-05-offline-gate.txt, 26-05-live-smoke.txt, 26-05-checkov.txt, 26-05-repo-hygiene.txt
- FOUND: 2b943a8, 4481cd7 in the docs repo
- Task 1 and Task 2 `<automated>` verify blocks both exited 0 (VERIFY_OK, VERIFY2_OK)
