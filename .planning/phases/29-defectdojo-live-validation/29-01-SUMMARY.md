---
phase: 29-defectdojo-live-validation
plan: 01
subsystem: live-validation
tags: [defectdojo, live-gate, csrf, tls, argocd, idempotency, bash]
requires: []
provides:
  - "repos/security-platform/scripts/defectdojo-homelab-validate.sh (8 check IDs, --write-state / --pre-state interface)"
affects: [29-06, 29-08, 29-17]
tech-stack:
  added: []
  patterns:
    - "Verbatim FAILURES/SKIPPED/CHECKS_PASSED accounting and NOTHING RAN branch from nexus-homelab-validate.sh"
    - "Origin-header login plus foreign-Origin negative control as the falsifiable D-05 CSRF proof"
    - "Second-sync idempotency measured against a --pre-state JSON captured by an earlier run"
key-files:
  created:
    - repos/security-platform/scripts/defectdojo-homelab-validate.sh
  modified: []
decisions:
  - "HOMELAB-CSRF-FOREIGN-403 asserts exactly 403 and the always-rendered 'CSRF verification failed' body. The Origin-check cause is read from the body when DEBUG is on and otherwise from the uwsgi log line 'Origin checking failed - https://evil.example'. A 403 with no attributable cause is a FAIL, not a pass."
  - "Idempotent-path markers were confirmed from source: 'Admin user already exists; skipping first-boot setup' (complete_initialization.py:39 @3.3.200) and 'No migrations to apply.' (Django 5.2.16 migrate.py:325). Two falsifiers were added: 0 lines of the form '  Applying <app>.<NNNN>', and 0 lines of 'Running first boot setup'."
  - "DDOJO-05 is not marked complete. All 19 phase-29 plans map to it, and this gate has not run live yet (plan 29-08 runs it first)."
metrics:
  duration: "~25min"
  completed: 2026-09-27
  tasks: 2
  files: 1
---

# Phase 29 Plan 01: DefectDojo homelab live-validation gate Summary

This plan adds a bash live gate, `defectdojo-homelab-validate.sh`, with no defaults. It runs eight measured checks:
- system-trust-store TLS with SANs on both hostnames;
- Origin-header admin login on both hostnames;
- a foreign-Origin 403 negative control;
- a Celery ping;
- the Argo CD initializer Sync-hook phase;
- a second-sync idempotency check against a `--pre-state` file.

The gate is committed on the security-platform branch `feature/phase-29-defectdojo-live-validation` at `9726b3515a82c403563db82e11a73d5684776821` (mode 100644). It is not pushed; plan 29-06 pushes it.

## What was built

`repos/security-platform/scripts/defectdojo-homelab-validate.sh` (1017 lines, shellcheck clean):

**Interface (as the plan defined it):**
- `--url`, `--alt-url`, `--context`, `--namespace`, `--app` and `--sync-pass first|second` are required, with no defaults.
- Both URLs must be `https://`.
- `--sync-pass second` also requires `--pre-state` and `--token-file`. A malformed pre-state is exit 2.
- `--write-state` writes `{initializer_uid, serviceaccount_uid, product_count, finding_count, captured_at, app_revision}`. The revision is kept as compact JSON so a multi-source `revisions` array compares exactly.
- `--argocd-namespace` is optional and defaults to `argocd`, as in the Nexus gate.

**Accounting:** copied verbatim from `nexus-homelab-validate.sh` (the `pass`/`fail`/`require_success`/`print_summary` functions and the three branches FAILED / NOTHING RAN / ALL PASS). The only `|| true` is in the EXIT trap.

**Checks:**
- **HOMELAB-TLS-INFRA / HOMELAB-TLS-HOME:** `curl --proto =https` must print `200 0` with no CA override. Then `openssl s_client | x509 -ext subjectAltName` must list both hostnames.
- **HOMELAB-LOGIN-ORIGIN-INFRA / HOMELAB-LOGIN-ORIGIN-HOME:**
  - `DD_ADMIN_PASSWORD` is read from Secret `defectdojo` into a 0600 file.
  - The POST sends `Origin: https://<host>` + Referer + token, using `password@FILE`.
  - It must return 302 to a location other than `/login`, then `/dashboard` must return 200.
  - A 403 prints the Django reason.
- **HOMELAB-CSRF-FOREIGN-403:** see Deviation 1.
- **HOMELAB-CELERY-PING:** `celery -A dojo inspect ping`, with the kind smoke's log-grep fallback kept exactly as it is labelled there.
- **ARGOCD-HOOK-PHASE:**
  - Reads `applications.argoproj.io`.
  - Selects the Job entry by `kind=="Job"` and `name=="defectdojo-initializer"`, and requires `Sync`/`Succeeded`.
  - Prints the ServiceAccount PreSync entry as INFO.
  - Requires Synced, Healthy and no ComparisonError.
- **SECOND-SYNC-IDEMPOTENT:**
  - New initializer UID and new ServiceAccount UID.
  - The admin-exists marker and the no-migrations marker are each present at least once.
  - 0 applied-migration lines and 0 first-boot lines.
  - Synced at the same revision.
  - Product and finding counts equal before and after. A null pre-state count is a named SKIP.
  - Every sub-assertion prints its before and after values.

## Confirmed idempotent-path markers (verbatim)

Read with `gh api` on 2026-09-27:

- **Admin-exists:** `Admin user already exists; skipping first-boot setup`
  - Source: `dojo/management/commands/complete_initialization.py` line 39, tag `3.3.200`.
  - `docker/entrypoint-initializer.sh` at `3.3.200` has no message of its own; it only runs `python manage.py complete_initialization`.
- **No migrations:** `No migrations to apply.`
  - Source: `django/core/management/commands/migrate.py` line 325, tag `5.2.16`, printed as `"  No migrations to apply."`.
  - The Django pin comes from DefectDojo 3.3.200 `requirements.txt`: `Django==5.2.16`.
  - `complete_initialization.py` line 33 calls `call_command("migrate", interactive=False)`.

Both strings match RESEARCH. What RESEARCH did not say is that the admin string lives in the management command, not in the entrypoint file the plan named. The header block `IDEMPOTENT-PATH MARKERS` records all three files and the delegation chain.

## Verification

- Both tasks' `<automated>` verify chains pass (TASK1-VERIFY-OK, TASK2-VERIFY-OK).
- Offline self-tests:
  - no args → 2;
  - `http://` URL → 2;
  - `--sync-pass second` without pre-state/token → 2;
  - missing `--namespace` → 2, with a "no default" message.
- Every acceptance grep returns its expected value:
  - `Origin: https://evil.example` = 1;
  - CA-override / insecure flags in non-comment lines = 0;
  - homelab literals anywhere in the file = 0;
  - `set -x` in non-comment lines = 0;
  - all 8 IDs present;
  - `NOTHING RAN` = 3;
  - `applications.argoproj.io` = 2;
  - bare `get application` = 0;
  - `defectdojo-initializer` = 10.
- An offline run against an unreachable host and a bogus context ended with a clean FAILED summary and exit 1, with no crash under `set -euo pipefail`. `--write-state` wrote a null-valued state file.
- The same run under macOS `/bin/bash` 3.2.57 had no unbound-variable errors.
- `git -C repos/security-platform log origin/main..HEAD --oneline` shows exactly one commit (`9726b35`), and the file mode is 100644.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The foreign-Origin 403 body cannot contain "Origin checking failed" in production**
- **Found during:** Task 1
- **Issue:** The plan required the 403 body to contain `Origin checking failed`. Django 5.2.16 `views/templates/csrf_403.html` renders "Reason given for failure" only inside `{% if DEBUG %}`, and DefectDojo 3.3.200 defaults `DD_DEBUG` to False. A correct production deployment would therefore FAIL this check every time.
- **Fix:**
  - The check asserts exactly 403 plus the always-rendered `CSRF verification failed` text, which shows it was the CSRF middleware that refused the request.
  - It then attributes the refusal to the Origin check. When DEBUG is on, it reads the reason from the body. Otherwise it reads the `django.security.csrf` WARNING (`Forbidden (Origin checking failed - https://evil.example does not match any trusted origins.): /login`) from `kubectl logs deploy/defectdojo-django -c uwsgi --since=5m`.
  - That log line reaches the console under the default `DD_LOG_LEVEL` (empty, so INFO when DEBUG is off, per settings.dist.py lines 2016-2018).
  - If neither source names the cause, the result is FAIL. If kubectl is absent, it is a named SKIP. It is never a pass.
- **Files modified:** repos/security-platform/scripts/defectdojo-homelab-validate.sh
- **Commit:** 9726b35

**2. [Rule 1 - Bug] Measurement helpers would lose error records in `$(...)` subshells**
- **Found during:** Task 2 (self-review before commit)
- **Fix:** `measure_uid` and `measure_count` now set the globals `UID_VAL`/`COUNT_VAL` instead of printing, so `MEAS_ERRORS` entries survive. Empty-array expansions (`pw_args`, `MEAS_ERRORS`) are guarded for bash 3.2 under `set -u`.
- **Commit:** 9726b35

**3. [Rule 2 - Added falsifiers] Stronger second-sync log assertions**
- Two assertions were added to SECOND-SYNC-IDEMPOTENT, alongside the two markers:
  - 0 lines matching `^\s*Applying <app>.<NNNN>`. DefectDojo's own `Applying migrations` line prints on every run, so a bare `Applying` grep would be wrong.
  - 0 `Running first boot setup` lines (complete_initialization.py:135).

### Other notes
- Tasks 1 and 2 edit one file, and the plan's acceptance criterion requires exactly one security-platform commit (`origin/main..HEAD` lists one). The work therefore landed as the single commit Task 2 step 5 prescribes, not as one commit per task.
- `require_success` is carried verbatim but has no caller, so it has a documented `# shellcheck disable=SC2329`.
- `--argocd-namespace` (default `argocd`) was added for parity with the Nexus gate. It is not a homelab literal.

## Known Stubs

None. The gate has not been run live yet, as planned; plan 29-08 runs it first.

## Threat Flags

None. There is no new surface beyond the plan's threat model:
- T-29-03: 0600 password and token files, no echo, no `set -x`, trap cleanup.
- T-29-05: positive Origin logins plus the negative control.
- T-29-08: no CA override or insecure flag, `--proto =https`.
- T-29-09: no literals.

## Self-Check: PASSED

- FOUND: repos/security-platform/scripts/defectdojo-homelab-validate.sh (mode 100644)
- FOUND: commit 9726b35 on security-platform branch feature/phase-29-defectdojo-live-validation (not pushed)
