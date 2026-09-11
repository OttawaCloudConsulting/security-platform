---
phase: 16-sca-ecosystem-coverage
verified: 2026-09-11T16:00:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 1
overrides:
  - must_have: "Terraform provider and module version pinning is checked, and floating or unpinned versions are reported as findings (ROADMAP Success Criterion 3)"
    reason: "tflint's default bundled ruleset (v0.15.0 under tflint v0.64.0) flags missing provider version constraints (terraform_required_providers) and unpinned module sources (terraform_module_version) but does NOT flag a floating range such as version = \">= 3.0\" — measured live on run 34614017396 and documented in ADR-015's Tradeoff section. A custom rule to close this gap was deliberately out of scope for Phase 16 (flagging every `~>` constraint would be noisy, since `~>` is HashiCorp's own recommended practice). The user was presented this exact limitation before approving the merge."
    accepted_by: "cturner (via 16-07 Task 1 checkpoint, recorded verbatim as 'Approved — merge')"
    accepted_at: "2026-09-11T15:27:38Z"
---

# Phase 16: SCA Ecosystem Coverage Verification Report

**Phase Goal:** The SCA job audits each dependency ecosystem this practice actually uses, rather than relying on the generic filesystem sweep alone.
**Verified:** 2026-09-11T16:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Verification Method

This report does not rely on SUMMARY.md narrative. Every claim below was re-derived independently:
- `git fetch origin` + `git show origin/main:<path>` against the nested, gitignored repo `repos/security-platform` (slug `OttawaCloudConsulting/security-platform`), confirming the Phase 16 merge (`40682ce`) actually landed on the real default branch, not just the local worktree.
- `gh run view --log --job 103311309103` against live workflow run `34614017396` on GitHub, read directly rather than copied from 16-05-SUMMARY's excerpts.
- `gh pr view 7 --json state,mergeCommit` confirming PR #7 is `MERGED` with mergeCommit `40682cea...` — matches origin/main HEAD.
- The three detector scripts (`detect-npm.sh`, `detect-python.sh`, `detect-terraform.sh`) extracted from `origin/main` and executed directly in a scratch empty git repo and in the real fixture-bearing checkout, to prove the skip/found behavior rather than trust the smoke-gate's own report.
- `python3 -c "yaml.safe_load(...)"` against `origin/main`'s `security.yml` to confirm job topology (5 jobs, 0 `needs:`).

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP Success Criteria) | Status | Evidence |
|---|---|---|---|
| 1 | On a repo containing `package-lock.json`, the SCA job reports npm dependency vulnerabilities with severity levels | ✓ VERIFIED | Live log, run 34614017396: `npm audit severity histogram [npm-audit-1.json]: info=0 low=0 moderate=0 high=1 critical=1 total=2`, `package=lodash severity=high`, `package=minimist severity=critical` — read directly via `gh run view --log`, not copied from SUMMARY |
| 2 | On a repo containing Python dependency files, the SCA job reports Python advisories via pip-audit or equivalent | ✓ VERIFIED | Live log: `pip-audit [fixtures/requirements.txt] exit=1`, `pip-audit advisory entries [pip-audit-1.json]: 46 (23 unique ids)` — read directly from the run |
| 3 | Terraform provider and module version pinning is checked, and floating or unpinned versions are reported as findings | ✓ PASSED (override) | Live log: `tflint rule ids: ['terraform_module_version', 'terraform_required_providers', 'terraform_required_version']` — two are genuine pinning rules (missing constraint + unpinned module). Floating ranges (`>= 3.0`) are NOT detected by tflint's default ruleset — measured limitation, documented in ADR-015, explicitly accepted by the user before merge (see override above) |
| 4 | Each sub-scan skips cleanly with a clear log message — no failure, no false pass — when the repo contains no files for that ecosystem | ✓ VERIFIED | Independently executed all three detectors from `origin/main` in a fresh empty `git init` scratch repo: all three printed `SKIP: ...`, wrote `found=false` to `$GITHUB_OUTPUT`, exited 0. Same detectors in the populated fixture repo printed `FOUND 1 ...`, wrote `found=true`, exited 0. Workflow YAML confirms every scan/verify/evidence step in the `sca` job is gated on `steps.<id>.outputs.found == 'true'`, so an absent ecosystem cannot turn the job red |

**Score:** 3/4 truths directly verified + 1/4 passed via documented, user-approved override = 4/4

### Required Artifacts (on `origin/main` of `OttawaCloudConsulting/security-platform`, post-merge)

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `.github/workflows/security.yml` | Extends `sca` job with npm/pip-audit/tflint steps, still 5 jobs, 0 `needs:` | ✓ VERIFIED | Confirmed via `yaml.safe_load`: jobs = `[sast, iac, sca, container, secrets]`, no job has `needs`; `sca.name == 'SCA — Trivy Filesystem'` (byte-checked em dash U+2014). Detect/scan/verify/evidence step groups present and correctly guarded |
| `scripts/detect-npm.sh` | npm lockfile detection, `*package-lock.json` pathspec | ✓ VERIFIED, WIRED | Content matches plan; invoked by workflow (`bash scripts/detect-npm.sh npm-lockfiles.txt`); executed directly — produces correct FOUND/SKIP behavior on both branches |
| `scripts/detect-python.sh` | Python requirements detection, `*requirements*.txt` pathspec | ✓ VERIFIED, WIRED | Same pattern; executed directly, correct behavior |
| `scripts/detect-terraform.sh` | Terraform file detection, `*.tf` pathspec | ✓ VERIFIED, WIRED | Same pattern; executed directly, correct behavior |
| `scripts/smoke-scans.sh` | Generalised local harness: `run_scan_rc`, SKIPPED accounting | ✓ VERIFIED | Contains `run_scan_rc`, tflint's `run_scan_rc 2` handling, `SKIPPED` array and accounting logic, calls the shared `detect-*.sh` scripts |
| `fixtures/requirements.txt` | `requests==2.19.1` pinned vulnerable package | ✓ VERIFIED | Content confirmed on `origin/main`: `requests==2.19.1`, `jinja2==2.11.2` |
| `fixtures/main.tf` | Unconstrained-and-used `random` provider + unpinned module; existing `aws` 3.74.0 pin untouched | ✓ VERIFIED | Content confirmed: `hashicorp/random` with no version, `random_id.fixture` resource consuming it, `module "fixture_unpinned_module"` with no version, and `hashicorp/aws` `version = "3.74.0"` still present (no regression) |
| `fixtures/README.md` | Re-measured finding counts including npm audit, pip-audit, tflint | ✓ VERIFIED | Table includes rows for tflint (3 issues, rule ids named) and pip-audit (46/23 unique) |
| `docs/adr/adr015-tflint-terraform-pin-checking.md` | ADR for tflint adoption, states floating-range limitation honestly | ✓ VERIFIED | Contains `terraform_required_providers`, explicit statement that `version = ">= 3.0"` is **NOT** flagged by the default ruleset |
| `docs/adr/README.md` | Index row for ADR-015 | ✓ VERIFIED | Row present: `[ADR-015](adr015-tflint-terraform-pin-checking.md) ... Accepted` |
| `docs/development-security-stack-option-1.md` | Tool tables list pip-audit and tflint | ✓ VERIFIED | Tool Selection Summary row for pip-audit and tflint; coverage matrix column for both; footnote on tflint's floating-range gap with ADR-015 cross-reference |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `sca` job detect steps | `scripts/detect-{npm,python,terraform}.sh` | `bash scripts/detect-<x>.sh <list-file>` | ✓ WIRED | Confirmed in workflow YAML at the expected line numbers |
| Detect step `outputs.found` | Scan/verify/evidence steps | `if: steps.<id>.outputs.found == 'true'` | ✓ WIRED | Every guarded step in the `sca` job correctly references its detector's output; independently proved to resolve `true` on a populated repo and behave correctly (skip, not fail) on an empty one |
| `fixtures/main.tf` `required_providers.random` | `resource "random_id" "fixture"` | provider must be USED to trigger `terraform_required_providers` | ✓ WIRED | Both present; live run confirms the rule fired |
| PR #7 / `feature/phase-16-sca-ecosystem-coverage` | `OttawaCloudConsulting/security-platform` `main` | human-approved merge | ✓ WIRED | `gh pr view 7` returns `state: MERGED`, `mergeCommit.oid: 40682cea...`, matching `origin/main` HEAD after `git fetch` |

### Data-Flow Trace (Level 4)

Not applicable in the UI-rendering sense — this phase's output is CI log/report data, not a rendered UI. The equivalent trace (report file → verification step → job log) was performed as part of truths 1–4 above: real tool output (`npm-audit-1.json`, `pip-audit-1.json`, `tflint.sarif`) flows into non-tolerant verification steps that would fail the job on an error-shaped or empty report, and this was confirmed both by reading the verification step source and by observing that the live run's `Verify *` steps concluded `success` (i.e., the guard did not fire, meaning real data was present).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Criterion 4 skip path (empty repo) | `bash detect-npm.sh` / `detect-python.sh` / `detect-terraform.sh` in fresh `git init` scratch dir | Three `SKIP: ...` lines, `found=false` x3, exit 0 x3 | ✓ PASS |
| Criterion 4 found path (populated repo) | Same three scripts run against the real `fixtures/` checkout | Three `FOUND 1 ...` lines, `found=true` x3, exit 0 x3 | ✓ PASS |
| Live npm/pip-audit/tflint evidence | `gh run view --log --job 103311309103` | Histogram, advisory counts, and rule-id set match SUMMARY claims exactly | ✓ PASS |
| PR merge state | `gh pr view 7 --json state,mergeCommit` | `MERGED`, commit matches `origin/main` HEAD | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` convention exists in `repos/security-platform`; none declared in the Phase 16 plans. N/A — skipped.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| SCA-01 | 16-02, 16-03, 16-04, 16-05, 16-07 | SCA job audits npm/Node dependencies | ✓ SATISFIED | Live npm audit histogram with severities; `[x]` in REQUIREMENTS.md, `Phase 16 \| Complete` |
| SCA-02 | 16-01, 16-02, 16-03, 16-04, 16-05, 16-07 | SCA job audits Python dependencies | ✓ SATISFIED | Live pip-audit advisory output; `[x]` in REQUIREMENTS.md |
| SCA-03 | 16-01, 16-02, 16-03, 16-04, 16-05, 16-06, 16-07 | SCA job checks Terraform provider/module pinning | ✓ SATISFIED (via documented override for the floating-range gap) | Live tflint pinning-rule findings; ADR-015 documents the honest limitation; `[x]` in REQUIREMENTS.md |

No orphaned requirements — REQUIREMENTS.md maps only SCA-01/02/03 to Phase 16, and all three are claimed across the plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `scripts/detect-npm.sh` | discovery pipeline | `\|\| true` after `grep -v` | ℹ️ Info | Documented in-line as intentional — `grep -v` returns rc=1 on no-match under `set -o pipefail`, which is not an error condition here. Does not affect the FOUND/SKIP decision branch. Not a stub. |
| `.planning/ROADMAP.md` | Phases 17–20 | `**Plans**: TBD` | ℹ️ Info | Future-phase planning placeholder for phases not yet planned — not a Phase 16 deliverable debt marker. Not a blocker. |
| `cicd/.github/workflows/security.yml` (outer repo) | — | Stale relative to the product-repo `security.yml` (unchanged since 16-04) | ⚠️ Warning | Explicitly flagged in 16-07-SUMMARY as a known loose end, non-blocking. Not addressed by a later phase's stated goal/success criteria as far as could be checked (Phase 20 covers "template packaging," which may eventually sync this, but nothing explicit) — recorded as a warning, not deferred, since the match is not clear enough per Step 9b's conservative-matching rule |

No `TBD`/`FIXME`/`XXX` debt markers found in the phase's actual source deliverables (workflow, detector scripts, smoke gate, fixtures, ADR-015, blueprint edits).

### Human Verification Required

None. All must-haves were verified either by direct re-derivation from `origin/main` and the live GitHub Actions run, or by an explicit, previously-recorded human decision (Criterion 3's override, approved verbatim by the user in the 16-07 checkpoint before this verification ran).

### Gaps Summary

No gaps. All four ROADMAP Success Criteria are met: three directly, one (Criterion 3) through a documented and already-approved override for a measured, disclosed limitation of tflint's default ruleset (floating version ranges are not flagged; missing constraints and unpinned module sources are). This is not a re-litigation of a settled question — the user was shown this exact tradeoff and approved the merge with it named explicitly.

The phase goal — "The SCA job audits each dependency ecosystem this practice actually uses, rather than relying on the generic filesystem sweep alone" — is achieved and observably true on `origin/main`: npm, Python and Terraform ecosystems are each audited by a dedicated tool (npm audit, pip-audit, tflint) wired into the existing `sca` job, each gated cleanly on ecosystem presence, verified both statically and on a live CI run.

---

_Verified: 2026-09-11T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
