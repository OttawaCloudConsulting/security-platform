# Roadmap: M1 — Developer Workstation Foundation

## Overview

M1 delivers the developer workstation security layer: a pre-commit framework with 9 language-specific linting hooks and Gitleaks secrets detection, plus 6 security CLI tools installed and validated for local scanning and JSON report generation. This is the dependency-free starting point — no infrastructure required, immediate value on every commit. The roadmap progresses from framework installation through hook categories to CLI tool installation and ends with full-stack validation.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Pre-commit Framework** - Install pre-commit and create the hook configuration file (completed 2026-03-16)
- [x] **Phase 2: Shell and Python Hooks** - ShellCheck and Ruff linting on every commit (completed 2026-03-16)
- [x] **Phase 3: Web and Config Hooks** - ESLint, hadolint, yamllint, and markdownlint on every commit (completed 2026-03-15)
- [x] **Phase 4: Infrastructure Hooks** - npm audit, terraform fmt, and terraform validate on every commit (completed 2026-03-16)
- [x] **Phase 5: Secrets Detection Gate** - Gitleaks pre-push hook blocks leaked credentials (completed 2026-03-16)
- [x] **Phase 6: SCA and Container CLI Tools** - Trivy, Syft, and Grype installed and on PATH (completed 2026-03-16)
- [ ] **Phase 7: SAST and IaC CLI Tools** - Semgrep, Checkov, and Gitleaks CLI installed and on PATH
- [ ] **Phase 8: CLI Tool Scanning Validation** - Every CLI tool runs a real scan and produces JSON output
- [ ] **Phase 9: Full Stack Validation** - All hooks pass cleanly across the entire repository

## Phase Details

### Phase 1: Pre-commit Framework
**Goal**: Developer has a working pre-commit framework with the configuration file committed to the target repository
**Depends on**: Nothing (first phase)
**Requirements**: PCOM-01, PCOM-02, PCOM-03
**Success Criteria** (what must be TRUE):
  1. `pre-commit --version` succeeds and shows a current version
  2. `.pre-commit-config.yaml` exists in the target repository root and is committed to version control
  3. `git commit` triggers pre-commit hooks (verified by a test commit)
**Plans:** 1/1 plans complete

Plans:
- [ ] 01-01-PLAN.md — Initialize canonical config in security-platform and deploy to target repo with hook activation

### Phase 2: Shell and Python Hooks
**Goal**: Shell scripts and Python files are automatically checked for quality issues on every commit
**Depends on**: Phase 1
**Requirements**: LINT-01, LINT-02
**Success Criteria** (what must be TRUE):
  1. Committing a shell script with an unquoted variable triggers a ShellCheck warning
  2. Committing a Python file with formatting violations triggers Ruff auto-fix and the file is reformatted
  3. Both hooks appear in `pre-commit run --show-diff-on-failure` output when violations exist
**Plans:** 1/1 plans complete

Plans:
- [ ] 02-01-PLAN.md — Fix ShellCheck and Ruff violations so both hooks pass cleanly

### Phase 3: Web and Config Hooks
**Goal**: TypeScript/JavaScript, Dockerfiles, YAML manifests, and Markdown files are automatically checked on every commit
**Depends on**: Phase 1
**Requirements**: LINT-03, LINT-04, LINT-05, LINT-06
**Success Criteria** (what must be TRUE):
  1. Committing a JS/TS file with a linting violation triggers an ESLint error
  2. Committing a Dockerfile with a best-practice violation triggers a hadolint warning
  3. Committing a YAML file with formatting issues triggers a yamllint error
  4. Committing a Markdown file with style issues triggers a markdownlint error
**Plans:** 2/2 plans complete

Plans:
- [ ] 03-01-PLAN.md — Install ESLint with typescript-eslint, fix all TS violations, verify hook passes
- [ ] 03-02-PLAN.md — Configure markdownlint, verify yamllint, verify hadolint via temp file test

### Phase 4: Infrastructure Hooks
**Goal**: npm dependencies, Terraform formatting, and Terraform syntax are automatically checked on every commit
**Depends on**: Phase 1
**Requirements**: LINT-07, LINT-08, LINT-09
**Success Criteria** (what must be TRUE):
  1. Committing a changed `package-lock.json` triggers npm audit
  2. Committing an unformatted `.tf` file triggers terraform fmt auto-formatting
  3. Committing a `.tf` file with invalid HCL syntax triggers a terraform validate error
**Plans:** 1/1 plans complete

Plans:
- [ ] 04-01-PLAN.md — Fix npm audit violations, clone terraform-pipelines, validate terraform_fmt and terraform_validate hooks end-to-end

### Phase 5: Secrets Detection Gate
**Goal**: Credentials and secrets are blocked from being pushed to the remote repository
**Depends on**: Phase 1
**Requirements**: SECR-01, SECR-02, SECR-03
**Success Criteria** (what must be TRUE):
  1. `git push` triggers Gitleaks in `protect --staged` mode via the pre-push hook
  2. A commit containing a dummy AWS key pattern (`AKIAIOSFODNN7EXAMPLE`) is blocked on push
  3. Developer can articulate that `--no-verify` bypasses the hook and that CI (M2) is the compensating control
**Plans:** 2/2 plans complete

Plans:
- [x] 05-01-PLAN.md — Install Gitleaks, reconfigure pre-push hook in all three repos, baseline scans
- [x] 05-02-PLAN.md — End-to-end dummy AWS key test and bypass documentation

### Phase 6: SCA and Container CLI Tools
**Goal**: The supply chain analysis toolchain (SBOM generation, vulnerability matching, container scanning) is installed and available locally
**Depends on**: Nothing (independent of hook phases)
**Requirements**: TOOL-01, TOOL-02, TOOL-03
**Success Criteria** (what must be TRUE):
  1. `trivy --version` succeeds and shows version >= 0.69.2
  2. `syft version` succeeds and shows a current version
  3. `grype version` succeeds and shows version >= 0.88.0 (required: DB schema v5 EOL was 2026-03-06)
**Plans:** 1/1 plans complete

Plans:
- [x] 06-01-PLAN.md — Install/upgrade Trivy, Syft, Grype via Homebrew and update main doc with verified versions

### Phase 7: SAST and IaC CLI Tools
**Goal**: The static analysis and IaC scanning toolchain is installed and available locally alongside the secrets scanner
**Depends on**: Nothing (independent of hook phases)
**Requirements**: TOOL-04, TOOL-05, TOOL-06
**Success Criteria** (what must be TRUE):
  1. `semgrep --version` succeeds and shows a current version
  2. `checkov --version` succeeds and shows a current version
  3. `gitleaks version` succeeds and shows a current version
**Plans:** 1 plan

Plans:
- [ ] 07-01-PLAN.md — Install Semgrep via pip, verify all three tools on PATH, update main doc with verified versions

### Phase 8: CLI Tool Scanning Validation
**Goal**: Every security CLI tool can run a real scan against the local repository and produce machine-readable JSON output
**Depends on**: Phase 6, Phase 7
**Requirements**: TOOL-07, TOOL-08
**Success Criteria** (what must be TRUE):
  1. Each of the 6 tools (Trivy, Syft, Grype, Semgrep, Checkov, Gitleaks) completes a scan against the local repository without errors
  2. Each tool produces a valid JSON report file that can be parsed (needed for M2 CI and M4 DefectDojo import)
  3. JSON output files exist on disk and contain scan results (not empty or error-only output)
**Plans:** 2 plans

Plans:
- [x] 08-01-PLAN.md — Run all 6 CLI tools against aws-zabbix repo, capture JSON reports, add validation notes to main doc
- [ ] 08-02-PLAN.md — (gap closure) Re-run Grype scan with --file flag to fix invalid JSON output

### Phase 9: Full Stack Validation
**Goal**: The entire pre-commit hook suite passes cleanly across the full repository with all existing issues resolved or suppressed
**Depends on**: Phase 2, Phase 3, Phase 4, Phase 5
**Requirements**: PCOM-04
**Success Criteria** (what must be TRUE):
  1. `pre-commit run --all-files` completes with exit code 0
  2. All 9 Tier 1 hooks and the Gitleaks Tier 2 hook execute without failure
  3. Any pre-existing issues are either fixed in the codebase or explicitly suppressed with inline annotations
**Plans**: TBD

Plans:
- [ ] 09-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9
Note: Phases 2/3/4 depend only on Phase 1 (parallel-eligible). Phases 6/7 have no dependencies (parallel-eligible with 1-5).

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Pre-commit Framework | 1/1 | Complete    | 2026-03-16 |
| 2. Shell and Python Hooks | 1/1 | Complete    | 2026-03-15 |
| 3. Web and Config Hooks | 2/2 | Complete    | 2026-03-15 |
| 4. Infrastructure Hooks | 1/1 | Complete   | 2026-03-16 |
| 5. Secrets Detection Gate | 2/2 | Complete | 2026-03-16 |
| 6. SCA and Container CLI Tools | 1/1 | Complete | 2026-03-16 |
| 7. SAST and IaC CLI Tools | 0/1 | Not started | - |
| 8. CLI Tool Scanning Validation | 1/2 | In progress | - |
| 9. Full Stack Validation | 0/? | Not started | - |
