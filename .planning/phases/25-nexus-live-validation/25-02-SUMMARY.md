---
phase: 25-nexus-live-validation
plan: 02
subsystem: occ-k8s-app-config overlay / Argo CD AppProject authorisation
tags: [nexus, argocd, appproject, allowlist, homelab, overlay]
requires: []
provides:
  - "Live `platform` AppProject admitting sourceRepo https://github.com/OttawaCloudConsulting/security-platform, destination nexus, and kinds apps/StatefulSet, batch/Job, bitnami.com/SealedSecret"
  - "Four operator-approved overlay values plus the confirmed homelab kube context, for plan 25-03 to read"
affects: [25-03, 25-04, 25-05]
tech-stack:
  added: []
  patterns:
    - "Shared-AppProject widening lands as its own PR, before any Application references it, so ArgoCD never raises a transient InvalidSpecError"
    - "Additions-only proof = jq set difference of live before and after `.spec` captures, per key"
key-files:
  created: []
  modified:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/automation/argocd/templates/projects.yaml
decisions:
  - "Operator replied approve-defaults: amend the shared platform AppProject (L-02) and accept all four proposed overlay values"
  - "targetRevision pinned to the security-platform main SHA aed14b916e9aa8ec1d0d47699b457040b99f7eac, not to `main` (ADR-004 pinning habit / overlay R23)"
  - "The unscoped ''/Namespace clusterResourceWhitelist entry is left byte-unchanged; narrowing it would revoke CreateNamespace for the other platform members"
metrics:
  duration: "~25 min (continuation; Task 1 by the prior executor)"
  completed: 2026-09-23
  tasks: 3
  files: 1
---

# Phase 25 Plan 02: platform AppProject amendment for Nexus Summary

The shared `platform` AppProject now admits the Nexus workload. It allows the `security-platform` source repo, the `nexus` destination, and the `apps/StatefulSet`, `batch/Job` and `bitnami.com/SealedSecret` kinds. The change landed through overlay PR #239: the required `conformance` check passed, the PR was merged with `--merge` (merge commit `7b7e25c`), and the change is confirmed live on `admin@occ-new`. The live before/after diff shows exactly five additions and zero removals.

## Values for plan 25-03 (read these; do not re-derive)

| Item | Value |
|------|-------|
| Homelab kube context | `admin@occ-new` (`kubectl config current-context` returned it at continuation time) |
| Canonical `sourceRepos` / `sources[0].repoURL` string (byte-identical) | `https://github.com/OttawaCloudConsulting/security-platform` |
| `repos.helm.remoteUrl` | `https://charts.jetstack.io` |
| Nexus PVC | chart default `8Gi` on the cluster default StorageClass `default` (provisioner `csi.trident.qnap.io`, reclaim `Delete`, `WaitForFirstConsumer`, expansion `true`) |
| `sources[0].targetRevision` | `aed14b916e9aa8ec1d0d47699b457040b99f7eac` (security-platform `main` at checkpoint time; re-read with `git ls-remote` at 2026-09-23 and still the same) |
| `syncPolicy.retry` | `limit: 5`, `backoff.duration: 30s`, `backoff.factor: 2`, `backoff.maxDuration: 10m` |
| `kubeseal --version` | `kubeseal version: v0.40.0` |
| Unambiguous Application resource name on this cluster | `applications.argoproj.io` (crossplane azuread also defines an `Application` CRD) |

## Task 2 decision (checkpoint:decision)

Operator's verbatim reply: **"approve-defaults"**

This reply authorised pushing, opening and merging the `platform` widening, and fixed the four values above.

## Commits

| Task | Repo | Commit | Description |
|------|------|--------|-------------|
| 1 | occ-k8s-app-config | `1d58250` | feat(nexus): allow StatefulSet, Job, SealedSecret, nexus ns and security-platform repo in platform AppProject (+27/-0, one file) |
| 2 | none | none | checkpoint:decision, resolved `approve-defaults` |
| 3 | occ-k8s-app-config | `7b7e25cfb2d90f10059ab8fa8cd6a9d32a3d8ce3` | Merge of PR #239 (`--merge`, head `1d58250`) |

## Task 3 evidence

- PR: https://github.com/OttawaCloudConsulting/occ-k8s-app-config/pull/239, state `MERGED`
- `gh pr checks 239`: `conformance  pass  23s` (run 35939157366); GitGuardian also passed
- Protection facts come from `gh api repos/OttawaCloudConsulting/occ-k8s-app-config/rules/branches/main`. It returned the rules deletion, non_fast_forward, pull_request (0 approvals, `require_extra_approval_for_unattributed_changes: true`, all merge methods) and required_status_checks (`conformance`). `branches/main/protection` was not consulted.
- Argo CD `argocd` Application: `Synced` / `Healthy` at revision `7b7e25c`. The project reconciled on its own, so the `argocd.argoproj.io/refresh` annotation was not needed. My first 9x20s poll loop printed no match, most likely because it ran before the sync landed. A direct read immediately afterwards showed the additions live, and every assertion below comes from that read.
- The plan's three `jq -e` assertions against the live cluster all exit 0: sourceRepos index `3`, exactly one `nexus` destination, and all three kinds present.
- Before/after set difference (live captures, per key):
  - removed: `{"sourceRepos":[],"destinations":[],"crw":[],"nrw":[]}`
  - added: sourceRepos `https://github.com/OttawaCloudConsulting/security-platform`; destinations `{name: in-cluster, namespace: nexus, server: https://kubernetes.default.svc}`; nrw `apps/StatefulSet`, `batch/Job`, `bitnami.com/SealedSecret`; crw none
  - `clusterResourceWhitelist` compact-JSON `diff` between the captures: IDENTICAL
- No `application-sets/security/` directory exists on overlay `origin/main` (L-02).

Post-merge live `.spec` (jq -S, compact):

```json
{"clusterResourceWhitelist":[{"group":"","kind":"Namespace"},{"group":"apiextensions.k8s.io","kind":"CustomResourceDefinition"},{"group":"admissionregistration.k8s.io","kind":"ValidatingWebhookConfiguration"},{"group":"admissionregistration.k8s.io","kind":"ValidatingAdmissionPolicy"},{"group":"admissionregistration.k8s.io","kind":"ValidatingAdmissionPolicyBinding"},{"group":"admissionregistration.k8s.io","kind":"MutatingWebhookConfiguration"},{"group":"rbac.authorization.k8s.io","kind":"ClusterRole"},{"group":"rbac.authorization.k8s.io","kind":"ClusterRoleBinding"}],"destinations":[{"name":"in-cluster","namespace":"admission-policies","server":"https://kubernetes.default.svc"},{"name":"in-cluster","namespace":"kube-system","server":"https://kubernetes.default.svc"},{"name":"in-cluster","namespace":"reloader","server":"https://kubernetes.default.svc"},{"name":"in-cluster","namespace":"argo","server":"https://kubernetes.default.svc"},{"name":"in-cluster","namespace":"authentik","server":"https://kubernetes.default.svc"},{"name":"in-cluster","namespace":"homepage","server":"https://kubernetes.default.svc"},{"name":"in-cluster","namespace":"cnpg-system","server":"https://kubernetes.default.svc"},{"name":"in-cluster","namespace":"nexus","server":"https://kubernetes.default.svc"}],"namespaceResourceWhitelist":[{"group":"apps","kind":"Deployment"},{"group":"cert-manager.io","kind":"Certificate"},{"group":"cert-manager.io","kind":"Issuer"},{"group":"networking.k8s.io","kind":"NetworkPolicy"},{"group":"rbac.authorization.k8s.io","kind":"Role"},{"group":"rbac.authorization.k8s.io","kind":"RoleBinding"},{"group":"","kind":"ConfigMap"},{"group":"","kind":"Secret"},{"group":"","kind":"Service"},{"group":"","kind":"ServiceAccount"},{"group":"apps","kind":"StatefulSet"},{"group":"batch","kind":"Job"},{"group":"bitnami.com","kind":"SealedSecret"}],"sourceRepos":["https://github.com/OttawaCloudConsulting/occ-k8s-app-config","ghcr.io/cloudnative-pg/charts","oci://ghcr.io/cloudnative-pg/charts","https://github.com/OttawaCloudConsulting/security-platform"]}
```

## Deviations from Plan

- **Member-app count:** the plan says six other `platform` members, but five were measured: admission-policies, cloudnative-pg, homepage, pod-identity-webhook and reloader. The PR body names these five.
- **Overlay base moved:** planning read overlay `main` at `6a8f2b2`; the branch was cut from `ac580a4`. The PR touches none of the changed lines.
- **Resource name:** use `applications.argoproj.io` instead of the plan's bare `application`, because the bare name is ambiguous on this cluster. The refresh annotation turned out to be unnecessary.

Otherwise the plan was executed as written. `''/ServiceAccount`, `''/ConfigMap`, `''/Service` and `''/Secret` were already present, so none was added.

## Known Stubs

None.

## Self-Check: PASSED

- Overlay commit `1d58250` exists and is the PR #239 head; merge commit `7b7e25c` is on overlay `main` and is the `argocd` app's synced revision
- `projects.yaml` is the only file in the PR diff (`git diff origin/main feat/nexus-appproject-platform --name-only`, run before push)
- The live `platform` AppProject carries all five additions with zero removals (jq set difference above)
