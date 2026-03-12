# ADR-008: Add NetworkPolicy Guidance to Kubernetes Deployment

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #5

## Context

The original document provided no NetworkPolicy guidance. Default Kubernetes behavior allows unrestricted pod-to-pod communication across all namespaces — any pod can reach any service on any port. The stack deploys DefectDojo, Nexus, SonarQube, Harbor, and Trivy Operator in separate namespaces, but namespace separation alone does not restrict network traffic without explicit NetworkPolicy resources. Agent 1 demonstrated the blast radius of this gap: a compromised application workload pod can reach the DefectDojo API (read, write, delete, or fabricate all security findings), the Nexus API (upload malicious packages into the cache), and the Harbor API (push malicious images). Agent 3 noted that DefectDojo's vulnerability inventory is an attacker's reconnaissance asset — it contains the complete list of known weaknesses in the system.

## Decision

A "Network Security" guidance section is added to the Phase 3 Kubernetes infrastructure documentation. It explains that default Kubernetes allows all pod-to-pod traffic and that NetworkPolicies are required to isolate security-sensitive services. A representative default-deny-ingress NetworkPolicy pattern is provided as a starting point. The isolation intent for each namespace is described (defectdojo, nexus, sonarqube, harbor, trivy-system should not be reachable from arbitrary application namespaces). Kubernetes NetworkPolicy documentation is linked. Full per-service production NetworkPolicy YAML is explicitly not provided — it is too cluster-specific to be accurate in a generic blueprint.

## Consequences

**Improved:** Implementers are explicitly informed that network isolation requires active configuration, and are given a starting pattern and conceptual model for doing so. The security gap from unrestricted lateral movement is documented rather than silently present.

**Tradeoff:** The guidance is approach-level plus a starting pattern, not a complete working configuration. Implementers must adapt NetworkPolicy rules to their specific cluster topology, CNI plugin, and service ingress requirements.
