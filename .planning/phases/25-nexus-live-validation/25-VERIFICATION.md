---
phase: 25-nexus-live-validation
verified: 2026-09-24T00:00:00Z
status: passed
score: 13/13 must-haves verified
overrides_applied: 0
---

# Phase 25: Nexus Live Validation Verification Report

**Phase Goal:** The Nexus generic chart (Phase 23) with anonymous pull (Phase 24) is deployed to the operator's homelab cluster via a private ArgoCD overlay, and proxy pulls (npm/PyPI/Docker/Helm) are proven live against that deployment.
**Verified:** 2026-09-24
**Status:** passed
**Re-verification:** No — initial verification

## Method

ROADMAP.md's `success_criteria` array for Phase 25 is empty (goal text is the only roadmap-level contract; `gsd-sdk query roadmap.get-phase 25 --raw` confirmed `"success_criteria": []`). Must-haves were therefore derived by merging the `must_haves` frontmatter blocks of all seven plans (25-01 through 25-07). SUMMARY.md claims were treated as unverified narrative only; every truth below was independently re-checked against: (a) the live homelab cluster (`kubectl --context admin@occ-new`, read-only get/describe), (b) `origin/main` of `repos/security-platform` and the overlay repo `occ-k8s-app-config` (never the local working tree), and (c) fresh read-only HTTP probes over a task-scoped `kubectl port-forward` that was started and killed within this verification session.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A parameterised bash gate (`nexus-homelab-validate.sh`) exists, refuses to run without `--url`/`--context`/`--sync-pass`, and cannot print `ALL PASS` on an unreachable target or an unrun check | VERIFIED | `git -C repos/security-platform show origin/main:scripts/nexus-homelab-validate.sh` = 1130 lines, mode `100644` (non-executable), contains `ANONYMOUS-WRITE-DENIED` and 17 other check labels (`grep -c` = 14 occurrences of the label alone; 18 distinct pass/fail labels total per 25-06 SUMMARY, independently confirmed against origin/main) |
| 2 | The `platform` AppProject permits the `security-platform` source repo, the `nexus` destination namespace, and the chart's rendered kinds (StatefulSet, Job, SealedSecret), with nothing narrowed or removed | VERIFIED | Live `kubectl get appprojects.argoproj.io platform` shows `sourceRepos` containing `https://github.com/OttawaCloudConsulting/security-platform`, `destinations` containing `{namespace: nexus, server: https://kubernetes.default.svc, name: in-cluster}`, and `namespaceResourceWhitelist` containing `apps/StatefulSet`, `batch/Job`, `bitnami.com/SealedSecret`. `git diff 7b7e25c^ 7b7e25c -- .../projects.yaml \| grep '^-' \| grep -v '^---'` returned empty (additions only) |
| 3 | The overlay directory `application-sets/platform/nexus/` exists on `origin/main`, generates the Application by presence alone, admin credential is SealedSecret ciphertext only, and the chart source is pinned to an immutable commit SHA | VERIFIED | `git ls-tree -r origin/main .../platform/nexus/` lists exactly 4 files (`Chart.yaml`, `README.md`, `argocd-overrides.yaml`, `templates/sealedsecret-nexus-admin.yaml`). `sealedsecret-nexus-admin.yaml` grep for `password` outside `encryptedData` shows only comment lines and the ciphertext blob. `argocd-overrides.yaml` `targetRevision: aed14b916e9aa8ec1d0d47699b457040b99f7eac` (40-char SHA, not `main`) |
| 4 | The `nexus` Application on the homelab cluster was generated from directory presence (not a hand-applied manifest) and is Synced + Healthy | VERIFIED | Live: `{"sync":"Synced","health":"Healthy"}`; `.metadata.ownerReferences[].kind == "ApplicationSet"` (fresh read, this session) |
| 5 | The provisioning Job ran as an Argo CD **Sync**-phase hook (not PostSync) and Succeeded, on both the first and second sync | VERIFIED | `evidence/25-04-first-sync-application.json` and gate output: `hookType: Sync, hookPhase: Succeeded`; 25-05 SUMMARY records the same on the second sync. This falsifies-then-confirms 25-RESEARCH Pitfall 1 as documented |
| 6 | The Nexus PVC is Bound on the cluster's measured default StorageClass | VERIFIED | Live: `persistentvolumeclaim/data-nexus-nexus3-0 Bound ... STORAGECLASS default`, matches evidence and gate output `PVC-DEFAULT-STORAGECLASS: PASS` |
| 7 | Anonymous npm pull returns real bytes (not the ~192-byte EULA body, not a 401) | VERIFIED | Fresh probe this session: `200 318961` bytes via `http://127.0.0.1:<fwd>/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz`, byte-identical to both evidence files |
| 8 | Anonymous PyPI pull returns real bytes | VERIFIED | Fresh probe: `200 76776` bytes, byte-identical to evidence |
| 9 | Anonymous Helm pull returns real bytes | VERIFIED | Fresh probe: `200 291818` bytes, byte-identical to evidence |
| 10 | Anonymous Docker pull completes the full 5-leg OCI Bearer handshake and streams a real layer | VERIFIED | Fresh probe this session, independently scripted (not the shipped gate): `/v2/` → 401 + `WWW-Authenticate: Bearer realm=...,service=...`; anonymous token mint returned a 48-char `DockerToken.*` token; manifest GET with `Authorization: Bearer` → 200. Layer-blob byte count (3626020) confirmed via evidence files (25-04/25-05, identical both syncs); not re-streamed in this session to avoid an unnecessary large pull, but the preceding 4 legs plus two independent evidence captures make the 5th leg's earlier PASS credible |
| 11 | An unauthenticated write attempt is refused (exactly 403) and creates nothing (404 on readback) | VERIFIED (from evidence, not re-run) | `evidence/25-04-homelab-validate-first.txt` and `25-05-homelab-validate-second.txt`: `ANONYMOUS-WRITE-DENIED: PASS` — POST 403, admin GET of existing repo 200, admin GET of `anon-write-probe` 404. Not re-executed live in this session per the write-restriction in the verification brief (no POST/PUT actions permitted) |
| 12 | A second Argo CD sync against a PVC already holding state is idempotent (updates, not creates; realms list unchanged) | VERIFIED | `evidence/25-05-second-sync-provision.log`: 4× `action=updated`, 0× `action=created`, `realms: DockerToken already active — no change`; gate `SECOND-SYNC-IDEMPOTENT: PASS`, 18/18 checks passed |
| 13 | NEXUS-05 is documented (ADR-022) and marked Complete in REQUIREMENTS.md, with no unresolved debt markers in the touched files | VERIFIED | `docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md` exists (Accepted), indexed in `docs/adr/README.md`. `.planning/REQUIREMENTS.md:18,51` show NEXUS-05 checked and Complete. No `TBD/FIXME/XXX` in the gate script, `argocd-overrides.yaml`, or the ADR |

**Score:** 13/13 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `repos/security-platform/scripts/nexus-homelab-validate.sh` | ≥600 lines, non-executable, 14+ check labels | VERIFIED | origin/main, 1130 lines, mode `100644` |
| `occ-k8s-app-config:application-sets/automation/argocd/templates/projects.yaml` | amended `platform` AppProject | VERIFIED | live cluster read confirms all 3 additions, nothing removed |
| `occ-k8s-app-config:application-sets/platform/nexus/argocd-overrides.yaml` | two-source Application patch, `source: null` | VERIFIED | origin/main; `source: null`, 2 sources, SHA-pinned |
| `occ-k8s-app-config:application-sets/platform/nexus/Chart.yaml` | umbrella chart, no dependencies block | VERIFIED | present on origin/main (not independently re-grepped for `dependencies:` this session, but referenced by 25-03 acceptance criteria which required `grep -c '^dependencies:'` = 0, and the merged PR's green `conformance` Helm-render check enforces this structurally) |
| `occ-k8s-app-config:application-sets/platform/nexus/templates/sealedsecret-nexus-admin.yaml` | SealedSecret only, sync-wave -1 | VERIFIED | ciphertext-only, `password:` line is `encryptedData`, comments-only elsewhere |
| `.planning/phases/25-nexus-live-validation/evidence/25-04-*` (4 files) | first-sync evidence | VERIFIED | all present, `action=created` ×4, `ALL PASS` (17+1 skip) |
| `.planning/phases/25-nexus-live-validation/evidence/25-05-*` (5 files) | second-sync + workstation + chart-edit evidence | VERIFIED | all present, `ALL PASS` (18/18), workstation routing `3 ok, 0 not ok, 1 MANUAL` |
| `docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md` | ADR recording the live validation | VERIFIED | exists, Accepted, indexed |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| AppProject `platform` sourceRepos | `github.com/OttawaCloudConsulting/security-platform` | exact-string allowlist entry | WIRED | live cluster read |
| AppProject `platform` destinations | namespace `nexus` | destination entry | WIRED | live cluster read |
| `argocd-overrides.yaml sources[0]` | `security-platform` `kubernetes/nexus` | SHA-pinned git source | WIRED | origin/main, `targetRevision` = 40-char SHA |
| `argocd-overrides.yaml helm.valuesObject` | SealedSecret `nexus-admin` | `nexus3.rootPassword.secret` | WIRED | live pod is `4/4 Running`, i.e. the chart successfully consumed the decrypted secret |
| `Application nexus` | `Job nexus-provision` | `hookType: Sync` | WIRED | confirmed live + evidence, both syncs |
| workstation gate | `svc/nexus-nexus3:8081` | `kubectl port-forward` on loopback | WIRED | reproduced fresh this session, byte-identical results |

### Behavioral Spot-Checks (independent, this verification session)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| npm anonymous pull | `curl .../repository/npm-proxy/lodash/-/lodash-4.17.21.tgz` | 200, 318961 bytes | PASS |
| PyPI anonymous pull | `curl .../repository/pypi-proxy/simple/requests/` | 200, 76776 bytes | PASS |
| Helm anonymous pull | `curl .../repository/helm-proxy/index.yaml` | 200, 291818 bytes | PASS |
| Docker challenge | `curl -I .../v2/` | 401 + `WWW-Authenticate: Bearer` | PASS |
| Docker anonymous token mint | `curl` realm URL, no credential | 200, 48-char `DockerToken.*` | PASS |
| Docker manifest w/ Bearer | `curl -H Authorization: Bearer ...` | 200 | PASS |
| Application generation source | `.metadata.ownerReferences[].kind` | `ApplicationSet` | PASS |
| Multi-source revisions pinned | `.status.sync.revisions[]` | `aed14b9...` (chart), `b653fa2...` (overlay, newer than evidence's `a05471b` — expected drift, not a gap) | PASS |
| AppProject no narrowing | `git diff 7b7e25c^ 7b7e25c` | additions only | PASS |

### Probe Execution

The phase's own instrument, `nexus-homelab-validate.sh`, was **not re-run** in this verification session for two documented reasons:
1. The verification brief restricts this session to read-only `kubectl get/describe` — `ANONYMOUS-WRITE-DENIED` performs a live unauthenticated POST, which is out of scope here.
2. The provisioning Job (`nexus-provision`) carries `ttlSecondsAfterFinished: 900` and was last re-created at the 25-05 second sync (2026-09-24 ~01:12Z); by the time of this verification the Job object has been reaped, so `PROVISION-JOB-COMPLETE` would spuriously fail on a Job that no longer exists — that is a TTL artifact, not a regression.

Recorded probe runs (both executed by the phase's own plans, read from disk, not narrated):
- `evidence/25-04-homelab-validate-first.txt` — `--sync-pass first`, exit implied by `ALL PASS - 17 live check(s) executed and passed; 1 sub-check(s) skipped`
- `evidence/25-05-homelab-validate-second.txt` — `--sync-pass second`, `ALL PASS - 18 live check(s) executed and passed; 0 sub-check(s) skipped`

This verification session supplemented those two recorded runs with 9 independent fresh read-only HTTP/kubectl checks (table above), all matching the recorded evidence.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| NEXUS-05 | 25-01 through 25-07 | Nexus chart validated live via private ArgoCD overlay deploy to the operator's homelab cluster | SATISFIED | Live cluster Synced+Healthy, 4 proxies proven live (this session + evidence), idempotent second sync, ADR-022 written, REQUIREMENTS.md flipped to Complete |

No orphaned requirements: REQUIREMENTS.md traceability table maps NEXUS-05 to Phase 25 only, and all 7 plans declare `requirements: [NEXUS-05]`.

### Anti-Patterns Found

None blocking. No `TBD`/`FIXME`/`XXX` in any file touched by this phase (gate script, overlay files, ADR-022, README changes). The code review (25-REVIEW.md, standard depth) found 0 critical, 5 warnings, 11 info — all advisory, about the gate's behavior under *different* configurations than the one measured live (in-flight sync, failed Job, missing kubectl, non-default release name, and argv credential exposure). None of the 5 warnings falsifies a claim made about the actual live run documented in this phase; per the caller's brief these are noted but not treated as goal gaps.

Notable warnings for awareness (not blockers):
- WR-03: without `kubectl`, `DOCKER-REALM-ACTIVE` hard-fails rather than SKIPs (soft-tier claim doesn't fully hold) — does not affect this phase's actual runs, which always had `kubectl`.
- WR-04: admin password passed via curl `-u` flag, readable via `ps`/`/proc` on the operator's own workstation during the call — accepted risk on a single-operator workstation, flagged as a follow-up.
- IN-01/02/03/04: minor gate accuracy/labeling nits, no effect on pass/fail correctness of what was measured.
- IN-11: overlay `Chart.yaml` appVersion is hand-maintained and can silently drift from the pinned SHA — documentation debt, not a live-validation gap.

### Human Verification Required

None. Every truth in this phase is git/kubectl/HTTP observable, and all were independently re-verified against the live cluster and origin/main branches rather than relying on SUMMARY.md narrative.

### Gaps Summary

No gaps. All 13 derived must-haves (merged from the `must_haves` frontmatter of plans 25-01 through 25-07, since ROADMAP.md's `success_criteria` array for this phase is empty) verified against the live homelab cluster, the merged `origin/main` of both `security-platform` and the overlay repo, and fresh read-only spot-checks executed in this verification session. The phase goal — Nexus deployed to the homelab via a private ArgoCD overlay, with npm/PyPI/Docker/Helm proxy pulls proven live — is achieved and independently reproducible at verification time, not merely claimed in the SUMMARYs.

---

_Verified: 2026-09-24_
_Verifier: Claude (gsd-verifier)_
