# Roadmap: Security & Supply Chain Scanning Stack

## Milestones

- ✅ **v1.0 M1 Workstation Foundation** — Phases 1-9 (shipped 2026-03-17)
- ✅ **v1.1 Distribution Packaging** — Phases 10-13 (shipped 2026-09-10)

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

## Progress

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
