---
phase: 27-defectdojo-ci-auto-import
plan: 02
subsystem: ci-workflow
tags: [defectdojo, github-actions, reimport-scan, side-channel, workflow_call]
requires:
  - "27-01 side-channel gate contract (check-workflow-uploads.sh, 16 checks)"
provides:
  - "security.yml on.workflow_call.secrets.DEFECTDOJO_API_TOKEN (required: false)"
  - "scan jobs skip on pull_request closed (ids/names unchanged)"
  - "defectdojo-import job: dd-gate, dd-download, dd-import, dd-verify (env-only run bodies, extractable by the 27-05 harness)"
  - "dd-import-results.json schema per the Phase 27 side-channel contract"
affects: [27-03, 27-04, 27-05, 27-06, 27-09, 27-10]
tech-stack:
  added:
    - "actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c (v8.0.1)"
  patterns:
    - "Token checked by a gate step writing only a boolean to GITHUB_OUTPUT; secret only in step env"
    - "python3 heredoc calling curl per file: --form-string for every non-file field, -H @0600-header-file"
    - "continue-on-error import + red verify reading the outcome through step env (IMPORT-VERIFY-PAIRING)"
key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml
key-decisions:
  - "curl exit failures (DNS/TLS/refused) record http_code 000 with curl's stderr as the FAILED detail, so they fail verify rather than slip through"
  - "Skip reasons: trivy-image 'no Dockerfile in this repository', npm 'no package-lock.json', pip 'no requirements file', tflint 'no Terraform', otherwise 'report missing'"
  - "Import job header points to the adoption guide's DefectDojo section (by name, not path) for the staff-token requirement, since Mode A consumers have no docs/ tree"
requirements-completed: []  # DDOJO-02 partial (2 of 10 plans); marked complete by 27-10
duration: ~35min
completed: 2026-09-25
---

# Phase 27 Plan 02: DefectDojo import job in security.yml Summary

`security.yml` now has an opt-in, non-blocking `defectdojo-import` job. It downloads the run's `*-results` artifacts and sends each report file to `POST /api/v2/reimport-scan/` with one curl call, using its native parser (tflint uses SARIF). The job uses `auto_create_context=true` and a unique `test_title` for each file, and its red verify step checks the results. The file also declares `DEFECTDOJO_API_TOKEN` as an optional `workflow_call` secret, and the five scan jobs now skip on `pull_request` `closed`.

## Tasks

| Task | Name | Commit | Repo |
|------|------|--------|------|
| 1 | Declare the optional secret, reword the header, skip scan jobs on closed | `7126fa1` (combined, as the plan specifies) | security-platform, branch `feature/phase-27-defectdojo-ci-auto-import` |
| 2 | Add the defectdojo-import job (gate, download, reimport loop, red verify) | `7126fa1` | security-platform |

## What changed (security.yml, +404 / -2)

- Header: "exactly ONE per-repo substitution point" is replaced. `gate_mode` is now described as the only setting that changes gating. The header also lists the `DEFECTDOJO_*` caller variables and the secret, says none of them affects a required check, and names ADR-024.
- `on.workflow_call.secrets.DEFECTDOJO_API_TOKEN` is declared with a description and `required: false`. A WHY comment explains why it is not `secrets: inherit`.
- `if: github.event.action != 'closed'` is added directly under `name:` on sast, iac, sca, container and secrets. The full WHY comment is on sast and the other four say "see sast". Ids and names are unchanged.
- The `defectdojo-import` job follows the side-channel contract exactly: the needs list, the if, `timeout-minutes: 20`, `contents: read` and `actions: read`, and the concurrency group with `cancel-in-progress: false`. It has no job-level env, no `shell:` key and no `defaults:` block. It has four steps: `dd-gate`, `dd-download`, `dd-import` (continue-on-error) and `dd-verify`, and every step has its WHY comment.
- The injection-inventory comment in the container job now says the DefectDojo run bodies contain no context interpolation.

## Verification evidence

- `actionlint` exits 0.
- `check-workflow-uploads.sh` gives `PASS - 16 checks, 0 failures`. The four remaining NOTE lines all name `defectdojo-cleanup`, and none names `defectdojo-import`.
- `check-detector-parity.sh` exits 0 (`PASSED 20 / FAILED 0`).
- `bash scripts/check-adoption-guide.sh` in the doc repo exits 0 (`PASSED 15 / FAILED 0`).
- `git diff --quiet main -- scripts/set-required-checks.sh` exits 0.
- The yq acceptance queries give:
  - needs = the five scan jobs;
  - step ids in the order dd-gate, dd-download, dd-import, dd-verify;
  - dd-import continue-on-error `true`, dd-verify `null`;
  - job env `null`;
  - a `${{` count of 0 across the run bodies.
- Every literal string the plan requires is present in the dd-import body. The body contains no `set -x` and no `-H "Authorization`. The download-artifact pin appears exactly once.

### Behavioral test: extracted step bodies against a local mock server

I extracted the committed `dd-gate`, `dd-import` and `dd-verify` bodies with yq and ran them under `bash -e`. The server was a stdlib HTTP mock in the scratchpad. The reports directory held semgrep, trivy-fs and pip-audit-{1,2,10}.

| Case | Result |
|------|--------|
| Mock returns 201 with a test_id | Five `IMPORTED:` lines. pip-audit is imported in numeric order 1, 2, 10. There are five `SKIP: … — <reason>` lines, import rc 0, and verify prints `OK` five times, then the SKIP lines, then rc 0. The results file matches the contract schema. |
| Branch `@/etc/passwd` on pull_request | The request body carries `engagement_name=ci/@/etc/passwd` literally, with no file content read (so `--form-string` works). A trailing `/` on DD_URL is stripped. The `Authorization: Token …` header reaches the server from the header file. |
| Mock returns 400 with INSECURE=true and CA_CERT set | Both `::warning::` lines print, followed by `TLS mode: insecure`. Each file gets a `FAILED: <file> http=400 body=<first 500 chars>` line, and import rc is 1. |
| Connection refused with CA only | `TLS mode: verified-ca`, `FAILED: … http=000 body=curl: (7) …`, rc 1. |
| Empty branch | `FAILED: cannot resolve a branch name`, rc 1. |
| Temp directory after the runs | 0 leftover entries (header and CA files removed in `finally`). |
| Verify: outcome=failure / missing results file / empty attempted / 400 records | Each gives rc 1 with its specific message, including `NOTHING IMPORTED is not a pass: …`. |
| Gate: token present / empty token / `dependabot[bot]` actor | `enabled=true` / `enabled=false` with the D-13 SKIP line / `enabled=false` with the Dependabot SKIP line. |

The live DefectDojo behavior (real 201 responses, statistics, reimport in place) was **not** tested here. That belongs to the 27-05 and 27-06 proof harness.

## Deviations from Plan

None in substance. Two small implementation choices stay within the contract:
- The form fields are built as literal `"key=value"` strings, so the acceptance grep for `auto_create_context=true` matches the body as written.
- When curl itself fails and returns no HTTP code, the step records `http_code` as `"000"` and prints curl's stderr (truncated to 500 characters) as the FAILED detail. The verify step still goes red.

## Known Stubs

None. The header comments refer to ADR-024 and to a DefectDojo section of the adoption guide. Neither exists yet: 27-10 writes ADR-024, and a later plan in this phase writes the adoption-guide section. Both are forward references by design.

## Next Phase Readiness

- 27-03 can add `defectdojo-cleanup`. The gate will then enforce its shape, and the four remaining vacuous NOTE lines go away.
- 27-05 can extract `dd-import` and `dd-verify` by step id. The bodies read only env and the runner `GITHUB_*` variables, and curl carries no `-q`, so a harness `.curlrc` applies.

## Self-Check: PASSED
