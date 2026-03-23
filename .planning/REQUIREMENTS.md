# Requirements: Security & Supply Chain Scanning Stack -- v1.1 Distribution Packaging

**Defined:** 2026-03-16
**Core Value:** Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production -- with zero ongoing cost and zero vendor lock-in.

## v1.1 Requirements

### Tool Installation

- [x] **INST-01**: Developer can run install script on macOS or Linux to install all security CLI tools without Homebrew
- [x] **INST-02**: Install script auto-detects OS (macOS/Linux) and architecture (amd64/arm64) for binary downloads
- [x] **INST-03**: Tool versions are pinned in a manifest file and install script installs those exact versions
- [x] **INST-04**: Install script verifies PATH includes tool install locations and warns if not configured
- [x] **INST-05**: Python CLI tools (pre-commit, Semgrep, Checkov) install via pipx for dependency isolation
- [x] **INST-06**: Go binary tools (Trivy, Syft, Grype, Gitleaks) install via official install scripts or direct binary download
- [x] **INST-07**: hadolint installs via direct binary download from GitHub releases

### Config Distribution

- [x] **DIST-01**: Setup command drops `.pre-commit-config.yaml` into target repository
- [x] **DIST-02**: Setup command drops all linting configs (ESLint, markdownlint, yamllint, hadolint, Ruff) into target repository
- [x] **DIST-03**: Setup command runs `pre-commit install` and `pre-commit install --hook-type pre-push` to wire hooks
- [x] **DIST-04**: All hooks use `types:` or `files:` filters so they only execute when matching files are staged
- [x] **DIST-05**: Setup command is idempotent -- safe to re-run on repos with existing configs (updates without breaking)

### Maintenance

- [ ] **MAINT-01**: Developer can run a check command to see installed vs expected versions for all tools
- [ ] **MAINT-02**: Check command can update outdated tools to the pinned version
- [ ] **MAINT-03**: Health check verifies all tools are on PATH and can execute their version command

## v2 Requirements

### CI/CD Security Gate (M2)

- **CICD-01**: GitHub Actions security workflow with 5 parallel scan jobs
- **CICD-02**: SARIF upload to GitHub Security tab
- **CICD-03**: JSON artifact retention for DefectDojo import
- **CICD-04**: Branch protection enforcement
- **CICD-05**: Dependabot for Actions SHA updates

### Future Milestones (M3-M7)

- **NEXS-01-03**: Nexus Repository proxy deployment and workstation routing
- **DOJO-01-05**: DefectDojo deployment and CI import automation
- **HARD-01-05**: Infrastructure hardening (NetworkPolicy, TLS, backup, monitoring)
- **RUNT-01-04**: Runtime security (Trivy Operator, Falco, Cosign, Kyverno)
- **OPTL-01-03**: Optional enhancements (SonarQube, Harbor, commit signing)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Checksum verification of downloads | Adds complexity; official install scripts handle integrity; can add later |
| Interactive setup wizard | User preference for low-touch, non-interactive setup |
| npm/npx distribution mechanism | Adds Node.js dependency; bash script is zero-dependency |
| Devcontainer-based isolation | Overkill for single-developer; adds Docker dependency |
| Centralized remote config | Anti-pattern per pre-commit maintainers; configs are copied not linked |
| Per-repo config customization | Universal config with file-pattern filters handles all repos |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INST-01 | Phase 10 | Complete |
| INST-02 | Phase 10 | Complete |
| INST-03 | Phase 10 | Complete |
| INST-04 | Phase 10 | Complete |
| INST-05 | Phase 10 | Complete |
| INST-06 | Phase 10 | Complete |
| INST-07 | Phase 10 | Complete |
| DIST-01 | Phase 12 | Complete |
| DIST-02 | Phase 12 | Complete |
| DIST-03 | Phase 12 | Complete |
| DIST-04 | Phase 11 | Complete |
| DIST-05 | Phase 12 | Complete |
| MAINT-01 | Phase 13 | Pending |
| MAINT-02 | Phase 13 | Pending |
| MAINT-03 | Phase 13 | Pending |

**Coverage:**
- v1.1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements defined: 2026-03-16*
*Last updated: 2026-03-16 after roadmap creation*
