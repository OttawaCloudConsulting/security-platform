# Phase 29: DefectDojo Live Validation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-26
**Phase:** 29-defectdojo-live-validation
**Areas discussed:** Exposure and TLS, Runner reachability, Live proof scope, Data layer and tokens

Pre-discussion live checks (read-only): no IngressClass, no Gateway API, no self-hosted runners; ClusterIssuers `letsencrypt-dns01-prod`/`-staging` Ready; LB VIPs in use on vlan43 at .60-.63 and .77.

---

## Exposure and TLS

| Option | Description | Selected |
|--------|-------------|----------|
| LB VIP + ghostunnel | Chart ingress off; LoadBalancer VIP, DNS-01 Certificate, ghostunnel (homepage pattern) | ✓ |
| Install ingress controller | New cluster-wide controller on one VIP; chart ingress runs as shipped | |
| Enable Cilium ingress | Turn on Cilium ingressController; cluster-wide CNI change | |

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone Deployment in overlay | ghostunnel proxies to django Service; public chart untouched | ✓ |
| Sidecar in django pod | Via upstream extra-containers value, if present | |
| You decide | Research picks | |

| Option | Description | Selected |
|--------|-------------|----------|
| 10.40.3.65 | Lowest unreferenced address | |
| Pick at execution | Executor checks live and asks | |

**User's choice (VIP):** Other: "use `sendmessage` to ask `cluster-team` for an IP address recommendation". The cluster-team session recommended 10.40.3.65 and reported that internal DNS is manual Pi-hole entries on 10.40.1.53. It also recommended a UniFi/ARP check before pinning.

| Option | Description | Selected |
|--------|-------------|----------|
| defectdojo.infra.ottawacloudconsulting.com | .infra convention, DNS-01 prod cert | |
| Also a .home SAN | Second SAN like homepage | ✓ |
| Other name | | |

---

## Runner reachability

| Option | Description | Selected |
|--------|-------------|----------|
| Self-hosted runner, import jobs only | ARC in cluster, only import/cleanup jobs route to it; v1.x tag | ✓ |
| Tailnet step in import job | Ephemeral tailnet join; needs tailnet + subnet router | |
| Public exposure | DefectDojo internet-facing | |
| In-cluster pull importer | Argo cron pulls artifacts; bypasses Phase 27 job | |

| Option | Description | Selected |
|--------|-------------|----------|
| Org runner group, selected repos | Reusable for later consumers | ✓ |
| Repo-scoped to security-platform | Tightest scope | |

| Option | Description | Selected |
|--------|-------------|----------|
| GitHub App, SealedSecret | Not person-bound | |
| Fine-grained PAT, SealedSecret | Simpler; expires; person-bound | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Repo variable DEFECTDOJO_RUNS_ON | Same mechanism as DEFECTDOJO_URL; old callers unchanged | ✓ |
| workflow_call input | Caller-file edit required | |
| You decide | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Ephemeral + egress NetworkPolicy | Egress limited to DefectDojo + GitHub | |
| Ephemeral only | ARC defaults; LAN reachable | ✓ |

**Notes:** A security note was given before the question: a self-hosted runner serving a public repo is a known risk. The operator accepted it, and also accepted having no runner-egress policy.

---

## Live proof scope

| Option | Description | Selected |
|--------|-------------|----------|
| security-platform itself | Realises 27 OQ5 side effect as the proof | ✓ |
| Dedicated test consumer repo | Mode B path | |
| Both | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Real PR lifecycle | New-finding PR, dispositions on ci/main, dispatch reimport, close PR | ✓ |
| Run proof script against live | Throwaway product in live instance | |
| Both | | |

| Option | Description | Selected |
|--------|-------------|----------|
| workflow_dispatch enough | Cron run observed opportunistically | ✓ |
| Require real cron run | Up to a day of latency | |

| Option | Description | Selected |
|--------|-------------|----------|
| Before first import | Dedup on from the start; ADR-026 item 1 stays open | ✓ |
| After some imports | Observe dedup-over-existing and recompute | |

---

## Data layer and tokens

| Option | Description | Selected |
|--------|-------------|----------|
| Bundled Bitnami | 26 D-05 default as shipped | ✓ |
| CloudNativePG cluster | Existing operator, external-PG recipe | |

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated least-priv user | ci-importer is_staff, non-superuser (ADR-024) | ✓ |
| Admin token | Full control if leaked | |

---

## Claude's Discretion

- The overlay directory name, where ARC lives and its chart version, the scale-set name and label.
- The `initializer.staticName` value and the ArgoCD hook/ignore settings, based on live measurement.
- The ghostunnel image tag and how cert reload is handled.
- Whether `ci-importer` is created manually or by a scripted step.

## Deferred Ideas

- The runner-egress NetworkPolicy, a GitHub App for ARC, CloudNativePG and backups, a cluster ingress controller, and a Mode B test consumer.
- Dedup-over-existing-findings and the recompute on real data.
- Internal DNS tracked in git.
