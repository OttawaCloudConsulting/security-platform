# Summary: 12-01 — Fix bash 3.2 compat, add require_git_repo call, add .markdownlintignore

**Completed:** 2026-03-22
**Duration:** ~10 min

## What Changed

Three targeted fixes to `repos/security-platform/workstation/setup.sh`:

### 1. Bash 3.2 compatibility (Bug fix)

Replaced two `declare -A` associative arrays (`TOOL_REPOS`, `HOOK_REPOS`) with plain `REPO_*` and `HOOK_REPO_*` variables. Also replaced `${!var}` indirect expansion with `eval` in the v-prefix loop. The script now parses and runs cleanly under `/bin/bash` (macOS stock bash 3.2.57).

### 2. Git repo validation (Bug fix)

Added `require_git_repo` calls before the `configure` and `setup` case branches. Running `bash setup.sh configure` outside a git repo now produces: `ERROR: Not inside a git repository. Run this from a repo root.` and exits 1. The `install` and `check` commands intentionally don't require a git repo.

### 3. `.markdownlintignore` generation (Gap closure)

Added `generate_markdownlintignore()` function using the existing `write_config` pattern (skip if file exists). Generates a `.markdownlintignore` with common directory excludes: `node_modules/`, `.terraform/`, `.planning/`, `.claude/`, `cdk.out/`. Wired into `generate_all_configs()` — the `configure` command now creates 6 files instead of 5.

## Validation Results

| Test | Result |
|------|--------|
| `/bin/bash -n setup.sh` (syntax check) | ✅ Exit 0 — no parse errors |
| `configure` in fresh git repo | ✅ 6 config files created |
| `configure` second run (idempotency) | ✅ "All configuration files already exist — no changes made" |
| User-added `.gitleaksignore` fingerprints preserved | ✅ Content intact after re-run |
| User-added `.markdownlintignore` entries preserved | ✅ Content intact after re-run |
| `configure` outside git repo | ✅ "ERROR: Not inside a git repository" + exit 1 |
| `setup` in fresh git repo | ✅ Tools verified + 6 configs + hooks installed |
| No bash 4+ constructs remaining | ✅ Zero instances of `declare -A`, `${!var}`, `mapfile`, `|&` |

## Requirement Coverage

- **DIST-01** ✅ Drops `.pre-commit-config.yaml` with explicit type filters
- **DIST-02** ✅ Drops all applicable linting configs (markdownlint ×3, gitleaksignore, markdownlintignore; yamllint/hadolint/ruff/eslint use defaults or hook args)
- **DIST-03** ✅ Runs `pre-commit install` + `pre-commit install --hook-type pre-push`
- **DIST-05** ✅ Idempotent — all generators skip existing files, user customizations preserved
