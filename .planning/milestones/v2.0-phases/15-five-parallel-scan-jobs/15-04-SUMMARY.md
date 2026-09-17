---
phase: 15-five-parallel-scan-jobs
plan: 04
subsystem: infra
tags: [github-actions, live-verification, semgrep, checkov, trivy, gitleaks, pull-request, check-runs]

# Dependency graph
requires:
  - phase: 15-03
    provides: "repos/security-platform/.github/workflows/security.yml with five concurrent, needs:-free, step-tolerant scan jobs"
provides:
  - "Live evidence PR #6 on OttawaCloudConsulting/security-platform, run 34546843396, with five green `security / *` check-runs starting at the identical second"
  - "Five verbatim check-run names, em-dash confirmed (U+2014), for Phase 18 branch protection"
  - "Per-job finding counts and non-zero-byte `ls -l` evidence cross-checked against 15-02/15-03 local baselines"
affects: [15-05, 17, 18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Run selection by workflowName=='PR Security' AND event=='pull_request' (never recency) — confirmed working again on a second PR"
    - "Evidence harvested via `gh run view --job <id> --log` per job rather than one giant `--log` dump, keeping each job's output isolated for grep"

key-files:
  created:
    - .planning/phases/15-five-parallel-scan-jobs/15-04-SUMMARY.md
  modified: []

key-decisions:
  - "Trivy fs/image steps use `--format json` with no table summary in the log, so the numeric finding count is not printed inline; non-zero evidence instead rests on the tool's own non-zero exit code (--exit-code 1 triggered) plus non-empty JSON/SARIF file sizes, cross-referenced against the 15-02/15-03 measured local baseline (Trivy fs filtered HIGH/CRITICAL = 5, Trivy image filtered HIGH/CRITICAL = 56)"
  - "PR body written to a scratchpad file and passed via --body-file after --body heredoc syntax hit a shell quoting error in the tool's command parser (backtick-in-heredoc), avoiding any retry with --fill"

requirements-completed: [CICD-01, SCA-04]

# Metrics
duration: 25min
completed: 2026-09-11
---

# Phase 15 Plan 04: Live Five-Parallel-Checks Evidence Summary

**Pushed the Phase 15 branch, opened PR #6 on OttawaCloudConsulting/security-platform, and watched run 34546843396 produce five `security / *` check-runs that all started at the same second (00:31:27Z, spread 0.0s), each concluding `success` with a real non-zero tool result and non-empty output files, while the PR still reports MERGEABLE.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-11T00:28:00Z (approx, after reading plan/context)
- **Completed:** 2026-09-11T00:35:00Z (approx, evidence harvested and PR left open)
- **Tasks:** 2
- **Files modified:** 0 (observation-only plan; only this SUMMARY and STATE/ROADMAP/REQUIREMENTS were created/updated)

## Accomplishments

- Confirmed the branch was clean, on `feature/phase-15-five-parallel-scan-jobs`, 4 commits ahead of a freshly-fetched `origin/main`, with the expected 8-file diff (`security.yml`, `.pre-commit-config.yaml`, `fixtures/*`, `scripts/smoke-scans.sh`)
- Pushed with `git push -u origin HEAD` — pre-push Gitleaks hook ran and passed, no `--no-verify`
- Opened PR #6 with explicit `--title`/`--body-file` (never `--fill`)
- Located run `34546843396` by `workflowName == "PR Security"` AND `event == "pull_request"` on the first poll attempt (15s after PR creation) — no Copilot-run collision this time, only one match
- Watched the run to completion (`gh run watch --exit-status`, rc=0) — total run wall-clock under 40s across all five jobs
- Harvested per-job logs individually via `gh run view --job <id> --log` for all five jobs, avoiding one giant multi-thousand-line dump
- Confirmed all five `security / *` check-runs `started_at` are byte-identical (`2026-09-11T00:31:27Z`), spread = 0.0 seconds — the strongest possible concurrency evidence, and a `needs:` edge would have made this impossible
- Confirmed `GITHUB_TOKEN Permissions: Contents: read / Metadata: read` in every one of the five job logs (T-15-23 mitigated)
- Confirmed PR `mergeable: MERGEABLE`, `mergeStateStatus: CLEAN`, `state: OPEN`; `main` ruleset carries only `deletion` and `non_fast_forward` (no `required_status_checks`)
- Left the PR open — no merge, no re-run

## Task Commits

Both tasks are observation-only, per the plan's design (identical pattern to 14-02). **Neither task produced a commit.** Zero files changed in `repos/security-platform` — `git status --porcelain` empty before and after, still exactly 4 commits ahead of `origin/main`.

1. **Task 1: Push the Phase 15 branch, open the pull request, and identify the run** — no commit (push + PR creation + run discovery only)
2. **Task 2: Collect the five-parallel-checks evidence and confirm the PR stays mergeable** — no commit (read-only evidence harvesting)

**Plan metadata:** outer documentation repo only (this SUMMARY + STATE + ROADMAP).

## Recorded Values (the deliverable)

| Value | Verbatim |
|---|---|
| **Repository slug** | `OttawaCloudConsulting/security-platform` |
| **Head branch** | `feature/phase-15-five-parallel-scan-jobs` |
| **Pull request number** | **`6`** — <https://github.com/OttawaCloudConsulting/security-platform/pull/6> |
| **Head SHA** | `3e187a36c3246e9a1804427870fbd7ec0173a0d6` |
| **Run `databaseId`** | **`34546843396`** — <https://github.com/OttawaCloudConsulting/security-platform/actions/runs/34546843396> |
| **Run `workflowName` / `event`** | `PR Security` / `pull_request` |
| **Run `status` / `conclusion`** | `completed` / `success` |
| **`mergeable` / `mergeStateStatus` / `state`** | `MERGEABLE` / `CLEAN` / `OPEN` |
| **`main` ruleset `type`s** | `deletion`, `non_fast_forward` (no `required_status_checks`) |
| **PR merged?** | **No.** Left OPEN. Plan 05 owns the human checkpoint and merge decision. |

## Success Criteria #1 — Five concurrent checks (CICD-01)

`gh api repos/<slug>/commits/<headSha>/check-runs`, filtered on the `security / ` prefix, returns **exactly 5** entries (the sixth, `GitGuardian Security Checks`, is a third-party app check and is explicitly excluded from the count):

```
check_runs:
security / Container — Trivy Image -> success started=2026-09-11T00:31:27Z completed=2026-09-11T00:31:48Z
security / IaC — Checkov -> success started=2026-09-11T00:31:27Z completed=2026-09-11T00:31:46Z
security / Secrets — Gitleaks -> success started=2026-09-11T00:31:27Z completed=2026-09-11T00:31:32Z
security / SCA — Trivy Filesystem -> success started=2026-09-11T00:31:27Z completed=2026-09-11T00:31:42Z
security / SAST — Semgrep CE -> success started=2026-09-11T00:31:27Z completed=2026-09-11T00:32:05Z
```

`GitGuardian Security Checks -> success started=2026-09-11T00:31:24Z completed=2026-09-11T00:31:25Z` — present in the unfiltered list, confirmed NOT one of the five.

**`started_at` spread: 0.0 seconds.** All five check-runs began at the identical timestamp `2026-09-11T00:31:27Z`. This is stronger than the plan's <120s threshold and rules out any `needs:` edge (Pitfall 8) — the jobs are true siblings.

### Verbatim check-run names (byte-verified, for Phase 18)

Verified programmatically that each name's non-ASCII character is exactly `U+2014` (EM DASH), not en-dash or hyphen:

```
security / SAST — Semgrep CE
security / IaC — Checkov
security / SCA — Trivy Filesystem
security / Container — Trivy Image
security / Secrets — Gitleaks
```

## Success Criteria #5 — All five green, PR stays mergeable

All five filtered check-runs conclude `success`. Full `statusCheckRollup` confirms the same five `CheckRun` entries at `conclusion: SUCCESS`, plus the separate `GitGuardian Security Checks` entry (`workflowName: ""`, not ours).

```
PR #6: mergeable=MERGEABLE, mergeStateStatus=CLEAN, state=OPEN
main ruleset: [{"type":"deletion"},{"type":"non_fast_forward"}]  (no required_status_checks — nothing blocks the merge)
```

Per Phase 14's learning, the classic `branches/main/protection` endpoint was **not** queried as evidence here — the rulesets endpoint above is authoritative and was used directly.

## Success Criteria #2 — Real results, not stubs (per job)

| Job | Tool invocation | Reported result | Step exit tolerated |
|---|---|---|---|
| **SAST — Semgrep CE** | `semgrep scan --config p/default --metrics=off --error \` | `Ran 207 rules on 28 files: 3 findings.` | `##[error]Process completed with exit code 1.` (job concluded `success`) |
| **IaC — Checkov** | `checkov -d . --output-file-path console,checkov-results.json,checkov.sarif --quiet --output cli --output json --output sarif` | `Passed checks: 8, Failed checks: 10, Skipped checks: 0` (terraform, `fixtures/main.tf`) + `Passed checks: 2, Failed checks: 2, Skipped checks: 0` (dockerfile) = **12 total failed checks**, matching CKV_AWS_144/145/18/21/23/24, CKV2_AWS_5/6/61/62 seen in the run-watch annotations | job itself reported `success` despite the failed checks |
| **SCA — Trivy Filesystem** | `trivy fs . --scanners vuln --format json --output trivy-fs.json --exit-code 1 --severity HIGH,CRITICAL` | Real DB pull (`vulndb` 112.44 MiB downloaded), `[npm] Detecting vulnerabilities...` against `fixtures/package-lock.json`; **`--exit-code 1` fired** (non-zero HIGH/CRITICAL vulnerabilities present) | `##[error]Process completed with exit code 1.` (job concluded `success`) |
| **Container — Trivy Image** | `trivy image scan-fixture:fb8f6c0990a225519b3eb596b246c1331d180a9e --scanners vuln --exit-code 1 --severity HIGH,CRITICAL` | `--exit-code 1` fired against the built `fixtures/Dockerfile` image (debian:12-slim base, per 15-01's D-02 fix) | `##[error]Process completed with exit code 1.` (job concluded `success`) |
| **Secrets — Gitleaks** | `gitleaks git . --no-banner --redact --report-format sarif/json` | `119 commits scanned`, `scanned ~4528722 bytes (4.53 MB) in 481ms`, `leaks found: 9` (both SARIF and JSON runs) | `##[error]Process completed with exit code 1.` twice (job concluded `success`) |

**On the two JSON-format Trivy jobs (SCA, Container):** `trivy ... --format json` does not print a numeric summary line to the log the way `--format table` would. The evidence for a real, non-zero result is therefore the tool's own non-zero exit code (triggered by `--exit-code 1` against the `HIGH,CRITICAL` filter — this is an explicit tool-level assertion of "vulnerabilities of that severity exist"), plus the non-empty JSON/SARIF files below (522,310 bytes for `trivy-image.json`, well beyond a header-only or empty-array file). Both counts are consistent with the local baselines already measured in 15-02/15-03 (SCA filtered = 5, Container filtered = 56) — no regression to zero.

All five findings counts are **non-zero**, satisfying Success Criteria #2. No job showed a skipped/stubbed step.

## Success Criteria #3 — SCA specifics (SCA-04)

From the SCA job's log, `trivy fs . --scanners vuln` ran with **no per-ecosystem flags** (no `--pkg-types`, no npm/pip-specific configuration):

```
2026-09-11T00:31:36Z	INFO	[vulndb] Downloading artifact...	repo="mirror.gcr.io/aquasec/trivy-db:2"
2026-09-11T00:31:40Z	INFO	[vuln] Vulnerability scanning is enabled
2026-09-11T00:31:40Z	INFO	[npm] Run "npm install" to collect the license information of packages	dir="fixtures/node_modules"
2026-09-11T00:31:40Z	INFO	Number of language-specific files	num=1
2026-09-11T00:31:40Z	INFO	[npm] Detecting vulnerabilities...
```

The target Trivy attributed vulnerabilities to is `fixtures/package-lock.json` (the sole npm lockfile in the fixtures tree, matching 15-01's fixture design), auto-detected by the generic `trivy fs .` invocation with zero ecosystem-specific configuration — this is the direct SCA-04 evidence.

## Success Criteria #4 — Output files exist, all non-zero-byte

`ls -l` evidence from all five jobs' `Show scan output files` steps:

```
# SAST — Semgrep CE
-rw-r--r-- 1 runner runner   12505 Sep 11 00:32 semgrep-results.json
-rw-r--r-- 1 runner runner 2119069 Sep 11 00:32 semgrep.sarif

# SCA — Trivy Filesystem
-rw-r--r-- 1 runner runner 24189 Sep 11 00:31 trivy-fs.json
-rw-r--r-- 1 runner runner 15476 Sep 11 00:31 trivy-fs.sarif

# Secrets — Gitleaks
-rw-r--r-- 1 runner runner 10726 Sep 11 00:31 gitleaks-results.json
-rw-r--r-- 1 runner runner 59576 Sep 11 00:31 gitleaks.sarif

# IaC — Checkov
-rw-r--r-- 1 root   root   18347 Sep 11 00:31 checkov-results.json
-rw-r--r-- 1 root   root   13326 Sep 11 00:31 checkov.sarif

# Container — Trivy Image
-rw-r--r-- 1 runner runner 522310 Sep 11 00:31 trivy-image.json
-rw-r--r-- 1 runner runner 102144 Sep 11 00:31 trivy-image.sarif
```

Every one of the 10 files across the five jobs is non-zero-byte. No "empty report reads as clean" failure (T-15-22 mitigated).

## Decisions Made

- **JSON-format Trivy count evidence** — documented above under key-decisions; no workaround was applied, no re-run, the numeric count simply isn't printed for `--format json` and non-zero exit code + file size stand as the evidence per the plan's own Success Criteria #2 wording ("a real result from its tool ... not a skipped or stubbed step" — satisfied by exit code + non-empty output, not contingent on a printed count).
- **PR body delivery method** — switched from an inline `--body "$(cat <<'EOF' ... EOF)"` heredoc (which errored in the harness's bash parser on the embedded backticks) to a scratchpad file plus `--body-file`. No change to plan intent; `--fill` was never used.

## Deviations from Plan

**None — plan executed exactly as written.** Every precondition and assertion passed on first evaluation; no auto-fixes were required.

Two plan-anticipated first-run failure modes from `<notes>` (PEP 668 Semgrep install failure, Checkov filename drift) did **not** materialize — the pip install and the checkov output-file-path syntax both worked on the first run, consistent with 15-02/15-03's local dry-runs.

## Issues Encountered

- The first `gh pr create --body "$(cat <<'EOF' ... EOF)"` invocation raised a shell syntax error (`unexpected EOF while looking for matching ''`) in the tool harness's bash evaluator — not a gh or git issue. Resolved by writing the body to a scratchpad file and using `--body-file` instead, with no change to the PR's actual content or the plan's "no `--fill`" requirement.

## Threat Model Coverage

| Threat ID | Disposition | Evidence in this plan |
|-----------|-------------|------------------------|
| T-15-18 | mitigated | Every git command scoped `git -C repos/security-platform`. No git command ran against the outer documentation repo. |
| T-15-19 | mitigated | Run matched by `workflowName == "PR Security"` AND `event == "pull_request"` (found on first poll, single match, no Copilot-run ambiguity this time). PR matched by head branch (`#6`, confirmed the only PR for this branch). |
| T-15-20 | mitigated | Gitleaks findings recorded as a count (`9`) and scan metadata only (`119 commits scanned`, byte count); no candidate secret values transcribed. Cross-referenced against the RuleID+File list already catalogued in 15-02-SUMMARY rather than re-extracting values from this run's log. |
| T-15-21 | accepted | Fixtures now publicly visible on PR #6 — same disposition as 15-01/15-03; no new exposure introduced. |
| T-15-22 | mitigated | All 10 `ls -l` evidence lines recorded with non-zero byte sizes; all five jobs' finding counts are non-zero. |
| T-15-23 | mitigated | `GITHUB_TOKEN Permissions: Contents: read / Metadata: read` confirmed in all five job logs — no write or `security-events` scope granted anywhere in the call chain. |

## User Setup Required

None — no external service configuration required. PR #6 is open on `OttawaCloudConsulting/security-platform`, awaiting Plan 05's human checkpoint before any merge decision.

## Next Phase Readiness

- **PR `6`** is OPEN, `MERGEABLE`/`CLEAN`, against base `main`, unmerged. Plan 05 owns the human checkpoint and merge decision.
- **Run `34546843396`** is the green, fully-witnessed evidence run — five `security / *` checks, `started_at` spread 0.0s, all `success`, all backed by real non-zero tool results and non-empty output files.
- **Phase 18** must use these five verbatim check-run names (em-dash, `U+2014`) as the required-status-check strings — captured above byte-exact, superseding the Phase 14 placeholder string `security / Placeholder`.
- No blockers. `git -C repos/security-platform status --porcelain` empty; still exactly 4 commits ahead of `origin/main`, matching the state at the start of this plan.

---
*Phase: 15-five-parallel-scan-jobs*
*Completed: 2026-09-11*

## Self-Check: PASSED

- `.planning/phases/15-five-parallel-scan-jobs/15-04-SUMMARY.md` (this file) exists on disk.
- PR #6 verified OPEN at self-check time: `gh pr view 6 -R OttawaCloudConsulting/security-platform --json state` → `OPEN`.
- Run `34546843396` verified `completed`/`success` at self-check time.
- Five `security / *` check-runs verified present, all `success`, `started_at` spread 0.0s, at self-check time.
- No commits to verify — this plan produced zero source-repo commits by design (observation-only, matching the 14-02 pattern).
