# Phase 10: Cross-Platform Install Script - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

A single bash script (`dist/install.sh`) that installs all security CLI tools on macOS and Linux without Homebrew. Reads pinned versions from a manifest file. Supports macOS arm64/x86_64 and Linux x86_64. The setup script (Phase 12) and maintenance commands (Phase 13) are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Tool list
- 6 tools, NOT 8: pre-commit (pipx), Trivy, Syft, Grype, Gitleaks, hadolint (binary download)
- Semgrep is CI-only (GitHub Actions in M2) -- excluded from local install to reduce install time
- Checkov is CI-only (GitHub Actions in M2) -- excluded from local install for the same reason
- pre-commit is the only Python/pipx tool remaining
- Success criteria in ROADMAP.md must be updated to reflect 6 tools

### Python tool installation
- pre-commit installs via pipx for PEP 668 compliance and dependency isolation
- install.sh bootstraps pipx automatically if not found (pip install --user pipx)
- No other Python tools in local install

### Binary tool installation
- All 5 binary tools (Trivy, Syft, Grype, Gitleaks, hadolint) install to ~/.local/bin
- Use official install scripts for Trivy, Syft, Grype, Gitleaks where available
- Direct binary download for hadolint (no upstream install script)
- OS/arch auto-detection for all binary downloads

### Install location and PATH
- All tools install to ~/.local/bin (both pipx tools and binaries)
- PATH handling: run `pipx ensurepath` which handles ~/.local/bin PATH addition
- No manual shell profile modification by the script
- Post-install verification: check all tool locations are on PATH, warn if missing

### Script UX and output
- Default output: minimal -- errors only (stderr)
- Support -v/--verbose flag for step-by-step progress and tool output during debugging
- No color output -- plain text only for maximum portability
- End-of-run summary: version table showing all tools with installed version and status (installed/skipped/failed)

### Version manifest
- Separate .env-style file (dist/versions.conf) with KEY=VALUE pairs, sourced by install.sh
- Contains versions AND URL templates per tool
- URL templates use placeholders: {VERSION}, {OS}, {ARCH} -- script substitutes at runtime
- One line per tool for version, one line per tool for URL template
- Compact format -- not full URLs per OS/arch combination

### Claude's Discretion
- Exact pipx bootstrap method (pip install --user vs python3 -m pip)
- Architecture name normalization table (arm64 vs aarch64 across tools)
- GNU/BSD command compatibility approach (sed, shasum, readlink)
- hadolint checksum verification approach (no standard checksums.txt in releases)
- Idempotency implementation (skip-if-already-installed checks)
- Bash 3.2 compatibility patterns throughout
- Error message format and remediation hints

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Tool installation methods
- `.planning/research/SUMMARY.md` -- Research summary with recommended stack, architecture, and critical pitfalls
- `.planning/research/PITFALLS.md` -- 11 identified pitfalls with mitigations (PEP 668, bash 3.2, arch naming, etc.)
- `.planning/research/ARCHITECTURE.md` -- Two-script architecture decision and component breakdown
- `.planning/research/STACK.md` -- Per-tool installation method details and version constraints

### Project requirements
- `.planning/REQUIREMENTS.md` -- INST-01 through INST-07 requirements (note: INST-05 scope reduced to pre-commit only; Semgrep/Checkov deferred to CI)
- `.planning/ROADMAP.md` -- Phase 10 success criteria (must be updated to reflect 6 tools, not 8)

### Existing conventions
- `.planning/codebase/CONVENTIONS.md` -- Shell script conventions (set -euo pipefail, variable naming, error handling patterns)

### Blockers and concerns
- `.planning/STATE.md` -- Accumulated context section lists hadolint checksum gap and GitHub API rate limiting concern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cicd/pre-commit.sh` -- Existing shell script following project conventions (set -euo pipefail, quoting, error handling)
- `cicd/lint-markdown.sh` -- Two-pass linting script with command-existence checks (`command -v` pattern with fallback)
- `repos/security-platform/.pre-commit-config.yaml` -- Current hook config with all 8 tool versions pinned (reference for version manifest)

### Established Patterns
- Shell scripts use `set -euo pipefail` and `#!/usr/bin/env bash` shebang
- UPPERCASE for constants, lowercase for locals
- `[[ ]]` conditionals, quoted variables and command substitutions
- Status messages prefixed with `==>`, errors to stderr
- `command -v` for tool existence checks with fallback

### Integration Points
- `dist/` directory does not yet exist -- will be created as new directory
- install.sh will be consumed by setup.sh (Phase 12) for tool verification
- Version manifest (dist/versions.conf) will be consumed by --check/--update commands (Phase 13)

</code_context>

<specifics>
## Specific Ideas

- Silent by default, verbose with -v -- Unix philosophy of "no news is good news"
- Version table at end gives confirmation without cluttering the install process
- pipx ensurepath as the single PATH solution avoids shell profile management complexity
- .env-style manifest with URL templates keeps version bumps to changing two lines per tool

</specifics>

<deferred>
## Deferred Ideas

- Semgrep local installation -- deferred to M2 CI/CD milestone (or could be added to install.sh later if needed)
- Checkov local installation -- deferred to M2 CI/CD milestone
- Checksum verification for all binary downloads -- noted as "should have" in research, can add in Phase 13 or as enhancement
- Dry-run mode (--dry-run flag) -- useful but not required for MVP

</deferred>

---

*Phase: 10-cross-platform-install-script*
*Context gathered: 2026-03-17*
