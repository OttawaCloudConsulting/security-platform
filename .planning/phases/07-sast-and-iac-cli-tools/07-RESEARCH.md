# Phase 7: SAST and IaC CLI Tools - Research

**Researched:** 2026-03-16
**Domain:** CLI tool installation (pip, Homebrew), SAST and IaC security tooling
**Confidence:** HIGH

## Summary

Phase 7 installs and verifies three security CLI tools -- Semgrep CE, Checkov, and Gitleaks -- so they are on `$PATH` with version verification. This is the lightest phase yet: Checkov (v3.2.396) and Gitleaks (v8.30.0) are already installed from prior work. Only Semgrep needs fresh installation via pip.

The established Phase 6 pattern applies directly: install tool, verify `--version`, update main doc with verified version notes. No scanning, no configuration, no hook setup -- just PATH availability. Phase 8 handles actual scanning validation.

Semgrep v1.155.0 is available via both pip and Homebrew. The user decision locks pip as the installation method (consistent with Checkov as a Python tool). One environment detail: Checkov is installed under system Python 3.10 at `/Library/Frameworks/Python.framework/Versions/3.10/bin/checkov`, while the default `pip3` in `$PATH` resolves to that same system Python 3.10 pip. Semgrep should install to the same location.

**Primary recommendation:** Install Semgrep via pip, verify all three tools on PATH, update main doc with verified version notes following the Phase 6 pattern.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Semgrep**: Install via pip (`pip install semgrep --break-system-packages`) -- consistent with Checkov as a Python tool
- **Checkov**: Already installed (v3.2.396 via pip) -- document actual state, do NOT switch to Homebrew
- **Gitleaks**: Already installed (v8.30.0 via Homebrew from Phase 5) -- just verify on PATH and document
- **Version policy**: No minimum version pinning -- just verify "latest" / "current" and record whatever version is installed
- **Documentation updates**: Same pattern as Phase 6 -- add "Verified versions" notes to each tool's setup section in `development-security-stack-option-1.md`
- **Semgrep doc update**: Add verified version note to section 1 (Semgrep CE, around line 154)
- **Checkov doc update**: Add verified version note to section 2 (Checkov, around line 206)
- **Gitleaks doc update**: Add CLI verified note to section 5 (Gitleaks, around line 361) -- separate from Phase 5's hook documentation

### Claude's Discretion
- Exact format and placement of version notes (follow Phase 6 pattern)
- Whether to upgrade Checkov from 3.2.396 to latest via pip before documenting
- Order of installation/verification operations

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TOOL-04 | Semgrep CE is installed and on `$PATH` (`semgrep --version` succeeds) | Semgrep v1.155.0 available via pip; `pip install semgrep --break-system-packages` |
| TOOL-05 | Checkov is installed and on `$PATH` (`checkov --version` succeeds) | Already installed: v3.2.396 at `/Library/Frameworks/Python.framework/Versions/3.10/bin/checkov` |
| TOOL-06 | Gitleaks is installed and on `$PATH` (`gitleaks version` succeeds) | Already installed: v8.30.0 at `/opt/homebrew/bin/gitleaks` |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Install Method | Purpose | Status |
|------|---------|---------------|---------|--------|
| Semgrep CE | 1.155.0 | pip | SAST -- pattern-based static analysis | NOT installed, needs fresh install |
| Checkov | 3.2.396 | pip (system Python 3.10) | IaC scanning -- Terraform, CDK, K8s, Dockerfile | Already installed |
| Gitleaks | 8.30.0 | Homebrew | Secrets detection CLI | Already installed (Phase 5) |

### Installation Commands
```bash
# Semgrep -- fresh install (only tool that needs installation)
pip install semgrep --break-system-packages

# Checkov -- already installed, no action needed (or optional upgrade)
# pip install --upgrade checkov --break-system-packages

# Gitleaks -- already installed via Homebrew, no action needed
```

### Version Verification Commands
```bash
semgrep --version    # expect 1.155.0 or similar current version
checkov --version    # expect 3.2.396 (or upgraded version)
gitleaks version     # expect 8.30.0
```

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| pip for Semgrep | brew install semgrep | User locked pip -- consistent with Checkov |
| Keeping Checkov 3.2.396 | pip upgrade to ~3.2.500 | Claude's discretion; upgrade is low risk but not required |

## Architecture Patterns

### Established Phase Pattern (from Phase 5/6)
1. Install tool (pip or brew as appropriate)
2. Verify version on PATH via `--version` / `version` command
3. Update main doc (`docs/development-security-stack-option-1.md`) with actual installed versions
4. No scanning or integration -- just availability on PATH

### Documentation Update Locations
The main doc already has setup sections for all three tools. Version notes go inline:
- **Semgrep**: section 1, lines ~168-189 (after install commands in the setup code block)
- **Checkov**: section 2, lines ~214-240 (after install commands in the setup code block)
- **Gitleaks**: section 5, lines ~367-381 (after install commands in the setup code block)

Follow the Phase 6 pattern -- add a comment line like:
```bash
# Verified: v1.155.0 (2026-03-16)
```

### Anti-Patterns to Avoid
- **Running scans during this phase:** Phase 7 is install-only. Scanning validation is Phase 8 (TOOL-07, TOOL-08).
- **Switching Checkov to Homebrew:** User explicitly locked pip. Do NOT change install method.
- **Installing Gitleaks again:** Already installed from Phase 5. Just verify and document.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tool installation | curl scripts, manual downloads | `pip install` / `brew install` | Package manager handles dependencies |
| Version checking | Custom parsing scripts | Direct CLI `--version` output | Tools self-report their versions |

## Common Pitfalls

### Pitfall 1: Wrong pip / Python Environment
**What goes wrong:** Semgrep installs to pyenv Python 3.12 instead of system Python 3.10 where Checkov lives, or vice versa.
**Why it happens:** Multiple Python installations on the system. `pip3` resolves to system Python 3.10 pip, but `pip` or pyenv-shimmed pip may differ.
**How to avoid:** Use `pip3 install semgrep --break-system-packages` which routes to system Python 3.10's pip (same as Checkov). Verify with `which semgrep` after install -- should be under `/Library/Frameworks/Python.framework/Versions/3.10/bin/`.
**Warning signs:** `semgrep --version` fails after install (not on PATH), or `which semgrep` shows unexpected location.

### Pitfall 2: --break-system-packages Flag
**What goes wrong:** pip refuses to install with "externally-managed-environment" error.
**Why it happens:** PEP 668 (Python 3.11+) prevents pip from modifying system Python without explicit flag.
**How to avoid:** Include `--break-system-packages` flag as specified in the user's locked decision. Note: system Python 3.10 may not require this flag (PEP 668 was Python 3.11+), but including it is harmless.
**Warning signs:** Error message about "externally-managed-environment".

### Pitfall 3: Semgrep First Run Downloads Rules
**What goes wrong:** First `semgrep scan` takes a long time downloading rule registry.
**Why it happens:** Semgrep fetches community rules from the Semgrep Registry on first scan.
**How to avoid:** This phase only verifies `semgrep --version` -- no scanning. Not an issue for Phase 7, but worth noting for Phase 8.
**Warning signs:** N/A for this phase.

### Pitfall 4: Gitleaks Version Command Syntax
**What goes wrong:** Using `gitleaks --version` instead of `gitleaks version`.
**Why it happens:** Most tools use `--version` flag, but Gitleaks uses a subcommand.
**How to avoid:** Use `gitleaks version` (no dashes). The success criteria in the phase description already specifies this correctly.
**Warning signs:** "unknown flag" error from Gitleaks.

## Code Examples

### Semgrep Installation and Verification
```bash
# Install via pip (system Python 3.10)
pip3 install semgrep --break-system-packages

# Verify
semgrep --version
# Expected output: 1.155.0
```

### Checkov Verification (Already Installed)
```bash
# Verify existing installation
checkov --version
# Expected output: 3.2.396

# Location
which checkov
# Expected: /Library/Frameworks/Python.framework/Versions/3.10/bin/checkov
```

### Gitleaks Verification (Already Installed)
```bash
# Verify existing installation
gitleaks version
# Expected output: v8.30.0 (note: subcommand, not --version flag)

# Location
which gitleaks
# Expected: /opt/homebrew/bin/gitleaks
```

### Documentation Version Note Pattern (from Phase 6)
```bash
# Inside the tool's setup code block in the main doc, add after install command:
# Verified: v1.155.0 (2026-03-16)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Semgrep required login/token | Semgrep CE fully local, no account | Semgrep OSS rebranded to CE | No telemetry, no login needed |
| Checkov v2 | Checkov v3 | 2024 | Improved performance, new policy framework |
| Gitleaks pre-v8 config format | Gitleaks v8+ TOML config | 2022 | `.gitleaks.toml` replaced older format |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell commands (version checks) |
| Config file | none -- direct CLI verification |
| Quick run command | `semgrep --version && checkov --version && gitleaks version` |
| Full suite command | `semgrep --version && checkov --version && gitleaks version` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOOL-04 | Semgrep on PATH, version current | smoke | `semgrep --version` | N/A (CLI check) |
| TOOL-05 | Checkov on PATH, version current | smoke | `checkov --version` | N/A (CLI check) |
| TOOL-06 | Gitleaks on PATH, version current | smoke | `gitleaks version` | N/A (CLI check) |

### Sampling Rate
- **Per task commit:** `semgrep --version && checkov --version && gitleaks version`
- **Per wave merge:** Same as above (this phase has no test files)
- **Phase gate:** All three version commands succeed

### Wave 0 Gaps
None -- existing CLI tools self-verify via version commands. No test infrastructure needed.

## Open Questions

1. **Checkov upgrade: yes or no?**
   - What we know: v3.2.396 installed, Homebrew has v3.2.500, pip likely has similar or newer
   - What's unclear: Whether upgrading is worth the risk of dependency conflicts
   - Recommendation: Claude's discretion per CONTEXT.md. Conservative choice is to keep 3.2.396 and just document. Low-risk choice is `pip3 install --upgrade checkov --break-system-packages` since it is a minor version bump.

2. **pip3 vs pip for Semgrep install**
   - What we know: `pip3` resolves to system Python 3.10 pip; `pip` may resolve differently via pyenv
   - Recommendation: Use `pip3` explicitly to match Checkov's Python environment

## Sources

### Primary (HIGH confidence)
- Direct system verification: `checkov --version` returns 3.2.396, `gitleaks version` returns 8.30.0, `semgrep` not found
- Direct system verification: `which checkov` at `/Library/Frameworks/Python.framework/Versions/3.10/bin/checkov`, `which gitleaks` at `/opt/homebrew/bin/gitleaks`
- Homebrew formula: `brew info semgrep` confirms v1.155.0 available
- pip dry-run: `pip install semgrep --dry-run` confirms v1.155.0 available

### Secondary (MEDIUM confidence)
- Main doc `docs/development-security-stack-option-1.md` lines 154-203 (Semgrep setup), 206-251 (Checkov setup), 361-384 (Gitleaks setup)
- Phase 6 summary pattern for documentation updates

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all tools verified on system or in package managers
- Architecture: HIGH -- follows established Phase 5/6 pattern exactly
- Pitfalls: HIGH -- Python environment complexity is the main risk, well understood

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable tools, versions may increment but pattern unchanged)
