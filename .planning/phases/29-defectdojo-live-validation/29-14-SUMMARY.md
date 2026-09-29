---
phase: 29-defectdojo-live-validation
plan: 14
subsystem: ci-cd
tags: [defectdojo, ci-importer, github-actions, secrets, ordering-gate, d-10, d-13, d-16, ddojo-05]
requires:
  - "29-06: main security.yml routes the two DefectDojo jobs via vars.DEFECTDOJO_RUNS_ON"
  - "29-10: configure.sh second run NO CHANGE"
  - "29-12: fork approval policy all_external_contributors"
  - "29-13: ARC listener occ-homelab-defectdojo Running"
provides:
  - "DefectDojo user ci-importer (id 3): is_staff true, is_superuser false, is_active true"
  - "security-platform secret DEFECTDOJO_API_TOKEN (ci-importer token), variables DEFECTDOJO_RUNS_ON=occ-homelab-defectdojo and DEFECTDOJO_URL=https://defectdojo.infra.ottawacloudconsulting.com (set last)"
  - "security-platform is the live DefectDojo importer"
affects: [29-15, ADR-024]
tech-stack:
  added: []
  patterns:
    - "Automated ordering gate (four live checks) before any live-importer setting is changed"
    - "Privilege read-back with the admin token only; a staff non-superuser token cannot list /api/v2/users/ (403)"
    - "Secret presence recorded by name and updatedAt only; token self-check via GET /api/v2/user_profile/"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-14-precondition-gate.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-14-settings-readback.txt
  modified: []
decisions:
  - "29-14: DefectDojo POST /api/v2/users/ requires email; ci-importer uses ci-importer@ottawacloudconsulting.com"
  - "29-14: validate a ci-importer token with GET /api/v2/user_profile/, not /api/v2/users/ (403 for non-superuser)"
  - "29-14: ci-importer is DefectDojo user id 3; failed-attempt user id 2 was deleted (now 404)"
  - "29-14: DEFECTDOJO_CA_CERT and DEFECTDOJO_INSECURE are not set; the .infra URL has a publicly trusted chain"
metrics:
  duration: "gate 23:44:10Z (2026-09-28); settings set 2026-09-29T00:14:10Z; read-back 00:15:07Z"
  completed: 2026-09-29
  tasks: 3
  files: 2
---

# Phase 29 Plan 14: Ordering gate, ci-importer identity and live-importer settings Summary

security-platform is now the live DefectDojo importer, and the settings went in the safe order. An automated gate first proved all four ordering preconditions live. The operator then created the least-privilege identity `ci-importer` (DefectDojo user id 3, staff, not superuser). They stored its token as the `DEFECTDOJO_API_TOKEN` secret, then set `DEFECTDOJO_RUNS_ON`, and set `DEFECTDOJO_URL` last. A read-back with the admin token confirmed every value. No token or password is in the repo, the evidence or the logs.

## Operator decisions

| Question | Reply |
|---|---|
| Task 2 checkpoint (create ci-importer, set secret and variables) | completed, "settings-done" equivalent, by running an orchestrator helper script in the session scratchpad (not committed) |
| Add the required `email` field to the user-create body | approved |
| Delete the failed-attempt user id 2 and change the token check to `/api/v2/user_profile/` | approved; the operator ran DELETE /api/v2/users/2/ (204) |

## Task 1: ordering gate (commit d412ee2)

| Check | Result |
|---|---|
| PRECONDITION-1 main security.yml runs-on expression count | PASS, 2 |
| PRECONDITION-2 listener arc-systems/occ-homelab-defectdojo-776f7979-listener | PASS, Running |
| PRECONDITION-3 configure.sh second run NO CHANGE | PASS, 1 |
| PRECONDITION-4 fork approval policy | PASS, all_external_contributors |

Pre-state: no variables and no secrets on security-platform.

## Task 2: identity and settings (operator)

- ci-importer created as **id 3**: `is_staff:true`, `is_superuser:false`, `is_active:true`, email `ci-importer@ottawacloudconsulting.com`.
- The token was minted via POST `/api/v2/api-token-auth/`, checked to be 40 hex characters, and verified with GET `/api/v2/user_profile/` (200, username ci-importer) before use.
- The password, token and auth header were held only in a `mktemp -d` directory removed by an EXIT trap. `~/.config/defectdojo/ci-importer.pw` and `ci-importer.token` were never written.

| Setting | Value | Set at (UTC) |
|---|---|---|
| secret DEFECTDOJO_API_TOKEN | (ci-importer token, not recorded) | 2026-09-29T00:14:10Z |
| variable DEFECTDOJO_RUNS_ON | occ-homelab-defectdojo | 2026-09-29T00:14:10Z |
| variable DEFECTDOJO_URL (last) | https://defectdojo.infra.ottawacloudconsulting.com | 2026-09-29T00:14:10Z |
| DEFECTDOJO_CA_CERT, DEFECTDOJO_INSECURE | not set | — |

The helper ran the three steps one after another, with URL last. GitHub's `updatedAt` shows the secret at 00:14:10Z and both variables at 00:14:11Z. The read-back therefore proves the secret came before the variables, but it cannot order RUNS_ON and URL within one second. That order rests on the helper's output.

## Task 3: read-back (commit 71781e7)

The admin token was used through a 0600 header file in a trap-removed temp directory.

- `GET /api/v2/users/?username=ci-importer` returned 200 with count 1: id 3, is_active true, is_staff true, is_superuser false.
- `GET /api/v2/users/2/` returned 404, so the failed-attempt user is gone.
- The variables are `DEFECTDOJO_RUNS_ON=occ-homelab-defectdojo` and `DEFECTDOJO_URL=https://defectdojo.infra.ottawacloudconsulting.com`.
- The secret `DEFECTDOJO_API_TOKEN` is present (updatedAt 2026-09-29T00:14:10Z).
- CA_CERT and INSECURE are absent.
- `~/.config/defectdojo/` has 0 `ci-importer*` files.
- The plan's verify passed. The evidence contains no 40-hex string and no `Token <value>` string.

## Deviations from Plan

### Auto-fixed / operator-approved issues

**1. [Rule 1 - Bug] Plan defect: user-create body lacked the required `email` field**
- **Found during:** Task 2, first attempt 2026-09-28T23:49:09Z
- **Issue:** POST `/api/v2/users/` returned HTTP 400 `{"email":["This field is required."]}`. Nothing was created.
- **Fix:** With operator approval, `email:"ci-importer@ottawacloudconsulting.com"` was added to the body.
- **Files modified:** none (operator procedure)

**2. [Rule 1 - Bug] Orchestrator helper defect: wrong token self-check endpoint**
- **Found during:** Task 2, second attempt 2026-09-28T23:54:57Z
- **Issue:** ci-importer was created as id 2. The helper then checked the new token with GET `/api/v2/users/?username=ci-importer`, which returns 403 for a non-superuser. The 403 (not 401) meant the token authenticated but lacked permission. The script exited before any repo setting was changed, and the token and password were discarded.
- **Fix:** With operator approval, the operator deleted user id 2 (DELETE `/api/v2/users/2/` returned 204). The check was changed to GET `/api/v2/user_profile/`, and the third run succeeded as id 3. Consequence: user-privilege read-back must use the admin token, which Task 3 did.
- **Files modified:** none (the helper was a scratchpad file)

**3. [Rule 3 - Blocking] ugrep 7.8.4 needs `grep -F` for the `${{ }}` pattern (Task 1)**
- The plan's basic-regex `grep -c` counted 0 on the workstation's ugrep. A fixed-string match counts the expected 2, and the comment filter is unchanged. This is documented in `evidence/29-14-precondition-gate.txt` (commit d412ee2).

**4. [Evidence wording] CA_CERT/INSECURE absence lines omit the `DEFECTDOJO_` prefix**
- The plan's verify fails if either full name appears anywhere in the evidence. The absence lines therefore name them as `CA_CERT` / `INSECURE`.

## Threat Flags

None. The only new surface is the ci-importer identity and the repo secret, both covered by T-29-03 and T-29-21.

## Known Stubs

None.

## Self-Check: PASSED
- FOUND: evidence/29-14-precondition-gate.txt, evidence/29-14-settings-readback.txt
- FOUND commits: d412ee2, 71781e7
