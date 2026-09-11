---
phase: 16-sca-ecosystem-coverage
plan: 05
subsystem: ci-cd
tags: [github-actions, live-run, npm-audit, pip-audit, tflint, sarif, evidence, pull-request, report-only]
requires:
  - "16-04 (f4388f8) — the sca job whose three sub-scan step groups this run exercises"
  - "16-03 (34d53ff) — the workstation baseline (histogram, advisory counts, tflint 0.61.0 rule ids) this run is compared against"
  - "15-05 (e8e1009) — the five verbatim check-run names this run must reproduce unchanged"
provides:
  - "Live CI evidence for Success Criteria 1, 2 and 3 on PR #7 / run 34614017396"
  - "Measured answer to the open v0.64.0-vs-0.61.0 tflint rule-id question: the ID set is IDENTICAL, the bundled ruleset is not"
  - "Four forward-facing facts Phase 17 must not have to infer (numbered filenames, SARIF availability, pip-audit severity gap, --audit-level semantics)"
  - "A sixth check-run name (GitGuardian, external app) Phase 18's branch-protection list must decide about"
affects:
  - "16-06 (ADR-015 / blueprint tables — can cite measured CI rule ids, not workstation ones)"
  - "16-07 (human sign-off and merge — PR #7 is open, MERGEABLE, CLEAN and deliberately unmerged)"
  - "17 (artifact upload: report filenames and byte sizes measured on the runner)"
  - "18 (branch protection: five names confirmed unchanged; a sixth non-Actions check exists)"
tech-stack:
  added: []
  patterns:
    - "Version evidence taken from the install step's download URL when the tool is never invoked with --version — quoted as such, not inferred"
    - "Per-step conclusions pulled from /actions/runs/<id>/jobs to prove no guarded step was SKIPPED, rather than reading the job conclusion alone"
key-files:
  created:
    - .planning/phases/16-sca-ecosystem-coverage/16-05-SUMMARY.md
  modified: []
key-decisions:
  - "No source file changed and no task commit made — this plan's `files_modified:` is empty by design; the only commit is the docs commit carrying this SUMMARY"
  - "tflint version evidence is the install step's v0.64.0 download URL plus the v0.15.0 ruleset doc links in the findings — the job never runs `tflint --version`, and adding a step would have violated the plan's no-source-change contract"
  - "The sixth check-run (GitGuardian Security Checks, app=gitguardian) is recorded as an observed fact rather than treated as a contract violation — it is an installed GitHub App, not a job in security.yml"
  - "Criterion 4 is recorded as NOT observed live, with its two actual evidence artefacts named, rather than manufactured by deleting fixtures"
requirements-completed: [SCA-01, SCA-02, SCA-03]
duration: ~15min
completed: 2026-09-11
---

# Phase 16 Plan 05: Live Run Evidence Summary

**On a real pull request (#7) against `OttawaCloudConsulting/security-platform`, the `sca` job detected all three ecosystems, reported npm vulnerabilities WITH severity levels, Python advisories from pip-audit, and Terraform pinning findings under tflint v0.64.0 — and the five Phase 15 check-run names came back byte-identical with every check `success` and the pull request `MERGEABLE` / `CLEAN`.**

## Performance

- **Duration:** ~15 min
- **Started:** ~2026-09-11T14:55Z
- **Completed:** 2026-09-11T15:07Z
- **Tasks:** 2 of 2
- **Files modified:** 0 source files (this plan changes nothing in either repository)

## Task Commits

**None, by design.** `files_modified: []` in the plan frontmatter — this plan pushes an existing
commit and reads a log; it authors no code. The only commit produced is the outer-repo docs commit
carrying this SUMMARY, STATE.md and ROADMAP.md.

Nothing was merged. PR #7 remains open for 16-07's human checkpoint. No job was rerun.

## Run Identifiers

| Item | Value |
|---|---|
| Repository | `OttawaCloudConsulting/security-platform` (slug resolved at runtime from the nested repo's `origin`) |
| Branch pushed | `feature/phase-16-sca-ecosystem-coverage` → `* [new branch] HEAD -> feature/phase-16-sca-ecosystem-coverage` |
| Head SHA | `f4388f8f05d314df613ca3bae78f6b1d068c2d2a` (`f4388f8`, the 16-04 commit) |
| Pull request | **#7** — https://github.com/OttawaCloudConsulting/security-platform/pull/7 |
| Workflow run id | **34614017396** — https://github.com/OttawaCloudConsulting/security-platform/actions/runs/34614017396 |
| Run event / workflow | `pull_request` / `PR Security` |
| Run window | started `2026-09-11T15:05:13Z`, updated `2026-09-11T15:05:42Z`, conclusion `success` |
| SCA job id | **103311309103**, `security / SCA — Trivy Filesystem`, completed in **26s** |

## Check-run names (Criterion: unchanged from 15-05)

`gh api repos/$SLUG/commits/$SHA/check-runs --jq '.check_runs[] | "\(.name) :: \(.status) :: \(.conclusion)"'`

```
security / SCA — Trivy Filesystem :: completed :: success
security / Container — Trivy Image :: completed :: success
security / IaC — Checkov :: completed :: success
security / Secrets — Gitleaks :: completed :: success
security / SAST — Semgrep CE :: completed :: success
GitGuardian Security Checks :: completed :: success
```

The five `security / …` names are **byte-identical to 15-05-SUMMARY**, including the deliberately
inaccurate `SCA — Trivy Filesystem`. `[.check_runs[] | select(.conclusion != "success")] | length`
returned `0`.

**Measured deviation from the plan's wording:** the plan's acceptance criterion says the endpoint
"returns five checks". It returned **six** (`total_count: 6`). The sixth is
`GitGuardian Security Checks`, `app=gitguardian` — an installed GitHub App, not a job in
`security.yml`. All five `github-actions` checks are accounted for and unchanged. 15-05 captured its
five names with `gh run view --json jobs`, which lists workflow jobs only and therefore could not
have shown this check; it is not new evidence of drift in our workflow. **Phase 18 must decide
explicitly whether the GitGuardian check belongs in the required-status-check list** — it is outside
this project's control.

## Per-step conclusions (no guarded step was skipped)

`gh api repos/$SLUG/actions/runs/34614017396/jobs` — all 21 steps of job 103311309103 returned
`conclusion: success`, including steps 12/15/18/19 (the four `continue-on-error: true # D-04` scans,
whose non-zero exits are tolerated and therefore surface as `success` at the step-conclusion level)
and steps 13/16/20 (the three **intolerant** report-content verifications). **No step was `skipped`**
— the three `steps.<id>.outputs.found == 'true'` guards all resolved true under a real
`$GITHUB_OUTPUT`, which is the key_link this plan had to prove.

## Criterion evidence, quoted verbatim from run 34614017396

All figures below are read from this run's log. None is copied from 16-RESEARCH or 16-03.

### Detectors — all three ecosystems resolved, nothing skipped

```
FOUND 1 npm lockfile(s):
fixtures/package-lock.json
FOUND 1 Python requirements file(s):
fixtures/requirements.txt
FOUND 1 Terraform file(s):
fixtures/main.tf
```

### Criterion 1 — npm dependency vulnerabilities WITH severity levels (SCA-01)

```
npm audit [fixtures] exit=1
npm audit severity histogram [npm-audit-1.json]: info=0 low=0 moderate=0 high=1 critical=1 total=2
  package=lodash severity=high
  package=minimist severity=critical
```

`high=1 critical=1` is non-zero, and the per-package lines carry the literal severity strings.
**Criterion 1 met.** `exit=1` is the expected findings signal, tolerated by `continue-on-error`.

The histogram is read straight out of the report's `metadata.vulnerabilities` object — the
verification step's own source, echoed by the runner in the same step group, is:

```
    if "error" in data or "auditReportVersion" not in data:
        print("npm audit report is an error object, not a report: {} ({})".format(
            path, data.get("error")))
        sys.exit(1)
    hist = (data.get("metadata") or {}).get("vulnerabilities") or {}
```

That guard did not fire on this run, so `npm-audit-1.json` is a real report carrying
`auditReportVersion` and a populated `metadata.vulnerabilities`, not an error object (T-16-23).

### Criterion 2 — Python advisories via pip-audit (SCA-02)

```
pip-audit [fixtures/requirements.txt] exit=1
  package=requests version=2.19.1 advisories=10
  package=jinja2 version=2.11.2 advisories=10
  package=idna version=2.7 advisories=4
  package=urllib3 version=1.23 advisories=22
pip-audit resolved dependencies [pip-audit-1.json]: 7
pip-audit advisory entries [pip-audit-1.json]: 46 (23 unique ids)
```

**Criterion 2 met.** pip-audit 2.10.1 installed cleanly on the runner
(`Successfully installed … pip-audit-2.10.1 …`) — the PEP 668 fallback path was not needed.

### Criterion 3 — Terraform provider and module pinning (SCA-03)

```
tflint rule ids: ['terraform_module_version', 'terraform_required_providers', 'terraform_required_version']
```

Two of the three ids are members of the pinning set
`{terraform_required_providers, terraform_module_version, terraform_module_pinned_source}`, so
**Criterion 3 is met on pinning grounds, not merely on `terraform_required_version`** (which alone
would not have satisfied it — T-16-21).

The human-readable step names the actual defects:

```
3 issue(s) found:

Warning: terraform "required_version" attribute is required (terraform_required_version)
  on fixtures/main.tf line 7:
Warning: Missing version constraint for provider "random" in `required_providers` (terraform_required_providers)
  on fixtures/main.tf line 16:
Warning: module "fixture_unpinned_module" should specify a version (terraform_module_version)
  on fixtures/main.tf line 38:
```

Both tflint steps exited **2** (`##[error]Process completed with exit code 2.`), the documented
findings code — not 1, which would have been an application error. Both are `continue-on-error`.

### Report evidence — the three guarded `ls -l` lines (plus Trivy's unchanged one)

```
-rw-r--r-- 1 runner runner  5242 Sep 11 15:05 npm-audit-1.json
-rw-r--r-- 1 runner runner 48204 Sep 11 15:05 pip-audit-1.json
-rw-r--r-- 1 runner runner  3521 Sep 11 15:05 tflint.sarif
-rw-r--r-- 1 runner runner 29888 Sep 11 15:05 trivy-fs.json     (unchanged Trivy step)
-rw-r--r-- 1 runner runner 18488 Sep 11 15:05 trivy-fs.sarif    (unchanged Trivy step)
```

All five non-zero bytes.

### Tolerated exit codes across the whole job

| Step | Exit | Tolerated by |
|---|---|---|
| Run Trivy filesystem scan | 1 | `continue-on-error: true # D-04` |
| SCA-01 — npm audit | 1 | `continue-on-error: true # D-04` |
| SCA-02 — pip-audit | 1 | `continue-on-error: true # D-04` |
| SCA-03 — tflint (SARIF) | 2 | `continue-on-error: true # D-04` |
| SCA-03 — tflint (human-readable log) | 2 | `continue-on-error: true # D-04` |

Five findings-bearing scans, zero red steps, green job, mergeable PR — report-only survived the
addition of three scanners.

## tflint v0.64.0 (CI) vs 0.61.0 (workstation) — measured, not assumed

**Version evidence.** The job never invokes `tflint --version`, and this plan may not add a step
(`files_modified: []`). The version is therefore evidenced by the install step's own log:

```
curl -sSfL -o tflint.zip
  https://github.com/terraform-linters/tflint/releases/download/v0.64.0/tflint_linux_amd64.zip
echo "cca9d13e2e1d7a2c627af60ff899a3c9b74212899416aeb96ec764d2ef954537  tflint.zip"
  | sha256sum -c -
sudo unzip -o -d /usr/local/bin tflint.zip
…
tflint.zip: OK
Archive:  tflint.zip
  inflating: /usr/local/bin/tflint
```

`tflint.zip: OK` is the checksum verification passing (T-16-14).

**Rule-id comparison:**

| | Workstation (16-03) | CI (this run) | Same? |
|---|---|---|---|
| tflint | 0.61.0 | **v0.64.0** | no (deliberate split) |
| Bundled terraform ruleset | `0.14.1-bundled` | **v0.15.0** (from the `…/tflint-ruleset-terraform/blob/v0.15.0/docs/rules/…` reference URLs printed with each finding) | **no** |
| Rule ids fired | `terraform_module_version`, `terraform_required_providers`, `terraform_required_version` | `terraform_module_version`, `terraform_required_providers`, `terraform_required_version` | **YES — identical set, same 3 ids** |
| `terraform_module_pinned_source` | did not fire | **did not fire** | same |
| Finding count | 3 | 3 | same |

**Stated plainly: v0.64.0 fired exactly the same three rules as v0.61.0 on this fixture, despite a
bundled-ruleset bump from 0.14.1 to 0.15.0.** 16-03's warning about possible drift is now closed as
*no drift observed*. `terraform_module_pinned_source` remains unfired in both environments — the
fixture's unpinned module uses a registry source, not a bare git source, so the rule has nothing to
flag. Verified this session by reading the fixture the run scanned:
`repos/security-platform/fixtures/main.tf` line 39 is
`  source = "terraform-aws-modules/s3-bucket/aws"` with no `version` argument, which is exactly what
`terraform_module_version` flagged and exactly what `terraform_module_pinned_source` (a git/ref
source rule) does not apply to. That limitation is unchanged by the newer version and is what 16-07's sign-off must
acknowledge.

**A secondary, unexpected match:** the npm histogram (`high=1 critical=1 total=2`) and the pip-audit
counts (`7` deps, `46` entries, `23` unique ids, per-package `10/10/4/22`) are **identical** to
16-03's workstation figures, even though both tools query live advisory feeds at run time and could
legitimately have drifted between the two measurements. Recorded as observed; no threshold in any
later phase should depend on these numbers staying put.

## Criterion 4 — NOT observed on this run

**The clean-skip path was not exercised live and this SUMMARY does not claim it was.** The product
repo carries `fixtures/package-lock.json`, `fixtures/requirements.txt` and `fixtures/main.tf`, so all
three detectors printed `FOUND 1 …` and nothing skipped. No fixture was deleted to manufacture a skip
(T-16-22).

Criterion 4's evidence is, precisely, these two artefacts:

1. **16-03's negative test** — `scripts/smoke-scans.sh` run inside an empty `git init` directory,
   where all three detectors reported the ecosystem absent, printed a clear message, and exited 0
   with no sub-scan counted as passed (recorded in 16-03-SUMMARY).
2. **16-04's static guard assertions** — `yaml.safe_load` confirmation that every scan, verification
   and `ls` evidence step in the `sca` job is gated on its detector's
   `steps.<id>.outputs.found == 'true'`, so an absent ecosystem cannot turn the job red.

The live run adds one thing to that case and only one: it proves the guards evaluate correctly under
a real `$GITHUB_OUTPUT` **in the true direction** (all three resolved true, all guarded steps ran,
zero `skipped`). The false direction remains evidenced locally and statically.

## Report-only behaviour (D-04) after three more scanners

```
gh pr view --repo OttawaCloudConsulting/security-platform 7 --json mergeable,mergeStateStatus
mergeable=MERGEABLE state=CLEAN pr=7
```

Queried **after** all checks concluded (immediately post-creation GitHub returns `UNKNOWN` while it
computes asynchronously). Five findings-bearing scans and the PR is still **MERGEABLE**.

## Hand-forwards Phase 17 must not have to infer

1. **npm and pip report filenames are numbered per input, not fixed.** This run produced
   `npm-audit-1.json` and `pip-audit-1.json` from one lockfile and one requirements file; a consumer
   repo with several manifests will produce `-2`, `-3`, … The artifact-upload step must **glob**
   (`npm-audit-*.json`, `pip-audit-*.json`), never name. Only `trivy-fs.json`, `trivy-fs.sarif` and
   `tflint.sarif` are fixed names.
2. **Neither npm audit nor pip-audit emits SARIF; tflint does.** `tflint --format sarif` wrote
   `tflint.sarif` (3521 bytes, `runs` key present) directly. `npm-audit-1.json` and
   `pip-audit-1.json` are tool-native JSON only. Phase 17's Criterion 4 ("a tool without native SARIF
   output still reaches the Security tab or the artifact set through a documented conversion step")
   therefore applies to **two** tools — npm audit and pip-audit — and Trivy's existing
   `trivy convert` is not a template for either, since neither has a converter.
3. **pip-audit's JSON carries no severity and no CVSS field anywhere.** The verification step can
   only count advisory entries and unique ids (`46 (23 unique ids)`); there is no per-advisory
   severity to render or threshold on. Any Phase 18 severity gate applies to npm audit and tflint but
   **cannot** be applied to pip-audit without a second data source.
4. **`--audit-level` does not filter npm audit's JSON report, even though Trivy's `--severity` does
   filter Trivy's.** The report contains every severity bucket regardless
   (`info=0 low=0 moderate=0 high=1 critical=1`); `--audit-level` affects only npm's exit code. A
   gate built on npm must read the histogram, not assume the file is pre-filtered. Trivy's
   `--severity HIGH,CRITICAL` genuinely does restrict `trivy-fs.json`'s contents — the two flags are
   not analogous.

## Deviations from Plan

### 1. [Finding, not a fix] The check-runs endpoint returns six checks, not five

Recorded above under *Check-run names*. All five workflow checks are present, unchanged and green;
the sixth is an external GitGuardian App check outside `security.yml`. Nothing was changed in
response — it is reported to Phase 18, which owns the required-check list.

### 2. [Rule 3 — blocking issue avoided] tflint version evidenced from the install URL, not `--version`

Task 2 asks for "the version line from the tflint install step". The 16-04 step never invokes
`tflint --version`, so no such line exists. Adding one would have modified a source file in a plan
declaring `files_modified: []`, and would have invalidated 16-04's own static gates. The download
URL (`…/download/v0.64.0/tflint_linux_amd64.zip`), the passing checksum (`tflint.zip: OK`) and the
`v0.15.0` ruleset reference URLs printed with each finding are quoted instead, and the substitution
is stated rather than glossed. **Carried forward: if a later phase wants a first-class version line
in the log, that is a one-line `tflint --version` addition to the install step — deliberately not
made here.**

---

**Total deviations:** 2 (1 finding, 1 evidence-source substitution). No source file touched, no
merge, no rerun, no fixture deleted.

## Threat Model Compliance

| Threat ID | Disposition | Evidence |
|---|---|---|
| T-16-20 | mitigated | Every git command scoped `git -C repos/security-platform`; readiness confirmed before the push (clean `status --porcelain`, HEAD on `feature/phase-16-sca-ecosystem-coverage`, `git log origin/main..HEAD` showing exactly the six 16-01..16-04 commits). Slug resolved at runtime from the nested repo's `origin`, never hardcoded. No push was issued from the outer documentation repo |
| T-16-21 | mitigated | Criterion 3 is recorded against `terraform_required_providers` and `terraform_module_version`, both pinning rules, quoted with their file and line. `terraform_required_version` is listed but explicitly noted as insufficient on its own |
| T-16-22 | mitigated | Criterion 4 is stated as NOT observed live, with the two real evidence artefacts named. No fixture was deleted, no skip was manufactured |
| T-16-23 | mitigated | Evidence is the histogram, the advisory counts and the rule-id set — not the check conclusion. The three intolerant verification steps all returned `success` on this run, so no sub-scan emitted an error-shaped report. Per-step conclusions were pulled to confirm none was `skipped` |
| T-16-SC | mitigated | No install performed by this plan. The runner's `pip install pip-audit==2.10.1` resolved to exactly `pip-audit-2.10.1`, and the tflint zip passed `sha256sum -c -` |

## Carried Forward

- **PR #7 is open, green and MERGEABLE, and must NOT be merged until 16-07's human checkpoint.**
  Branch `feature/phase-16-sca-ecosystem-coverage` now exists on the remote.
- **16-06 (ADR-015 / blueprint tables) can cite CI-measured rule ids**, not workstation ones: three
  ids under v0.64.0 with ruleset v0.15.0, of which two are pinning rules.
- **`terraform_module_pinned_source` still does not fire** on this fixture under either tflint
  version. 16-07's sign-off covers this as the known Criterion 3 limitation.
- **Phase 18 must resolve the GitGuardian check** — six checks appear on the head SHA, five of them
  ours.
- **Phase 18 may want a `tflint --version` line** in the install step; deliberately not added here.
- **`cicd/.github/workflows/security.yml` remains stale** (unchanged since 16-04).

## Self-Check: PASSED

Commands run and their results:

- `.planning/phases/16-sca-ecosystem-coverage/16-05-SUMMARY.md` — FOUND (this file)
- PR #7 exists, `mergeable=MERGEABLE state=CLEAN` — FOUND
- Run `34614017396`, conclusion `success` — FOUND
- Plan verify (Task 1, #1): six check-runs listed, five `security / …` unchanged, all `success`
- Plan verify (Task 1, #2): `SCA — Trivy Filesystem` present (rc=0); non-success count `0`
- Plan verify (Task 2, #2): `mergeable=MERGEABLE state=CLEAN` (rc=0)
- `git -C repos/security-platform status --porcelain` — empty; no source file changed by this plan
- No merge performed, no job rerun, no fixture deleted
