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

## Routing a Repository Through Nexus (`nexus-setup.sh`)

`nexus-setup.sh` points **one repository's** npm, pip and Helm clients at a Nexus instance (see `kubernetes/nexus/`). It is a separate entry point from `setup.sh` and shares nothing with it but the house style.

Run it from inside the repository you want to route. It is deliberately **not executable** and is invoked with an explicit interpreter — that is the project's Script Safety rule, not an oversight. (`setup.sh` and the `cicd/` scripts beside it are mode `755`; they predate the rule.)

```bash
# Configure this repository, then prove it routes
bash workstation/nexus-setup.sh --url http://nexus.example.com:8081 --verify

# Source the env file — pip and Helm do nothing until you do
source .nexus-env
```

### Flags

| Flag | Effect |
|---|---|
| `--url <URL>` | **Required.** Base URL of the Nexus instance: `http://` or `https://`, host with optional `:port` and optional path. A single trailing slash is accepted and stripped. |
| `--force` | Overwrite generated files that already exist. Without it, an existing `pip.conf` or `.nexus-env` is left alone and reported as skipped. `.npmrc` is never overwritten either way — npm merges it. |
| `--verify` | After configuring, prove it: ask each client what it resolves, then pull a real component through it. See below. |
| `--docker-daemon` | Also write the **machine-global** Docker daemon configuration. Off by default. See below. |
| `--commit-config` | Do **not** add the generated files to `.gitignore`. See below. |
| `-v`, `--verbose` | Detailed progress output. |
| `-h`, `--help` | Usage and exit. |

Three environment variables override which sample artefacts `--verify` fetches: `NEXUS_VERIFY_NPM_NAME`, `NEXUS_VERIFY_NPM_VERSION` and `NEXUS_VERIFY_PIP_PACKAGE`.

Re-running is safe. `helm repo add` is invoked with `--force-update`, so a re-run with a different `--url` replaces the `nexus` entry rather than erroring, and `.gitignore` entries are added only when absent.

### Files written, all inside the target repository

| File | Written by |
|---|---|
| `.npmrc` | `npm config set registry=… --location=project` |
| `pip.conf` | the script — `index-url`, plus a TLS-bypass line only when one is genuinely required |
| `.helm/repositories.yaml` | `helm repo add` itself, never by hand |
| `.helm/cache/` | Helm's repository cache for this repository |
| `.nexus-env` | the script — four exports: `PIP_CONFIG_FILE`, `HELM_REPOSITORY_CONFIG`, `HELM_REPOSITORY_CACHE`, `NEXUS_DOCKER_REGISTRY` |
| `.gitignore` | append-only entries for the above, unless `--commit-config` is passed |

### Which ecosystems actually route — the table to read first

**Three of the four do not route until you source a file, and one of them never routes on its own at all.** This is the honest shape of the mechanism, not a limitation of the script:

| Ecosystem | Mechanism | Needs `source .nexus-env`? |
|---|---|---|
| npm | `.npmrc`, npm's native **project scope** | **No.** npm reads it natively. |
| pip | `pip.conf` reached through `PIP_CONFIG_FILE` | **Yes.** pip has no project scope; `pip.conf` in the repository is inert until the variable points at it. |
| Helm | `.helm/repositories.yaml` reached through `HELM_REPOSITORY_CONFIG` | **Yes.** Helm has no project scope either; the repository entry is invisible to `helm` until the variable points at it. |
| Docker | none — **no per-repository configuration of any kind exists** | No, and sourcing does not route it either. `.nexus-env` exports `NEXUS_DOCKER_REGISTRY` as a prefix **string**; routing an image is a manual edit of an image reference. |

The Docker prefix carries **no `/repository/` segment**, unlike the npm, pip and Helm URLs. A Docker client inserts `/v2/` immediately after the host, so the repository name has to be the first path segment; the analogous prefixed reference returns HTTP 404. Measured. Use it like this:

```bash
source .nexus-env
docker pull "${NEXUS_DOCKER_REGISTRY}"/library/alpine:3.21
# e.g. docker pull nexus.example.com:8081/docker-proxy/library/alpine:3.21
```

An npm subtlety worth knowing before reporting a bug: npm reads `.npmrc` from its **local prefix** — the nearest ancestor containing `package.json` or `node_modules` — not from the current directory. In a repository with no `package.json` anywhere up the tree, npm falls back to the public registry and the script looks as though it did nothing. It warns when that applies.

### `PIP_CONFIG_FILE` replaces your pip configuration; it does not add to it

Measured: with `PIP_CONFIG_FILE` set, `pip config list -v` no longer lists **either** user-scope variant. A corporate CA bundle, an `extra-index-url`, anything in your own user-level `pip.conf` — all of it silently stops applying in that shell.

**Source `.nexus-env` per shell session. Never add it to a shell rc file** (`.bashrc`, `.zshrc` and friends). Doing so would make one repository's Nexus the default for every project on the machine — the global workstation default this script is deliberately scoped to avoid — and would take your own pip settings down with it everywhere.

### `trusted-host` in the generated `pip.conf`

The script emits a `trusted-host` line **only** when it is genuinely required: a plain-HTTP `--url` pointing at a non-loopback host. For `https://`, and for loopback, it is absent.

**Security warning (ADR-009).** `trusted-host` does not merely permit plain HTTP — it disables TLS certificate verification for that host entirely, so anything positioned between this machine and Nexus can substitute packages without raising a certificate error. **It must be removed once TLS is configured on that Nexus instance.**

### `--docker-daemon`: the one machine-global change

Off by default, and the only thing this script writes **outside** the target repository. Unlike the npm, pip and Helm configuration — which is scoped to one repository — **this change is machine-global and affects every repository and every project on this workstation.**

It writes to `~/.docker/daemon.json`:

| Key | When | What it does |
|---|---|---|
| `registry-mirrors` | always | Tells the Docker engine to try Nexus before Docker Hub. **Only `docker.io` references are ever mirrored** — `ghcr.io`, `quay.io`, `public.ecr.aws` and every other registry continue to be pulled directly, so this routes *part* of a typical project's images and never all of them. |
| `insecure-registries` | only for a plain-HTTP `--url` | Disables TLS verification for that host entirely; must be removed once TLS is configured on that Nexus instance (ADR-009) — see the full warning below. |

The mirror URL is the one asymmetry to be careful with: as a daemon mirror target the Nexus Docker proxy is addressed **with** a `/repository/` segment — `<NEXUS_URL>/repository/<docker-repo>` — while the `NEXUS_DOCKER_REGISTRY` pull prefix above carries **none**. Both shapes were measured; the alternative candidate for the mirror produced a `docker pull` that exited 0 with real layer traffic and stored **zero** components in Nexus. Unifying the two shapes would break one of them.

**Security warning (ADR-009).** `insecure-registries` does not merely permit plain HTTP — it disables TLS verification for that host entirely, so anything positioned between this machine and Nexus can substitute images and the engine will raise no certificate error. **It must be removed once TLS is configured on that Nexus instance.** For an `https://` URL the script does not write the key at all and says so.

Before any write the existing file is copied to `~/.docker/daemon.json.nexus-setup-backup-<UTC timestamp>`, and the path is printed. Restore is a copy back:

```bash
cp ~/.docker/daemon.json.nexus-setup-backup-20260920T192802Z ~/.docker/daemon.json
```

Every pre-existing key survives, your own mirrors stay ahead of the appended one (`registry-mirrors` is a priority list), each entry is added at most once, a re-run writes nothing, and a `daemon.json` that is not valid JSON is never overwritten — the run fails instead.

**A Docker engine restart is required before any of it takes effect, and this script never performs one.** Restarting your engine is yours to do.

### `--verify` — the only thing that proves anything routes

Writing a config file is not the same as a client reading it. `--verify` asks each client what it resolves **and then pulls a real component through it** with the client's cache disabled, and prints one row per ecosystem:

| Status | Meaning |
|---|---|
| `ok` | readback correct **and** a real component came through. |
| `FAILED` | the fetch did not succeed. The message names the cause: HTTP 401 → the server's `anonymous.enabled`; HTTP 403 with a body under ~1,000 bytes → the server's `eula.accepted` (the licence refusal is a well-formed 192-byte response); a curl transport error → the endpoint is unreachable. |
| `UNVERIFIABLE` | the client could not be made to answer the question. **Not a pass.** |
| `SKIPPED` | the client is not installed. **Not a pass.** |
| `MANUAL` | docker, always, under every condition — including runs where `--docker-daemon` wrote a mirror. |

Anything that is not `ok` or `MANUAL` makes the run exit non-zero, `SKIPPED` and `UNVERIFIABLE` included. **A `MANUAL` docker row is the expected result, not a failure** — it reflects that no per-repository Docker mechanism exists.

One consequence worth knowing: because `UNVERIFIABLE` counts as a failure, `--verify` in a repository with no `package.json` anywhere up the tree exits 1 on the npm row, since npm's local prefix does not resolve there and any registry it reports came from somewhere else up the tree. Run `npm init -y` (or add a `package.json`) and re-run.

Run it on an already-configured repository too: without `--force` nothing is rewritten, so the run verifies rather than reconfigures.

### The generated files are gitignored by default

`.npmrc`, `pip.conf`, `.helm/` and `.nexus-env` are appended to the target repository's `.gitignore` unless you pass `--commit-config`. A committed `.npmrc` pointing at one operator's Nexus breaks dependency resolution for every contributor who cannot reach that host, and discloses an internal hostname if the repository is public. Pass `--commit-config` when the whole team shares the same Nexus and you want the routing committed on purpose.

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
| `nexus-setup.sh` | Points one repository's npm, pip and Helm clients at a Nexus instance, and proves it with `--verify` |
| `ARCHITECTURE.md` | Architecture, design decisions, tool model, coverage matrix |
| `README.md` | This document |
| `cicd/lint-markdown.sh` | Three-tier markdown linting script (auto-fix + enforce) |
| `cicd/pre-commit.sh` | Pre-commit hook for staged markdown files |
