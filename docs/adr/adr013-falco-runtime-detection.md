# ADR-013: Add Falco CE + FalcoSidekick for Kubernetes Runtime Anomaly Detection

**Status:** Accepted
**Date:** 2026-02-26
**Addresses:** Known Gap — Security Logging, Monitoring, and SIEM

## Context

The previous red-team response (ADR-001 through ADR-012) documented "Security Logging, Monitoring, and SIEM" as a known gap. The gap analysis noted: "Falco, for example, detects container runtime anomalies that none of the static tools can surface." The entire original stack was static analysis only — every tool ran against source code, manifests, or built artifacts. No tool observed runtime behavior in the running Kubernetes cluster.

The specific threats undetected without runtime monitoring:

- A compromised application pod executing `/bin/sh` to establish a reverse shell
- A process inside DefectDojo or Nexus spawning an unexpected child process (post-exploitation lateral movement)
- Privilege escalation via `setuid` binaries or Linux capability abuse inside containers
- `kubectl exec` into security-sensitive pods (defectdojo, nexus, falco-system)
- Unexpected outbound network connections from security namespace pods (potential C2 communication or data exfiltration)
- Writes to `/etc` or other read-only filesystem locations inside immutable container images

A full SIEM (Wazuh, Splunk, Elastic SIEM) was explicitly ruled out due to operational overhead — a SIEM at meaningful fidelity is a dedicated workload, not a single-developer addition. Falco is the right scope for this stack: a lightweight, Kubernetes-native DaemonSet that fires on specific syscall patterns without requiring a dedicated security operations function to maintain.

## Decision

Falco CE + FalcoSidekick are added to the stack as a required Phase 4 component. Falco runs as a DaemonSet on every node using the eBPF driver (preferred; falls back to kernel module). FalcoSidekick provides alert routing (Slack webhook, generic webhook to Alertmanager) and a web UI dashboard.

Four custom Falco rules are added targeting this stack specifically:

1. **Shell spawned in security namespace pod** — detects unexpected shell execution in defectdojo, nexus, falco-system, kyverno, trivy-system
2. **kubectl exec into security namespace** — uses the Kubernetes audit log plugin to detect API-level exec access to sensitive pods
3. **Unexpected outbound connection from security namespace** — detects pods initiating connections to unexpected destinations
4. **Write to /etc in container** — detects filesystem mutations in typically immutable containers

Wazuh (full SIEM) is documented as a future consideration for organizations requiring broader log analysis, file integrity monitoring, and SIEM correlation beyond Kubernetes runtime events.

**Why Falco over Wazuh for this stack:** Falco is lightweight (~512Mi per node, DaemonSet), Kubernetes-native, CNCF Graduated, and integrates directly with the K8s audit log. Wazuh is the right answer when dedicated ops resources exist for tuning and maintaining a full SIEM. For a single-developer practice, Falco provides 80% of the runtime detection value at 20% of the operational complexity.

## Consequences

**Improved:** The stack now detects runtime anomalies that no static tool can surface. Container escapes, privilege escalation attempts, and unexpected process execution are surfaced in near-real-time rather than discovered after the fact (if discovered at all).

**Tradeoff:** Falco adds DaemonSet overhead (~512Mi per node). The Kubernetes audit log plugin requires cluster-level configuration (API server audit webhook) that is provider-specific — the document describes the requirement but cannot provide a universal configuration. Custom rule tuning is required to suppress false positives from legitimate tooling behavior (e.g., operations tooling that runs inside security namespace pods intentionally).
