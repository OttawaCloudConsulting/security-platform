---
phase: 16-sca-ecosystem-coverage
plan: 02
subsystem: scan-harness
tags: [detectors, smoke-gate, shellcheck, exit-codes, pathspec, skipped-not-passed]
requires:
  - "16-01 fixtures on feature/phase-16-sca-ecosystem-coverage (68c3bbb) — the positive path each detector is verified against"
provides:
  - "scripts/detect-npm.sh / detect-python.sh / detect-terraform.sh — one shared detection implementation for CI (16-04) and the smoke gate (16-03)"
  - "run_scan_rc <expected_rc> — lets 16-03 express tflint's rc=2 as findings"
  - "require_parses_json <label> <file> <required_key> — lets 16-03 reject an npm ENOLOCK error object"
  - "HAVE_PIP_AUDIT / HAVE_TFLINT flags and the SKIPPED array — the soft-skip accounting 16-03 reads"
affects:
  - "16-03 smoke-gate sub-scan sections (call sites for all of the above)"
  - "16-04 security.yml SCA steps (invoke the same three detectors)"
tech-stack:
  added: []
  patterns:
    - "Detector contract: optional $1 list-file path, log on both branches, always exit 0, guarded $GITHUB_OUTPUT append"
    - "Expected-exit-code parameter instead of per-tool special cases in the scan helper"
    - "SKIPPED array printed under its own heading, never affecting exit status"
key-files:
  created:
    - repos/security-platform/scripts/detect-npm.sh
    - repos/security-platform/scripts/detect-python.sh
    - repos/security-platform/scripts/detect-terraform.sh
  modified:
    - repos/security-platform/scripts/smoke-scans.sh
decisions:
  - "grep -v also excludes '^node_modules/' alongside '/node_modules/' — the plan's verbatim form misses a root-level vendored lockfile"
  - "SC2329 (function never invoked) suppressed with an inline directive naming 16-03 as the call site, rather than adding scan behaviour this plan forbids"
  - "Summary counts gated scan runs from the run itself (SCANS_PASSED) rather than hardcoding a scanner count that would go stale in 16-03"
metrics:
  duration: ~56min
  completed: 2026-09-11
---

# Phase 16 Plan 02: Shared Ecosystem Detectors and Generalised Smoke-Gate Helpers Summary

Three standalone detector scripts now provide the single ecosystem-detection implementation that both CI
and the local smoke gate call, and the smoke gate's helpers can express "exit code 2 means findings",
"this report is an error object, not a result", and "this sub-check was skipped, not passed" — with the
five Phase 15 scanners passing through the refactored helpers unchanged.

**Commit:** `29dbc62` — `test(16-02): add shared ecosystem detectors and generalise the smoke-gate
helpers`, on `feature/phase-16-sca-ecosystem-coverage` in `repos/security-platform`. One commit for both
tasks, by plan design. 4 files changed, 297 insertions, 15 deletions, 0 deletions of files. Nothing was
pushed from either repository.

## The Detector Contract (16-03 and 16-04 must not re-derive this)

Identical across all three scripts; only the pathspec, the default list-file name and the log wording
differ.

| Element | Value |
|---|---|
| Invocation | `bash scripts/detect-<x>.sh [LIST_FILE]` — never `./`, never `sh`, mode `644`, no executable bit |
| Argument | Optional `$1` = path of the list file to write, resolved as `"${1:-<default>}"`. Used as given, so an absolute `$OUT/...` path (16-03) and a repo-relative path (16-04) both work |
| Default list file | `npm-lockfiles.txt` / `py-reqs.txt` / `tf-files.txt` |
| Discovery | `git ls-files -- '<pathspec>'` in the **current working directory** — the scripts deliberately do **not** `cd` to their own repo root, which is what makes the 16-03 negative test in a throwaway `git init` dir meaningful |
| Pathspec | `*package-lock.json` (npm, minus node_modules) / `*requirements*.txt` (python) / `*.tf` (terraform) |
| Found branch | prints `FOUND <n> npm lockfile(s):` / `FOUND <n> Python requirements file(s):` / `FOUND <n> Terraform file(s):` followed by the paths one per line; writes those paths to the list file; writes `found=true` |
| Zero-match branch | prints one line with the literal prefix `SKIP: ` naming the ecosystem and stating the sub-scan is not applicable to this repository; **does not create the list file**; writes `found=false` |
| `$GITHUB_OUTPUT` | appended **only** inside `if [ -n "${GITHUB_OUTPUT:-}" ]`, exactly one `found=true\|false` line per invocation. With the variable unset the script still logs and still writes the list file |
| Exit code | `exit 0` on **every** path, including zero matches |

Exact SKIP strings (16-03's negative test may match on them):

```
SKIP: no package-lock.json found — npm sub-scan not applicable to this repository
SKIP: no requirements*.txt found — Python sub-scan not applicable to this repository
SKIP: no .tf files found — Terraform pinning sub-scan not applicable to this repository
```

(The `—` is U+2014, as in 16-RESEARCH's code examples.)

No `mapfile` anywhere: discovery is a `while IFS= read -r` loop accumulating into a counter and a
newline-joined string, so the shared scripts stay bash-3 compatible. **Verified by running, not just by
`bash -n`:** all three detectors were executed under `/bin/bash` 3.2.57 on both branches and exited 0.

## Smoke-Gate Changes (`scripts/smoke-scans.sh`)

1. **`run_scan_rc <expected_rc> <label> <cmd...>`** — PASS when rc equals the expected code, FAIL
   "scanner found nothing" when rc is 0 and the expected code is not, FAIL "tool/infrastructure error"
   otherwise. The three verdict strings are byte-for-byte the Phase 15 ones. `run_scan()` is now exactly
   `run_scan_rc 1 "$@"`; all six existing call sites (semgrep, checkov, trivy-fs, trivy-image,
   gitleaks×2) are untouched.
2. **`require_parses_json <label> <file> <required_key>`** — exists / parses as JSON / has the key at top
   level, pushing to `FAILURES` on any of those, following the `require_nonempty` shape. Python runs via
   a quoted heredoc with the file and key passed as `argv`, so no bash quoting applies to the f-string
   braces. No `|| true` on the assertion path: the rc is captured and acted on.
3. **Two-tier preflight.** Hard tier is `semgrep checkov trivy gitleaks docker python3 npm` — still
   `FATAL: … not found on PATH` + `exit 1`. Soft tier is `pip-audit` and `tflint` only: a named NOTE line
   with an install hint, `HAVE_PIP_AUDIT`/`HAVE_TFLINT` set to `0`, a `SKIPPED` entry, and the run
   continues. A log line `Optional tooling: pip-audit=N tflint=N` prints both flags.
4. **Strings and summary.** The header now covers the three Phase 16 sub-scans and explains the
   expected-rc and report-key mechanisms. `all five scanners produced real` is gone; the success line
   reads `ALL PASS - ${SCANS_PASSED} gated scan run(s) produced real, non-empty findings; N sub-check(s)
   skipped (not passed).` Skips print before the verdict on both the pass and fail paths under
   `SKIPPED - N sub-check(s) did not run. A SKIP IS NOT A PASS:`. Exit status is still non-zero iff
   `FAILURES` is non-empty.

## Verification (every line below is an observed result, not a prediction)

| Check | Result |
|---|---|
| Detectors, positive path from repo root, `GITHUB_OUTPUT` unset | rc=0 each; `FOUND 1 …`; list files contain `fixtures/package-lock.json`, `fixtures/requirements.txt`, `fixtures/main.tf` |
| Detectors, negative path in a fresh `git init` dir, `GITHUB_OUTPUT` unset | rc=0 each; `^SKIP:` printed; **no list file created** (`ls -A` showed only `.git`) |
| Detectors with `GITHUB_OUTPUT` set, 3 positive + 3 negative invocations | file contained exactly 6 lines: `found=true`×3 then `found=false`×3 |
| Detectors under `/bin/bash` 3.2.57, both branches | rc=0 on all 6 invocations |
| `test -x` / `bash -n` on all three | not executable (`-rw-r--r--`), all parse; `grep -c mapfile` = 0/0/0; `grep -L 'GITHUB_OUTPUT:-'` = empty |
| `run_scan_rc` unit harness (function extracted from the real file) | rc=2→PASS, rc=0→"found nothing", rc=1→"tool error" under `run_scan_rc 2`; and rc=2 through the rc=1 default still FAILs as a tool error — the regression 16-03's `run_scan_rc 2` call site exists to avoid |
| `require_parses_json` unit harness, 6 cases | real npm report PASS; ENOLOCK error object FAIL; unparseable FAIL; top-level JSON list FAIL (message, no traceback); zero-byte FAIL; missing file FAIL — 5 FAILURES from 6 cases, identical under bash 3.2 |
| `bash scripts/smoke-scans.sh`, all tools present | **rc=0**; same five scanners, six gated runs, all PASS; `ALL PASS - 6 gated scan run(s) …; 0 sub-check(s) skipped` |
| `bash scripts/smoke-scans.sh` with `pip-audit` and `tflint` removed from PATH | **rc=0**; both NOTE lines; `Optional tooling: pip-audit=0 tflint=0`; SKIPPED block listing both; scanners still all PASS |
| Hard tier with `npm` genuinely absent | rc=1, `FATAL: required binary 'npm' not found on PATH`, no scans run |
| `pre-commit run --all-files` (files staged first) | rc=0 — shellcheck/yamllint/markdownlint Passed |
| `git log -1 --format=%s` | `test(16-02): add shared ecosystem detectors and generalise the smoke-gate helpers` |

The restricted-PATH run was built by symlinking the hard-tier binaries that share a directory with the
optional ones (`trivy` from `~/.local/bin`, `gitleaks` and `pyenv` from `/opt/homebrew/bin`) into a
scratch shim dir and dropping those two directories, so the soft tier was exercised without disabling
anything else.

## Deviations from Plan

### 1. [Rule 2 — missing critical functionality] npm detector also excludes a root-level `node_modules/`

- **Found during:** Task 1
- **Issue:** The plan specifies `grep -v '/node_modules/'`. A vendored lockfile at
  `node_modules/foo/package-lock.json` (repo root) has no leading slash and would have survived the
  filter, sending `npm audit` into a vendored dependency's directory.
- **Fix:** `grep -v -e '/node_modules/' -e '^node_modules/'`. The pathspec and the plan's acceptance
  criterion ("excludes paths containing `/node_modules/`") are both still satisfied.
- **Commit:** 29dbc62

### 2. [Rule 3 — blocking issue] `shellcheck` SC2329 blocked the commit

- **Found during:** Task 2
- **Issue:** `pre-commit run --all-files` failed: `SC2329 (info): This function is never invoked` for
  `require_parses_json`. It is genuinely uncalled — by plan design, since its call sites are 16-03's
  sub-scan sections and this plan forbids adding scan behaviour.
- **Fix:** A single `# shellcheck disable=SC2329` immediately above the function, preceded by a comment
  explaining why it has no call site yet and instructing the next reader to remove the suppression once
  16-03 adds them. The alternatives were both worse: inventing a call site would break the
  behaviour-preserving property this plan exists to demonstrate, and relaxing shellcheck's severity
  globally would weaken every other script. `--no-verify` was never used.
- **Commit:** 29dbc62

### 3. [Rule 2 — staleness-proofing] Summary counts scan runs instead of naming a number

- The plan asks the summary to "report the actual scanner count". A literal `5`/`8` would be stale the
  moment 16-03 adds three sub-scans, which is exactly how the `all five scanners` string went stale.
  `SCANS_PASSED` is incremented inside `run_scan_rc`, so the figure is derived from the run. The wording
  is "gated scan run(s)", not "scanners", because Gitleaks is run twice (SARIF and JSON) — today's count
  is 6 for five scanners.

### Falsified assumption worth recording

The first attempt at the hard-tier FATAL check dropped the nvm `bin` directory and still exited 0.
Cause: a **second, older npm exists at `/usr/local/bin/npm`** (a 2023 system Node install), so the hard
tier was legitimately satisfied. Not a defect — but it means "npm is present" on this workstation does
not imply nvm is on PATH. Re-tested with an isolated shim PATH containing every hard-tier binary except
npm; that produced the expected rc=1 and `FATAL: required binary 'npm' not found on PATH`.

## Requirements Note

The plan's frontmatter lists SCA-01/02/03, but this plan ships **no scan behaviour** — it ships the
detection and harness primitives the sub-scans are built from. 16-03 (smoke gate) and 16-04 (CI workflow)
are where those requirements actually become executable. The verifier should read these checkboxes as
"the shared machinery the sub-scan depends on exists and is tested", not "the sub-scan runs".

## Carried Forward

- **`require_parses_json` carries a `# shellcheck disable=SC2329`.** 16-03 must delete that directive
  (and the comment paragraph above it that explains it) in the same edit that adds the first call site,
  or the repo keeps a suppression that no longer describes reality.
- **`fixtures/README.md` rewording from 16-01 is still outstanding** — logged in `deferred-items.md`.
  16-03 commits to the same repo next and should absorb it: "46 entries = 23 unique advisories reported
  twice each; the 10 unique IDs on the direct pins match Trivy's 10 exactly."
- **`SCANS_PASSED` counts runs, not tools.** If 16-03 wants a per-tool figure it needs a separate
  counter; do not reinterpret this one.
- **Detectors intentionally do not `cd`.** They inspect `$PWD`'s git index. Any future caller that runs
  them from outside the repository root will get that directory's answer — which is the property 16-03's
  negative test relies on, and a trap for anything else.
- **tflint rc=2 is still misclassified if called through `run_scan`.** The helper now *can* express it
  (`run_scan_rc 2`), but nothing enforces the right choice at the call site; this was measured in the
  unit harness above. 16-03's tflint section must use `run_scan_rc 2` explicitly.

## Threat Model Compliance

| Threat ID | Disposition | Evidence |
|---|---|---|
| T-16-05 | mitigated | Verbatim measured pathspecs (`*package-lock.json`, `*requirements*.txt`, `*.tf`); each detector was run against the real repo and discovered its fixture path; the wrong forms are named in each script's header comment so a future editor cannot "simplify" them back |
| T-16-06 | mitigated | `[ -n "${GITHUB_OUTPUT:-}" ]` guard present in all three (`grep -L` returns nothing); all six unset-variable invocations exited 0 and wrote complete list files; no list file is written at all on the SKIP branch, so a partial file is not reachable |
| T-16-07 | mitigated | `run_scan_rc` unit-tested across rc 0/1/2/127 with expected codes 1 and 2; `require_parses_json` unit-tested against a real npm report, an ENOLOCK error object, a JSON list, a zero-byte file, garbage and a missing file — five of six produced a FAILURES entry, none were swallowed |
| T-16-08 | mitigated | All four scripts are mode `644` (`git ls-tree` records `100644` for the three new ones); `test -x` false for each; no `chmod` was run; every invocation in the plan, the scripts' own comments and this summary is `bash scripts/…` |
| T-16-SC | mitigated | Zero package installs. The soft preflight only runs `command -v` on `pip-audit` and `tflint`; the NOTE lines print install instructions for a human and never execute them |

## Self-Check: PASSED

- `repos/security-platform/scripts/detect-npm.sh` — FOUND (mode 100644 in commit)
- `repos/security-platform/scripts/detect-python.sh` — FOUND (mode 100644 in commit)
- `repos/security-platform/scripts/detect-terraform.sh` — FOUND (mode 100644 in commit)
- `repos/security-platform/scripts/smoke-scans.sh` — FOUND (modified)
- Commit `29dbc62` — FOUND in `repos/security-platform` on `feature/phase-16-sca-ecosystem-coverage`
- `git -C repos/security-platform status --porcelain` — empty after commit
- No files deleted by the commit (`git diff --diff-filter=D HEAD~1 HEAD` empty)
