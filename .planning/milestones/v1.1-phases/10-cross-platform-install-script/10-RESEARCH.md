# Phase 10: Cross-Platform Install Script - Research

**Researched:** 2026-03-17
**Domain:** Cross-platform bash installer for security CLI tools (macOS + Linux)
**Confidence:** HIGH

## Summary

Phase 10 delivers `dist/install.sh` -- a single bash script that installs 6 security CLI tools (pre-commit, Trivy, Syft, Grype, Gitleaks, hadolint) on macOS and Linux without Homebrew. The script reads pinned versions from `dist/versions.conf`, auto-detects OS/architecture, and installs tools to `~/.local/bin`. Pre-commit is the only Python/pipx tool; the other 5 are direct binary downloads.

The primary complexity is in architecture naming normalization -- each tool uses a different naming convention in its GitHub release assets (Trivy: `macOS-ARM64`, Grype: `darwin_arm64`, Gitleaks: `darwin_arm64` with `x64` for amd64, hadolint: `macos-arm64`). The version manifest with URL templates must encode these per-tool differences. The script must target bash 3.2 (macOS ships this permanently) and avoid GNU-specific commands.

**Primary recommendation:** Build the install script around per-tool URL templates in `dist/versions.conf` with `{VERSION}`, `{OS}`, `{ARCH}` placeholders. Each tool gets its own OS/arch mapping because the naming is not standardized. Use official install scripts only for Trivy, Syft, and Grype (which provide verified curl-pipe installers with checksum verification). Gitleaks and hadolint require direct binary download with manual checksum verification.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- 6 tools, NOT 8: pre-commit (pipx), Trivy, Syft, Grype, Gitleaks, hadolint (binary download)
- Semgrep is CI-only (GitHub Actions in M2) -- excluded from local install
- Checkov is CI-only (GitHub Actions in M2) -- excluded from local install
- pre-commit is the only Python/pipx tool remaining
- pre-commit installs via pipx for PEP 668 compliance and dependency isolation
- install.sh bootstraps pipx automatically if not found (pip install --user pipx)
- All 5 binary tools install to ~/.local/bin
- Use official install scripts for Trivy, Syft, Grype, Gitleaks where available
- Direct binary download for hadolint (no upstream install script)
- OS/arch auto-detection for all binary downloads
- PATH handling: run `pipx ensurepath` which handles ~/.local/bin PATH addition
- No manual shell profile modification by the script
- Default output: minimal -- errors only (stderr)
- Support -v/--verbose flag for step-by-step progress
- No color output -- plain text only
- End-of-run summary: version table showing all tools with installed version and status
- Separate .env-style file (dist/versions.conf) with KEY=VALUE pairs, sourced by install.sh
- URL templates use placeholders: {VERSION}, {OS}, {ARCH}

### Claude's Discretion
- Exact pipx bootstrap method (pip install --user vs python3 -m pip)
- Architecture name normalization table (arm64 vs aarch64 across tools)
- GNU/BSD command compatibility approach (sed, shasum, readlink)
- hadolint checksum verification approach (no standard checksums.txt in releases)
- Idempotency implementation (skip-if-already-installed checks)
- Bash 3.2 compatibility patterns throughout
- Error message format and remediation hints

### Deferred Ideas (OUT OF SCOPE)
- Semgrep local installation -- deferred to M2 CI/CD milestone
- Checkov local installation -- deferred to M2 CI/CD milestone
- Checksum verification for all binary downloads -- noted as "should have", can add later
- Dry-run mode (--dry-run flag) -- useful but not required for MVP

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INST-01 | Install script on macOS or Linux without Homebrew | Verified: all 6 tools have non-Homebrew install paths (pipx for pre-commit, official scripts for Trivy/Syft/Grype, binary download for Gitleaks/hadolint) |
| INST-02 | Auto-detect OS and architecture for binary downloads | Architecture naming table built from verified GitHub release assets for all 5 binary tools |
| INST-03 | Versions pinned in manifest, install exact versions | dist/versions.conf .env-style format with URL templates; all official install scripts accept version arguments |
| INST-04 | Verify PATH includes tool install locations, warn if missing | `pipx ensurepath` handles PATH; `command -v` verification for each tool post-install |
| INST-05 | Python CLI tools install via pipx (reduced to pre-commit only) | pipx install pre-commit; pipx bootstrap via `python3 -m pip install --user pipx` |
| INST-06 | Go binary tools via official install scripts or direct binary download | Trivy/Syft/Grype have official install scripts; Gitleaks requires direct binary download (no official script exists) |
| INST-07 | hadolint via direct binary download from GitHub releases | Verified: release assets use pattern `hadolint-{os}-{arch}` with per-file .sha256 checksums |

</phase_requirements>

## Standard Stack

### Core

| Tool | Version | Purpose | Install Method |
|------|---------|---------|----------------|
| Bash | 3.2+ | Script language | Pre-installed on macOS and Linux |
| curl | any | HTTP downloads | Pre-installed on macOS and Linux |
| pipx | 1.7+ | Python CLI isolation | Bootstrapped by install.sh via `python3 -m pip install --user pipx` |
| pre-commit | latest via pipx | Git hook framework | `pipx install pre-commit` |
| Trivy | 0.69.3 | Vulnerability scanner | Official install script with version pinning and checksum verification |
| Syft | 1.42.2 | SBOM generator | Official Anchore install script with checksum verification |
| Grype | 0.109.1 | Vulnerability scanner | Official Anchore install script with checksum verification |
| Gitleaks | 8.30.0 | Secret scanner | Direct binary download from GitHub releases (no official install script) |
| hadolint | 2.14.0 | Dockerfile linter | Direct binary download from GitHub releases |

**Version verification date:** 2026-03-17 -- all versions confirmed against GitHub releases API.

**Critical constraint:** Grype >= 0.88.0 mandatory (DB schema v5 EOL 2026-03-06).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| pipx for pre-commit | pip install --user | Breaks on PEP 668 systems (macOS 14+, Ubuntu 23.04+) |
| Official install scripts for Trivy/Syft/Grype | Direct binary download | Official scripts include checksum verification; direct download requires manual verification |
| Direct binary download for Gitleaks | go install | Requires Go toolchain on target machine |

### Installation Commands

```bash
# Prerequisites: python3, pip, curl, bash

# pipx bootstrap
python3 -m pip install --user pipx
python3 -m pipx ensurepath

# pre-commit via pipx
pipx install pre-commit

# Trivy (official install script)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ~/.local/bin v0.69.3

# Syft (official Anchore install script)
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/.local/bin v1.42.2

# Grype (official Anchore install script)
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b ~/.local/bin v0.109.1

# Gitleaks (direct binary download -- no official install script)
# Download tarball, extract, place binary in ~/.local/bin

# hadolint (direct binary download)
# Download platform-specific binary, place in ~/.local/bin, chmod +x
```

## Architecture Patterns

### Recommended Project Structure

```
dist/
  install.sh          # Main install script (~300-400 lines)
  versions.conf       # Version manifest with URL templates
```

### Pattern 1: Version Manifest Format (dist/versions.conf)

**What:** .env-style KEY=VALUE file sourced by install.sh, containing versions and URL templates per tool.

**Example:**
```bash
# dist/versions.conf -- sourced by install.sh
# Tool versions
PRECOMMIT_VERSION="4.2.0"
TRIVY_VERSION="0.69.3"
SYFT_VERSION="1.42.2"
GRYPE_VERSION="0.109.1"
GITLEAKS_VERSION="8.30.0"
HADOLINT_VERSION="2.14.0"

# URL templates -- {VERSION}, {OS}, {ARCH} replaced at runtime
# Trivy, Syft, Grype use official install scripts (no URL template needed)
GITLEAKS_URL="https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/gitleaks_{VERSION}_{OS}_{ARCH}.tar.gz"
GITLEAKS_CHECKSUMS_URL="https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/gitleaks_{VERSION}_checksums.txt"
HADOLINT_URL="https://github.com/hadolint/hadolint/releases/download/v{VERSION}/hadolint-{OS}-{ARCH}"
HADOLINT_CHECKSUM_URL="https://github.com/hadolint/hadolint/releases/download/v{VERSION}/hadolint-{OS}-{ARCH}.sha256"
```

### Pattern 2: Architecture Normalization Table

**What:** Per-tool mapping from `uname -s` / `uname -m` to the tool's release asset naming convention.

**This is CRITICAL.** Each tool uses different naming. Verified from actual GitHub release assets:

```
              | uname -s=Darwin        | uname -s=Linux
              | uname -m=arm64  x86_64 | uname -m=aarch64  x86_64
--------------+------------------------+---------------------------
Trivy OS      | macOS           macOS  | Linux           Linux
Trivy ARCH    | ARM64           64bit  | ARM64           64bit
Syft OS       | darwin          darwin | linux           linux
Syft ARCH     | arm64           amd64  | arm64           amd64
Grype OS      | darwin          darwin | linux           linux
Grype ARCH    | arm64           amd64  | arm64           amd64
Gitleaks OS   | darwin          darwin | linux           linux
Gitleaks ARCH | arm64           x64    | arm64           x64
hadolint OS   | macos           macos  | linux           linux
hadolint ARCH | arm64           x86_64 | arm64           x86_64
```

**Key gotchas discovered from live release asset data:**
- Trivy uses `macOS` (capitalized) and `64bit` / `ARM64` (not amd64 or x86_64)
- Gitleaks uses `x64` (not x86_64 or amd64) for Intel
- hadolint uses `macos` (lowercase) not `Darwin` or `macOS`
- Syft/Grype are consistent: `darwin`/`linux` + `arm64`/`amd64`
- `uname -m` returns `arm64` on macOS but `aarch64` on Linux ARM -- normalize to the tool's expected value

**Implementation approach:** Since Trivy, Syft, and Grype use official install scripts that handle their own OS/arch detection, the normalization table is only needed for Gitleaks and hadolint. For URL templates, store the normalized values per-tool:

```bash
# Bash 3.2 compatible -- no associative arrays
get_gitleaks_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "linux" ;;
    *)      echo "unsupported" ;;
  esac
}

get_gitleaks_arch() {
  case "$(uname -m)" in
    x86_64)       echo "x64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)             echo "unsupported" ;;
  esac
}

get_hadolint_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unsupported" ;;
  esac
}

get_hadolint_arch() {
  case "$(uname -m)" in
    x86_64)        echo "x86_64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)             echo "unsupported" ;;
  esac
}
```

### Pattern 3: Idempotent Install Logic

**What:** Check if tool is already installed at the correct version before downloading.

```bash
# Bash 3.2 compatible
is_installed() {
  local tool="$1"
  local expected_version="$2"

  if ! command -v "$tool" > /dev/null 2>&1; then
    return 1  # not installed
  fi

  local installed_version
  installed_version="$("$tool" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"

  if [[ "$installed_version" = "$expected_version" ]]; then
    return 0  # correct version
  fi

  return 1  # wrong version
}
```

### Pattern 4: Verbose/Quiet Output Control

**What:** Default to errors-only output. -v/--verbose shows progress.

```bash
VERBOSE=false

log() {
  if [[ "$VERBOSE" = true ]]; then
    echo "==> $*"
  fi
}

err() {
  echo "ERROR: $*" >&2
}

# curl respects verbose flag
curl_flags="-sfL"
if [[ "$VERBOSE" = true ]]; then
  curl_flags="-fL --progress-bar"
fi
```

### Pattern 5: Summary Table

**What:** End-of-run table showing install results.

```bash
# Collect results during install, print at end
# Format: TOOL VERSION STATUS
RESULTS=""

add_result() {
  local tool="$1" version="$2" status="$3"
  RESULTS="${RESULTS}${tool}|${version}|${status}\n"
}

print_summary() {
  echo ""
  echo "Security Tool Installation Summary"
  echo "-----------------------------------"
  printf "%-12s %-10s %s\n" "Tool" "Version" "Status"
  printf "%-12s %-10s %s\n" "----" "-------" "------"
  printf "%b" "$RESULTS" | while IFS='|' read -r tool version status; do
    printf "%-12s %-10s %s\n" "$tool" "$version" "$status"
  done
}
```

### Anti-Patterns to Avoid

- **Associative arrays (`declare -A`):** Fails on macOS bash 3.2. Use case statements or parallel indexed variables.
- **`${var,,}` lowercase:** Fails on bash 3.2. Use `echo "$var" | tr '[:upper:]' '[:lower:]'`.
- **`mapfile`/`readarray`:** Not available in bash 3.2. Use `while IFS= read -r line` loops.
- **`|&` pipe stderr:** Not available in bash 3.2. Use `2>&1 |`.
- **`&>` redirect both:** Not available in bash 3.2. Use `> file 2>&1`.
- **`sed -i` without empty arg:** BSD sed (macOS) requires `sed -i ''`. Avoid `sed -i` entirely; use temp file + mv.
- **`readlink -f`:** Not on macOS. Use `cd "$(dirname "$0")" && pwd` pattern.
- **`grep -P`:** Not on macOS. Use `grep -E` (extended regex).
- **`sha256sum`:** Not on macOS. Use conditional: `shasum -a 256` on macOS, `sha256sum` on Linux.
- **Single generic arch mapping for all tools:** Each tool uses different naming. Must be per-tool.
- **`curl | sh` for Gitleaks:** No official install script exists. Must download binary directly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Trivy install + checksum verify | Custom download + verify | Official install script (`contrib/install.sh`) | Handles OS/arch detection, checksum verification, version pinning |
| Syft install + checksum verify | Custom download + verify | Official Anchore install script | Same as Trivy -- handles everything |
| Grype install + checksum verify | Custom download + verify | Official Anchore install script | Same; critical for DB schema compatibility |
| pipx PATH setup | Manual shell profile editing | `pipx ensurepath` | Handles bash/zsh/fish profile detection |
| Semver comparison | Custom string parsing | Simple exact-match check | For v1.1, exact version match is sufficient; no need for semver gt/lt |

## Common Pitfalls

### Pitfall 1: Gitleaks Has No Official Install Script

**What goes wrong:** STACK.md and CONTEXT.md reference "official install scripts for Gitleaks" but this does NOT exist.
**Why it happens:** Gitleaks README mentions Homebrew and Go install, but has no curl-pipe install script at `scripts/install.sh` (verified: returns 404).
**How to avoid:** Treat Gitleaks like hadolint -- direct binary download from GitHub releases. Download tarball, extract, place in `~/.local/bin`.
**Confidence:** HIGH -- verified 404 at the expected URL on 2026-03-17.

### Pitfall 2: Gitleaks Uses `x64` Not `x86_64` or `amd64`

**What goes wrong:** Script constructs URL with `x86_64` or `amd64` for Intel arch and gets 404.
**Why it happens:** Gitleaks uses non-standard `x64` for Intel architecture in release asset naming.
**How to avoid:** Per-tool arch normalization. For Gitleaks Intel: `x64`. Verified from `gitleaks_8.30.0_darwin_x64.tar.gz`.

### Pitfall 3: Trivy Uses Capitalized `macOS` and `64bit`/`ARM64`

**What goes wrong:** Script constructs URL with `darwin` or `amd64` and gets 404.
**Why it happens:** Trivy uses unusual naming: `macOS-ARM64`, `Linux-64bit` instead of standard Go naming conventions.
**How to avoid:** This is handled by Trivy's official install script -- use it and avoid manual URL construction. The official script normalizes internally.

### Pitfall 4: hadolint Uses `macos` (lowercase)

**What goes wrong:** Script uses `Darwin` from `uname -s` directly in URL and gets 404.
**Why it happens:** hadolint uses lowercase `macos` and `linux`, not the `uname -s` output.
**How to avoid:** Map `Darwin` to `macos`, `Linux` to `linux` in the hadolint-specific function.

### Pitfall 5: PEP 668 Blocks pipx Bootstrap

**What goes wrong:** `python3 -m pip install --user pipx` fails on PEP 668 systems.
**Why it happens:** Modern macOS 14+ with Homebrew Python and Ubuntu 23.04+ enforce externally-managed-environment.
**How to avoid:** Try `python3 -m pip install --user pipx` first. If it fails with PEP 668 error, fall back to `python3 -m pip install --user --break-system-packages pipx` with a warning, or check if `apt install pipx` / `brew install pipx` is available. The pipx bootstrap is a one-time operation and pipx itself is small enough that `--break-system-packages` is acceptable for this single package.
**Alternative approach:** Check for pipx first with `command -v pipx`. Many modern systems (Ubuntu 24.04, Fedora) ship pipx in their package manager. Only bootstrap via pip if pipx is truly absent.

### Pitfall 6: `~/.local/bin` Not on PATH After First pipx Install

**What goes wrong:** Tools install but `command -v` fails in the same session.
**Why it happens:** `pipx ensurepath` modifies shell profile but the current session does not re-source it.
**How to avoid:** After `pipx ensurepath`, explicitly add `~/.local/bin` to `PATH` for the current script session: `export PATH="$HOME/.local/bin:$PATH"`. The end-of-script summary should note if a terminal restart is needed for the changes to persist.

### Pitfall 7: Official Install Scripts Default to `/usr/local/bin`

**What goes wrong:** Trivy/Syft/Grype install to `/usr/local/bin` (requires sudo on Linux) instead of `~/.local/bin`.
**Why it happens:** The `-b` flag defaults to `./bin` or `/usr/local/bin` in the official scripts.
**How to avoid:** Always pass `-b ~/.local/bin` explicitly: `curl -sfL ... | sh -s -- -b "$HOME/.local/bin" v0.69.3`. The `~` does not expand inside quotes passed to `sh -s`, so use `$HOME`.

## Code Examples

### Script Skeleton (bash 3.2 compatible)

```bash
#!/usr/bin/env bash
set -euo pipefail

# install.sh -- Install security CLI tools
# Usage: bash install.sh [-v|--verbose]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERBOSE=false
INSTALL_DIR="$HOME/.local/bin"

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=true ;;
    -h|--help)    usage; exit 0 ;;
    *)            err "Unknown argument: $arg"; exit 1 ;;
  esac
done

# Source version manifest
if [[ -f "$SCRIPT_DIR/versions.conf" ]]; then
  # shellcheck source=versions.conf
  . "$SCRIPT_DIR/versions.conf"
else
  err "versions.conf not found in $SCRIPT_DIR"
  exit 1
fi

# Ensure install directory exists
mkdir -p "$INSTALL_DIR"

# Add to PATH for this session
export PATH="$INSTALL_DIR:$PATH"
```

### Checksum Verification (cross-platform)

```bash
verify_sha256() {
  local file="$1"
  local expected="$2"

  local actual
  if command -v sha256sum > /dev/null 2>&1; then
    actual="$(sha256sum "$file" | cut -d' ' -f1)"
  elif command -v shasum > /dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  else
    err "No sha256sum or shasum found; cannot verify checksum"
    return 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    err "Checksum mismatch for $file"
    err "  Expected: $expected"
    err "  Actual:   $actual"
    return 1
  fi
}
```

### hadolint Direct Download Pattern

```bash
install_hadolint() {
  local version="$1"
  local os arch url checksum_url

  os="$(get_hadolint_os)"
  arch="$(get_hadolint_arch)"
  url="https://github.com/hadolint/hadolint/releases/download/v${version}/hadolint-${os}-${arch}"
  checksum_url="${url}.sha256"

  local tmpdir
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/hadolint.XXXXXX")"

  log "Downloading hadolint v${version} (${os}/${arch})"
  curl -sfL -o "$tmpdir/hadolint" "$url"
  curl -sfL -o "$tmpdir/hadolint.sha256" "$checksum_url"

  # Verify checksum -- hadolint .sha256 files contain just the hash
  local expected_hash
  expected_hash="$(cat "$tmpdir/hadolint.sha256" | cut -d' ' -f1)"
  verify_sha256 "$tmpdir/hadolint" "$expected_hash"

  chmod +x "$tmpdir/hadolint"
  mv "$tmpdir/hadolint" "$INSTALL_DIR/hadolint"
  rm -rf "$tmpdir"
}
```

### Gitleaks Direct Download Pattern

```bash
install_gitleaks() {
  local version="$1"
  local os arch url checksums_url

  os="$(get_gitleaks_os)"
  arch="$(get_gitleaks_arch)"
  url="https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_${os}_${arch}.tar.gz"
  checksums_url="https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_checksums.txt"

  local tmpdir
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/gitleaks.XXXXXX")"

  log "Downloading gitleaks v${version} (${os}/${arch})"
  curl -sfL -o "$tmpdir/gitleaks.tar.gz" "$url"
  curl -sfL -o "$tmpdir/checksums.txt" "$checksums_url"

  # Verify checksum from checksums.txt
  local filename="gitleaks_${version}_${os}_${arch}.tar.gz"
  local expected_hash
  expected_hash="$(grep "$filename" "$tmpdir/checksums.txt" | cut -d' ' -f1)"
  verify_sha256 "$tmpdir/gitleaks.tar.gz" "$expected_hash"

  tar -xzf "$tmpdir/gitleaks.tar.gz" -C "$tmpdir"
  mv "$tmpdir/gitleaks" "$INSTALL_DIR/gitleaks"
  rm -rf "$tmpdir"
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `pip install` for Python CLIs | `pipx install` | PEP 668 enforcement (2023-2024) | `pip install` fails on modern systems; pipx is now required |
| `brew install` for all tools | Official install scripts + binary download | Always available, but Homebrew was convenient default | Cross-platform without Homebrew dependency |
| Grype DB schema v5 | Grype DB schema v6 | v5 EOL 2026-03-06 | Grype < 0.88.0 cannot fetch current vulnerability data |
| hadolint `hadolint-Darwin-arm64` naming | `hadolint-macos-arm64` | v2.14.0 | Changed from `Darwin` to `macos` in release assets |

## Open Questions

1. **pipx bootstrap on strict PEP 668 systems**
   - What we know: `python3 -m pip install --user pipx` may fail on PEP 668 systems
   - What's unclear: Whether `--break-system-packages` for pipx alone is acceptable, or if we should detect and use OS package manager (`apt install pipx`, `brew install pipx`)
   - Recommendation: Try pip first, fall back to OS package manager detection. pipx is a small package and `--break-system-packages` for this one package is low-risk.

2. **pre-commit version pinning in pipx**
   - What we know: `pipx install pre-commit` installs latest by default
   - What's unclear: Whether to pin (`pipx install pre-commit==4.2.0`) or allow latest
   - Recommendation: Pin the version in versions.conf for reproducibility. Use `pipx install "pre-commit==${PRECOMMIT_VERSION}"`.

3. **Gitleaks install script path correction**
   - What we know: The CONTEXT.md says "Use official install scripts for Trivy, Syft, Grype, Gitleaks where available" but Gitleaks has NO official install script
   - Resolution: Treat Gitleaks as direct binary download (same as hadolint). The PLAN must reflect this.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash + manual verification (no test framework for shell scripts in this project) |
| Config file | None -- shell scripts validated by execution + ShellCheck |
| Quick run command | `bash dist/install.sh -v && bash dist/install.sh -v` (idempotency test) |
| Full suite command | `bash dist/install.sh -v` followed by version verification of all 6 tools |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INST-01 | Script installs 6 tools on macOS without Homebrew | smoke | `bash dist/install.sh -v` on macOS | Wave 0 |
| INST-02 | Auto-detects OS and architecture | smoke | Run on macOS arm64, verify correct binaries downloaded | Wave 0 |
| INST-03 | Reads versions from manifest, installs exact versions | smoke | `bash dist/install.sh -v && trivy --version \| grep 0.69.3` | Wave 0 |
| INST-04 | Verifies PATH and warns if missing | smoke | Check script output for PATH warning when ~/.local/bin not in PATH | Wave 0 |
| INST-05 | pre-commit installs via pipx | smoke | `pipx list \| grep pre-commit` after install | Wave 0 |
| INST-06 | Go binary tools via official scripts or binary download | smoke | `trivy --version && syft --version && grype --version && gitleaks version` | Wave 0 |
| INST-07 | hadolint via direct binary download | smoke | `hadolint --version \| grep 2.14.0` | Wave 0 |

### Sampling Rate

- **Per task commit:** `shellcheck dist/install.sh && bash -n dist/install.sh`
- **Per wave merge:** Full install on clean environment
- **Phase gate:** All 6 tools respond to version command after fresh install

### Wave 0 Gaps

- [ ] `dist/install.sh` -- main install script (to be created)
- [ ] `dist/versions.conf` -- version manifest (to be created)
- [ ] ShellCheck validation: `shellcheck dist/install.sh`
- [ ] Bash syntax check: `bash -n dist/install.sh`

## Sources

### Primary (HIGH confidence)

- GitHub Releases API for [hadolint](https://api.github.com/repos/hadolint/hadolint/releases/latest) -- verified asset naming: `hadolint-{macos|linux}-{arm64|x86_64}` with per-file `.sha256` checksums
- GitHub Releases API for [Gitleaks](https://api.github.com/repos/gitleaks/gitleaks/releases/latest) -- verified: v8.30.0, naming `gitleaks_{version}_{os}_{arch}.tar.gz`, uses `x64` for Intel, `checksums.txt` available
- GitHub Releases API for [Trivy](https://api.github.com/repos/aquasecurity/trivy/releases/latest) -- verified: v0.69.3, naming `trivy_{version}_{macOS|Linux}-{ARM64|64bit}.tar.gz`
- GitHub Releases API for [Grype](https://api.github.com/repos/anchore/grype/releases/latest) -- verified: v0.109.1, naming `grype_{version}_{darwin|linux}_{arm64|amd64}.tar.gz`
- GitHub Releases API for [Syft](https://api.github.com/repos/anchore/syft/releases/latest) -- verified: v1.42.2, naming `syft_{version}_{darwin|linux}_{arm64|amd64}.tar.gz`
- [Trivy official install script](https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh) -- verified: supports `-b` flag and version pinning, includes SHA-256 verification
- Gitleaks install script at `scripts/install.sh` -- verified: **does NOT exist** (404). Gitleaks requires direct binary download.
- `.planning/research/STACK.md`, `PITFALLS.md`, `ARCHITECTURE.md`, `SUMMARY.md` -- project research (HIGH confidence)
- `.planning/codebase/CONVENTIONS.md` -- shell script conventions (HIGH confidence)

### Secondary (MEDIUM confidence)

- [Trivy installation docs](https://trivy.dev/docs/latest/getting-started/installation/)
- [Anchore Grype installation](https://oss.anchore.com/docs/installation/grype/)
- [Anchore Syft installation](https://oss.anchore.com/docs/installation/syft/)
- [pre-commit PyPI](https://pypi.org/project/pre-commit/)
- [pipx installation docs](https://pipx.pypa.io/stable/installation/)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all versions confirmed against GitHub API on 2026-03-17
- Architecture naming: HIGH -- every tool's release asset naming verified from live API data
- Pitfalls: HIGH -- Gitleaks install script absence confirmed (404); PEP 668 and bash 3.2 well-documented in project research
- Code patterns: HIGH -- bash 3.2 patterns from project conventions + pitfalls research

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (30 days -- tool versions may update but patterns are stable)
