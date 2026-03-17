# Architecture Research: v1.1 Distribution Packaging

**Domain:** Cross-platform security tool distribution and config management
**Researched:** 2026-03-16
**Confidence:** HIGH (existing architecture well-documented; distribution is an additive layer)

## System Overview

v1.1 adds a distribution layer between the security-platform repo (canonical source) and target repos. The current manual copy-paste flow becomes a scripted, single-command operation.

### Current State (M1)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    security-platform repo                                │
│                                                                          │
│  Canonical configs:                                                      │
│  ┌──────────────────────┐  ┌──────────────────┐  ┌──────────────┐       │
│  │ .pre-commit-config   │  │ .markdownlint    │  │ eslint.config │      │
│  │      .yaml           │  │    .json         │  │    .mjs       │      │
│  └──────────┬───────────┘  └────────┬─────────┘  └──────┬───────┘       │
│             │                       │                     │              │
└─────────────┼───────────────────────┼─────────────────────┼──────────────┘
              │  manual cp            │  manual cp           │  manual cp
              ▼                       ▼                      ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  Target repos (aws-zabbix, terraform-pipelines, etc.)                    │
│  ┌──────────────────────┐  ┌──────────────────┐  ┌──────────────┐       │
│  │ .pre-commit-config   │  │ .markdownlint    │  │ eslint.config │      │
│  │      .yaml           │  │    .json         │  │    .mjs       │      │
│  └──────────────────────┘  └──────────────────┘  └──────────────┘       │
│                                                                          │
│  Tools on PATH: trivy, syft, grype, semgrep, checkov, gitleaks           │
│  (installed via brew/pip — system-wide, Homebrew-only)                   │
└──────────────────────────────────────────────────────────────────────────┘
```

**Problems with current state:**
1. Config deployment is manual `cp` -- error-prone, no version tracking
2. Tool installation requires Homebrew -- Linux users cannot onboard
3. No single command to set up a fresh repo
4. No way to check if tools are current or need updating

### Target State (v1.1)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    security-platform repo                                │
│                                                                          │
│  ┌── dist/ ──────────────────────────────────────────────────────────┐   │
│  │                                                                    │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐    │   │
│  │  │ install.sh   │  │ setup.sh     │  │ configs/             │    │   │
│  │  │ (tool        │  │ (repo setup  │  │  .pre-commit-config  │    │   │
│  │  │  installer)  │  │  + config    │  │  .markdownlint.json  │    │   │
│  │  │              │  │  deployer)   │  │  .markdownlintignore │    │   │
│  │  └──────┬───────┘  └──────┬───────┘  │  .gitleaksignore     │    │   │
│  │         │                  │          └──────────────────────┘    │   │
│  │         │                  │                     ▲                │   │
│  │         │                  └─────────────────────┘                │   │
│  │         │                    reads configs from                    │   │
│  └─────────┼─────────────────────────────────────────────────────────┘   │
│            │                                                             │
└────────────┼─────────────────────────────────────────────────────────────┘
             │
             │  Developer runs:
             │  bash <(curl -sL .../install.sh)     # install tools
             │  bash <(curl -sL .../setup.sh) .     # setup this repo
             ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  Target repo (any git repo)                                              │
│                                                                          │
│  setup.sh drops:                                                         │
│  ┌──────────────────────┐  ┌──────────────────┐  ┌──────────────┐       │
│  │ .pre-commit-config   │  │ .markdownlint    │  │ .gitleaks    │       │
│  │      .yaml           │  │    .json         │  │    ignore     │      │
│  └──────────────────────┘  └──────────────────┘  └──────────────┘       │
│                                                                          │
│  setup.sh activates:                                                     │
│  ┌──────────────────────────────────────────────────────────────┐        │
│  │ pre-commit install + pre-commit install --hook-type pre-push │        │
│  └──────────────────────────────────────────────────────────────┘        │
│                                                                          │
│  Tools on PATH (installed by install.sh):                                │
│  trivy, syft, grype, gitleaks     (binary download)                      │
│  semgrep, checkov, pre-commit     (pip)                                  │
│  hadolint                          (binary download)                     │
└──────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | New/Modified | Location |
|-----------|----------------|-------------|----------|
| `dist/install.sh` | Install all security CLI tools cross-platform (macOS + Linux) | **NEW** | security-platform repo |
| `dist/setup.sh` | Drop configs into target repo, activate pre-commit hooks | **NEW** | security-platform repo |
| `dist/configs/` | Canonical config files for deployment | **NEW** (extracted from repo root) | security-platform repo |
| `.pre-commit-config.yaml` | Hook definitions with file-pattern filters | **MODIFIED** (add file-type filters for selective execution) | Deployed to target repos |
| `.markdownlint.json` | Markdownlint rule suppressions | Unchanged | Deployed to target repos |
| `.markdownlintignore` | Markdownlint directory exclusions | Unchanged | Deployed to target repos |
| `.gitleaksignore` | Template for false positive fingerprints | Unchanged | Deployed to target repos |

## Recommended Architecture

### Where the Install Script Lives: security-platform Repo

**Decision:** Keep `install.sh` and `setup.sh` in the security-platform repo under a `dist/` directory. Do not publish as an npm package or standalone repo.

**Rationale:**
- The security-platform repo already owns the canonical configs -- adding the installer keeps everything in one place
- An npm package adds a publish step, versioning ceremony, and registry dependency for a single-developer practice with 6 repos
- A standalone repo fragments the source of truth -- configs in one place, installer in another
- The scripts can be curl-piped directly from GitHub raw URLs for remote execution, or run locally after cloning

**Trade-offs:**
- Pro: Zero additional infrastructure (no npm registry, no separate repo)
- Pro: Configs and installer are always in sync (same commit)
- Con: Target repo developers need access to security-platform repo (acceptable -- single developer)
- Con: No semantic versioning of the distribution package (acceptable at this scale)

### Two Scripts, Not One

**Decision:** Separate tool installation (`install.sh`) from repo setup (`setup.sh`).

**Rationale:**
- Tool installation is a machine-level concern (once per workstation)
- Repo setup is a per-repo concern (once per git repo)
- A developer may need to re-run setup without reinstalling tools
- A developer may need to update tools without re-deploying configs

**`install.sh` responsibilities:**
1. Detect OS (macOS vs Linux) and architecture (x86_64 vs arm64)
2. Check if each tool is already installed and at a sufficient version
3. Install missing tools via the best cross-platform method:
   - **Binary download:** Trivy, Syft, Grype, Gitleaks, hadolint (Go/Haskell binaries from GitHub Releases)
   - **pip:** pre-commit, Semgrep, Checkov (Python packages)
4. Verify all tools are on PATH and functional
5. Report what was installed/skipped/updated

**`setup.sh` responsibilities:**
1. Verify it is running inside a git repository
2. Copy config files from `dist/configs/` (or embedded in the script) to the repo root
3. Run `pre-commit install` and `pre-commit install --hook-type pre-push`
4. Run `pre-commit run --all-files` as validation
5. Report what was deployed

### Config Flow Architecture

```
                    security-platform/dist/configs/
                    (single source of truth)
                              │
                 ┌────────────┼────────────────┐
                 │            │                │
                 ▼            ▼                ▼
           aws-zabbix/   terraform-       repo-N/
                         pipelines/

  Each target gets IDENTICAL copies.
  No per-repo customization in the config files themselves.
  Per-repo differences handled by:
    - file-type filters in .pre-commit-config.yaml
      (hooks only run when matching files exist)
    - per-repo .markdownlintignore entries
    - per-repo eslint.config.mjs (remains project-managed)
```

**Key insight from M1:** The `.pre-commit-config.yaml` already handles multi-language repos gracefully because pre-commit skips hooks when no matching files exist. A Terraform-only repo naturally skips ESLint. A Python-only repo naturally skips hadolint. No per-repo config variants needed.

### Tool Installation Paths

**Decision:** Project-scoped where the tool supports it; system-wide otherwise.

| Tool | Install Method | Scope | Path |
|------|---------------|-------|------|
| pre-commit | pip | User (`--user`) or venv | `~/.local/bin/pre-commit` |
| Semgrep | pip | User (`--user`) or venv | `~/.local/bin/semgrep` |
| Checkov | pip | User (`--user`) or venv | `~/.local/bin/checkov` |
| Trivy | Binary download | System | `~/.local/bin/trivy` or `/usr/local/bin/trivy` |
| Syft | Binary download | System | `~/.local/bin/syft` or `/usr/local/bin/syft` |
| Grype | Binary download | System | `~/.local/bin/grype` or `/usr/local/bin/grype` |
| Gitleaks | Binary download | System | `~/.local/bin/gitleaks` or `/usr/local/bin/gitleaks` |
| hadolint | Binary download | System | `~/.local/bin/hadolint` or `/usr/local/bin/hadolint` |

**Scope strategy:**
- Prefer `~/.local/bin/` (user-scoped, no sudo required) over `/usr/local/bin/` (requires sudo)
- pip tools use `pip install --user` to avoid `--break-system-packages` and venv complexity
- Binary tools download to `~/.local/bin/` by default, with a flag for `/usr/local/bin/` if preferred
- The install script ensures `~/.local/bin` is on PATH (adds to `~/.bashrc` or `~/.zshrc` if needed)

**Why not truly project-scoped (node_modules/.bin style):**
- These are security scanning tools, not project dependencies
- They need to work across all repos, not be installed per-repo
- Project-scoped would mean 6x disk usage for identical binaries
- pre-commit itself manages hook tool versions per-repo via its own cache

## Data Flow

### Installation Flow

```
Developer runs: bash install.sh
    │
    ├── Detect OS + arch
    │       │
    │       ├── macOS arm64 → download darwin-arm64 binaries
    │       ├── macOS x86_64 → download darwin-amd64 binaries
    │       └── Linux x86_64 → download linux-amd64 binaries
    │
    ├── For each tool:
    │       │
    │       ├── Check: is it installed? → Yes → check version
    │       │                                      │
    │       │                              Sufficient? → Yes → skip
    │       │                                      │
    │       │                              No → upgrade
    │       │
    │       └── Not installed → install
    │
    └── Verify all tools on PATH
            │
            └── Print summary table
```

### Setup Flow

```
Developer runs: bash setup.sh [target-dir]
    │
    ├── Verify: is target a git repo?
    │       │
    │       No → error and exit
    │
    ├── Check: are tools installed?
    │       │
    │       No → suggest running install.sh first
    │
    ├── Copy configs to target repo root:
    │       │
    │       ├── .pre-commit-config.yaml
    │       ├── .markdownlint.json
    │       ├── .markdownlintignore (if not exists — don't overwrite)
    │       └── .gitleaksignore (template, if not exists)
    │
    ├── Activate hooks:
    │       │
    │       ├── pre-commit install
    │       └── pre-commit install --hook-type pre-push
    │
    └── Validate:
            │
            └── pre-commit run --all-files (report result, don't fail script)
```

### Version Check Flow

```
Developer runs: bash install.sh --check
    │
    └── For each tool:
            │
            ├── Run: tool --version
            ├── Compare against minimum version in script
            └── Print: tool | installed | minimum | status (OK/UPGRADE/MISSING)
```

## Architectural Patterns

### Pattern 1: Curl-Pipe Install with Local Fallback

**What:** Scripts can be run directly via `curl | bash` from GitHub raw URL, or locally after cloning the security-platform repo.

**When to use:** Always. The curl-pipe pattern provides convenience for one-off setup; local execution provides repeatability and auditability.

**Trade-offs:**
- Pro: No package manager dependency for the distribution itself
- Pro: Works on any machine with curl and bash
- Con: Curl-pipe is not verifiable before execution (mitigated by: single developer, trusted repo)
- Con: GitHub raw URL availability dependency (mitigated by: local clone fallback)

**Example:**
```bash
# Remote execution (convenience)
bash <(curl -sL https://raw.githubusercontent.com/ORG/security-platform/main/dist/install.sh)

# Local execution (auditable)
git clone git@github.com:ORG/security-platform.git
bash security-platform/dist/install.sh
```

### Pattern 2: Idempotent Installation

**What:** Running `install.sh` multiple times produces the same result. Already-installed tools at sufficient versions are skipped. Version checks prevent unnecessary downloads.

**When to use:** Always. The install script must be safe to re-run.

**Trade-offs:**
- Pro: Developer can run install.sh as a health check without side effects
- Pro: Enables `--check` mode that reports status without installing
- Con: Version comparison logic in bash is fragile (mitigated by: simple semver comparison function)

### Pattern 3: Config-as-Copy, Not Config-as-Link

**What:** Setup copies configs to target repos rather than symlinking to the security-platform repo.

**When to use:** Always for this project. Symlinks break when the security-platform repo is not cloned locally.

**Trade-offs:**
- Pro: Target repos are self-contained -- they work without security-platform being cloned
- Pro: Explicit versioning -- `git diff` shows exactly what changed
- Con: Drift is possible (config updated in security-platform but not re-deployed)
- Con: No automatic propagation of updates

**Drift detection:** `setup.sh --diff` mode compares deployed configs against canonical versions and reports differences.

### Pattern 4: File-Type Filters for Language-Aware Execution

**What:** Each pre-commit hook specifies `types:` or `files:` filters so it only runs when matching files are staged. Repos without Python files never trigger Ruff. Repos without Dockerfiles never trigger hadolint.

**When to use:** Always. This is what enables a single universal `.pre-commit-config.yaml` across diverse repos.

**Trade-offs:**
- Pro: One config serves all repos regardless of language mix
- Pro: No per-repo customization needed
- Pro: Zero overhead for irrelevant hooks (they skip instantly)
- Con: File-type matching must be tested for edge cases

## Anti-Patterns

### Anti-Pattern 1: Per-Repo Config Variants

**What people do:** Create repo-specific `.pre-commit-config.yaml` variants for repos with different language stacks.
**Why it's wrong:** Configuration drift becomes unmanageable at 6+ repos. Updates must be applied N times instead of once. Bugs in one variant may not be fixed in others.
**Do this instead:** Use one universal config with file-type filters. pre-commit already skips hooks with no matching files. The only per-repo files should be `.markdownlintignore` (directory exclusions) and `eslint.config.mjs` (project-specific).

### Anti-Pattern 2: npm Package for Internal Distribution

**What people do:** Create an npm package to distribute configs and install scripts, requiring `npm install -g @org/security-setup`.
**Why it's wrong:** Adds npm registry dependency, publish workflow, version management, and Node.js as a prerequisite for non-JS repos. Overkill for a single developer with 6 repos.
**Do this instead:** Plain bash scripts in the security-platform repo. No build step, no publish step, no registry dependency.

### Anti-Pattern 3: Global git hooks via core.hooksPath

**What people do:** Set `git config --global core.hooksPath` to point all repos at a shared hooks directory, bypassing per-repo `.pre-commit-config.yaml`.
**Why it's wrong:** Breaks pre-commit's per-repo hook management. Cannot have different hook versions per repo. Invisible to collaborators (not committed to the repo).
**Do this instead:** Deploy `.pre-commit-config.yaml` per repo and use `pre-commit install` in each. This is explicit, version-controlled, and visible.

### Anti-Pattern 4: Embedding All Configs in the Install Script

**What people do:** Embed config file contents as heredocs inside install.sh, making it a single file.
**Why it's wrong:** Makes configs hard to diff, review, and update. The YAML becomes invisible inside bash. Version control shows script changes, not config changes.
**Do this instead:** Keep configs as standalone files in `dist/configs/`. The setup script copies them. Configs are independently diffable and reviewable.

## Build Order (Dependency-Driven)

The v1.1 milestone has clear internal dependencies. Build in this order:

```
Phase 1: install.sh (tool installer)
    │
    │  No dependencies. This is the foundation.
    │  Replaces: manual Homebrew commands from M1 Installation Guide
    │
    ▼
Phase 2: File-pattern hooks
    │
    │  Depends on: tools being installable (Phase 1 validates this)
    │  Modifies: .pre-commit-config.yaml with types:/files: filters
    │
    ▼
Phase 3: setup.sh (repo bootstrapper)
    │
    │  Depends on: install.sh (verifies tools exist), configs (deploys them)
    │  Bundles: config deployment + hook activation + validation
    │
    ▼
Phase 4: Integration validation
    │
    │  Depends on: everything above
    │  Tests: fresh repo setup end-to-end on macOS
    │  Tests: install.sh --check version reporting
    │  Tests: setup.sh --diff drift detection
```

**Phase ordering rationale:**

1. **install.sh first** because it is the most complex component (OS detection, binary downloads, version comparison) and has no dependencies. It also validates that the cross-platform installation methods actually work, which gates everything else.

2. **File-pattern hooks second** because the updated `.pre-commit-config.yaml` needs to be tested with the tools installed by Phase 1. This is a config modification to an existing file -- lower risk than the new scripts.

3. **setup.sh third** because it depends on both the install script (to verify prerequisites) and the finalized configs (to deploy them). Writing it last means the inputs are stable.

4. **Integration validation last** because it exercises the full flow: install tools, setup repo, run hooks. This is the end-to-end acceptance test.

## Integration Points

### New Components Integrating with Existing Architecture

| New Component | Integrates With | How | Notes |
|---------------|----------------|-----|-------|
| `install.sh` | GitHub Releases API | HTTP download of binaries | Trivy, Syft, Grype, Gitleaks, hadolint release tarballs |
| `install.sh` | PyPI | `pip install --user` | pre-commit, Semgrep, Checkov |
| `install.sh` | User's PATH | Adds `~/.local/bin` if missing | Must handle both bash and zsh profiles |
| `setup.sh` | Target git repos | Copies configs, runs `pre-commit install` | Must detect existing configs and prompt before overwriting |
| `setup.sh` | `dist/configs/` | Reads canonical configs | Source of truth for all config files |
| `dist/configs/` | Existing `.pre-commit-config.yaml` | Replaces manual copy from security-platform root | File-pattern filters added |

### Unchanged Integration Points

| Existing Component | Status | Notes |
|--------------------|--------|-------|
| pre-commit hook execution | Unchanged | Hooks still run on commit/push as before |
| Gitleaks pre-push gate | Unchanged | Same config, same behavior |
| CLI tool scan commands | Unchanged | Same tools, same commands, just installed differently |
| JSON report output | Unchanged | Same formats, same downstream compatibility (M2 CI, M4 DefectDojo) |

### Modified Components

| Component | What Changes | Why |
|-----------|-------------|-----|
| `.pre-commit-config.yaml` | Add explicit `types:` and `files:` filters to all hooks | Enable selective execution -- hooks skip when no matching files are staged |
| M1 Installation Guide | Reference `install.sh` as primary install method, keep manual steps as fallback | Distribution package replaces manual installation |
| M1 Developer Guide "Rolling Out" section | Reference `setup.sh` as primary setup method | Distribution package replaces manual copy-paste |

## Sources

- Trivy installation methods: [trivy.dev/docs/latest/getting-started/installation/](https://trivy.dev/docs/latest/getting-started/installation/)
- Grype install script: [oss.anchore.com/docs/installation/grype/](https://oss.anchore.com/docs/installation/grype/)
- Syft install script: [oss.anchore.com/docs/installation/syft/](https://oss.anchore.com/docs/installation/syft/)
- Gitleaks binary releases: [github.com/gitleaks/gitleaks](https://github.com/gitleaks/gitleaks)
- hadolint binary releases: [github.com/hadolint/hadolint](https://github.com/hadolint/hadolint)
- Pre-commit hooks multi-repo maintenance: [thedissonance.net/2024/03/27/pre-commit-hooks.html](https://thedissonance.net/2024/03/27/pre-commit-hooks.html)
- Existing architecture: `.planning/research/ARCHITECTURE.md` (M1 version), `docs/milestone-1-workstation/DEVELOPER_GUIDE.md`
- Current install methods: `docs/milestone-1-workstation/INSTALLATION_GUIDE.md`

---
*Architecture research for: v1.1 distribution packaging integration*
*Researched: 2026-03-16*
