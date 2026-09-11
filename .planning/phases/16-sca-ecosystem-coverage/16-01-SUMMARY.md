---
phase: 16-sca-ecosystem-coverage
plan: 01
subsystem: scan-fixtures
tags: [fixtures, sca, terraform, python, pip-audit, tflint, measurement]
requires:
  - "Phase 15 fixture baseline on security-platform main (commit e8e1009)"
provides:
  - "SCA-02 scan target: fixtures/requirements.txt (pip-audit + Trivy fs input)"
  - "SCA-03 scan target: unconstrained provider + unpinned module in fixtures/main.tf"
  - "Re-measured fixture count table for all six consuming scans"
affects:
  - "SCA-04 Trivy fs finding count (9 -> 19)"
  - "IaC Checkov terraform failed-check count (10 -> 12)"
tech-stack:
  added: []
  patterns:
    - "Fixture header comment: INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT \"FIX\" OR INSTALL"
    - "Exact == pins only in requirements.txt (keeps --no-deps fast path viable, --require-hashes not used)"
key-files:
  created:
    - repos/security-platform/fixtures/requirements.txt
  modified:
    - repos/security-platform/fixtures/main.tf
    - repos/security-platform/fixtures/README.md
decisions:
  - "Dockerfile row re-measured by building the fixture image and running trivy image, even though the plan's command list omitted it — acceptance required every table count to come from a command run today"
  - "requirements.txt carries two rows in the README (pip-audit 46 / Trivy fs 10) because the tools disagree by design; the gap is documented so it is not read as a broken scan"
metrics:
  duration: ~18min
  completed: 2026-09-11
---

# Phase 16 Plan 01: Seed Python and Terraform Pinning Fixtures Summary

SCA-02 and SCA-03 now have real scan targets: a new `fixtures/requirements.txt` producing 46 pip-audit
advisories, and an additively-extended `fixtures/main.tf` that fires two genuine tflint pinning rules —
with the Phase 15 aws pin and misconfigured resources untouched.

## What Was Built

**Branch:** `feature/phase-16-sca-ecosystem-coverage` in `repos/security-platform`, cut with
`--no-track` from `origin/main` (`e8e1009`). Local `main` and `origin/main` were verified identical
and the working tree was clean before branching.

**Commit:** `68c3bbb` — `test(16-01): seed Python and Terraform pinning fixtures for SCA-02 and SCA-03`
(one commit for both tasks, by plan design — same pattern as 15-03).

### `fixtures/requirements.txt` (new)

Two-line `#` header (DO-NOT-"FIX"-OR-INSTALL + "nothing ever runs `pip install -r` against this file"),
then exactly two `==` pins: `requests==2.19.1`, `jinja2==2.11.2`. No range operators
(`grep -c '>=' → 0`), no hashes.

### `fixtures/main.tf` (additive, plus one stale-comment correction)

1. Header line 2 rewritten. It claimed the `3.74.0` pin "seeds Phase 16 / SCA-03"; it now states the
   exact pin is *correctly silent* under tflint and exists only for D-02, and names the `random`
   provider and the unpinned module as what actually seeds SCA-03.
   `grep -n 'seeds Phase 16' fixtures/main.tf` now returns nothing.
2. `random = { source = "hashicorp/random" }` inside `required_providers` — no `version` key — plus
   `resource "random_id" "fixture" { byte_length = 8 }` so the provider is actually **used**. Both
   halves were mandatory: `terraform_required_providers` does not fire on a declared-but-unused provider.
3. `module "fixture_unpinned_module"` with `source = "terraform-aws-modules/s3-bucket/aws"` and no
   `version` argument.

Untouched as required: `version = "3.74.0"`, `resource "aws_s3_bucket" "fixture"`,
`resource "aws_security_group" "fixture"`. No `required_version` attribute added. No floating range
added — 16-RESEARCH measured `>= 3.0` as NOT flagged by the default ruleset, so adding one would have
produced a fixture that looks like it proves something it does not.

### `fixtures/README.md` (re-measured)

Structure tree now lists `requirements.txt` and describes `main.tf` as carrying the unconstrained
provider and unpinned module. The Fixture Reference table has seven rows covering all six consuming
scans, a date header of 2026-09-11, a tool-version line, an explanation of the pip-audit/Trivy gap,
and the original drift caveat retained. The Pre-commit Scoping section records the verified negative.

## Measurements (every figure below came from a command run on this branch, today)

| Command | Result |
|---|---|
| `tflint --chdir=fixtures --format json` (TFLint 0.61.0, ruleset.terraform 0.14.1-bundled) | rc=2, **3 issues**: `terraform_required_providers` ("Missing version constraint for provider \"random\""), `terraform_module_version` ("module \"fixture_unpinned_module\" should specify a version"), `terraform_required_version` (pre-existing Phase 15 state) |
| `pip-audit -r fixtures/requirements.txt --format json` (pip-audit 2.10.1) | rc=1, "Found 46 known vulnerabilities in 4 packages" — **46 advisory entries / 23 unique IDs** across 7 resolved dependencies (requests 10, jinja2 10, urllib3 22, idna 4) |
| `(cd fixtures && npm audit --audit-level=high --json)` (npm 11.7.0) | rc=1, `auditReportVersion: 2` (not `error`), `metadata.vulnerabilities` = `{high: 1, critical: 1, total: 2}` — lodash, minimist |
| `checkov -d . --quiet --compact` (Checkov 3.2.396) | terraform scan results: Passed 8, **Failed 12** |
| `trivy fs . --scanners vuln --format json` (Trivy 0.74.0) | `fixtures/package-lock.json` npm **9** (1 CRITICAL, 4 HIGH, 4 MEDIUM); `fixtures/requirements.txt` pip **10** (1 HIGH, 9 MEDIUM); **total 19** |
| `docker build -t scan-fixture:16-01 fixtures/ && trivy image scan-fixture:16-01 --scanners vuln` | **222** vulnerabilities (4 CRITICAL, 52 HIGH, 88 MEDIUM, 72 LOW, 6 UNKNOWN) |
| `pre-commit run --files fixtures/requirements.txt` | rc=0, all 10 hooks "(no files to check) Skipped" |
| `pre-commit run --all-files` | rc=0 (shellcheck, yamllint, markdownlint Passed; rest skipped) |

### Predicted side effects — now recorded observations, not predictions

| Consumer | Previous (2026-09-10) | Now (2026-09-11) | Cause |
|---|---|---|---|
| Checkov, terraform framework | 10 failed | **12 failed** | `CKV_TF_1` + `CKV_TF_2` both FAILED for `fixture_unpinned_module` at `/fixtures/main.tf:38-40`. Attributed by reading the Checkov output, not inferred from the delta. Exactly +2; no pre-existing check changed verdict. |
| Trivy fs | 9 (npm only) | **19** (9 npm + 10 pip) | Trivy parses `requirements.txt` natively. The npm sub-total is unchanged at 9, so this is purely additive. |
| Trivy image | 222 (4 CRITICAL, 52 HIGH) | **222 (4 CRITICAL, 52 HIGH)** | Re-measured today and identical — the digest pin is doing its job. This is a fresh measurement that happens to match, not a carried-forward number. |

`checkov` also emitted `WARNI Failed to download module terraform-aws-modules/s3-bucket/aws:None (for
external modules, the --download-external-modules flag is required)`. That is expected and desirable —
it confirms T-16-04's "accept" disposition holds: nothing in this repo fetches the remote module.

## Deviations from Plan

### Additions beyond the literal plan text

**1. [Rule 2 — missing critical verification] Re-measured the `Dockerfile` row with a real Trivy image scan**
- **Found during:** Task 2
- **Issue:** The plan's action listed five commands to run, none of which measures the `Dockerfile` row
  — but its acceptance criteria state "every number in the new table must come from a command you ran
  in this task." Copying forward the 222/4/52 figure would have violated T-16-02 (the exact threat the
  task exists to mitigate).
- **Fix:** Built the fixture image (`docker build -t scan-fixture:16-01 fixtures/`) and ran
  `trivy image`. Result matched the previous figure exactly. Test image removed afterward
  (`docker rmi scan-fixture:16-01`).
- **Commit:** 68c3bbb (README content)

**2. [Rule 2 — verification hardening] Staged the fixture files before running `pre-commit run --all-files`**
- **Found during:** Task 2
- **Issue:** `--all-files` operates on `git ls-files`. An untracked `requirements.txt` would not have
  been exercised at all, making the plan's "exits 0" check vacuous for the one genuinely new file.
- **Fix:** `git add` the three files first, then ran `--all-files`, then ran
  `pre-commit run --files fixtures/requirements.txt` separately to capture the verified negative.

**3. [Rule 2 — footgun removal] Branch cut with `git switch -c ... --no-track origin/main`**
- A plain `checkout -b X origin/main` would set the upstream to `origin/main`, which is a hazard for
  whichever later plan runs `git push`. `--no-track` leaves the branch with no upstream.

### Scope notes (not deviations)

- **Single commit for both tasks** is plan design (Task 2's action instructs the commit), matching the
  15-01/15-02/15-03 verification-then-commit pattern.
- **No push.** Nothing was pushed from either repository. The branch is local to
  `repos/security-platform`.
- **README markdown line length:** the new table rows exceed the prose wrap used elsewhere in the file,
  but `markdownlint` (the repo's own gate) passes — MD013 is not enforced in this configuration, and
  the pre-existing table rows already ran long.

## Requirements Note

This plan marks **SCA-02** and **SCA-03** complete in REQUIREMENTS.md per the execution protocol, but
what it delivers is the **scan targets**, not the sub-scans themselves. No workflow, script, or
outer-repo change was made. The pip-audit and tflint sub-scan steps land in a later Phase 16 plan; the
verifier should read these checkboxes as "the thing the sub-scan will assert on now exists and produces
a rule-correct finding."

## Carried Forward

- **tflint exits 2 on findings.** `scripts/smoke-scans.sh`'s `run_scan()` treats rc=1 as PASS and
  anything else as a tool error, so a healthy tflint run would be misclassified. Confirmed again here:
  `tflint --chdir=fixtures` returned rc=2. The smoke-gate plan must handle this.
- **pip-audit JSON has no severity field.** The 46 advisories carry IDs, aliases, fix versions and
  descriptions only. Any Python severity threshold in Phase 18's gate mode must be derived externally
  or taken from the Trivy pip results (which do carry severities — 1 HIGH, 9 MEDIUM here).
- **Neither pip-audit nor npm audit emits SARIF.** tflint does. Phase 17's Criterion 4 applies to two
  of the three tools.
- **`sca` job check-run name** is still verbatim `SCA — Trivy Filesystem` (em-dash U+2014), unchanged
  by this plan. If a later plan renames it, Phase 18's branch-protection list must follow.

## Threat Model Compliance

| Threat ID | Disposition | Evidence |
|---|---|---|
| T-16-01 | mitigated | `requirements.txt` line 1 carries the `INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX" OR INSTALL` header; line 2-3 state nothing ever runs `pip install -r` against it; README structure tree and two table rows name its consuming jobs |
| T-16-02 | mitigated | Every table figure re-measured today; commands and raw outputs recorded above; the Trivy-image row was re-measured rather than copied even though the plan's command list omitted it |
| T-16-03 | mitigated | `version = "3.74.0"`, `aws_s3_bucket.fixture` and `aws_security_group.fixture` all verified literally present post-edit; Checkov's pre-existing 10 terraform failures are all still present (12 = 10 + the 2 new CKV_TF checks); Trivy fs npm sub-total unchanged at 9 |
| T-16-04 | accepted, holds | Checkov's "Failed to download module … --download-external-modules flag is required" warning is positive evidence that no remote module fetch occurs. No `terraform init` is run on `fixtures/`; `terraform_validate`/`terraform_fmt` remain `exclude: ^fixtures/` |
| T-16-SC | mitigated | Zero package installs. `pip-audit -r` resolves dependency metadata for auditing only; `npm audit` reads the existing lockfile. No `npm install`, `pip install`, or `terraform init` was run. |

## Self-Check: PASSED

- `repos/security-platform/fixtures/requirements.txt` — FOUND
- `repos/security-platform/fixtures/main.tf` — FOUND (modified)
- `repos/security-platform/fixtures/README.md` — FOUND (modified)
- Commit `68c3bbb` — FOUND in `repos/security-platform` on `feature/phase-16-sca-ecosystem-coverage`
- `git -C repos/security-platform status --porcelain` — empty
- No files deleted by the commit (`git diff --diff-filter=D HEAD~1 HEAD` empty)
