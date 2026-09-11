---
phase: 16-sca-ecosystem-coverage
plan: 04
subsystem: ci-cd
tags: [github-actions, npm-audit, pip-audit, tflint, sarif, checksum-verify, detect-then-guard, continue-on-error]
requires:
  - "16-02 detectors (29dbc62) — scripts/detect-{npm,python,terraform}.sh are invoked verbatim by the three CI detect steps"
  - "16-03 proven invocations (34d53ff) — the npm/pip-audit/tflint command lines and the report-content discriminators are copied from the green smoke gate"
  - "15-05 (e8e1009) — the five verbatim check-run names this plan must not disturb"
provides:
  - "sca job running four scanners: Trivy fs (SCA-04), npm audit (SCA-01), pip-audit (SCA-02), tflint (SCA-03) — still one job, still five jobs total, still zero needs:"
  - "Report filenames CI will produce: trivy-fs.json, trivy-fs.sarif, npm-audit-<n>.json, pip-audit-<n>.json, tflint.sarif"
  - "Three intolerant report-content verification steps whose stdout labels 16-05 can grep for evidence"
affects:
  - "16-05 (push + live run; the labels and filenames recorded here are what it extracts evidence from)"
  - "17 (artifact upload cannot assume fixed npm/pip filenames — they are numbered per input)"
  - "18 (branch protection: the sca check-run name is unchanged and still inaccurate by design)"
tech-stack:
  added:
    - "pip-audit==2.10.1 (pip install on the runner)"
    - "tflint v0.64.0 (checksum-verified zip, unzip into /usr/local/bin)"
  patterns:
    - "detect step (id) -> guarded scan (continue-on-error, D-04) -> intolerant report check -> guarded ls evidence, one group per ecosystem"
    - "Numbered per-input reports (npm-audit-<n>.json / pip-audit-<n>.json) because npm audit takes a directory and a consumer repo may hold several manifests"
    - "Every evidence ls is guarded by its detector, so an absent ecosystem cannot turn the job red on a clean skip"
key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml
key-decisions:
  - "One commit, not three: Task 3's acceptance pins `git log -1` to a specific subject and requires a clean tree, and no other task names a commit"
  - "The npm and pip loops read their list file on fd 3 (not stdin) — carried forward from 16-03, where a scanner consuming the loop's stdin would swallow the remaining paths"
  - "npm verification fails on EITHER a top-level `error` key OR a missing `auditReportVersion` — the acceptance criterion names the first, the threat register names the second"
  - "Comments phrased to avoid the literal flag names the plan's own negative greps forbid (`--no-deps`, `--disable-pip`, `--require-hashes`, `--force`, the runtime setup actions)"
  - "The three verification bodies were extracted and EXECUTED locally against real fixture reports and against four corrupted ones, rather than relying on the plan's `'python3' in run` static check"
patterns-established:
  - "Pattern: explanations live in YAML comments above the step; `run:` bodies stay commands-only, because the plan's parse-based verifies count substrings inside run: blocks"
  - "Pattern: splice a rewritten job block in by line range, then confirm every `git diff -U0` hunk header falls inside that job"
requirements-completed: [SCA-01, SCA-02, SCA-03]
duration: ~25min
completed: 2026-09-11
---

# Phase 16 Plan 04: Wire the Three SCA Sub-Scans into CI Summary

**The `sca` job now installs pip-audit 2.10.1 and checksum-verified tflint v0.64.0, resolves npm/Python/Terraform through the same detector scripts the smoke gate tests, runs three guarded sub-scans tolerated under D-04, and follows each with a deliberately intolerant report-content check — while the workflow still parses as exactly five jobs with the five frozen check-run names, zero `needs:`, and `permissions: contents: read`.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-11T14:07Z
- **Completed:** 2026-09-11T14:31Z (commit `f4388f8` at 14:31:19Z)
- **Tasks:** 3 of 3
- **Files modified:** 1 (`repos/security-platform/.github/workflows/security.yml`, 188 → 420 lines)

## Task Commits

One commit, in `repos/security-platform` on `feature/phase-16-sca-ecosystem-coverage`:

| Commit | Subject |
|---|---|
| `f4388f8` | `feat(16-04): add npm, Python and Terraform sub-scans to the SCA job` |

Nothing was pushed from either repository, and no PR was opened — 16-05 owns both.

## What the `sca` job looks like now

Twenty steps, one job. `name:` is byte-identical to Phase 15's value.

| # | Step | `if:` | `continue-on-error` |
|---|---|---|---|
| 1-2 | checkout, setup-trivy | — | — |
| 3 | `pip install pip-audit==2.10.1` (+ A7 pipx / break-system-packages fallback comment) | — | — |
| 4 | `Install tflint` (curl -o → `sha256sum -c -` → `sudo unzip -o -d /usr/local/bin`) | — | — |
| 5-7 | `Detect npm lockfiles` / `… Python requirements files` / `… Terraform files`, ids `npm` / `py` / `tf` | — | — (deliberately) |
| 8-10 | Trivy fs scan, convert to SARIF, unconditional `ls -l trivy-fs.json trivy-fs.sarif` (**unchanged**) | `always()` on 9-10 | `true # D-04` on 8 |
| 11 | `SCA-01 — npm audit` | `steps.npm.outputs.found == 'true'` | `true # D-04` |
| 12 | `Verify npm audit reports` | `always() && steps.npm…` | **none, by design** |
| 13 | `Show npm audit output files` (`ls -l npm-audit-*.json`) | `always() && steps.npm…` | — |
| 14-16 | same three-step shape for `SCA-02 — pip-audit` | `steps.py…` | `true # D-04` on 14 only |
| 17 | `SCA-03 — tflint (SARIF)` — `tflint --recursive --format sarif > tflint.sarif` | `steps.tf.outputs.found == 'true'` | `true # D-04` |
| 18 | `SCA-03 — tflint (human-readable log)` — `--format default` | `always() && steps.tf…` | `true # D-04` |
| 19-20 | `Verify tflint SARIF`, `Show tflint output files` | `always() && steps.tf…` | none / — |

**Verbatim `sca` check-run name after this plan (unchanged, and deliberately inaccurate):**

```
SCA — Trivy Filesystem
```

(em-dash U+2014; a comment immediately above the `name:` records that Phase 18's required-check list hard-codes it, so renaming it would leave branch protection pointing at a check that no longer exists — silently non-blocking.)

**Report filenames this job produces** — Phase 17's artifact step must glob, not name:

| Sub-scan | Files |
|---|---|
| SCA-04 Trivy fs | `trivy-fs.json`, `trivy-fs.sarif` (fixed) |
| SCA-01 npm audit | `npm-audit-<n>.json`, one per lockfile directory (**numbered, not fixed**) |
| SCA-02 pip-audit | `pip-audit-<n>.json`, one per requirements file (**numbered, not fixed**) |
| SCA-03 tflint | `tflint.sarif` (fixed; written by shell redirection — tflint has no `-o`) |

`cicd/.github/workflows/security.yml` — the **stale** reference template that still runs Grype and installs via `curl | sh` — **was deliberately not modified**. `git log origin/main..HEAD --name-only -- cicd/` is empty. Phase 17 needs all three of those facts.

## Verification (observed results, not predictions)

### Plan verifies

| Check | Result |
|---|---|
| Task 1 v1 (`yaml.safe_load`: 5 jobs, frozen `sca` name, zero `needs:`, ids `npm`/`py`/`tf`, exactly 3 `bash scripts/detect-` run blocks) | PASS |
| Task 1 v2 (greps: pip-audit pin, tflint SHA-256, `unzip -o -d`; negatives: no `tar xzf tflint`, no runtime/tflint setup actions) | rc=0 |
| Task 1 v3 (`yamllint -d relaxed`) | rc=0 (22 pre-existing line-length **warnings** only) |
| Task 2 v1 (3 guarded scans all tolerated; exactly 3 `python3` verification steps, **none** tolerated; exactly 1 `--format default` step and it *is* tolerated; exactly 3 guarded `ls` evidence steps) | PASS |
| Task 2 v2 (greps: npm/pip-audit/tflint invocations present; `disable-pip`, `require-hashes`, `tflint --force` absent) | rc=0 |
| Task 2 v3 (`# D-04` count ≥ 11) | **11** (7 pre-existing + 4 new), rc=0 |
| Task 3 v1 (5 job ids, 5 byte-exact names, zero `needs:`, `workflow_call`, `permissions == {contents: read}`) | PASS |
| Task 3 v2 (`yamllint -d relaxed` + `pre-commit run --all-files`) | both rc=0 — shellcheck / yamllint / markdownlint Passed, rest Skipped |
| Task 3 v3 (`git log -1` contains `16-04`, clean tree, no `cicd/` file in the branch diff) | rc=0 |

### Extra verification the plan did not require

The three Python verification bodies are the only genuinely new logic in this plan; the plan's static
checks only assert that the string `python3` appears in them. A syntax or logic error would have
surfaced for the first time in 16-05's live run. So each body was extracted from the committed YAML
with `yaml.safe_load` and executed with `bash -eo pipefail` in the scratchpad.

**Against real reports regenerated from `fixtures/` (npm rc=1, pip-audit rc=1, tflint rc=2):**

| Body | rc | stdout |
|---|---|---|
| `Verify npm audit reports` | 0 | `npm audit severity histogram [npm-audit-1.json]: info=0 low=0 moderate=0 high=1 critical=1 total=2`, then `package=lodash severity=high`, `package=minimist severity=critical` |
| `Verify pip-audit reports` | 0 | `requests` 10 / `jinja2` 10 / `idna` 4 / `urllib3` 22 advisories; `pip-audit resolved dependencies: 7`; `pip-audit advisory entries: 46 (23 unique ids)` |
| `Verify tflint SARIF` | 0 | `tflint rule ids: ['terraform_module_version', 'terraform_required_providers', 'terraform_required_version']` |

Every figure matches 16-03's measured baseline exactly, including the carried-forward correction that
this fixture emits **three** rule ids — `terraform_module_pinned_source` does **not** fire here.

**Against corrupted reports (T-16-15 / T-16-16, the whole point of the intolerant steps):**

| Negative case | rc | message |
|---|---|---|
| `npm-audit-1.json` = `{"error":{"code":"ENOLOCK",…}}` | **1** | `npm audit report is an error object, not a report: …` |
| `pip-audit-1.json` with no `dependencies` key | **1** | `pip-audit report has no dependencies key: …` |
| `pip-audit-*.json` matching nothing (report never written) | **1** | `FileNotFoundError: … 'pip-audit-*.json'` |
| `tflint.sarif` = `{"version":"2.1.0"}` | **1** | `tflint SARIF has no runs key: …` |

Since these steps carry no `continue-on-error`, each rc=1 is a red step — an error-shaped report can no
longer be read as a clean scan.

**Diff containment:** all four `git diff -U0` hunk headers (`@@ -77,2`, `@@ -80,0`, `@@ -89,0`, `@@ -107,0`)
fall inside the old `sca` job span (lines 76-107). The other four jobs and `cicd/` are byte-identical.

## Deviations from Plan

### 1. [Process] One commit, not one per task

The plan assigns a commit only to Task 3, and Task 3's acceptance pins `git log -1`'s subject to
`feat(16-04): add npm, Python and Terraform sub-scans to the SCA job` **and** requires a clean tree.
Committing Tasks 1 and 2 separately would leave Task 3 with nothing to commit and a different `git log -1`
subject, failing its own acceptance. All three tasks touch the same file, and Tasks 1 and 2 were each
verified green before the next was started; the commit was made only after Task 3's gates passed. This
mirrors 15-03's single-commit-by-plan-design note.

### 2. [Rule 1 — bug avoided] Comments reworded to dodge the plan's own negative greps

The plan's action text asks for comments that explain the absent flags (`--no-deps`, `--disable-pip`,
`--require-hashes`, `--force`) and the absent runtime setup actions — but Task 1 verify #2 and Task 2
verify #2 `grep` the whole file for those exact strings and fail if present. Comments were therefore
phrased around the flags ("the flags that skip transitive resolution or demand hash-pinned inputs are
absent on purpose", "No soft-fail flag is used", "No language-runtime setup action is needed here")
following the same avoidance smoke-scans.sh already uses. Same class of mismatch as 15-03's
`config auto` / `gitleaks dir` rewording. No behaviour change.

### 3. [Rule 2 — missing critical, carried forward from 16-03] `fd 3` instead of stdin in both loops

16-RESEARCH's example loops read the list file on stdin (`done < npm-lockfiles.txt`). `npm audit` reads
stdin, so it can consume the remaining lockfile paths and silently scan fewer manifests than were
detected — a false pass invisible in the log. 16-03 already hit this and solved it with fd 3 in
`scripts/smoke-scans.sh`; both CI loops now use `done 3< …` with `while IFS= read -r … <&3`, and a comment
records why. Applied to the pip-audit loop too, for symmetry.

### 4. [Rule 2 — missing critical] npm verification fails on two conditions, not one

The acceptance criterion says "fails if the report's top-level key is `error`"; threat T-16-15 says assert
`auditReportVersion`. A truncated or half-written report satisfies neither shape yet has no `error` key,
so the check is `if "error" in data or "auditReportVersion" not in data`. Both were exercised (ENOLOCK
object → rc=1 above).

---

**Total deviations:** 4 (1 process, 1 bug avoided, 2 missing-critical). No scope creep — one file touched,
no new job, no new `uses:`, no permission widened.

## Threat Model Compliance

| Threat ID | Disposition | Evidence |
|---|---|---|
| T-16-14 | mitigated | `curl -sSfL -o tflint.zip` → `echo "cca9d13e…4537  tflint.zip" \| sha256sum -c -` → `sudo unzip -o -d /usr/local/bin tflint.zip`. No `curl \| sh` and no `tar xzf tflint` in the file (both greps rc=0) |
| T-16-15 | mitigated | Three verification steps, each parsed out of the committed YAML and executed: rc=0 on real reports, **rc=1 on all four corrupted/absent inputs**. `yaml.safe_load` confirms none of the three carries `continue-on-error` |
| T-16-16 | mitigated | Three new `ls` evidence steps, each `always() && steps.<id>.outputs.found == 'true'`; the unconditional Trivy `ls -l trivy-fs.json trivy-fs.sarif` is byte-unchanged and still unconditional because both Trivy files are produced unconditionally |
| T-16-17 | mitigated | No `${{ }}` interpolation added to any `run:` block. The only one in the file (`${{ github.sha }}`, container job) is untouched — confirmed by the diff-hunk containment check |
| T-16-18 | mitigated | Task 3 asserts `d['permissions'] == {'contents': 'read'}` through the parse. No sub-scan needs more |
| T-16-19 | mitigated | `npm audit` reads the lockfile and queries the advisory endpoint; no `npm ci` / `npm install` / `terraform init` was added anywhere in the job |
| T-16-SC | mitigated | Exactly one package install: `pip install pip-audit==2.10.1`, version-pinned, recorded Approved (PyPA-maintained) in RESEARCH's legitimacy audit. tflint arrives as a checksum-verified release asset. No `[ASSUMED]`/`[SUS]` package, so no legitimacy checkpoint was required |

## Carried Forward

- **16-05 must push and run.** Nothing was pushed. `feature/phase-16-sca-ecosystem-coverage` is
  **6 commits ahead** of `origin/main` (`68c3bbb`, `29dbc62`, `bfb57e0`, `6ae3019`, `34d53ff`, `f4388f8`),
  measured with `git log origin/main..HEAD --oneline`.
- **Grep these labels in the live log** (they are identical in the smoke gate, so local and CI lines up):
  `npm audit severity histogram [<file>]:`, `pip-audit advisory entries [<file>]: N (M unique ids)`,
  `tflint rule ids: [...]`, plus the per-iteration `npm audit [<dir>] exit=<rc>` /
  `pip-audit [<file>] exit=<rc>` lines.
- **Expect CI rule-id drift.** Local tflint is 0.61.0, CI installs v0.64.0. Compare against the three
  ids listed above; a `terraform_module_pinned_source` appearance is new information, not confirmation.
- **tflint exits 2 on findings.** Both tflint steps are `continue-on-error`, so a green scan with findings
  shows as two orange steps and a green job. A *red* tflint step means rc=1 — an application error.
- **Phase 17 cannot hard-code npm/pip report names** — they are numbered per input.
- **The `sca` check-run name is still `SCA — Trivy Filesystem`.** Phase 18 must use that exact string.
- **`cicd/.github/workflows/security.yml` remains stale** (Grype, `curl | sh`, artifact uploads). Untouched
  on purpose; if Phase 17 or a later phase publishes it, it needs its own reconciliation plan.

## Self-Check: PASSED

- `repos/security-platform/.github/workflows/security.yml` — FOUND (420 lines, modified, committed)
- Commit `f4388f8` — FOUND on `feature/phase-16-sca-ecosystem-coverage`
- `git -C repos/security-platform status --porcelain` — empty
- `git diff --diff-filter=D --name-only HEAD~1 HEAD` — empty (no deletions)
- No file under `cicd/` in `git log origin/main..HEAD --name-only`
- `.planning/phases/16-sca-ecosystem-coverage/16-04-SUMMARY.md` — FOUND (this file)
