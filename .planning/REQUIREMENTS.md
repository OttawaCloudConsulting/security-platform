# Requirements: Security & Supply Chain Scanning Stack — v2.0

**Defined:** 2026-09-10
**Core Value:** Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production — with zero ongoing cost and zero vendor lock-in.

## v1 Requirements (this milestone)

### CI/CD Pipeline

- [ ] **CICD-01**: GitHub Actions security workflow runs 5 parallel scan jobs (SAST, IaC, SCA, container, secrets) on every PR
- [ ] **CICD-02**: Each scan job uploads SARIF results to the GitHub Security tab
- [ ] **CICD-03**: Each scan job retains JSON artifact output for future DefectDojo import (import pipeline itself is out of scope this milestone)
- [ ] **CICD-04**: Branch protection config/guidance provided so scan checks can be made required (block merge) once enabled
- [x] **CICD-05**: Dependabot configured to keep GitHub Actions SHA pins updated
- [ ] **CICD-06**: Gate mode (block merge vs report-only) is configurable per consuming repo via a flag/input, not hardcoded

### SCA Coverage

- [ ] **SCA-01**: SCA job audits npm/Node dependencies
- [ ] **SCA-02**: SCA job audits Python dependencies (pip-audit or equivalent)
- [ ] **SCA-03**: SCA job checks Terraform provider/module pinning
- [ ] **SCA-04**: SCA job runs a generic Trivy/Grype filesystem scan as a catch-all for ecosystems not covered above

### Distribution

- [ ] **DIST-06**: Copy-paste workflow template packaged for manual adoption into a consumer repo
- [ ] **DIST-07**: Reusable workflow callable via `uses: OCC-github/security_solution/.github/workflows/<name>.yml@ref` from other repos in the org
- [ ] **DIST-08**: Adoption docs cover both consumption modes, written for rollout to the remaining 6+ repos

### Validation

- [ ] **VAL-01**: Full pipeline validated in this repo using branch-target PRs (no second repo required to prove it out)

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
| CICD-01 | Phase 15 | Pending |
| CICD-02 | Phase 17 | Pending |
| CICD-03 | Phase 17 | Pending |
| CICD-04 | Phase 18 | Pending |
| CICD-05 | Phase 14 | Complete |
| CICD-06 | Phase 18 | Pending |
| SCA-01 | Phase 16 | Pending |
| SCA-02 | Phase 16 | Pending |
| SCA-03 | Phase 16 | Pending |
| SCA-04 | Phase 15 | Pending |
| DIST-06 | Phase 20 | Pending |
| DIST-07 | Phase 20 | Pending |
| DIST-08 | Phase 20 | Pending |
| VAL-01 | Phase 19 | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14 ✓
- Unmapped: 0

---
*Requirements defined: 2026-09-10*
*Last updated: 2026-09-10 after v2.0 roadmap creation (Phases 14-20)*
