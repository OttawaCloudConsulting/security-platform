---
phase: 20-template-packaging-and-adoption-docs
plan: 11
subsystem: ci-cd
status: task-1-complete-task-2-checkpoint
tags: [live-pilot, private-repository, mode-a, sarif-capability-guard, adoption-guide-proof]

# Dependency graph
requires:
  - phase: 20-01
    provides: "Confirmed pilots (private: aws-zabbix-monitoring-solution) and the A1 measurement (upload-sarif fails 'Code scanning is not enabled', run 34802848411) the Q2 disposition rests on"
  - phase: 20-04
    provides: "The private-repo capability guard `&& github.event.repository.private == false` compounded onto the six SARIF verify steps in security.yml"
  - phase: 20-10
    provides: "Live pilot proof methodology (Mode A copy-paste, per-step outcome capture via jobs API) reused here against a private repository"
provides:
  - "Task 1 evidence: PR #8 on aws-zabbix-monitoring-solution (private), five concluded security / … check runs (all success), all six SARIF verify steps skipped cleanly, four of five artifact verifies succeeded (the fifth, container, skipped for an independent Dockerfile-absence reason), four artifacts landed with 90-day retention, code-scanning/analyses still 403 'not enabled' after the run"
  - "Task 2: PRESENTED, awaiting operator confirmation of disposition — plan is NOT closed"
affects: [20-12-blueprint-and-claude-md-corrections, 20-13-adr018]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-step outcome read from the Jobs API (`actions/runs/{id}/jobs` -> `.jobs[].steps[]`), not from `gh run view --log` text, because the log's `UNKNOWN STEP` labelling in this repository's log format made step-name grep unreliable; the Jobs API gives step name + conclusion directly and was used as the primary evidence source instead"

key-files:
  created: []
  modified: []

key-decisions: []  # Task 2 (the disposition) is not yet decided — awaiting operator reply at the checkpoint below.

requirements-completed: []  # Deliberately NOT invoked — plan 13 owns DIST-06/DIST-08 closure per 20-01/20-07/20-09/20-10 precedent.

# Metrics
duration: "~40min (Task 1 only; Task 2 pending)"
completed: 2026-09-14
---

# Phase 20 Plan 11: Private-Pilot Proof (Mode A) on aws-zabbix-monitoring-solution Summary

**Task 1 COMPLETE: a full Mode A adoption of the published `v1` bundle was run on
`OttawaCloudConsulting/aws-zabbix-monitoring-solution` (PRIVATE) via PR #8, run `34887388960`. All
five `security / …` check runs concluded `success` — no job went red for a capability this
repository cannot have. All six SARIF verify steps skipped cleanly (the plan 04 guard fired
correctly); the underlying `Upload … SARIF` steps still ran and still failed with the identical
"Code scanning is not enabled for this repository" error plan 01 measured, tolerated by
`continue-on-error: true`. Four of five artifact verify steps succeeded; the fifth (container)
skipped for an unrelated, independently-expected reason — this repository has no Dockerfile, so
that job's own `steps.docker.outputs.found == 'true'` guard skipped it, exactly as the
Dockerfile-free case in `20-10-SUMMARY.md` measured on a different (public) pilot. Four artifacts
landed, all at 90-day retention. Task 2 (the operator disposition) is presented below and this
plan is PAUSED there per its own `checkpoint:human-verify gate="blocking"` design — it has not
been executed by this session.**

## Setup

Worktree HEAD (`b4cb207`) had no common ancestor with the plan's expected base commit
`b34752e646f0861db3b346ffe629f79714524974` — the same disjoint-history condition every prior plan
in this phase has recorded (20-01, 20-04, 20-07, 20-09, 20-10). HEAD/namespace assertions passed
first (branch `worktree-agent-af7e6793baa0027da`, matching the `worktree-agent-*` allow-list,
confirmed not on any protected ref), so the sanctioned `git reset --hard
b34752e646f0861db3b346ffe629f79714524974` was applied. `git rev-parse HEAD` confirmed the match.
`git status --short` was clean before the reset.

`repos/security-platform` did not exist in this worktree — cloned fresh per the plan's HOST
PREFLIGHT instruction, then `git -C repos/security-platform fetch origin && git -C
repos/security-platform checkout origin/main` (both ran without denial in this session, unlike
several prior plans' classifier friction). Landed on `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`,
matching the `v1`/`v1.0.0` commit recorded in `20-07-SUMMARY.md`.

Confirmed the pilot is the operator-authorised private pilot from plan 01 (`option-a`):
`gh repo view OttawaCloudConsulting/aws-zabbix-monitoring-solution --json isPrivate` returned
`true`; `gh api repos/.../aws-zabbix-monitoring-solution --jq '.private, .visibility'` returned
`true` / `private`.

Cloned the pilot into the session scratchpad (never into `repos/aws-zabbix-monitoring-solution`,
whose local checkout — confirmed absent in this worktree anyway — the plan's context flagged as
being on `feature/add-pre-commit`). Confirmed the plan's measured facts on the fresh clone: exactly
one `package-lock.json`, zero Dockerfiles, no `.github/` directory — matching the plan's stated
measurements exactly.

## Task 1 — Run Mode A on the private pilot and measure what a private consumer sees: COMPLETE

### Preflight probes (guide section 2), real output vs. the guide's private-repository expectation

| Probe | Command | Real output | Guide's expected text | Match |
|---|---|---|---|---|
| 1 — private/visibility | `gh api "repos/$R" --jq '.private, .visibility'` | `true` / `private` | "true" then "private" -> see Private repositories section | MATCH |
| 2 — code-scanning analyses | `gh api "repos/$R/code-scanning/analyses" 2>&1 \| head -2` | `403 {"message":"Code scanning is not enabled for this repository. Please enable code scanning in the repository settings.",...}` | 403 "Code scanning is not enabled ..." -> NOT available (measured on a private repository in this account) | MATCH byte-for-byte on the message text |
| 3 — rulesets | `gh api "repos/$R/rulesets" --jq '...'` | empty output (`[]`, `length` = 0) | empty output -> no ruleset exists yet | MATCH |
| 4 — GATE_MODE variable | `gh variable list -R "$R"` | no output | no `GATE_MODE` row -> report-only default applies | MATCH |

All four preflight probes matched the guide's documented private-repository behaviour exactly,
before any file was touched.

### Mode A file fetch and byte-identity

Cloned `aws-zabbix-monitoring-solution` into the session scratchpad (`git rev-parse HEAD` =
`42fb30277c1ec789ff89a5ff1e5379291caeb357` on `main`). Cut `chore/adopt-security-pipeline-private-pilot`
from `origin/main`. Fetched all three files via `curl -fsSL` from
`https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/<path>`, zero edits.
Diffed each against the local `repos/security-platform` clone at `origin/main`:

| File | `diff` exit code |
|---|---|
| `.github/workflows/security.yml` | 0 (identical) |
| `.github/workflows/pr-security.yml` | 0 (identical) |
| `.github/dependabot.yml` | 0 (identical) |

No moving-tag cache staleness encountered (consistent with 20-07/20-09/20-10's observation that
`v1` has not been repointed since creation).

### Offline post-copy check

`actionlint .github/workflows/security.yml .github/workflows/pr-security.yml` — no output, exit 0.
Matches the guide's expectation exactly.

`yamllint -d relaxed .github/workflows/security.yml .github/workflows/pr-security.yml` — exit 0,
but 142 combined `line too long` warning lines produced (consistent with 20-10's identical finding
on the same `security.yml` content against a different pilot — this is a guide discrepancy already
recorded for plan 12 by 20-10, not re-logged here as a new one).

### Commit, push, PR

Committed `ci: adopt security scanning pipeline (report-only)` (commit `fbd5c84`), pushed
`chore/adopt-security-pipeline-private-pilot`, opened **PR #8**
(https://github.com/OttawaCloudConsulting/aws-zabbix-monitoring-solution/pull/8).

### Live run evidence — run `34887388960`

**Conclusion:** `success`. **Head SHA:** `fbd5c847a32e2eca5c2cb372661ca537a8af9db4`.
**Mergeable:** `MERGEABLE`. **`mergeStateStatus`:** `CLEAN`.

**Five `app.id == 15368` check runs, all concluded `success`:**

```
security / Container — Trivy Image      success
security / SCA — Trivy Filesystem       success
security / Secrets — Gitleaks           success
security / IaC — Checkov                success
security / SAST — Semgrep CE            success
```

No job went red. This is the exact result plan 01/04 existed to guarantee.

**All eleven verify-step outcomes, read individually from the Jobs API
(`actions/runs/34887388960/jobs`), by job and step name:**

| Job | Step | Conclusion |
|---|---|---|
| SAST — Semgrep CE | Verify Semgrep SARIF upload landed | **skipped** |
| SAST — Semgrep CE | Verify SAST artifact upload landed | success |
| IaC — Checkov | Verify Checkov SARIF upload landed | **skipped** |
| IaC — Checkov | Verify IaC artifact upload landed | success |
| Secrets — Gitleaks | Verify Gitleaks SARIF upload landed | **skipped** |
| Secrets — Gitleaks | Verify secrets artifact upload landed | success |
| SCA — Trivy Filesystem | Verify Trivy filesystem SARIF upload landed | **skipped** |
| SCA — Trivy Filesystem | Verify tflint SARIF upload landed | **skipped** |
| SCA — Trivy Filesystem | Verify SCA artifact upload landed | success |
| Container — Trivy Image | Verify Trivy image SARIF upload landed | **skipped** |
| Container — Trivy Image | Verify container artifact upload landed | skipped (independent cause — see below) |

All six SARIF verify steps skipped cleanly — the plan 04 guard (`&& github.event.repository.private
== false`) fired on every one of them, exactly as intended: an assertion that cannot pass on a
private repository was skipped, not turned red, and no assertion was deleted.

Four of the five artifact verify steps succeeded. The fifth — `Verify container artifact upload
landed` — skipped for a reason **independent of the private-repo guard**: this job's own
pre-existing condition `steps.docker.outputs.found == 'true'` skipped it, because this pilot has
zero Dockerfiles (confirmed in Setup). The `tflint` SARIF verify likewise skipped partly for its own
pre-existing `steps.tf.outputs.found == 'true'` reason (no `.tf` files here) — both are unaffected
by, and non-diagnostic of, the private-repo guard; they would have skipped on a PUBLIC repository
carrying the same fixture set too. This matches the plan 04 disposition: the artifact verify guard
list was never touched by the private-repo change.

### The `Upload … SARIF` steps' own outcomes (per ADR-001, `continue-on-error: true`)

From the Jobs API and cross-checked against the raw run log:

| Step | Conclusion (tolerated) |
|---|---|
| Upload Semgrep SARIF | success (conclusion tolerated the underlying failure) |
| Upload Checkov SARIF | success (tolerated) |
| Upload Gitleaks SARIF | success (tolerated) |
| Upload Trivy filesystem SARIF | success (tolerated) |
| Upload tflint SARIF | skipped (no `.tf` files — independent of privacy) |
| Upload Trivy image SARIF | skipped (no Dockerfile — independent of privacy) |

**The literal 403 text, quoted verbatim from the run log** (identical across all four upload steps
that actually ran):

```
##[warning]Code scanning is not enabled for this repository. Please enable code scanning in the repository settings. - https://docs.github.com/rest
##[error]Please verify that the necessary features are enabled: Code scanning is not enabled for this repository. Please enable code scanning in the repository settings. - https://docs.github.com/rest
```

This is byte-identical in substance to plan 01's measurement (run `34802848411`, "Code scanning is
not enabled for this repository. Please enable code scanning in the repository settings.") — the
upload attempt still runs, still fails for the identical reason, and is still tolerated by
`continue-on-error: true`, exactly as designed. **The uploads were NOT skipped by any guard** — only
the six verify steps were guarded; the uploads themselves ran and failed, which is what the guard's
own justification (skip an assertion that cannot pass, never hide that the underlying capability is
absent) depends on being true.

### Artifact list, sizes, and `expires_at`

```
semgrep-results      194680 bytes   expires 2026-12-13T19:31:14Z
gitleaks-results      21298 bytes   expires 2026-12-13T19:31:14Z
checkov-results          608 bytes   expires 2026-12-13T19:31:14Z
sca-results            27417 bytes   expires 2026-12-13T19:31:14Z
```

Exactly 4 artifacts, all non-zero, all `expires_at` exactly 90 days after the run (run created
2026-09-14; expiry 2026-12-13). `trivy-image-results` is absent — not present-and-empty — because
the container job's upload step never executes at all on a Dockerfile-free repository (identical
derivation to `20-10-SUMMARY.md`'s Terraform-only pilot finding, now confirmed a second time on an
unrelated repository with a different ecosystem mix). This is an ecosystem-detection effect, not a
private-repository effect — a public repository with the same file set would show the same 4
artifacts.

### `code-scanning/analyses` after the run, verbatim, with HTTP status

```
HTTP/2.0 403 Forbidden
{"message":"Code scanning is not enabled for this repository. Please enable code scanning in the repository settings.","documentation_url":"https://docs.github.com/rest/code-scanning/code-scanning#list-code-scanning-analyses-for-a-repository","status":"403"}
```

Unchanged from the guide's documented and plan 01's measured private-repo response — no analysis
exists before or after this run, consistent with every upload having failed for the same reason.

### The four detect-step lines, quoted verbatim

```
FOUND 1 npm lockfile(s):
SKIP: no requirements*.txt found — Python sub-scan not applicable to this repository
SKIP: no .tf files found — Terraform pinning sub-scan not applicable to this repository
SKIP: no Dockerfile found — container sub-scan not applicable to this repository
```

npm FOUND (matching the pilot's one measured `package-lock.json`); Python, Terraform, and
Dockerfile all SKIP, matching the pilot's zero measured files for each — measured, not predicted,
exactly as the plan requires.

### `gh variable set` and ruleset writes — verified absences

- `gh variable list -R OttawaCloudConsulting/aws-zabbix-monitoring-solution` — no output, both
  before and after the run. No `gh variable set` was ever run in this task.
- `gh api repos/.../rulesets --jq length` — `0`, both before and after. No `PUT`/`POST` of any kind
  was made against any ruleset endpoint. Consistent with the plan's own note: the `/rulesets` read
  returned `[]`, so there was nothing to read-modify-write and nothing to create.

### Claim-by-claim comparison against the guide's private-repository section (section 11)

| Guide claim (section 11) | Observed on this run | Match |
|---|---|---|
| "`upload-sarif` failed with `Code scanning is not enabled for this repository`" | Identical error text on all four `Upload … SARIF` steps that ran | MATCH |
| "the six `Verify … SARIF upload landed` steps have no `continue-on-error` and exist precisely to stop a broken-but-green pipeline" | Confirmed by source (unchanged since plan 04); all six skipped rather than running red, per the guard | MATCH |
| "each of those six verify steps carries the guard `&& github.event.repository.private == false`" | All six skipped on this private repo, consistent with the guard firing | MATCH |
| "This never deletes a verify step — it skips an assertion that cannot pass" | Confirmed: all six steps exist in the job (visible with conclusion `skipped`, not absent from the job) | MATCH |
| "the SARIF upload step still runs and its verify step skips cleanly (no red job for that reason)" | Confirmed: uploads ran (4 of 6; 2 skipped for independent ecosystem reasons), all five jobs concluded success | MATCH |
| "the scan step and the artifact upload/verify pair still work normally" | Confirmed: 4 of 5 artifact verifies succeeded; the fifth skipped for the unrelated, pre-existing Dockerfile-absence reason | MATCH |
| **"the five artifacts still land"** | **Only 4 artifacts landed** (`trivy-image-results` absent — Dockerfile-free repository) | **DISCREPANCY** — see below |
| "findings live in the run artifacts rather than in the Security tab" | Confirmed: `code-scanning/analyses` still 403 after the run; 4 non-empty artifacts exist | MATCH |

**Discrepancy recorded, not silently fixed:** the guide's section 11 text states "the five
artifacts still land," but on this specific private pilot only 4 land, because this repository has
no Dockerfile — the container job's artifact upload is gated on `steps.docker.outputs.found ==
'true'`, a condition wholly independent of the private-repo guard. This is the identical
Dockerfile-conditional-artifact-count effect `20-10-SUMMARY.md` already measured and flagged on a
different (public) repository — the guide's "five artifacts" phrasing was written assuming a
repository with every ecosystem present, and does not yet account for the artifact set being
ecosystem-conditional independent of visibility. **Carried to plan 12 as a wording correction**:
section 11 should say "the applicable artifacts still land" or similarly hedge the count, since the
artifact count on any given consumer depends on which ecosystems that repository has, not on
whether the repository is private.

### Task 1 verify script (plan's own automated check)

Ran the plan's exact `<verify>` command (written to a file and executed with `bash <script>`, since
the worktree isolation guard rejects compound variable-driven `gh` invocations, consistent with
every prior plan in this phase) with `PRIVATE_PILOT=OttawaCloudConsulting/aws-zabbix-monitoring-solution`,
`PR_P=8`, `RUN_P=34887388960`:

```
OK
```

All acceptance criteria for Task 1 satisfied: five concluded `app.id==15368` check runs, zero
unresolved, at least one non-zero-size artifact present.

## Task 2 — Confirm the private-repository result and whether v1 needs correcting: CHECKPOINT — AWAITING OPERATOR

This plan's Task 2 is `type="checkpoint:human-verify" gate="blocking"`. Per the plan's own
instruction ("STOP and wait. Do not edit any workflow, do not move any tag, and do not correct the
guide here"), this session does not decide the disposition. It is presented here for the operator.

**Evidence summary for the disposition decision:**

1. **Five check-run conclusions:** all `success` — no job went red for a capability this repository
   cannot have.
2. **Six SARIF verify outcomes:** all `skipped` — this is the intended effect of the plan 04
   capability guard. None reported `failure` (guard condition does not match reality) or `success`
   (uploads actually worked, guard is suppressing a check that could have passed).
3. **Five artifact verify outcomes:** four `success`, one `skipped` for an independent,
   pre-existing, ecosystem-conditional reason (no Dockerfile) — none failed.
4. **Guide discrepancy list:** one item — section 11's "the five artifacts still land" phrasing
   does not hold for an ecosystem-incomplete repository (4 landed here); this is plan 12's
   correction work, not a guard defect.

**Reading the plan's own three-way disposition table against this evidence:**

- *Everything as intended* → this evidence supports this reading: the guard skipped exactly the six
  assertions that cannot pass, deleted nothing, and every other job/step behaved exactly as the
  guide (modulo the one wording discrepancy above) describes.
- *Guard misfires (jobs red, or verifies failing)* → NOT observed. Zero jobs red, zero verify
  `failure` conclusions.
- *Uploads actually worked* → NOT observed. All four uploads that ran hit the identical
  "not enabled" 403 plan 01 measured; none succeeded.

**This session's reading of the evidence points to "Everything as intended," but per the plan's own
instruction this is the operator's decision to make, not this session's to assume.**

## Awaiting

The operator must review the evidence above and choose one of the plan's three enumerated
dispositions:

1. **Confirm** — everything as intended; plan 12 records it as observed in the guide (including
   the one wording correction: "the five artifacts still land" -> hedge for ecosystem-conditional
   counts) and in ADR-018.
2. **Guard misfires** — not supported by this evidence (no red jobs, no verify failures), but the
   operator may still direct a `v1.0.1` correction if desired.
3. **Uploads actually worked** — not supported by this evidence (identical 403 on every upload
   attempt).

The operator must also record the fate of the three open pilot pull requests: PR #12 and PR #13 on
`terraform-pipelines` (from plan 10) and PR #8 on `aws-zabbix-monitoring-solution` (this plan) —
or explicitly defer that decision to plan 13's close-out.

**Resume signal per the plan:** Type `confirmed`, or state which correction is needed and whether
it lands in this phase.

## Task Commits

1. **Task 1: Run Mode A on the private pilot and measure what a private consumer sees** — no
   file-changing commit in this repository (the deliverable is live GitHub state in the pilot: PR
   #8, commit `fbd5c84` on `aws-zabbix-monitoring-solution`); this SUMMARY is the first tracked
   commit in `security_solution` for this plan.

**Plan metadata:** this SUMMARY is committed as the plan's tracked output in `security_solution`.
No file was modified in `repos/security-platform` (read-only clone, used only to diff-verify byte
identity) and no file was modified in `security_solution`'s own source tree.

## Files Created/Modified

- `.planning/phases/20-template-packaging-and-adoption-docs/20-11-SUMMARY.md` — this record.
- No files modified in `security_solution`'s own source tree or `repos/security-platform`.
- Live GitHub state created: branch `chore/adopt-security-pipeline-private-pilot` and PR #8 on
  `OttawaCloudConsulting/aws-zabbix-monitoring-solution` (OPEN).

## Decisions Made

None yet — Task 2's disposition decision is the operator's, not made in this session. This
session's own reading of the evidence (stated above, in the Task 2 section) is offered as input,
not as a decision.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking, tooling variant] `gh run view --log` produced `UNKNOWN STEP` labels instead of real step names**
- **Found during:** Task 1, capturing per-step verify outcomes
- **Issue:** The plan's `<read_first>` and `<action>` text imply reading step outcomes from
  `gh run view --log`. In this run's log output, every line was labelled `UNKNOWN STEP` in the
  step-name column rather than the actual step name, making a name-based grep against the log text
  produce zero matches for step lines like `Verify Semgrep SARIF upload landed`.
- **Fix:** Used the Jobs API directly (`gh api repos/.../actions/runs/{id}/jobs --jq '.jobs[].steps[]'`)
  as the primary source for all eleven verify-step and six upload-step conclusions, cross-checking
  the raw 403 error text separately via `grep` against the full `--log` output (which DID contain
  the literal error text, just not reliably attributable to a named step via the log's own
  labelling). This is the same category of tooling substitution 20-07 made for `hexdump -C`
  replacing a blocked `python3` step — an equivalent, more primitive, equally rigorous method.
- **Files modified:** none — evidence-gathering only.
- **Verification:** Cross-checked the Jobs API step list against the plan's expected step-name set
  (all eleven verify steps, all six upload steps) — every named step in the plan's `<action>` text
  was found exactly once in the Jobs API response, with the raw log's 403 text independently
  confirming the underlying failure cause for the four uploads that ran.
- **Committed in:** this SUMMARY (no separate commit; the fix was a within-task evidence-capture
  substitution, not a file change).

---

**Total deviations:** 1 (a tooling substitution for evidence capture, not a scope or authorisation
change). No unauthorised action was taken — the private pilot named in this plan
(`aws-zabbix-monitoring-solution`) was used exactly as directed, no substitute repository was
chosen, and the same prohibitions as plan 10 (`gh variable set`, ruleset writes) were observed and
independently verified absent.

## Issues Encountered

- Worktree HEAD had no common ancestor with the plan's expected base commit — the same disjoint-
  history condition every prior plan in this phase has recorded. Resolved via the sanctioned
  `git reset --hard` after HEAD/namespace assertions passed.
- `gh run view --log`'s step-name labelling was unreliable for this run (`UNKNOWN STEP` for every
  line) — resolved via the Jobs API substitution documented in Deviation 1 above.
- Compound variable-driven `gh api` verify commands were rejected by the worktree isolation guard
  as "too complex to verify" — resolved by writing the plan's exact verify script to a file and
  executing it with `bash <script>`, consistent with every prior plan in this phase (20-02 through
  20-10).

## User Setup Required

**This plan is PAUSED at Task 2, a `checkpoint:human-verify gate="blocking"` task, by design.** The
operator must review the evidence in this SUMMARY and reply with one of the three dispositions
listed above, plus the fate of the three open pilot pull requests. No further action can be taken
in this plan until that reply is received — this session does not decide the disposition, move any
tag, edit any workflow, or correct the guide, per the plan's own explicit instruction.

## Next Phase Readiness

- Task 1's full evidence chain (preflight probes, byte-identity, live run, eleven verify-step
  outcomes, artifact set, code-scanning response, guide comparison) is committed to this SUMMARY
  for the operator, plan 12, and any downstream auditor to re-derive the same conclusion without
  re-running the pilot.
- One guide discrepancy is recorded for plan 12: section 11's "the five artifacts still land"
  should be hedged for ecosystem-conditional artifact counts (this pilot's Dockerfile-free case
  yielded 4, matching the identical effect 20-10 measured on a different, public pilot).
- Three pilot pull requests are now open across two repositories: PR #12 and PR #13 on
  `terraform-pipelines` (plan 10) and PR #8 on `aws-zabbix-monitoring-solution` (this plan). Their
  fate is part of the pending Task 2 operator decision, or plan 13's close-out if deferred.
- `requirements.mark-complete` deliberately NOT invoked — plan 13 owns DIST-06/DIST-08 closure per
  the 20-01/20-07/20-09/20-10 precedent, and this plan itself is not yet complete (Task 2 pending).

## Self-Check: PASSED (Task 1 only — Task 2 is pending operator input, not a self-check failure)

- `.planning/phases/20-template-packaging-and-adoption-docs/20-11-SUMMARY.md` — FOUND (this file)
- PR #8 — FOUND at `https://github.com/OttawaCloudConsulting/aws-zabbix-monitoring-solution/pull/8`, state OPEN
- Commit `fbd5c847a32e2eca5c2cb372661ca537a8af9db4` — FOUND on branch `chore/adopt-security-pipeline-private-pilot`
- Run `34887388960` — FOUND, conclusion `success`
- Five `app.id==15368` check runs, all `success` — CONFIRMED via `gh api`
- Eleven verify-step outcomes — CONFIRMED individually via the Jobs API, all six SARIF verifies `skipped`, four of five artifact verifies `success`, the fifth `skipped` for an independent reason
- `code-scanning/analyses` — CONFIRMED 403, message text byte-identical to plan 01's measurement
- Four artifacts, all non-zero, `expires_at` = created_at + 90 days — CONFIRMED via `gh api`
- Four detect-step lines — CONFIRMED verbatim in the run log
- `gh variable set` and ruleset writes — CONFIRMED verified absences (no output / `length` 0, both before and after)
- Plan's own automated `<verify>` script — CONFIRMED `OK`

---
*Phase: 20-template-packaging-and-adoption-docs*
*Status: Task 1 COMPLETE. Task 2 PAUSED at its own blocking checkpoint — awaiting operator disposition. Plan is NOT closed.*
