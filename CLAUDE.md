# CLAUDE.md

## What This Repository Is

A **reference documentation project** (not buildable software). The primary artifact is `development-security-stack-option-1.md` — a complete blueprint for a zero-cost, open-source security and supply chain scanning stack for a single-developer AWS cloud practice.

## Project Structure

- `development-security-stack-option-1.md` — primary document (~2,300 lines), contains copy-pasteable configs and ASCII architecture diagrams
- `docs/adr/` — individual architectural decision records (ADR-001 through ADR-014); see `docs/adr/README.md` for index
- `red-team/` — three-agent red-team analysis and consolidated findings
- `drafts/` — in-progress section rewrites
- `docs/ARCHITECTURE_AND_DESIGN.md` — extracted architecture reference
- `prd.md` — (when present) product requirements document
- `progress.txt` — (when present) implementation tracking

## Editing Guidelines

- Preserve ASCII architecture diagrams and the 4-phase layered structure (Workstation → CI/CD → K8s Infrastructure → Runtime)
- Preserve tool coverage matrices and the security tools comparison table
- ADR records in `docs/adr/` are append-only — add new records as new files, don't modify accepted ones
