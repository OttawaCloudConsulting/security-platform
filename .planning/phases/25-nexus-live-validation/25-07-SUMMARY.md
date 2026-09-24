---
phase: 25-nexus-live-validation
plan: 07
subsystem: docs / ADR log and requirements traceability
tags: [nexus, adr, argocd, homelab, live-validation, requirements]
requires:
  - "25-01..25-06 SUMMARYs and evidence/ (all committed before this plan)"
  - "security-platform PR #16 (merge 61589d5), whose chart README already cites ADR-022"
provides:
  - "docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md (Accepted), extending ADR-020 and ADR-021 in prose"
  - "ADR index row for ADR-022"
  - "NEXUS-05 Complete in REQUIREMENTS.md (checklist and traceability table)"
affects: [phase-26, phase-29]
tech-stack:
  added: []
  patterns:
    - "Every measured value in the ADR is attributed to a Phase 25 summary or evidence file; values measured earlier are attributed to the ADR that measured them (the ~192-byte EULA body and the anonymous /repositories 200 go to ADR-021)"
key-files:
  created:
    - docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md
  modified:
    - docs/adr/README.md
    - .planning/REQUIREMENTS.md
decisions:
  - "ADR-022 records ingress/TLS as deliberately excluded (L-01). ADR-021 item 4 stays open, and ADR-021 item 1 (real dockerd pull) is deferred behind it"
  - "ADR-022 records ADR-020 items 3 and 4 and ADR-021 item 7 as closed by observation. Item 3's observation contradicted the training-knowledge claim: hookType Sync, not PostSync"
  - "No homelab identifiers in ADR-022: 'the homelab kube context' is used because no prior ADR names the context, and the storage provisioner and CNI vendor are not named"
metrics:
  duration: "~15 min"
  completed: 2026-09-23
  tasks: 2
  files: 3
---

# Phase 25 Plan 07: ADR-022 and NEXUS-05 closure Summary

ADR-022 (240 lines, Accepted) records how the Nexus chart was validated live through the private ArgoCD overlay. It covers the directory-derived Application, the five-addition `platform` AppProject widening, the provisioning Job running as a `Sync` hook rather than PostSync, and the anonymous pulls with byte counts (npm 318,961, PyPI 76,776, Helm 291,818, Docker layer 3,626,020). It also records the exactly-403 write refusal and the second-sync idempotency result (4× updated, 0× created). The record includes six decisions, seven Consequences entries and a `## What was NOT verified` section that keeps ADR-021 items 1 and 4 visibly open. NEXUS-05 is now Complete in `REQUIREMENTS.md`.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1+2 | `e04beac` | docs(25-07): record ADR-022 and close NEXUS-05 (ADR, ADR index, REQUIREMENTS.md) |

Tasks 1 and 2 share one commit. Task 2's verify requires `git show --stat HEAD` to list the ADR, so a separate Task 1 commit would have failed it. 25-01 handled the same situation the same way. Nothing was pushed from this repository. `git log --oneline -1` after the commit printed `e04beac docs(25-07): record ADR-022 and close NEXUS-05`.

## What the ADR records beyond the plan's list

- ADR-020 item 4 (Argo resolving the gitignored subchart) is closed by observation: 25-04 saw no `ComparisonError` and no `InvalidSpecError`.
- The SealedSecret no-health caveat is cited from `evidence/25-04-first-sync-application.json` (`health: null`), not from research.
- The anonymous realms read returns 403 live, which makes the gate's admin fallback load-bearing.
- The `BeforeHookCreation` policy source is unresolved: it could be Argo's default or the mapped `helm.sh/hook-delete-policy`.
- The SHA pin is already one merge behind `security-platform` main (`aed14b9` vs `61589d5`). The deployed Job is unaffected only because the `job-provision.yaml` blob `929bc35f` is identical in both.
- The sealed-secrets controller namespace is `sealed-secrets`.
- Bare `application` resource names are ambiguous on the cluster. The ADR describes this generically ("another installed CRD") and does not name the other operator.
- Follow-up: `nexus-setup.sh --verify` writes files into the enclosing repository and is not read-only.
- The operator's decisions are quoted verbatim: "approve-defaults" (25-02) and "merge" (25-06).
- ADR-022 is cited from the public README but lives in this repository.

## Verification (observed)

- The Task 1 `<automated>` block printed `T1-VERIFY-OK`. This covers the file, all four sections, the ADR-021 reference, the index row, an empty `git diff` for ADR-020 and ADR-021, and no IPv4 literal other than `127.0.0.1`.
- An extra identifier grep for `occ-new|admin@|qnap|trident|cilium|svc.cluster|.local|.lan|crossplane` on the ADR matched nothing.
- `gsd-sdk query requirements.mark-complete NEXUS-05` ran, returning `{"updated":true,"marked_complete":["NEXUS-05"]}`. `git diff` then showed exactly two changed lines, the checklist line and the traceability row. The Out-of-Scope table was untouched, because nothing Phase 25 measured contradicts a row.
- Task 2 verify: the checklist `[x]` line matched, the table row matched, the unchecked-NEXUS count is 0, and the HEAD subject contains `docs(25-07)`. The `git show --stat HEAD | grep adr022…` term failed because non-tty `--stat` truncates the long path to `...022-nexus-live-validation-via-argocd-overlay.md`. `git show --stat=200 HEAD` and `git show --name-only HEAD` both list `docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md`.
- `docs/adoption-guide.md` was not touched, so `check-adoption-guide.sh` was not required.

## Deviations from Plan

1. **[Plan text] The evidence/ files were not in the 25-07 commit.** They were already committed by 25-04/25-05 (`32c9e26`, `d969494`, `e008990`, `58bc8ab`, `b62e893`, `5604aaa`, `b1cfbe9`), so staging them would have added nothing. The acceptance line "`git show --stat HEAD` lists … the `evidence/` files" cannot hold, and the files were not touched to force it.
2. **[Plan text] One commit for both tasks,** as explained under Commits.
3. **[Verify artefact] `--stat` path truncation,** as explained under Verification. This is not a content failure.
4. **[Provenance] Two figures that the plan's wording presents as this phase's measurements are attributed to ADR-021:** the ~192-byte EULA refusal body and the anonymous `GET /service/rest/v1/repositories` 200. Phase 25's gate only made admin reads of individual repositories. The absence of an IngressClass or Gateway API is attributed to 25-RESEARCH (locked decision L-01), because no plan summary re-measured it.
5. **[Wording] The plan says "the provisioner is `WaitForFirstConsumer`".** That value is the StorageClass's volume binding mode, and the ADR says so. The provisioner name is omitted for identifier hygiene.

## Known Stubs

None.

## Threat Flags

None. T-25-34 was mitigated by the negative IPv4 grep and the identifier grep. T-25-35 was mitigated by attributing every value to its source. T-25-36 was mitigated by the empty ADR-020/021 diff. T-25-37 was mitigated because NEXUS-05 was flipped only here.

## Self-Check: PASSED

- FOUND: docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md
- FOUND: e04beac (lists the ADR, docs/adr/README.md and .planning/REQUIREMENTS.md)
