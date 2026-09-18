---
phase: 23-nexus-generic-chart
plan: 08
subsystem: infra
tags: [pull-request, ci, checkpoint, merge-gate, helm, nexus, public-repo]
status: PAUSED-AT-CHECKPOINT

# Dependency graph
requires:
  - phase: 23-nexus-generic-chart
    plan: 06
    provides: "the measured offline-gate PASS line, the two-pass idempotency outcome, the 318,961-byte post-EULA lodash download and the 14 -> 14 Checkov delta that this PR body quotes instead of recalling"
  - phase: 23-nexus-generic-chart
    plan: 07
    provides: "ADR-020, referenced from the PR body as the written home of the chart-base and EULA-opt-in decisions"
provides:
  - "OttawaCloudConsulting/security-platform PR #14 — OPEN, MERGEABLE, mergeStateStatus CLEAN, head e157a44135f98e7b718655c0a12ced5f7a9899f5"
  - "The branch feature/phase-23-nexus-generic-chart exists on origin for the first time (15 commits ahead of origin/main, 0 behind)"
  - "Twelve CI check conclusions on the chart, recorded verbatim — all SUCCESS, including the `Checkov` code-scanning check, which did NOT reproduce Phase 17-05's FAILURE"
  - "An OPEN, unanswered blocking approval gate (Task 2): the merge is authorised only by the operator's own reply"
affects: [23-08-task-3, phase-24-nexus-hardening]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "`gh pr create --body-file` from a scratchpad file rather than `--body`, because the body carries em dashes, backticks and fenced blocks that inline shell quoting mangles"
    - "`gh pr checks <N> --watch --interval 30` with the exit code captured explicitly (`echo CHECKS_EXIT=$?`), since gh exits non-zero when any check concludes FAILURE and that is data, not a tool error"
    - "PR-body acceptance criteria verified by grepping the body back OUT of GitHub (`gh pr view --json body -q .body | grep -cF '<literal>'`), not by trusting what was written into the file"

key-files:
  created:
    - ".planning/phases/23-nexus-generic-chart/23-08-SUMMARY.md"
  modified: []

key-decisions:
  - "Task 3 was NOT executed and `gh pr merge` was never invoked. The plan's Task 2 is `gate=\"blocking\"`, `config.json` has no `auto_advance` and `_auto_chain_active` is `false`, and the orchestrator's own dispatch explicitly withheld Task 3. The operator's reply is the only authorisation (T-23-14)."
  - "The push was made WITHOUT `--no-verify`, which is what made the pre-push gitleaks hook run for real — 23-06 observation 4 predicted exactly this, and the hook reported `Detect hardcoded secrets ... Passed`."
  - "The PR body states the Checkov result BOTH ways: `DELTA = 0` and `CI's Checkov provides zero coverage of this chart`. Quoting only the delta would have been true and misleading, which is 23-06's own recorded judgement."
  - "`eula.accepted` is described in the PR body as `defaults to false and must be flipped explicitly`, NOT as `no default`. Only `nexus3.rootPassword.secret` (and `repos.helm.remoteUrl`) are genuinely null; conflating the two would have misdescribed the value surface."
  - "No state handler beyond `state.record-session` was run. `state.advance-plan`, `roadmap.update-plan-progress` and `requirements.mark-complete` are deliberately deferred: plan 23-08 is NOT complete, and every 23-01..23-07 summary records that NEXUS-01/NEXUS-03 are marked by the plan that merges, not before it."

requirements-completed: []

# Metrics
duration: 12min
completed: null
---

# Phase 23 Plan 08: Publish the Chart — Tasks 1-2 Summary (PAUSED AT CHECKPOINT)

**The chart is now publicly proposed: PR #14 on `OttawaCloudConsulting/security-platform`, head `e157a44`, twelve CI checks all SUCCESS, `MERGEABLE` / `CLEAN` — and it is stopped dead at the one gate this project requires a human to open. Nothing is merged.**

## Performance

- **Duration:** ~12 min (push → PR → checks settled → summary)
- **Started:** 2026-09-18T20:05:00Z (approx.)
- **Tasks:** 2 of 3 — Task 1 complete, Task 2 **awaiting the operator's reply**, Task 3 **not executed**
- **Files modified in `repos/security-platform`:** 0. Both tasks are remote-state-only; `git status --porcelain` is empty and `HEAD` is still `e157a44135f98e7b718655c0a12ced5f7a9899f5`, unchanged since 23-05.

## Task Commits

**None in `repos/security-platform`.** The plan declares both tasks `(no local files modified — remote state only)`. The only commit this run produces is the documentation commit in the planning repository carrying this SUMMARY.

---

## Task 1 — Push the branch and open the pull request

### Pre-push state, observed

```
branch:                 feature/phase-23-nexus-generic-chart
git status --porcelain: (empty)
HEAD:                   e157a44135f98e7b718655c0a12ced5f7a9899f5
merge-base main HEAD:   cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef  (== origin/main)
ahead/behind origin/main: 15 ahead, 0 behind
```

### The push — gitleaks ran for real

`git push -u origin feature/phase-23-nexus-generic-chart`, **no `--no-verify`**:

```
Terraform fmt........................................(no files to check)Skipped
Terraform validate...................................(no files to check)Skipped
ruff (legacy alias)..................................(no files to check)Skipped
ruff format..........................................(no files to check)Skipped
shellcheck...............................................................Passed
Lint Dockerfiles.....................................(no files to check)Skipped
yamllint.................................................................Passed
markdownlint.............................................................Passed
eslint...............................................(no files to check)Skipped
npm audit............................................(no files to check)Skipped
Detect hardcoded secrets.................................................Passed
 * [new branch]      feature/phase-23-nexus-generic-chart -> feature/phase-23-nexus-generic-chart
branch 'feature/phase-23-nexus-generic-chart' set up to track 'origin/feature/phase-23-nexus-generic-chart'.
PUSH_EXIT=0
```

23-06's observation 4 — "23-08, which pushes the branch, will trigger [gitleaks] for real on `git push`" — is now an observation rather than a prediction. `Detect hardcoded secrets ... Passed`, on the whole tree, at the pre-push stage.

### The pull request

| Field | Value |
|---|---|
| **Number** | **#14** |
| **URL** | **https://github.com/OttawaCloudConsulting/security-platform/pull/14** |
| **Title** | Phase 23: Nexus Repository Helm chart with npm, PyPI, Docker and Helm proxy repos |
| **Head SHA** | `e157a44135f98e7b718655c0a12ced5f7a9899f5` |
| **Base** | `main` (`cdf2c21`) |
| **State** | `OPEN` |
| **mergeable / mergeStateStatus** | `MERGEABLE` / `CLEAN` |

The body was written to a scratchpad file and passed with `--body-file`; it states, with 23-06's measured values rather than recalled ones: what the PR adds (the wrapper chart around `stevehipwell/nexus3` 5.26.0, the two standing gate scripts, the `yamllint` exclusion, the `.gitignore` entry, the `infrastructure/` → `kubernetes/` front-page correction), the literal offline-gate PASS line, the live-smoke result with the lodash byte count and the two-pass idempotency outcome, the Checkov delta **and** the reason it is zero, the two consumer-set values, and that NEXUS-02 anonymous pull is deliberately not enabled.

**Body literals verified by reading the body back from GitHub** (`gh pr view 14 --json body -q .body | grep -cF …`):

| Literal | Occurrences in the published body |
|---|---|
| `PASS - 16 checks, 0 failures` | 2 |
| `ALL PASS - 12 live check(s) executed and passed; 0 sub-check(s) skipped` | 1 |
| `action=created (HTTP 201)` | 1 |
| `action=updated (HTTP 204)` | 1 |
| `318961 bytes` | 1 |
| `DELTA = 0` | 1 |
| `nexus3.rootPassword.secret` | 1 |
| `eula.accepted` | 1 |
| `NEXUS-02` | 1 |

### `gh pr checks 14` — verbatim, after the checks settled

```
Checkov	pass	5s	https://github.com/OttawaCloudConsulting/security-platform/runs/105740041048
GitGuardian Security Checks	pass	1s	https://dashboard.gitguardian.com
Semgrep OSS	pass	9s	https://github.com/OttawaCloudConsulting/security-platform/runs/105740065932
Trivy	pass	7s	https://github.com/OttawaCloudConsulting/security-platform/runs/105740017064
gitleaks	pass	3s	https://github.com/OttawaCloudConsulting/security-platform/runs/105739967241
security / Container — Trivy Image	pass	29s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/35388165765/job/105739911031
security / IaC — Checkov	pass	31s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/35388165765/job/105739911217
security / SAST — Semgrep CE	pass	37s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/35388165765/job/105739911085
security / SCA — Trivy Filesystem	pass	41s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/35388165765/job/105739911159
security / Secrets — Gitleaks	pass	17s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/35388165765/job/105739910796
tflint	pass	6s	https://github.com/OttawaCloudConsulting/security-platform/runs/105740090431
tflint-errors	pass	5s	https://github.com/OttawaCloudConsulting/security-platform/runs/105740091143
CHECKS_EXIT=0
```

Machine-readable conclusions (`gh pr checks 14 --json name,state`):

| Check | Conclusion |
|---|---|
| `security / SAST — Semgrep CE` | **SUCCESS** |
| `security / IaC — Checkov` | **SUCCESS** |
| `security / SCA — Trivy Filesystem` | **SUCCESS** |
| `security / Container — Trivy Image` | **SUCCESS** |
| `security / Secrets — Gitleaks` | **SUCCESS** |
| `Checkov` (code scanning) | **SUCCESS** |
| `Semgrep OSS` (code scanning) | **SUCCESS** |
| `Trivy` (code scanning) | **SUCCESS** |
| `gitleaks` (code scanning) | **SUCCESS** |
| `tflint` (code scanning) | **SUCCESS** |
| `tflint-errors` (code scanning) | **SUCCESS** |
| `GitGuardian Security Checks` (external app) | **SUCCESS** |

Twelve checks, twelve SUCCESS, `CHECKS_EXIT=0`. The GitGuardian App check that 16-05 flagged is still present and still outside the `security/*` set.

**The Phase 17-05 FAILURE precedent did not reproduce.** The plan anticipated a `Checkov` code-scanning FAILURE arising from this repository's deliberate `fixtures/` corpus, and prescribed discriminating a fixture finding from a `kubernetes/nexus/` one. No discrimination was needed: the `Checkov` check concluded **SUCCESS**. A plausible — and explicitly *unverified* — explanation is that a code-scanning check on a PR turns on alerts the PR *introduces*, and 23-06 measured this PR's Checkov delta as exactly zero with an identical `check_id`+`file_path` set, so there is nothing new for it to fail on. That reasoning was **not** measured here and is recorded as a hypothesis, not a finding. What *was* observed is the conclusion: SUCCESS.

### File-list acceptance, from GitHub

`gh pr view 14 --json files -q '.files[].path'`:

```
.gitignore
.pre-commit-config.yaml
README.md
kubernetes/nexus/.helmignore
kubernetes/nexus/Chart.lock
kubernetes/nexus/Chart.yaml
kubernetes/nexus/README.md
kubernetes/nexus/files/provision.sh
kubernetes/nexus/templates/_helpers.tpl
kubernetes/nexus/templates/configmap-provision-script.yaml
kubernetes/nexus/templates/configmap-repos.yaml
kubernetes/nexus/templates/job-provision.yaml
kubernetes/nexus/values.yaml
scripts/check-nexus-chart.sh
scripts/nexus-live-smoke.sh
```

- `kubernetes/nexus/Chart.yaml` — present
- `kubernetes/nexus/values.yaml` — present
- `kubernetes/nexus/files/provision.sh` — present
- paths under `kubernetes/nexus/charts/` — **count 0** (T-23-15: the vendored subchart tarball did not reach the remote)

### Task 1 `<verify>` block, run verbatim

```
cd repos/security-platform && test -z "$(git status --porcelain)" \
  && git rev-parse --abbrev-ref --symbolic-full-name @{u} | grep -q 'origin/feature/phase-23-nexus-generic-chart' \
  && gh pr view --json number,state,headRefName -q '.state' | grep -qx OPEN
VERIFY_EXIT=0
```

**Task 1 done criterion met:** the chart is proposed publicly and the repository's own security pipeline has judged it — green.

---

## Task 2 — Operator approval checkpoint: **OPEN, AWAITING THE OPERATOR**

`gh pr merge` was **not** invoked. No further commits were pushed. Branch protection and required checks were not touched.

### The checkpoint as presented

> **CHECKPOINT — approval required to merge into `security-platform` `main`**
>
> **Pull request:** **#14** — https://github.com/OttawaCloudConsulting/security-platform/pull/14
> **Head:** `e157a44135f98e7b718655c0a12ced5f7a9899f5` · **State:** `OPEN` · `MERGEABLE` / `CLEAN`
>
> **What it builds.** A Helm wrapper chart at `kubernetes/nexus/` around the community
> `stevehipwell/nexus3` **5.26.0** chart, plus `scripts/check-nexus-chart.sh` and
> `scripts/nexus-live-smoke.sh` as standing gates, a `yamllint` exclusion for Helm templates
> (`^kubernetes/.*/templates/`), a `.gitignore` entry for the vendored subchart tarball
> (`kubernetes/*/charts/*.tgz`), and a correction of the front-page directory name from
> `infrastructure/` to `kubernetes/`.
>
> **Measured evidence — quoted from `23-06-SUMMARY.md`, not recalled:**
>
> - Offline gate: `PASS - 16 checks, 0 failures`, exit 0, and `grep -c '^SKIP:'` = `0` (non-vacuous — all 16 checks actually ran).
> - Live smoke: `ALL PASS - 12 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).`, exit 0.
> - Two-pass idempotency: pass 1 = all four formats `action=created (HTTP 201)`; pass 2 = all four `action=updated (HTTP 204)` — the GET→PUT branch is real, not a repeat blind POST.
> - Post-EULA lodash download: **HTTP 200, `318961` bytes** (threshold 100,000; the pre-EULA refusal body is ~192 bytes).
> - Checkov delta, measured in the pinned CI container `checkov@sha256:41c4701c…`: **14 failed before, 14 failed after, identical `check_id`+`file_path` set, `CKV_K8S_*`/`CKV2_K8S_*` = 0 in both**; re-measured without `--soft-fail` (the CI setting): **exit 1 before, exit 1 after**. **DELTA = 0.**
> - And the half of that number that matters: the delta is zero because the pinned container's helm runner engages and then **cannot render the chart** — the chart's own `required` guard on `nexus3.rootPassword.secret` fires, logged at `WARNI`. So **CI's Checkov scans this chart zero times**. Rendered locally with values supplied, the chart carries **24** latent kubernetes-framework findings (5 on this phase's wrapper resources, 19 on the subchart). Accept-or-fix is Phase 24's call; the guard was deliberately not weakened to buy coverage.
>
> **CI on the PR — verbatim conclusions:** twelve checks, twelve `SUCCESS` (the five `security / *` jobs, six code-scanning checks including `Checkov`, and `GitGuardian Security Checks`). `CHECKS_EXIT=0`. Phase 17-05's `Checkov` FAILURE precedent did **not** reproduce, so no fixture-vs-chart discrimination was required.
>
> **The two decisions this merge makes public:**
>
> 1. **The chart base is a community chart, not a Sonatype-published one** (D-01 REVISED). `stevehipwell/nexus3` — MIT, ArtifactHub **verified publisher**, **unsigned** — running the official Sonatype Nexus image. Chosen because every Sonatype alternative is unusable: `nexus-repository-manager` is deprecated and frozen at 3.64.0 with a DB-corruption warning, and `nxrm-ha` requires 3 replicas, external PostgreSQL and a Pro licence.
> 2. **The Helm proxy ships no default remote** (D-05 REVISED). Helm Hub is defunct since 2020, Artifact Hub is a cross-repo search index rather than a chart repository serving a single `index.yaml`, and Bitnami's repo is mid-deprecation — so there is no honest default to hardcode. Consequence: **a default install creates three proxy repositories, not four**, until the consumer sets `repos.helm.remoteUrl`.
>
> **Also note:** the chart ships **no admin password** (`nexus3.rootPassword.secret: null`, enforced by Helm's `required`) and does **not** accept the Sonatype EULA on a consumer's behalf (`eula.accepted: false` by default — flipping it is an explicit opt-in). Anonymous pull (NEXUS-02) is deliberately **not** enabled by this PR.
>
> **How to verify before approving:** open PR #14 and review the diff, in particular
> `kubernetes/nexus/values.yaml` and `kubernetes/nexus/templates/job-provision.yaml`; confirm the
> CI state above matches what you expect; confirm you accept the two decisions. Merging is
> irreversible in practice — this repository is public and `main` is what other repositories consume.
>
> **Resume signal:** Reply with your explicit approval to merge (for example "Approved — merge"),
> or describe what must change first. Nothing merges without your own reply.

### Operator reply

**PENDING — not yet given.** No reply has been received in this execution. This section is to be replaced verbatim with the operator's own words when Task 3 is dispatched.

---

## Task 3 — NOT EXECUTED

Deliberately not run in this session. The orchestrator's dispatch scoped this execution to Tasks 1 and 2 and withheld Task 3 explicitly, because no operator reply exists to authorise it. `gh pr merge` does not appear anywhere in this run's command history. Task 3 remains exactly as the plan specifies: re-read the PR state first (this project has recorded the operator merging out of band twice — Phase 18 PR #9, Phase 19 PR #10 — in which case `gh pr merge` must NOT be run), otherwise merge with `gh pr merge 14 --merge`, then verify from `origin/main` after `git fetch`, never from the local working tree.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `state.record-session` marked the phase 100% complete while the merge gate is still open**

- **Found during:** the state-update step, after Task 2's checkpoint was reached
- **Issue:** `gsd-sdk query state.record-session` recalculates progress by counting `*-SUMMARY.md` files on disk. Because this SUMMARY had just been written, it flipped `completed_plans: 7 -> 8`, `completed_phases: 0 -> 1` and `percent: 0 -> 100` — asserting that Phase 23 is finished while PR #14 is unmerged and the approval gate is unanswered. It also left `stopped_at` at the stale `Completed 23-07-PLAN.md`.
- **Fix:** counters reverted by hand to `completed_plans: 7`, `completed_phases: 0`, `percent: 0`; both `stopped_at` (frontmatter) and `Stopped at:` (§Session Continuity) set to `PAUSED at 23-08 Task 2 checkpoint — PR #14 open, awaiting operator approval to merge`. `last_updated` / `Last session` were left at the handler's new timestamps, which are correct.
- **Files modified:** `.planning/STATE.md`
- **Commit:** `2a07929`
- **Carries forward:** the recount is triggered by this SUMMARY's mere existence. Any `state.update-progress`, or any executor init that recounts, will flip STATE.md back to 8/8 = 100% before Task 3 actually merges. The Task 3 continuation must **update this file in place** rather than create a new summary, and must be the one to run `advance-plan` / `roadmap.update-plan-progress` / `requirements.mark-complete`.

Otherwise none: no bug in the chart, no missing critical functionality and no blocking issue was encountered. The push, the PR creation and all twelve CI checks were green on first contact.

### Divergences from the plan text (deliberate, with reasons)

**1. The plan's `checkpoint:human-verify` was not followed by Task 3 in the same execution.** That is the plan working as designed under this dispatch, not a divergence from its intent — but it does mean this SUMMARY is written at a checkpoint rather than at plan completion, and its frontmatter carries `status: PAUSED-AT-CHECKPOINT` with `completed: null`.

**2. The plan's anticipated `Checkov` FAILURE branch was not exercised**, because the check concluded SUCCESS. The plan's instruction to discriminate a `fixtures/` finding from a `kubernetes/nexus/` one was therefore unnecessary; no `code-scanning/alerts` query was made, and this SUMMARY claims nothing about alert paths.

**3. `eula.accepted` is described as "defaults to `false`, must be flipped explicitly" rather than as "no default".** The plan's Task 1 text groups it with the admin Secret as "the two consumer-facing values that have no default". Strictly, only `nexus3.rootPassword.secret` (and `repos.helm.remoteUrl`) are `null`; `eula.accepted` has a default and it is `false`. The PR body states each accurately rather than flattening them into one claim.

**4. No state handler other than `state.record-session` was run.** `state.advance-plan`, `roadmap.update-plan-progress` and `requirements.mark-complete` all assert completion that has not happened. NEXUS-01 ("public Helm chart") is not yet literally true — the chart is on a branch and in an open PR, not on `main`.

## Observations Handed Forward

1. **PR #14 is `MERGEABLE` / `CLEAN` at head `e157a44`.** Task 3 must re-read the state before acting; if it already reads `MERGED`, the operator merged out of band (Phase 18/19 precedent) and `gh pr merge` must not be run.
2. **The `Checkov` code-scanning check passing is a data point Phase 24 should not over-read.** It is consistent with the measured zero delta, but it also sits on top of the fact that CI's Checkov never renders this chart. A green `Checkov` check on this PR is *not* evidence that `kubernetes/nexus/` is clean.
3. **Twelve checks now report on this repository's PRs**, up from the six 16-05 recorded — five `security / *` jobs, six code-scanning checks (`Checkov`, `Semgrep OSS`, `Trivy`, `gitleaks`, `tflint`, `tflint-errors`) and `GitGuardian Security Checks`. Phase 22's required-check list decision should be taken against this observed set, not against the older one.
4. **The pre-push gitleaks hook is now proven to run on a real push**, closing 23-06 observation 4.

## Threat Model Coverage

| Threat ID | Disposition | How this run handles it | Status |
|---|---|---|---|
| T-23-14 | mitigate | Execution stopped at the blocking checkpoint. `gh pr merge` was not invoked; no `auto_advance` is set and `_auto_chain_active` is `false`; the orchestrator's dispatch is explicitly not authorisation | ✅ held (gate open) |
| T-23-15 | mitigate | `gh pr view 14 --json files` read back from GitHub: zero paths under `kubernetes/nexus/charts/` | ✅ observed |
| T-23-02 | mitigate | The pushed tree passed the pre-push gitleaks hook (`Detect hardcoded secrets ... Passed`) and the `gitleaks` + `GitGuardian` checks on the PR; `nexus3.rootPassword.secret` is `null` with a `required` guard | ✅ observed |
| T-23-12 | mitigate | Every value here is read from a command's output — the push transcript, `gh pr checks`, `gh pr view --json`, and the PR body grepped back OUT of GitHub rather than assumed from the file that was uploaded | ✅ observed |
| T-23-SC | mitigate | No package-manager install occurred in this run | ✅ observed |

## Known Stubs

None introduced. The phase's one piece of inert surface — `provision.readiness.attempts` / `.intervalSeconds`, present in `values.yaml` and not read by `provision.sh` — is inherited from 23-04, documented as inert by 23-05, and handed to Phase 24 by 23-06/23-07. It is unchanged by this run.

## Threat Flags

None new. The `scanner-blind-spot` flag raised by 23-06 against `kubernetes/nexus/` still stands and is now stated in the public PR body as well as in ADR-020.

## Self-Check: PASSED

- `.planning/phases/23-nexus-generic-chart/23-08-SUMMARY.md` — created by this run
- PR **#14** — `gh pr view 14 --json state` = `OPEN`, `mergeable` = `MERGEABLE`, `mergeStateStatus` = `CLEAN`, `headRefOid` = `e157a44135f98e7b718655c0a12ced5f7a9899f5`
- `origin/feature/phase-23-nexus-generic-chart` — exists; local branch upstream verified via `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
- `repos/security-platform` working tree — `git status --porcelain` empty, `HEAD` = `e157a44`, no commits made (both tasks are remote-state-only by the plan's own `<files>` declaration)
- `gh pr checks 14` — 12 checks, all `SUCCESS`, `CHECKS_EXIT=0`, recorded verbatim above
- `gh pr merge` — **never invoked**; verified by the absence of any such command in this run
