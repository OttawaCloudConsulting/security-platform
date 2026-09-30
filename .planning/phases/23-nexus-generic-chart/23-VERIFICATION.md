---
phase: 23-nexus-generic-chart
verified: 2026-09-29T00:00:00Z
status: passed
score: 30/30 must-haves verified
overrides_applied: 0
---

# Phase 23: Nexus Generic Chart Verification Report

**Phase Goal:** Public Helm chart wraps the community `stevehipwell/nexus3` subchart (runs the official Sonatype Nexus image; no Sonatype-published chart named `nexus3` exists) and deploys Nexus Repository with npm, PyPI, and Docker proxy repos configured by default (Helm proxy is consumer-configured, no universal default exists post-Helm-Hub), using the cluster's default StorageClass unless overridden.
**Requirements:** NEXUS-01, NEXUS-03
**Verified:** 2026-09-29 (against `OttawaCloudConsulting/security-platform` merge of PR #14 @ `ea2770fbf1f8a4bd532d131835d90fb86c6f5d54` and `origin/main` @ `fdabac9464f2baaeaa276f8934dc8d353295b355`; overlay `occ-k8s-app-config` `origin/main` @ `bb1332b`; live state read 2026-09-29)
**Status:** passed
**Re-verification:** No — initial verification (retroactive, authored in Phase 29.1)

## Method

ROADMAP.md's `success_criteria` array for Phase 23 is empty (the goal text is the only roadmap-level contract), so must-haves were derived by Option A: merging the `must_haves.truths` frontmatter of all eight plans (23-01 through 23-08) with `yq --front-matter=extract '.must_haves.truths[]' 23-0N-PLAN.md`. The `gsd-sdk query frontmatter.get <plan> --field must_haves` form shown in the verify workflow errors (`"Field not found","field":"--field"`); the positional form works but nests the result under `.must_haves.truths`, so a naive `.truths` read yields zero. The eight plans declare 4+4+5+5+3+5+5+4 = **35 raw truths**; overlapping truths were merged into **30 rows** below, each annotated with its source plan and truth index (e.g. `23-02.3`) so the 35-to-30 reduction is reconstructible. SUMMARY.md claims were treated as unverified narrative only. Every truth was independently re-checked against: (a) `origin/main` of `repos/security-platform` (local clone proven identical, see below); (b) a `git archive` of the Phase 23 merge commit `ea2770f` extracted into a scratch directory; (c) the live homelab cluster (`kubectl --context admin@occ-new`, read-only `get`); (d) the overlay repo `occ-k8s-app-config` read only through `git show origin/main:<path>`, never its working tree; and (e) fresh read-only HTTP probes over a task-scoped `kubectl port-forward` that was started and killed within a single command.

This report is retroactive: Phase 23 closed on 2026-09-19 with 8/8 plans complete and no `VERIFICATION.md`, and this document is authored ~10 days later, by Phase 29.1, after Phases 24 (anonymous access), 25 (live homelab deployment), 26-29 all ran on top of the same chart, and after the live Nexus StatefulSet had been running for 6 days (`creationTimestamp: 2026-09-24T01:03:09Z`). That gap in time is corroborating evidence, not a liability: the NEXUS-01/NEXUS-03 surfaces were carried through all of it unchanged (surface identity below).

**Pinned evidence snapshot** (pinned once in plan 29.1-01 Task 1 and cited identically throughout): PR `#14`, state `MERGED`, head `162bdf4b2fa684831aa973f6f4a33c520ca1c562`, merge `ea2770fbf1f8a4bd532d131835d90fb86c6f5d54` ("what Phase 23 shipped"), merged `2026-09-19T11:41:43Z` by `OttawaCloudConsulting` (`is_bot: false`; `gh api repos/$R/pulls/14` `merged_by.type: User`); today's `origin/main` `fdabac9464f2baaeaa276f8934dc8d353295b355` (tags `v1`, `v1.2.0`), equal across `gh api repos/$R/commits/main -q .sha`, local `git rev-parse HEAD`, and local `git rev-parse origin/main`, with `git status --porcelain` empty; repo `visibility: public`, `default_branch: main`; overlay `origin/main` `bb1332b` (`bb1332bdb395ee2d1d4b15b313174df4ce942e2e`). Claims about *what Phase 23 shipped* hang off `ea2770f` (the gate run against its archive); claims about *the chart as it stands* (renders, artifacts, gate at 18 checks) hang off `fdabac9`; the two are cited separately and never conflated. `git merge-base --is-ancestor ea2770f origin/main` exited 0.

**Surface identity.** `git diff --quiet ea2770f fdabac9 -- kubernetes/nexus/templates/configmap-repos.yaml kubernetes/nexus/Chart.yaml kubernetes/nexus/Chart.lock` exited 0 (identical), and `diff` of the two SHAs' `values.yaml` passed through `yq -o json '{"p":.nexus3.persistence,"r":.repos}'` printed nothing and exited 0. The whole-chart `git diff --stat ea2770f fdabac9 -- kubernetes/nexus` touches only `README.md` (70 lines), `files/provision.sh` (148), `templates/job-provision.yaml` (21) and `values.yaml` (77) — Phase 24's anonymous-access wiring and Phase 25's README additions. None touches the PVC template path or the repo-body definitions. `provision.sh` consumes those bodies and its creation path was not diffed line by line, so the NEXUS-01 *outcome* is proven at both ends instead: the gate passes at both SHAs and the live listing shows all four proxies created by the current script.

**Read-only scope for this session:** `gh api` (GET), `gh pr view`, `gh pr checks`, `git fetch/rev-parse/status/diff/show/archive/ls-tree/merge-base`, `helm template/dependency list`, `helm pull -d <scratch>`, `yq`, `jq`, `shasum`, `tar -x` into scratch, `kubectl --context admin@occ-new get`, one task-scoped `kubectl port-forward`, `curl` GET to `127.0.0.1`, and `bash scripts/check-nexus-chart.sh`. No `helm install/upgrade/uninstall`, no `kubectl apply/patch/delete/edit`, no ArgoCD sync, no push, no PR, no edit inside either clone, and no `kubectl get secret` in namespace `nexus`. The admin credential was never read. Both mutation-style runs (N3-e and the preflight probe) ran on `git archive` extracts in the session scratchpad; `git -C repos/security-platform status --porcelain` was empty before and after. The clone identity above was re-proven this session, not inherited from research.

**NEXUS-03 Evidence Tier.** The chart's contract for NEXUS-03 ends at the rendered `volumeClaimTemplate`: the chart must *omit* `storageClassName` by default and must pass a consumer's value through verbatim when set. Whether Kubernetes then binds a PVC to a named class is Kubernetes' own tested behaviour, not the chart's. The **default path** is therefore proven at render tier (N3-a, gate check STORAGECLASS-OMITTED) *and* live (N3-g: the deployed StatefulSet's template has no `storageClassName`; N3-h: the PVC received `default` from the DefaultStorageClass admission plugin, because the class named `default` is the cluster default and the overlay sets no class). The **override path** is proven at render tier, which is the correct tier for it: the verifier's own probes via `--set` (N3-b, `longhorn`) and via an overlay-shaped `-f` values file (N3-c, `fast-ssd`), the gate's STORAGECLASS-OVERRIDE check, the subchart source lines that implement it (N3-f), and a scratch-only mutation (N3-e) that proves the gate discriminates. No `kind` live-override witness was run and no homelab override was attempted (that would be a mutation); neither would prove anything the rendered template does not already prove.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A commit touching a Helm Go template under `kubernetes/*/templates/` passes pre-commit instead of failing yamllint (23-01.1) | VERIFIED | `fdabac9`: `grep -nE 'exclude\|yamllint' .pre-commit-config.yaml` → L60 `id: yamllint`, L63 `exclude: ^kubernetes/.*/templates/`. The hook cannot see Go-templated YAML. Reconciles with 23-01-SUMMARY |
| 2 | `helm dependency build` output (`charts/*.tgz`) is never committed to git (23-01.2) | VERIFIED | `fdabac9`: `.gitignore:28` `kubernetes/*/charts/*.tgz`; `git ls-files '*.tgz'` → empty; `git ls-tree -r --name-only origin/main kubernetes/nexus \| grep -c charts/` → `0`. Corroborated by the preflight probe (a fresh archive has no tgz and exits 2) |
| 3 | One command decides PASS/FAIL for every offline chart invariant, and it reports a real pass, not a skip (23-01.3 + 23-06.1) | VERIFIED | `fdabac9`: `bash scripts/check-nexus-chart.sh` → `check-nexus-chart: asserting 18 offline invariants` / `PASS - 18 checks, 0 failures`, exit 0, no SKIP line. 18 distinct `fail "<LABEL>"` sites in the script (CHART-LINT … ANONYMOUS-DEFAULT) |
| 4 | That command passes at every intermediate commit of the phase, and never reports a missing tool as a chart defect (23-01.4) | VERIFIED | Header L22-24 documents exit 0/1/2 (2 = preflight, not a defect); L33-39 documents the VACUOUS-PASS convention (`kubernetes/nexus absent -> SKIP, exit 0`). Observed: `git archive fdabac9` without the tgz → `PREFLIGHT FAIL: subchart not vendored`, **exit 2** (not 1). Endpoints re-run: `ea2770f` archive 17/17 exit 0, `fdabac9` 18/18 exit 0. The individual intermediate commits of 23-01..23-07 were not replayed; that part rests on the documented convention plus both endpoints |
| 5 | One command boots a real Nexus, provisions it twice (both succeed), and proves a real package tarball downloads after EULA acceptance (23-02.1 + 23-06.2 + 23-06.3) | VERIFIED (from evidence, not re-run) | `scripts/nexus-live-smoke.sh` present at `fdabac9`; not re-run (Docker + kind, ~8 min; see Probe Execution). Durable later witnesses: `25-VERIFICATION.md` truth 7 (fresh live probe, lodash `200 318961` bytes — the same byte count 23-06-SUMMARY:183 records as `ARTIFACT-SIZE: PASS - 318961 bytes`) and truth 12 (second sync `4× action=updated, 0× action=created` on the real cluster). 23-06-SUMMARY:170 records the two-pass run |
| 6 | A skipped sub-check is reported as SKIPPED and never counted as a pass (23-02.2) | VERIFIED | `fdabac9`: `grep -n SKIPPED scripts/nexus-live-smoke.sh` → L84 `SKIPPED=()`, L195-196 `SKIPPED - ${#SKIPPED[@]} sub-check(s) did not run. A SKIP IS NOT A PASS:` |
| 7 | No admin password literal exists in the repository; a consumer who has not supplied an admin Secret gets a failed render, not a default credential (23-02.3 + 23-03.4a + 23-04.5) | VERIFIED | `helm template t kubernetes/nexus` (no `--set`) → exit 1, error names `nexus3.rootPassword.secret ... this chart deliberately ships no default credential`. `git grep -nIiE 'password *[:=] *["']?[A-Za-z0-9]{6,}' -- kubernetes/nexus scripts` → no match, exit 1. Gate check NO-DEFAULT-PASSWORD passes within 18/18 |
| 8 | The smoke test reads the repo bodies and the Nexus image out of the chart, so it cannot drift from what the chart ships (23-02.4) | VERIFIED | `fdabac9` `scripts/nexus-live-smoke.sh`: L54 `PROVISION_SH="kubernetes/nexus/files/provision.sh"`, L135 `helm template t kubernetes/nexus`, L257 `NEXUS_IMAGE="$(unquote "$(render \| yq 'select(.kind=="StatefulSet") \| .spec.template.spec.containers[0].image')")"` |
| 9 | The chart resolves and lints against a pinned upstream subchart without a fork or a vendored copy (23-03.1) | VERIFIED | `Chart.yaml:6-9` `dependencies: nexus3 5.26.0 https://stevehipwell.github.io/helm-charts/`; `helm dependency list kubernetes/nexus` → `nexus3 5.26.0 ... ok` (P-a); local tgz sha256 = fresh `helm pull` sha256 = `e47791e668e29e6f2242a81630259ae59e852219776ee55c4df0f3d17a918e4f` (P-b); tgz is gitignored (row 2), so nothing is vendored into git. CHART-LINT passes within 18/18 |
| 10 | Installing with no storageClass override lands the PVC on the cluster's default StorageClass (23-03.2) — NEXUS-03 default path | VERIFIED | Render: N3-a `{"has":false,"sc":null}` (key absent, not empty). Live: N3-g `kubectl -n nexus get sts nexus-nexus3 -o json \| jq '.spec.volumeClaimTemplates[0].spec'` → `{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"8Gi"}},"volumeMode":"Filesystem"}`, `has_sc:false`; N3-h PVC `data-nexus-nexus3-0` `{"sc":"default","phase":"Bound","cap":"8Gi"}`, and `kubectl get storageclass` lists `default (default)` `csi.trident.qnap.io` among 5 classes. Overlay `bb1332b` has no `storageClass`/`persistence` key (grep exit 1). Matches 25-VERIFICATION truth 6 and adds the mechanism |
| 11 | Nexus state survives a pod restart by default (23-03.3) | VERIFIED | `yq '.nexus3.persistence' values.yaml` → `enabled: true`, `size: 8Gi` (comment: the upstream default `false` is an `emptyDir`). Default render: StatefulSet has `1` volumeClaimTemplate named `data`. Gate PERSISTENCE-ENABLED passes. Live PVC `Bound` 8Gi (row 10) |
| 12 | A consumer can override any value the upstream subchart exposes (23-03.5) — NEXUS-03 override path | VERIFIED | `--set nexus3.persistence.storageClass=longhorn` → `{"has":true,"sc":"longhorn"}` (N3-b); `-f` file `nexus3: {persistence: {storageClass: fast-ssd}}` → `{"has":true,"sc":"fast-ssd"}` (N3-c); `--set nexus3.persistence.size=20Gi` → rendered request `20Gi`. Gates STORAGECLASS-OVERRIDE and PASSTHROUGH-SIZE pass |
| 13 | After install, npm, PyPI and Docker proxy repositories exist in Nexus without any manual step (23-04.1) | VERIFIED | Render N1-f (no Helm remote) → exactly `000-npm.json npm-proxy https://registry.npmjs.org`, `001-pypi.json pypi-proxy https://pypi.org`, `002-docker.json docker-proxy https://registry-1.docker.io`. `templates/job-provision.yaml:66,69` `"helm.sh/hook": post-install,post-upgrade` and `"argocd.argoproj.io/hook": Sync`. Live N1-g: `GET /service/rest/v1/repositories` lists `npm-proxy`/`pypi-proxy`/`docker-proxy` with those exact remotes, created by the Job, not by hand |
| 14 | A Helm proxy repository is created when, and only when, the consumer supplies a remote (23-04.2) | VERIFIED | N1-e with `--set repos.helm.remoteUrl=https://charts.jetstack.io` → 4 lines incl. `003-helm.json helm-proxy https://charts.jetstack.io`; N1-f without it → 3 lines, no `003-helm`. `values.yaml` `repos.helm.remoteUrl: null`. Gate HELM-REPO-OPT-IN passes. Live `helm-proxy` → `https://charts.jetstack.io`, supplied by overlay `argocd-overrides.yaml:82` (N1-h). See Important Note (D-05) |
| 15 | Re-running an upgrade re-applies the same configuration without failing (23-04.3) | VERIFIED (from evidence, not re-run) | `job-provision.yaml:66-68` hook `post-install,post-upgrade` with `hook-delete-policy: before-hook-creation` (the Job re-runs on every upgrade). Not re-run (would mutate the homelab). Durable witness: `25-VERIFICATION.md` truth 12, second sync against a PVC holding state → `4× action=updated, 0× action=created`, `SECOND-SYNC-IDEMPOTENT: PASS` |
| 16 | The chart ships no auto-accepted licence agreement; a consumer who has opted in gets a Nexus whose EULA is accepted, so packages download (23-03.4b + 23-04.4) | VERIFIED | `values.yaml` `eula: {accepted: false}`. Gates EULA-OPT-IN and EULA-ENV pass within 18/18. Chart `README.md:78` `eula.accepted defaults to false`, L87 the `POST /service/rest/v1/system/eula` → `204` path. Opted-in download: `25-VERIFICATION.md` truth 7, live lodash `200 318961` bytes (overlay opts in) |
| 17 | A consumer can install the chart correctly from its README alone, without reading the templates (23-05.1) | VERIFIED | `kubernetes/nexus/README.md` `## Install` L139: L144 `helm dependency build kubernetes/nexus`, L150-154 `helm install nexus kubernetes/nexus --set nexus3.rootPassword.secret=nexus-admin --set eula.accepted=true --set repos.helm.remoteUrl=...`; values table L201-233 lists every consumer knob incl. `nexus3.persistence.storageClass` *unset* (L211) and `repos.helm.remoteUrl` *unset* (L233) |
| 18 | The four facts that would otherwise cause a silent failure are stated before the install command (23-05.2) | VERIFIED | `grep -nE '^#{1,3} ' README.md` → `## Before You Install` L51 with `### 1.` admin credential L55, `### 2.` EULA L76, `### 3.` Helm proxy no default L91, `### 4.` CE usage ceiling L101 — all before `## Install` L139. A fifth fact (`### 5.` anonymous read, L107) was added by Phase 24: expected growth, not drift |
| 19 | The repository's own front page names the directory that actually exists (23-05.3) | VERIFIED | `security-platform` `README.md:30` tree entry `nexus/  # Nexus Repository chart — npm, PyPI, Docker and Helm proxy repos` under the `kubernetes/` branch; L42 row for `kubernetes/` "Nexus chart complete (Phase 23)". The literal string `kubernetes/nexus` does not appear because the tree splits the path. `git ls-tree --name-only origin/main kubernetes/nexus/` confirms the directory exists |
| 20 | The chart installs on a real Kubernetes cluster and its hook Job reaches completion (23-06.4) | VERIFIED (from evidence, not re-run) | The one-time 23-06 `kind` install is recorded in 23-06-SUMMARY:63,185 and not re-run. Stronger durable witness: the live homelab `kubectl -n nexus get sts,pvc` → `statefulset.apps/nexus-nexus3 1/1` (6d), PVC Bound, and the 4 chart proxies exist live (N1-g), which only the hook Job creates. `kubectl -n nexus get jobs` → `No resources found` (TTL-reaped, as `25-VERIFICATION.md` Probe Execution explains); `25-VERIFICATION.md` truth 5 records `hookType: Sync, hookPhase: Succeeded` on both syncs |
| 21 | Adding this chart does not turn the repository's CI security gate red (23-06.5) | VERIFIED | `gh pr checks 14 -R $R` → 12 checks, all `pass`: Checkov, GitGuardian, Semgrep OSS, Trivy, gitleaks, `security / Container — Trivy Image`, `security / IaC — Checkov`, `security / SAST — Semgrep CE`, `security / SCA — Trivy Filesystem`, `security / Secrets — Gitleaks`, tflint, tflint-errors. Matches 23-08-SUMMARY:19 "Twelve CI check conclusions ... all SUCCESS". Coverage caveat: deferred item 3 (Checkov cannot render the chart) |
| 22 | This repository's scope statement names security-platform as the host of K8s packages, not only the CI workflow (23-07.1) | VERIFIED | `CLAUDE.md:5` "...together with the K8s packages that implement its Kubernetes infrastructure layer (`kubernetes/<service>/` Helm charts, starting with `kubernetes/nexus/`), live in `OttawaCloudConsulting/security-platform`" |
| 23 | The decision to wrap a community chart instead of a Sonatype-published one is recorded with the measurements that forced it (23-07.2) | VERIFIED | `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md` `**Status:** Accepted`; `grep -noiE 'Sonatype-published\|stevehipwell\|measured'` → L9 `Sonatype-published`, L10-11 `Measured`, L17 `stevehipwell`. Read as evidence, not edited |
| 24 | The EULA opt-in and the unset Helm proxy remote are recorded as deliberate decisions, not oversights (23-07.3) | VERIFIED | ADR-020 title (L1) `Nexus Chart Base, EULA Opt-In and the Unset Helm Proxy Remote`; L10 `eula`, L20 `remoteUrl`; `## Decision` at L15; indexed at `docs/adr/README.md:30` as Accepted |
| 25 | What was not verified in this phase is written down rather than left implicit (23-07.4) | VERIFIED | ADR-020 `grep -n '^## '` → L7 Context, L15 Decision, L24 Consequences, **L40 `## What was NOT verified`** |
| 26 | The subchart pin-freshness question (Renovate vs Dependabot) carries an explicit recorded disposition (23-07.5) | VERIFIED | ADR-020 L38 contains both `Renovate` and `Dependabot` (the `**Tradeoff — subchart pin freshness.**` paragraph). Current status: deferred item 4, OPEN (`Chart.lock:4` still `version: 5.26.0`) |
| 27 | The chart is public: it exists on `OttawaCloudConsulting/security-platform` main, not only in a local branch (23-08.1) | VERIFIED | N1-a `gh api repos/$R -q '{visibility,default_branch}'` → `{"default_branch":"main","visibility":"public"}`. `git ls-tree --name-only origin/main kubernetes/nexus/` → `.helmignore`, `Chart.lock`, `Chart.yaml`, `README.md`, `files`, `templates`, `values.yaml`; `git merge-base --is-ancestor ea2770f origin/main` exit 0 |
| 28 | The repository's own CI security pipeline ran against the chart and its result is known (23-08.2) | VERIFIED | `gh pr checks 14 -R $R` → the five `security / *` jobs of run `35416306666` all `pass` (see row 21) |
| 29 | The merge happened only after the operator explicitly approved it (23-08.3) | VERIFIED | N1-b `gh pr view 14 --json mergedBy` → `{"is_bot":false,"login":"OttawaCloudConsulting","name":"OCC"}`; `gh api repos/$R/pulls/14 -q '.merged_by \| {login, type}'` → `{"login":"OttawaCloudConsulting","type":"User"}`. 23-08-SUMMARY:45 records the operator merged through the GitHub UI and `gh pr merge` was never invoked by an agent |
| 30 | The merged state was read from `origin/main`, never inferred from the local working tree (23-08.4) | VERIFIED | This session re-derived it the same way: `gh api repos/$R/commits/main -q .sha` = `git rev-parse origin/main` = `git rev-parse HEAD` = `fdabac9464f2baaeaa276f8934dc8d353295b355`, `git status --porcelain` empty; every chart read above is from that tree or a `git archive` of a named SHA. 23-08-SUMMARY:18 records the original read at `ea2770f` via `git ls-tree`/`git show` |

**Score:** 30/30 truths verified (26 re-observed this session; rows 5, 15 and 20 scored `VERIFIED (from evidence, not re-run)` from durable later witnesses; row 4's intermediate-commit clause rests on the documented convention plus both re-run endpoints).

**The counting asymmetries — expected structure, not drift:**
- **17 gate checks at `ea2770f`, 18 at `fdabac9`.** Phase 24 added ANONYMOUS-DEFAULT and rewrote check 8 into ANONYMOUS-VALUE-PRESENT; the script header (L17) states the count is a literal kept in three places. (23-06-SUMMARY:63 records 16 at 23-06 time; the post-review fixes before merge brought it to the 17 observed on the `ea2770f` archive.)
- **11 live repositories, 4 chart proxies.** The live list is `docker-proxy, helm-proxy, maven-central, maven-public, maven-releases, maven-snapshots, npm-proxy, nuget-group, nuget-hosted, nuget.org-proxy, pypi-proxy`. The 7 `maven-*`/`nuget*` entries are Nexus built-ins; the chart sets `nexus3.config.enabled: false` (CONFIG-DISABLED) and does not manage them. The four chart names were *selected*, not counted.
- **3 default repo bodies, 4 with a Helm remote.** This is D-05 by design (Important Note below).
- **PVC StorageClass `default`.** It is not a placeholder: `default` is the literal name of the cluster's default class (`default (default)`, provisioner `csi.trident.qnap.io`). Paired with the STS template read (no `storageClassName`), it shows admission filled it in.

### Important Note: Helm Proxy Is Consumer-Configured (D-05)

REQUIREMENTS.md:14 states NEXUS-01 as "Public Helm chart deploys Nexus Repository with npm, PyPI, Docker, and Helm proxy repos configured". A default install of the shipped chart creates **three** proxy repositories; the Helm proxy is created only when the consumer supplies `repos.helm.remoteUrl`. This is **not an unexplained gap**:
- `23-CONTEXT.md:27` locks **D-05 (REVISED post-research 2026-09-17)**: the npm/PyPI/Docker remotes ship as defaults, and the Helm remote has **no default** because Helm Hub is defunct, Artifact Hub is a search index rather than a chart repository serving one `index.yaml`, and Bitnami's repo is mid-deprecation.
- The ROADMAP.md:25 goal — the contract for this phase — encodes the same decision verbatim: "(Helm proxy is consumer-configured, no universal default exists post-Helm-Hub)".
- ADR-020 (Accepted) records it as a deliberate decision (row 24), and the chart README §3 (L91-100) tells the consumer before the install command.
- The mechanism is proven both ways: N1-e renders the 4th body `003-helm.json helm-proxy https://charts.jetstack.io` when a remote is set, N1-f renders exactly 3 without one, and gate check HELM-REPO-OPT-IN enforces it.
- The deployed instance has a Helm proxy: live N1-g lists `helm-proxy` (`format: helm`, `type: proxy`, remote `https://charts.jetstack.io`), supplied by the private overlay at `argocd-overrides.yaml:82` (N1-h).
- Same-milestone precedent: `24-VERIFICATION.md` marked NEXUS-02 SATISFIED with its opt-in default disclosed in an Important Note, without an override, and the v3.0 audit accepted it.

The capability NEXUS-01 names is fully implemented; only the shipped default for one of the four remotes is deliberately empty. No override entry is added (`overrides_applied: 0`) because the deviation is already disclosed in-repo at the point a reader would look (ROADMAP goal, chart README §3, ADR-020); it is flagged here for visibility only.

### Required Artifacts

All chart artifacts are read from `security-platform` at `fdabac9`; ADR-020 from this repository.

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `kubernetes/nexus/Chart.yaml` | wrapper chart, one pinned dependency | VERIFIED | `name: nexus`, `version: 0.1.0`, `appVersion: "3.96.0"`, dependency `nexus3` `5.26.0` from `https://stevehipwell.github.io/helm-charts/`; identical to `ea2770f` |
| `kubernetes/nexus/Chart.lock` | pinned subchart | VERIFIED | `version: 5.26.0` (L4); identical to `ea2770f`; `helm dependency list` → `ok` |
| `kubernetes/nexus/values.yaml` | persistence on, storageClass absent, 4 repo entries, no credential | VERIFIED | `.nexus3.persistence` `{enabled: true, size: 8Gi}`, no `storageClass` key; `.repos` npm/pypi/docker remotes set, `helm.remoteUrl: null`; `eula.accepted: false`; `anonymous.enabled: false`; `.nexus3.persistence` and `.repos` subtrees identical to `ea2770f` |
| `kubernetes/nexus/templates/_helpers.tpl` | naming helpers incl. `nexus.nexus3Fullname` | VERIFIED | Present in `git ls-tree origin/main kubernetes/nexus/templates`; the 23-04 key-link to `nexus.nexus3Fullname` verified by `gsd-sdk query verify.key-links` |
| `kubernetes/nexus/templates/configmap-repos.yaml` | one JSON body per configured repo | VERIFIED | Renders `000-npm.json`..`003-helm.json` (N1-e/f); REPO-BODIES and DOCKER-BODY pass; identical to `ea2770f` |
| `kubernetes/nexus/templates/configmap-provision-script.yaml` | ships `files/provision.sh` into the Job | VERIFIED | Present on `origin/main`; rendered by the default `helm template` used in every probe |
| `kubernetes/nexus/templates/job-provision.yaml` | single hook Job, both hook systems | VERIFIED | L66 `helm.sh/hook: post-install,post-upgrade`, L68 `before-hook-creation`, L69 `argocd.argoproj.io/hook: Sync`; JOB-HOOK, JOB-NAME-LENGTH, EULA-ENV pass |
| `kubernetes/nexus/files/provision.sh` | REST upsert of repos + EULA | VERIFIED | Present; 23-04 key-link to "Nexus REST API v1" verified; +148 lines since `ea2770f` (Phase 24 anonymous realm), outcome proven live (N1-g) |
| `kubernetes/nexus/README.md` | consumer install guide | VERIFIED | Rows 17-18; §Storage L169-175 documents NEXUS-03 and the `"-"` sentinel |
| `scripts/check-nexus-chart.sh` | offline gate, exit 0/1/2 | VERIFIED | 18/18 at `fdabac9`, 17/17 at `ea2770f`, exit 1 on mutation, exit 2 on missing tgz |
| `scripts/nexus-live-smoke.sh` | live smoke derived from the chart | VERIFIED | Present; rows 6 and 8; not re-run (Probe Execution) |
| `.gitignore` | ignores vendored subchart | VERIFIED | L28 `kubernetes/*/charts/*.tgz` |
| `.pre-commit-config.yaml` | yamllint excludes Go templates | VERIFIED | L63 `exclude: ^kubernetes/.*/templates/` |
| `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md` (this repo) | ADR recording chart base, EULA opt-in, unset Helm remote | VERIFIED | `Status: Accepted`, `Addresses: NEXUS-01 ... and NEXUS-03`; `wc -l -c` → 48 lines, 19,622 bytes; 4 `##` sections (Context, Decision, Consequences, What was NOT verified). `verify.artifacts` reports "Only 49 lines, need 60" (it counts the final line after the trailing newline): a `min_lines` tooling-fit shortfall on a document written as long one-line paragraphs, not a stub (23-07-SUMMARY:106 "47 content lines"). Read as evidence, not edited — `docs/adr/` is append-only |

### Key Link Verification

`gsd-sdk query verify.key-links` reports four links as unverified. None is a defect. Three are **double-escaped patterns**: the plan frontmatter stores e.g. `provision\\.sh`, which the tool matches as a literal backslash followed by any character, so a correct source line cannot match. The fourth is a branch-to-branch link (23-08) whose "source" is a remote fact, not a file, so the tool reports "Source file not found". Each was re-verified manually in this session by the grep or `gh` call named below, and every one held.

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `scripts/check-nexus-chart.sh` | `kubernetes/nexus` | `helm lint` / `helm template` through `render()` | WIRED | `verify.key-links` 23-01: verified; gate run 18/18 |
| `scripts/nexus-live-smoke.sh` | `kubernetes/nexus/files/provision.sh` | invokes the script the Job runs | WIRED | Tool false negative (pattern `kubernetes/nexus/files/provision\\.sh`). Manual: `grep -n 'PROVISION_SH=' scripts/nexus-live-smoke.sh` → L54 `PROVISION_SH="kubernetes/nexus/files/provision.sh"` |
| `scripts/nexus-live-smoke.sh` | rendered repos ConfigMap | `helm template \| yq` | WIRED | `verify.key-links` 23-02: verified; L135 |
| `kubernetes/nexus/Chart.yaml` | `stevehipwell/nexus3` 5.26.0 | `dependencies` entry | WIRED | Tool false negative (pattern `version:\\s*5\\.26\\.0`). Manual: `grep -n 'version: 5.26.0' Chart.yaml` → L8 `    version: 5.26.0`; P-a `ok` |
| `kubernetes/nexus/values.yaml` | subchart `volumeClaimTemplates` | `nexus3.persistence` passthrough, storageClass omitted | WIRED | `verify.key-links` 23-03: verified; N3-a..N3-c |
| `templates/job-provision.yaml` | `nexus.nexus3Fullname`, `nexus3.rootPassword.secret` | Service DNS name; `secretKeyRef` wrapped in `required` | WIRED | `verify.key-links` 23-04: 3/3 verified |
| `files/provision.sh` | Nexus REST API v1 | GET → PUT/POST upsert, EULA POST | WIRED | `verify.key-links` 23-04: verified; live N1-g |
| `security-platform` `README.md` | `kubernetes/nexus/README.md` | structure tree entry | WIRED | `verify.key-links` 23-05: verified; row 19 |
| `scripts/nexus-live-smoke.sh` | live Nexus container + kind cluster | `docker run` + `helm install` | WIRED | `verify.key-links` 23-06: verified (pattern in source; run not repeated) |
| `docs/adr/README.md` | `adr020-nexus-chart-base-and-eula-opt-in.md` | index table row | WIRED | Tool false negative (pattern `adr020-nexus-chart-base-and-eula-opt-in\\.md`). Manual: `grep -n` → `docs/adr/README.md:30` `\| [ADR-020](adr020-nexus-chart-base-and-eula-opt-in.md) \| ... \| Accepted \|` |
| `feature/phase-23-nexus-generic-chart` | `security-platform` `main` | PR merged after operator approval | WIRED | Tool "Source file not found" (remote fact). Substituted N1-b: PR #14 `MERGED`, merge `ea2770f…`, `mergedBy` `is_bot: false`, `type: User`; `ea2770f` is an ancestor of `origin/main` |

### Behavioral Spot-Checks

All run in this session (2026-09-29). Render commands run from `repos/security-platform` at `fdabac9` with `--set nexus3.rootPassword.secret=x` (a Secret *name*, not a credential).

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Repo is public (N1-a) | `gh api repos/$R -q '{visibility,default_branch}'` | `{"default_branch":"main","visibility":"public"}` | PASS |
| Phase 23 PR identity (N1-b) | `gh pr view 14 -R $R --json state,mergeCommit,mergedAt,mergedBy,headRefOid` | `MERGED`, `ea2770fbf1f8a4bd532d131835d90fb86c6f5d54`, `2026-09-19T11:41:43Z`, `OttawaCloudConsulting` `is_bot:false`, head `162bdf4b2fa684831aa973f6f4a33c520ca1c562` | PASS |
| Gate at today's main (N1-c) | `bash scripts/check-nexus-chart.sh` | `PASS - 18 checks, 0 failures`, exit 0 | PASS |
| Gate at the Phase 23 merge (N1-d) | `git archive ea2770f kubernetes/nexus scripts/check-nexus-chart.sh \| tar -x`, copy tgz, run gate | `PASS - 17 checks, 0 failures`, exit 0 | PASS — 17 vs 18 is Phase 24's added check |
| Helm opt-in renders 4 bodies (N1-e) | `helm template ... --set repos.helm.remoteUrl=https://charts.jetstack.io \| yq '<-repos ConfigMap: key name remoteUrl>'` | `000-npm.json npm-proxy https://registry.npmjs.org` / `001-pypi.json pypi-proxy https://pypi.org` / `002-docker.json docker-proxy https://registry-1.docker.io` / `003-helm.json helm-proxy https://charts.jetstack.io` | PASS |
| Default renders 3 bodies (N1-f) | same, no `repos.helm.remoteUrl` | the first three lines only, no `003-helm` | PASS — D-05 by design |
| Live proxies (N1-g) | port-forward `svc/nexus-nexus3 18081:8081`; `curl .../service/rest/v1/status`; `curl .../service/rest/v1/repositories \| jq '[select(.name\|test("^(npm\|pypi\|docker\|helm)-proxy$"))]'`; `kill $PF` | status `200` (after one `curl: (7)` connection-refused retry while the forward came up); `npm-proxy` npm/proxy `https://registry.npmjs.org`, `pypi-proxy` pypi/proxy `https://pypi.org`, `docker-proxy` docker/proxy `https://registry-1.docker.io`, `helm-proxy` helm/proxy `https://charts.jetstack.io`; 11 repos total; `pgrep -f '[p]ort-forward svc/nexus-nexus3'` empty after | PASS — unauthenticated read works via the overlay's NEXUS-02 opt-in |
| Overlay supplies the Helm remote (N1-h) | `git -C $OV show origin/main:application-sets/platform/nexus/argocd-overrides.yaml \| grep -n remoteUrl` | L82 `remoteUrl: https://charts.jetstack.io` | PASS |
| Default omits storageClassName (N3-a) | `helm template ... \| yq 'select(.kind=="StatefulSet")\|.spec.volumeClaimTemplates[0].spec\|{"has":has("storageClassName"),"sc":.storageClassName}'` | `{"has":false,"sc":null}` | PASS |
| `--set` override (N3-b) | `+ --set nexus3.persistence.storageClass=longhorn` | `{"has":true,"sc":"longhorn"}` | PASS |
| Values-file override (N3-c) | `+ -f ovr.yaml` (`nexus3.persistence.storageClass: fast-ssd`) | `{"has":true,"sc":"fast-ssd"}` | PASS |
| `-` sentinel (N3-d) | `+ --set nexus3.persistence.storageClass=-` | `{"has":true,"sc":""}` | PASS — '-' sentinel, not an override (Pitfall 8) |
| Gate discriminates (N3-e) | scratch `git archive fdabac9`, `yq -i '.nexus3.persistence.storageClass = "standard"'`, run gate | `FAIL: STORAGECLASS-OMITTED: expected has("storageClassName") == false on the default render, got 'true'` / `FAILED - 1 check(s)`, exit 1; clone porcelain empty after | PASS — gate discriminates |
| Subchart implements override (N3-f) | `tar -xzf nexus3-5.26.0.tgz; grep -n storageClass nexus3/templates/statefulset.yaml` | L426 `{{- with .Values.persistence.storageClass }}`, L428 `storageClassName: ""`, L430 `storageClassName: {{ . \| quote }}` | PASS |
| Live STS template has no class (N3-g) | `kubectl --context admin@occ-new -n nexus get sts nexus-nexus3 -o json \| jq '.spec.volumeClaimTemplates[0].spec'` | `{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"8Gi"}},"volumeMode":"Filesystem"}` — no `storageClassName`; STS 1/1 | PASS |
| Live PVC got the cluster default (N3-h) | `kubectl ... get pvc data-nexus-nexus3-0 -o json \| jq '{sc,phase}'`; `kubectl get storageclass`; overlay `grep -nE 'storageClass\|persistence'` | `{"sc":"default","phase":"Bound","cap":"8Gi"}`; `default (default)` `csi.trident.qnap.io` among 5 classes; overlay grep no match, exit 1 (expected) | PASS |
| NEXUS-01 surfaces unchanged (SI-1) | `git diff --quiet ea2770f fdabac9 -- templates/configmap-repos.yaml Chart.yaml Chart.lock` | exit 0 | PASS |
| NEXUS-03 / repos values unchanged (SI-2) | `diff <(git show ea2770f:values.yaml \| yq -o json '{"p":.nexus3.persistence,"r":.repos}') <(... fdabac9 ...)` | no output, exit 0 | PASS |
| Subchart resolves (P-a) | `helm dependency list kubernetes/nexus` | `nexus3 5.26.0 https://stevehipwell.github.io/helm-charts/ ok` | PASS |
| Vendored tgz is the genuine upstream (P-b) | `shasum -a 256` local tgz vs fresh `helm pull nexus3 --version 5.26.0 -d <scratch>` | both `e47791e668e29e6f2242a81630259ae59e852219776ee55c4df0f3d17a918e4f` | PASS |
| Missing tool is not a chart defect (preflight) | `git archive fdabac9` without the tgz, run gate | `PREFLIGHT FAIL: subchart not vendored — no kubernetes/nexus/charts/*.tgz`, exit 2 | PASS |
| No default credential (bare render) | `helm template t kubernetes/nexus` | exit 1, error names `nexus3.rootPassword.secret` | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| `scripts/check-nexus-chart.sh` at `fdabac9` | `(cd repos/security-platform && bash scripts/check-nexus-chart.sh)` | `PASS - 18 checks, 0 failures`, exit 0 | PASS |
| `scripts/check-nexus-chart.sh` at `ea2770f` archive | `git archive ea2770f ... \| tar -x -C <scratch>/at-ea2770f`, tgz copied (valid: `Chart.lock` identical, SI-1), run gate | `PASS - 17 checks, 0 failures`, exit 0 | PASS — 17 is the as-shipped count (Pitfall 2); without the copied tgz the gate would exit 2 on preflight (Pitfall 7) |
| Mutation N3-e | scratch archive with `storageClass: "standard"` pinned | `FAIL: STORAGECLASS-OMITTED ... got 'true'`, `FAILED - 1 check(s)`, exit 1 | PASS — gate discriminates |
| `scripts/nexus-live-smoke.sh` | — | NOT RUN — Docker + `kind`, ~8 min; per the NEXUS-03 Evidence Tier it would prove nothing the render and the live homelab do not already prove, and its one-time facts have durable later witnesses (`25-VERIFICATION.md` truths 5, 7, 12) | SKIP (not MISSING_PROBE — the probe file exists and was read) |

**GSD tooling probes (P-c / P-d)**, run per plan with `gsd-sdk query verify.artifacts` and `verify.key-links`:

| Plan | `verify.artifacts` | `verify.key-links` | Reading |
|------|--------------------|--------------------|---------|
| 23-01 | 3/3 | 1/1 | clean |
| 23-02 | 1/1 | 1/2 | false negative, double-escaped pattern; manual grep L54 holds |
| 23-03 | 4/4 | 1/2 | false negative, double-escaped pattern; manual grep `Chart.yaml:8` holds |
| 23-04 | 4/4 | 3/3 | clean |
| 23-05 | 2/2 | 1/1 | clean |
| 23-06 | `error: No must_haves.artifacts found in frontmatter` | 1/1 | run plan, no file artifacts by design |
| 23-07 | 2/3 | 0/1 | ADR-020 `min_lines` (49 < 60, tooling-fit); double-escaped pattern, manual grep `docs/adr/README.md:30` holds |
| 23-08 | `error: No must_haves.artifacts found in frontmatter` | 0/1 | merge plan; "Source file not found" on a branch-to-branch link, substituted by N1-b |

Every non-clean result is a tooling fit, not a defect: none of them changes a verdict above. They are recorded as new tooling findings in the Phase 29.1 ledger (see Gaps Summary).

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| NEXUS-01 | 23-01, 23-02, 23-03, 23-04, 23-05, 23-06, 23-07, 23-08 | Public Helm chart deploys Nexus Repository with npm, PyPI, Docker, and Helm proxy repos configured | SATISFIED (Helm proxy consumer-configured per D-05, disclosed — see note above) | Public on `main` (N1-a, row 27); 3 default bodies + Helm body on opt-in (N1-e/f, HELM-REPO-OPT-IN); 4 proxies live (N1-g); gate 17/17 at `ea2770f`, 18/18 at `fdabac9`. 3-source cross-reference re-grepped this session: this report names NEXUS-01; `23-08-SUMMARY.md:53` `requirements-completed: [NEXUS-01, NEXUS-03]`; `REQUIREMENTS.md:14` `- [x] **NEXUS-01**` and `:47` `\| NEXUS-01 \| Phase 23 \| Complete \|` |
| NEXUS-03 | 23-01, 23-03, 23-05, 23-06, 23-07, 23-08 | Chart uses the cluster's default StorageClass unless overridden by the consumer | SATISFIED | Default path render (N3-a) + live (N3-g/h); override path render via `--set` and `-f` (N3-b/c), subchart source (N3-f), gate mutation exit 1 (N3-e); `.nexus3.persistence` identical between `ea2770f` and `fdabac9` (SI-2). 3-source cross-reference re-grepped this session: this report names NEXUS-03; `23-08-SUMMARY.md:53` `requirements-completed: [NEXUS-01, NEXUS-03]`; `REQUIREMENTS.md:16` `- [x] **NEXUS-03**` and `:48` `\| NEXUS-03 \| Phase 23 \| Complete \|` |

Source plans were taken from each plan's `requirements:` frontmatter (`yq --front-matter=extract '.requirements'`): all eight declare NEXUS-01; 23-02 and 23-04 declare only `[NEXUS-01]`; the other six declare `[NEXUS-01, NEXUS-03]`.

No orphaned requirements — REQUIREMENTS.md maps only NEXUS-01 and NEXUS-03 to Phase 23.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `kubernetes/nexus/files/provision.sh` | 119 | `mktemp -d /tmp/nexus-provision.XXXXXX` | — | False positive: a `mktemp` template placeholder, not a debt marker (same disclaimer as `24-VERIFICATION.md`) |

`grep -rnE 'TBD|FIXME|XXX' kubernetes/nexus scripts/check-nexus-chart.sh scripts/nexus-live-smoke.sh` at `fdabac9` returned that single line and nothing else. No debt markers.

### Human Verification Required

None. The one human gate Phase 23 required — 23-08's blocking operator approval before merge — was closed during the original phase: 23-08-SUMMARY:20 and :45 record that the operator reviewed, approved and merged PR #14 himself through the GitHub UI, and N1-b re-confirms it this session (`mergedBy: OttawaCloudConsulting`, `is_bot: false`; REST `merged_by.type: User`). No new human verification is deferred by this report.

### Gaps Summary

No gaps against NEXUS-01, NEXUS-03, or any of the 30 derived must-haves — all are confirmed against `security-platform` at the pinned SHAs, the live homelab, and the overlay's `origin/main`, not merely asserted in SUMMARY.md prose. The items below are informational, not gaps; they are stated here so that nothing is concealed:

1. **D-05 Helm opt-in.** NEXUS-01's literal wording lists a Helm proxy; a default install creates three proxies and the Helm proxy appears only when the consumer supplies a remote. Disclosed in the Important Note above; `overrides_applied: 0`.
2. **The live anonymous listing is an overlay opt-in, not chart default behaviour.** N1-g's unauthenticated `GET /service/rest/v1/repositories` succeeds because the overlay sets `anonymous: enabled: true` (`argocd-overrides.yaml:72-76`). The chart ships `anonymous.enabled: false` (ANONYMOUS-DEFAULT). If the homelab ever closes anonymous read, N1-g would need the admin credential; the correct substitute is `25-VERIFICATION.md` truths 7 and 10, not reading the Secret.
3. **`23-VALIDATION.md` still carries `wave_0_complete: false`** (L6). It is owned by `/gsd:validate-phase 23` and listed by the v3.0 audit as tech debt; it was not changed here.
4. **GSD tooling findings.** `frontmatter.get --field` errors; `verify.key-links` false negatives on double-escaped patterns (23-02, 23-03, 23-07); `verify.artifacts` `min_lines` against a long-line ADR (23-07). None affects a verdict. They are logged in `.planning/phases/29.1-close-gap-nexus-01-nexus-03-retroactive-verification-md-for-/deferred-items.md` (created by plan 29.1-02), not in Phase 23's ledger.

**Each of Phase 23's eight `deferred-items.md` entries, current verdict:**

1. **`CLAUDE.md` ADR range — OPEN.** `grep -n 'ADR-001 through ADR-0' CLAUDE.md` → L10 still says `ADR-001 through ADR-018`, while `docs/adr/` now runs to `adr028`. The correction remains the operator's call.
2. **`provision.readiness.*` dead knobs — RESOLVED 2026-09-20** in plan 24-02 (`security-platform` `07c74e2`), as already recorded in the ledger.
3. **CI Checkov has zero coverage of `kubernetes/nexus` — ACCEPTED** per ADR-021 decision 10 (24 latent findings restated, the `required` guard not weakened). PR #14's Checkov checks `pass` (row 21) must be read with this caveat.
4. **Subchart pin freshness has no automation — OPEN.** `Chart.lock:4` still `version: 5.26.0`; ADR-020's pin-freshness tradeoff stands.
5. **Pre-existing `.planning/` working-tree changes — still present, decision left to the operator.** Measured 2026-09-29: `git status --short .planning/config.json .planning/v2.0-MILESTONE-AUDIT.md` → ` M .planning/config.json`, ` D .planning/v2.0-MILESTONE-AUDIT.md`; `git log --oneline -1 -- .planning/v2.0-MILESTONE-AUDIT.md` → `c6ccf48 docs(v2.0): close phase 21 with retroactive verification, audit milestone`. Neither was staged, committed or restored by this phase.
6. **`state.update-progress` no-ops on this STATE.md — OPEN** (inspection only; the handler was not invoked while re-checking, and the v3.0 audit still carries it).
7. **`state.record-metric` rejects positional arguments — OPEN** (inspection only; the flag form remains the working form).
8. **`roadmap.update-plan-progress` does not flip the milestone checklist line — OPEN** (inspection only; the 23-08 hand-edit fixed that one ROADMAP line, not the tool).

---

_Verified: 2026-09-29_
_Verifier: Claude (gsd-verifier), retroactive via Phase 29.1_
