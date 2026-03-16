# Phase 2: Shell and Python Hooks - Research

**Researched:** 2026-03-15
**Domain:** ShellCheck and Ruff pre-commit hook validation and violation remediation
**Confidence:** HIGH

## Summary

Phase 2 validates that ShellCheck and Ruff pre-commit hooks (already configured in `.pre-commit-config.yaml` from Phase 1) correctly trigger on the target repository's shell scripts and Python files. The work is remediation-focused: run the hooks, identify violations, fix or suppress them, and verify the success criteria.

The target repo (`repos/aws-zabbix-monitoring-solution/` on branch `feature/add-pre-commit`) contains 3 shell scripts and 1 Python file. Based on reading the files, there are known issues: the Python file (`snippet-python-hostname.py`) is missing an `import json` statement and may have Ruff formatting violations. The shell scripts will likely trigger ShellCheck warnings for unquoted variables (e.g., `$AWS_PROFILE` in `cdk-validation.sh` line 18, `$UBUNTU_VERSION` in `zabbix_agent_install.sh` line 34) and other common patterns.

**Primary recommendation:** Run `pre-commit run shellcheck --all-files` and `pre-commit run ruff --all-files` in the target repo to discover all violations, fix what is safe to fix, suppress the rest with inline annotations, then verify the success criteria from REQUIREMENTS.md.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- ShellCheck: `shellcheck-py` rev v0.10.0.1 -- catches shell script issues
- Ruff: `ruff-pre-commit` rev v0.8.4 -- `ruff --fix` for linting + `ruff-format` for formatting
- Both hooks already present in `.pre-commit-config.yaml` committed in Phase 1
- Target files: `scripts/cdk-validation.sh`, `scripts/dev-certs/generate-certs.sh`, `scripts/zabbix_agent_install.sh`, `scripts/snippet-python-hostname.py`
- Validation approach: Run hooks, fix violations where practical, suppress with inline annotations where fixing would change behavior

### Claude's Discretion
- Whether to fix or suppress specific ShellCheck/Ruff violations
- Inline suppression comment style (`# shellcheck disable=SC2xxx` vs `.shellcheckrc`)
- Whether to add a `.ruff.toml` for project-level Ruff configuration

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LINT-01 | ShellCheck hook catches unquoted variables and shell script issues on every commit | ShellCheck v0.10.0.1 configured in `.pre-commit-config.yaml`. Three shell scripts in `scripts/` directory. Unquoted variable patterns confirmed in `cdk-validation.sh` (line 18: `$AWS_PROFILE`) and `zabbix_agent_install.sh` (line 34: `$UBUNTU_VERSION`). |
| LINT-02 | Ruff hook auto-fixes Python formatting violations and flags linting errors on every commit | Ruff v0.8.4 configured with both `ruff --fix` and `ruff-format` hooks. One Python file: `scripts/snippet-python-hostname.py` which is missing `import json` (uses `json.load` on line 6). |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| shellcheck-py | v0.10.0.1 | Shell script static analysis | Already configured in Phase 1 `.pre-commit-config.yaml` |
| ruff-pre-commit | v0.8.4 | Python linting + formatting | Already configured in Phase 1 `.pre-commit-config.yaml` |
| pre-commit | 4.5.0 | Hook framework | Already installed and activated in target repo |

### Supporting
No additional tools needed. This phase uses only what Phase 1 installed.

## Architecture Patterns

### Target File Inventory

```
repos/aws-zabbix-monitoring-solution/
├── scripts/
│   ├── cdk-validation.sh          # 153 lines, CDK quality validation
│   ├── zabbix_agent_install.sh    # 125 lines, Zabbix agent installer
│   ├── snippet-python-hostname.py # 10 lines, hostname lookup utility
│   └── dev-certs/
│       └── generate-certs.sh      # 455 lines, TLS certificate generator
```

### Pattern: Hook Execution Flow

Pre-commit hooks run against **staged files only** during `git commit`. To test all files:
```bash
pre-commit run shellcheck --all-files
pre-commit run ruff --all-files
pre-commit run ruff-format --all-files
```

To test against specific files:
```bash
pre-commit run shellcheck --files scripts/cdk-validation.sh
pre-commit run ruff --files scripts/snippet-python-hostname.py
```

### Pattern: ShellCheck Inline Suppression

Suppress specific warnings on the line above the flagged code:
```bash
# shellcheck disable=SC2086
echo "Using profile: $AWS_PROFILE_FLAG"
```

Multiple codes on one line:
```bash
# shellcheck disable=SC2086,SC2154
```

File-level suppression at top of script (after shebang):
```bash
#!/bin/bash
# shellcheck disable=SC2034
```

### Pattern: Ruff Inline Suppression

Suppress on a single line:
```python
import json  # noqa: F401
```

Suppress specific rules:
```python
x = 1  # noqa: E741
```

### Pattern: Project-Level Ruff Config

Optional `.ruff.toml` for consistent project settings:
```toml
[lint]
select = ["E", "F", "W"]
ignore = []

[format]
quote-style = "double"
```

### Anti-Patterns to Avoid
- **Blanket suppression of entire ShellCheck categories:** Suppress individual occurrences, not whole rule classes
- **Fixing scripts that change runtime behavior:** If quoting a variable changes how word splitting works (e.g., passing multiple args via a single variable), suppress rather than fix
- **Adding `import json` without verifying the file is a complete script:** The Python file appears to be a snippet/fragment -- verify whether it should have a proper module structure or remain a snippet

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Shell lint rules | Custom bash checks | ShellCheck SC codes | ShellCheck covers 400+ rules with POSIX compliance |
| Python formatting | Manual style fixes | `ruff format` auto-fix | Ruff formats consistently and deterministically |
| Python lint fixes | Manual code edits | `ruff --fix` auto-fix | Ruff safely applies fixes for fixable rules |

## Common Pitfalls

### Pitfall 1: Unquoted Variable Expansion in Shell Scripts (SC2086)
**What goes wrong:** ShellCheck flags `$VAR` as needing quotes: `"$VAR"`. But quoting a variable used as multiple CLI flags (like `$AWS_PROFILE_FLAG` which expands to `--profile name`) changes behavior -- the quoted version passes as a single argument instead of two.
**Why it happens:** Word splitting is intentional when building command arguments from variables.
**How to avoid:** For variables that intentionally expand to multiple words, suppress with `# shellcheck disable=SC2086`. For simple value variables, add quotes.
**Warning signs:** Variables that contain spaces or flags like `--profile developer-account` are candidates for intentional word splitting.

### Pitfall 2: Python Snippet vs Complete Module
**What goes wrong:** Ruff flags missing imports and undefined names in code fragments that are intentionally incomplete.
**Why it happens:** `snippet-python-hostname.py` uses `json.load()` without `import json` at the top. It may be a code snippet, not a runnable module.
**How to avoid:** Check if adding the import makes the file a valid module. If the file is intentionally a snippet, add `# noqa` suppression or add the missing import.
**Warning signs:** Files named "snippet" that lack standard module structure.

### Pitfall 3: Heredoc Variable Expansion (SC2016/SC2064)
**What goes wrong:** `zabbix_agent_install.sh` uses both quoted (`<<'ZABBIXEOF'`) and unquoted (`<<TLSEOF`) heredocs. ShellCheck may flag the difference.
**Why it happens:** Quoted heredocs suppress variable expansion (literal `${ZabbixServerActive}` in config file), while unquoted heredocs expand variables (TLS values injected at runtime). Both are intentional.
**How to avoid:** Verify each heredoc's quoting matches the author's intent before changing anything.

### Pitfall 4: sed -i Portability (SC2001)
**What goes wrong:** `generate-certs.sh` uses `sed -i.bak` which is GNU sed syntax. ShellCheck may flag sed usage patterns.
**Why it happens:** macOS ships BSD sed, GNU/Linux ships GNU sed. The script uses `-i.bak` which works on both.
**How to avoid:** This pattern is already portable. Leave as-is unless ShellCheck specifically flags it.

### Pitfall 5: Ruff Auto-Fix Modifying Committed Files
**What goes wrong:** `ruff --fix` auto-modifies files. If changes are staged and Ruff modifies the working tree copy, the staged and working tree versions diverge.
**Why it happens:** Pre-commit runs on staged content but writes fixes to the working tree.
**How to avoid:** After Ruff auto-fixes, re-stage the modified files before committing. Pre-commit handles this automatically when running as a git hook.

## Code Examples

### Running ShellCheck Hook Against All Files
```bash
cd repos/aws-zabbix-monitoring-solution
pre-commit run shellcheck --all-files
```

### Running Ruff Hooks Against All Files
```bash
cd repos/aws-zabbix-monitoring-solution
pre-commit run ruff --all-files
pre-commit run ruff-format --all-files
```

### Full Pre-commit Run with Diff Output
```bash
cd repos/aws-zabbix-monitoring-solution
pre-commit run --all-files --show-diff-on-failure
```

### Verifying Success Criteria: ShellCheck Catches Unquoted Variable
To demonstrate LINT-01, introduce a deliberate violation and verify ShellCheck catches it:
```bash
# Stage a file with unquoted variable
echo 'echo $UNQUOTED_VAR' >> scripts/cdk-validation.sh
git add scripts/cdk-validation.sh
git commit -m "test"  # Should fail with SC2086
# Then revert the test change
git checkout -- scripts/cdk-validation.sh
```

### Verifying Success Criteria: Ruff Auto-Fixes Python
To demonstrate LINT-02, introduce a formatting violation:
```bash
# Stage a Python file with bad formatting
echo 'x=1' >> scripts/snippet-python-hostname.py
git add scripts/snippet-python-hostname.py
git commit -m "test"  # Ruff should auto-fix spacing: x = 1
```

## Known Violations to Expect

### Shell Scripts -- Likely ShellCheck Findings

**`scripts/cdk-validation.sh`:**
- SC2086: Unquoted `$AWS_PROFILE` (line 18) -- FIX: quote it
- SC2086: Unquoted `$AWS_PROFILE_FLAG` (not used in command substitution, but defined) -- review usage
- SC2086: Unquoted `$CHECKS_PASSED`, `$CHECKS_SKIPPED`, `$CHECKS_FAILED` in echo (lines 147-149) -- FIX: quote them

**`scripts/zabbix_agent_install.sh`:**
- SC2086: Unquoted `$UBUNTU_VERSION` in echo (line 39) -- FIX: quote it
- SC2086: Unquoted `$PACKAGE_NAME` (lines 43-44) -- FIX: quote it
- SC2086: Unquoted `$ZabbixTLSConnect` in echo (line 78) -- FIX: quote it
- SC2154: Variables referenced but not assigned in this scope (TLS vars from environment)
- Heredoc quoting variations (intentional -- suppress if flagged)

**`scripts/dev-certs/generate-certs.sh`:**
- SC2086: Unquoted `${KEY_SIZE_CA}`, `${KEY_SIZE_CERT}`, `${CA_VALIDITY_DAYS}`, `${CERT_VALIDITY_DAYS}` in openssl commands -- FIX: quote them
- Generally well-written with `set -euo pipefail` and proper quoting throughout

### Python -- Likely Ruff Findings

**`scripts/snippet-python-hostname.py`:**
- F821: Undefined name `json` (missing `import json`)
- E302: Possible missing blank lines (depending on full file structure)
- Formatting: may need reformatting by `ruff-format`

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pre-commit 4.5.0 (hook execution framework) |
| Config file | `repos/aws-zabbix-monitoring-solution/.pre-commit-config.yaml` |
| Quick run command | `cd repos/aws-zabbix-monitoring-solution && pre-commit run shellcheck --all-files && pre-commit run ruff --all-files && pre-commit run ruff-format --all-files` |
| Full suite command | `cd repos/aws-zabbix-monitoring-solution && pre-commit run --all-files --show-diff-on-failure` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LINT-01 | ShellCheck catches unquoted variables on commit | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run shellcheck --all-files` | N/A (pre-commit built-in) |
| LINT-02 | Ruff auto-fixes Python formatting on commit | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run ruff --all-files && pre-commit run ruff-format --all-files` | N/A (pre-commit built-in) |

### Sampling Rate
- **Per task commit:** `pre-commit run shellcheck --all-files && pre-commit run ruff --all-files`
- **Per wave merge:** `pre-commit run --all-files --show-diff-on-failure`
- **Phase gate:** All hooks pass cleanly on `--all-files`

### Wave 0 Gaps
None -- pre-commit infrastructure is fully installed from Phase 1. No additional test framework needed.

## Open Questions

1. **Is `snippet-python-hostname.py` a complete module or an intentional fragment?**
   - What we know: The file uses `json.load()` but has no `import json`. It defines one function but has no `if __name__` block. The filename contains "snippet".
   - What's unclear: Whether to add `import json` (making it a proper module) or suppress the undefined name warning.
   - Recommendation: Add `import json` -- it makes the file valid and is the minimal fix. The file is tracked in git and will be committed, so it should be valid Python.

2. **Should `.shellcheckrc` be used for project-level suppression?**
   - What we know: CONTEXT.md lists this as Claude's discretion.
   - Recommendation: Use inline `# shellcheck disable=SCxxxx` comments, not `.shellcheckrc`. Inline comments are self-documenting and visible at the point of suppression. A `.shellcheckrc` hides suppressions from code reviewers.

3. **Should `.ruff.toml` be added?**
   - What we know: CONTEXT.md lists this as Claude's discretion.
   - Recommendation: Do not add `.ruff.toml` unless Ruff's defaults produce undesirable behavior. The single Python file is small; default Ruff rules are sufficient. Adding config adds maintenance burden with minimal benefit for one file.

## Sources

### Primary (HIGH confidence)
- Direct file inspection of all 4 target files in `repos/aws-zabbix-monitoring-solution/scripts/`
- `.pre-commit-config.yaml` in target repo (verified ShellCheck v0.10.0.1 and Ruff v0.8.4 configuration)
- Phase 1 summary (`01-01-SUMMARY.md`) confirming hooks are installed and activated

### Secondary (MEDIUM confidence)
- ShellCheck wiki SC codes (well-documented, stable project)
- Ruff rule codes (stable, well-documented)

### Tertiary (LOW confidence)
- Specific violation predictions are based on reading the source files and applying ShellCheck/Ruff rule knowledge. Actual violations should be confirmed by running the hooks.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - already installed in Phase 1, versions pinned
- Architecture: HIGH - files are small, well-understood, directly inspected
- Pitfalls: HIGH - ShellCheck/Ruff are mature tools with well-documented behavior
- Violation predictions: MEDIUM - based on code reading, must verify by running hooks

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (stable tools, no version changes expected)
