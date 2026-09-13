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
├── requirements.txt      # SCA-scan target: vulnerable requests + jinja2 pins — nothing installs it
├── secret.env            # Secrets-scan target (Gitleaks): synthetic AWS credentials — also read by the SAST scan
└── vulnerable.py         # SAST-scan target (Semgrep CE): eval/exec/subprocess shell=True — never imported or run
```

## Fixture Reference

| File | Consuming Job | Measured Finding Count (2026-09-11 unless the row states another date) |
|---|---|---|
| `Dockerfile` | Container scan (Trivy image) | 222 vulnerabilities (4 CRITICAL, 52 HIGH, 88 MEDIUM, 72 LOW, 6 UNKNOWN) |
| `main.tf` | IaC scan (Checkov) | 12 failed terraform checks (was 10 — the unpinned module adds `CKV_TF_1` + `CKV_TF_2`) |
| `main.tf` | Pinning sub-scan (tflint) | 3 issues: `terraform_required_providers` (unconstrained `random`), `terraform_module_version` (`fixture_unpinned_module`), `terraform_required_version` (pre-existing, not a pinning issue) |
| `package.json` + `package-lock.json` | SCA scan (Trivy fs) | 9 npm vulnerabilities (1 CRITICAL, 4 HIGH, 4 MEDIUM) |
| `package.json` + `package-lock.json` | SCA sub-scan (npm audit `--audit-level=high`) | 2 advisories: 1 critical (minimist), 1 high (lodash) |
| `requirements.txt` | SCA scan (Trivy fs) | 10 pip vulnerabilities (1 HIGH, 9 MEDIUM) |
| `requirements.txt` | SCA sub-scan (pip-audit) | 46 advisory entries / 23 unique IDs across 4 vulnerable packages of 7 resolved dependencies |
| `secret.env` | Secrets scan (Gitleaks) | Measured 2026-09-12 against gitleaks 8.30.1 — 2 findings: `aws-access-token` (named rule, deterministic) and `generic-api-key` (entropy 5.22, NOT version-stable) |
| `secret.env` | SAST scan (Semgrep CE) | Measured 2026-09-12 against semgrep 1.177.0 — 2 findings: `generic.secrets.security.detected-aws-access-key-id-value.detected-aws-access-key-id-value` and `generic.secrets.security.detected-aws-secret-access-key.detected-aws-secret-access-key` |
| `vulnerable.py` | SAST scan (Semgrep CE) | Measured 2026-09-12 against semgrep 1.177.0 — 3 findings, all named: `python.lang.security.audit.eval-detected.eval-detected`, `python.lang.security.audit.exec-detected.exec-detected`, `python.lang.security.audit.subprocess-shell-true.subprocess-shell-true` |

The two `requirements.txt` rows report different numbers on purpose: `pip-audit -r` resolves the
transitive closure (`urllib3`, `idna`, `MarkupSafe`, …) while `trivy fs` reads only the two direct
`==` pins in the file. Inside pip-audit's own JSON every advisory is reported exactly twice — 46
entries are 23 unique advisories, so dedupe on `vulns[].id` before counting anything. Measured
2026-09-11 and not inferred: the 10 unique advisories pip-audit reports against the two direct pins
carry exactly Trivy's 10 `requirements.txt` CVE ids in their `aliases` — the same ten
vulnerabilities in two ID namespaces (`PYSEC-*` vs `CVE-*`), not a discrepancy. Neither figure is
wrong and the gap is not a broken scan. Note also that pip-audit emits no severity or CVSS field at
all, so no severity split can be quoted for that row.

`vulnerable.py` reports THREE findings, not five, and that is the correct number. `os.system()`
and `os.popen()` in that file are DELIBERATELY SILENT under `p/default` — measured 2026-09-12,
zero findings each — and are kept for shape, not for signal, the same convention as the exact
provider pin in `main.tf`. Three is not a fixture that half-broke; do not "fix" it, and do not
raise the expected count to five. The two `secret.env` rows are also not a duplicate: one file
is read by two different jobs, so it carries one row per consuming job exactly as `main.tf` and
`package.json` do.

Tool versions used for the 2026-09-11 measurement: Trivy 0.74.0, Checkov 3.2.396, tflint 0.61.0
(ruleset.terraform 0.14.1-bundled), pip-audit 2.10.1, npm 11.7.0.

Tool versions used for the 2026-09-12 measurement of the three rows that carry that date:
semgrep 1.177.0 and gitleaks 8.30.1 — the versions the `sast` and `secrets` CI jobs pin.

Counts will drift upward over time as new CVEs publish against the pinned digest and
package versions — that is expected and does not indicate a broken fixture; and for Semgrep
the drift source is not only the CVE feed but the `p/default` RULESET itself, which is
resolved from the semgrep.dev registry at scan time, so a rule can be renamed, retired or
added without anything in this repository changing.

## Pre-commit Scoping

`fixtures/` is deliberately excluded (`exclude: ^fixtures/`) from four pre-commit hooks
so this intentionally-vulnerable content can be committed through the repo's own gates
without a blanket bypass:

- `terraform_fmt`
- `terraform_validate`
- `hadolint`
- `npm-audit`

The Gitleaks secrets hook is NOT excluded, and that is deliberate. `fixtures/secret.env` does
now carry credential-shaped values, but they are SYNTHETIC and have never existed in any AWS
account, so "no fixture contains a real secret" remains true.

Measured 2026-09-13, not assumed: **the pre-commit hook does not block this fixture, and that is
a property of the hook, not of the fixture.** The hook is `stages: [pre-push]`, so it never runs
at `git commit`; and its entry is `gitleaks git --pre-commit --redact --staged --verbose`, which
scans the STAGED diff — at push time nothing is staged, so it reports `0 commits scanned` /
`no leaks found` and Passes. Observed: `pre-commit run gitleaks --hook-stage pre-push
--all-files` exits 0 on a tree containing this fixture.

Do not read that as the fixture being undetectable. The CI `secrets` job runs `gitleaks git .`
over full history with gitleaks 8.30.1 and DOES report `aws-access-token` at
`fixtures/secret.env` (measured 2026-09-12). The pre-push hook pins v8.30.0 and is a different
invocation from the CI job — never quote one as evidence about the other.

Bypass, should the hook ever fire: `git push --no-verify` skips it — CI is the compensating
control. Do NOT add this file's fingerprint to `.gitleaksignore`: CI reads that file too, so the
suppression would silence the `secrets` job, which is the exact detection this fixture exists to
produce.

**That bypass paragraph is incomplete, and the missing layer is server-side.** Measured 2026-09-13:
`--no-verify` is a CLIENT-SIDE flag, and GitHub Push Protection runs on the receiving end where no
client flag reaches it. It rejected a `git push --no-verify` carrying commit `fbfcbe9` with
`GH013 — repository rule violations`, naming the two credential-shaped lines at `fixtures/secret.env`
lines 21 and 22 (Amazon AWS Access Key ID and Amazon AWS Secret Access Key). The control stack a
commit touching this directory traverses is therefore three layers deep, not two:

| Layer | Where it runs | Measured 2026-09-13 |
|---|---|---|
| pre-commit Gitleaks hook | client-side, `stages: [pre-push]` | no-op — `0 commits scanned`, `no leaks found`, rc=0; skipped by `--no-verify`, and it would have Passed anyway |
| GitHub Push Protection | SERVER-SIDE, on the receiving ref | REJECTED the push with `GH013`; `--no-verify` cannot skip it |
| CI `secrets` job (`gitleaks git .`) | GitHub Actions, on the pull request | reached once the push landed, and DID report on `fixtures/secret.env` |

The block was cleared on 2026-09-13 by the repository operator approving two per-secret unblock URLs
with the reason "used in tests". Nothing in this repository was changed to make the push succeed — no
fixture edit, no `.gitleaksignore` fingerprint, no rebase, no history rewrite. Approving those URLs
did NOT enable Secret Scanning: `gh api repos/OWNER/REPO --jq .security_and_analysis` still reports
`secret_scanning: disabled` and `secret_scanning_push_protection: disabled`, because free push
protection for PUBLIC repositories is controlled at the account level rather than by the repo-level
`security_and_analysis` block — so that block is a misleading place to look for whether push
protection is in force here. Expect Push Protection to block any future push that introduces a new
credential-shaped fixture, regardless of `--no-verify`, and plan a human unblock step for it.

**No hook fires on `requirements.txt`, and the four-hook list above is deliberately unchanged.**
Verified, not assumed: `ruff`/`ruff-format` are `types_or: [python, pyi]`, which does not match a
bare `requirements.txt`, and the `npm-audit` hook is `files: package-lock\.json$`. Running
`pre-commit run --files fixtures/requirements.txt` skips every hook. Do not "fix" this by adding a
fifth `exclude: ^fixtures/` entry — there is nothing to exclude.

**`ruff` and `ruff-format` DO match `fixtures/vulnerable.py`, and they PASS on it.** Measured
2026-09-12 against the pinned hooks (ruff-pre-commit v0.15.7): `pre-commit run ruff --files
fixtures/vulnerable.py` and `pre-commit run ruff-format --files fixtures/vulnerable.py` both
report Passed, not Skipped. The fixture is authored ruff-clean ON PURPOSE so that the four-hook
`exclude: ^fixtures/` list above stays at four. This matters more than style: the `ruff` hook
carries `args: [--fix]`, so an unclean fixture would be SILENTLY REWRITTEN IN PLACE at commit
time — the vulnerable construct could be edited away by the hook and the SAST fixture would go
quiet with nothing in the diff to explain it. If a future edit makes `vulnerable.py` trip ruff,
fix the style, never the vulnerability, and never add a fifth exclude entry.

**`fixtures/secret.env` is permanent once it is on `main`, by design.** The `secrets` job runs
`gitleaks git .` with `fetch-depth: 0` — a HISTORY scan, not a working-tree scan — so the moment
this file is in `main`'s history it is in the history of every branch cut from `main`, and the
`secrets` job will report it on every future run, forever. That is intended by D-04: it is what
keeps the Secrets detection path continuously exercised. Nobody may "clean up" that history with
a rebase, a filter-repo run or a `.gitleaksignore` fingerprint.

## Regenerating the lockfile

```bash
cd fixtures && npm install --package-lock-only --ignore-scripts --no-audit --no-fund
```

`--package-lock-only` and `--ignore-scripts` ensure no package is ever downloaded,
installed, or executed — only lockfile metadata is fetched from the registry.
