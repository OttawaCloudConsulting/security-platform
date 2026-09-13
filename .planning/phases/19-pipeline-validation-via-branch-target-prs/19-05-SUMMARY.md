---
phase: 19-pipeline-validation-via-branch-target-prs
plan: 05
subsystem: ci-cd
tags: [gate-mode, blocking, report-only, pull-request, push-protection, sc2, d-09, checkpoint, halted]

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
  - "PR #11 — the REPLACEMENT Phase 19 gate-mode validation PR, OPEN at head 35ca46c"
  - "run 34790727189 — the report-only BASELINE this plan's blocking run is paired against"
  - "the D-19-A action: fixtures/README.md now documents the server-side Push Protection layer"
  - "run 1's code-scanning category set and artifact manifest, the comparison targets for the blocking run"
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
  - "HALTED at Task 1's blocking checkpoint. auto_advance is unset and workflow._auto_chain_active is false, the plan is autonomous:false, and the checkpoint AUTHORISES a repository-wide blocking window before it opens. Auto-approving would have opened that window on the executor's own authority."
  - "Pushed WITHOUT --no-verify, deliberately. The plan asked for the hook's ACTUAL behaviour rather than a prediction; bypassing it would have produced no observation. The hook ran (`Detect hardcoded secrets`) and Passed, re-confirming D-19-C at push scope for a third time."
  - "GATE_MODE was NOT set. Nothing was flipped, merged, closed, or written to the ruleset in this task."
  - "VAL-01 NOT marked complete — following 19-01 through 19-04 and the 17-01 precedent. SC2 is not yet measured and plan 07 owns VAL-01's closure."

patterns-established:
  - "When the pull request an evidence chain is scoped to disappears out of band, record the disappearance as a live-read fact and rebuild the claim on a substitute whose equivalence is SHOWN (six fixture paths asserted present) rather than argued"

requirements-completed: []

# Metrics
duration: 18min (Task 1 to the checkpoint halt)
completed: 2026-09-13
---

# Phase 19 Plan 05: Prove the Gate Actually Gates Summary

**PR #10 was merged out of band before SC2 could be measured, so a REPLACEMENT validation pull request —
**[PR #11](https://github.com/OttawaCloudConsulting/security-platform/pull/11)**, cut from post-merge
`origin/main` and carrying all five seeded fixture categories — is OPEN and GREEN under report-only: run
**34790727189**, five `security / …` checks all `success`, five anchored `gate_mode=report-only` lines, zero
`blocking`, five artifacts, seven code-scanning analyses. That is the baseline the blocking run will be
paired against. Nothing has been flipped.**

**STATUS: HALTED at Task 1's blocking `checkpoint:human-verify`.** Tasks 2 and 3 have not run.
`gh variable list` prints nothing — `GATE_MODE` has not been touched. The operator's authorisation to open
the repository-wide blocking window is outstanding; see [Operator Reply (Task 1) —
PENDING](#operator-reply-task-1--pending).

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
The Checkov job's scan step is visibly `Process completed with exit code 1` in the run log while its check
concludes `success`. The seven non-`security / ` check runs, recorded so a later unfiltered query does not
read them as drift:

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

## Operator Reply (Task 1) — PENDING

Task 1 is `checkpoint:human-verify` with `gate="blocking"`, and its acceptance criteria require the
operator's reply **verbatim**. The plan halted here. Nothing has been flipped.

| Field | Value |
|---|---|
| What is being asked | Authorisation to set the repository-wide Actions variable `GATE_MODE=blocking` for a window of a few minutes |
| Blast radius, stated to the operator | `GATE_MODE` is **repository-wide**: while it is set, **every run on every branch** of `OttawaCloudConsulting/security-platform` — including PR #11, the only open PR — resolves to blocking and will go red |
| Expected window length | **minutes** — 18-05 measured ~2.5 |
| Restore commitment | `gh variable delete GATE_MODE` runs **unconditionally**, including if the measurement fails; the variable is **deleted**, never set back to the string `report-only` |
| Resume signal | `go` to authorise, or a description of the concern |
| **Operator reply (VERBATIM)** | **_pending — not yet received_** |

**Why this was not auto-approved.** `.planning/config.json` has `workflow._auto_chain_active: false` and no
`workflow.auto_advance`; the plan is `autonomous: false`; and the orchestrator instructed a clean halt at any
defined checkpoint. More than any of those: this checkpoint **authorises** opening a repository-wide gating
window before it opens. Auto-approving it would mean the executor authorising its own repo-wide write — the
exact thing T-19-19's mitigation exists to prevent.

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
precedent: **SC2 is not yet measured** — this plan halted before the flip — and plan 07 owns VAL-01's
closure. `requirements.mark-complete` was deliberately not invoked.

### Auto-fixed Issues

None. No Rule 1, 2 or 3 fix was required: every command behaved as the plan predicted, including the
prediction that `GH013` would not fire.

### Checkpoints

**Task 1 — REACHED and HALTED.** See [Operator Reply (Task 1) — PENDING](#operator-reply-task-1--pending).
The halt is the plan working as designed. Tasks 2 and 3 have not run.

### Authentication gates

None. `gh` was already authenticated. No package was installed and no dependency manifest was touched.

## Issues Encountered

None unresolved. Two observations that could be misread and are not problems:

- **`GitGuardian Security Checks` and `Semgrep OSS` are GREEN on PR #11 but were RED on PR #10.** Documented
  under "Check runs" above. Both are outside the five `security / ` checks and neither is gated by
  `GATE_MODE`.
- **`security / IaC — Checkov` concluded `success` while its scan step logged `Process completed with exit
  code 1`.** That is `continue-on-error: true` working exactly as report-only intends — the same contrast
  19-03 recorded on the Gitleaks job. Under blocking, that step turning its check red is SC2's evidence.

## Post-state — what Task 2 inherits, and what a resumer must not redo

| Item | State |
|---|---|
| **`GATE_MODE`** | **ABSENT** — `gh variable list` prints nothing. **Not touched by this session.** |
| PR **#11** | **OPEN**, `MERGEABLE`, head `35ca46c`, tree `895c1bdf…` |
| Runs on `feature/phase-19-gate-mode-proof` | **1** — `34790727189`, `success` |
| `rules/branches/main` | `deletion`, `non_fast_forward` — unchanged, nothing written |
| Inner working tree | clean; branch vs `origin/main` = exactly `fixtures/README.md` |
| Stale local branch `feature/phase-19-pipeline-validation` | present at `d8bd09b`, deliberately untouched |
| Artifacts from run 1 | retained until **2026-12-12T23:47:51Z** |

**Resume instructions for Task 2.** On `go`: `gh variable set GATE_MODE --body blocking`, read back and
record `updatedAt` as `SET_TS`, push ONE empty commit, measure, then **`gh variable delete GATE_MODE`
unconditionally**, record `DEL_TS`, push a SECOND empty commit, and enumerate every run created between the
two timestamps. Do not re-open a PR, do not re-run run 1, and do not re-derive anything in this SUMMARY.
**Do not merge or close PR #11** — plan 07 owns its fate.

## Self-Check: PASSED

| Claim | Verification | Result |
|---|---|---|
| This SUMMARY exists at the path the plan names | `[ -f .planning/phases/19-…/19-05-SUMMARY.md ]` | FOUND |
| `must_haves.artifacts[0].contains: blocking` | the word appears in the frontmatter, the halt banner, the operator table and the resume instructions | FOUND |
| `key_links[0].pattern: fixtures/vulnerable.py` | the `origin/main` header read and the six-path presence assertion | FOUND in both |
| `key_links[2].pattern: gate_mode=report-only` | run 1's anchored grep, 5 occurrences, one per job | FOUND |
| Inner-repo commit `35ca46c` exists | `git -C repos/security-platform log --oneline origin/main..HEAD` | `35ca46c docs(19-05): record the server-side push-protection layer…` |
| Exactly one path differs from `origin/main` | `git diff origin/main --name-only` | `fixtures/README.md` |
| No measured count changed | four `grep -c` pairs, main vs branch | `1/1`, `1/1`, `2/2`, `1/1` |
| markdownlint passes on the edited file | `pre-commit run markdownlint --files fixtures/README.md` | **Passed**, rc=0 |
| PR #11 read back, not predicted | `gh pr view 11 --json number,url,state,headRefOid` | `11`, OPEN, `35ca46c…` |
| `GATE_MODE` absent at task end | `gh variable list -R …` | **nothing printed** |
| Ruleset not written | `gh api …/rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` |
| `requirements-completed` still `[]` | frontmatter | PASS — withheld on purpose (deviation 6) |

Every figure in this SUMMARY was read from a command's recorded output in **this** session. The one item
that is not a measurement is the operator's reply, which is marked **pending** rather than written on their
behalf.
