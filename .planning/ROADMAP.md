# Roadmap: Security & Supply Chain Scanning Stack

## Milestones

- ✅ **v1.0 M1 Workstation Foundation** — Phases 1-9 (shipped 2026-03-17)
- ✅ **v1.1 Distribution Packaging** — Phases 10-13 (shipped 2026-09-10)
- 🚧 **v2.0 CI/CD Security Pipeline** — Phases 14-20 (in progress)

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

### 🚧 v2.0 CI/CD Security Pipeline (In Progress)

**Milestone Goal:** Ship reusable/copy-paste GitHub Actions security scanning templates, proven in this repo and ready to adopt across all 6+ org repos.

- [x] **Phase 14: Workflow Foundation and Action Pinning** - Callable security workflow triggers on PRs with SHA-pinned actions kept current by Dependabot (completed 2026-09-10)
- [x] **Phase 15: Five Parallel Scan Jobs** - SAST, IaC, SCA, container, and secrets scans run concurrently on every PR in report-only mode (completed 2026-09-11)
- [ ] **Phase 16: SCA Ecosystem Coverage** - SCA job audits npm, Python, and Terraform dependencies alongside the generic filesystem sweep
- [ ] **Phase 17: SARIF Upload and Artifact Retention** - Findings reach the GitHub Security tab and persist as JSON artifacts
- [ ] **Phase 18: Configurable Gate Mode and Branch Protection** - Each repo picks block-merge or report-only via a flag, with branch protection guidance
- [ ] **Phase 19: Pipeline Validation via Branch-Target PRs** - Full pipeline proven end-to-end against seeded findings in this repo
- [ ] **Phase 20: Template Packaging and Adoption Docs** - Both consumption modes packaged and documented for rollout to the remaining repos

## Phase Details

### Phase 14: Workflow Foundation and Action Pinning
**Goal**: This repo has a callable security scanning workflow that runs on every pull request, pinned to immutable action SHAs and kept current automatically.
**Depends on**: Phase 13 (v1.1 shipped)
**Requirements**: CICD-05
**Success Criteria** (what must be TRUE):
  1. Opening a pull request in this repo triggers a security workflow run visible in the Actions tab, and the run completes without blocking the merge.
  2. The scanning workflow is defined with `on: workflow_call` and is invoked by a thin `pull_request` caller workflow in this repo, so the same file is callable from another repo without restructuring later.
  3. Every `uses:` reference in the workflows is pinned to a full commit SHA with a human-readable version comment.
  4. Dependabot opens a pull request against this repo when a pinned action publishes a newer release.
**Plans**: 3 plans
- [x] 14-01-PLAN.md — Create root `.github/` tree in `repos/security-platform/`: callable `security.yml`, `pull_request` caller `pr-security.yml`, `dependabot.yml`; static gate
- [x] 14-02-PLAN.md — Push the product-repo branch, open PR, observe the green PR-triggered run and capture the check-run name (criteria 1-2)
- [x] 14-03-PLAN.md — Human-confirmed merge to `main`, then observe and classify Dependabot's first run (criterion 4 / CICD-05)

### Phase 15: Five Parallel Scan Jobs
**Goal**: Every pull request is scanned by five independent security tools running in parallel, each reporting what it finds without blocking the merge.
**Depends on**: Phase 14
**Requirements**: CICD-01, SCA-04
**Success Criteria** (what must be TRUE):
  1. A single pull request shows five separate scan checks — SAST, IaC, SCA, container, secrets — running concurrently rather than one after another.
  2. Each job's log shows a real result from its tool run against real files in the checkout — repo sources plus the scan fixtures added for the jobs that have nothing to scan otherwise — not a skipped or stubbed step.
  3. The SCA job runs a Trivy/Grype filesystem scan across the repo and reports the packages and vulnerabilities it detects, with no per-ecosystem configuration required.
  4. Each job writes its machine-readable output (SARIF and/or JSON) to a file on the runner, even though nothing consumes those files yet.
  5. A job that reports findings still leaves the pull request mergeable.
**Plans**: 5 plans
- [x] 15-01-PLAN.md — Cut the phase branch, scope four pre-commit hooks away from `fixtures/`, and author the fixture tree (Dockerfile, main.tf, package.json + generated lock, README)
- [x] 15-02-PLAN.md — Author and run `scripts/smoke-scans.sh`, a local pass/fail gate proving all five scanner invocations yield real, non-empty results
- [x] 15-03-PLAN.md — Replace the `placeholder` job with five SHA-pinned, `needs:`-free, step-tolerated scan jobs in `security.yml`; validate statically
- [x] 15-04-PLAN.md — Push, open the PR, and collect live evidence: five concurrent `security / *` checks, all green, PR MERGEABLE
- [x] 15-05-PLAN.md — Human sign-off on concurrency and report-only behaviour, then merge to `main` and close out the phase's open questions

### Phase 16: SCA Ecosystem Coverage
**Goal**: The SCA job audits each dependency ecosystem this practice actually uses, rather than relying on the generic filesystem sweep alone.
**Depends on**: Phase 15
**Requirements**: SCA-01, SCA-02, SCA-03
**Success Criteria** (what must be TRUE):
  1. On a repo containing `package-lock.json`, the SCA job reports npm dependency vulnerabilities with severity levels.
  2. On a repo containing Python dependency files, the SCA job reports Python advisories via pip-audit or an equivalent tool.
  3. Terraform provider and module version pinning is checked, and floating or unpinned versions are reported as findings.
  4. Each sub-scan skips cleanly with a clear log message — no failure, no false pass — when the repo contains no files for that ecosystem.
**Plans**: 7 plans
- [x] 16-01-PLAN.md — Cut the phase branch and seed the missing fixtures: `fixtures/requirements.txt` plus an unconstrained-and-used provider and an unpinned module in `fixtures/main.tf`; re-measure `fixtures/README.md`
- [ ] 16-02-PLAN.md — Extract `scripts/detect-{npm,python,terraform}.sh` and generalise the smoke-gate helpers (`run_scan_rc`, `require_parses_json`, soft preflight, SKIPPED accounting)
- [ ] 16-03-PLAN.md — Prove npm audit, pip-audit and tflint locally with report-content assertions, plus the Criterion 4 clean-skip negative test in an empty repo
- [ ] 16-04-PLAN.md — Add the three detect/scan/verify step groups and guarded evidence steps to the existing `sca` job in `.github/workflows/security.yml`; static validation
- [ ] 16-05-PLAN.md — Push, open the PR, and collect live evidence for Criteria 1-3 from the SCA job log; confirm the five check-run names and MERGEABLE
- [ ] 16-06-PLAN.md — Record the tflint adoption in ADR-015 and add pip-audit/tflint to the blueprint's tool tables
- [ ] 16-07-PLAN.md — Human sign-off on the evidence and the Criterion 3 limitation, then merge and close SCA-01/02/03

### Phase 17: SARIF Upload and Artifact Retention
**Goal**: Scan findings surface in GitHub's Security tab and are retained as JSON so a future DefectDojo import has data to consume.
**Depends on**: Phase 16
**Requirements**: CICD-02, CICD-03
**Success Criteria** (what must be TRUE):
  1. After a workflow run, the repo's Security > Code scanning view shows findings attributed to each scanner separately, so results from one tool do not overwrite another's.
  2. Findings appear as inline annotations on the pull request diff wherever the tool reports a file and line.
  3. Every run leaves downloadable JSON artifacts — one per scan job, including the SCA sub-scans — with an explicit retention period.
  4. A tool without native SARIF output still reaches the Security tab or the artifact set through a documented conversion step.
**Plans**: TBD

### Phase 18: Configurable Gate Mode and Branch Protection
**Goal**: Each consuming repo chooses whether security scans block a merge or merely report, without editing workflow YAML.
**Depends on**: Phase 17
**Requirements**: CICD-06, CICD-04
**Success Criteria** (what must be TRUE):
  1. With the gate flag set to blocking, a pull request carrying a seeded finding fails its check; with the flag set to report-only, the same pull request passes.
  2. The flag is settable in both consumption modes — as a `workflow_call` input when the workflow is referenced remotely, and as a repo-level variable or env when the template is copy-pasted.
  3. Switching a repo between blocking and report-only requires no change to workflow YAML.
  4. Written branch-protection configuration and steps exist for promoting the scan checks to required checks, including which severity threshold triggers a failure.
**Plans**: TBD

### Phase 19: Pipeline Validation via Branch-Target PRs
**Goal**: The complete pipeline is proven end-to-end inside this repo against deliberately seeded findings, with no second repo required.
**Depends on**: Phase 18
**Requirements**: VAL-01
**Success Criteria** (what must be TRUE):
  1. A branch-target pull request carrying seeded findings for all five scan categories produces a detection from each of the five jobs.
  2. That same pull request is observed failing its checks under blocking mode and passing under report-only mode — both runs witnessed, not inferred.
  3. A seeded finding is traced from its source file through to both the Security tab entry and the retained JSON artifact.
  4. A clean pull request with no seeded findings passes all five jobs green.
**Plans**: TBD

### Phase 20: Template Packaging and Adoption Docs
**Goal**: Any of the other 6+ org repos can adopt the security pipeline in either consumption mode by following documentation alone.
**Depends on**: Phase 19
**Requirements**: DIST-06, DIST-07, DIST-08
**Success Criteria** (what must be TRUE):
  1. A copy-paste workflow template exists with every per-repo substitution clearly marked, and dropping it into a repo produces a working scan run.
  2. Another repo in the org can call the workflow via `uses: OCC-github/security_solution/.github/workflows/<name>.yml@<ref>` against a stable published ref.
  3. Adoption docs walk through both consumption modes end to end, covering gate-mode selection, branch protection setup, and Dependabot wiring.
  4. Docs state which scan jobs apply to which repo types and how to disable the ones that do not apply.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 14 → 15 → 16 → 17 → 18 → 19 → 20

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
| 14. Workflow Foundation and Action Pinning | v2.0 | 3/3 | Complete   | 2026-09-10 |
| 15. Five Parallel Scan Jobs | v2.0 | 5/5 | Complete   | 2026-09-11 |
| 16. SCA Ecosystem Coverage | v2.0 | 1/7 | In Progress|  |
| 17. SARIF Upload and Artifact Retention | v2.0 | 0/? | Not started | - |
| 18. Configurable Gate Mode and Branch Protection | v2.0 | 0/? | Not started | - |
| 19. Pipeline Validation via Branch-Target PRs | v2.0 | 0/? | Not started | - |
| 20. Template Packaging and Adoption Docs | v2.0 | 0/? | Not started | - |
