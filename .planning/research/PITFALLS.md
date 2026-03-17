# Pitfalls Research

**Domain:** Cross-platform security tool distribution packaging (v1.1 milestone)
**Researched:** 2026-03-16
**Confidence:** HIGH (verified against project's existing M1 install guide, macOS/Linux ecosystem docs, and community-reported issues)

## Critical Pitfalls

### Pitfall 1: PEP 668 "Externally Managed Environment" Breaks pip install

**What goes wrong:**
The install script runs `pip install pre-commit semgrep checkov` and fails immediately on modern Linux distributions (Debian 12+, Ubuntu 23.04+, Fedora 38+) and macOS 14+ with Homebrew Python. The error is `error: externally-managed-environment`. The existing M1 installation guide uses `pip install --break-system-packages` which works but is a fragile workaround that may stop working or cause package conflicts.

**Why it happens:**
PEP 668 (adopted 2023, now enforced by default on all major distributions) prevents pip from installing packages into the system Python environment to avoid conflicts with the OS package manager. Both `apt`-managed Python on Linux and `brew`-managed Python on macOS now set the `EXTERNALLY-MANAGED` marker. This is not a temporary restriction -- it is the permanent new default.

**How to avoid:**
- Use `pipx` for CLI tool installation (pre-commit, semgrep, checkov). pipx creates isolated venvs per tool automatically. This is the officially recommended approach for Python CLI applications.
- Detect whether `pipx` is available; if not, install it first (`pip install --user pipx` or `brew install pipx` or `apt install pipx`).
- Fall back to `pip install --user` only if pipx is unavailable AND the system does not have the `EXTERNALLY-MANAGED` marker.
- Never use `--break-system-packages` in an automated installer -- it works today but teaches users to override safety mechanisms, and future Python versions may remove the flag entirely.

**Warning signs:**
- Install script fails on a fresh Ubuntu 24.04 or Debian 12 machine
- Users report "externally-managed-environment" errors in issues
- Script uses `--break-system-packages` as default path

**Phase to address:** Phase 1 (Install Script) -- the Python tool installation strategy must be decided before writing any install logic

---

### Pitfall 2: macOS Bash 3.2 vs Linux Bash 5.x Compatibility

**What goes wrong:**
The install script uses bash 4+ features (associative arrays `declare -A`, `${var,,}` lowercase expansion, `mapfile`/`readarray`, `|&` pipe stderr, `{var}` automatic fd allocation) and fails silently or with cryptic syntax errors on macOS, which ships bash 3.2.57 (GPLv2 -- Apple will never ship bash 4+ due to GPLv3 licensing). The script works perfectly on the developer's Linux CI runner and their upgraded-bash macOS, but breaks for any macOS user with stock bash.

**Why it happens:**
macOS has shipped bash 3.2 since 2007 and will never update it due to the GPLv3 license change in bash 4.0. Developers who have `brew install bash` on their own machines do not realize they are testing against a non-default shell. The default macOS shell is now zsh, but shebangs targeting `#!/usr/bin/env bash` still invoke bash 3.2 unless the user has explicitly changed their PATH to prioritize Homebrew's bash.

**How to avoid:**
- Write all install scripts to POSIX sh or bash 3.2 compatibility. Specifically:
  - No associative arrays (`declare -A`) -- use multiple indexed arrays or case statements
  - No `${var,,}` or `${var^^}` -- use `tr '[:upper:]' '[:lower:]'` or `echo "$var" | tr A-Z a-z`
  - No `mapfile`/`readarray` -- use `while IFS= read -r line` loops
  - No `|&` -- use `2>&1 |`
  - No `[[ ... =~ regex ]]` with complex patterns -- keep regex simple or use `grep -qE`
  - No `&>` -- use `> file 2>&1`
- Use `#!/usr/bin/env bash` (not `#!/bin/bash`) so Homebrew-installed bash is found if available, but do not require it
- Test on macOS with `/bin/bash --version` confirming 3.2.x before releasing
- Consider writing the install script in POSIX `sh` entirely (`#!/bin/sh`) -- this sidesteps the bash version issue completely

**Warning signs:**
- Script contains `declare -A`, `mapfile`, `readarray`, `${var,,}`, `|&`, or `&>`
- Script only tested on Linux or on macOS with Homebrew bash
- Syntax errors on macOS that do not reproduce on Linux

**Phase to address:** Phase 1 (Install Script) -- must be a constraint from line one of the script

---

### Pitfall 3: Architecture Detection Naming Inconsistency

**What goes wrong:**
The install script downloads the wrong binary (or no binary) because architecture naming is inconsistent across tools. `uname -m` returns `x86_64` on Intel and `arm64` on Apple Silicon macOS, but `aarch64` on ARM Linux. GitHub release assets use varying naming: Trivy uses `Linux-ARM64`, `macOS-ARM64`; Grype uses `linux_arm64`, `darwin_arm64`; hadolint uses `Linux-arm64`, `Darwin-arm64`. A naive mapping breaks on at least one tool.

**Why it happens:**
There is no universal standard for architecture naming in release artifacts. Each Go project chooses its own naming convention based on how `GOOS` and `GOARCH` are interpolated into the release filename template. `uname -m` itself is inconsistent: macOS returns `arm64` while Linux returns `aarch64` for the same ARM64 architecture. The OS name is also inconsistent: `uname -s` returns `Darwin` on macOS.

**How to avoid:**
- Build a normalization function that maps `uname -s` and `uname -m` to per-tool naming:
  ```
  OS: Darwin -> {darwin, macOS, Darwin} (varies by tool)
  ARCH: x86_64 -> {amd64, 64bit, x86_64}
  ARCH: arm64|aarch64 -> {arm64, ARM64, aarch64}
  ```
- Maintain a lookup table of download URL patterns per tool, not a generic template
- Verify the downloaded binary's architecture matches the host: `file /path/to/binary` should show the correct architecture
- Test on all four combinations: macOS-arm64, macOS-amd64 (rare but exists), Linux-amd64, Linux-arm64

**Warning signs:**
- Script has a single `ARCH=$(uname -m)` used directly in all download URLs without normalization
- Binary downloads succeed but `exec format error` when running (wrong architecture)
- Script works on macOS but fails on Linux ARM (or vice versa)

**Phase to address:** Phase 1 (Install Script) -- the architecture mapping table must be defined and tested for every tool

---

### Pitfall 4: `~/.local/bin` Not on PATH (pip --user and pipx Installs Invisible)

**What goes wrong:**
The install script installs tools via `pip install --user` or `pipx` and reports success, but the tools are not found when the user opens a new terminal or runs them. On macOS, pip --user installs to `~/Library/Python/3.x/bin/`, not `~/.local/bin`. On some Linux distributions (notably Debian/Ubuntu), `~/.local/bin` is not on PATH by default unless it already exists when the shell profile is sourced. pipx installs to `~/.local/bin` on both platforms but the same PATH issue applies.

**Why it happens:**
pip's `--user` scheme uses platform-specific paths. macOS uses the Framework layout (`~/Library/Python/X.Y/bin`), while Linux uses the sysconfig user scheme (`~/.local/bin`). Debian/Ubuntu's `~/.profile` contains a conditional that only adds `~/.local/bin` to PATH if the directory exists at login time -- so if you create it mid-session, you need to re-login. pipx is consistent (`~/.local/bin` on both platforms) but still has the PATH problem.

**How to avoid:**
- After installing tools, check if the install destination is on PATH. If not, print an explicit instruction telling the user what to add and to which file (`~/.bashrc`, `~/.zshrc`, `~/.profile`)
- Create `~/.local/bin` before installation if using pipx, so Debian's profile conditional picks it up on next login
- Use `pipx ensurepath` after pipx install -- this adds `~/.local/bin` to the appropriate shell profile automatically
- For the install script itself, detect the actual install location: `python3 -m site --user-base` + `/bin`
- Verify tools are callable after install by running `command -v <tool>` -- do not just check exit codes of the install command

**Warning signs:**
- Install script exits 0 but `pre-commit --version` fails with "command not found" in a new terminal
- User reports tools work in the install session (because PATH was temporarily modified) but not after reopening terminal
- Different behavior between bash and zsh users (different profile files sourced)

**Phase to address:** Phase 1 (Install Script) -- PATH verification must be the final step, not assumed

---

### Pitfall 5: Non-Idempotent Installer Corrupts Config on Re-run

**What goes wrong:**
Running the install/setup script a second time (for updates, or after a partial failure) causes: duplicate PATH entries in shell profiles, duplicate hook entries appended to `.pre-commit-config.yaml`, config files overwritten losing user customizations (e.g., added `.gitleaksignore` entries, custom `.markdownlint.json` rules), or errors because resources already exist (pre-commit hooks already installed, tool already at correct version).

**Why it happens:**
Install scripts are written for the first-run case. Appending to shell profiles (`echo 'export PATH=...' >> ~/.bashrc`) creates duplicates on every run. File copy operations (`cp template.yaml .pre-commit-config.yaml`) overwrite customizations. `pre-commit install` is already idempotent but other setup steps are not. The developer tests the script once on a clean machine and never re-runs it.

**How to avoid:**
- Use marker comments to detect prior installation: `grep -q '# security-stack-managed' ~/.bashrc` before appending
- For config files that users may customize (`.markdownlint.json`, `.gitleaksignore`), do not overwrite if file exists -- print a diff or prompt
- For config files that are fully managed (`.pre-commit-config.yaml`), overwrite is acceptable but warn the user what changed
- Every setup step should check preconditions: "Is this tool already installed at the correct version? Skip."
- Test the script by running it twice in sequence -- the second run should produce no changes and no errors

**Warning signs:**
- `echo $PATH` shows the same directory repeated multiple times
- Shell startup is slow (loading duplicate profile entries)
- User's custom `.gitleaksignore` fingerprints disappear after running setup

**Phase to address:** Phase 2 (Distribution Package) -- the "drop configs into repo" logic must handle existing files

---

### Pitfall 6: pre-commit Hook Version Conflicts with Existing Repos

**What goes wrong:**
The distribution package drops a `.pre-commit-config.yaml` into a repo that already has one (from M1 manual setup). The pinned versions in the template may differ from what the existing repo uses. Running `pre-commit install-hooks` after dropping the new config downloads different hook environments, and the old cached environments waste disk. Worse: if the existing repo pinned a specific version of a hook due to a compatibility issue (e.g., a ruff version that broke their code), the template overwrites that pin.

**Why it happens:**
The distribution package is designed for fresh repos but gets applied to repos that already have M1 tooling. There is no merge strategy for `.pre-commit-config.yaml` -- it is a YAML file with ordered list semantics that does not support simple key-based merging.

**How to avoid:**
- Detect existing `.pre-commit-config.yaml` before dropping the template. If one exists, compare versions and report differences rather than overwriting
- Provide a `--force` flag for intentional overwrites, but default to non-destructive
- Keep a single source of truth for hook versions (e.g., a versions file in the distribution package) and provide an `update` command that bumps versions in existing configs
- Run `pre-commit clean` after version changes to remove stale cached environments
- Document which hooks have known version-sensitive behavior (ruff major versions, eslint config format changes)

**Warning signs:**
- Different repos have different hook versions for no reason
- Disk usage grows because old and new hook environments coexist in `~/.cache/pre-commit`
- A hook that worked before the distribution package was applied now fails

**Phase to address:** Phase 2 (Distribution Package) -- the config deployment strategy must distinguish fresh vs existing repos

---

### Pitfall 7: GNU vs BSD Command Differences in Install Script

**What goes wrong:**
The install script uses GNU-specific flags for common utilities and fails on macOS, which ships BSD variants. Most common failures: `sed -i` (GNU) vs `sed -i ''` (BSD) -- on macOS, `sed -i` without the empty string argument treats the next argument as the backup extension. `grep -P` (Perl regex) does not exist on macOS BSD grep. `readlink -f` does not exist on macOS. `mktemp -d` works on both but `mktemp --suffix` does not exist on BSD.

**Why it happens:**
Linux is the default development and CI environment for most developers. GNU coreutils behavior is assumed universal. macOS provides BSD-derived utilities with subtly different flag semantics. The differences are especially treacherous because many commands with the same name accept different flags, often failing silently rather than with errors.

**How to avoid:**
- `sed -i`: use `sed -i'' -e '...'` (works on both GNU and BSD) or write to a temp file and mv
- `grep -P`: use `grep -E` (extended regex, works everywhere) or `awk`
- `readlink -f`: use a function: `realpath() { python3 -c "import os; print(os.path.realpath('$1'))"; }`; or use `cd "$(dirname "$1")" && pwd -P`
- `mktemp`: use `mktemp -d` without `--suffix` (universally supported)
- `date`: GNU `date -d` vs BSD `date -j -f` -- avoid date arithmetic in the install script entirely, or use python3 for date operations
- Run ShellCheck on the install script with `--shell=bash` and pay attention to SC2039 (bash-specific features in sh scripts)

**Warning signs:**
- `sed: 1: "...": invalid command code` errors on macOS
- `grep: invalid option -- P` errors on macOS
- Script tested only on Linux CI

**Phase to address:** Phase 1 (Install Script) -- every shell command must be tested on macOS BSD utilities

---

### Pitfall 8: Binary Downloads Without Checksum Verification

**What goes wrong:**
The install script downloads security tool binaries from GitHub Releases via curl and executes them without verifying checksums. A compromised CDN, DNS hijack, or man-in-the-middle attack substitutes a malicious binary. The irony is particularly sharp: the security scanning stack is itself installed via an insecure mechanism.

**Why it happens:**
Checksum verification adds complexity to the install script. Each GitHub release has a different checksum file format. Some tools provide `.sha256` files, others embed checksums in the release notes, others provide a `checksums.txt` file. The developer skips verification because "it is from GitHub over HTTPS."

**How to avoid:**
- Download the checksum file alongside every binary (Trivy, Grype, Syft, hadolint, Gitleaks all provide checksums in their GitHub releases)
- Verify with `sha256sum --check` (Linux) or `shasum -a 256 --check` (macOS) -- note this is itself a GNU vs BSD difference
- Use the tool's official install script where one exists (Grype and Syft provide `install.sh` from Anchore that includes verification)
- If no checksum is available, at minimum verify the binary with `file` to confirm it is the correct architecture and format

**Warning signs:**
- Install script contains `curl ... | sh` or `curl ... -o binary && chmod +x binary` with no checksum step
- No `.sha256` or `checksums.txt` file referenced in the download logic
- Script downloads from GitHub but does not pin to a specific release tag (uses `latest`)

**Phase to address:** Phase 1 (Install Script) -- security tools must be installed securely

---

### Pitfall 9: Version Pinning Without Update Mechanism

**What goes wrong:**
The install script pins every tool to a specific version (correct for reproducibility) but provides no mechanism to check for or apply updates. Six months later, all tools are outdated, vulnerability databases reference CVEs the tools cannot detect, and the developer has no way to update without manually editing version strings in the script. Grype's DB schema versioning is especially dangerous: a too-old Grype version cannot use the current vulnerability database at all (as happened with the DB v5 EOL on 2026-03-06).

**Why it happens:**
The initial focus is on "get it working." Version pinning is added for reliability. The update workflow is deferred to "later" and never built. The version pins become stale silently because there is no notification mechanism.

**How to avoid:**
- Build a `--check-updates` or `--update` subcommand into the install script from day one
- For each tool, query the GitHub API for the latest release: `curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r .tag_name`
- Compare installed version against latest; print a summary of what is outdated
- Separate "check" from "apply" -- checking should be non-destructive
- For Grype specifically: check DB schema compatibility before updating (the DB schema version must match the Grype version)
- Store installed versions in a manifest file (e.g., `.security-stack-versions.json`) for easy comparison

**Warning signs:**
- No `--update` or version-check capability in the install script
- All version strings are hardcoded with no mechanism to change them
- Developer discovers tools are outdated only when scans start failing

**Phase to address:** Phase 1 (Install Script) -- version check is a v1.1 requirement per PROJECT.md

---

### Pitfall 10: Local Hook Definitions Require System-Installed Tools

**What goes wrong:**
The `.pre-commit-config.yaml` defines `local` hooks (ESLint, npm-audit) that use `language: system`. These hooks assume the tool is installed and on PATH in the system where git runs. If a fresh repo gets the distribution config but does not have eslint installed, the hook fails with "command not found" on every commit. The user's first experience with the security stack is a broken commit.

**Why it happens:**
`language: system` means pre-commit does not manage the tool's installation -- it just calls whatever is on PATH. This is fine for tools that the install script installs, but ESLint is per-project (requires `npm install` in the repo) and npm-audit requires npm (universally present but the hook still fails if `package-lock.json` is absent). The distribution package assumes all tools are ready, but not all repos have the same language dependencies.

**How to avoid:**
- Add `types_or` or `files` patterns to every local hook so hooks are skipped when no matching files exist (the current config already does this for ESLint with `files: \.(js|jsx|ts|tsx)$` -- verify npm-audit also has proper file matching)
- Document that ESLint hooks require per-project npm install
- Consider using pre-commit's `language: node` for ESLint instead of `language: system` -- pre-commit will manage the node environment
- For the distribution package, detect which languages are present in the target repo and only enable relevant hooks
- Add `verbose: true` or a custom `entry` wrapper that prints a helpful message when the tool is not found

**Warning signs:**
- `pre-commit run --all-files` fails on a repo that has no JavaScript/TypeScript files (should skip, not fail)
- User's first commit after setup fails with "eslint: command not found"
- Different repos produce different hook results despite identical `.pre-commit-config.yaml`

**Phase to address:** Phase 2 (Distribution Package) -- the config must use file-pattern matching to be language-aware

---

### Pitfall 11: Semgrep Binary Size and Installation Time

**What goes wrong:**
Semgrep's pip installation downloads hundreds of megabytes and takes 2-5 minutes. On CI runners or constrained machines, this dominates the entire install script runtime. If the install is interrupted, pip may leave a partially installed package that breaks subsequent attempts. Additionally, Semgrep's first scan downloads community rules (~100MB), adding more latency to the first-use experience.

**Why it happens:**
Semgrep bundles a large OCaml binary and multiple language parsers. Unlike Go-based tools (Trivy, Grype) that are single static binaries, Semgrep is a complex Python package with native extensions. The pip install is genuinely slow, and there is no lightweight alternative.

**How to avoid:**
- Install Semgrep via pipx (isolated venv, avoids dependency conflicts with other Python tools)
- Consider whether Semgrep belongs in the local install script at all vs being CI-only (per the project's own architecture, Semgrep runs at the PR gate in GitHub Actions, not as a pre-commit hook)
- If included in local install: warn the user about expected install time, show progress
- Pre-download community rules during install so first scan is fast: `semgrep --config auto --dry-run .`
- For version updates, `pipx upgrade semgrep` avoids full reinstall in many cases

**Warning signs:**
- Install script takes 5+ minutes and most of the time is Semgrep
- Users cancel the install because it appears hung during Semgrep download
- Semgrep and Checkov dependency conflicts when installed in the same pip environment

**Phase to address:** Phase 1 (Install Script) -- decide Semgrep's install scope (local vs CI-only) before building

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `--break-system-packages` for pip | Script works on all systems immediately | Overrides PEP 668 safety; future Python versions may remove the flag; creates package conflicts with OS-managed packages | Never in an automated installer; only for manual one-off installs with understanding |
| Hardcoded GitHub release URLs | Simple download logic | URLs break when repos change organization, naming convention, or release format | Never -- use the GitHub API or tool's official install script |
| Single `install.sh` for all tools | One script does everything | Script grows to 500+ lines; failures partway through leave partial state; hard to test individual components | Early prototype only; refactor into per-tool functions before v1.1 release |
| Skipping checksum verification | Faster install, simpler script | Security tools installed insecurely; undermines trust in the stack | Never for a security tooling installer |
| Using `curl ... \| sh` for tool install scripts | Convenient, works out of the box | Cannot audit what runs; version not pinned; script content may change | Acceptable for Anchore's grype/syft install scripts which are well-maintained, but download and inspect first |
| Overwriting config files without diffing | Simpler distribution logic | User customizations lost; no merge strategy; frustrating experience | Only on `--force` flag; default should be non-destructive |

## Integration Gotchas

Common mistakes when connecting cross-platform install to existing repo configurations.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| pip/pipx PATH | Assuming `~/.local/bin` is on PATH on all systems | Run `pipx ensurepath` or detect and advise; verify with `command -v` after install |
| pre-commit config drop | Overwriting existing `.pre-commit-config.yaml` from M1 | Detect existing config; compare versions; merge or prompt |
| ESLint flat config | Dropping `eslint.config.mjs` into repos that use legacy `.eslintrc` format | Detect existing ESLint config format; ESLint 9+ uses flat config but older versions use legacy |
| hadolint binary | Using `brew install hadolint` (macOS-only) in cross-platform script | Download binary from GitHub Releases for both platforms |
| Gitleaks config | `.gitleaksignore` dropped by distribution but user already has fingerprints | Append new entries, do not replace; use unique-line deduplication |
| npm audit hook | Enabling npm-audit hook on repos without `package-lock.json` | Hook already has `files: package-lock\.json$` -- ensure this pattern is preserved in distribution config |
| Shell profile modification | Appending to `~/.bashrc` when user's default shell is zsh | Detect `$SHELL` and modify the correct profile file (`~/.zshrc`, `~/.bashrc`, `~/.profile`) |
| Terraform hook | Enabling terraform hooks on repos without `.tf` files | Use `types: [terraform]` in pre-commit config so hooks auto-skip |

## Performance Traps

Patterns that work initially but degrade over time.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Installing all tools globally (system-wide) | Version conflicts between repos needing different tool versions; one repo's update breaks another | Use pipx for Python tools (per-tool venvs); use project-scoped npm installs; binaries in project-local directory | When 2+ repos need different versions of the same tool |
| pre-commit cache growth | `~/.cache/pre-commit` grows unbounded as hook versions change | Run `pre-commit gc` periodically; run `pre-commit clean` after major version bumps | After 6+ months of version updates across multiple repos |
| GitHub API rate limiting in install script | `curl https://api.github.com/repos/.../releases/latest` returns 403 | Cache API responses; provide offline fallback version list; authenticate API requests if available | After ~60 unauthenticated requests per hour (shared across all API calls from the IP) |
| Download-on-first-commit latency | First commit after setup takes 30+ seconds as pre-commit downloads hook environments | Run `pre-commit install-hooks` during setup, not on first commit | Immediately on first use if hooks are not pre-downloaded |

## Security Mistakes

Domain-specific security issues for a security tool installer.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Downloading binaries without checksum verification | MITM or compromised CDN delivers malicious binary; ironic for a security tool installer | Verify SHA256 checksums for every binary download; use tool-provided install scripts where available |
| Using `curl \| sh` pattern | Script content not audited; could be modified between releases | Download script to file, inspect, then execute; or use tool-specific package manager |
| Storing tool versions in the script itself | No audit trail of version changes; harder to update programmatically | Use a separate versions manifest file (JSON/YAML); the script reads from it |
| Not verifying downloaded binary architecture | `exec format error` at runtime; on macOS with Rosetta, wrong-arch binary runs slowly under emulation without error | Check `file <binary>` output matches expected architecture |
| Running install script as root/sudo unnecessarily | Tools installed system-wide; any tool compromise affects all users | Install to user-local directories (`~/.local/bin`, pipx); only use sudo for system prerequisites if absolutely necessary |

## UX Pitfalls

Common user experience mistakes in cross-platform tool installers.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Silent failure with exit 0 | User thinks install succeeded but tools are not functional | Verify every tool is callable after install; print summary with pass/fail per tool |
| No progress indication during long downloads | User thinks script is hung and kills it | Print what is being downloaded and show progress (`curl --progress-bar`) |
| Modifying shell profile without telling user | User confused by PATH changes they did not make | Print exactly what was added to which file; let user review |
| Error messages without remediation steps | User cannot fix the problem without researching it | Every error message should include "To fix this: [specific command]" |
| Requiring terminal restart without saying so | Tools not found despite successful install | Print "Restart your terminal or run: source ~/.bashrc" |
| One-size-fits-all config for all repos | Terraform hooks fail on Node-only repos; ESLint hooks fail on Python-only repos | Generate config based on detected languages, or use file-pattern matching so inapplicable hooks auto-skip |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Install script:** All tools install successfully -- verify tools are on PATH in a NEW terminal session (not the install session)
- [ ] **Architecture detection:** Script works on your macOS -- verify it also handles Linux arm64 (`aarch64` from `uname -m`, not `arm64`)
- [ ] **pip tools installed:** pip install exits 0 -- verify on a PEP 668 system (Ubuntu 24.04, macOS 14+) without `--break-system-packages`
- [ ] **Shell compatibility:** Script works on your machine -- verify with `/bin/bash` on macOS (bash 3.2), not Homebrew bash
- [ ] **Idempotency:** Script works on first run -- verify second run produces no errors, no duplicate PATH entries, no config overwrites
- [ ] **Config distribution:** Configs dropped into repo -- verify repos with existing configs are not silently overwritten
- [ ] **pre-commit hooks:** `pre-commit run --all-files` passes -- verify in a repo with ONLY Python files (no JS/TS) that ESLint hook skips cleanly
- [ ] **Version check:** `--check-updates` works -- verify GitHub API rate limit handling (unauthenticated limit is 60/hour)
- [ ] **Checksum verification:** Binary downloads succeed -- verify checksums are actually checked (not just downloaded and ignored)
- [ ] **hadolint install:** Tool is available -- verify it was NOT installed via Homebrew (must use binary download for cross-platform)

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| PEP 668 breaking pip installs | LOW | Switch to pipx; uninstall pip-installed tools with `pip uninstall`; reinstall via pipx |
| Bash 3.2 script failure on macOS | MEDIUM | Rewrite affected sections to bash 3.2 / POSIX sh compatibility; re-test on stock macOS |
| Wrong architecture binary downloaded | LOW | Delete the binary; fix the architecture mapping; re-download correct binary |
| PATH not configured after install | LOW | Run `pipx ensurepath`; add appropriate directory to shell profile; source profile |
| Config overwritten on re-run | MEDIUM | Restore from git (`git checkout -- .pre-commit-config.yaml`); add idempotency checks to script |
| Hook version conflict with existing repo | LOW | Run `pre-commit clean`; pin to the version that works for the specific repo; document the deviation |
| GNU command failure on macOS | LOW | Replace with portable equivalent; test on macOS before release |
| No checksum verification discovered post-deploy | MEDIUM | Re-download all binaries with verification; compare checksums of existing installs against known-good values |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| PEP 668 pip failures | Phase 1 (Install Script) | Run install script on Ubuntu 24.04 and macOS 14+ -- no `--break-system-packages` used |
| Bash 3.2 compatibility | Phase 1 (Install Script) | Run install script with `/bin/bash` on macOS; confirm bash version is 3.2.x |
| Architecture naming | Phase 1 (Install Script) | Test all 4 OS/arch combos; `file` command on each downloaded binary confirms correct arch |
| PATH issues | Phase 1 (Install Script) | Open new terminal after install; `command -v pre-commit semgrep checkov` all succeed |
| Non-idempotent installer | Phase 2 (Distribution Package) | Run setup script twice; second run produces zero errors and zero duplicate entries |
| Pre-commit version conflicts | Phase 2 (Distribution Package) | Apply distribution to repo with existing `.pre-commit-config.yaml`; user customizations preserved |
| GNU vs BSD commands | Phase 1 (Install Script) | ShellCheck passes; script runs on macOS with BSD utilities |
| No checksum verification | Phase 1 (Install Script) | Tamper with a downloaded binary; verification step catches it |
| No update mechanism | Phase 1 (Install Script) | Run `--check-updates`; outdated tools correctly identified |
| System hook dependencies | Phase 2 (Distribution Package) | `pre-commit run --all-files` in Python-only repo skips JS hooks cleanly |
| Semgrep install time | Phase 1 (Install Script) | Install completes in reasonable time; user sees progress feedback |

## Sources

- [PEP 668: Marking Python base environments as externally managed](https://peps.python.org/pep-0668/) -- HIGH confidence (Python PEP, authoritative)
- [Semgrep: error: externally-managed-environment](https://semgrep.dev/docs/kb/semgrep-appsec-platform/error-externally-managed-environment) -- HIGH confidence (official Semgrep docs)
- [Python Packaging User Guide: Installing Packages](https://packaging.python.org/tutorials/installing-packages/) -- HIGH confidence (official Python docs)
- [pip install --user should check PATH](https://github.com/pypa/pip/issues/3813) -- HIGH confidence (official pip issue tracker)
- [Bash portability issues](https://tldp.org/LDP/abs/html/portabilityissues.html) -- MEDIUM confidence (community reference)
- [macOS ships bash 3.2 due to GPLv3](https://www.quora.com/Why-does-MacOS-come-with-Bash-version-3-instead-of-Bash-version-4) -- HIGH confidence (well-known fact, verified)
- [How to write idempotent bash scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) -- MEDIUM confidence (community best practice)
- [Nix installer idempotency issues](https://github.com/NixOS/nix/issues/12156) -- MEDIUM confidence (demonstrates real-world idempotency bugs)
- [Trivy installation](https://trivy.dev/docs/latest/getting-started/installation/) -- HIGH confidence (official docs)
- [Grype GitHub repository](https://github.com/anchore/grype) -- HIGH confidence (official repo)
- [pre-commit version pinning issues](https://github.com/pre-commit/pre-commit/issues/3521) -- HIGH confidence (official issue tracker)
- [Ansible-lint pre-commit Python version pinning problem](https://reinout.vanrees.org/weblog/2025/11/19/ansible-lint-pre-commit.html) -- MEDIUM confidence (community report of real issue)
- Project M1 Installation Guide: `docs/milestone-1-workstation/INSTALLATION_GUIDE.md` -- HIGH confidence (primary source)
- Project `.pre-commit-config.yaml` in `repos/security-platform/` -- HIGH confidence (primary source)
- Project `PROJECT.md` v1.1 requirements -- HIGH confidence (primary source)

---
*Pitfalls research for: cross-platform security tool distribution packaging (v1.1 milestone)*
*Researched: 2026-03-16*
