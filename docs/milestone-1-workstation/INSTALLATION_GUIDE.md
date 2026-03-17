# Milestone 1: Installation Guide

Step-by-step installation of the developer workstation security stack. After completing this guide you will have pre-commit hooks enforcing code quality on every commit, a Gitleaks secrets gate on every push, and six security CLI tools ready for on-demand scanning.

## Prerequisites

| Requirement | Minimum | Verify |
|-------------|---------|--------|
| macOS or Linux | macOS 13+ / Ubuntu 22.04+ | `uname -a` |
| Homebrew | 4.x | `brew --version` |
| Python 3 | 3.10+ | `python3 --version` |
| pip | 23+ | `pip --version` |
| Node.js | 18+ | `node --version` |
| npm | 9+ | `npm --version` |
| Git | 2.30+ | `git --version` |
| Terraform | 1.5+ | `terraform --version` |

All tools installed below are free and open-source. No accounts, logins, or API keys required.

---

## Part 1: Pre-commit Framework

### 1.1 Install pre-commit

```bash
pip install pre-commit --break-system-packages
```

Verify:

```bash
pre-commit --version
# Expected: pre-commit 4.5.0 or higher
```

### 1.2 Create the hook configuration

Place `.pre-commit-config.yaml` in the root of each target repository. The canonical configuration:

```yaml
# .pre-commit-config.yaml

# ─────────────────────────────────────────────────────────────────────────────
# TIER 1: Quality & Linting
# Fast checks — run on every commit. Catch formatting, style, and syntax issues
# before they reach security scanners or CI.
# ─────────────────────────────────────────────────────────────────────────────
repos:

  # --- Terraform: formatting and validation ---
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.105.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate

  # --- Python: Ruff (replaces flake8, black, isort) ---
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.15.6
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  # --- Bash / Shell: ShellCheck ---
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.11.0.1
    hooks:
      - id: shellcheck

  # --- Dockerfile: hadolint ---
  - repo: https://github.com/hadolint/hadolint
    rev: v2.14.0
    hooks:
      - id: hadolint

  # --- YAML / Kubernetes manifests: yamllint ---
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.38.0
    hooks:
      - id: yamllint
        args: [-d, relaxed]

  # --- Markdown: markdownlint ---
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.48.0
    hooks:
      - id: markdownlint

  # --- TypeScript / JavaScript: ESLint (local — requires eslint in project) ---
  - repo: local
    hooks:
      - id: eslint
        name: eslint
        entry: npx eslint
        language: system
        files: \.(js|jsx|ts|tsx)$
        pass_filenames: true

  # --- npm: lightweight dependency audit (triggers on package-lock.json changes only) ---
  - repo: local
    hooks:
      - id: npm-audit
        name: npm audit
        entry: npm audit --audit-level=high
        language: system
        files: package-lock\.json$
        pass_filenames: false

# ─────────────────────────────────────────────────────────────────────────────
# TIER 2: Secrets Gate
# Secrets are the only pre-commit security check. A credential pushed to any
# branch is a potential exposure regardless of context. SAST (Semgrep CE) and
# IaC scanning (Checkov) run at the Pull Request gate in GitHub Actions instead.
# ─────────────────────────────────────────────────────────────────────────────

  # --- Secrets detection: Gitleaks ---
  # Bypass: git push --no-verify skips this hook — CI is the compensating control
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
        stages: [pre-push]
        args: [protect, --staged]
```

### 1.3 Activate hooks

In each target repository:

```bash
cd /path/to/your/repo
pre-commit install       # activates Tier 1 hooks on git commit
pre-commit install --hook-type pre-push  # activates Tier 2 Gitleaks on git push
```

### 1.4 Install hadolint native binary

The `hadolint` hook requires the native binary on PATH (not the Docker variant):

```bash
brew install hadolint
```

Verify:

```bash
hadolint --version
# Expected: Haskell Dockerfile Linter 2.14.0
```

---

## Part 2: Linter Configuration Files

### 2.1 ESLint (TypeScript/JavaScript repos only)

For repos with TypeScript or JavaScript, install ESLint and create the flat config:

```bash
npm install --save-dev @eslint/js typescript-eslint
```

Create `eslint.config.mjs`:

```javascript
// @ts-check
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  eslint.configs.recommended,
  tseslint.configs.recommended,
  {
    ignores: ['cdk.out/**', 'jest.config.js'],
  },
);
```

### 2.2 Markdownlint

Create `.markdownlint.json` in each repo to suppress rules that produce false positives:

```json
{
  "MD013": false,
  "MD024": false,
  "MD033": false,
  "MD036": false,
  "MD040": false,
  "MD041": false,
  "MD049": false,
  "MD060": false
}
```

For repos with generated content or vendor directories, create `.markdownlintignore`:

```
.claude/
.obsidian/
.planning/
agents/
node_modules/
cdk.out/
.terraform/
```

### 2.3 Gitleaks (false positive suppression)

If Gitleaks flags known false positives, create `.gitleaksignore` in the repo root:

```
# Format: fingerprint (from gitleaks detect --report-format json)
# Each line is a SHA256 fingerprint of a known false positive
```

Generate fingerprints from the JSON report:

```bash
gitleaks detect --source . --report-format json --report-path /tmp/gitleaks.json
# Review the report, then add fingerprints for confirmed false positives
```

---

## Part 3: Security CLI Tools

### 3.1 SCA and Container Tools

```bash
brew install trivy syft grype
```

Verify each tool:

```bash
trivy --version
# Expected: Version: 0.69.3 or higher

syft version
# Expected: 1.42.2 or compatible

grype version
# Expected: 0.109.1 or higher (requires DB schema v6)
```

### 3.2 SAST and IaC Tools

```bash
pip install semgrep --break-system-packages
pip install checkov --break-system-packages
brew install gitleaks
```

Verify each tool:

```bash
semgrep --version
# Expected: 1.155.0 or compatible

checkov --version
# Expected: 3.2.396 or compatible

gitleaks version
# Expected: 8.30.0 or compatible
```

---

## Part 4: Validation

### 4.1 Validate all hooks pass

Run against all files in each target repository:

```bash
cd /path/to/your/repo
pre-commit run --all-files
```

Expected: all applicable hooks show `Passed` or `Skipped` (hooks skip when the repo contains no matching file types). Exit code must be 0.

### 4.2 Validate Gitleaks detects secrets

```bash
gitleaks detect --source .
# Expected: "no leaks found" for a clean repo
```

### 4.3 Validate CLI tools produce JSON

Run each tool and confirm valid JSON output:

```bash
trivy fs --scanners vuln --format json --output /tmp/trivy.json .
syft dir:. -o cyclonedx-json > /tmp/sbom.json
grype dir:. -o json > /tmp/grype.json
semgrep scan --config auto --json --output /tmp/semgrep.json .
checkov -d . -o json > /tmp/checkov.json
gitleaks detect --source . --report-format json --report-path /tmp/gitleaks.json
```

Quick validation that each file is valid JSON:

```bash
for f in /tmp/trivy.json /tmp/sbom.json /tmp/grype.json /tmp/semgrep.json /tmp/checkov.json /tmp/gitleaks.json; do
  python3 -c "import json; json.load(open('$f'))" && echo "$f: valid" || echo "$f: INVALID"
done
```

---

## Installed Tool Summary

| Tool | Version | Install Method | Purpose |
|------|---------|---------------|---------|
| pre-commit | 4.5.0 | pip | Hook framework |
| ShellCheck | 0.11.0.1 | pre-commit (auto) | Bash/shell linting |
| Ruff | 0.15.6 | pre-commit (auto) | Python linting + formatting |
| ESLint | local | npm (per-project) | TypeScript/JavaScript linting |
| hadolint | 2.14.0 | brew | Dockerfile best practices |
| yamllint | 1.38.0 | pre-commit (auto) | YAML/Kubernetes linting |
| markdownlint | 0.48.0 | pre-commit (auto) | Markdown style |
| terraform fmt | (bundled) | terraform CLI | HCL formatting |
| terraform validate | (bundled) | terraform CLI | HCL syntax |
| Gitleaks | 8.30.1 (hook) / 8.30.0 (CLI) | brew + pre-commit | Secrets detection |
| Trivy | 0.69.3 | brew | Multi-scanner (container, fs, IaC, secrets) |
| Syft | 1.42.2 | brew | SBOM generation |
| Grype | 0.109.1 | brew | SCA vulnerability scanning |
| Semgrep CE | 1.155.0 | pip | SAST pattern analysis |
| Checkov | 3.2.396 | pip | IaC scanning |

---

## Troubleshooting

### Hook fails to download on first commit

Pre-commit downloads hook environments on first run. If it fails:

```bash
pre-commit clean    # clear cached environments
pre-commit install-hooks  # pre-download all hooks
```

### hadolint hook fails with "executable not found"

The hook uses the native binary, not Docker. Install via Homebrew:

```bash
brew install hadolint
```

### ESLint hook fails with "eslint: command not found"

The ESLint hook is a `local` hook — it requires ESLint installed in the project:

```bash
npm install --save-dev @eslint/js typescript-eslint
```

### Grype database error

Grype requires DB schema v6. If you see schema errors, upgrade:

```bash
brew upgrade grype
grype db update
```

### Semgrep rule download timeout

Semgrep fetches community rules on first scan. For slow connections:

```bash
semgrep --config auto --dump-config > /tmp/rules.yaml   # download once
semgrep scan --config /tmp/rules.yaml .                  # use local copy
```
