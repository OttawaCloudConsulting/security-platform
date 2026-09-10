# Phase 9: Full Stack Validation - Research

**Researched:** 2026-03-16
**Domain:** pre-commit hook validation across multi-repo codebase
**Confidence:** HIGH

## Summary

Phase 9 is the final integration validation for Milestone 1. The task is to run `pre-commit run --all-files` in two target repositories (aws-zabbix-monitoring-solution and terraform-pipelines) on their `feature/add-pre-commit` branches and achieve exit code 0. A separate Gitleaks check validates the Tier 2 pre-push hook. One configuration change is required first: switching the hadolint hook from Docker-based (`hadolint-docker`) to native binary (`hadolint`).

The repos have very different profiles. aws-zabbix is a CDK project with ~17K JS/TS files (mostly in node_modules), shell scripts, Python, YAML, and Markdown. terraform-pipelines is pure infrastructure -- .tf files, shell scripts, YAML buildspecs, and Markdown docs. Many hooks will naturally skip in terraform-pipelines (ESLint, npm audit, hadolint) because no matching files exist. The main validation work will be in aws-zabbix where more hook types have matching files.

**Primary recommendation:** Start with the hadolint config change (all three repos), then run `--all-files` in each target repo sequentially, fixing or suppressing violations as they appear. Tackle aws-zabbix first (richer target), then terraform-pipelines (expected to be cleaner).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Two repos in scope:** aws-zabbix-monitoring-solution and terraform-pipelines on `feature/add-pre-commit` branches
- **security-platform skipped for validation** but receives hadolint config change (canonical source)
- **Merge to main is NOT part of Phase 9**
- **Fix first, suppress as last resort** -- genuine issues get code fixes; behavioral changes get inline suppression with comments
- **Inline annotations only** -- no separate suppression log or tracking file
- **Switch hadolint to native binary** (`brew install hadolint`) -- update hook ID from `hadolint-docker` to `hadolint` in all three repos
- **Run `terraform init` before `--all-files`** in terraform directories (established Phase 4 prereq)
- **Gitleaks validated separately** via `pre-commit run gitleaks --all-files --hook-stage pre-push`
- **Validation stamp per repo** in `docs/development-security-stack-option-1.md` -- no finding counts

### Claude's Discretion
- Order of hook remediation (which hooks to tackle first)
- Which hooks are relevant per repo (let pre-commit skip non-matching naturally, or identify upfront)
- Exact placement of validation stamp in main doc
- Handling of tool-specific warnings or non-fatal errors
- Environment prereq identification and resolution for each hook

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PCOM-04 | `pre-commit run --all-files` passes cleanly (all existing issues resolved or suppressed) | Full hook inventory, per-repo file type analysis, hadolint migration, terraform init prereqs, gitleaks separate validation -- all documented below |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| pre-commit | 4.5.0 | Hook framework | Already installed, orchestrates all hooks |
| hadolint | (latest via brew) | Dockerfile linting | Replacing Docker-based hadolint-docker hook |

### Supporting (already installed from prior phases)
| Tool | Version | Purpose | Repo Scope |
|------|---------|---------|------------|
| shellcheck-py | v0.11.0.1 | Shell script linting | aws-zabbix (3 scripts), terraform-pipelines (4 scripts) |
| ruff | v0.15.6 | Python linting + formatting | aws-zabbix (1 file), terraform-pipelines (none) |
| eslint | local (npx) | TypeScript/JavaScript linting | aws-zabbix only (CDK project) |
| yamllint | v1.38.0 | YAML linting (relaxed mode) | Both repos |
| markdownlint | v0.48.0 | Markdown linting | Both repos |
| pre-commit-terraform | v1.105.0 | terraform fmt + validate | terraform-pipelines (36 .tf files), aws-zabbix (none) |
| npm audit | local | Dependency audit | aws-zabbix only (has package-lock.json) |
| gitleaks | v8.30.1 | Secrets detection (pre-push) | Both repos |

**Installation (only new item):**
```bash
brew install hadolint
```

## Architecture Patterns

### Per-Repo Hook Relevance Matrix

Understanding which hooks will actually run (vs skip) in each repo is critical for planning:

| Hook | aws-zabbix | terraform-pipelines | Notes |
|------|-----------|---------------------|-------|
| terraform_fmt | SKIP (no .tf files) | RUN | 36 .tf files |
| terraform_validate | SKIP | RUN | Needs .terraform dirs (already present) |
| ruff | RUN | SKIP (no .py files) | 1 Python file |
| ruff-format | RUN | SKIP | Same file |
| shellcheck | RUN | RUN | 3 scripts / 4 scripts |
| hadolint | SKIP (no Dockerfiles*) | SKIP (no Dockerfiles) | *Only in node_modules, excluded by types filter |
| yamllint | RUN | RUN | .pre-commit-config.yaml + buildspecs |
| markdownlint | RUN | RUN | Many .md files in both |
| eslint | RUN | SKIP (no .js/.ts files) | CDK source files |
| npm-audit | RUN | SKIP (no package-lock.json) | Triggers on package-lock.json |
| gitleaks | RUN (separate) | RUN (separate) | Pre-push stage, tested separately |

### Remediation Workflow Pattern
```
For each repo:
  1. Ensure environment prereqs (terraform init, npm install, etc.)
  2. Run `pre-commit run --all-files`
  3. For each failing hook:
     a. Read the error output
     b. If auto-fixable (ruff, terraform_fmt): let auto-fix run, commit
     c. If genuine bug: fix the code
     d. If false positive or behavioral suggestion: suppress inline
  4. Re-run until exit 0
  5. Run gitleaks separately: `pre-commit run gitleaks --all-files --hook-stage pre-push`
```

### Config Change Pattern (hadolint)
```yaml
# BEFORE (all three repos)
  - repo: https://github.com/hadolint/hadolint
    rev: v2.14.0
    hooks:
      - id: hadolint-docker

# AFTER (all three repos)
  - repo: https://github.com/hadolint/hadolint
    rev: v2.14.0
    hooks:
      - id: hadolint
```

The `hadolint` hook uses `language: system` and `entry: hadolint` -- requires the native binary on PATH. The `hadolint-docker` hook uses `language: docker_image` and pulls the Docker image. Same rev, just different hook ID.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hook file filtering | Custom exclude patterns | Let pre-commit `types` and `files` filters do it | Pre-commit already handles .gitignore + type detection |
| Suppression tracking | Separate suppression log | Inline annotations (grep-discoverable) | User decision: inline only |
| Terraform init | Custom init script | Run `terraform init` manually per directory | Only needed once, .terraform dirs persist |

## Common Pitfalls

### Pitfall 1: node_modules triggering hooks
**What goes wrong:** Hooks match files inside `node_modules/` and fail on vendor code.
**Why it happens:** pre-commit's `--all-files` respects `.gitignore` only if files are not tracked. In aws-zabbix, `node_modules/` should be in `.gitignore`, but verify.
**How to avoid:** Confirm `node_modules/` is gitignored. If hook still matches, the `types` filter and `files` regex should limit scope. For markdownlint, `.markdownlintignore` already excludes `node_modules/`.
**Warning signs:** Thousands of files being checked by a hook that should only see a handful.

### Pitfall 2: ESLint failing without node_modules
**What goes wrong:** The ESLint hook is `language: system` with `entry: npx eslint` -- if `node_modules` doesn't exist or eslint isn't installed, it fails.
**Why it happens:** `npx eslint` requires the project's eslint + typescript-eslint packages.
**How to avoid:** Run `npm install` in aws-zabbix before running `--all-files`. Already confirmed node_modules exists.
**Warning signs:** "Cannot find module" or "npx: command not found" errors.

### Pitfall 3: terraform validate without init
**What goes wrong:** `terraform validate` requires providers to be installed. Without `.terraform/` directory, it fails.
**Why it happens:** `validate` checks HCL syntax including provider schemas.
**How to avoid:** terraform-pipelines already has `.terraform/` dirs in all 13 directories with .tf files. Verify they're current. If needed, run `terraform init` in each.
**Warning signs:** "Error: Could not satisfy plugin requirements" or "Plugin reinitialization required".

### Pitfall 4: yamllint on pre-commit-config.yaml itself
**What goes wrong:** yamllint may flag the `.pre-commit-config.yaml` file itself.
**Why it happens:** The `relaxed` preset is lenient but may still catch issues.
**How to avoid:** yamllint in relaxed mode allows most common patterns. If the config file has issues, fix them.
**Warning signs:** yamllint errors pointing at `.pre-commit-config.yaml`.

### Pitfall 5: markdownlint without config in terraform-pipelines
**What goes wrong:** markdownlint runs with default rules (strict) in terraform-pipelines, which has no `.markdownlint.json` or `.markdownlintignore`.
**Why it happens:** aws-zabbix has a tuned config disabling MD013/MD024/MD033/MD036/MD040/MD041/MD049. terraform-pipelines has no such config.
**How to avoid:** Copy the markdownlint config from aws-zabbix to terraform-pipelines, or create a minimal one. The same rules (especially MD013 for line length) will cause mass failures on documentation-heavy repos.
**Warning signs:** Hundreds of markdownlint violations on first run.

### Pitfall 6: cdk.out directory triggering hooks
**What goes wrong:** CDK synthesized output in `cdk.out/` can match hook file patterns.
**Why it happens:** `cdk.out/` contains generated JSON, JS, and template files.
**How to avoid:** Confirm `cdk.out/` is in `.gitignore`. The markdownlintignore already excludes it. ESLint config ignores it too.
**Warning signs:** Errors in files under `cdk.out/`.

## Code Examples

### Running pre-commit --all-files
```bash
# In each target repo on feature/add-pre-commit branch
cd repos/aws-zabbix-monitoring-solution
pre-commit run --all-files

# If hooks auto-fix files (ruff-format, terraform_fmt), stage and re-run
git add -A
pre-commit run --all-files
```

### Separate Gitleaks validation
```bash
# Gitleaks is pre-push stage, not triggered by default --all-files
pre-commit run gitleaks --all-files --hook-stage pre-push
```

### Inline suppression patterns (from prior phases)
```bash
# ShellCheck (Phase 2 pattern)
# shellcheck disable=SC2034  # AWS_PROFILE_FLAG is used by sourcing scripts
export AWS_PROFILE_FLAG="--profile ${AWS_PROFILE}"

# Python/Ruff
x = 1  # noqa: F841  -- intentionally unused for demonstration

# ESLint/TypeScript
// eslint-disable-next-line @typescript-eslint/no-unused-vars
```

### hadolint hook ID change
```yaml
# Change from hadolint-docker to hadolint in .pre-commit-config.yaml
  - repo: https://github.com/hadolint/hadolint
    rev: v2.14.0
    hooks:
      - id: hadolint    # was: hadolint-docker
```

### Validation stamp pattern (from Phases 6/7/8)
```markdown
Validated: `pre-commit run --all-files` passed (aws-zabbix, terraform-pipelines) -- 2026-03-16
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| hadolint-docker (Docker daemon required) | hadolint native binary (brew install) | Phase 9 decision | Removes Docker dependency for pre-commit |
| pre-commit-terraform v1.96.0 | v1.105.0 | Phase 4 autoupdate | Newer terraform hooks |

## Key Observations from Codebase Investigation

### aws-zabbix-monitoring-solution
- **Branch:** `feature/add-pre-commit` (confirmed)
- **File types:** ~17K JS/TS (mostly node_modules -- gitignored), 3 shell scripts, 1 Python file, 35 YAML, ~1K markdown
- **No Dockerfiles** outside vendor directories -- hadolint will skip
- **No .tf files** -- terraform hooks will skip
- **Configs present:** `.markdownlint.json` (7 rules disabled), `.markdownlintignore` (6 dirs excluded), `eslint.config.mjs` (recommended + ts), `.gitleaksignore` (40 entries)
- **node_modules exists** -- ESLint and npm audit should work

### terraform-pipelines
- **Branch:** `feature/add-pre-commit` (confirmed)
- **File types:** 36 .tf files, 13 .hcl, 23 .md, 4 .sh, 5 .yml, 14 .json, 14 .txt
- **No JS/TS, no Python, no Dockerfiles, no package-lock.json** -- ESLint, npm-audit, ruff, hadolint all skip
- **13 `.terraform/` directories** already initialized -- terraform validate should work
- **No markdownlint config** -- CRITICAL: will need one (see Pitfall 5)
- **No `.markdownlintignore`** -- may need one depending on content
- **Has `.gitleaksignore`** -- already configured from Phase 5

### security-platform (config change only)
- **Not a validation target** -- only receives hadolint hook ID change for consistency
- **Same `.pre-commit-config.yaml` structure** as other two repos

## Recommended Execution Order

1. **Install hadolint native binary** (`brew install hadolint`)
2. **Update hadolint hook ID** in all three repos' `.pre-commit-config.yaml` (hadolint-docker -> hadolint)
3. **Add markdownlint config** to terraform-pipelines (copy from aws-zabbix or create equivalent)
4. **Validate aws-zabbix** -- run `--all-files`, fix/suppress, iterate to exit 0
5. **Validate terraform-pipelines** -- run `--all-files`, fix/suppress, iterate to exit 0
6. **Validate Gitleaks** in both repos with `--hook-stage pre-push`
7. **Add validation stamp** to main doc

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pre-commit (hook execution framework) |
| Config file | `.pre-commit-config.yaml` per repo |
| Quick run command | `pre-commit run --all-files` (per repo) |
| Full suite command | `pre-commit run --all-files` + `pre-commit run gitleaks --all-files --hook-stage pre-push` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PCOM-04 | All hooks pass on full repo scan | integration | `cd repos/aws-zabbix-monitoring-solution && pre-commit run --all-files` | N/A (runtime) |
| PCOM-04 | All hooks pass on full repo scan | integration | `cd repos/terraform-pipelines && pre-commit run --all-files` | N/A (runtime) |
| PCOM-04 | Gitleaks pre-push passes | integration | `pre-commit run gitleaks --all-files --hook-stage pre-push` (each repo) | N/A (runtime) |

### Sampling Rate
- **Per task commit:** `pre-commit run --all-files` in the repo being worked on
- **Per wave merge:** Both repos pass `--all-files` + gitleaks
- **Phase gate:** Exit code 0 on all commands in both repos

### Wave 0 Gaps
- [ ] `brew install hadolint` -- native binary not yet installed
- [ ] markdownlint config for terraform-pipelines -- no `.markdownlint.json` exists
- [ ] Verify terraform-pipelines `.terraform/` dirs are current (providers may need refresh)

## Open Questions

1. **terraform-pipelines markdownlint config**
   - What we know: aws-zabbix has a tuned config disabling 7 rules; terraform-pipelines has none
   - What's unclear: Whether the same rule set applies or if terraform-pipelines needs different tuning
   - Recommendation: Start with the same config as aws-zabbix; adjust if needed based on violations

2. **npm audit current state**
   - What we know: Phase 4 ran `npm audit fix` and resolved high vulns
   - What's unclear: Whether new vulnerabilities have appeared since then
   - Recommendation: Run it and handle any new findings if they appear

3. **ESLint scope in aws-zabbix**
   - What we know: The hook matches `\.(js|jsx|ts|tsx)$` and node_modules is gitignored
   - What's unclear: Exactly which files ESLint will lint (CDK source vs test files)
   - Recommendation: Let it run and see what it reports; the `eslint.config.mjs` ignores `cdk.out/`

## Sources

### Primary (HIGH confidence)
- Direct filesystem inspection of all three repos (branches, file types, configs)
- `.pre-commit-config.yaml` in all three repos -- identical configs confirmed
- [hadolint/.pre-commit-hooks.yaml](https://github.com/hadolint/hadolint/blob/master/.pre-commit-hooks.yaml) -- confirmed `hadolint` hook ID uses `language: system`
- Prior phase CONTEXT.md files (Phases 2-5) for established suppression patterns

### Secondary (MEDIUM confidence)
- [hadolint pre-commit issue #886](https://github.com/hadolint/hadolint/issues/886) -- pre-commit hook installation behavior

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all tools already installed/configured from prior phases; only hadolint native is new
- Architecture: HIGH -- direct codebase inspection of both repos, file types enumerated
- Pitfalls: HIGH -- based on observed codebase state (missing markdownlint config, node_modules behavior)

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable -- pre-commit ecosystem moves slowly)
