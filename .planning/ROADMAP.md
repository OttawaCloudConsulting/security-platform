# Roadmap: Security & Supply Chain Scanning Stack

## Milestones

- ✅ **v1.0 M1 Workstation Foundation** — Phases 1-9 (shipped 2026-03-17)
- ✅ **v1.1 Distribution Packaging** — Phases 10-13 (shipped 2026-09-10)
- ✅ **v2.0 CI/CD Security Pipeline** — Phases 14-22 (shipped 2026-09-17)
- ✅ **v3.0 K8s Infra & Dashboards** — Phases 23-29.7 (shipped 2026-10-10)

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

<details>
<summary>✅ v3.0 K8s Infra & Dashboards (Phases 23-29.7) — SHIPPED 2026-10-10</summary>

- [x] **Phase 23: Nexus Generic Chart** - Public Helm chart deploys Nexus with npm/PyPI/Docker/Helm proxy repos, default StorageClass (completed 2026-09-19)
- [x] **Phase 24: Nexus Anonymous Access and Workstation Script** - Anonymous pull enabled; install script points a target repo's package-manager config at a Nexus instance
- [x] **Phase 25: Nexus Live Validation** - Chart deployed to the homelab cluster via private ArgoCD overlay; proxy pulls proven live
- [x] **Phase 26: DefectDojo Generic Chart** - Public Helm chart deploys DefectDojo with external ingress and cert-manager TLS (completed 2026-09-25)
- [x] **Phase 27: DefectDojo CI Auto-Import** - security-platform scan jobs push SARIF/JSON findings into DefectDojo automatically (completed 2026-09-26)
- [x] **Phase 28: DefectDojo Dedup and Triage** - Dedup rules collapse repeated findings; triage workflow documented and configured (completed 2026-09-26)
- [x] **Phase 29: DefectDojo Live Validation** - Chart deployed to the homelab cluster via private ArgoCD overlay; CI import proven live end-to-end (completed 2026-09-29)
- [x] **Phase 29.1: Close gap: NEXUS-01/NEXUS-03 — retroactive VERIFICATION.md for Phase 23** (INSERTED) - Retroactive read-only 23-VERIFICATION.md re-proved NEXUS-01 and NEXUS-03 (completed 2026-09-29)
- [x] **Phase 29.2: Fix CR-01: defectdojo-configure.sh honours ~/.curlrc (insecure disables TLS)** (INSERTED) - Ambient curlrc can no longer send a DefectDojo API token over unverified TLS; merged untagged (completed 2026-09-30)
- [x] **Phase 29.3: Fix WR-05: chart gates fail closed on missing validate-tls.yaml and run in CI** (INSERTED) - Both offline chart gates fail closed and run in chart-gates.yml; merged untagged (completed 2026-10-01)
- [x] **Phase 29.4: Fix trivy-image cross-branch dedup: replace scan-target github.sha tag (v1 consumer impact check)** (INSERTED) - Scanned image tagged scan-target:ci so trivy-image findings dedupe across branches; released v1.3.0, ADR-031 (completed 2026-10-04)
- [x] **Phase 29.5: Fix WR-03: TRIAGE.md Under Review query hides verified=true Trivy findings** (INSERTED) - dd-import sends verified=false on every reimport; released v1.4.0, ADR-032 (completed 2026-10-05)
- [x] **Phase 29.6: Close 27 UAT item 3 (closed-PR reopen race) and refresh stale 27-HUMAN-UAT.md** (INSERTED) - Close-reopen-merge race refused in 6/6 attempts against an enforcing ruleset; 27-HUMAN-UAT.md refreshed, ADR-033 (completed 2026-10-08)
- [x] **Phase 29.7: Bookkeeping: ROADMAP checkboxes, requirements-completed frontmatter, CLAUDE.md ADR range, gsd-sdk tooling ledger** (INSERTED) - Records reconciled with the repository; gsd-sdk defects consolidated in one ledger (completed 2026-10-10)

See `.planning/milestones/v3.0-ROADMAP.md` for full phase details.

</details>

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → ... → 29 → 29.1 → ... → 29.7 (see milestone archives for full phase-detail history)

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
| 23. Nexus Generic Chart | v3.0 | 8/8 | Complete   | 2026-09-19 |
| 24. Nexus Anonymous Access and Workstation Script | v3.0 | 10/10 | Complete   | 2026-09-20 |
| 25. Nexus Live Validation | v3.0 | 7/7 | Complete    | 2026-09-24 |
| 26. DefectDojo Generic Chart | v3.0 | 7/7 | Complete    | 2026-09-25 |
| 27. DefectDojo CI Auto-Import | v3.0 | 14/14 | Complete    | 2026-09-26 |
| 28. DefectDojo Dedup and Triage | v3.0 | 9/9 | Complete    | 2026-09-26 |
| 29. DefectDojo Live Validation | v3.0 | 20/20 | Complete    | 2026-09-29 |
| 29.1. Close gap: NEXUS-01/NEXUS-03 — retroactive VERIFICATION.md for Phase 23 | v3.0 | 2/2 | Complete | 2026-09-29 |
| 29.2. Fix CR-01: defectdojo-configure.sh honours ~/.curlrc (insecure disables TLS) | v3.0 | 12/12 | Complete | 2026-09-30 |
| 29.3. Fix WR-05: chart gates fail closed on missing validate-tls.yaml and run in CI | v3.0 | 7/7 | Complete | 2026-10-01 |
| 29.4. Fix trivy-image cross-branch dedup: replace scan-target github.sha tag (v1 consumer impact check) | v3.0 | 10/10 | Complete | 2026-10-04 |
| 29.5. Fix WR-03: TRIAGE.md Under Review query hides verified=true Trivy findings | v3.0 | 12/12 | Complete | 2026-10-05 |
| 29.6. Close 27 UAT item 3 (closed-PR reopen race) and refresh stale 27-HUMAN-UAT.md | v3.0 | 15/15 | Complete | 2026-10-08 |
| 29.7. Bookkeeping: ROADMAP checkboxes, requirements-completed frontmatter, CLAUDE.md ADR range, gsd-sdk tooling ledger | v3.0 | 7/7 | Complete    | 2026-10-10 |

## Next Milestone

Not yet defined. v3.0 (Phases 23-29.7) shipped 2026-10-10. Run `/gsd:new-milestone`. Candidate scope: Checkov baseline for existing repos, and the hardening bucket deferred from v3.0 (NetworkPolicy isolation, backup automation, monitoring/alerting). Deferred v3.0 items are in STATE.md Deferred Items.
