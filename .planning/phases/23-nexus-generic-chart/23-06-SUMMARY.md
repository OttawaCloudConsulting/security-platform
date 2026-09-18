---
phase: 23-nexus-generic-chart
plan: 06
subsystem: infra
tags: [verification, helm, nexus, checkov, live-evidence, eula, idempotency, kind, pre-commit, ci-parity]

# Dependency graph
requires:
  - phase: 23-nexus-generic-chart
    plan: 01
    provides: "scripts/check-nexus-chart.sh — the 16 offline invariants, and the two named SKIP guards this plan proves are no longer firing"
  - phase: 23-nexus-generic-chart
    plan: 02
    provides: "scripts/nexus-live-smoke.sh — the docker two-pass + post-EULA download + kind install evidence chain"
  - phase: 23-nexus-generic-chart
    plan: 04
    provides: "the complete chart (provision.sh, the two ConfigMaps, the hook Job) that makes both gates non-vacuous, and the open question 'whether CI's Checkov scans this chart' that this plan closes"
  - phase: 23-nexus-generic-chart
    plan: 05
    provides: "kubernetes/nexus/README.md and the root README — both re-linted here by pre-commit over the whole tree"
provides:
  - "MEASURED CLOSURE of assumption A3: the pinned CI container ghcr.io/bridgecrewio/checkov:3.3.17 DOES ship helm (v3.22.0) and its helm runner DOES engage on kubernetes/nexus — but `helm template` fails on the chart's own `required` credential guard, so the chart contributes ZERO findings to CI. The failure is logged at WARNI, not ERROR, and does not raise Checkov's exit code."
  - "Measured Checkov delta for the phase: 14 failed checks BEFORE, 14 failed checks AFTER, identical check_id+file_path set. CKV_K8S_*/CKV2_K8S_* count is 0 in both. Re-measured WITHOUT --soft-fail (the CI setting): exit 1 before, exit 1 after — the chart does not change the gate's colour."
  - "The LATENT Checkov set, quantified: 24 kubernetes-framework findings if the chart were rendered (5 on Phase 23's own wrapper resources, 19 on the subchart's StatefulSet). None reach CI today."
  - "Second independent live-smoke green on the chart as committed (ALL PASS - 12 live check(s), 0 skipped), taken after 23-05's documentation commits rather than at 23-04's"
  - "Observed proof that `pre-commit run --all-files` does NOT run gitleaks in this repo — the hook is stages: [pre-push] and needs --hook-stage pre-push"
affects: [23-07, 23-08, phase-24-nexus-hardening, phase-25-argocd]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CI-equivalence reproduced by `git archive HEAD | tar -x` into a scratch dir rather than scanning $PWD, because the working tree carries a gitignored subchart tarball that CI's fresh clone does not"
    - "A scanner measurement mounted read-only can produce a FALSE zero: Checkov's helm runner needs to write charts/, and a :ro mount makes it fail for an infrastructure reason that masks the real one"
    - "Delta measured as a set diff on check_id+file_path from `-o json`, not as a grep over CLI text, because a regex scoped to CKV_K8S_* would have missed CKV2_K8S_*"

key-files:
  created: []
  modified: []

key-decisions:
  - "NO chart file was modified. The Checkov delta is exactly zero (14 -> 14, identical finding set), so the plan's branch (a) applies: record the counts, create no file, add no suppression. No `# checkov:skip=` comment was added anywhere and no `.checkov.yaml` exists in the repository."
  - "The plan's own Task 3 `<verify>` block mounts the tree `:ro`, which makes Checkov's helm runner fail with `Error: mkdir /src/kubernetes/nexus/charts: read-only file system` — an artefact of the measurement, not of CI, whose workspace is writable. The measurement was therefore re-run with a WRITABLE mount as the primary result. Both runs report the same 14 failures, so the conclusion is unchanged, but only the writable run shows the real reason the chart is not scanned."
  - "A3 is closed as MEASURED-ZERO-WITH-A-NAMED-CAUSE, not as 'no impact'. The helm runner engages; it is the chart's `required` guard on nexus3.rootPassword.secret that stops the render. Reporting only 'delta zero' would have been true and misleading."
  - "The `required` guard was NOT relaxed to make the chart scannable. It is T-23-02's locked mitigation and 23-01's NO-DEFAULT-PASSWORD check asserts it; trading a credential guarantee for scanner coverage is a Rule 4 architectural call, handed to Phase 24 rather than taken here."
  - "gitleaks evidence is recorded as a SEPARATE invocation. `pre-commit run --all-files` exits 0 without ever running it (stages: [pre-push]); `pre-commit run --all-files --hook-stage pre-push` is what executes it. Writing 'pre-commit passed, including gitleaks' from the first command alone would have been the exact class of unobserved claim T-23-12 names."
  - "provision.readiness.* was left untouched. The plan's frontmatter lists values.yaml as conditionally modified, but no task instructs wiring or deleting the dead knobs and no Checkov finding required a values.yaml edit. Editing it would have been undeclared surface and would have invalidated 23-05's README values table without a task to update it."
  - "requirements.mark-complete deliberately NOT invoked; requirements-completed: []. NEXUS-01/NEXUS-03 are in this plan's frontmatter and are now evidenced, but 23-08 is the plan that marks them — the 23-01..23-05 precedent."

patterns-established:
  - "Before trusting a container-based scanner measurement, check the tool the framework depends on is actually inside the image (`--entrypoint sh ... command -v helm`) — a two-second check that decided the whole task's interpretation"
  - "Quantify the LATENT finding set when the measured delta is zero for a structural reason, so 'zero' is not mistaken for 'clean'"

requirements-completed: []

# Metrics
duration: 40min
completed: 2026-09-18
---

# Phase 23 Plan 06: Live Verification and CI-Equivalent Checkov Delta Summary

**Every assertion waves 1-2 wrote down is now an observation: the offline gate reports `PASS - 16 checks, 0 failures` with no SKIP line, the live smoke reports `ALL PASS - 12 live check(s) executed and passed; 0 sub-check(s) skipped` including a 318,961-byte post-EULA lodash tarball and a completed hook Job on a real kind cluster, and the MEDIUM-confidence Checkov assumption is closed by measurement — 14 failed checks before, 14 after, identical set — with the reason named: the pinned CI container's helm runner engages and then cannot render the chart, because the chart's own no-default-credential guard stops it.**

## Performance

- **Duration:** ~20 min of active measurement inside a 2h20m wall clock. The gap is orchestration
  latency between steps, not compute. Read from artefact mtimes rather than estimated: first
  artefact `nexus-gate.txt` at 17:12Z, last (`cv-after-hard.json`) at 19:31Z, with two idle
  stretches of 81 and 53 minutes between them. The live smoke is ~7 min of that; seven Checkov
  container runs are most of the rest.
- **Started:** 2026-09-18T17:11:00Z
- **Completed:** 2026-09-18T19:31:00Z
- **Tasks:** 3 of 3
- **Files modified:** 0 in `repos/security-platform` — all three tasks are verification-only and the Checkov delta triggered no remediation

## Task Commits

**None in `repos/security-platform`.** All three tasks are declared `(no files modified — verification only)` by the plan, and Task 3's conditional remediation did not trigger because the measured delta is zero. `git status --porcelain` and `git diff HEAD --stat` are both empty; `HEAD` is still `e157a44` from 23-05.

Branch: `feature/phase-23-nexus-generic-chart` on `repos/security-platform`, **unpushed** (23-08 owns push/PR/merge).

The only commit this plan produces is the documentation commit carrying this SUMMARY, `STATE.md` and `ROADMAP.md` in the planning repository.

## Verification Evidence

### Task 1 — the offline gate is non-vacuous

```
$ bash scripts/check-nexus-chart.sh
check-nexus-chart: asserting 16 offline invariants against kubernetes/nexus
PASS - 16 checks, 0 failures
EXIT=0
```

That is the complete output — two lines. Mechanically:

| Assertion | Command | Observed |
|---|---|---|
| exit code | `bash scripts/check-nexus-chart.sh` | `0` |
| the literal pass line | `grep -c 'PASS - 16 checks, 0 failures'` | `1` |
| **no SKIP line** (the anti-vacuity guard) | `grep -c '^SKIP:'` | `0` |
| tarball untracked | `git ls-files kubernetes/nexus/charts` | prints nothing (`[]`) |
| tree clean | `git status --porcelain` | prints nothing (`[]`) |

Both of 23-01's named SKIP guards (`kubernetes/nexus` absent, `templates/job-provision.yaml` absent) are behind us: the chart directory and the Job template both exist, so neither guard fires and all 16 checks genuinely executed.

Re-run at the end of the plan after the Checkov work: identical output, exit 0.

### Task 1 — pre-commit, BOTH stages

```
$ pre-commit run --all-files                      # EXIT=0
Terraform fmt........................................(no files to check)Skipped
Terraform validate...................................(no files to check)Skipped
ruff (legacy alias)......................................................Passed
ruff format..............................................................Passed
shellcheck...............................................................Passed
Lint Dockerfiles.....................................(no files to check)Skipped
yamllint.................................................................Passed
markdownlint.............................................................Passed
eslint...............................................(no files to check)Skipped
npm audit............................................(no files to check)Skipped

$ pre-commit run --all-files --hook-stage pre-push   # EXIT=0
... (the ten above, identical) ...
Detect hardcoded secrets.................................................Passed
```

**gitleaks does not run in the default stage.** `.pre-commit-config.yaml` declares it `stages: [pre-push]`, so the first command exits 0 without ever invoking it. The plan's Task 1 acceptance criterion names gitleaks explicitly, so the second command was run to produce that evidence rather than inferring it. Both exit 0.

Per-file coverage, proven by targeted runs rather than assumed from the whole-tree pass:

| Hook | Files | Observed |
|---|---|---|
| `shellcheck` | `kubernetes/nexus/files/provision.sh` | `Passed`, exit 0 |
| `yamllint` | `kubernetes/nexus/Chart.yaml`, `kubernetes/nexus/values.yaml` | `Passed`, exit 0 |
| `yamllint` | `kubernetes/nexus/templates/job-provision.yaml` | `(no files to check)Skipped` — 23-01's `exclude: ^kubernetes/.*/templates/` is doing its job |
| `markdownlint` | `kubernetes/nexus/README.md`, `README.md` | `Passed`, exit 0 |
| `gitleaks` | whole tree, pre-push stage | `Detect hardcoded secrets ... Passed` |

### Task 2 — the live smoke, verbatim

```
--- 1. Boot Nexus ---
    image (from the chart): docker.io/sonatype/nexus3:3.96.0-ubi
    container: nexus-live-smoke-46015 -> http://127.0.0.1:53170
==> NEXUS-BOOT: PASS - container is running (provision.sh owns the readiness poll)

--- 2. Extract repo bodies from the chart ---
==> REPO-BODY-COUNT: PASS - 4 repo body files written to $OUT/config
==> REPO-BODY-JSON: PASS - every extracted repo body parses as JSON

--- 3. provision.sh pass 1 ---
curl: (52) Empty reply from server
Waiting for Nexus (attempt 1/60, HTTP 000)...
curl: (52) Empty reply from server
Waiting for Nexus (attempt 2/60, HTTP 000)...
Nexus is writable (HTTP 200).
EULA: eula.accepted is true — accepting the Sonatype Nexus Repository Community Edition licence agreement.
EULA: accepted (HTTP 204). The call is idempotent — a re-run returns 204 again.
Provisioning 4 proxy repositor(ies) ...
repo: format=npm name=npm-proxy action=created (HTTP 201)
repo: format=pypi name=pypi-proxy action=created (HTTP 201)
repo: format=docker name=docker-proxy action=created (HTTP 201)
repo: format=helm name=helm-proxy action=created (HTTP 201)
Provisioning complete: 4 proxy repositor(ies) present and online.
==> PROVISION-PASS-1: exit=0 (PASS - completed successfully)

--- 4. provision.sh pass 2 (idempotency) ---
Nexus is writable (HTTP 200).
EULA: accepted (HTTP 204). The call is idempotent — a re-run returns 204 again.
repo: format=npm name=npm-proxy action=updated (HTTP 204)
repo: format=pypi name=pypi-proxy action=updated (HTTP 204)
repo: format=docker name=docker-proxy action=updated (HTTP 204)
repo: format=helm name=helm-proxy action=updated (HTTP 204)
Provisioning complete: 4 proxy repositor(ies) present and online.
==> PROVISION-PASS-2: exit=0 (PASS - completed successfully)

--- 5. Post-EULA artifact download ---
==> ARTIFACT-TRANSPORT: PASS - curl completed against http://127.0.0.1:53170/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz
==> ARTIFACT-HTTP-200: PASS - tarball request returned HTTP 200
==> ARTIFACT-SIZE: PASS - 318961 bytes downloaded (> 100000)

--- 6. kind install smoke ---
    creating cluster nexus-smoke (this is the slow part)
==> KIND-CLUSTER: PASS - cluster nexus-smoke is up
Saving 1 charts
Downloading nexus3 from repo https://stevehipwell.github.io/helm-charts/
==> KIND-DEPENDENCY-BUILD: exit=0 (PASS - completed successfully)
NAME: t
LAST DEPLOYED: Fri Sep 18 13:14:15 2026
NAMESPACE: nexus-smoke
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
==> KIND-INSTALL: exit=0 (PASS - completed successfully)
    1 Job(s) still present after install: the delete-policy left the evidence in place
job.batch/t-nexus-provision condition met
==> KIND-JOB-COMPLETE: exit=0 (PASS - completed successfully)

=== Summary ===
ALL PASS - 12 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).
EXIT=0
```

**The four results the plan names, with their observed values:**

| Result | Observed |
|---|---|
| `PROVISION-PASS-1` | `exit=0 (PASS)` — all four formats `action=created (HTTP 201)` |
| `PROVISION-PASS-2` | `exit=0 (PASS)` — all four formats `action=updated (HTTP 204)`; the GET->PUT branch is real, not a repeat blind POST |
| lodash tarball | **HTTP 200, 318,961 bytes** (threshold 100,000; the pre-EULA refusal body is ~192 bytes) |
| `KIND-INSTALL` / `KIND-JOB-COMPLETE` | `exit=0 (PASS)` / `exit=0 (PASS)` — `job.batch/t-nexus-provision condition met` |

Anti-vacuity assertions on the smoke output:

- `grep -c '^ALL PASS'` → `1`
- `grep -ic 'skip.*provision\.sh'` → **`0`** — 23-02's vacuous-skip guard is not firing
- `grep -ic 'skip'` → `1`, and that single match is the summary's own `0 sub-check(s) skipped` clause. **No sub-check was skipped; no optional tool was absent.** `docker`, `kind` and `kubectl` were all on PATH and all exercised.

**Environment left clean** (T-23-01):

| Check | Before | After |
|---|---|---|
| `docker ps -a` count | 2 (both unrelated, `Exited 7 months ago`) | 2, the same two |
| containers matching `nexus-live-smoke` | 0 | **0** |
| `kind get clusters` | `No kind clusters found.` | **`No kind clusters found.`** |
| `kubectl config current-context` | `admin@occ-new` | **`admin@occ-new`** (the trap restored it) |
| `git status --porcelain` | empty | empty |

This is the **second** independent live green on this chart. 23-04's was taken at commit `39753db`; this one is taken at `e157a44`, after 23-05's three documentation commits, and confirms they changed no behaviour.

### Task 3 — the Checkov delta, measured

**Container identity**

```
$ docker inspect --format '{{index .RepoDigests 0}}' ghcr.io/bridgecrewio/checkov:3.3.17
ghcr.io/bridgecrewio/checkov@sha256:41c4701c6a56d8952e5aba7a420f871c8b70b57da94eb4f142dcdf7295bb0be3
```

Matches `.github/workflows/security.yml` line 244's comment (`bridgecrewio/checkov-action` internally pulls `ghcr.io/bridgecrewio/checkov:3.3.17`); the job runs `directory: .`, `quiet: true`, `soft_fail: false`, and declares no `framework:` filter.

**Does the helm runner even have helm? Yes — this is what closes A3.**

```
$ docker run --rm --entrypoint sh ghcr.io/bridgecrewio/checkov:3.3.17 \
    -c 'command -v helm && helm version --short; command -v kustomize; checkov --version'
/usr/local/bin/helm
v3.22.0+g144ca65
/usr/bin/kustomize
3.3.17
```

Research could not resolve this locally because Checkov 3.2.396's helm runner would not load against the workstation's Helm v4.3.0. **The pinned CI container ships its own Helm v3.22.0.** The runner engages.

**CI-state reproduction.** Method: `git archive HEAD | tar -x -C "$(mktemp -d)"`. Asserted before scanning:

```
kubernetes/nexus present in archive:        YES
find "$T/kubernetes/nexus" -name '*.tgz':   []          (no subchart tarball — this IS the CI state)
charts/ directory in archive:               NO          (git tracks no empty dirs; .gitignore:28 is kubernetes/*/charts/*.tgz)
root .checkov config in archive:            []
```

**The measurement — three trees, one command shape**

```
docker run --rm -v "$T":/src -w /src ghcr.io/bridgecrewio/checkov:3.3.17 \
  --directory . --soft-fail --quiet -o json
```

| Tree | How produced | passed | **failed** | `CKV_K8S_*`/`CKV2_K8S_*` failed |
|---|---|---|---|---|
| **BEFORE (a)** — the PR base | `git archive $(git merge-base main HEAD)` = `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` (no `kubernetes/` at all) | 333 | **14** | **0** |
| **BEFORE (b)** — HEAD minus the chart | `git archive HEAD`, then `rm -rf "$T/kubernetes"` | 333 | **14** | **0** |
| **AFTER** — the branch | `git archive HEAD` | 333 | **14** | **0** |

Per-framework, identical across all three trees:

```
terraform:        passed=8   failed=12
dockerfile:       passed=2   failed=2
gitlab_ci:        passed=22  failed=0
github_actions:   passed=296 failed=0
azure_pipelines:  passed=5   failed=0
```

There is **no `helm` and no `kubernetes` section in the report at all.**

**Set diff, not just counts** — `check_id` + `file_path` for every failed check, BEFORE (b) vs AFTER:

```
$ diff <(jq ... checkov-before-nok8s.json) <(jq ... checkov-after-rw.json)
NO DIFFERENCE
```

The 14 pre-existing failures, unchanged by this phase:

```
CKV2_AWS_5 x1   CKV2_AWS_6 x1   CKV2_AWS_61 x1  CKV2_AWS_62 x1
CKV_AWS_144 x1  CKV_AWS_145 x1  CKV_AWS_18 x1   CKV_AWS_21 x1
CKV_AWS_23 x1   CKV_AWS_24 x1   CKV_DOCKER_2 x1 CKV_DOCKER_3 x1
CKV_TF_1 x1     CKV_TF_2 x1
```

All on `fixtures/` — Phase 15/16's deliberately-misconfigured Terraform and Dockerfile. `soft_fail: false` is reconciled with them by the workflow's `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}`; that arrangement predates this phase and is untouched by it.

**DELTA = 0.** No chart file was changed, no suppression comment was added, and no `.checkov.yaml` was created. `find kubernetes -name '.checkov.y*ml'` → nothing; `find . -name '.checkov.y*ml' -not -path './.git/*'` → nothing anywhere in the repository.

**Why the delta is zero — the part that matters more than the number**

The helm runner engages, runs `helm dependency update` successfully (it fetched `nexus3-5.26.0.tgz` into the scratch tree over the network, exactly as CI would), and then fails at `helm template`:

```
[WARNI]  Failed processing helm chart nexus at dir: ./kubernetes/nexus.
         Working dir: /tmp/tmpj8_jzd0d. Failure details:
         Error: execution error at (nexus/templates/job-provision.yaml:114:27):
         A Nexus admin password Secret is required. Create a Secret holding the
         admin password and name it in nexus3.rootPassword.secret (the key
         defaults to 'password'); this chart deliberately ships no default credential.
```

That is the chart's own `required` guard — T-23-02's mitigation, asserted by 23-01's `NO-DEFAULT-PASSWORD` check — doing precisely what it was built to do, on a caller that supplies no values. Checkov logs it at **WARNI**, not at ERROR, and continues. So:

- the chart contributes **zero** findings to CI, and
- **CI's Checkov provides zero coverage of this chart.** Those are the same fact stated two ways, and only the first is good news.

This is recorded as the honest closure of A3: **not** "the chart is clean", but "the chart is not scanned, for a named and deliberate reason". The plan's `<verify>` block (`:ro` mount) reaches the same zero via a *different* failure — `Error: mkdir /src/kubernetes/nexus/charts: read-only file system` — which is an artefact of the read-only mount and not something CI would ever hit. Both were run; the writable one is the primary result.

**The exit code CI actually gets, measured rather than inferred.** Every run above used
`--soft-fail` so that a report came back instead of a verdict. CI sets `soft_fail: false`, which
is Checkov's default — i.e. no flag. Both trees were therefore re-scanned with the flag removed:

```
$ docker run --rm -v "$T":/src -w /src ghcr.io/bridgecrewio/checkov:3.3.17 --directory . --quiet -o json
BEFORE(b)  (HEAD minus kubernetes/)  EXIT=1   failed=14
AFTER      (HEAD)                    EXIT=1   failed=14
```

Identical. The helm-runner failure is logged at WARNI and does **not** raise Checkov's exit code:
`grep -iE '\[ERROR' ` over the AFTER stderr prints nothing, and the only chart-related line is the
single `Failed processing helm chart nexus` WARNI. Both trees exit 1 because of the 14 pre-existing
`fixtures/` failures, which is the state the workflow's
`continue-on-error: ${{ env.GATE_MODE == 'report-only' }}` already governs and which this phase
does not touch. **Adding this chart does not change the CI gate's colour** — must-have truth #5,
observed as an exit-code pair rather than reasoned about.

**The latent set, quantified.** So that "zero" is not mistaken for "clean", the chart was rendered with the required value supplied and the rendered manifest scanned with the same pinned container:

```
$ helm template nexus kubernetes/nexus --set nexus3.rootPassword.secret=dummy --set eula.accepted=true > rendered/nexus.yaml   # exit 0, 973 lines
$ checkov --directory rendered --framework kubernetes --soft-fail --quiet -o json
kubernetes: passed=161 failed=24
```

| Owner | Findings |
|---|---|
| **Phase 23's wrapper (5)** | `CKV2_K8S_6` (Pod `nexus-provision`, no NetworkPolicy); `CKV_K8S_35` (Job `nexus-provision`, secret as env — inherent to 23-02's binding `NEXUS_PASSWORD` env contract); `CKV_K8S_21` x3 (ConfigMaps `nexus-provision-script`, `nexus-repos`, Job `nexus-provision` — "default namespace", an artefact of rendering without `--namespace`, not a property of an install) |
| **Subchart (19)** | `CKV_K8S_10/11/12/13/15/28/37/38/40/43`, `CKV2_K8S_6`, `CKV_K8S_21` x7, `CKV_K8S_35` — all on `StatefulSet.nexus-nexus3` and its Services/ServiceAccount/ConfigMaps |

`CKV_K8S_38` no longer fires on the provisioning Job — 23-04's `automountServiceAccountToken: false` holds. None of these 24 reach CI today.

### Plan-level verification block

```
bash scripts/check-nexus-chart.sh        -> PASS - 16 checks, 0 failures   (exit 0, no SKIP: line)
bash scripts/nexus-live-smoke.sh         -> ALL PASS - 12 live check(s)    (exit 0, 0 skipped)
pre-commit run --all-files               -> exit 0
pre-commit run --all-files --hook-stage pre-push  -> exit 0 (this is the one that runs gitleaks)
Checkov BEFORE / AFTER failed checks     -> 14 / 14, identical set, CKV_K8S_* = 0 / 0
Checkov BEFORE / AFTER exit code, no --soft-fail (the CI setting) -> 1 / 1, unchanged
```

The plan's literal Task 3 `<verify>` one-liner was also executed as written and reported `VERIFY_BLOCK_RESULT=PASS (RC=0)`.

## Deviations from Plan

### Auto-fixed Issues

None. No bug, no missing critical functionality and no blocking issue was found. Every gate was green on first contact and the Checkov delta triggered no remediation.

### Divergences from the plan text (deliberate, with reasons)

**1. The Checkov measurement was re-run with a WRITABLE mount, because the plan's `:ro` mount produces a false negative for the wrong reason.** The plan's `<verify>` mounts `-v "$T":/src:ro`. Checkov's helm runner needs to create `kubernetes/nexus/charts/` to resolve the dependency, and on a read-only mount it fails with `Error: mkdir /src/kubernetes/nexus/charts: read-only file system`. GitHub Actions checks out into a writable workspace, so that failure is an artefact of the measurement. Both mounts were run; both report 14 failures and no helm/kubernetes section, so the *number* is unaffected — but only the writable run reveals that the real blocker is the chart's `required` guard. Reporting the `:ro` result alone would have closed A3 on a measurement that did not reproduce CI.

**2. `pre-commit` was run twice, at two hook stages.** The plan's criterion is `pre-commit run --all-files` exits 0 "including `gitleaks`". Those two clauses cannot both be satisfied by one command in this repository: gitleaks is `stages: [pre-push]` and the default-stage run never invokes it. Resolved by running both and recording both, rather than by writing a gitleaks claim the first command does not support.

**3. `values.yaml` was not modified, despite being listed in the plan's `files_modified`.** It is listed conditionally ("conditional" on a Checkov finding), the delta is zero, and no task instructs anything about the dead `provision.readiness.*` knobs 23-04 handed forward and 23-05 documented as inert. Editing them here would be undeclared surface and would silently invalidate two sections of `kubernetes/nexus/README.md` with no task to update them. Handed forward to 23-07 instead (observation 2).

**4. The `required` guard was not relaxed to obtain Checkov coverage.** Making the chart scannable by CI would require either removing the guard (contradicting T-23-02, a locked decision, and failing 23-01's `NO-DEFAULT-PASSWORD` check) or introducing a Checkov values file (unspecified surface). Both are Rule 4 architectural changes. Flagged for Phase 24, not taken here.

**5. No task produced a commit in `repos/security-platform`.** All three tasks are verification-only by the plan's own `<files>` declarations, and the conditional remediation branch did not trigger. The per-task-commit rule has nothing to commit; `git diff HEAD --stat` is empty and `HEAD` remains `e157a44`.

## Observations Handed Forward

1. **CI's Checkov does not scan `kubernetes/nexus`, and will not until someone gives its helm runner a way to render the chart.** This is the single most consequential finding of the plan. The chart's K8s security posture is currently evidenced only by local measurement (the 24-finding latent set above), never by the pipeline. Phase 24 should decide explicitly between (a) accepting it, documented; (b) a `kubernetes/nexus/ci-values.yaml` naming a dummy Secret, fed to Checkov via `--var-file` or an equivalent, which reintroduces the question of whether a scanner-only values file drifts from the real one; or (c) committing a rendered manifest for scanning, which drifts by construction. **Do not "fix" it by weakening the `required` guard.**
2. **`provision.readiness.attempts` / `.intervalSeconds` are still dead knobs.** 23-04 raised them, 23-05 documented them as present-but-not-read, and 23-06 — whose `files_modified` listed `values.yaml` — had no task that touches them. They are now the phase's one piece of unresolved surface. 23-07 or Phase 24 must either wire them through (which means extending 23-02's four-variable env contract and `nexus-live-smoke.sh` with it) or delete them and update the README values table and Limitations bullet together.
3. **A container-based scanner measurement mounted `:ro` can silently mis-measure.** Checkov's helm runner writes into the chart directory. Any future plan that reuses the `-v "$T":/src:ro` pattern for a helm-bearing tree will get a plausible zero for an infrastructure reason. Prefer a writable throwaway mount and read the stderr WARNIs.
4. **`pre-commit run --all-files` is not the whole gate in `security-platform`.** gitleaks is pre-push-staged. Any plan whose acceptance criteria name gitleaks must add `--hook-stage pre-push`; 23-08, which pushes the branch, will trigger it for real on `git push`.
5. **`CKV_K8S_21` ("default namespace") in the latent set is a rendering artefact.** `helm template` without `--namespace` puts everything in `default`. A real install into `nexus` would not produce those 10 findings. Do not count them as chart defects if Phase 24 revisits this.
6. **The 14 pre-existing Checkov failures all come from `fixtures/`** and are Phase 15/16's deliberate bad-IaC corpus. Any future "get Checkov to zero" ambition must reckon with the fact that those fixtures exist precisely to make the scanners report something.
7. **The live smoke is reproducible and cheap enough to re-run.** Two independent full-green runs now exist (23-04 at `39753db`, 23-06 at `e157a44`), both ~7-10 minutes, both leaving no container, no kind cluster and no kubeconfig damage. 23-08 can afford one more against the final merge commit if it wants.
8. **`helm dependency update` inside the Checkov container reached `https://stevehipwell.github.io/helm-charts/` successfully.** Whatever Phase 24 decides about scanning the chart, network egress from the scanner is not the obstacle.

## Threat Model Coverage

| Threat ID | Disposition | How this plan mitigates it | Status |
|---|---|---|---|
| T-23-08 | mitigate | The gate's pass condition was evaluated as the literal line plus `grep -c '^SKIP:' == 0`, not as exit 0. Observed: pass line count `1`, SKIP line count `0` | ✅ observed |
| T-23-12 | mitigate | Every acceptance criterion is recorded with its observed value — the gate's two-line output verbatim, the smoke's labelled results verbatim, the byte count `318961`, the Checkov counts `14`/`14` with the commands and the container digest. The one claim that could not be supported by the stated command (gitleaks under `pre-commit run --all-files`) was re-measured rather than written | ✅ observed |
| T-23-05 | mitigate | The post-EULA download is asserted on HTTP status **and** size: `HTTP 200` + `318961 bytes`. The ~192-byte pre-EULA refusal body would fail the size assertion while passing a naive transport check | ✅ observed |
| T-23-SC | mitigate | No package-manager install occurred. The only image pulled for the measurement is the CI-pinned `ghcr.io/bridgecrewio/checkov:3.3.17`, recorded by digest `sha256:41c4701c…`, never `latest` | ✅ observed |
| T-23-01 | mitigate | Before/after comparison of `docker ps -a` (2 unrelated containers both times, 0 matching `nexus-live-smoke`), `kind get clusters` (`No kind clusters found.` both times) and `kubectl config current-context` (`admin@occ-new` both times) | ✅ observed |
| T-23-02 | mitigate | Re-evidenced incidentally and strongly: the `required` guard fired inside a third-party scanner's render, naming `nexus3.rootPassword.secret`, with no default credential available to it | ✅ observed |

## Known Stubs

None. No file was created or modified by this plan. The one piece of unimplemented surface in the phase — `provision.readiness.*` — is a dead knob inherited from 23-04, documented as inert by 23-05, and handed forward here as observation 2 rather than hidden.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: scanner-blind-spot | `repos/security-platform/kubernetes/nexus/` (whole chart) | Measured, not inferred: the CI Checkov job's helm runner engages on this chart and then cannot render it, so **no** Kubernetes policy check in the pipeline evaluates any resource this chart ships. A rendered install carries 24 kubernetes-framework findings (5 on this phase's own wrapper resources, 19 on the subchart), none of which CI can see. This is not a new attack surface introduced by a file — it is the *absence* of a control the repository's security gate is otherwise assumed to provide, and it should be an explicit accept-or-fix decision in Phase 24 rather than an unstated gap. |

## Self-Check: PASSED

- `.planning/phases/23-nexus-generic-chart/23-06-SUMMARY.md` — created by this plan
- `repos/security-platform` working tree — `git status --porcelain` empty, `git diff HEAD --stat` empty, `HEAD` = `e157a44` (unchanged by this plan, as designed)
- No commits expected or made in `repos/security-platform` — all three tasks are verification-only and the conditional remediation branch did not trigger
- `bash scripts/check-nexus-chart.sh` — run twice, exit 0, `PASS - 16 checks, 0 failures`, `grep -c '^SKIP:'` = `0`
- `bash scripts/nexus-live-smoke.sh` — run once for real, exit 0, `ALL PASS - 12 live check(s) executed and passed; 0 sub-check(s) skipped`
- `pre-commit run --all-files` — exit 0; `pre-commit run --all-files --hook-stage pre-push` — exit 0
- Checkov `ghcr.io/bridgecrewio/checkov@sha256:41c4701c6a56d8952e5aba7a420f871c8b70b57da94eb4f142dcdf7295bb0be3` — three trees scanned, 14 / 14 / 14 failed checks, identical `check_id`+`file_path` set, `CKV_K8S_*` = 0
- Checkov without `--soft-fail` (the CI setting) — BEFORE exit `1`, AFTER exit `1`, `failed=14` both; no ERROR-level line in stderr
- `find . -name '.checkov.y*ml' -not -path './.git/*'` — prints nothing
