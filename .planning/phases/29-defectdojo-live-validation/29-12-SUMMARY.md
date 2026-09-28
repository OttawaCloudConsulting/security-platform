---
phase: 29-defectdojo-live-validation
plan: 12
subsystem: k8s-infrastructure
tags: [defectdojo, arc, gha-runner-scale-set, sealed-secrets, hostaliases, fork-pr-policy, d-06, d-07, d-08, d-09, ddojo-05]
requires:
  - "29-11: runner tag 2.337.0 and HOSTALIASES-TARGET 10.40.3.65"
  - "29-02: platform AppProject entries for arc-systems/arc-runners, both OCI sourceRepos spellings, AutoscalingRunnerSet"
provides:
  - "occ-k8s-app-config feat/arc-systems @ ad8c5db: arc-systems controller Application (gha-runner-scale-set-controller 0.14.2, release arc, SSA, prune off)"
  - "occ-k8s-app-config feat/arc-runners @ 1070fac: arc-runners repo-scoped scale set occ-homelab-defectdojo + SealedSecret arc-github-pat + one .gitleaksignore fingerprint"
  - "evidence/29-12-fork-approval-policy.json: first_time_contributors -> all_external_contributors"
affects: [29-13, ADR-027, ADR-028]
tech-stack:
  added: []
  patterns:
    - "Guarded sealing: one `set -euo pipefail` script, single-redirect env-file write, count-only and length-only checks, PAT deleted only after all ciphertext assertions pass; ENVF-only EXIT trap"
    - "mikefarah yq: `A | B and C` parses as `(A | B) and C`; parenthesise the whole conjunction after the pipe"
key-files:
  created:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-systems/argocd-overrides.yaml (feat/arc-systems)
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-systems/README.md (feat/arc-systems)
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-runners/argocd-overrides.yaml (feat/arc-runners)
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-runners/Chart.yaml (feat/arc-runners)
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-runners/README.md (feat/arc-runners)
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/arc-runners/templates/sealedsecret-arc-github-pat.yaml (feat/arc-runners)
    - .planning/phases/29-defectdojo-live-validation/evidence/29-12-fork-approval-policy.json
  modified:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/.gitleaksignore (feat/arc-runners)
decisions:
  - "29-12: fork-PR workflow approval on security-platform raised first_time_contributors (13:39:02Z) -> all_external_contributors (13:48:46Z), before any DEFECTDOJO_RUNS_ON exists"
  - "29-12: scale set name / release name / runs-on label = occ-homelab-defectdojo; controller release arc -> controllerServiceAccount arc-systems/arc-gha-rs-controller"
  - "29-12: arc-runners prune ON (owns no CRD), no SSA; arc-systems prune OFF with ServerSideApply=true (CRDs 612248/309369/307754/307683 bytes)"
  - "29-12: the ARC PAT exists only as SealedSecret arc-runners/arc-github-pat (key github_token, wave -1); the plaintext file and env file were deleted after sealing"
  - "29-12: kubectl --dry-run=client of the AutoscalingRunnerSet cannot pass until arc-systems installs the CRDs (29-13); the other three rendered kinds and the SealedSecret pass"
metrics:
  duration: "~30min wall clock (13:39Z-14:08Z), including two operator waits and one failed sealing attempt"
  completed: 2026-09-28
  tasks: 3
  files: 8
---

# Phase 29 Plan 12: ARC controller and repo-scoped runner scale set (arc-systems, arc-runners) Summary

Two gate-clean local branches in `occ-k8s-app-config` hold the ARC Applications. `feat/arc-systems` @ `ad8c5db` has the controller (0.14.2, release `arc`, ServerSideApply, prune off). `feat/arc-runners` @ `1070fac` has the repository-scoped scale set `occ-homelab-defectdojo` on security-platform. That scale set pins `ghcr.io/actions/actions-runner:2.337.0`, maps `defectdojo.infra.ottawacloudconsulting.com` to `10.40.3.65` through `hostAliases`, and reads the fine-grained PAT from SealedSecret `arc-github-pat`. The security-platform fork-PR approval policy went from `first_time_contributors` to `all_external_contributors`. The PAT plaintext file is gone. Nothing was pushed, and both branches and the worktree are left in place for 29-13.

## For plan 29-13

| Item | Value |
|---|---|
| Merge order | `feat/arc-systems` (ad8c5db) first, wait for the controller + CRDs, then `feat/arc-runners` (1070fac) |
| Worktree | `/private/tmp/claude-501/-Users-christian-git-repos-OCC-github-development-environment-security-solution/4a04faf8-acc3-4cd1-927d-a88ede360f9f/scratchpad/wt-29-12` (on feat/arc-runners) |
| Runner label / `DEFECTDOJO_RUNS_ON` | `occ-homelab-defectdojo` |
| Runner image | `ghcr.io/actions/actions-runner:2.337.0` (index `sha256:e5496277be5d09bc968b3d64911b74e219ac4a3f2edce956a3ecf9271bea1ef4`, amd64 `sha256:5036480998280bb21e32ade9fe1b02b493861ac314b62ba1aea320b94f56ec97`) |
| hostAliases | `10.40.3.65` -> `defectdojo.infra.ottawacloudconsulting.com` (measured only from the L2-lease node, see 29-11) |
| Secret | `arc-runners/arc-github-pat`, key `github_token`, wave -1 |
| Fork policy | before `first_time_contributors` (2026-09-28T13:39:02Z), after `all_external_contributors` (2026-09-28T13:48:46Z) |

## Task 1: fork-PR approval policy (docs a976183)

- The operator raised the policy and created the PAT. Operator reply, verbatim: `pat-ready policy-raised`
- The evidence JSON records the before/after policy reads and the PAT file's shape. The content was never read.

## Task 2: arc-systems controller (overlay ad8c5db on feat/arc-systems)

- 0.14.2 render with `--include-crds`: 4 CRDs (612248 / 309369 / 307754 / 307683 bytes compact JSON), ClusterRole, ClusterRoleBinding, Deployment, SA `arc-gha-rs-controller`, Role, RoleBinding.
- No `--watch-single-namespace` flag, so the controller serves every namespace, including `arc-runners`.
- All gates passed.

## Task 3: arc-runners scale set (overlay 1070fac on feat/arc-runners)

### Sealing incident (first attempt) and retry

- **Incident.** The first attempt used `printf 'SECRET_LITERAL_github_token=%s\n' "$(cat PAT)" >> $ENVF >/dev/null`. The last redirect wins, so the line went to `/dev/null`. `seal-secret.sh` then failed with `No SECRET_LITERAL_* variables found` (rc=1). The command then ran `rm -f` on the env file and the PAT file regardless of the failure.
  - The token was never displayed, never in the process list (`kubectl` never ran), and never in git or evidence. The orchestrator scanned the scratchpad and found 0 token-length strings.
  - The operator was asked to revoke the orphaned token and create a new one.
- **Operator replies, verbatim, in order:** `pat-ready policy-raised`, `issue fixed, try again`, `pat-ready in ~/.config/arc/security-platform-pat`.
- **The replacement file, as read back by the orchestrator** (content never read): mode 600, 94 bytes, 1 line, starts with `github_pat_`.
- **Guarded retry** (`scratchpad/seal-arc.sh`, one `bash` invocation, `set -euo pipefail`):
  - It first checked that the context is `admin@occ-new`.
  - It wrote the env file under umask 077 (mode 600), with a single `>>` on the literal line.
  - It checked the literal line count (1) and length (121) without printing the value.
  - `seal-secret.sh` ran with `CONTROLLER_NAMESPACE=sealed-secrets`.
  - It checked the result: kind SealedSecret, name `arc-github-pat`, namespace `arc-runners` in both metadata blocks, ciphertext starting with `Ag` (832 characters), and a `github_pat_` count of 0.
  - Only after all of that did it `rm -f` the env file and the PAT file and check that both were gone.
  - An EXIT trap removes only the env file, and only on failure. It never touches the PAT.
- **Result:** `sealed-ok ... plaintext-removed: envf=gone pat=gone`. An independent check confirmed both files were gone (`~/.config/arc/` is empty).

### Authored

- `argocd-overrides.yaml`:
  - `source: null` plus two sources: OCI `gha-runner-scale-set` 0.14.2, release `occ-homelab-defectdojo`, and the local directory.
  - valuesObject exactly per RESEARCH Pattern 3.
  - No `runnerGroup` or `containerMode`, and no NetworkPolicy.
  - Prune on, CreateNamespace + ApplyOutOfSyncOnly, retry 5 / 30s / 2 / 10m.
  - Comments cover D-07 amended (personal account), the `lookup`/`fail` reason, D-09, ephemeral pods, the 30-day rule and bump procedure, and the rollback ordering (delete before arc-systems).
- `Chart.yaml`: `arc-runners` 0.1.0, appVersion "0.14.2", with the no-dependencies rationale.
- `templates/sealedsecret-arc-github-pat.yaml`: Nexus form, wave "-1", `type: Opaque`. The header covers the PAT scope, the ADR-028 breadth and the rotation procedure.
- `README.md`: the label = `DEFECTDOJO_RUNS_ON` identity, the literals table, the discretion choices, the security posture, the per-consumer-repo scale set rule, PAT rotation, the 30-day rule, rollback ordering and validation commands.
- `.gitleaksignore`: 1 fingerprint (`...sealedsecret-arc-github-pat.yaml:generic-api-key:39`, the `github_token` ciphertext line). This follows the 29-05 precedent.

### Gates (all in the worktree)

| Gate | Result |
|---|---|
| source-1 render (empty DOCKER_CONFIG, scratchpad `--registry-config`, `--include-crds`) | rc 0, chart digest `sha256:579e3a1b...24d11`. Renders exactly 4 objects: AutoscalingRunnerSet `occ-homelab-defectdojo`, Role + RoleBinding `occ-homelab-defectdojo-gha-rs-manager`, SA `occ-homelab-defectdojo-gha-rs-no-permission` |
| render assertions | exactly 1 AutoscalingRunnerSet. The pod template has hostAliases `10.40.3.65` / the FQDN, image `ghcr.io/actions/actions-runner:2.337.0`, `githubConfigSecret: arc-github-pat`, the repo URL and min 0 / max 2. No runnerGroup or containerMode |
| AppProject `platform` whitelist | AutoscalingRunnerSet, Role, RoleBinding, ServiceAccount and SealedSecret are all listed |
| `helm template arc-runners-local` | rc 0, renders exactly SealedSecret `arc-github-pat` / `arc-runners` |
| `kubectl --dry-run=client` | SealedSecret, SA, Role and RoleBinding pass. The AutoscalingRunnerSet fails with `no matches for kind` because the CRD does not exist until arc-systems syncs (29-13). This is expected |
| yamllint (scoped), c1.py, check_appconfig `--base origin/main` | all PASS |
| gitleaks scoped (`--source application-sets --no-git --redact`) | 1 finding (the ciphertext) before the fingerprint, `no leaks found` after |
| gitleaks CI form (`--source .` on a `git archive` extract of the staged tree) | `no leaks found`, rc 0 |
| `git diff origin/main HEAD \| grep -Ec 'github_pat_\|ghp_'` | 0 |
| pre-commit (no `--no-verify`) | yamllint, markdownlint, c1, check_appconfig Passed |
| plan `<verify>` block | VERIFY-PASS with the yq parenthesisation fix (see Deviations); negative control rc 1 |

### Shared overlay tree

The shared tree is unchanged from its before-state: HEAD `08ce26b` on `main`. The worktree list is the main tree plus `wt-29-12` (and the pre-existing prunable `/private/tmp/occ-5.4-outage`). The two local branches are `feat/arc-systems` ad8c5db and `feat/arc-runners` 1070fac, both 1 commit ahead of origin/main. Nothing was pushed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's verify-block yq conjunction is parsed as `(A | B) and C` by mikefarah yq v4.53.6**
- **Found during:** Task 3 verification.
- **Issue:** `.argocdOverrides...valuesObject | .x==.. and .y==..` evaluates every operand after the first against the document root, so the expression returns false against correct content (`Error: no matches found`). Reproduced on a 3-line fixture.
- **Fix:** Parenthesise the whole conjunction after the pipe. The corrected block passed, and a negative control (`maxRunners==3`) returned rc 1. The committed files did not change. This is the same class of problem as the Task 2 note (`any_c` instead of `index()`).
- **Commit:** none (verification-only).

**2. [Rule 3 - Blocking] Gitleaks flagged the SealedSecret ciphertext**
- The fix is one `.gitleaksignore` fingerprint with a rationale comment, per the plan's allowance and the 29-05 precedent. Included in 1070fac.

**3. [Rule 1 - Bug] Sealing-command redirect defect (first attempt)** — see "Sealing incident" above. It was fixed by the guarded retry script. The orphaned first PAT is an open operator follow-up (below).

**4. Commit mechanism:** the overlay has no `.claude/scripts/gcommit`, so the commit used `git commit -F <scratch msgfile>` with the session trailers, as the orchestrator directed.

## Open operator follow-ups

- **Revocation of the orphaned first PAT is NOT confirmed.** The operator's reply `pat-ready in ~/.config/arc/security-platform-pat` confirmed the new token, not revocation of the first. Check GitHub → Settings → Developer settings → Fine-grained tokens and revoke any older security-platform token other than the one sealed here.

## Residual risks

- `seal-secret.sh` passes the value to `kubectl create secret --dry-run=client --from-literal=github_token=...`, so the token was briefly visible in the local process list during sealing (a single-user workstation, a sub-second window).
- The token was in `$(cat ...)` expansion and the sourced shell environment of `seal-secret.sh` for the duration of that process.
- APFS has no reliable overwrite, so deleted plaintext blocks may persist until reused. The token's scope (one repository) and its sealing are the mitigations; ADR-028 records the breadth.
- The hostAliases hairpin was measured only from the node holding the L2 lease (29-11 caveat).

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat register (T-29-01/02/03/04/07/SC all addressed as planned).

## Self-Check: PASSED
