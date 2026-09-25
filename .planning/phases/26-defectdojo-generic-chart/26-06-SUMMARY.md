---
phase: 26-defectdojo-generic-chart
plan: 06
subsystem: security-platform publication (PR, operator gate, merge verification from origin/main)
tags: [pr, merge, operator-gate, ci, origin-main, defectdojo, publication]
requires:
  - "26-05: verbatim offline gate, live smoke, Checkov and repo hygiene evidence at security-platform 60205bd"
provides:
  - "kubernetes/defectdojo/ published on OttawaCloudConsulting/security-platform main (PR #19, merge commit e097381)"
  - "Verbatim record of the 12 CI checks on PR #19 (12/12 pass)"
  - "Verification read from origin/main after git fetch (ls-tree, show, rev-list --parents), plus the offline gate re-run on a detached origin/main checkout"
affects: [26-07, 29]
tech-stack:
  added: []
  patterns:
    - "Operator merged out of band: gh pr view --json state read MERGED, gh pr merge not invoked (Phases 18/19 precedent)"
    - "Offline gate against origin/main run in a scratchpad detached worktree, removed afterwards; local clone untouched"
key-files:
  created:
    - .planning/phases/26-defectdojo-generic-chart/26-06-SUMMARY.md
  modified: []
decisions:
  - "Phase 26 publication decisions a-g (media emptyDir, fail-guard issuer enforcement, issuer kind by annotation key, tag pin + drift check, uwsgi sizing, smoke beyond D-14, example.com placeholder) are recorded as accepted by the operator's merge of PR #19. This is not a separate per-item approval. The operator rejected none."
  - "PR #19 was merged by the operator (GitHub mergedAt 2026-09-25T02:20:25Z) as a two-parent merge commit e097381, parents 61589d5 (main) and 60205bd (branch head). The agent did not run gh pr merge."
metrics:
  duration: "~15 min (continuation: Task 3 + summary)"
  completed: 2026-09-25
  tasks: 3
  files: 0
---

# Phase 26 Plan 06: Publish the DefectDojo chart Summary

The DefectDojo wrapper chart is now public. PR #19 on `OttawaCloudConsulting/security-platform` was merged into `main` by the operator as the two-parent merge commit `e097381c72fab2534199e8c63cc3f3f6d198e3a2`. After `git fetch`, `origin/main` has all eight chart and script files and no vendored tarball. Its README carries the Phase 26 marker once. The offline gate prints `PASS - 20 checks, 0 failures` on a detached `origin/main` checkout.

## Tasks

| # | Task | Commit | Notes |
|---|------|--------|-------|
| 1 | Push branch, open PR, record CI | none (remote only) | PR #19, head `60205bd15a0cd6154831ce28619a0e7f044352a3`, 12/12 checks pass |
| 2 | Operator approval to merge | none (gate) | Operator merged PR #19 themselves; reply recorded verbatim below |
| 3 | Merge and verify from origin/main | none (remote only) | Already MERGED; `gh pr merge` not invoked; verified from origin/main |

security-platform: no commits by this plan. `git status --porcelain` is empty (0 lines) and the clone is still on `feature/phase-26-defectdojo-generic-chart` at `60205bd`.

## Task 1: PR and CI

- PR: **#19** https://github.com/OttawaCloudConsulting/security-platform/pull/19
- Title: `feat: add DefectDojo generic Helm chart (Phase 26)`. Base `main` (then `61589d5`). Head `feature/phase-26-defectdojo-generic-chart` @ `60205bd15a0cd6154831ce28619a0e7f044352a3`
- Files (9): `README.md`, `kubernetes/defectdojo/.helmignore`, `kubernetes/defectdojo/Chart.lock`, `kubernetes/defectdojo/Chart.yaml`, `kubernetes/defectdojo/README.md`, `kubernetes/defectdojo/templates/validate-tls.yaml`, `kubernetes/defectdojo/values.yaml`, `scripts/check-defectdojo-chart.sh`, `scripts/defectdojo-live-smoke.sh`. None is under `kubernetes/defectdojo/charts/`.
- PR body contains `PASS - 20 checks, 0 failures` (1), `ALL PASS` (1) and `emptyDir` (1). I counted each with `grep -cF` on `gh pr view 19 --json body`.
- `gh pr checks 19`, verbatim:

```
Checkov	pass	3s	https://github.com/OttawaCloudConsulting/security-platform/runs/107903280702
GitGuardian Security Checks	pass	1s	https://dashboard.gitguardian.com
Semgrep OSS	pass	2s	https://github.com/OttawaCloudConsulting/security-platform/runs/107903272740
Trivy	pass	2s	https://github.com/OttawaCloudConsulting/security-platform/runs/107903267202
gitleaks	pass	3s	https://github.com/OttawaCloudConsulting/security-platform/runs/107903237653
security / Container — Trivy Image	pass	33s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36081157024/job/107903205181
security / IaC — Checkov	pass	27s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36081157024/job/107903205153
security / SAST — Semgrep CE	pass	27s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36081157024/job/107903204990
security / SCA — Trivy Filesystem	pass	37s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36081157024/job/107903205216
security / Secrets — Gitleaks	pass	16s	https://github.com/OttawaCloudConsulting/security-platform/actions/runs/36081157024/job/107903205113
tflint	pass	4s	https://github.com/OttawaCloudConsulting/security-platform/runs/107903313452
tflint-errors	pass	3s	https://github.com/OttawaCloudConsulting/security-platform/runs/107903313984
```

No Checkov FAILURE this time, so interfaces rule 6 (fixture vs chart finding) never applied. As 26-05 measured, CI's Checkov covers `kubernetes/defectdojo` zero times, for a named cause: the issuer guard fails the bare render.

## Task 2: Operator gate

The checkpoint presented PR #19, the measured 26-05 values and decisions a-g:

- a. media `emptyDir`
- b. `fail` guard instead of `required`
- c. issuer kind chosen by the annotation key
- d. tag pin 3.3.200 plus a drift check
- e. uwsgi `processes: 2` / `maxFd: 102400` / 384Mi-1Gi
- f. the smoke goes beyond D-14 (login POST, celery ping)
- g. placeholder `defectdojo.example.com`

The operator merged PR #19 themselves (GitHub `mergedAt` `2026-09-25T02:20:25Z`, `mergedBy` `OttawaCloudConsulting`). Their reply, verbatim:

> PR#19 is merged, PR17 and PR18 are not - tell me if I need to

**Decisions a-g are recorded as accepted by the operator's merge.** The operator did not approve them one by one, and rejected none. No agent message stood in for the operator's authorisation. The merge was the operator's own act.

Context on PR #17 and #18: these are unrelated Dependabot bumps to `.github/workflows/security.yml`. #17 bumps `checkov-action` 12.3123.0 -> 12.3125.0 (container 3.3.17 -> 3.3.19). #18 bumps codeql `upload-sarif` 4.38.0 -> 4.38.1. Neither is required for Phase 26 and both are still unmerged. Merging them is the operator's call. Note that #17 changes the Checkov container version that 26-05's CI-equivalent measurement pinned (3.3.17).

## Task 3: Verification from origin/main

Prediction stated before acting:

- DOING: read-only verification.
- EXPECT: 8 files, no `charts/` path, marker count 1, merge commit with 2 parents including 60205bd.
- IF MISMATCH: stop.

Every expected value matched.

- `gh pr view 19 --json state,mergeCommit,mergedAt`: `state` `MERGED`, `mergeCommit.oid` `e097381c72fab2534199e8c63cc3f3f6d198e3a2`, `mergedAt` `2026-09-25T02:20:25Z`. `gh pr merge` was **not** invoked.
- `git fetch origin`: `61589d5..e097381  main -> origin/main`. `git rev-parse origin/main`: `e097381c72fab2534199e8c63cc3f3f6d198e3a2`.
- `git rev-list --parents -n1 e097381…` printed three SHAs: `e097381c72fab2534199e8c63cc3f3f6d198e3a2 61589d509505442a3e26110fbc5c4bf156a6a488 60205bd15a0cd6154831ce28619a0e7f044352a3`. So this is a two-parent merge: first parent is the previous main `61589d5`, second is the branch head `60205bd`. Its subject is `Merge pull request #19 from OttawaCloudConsulting/feature/phase-26-defectdojo-generic-chart`.
- `git merge-base --is-ancestor 60205bd… origin/main`: true.
- `git ls-tree -r origin/main --name-only`, filtered to the chart and scripts:
  ```
  kubernetes/defectdojo/.helmignore
  kubernetes/defectdojo/Chart.lock
  kubernetes/defectdojo/Chart.yaml
  kubernetes/defectdojo/README.md
  kubernetes/defectdojo/templates/validate-tls.yaml
  kubernetes/defectdojo/values.yaml
  scripts/check-defectdojo-chart.sh
  scripts/defectdojo-live-smoke.sh
  ```
- `git ls-tree -r origin/main --name-only | grep '^kubernetes/defectdojo/charts/'`: no output (rc=1).
- `git show origin/main:README.md | grep -c 'DefectDojo chart complete (Phase 26)'`: `1`.
- The plan's automated verify (ls-tree for validate-tls.yaml and the live smoke, no `charts/`, state MERGED) printed `VERIFY_PASS`.
- **Offline gate on origin/main**, which goes beyond the plan's acceptance criteria:
  - I made a detached worktree at `e097381` in the session scratchpad.
  - The first run exited 2 with `PREFLIGHT FAIL: subchart not vendored`. That is expected, because the tarball is git-ignored (`.gitignore:28: kubernetes/*/charts/*.tgz`).
  - `helm dependency build` then failed with `no repository definition for https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts`. This helm client has no repo entry for that URL, and I did not change the operator's helm repo config.
  - Instead I copied the local clone's already-vendored `defectdojo-1.9.53.tgz` (sha256 `0393332d77412d2a76921f418faf933e9739088ddbf207b2a4b94867daa0657d`, the tarball 26-05's gates ran against) into the worktree.
  - `bash scripts/check-defectdojo-chart.sh` then printed `PASS - 20 checks, 0 failures`, exit 0.
  - I removed the worktree with `git worktree remove --force`. `git worktree list` now shows only the main clone.
- No remote branch was deleted. I did not touch branch protection or required checks. I made no kubectl or helm install call against any cluster.

## Deviations from Plan

- **Operator merged out of band (interfaces rule 4).** The plan expected the agent to run `gh pr merge 19 --merge` after an explicit approval reply. Instead the operator merged it themselves, and GitHub produced a two-parent merge commit, matching the `--merge` requirement. I recorded the merge and did not run `gh pr merge`. The must-have truth "operator explicitly accepted the decisions ... before anything merged" is satisfied only in the sense that the operator chose to merge with decisions a-g in front of them. No per-item acceptance exists.
- **Extra verification.** The continuation instructions asked for the offline gate to run on an origin/main checkout, which the plan's acceptance criteria do not require. Vendoring for that run used the local tarball, not a fresh `helm dependency build`, for the reason given above. So this run shows that origin/main's chart, values and scripts pass with the same 1.9.53 tarball. It does not show a fresh download.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: .planning/phases/26-defectdojo-generic-chart/26-06-SUMMARY.md
- FOUND (origin/main): e097381c72fab2534199e8c63cc3f3f6d198e3a2, parents 61589d5 and 60205bd
- FOUND (origin/main): all 8 chart/script paths; 0 paths under kubernetes/defectdojo/charts/
