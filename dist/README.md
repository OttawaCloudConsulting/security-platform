# Security Tool Installer

Cross-platform install script for the development security stack. Installs six security CLI tools to `~/.local/bin` on macOS and Linux.

## Tools Installed

| Tool | Purpose | Install Method |
|------|---------|----------------|
| pre-commit | Git hook framework | pipx |
| Trivy | Container/IaC vulnerability scanner | Official install script |
| Syft | SBOM generator | Official install script |
| Grype | Dependency vulnerability scanner | Official install script |
| Gitleaks | Secret detection | Binary download + checksum |
| hadolint | Dockerfile linter | Binary download + checksum |

Pinned versions are in `versions.conf`.

## Usage

```bash
bash dist/install.sh              # standard install
bash dist/install.sh -v           # verbose output
bash dist/install.sh -h           # show help
```

## Prerequisites

- **macOS** (arm64/x86_64) or **Linux** (x86_64/arm64)
- `curl`
- `python3` (for pipx bootstrap, only if pipx is not already installed)

## Behavior

- **Idempotent** — re-running skips tools that are already installed at the pinned version
- Installs binaries to `~/.local/bin` (created if missing)
- Warns if `~/.local/bin` is not on `PATH`
- Verifies SHA-256 checksums for directly downloaded binaries (Gitleaks, hadolint)
- Prints a summary table on completion
- Exits non-zero if any tool fails to install

## Updating Versions

Edit `versions.conf` to bump a tool version. For Gitleaks and hadolint, the URL templates use `{VERSION}` placeholders — no URL changes needed for version bumps.

## Files

| File | Description |
|------|-------------|
| `install.sh` | Main install script |
| `versions.conf` | Pinned versions and download URLs |
