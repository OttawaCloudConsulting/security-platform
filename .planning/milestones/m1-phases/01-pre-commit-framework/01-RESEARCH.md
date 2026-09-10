# Phase 1: Pre-commit Framework - Research

**Researched:** 2026-03-15
**Domain:** pre-commit hook framework installation and configuration
**Confidence:** HIGH

## Summary

Phase 1 is a straightforward infrastructure setup phase: install pre-commit, create the config file in two repos (canonical source in `security-platform`, deployed copy in the target repo `aws-zabbix-monitoring-solution`), and verify hook execution on commit. The pre-commit framework (v4.5.0) is already installed on the developer workstation. Both repos are already cloned into `repos/`. The `security-platform` repo already has a `feature/m1-workstation-foundation` branch checked out. The target repo has no existing `.pre-commit-config.yaml`.

The complete `.pre-commit-config.yaml` content is specified verbatim in the reference document (lines 1302-1384). This is a copy-paste operation, not a design exercise. The config includes 9 Tier 1 hooks and 1 Tier 2 hook (Gitleaks). Version pins from the reference document should be used as-is, with optional `pre-commit autoupdate` to bump to latest.

**Primary recommendation:** Copy the exact config from the reference document, place it in both repos, run `pre-commit install` in the target repo, and verify with a test commit. No design decisions needed -- everything is specified.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Planning repo** (`security_solution/`) stays documentation/planning only -- no deployable code here
- **Implementation repo** (`security-platform`) on GitHub (private, `OttawaCloudConsulting/security-platform`) holds the canonical config files
- **Target repos** get pre-commit installed with the config copied/placed from the canonical source
- Both repos are cloned into `security_solution/repos/` for development access
- Work happens on feature branches, not main directly
- First target repo: `OttawaCloudConsulting/aws-zabbix-monitoring-solution` (AWS CDK TypeScript project), cloned to `repos/aws-zabbix-monitoring-solution/`
- Phase 1 commits the FULL `.pre-commit-config.yaml` from the reference document (all 9 Tier 1 hooks + Gitleaks Tier 2)
- Phases 2-5 validate and test each hook category -- they don't need to add hooks to the config
- Use the versions from the reference document as the starting point; `pre-commit autoupdate` can bump to latest before committing

### Claude's Discretion
- Whether to run `pre-commit autoupdate` before or after initial commit
- README or documentation additions to `security-platform`
- `.gitignore` contents for `security-platform`

### Deferred Ideas (OUT OF SCOPE)
- Multi-repo rollout (applying pre-commit to remaining 5+ repos) -- after M1 validation on first target
- Template/automation for distributing config updates across repos -- future consideration
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PCOM-01 | Developer can install pre-commit framework via `pip install pre-commit` or `brew install pre-commit` | Already installed: `pre-commit 4.5.0` on PATH via pyenv. Verification command: `pre-commit --version` |
| PCOM-02 | `.pre-commit-config.yaml` is committed to the target repository root with all Tier 1 and Tier 2 hooks configured | Full config content available in reference doc lines 1302-1384. Copy verbatim to both repos |
| PCOM-03 | `pre-commit install` activates hooks in the target repository | Standard command; creates `.git/hooks/pre-commit` symlink |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| pre-commit | 4.5.0 (installed) | Git hook framework | Industry standard for multi-language hook management |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| git | (system) | Version control | Branching, committing, hook triggering |
| pip/pyenv | (system) | Python package management | pre-commit is already installed via this path |

### Alternatives Considered
None -- pre-commit is the locked decision from CONTEXT.md and the reference document.

**Installation:**
```bash
# Already installed -- verify only
pre-commit --version
# If reinstall needed:
pip install pre-commit
# Or:
brew install pre-commit
```

## Architecture Patterns

### Recommended Repository Structure

**security-platform (canonical source):**
```
security-platform/
├── .pre-commit-config.yaml    # Canonical config, source of truth
├── .gitignore                 # Standard ignores
└── README.md                  # Optional docs
```

**aws-zabbix-monitoring-solution (target repo):**
```
aws-zabbix-monitoring-solution/
├── .pre-commit-config.yaml    # Deployed copy from canonical source
├── .git/hooks/pre-commit      # Created by `pre-commit install`
└── (existing project files)
```

### Pattern 1: Canonical Config in Implementation Repo
**What:** The `.pre-commit-config.yaml` lives as a source-of-truth in `security-platform`, then is copied to target repos.
**When to use:** Always for this project -- this is the locked decision.
**Workflow:**
1. Create/edit config in `security-platform` on feature branch
2. Copy identical config to target repo on its own feature branch
3. Run `pre-commit install` in target repo
4. Verify hooks fire on commit

### Pattern 2: Feature Branch Workflow
**What:** All changes go on feature branches, not main.
**Branches:**
- `security-platform`: already on `feature/m1-workstation-foundation`
- `aws-zabbix-monitoring-solution`: needs a new feature branch (e.g., `feature/add-pre-commit`)

### Anti-Patterns to Avoid
- **Editing config only in the target repo:** The canonical source is `security-platform`. If you edit only in the target repo, the source of truth diverges.
- **Running `pre-commit run --all-files` in Phase 1:** Phase 1 only needs to verify hooks trigger. Running `--all-files` will likely fail because individual hooks are not yet validated (that is Phases 2-5). A simple test commit is sufficient.
- **Installing pre-commit hooks globally:** `pre-commit install` is per-repo. Run it in the target repo specifically.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Git hook management | Manual `.git/hooks/` scripts | `pre-commit install` | pre-commit handles hook lifecycle, virtual environments, caching |
| Hook version management | Manual git submodules or downloads | `pre-commit autoupdate` | Single command bumps all hook versions |
| Config validation | Manual YAML checking | `pre-commit validate-config` | Built-in validation |

## Common Pitfalls

### Pitfall 1: Hooks fail on first run because tools are not installed
**What goes wrong:** Some hooks (ESLint, npm audit) use `language: system` and require the tool to be available locally. If `npx eslint` or `npm audit` is not available, those hooks fail.
**Why it happens:** The target repo uses local hooks that depend on the project's node_modules.
**How to avoid:** Ensure `npm install` has been run in the target repo before `pre-commit install`. The target repo (`aws-zabbix-monitoring-solution`) has a `package.json` and `package-lock.json`.
**Warning signs:** Hook errors mentioning "command not found" for eslint or npm.

### Pitfall 2: Confusing pre-commit hook stages
**What goes wrong:** Gitleaks is configured as a pre-commit hook but the reference document says "before push." The default hook type in pre-commit is `pre-commit` (runs on commit), not `pre-push`.
**Why it happens:** The Gitleaks entry in the reference config does not specify `stages: [pre-push]`. By default, it runs on commit.
**How to avoid:** For Phase 1, accept the default behavior (runs on commit). The exact stage configuration for Gitleaks is validated in Phase 5 (SECR-01). Phase 1 just needs the config file committed and hooks triggering.
**Warning signs:** Confusion about when Gitleaks runs.

### Pitfall 3: pre-commit autoupdate changes versions unexpectedly
**What goes wrong:** Running `pre-commit autoupdate` bumps all `rev:` entries, potentially introducing breaking changes or version mismatches with the reference document.
**Why it happens:** Upstream repos release new versions.
**How to avoid:** Recommendation: commit the reference document versions first, then optionally run `pre-commit autoupdate` as a separate commit so the diff is visible and reversible.

### Pitfall 4: hadolint-docker hook requires Docker
**What goes wrong:** The `hadolint-docker` hook ID runs hadolint inside a Docker container. If Docker is not running, this hook fails.
**Why it happens:** The hook definition uses Docker as the execution environment.
**How to avoid:** Ensure Docker Desktop is running, or note this as a known dependency. This is validated in Phase 3, not Phase 1.

### Pitfall 5: security-platform repo is empty
**What goes wrong:** The `security-platform` repo currently has only a `.git` directory -- no files, no README, no `.gitignore`. The first commit needs to initialize the repo properly.
**Why it happens:** The repo was just created/cloned.
**How to avoid:** The first task should initialize the repo with at least `.gitignore` and the config file.

## Code Examples

### The Complete Config File (from Reference Document)
```yaml
# .pre-commit-config.yaml
# Source: docs/development-security-stack-option-1.md lines 1302-1384

# TIER 1: Quality & Linting
repos:

  # --- Terraform: formatting and validation ---
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate

  # --- Python: Ruff (replaces flake8, black, isort) ---
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  # --- Bash / Shell: ShellCheck ---
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0.1
    hooks:
      - id: shellcheck

  # --- Dockerfile: hadolint ---
  - repo: https://github.com/hadolint/hadolint
    rev: v2.12.0
    hooks:
      - id: hadolint-docker

  # --- YAML / Kubernetes manifests: yamllint ---
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        args: [-d, relaxed]

  # --- Markdown: markdownlint ---
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.43.0
    hooks:
      - id: markdownlint

  # --- TypeScript / JavaScript: ESLint (local) ---
  - repo: local
    hooks:
      - id: eslint
        name: eslint
        entry: npx eslint
        language: system
        files: \.(js|jsx|ts|tsx)$
        pass_filenames: true

  # --- npm: lightweight dependency audit ---
  - repo: local
    hooks:
      - id: npm-audit
        name: npm audit
        entry: npm audit --audit-level=high
        language: system
        files: package-lock\.json$
        pass_filenames: false

# TIER 2: Secrets Gate
  # --- Secrets detection: Gitleaks ---
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

### Key Commands
```bash
# Verify installation
pre-commit --version

# Install hooks in a repo (creates .git/hooks/pre-commit)
cd repos/aws-zabbix-monitoring-solution
pre-commit install

# Validate config syntax
pre-commit validate-config .pre-commit-config.yaml

# Run all hooks against all files (for validation -- expect failures in Phase 1)
pre-commit run --all-files

# Run against staged files only (what happens on commit)
pre-commit run

# Update all hook versions to latest
pre-commit autoupdate

# Test that hooks fire: stage a file and commit
git add somefile
git commit -m "test: verify pre-commit hooks trigger"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual .git/hooks scripts | pre-commit framework | ~2019 onward | Standardized, shareable, version-pinned hooks |
| Husky (JS ecosystem only) | pre-commit (language-agnostic) | N/A | pre-commit supports any language; Husky is JS-only |
| pre-commit v3.x | pre-commit v4.x | 2025 | Minor API changes; config format unchanged |

**Deprecated/outdated:**
- pre-commit v3.x line: v4.x is current. Config format is backward-compatible. No migration needed.
- The reference document version pins are from late 2024/early 2025. Running `pre-commit autoupdate` will bring them current.

## Open Questions

1. **Docker availability for hadolint-docker hook**
   - What we know: The hook uses `hadolint-docker` which requires Docker
   - What's unclear: Whether Docker Desktop is running/available on the workstation
   - Recommendation: Note as a dependency; validation happens in Phase 3

2. **npm install state of target repo**
   - What we know: Target repo has `package.json` and `package-lock.json`
   - What's unclear: Whether `node_modules/` is populated (needed for ESLint and npm audit local hooks)
   - Recommendation: Run `npm install` in target repo as a prerequisite step

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual verification (shell commands) |
| Config file | None -- this is infrastructure setup, not code |
| Quick run command | `pre-commit --version && pre-commit validate-config .pre-commit-config.yaml` |
| Full suite command | `pre-commit run --all-files` (expected to have failures in Phase 1) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PCOM-01 | pre-commit is installed and shows version | smoke | `pre-commit --version` | N/A (CLI check) |
| PCOM-02 | .pre-commit-config.yaml exists and is committed | smoke | `git -C repos/aws-zabbix-monitoring-solution show HEAD:.pre-commit-config.yaml > /dev/null` | Wave 0 |
| PCOM-03 | `pre-commit install` activates hooks, git commit triggers them | integration | `cd repos/aws-zabbix-monitoring-solution && ls .git/hooks/pre-commit` | Wave 0 |

### Sampling Rate
- **Per task commit:** `pre-commit --version && pre-commit validate-config .pre-commit-config.yaml`
- **Per wave merge:** Verify hooks trigger on a test commit in target repo
- **Phase gate:** All three PCOM requirements verified before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Target repo needs `npm install` run to support local hooks (ESLint, npm audit)
- [ ] Target repo needs a feature branch created for the pre-commit config commit

*(No test framework files needed -- validation is via CLI commands)*

## Sources

### Primary (HIGH confidence)
- Reference document `docs/development-security-stack-option-1.md` lines 1120-1395 -- complete config, tier rationale, maintenance guidance
- `docs/adr/adr011-precommit-bypass-warning.md` -- bypass model and CI compensating control
- `docs/milestone-plan/milestone-1-workstation.md` -- done criteria for M1-F1/F2
- Local verification: `pre-commit --version` returns 4.5.0, both repos cloned into `repos/`

### Secondary (MEDIUM confidence)
- [pre-commit releases](https://github.com/pre-commit/pre-commit/releases) -- v4.5.1 is latest (installed v4.5.0 is current enough)
- [pre-commit official docs](https://pre-commit.com/) -- API and command reference

### Tertiary (LOW confidence)
- None -- all findings verified locally or from project reference documents

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- pre-commit is already installed, version verified locally
- Architecture: HIGH -- repo structure and config content are fully specified in CONTEXT.md and reference document
- Pitfalls: HIGH -- based on direct inspection of repos and known pre-commit behavior

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (stable tooling, unlikely to change)
