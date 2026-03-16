# security-platform

Canonical security configuration for OttawaCloudConsulting repositories.

## Contents

- `.pre-commit-config.yaml` — Pre-commit hook configuration (Tier 1 quality + Tier 2 secrets)

## Usage

Copy `.pre-commit-config.yaml` to target repository root, then:

    cd <target-repo>
    pre-commit install
    pre-commit install --hook-type pre-push
    pre-commit run --all-files

## Secrets Detection

Gitleaks runs as a **pre-push hook** — it scans staged changes for credentials and secrets before they reach the remote repository.

**If Gitleaks blocks your push:**
1. Review the finding — is it a real secret or a false positive?
2. Real secret: remove it, rotate the credential, then push again
3. False positive: add the fingerprint to `.gitleaksignore` (see format in that file)

**Bypass:** `git push --no-verify` skips the hook. Use only when you've verified the finding is a false positive and can't immediately update `.gitleaksignore`. CI will re-scan server-side (see ADR-011).
