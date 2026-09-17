# Roadmap: Security & Supply Chain Scanning Stack

## Milestones

- ✅ **v1.0 M1 Workstation Foundation** — Phases 1-9 (shipped 2026-03-17)
- ✅ **v1.1 Distribution Packaging** — Phases 10-13 (shipped 2026-09-10)
- ✅ **v2.0 CI/CD Security Pipeline** — Phases 14-22 (shipped 2026-09-17)

## Phases

<details>
<summary>✅ v1.0 M1 Workstation Foundation (Phases 1-9) — SHIPPED 2026-03-17</summary>

- [x] **Phase 1: Pre-commit Framework** - Install pre-commit and create the hook configuration file (completed 2026-03-16)
- [x] **Phase 2: Shell and Python Hooks** - ShellCheck and Ruff linting on every commit (completed 2026-03-16)
- [x] **Phase 3: Web and Config Hooks** - ESLint, hadolint, yamllint, and markdownlint on every commit (completed 2026-03-15)
- [x] **Phase 4: Infrastructure Hooks** - npm audit, terraform fmt, and terraform validate on every commit (completed 2026-03-16)
- [x] **Phase 5: Secrets Detection Gate** - Gitleaks pre-push hook blocks leaked credentials (completed 2026-03-16)
- [x] **Phase 6: SCA and Container CLI Tools** - Trivy, Syft, and Grype installed and on PATH (completed 2026-03-16)
- [x] **Phase 7: SAST and IaC CLI Tools** - Semgrep, Checkov, and Gitleaks CLI installed and on PATH (completed 2026-03-16)
- [x] **Phase 8: CLI Tool Scanning Validation** - Every CLI tool runs a real scan and produces JSON output (completed 2026-03-16)
- [x] **Phase 9: Full Stack Validation** - All hooks pass cleanly across the entire repository (completed 2026-03-17)

</details>

<details>
<summary>✅ v1.1 Distribution Packaging (Phases 10-13) — SHIPPED 2026-09-10</summary>

- [x] **Phase 10: Cross-Platform Install Script** - install.sh installs all security CLI tools on macOS and Linux without Homebrew (completed 2026-03-18)
- [x] **Phase 11: File-Pattern Hook Configuration** - Universal pre-commit config with language-aware filters for selective hook execution (completed 2026-03-22)
- [x] **Phase 12: Repo Setup Script** - setup.sh copies configs and wires hooks in any git repo with one command (completed 2026-03-22)
- [x] **Phase 13: Maintenance and Validation** - Version check, update, and health check commands for installed tools (completed 2026-09-10)

See `.planning/milestones/v1.1-ROADMAP.md` for full phase details.

</details>

<details>
<summary>✅ v2.0 CI/CD Security Pipeline (Phases 14-22) — SHIPPED 2026-09-17</summary>

- [x] **Phase 14: Workflow Foundation and Action Pinning** - Callable security workflow triggers on PRs with SHA-pinned actions kept current by Dependabot (completed 2026-09-10)
- [x] **Phase 15: Five Parallel Scan Jobs** - SAST, IaC, SCA, container, and secrets scans run concurrently on every PR in report-only mode (completed 2026-09-11)
- [x] **Phase 16: SCA Ecosystem Coverage** - SCA job audits npm, Python, and Terraform dependencies alongside the generic filesystem sweep (completed 2026-09-11)
- [x] **Phase 17: SARIF Upload and Artifact Retention** - Findings reach the GitHub Security tab and persist as JSON artifacts (completed 2026-09-11)
- [x] **Phase 18: Configurable Gate Mode and Branch Protection** - Each repo picks block-merge or report-only via a flag, with branch protection guidance (completed 2026-09-12)
- [x] **Phase 19: Pipeline Validation via Branch-Target PRs** - Full pipeline proven end-to-end against seeded findings in this repo (completed 2026-09-14)
- [x] **Phase 20: Template Packaging and Adoption Docs** - Both consumption modes packaged and documented for rollout to the remaining repos (completed 2026-09-14)
- [x] **Phase 20.1: Close gap: Retroactive VERIFICATION.md for Phases 14/17/18** (INSERTED) - Independently reconfirmed CICD-02 through CICD-06 live against `origin/main` (completed 2026-09-15)
- [x] **Phase 21: Docs cleanup — close remaining Phase 20 deferred items** - Fixed stale Grype references, SARIF ceiling docs, and stale action-version comments (completed 2026-09-15)
- [x] **Phase 22: branch-protection --apply live exercise** - Witnessed GitHub refuse a merge on a red required check on `terraform-pipelines`, then restored the ruleset byte-identically (completed 2026-09-16)

See `.planning/milestones/v2.0-ROADMAP.md` for full phase details.

</details>

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → ... → 22 (see milestone archives for full phase-detail history)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Pre-commit Framework | v1.0 | 1/1 | Complete | 2026-03-16 |
| 2. Shell and Python Hooks | v1.0 | 1/1 | Complete | 2026-03-16 |
| 3. Web and Config Hooks | v1.0 | 2/2 | Complete | 2026-03-15 |
| 4. Infrastructure Hooks | v1.0 | 1/1 | Complete | 2026-03-16 |
| 5. Secrets Detection Gate | v1.0 | 2/2 | Complete | 2026-03-16 |
| 6. SCA and Container CLI Tools | v1.0 | 1/1 | Complete | 2026-03-16 |
| 7. SAST and IaC CLI Tools | v1.0 | 1/1 | Complete | 2026-03-16 |
| 8. CLI Tool Scanning Validation | v1.0 | 2/2 | Complete | 2026-03-16 |
| 9. Full Stack Validation | v1.0 | 2/2 | Complete | 2026-03-17 |
| 10. Cross-Platform Install Script | v1.1 | 2/2 | Complete | 2026-03-18 |
| 11. File-Pattern Hook Configuration | v1.1 | 1/1 | Complete | 2026-03-22 |
| 12. Repo Setup Script | v1.1 | 1/1 | Complete | 2026-03-22 |
| 13. Maintenance and Validation | v1.1 | 8/8 | Complete | 2026-09-10 |
| 14. Workflow Foundation and Action Pinning | v2.0 | 3/3 | Complete | 2026-09-10 |
| 15. Five Parallel Scan Jobs | v2.0 | 5/5 | Complete | 2026-09-11 |
| 16. SCA Ecosystem Coverage | v2.0 | 7/7 | Complete | 2026-09-11 |
| 17. SARIF Upload and Artifact Retention | v2.0 | 7/7 | Complete | 2026-09-11 |
| 18. Configurable Gate Mode and Branch Protection | v2.0 | 8/8 | Complete | 2026-09-12 |
| 19. Pipeline Validation via Branch-Target PRs | v2.0 | 7/7 | Complete | 2026-09-14 |
| 20. Template Packaging and Adoption Docs | v2.0 | 13/13 | Complete | 2026-09-14 |
| 20.1. Close gap: Retroactive VERIFICATION.md for Phases 14/17/18 | v2.0 | 3/3 | Complete | 2026-09-15 |
| 21. Docs cleanup — close remaining Phase 20 deferred items | v2.0 | 4/4 | Complete | 2026-09-15 |
| 22. branch-protection --apply live exercise | v2.0 | 6/6 | Complete | 2026-09-16 |

## Next Milestone

v3.0 not yet defined. Run `/gsd:new-milestone` to start requirements gathering. Candidate scope (see PROJECT.md "Next Milestone Goals"): Nexus Repository, DefectDojo dashboard, CI-to-DefectDojo import pipeline, Checkov baseline for existing repos.
