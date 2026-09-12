---
phase: 19-pipeline-validation-via-branch-target-prs
plan: 01
subsystem: testing
tags: [semgrep, gitleaks, ruff, pre-commit, fixtures, sast, secrets]

# Dependency graph
requires:
  - phase: 15-five-parallel-scan-jobs
    provides: the `fixtures/` directory, the four `exclude: ^fixtures/` pre-commit entries, and the IaC/container/SCA fixtures already on main
  - phase: 17-sarif-upload-and-artifact-retention
    provides: the `semgrep-results` and `gitleaks-results` artifacts these fixtures will land in
  - phase: 18
    provides: origin/main at 2e29004, the merge base this plan branched from
provides:
  - fixtures/vulnerable.py — SAST seed firing 3 named Semgrep p/default rules
  - fixtures/secret.env — Secrets seed firing gitleaks aws-access-token plus 2 named Semgrep generic.secrets rules
  - dated pre-fixture Semgrep and Gitleaks baselines as enumerated (rule, path) pairs
  - the feature/phase-19-pipeline-validation branch, cut from origin/main, carrying exactly one commit
affects: [19-02, 19-03, 19-04, 19-05, 19-06, 19-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-fixture baseline recorded BEFORE authoring, so every later claim is a measured delta"
    - "Gate on the PINNED pre-commit hook, not the local binary, when the hook rewrites in place"

key-files:
  created:
    - repos/security-platform/fixtures/vulnerable.py
    - repos/security-platform/fixtures/secret.env
  modified: []

key-decisions:
  - "The Gitleaks pre-fixture baseline ALREADY carries 8 aws-access-token findings in .planning/ history — so an SC1 assertion on RuleID alone passes against the baseline and proves nothing; it MUST be scoped to File containing secret.env. This upgrades PATTERNS S-4 from a convention to a measured necessity."
  - "VAL-01 NOT marked complete — its text is 'full pipeline validated using branch-target PRs', which needs the live PR runs in 19-03+, not local seeding. Follows the 17-01 precedent where a premature mark-complete had to be reverted."
  - "secret.env's header spells BOTH generic.secrets.security.* rule ids out in full rather than RESEARCH's abbreviated second form, removing a grep ambiguity for plan 03; both spelled-out ids were then confirmed byte-identical to the measured check_ids."
  - "Tasks 1 and 2 carry no commit by plan design (Task 1 creates no files; Task 2 forbids git add) — the plan's own acceptance criterion requires exactly ONE commit above origin/main."

patterns-established:
  - "Deliberately-silent annotation carried from fixtures/main.tf to a Python fixture: os.system()/os.popen() kept for D-01 shape, annotated as measured-zero under p/default, and explicitly forbidden from being 'fixed'"
  - "Byte-identity proof over assertion: sha256 recorded before the commit and git show | diff after it, so a --fix hook rewrite is caught rather than assumed absent"

requirements-completed: []

# Metrics
duration: 18min
completed: 2026-09-12
---

# Phase 19 Plan 01: Seed SAST and Secrets Fixtures Summary

**Both missing scan fixtures authored and committed locally, each measured firing its intended NAMED rule against the exact CI-pinned tool version — Semgrep 3 → 8 findings and Gitleaks 9 → 11, both recorded as deltas against baselines captured before the fixtures existed.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-09-12T18:04Z
- **Completed:** 2026-09-12T18:22Z
- **Tasks:** 3 of 3
- **Files created:** 2 (both in the inner repo)

## Preflight (Task 1)

| Check | Result |
|---|---|
| `repos/security-platform` present? | Yes — no clone needed; `git fetch origin` ran clean |
| `git rev-parse origin/main` | `2e290042a775ff1c442bac75757ef8d0106d7dc3` |
| "2e29004 or later" test | `git merge-base --is-ancestor 2e29004… origin/main` → rc=0 (exactly equal) |
| Branch before | `feature/phase-17-sarif-upload-and-artifact-retention` (stale, as Pitfall 7 predicted) |
| Branch after | `feature/phase-19-pipeline-validation`, tracking `origin/main` |
| `git rev-parse HEAD` after checkout | `2e290042a775ff1c442bac75757ef8d0106d7dc3` |
| `git status --short` | empty, before and after checkout |
| pre-commit installed as a real git hook? | **Yes** — `.git/hooks/pre-commit` exists and is the pre-commit framework hook (ID `138fd403…`). The hooks genuinely fire at commit; the byte-identity check below is therefore a real test, not a vacuous one. |

### Semgrep version, as printed

```
$ "$SCRATCH/sgvenv/bin/semgrep" --version
1.155.0
$ "$SCRATCH/sgvenv/bin/pip" show semgrep | grep -i '^version'
Version: 1.177.0
```

RESEARCH assumption **A5 CONFIRMED**: the binary self-reports `1.155.0` while pip metadata reports the pinned
`1.177.0`. Recorded verbatim per the plan's instruction; **not** treated as a failure and **not** investigated.

### Pre-fixture Semgrep baseline — `origin/main` 2e29004, rc=1, exactly 3 results

| Rule | Path |
|---|---|
| `dockerfile.security.missing-user.missing-user` | `fixtures/Dockerfile` |
| `package_managers.dependabot.dependabot-missing-cooldown.dependabot-missing-cooldown` | `.github/dependabot.yml` |
| `yaml.github-actions.security.gha-curl-pipe-shell.gha-curl-pipe-shell` | `cicd/.github/workflows/security.yml` |

Zero entries on `fixtures/vulnerable.py` or `fixtures/secret.env` — the branch was clean. **No registry drift:**
this reproduces RESEARCH Pitfall 3's measurement exactly, three for three.

### Pre-fixture Gitleaks baseline — `gitleaks git .`, 140 commits, rc=1, 9 findings

| RuleID | File | StartLine |
|---|---|---|
| `aws-access-token` | `.planning/STATE.md` | 82 |
| `aws-access-token` | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 26 |
| `aws-access-token` | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 70 |
| `aws-access-token` | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 80 |
| `aws-access-token` | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 92 |
| `aws-access-token` | `.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` | 93 |
| `aws-access-token` | `.planning/phases/05-secrets-detection-gate/05-VERIFICATION.md` | 26 |
| `aws-access-token` | `.planning/phases/05-secrets-detection-gate/05-VERIFICATION.md` | 60 |
| `discord-api-token` | `.claude/gsd-file-manifest.json` | 114 |

Zero entries whose `File` contains `secret.env`.

> **Finding that changes how plan 03 must assert.** Eight of the nine baseline findings are **already**
> `aws-access-token`. An SC1 check of the form *"gitleaks-results.json contains a finding with
> `RuleID == 'aws-access-token'`"* therefore **passes against the untouched baseline and proves nothing** —
> exactly the false pass PATTERNS S-4 warns about for Semgrep, now measured to apply to Gitleaks as well.
> Every Secrets assertion in 19-03 onward must AND the rule id with `'secret.env' in File`. The plan's own
> verify command already does this; this note exists so nobody "simplifies" it later.

### `.gitleaksignore` — untouched, zero fingerprints

```
# .gitleaksignore ?M-^@M-^T Gitleaks false positive suppressions$
# Format: fingerprint from gitleaks JSON output$
# Generate: gitleaks detect --source . --report-format json$
```

Non-comment, non-blank line count: **0**, before and after. `git diff origin/main -- .gitleaksignore` is empty.

## Fixtures authored (Task 2)

Both bodies were taken **verbatim** from RESEARCH §Code Examples rather than re-derived — they were already
measured ruff-clean and detection-positive, and re-deriving would have reopened a closed question.

| Check | `fixtures/vulnerable.py` | `fixtures/secret.env` |
|---|---|---|
| Line 1 byte 0 | `#` (od: `# I N T E N T I O N A L L Y`) — no shebang, no leading blank | `#`, same |
| Em dash is U+2014 | yes — `od -b` on line 1 matches `342 200 224` | yes — same |
| Trailing bytes | exactly one `\n` (`] ) \n`) | single trailing newline |
| `head -1 … \| grep -c 'INTENTIONALLY VULNERABLE'` | **2** across both files | |
| Constructs | `eval(`=1, `shell=True`=1, `exec(`=2 lines, `os.system`, `os.popen`, each in its own function, plus `if __name__ == "__main__":` | `^AWS_ACCESS_KEY_ID=AKIA[A-Z0-9]{16}$` matches; separate `AWS_SECRET_ACCESS_KEY=` line |
| Imports all used | `os` 3 uses, `subprocess` 1, `sys` 1 — none droppable by ruff F401 `--fix` | n/a |
| `EXAMPLE` occurrences | n/a | **2, both inside the do-not-substitute warning comment** (lines 17–18); never in a key value |
| Silent-construct annotation | present — "os.system() and os.popen() … DELIBERATELY SILENT under p/default — measured, zero findings … kept for shape, not for signal" | the `AKIAIOSFODNN7EXAMPLE` trap documented as measured, not assumed |

`git status --short` after authoring showed exactly two untracked paths and no modified tracked files.

## Measurements and commit (Task 3)

### ruff — pinned hook and local binary agree

| Gate | Version | Result |
|---|---|---|
| `pre-commit run ruff --files fixtures/vulnerable.py` | **pinned v0.15.7** | `ruff (legacy alias) … Passed` (rc=0) — **Passed, not Skipped** |
| `pre-commit run ruff-format --files fixtures/vulnerable.py` | **pinned v0.15.7** | `ruff format … Passed` (rc=0) |
| `ruff check fixtures/vulnerable.py` | local 0.14.8 | `All checks passed!` (rc=0) |
| `ruff format --diff fixtures/vulnerable.py` | local 0.14.8 | `1 file already formatted` (rc=0) |

**No version-drift disagreement.** The v0.15.7 → 0.14.8 gap the plan flagged as a risk did not materialise; no
`# noqa` was added and no fifth `exclude: ^fixtures/` was added.

### Semgrep — 3 → 8, delta attributable entirely to the two new fixtures

Byte-exact CI invocation, rc=1, 8 results:

| Path | Rule | Delta |
|---|---|---|
| `fixtures/Dockerfile` | `dockerfile.security.missing-user.missing-user` | baseline |
| `.github/dependabot.yml` | `package_managers.dependabot.dependabot-missing-cooldown…` | baseline |
| `cicd/.github/workflows/security.yml` | `yaml.github-actions.security.gha-curl-pipe-shell…` | baseline |
| **`fixtures/vulnerable.py`** | **`python.lang.security.audit.eval-detected.eval-detected`** | **NEW** |
| **`fixtures/vulnerable.py`** | **`python.lang.security.audit.exec-detected.exec-detected`** | **NEW** |
| **`fixtures/vulnerable.py`** | **`python.lang.security.audit.subprocess-shell-true.subprocess-shell-true`** | **NEW** |
| **`fixtures/secret.env`** | **`generic.secrets.security.detected-aws-access-key-id-value.detected-aws-access-key-id-value`** | **NEW** |
| **`fixtures/secret.env`** | **`generic.secrets.security.detected-aws-secret-access-key.detected-aws-secret-access-key`** | **NEW** |

Hard assertion (`eval-detected` at `path == "fixtures/vulnerable.py"`): **rc=0, PASS.** Total 3 → 8 matches
RESEARCH's prediction exactly — 5 new, not 6, and `secret.env` contributes 2 of them as predicted.

### Gitleaks — 9 → 11, measured AFTER the commit (history scan)

141 commits scanned, rc=1, 11 findings. The two new ones:

| RuleID | File | StartLine | Nature |
|---|---|---|---|
| `aws-access-token` | `fixtures/secret.env` | 21 | **NAMED, deterministic** — this is the SC1 detection |
| `generic-api-key` | `fixtures/secret.env` | 22 | entropy-based, NOT version-stable |

Hard assertion (`RuleID == "aws-access-token"` AND `File` contains `secret.env`): **rc=0, PASS.** The 2/2 split
RESEARCH predicted is confirmed, and the `AKIAIOSFODNN7EXAMPLE` trap was avoided by construction.

### Commit and byte identity

| Check | Result |
|---|---|
| Commit | `fbfcbe9` — `test(19-01): seed SAST and Secrets fixtures for pipeline validation` |
| Hooks | ran normally, **no `--no-verify`** — `ruff` Passed, `ruff format` Passed, 8 others Skipped (no matching files), gitleaks did not fire (`stages: [pre-push]`, as predicted) |
| `git log origin/main..HEAD --oneline` | exactly **one** commit |
| `git diff origin/main --name-only` | exactly `fixtures/secret.env`, `fixtures/vulnerable.py` |
| `git show HEAD:… \| diff - …` (both files) | **no output — byte-identical.** `ruff --fix` did not rewrite either file |
| sha256 before vs after commit | `vulnerable.py` `805337994bdc…` unchanged; `secret.env` `5992aa37daa4…` unchanged |
| Pushed? | **No.** `git ls-remote --heads origin feature/phase-19-pipeline-validation` is empty |
| `.gitleaksignore` / `.pre-commit-config.yaml` | unchanged (`git diff origin/main` empty for both); 0 fingerprints, still exactly 4 `exclude: ^fixtures/` entries |
| `bash scripts/check-workflow-uploads.sh` | rc=0 — standing gate still passes, script not edited |

## Repo-local scripts need no change

Recorded explicitly so a later reader does not read the absence as an oversight:

- **`scripts/check-workflow-uploads.sh`** — ten static checks over the two workflow YAML files. Fixture files
  are invisible to it. Run here as a regression check (rc=0); **not edited**, per PATTERNS.
- **`scripts/smoke-scans.sh`** — needs no change for these fixtures. **Plan 19-02** adds the discretionary
  rule-id verdict to the smoke gate; its absence here is deliberate sequencing, not an omission.
- No workflow file, `.gitleaksignore`, `.pre-commit-config.yaml` or `fixtures/README.md` was touched by this
  plan. The `fixtures/README.md` rows for the two new fixtures are a later plan's deliverable.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `cat -A` is not available on this workstation**

- **Found during:** Task 1
- **Issue:** The plan's verify command `cat -A repos/security-platform/.gitleaksignore` failed with
  `cat: illegal option -- A`. macOS ships BSD `cat`, which has no `-A`.
- **Fix:** Substituted `cat -vet`, which produces the same visible output (`$` at end of line, `^I` for tabs).
  The raw file was dumped and the assertion checked against what is actually there, satisfying the acceptance
  criterion's intent.
- **Files modified:** none — this changed a verification command, not a deliverable.
- **Commit:** n/a

### Intentional divergences

**2. `secret.env` header spells both Semgrep rule ids out in full.** RESEARCH abbreviates the second as
`.detected-aws-secret-access-key`. The plan's acceptance criterion asks that the header "names the two
`generic.secrets.security.*` rules", and plan 03 will grep for them, so both were written out in full. The
spelled-out ids were subsequently confirmed byte-identical to the `check_id` values the measurement returned.

**3. Tasks 1 and 2 produced no commit.** By plan design: Task 1's acceptance criterion is *"No file inside
either repository was created or edited by this task"*, and Task 2 states *"Do not commit in this task and do
not run `git add`"*. Task 3's acceptance criterion requires *exactly one* commit above `origin/main`. Per-task
commits were therefore impossible without violating the plan's own verification. Same pattern as Phase 15-03.

### Authentication gates

None. No network authentication was required — no push, no `gh` call.

## Issues Encountered

None unresolved. Both hard-failure conditions the plan defined (a missing `eval-detected` on
`fixtures/vulnerable.py`; a missing `aws-access-token` on `secret.env`) were checked and neither occurred, so
the anti-slop STOP → REPORT → WAIT path was not entered.

Two results that could have been misread as failures, and were not:

- `semgrep … --error` exits **1** when findings exist. rc=1 is the success condition here, not a fault.
- `gitleaks git .` exits **1** on the pre-existing 9-finding history baseline. Also expected.

## Handoff Notes for Plan 19-02 and Later

1. **Nothing is pushed.** `feature/phase-19-pipeline-validation` exists locally only, at `fbfcbe9`, one commit
   above `origin/main` (`2e29004`). Plan 03 opens the PR.
2. **Scope every Secrets assertion to the file, not the rule.** Eight baseline `aws-access-token` findings
   already exist in `.planning/` history. `RuleID == 'aws-access-token'` alone is a guaranteed false pass.
3. **The `p/default` totals are dated measurements, not invariants** (Pitfall 8). 3 → 8 held exactly on
   2026-09-12; assert on rule id + path.
4. **VAL-01 remains Pending** and was deliberately not marked complete — see Key Decisions.
5. **`fixtures/README.md` has no rows for these two fixtures yet.** Pitfall 3 calls for a `secret.env` → SAST
   (Semgrep) row alongside its Secrets (Gitleaks) row. Owner: a later plan in this phase.
6. **Pre-commit hooks are genuinely installed** in the inner repo, so a future plan editing `vulnerable.py`
   must re-gate with `pre-commit run ruff` before committing — the `--fix` rewrite risk is live, not theoretical.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern or schema was introduced. The two threat-register
items requiring active mitigation were both discharged as written: **T-19-01** (synthetic credentials, never
real, stated as such in the fixture header) and **T-19-02** (zero fingerprints in `.gitleaksignore`, verified
before and after). **T-19-03** holds — nothing imports or executes `vulnerable.py`, and it was never run.
