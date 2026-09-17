# Requirements: Security & Supply Chain Scanning Stack — v2.0

**Defined:** 2026-09-10
**Core Value:** Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production — with zero ongoing cost and zero vendor lock-in.

## v1 Requirements (this milestone)

### CI/CD Pipeline

- [x] **CICD-01**: GitHub Actions security workflow runs 5 parallel scan jobs (SAST, IaC, SCA, container, secrets) on every PR
- [x] **CICD-02**: Each scan job uploads SARIF results to the GitHub Security tab
- [x] **CICD-03**: Each scan job retains JSON artifact output for future DefectDojo import (import pipeline itself is out of scope this milestone)
- [x] **CICD-04**: Branch protection config/guidance provided so scan checks can be made required (block merge) once enabled
- [x] **CICD-05**: Dependabot configured to keep GitHub Actions SHA pins updated
- [x] **CICD-06**: Gate mode (block merge vs report-only) is configurable per consuming repo via a flag/input, not hardcoded

### SCA Coverage

- [x] **SCA-01**: SCA job audits npm/Node dependencies
- [x] **SCA-02**: SCA job audits Python dependencies (pip-audit or equivalent)
- [x] **SCA-03**: SCA job checks Terraform provider/module pinning
- [x] **SCA-04**: SCA job runs a generic Trivy/Grype filesystem scan as a catch-all for ecosystems not covered above

### Distribution

- [x] **DIST-06**: Copy-paste workflow template packaged for manual adoption into a consumer repo
- [x] **DIST-07**: Reusable workflow callable via `uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@<ref>` from other repos (corrected per the D-01 amendment and RESEARCH C-1 — the org identifier this requirement originally named was never a real GitHub account, org or user lookup both 404)
- [x] **DIST-08**: Adoption docs cover both consumption modes, written for rollout to the remaining 6+ repos

### Validation

- [x] **VAL-01**: Full pipeline validated in this repo using branch-target PRs (no second repo required to prove it out)
- [x] **VAL-02**: Required-check enforcement exercised live — a pull request with a red required check is observably refused by GitHub

## v2 Requirements

Deferred to future milestones (M3+).

### Artifact Management

- **DEFECT-01**: CI-to-DefectDojo automated import pipeline consuming the JSON artifacts from CICD-03
- **DEFECT-02**: Deduplication and triage workflow configuration in DefectDojo

## Out of Scope

| Feature | Reason |
|---------|--------|
| DefectDojo dashboard deployment | Separate K8s-hosted milestone (M3+) per PROJECT.md Future list |
| Nexus Repository proxy | Separate K8s-hosted milestone (M3+) |
| Checkov baseline suppression for existing repo findings | Deferred until repos are actually onboarded with the new workflow |
| Cross-repo live test (second repo) | Branch-target PRs in this repo are sufficient to validate before rollout |
| CI-to-DefectDojo import pipeline (DEFECT-01) | DefectDojo itself doesn't exist yet; artifacts are retained (CICD-03) so import can be built later |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CICD-01 | Phase 15 | Complete |
| CICD-02 | Phase 17 | Complete |
| CICD-03 | Phase 17 | Complete |
| CICD-04 | Phase 18 | Complete |
| CICD-05 | Phase 14 | Complete |
| CICD-06 | Phase 18 | Complete |
| SCA-01 | Phase 16 | Complete |
| SCA-02 | Phase 16 | Complete |
| SCA-03 | Phase 16 | Complete |
| SCA-04 | Phase 15 | Complete |
| DIST-06 | Phase 20 | Complete |
| DIST-07 | Phase 20 | Complete |
| DIST-08 | Phase 20 | Complete |
| VAL-01 | Phase 19 | Complete |
| VAL-02 | Phase 22 | Complete |

**Coverage:**
- v1 requirements: 15 total
- Mapped to phases: 15 ✓
- Unmapped: 0

---
*Requirements defined: 2026-09-10*
*Last updated: 2026-09-16 after Phase 22 closed VAL-02 — the refusal was witnessed and the target repository's ruleset restored (ADR-019)*
