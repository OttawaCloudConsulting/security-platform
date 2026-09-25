# Roadmap: Security & Supply Chain Scanning Stack

## Milestones

- ✅ **v1.0 M1 Workstation Foundation** — Phases 1-9 (shipped 2026-03-17)
- ✅ **v1.1 Distribution Packaging** — Phases 10-13 (shipped 2026-09-10)
- ✅ **v2.0 CI/CD Security Pipeline** — Phases 14-22 (shipped 2026-09-17)
- 🔄 **v3.0 K8s Infra & Dashboards** — Phases 23-29 (in progress)

## Phases

<details open>
<summary>🔄 v3.0 K8s Infra & Dashboards (Phases 23-29) — IN PROGRESS</summary>

- [x] **Phase 23: Nexus Generic Chart** - Public Helm chart deploys Nexus with npm/PyPI/Docker/Helm proxy repos, default StorageClass (completed 2026-09-19)
- [x] **Phase 24: Nexus Anonymous Access and Workstation Script** - Anonymous pull enabled; install script points a target repo's package-manager config at a Nexus instance
- [x] **Phase 25: Nexus Live Validation** - Chart deployed to the homelab cluster via private ArgoCD overlay; proxy pulls proven live
- [ ] **Phase 26: DefectDojo Generic Chart** - Public Helm chart deploys DefectDojo with external ingress and cert-manager TLS
- [ ] **Phase 27: DefectDojo CI Auto-Import** - security-platform scan jobs push SARIF/JSON findings into DefectDojo automatically
- [ ] **Phase 28: DefectDojo Dedup and Triage** - Dedup rules collapse repeated findings; triage workflow documented and configured
- [ ] **Phase 29: DefectDojo Live Validation** - Chart deployed to the homelab cluster via private ArgoCD overlay; CI import proven live end-to-end

### Phase 23: Nexus Generic Chart

**Goal:** Public Helm chart wraps the community `stevehipwell/nexus3` subchart (runs the official Sonatype Nexus image; no Sonatype-published chart named `nexus3` exists) and deploys Nexus Repository with npm, PyPI, and Docker proxy repos configured by default (Helm proxy is consumer-configured, no universal default exists post-Helm-Hub), using the cluster's default StorageClass unless overridden.
**Requirements**: NEXUS-01, NEXUS-03
**Plans:** 8 plans

Plans:

- [x] 23-01-PLAN.md — Repo guards (yamllint exclusion, .gitignore) and the standing offline chart gate
- [x] 23-02-PLAN.md — Live smoke script: docker two-pass idempotency, post-EULA download, kind install
- [x] 23-03-PLAN.md — Chart scaffold: Chart.yaml/Chart.lock, .helmignore, values.yaml, template helpers
- [x] 23-04-PLAN.md — provision.sh plus the two ConfigMaps and the post-install hook Job
- [x] 23-05-PLAN.md — Chart README and the root README correction to `kubernetes/`
- [x] 23-06-PLAN.md — Run the gates live and measure the Checkov delta in the CI-equivalent state
- [x] 23-07-PLAN.md — CLAUDE.md scope statement, ADR-020, ADR index row
- [x] 23-08-PLAN.md — PR, operator approval gate, merge to security-platform main

### Phase 24: Nexus Anonymous Access and Workstation Script

**Goal:** Nexus proxy repos allow anonymous pull (no auth required for read/proxy access), and a workstation install script configures a target repo's package-manager files (`.npmrc`, `pip.conf`, Docker/Helm registry config) to route through a given Nexus instance.
**Requirements**: NEXUS-02, NEXUS-04
**Plans:** 10 plans in 6 waves

Plans:

- [x] 24-01-PLAN.md — anonymous.enabled value, the two Nexus REST calls, offline gate inversion (wave 1)
- [x] 24-02-PLAN.md — live gate: anonymous pull for npm/PyPI/Helm; readiness knobs wired (wave 3)
- [x] 24-03-PLAN.md — scripts/check-nexus-setup.sh, the workstation script's offline gate (wave 1)
- [x] 24-04-PLAN.md — measure Assumption A3: Nexus path-routed proxy as a Docker daemon mirror (wave 2, checkpoint)
- [x] 24-05-PLAN.md — live gate: full anonymous Docker handshake, realm state, path shape, write refusal (wave 4)
- [x] 24-06-PLAN.md — workstation/nexus-setup.sh: npm, pip, Helm, .nexus-env, gitignore (wave 3)
- [x] 24-07-PLAN.md — nexus-setup.sh --verify pass and the measured Docker branch (wave 4)
- [x] 24-08-PLAN.md — chart README and workstation README (wave 5)
- [x] 24-09-PLAN.md — ADR-021, ADR index row, Phase 23 deferred items 2 and 3 (wave 5)
- [x] 24-10-PLAN.md — PR, merge gate, origin/main verification, requirement marks (wave 6, checkpoint)

### Phase 25: Nexus Live Validation

**Goal:** The Nexus generic chart (Phase 23) with anonymous pull (Phase 24) is deployed to the operator's homelab cluster via a private ArgoCD overlay, and proxy pulls (npm/PyPI/Docker/Helm) are proven live against that deployment.
**Requirements**: NEXUS-05
**Plans:** 7 plans in 6 waves

Plans:

- [x] 25-01-PLAN.md — scripts/nexus-homelab-validate.sh: the NEXUS_HOST-parameterised live gate, 14 checks (wave 1)
- [x] 25-02-PLAN.md — amend the `platform` AppProject for StatefulSet/Job/SealedSecret, the `nexus` namespace and the security-platform repo (wave 1, checkpoint)
- [x] 25-03-PLAN.md — author `application-sets/platform/nexus/`: two-source override, umbrella Chart.yaml, SealedSecret; open PR 2 unmerged (wave 2)
- [x] 25-04-PLAN.md — merge PR 2, first sync to Synced+Healthy, capture hook/Job/PVC evidence, run the gate `--sync-pass first` (wave 3)
- [x] 25-05-PLAN.md — second sync idempotency (ADR-021 item 7), NEXUS-04 client verify, Open Question 3 assessment (wave 4)
- [x] 25-06-PLAN.md — security-platform PR: ship the gate, rewrite the chart README limitations, conditional chart edit (wave 5, checkpoint)
- [x] 25-07-PLAN.md — ADR-022 and NEXUS-05 closure in REQUIREMENTS.md (wave 6)

### Phase 26: DefectDojo Generic Chart

**Goal:** Public Helm chart deploys DefectDojo with external ingress and cert-manager-issued TLS, generic for any Kubernetes cluster: environment-specific values (hostnames, StorageClass overrides, ClusterIssuer names) are consumer-supplied, never baked into the public package.
**Requirements**: DDOJO-01
**Plans:** 7 plans in 7 waves

Plans:
**Wave 1**

- [x] 26-01-PLAN.md — Refresh security-platform onto main, phase branch, offline gate check-defectdojo-chart.sh (20 checks)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 26-02-PLAN.md — Live kind smoke defectdojo-live-smoke.sh: cert-manager + ingress-nginx + CA issuer, verified TLS, login, celery ping

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 26-03-PLAN.md — Wrapper chart: Chart.yaml/Chart.lock (defectdojo 1.9.53), values.yaml, validate-tls.yaml guard; gate green

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 26-04-PLAN.md — Chart README (Secret contract, issuer, limitations incl. media emptyDir) and root README

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 26-05-PLAN.md — Run gates live, measure Checkov (local + CI-equivalent), repo hygiene; record evidence

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 26-06-PLAN.md — PR, operator approval gate, merge to security-platform main, verify from origin/main

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 26-07-PLAN.md — ADR-023, ADR index row, DDOJO-01 Complete

### Phase 27: DefectDojo CI Auto-Import

**Goal:** `security-platform` scan jobs automatically import their SARIF/JSON findings into a DefectDojo instance after each run.
**Requirements**: DDOJO-02
**Plans:** 10 plans in 10 waves (sequential: one working tree per repository)

Plans:

**Wave 1**

- [x] 27-01-PLAN.md — Gates: split scan vs side-channel jobs in check-workflow-uploads.sh; adoption-guide contexts by job id

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 27-02-PLAN.md — security.yml: optional secret, closed-skip on scan jobs, defectdojo-import job (reimport-scan loop + red verify)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 27-03-PLAN.md — security.yml: defectdojo-cleanup job with the exact-name, product-scoped, default-branch-refusing delete

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 27-04-PLAN.md — Callers: pr-security.yml closed + secret pass, scheduled-security.yml (06:00 America/Toronto); gate made mandatory

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 27-05-PLAN.md — Proof harness part 1: smoke post-hook, extract-and-run of committed bodies, staff token, run-1 assertions

**Wave 6** *(blocked on Wave 5 completion)*

- [ ] 27-06-PLAN.md — Proof harness part 2: reimport, cleanup, hostile-name, scope, insecure-warning; proof workflow; local kind run

**Wave 7** *(blocked on Wave 6 completion)*

- [ ] 27-07-PLAN.md — PR + real GitHub Actions proof run (D-19), operator approval, merge to security-platform main

**Wave 8** *(blocked on Wave 7 completion)*

- [ ] 27-08-PLAN.md — Post-merge closed-event and dispatch evidence; operator-approved v1.1.0 tag and v1 move

**Wave 9** *(blocked on Wave 8 completion)*

- [ ] 27-09-PLAN.md — Adoption guide "Enable DefectDojo Import" section plus its gate check

**Wave 10** *(blocked on Wave 9 completion)*

- [ ] 27-10-PLAN.md — ADR-024, ADR index row, DDOJO-02 Complete

### Phase 28: DefectDojo Dedup and Triage

**Goal:** Deduplication rules collapse repeated findings across scans and tools, and a triage workflow for reviewing and dispositioning findings is documented and configured.
**Requirements**: DDOJO-03, DDOJO-04
**Plans:** TBD

### Phase 29: DefectDojo Live Validation

**Goal:** The DefectDojo generic chart (Phase 26) is deployed to the operator's homelab cluster via a private ArgoCD overlay, and CI import (Phase 27) with dedup/triage (Phase 28) is proven live end-to-end against that deployment.
**Requirements**: DDOJO-05
**Plans:** TBD

</details>

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
Phases execute in numeric order: 1 → 2 → ... → 29 (see milestone archives for full phase-detail history)

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
| 27. DefectDojo CI Auto-Import | v3.0 | 4/10 | In Progress|  |
| 28. DefectDojo Dedup and Triage | v3.0 | 0/? | Not started | — |
| 29. DefectDojo Live Validation | v3.0 | 0/? | Not started | — |

## Next Milestone

Not yet defined. v3.0 (Phases 23-29) is in progress. Run `/gsd:new-milestone` after v3.0 ships. Candidate scope: Checkov baseline for existing repos, and the hardening bucket deferred from v3.0 (NetworkPolicy isolation, backup automation, monitoring/alerting).
