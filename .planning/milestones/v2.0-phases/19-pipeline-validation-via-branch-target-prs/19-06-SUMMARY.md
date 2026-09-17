---
phase: 19-pipeline-validation-via-branch-target-prs
plan: 06
subsystem: ci-cd
tags: [sc4, clean-pr, report-only, d-06, pull-request, continue-on-error, post-merge, complete]

# Dependency graph
requires:
  - phase: 19-05
    provides: "GATE_MODE DELETED (absent, REST 404); PR #11 OPEN at 426c84c; the five frozen check-run names; the post-merge origin/main 80e91de this branch is cut from"
  - phase: 19-03
    provides: "PR #10's per-job artifact-derived finding counts — the cross-check targets for this run"
  - phase: 19-04
    provides: "SC1 and SC3 closed"
provides:
  - "SC4 MEASURED: PR #12 — the clean-PR probe — five security / … check runs ALL success on head 9483ba5, run 34792868246"
  - "GATE_MODE verified ABSENT at FOUR separate reads — reads 1 and 3 bracket the run, read 2 is CONCURRENT with four jobs' gate_mode resolution — each with both the empty-list and the REST-404 proof"
  - "The POST-merge clean-PR steady state: semgrep 8 total / 3 on fixtures/vulnerable.py; gitleaks 11 total / 2 on fixtures/secret.env"
  - "The full non-zero finding set beside the green verdict: checkov 14 failed, trivy-fs 6, trivy-image 58, tflint 3, npm 2, pip-audit 4 deps / 46 vulns"
  - "PR #12 CLOSED, not merged; PR #11 left OPEN and untouched at 426c84c for plan 07"
  - "The Phase 20 input: fixture permanence blocks this repository's own live blocking-mode adoption"
affects: [19-07, 20]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A 'clean' PR is made by changing one inert non-fixture file on a branch cut from main — never by deleting fixtures, which would destroy the permanent finding baseline"
    - "A green verdict and the non-zero finding counts that produced it are recorded in the SAME table, so 'green' can never be read as 'clean'"
    - "A repo-wide variable whose absence is the measurement's precondition is read at every phase boundary of the plan — before, at PR creation, after the run, and at close — never inherited from a prior plan's claim"

key-files:
  created:
    - .planning/phases/19-pipeline-validation-via-branch-target-prs/19-06-SUMMARY.md
  modified:
    - repos/security-platform/README.md

key-decisions:
  - "SC4 is recorded as FIVE security / … CHECK RUNS CONCLUDING success — never as zero findings. Zero findings is impossible in this repository: fixtures/ is permanent and lives on main, so every PR checks out a deliberately vulnerable tree. The jobs are green because report-only sets continue-on-error: true on every scan step."
  - "The clean branch was cut from origin/main (80e91de) and changes exactly ONE non-fixture file, the repo-root README.md. Manufacturing a clean branch by deleting fixtures was explicitly forbidden and was not done — git diff origin/main -- fixtures/ .github/ scripts/ is empty."
  - "fixtures/README.md was deliberately NOT touched. PR #11 carries an open change to that exact file (the D-19-A correction); editing it here would have created a conflict between two open PRs for no reason."
  - "GATE_MODE was read FOUR times, not once, and each read carries BOTH proofs — the empty gh variable list AND the positive REST 404. Reads 1 (00:28:08Z) and 3 (00:31:25Z) BRACKET the run (created 00:29:47Z, completed 00:30:38Z), and read 2 (00:29:52Z) is CONCURRENT with four of the five jobs' Validate gate_mode step, so the at-run-time claim is bracketed and witnessed rather than inferred."
  - "Pushed WITHOUT --no-verify, following 19-05's deviation 2. The acceptance criterion asks for the hook's ACTUAL behaviour; a bypassed hook produces no observation. Both hooks Passed and GH013 did not fire."
  - "PR #12 was CLOSED, not merged — its README line is not wanted on main. PR #11 was not touched: still OPEN, mergedAt null, closedAt null, head 426c84c, re-read at close."
  - "VAL-01 still NOT marked complete, following 19-01 through 19-05. SC4 is now measured and plan 07 owns VAL-01's closure. requirements.mark-complete was deliberately not invoked."

patterns-established:
  - "Record the metric that would falsify the flattering reading in the same table as the flattering reading itself — five success conclusions beside 14/11/8/58/6/3 findings"
  - "When an expected-value shift is caused by an out-of-band event, state which side of that event the measurement is on and what physically causes the difference (fetch-depth: 0 history scan), rather than letting a future reader diagnose a broken scanner"

requirements-completed: []

# Metrics
duration: 5min
completed: 2026-09-14
---

# Phase 19 Plan 06: SC4 — The Clean-PR Probe Summary

**SC4 is measured. [PR #12](https://github.com/OttawaCloudConsulting/security-platform/pull/12) — a pull
request that seeds NOTHING new, changing exactly one non-fixture file — has all five `security / …` check
runs concluding `success` (run **34792868246**), with `GATE_MODE` verified ABSENT at four separate reads —
two bracketing the run and one concurrent with four jobs' gate-mode resolution, each read carrying both the
empty-list and the REST-`404` proof. And the findings were NOT zero: 8 Semgrep results, 11 Gitleaks
findings, 14 failed Checkov checks, 58 Trivy image vulnerabilities, 6 Trivy filesystem vulnerabilities and
3 tflint results. The five checks are green because report-only sets `continue-on-error: true` on every
scan step — NOT because the tree is clean.**

**STATUS: COMPLETE.** PR #12 is **CLOSED** (`mergedAt: null`). **PR #11 was not touched** — re-read at
close: `OPEN`, `mergedAt: null`, `closedAt: null`, head `426c84c`.

## SC4 — the criterion, and what it does and does not claim

D-06 asks for "a clean pull request with no seeded findings passes all five jobs green". The phrase that
misleads is **"no seeded findings"**. `fixtures/` is permanent by D-04 and lives on `main`, so **every pull
request in this repository forever checks out a tree full of deliberately vulnerable content and produces
findings in all five jobs.** A job is green only because report-only sets `continue-on-error: true` on its
scan step.

So "no seeded findings" means **this PR seeds nothing new** — and SC4's evidence is phrased as *five
`security / …` check runs concluded `success`*, never as *zero findings*. The table below puts both
numbers side by side deliberately, because the contrast IS the criterion.

## THE SC4 TABLE — five green conclusions and the findings that were still there

| `security / …` check run (byte-exact, em dash U+2014) | Conclusion | Job conclusion | Findings this run reported |
|---|---|---|---|
| `security / SAST — Semgrep CE` | **success** | success | **8** results — **3 on `fixtures/vulnerable.py`** |
| `security / Secrets — Gitleaks` | **success** | success | **11** findings — **2 on `fixtures/secret.env`** |
| `security / IaC — Checkov` | **success** | success | **14** failed checks — 12 on `/fixtures/main.tf`, 2 on `/fixtures/Dockerfile` |
| `security / SCA — Trivy Filesystem` | **success** | success | **6** vulns (5 npm + 1 pip) + **3** tflint + npm-audit **2** + pip-audit **4 deps / 46 vulns** |
| `security / Container — Trivy Image` | **success** | success | **58** vulns on `scan-fixture:c308a24a… (debian 12.15)` |

**Five for five `success`. Not one finding count is zero.** The count of non-`success` entries among the
five was queried explicitly and is **0**:

```
[.check_runs[] | select(.name|startswith("security / ")) | select(.conclusion != "success")] | length
  →  0
```

**Never assumed to be five — counted.** The head SHA carries **12** check runs in total; filtering on
`startswith("security / ")` yields exactly **5**.

The seven non-`security / ` check runs, recorded so a later unfiltered query does not read them as drift —
**all seven `success`**, none gated by `GATE_MODE`:

| Check run | App | Conclusion |
|---|---|---|
| `GitGuardian Security Checks` | gitguardian | success |
| `Checkov`, `Semgrep OSS`, `Trivy`, `gitleaks`, `tflint`, `tflint-errors` | github-advanced-security | success |

Note `GitGuardian Security Checks` and `Semgrep OSS` are `success` here, as they were on PR #11 and unlike
on PR #10 — consistent with 19-05's recorded explanation that those two apps report on what a pull request
*introduces*, and this one introduces one prose paragraph.

**Skipped steps anywhere in the run: ZERO.** Queried directly over every step of every job
(`select(.conclusion=="skipped")`), the result set is empty.

## `GATE_MODE` — read FOUR times, each with both proofs

The plan requires the variable to be absent **at the time this run executes**, not merely inherited from
plan 05's claim. It was read four times, and each read carries both the empty-list form and the positive
REST form, because an empty `gh variable list` is indistinguishable from a command that silently produced
nothing:

| # | When | UTC | `gh variable list` | `GET actions/variables/GATE_MODE` |
|---|---|---|---|---|
| 1 | **Start of plan** (Task 1) | `2026-09-14T00:28:08Z` | nothing printed | **`404` Not Found** |
| 2 | **At PR creation / run start** | `2026-09-14T00:29:52Z` | nothing printed | **`404` Not Found** |
| 3 | **AT RUN TIME — after the run completed** (Task 2) | `2026-09-14T00:31:25Z` | nothing printed | **`404` Not Found** |
| 4 | **Plan close** | `2026-09-14T00:33:03Z` | nothing printed | **`404` Not Found** |

**Reads 1 and 3 BRACKET the run, and read 2 is CONCURRENT with it.** The run was created `00:29:47Z` and
completed `00:30:38Z`. Read 1 (`00:28:08Z`) precedes the run entirely and read 3 (`00:31:25Z`) follows its
completion, so there is no window edge inside the run and the absence is **bracketed** rather than inferred.
Read 2 (`00:29:52Z`) is **not** before the run started — it lands *inside* it, within the `00:29:51.9Z` to
`00:29:53.4Z` span in which four of the five jobs resolved `gate_mode`, and ahead of Checkov's resolution at
`00:30:11Z`. Stated precisely rather than loosely, because "read 2 bracketed the run" would be a claim the
timestamps do not support; what read 2 actually gives is a **witness during** gate-mode resolution, which is
stronger evidence for the same point. Task 2's read (#3) is recorded as the at-run-time state **distinct
from** Task 1's start-of-plan read (#1), exactly as the plan requires.

### Anchored gate-mode evidence

| Grep | Count |
|---|---|
| `gate_mode=report-only$` | **5** |
| `gate_mode=blocking$` | **0** |
| `gate_mode=` (UNanchored, context only) | 10 |

The anchor stays load-bearing exactly as 19-03 and 19-05 recorded: the unanchored count is **10** because
each job's `Validate gate_mode` step also echoes its own source line
`blocking|report-only) echo "gate_mode=${GATE_MODE}" ;;` into the log's Run group. One anchored line per job:

| Job | Log line |
|---|---|
| `security / SAST — Semgrep CE` | `00:29:51.9194829Z gate_mode=report-only` |
| `security / Secrets — Gitleaks` | `00:29:52.6575422Z gate_mode=report-only` |
| `security / SCA — Trivy Filesystem` | `00:29:53.1519207Z gate_mode=report-only` |
| `security / Container — Trivy Image` | `00:29:53.4438552Z gate_mode=report-only` |
| `security / IaC — Checkov` | `00:30:11.1313432Z gate_mode=report-only` |

These five `report-only` lines are Phase 18 D-03's fallback chain
`inputs.gate_mode || vars.GATE_MODE || 'report-only'` terminating at its literal, with **no variable
present** — and, like 19-05's run 3, produced *after* a variable had existed and been removed.

## Why the jobs are green — the mechanism, stated

`continue-on-error: true` on every scan step. Measured, not asserted: **10** `##[error]Process completed
with exit code …` lines appear in this run's log, distributed across **four** of the five jobs, and **all
five checks still concluded `success`**:

| Job | `Process completed with exit code …` lines |
|---|---|
| `security / SCA — Trivy Filesystem` | **6** |
| `security / Secrets — Gitleaks` | **2** |
| `security / SAST — Semgrep CE` | **1** |
| `security / Container — Trivy Image` | **1** |
| `security / IaC — Checkov` | **0** |

This distribution is byte-for-byte the same as 19-05's run 1. **Checkov's zero is a property of the GREP,
not of the job** — that string is the Actions runner's format for `run:` shell steps, and Checkov's scan is
a `uses:` step (`bridgecrewio/checkov-action`), so a failing action never emits it. 19-05 settled this by
measurement: under blocking, `Run Checkov` carries `conclusion: failure` in the jobs API. Checkov's step
does fail here too and is tolerated exactly like the other four. **Four jobs exit non-zero, all five
conclude `success` — that is precisely what report-only tolerance means.**

## This is the POST-merge clean-PR case, and here is what follows from it

The plan was originally written while PR #10 was still open, and predicted a branch cut from `main` would
carry NEITHER `fixtures/vulnerable.py` NOR `fixtures/secret.env`. **That is no longer the situation.** On
`2026-09-13T22:34:18Z` the operator merged PR #10 through the GitHub web UI (merge commit `80e91de`),
before SC2 or SC4 were measured, and its head branch was auto-deleted.

`origin/main` was read fresh in this session rather than trusted from the plan's text:

| Read | Result |
|---|---|
| `git rev-parse origin/main` | **`80e91de51812e8ca189dab3107629ad8d501b83d`** |
| `git rev-parse origin/main^{tree}` | `2d7f5ad91315abb0b070ffe634bbfb65b9506df0` |

**Both seeded fixtures are PRESENT on the clean branch — six for six, asserted rather than assumed:**

```
present: fixtures/vulnerable.py     present: fixtures/Dockerfile
present: fixtures/secret.env        present: fixtures/package-lock.json
present: fixtures/main.tf           present: fixtures/requirements.txt
```

That presence is the proof the branch is cut from the POST-merge `main`, and it is what makes the finding
counts above explicable. The plan said an ABSENT fixture would be a finding worth stopping over. Neither
was absent.

### The two assertions the POST-merge side demands

| Assertion | Measured | Detail |
|---|---|---|
| `semgrep-results.json` carries results on `fixtures/vulnerable.py` | **3**, non-zero | `eval-detected` L20, `exec-detected` L24, `subprocess-shell-true` L32 |
| `gitleaks-results.json` carries findings on `fixtures/secret.env` | **2**, non-zero | `aws-access-token` L21, `generic-api-key` L22 |

Both plan-supplied Python assertions exited **0** (they are written to exit **3** if either the total or
the per-fixture count is zero — no silent default, no swallowed exception).

**Why Gitleaks reports the secret fixture on a branch that does not contain a single fixture change.** The
`secrets` job checks out with `fetch-depth: 0` and runs **`gitleaks git .`** — a **HISTORY** scan, not a
working-tree scan. Once `secret.env` is on `main`, it is in the history of **every** branch cut from `main`
from now on. So this job will report it on every future pull request, forever, **by D-04's design**. This is
RESEARCH Pitfall 6 exactly, and it is the difference a future reader would otherwise diagnose as a broken
scanner when comparing this run against a pre-merge one.

`Secret` reads `REDACTED` on every one of the 11 findings — `--redact` is intact on every gitleaks
invocation. The other **9** findings were measured on THIS run's artifact rather than carried over from
19-03, because the `File` clause in the assertion is load-bearing rather than decorative and its
justification deserves a current number:

| Count | RuleID | File |
|---|---|---|
| 5 | `aws-access-token` | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` |
| 2 | `aws-access-token` | `.planning/phases/05-secrets-detection-gate/05-VERIFICATION.md` |
| 1 | `aws-access-token` | `.planning/STATE.md` |
| 1 | `discord-api-token` | `.claude/gsd-file-manifest.json` |

**8 of the 11 are `aws-access-token` in `.planning/` history** — which matches 19-03's figure exactly, and
is now a measurement of this run rather than an inherited one. A count- or non-empty-based check would be
satisfied by those 9 alone, which is precisely why the assertion ANDs the total with the per-file clause.

### The ordering, and how the project arrived at it

**RESEARCH Q3 recommended exactly this ordering** — the clean PR run *after* the fixtures reach `main`, so
that it shows the steady state rather than a transient. That is what happened. **But the project arrived at
it by accident, not by design: the operator merged PR #10 out of band, rather than D-10's ordering being
reversed.** Stated in those terms because a future reader comparing the plan's original prediction against
this SUMMARY's numbers deserves to know which one moved and why.

## Cross-check against 19-03's PR #10 counts — a cross-check, not a pass condition

The scanned fixture files are byte-identical on `main`, so the counts are *expected* to agree; a difference
would be explained, not failed on. Compared **like with like** — 19-03's artifact-derived JSON counts
against this run's artifact-derived JSON counts:

| Metric | 19-03 (PR #10, run `34786019516`) | **This run (PR #12, run `34792868246`)** | Agrees? |
|---|---|---|---|
| Semgrep results total | 8 | **8** | yes |
| Semgrep on `fixtures/vulnerable.py` | 3 (same three rule ids, same lines 20/24/32) | **3** (identical ids and lines) | yes |
| Gitleaks findings total | 11 | **11** | yes |
| Gitleaks on `fixtures/secret.env` | 2 — `aws-access-token` L21, `generic-api-key` L22 | **2** — identical | yes |
| Checkov failed checks | 14 (12 on `/fixtures/main.tf`, 2 on `/fixtures/Dockerfile`) | **14** — identical split | yes |
| Trivy fs vulns | 6 — 5 npm (`package-lock.json`) + 1 pip (`requirements.txt`) | **6** — identical split | yes |
| Trivy image vulns | 58, debian 12.15 | **58**, debian 12.15 | yes |
| tflint results | 3 — `terraform_module_version`, `terraform_required_providers`, `terraform_required_version` | **3** — identical ids | yes |
| npm audit | 2 (1 high, 1 critical) | **2** (1 high, 1 critical) | yes |
| pip-audit | 4 vulnerable deps (`requests`, `jinja2`, `idna`, `urllib3`) | **4** deps / **46** vulns | yes |

**Every row agrees.** Checkov's report is a **list of five framework blocks**, not a single dict, and its
paths carry a **leading slash** (`/fixtures/main.tf`) — both handled as 19-03 recorded, with substring
matching rather than `==`.

**The one difference, explained rather than smoothed over.** The container image tag differs:
`scan-fixture:c308a24a…` here versus `scan-fixture:b6123ab3…` on PR #10. That is
`scan-fixture:${{ github.sha }}`, and on a `pull_request` event `github.sha` is the **PR merge commit** —
confirmed by reading it back: `gh api repos/…/pulls/12 --jq .merge_commit_sha` returns
**`c308a24aa52dec5178d0df7526ef95b9872ea15f`**, byte-identical to the `ArtifactName` in
`trivy-image.json`. **The tag differs per pull request by construction; the base image digest and the 58
vulnerabilities are unchanged.** This is not drift.

### SARIF survived too — seven analyses on `refs/pull/12/merge`

| Analysis id | Category | Tool | `results_count` | 19-05 run 1 | Agrees? |
|---|---|---|---|---|---|
| 1769788544 | `checkov` | checkov | **14** | 14 | yes |
| 1769787862 | `gitleaks` | Gitleaks | **11** | 11 | yes |
| 1769788826 | `semgrep` | Semgrep OSS | **8** | 8 | yes |
| 1769788870 | `tflint` | tflint | **3** | 3 | yes |
| 1769788873 | `tflint` | tflint-errors | **0** | 0 | yes |
| 1769788393 | `trivy-fs` | Trivy | **6** | 6 | yes |
| 1769788304 | `trivy-image` | Trivy | **58** | 58 | yes |

**Seven analyses, six unique categories** — the same set as every other run in this phase.

### Artifacts — `total_count` = 5

| Artifact | Id | Bytes | Contents | Expired |
|---|---|---|---|---|
| `semgrep-results` | 10328429769 | 197,863 | `semgrep-results.json`, `semgrep.sarif` | false |
| `gitleaks-results` | 10328940322 | 10,390 | `gitleaks-results.json`, `gitleaks.sarif` | false |
| `checkov-results` | 10328133471 | 5,149 | `checkov-results.json`, `checkov.sarif` | false |
| `sca-results` | 10328569301 | 19,900 | `npm-audit-1.json`, `pip-audit-1.json`, `tflint.sarif`, `trivy-fs.json`, `trivy-fs.sarif` | false |
| `trivy-image-results` | 10327878757 | 65,218 | `trivy-image.json`, `trivy-image.sarif` | false |

All five retained to `2026-12-13T00:29:47Z`. The few-byte size differences against 19-03's and 19-05's runs
are the same run- and commit-specific embedded values 19-05 documented (scan timestamps, the commit SHA, the
per-commit image tag, absolute runner paths); the authoritative finding-change check is the code-scanning
`results_count` table above, which is identical on every row.

## Task 1 — the clean branch, the inert change, and PR #12

| Item | Value |
|---|---|
| PR #11 at plan start | **`OPEN`**, head `426c84c`, `mergedAt: null`, `closedAt: null` — as 19-05 left it; **no further deviation to record** |
| Open PRs at plan start | exactly one — `#11 / feature/phase-19-gate-mode-proof` |
| `git ls-remote --heads origin feature/phase-19-clean-pr` before | **empty** — no pre-existing remote branch |
| Branch | `feature/phase-19-clean-pr`, `git checkout -B … origin/main` |
| `git diff origin/main --name-only` | **`README.md`** — exactly one path, `1 file changed, 2 insertions(+)`, insertions only |
| `git diff origin/main -- fixtures/ .github/ scripts/ --stat` | **EMPTY** — no fixture, workflow or script change, and no fixture deleted |
| `fixtures/README.md` | **NOT touched** — PR #11 has an open change to that file |
| markdownlint | **Passed**, rc=0 |
| Commit | **`9483ba5265ed30bf58979b599eda3525e3afdd1e`** |

The added line, which is a real factual sentence about a real permanent behaviour rather than a placeholder
or a timestamp:

> Every pull request against `main` runs the CI security pipeline — five parallel scan jobs covering SAST,
> IaC, SCA, container images and secrets. The pipeline runs in report-only mode: each job publishes its
> findings to the repository Security tab and retains them as build artifacts, and reports them without
> blocking the merge.

### The push — OBSERVED, not predicted

| Item | Value |
|---|---|
| Command | `git push -u origin feature/phase-19-clean-pr` — **without `--no-verify`** |
| pre-commit hooks at push | `markdownlint` **Passed**; `Detect hardcoded secrets` (Gitleaks) **Passed** |
| GitHub Push Protection / `GH013` | **did NOT fire** |
| Result | `* [new branch] feature/phase-19-clean-pr`, rc=0 |
| Runs triggered by the push alone | **0** (`gh run list -b … --jq length` → `0`) — no `push:` trigger, as designed |
| `.gitleaksignore` | **not touched**; no fingerprint added |

The prediction in the plan's `<interfaces>` block held — this branch adds one README commit and no new
secret-bearing blobs, and the credential-shaped blobs are already on `main` and were allowed per-blob in
19-03 — but it is recorded here as an **observation** because the push was made with hooks live rather than
bypassed. The Gitleaks hook Passing is the **fourth** independent confirmation of **D-19-C**: it is
`stages: [pre-push]` with a `--staged` entry, so at push time it scans an empty staged diff and is
structurally a no-op, passing here on a tree that indisputably contains a credential-shaped fixture.

### The pull request and its run

| Field | Value |
|---|---|
| Number | **#12** |
| URL | **<https://github.com/OttawaCloudConsulting/security-platform/pull/12>** |
| Base ← head | `main` ← `feature/phase-19-clean-pr` |
| Head SHA | **`9483ba5265ed30bf58979b599eda3525e3afdd1e`** |
| Merge commit (`github.sha` in the run) | `c308a24aa52dec5178d0df7526ef95b9872ea15f` |
| Run id | **34792868246** — `PR Security` / `pull_request` |
| Run conclusion | **success** |
| Created → updated | `2026-09-14T00:29:47Z` → `00:30:38Z` (**51s**) |
| Runs on the branch | **1** — no extra push, no empty commit, no re-run |
| Final state | **`CLOSED`** at `2026-09-14T00:33:02Z`, `mergedAt: null` |

The PR body states all three required things: that it is the Phase 19 SC4 clean-PR probe (D-06), that it
seeds no new findings (with the "green is report-only tolerance, not zero findings" distinction spelled out
in the body itself), and that it would be closed once the five green conclusions were recorded.

## The Phase 20 input — a finding, not a problem solved here

**Because `fixtures/` is permanent and lives on `main`, this repository cannot itself adopt blocking mode
live (Phase 18 D-07 step 3) without first excluding `fixtures/` from the scanners.** Every pull request it
will ever receive checks out the vulnerable tree; under blocking, all five checks go red — 19-05 measured
exactly that on a tree that differed from this one by a single documentation paragraph. **Report-only is
currently the only state in which this repository's own pull requests can merge green.**

This is RESEARCH Pitfall 5's second-order effect, and it recasts D-09's revert: it is not merely cautious
sequencing, it is the only viable state for this repo today. Recorded as an input to Phase 20 — the fix is
a scanner-scope change (exclude `fixtures/`), which is out of scope here and touches files this plan is
forbidden from editing.

## Deviations from Plan

### Intentional divergences

**1. Pushed WITHOUT `--no-verify`.** The plan's action anticipates the hook possibly firing and offers
`--no-verify` as the response. It was deliberately not used, following 19-05's deviation 2: the acceptance
criterion asks for the hook's *actual* behaviour "rather than predicted", and a bypassed hook produces no
observation. Both hooks ran and Passed. Strictly more evidence than asked for, at no cost.

**2. `--head` passed explicitly to `gh pr create`,** following 19-03's and 19-05's precedent — it removes
any dependence on the local branch's tracking state.

**3. `-R OttawaCloudConsulting/security-platform` passed on every `gh` invocation,** following 19-04's
deviation 1. The working directory is the outer docs repo, whose remote is a different repository.

**4. `GATE_MODE` read FOUR times, not twice, and each read carries BOTH proofs.** The plan requires two
reads (start of plan, at run time). Two more were added — one immediately at PR creation and one at plan
close. The result is tighter than the plan asked for: reads 1 and 3 **bracket** the run and read 2 lands
**inside** it, concurrent with four jobs' gate-mode resolution. The REST `404`
was queried alongside every `gh variable list` because an empty list is indistinguishable from a silently
failed command. This follows 19-05's deviation 11 and the project's anti-slop rule that a silent empty
result is not evidence.

**5. A partial SUMMARY was written and committed at the end of Task 1.** Task 2's `read_first` names
`19-06-SUMMARY.md`, so the plan expects it to exist between the two tasks, and it is the only outer-repo
artifact Task 1 produces (`repos/` is gitignored in the outer docs repo). It is fully superseded by this
version.

**6. VAL-01 NOT marked complete.** The plan frontmatter lists `requirements: [VAL-01]` and the executor
template marks listed requirements complete. Withheld, following 19-01 through 19-05 and the 17-01
precedent: **plan 07 owns VAL-01's closure**, and it consolidates SC1-SC4 across the phase.
`requirements-completed: []` on this SUMMARY should be read as withheld on purpose, not as a missed step.

**7. Trivy filesystem's finding count is reported as 6 from `trivy-fs.json`, with the ecosystem sub-scan
numbers alongside it.** The SCA job produces four distinct finding streams (Trivy fs, npm audit, pip-audit,
tflint) into one artifact. Reporting only one of them would understate the job. All four are in the table.

### The plan-level deviation this plan inherits rather than creates

**8. PR #10's out-of-band merge.** Recorded in full by 19-05 and re-verified here from `origin/main`
(`80e91de`, both fixtures present). It is not an executor deviation — it is the condition this plan's
revision was written to absorb, and it is what put this measurement on the POST-merge side.

### Auto-fixed Issues

**None.** No Rule 1, 2 or 3 fix was required. Every command behaved as the plan predicted — including the
predictions that `GH013` would not fire, that all five checks would be green, and that both fixtures would
produce non-zero findings on a branch containing no fixture change.

### Checkpoints

**None.** This plan is `autonomous: true` and defines no checkpoint tasks. No repository-wide variable was
written, nothing was merged, and the only mutation outside this branch was `gh pr close 12` — which the
plan explicitly instructs.

### Authentication gates

None. `gh` was already authenticated. No package was installed and no dependency manifest was touched.

## Issues Encountered

None unresolved. Three observations that could be misread and are not problems:

- **Ten `##[error]Process completed with exit code 1`/`2` lines, and all five checks still `success`.**
  That is `continue-on-error: true` working exactly as report-only intends. It is the mechanism SC4 rests on.
- **Checkov logs zero such lines.** A grep artifact, settled by measurement in 19-05: Checkov's scan is a
  `uses:` step, and that error string is the runner's format for `run:` steps.
- **The container image tag changed** from `scan-fixture:b6123ab3…` to `scan-fixture:c308a24a…`. Explained
  above and confirmed against `pulls/12 --jq .merge_commit_sha`: it is `github.sha`, the PR merge commit,
  different per pull request by construction. The 58 vulnerabilities and the debian 12.15 base are unchanged.

## Post-state — what plan 07 inherits, and what a resumer must not redo

| Item | State |
|---|---|
| **`GATE_MODE`** | **ABSENT** — `gh variable list` prints nothing and the REST endpoint returns `404`, re-read at `00:33:03Z`. Never set by this plan. |
| PR **#12** (clean probe) | **CLOSED** at `00:33:02Z`, `mergedAt: null` — closed on purpose; its README line is not wanted on `main` |
| PR **#11** (gate-mode proof) | **OPEN**, `mergedAt: null`, `closedAt: null`, head `426c84c` — **completely untouched by this plan**; plan 07 owns its fate |
| Runs on `feature/phase-19-clean-pr` | **1** — `34792868246`, success |
| `rules/branches/main` | `deletion`, `non_fast_forward` — unchanged, nothing written |
| `origin/main` | `80e91de…`, unchanged by this plan — nothing was merged |
| Inner repo HEAD | `feature/phase-19-clean-pr` at `9483ba5`, working tree clean, `git diff origin/main --name-only` = `README.md` |
| Stale local branch `feature/phase-19-pipeline-validation` | present at `d8bd09b`, deliberately untouched |
| Artifacts | five, retained to `2026-12-13T00:29:47Z` |
| VAL-01 | **not marked complete** — plan 07's to close |

**What a resumer must NOT redo.** Do not re-open PR #12 or push further commits to
`feature/phase-19-clean-pr` — SC4 is measured and a second run adds a run set a reader must reconcile.
**Do not merge or close PR #11.** Do not touch the ruleset. Do not set `GATE_MODE`.

## State bookkeeping at close — every figure is a command's recorded output

| Command | Output |
|---|---|
| `gsd-sdk query roadmap.update-plan-progress --phase 19` | `{"updated":true,"phase":"19","plan_count":7,"summary_count":6,"status":"In Progress","complete":false}` |
| `gsd-sdk query state.advance-plan` | `{"advanced":true,"previous_plan":6,"current_plan":7,"total_plans":7}` |
| `gsd-sdk query state.record-metric --phase 19 --plan 06 …` | `{"recorded":true,…}` |
| `gsd-sdk query state.add-decision …` (x2) | `{"added":true,…}` each |
| `git diff .planning/ROADMAP.md` | exactly two lines: `- [ ] 19-06-PLAN.md` → `- [x]`, and the progress row `5/7` → **`6/7`**, still `In Progress` |
| `gsd-sdk query state.record-session …` | `updated: ["Last session","Stopped At","Resume File"]` — the `updated` array read, not the `recorded` boolean (D-19-D) |
| `gsd-sdk query state.sync` | `{"synced":true,"changes":["Progress: [██████████] 95% -> [██████████] 97%"]}` — one change, the bar; frontmatter otherwise already in line |
| `gsd-sdk query state.update-progress` | `{"updated":true,"percent":97,"completed":36,"total":37}` |
| `gsd-sdk query state.validate` | `{"valid":true,"warnings":[],"drift":{}}` |

STATE.md now reads `Plan: 7 of 7` with the resume file pointing at `19-07-PLAN.md`.

`requirements.mark-complete` was **deliberately not invoked** — VAL-01 is plan 07's to close (deviation 6).

## Self-Check: PASSED

| Claim | Verification | Result |
|---|---|---|
| This SUMMARY exists at the path the plan names | `[ -f .planning/phases/19-…/19-06-SUMMARY.md ]` | FOUND |
| `must_haves.artifacts[0].contains: success` | frontmatter, banner, the SC4 table (5×), the check-run query | FOUND |
| `key_links[0].pattern: gate_mode=report-only` | anchored grep on `clean-34792868246.log` | **5** occurrences, one per job |
| Clean branch cut from post-merge `origin/main` | `git rev-parse origin/main` + six fixture presence assertions | `80e91de…`, **6/6 present** |
| Exactly one path differs from `origin/main` | `git diff origin/main --name-only` | **`README.md`** |
| Nothing under `fixtures/`, `.github/`, `scripts/` changed | `git diff origin/main -- fixtures/ .github/ scripts/ --stat` | **empty** |
| `fixtures/README.md` untouched (PR #11 collision avoided) | same diff | not listed |
| markdownlint passes | `pre-commit run markdownlint --files README.md` | **Passed**, rc=0 |
| Inner-repo commit `9483ba5` exists | `git log`/`git rev-parse HEAD` | `docs(19-06): note report-only pipeline behaviour in the repo README` |
| Five `security / ` checks, all `success` | `commits/9483ba5…/check-runs`, filtered | **5 × success** |
| Non-`success` count among them | same query, `select(.conclusion != "success") | length` | **0** |
| Check-run list never assumed to be five | `.check_runs | length` | **12** total, 5 after filtering |
| No step skipped anywhere in the run | `runs/34792868246/jobs`, `select(.conclusion=="skipped")` | **empty result set** |
| `GATE_MODE` absent at run time | `gh variable list` + REST at `00:31:25Z` | **nothing printed**, **HTTP `404`** |
| `GATE_MODE` absence bracketed around the run | reads at `00:28:08Z` and `00:31:25Z` vs run `00:29:47Z`→`00:30:38Z` | **bracketed** (reads 1 and 3) |
| `GATE_MODE` absence witnessed DURING gate-mode resolution | read at `00:29:52Z` vs four jobs resolving `00:29:51.9Z`–`00:29:53.4Z` | **concurrent** (read 2) — not a bracket, stated as such |
| Anchored gate-mode counts | greps on the saved log | **report-only=5, blocking=0** |
| Semgrep non-zero, and non-zero on `vulnerable.py` | plan's Python assertion (exits 3 if either is 0) | **8 / 3**, rc=**0** |
| Gitleaks non-zero, and non-zero on `secret.env` | plan's Python assertion (exits 3 if either is 0) | **11 / 2**, rc=**0** |
| Checkov / Trivy fs / Trivy image / tflint non-zero | downloaded artifacts | **14 / 6 / 58 / 3** |
| Artifacts present | `runs/34792868246/artifacts` | `total_count` = **5**, all five names, `expired: false` |
| SARIF present | `code-scanning/analyses?ref=refs/pull/12/merge` | **7** analyses, 6 categories, counts identical |
| Cross-check vs 19-03's PR #10 | ten-row table | **every row agrees**; the one difference (image tag) explained and verified against `merge_commit_sha` |
| Clean PR CLOSED | `gh pr list --head feature/phase-19-clean-pr --state all --json` | **`CLOSED`**, `mergedAt: null` |
| PR #11 untouched | `gh pr list --head feature/phase-19-gate-mode-proof --state all --json` | **`OPEN`**, `mergedAt: null`, `closedAt: null`, head `426c84c` |
| Ruleset not written | `gh api …/rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` |
| `requirements-completed` still `[]` | frontmatter | PASS — withheld on purpose (deviation 6) |

Every figure in this SUMMARY was read from a command's recorded output. No number is carried over from the
plan's text or from a prior SUMMARY except where it is explicitly labelled as a cross-check target.
