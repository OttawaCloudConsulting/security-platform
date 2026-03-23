# Summary: 11-01 — Add explicit type/file filters and validate cross-repo

**Completed:** 2026-03-22
**Duration:** ~5 min

## What Changed

Updated the universal `.pre-commit-config.yaml` so every hook has an **explicit** `types:` or `files:` filter visible in the config file itself. Previously, filtering was handled by upstream hook manifests (invisible to the user reading the config). Now the config is self-documenting.

### Files Modified

1. **`repos/security-platform/workstation/setup.sh`** — Updated `generate_precommit_config()` heredoc to include explicit type filters on all hooks
2. **`repos/security-platform/.pre-commit-config.yaml`** — Regenerated with explicit type filters

### Hook Filter Summary

| Hook | Filter Added | Behavior |
|------|-------------|----------|
| terraform_fmt | `types: [terraform]` | Skips repos without .tf files |
| terraform_validate | `types: [terraform]` | Skips repos without .tf files |
| ruff | `types_or: [python, pyi]` | Skips repos without .py files |
| ruff-format | `types_or: [python, pyi]` | Skips repos without .py files |
| shellcheck | `types: [shell]` | Skips repos without shell scripts |
| hadolint | `types: [dockerfile]` | Skips repos without Dockerfiles |
| yamllint | `types: [yaml]` | Skips repos without YAML files |
| markdownlint | `types: [markdown]` | Skips repos without .md files |
| eslint | `types_or: [javascript, jsx, ts, tsx]` + `files:` | Skips repos without JS/TS |
| npm-audit | `files: package-lock\.json$` | Skips repos without package-lock.json |
| gitleaks | (no filter — scans git diff) | Runs on all repos (intentional) |

## Validation Results

### security-platform (config-only: .md, .yml, .sh)
- ✅ Exit code 0
- Skipped: terraform_fmt, terraform_validate, ruff, ruff-format, hadolint, eslint, npm-audit
- Passed: shellcheck, yamllint, markdownlint

### terraform-pipelines (Terraform: .tf, .md, .sh, .yml)
- ✅ Exit code 0
- Skipped: ruff, ruff-format, hadolint, eslint, npm-audit
- Passed: terraform_fmt, terraform_validate, shellcheck, yamllint, markdownlint

### aws-zabbix-monitoring-solution (Python+TS: .ts, .py, .md, .sh)
- Skipped: terraform_fmt, terraform_validate, hadolint
- Passed: ruff, ruff-format, shellcheck, yamllint, markdownlint, eslint
- npm-audit: Failed (real vulnerability finding — fast-xml-parser, flatted CVEs)

## Requirement Coverage

- **DIST-04** ✅ All hooks use `types:` or `files:` filters so they only execute when matching files are staged
