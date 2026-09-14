## What v1 contains

Five parallel scan jobs, run on every push and pull request:

- `security / SAST — Semgrep CE`
- `security / IaC — Checkov`
- `security / SCA — Trivy Filesystem` (plus npm audit, pip-audit, and tflint where a matching manifest is present)
- `security / Container — Trivy Image` (conditional — only runs if a Dockerfile is discovered)
- `security / Secrets — Gitleaks`

`gate_mode` defaults to `report-only`. Six SARIF categories are uploaded to code scanning
(semgrep, checkov, trivy-fs, tflint, trivy-image, gitleaks). Five JSON/SARIF artifacts are
retained for 90 days. Ecosystem detection (npm, Python, Terraform, Docker) is inlined into the
workflow, so the caller repository needs no detector files of its own.

## Consuming this workflow

### Mode B — reusable workflow call (recommended)

Add one caller file to your repository, for example `.github/workflows/security.yml`:

```yaml
name: security

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  security-events: write
  actions: read

jobs:
  security:
    uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1
```

The caller's `permissions:` block is the CEILING for everything the called workflow can do.
Omitting `security-events: write` at the caller does not fail the run — it makes every SARIF
upload return 403 while the job still reports green. Set all three permissions shown above.

### Mode A — copy the files

Fetch `security.yml`, `pr-security.yml`, and `dependabot.yml` from this tag and place them in
your own `.github/` directory unmodified:

- `https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/.github/workflows/security.yml`
- `https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/.github/workflows/pr-security.yml`
- `https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/.github/dependabot.yml`

## Switching to blocking mode

`report-only` is the default and needs no action. To make findings fail the run:

```
gh variable set GATE_MODE --body blocking -R OWNER/REPO
```

No YAML edit is required — this is the one substitution point in the whole workflow.

## The five required check contexts

If you configure branch protection or a ruleset around this workflow, the five contexts to
require are exactly the job names above with the `security / ` prefix and an em dash
(U+2014), not a hyphen:

- `security / SAST — Semgrep CE`
- `security / IaC — Checkov`
- `security / SCA — Trivy Filesystem`
- `security / Container — Trivy Image`
- `security / Secrets — Gitleaks`

Renaming the `security` job in your caller file renames all five contexts at once.

## Tag semantics

`@v1` moves — it is repointed to each new `v1.x.y` release. `@v1.0.0` does not move; pin it
where an audit or a security-sensitive consumer needs an immutable reference. Do not add a
hand-written version comment beside a tag ref — Dependabot maintains comments on SHA pins, not
tag refs, so a hand-written one rots silently and stops matching reality.

## Private repositories

Measured directly, not inferred: on a private repository without GitHub Advanced Security
enabled, the `upload-sarif` step fails with "Code scanning is not enabled for this repository."
This is a GitHub Advanced Security licensing gate, not a token-scope problem — confirmed by an
in-workflow `GITHUB_TOKEN` read (granted `security-events: write`) hitting the identical 403 in
the same run. Measured in run `34802848411`. The five artifact-upload steps are unaffected;
only the six SARIF verify steps are guarded to skip on private repositories, and they are not
deleted.

## Adoption guide

The procedure of record for adopting this workflow, including a full walkthrough of both
consumption modes, lives in `docs/adoption-guide.md` in the `security_solution` documentation
repository.
