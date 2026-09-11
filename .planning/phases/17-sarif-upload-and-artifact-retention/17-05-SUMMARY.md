---
phase: 17-sarif-upload-and-artifact-retention
plan: 05
subsystem: infra
tags: [github-actions, code-scanning, sarif, upload-artifact, live-run, pull-request, annotations, evidence]

# Dependency graph
requires:
  - phase: 17-sarif-upload-and-artifact-retention
    provides: "17-01's caller/callee security-events: write grant; 17-02's direct trivy-fs SARIF; 17-03's six categorised SARIF uploads; 17-04's five retained artifacts — all committed but never pushed until this plan"
  - phase: 16-sca-ecosystem-coverage
    provides: "16-05's live-run procedure (push, gh pr create, watch, gh api evidence collection) and its six-checks-on-head-SHA baseline"
provides:
  - "PR #8 open against OttawaCloudConsulting/security-platform main, unmerged, with run 34638828775 completed green"
  - "Live evidence for Criterion 1: six distinct code-scanning categories on refs/pull/8/merge, read from code-scanning/analyses"
  - "Live evidence for Criterion 3: five artifacts with non-zero sizes and an expires_at exactly 90 days after the run"
  - "Live evidence for Criterion 2: three inline code-scanning annotations on fixtures/main.tf line 38, the exact line the fixture edit touched"
  - "The byte-exact check-run name list on the head SHA, and the resolution of the one-per-tool vs one-per-category question Phase 18 was handed"
affects: [17-06, 17-07, 18-gate-mode-and-branch-protection, 19-validation, 20-distribution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The verification PR is CONSTRUCTED, not assumed: before opening it, measure which lines each scanner reports, then edit one line that is a reported startLine for more than one tool, and re-measure to prove the finding survived."
    - "Code-scanning PR diff annotations are readable from the API without the UI: GET /repos/{o}/{r}/check-runs/{id}/annotations on the github-advanced-security check runs returns the same path/start_line/end_line set the Files-changed tab renders."

key-files:
  created: []
  modified:
    - repos/security-platform/fixtures/main.tf

key-decisions:
  - "`gh auth refresh -h github.com -s security_events` was NOT run. The local token carries 'gist', 'read:org', 'repo', 'workflow' and NO security_events scope, yet every code-scanning read succeeded — security_events is required only for PRIVATE repositories and security-platform is PUBLIC, where `repo` suffices. The documented fallback stayed unused rather than being fired pre-emptively; `gh auth refresh` is an interactive device-code flow that would have blocked an autonomous run."
  - "The fixture edit landed on `fixtures/main.tf` line 38, the `module \"fixture_unpinned_module\" {` header — the single highest-overlap line in the repo. It is the reported startLine for Checkov CKV_TF_1 and CKV_TF_2 (region 38-40 before, 38-42 after) AND the exact single line for tflint terraform_module_version. One changed line therefore feeds two tools' annotations."
  - "Criterion 2 is OBSERVED, not NOT OBSERVED. The pre-authorised NOT-OBSERVED branch was not taken: three annotations rendered on the edited line. RESEARCH Open Question Q2 (whether diff annotations render at all with no base analysis on main to diff against) is answered YES — D-02's pull_request-only trigger does not suppress them."
  - "The check-run hypothesis Phase 18 was handed resolves to ONE CHECK PER `tool.driver.name`, not per category. `Trivy` appears exactly ONCE on the head SHA despite owning two categories (trivy-fs, trivy-image). Six new checks appeared, which is the count the per-category hypothesis predicted — but for a different reason: tflint's single SARIF carries TWO drivers (`tflint` and `tflint-errors`), so it produced two checks and two analyses under one category. Matching the predicted count would have been a false confirmation."
  - "The `Checkov` code-scanning check concluded FAILURE while all five `security / *` job checks concluded success and the PR stayed MERGEABLE. Phase 18 must treat this as a first-class input: adding code-scanning checks to a required-check list would block this PR today, on findings the fixtures exist to produce."
  - "Analyses `tool.name` and check-run `name` DIFFER IN CASE for two tools — analyses say `checkov` and `Gitleaks`, check runs say `Checkov` and `gitleaks`. A required-check list must be built from the check-runs endpoint, never from the analyses endpoint."

patterns-established:
  - "Pattern: prove an absence is informative before recording it. The plan pre-authorised recording Criterion 2 as NOT OBSERVED, but only after constructing a PR where an absence would have meant something. The construction cost two tool runs and turned a would-be unresolved criterion into a measured pass."
  - "Pattern: when two hypotheses predict different counts, check WHICH members produce the count, not just the count. The observed six matched the wrong hypothesis's number."

requirements-completed: [CICD-02, CICD-03]

# Metrics
duration: 11min
completed: 2026-09-11
---

# Phase 17 Plan 05: The First Live Upload — Six Categories, Five Artifacts, And Three Annotations On The Line We Aimed At

**PR #8 and run 34638828775 turned the phase from static YAML into measured fact: the repo went from `total_count: 0` artifacts and HTTP 404 "no analysis found" to seven code-scanning analyses across six distinct categories, five artifacts expiring exactly 90 days out, and three inline annotations on `fixtures/main.tf` line 38 — the line the fixture edit was constructed to touch.**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-09-11T19:22Z
- **Completed:** 2026-09-11T19:33Z
- **Tasks:** 2
- **Files modified:** 1 (0 created, 1 modified)

## Accomplishments

- **Criterion 1 has live evidence under the branch/PR filter D-02 makes necessary.** All six categories are
  present and distinct on `refs/pull/8/merge`, read from `code-scanning/analyses`, never from the UI.
- **Criterion 3 has live evidence including the SCA sub-scan reports.** Five artifacts, five distinct names,
  every size non-zero, every `expires_at` exactly 90 days after the run — and the downloaded `sca-results`
  really does contain the numbered `npm-audit-1.json` and `pip-audit-1.json` the glob was written for.
- **Criterion 2 is OBSERVED, and that was not the expected outcome.** The plan pre-authorised recording it as
  NOT OBSERVED. Instead, three code-scanning annotations landed on `fixtures/main.tf` line 38: tflint
  `terraform_module_version` (warning, 38-38) and Checkov `CKV_TF_1`/`CKV_TF_2` (failure, 38-42). Every other
  check run returned zero annotations — precisely the discrimination RESEARCH Pitfall 4 predicted, and the
  reason the PR had to be constructed rather than assumed.
- **All eleven intolerant `.outcome` assertions ran GREEN — none skipped.** The same-repo, non-Dependabot PR
  requirement 17-03 and 17-04 flagged was met, so the fork/Dependabot guard evaluated true and every
  assertion actually proved something.
- **Phase 18's open question is answered with a measurement that contradicts the obvious reading of the
  count.** One check per `tool.driver.name`, not per category.

## Task Commits

1. **Task 1: Construct a verification edit on a line a scanner actually flags** — `fbe0071` (test)
2. **Task 2: Push, open the PR, and collect the live upload, artifact and check-run evidence** — no commit;
   the task changes no files by design (`<files></files>` in the plan). Its deliverable is the live PR, the
   completed run and the evidence recorded below.

Commit `fbe0071` is on `feature/phase-17-sarif-upload-and-artifact-retention` in the nested product repo
`repos/security-platform`, continuing 17-01 through 17-04 (`34cd158`, `66a18ad`, `a3f9dac`, `f3e6dec`,
`7525ad2`, `9692fa7`, `4355f10`, `803f988`). Committed with hooks; `--no-verify` was not used. The push ran
the pre-push hooks (shellcheck, yamllint, Gitleaks — all Passed).

## Files Created/Modified

- `repos/security-platform/fixtures/main.tf` — 3 insertions, 1 deletion. A trailing comment on the
  `module "fixture_unpinned_module" {` header plus two comment lines inside the block. No `cidr_blocks`
  value, provider version constraint or module source changed.

## Required Output: Observed Evidence

### 0. Preflight — `gh auth status`, recorded verbatim

```
github.com
  ✓ Logged in to github.com account OttawaCloudConsulting (keyring)
  - Active account: true
  - Git operations protocol: https
  - Token: gho_************************************
  - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
```

**`security_events` is ABSENT and was NOT refreshed.** Every `code-scanning/analyses` read below succeeded
anyway: the scope is required only for private repositories, and `OttawaCloudConsulting/security-platform`
is public, where `repo` covers it. T-17-22 is therefore closed by evidence rather than by mitigation — no
read returned 403 at any point, and the only 404 observed is the documented pre-upload baseline.

### 1. The measured before/after pair

| Reading | BEFORE (re-taken 2026-09-11T19:26Z, immediately pre-push) | AFTER |
|---|---|---|
| `gh api repos/…/actions/artifacts --jq .total_count` | `0` | `5` for run 34638828775 |
| `gh api repos/…/code-scanning/analyses` | HTTP **404** `{"message":"no analysis found", … "status":"404"}` | 7 analyses, 6 distinct categories |

The before-state 404 is the healthy pre-upload state, **not** a 403. `gh` appends a generic
`needs the "admin:repo_hook" scope` hint to that 404 — noise from the CLI's error handler, not the API's
actual complaint, and not evidence of a scope problem.

### 2. PR and run identifiers

| Item | Value |
|---|---|
| PR | **#8** — `https://github.com/OttawaCloudConsulting/security-platform/pull/8` |
| Run | **34638828775**, event `pull_request`, conclusion `success` |
| Head SHA | `fbe0071d6934d19524f5bf9345e91396080fa882` |
| Merge ref SHA (what the analyses are attached to) | `a2b330f38db3c2b7c995cea7d377c931ccca781e` |
| PR state at close of plan | `OPEN`, `MERGEABLE` — **nothing merged** |

### 3. Criterion 1 — the six categories and their LIVE `tool.name`

`gh api "repos/OttawaCloudConsulting/security-platform/code-scanning/analyses?ref=refs/pull/8/merge"`

| Category | Live `tool.name` | `tool.version` | `results_count` | Analysis id |
|---|---|---|---|---|
| `tflint` | `tflint-errors` | `0.64.0` | 0 | 1763619293 |
| `tflint` | `tflint` | `0.64.0` | 3 | 1763619166 |
| `semgrep` | `Semgrep OSS` | `1.177.0` | 3 | 1763617952 |
| `trivy-fs` | `Trivy` | `0.74.0` | 6 | 1763617805 |
| `checkov` | `checkov` | `3.3.17` | 14 | 1763617591 |
| `trivy-image` | `Trivy` | `0.74.0` | 56 | 1763617437 |
| `gitleaks` | `Gitleaks` | `v8.0.0` | 9 | 1763616327 |

```
all six categories present and distinct: ['checkov', 'gitleaks', 'semgrep', 'tflint', 'trivy-fs', 'trivy-image']
```

**Seven analyses, six categories.** The extra one is not a duplicate upload: tflint's single SARIF file
carries two `runs[]` entries with two different `tool.driver.name` values (`tflint` and `tflint-errors`), and
GitHub creates one analysis per driver. The empty `tflint-errors` run is tflint's error channel and reported
0 results, which is the correct state.

Two of the live driver names differ in case from what was recorded locally and in RESEARCH: the API says
`checkov` (lowercase) and `Gitleaks` (capitalised). See §6 — the *check-run* names invert both.

The 56 `trivy-image` results and the 9 `gitleaks` results are present in the Security tab but contribute no
diff annotations, exactly as 17-RESEARCH measured — the container results point at `library/scan-fixture`
and the Gitleaks findings point at `.planning/`/`.claude/` paths absent from this tree.

### 4. Criterion 3 — five artifacts, non-zero, with `expires_at`

`gh api repos/OttawaCloudConsulting/security-platform/actions/runs/34638828775/artifacts`

| Artifact | id | `size_in_bytes` | `expired` | `created_at` | `expires_at` |
|---|---|---|---|---|---|
| `semgrep-results` | 10279271331 | 195880 | false | 2026-09-11T19:26:51Z | 2026-12-10T19:26:17Z |
| `checkov-results` | 10279690741 | 5178 | false | 2026-09-11T19:26:48Z | 2026-12-10T19:26:17Z |
| `sca-results` | 10279206373 | 19909 | false | 2026-09-11T19:27:06Z | 2026-12-10T19:26:17Z |
| `trivy-image-results` | 10279191308 | 63966 | false | 2026-09-11T19:26:45Z | 2026-12-10T19:26:17Z |
| `gitleaks-results` | 10279710606 | 9442 | false | 2026-09-11T19:26:31Z | 2026-12-10T19:26:17Z |

```
five artifacts, expected names, non-zero sizes, every one carrying an expiry
```

"Roughly 90 days out" is an exact number, not an adjective: every `expires_at` is
`2026-12-10T19:26:17Z`, which is **exactly 90 days** after the RUN's `created_at`
(`2026-09-11T19:26:17Z`) — 19 remaining days of September + 31 + 30 + 10. The per-artifact delta computes as
89 days only because each artifact's own `created_at` is 14-49 s later than the run's; the expiry clock is
anchored to the run, not to the upload step. `retention-days: 90` applied on all five.

### 5. The `sca-results` artifact really contains the globbed reports

`gh run download 34638828775 -n sca-results`

```
-rw-r--r--  5242   npm-audit-1.json
-rw-r--r--  48204  pip-audit-1.json
-rw-r--r--  3521   tflint.sarif
-rw-r--r--  29889  trivy-fs.json
-rw-r--r--  18474  trivy-fs.sarif
SCA artifact carries the globbed npm/pip reports plus trivy-fs and tflint
```

The `-1` suffixes are 16-04's per-input numbering. A literal `npm-audit.json` path would have matched
nothing and, with `if-no-files-found: warn`, would have retained nothing silently — the glob is the whole
point of 17-04 and it is now proven end to end.

### 6. The complete check-run list on the head SHA, byte-for-byte

`gh api "repos/…/commits/fbe0071d6934d19524f5bf9345e91396080fa882/check-runs?per_page=100"` →
`total_count: 12`

```
'tflint-errors'
'tflint'
'Semgrep OSS'
'Checkov'
'Trivy'
'gitleaks'
'security / IaC — Checkov'
'security / SAST — Semgrep CE'
'security / Secrets — Gitleaks'
'security / Container — Trivy Image'
'security / SCA — Trivy Filesystem'
'GitGuardian Security Checks'
count= 12
```

| Check-run name | App | Conclusion |
|---|---|---|
| `tflint-errors` | `github-advanced-security` | success |
| `tflint` | `github-advanced-security` | success |
| `Semgrep OSS` | `github-advanced-security` | success |
| `Checkov` | `github-advanced-security` | **failure** |
| `Trivy` | `github-advanced-security` | success |
| `gitleaks` | `github-advanced-security` | success |
| `security / IaC — Checkov` | `github-actions` | success |
| `security / SAST — Semgrep CE` | `github-actions` | success |
| `security / Secrets — Gitleaks` | `github-actions` | success |
| `security / Container — Trivy Image` | `github-actions` | success |
| `security / SCA — Trivy Filesystem` | `github-actions` | success |
| `GitGuardian Security Checks` | `gitguardian` | success |

**Count comparison against 16-05.** 16-05 counted **six** checks (five `security / …` jobs plus the external
GitGuardian app). This run shows **twelve** — the same six, unchanged and byte-identical (em dash U+2014
intact in all five job names), plus **six new `github-advanced-security` checks**.

**The hypothesis Phase 18 was handed, resolved.** RESEARCH stated the two candidates predict different
counts here: one-per-`tool.driver.name` predicts 5 new checks, one-per-`category` predicts 6, because
`Trivy` owns two categories. Observed: **6 new checks, and the answer is one-per-`tool.driver.name`.**
`Trivy` appears exactly ONCE despite `trivy-fs` and `trivy-image` both being live. The sixth check is
`tflint-errors` — tflint's second SARIF driver. **Reading the count alone would have confirmed the wrong
hypothesis.** Phase 18 must enumerate drivers, not categories, to predict this list.

**Nothing was added to any required-check list.** T-17-23 held; that decision is Phase 18's.

**A finding Phase 18 needs before it decides.** The `Checkov` code-scanning check concluded **failure** while
every job check was green and the PR remained `MERGEABLE`. A code-scanning check fails when the analysis
carries `error`-severity alerts, which the fixtures exist to produce. Making these checks required would
block this PR today. This is an observation, not a recommendation.

**A trap for the required-check list.** The analyses endpoint and the check-runs endpoint disagree on case
for two tools: analyses `checkov` / check-run `Checkov`; analyses `Gitleaks` / check-run `gitleaks`. Branch
protection matches the check-run name. Build the list from `commits/{sha}/check-runs`, never from
`code-scanning/analyses`.

### 7. Criterion 2's raw material — and the annotations that actually rendered

The fixture edit was chosen by measurement, not assumption. Pre-edit Checkov on `fixtures/main.tf`:

```
CKV_TF_1      38 - 40        CKV_AWS_24    26 - 34        CKV2_AWS_62   22 - 24
CKV_TF_2      38 - 40        CKV_AWS_23    26 - 34        CKV2_AWS_6    22 - 24
CKV2_AWS_5    26 - 34        CKV_AWS_18    22 - 24        CKV2_AWS_61   22 - 24
CKV_AWS_145   22 - 24        CKV_AWS_144   22 - 24        CKV_AWS_21    22 - 24
```

Pre-edit tflint: `terraform_module_version` at 38-38, `terraform_required_providers` at 16-18,
`terraform_required_version` at 7-7.

**Line 38 was chosen because it is a reported `startLine` for three results across two tools at once.**

| | Pre-edit | Post-edit |
|---|---|---|
| Checkov results, whole repo | 14 | 14 |
| Checkov results, `fixtures/main.tf` | 12 | 12 |
| Checkov `main.tf` rule-id set | 12 ids | **identical 12 ids** |
| Checkov `CKV_TF_1`/`CKV_TF_2` region | 38-40 | 38-42 (block grew by the two comment lines) |
| tflint rule-id set | `terraform_module_version`, `terraform_required_providers`, `terraform_required_version` | **identical** |
| tflint lines | 38, 16-18, 7 | **identical** |

No drift, no count drop — the edit could not have removed the finding the annotation depends on.

**The annotations that rendered**, read from
`GET /repos/…/check-runs/{id}/annotations` on all six `github-advanced-security` check runs:

| Check run | path | start_line | end_line | level | title |
|---|---|---|---|---|---|
| `tflint` | `fixtures/main.tf` | 38 | 38 | warning | (none) |
| `Checkov` | `fixtures/main.tf` | 38 | 42 | failure | Ensure Terraform module sources use a commit hash |
| `Checkov` | `fixtures/main.tf` | 38 | 42 | failure | Ensure Terraform module sources use a tag with a version number |
| `tflint-errors`, `Semgrep OSS`, `Trivy`, `gitleaks` | — | — | — | — | **zero annotations** |

Three annotations, all on line 38, all from the two tools whose results were measured to report there, and
zero from everything else. That is exactly the discrimination Pitfall 4 describes: 82 other live results
exist on this run and **none** of them annotated the diff, because none of them sits on a changed line.

**RESEARCH Open Question Q2 is answered: YES.** Annotations DO render with no base analysis on `main` to
diff against. D-02's `pull_request`-only trigger does not suppress them, and no `push: branches: [main]`
trigger is needed. 17-07 judges the criterion, but the raw material is unambiguous.

### 8. The eleven intolerant assertions — all green, none skipped

Read from `gh run view 34638828775 --json jobs`, not from scraped logs.

| # | Job | Assertion step | Conclusion |
|---|---|---|---|
| 1 | SAST | Verify Semgrep SARIF upload landed | success |
| 2 | IaC | Verify Checkov SARIF upload landed | success |
| 3 | SCA | Verify Trivy filesystem SARIF upload landed | success |
| 4 | SCA | Verify tflint SARIF upload landed | success |
| 5 | Container | Verify Trivy image SARIF upload landed | success |
| 6 | Secrets | Verify Gitleaks SARIF upload landed | success |
| 7 | SAST | Verify SAST artifact upload landed | success |
| 8 | IaC | Verify IaC artifact upload landed | success |
| 9 | SCA | Verify SCA artifact upload landed | success |
| 10 | Container | Verify container artifact upload landed | success |
| 11 | Secrets | Verify secrets artifact upload landed | success |

**Zero skips, so no skip needs attributing to a guard.** The
`github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'`
guard evaluated TRUE on all eleven — the same-repo, non-Dependabot PR condition 17-04-SUMMARY named as a
precondition was satisfied. Every one of the five `security / *` job checks concluded `success`; none red.

**Incidentally measured, closing 17-04 issue #3:** the five ARTIFACT verify steps ran rather than skipping on
this run, so their guard is now known to be satisfiable. Whether `upload-artifact` would ALSO succeed on a
fork or Dependabot run (where its `ACTIONS_RUNTIME_TOKEN` differs from `GITHUB_TOKEN`) is still unmeasured —
this run cannot distinguish the two, and the question stays open for Phase 18.

## Decisions Made

See `key-decisions` in the frontmatter. The two most load-bearing:

**The `security_events` refresh was deliberately not fired.** The plan offered
`gh auth refresh -h github.com -s security_events` as a fallback. It is an interactive device-code flow that
would have blocked this run, and it was unnecessary: the repo is public. Running it pre-emptively would have
hung the plan on a problem that did not exist.

**The check-run count matched the wrong hypothesis.** Six new checks is the number one-per-category predicts,
and it is not what happened. Anyone who records "6 new checks, therefore per-category" will mis-predict
Phase 18's required-check list, because the real rule is per-driver and `Trivy` collapses to one entry.

## Deviations from Plan

**1. Criterion 2 was recorded as OBSERVED rather than NOT OBSERVED.** The plan's notes pre-authorised and
bounded a NOT OBSERVED outcome, and 17-04's hand-forward treated annotations as genuinely uncertain
(RESEARCH Q2). The constructed PR produced three real annotations, so the pre-authorised branch was not
taken. Nothing was relaxed, widened or fabricated to get there: no trigger was added, `push: branches:
[main]` was never considered, and the finding is read from the annotations API rather than a screenshot.

**2. Task 2 produced no commit.** By design — the plan declares `<files></files>` for it. Its deliverables are
the pushed branch, PR #8, run 34638828775 and the evidence in this document. Recorded so that
"one commit for a two-task plan" is not read later as a missing atomic commit.

**Total deviations:** 0 auto-fixed. Both entries are outcome/shape notes, not corrective work.
**Impact on plan:** none — the plan executed as written and one uncertain criterion resolved favourably.

## Issues Encountered

**1. The `Checkov` code-scanning check is RED on an otherwise-green PR.** Not a defect in this phase: the
fixtures exist to produce error-severity findings and a code-scanning check reports them faithfully. It is
recorded because Phase 18 is about to decide what becomes merge-blocking, and this is the concrete
consequence of making these checks required on a repo that deliberately carries vulnerable fixtures.

**2. `tflint` emits two SARIF drivers, which nobody had accounted for.** `tflint` and `tflint-errors` in one
file produce two analyses and two check runs under a single category. Harmless here — the error channel is
empty — but it means "one category equals one analysis" is false in this repo, and any future count
assertion on `code-scanning/analyses` must expect seven, not six.

**3. The `gh` 404 carries a misleading scope hint.** The pre-upload
`code-scanning/analyses` 404 is followed by `gh: This API operation needs the "admin:repo_hook" scope`. That
line is the CLI's generic error decoration, not the API's complaint, and reading it as a permission problem
would have sent the plan chasing T-17-22 for nothing.

No unresolved issues.

## User Setup Required

**PR #8 is OPEN and awaiting human sign-off. It must NOT be merged here — 17-07 owns that.**
`https://github.com/OttawaCloudConsulting/security-platform/pull/8`

## Next Phase Readiness

- **17-06 (ADR-016)** is unblocked and now has a live fact to cite: the `sca` job's direct-SARIF change
  produced correctly-based `trivy-fs` results that GitHub ingested (6 results, no path errors), while the
  container job's surviving `trivy convert` produced 56 results that annotate nothing — exactly the
  asymmetry the ADR records.
- **17-07** inherits an open, unmerged, mergeable PR; six categories for Criterion 1; five artifacts with a
  measured 90-day expiry for Criterion 3; and three annotations for Criterion 2. It does not need to
  re-derive any of them, and it should not score Criterion 1 off the unfiltered Security tab.
- **Phase 18** gets: the twelve byte-exact check-run names; the resolved per-driver rule; the red `Checkov`
  check; the analyses-vs-check-runs case mismatch; and one still-open question (whether the artifact verify
  guard is over-tight for fork/Dependabot runs).
- **Phase 19 (VAL-01)** still owns the end-to-end proof, but it inherits a positive annotation result rather
  than an unresolved one.
- **No blockers.**

---
*Phase: 17-sarif-upload-and-artifact-retention*
*Completed: 2026-09-11*
