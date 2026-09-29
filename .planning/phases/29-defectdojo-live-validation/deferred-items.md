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
