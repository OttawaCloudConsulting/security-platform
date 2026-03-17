# Milestone 1: User Guide

Day-to-day usage of the developer workstation security stack. This guide assumes all tools are installed per the [Installation Guide](INSTALLATION_GUIDE.md).

---

## How It Works

The workstation security stack operates in two tiers with an additional set of on-demand CLI tools:

```
                          git commit
                              │
                              ▼
               ┌──────────────────────────┐
               │  TIER 1: Quality Hooks   │
               │  9 linters run auto      │
               │  ~2-5 seconds            │
               └────────────┬─────────────┘
                            │ pass
                            ▼
                       local work
                            │
                          git push
                            │
                            ▼
               ┌──────────────────────────┐
               │  TIER 2: Secrets Gate    │
               │  Gitleaks pre-push       │
               │  blocks credentials      │
               └────────────┬─────────────┘
                            │ pass
                            ▼
                    pushed to remote

  CLI Tools (on demand):
  trivy · syft · grype · semgrep · checkov · gitleaks
```

---

## Tier 1: Automatic Quality Hooks

These hooks run automatically on every `git commit`. No action required — they fire when you commit.

### What Each Hook Does

| Hook | Language/Files | What It Catches | Auto-fixes? |
|------|---------------|-----------------|-------------|
| **terraform_fmt** | `.tf` files | Formatting inconsistencies | Yes |
| **terraform_validate** | `.tf` files | Invalid HCL syntax | No |
| **ruff** | `.py` files | Python lint violations | Yes (`--fix`) |
| **ruff-format** | `.py` files | Python formatting | Yes |
| **shellcheck** | `.sh`, `.bash` files | Shell scripting bugs, quoting issues | No |
| **hadolint** | `Dockerfile` | Docker best practice violations | No |
| **yamllint** | `.yaml`, `.yml` files | YAML syntax and style issues | No |
| **markdownlint** | `.md` files | Markdown style inconsistencies | No |
| **eslint** | `.js`, `.ts`, `.tsx`, `.jsx` files | JavaScript/TypeScript lint errors | No |
| **npm-audit** | `package-lock.json` | Known vulnerable dependencies | No |

### Normal Workflow

```bash
# 1. Make your changes
vim main.tf

# 2. Stage and commit — hooks fire automatically
git add main.tf
git commit -m "update VPC CIDR"

# Hooks run:
#   terraform_fmt .............. Passed
#   terraform_validate ......... Passed
#   shellcheck ................. Skipped (no .sh files staged)
#   ...
```

### When a Hook Fails

If a hook fails, the commit is blocked. Read the error output to understand the issue.

**Auto-fixing hooks** (terraform_fmt, ruff, ruff-format): The hook modifies the file automatically. Re-stage and commit:

```bash
git add -u
git commit -m "update VPC CIDR"
```

**Non-auto-fixing hooks** (shellcheck, hadolint, yamllint, etc.): Fix the reported issue manually, then re-stage and commit.

### Running Hooks Manually

Check all files without committing:

```bash
pre-commit run --all-files
```

Run a specific hook:

```bash
pre-commit run shellcheck --all-files
pre-commit run hadolint --all-files
```

### Suppressing False Positives

When a hook flags something that is intentionally correct, suppress it inline rather than disabling the rule globally.

**ShellCheck:**

```bash
# shellcheck disable=SC1091
source /etc/os-release
```

**hadolint:**

```dockerfile
# hadolint ignore=DL3008
RUN apt-get install -y curl
```

**markdownlint:** Adjust `.markdownlint.json` for project-wide rules. For inline suppression:

```markdown
<!-- markdownlint-disable MD013 -->
This very long line is intentional.
```

**ESLint:**

```typescript
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const data: any = response.body;
```

---

## Tier 2: Secrets Gate

Gitleaks runs automatically on every `git push`. It scans staged changes for credentials, API keys, tokens, and other secrets.

### Normal Workflow

```bash
git push origin main
# Gitleaks runs automatically — if clean, push proceeds
```

### When Gitleaks Blocks a Push

If Gitleaks detects a potential secret:

1. **Read the output** — it shows the file, line number, and rule that matched
2. **If it's a real secret:** Remove the secret from the file, use environment variables or a secrets manager instead. If the secret was committed to history, rotate the credential immediately
3. **If it's a false positive:** Add the fingerprint to `.gitleaksignore`:

   ```bash
   # Generate the report to get fingerprints
   gitleaks detect --source . --report-format json --report-path /tmp/gitleaks.json
   # Copy the fingerprint for the false positive into .gitleaksignore
   ```

### Bypass (Emergency Only)

```bash
git push --no-verify
```

This skips the Gitleaks hook entirely. The CI/CD pipeline (Milestone 2) runs Gitleaks server-side as a compensating control, so bypassed secrets will still be caught at the PR gate. Use this only when you are certain the finding is a false positive and need to push immediately.

---

## CLI Tools: On-Demand Scanning

Six security CLI tools are available for manual scanning. These are not automated — run them when you want deeper analysis before pushing or when investigating security posture.

### Trivy (Multi-Scanner)

Scans for vulnerabilities in dependencies, container images, IaC misconfigurations, and embedded secrets.

```bash
# Scan project dependencies for known vulnerabilities
trivy fs --scanners vuln .

# Scan a container image
trivy image my-app:latest

# Scan Terraform/CloudFormation for misconfigurations
trivy config ./infrastructure/

# JSON output for downstream processing
trivy fs --scanners vuln --format json --output trivy-results.json .
```

### Syft (SBOM Generation)

Generates a Software Bill of Materials listing every dependency and its version.

```bash
# Generate SBOM from project directory (CycloneDX format)
syft dir:. -o cyclonedx-json > sbom.json

# Generate SBOM from a container image
syft my-app:latest -o cyclonedx-json > sbom.json

# SPDX format (alternative standard)
syft dir:. -o spdx-json > sbom-spdx.json
```

### Grype (SCA Vulnerability Scanner)

Matches dependencies against vulnerability databases. Can consume Syft SBOMs directly.

```bash
# Scan project directory
grype dir:.

# Scan from an existing SBOM
grype sbom:sbom.json

# Fail if high or critical vulnerabilities found (useful in scripts)
grype dir:. --fail-on high

# JSON output
grype dir:. -o json > grype-results.json
```

### Semgrep CE (SAST)

Pattern-based static analysis using community-maintained rules. Fetches rules automatically from the Semgrep Registry (no login required).

```bash
# Scan with auto-detected rules for your languages
semgrep scan --config auto .

# Use a specific rule pack
semgrep scan --config p/python .
semgrep scan --config p/typescript .
semgrep scan --config p/terraform .

# JSON output
semgrep scan --config auto --json --output semgrep-results.json .

# SARIF output (for GitHub Security tab integration)
semgrep scan --config auto --sarif --output semgrep-results.sarif .
```

### Checkov (IaC Scanner)

Scans infrastructure-as-code for security misconfigurations. Covers Terraform, CloudFormation, CDK, Kubernetes, Helm, Dockerfile, and GitHub Actions.

```bash
# Scan a directory
checkov -d ./infrastructure/terraform

# Scan a single file
checkov -f Dockerfile

# Scan Kubernetes manifests
checkov -d ./k8s/

# JSON output
checkov -d . -o json > checkov-results.json

# Create a baseline (suppress all current findings, flag only new ones)
checkov -d . --create-baseline
checkov -d . --baseline .checkov.baseline
```

### Gitleaks (Secrets Detection)

Full repository secrets scan — deeper than the pre-push hook which only checks staged changes.

```bash
# Scan current files
gitleaks detect --source .

# Scan full git history (catches secrets in old commits)
gitleaks detect --source . --log-opts="--all"

# JSON report
gitleaks detect --source . --report-format json --report-path gitleaks-report.json
```

---

## Common Scenarios

### Starting a New Repository

```bash
cd /path/to/new-repo
# 1. Copy .pre-commit-config.yaml from the canonical source
# 2. Create .markdownlint.json and .markdownlintignore as needed
# 3. Activate hooks:
pre-commit install
pre-commit install --hook-type pre-push
# 4. Validate:
pre-commit run --all-files
```

### Updating Hook Versions

Pin versions drift over time. Monthly update:

```bash
pre-commit autoupdate        # bumps all rev: entries to latest tags
pre-commit run --all-files   # validate nothing broke
git add .pre-commit-config.yaml
git commit -m "chore: update pre-commit hook versions"
```

### Running a Full Security Scan Before a Release

```bash
# Dependency vulnerabilities
trivy fs --scanners vuln .

# Generate SBOM
syft dir:. -o cyclonedx-json > sbom.json

# Match SBOM against vulnerability databases
grype sbom:sbom.json

# Static analysis
semgrep scan --config auto .

# IaC misconfigurations
checkov -d .

# Secrets in full history
gitleaks detect --source . --log-opts="--all"
```

### Investigating a Specific Finding

All CLI tools support JSON output. Use `jq` to filter:

```bash
# Find high/critical Trivy findings
trivy fs --scanners vuln --format json . | jq '.Results[].Vulnerabilities[] | select(.Severity == "HIGH" or .Severity == "CRITICAL")'

# Find Semgrep findings by severity
semgrep scan --config auto --json . | jq '.results[] | select(.extra.severity == "ERROR")'

# List all Grype matches with fix available
grype dir:. -o json | jq '.matches[] | select(.vulnerability.fix.state == "fixed")'
```

---

## What Happens Next (Milestones 2-6)

The workstation tools are the first layer in a multi-layer security architecture:

| Layer | Milestone | What It Adds |
|-------|-----------|-------------|
| Workstation | **M1 (this)** | Pre-commit hooks + CLI tools |
| CI/CD | M2 | GitHub Actions PR gate with 5 parallel scan jobs, SARIF upload, branch protection |
| Artifact Management | M3 | Nexus Repository proxy on Kubernetes for npm, PyPI, Docker, Helm |
| Security Dashboard | M4 | DefectDojo on Kubernetes, automated CI-to-dashboard import |
| Infrastructure | M5 | NetworkPolicy, TLS, backups, monitoring |
| Runtime | M6 | Trivy Operator continuous scanning, Falco CE anomaly detection |

The CLI tools installed in M1 (Trivy, Syft, Grype, Semgrep, Checkov, Gitleaks) are the same tools that run in CI (M2) and feed findings into DefectDojo (M4). Local scans let you catch issues before they reach CI.
