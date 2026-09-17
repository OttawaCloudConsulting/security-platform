---
phase: 15-five-parallel-scan-jobs
plan: 05
subsystem: infra
tags: [github-actions, pull-request, merge, dependabot, vulnerability-alerts]

# Dependency graph
requires:
  - phase: 15-04
    provides: "Live evidence PR #6 on OttawaCloudConsulting/security-platform, run 34546843396, five green security / * checks with started_at spread 0.0s"
provides:
  - "MERGED: PR #6 merged to OttawaCloudConsulting/security-platform main via --merge, commit e8e10091746522d1933585f3ba8709e818b62315"
  - "origin/main confirmed carrying the five-job security.yml (no needs:), fixtures/, .pre-commit-config.yaml exclusions, and scripts/smoke-scans.sh"
  - "Open Question Q3 closed: Dependabot alerts are disabled on this repository (404 on vulnerability-alerts; 403 'Dependabot alerts are disabled for this repository' from dependabot/alerts)"
  - "Five verbatim check-run names re-read from the merged run for Phase 18's required-status-check configuration"
  - "Carried-forward open items handed to Phases 16, 17, 18 individually"
affects: [16, 17, 18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Post-merge verification reads origin/main via git show origin/main:<path> rather than trusting the local working tree, per T-15-25"
    - "A 404 on a probe endpoint is a measured answer (feature disabled), not a failure requiring escalation or retry"

key-files:
  created:
    - .planning/phases/15-five-parallel-scan-jobs/15-05-SUMMARY.md
  modified: []

key-decisions:
  - "Merge used gh pr merge 6 -R \"$SLUG\" --merge with no --delete-branch flag, to avoid gh's local-branch side effects acting on the outer documentation repo (which shares the remote URL but is a separate checkout on a different branch with unrelated uncommitted changes)"
  - "Remote feature branch feature/phase-15-five-parallel-scan-jobs was left in place on the remote (not auto-deleted by the merge, and the plan scopes cleanup to the LOCAL branch only) — noted as a minor, non-blocking loose end rather than pushed as a deletion outside plan scope"
  - "D-02 and D-03 were implemented in their RESEARCH-corrected forms (C-1, C-2, C-3), not their literal CONTEXT.md wording — restated here so a later reader does not mistake this for undocumented drift"

requirements-completed: [CICD-01]

# Metrics
duration: 20min
completed: 2026-09-11
---

# Phase 15 Plan 05: Human Sign-Off and Merge to Main Summary

**PR #6 merged to `OttawaCloudConsulting/security-platform` main via `--merge` (commit `e8e1009`), `origin/main` verified to carry the five-job `security.yml`, fixtures, hook exclusions and smoke script, and Open Question Q3 closed: Dependabot alerts are disabled on this repository.**

## Performance

- **Duration:** ~20 min (Task 2 only — Task 1 was a prior-session checkpoint)
- **Started:** 2026-09-11T00:45:00Z (approx, after loading plan/context)
- **Completed:** 2026-09-11T00:55:00Z (approx)
- **Tasks:** 2 (Task 1 human checkpoint, completed in a prior turn; Task 2 auto, completed this session)
- **Files modified:** 0 in `repos/security-platform` this session (the merge itself lands the 8-file diff already authored in 15-03; this plan is merge + observation only). Outer repo: this SUMMARY + STATE/ROADMAP/REQUIREMENTS.

## Task 1 — Human Confirmation (completed prior to this session)

Task 1 is a `gate="blocking"` checkpoint. The user's two responses, recorded verbatim, are the sole authority for everything Task 2 does:

**Response 1 (verbatim):** "I confirm the trivy jobs shows failed, but the job is green"
— This answers `<how-to-verify>` step 4: confirmation that the scan step is annotated as failed while the job as a whole stays green — the report-only (D-04) behaviour working as designed. It confirms only that specific observation; it does not on its own constitute the merge decision.

**Response 2 (verbatim):** "approved"
— Given after the user was asked explicitly to confirm the five checks ran concurrently, the PR's mergeable state, and that the Gitleaks history strings are confirmed fake test data (Assumption A4) — immediately before merging. Per the plan's `<resume-signal>`, `approved` means: the five checks are concurrent, findings are visible, the PR is mergeable, the Gitleaks strings are confirmed fake, and the merge should proceed.

Both responses together satisfy the plan's requirement that the user directly observed the concurrency and report-only behaviour on GitHub, ruled on the Gitleaks findings, and gave an explicit merge decision. Nothing was merged, closed, or pushed before response 2 arrived.

## Task 2 — Merge, Verify Main, Close Open Questions

Since the recorded decision was `approved`, all seven action steps were executed.

### 1. Merge

```
gh pr merge 6 -R OttawaCloudConsulting/security-platform --merge
```

No `--delete-branch` flag was used (deliberate — see Decisions Made). Result:

| Field | Value |
|---|---|
| PR state | `MERGED` |
| Merge commit SHA | `e8e10091746522d1933585f3ba8709e818b62315` |
| Merged at | `2026-09-11T00:50:35Z` |

Merge type confirmed `--merge` (a merge commit), matching the Phase 14 convention — not squash, not rebase.

### 2. Confirm `main` carries the work

`git -C repos/security-platform fetch origin`, then read via `git show origin/main:<path>` (never the local working tree):

- `origin/main:.github/workflows/security.yml` parses to exactly five job ids — `sast`, `iac`, `sca`, `container`, `secrets` — with **zero** `needs:` keys anywhere in the file (`grep -c 'needs:'` = `0`).
- All six required files present on `origin/main` (`git cat-file -e origin/main:<path>` for each): `fixtures/Dockerfile`, `fixtures/main.tf`, `fixtures/package.json`, `fixtures/package-lock.json`, `fixtures/README.md`, `scripts/smoke-scans.sh`.
- `origin/main:.pre-commit-config.yaml` carries exactly **4** non-comment `exclude: ^fixtures/` lines.

All three assertions passed.

### 3. Local checkout returned to `main`

```
git -C repos/security-platform switch main
git -C repos/security-platform pull --ff-only   # fast-forwarded 51714df..e8e1009
git -C repos/security-platform branch -d feature/phase-15-five-parallel-scan-jobs
```

`git -C repos/security-platform status --porcelain` is empty; `git -C repos/security-platform branch --show-current` reports `main`. The local feature branch was deleted (merged, safe `-d`).

**Loose end (non-blocking):** the plan scopes cleanup to the local branch only. The **remote** branch `feature/phase-15-five-parallel-scan-jobs` was not auto-deleted by the merge (`git ls-remote origin feature/phase-15-five-parallel-scan-jobs` still returns the head SHA `3e187a3...`) and was left alone per plan scope — deleting it was out of scope for this task.

### 4. Open Question Q3 closed — Dependabot alerts

```
gh api -i repos/OttawaCloudConsulting/security-platform/vulnerability-alerts
```
→ `HTTP/2.0 404 Not Found`

```
gh api repos/OttawaCloudConsulting/security-platform/dependabot/alerts
```
→ `403`, body: `"Dependabot alerts are disabled for this repository."`

**Answer: Dependabot alerts are disabled** on this repository (both probes agree — a 404 on the vulnerability-alerts toggle endpoint, and an explicit disabled message from the alerts-list endpoint). No alert can therefore reference `fixtures/package-lock.json` while alerts remain off. `dependabot.yml` was **not modified** — confirmed by reading `origin/main:.github/dependabot.yml`, which still declares only the `github-actions` ecosystem, no `npm` entry added, no ignore rules added.

Caveat for whoever revisits this: enabling Dependabot alerts is a repo-settings change, not a workflow/config change, and doing so is out of scope for this phase and this task — it was measured, not toggled.

### 5. Verbatim check-run names re-read from the merged run (for Phase 18)

```
gh run view 34546843396 -R OttawaCloudConsulting/security-platform --json jobs --jq '.jobs[].name'
```

```
security / SAST — Semgrep CE
security / IaC — Checkov
security / SCA — Trivy Filesystem
security / Container — Trivy Image
security / Secrets — Gitleaks
```

These are byte-identical to the names captured in 15-04-SUMMARY (em-dash `U+2014` verified there). **`security / Placeholder`, recorded by Phase 14 as the placeholder check name, is now superseded** — Phase 18 must configure branch protection against these five names, not the Phase 14 placeholder.

### 6. Carried-forward items, named against owning phase

**Phase 16 (SCA-01/02/03):**
- `fixtures/main.tf`'s `hashicorp/aws 3.74.0` provider pin exists specifically to seed SCA-03 (provider/module pin checks) — it produces zero Checkov findings on its own (RESEARCH C-2); the IaC job's actual findings come from the `aws_s3_bucket`/`aws_security_group` misconfigurations in the same file.
- `fixtures/package-lock.json` seeds SCA-01 (npm ecosystem sub-scan).
- There is no Python fixture yet — Phase 16 (SCA-02) will need to add one.

**Phase 17 (CICD-02/03, DefectDojo import):**
- The `--severity HIGH,CRITICAL` filter on both Trivy jobs applies to the report **file**, not just the exit code (Pitfall 7 / Assumption A3) — Phase 17 must decide whether DefectDojo wants full-severity artifacts, and if so, either drop `--severity` from the report run and move the threshold to Phase 18's gate, or add a second full-severity report run.
- `pr-security.yml` currently grants only `contents: read`; it must be widened to `security-events: write` before `upload-sarif` can work at all (Pitfall 5) — a called workflow cannot self-elevate permissions above what the caller grants.

**Phase 18 (CICD-04/06, gate mode + branch protection):**
- The 9 Gitleaks history findings (Phase-05 test strings, confirmed fake per the user's `approved` response) are report-only this phase but WILL block once gate mode is turned on. Remedy is `--baseline-path` or fingerprint-form `.gitleaksignore` entries (`file:rule-id:start-line`) — path globs are not a valid `.gitleaksignore` form (RESEARCH C-3).
- Must configure branch protection against the five verbatim check-run names re-read in step 5 above, not the superseded `security / Placeholder`.

**Standing (no single owning phase yet):**
- The `versions.conf` CI-vs-workstation version split (Trivy 0.69.3 / Gitleaks 8.30.0 on the workstation vs Trivy v0.74.0 / Gitleaks 8.30.1 in CI) is left deliberately divergent; convergence is a later-phase call.
- `bridgecrewio/checkov-action`'s SHA pin protects the action boundary only — it then pulls `ghcr.io/bridgecrewio/checkov:3.3.17` by mutable tag internally. This is an accepted residual risk under ADR-004, not a gap to close this phase.

**D-02 / D-03 correction note (so a later reader does not read this as drift):**
- CONTEXT.md's D-02 ("old base image with known CVEs") was implemented as `public.ecr.aws/docker/library/debian:12-slim` (a currently-supported distro with unpatched CVEs), not a literally "old" EOL image — RESEARCH C-1 measured that an EOL base (`alpine:3.14`) produces **zero** findings because EOL distributions have no advisory feed, which is the opposite of D-02's intent. The corrected image measured 222 vulnerabilities (4 CRITICAL, 52 HIGH).
- CONTEXT.md's D-02 "unpinned/old Terraform provider" clause was also corrected: the old `hashicorp/aws 3.74.0` pin alone produces zero Checkov findings (RESEARCH C-2); the fixture's actual findings come from misconfigured `aws_s3_bucket`/`aws_security_group` resources added alongside the pin.
- CONTEXT.md's D-03 (Gitleaks exemption scoped to `fixtures/`) was implemented with **no Gitleaks or `.gitleaksignore` change at all** — RESEARCH C-3 found the exemption both unnecessary (no secret is seeded in the fixtures) and mechanically impossible as originally envisioned (`.gitleaksignore` accepts fingerprints only, not path globs; a path-based allowlist would require `.gitleaks.toml`, which would also blind the CI secrets job). D-03's *scoping intent* was satisfied instead by four `exclude: ^fixtures/` entries on the `terraform_fmt`, `terraform_validate`, `hadolint`, and `npm-audit` pre-commit hooks — the hooks that actually fire on fixture content (RESEARCH C-4).

Both corrections were made under Rule 1 (bug: the literal wording produced zero verifiable findings, contradicting Success Criteria #2) during Plan 01/02/03, not introduced or altered in this plan. They are restated here per the plan's explicit instruction so a later reader treats them as deliberate RESEARCH-driven corrections, not undocumented drift from CONTEXT.md.

### 7. Note for the next STATE.md update (RESEARCH C-6)

RESEARCH C-6 found that STATE.md's "Phase 14 branch is unpushed" blocker note is stale — the Phase 14 branch was merged (`51714df`, `5c4188a` in `repos/security-platform`'s history) well before this plan ran. Additionally, this phase (15) resolves both of STATE.md's fixture/hook blockers:
- "Scan fixtures are needed from Phase 15" — resolved: `fixtures/` now exists on `main` with real Dockerfile/lockfile/`.tf` content.
- "This repo's own hooks will block committing those fixtures" — resolved: four `exclude: ^fixtures/` hook entries now exist on `main`, confirmed present in step 2 above.

These corrections are applied to STATE.md in the State Updates step of this execution (see below), not deferred.

## Task Commits

Both tasks in this plan are checkpoint/observation-only, per the plan's design (identical pattern to 15-04):

1. **Task 1: Human confirmation checkpoint** — no commit (checkpoint gate; user responses recorded above)
2. **Task 2: Merge, verify main, close open questions** — no commit in `repos/security-platform` beyond the merge commit itself (`e8e1009`, created by `gh pr merge`, not authored by this executor). Zero files changed by this executor in `repos/security-platform`; `git status --porcelain` is empty.

**Plan metadata:** outer documentation repo only (this SUMMARY + STATE + ROADMAP + REQUIREMENTS, committed separately as the final metadata commit).

## Files Created/Modified

- `.planning/phases/15-five-parallel-scan-jobs/15-05-SUMMARY.md` — this file (created)
- No files modified in `repos/security-platform` by this executor. The 8-file diff (`security.yml`, `.pre-commit-config.yaml`, `fixtures/*`, `scripts/smoke-scans.sh`) was authored in Plan 03 and landed on `main` via the merge, not by any command run in this plan.

## Decisions Made

See `key-decisions` in frontmatter:
- No `--delete-branch` on the `gh pr merge` invocation, to avoid gh's checkout/branch-delete side effects touching the outer documentation repo's separate checkout (which shares the same remote URL but is on an unrelated branch with its own uncommitted changes).
- The remote feature branch was left in place — its deletion is outside the plan's scoped cleanup (local branch only).
- D-02/D-03 RESEARCH-corrected forms restated as deliberate, not drift (see step 6 above).

## Deviations from Plan

**None — plan executed exactly as written.** Every verification assertion in Task 2's `<automated>` block passed on first evaluation (five jobs with no `needs:`, all six files present, four exclude lines, clean fast-forwarded `main`, feature branch deleted). The Q3 probe's 404/403 outcome was anticipated by the plan's own framing ("a 204 means alerts are enabled, 404 means disabled") and required no auto-fix or escalation.

## Issues Encountered

None. The `gh api repos/<slug>/dependabot/alerts` call returned a 403 with an explicit "Dependabot alerts are disabled for this repository" message rather than a bare 404 — this is consistent with (and reinforces, not contradicts) the 404 from `vulnerability-alerts`, and was treated as a confirming second data point, not a failure requiring the anti-slop STOP protocol.

## Threat Model Coverage

| Threat ID | Disposition | Evidence in this plan |
|-----------|-------------|------------------------|
| T-15-24 | mitigated | Task 1's `gate="blocking"` checkpoint was honored across a session boundary — no merge, close, or push occurred until the verbatim `approved` response was recorded in a prior turn and re-confirmed as the basis for this task's actions. |
| T-15-25 | mitigated | All post-merge verification of `main`'s contents used `git show origin/main:<path>` / `git cat-file -e origin/main:<path>` against a freshly fetched `origin`, never the local working tree, before the local checkout was moved. |
| T-15-26 | accepted | No change to this disposition — fixtures are still never installed/built by any pipeline other than the container job's isolated `docker build`; `package.json` remains `"private": true`. Q3 measurement (step 4) confirms Dependabot alert noise is not even possible while alerts remain disabled repo-wide. |
| T-15-27 | mitigated | Only rule ID, file path, and line number were shown to the user in Task 1 (per 15-04/15-02 SUMMARY); the user's `approved` response explicitly confirms these are recognized as fake test strings, not live credentials — no incident. |
| T-15-28 | mitigated | The five verbatim check-run names were re-read directly from the merged run (`gh run view 34546843396 --json jobs`) in step 5, and the superseded `security / Placeholder` name is called out explicitly for Phase 18. |

## User Setup Required

None — no external service configuration required. Merge is complete; `main` is current.

## Next Phase Readiness

- `OttawaCloudConsulting/security-platform`'s `main` branch now carries the five-job `security.yml`, the fixtures tree, the four pre-commit hook exclusions, and `scripts/smoke-scans.sh` — Phase 16 starts from a current default branch.
- Open Question Q3 is closed: Dependabot alerts are disabled on this repository; no noise-handling action is needed unless/until alerts are enabled.
- Open Question Q1, Assumption A3, and the `versions.conf` version split are handed to Phases 18, 17, and (standing, unowned) respectively, as itemized above.
- Phase 18 has the five verbatim check-run names it needs for branch protection configuration, byte-exact and independently re-confirmed from the merged run (not re-derived from 15-04's evidence, but a fresh read, satisfying T-15-28's repudiation mitigation).
- No blockers remain from this phase. `repos/security-platform` is on a clean `main`, fast-forwarded to `e8e1009`, local feature branch deleted; the only loose end (remote feature branch not deleted) is explicitly out of this plan's scope and non-blocking.

---
*Phase: 15-five-parallel-scan-jobs*
*Completed: 2026-09-11*

## Self-Check: PASSED

- `.planning/phases/15-five-parallel-scan-jobs/15-05-SUMMARY.md` (this file) exists on disk.
- PR #6 verified `MERGED` at execution time: `gh pr view 6 -R OttawaCloudConsulting/security-platform --json state` → `MERGED`.
- Merge commit `e8e10091746522d1933585f3ba8709e818b62315` verified present in `repos/security-platform` history at `origin/main` (fast-forward pulled onto local `main` with no conflict — a nonexistent SHA would have failed the `pull --ff-only`).
- `origin/main`'s `security.yml`, six fixture/script files, and four pre-commit excludes all independently re-verified via `git show`/`git cat-file -e` at self-check time (see step 2 output above).
- Local checkout confirmed on branch `main`, working tree clean, feature branch deleted.
