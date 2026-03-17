# Feature Research

**Domain:** Cross-platform security tool distribution packaging
**Researched:** 2026-03-16
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Single-command setup | Every comparable tool (husky, pre-commit, mrm) offers `npx husky init` / `pre-commit install` / `npx mrm`. Users expect one command to go from zero to working. | MEDIUM | The command must: install CLI tools, drop config files, wire git hooks. Orchestration script that calls sub-steps. |
| macOS + Linux support | The stated project requirement. Every security CLI (Trivy, Grype, Syft) ships official install scripts for both. Users of cross-platform tools expect this. | MEDIUM | Requires OS/arch detection (`uname -s`/`uname -m`), conditional package manager selection (pip/npm/binary), and testing on both platforms. |
| Idempotent execution | Running setup twice must not break anything. Husky, pre-commit, and mrm all handle re-runs gracefully. Standard expectation for any installer. | LOW | Check-before-write pattern: skip if file exists and matches, skip if tool already at correct version. |
| Config file dropping | Mrm's core value proposition. The setup command drops `.pre-commit-config.yaml`, `.gitleaks.toml`, linter configs, etc. into the target repo. Without this, the user still has manual work. | LOW | Copy from a template directory or embed in the script. Must not overwrite user customizations (see anti-features). |
| Version pinning | pre-commit pins hook versions in YAML. Trivy/Grype install scripts accept version args. Users expect reproducible environments where tool versions are explicit. | LOW | Store desired versions in a manifest file (JSON/YAML). Install script reads versions from manifest rather than hardcoding. |
| Git hook wiring | Husky wires hooks via `.husky/` directory + `core.hooksPath`. pre-commit wires via `pre-commit install`. The distribution must wire hooks so they actually fire on commit/push. | LOW | Already solved: `pre-commit install` + `pre-commit install --hook-type pre-push`. Just needs to be called as part of setup. Depends on: pre-commit framework installed. |
| Clear error messages | When a tool fails to install (missing dependency, network error, wrong arch), the user needs actionable errors, not silent failures or cryptic exits. | LOW | `set -euo pipefail`, trap handlers, explicit error messages with remediation hints. |
| Uninstall / clean removal | Husky documents removal. pre-commit has `uninstall`. Users expect to be able to cleanly remove what was added. | LOW | Remove hooks, remove dropped config files, optionally remove installed binaries. Inverse of setup. |

### Differentiators (Competitive Advantage)

Features that set the product apart from generic setup tools. Not required, but valuable for a security-focused distribution.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Version check and update command | Most install scripts are fire-and-forget. A `security-tools update` command that checks installed versions against desired versions and upgrades selectively is uncommon. Trivy/Grype have `--download-db-only` but no cross-tool update orchestrator exists. | MEDIUM | Compare installed version (`tool --version`) against manifest. Download new binary/package only when outdated. Depends on: version pinning manifest. |
| File-pattern-based selective hook execution | pre-commit supports `types` and `files` filters, but most shared configs use broad patterns. Shipping configs where hooks only fire on relevant file types (ShellCheck only on `.sh`, Ruff only on `.py`, etc.) reduces noise and speeds up commits for polyglot repos. | LOW | Already partially done in M1. Needs to be complete and consistent across all hooks in the distribution config. |
| Checksum verification for binary downloads | Most install-via-curl patterns skip verification. Verifying SHA-256 checksums for Trivy/Grype/Syft/Gitleaks binaries before installing is a security differentiator appropriate for a security tool distribution. | MEDIUM | Download checksum file from GitHub release alongside binary. Verify with `sha256sum` / `shasum -a 256`. Fail loudly on mismatch. |
| Project-scoped tool installation | System-wide installs (e.g., `brew install trivy`) create version conflicts across projects. Where possible (pip tools: Semgrep, Checkov, Ruff), installing into a project-local virtualenv avoids this. | MEDIUM | Create `.venv` or use `pipx` for isolation. Binary tools (Trivy, Grype, Syft, Gitleaks) are inherently single-version; install to a project-local `bin/` or accept system-wide. |
| Dry-run mode | Show what would be installed/changed without doing it. Mrm does not have this. Gives users confidence before modifying their repo. | LOW | Run all detection and version checks, print planned actions, exit without modifying. |
| Health check command | After setup, run `security-tools doctor` to verify all tools are installed, correct versions, hooks are wired, configs are present. Similar to `brew doctor`. | LOW | Iterate through expected tools and configs, check presence and version, report pass/fail for each. Depends on: version pinning manifest. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems in this context.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Centralized remote config (single source of truth YAML) | Keeps all repos in sync automatically. `centralized-pre-commit-conf` exists for this. | pre-commit maintainers explicitly reject mutable remote configs because a linter behavior change breaks every repo's main branch simultaneously. Debugging is nightmare. See pre-commit issue #2337. | Drop config files into each repo (decentralized). Update via re-running the setup command or a dedicated update command. Each repo can diverge if needed. |
| Auto-update on every commit | Automatically check for new tool versions before each commit. | Adds latency to every commit. Network dependency in a git hook is fragile and violates offline-first principle. | Explicit `security-tools update` command run manually or via cron. |
| Windows support | Completeness. | Out of scope per project constraints (single developer, macOS + Linux). WSL exists for Windows users. Adding Windows support triples testing surface for near-zero benefit. | Document WSL as the path for Windows. Do not add `.bat`/PowerShell scripts. |
| Interactive setup wizard | Guide user through options with prompts. | Single developer, 6 repos. Interactive prompts slow down automation and break CI usage. Mrm's original interactive mode was its weakest feature. | Opinionated defaults with override via env vars or a config file. No prompts. |
| Hook bypass prevention (blocking `--no-verify`) | Prevent developers from skipping hooks. | Single-developer project. The developer IS the policy authority. Blocking bypass is hostile UX. CI is the compensating control (per ADR-011). | Warn on bypass (already in ADR-011). CI enforces what hooks cannot. |
| Container-based tool isolation (devcontainer) | Guarantees identical environments. | Massive overhead for 6 CLI tools. Requires Docker running. Adds startup latency. Overkill for a single developer installing well-known binaries. | Direct binary/pip/npm installation with version pinning. Reserve devcontainers for complex multi-service development, not CLI tool distribution. |

## Feature Dependencies

```
[Version pinning manifest]
    |
    +--requires--> [Single-command setup]
    |                  |
    |                  +--installs--> [CLI tool installation (cross-platform)]
    |                  |                  |
    |                  |                  +--enhanced-by--> [Checksum verification]
    |                  |                  +--enhanced-by--> [Project-scoped installation]
    |                  |
    |                  +--drops--> [Config file dropping]
    |                  |               |
    |                  |               +--includes--> [File-pattern selective hooks]
    |                  |
    |                  +--wires--> [Git hook wiring]
    |
    +--enables--> [Version check and update command]
    +--enables--> [Health check / doctor command]

[Uninstall command] <--inverse-of-- [Single-command setup]

[Dry-run mode] --enhances--> [Single-command setup]
```

### Dependency Notes

- **Version check/update requires version pinning manifest:** Cannot compare versions without knowing what versions are desired. The manifest is the foundational data structure.
- **Checksum verification enhances CLI tool installation:** Only relevant for binary downloads (Trivy, Grype, Syft, Gitleaks). Pip/npm tools are verified by their package managers.
- **Config file dropping includes file-pattern hooks:** The dropped `.pre-commit-config.yaml` must already contain the correct `files:` and `types:` patterns. This is a content concern, not a separate installation step.
- **Uninstall is inverse of setup:** Must track what was installed/dropped to cleanly remove it. Simpler if setup writes a manifest of what it did.

## MVP Definition

### Launch With (v1.1)

Minimum viable distribution package -- what's needed to onboard the remaining 4+ repos.

- [ ] **Version pinning manifest** -- single source of truth for tool names, versions, install methods
- [ ] **Cross-platform install script (macOS + Linux)** -- OS/arch detection, pip/npm/binary download per tool
- [ ] **Config file dropping** -- copy `.pre-commit-config.yaml` and linter configs into target repo
- [ ] **File-pattern selective hook execution** -- complete, consistent `files:`/`types:` patterns across all hooks
- [ ] **Git hook wiring** -- `pre-commit install` + pre-push hook setup
- [ ] **Idempotent execution** -- safe to re-run without breaking existing setup
- [ ] **Clear error messages** -- actionable failures, not silent exits

### Add After Validation (v1.x)

Features to add once the core distribution is working across all repos.

- [ ] **Version check and update command** -- trigger: first time a tool version needs bumping across repos
- [ ] **Health check / doctor command** -- trigger: debugging why hooks aren't firing in a repo
- [ ] **Checksum verification for binary downloads** -- trigger: security hardening pass
- [ ] **Dry-run mode** -- trigger: when onboarding becomes less familiar (new repos, new contributors)
- [ ] **Uninstall command** -- trigger: when any repo needs to cleanly remove the security stack

### Future Consideration (v2+)

Features to defer until the distribution is mature.

- [ ] **Project-scoped virtualenv for pip tools** -- defer because single developer has no version conflict risk yet; system-wide pip installs are simpler for now
- [ ] **CI integration of the install script** -- defer to M2 (CI/CD milestone) where GitHub Actions will install tools independently

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Cross-platform install script | HIGH | MEDIUM | P1 |
| Config file dropping | HIGH | LOW | P1 |
| File-pattern selective hooks | HIGH | LOW | P1 |
| Git hook wiring | HIGH | LOW | P1 |
| Version pinning manifest | HIGH | LOW | P1 |
| Idempotent execution | HIGH | LOW | P1 |
| Clear error messages | MEDIUM | LOW | P1 |
| Version check/update command | MEDIUM | MEDIUM | P2 |
| Health check / doctor | MEDIUM | LOW | P2 |
| Checksum verification | MEDIUM | MEDIUM | P2 |
| Dry-run mode | LOW | LOW | P2 |
| Uninstall command | LOW | LOW | P3 |
| Project-scoped install | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for v1.1 launch (enables repo onboarding)
- P2: Should have, add when possible (improves maintenance experience)
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Husky + lint-staged | pre-commit framework | Mrm | Lefthook | Our Approach |
|---------|--------------------|--------------------|-----|----------|--------------|
| Single-command setup | `npx husky init` | `pre-commit install` | `npx mrm <task>` | `lefthook install` | `bash setup.sh` (orchestrates all sub-steps) |
| Language scope | JS/TS only | Polyglot (any language) | JS ecosystem configs | Polyglot | Polyglot (8 languages via pre-commit) |
| Config dropping | `.husky/` dir only | `.pre-commit-config.yaml` only | Any config file (ESLint, Prettier, etc.) | `lefthook.yml` only | All security configs + linter configs |
| Tool installation | Does not install linters | Manages hook tool envs automatically | Does not install tools | Does not install tools | Installs 6 security CLIs + linters |
| Cross-platform | Node.js required | Python required | Node.js required | Go binary, no runtime needed | Bash script, uses pip/npm/binary as needed |
| Version management | npm/package.json | Hook versions in YAML | npm | YAML config | Version manifest file |
| Selective execution | lint-staged runs on staged files | `files:`/`types:` patterns | N/A | `glob:` patterns | pre-commit `files:`/`types:` patterns |
| Idempotent | Yes | Yes | Yes (codemod approach) | Yes | Yes (check-before-write) |

**Key insight:** No existing tool combines security CLI installation + config dropping + hook wiring. Husky/Lefthook manage hooks but don't install tools. Mrm drops configs but doesn't install tools. pre-commit manages hook execution environments but doesn't install standalone CLIs. Our distribution fills the gap by orchestrating all three concerns in one command.

## Sources

- [Husky - Get Started](https://typicode.github.io/husky/get-started.html)
- [lint-staged GitHub](https://github.com/lint-staged/lint-staged)
- [Mrm - Codemods for project config files](https://mrm.js.org/)
- [pre-commit framework](https://pre-commit.com/)
- [centralized-pre-commit-conf PyPI](https://pypi.org/project/centralized-pre-commit-conf/)
- [pre-commit issue #2337 - Remote config inclusion](https://github.com/pre-commit/pre-commit/issues/2337)
- [Lefthook vs Husky comparison](https://dev.to/quave/lefthook-benefits-vs-husky-and-how-to-use-30je)
- [Trivy installation docs](https://trivy.dev/docs/latest/getting-started/installation/)
- [checksum.sh - Verify install scripts](https://checksum.sh/)
- [DevContainers specification](https://containers.dev/)
- [Git hooks management with pre-commit and lefthook](https://0xdc.me/blog/git-hooks-management-with-pre-commit-and-lefthook/)

---
*Feature research for: cross-platform security tool distribution packaging*
*Researched: 2026-03-16*
