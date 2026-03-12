# ADR-005: Replace Plaintext Tokens with Environment Variables and GitHub Secrets

**Status:** Accepted
**Date:** 2026-02-24
**Addresses:** Red-team Convergent Finding #14

## Context

All DefectDojo import script examples in the original document used `DD_TOKEN="your-api-token"` as a literal inline shell variable assignment. All Nexus REST API setup examples used `NEXUS_AUTH="admin:your-password"`. A complete import script block assigned `DD_TOKEN="your-token"` at the top and used it across five separate `curl` calls importing Semgrep, Checkov, Trivy, Grype, and Gitleaks results. These are documentation examples that readers copy directly into real workflows. Credential examples that use literal placeholder strings get transcribed into scripts, committed to repositories, and exposed. Agent 1 rated this Critical: compromise of the DefectDojo API token allows an attacker to read, modify, delete, or fabricate all security findings — eliminating the entire value of the security stack. Agent 2 noted that no token rotation or storage guidance was provided.

## Decision

All DefectDojo token references in bash script examples are replaced with `${DEFECTDOJO_API_TOKEN}` environment variable syntax. All Nexus credential references are replaced with `${NEXUS_PASSWORD}` syntax. In GitHub Actions workflow sections, any token reference uses `${{ secrets.DEFECTDOJO_API_TOKEN }}` syntax. A setup note is added instructing the reader to store the token as a GitHub Actions secret named `DEFECTDOJO_API_TOKEN` via the repository Settings > Secrets and variables > Actions interface.

## Consequences

**Improved:** Script examples model secure credential handling. Tokens are never stored in the script files themselves, reducing the risk of accidental credential exposure through committed workflow files.

**Tradeoff:** One additional setup step is required before the import scripts are functional: the reader must create the GitHub secret and set the environment variable in their shell profile or CI environment. This is a minor and standard operational task.
