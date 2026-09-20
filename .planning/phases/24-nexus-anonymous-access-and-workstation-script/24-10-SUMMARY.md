---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 10
subsystem: infra
tags: [nexus, release, pull-request, gates, gitleaks, approval-gate, merge-gate, origin-main-evidence]
status: COMPLETE — PR #15 merged (aed14b9); NEXUS-02 and NEXUS-04 marked from origin/main evidence

# Dependency graph
requires:
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 08
    provides: "Both security-platform READMEs updated — the last commit on the branch"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 09
    provides: "ADR-021 recorded in this repository; Phase 23 deferred items 2 and 3 dispositioned"
provides:
  - "Branch-tip verification of all four gates on feature/phase-24-nexus-anonymous-and-workstation, with no --no-verify anywhere"
  - "A reconciled 13-commit / seven-plan branch manifest, confirmed pushed intact (origin tip == local tip, 0 behind main)"
  - "The approved PR title and body committed as phase evidence, diffed byte-identical against what PR #15 actually published"
  - "PR #15 merged as aed14b9, verified from origin/main only — merged tree hash identical to the gated tree hash (a4a7962)"
  - "NEXUS-02 and NEXUS-04 marked Complete, closing the nine-plan withholding chain"
  - "24-VALIDATION.md finalised: status complete, nyquist_compliant true, wave_0_complete true, 15/15 rows green with the observing SUMMARY named"
affects: [24-10-continuation, phase-25-nexus-live-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Run a pre-push-staged hook at its own stage against the exact push range (--from-ref/--to-ref) to learn its verdict without performing the push"

key-files:
  created:
    - .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-10-SUMMARY.md
    - .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-evidence/pr-title.txt
    - .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-evidence/pr-body.md
  modified:
    - .planning/REQUIREMENTS.md
    - .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-VALIDATION.md
    - .planning/STATE.md

key-decisions:
  - "NEXUS-02 and NEXUS-04 were marked BY HAND in Task 3, from quoted git ls-tree origin/main evidence; requirements.mark-complete was never run from plan frontmatter. The orchestrator's brief offered marking them as an example of non-push work that could proceed; the plan forbids it (T-24-49, the 17-01 reverted-mark precedent) and nine prior SUMMARYs in this phase withheld the marks for exactly this reason. The marks were withheld through Task 1 and Task 2 — NEXUS-01's precedent is explicit that 'a chart on an unpushed branch or in an open PR is not public' — and made in Task 3 only once `git ls-tree origin/main` showed the work on the merged default branch. The contradiction was surfaced in the report rather than decided silently."
  - "24-VALIDATION.md was held at status: draft until the merge, then finalised in the same commit as the marks. One row, 24-W0-11, is green on its BEHAVIOUR with its stated COMMAND recorded as falsified (pip config get cannot read the PIP_CONFIG_FILE scope on pip 26.2.1) rather than quietly swapped — a contract that edits its own assertions to match whatever passed is worth nothing."
  - "MEASURED TOOL DEFECT: gsd-sdk query state.record-session silently rewrote the STATE.md progress block to 18/18 / percent 100 as a side effect of this SUMMARY existing on disk, and ignored the stopped_at argument it was given. It was reverted by hand while the phase was still open. Progress handlers were only run once the phase was genuinely complete, and their output was read back rather than trusted."
  - "The live gate was re-run on the branch tip rather than cited from 24-05. Its inputs are unchanged since 9b670c4 (24-06/24-07 touched only workstation/, 24-08 only the READMEs), so 25/0 was the expectation — but the plan asks for a branch-tip verdict and an approval report should rest on a measurement taken now."
  - "git push --dry-run was deliberately NOT run before the approval. It is a git push invocation that contacts the remote; the approval gate was respected literally. After approval the operator performed the push and the PR creation, and this executor verified the outcome (remote tip, ahead/behind, published PR text) rather than assuming it."
  - "gh pr merge was NOT invoked, and Task 2 forbids it under any circumstance. PR #15 was read only after every check run reported completed — the first read returned a settled-looking UNSTABLE on an unsettled tree (Phase 22 Pitfall 7). Task 3 owns the merge and must re-read state again first, because PRs #9, #10 and #14 were all merged out of band by the operator."
  - "The twelve green checks are report-only tolerance, not zero findings. GATE_MODE is still absent (Phase 19 D-09's deleted state) so every scan step carries continue-on-error, and fixtures/ is permanent on main, so a green rollup is guaranteed regardless of this PR's diff (the 19-06 finding)."

patterns-established:
  - "Pattern: when an orchestrator's brief and a plan's evidence rule disagree about whether a requirement may be marked, the evidence rule wins and the disagreement is reported, not absorbed."

requirements-completed: [NEXUS-02, NEXUS-04]  # Marked only after git ls-tree origin/main evidence — see Task 3.

# Metrics
duration: ~1h15m (spanning three operator round-trips)
completed: 2026-09-20
---

# Phase 24 Plan 10: Ship Phase 24 — Paused at the Merge Gate Summary

**Phase 24 is shipped: PR #15 merged as `aed14b9` with a tree hash identical to the one the gates ran against, and NEXUS-02 and NEXUS-04 marked complete from `git ls-tree origin/main` evidence — closing a withholding chain nine plans long, and doing it without this plan ever invoking `gh pr merge`.**

## Status: COMPLETE

| Plan task | State |
|-----------|-------|
| Task 1 — push the branch and open the PR | **COMPLETE.** Gates green on the branch tip, commit manifest reconciled, PR drafted and approved, branch pushed, PR #15 opened with byte-identical text. |
| Task 2 — merge approval gate | **COMPLETE.** Evidence and the four residual risks presented; the operator merged PR #15 himself. `gh pr merge` was never invoked by this plan. |
| Task 3 — verify from `origin/main`, mark the requirements, finalise the validation contract | **COMPLETE.** Merge verified from the remote only; NEXUS-02 and NEXUS-04 marked; `24-VALIDATION.md` finalised. Commit `fc6900e`. |

The plan ran across **three** operator round-trips rather than the one checkpoint it was written with. The orchestrator's brief required a stop before any action visible on the shared remote — a stricter reading of the same boundary the plan's own Task 2 draws, landing one step earlier — so Task 1 split around an approval gate, and the merge gate followed.

### The push and the PR, as executed

The operator approved and performed the push and the PR creation, reporting verbatim:

> "Approved and done: branch pushed clean (all pre-push hooks passed, gitleaks clean), PR opened at https://github.com/OttawaCloudConsulting/security-platform/pull/15."

Verified rather than taken on trust:

- `git ls-remote --heads origin feature/phase-24-nexus-anonymous-and-workstation` → `c3ba86470fc26483f16acdeb161417190126ac64` — the branch is on the remote, at exactly the local tip that was reconciled and gated.
- `git rev-list --left-right --count origin/main...HEAD` → `0 13` — still 13 commits ahead, zero behind; `main` has not moved and no commit was added or lost in the push.
- PR #15: `state: OPEN`, `isDraft: false`, base `main`, head `feature/phase-24-nexus-anonymous-and-workstation` at `c3ba864`, 13 commits, 9 files, +3,440 / −83 — matching this SUMMARY's manifest and the PR body's own claims exactly. Created `2026-09-20T20:44:24Z` by `OttawaCloudConsulting`.
- **The published text is the approved text.** `gh pr view 15 --json title,body` diffed against the committed `24-evidence/pr-title.txt` and `24-evidence/pr-body.md`: the title is byte-identical and the body differs only by one trailing newline that GitHub appends. What the operator approved is what a reviewer reads.
- The gitleaks pre-push hook ran for real on the push and passed, as the operator reports and as the simulated-range run predicted. `--no-verify` was not used at any point by either party.

## Task 2 — PR #15 state, re-read at the gate

`https://github.com/OttawaCloudConsulting/security-platform/pull/15`

Read **after** the checks settled, not from the first response. The first read, one minute after creation, returned `mergeStateStatus: UNSTABLE` with 7 checks of which 4 were `in_progress`/`queued` — a settled-looking verdict on an unsettled tree, which is the Phase 22 Pitfall 7 shape. The poll asserted every check run `completed` before any verdict was read, per the 22-02 precedent.

| Field | Value |
|-------|-------|
| `state` | `OPEN` |
| `isDraft` | `false` |
| `mergeable` | `MERGEABLE` |
| `mergeStateStatus` | `CLEAN` (settled — was `UNSTABLE` only while checks ran) |
| `headRefOid` | `c3ba86470fc26483f16acdeb161417190126ac64` |
| `mergedAt` / `mergedBy` | `null` / `null` — **not merged, by anyone** |
| `reviewDecision` | empty — no review is required on this repository |
| Check rollup | **12 of 12 `SUCCESS`, 0 pending, 0 failure** |

The twelve check runs on `c3ba864`, all `success`: `security / SAST — Semgrep CE`, `security / IaC — Checkov`, `security / SCA — Trivy Filesystem`, `security / Container — Trivy Image`, `security / Secrets — Gitleaks`, plus the seven `github-advanced-security` / external checks `Semgrep OSS`, `Checkov`, `Trivy`, `tflint`, `tflint-errors`, `gitleaks` and `GitGuardian Security Checks`. That membership matches 17-05's measured twelve exactly — code scanning creates one check run per `tool.driver.name`, not per category.

**Green is not zero findings, and must not be read as such.** The `GATE_MODE` repository variable is still absent (`gh variable list` prints nothing), which is Phase 19 D-09's deleted state, so the five scan jobs run **report-only** with `continue-on-error: true` on every scan step. `fixtures/` is permanent on `main`, so every PR scans a deliberately vulnerable tree and the checks go green regardless — the 19-06 finding, restated here so a green rollup is not mistaken for a clean scan of this PR's own diff. The branch ruleset on `main` carries only `deletion` and `non_fast_forward`; no check is required, so nothing here blocks or authorises a merge on its own.

The four residual risks the operator was asked to weigh are stated in full in `24-evidence/pr-body.md` and in the PR itself: all-repository anonymous read via the un-narrowable `nx-anonymous` role; the anonymous repository-inventory disclosure at `GET /service/rest/v1/repositories`; plaintext until Phase 25 adds TLS; and Checkov's zero coverage of this chart (24 latent findings, none reaching CI).

### The decision: merged out of band, for the fourth consecutive phase

**`gh pr merge` was never invoked by this plan, in any task.** The operator merged PR #15 himself on GitHub and deleted the branch, reporting verbatim:

> "Confirmed: PR #15 state=MERGED, mergeCommit=aed14b916e9aa8ec1d0d47699b457040b99f7eac, mergedAt=2026-09-20T20:46:24Z (operator merged and deleted branch on GitHub)."

Re-read directly rather than accepted — `gh pr view 15` and `gh api repos/.../pulls/15` both return `state: MERGED`, `merged: true`, `merged_at: 2026-09-20T20:46:24Z`, `merged_by: OttawaCloudConsulting`, `merge_commit_sha: aed14b916e9aa8ec1d0d47699b457040b99f7eac`, 13 commits, 9 files, +3,440 / −83.

The merge landed **two minutes** after the PR was created, *while this plan was still polling the PR's checks*. That the `OPEN` / `mergedAt: null` reading was **genuinely pre-merge rather than a stale API response** is measured, not assumed, and the distinction matters: a stale `OPEN` is exactly what makes a `gh pr merge` double-fire. The latest `completed_at` across all twelve check runs is `2026-09-20T20:45:24Z`; the poll only stopped once every run reported `completed`, so the state read that followed it happened after `20:45:24Z`, and it returned `mergedAt: null`, so it happened before `20:46:24Z`. The read sits inside a one-minute window that closed while the result was being written up — a true reading of a window that had already closed by the time it was reported, not a stale one. That is exactly the standing project fact this plan's own context warns about — PRs #9, #10 and #14 were all merged out of band, #14 through the UI while a plan was running — and it is why Task 3's first instruction is to re-read PR state before touching `gh pr merge`. Doing so found nothing to merge, and nothing was re-merged.

## Task 3 — closed against `origin/main` evidence

Every assertion below is read from the remote (`git fetch` then `git ls-tree` / `git show` / `git ls-remote`), never from the local working tree, per the Phase 23 T-23-12 rule.

### The merge

| Fact | Value |
|------|-------|
| Merge commit | `aed14b916e9aa8ec1d0d47699b457040b99f7eac` |
| Parents | `ea2770fbf1f8a4bd532d131835d90fb86c6f5d54` (branch point) + `c3ba86470fc26483f16acdeb161417190126ac64` (gated branch tip) |
| `mergedAt` / `mergedBy` | `2026-09-20T20:46:24Z` / `OttawaCloudConsulting` |
| `origin/main` tip | `aed14b9` — the merge commit *is* the tip |
| All 13 branch commits ancestors of `origin/main` | yes, each checked individually with `git merge-base --is-ancestor` |

**The merged tree is byte-for-byte the tree that was gated.** `git rev-parse origin/main^{tree}` and `git rev-parse c3ba864^{tree}` both return `a4a79626fbd3782ed1d2e9f55c5ed5a0d3c89811`, and `git diff --stat origin/main c3ba864` is empty. Nothing was amended, squashed differently or re-resolved between verification and publication — the 18-08 technique.

### The shipped paths, from `git ls-tree -r origin/main --name-only`

```
kubernetes/nexus/README.md
kubernetes/nexus/files/provision.sh
kubernetes/nexus/templates/job-provision.yaml
kubernetes/nexus/values.yaml
scripts/check-nexus-chart.sh
scripts/check-nexus-setup.sh
scripts/nexus-live-smoke.sh
workstation/README.md
workstation/nexus-setup.sh
```

All nine. `git ls-tree -r origin/main -- workstation/nexus-setup.sh scripts/check-nexus-setup.sh` reports both at mode `100644` — the project's Script Safety rule holds on the published tree, not just locally.

### Content, from `git show origin/main:<path>`

- `git show origin/main:kubernetes/nexus/values.yaml | yq '.anonymous.enabled'` → **`false`**. The shipped default is closed on the public default branch.
- `git show origin/main:kubernetes/nexus/files/provision.sh | grep -c 'security/realms/active'` → **4** (the criterion asks for at least 2).
- Both standing offline gates re-run **against the merged tree** (detached at `origin/main`, then `main` fast-forwarded): `PASS - 18 checks, 0 failures` and `ALL PASS - 12 check(s) executed and passed; 0 sub-check(s) skipped (not passed).`

### The remote branch

`git ls-remote --heads origin feature/phase-24-nexus-anonymous-and-workstation` prints **nothing** — deleted on the remote, as the operator reported. Determined by `ls-remote`, never by a local `git branch -a`, per the Phase 23 evidence rule. The local branch still exists at `c3ba864` and is fully merged into local `main`; it was left in place, matching the other five merged phase branches already sitting in that repository, and deliberately not deleted.

## Why the requirements could be marked — and only now

`24-10-PLAN.md` frontmatter carries `requirements: [NEXUS-02, NEXUS-04]`. They were **not** marked during Task 1 or Task 2, and `requirements.mark-complete` was never invoked from frontmatter.

Threat `T-24-49` names "requirement marked before the deliverable is public" as a Repudiation threat with disposition `mitigate`, and the mitigation is: marks gated on `git ls-tree origin/main` output quoted in the SUMMARY. The 17-01 precedent already in `STATE.md` is a mark that had to be **reverted** because the deliverable shipped in a later plan. Plans 24-01 through 24-09 each carry `requirements-completed: []` with an explicit note that 24-10 marks them *after* the work reaches `origin/main`. NEXUS-01's Phase 23 precedent set the standard in one line: *a chart on an unpushed branch or in an open PR is not public.*

That condition is now satisfied and quoted above, so the marks were made **by hand**, in the same commit as the finalised validation contract:

- `.planning/REQUIREMENTS.md`: NEXUS-02 and NEXUS-04 flipped to `[x]`; both traceability rows `Pending` → `Complete`.
- The Out of Scope table's Docker carve-out row is **reconciled, not reverted**. The `daemon-opt-in` branch did ship, so the row is annotated *carve-out EXERCISED as shipped* with the ADR-021 decision 7 reference, the measured mirror URL shape and the `VERDICT: A3-FALSIFIED-CANDIDATE-1` citation — plus the one refinement on the operator's literal "both keys" selection, that `insecure-registries` is emitted only for a plain-`http` URL, so a reader comparing the script to the recorded decision does not read the difference as a defect.
- `24-VALIDATION.md`: `status: complete`, `nyquist_compliant: true`, `wave_0_complete: true`, all fifteen `24-W0-xx` rows green with the observing SUMMARY named in each row, all six Wave 0 requirement boxes ticked, all six sign-off boxes ticked.

Commit `fc6900e` — `git diff-tree --no-commit-id --name-only -r fc6900e` lists exactly the two paths in this plan's `files_modified` and nothing else.

**One validation row carries a correction rather than a plain pass.** `24-W0-11` originally named `PIP_CONFIG_FILE=… pip config get global.index-url` as its command. 24-07 measured that command to be unusable — it exits 1 with `ERROR: No such key` on pip 26.2.1 under every scope flag, against a file that plainly carries the key, because `get` reads the writable scopes only and cannot see the `:env:` variant `PIP_CONFIG_FILE` creates. The row is green on the behaviour (the script writes `pip.conf`; pip resolves its index through Nexus, verified by `pip config list` plus pip's own `Looking in indexes:` line plus a real component fetch), and the falsified command is recorded as falsified rather than quietly swapped. A validation contract that edits its own assertions to match whatever passed is worth nothing.

## Branch manifest — reconciled

Reconciled **before** the push, and quoted here as the manifest the operator approved. Branch: `feature/phase-24-nexus-anonymous-and-workstation`, in `repos/security-platform` (an independent git repository, not a submodule of this one). Cut from `main` at `ea2770f` — which is now the first parent of the merge commit. Working tree clean (`git status --porcelain` empty).

`git log --oneline origin/main..HEAD` — 13 commits:

```
c3ba864 docs(24-08): correct the script-mode claim in the workstation README
ee40e42 docs(24-08): document anonymous access and the workstation routing script
9ec38b6 fix(24-07): stop the pip verification fetch blocking on a credential prompt
ec9544d feat(24-07): add the measured Docker daemon-opt-in branch to nexus-setup.sh
c1df999 feat(24-07): add the --verify proof pass to nexus-setup.sh
4bdb5e9 feat(24-06): add workstation/nexus-setup.sh — per-repo npm, pip and Helm routing
3c41ab8 feat(24-06): add the npm and pip writers to nexus-setup.sh
dc01b0f feat(24-06): scaffold workstation/nexus-setup.sh with validated --url interface
9b670c4 test(24-05): prove anonymous Docker pull, realm state, path shape and the write boundary live
07c74e2 feat(24-02): prove anonymous pull for npm/PyPI/Helm live and wire the readiness knobs
41c2e6a fix(24-03): sanitise the routing environment before GLOBAL-CONFIG-UNTOUCHED snapshots
f008707 test(24-03): add the offline gate for the workstation Nexus routing script
1266279 feat(24-01): wire anonymous.enabled through to Nexus and invert the offline anonymous gate
```

Every commit is accounted for against a plan; **no unexplained commit**. The plan predicted commits from seven plans — 24-01, 24-02, 24-03, 24-05, 24-06, 24-07, 24-08 — and that is exactly what is there. The count per plan is 1 / 1 / 2 / 1 / 3 / 3 / 2 = 13. Three plans contribute more than one commit and each is already explained in its own SUMMARY: 24-03's `41c2e6a` is an environment-sanitisation fix to its own gate; 24-06 and 24-07 commit per task under the executor protocol, and 24-07's third commit (`9ec38b6`) is a Rule 1 fix found during its own verification; 24-08's `c3ba864` is a Rule 1 fix found during self-review, deliberately not amended into `ee40e42` because that SHA was already recorded in `STATE.md`.

Plans 24-04 and 24-09 contribute **no** commit to this branch by design — 24-04's A3 evidence files and 24-09's ADR-021 live in this documentation repository.

`git diff --stat origin/main..HEAD` — 9 files changed, 3,440 insertions(+), 83 deletions(-):

```
 kubernetes/nexus/README.md                    |   56 +-
 kubernetes/nexus/files/provision.sh           |  148 ++-
 kubernetes/nexus/templates/job-provision.yaml |   21 +
 kubernetes/nexus/values.yaml                  |   77 +-
 scripts/check-nexus-chart.sh                  |   95 +-
 scripts/check-nexus-setup.sh                  |  747 +++++++++++
 scripts/nexus-live-smoke.sh                   |  620 +++++++++-
 workstation/README.md                         |  122 ++
 workstation/nexus-setup.sh                    | 1637 +++++++++++++++++++++++++
```

## Gate results on the branch tip

All run from `repos/security-platform` at `c3ba864`, 2026-09-20. **`--no-verify` was not used anywhere, and no `git push` was invoked in any form, including `--dry-run`.**

| Gate | Command | Verdict | Exit |
|------|---------|---------|------|
| Chart offline gate | `bash scripts/check-nexus-chart.sh` | `PASS - 18 checks, 0 failures` | 0 |
| Workstation offline gate | `bash scripts/check-nexus-setup.sh` | `ALL PASS - 12 check(s) executed and passed; 0 sub-check(s) skipped (not passed).` | 0 |
| pre-commit | `pre-commit run --all-files` | ruff, ruff-format, shellcheck, yamllint, markdownlint all `Passed`; terraform_fmt, terraform_validate, hadolint, eslint, npm-audit `Skipped` (no matching files) | 0 |
| Live smoke | `bash scripts/nexus-live-smoke.sh` | `ALL PASS - 25 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).` | 0 |

The live gate's 25/0 matches 24-05's recorded count exactly, as predicted: its inputs have not changed since `9b670c4`. Both halves ran — the docker half against a real `sonatype/nexus3:3.96.0-ubi` container and the `kind` half through `KIND-DEPENDENCY-BUILD`, `KIND-INSTALL` and `KIND-JOB-COMPLETE`. No kind cluster and no Nexus container survived the run (`kind get clusters` → *No kind clusters found*; `docker ps -a --filter name=nexus` → empty).

### The gitleaks question, answered without pushing

`gitleaks` is configured at `stages: [pre-push]` in `.pre-commit-config.yaml`, which is why it does **not** appear in the `pre-commit run --all-files` output above — 23-06 recorded this and it reproduced exactly. The plan's acceptance criterion ("the gitleaks pre-push hook ran and passed") cannot be satisfied by the push, because the push is what is being withheld. Two things were established instead:

1. **The hook is installed.** `repos/security-platform/.git/hooks/pre-push` exists, mode 755, generated by pre-commit with `--hook-type=pre-push`. The eventual push *will* run gitleaks; no `pre-commit install` step needs to be added to the approved sequence.
2. **It passes on this exact range.** `pre-commit run gitleaks --hook-stage pre-push --from-ref origin/main --to-ref HEAD` → `Detect hardcoded secrets....Passed`, exit 0. The same hook with `--all-files` also passed. This is the same hook, the same stage and the same commit range the push will hand it.

This is a simulation, not the push itself. The hook runs again for real when the push is approved, and if it blocks then the finding is reported rather than bypassed.

GitHub server-side Push Protection is a separate mechanism that `--no-verify` cannot reach either (Phase 19's GH013 experience) and it cannot be simulated locally at all. It remains an unknown until the push happens.

### Auth

`gh auth status` → logged in to `github.com` as `OttawaCloudConsulting`, token scopes `gist`, `read:org`, `repo`, `workflow`. `repo` covers `gh pr create` against a public repository, so no auth gate is expected on the approved sequence.

## The PR, as drafted and as published

Target: `OttawaCloudConsulting/security-platform`, base `main`, head `feature/phase-24-nexus-anonymous-and-workstation`. Opened as **PR #15**, merged as `aed14b9`.

Title:

```
Phase 24: anonymous pull for the Nexus proxy repos, and the workstation routing script
```

The body is drafted in full and committed as phase evidence at
`.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-evidence/pr-body.md` (112 lines, mode 644),
with the title at `24-evidence/pr-title.txt` alongside it — the same evidence home 24-04 established. They are
committed rather than left in a session scratchpad **because this plan is not resumed in place**: a fresh agent
opens the PR, and the text the operator approves must be the byte-identical text that gets published. The body is
also reproduced verbatim in this plan's run output for the approval round-trip.

Every number in it traces to a named SUMMARY of this phase — the 24-08 / 24-09 discipline. Nothing is recalled:

| Claim in the PR body | Source |
|----------------------|--------|
| Offline gate counts 18 and 12 | 24-01, 24-07; re-measured on the branch tip today |
| Live gate 25 checks, 0 skipped | 24-05; re-measured on the branch tip today |
| npm 318,961 / PyPI 76,776 / Helm 291,818 bytes | 24-02 |
| Docker layer blob 3,626,020 bytes; the five-leg handshake; `/v2/<repo>` 200 vs `/v2/repository/<repo>` 404; write 403 | 24-05 |
| `VERDICT: A3-FALSIFIED-CANDIDATE-1`, components 0→1 vs 0→0, moby v28.3.2 source | 24-04 |
| `daemon-opt-in` shipped behind `--docker-daemon`, off by default; `insecure-registries` only for plain-http | 24-04 decision, 24-07 ADR-009 refinement |
| `anonymous.enabled: false` shipped default; `DockerToken` unconditional because an admin-issued token is also 401 without it | 24-01 |
| EULA/metadata boundary (PyPI 200 while npm and Helm are 403 at 192 bytes) | 24-02 |
| `nx-anonymous` wildcard scope; CE 40,000-component / 100,000-request ceiling | 24-01, values.yaml |
| `GET /service/rest/v1/repositories` inventory disclosure and its exact bounds | 24-08 |
| Checkov zero coverage, 24 latent findings (5 wrapper, 19 subchart) | 24-09, ADR-021 decision 10 |

The body's required elements, all present: PR #14 named as superseded (quoting its out-of-scope sentence verbatim from `gh pr view 14 --json body`, **not** from recall, and not editing PR #14); the `false` default; the unconditional `DockerToken` realm with its one-sentence reason; the measured evidence summary; the four residual risks; the attribution lines.

PR #14 was confirmed `MERGED` at `2026-09-19T11:41:43Z` on `OttawaCloudConsulting/security-platform`. (`STATE.md` also refers to a PR #14 on `OttawaCloudConsulting/terraform-pipelines` from Phase 22 — a different repository, not this one.)

## Deviations from Plan

### 1. [Approval gate] Task 1 split around an approval round-trip

**Found during:** Task 1, before any remote-visible action.
**Issue:** The orchestrator's brief, citing this project's operating protocol on irreversible and shared-visibility actions, requires explicit user confirmation *before* pushing a branch or opening a PR on a shared remote — not after. The plan's own Task 1 assumes the executor pushes.
**Action:** Everything up to and including the drafted push and PR was completed and reported; `git push` and `gh pr create` were withheld. `git push --dry-run` was also not run, since it is a push invocation that contacts the remote. On approval the operator performed both, and this executor verified the outcome — remote tip equals the gated tip, `0 13` ahead/behind, and the published PR title and body diffed byte-identical against the committed drafts — rather than assuming the report was accurate.
**Files modified:** none in `repos/security-platform`; the drafted text was committed here as `24-evidence/pr-title.txt` and `24-evidence/pr-body.md` precisely because the plan is not resumed in place.

### 2. [Evidence rule] The requirement marks were withheld until the merge, against the orchestrator's suggestion

**Found during:** planning the execution order.
**Issue:** The orchestrator's brief names "marking NEXUS-02/NEXUS-04 complete in REQUIREMENTS.md" as an example of a non-push task that could be completed and committed normally. The plan forbids exactly that until `git ls-tree origin/main` shows the work on the default branch.
**Action:** Not marked at Task 1 or Task 2; `.planning/REQUIREMENTS.md` was left untouched through both. The disagreement was reported rather than absorbed, per the contradiction-handling rule, and the marks were made in Task 3 once `git ls-tree origin/main` evidence existed and could be quoted.
**Rationale:** T-24-49; the 17-01 reverted-mark precedent; nine prior SUMMARYs in this phase withholding for the same reason; the NEXUS-01 precedent from Phase 23 that established the standard ("a chart on an unpushed branch or in an open PR is not public").

### 3. [State handlers] Progress handlers not run

**Found during:** the state-update step.
**Issue:** `state.advance-plan`, `state.update-progress` and `roadmap.update-plan-progress` derive progress from SUMMARY files on disk. Writing this SUMMARY would have made them report Phase 24 as 10/10 plans and the milestone as 18/18 — a completion claim for a phase that has not shipped.
**Action:** While the phase was open, only `state.record-session` was run, recording the pause and the resume condition. All three progress handlers were run at phase close, once the merge made a completion claim true, and their output was **read back and checked** rather than trusted: `state.advance-plan` → `advanced: false, reason: last_plan, status: ready_for_verification`; `state.update-progress` → `updated: false, reason: Progress field not found in STATE.md` (a no-op — the frontmatter block it looks for is not the field name it expects, which is why the side effect in deviation 4 was the only thing ever writing those numbers); `roadmap.update-plan-progress 24` → `10/10, Complete`. The resulting 18/18 / 100% is truthful now, and was verified against the phase's actual state rather than accepted.

### 4. [Rule 1 - Bug] `state.record-session` wrote a false completion claim; reverted by hand

**Found during:** the state-update step, immediately after running `gsd-sdk query state.record-session`.
**Issue:** The handler was asked only to record the session. It additionally, and silently, rewrote the frontmatter progress block to `completed_phases: 2`, `completed_plans: 18`, `percent: 100` — because `24-10-SUMMARY.md` now exists on disk and the handler re-derives progress from SUMMARY file counts. That is the exact false claim deviation 3 was avoiding. It also did **not** apply the `stopped_at` text passed to it; only `Last session` and `Resume File` changed.
**Fix:** The progress block was reverted by hand to the truthful `completed_phases: 1`, `completed_plans: 17`, `percent: 50`. `stopped_at` (frontmatter), `Stopped at:` (Session Continuity), the `Status:` line under *Current Position* and `Resume file:` were then written manually to record the pause. The defect is recorded in `STATE.md`'s decision log so the next executor does not trust the handler's scope.
**Files modified:** `.planning/STATE.md`.
**Lesson, now carried out:** the three progress handlers were run at phase close and their output read back (deviation 3). Note the asymmetry that makes this defect easy to miss — the handler that is *supposed* to write progress, `state.update-progress`, reports `updated: false, reason: Progress field not found in STATE.md` and writes nothing, while `state.record-session`, which has no business touching progress, silently rewrites it. Re-check the progress block after *any* state handler call, not just the ones named for it.
**Also note:** `state.record-metric` rejects positional arguments (`error: phase, plan, and duration required`) and requires flags — `--phase 24 --plan 10 --duration "…" --tasks 3 --files 6`. The executor protocol documents the positional form.

### 5. [Process] PR #15 was merged out of band, for the fourth consecutive phase

**Found during:** Task 3's mandatory re-read of PR state.
**Issue:** The plan's own context warns that PRs #9, #10 and #14 were all merged out of band by the operator, #14 through the UI while a plan was running, and instructs the executor to treat operator-merges-it-himself as the expected case. It happened again: PR #15 was merged at `20:46:24Z`, **two minutes** after creation and while this plan was still polling its checks. The `OPEN` / `mergedAt: null` state this SUMMARY records at the Task 2 gate was a true reading of a window that had already closed.
**Action:** `gh pr merge` was never invoked — there was nothing to merge, and an already-merged PR is reported, not re-merged (T-24-52). The merge was verified from `origin/main` rather than from the report, and the merged tree hash was compared against the gated tree hash to prove nothing changed between verification and publication.
**Not a defect:** this is now the established operating pattern for this project, not an anomaly. It is recorded so that the fifth occurrence is still met with a re-read rather than an assumption.

## Hand-off

Nothing in this plan remains open. For Phase 25 (NEXUS-05, the private ArgoCD overlay deploy):

- ADR-021's `What was NOT verified` item 6 is a named hand-off written for exactly that phase, so the overlay is authored once.
- Three things this phase could not measure and Phase 25 is positioned to: no pull was performed by the operator's own Docker daemon (three substitutes stood in); nothing was measured against a TLS-terminated Nexus, and no ingress exists yet; and no `helm upgrade` of an existing install was exercised, so the guarded realms append is proven across two provisioning passes on one instance and not across an upgrade of an instance whose PVC already carried Phase 23's state.
- The `anonymous.enabled: false` default means the overlay must opt in explicitly, and doing so accepts residual risks 1 and 2 above. Residual risk 3 (plaintext) is Phase 25's own subject matter.
- `.planning/phases/23-nexus-generic-chart/deferred-items.md` items 1 and 4-8 remain open; items 2 and 3 were dispositioned in 24-09.

## Self-Check: PASSED

- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-10-SUMMARY.md` — FOUND
- `24-evidence/pr-body.md` and `24-evidence/pr-title.txt` — FOUND, committed, and diffed byte-identical against PR #15's published title and body
- Commits `09cf77f`, `5bc1725`, `1fddbe7`, `fc6900e` — all FOUND in `git log`
- `git diff-tree --no-commit-id --name-only -r fc6900e` lists exactly `.planning/REQUIREMENTS.md` and `24-VALIDATION.md` — the two paths in `files_modified`, nothing else
- `origin/main` @ `aed14b9`; `origin/main^{tree}` == `c3ba864^{tree}` == `a4a7962` — CONFIRMED
- `git show origin/main:kubernetes/nexus/values.yaml | yq '.anonymous.enabled'` → `false` — CONFIRMED
- `git ls-remote --heads origin feature/phase-24-nexus-anonymous-and-workstation` — empty (branch deleted on the remote), determined by `ls-remote` not a local listing
- `.planning/REQUIREMENTS.md` NEXUS-02 / NEXUS-04 now `[x]` and `Complete` — CONFIRMED
- `24-VALIDATION.md` `status: complete`, `nyquist_compliant: true`, `wave_0_complete: true`, 15/15 rows green, 13/13 boxes ticked, 0 unticked — CONFIRMED
- `repos/security-platform` clean, on `main` at `aed14b9` (fast-forwarded) — CONFIRMED
