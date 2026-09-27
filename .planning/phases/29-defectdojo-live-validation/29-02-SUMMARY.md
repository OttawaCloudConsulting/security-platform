---
phase: 29-defectdojo-live-validation
plan: 02
subsystem: k8s-overlay
tags: [defectdojo, arc, argocd, appproject, occ-k8s-app-config, ddojo-05]
requires: []
provides:
  - "Live `platform` AppProject admits destinations defectdojo, arc-systems, arc-runners"
  - "Live `platform` AppProject sourceRepos include ghcr.io/actions/actions-runner-controller-charts (scheme-less and oci://)"
  - "Live `platform` namespaceResourceWhitelist includes policy/PodDisruptionBudget and actions.github.com/AutoscalingRunnerSet"
  - "Confirmed homelab kube context: admin@occ-new"
affects: [29-05, 29-07, 29-12, 29-13]
tech-stack:
  added: []
  patterns:
    - "AppProject allowlist entries enumerated from fresh `helm template --include-crds` renders, never copied from research"
    - "AppProject PR merged and confirmed live before any Application directory references it (Phase 25 PR-1 precedent)"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-02-appproject-before.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-02-appproject-after.json
    - .planning/phases/29-defectdojo-live-validation/evidence/29-02-rendered-kinds.txt
  modified:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/automation/argocd/templates/projects.yaml
decisions:
  - "Homelab kube context is admin@occ-new (matches 25-02-SUMMARY). Every later Phase 29 plan uses it."
  - "The renders used --include-crds because Argo CD applies chart crds/ by default. This surfaced the ARC CustomResourceDefinitions, and the live clusterResourceWhitelist already admits them."
  - "''/Pod is not admitted: defectdojo-unit-tests is a helm test-success hook that Argo CD skips. ''/PersistentVolumeClaim is not admitted because the StatefulSet controller creates PVCs. ''/Secret was already admitted."
  - "clusterResourceWhitelist is byte-unchanged. The jq -S diff of before vs after is empty."
  - "The PR was merged with --merge (merge commit), matching the repo's `Merge pull request #N` history and the operator's instruction."
  - "DDOJO-05 is not marked complete; plan 29-19 does that."
metrics:
  duration: "~35min (Task 1 renders to live confirmation)"
  completed: 2026-09-27
  tasks: 3
  files: 4
---

# Phase 29 Plan 02: Platform AppProject amendment for DefectDojo and ARC Summary

The shared `platform` AppProject now admits the three Phase 29 Applications (`defectdojo`, `arc-systems`, `arc-runners`). It also admits both spellings of the ARC OCI chart repository and two new namespaced kinds, `policy/PodDisruptionBudget` and `actions.github.com/AutoscalingRunnerSet`. Both kinds were enumerated from fresh renders. The change merged as occ-k8s-app-config PR #246 after the operator approved it and `conformance` went green. The live project read confirmed it on `admin@occ-new` before any Application references it.

## Homelab context (read by every later Phase 29 plan)

- **Context:** `admin@occ-new`. Resolved via `kubectl config current-context`, which matches the value recorded in 25-02-SUMMARY. Reachability was confirmed in Task 1 via `kubectl --context admin@occ-new -n argocd get applicationset appset-apps -o name`.
- `KUBECONFIG` was never set.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Measure live project + three chart renders, author enumerated amendment | overlay `ee35cfb`; docs repo `ee323c0` | projects.yaml; evidence/29-02-appproject-before.json; evidence/29-02-rendered-kinds.txt |
| 2 | Operator authorises the shared platform AppProject amendment | (decision, no commit) | none |
| 3 | Push, pass conformance, merge, read the live AppProject | overlay merge `e965581`; docs repo: this plan's metadata commit | evidence/29-02-appproject-after.json |

## Operator decision (Task 2)

The operator was shown the literal diff (+43/-1, projects.yaml only, `platform` block only), the rendered-kinds file, the kinds deliberately not added and the rollback (revert the PR). The operator replied verbatim:

```
approve
```

## Overlay PR

- **PR:** https://github.com/OttawaCloudConsulting/occ-k8s-app-config/pull/246
- **Title:** `feat(defectdojo): Phase 29 / DDOJO-05 admit defectdojo and ARC apps in platform AppProject`
- **Branch:** `feat/defectdojo-arc-appproject-platform` (feature commit `ee35cfb`)
- **Pre-push check:** `git fetch origin` showed origin/main still at `4ee013a`, an ancestor of the branch, so no rebase was needed. `git diff origin/main HEAD` was unchanged from Task 1 (1 file, +43/-1).
- **Checks:** `conformance` passed in 19s; GitGuardian Security Checks passed.
- **Merge:** `gh pr merge 246 --merge` → state `MERGED`, merge commit `e965581c75574df18d23137bdf7d5fba06684cb1`, merged at 2026-09-27T13:35:30Z.
- **Live confirmation:** the entries appeared on the 7th 30s poll of `kubectl --context admin@occ-new -n argocd get appprojects.argoproj.io platform -o json`, about 3 minutes after the merge.
- **Overlay clone:** back on `main` at `e965581`, equal to `origin/main` (via `checkout main && pull --ff-only`). The operator's untracked files were left untouched.

## Entries added (live, verified from 29-02-appproject-after.json)

| Field | Added | Before → after count |
| ----- | ----- | -------------------- |
| sourceRepos | `ghcr.io/actions/actions-runner-controller-charts`, `oci://ghcr.io/actions/actions-runner-controller-charts` | +2 |
| destinations | `defectdojo`, `arc-systems`, `arc-runners` (server `https://kubernetes.default.svc`, name `in-cluster`) | +3 |
| namespaceResourceWhitelist | `policy/PodDisruptionBudget`, `actions.github.com/AutoscalingRunnerSet` | +2 |
| clusterResourceWhitelist | none: `jq -S` diff of before vs after is empty | 0 |
| description | appended `defectdojo, arc-systems, arc-runners` | n/a |

Checks run on the after file:
- `https://github.com/OttawaCloudConsulting/security-platform` appears exactly once in sourceRepos.
- `''/Pod` count in namespaceResourceWhitelist: 0.
- Every before-state entry in sourceRepos, destinations, namespaceResourceWhitelist and clusterResourceWhitelist is present in the after-state: 0 missing. Nothing was narrowed or removed.
- The plan's Task 3 automated verify (the AutoscalingRunnerSet entry and all three destinations) passes.

## Kinds deliberately NOT added

- `''/Pod`: `defectdojo-unit-tests` is a `helm.sh/hook: test-success` hook, which Argo CD skips.
- `''/PersistentVolumeClaim`: the StatefulSet controller creates these from `volumeClaimTemplates`.
- `''/Secret`: already admitted in the before-state.
- ARC runtime objects (EphemeralRunnerSet, EphemeralRunner, listener and runner Pods): the controller creates these; Argo CD never applies them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Renders used `--include-crds`**
- **Found during:** Task 1
- **Issue:** The plan's `helm template` commands omit chart `crds/`, but Argo CD applies them by default. Without the flag, the kind enumeration would miss the ARC CustomResourceDefinitions.
- **Fix:** Added `--include-crds` to all three renders and recorded it in the rendered-kinds header and the projects.yaml comment. The CRDs are cluster-scoped and already admitted, so clusterResourceWhitelist stayed unchanged.
- **Files modified:** evidence/29-02-rendered-kinds.txt, projects.yaml (comment only)
- **Commit:** overlay `ee35cfb`, docs `ee323c0`

**2. [Rule 3 - Blocking] ARC OCI `helm` pulls hung on the Docker Desktop credential helper**
- **Found during:** Task 1
- **Issue:** `~/.docker/config.json` sets `credsStore: desktop`, which made the anonymous `helm` OCI pulls from ghcr.io hang. The orchestrator killed the hung helm process.
- **Fix:** The documented workaround is an empty `DOCKER_CONFIG` directory plus a scratchpad `--registry-config`, set per command. The operator's Docker configuration was not modified. The ARC renders did complete, and the pulled chart digests are recorded in the rendered-kinds file. This continuation agent did not observe the exact invocation Task 1 used, so the invocation is recorded here as reported rather than as verified.
- **Files modified:** none (per-command environment only)

### Other notes

- The docs-repo commit `ee323c0` (Task 1 evidence) lacks the Co-Authored-By/Claude-Session trailers. It was left as is so history is not rewritten.
- The overlay CLAUDE.md describes squash merges. This PR used `--merge` as the plan and the operator's instruction specified. The next overlay branch is cut fresh from the updated `main`, so no graph divergence results.

## Threat model

- T-29-10 (EoP, AppProject widening): mitigated. Kinds are enumerated with no wildcards, clusterResourceWhitelist is proven unchanged, `''/Pod` is excluded and the operator gated the merge.
- T-29-11 (Tampering, ARC OCI source): mitigated. sourceRepos are limited to `ghcr.io/actions/actions-runner-controller-charts` (both spellings), and the version pin to 0.14.2 lands with plans 29-12/29-13.

## Known Stubs

None.

## Next

Plan 29-04. Plans 29-05, 29-07, 29-12 and 29-13 can add Application directories that the live `platform` project already admits.

## Self-Check: PASSED

- FOUND: 29-02-SUMMARY.md, evidence/29-02-appproject-after.json (plus the before and rendered-kinds evidence from Task 1)
- FOUND commits: overlay ee35cfb, overlay merge e965581, docs ee323c0
- PR #246 state: MERGED
