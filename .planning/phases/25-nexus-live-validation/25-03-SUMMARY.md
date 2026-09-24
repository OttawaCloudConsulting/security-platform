---
phase: 25-nexus-live-validation
plan: 03
subsystem: occ-k8s-app-config overlay / Argo CD Application for Nexus
tags: [nexus, argocd, appset-apps, sealed-secrets, overlay, homelab]
requires:
  - "25-02: live platform AppProject admitting security-platform, nexus destination, StatefulSet/Job/SealedSecret"
provides:
  - "Open PR #241 on occ-k8s-app-config adding application-sets/platform/nexus/ (green conformance, unmerged), for 25-04 to merge"
  - "SealedSecret nexus/nexus-admin (key password) carrying a randomly generated Nexus admin password"
affects: [25-04, 25-05, 25-07]
tech-stack:
  added: []
  patterns:
    - "Two-source Application via argocd-overrides.yaml: SHA-pinned public git chart plus a local manifests chart for the wave -1 SealedSecret"
    - "Password generated straight into a scratchpad env file (umask 077), sealed through scripts/seal-secret.sh, env file deleted immediately; plaintext never on stdout or in any repo"
key-files:
  created:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/nexus/argocd-overrides.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/nexus/Chart.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/nexus/README.md
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/nexus/templates/sealedsecret-nexus-admin.yaml
  modified:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/.gitleaksignore
decisions:
  - "sources[0].targetRevision pinned to security-platform main aed14b916e9aa8ec1d0d47699b457040b99f7eac (re-read by git ls-remote at execution time, unchanged since 25-02)"
  - "Sealing used CONTROLLER_NAMESPACE=sealed-secrets: the live controller is sealed-secrets/sealed-secrets, not the script default kube-system"
  - "The overlay work landed as two commits (Task 1 files, then argocd-overrides.yaml), not the plan's single Task 3 commit. The plan's commit message is used for the override commit"
metrics:
  duration: "~20 min"
  completed: 2026-09-23
  tasks: 3
  files: 5
---

# Phase 25 Plan 03: platform/nexus overlay directory (PR 2) Summary

`application-sets/platform/nexus/` is written and open as overlay PR #241. The required `conformance` check passed and the PR is deliberately unmerged. The directory's `argocd-overrides.yaml` generates the two-source Application `nexus` (namespace `nexus`, project `platform`). Source 1 is the public security-platform `kubernetes/nexus` chart, pinned to a commit SHA. Source 2 is this directory, which holds the admin password as a wave -1 SealedSecret.

## Values for plan 25-04 (read these; do not re-derive)

| Item | Value |
|------|-------|
| PR | https://github.com/OttawaCloudConsulting/occ-k8s-app-config/pull/241, number **241**, state `OPEN` |
| PR head SHA | `f65c2dc786ebc19b2f6a422fdc0d6c8cac2f68b2` (branch `feat/nexus-app-directory`, based on overlay `origin/main` `f2452de`) |
| `conformance` conclusion | `pass` (21s, run 35940547567). GitGuardian also passed. |
| `sources[0].targetRevision` | `aed14b916e9aa8ec1d0d47699b457040b99f7eac` |
| Kube context | `admin@occ-new` (re-confirmed via `kubectl config current-context`) |
| Admin credential | Secret `nexus/nexus-admin`, key `password`. Retrieve with `kubectl --context admin@occ-new -n nexus get secret nexus-admin -o jsonpath='{.data.password}' \| base64 -d` |
| Service / port-forward | `svc/nexus-nexus3` on port 8081 (a local render at the pinned SHA confirmed both) |
| Sealed-secrets controller | `sealed-secrets/sealed-secrets` (namespace `sealed-secrets`) |

## Preflight evidence

- **Generator baseline (A):** `appset-apps` was read live with `applicationsets.argoproj.io`. It matches research on every point:
  - glob `application-sets/*/*/argocd-overrides.yaml`
  - name `{{.path.basename}}`
  - `destination.namespace` `{{.path.basename}}`
  - project `{{ index .path.segments 1 }}`
  - syncPolicy `automated {prune: true, selfHeal: true}`, syncOptions `[CreateNamespace=true, ApplyOutOfSyncOnly=true]`
  - generator `preserveResourcesOnDeletion: true`

  There was no divergence.
- **Sealing toolchain (B):** `command -v kubeseal` returned `/opt/homebrew/bin/kubeseal`, and `kubeseal version: v0.40.0` matches `25-02-SUMMARY.md`. `scripts/seal-secret.sh` defaults `CONTROLLER_NAMESPACE` to `kube-system`, but `kubectl --context admin@occ-new -n kube-system get deploy sealed-secrets` returned NotFound. The live controller is `sealed-secrets/sealed-secrets`, 1/1 ready, and `scripts/.env.example` also sets `CONTROLLER_NAMESPACE=sealed-secrets`.

## Task results

- **Task 1:**
  - `helm template nexus application-sets/platform/nexus` exits 0 and renders exactly one resource. That resource is `SealedSecret nexus-admin nexus`, with template name `nexus-admin`, template namespace `nexus`, `type: Opaque`, and sync-wave `"-1"` (a string).
  - `Chart.yaml` has no `dependencies:` block (`grep -c` returns 0).
  - yamllint and markdownlint passed.
- **Gitleaks:**
  - The scoped baseline `--source application-sets` found 0 before the file was added and 1 after: `application-sets/platform/nexus/templates/sealedsecret-nexus-admin.yaml:generic-api-key:28`. Line 28 is `password:` under `spec.encryptedData`, which is ciphertext.
  - That fingerprint was taken from the final, fully commented file and pinned as exactly one new `.gitleaksignore` line, under a Phase 25 / NEXUS-05 comment. The scoped re-scan then found 0.
  - The CI form, repo-root `gitleaks detect --source . --no-git --redact` run on a clean `git archive HEAD` extract, exited 0.
- **Plaintext check:** `grep -rn password` in the directory matches only key names (`key: password`, `.data.password` in the retrieval command, the README table) and the ciphertext line. There is no plaintext credential. The generated password was written only into a scratchpad env file (umask 077) that was deleted right after sealing, together with `tmp/sealed-secrets/`. It never appeared on stdout, in shell history or in any repo. `seal-secret.sh` does pass it briefly as a `--from-literal` argument to a client-side `kubectl create secret --dry-run=client`, which puts it in that process's argv. That is inherent to the repo's helper.
- **Task 2:**
  - `c1.py` passes (20 files).
  - `check_appconfig.py --base origin/main` passes, including 14b. It was re-run after staging, when it counted 21 applications (nexus included). The first run counted 20 because the file was still untracked.
  - yamllint passes, and every `yq` assertion in the plan holds: `has("source")` is true while `source` is null, there are 2 sources, no project or destination is set, `retry` sits under `syncPolicy` and `spec.retry` is absent, `automated` has `$patch: replace` plus all three keys, `syncOptions` equals the live baseline, and there is exactly one override file.
  - `grep -c ServerSideApply` and `grep -ci 'ingress\|gateway'` both return 0 on the override file.
  - `targetRevision` is a 40-character hex SHA and equals `git ls-remote … refs/heads/main | cut -f1`.
  - `scripts/discover_apps.py` lists `helm	application-sets/platform/nexus` in the render matrix.
- **Task 3:** the PR contains exactly the five intended paths and nothing under `application-sets/security/` (L-02). The plan's `<verify>` block printed `TASK3-VERIFY-OK PR=241`.

## Commits

| Task | Repo | Commit | Description |
|------|------|--------|-------------|
| 1 | occ-k8s-app-config | `684100f` | feat(nexus): add platform/nexus chart metadata, README and sealed admin credential (NEXUS-05) |
| 2 | occ-k8s-app-config | `f65c2dc` | feat(nexus): add platform/nexus application directory for the security-platform Nexus chart (NEXUS-05) |
| 3 | occ-k8s-app-config | none | pushed `feat/nexus-app-directory`, opened PR #241, left it unmerged |

Both commits used the `OCC <60020004+OttawaCloudConsulting@users.noreply.github.com>` identity, and the pre-commit hooks passed (yamllint, markdownlint, c1, check_appconfig).

## Deviations from Plan

1. **[Rule 3 - Blocking] Sealed-secrets controller namespace.** The plan suggested `kube-system` (the script default), but the live install is in `sealed-secrets`. The scratchpad `SEAL_ENV` set `CONTROLLER_NAME=sealed-secrets` and `CONTROLLER_NAMESPACE=sealed-secrets`. The plan anticipated this ("do not assume the default matches the live install").
2. **Commit granularity.** The plan puts one overlay commit in Task 3. I made one commit per task instead (Task 1 files, then the override file), and the plan's commit message went on the override commit. The PR diff is the same five files either way.
3. **kubeseal context.** `seal-secret.sh` calls `kubeseal` without `--context`, so it used the ambient context. I asserted `kubectl config current-context == admin@occ-new` in the same shell immediately before sealing. Every direct `kubectl` call passed `--context admin@occ-new`.
4. **SealedSecret wave comment.** The plan text says the provisioning Job is "wave-0". Rendering the pinned chart shows `Job nexus-provision` is a Helm `post-install,post-upgrade` hook, which Argo CD maps to PostSync, so the comment says that. The StatefulSet has no wave annotation, which puts it at wave 0.
5. **Overlay base moved.** 25-02 recorded overlay `main` at `7b7e25c`. The branch was cut from `f2452de` (PR #240, identity LDAP split), which touches no nexus path.

## Notes for 25-04

- **Subchart build at render time.** At `aed14b9`, the `kubernetes/nexus/charts/*.tgz` subchart tarball is gitignored upstream. The Argo CD repo-server must therefore run `helm dependency build` against `https://stevehipwell.github.io/helm-charts/` when it first renders the chart (`Chart.lock` digest `sha256:24ad740d…`). A local `helm dependency build` + `helm template` at the pinned SHA with the four override values worked. If the first sync shows a ComparisonError, check this first.
- **Hook cleanup.** The provisioning Job is a PostSync hook, and its default `BeforeHookCreation` delete policy applies as the plan describes.

## Known Stubs

None.

## Threat Flags

None beyond the plan's register: T-25-12 through T-25-15 were mitigated as specified, and T-25-16 and T-25-17 were accepted as recorded.

## Self-Check: PASSED

- All four new files exist on overlay branch `feat/nexus-app-directory`, and the `.gitleaksignore` entry is present
- Commits `684100f` and `f65c2dc` exist, and `f65c2dc` is the PR #241 head
- PR #241 is `OPEN` with `conformance` passing
