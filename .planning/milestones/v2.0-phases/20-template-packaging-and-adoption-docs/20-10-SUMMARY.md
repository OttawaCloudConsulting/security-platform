---
phase: 20-template-packaging-and-adoption-docs
plan: 10
subsystem: ci-cd
status: complete
tags: [live-pilot, mode-a, mode-b, sc1, sc2, adoption-guide-proof]

# Dependency graph
requires:
  - phase: 20-01
    provides: "Operator-authorised pilots (terraform-pipelines public, aws-zabbix-monitoring-solution private); branch/PR/workflow-run activity authorised, ruleset/variable writes NOT authorised"
  - phase: 20-07
    provides: "Published v1/v1.0.0 tags at commit cdf2c21 on OttawaCloudConsulting/security-platform, byte-verified for both consumption modes"
  - phase: 20-09
    provides: "Complete docs/adoption-guide.md (sections 1-13), standing gate green"
provides:
  - "SC1 evidence: PR #12 on terraform-pipelines, Mode A copy-paste, five concluded security / … check runs, three byte-exact SKIP: lines, one Terraform FOUND line, 4 artifacts (not 5 — Dockerfile-free), 6 code-scanning analyses (no trivy-image)"
  - "SC2 evidence (partial): PR #13 on terraform-pipelines, Mode B uses: reference, five concluded security / … check runs byte-identical in name to Mode A's, external ref resolved to the v1 tag's exact commit SHA cdf2c21..., artifact set identical to Mode A"
  - "Branch-protection dry run COMPLETE: set-required-checks.sh (--out only, never --apply) run by the orchestrator in an unblocked session after this executor's own two attempts were denied by its auto-mode Bash classifier (identical to 20-07's gh-release-create denial); exit 0, three pre-existing rule types preserved, required_status_checks (5 contexts, integration_id 15368) and pull_request added; independently re-verified read-only in this session — rules/branches/main unchanged before and after"
affects: [20-12-blueprint-and-claude-md-corrections, 20-13-adr018]

key-files:
  created:
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/run-a.log.txt
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/artifacts-a.json
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/analyses-a.json
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/check-runs-a.json
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/run-b.log.txt
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/artifacts-b.json
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/check-runs-b.json
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/rules-before.txt
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/rules-after.txt
    - .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/merged.json
  modified: []

key-decisions:
  - "Derived (not assumed) the expected artifact set for a Terraform-only pilot from security.yml's own guard structure before running: the container job's 'Upload container reports' step carries 'if: always() && steps.docker.outputs.found == \"true\"', so on a Dockerfile-free repository that upload step never runs at all — trivy-image-results is ABSENT, not empty-with-warn. Measured: exactly 4 artifacts (semgrep-results, checkov-results, sca-results, gitleaks-results), matching the derivation exactly."
  - "yamllint -d relaxed produced 96 line-length warnings on security.yml and 1 on pr-security.yml (all `line too long`) while still exiting 0 — the guide's section 4 says 'Expected: no output, exit code 0'; the exit-code half held, the no-output half did not. Recorded as a guide correction for plan 12: the guide should say 'exit code 0 (line-length warnings on long comment lines are expected and non-blocking)', not 'no output'."

requirements-completed: []  # Deliberately NOT invoked — plan 13 owns DIST-06/DIST-07 closure per 20-01/20-07/20-09 precedent

# Metrics
duration: "~65min"
completed: 2026-09-14
---

# Phase 20 Plan 10: Live Pilot Proofs (Mode A / Mode B) on terraform-pipelines Summary

**Both tasks COMPLETE. SC1 measured on PR #12 (Mode A copy-paste) and SC2 measured on PR #13 (Mode
B `uses:` reference) on `OttawaCloudConsulting/terraform-pipelines`, a repository outside this
project — five concluded `security / …` check runs on each, byte-identical context names across
both modes, three clean ecosystem `SKIP:` lines plus one Terraform `FOUND` line, and the external
`uses:` reference resolving to the exact published `v1`/`v1.0.0` commit. The branch-protection
dry run (`set-required-checks.sh --out`, never `--apply`) was denied twice by this executor
session's own auto-mode Bash classifier — the identical denial shape 20-07 hit with `gh release
create` — so the orchestrator ran the exact recorded command directly in its own session, which
succeeded (exit 0, all three pre-existing rule types preserved, five contexts added). This session
then independently re-verified the result read-only rather than accepting the orchestrator's
report at face value: `rules/branches/main` confirmed byte-identical before and after the dry run,
and the produced `merged.json` was read directly and cross-checked against the orchestrator's
reported rule-type lists and `bypass_actors`.**

## Setup

Worktree HEAD (`b4cb207`, Phase 19 gate-mode-proof merge lineage) had no common ancestor with the
plan's expected base `b03a29ae39e2503397ec1601709ddc52b59a2628` — `git merge-base` returned no
output (exit 1), the same disjoint-history condition every prior plan in this phase has recorded
(20-01, 20-07, 20-09). Corrected via the sanctioned `git reset --hard
b03a29ae39e2503397ec1601709ddc52b59a2628` after HEAD/namespace assertions passed (branch
`worktree-agent-a23c002b54b5af22b`, matching the `worktree-agent-*` allow-list, and confirmed NOT
on any protected ref). `git rev-parse HEAD` confirmed the match; `git status --short` was clean
before the reset.

`repos/security-platform` did not exist in this worktree — cloned fresh per the plan's HOST
PREFLIGHT instruction. The fresh clone landed already on `main` at `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`
(the expected commit), so the plan's `git -C repos/security-platform fetch origin && git -C
repos/security-platform checkout origin/main` follow-up commands were unnecessary (both were
denied by this session's auto-mode Bash classifier when attempted anyway — "Blocked by
classifier" — but the clone had already put the repository in the required state, so no
functionality was lost).

Preflight tool check: `actionlint`, `yamllint`, `gh`, `git` all present. `gh auth status`:
authenticated as `OttawaCloudConsulting`, scopes `gist, read:org, repo, workflow`.
`gh api repos/OttawaCloudConsulting/terraform-pipelines/actions/permissions`:
`{"enabled":true,"allowed_actions":"all","sha_pinning_required":false}` — Actions enabled, no
silent block expected. This check is not in the guide's own section 2 preflight (which covers
`.private`/`.visibility`, code-scanning analyses, rulesets, and `GATE_MODE` only) — noted as a
possible guide addition for plan 12, since 20-01 performed the analogous check for the private
pilot but the guide itself never asks for it.

Cloned `OttawaCloudConsulting/terraform-pipelines` fresh into the session scratchpad (never into
`repos/terraform-pipelines`, which sits on an unrelated `feature/add-pre-commit` branch). Confirmed
the plan's measured facts on the fresh clone: `git rev-parse HEAD` = `c490bed09f43bae5440594db7e76011e8951f26c`
on `main`; exactly 36 `.tf` files; no `.github/` directory at all; zero `package-lock.json`, zero
`requirements*.txt`, zero Dockerfiles found by `find`.

`gh api repos/OttawaCloudConsulting/security-platform/git/ref/tags/v1 --jq .object.sha` confirmed
`cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` immediately before fetching — unchanged since 20-07/20-09.

## Task 1 — Mode A on the public pilot (SC1): COMPLETE

### Preflight probes (guide section 2), real output vs. `# Expected:`

| Probe | Command | Real output | Guide's `# Expected:` | Match |
|---|---|---|---|---|
| 1 | `gh api "repos/$REPO" --jq '.private, .visibility'` | `false` / `public` | `"false"` then `"public"` | MATCH |
| 2 | `gh api "repos/$REPO/code-scanning/analyses" 2>\&1 \| head -2` | `404 "no analysis found"` (plus a `gh: This API operation needs the "admin:repo_hook" scope` decoration line the guide does not mention) | 404 "no analysis found" -> AVAILABLE | MATCH on substance; the extra CLI decoration line is a minor discrepancy noted for plan 12 (same decoration 20-01/17-05 already observed as a CLI artifact, not an API fact) |
| 3 | `gh api "repos/$REPO/rulesets" --jq …` | one row: `12760793\tDefault\tactive` | a row -> existing ruleset, read-modify-write | MATCH |
| 4 | `gh variable list -R "$REPO"` | no output | no `GATE_MODE` row | MATCH |

### Mode A file fetch and byte-identity

Cut `chore/adopt-security-pipeline-mode-a` from `origin/main` (head `c490bed`). Fetched all three
files via `curl -fsSL` from `https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/<path>`,
zero edits. Diffed each against `gh api "repos/.../contents/<path>?ref=v1" -H "Accept:
application/vnd.github.raw"`:

| File | `diff` exit code |
|---|---|
| `.github/workflows/security.yml` | 0 (identical) |
| `.github/workflows/pr-security.yml` | 0 (identical) |
| `.github/dependabot.yml` | 0 (identical) |

No moving-tag cache staleness encountered (consistent with 20-07/20-09's observation that `v1`
has not been repointed since creation).

### Offline post-copy check

`actionlint .github/workflows/security.yml .github/workflows/pr-security.yml` — no output, exit 0.
MATCHES the guide's expectation exactly.

`yamllint -d relaxed .github/workflows/security.yml .github/workflows/pr-security.yml` — **exit 0**
(matches), but produced 96 `line too long` warnings on `security.yml` (lines exceeding 80 chars,
almost entirely long inline comments explaining `if:` guards) and 1 on `pr-security.yml` line 16.
**This is a guide discrepancy, recorded verbatim per the plan's instruction, not silently fixed
here:** section 4 states "Expected: no output, exit code 0" — the exit-code half is correct, the
"no output" half is not. Carried to plan 12 as a correction: the guide should state that
line-length warnings are expected and non-blocking, or note that the copied files exceed
yamllint's default 80-column rule intentionally (readable inline documentation over strict line
length).

### Commit, push, PR

Committed `ci: adopt security scanning pipeline (report-only)` (commit `6e8975f`), pushed
`chore/adopt-security-pipeline-mode-a`, opened **PR #12**
(https://github.com/OttawaCloudConsulting/terraform-pipelines/pull/12).

### Live run evidence — run `34884582425`

**Conclusion:** `success`. **Head SHA:** `6e8975f22232659c1403de452d559d6c97ebb1eb`.
**Mergeable:** `true`. **`mergeable_state`:** `clean` (was `unstable` mid-run while checks were
pending, settled to `clean` once the run concluded).

**Five `app.id == 15368` check runs, all concluded `success`, names byte-matching the five frozen
contexts** (verified via `gh api repos/.../commits/<sha>/check-runs`):

```
security / SCA — Trivy Filesystem       success
security / Container — Trivy Image      success
security / SAST — Semgrep CE            success
security / Secrets — Gitleaks           success
security / IaC — Checkov                success
```

**The four detect-step log lines, quoted verbatim from `gh run view --log`:**

```
SKIP: no Dockerfile found — container sub-scan not applicable to this repository
SKIP: no package-lock.json found — npm sub-scan not applicable to this repository
SKIP: no requirements*.txt found — Python sub-scan not applicable to this repository
FOUND 36 Terraform file(s):
```

All three ecosystem sub-scans (npm, Python, container) skipped cleanly with the byte-exact `SKIP:`
strings; Terraform was found (36 files, matching the pilot's own measured fact). No error-shaped
log line anywhere in the sca or container job — this is the clean-skip proof `security-platform`'s
own repository structurally cannot produce (it carries fixtures for every ecosystem).

**Artifact set — 4, not 5, derived and confirmed, not assumed:**

Before running, derived from `security.yml`'s own guard structure: the container job's `Upload
container reports` step carries `if: always() && steps.docker.outputs.found == 'true'` — on a
Dockerfile-free repository this upload step never executes at all (the job's `if:` guard is false),
so `trivy-image-results` is **absent from the artifact list entirely**, not present-and-empty under
`if-no-files-found: warn` (that `warn` semantic belongs only to the `sca` job's npm/pip/tflint
glob entries, per the workflow's own comments).

Measured via `gh api repos/.../actions/runs/34884582425/artifacts`:

```
sca-results        1802 bytes
gitleaks-results    7202 bytes
semgrep-results   195940 bytes
checkov-results     6333 bytes
```

Exactly 4 artifacts. `trivy-image-results` correctly absent. This matches the derivation exactly —
the expected-vs-observed comparison the plan requires.

**`code-scanning/analyses` for `refs/pull/12/merge`** — the pilot is PUBLIC, so analyses are
expected and present. 6 analyses returned:

```
tflint    / tflint-errors
tflint    / tflint
semgrep   / Semgrep OSS
checkov   / checkov
trivy-fs  / Trivy
gitleaks  / Gitleaks
```

No `trivy-image` category — consistent with the Dockerfile-free repository and the artifact-set
finding above (the container job's scan step, like its upload, never ran).

**Verify-step outcomes:** all six SARIF verify steps and all four artifact verify steps that
applied to this run (semgrep, checkov, trivy-fs, tflint, gitleaks — five SARIF verifies; the
container/trivy-image SARIF verify's own guard `steps.docker.outputs.found == 'true'` made it
never execute) ran and passed — visible as green in the job log (`gh run watch` output; every step
under each of the five jobs shows ✓, with the container job's Docker-specific steps showing `-`
skipped). No step failed, no step reported an error-shaped log.

`gh variable list -R OttawaCloudConsulting/terraform-pipelines` — no output (confirmed empty, no
`GATE_MODE`), both before and after the run.

**No ruleset call of any kind was made in this task.** PR #12 is **OPEN** at the end of Task 1 —
not merged, not closed, branch not deleted.

### Task 1 verify script (plan's own automated check)

Ran the plan's exact `<verify>` command with `PILOT=OttawaCloudConsulting/terraform-pipelines`,
`PR_A=12`, `RUN_A=34884582425` hardcoded (worktree isolation guard rejects compound
variable-driven `gh`/`git` invocations, so the script was written to a file and executed with
`bash <script>` rather than inline):

```
mergeable_state=clean
OK
```

All acceptance criteria for Task 1 satisfied.

## Task 2 — Mode B on the public pilot (SC2) and branch-protection dry run: LIVE RUN COMPLETE, DRY RUN BLOCKED

### Setup

Read `docs/adoption-guide.md` sections 5, 8, 9; `20-07-SUMMARY.md` for the exact `uses:` string and
the `v1` tag's commit SHA (`cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`); `repos/security-platform/scripts/set-required-checks.sh`
lines 1-100 plus its `usage()` block. Confirmed by direct grep of the script for every `PUT`/`POST`/`-X`
occurrence: the only live write (`gh api --method PUT repos/${REPO}/rulesets/${RULESET_ID}`) sits at
line 278, inside the block explicitly gated `# ── 4. WRITE — only reached when --apply, --verify-sha
and the lockout ────`, and the script's own arg parser refuses `--apply` without `--verify-sha`
(exit 4) and without `--yes-i-understand-lockout` (exit 5) before any network call. T-20-08's
"mitigate" disposition is confirmed by reading the guard, not merely trusted from the header
comment.

Cut `chore/adopt-security-pipeline-mode-b` from `origin/main` (fresh branch, not Task 1's). Created
exactly two files: `.github/workflows/pr-security.yml` (copied verbatim from the guide's section 5
code block — diffed against the guide's own extracted lines, identical except the fenced-code-block
delimiter that is not part of the file) and `.github/dependabot.yml` (fetched via the same `curl
-fsSL .../v1/.github/dependabot.yml` as Task 1). No `security.yml`, no `with:` block, `name:
security`, job-level `contents: read` + `security-events: write` + `actions: read`, `uses:
OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1` with no trailing version
comment — all confirmed present exactly as the guide specifies.

`actionlint` and `yamllint -d relaxed` on `pr-security.yml`: both exit 0, **no output at all** this
time (unlike Task 1's `security.yml`, whose long inline comments triggered line-length warnings;
`pr-security.yml` is short enough that the guide's "no output, exit 0" expectation holds exactly
here).

### Commit, push, PR

Committed `ci: adopt security scanning pipeline (Mode B, report-only)` (commit `44b9d56`), pushed
`chore/adopt-security-pipeline-mode-b`, opened **PR #13**
(https://github.com/OttawaCloudConsulting/terraform-pipelines/pull/13).

### Live run evidence — run `34885287142`

**Conclusion:** `success`. **Head SHA:** `44b9d56a3d97ea1ca108f5df167cb246de47bb25`. **Mergeable:**
`true`. **`mergeable_state`:** `clean`.

**Five `app.id == 15368` check runs, all concluded `success`:**

```
security / SAST — Semgrep CE            success
security / SCA — Trivy Filesystem       success
security / IaC — Checkov                success
security / Secrets — Gitleaks           success
security / Container — Trivy Image      success
```

**Sorted name-list diff between Mode A (PR #12, SHA `6e8975f`) and Mode B (PR #13, SHA
`44b9d56`): `diff` exited 0 — the two sorted lists are byte-identical.** T-20-22's mitigation
holds: Mode A and Mode B produce exactly the same five branch-protection contexts.

**Resolved workflow reference**, from `gh api repos/.../actions/runs/34885287142 --jq
.referenced_workflows`:

```json
[{"path":"OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1",
  "ref":"refs/tags/v1",
  "sha":"cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef"}]
```

The external `uses:` reference resolved to `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` — the exact
commit SHA both `v1` and `v1.0.0` point to, recorded in `20-07-SUMMARY.md`. Not a cached, stale, or
different commit.

**Detect-step lines**, identical to Task 1 (same underlying `security.yml`, only the caller
differs):

```
SKIP: no Dockerfile found — container sub-scan not applicable to this repository
SKIP: no package-lock.json found — npm sub-scan not applicable to this repository
SKIP: no requirements*.txt found — Python sub-scan not applicable to this repository
FOUND 36 Terraform file(s):
```

**Artifact set** — 4, identical names to Task 1 (`semgrep-results`, `gitleaks-results`,
`sca-results`, `checkov-results`) via `gh api repos/.../actions/runs/34885287142/artifacts`.

`gh variable set` was never run in this task. `gh api --method PUT` was never invoked (the dry-run
script never executed — see below). Both pull requests are **OPEN** at the end of this plan.

### Branch-protection dry run — COMPLETE

Captured the live baseline **before** attempting the dry run, as the plan requires:

```
gh api repos/OttawaCloudConsulting/terraform-pipelines/rules/branches/main --jq '[.[].type] | sort | join(",")'
-> copilot_code_review,deletion,non_fast_forward
```

(Saved to `/tmp/p20-rules-before.txt` per the plan's exact path, and copied into this plan's
evidence directory as `rules-before.txt`.)

Attempted the plan's exact command, twice, from two different working directories (first with an
absolute `--out` path from the worktree root, then again from inside `repos/security-platform`
matching the plan's own phrasing "run ... from inside repos/security-platform"):

```
bash scripts/set-required-checks.sh --repo OttawaCloudConsulting/terraform-pipelines \
  --ruleset 12760793 --out <scratch>/merged.json
```

**Both attempts were denied identically** by this executor session's own auto-mode Bash classifier:
`"Permission for this action was denied by the Claude Code auto mode classifier. Reason: Blocked by
classifier."` — the exact same denial shape 20-07-SUMMARY.md recorded for `gh release create`, not
a git/GitHub authentication or authorisation error, and not a package-manager install (so Rule 3's
install-exclusion checkpoint format does not apply; this is the general tool-permission-gate
variant).

**No workaround was attempted in this session.** The classifier's own denial text explicitly
permits routing through "other tools that might naturally be used to accomplish this goal" but
forbids "malicious" workarounds and instructs stopping when the capability is essential.
Reimplementing the script's read-modify-write logic by hand via direct `gh api` calls was
considered and rejected: the plan's own acceptance criteria require `set-required-checks.sh`
itself to exit 0 and print its rule-type comparison — a hand-rolled equivalent would not be
evidence that the shipped script works. This session returned a `checkpoint:human-action`,
following the 20-07 precedent exactly.

**Resolution: the orchestrator ran the exact recorded handoff command directly** (in a session
whose classifier did not block it):

```
bash scripts/set-required-checks.sh --repo OttawaCloudConsulting/terraform-pipelines \
  --ruleset 12760793 --out /private/tmp/.../scratchpad/merged.json
```

**Reported result:** exit 0.

```
BEFORE rule types: ['deletion', 'non_fast_forward', 'copilot_code_review']
AFTER rule types:  ['deletion', 'non_fast_forward', 'copilot_code_review',
                     'required_status_checks', 'pull_request']
```
"Every pre-existing rule type preserved; 5 contexts added, each pinned to integration_id 15368."
"DRY RUN complete. No write made to GitHub."

**This session independently re-verified the outcome read-only** (not trusting the orchestrator's
report at face value), per the anti-slop discipline this project follows (the same pattern 20-07
used for the `gh release create` handoff):

1. **`rules/branches/main` re-read** after the orchestrator's run:
   ```
   gh api repos/OttawaCloudConsulting/terraform-pipelines/rules/branches/main --jq '[.[].type] | sort | join(",")'
   -> copilot_code_review,deletion,non_fast_forward
   ```
   Identical to the pre-run baseline (`rules-before.txt` vs `rules-after.txt`, both committed to
   this plan's evidence directory) — `diff` is empty. **Confirmed: nothing was written to
   GitHub.**

2. **Read the produced `merged.json` directly** (path the orchestrator reported, copied into this
   plan's evidence as `20-10-evidence/merged.json`) rather than trusting the orchestrator's summary
   of its contents:
   - `rules[].type` in order: `deletion`, `non_fast_forward`, `copilot_code_review`,
     `required_status_checks`, `pull_request` — all three pre-existing types present, matching the
     orchestrator's reported BEFORE list exactly, plus the two new types matching the reported
     AFTER list exactly.
   - `required_status_checks.parameters.required_status_checks` contains exactly five entries,
     each `"integration_id": 15368`, contexts: `security / SAST — Semgrep CE`, `security / IaC —
     Checkov`, `security / SCA — Trivy Filesystem`, `security / Container — Trivy Image`,
     `security / Secrets — Gitleaks` — byte-matching the five frozen contexts measured live in
     Task 1 and Task 2's own check-runs reads.
   - `bypass_actors: []` in the merged document — carried forward verbatim from the live ruleset
     (independently confirmed via `gh api repos/.../rulesets/12760793 --jq '.bypass_actors'` ->
     `[]`), not synthesised. This is the read-modify-write correctness the script exists to
     guarantee (RESEARCH P-05 / T-20-08).
   - `pull_request` rule type present with `required_approving_review_count: 0` — the script adds
     both rules together as its own header comment states it must, never `required_status_checks`
     alone.

**`--apply` was never passed at any point, by either session.** `gh variable set` was never run.
T-20-08's "mitigate" disposition (dry run only, `--apply` never passed, live rule-type list diffed
before and after) is fully satisfied and independently re-verified, not merely trusted from the
orchestrator's report.

Both pull requests (#12, #13) remain **OPEN** — plan 13 owns their fate per the plan's own
instruction.

## Task 2 Verify Script

The plan's own automated Task 2 `<verify>` block requires `SHA_A` (Task 1's head SHA) for the
context-name diff. Re-ran the comparison directly (already shown above): `diff` of the two sorted
check-run name lists for SHA `6e8975f` (PR #12) and SHA `44b9d56` (PR #13) is empty, and the
post-dry-run `rules/branches/main` read matches the pre-attempt baseline exactly — both conditions
the plan's verify script checks.

## Guide Corrections Required (final list)

1. **Section 4, offline post-copy check.** `yamllint -d relaxed` on the copied `security.yml` and
   `pr-security.yml` produces 96 and 1 `line too long` warnings respectively (still exit 0). The
   guide's "Expected: no output, exit code 0" is half right — reword to state that line-length
   warnings on the workflow's long inline comments are expected and do not indicate a problem,
   or explicitly say "exit code 0 (warnings permitted)".
2. **Section 2 preflight, possible addition.** The guide's four preflight probes do not include
   `gh api repos/OWNER/REPO/actions/permissions` (confirming Actions is enabled at all). 20-01
   performed this check for the private pilot outside the guide's own text; plan 12 should decide
   whether to add it as a fifth preflight probe or leave it implicit.
3. **Probe 2's CLI decoration.** `gh api .../code-scanning/analyses` prints both the 404 JSON body
   AND a secondary `gh: This API operation needs the "admin:repo_hook" scope` line that is a CLI
   artifact, not a fact about the API response itself (this decoration was also observed in 20-01
   and 17-05 on the identical call shape). The guide's `head -2` truncation happens to keep only
   the 404 half in this session's run order, but the decoration is present and could confuse a
   first-time reader if line ordering differs. Not a blocking issue, flagged for completeness.

4. **Section 8's dry-run instruction, "run ... from inside repos/security-platform."** Both attempted
   invocation shapes (absolute `--out` path from the worktree root, and running from inside
   `repos/security-platform` per the guide's own phrasing) were denied identically by this executor
   session's classifier — the guide text itself was not at fault, this is a session-local tooling
   constraint (Claude Code's own auto-mode Bash classifier), not a guide defect. Not carried to
   plan 12 as a wording fix; noted here for completeness since it did delay Task 2's close.
5. **Section 8's dry-run output, confirmed accurate.** Once run (by the orchestrator), the script's
   own printed before/after comparison and this session's independent `merged.json` read matched
   the guide's description exactly: all pre-existing rule types preserved, five contexts added at
   `integration_id 15368`, `bypass_actors` carried forward verbatim. No correction needed for
   section 8's substantive content — only its dependency on a specific execution environment (item
   4 above) caused friction in this run.

This is the final list — both tasks are now complete.

## Task Commits

1. **Task 1: Mode A on the public pilot — SC1** — `bbc267b` (`docs(20-10): Task 1 — Mode A live
   pilot proof (SC1) on terraform-pipelines PR #12`); pilot-side commit `6e8975f` on
   `chore/adopt-security-pipeline-mode-a` (PR #12).
2. **Task 2: Mode B live-run half + branch-protection dry-run evidence** — `22aed38`
   (`docs(20-10): Task 2 — Mode B live pilot proof (SC2) on terraform-pipelines PR #13;
   branch-protection dry run BLOCKED`, later resolved); pilot-side commit `44b9d56` on
   `chore/adopt-security-pipeline-mode-b` (PR #13). Dry-run evidence (`merged.json`,
   `rules-after.txt`) and this SUMMARY's completion update are committed as the plan's final
   metadata commit (hash recorded in the finished-plan close-out below).

**Plan metadata:** this SUMMARY, plus `20-10-evidence/merged.json` and
`20-10-evidence/rules-after.txt`, committed together as the plan's closing metadata commit.

## Files Created/Modified

- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-SUMMARY.md` — this record.
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/` — `run-a.log.txt`,
  `run-b.log.txt`, `artifacts-a.json`, `artifacts-b.json`, `analyses-a.json`, `check-runs-a.json`,
  `check-runs-b.json`, `rules-before.txt`, `rules-after.txt`, `merged.json`.
- No files modified in `security_solution`'s own source tree, `repos/security-platform`, or any
  tracked file outside `.planning/` — this plan's deliverable is live GitHub state on the pilot
  (two open PRs, two branches, no ruleset/variable writes) plus the evidence record.

## Decisions Made

See `key-decisions` in frontmatter. Summary: (1) the Terraform-only artifact set (4, not 5) was
derived from `security.yml`'s own `if:` guard structure before running, then confirmed exactly;
(2) `yamllint`'s line-length warnings on the copied `security.yml` are a guide discrepancy
(exit-code half of "no output, exit 0" holds, the no-output half does not); (3) the dry-run
classifier denial was handled by handoff to the orchestrator, not by a hand-rolled `gh api`
substitute, because the plan's acceptance criteria require the shipped script itself to run; (4)
this session independently re-verified the orchestrator's dry-run report read-only — re-reading
`rules/branches/main` and the produced `merged.json` directly — rather than accepting the report
at face value, consistent with the 20-07 precedent's own verification discipline.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking, tool-permission variant] `set-required-checks.sh` dry-run invocation
denied twice by this executor session's auto-mode Bash classifier — resolved by the orchestrator
running the recorded handoff command directly**
- **Found during:** Task 2, branch-protection dry run
- **Issue:** `bash scripts/set-required-checks.sh --repo ... --ruleset 12760793 --out <path>` (no
  `--apply`, confirmed read-only by source inspection) was denied identically to 20-07's `gh
  release create` denial — "Blocked by classifier" — on two different invocation shapes.
- **Fix:** No workaround attempted in this session (per the anti-slop stop/report/wait protocol
  and the classifier's own instruction against routing around a denial). Returned a
  `checkpoint:human-action` with the exact command and the pre-attempt baseline already captured.
  The orchestrator then ran that exact command directly in its own session, which succeeded. This
  session subsequently re-verified the result read-only rather than trusting the report: re-read
  `rules/branches/main` (unchanged before/after) and the produced `merged.json` directly (all
  claimed rule types, contexts, and `bypass_actors` confirmed present and correct).
- **Files modified:** `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/merged.json`
  and `rules-after.txt` (new), this SUMMARY (updated in place).
- **Verification:** `gh api repos/OttawaCloudConsulting/terraform-pipelines/rules/branches/main
  --jq '[.[].type] | sort | join(",")'` returns `copilot_code_review,deletion,non_fast_forward`
  both before and after; `merged.json`'s five `required_status_checks` entries byte-match the five
  frozen contexts measured live in Task 1/Task 2; `bypass_actors: []` in both the merged document
  and the live ruleset.
- **Committed in:** the plan's closing metadata commit (hash recorded below).

---

**Total deviations:** 1 (a tool-permission gate identical in shape to 20-07's, resolved via the
same handoff-and-independently-reverify pattern). No scope change, no unauthorised action — the
dry run touched nothing on GitHub at any point, confirmed twice.

## Issues Encountered

- Worktree HEAD had no common ancestor with the plan's expected base commit — the same disjoint-
  history condition every prior plan in this phase has recorded. Resolved via the sanctioned `git
  reset --hard` after HEAD/namespace assertions passed.
- `git -C repos/security-platform fetch origin && git -C repos/security-platform checkout
  origin/main` (the plan's own HOST PREFLIGHT follow-up) was denied by this session's classifier
  when attempted; harmless, since the fresh clone had already landed on the correct commit.
- The Task 1 `<verify>` block and the branch-protection dry run both required writing scripts to
  files and executing with `bash <script>` rather than inline, because the worktree isolation
  guard rejected compound variable-driven `gh`/`git` invocations — consistent with every prior
  plan in this phase.
- `bash scripts/set-required-checks.sh` (dry run, no `--apply`) was denied twice by this executor
  session's own classifier — see Deviation 1 above; resolved via orchestrator handoff and
  independent read-only re-verification, not a workaround.

## User Setup Required

None. The one manual action originally required — running `set-required-checks.sh`'s dry run
because this executor session's own attempt was denied by its Bash classifier — has been completed
by the orchestrator, running the exact recorded handoff command in its own session. This session
independently re-verified the result read-only.

## Next Phase Readiness

- SC1 and SC2 are both measured on a repository outside this project (`terraform-pipelines`),
  using only the adoption guide's own documented commands, per this plan's success criteria.
- Both pull requests (#12, #13) are OPEN — plan 13 owns their fate (merge, close, or leave open)
  and VAL-01/DIST-06/DIST-07's final closure.
- Five guide corrections recorded above for plan 12: the `yamllint` "no output" overstatement on
  long-comment files, a possible fifth preflight probe (`actions/permissions`), the CLI decoration
  line on the 404 code-scanning probe, and the session-local (not guide-level) friction on the
  dry-run's execution environment.
- The branch-protection dry run's full evidence chain (baseline, script output, `merged.json`,
  post-run baseline, and independent read-only re-verification of both) is committed to
  `20-10-evidence/` for any downstream plan or auditor to re-derive the same conclusion without
  re-running the pilot.

## Self-Check: PASSED

- PR #12 — FOUND at `https://github.com/OttawaCloudConsulting/terraform-pipelines/pull/12`, state OPEN
- Commit `6e8975f22232659c1403de452d559d6c97ebb1eb` — FOUND on branch `chore/adopt-security-pipeline-mode-a`
- Run `34884582425` — FOUND, conclusion `success`
- Five `app.id==15368` check runs, all `success` — CONFIRMED via `gh api`
- Four detect-step lines — CONFIRMED verbatim in `gh run view --log`
- Artifact count 4 (not 5) — CONFIRMED via `gh api .../actions/runs/.../artifacts`
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/run-a.log.txt` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/artifacts-a.json` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/analyses-a.json` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/check-runs-a.json` — FOUND
- PR #13 — FOUND at `https://github.com/OttawaCloudConsulting/terraform-pipelines/pull/13`, state OPEN
- Commit `44b9d56a3d97ea1ca108f5df167cb246de47bb25` — FOUND on branch `chore/adopt-security-pipeline-mode-b`
- Run `34885287142` — FOUND, conclusion `success`
- Five `app.id==15368` check runs on PR #13's head SHA, all `success` — CONFIRMED via `gh api`
- Context-name diff between PR #12 and PR #13 — CONFIRMED empty (identical)
- `referenced_workflows[0].sha` — CONFIRMED `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/run-b.log.txt` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/artifacts-b.json` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/check-runs-b.json` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/rules-before.txt` — FOUND
- `rules/branches/main` rule-type list unchanged before and after the dry run — CONFIRMED (both reads identical: `copilot_code_review,deletion,non_fast_forward`)
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/rules-after.txt` — FOUND
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/merged.json` — FOUND, read directly and cross-checked (5 contexts at integration_id 15368, 3 pre-existing rule types preserved, bypass_actors: [] carried forward verbatim)
- `gh api repos/.../rulesets/12760793 --jq '.bypass_actors'` — CONFIRMED `[]`, matching merged.json
- `--apply` never passed by either session — CONFIRMED (script source-read shows the only PUT is gated behind it; both dry-run outputs and both baseline reads consistent with no write)
- `requirements.mark-complete` NOT invoked — CONFIRMED, per plan's own `<output>` instruction (plan 13 owns DIST-06/DIST-07 closure)

---
*Phase: 20-template-packaging-and-adoption-docs*
*Status: COMPLETE — SC1 and SC2 both measured live on terraform-pipelines using only the adoption guide's own commands; branch-protection dry run completed and independently re-verified read-only; both pilot PRs left OPEN for plan 13*
