# CLAUDE.md

## What This Repository Is

A **reference documentation project** (not buildable software). The primary artifact is `docs/development-security-stack-option-1.md` — a complete blueprint for a zero-cost, open-source security and supply chain scanning stack for a single-developer AWS cloud practice. The canonical, live-validated GitHub Actions workflows that implement Phase 2 of that blueprint, together with the K8s packages that implement its Kubernetes infrastructure layer (`kubernetes/<service>/` Helm charts, currently `kubernetes/nexus/` and `kubernetes/defectdojo/`), live in `OttawaCloudConsulting/security-platform`, not in this repository — this repository documents them, it does not ship them.

## Project Structure

- `docs/development-security-stack-option-1.md` — primary document (~2,450 lines), contains copy-pasteable configs and ASCII architecture diagrams
- `docs/adr/` — individual architectural decision records, numbered ADR-NNN; `docs/adr/README.md` is the authoritative index
- `docs/adoption-guide.md` — the adoption procedure for both consumption modes (copy-paste and reusable `workflow_call`) of the canonical `security-platform` pipeline
- `scripts/` — standing documentation gates, including `bash scripts/check-adoption-guide.sh`
- `docs/ARCHITECTURE_AND_DESIGN.md` — extracted architecture reference
- `prd.md` — (when present) product requirements document
- `progress.txt` — (when present) implementation tracking

## Editing Guidelines

- Preserve ASCII architecture diagrams and the 4-phase layered structure (Workstation → CI/CD → K8s Infrastructure → Runtime)
- Preserve tool coverage matrices and the security tools comparison table
- ADR records in `docs/adr/` are append-only — add new records as new files, don't modify accepted ones
