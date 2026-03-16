# Phase 4: Infrastructure Hooks - Research

**Researched:** 2026-03-15
**Domain:** npm audit, terraform fmt, terraform validate pre-commit hooks
**Confidence:** HIGH

## Summary

Phase 4 validates three infrastructure-focused pre-commit hooks that are already configured in `.pre-commit-config.yaml` (committed in Phase 1): npm audit for dependency scanning, terraform_fmt for HCL formatting, and terraform_validate for HCL syntax checking. The hooks exist in the config -- this phase is about making them actually work end-to-end.

The npm audit hook targets `aws-zabbix-monitoring-solution` (which has `package-lock.json`). Currently `npm audit --audit-level=high` exits with code 1 due to 2 high vulnerabilities (minimatch ReDoS in aws-cdk-lib, fast-xml-parser stack overflow in @aws-sdk/xml-builder), both fixable via `npm audit fix`. The terraform hooks target a real Terraform repo (`terraform-pipelines`) which must be cloned, have pre-commit installed, and have its `.tf` files validated.

**Primary recommendation:** Run `npm audit fix` to clear existing vulnerabilities, then test the hook triggers on `package-lock.json` changes. Clone terraform-pipelines, install pre-commit, run `pre-commit autoupdate` for latest pre-commit-terraform version, run `terraform fmt` and `terraform validate` across all `.tf` files, fix any formatting violations, and verify hooks trigger correctly.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Test terraform hooks against real Terraform repo: `OttawaCloudConsulting/terraform-pipelines`
- Clone to `repos/terraform-pipelines/` alongside existing target repos
- Deployable example at `examples/default/minimal/main.tf`, module in `modules/default`
- Install pre-commit in terraform-pipelines with the same `.pre-commit-config.yaml` config
- Full end-to-end test: install hooks, verify terraform_fmt and terraform_validate trigger on real `.tf` files
- Fix and commit any terraform fmt formatting violations (same clean-slate pattern as Phases 2/3)
- Run `npm audit fix` to resolve auto-fixable high/critical vulnerabilities in aws-zabbix-monitoring-solution
- If unfixable vulnerabilities remain, document them and adjust audit-level threshold so hook doesn't block indefinitely
- Terraform CLI already installed -- no installation needed
- Run `pre-commit autoupdate` to get latest `pre-commit-terraform` version (not pinned to v1.96.0)
- npm already available (target repo is a Node.js project)
- Hook configuration carried from Phase 1: npm-audit local hook, terraform_fmt and terraform_validate from pre-commit-terraform

### Claude's Discretion
- Whether to adjust npm audit-level from `high` to `critical` based on findings
- How to handle terraform validate's need for `terraform init` (provider initialization)
- Whether terraform-pipelines needs its own feature branch or can work on main

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LINT-07 | npm audit hook runs lightweight dependency audit when package-lock.json changes | npm audit currently fails (exit 1) with 2 high vulns; `npm audit fix` resolves both; hook config already in `.pre-commit-config.yaml` |
| LINT-08 | terraform fmt hook auto-formats HCL files on every commit | pre-commit-terraform provides terraform_fmt hook; terraform v1.14.7 installed; terraform-pipelines has 36 `.tf` files to test against |
| LINT-09 | terraform validate hook checks HCL syntax on every commit | pre-commit-terraform provides terraform_validate hook with automatic `terraform init` fallback; requires serial execution |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| pre-commit | (installed) | Hook framework | Already active in target repos from Phase 1 |
| pre-commit-terraform | v1.96.0 (will autoupdate) | terraform_fmt + terraform_validate hooks | antonbabenko/pre-commit-terraform is the de facto standard |
| terraform | v1.14.7 | HCL formatting and validation | Already installed on workstation |
| npm | (installed) | Dependency audit | Built into Node.js, already available |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `npm audit fix` | Auto-resolve known vulnerabilities | Before hook validation, to clear existing violations |
| `pre-commit autoupdate` | Bump hook versions to latest | Once during setup to get latest pre-commit-terraform |

### Alternatives Considered
None -- all tools are locked decisions from CONTEXT.md.

## Architecture Patterns

### Repo Layout for Phase 4
```
repos/
  aws-zabbix-monitoring-solution/    # npm audit testing (already cloned, feature/add-pre-commit branch)
    package-lock.json                 # triggers npm-audit hook
    .pre-commit-config.yaml           # already has npm-audit hook
  terraform-pipelines/               # terraform hook testing (TO CLONE)
    .pre-commit-config.yaml           # TO DEPLOY (copy from security-platform)
    examples/default/minimal/main.tf  # test target
    modules/default/                  # module code
    modules/core/                     # core module with providers
```

### Pattern: Clean-Slate Hook Validation (from Phases 2/3)
1. Install hooks in target repo
2. Run hook against all existing files
3. Fix all violations (formatting fixes, dependency fixes)
4. Commit fixes
5. Verify hook passes cleanly
6. Demonstrate hook catches new violations (end-to-end proof)

### Pattern: npm audit Hook (Local Hook)
```yaml
# Already in .pre-commit-config.yaml
- repo: local
  hooks:
    - id: npm-audit
      name: npm audit
      entry: npm audit --audit-level=high
      language: system
      files: package-lock\.json$
      pass_filenames: false
```
Key: `pass_filenames: false` means npm audit runs without file args (it reads package-lock.json from cwd). The `files:` pattern only controls WHEN the hook triggers (only when package-lock.json is staged).

### Pattern: terraform_fmt Hook
```yaml
# Already in .pre-commit-config.yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.96.0  # will be updated by pre-commit autoupdate
  hooks:
    - id: terraform_fmt
    - id: terraform_validate
```
terraform_fmt rewrites files in-place. Pre-commit detects the modification and fails the commit (showing what changed). The developer stages the reformatted files and re-commits.

### Anti-Patterns to Avoid
- **Testing terraform hooks without real .tf files:** Temp file testing was used for hadolint (Phase 3) but user explicitly chose real repo testing for terraform.
- **Leaving npm audit failures unresolved:** The hook will block every commit that touches package-lock.json. Fix first, gate later.
- **Running terraform validate without init:** terraform validate requires providers to be initialized. The pre-commit-terraform hook handles this automatically (tries validate first, falls back to init if it fails), but it needs network access on first run.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| terraform fmt integration | Custom script calling terraform fmt | pre-commit-terraform `terraform_fmt` hook | Handles file discovery, directory traversal, exclude patterns |
| terraform validate integration | Custom script calling terraform validate | pre-commit-terraform `terraform_validate` hook | Handles init fallback, serial execution, error recovery |
| npm dependency scanning | Custom npm audit wrapper | Local hook with `npm audit --audit-level=high` | Already configured; simple entry point is sufficient |

## Common Pitfalls

### Pitfall 1: npm audit exit codes blocking all commits
**What goes wrong:** `npm audit --audit-level=high` exits non-zero when ANY high+ vulnerability exists, even if it's unfixable (no patch available). This blocks every commit touching package-lock.json.
**Why it happens:** npm audit is binary -- pass or fail. No way to allowlist known unfixable vulns inline.
**How to avoid:** Run `npm audit fix` first. If unfixable vulns remain, either lower to `--audit-level=critical` or accept the remaining vulns are low-severity. Current state: 2 high vulns, both fixable via `npm audit fix`.
**Warning signs:** Exit code 1 from npm audit when no new dependencies were added.

### Pitfall 2: terraform validate needs provider initialization
**What goes wrong:** `terraform validate` fails with "provider not installed" errors when `.terraform/` directory doesn't exist.
**Why it happens:** terraform validate checks provider references against installed providers.
**How to avoid:** The pre-commit-terraform hook script handles this automatically -- it tries validate first, and if it fails, runs `terraform init` then retries. First run in a directory will be slower (downloads providers). Subsequent runs use cached providers.
**Warning signs:** First-time hook execution takes 30+ seconds per directory (downloading providers).

### Pitfall 3: terraform_validate runs per-directory, not per-file
**What goes wrong:** Developer expects hook to validate individual files but it validates entire Terraform root modules.
**Why it happens:** Terraform validates at the module level, not file level. The hook discovers which directories contain changed `.tf` files and validates each directory.
**How to avoid:** Understand that the hook validates the directory containing the changed file. This means ALL files in that directory must be valid, not just the changed one.
**Warning signs:** Validation errors in files you didn't change.

### Pitfall 4: terraform_validate with modules that reference remote sources
**What goes wrong:** `terraform validate` fails because module sources can't be resolved without `terraform init -upgrade`.
**Why it happens:** Modules referencing remote git repos or registries need init to download.
**How to avoid:** The pre-commit-terraform hook's init fallback handles this. For terraform-pipelines, the examples reference local modules (`../../modules/default`), so init should resolve them locally.
**Warning signs:** "Module not installed" errors during validation.

### Pitfall 5: terraform-pipelines .pre-commit-config.yaml has hooks for non-terraform tools
**What goes wrong:** Copying the full `.pre-commit-config.yaml` to terraform-pipelines means ESLint, npm audit, ShellCheck, etc. try to run on a repo that has none of those file types, or worse, fail because Node.js tooling isn't configured there.
**Why it happens:** The config is designed for aws-zabbix-monitoring-solution which is a polyglot repo.
**How to avoid:** The full config can be deployed -- hooks only trigger when matching files are staged. No `.js`/`.ts` files means ESLint won't run. No `package-lock.json` means npm audit won't run. No `.sh` files means ShellCheck won't run. However, yamllint and markdownlint WILL run if those file types exist. Consider whether terraform-pipelines has YAML/MD files that might fail those hooks.
**Warning signs:** yamllint or markdownlint failures on files in terraform-pipelines.

### Pitfall 6: npm audit fix changes package-lock.json
**What goes wrong:** Running `npm audit fix` modifies package-lock.json, which must be committed. If the hook is already active, committing the changed package-lock.json triggers the hook again.
**Why it happens:** Circular dependency between fixing and committing.
**How to avoid:** This is actually fine -- `npm audit fix` resolves the vulnerabilities, so re-running `npm audit --audit-level=high` on the fixed package-lock.json should pass (exit 0). Just make sure to stage the updated package-lock.json AND any changed package.json together.
**Warning signs:** None -- this is expected behavior.

## Code Examples

### Running npm audit fix
```bash
# Source: verified against repos/aws-zabbix-monitoring-solution
cd repos/aws-zabbix-monitoring-solution
npm audit fix
# Verify clean
npm audit --audit-level=high
# Should exit 0
```

### Testing npm audit hook triggers
```bash
# Stage package-lock.json (after npm audit fix)
cd repos/aws-zabbix-monitoring-solution
git add package-lock.json package.json
pre-commit run npm-audit --files package-lock.json
# Should pass (exit 0)
```

### Cloning and setting up terraform-pipelines
```bash
cd repos/
gh repo clone OttawaCloudConsulting/terraform-pipelines
cd terraform-pipelines
# Copy pre-commit config
cp ../security-platform/.pre-commit-config.yaml .
# Update hook versions
pre-commit autoupdate
# Install hooks
pre-commit install
```

### Running terraform hooks against all files
```bash
cd repos/terraform-pipelines
pre-commit run terraform_fmt --all-files
# If formatting issues found, files are auto-fixed
# Stage fixes and re-run to verify clean
pre-commit run terraform_validate --all-files
# May take time on first run (terraform init downloads providers)
```

### Testing terraform_fmt catches violations
```bash
# Deliberately mis-format a .tf file
cd repos/terraform-pipelines/examples/default/minimal
# Add unformatted content, stage, and commit -- terraform_fmt should catch it
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual `terraform fmt` before commit | pre-commit-terraform auto-runs on staged .tf files | pre-commit-terraform has existed since 2017 | Eliminates forgotten formatting |
| `terraform validate` requires manual init | Hook script auto-inits on validation failure | pre-commit-terraform built-in | Removes friction from first-time validation |
| npm audit as manual check | Local pre-commit hook on package-lock.json changes | Custom local hook pattern | Only triggers on dependency changes, not every commit |

## Open Questions

1. **Will terraform-pipelines examples validate without AWS credentials?**
   - What we know: `terraform validate` checks syntax and internal consistency, not provider authentication. Examples reference local modules.
   - What's unclear: Whether any `.tf` files reference data sources or resources that require provider configuration beyond what init provides.
   - Recommendation: Try it. Validation should work without credentials for syntax checking. If a specific example fails, skip that directory or add `--args=--no-color` for cleaner output.

2. **Should terraform-pipelines use a feature branch?**
   - What we know: aws-zabbix-monitoring-solution uses `feature/add-pre-commit` branch. terraform-pipelines is being used as a test target.
   - What's unclear: Whether user wants formatting fixes pushed upstream.
   - Recommendation: Use a feature branch (`feature/add-pre-commit`) for consistency with the established pattern. This keeps main clean and allows PR review if desired.

3. **Will yamllint/markdownlint cause issues in terraform-pipelines?**
   - What we know: The full `.pre-commit-config.yaml` includes yamllint and markdownlint. terraform-pipelines has `README.md`, `CHANGELOG.md`, and likely YAML files.
   - What's unclear: Whether those files pass yamllint/markdownlint rules.
   - Recommendation: If they fail, either fix them (clean-slate pattern) or focus only on terraform hooks by running `pre-commit run terraform_fmt --all-files` and `pre-commit run terraform_validate --all-files` rather than `--all-files` for all hooks.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pre-commit (hook execution framework) |
| Config file | `.pre-commit-config.yaml` in each target repo |
| Quick run command | `pre-commit run <hook-id> --files <file>` |
| Full suite command | `pre-commit run --all-files` (per repo) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LINT-07 | npm audit triggers on package-lock.json changes | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run npm-audit --files package-lock.json` | N/A (hook-based) |
| LINT-08 | terraform fmt auto-formats HCL files | smoke | `cd repos/terraform-pipelines && pre-commit run terraform_fmt --all-files` | N/A (hook-based) |
| LINT-09 | terraform validate catches HCL syntax errors | smoke | `cd repos/terraform-pipelines && pre-commit run terraform_validate --all-files` | N/A (hook-based) |

### Sampling Rate
- **Per task commit:** Run specific hook against relevant files
- **Per wave merge:** `pre-commit run --all-files` in each target repo
- **Phase gate:** All three hooks pass cleanly; demonstrate each catches a deliberate violation

### Wave 0 Gaps
- [ ] Clone `terraform-pipelines` repo to `repos/terraform-pipelines/`
- [ ] Copy `.pre-commit-config.yaml` to terraform-pipelines
- [ ] Run `pre-commit install` in terraform-pipelines
- [ ] Run `npm audit fix` in aws-zabbix-monitoring-solution to clear existing violations

## Sources

### Primary (HIGH confidence)
- Verified npm audit output: ran `npm audit --audit-level=high` in aws-zabbix-monitoring-solution -- 2 high vulns (minimatch, fast-xml-parser), both fixable
- Verified terraform version: `terraform v1.14.7` installed
- Verified `.pre-commit-config.yaml` in both aws-zabbix-monitoring-solution and security-platform -- identical configs with all hooks
- Verified terraform-pipelines repo structure via GitHub API -- 36 `.tf` files across examples/, modules/, tests/
- [pre-commit-terraform hooks definition](https://github.com/antonbabenko/pre-commit-terraform/blob/master/.pre-commit-hooks.yaml) -- terraform_validate uses `require_serial: true`, auto-inits on failure
- [pre-commit-terraform validate script](https://raw.githubusercontent.com/antonbabenko/pre-commit-terraform/master/hooks/terraform_validate.sh) -- confirmed init fallback behavior

### Secondary (MEDIUM confidence)
- [antonbabenko/pre-commit-terraform GitHub](https://github.com/antonbabenko/pre-commit-terraform) -- README and hook documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all tools verified installed and working
- Architecture: HIGH -- hook configs already exist, repo structures confirmed via API
- Pitfalls: HIGH -- npm audit failure verified firsthand (exit code 1), terraform init behavior confirmed from source code

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (stable tools, no fast-moving dependencies)
