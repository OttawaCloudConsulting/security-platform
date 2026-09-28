---
phase: 29-defectdojo-live-validation
plan: 09
subsystem: k8s-infrastructure
tags: [runbook, cilium, lb-ipam, vlan43, vip-inventory, defectdojo, d-19, docs]
requires:
  - "29-08a: defectdojo-ghostunnel LB Service live on 10.40.3.65 (selecting the django pod)"
provides:
  - "occ-k8s-cluster-config main 5c65ffb221efa4fd665afe4e24537f608081302c: PR #43 squash-merged; VLAN 43 VIP inventory in docs/upgrade/cilium-l2-vantage-host-runbook.md rebuilt from a live read (eight VIPs, including defectdojo-ghostunnel 10.40.3.65)"
  - "Live LB Service + pool evidence: evidence/29-09-lb-services-live.txt (captured 2026-09-28T12:36:27Z)"
affects: [29-08, 29-12, 29-14]
tech-stack:
  added: []
  patterns:
    - "VIP tables are rebuilt from a live kubectl LoadBalancer read plus the lbipam.cilium.io/ips annotation and IPautoAssign label, not from memory of earlier revisions"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-09-lb-services-live.txt
  modified:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-cluster-config/docs/upgrade/cilium-l2-vantage-host-runbook.md
decisions:
  - "29-09: operator Task 2 reply verbatim: \"approved\". This authorised the commit and the merge after green checks."
  - "29-09: .80/.81 (authentik-outpost-ldap/-radius) are recorded as `vlan43-dhcp` (pinned via annotation), not \"auto-assigned, may move\": both carry lbipam.cilium.io/ips, so the address is stable across Service recreation."
  - "29-09: .60 is authentik-outpost-proxy and .77 is homepage (live read). The 2026-09-08 correction note had these swapped and claimed homepage had no LB IP; both claims were false."
  - "29-09: PR #43 squash-merged as 5c65ffb221efa4fd665afe4e24537f608081302c at 2026-09-28T13:04:01Z, pinned by --match-head-commit d3d00bbceaae9fdd30ce00cad82f881968fe137b. No rulesets on main (rules/branches/main returned [])."
metrics:
  duration: "~30min (live read 12:36Z to merge 13:04Z, including the operator checkpoint)"
  completed: 2026-09-28
  tasks: 3
  files: 2
---

# Phase 29 Plan 09: VLAN43 VIP Inventory Refresh Summary

I rebuilt the VLAN 43 VIP inventory in the cluster-config Cilium L2 runbook from a live `kubectl get svc` LoadBalancer read. It now lists eight VIPs, including the DefectDojo ghostunnel at 10.40.3.65. The read also showed that the 2026-09-08 note had the owners of `.60` and `.77` swapped, so I fixed that too. After the operator approved the table, PR #43 was squash-merged to occ-k8s-cluster-config `main` (5c65ffb).

## Operator Decision (Task 2)

The operator was shown the 8-row live-vs-proposed table. The orchestrator re-read the live cluster on its own and got the same rows. The operator also saw the four decisions: the .80/.81 wording, Service names following live, the .60/.77 correction note and the `Revised:` line entry. The VLAN41 edgebridge observation was included as well.

Operator reply, verbatim: `approved`

## Measured VLAN 43 rows (live, 2026-09-28T12:36:27Z)

| Service | VIP | Pool |
|---|---|---|
| `authentik-outpost-proxy` | 10.40.3.60 | `vlan43-static` (pinned) |
| `argocd-server-lb` | 10.40.3.61 | `vlan43-static` (pinned) |
| `argo-argo-workflows-server` | 10.40.3.62 | `vlan43-static` (pinned) |
| `authentik-server` | 10.40.3.63 | `vlan43-static` (pinned) |
| `defectdojo-ghostunnel` | 10.40.3.65 | `vlan43-static` (pinned) |
| `homepage` | 10.40.3.77 | `vlan43-static` (pinned) |
| `authentik-outpost-ldap` | 10.40.3.80 | `vlan43-dhcp` (pinned via annotation) |
| `authentik-outpost-radius` | 10.40.3.81 | `vlan43-dhcp` (pinned via annotation) |

The evidence file has 8 live Services in 10.40.3.0/24, and the table has 8 rows. The count word is "eight" in both the topology cell and the bold heading.

## Tasks

| Task | Name | Commit | Files |
|---|---|---|---|
| 1 | Live LB read + rebuilt VLAN43 table | security_solution f50c581 (evidence); runbook edit left uncommitted per plan | evidence/29-09-lb-services-live.txt, runbook |
| 2 | Operator checkpoint | n/a (reply: `approved`) | none |
| 3 | Commit via gcommit, PR, checks, merge | cluster-config d3d00bb (branch), 5c65ffb (squash on main, PR #43) | docs/upgrade/cilium-l2-vantage-host-runbook.md |

Task 3 gates:

- I ran `bash .claude/scripts/gcommit <msgfile>` from the worktree root, with the subject exactly as the plan gives it and the Co-Authored-By/Claude-Session trailers. No heredoc was used.
- Pre-commit results: markdownlint Passed, C-1/C-4 Passed, and "regenerate docs/README.md index" Passed. That hook did not rewrite `docs/README.md`, so only one commit was needed. The commit touched 1 file (+23/-16).
- PR checks: `C-1 and C-4 parity` pass (8s) and `GitGuardian Security Checks` pass (37s). `gh pr checks --watch` exited 0.
- Rulesets: `rules/branches/main` returned `[]`. Squash is allowed. `delete_branch_on_merge` is false, so I left the remote branch `docs/vlan43-vip-inventory-refresh` in place and did not delete it by hand.
- The plan's automated verify passes: `git show origin/main:docs/upgrade/cilium-l2-vantage-host-runbook.md | grep 10.40.3.65` matches.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `.80`/`.81` pool wording**
- **Found during:** Task 1
- **Issue:** The plan's rule says an IP in .80-99 "without a pin" is labelled `vlan43-dhcp (auto-assigned — may move)`. The live read shows that ldap and radius carry the `lbipam.cilium.io/ips` annotation (`IPautoAssign: "true"`), so they are pinned. The "may move" wording would have been wrong.
- **Fix:** They are labelled `vlan43-dhcp` (pinned via annotation). The note under the table now explains the difference between pinned and truly auto-assigned addresses. The operator approved this in Task 2.
- **Commit:** cluster-config 5c65ffb

**2. [Rule 1 - Bug] Service names follow live**
- **Issue:** The earlier rows said `argocd-server` and `argo-workflows`. The live Service names are `argocd-server-lb` and `argo-argo-workflows-server`.
- **Fix:** The rows now use the live names.

**3. [Rule 1 - Bug] `.60`/`.77` ownership swap**
- **Issue:** The 2026-09-08 correction note said `.77` was authentik-outpost-proxy and that homepage had no LB IP. Live shows `.60` is authentik-outpost-proxy and `.77` is homepage.
- **Fix:** I replaced it with a `Correction 2026-09-28` note that records what live shows and warns that any ARP baseline taken against "authentik-outpost-proxy .77" was actually measuring homepage. The "Re-read the live VIP list" instruction and its command are kept.

**4. [Rule 2 - Doc accuracy] `Revised:` header line**
- **Fix:** I added a 2026-09-28 entry to the runbook's `Revised:` line, alongside the date changes the plan asked for.

**5. [Override] Worktree instead of branch-sync on the shared checkout**
- **Issue:** The shared cluster-config checkout is on another session's branch, `feat/lightrag-storageclasses` (339d571), and has the operator's uncommitted files. The plan's `checkout -B` and post-merge `branch-sync.sh` / `checkout main && pull` would have disturbed that work.
- **Fix:** All work happened in a scratchpad worktree on `docs/vlan43-vip-inventory-refresh`, based on origin/main fe7af30. After the merge I ran `git worktree remove` and then `git fetch origin` (origin/main fe7af30..5c65ffb). The shared tree was not checked out, pulled, reset or stashed, and it is still on `feat/lightrag-storageclasses`. The local branch `docs/vlan43-vip-inventory-refresh` still exists in the shared repo's ref store; I did not delete it.

**6. [Info] README index**
- The docs-index pre-commit hook left `docs/README.md` unchanged, so no second commit was needed. A graphify post-commit hook also started a background rebuild (log in `~/.cache/graphify-rebuild.log`). That is outside this repo and needs no action.

## Observations (not fixed; open follow-ups)

- **VLAN 41 edgebridge:** In the topology row, `edgebridge` 10.40.1.80 is described as "**auto-assigned** from `vlan41-dhcp` — may move". Live shows it carries the `lbipam.cilium.io/ips: 10.40.1.80` annotation, so it is pinned via annotation, just like authentik ldap/radius. This row was out of scope and left untouched. **Open follow-up:** fix the wording in a later cluster-config docs PR.
- **VLAN 44:** Live has no Services on 10.40.4.x, which matches "none recorded".
- `smarthome-pihole` 10.30.1.53 (VLAN 30) is outside the runbook's three announce VLANs, so there is nothing to record.

## Threat Model

T-29-16 is mitigated. The table was rebuilt from the captured live read and checked by the operator before the commit. T-29-SC was accepted: nothing was installed, and markdownlint ran through the repo's own pre-commit hook.

## Requirement Status

DDOJO-05 is **not** marked complete here. It stays open until 29-08 finishes.

## Next

Wave 4 is complete (9/20). Next is 29-08 (wave 5), which resumes from its Task 1.

## Self-Check: PASSED

- FOUND: 29-09-SUMMARY.md, evidence/29-09-lb-services-live.txt
- FOUND commits: security_solution f50c581; cluster-config d3d00bb (branch), 5c65ffb (origin/main, PR #43)
- origin/main runbook contains the defectdojo-ghostunnel 10.40.3.65 vlan43-static row (plan automated verify passes)
- STATE.md Plan line corrected by hand after state.advance-plan kept the stale 'next: 29-09' text; state.update-progress reported 'Progress field not found' , yet the frontmatter progress became 64/85% after these calls (verified correct: 63+1)
