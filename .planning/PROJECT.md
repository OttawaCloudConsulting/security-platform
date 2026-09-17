# Security & Supply Chain Scanning Stack

## What This Is

A zero-cost, open-source security and supply chain scanning stack for a single-developer AWS cloud practice. Covers the full development lifecycle — workstation linting and secrets detection, CI/CD security gates, Kubernetes-hosted artifact management and vulnerability dashboards, infrastructure hardening, and runtime security. All tools are free, self-hosted, and require no external accounts or logins.

## Core Value

Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production — with zero ongoing cost and zero vendor lock-in.

## Requirements

### Validated

- [x] Pre-commit Tier 1: quality and linting hooks (ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint, npm audit, terraform fmt/validate) on every commit
- [x] Pre-commit Tier 2: Gitleaks secrets detection on every push
- [x] Security CLI tool suite: Trivy, Syft, Grype, Semgrep CE, Checkov, Gitleaks installed and functional
- [x] CICD-01: 5 parallel scan jobs (SAST, IaC, SCA, container, secrets) on every PR — v2.0
- [x] CICD-02: SARIF upload to GitHub Security tab per job — v2.0
- [x] CICD-03: JSON artifact retention (90-day) for future DefectDojo import — v2.0
- [x] CICD-04: Branch protection config/guidance for required checks — v2.0
- [x] CICD-05: Dependabot keeps Actions SHA pins updated — v2.0
- [x] CICD-06: Gate mode (blocking vs report-only) configurable per repo via input/variable — v2.0
- [x] SCA-01: SCA job audits npm/Node dependencies — v2.0
- [x] SCA-02: SCA job audits Python dependencies (pip-audit) — v2.0
- [x] SCA-03: SCA job checks Terraform provider/module pinning (tflint) — v2.0
- [x] SCA-04: SCA job runs generic Trivy filesystem scan as catch-all — v2.0
- [x] DIST-06: Copy-paste workflow template packaged for manual adoption — v2.0
- [x] DIST-07: Reusable workflow callable via `uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1` — v2.0
- [x] DIST-08: Adoption docs cover both consumption modes — v2.0
- [x] VAL-01: Full pipeline validated via branch-target PRs in canonical repo — v2.0
- [x] VAL-02: Required-check enforcement exercised live on external repo (`terraform-pipelines`) — GitHub observably refused a merge with a red required check, then window closed and ruleset restored byte-identical — v2.0

## Current Milestone

(None — v2.0 shipped 2026-09-17. Awaiting `/gsd:new-milestone`.)

### Active

(None yet — next milestone requirements TBD via `/gsd:new-milestone`)

### Validated (v1.1)

- [x] Cross-platform tool installation script (replaces Homebrew with pipx/binary downloads)
- [x] Distribution package: setup.sh command for fresh git repos (install + configure + activate)
- [x] Distribution drops all config files (pre-commit, linting, secrets detection)
- [x] Hooks use file-pattern matching for selective execution (universal config, language-aware)
- [x] Setup script is idempotent and bash 3.2 compatible (macOS stock bash)
- [x] Version check and update capability (`check`, `update`, `doctor` subcommands) — v1.1

### Future (M3+)

- [ ] Nexus Repository proxy deployment on Kubernetes (npm, PyPI, Docker, Helm)
- [ ] Workstation package managers routed through Nexus
- [ ] DefectDojo unified security dashboard on Kubernetes
- [ ] CI-to-DefectDojo automated import pipeline
- [ ] Deduplication and triage workflow configuration
- [ ] Checkov baseline for existing repos (only new findings flagged)
- [ ] NetworkPolicy namespace isolation for all security services
- [ ] TLS via cert-manager for all internal service communication
- [ ] Backup automation for stateful services (DefectDojo PostgreSQL, Nexus PVC)
- [ ] Monitoring and alerting via kube-prometheus-stack
- [ ] Version update process for all tools and Helm charts
- [ ] Trivy Operator for continuous K8s workload scanning
- [ ] Falco CE + FalcoSidekick for runtime anomaly detection
- [ ] Cosign keyless image signing in CI
- [ ] Kyverno admission control rejecting unsigned images

### Out of Scope

- SonarQube Community Build — optional enhancement, deferred to M7 if desired
- Harbor Container Registry — optional enhancement, deferred to M7 if desired
- Commit signing — optional enhancement, deferred to M7 if desired
- Multi-developer RBAC or team access controls — single-developer practice
- Paid tools or SaaS subscriptions — zero-cost constraint
- Production Kubernetes workload deployment — this stack secures the development pipeline, not the application runtime

## Current State

**Shipped: v2.0 CI/CD Security Pipeline** (2026-09-17) — Phases 14-22 (10 phases incl. inserted 20.1), 63 plans, 15/15 requirements.

The canonical callable security workflow (`OttawaCloudConsulting/security-platform`) now runs 5 parallel scan jobs (Semgrep SAST, Checkov IaC, SCA covering npm/Python/Terraform/generic Trivy fs, Trivy container, Gitleaks secrets) on every PR, SHA-pinned with Dependabot keeping pins current. Every job uploads categorized SARIF to the Security tab and retains a 90-day JSON/SARIF artifact. Gate mode (report-only vs blocking) is a per-repo variable, no YAML edits needed. Both consumption modes (copy-paste and `workflow_call` reusable) are packaged, tagged (`v1`/`v1.0.0`), released, and documented in `docs/adoption-guide.md`. Adopted live on 3 external repos across 2 orgs (`terraform-pipelines` public, `aws-zabbix-monitoring-solution` private). Phase 22 proved the end-to-end enforcement claim live: made the 5 scan checks required on `terraform-pipelines`' `main`, watched GitHub refuse a merge with a red required check, then closed the exposure window and restored the ruleset byte-identical.

<details>
<summary>v1.1 Distribution Packaging (shipped 2026-09-10)</summary>

**Shipped: v1.1 Distribution Packaging** (2026-09-10) — Phases 10-13, 12 plans, 15/15 requirements.

Cross-platform install + setup + maintenance tooling now replaces the Homebrew-only M1 workflow: `workstation/setup.sh` bootstraps any git repo (install tools, generate configs, activate hooks) and supports `check`/`update`/`doctor` subcommands for ongoing maintenance. Version manifest pins 6 tools (pre-commit, Trivy, Syft, Grype, Gitleaks, hadolint); pre-commit and Semgrep/Checkov via pipx are still deferred to CI (M2) per INST-05 scope decision.

</details>

## Next Milestone Goals

Awaiting `/gsd:new-milestone`. Candidate scope from ROADMAP.md Backlog and PROJECT.md Future (M3+): Nexus Repository proxy + DefectDojo dashboard on Kubernetes, CI-to-DefectDojo import pipeline (the artifact retention this milestone built for), Checkov baseline for existing repos, and the still-open tech debt from v2.0 (DIST-08 §13 cross-reference gap, blueprint Grype/Trivy naming drift, stale M1 USER_GUIDE.md claim, orphaned Phase 20.1/21 verification gaps — see `.planning/milestones/v2.0-ROADMAP.md` and STATE.md Deferred Items).

## Context

- **Deployment model:** Single developer, personal AWS cloud practice with 6+ GitHub repositories
- **Existing infrastructure:** Kubernetes cluster already running (non-EKS), kubectl configured
- **Current security tooling:** v1.1 complete — `workstation/setup.sh` (security-platform repo) is the single onboarding entrypoint; `dist/install.sh` from M1/early v1.1 is retired (superseded 2026-03-20, commit 828f048)
- **Rollout strategy:** v1.1 produced the distribution package; v2.0 produced the CI/CD pipeline and adopted it on 3 external repos; remaining repos onboard via `setup.sh` (M1) + adoption-guide.md (M2)
- **Canonical pipeline host:** `OttawaCloudConsulting/security-platform` — the callable `security.yml` workflow lives there, not in this repo. This repo documents it (see `docs/adoption-guide.md`).
- **Reference document:** `docs/development-security-stack-option-1.md` (~2,300 lines) contains all tool configs, architecture diagrams, and copy-pasteable configurations; its CI/CD section is now illustrative-only with a pointer to the canonical workflow
- **Milestone plans:** `docs/milestone-plan/` contains 7 detailed milestone documents with 28 features, done criteria, and verification checks
- **ADRs:** `docs/adr/` contains 19 architectural decision records (ADR-001 through ADR-019)
- **Languages covered:** Terraform, CDK, CloudFormation, Python, TypeScript/JavaScript, Bash, Kubernetes/YAML, Docker
- **GSD approach:** One GSD milestone at a time
- **Known issues (deferred, carried forward):**
  - `aws-zabbix-monitoring-solution` package-lock.json has 16 real npm vulnerabilities (1 critical: handlebars, 10 high) as of 2026-09-10 — npm-audit hook correctly blocks commits until fixed; target-repo remediation is out of scope (tooling-focused milestone)
  - ESLint hook in `.pre-commit-config.yaml` uses `language: system` — if eslint is absent (it is, in aws-zabbix) and a `.js`/`.ts` file is ever staged, the hook errors with "command not found" rather than skipping silently. Accepted as known gap, not fixed.
  - v2.0 tech debt (see `.planning/milestones/v2.0-ROADMAP.md` for full list): DIST-08 partial (ADR-019 missing from adoption-guide.md §13 cross-reference), blueprint's illustrative CI/CD section still names Grype where the live pipeline runs Trivy, stale M1 USER_GUIDE.md claim that M1 tools match CI tools, Phase 20.1/21 lack their own VERIFICATION.md (requirements independently verified elsewhere), gsd-sdk tooling defects (state.record-metric/add-decision/record-session, update-progress) open since Phase 14.

## Constraints

- **Cost:** $0 — all tools must be free and open-source with no external account requirements
- **Self-hosted:** Everything runs locally or on the developer's own Kubernetes cluster
- **Single developer:** No team coordination overhead; tooling optimized for solo workflow
- **Milestone ordering:** M1 -> M2 -> M4 -> M5 -> M6 is the critical path; M3 (Nexus) can run in parallel with M1/M2 once K8s is available

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| One GSD milestone per implementation milestone | Keeps focus tight; each milestone produces a usable capability increment | Validated (M1 complete) |
| Start with one repo, then roll out | Validate the tooling works before applying to all repos | Validated (M1 complete) |
| Milestone verification checks as done criteria | The milestone docs already have thorough verification sections | Validated (M1 complete) |
| M7 features (SonarQube, Harbor, commit signing) deferred | Optional enhancements, not required for core security program | -- Pending |
| Replace Homebrew with cross-platform install methods | Portability across macOS and Linux; single install path | Validated (Phase 10) |
| Distribution package for repo onboarding | Low-touch rollout to remaining 4+ repos | Validated (Phase 12) |
| Explicit type/file filters on all hooks | Universal config works across all repo types | Validated (Phase 11) |
| Bash 3.2 compatibility | macOS ships bash 3.2 permanently (GPLv3 licensing) | Validated (Phase 12) |
| Replace `dist/install.sh` with `workstation/setup.sh` bootstrapper | Standalone installer too narrow; repos need config generation + hook activation too, not just tool install | Validated (Phase 12, commit 828f048) |
| INST-05 scope: only pre-commit installs via pipx; Semgrep/Checkov deferred to CI-only | Avoid duplicating CI-only tools on the workstation; requirement text left unnarrowed by deliberate choice | Validated (Phase 10, reconfirmed at v1.1 close) |
| `trap ... RETURN` in installer helpers must self-clear (`trap - RETURN` inside the handler) | Bash RETURN traps aren't function-scoped — they re-fire on the caller's return, crashing on an out-of-scope local under `set -u`. Found live-testing `setup.sh install` at v1.1 close | Validated (security-platform commit 2a70c97) |
| npm-audit / ESLint gaps found in aws-zabbix at v1.1 close are target-repo issues, not tooling bugs | Milestone scope is the distribution tooling, not remediating individual repos | Accepted as deferred — ⚠️ Revisit if aws-zabbix work resumes |
| `OttawaCloudConsulting/security-platform` is the canonical pipeline host, not this repo | This repo is documentation-only per CLAUDE.md; the org identifier originally named in DIST-07 (`OCC-github`) was never a real GitHub org | Validated (Phase 20, ADR-018 D-01 amendment) |
| Fail-closed gate design: `continue-on-error` resolves from `env.GATE_MODE`, defaulting to report-only | Report-only default lets adoption happen without immediately blocking merges; blocking is opt-in per repo via a variable flip, no YAML edit | Validated (Phase 18) |
| SARIF upload steps guarded by a private-repo capability check (GHAS licensing, not a token-scope issue) | Measured live on a private pilot: `upload-sarif` fails with "Code scanning is not enabled" regardless of token scope | Validated (Phase 20, ADR-018) |
| Dual-tag versioning (`v1` lightweight + `v1.0.0` annotated) for the reusable workflow | Lets Mode B consumers pin to a moving major or an exact release | Validated (Phase 20) |
| Branch-protection `--apply` live exercise required an explicit target repo and operator hand at the write | Proving "GitHub actually refuses a merge" needs a real ruleset write with real blast radius; irreversible-ish, so gated on explicit confirm | Validated (Phase 22, ADR-019) — window closed, ruleset restored byte-identical |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-17 after v2.0 milestone*
