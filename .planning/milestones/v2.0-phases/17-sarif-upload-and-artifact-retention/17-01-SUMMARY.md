---
phase: 17-sarif-upload-and-artifact-retention
plan: 01
subsystem: infra
tags: [github-actions, sarif, code-scanning, permissions, pyyaml, shellcheck, yamllint, workflow_call]

# Dependency graph
requires:
  - phase: 14-callable-workflow-and-caller
    provides: ".github/workflows/security.yml (workflow_call) and pr-security.yml (pull_request caller); the frozen check-run string `security / <job name>`"
  - phase: 15-five-parallel-scan-jobs
    provides: "the five parallel scan jobs and their five frozen check-run names"
  - phase: 16-sca-ecosystem-coverage
    provides: "the four-tool sca job, scripts/detect-*.sh, the extended smoke gate"
provides:
  - "scripts/check-workflow-uploads.sh — a single offline command deciding PASS/FAIL for ten static SARIF-upload and artifact-retention invariants, with exit 2 reserved for a missing pyyaml"
  - "security-events: write granted at the caller's `security` job (pr-security.yml) and re-declared at the callee's workflow level (security.yml)"
  - "actions: read in both permission blocks for Phase 20 consumer-template portability"
  - "A permanent UPLOAD-VERIFY-PAIRING guard on ADR-001's continue-on-error blind spot, vacuous until 17-03/17-04 add upload steps"
affects: [17-02, 17-03, 17-04, 17-05, 17-06, 17-07, 18-gate-mode-and-branch-protection, 20-distribution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Offline static gate: a .sh wrapper around a QUOTED python3 heredoc that yaml.safe_loads both workflow files and reports every failure, not the first"
    - "Three-valued exit contract: 0 pass / 1 workflow defect / 2 workstation dependency missing — never conflated, never a silent regex fallback"
    - "RED-then-GREEN discipline on a static gate: the gate is authored and observed FAILING before the change that satisfies it"

key-files:
  created:
    - repos/security-platform/scripts/check-workflow-uploads.sh
  modified:
    - repos/security-platform/.github/workflows/pr-security.yml
    - repos/security-platform/.github/workflows/security.yml

key-decisions:
  - "The gate reports every failure rather than stopping at the first, and each line is prefixed `FAIL: <CHECK-LABEL>:` so a caller can grep for one specific invariant"
  - "Exit 2 (not 1) when pyyaml is unimportable — an infrastructure problem is not a workflow defect; no regex fallback exists by design"
  - "The gitleaks --redact check matches an anchored invocation line (^[ \\t]*gitleaks[ \\t]), NOT the substring 'gitleaks' — the Install Gitleaks step mentions the binary three times and redacts nothing, so a substring test would produce a permanent false failure"
  - "ARTIFACT-PATH-SAFETY tests `'**' not in line` separately from the regex: the plan's character class [A-Za-z0-9_.*-] admits `*`, so `**.json` would have matched the regex and defeated the stated no-`**` invariant"
  - "ARTIFACT-PATH-SAFETY also fails an upload-artifact step with NO with.path at all — otherwise the check is trivially vacuous on the one shape that most needs it (small addition beyond the plan's wording)"
  - "SHA-PIN walks JOB-level `uses:` as well as step-level: today the caller's `./.github/workflows/security.yml` carries no @ and is skipped, but a future org/repo reusable-workflow reference must be pinned"
  - "Type checks are strict: `continue-on-error is True` (YAML bool, not the string 'true') and `type(retention) is not int` (bool subclasses int, so retention-days: true must not read as 1)"
  - "OD-1 honoured: the grant is JOB-scoped in pr-security.yml and the workflow-level block stays exactly {contents: read}; the job block restates contents: read because a job-level block REPLACES the workflow-level set"
  - "Two new comment lines in security.yml were reflowed to <=80 chars so the change adds zero new yamllint warnings to the 33 pre-existing ones"

patterns-established:
  - "Negative-testing a static gate: every check label was observed firing against mutated COPIES of the workflows in a scratch tree, never by mutating the repo"
  - "Inducing a missing-dependency path without altering the workstation: a scratch dir containing `yaml.py` that raises ImportError, injected via PYTHONPATH"

# NOTE: this field mirrors the PLAN.md frontmatter, as the template requires. It is NOT an
# assertion of delivery. 17-01 ships the static gate and the permission grant only; the SARIF
# upload steps and the artifact upload steps that actually satisfy CICD-02 and CICD-03 land in
# 17-03 and 17-04. REQUIREMENTS.md correctly still shows both as Pending — see Issues Encountered.
requirements-completed: [CICD-02, CICD-03]

# Metrics
duration: 20min
completed: 2026-09-11
---

# Phase 17 Plan 01: Static Upload Gate and the security-events Grant

**An offline ten-check gate over both workflow files, authored and observed failing first, then satisfied by a job-scoped `security-events: write` grant in the caller and its re-declaration in the callee.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-09-11T17:40Z
- **Completed:** 2026-09-11T17:59Z
- **Tasks:** 2
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments

- `scripts/check-workflow-uploads.sh` encodes all ten static invariants this phase rests on: PERMISSIONS-CALLER, PERMISSIONS-CALLEE, PERMISSIONS-FORBIDDEN, SHA-PIN, SARIF-CATEGORY, ARTIFACT-RETENTION, ARTIFACT-PATH-SAFETY, UPLOAD-VERIFY-PAIRING, REDACT-RETAINED, JOB-SHAPE.
- The gate was observed **failing before it was satisfied** — the RED baseline is the evidence, not the final green state alone.
- `security-events: write` now exists on **both** sides of the `workflow_call` boundary, closing RESEARCH Pitfall 1 + Pitfall 2 before any upload step is written.
- Every check label was additionally proven to fire, against mutated copies in a scratch tree — the gate is not merely green, it has been seen catching each of its targets.

## Task Commits

1. **Task 1: Cut the phase branch and author the offline static upload gate** — `34cd158` (test)
2. **Task 2: Grant security-events at the calling job and re-declare it at the callee** — `66a18ad` (feat)

Branch: `feature/phase-17-sarif-upload-and-artifact-retention`, cut from clean `main` at `40682ce` in the nested product repo `repos/security-platform` (remote `OttawaCloudConsulting/security-platform`).

## Files Created/Modified

- `repos/security-platform/scripts/check-workflow-uploads.sh` (new, 326 lines, mode 100644 — never executable) — the offline gate.
- `repos/security-platform/.github/workflows/pr-security.yml` — job-level `permissions` block on `security`; workflow-level block untouched; the `name: security` freeze recorded in a comment.
- `repos/security-platform/.github/workflows/security.yml` — workflow-level `permissions` block extended to the explicit full set.

## Required Output: Observed Evidence

### Gate exit code before and after Task 2 — both observed, neither assumed

**Before** (`bash scripts/check-workflow-uploads.sh` on the tree at `34cd158`) — **exit 1**:

```
check-workflow-uploads: parsing .github/workflows/pr-security.yml and .github/workflows/security.yml
FAIL: PERMISSIONS-CALLER: jobs.security.permissions is not a mapping (got None)
FAIL: PERMISSIONS-CALLEE: security-events: write missing from the top-level permissions block
FAILED - 2 check(s)
```

Exactly two failures: the other eight checks passed on the pre-existing workflows, which also confirms
no false positive from SHA-PIN (four SHA-pinned actions) or REDACT-RETAINED (the Install Gitleaks step,
which mentions the binary three times without redacting anything).

**After** (same command on the tree at `66a18ad`) — **exit 0**:

```
check-workflow-uploads: parsing .github/workflows/pr-security.yml and .github/workflows/security.yml
PASS - 10 checks, 0 failures
```

### Permission mappings, as parsed by `yaml.safe_load` from each file

| File | Level | Parsed mapping |
|------|-------|----------------|
| `.github/workflows/pr-security.yml` | workflow | `{'contents': 'read'}` |
| `.github/workflows/pr-security.yml` | `jobs.security` | `{'contents': 'read', 'security-events': 'write', 'actions': 'read'}` |
| `.github/workflows/security.yml` | workflow | `{'contents': 'read', 'security-events': 'write', 'actions': 'read'}` |

No level of either file sets `contents: write`, `pull-requests: write`, `actions: write`, `id-token: write`,
`write-all` or `read-all`. `jobs.security.name` is still exactly `security`. `security.yml` still parses to
exactly 5 jobs with zero `needs:` keys and the five frozen check-run names byte-identical.

### The pyyaml-missing exit-2 path — INDUCED, not merely read

A scratch directory containing `yaml.py` whose only statement is `raise ImportError("simulated missing
pyyaml")` was injected via `PYTHONPATH`, shadowing the real pyyaml through the pyenv `python3` shim. No
workstation package was altered. Observed:

```
PREFLIGHT FAIL: python3 yaml module (pyyaml) not available — install with: python3 -m pip install pyyaml
EXIT=2
```

### Every check label observed firing

Against mutated **copies** of both workflow files in a scratch tree (the repo was never mutated):

| Check | How it was induced | Fired |
|-------|--------------------|-------|
| PERMISSIONS-CALLER | current tree, pre-Task-2 | yes |
| PERMISSIONS-CALLEE | current tree, pre-Task-2 | yes |
| PERMISSIONS-FORBIDDEN | `permissions: write-all` at workflow level | yes |
| SHA-PIN | `actions/upload-artifact@v7` (mutable tag) | yes |
| SARIF-CATEGORY | upload-sarif step with no `category`, no `id`, no `continue-on-error` (3 lines) | yes |
| ARTIFACT-RETENTION | upload-artifact step with no `name`, no `continue-on-error`, no `retention-days` (3 lines) | yes |
| ARTIFACT-PATH-SAFETY | `path:` lines `**/*.json` and `../secrets.txt` (2 lines) | yes |
| UPLOAD-VERIFY-PAIRING | `id: art` upload with no later step reading `steps.art.outcome` | yes |
| REDACT-RETAINED | a `gitleaks git .` run with `--redact` removed | yes |
| JOB-SHAPE | `needs: [sast]` on `iac` plus an em dash replaced with a hyphen in its `name` (2 lines) | yes |

### Other verification

- `shellcheck scripts/check-workflow-uploads.sh` — exit 0; also run by the repo's pre-commit hook on the Task 1 commit (Passed).
- `grep -c "python3 - <<'PY'"` — 1 (quoted delimiter present).
- `test ! -x scripts/check-workflow-uploads.sh` — succeeds; git mode is `100644`.
- `yamllint -d relaxed` on both workflow files — exit 0, and the change adds **zero** new warnings (the two new comment lines were reflowed to <=80 chars after an initial run showed them at 83).
- `git diff --name-only HEAD~1 HEAD` on the Task 2 commit — exactly the two workflow files.

## Decisions Made

See `key-decisions` in the frontmatter. The two that a later reader is most likely to "simplify" wrongly:

1. **REDACT-RETAINED matches an anchored invocation line, not the substring `gitleaks`.** The `Install
   Gitleaks` step's run block contains `gitleaks.tar.gz`, the release URL and `sudo tar … gitleaks`, none of
   which redact anything. A substring test fails that step permanently. The rationale is written into the
   script as a comment.
2. **The gate deliberately asserts NO counts of upload steps.** It must pass at every intermediate commit of
   Phase 17; the exact counts belong to 17-03 and 17-04. A comment in the script says so, to stop a later
   reader "completing" it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing Critical] ARTIFACT-PATH-SAFETY strengthened against `**`**
- **Found during:** Task 1 (authoring check 7)
- **Issue:** The plan's regex `^[A-Za-z0-9_.*-]+\.(json|sarif)$` includes `*` in its character class, so
  `**.json` matches it. The plan's own stated intent for the check is "no `**`" (T-17-05), so the regex
  alone was weaker than the documented invariant.
- **Fix:** An explicit `"**" in line` test runs alongside the regex, with a comment explaining why the regex
  cannot carry the invariant by itself.
- **Files modified:** `repos/security-platform/scripts/check-workflow-uploads.sh`
- **Verification:** A scratch-tree upload step with `path: **/*.json` produces a FAIL line.
- **Committed in:** `34cd158` (Task 1 commit)

**2. [Rule 2 — Missing Critical] ARTIFACT-PATH-SAFETY fails an upload-artifact step with no `path` at all**
- **Found during:** Task 1 (authoring check 7)
- **Issue:** The plan's wording gates "every non-empty line of every `with.path`". An upload-artifact step
  with no `path` key has zero lines, so the loop body never runs and the step passes silently — the one
  shape most in need of the check.
- **Fix:** An empty path list is itself a FAIL under the ARTIFACT-PATH-SAFETY label.
- **Files modified:** `repos/security-platform/scripts/check-workflow-uploads.sh`
- **Verification:** A scratch-tree upload step without `path` produces a FAIL line (observed as part of the
  ARTIFACT-RETENTION/PATH-SAFETY negative test).
- **Committed in:** `34cd158` (Task 1 commit)

**3. [Rule 1 — Trivial] SHA-PIN extended to job-level `uses:`**
- **Found during:** Task 1 (authoring check 4)
- **Issue:** The plan says "every `uses:` value in either file". A literal step-only walk would miss
  `jobs.<id>.uses`, which is how a reusable workflow is referenced — precisely the shape Phase 20 will add.
- **Fix:** Job-level `uses:` is walked too. Today the caller's `./.github/workflows/security.yml` carries no
  `@` and is skipped, so behaviour on the current tree is unchanged.
- **Files modified:** `repos/security-platform/scripts/check-workflow-uploads.sh`
- **Verification:** Gate still reports exactly 2 failures on the pre-Task-2 tree — no false positive.
- **Committed in:** `34cd158` (Task 1 commit)

**4. [Rule 1 — Trivial] Two new comment lines reflowed to <=80 characters**
- **Found during:** Task 2 (yamllint verification)
- **Issue:** The first draft of the `security.yml` comment block produced two new `line too long` warnings
  (83 > 80) on top of the file's 33 pre-existing ones.
- **Fix:** Reflowed the three-line comment. `yamllint -d relaxed` still exits 0 either way (line-length is a
  warning there), but the change now adds no new noise.
- **Files modified:** `repos/security-platform/.github/workflows/security.yml`
- **Verification:** No warning reported on lines 14-26; gate re-run still `PASS - 10 checks, 0 failures`.
- **Committed in:** `66a18ad` (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (2 missing critical, 2 trivial)
**Impact on plan:** All four strengthen invariants the plan already states as its intent, or reduce lint
noise. No scope creep; no upload step, no artifact step and no trigger change was added — those remain
17-03 and 17-04.

## Issues Encountered

Both tasks ran as planned; the gate's RED-to-GREEN transition matched the prediction exactly. Two issues
arose in the surrounding bookkeeping, both resolved:

**1. `requirements.mark-complete` marked CICD-02 and CICD-03 Complete — reverted.**
The GSD finalisation step marks every requirement ID in the plan's frontmatter complete. Run verbatim, it
flipped `CICD-02` (SARIF upload to the Security tab) and `CICD-03` (JSON artifact retention) to `[x]` and
their traceability rows to `Complete`. Neither is delivered: 17-01 adds the static gate and the permission
grant, and there is still not a single `upload-sarif` or `upload-artifact` step in either workflow file.
Marking them would have been exactly the broken-but-green bookkeeping this phase exists to prevent.
`.planning/REQUIREMENTS.md` was restored with `git checkout` (diff confirmed empty) and both requirements
remain `Pending`. **17-03 and 17-04 must mark them**, once the upload steps they name actually exist.

**2. Task 2's comment placement differs from the acceptance criterion's literal wording.**
The criterion asks for a *trailing* comment on the `security-events: write` line in each file. The rationale
is multi-sentence in both files — the caller's names it as the grant that a called workflow cannot elevate,
the callee's states its block is an explicit full set — and a trailing comment carrying that would run well
past 80 characters and add yamllint `line-length` warnings. The comments were therefore placed on the lines
immediately **above** each key. The required content is present verbatim in both files; only the position
differs, so a verifier grepping for `security-events: write  #` will not match. Recorded here rather than
amended: rewriting `66a18ad` is a git history modification, and adding a third commit to the phase branch
would break this plan's own "exactly two commits" verification.

## User Setup Required

None — no external service configuration required. Nothing was pushed and no PR was opened; the phase
branch is local to `repos/security-platform` and merges in 17-07 after human sign-off.

## Next Phase Readiness

- **Ready for 17-02 onward.** `bash scripts/check-workflow-uploads.sh` is the phase's standing gate: it must
  stay at exit 0 through every subsequent plan, and 17-03/17-04 must satisfy SARIF-CATEGORY,
  ARTIFACT-RETENTION, ARTIFACT-PATH-SAFETY and UPLOAD-VERIFY-PAIRING the moment they add upload steps.
- **UPLOAD-VERIFY-PAIRING is the contract 17-03/17-04 inherit:** every upload step needs an `id:` and a
  LATER step in the SAME job whose `run` reads `steps.<id>.outcome`.
- **ARTIFACT-PATH-SAFETY forbids globs with a directory component.** 16-04 numbers the npm and pip reports
  per input (`npm-audit-<n>.json`, `pip-audit-<n>.json`), so 17-04 must use a bare-basename glob such as
  `npm-audit-*.json` — not a path-qualified one.
- **Two action SHAs stand resolved and unused so far** (upload-sarif `b96794f0…`, upload-artifact
  `043fb46d…`). The trap recorded in the plan still applies: `actions/checkout` is also v7.0.1 with a
  different SHA (`3d3c42e5…`).
- **No blockers.**

---
*Phase: 17-sarif-upload-and-artifact-retention*
*Completed: 2026-09-11*
