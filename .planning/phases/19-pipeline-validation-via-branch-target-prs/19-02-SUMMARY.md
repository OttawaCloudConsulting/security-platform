---
phase: 19-pipeline-validation-via-branch-target-prs
plan: 02
subsystem: testing
tags: [semgrep, gitleaks, fixtures, documentation, smoke-gate, shellcheck, markdownlint]

# Dependency graph
requires:
  - phase: 19-01
    provides: fixtures/vulnerable.py, fixtures/secret.env, and the measured Semgrep/Gitleaks reports the new assertions were tested against
  - phase: 15-five-parallel-scan-jobs
    provides: fixtures/README.md, the four `exclude: ^fixtures/` pre-commit entries, scripts/smoke-scans.sh
provides:
  - fixtures/README.md rows and prose covering both new fixtures, one row per consuming job
  - a local smoke gate that FAILS (not prints) when either new fixture stops firing its named rule
  - the corrected Gitleaks-hook and pre-commit-scoping claims that the new fixtures falsified
affects: [19-03, 19-04, 19-05, 19-06, 19-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Verdict assertion over informational print: a separate `|| rc=$?`-guarded heredoc routed to FAILURES+=, never a modification of the existing `|| true` print"
    - "Stale-claim correction lands in the SAME commit that falsifies the claim"
    - "Guard proof by VERBATIM heredoc extraction from the COMMITTED script, run against real / filtered / invalid reports — no full gate re-run"
    - "Filtered negative-test copies keep the baseline entries, so a passing exit 3 proves the path/file clause is load-bearing rather than a count check"

key-files:
  created: []
  modified:
    - repos/security-platform/fixtures/README.md
    - repos/security-platform/scripts/smoke-scans.sh

key-decisions:
  - "The smoke-gate change was DISCRETIONARY per RESEARCH §Repo-Local Scripts and was taken deliberately: `p/default` resolves rules from the semgrep.dev registry at scan time, so an informational print that swallows its own result is a live false-pass mechanism, not a hypothetical one."
  - "The Gitleaks assertion ANDs `RuleID == aws-access-token` with `'secret.env' in File`. 19-01 measured 8 of 9 baseline findings as already `aws-access-token`, so the rule id alone is a guaranteed false pass. The filtered negative test keeps all 8 and still exits 3, which is the evidence."
  - "The Semgrep assertion ANDs `eval-detected` with `path == fixtures/vulnerable.py`. The filtered negative test keeps the 3 baseline findings AND both secret.env findings and still exits 3, proving it is not a count check."
  - "Table header restructured to '(2026-09-11 unless the row states another date)' AND each new row carries 'Measured 2026-09-12' explicitly — both, not either, so no new row is silently read under the old date."
  - "VAL-01 NOT marked complete, following 19-01's decision and the 17-01 precedent. Its text is 'full pipeline validated using branch-target PRs', which needs the live PR runs in 19-03+, not local documentation and a local gate."
  - "Edit point 4 cites the pre-commit hook pin as gitleaks v8.30.0 and the measurement/CI pin as 8.30.1 separately — the two differ and conflating them would have put a wrong version next to a measured claim."

patterns-established:
  - "Exact-string replacement with an `assert count == 1` per edit point, in preference to sed, when the target contains box-drawing Unicode and multi-line prose"
  - "Post-commit re-extraction and diff against the pre-commit extraction, so 'tested the committed body' is literally true rather than approximately true"

requirements-completed: []

# Metrics
duration: 24min
completed: 2026-09-13
---

# Phase 19 Plan 02: Document and Defend the New Fixtures Summary

**`fixtures/README.md` updated at all five edit points with both stale claims replaced in the same commit that falsified them, and two rule-id-plus-path verdict assertions added to the local smoke gate — each observed exiting 0 against 19-01's real report, 3 against a baseline-preserving filtered copy, and 2 against an invalid one, using heredoc bodies extracted verbatim from the committed script.**

## Performance

- **Duration:** ~24 min
- **Tasks:** 2 of 2
- **Files modified:** 2 (both in the inner repo)
- **Commits:** `22d3328` (inner), `0df88d8` (inner)

## Task 1 — fixtures/README.md, five edit points

Applied by a single `python3` exact-string replacement script with `assert count == 1` per edit point, so a
silently-missed or double-applied edit would have raised rather than passed. All seven replacements asserted.

### Edit point 1 — structure tree

Two leaves added in existing alphabetical order, each with a one-line purpose comment naming its consuming
scan. `requirements.txt` demoted from `└──` to `├──`; `vulnerable.py` now carries the single elbow.

```text
├── requirements.txt      # SCA-scan target: vulnerable requests + jinja2 pins — nothing installs it
├── secret.env            # Secrets-scan target (Gitleaks): synthetic AWS credentials — also read by the SAST scan
└── vulnerable.py         # SAST-scan target (Semgrep CE): eval/exec/subprocess shell=True — never imported or run
```

`grep -c '└──' fixtures/README.md` → **1**, as required.

### Edit point 2 — Fixture Reference table, three new rows AS COMMITTED

One row per consuming job, not per file. Every rule id and count was read from 19-01-SUMMARY's measurement
tables, not recalled.

| File | Consuming Job | Measured Finding Count |
|---|---|---|
| `secret.env` | Secrets scan (Gitleaks) | Measured 2026-09-12 against gitleaks 8.30.1 — 2 findings: `aws-access-token` (named rule, deterministic) and `generic-api-key` (entropy 5.22, NOT version-stable) |
| `secret.env` | SAST scan (Semgrep CE) | Measured 2026-09-12 against semgrep 1.177.0 — 2 findings: `generic.secrets.security.detected-aws-access-key-id-value.detected-aws-access-key-id-value` and `generic.secrets.security.detected-aws-secret-access-key.detected-aws-secret-access-key` |
| `vulnerable.py` | SAST scan (Semgrep CE) | Measured 2026-09-12 against semgrep 1.177.0 — 3 findings, all named: `python.lang.security.audit.eval-detected.eval-detected`, `python.lang.security.audit.exec-detected.exec-detected`, `python.lang.security.audit.subprocess-shell-true.subprocess-shell-true` |

**Date handling — both mechanisms, not either.** The header was restructured to
`Measured Finding Count (2026-09-11 unless the row states another date)` **and** each new row opens with
`Measured 2026-09-12`. The `| File | Consuming Job` header prefix was preserved so the plan's `awk` range
verify still anchors. Table body: 7 existing + 3 new = **10 rows**; `awk` range pipe-line count = **12**
(header + separator + 10), exactly as the plan predicted.

Prose added after the table (outside the `awk` range, so the row count stays clean) records that
`os.system()` and `os.popen()` are deliberately silent under `p/default`, so three findings is the correct
number and must never be "raised to five", and that the two `secret.env` rows are one-per-consuming-job
rather than a duplicate.

### Edit point 3 — tool versions and drift disclaimer

New line: *"Tool versions used for the 2026-09-12 measurement of the three rows that carry that date:
semgrep 1.177.0 and gitleaks 8.30.1 — the versions the `sast` and `secrets` CI jobs pin."* Confirmed against
`.github/workflows/security.yml` L70 (`pip install semgrep==1.177.0`) and L963
(`gitleaks_8.30.1_linux_x64.tar.gz`), not assumed.

The existing drift disclaimer was **extended by one clause, not duplicated**: *"…and for Semgrep the drift
source is not only the CVE feed but the `p/default` RULESET itself, which is resolved from the semgrep.dev
registry at scan time, so a rule can be renamed, retired or added without anything in this repository
changing."*

### Edit point 4 — the stale Gitleaks claim, BEFORE and AFTER

**BEFORE (lines 60-61, now false):**

> The Gitleaks secrets hook is NOT excluded — no fixture ever contains a real secret, so
> it is unaffected and continues to run normally.

**AFTER (as committed):**

> The Gitleaks secrets hook is NOT excluded, and that is deliberate. `fixtures/secret.env`
> does now carry credential-shaped values, so the hook DOES fire on it — but the values are
> SYNTHETIC and have never existed in any AWS account, so "no fixture contains a real secret"
> remains true. The hook is `stages: [pre-push]`, so it fires on `git push`, never on
> `git commit`. Bypass: `git push --no-verify` skips this hook — CI is the compensating
> control. Do NOT add this file's fingerprint to `.gitleaksignore`: CI reads that file too, so
> the suppression would silence the `secrets` job, which is the exact detection this fixture
> exists to produce. Measured 2026-09-12 against the pinned hook (gitleaks v8.30.0) and the CI
> version (gitleaks 8.30.1): `aws-access-token` at `fixtures/secret.env`.

The bypass sentence is byte-for-byte the wording `.pre-commit-config.yaml` L101 already uses. The literal
string `no fixture ever contains a real secret, so` no longer appears anywhere in the file (verified by
`grep -q`, which found nothing).

### Edit point 5 — the half-stale no-hook-fires claim, BEFORE and AFTER

**BEFORE (lines 63-67):** the `requirements.txt` paragraph ending *"Do not 'fix' this by adding a fifth
`exclude: ^fixtures/` entry — there is nothing to exclude."* — still true for `requirements.txt`, and
therefore **kept unchanged**; it was half-stale, not stale.

**AFTER — two paragraphs appended:**

1. **`ruff`/`ruff-format` DO match `fixtures/vulnerable.py` and PASS on it** (measured 2026-09-12 against the
   pinned ruff-pre-commit v0.15.7, Passed not Skipped). The fixture is authored ruff-clean **on purpose** so
   the four-hook exclude list stays at four. Because the `ruff` hook carries `args: [--fix]`, an unclean
   fixture would be **silently rewritten in place** at commit time — the vulnerable construct could be edited
   away with nothing in the diff to explain the SAST fixture going quiet. *"Fix the style, never the
   vulnerability, and never add a fifth exclude entry."*
2. **The permanence note.** The `secrets` job runs `gitleaks git .` with `fetch-depth: 0` — a HISTORY scan —
   so once `secret.env` is in `main`'s history it is in the history of every branch cut from `main` and the
   secrets job reports it forever. Intended by D-04; not to be "cleaned up" by rebase, filter-repo, or a
   `.gitleaksignore` fingerprint.

### Task 1 verification, as observed

| Check | Result |
|---|---|
| `grep -c 'vulnerable\.py'` / `grep -c 'secret\.env'` | 6 / 7 lines |
| `awk '/^\| File \| Consuming Job/,/^$/' \| grep -c '^\|'` | **12** (expected 12) |
| `aws-access-token` / `eval-detected` / `generic-api-key` | 2 / 1 / 1 lines |
| `semgrep 1.177.0` / `gitleaks 8.30.1` | 3 / 3 lines |
| `no-verify` / `gitleaksignore` / `fetch-depth` | 1 / 2 / 1 lines |
| `grep -ci 'history'` | 3 |
| `grep -c '└──'` | **1** |
| stale Gitleaks sentence | **gone** (`grep -q` found nothing) |
| `pre-commit run markdownlint --files fixtures/README.md` | **Passed** (rc=0), run before the commit and again by the hook at commit |
| `git show HEAD:fixtures/README.md \| diff - fixtures/README.md` | no output — byte-identical, no hook rewrite |

Commit `22d3328` — `docs(19-02): document the SAST and Secrets fixtures`, 48 insertions / 5 deletions,
hooks ran normally (no `--no-verify`).

## Task 2 — smoke-gate verdict assertions

Two **separate** blocks added: SAST immediately after the section-1 informational print, Secrets immediately
after the section-9 informational print. Both follow the tflint block's shape exactly — a local rc
initialised to 0, a separate `python3 - "$OUT/<report>" <<'PY' || <rc>=$?` heredoc, `sys.exit(2)` for an
unreadable/unparseable report and `sys.exit(3)` for "expected rule id absent", matched ids printed before
the exit, and a non-zero rc routed into `FAILURES+=`.

- **SAST** (`$OUT/semgrep-results.json`): at least one result whose `path == "fixtures/vulnerable.py"` AND
  whose `check_id` contains `eval-detected`.
- **Secrets** (`$OUT/gitleaks-results.json`, a top-level **LIST**): at least one finding with
  `RuleID == "aws-access-token"` AND `"secret.env" in File`. An explicit `isinstance(data, list)` guard exits
  2 on a tool-error object rather than raising.

Each block carries the required WHY comment. The SAST comment names the three-finding pre-existing baseline
(`.github/dependabot.yml`, `cicd/.github/workflows/security.yml`, `fixtures/Dockerfile`) and the registry-at-
scan-time resolution of `p/default`. The Secrets comment names the entropy-instability of `generic-api-key`
**and** 19-01's finding that 8 of 9 baseline gitleaks findings are already `aws-access-token`, which is why
the `File` clause is load-bearing rather than decorative.

### The existing prints were not touched — proven, not asserted

`git diff --numstat scripts/smoke-scans.sh` → **84 insertions, 0 deletions**. A zero deletion count means
neither `|| true` print could have been modified. Both `|| true` markers survive at what are now lines 248
and 622.

### The six exit codes

Heredoc bodies were **extracted verbatim**, never hand-written. The extractor takes everything strictly
between the `python3 - "<report>" <<'PY'` opener and the next line that is exactly `PY`, asserting exactly
one opener per report path (there are five other `<<'PY'` heredocs in the file, so the anchor is the report
filename). Extraction yielded 22 lines (SAST) and 29 lines (Secrets).

Inputs — the "filtered" copies deliberately **retain the baseline entries**, so an exit 3 proves the
path/file clause is doing the work and the check is not a disguised count:

- `sg-filtered`: only `path == fixtures/vulnerable.py` dropped; **5 entries kept**, including all 3 baseline
  findings and both `fixtures/secret.env` findings.
- `gl-filtered`: only findings with `secret.env` in `File` dropped; **9 entries kept, 8 of them
  `aws-access-token`** — precisely the false pass 19-01 warned about.
- `*-invalid`: `head -c 100` of the real report.

| Block | Report | Expected | **Observed exit** |
|---|---|---|---|
| SAST | 19-01's real `sg-fixtures.json` | 0 | **0** — printed `['python.lang.security.audit.eval-detected.eval-detected']` |
| SAST | filtered (baseline + secret.env kept) | 3 | **3** — "semgrep reported no eval-detected finding at fixtures/vulnerable.py" |
| SAST | invalid JSON | 2 | **2** — "semgrep report unreadable … Unterminated string" |
| Secrets | 19-01's real `gl-fixtures.json` | 0 | **0** — printed `['aws-access-token at fixtures/secret.env']` |
| Secrets | filtered (8 baseline `aws-access-token` kept) | 3 | **3** — "gitleaks reported no aws-access-token finding in a file containing secret.env" |
| Secrets | invalid JSON | 2 | **2** — "gitleaks report unreadable … Unterminated string" |

Run **twice**: once from the working tree before the commit (gating it), then re-extracted from
`git show HEAD:scripts/smoke-scans.sh` after the commit. The post-commit extraction `diff`s byte-identical
to the pre-commit one, and all six codes reproduced. The claim "the tested bodies are the shipped bodies" is
therefore literal.

### Task 2 verification, as observed

| Check | Result |
|---|---|
| `git show origin/main:scripts/smoke-scans.sh \| grep -c 'FAILURES+='` | **15** (baseline, shown not remembered) |
| `grep -c 'FAILURES+=' scripts/smoke-scans.sh` | **17** — exactly 2 higher |
| `git diff --numstat` | 84 insertions, **0 deletions** |
| `bash -n scripts/smoke-scans.sh` | rc=0, syntax OK |
| `pre-commit run shellcheck --files scripts/smoke-scans.sh` | **Passed** (rc=0), before the commit and again by the hook |
| `bash scripts/check-workflow-uploads.sh` | **rc=0** — `PASS - 10 checks, 0 failures` |
| `git diff --name-only origin/main -- scripts/check-workflow-uploads.sh` | empty — file unchanged, run as a pure regression check |
| `git diff origin/main --name-only` | **exactly four paths** |

Commit `0df88d8` — `test(19-02): assert the SAST and Secrets fixture rule ids in the smoke gate`, 84
insertions, hooks ran normally (no `--no-verify`).

## The full gate was deliberately NOT run

Per the plan. It takes minutes and its hard-tier preflight `exit 1`s when `semgrep` is absent from PATH; the
only semgrep on this workstation's PATH self-reports 1.155.0, not the pinned 1.177.0. The extracted-heredoc
technique (17-02 precedent) proves the guards fire without re-running the gate, and 19-01's reports were
produced by the pinned 1.177.0 venv, so the inputs are the right ones.

## Branch state

| Item | Value |
|---|---|
| Branch | `feature/phase-19-pipeline-validation` |
| Commits above `origin/main` (`2e29004`) | **3** — `fbfcbe9` (19-01), `22d3328`, `0df88d8` |
| `git diff origin/main --name-only` | `fixtures/README.md`, `fixtures/secret.env`, `fixtures/vulnerable.py`, `scripts/smoke-scans.sh` |
| Pushed? | **No.** Still local only. Plan 19-03 opens the PR. |
| `.gitleaksignore` / `.pre-commit-config.yaml` / workflow YAML | untouched; still 0 fingerprints and exactly 4 `exclude: ^fixtures/` entries |

## Discretionary-scope record

Stated explicitly so no later reader mistakes it for drift: **the smoke-gate change in Task 2 is
DISCRETIONARY** per RESEARCH §Repo-Local Scripts, which records that no repo-local script *needs* changing
for these fixtures. It was taken as a deliberate planner decision, carried into execution unchanged, for
three reasons: shared pattern S-4 ("scanner assertions target rule ids and paths, never totals"); the project
anti-slop rule against silent fallbacks, of which a `|| true` print that swallows its own result is the
canonical instance; and the measured fact that `p/default` resolves from the registry at scan time, making
rule drift a live risk. It is a local script, not scan-job logic, so it stays inside CONTEXT's "no scan-job
logic changes" boundary. `scripts/check-workflow-uploads.sh` was **not** edited — fixture files are invisible
to its static YAML checks — and was run unchanged as a regression check.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The first heredoc extractor matched nothing and produced six vacuous exit codes**

- **Found during:** Task 2, verification.
- **Issue:** The `awk` extractor anchored on `/<<.PY.$/` — end-of-line after the heredoc token. The real
  opener lines end `<<'PY' || sast_rc=$?`, so the pattern never matched. Both extractions produced **0-line**
  files, and an empty Python file exits 0 — so the first run reported `exit=0` for all six cases, including
  the two that must exit 3 and the two that must exit 2. Read naively that is a full pass.
- **Detection:** The `wc -l` echo printed `sast_body lines=0`, and an all-zeroes result for tests designed to
  produce three distinct codes is not a pass. Stopped rather than proceeding, per the anti-slop rule.
- **Fix:** Replaced `awk` with a `python3` extractor that anchors on the report filename plus `<<'PY'`
  anywhere in the line, asserts exactly one opener, and terminates at a line that is exactly `PY`. Re-ran:
  0 / 3 / 2 for both blocks.
- **Files modified:** none in either repository — this was a verification harness defect, not a deliverable
  defect. `scripts/smoke-scans.sh` was already correct.
- **Commit:** n/a

This is worth recording beyond the bookkeeping: a broken test harness for a false-pass guard was itself
producing a false pass. The guard against that was printing the extracted line count before trusting the
result.

### Intentional divergences

**2. Both date mechanisms applied, not one.** The plan offered "carry the date per new row **or** restructure
the header". Both were done. Per-row dates alone leave a header that still reads `(2026-09-11)` over rows
measured a day later; a restructured header alone leaves the specific date unstated. Together neither gap
exists, and the `| File | Consuming Job` prefix the verify command anchors on was preserved.

**3. `isinstance(data, list)` guard added to the Secrets block.** Not requested. Without it a gitleaks tool-
error object (a dict) would reach `finding.get(...)` on a string key and raise `AttributeError`, exiting 1 —
which still routes to `FAILURES+=`, but reports a traceback instead of a diagnosis. Rule 2: the report is
untrusted tool output crossing a trust boundary into the pass/fail decision. Exits 2, the existing
"unreadable" code.

**4. VAL-01 NOT marked complete.** The plan frontmatter lists `requirements: [VAL-01]`, and the executor
template marks listed requirements complete. Withheld, following 19-01's identical decision and the 17-01
precedent of a premature mark-complete that had to be reverted: VAL-01 reads "full pipeline validated using
branch-target PRs", which needs the live PR runs in 19-03+, not local documentation and a local gate.
`requirements.mark-complete` was deliberately not invoked.

### Authentication gates

None. No network authentication was required — no push, no `gh` call, no package install.

## Issues Encountered

None unresolved. The one surprise (Deviation 1) was caught, diagnosed and fixed before anything was read into
its output.

Execution ran 2026-09-13; every `Measured 2026-09-12` claim in this summary and in the two committed
files is 19-01's measurement date, correctly attributed, not this plan's execution date.

Two results that could be misread as failures, and were not:

- `grep -n '|| true'` reports **8** lines, not 6. Two of those are prose: the `require_parses_json` doc at
  L123 and the new SAST comment at L250, both of which mention `|| true` while explaining why an assertion
  must not use it. The six real `" || true` terminators are unchanged, and the 0-deletion diff proves it.
- The pre-commit hook pins gitleaks **v8.30.0** while CI and the measurement use **8.30.1**. This is a real
  version gap, not a typo; it is documented as two separate facts in edit point 4 rather than conflated.
  Whether to close the gap is out of scope here — noted for a future plan.

## Handoff Notes for Plan 19-03 and Later

1. **Nothing is pushed.** `feature/phase-19-pipeline-validation` is local only at `0df88d8`, three commits
   above `origin/main` (`2e29004`), touching exactly four paths. 19-03 opens the PR.
2. **The smoke gate now has teeth on both new fixtures.** If a future plan sees
   `semgrep: no eval-detected finding at fixtures/vulnerable.py` or
   `gitleaks: no aws-access-token finding at fixtures/secret.env` in `FAILURES`, that is registry or fixture
   drift — investigate the fixture and the ruleset, do not relax the assertion.
3. **Every Secrets assertion must still AND the rule id with the file.** Re-confirmed empirically here: the
   filtered report retaining all 8 baseline `aws-access-token` findings exits 3.
4. **VAL-01 remains Pending** — see Deviation 4.
5. **`fixtures/README.md` is now the authority on why nothing may be excluded, suppressed or cleaned up.**
   Three prohibitions with their reasons are recorded there: no fifth `exclude: ^fixtures/`, no
   `.gitleaksignore` fingerprint, no history cleanup of `secret.env`.
6. **The extracted-heredoc harness lives in this session's scratchpad** (`extract.py`, `t2/`). It is
   reproducible from the script itself; nothing about it needs preserving beyond this record.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern or schema was introduced. The four
threat-register items requiring mitigation were discharged as written:

- **T-19-06** (stale claim invites a future suppression) — both stale claims replaced in the same commit that
  falsified them, each replacement stating the prohibition *with its reason*, not only the fact.
- **T-19-07** (a gate that prints but asserts nothing) — two verdict blocks on rule id AND path, each observed
  firing against a filtered and an invalid report before the commit.
- **T-19-08** (an unguarded assertion aborts the whole gate under `set -euo pipefail`) — both use `|| rc=$?`
  and route to `FAILURES+=`; `bash -n`, shellcheck and the six extracted-body runs all confirm it.
- **T-19-09** (a secret value in gate stdout) — both assertions match and print `RuleID`/`File` and
  `check_id`/`path` only. No secret value is read, matched or printed. `--redact` on every gitleaks
  invocation is unchanged and still enforced by `check-workflow-uploads.sh` (rc=0).
- **T-19-SC** — zero package installs; no dependency manifest touched.

## Self-Check: PASSED

Both modified files verified present on disk with the expected content; both inner-repo commits (`22d3328`,
`0df88d8`) verified present in `git log origin/main..HEAD`, and `git diff origin/main --name-only` returns
exactly the four expected paths.
