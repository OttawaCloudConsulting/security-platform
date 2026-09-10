# Roadmap: Security & Supply Chain Scanning Stack

## Milestones

- **v1.0 M1 Workstation Foundation** - Phases 1-9 (shipped 2026-03-17)
- **v1.1 Distribution Packaging** - Phases 10-13 (in progress)

## Phases

<details>
<summary>v1.0 M1 Workstation Foundation (Phases 1-9) - SHIPPED 2026-03-17</summary>

- [x] **Phase 1: Pre-commit Framework** - Install pre-commit and create the hook configuration file (completed 2026-03-16)
- [x] **Phase 2: Shell and Python Hooks** - ShellCheck and Ruff linting on every commit (completed 2026-03-16)
- [x] **Phase 3: Web and Config Hooks** - ESLint, hadolint, yamllint, and markdownlint on every commit (completed 2026-03-15)
- [x] **Phase 4: Infrastructure Hooks** - npm audit, terraform fmt, and terraform validate on every commit (completed 2026-03-16)
- [x] **Phase 5: Secrets Detection Gate** - Gitleaks pre-push hook blocks leaked credentials (completed 2026-03-16)
- [x] **Phase 6: SCA and Container CLI Tools** - Trivy, Syft, and Grype installed and on PATH (completed 2026-03-16)
- [x] **Phase 7: SAST and IaC CLI Tools** - Semgrep, Checkov, and Gitleaks CLI installed and on PATH (completed 2026-03-16)
- [x] **Phase 8: CLI Tool Scanning Validation** - Every CLI tool runs a real scan and produces JSON output (completed 2026-03-16)
- [x] **Phase 9: Full Stack Validation** - All hooks pass cleanly across the entire repository (completed 2026-03-17)

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

- [x] 01-01-PLAN.md -- Initialize canonical config in security-platform and deploy to target repo with hook activation

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

- [x] 02-01-PLAN.md -- Fix ShellCheck and Ruff violations so both hooks pass cleanly

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

- [x] 03-01-PLAN.md -- Install ESLint with typescript-eslint, fix all TS violations, verify hook passes
- [x] 03-02-PLAN.md -- Configure markdownlint, verify yamllint, verify hadolint via temp file test

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

- [x] 04-01-PLAN.md -- Fix npm audit violations, clone terraform-pipelines, validate terraform_fmt and terraform_validate hooks end-to-end

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

- [x] 05-01-PLAN.md -- Install Gitleaks, reconfigure pre-push hook in all three repos, baseline scans
- [x] 05-02-PLAN.md -- End-to-end dummy AWS key test and bypass documentation

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

- [x] 06-01-PLAN.md -- Install/upgrade Trivy, Syft, Grype via Homebrew and update main doc with verified versions

### Phase 7: SAST and IaC CLI Tools

**Goal**: The static analysis and IaC scanning toolchain is installed and available locally alongside the secrets scanner
**Depends on**: Nothing (independent of hook phases)
**Requirements**: TOOL-04, TOOL-05, TOOL-06
**Success Criteria** (what must be TRUE):

  1. `semgrep --version` succeeds and shows a current version
  2. `checkov --version` succeeds and shows a current version
  3. `gitleaks version` succeeds and shows a current version

**Plans:** 1/1 plans complete

Plans:

- [x] 07-01-PLAN.md -- Install Semgrep via pip, verify all three tools on PATH, update main doc with verified versions

### Phase 8: CLI Tool Scanning Validation

**Goal**: Every security CLI tool can run a real scan against the local repository and produce machine-readable JSON output
**Depends on**: Phase 6, Phase 7
**Requirements**: TOOL-07, TOOL-08
**Success Criteria** (what must be TRUE):

  1. Each of the 6 tools (Trivy, Syft, Grype, Semgrep, Checkov, Gitleaks) completes a scan against the local repository without errors
  2. Each tool produces a valid JSON report file that can be parsed (needed for M2 CI and M4 DefectDojo import)
  3. JSON output files exist on disk and contain scan results (not empty or error-only output)

**Plans:** 2/2 plans complete

Plans:

- [x] 08-01-PLAN.md -- Run all 6 CLI tools against aws-zabbix repo, capture JSON reports, add validation notes to main doc
- [x] 08-02-PLAN.md -- (gap closure) Re-run Grype scan with --file flag to fix invalid JSON output

### Phase 9: Full Stack Validation

**Goal**: The entire pre-commit hook suite passes cleanly across the full repository with all existing issues resolved or suppressed
**Depends on**: Phase 2, Phase 3, Phase 4, Phase 5
**Requirements**: PCOM-04
**Success Criteria** (what must be TRUE):

  1. `pre-commit run --all-files` completes with exit code 0
  2. All 9 Tier 1 hooks and the Gitleaks Tier 2 hook execute without failure
  3. Any pre-existing issues are either fixed in the codebase or explicitly suppressed with inline annotations

**Plans:** 2/2 plans complete

Plans:

- [x] 09-01-PLAN.md -- Install native hadolint, switch hook ID from hadolint-docker to hadolint in all repos, add markdownlint config to terraform-pipelines
- [x] 09-02-PLAN.md -- Run pre-commit --all-files in both repos to exit 0, validate Gitleaks separately, add validation stamp to main doc

</details>

## v1.1 Distribution Packaging (In Progress)

**Milestone Goal:** Replace Homebrew-based tool installation with cross-platform methods (pip/npm/binary) and create a distribution package that sets up security tooling in any fresh git repo with a single command.

- [x] **Phase 10: Cross-Platform Install Script** - install.sh installs all security CLI tools on macOS and Linux without Homebrew (completed 2026-03-18)
- [x] **Phase 11: File-Pattern Hook Configuration** - Universal pre-commit config with language-aware filters for selective hook execution (completed 2026-03-22)
- [x] **Phase 12: Repo Setup Script** - setup.sh copies configs and wires hooks in any git repo with one command (completed 2026-03-22)
- [ ] **Phase 13: Maintenance and Validation** - Version check, update, and health check commands for installed tools

## Phase Details

### Phase 10: Cross-Platform Install Script

**Goal**: Developer can install the complete security CLI tool suite on any macOS or Linux machine with a single script, no Homebrew required
**Depends on**: Nothing (foundation for this milestone)
**Requirements**: INST-01, INST-02, INST-03, INST-04, INST-05, INST-06, INST-07
**Success Criteria** (what must be TRUE):

  1. Running `bash dist/install.sh` on macOS arm64 installs all 6 security CLI tools (pre-commit, Trivy, Syft, Grype, Gitleaks, hadolint) and each responds to its version command
  2. The script reads tool versions from a manifest file and installs those exact versions (not latest)
  3. pre-commit is installed via pipx and isolated from system Python (Semgrep and Checkov deferred to CI-only in M2)
  4. Go/Haskell tools (Trivy, Syft, Grype, Gitleaks, hadolint) are installed via official install scripts or direct binary download with OS/arch auto-detection
  5. After install completes, the script verifies all tool locations are on PATH and warns if any are missing

**Plans:** 2/2 plans complete

Plans:

- [ ] 10-01-PLAN.md -- Version manifest and install script framework with pipx/pre-commit installer
- [ ] 10-02-PLAN.md -- Binary tool installers (Trivy, Syft, Grype, Gitleaks, hadolint) and ROADMAP update

### Phase 11: File-Pattern Hook Configuration

**Goal**: A single universal pre-commit config works correctly across all repos by only running hooks on matching file types
**Depends on**: Phase 10 (tools must be installable to validate hooks execute correctly)
**Requirements**: DIST-04
**Success Criteria** (what must be TRUE):

  1. Every hook in `.pre-commit-config.yaml` has explicit `types:` or `files:` filters that restrict execution to relevant files
  2. Running `pre-commit run --all-files` in a Python-only repo skips ESLint, hadolint, terraform, and npm hooks cleanly (exit 0, no errors)
  3. Running `pre-commit run --all-files` in a Terraform-only repo skips Ruff, ESLint, and npm hooks cleanly

**Plans:** 1/1 plans complete

Plans:

- [x] 11-01-PLAN.md -- Add explicit type/file filters to all hooks, validate across three repo types

### Phase 12: Repo Setup Script

**Goal**: Validate and fix the existing setup.sh so it reliably onboards any git repo with a single command
**Depends on**: Phase 10, Phase 11 (tools must be installed; config must be finalized before deployment)
**Requirements**: DIST-01, DIST-02, DIST-03, DIST-05
**Success Criteria** (what must be TRUE):

  1. Running `bash setup.sh` in a git repo copies `.pre-commit-config.yaml` and all linting configs into the repo root
  2. After setup completes, `pre-commit run --all-files` works (hooks are installed for both commit and pre-push)
  3. Running setup.sh a second time in the same repo produces no errors and does not corrupt existing configs or user-customized files (e.g., `.gitleaksignore`)

**Plans:** 1/1 plans complete

Plans:

- [x] 12-01-PLAN.md -- Fix bash 3.2 compat, add require_git_repo call, add .markdownlintignore generation

### Phase 13: Maintenance and Validation

**Goal**: Developer can check tool health, compare installed versions against expected versions, and update outdated tools
**Depends on**: Phase 10 (install script establishes the version manifest and install paths that maintenance commands operate on)
**Requirements**: MAINT-01, MAINT-02, MAINT-03
**Success Criteria** (what must be TRUE):

  1. Running `bash repos/security-platform/workstation/setup.sh check` shows a table of all tools with installed version vs expected version, highlights any mismatches, and exits non-zero when any tool is missing or mismatched
  2. Running `bash repos/security-platform/workstation/setup.sh update` upgrades any outdated tool to the version pinned in `versions.conf`, continues past individual failures, falls back to the latest release within the pinned major when the exact pin is unavailable, logs anything it could not fix, and exits non-zero only when a tool failed both attempts
  3. Running `bash repos/security-platform/workstation/setup.sh doctor` verifies every tool is on PATH and can execute its version command, reporting `OK` / `NOT_ON_PATH` / `BROKEN` / `UNPARSEABLE` per tool plus PATH and prerequisite health, and exits non-zero on any problem

> **Path correction (see 13-CONTEXT.md D-01):** earlier drafts of these criteria referenced
> `bash dist/install.sh --check/--update/--doctor`. That path and flag style are stale. The real
> target is `repos/security-platform/workstation/setup.sh` (a sibling checkout), using subcommand
> style to match the existing `install|configure|setup|check` dispatcher. No `dist/install.sh` is
> created by this phase.

**Plans**: 7 plans

Plans:
**Wave 1**

- [x] 13-01-PLAN.md -- Main-guard for sourceability + plain-bash test harness and GitHub JSON fixtures (Nyquist Wave 0)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 13-02-PLAN.md -- Authenticated gh_api_get, whitespace-tolerant JSON parsing, resolve_latest_in_major

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 13-03-PLAN.md -- pipx --force / ensure_pipx fixes, attempt_install, failure-log writer

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 13-04-PLAN.md -- update subcommand: two-attempt fallback loop, downgrade guard, selective per-tool targeting

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 13-05-PLAN.md -- doctor subcommand, tool_health probe, check/doctor exit-code contract

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 13-06-PLAN.md -- README and ARCHITECTURE documentation, failure-log gitignore rule

**Wave 7** *(blocked on Wave 6 completion)*

- [ ] 13-07-PLAN.md -- Human-verified pre-commit downgrade/upgrade round trip and doctor sanity check

## Progress

**Execution Order:**
Phases execute in numeric order: 10 -> 11 -> 12 -> 13
Note: Phase 11 depends on Phase 10. Phase 12 depends on Phases 10 and 11. Phase 13 depends on Phase 10.

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
| 10. Cross-Platform Install Script | 2/2 | Complete   | 2026-03-18 | - |
| 11. File-Pattern Hook Configuration | v1.1 | 1/1 | Complete | 2026-03-22 |
| 12. Repo Setup Script | v1.1 | 1/1 | Complete | 2026-03-22 |
| 13. Maintenance and Validation | v1.1 | 6/7 | In Progress|  |
