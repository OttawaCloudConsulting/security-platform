---
phase: 19-pipeline-validation-via-branch-target-prs
plan: 05
subsystem: ci-cd
tags: [gate-mode, blocking, report-only, pull-request, push-protection, sc2, d-09, checkpoint, complete]

# Dependency graph
requires:
  - phase: 19-03
    provides: the preflight baseline (gh variable list EMPTY), the five frozen check-run names, the five artifact names, and PR #10's report-only evidence used for SHAPE only
  - phase: 19-04
    provides: SC1 and SC3 closed against PR #10 before it was merged out of band
  - phase: 18-05
    provides: the four-table evidence shape and the ~2.5 minute flip-window precedent
provides:
  - "the PR #10 out-of-band-merge deviation record, read live: MERGED 2026-09-13T22:34:18Z, merge commit 80e91de, head branch deleted"
  - "PR #11 — the REPLACEMENT Phase 19 gate-mode validation PR, OPEN at head 426c84c, three commits, ONE tree 895c1bdf"
  - "run 34790727189 — the report-only BASELINE this plan's blocking run is paired against"
  - "the D-19-A action: fixtures/README.md now documents the server-side Push Protection layer"
  - "run 1's code-scanning category set and artifact manifest, the comparison targets for the blocking run"
  - "SC2 MEASURED: run 34791497579 — five security / … checks all FAILURE under GATE_MODE=blocking on tree 895c1bdf"
  - "run 34791562222 — five success under the restored absent-variable fallback, same tree 895c1bdf"
  - "D-09 EXECUTED: GATE_MODE deleted (not set to report-only); gh variable list empty and the REST endpoint 404s"
  - "the bounded flip window 2026-09-14T00:04:10Z → 00:05:13Z (63s) with its collateral-run enumeration: exactly one run, the measurement's own"
affects: [19-06, 19-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A replacement PR is cut from post-merge origin/main so its checkout carries the seeded fixtures without re-seeding them"
    - "The PR's diff is a documentation correction that changes no measured count, asserted by grepping four measured-count strings on BOTH origin/main and the branch"
    - "The push was made WITHOUT --no-verify, so the pre-push hook's behaviour is observed rather than bypassed and predicted"

key-files:
  created:
    - .planning/phases/19-pipeline-validation-via-branch-target-prs/19-05-SUMMARY.md
  modified:
    - repos/security-platform/fixtures/README.md

key-decisions:
  - "COMPLETE. Task 3's blocking checkpoint — the D-09 restore CONFIRMATION — was answered `approved`, which is the last must_haves truth ('A human has confirmed the paired evidence and that no GATE_MODE variable remains'). Only then was roadmap.update-plan-progress run, ticking 19-05 to 5/7; the two earlier sessions withheld that tick on purpose and said so."
  - "The plan halted TWICE at blocking checkpoints across three sessions, and neither halt was auto-approved. Task 1's authorised a repo-wide gating window before it opened; Task 3's confirmed a restore that had already happened. Both replies are recorded verbatim and both are labelled as relayed through the orchestrating agent rather than read from the operator directly."
  - "The whole set→measure→delete window ran inside ONE shell invocation, chained with ';' rather than '&&', so gh variable delete executes whatever any earlier command returns. Shell state does not persist between tool calls in this harness, so splitting the window across calls would make a session death between set and delete leave the repository permanently gating every PR — exactly T-19-20."
  - "The blocking empty commit was created BEFORE the variable was set, so no commit-time hook work happened inside the live window."
  - "All detailed measurement was done AFTER the delete. A completed run's logs, check runs, artifacts and analyses are immutable, so nothing measured needed the variable live; this cut the window to 63s against 18-05's ~2.5min precedent."
  - "Per-step evidence was taken from the jobs REST API, not from a log grep. 'Which step failed first' and 'was any post-scan step skipped' are structured fields there; run 1's near-miss (a mis-attributed annotation, then a grep-pattern artifact) was caused by reading step outcomes out of log text."
  - "Session 1 HALTED at Task 1's blocking checkpoint, and did not auto-approve it. auto_advance was unset and workflow._auto_chain_active is false, the plan is autonomous:false, and the checkpoint AUTHORISES a repository-wide blocking window before it opens. Auto-approving would have opened that window on the executor's own authority."
  - "Pushed WITHOUT --no-verify, deliberately. The plan asked for the hook's ACTUAL behaviour rather than a prediction; bypassing it would have produced no observation. The hook ran (`Detect hardcoded secrets`) and Passed, re-confirming D-19-C at push scope for a third time."
  - "GATE_MODE was NOT set. Nothing was flipped, merged, closed, or written to the ruleset in this task."
  - "VAL-01 still NOT marked complete even at plan close — following 19-01 through 19-04 and the 17-01 precedent. SC2 is now measured and SC4 is not; plan 07 owns VAL-01's closure. requirements.mark-complete was deliberately not invoked."

patterns-established:
  - "When the pull request an evidence chain is scoped to disappears out of band, record the disappearance as a live-read fact and rebuild the claim on a substitute whose equivalence is SHOWN (six fixture paths asserted present) rather than argued"
  - "A repo-wide destructive-by-default toggle is opened and closed inside a SINGLE shell invocation, ';'-chained so the restore cannot be orphaned by a failure or a session death; everything that does not need the toggle live is moved outside the window"
  - "Isolate the variable under test by making the tree byte-identical: three commits, two of them empty, one tree hash, an empty git diff between the outer two — the opposite verdicts then have exactly one possible cause"
  - "Read step-level outcomes from the Actions jobs REST API rather than grepping run logs; 'first failing step' and 'skipped' are structured fields, and log text invites mis-attribution"

requirements-completed: []

# Metrics
duration: 18min (Task 1) + 14min (Task 2 and the second halt) + 6min (Task 3 confirmation and close)
completed: 2026-09-14
---

# Phase 19 Plan 05: Prove the Gate Actually Gates Summary

**SC2 is measured. One pull request — [PR
#11](https://github.com/OttawaCloudConsulting/security-platform/pull/11) — three commits, ONE tree hash
`895c1bdf`, an empty `git diff` between the outer two, and OPPOSITE VERDICTS: five `security / …` checks all
`failure` under `GATE_MODE=blocking` (run **34791497579**) and all `success` under report-only both before
(run **34790727189**) and after (run **34791562222**). Nothing was edited between them — one `gh variable
set` and one `gh variable delete` are the entire difference. The reporting guarantees were COUNTED under
blocking, not inferred: five artifacts, seven code-scanning analyses with identical `results_count` on every
row, and all eleven intolerant upload-verify assertions green with ZERO skipped steps anywhere in the run.**

**D-09 is executed. `GATE_MODE` is DELETED, not set back to a string** — `gh variable list` prints nothing
and `GET /actions/variables/GATE_MODE` returns `404`, which is the repository's original state and is what
exercises Phase 18 D-03's fallback terminating at the literal. The repository-wide window ran
**2026-09-14T00:04:10Z → 00:05:13Z, 63 seconds**, and exactly **one** run was created inside it: the
measurement's own.

**STATUS: COMPLETE.** Both blocking checkpoints were answered: Task 1 with `go` (authorising the window
before it opened) and Task 3 with **`approved`** (confirming the paired verdicts and the restore). Task 3 was
the **D-09 restore CONFIRMATION** — it did not gate the restore, which had already happened unconditionally
inside Task 2; it asked a human to confirm the paired verdicts and that no variable remains. See [Operator
Reply (Task 3) — RECEIVED](#operator-reply-task-3--received). **PR #11 is deliberately left OPEN** — plan 07
owns its fate, and plan 06 needs it open. Re-read at close: `state: OPEN`, `mergedAt: null`,
`closedAt: null`, head `426c84c`.

## The deviation this plan exists to absorb — PR #10, read live

Read in this session, not carried over from the plan's text:

```
$ gh pr view 10 -R OttawaCloudConsulting/security-platform \
    --json number,state,mergedAt,mergeCommit,headRefName
{"headRefName":"feature/phase-19-pipeline-validation",
 "mergeCommit":{"oid":"80e91de51812e8ca189dab3107629ad8d501b83d"},
 "mergedAt":"2026-09-13T22:34:18Z","number":10,"state":"MERGED"}
```

| Field | Value, verbatim |
|---|---|
| `number` | **10** |
| `state` | **`MERGED`** |
| `mergedAt` | **`2026-09-13T22:34:18Z`** |
| `mergeCommit.oid` | **`80e91de51812e8ca189dab3107629ad8d501b83d`** |
| `headRefName` | `feature/phase-19-pipeline-validation` |
| `git ls-remote --heads origin \| grep -c 'feature/phase-19-pipeline-validation'` | **0** — the head branch was auto-deleted |

**Stated plainly: the merge happened outside the planned flow.** Plan 07 was to be the only point in this
phase where PR #10's fate was decided. The merge landed after 19-04 closed SC1 and SC3 and **before SC2 or
SC4 were measured**. PR #10 and its branch therefore no longer exist to re-run, and SC2's literal wording —
"that **same** pull request" — is no longer satisfiable. SC2's essential claim is, and that is what this plan
proves: **one pull request, two gate modes, opposite verdicts, byte-identical trees, nothing edited between
them.** The substitution is recorded here as a deviation rather than smoothed over, and plan 07 consolidates
it.

The `git fetch origin --prune` that produced the ls-remote result also pruned two now-deleted remote
branches, recorded as observed:

```
 - [deleted]  (none) -> origin/feature/phase-17-sarif-upload-and-artifact-retention
 - [deleted]  (none) -> origin/feature/phase-19-pipeline-validation
```

The stale **local** branch `feature/phase-19-pipeline-validation` at `d8bd09b` is still present and was
deliberately left alone — not deleted, not renamed, not pushed. Its commits are already on `main` via the
merge.

## What that merge delivered — read from `origin/main`, never from the local tree

| Read | Result |
|---|---|
| `git rev-parse origin/main` | **`80e91de51812e8ca189dab3107629ad8d501b83d`** |
| `git rev-parse origin/main^{tree}` | **`2d7f5ad91315abb0b070ffe634bbfb65b9506df0`** |
| `git show origin/main:fixtures/vulnerable.py \| head -1` | `# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX" OR RUN` |
| `git show origin/main:fixtures/secret.env \| head -1` | `# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"` |

This is the evidence that **D-04's "the fixtures land on `main`" requirement was satisfied by PR #10's
merge**. Plan 07 re-verifies it and owns the finding; it is recorded here because it is what makes the
replacement PR equivalent to the one it replaces.

## The replacement branch — equivalence SHOWN, not argued

`git checkout -B feature/phase-19-gate-mode-proof origin/main`, then every seeded fixture path asserted
present in the checkout rather than assumed:

```
present: fixtures/vulnerable.py     present: fixtures/Dockerfile
present: fixtures/secret.env        present: fixtures/package-lock.json
present: fixtures/main.tf           present: fixtures/requirements.txt
```

**Six for six.** Every scanner in the workflow scans the whole checkout, not the diff, so the findings that
turn the five checks red under blocking are already in this tree. That is the substitution's whole
justification, and it is a measurement rather than a claim.

### Why the diff is a documentation correction and not a newly seeded finding

The replacement PR needs a non-empty diff to exist as a PR; it does **not** need to seed a finding. Seeding
one would have meant editing counts that `fixtures/README.md` on `main` states as measured facts, to
manufacture a condition that already exists. Instead the diff actions deferred item **D-19-A**.

| Property | Value |
|---|---|
| Paths changed vs `origin/main` | **exactly one — `fixtures/README.md`** |
| Diffstat | `1 file changed, 23 insertions(+)` — insertions only, no deletions |
| `git diff origin/main -- .github/ scripts/ fixtures/vulnerable.py fixtures/secret.env fixtures/main.tf fixtures/Dockerfile --stat` | **empty** |
| Commit | `35ca46cc825d0c8180f4e6cdd0b1f44902e1c1d6` — `docs(19-05): record the server-side push-protection layer in the fixtures README` |

**Every measured-count string is byte-identical between `origin/main` and the branch** — counted on both
sides, not asserted:

```
THREE findings:  main=1  branch=1
eval-detected:   main=1  branch=1
aws-access-token: main=2  branch=2
generic-api-key: main=1  branch=1
```

`grep -c 'GH013\|Push Protection' fixtures/README.md` → **4**. D-19-A is actioned.
`pre-commit run markdownlint --files fixtures/README.md` → **Passed** (rc=0). The new prose deliberately
avoids all four strings above and refers to the blocked secret by file and line (`fixtures/secret.env` lines
21-22) and by error code (`GH013`), never by scanner rule id.

What the new paragraph records: that `--no-verify` is client-side and **GitHub Push Protection is
server-side and cannot be skipped by it**; that it rejected a push carrying commit `fbfcbe9` with `GH013` on
`fixtures/secret.env` lines 21 and 22; a three-layer control-stack table (hook → Push Protection → CI
`secrets` job) with each layer's measured 2026-09-13 behaviour; that the block was cleared by the operator
approving two per-secret unblock URLs with the reason **"used in tests"** and that nothing in the repository
was changed to make the push succeed; and that doing so did **not** enable Secret Scanning —
`security_and_analysis` still reports `secret_scanning: disabled` and `secret_scanning_push_protection:
disabled`, because free push protection for public repositories is account-level.

## The push — observed, not predicted

The plan asked for what the pre-push hook and Push Protection **actually** do. Bypassing the hook with
`--no-verify` would have produced a prediction, not an observation, so the push was made **without it**:

| Item | Value |
|---|---|
| Command | `git push -u origin feature/phase-19-gate-mode-proof` — **no `--no-verify`** |
| pre-commit hooks at push | `markdownlint` **Passed**; `Detect hardcoded secrets` (Gitleaks) **Passed** |
| GitHub Push Protection / `GH013` | **did NOT fire** |
| Result | `* [new branch] feature/phase-19-gate-mode-proof`, rc=0 |
| `git ls-remote --heads origin feature/phase-19-gate-mode-proof` before | empty |
| after | `35ca46cc825d0c8180f4e6cdd0b1f44902e1c1d6	refs/heads/feature/phase-19-gate-mode-proof` |
| Runs triggered by the push alone | **zero** (`gh run list -b … --jq length` → `0`) — no `push:` trigger, as designed |

**Why `GH013` did not fire, stated as the plan predicted it and as it was then observed.** The only new
objects this branch pushes are one documentation commit's; the credential-shaped blobs are already on `main`
and were already allowed per-blob in 19-03. The prediction held. **No fixture was edited and no
`.gitleaksignore` fingerprint was added** — `.gitleaksignore` was not touched at all.

The Gitleaks hook Passing is the **third** independent confirmation of D-19-C: it is `stages: [pre-push]`
with a `--staged` entry, so at push time it scans an empty staged diff. It is structurally a no-op, and this
run shows it passing on a tree that indisputably contains a credential-shaped fixture.

## The replacement pull request — read back, never predicted

```
$ gh pr view 11 -R OttawaCloudConsulting/security-platform \
    --json number,url,state,headRefOid,baseRefName,headRefName,mergeable
```

| Field | Value |
|---|---|
| Number | **11** |
| URL | **<https://github.com/OttawaCloudConsulting/security-platform/pull/11>** |
| State | **OPEN** |
| Mergeable | `MERGEABLE` |
| Base ← head | `main` ← `feature/phase-19-gate-mode-proof` |
| Head SHA | **`35ca46cc825d0c8180f4e6cdd0b1f44902e1c1d6`** |
| Head **TREE** | **`895c1bdf42f32676b732dee10ec6cc36458568fc`** — the hash Task 2's two empty commits must reproduce |

The body states all three required things: that it **replaces PR #10** as the Phase 19 gate-mode proof after
PR #10 was merged out of band (with the timestamp and merge commit); that it carries the **D-19-A**
documentation correction and changes no measured count; and that **its fate is decided by the operator in
plan 07** — explicitly "do not merge or close this PR here".

## Run 1 — the report-only BASELINE this plan pairs against

Not 19-03's run `34786019516`. That run is a different pull request on a different base; pairing across them
would smuggle in a second changed variable. 19-03 is used for expected **shape** only.

| Field | Value |
|---|---|
| Run id | **34790727189** |
| Workflow / event | `PR Security` / `pull_request` |
| Head SHA | `35ca46cc825d0c8180f4e6cdd0b1f44902e1c1d6` |
| Conclusion | **success** |
| Created → updated | `2026-09-13T23:47:51Z` → `2026-09-13T23:48:40Z` (**49s**) |
| Runs on the branch | **1** |

### Gate-mode evidence, anchored

```
grep -c 'gate_mode=report-only$'  →  5
grep -c 'gate_mode=blocking$'     →  0
grep -c 'gate_mode='  (UNanchored, context only)  →  10
```

The anchor is load-bearing exactly as 19-03 recorded: the unanchored count is **10**, because each job's
`Validate gate_mode` step echoes its own source line `blocking|report-only) echo "gate_mode=${GATE_MODE}" ;;`
into the log's Run group. One anchored line per job:

| Job | Log line |
|---|---|
| `security / SAST — Semgrep CE` | `23:47:56.1601121Z gate_mode=report-only` |
| `security / Secrets — Gitleaks` | `23:47:56.5734663Z gate_mode=report-only` |
| `security / SCA — Trivy Filesystem` | `23:47:57.3636987Z gate_mode=report-only` |
| `security / Container — Trivy Image` | `23:47:58.1471107Z gate_mode=report-only` |
| `security / IaC — Checkov` | `23:48:06.6273011Z gate_mode=report-only` |

### Check runs on the head SHA

The head SHA carries **12** check runs; filtering on `startswith("security / ")` yields exactly **5**, with
the five byte-exact frozen names:

| Check run (byte-exact) | Conclusion |
|---|---|
| `security / Container — Trivy Image` | **success** |
| `security / IaC — Checkov` | **success** |
| `security / SAST — Semgrep CE` | **success** |
| `security / SCA — Trivy Filesystem` | **success** |
| `security / Secrets — Gitleaks` | **success** |

Green here is **report-only tolerance, not zero findings** — `continue-on-error: true` on every scan step.
Measured from the saved log rather than read off the `gh run watch` tail, whose annotation lines are easy to
mis-attribute: `grep -c 'Process completed with exit code'` → **10**, distributed across **four** of the five
jobs. This is run 1's per-job non-zero-exit baseline, and Task 2's "which step failed first" comparison pairs
against it:

| Job | `##[error]Process completed with exit code …` lines |
|---|---|
| `security / SCA — Trivy Filesystem` | **6** — four `exit code 1`, two `exit code 2` |
| `security / Secrets — Gitleaks` | **2** — both `exit code 1` |
| `security / SAST — Semgrep CE` | **1** — `exit code 1` |
| `security / Container — Trivy Image` | **1** — `exit code 1` |
| `security / IaC — Checkov` | **0** |

Four jobs exit non-zero and all five conclude `success` — that is exactly what report-only tolerance means.

**Checkov's zero is a property of the GREP, not of the job, and it was chased down rather than reported as
an asymmetry.** The `Process completed with exit code N` string is the format the Actions runner uses for
**`run:` shell steps**; Checkov's scan is a `uses:` step
(`bridgecrewio/checkov-action@a8664e3a…`), so a failing action never produces that line. Measured two ways:
the Checkov job emits its own `##[error] | File: /fixtures/main.tf:…` annotations for the failed checks, and
`security.yml` L229-236 sets **`soft_fail: false`** with the comment *"D-04: keep native failing exit code"*
under `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}`. So Checkov **does** fail its step under
report-only and is tolerated like the other four. **Five red under blocking remains the expected result.**
Had this been left as the "four of five" warning the raw grep first suggested, Task 2 would have been handed
a false expectation — recorded here because the near-miss is the useful part.

The seven non-`security / ` check runs, recorded so a later unfiltered query does not read them as drift:

| Check run | App | Conclusion |
|---|---|---|
| `GitGuardian Security Checks` | gitguardian | **success** |
| `Semgrep OSS`, `Checkov`, `Trivy`, `gitleaks`, `tflint`, `tflint-errors` | github-advanced-security | **success** |

**Observed difference from 19-03, recorded rather than smoothed over.** On PR #10, `GitGuardian Security
Checks` and `Semgrep OSS` concluded **failure**; on PR #11 both conclude **success**. This is a difference in
those two apps' inputs, not in the scanned tree: they report on findings the pull request *introduces*, and
PR #10 introduced the two fixture files while PR #11 introduces one documentation paragraph. The
whole-checkout `security / …` scans still see every fixture, which the analyses table below confirms with
identical result counts. Recorded as observed; the explanation is offered as reasoning, not as a measurement.

### Artifacts — `total_count` = 5, the same five names as 19-03

| Artifact | Id | Bytes | Expires |
|---|---|---|---|
| `semgrep-results` | 10328765180 | 197,853 | 2026-12-12T23:47:51Z |
| `checkov-results` | 10328760190 | 5,141 | 2026-12-12T23:47:51Z |
| `gitleaks-results` | 10328685765 | 10,386 | 2026-12-12T23:47:51Z |
| `trivy-image-results` | 10328271843 | 65,232 | 2026-12-12T23:47:51Z |
| `sca-results` | 10327249362 | 19,915 | 2026-12-12T23:47:51Z |

`expired: false` on all five.

### Code-scanning analyses on `refs/pull/11/merge` — the category set the blocking run must match

| Analysis id | Category | Tool | `results_count` |
|---|---|---|---|
| 1769701728 | `checkov` | checkov | 14 |
| 1769701382 | `gitleaks` | Gitleaks | 11 |
| 1769701846 | `semgrep` | Semgrep OSS | 8 |
| 1769702215 | `tflint` | tflint | 3 |
| 1769702244 | `tflint` | tflint-errors | 0 |
| 1769701805 | `trivy-fs` | Trivy | 6 |
| 1769701767 | `trivy-image` | Trivy | 58 |

Seven analyses, **six unique categories**.

**Finding-count cross-check against 19-03's PR #10 run, stated as a cross-check and not as a pass
condition.** The scanned fixture files are byte-identical on `main`, so the counts are expected to agree —
and they do, on every row: Semgrep **8** = 8; Gitleaks **11** = 11; Checkov **14** = 14 failed checks;
Trivy image **58** = 58; Trivy fs **6** = 19-03's 5 npm + 1 pip; tflint **3** = the three rule ids 19-03
named. No difference to explain.

## Preflight for the blocking window — read fresh, after the PR existed

| Command | Output |
|---|---|
| `gh variable list -R OttawaCloudConsulting/security-platform` | **nothing** (zero lines) — no `GATE_MODE`, the repository is in its default state |
| `gh api repos/…/rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` — **no required status checks** |
| `gh pr list -R … --state open` | **exactly one:** `#11  feature/phase-19-gate-mode-proof  OttawaCloudConsulting` |

Open pull requests enumerated by number and branch rather than summarised as a count, per the plan: **#11 /
`feature/phase-19-gate-mode-proof`** is the only one. **There is no open Dependabot pull request.**

## Operator Reply (Task 1) — RECEIVED

Task 1 is `checkpoint:human-verify` with `gate="blocking"`, and its acceptance criteria require the
operator's reply **verbatim**. The plan halted here across a session boundary and resumed on authorisation.

| Field | Value |
|---|---|
| What is being asked | Authorisation to set the repository-wide Actions variable `GATE_MODE=blocking` for a window of a few minutes |
| Blast radius, stated to the operator | `GATE_MODE` is **repository-wide**: while it is set, **every run on every branch** of `OttawaCloudConsulting/security-platform` — including PR #11, the only open PR — resolves to blocking and will go red |
| Expected window length | **minutes** — 18-05 measured ~2.5 |
| Restore commitment | `gh variable delete GATE_MODE` runs **unconditionally**, including if the measurement fails; the variable is **deleted**, never set back to the string `report-only` |
| Resume signal | `go` to authorise, or a description of the concern |
| **Operator reply (VERBATIM)** | **`go`** |

A second instruction was relayed in the same breath, in answer to an explicit question about PR #11's fate:
**leave PR #11 OPEN — do not merge it and do not close it in this plan.** That decision belongs to plan 07 at
phase close, after both SC2 (this plan) and SC4 (plan 06, which needs PR #11 still open) are captured. It was
obeyed: PR #11 is `OPEN` and `MERGEABLE` at the end of this plan.

**Provenance, stated rather than blurred.** Both the `go` and the leave-open instruction reached this
executor **relayed through the orchestrating agent's prompt**, not read by this executor from the operator
directly. They are recorded verbatim as received. The paired-evidence confirmation that Task 3 asks for is a
separate signal, given in a later session and recorded separately — see [Operator Reply (Task 3) —
RECEIVED](#operator-reply-task-3--received).

**Why this was not auto-approved.** `.planning/config.json` has `workflow._auto_chain_active: false` and no
`workflow.auto_advance`; the plan is `autonomous: false`; and the orchestrator instructed a clean halt at any
defined checkpoint. More than any of those: this checkpoint **authorises** opening a repository-wide gating
window before it opens. Auto-approving it would mean the executor authorising its own repo-wide write — the
exact thing T-19-19's mitigation exists to prevent.

## Task 2 — the flip, the paired verdicts, and the unconditional restore

### How the window was made un-orphanable

The plan's hardest constraint is that **no task boundary and no plan boundary may separate the `set` from the
`delete`**. In this harness shell state does not persist between tool calls, so a boundary between them is
not merely a plan-structure question: a session death, a tool timeout or a raised error between two calls
would leave `GATE_MODE=blocking` live on the repository indefinitely, gating every pull request. That is
T-19-20 exactly.

So the entire window — set, read back, push, poll to completion, delete, read back — ran as **one shell
invocation** of a single script, deliberately **without `set -e`** and chained with `;` rather than `&&`, so
that `gh variable delete` runs whatever any earlier command returns. Two further reductions:

- **The empty commit was created BEFORE the variable was set.** Commit-time hook work (the repo's pre-commit
  suite runs on `--allow-empty` too) therefore happened outside the live window.
- **All detailed measurement was done AFTER the delete.** A completed run's logs, check runs, artifacts and
  code-scanning analyses are immutable; none of it needs the variable live. Only the *poll to completion* had
  to stay inside.

Measured result: **63 seconds**, against 18-05's ~2.5 minute precedent.

### Flip window

| Event | Source | Timestamp |
|---|---|---|
| `gh variable set GATE_MODE --body blocking` | rc=`0` | — |
| **`SET_TS`** (GitHub's own `updated_at`) | `gh api repos/…/actions/variables/GATE_MODE` | **`2026-09-14T00:04:10Z`** |
| Local clock at set | `date -u` | `2026-09-14T00:04:09Z` |
| Read-back | `gh variable list` | `GATE_MODE	blocking	2026-09-14T00:04:10Z` |
| Push (same tree) | `35ca46c..41d676f` | rc=`0` |
| Blocking run created → completed | run `34791497579` | `00:04:17Z` → `00:05:06Z` |
| `gh variable delete GATE_MODE` | rc=`0` | — |
| **`DEL_TS`** (local clock; the delete API returns no timestamp) | `date -u` | **`2026-09-14T00:05:13Z`** |
| **Window length** | `DEL_TS − SET_TS` | **63 seconds** |

Two clock sources are recorded because they are not the same clock: `SET_TS` is GitHub's server-side
`updated_at`, `DEL_TS` is this machine's UTC clock, and `DELETE` returns no timestamp to read. They agreed to
within one second at the set, which is the only cross-check available.

The full read-back JSON, verbatim:

```
{"name":"GATE_MODE","value":"blocking","created_at":"2026-09-14T00:04:10Z","updated_at":"2026-09-14T00:04:10Z"}
```

`created_at == updated_at` confirms this variable was **created** by this command, not overwritten — the
repository genuinely had none, as Task 1's preflight recorded.

**The variable covered the whole blocking run.** Set `00:04:10Z`, run created `00:04:17Z`, run completed
`00:05:06Z`, deleted `00:05:13Z`. There is no window edge inside the run.

### Blast radius — enumerated, not asserted

```
$ gh run list -R … --limit 50 --json databaseId,createdAt,headBranch,conclusion,event,name \
    --jq '[.[] | select(.createdAt >= "2026-09-14T00:04:10Z" and .createdAt <= "2026-09-14T00:05:13Z")]'
```

| Run id | Created | Branch | Event | Workflow | Conclusion |
|---|---|---|---|---|---|
| **34791497579** | `2026-09-14T00:04:17Z` | `feature/phase-19-gate-mode-proof` | `pull_request` | `PR Security` | **failure** |

**Exactly one run was created inside the window, and it is the measurement's own.** No collateral run on any
other branch, no Dependabot run — consistent with Task 1's enumeration, which found PR #11 to be the only
open pull request. This is a query result, not a "none".

### Run identity — three commits, ONE tree

The whole argument rests here. If the trees differed, something other than the gate could explain the
verdict change (T-19-22).

```
commit 426c84c3fcc3207af2a4dd90263b2f7dd0a17df5 tree 895c1bdf42f32676b732dee10ec6cc36458568fc
commit 41d676f590a0dcd6cd8c5408e402a3faa4b6953b tree 895c1bdf42f32676b732dee10ec6cc36458568fc
commit 35ca46cc825d0c8180f4e6cdd0b1f44902e1c1d6 tree 895c1bdf42f32676b732dee10ec6cc36458568fc

$ git diff --stat HEAD~2 HEAD
(no output)
```

| # | Commit | Message | **Tree** | Run id | `GATE_MODE` | Conclusion |
|---|---|---|---|---|---|---|
| 1 | `35ca46c` | `docs(19-05): record the server-side push-protection layer…` | **`895c1bdf`** | `34790727189` | absent → `report-only` | **success** |
| 2 | `41d676f` | `chore(19-05): trigger a blocking-mode run on an identical tree` (EMPTY) | **`895c1bdf`** | `34791497579` | **`blocking`** | **failure** |
| 3 | `426c84c` | `chore(19-05): restore report-only after the blocking measurement` (EMPTY) | **`895c1bdf`** | `34791562222` | absent → `report-only` | **success** |

One tree hash across all three. `git diff` between the outer two produces **no output at all**. And
`git diff origin/main --name-only` still lists **exactly `fixtures/README.md`** — the two extra commits are
genuinely empty. **The only thing that changed between verdicts was one repository variable.**

Empty commits rather than `gh run rerun`, per the plan and RESEARCH P-2: a re-run is a new *attempt* of the
same run id, and `actions/upload-artifact` v4 artifacts are immutable and name-unique per run, so
re-uploading the five fixed names risks a conflict with nothing to do with gate mode — corrupting exactly the
measurement this plan exists to make. `pr-security.yml` is `on: pull_request: {}` only, so `gh workflow run`
cannot drive it either.

### Gate-mode resolution, anchored

| Run | `gate_mode=blocking$` | `gate_mode=report-only$` | unanchored `gate_mode=` |
|---|---|---|---|
| 1 — `34790727189` | **0** | **5** | 10 |
| 2 — `34791497579` | **5** | **0** | 10 |
| 3 — `34791562222` | **0** | **5** | 10 |

The anchor stays load-bearing: the unanchored count is 10 in every run because each job's `Validate
gate_mode` step echoes its own source line into the log's Run group. The five anchored blocking lines, one
per job, with their log timestamps:

| Job | Log line |
|---|---|
| `security / Secrets — Gitleaks` | `00:04:20.9178600Z gate_mode=blocking` |
| `security / SAST — Semgrep CE` | `00:04:20.9304637Z gate_mode=blocking` |
| `security / Container — Trivy Image` | `00:04:21.9607088Z gate_mode=blocking` |
| `security / SCA — Trivy Filesystem` | `00:04:22.0627038Z gate_mode=blocking` |
| `security / IaC — Checkov` | `00:04:34.4162445Z gate_mode=blocking` |

Run 3's five `report-only` lines re-prove Phase 18 D-03's fallback **after** a variable has existed and been
removed — not merely before one ever did.

### Check runs — the five frozen names under each mode

The head SHA carries **12** check runs in both cases; filtering on `startswith("security / ")` yields exactly
**5**. Never assumed to be five — counted.

| Check run (byte-exact, em dash U+2014) | Run 1 report-only | **Run 2 blocking** | Run 3 report-only |
|---|---|---|---|
| `security / Container — Trivy Image` | success | **failure** | success |
| `security / IaC — Checkov` | success | **failure** | success |
| `security / SAST — Semgrep CE` | success | **failure** | success |
| `security / SCA — Trivy Filesystem` | success | **failure** | success |
| `security / Secrets — Gitleaks` | success | **failure** | success |

**Five red under blocking is the SUCCESS condition of this task.** All five jobs also concluded `failure` at
the job level, so no check run is red for a reason its job is not.

The seven non-`security / ` check runs on the blocking SHA, recorded so a later unfiltered query does not
read them as drift — all seven **success**, none gated by `GATE_MODE`:

| Check run | App |
|---|---|
| `GitGuardian Security Checks` | gitguardian |
| `Checkov`, `Semgrep OSS`, `Trivy`, `gitleaks`, `tflint`, `tflint-errors` | github-advanced-security |

### Which step failed FIRST in each job — from the jobs API, not a log grep

The plan requires the first failing step to be the **scan** step: tolerance off, nothing else broken. Taken
from `GET /actions/runs/34791497579/jobs`, where `conclusion` is a structured per-step field:

| Job | First failing step | Is it the scan step? |
|---|---|---|
| `security / SAST — Semgrep CE` | 5. **`Run Semgrep`** | yes |
| `security / IaC — Checkov` | 5. **`Run Checkov`** | yes |
| `security / SCA — Trivy Filesystem` | 10. **`Run Trivy filesystem scan (JSON for retention)`** | yes |
| `security / Container — Trivy Image` | 6. **`Run Trivy image scan`** | yes |
| `security / Secrets — Gitleaks` | 5. **`Run Gitleaks (SARIF)`** | yes |

Not one is a `Verify …` step and not one is `Validate gate_mode` — which is the point: the gate turned the
checks red, a broken assertion did not.

All eleven failing steps across the run, every one a `GATE_MODE`-conditioned scan step, matching the eleven
`continue-on-error: ${{ env.GATE_MODE == 'report-only' }}` tolerances Phase 18 plan 02 installed:

| Job | Failing steps |
|---|---|
| `security / SCA — Trivy Filesystem` | 10. `Run Trivy filesystem scan (JSON for retention)`; 11. `Run Trivy filesystem scan (SARIF for code scanning)`; 15. `SCA-01 — npm audit`; 18. `SCA-02 — pip-audit`; 21. `SCA-03 — tflint (SARIF)`; 22. `SCA-03 — tflint (human-readable log)` |
| `security / Secrets — Gitleaks` | 5. `Run Gitleaks (SARIF)`; 6. `Run Gitleaks (JSON)` |
| `security / SAST — Semgrep CE` | 5. `Run Semgrep` |
| `security / IaC — Checkov` | 5. `Run Checkov` |
| `security / Container — Trivy Image` | 6. `Run Trivy image scan` |

**Eleven flipped tolerances, eleven failing steps, exactly.** That correspondence is a stronger statement
than the plan asked for and it is a count, not a reading.

**Checkov's step failed — settling run 1's open question.** Run 1's SUMMARY recorded that
`grep -c 'Process completed with exit code'` returned **0** for the Checkov job, and reasoned from
`security.yml` L229-236 (`soft_fail: false`) that this was a grep artifact — that string is the Actions
runner's format for `run:` shell steps, and Checkov's scan is a `uses:` step. The reasoning is now
**confirmed by measurement**: under blocking, `Run Checkov` carries `conclusion: failure` in the jobs API.
Had that been left as the raw grep's apparent "four of five", this task would have been handed a false
expectation of four red checks.

### The reporting guarantees, COUNTED under blocking

T-19-23 is the risk that a red run silently publishes nothing. Every figure below is read from the
**blocking** run, never inferred from a report-only one.

**Skipped steps across the entire blocking run: ZERO.** Queried directly
(`select(.conclusion=="skipped")` over every step of every job) and the result set is empty — no post-scan
step was skipped, which is what the `if: always()` guards exist to secure.

**All eleven intolerant `Verify … upload landed` assertions — green, none skipped:**

| # | Job | Assertion | Conclusion |
|---|---|---|---|
| 1 | SAST — Semgrep CE | `Verify Semgrep SARIF upload landed` | success |
| 2 | SAST — Semgrep CE | `Verify SAST artifact upload landed` | success |
| 3 | IaC — Checkov | `Verify Checkov SARIF upload landed` | success |
| 4 | IaC — Checkov | `Verify IaC artifact upload landed` | success |
| 5 | SCA — Trivy Filesystem | `Verify Trivy filesystem SARIF upload landed` | success |
| 6 | SCA — Trivy Filesystem | `Verify tflint SARIF upload landed` | success |
| 7 | SCA — Trivy Filesystem | `Verify SCA artifact upload landed` | success |
| 8 | Container — Trivy Image | `Verify Trivy image SARIF upload landed` | success |
| 9 | Container — Trivy Image | `Verify container artifact upload landed` | success |
| 10 | Secrets — Gitleaks | `Verify Gitleaks SARIF upload landed` | success |
| 11 | Secrets — Gitleaks | `Verify secrets artifact upload landed` | success |

The file carries **14** `Verify …` steps; the other three are report-*content* checks rather than
upload-landed assertions, and they are green under blocking too: `Verify npm audit reports`, `Verify
pip-audit reports`, `Verify tflint SARIF`. Recorded so the eleven is a defined set rather than a number
carried over from 19-03.

**Artifacts — `total_count` = 5 under blocking, the same five names as run 1:**

| Artifact | Id | Bytes (run 2) | Bytes (run 1) | Expired |
|---|---|---|---|---|
| `semgrep-results` | 10328397790 | 197,859 | 197,853 | false |
| `sca-results` | 10328387820 | 19,916 | 19,915 | false |
| `checkov-results` | 10327932303 | 5,167 | 5,141 | false |
| `trivy-image-results` | 10327792614 | 65,238 | 65,232 | false |
| `gitleaks-results` | 10327789076 | 10,396 | 10,386 | false |

All five retained to `2026-12-13T00:04:17Z`. Run 3 likewise reports `total=5` with the identical five names.

**The few-byte size differences are recorded rather than smoothed over, and they are not findings drift.**
The reports embed run- and commit-specific values — scan timestamps, the commit SHA, the image tag
`scan-fixture:<github.sha>` which differs per commit by construction, and absolute runner paths. The
authoritative check on whether the *findings* changed is the code-scanning `results_count`, which is
identical on every row across all three runs (next table). A byte-identical artifact across two different
commits would in fact have been the surprising result.

**Code-scanning analyses — identical category set and identical counts under blocking:**

| Category | Tool | Run 1 (`b9db5a1d`) | **Run 2 blocking (`3dcdcd33`)** | Run 3 (`50c80ae8`) |
|---|---|---|---|---|
| `checkov` | checkov | 14 | **14** | 14 |
| `gitleaks` | Gitleaks | 11 | **11** | 11 |
| `semgrep` | Semgrep OSS | 8 | **8** | 8 |
| `tflint` | tflint | 3 | **3** | 3 |
| `tflint` | tflint-errors | 0 | **0** | 0 |
| `trivy-fs` | Trivy | 6 | **6** | 6 |
| `trivy-image` | Trivy | 58 | **58** | 58 |

**Seven analyses, six unique categories, in all three runs.** The SARIF pipeline is entirely unaffected by
gate mode — the checks go red and the Security tab still fills. That is the whole content of ADR-001's
"upload failures must not block", now measured from the failing side.

### Finding-count cross-check against 19-03's PR #10 — a cross-check, not a pass condition

The scanned fixture files are byte-identical on `main`, so the counts are *expected* to agree; a difference
would be explained, not failed on. They agree on every row: Semgrep **8**; Gitleaks **11**; Checkov **14**
failed checks; Trivy image **58**; Trivy fs **6** (19-03's 5 npm + 1 pip); tflint **3**. **No difference to
explain.**

### The restore — `delete`, not `set --body report-only`

| Check | Result |
|---|---|
| `gh variable delete GATE_MODE -R …` | rc=`0` |
| `gh variable list -R …` | **nothing printed** |
| `gh api repos/…/actions/variables/GATE_MODE` | **`{"message":"Not Found",…,"status":"404"}`** — `gh: Not Found (HTTP 404)` |
| Run 3 anchored `gate_mode=report-only$` | **5** |
| Run 3 five `security / …` checks | **all success** |

The variable is **absent**, not set to a string. Setting `report-only` would have left a variable that never
existed before this plan and would have quietly stopped exercising Phase 18 D-03's fallback chain
`inputs.gate_mode || vars.GATE_MODE || 'report-only'` at its terminating literal — T-19-21. Run 3's five
anchored `report-only` lines are that fallback working with no variable present, and they were produced
**after** a variable had existed and been removed, which is strictly more than 18-05 could show.

Two independent absence proofs are recorded because `gh variable list` printing nothing is also what a failed
command looks like; the explicit `404` from the REST endpoint is the positive form of the same fact.

### Nothing else was touched

| Invariant | Check | Result |
|---|---|---|
| Ruleset unchanged from Task 1's preflight | `gh api repos/…/rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` — **no required checks**, nothing written |
| No workflow file edited | `git diff origin/main --name-only` | `fixtures/README.md` only |
| No fixture other than the README edited | same | same |
| PR #11 not merged, not closed | `gh pr view 11 --json state,mergeable` | **`OPEN`**, `MERGEABLE`, head `426c84c` |
| Stale local branch `feature/phase-19-pipeline-validation` | untouched | still at `d8bd09b` |

## Operator Reply (Task 3) — RECEIVED

Task 3 is a second `checkpoint:human-verify` with `gate="blocking"`. **It does not gate the restore** — the
`gh variable delete` already ran, unconditionally, inside Task 2, precisely so that an unanswered prompt
could never leave a live repository gating every pull request. Task 3 **confirms** the restore and the paired
verdicts.

| Field | Value |
|---|---|
| What was asked | Confirmation that the paired verdicts are real and that no `GATE_MODE` variable remains |
| What was put in front of the operator | One tree hash `895c1bdf` across three commits; run `34791497579` five RED; runs `34790727189` and `34791562222` five GREEN; a red job showing `gate_mode=blocking` with its upload steps still green below the red scan step; five artifacts and a populated Security tab on the red run; `gh variable list` printing nothing when the operator runs it themselves; PR #11 still OPEN |
| Resume signal | `approved` to continue, or a description of what does not match |
| **Operator reply (VERBATIM)** | **`approved`** |

**Provenance, stated for this reply exactly as it was for Task 1's.** The `approved` reached this executor
**relayed through the orchestrating agent's prompt**, not read by this executor from the operator directly.
It is recorded verbatim as received. No mismatch was reported, no condition was attached, and no instruction
about PR #11's fate was changed — the leave-it-open instruction from Task 1 still stands and was obeyed.

**Why this was not auto-approved either.** `.planning/config.json` still has
`workflow._auto_chain_active: false` and no `workflow.auto_advance`, and the plan is `autonomous: false`. The
plan's own `must_haves.truths` include *"A human has confirmed the paired evidence and that no GATE_MODE
variable remains"* — a truth no executor can make true on its own behalf. The authorisation received for
Task 1 was `go`, scoped to opening the window; it was not a confirmation of evidence that did not exist when
it was given. `approved` is that second, separate signal, and it is what makes the final must_haves truth
true.

## Deviations from Plan

### The plan-level deviation this plan absorbs

**1. PR #10 was merged out of band; SC2 moves to a replacement pull request.** Recorded in full at the top of
this SUMMARY with its live-read `state`, `mergedAt`, `mergeCommit` and deleted head branch. Not an executor
deviation — it is the condition the replan was written to absorb, re-verified live here rather than trusted
from the plan's text.

### Intentional divergences

**2. Pushed WITHOUT `--no-verify`.** The plan's interfaces block notes the hook "may still be bypassed with
`git push --no-verify`", and 19-03 used it. It was deliberately **not** used here, because the acceptance
criterion asks for the hook's *actual* behaviour on this push "rather than predicted" — and a bypassed hook
produces no observation. The hook ran and Passed. This is strictly more evidence than the plan asked for, and
it cost nothing.

**3. `--head` passed explicitly to `gh pr create`,** following 19-03's divergence 2: it removes any
dependence on the local branch's tracking state.

**4. `-R OttawaCloudConsulting/security-platform` passed on every `gh` invocation,** following 19-04's
deviation 1. The working directory is the outer docs repo, whose remote is a different repository.

**5. Run 1's code-scanning analyses and category set captured.** Not required by Task 1's acceptance
criteria, but Task 2 must assert "the same category set as run 1", and that comparison needs a recorded run-1
value rather than one re-derived after the blocking run has replaced it.

**6. VAL-01 NOT marked complete.** The plan frontmatter lists `requirements: [VAL-01]` and the executor
template marks listed requirements complete. Withheld, following 19-01 through 19-04 and the 17-01
precedent: plan 07 owns VAL-01's closure, and SC4 — the other half of what VAL-01 asserts — is plan 06's to
measure. Withheld again at plan close, after `approved`: `requirements.mark-complete` was deliberately not
invoked. `requirements-completed: []` on this SUMMARY should be read as withheld on purpose, not as a missed
step.

**7. Task 2's two pushes DID use `--no-verify`,** unlike Task 1's. The plan prescribes it there, and the
reason the divergence does not extend to Task 2 is that the observation was already made: Task 1 ran the hook
un-bypassed and recorded it Passing. Repeating it inside the live blocking window would have added seconds to
a repository-wide gating window in exchange for a third copy of a known result. The pushes carry **empty
commits** — there is no content for a secret scanner to see in either case.

**8. The whole set→measure→delete window ran as ONE shell invocation of a script,** rather than as the
sequence of separate commands the plan's interfaces block lays out line by line. The sequence is identical;
only the packaging differs, and it differs for a reason the plan itself argues: "no task boundary and no plan
boundary may ever separate the `set` from the `delete`". In this harness, shell state does not persist
between tool calls, so *every* tool-call boundary is a point where a timeout or a session death orphans the
variable. The script is `;`-chained and deliberately not `set -e`, so `gh variable delete` executes whatever
any earlier command returns.

**9. Per-step evidence came from the jobs REST API rather than from log greps.** The plan's `<action>` asks
"WHICH STEP FAILED FIRST" and whether any post-scan step skipped. `GET /actions/runs/{id}/jobs` carries
`steps[].conclusion` as a structured field; a log grep infers the same thing from runner message text. Run
1's two near-misses were both log-reading errors, so the structured source was preferred. The log is still
used where it is the only source — the anchored `gate_mode=` counts, which the plan specifies as greps.

**10. The empty commit for the blocking run was created BEFORE the variable was set.** The plan's sequence
shows `git commit --allow-empty && git push` after the `set`. Creating the commit first moves the repo's
pre-commit hook suite outside the live window and changes nothing about what is measured: the push, which is
what triggers the run, still happens inside it.

**11. Both absence proofs recorded for the delete, not just `gh variable list`.** An empty `gh variable list`
is indistinguishable from a command that silently produced nothing, so `GET
/actions/variables/GATE_MODE` was queried as well and its `404` recorded. The anti-slop rule that a silent
empty result is not evidence applies to the most important assertion in this plan.

### Auto-fixed Issues

None. No Rule 1, 2 or 3 fix was required across either session. Every command behaved as the plan
predicted — including the predictions that `GH013` would not fire, that five checks would go red under
blocking, and that the artifacts and SARIF categories would survive the red run.

### Checkpoints

**Task 1 — REACHED, HALTED across a session boundary, then AUTHORISED.** The operator replied **`go`**, plus
a relayed instruction to leave PR #11 open. See [Operator Reply (Task 1) —
RECEIVED](#operator-reply-task-1--received).

**Task 3 — REACHED, HALTED across a second session boundary, then CONFIRMED.** The operator replied
**`approved`**. See [Operator Reply (Task 3) — RECEIVED](#operator-reply-task-3--received). That halt was the
plan working as designed; unlike Task 1's, this checkpoint gated nothing operational — the restore was
already done and verified — so the delay cost nothing and left the repository in its original state
throughout.

### Authentication gates

None. `gh` was already authenticated. No package was installed and no dependency manifest was touched.

## Issues Encountered

None unresolved. Two observations that could be misread and are not problems:

- **`GitGuardian Security Checks` and `Semgrep OSS` are GREEN on PR #11 but were RED on PR #10.** Documented
  under "Check runs" above. Both are outside the five `security / ` checks and neither is gated by
  `GATE_MODE`.
- **Four jobs logged `##[error]Process completed with exit code 1`/`2` and all five checks still concluded
  `success`.** That is `continue-on-error: true` working exactly as report-only intends — the same contrast
  19-03 recorded on the Gitleaks job. Under blocking, those steps turning their checks red is SC2's evidence.

### A measurement error that was caught before it reached the operator

The first pass of this SUMMARY attributed a `Process completed with exit code 1` line to the Checkov job,
read off the `gh run watch` tail — where an annotation's *message* line and its `job: path#line` attribution
line print adjacently and are trivially mis-paired. Re-measured against the saved log, that line belongs to
`security / Container — Trivy Image`. The corrected per-job table above is grepped from
`$SCRATCH/r34790727189.log`, whose every line carries its own job prefix.

The correction then produced a second, subtler false reading — Checkov at **0** — which looked like a real
asymmetry that would have made Task 2 expect four red checks instead of five. That was a grep-pattern
artifact, resolved above against `security.yml` L229-236. Both are recorded because this phase's entire
discipline is that a figure must come from a command's output with its attribution intact, and the failure
mode here was reading a real command's output the wrong way round rather than inventing one.

Both readings are now **settled by measurement** rather than by argument: the blocking run's jobs API shows
`Run Checkov` with `conclusion: failure`, so Checkov's step does fail and is tolerated under report-only
exactly like the other four. Five red under blocking was the right expectation.

## Post-state — what plan 06 and plan 07 inherit, and what a resumer must not redo

| Item | State |
|---|---|
| **`GATE_MODE`** | **ABSENT** — `gh variable list` prints nothing and the REST endpoint returns `404`. Set at `00:04:10Z`, deleted at `00:05:13Z`, gone. |
| PR **#11** | **OPEN**, `MERGEABLE`, head `426c84c`, tree `895c1bdf…` — **left open deliberately**; plan 06 needs it open for SC4 and plan 07 owns its fate |
| Runs on `feature/phase-19-gate-mode-proof` | **3** — `34790727189` success, `34791497579` **failure (blocking)**, `34791562222` success |
| `rules/branches/main` | `deletion`, `non_fast_forward` — unchanged across both sessions, nothing written |
| Inner working tree | clean; branch vs `origin/main` = exactly `fixtures/README.md`; three commits ahead, two of them empty |
| Stale local branch `feature/phase-19-pipeline-validation` | present at `d8bd09b`, deliberately untouched |
| Artifacts | run 1 to `2026-12-12T23:47:51Z`; run 2 to **`2026-12-13T00:04:17Z`**; run 3 likewise 5 artifacts |
| D-09 | **EXECUTED.** Required-checks adoption (Phase 18 D-07 step 3) remains deferred past this phase — untouched here |

**What a resumer must NOT redo.** Do not re-run the flip: SC2 is measured and the evidence is above. Do not
push further commits to this branch — three commits with one tree hash *are* the evidence, and a fourth adds
nothing while risking the run set a reader has to reconcile. **Do not merge or close PR #11.** Do not touch
the ruleset. The Task 3 confirmation has been received (`approved`) and the bookkeeping is closed out below,
so nothing in this plan is outstanding.

### State bookkeeping across the two halts — the tick that was withheld twice, and why

At the **first** halt (Task 1) and again at the **second** (Task 3), `roadmap.update-plan-progress` was
deliberately NOT run, the second time against an explicit instruction from the orchestrating agent — which
was surfaced rather than decided quietly. The second session's reasoning, preserved here because the
withholding is part of this plan's record:

- Task 3 is `type="checkpoint:human-verify"` with `gate="blocking"` and the resume signal `approved`. That
  signal had not been received.
- The plan's own `must_haves.truths` include **"A human has confirmed the paired evidence and that no
  GATE_MODE variable remains"**. No executor can make that truth true on its own behalf.
- Ticking `19-05-PLAN.md` as `[x]` asserts the *plan* is complete, which is a stronger claim than "SC2 is
  captured". Both claims deserve to be readable separately, and this SUMMARY states each one plainly.

**The signal has now been received**, so the condition attached to the withholding is met and the tick is
correct. It was not run on the executor's judgement that the evidence was good enough; it was run because the
human said `approved`.

### State bookkeeping at close — every figure below is a command's recorded output

| Command | Output |
|---|---|
| `gsd-sdk query roadmap.update-plan-progress --phase 19` | `{"updated":true,"phase":"19","plan_count":7,"summary_count":5,"status":"In Progress","complete":false}` |
| `git diff .planning/ROADMAP.md` | exactly two lines: `- [ ] 19-05-PLAN.md` → `- [x]`, and the progress row `4/7` → **`5/7`**, still `In Progress` |
| `gsd-sdk query state.advance-plan` | `{"advanced":true,"previous_plan":5,"current_plan":6,"total_plans":7}` |
| `gsd-sdk query state.record-metric --phase 19 --plan 05 …` | `{"recorded":true,…}` — row `Phase 19 P05 \| 18min + 14min + 6min \| 3 tasks \| 1 files` |
| `gsd-sdk query state.add-decision --summary … --phase 19` (x2) | `{"added":true,…}` each |
| `gsd-sdk query state.record-session --stopped-at … --resume-file …` | `updated: ["Last session","Stopped At","Resume File"]` — the `updated` array read, not the `recorded` boolean (D-19-D) |
| `gsd-sdk query state.sync` | `{"synced":true,"changes":[]}` — frontmatter already in line |
| `gsd-sdk query state.update-progress` | `{"updated":true,"percent":95,"completed":35,"total":37}` |
| `gsd-sdk query state.validate` | `{"valid":true,"warnings":[],"drift":{}}` |

STATE.md now reads `Plan: 6 of 7` and
`Stopped at: Completed 19-05-PLAN.md (SC2 measured, D-09 executed, operator approved)`, with the resume file
pointing at `19-06-PLAN.md`. **`requirements.mark-complete` was still not invoked** — VAL-01 is plan 07's to
close (deviation 6).

**`--phase 19` worked, contrary to the local source.** `bin/lib/roadmap-command-router.cjs` in this repo
passes `args[2]` positionally, which would have made `--phase` the phase name; the **installed global**
`gsd-sdk v1.42.3` parses named flags instead, exactly as D-19-D found for the `state.*` handlers. The flag
form was tried first per the resume instruction and returned `updated: true` with the right counts, so no
positional fallback was needed. Recorded because the repo-local source and the executing binary disagree, and
a future reader following the local source would get the wrong answer.

Two decisions were added to STATE.md rather than left implicit, because STATE.md's Phase 19-03 note still
says *"PR #10 is the long-lived D-05 validation PR, OPEN at head d8bd09b"* — which PR #10's out-of-band merge
falsified. The new decision names PR #11 as the pull request 19-06 and 19-07 must use.

The side effect recorded at the first halt is left alone rather than hand-edited, per D-19-E: `state.sync`
counts SUMMARY files on disk, so STATE.md's `completed_plans: 35` and its 95% progress bar already included
this plan while it was still halted. That is now simply correct.

## Self-Check: PASSED

| Claim | Verification | Result |
|---|---|---|
| This SUMMARY exists at the path the plan names | `[ -f .planning/phases/19-…/19-05-SUMMARY.md ]` | FOUND |
| `must_haves.artifacts[0].contains: blocking` | frontmatter, banner, flip-window table, check-run table | FOUND |
| `key_links[0].pattern: fixtures/vulnerable.py` | the `origin/main` header read and the six-path presence assertion | FOUND in both |
| `key_links[1].pattern: gate_mode=blocking` | run 2's anchored grep, **5** occurrences, one per job, listed with timestamps | FOUND |
| `key_links[2].pattern: gate_mode=report-only` | runs 1 and 3's anchored greps, **5** each | FOUND in both |
| Inner-repo commit `35ca46c` exists | `git log --oneline origin/main..HEAD` | `docs(19-05): record the server-side push-protection layer…` |
| Inner-repo commit `41d676f` exists (blocking trigger) | same | `chore(19-05): trigger a blocking-mode run on an identical tree` |
| Inner-repo commit `426c84c` exists (restore trigger) | same | `chore(19-05): restore report-only after the blocking measurement` |
| All three commits share ONE tree | `git rev-parse <c>^{tree}` x3 | **`895c1bdf…`** x3 |
| `git diff` between the outer two is empty | `git diff --stat HEAD~2 HEAD` | **no output** |
| Exactly one path differs from `origin/main` | `git diff origin/main --name-only` | `fixtures/README.md` |
| No measured count changed | four `grep -c` pairs, main vs branch | `1/1`, `1/1`, `2/2`, `1/1` |
| markdownlint passes on the edited file | `pre-commit run markdownlint --files fixtures/README.md` | **Passed**, rc=0 |
| Five checks RED under blocking | `commits/41d676f/check-runs`, filtered on `security / ` | **5 × failure** |
| Five checks GREEN after restore | `commits/426c84c/check-runs`, filtered | **5 × success** |
| Artifacts survive blocking | `runs/34791497579/artifacts` | `total_count` = **5**, same five names |
| SARIF survives blocking | `code-scanning/analyses?ref=refs/pull/11/merge` | **7** analyses, 6 categories, counts identical to runs 1 and 3 |
| Eleven intolerant verify assertions green | `runs/34791497579/jobs`, `steps[]` filter | **11 × success**, 0 skipped |
| No step skipped anywhere in the blocking run | same, `select(.conclusion=="skipped")` | **empty result set** |
| `GATE_MODE` absent at plan end | `gh variable list -R …` | **nothing printed** |
| `GATE_MODE` absent — positive proof | `gh api repos/…/actions/variables/GATE_MODE` | **HTTP `404` Not Found** |
| Window bounded and enumerated | `SET_TS` `00:04:10Z`, `DEL_TS` `00:05:13Z`, run-list filter | **63s**, **1** run inside, the measurement's own |
| Ruleset not written | `gh api …/rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` |
| PR #11 still OPEN, not merged, not closed | `gh pr view 11 --json state,mergeable` | **`OPEN`**, `MERGEABLE`, head `426c84c` |
| `requirements-completed` still `[]` | frontmatter | PASS — withheld on purpose (deviation 6) |
| ROADMAP ticked, after `approved` and not before | `grep '19-05-PLAN' .planning/ROADMAP.md` | **`- [x] 19-05-PLAN.md …`**, progress row **`5/7`**, `In Progress` |
| STATE advanced past this plan | `grep '^Plan:' .planning/STATE.md` | **`Plan: 6 of 7`** |
| PR #11 untouched at close | `gh pr view 11 --json state,mergedAt,closedAt,headRefOid` | **`OPEN`**, `mergedAt: null`, `closedAt: null`, head `426c84c` |
| `GATE_MODE` still absent at close | `gh variable list -R …` | **nothing printed** |
| Operator's Task 3 reply recorded verbatim | this SUMMARY, [Operator Reply (Task 3)](#operator-reply-task-3--received) | **`approved`** |

Every figure in this SUMMARY was read from a command's recorded output. The two items that are not
measurements are the operator's replies — `go` at Task 1 and `approved` at Task 3 — each recorded verbatim as
received and each explicitly labelled as relayed through the orchestrating agent rather than read from the
operator directly. Nothing was written on the operator's behalf.
