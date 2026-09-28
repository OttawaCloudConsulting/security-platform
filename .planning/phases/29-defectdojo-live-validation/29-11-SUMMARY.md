---
phase: 29-defectdojo-live-validation
plan: 11
subsystem: k8s-infrastructure
tags: [defectdojo, arc, reachability, hostaliases, cilium, networkpolicy, d-14, d-18, ddojo-05]
requires:
  - "29-08: DefectDojo live behind the ghostunnel LoadBalancer VIP 10.40.3.65"
provides:
  - "evidence/29-11-runner-image.txt: runner tag 2.337.0 (v2.337.0 published 2026-08-26T14:33:29Z), index sha256:e5496277...a1ef4, linux/amd64 sha256:50364809...56ec97, manifest HTTP 200"
  - "evidence/29-11-reachability-probe.txt: probe A NO-RESOLVE; probe B getent 10.40.3.65 + '200 0'; HOSTALIASES-TARGET: 10.40.3.65; both pods NotFound; default inventory unchanged"
  - "evidence/29-11-postgres-netpol.txt: passive D-14 measurement with VERDICT (allow path observed, deny path NOT verified)"
affects: [29-12, ADR-027, ADR-028]
tech-stack:
  added: []
  patterns:
    - "One-off `kubectl run --rm -i --restart=Never` probes under a narrow waiver, followed by events capture, NotFound assertion and a `get all -o name` diff against a committed pre-probe inventory"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-11-runner-image.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-11-reachability-probe.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-11-postgres-netpol.txt
  modified: []
decisions:
  - "29-11: operator approved the exact D-18 probe commands, verbatim: `approve-probes`"
  - "29-11: operator chose the D-14 method, verbatim: `passive-only`. The Postgres NetworkPolicy deny path is NOT verified (for ADR-027)"
  - "29-11: ARC runner pods REQUIRE hostAliases defectdojo.infra.ottawacloudconsulting.com -> 10.40.3.65 (measured: NO-RESOLVE without it; 200 0 with it)"
  - "29-11: runner image for 29-12 is ghcr.io/actions/actions-runner:2.337.0 (latest release, unchanged from the RESEARCH pin)"
  - "29-11: the hairpin was measured from occ-cs-k8worker01, the current L2 lease holder for the VIP. Other nodes are expected to behave the same via Cilium socket-LB, but that was not measured"
metrics:
  duration: "~8min of active execution (13:28Z-13:36Z), excluding the operator decision wait"
  completed: 2026-09-28
  tasks: 3
  files: 3
---

# Phase 29 Plan 11: Runner reachability probe and Postgres NetworkPolicy (D-18, D-14) Summary

Both runner hops are measured. Without `hostAliases`, a runner-image pod cannot resolve the Pi-hole-only name (`NO-RESOLVE`). With `hostAliases` pointing at 10.40.3.65, HTTPS `/login` returned `200 0`: HTTP 200 with TLS verified. The pod-to-VIP hairpin works, so no fallback is needed. **HOSTALIASES-TARGET: 10.40.3.65.** The runner tag for plan 29-12 is **2.337.0**. The operator chose `passive-only` for D-14: the Postgres allow path was observed and the deny path was not verified.

## For plan 29-12

| Item | Value | Source |
|---|---|---|
| Runner image | `ghcr.io/actions/actions-runner:2.337.0` | evidence/29-11-runner-image.txt |
| Index digest | `sha256:e5496277be5d09bc968b3d64911b74e219ac4a3f2edce956a3ecf9271bea1ef4` | ghcr manifest HEAD 200 |
| linux/amd64 digest | `sha256:5036480998280bb21e32ade9fe1b02b493861ac314b62ba1aea320b94f56ec97` | all 4 nodes x86_64 |
| hostAliases | `10.40.3.65` -> `defectdojo.infra.ottawacloudconsulting.com` (**required**) | evidence/29-11-reachability-probe.txt |
| 30-day rule | The pinned image stops receiving jobs 30 days after the next runner release | RESEARCH Pitfall 6 |

## Task 1: runner tag and D-18 reachability probe

- The runner tag was re-read in 8a995ba. The latest release is v2.337.0, the same as the RESEARCH pin.
- **Operator approval (verbatim):** `approve-probes`
- **Probe A** (`dd-reach-probe-a`, no hostAliases): `NO-RESOLVE`. The RESEARCH prediction held.
- **Probe B** (`dd-reach-probe-b`, hostAliases -> 10.40.3.65): getent returned `10.40.3.65`, and curl `--proto =https` to `/login` returned `200 0`.
- **Cleanup:** `--rm` removed both pods. `get pod` returned NotFound for both. `default` `get all -o name` matched the pre-probe inventory exactly (diff exit 0). The namespace still has no netpol, limitrange or resourcequota.
- **Residue:** the runner image (541,817,226 bytes) stays cached on occ-cs-k8worker01. The Scheduled/Pulled/Created/Started events stay until the default event TTL expires. No API objects remain.

**Measured reachability model:** an ARC runner pod cannot reach DefectDojo by name without `hostAliases`, because cluster DNS does not serve the Pi-hole-only `.infra` name. With `hostAliases` to the L2 VIP, the path works end to end with system-CA TLS verification. The scale set must therefore set `hostAliases` to 10.40.3.65.

**Caveat:** both probe pods were scheduled on occ-cs-k8worker01. That node holds the `cilium-l2announce-defectdojo-defectdojo-ghostunnel` lease. Cilium socket-LB translates the VIP at connect() on every node, so a runner on another node is expected to behave the same. That is a theory and was not measured.

## Task 2: D-14 method (checkpoint)

**Operator reply (verbatim):** `passive-only`

## Task 3: Postgres NetworkPolicy, passive

- NetworkPolicy `defectdojo-postgresql` selects the primary pod. It allows ingress on TCP/5432 from any peer, allows all egress, and sets policyTypes Ingress+Egress.
- The `defectdojo-postgresql-0` pod (10.0.1.1, worker01) is Cilium endpoint 3821, identity 6201. Ingress and egress enforcement are both Enabled; realized `policy-enabled` is `both`.
- Hubble on the local cilium-agent socket showed django (ID 13784) and celery-worker (ID 23303) -> 5432 as ALLOWED/FORWARDED. The full 4095-flow ring showed zero DROPPED.
- The endpoint-list block was re-captured with the header and endpoint 3821 rows only. The earlier capture had an unrelated crossplane endpoint 30, which is now removed.
- No probe pod was created for D-14. There was no exec into DefectDojo workloads; the only execs were read-only `cilium-dbg`/`hubble` commands in the cilium-agent container.

**VERDICT:** allow path OBSERVED. Deny path (non-5432 ingress dropped) NOT verified, by operator decision `passive-only`. ADR-027 should record the negative case as not verified.

## Commits

| Commit | Content |
|---|---|
| 8a995ba | Runner image re-read, pre-probe `default` inventory, passive netpol capture |
| 1fb948a | Probe A/B results, cleanup proof, VIP placement, D-14 VERDICT |

## Deviations from Plan

**1. [Rule 2 - Evidence completeness] Recorded the VIP lease holder next to probe B.** I ran one read-only `get lease`/`get svc`, which showed that the probe pods and the VIP holder share a node. This bounds what probe B proves. It is recorded as a caveat and changes no decision.

Otherwise the plan ran as written, with the context `admin@occ-new` in place of `<homelab-context>`.

## Known Stubs

None.

## Self-Check: PASSED

- The three evidence files exist, and all the plan's verify greps pass (NO-RESOLVE, `^200 0$`, HOSTALIASES-TARGET, tag, `defectdojo-postgresql`, `^VERDICT:`, `ssl_verify_result`)
- Commits 8a995ba and 1fb948a are present on the branch
- `kubectl get pod dd-reach-probe-a dd-reach-probe-b` returned NotFound for both
- DDOJO-05 is deliberately NOT marked complete
