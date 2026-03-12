# Draft Agent A — Features 1, 7, 9

---
## FEATURE 1: REPLACE GitHub Actions workflow
<!-- ANCHOR: replaces the complete ```yaml block starting with "# .github/workflows/security.yml" in the "Complete GitHub Actions Workflow" section -->

```yaml
# .github/workflows/security.yml
name: Security Scans

# Primary trigger: Pull Requests to any branch (the main enforcement gate).
# Secondary trigger: Direct pushes to main (safety net for non-PR merges).
on:
  pull_request:
  push:
    branches: [main]

# ─────────────────────────────────────────────────────────────────────────────
# SHA PINNING NOTE
#
# All GitHub Actions below are pinned to immutable SHA digests rather than
# mutable version tags (e.g. @v4, @master). Mutable tags can be silently
# updated by the action maintainer — intentionally or after a supply-chain
# compromise — and your workflow will execute the changed code without notice.
# SHA pinning ensures you run exactly the code you reviewed.
#
# To keep SHAs current without manual tracking, enable Dependabot for
# GitHub Actions in your repository:
#
#   Create .github/dependabot.yml:
#     version: 2
#     updates:
#       - package-ecosystem: "github-actions"
#         directory: "/"
#         schedule:
#           interval: "monthly"
#
# Dependabot will open PRs updating SHA digests when new versions are
# released. Review the release notes before merging. Alternatively, Renovate
# Bot supports the same workflow with more configuration options.
#
# To find the current SHA for any action, run:
#   gh api repos/<owner>/<repo>/git/ref/tags/<version> --jq '.object.sha'
# or visit the action's releases page and copy the "full commit SHA" shown
# next to each release tag.
# ─────────────────────────────────────────────────────────────────────────────

jobs:
  sast:
    name: SAST — Semgrep CE
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
      - run: pip install semgrep
      - name: Run Semgrep (JSON output for DefectDojo)
        run: semgrep scan --config auto --error --json --output semgrep-results.json .
      - name: Run Semgrep (SARIF output for GitHub Security tab)
        if: always()
        run: semgrep scan --config auto --sarif --output semgrep.sarif . || true
      - uses: github/codeql-action/upload-sarif@<SHA>  # v3 — pin to current SHA: https://github.com/github/codeql-action/releases
        if: always()
        continue-on-error: true
        with: { sarif_file: semgrep.sarif }
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: semgrep-results, path: semgrep-results.json }

  iac:
    name: IaC — Checkov
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
      - uses: bridgecrewio/checkov-action@<SHA>  # v12 — pin to current SHA: https://github.com/bridgecrewio/checkov-action/releases
        with:
          directory: .
          output_format: cli,json,sarif
          output_file_path: console,checkov-results.json,checkov.sarif
          quiet: true
          soft_fail: false
      - uses: github/codeql-action/upload-sarif@<SHA>  # v3 — pin to current SHA: https://github.com/github/codeql-action/releases
        if: always()
        continue-on-error: true
        with: { sarif_file: checkov.sarif }
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: checkov-results, path: checkov-results.json }

  sca:
    name: SCA — Grype
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
      - run: |
          curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
            | sh -s -- -b /usr/local/bin
      - name: Run Grype (fails on high/critical findings)
        run: grype dir:. --fail-on high -o json > grype-results.json
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: grype-results, path: grype-results.json }

  container:
    name: Container — Trivy
    runs-on: ubuntu-latest
    # Runs on both pull_request and push events so container vulnerabilities
    # are visible to reviewers before merge, not only after.
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
      - run: docker build -t app:${{ github.sha }} .
      - name: Run Trivy (JSON output for DefectDojo)
        uses: aquasecurity/trivy-action@<SHA>  # pin to current SHA: https://github.com/aquasecurity/trivy-action/releases
        with:
          image-ref: 'app:${{ github.sha }}'
          format: json
          output: trivy-results.json
          exit-code: '1'
          severity: 'HIGH,CRITICAL'
      - name: Run Trivy (SARIF output for GitHub Security tab)
        if: always()
        uses: aquasecurity/trivy-action@<SHA>  # pin to current SHA: https://github.com/aquasecurity/trivy-action/releases
        with:
          image-ref: 'app:${{ github.sha }}'
          format: sarif
          output: trivy.sarif
      - uses: github/codeql-action/upload-sarif@<SHA>  # v3 — pin to current SHA: https://github.com/github/codeql-action/releases
        if: always()
        continue-on-error: true
        with: { sarif_file: trivy.sarif }
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: trivy-results, path: trivy-results.json }

  secrets:
    name: Secrets — Gitleaks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>  # v4 — pin to current SHA: https://github.com/actions/checkout/releases
        with: { fetch-depth: 0 }
      - run: |
          curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz \
            | tar xz -C /usr/local/bin gitleaks
      - name: Run Gitleaks (fails on any secret found)
        run: gitleaks detect --source . --report-path gitleaks-results.json --report-format json
      - uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: https://github.com/actions/upload-artifact/releases
        if: always()
        continue-on-error: true
        with: { name: gitleaks-results, path: gitleaks-results.json }
```

---
## FEATURE 7: INSERT after .pre-commit-config.yaml block
<!-- ANCHOR: insert immediately after the closing ``` of the .pre-commit-config.yaml block, before the "```bash" install commands -->

### Keeping Hooks Current

Pinned hook versions (`rev: v8.21.2`, `rev: v0.8.4`, etc.) provide reproducibility but require active maintenance — a version pinned today accumulates unpatched bugs and missing detection rules over time. Run `pre-commit autoupdate` monthly to bump all `rev:` entries to their latest upstream tags:

```bash
pre-commit autoupdate        # updates all rev: entries in .pre-commit-config.yaml
pre-commit run --all-files   # validate nothing broke after the update
```

Commit the resulting changes to `.pre-commit-config.yaml` as a routine maintenance commit. For GitHub Actions SHA digests, Dependabot or Renovate automates the equivalent process — configure either tool with a monthly schedule (see the SHA pinning note in the workflow file) so action versions track upstream releases without manual monitoring across 20+ components.

---
## FEATURE 9: INSERT before Pre-commit Configuration section
<!-- ANCHOR: insert immediately before the "## Pre-commit Configuration" heading -->

> **Client-Side Enforcement Limitation:** Pre-commit hooks run entirely on the developer workstation and can be bypassed with `git commit --no-verify` or `git push --no-verify`, including the Gitleaks secrets gate. The Phase 2 GitHub Actions workflow is the compensating control — Gitleaks runs again in CI against the full repository history, and Semgrep/Checkov/Grype run at the PR gate regardless of what happened locally. The only mechanism that cannot be bypassed client-side is branch protection with required CI checks: without it, the CI gate is advisory. Use pre-commit as the fast inner loop it is designed to be; rely on the CI gate and branch protection for enforcement.

---
## FEATURE 1 ADDENDUM: REPLACE DefectDojo import script
<!-- ANCHOR: replaces the bash script block starting with "#!/bin/bash" under "Import script for DefectDojo:" -->

```bash
#!/bin/bash
# Set DEFECTDOJO_API_TOKEN as a GitHub Actions secret or export it locally:
#   export DEFECTDOJO_API_TOKEN="your-token-here"
# In GitHub Actions, reference it as: ${{ secrets.DEFECTDOJO_API_TOKEN }}
DD_URL="http://localhost:8080"
DD_TOKEN="${DEFECTDOJO_API_TOKEN}"
PRODUCT="My App"
ENGAGEMENT="CI-$(date +%Y%m%d)"

for scan in \
  "Semgrep JSON Report:semgrep-results.json" \
  "Checkov Scan:checkov-results.json" \
  "Anchore Grype:grype-results.json" \
  "Trivy Scan:trivy-results.json" \
  "Gitleaks Scan:gitleaks-results.json"; do
  TYPE="${scan%%:*}"; FILE="${scan##*:}"
  [ -f "$FILE" ] && curl -s -X POST "${DD_URL}/api/v2/import-scan/" \
    -H "Authorization: Token ${DD_TOKEN}" \
    -F "scan_type=${TYPE}" -F "file=@${FILE}" \
    -F "product_name=${PRODUCT}" -F "engagement_name=${ENGAGEMENT}" \
    -F "auto_create_context=True" && echo "Imported: ${TYPE}"
done
```
