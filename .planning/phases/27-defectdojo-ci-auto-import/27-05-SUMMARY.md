---
phase: 27-defectdojo-ci-auto-import
plan: 05
subsystem: live-proof-harness
tags: [defectdojo, kind, live-proof, least-privilege, tls, harness]
requires:
  - "27-02 defectdojo-import job (dd-gate, dd-download, dd-import, dd-verify) and the results-file schema"
  - "27-03 defectdojo-cleanup job (dd-gate, dd-delete, dd-cleanup-verify)"
  - "27-04 final check-workflow-uploads.sh (18 checks)"
  - "Phase 26 defectdojo-live-smoke.sh (kind bring-up, verified TLS)"
provides:
  - "defectdojo-live-smoke.sh: optional DD_SMOKE_POST_HOOK before the final print_summary (additive only)"
  - "scripts/defectdojo-import-proof.sh: entry, --extract-only and --hook modes; token minting; run-1 assertions"
  - "$DD_SMOKE_OUT/proof-run1.json: per-file run-1 numbers for 27-06's run-2 comparison"
affects: [27-06]
tech-stack:
  added: []
  patterns:
    - "Execute committed workflow run: bodies extracted with yq (single source of truth); refuse ${{ in any body"
    - "Env contract drift detection: step env: key set must EQUAL the side-channel contract"
    - "Host resolution via CURL_HOME/.curlrc resolve entry, reaching the bodies' own curl calls"
    - "Secrets exported into a subshell with the export builtin, never on an argv"
key-files:
  created:
    - repos/security-platform/scripts/defectdojo-import-proof.sh
  modified:
    - repos/security-platform/scripts/defectdojo-live-smoke.sh
key-decisions:
  - "--extract-only checks the step env: key set for EQUALITY with the contract, not just presence: an extra env name is also drift"
  - "--extract-only needs only yq and python3; the full hard tier (curl jq yq python3 kind kubectl helm docker openssl) is entry mode only"
  - "--hook re-runs the static extraction and executes only the bodies it just checked (P-EXTRACT)"
  - "npm-audit raw upper bound = per package, the number of dict-typed via advisories, or 1 when via holds only names"
  - "P-RUN1 also asserts tls_mode verified-ca and no ::warning:: line in the dd-import log"
requirements-completed: []  # DDOJO-02 partial (5 of 10 plans); marked complete by 27-10
duration: ~25min
completed: 2026-09-25
---

# Phase 27 Plan 05: Live proof harness (entry, extraction, run 1) Summary

The Phase 26 kind smoke now has an optional post-hook. `scripts/defectdojo-import-proof.sh` is that hook. It pulls the committed DefectDojo side-channel step bodies out of `security.yml` with yq and runs them itself. Imports run as a staff, non-superuser `ci-importer` over TLS verified against the kind CA. The script then asserts the whole run-1 state: gate paths, product, engagement, tests and finding counts. Every check is static-proven in this plan. The live run belongs to 27-06.

## Tasks

| Task | Name | Commit | Repo |
|------|------|--------|------|
| 1 | Add the optional post-hook to the kind smoke | `7e43593` | security-platform (branch `feature/phase-27-defectdojo-ci-auto-import`) |
| 2 | Write defectdojo-import-proof.sh (entry, --extract-only, token minting, run-1 assertions) | `7e43593` | security-platform |
| 2 (fix) | Read-side assertions: readonly env prefix, paged findings count | `bdbc34a` | security-platform |

The plan asked for one commit covering both tasks: `test(27-05): add DefectDojo import proof harness and smoke post-hook`.

## What was built

**Smoke post-hook (`defectdojo-live-smoke.sh`, +31 lines, 0 removed vs `main`).** The block sits immediately before the final `print_summary`, guarded by `[ "${#FAILURES[@]}" -eq 0 ] && [ -n "${DD_SMOKE_POST_HOOK:-}" ]`. It exports `BASE_URL SMOKE_HOST PF_PORT KIND_CONTEXT ADMIN_USER DD_CA_FILE DD_ADMIN_PW_FILE DD_SMOKE_OUT` and runs `bash "$DD_SMOKE_POST_HOOK" --hook`. The hook's exit status becomes one more check, `POST-HOOK`. A new header paragraph documents the contract. When the variable is unset the smoke prints nothing new.

**Proof script (`defectdojo-import-proof.sh`, 852 lines):**
- **Entry `<reports-dir>`.** Runs the hard-tier preflight, then requires the four report files every run produces (exit 2 names any that are missing). Next it self-runs `--extract-only` and exports `DD_PROOF_REPORTS` (absolute) and `DD_SMOKE_POST_HOOK` (the script's own absolute path). Finally it runs the smoke and exits with the smoke's code.
- **`--extract-only`.** Converts the workflow to JSON with yq once, then checks it with stdlib Python:
  - finds all six `run:` bodies, confirms none has a `shell:` key, and refuses `${{`;
  - runs `bash -n` on each body (written 0600);
  - requires each step's env key set to equal the contract exactly;
  - confirms `dd-download` is still a `uses:`-only step;
  - requires the two `dd-gate` bodies to be byte-identical.

  `DD_PROOF_WORKFLOW` overrides the workflow path for scratch self-tests.
- **`--hook`.** Every assertion prints one `PROOF: <ID> PASS|FAIL` line. The IDs are P-EXTRACT, P-TLS, P-ADMIN-TOKEN, P-USER, P-IMPORTER-TOKEN, P-GATE (×3), P-RUN1 (import + verify), P-CONTEXT, P-TESTS and P-COUNTS (a: `after.total.total` equals the findings API count; b: exact or bounded against the raw artifact).
  - A failure that later steps depend on aborts with `PROOF FAIL - k of n`.
  - The run-1 numbers are saved to `$DD_SMOKE_OUT/proof-run1.json`.
  - There are three `# 27-06:` markers, for run 2, the cleanup assertions and the insecure-warning check.
  - The final line is `PROOF INCOMPLETE - run-2 and cleanup assertions pending (27-06)`, with exit 1.

## Verification (all run, all observed)

| Check | Result |
|-------|--------|
| Baseline before edits: `check-defectdojo-chart.sh`, `check-workflow-uploads.sh`, shellcheck smoke | green; `PASS - 18 checks, 0 failures` |
| `shellcheck` + `bash -n` smoke; `git diff main` removed lines | exit 0; **0** removed lines |
| Hook placement | every non-comment `DD_SMOKE_POST_HOOK` at L758-767, after CA extraction (L607), before final `print_summary` (L771) |
| `bash scripts/defectdojo-import-proof.sh --extract-only` | exit 0; 6 body PASS lines + DD-GATE-IDENTICAL; `EXTRACT PASS` |
| Scratch copy with `echo "${{ github.head_ref }}"` injected into the dd-import `run:` (via `DD_PROOF_WORKFLOW`) | exit 1, `FAIL: defectdojo-import/dd-import: run: body contains a ${{ expression`; scratch file deleted |
| `/nonexistent` | exit 2 |
| Reports dir with only semgrep | exit 2, names the three missing files |
| `--hook` without smoke env / no args | exit 2 / exit 2 (usage) |
| No `--insecure`, no `curl ... -k`, no xtrace, no `/etc/hosts` | all four greps clean |
| `is_superuser` / `is_staff` / `CURL_HOME` counts | 5 / 5 / 6 |
| All nine assertion IDs present | yes |
| File modes | 644 and 644 |
| `check-workflow-uploads.sh` after | `PASS - 18 checks, 0 failures` |
| `check-defectdojo-chart.sh` after | exit 0 |
| Offline driver: `run_body` on the extracted dd-gate with no token / dependabot / token | `enabled=false` + SKIP line / `enabled=false` / `enabled=true`; the token value was found in no log or output file |
| Read-side Python heredoc | `py_compile` OK (222 lines) |
| Pre-commit hooks (shellcheck) on commit | Passed |
| curl 8.7.1: `CURL_HOME` curlrc `resolve` | observed `Added proof.smoke.invalid:18999:127.0.0.1 to DNS cache` |
| After fix `bdbc34a`: the readonly names reach Python via `export` (sourced functions) | printed `proof/security-platform CI` |
| After fix `bdbc34a`: stubbed `get()`, where the response has `next` set | `count_only=True` returns count 5; a list lookup is still refused ("more than one page") |
| After fix: shellcheck both, `--extract-only`, the four greps, mode 644, uploads 18/0, `/nonexistent` exit 2 | all unchanged and green |

No kind cluster was started and no live smoke was run (static-only per plan). The live run happens in 27-06.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Correctness] Additional P-RUN1 assertion on TLS mode**
- **Found during:** Task 2
- **Issue:** D-18 requires TLS to stay verified throughout. An exit-0 import could still have run with `tls_mode` other than `verified-ca`.
- **Fix:** P-RUN1 also asserts the results file's `tls_mode == verified-ca` and no `::warning::` line in the dd-import log. This matches on the `::warning::` marker, not the sentence (the 27-03 carry-forward).
- **Commit:** `7e43593`

**2. [Rule 2 - Correctness] Env contract checked for equality, not only presence**
- **Found during:** Task 2
- **Issue:** With a presence-only check, a new env name added to a committed step would go unnoticed. The harness would then run that body with inputs that differ from the runner's.
- **Fix:** `--extract-only` requires the step's env key set to equal the contract exactly.
- **Commit:** `7e43593`

**3. [Rule 1 - Bug avoidance] npm-audit raw upper bound**
- **Found during:** Task 2
- **Issue:** The v7+ parser can emit one finding per dict-typed `via` advisory. So `len(vulnerabilities)` is not a true upper bound, and a correct import could fail the bounded check.
- **Fix:** For each package, the raw count is the number of dict-typed `via` entries, or 1 when `via` holds only package names.
- **Commit:** `7e43593`

**4. [Rule 1 - Bug] Readonly names in a command-prefix assignment**
- **Found during:** final review, before handback
- **Issue:** The read-side `python3 -` call assigned the readonly `PROOF_PRODUCT` / `PROOF_PRODUCT_TYPE` in its command prefix. Bash refuses that: observed `A: readonly variable`, and the name was not passed to the child. Python would therefore raise `KeyError` before any P-CONTEXT/P-TESTS/P-COUNTS line printed.
- **Fix:** `export PROOF_PRODUCT PROOF_PRODUCT_TYPE` before the call.
- **Commit:** `bdbc34a`

**5. [Rule 1 - Bug] One-page guard rejected the count-only findings query**
- **Found during:** final review, before handback
- **Issue:** `get()` raised on any response with `next` set. The P-COUNTS query `findings/?test=<id>&limit=1` is paged whenever a test has more than one finding, so it would have aborted the whole read-side block.
- **Fix:** Added `get(..., count_only=True)` for that one call. List lookups keep the one-page refusal.
- **Commit:** `bdbc34a`

No other deviations. None of the five 26-REVIEW warnings blocked the hook (T-27-17 accept).

## Known Stubs

- `repos/security-platform/scripts/defectdojo-import-proof.sh` `proof_finish`: always ends `PROOF INCOMPLETE - run-2 and cleanup assertions pending (27-06)` and exits 1 when no assertion failed. This is intentional: the plan says a partial proof is never reported as a pass. 27-06 replaces it with `PROOF PASS - <n> assertions` / exit 0 once run 2, cleanup and the insecure-warning check exist (three `# 27-06:` markers). Until then, entry mode always ends with the smoke's POST-HOOK FAIL and exit 1.

## Open items for 27-06 (unmeasured, live only)

- The users API field names (`is_staff`, `is_superuser` in the GET response) and the tests API field names (`title`, `scan_type`) are taken from RESEARCH. They have not been observed live yet. A mismatch shows up as a named FAIL, never a silent pass.
- An unauthenticated `GET /api/v2/` may return 401/403. P-TLS asserts only curl exit 0, `ssl_verify_result` 0 and a non-000 code.
- If `api-token-auth` refuses `ci-importer` (for example a forced password reset), P-IMPORTER-TOKEN FAILs. Per plan, stop and report rather than work around it.
- The exact-count checks (checkov, trivy-fs, trivy-image, pip-audit) must not be relaxed to bounded checks without operator confirmation.

## Threat Flags

None. The only new surface is the harness itself (T-27-01/02/04/05 in the plan's register), and each mitigation is implemented. Credentials live in 0600 files under `umask 077`, go out with `--data-binary @file` or `-H @file`, and reach bodies only through `export`. Every harness curl uses `--cacert` with `ssl_verify_result` asserted. Imports run as `ci-importer`.

## Self-Check: PASSED

- FOUND: repos/security-platform/scripts/defectdojo-import-proof.sh
- FOUND: repos/security-platform/scripts/defectdojo-live-smoke.sh (hook block)
- FOUND: commit 7e43593 in repos/security-platform
- FOUND: commit bdbc34a in repos/security-platform
