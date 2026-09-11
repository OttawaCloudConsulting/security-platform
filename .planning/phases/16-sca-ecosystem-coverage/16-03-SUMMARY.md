---
phase: 16-sca-ecosystem-coverage
plan: 03
subsystem: scan-harness
tags: [smoke-gate, npm-audit, pip-audit, tflint, sarif, exit-codes, negative-test, skipped-not-passed]
requires:
  - "16-01 fixtures (68c3bbb) — package-lock.json, requirements.txt and main.tf are the inputs every assertion below is measured against"
  - "16-02 detectors and helpers (29dbc62) — detect-{npm,python,terraform}.sh, run_scan_rc, require_parses_json, HAVE_* flags, SKIPPED array"
provides:
  - "scripts/smoke-scans.sh sub-scan sections for SCA-01 (npm audit), SCA-02 (pip-audit) and SCA-03 (tflint), each asserting on report CONTENT"
  - "The measured local baseline 16-05 must compare its CI run against (severity histogram, advisory counts, tflint rule-id set, tool versions)"
  - "The Criterion 4 clean-skip negative test — the only place the skip path is observable, since the product repo has all three ecosystems"
affects:
  - "16-04 security.yml SCA steps (the invocations proven here are the ones CI should carry)"
  - "16-05 live-run evidence extraction (matches on the labels npm-audit / pip-audit / tflint)"
  - "17/18 (gate thresholds — pip-audit carries no severity field; npm and tflint do)"
tech-stack:
  added: []
  patterns:
    - "Verdict assertions read the report, never the exit code: npm audit and pip-audit both exit 1 for findings AND for bad input"
    - "Set-intersection assertion on SARIF ruleId values instead of a finding count"
    - "Wrapper functions (npm_audit_to_file / tflint_sarif_to_file) keep shell redirection out of run_scan_rc's argument list"
    - "Negative test runs the real detector scripts inside a throwaway git init repository with GITHUB_OUTPUT unset"
key-files:
  created: []
  modified:
    - repos/security-platform/scripts/smoke-scans.sh
    - repos/security-platform/fixtures/README.md
key-decisions:
  - "SKIPPED bookkeeping for pip-audit/tflint moved out of the preflight into the sub-scan sections, so one absent tool is counted as exactly one skipped sub-check"
  - "Two scoped SC2329 suppressions added on the new wrapper functions (invoked indirectly through run_scan_rc); the 16-02 suppression on require_parses_json was deleted as instructed"
  - "git init written as (cd \"$PROBE_DIR\" && git init -q) rather than git -C, because the plan's own verify greps for the literal string 'git init'"
  - "Three commits, not one: Task 1 and Task 2 each carry their own commit and the deferred fixtures/README.md rewording is a separate docs commit, with the plan-mandated subject last"
patterns-established:
  - "Pattern: assert the discriminating top-level key (auditReportVersion / dependencies / runs) before asserting on counts"
  - "Pattern: a skip probe passes only on rc=0 AND a ^SKIP: line — rc alone would accept a silent skip"
requirements-completed: [SCA-01, SCA-02, SCA-03]
duration: ~35min
completed: 2026-09-11
---

# Phase 16 Plan 03: Local Proof of the Three SCA Sub-Scans Summary

**The smoke gate now runs npm audit, pip-audit and tflint against the real fixtures and renders its verdict from report content — severity histogram, advisory count and SARIF pinning rule ids — plus a negative test that proves all three detectors skip cleanly in an empty git repository.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-09-11T13:38Z
- **Completed:** 2026-09-11T13:58Z (last code commit 13:53:17Z)
- **Tasks:** 2 of 2
- **Files modified:** 2 (`scripts/smoke-scans.sh`, `fixtures/README.md`)
- **Commits (all in `repos/security-platform`, branch `feature/phase-16-sca-ecosystem-coverage`):**

| Commit | Subject |
|---|---|
| `bfb57e0` | `test(16-03): add npm audit, pip-audit and tflint sub-scan sections` (Task 1) |
| `6ae3019` | `docs(16-03): correct the pip-audit vs Trivy count explanation in fixtures` (deferred item) |
| `34d53ff` | `test(16-03): prove npm, Python and Terraform sub-scans plus the clean-skip path locally` (Task 2) |

Nothing was pushed from either repository.

## Measured Values — from the final gate run, not from RESEARCH

Every number below is copied from `/tmp/smoke-16-03-final.log`, produced by
`bash scripts/smoke-scans.sh` at 2026-09-11 09:50 EDT on commit `34d53ff`'s content.

| Sub-scan | Exit | Measured result |
|---|---|---|
| `npm-audit` | 1 | histogram `info=0 low=0 moderate=0 high=1 critical=1 total=2`; `lodash` high, `minimist` critical; high+critical = 2 |
| `pip-audit` | 1 | 7 resolved dependencies, **46 advisory entries / 23 unique ids**; per package: `requests` 10, `jinja2` 10, `idna` 4, `urllib3` 22 entries |
| `tflint` | 2 | rule ids `['terraform_module_version', 'terraform_required_providers', 'terraform_required_version']`; **pinning subset `['terraform_module_version', 'terraform_required_providers']`** |
| `skip-npm` / `skip-python` / `skip-terraform` | 0 | each printed its `SKIP:` line and wrote no list file |

Re-measured Phase 15 scanners in the same run (for drift tracking). Each prior figure is cited to
the SUMMARY it was measured in — none is quoted from memory, and where no prior plan recorded a
figure the cell says so:

| Scanner | This run | Previously recorded | Source |
|---|---|---|---|
| Semgrep findings | 3 (same three rule ids) | 3 | 15-02-SUMMARY |
| Checkov failed, terraform | 12 | 12 (was 10 before the unpinned module) | 16-01-SUMMARY |
| Checkov failed, all frameworks | 14 (terraform 12 + dockerfile 2) | not recorded as a total by 16-01 | — |
| Trivy fs, unfiltered | 19 (9 npm + 10 pip) | 19 (9 npm + 10 pip) | 16-01-SUMMARY |
| Trivy fs, HIGH/CRITICAL (gated) | **6** (package-lock 5 + requirements 1) | 5 (package-lock only) | 15-02-SUMMARY — measured before `fixtures/requirements.txt` existed; the +1 is that fixture's HIGH, consistent with 16-01's "1 HIGH, 9 MEDIUM" pip split |
| Trivy image, HIGH/CRITICAL | 56 | 56 | 15-02-SUMMARY; 16-01 re-measured the same image as 222 total incl. 4 CRITICAL + 52 HIGH |
| Gitleaks findings | 9 (identical file/line list) | 9 | 15-02-SUMMARY, re-verified in 15-03 |
| `SCANS_PASSED` | **9** gated runs | 6 | 16-02-SUMMARY |

**Local tool versions — 16-05 must compare its CI rule ids against these, not assume a match:**

| Tool | Local (this run) | CI (expected) |
|---|---|---|
| tflint | **0.61.0**, `ruleset.terraform 0.14.1-bundled` | v0.64.0 — deliberate split, mirroring the Trivy/Gitleaks split in 15-05 |
| pip-audit | **2.10.1** | pip-installed latest |
| npm | 11.7.0 | runner-provided |
| python3 | 3.12.0 | runner-provided |
| Trivy / Checkov / Semgrep / Gitleaks | 0.74.0 / 3.2.396 / (pyenv 3.12 install) / as Phase 15 | per 15-05 |

**Explicit warning for 16-05:** RESEARCH lists four SARIF rule ids including
`terraform_module_pinned_source`. That fourth id came from a *reproduction* fixture, not from
`fixtures/main.tf`. This repository emits **three** ids, of which **two** are pinning ids. Compare
CI against three, and treat a `terraform_module_pinned_source` appearance under v0.64.0 as new
information rather than confirmation.

## What Was Built

### Task 1 — three sub-scan sections (`bfb57e0`)

Inserted as sections 5, 6 and 7 between the gated Trivy fs section and the container section (the
container and secrets sections were renumbered to 8 and 9 rather than leaving gaps).

- **SCA-01 npm audit.** Guarded by `bash scripts/detect-npm.sh "$OUT/npm-lockfiles.txt"` — the
  `$OUT` argument is always passed, so no list file is ever written into the checkout. Loops over
  every discovered lockfile (consumer repos are not guaranteed a single root manifest), writing
  `$OUT/npm-audit-<n>.json`. `run_scan_rc 1 "npm-audit" npm_audit_to_file …` →
  `require_nonempty` → `require_parses_json … auditReportVersion` → a verdict assertion that
  `metadata.vulnerabilities` high+critical exceeds zero, which also **prints** the histogram and
  every package's severity.
- **SCA-02 pip-audit.** Locked invocation `pip-audit -r <file> --format json
  --progress-spinner=off -o <out>` through `run_scan_rc 1`, then `require_nonempty`,
  `require_parses_json … dependencies`, and a verdict assertion on the total `vulns` count. An
  inline comment records that pip-audit emits **no severity and no CVSS field anywhere**, so the
  count is over advisory IDs and no threshold can be derived from it — the fact Phase 17/18 must
  not infer from the npm section's shape.
- **SCA-03 tflint.** `run_scan_rc 2 "tflint" tflint_sarif_to_file "$OUT/tflint.sarif"` —
  rc 2 is findings, rc 1 is an application error. SARIF reaches the file by shell redirection
  because tflint has no output-file flag. The verdict is a **set intersection** of the
  `runs[].results[].ruleId` values with
  `{terraform_required_providers, terraform_module_version, terraform_module_pinned_source}`;
  the full rule-id set is printed. `terraform_required_version` appears exactly once in the file,
  in a comment explaining why it does not count (it reports an absent top-level version block and
  already fires on this fixture). A second comment records that tflint's default ruleset does not
  flag a floating `>=` range, so Criterion 3 is satisfied through missing constraints and unpinned
  module sources only.
- The `# shellcheck disable=SC2329` on `require_parses_json` was **deleted**, as 16-02's carried-
  forward note instructed: it now has three call sites.

### Task 2 — Criterion 4 negative skip test (`34d53ff`)

A final section before the summary block creates `mktemp -d`, runs `git init -q` in it, and invokes
each real detector from inside it with `env -u GITHUB_OUTPUT`. A probe passes only on **rc=0 AND a
line matching `^SKIP:`** — a detector that exits 0 while printing nothing is recorded as a FAILURE,
which is the silent-skip false pass the test exists to catch. It additionally asserts that no list
file (`npm-lockfiles.txt`, `py-reqs.txt`, `tf-files.txt`) was written on the skip branch. The
existing EXIT trap is *extended* (`trap 'rm -rf "$OUT" "$PROBE_DIR"' EXIT`) rather than joined by a
second trap, which bash would silently replace, and the directory is also removed explicitly at the
end of the section. A comment states why a live CI run can never replace this test: the product repo
carries all three ecosystems, so CI always takes the FOUND branch.

## Verification (observed results, not predictions)

| Check | Result |
|---|---|
| `bash -n scripts/smoke-scans.sh` | parses |
| `shellcheck scripts/smoke-scans.sh` (v0.11.0, same as the hook) | rc=0 |
| Plan verify 1 (static greps: `run_scan_rc 2`, `terraform_module_version`, `auditReportVersion`, `progress-spinner=off`, `recursive`; negative greps for the dependency-skipping / hash-requiring / soft-fail flags) | PASS |
| Plan verify 2 (`bash scripts/smoke-scans.sh`) | **rc=0**; PASS lines for `npm-audit`, `pip-audit`, `tflint` |
| Plan verify 3 (pinning rule id + severity words in the log) | PASS |
| Task 2 verify 1 (`mktemp -d`, `git init`, `detect-`, `bash -n`) | PASS (see Deviation 3 — first form used `git -C` and failed this grep) |
| Task 2 verify 2 (full gate + skip-probe PASS lines) | **rc=0**; `skip-npm`, `skip-python`, `skip-terraform` all PASS |
| Probe dir and `$OUT` removed after the run | both `[ ! -d … ]` true |
| **Soft-skip path exercised, not assumed** — gate re-run with `pip-audit` and `tflint` removed from PATH | **rc=0**; `Optional tooling: pip-audit=0 tflint=0`; both sections printed `SKIPPED:`; **exactly 2** SKIPPED entries; no `pip-audit`/`tflint` PASS line; 7 gated runs instead of 9; skip probes still PASS |
| `pre-commit run --all-files` (post-commit) | rc=0 — shellcheck / yamllint / markdownlint Passed |
| `git status --porcelain` | empty |
| `git log -1 --format=%s` | `test(16-03): prove npm, Python and Terraform sub-scans plus the clean-skip path locally` |
| `git diff --diff-filter=D HEAD~3 HEAD` | no file deletions |

The restricted-PATH run was built by mirroring every binary in `/opt/homebrew/bin` and
`~/.local/bin` into a scratch shim directory **except** `tflint` and `pip-audit`, then dropping the
two originals from `PATH` — so only the two optional tools were made absent.

## Deviations from Plan

### 1. [Rule 3 — blocking issue] Two scoped `SC2329` suppressions on the new wrapper functions

- **Found during:** Task 1, `shellcheck` before commit.
- **Issue:** `npm_audit_to_file` and `tflint_sarif_to_file` are invoked as the *command argument*
  of `run_scan_rc`, which runs them via `"$@"`. ShellCheck 0.11.0 counts only command-position
  usage in this file and reported `SC2329 (info): This function is never invoked` for both, which
  the pre-commit hook fails on.
- **Alternatives measured and rejected:** the `bash -c '…'` form the wrappers replace draws
  `SC2016` instead (reproduced in a scratch file, so this is a swap of one suppression for
  another); running the scanner inside a `( cd … )` subshell would lose every `FAILURES` and
  `SCANS_PASSED` update, which is a correctness regression, not a style one.
- **Fix:** one scoped `# shellcheck disable=SC2329` per wrapper, with a comment naming the real
  call site and the `grep` that checks it. ShellCheck's own message documents this false-positive
  class ("or ignored if invoked indirectly"). Unlike the 16-02 suppression this plan deleted, these
  describe reality: each wrapper has exactly one live call site.
- **Commit:** `bfb57e0`

### 2. [Rule 2 — honest accounting] `SKIPPED` bookkeeping moved from the preflight into the sections

- **Found during:** Task 1.
- **Issue:** 16-02's preflight already appended a `SKIPPED` entry when `pip-audit`/`tflint` was
  absent, and this plan requires the *section* to append one. Doing both would make a single absent
  tool count as two skipped sub-checks in a gate whose entire purpose is honest accounting.
- **Fix:** the preflight keeps its `NOTE:` line and the `HAVE_*` flag; the section owns the
  `SKIPPED` entry. The observable output 16-02 tested is unchanged, and the section now also
  appends an entry for the *other* skip reason (ecosystem not present in the repository), which the
  preflight could never express. **Verified:** the restricted-PATH run reports exactly 2 skips.
- **Commit:** `bfb57e0`

### 3. [Rule 1 — bug, caught by the plan's own verify] `git -C` replaced with `(cd … && git init -q)`

- **Found during:** Task 2 verification.
- **Issue:** the first implementation used `git -C "$PROBE_DIR" init -q`, which is behaviourally
  identical but does not contain the literal string `git init` that the plan's verify command
  greps for. The verify failed.
- **Fix:** `(cd "$PROBE_DIR" && git init -q)` in a subshell — the plan's literal form, no change in
  behaviour. Recorded because the same class of mismatch bit Phase 15-03.
- **Commit:** `34d53ff`

### 4. [Scope — deferred item absorbed] `fixtures/README.md` rewording

- 16-02 deferred the 16-01 rewording of the pip-audit vs Trivy count paragraph to this plan, which
  commits to the same repository next. Absorbed as its **own** `docs(16-03)` commit made *before*
  the final test commit, so the plan's pinned `git log -1` subject is unaffected.
- The replacement text is measured rather than copied: pip-audit reports every advisory exactly
  twice (46 entries = 23 unique ids), and the **10 unique advisories on the two direct pins carry
  exactly Trivy's 10 `requirements.txt` CVE ids as `aliases`** — verified as an identical set, so
  the two rows describe the same ten vulnerabilities in the `PYSEC-*` and `CVE-*` namespaces. The
  earlier wording ("counts an advisory per source") was a guess at the mechanism.
- **Commit:** `6ae3019`

### 5. [Process] Three commits rather than one

The plan names a commit subject only for Task 2. Task 1 is independently verifiable (its own green
gate run), so it carries its own commit, per the executor's per-task commit protocol; the deferred
docs edit is separate again. The mandated subject is the last commit, satisfying the acceptance
criterion.

## Threat Model Compliance

| Threat ID | Disposition | Evidence |
|---|---|---|
| T-16-09 | mitigated | `require_parses_json "npm-audit" <file> auditReportVersion` plus the high+critical histogram assertion, both appending to `FAILURES`. 16-02 unit-tested the same helper against a real ENOLOCK object (FAIL) and a real report (PASS); this run shows the real report passing with `high=1 critical=1` |
| T-16-10 | mitigated | The tflint verdict is a set intersection with the three pinning ids. Measured: the fixture emits `terraform_required_version` too, and it is **excluded** — it appears exactly once in the script, in a comment saying why. Without this, "≥1 finding" would have passed with SCA-03 unproven |
| T-16-11 | mitigated | Restricted-PATH run: rc=0, both sections printed `SKIPPED:`, the summary listed exactly 2 entries under `A SKIP IS NOT A PASS`, no PASS line was emitted for either tool, and `SCANS_PASSED` dropped 9 → 7 |
| T-16-12 | accepted (unchanged) | The locked default resolving mode is used; the fixture pins two wheel-publishing packages. Observed: 7 dependencies resolved in ~13 s, no build step, workstation-local |
| T-16-13 | mitigated | Every sub-scan's verdict is a content assertion appending to `FAILURES`; a feed outage would produce an empty/absent report or a non-zero-but-unexpected rc, both of which fail. No `\|\| true` appears on any assertion line — only on the pre-existing informational count prints |
| T-16-SC | mitigated | Zero package installs. `npm audit` never installs; pip-audit and tflint were already present. No `npm ci`, `npm install`, `pip install` or `terraform init` anywhere in the gate |

## Carried Forward

- **16-04 should copy the invocations proven here verbatim**: `npm audit --audit-level=high --json`
  from the lockfile's directory; `pip-audit -r <file> --format json --progress-spinner=off -o
  <out>`; `tflint --recursive --format sarif > <file>` with rc 2 meaning findings. The detectors
  take the list-file path as `$1`.
- **16-05 must not assume the CI rule-id set matches**: three ids locally under tflint 0.61.0, two
  of them pinning ids. CI runs v0.64.0.
- **pip-audit's JSON double-counts.** 46 entries, 23 unique ids on this fixture. Any later count
  must dedupe on `vulns[].id`; the gate prints both figures so neither can be quoted by accident.
- **`fixtures/README.md` counts are dated 2026-09-11** and will drift upward as advisories publish.
- **Two new scoped `SC2329` suppressions exist** (on the wrappers). Delete each wrapper and its
  directive together if a refactor removes the `run_scan_rc` call site.
- **The negative test is the only skip coverage that exists.** If a future plan moves the fixtures
  out of this repository, the FOUND branches lose their coverage instead — the reverse problem.

## Self-Check: PASSED

- `repos/security-platform/scripts/smoke-scans.sh` — FOUND (modified, committed)
- `repos/security-platform/fixtures/README.md` — FOUND (modified, committed)
- `.planning/phases/16-sca-ecosystem-coverage/16-03-SUMMARY.md` — FOUND (this file)
- Commits `bfb57e0`, `6ae3019`, `34d53ff` — FOUND in `repos/security-platform` on
  `feature/phase-16-sca-ecosystem-coverage`
- `git -C repos/security-platform status --porcelain` — empty
- No files deleted across the three commits
