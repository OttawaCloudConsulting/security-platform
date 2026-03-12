# ADR-006: Pin DefectDojo to Specific Version Tag

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #8

## Context

The original Helm installation command for DefectDojo used `--set tag="latest"`, appearing in two locations in the document: the Phase 3 initial deployment section and the Phase 4 re-deployment section. The `latest` tag in a Helm chart is a floating reference — any pod restart, node replacement, or `helm upgrade` command will pull whatever Docker image is currently tagged `latest` in the DefectDojo image registry. DefectDojo versions can include breaking database schema migrations. A spontaneous upgrade during a pod restart could introduce schema incompatibilities that break the import pipeline scripts (which reference specific API endpoints and field names) or corrupt the vulnerability database. Agent 2 identified this as a silent operational risk. Agent 3 noted that security infrastructure must be pinned to specific tested versions for deployments to be reproducible.

## Decision

The Helm install command is updated to use `--set tag="2.x.y"` with a comment directing the reader to check the DefectDojo releases page (github.com/DefectDojo/django-DefectDojo/releases) for the current stable version at time of deployment. An upgrade procedure note is added: check release notes for breaking changes, run a database backup first, then execute `helm upgrade`.

## Consequences

**Improved:** DefectDojo deployments are reproducible and stable between explicit upgrade decisions. Pod restarts and Helm operations do not silently change the running software version or trigger unexpected schema migrations.

**Tradeoff:** The reader must actively look up the current stable version before deploying rather than relying on `latest`. The pinned version in any persisted `values.yaml` file must be updated when the reader chooses to upgrade.
