---
phase: 17-sarif-upload-and-artifact-retention
plan: 02
subsystem: infra
tags: [github-actions, trivy, sarif, code-scanning, originalUriBaseIds, smoke-gate, shellcheck, yamllint]

# Dependency graph
requires:
  - phase: 15-five-parallel-scan-jobs
    provides: "the sca job's Trivy filesystem scan + Convert to SARIF pair, and the run_scan/require_success split in scripts/smoke-scans.sh"
  - phase: 16-sca-ecosystem-coverage
    provides: "the four-tool sca job and the 9-gated-run smoke gate baseline recorded in 16-03-SUMMARY.md"
  - phase: 17-sarif-upload-and-artifact-retention
    provides: "17-01: scripts/check-workflow-uploads.sh (the phase's standing offline gate) and the security-events: write grant on both sides of the workflow_call boundary"
provides:
  - "sca job emits trivy-fs.sarif from a DIRECT `trivy fs . --format sarif` run, so originalUriBaseIds.ROOTPATH is the scan root (measured: the repo root) rather than the input JSON file"
  - "Flag parity between the two sca Trivy invocations (--scanners vuln / --exit-code 1 / --severity HIGH,CRITICAL) so the retained JSON artifact and the uploaded SARIF describe the same finding set"
  - "scripts/smoke-scans.sh runs the same two invocations locally, scored with scanner semantics (run_scan, not require_success)"
  - "A ROOTPATH regression guard in the smoke gate that fails when runs[0].originalUriBaseIds.ROOTPATH is absent or points at a .json input file"
affects: [17-03, 17-04, 17-05, 17-06, 17-07, 18-gate-mode-and-branch-protection, 20-distribution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-invocation scanner split: one scanner run per output format, as two separate steps with `if: always()` on the second, because GitHub's default shell is bash -e and every scanner here exits non-zero by design (D-04). Established by the secrets job's Gitleaks pair in Phase 15; now also the sca job's Trivy pair."
    - "Format conversion is not assumed lossless: where a converted artifact's metadata differs from a directly-emitted one, the directly-emitted form wins and the difference is asserted in the gate, not just commented."
    - "A regression guard that names the wrong form it defends against, in-line, so 'simplify this back' is refused by the gate rather than by reviewer memory."

key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml
    - repos/security-platform/scripts/smoke-scans.sh

key-decisions:
  - "OD-7 Option A executed as written: the sca job's `Convert to SARIF` step was REPLACED by a second direct `trivy fs` run rather than post-processed. `trivy convert` writes originalUriBaseIds.ROOTPATH = the INPUT JSON FILE path; direct --format sarif writes the SCAN ROOT (measured 2026-09-11, trivy 0.74.0, re-confirmed live by this plan's own gate run)."
  - "The new SARIF run carries --exit-code 1 and --severity HIGH,CRITICAL, identical to the JSON run, NOT --exit-code 0. Flag parity is the property that keeps the retained artifact and the uploaded SARIF describing the same finding set; a drifting severity or exit code would publish a SARIF that disagrees with the artifact."
  - "The consequence of that parity is the tiebreaker 17-PATTERNS OD-7 asked for: in smoke-scans.sh the new run takes `run_scan` (PASS on exit 1), NOT `require_success`. 17-VALIDATION's blanket 'must use require_success' is correct only for genuinely exit-0 infrastructure steps; applying it to a scanner would score a healthy findings run as a FAIL — the exact inversion Phase 15 hit with docker build and trivy convert."
  - "The container job's `Convert to SARIF` is deliberately UNTOUCHED — its 56 results point at library/scan-fixture 1:1 under any form, so there is no location fidelity to preserve, and user decision D-01 satisfies Criterion 4 by naming trivy convert as the phase's already-implemented documented conversion step. ADR-016 (17-06) records that the surviving trivy convert lives in the container job."
  - "The ROOTPATH guard rejects `.json` after stripping trailing slashes, not just the literal `.json/` the plan names — the converted form's value ends in `.json/`, but a future Trivy release emitting the same input-file base without the trailing slash would otherwise slip through."
  - "The guard distinguishes its failure modes by exit code (2 unreadable, 3 no runs[], 4 ROOTPATH absent, 5 ROOTPATH is a .json input file) so a future reader can tell which invariant broke from the exit status alone; the surrounding bash appends one FAILURES entry, matching the pip-audit/tflint idiom exactly."

patterns-established:
  - "Negative-testing a bash-embedded python assertion without running the slow gate: extract the heredoc body verbatim with sed, then drive it against crafted fixtures in the scratchpad. Proves the guard fires without a second 4-minute full-gate run."
  - "Baseline comparison by recorded number, not by re-measurement: the 'before' gated-run count came from 16-03-SUMMARY.md (9), never from a pre-change gate run, so the expected 10 was a prediction the single permitted run either confirmed or falsified."

# NOTE: this field mirrors the PLAN.md frontmatter, as the template requires. It is NOT an
# assertion of delivery. 17-02 changes HOW trivy-fs.sarif is produced; it adds no upload step.
# CICD-02 (SARIF upload to the Security tab) and CICD-03 (JSON artifact retention) remain
# Pending and are marked by 17-03 and 17-04. See Issues Encountered.
requirements-completed: [CICD-02, CICD-03]

# Metrics
duration: 5min
completed: 2026-09-11
---

# Phase 17 Plan 02: Direct SARIF Emission for the SCA Trivy Scan

**The `sca` job's `trivy convert` step is gone, replaced by a second flag-identical `trivy fs --format sarif` run whose `originalUriBaseIds.ROOTPATH` is the scan root; the smoke gate now runs both invocations with scanner semantics and fails if the broken base ever returns.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-09-11T18:10:27Z
- **Completed:** 2026-09-11T18:15:13Z
- **Tasks:** 2
- **Files modified:** 2 (0 created, 2 modified)

## Accomplishments

- The first SARIF this repository will ever upload (17-03) is now correctly based. The change landed **before** any upload step exists, so there is no window in which a broken-base SARIF reaches code scanning.
- The measured ROOTPATH prediction from 17-RESEARCH Pitfall 3 was **re-confirmed live**, not taken on trust: the gate printed the repo root.
- The gate's new guard was **observed firing** against all three of its failure modes, without spending a second full-gate run.
- The two Trivy invocations are byte-identical in flags, so T-17-09 (the retained JSON and the uploaded SARIF disagreeing about what was found) is closed structurally rather than by convention.

## Task Commits

1. **Task 1: Replace the sca job's convert step with a direct SARIF scan** — `a3f9dac` (refactor)
2. **Task 2: Mirror the change in the smoke gate, add the ROOTPATH regression assertion, and run the full gate** — `f3e6dec` (test)

Both commits are on `feature/phase-17-sarif-upload-and-artifact-retention` in the nested product repo `repos/security-platform`, continuing 17-01's branch (`34cd158`, `66a18ad`). Nothing pushed.

## Files Created/Modified

- `repos/security-platform/.github/workflows/security.yml` — `sca` job: step renamed to `Run Trivy filesystem scan (JSON for retention)`; `Convert to SARIF` deleted and replaced by `Run Trivy filesystem scan (SARIF for code scanning)` with a 13-line rationale comment. +20 / -4.
- `repos/security-platform/scripts/smoke-scans.sh` — header paragraph on the two invocations, `SCANS_PASSED` comment extended, `require_success "trivy-fs-convert"` replaced by `run_scan "trivy-fs-sarif"`, ROOTPATH guard added. +55 / -2.

## Required Output: Observed Evidence

### The ROOTPATH value the gate actually printed

```
==> trivy-fs-sarif: exit=1 (PASS - finding(s) detected)
    report OK: …/trivy-fs.sarif
    trivy-fs SARIF originalUriBaseIds.ROOTPATH: file:///Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/
```

The scan root — the repository itself. Not `…/trivy-fs.json/`. This is the live confirmation of
17-RESEARCH Pitfall 3's measurement (b); on the runner the same invocation yields
`file:///home/runner/work/security-platform/security-platform/`.

### `ALL PASS` gated-run count, before and after

| | Gated runs | Source |
|---|---|---|
| Before (16-03 / 16-04 baseline) | **9** | `16-03-SUMMARY.md` line 88 — `SCANS_PASSED` = 9 gated runs |
| After (this plan) | **10** | observed |

```
ALL PASS - 10 gated scan run(s) produced real, non-empty findings; 0 sub-check(s) skipped (not passed).
```

Exactly one higher, as predicted: the new `trivy-fs-sarif` run is counted, consistent with the header's
documented rule that runs are counted, not tools (Gitleaks is likewise counted twice). Gate exit code 0.
No previously-passing sub-check regressed — Gitleaks still reports its 9-finding baseline list, the three
skip probes still PASS, and 0 sub-checks were skipped (every optional tool was present: `pip-audit`,
`tflint`, `trivy 0.74.0`, a running Docker daemon — all pre-flighted before the single permitted run).

### The container job's `trivy convert` is still present — quoted verbatim

`.github/workflows/security.yml` lines 394-396, unmodified by this plan:

```yaml
      - name: Convert to SARIF
        if: always()
        run: trivy convert --format sarif --output trivy-image.sarif trivy-image.json
```

The inline YAML parse asserts this positively (`'the container job trivy convert was removed — it must
stay'`) alongside asserting its absence from the `sca` job, so a later plan cannot delete the step D-01
rests on without failing 17-02's own verification.

### The ROOTPATH guard was observed firing, all three failure modes

The heredoc body was extracted verbatim from the committed script with `sed` and driven against crafted
SARIF fixtures in the scratchpad (the repo was never mutated, and the slow gate was not re-run):

| Case | Fixture | Observed |
|---|---|---|
| The `trivy convert` form | `ROOTPATH.uri = "file:///w/trivy-fs.json/"` | rc=5, `ROOTPATH points at a .json INPUT FILE, not the scan root` |
| ROOTPATH absent | `runs[0]` with no `originalUriBaseIds` | rc=4, `ROOTPATH absent: result locations have no base to resolve against` |
| No runs at all | `{"runs":[]}` | rc=3, `trivy-fs SARIF carries no runs[]` |

Each non-zero rc reaches the surrounding `if [ "$rootpath_rc" -ne 0 ]` and appends to `FAILURES`. The
block does **not** end in `|| true`.

### Other verification

| Check | Result |
|---|---|
| Inline `yaml.safe_load` assertions (Task 1 verify 1) | all pass — `sca: convert removed, one direct SARIF run with parity flags; container convert intact` |
| `bash scripts/check-workflow-uploads.sh` | exit 0, `PASS - 10 checks, 0 failures` |
| `yamllint -d relaxed .github/workflows/security.yml` | exit 0; **33 output lines before and after the change** — the 13 new comment lines add zero new warnings (all ≤80 chars) |
| `shellcheck scripts/smoke-scans.sh` | exit 0 (also run by the repo's pre-commit hook on the Task 2 commit — Passed) |
| `grep 'run_scan "trivy-fs-sarif"'` / `! grep 'trivy-fs-convert'` / `grep 'require_success "trivy-image-convert"'` | all as required |
| `security.yml` job shape | 5 jobs, zero `needs:` |

## Decisions Made

See `key-decisions` in the frontmatter. The one a later reader is most likely to "correct" wrongly:

**`run_scan`, not `require_success`, for `trivy-fs-sarif`.** 17-VALIDATION states the SCA additions must use
`require_success`. That instruction is correct for exit-0 infrastructure steps and wrong here, because
OD-7's flag-parity decision makes the new invocation a scanner that exits 1 on findings. Scoring it with
`require_success` would turn a healthy findings run into a FAIL — the precise inversion Phase 15 already
hit once. The rationale is written into the script above the call, naming `trivy-image-convert` as the
contrasting case that keeps `require_success`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing Critical] The ROOTPATH guard rejects `.json` with or without a trailing slash**
- **Found during:** Task 2 (authoring the assertion)
- **Issue:** The plan specifies failing when the value "ends with `.json/`". Trivy 0.74.0's converted form
  does end in `.json/`, but the invariant being defended is "ROOTPATH must not be the input file", and a
  value of `file:///w/trivy-fs.json` (no trailing slash) would satisfy the literal rule while violating it.
- **Fix:** `rootpath.rstrip("/").endswith(".json")` — strictly stronger than the plan's wording, never weaker.
- **Files modified:** `repos/security-platform/scripts/smoke-scans.sh`
- **Verification:** The `file:///w/trivy-fs.json/` fixture fires (rc=5); the real scan-root value passes.
- **Committed in:** `f3e6dec` (Task 2 commit)

**2. [Rule 1 — Trivial] The guard also fails an empty or missing `runs[]`**
- **Found during:** Task 2 (authoring the assertion)
- **Issue:** The plan's wording reads `runs[0].originalUriBaseIds.ROOTPATH.uri`. On a SARIF with `runs: []`
  that is an `IndexError` — an uncaught traceback whose non-zero exit would be argued after the fact as
  "the guard worked", rather than a named verdict.
- **Fix:** An explicit `if not runs: … sys.exit(3)` branch with its own message, before any indexing.
- **Files modified:** `repos/security-platform/scripts/smoke-scans.sh`
- **Verification:** The `{"runs":[]}` fixture prints `trivy-fs SARIF carries no runs[]` and exits 3.
- **Committed in:** `f3e6dec` (Task 2 commit)

**3. [Rule 1 — Trivial] Header change placed as a new paragraph rather than an edit to the opening sentence**
- **Found during:** Task 2 (header update)
- **Issue:** The plan asks the header to "mention the two Trivy fs invocations … rather than a conversion".
  The opening sentence enumerates CI *jobs*, not invocations; rewriting it to carry per-invocation detail
  would have made it less accurate about the thing it actually describes.
- **Fix:** A dedicated paragraph on the SCA section's two invocations, plus an extension of the
  `SCANS_PASSED` comment ("and so is Trivy fs"). `require_success`'s own docstring still mentions
  `trivy convert` — correctly, since the container job still uses it.
- **Files modified:** `repos/security-platform/scripts/smoke-scans.sh`
- **Verification:** Header reads accurately against the code beneath it; `shellcheck` exit 0.
- **Committed in:** `f3e6dec` (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 missing critical, 2 trivial)
**Impact on plan:** All three strengthen or clarify invariants the plan already states as its intent. No
scope creep: no upload step, no artifact step, no trigger change, and the container job untouched.

## Issues Encountered

**1. `requirements.mark-complete` was NOT run for CICD-02 / CICD-03 — deliberately, following 17-01.**
This plan's frontmatter mirrors the PLAN's `requirements: [CICD-02, CICD-03]`, as the summary template
requires, but 17-02 delivers neither. It changes *how* `trivy-fs.sarif` is produced; there is still not a
single `upload-sarif` or `upload-artifact` step in either workflow file. 17-01 ran the finalisation step
verbatim, saw both requirements flip to Complete, and reverted it. That lesson was applied here by not
running the step at all. `.planning/REQUIREMENTS.md` is untouched and both requirements remain **Pending**.
**17-03 and 17-04 must mark them**, once the upload steps they name actually exist.

**2. The smoke gate is slow (~4 min) and the plan permits exactly one run.** Rather than discover a missing
dependency mid-run, the environment was pre-flighted first: `trivy --version` (0.74.0), `pip-audit`,
`tflint`, `shellcheck`, `yamllint`, and `docker info`. All present, which is why the run produced 10 gated
runs and 0 skips instead of a skip-reduced count that would have had to be reported as a mismatch.

No unresolved issues.

## User Setup Required

None — no external service configuration required. Nothing was pushed and no PR was opened; the phase
branch is local to `repos/security-platform` and merges in 17-07 after human sign-off.

## Next Phase Readiness

- **Ready for 17-03.** `trivy-fs.sarif` now exists at the workspace root with a scan-root `ROOTPATH`, ready
  for `upload-sarif`. 17-03 inherits 17-01's UPLOAD-VERIFY-PAIRING contract (every upload step needs an
  `id:` and a LATER step in the SAME job whose `run` reads `steps.<id>.outcome`) and SARIF-CATEGORY.
- **Flag parity is now a maintained invariant, not a comment.** If 17-03 or a later plan changes
  `--severity` or `--exit-code` on either `sca` Trivy run, it must change both — Task 1's inline YAML parse
  asserts the JSON run's flags and the SARIF run's flags independently, and the smoke gate runs both.
- **The gated-run baseline for the next plan that touches `smoke-scans.sh` is 10**, not 9.
- **17-06 (ADR-016) has its subject matter confirmed:** exactly one `trivy convert` survives in the repo,
  in the `container` job at `security.yml:394-396`, quoted above.
- **No blockers.**

---
*Phase: 17-sarif-upload-and-artifact-retention*
*Completed: 2026-09-11*
