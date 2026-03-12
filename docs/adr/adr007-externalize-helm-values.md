# ADR-007: Externalize Helm Values to Version-Controlled Files

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #4

## Context

All Helm installation commands in the original document used inline `--set` flags exclusively. The DefectDojo deployment used `helm install defectdojo ... --set django.ingress.enabled=true --set host="defectdojo.local" --set tag="latest"`. The Nexus deployment and other services followed the same pattern. Inline `--set` flags are ephemeral: they exist only in shell history. If the Kubernetes cluster is lost, a node is replaced, or the Helm release is accidentally deleted, there is no record of the original configuration values. The service cannot be rebuilt from scratch without reconstructing configuration from memory or command history. Agent 2 flagged this alongside the backup finding: not only is the data at risk, but the configuration required to restore the service is also at risk.

## Decision

Helm install commands are shown alongside a corresponding `values.yaml` example for each service (e.g., `defectdojo-values.yaml`, `nexus-values.yaml`). Installation instructions use the `helm install -f values.yaml` form. The document instructs the reader to store these `values.yaml` files in version control alongside the rest of their infrastructure code.

## Consequences

**Improved:** Service configuration is durable and version-controlled. A complete cluster rebuild or service restore begins from the `values.yaml` file rather than from memory. Configuration drift is visible via git history.

**Tradeoff:** One additional file per deployed service must be created and maintained. This is a small and standard operational practice for any Helm-managed service.
