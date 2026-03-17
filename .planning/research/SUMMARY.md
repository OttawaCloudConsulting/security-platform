# Project Research Summary

**Project:** v1.1 Distribution Packaging — Cross-Platform Security Tool Installation
**Domain:** Developer tooling distribution / security scanning stack
**Researched:** 2026-03-16
**Confidence:** HIGH

## Executive Summary

This milestone converts a working but macOS-only, manually-installed security scanning stack (Milestone 1) into a distributable, cross-platform package that onboards any git repo with a single command. The project is squarely in the category of "developer tooling distribution" — comparable to how Husky distributes git hook management, Mrm distributes config files, and Homebrew distributes CLI tools — but uniquely combining all three concerns: CLI tool installation, config file deployment, and git hook wiring. No existing tool in this space handles all three, which is the core value proposition.

The recommended approach is a two-script architecture in bash: `install.sh` handles machine-level tool installation (run once per workstation) and `setup.sh` handles repo-level configuration (run once per git repo). Tools split naturally into two install methods: Go binaries (Trivy, Syft, Grype, Gitleaks, hadolint) installed via official curl-pipe scripts or direct binary download, and Python CLIs (pre-commit, Semgrep, Checkov) installed via `pipx`. The entire distribution lives in a `dist/` directory of the security-platform repo — no npm registry, no separate repository, no publish step. Canonical configs are standalone files in `dist/configs/` and are copied (not symlinked) to target repos.

The two critical risks are: (1) bash compatibility — macOS ships bash 3.2 permanently due to GPLv3 licensing and the install script must be written to that constraint from line one, and (2) Python environment fragmentation — PEP 668, now enforced on all modern Linux distributions and macOS 14+, blocks bare `pip install`. Both risks have clear mitigations (bash 3.2-compatible syntax everywhere; pipx for all Python CLI tools) and must be treated as hard requirements, not afterthoughts.

## Key Findings

### Recommended Stack

The distribution mechanism is a standalone bash script — not npx, not pip package, not Makefile. Bash and curl are the only prerequisites, present on all macOS and Linux systems without any bootstrapping. Python tools (pre-commit, Semgrep, Checkov) are installed via `pipx`, which creates isolated virtual environments per tool, resolves PEP 668 conflicts, and avoids dependency collisions between Semgrep and Checkov's large overlapping dep trees. Go binaries (Trivy, Syft, Grype, Gitleaks) have official curl-pipe install scripts that handle OS/arch detection and checksum verification. hadolint (Haskell binary) requires direct binary download from GitHub Releases with per-platform URL construction.

**Core technologies:**
- **Bash 3.2** — install script language — universal on macOS and Linux; script must not use bash 4+ features (macOS ships 3.2 permanently due to GPLv3 licensing)
- **curl** — HTTP downloads — present on all target platforms; preferred over wget (macOS ships curl, not wget by default)
- **pipx 1.7+** — Python CLI isolation — resolves PEP 668 "externally-managed-environment"; prevents dep conflicts between Semgrep and Checkov
- **Official curl-pipe scripts** — Go binary installation — Trivy, Syft, Grype, Gitleaks all provide these with checksum verification built in
- **Direct binary download** — hadolint installation — no install script upstream; must construct platform-specific URL from GitHub Releases
- **shasum / sha256sum** — checksum verification — macOS uses `shasum -a 256`; Linux uses `sha256sum`; install script must handle both

**Critical version constraint:** Grype >= 0.88.0 is mandatory. DB schema v5 reached EOL on 2026-03-06. Any older version cannot use the current vulnerability database.

### Expected Features

The distribution must match the UX standard set by comparable tools (Husky: `npx husky init`, pre-commit: `pre-commit install`, Mrm: `npx mrm <task>`). Users expect a single command that goes from zero to working with no manual steps remaining.

**Must have (table stakes for v1.1):**
- Single-command setup — orchestrates tool install + config deployment + hook wiring in one invocation
- macOS + Linux cross-platform support — OS/arch detection with conditional install paths per tool
- Idempotent execution — safe to re-run; skip-if-already-installed; no duplicate PATH entries
- Config file dropping — `.pre-commit-config.yaml`, `.markdownlint.json`, `.markdownlintignore`, `.gitleaksignore` deployed to target repo
- Version pinning — explicit versions in manifest; reproducible across machines
- Git hook wiring — `pre-commit install` + `pre-commit install --hook-type pre-push` called automatically
- Clear error messages — every failure includes a "To fix this:" remediation step

**Should have (v1.x after validation):**
- Version check / update command — cross-tool update orchestrator; no equivalent exists in the ecosystem
- Health check (doctor) command — verify all tools installed, correct versions, hooks wired
- Checksum verification for binary downloads — security differentiator appropriate for a security tool installer
- Dry-run mode — show planned actions without modifying anything

**Defer to v2+:**
- Project-scoped virtualenvs for pip tools — single developer has no version conflict risk between repos yet
- CI integration of install script — belongs in M2 (CI/CD milestone), not M1.1
- Windows support — out of scope; WSL is the documented path

**Anti-features to avoid:**
- Centralized remote config (single source of truth YAML) — pre-commit maintainers explicitly warn against this; a linter behavior change breaks every repo simultaneously
- Auto-update on every commit — network dependency in a git hook violates offline-first principle
- Interactive setup wizard — breaks automation and CI usage; use opinionated defaults instead

### Architecture Approach

v1.1 adds a distribution layer between the security-platform repo (canonical source) and target repos. The key structural decision is two scripts rather than one: `install.sh` is a machine-level concern (once per workstation), `setup.sh` is a per-repo concern (once per git repo). This separation means a developer can re-deploy configs without reinstalling tools, and can update tools without re-deploying configs. All canonical configs live in `dist/configs/` as standalone files — not embedded in scripts as heredocs — so they are independently reviewable and diffable in version control.

**Major components:**
1. `dist/install.sh` — machine-level tool installer; OS/arch detection; installs via pipx (Python tools) and binary download (Go/Haskell tools); version checking; PATH verification
2. `dist/setup.sh` — per-repo bootstrapper; verifies git repo; copies configs; activates pre-commit hooks; runs validation
3. `dist/configs/` — canonical config files; single source of truth; identical copies deployed to all target repos
4. `.pre-commit-config.yaml` — universal config with `files:` / `types:` filters enabling language-aware hook execution across polyglot repos

**Key architectural patterns:**
- **Config-as-copy, not config-as-link** — symlinks break when security-platform is not cloned; copies make target repos self-contained
- **File-type filters for language-aware execution** — one universal config serves all repos; hooks auto-skip on repos with no matching files; a Terraform-only repo never triggers ESLint
- **Idempotent installation** — every step checks preconditions; running twice produces no errors and no side effects
- **Curl-pipe with local fallback** — `bash <(curl -sL ...)` for convenience; `bash dist/install.sh` for auditability

### Critical Pitfalls

1. **PEP 668 breaks bare `pip install`** — Enforced on all modern Linux distributions (Debian 12+, Ubuntu 23.04+) and macOS 14+. Use `pipx` for all Python CLI tools. Never use `--break-system-packages` in an automated installer. Must be decided before writing any install logic.

2. **Bash 3.2 incompatibility silently breaks macOS** — macOS ships bash 3.2 permanently (GPLv3 licensing). Do not use: `declare -A` (associative arrays), `${var,,}` (lowercase expansion), `mapfile`/`readarray`, `|&` (pipe stderr), `&>`. Use `tr` for case, `while IFS= read -r` loops, `2>&1 |` for stderr. Run ShellCheck and test on stock macOS `/bin/bash` before release.

3. **Architecture naming inconsistency across tools** — `uname -m` returns `arm64` on macOS ARM but `aarch64` on Linux ARM. Each tool's GitHub release naming differs (Trivy: `macOS-ARM64`; Grype: `darwin_arm64`). Build a per-tool normalization lookup table; test all four OS/arch combinations.

4. **`~/.local/bin` not on PATH after pipx install** — pip `--user` installs to `~/Library/Python/3.x/bin/` on macOS, not `~/.local/bin`. Run `pipx ensurepath`. Verify with `command -v <tool>` in a NEW terminal session, not the install session.

5. **Non-idempotent installer corrupts config on re-run** — Appending to shell profiles creates duplicate PATH entries; overwriting `.gitleaksignore` loses user-added fingerprints. Use marker comments to detect prior PATH additions. Default to non-destructive for user-customizable files; use `--force` for intentional overwrites.

6. **GNU vs BSD command differences** — `sed -i` requires `sed -i ''` on macOS BSD; `grep -P` (Perl regex) does not exist on macOS; `readlink -f` does not exist on macOS. Use `sed -i'' -e`, `grep -E`, and portable shell function substitutes.

7. **Binary downloads without checksum verification** — Ironic failure mode for a security tool installer. All four Go tools (Trivy, Syft, Grype, Gitleaks) provide checksums in GitHub releases. Use Anchore's official install scripts for Grype and Syft — they include verification. Never pin to `latest`; pin to explicit versions.

## Implications for Roadmap

The architecture research explicitly defines a dependency-driven build order. This maps cleanly to four phases, with the critical-path pitfall cluster concentrated in Phase 1.

### Phase 1: Cross-Platform Install Script (`install.sh`)

**Rationale:** No dependencies on other components. This is the foundation that validates whether cross-platform installation methods actually work. All subsequent work depends on tools being installable. Seven of the eleven identified pitfalls are concentrated here and must be resolved before any other work proceeds.

**Delivers:** A single script that installs all 8 security CLI tools (pre-commit, Semgrep, Checkov via pipx; Trivy, Syft, Grype, Gitleaks, hadolint via binary download) on macOS arm64 + x86_64 and Linux x86_64. Includes `--check` subcommand for version reporting.

**Features addressed:** Cross-platform install, version pinning manifest, clear error messages, idempotent execution (tool install portion)

**Pitfalls to avoid:** PEP 668 / pipx migration, bash 3.2 compatibility, architecture naming normalization, PATH verification, GNU/BSD command differences, checksum verification, Semgrep install time (warn user, show progress)

### Phase 2: File-Pattern Hook Updates (`.pre-commit-config.yaml`)

**Rationale:** Depends on Phase 1 (tools must be installable to validate hooks). This is a targeted modification to an existing file — lower risk than the new scripts. Must be finalized before `setup.sh` is written, because `setup.sh` deploys the finalized config.

**Delivers:** An updated `.pre-commit-config.yaml` where every hook has correct `files:` / `types:` filters so hooks auto-skip on repos with no matching files. Validated on Python-only, Terraform-only, and mixed repos.

**Features addressed:** File-pattern selective hook execution, single universal config across diverse repos

**Pitfalls to avoid:** Local hooks with `language: system` failing when tool not installed; ESLint firing on Python-only repos; Terraform hooks firing on Node-only repos

### Phase 3: Repo Bootstrapper (`setup.sh`)

**Rationale:** Depends on Phase 1 (must verify tools exist) and Phase 2 (must deploy the finalized config). Writing it last means the inputs are stable. Contains the config-deployment idempotency logic for repos already configured via M1 manual setup.

**Delivers:** A script that copies config files from `dist/configs/` into a target repo, activates pre-commit hooks, runs `pre-commit run --all-files` as validation, and reports results. Non-destructive by default for user-customizable files (`.gitleaksignore`, `.markdownlintignore`).

**Features addressed:** Config file dropping, git hook wiring, single-command setup (combined with Phase 1), idempotent execution (config deployment portion)

**Pitfalls to avoid:** Non-idempotent config deployment, pre-commit hook version conflicts with existing M1-configured repos, overwriting user `.gitleaksignore` fingerprints

### Phase 4: Integration Validation

**Rationale:** The end-to-end acceptance test. Cannot run until Phases 1-3 are complete. Validates the "looks done but isn't" checklist from PITFALLS.md.

**Delivers:** Verified end-to-end proof that a fresh machine + fresh repo can be onboarded with two commands. Updated Installation Guide referencing `install.sh` as primary method. Updated Developer Guide "Rolling Out" section referencing `setup.sh`.

**Validates:** Fresh macOS arm64 install, PATH visible in new terminal, second run of install.sh produces no errors, second run of setup.sh produces no errors, `pre-commit run --all-files` in a Python-only repo skips ESLint cleanly, `--check` version reporting works

### Phase Ordering Rationale

- `install.sh` first because it is the most complex component, has the highest pitfall density (7/11 pitfalls), and is the critical path dependency for everything else. It also empirically validates that the chosen cross-platform installation methods actually work before `setup.sh` is built to depend on them.
- Hook config updates second because they depend on tools being available (Phase 1) but are a config modification, not new code — lower risk, good to finalize before `setup.sh` is written so the inputs to Phase 3 are stable.
- `setup.sh` third because it is the integrator — depends on both tools (Phase 1) and configs (Phase 2) as stable inputs.
- Integration validation last because it is the acceptance test for the whole system. Running it before the components are finalized generates noise, not signal.

### Research Flags

Phases needing extra care during planning and implementation:

- **Phase 1 (install.sh):** High complexity, many cross-platform edge cases. ShellCheck is mandatory. Testing on stock macOS bash 3.2 is mandatory before marking done. The architecture normalization lookup table needs to be built and verified for all 4 OS/arch combinations before binary download code is written. Two design decisions must be made explicitly upfront: (1) whether Semgrep belongs in the local install or is CI-only, (2) GitHub API rate limit strategy for `--check-updates`.
- **Phase 3 (setup.sh):** Idempotency logic for existing repos (M1-configured) has nuanced behavior decisions: which files to overwrite, which to preserve, how to handle version drift. Document the behavior contract explicitly before implementation.

Phases with standard patterns (no additional research needed):

- **Phase 2 (hook config updates):** pre-commit `files:` and `types:` filter syntax is well-documented. The M1 config already uses some filters; this is incremental improvement.
- **Phase 4 (integration validation):** Standard end-to-end testing — no novel patterns needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All install methods verified against official docs. pipx is the officially recommended pattern for Python CLI tools. Go binary install scripts are provided by upstream maintainers. Grype DB v5 EOL date confirmed. |
| Features | HIGH | Competitor analysis grounded in real tools (Husky, Mrm, pre-commit, Lefthook). Feature gaps clearly identified. MVP scope well-defined against v1.1 PROJECT.md requirements. |
| Architecture | HIGH | Two-script architecture is straightforward and directly supported by research. Config-as-copy tradeoffs are well-understood. Existing M1 architecture is validated in production across one repo. |
| Pitfalls | HIGH | All critical pitfalls verified against official sources (PEP 668 from python.org, bash 3.2 from Apple docs, GNU/BSD from community reference). Grounded in the existing M1 install guide as primary source. |

**Overall confidence:** HIGH

### Gaps to Address

- **hadolint binary checksum verification:** hadolint does not provide a standard `checksums.txt` in releases. Need to determine during Phase 1 implementation what checksum artifact is available (if any) and whether `file <binary>` architecture verification is the best available option.
- **Semgrep placement decision (local vs CI-only):** PITFALLS.md notes that Semgrep runs at the PR gate in GitHub Actions (M2), not as a pre-commit hook. The decision of whether Semgrep belongs in the local `install.sh` at all must be made explicitly before Phase 1 implementation. This materially affects install time (Semgrep is 2-5 minutes) and script complexity.
- **GitHub API rate limiting for `--check-updates`:** Unauthenticated rate limit is 60 requests/hour shared across all API calls from the IP. For a `--check` command querying 8 tools, this could hit limits. Decide: hardcoded version manifest + manual update vs. live API query with rate limit handling.

## Sources

### Primary (HIGH confidence)

- [Trivy Installation Docs](https://trivy.dev/docs/latest/getting-started/installation/) — official install script method, version pinning
- [Grype Installation](https://oss.anchore.com/docs/installation/grype/) — curl install script, DB schema v5 EOL 2026-03-06
- [Syft Installation](https://oss.anchore.com/docs/installation/syft/) — curl install script
- [Gitleaks GitHub](https://github.com/gitleaks/gitleaks) — binary releases, install script path
- [hadolint GitHub](https://github.com/hadolint/hadolint) — binary download only, no install script available
- [Checkov Installation](https://www.checkov.io/2.Basics/Installing%20Checkov.html) — pip/pipx install confirmed
- [Semgrep PyPI](https://pypi.org/project/semgrep/) — pip/pipx install, v1.155.0 current
- [PEP 668](https://peps.python.org/pep-0668/) — externally-managed-environment enforcement (authoritative)
- [Semgrep: externally-managed-environment](https://semgrep.dev/docs/kb/semgrep-appsec-platform/error-externally-managed-environment) — official Semgrep docs
- [pipx GitHub](https://github.com/pypa/pipx) — isolation benefits, ensurepath behavior
- [pre-commit docs](https://pre-commit.com/) — hook environment isolation, file-type filters
- Project M1 Installation Guide: `docs/milestone-1-workstation/INSTALLATION_GUIDE.md` — primary source for current install state and known issues

### Secondary (MEDIUM confidence)

- [Bash portability issues](https://tldp.org/LDP/abs/html/portabilityissues.html) — bash 3.2 compatibility patterns
- [How to write idempotent bash scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) — idempotency patterns for shell installers
- [pip vs pipx Guide](https://betterstack.com/community/guides/scaling-python/pip-vs-pipx/) — best practices for CLI tool distribution
- [Lefthook vs Husky comparison](https://dev.to/quave/lefthook-benefits-vs-husky-and-how-to-use-30je) — competitor feature analysis
- [pre-commit multi-repo maintenance](https://thedissonance.net/2024/03/27/pre-commit-hooks.html) — config-as-copy vs centralized patterns

---
*Research completed: 2026-03-16*
*Ready for roadmap: yes*
