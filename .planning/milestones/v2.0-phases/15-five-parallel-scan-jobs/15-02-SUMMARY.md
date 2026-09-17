---
phase: 15-five-parallel-scan-jobs
plan: 02
subsystem: infra
tags: [semgrep, checkov, trivy, gitleaks, docker, bash, ci-validation]

# Dependency graph
requires:
  - phase: 15-01
    provides: "fixtures/ tree with real, non-zero findings for IaC, container and SCA scan jobs"
provides:
  - "repos/security-platform/scripts/smoke-scans.sh — reusable local pass/fail gate for all five Phase 15 CI scan jobs"
  - "Empirically-verified flag sets and exit-code semantics for Semgrep, Checkov, Trivy fs, Trivy image, Gitleaks before they are embedded in workflow YAML (Plans 03-05)"
  - "SCA-04 evidence: unfiltered generic trivy fs sweep reports npm vulnerabilities in fixtures/package-lock.json with zero per-ecosystem configuration"
  - "Checkov 3.3.17 (the CI action's pinned version) confirmed to honor the same comma-mapped --output-file-path filenames as local Checkov 3.2.396 (Assumption A6 resolved)"
affects: [15-03, 15-04, 15-05, 16, 18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "run_scan / require_success dual-helper pattern: scanners whose PASS condition is exit==1 (a real finding) use one helper; infrastructure steps whose PASS condition is exit==0 (docker build, trivy convert) use a distinct helper. Conflating the two inverts the pass/fail verdict."
    - "FAILURES=() initialised and always guarded behind `[ \"${#FAILURES[@]}\" -gt 0 ]` before array expansion — required for macOS bash 3.2 `set -u` compatibility on the empty-array (all-pass) path"

key-files:
  created:
    - repos/security-platform/scripts/smoke-scans.sh
  modified: []

key-decisions:
  - "Corrected a self-introduced bug before commit: docker build and trivy convert expect exit 0 as PASS, the inverse of the five real scanners (exit 1 = PASS). Using the scanner helper (run_scan) on these two steps silently flipped a real docker-build failure into a false PASS during first local test run. Added a distinct require_success helper and re-verified."
  - "Added a docker-build success guard around the Trivy image step: if the build fails, trivy image is skipped (rather than run against a stale/absent image and falsely reported as PASS) and both are recorded as failures."
  - "Confirmed the one Gitleaks finding outside .planning/ (discord-api-token in .claude/gsd-file-manifest.json, historical commit 2dd8fb8) is a false-positive regex match on a SHA-256 hex hash in a GSD file manifest, not a credential — verified against primary source (git show) before concluding it is not an active incident."

requirements-completed: [CICD-01, SCA-04]

# Metrics
duration: 25min
completed: 2026-09-10
---

# Phase 15 Plan 02: Local Five-Scanner Smoke Gate Summary

**Built `scripts/smoke-scans.sh`, a self-contained pass/fail gate that runs the exact CI-shaped Semgrep, Checkov, Trivy filesystem, Trivy image, and Gitleaks invocations against the real checkout and proves all five produce genuine, non-empty findings before any of them is embedded in workflow YAML.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-10T23:30:00Z (approx, after reading plan/context)
- **Completed:** 2026-09-10T23:55:00Z (approx, Checkov 3.3.17 verification + final clean check)
- **Tasks:** 2
- **Files modified:** 1 (created)

## Accomplishments
- Authored `scripts/smoke-scans.sh` in the target repo: preflight binary check, `mktemp -d` report directory with `EXIT` trap, `rc=0; cmd || rc=$?` exit-code capture (never `|| true`), and a `FAILURES` array gated for macOS bash 3.2 `set -u` safety
- All five CI-shaped scanner invocations verified locally to produce real, non-empty findings: Semgrep (3), Checkov (12), Trivy fs filtered (5), Trivy image filtered (56), Gitleaks (9)
- SCA-04 evidence captured: `fixtures/package-lock.json` is the sole Trivy fs `Target` carrying vulnerabilities, with zero per-ecosystem configuration in the scan command
- Confirmed no `no longer supported by the distribution` warning in Trivy image output (fixture base image remains non-EOL)
- Verified Assumption A6: Checkov 3.3.17 (the exact image the CI `bridgecrewio/checkov-action` runs) writes the same two files (`checkov-results.json`, `checkov.sarif`) under the identical comma-mapped `--output-file-path` syntax as local Checkov 3.2.396 — no filename drift for Plan 03 to account for
- Enumerated all 9 Gitleaks findings (RuleID + File + StartLine only, no secret values) for Open Question Q1

## Task Commits

Each task was committed atomically in `repos/security-platform`:

1. **Task 1: Author scripts/smoke-scans.sh as a pass/fail gate over all five scanners** - `532db3f` (test)
2. **Task 2: Run the smoke gate and record measured evidence for all five tools** - no commit (read-only verification task; no files changed)

**Plan metadata:** committed in the outer documentation repo (this commit)

## Files Created/Modified
- `repos/security-platform/scripts/smoke-scans.sh` - Local five-scanner smoke gate. Shellcheck-clean, non-executable, `bash -n`-valid. Runs Semgrep (`--config p/default --metrics=off --error`), Checkov (`cli`+`json`+`sarif` via comma-mapped `--output-file-path`), Trivy fs (unfiltered record-only + `--severity HIGH,CRITICAL --exit-code 1` gated), Trivy image (build + `--severity HIGH,CRITICAL --exit-code 1` + EOL-string grep), and Gitleaks (`git` mode, sarif + json, `--redact`)

## Decisions Made

See `key-decisions` in frontmatter. Summary:
- Split scanner-verdict logic (`run_scan`, PASS on exit 1) from infrastructure-step logic (`require_success`, PASS on exit 0) — the plan's `<notes>` warned about the `set -e` trap but the actual bug found live-testing was more specific: applying the wrong helper to `docker build`/`trivy convert` inverts their verdict.
- Guarded the Trivy image step behind a successful docker build, so a build failure cannot cascade into a false "trivy-image PASS" against a stale or nonexistent image.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed inverted exit-code semantics for docker build and trivy convert**
- **Found during:** Task 2 (first live run of the script, before commit)
- **Issue:** The plan's `<action>` described a single `run_scan` helper (PASS = exit 1) applied uniformly. Applying it to `docker build` and `trivy convert` — both of which signal success via exit 0 — inverted their verdicts. In the first live run, Docker Desktop hit a transient `unable to lease content: lease does not exist` error on `docker build` (exit 1); `run_scan` logged this as `PASS`, and the subsequent Trivy image scan against the nonexistent image also exited 1 (image-not-found error) and was likewise logged as `PASS`. Only the report-emptiness check caught the resulting missing files.
- **Fix:** Added a `require_success` helper (PASS = exit 0, used for `trivy convert` on both fs and image paths) and a docker-build-specific inline check with the same exit-0-is-PASS semantics; gated the entire Trivy image step behind a successful docker build so a build failure is recorded once and does not cascade into a misleading scanner verdict.
- **Files modified:** `repos/security-platform/scripts/smoke-scans.sh`
- **Verification:** Re-ran the full script twice — once confirming the transient Docker Desktop error was not reproducible (`docker build` succeeded standalone), then a clean full run of `smoke-scans.sh` exiting 0 with all five scanners correctly verdicted.
- **Committed in:** `532db3f` (Task 1 commit — the fix landed before the first commit, so there is no separate fix commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The fix was necessary for the gate to be a real assertion rather than a decorative one — an inverted verdict on the container job is exactly the "empty report reads as clean" failure mode Success Criteria #2 exists to prevent. No scope creep; the helper split stayed within `scripts/smoke-scans.sh`.

## Issues Encountered
- First `docker build -f fixtures/Dockerfile` invocation hit a transient Docker Desktop error (`unable to lease content: lease does not exist: not found`) unrelated to the fixture or script. Confirmed transient by re-running standalone (succeeded immediately, image layer was cached). No script or fixture change needed; documented here per the anti-slop "confusion response" protocol since it briefly looked like a real regression until isolated.
- `ghcr.io/bridgecrewio/checkov:3.3.17` was not present locally; had to `docker pull` explicitly (~40s) before the Assumption A6 verification `docker run` would proceed — no functional issue, just added latency.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plans 03-05 can embed the exact flag sets proven here (`semgrep scan --config p/default --metrics=off --error`, the Checkov comma-mapped `--output-file-path`, both `trivy fs` invocations, `trivy image` + convert, and `gitleaks git`) directly into workflow YAML with empirical confidence.
- Plan 03's `ls -l` evidence step for the IaC job can reference `checkov-results.json` and `checkov.sarif` without adjustment — Checkov 3.3.17 produces identical filenames to the local 3.2.396 install.
- No blockers. The branch remains local-only (`feature/phase-15-five-parallel-scan-jobs` in `repos/security-platform`), unpushed, consistent with the Phase 14/15-01 pattern.

## Measured Findings (this session)

| Tool | Command form | Exit | Result |
|---|---|---|---|
| Semgrep | `semgrep scan --config p/default --metrics=off --error --json-output=... --sarif-output=...` | 1 | 3 findings: `dependabot-missing-cooldown` (`.github/dependabot.yml`), `gha-curl-pipe-shell` (`cicd/.github/workflows/security.yml`), `dockerfile.security.missing-user` (`fixtures/Dockerfile`) |
| Checkov | `checkov -d . --quiet --compact --output cli --output json --output sarif --output-file-path console,...,...` | 1 | `summary.failed`: terraform=10, dockerfile=2, gitlab_ci=0, github_actions=0, azure_pipelines=0 — total 12 |
| Trivy fs (unfiltered) | `trivy fs . --scanners vuln --format json -o ...` | 0 (not gated) | 9 vulnerabilities total, target `fixtures/package-lock.json` |
| Trivy fs (filtered, CI form) | `trivy fs . --scanners vuln --format json -o ... --exit-code 1 --severity HIGH,CRITICAL` | 1 | 5 HIGH/CRITICAL vulnerabilities, target `fixtures/package-lock.json` |
| Docker build | `docker build -f fixtures/Dockerfile -t scan-fixture:smoke fixtures/` | 0 | Image built (debian 12.15 base) |
| Trivy image (filtered) | `trivy image scan-fixture:smoke --scanners vuln --format json -o ... --exit-code 1 --severity HIGH,CRITICAL` | 1 | 56 HIGH/CRITICAL vulnerabilities; no `no longer supported by the distribution` warning |
| Gitleaks (sarif + json) | `gitleaks git . --no-banner --redact --report-format {sarif,json} --report-path ...` | 1 | 9 findings (see below) |
| Checkov 3.3.17 (Assumption A6) | `docker run ... ghcr.io/bridgecrewio/checkov:3.3.17 -d /tf --quiet --compact --output cli --output json --output sarif --output-file-path console,/out/checkov-results.json,/out/checkov.sarif` | 1 | Same finding counts (10 terraform + 2 dockerfile = 12) and same two filenames produced, non-empty. No filename drift vs local 3.2.396. |

**SCA-04 evidence (verbatim):** The Trivy fs `Results[].Target` list for both the unfiltered and `HIGH,CRITICAL`-filtered runs contains exactly one entry carrying vulnerabilities: `fixtures/package-lock.json`. No `.trivyignore`, per-ecosystem plugin, or npm-specific configuration exists anywhere in the scan command or the repo — the generic `trivy fs . --scanners vuln` sweep discovered and scanned the npm lockfile automatically.

### Gitleaks findings — Open Question Q1 (user confirmation requested)

Redacted values only (`--redact` applied on every invocation); no secret value appears in this file, the terminal transcript, or any committed artifact.

| # | RuleID | File | StartLine | In `.planning/`? |
|---|---|---|---|---|
| 1 | aws-access-token | `.planning/STATE.md` | 82 | yes |
| 2 | aws-access-token | `.planning/phases/05-secrets-detection-gate/05-VERIFICATION.md` | 26 | yes |
| 3 | aws-access-token | `.planning/phases/05-secrets-detection-gate/05-VERIFICATION.md` | 60 | yes |
| 4 | aws-access-token | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 26 | yes |
| 5 | aws-access-token | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 70 | yes |
| 6 | aws-access-token | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 80 | yes |
| 7 | aws-access-token | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 92 | yes |
| 8 | aws-access-token | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 93 | yes |
| 9 | discord-api-token | `.claude/gsd-file-manifest.json` (historical commit `2dd8fb8`, file no longer present in the working tree) | 114 | **no** |

**Please confirm findings 1-8 are the Phase-05 secrets-detection-gate test strings referenced in Assumption A4** (this repo's own earlier GSD phase that built the secrets-detection tooling, not a live AWS credential).

**Finding 9 was investigated directly** (per the plan's explicit STOP condition for anything outside `.planning/`): `git show 2dd8fb8:.claude/gsd-file-manifest.json` at line 114 shows `"commands/gsd/autonomous.md": "817528d44c8ec31812e2ea9f8c1c770d3ed3d6752561af18068e56504c070308"` — a SHA-256 hex checksum in a GSD file-integrity manifest, matched by Gitleaks' `discord-api-token` regex (which looks for long hex-like tokens) as a false positive. This is not a credential of any kind and does not represent an active incident. No STOP was warranted once the primary source was checked.

**Carried forward to Phase 18:** gate mode will block on these 9 history findings. The remedy is a `--baseline-path` or fingerprint-form `.gitleaksignore` entries (`file:rule-id:start-line` — path globs are not valid), per Assumption A4/RESEARCH C-3.

---
*Phase: 15-five-parallel-scan-jobs*
*Completed: 2026-09-10*

## Self-Check: PASSED

- `repos/security-platform/scripts/smoke-scans.sh` exists on disk.
- `.planning/phases/15-five-parallel-scan-jobs/15-02-SUMMARY.md` (this file) exists on disk.
- Task 1 commit `532db3f` found in `repos/security-platform` git log.
- No commit expected for Task 2 (read-only verification task, no files changed) — confirmed `git -C repos/security-platform status --porcelain` is empty.
