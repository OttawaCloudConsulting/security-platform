---
phase: 29-defectdojo-live-validation
plan: 07
subsystem: k8s-infrastructure
tags: [defectdojo, argocd, overlay, lb-vip, pihole, dns, ddojo-05]
requires:
  - "29-05: DefectDojo overlay app directory committed on feat/defectdojo-app-directory"
  - "29-02: homelab context (admin@occ-new) and pinned values"
provides:
  - "occ-k8s-app-config main cc7fbc958c7928d1d640c2f9ec20a44b78a7fcfd: PR #248 merged, application-sets/platform/defectdojo/** live"
  - "Argo CD Application argocd/defectdojo exists on admin@occ-new (first seen 2026-09-28T01:56:38Z)"
  - "Evidence: LB VIP pool read with 10.40.3.65 unallocated before the merge, and Pi-hole 10.40.1.53 resolving both FQDNs to 10.40.3.65"
affects: [29-08, 29-12, 29-14]
tech-stack:
  added: []
  patterns:
    - "Merge pinned with gh pr merge --match-head-commit so an unexpected push between approval and merge fails the merge"
    - "Overlay work in a disposable git worktree; the shared overlay checkout only receives git fetch"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-07-vip-pool-before.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-07-dns-check.txt
  modified:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/README.md
decisions:
  - "29-07: operator Task 1 reply verbatim: \"vip-free vlan30-skip\". The records are not added on the in-cluster Pi-hole 10.30.1.53, so VLAN30 clients cannot resolve the DefectDojo names. The runner path does not need them."
  - "29-07: operator Task 3 reply verbatim: \"approve\". The operator approved merging without waiting on the GitGuardian check."
  - "29-07: PR #248 merged as cc7fbc958c7928d1d640c2f9ec20a44b78a7fcfd at 2026-09-28T01:54:56Z, head ad0a391, with --merge and pinned by --match-head-commit"
  - "29-07: GitGuardian incident 37678807 (\"Django Secret Key\", templates/sealedsecret-defectdojo.yaml:41, spec.encryptedData.DD_SECRET_KEY) is a false positive on kubeseal ciphertext. It is still open for the operator to dismiss."
  - "29-07: DDOJO-05 not marked complete. The Application exists, but health and first sync are measured by 29-08 and later plans."
metrics:
  duration: "~2h (across executor sessions, including both operator gates)"
  completed: 2026-09-28
  tasks: 3
  files: 3
---

# Phase 29 Plan 07: DefectDojo overlay merge and network pre-checks Summary

The DefectDojo overlay (`occ-k8s-app-config` PR #248, overlay commit `db5aae1` plus README commit `ad0a391`) merged to `main` as `cc7fbc958c7928d1d640c2f9ec20a44b78a7fcfd` with operator approval. It went in on a VIP (10.40.3.65) that was confirmed free and has working LAN DNS. Argo CD generated the `defectdojo` Application about 100 seconds after the merge.

## Operator replies (verbatim)

- Task 1: `vip-free vlan30-skip`
- Task 3: `approve`. The operator saw PR #248, the GitGuardian false-positive analysis, the deploy effects and the rollback, and chose to merge without waiting on GitGuardian.

## VLAN30 decision

`vlan30-skip`: the two A records exist only on the LAN Pi-hole 10.40.1.53, not on the in-cluster Pi-hole 10.30.1.53. VLAN30 clients cannot resolve `defectdojo.infra.ottawacloudconsulting.com` or `defectdojo.home.ottawacloudconsulting.com`, and the runner path does not need them. This is recorded in the overlay README (commit `ad0a391`) for ADR-027.

## Task results

| Task | Result | Commit |
|------|--------|--------|
| 1 | The live LoadBalancer Service read shows no Service holding 10.40.3.65. The operator confirmed in UniFi that the VIP is free. At 2026-09-28T01:43:36Z, `dig +short @10.40.1.53` returned exactly `10.40.3.65` for both FQDNs. | docs `aa1e625`, docs `7991288` |
| 2 | The 29-05 overlay commit was rebased from `a783559` onto `origin/main` `97d347f` and is now `db5aae1`. The README VLAN30 note was added as `ad0a391`. The branch was pushed and PR #248 opened (10 files). Post-rebase gates all passed: c1 0/21, `check_appconfig` 22 apps, scoped yamllint, source-1 and source-2 renders, `kubectl` dry-run 6/6, gitleaks scoped and in CI form. `conformance` passed (run 36367516504). | overlay `db5aae1`, overlay `ad0a391` |
| 3 | Re-checked before merging: head was still `ad0a3918d19caca125e2e0b75c44d544b9bc16e4` and `conformance` was SUCCESS. Merged with `gh pr merge 248 --merge --match-head-commit ad0a391...`, which produced merge commit `cc7fbc9` (parents `97d347f`, `ad0a391`). `kubectl --context admin@occ-new -n argocd get applications.argoproj.io defectdojo -o name` returned `application.argoproj.io/defectdojo` on poll attempt 4 at 2026-09-28T01:56:38Z. Health was not judged here; plan 29-08 does that. | merge `cc7fbc9` |

PR #248 files: `.gitleaksignore`, plus `application-sets/platform/defectdojo/{Chart.yaml, README.md, argocd-overrides.yaml, templates/certificate.yaml, templates/ghostunnel-deployment.yaml, templates/sealedsecret-defectdojo.yaml, templates/sealedsecret-defectdojo-postgresql-specific.yaml, templates/sealedsecret-defectdojo-valkey-specific.yaml, templates/service.yaml}`.

## Open item for the operator

- **GitGuardian incident 37678807, "Django Secret Key"** at `application-sets/platform/defectdojo/templates/sealedsecret-defectdojo.yaml:41`. The flagged value is `spec.encryptedData.DD_SECRET_KEY`: kubeseal ciphertext, 880 characters, prefix `Ag`, which only the cluster's sealed-secrets controller can decrypt. **This is a false positive and it is still OPEN.** The operator should dismiss it in the GitGuardian dashboard. `main` has no branch protection, so the failing check did not block the merge.

## Deviations from Plan

1. **[Rule 3 - Blocking] Rebased onto a moved `origin/main`.** `origin/main` had advanced to `97d347f`, so the 29-05 commit `a783559` was rebased and became `db5aae1`. All gates were re-run after the rebase and passed. `db5aae1` is the commit that shipped; `a783559` no longer exists on any pushed ref.
2. **README bullet replaced instead of appended.** The README's DNS section had an "Open question" bullet about VLAN30. Task 2 replaced it with the `vlan30-skip` decision (dated 2026-09-28) plus a bullet giving the dig result. Appending would have left the question and its answer side by side.
3. **Task 3 cleanup replaced `checkout main && pull --ff-only`.** The shared overlay checkout is another session's active tree, so it was never checked out, switched, reset or pulled. Instead, the scratchpad worktree `wt-29-07` was removed with `git worktree remove` (it was clean), and the shared tree only received `git fetch origin`, which moved `origin/main` from `97d347f` to `cc7fbc9`. The shared tree's local `main` is still at `97d347f` and has not been touched.
4. **Scratchpad clean-up of the security-platform clone was not done.** The permission system denied `rm -rf` of `scratchpad/sp-clone`, `scratchpad/src1`, `scratchpad/src1-render.yaml` and `scratchpad/src1-values.yaml`. These are in the session scratchpad only, outside every repository, and hold no secrets. The operator can delete them.

## Threat model

- T-29-16 (VIP conflict): mitigated. The kubectl pool read and the operator's UniFi check both happened before the merge.
- T-29-17 (DNS misdirection): mitigated. The dig evidence shows exactly `10.40.3.65` for both names.
- T-29-13 (PVC data loss): mitigated. There was an operator merge gate, and the README's `## Rollback` section forbids deleting the PVC.

## Known Stubs

None.

## Next

Plan 29-08 measures the first sync and health of the `defectdojo` Application.

## Self-Check: PASSED

- Both evidence files exist, and the Task 1 automated verify passes.
- The Task 3 automated verify passes: `application.argoproj.io/defectdojo` exists on admin@occ-new.
- Commits found: docs aa1e625 and 7991288; overlay db5aae1, ad0a391 and cc7fbc9. db5aae1 is an ancestor of origin/main.
