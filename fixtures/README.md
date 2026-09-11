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
├── main.tf               # IaC/pinning-scan target: old AWS provider pin + misconfigured S3 bucket/security
│                         #   group + unconstrained `random` provider + unpinned registry module
├── package.json          # SCA-scan target: vulnerable lodash + minimist pins
├── package-lock.json     # Generated lockfile — never hand-write this file
└── requirements.txt      # SCA-scan target: vulnerable requests + jinja2 pins — nothing installs it
```

## Fixture Reference

| File | Consuming Job | Measured Finding Count (2026-09-11) |
|---|---|---|
| `Dockerfile` | Container scan (Trivy image) | 222 vulnerabilities (4 CRITICAL, 52 HIGH, 88 MEDIUM, 72 LOW, 6 UNKNOWN) |
| `main.tf` | IaC scan (Checkov) | 12 failed terraform checks (was 10 — the unpinned module adds `CKV_TF_1` + `CKV_TF_2`) |
| `main.tf` | Pinning sub-scan (tflint) | 3 issues: `terraform_required_providers` (unconstrained `random`), `terraform_module_version` (`fixture_unpinned_module`), `terraform_required_version` (pre-existing, not a pinning issue) |
| `package.json` + `package-lock.json` | SCA scan (Trivy fs) | 9 npm vulnerabilities (1 CRITICAL, 4 HIGH, 4 MEDIUM) |
| `package.json` + `package-lock.json` | SCA sub-scan (npm audit `--audit-level=high`) | 2 advisories: 1 critical (minimist), 1 high (lodash) |
| `requirements.txt` | SCA scan (Trivy fs) | 10 pip vulnerabilities (1 HIGH, 9 MEDIUM) |
| `requirements.txt` | SCA sub-scan (pip-audit) | 46 advisory entries / 23 unique IDs across 4 vulnerable packages of 7 resolved dependencies |

The two `requirements.txt` rows report different numbers on purpose: `pip-audit -r` resolves the
transitive closure (`urllib3`, `idna`, `MarkupSafe`, …) while `trivy fs` reads only the two direct
`==` pins in the file. Inside pip-audit's own JSON every advisory is reported exactly twice — 46
entries are 23 unique advisories, so dedupe on `vulns[].id` before counting anything. Measured
2026-09-11 and not inferred: the 10 unique advisories pip-audit reports against the two direct pins
carry exactly Trivy's 10 `requirements.txt` CVE ids in their `aliases` — the same ten
vulnerabilities in two ID namespaces (`PYSEC-*` vs `CVE-*`), not a discrepancy. Neither figure is
wrong and the gap is not a broken scan. Note also that pip-audit emits no severity or CVSS field at
all, so no severity split can be quoted for that row.

Tool versions used for the 2026-09-11 measurement: Trivy 0.74.0, Checkov 3.2.396, tflint 0.61.0
(ruleset.terraform 0.14.1-bundled), pip-audit 2.10.1, npm 11.7.0.

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

**No hook fires on `requirements.txt`, and the four-hook list above is deliberately unchanged.**
Verified, not assumed: `ruff`/`ruff-format` are `types_or: [python, pyi]`, which does not match a
bare `requirements.txt`, and the `npm-audit` hook is `files: package-lock\.json$`. Running
`pre-commit run --files fixtures/requirements.txt` skips every hook. Do not "fix" this by adding a
fifth `exclude: ^fixtures/` entry — there is nothing to exclude.

## Regenerating the lockfile

```bash
cd fixtures && npm install --package-lock-only --ignore-scripts --no-audit --no-fund
```

`--package-lock-only` and `--ignore-scripts` ensure no package is ever downloaded,
installed, or executed — only lockfile metadata is fetched from the registry.
