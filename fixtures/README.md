# fixtures

INTENTIONALLY VULNERABLE SCAN FIXTURES. Every file in this directory is deliberately
insecure and exists solely as scanner input for the Phase 15/16/19 CI security jobs.
None of it must ever be "fixed", installed, deployed, or treated as real infrastructure
or application code — it is fixture data, not a real product.

## Structure

```
fixtures/
├── README.md            # This file
├── Dockerfile            # Container-scan target: digest-pinned debian:12-slim with unpatched CVEs
├── main.tf               # IaC-scan target: old AWS provider pin + misconfigured S3 bucket/security group
├── package.json          # SCA-scan target: vulnerable lodash + minimist pins
└── package-lock.json     # Generated lockfile — never hand-write this file
```

## Fixture Reference

| File | Consuming Job | Measured Finding Count (2026-09-10) |
|---|---|---|
| `Dockerfile` | Container scan (Trivy image) | 222 vulnerabilities (4 CRITICAL, 52 HIGH) |
| `main.tf` | IaC scan (Checkov) | 10 failed terraform checks |
| `package.json` + `package-lock.json` | SCA scan (Trivy fs) | 9 npm vulnerabilities |

Counts will drift upward over time as new CVEs publish against the pinned digest and
package versions — that is expected and does not indicate a broken fixture.

## Pre-commit Scoping

`fixtures/` is deliberately excluded (`exclude: ^fixtures/`) from four pre-commit hooks
so this intentionally-vulnerable content can be committed through the repo's own gates
without a blanket bypass:

- `terraform_fmt`
- `terraform_validate`
- `hadolint`
- `npm-audit`

The Gitleaks secrets hook is NOT excluded — no fixture ever contains a real secret, so
it is unaffected and continues to run normally.

## Regenerating the lockfile

```bash
cd fixtures && npm install --package-lock-only --ignore-scripts --no-audit --no-fund
```

`--package-lock-only` and `--ignore-scripts` ensure no package is ever downloaded,
installed, or executed — only lockfile metadata is fetched from the registry.
