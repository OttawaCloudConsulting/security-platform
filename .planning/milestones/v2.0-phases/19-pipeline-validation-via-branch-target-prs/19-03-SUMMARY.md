---
phase: 19-pipeline-validation-via-branch-target-prs
plan: 03
subsystem: ci-cd
tags: [pull-request, github-actions, semgrep, gitleaks, checkov, trivy, tflint, push-protection, sc1]

# Dependency graph
requires:
  - phase: 19-01
    provides: fixtures/vulnerable.py, fixtures/secret.env and the local pre/post-fixture Semgrep (3 → 8) and Gitleaks (9 → 11) baselines the CI totals are compared against
  - phase: 19-02
    provides: the branch at d8bd09b — exactly four changed paths, fixtures/README.md and the rule-id-plus-path smoke-gate assertions
  - phase: 18-configurable-gate-mode-and-branch-protection
    provides: the env.GATE_MODE resolution chain and the per-job `Validate gate_mode` step whose stdout the anchored grep counts
provides:
  - "PR #10 — the long-lived Phase 19 validation PR (D-05), OPEN at head d8bd09b"
  - "run 34786019516 — the SC1 source run and the SC3 trace source for plan 04"
  - "the five retained artifacts (expire 2026-12-12) with their ids and sizes"
  - "the preflight baseline plan 05's GATE_MODE restore is proven against: gh variable list EMPTY"
affects: [19-04, 19-05, 19-06, 19-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Every per-job detection asserted by rule id AND fixture path, never by a count and never by non-empty"
    - "Anchored log greps ($) so the Validate gate_mode step's own echoed SOURCE is not counted as output"
    - "Check-run queries filtered by startswith('security / ') — the head SHA carries 12 check runs, not 5"
    - "Artifacts downloaded to explicit -D directories and their unpacked file lists enumerated, not assumed"

key-files:
  created:
    - .planning/phases/19-pipeline-validation-via-branch-target-prs/19-03-SUMMARY.md
  modified:
    - .planning/phases/19-pipeline-validation-via-branch-target-prs/deferred-items.md

key-decisions:
  - "The push blocker was SERVER-SIDE GitHub Push Protection (GH013), not the local pre-push hook. It was cleared by the user approving two per-secret unblock URLs with reason 'used in tests' — no .gitleaksignore fingerprint, no rebase, no history rewrite, no fixture edit."
  - "Approving the allowances did NOT enable Secret Scanning: security_and_analysis still reports secret_scanning and secret_scanning_push_protection as disabled. The allowance is a per-blob bypass, so the measurement conditions for plans 04-06 are unchanged."
  - "VAL-01 NOT marked complete, following 19-01 and 19-02 and the 17-01 precedent: SC2 and SC3 still live in plans 04-06."
  - "Five green `security / ` conclusions are report-only tolerance (continue-on-error: true on every scan step), NOT a claim of zero findings. The Secrets job's own step exited 1 and is visible as a run annotation."

patterns-established:
  - "Record the whole control stack a push traverses — local hook, server-side push protection, CI job — as three separate measurements, because the repo's own documentation described only two of the three"

requirements-completed: []

# Metrics
duration: 22min
completed: 2026-09-13
---

# Phase 19 Plan 03: Open the Validation PR and Capture SC1 Summary

**PR #10 is OPEN against `main` at head `d8bd09b`, its single run `34786019516` concluded under report-only
with five anchored `gate_mode=report-only` lines and zero `blocking`, and all five retained artifacts were
downloaded and read to yield one named, path-scoped detection per job — `eval-detected` at
`fixtures/vulnerable.py`, `aws-access-token` at `fixtures/secret.env:21`, twelve failed Checkov ids on
`fixtures/main.tf`, vulnerabilities on both `fixtures/package-lock.json` and `fixtures/requirements.txt`, and
58 vulnerabilities against the digest-pinned `debian:12-slim` fixture image.**

## Performance

- **Duration:** ~22 min (this resume session). A prior session reached the push and halted at a checkpoint —
  see "The blocked first attempt" below.
- **Tasks:** 2 of 2
- **Inner-repo commits:** none (plan frontmatter `files_modified: []`) — the only inner-repo write was the
  branch push itself, at the already-committed `d8bd09b`
- **Outer-repo commits:** `5bb5883` (deferred log, prior session), `9187d4c` (deferred log update), plus this
  SUMMARY's final docs commit

## The blocked first attempt, and what it measured

The first attempt at Task 1 pushed and was **rejected by GitHub Push Protection**, not by the local hook.

**Provenance of the figures below: they are RECONSTRUCTED from `deferred-items.md` D-19-A, not quoted.** The
rejection happened in a prior session and its raw `remote:` output was not preserved into this one. What
D-19-A recorded at the time is reproduced as a fact table rather than as a fake transcript — writing a
plausible-looking verbatim block for output nobody still holds is exactly the substitution T-19-13 exists to
prevent:

| Field | As recorded in D-19-A |
|---|---|
| Error code | `GH013` — repository rule violations for `refs/heads/feature/phase-19-pipeline-validation` |
| Pattern 1 | Amazon AWS Access Key ID, at `fixtures/secret.env:21` |
| Pattern 2 | Amazon AWS Secret Access Key, at `fixtures/secret.env:22` |
| Named commit | `fbfcbe9` (the 19-01 fixture commit) |
| Side note in the rejection | the repo "does not have Secret Scanning enabled, but is eligible" |

Three layers, measured separately, because the repository's own documentation describes only two of them:

| Layer | `fixtures/README.md` says | Measured 2026-09-13 |
|---|---|---|
| pre-commit Gitleaks hook (`stages: [pre-push]`, entry uses `--staged`) | the bypass is `git push --no-verify` | **no-op** — invoking `.git/hooks/pre-push` with git's exact stdin gave rc=0, `0 commits scanned`, `no leaks found`. Skipped by `--no-verify` on both attempts, and it would have passed anyway. |
| GitHub Push Protection (server-side) | **not mentioned anywhere** | **blocked the push.** `--no-verify` is a client-side flag and cannot reach it. |
| CI `secrets` job (`gitleaks git .`) | "the compensating control" | reached on this attempt and **did** fire — see the SC1 table |

**Resolution, and what was explicitly NOT done.** The user approved the two per-secret unblock URLs with the
reason *"used in tests"*. Nothing in either repository changed to make the push succeed: no
`.gitleaksignore` fingerprint (T-19-11), no rebase or `filter-repo`, no fixture edit, no workflow edit. The
retry then succeeded at the same commit the rejection named.

**The allowance is not an enablement.** After the successful push,
`gh api repos/… --jq .security_and_analysis` still reports `secret_scanning: disabled` and
`secret_scanning_push_protection: disabled`. Free push protection for public repositories is account-level,
and a per-secret allowance is recorded against the two specific blobs. Deferred item **D-19-B** is updated
with this measurement; the measurement conditions for plans 04-06 are unchanged.

## Preflight, recorded verbatim — plan 05's restore is proven against this

| Command | Output |
|---|---|
| `gh variable list -R OttawaCloudConsulting/security-platform` | **nothing** (rc=0, zero lines) — no `GATE_MODE` |
| `gh api repos/…/rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` — **no required status checks** |
| `gh pr list -R … --state open` | **nothing** — zero open PRs before this one, including no Dependabot PR |
| `git diff origin/main --name-only` | `fixtures/README.md`, `fixtures/secret.env`, `fixtures/vulnerable.py`, `scripts/smoke-scans.sh` — exactly four |
| `git status --short` | empty — clean tree |
| `.gitleaksignore` non-comment, non-blank lines | **0**, before and after |
| `git diff origin/main -- .gitleaksignore .pre-commit-config.yaml .github/workflows/` | empty — unchanged |

`gh variable list` being **empty** is the baseline plan 05 must restore the repository to after its
`GATE_MODE=blocking` window: the variable must be **deleted**, not set back to `report-only`.

## The push

| Item | Value |
|---|---|
| Command | `git push --no-verify -u origin feature/phase-19-pipeline-validation` |
| `--no-verify` | required and intended, per `.pre-commit-config.yaml`'s own bypass comment |
| Result | `* [new branch] feature/phase-19-pipeline-validation`, rc=0 |
| `git ls-remote --heads origin feature/phase-19-pipeline-validation` before | empty |
| after | `d8bd09bbbb8d34666cddb7afb0b2c4e3b4c4dca1	refs/heads/feature/phase-19-pipeline-validation` |
| Runs triggered by the push alone | **zero** — confirming there is no `push:` trigger, as designed |

## The pull request

| Field | Value (read back from `gh pr view --json`, never predicted) |
|---|---|
| Number | **10** |
| URL | https://github.com/OttawaCloudConsulting/security-platform/pull/10 |
| State | **OPEN** |
| Mergeable | `MERGEABLE` (at creation and re-checked after the run) |
| Base / head | `main` ← `feature/phase-19-pipeline-validation` |
| Head SHA | `d8bd09bbbb8d34666cddb7afb0b2c4e3b4c4dca1` |
| Commits | 4 — `fbfcbe9`, `22d3328`, `0df88d8`, `d8bd09b` |

The body states all four required things: that the PR deliberately carries seeded findings for all five scan
categories; that it is the Phase 19 validation PR (D-05); that it will be re-run under `GATE_MODE=blocking`
and back; and that the two new fixture files are synthetic and permanent per D-04.

## The run

| Field | Value |
|---|---|
| Run id | **34786019516** |
| Workflow | `PR Security` |
| Event | `pull_request` |
| Head SHA | `d8bd09bbbb8d34666cddb7afb0b2c4e3b4c4dca1` |
| Conclusion | **success** |
| Created / updated | 2026-09-13T22:11:03Z → 22:11:52Z (**49s**) |
| Runs on the branch | **1** — nothing further was pushed |

### Gate-mode evidence, anchored

```
grep -c 'gate_mode=report-only$'  →  5
grep -c 'gate_mode=blocking$'     →  0
```

The anchor was load-bearing, not ceremonial. `grep -n 'gate_mode='` returns **ten** lines: five are the step's
own echoed source, `blocking|report-only) echo "gate_mode=${GATE_MODE}" ;;`, which an unanchored count would
have inflated to 10 and an unanchored `blocking` count to 5. One anchored `report-only` line per job:

| Job | Log line |
|---|---|
| `security / SCA — Trivy Filesystem` | `22:11:10.0484475Z gate_mode=report-only` |
| `security / Container — Trivy Image` | `22:11:11.3303111Z gate_mode=report-only` |
| `security / SAST — Semgrep CE` | `22:11:08.5678312Z gate_mode=report-only` |
| `security / IaC — Checkov` | `22:11:21.4052426Z gate_mode=report-only` |
| `security / Secrets — Gitleaks` | `22:11:09.2181464Z gate_mode=report-only` |

### Check runs on the head SHA

The head SHA carries **12** check runs, not five. Filtering by `startswith("security / ")` yields exactly
**5**, carrying the five byte-exact frozen names:

| Check run (byte-exact) | Conclusion |
|---|---|
| `security / Container — Trivy Image` | success |
| `security / IaC — Checkov` | success |
| `security / SAST — Semgrep CE` | success |
| `security / SCA — Trivy Filesystem` | success |
| `security / Secrets — Gitleaks` | success |

**Green here means report-only tolerance, not zero findings.** `GATE_MODE` resolved to `report-only`, which
sets `continue-on-error: true` on every scan step, so a scanner that exits non-zero still leaves its job
green. The proof that findings existed is in the artifacts below — and, visibly, in the run's own
annotations: `security / Secrets — Gitleaks` logged `Process completed with exit code 1` while concluding
`success`. Had these five been red, that would have meant a job died before its scan step, not that the
scanners were stricter.

The other seven check runs are recorded because a later query that forgets the filter will see them:

| Check run | App | Conclusion |
|---|---|---|
| `GitGuardian Security Checks` | GitGuardian | **failure** |
| `Semgrep OSS` | GitHub Advanced Security | **failure** |
| `Checkov`, `Trivy`, `gitleaks`, `tflint`, `tflint-errors` | GitHub Advanced Security | success |

The two failures are third-party / code-scanning verdicts on the seeded fixtures and are **expected** — they
are outside the five `security / ` checks this phase measures, and they are not gated by `GATE_MODE`.

## Artifact manifest

`artifacts.total_count` = **5**. All five downloaded to explicit `-D` directories and read.

| Artifact | Id | Size (bytes) | Expires | Unpacked files (enumerated, not assumed) |
|---|---|---|---|---|
| `semgrep-results` | 10326766234 | 197,864 | 2026-12-12T22:11:04Z | `semgrep-results.json`, `semgrep.sarif` |
| `checkov-results` | 10326019806 | 5,165 | 2026-12-12T22:11:04Z | `checkov-results.json`, `checkov.sarif` |
| `sca-results` | 10326820911 | 19,918 | 2026-12-12T22:11:04Z | `npm-audit-1.json`, `pip-audit-1.json`, `tflint.sarif`, `trivy-fs.json`, `trivy-fs.sarif` |
| `trivy-image-results` | 10326328889 | 65,242 | 2026-12-12T22:11:04Z | `trivy-image.json`, `trivy-image.sarif` |
| `gitleaks-results` | 10326656573 | 10,397 | 2026-12-12T22:11:04Z | `gitleaks-results.json`, `gitleaks.sarif` |

`sca-results`' npm and pip reports are numbered per input and the numbers were **read**: exactly one of each,
`npm-audit-1.json` and `pip-audit-1.json`. `expired: false` on all five; 90-day retention as 17-04 set it.

## SC1 — the five-row detection table

Every row names a rule id (or Target) **and** a fixture path. No row is a count and no row is "non-empty".

| Check run | Artifact → file | Matched rule id / Target | Fixture path |
|---|---|---|---|
| `security / SAST — Semgrep CE` | `semgrep-results` → `semgrep-results.json` | `python.lang.security.audit.eval-detected.eval-detected` | `fixtures/vulnerable.py:20` |
| `security / Secrets — Gitleaks` | `gitleaks-results` → `gitleaks-results.json` | `aws-access-token` | `fixtures/secret.env:21` |
| `security / IaC — Checkov` | `checkov-results` → `checkov-results.json` | `CKV_TF_1`, `CKV_TF_2` (+10 more, FAILED) | `/fixtures/main.tf` |
| `security / SCA — Trivy Filesystem` | `sca-results` → `trivy-fs.json` | Targets `fixtures/package-lock.json` (npm) and `fixtures/requirements.txt` (pip) | both fixture paths |
| `security / Container — Trivy Image` | `trivy-image-results` → `trivy-image.json` | 58 vulns on `scan-fixture:b6123ab3…` (debian 12.15) | `fixtures/Dockerfile` |

Each assertion exits **3** when its target is absent and **2** on an unreadable report — no `or {}`, no
empty-list default, no swallowed exception. All five exited **0**.

### SAST — measured, with the delta against 19-01

CI total: **8** results. 19-01 measured **3 → 8** locally against the CI-pinned semgrep 1.177.0, so the CI
total matches the local post-fixture measurement **exactly**, with the same rule/path pairs:

| Path | `check_id` | Line |
|---|---|---|
| `fixtures/vulnerable.py` | `python.lang.security.audit.eval-detected.eval-detected` | 20 |
| `fixtures/vulnerable.py` | `python.lang.security.audit.exec-detected.exec-detected` | 24 |
| `fixtures/vulnerable.py` | `python.lang.security.audit.subprocess-shell-true.subprocess-shell-true` | 32 |
| `fixtures/secret.env` | `generic.secrets.security.detected-aws-access-key-id-value…` | 21 |
| `fixtures/secret.env` | `generic.secrets.security.detected-aws-secret-access-key…` | 22 |
| `.github/dependabot.yml` | `package_managers.dependabot.dependabot-missing-cooldown…` | 10 — baseline |
| `cicd/.github/workflows/security.yml` | `yaml.github-actions.security.gha-curl-pipe-shell…` | 102 — baseline |
| `fixtures/Dockerfile` | `dockerfile.security.missing-user.missing-user` | 6 — baseline |

Delta against the 3-finding pre-fixture baseline: **+5**, all five on the two new fixtures. This is why the
assertion ANDs `eval-detected` with `path == fixtures/vulnerable.py` — the three baseline findings alone
would satisfy any count- or non-empty-based check (shared pattern S-4, T-19-12).

### Secrets — measured

CI total: **11** findings. 19-01 measured **9 → 11** locally against gitleaks 8.30.1 — an exact match.
Every entry whose `File` contains `secret.env`, as `(RuleID, File, StartLine)`:

| RuleID | File | StartLine |
|---|---|---|
| `aws-access-token` | `fixtures/secret.env` | 21 |
| `generic-api-key` | `fixtures/secret.env` | 22 |

`Secret` on both entries reads `REDACTED` — `--redact` is intact on every gitleaks invocation and was **not**
removed to make tracing easier (T-19-10). The trace runs on rule id, file and line, which are unredacted.
Note that 8 of the 11 findings are `aws-access-token` in `.planning/` history, which is exactly why the
`File` clause is load-bearing rather than decorative.

### IaC — measured, against CI's Checkov 3.3.17

The report is a **list of five framework blocks** (`terraform`, `dockerfile`, `gitlab_ci`, `github_actions`,
`azure_pipelines`), not a single dict — both shapes were handled and the shape is recorded here so a later
plan does not rediscover it. `checkov_version` reads **3.3.17** in every block, confirming RESEARCH
assumption A2 (CI 3.3.17 vs 3.2.396 locally).

**14 failed checks total.** On `/fixtures/main.tf` — **12**:

`CKV2_AWS_5`, `CKV2_AWS_6`, `CKV2_AWS_61`, `CKV2_AWS_62`, `CKV_AWS_144`, `CKV_AWS_145`, `CKV_AWS_18`,
`CKV_AWS_21`, `CKV_AWS_23`, `CKV_AWS_24`, **`CKV_TF_1`**, **`CKV_TF_2`**

`CKV_TF_1` and `CKV_TF_2` are the unpinned-module-source checks the plan named, and both are present. The
remaining two failures are `CKV_DOCKER_2` and `CKV_DOCKER_3` on `/fixtures/Dockerfile`.

**New observation:** **no** `CKV_SECRET_*` check fired on `fixtures/secret.env` under CI's 3.3.17. The
possibility was anticipated by the plan and is recorded here as measured absence, not silence.
`fixtures/README.md`'s IaC row therefore needs no CI-number correction from this run. Note also that Checkov
paths in the CI report are **leading-slash absolute-from-repo-root** (`/fixtures/main.tf`), unlike Semgrep's
repo-relative paths — a later `==` comparison against `fixtures/main.tf` would silently fail.

### SCA — measured

Both Target strings carrying vulnerabilities, named:

| Target | Type | Vulns | Severity split | Example ids |
|---|---|---|---|---|
| `fixtures/package-lock.json` | npm | 5 | 4 HIGH, 1 CRITICAL | `CVE-2020-8203`, `CVE-2021-23337`, `CVE-2021-44906`, `CVE-2026-4800`, `NSWG-ECO-516` |
| `fixtures/requirements.txt` | pip | 1 | 1 HIGH | `CVE-2018-18074` |

tflint rule ids present in `tflint.sarif`: **`terraform_module_version`, `terraform_required_providers`,
`terraform_required_version`** — both required ids are present, plus one more, consistent with the
0.61/0.64 stability RESEARCH measured.

The two ecosystem sub-scans also produced findings, recorded because they are part of the same artifact:
`npm-audit-1.json` metadata reports 2 vulnerabilities (1 high, 1 critical); `pip-audit-1.json` reports
vulnerable `requests 2.19.1`, `jinja2 2.11.2`, `idna 2.7` and `urllib3 1.23`.

### Container — measured from the report, not from README

| Field | Value |
|---|---|
| `ArtifactName` | `scan-fixture:b6123ab3328c013db621f6de77613aeaf739e62f` |
| Target | `scan-fixture:b6123ab3… (debian 12.15)`, type `debian` |
| Vulnerabilities | **58** |
| Severity split | **54 HIGH, 4 CRITICAL** |

The image is built from `fixtures/Dockerfile`, whose base is digest-pinned:
`FROM public.ecr.aws/docker/library/debian:12-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171`.
The severity split is only HIGH and CRITICAL because the scan step filters severities. **Verified, not
inferred:** `security.yml` L834 runs `trivy image scan-fixture:… --exit-code 1 --severity HIGH,CRITICAL`.
This is not a claim that the image has no lower-severity vulnerabilities — 15-01 measured 222 vulnerabilities
on the same digest-pinned base unfiltered. The same `--severity HIGH,CRITICAL` filter is on both Trivy
filesystem steps (L414 JSON, L434 SARIF), so the SCA counts above are filtered the same way.

## Post-state — what plans 04-07 inherit

| Item | State |
|---|---|
| PR #10 | **OPEN**, `MERGEABLE`, untouched since creation |
| Runs on the branch | **1** (`34786019516`) — no extra push, no empty commit, no re-run |
| `gh variable list` | still **empty** — plan 05 sets and then **deletes** `GATE_MODE` |
| Branch vs `origin/main` | the same four paths; `.gitleaksignore`, `.pre-commit-config.yaml` and both workflow files unchanged |
| Artifacts | retained until **2026-12-12T22:11:04Z** |
| Local copies | the run log and all five unpacked artifacts remain in this session's scratchpad — outside both repositories |

## Deviations from Plan

### Auto-fixed Issues

None. No Rule 1-3 fix was required: every command behaved as the plan predicted.

### Checkpoints

**1. GitHub Push Protection (GH013) — resolved by the user, not by the executor.**

- **Found during:** Task 1, the push, in the prior session.
- **Why it was a checkpoint and not a Rule 3 auto-fix:** every available "fix" was forbidden. A
  `.gitleaksignore` fingerprint is T-19-11 and would silence the CI `secrets` job; a rebase or history
  rewrite would destroy the fixture the phase depends on; editing the fixture would remove the very finding
  SC1 measures. Unblocking requires a human with repository permissions. The executor stopped rather than
  improvising, per the anti-slop protocol.
- **Resolution:** the user approved both unblock URLs with reason "used in tests"; the retry succeeded at the
  same commit `fbfcbe9` the rejection named, with nothing changed in either repository.
- **Cost:** one wave boundary. No measurement was affected — the run that produced all SC1 evidence is the
  first and only run on the branch.

### Intentional divergences

**2. `--head` passed explicitly to `gh pr create`.** The plan's command omits it. Passing it removes any
dependence on the local branch's tracking state and makes the command reproducible from the recorded text.

**3. VAL-01 NOT marked complete.** The plan frontmatter lists `requirements: [VAL-01]`, and the executor
template marks listed requirements complete. Withheld, following 19-01 and 19-02 and the 17-01 precedent:
VAL-01 reads "full pipeline validated using branch-target PRs", and SC2 (the blocking gate) and SC3 (the
end-to-end trace) are still unmeasured, in plans 05 and 04. `requirements.mark-complete` was deliberately not
invoked.

**4. The `security_and_analysis` re-check after the push was not in the plan.** Added because the allowance
approval could plausibly have enabled Secret Scanning, which would have changed the measurement conditions
for plans 04-06. It did not. Recorded in D-19-B rather than left as an assumption.

### Authentication gates

None. `gh` was already authenticated and no package was installed. The push rejection was an authorization
decision about content, not an authentication failure, and is recorded above as a checkpoint.

## Issues Encountered

None unresolved.

Three results that could be misread as failures, and are not:

- **`security / Secrets — Gitleaks` concluded `success` while its own step logged `Process completed with
  exit code 1`.** That is `continue-on-error: true` working exactly as report-only intends. Under plan 05's
  blocking run the same step should turn the check red — that contrast is SC2's evidence.
- **`GitGuardian Security Checks` and `Semgrep OSS` are red on the head SHA.** Both are outside the five
  `security / ` checks and are not gated by `GATE_MODE`. They are third-party and code-scanning verdicts on
  fixtures that exist to be detected.
- **Twelve check runs on the head SHA, not five.** Anticipated by the plan. Every query here filters on
  `startswith("security / ")`; the unfiltered list is recorded above so no later plan mistakes 12 for drift.

## Handoff Notes for Plans 04-07

1. **The SC3 trace source is run `34786019516` on PR #10 at head `d8bd09b`.** Plan 04 must trace from that
   run and no other — there is exactly one run on the branch and no further push may occur before plan 05.
2. **Plan 05's restore target is the DELETION of `GATE_MODE`, not setting it to `report-only`.** The
   preflight measured `gh variable list` as empty, and this SUMMARY is that baseline's record.
3. **The repository has no required status checks** (`rules/branches/main` → `deletion`,
   `non_fast_forward` only). A red check on this PR will not block merge by itself; plan 05 must not
   conclude "blocking works" from a red check alone without stating that fact.
4. **Checkov CI paths carry a leading slash** (`/fixtures/main.tf`). Any later `==` comparison against
   `fixtures/main.tf` will silently fail — use a containment test.
5. **Push Protection will block any future push of a new credential-shaped fixture,** regardless of
   `--no-verify` and regardless of `security_and_analysis` reporting `disabled`. Plan a human unblock step
   into any phase that seeds another secret fixture. See D-19-A and D-19-B.
6. **Artifacts expire 2026-12-12T22:11:04Z.** Any evidence a later plan needs from this run must be
   extracted before then; the unpacked copies in this session's scratchpad are not durable.

## Self-Check: PASSED

| Claim | Verification | Result |
|---|---|---|
| This SUMMARY exists at the path the plan names | `[ -f … ]` | FOUND |
| `must_haves.artifacts[0].contains: eval-detected` | `grep -c 'eval-detected'` | 4 occurrences |
| Outer-repo commits `5bb5883`, `9187d4c` | `git log --oneline --all` | both FOUND |
| The four inner commits on PR #10 | `git -C repos/security-platform log --oneline --all` | `fbfcbe9`, `22d3328`, `0df88d8`, `d8bd09b` all FOUND |
| PR #10 still OPEN, 1 run on the branch | `gh pr view --json state`, `gh run list --jq length` | `OPEN`, `1` |

Every figure in this SUMMARY was read from a recorded command's output in **this** session, with exactly one
declared exception: the GH013 rejection details in "The blocked first attempt", which are reconstructed from
`deferred-items.md` D-19-A because the prior session's raw `remote:` output was not preserved. That section
says so in its own words. No figure anywhere in this SUMMARY is a UI impression (T-19-13).
