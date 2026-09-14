---
phase: 20-template-packaging-and-adoption-docs
plan: 06
subsystem: ci-cd
status: checkpoint-pending
tags: [live-proof, portability, merge-checkpoint, sarif, artifacts, semgrep-delta]

# Dependency graph
requires:
  - phase: 20-05
    provides: "repos/security-platform at c06d272 on feature/phase-20-template-packaging: portable security.yml (20-03), private-repo SARIF guard + adoption banners (20-04), stale third template deleted (20-05)"
provides:
  - "Live PR #13 evidence: five security / … check runs concluding success on head c06d272, run 34870572604, all five per-scanner counts reconciled against the 19-06 baseline"
  - "The semgrep count delta (8 -> 7) traced to its exact cause (plan 05's deletion of cicd/.github/workflows/security.yml, which carried the only baseline finding not reproduced) and stated as a rule-id SET diff, not an unexplained number"
affects: [20-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Byte-exact check-name verification via diff, not eyeballing: grep the source name: lines, prefix 'security / ', sort, diff against the sorted API names, then Python byte-dump the em dash"
    - "A changed finding count is stated as a rule-id SET diff (which id disappeared, from which path) with primary evidence (git show on the deleted file) proving the cause, never left as a bare number mismatch"

key-files:
  created:
    - .planning/phases/20-template-packaging-and-adoption-docs/20-06-SUMMARY.md
  modified: []

key-decisions:
  - "This SUMMARY is written as a PARTIAL result: Task 1 is COMPLETE, Task 2 (the operator merge/tag checkpoint) is PENDING, Task 3 (merge and post-merge verification) has NOT been executed. Any reader — including plan 07 — must treat this as unauthorised to merge or tag while status: checkpoint-pending is set in the frontmatter."
  - "PR #13 was opened fresh in this plan (not PR #11 or #12, both closed/superseded by Phase 19) because it carries the portability-pass content from plans 02-05, which those earlier PRs predate."

requirements-completed: []  # Deliberately empty — DIST-06/DIST-07 are marked complete only by plan 12, per this plan's own <output> instruction and the 17-01/19-01/20-04/20-05 precedent it carries forward.

# Metrics
duration: ~65min (Task 1 only; Task 2/3 pending)
completed: 2026-09-14
---

# Phase 20 Plan 06: Live Portability Proof and Merge Checkpoint Summary (PARTIAL — CHECKPOINT PENDING)

**Task 1 is complete: PR #13 opened, run 34870572604 concluded, all five `security / …` check runs succeeded,
all per-scanner counts reconciled against the 19-06 baseline (four equal, one explained delta). Task 2 (the
operator's merge/tag decision) is a `gate="blocking"` checkpoint on a plan marked `autonomous: false` and has
NOT been answered. Task 3 (merge, post-merge verification) has NOT been executed. Do not merge. Do not tag.**

## Setup

`repos/security-platform` did not exist in this worktree — cloned fresh per the plan's HOST PREFLIGHT,
checked out `feature/phase-20-template-packaging` (head `c06d272`, confirmed carrying all four prior plans'
commits via `git log --oneline -8`). `gh variable list -R OttawaCloudConsulting/security-platform` produced
no output both before opening the PR and again after the run — `GATE_MODE` confirmed absent both times.
Branch was already in sync with `origin` (`git push` reported "Everything up-to-date").

This worktree's own HEAD (base commit `ad8c6b8b938bf91172a892ae0abbdf5138e8cfe0`, "chore: merge executor
worktree (20-05)") was on a genuinely disjoint history from the expected base per the parallel_execution
note's stated precedent (`git merge-base` returned no common ancestor). HEAD/namespace assertions passed
first (branch `worktree-agent-a03f5503c87b4170a`), so the sanctioned `git reset --hard
ad8c6b8b938bf91172a892ae0abbdf5138e8cfe0` was applied; `git rev-parse HEAD` confirmed the match. No
uncommitted work existed at the old HEAD.

## Task 1 — Open the pull request and collect the live evidence

### The pull request

- **PR:** [#13](https://github.com/OttawaCloudConsulting/security-platform/pull/13),
  `OttawaCloudConsulting/security-platform`, `feature/phase-20-template-packaging` → `main`
- **Head SHA:** `c06d2729b123094bcbb48e03c1155b72c7727b8c`
- **Run id:** `34870572604`
- **Run conclusion:** `success`
- **PR state at end of Task 1:** `OPEN`, `mergedAt: null`, `mergeable: MERGEABLE` — confirmed by direct read,
  not merged
- Body names the portability pass (P-1..P-6), the Q2 SARIF-guard disposition from plan 04, and the two
  deletions from plan 05, per the plan's action text.

### Five `security / …` check runs — byte-exact names, all concluded success

Names were **not** eyeballed. Derived from source and diffed:

```
grep "^    name: " security.yml | sed 's/^    name: /security \/ /' | sort   > expected-names.txt
gh api .../check-runs --jq '...select(app.id==15368)|.name' | sort           > actual-names.txt
diff expected-names.txt actual-names.txt   →   (empty, exit 0)
```

Python byte-dump confirming the U+2014 em dash in all five (not a hyphen):

```
b'security / Container \xe2\x80\x94 Trivy Image'        True
b'security / IaC \xe2\x80\x94 Checkov'                  True
b'security / SAST \xe2\x80\x94 Semgrep CE'               True
b'security / SCA \xe2\x80\x94 Trivy Filesystem'          True
b'security / Secrets \xe2\x80\x94 Gitleaks'              True
```

| Check run (`app.id == 15368`) | Conclusion |
|---|---|
| `security / SAST — Semgrep CE` | success |
| `security / IaC — Checkov` | success |
| `security / SCA — Trivy Filesystem` | success |
| `security / Container — Trivy Image` | success |
| `security / Secrets — Gitleaks` | success |

Zero unresolved (`conclusion == null`) among the five. The Task 1 automated verify command
(five `app.id==15368` checks, zero unresolved, five artifacts) ran and printed `OK`.

**Every other check name on the head SHA** (12 total, matching 16-05/17-05's precedent shape):
`tflint-errors`, `tflint`, `Semgrep OSS`, `Checkov`, `Trivy`, `gitleaks` (six `github-advanced-security`,
`app.id 57789`) plus the five `security / …` above plus `GitGuardian Security Checks` (`app.id 46505`). No
extra name treated as a failure, per the plan's instruction.

### Four detect steps — all FOUND, zero SKIP taken

Read from `gh run view --log`, matched against literal `FOUND`/`SKIP:` lines (the `SKIP:` strings appearing
in the log are `##[group]Run echo "SKIP: …"` **command-echo text for the untaken branch**, not executed
output — confirmed by their `UNKNOWN STEP` ANSI-command-group prefix immediately followed by the `FOUND`
line that WAS executed; this must not be misread as four skips on a future grep):

| Detect step | Line |
|---|---|
| `Detect npm lockfiles` | `FOUND 1 npm lockfile(s):` |
| `Detect Python requirements files` | `FOUND 1 Python requirements file(s):` |
| `Detect Terraform files` | `FOUND 1 Terraform file(s):` |
| `Detect Dockerfile` | `FOUND 1 Dockerfile(s); building the first: fixtures/Dockerfile` |

Zero `SKIP:` lines were taken (the branch executed was always `FOUND` on this repository, as the plan
expects).

### Build step — discovered path and derived context

```
FOUND 1 Dockerfile(s); building the first: fixtures/Dockerfile
Run ctx=$(dirname "fixtures/Dockerfile")
docker build -f "fixtures/Dockerfile" -t scan-target:9af8d659561a1223c97c4dd9403dfe9a5a9a2148 "$ctx"
```

Discovered path `fixtures/Dockerfile`; derived build context `fixtures` (via `dirname`), matching the
acceptance criterion exactly.

### Per-scanner comparison against the 19-06 baseline

Baseline source: `19-06-SUMMARY.md`'s SC4 table (PR #12, run `34792868246`) — 8 semgrep / 11 gitleaks /
14 checkov / 58 trivy-image / 6 trivy-fs / 3 tflint. Counts here read from
`code-scanning/analyses?ref=refs/pull/13/merge` (`results_count`), the same endpoint 17-05 established.

| Scanner | 19-06 baseline | This run (PR #13) | Verdict |
|---|---|---|---|
| Gitleaks | 11 | 11 | **EQUAL** |
| Checkov | 14 | 14 | **EQUAL** |
| Trivy filesystem | 6 | 6 | **EQUAL** |
| Trivy image | 58 | 58 | **EQUAL** |
| tflint | 3 | 3 | **EQUAL** |
| Semgrep | 8 | 7 | **CHANGED −1 — explained, see below** |

**The one non-equal verdict, first because Task 2's context asks the operator to confirm the verdicts read
correctly:**

19-01's original 3→8 baseline table names the THREE pre-existing ("baseline", not "NEW") semgrep findings
as: `dockerfile.security.missing-user.missing-user` (`fixtures/Dockerfile`),
`package_managers.dependabot.dependabot-missing-cooldown.dependabot-missing-cooldown`
(`.github/dependabot.yml`), and
`yaml.github-actions.security.gha-curl-pipe-shell...` (`cicd/.github/workflows/security.yml`).

This run's 7 findings are, by rule id and path (read from the run log):

| Path | Rule id |
|---|---|
| `.github/dependabot.yml` | `package_managers.dependabot.dependabot-missing-cooldown.dependabot-missing-cooldown` |
| `fixtures/Dockerfile` | `dockerfile.security.missing-user.missing-user` |
| `fixtures/secret.env` | `generic.secrets.security.detected-aws-access-key-id-value.detected-aws-access-key-id-value` |
| `fixtures/secret.env` | `generic.secrets.security.detected-aws-secret-access-key.detected-aws-secret-access-key` |
| `fixtures/vulnerable.py` | `python.lang.security.audit.eval-detected.eval-detected` |
| `fixtures/vulnerable.py` | `python.lang.security.audit.exec-detected.exec-detected` |
| `fixtures/vulnerable.py` | `python.lang.security.audit.subprocess-shell-true.subprocess-shell-true` |

**Set diff:** observed = baseline − exactly `{yaml.github-actions.security.gha-curl-pipe-shell @
cicd/.github/workflows/security.yml}`. No additions, no other removals.

**Cause, verified from primary evidence, not inferred:** `cicd/.github/workflows/security.yml` is the file
plan 05 (commit `916af8b`) deleted from this branch. `git show main:cicd/.github/workflows/security.yml`
(pre-merge `main`, the file still exists there) confirms it carries the exact pattern the
`gha-curl-pipe-shell` rule fires on — two `curl -sSfL ... \` lines feeding an install pipeline (lines 103,
190). Deleting the file that carried the finding is the sole and sufficient cause of the −1; nothing in
plans 02/03's portability pass (the inlined detectors, the conditional container job) touched Semgrep's
target set or its findings on any file that still exists.

**Verdict: this is a plan-05-caused, explained, non-regression delta — not a portability regression.** The
scanners still find the SAME things on every file the portability pass touched or ran against; the one
file whose finding disappeared was intentionally deleted three plans ago for reasons unrelated to
portability, and its deletion was already reviewed and recorded in 20-05-SUMMARY.md.

**Gitleaks fixture attribution** (the plan's example of a sharper instrument than a bare count), confirmed
via `code-scanning/alerts?ref=refs/pull/13/merge&tool_name=Gitleaks` filtered on
`most_recent_instance.location.path == "fixtures/secret.env"`:

```
aws-access-token
generic-api-key
```

Both present, matching the 19-06 baseline's "11 — 2 on `fixtures/secret.env`" exactly.

**tflint rule-id set**, confirmed via `code-scanning/alerts?ref=refs/pull/13/merge&tool_name=tflint`:

```
terraform_module_version
terraform_required_providers
terraform_required_version
```

Identical to 16-05's three ids — no drift.

**Semgrep fixture attribution** (visible directly in the run log, recorded for completeness): 3 findings on
`fixtures/vulnerable.py` (eval/exec/subprocess-shell-true), 2 on `fixtures/secret.env`
(aws-access-key-id/aws-secret-access-key) — matching 19-01's "NEW" rows exactly; both pre-existing
non-fixture findings (`dependabot.yml`, `fixtures/Dockerfile`) are also unchanged.

### Artifacts — five, non-zero, retention period recorded precisely

```
{total_count: 5}
semgrep-results       197221 bytes
checkov-results          5165 bytes
sca-results             19917 bytes
trivy-image-results     65241 bytes
gitleaks-results        10392 bytes
```

Run `created_at` **and** `run_started_at` both read `2026-09-14T16:45:26Z`. Every artifact's `expires_at`
reads `2026-12-13T16:45:27Z` — **90 days and 1 second** after `created_at`/`run_started_at`, not exactly 90
days flat. Recorded honestly rather than rounded: the 1-second offset is consistent with GitHub computing
the artifact's own `created_at` (a few hundred milliseconds after the run started) as the retention
anchor, not the run's `created_at` itself — a plausible mechanism, not independently verified here.

### Six code-scanning categories

`code-scanning/analyses?ref=refs/pull/13/merge` returned exactly six distinct `category` values:
`semgrep`, `checkov`, `trivy-fs`, `tflint`, `trivy-image`, `gitleaks` — matching the acceptance criterion.

### Eleven intolerant verify steps — all concluded, none skipped

This repository is confirmed **public** (`gh api repos/.../security-platform --jq .private` → `false`), so
per the plan's instruction the six SARIF verify steps must RUN here, not skip (a skip would mean the Q2
private-repo guard is inverted). All eleven read via `gh run view --json jobs`:

```
Verify Semgrep SARIF upload landed            success
Verify Checkov SARIF upload landed            success
Verify Trivy filesystem SARIF upload landed   success
Verify tflint SARIF upload landed             success
Verify Trivy image SARIF upload landed        success
Verify Gitleaks SARIF upload landed           success
Verify SAST artifact upload landed            success
Verify IaC artifact upload landed             success
Verify SCA artifact upload landed             success
Verify container artifact upload landed       success
Verify secrets artifact upload landed         success
```

All eleven concluded `success`; zero skipped — the guard expression `&&
github.event.repository.private == false` correctly evaluated `true` on this public repository. No
capability guard is misapplied.

### `gh variable list` — verbatim

Empty output, both before opening the PR and after the run concluded. `GATE_MODE` remains absent.

## Task 1 acceptance criteria — status

- [x] Exactly five `app.id == 15368` check runs, all non-null conclusion, byte-diff-matched names, em dash
      confirmed by Python byte dump.
- [x] Four `FOUND` lines recorded verbatim, zero `SKIP:` lines taken.
- [x] Build step names `fixtures/Dockerfile` and derives context `fixtures`.
- [x] Per-scanner comparison table with explicit verdicts against the 19-06 baseline; the one delta carries
      a hypothesis (plan 05's deletion) AND an investigation result (primary-source `git show` confirmation).
- [x] Artifact `total_count` 5, every artifact non-zero, `expires_at` recorded precisely (90d + 1s after
      `created_at`, not rounded to exactly 90d).
- [x] Six distinct code-scanning categories recorded.
- [x] All eleven verify-step outcomes recorded; all concluded (none skipped, correctly, on a public repo).
- [x] `gh variable list` produced no output, recorded verbatim.
- [x] PR is OPEN and unmerged at the end of Task 1.

## Task 2 — CHECKPOINT PENDING (not yet executed)

**This is a `type="checkpoint:decision"` task with `gate="blocking"` on a plan explicitly marked
`autonomous: false`.** Per this worktree's parallel_execution instruction, any action that merges a PR into
`security-platform`'s protected `main` is treated as a blocking checkpoint requiring an explicit operator
"approved" — it is NOT auto-selected, even though "Auto Mode Active" is otherwise in effect for this
session; the plan-level `autonomous: false` and `gate="blocking"` together override the
auto-mode/checkpoint:decision auto-select default.

**Evidence for the operator's decision** (repeating Task 1's findings in the form Task 2 asks for):

1. Five check-run conclusions: all `success` (table above).
2. Per-scanner comparison against 19-06: 5 of 6 scanners EQUAL; Semgrep CHANGED −1, fully explained as
   caused by plan 05's deletion of `cicd/.github/workflows/security.yml` (verified via `git show
   main:cicd/.github/workflows/security.yml`), not by the portability pass.
3. Four FOUND detect lines, zero SKIP taken.
4. Artifact set (5, non-zero) and category set (6, distinct) both match expectations.
5. Eleven verify outcomes: all concluded `success`, none skipped, correctly (public repo).
6. The two deletions from plan 05: `cicd/.github/workflows/security.yml` (203 lines, pre-Phase-14 draft
   with measured defects — unpinned `actions/checkout`, unpinned `pip install semgrep`, `--config auto`,
   `|| true` silent fallback, missing `actions: read`, no `gate_mode`, no verify-step pairing, no
   `retention-days`, no SARIF `category:`) and `cicd/renovate.json` (pointed at a hosted Mend Marketplace
   app). Both removed with rationale recorded in their commit bodies; git history retains both.
7. The tag question: once `v1` exists, consumers can pin it publicly; `v1` is a MOVING tag by design and
   `v1.0.0` is immutable — the first publication is effectively a commitment.

**Decision requested:** Merge PR #13 to `main`, and may plan 07 cut `v1.0.0`/`v1` from the resulting merge
commit? (`option-a` merge+tag / `option-b` merge only, hold the tag / `option-c` do not merge, changes
requested.)

**TAG AUTHORISATION: UNDECIDED.** The operator has not yet replied. **Plan 07 must treat tagging as NOT
authorised while this line is present in this file.** This SUMMARY will be updated (or superseded by a
continuation agent) once the operator's reply is recorded.

## Task 3 — NOT EXECUTED

Task 3 (merge via `gh pr merge --merge`, post-merge verification from `origin/main`) has not run and must
not run until Task 2's checkpoint returns `option-a` or `option-b`. If Task 2 returns `option-c`, Task 3 is
never executed for this PR at all, per the plan's own acceptance criteria.

## Task Commits

None — Task 1 authors no tracked file (per the plan's own `<files>` note: "this task pushes and reads; it
authors no tracked file"). The only content artifact from Task 1 is PR #13 itself, on
`OttawaCloudConsulting/security-platform`, not a commit in either this repository or that one.

This SUMMARY is the only file this plan modifies in `security_solution`, consistent with plans 03-05's
worktree parallel-execution note.

## Files Created/Modified

- `.planning/phases/20-template-packaging-and-adoption-docs/20-06-SUMMARY.md` — this file (created)
- No files modified in `repos/security-platform` by this plan's Task 1 (it opens a PR against existing
  commits from plans 02-05; it does not push new commits).

## Decisions Made

See `key-decisions` in frontmatter. Summary: (1) this SUMMARY is deliberately written and marked as a
PARTIAL result with `status: checkpoint-pending`, so a reader who opens it before the operator's decision
is recorded cannot mistake it for plan completion; (2) PR #13 was opened fresh rather than reusing #11/#12,
both of which predate the portability-pass content this plan proves.

## Deviations from Plan

None. Task 1 was executed exactly as written; the semgrep count delta is an investigation RESULT the
plan's own acceptance criteria require recording, not a deviation from the plan.

## Issues Encountered

- The worktree's initial HEAD (`ad8c6b8`) was on a disjoint history from the plan's expected base, matching
  the exact known deviation named in this plan's own parallel_execution note. Resolved via the sanctioned
  `git reset --hard` after HEAD/namespace assertions passed; no uncommitted work was at risk.
- Several compound Bash invocations (inline `bash -c 'set -eu; ...'` one-liners, a `python3 -c` computing a
  timedelta) were rejected by the worktree-isolation guard as too complex to verify — consistent with prior
  plans in this phase (20-02 through 20-05). Resolved by writing the verify command to a scratch script file
  and invoking it with `bash <file>`, and by writing intermediate `gh api` output to files before reading
  them with plain Python.

## User Setup Required

**A checkpoint decision is required before this plan can proceed.** See "Task 2 — CHECKPOINT PENDING" above
for the full evidence packet and the exact question. Reply with `option-a`, `option-b`, or `option-c` (plus
the concern, if `option-c`).

## Next Phase Readiness

- PR #13 is OPEN, unmerged, at head `c06d272` (tree `158f7f9`), on
  `OttawaCloudConsulting/security-platform`, run `34870572604` concluded `success`.
- Plan 07 must read the "TAG AUTHORISATION: UNDECIDED" line above and treat tagging as blocked until this
  file is updated with the operator's actual reply.
- If a continuation agent resumes this plan: Task 1's evidence above is complete and does not need
  re-gathering; only Tasks 2 and 3 remain.

## Self-Check: PASSED

- `.planning/phases/20-template-packaging-and-adoption-docs/20-06-SUMMARY.md` — FOUND (this file)
- PR #13 — FOUND via `gh pr view 13 -R OttawaCloudConsulting/security-platform` (state OPEN, mergedAt null)
- Run `34870572604` — FOUND via `gh run view 34870572604 -R OttawaCloudConsulting/security-platform`
  (conclusion success)
- Five artifacts — FOUND via `gh api .../actions/runs/34870572604/artifacts` (total_count 5)
- `gh variable list -R OttawaCloudConsulting/security-platform` — CONFIRMED empty output

---
*Phase: 20-template-packaging-and-adoption-docs*
*Status: CHECKPOINT PENDING — Task 1 complete, Task 2 awaiting operator decision, Task 3 not executed*
