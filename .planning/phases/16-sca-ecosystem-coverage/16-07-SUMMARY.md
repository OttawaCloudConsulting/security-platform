---
phase: 16-sca-ecosystem-coverage
plan: 07
subsystem: ci-cd
tags: [merge, pull-request, human-sign-off, sca, npm-audit, pip-audit, tflint, phase-close]
requires:
  - "16-05 (PR #7 / run 34614017396) — the live evidence put in front of the user before the merge decision"
  - "16-06 (7b9b49d, 3131a5e) — ADR-015 and the blueprint tables the sign-off cites instead of restating"
  - "15-05 (e8e1009) — the merge-and-verify procedure reapplied here, including the remote-verification rule"
provides:
  - "MERGED: PR #7 merged to OttawaCloudConsulting/security-platform main via --merge, commit 40682cea329c34b65115236bd449d16f84432e0e"
  - "origin/main confirmed carrying the four-tool sca job, scripts/detect-{npm,python,terraform}.sh, the extended scripts/smoke-scans.sh, fixtures/requirements.txt and the extended fixtures/main.tf"
  - "The verbatim sca job name re-read from origin/main and byte-checked: 'SCA — Trivy Filesystem' (em dash U+2014), check-run 'security / SCA — Trivy Filesystem'"
  - "An honest criterion-by-criterion verdict: 1 and 2 met live, 3 partially met and accepted by the user, 4 met by negative test and static guards rather than a live skip"
  - "Four Phase 17 hand-forwards and two Phase 18 hand-forwards, stated so neither phase re-derives them"
affects: [17, 18]
tech-stack:
  added: []
  patterns:
    - "The verbatim check-run string is re-read from origin/main by yaml.safe_load and byte-dumped (e2 80 94) rather than copied from a prior SUMMARY, so a hyphen substitution cannot propagate into branch protection"
    - "A requirement already ticked by an earlier plan's metadata step is reported as confirmed, not claimed as marked by this plan"
key-files:
  created:
    - .planning/phases/16-sca-ecosystem-coverage/16-07-SUMMARY.md
  modified:
    - .planning/ROADMAP.md
    - .planning/STATE.md
key-decisions:
  - "Merged with `gh pr merge --repo <slug> 7 --merge` (a merge commit, matching the Phase 14/15 precedent) and deliberately WITHOUT --delete-branch, so gh's local-branch side effects cannot act on the outer documentation repo, which shares the remote URL but is a separate checkout on an unrelated branch"
  - "Criterion 3 is recorded as PARTIALLY satisfied, on the user's explicit acceptance — met for missing provider constraints and unpinned module sources, NOT met for floating ranges such as version = \">= 3.0\""
  - "The sca check-run name stays 'SCA — Trivy Filesystem' despite the job now running four tools, because Phase 18's required-status-check list hard-codes it; renaming would silently break branch protection"
  - "SCA-01/02/03 were already marked complete by 16-05's and 16-06's requirements-completed frontmatter; this plan re-ran the mark idempotently and confirms rather than claims the marking"
requirements-completed: [SCA-01, SCA-02, SCA-03]
duration: ~10min
completed: 2026-09-11
---

# Phase 16 Plan 07: Human Sign-Off and Merge to Main Summary

**PR #7 is MERGED to `OttawaCloudConsulting/security-platform` `main` (merge commit `40682cea329c34b65115236bd449d16f84432e0e`) on the user's explicit approval; `origin/main` is verified — not the local tree — to carry the four-tool `sca` job, all three detector scripts, the extended smoke gate and both fixture changes; and the phase closes with Criterion 3 recorded as partially satisfied rather than glossed.**

## Performance

- **Duration:** ~10 min (Task 2 only — Task 1 was answered in the immediately preceding turn)
- **Merged at:** 2026-09-11T15:27:38Z
- **Completed:** 2026-09-11T15:30Z
- **Tasks:** 2 of 2
- **Files modified:** 0 source files in `repos/security-platform` by this executor (the merge lands the diff authored in 16-01..16-04). Outer repo: this SUMMARY + ROADMAP + STATE.

## Task 1 — Human sign-off (checkpoint, `gate="blocking"`)

**The question put to the user, as asked:**

> "Accept Criterion 3 as partially satisfied (missing constraints + unpinned modules flagged; floating ranges like '>= 3.0' are NOT flagged) and keep the check-run name 'SCA — Trivy Filesystem' unchanged (Phase 18 hard-codes it)? If yes, merge PR #7 to main."

**The user's literal answer, recorded verbatim:**

> **"Approved — merge"**

The evidence presented before the question was asked: the PR URL
(https://github.com/OttawaCloudConsulting/security-platform/pull/7), the five required check-run
names all green (`security / SAST — Semgrep CE`, `security / IaC — Checkov`,
`security / SCA — Trivy Filesystem`, `security / Container — Trivy Image`,
`security / Secrets — Gitleaks`) plus the sixth, external `GitGuardian Security Checks` also green,
and the three per-criterion log excerpts from run `34614017396` — the npm severity histogram
(`high=1 critical=1`), the pip-audit advisory counts (46 entries / 23 unique ids over 7 resolved
dependencies), and the tflint rule-id set
(`terraform_module_version`, `terraform_required_providers`, `terraform_required_version`), matching
the workstation baseline. Both judgement calls (Criterion 3's partial coverage and the frozen
check-run name) were named explicitly in the question, not buried in the evidence.

Nothing was merged, pushed or modified before that response. `workflow.auto_advance` was not applied
to this gate.

## Task 2 — Merge, verify from the remote, close the record

### 1. Merge

```
gh pr merge --repo OttawaCloudConsulting/security-platform 7 --merge
```

| Field | Value |
|---|---|
| PR state | **`MERGED`** |
| Merge commit SHA | **`40682cea329c34b65115236bd449d16f84432e0e`** (`40682ce`) |
| Merged at | `2026-09-11T15:27:38Z` |
| Merged by | `OttawaCloudConsulting` (OCC) |
| Merge type | `--merge` — a merge commit, not squash, not rebase (Phase 14/15 precedent) |

`gh pr list --state merged --head feature/phase-16-sca-ecosystem-coverage` independently returns
`pr=7 merge=40682cea329c34b65115236bd449d16f84432e0e`. No `--delete-branch` flag was used (see
Decisions Made).

### 2. Verified from `origin/main`, never from the local working tree

`git -C repos/security-platform fetch origin` moved `origin/main` `e8e1009..40682ce`. Everything
below was then read with `git show origin/main:<path>` / `git cat-file -e origin/main:<path>`
**before** the local checkout was touched (T-16-29 ordering).

| Path on `origin/main` | Confirmed |
|---|---|
| `.github/workflows/security.yml` | Four-tool `sca` job: `bash scripts/detect-npm.sh`, `detect-python.sh`, `detect-terraform.sh` (lines 132/136/140), `trivy fs` (148), `SCA-01 — npm audit` (172), `SCA-02 — pip-audit` (235), tflint install pinned to `v0.64.0` with a `sha256sum -c -` checksum (113–119) |
| `scripts/detect-npm.sh` | present, matches on `package-lock.json` |
| `scripts/detect-python.sh` | present, `*requirements*.txt` pathspec, exits 0 on the skip branch |
| `scripts/detect-terraform.sh` | present, `git ls-files -- '*.tf'`, `FOUND n` / `SKIP:` on both branches, `exit 0` on skip |
| `scripts/smoke-scans.sh` | extended gate: `run_scan_rc` present, tflint's rc=2 handled, `SKIPPED` accounting present |
| `fixtures/requirements.txt` | present, `requests==2.19.1` and `jinja2==2.11.2` under the DO-NOT-INSTALL header |
| `fixtures/main.tf` | extended: unconstrained `random` provider (no `version` key) **plus** the `random_id.fixture` resource that makes it fire, and `module "fixture_unpinned_module"` sourcing `terraform-aws-modules/s3-bucket/aws` with no `version` |

The plan's own `<automated>` verify #2 (`detect-terraform.sh` + `requests==2.19.1` +
`package-lock.json` + `run_scan_rc`, all on `origin/main`) returned **PASS**.

Job structure on `origin/main` is unchanged from Phase 15: exactly five job ids
(`sast`, `iac`, `sca`, `container`, `secrets`) and **zero** `needs:` keys — the three new scanners
are steps inside `sca` (20 steps), not new jobs.

### 3. The verbatim `sca` check-run name, re-read from `origin/main`

Parsed with `yaml.safe_load` from `git show origin/main:.github/workflows/security.yml`, not copied
from 15-05 or 16-05:

```
jobs.sca.name = 'SCA — Trivy Filesystem'
utf-8 bytes  = 53 43 41 20 e2 80 94 20 54 72 69 76 79 20 46 69 6c 65 73 79 73 74 65 6d
```

`e2 80 94` confirms **em dash U+2014**, not a hyphen and not an en dash. The check-run name Phase 18
must configure branch protection against is therefore, byte-exact:

```
security / SCA — Trivy Filesystem
```

All five, re-read from the same parse: `SAST — Semgrep CE`, `IaC — Checkov`,
`SCA — Trivy Filesystem`, `Container — Trivy Image`, `Secrets — Gitleaks`.

**The name is deliberately inaccurate and deliberately frozen** — the job now runs Trivy filesystem,
npm audit, pip-audit and tflint. The user approved keeping it because Phase 18's required-check list
hard-codes it.

### 4. Local checkout returned to a current default branch

```
git -C repos/security-platform switch main
git -C repos/security-platform pull --ff-only     # f4388f8 → 40682ce, 7 commits fast-forwarded
git -C repos/security-platform branch -d feature/phase-16-sca-ecosystem-coverage   # was f4388f8
```

Working tree clean (`status --porcelain` empty), on `main` at `40682ce`, so Phase 17 starts from a
current default branch.

**Loose end (non-blocking, same as Phase 15):** the **remote** branch
`feature/phase-16-sca-ecosystem-coverage` was not auto-deleted by the merge
(`git ls-remote` still returns `f4388f8f…`) and was left in place — deleting it is outside this
plan's scope.

## Criterion-by-criterion verdict

### Criterion 1 — npm dependency vulnerabilities with severity levels (SCA-01): **MET**

Live on run `34614017396`:
`npm audit severity histogram [npm-audit-1.json]: info=0 low=0 moderate=0 high=1 critical=1 total=2`,
with `package=lodash severity=high` and `package=minimist severity=critical`. Non-zero, and the
severity strings are literally present. The intolerant report-content check did not fire, so the
report is a real `auditReportVersion` document, not an error object.

### Criterion 2 — Python advisories via pip-audit (SCA-02): **MET**

Live: `pip-audit resolved dependencies [pip-audit-1.json]: 7` and
`pip-audit advisory entries [pip-audit-1.json]: 46 (23 unique ids)`, with per-package lines for
`requests 2.19.1` (10), `jinja2 2.11.2` (10), `idna 2.7` (4), `urllib3 1.23` (22). pip-audit 2.10.1
installed cleanly on the runner; the PEP 668 fallback was not needed.

### Criterion 3 — Terraform provider and module pinning: **PARTIALLY MET — accepted by the user**

**Met, live:**

| Rule id | Finding | Pinning rule? |
|---|---|---|
| `terraform_required_providers` | Missing version constraint for provider `random` — `fixtures/main.tf:16` | **yes** |
| `terraform_module_version` | module `fixture_unpinned_module` should specify a version — `fixtures/main.tf:38` | **yes** |
| `terraform_required_version` | `terraform {}` declares no `required_version` — `fixtures/main.tf:7` | no — hygiene only |

Two of the three are genuine pinning rules, so the criterion does not rest on
`terraform_required_version` alone.

**Not met, and stated plainly:** the criterion's word *"floating"* is **not** covered. tflint's
default bundled ruleset (v0.15.0 under tflint v0.64.0) does **NOT** flag a floating range such as
`version = ">= 3.0"` — measured in 16-RESEARCH, recorded in ADR-015's Tradeoff section and in the
blueprint's coverage-matrix note. A custom rule was deliberately not built this phase; ADR-015
records that as out of scope with its reason (flagging every `~>` would be noisy, since `~>` is
HashiCorp's own recommended practice for root modules).

Additionally, `terraform_module_pinned_source` **did not fire** in either environment — it is a
git-source rule and the fixture's unpinned module uses a registry source
(`terraform-aws-modules/s3-bucket/aws`). That is a property of the fixture and the rule, not a
regression.

The user accepted this partial coverage explicitly ("Approved — merge" to a question naming the
limitation). **SCA-03 is therefore closed as satisfied through the missing-constraint and
unpinned-module cases only.** Any later phase that needs loose-range detection must start from
ADR-015's Tradeoff section — it is a known gap, not an oversight.

### Criterion 4 — clean skip when an ecosystem is absent: **MET, but not by live observation**

**This SUMMARY does not claim a live skip was seen.** The product repo carries all three ecosystems,
so on run `34614017396` every detector printed `FOUND 1 …` and no guarded step was `skipped`. The
evidence for Criterion 4 is, precisely:

1. **16-03's negative test** — `scripts/smoke-scans.sh` executed inside an empty `git init`
   directory: all three detectors reported the ecosystem absent, printed a clear message, exited 0,
   and no sub-scan was counted as passed (a skip is accounted as `SKIPPED`, never as a pass).
2. **16-04's static guard assertions** — `yaml.safe_load` confirmation that every scan, verification
   and evidence step in the `sca` job is gated on its detector's
   `steps.<id>.outputs.found == 'true'`, so an absent ecosystem cannot turn the job red.

The live run contributes exactly one thing: proof that the guards evaluate correctly under a real
`$GITHUB_OUTPUT` **in the true direction**. The false direction remains evidenced locally and
statically. No fixture was deleted to manufacture a skip (T-16-22).

## Hand-forwards — Phase 17 (SARIF upload and artifact retention)

1. **npm and pip report filenames are numbered per input, not fixed.** The run produced
   `npm-audit-1.json` and `pip-audit-1.json` from one lockfile and one requirements file; a repo with
   several manifests yields `-2`, `-3`, … The artifact-upload step must **glob**
   (`npm-audit-*.json`, `pip-audit-*.json`) and must never name them. Only `trivy-fs.json`,
   `trivy-fs.sarif` and `tflint.sarif` are fixed names.
2. **Neither npm audit nor pip-audit emits SARIF; tflint does.** `tflint --format sarif` writes
   `tflint.sarif` directly (3521 bytes, `runs` key present). Phase 17's Criterion 4 (a tool without
   native SARIF still reaching the Security tab or the artifact set via a documented conversion)
   therefore applies to **two of the three** new tools — npm audit and pip-audit — and Trivy's
   `trivy convert` is not a template for either, since neither ships a converter.
3. **pip-audit's JSON carries no severity and no CVSS field anywhere.** Only advisory entries and
   unique ids can be counted (`46 (23 unique ids)`). There is no per-advisory severity to render or
   threshold on without a second data source.
4. **`--audit-level` does NOT filter npm audit's JSON report, even though Trivy's `--severity` does
   filter Trivy's.** npm's report contains every severity bucket regardless
   (`info=0 low=0 moderate=0 high=1 critical=1`); `--audit-level` affects the exit code only. Trivy's
   `--severity HIGH,CRITICAL` genuinely does restrict `trivy-fs.json`'s contents. **The two flags
   must not be generalised to each other.**

## Hand-forwards — Phase 18 (gate mode and branch protection)

1. **The check-run name is frozen:** `security / SCA — Trivy Filesystem`, em dash U+2014, re-read from
   `origin/main` in step 3 above. It is inaccurate (four tools, one Trivy-flavoured name) by an
   explicit, user-approved decision. Configure branch protection against this exact string.
2. **Gate mode must not re-derive severity thresholds.** Every tool kept its **native** semantics
   under D-04 (report-only, `continue-on-error`): npm audit and Trivy exit 1 on findings, tflint
   exits **2** (1 means an application error), and pip-audit exits 1. Nothing was normalised to a
   common severity scale, and pip-audit has no severity field at all, so a single cross-tool
   threshold cannot be assumed — the gate must be expressed per tool.

**Also carried (not re-derived elsewhere):**

- The check-runs endpoint returns **six** checks on the head SHA — the five `security / …` jobs plus
  the external `GitGuardian Security Checks` GitHub App. Phase 18 must decide explicitly whether it
  belongs in the required-check list; it is outside this project's control.
- The 9 Gitleaks history findings (Phase-05 test strings, confirmed fake) are report-only today but
  **will** block once gate mode is on — remedy is `--baseline-path` or fingerprint-form
  `.gitleaksignore` entries.
- `cicd/.github/workflows/security.yml` in the outer documentation repo **remains stale** (unchanged
  since 16-04) — it does not reflect the four-tool `sca` job now on the product repo's `main`.
- The `sca` job never runs `tflint --version`; the version is evidenced by the install URL and
  checksum. A first-class version line is a one-line addition, deliberately not made.
- The remote branch `feature/phase-16-sca-ecosystem-coverage` still exists on the remote.

## Requirements

SCA-01, SCA-02 and SCA-03 are complete in `.planning/REQUIREMENTS.md` (checkboxes `[x]` and
traceability rows `Phase 16 | Complete`). **Honest note:** they were already marked by 16-05's and
16-06's `requirements-completed:` metadata step, which runs before the human sign-off. This plan
re-ran `requirements.mark-complete` idempotently — it returned
`already_complete: [SCA-01, SCA-02, SCA-03]`, `updated: false` — so this plan **confirms** the
marking rather than performing it. The sign-off that actually authorises the closure is the Task 1
response above, not the checkbox.

## Task Commits

Both tasks are checkpoint/observation-only by plan design (`files_modified: []`):

1. **Task 1 — human sign-off:** no commit (checkpoint gate; response recorded verbatim above).
2. **Task 2 — merge and verify:** no executor-authored commit in `repos/security-platform`. The only
   commit created there is the merge commit `40682ce`, produced by `gh pr merge`.
   `git -C repos/security-platform status --porcelain` is empty.

Outer documentation repo: this SUMMARY + `ROADMAP.md` + `STATE.md`, staged by name in the final
metadata commit. No `git add -A` — the outer working tree carries dozens of unrelated `.claude/**`
modifications from other work. No `git push` was issued from the outer repository at any point.

## Files Created/Modified

- `.planning/phases/16-sca-ecosystem-coverage/16-07-SUMMARY.md` — created (this file)
- `.planning/ROADMAP.md` — Phase 16 row and plan checkboxes updated
- `.planning/STATE.md` — position, decisions, session continuity
- `repos/security-platform` — **zero** files modified by this executor

## Decisions Made

See `key-decisions` in frontmatter. In short: a merge commit (not squash/rebase) without
`--delete-branch`; Criterion 3 closed as partially satisfied on explicit user acceptance; the
check-run name frozen despite being inaccurate; and the already-ticked requirements reported as
confirmed rather than claimed.

## Deviations from Plan

**None affecting the plan's intent.** Two mechanical notes, recorded rather than glossed:

1. **[Reporting accuracy]** The plan's acceptance criterion says SCA-01/02/03 "are marked complete in
   REQUIREMENTS.md". They were already `[x]` on arrival, marked by 16-05/16-06's metadata step. The
   criterion is satisfied, but this SUMMARY says *confirmed*, not *marked* — see Requirements above.
2. **[In-scope tidy-up]** Returning the local checkout to `main` and deleting the merged local
   feature branch is not spelled out in Task 2's action text, but the plan's objective requires
   "Phase 17 builds on a current default branch". Done with `pull --ff-only` and a safe `branch -d`;
   the remote branch was left alone, matching 15-05's scoping.

## Threat Model Compliance

| Threat ID | Disposition | Evidence |
|---|---|---|
| T-16-27 | mitigated | No merge occurred before the user's literal `"Approved — merge"` was recorded against a question that named both judgement calls. `auto_advance` was not applied to this `gate="blocking"` checkpoint |
| T-16-28 | mitigated | Criterion 3 is recorded as PARTIALLY met, with the uncovered case (`version = ">= 3.0"`) named in the verdict, in ADR-015 and in the blueprint note. No full-coverage claim appears anywhere in this record |
| T-16-29 | mitigated | Every post-merge content assertion used `git show origin/main:<path>` after an explicit `fetch`, and all of them ran **before** the local checkout was moved off the feature branch |
| T-16-30 | mitigated | `jobs.sca.name` was re-parsed from `origin/main` and byte-dumped (`e2 80 94` = U+2014) rather than copied from 15-05 or 16-05 |
| T-16-SC | mitigated | Zero installs performed by this plan |

## User Setup Required

None. The merge is complete and `main` is current.

## Next Phase Readiness

- `OttawaCloudConsulting/security-platform` `main` is at `40682ce` and carries the four-tool `sca`
  job, the three detector scripts, the extended smoke gate and both fixture changes. Phase 17 starts
  from a current default branch with a clean local checkout.
- Phase 17 has its four hand-forwards (numbered filenames, SARIF availability, pip-audit's missing
  severity field, `--audit-level` vs `--severity`) and does not need to re-derive any of them.
- Phase 18 has the frozen, byte-exact check-run name and the per-tool exit-code semantics it must
  gate on.
- No blockers. The only loose ends are the undeleted remote feature branch and the stale
  `cicd/.github/workflows/security.yml` in the outer repo, both non-blocking and both recorded above.

---
*Phase: 16-sca-ecosystem-coverage*
*Completed: 2026-09-11*

## Self-Check: PASSED

| Check | Result |
|---|---|
| `.planning/phases/16-sca-ecosystem-coverage/16-07-SUMMARY.md` exists | FOUND (this file) |
| PR #7 state | `MERGED`, merge commit `40682cea329c34b65115236bd449d16f84432e0e` |
| Merge commit is an object in `repos/security-platform` and an ancestor of `origin/main` | FOUND (`git cat-file -t` = commit; `merge-base --is-ancestor` rc=0; `origin/main` head is `40682ce Merge pull request #7 …`) |
| Plan verify #1 (`gh pr list --state merged --head …`) | PASS — `pr=7 merge=40682cea329c34b65115236bd449d16f84432e0e` |
| Plan verify #2 (`origin/main` carries `detect-terraform.sh` invocation, `requests==2.19.1`, `package-lock.json` in `detect-npm.sh`, `run_scan_rc` in `smoke-scans.sh`) | PASS |
| Plan verify #3 (SUMMARY contains `MERGED`, `Criterion 3`, `Criterion 4`, `SCA — Trivy Filesystem`, `Phase 17`; SCA-01/02/03 `[x]`) | PASS |
| All seven remote paths present (`cat-file -e origin/main:<path>`) | FOUND — workflow, three detectors, smoke gate, both fixtures |
| `jobs.sca.name` re-parsed from `origin/main` | `SCA — Trivy Filesystem`, bytes `…20 e2 80 94 20…` (U+2014) |
| Job structure on `origin/main` | five job ids, zero `needs:` keys — unchanged from Phase 15 |
| ROADMAP Phase 16 | row `7/7 | Complete | 2026-09-11`, phase checkbox and 16-07 plan checkbox both `[x]` |
| STATE.md | position, progress `[██████████] 100%`, four decisions, P07 metric row, session continuity and Operator Next Steps all updated |
| `repos/security-platform` | clean `main` at `40682ce`, local feature branch deleted, `status --porcelain` empty |
