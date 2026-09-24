---
phase: 25-nexus-live-validation
plan: 06
subsystem: security-platform merge of the homelab gate and the measured chart README limitations
tags: [nexus, security-platform, readme, homelab-validation, merge, public-repo]
requires:
  - "25-01: scripts/nexus-homelab-validate.sh on branch feature/phase-25-nexus-live-validation (2c76632)"
  - "25-04: first-sync byte counts cited in the README"
  - "25-05: evidence/25-05-chart-edit-assessment.md verdict NO CHART EDIT NEEDED"
provides:
  - "scripts/nexus-homelab-validate.sh on security-platform origin/main, mode 100644"
  - "kubernetes/nexus/README.md limitation bullets naming the measured homelab result and narrowing the open item to a real-dockerd pull over TLS/ingress (ADR-022)"
  - "security-platform PR #16 merged as 61589d509505442a3e26110fbc5c4bf156a6a488"
affects: [25-07]
tech-stack:
  added: []
  patterns:
    - "Post-merge verification read from origin/main via git show / git ls-tree, never from the local working tree"
    - "Record the pre-merge origin/main blob id of a file that must stay unchanged, then compare blob ids after the merge"
key-files:
  created:
    - repos/security-platform/scripts/nexus-homelab-validate.sh (merged to origin/main; authored in 25-01)
  modified:
    - repos/security-platform/kubernetes/nexus/README.md
decisions:
  - "job-provision.yaml deliberately untouched, per 25-05 assessment NO CHART EDIT NEEDED. Blob 929bc35f is identical before and after the merge"
  - "Operator accepted the README as-is, including the ADR-022 references (ADR-022 is written by 25-07 in the private docs repo, so the public README can't link to it) and the unplanned NEXUS-05 requirements-table row change Planned -> Complete"
metrics:
  duration: "~2h25m wall clock, including the operator review wait (Task 1 commit 01:22Z; merge 03:47Z)"
  completed: 2026-09-24
  tasks: 3
  files: 2
---

# Phase 25 Plan 06: Homelab gate and measured README limitations merged to security-platform Summary

`security-platform` PR #16 is merged into `main` as merge commit `61589d509505442a3e26110fbc5c4bf156a6a488`. It adds the `scripts/nexus-homelab-validate.sh` live gate (mode `100644`), and it rewrites the chart README's two stale limitation bullets. The rewritten bullets now state the measured homelab result, and they narrow what is still open to a real-`dockerd` pull against a routable hostname with TLS and ingress. `kubernetes/nexus/templates/job-provision.yaml` is byte-identical before and after the merge, as the 25-05 assessment required.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Rewrite the chart README limitation bullets, leave the chart alone, commit, open the PR | security-platform `5cc2a34` (on top of 25-01's `2c76632`) | `kubernetes/nexus/README.md` (+13/-3); `scripts/nexus-homelab-validate.sh` (new, from `2c76632`) |
| 2 | Checkpoint: operator reads the full public-repo diff | none (review only) | none |
| 3 | Merge and verify from origin/main | security-platform merge `61589d5` | none (merge only) |

## Task 2: operator reply (verbatim)

Before replying, the operator was shown the diff summary, the CI status (12/12 SUCCESS), the grep results for homelab identifiers, the unplanned change to the NEXUS-05 README table row, and the caveat that ADR-022 is referenced publicly. The operator's reply:

> merge

The operator explicitly accepted the README as-is, including the ADR-022 references and the NEXUS-05 table-row change. No `gh pr merge` ran before the reply.

## Task 3: merge and origin/main verification

The continuation executor re-checked the PR immediately before merging. Head was still `5cc2a34fe5854d6dab8138d4c405e323e3a7156e`, state `OPEN`, `MERGEABLE`, and all 12 checks were `SUCCESS`: security / SAST — Semgrep CE, IaC — Checkov, SCA — Trivy Filesystem, Container — Trivy Image, Secrets — Gitleaks; Checkov; Semgrep OSS; Trivy; gitleaks; tflint; tflint-errors; GitGuardian Security Checks.

- Pre-merge `origin/main`: `aed14b916e9aa8ec1d0d47699b457040b99f7eac`
- Merge command: `gh pr merge 16 --repo OttawaCloudConsulting/security-platform --merge`
- PR #16 state: `MERGED` at `2026-09-24T03:47:03Z`; merge commit `61589d509505442a3e26110fbc5c4bf156a6a488`
- Post-fetch `origin/main`: `61589d5`, with history `61589d5` merge ← `5cc2a34` ← `2c76632` ← `aed14b9`

**All checks below were read from `origin/main` after `git fetch origin`, not from the local working tree:**

| Assertion | Command | Result |
|-----------|---------|--------|
| Gate script present with its check labels | `git show origin/main:scripts/nexus-homelab-validate.sh \| grep -q ANONYMOUS-WRITE-DENIED` | PASS. 18 distinct pass/fail labels: ARGOCD-HOOK-PHASE, PROVISION-JOB-COMPLETE, PROVISION-JOB-REPOS, PVC-DEFAULT-STORAGECLASS, DOCKER-REALM-ACTIVE, DOCKER-PATH-SHAPE, ANONYMOUS-PULL-DOCKER, ANONYMOUS-PULL-{ALLOWED,HELM,PYPI}-{TRANSPORT,HTTP-200,SIZE}, ANONYMOUS-WRITE-DENIED, SECOND-SYNC-IDEMPOTENT |
| Old bullet gone | `! git show origin/main:kubernetes/nexus/README.md \| grep -q 'Validation so far is a throwaway kind cluster'` | PASS |
| README names the gate | `git show origin/main:kubernetes/nexus/README.md \| grep -c nexus-homelab-validate.sh` | 2 (`--sync-pass` appears on 2 lines) |
| Chart unchanged | `git rev-parse origin/main:kubernetes/nexus/templates/job-provision.yaml`, before vs after | `929bc35f4d290b898527698b99ba3b2f429f58dc` both times (byte-identical) |
| Merge scope | `git diff aed14b9 origin/main --stat` | 2 files: README.md (16 +-), nexus-homelab-validate.sh (+1130) |
| Executable bit never set | `git ls-tree origin/main scripts/nexus-homelab-validate.sh` | `100644 blob 7c7069c2…` |

## Chart edit: deliberately none

`evidence/25-05-chart-edit-assessment.md` gives the verdict **NO CHART EDIT NEEDED**. The quoted reasoning from 25-05:

> hookType was Sync on both syncs, BeforeHookCreation was measured (new Job UID, no immutable error), and the 900s TTL truncated nothing (logs captured 9s and 4s after completion).

`ttlSecondsAfterFinished: 900` and every Helm hook annotation are unchanged. The blob id comparison above shows this.

## Deviations from Plan

1. **README NEXUS-05 requirements-table row changed from Planned to Complete.** This row is not one of the plan's listed edits. The operator saw it at the checkpoint and accepted it. REQUIREMENTS.md in this docs repo is **not** marked complete here; plan 25-07 closes it formally.
2. **The plan says "14 check labels", but the merged script has 18 distinct pass/fail labels.** The three proxy pulls each carry TRANSPORT, HTTP-200 and SIZE sub-labels. This matches the "ALL PASS over 18 checks" that 25-05 measured. The plan's automated verify (the ANONYMOUS-WRITE-DENIED grep) passes.

## Notes for 25-07

- **ADR-022 is referenced by the public README but does not exist yet.** 25-07 writes it in this private docs repo, so a public reader can't resolve the reference. The operator accepted this. 25-07 should keep the ADR number 022, so that the reference stays accurate.
- Formal closure of NEXUS-05 in REQUIREMENTS.md belongs to 25-07.

## Follow-up (not this PR)

- `workstation/nexus-setup.sh --verify` is not read-only. Before it verifies anything, it writes `.npmrc`, `pip.conf`, `.nexus-env` and `.helm/` into the enclosing git repo and adds an entry to its `.gitignore`. The workstation README should say so, and this should be decided in a future security-platform change.

## Evidence hygiene

- The orchestrator grepped the lines added in the PR for non-loopback IPv4 literals, `occ-new`, `admin@`, `svc.cluster`, `.local`/`.lan`, `occ-k8s`, `qnap` and `trident`. There were zero matches.
- The operator read the full diff at the Task 2 checkpoint before the merge (T-25-30).

## Known Stubs

None.

## Threat Flags

None. T-25-30 was mitigated by the identifier grep plus the operator's diff review, T-25-31 by the README citing measured byte counts and stating loopback port-forward only, T-25-32 by the identical chart blob, and T-25-33 by `100644` on origin/main.

## Self-Check: PASSED

- `gh pr view 16` state is `MERGED`, and merge commit `61589d5` is `origin/main`
- `5cc2a34` and `2c76632` are ancestors of `origin/main`
- The Task 3 `<verify>` conditions all passed against `origin/main`
