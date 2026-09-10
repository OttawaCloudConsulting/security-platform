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
bash setup.sh update        # update outdated tools to the pinned versions
bash setup.sh update trivy  # update a single named tool
bash setup.sh doctor        # verify every tool is on PATH and can run its version command
```

The tool name in `update <tool>` must come *after* the `update` keyword — argument
parsing is order-sensitive, so `bash setup.sh trivy update` is rejected.

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
| `.markdownlintignore` | Directories excluded from markdownlint |

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
3. Or run `bash setup.sh update` (preferred) — updates only the tools that are outdated,
   without touching `versions.conf`. See [Maintenance](#maintenance) below.

### Hook Versions (`.pre-commit-config.yaml`)

Hook versions in `.pre-commit-config.yaml` are resolved from GitHub at generation time. To update:

```bash
pre-commit autoupdate
pre-commit run --all-files   # validate nothing broke
```

## Maintenance

`check`, `update`, and `doctor` answer three different questions: is my version current, can
I get to the current version, and does my environment actually work.

### `check` — am I on the right version?

```bash
bash setup.sh check
```

Prints installed vs. expected versions for all six tools, plus a prerequisites table
(git, curl, python3, node, npm, terraform). Searches `~/.local/bin` in addition to the
rest of `PATH`, because `check` answers "am I on the pinned version", not "is my shell
configured". **Exits 0** when every tool matches its pin, **exits 1** when any tool is
missing or mismatched.

### `update` — get current

```bash
bash setup.sh update         # update every outdated tool
bash setup.sh update trivy   # update only trivy
```

Updates every tool whose installed version differs from its pin, or just the named tool.
Tools already at their pin are skipped — a fully current machine makes no installer calls.
A tool that fails to update does not stop the others from being attempted.

For each outdated tool, `update` tries the exact pinned version first. If that install
fails, it resolves the latest release within the *same major version* from GitHub and
tries that instead — and it refuses a fallback that would move the tool backwards (a
resolved fallback below the pin is treated as a failure, not silently accepted). It never
rewrites `versions.conf`. After the run it automatically re-prints the `check` table so
you can see the result.

**Result statuses** shown in the update summary table:

| Status | Meaning |
|--------|---------|
| `ok` | Already at the pinned version — nothing done |
| `installed` | Updated to the pinned version |
| `fallback` | Installed at a same-major version because the pin was unavailable — the follow-up `check` table will show `MISMATCH` for this tool, and a `NOTE:` line explains why |
| `FAILED` | Both attempts failed |

**What to do about a `fallback`:** edit `versions.conf` to adopt the version that
actually installed, then re-run `bash setup.sh check` to confirm it's clean. This is
deliberately a manual step — the pinned manifest stays a user-owned, intentional artifact
that `update` never rewrites on your behalf.

**`update-failures.log`:** written to the root of whatever repo you ran `update` in
(plain text, one line per tool that failed both attempts, each line containing a UTC
timestamp, the tool name, the pinned version, the fallback version tried, and the
version actually installed — never a token, credential, or environment dump). Add it to
that repo's `.gitignore`:

```gitignore
update-failures.log
```

(`repos/security-platform`'s own `.gitignore` already ignores it — see below.)

### `doctor` — does my environment actually work?

```bash
bash setup.sh doctor
```

Fully offline — makes zero network calls. Reports, per tool, one of:

| Status | Meaning |
|--------|---------|
| `OK` | On PATH, version command ran, output was parseable |
| `NOT_ON_PATH` | Tool not found via `command -v` |
| `BROKEN` | Found on PATH, but its version command exited non-zero |
| `UNPARSEABLE` | Version command exited 0, but produced no recognisable version string |

It also reports whether `~/.local/bin` exists and is on `PATH`, and whether `git`,
`curl`, and `python3` are present. `doctor` uses your **real** `PATH`, untouched — unlike
`check`, it does not export `~/.local/bin` onto `PATH` before probing, because doing so
would mask the exact failure `doctor` exists to detect.

### Exit codes

| Command | Exit 0 | Exit 1 |
|---------|--------|--------|
| `check` | every tool matches its pin | any tool `MISSING` or `MISMATCH` |
| `update` | no tool failed both attempts (a `fallback` is not a failure, and the automatic post-update `check` recheck does not affect this exit status) | one or more tools `FAILED` both attempts |
| `doctor` | every tool `OK` and all prerequisites present | any non-`OK` finding |

### `GITHUB_TOKEN` — avoiding GitHub rate limits

Set `GITHUB_TOKEN` or `GH_TOKEN` in your environment, or be logged in via `gh auth login`,
to raise the GitHub API limit from 60 requests/hour (unauthenticated) to **5000**
requests/hour. The script calls the GitHub API in exactly three places: generating
`versions.conf` on first run, resolving hook versions for `.pre-commit-config.yaml`, and
`update`'s same-major fallback resolution. The token is sent only as an `Authorization:
Bearer` request header — never as a command-line argument, never written to
`update-failures.log`, and never logged.

## Contents

| File | Description |
|------|-------------|
| `setup.sh` | Workstation bootstrap script — installs tools, generates configs, activates hooks |
| `ARCHITECTURE.md` | Architecture, design decisions, tool model, coverage matrix |
| `README.md` | This document |
| `cicd/lint-markdown.sh` | Three-tier markdown linting script (auto-fix + enforce) |
| `cicd/pre-commit.sh` | Pre-commit hook for staged markdown files |
| `tests/` | Plain-bash test suite for `setup.sh` — run with `bash tests/run-tests.sh` |
