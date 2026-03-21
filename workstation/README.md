# Workstation Security Configuration

Canonical security tooling and configuration for OttawaCloudConsulting developer workstations. This directory contains everything needed to establish the shift-left foundation described in Phase 1 of the security stack blueprint.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full workstation architecture, design decisions, and tool interaction model.

## Quick Start

Run `setup.sh` from inside any git repository:

```bash
# Full setup: install tools + generate configs + activate hooks
bash setup.sh

# Or run individual steps:
bash setup.sh install       # install security CLI tools only
bash setup.sh configure     # generate config files only
bash setup.sh check         # show installed vs expected versions
```

On first run, `setup.sh`:

1. Creates `versions.conf` in the repo root with the **latest** pinned versions (resolved from GitHub)
2. Installs six security CLI tools to `~/.local/bin`
3. Generates all configuration files (`.pre-commit-config.yaml`, linting configs, `.gitleaksignore`)
4. Activates pre-commit and pre-push hooks

Every step is **idempotent** — re-running skips tools already at the pinned version and skips config files that already exist.

## Prerequisites

Before running `setup.sh`, the workstation must have:

| Prerequisite | Required by | Install |
|---|---|---|
| **git** | Everything — hooks, gitleaks, the entire workflow | OS package manager |
| **python3** | pipx bootstrap (which installs pre-commit) | OS package manager or `brew install python` |
| **curl** | `setup.sh` binary downloads and version resolution | OS package manager |
| **Node.js / npm / npx** | ESLint and npm audit pre-commit hooks | `brew install node` or [nodejs.org](https://nodejs.org) |
| **Terraform** | `terraform_fmt` and `terraform_validate` hooks | `brew install terraform` or [terraform.io](https://developer.hashicorp.com/terraform/install) |

## What Gets Installed

### Security CLI Tools (installed to `~/.local/bin`)

| Tool | Purpose | Install Method |
|------|---------|----------------|
| pre-commit | Git hook framework | pipx |
| Trivy | Container/IaC vulnerability scanner | Official install script |
| Syft | SBOM generator | Official install script |
| Grype | Dependency vulnerability scanner | Official install script |
| Gitleaks | Secret detection | Binary download + SHA-256 checksum |
| hadolint | Dockerfile linter | Binary download + SHA-256 checksum |

### Generated Configuration Files (in repo root)

| File | Description |
|------|-------------|
| `versions.conf` | Pinned tool versions and download URLs |
| `.pre-commit-config.yaml` | Pre-commit hook configuration (Tier 1 quality + Tier 2 secrets) |
| `.gitleaksignore` | Gitleaks false-positive suppressions |
| `.markdownlint.jsonc` | Enforced markdownlint rules |
| `.markdownlint-fix.markdownlint.jsonc` | Auto-fixable markdownlint rules |
| `.markdownlint-cli2.yaml` | markdownlint-cli2 configuration |

### Per-Project npm Tooling (JS/TS Repos Only)

For repositories with JavaScript or TypeScript, install ESLint manually:

```bash
cd <target-repo>
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
```

This is required because the ESLint pre-commit hook is configured as a `local` hook that runs `npx eslint`, which expects ESLint in the project's `node_modules`.

## How Pre-commit Manages Linting Tools

A common question is whether tools like ShellCheck, Ruff, yamllint, hadolint, and markdownlint need to be installed system-wide. **For the pre-commit hooks, the answer is no.** Pre-commit manages its own isolated tool environments automatically.

### Remote Hooks — Fully Managed by Pre-commit

The following hooks reference remote repositories in `.pre-commit-config.yaml`. When you run `pre-commit install` and make your first commit, pre-commit clones each repository at the pinned `rev:` version and installs the tool into an isolated environment under `~/.cache/pre-commit/`. **No system-wide installation is needed for these tools to work as hooks:**

| Hook | Repository | What pre-commit does |
|------|-----------|---------------------|
| ShellCheck | `shellcheck-py/shellcheck-py` | Downloads a platform-specific ShellCheck binary via a Python wrapper |
| Ruff | `astral-sh/ruff-pre-commit` | Downloads a platform-specific Ruff binary |
| hadolint | `hadolint/hadolint` | Downloads a platform-specific hadolint binary |
| yamllint | `adrienverge/yamllint` | Installs yamllint into an isolated Python virtualenv |
| markdownlint | `igorshubovych/markdownlint-cli` | Installs markdownlint-cli into an isolated Node.js environment |
| Gitleaks | `gitleaks/gitleaks` | Downloads a platform-specific Gitleaks binary |
| terraform fmt/validate | `antonbabenko/pre-commit-terraform` | Runs terraform commands — **requires Terraform on PATH** (see below) |

Pre-commit pins the exact version via the `rev:` field. Running `pre-commit autoupdate` bumps all `rev:` entries to the latest upstream tags.

### Local Hooks — Require System Dependencies

Two hooks are configured as `local` hooks in `.pre-commit-config.yaml`. These run commands directly on the developer's system rather than in a pre-commit-managed environment:

| Hook | Command | System dependency |
|------|---------|-------------------|
| ESLint | `npx eslint` | Node.js, npm, and ESLint installed in the project's `node_modules` |
| npm audit | `npm audit --audit-level=high` | Node.js and npm |

### Hooks That Delegate to System Binaries

The `pre-commit-terraform` hook is a remote repository, but it delegates to `terraform` on your PATH — it does not bundle Terraform itself. **Terraform must be installed separately** for the `terraform_fmt` and `terraform_validate` hooks to work.

### When You Would Install Tools System-Wide

The pre-commit hooks cover the **git commit workflow**. If you also want to run these tools directly from the command line outside of a commit (e.g., `ruff check .`, `shellcheck script.sh`, `yamllint k8s/`), you would install them system-wide:

```bash
# Optional — only if you want CLI access outside of git hooks
pip install ruff yamllint shellcheck-py --break-system-packages
brew install shellcheck
npm install -g markdownlint-cli
```

This is entirely optional. The pre-commit hooks function without any of these system-wide installations.

## Secrets Detection

Gitleaks runs as a **pre-push hook** — it scans staged changes for credentials and secrets before they reach the remote repository.

**If Gitleaks blocks your push:**

1. Review the finding — is it a real secret or a false positive?
2. Real secret: remove it, rotate the credential, then push again
3. False positive: add the fingerprint to `.gitleaksignore` (see format in that file)

**Bypass:** `git push --no-verify` skips the hook. Use only when you've verified the finding is a false positive and can't immediately update `.gitleaksignore`. CI will re-scan server-side as the compensating control.

## On-Demand Security CLI Tools

The six tools installed by `setup.sh install` are available for direct CLI use beyond what the pre-commit hooks automate:

| Tool | Example usage |
|------|---------------|
| `trivy fs --scanners vuln .` | Scan project dependencies for vulnerabilities |
| `trivy config ./infrastructure/` | Scan Terraform/CloudFormation/K8s for misconfigurations |
| `trivy fs --scanners secret .` | Detect secrets in code |
| `syft dir:. -o cyclonedx-json` | Generate a Software Bill of Materials |
| `grype dir:.` | Scan dependencies for known vulnerabilities |
| `grype sbom:sbom.json` | Scan an existing SBOM for vulnerabilities |
| `gitleaks detect --source .` | Scan current files for secrets |
| `gitleaks detect --source . --log-opts="--all"` | Scan full git history |

Semgrep CE and Checkov are **not** installed by the workstation setup. They run at the Pull Request gate in GitHub Actions (Milestone 2) where full-repository analysis is appropriate. See [ARCHITECTURE.md](ARCHITECTURE.md) for the rationale.

## Version Management

### Tool Versions (`versions.conf`)

`setup.sh` creates `versions.conf` in the repo root on first run, populated with the latest versions from GitHub. To update:

1. Delete `versions.conf` and re-run `bash setup.sh install` to resolve fresh latest versions
2. Or edit `versions.conf` manually to pin a specific version, then `bash setup.sh install`

### Hook Versions (`.pre-commit-config.yaml`)

Hook versions in `.pre-commit-config.yaml` are resolved from GitHub at generation time. To update:

```bash
pre-commit autoupdate
pre-commit run --all-files   # validate nothing broke
```

## Contents

| File | Description |
|------|-------------|
| `setup.sh` | Workstation bootstrap script — installs tools, generates configs, activates hooks |
| `ARCHITECTURE.md` | Architecture, design decisions, tool model, coverage matrix |
| `README.md` | This document |
| `cicd/lint-markdown.sh` | Three-tier markdown linting script (auto-fix + enforce) |
| `cicd/pre-commit.sh` | Pre-commit hook for staged markdown files |
