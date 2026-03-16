# Phase 5: Secrets Detection Gate - Research

**Researched:** 2026-03-15
**Domain:** Gitleaks secrets scanning, pre-commit framework pre-push hooks, .gitleaksignore management
**Confidence:** HIGH

## Summary

Phase 5 configures Gitleaks as a pre-push hook across three target repos, performs baseline scans, manages false positives via `.gitleaksignore`, and documents the `--no-verify` bypass with CI as the compensating control. The core work is reconfiguring an existing Gitleaks entry in `.pre-commit-config.yaml` (already present from Phase 1) to run at the pre-push stage with explicit `protect --staged` args.

Key technical findings: (1) Gitleaks v8.19+ deprecated `protect` and `detect` commands in favor of `gitleaks git --pre-commit --staged`, but the old commands still work and the pre-commit hook definition in the gitleaks repo still uses them -- the requirement text says `protect --staged` which maps to adding `args: [protect, --staged]` to the hook entry. (2) Pre-commit framework v4.x uses `stages: [pre-push]` (not the deprecated `stages: [push]`). (3) Gitleaks is NOT currently installed on this workstation -- `brew install gitleaks` is a prerequisite. (4) The three repos have different Gitleaks versions pinned: aws-zabbix has v8.21.2, terraform-pipelines has v8.30.1, security-platform has v8.21.2 -- `pre-commit autoupdate` will normalize these.

**Primary recommendation:** Install Gitleaks via brew, add `stages: [pre-push]` and `args: [protect, --staged]` to the Gitleaks hook entry in all three repos, run `pre-commit install --hook-type pre-push` in each, perform baseline scans, and test with a dummy AWS key.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Change Gitleaks from default pre-commit stage to **pre-push only** (`stages: [pre-push]`)
- Add explicit args: `[protect, --staged]` to match SECR-01 requirement exactly
- Run `pre-commit autoupdate` to get latest Gitleaks version (not pinned to v8.21.2)
- Update canonical `.pre-commit-config.yaml` in security-platform first, then sync to all target repos
- Run `pre-commit install --hook-type pre-push` in each repo to activate the pre-push hook
- Run full-history Gitleaks scan (`gitleaks detect --source . --log-opts="--all"`) on all three repos to establish baseline
- Add legitimate false positives to `.gitleaksignore` (aws-zabbix already has CDK asset hash entry)
- SECR-02 demo: create temp file with dummy AWS key `AKIAIOSFODNN7EXAMPLE`, stage, attempt push, verify block, clean up
- **Canonical + per-repo:** `.gitleaksignore` strategy -- base template in security-platform, repo-specific extensions
- All three repos get the Gitleaks pre-push hook: aws-zabbix-monitoring-solution, terraform-pipelines, security-platform
- Install via `brew install gitleaks` (system-wide CLI)
- Document `--no-verify` bypass and CI compensating control in three places: main doc, README, inline config comments
- References ADR-011 (pre-commit bypass warning)

### Claude's Discretion
- Exact `.gitleaksignore` template contents for the canonical base
- Whether to add a custom Gitleaks config (`.gitleaks.toml`) or use defaults
- Order of operations for multi-repo config sync
- How to structure the bypass documentation sections

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SECR-01 | Gitleaks hook runs in `protect --staged` mode on every push (pre-push hook) | Add `stages: [pre-push]` and `args: [protect, --staged]` to hook entry; run `pre-commit install --hook-type pre-push` in each repo |
| SECR-02 | A commit containing a dummy AWS key pattern (`AKIAIOSFODNN7EXAMPLE`) is blocked by Gitleaks | Create temp file with dummy key, stage+commit, attempt push -- gitleaks blocks; clean up after |
| SECR-03 | Developer understands `--no-verify` bypass and that CI is the compensating control | Document in main doc, README, and inline config comments per ADR-011 |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Gitleaks | latest via brew | Secrets detection in git repos | Purpose-built, actively maintained, default rules cover AWS/GCP/Azure/generic patterns |
| pre-commit | 4.5.0 (installed) | Git hook framework | Already in use across all repos since Phase 1 |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| brew | system | Package manager for Gitleaks install | One-time install |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Gitleaks | TruffleHog | TruffleHog is more thorough but slower; Gitleaks is the project's chosen tool per architecture doc |
| System gitleaks | Pre-commit-managed gitleaks | System install also satisfies TOOL-06 (Phase 7); pre-commit-managed would be isolated |

**Installation:**
```bash
brew install gitleaks
```

## Architecture Patterns

### Hook Configuration Pattern
The `.pre-commit-config.yaml` Gitleaks entry needs three modifications from the current state:

```yaml
  # --- Secrets detection: Gitleaks ---
  # Runs on push only — a credential pushed to any branch is a potential exposure.
  # Bypass: git push --no-verify (CI is the compensating control — see ADR-011)
  - repo: https://github.com/gitleaks/gitleaks
    rev: <latest via autoupdate>
    hooks:
      - id: gitleaks
        stages: [pre-push]
        args: [protect, --staged]
```

Changes from current:
1. Add `stages: [pre-push]` -- moves hook from pre-commit to pre-push stage
2. Add `args: [protect, --staged]` -- makes scanning mode explicit
3. Version bump via `pre-commit autoupdate`

### Pre-push Hook Activation
```bash
# Must be run in each repo after config change
pre-commit install --hook-type pre-push
```
This creates `.git/hooks/pre-push` alongside the existing `.git/hooks/pre-commit`.

### .gitleaksignore Format
Each line is a fingerprint in the format: `commit:filepath:rule-id:line-number`

Example (existing in aws-zabbix):
```
# CDK asset hashes in snapshot files are content-addressable hashes, not secrets
test/__snapshots__/snapshot.test.ts.snap:generic-api-key:2974
```

### Baseline Scan Command
```bash
# Full-history scan to find all existing findings
gitleaks detect --source . --log-opts="--all" --report-path gitleaks-baseline.json --report-format json
```
Review output, add legitimate false positives to `.gitleaksignore`.

### SECR-02 Test Pattern (from Phase 3 hadolint pattern)
```bash
# Create temp file with dummy AWS key
echo 'AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"' > /tmp/test-secret.txt
cp /tmp/test-secret.txt ./test-secret.txt
git add test-secret.txt
git commit -m "test: dummy secret for SECR-02 verification"
git push  # Should be BLOCKED by gitleaks pre-push hook
# Clean up
git reset --soft HEAD~1
rm test-secret.txt
git checkout -- . 2>/dev/null
```

### Multi-Repo Sync Order
1. security-platform (canonical source) -- update config, autoupdate, baseline scan
2. aws-zabbix-monitoring-solution -- sync config, baseline scan (already has .gitleaksignore)
3. terraform-pipelines -- sync config, baseline scan

### Anti-Patterns to Avoid
- **Using `stages: [push]` instead of `stages: [pre-push]`:** The old `push` naming was deprecated in pre-commit 3.2.0 and will warn or fail in v4.x (currently installed: 4.5.0)
- **Skipping `pre-commit install --hook-type pre-push`:** Adding `stages: [pre-push]` to the config is not enough -- the pre-push git hook must be installed separately
- **Running baseline scan before installing gitleaks:** `gitleaks detect` requires the CLI to be on PATH first

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Secret pattern detection | Custom regex | Gitleaks default rules | Covers 150+ secret patterns with entropy checks; maintaining custom regex is error-prone |
| Git hook management | Manual .git/hooks scripts | pre-commit framework | Already established in Phase 1; handles hook orchestration, updates, environments |
| False positive tracking | Manual log files | .gitleaksignore with fingerprints | Standard mechanism, per-finding granularity, version-controlled |

## Common Pitfalls

### Pitfall 1: Forgetting to install the pre-push hook type
**What goes wrong:** Config says `stages: [pre-push]` but `pre-commit install` only installs the pre-commit hook by default. Push proceeds without scanning.
**Why it happens:** `pre-commit install` without `--hook-type pre-push` only creates `.git/hooks/pre-commit`.
**How to avoid:** Run `pre-commit install --hook-type pre-push` in every repo.
**Warning signs:** `ls .git/hooks/pre-push` returns "not found" or only has the `.sample` file.

### Pitfall 2: Version mismatch across repos
**What goes wrong:** Repos have different Gitleaks versions (currently: v8.21.2 in aws-zabbix and security-platform, v8.30.1 in terraform-pipelines).
**Why it happens:** `pre-commit autoupdate` was run in some repos but not others.
**How to avoid:** Run `pre-commit autoupdate` in all repos during this phase; commit the updated configs.
**Warning signs:** Different `rev:` values for the gitleaks repo across `.pre-commit-config.yaml` files.

### Pitfall 3: Baseline scan producing many findings in history
**What goes wrong:** Full-history scan may surface dozens of findings from old commits, causing confusion about what needs suppression.
**Why it happens:** `gitleaks detect --log-opts="--all"` scans every commit ever made.
**How to avoid:** Remember that `protect --staged` in pre-push mode only checks new changes. Baseline scan is for documentation/clarity, not for blocking. Add genuine false positives to `.gitleaksignore`; real historical secrets need rotation, not suppression.
**Warning signs:** Temptation to suppress everything without reviewing -- real leaked secrets should be rotated.

### Pitfall 4: Test secret left in repo after SECR-02 verification
**What goes wrong:** Dummy AWS key `AKIAIOSFODNN7EXAMPLE` accidentally remains committed.
**Why it happens:** Test cleanup step skipped or done incorrectly.
**How to avoid:** Use `git reset --soft HEAD~1` immediately after verifying the block, then remove the test file. Verify with `git log --oneline -3` that the test commit is gone.

### Pitfall 5: Deprecated stage name in pre-commit v4.x
**What goes wrong:** Using `stages: [push]` instead of `stages: [pre-push]` produces deprecation warnings or errors.
**Why it happens:** Old documentation and blog posts use the v3.x naming convention.
**How to avoid:** Always use `stages: [pre-push]` with pre-commit >= 3.2.0.

## Code Examples

### Complete .pre-commit-config.yaml Gitleaks section
```yaml
# ─────────────────────────────────────────────────────────────────────────────
# TIER 2: Secrets Gate
# Secrets are the only pre-commit security check. A credential pushed to any
# branch is a potential exposure regardless of context. SAST (Semgrep CE) and
# IaC scanning (Checkov) run at the Pull Request gate in GitHub Actions instead.
# Bypass: git push --no-verify skips this hook — CI is the compensating control
# (see ADR-011).
# ─────────────────────────────────────────────────────────────────────────────

  # --- Secrets detection: Gitleaks ---
  - repo: https://github.com/gitleaks/gitleaks
    rev: <latest via pre-commit autoupdate>
    hooks:
      - id: gitleaks
        stages: [pre-push]
        args: [protect, --staged]
```

### .gitleaksignore template (canonical base for security-platform)
```
# .gitleaksignore — Gitleaks false positive suppressions
# Format: filepath:rule-id:line-number (fingerprint from gitleaks JSON output)
# Add entries from `gitleaks detect --source . --report-format json` output
#
# Common patterns to suppress:
# - CDK/CloudFormation asset hashes that match generic-api-key patterns
# - Example/placeholder values in documentation
# - Test fixtures with intentional dummy credentials
```

### Full-history baseline scan
```bash
# Run in each target repo
gitleaks detect --source . --log-opts="--all" --report-path /tmp/gitleaks-baseline.json --report-format json

# Review findings
cat /tmp/gitleaks-baseline.json | python3 -m json.tool | head -50

# For each legitimate false positive, extract the fingerprint and add to .gitleaksignore
```

### Pre-push hook activation
```bash
# Run in each target repo after updating .pre-commit-config.yaml
pre-commit install --hook-type pre-push

# Verify the hook file was created
ls -la .git/hooks/pre-push
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `gitleaks detect` | `gitleaks git` | v8.19.0 (2024) | Old commands still work but are hidden; pre-commit hooks still use `protect --staged` |
| `gitleaks protect --staged` | `gitleaks git --pre-commit --staged` | v8.19.0 (2024) | Both work; the pre-commit hook definition uses the old syntax |
| `stages: [push]` | `stages: [pre-push]` | pre-commit 3.2.0 | Old naming deprecated; v4.x warns/errors on old names |
| `stages: [commit]` | `stages: [pre-commit]` | pre-commit 3.2.0 | Same deprecation cycle |

**Current state:** Using `args: [protect, --staged]` per SECR-01 requirement is correct and functional even though `protect` is technically deprecated -- the gitleaks project's own `.pre-commit-hooks.yaml` still references this mode. No action needed to migrate to new command syntax for the pre-commit hook use case.

## Open Questions

1. **Custom .gitleaks.toml configuration**
   - What we know: Gitleaks works with sensible defaults out of the box covering 150+ patterns
   - What's unclear: Whether any project-specific patterns need custom rules
   - Recommendation: Start without `.gitleaks.toml`; add only if baseline scan reveals need for custom allowlists beyond `.gitleaksignore` fingerprints (Claude's discretion per CONTEXT.md)

2. **Baseline scan findings in terraform-pipelines**
   - What we know: aws-zabbix already has CDK asset hash suppressions; security-platform is a docs repo (low risk)
   - What's unclear: What false positives terraform-pipelines may surface (Terraform state, provider configs)
   - Recommendation: Run baseline scan and handle findings during execution; likely minimal since it's IaC templates

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual verification (documentation project, no automated test suite) |
| Config file | none |
| Quick run command | `gitleaks protect --staged` (in any target repo) |
| Full suite command | `pre-commit run gitleaks --hook-stage pre-push --all-files` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SECR-01 | Gitleaks runs in protect --staged mode on push | manual + smoke | `pre-commit run gitleaks --hook-stage pre-push` | N/A (hook config) |
| SECR-02 | Dummy AWS key AKIAIOSFODNN7EXAMPLE is blocked | manual e2e | Create test file, stage, commit, push -- verify block | N/A (manual test) |
| SECR-03 | Developer understands --no-verify bypass and CI control | documentation | Visual inspection of three documentation locations | N/A (docs) |

### Sampling Rate
- **Per task commit:** `gitleaks version` (verify installed) + `ls .git/hooks/pre-push` (verify hook exists)
- **Per wave merge:** Full SECR-02 dummy key test
- **Phase gate:** All three success criteria verified across all three repos

### Wave 0 Gaps
- [ ] `brew install gitleaks` -- Gitleaks not currently on PATH
- [ ] `pre-commit install --hook-type pre-push` -- pre-push hook not yet installed in any repo

## Sources

### Primary (HIGH confidence)
- Gitleaks GitHub repository README -- pre-commit hook configuration, .gitleaksignore format, baseline scanning
- Pre-commit framework official docs (pre-commit.com) -- stages configuration, pre-push hook activation
- Direct inspection of target repo `.pre-commit-config.yaml` files -- current state verified
- Direct inspection of `gitleaks version` -- confirmed NOT installed (prerequisite)
- Direct inspection of `pre-commit --version` -- confirmed v4.5.0 (uses new stage names)
- ADR-011 in `docs/adr/adr011-precommit-bypass-warning.md` -- bypass documentation requirements
- `docs/development-security-stack-option-1.md` lines 362-377, 1377-1384 -- canonical Gitleaks configuration

### Secondary (MEDIUM confidence)
- [Gitleaks GitHub](https://github.com/gitleaks/gitleaks) -- v8.19.0 deprecated protect/detect commands
- [Gitleaks Discussion #1493](https://github.com/gitleaks/gitleaks/discussions/1493) -- pre-push behavior with protect mode
- [Pre-commit framework](https://pre-commit.com/) -- stage naming convention changes in v3.2.0
- [Pre-commit hooks issue #1096](https://github.com/pre-commit/pre-commit-hooks/issues/1096) -- deprecated stage names warning

### Tertiary (LOW confidence)
- None -- all findings verified against primary or secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Gitleaks and pre-commit are locked decisions; versions verified on workstation
- Architecture: HIGH -- hook configuration pattern verified against pre-commit v4.x docs and gitleaks repo
- Pitfalls: HIGH -- stage naming deprecation verified; hook installation requirement verified by inspecting .git/hooks/

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (stable tools, low churn)
