# Milestone 1: Developer Workstation Foundation

## Goal

Every developer workstation has consistent linting, formatting, and secrets detection running on every commit. Security CLI tools are available locally for on-demand scanning. No infrastructure required.

## Prerequisites

- None. This is the starting milestone.
- Developer workstation with `brew`, `pip`, and `npm` available.

## Features

| ID | Feature | Components |
|----|---------|------------|
| M1-F1 | Pre-commit Tier 1 (quality/linting hooks) | pre-commit, ShellCheck, Ruff, ESLint, hadolint, yamllint, markdownlint-cli, npm audit, terraform fmt/validate |
| M1-F2 | Pre-commit Tier 2 (Gitleaks secrets gate) | Gitleaks |
| M1-F3 | Security CLI tool suite installation | Trivy, Syft, Grype, Semgrep CE, Checkov, Gitleaks |

---

### M1-F1: Pre-commit Tier 1 (Quality & Linting Hooks)

**Delivers:** Fast quality and linting checks on every commit — catches formatting, style, and syntax issues before they reach security scanners or CI.

**Key Components:**

- `pre-commit` framework
- `terraform_fmt` + `terraform_validate` (HCL formatting and validation)
- `shellcheck` (Bash/shell static analysis)
- `ruff` + `ruff-format` (Python linting and formatting)
- `eslint` (TypeScript/JavaScript linting)
- `hadolint-docker` (Dockerfile linting)
- `yamllint` (YAML/Kubernetes manifest linting)
- `markdownlint` (Markdown style linting)
- `npm audit` (lightweight dependency audit on `package-lock.json` changes only)

**Done Criteria:**

- `.pre-commit-config.yaml` committed to each target repository root with all Tier 1 hooks configured
- `pre-commit install` run in each repository
- `pre-commit run --all-files` passes cleanly (all existing issues resolved or suppressed)
- A test commit introducing an unquoted variable in a shell script is flagged by ShellCheck
- A test commit with a Python formatting violation is auto-fixed by Ruff

**Dependencies:** None.

---

### M1-F2: Pre-commit Tier 2 (Gitleaks Secrets Gate)

**Delivers:** Secrets detection on every push — credentials are caught regardless of branch context before they reach a remote.

**Key Components:**

- Gitleaks (pre-commit hook in `protect --staged` mode)

**Done Criteria:**

- Gitleaks hook is present in `.pre-commit-config.yaml` in the Tier 2 section
- A test commit containing a dummy AWS key pattern (e.g., `AKIAIOSFODNN7EXAMPLE`) is blocked by Gitleaks
- Developer understands that `--no-verify` bypasses this gate and that CI is the compensating control (per ADR-011)

**Dependencies:** M1-F1 (pre-commit framework must be installed first).

---

### M1-F3: Security CLI Tool Suite Installation

**Delivers:** All six security scanning CLIs available on the developer workstation for on-demand use and CI preparation.

**Key Components:**

- Trivy (container, filesystem, IaC, and secrets scanning)
- Syft (SBOM generation — CycloneDX, SPDX)
- Grype (SCA vulnerability scanning)
- Semgrep CE (SAST — pattern-based static analysis)
- Checkov (IaC scanning — Terraform, CloudFormation, K8s, Dockerfile)
- Gitleaks (secrets detection — full git history scan)

**Done Criteria:**

- All six tools are installed and on `$PATH`:
  - `trivy --version`
  - `syft version`
  - `grype version`
  - `semgrep --version`
  - `checkov --version`
  - `gitleaks version`
- Each tool can run a basic scan against the local repository without errors
- Developer can generate a JSON report from each tool (used in M2 and M4 for CI and DefectDojo import)

**Dependencies:** None.

---

## Milestone Verification

Run these checks to confirm M1 is complete:

1. **Pre-commit active:** `cd <repo> && pre-commit run --all-files` — all hooks pass
2. **Secrets gate working:** Stage a file containing `AKIA` + 16 alphanumeric characters, run `git commit` — Gitleaks blocks it
3. **CLI tools available:** Run `trivy fs --scanners vuln . && semgrep scan --config auto . && checkov -d . && grype dir:. && gitleaks detect --source .` — all produce output without install errors
4. **No infrastructure dependency:** All of the above works without any running server, cluster, or external service

## Reference

- Main document: Phase 1 — Developer Workstation (line ~1896)
- Main document: Shift-Left Linting Layer (line ~1115)
- Main document: Pre-commit Configuration (line ~1297)
- Main document: Tool Details sections 1–5 (lines ~154–378)
- [ADR-011: Pre-commit Bypass Warning](../adr/adr011-precommit-bypass-warning.md)
