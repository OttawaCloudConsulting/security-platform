---
phase: 26-defectdojo-generic-chart
verified: 2026-09-24T23:59:00Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
---

# Phase 26: DefectDojo Generic Chart Verification Report

**Phase Goal:** Public Helm chart deploys DefectDojo with external ingress and cert-manager-issued TLS, generic for any Kubernetes cluster: environment-specific values (hostnames, StorageClass overrides, ClusterIssuer names) are consumer-supplied, never baked into the public package.
**Verified:** 2026-09-24T23:59:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Verification method

Verified against `OttawaCloudConsulting/security-platform` `origin/main` at `71a112e` (confirmed via `git fetch` + `git rev-parse origin/main`; local clone working tree clean, on `main`, up to date with `origin/main`). Ran the offline gate myself (not trusted from evidence files). Reproduced the reviewer's two measured warnings independently with fresh `helm template` renders. Diffed the live-smoke evidence SHA (`60205bd`, pre-merge feature branch) against merged `71a112e` restricted to `kubernetes/defectdojo/` — only `README.md` changed (3 insertions / 2 deletions, the PR #20 `helm repo add` fix), so the chart mechanics the live smoke exercised (`Chart.yaml`, `Chart.lock`, `values.yaml`, `templates/`) are byte-identical to what is on `main` today. The live-smoke evidence therefore applies to the current, merged chart. Did not run the live smoke or any kubectl/helm install/upgrade myself (real homelab kube context risk, per task instructions) — relied on the 26-05 evidence file plus the orchestrator's confirmed post-PR#20 clean-worktree rerun (ALL PASS 12, rc=0).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Chart is public on `security-platform` `main`, not only a branch | VERIFIED | `git rev-parse origin/main` = `71a112e02bf...`, matches local clone HEAD; `kubernetes/defectdojo/{Chart.yaml,Chart.lock,values.yaml,templates/validate-tls.yaml,README.md}` present and populated on that tree |
| 2 | Offline gate passes non-vacuously (20 checks) | VERIFIED | Ran `bash scripts/check-defectdojo-chart.sh` myself against the committed tree: `PASS - 20 checks, 0 failures` |
| 3 | Ingress + cert-manager TLS work end-to-end on a real cluster (documented path) | VERIFIED | 26-05-live-smoke.txt: `KIND-CERT-READY: PASS`, `KIND-TLS-LOGIN-200: PASS` (verified against issued CA, not `-k`), `KIND-LOGIN: PASS` (real admin login POST, 302→200 session), `KIND-CELERY-PING: PASS` (broker round-trip). `ALL PASS - 12 live check(s) ... rc=0`. Confirmed the evidence SHA's chart files are identical to `origin/main`'s (diff restricted to README only) |
| 4 | D-11: TLS-on + no issuer fails fast, naming the cert-manager key, on the documented consumer path | VERIFIED | Reproduced myself: bare `helm template` with TLS on (default) errors with the exact message naming `cert-manager.io/cluster-issuer`; supplying it via the documented `defectdojo.django.ingress.annotations."cert-manager.io/cluster-issuer"` path renders cleanly (20 objects) |
| 5 | No environment-specific values (hostnames, StorageClass, ClusterIssuer names, IngressClass) baked into the public chart | VERIFIED | `values.yaml`: `host: defectdojo.example.com` (placeholder), `ingressClassName` key absent (commented, D-12), `storageClass` key absent (D-08). Grep for homelab-specific strings across `values.yaml`/`README.md` found none. Rendered manifest (with issuer supplied) has no `storageClassName` and no `ingressClassName` field |
| 6 | Requirement DDOJO-01 traced end to end, no orphaned requirement IDs for this phase | VERIFIED | `.planning/REQUIREMENTS.md`: `[x] DDOJO-01`, mapped `Phase 26 | Complete`; all 7 plans (26-01..26-07) declare `requirements: [DDOJO-01]`, none declare an ID absent from REQUIREMENTS.md, and REQUIREMENTS.md maps no other ID to Phase 26 |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `kubernetes/defectdojo/Chart.yaml` | Wrapper manifest, pinned `defectdojo` 1.9.53 dependency | VERIFIED | `version: 1.9.53`, `appVersion: "3.3.200"`, single dependency entry, no vendored templates for upstream workloads |
| `kubernetes/defectdojo/Chart.lock` | Committed lock with digest | VERIFIED | `digest: sha256:166631...` present |
| `kubernetes/defectdojo/values.yaml` | Thin override surface (117 lines) | VERIFIED | Ingress/TLS/secrets/persistence/resources only; rest passes through |
| `kubernetes/defectdojo/templates/validate-tls.yaml` | Render-time fail guard for cert-manager issuer (D-11) | VERIFIED (with a documented-path caveat, see Anti-Patterns WR-01) | Only template in the wrapper; fails fast on the documented input path |
| `kubernetes/defectdojo/README.md` (350 lines) | Consumer documentation | VERIFIED, with two known factual defects (WR-02, WR-03) that do not block the documented happy-path install |
| `scripts/check-defectdojo-chart.sh` (485 lines) | Standing offline gate, 20 checks | VERIFIED (functionally); one latent gate-quality gap, see WR-05 |
| `scripts/defectdojo-live-smoke.sh` (744 lines) | Live kind smoke | VERIFIED via evidence + SHA-identity check above |
| `docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md` | Accepted ADR with "What was NOT verified" | VERIFIED | Status: Accepted; contains `## What was NOT verified` section (5 enumerated items) |
| `docs/adr/README.md` | ADR-023 index row | VERIFIED | Row present, links to the ADR file, status Accepted |
| `.planning/REQUIREMENTS.md` | DDOJO-01 marked Complete | VERIFIED | `[x] **DDOJO-01**`, `Phase 26 | Complete` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `check-defectdojo-chart.sh` | `kubernetes/defectdojo` | `helm lint` / `helm template --namespace defectdojo` | WIRED | Ran it myself, 20/20 pass |
| `defectdojo-live-smoke.sh` | `kind-dd-smoke` context | `--kube-context "$KIND_CONTEXT"` on every call | WIRED | Confirmed via grep (line 504 `helm install ... --kube-context "$KIND_CONTEXT"`); 1 `helm install`, 0 `helm upgrade` occurrences (D-15 satisfied) |
| `defectdojo-live-smoke.sh` | `https://defectdojo.smoke.test:18443/login` | `curl --resolve ... --cacert` | WIRED | Confirmed `--cacert "$OUT/ca.crt"` used on both TLS-verification and login curl calls; no `-k` found |
| `kubernetes/defectdojo/README.md` | ADR-023 | README cites ADR-023 by number | WIRED | Line 350 on `origin/main`: "recorded in ADR-023 in the ... documentation repository" |

### Data-Flow Trace (Level 4)

Not applicable in the strict sense (no dashboard/UI rendering pipeline), but the equivalent for a Helm chart — "does the guard actually see what the real Ingress gets" — was traced and found to have a real gap: see WR-01 below. The guard's `$ing.annotations` map is not the same map the rendered Ingress receives when `extraAnnotations` is also used; confirmed via direct `helm template` renders producing a divergent effective annotation set from what the guard validates.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `kubernetes/defectdojo/templates/validate-tls.yaml:35-43` | WR-01: guard reads `django.ingress.annotations` only, ignores `extraAnnotations` which upstream also merges into the Ingress | WARNING | Reproduced independently: `--set 'defectdojo.extraAnnotations.cert-manager\.io/cluster-issuer=x'` alone fails the render (false rejection); combined with a second issuer set via `django.ingress.annotations` it renders successfully with **both** issuer annotation keys on the real Ingress (false acceptance — exactly the ambiguous case the guard exists to catch). Does not block the phase goal: README (line 324) documents only `defectdojo.django.ingress.annotations` as the supported path, and that path's fail-fast and success cases both work correctly, as measured. Needs a follow-up PR to `security-platform` (build the effective merged map with `mergeOverwrite`, add a gate check for the mixed-path case) |
| `kubernetes/defectdojo/README.md:66` | WR-02: Secret-naming table wrong for release names that merely contain, but are not equal to, `defectdojo` | WARNING | Reproduced: release `my-defectdojo` renders Secret references to `my-defectdojo`, not `defectdojo`. The README's own worked install example (`helm install defectdojo kubernetes/defectdojo`, line 201) uses the exact release name for which the table is correct, so the documented happy path is not broken — only the general statement is wrong for other release names. Needs a follow-up PR to fix the wording |
| `kubernetes/defectdojo/README.md:85-117` | WR-03: Secret recipe's `read -rsp` is bash-only; fails silently in zsh (macOS default shell) and can apply an empty `DD_ADMIN_PASSWORD`, the exact leak the README warns about | WARNING | Not independently re-measured by me (accepted reviewer's finding, plausible and specific); does not affect the chart itself, only an operational recipe. Follow-up PR |
| `scripts/check-defectdojo-chart.sh:90-93` | WR-04: preflight hint still prints the build-only `helm dependency build` command that ADR-023 itself documents as failing on a fresh clone (needs `helm repo add` first) | WARNING | Confirmed the stale command is still present at those lines on `main`. Cosmetic/DX issue, not a functional gate defect (the 20 checks still pass on a properly-prepared tree). Follow-up PR |
| `scripts/check-defectdojo-chart.sh:53-63` | WR-05: SKIP guard for a missing `validate-tls.yaml` still fires now that the chart is complete and public, so deleting the TLS guard makes the gate exit 0 (green-with-SKIP) instead of failing | WARNING | Confirmed the guard code is unchanged and still present as of `main`. This is the most consequential of the five warnings for future robustness (a regression that silently disables D-11 enforcement would go undetected by this gate), but it describes a *latent* risk to a future change, not a defect in what is deployed today — the guard is present and functioning now. Follow-up PR; consider also wiring the gate into CI, since neither `pr-security.yml` nor `security.yml` currently runs it |

None of the five warnings represents a chart default that bakes in an environment-specific value, a broken documented consumer path, or a reversal of an accepted decision — the discriminator used to decide BLOCKER vs WARNING here. All five are genuine, independently reproduced defects that should be fixed in a follow-up PR to `security-platform`.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|--------------|-------------|--------------|--------|----------|
| DDOJO-01 | 26-01 through 26-07 | Public Helm chart deploys DefectDojo with external ingress and cert-manager-issued TLS | SATISFIED | Chart merged to `origin/main`, offline gate 20/20 pass (re-run by me), live smoke 12/12 pass with genuine TLS/login/broker checks (evidence + SHA-identity confirmed), no orphaned requirement IDs found for Phase 26 |

### Human Verification Required

None. All must-haves resolved programmatically: chart existence, gate execution, guard behavior, and generic-defaults were independently re-verified via `helm template`/`helm lint`/git diff rather than trusted from SUMMARY claims. The live smoke's real-cluster behavior (Certificate issuance, TLS handshake, session cookie, Celery ping) is not something I re-ran myself per the task's explicit instruction not to touch the live homelab context, but the evidence file's SHA was confirmed identical to the merged chart's mechanics, and the orchestrator's separately-reported clean-worktree rerun (ALL PASS 12, rc=0 after PR #20) corroborates it. This is treated as sufficiently strong evidence, not a human-verification gap.

### Gaps Summary

No blocking gaps. The phase goal — a public, generic Helm chart that deploys DefectDojo with external ingress and cert-manager TLS, with all environment-specific values left to the consumer — is achieved and independently verified against the merged `origin/main` tree, not just SUMMARY claims. Five WARNING-level defects (WR-01 through WR-05) were found and independently confirmed; none breaks the documented consumer contract or bakes an environment value into the public package. Recommend a follow-up PR to `security-platform` addressing WR-01 (annotation-map guard gap, most important for defense-in-depth), WR-05 (SKIP guard regression risk, most important for keeping the gate honest going forward), and the two documentation defects (WR-02, WR-03), plus the low-cost DX fix WR-04.

---

_Verified: 2026-09-24T23:59:00Z_
_Verifier: Claude (gsd-verifier)_
