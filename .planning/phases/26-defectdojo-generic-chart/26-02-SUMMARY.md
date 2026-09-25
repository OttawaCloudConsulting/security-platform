---
phase: 26-defectdojo-generic-chart
plan: 02
subsystem: kubernetes/defectdojo live smoke (security-platform)
tags: [kind, defectdojo, cert-manager, ingress-nginx, tls, smoke, celery]
requires:
  - "26-01: branch feature/phase-26-defectdojo-generic-chart, check-defectdojo-chart.sh"
provides:
  - "scripts/defectdojo-live-smoke.sh: live kind smoke for kubernetes/defectdojo (vacuous SKIP until 26-03; run for real in 26-05)"
affects: [26-03, 26-05, 26-06, 26-07]
tech-stack:
  added: []
  patterns:
    - "Nexus kind-smoke harness (trap, pass/fail/SKIPPED accounting, print_summary, ownership guard, KIND_CREATED after rc 0) without the docker half"
    - "SelfSigned -> isCA Certificate -> CA ClusterIssuer so curl verifies the served cert with --cacert from the issued Secret"
    - "Background port-forward with PF_PID assigned before the trap and killed by it; readiness polled via bash /dev/tcp"
    - "Credentials generated to upstream randAlphaNum lengths, applied via stdin heredoc, login password via --data-urlencode password@FILE (umask 077)"
key-files:
  created:
    - repos/security-platform/scripts/defectdojo-live-smoke.sh
  modified: []
decisions:
  - "Subchart vendoring is preflight (exit 2 on failure), not a require_success live check, so a run that vendors and then skips the cluster half still reads NOTHING RAN"
  - "KIND-TLS-LOGIN-200 asserts curl exit status, ssl_verify_result 0, served issuer CN=smoke-ca and SAN DNS:defectdojo.smoke.test (issuer/SAN are part of the pass, not just logged)"
  - "KIND-CELERY-PING falls back to the worker log grep only when the ping command itself is unusable (exit 126/127, module/command not found); a broker-side ping failure is a FAIL with no fallback"
metrics:
  duration: "~25 min"
  completed: 2026-09-25
  tasks: 2
  files: 1
---

# Phase 26 Plan 02: DefectDojo live kind smoke Summary

`scripts/defectdojo-live-smoke.sh` (733 lines, mode 100644) is the live half of D-14. It creates kind cluster `dd-smoke` and installs cert-manager v1.21.2 and ingress-nginx controller-v1.15.1, with IngressClass `nginx` annotated as the cluster default. It then builds a SelfSigned -> CA ClusterIssuer `smoke-ca`, pre-creates three Secrets from stdin, and runs one `helm install defectdojo`. Seven live assertions follow; the key ones are a verified-TLS `/login` 200, a real admin login and a Celery broker ping. The chart does not exist yet, so today the script prints `SKIPPED` / `NOTHING RAN` and exits 0 before any kind or kube call.

## Tasks

| # | Task | Commit (security-platform) | Files |
|---|------|--------|-------|
| 1 | Harness, preflight, cluster and TLS infrastructure | `f46a292` | `scripts/defectdojo-live-smoke.sh` |
| 2 | Live assertions: readiness, Certificate, D-12 class, verified TLS, login, Celery | `0471da1`, fix `962202b` | `scripts/defectdojo-live-smoke.sh` |

## Check IDs

KIND-CLUSTER, KIND-CERT-MANAGER, KIND-INGRESS-NGINX, KIND-CA-ISSUER, KIND-INSTALL, then KIND-DEPLOYMENTS-READY, KIND-PG-PVC-BOUND, KIND-CERT-READY, KIND-INGRESSCLASS-DEFAULTED, KIND-TLS-LOGIN-200, KIND-LOGIN, KIND-CELERY-PING.

KIND-LOGIN and KIND-CELERY-PING go beyond D-14's literal text ("login page returns 200"), as RESEARCH OQ5 recommended and the plan objective records. The reason: a GET `/login` 200 was measured while uwsgi was one POST from OOMKill, and upstream ships no Celery probes.

## Verification (measured, from repos/security-platform/)

- `shellcheck` exits 0 after each task. The pre-commit shellcheck hook passed on both commits. `/bin/bash -n` (bash 3.2) also parses the file.
- `bash scripts/defectdojo-live-smoke.sh` exits 0 and prints `helm client: v4.3.0+gbec5b06`, a SKIPPED entry naming `kubernetes/defectdojo/templates/validate-tls.yaml`, and `NOTHING RAN`. Afterwards `kind get clusters` reports `No kind clusters found.` and `kubectl config current-context` is unchanged.
- I ran every acceptance grep literally on this Mac (BSD grep). I first confirmed that `\b` and `\s` behave as intended there, so a 0 below is a real zero. Results:
  - kubectl lines without `--context`: 0
  - `helm install`: 1, and its line carries `--kube-context "$KIND_CONTEXT"`; `helm upgrade`: 0
  - `v1.21.2`: 2, `controller-v1.15.1`: 2, `is-default-class=true`: 2
  - `KUBECTX_BEFORE=""` is at line 98 and `PF_PID=""` at line 101, both before the trap at line 108 (as of Task 1)
  - all seven Task 2 IDs are present
  - `curl` with `-k`/`--insecure`: 0; `--cacert`: 6
  - `wait .*job|get jobs?`: 0
  - `password@`: 3; `password=$` / `password="$`: 0
  - the literal Referer line: 1
- `bash scripts/check-defectdojo-chart.sh` still exits 0 with SKIP.
- Parsers tested offline in a scratchpad (since deleted):
  - `gen_secret` returns exactly 22, 32 and 128 alphanumeric characters.
  - The issuer sed and grep read `issuer=CN=smoke-ca` from OpenSSL 3.6.4 and find `DNS:defectdojo.smoke.test` in the SAN.
  - The csrfmiddlewaretoken sed pulls the token from a Django-shaped hidden input.
  - The log-line mask turns `redis://:s3cret@host` into `redis://***@host`.
- **Not exercised:** the live kind path. There is no chart, and running it is 26-05's job. None of the Task 2 assertions has run against a cluster.

## Deviations from Plan

**1. [Rule 1 - Bug] Subchart vendoring is preflight rather than `require_success`**
- **Found during:** Task 1
- **Issue:** The plan says to run `helm dependency build` through `require_success` when the tarball is missing, and that increments `CHECKS_PASSED`. On a machine with no tarball and no kind, the run would then end `ALL PASS - 1 live check` even though nothing was installed. That is the vacuous green the harness exists to forbid.
- **Fix:** it is now plain preflight. A failed build, or a build that leaves the tarball absent, is FATAL with exit 2, and neither path touches the counter. The tarball name still comes from `yq '.dependencies[0].version' Chart.yaml`.
- **Commit:** `f46a292`

**2. [Rule 1 - Bug] `KUBECTX_BEFORE` capture without `|| true`**
- The analog's `$(kubectl config current-context ... || true)` is forbidden outside the trap. The bare form would abort under `set -e` when no context is set. I used `if ! KUBECTX_BEFORE="$(...)"; then KUBECTX_BEFORE=""; fi` instead.

**3. [Rule 2 - Correctness] Ownership guard records a FAIL instead of a FATAL exit**
- The plan says "FAIL and refuse". The guard calls `fail "KIND-CLUSTER" ...` and then `print_summary` (exit 1), so the refusal shows up in the summary. It still never deletes anything.

**4. [Rule 2 - Correctness] Extra hard-tier binary `openssl`, and stronger TLS evidence**
- The plan asks for the served certificate's issuer and SAN to be recorded. That needs `openssl s_client`, so `openssl` joins the hard tier (exit 2 if missing). The issuer (`CN=smoke-ca`) and SAN are part of the KIND-TLS-LOGIN-200 pass condition, and curl's exit status is asserted alongside `ssl_verify_result`. This Mac's `/usr/bin/curl` is a SecureTransport/LibreSSL build, where exit 60 is the reliable signal that verification failed.

**5. [Rule 2 - Correctness] Smaller hardening**
- The soft-tier loop is `for bin in kind kubectl`, so no non-comment line contains an unpinned `kubectl `.
- If the install fails, the script prints the pod table and stops, so the later assertions don't stack consequential failures on top of it.
- If cert-manager, ingress-nginx or the CA issuer fails, the script stops there as well.
- KIND-DEPLOYMENTS-READY first checks that each of the three Deployments exists by name, so a rename cannot pass through `--all`.
- KIND-LOGIN treats a 302 that redirects back to `/login` as a failure.
- Celery log lines are masked (`//***@`) before they are printed.
- `gen_secret` matches the upstream `randAlphaNum` lengths (22/128/128/32), which I read from `defectdojo/templates/secret.yaml` in `defectdojo-1.9.53.tgz` while writing the script. It is not parsed at runtime.

**6. [Rule 1 - Bug] Three `set -e` abort points in Task 2 (found in post-task review)**
- **Issue:** `pvc_json=$(kubectl ...)` and `ing_json=$(kubectl ...)` would abort the script on a kubectl error before `print_summary` ran. The CSRF-token `sed` ran before the GET's exit code was checked, so if curl never wrote `login-form.html`, sed exited 2 and killed the run. All three failed loudly, never falsely green, but they lost the summary.
- **Fix:** the two list captures now record their exit code and continue with an empty item list, so the assertion FAILs inside the summary. The sed is skipped when the form file does not exist.
- **Commit:** `962202b`. shellcheck, the SKIP run, the context check and all acceptance greps were re-run and passed.

## Known Stubs

None. The Deployment names come from `<interfaces>` and were confirmed by rendering the scratchpad prototype chart (`defectdojo-django`, `defectdojo-celery-worker`, `defectdojo-celery-beat`, celery container `celery`, Ingress `defectdojo`). 26-05 must re-confirm them against the real chart. The Celery fallback log line (`Connected to (redis|valkey)://`) is unmeasured (RESEARCH A7), and 26-05 must confirm it from a live log.

## Threat Flags

None beyond the plan's register. T-26-05, 06, 07, 03 and 15 are mitigated as specified. T-26-08 (archived ingress-nginx) is accepted and noted in the script header as smoke-only.

## Notes for later plans

- 26-05: this Mac's `/usr/bin/curl` is a SecureTransport/LibreSSL build, where `%{ssl_verify_result}` may read 0 regardless of the outcome. The load-bearing TLS signal is curl's exit status (60 means verification failed), which the smoke asserts first, together with the issuer and SAN checks. Don't read too much into the `0`.

- 26-03: the smoke keys on `kubernetes/defectdojo/templates/validate-tls.yaml`. The scratchpad prototype's guard file is `templates/validate.yaml`, but the plan's name is authoritative, so name the real template `validate-tls.yaml` or the smoke stays SKIPPED.
- 26-05: expect a cold-cache runtime of 10-20 min (install measured 101 s warm). Run it with `run_in_background`, because a Bash call is capped at 600 s.

## Self-Check: PASSED

- FOUND: repos/security-platform/scripts/defectdojo-live-smoke.sh (mode 100644)
- FOUND: f46a292, 0471da1, 962202b on feature/phase-26-defectdojo-generic-chart
