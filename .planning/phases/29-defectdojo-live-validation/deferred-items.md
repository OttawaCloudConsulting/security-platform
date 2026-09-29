# Phase 29 Deferred Items

## From 29-15

### prove-import red on workflow_dispatch run 36502717161 (KIND-CELERY-PING)

- **Observed:** 2026-09-29T00:27:32Z, `prove-import` job 109197316267 (ubuntu-latest) failed with
  `KIND-CELERY-PING: FAIL - celery -A dojo inspect ping exited 69 without pong (broker unreachable or worker not replying)`.
  All earlier kind checks passed: cluster, cert-manager, ingress, CA issuer, install, deployments ready, PVC bound, cert ready, TLS login 200 and admin login.
- **Scope:** this is the ephemeral kind DefectDojo on a GitHub-hosted runner, not the live homelab instance. The live-side D-10 assertions for 29-15 all passed.
- **Prior state:** DefectDojo Import Proof passed on 2026-09-27 in run 36350180923 (pull_request, the PR later merged to main as 2fda1ac). The code under test is the same.
- **Unknown:** a single run cannot tell a transient Celery worker readiness race apart from a regression. It was not re-dispatched (29-15 did not ask for a rerun).
- **Operator-visible effect:** `main` now has a red "DefectDojo Import Proof" run.
- **Suggested next step:** re-dispatch `defectdojo-import-proof.yml` once. If KIND-CELERY-PING fails again, investigate worker readiness and the ping timeout in `scripts/defectdojo-live-smoke.sh`.
- **Rerun (2026-09-29, operator-approved):** `gh run rerun 36502717161 --failed` created attempt 2. Its `prove-import` job 109200085064 started at 00:33:22Z and passed, including KIND-CELERY-PING, and run 36502717161 now concludes `success`. The unchanged code passed on rerun, so the first failure was most likely a transient Celery worker readiness race rather than a regression. That is an inference from one pass after one fail, not a root cause.
- **Status:** not blocking. The ping has flaked once in two attempts at the same code. If it flakes again, harden worker readiness or the ping retry in `scripts/defectdojo-live-smoke.sh`. Re-check at 29-18, before the `v1.2.0` tag.
