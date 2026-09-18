---
phase: 23-nexus-generic-chart
plan: 03
subsystem: infra
tags: [helm, nexus, subchart, chart-lock, values, helpers, storageclass, eula, digest-pin]

# Dependency graph
requires:
  - phase: 23-nexus-generic-chart
    plan: 01
    provides: "feature/phase-23-nexus-generic-chart branch; .gitignore kubernetes/*/charts/*.tgz; scripts/check-nexus-chart.sh, whose 16 checks read the value keys this plan writes"
  - phase: 23-nexus-generic-chart
    plan: 02
    provides: "scripts/nexus-live-smoke.sh and its binding contracts on chart shape (instance label on the Job, -repos ConfigMap suffix, Secret key 'password')"
provides:
  - "kubernetes/nexus — a wrapper chart that resolves and lints against pinned stevehipwell/nexus3 5.26.0 with no fork and no vendored copy in git"
  - "The complete consumer value surface (nexus3.*, eula.*, provision.*, repos.*) that plans 23-04..23-08 read"
  - "Four template helpers, incl. nexus.nexus3Fullname — the only correct way for 23-04's Job to address the subchart's Service"
  - "MEASURED NEXUS-03 evidence: the default render emits a volumeClaimTemplate with no storageClassName at all"
affects: [23-04, 23-05, 23-06, 23-07, 23-08, phase-24-nexus-hardening, phase-25-argocd]

# Tech tracking
tech-stack:
  added:
    - "stevehipwell/nexus3 5.26.0 (Helm subchart, MIT, ArtifactHub verified publisher) — pinned in Chart.lock, digest sha256:24ad740d457b527f5e89f176fe4965c0c44d90f30133a3e4c8766b7f4156240f"
  patterns:
    - "Wrapper chart over a community subchart: declare the dependency, override only the defaults that are wrong for this stack, never re-declare the subchart's full surface"
    - "Absence as configuration: the NEXUS-03 behaviour is the storageClass key NOT existing, documented in a comment so a future editor cannot 'tidy' it back in"
    - "Replicating a subchart helper in the parent rather than hardcoding <release>-<subchart>, and proving the replica by diffing it against the subchart's own rendered Service name under five override combinations"

key-files:
  created:
    - repos/security-platform/kubernetes/nexus/Chart.yaml
    - repos/security-platform/kubernetes/nexus/Chart.lock
    - repos/security-platform/kubernetes/nexus/.helmignore
    - repos/security-platform/kubernetes/nexus/values.yaml
    - repos/security-platform/kubernetes/nexus/templates/_helpers.tpl
  modified: []

key-decisions:
  - "nexus3.rootPassword.secret and repos.helm.remoteUrl are written as explicit `null`, not as bare keys. MEASURED: yq v4.53.6 prints an EMPTY STRING for a bare `key:` and `null` only for a missing or explicitly-null key. The plan's action text asks for the key to be present; its acceptance criteria assert yq reports `null`. Explicit `null` is the only form that satisfies both, and it is the same YAML value the upstream bare-key style produces. PROVEN SAFE end-to-end: Helm treats an explicit null on a subchart key as a deletion from the coalesced subchart values, so this was checked rather than assumed — `--set nexus3.rootPassword.secret=dummy-secret-name` still reaches the subchart's StatefulSet and renders `secretKeyRef: {name: dummy-secret-name, key: password}`."
  - "No `nexus3.image:` block at all, rather than an image block with the tag omitted. Both make yq report `.nexus3.image.tag` as null; omitting the block entirely means there is no place for a tag to be accidentally added. The Nexus version rides the subchart appVersion (D-08) — the default render resolves docker.io/sonatype/nexus3:3.96.0-ubi."
  - "requirements.mark-complete deliberately NOT invoked. NEXUS-03 is implemented AND measured here, but the phase's own gate cannot assert it until 23-04 lands the Job, and the chart is not yet a deployable whole. 23-08 carries [NEXUS-01, NEXUS-03] in its frontmatter and is the plan that should mark them. Read `[]` as withheld on purpose — the 23-01 / 23-02 / 19-01..19-04 / 17-01 precedent."
  - "No `nexus.chart` helper. The plan's verify loops over exactly four helper names, so helm.sh/chart is built inline in nexus.labels with printf/replace rather than by a fifth define."

patterns-established:
  - "Prove a name-derivation helper by differential render: render the wrapper's helper and the subchart's real object name in the same pass and compare, across the default, both override knobs, and both sides of upstream's `contains $name .Release.Name` branch"
  - "Reproducibility check on a gitignored build artifact: sha256 the tarball, delete charts/, rebuild from Chart.lock, compare — proves the lockfile is the real control point, not the file on disk"

requirements-completed: []

# Metrics
duration: 35min
completed: 2026-09-18
---

# Phase 23 Plan 03: Wrapper Chart Scaffold Summary

**`kubernetes/nexus` now resolves, lints and renders a real Nexus StatefulSet from a pinned community subchart it does not fork or vendor into git — and the NEXUS-03 behaviour is a measurement, not a claim: the default render emits a PVC with no `storageClassName` field at all, while `--set nexus3.persistence.storageClass=test` reaches it verbatim.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-09-18T14:47:00Z (approx.)
- **Completed:** 2026-09-18T15:22:34Z
- **Tasks:** 3 of 3
- **Files modified:** 5 (5 created, 0 modified) — all in `repos/security-platform`

## Accomplishments

- **The chart is a real chart now.** `helm template t kubernetes/nexus` produces a Sonatype Nexus StatefulSet, two Services and a PVC template from 9 lines of `Chart.yaml` plus a lockfile. No fork, no vendored copy in git, no reimplemented StatefulSet — D-01 REVISED delivered as written.
- **NEXUS-03 was proven, not asserted.** The plan's own verify only checks that the `storageClass` key is absent from *our* values file. That proves nothing about the subchart honouring it, and this plan is the only point in the phase where it can be checked (23-04's `required` guard makes bare renders fail, and the gate stays in SKIP until then). The render was driven directly — see Verification Evidence.
- **`nexus.nexus3Fullname` was proven against the subchart's actual output** under five release/override combinations, including both sides of upstream's `contains $name .Release.Name` branch. A hardcoded `<release>-nexus3` would have been wrong in three of the five.
- **The lockfile was proven to be the control point.** The tarball was deleted and rebuilt from `Chart.lock`; the rebuilt file is byte-identical (sha256 `e47791e6…18e4f`) and `Chart.lock` was not rewritten.

## Task Commits

1. **Task 1: Chart manifest, pinned dependency, and .helmignore** — `2af546f` (feat)
2. **Task 2: The consumer value surface** — `8c58dba` (feat)
3. **Task 3: Template helpers, including a faithful subchart fullname replica** — `31f110f` (feat)

Branch: `feature/phase-23-nexus-generic-chart` on `repos/security-platform`, **unpushed** (23-08 owns push/PR/merge). Working tree clean.

## Files Created/Modified

- `kubernetes/nexus/Chart.yaml` (9 lines) — `apiVersion: v2`, `name: nexus`, `version: 0.1.0`, `appVersion: "3.96.0"`, one `dependencies` entry for `nexus3` 5.26.0 from `https://stevehipwell.github.io/helm-charts/`. No `alias:`, no Nexus image tag.
- `kubernetes/nexus/Chart.lock` — pins `nexus3` 5.26.0, digest `sha256:24ad740d457b527f5e89f176fe4965c0c44d90f30133a3e4c8766b7f4156240f`.
- `kubernetes/nexus/.helmignore` (33 lines) — sectioned `# OS` / `# Editor` / `# VCS` / `# CI` blocks in the repo's `.gitignore` house style. Contains **zero** occurrences of the string `charts` (including in comments): excluding the vendored dependency would produce a package that cannot install, and git exclusion is `.gitignore`'s job.
- `kubernetes/nexus/values.yaml` (153 lines) — helm-docs `# --` annotations, one `nexus3:` mapping, every non-obvious default with a `versions.conf`-style rationale.
- `kubernetes/nexus/templates/_helpers.tpl` (75 lines) — `nexus.name`, `nexus.fullname`, `nexus.labels`, `nexus.nexus3Fullname`.

`git ls-files kubernetes/nexus` lists **exactly** the five files the plan's `<verification>` requires. The tarball `charts/nexus3-5.26.0.tgz` is present on disk and `git check-ignore` confirms it is ignored.

## Verification Evidence

### The subchart passthrough — driven against the real render, not against our values file

```
helm template t kubernetes/nexus | yq '…volumeClaimTemplates[0].spec | has("storageClassName")'   -> false
helm template t kubernetes/nexus | yq '…volumeClaimTemplates[0].spec'
    accessModes: ["ReadWriteOnce"]   resources.requests.storage: "8Gi"      (a PVC exists — persistence.enabled reached the subchart)
--set nexus3.persistence.storageClass=test  -> storageClassName: test       (override passes through verbatim)
--set nexus3.persistence.size=20Gi          -> requests.storage: 20Gi       (D-07 passthrough canary)
default render, container image             -> docker.io/sonatype/nexus3:3.96.0-ubi   (D-08 floating tag, from the subchart appVersion)
```

The first two lines together are NEXUS-03: a volumeClaimTemplate that exists and carries no `storageClassName`, so Kubernetes substitutes the cluster default.

### `nexus.nexus3Fullname` vs. the subchart's actual Service name

A probe template was added to a **scratchpad copy** of the chart (never inside the repo — the repo tree was verified clean before and after) that emits all four helpers; the probe's `nexus3Fullname` was compared to the name of the non-headless Service the subchart actually rendered in the same pass:

| Release | Override | Helper output | Actual Service | |
|---|---|---|---|---|
| `t` | — | `t-nexus3` | `t-nexus3` | MATCH |
| `nexus3-prod` | — | `nexus3-prod` | `nexus3-prod` | MATCH (`contains` branch) |
| `t` | `nexus3.nameOverride=foo` | `t-foo` | `t-foo` | MATCH |
| `t` | `nexus3.fullnameOverride=bar` | `bar` | `bar` | MATCH |
| `repo` | `nexus3.nameOverride=repo` | `repo` | `repo` | MATCH (`contains` branch via the override) |

A hardcoded `<release>-nexus3` would have been wrong in rows 2, 3, 4 and 5.

Wrapper-owned helpers at release `t`: `nexus.name` → `nexus`, `nexus.fullname` → `t-nexus`, and with `--set nameOverride=custom` → `custom` / `t-custom`, with `--set fullnameOverride=myrelease` → `nexus` / `myrelease`. `nexus.labels` renders `helm.sh/chart: nexus-0.1.0`, `app.kubernetes.io/name: nexus`, `app.kubernetes.io/instance: t`, `app.kubernetes.io/managed-by: Helm`, `app.kubernetes.io/version: "3.96.0"` — the `instance` label 23-02 binds on is present.

Note: `helm` refuses release names longer than 53 chars (`invalid release name … must not be longer than 53`), so the `trunc 63` path is unreachable through the release name alone. It is retained because it is upstream's logic verbatim and `fullnameOverride` is unbounded.

### Value-surface assertions (all 25 keys read back)

Every key in the plan's `<interfaces>` table was read with `yq` and matched its required default. Notable ones: `.nexus3.persistence | has("storageClass")` → `false`; `.nexus3.image.tag` → `null`; `.nexus3.rootPassword.secret` → `null`; `.nexus3.rootPassword.key` → `password`; `.eula.accepted` → `false`; `.nexus3.config.enabled` → `false`; `.nexus3.config.anonymous.enabled` → `false`; both helper digests match the values measured in 23-RESEARCH.md; `.repos.helm.remoteUrl` → `null` with `.repos.helm.name` → `helm-proxy`; all four `provision.resources` knobs non-null.

Credential grep `grep -vE '^\s*#' values.yaml | grep -ciE 'password:\s*\S'` → **0**. EULA URL `https://links.sonatype.com/products/nxrm/ce-eula` present once.

### The explicit-`null` decision, checked against the subchart rather than assumed

Helm treats an explicit `null` on a subchart key as "delete this key from the coalesced subchart
values", so writing `nexus3.rootPassword.secret: null` could in principle have severed the
passthrough that 23-04 and 23-06 both depend on. The subchart consumes it in
`nexus3/templates/statefulset.yaml` lines 221-232, guarded on `{{- if .Values.rootPassword.secret }}`.
Both branches were driven:

| Render | `NEXUS_SECURITY_*` env produced |
|---|---|
| default (no override) | `NEXUS_SECURITY_RANDOMPASSWORD: "true"` — Nexus self-generates |
| `--set nexus3.rootPassword.secret=dummy-secret-name` | `RANDOMPASSWORD: "false"` plus `NEXUS_SECURITY_INITIAL_PASSWORD` from `secretKeyRef{name: dummy-secret-name, key: password}` |

The `key: password` in that output comes from this plan's `nexus3.rootPassword.key`, so both halves
of the credential wiring are confirmed to pass through the explicit null.

### Lockfile reproducibility

```
sha256 before  e47791e668e29e6f2242a81630259ae59e852219776ee55c4df0f3d17a918e4f
rm -rf kubernetes/nexus/charts && helm dependency build kubernetes/nexus
sha256 after   e47791e668e29e6f2242a81630259ae59e852219776ee55c4df0f3d17a918e4f
git status --short -> empty  (Chart.lock not rewritten)
```

The subchart's own `Chart.yaml` reports `appVersion: 3.96.0`, matching the wrapper's `appVersion: "3.96.0"` — so the `app.kubernetes.io/version` label `nexus.labels` stamps agrees with the image the subchart actually pulls at this pin. That agreement is not structural: D-08 lets the image float, so a future subchart bump will move the image without moving the wrapper's `appVersion`. Whoever bumps `Chart.lock` should bump `appVersion` too.

### Gate and regression status

| Command | Result |
|---|---|
| `helm lint kubernetes/nexus --set nexus3.rootPassword.secret=dummy-secret-name` | exit 0, `1 chart(s) linted, 0 chart(s) failed` |
| `bash scripts/check-nexus-chart.sh` | exit 0, **`SKIP: chart incomplete — kubernetes/nexus/templates/job-provision.yaml does not exist yet`** |
| `bash scripts/nexus-live-smoke.sh` | exit 0, `NOTHING RAN - 0 live check(s) executed` (no regression) |
| `pre-commit run --all-files` | exit 0, before each of the three commits |
| `yamllint -d relaxed kubernetes/nexus/values.yaml` | exit 0 |

The gate's message is guard **2**, not guard 1 — it proves the chart directory now exists and the gate advanced past it, exactly as the plan's acceptance criterion specifies.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `helm repo add` errors when the repo name already exists**

- **Found during:** Task 1
- **Issue:** This workstation already has 25 Helm repositories configured. The plan's bare `helm repo add stevehipwell …` would have exited non-zero on a name collision.
- **Fix:** Ran it with `--force-update`. Output: `"stevehipwell" has been added to your repositories`. No substitution of repository or version was made — the URL and version are exactly as the plan specifies.
- **Files modified:** none (workstation Helm config only).

**2. [Rule 1 — Bug in the plan's own assertion] Two keys had to be written as explicit `null`**

- **Found during:** Task 2 verification
- **Issue:** The plan's action text asks for `nexus3.rootPassword.secret` and `repos.helm.remoteUrl` to be present as keys "with no value", i.e. the upstream bare-key style. Its acceptance criteria assert `yq` reports `null` for both. **Measured:** yq v4.53.6 prints an *empty string* for a bare `key:` and `null` only for a missing or explicitly-`null` key (probed on a throwaway file: bare `b:` → `[]`, missing `z` → `[null]`, literal `null` → `[null]`). Written bare, the plan's own `<verify>` block would have failed.
- **Fix:** Both are written `key: null`. Identical YAML value, key still present, and `yq` now reports `null`. A two-line comment at each site records why, so a future editor does not "tidy" them back to the bare form.
- **Files modified:** `kubernetes/nexus/values.yaml` — **Commit:** `8c58dba`

### Divergences from the plan text (deliberate, with reasons)

**1. Task 3's acceptance claim that this commit proves the 23-01 yamllint exclusion is not true, and the SUMMARY says so rather than repeating it.**
The criterion reads *"this is the first commit containing a file under `kubernetes/nexus/templates/`, so it is also the live proof that plan 23-01's yamllint exclusion works."* **Measured:** `identify` tags `_helpers.tpl` as `['file', 'non-executable', 'text']` — there is no `yaml` tag, so the yamllint hook's `types: [yaml]` never selects it, with or without the exclusion. `pre-commit run yamllint --files kubernetes/nexus/templates/_helpers.tpl` reports `(no files to check) Skipped`. `pre-commit run --all-files` does exit 0, but that is not evidence about the exclusion. **The real proof arrives in 23-04**, which lands `templates/*.yaml` Go templates — the file type 23-01 measured yamllint exiting 1 on.

**2. No `checkpoint:human-verify` before the first `helm dependency build`.**
23-RESEARCH.md §Package Legitimacy Audit recommends one, because chart-repo additions are covered by no existing gate in `security-platform`. Plan 23-03 omits it and is marked `autonomous: true`. That omission is correct and was followed: D-01 REVISED is an explicit, recorded user decision to adopt this specific community chart after the audit, taken because every Sonatype-published alternative is deprecated. The research recommendation predates that decision and is superseded by it. **No package-manager install occurred** — the executor's Rule 3 install exclusion does not apply to a `helm dependency build` against a repository and version named verbatim in the plan.

**3. No `nexus.chart` helper.** `helm.sh/chart` is built inline inside `nexus.labels`. The plan specifies four named templates and its `<verify>` loops over exactly those four names; a fifth define would be undeclared surface.

**4. `requirements.mark-complete` deliberately not invoked; `requirements-completed: []`.** See key-decisions. NEXUS-03 is implemented and measured here, but the chart is not yet installable as a whole and the phase's gate cannot assert it until 23-04. 23-08 carries both IDs and is the right place to mark.

## Observations Handed Forward

1. **Contracts 23-04 can rely on, verified here.** `nexus.fullname` at release `t` is `t-nexus`, so the objects 23-04 creates will be `t-nexus-provision-script`, `t-nexus-repos` (the `-repos` suffix 23-02 binds on) and `t-nexus-provision`. `include "nexus.nexus3Fullname" .` is the Service host — `nexus3.serviceName` is defined as literally `include "nexus3.fullname"`, so the two are the same string, confirmed by render.
2. **The subchart renders TWO Services** — `<fullname>` and `<fullname>-hl` (headless). The Job must target the non-headless one, which is what `nexus.nexus3Fullname` returns. Any future check that selects "the Service" by `kind` alone will get two documents back.
3. **The subchart's own `config.enabled` already defaults to `false`.** Our restatement in `values.yaml` is not a behaviour change — it exists so the `CONFIG-DISABLED` check has something to read and so an upstream default flip cannot silently enable the Groovy scripting API. The same is true of `config.anonymous.enabled`.
4. **`helm dependency build` needs network and refreshes every configured repo.** On this workstation it refreshed 25 repositories (~20s), including one unrelated 404 (`kubernetes-dashboard`) that did **not** fail the command — the same observation 23-02 recorded. Any CI wiring must budget for this.
5. **`appVersion` and the image can drift apart.** They agree today (both 3.96.0). D-08 makes the image float with the subchart, while the wrapper's `appVersion` is a hand-maintained literal that feeds `app.kubernetes.io/version`. Bumping `Chart.lock` without bumping `appVersion` produces a label that lies. Worth a Renovate/Dependabot rule or a gate check in a later phase — flagged, not fixed, as D-08 already anticipated.
6. **Without a consumer Secret the subchart sets `NEXUS_SECURITY_RANDOMPASSWORD: "true"`** — Nexus self-generates an admin password nobody holds. That is the state a bare install lands in today, and it is exactly what 23-04's `required` guard on `nexus3.rootPassword.secret` must make unreachable. The guard is not cosmetic: without it the chart installs green and is unusable.
7. **Helm here is v4.3.0 and caps release names at 53 characters.** Inherited from 23-01's observation; noted again because it makes the `trunc 63` in both fullname helpers unreachable via the release name.

## Threat Model Coverage

| Threat ID | Disposition | How this plan mitigates it | Status |
|---|---|---|---|
| T-23-02 | mitigate | `nexus3.rootPassword.secret` is a Secret **name** with no default; no literal password key anywhere; credential grep measured 0. The render-time `required` guard is 23-04's half of the mitigation and is not yet in place — a bare `helm template` currently succeeds, by construction. | ✅ values half implemented + measured; render guard owed by 23-04 |
| T-23-03 | mitigate | `nexus3.config.enabled: false` shipped as an explicit default with the `nexus.scripts.allowCreation=true` rationale in the comment; the property is emitted nowhere | ✅ implemented |
| T-23-05 | mitigate | `eula.accepted: false` (D-09), EULA URL carried in the comment together with the measured 403 consequence; nothing in this plan accepts the agreement | ✅ implemented |
| T-23-04 | mitigate | `repos.*.remoteUrl` are declarative values only at this commit; the `toJson` rendering obligation is 23-04's | ✅ as designed |
| T-23-SC | mitigate | `Chart.lock` pins nexus3 5.26.0 by version **and digest**, and the pin was proven reproducible (byte-identical rebuild). Both helper images are digest-pinned to the values measured in 23-RESEARCH.md. No package-manager install occurred. | ✅ implemented + measured |
| T-23-09 | mitigate | `nexus3.persistence.enabled: true` (D-10), and the render was checked to confirm a real `volumeClaimTemplate` is produced rather than an `emptyDir` | ✅ implemented + measured |

## Known Stubs

None. `nexus3.rootPassword.secret: null` and `repos.helm.remoteUrl: null` are **intentional absent-by-design defaults** (T-23-02 and D-05 respectively), not placeholders: shipping a value for either would itself be the defect. Both carry comments explaining what the consumer must supply. The chart is incomplete only in the sense the phase plan intends — the provisioning Job and its two ConfigMaps are plan 23-04's deliverable, which is why `check-nexus-chart.sh` correctly still reports `SKIP: chart incomplete`.

## Threat Flags

None. No new network endpoint, auth path or file-access pattern was introduced by this plan. The one new trust-boundary surface — a dependency on a third-party chart repository — is T-23-SC, already in the register, and it is pinned by version and digest in a committed lockfile whose reproducibility was measured.

## Self-Check: PASSED

- `repos/security-platform/kubernetes/nexus/Chart.yaml` — FOUND (9 lines)
- `repos/security-platform/kubernetes/nexus/Chart.lock` — FOUND, pins nexus3 5.26.0
- `repos/security-platform/kubernetes/nexus/.helmignore` — FOUND (33 lines, 0 occurrences of `charts`)
- `repos/security-platform/kubernetes/nexus/values.yaml` — FOUND (153 lines)
- `repos/security-platform/kubernetes/nexus/templates/_helpers.tpl` — FOUND (75 lines, all four defines)
- Commit `2af546f` — FOUND on `feature/phase-23-nexus-generic-chart`
- Commit `8c58dba` — FOUND on `feature/phase-23-nexus-generic-chart`
- Commit `31f110f` — FOUND on `feature/phase-23-nexus-generic-chart`
- `git ls-files kubernetes/nexus` — exactly the five required paths, working tree clean
