---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 10
subsystem: infra
tags: [nexus, release, pull-request, gates, gitleaks, approval-gate, paused]
status: PAUSED — awaiting operator approval to push and open the PR

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
  - "A reconciled 13-commit / seven-plan branch manifest"
  - "A fully drafted PR title and body, held in the scratchpad, awaiting approval"
affects: [24-10-continuation, phase-25-nexus-live-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Run a pre-push-staged hook at its own stage against the exact push range (--from-ref/--to-ref) to learn its verdict without performing the push"

key-files:
  created:
    - .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-10-SUMMARY.md
  modified: []

key-decisions:
  - "NEXUS-02 and NEXUS-04 were NOT marked complete, and requirements.mark-complete was NOT run. The orchestrator's brief offered marking them as an example of non-push work that could proceed; the plan forbids it (T-24-49, the 17-01 reverted-mark precedent) and nine prior SUMMARYs in this phase withheld the marks for exactly this reason. Nothing is pushed, so there is no origin/main evidence, so there is no mark. The contradiction is resolved in favour of the plan's evidence rule and surfaced in the report rather than decided silently."
  - "24-VALIDATION.md was left at status: draft with all fifteen rows pending. Task 3 commits it together with the requirement marks; setting status: complete and wave_0_complete: true is the phase-close signal and would be as false as the marks while the work sits on an unpushed branch."
  - "state.advance-plan, state.update-progress and roadmap.update-plan-progress were NOT run. Both progress handlers count SUMMARY files on disk, so writing this file would have made them report Phase 24 as 18/18 complete. Only state.record-session ran, recording the pause."
  - "The live gate was re-run on the branch tip rather than cited from 24-05. Its inputs are unchanged since 9b670c4 (24-06/24-07 touched only workstation/, 24-08 only the READMEs), so 25/0 was the expectation — but the plan asks for a branch-tip verdict and an approval report should rest on a measurement taken now."
  - "git push --dry-run was deliberately NOT run. It is a git push invocation that contacts the remote; the approval gate is respected literally."

patterns-established:
  - "Pattern: when an orchestrator's brief and a plan's evidence rule disagree about whether a requirement may be marked, the evidence rule wins and the disagreement is reported, not absorbed."

requirements-completed: []  # NEXUS-02 and NEXUS-04 remain withheld — nothing is on origin/main.

# Metrics
duration: ~35min
completed: 2026-09-20
---

# Phase 24 Plan 10: Ship Phase 24 — Paused at the Push/PR Approval Gate Summary

**Every gate the plan asks for was run green on the branch tip and the PR was drafted in full — but the push and the PR creation were withheld for operator approval, and with them the two requirement marks that only `origin/main` evidence can justify.**

## Status: PAUSED

| Plan task | State |
|-----------|-------|
| Task 1 — push the branch and open the PR | **Partially executed.** Working tree confirmed clean, commit manifest reconciled, all four gates run green, PR title and body drafted in full. `git push` and `gh pr create` **not executed.** |
| Task 2 — merge approval gate | Not reached. |
| Task 3 — verify from `origin/main`, mark the requirements, finalise the validation contract | Not started, and **not startable**: it is gated on `git ls-tree origin/main` evidence that cannot exist until the branch is pushed and the PR merged. |

The orchestrator's brief required a stop before any action visible on the shared remote. That is a stricter reading of the same boundary the plan's own Task 2 draws, and it lands one step earlier.

## Why no requirement was marked

`24-10-PLAN.md` frontmatter carries `requirements: [NEXUS-02, NEXUS-04]`, and the executor protocol's state-update step says to mark a plan's frontmatter requirements complete. Both were ignored, deliberately.

Threat `T-24-49` in this plan's own register names "requirement marked before the deliverable is public" as a Repudiation threat with disposition `mitigate`, and the mitigation is: marks gated on `git ls-tree origin/main` output quoted in the SUMMARY. The 17-01 precedent already in `STATE.md` is a mark that had to be **reverted** because the deliverable shipped in a later plan. Plans 24-01, 24-02, 24-03, 24-04, 24-05, 24-06, 24-07, 24-08 and 24-09 each carry `requirements-completed: []` with an explicit note that 24-10 marks them *after* the work reaches `origin/main`.

Nothing is pushed. `git ls-remote --heads origin feature/phase-24-nexus-anonymous-and-workstation` prints nothing. There is no evidence, so there is no mark.

`requirements.mark-complete` was not invoked. `.planning/REQUIREMENTS.md` is byte-unchanged: NEXUS-02 and NEXUS-04 remain `[ ]` and both traceability rows remain `Pending`. `24-VALIDATION.md` is byte-unchanged at `status: draft`, `nyquist_compliant: false`, `wave_0_complete: false`.

## Branch manifest — reconciled

Branch: `feature/phase-24-nexus-anonymous-and-workstation`, in `repos/security-platform` (an independent git repository, not a submodule of this one). Cut from `main` at `ea2770f`, which is still the merge base. Working tree clean (`git status --porcelain` empty).

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

## The PR, drafted but not opened

Target: `OttawaCloudConsulting/security-platform`, base `main`, head `feature/phase-24-nexus-anonymous-and-workstation`.

Title:

```
Phase 24: anonymous pull for the Nexus proxy repos, and the workstation routing script
```

The body is drafted in full and held at
`/private/tmp/claude-501/-Users-christian-git-repos-OCC-github-development-environment-security-solution/1648f4c4-57ad-4825-9cc5-8628dd906a56/scratchpad/pr-body.md`
(112 lines), with the title at `pr-title.txt` alongside it. It is reproduced verbatim in this plan's run output for the approval round-trip.

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

### 1. [Approval gate] Task 1 stopped short of the push and the PR

**Found during:** Task 1, before any remote-visible action.
**Issue:** The orchestrator's brief, citing this project's operating protocol on irreversible and shared-visibility actions, requires explicit user confirmation *before* pushing a branch or opening a PR on a shared remote — not after.
**Action:** Everything up to and including the drafted push and PR was completed; `git push` and `gh pr create` were not run. `git push --dry-run` was also not run, since it is a push invocation that contacts the remote.
**Files modified:** none in `repos/security-platform`.

### 2. [Evidence rule] Task 3's requirement marks withheld, against the orchestrator's suggestion

**Found during:** planning the execution order.
**Issue:** The orchestrator's brief names "marking NEXUS-02/NEXUS-04 complete in REQUIREMENTS.md" as an example of a non-push task that could be completed and committed normally. The plan forbids exactly that until `git ls-tree origin/main` shows the work on the default branch.
**Action:** Not marked. The disagreement is reported rather than absorbed, per the contradiction-handling rule. `.planning/REQUIREMENTS.md` untouched.
**Rationale:** T-24-49; the 17-01 reverted-mark precedent; nine prior SUMMARYs in this phase withholding for the same reason; the NEXUS-01 precedent from Phase 23 that established the standard ("a chart on an unpushed branch or in an open PR is not public").

### 3. [State handlers] Progress handlers not run

**Found during:** the state-update step.
**Issue:** `state.advance-plan`, `state.update-progress` and `roadmap.update-plan-progress` derive progress from SUMMARY files on disk. Writing this SUMMARY would have made them report Phase 24 as 10/10 plans and the milestone as 18/18 — a completion claim for a phase that has not shipped.
**Action:** Only `state.record-session` was run, recording the pause and the resume condition.

### 4. [Rule 1 - Bug] `state.record-session` wrote a false completion claim; reverted by hand

**Found during:** the state-update step, immediately after running `gsd-sdk query state.record-session`.
**Issue:** The handler was asked only to record the session. It additionally, and silently, rewrote the frontmatter progress block to `completed_phases: 2`, `completed_plans: 18`, `percent: 100` — because `24-10-SUMMARY.md` now exists on disk and the handler re-derives progress from SUMMARY file counts. That is the exact false claim deviation 3 was avoiding. It also did **not** apply the `stopped_at` text passed to it; only `Last session` and `Resume File` changed.
**Fix:** The progress block was reverted by hand to the truthful `completed_phases: 1`, `completed_plans: 17`, `percent: 50`. `stopped_at` (frontmatter), `Stopped at:` (Session Continuity), the `Status:` line under *Current Position* and `Resume file:` were then written manually to record the pause. The defect is recorded in `STATE.md`'s decision log so the next executor does not trust the handler's scope.
**Files modified:** `.planning/STATE.md`.
**Lesson for the continuation agent:** after the merge, `state.advance-plan` / `state.update-progress` / `roadmap.update-plan-progress` will be correct to run — but verify the progress block they write rather than assuming it, and re-check it after *any* state handler call, including ones that have no business touching it.

## What the continuation agent must do

1. Obtain the operator's explicit approval for the push and the PR.
2. Push `feature/phase-24-nexus-anonymous-and-workstation`. The gitleaks pre-push hook runs for real; if it blocks, report the finding — do not use `--no-verify`, and note that it could not reach GitHub Push Protection anyway.
3. `gh pr create` with the drafted title and body. Record the PR number and URL. Do not merge.
4. Present Task 2's checkpoint: the PR URL, the four gate verdicts above, and the four residual risks. Record the operator's reply verbatim.
5. Task 3: **re-read PR state before any `gh pr merge`** — PRs #9, #10 and #14 were all merged out of band by the operator, #14 through the UI while a plan was running. An already-MERGED PR is reported, never re-merged.
6. Only then: `git fetch origin`, `git ls-tree -r origin/main --name-only`, `git show origin/main:<path>`, `git ls-remote --heads` — never the local working tree — and, with that evidence quoted, mark NEXUS-02 and NEXUS-04 and finalise `24-VALIDATION.md`.

## Self-Check: PASSED

- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-10-SUMMARY.md` — FOUND
- Scratchpad `pr-body.md` and `pr-title.txt` — FOUND
- `repos/security-platform` working tree clean, branch at `c3ba864`, unpushed — CONFIRMED
- `git ls-remote --heads origin feature/phase-24-nexus-anonymous-and-workstation` — empty, as expected for an unpushed branch
- `.planning/REQUIREMENTS.md` NEXUS-02 / NEXUS-04 still `[ ]` and `Pending` — CONFIRMED (intended state)
- `24-VALIDATION.md` still `status: draft` — CONFIRMED (intended state)
