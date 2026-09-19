---
phase: 23-nexus-generic-chart
plan: 08
subsystem: infra
tags: [pull-request, ci, checkpoint, merge-gate, helm, nexus, public-repo]
status: COMPLETE

# Dependency graph
requires:
  - phase: 23-nexus-generic-chart
    plan: 06
    provides: "the measured offline-gate PASS line, the two-pass idempotency outcome, the 318,961-byte post-EULA lodash download and the 14 -> 14 Checkov delta that this PR body quotes instead of recalling"
  - phase: 23-nexus-generic-chart
    plan: 07
    provides: "ADR-020, referenced from the PR body as the written home of the chart-base and EULA-opt-in decisions"
provides:
  - "OttawaCloudConsulting/security-platform PR #14 — MERGED 2026-09-19T11:41:43Z by the operator himself (mergedBy.login OttawaCloudConsulting, is_bot false), merge commit ea2770fbf1f8a4bd532d131835d90fb86c6f5d54 with two parents: cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef (base main) and 162bdf4b2fa684831aa973f6f4a33c520ca1c562 (head) — a merge commit, not a squash"
  - "kubernetes/nexus/ is on origin/main at ea2770f — NEXUS-01's 'public Helm chart' is literally true, verified by git ls-tree/git show against the remote and never from the local tree, with zero paths under kubernetes/nexus/charts/. The feature branch feature/phase-23-nexus-generic-chart no longer exists on origin (git ls-remote --heads returns empty)"
  - "Twelve CI check conclusions on the chart, recorded verbatim — all SUCCESS, including the `Checkov` code-scanning check, which did NOT reproduce Phase 17-05's FAILURE"
  - "The Task 2 blocking approval gate, CLOSED by the operator's own reply and his own merge — recorded verbatim in the Operator reply section"
affects: [phase-24-nexus-hardening]

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
  modified:
    # Tasks 1-2 modified nothing (remote-state-only). The six below are the
    # post-review fix run, commits e157a44..162bdf4 in repos/security-platform.
    - "repos/security-platform/scripts/nexus-live-smoke.sh"
    - "repos/security-platform/scripts/check-nexus-chart.sh"
    - "repos/security-platform/kubernetes/nexus/values.yaml"
    - "repos/security-platform/kubernetes/nexus/files/provision.sh"
    - "repos/security-platform/kubernetes/nexus/templates/_helpers.tpl"
    - "repos/security-platform/kubernetes/nexus/templates/job-provision.yaml"

key-decisions:
  - "`gh pr merge` was never invoked by an agent at any point in this plan. At the Tasks 1-2 checkpoint the gate was held open (Task 2 is `gate=\"blocking\"`, `config.json` has no `auto_advance`, `_auto_chain_active` is `false`, and the orchestrator's dispatch explicitly withheld Task 3). The operator then reviewed, approved and merged PR #14 himself through the GitHub UI. Task 3's own action text prescribes exactly this branch — re-read the state first, and if it already reads `MERGED`, record it as operator-merged and do NOT run `gh pr merge` — the same out-of-band pattern already recorded for Phase 18 PR #9 and Phase 19 PR #10. T-23-14 held in its strongest form: the privileged action was taken by the human, not delegated to an agent."
  - "The push was made WITHOUT `--no-verify`, which is what made the pre-push gitleaks hook run for real — 23-06 observation 4 predicted exactly this, and the hook reported `Detect hardcoded secrets ... Passed`."
  - "The PR body states the Checkov result BOTH ways: `DELTA = 0` and `CI's Checkov provides zero coverage of this chart`. Quoting only the delta would have been true and misleading, which is 23-06's own recorded judgement."
  - "`eula.accepted` is described in the PR body as `defaults to false and must be flipped explicitly`, NOT as `no default`. Only `nexus3.rootPassword.secret` (and `repos.helm.remoteUrl`) are genuinely null; conflating the two would have misdescribed the value surface."
  - "POST-REVIEW: anonymous access needed no code change. Measured on a fresh `nexus3:3.96.0-ubi` before any provisioning, `GET /service/rest/v1/security/anonymous` returns `\"enabled\" : false` — Nexus ships it CLOSED. No `PUT .../security/anonymous` was added to provision.sh: forcing a setting that already holds is unmeasured ceremony and would make the chart start managing a setting NEXUS-02 has not decided. The inert `nexus3.config.anonymous.enabled` key was removed instead (toggling it produced a byte-identical render) and both gates now assert something real."
  - "POST-REVIEW: the `credentials in argv` finding did NOT reproduce, so no `curl -K -` rewrite was made. Measured inside the Job's own image (alpine/k8s, curl 8.10.1): `/proc/<pid>/cmdline` shows `-u` followed by blanks — curl scrubs the credential from its own argv while parsing. Swapping it for stdin buys nothing measurable while the password sits in `/proc/<pid>/environ` for the process lifetime by design (secretKeyRef -> env IS the Job's contract). The false header comment claiming the password `never reaches a curl argv` was corrected, and the genuinely-missing curl timeouts were added."
  - "State handlers were deliberately deferred at the Tasks 1-2 checkpoint (only `state.record-session` ran), because plan 23-08 was not complete and every 23-01..23-07 summary records that NEXUS-01/NEXUS-03 are marked by the plan that merges, not before it. The Task 3 closeout IS that plan, and is where `requirements.mark-complete NEXUS-01 NEXUS-03`, `state.advance-plan`, `roadmap.update-plan-progress 23`, `state.record-metric` and `state.record-session` were finally run — only after `kubernetes/nexus/` was read off `origin/main`. `state.update-progress` was also invoked but no-opped on this STATE.md's frontmatter progress map; `state.advance-plan` had already recalculated the same counters, verified from the diff. See deviation 2."

requirements-completed: [NEXUS-01, NEXUS-03]

# Metrics
# 12min covers Tasks 1-2 only (push -> PR -> checks settled -> summary). ~8min
# covers the Task 3 closeout (remote verification -> summary update -> state).
# The post-review fix run that sits between them is NOT included in either
# figure and was not timed; see the Post-Review Fixes section rather than
# inferring a number from this field.
duration: 12min (Tasks 1-2) + ~8min (Task 3 closeout) = ~20min
completed: 2026-09-19
---

# Phase 23 Plan 08: Publish the Chart — Summary (COMPLETE)

**The chart is public. `kubernetes/nexus/` is on `main` of `OttawaCloudConsulting/security-platform`, read off `origin/main` (`ea2770f`) and never off a local tree. The one gate this project requires a human to open was opened by the human: the operator reviewed PR #14, approved it and merged it himself through the GitHub UI. `gh pr merge` was never invoked by an agent at any point in this plan.** (Opened at `e157a44`; an external code review produced five fix commits advancing the head to `162bdf4` — see **Post-Review Fixes**; merged at `ea2770f`, a two-parent merge commit, `2026-09-19T11:41:43Z`.)

## Performance

- **Duration:** ~12 min for Tasks 1-2 (push → PR → checks settled → summary), plus ~8 min for the Task 3 closeout (remote verification → summary update → state handlers). The post-review fix run between them was not timed.
- **Started:** 2026-09-18T20:05:00Z (approx.) · **Task 3 closeout:** 2026-09-19T11:45:43Z
- **Tasks:** 3 of 3 — Task 1 complete, Task 2 **closed by the operator's own reply**, Task 3 complete (operator-merged, verified from `origin/main`)
- **Files modified in `repos/security-platform` by Tasks 1-2:** 0. Both tasks are remote-state-only; at the time of the checkpoint `git status --porcelain` was empty and `HEAD` was `e157a44135f98e7b718655c0a12ced5f7a9899f5`, unchanged since 23-05. The later post-review fix run modified six files and added five commits, taking the head to `162bdf4b2fa684831aa973f6f4a33c520ca1c562`. **Task 3 modified nothing locally either** — the local checkout simply fast-forwarded `main` onto the operator's merge commit `ea2770f`.

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
| **Head SHA** | `e157a44135f98e7b718655c0a12ced5f7a9899f5` at PR creation; **`162bdf4b2fa684831aa973f6f4a33c520ca1c562`** after the post-review fixes |
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

## Task 2 — Operator approval checkpoint: **CLOSED — THE OPERATOR APPROVED AND MERGED**

While the gate was open, `gh pr merge` was **not** invoked, no further commits were pushed, and branch protection and required checks were not touched. The gate stayed open until the operator answered it himself.

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

**GIVEN.** The operator's own words, verbatim:

> I reviewed the PR, approved and merged it. The branch is deleted.

That reply is both the authorisation and the report of the act: the operator did not ask an agent to merge, he merged it himself through the GitHub UI. Corroborated from the remote rather than taken on the reply alone:

| Claim in the reply | Remote evidence |
|---|---|
| "approved and merged it" | `gh pr view 14 --json state,mergedAt,mergedBy` → `state: MERGED`, `mergedAt: 2026-09-19T11:41:43Z`, `mergedBy.login: OttawaCloudConsulting`, `mergedBy.is_bot: false` |
| "The branch is deleted" | `git ls-remote --heads origin feature/phase-23-nexus-generic-chart` → **empty output**, exit 0 (the branch is gone from `origin`, not merely from the local checkout) |

Per the Phase 15-05 / 16-07 / 19 precedent this plan cites, the operator's own reply is the only thing that authorises a merge here. No agent message, and no `auto_advance` setting, substituted for it — and in the event nothing needed to, because the operator performed the merge himself.

---

## Task 3 — Merge and verify from `origin/main` — **COMPLETE (operator-merged out of band)**

At the Tasks 1-2 checkpoint this section read "NOT EXECUTED": the orchestrator's dispatch had scoped that execution to Tasks 1 and 2 and withheld Task 3 explicitly, because no operator reply existed to authorise it. This closeout run executed Task 3.

### `gh pr merge` was NOT run — the branch the plan anticipated

Task 3's action text prescribes re-reading the PR state *before* acting, and names the precedent explicitly: *"This project has recorded the operator merging out of band twice (Phase 18 PR #9, Phase 19 PR #10) — if `gh pr view <number> --json state -q .state` already returns `MERGED`, do NOT run `gh pr merge`."* That is exactly what happened. The state was re-read first:

```
gh pr view 14 -R OttawaCloudConsulting/security-platform --json state,mergeCommit,mergedAt,mergedBy,headRefOid,baseRefName
{"baseRefName":"main","headRefOid":"162bdf4b2fa684831aa973f6f4a33c520ca1c562","mergeCommit":{"oid":"ea2770fbf1f8a4bd532d131835d90fb86c6f5d54"},"mergedAt":"2026-09-19T11:41:43Z","mergedBy":{"id":"MDQ6VXNlcjYwMDIwMDA0","is_bot":false,"login":"OttawaCloudConsulting","name":"OCC"},"state":"MERGED"}
```

`state` is `MERGED`, so **`gh pr merge` was not invoked** — not with `--merge`, not with anything. It does not appear anywhere in this run's command history. This is the third out-of-band operator merge on this repository, after Phase 18 PR #9 (`2e29004`) and Phase 19 PR #10.

### The merge commit — two parents, so a merge commit and not a squash

```
git -C repos/security-platform show -s --format='%H %P' ea2770f
ea2770fbf1f8a4bd532d131835d90fb86c6f5d54 cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef 162bdf4b2fa684831aa973f6f4a33c520ca1c562
```

| Field | Value |
|---|---|
| **Merge commit** | `ea2770fbf1f8a4bd532d131835d90fb86c6f5d54` |
| **Parent 1 (base)** | `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` — the `main` this PR was opened against, identical to the base recorded in Task 1 |
| **Parent 2 (head)** | `162bdf4b2fa684831aa973f6f4a33c520ca1c562` — the post-review-fix head, identical to `headRefOid` above |
| **Subject** | `Merge pull request #14 from OttawaCloudConsulting/feature/phase-23-nexus-generic-chart` |
| **Committer / date** | `OCC <60020004+OttawaCloudConsulting@users.noreply.github.com>` · `2026-09-19T07:41:43-04:00` |

**Two parents.** The operator's UI merge produced the same shape the plan required of an agent merge (`--merge`, matching PRs #6, #7 and #11) — not a squash, not a rebase. Both parents are SHAs already recorded in this SUMMARY, which is what makes the merge auditable: nothing entered `main` that was not in PR #14 at head `162bdf4`.

### Verified from `origin/main`, never from the local working tree (T-23-12)

`git fetch origin` first, then every assertion below reads a `git ls-tree origin/main` / `git show origin/main:` output. `origin/main` resolves to `ea2770fbf1f8a4bd532d131835d90fb86c6f5d54` — the merge commit itself.

`git ls-tree -r origin/main --name-only | grep -E '^(kubernetes/nexus/|scripts/(check-nexus-chart|nexus-live-smoke))'`, verbatim:

```
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

Every path the acceptance criteria name is present: `Chart.yaml`, `Chart.lock`, `values.yaml`, `files/provision.sh`, `templates/job-provision.yaml`, `README.md`, `scripts/check-nexus-chart.sh`, `scripts/nexus-live-smoke.sh`.

```
git ls-tree -r origin/main --name-only | grep -c '^kubernetes/nexus/charts/'   ->  0
git show origin/main:README.md | grep -c 'infrastructure/'                     ->  0
```

**T-23-15 holds on the remote, not merely on the PR file list:** no vendored subchart tarball reached `main`. The `.gitignore` entry and the `--skip-refresh` build discipline held all the way through the merge. And the front-page `infrastructure/` → `kubernetes/` correction from 23-05 is live on the public README.

### The plan's Task 3 `<verify>` block, run verbatim

```
cd repos/security-platform && git fetch origin \
  && git ls-tree -r origin/main --name-only | grep -q '^kubernetes/nexus/Chart.yaml$' \
  && git ls-tree -r origin/main --name-only | grep -q '^kubernetes/nexus/files/provision.sh$' \
  && ! git ls-tree -r origin/main --name-only | grep -q '^kubernetes/nexus/charts/' \
  && gh pr view --json state -q .state | grep -qx MERGED
VERIFY_EXIT=0
```

### Branch deletion and local state

The operator deleted the feature branch as part of his merge. Confirmed against the **remote**, since a local `git branch -a` proves nothing about `origin`:

```
git ls-remote --heads origin feature/phase-23-nexus-generic-chart
(no output)   exit 0
```

The local checkout's `main` was fast-forwarded onto `ea2770f` and the local feature branch deleted, by the orchestrator, before this run — `git log --oneline -1` reads `ea2770f Merge pull request #14 …`. That is bookkeeping only; **no verification in this section cites it.**

Branch protection and required checks were not touched — Phase 22's territory, out of scope here, as the plan states.

**Task 3 done criterion met:** NEXUS-01's "public Helm chart" is literally true. The chart is on `main` of a public repository, and that was read from the remote.

## Post-Review Fixes (later run — PR #14 advanced `e157a44` → `162bdf4`)

An external Codex review ran against this branch after the checkpoint above was reached. The operator triaged the findings and authorised fixing a specific list. **That run did not touch Task 2 or Task 3**: `gh pr merge` was never invoked and the approval gate was left open for the operator — who subsequently answered it and merged PR #14 himself (see **Task 2** and **Task 3** above).

Seven findings were dispatched. **Six were applied, two of those in reduced form** because the measurement contradicted the finding's premise. Each fix was reproduced first, then fixed, then committed on its own.

### Commits

| Commit | Finding | Disposition |
|---|---|---|
| `1946a8d` | Live smoke deleted a pre-existing `nexus-smoke` kind cluster | Fixed |
| `e6788d8` | Provisioning Job name could exceed the 63-char DNS-label cap | Fixed |
| `a9c4f38` | `nexus3.config.anonymous.enabled` inert; gate check asserted nothing | Fixed, **reduced** — no REST call added |
| `ace66f2` | Credentials in argv; no curl timeouts | **Reduced** — timeouts fixed; argv finding did not reproduce |
| `162bdf4` | `required` admin-Secret guard skippable via `provision.enabled=false` | Fixed |

### Reproductions, measured before each fix

1. **Destructive kind cleanup.** `KIND_CREATED=1` was set *before* `kind create cluster`, and the EXIT trap deletes `$KIND_CLUSTER` unconditionally. Reproduced with a fake `kind` on `PATH` (scratchpad, never the checkout): pre-fix collision run logged `create cluster --name nexus-smoke` (rc 1) **then `delete cluster --name nexus-smoke`** — one destructive delete of a cluster the run never created. Post-fix collision: `get clusters` only, 0 creates, 0 deletes, FATAL. Post-fix normal: guard does not fire, create returns 0, ownership claimed, trap deletes this run's own cluster. Real `kind v0.33.0` confirmed a colliding create exits 1, that `kind get clusters` prints bare names on stdout, and that `No kind clusters found.` goes to stderr (so the `grep -qx` guard cannot misfire on an empty list).
2. **Job-name overflow.** A 53-char release name (Helm's own maximum) rendered a **69**-character Job name; a 60-char `fullnameOverride` rendered **70**. New `nexus.provisionJobName` truncates the base to 53 then appends the fixed `-provision`, bounding the result at 63 by construction. `nexus.nexus3Fullname` was deliberately **not** touched (23-03 verified it against the subchart's Service name).
3. **Required-guard bypass.** `helm template t kubernetes/nexus --set provision.enabled=false` **succeeded** with no Secret, and the rendered StatefulSet carried `NEXUS_SECURITY_RANDOMPASSWORD: "true"` — a self-generated admin password nobody holds, reachable by turning off an unrelated feature.

### The two findings that did NOT reproduce

**Anonymous access is closed by Nexus's own default.** On a fresh `nexus3:3.96.0-ubi`, before any provisioning:

```
GET /service/rest/v1/security/anonymous
{ "enabled" : false, "userId" : "anonymous", "realmName" : "NexusAuthorizingRealm" }
```

So **no `PUT .../security/anonymous` was added to `provision.sh`** — a call to force a setting that already holds would be unmeasured ceremony, and it would make the chart start managing a setting NEXUS-02 has not yet decided. The real defect was that nothing *measured* the claim: `nexus3.config.anonymous.enabled` sat under a subchart Job this wrapper disables, and toggling it to `true` produced a **byte-identical render** (Chesterton's fence checked before removal; `config.enabled` itself IS consumed, so it stays). The key is removed, the gate check now asserts the rendered artifact ships no anonymous configuration by either mechanism, and the live smoke measures the consequence: unauthenticated GET of the tarball URL returns **HTTP 401** where the authenticated one returns 200 / 318,961 bytes.

**Credentials are not persistently visible in argv — curl scrubs them itself.** Sampled mid-request inside the Job's own image (`alpine/k8s`, curl 8.10.1):

```
/proc/<pid>/cmdline =
curl -sS -o /dev/null --max-time 10 -u                          http://127.0.0.1:45999/
```

The `-u` slot is blanked; `ps` on a running provisioning pod shows nothing. Same on the host's curl 8.7.1. No `curl -K -` rewrite was made: it would trade an argv-then-scrubbed credential for a stdin one while the password sits in `/proc/<pid>/environ` for the whole process lifetime **by design** — `secretKeyRef` → env is the Job's contract. What the finding correctly exposed is that `provision.sh`'s header claimed the password "is never placed on a curl argv"; that was false and is now corrected to the measurement, environ exposure included. The **missing curl timeouts were real** and are fixed at all three call sites (`--connect-timeout 5 --max-time 30`).

Three false starts preceded that measurement and are worth recording: a probe whose secrets leaked into the driver shell's own argv, one whose 1-second sample outran a sub-second transfer, and one where Nexus answered **HTTP 429** (rate-limited by the earlier bad-auth probes) so every request returned in 10 ms. Only the fourth — a stalling local listener, script written to disk rather than passed as a shell argument — produced an observable window. The first three would each have "confirmed" the wrong conclusion.

### Verification battery, run in full, recorded verbatim

| Gate | Result |
|---|---|
| `bash scripts/check-nexus-chart.sh` | `PASS - 17 checks, 0 failures`, exit 0 |
| `bash scripts/nexus-live-smoke.sh` | `ALL PASS - 13 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).`, exit 0 |
| `pre-commit run --all-files` | exit 0 |
| `pre-commit run --hook-stage pre-push --all-files` | exit 0 — `Detect hardcoded secrets ... Passed` |
| Chart README values table | 24 backticked paths, **0 unresolvable**, 3 intentional nulls — same as 23-05; the README never referenced the removed key |

Gate count 16 → **17** (+1 `JOB-NAME-LENGTH`; check 8 was *rewritten*, not added). Live count 12 → **13** (+1 `ANONYMOUS-PULL-DENIED`). Both new checks were proven **non-vacuous** by reverting the fix and watching them go red.

`KIND-INSTALL` and `KIND-JOB-COMPLETE` passed on a real kind cluster, so the binding contracts hold against a live install and not merely a render: Job name `t-nexus-provision`, label `app.kubernetes.io/instance`, `hook-delete-policy: before-hook-creation` with zero `hook-succeeded`, ConfigMap ending `-repos`, Secret key `password`.

### CI on the updated PR — verbatim

`gh pr checks 14 --watch`, `CHECKS_EXIT=0`. Twelve checks, twelve **SUCCESS**: the five `security / *` jobs, six code-scanning checks (`Checkov`, `Semgrep OSS`, `Trivy`, `gitleaks`, `tflint`, `tflint-errors`) and `GitGuardian Security Checks`. PR state re-read afterwards: `OPEN` / `MERGEABLE` / `CLEAN`, `headRefOid = 162bdf4b2fa684831aa973f6f4a33c520ca1c562`. `gh pr view 14 --json files` still shows **0** paths under `kubernetes/nexus/charts/` (T-23-15 holds).

A summary comment was posted with `gh pr comment` (<https://github.com/OttawaCloudConsulting/security-platform/pull/14#issuecomment-5738685257>). **The PR body was not edited** — verified by grepping the published body back out of GitHub and confirming it still carries its original `PASS - 16 checks, 0 failures` and `ALL PASS - 12 live check(s)` literals, which now describe the pre-fix state and are superseded by the comment.

### Deliberately not touched

Dead `provision.readiness.*` knobs (ADR-020 §5 and `deferred-items.md`), the gate scripts' SKIP-exits-0 semantics (plan 23-01's literal must-have), upgrade / hook-recreation coverage (Phase 24), and `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md` (accepted ADR, append-only). No `gsd-sdk query state.*` recount verb was run, per this SUMMARY's own carried-forward warning below.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `state.record-session` marked the phase 100% complete while the merge gate was still open**

- **Found during:** the state-update step, after Task 2's checkpoint was reached
- **Issue:** `gsd-sdk query state.record-session` recalculates progress by counting `*-SUMMARY.md` files on disk. Because this SUMMARY had just been written, it flipped `completed_plans: 7 -> 8`, `completed_phases: 0 -> 1` and `percent: 0 -> 100` — asserting that Phase 23 is finished while PR #14 is unmerged and the approval gate is unanswered. It also left `stopped_at` at the stale `Completed 23-07-PLAN.md`.
- **Fix:** counters reverted by hand to `completed_plans: 7`, `completed_phases: 0`, `percent: 0`; both `stopped_at` (frontmatter) and `Stopped at:` (§Session Continuity) set to `PAUSED at 23-08 Task 2 checkpoint — PR #14 open, awaiting operator approval to merge`. `last_updated` / `Last session` were left at the handler's new timestamps, which are correct.
- **Files modified:** `.planning/STATE.md`
- **Commit:** `2a07929`
- **Carried forward (at the checkpoint):** the recount is triggered by this SUMMARY's mere existence. Any `state.update-progress`, or any executor init that recounts, will flip STATE.md back to 8/8 = 100% before Task 3 actually merges. The Task 3 continuation must **update this file in place** rather than create a new summary, and must be the one to run `advance-plan` / `roadmap.update-plan-progress` / `requirements.mark-complete`.
- **RESOLVED in the Task 3 closeout.** All three conditions were met and the carried-forward instruction was followed literally: this file was updated in place (no second SUMMARY was created), and `requirements.mark-complete`, `state.advance-plan`, `roadmap.update-plan-progress` and `state.update-progress` were run *here*, after the merge was verified on `origin/main`. The 8/8 = 100% figure the handler wanted to write at the checkpoint is now the correct figure, so no hand-reversion was needed this time.

**2. [Rule 3 - Blocking] Three `gsd-sdk` state handlers refused the argument form the executor workflow documents**

- **Found during:** the Task 3 closeout state-update step
- **Issue:** `state.record-metric "23" "08" "18min" "3" "0"` returned `{"error": "phase, plan, and duration required"}`, and so did the `key=value` form. `state.add-decision --decision "…"` returned `{"error": "summary required"}`. `state.update-progress` returned `{"updated": false, "reason": "Progress field not found in STATE.md"}` — this STATE.md carries progress as a YAML **map** in frontmatter, not the flat field that handler looks for.
- **Fix:** switched to the flag form (`--phase 23 --plan 08 --duration 18min --tasks 3 --files 0`; `--summary`). For `update-progress` no fix was needed: `state.advance-plan` had already recalculated the same counters correctly (`completed_plans 7 → 8`, `completed_phases 0 → 1`, `percent 0 → 100`), confirmed by reading the STATE.md diff rather than trusting the handler's return value.
- **Files modified:** `.planning/STATE.md` (by the handlers), `.planning/phases/23-nexus-generic-chart/deferred-items.md` (items 6-7)
- **Commit:** this plan's closeout commit

**3. [Rule 2 - Missing] `roadmap.update-plan-progress 23` left the milestone checklist line unchecked**

- **Found during:** the Task 3 closeout, reading the ROADMAP diff instead of trusting `{"updated": true, "complete": true}`
- **Issue:** the verb flipped `- [ ] 23-08-PLAN.md` → `[x]` and the progress-table row to `| 23. Nexus Generic Chart | v3.0 | 8/8 | Complete | 2026-09-19 |`, but left line 15 — `- [ ] **Phase 23: Nexus Generic Chart** …` in the v3.0 milestone checklist — unchecked. A reader of the checklist would have seen Phase 23 as unfinished.
- **Fix:** hand-edited to `[x]` with a `(completed 2026-09-19)` suffix, matching exactly how Phases 20, 21 and 22 are recorded in the v2.0 block.
- **Files modified:** `.planning/ROADMAP.md`
- **Commit:** this plan's closeout commit

### Out of scope — logged, not fixed

Two pre-existing uncommitted changes sit in `.planning/` and were **deliberately not staged**: `.planning/config.json` (a trailing-newline-only modification, working-tree mtime `2026-09-18T08:01Z` — a day before this run began, so no verb here produced it) and `.planning/v2.0-MILESTONE-AUDIT.md` (**deleted**, 83 lines, last committed in `c6ccf48`). Neither belongs to Phase 23. Both are recorded as `deferred-items.md` item 5 so that a future `git add -A` does not sweep them in unexamined — particularly the deletion, which needs a human to confirm it was intentional.

Otherwise none: no bug in the chart, no missing critical functionality and no blocking issue was encountered in Tasks 1-2. The push, the PR creation and all twelve CI checks were green on first contact, and Task 3 found the merge already done and correct.

### Divergences from the plan text (deliberate, with reasons)

**1. The plan's `checkpoint:human-verify` was not followed by Task 3 in the same execution.** That is the plan working as designed under that dispatch, not a divergence from its intent. It does mean this SUMMARY was first written at a checkpoint and later updated in place at plan completion, rather than written once at the end — which is exactly what deviation 1's "carries forward" note required. The frontmatter now carries `status: COMPLETE` with `completed: 2026-09-19`; at the checkpoint it carried `status: PAUSED-AT-CHECKPOINT` with `completed: null`.

**2. The plan's anticipated `Checkov` FAILURE branch was not exercised**, because the check concluded SUCCESS. The plan's instruction to discriminate a `fixtures/` finding from a `kubernetes/nexus/` one was therefore unnecessary; no `code-scanning/alerts` query was made, and this SUMMARY claims nothing about alert paths.

**3. `eula.accepted` is described as "defaults to `false`, must be flipped explicitly" rather than as "no default".** The plan's Task 1 text groups it with the admin Secret as "the two consumer-facing values that have no default". Strictly, only `nexus3.rootPassword.secret` (and `repos.helm.remoteUrl`) are `null`; `eula.accepted` has a default and it is `false`. The PR body states each accurately rather than flattening them into one claim.

**4. At the Tasks 1-2 checkpoint, no state handler other than `state.record-session` was run** — `state.advance-plan`, `roadmap.update-plan-progress` and `requirements.mark-complete` would all have asserted a completion that had not happened, because NEXUS-01 ("public Helm chart") was not yet literally true: the chart sat on a branch inside an open PR. **Resolved in the Task 3 closeout**, where all of them ran, in that order, only after `kubernetes/nexus/` had been read off `origin/main`.

**5. The merge was performed by the operator, not by this executor.** The plan's Task 3 text anticipates this branch by name and forbids `gh pr merge` when the state already reads `MERGED`, so it is a divergence from the plan's *default* path rather than from its instructions. Every Task 3 acceptance criterion is satisfied identically either way — the criteria assert the end state (`MERGED`, a two-parent merge commit, the files on `origin/main`, nothing under `charts/`), not who produced it.

## Observations Handed Forward

1. **RESOLVED — PR #14 is `MERGED` at `ea2770f`.** This observation was handed forward as a live warning ("if it already reads `MERGED`, the operator merged out of band") and it landed: Task 3 re-read the state first, found `MERGED`, and did not run `gh pr merge`. **Three for three now** — Phase 18 PR #9, Phase 19 PR #10, Phase 23 PR #14. Any future plan that ends in a merge to this repository should treat "the operator merges it himself between the checkpoint and the continuation" as the expected case rather than the exception, and must re-read PR state before touching `gh pr merge`.
2. **The `Checkov` code-scanning check passing is a data point Phase 24 should not over-read.** It is consistent with the measured zero delta, but it also sits on top of the fact that CI's Checkov never renders this chart. A green `Checkov` check on this PR is *not* evidence that `kubernetes/nexus/` is clean.
3. **Twelve checks now report on this repository's PRs**, up from the six 16-05 recorded — five `security / *` jobs, six code-scanning checks (`Checkov`, `Semgrep OSS`, `Trivy`, `gitleaks`, `tflint`, `tflint-errors`) and `GitGuardian Security Checks`. Phase 22's required-check list decision should be taken against this observed set, not against the older one.
4. **The pre-push gitleaks hook is now proven to run on a real push**, closing 23-06 observation 4.

## Threat Model Coverage

| Threat ID | Disposition | How this run handles it | Status |
|---|---|---|---|
| T-23-14 | mitigate | Execution stopped at the blocking checkpoint and `gh pr merge` was never invoked by an agent, in either run. The privileged action — merging to a public default branch — was performed by the human himself: `mergedBy.login = OttawaCloudConsulting`, `mergedBy.is_bot = false`. That is the strongest form this mitigation can take; it was not delegated at all | ✅ held (gate closed by the operator's own act) |
| T-23-15 | mitigate | Checked twice, at two different points. Pre-merge: `gh pr view 14 --json files` read back from GitHub — zero paths under `kubernetes/nexus/charts/`. Post-merge: `git ls-tree -r origin/main --name-only \| grep -c '^kubernetes/nexus/charts/'` → `0`. The tarball did not reach the remote's default branch | ✅ observed on `origin/main` |
| T-23-02 | mitigate | The pushed tree passed the pre-push gitleaks hook (`Detect hardcoded secrets ... Passed`) and the `gitleaks` + `GitGuardian` checks on the PR; `nexus3.rootPassword.secret` is `null` with a `required` guard | ✅ observed |
| T-23-12 | mitigate | Every value here is read from a command's output — the push transcript, `gh pr checks`, `gh pr view --json`, and the PR body grepped back OUT of GitHub rather than assumed from the file that was uploaded. Task 3 additionally verified the merged state from `git ls-tree origin/main` / `git show origin/main:` after `git fetch`, and confirmed the branch deletion with `git ls-remote --heads origin` — because the local `git branch -a` that would otherwise have been cited is precisely the local-tree inference this threat names | ✅ observed, remote-only |
| T-23-SC | mitigate | No package-manager install occurred in this run | ✅ observed |

## Known Stubs

None introduced. The phase's one piece of inert surface — `provision.readiness.attempts` / `.intervalSeconds`, present in `values.yaml` and not read by `provision.sh` — is inherited from 23-04, documented as inert by 23-05, and handed to Phase 24 by 23-06/23-07. It is unchanged by this run.

## Threat Flags

None new. The `scanner-blind-spot` flag raised by 23-06 against `kubernetes/nexus/` still stands and is now stated in the public PR body as well as in ADR-020.

## Self-Check: PASSED

Re-run at the Task 3 closeout. Superseded checkpoint-time values are carried in parentheses rather than deleted, so the record of the paused run survives.

- `.planning/phases/23-nexus-generic-chart/23-08-SUMMARY.md` — exists; **updated in place** by the Task 3 closeout rather than replaced by a new file, as deviation 1's carry-forward note required
- PR **#14** — `gh pr view 14 --json state` = **`MERGED`**, `mergedAt` = `2026-09-19T11:41:43Z`, `mergedBy.login` = `OttawaCloudConsulting` (`is_bot: false`), `mergeCommit.oid` = `ea2770fbf1f8a4bd532d131835d90fb86c6f5d54`, `headRefOid` = `162bdf4b2fa684831aa973f6f4a33c520ca1c562`. (At the Tasks 1-2 checkpoint this read `OPEN` / `MERGEABLE` / `CLEAN` at head `e157a44`, then `162bdf4` after the post-review fixes.)
- Merge commit `ea2770f` — **two parents**, `cdf2c21` (base) and `162bdf4` (head), confirmed with `git show -s --format='%H %P'`. A merge commit, not a squash
- `origin/main` — resolves to `ea2770fbf1f8a4bd532d131835d90fb86c6f5d54`; carries all ten `kubernetes/nexus/` paths plus both `scripts/` gates; **0** paths under `kubernetes/nexus/charts/`; `README.md` contains **0** occurrences of `infrastructure/`
- `origin/feature/phase-23-nexus-generic-chart` — **deleted by the operator**; `git ls-remote --heads origin feature/phase-23-nexus-generic-chart` returns empty. (It existed at the checkpoint, with upstream verified via `git rev-parse --abbrev-ref --symbolic-full-name @{u}`.)
- `repos/security-platform` working tree — clean; local `main` fast-forwarded to `ea2770f`. No task in this plan committed anything to this repository; the five commits between `e157a44` and `162bdf4` are the post-review fixes recorded above
- `gh pr checks 14` — 12 checks, all `SUCCESS`, `CHECKS_EXIT=0`, recorded verbatim above
- `gh pr merge` — **never invoked**, in either run; verified by the absence of any such command in both command histories
- `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md` — **not touched** by the Task 3 closeout (accepted ADR, append-only per CLAUDE.md)
