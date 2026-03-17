# Milestone 1: Developer Guide

Architecture, design decisions, and extension patterns for the developer workstation security stack. Read this if you need to modify the hook configuration, add new hooks, roll out to additional repositories, or understand why things are structured the way they are.

---

## Architecture

### Layered Security Model

The workstation layer is the first of four security boundaries. Each layer catches what the previous one missed or what was intentionally deferred.

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         Developer Workstation                              │
│  IDE (VS Code) + Pre-commit Hooks (Tier 1 & 2) + CLI Tools                │
│                                                                            │
│  Pre-commit Tier 1 — Quality & Linting (fast, every commit)                │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │  ShellCheck  │ │     Ruff     │ │   ESLint     │ │  hadolint    │       │
│  │  (sh/bash)   │ │   (Python)   │ │   (TS/JS)    │ │ (Dockerfile) │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │   yamllint   │ │ markdownlint │ │  npm audit   │ │  tf fmt/val  │       │
│  │  (K8s/YAML)  │ │    (.md)     │ │  (fast dep)  │ │  (Terraform) │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│                                                                            │
│  Pre-Push Tier 2 — Secrets Gate (before push)                              │
│  ┌──────────────┐                                                          │
│  │  Gitleaks    │  ← only secrets; SAST/IaC scanning moves to PR gate      │
│  │  (Secrets)   │                                                          │
│  └──────────────┘                                                          │
│                                                                            │
│  Manual / CLI (run on demand)                                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                        │
│  │    Trivy     │ │    Syft      │ │    Grype     │                        │
│  │ (Multi-scan) │ │   (SBOM)     │ │    (SCA)     │                        │
│  └──────────────┘ └──────────────┘ └──────────────┘                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                        │
│  │  Semgrep CE  │ │   Checkov    │ │  Gitleaks    │                        │
│  │   (SAST)     │ │  (IaC Scan)  │ │ (full hist.) │                        │
│  └──────────────┘ └──────────────┘ └──────────────┘                        │
└────────────────────────────────────────────────────────────────────────────┘
```

### Tier 1 vs Tier 2 Split

Hooks are split by execution trigger:

| Tier | Trigger | Scope | Rationale |
|------|---------|-------|-----------|
| Tier 1 | `pre-commit` (every commit) | Quality and linting (9 hooks) | Fast feedback, sub-5-second total. Catches formatting and syntax issues before they accumulate. |
| Tier 2 | `pre-push` (every push) | Secrets only (Gitleaks) | Secrets are the only finding type where local detection is critical — a pushed credential is an immediate exposure. SAST and IaC scanning are deferred to CI because they are slower and benefit from full-repo context. |

SAST (Semgrep) and IaC scanning (Checkov) are intentionally **not** pre-commit hooks. They run in GitHub Actions (M2) where they have access to the full repo, consistent environments, and can block merges via branch protection. Running them locally as CLI tools is optional.

See [ADR-011](../adr/adr011-precommit-bypass-warning.md) for the bypass and compensating controls rationale.

### Canonical Config Pattern

The `.pre-commit-config.yaml` lives in `repos/security-platform/` as the single source of truth. Target repositories receive identical copies. This pattern means:

- Updates happen in one place, then deploy to all repos
- All repos share the same hook versions and configuration
- Drift is visible via diff between canonical and deployed copies

### Hook Type Reference

| Type | How It Works | Examples |
|------|-------------|----------|
| **Remote repo hook** | pre-commit downloads and caches the tool at the pinned `rev:` | shellcheck, hadolint, yamllint, markdownlint, ruff, gitleaks |
| **Local hook** | Runs a command already on PATH or in `node_modules` | eslint (`npx eslint`), npm-audit (`npm audit`) |
| **Native binary hook** | Remote repo hook that delegates to a native binary | hadolint (requires `brew install hadolint`) |

Remote hooks auto-install their environments on first run. Local hooks require the tool to be pre-installed in the project.

---

## Design Decisions

### Why Ruff Instead of flake8 + black + isort

Ruff replaces three Python tools (flake8, black, isort) with a single Rust-based tool that is 10-100x faster. The `--fix` flag auto-corrects most violations, reducing commit friction.

### Why ESLint as a Local Hook

ESLint requires project-specific configuration (`eslint.config.mjs`) and access to `node_modules`. A remote hook would install its own ESLint version, potentially conflicting with the project's config. The `local` hook type runs `npx eslint`, which uses the project's installed version.

### Why hadolint Native Instead of Docker

The `hadolint-docker` hook variant requires Docker running on every commit. The native binary (`brew install hadolint`) has no runtime dependency and is faster. The hook ID is `hadolint` (not `hadolint-docker`).

### Why yamllint Uses `-d relaxed`

The `relaxed` preset disables rules that conflict with Kubernetes manifests (line length, truthy values). Kubernetes YAML follows different conventions than general YAML style guides.

### Why npm-audit Only Triggers on package-lock.json

Running `npm audit` on every commit regardless of changes adds 2-3 seconds for zero value. The `files: package-lock\.json$` filter ensures it runs only when dependencies actually change.

### Why Gitleaks Is Pre-Push, Not Pre-Commit

Secrets detection needs to scan the full diff being pushed, not individual file snapshots. The `protect --staged` mode checks staged changes against the full commit history. Running at pre-push gives it the right context window.

---

## Configuration Files Reference

### Per-Repository Files

| File | Required? | Purpose |
|------|-----------|---------|
| `.pre-commit-config.yaml` | Yes | Hook definitions and versions |
| `.markdownlint.json` | If repo has `.md` files | Suppress false positive rules |
| `.markdownlintignore` | If repo has generated `.md` | Exclude directories from scanning |
| `eslint.config.mjs` | If repo has JS/TS | ESLint flat config |
| `.gitleaksignore` | If false positives exist | Fingerprints of known false positives |

### Markdownlint Rule Suppressions

Rules currently disabled across repos and why:

| Rule | Name | Why Disabled |
|------|------|-------------|
| MD013 | Line length | Code examples and tables frequently exceed 80 chars |
| MD024 | Multiple same-level headings | Valid in structured docs (e.g., repeated "Parameters" sections) |
| MD033 | Inline HTML | Used for details/summary tags, badges, etc. |
| MD036 | Emphasis used instead of heading | Stylistic preference in some doc formats |
| MD040 | Fenced code block without language | Legacy code blocks, not worth retroactive tagging |
| MD041 | First line should be top-level heading | Not always appropriate (frontmatter, etc.) |
| MD049 | Emphasis style | Inconsistent across docs, not worth enforcing |
| MD060 | Table column count | False positives on complex tables |

Additional per-repo rules:

| Rule | Repo | Why |
|------|------|-----|
| MD032 | terraform-pipelines | Blanks around lists — false positives in generated docs |

---

## Rolling Out to New Repositories

### Step-by-Step

1. **Copy the canonical config:**

   ```bash
   cp repos/security-platform/.pre-commit-config.yaml /path/to/new-repo/
   ```

2. **Create linter configs** (`.markdownlint.json`, `.markdownlintignore`) based on the repo's file types. Start with the template from the Installation Guide and adjust as needed.

3. **Install ESLint** (JS/TS repos only):

   ```bash
   cd /path/to/new-repo
   npm install --save-dev @eslint/js typescript-eslint
   # Create eslint.config.mjs (see Installation Guide)
   ```

4. **Activate hooks:**

   ```bash
   cd /path/to/new-repo
   pre-commit install
   pre-commit install --hook-type pre-push
   ```

5. **Run full validation:**

   ```bash
   pre-commit run --all-files
   ```

6. **Fix or suppress violations** — fix genuine issues in source, suppress false positives with inline annotations or config files.

7. **Commit** the config files and any fixes.

### What to Expect

Depending on the repo's codebase, you may see violations on first run. Common patterns:

- **ShellCheck:** Unquoted variables, missing double brackets — these are genuine improvements
- **hadolint:** `DL3008` (apt-get without version pinning) — suppress if version pinning is impractical
- **markdownlint:** Style issues in existing docs — suppress rules that produce too many false positives
- **ESLint:** Type errors, unused variables — fix or disable per-line as appropriate

---

## Adding a New Hook

### Remote Hook (Most Common)

Find the pre-commit hook repository (most tools publish one). Add to `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/org/tool-pre-commit
    rev: v1.2.3   # pin to a specific tag
    hooks:
      - id: tool-name
        args: [--flag, value]  # optional
```

### Local Hook

For tools that need project context or are already installed:

```yaml
  - repo: local
    hooks:
      - id: my-tool
        name: my tool
        entry: my-tool --check
        language: system
        files: \.ext$
        pass_filenames: true   # or false if tool doesn't accept filenames
```

### Placement Rules

- **Tier 1 hooks** go in the main `repos:` block (run on every commit)
- **Tier 2 hooks** use `stages: [pre-push]` to run only on push
- Order within the config file doesn't affect execution order — pre-commit runs hooks in parallel where possible

### After Adding

1. Update the canonical config in `repos/security-platform/`
2. Deploy to all target repos
3. Run `pre-commit run --all-files` in each repo to validate
4. Update this documentation

---

## Maintaining Hook Versions

### Monthly Update Cadence

```bash
cd /path/to/repo
pre-commit autoupdate
pre-commit run --all-files
```

`pre-commit autoupdate` bumps each `rev:` to the latest tag from the hook's repository.

### Version Pinning Strategy

All hooks use pinned versions (`rev: v1.105.0`, not `rev: main`). This ensures:

- Reproducible behavior across machines and time
- No surprise breakage from upstream changes
- Explicit upgrade decisions

The trade-off is that pinned versions accumulate unpatched bugs and missing detection rules. The monthly update cadence mitigates this.

### Breaking Changes

When `pre-commit autoupdate` bumps a version and `--all-files` starts failing:

1. Check the tool's changelog for breaking changes
2. If new rules are catching genuine issues — fix them
3. If new rules are false positives — suppress via config (e.g., `.markdownlint.json`)
4. If the new version is broken — pin to the previous version temporarily and file an issue upstream

---

## JSON Output and Downstream Integration

All six CLI tools produce JSON output compatible with downstream systems:

| Tool | JSON Flag | Downstream Consumer |
|------|-----------|-------------------|
| Trivy | `--format json` | DefectDojo ("Trivy Scan"), GitHub SARIF |
| Syft | `-o cyclonedx-json` | Grype input, SBOM registries |
| Grype | `-o json` | DefectDojo ("Anchore Grype") |
| Semgrep | `--json` | DefectDojo ("Semgrep JSON Report"), GitHub SARIF |
| Checkov | `-o json` | DefectDojo ("Checkov Scan"), GitHub SARIF |
| Gitleaks | `--report-format json` | DefectDojo ("Gitleaks Scan") |

These same tools run in the CI pipeline (M2) and their JSON output is automatically imported into DefectDojo (M4) for centralized vulnerability tracking.

### Expected Report Sizes

From Phase 8 validation against the aws-zabbix-monitoring-solution repo:

| Tool | Report Size | Notes |
|------|-------------|-------|
| Trivy | ~53 KB | Dependency vulnerability scan |
| Syft | ~100 KB | Full CycloneDX SBOM |
| Grype | ~15 KB | Vulnerability matches |
| Semgrep | ~9 KB | 3 findings (community rules) |
| Checkov | ~5.9 MB | Largest report (comprehensive IaC audit) |
| Gitleaks | ~147 KB | 44 findings (CDK asset hash false positives) |

---

## Bypass and Compensating Controls

### Client-Side Bypass

Pre-commit hooks are client-side enforcement and can be bypassed:

```bash
git commit --no-verify   # skips Tier 1 hooks
git push --no-verify     # skips Tier 2 Gitleaks hook
```

This is by design — Git does not support mandatory client-side hooks. The enforcement chain:

1. **Pre-commit/pre-push hooks** (client-side, bypassable) — fast feedback loop
2. **CI/CD scan jobs** (server-side, non-bypassable) — same tools run in GitHub Actions
3. **Branch protection + required status checks** — prevents merge without passing CI

Without branch protection (M2), the CI gate is advisory. The workstation hooks are defense-in-depth, not the sole control.

### When Bypass Is Acceptable

- Committing generated files that legitimately fail linting (e.g., CDK output)
- Emergency hotfix where the hook environment is broken
- False positive that cannot be suppressed inline and you need to push before updating `.gitleaksignore`

In all cases, CI runs the same checks server-side and will catch anything missed locally.

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Installation Guide](INSTALLATION_GUIDE.md) | Step-by-step installation of all tools |
| [User Guide](USER_GUIDE.md) | Day-to-day usage and CLI tool commands |
| [Main Reference](../development-security-stack-option-1.md) | Complete stack blueprint (~2,300 lines) |
| [Architecture & Design](../ARCHITECTURE_AND_DESIGN.md) | Full architecture reference |
| [ADR Index](../adr/README.md) | Architectural decision records (ADR-001 through ADR-014) |
| [Milestone Plans](../milestone-plan/) | Detailed milestone documents with verification checks |
