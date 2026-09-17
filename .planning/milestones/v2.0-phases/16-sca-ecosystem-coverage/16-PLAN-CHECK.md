# Plan Check: Phase 16 — SCA Ecosystem Coverage

**Checked:** 2026-09-11
**Plans:** 16-01 through 16-07 (7 plans)
**Status:** ISSUES FOUND (1 blocker, 5 warnings)

---

## Coverage Summary

| Requirement | Plans | Status |
|---|---|---|
| SCA-01 (npm audit) | 02, 03, 04, 05, 07 | Covered |
| SCA-02 (pip-audit) | 01, 02, 03, 04, 05, 07 | Covered |
| SCA-03 (tflint) | 01, 02, 03, 04, 05, 06, 07 | Covered |
| Criterion 4 (clean skip) | 02, 03, 04 | Covered |

All three phase requirements (SCA-01/02/03) appear in `requirements:` frontmatter of the plans that implement them. No ROADMAP requirement for this phase is unmapped.

## Plan Summary

| Plan | Wave | depends_on | Tasks | Files | Status |
|---|---|---|---|---|---|
| 16-01 | 1 | [] | 2 | 3 | Valid |
| 16-02 | 2 | [16-01] | 2 | 4 | Valid |
| 16-03 | 3 | [16-02] | 2 | 1 (same file, 2 tasks) | Valid — see Blocker 1 |
| 16-04 | 4 | [16-03] | 3 | 1 | Valid |
| 16-05 | 5 | [16-04] | 2 | 0 (evidence-only) | Valid |
| 16-06 | 6 | [16-05] | 2 | 3 | Valid |
| 16-07 | 7 | [16-05, 16-06] | 2 (1 checkpoint) | 0 (merge/sign-off) | Valid |

Dependency graph is a single linear chain, acyclic, no forward references, no missing plan references. Wave numbers = max(deps)+1 throughout. Scope is well within budget on every plan (1–3 tasks, ≤4 files).

---

## Blockers (must fix)

### 1. [key_links_planned / task_completeness] 16-03 detector list files will pollute the working tree and break the plan's own "clean git status" acceptance criterion

- **Plan:** 16-03, Task 2
- **Evidence:** The detector contract fixed by 16-02 (Task 1) writes its list file to a **positional argument defaulting to cwd** (`npm-lockfiles.txt`, `py-reqs.txt`, `tf-files.txt`) when no argument is given. `scripts/smoke-scans.sh` uses `OUT="$(mktemp -d)"` for every report it writes (confirmed: `grep -n 'OUT=' scripts/smoke-scans.sh` → line 17, the only definition). Neither 16-03's Task 1 action nor Task 2's action instructs the new SCA sub-scan sections to invoke the detectors with an explicit `"$OUT/<file>"` argument, nor does it add the three default list-file names to `.gitignore` (confirmed absent: `repos/security-platform/.gitignore` has no entry for `npm-lockfiles.txt` / `py-reqs.txt` / `tf-files.txt`).
- **Consequence:** Running `bash scripts/smoke-scans.sh` from the repo root (as every verify command in 16-03 and 16-02 does) will leave three untracked files at the repo root. Task 2's own verify command chain — `pre-commit run --all-files && git status --porcelain | wc -l | grep -qx '[[:space:]]*0'` — and its acceptance criterion ("Working tree clean") will fail on the very first execution, because the smoke gate run earlier in the same task creates those untracked files and nothing in the plan removes or redirects them.
- **Fix hint:** In 16-03 Task 1's action, specify that each sub-scan section invokes its detector with an explicit output path inside the existing `$OUT` temp directory (e.g. `bash scripts/detect-npm.sh "$OUT/npm-lockfiles.txt"`), consistent with how every other report in this script is already handled — or add the three default filenames to `.gitignore` and have Task 2 explicitly remove them before the git-status check. Either fix is small; the plan should say which.

---

## Warnings (should fix)

### 2. [research_resolution] 16-RESEARCH.md's Open Questions and 16-PATTERNS.md's Open Decisions are functionally resolved but not formally marked

- **File:** `16-RESEARCH.md` §Open Questions (no `(RESOLVED)` suffix on the heading, no inline `RESOLVED:` markers on Q1–Q4); `16-PATTERNS.md` §"Decision Conflicts / Open Decisions for the Planner" (same gap, 7 items).
- **Evidence these were actually resolved** (traceable through the plans, not guessed):

  | Open item | Resolution | Where encoded |
  |---|---|---|
  | Q1 / #6 — "floating" ranges | Scoped honestly to missing-constraint + unpinned-module only; `>= 3.0` explicitly excluded | 16-01 fixture header comment, 16-03 assertion + comment, 16-06 ADR-015 Tradeoff, 16-07 checkpoint item 3 |
  | Q2 / #2 — pip-audit invocation mode | Default resolving mode locked in, `--no-deps`/`--disable-pip`/`--require-hashes` explicitly forbidden | 16-03 notes ("locked decision"), 16-04 action + acceptance criteria |
  | Q3 — severity threshold | `--audit-level=high` for exit-code consistency, full report retained regardless | 16-04 notes, action |
  | Q4 / #4 — blueprint/ADR update | Yes, as a separate plan so a failed CI iteration can't leave docs half-edited | 16-06 (entire plan), sequenced after 16-05 |
  | #1 — inline vs. extracted detectors | Extracted scripts (stated explicitly: "The user resolved it: extracted scripts") | 16-02 objective |
  | #3 — smoke-gate preflight for pip-audit/tflint | Soft tier: skip-and-warn, not hard-fail | 16-02 Task 2 |
  | A1 — tflint has zero precedent | Adopted, with ADR-015 as the record | 16-06 |
  | #4/A3 — `sca` job rename | Not renamed; frozen because Phase 18 hard-codes the name | 16-04 notes, 16-07 checkpoint item 4 |

- **Impact:** None on execution — every decision needed by the plans is present and enforced (anti-pattern callouts, explicit "locked decision" language, acceptance criteria). This is a paper-trail gap in the research/pattern artifacts themselves, which will confuse a future reader who consults `16-RESEARCH.md` directly and sees unresolved-looking questions.
- **Fix hint:** Append `(RESOLVED)` to the `## Open Questions` heading in 16-RESEARCH.md and a one-line resolution under each of Q1–Q4; do the same for the "Decision Conflicts" table in 16-PATTERNS.md. Low cost, no plan changes required.

### 3. [nyquist_compliance / process] 16-VALIDATION.md is still the unfilled template

- **File:** `16-VALIDATION.md` — frontmatter `nyquist_compliant: false`, `wave_0_complete: false`; every section body is still a `{placeholder}`.
- **Assessment:** This does **not** block Dimension 8 mechanically — Check 8e only verifies the file exists (it does), and Checks 8a–8d evaluate the *plan tasks*, not this file's content. Every task across all 7 plans carries concrete `<automated>` verify commands (bash smoke-gate runs, `yamllint`, `python3`/`yaml.safe_load` static assertions, `bash -n`), there are no watch-mode flags, and no 3-consecutive-task window lacks automated verify. The Wave 0 gaps this template should have listed are the exact same list already itemized, correctly, in `16-RESEARCH.md` §Validation Architecture ("Wave 0 Gaps," lines 699–707: `run_scan_rc`, `require_parses_json`, three sub-scan sections, negative-test block, `fixtures/requirements.txt`, extended `fixtures/main.tf`, `fixtures/README.md`) — and every one of those gaps is closed by 16-01/16-02/16-03. Substantive Nyquist compliance is met; the template artifact is simply out of sync with it.
- **Fix hint:** Acceptable to close post-execution via the nyquist-auditor, as the orchestrator's framing suggested — but recommend populating `16-VALIDATION.md` from the content already sitting in `16-RESEARCH.md` lines 666–707 (a copy/reformat, not new analysis) and flipping `nyquist_compliant: true` once done, so the artifact stops contradicting the plans it's supposed to govern.

### 4. [feedback_latency] Full smoke-gate runs (`bash scripts/smoke-scans.sh`) exceed the 30-second Nyquist latency guideline

- **Plans:** 16-02 Task 2, 16-03 Task 1 and Task 2 all use `bash scripts/smoke-scans.sh` as an `<automated>` verify command. 16-RESEARCH.md states the full suite takes "several minutes, dominated by the Trivy DB download and `docker build`," and pip-audit's default resolving mode alone measures ~11.5s per file.
- **Impact:** Per Check 8b this is a WARNING (full E2E-shaped local suite, not a fast unit/smoke check), not a blocker — GitHub Actions equivalents don't apply here since this runs locally, and each of these tasks *also* carries fast static checks (`bash -n`, `yamllint`, targeted `grep`, YAML-parse assertions) that fire first and would catch most defects before the slow full run is reached.
- **Fix hint:** None required to proceed; noted for awareness. If a future phase wants faster inner-loop feedback, consider splitting a "fast" detector-only smoke path from the full scanner suite.

### 5. [key_links_planned — resolved on inspection, recorded for completeness] "Three separate guarded evidence steps" deviation is sound, not a real deviation

- **Plan:** 16-04, Task 2 ("Show scan output files" step).
- **Assessment:** The orchestrator flagged this as a planner-declared deviation from a locked decision. On inspection, no locked decision specifies a single combined guard — the only requirement is "no false pass on ecosystem absence" (Criterion 4). `16-PATTERNS.md` Shared Pattern 4 explicitly *mandates* per-ecosystem guards on the evidence step and calls it "a required change, not a nicety," with a concrete failure scenario: a single combined guard (or the existing unconditional `ls`) would `ls` a numbered glob that doesn't exist when only one or two ecosystems are present, exiting 2 and failing the job on a clean skip — the exact failure Criterion 4 forbids from the other direction. 16-04's three separate guards, each keyed to its own `steps.<id>.outputs.found`, is the correct implementation of the project's own documented pattern, not a departure from it.
- **Verdict:** No fix needed. Not a deviation — a correct application of Shared Pattern 4.

### 6. [D-04 tag count spot-check — verified correct, recorded for completeness]

- **Plan:** 16-04, Task 2 verify: `[ "$(grep -c '# D-04' .github/workflows/security.yml)" -ge 11 ]`.
- **Verification performed:** `grep -c '# D-04' repos/security-platform/.github/workflows/security.yml` on the current `main` returns **7** (lines 38, 64, 94, 131, 174, 181, plus the `soft_fail: false` comment at line 70). Task 2 adds 4 new `# D-04`-tagged steps (npm scan, pip-audit scan, tflint-sarif, tflint-default). 7 + 4 = 11, exactly matching the `-ge 11` threshold in the plan's own verify command. **No defect — the threshold is correct.**

---

## Dimension Results

| Dimension | Result |
|---|---|
| 1. Requirement Coverage | PASS |
| 2. Task Completeness | PASS |
| 3. Dependency Correctness | PASS |
| 4. Key Links Planned | PASS (one BLOCKER on an unaddressed side effect — see Blocker 1) |
| 5. Scope Sanity | PASS |
| 6. Verification Derivation | PASS — truths are user-observable (log lines, PR mergeable state, rule ids), not implementation details |
| 7. Context Compliance (locked decisions passed via AskUserQuestion, no CONTEXT.md file) | PASS — all listed locked decisions (tflint for both provider+module, live workflow file not `cicd/`, pip-audit default mode, extracted detector scripts, soft-skip preflight, content-not-exit-code assertions, expected-rc parameterization, real negative test) are implemented and enforced with anti-pattern callouts across the 7 plans |
| 7b. Scope Reduction Detection | PASS — no "v1/v2", "static for now", "future enhancement", "stub" or similar scope-reduction language found reducing any locked decision. The one partial-coverage item (tflint not flagging floating ranges) is an honest, disclosed tool limitation — stated in the fixture comments, the smoke-gate assertions, ADR-015's Tradeoff section, and routed to explicit human sign-off in 16-07 — not a silently invented "v1" of the requirement. |
| 7c. Architectural Tier Compliance | PASS (SKIPPED-equivalent — no mismatches found; RESEARCH's Architectural Responsibility Map places all three sub-scans as CI-job steps in the `sca` job, and every plan honors that; no security-sensitive capability misplaced) |
| 8. Nyquist Compliance | PASS with WARNING (see Warning 3, 4) |
| 9. Cross-Plan Data Contracts | PASS — single linear pipeline (fixtures → detectors/helpers → sub-scan sections → workflow wiring → live evidence → docs → merge), no two plans transform the same data incompatibly |
| 10. CLAUDE.md Compliance | PASS — ADRs treated append-only, no executable bits set, `bash scripts/…` invocation preserved, blueprint structure/diagrams preservation explicitly checked (fence-count parity), STOP/REPORT/WAIT discipline on gate failures throughout |
| 11. Research Resolution | WARNING (see Warning 2) — functionally resolved, not formally marked |
| 12. Pattern Compliance | PASS — every file classified in 16-PATTERNS.md has a corresponding plan action that references its analog explicitly |

---

## Recommendation

One blocker (16-03's untracked list-file side effect) should be fixed before execution — it is small and mechanical (redirect detector output into the existing `$OUT` temp directory, or gitignore + explicit cleanup). The four warnings do not need to block execution: they are documentation/traceability gaps (Open Questions markers, VALIDATION.md sync) or accepted-tradeoff notes (smoke-gate latency) that don't change what the plans deliver.
