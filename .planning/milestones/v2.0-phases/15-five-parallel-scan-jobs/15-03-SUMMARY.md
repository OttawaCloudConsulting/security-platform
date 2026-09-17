---
phase: 15-five-parallel-scan-jobs
plan: 03
subsystem: infra
tags: [github-actions, semgrep, checkov, trivy, gitleaks, ci-cd, sha-pinning]

# Dependency graph
requires:
  - phase: 15-01
    provides: "fixtures/ tree with real, non-zero findings for IaC, container and SCA scan jobs"
  - phase: 15-02
    provides: "scripts/smoke-scans.sh empirically-verified flag sets and exit-code semantics for all five tools"
provides:
  - "repos/security-platform/.github/workflows/security.yml with five concurrent, needs:-free, step-tolerant scan jobs (sast, iac, sca, container, secrets) replacing the Phase 14 placeholder"
  - "Provenance-verified SHA pins for aquasecurity/setup-trivy@v0.3.1 and bridgecrewio/checkov-action@v12.3123.0, both dereferenced directly to a commit object via gh api"
  - "Empirical confirmation that the workflow file itself introduces zero new Semgrep/Checkov/Gitleaks findings, both pre-commit and post-commit"
affects: [15-04, 15-05, 17, 18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Step-level continue-on-error only, never job-level — D-04's report-only mechanism as a single flag per step, so Phase 18 flips gating back on by removing that flag rather than rewriting tool invocations"
    - "Two separate steps for tools with no dual-output flag (Gitleaks SARIF + JSON), the second carrying if: always(), to avoid GitHub's default bash -e silently dropping a chained second command after an expected-nonzero exit"

key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml

key-decisions:
  - "Task 1 has no separate commit by plan design — both tasks land in a single feat(15-03) commit at Task 2 step 4, matching the pattern already used in 15-01/15-02 for verification-then-commit task pairs"
  - "Reworded two inline comments (the p/default-vs-auto NOTE on the sast job, and the fetch-depth: 0 rationale on the secrets job) to avoid the literal substrings 'config auto' and 'gitleaks dir' that the plan's own negative-grep verify block checks for — RESEARCH's authoritative Code Examples block uses those exact substrings in its comments, so a byte-for-byte copy of that source text would have failed the plan's own verification step it was meant to satisfy"
  - "No .gitleaksignore change made — the smoke gate, re-run against both the pre-commit staged tree and the post-commit committed tree, produced the identical 9-finding list from 15-02-SUMMARY with nothing pointing at .github/workflows/security.yml; the embedded Gitleaks SHA-256 release checksum did not trigger a false positive"

requirements-completed: [CICD-01, SCA-04]

# Metrics
duration: 20min
completed: 2026-09-10
---

# Phase 15 Plan 03: Five Parallel Scan Jobs Summary

**Replaced the Phase 14 `placeholder` job in `security.yml` with five concurrent, SHA-pin-provenance-verified scan jobs (Semgrep, Checkov, Trivy filesystem, Trivy image, Gitleaks), each report-only at the step level while every tool keeps its native failing exit code.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-09-10T20:10:00-04:00 (approx, after reading plan/context)
- **Completed:** 2026-09-10T20:24:00-04:00 (approx, post-commit re-verification complete)
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Verified both new third-party action pins directly against the canonical org via `gh api` before writing any YAML — `aquasecurity/setup-trivy` tag `v0.3.1` and `bridgecrewio/checkov-action` tag `v12.3123.0` both resolved straight to a `commit`-type object matching the pinned SHA, no annotated-tag dereference needed
- Confirmed the Gitleaks v8.30.1 `linux_x64` release checksum (`551f6fc8...2470eb`) still matches the published checksums file before embedding it in the Install Gitleaks step
- Wrote five sibling jobs (`sast`, `iac`, `sca`, `container`, `secrets`) with zero `needs:` edges and zero job-level `continue-on-error`, each carrying a step-level `continue-on-error: true` on its tool invocation and an `if: always()` evidence `ls -l` step
- Passed `actionlint`, `yamllint -d relaxed`, and a full structural/negative-grep verification pass exactly as specified in the plan
- Re-ran `scripts/smoke-scans.sh` both before and after the commit — identical counts to the 15-02 baseline (Semgrep 3, Checkov 12, Trivy fs filtered 5, Trivy image filtered 56, Gitleaks 9), confirming the workflow file itself introduces no new findings
- Committed cleanly through the target repo's own `pre-commit run --all-files` gate with zero bypass

## Task Commits

Both tasks landed in a single commit, per the plan's design (Task 1 writes the file, Task 2 verifies and commits it):

1. **Task 1: Verify action-pin provenance, then replace the placeholder with five parallel scan jobs** - no separate commit (file staged, verified statically)
2. **Task 2: Re-run the smoke gate against the new workflow, clear the pre-push hooks, and commit** - `3e187a3` (feat)

**Plan metadata:** committed in the outer documentation repo (this commit)

## Files Created/Modified
- `repos/security-platform/.github/workflows/security.yml` - Replaced the single `placeholder` job with five sibling jobs (`sast`, `iac`, `sca`, `container`, `secrets`); envelope (lines 1-13) preserved verbatim with two appended header comment lines noting Phase 15 report-only status and the Phase 18 gate-mode pointer

## Decisions Made

See `key-decisions` in frontmatter. Summary:
- Single commit for both tasks (plan design, not a deviation)
- Two comments reworded to dodge the plan's own negative-grep verify strings (see Deviations below)
- `.gitleaksignore` left untouched — verified both pre- and post-commit

## Provenance Evidence

| Action | Tag | `gh api` result | Object type | Matches pin |
|---|---|---|---|---|
| `aquasecurity/setup-trivy` | `v0.3.1` | `81e514348e19b6112ce2a7e3ecbafe19c1e1f567` | `commit` | yes |
| `bridgecrewio/checkov-action` | `v12.3123.0` | `a8664e3a0549367977f0cda990a34311835c87c0` | `commit` | yes |

Gitleaks `gitleaks_8.30.1_linux_x64.tar.gz` checksum fetched live from `https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_checksums.txt`: `551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb` — matches the embedded pin exactly.

`actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` was already live in the file (Phase 14) and reused unchanged in all five jobs, per plan instruction.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reworded two inline comments that collided with the plan's own negative-grep verify strings**
- **Found during:** Task 1 verification (first run of the automated `<verify>` block)
- **Issue:** The plan's Task 1 verify block asserts `! grep -q 'config auto' "$W"` and `! grep -q 'gitleaks dir' "$W"` to prove the workflow never uses `--config auto` or `gitleaks dir` as live commands. RESEARCH's own authoritative Code Examples block (the plan's designated "THE authoritative command source") uses the exact substrings `--config auto is a hard error` and `` `gitleaks dir` finds zero `` in explanatory comments — meaning a byte-for-byte copy of the authoritative source text would fail the plan's own verify block against its own source.
- **Fix:** Reworded the sast job's comment from "`--config auto` is a hard error" to "the auto config value ... is a hard error" (word order flipped so the two words are no longer adjacent as `config auto`), and the secrets job's `fetch-depth: 0` comment from "`gitleaks dir` finds zero" to "the working-tree-only dir subcommand of gitleaks finds zero" (same substring-avoidance, same meaning preserved). No behavior or intent changed — only comment wording.
- **Files modified:** `repos/security-platform/.github/workflows/security.yml`
- **Verification:** Re-ran the full Task 1 `<verify>` block after the edit; all negative greps and the structural assertion passed, `actionlint` and `yamllint -d relaxed` both exited 0.
- **Committed in:** `3e187a3` (Task 2 commit — the fix landed before the first commit, so there is no separate fix commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Purely cosmetic wording fix required to satisfy the plan's own stated verification gate. No scope creep, no semantic or security-relevant change.

## Issues Encountered

None beyond the deviation above.

## Carried-Forward Notes for Later Phases

- **Pitfall 7 / severity-filter choice (Phase 17):** Both Trivy steps carry `--severity HIGH,CRITICAL`, which filters the report file content, not just the exit-code gate. This is intentional per D-04/A3 — it matches the reference workflow's native severity semantics so Phase 18 can flip gating back on unchanged. Phase 17 (DefectDojo import) must decide whether it wants full-severity data; if so, the fix is either dropping `--severity` from the report run and moving the threshold to a separate `--exit-code` gate, or adding a second full-severity run. Not changed in this plan.
- **Assumption A7 / Semgrep install fallback ladder:** The primary command `pip install semgrep==1.177.0` is in the workflow. The fallback ladder, recorded here for Plan 04 rather than discovered on the runner: (1) `pipx install semgrep==1.177.0` — pipx is preinstalled on `ubuntu-latest`; (2) `python -m pip install --break-system-packages semgrep==1.177.0` if PEP 668's externally-managed-environment guard blocks the plain `pip install`. This ladder is documented here, not embedded in the workflow, since the primary command has not yet been observed to fail in CI.
- **`versions.conf` split:** Confirmed untouched. It pins `TRIVY_VERSION="0.69.3"` / `GITLEAKS_VERSION="8.30.0"` for the workstation (generated by `workstation/setup.sh`); the CI pins in this workflow (Trivy `v0.74.0`, Gitleaks `8.30.1`) deliberately differ and remain unconverged, per 15-01's prior note. Whether to converge them is a later-phase decision.

## Measured Findings (this session)

| Tool | Command form | Exit | Count | vs 15-02 baseline |
|---|---|---|---|---|
| Semgrep | `semgrep scan --config p/default --metrics=off --error ...` | 1 | 3 | unchanged |
| Checkov | `checkov -d . --quiet --compact --output cli,json,sarif ...` | 1 | 12 (10 terraform + 2 dockerfile) | unchanged |
| Trivy fs (unfiltered, informational) | `trivy fs . --scanners vuln` | 0 | 9 | unchanged |
| Trivy fs (filtered, CI form) | `trivy fs . --scanners vuln --exit-code 1 --severity HIGH,CRITICAL` | 1 | 5 | unchanged |
| Docker build + Trivy image (filtered) | `docker build ...` + `trivy image ... --exit-code 1 --severity HIGH,CRITICAL` | 0 / 1 | 56 | unchanged |
| Gitleaks (sarif + json) | `gitleaks git . --no-banner --redact ...` | 1 / 1 | 9 findings, identical RuleID+File+StartLine list to 15-02, re-verified against the post-commit tree | unchanged, no new finding on `security.yml` |

Smoke gate (`scripts/smoke-scans.sh`) exited 0 on both the pre-commit (staged) and post-commit (committed) runs. `pre-commit run --all-files` from inside `repos/security-platform` exited 0 on both runs, with no `--no-verify` and no `SKIP=`.

## User Setup Required

None - no external service configuration required. The branch remains local-only (`feature/phase-15-five-parallel-scan-jobs` in `repos/security-platform`), now 4 commits ahead of `origin/main`, unpushed.

## Next Phase Readiness

- Plans 04-05 have a real five-job workflow to observe running concurrently and to extend
- Phase 17 can widen this file for SARIF/artifact upload without restructuring the job graph
- Phase 18 can flip gate mode by removing the step-level `continue-on-error` flags — no tool-invocation rewrite needed
- No blockers. `git -C repos/security-platform rev-list --count origin/main..HEAD` = 4.

---
*Phase: 15-five-parallel-scan-jobs*
*Completed: 2026-09-10*

## Self-Check: PASSED

- `repos/security-platform/.github/workflows/security.yml` exists and contains five job ids (`sast`, `iac`, `sca`, `container`, `secrets`), no `placeholder` string.
- Commit `3e187a3` found in `repos/security-platform` git log.
- `.planning/phases/15-five-parallel-scan-jobs/15-03-SUMMARY.md` (this file) exists on disk.
- `git -C repos/security-platform status --porcelain` is empty.
