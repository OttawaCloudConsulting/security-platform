# Stack Research: Cross-Platform Installation & Distribution Packaging

**Domain:** Cross-platform tool distribution for developer security scanning stack
**Researched:** 2026-03-16
**Confidence:** HIGH

## Scope

This research covers ONLY what's needed for v1.1 Distribution Packaging milestone:
1. Replacing Homebrew-only tool installation with cross-platform methods (macOS + Linux)
2. Distribution mechanism for onboarding fresh git repos with a single command
3. Project-scoped vs system-wide installation decisions per tool

Tools themselves are already validated (M1 complete). This is about HOW to install and distribute them.

---

## Tool Installation Methods (Replacing Homebrew)

### Per-Tool Install Method Matrix

| Tool | Current (M1) | Recommended (v1.1) | Scoping | Rationale |
|------|--------------|---------------------|---------|-----------|
| **pre-commit** | `pip install` | `pipx install pre-commit` | System-wide | CLI tool, not a library. pipx isolates deps. Already works cross-platform. |
| **Semgrep CE** | `pip install` | `pipx install semgrep` | System-wide | Large dep tree, isolating via pipx prevents conflicts. Already works cross-platform via PyPI. |
| **Checkov** | `pip install` | `pipx install checkov` | System-wide | Same rationale as Semgrep. Large dep tree, benefits from pipx isolation. |
| **Trivy** | `brew install` | Curl install script | System-wide | Go binary, no deps. Official: `curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \| sh -s -- -b /usr/local/bin` |
| **Syft** | `brew install` | Curl install script | System-wide | Go binary. Official: `curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \| sh -s -- -b /usr/local/bin` |
| **Grype** | `brew install` | Curl install script | System-wide | Go binary. Official: `curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \| sh -s -- -b /usr/local/bin` |
| **Gitleaks** | `brew install` | Curl install script | System-wide | Go binary. Official: `curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh \| sh -s -- -b /usr/local/bin` |
| **hadolint** | `brew install` | Direct binary download from GitHub Releases | System-wide | Haskell binary, no install script. Download platform-specific binary, place in PATH. |
| **Ruff** | pre-commit (auto) | pre-commit (auto) | Project-scoped (via pre-commit cache) | No change needed. pre-commit manages Ruff's environment per-hook. |
| **ShellCheck** | pre-commit (auto) | pre-commit (auto) | Project-scoped (via pre-commit cache) | No change needed. pre-commit downloads and caches the binary. |
| **yamllint** | pre-commit (auto) | pre-commit (auto) | Project-scoped (via pre-commit cache) | No change needed. |
| **markdownlint** | pre-commit (auto) | pre-commit (auto) | Project-scoped (via pre-commit cache) | No change needed. |
| **ESLint** | `npm install --save-dev` | `npm install --save-dev` | Project-scoped (node_modules) | No change needed. Remains per-project via package.json. |

### Category Summary

**Go binaries (Trivy, Syft, Grype, Gitleaks):** All four provide official curl-pipe-sh install scripts that detect OS and architecture automatically. These are the canonical cross-platform install method. Each script downloads a platform-specific binary and verifies checksums. System-wide installation to `/usr/local/bin` (or a user-chosen bin directory).

**Python CLIs (pre-commit, Semgrep, Checkov):** Use `pipx install` instead of bare `pip install`. pipx creates isolated virtual environments per tool, preventing dependency conflicts between tools (Semgrep and Checkov have large, overlapping dep trees). pipx itself installs via `pip install --user pipx` or `brew install pipx` or `apt install pipx`.

**Haskell binary (hadolint):** No install script available. Must download the correct platform binary from GitHub Releases manually. The install script should handle this: detect OS+arch, construct download URL, fetch, verify, place in PATH.

**Pre-commit managed (Ruff, ShellCheck, yamllint, markdownlint):** No action needed. pre-commit clones repos and creates isolated environments in `~/.cache/pre-commit/`. These are already cross-platform and project-scoped by design.

**npm project-local (ESLint):** No change needed. Stays as `npm install --save-dev` per-project. The pre-commit hook uses `npx eslint` which resolves to the project's version.

---

## Project-Scoped vs System-Wide Decision

**Decision: System-wide for CLI tools, project-scoped for linters.**

| Scope | Tools | Why |
|-------|-------|-----|
| System-wide | Trivy, Syft, Grype, Gitleaks, hadolint, Semgrep, Checkov, pre-commit | These are standalone CLI tools invoked from the command line or CI. They don't have project-specific versions. A single developer wants one version on the machine. |
| Project-scoped (pre-commit cache) | Ruff, ShellCheck, yamllint, markdownlint | Pre-commit manages their environments. Version pinned in `.pre-commit-config.yaml` per repo. |
| Project-scoped (node_modules) | ESLint, typescript-eslint | JS/TS tools belong in the project's devDependencies. |

**Why NOT project-scoped for CLI tools:** Trivy, Grype, etc. are Go binaries with no dependency isolation mechanism (no virtualenv, no node_modules). Project-scoping would mean downloading ~50MB+ of binaries per repo. For a single developer with 6+ repos, this wastes disk and adds complexity for zero benefit. A single system-wide install is the correct pattern.

---

## Distribution Mechanism

### Recommendation: Standalone Bash Install Script

**Use a single `install.sh` bash script. Not npx. Not pip package. Not Makefile.**

| Mechanism | Verdict | Why |
|-----------|---------|-----|
| **Standalone bash script** | **USE THIS** | Zero dependencies beyond bash + curl (present on all macOS/Linux). No npm/pip/node required to bootstrap. Can install pipx, then Python tools, then Go binaries. Self-contained. |
| npx create-* package | Reject | Requires Node.js pre-installed. Adds npm registry dependency. Over-engineered for config file distribution. |
| pip package | Reject | Requires Python pre-installed. Packaging a bash installer as a Python package is awkward. pip is for libraries. |
| Makefile | Reject | Make is available everywhere but Makefiles have poor error handling, no OS detection, no progress reporting. Bash is more expressive for installer logic. |
| Docker container | Reject | Running security tools inside Docker isolates them from the repo they need to scan. Adds Docker dependency. Wrong abstraction. |
| Ansible/Terraform | Reject | Configuration management tools are overkill for "install 10 tools and drop 5 config files." |

### Distribution Script Architecture

The install script should have two modes:

**1. `install.sh tools` -- Install all security CLI tools (run once per machine)**

```
Detect OS (Darwin/Linux) and architecture (amd64/arm64)
Check prerequisites: bash, curl, python3, pip, git
Install pipx if not present
pipx install pre-commit semgrep checkov
curl-install Trivy, Syft, Grype, Gitleaks (official scripts)
Download hadolint binary for platform
Verify all tools accessible: tool --version for each
```

**2. `install.sh repo` -- Set up a git repo with security tooling (run once per repo)**

```
Verify in a git repo root
Drop config files: .pre-commit-config.yaml, .markdownlint.json, .markdownlintignore, .gitleaksignore
If package.json exists and has TS/JS: suggest ESLint setup
pre-commit install (commit hooks)
pre-commit install --hook-type pre-push (push hooks)
pre-commit run --all-files (validate)
```

### Version Checking

The script should support `install.sh check` to verify installed tool versions against expected minimums and report which need updating. This replaces ad-hoc `tool --version` checks.

---

## Core Technologies for the Install Script

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Bash** | 3.2+ (macOS default) | Install script language | Universal on macOS and Linux. macOS ships bash 3.2 (GPLv2); Linux ships 5.x. Script MUST be compatible with bash 3.2 (no associative arrays, no `readarray`, no `${var,,}` lowercase). |
| **curl** | any | HTTP downloads | Present on all macOS/Linux systems. Preferred over wget (macOS has curl but not wget by default). |
| **pipx** | 1.7+ | Python CLI tool isolation | Installed as prerequisite. Provides `pipx install` for Semgrep, Checkov, pre-commit. |
| **sha256sum / shasum** | system | Checksum verification | macOS uses `shasum -a 256`, Linux uses `sha256sum`. Script must handle both. |

## Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **jq** | 1.7+ | JSON parsing in shell | Optional. For parsing GitHub API responses to find latest release URLs. Can be avoided by hardcoding version numbers. |

---

## Installation Commands (Cross-Platform)

```bash
# === Prerequisites ===
# Python 3.10+ and pip must be pre-installed
# Node.js 18+ and npm 9+ must be pre-installed (for ESLint in TS/JS repos)
# Git 2.30+ must be pre-installed

# === Step 1: Install pipx ===
python3 -m pip install --user pipx
python3 -m pipx ensurepath

# === Step 2: Python CLI tools via pipx ===
pipx install pre-commit
pipx install semgrep
pipx install checkov

# === Step 3: Go binaries via official install scripts ===
# Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.69.3

# Syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Grype
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Gitleaks
curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh | sh -s -- -b /usr/local/bin

# === Step 4: hadolint (platform-specific binary) ===
# macOS (Apple Silicon)
curl -sL https://github.com/hadolint/hadolint/releases/download/v2.14.0/hadolint-Darwin-arm64 -o /usr/local/bin/hadolint
# macOS (Intel)
# curl -sL https://github.com/hadolint/hadolint/releases/download/v2.14.0/hadolint-Darwin-x86_64 -o /usr/local/bin/hadolint
# Linux (x86_64)
# curl -sL https://github.com/hadolint/hadolint/releases/download/v2.14.0/hadolint-Linux-x86_64 -o /usr/local/bin/hadolint
chmod +x /usr/local/bin/hadolint

# === Step 5: Per-repo setup ===
cd /path/to/repo
# (copy .pre-commit-config.yaml and linter configs here)
pre-commit install
pre-commit install --hook-type pre-push
pre-commit run --all-files
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| pipx for Python CLIs | pip install --break-system-packages | Only if pipx cannot be installed (extremely constrained environments). pip works but risks dependency conflicts between Semgrep and Checkov. |
| pipx for Python CLIs | pip install in dedicated venv | If the user wants manual control over venv locations. pipx is just automated venv management, so this is equivalent but more manual. |
| Bash install script | Makefile | If the team already uses Make extensively and prefers Makefile-driven workflows. Make lacks OS detection and error handling compared to bash. |
| Bash install script | npx setup tool | Only if all target users already have Node.js. Adds npm registry dependency for no benefit. |
| Curl install scripts for Go tools | go install github.com/... | Only if Go is installed on the target system. Requires Go toolchain + adds compile time. Binary downloads are faster and don't need Go. |
| Hardcoded versions in script | GitHub API latest release lookup | Only if you want always-latest behavior. Hardcoded versions are more predictable and verifiable. The `check` subcommand can report when updates are available. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Homebrew as sole install method** | Not available on Linux without Linuxbrew (which is awkward). Adds unnecessary dependency. | Curl install scripts (Go tools) + pipx (Python tools) |
| **Docker-based tool wrappers** | Adds Docker dependency, complicates PATH, makes tool output harder to capture, breaks file permission assumptions. | Native binary installation |
| **npm for non-JS security tools** | Semgrep and Checkov are Python tools. Wrapping them in npm adds fragile shims. | pipx for Python tools |
| **snap/flatpak** | Not available on macOS. Not standard for developer CLI tools. | Direct binary downloads |
| **asdf/mise version manager** | Adds another tool to install before you can install tools. Good for teams with complex version requirements, overkill for single-developer. | Direct installation with version pinning in the script |
| **pip install --break-system-packages** | Fragile. Conflicts between system Python packages and tool dependencies. macOS Sonoma+ and Ubuntu 23.04+ enforce PEP 668 (externally-managed-environment). | pipx (respects PEP 668 automatically) |
| **Global npm install for markdownlint** | M1 used `npm install -g markdownlint-cli`. Unnecessary -- pre-commit manages markdownlint via its own cache. | pre-commit-managed markdownlint hook |

---

## Shell Script Portability Concerns

| Concern | macOS Behavior | Linux Behavior | Mitigation |
|---------|---------------|----------------|------------|
| Bash version | 3.2 (GPLv2, Apple won't ship GPLv3) | 5.x | Script MUST target bash 3.2. No associative arrays (`declare -A`), no `readarray`/`mapfile`, no `${var,,}` lowercase, no `\|&` pipe. |
| `sed -i` | Requires `sed -i ''` (empty string backup extension) | Uses `sed -i` (no backup arg) | Avoid `sed -i`. Use `sed 's/x/y/' file > tmp && mv tmp file` pattern instead. |
| `sha256sum` | Not present. Use `shasum -a 256` | Present. | `if command -v sha256sum; then ... else shasum -a 256; fi` |
| `readlink -f` | Not present on macOS (BSD readlink) | Present (GNU readlink) | Use `cd "$(dirname "$0")" && pwd` pattern for script self-location. |
| `/usr/local/bin` permissions | Writable by admin user (no sudo on macOS with Homebrew-prepared systems) | Requires sudo | Use `$HOME/.local/bin` as default, fall back to `/usr/local/bin` with sudo. |
| `mktemp` | `mktemp -d -t prefix` (macOS requires -t) | `mktemp -d` works | Use `mktemp -d "${TMPDIR:-/tmp}/prefix.XXXXXX"` |
| Color output | Terminal.app and iTerm2 support ANSI | Most terminals support ANSI | Use `tput` or check `$TERM` before emitting colors. |

---

## Version Pinning Strategy

Pin specific versions in the install script for reproducibility. The script should contain a version block:

```bash
TRIVY_VERSION="0.69.3"
SYFT_VERSION="1.42.2"
GRYPE_VERSION="0.109.1"
GITLEAKS_VERSION="8.30.1"
HADOLINT_VERSION="2.14.0"
# Python tools: pipx installs latest by default
# Pin with: pipx install semgrep==1.155.0
```

The `install.sh check` subcommand compares installed versions against these minimums and reports deltas.

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| pipx 1.7+ | Python 3.10+ | pipx requires Python 3.8+, but Semgrep requires 3.10+, so 3.10 is the effective floor. |
| Grype >= 0.88.0 | DB schema v6 | CRITICAL: v5 EOL was 2026-03-06. Must not install older versions. |
| pre-commit 4.5.x | Python 3.9+ | pipx will create a 3.9+ venv automatically. |
| hadolint 2.14.0 | macOS arm64 / x86_64, Linux x86_64 | No Linux arm64 binary available from upstream. ARM Linux users must use Docker variant. |
| Bash 3.2 | macOS default | All script features must work on bash 3.2. Test on macOS before releasing. |

---

## Sources

- [Trivy Installation Docs](https://trivy.dev/docs/latest/getting-started/installation/) -- official install script method confirmed (HIGH confidence)
- [Anchore Grype Installation](https://oss.anchore.com/docs/installation/grype/) -- curl install script confirmed (HIGH confidence)
- [Anchore Syft Installation](https://oss.anchore.com/docs/installation/syft/) -- curl install script confirmed (HIGH confidence)
- [Gitleaks GitHub](https://github.com/gitleaks/gitleaks) -- install script path confirmed (HIGH confidence)
- [hadolint GitHub](https://github.com/hadolint/hadolint) -- binary download only, no install script (HIGH confidence)
- [Checkov Installation](https://www.checkov.io/2.Basics/Installing%20Checkov.html) -- pip/pipx confirmed (HIGH confidence)
- [Semgrep PyPI](https://pypi.org/project/semgrep/) -- pip/pipx confirmed, v1.155.0 current (HIGH confidence)
- [pipx GitHub](https://github.com/pypa/pipx) -- isolation benefits documented (HIGH confidence)
- [pip vs pipx Guide](https://betterstack.com/community/guides/scaling-python/pip-vs-pipx/) -- best practices for CLI tools (MEDIUM confidence)
- [Grype DB v5 EOL](https://anchorecommunity.discourse.group/t/grype-db-schema-v5-will-be-eol-on-march-6-2026/591) -- v5 EOL confirmed 2026-03-06 (HIGH confidence)
- [pre-commit docs](https://pre-commit.com/) -- hook environment isolation documented (HIGH confidence)
- [Apple Shell Scripting Portability](https://developer.apple.com/library/archive/documentation/OpenSource/Conceptual/ShellScripting/PortingScriptstoMacOSX/PortingScriptstoMacOSX.html) -- macOS bash/BSD differences (HIGH confidence)

---
*Stack research for: cross-platform tool installation and distribution packaging (v1.1)*
*Researched: 2026-03-16*
