---
phase: 27-defectdojo-ci-auto-import
plan: 11
subsystem: ci-defectdojo-side-channel
tags: [security, defectdojo, tls, cr-01, gap-closure]
gap_closure: true
requires: ["27-10"]
provides:
  - "https-only refusal and curl --proto pins in dd-import and dd-delete"
  - "SCHEME gate check (19th) with ordering assertion"
  - "P-HTTP proof case and offline --scheme-only mode"
affects: ["27-12 (publish)", "27-13", "27-14 (ADR-025)", "Phase 29"]
tech-stack:
  added: []
  patterns: ["RED-then-GREEN gate/proof before fix", "ordering assertion instead of presence-only substring"]
key-files:
  modified:
    - repos/security-platform/.github/workflows/security.yml
    - repos/security-platform/scripts/check-workflow-uploads.sh
    - repos/security-platform/scripts/defectdojo-import-proof.sh
decisions:
  - "dd-delete checks the scheme before its default-branch refusals, so a misconfigured URL fails loudly even on a refusal-path run"
  - "P-HTTP masks the dummy token when echoing body logs, and also asserts the token is absent from the log"
  - "One security-platform commit for all three tasks, as the plan's RED/RED/GREEN order requires (tasks 1-2 say 'do not commit yet')"
metrics:
  completed: 2026-09-25
  tasks: 3
  files: 3
---

# Phase 27 Plan 11: CR-01 https-only DefectDojo URL Summary

Both DefectDojo side-channel bodies now refuse any non-https `DEFECTDOJO_URL` as the first statement of `main()`. The refusal runs before the TLS label, before the token header is written and before any request. Every curl call is pinned with `--proto =https --proto-redir =https`. The offline gate enforces this through the new SCHEME check, which also asserts the ordering. The P-HTTP case proves it by running the committed bodies.

## Commits

| Repo | SHA | Message |
|------|-----|---------|
| repos/security-platform (branch `fix/phase-27-https-only`, local only, not pushed) | ba3683a | fix(27-11): refuse non-https DEFECTDOJO_URL and pin curl to https (CR-01) |

The branch was cut from origin/main at 0f7e4e1. `git rev-list --count origin/main..HEAD` = 1, and `git ls-remote --heads origin fix/phase-27-https-only` is empty.

## RED evidence (before the fix)

**Task 1:** `bash scripts/check-workflow-uploads.sh` exited 1 with `FAILED - 8 check(s)`. All 8 failures were SCHEME: three missing fragments plus the ordering failure, for both `jobs.defectdojo-import step dd-import` and `jobs.defectdojo-cleanup step dd-delete`. No other check failed.

**Task 2:** `bash scripts/defectdojo-import-proof.sh --scheme-only` exited 1:
```
PROOF: P-HTTP FAIL import-http: DD_URL=http://127.0.0.1:9: no 'must be https://' refusal line; a 'TLS mode:' line was printed; an 'http=' request line was printed; results file results-import-http.json was written;
PROOF: P-HTTP FAIL import-noscheme: DD_URL=127.0.0.1:9: no 'must be https://' refusal line; a 'TLS mode:' line was printed; an 'http=' request line was printed; results file results-import-noscheme.json was written;
PROOF: P-HTTP FAIL delete-http: DD_URL=http://127.0.0.1:9: no 'must be https://' refusal line; a 'TLS mode:' line was printed; an 'http=' request line was printed;
PROOF FAIL - 3 of 3
```
The unfixed body printed `TLS mode: verified-system` and made real curl attempts to 127.0.0.1:9. This reproduces CR-01. `--extract-only` still passed (`EXTRACT PASS`).

## GREEN evidence (after the fix, from repos/security-platform)

- `bash scripts/check-workflow-uploads.sh` -> `PASS - 19 checks, 0 failures`
- `bash scripts/check-detector-parity.sh` -> `check-detector-parity: PASSED 20 / FAILED 0`
- `actionlint` -> exit 0
- `bash scripts/defectdojo-import-proof.sh --extract-only` -> `EXTRACT PASS - .github/workflows/security.yml`
- `bash scripts/defectdojo-import-proof.sh --scheme-only` -> `PROOF PASS - 3 assertions` (import-http, import-noscheme, delete-http; each refused with `FAILED: DEFECTDOJO_URL must be https:// — refusing to send the API token over 'http'` / `'(no scheme)'`)
- Parent repo `bash scripts/check-adoption-guide.sh` -> `check-adoption-guide: PASSED 16 / FAILED 0`
- `shellcheck` on both scripts -> exit 0; pre-commit (shellcheck, yamllint) passed at commit time
- The plan's Task 3 `<verify>` block, run verbatim -> exit 0

**Scratch negative self-tests.** Both ran with `WORKFLOWS_DIR` pointing at copies in the session scratchpad:
- dd-delete refusal removed: SCHEME failed for `defectdojo-cleanup` only, on the missing fragment and on ordering (`FAILED - 2 check(s)`).
- dd-import refusal moved below `write_private(hdr_path`: SCHEME failed for `defectdojo-import` only, with the ordering message `the https refusal ('startswith("https://")') must precede the header write ('write_private(hdr_path')` (`FAILED - 1 check(s)`).

**Case-insensitivity spot check:** the extracted fixed dd-import body run with `DD_URL=HTTPS://127.0.0.1:9` was accepted (`TLS mode: verified-system`, rc 0, empty reports dir).

**Acceptance greps** on security.yml:
- `url.lower().startswith("https://")` = 2, `"--proto-redir", "=https"` = 2, `"--proto", "=https"` = 2
- No comment line contains `startswith(` or `--proto`
- Line order in dd-import: refusal L1426 < `TLS mode:` L1443 < `write_private(hdr_path` L1456
- Line order in dd-delete: refusal L1796 < `TLS mode:` L1825 < `write_private(hdr_path` L1828
- The mode_hook call to `prove_http_refusal` comes after the P-INSECURE block and before `proof_finish`
- In the two scripts, the only removed lines are the CHECK_COUNT, the comment list, the usage and the header lines

## Deviations from Plan

None. The plan was executed as written. One addition within scope: P-HTTP pipes each body log through a mask that replaces the dummy token with `<dummy-token>` before echoing it to the terminal (threat T-27-02, defence in depth). The log file itself is not changed, so the token-absent assertion is still checked against the raw log.

## Threat Flags

None. The change removes network surface and adds none.

## Known Stubs

None.

## Self-Check: PASSED
- FOUND: repos/security-platform commit ba3683a on fix/phase-27-https-only
- FOUND: all three modified files contain the required markers (`--proto-redir`, `SCHEME`, `P-HTTP`)
