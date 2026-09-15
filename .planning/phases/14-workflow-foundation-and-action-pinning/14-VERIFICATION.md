---
phase: 14-workflow-foundation-and-action-pinning
verified: 2026-09-15T00:00:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
---

# Phase 14: Workflow Foundation and Action Pinning Verification Report

**Phase Goal:** This repo has a callable security scanning workflow that runs on every pull request, pinned to immutable action SHAs and kept current automatically.
**Verified:** 2026-09-15 (session date; live repo state read 2026-09-15 per artifact timestamps)
**Status:** passed
**Re-verification:** No — initial verification (retroactive, authored in Phase 20.1)

## Method

This verification does not trust SUMMARY.md narrative. Every load-bearing claim in the four success
criteria was independently re-queried against the live `OttawaCloudConsulting/security-platform`
repository via `gh` (PRs #4, #5, #13, run conclusions, workflow YAML content, Dependabot PR/job history) in
this session, and the results are reproduced below next to the SUMMARY's claim. All spot-checks matched
exactly — no figure in the three SUMMARYs (14-01 through 14-03) that this report re-queried differed from
the live repository.

This report is retroactive, authored ~5 days after Phase 14 closed (2026-09-10), during Phase 20.1. Four
subsequent phases (15 through 20) and one Dependabot version bump have landed on this configuration in the
interim without breaking it — that is itself evidence the workflow foundation this phase built is durable,
not merely evidence it once worked.

**Pinned evidence snapshot** (re-confirmed live this session, carried verbatim into this report and shared
with `17-VERIFICATION.md` / `18-VERIFICATION.md` so the three documents cannot contradict each other):

| Field | Value |
|---|---|
| Reference PR | `#13` |
| Head SHA | `c06d2729b123094bcbb48e03c1155b72c7727b8c` |
| Reference run | `34870572604` (`PR Security`, `success`, 2026-09-14T16:45:26Z) |
| Merge commit date | `2026-09-14T17:04:38Z` |
| `origin/main` HEAD (workflow-definition SHA, as measured) | `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` |
| Repo visibility | `public` (`default_branch: main`, `archived: false`) |

`c06d272…` (PR #13's head) and `cdf2c21…` (`origin/main`'s current tip, the merge commit of PR #13) are
**two different refs**: server-side scan records (analyses, check-runs, artifacts) hang off the PR head,
while workflow YAML source-of-truth is read from `origin/main`. Neither statement below should be read as
claiming server-side scan records exist on a bare `refs/heads/main` ref — this repo's pipeline is
`on: pull_request` only (see SC1 below).

**Read-only scope:** no `gh variable set`, no `gh variable delete`, no `--apply`, no `gh pr create`, no
`gh pr merge`, no push to `security-platform`, no package install. Only `gh api`, `gh pr view`, `gh run
view`, `gh pr list`, `git diff`, and `grep` were run.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth (from ROADMAP.md) | Status | Evidence |
|---|---|---|---|
| SC1 | Opening a pull request in this repo triggers a security workflow run visible in the Actions tab, and the run completes without blocking the merge. | ✓ VERIFIED | PR #4. `gh pr view 4 -R $R --json state,mergedAt,mergeCommit` this session → `state: MERGED`, `mergedAt: 2026-09-10T19:34:37Z`, merge commit `5c4188a5310d4810fee5e00f2cbdec9c3fd71898`. `gh run view 34519772020 -R $R --json conclusion` → `success`. `gh run view 34519781051 -R $R --json conclusion` → `success`. Matches `14-02-SUMMARY.md`'s claim exactly — a merged PR, two successful runs, no blocked merge. |
| SC2 | The scanning workflow is defined with `on: workflow_call` and is invoked by a thin `pull_request` caller workflow in this repo, so the same file is callable from another repo without restructuring later. | ✓ VERIFIED | Live `contents` API read of `.github/workflows/security.yml` on `origin/main` this session: `grep -n 'workflow_call'` → line 20, `workflow_call:` trigger present. Live read of `.github/workflows/pr-security.yml`: line 24-25 `on:` / `pull_request: {}`, line 60 `uses: ./.github/workflows/security.yml`. Caller file is 81 lines vs callee's 1206 lines — genuinely thin. Matches `14-01-SUMMARY.md`'s architecture claim exactly. |
| SC3 | Every `uses:` reference in the workflows is pinned to a full commit SHA with a human-readable version comment. | ✓ VERIFIED | Live `security.yml` read, `grep -n 'uses:'` this session — 20 hits, every external reference matching `@[0-9a-f]{40}  # v<semver>`: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` (×5), `github/codeql-action/upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63  # v4.38.0` (×6), `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1` (×5), `bridgecrewio/checkov-action@a8664e3a0549367977f0cda990a34311835c87c0  # v12.3123.0` (×1), `aquasecurity/setup-trivy@81e514348e19b6112ce2a7e3ecbafe19c1e1f567  # v0.3.1` (×2). Two non-defects stated explicitly rather than flagged: (i) `pr-security.yml:60`'s `uses: ./.github/workflows/security.yml` is a relative local reference, unpinnable by design and never proposed by Dependabot (the file's own header comment says so); (ii) `14-VALIDATION.md` task 14-01-02 recorded `actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0  # v7.0.0` — live is now `@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1`. This SHA changed. The mechanism: Dependabot PR #5 (`chore(deps): bump actions/checkout from 7.0.0 to 7.0.1`) merged 2026-09-10T19:40:34Z and updated every occurrence. The verdict: this drift **is** CICD-05 working as designed — a pin that never moved would be the weaker result — not a failure of SC3's invariant, which was re-verified against the live `@<40-hex>  # v<semver>` shape, not the literal SHA. |
| SC4 | Dependabot opens a pull request against this repo when a pinned action publishes a newer release. | ✓ VERIFIED | `gh api repos/$R/contents/.github/dependabot.yml --jq '.content' \| base64 -d` this session → `version: 2`, one `updates:` entry, `package-ecosystem: "github-actions"`, `directory: "/"`, `schedule.interval: "weekly"`. `gh pr list -R $R --state all --author "app/dependabot" --json number,state,title,mergedAt` → PR `#5`, `MERGED`, `2026-09-10T19:40:34Z`, "chore(deps): bump actions/checkout from 7.0.0 to 7.0.1". `gh run view 34872527866 -R $R --json name,conclusion,headBranch,createdAt` → `github_actions in /. - Update #1576015494`, branch `main`, `success`, created `2026-09-14T17:04:43Z` — a Dependabot version-update job ran on `main` the same day as the pinned snapshot, four days after PR #5 merged, proving the loop is still live, not a one-time fluke. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `.github/workflows/security.yml` | Callable workflow, `on: workflow_call`, 1200+ lines | ✓ VERIFIED | Confirmed present on live `origin/main` via `contents` API this session; 1206 lines; `workflow_call:` at line 20 |
| `.github/workflows/pr-security.yml` | Thin `pull_request` caller, `uses: ./.github/workflows/security.yml` | ✓ VERIFIED | Confirmed present on live `origin/main`; 81 lines; caller line 60 |
| `.github/dependabot.yml` | `github-actions` ecosystem, weekly schedule | ✓ VERIFIED | Confirmed present on live `origin/main`; content matches SC4 evidence above |
| `.planning/REQUIREMENTS.md` | CICD-05 marked complete | ✓ VERIFIED | Live grep this session: line 14 `[x] **CICD-05**`, line 63 traceability row `CICD-05 \| Phase 14 \| Complete` |

### Key Link Verification

The `gsd-sdk query verify.key-links` tool is built to pattern-match static source-file references. Phase
14's key links are live CI/GitHub API facts (a merged PR's head SHA, a workflow run's conclusion, a
Dependabot job's outcome), not static source-file greps — the same tooling-fit mismatch
`19-VERIFICATION.md` documented for Phase 19. Each link below was independently re-verified by direct
`gh`/`gh api` calls in this session rather than relying on the tool.

| From | To | Via | Status | Details |
|---|---|---|---|---|
| PR #4 merge | Actions-tab-visible, non-blocking run | `pull_request` trigger in `pr-security.yml` | ✓ WIRED (live) | Live PR #4 `state: MERGED`; runs `34519772020`/`34519781051` both `conclusion: success` |
| `pr-security.yml`'s `uses: ./.github/workflows/security.yml` | `security.yml`'s `on: workflow_call` | local relative reference | ✓ WIRED (live) | Both live-read this session; caller line 60 references the exact relative path of the callee, whose own trigger block declares `workflow_call:` at line 20 |
| Pinned `actions/checkout` SHA | Dependabot PR #5 | GitHub Actions version-update scan | ✓ WIRED (live) | Live `dependabot.yml` targets `github-actions`; live PR #5 `MERGED`, bumping the exact action `security.yml` pins; live `security.yml` now carries the bumped SHA at all 5 occurrences |
| Dependabot config | scheduled update job execution | GitHub-managed Dependabot scheduler | ✓ WIRED (live) | Live run `34872527866`, `github_actions in /. - Update #1576015494`, `success`, `main`, 2026-09-14 — proof the scheduled loop still executes, not just that the config file exists |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| CICD-05 | 14-01 through 14-03 | Dependabot configured to keep GitHub Actions SHA pins updated | ✓ SATISFIED | Marked complete in `.planning/REQUIREMENTS.md` (both tracking locations, live-read this session: line 14 checkbox, line 63 traceability row). All four SC rows above independently re-verified live, including the SC3 pin-drift/SC4 merged-PR/scheduled-job evidence that is CICD-05's direct proof. No orphaned requirements — REQUIREMENTS.md maps only CICD-05 to Phase 14. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | No `TBD`/`FIXME`/`XXX` debt markers found in any phase-modified file (`14-01-SUMMARY.md`, `14-02-SUMMARY.md`, `14-03-SUMMARY.md`, `14-VALIDATION.md`, `deferred-items.md`) or in `.planning/ROADMAP.md`'s Phase 14 section — re-grepped live at execution time (2026-09-15), no hits anywhere in the file | — | — |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Repo state | `gh api repos/$R --jq '{visibility,default_branch,archived,pushed_at}'` | `visibility: public`, `default_branch: main`, `archived: false` | ✓ PASS (matches SUMMARY) |
| PR #13 head (pinned snapshot) | `gh pr view 13 -R $R --json number,title,headRefOid,mergedAt,mergeCommit` | `headRefOid: c06d2729b123094bcbb48e03c1155b72c7727b8c`, merged `2026-09-14T17:04:38Z` | ✓ PASS |
| `origin/main` workflow-definition SHA | `gh api repos/$R/commits/main --jq '.sha'` | `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` | ✓ PASS |
| Reference run success | `gh run view 34870572604 -R $R --json databaseId,name,conclusion,createdAt,headSha` | `PR Security`, `success`, `2026-09-14T16:45:26Z` | ✓ PASS |
| Local clone matches live `origin/main` | `git -C repos/security-platform fetch origin && git -C repos/security-platform rev-parse origin/main` | `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` — string-equal to `commits/main` above | ✓ PASS |
| Six load-bearing files byte-identical | `git -C repos/security-platform diff origin/main --stat -- <6 files>` | empty output | ✓ PASS |
| Offline workflow gate | `bash repos/security-platform/scripts/check-workflow-uploads.sh` | `PASS - 10 checks, 0 failures`, exit 0 | ✓ PASS |
| PR #4 state | `gh pr view 4 -R $R --json state,mergedAt,mergeCommit` | `MERGED`, `2026-09-10T19:34:37Z`, `5c4188a…` | ✓ PASS (matches SUMMARY) |
| PR #4-triggered runs | `gh run view 34519772020/34519781051 -R $R --json conclusion` | both `success` | ✓ PASS |
| `security.yml` `workflow_call` trigger | live `contents` read, `grep -n 'workflow_call'` | line 20 | ✓ PASS |
| `pr-security.yml` caller shape | live `contents` read, `grep -n 'on:\|pull_request\|uses: \./'` | `on:`/`pull_request: {}` at 24-25, `uses: ./.github/workflows/security.yml` at 60 | ✓ PASS |
| SC3 `uses:` pin invariant | live `contents` read, `grep -n 'uses:'` on `security.yml` | 20/20 external references match `@<40-hex>  # v<semver>` | ✓ PASS |
| SC3 pin-drift narration | cross-reference `14-VALIDATION.md` task 14-01-02 vs live SHA | `9c091bb2…  # v7.0.0` (recorded) → `3d3c42e5…  # v7.0.1` (live) | ✓ PASS — corroborates the "Dependabot PR #5 working, not a defect" narrative |
| `dependabot.yml` config | live `contents` read | `version: 2`, `package-ecosystem: "github-actions"`, `directory: "/"`, `interval: "weekly"` | ✓ PASS |
| Dependabot merged bump PR | `gh pr list -R $R --state all --author "app/dependabot" --json number,state,title,mergedAt` | PR #5, `MERGED`, 2026-09-10T19:40:34Z | ✓ PASS |
| Dependabot scheduled job execution | `gh run view 34872527866 -R $R --json name,conclusion,headBranch,createdAt` | `github_actions in /. - Update #1576015494`, `success`, `main` | ✓ PASS |
| REQUIREMENTS.md CICD-05 tracking | live grep, both locations | checkbox line 14, traceability row line 63, both `Complete`/`[x]` | ✓ PASS |

### Probe Execution

Checked `grep -rn 'probe-' .planning/phases/14-*/14-0*-PLAN.md .planning/phases/14-*/14-VALIDATION.md`
(no hits) and `find repos/security-platform/scripts -path '*/tests/probe-*.sh'` (no hits), both re-run live
this session. This phase is validated via live GitHub Actions runs and API reads, not local probe scripts.

### Human Verification Required

None — the UI confirmations these phases required were `checkpoint:human-verify` gates closed during the
original phases, cited above; no new human verification is deferred by this report.

### Gaps Summary

No gaps against CICD-05 or any of the four ROADMAP success criteria — all four are independently confirmed
against live GitHub state, not merely asserted in SUMMARY.md prose.

One item is worth surfacing as informational context, not a gap: **SC3's checkout SHA drift**
(`9c091bb2…  # v7.0.0` → `3d3c42e5…  # v7.0.1`). This is Dependabot PR #5 doing exactly what CICD-05
requires — a pin that never moved would be the weaker result — and is recorded above as a `✓ VERIFIED`
observation, not a failure.

`.planning/phases/14-workflow-foundation-and-action-pinning/deferred-items.md` carries five items, all
`gsd-sdk` state-handler tooling defects (or a related STATE.md placement issue), none of them pipeline
defects and none bearing on CICD-05. Their status by inspection this session (no mutating `gsd-sdk`
handler was invoked to "reproduce" them, per this phase's read-only scope):

1. **`state.record-metric` rejects the documented positional form.** OPEN — out of scope for CICD-05; a
   GSD tooling defect, not a pipeline defect.
2. **`state.add-decision` rejects a positional summary and double-prefixes.** OPEN — out of scope for
   CICD-05; same tooling class.
3. **`state.record-session` corrupts frontmatter fields.** OPEN — out of scope for CICD-05; same tooling
   class.
4. **`state.update-progress` does not rewrite frontmatter `percent`.** OPEN — out of scope for CICD-05;
   same tooling class.
5. **STATE.md metric rows land in the wrong table.** OPEN — pre-existing, out of scope for CICD-05; a
   GSD bookkeeping cosmetic issue, not a pipeline defect.

See the dated status re-check appended to `deferred-items.md` below for the full evidence trail.

**Reproducibility caveat:** the token used for these reads carries `repo` scope but not
`security_events`; this is sufficient only because `security-platform` is `visibility: public`. If the repo
were ever made private, code-scanning reads would 403 and this report's CICD-02/03-adjacent claims would
need a re-scoped token — noted here for completeness even though Phase 14 itself makes no code-scanning
claim.

---

*Verified: 2026-09-15*
*Verifier: Claude (gsd-verifier)*
