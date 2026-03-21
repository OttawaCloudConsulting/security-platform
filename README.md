# security-platform

Canonical security configuration for OttawaCloudConsulting repositories.

## Contents

| Path | Description |
|------|-------------|
| `.pre-commit-config.yaml` | Pre-commit hook configuration (Tier 1 quality + Tier 2 secrets) |
| `.gitleaksignore` | Gitleaks false-positive suppressions |
| `.markdownlint-cli2.yaml` | markdownlint-cli2 rule configuration |
| `.markdownlint-fix.markdownlint.jsonc` | Auto-fixable markdownlint rules |
| `.markdownlint.jsonc` | Enforced markdownlint rules |
| `dist/install.sh` | Cross-platform security tool installer |
| `dist/versions.conf` | Pinned tool versions and download URLs |
| `cicd/lint-markdown.sh` | Three-tier markdown linting script |
| `cicd/pre-commit.sh` | Pre-commit hook for staged markdown files |

## Quick Start

### Install Security Tools

```bash
bash dist/install.sh              # standard install
bash dist/install.sh -v           # verbose output
```

Installs six security CLI tools to `~/.local/bin`:

| Tool | Purpose | Install Method |
|------|---------|----------------|
| pre-commit | Git hook framework | pipx |
| Trivy | Container/IaC vulnerability scanner | Official install script |
| Syft | SBOM generator | Official install script |
| Grype | Dependency vulnerability scanner | Official install script |
| Gitleaks | Secret detection | Binary download + checksum |
| hadolint | Dockerfile linter | Binary download + checksum |

Pinned versions are in `dist/versions.conf`. The installer is idempotent — re-running skips tools already at the pinned version. SHA-256 checksums are verified for directly downloaded binaries.

### Deploy Pre-commit Hooks

Copy `.pre-commit-config.yaml` to the target repository root, then:

```bash
cd <target-repo>
pre-commit install
pre-commit install --hook-type pre-push
pre-commit run --all-files
```

### Markdown Linting

The `cicd/lint-markdown.sh` script provides three-tier markdown linting:

1. **Ignored rules** — disabled in `.markdownlint.jsonc` (never checked)
2. **Auto-fix rules** — enabled in `.markdownlint-fix.markdownlint.jsonc` (fixed silently)
3. **Error rules** — everything else (reported as errors)

```bash
bash cicd/lint-markdown.sh                # lint *.md in current directory
bash cicd/lint-markdown.sh -r             # lint *.md recursively
bash cicd/lint-markdown.sh README.md      # lint a single file
bash cicd/lint-markdown.sh --no-fix       # skip auto-fix, report everything
```

The `cicd/pre-commit.sh` hook lints only staged markdown files and re-stages auto-fixes.

## Secrets Detection

Gitleaks runs as a **pre-push hook** — it scans staged changes for credentials and secrets before they reach the remote repository.

**If Gitleaks blocks your push:**

1. Review the finding — is it a real secret or a false positive?
2. Real secret: remove it, rotate the credential, then push again
3. False positive: add the fingerprint to `.gitleaksignore` (see format in that file)

**Bypass:** `git push --no-verify` skips the hook. Use only when you've verified the finding is a false positive and can't immediately update `.gitleaksignore`. CI will re-scan server-side (see ADR-011).

## Prerequisites

- **macOS** (arm64/x86_64) or **Linux** (x86_64/arm64)
- `curl`
- `python3` (for pipx bootstrap, only if pipx is not already installed)

## Updating Versions

Edit `dist/versions.conf` to bump a tool version. For Gitleaks and hadolint, the URL templates use `{VERSION}` placeholders — no URL changes needed for version bumps.
