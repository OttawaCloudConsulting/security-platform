---
phase: 17-sarif-upload-and-artifact-retention
plan: 07
subsystem: ci-cd
tags: [merge, pull-request, human-sign-off, sarif, code-scanning, artifact-retention, phase-close]

# Dependency graph
requires:
  - phase: 17-sarif-upload-and-artifact-retention
    provides: "17-05's live evidence (PR #8, run 34638828775, six categories, five artifacts, three annotations, twelve check runs) — the material put in front of the user before the merge decision"
  - phase: 17-sarif-upload-and-artifact-retention
    provides: "17-06's ADR-016 and the copy-pasteable blueprint CI/CD template, so the sign-off cites written decisions rather than restating them"
  - phase: 16-sca-ecosystem-coverage
    provides: "16-07's merge-and-close procedure — `gh pr merge --merge` without `--delete-branch`, then verification against `origin/main` rather than the local tree"
provides:
  - "MERGED: PR #8 merged to OttawaCloudConsulting/security-platform main via --merge, commit 8fbea7d169ab79c31cb77cd18b835ff3ffb14633"
  - "origin/main confirmed carrying 6 categorised upload-sarif steps, 5 named artifacts at retention-days: 90, workflow-level security-events: write, 5 jobs, 0 needs:, and the 5 byte-identical job names"
  - "origin/main:.github/workflows/pr-security.yml confirmed carrying job-level security-events: write + contents: read on the `security` job"
  - "An honest criterion-by-criterion verdict: 2, 3 and 4 met; 1 NOT OBSERVED in the Security-tab UI with a named cause, and handed forward"
  - "The Phase 18 hand-forward set: twelve byte-exact check-run names, the live tool.name values, the per-driver rule, the red Checkov check, the analyses-vs-check-runs case mismatch, and the fact that nothing is yet required"
affects: [18-gate-mode-and-branch-protection, 19-validation, 20-distribution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A criterion whose only evidence path is a UI observation gets a NOT OBSERVED verdict with a named cause, not a MET inferred from the API result that happens to agree with it"
    - "Post-merge invariants are re-parsed from `git show origin/main:<path>` by yaml.safe_load, never from the local working tree — the local checkout stays on the feature branch throughout"

key-files:
  created:
    - .planning/phases/17-sarif-upload-and-artifact-retention/17-07-SUMMARY.md
  modified:
    - .planning/ROADMAP.md
    - .planning/STATE.md

key-decisions:
  - "Merged with `gh pr merge --repo OttawaCloudConsulting/security-platform 8 --merge` — a merge commit, matching PR #6 (e8e1009) and PR #7 (40682ce) — and deliberately WITHOUT --delete-branch, so gh's local-branch side effects cannot act on the outer documentation repo, which shares the remote URL but is a separate checkout on an unrelated branch (16-07's reasoning, reapplied)"
  - "Criterion 1 is recorded NOT OBSERVED, not MET. The user looked and the Security > Code scanning view showed no results, which they attribute to code scanning possibly not being fully enabled at the repository level. 17-05's analyses API read proves six distinct categories exist server-side and the user confirms per-tool separation IS visible on the PR's Checks tab — but neither of those is the question Criterion 1 asks, which is about the Security tab under the branch/PR filter. Scoring it MET off the API would be exactly the substitution T-17-30 exists to prevent."
  - "No filtered Security-tab URL was captured. The plan asked for one verbatim; the user's observation was of the unfiltered `…/security/code-scanning` view. Recording a URL the user did not land on would be fabrication, so the gap is recorded as a gap and handed forward with the two things that would discriminate the cause."
  - "REQUIREMENTS.md was NOT edited. CICD-02 and CICD-03 were already `[x]` in the CI/CD Pipeline list and already `Complete` in the traceability table, marked by 17-03's and 17-04's requirements-completed metadata (commit 997ae65). The plan's grep verify was run and confirms the state; this plan reports it as confirmed, not as marked here — 16-07's precedent for the same situation."
  - "The red `Checkov` code-scanning check was NOT treated as a merge blocker. It concluded `failure` on findings the fixtures exist to produce, while all five `security / *` job checks were green and the PR stayed MERGEABLE. Nothing was added to any required-check list; T-17-23 held and the decision stays Phase 18's."

patterns-established:
  - "Pattern: when the machine evidence and the human observation disagree about the SAME criterion, record both and let the criterion take the weaker verdict. The disagreement is the finding — here it isolates a repo-settings question (is code scanning enabled?) that no amount of workflow YAML would have surfaced."
  - "Pattern: a phase can close with an open question. Criterion 1's UI gap is handed to Phase 18/19 with the exact next probes, rather than blocking a merge the user explicitly approved on evidence they found sufficient."

requirements-completed: [CICD-02, CICD-03]

# Metrics
duration: ~8min
completed: 2026-09-11
---

# Phase 17 Plan 07: Merged On An Explicit Approval, With One Criterion Honestly Unobserved

**PR #8 is MERGED to `OttawaCloudConsulting/security-platform` `main` (merge commit `8fbea7d169ab79c31cb77cd18b835ff3ffb14633`) on the user's literal approval; `origin/main` — not the local tree — is re-parsed and confirmed to carry all six categorised SARIF uploads, all five 90-day artifacts and both permission grants; and Criterion 1 closes as NOT OBSERVED with a named cause rather than as a MET borrowed from the API.**

## Performance

- **Duration:** ~8 min (Task 2 only — Task 1's checkpoint was answered in the preceding turn)
- **Merged at:** 2026-09-11T20:02:53Z
- **Tasks:** 2 of 2
- **Files modified:** 0 source files in `repos/security-platform` by this executor — the merge lands the diff authored across 17-01..17-05. Outer repo: this SUMMARY + ROADMAP + STATE.

## Task 1 — Human verification (checkpoint, `gate="blocking"`)

The evidence was presented before the question was asked, quoting `17-05-SUMMARY.md`: PR #8's URL, the
six categories with their live `tool.name` values, the five artifacts with sizes and `expires_at`, the
`sca-results` file listing, the twelve check-run names, and `fixtures/main.tf` line 38 as the line the
fixture edit was constructed to touch.

### The user's literal answers, recorded verbatim

**Criterion 1** — *is each scanner's output listed separately under the Security tab's branch/PR filter?*

> **"URL to code-scanning shows no results, I do not think it is properly enabled in the repo. On PR#8 I see checks uploaded to conversation, and under checks tab I see the results for each tool."**

**Criterion 2** — *does an inline annotation appear on `fixtures/main.tf` line 38?*

> **"MET — annotations visible"**

**Criterion 4** — *npm-audit/pip-audit in the `sca-results` artifact, `trivy convert` as the documented conversion path — still matches intent?*

> **"Yes, confirmed"**

**90-day artifact retention, and the merge decision:**

> **"approved — satisfied, merge it"**

Nothing was merged, pushed or modified before that response. The merge approval is explicit and
literal; `workflow.auto_advance` was not applied to this gate.

## The four criteria, one verdict each

### Criterion 1 — Security > Code scanning shows findings attributed to each scanner separately → **NOT OBSERVED**

**Named cause:** the Security > Code scanning UI showed **no results** under the branch/PR filter, which
the user attributes to code scanning possibly **not being fully enabled at the repository level** — a
GitHub Advanced Security / repository-settings question, **not a workflow defect**.

What *was* seen, and what it does and does not prove:

| Evidence | Source | What it shows |
|---|---|---|
| Per-tool results visible and separated on PR #8's **Checks** tab; checks also surfaced in the conversation timeline | the user, live | Separation is real and visible to a reviewer — but on the Checks tab, which is not the surface Criterion 1 names |
| Six **distinct** categories on `refs/pull/8/merge` — `checkov`, `gitleaks`, `semgrep`, `tflint`, `trivy-fs`, `trivy-image` | 17-05 §3, `code-scanning/analyses` API | The uploads landed server-side and no tool overwrote another's results. The upload did **not** fail |
| Security > Code scanning view, unfiltered and as the user opened it | the user, live | Empty |

**This is a UI-enablement discrepancy handed forward, not evidence that the upload failed.** The
server-side state and the UI disagree; the criterion asks about the UI, so the criterion takes the
weaker verdict.

**No filtered Security-tab URL was captured.** The plan asked for one verbatim and the honest answer is
that the user's observation was of `https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning`
with no branch/PR filter applied. Nothing is recorded as "the URL the user landed on" because no such
URL exists in their answer.

**Handed to Phase 18 (and Phase 19 for the end-to-end proof) — the two probes that discriminate the
cause:**

1. The canonical filtered URL to try:
   `https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning?query=pr%3A8`
   (or the equivalent branch filter on `feature/phase-17-sarif-upload-and-artifact-retention`). If
   alerts appear here, the cause was the unfiltered view, exactly as D-02 predicts — `main` has never
   been analysed.
2. **Settings → Code security → Code scanning** on `OttawaCloudConsulting/security-platform`. If the
   feature is not enabled there, that is the cause, and it is a repo-settings action item that no
   workflow change addresses. Note that 17-05 read `code-scanning/analyses` successfully on a token
   carrying **no** `security_events` scope, so an API-permission explanation is already ruled out.

### Criterion 2 — findings appear as inline annotations on the PR diff → **MET**

The user's words: **"MET — annotations visible"**.

Corroborated by 17-05 §7's API read of `GET /repos/…/check-runs/{id}/annotations`: three annotations,
all on `fixtures/main.tf` line 38 — `tflint` `terraform_module_version` (warning, 38-38) and Checkov
`CKV_TF_1` / `CKV_TF_2` (failure, 38-42) — and **zero** from `tflint-errors`, `Semgrep OSS`, `Trivy` and
`gitleaks`, whose 88 other results do not sit on a changed line. RESEARCH Open Question Q2 is answered
**YES**: annotations render with no base analysis on `main` to diff against, so D-02's
`pull_request`-only trigger does not suppress them. The pre-authorised NOT OBSERVED branch was not
taken, and no trigger was widened to get there.

### Criterion 3 — every run leaves downloadable JSON artifacts with an explicit retention period → **MET** (machine evidence, 17-05)

Five artifacts on run 34638828775, five distinct names, every size non-zero, every `expires_at` exactly
`2026-12-10T19:26:17Z` — **exactly 90 days** after the run's `created_at` (17-05 §4):

| Artifact | `size_in_bytes` | `expires_at` |
|---|---|---|
| `semgrep-results` | 195880 | 2026-12-10T19:26:17Z |
| `checkov-results` | 5178 | 2026-12-10T19:26:17Z |
| `sca-results` | 19909 | 2026-12-10T19:26:17Z |
| `trivy-image-results` | 63966 | 2026-12-10T19:26:17Z |
| `gitleaks-results` | 9442 | 2026-12-10T19:26:17Z |

The SCA sub-scans are inside the artifact, not merely claimed to be — `gh run download … -n sca-results`
(17-05 §5) yielded `npm-audit-1.json` (5242 B), `pip-audit-1.json` (48204 B), `tflint.sarif`,
`trivy-fs.json` and `trivy-fs.sarif`. The `-1` suffix is 16-04's per-input numbering, which is why the
glob-based path in 17-04 was necessary; a literal `npm-audit.json` would have retained nothing silently.

The user accepted the 90-day period explicitly — **"approved — satisfied, merge it"** — knowing
DefectDojo (DEFECT-01) is a later milestone and that 90 days is the maximum without changing repository
settings.

### Criterion 4 — a tool without native SARIF still reaches the Security tab or the artifact set through a documented conversion step → **MET / confirmed by the user**

The user's words: **"Yes, confirmed"**.

The reading they confirmed: npm audit and pip-audit reach the **artifact set** (`sca-results`), **not**
the Security tab, and `trivy convert` survives in the container job as the documented conversion step.
Both are recorded in ADR-016 by 17-06, so this is a confirmation of a written decision (D-01), not an
undocumented reading.

## Task 2 — Merge, verify from the remote, close the record

### 1. The merge

```
gh pr merge --repo OttawaCloudConsulting/security-platform 8 --merge
```

| Field | Value |
|---|---|
| PR state | **`MERGED`** |
| **Merge commit SHA** | **`8fbea7d169ab79c31cb77cd18b835ff3ffb14633`** (`8fbea7d`) |
| Merged at | `2026-09-11T20:02:53Z` |
| Merged by | `OttawaCloudConsulting` (OCC) |
| Merge type | `--merge` — a merge commit, not squash, not rebase (PR #6 / PR #7 precedent) |
| Parents | `40682ce` (Phase 16's merge commit) + `fbe0071` (17-05's head SHA) |

`--delete-branch` was deliberately not used.

```
commit 8fbea7d169ab79c31cb77cd18b835ff3ffb14633
Merge: 40682ce fbe0071
    Merge pull request #8 from OttawaCloudConsulting/feature/phase-17-sarif-upload-and-artifact-retention
    Phase 17: SARIF upload to the Security tab and 90-day artifact retention

 .github/workflows/pr-security.yml |  22 ++
 .github/workflows/security.yml    | 554 +++++++++++++++++++++++++++++++++++++-
 fixtures/main.tf                  |   4 +-
 scripts/check-workflow-uploads.sh | 326 ++++++++++++++++++++++
 scripts/smoke-scans.sh            |  57 +++-
 5 files changed, 954 insertions(+), 9 deletions(-)
```

### 2. Verified from `origin/main`, never from the local working tree

`git -C repos/security-platform fetch origin` moved `origin/main` `40682ce..8fbea7d`. Every assertion
below was run on content extracted with `git show origin/main:<path>` and parsed with `yaml.safe_load`.
The local nested checkout stayed on `feature/phase-17-sarif-upload-and-artifact-retention` throughout —
it was never checked out to `main`, so no assertion could have read a local file by accident.

**`origin/main:.github/workflows/security.yml`** — raw output:

```
origin/main carries 6 categorised uploads, 5 named artifacts at 90 days, 5 jobs, frozen names
categories: ['checkov', 'gitleaks', 'semgrep', 'tflint', 'trivy-fs', 'trivy-image']
artifacts: ['checkov-results', 'gitleaks-results', 'sca-results', 'semgrep-results', 'trivy-image-results']
job names bytes: ['5341535420e280942053656d67726570204345']
```

Asserted and passed on the merged content: exactly **6** `upload-sarif` steps carrying the six distinct
categories; exactly **5** `upload-artifact` steps with **5** distinct names and `retention-days: 90` on
every one; workflow-level `permissions.security-events == 'write'`; exactly **5** jobs with **zero**
`needs:` keys; and the five job names byte-identical to the frozen list
`['SAST — Semgrep CE', 'IaC — Checkov', 'SCA — Trivy Filesystem', 'Container — Trivy Image', 'Secrets — Gitleaks']`.
The hex dump of the first name shows `e2 80 94` — the em dash U+2014 survived the merge intact, which is
what Phase 18's required-check list depends on.

**`origin/main:.github/workflows/pr-security.yml`** — raw output:

```
origin/main caller grants security-events: write at job level
caller security job permissions: {'contents': 'read', 'security-events': 'write', 'actions': 'read'}
```

`security-events: write` and `contents: read` both present on the `security` job, as required. The
`actions: read` grant is also present (17-01's addition, needed for the artifact-listing reads).

**T-17-04 re-checked on the merged content:** `--redact` appears **2** times in
`origin/main:.github/workflows/security.yml` — both Gitleaks invocations, so no world-downloadable
artifact on this public repo carries unredacted secrets.

### 3. Documentation close-out

**`.planning/ROADMAP.md`** — three edits:

- The v2.0 milestone list: Phase 17 `[ ]` → `[x]`, with `(completed 2026-09-11)`.
- The Phase 17 plan list: `17-07-PLAN.md` `[ ]` → `[x]`. **All seven plan checkboxes now ticked.**
- The progress table: `| 17. SARIF Upload and Artifact Retention | v2.0 | 7/7 | Complete    | 2026-09-11 |`
  (was `6/7 | In Progress`).

**`.planning/REQUIREMENTS.md`** — **not modified, and deliberately so.** CICD-02 and CICD-03 were
already `[x]` in the CI/CD Pipeline list and already `| Phase 17 | Complete |` in the traceability
table, marked by 17-03's and 17-04's `requirements-completed` metadata (commit `997ae65`). The plan's
grep verify was run and confirms all four conditions hold. This plan **confirms** the marking rather
than claiming to have done it — the same situation 16-07 recorded for SCA-01/02/03. Writing a no-op
edit to satisfy the task wording would have produced a false diff.

**`.planning/STATE.md`** — Phase 17 marked COMPLETE with the merge commit, `completed_phases` 3 → 4,
`completed_plans` 21 → 22, focus advanced to Phase 18.

## Hand-forwards for Phase 18

**1. The twelve byte-exact check-run names on head SHA `fbe0071d6934d19524f5bf9345e91396080fa882`**, as
GitHub reported them (17-05 §6, `total_count: 12`):

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
```

Six of these are 16-05's baseline (five `security / …` job checks plus the external GitGuardian app),
unchanged and byte-identical. The other **six are new `github-advanced-security` checks** added by this
phase's code-scanning uploads.

**2. The live `tool.name` values** from `code-scanning/analyses` (17-05 §3) — these are what the
analyses endpoint reports, and they are **not** interchangeable with the check-run names above:

| Category | Live `tool.name` | `tool.version` | `results_count` |
|---|---|---|---|
| `tflint` | **`tflint-errors`** | 0.64.0 | 0 |
| `tflint` | `tflint` | 0.64.0 | 3 |
| `semgrep` | **`Semgrep OSS`** — *not* `Semgrep` | 1.177.0 | 3 |
| `trivy-fs` | `Trivy` | 0.74.0 | 6 |
| `checkov` | **`checkov`** (lowercase) | 3.3.17 | 14 |
| `trivy-image` | `Trivy` | 0.74.0 | 56 |
| `gitleaks` | **`Gitleaks`** (capitalised) | v8.0.0 | 9 |

**3. Nothing was added to any required-check list.** T-17-23 held through this merge. Phase 18 owns that
decision and must make it deliberately: a code-scanning check that is `neutral` when no alerts are found
behaves differently from a job check that is `success`.

**4. The red `Checkov` check.** On PR #8 the `Checkov` code-scanning check concluded **`failure`** while
every one of the five `security / *` job checks concluded `success` and the PR remained `MERGEABLE` — and
it merged. A code-scanning check fails when its analysis carries `error`-severity alerts, which the
fixtures exist to produce. **Making these checks required would have blocked this very PR.** This is an
observation, not a recommendation.

**5. The analyses-vs-check-runs case mismatch — a trap for the required-check list.** The two endpoints
disagree on case for two tools: analyses say `checkov` and `Gitleaks`; check runs say `Checkov` and
`gitleaks`. **Branch protection matches the check-run name.** Build the list from
`commits/{sha}/check-runs`, never from `code-scanning/analyses`.

**6. Code scanning adds one check per `tool.driver.name`, NOT per category — and the count misleads.**
The per-driver hypothesis predicted 5 new checks and the per-category hypothesis predicted 6, because
`Trivy` owns two categories. Observed: **6 new checks, and the rule is per-driver.** `Trivy` appears
exactly **once** despite `trivy-fs` and `trivy-image` both being live; the sixth check is
`tflint-errors`, tflint's second SARIF driver in a single file under a single category. Reading the
count alone confirms the wrong hypothesis. Phase 18 must enumerate **drivers**, not categories, to
predict this list — and must expect **seven** analyses for six categories.

**7. Still open, inherited from 17-04/17-05.** Whether `upload-artifact` succeeds on a fork or Dependabot
run (where `ACTIONS_RUNTIME_TOKEN` differs from `GITHUB_TOKEN`) is unmeasured — run 34638828775 was a
same-repo, non-Dependabot PR, so all eleven intolerant assertions ran rather than skipping and the run
cannot distinguish the two cases.

**8. Criterion 1's UI gap**, with the two discriminating probes — see the Criterion 1 section above.
Phase 19 (VAL-01) owns the end-to-end proof; Phase 18 will touch repository settings anyway for branch
protection and is the natural place to check whether code scanning is enabled at the repo level.

## Deviations from Plan

**1. `.planning/REQUIREMENTS.md` was not modified.** The plan's action says to mark CICD-02 and CICD-03
`[x]` and set their traceability rows to Complete; both were already in that exact state from commit
`997ae65`. The plan's own grep verify passes on the unmodified file. Reported as confirmed rather than
claimed — 16-07 set this precedent for SCA-01/02/03.

**2. No filtered Security-tab URL is recorded.** The plan's `<output>` requires the URL the user landed
on verbatim. The user's observation was of the unfiltered view; inventing a filtered URL they did not
visit would be fabrication. The gap is recorded, with the canonical URL to *try* clearly labelled as a
Phase 18/19 next step rather than as an observation.

**3. Criterion 1 closes NOT OBSERVED although 17-05's API read is unambiguous.** The plan pre-authorised
NOT OBSERVED as a legitimate outcome and forbids scoring a criterion off evidence that answers a
different question. The API proves the uploads are distinct server-side; it does not prove the Security
tab renders them, which is what Criterion 1 asks.

**Total deviations:** 0 auto-fixed, 0 corrective. All three are honesty/shape notes.
**Impact on plan:** none — the plan executed as written and the merge proceeded on an explicit approval.

## Issues Encountered

**1. The Security > Code scanning view is empty for the user while the API returns seven analyses.**
Unresolved by design — it is a repository-settings question, not a workflow defect, and the merge was
approved on the evidence the user did find sufficient. Two discriminating probes are recorded above.
This is the phase's one open item.

**2. The red `Checkov` check merged without blocking.** Correct behaviour today (nothing is required),
and recorded because Phase 18 is about to change exactly that.

No blockers.

## User Setup Required

**One item, for whoever opens Phase 18:** check **Settings → Code security → Code scanning** on
`OttawaCloudConsulting/security-platform` and try
`https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning?query=pr%3A8`. One of
those two closes Criterion 1's gap.

## Next Phase Readiness

- **Phase 18** inherits a merged `main` carrying the full upload and retention machinery, the twelve
  byte-exact check-run names, the per-driver rule, the case mismatch, the red `Checkov` check, and an
  empty required-check list it is free to populate deliberately.
- **Phase 19 (VAL-01)** inherits a positive annotation result (three annotations on a changed line) plus
  Criterion 1's open UI question.
- **Phase 20** inherits a blueprint CI/CD template that is copy-pasteable as of 17-06.
- **No blockers.**

---
*Phase: 17-sarif-upload-and-artifact-retention*
*Completed: 2026-09-11*
