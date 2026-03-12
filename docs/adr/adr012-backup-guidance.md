# ADR-012: Add Backup Guidance for Stateful Services

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #4

## Context

The original document contained no backup, restore, or disaster recovery guidance for any of the stateful services in the stack: DefectDojo (PostgreSQL database containing all vulnerability history, deduplication state, and SLA tracking), Nexus (blob store at `/nexus-data` containing all cached packages), SonarQube (PostgreSQL and Elasticsearch), and Harbor (PostgreSQL and registry storage). Agent 2 rated this Critical, identifying four specific data stores requiring backup and noting that Helm values used during installation were not stored in version control, making rebuild from scratch impossible even with intact data. Agent 3 described the specific consequences: loss of DefectDojo's PostgreSQL means rebuilding the entire vulnerability management history from scratch, and loss of Nexus blob store triggers re-downloading every cached package from upstream registries, which can take hours and stresses upstream bandwidth limits. The combination of no data backup and no configuration backup (inline `--set` flags with no persistence) created a complete recovery gap.

## Decision

A "Backup Considerations" section is added to the Phase 3 documentation. It covers: a `pg_dump` command for DefectDojo PostgreSQL with a CronJob skeleton showing how to schedule it; PVC snapshot guidance for the Nexus `/nexus-data` volume explaining what is lost if the blob store is not backed up; a cross-reference to ADR-007 (Helm values externalization) as the mechanism for preserving service configuration; and a note that Harbor and SonarQube also require backup if deployed. The guidance is approach-level — a complete production backup automation system is outside the scope of this blueprint, but the mechanism and consequence of not backing up each service is documented.

## Consequences

**Improved:** Implementers are informed of the backup requirement for each stateful service, the specific data that is at risk, and a concrete starting mechanism for each. The recovery gap from combining missing data backup with missing configuration backup is closed at the awareness level.

**Tradeoff:** Backup operations require cluster access and persistent storage for backup artifacts. Scheduling automation (Kubernetes CronJob for `pg_dump`) is described but left to the implementer to configure for their specific cluster and storage environment. Backup testing and restore verification procedures are not covered — these require a functioning restore target, which is cluster-specific.
