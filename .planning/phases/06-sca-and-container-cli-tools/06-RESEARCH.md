# Phase 6: SCA and Container CLI Tools - Research

**Researched:** 2026-03-16
**Domain:** CLI tool installation (Homebrew), supply chain security tooling
**Confidence:** HIGH

## Summary

Phase 6 installs three supply chain / container security CLI tools -- Trivy (upgrade + DB refresh), Syft (fresh install), and Grype (fresh install) -- via Homebrew. This is a straightforward installation phase with no code changes, no hook configuration, and no scanning validation (that is Phase 8).

The Grype version concern from STATE.md is resolved: Homebrew currently ships Grype 0.109.1, well above the 0.88.0 minimum required for DB schema v6. All three tools are available via standard `brew install` / `brew upgrade` with no tap configuration needed. The established Phase 5 pattern (install, verify version, update main doc) applies directly.

**Primary recommendation:** Follow the Homebrew install/upgrade pattern from Phase 5. Install order: Trivy upgrade first (includes DB refresh), then Syft, then Grype. Verify versions, update main doc.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Homebrew for all three tools** -- consistent with Gitleaks (Phase 5) and existing Trivy install. No curl-based binary installs.
- **Trivy**: upgrade existing v0.69.3 via `brew upgrade trivy`, then refresh vulnerability DB via `trivy image --download-db-only`
- **Grype**: install via Homebrew, verify >= 0.88.0. Fallback to curl-based install from Anchore GitHub releases only if Homebrew version is below 0.88.0
- **Syft**: install via `brew install syft`
- **Documentation updates**: Update `docs/development-security-stack-option-1.md` with actual installed versions for all three tools

### Claude's Discretion
- Exact format and placement of version notes in the main doc
- Whether to update the Trivy DB refresh section with current timestamps
- Order of installation (Trivy upgrade first, then Syft, then Grype -- or parallel)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TOOL-01 | Trivy is installed and on `$PATH` (`trivy --version` succeeds), version >= 0.69.2 | Trivy v0.69.3 already installed; Homebrew has v0.69.3; `brew upgrade trivy` + DB refresh |
| TOOL-02 | Syft is installed and on `$PATH` (`syft version` succeeds) | Homebrew has Syft v1.42.2; `brew install syft` |
| TOOL-03 | Grype is installed and on `$PATH` (`grype version` succeeds), version >= 0.88.0 | Homebrew has Grype v0.109.1 (well above 0.88.0 minimum); `brew install grype` |
</phase_requirements>

## Standard Stack

### Core
| Tool | Homebrew Version | Purpose | Why Standard |
|------|-----------------|---------|--------------|
| Trivy | 0.69.3 | Container, filesystem, IaC, secrets scanning | Swiss army knife scanner from Aqua Security; absorbed tfsec |
| Syft | 1.42.2 | SBOM generation (CycloneDX, SPDX) | Anchore's dedicated SBOM tool; richer output than Trivy SBOM |
| Grype | 0.109.1 | SCA vulnerability scanning from SBOMs | Anchore's vuln scanner; pairs with Syft; uses DB schema v6 |

### Installation Commands
```bash
# Trivy -- already installed, upgrade + DB refresh
brew upgrade trivy
trivy image --download-db-only

# Syft -- fresh install
brew install syft

# Grype -- fresh install
brew install grype
```

### Version Verification Commands
```bash
trivy --version    # expect >= 0.69.2
syft version       # expect current (1.42.x)
grype version      # expect >= 0.88.0
```

## Architecture Patterns

### Established Phase Pattern (from Phase 5)
1. Install/upgrade tool via Homebrew
2. Verify version on PATH meets minimum requirement
3. Update main doc (`docs/development-security-stack-option-1.md`) with actual installed versions
4. No scanning or integration -- just availability on PATH

### Documentation Update Pattern
The main doc already has setup sections for all three tools:
- Trivy: lines 253-292 (install, scan modes, DB management, offline mode)
- Syft + Grype: lines 296-352 (install, SBOM generation, vulnerability scanning)

Version notes should be added to match the pattern established in prior phases -- noting actual verified versions alongside the install commands.

### Anti-Patterns to Avoid
- **Running scans during this phase:** Phase 6 is install-only. Scanning validation is Phase 8 (TOOL-07, TOOL-08).
- **Using curl installers when Homebrew works:** The user explicitly chose Homebrew for upgrade-path consistency.
- **Skipping Trivy DB refresh:** The DB was last downloaded 2026-02-22 -- over 3 weeks stale. Missing recent CVEs.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tool installation | curl scripts, manual binary downloads | `brew install` / `brew upgrade` | Consistent upgrade path, dependency management |
| Version checking | Custom parsing scripts | Direct CLI `--version` output | Tools self-report their versions |
| DB updates | Manual DB file downloads | `trivy image --download-db-only` | Built-in DB management handles checksums and caching |

## Common Pitfalls

### Pitfall 1: Stale Trivy Vulnerability Database
**What goes wrong:** Trivy appears to work but misses recent CVEs because the vulnerability DB is weeks old.
**Why it happens:** `brew upgrade` updates the binary but does NOT refresh the vulnerability database.
**How to avoid:** Always run `trivy image --download-db-only` after upgrading Trivy.
**Warning signs:** `trivy image --download-db-only` output shows a DB date more than a few days old.

### Pitfall 2: Grype First Run DB Download
**What goes wrong:** First `grype` command takes 1-2 minutes and may appear hung.
**Why it happens:** Grype downloads its vulnerability database on first run (~200MB compressed).
**How to avoid:** Expect this delay on first run. Verification should allow time for DB download.
**Warning signs:** `grype version` works instantly (no DB needed), but `grype db check` or actual scans will trigger the download.

### Pitfall 3: Homebrew Tap Confusion
**What goes wrong:** Old documentation suggests `brew tap anchore/grype` before install.
**Why it happens:** Grype and Syft used to require custom taps but are now in the main Homebrew formulae.
**How to avoid:** Use plain `brew install grype` and `brew install syft` -- no tap needed.
**Warning signs:** Error messages about tap conflicts or duplicate formulae.

### Pitfall 4: Trivy Already at Latest
**What goes wrong:** `brew upgrade trivy` reports "already installed" with exit code 0 but no actual upgrade.
**Why it happens:** Trivy v0.69.3 is already the latest in Homebrew.
**How to avoid:** This is fine -- the requirement is >= 0.69.2 and v0.69.3 satisfies it. Still run DB refresh.
**Warning signs:** None -- this is expected behavior.

## Code Examples

### Trivy DB Refresh Verification
```bash
# Source: Trivy installation docs (https://trivy.dev/docs/latest/getting-started/installation/)
trivy image --download-db-only
# Verify DB freshness -- look for recent date in output
```

### Syft Version Check
```bash
# Source: Anchore Syft docs (https://oss.anchore.com/docs/installation/syft/)
syft version
# Output includes version number, e.g., "1.42.2"
```

### Grype Version and DB Status
```bash
# Source: Anchore Grype docs (https://oss.anchore.com/docs/installation/grype/)
grype version
# Verify DB schema v6 support
grype db check
# Shows DB status, schema version, and last update time
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Grype DB schema v5 | DB schema v6 | Grype v0.88.0 (March 2025) | v5 EOL was 2026-03-06; must use >= 0.88.0 |
| `brew tap anchore/grype` required | Standard Homebrew formula | Recent | No tap needed, simpler install |
| Syft v0.x | Syft v1.x | 2024 | Stable API, richer SBOM output formats |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell commands (version checks) |
| Config file | none -- direct CLI verification |
| Quick run command | `trivy --version && syft version && grype version` |
| Full suite command | `trivy --version && syft version && grype version` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TOOL-01 | Trivy on PATH, version >= 0.69.2 | smoke | `trivy --version` | N/A (CLI check) |
| TOOL-02 | Syft on PATH, version current | smoke | `syft version` | N/A (CLI check) |
| TOOL-03 | Grype on PATH, version >= 0.88.0 | smoke | `grype version` | N/A (CLI check) |

### Sampling Rate
- **Per task commit:** `trivy --version && syft version && grype version`
- **Per wave merge:** Same as above (this phase has no test files)
- **Phase gate:** All three version commands succeed with versions meeting minimums

### Wave 0 Gaps
None -- existing CLI tools self-verify via `--version` commands. No test infrastructure needed.

## Open Questions

None. All questions resolved during research:
- Grype Homebrew version (0.109.1) exceeds the 0.88.0 minimum -- no fallback to curl install needed.
- Trivy Homebrew version (0.69.3) meets the >= 0.69.2 requirement.
- All three tools available via standard `brew install`/`brew upgrade` without custom taps.

## Sources

### Primary (HIGH confidence)
- [Homebrew Grype formula](https://formulae.brew.sh/formula/grype) -- confirmed version 0.109.1
- [Homebrew Syft formula](https://formulae.brew.sh/formula/syft) -- confirmed version 1.42.2
- [Homebrew Trivy formula](https://formulae.brew.sh/formula/trivy) -- confirmed version 0.69.3
- [Anchore Grype installation docs](https://oss.anchore.com/docs/installation/grype/) -- installation methods
- [Trivy installation docs](https://trivy.dev/docs/latest/getting-started/installation/) -- installation and DB management

### Secondary (MEDIUM confidence)
- [Grype DB schema v5 EOL announcement](https://anchorecommunity.discourse.group/t/grype-db-schema-v5-will-be-eol-on-march-6-2026/591) -- confirmed v5 EOL date and v0.88.0 as minimum for v6
- [Anchore Grype DB schema evolution blog](https://anchore.com/blog/grype-db-schema-evolution-from-v5-to-v6-smaller-faster-better/) -- v6 schema details

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all versions verified via Homebrew formulae pages
- Architecture: HIGH -- follows established Phase 5 pattern, no novel architecture
- Pitfalls: HIGH -- well-known tool behaviors, documented in official sources

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable tools, Homebrew versions may increment but will remain above minimums)
