---
phase: 28-defectdojo-dedup-and-triage
plan: 02
subsystem: DefectDojo System Settings bootstrap + offline proof (security-platform)
tags: [defectdojo, deduplication, triage, bootstrap, https-only, DDOJO-03, DDOJO-04]
requires:
  - "28-01: branch feature/phase-28-defectdojo-dedup-and-triage with the chart dedup guards"
provides:
  - "scripts/defectdojo-configure.sh: idempotent GET-compare-PATCH of 5 System Settings keys (D-10, D-21, D-22)"
  - "Token contract for 28-03: DEFECTDOJO_ADMIN_TOKEN_FILE holds the BARE superuser token in a 0600 file; optional DEFECTDOJO_CA_FILE is a CA file path"
  - "Output contract for 28-03: lines starting 'NO CHANGE:' / 'CHANGED: <keys>' / 'VERIFIED: all 5 settings match'"
  - "proof --scheme-only covers the configure script: P-HTTP configure-http/configure-noscheme, P-CONFIGURE-GUARD configure-no-env/configure-loose-perms"
  - "defectdojo-import-proof.yml path filter includes scripts/defectdojo-configure.sh"
affects: [28-03, 28-06, 28-08]
tech-stack:
  added: []
  patterns: ["bash wrapper + python3 stdlib heredoc body (Phase 27 idiom)", "drift-only PATCH with re-GET verification", "Preflight exception -> exit 2, Failed -> exit 1"]
key-files:
  created:
    - repos/security-platform/scripts/defectdojo-configure.sh
  modified:
    - repos/security-platform/scripts/defectdojo-import-proof.sh
    - repos/security-platform/.github/workflows/defectdojo-import-proof.yml
decisions:
  - "The configure script takes a CA FILE path (DEFECTDOJO_CA_FILE -> --cacert), not PEM text, and has no insecure mode"
  - "Drift compares type as well as value, so 1 vs True or '90' vs 90 counts as drift"
  - "Token-file preflight failures (missing, 0077 bits, empty) and a missing CA file raise Preflight -> exit 2; they are checked only after the https refusal"
  - "The proof exports DEFECTDOJO_CA_FILE empty in every configure case so the caller's environment cannot leak in"
metrics:
  duration: ~15 min
  completed: 2026-09-26
  tasks: 2
  files: 3
---

# Phase 28 Plan 02: DefectDojo System Settings bootstrap Summary

`scripts/defectdojo-configure.sh` is a new operator-run script. It takes a superuser token from a 0600 file and refuses any URL that is not https before it reads that file. It GETs `/api/v2/system_settings/` and PATCHes only the drifted keys to `/api/v2/system_settings/<id>/`, using the id the GET returned. It then re-GETs and verifies. The five desired values are:

- `enable_deduplication=true`
- `delete_duplicates=false`
- `false_positive_history=false`
- `retroactive_false_positive_history=false`
- `risk_acceptance_form_default_days=90`

`enable_finding_sla` is never sent. The offline proof now exercises the script's refusals, and a change to the script triggers the proof workflow.

## Tasks

| Task | Name | Commit (security-platform) | Files |
| ---- | ---- | ------ | ----- |
| 1 | Idempotent System Settings bootstrap | 9c56c8b | scripts/defectdojo-configure.sh |
| 2 | Offline refusal/guard proof + path filter | e201c11 | scripts/defectdojo-import-proof.sh, .github/workflows/defectdojo-import-proof.yml |

Both commits are local on `feature/phase-28-defectdojo-dedup-and-triage` and have not been pushed.

## Evidence

- **Task 1 verify.** The plan's automated command printed OK. The file is mode `-rw-r--r--` and passes `bash -n`. `shellcheck` passed when run directly and again through the pre-commit hook. The `-k`/`--insecure`/`-q` grep and the non-comment `enable_finding_sla` grep both came back empty.
- **Offline refusals and guards** (manual, beyond the plan):

  | Input | Exit | Output |
  | ----- | ---- | ------ |
  | No env | 2 | |
  | http:// URL | 1 | `must be https://`; token not printed |
  | Argument given | 2 | usage |
  | Empty `DEFECTDOJO_ADMIN_TOKEN_FILE` | 2 | FATAL naming the variable |
  | 0644 token file | 2 | FATAL with the path and mode |
  | Missing token file | 2 | |
  | Missing CA file | 2 | |
  | https URL, nothing listening | 1 | `FAILED: GET ... http=000` |

- **Mock HTTPS server** (scratchpad only, self-signed certificate, reached through `--cacert` plus a `CURL_HOME` curlrc `resolve` line):
  - Run 1 printed `CHANGED: enable_deduplication, false_positive_history, risk_acceptance_form_default_days` then `VERIFIED: all 5 settings match`, exit 0.
  - The PATCH body held only those 3 keys. `enable_finding_sla` was not sent, and the Content-Type was application/json.
  - Run 2 printed `NO CHANGE: all 5 settings already match (...)`, exit 0, and made a single GET.
  - Without the CA, curl returned error 60 (self-signed certificate), so TLS verification is on. The script printed FAILED and exited 1.
- **`--scheme-only` count:** 3 assertions before this plan, 7 after (3 + 4). The new lines are `P-HTTP PASS configure-http`, `P-HTTP PASS configure-noscheme` and two `P-CONFIGURE-GUARD PASS` lines. The existing import-http, import-noscheme and delete-http cases still pass. The dummy token (`p27http...`) appears 0 times in the output.
- **Mutation test:** disabling the 0077 permission check in the configure script turned `configure-loose-perms` into a FAIL. The failure reported three things: an `http=` line was printed, the exit code was 1 instead of 2, and no FATAL line appeared. The proof printed `PROOF FAIL - 1 of 7`. The file was restored with `git checkout` before committing.
- **Task 2 gates:**
  - `--extract-only` passed.
  - `actionlint` was clean.
  - `check-workflow-uploads.sh` printed PASS - 19 checks.
  - `check-detector-parity.sh` printed PASSED 20 / FAILED 0.
  - `check-defectdojo-chart.sh` printed PASS - 22 checks, 0 failures.
  - `yq` lists `scripts/defectdojo-configure.sh` in `on.pull_request.paths`, and `timeout-minutes` is still 60.
  - The working tree is clean.
  - The pre-commit hooks (shellcheck, yamllint) passed.

## Deviations from Plan

**1. [Design choice within spec] `api()` takes the body as a path argument named `body`, not `body_path`.**
- The plan names the signature `api(method, path, expect, body_path=None)`. The script has `api(tls_args, method, path, expect, body=None)`, which follows the dd-delete helper that passes `tls_args` explicitly. The temp-file path variable is still `body_path`, and it is removed in `finally`.
- Behaviour is the same: every response is parsed as JSON and returned, and the caller checks its shape. A GET must return a `results` list with exactly one object that has an integer id. A PATCH must return an object.

**2. [Rule 2 - Correctness] Added a `Preflight` exception (exit 2) next to `Failed` (exit 1).**
- The token-file and CA-file checks happen in Python after the https refusal, but must exit 2. A separate exception keeps the `finally` cleanup on that path.

**3. [Rule 2 - Correctness] Drift also compares types.**
- The API could return a value that is equal in Python but has the wrong type, for example `1 == True`. The script treats that as drift, so it never reports NO CHANGE on it.

## Known Stubs

None.

## Threat Flags

None. T-28-05 through T-28-10 are mitigated as the register specifies:

- The token goes into a 0600 O_EXCL header file and is sent with -H @file. The dummy token is absent from the proof output (T-28-05).
- The https refusal comes first and curl is pinned with `--proto =https --proto-redir =https` (T-28-06).
- There is no -k or insecure option, and the no-CA mock run failed closed (T-28-07).
- A token file with any 0077 permission bit is refused (T-28-08).
- The header comment says the bootstrap token is never the CI token or a GitHub secret (T-28-09).
- Only drifted keys are PATCHed, `enable_finding_sla` is never sent, and the result is re-GET verified (T-28-10).

## Self-Check: PASSED

- `repos/security-platform/scripts/defectdojo-configure.sh` exists. The two modified files have the changes described above.
- Commits 9c56c8b and e201c11 are present in the security-platform `git log`.
