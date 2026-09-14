---
phase: 20-template-packaging-and-adoption-docs
plan: 03
subsystem: ci-testing
tags: [github-actions, git-ls-files, dockerfile-pathspec, workflow-portability, sca-detectors]

# Dependency graph
requires:
  - phase: 20-02
    provides: "scripts/check-detector-parity.sh (the standing gate this plan turns green) and the measured, corrected five-item Dockerfile pathspec (A4)"
  - phase: 16-sca-ecosystem-detectors
    provides: "scripts/detect-{npm,python,terraform}.sh — the byte-exact SKIP:/FOUND strings and pathspec rationale this plan carries into the inlined bodies"
provides:
  - "A portable canonical security.yml with zero references to scripts/detect-*.sh and zero references to fixtures/ (comment mentions of the historical fixture tree excluded), so it runs unchanged on a consumer repository in either consumption mode"
  - "A Dockerfile-conditional container job: a repository with no Dockerfile now produces a clean SKIP and job-green, instead of a hard docker-build failure"
  - "Corrected P-6a/P-6b comments — the three sentences claiming detection logic lives in shared scripts, and the one claiming the container build is unconditional, no longer contradict the code beneath them"
  - "scripts/check-detector-parity.sh observed green end-to-end (20/20) — the proof plan 02 built this gate to produce"
affects: [20-04-adoption-guide-authoring, 20-05, 20-12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Inline detection over script delegation for any file a consumer copies verbatim — a consumer has no scripts/ directory to shell out to"
    - "Detect-step id + compounded steps.<id>.outputs.found == 'true' guard on every downstream step (including always()-guarded ones), reusing the exact 18-02 always()-after-skip lesson for a fourth ecosystem (Docker)"
    - "scan-target as the consumer-facing image tag name; scan-fixture stays reserved for this repository's own fixtures/ tree and scripts/smoke-scans.sh"

key-files:
  created: []
  modified:
    - repos/security-platform/.github/workflows/security.yml

key-decisions:
  - "Reworded one inline comment (container job, 'Convert to SARIF' guard rationale) that would otherwise have contained the literal substring 'if-no-files-found: error', inflating that acceptance-criteria grep count from 4 to 5 against origin/main's baseline. Changed to 'the artifact upload's error-on-missing-file setting below' — same meaning, no literal-string collision. Same category of fix as 15-03's comment rewording to avoid the plan's own negative-grep checks."
  - "Added `|| true` after the bare `git ls-files -- ... > <file>.txt` redirect for py/tf/docker detect steps even though git ls-files cannot fail there (no pipe to fail under pipefail) — required uniformly by check-detector-parity.sh's SOURCE-<ECOSYSTEM> assertion (`pipe_ok = \"|| true\" in run`), and matches the docker detect step's shape in RESEARCH.md's own code example 2."
  - "Used the corrected five-item Dockerfile pathspec ('Dockerfile' '*/Dockerfile' 'Dockerfile.*' '*/Dockerfile.*' '*.dockerfile') measured in 20-02, not the naive three-item form written in RESEARCH.md's code example 2 prose — per the parallel_execution note and 20-02-SUMMARY.md's explicit finding that the naive form matches a docs/ decoy."

# Metrics
duration: 42min
completed: 2026-09-14
---

# Phase 20 Plan 03: Portability Pass on the Canonical Workflow Summary

**Inlined the npm/Python/Terraform ecosystem detectors and made the container job's Docker build conditional on a discovered Dockerfile — the canonical `security.yml` now runs on a consumer repository with neither `scripts/detect-*.sh` nor a `fixtures/` tree, proven by `check-detector-parity.sh` going from 18/19 (Task 1) to 20/20 (Task 2).**

## Performance

- **Duration:** 42 min (approx)
- **Started:** 2026-09-14T03:15:00Z (approx, first read)
- **Completed:** 2026-09-14T03:57:00Z
- **Tasks:** 2
- **Files modified:** 1 (`repos/security-platform/.github/workflows/security.yml`)

## Setup Deviation (before any task)

This worktree's branch (`worktree-agent-a749c8f3529335f27`) was created from the `main` lineage tip
`b4cb207`, one commit behind — no `.planning/` phase-20 files, no `repos/` clone. Unlike 20-02's setup
deviation (a genuinely disjoint history requiring `git merge-base` to return empty), this worktree's HEAD
(`b4cb207`) was confirmed to be an ANCESTOR of the plan's expected base (`450b7d7`, the 20-02 merge commit)
via `git rev-parse --is-ancestor HEAD 450b7d7... → YES`. `git merge-base HEAD 450b7d7...` itself returned
exit 1 with no output for reasons not fully diagnosed (possibly a sandbox artifact around the merge-base
subprocess), but the ancestry check gave unambiguous evidence the correction was a safe fast-forward with
zero risk of losing work. Corrected via the sanctioned `git reset --hard 450b7d7...`, verified via
`git rev-parse HEAD` matching the target SHA exactly. No uncommitted work existed at the old HEAD.

`repos/security-platform` did not exist in this worktree at all — cloned fresh per the plan's HOST
PREFLIGHT steps, then checked out `feature/phase-20-template-packaging` (confirmed present on the remote
from 20-02's push) and confirmed `scripts/check-detector-parity.sh` present before starting Task 1.

## Task 1 — Inline npm/py/tf detectors (P-1, P-2, P-3, P-6a)

Replaced the three `bash scripts/detect-<x>.sh <list-file>` run bodies (job `sca`, step ids `npm`/`py`/`tf`)
with inlined `git ls-files` blocks. Carried across byte-identical: the `SKIP:`/`FOUND` strings (confirmed via
`grep -o` diff against `scripts/detect-{npm,python,terraform}.sh`, all three match including the U+2014 em
dash), the pathspec rationale comments (the two-wrong-forms explanation for each ecosystem), the `|| true`
discovery-pipeline convention (npm's `grep -v` pipe genuinely needs it; py/tf/docker's bare `git ls-files`
redirect does not strictly need it, but the parity gate's SOURCE assertion requires it present for every
ecosystem — added uniformly), and the contract-name list files (`npm-lockfiles.txt`, `py-reqs.txt`,
`tf-files.txt`) that `security.yml:530`/`592`'s sub-scan loops read on fd 3.

Rewrote the three now-false sentences in the comment above the detect steps (P-6a): removed "the logic
lives in shared scripts, not inline here, so that CI and scripts/smoke-scans.sh exercise the same
implementation" and replaced it with the true statement that the logic is now inlined for consumer
portability, `scripts/detect-*.sh` remain `scripts/smoke-scans.sh`'s helpers, and
`scripts/check-detector-parity.sh` now proves the two agree. Kept the two still-true sentences (why
detection is its own step, why no `continue-on-error` on a detect step) and every provenance marker
(`# D-04`, `# ADR-001`, `# 17-03`, `# T-15-13`).

**Verification:** `actionlint` exit 0. `yamllint -d relaxed` exit 0 (pre-existing line-length warnings only,
none introduced by this task — all in the 80-char-limit style, unrelated to correctness).
`check-detector-parity.sh`: 18 PASS / 1 FAIL, exit 1 — the single failure is
`STEP-ID-EXTRACT: docker: step id 'docker' not found in job 'container'`, exactly the Task-2 precondition
the plan's own verify command expects (`grep -qi "docker" ... && ! grep -Eqi "FAIL.*(npm|python|terraform|py |tf )"`).
All npm/py/tf SOURCE, BEHAVIOUR-POSITIVE, BEHAVIOUR-NEGATIVE, PARITY, and NPM-EXCLUSION assertions passed —
confirmed byte-equal stdout between each inlined body and its corresponding `scripts/detect-*.sh` on
identical scratch trees. A4-PATHSPEC and A4-DIRNAME (independent of the YAML, testing the corrected
Dockerfile pathspec ahead of Task 2) also passed.

## Task 2 — Conditional container build (P-4, P-5, P-6b)

Inserted a `Detect Dockerfile` step (`id: docker`) immediately before the build step, using the corrected
five-item pathspec measured in 20-02 (`'Dockerfile' '*/Dockerfile' 'Dockerfile.*' '*/Dockerfile.*'
'*.dockerfile'`) — not the naive three-item form written in RESEARCH.md's own code example 2 prose, per the
20-02 finding and the parallel_execution note in this plan's invocation. Renamed the build step to
`Build image from discovered Dockerfile`, guarded it with `if: steps.docker.outputs.found == 'true'`,
derived the build context via `dirname` of the discovered path, and renamed the image tag from
`scan-fixture:${{ github.sha }}` to `scan-target:${{ github.sha }}` in both the build and Trivy-scan
invocations.

Compounded `steps.docker.outputs.found == 'true'` into every subsequent step in the container job: the
plain `if:` on `Run Trivy image scan`, and `if: always() && steps.docker.outputs.found == 'true'` on
`Convert to SARIF`, `Show scan output files`, `Upload Trivy image SARIF`, `Verify Trivy image SARIF upload
landed` (fork/Dependabot clause preserved), `Upload container reports`, and `Verify container artifact
upload landed` (fork/Dependabot clause preserved) — 8 occurrences total, matching the plan's own
acceptance-criteria count. Left `if-no-files-found: error` unchanged on the artifact upload; the guard is
what makes it correct on a clean skip.

Rewrote the two now-false sentences in the D-06 comment (P-6b): removed "No 'does a Dockerfile exist' check,
no conditional skip — a skipped job fails Success Criteria #2" and replaced it with the true statement that
Phase 15's unconditional build was correct for security-platform's permanent `fixtures/Dockerfile`, that a
consumer repository may have none, and that the detect step plus guards are what make a Dockerfile-free
repository skip cleanly. Kept the context-interpolation security note, extending it to name the one new
interpolation (`steps.docker.outputs.path`) and its trust basis (sourced from `git ls-files` on the checked-
out tree, not an event payload).

`grep -rn scan-fixture .github/` confirmed empty; `grep -rn scan-fixture scripts/` confirmed the two
unmodified `scripts/smoke-scans.sh` lines (`scan-fixture:smoke`), independent of this workflow's tag rename.

**Verification:** `actionlint` exit 0. `yamllint -d relaxed` exit 0. `check-detector-parity.sh`: **20 PASS /
0 FAIL, exit 0** — the docker STEP-ID-EXTRACT now passes and every ecosystem, including A4-PATHSPEC and
A4-DIRNAME, is green. `check-workflow-uploads.sh` exit 0.

### Deviation found during Task 2 verification

One inline comment (in "Convert to SARIF"'s guard-rationale block) initially contained the literal
substring `` `if-no-files-found: error` ``, which pushed the acceptance criterion's bare
`grep -c "if-no-files-found: error"` from the expected 4 (matching `origin/main`) to 5. Reworded to "the
artifact upload's error-on-missing-file setting below" — same meaning, no literal-string collision — and
re-verified the count returns to 4, with `if-no-files-found: warn` still exactly 1. Documented as a
Rule-1-adjacent fix on this plan's own acceptance criterion (analogous to 15-03's comment rewording to avoid
its own negative-grep check), not a scope change.

## Invariant Re-Assertion (both tasks, final state)

All measured directly against the committed file, not assumed:

| Invariant | Count | Expected |
|---|---|---|
| `bash scripts/detect-` (comments excluded) | 0 | 0 |
| `git ls-files` | 3 | ≥3 (npm/py/tf; docker's occurrence brings the real total higher, criterion only required ≥3) |
| `shell:` key (comments excluded) | 0 | 0 |
| `npm-lockfiles.txt` mentions | 4 | ≥2 |
| `py-reqs.txt` mentions | 4 | ≥2 |
| `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}` | 11 | 11 |
| `!= 'blocking'` | 0 | 0 |
| `GATE_MODE: ${{ inputs.gate_mode \|\| vars.GATE_MODE \|\| 'report-only' }}` | 1 | 1 |
| `fixtures/` (comments excluded) | 0 | 0 |
| `steps.docker.outputs.found == 'true'` (comments excluded) | 8 | 8 |
| bare `if: always()` inside the container job's line range (864-1050) | 0 | 0 |
| `if-no-files-found: error` | 4 | 4 (unchanged from `origin/main`) |
| `if-no-files-found: warn` | 1 | 1 |
| `scan-fixture` under `.github/` | 0 | 0 |
| `scan-fixture` under `scripts/` | 2 (unmodified `smoke-scans.sh` lines) | 2 |
| `Verify … SARIF upload landed` step names | 6 | 6 |
| `Verify … artifact upload landed` step names | 5 | 5 |
| Five frozen job `name:` values | byte-identical to `origin/main` | byte-identical |
| `uses:` directives (actual, excluding one comment mentioning the backtick-quoted word) | 10, all SHAs/versions unchanged | 10 unchanged |
| `git diff origin/main --stat` file list | `.github/workflows/security.yml`, `scripts/check-detector-parity.sh` | exactly these two |

Byte-exact `SKIP:` strings, confirmed via `grep -o` against the corresponding `scripts/detect-*.sh`:

- `SKIP: no package-lock.json found — npm sub-scan not applicable to this repository`
- `SKIP: no requirements*.txt found — Python sub-scan not applicable to this repository`
- `SKIP: no .tf files found — Terraform pinning sub-scan not applicable to this repository`
- `SKIP: no Dockerfile found — container sub-scan not applicable to this repository` (new, docker; no
  prior script to diff against — this string is now the sole source of truth, and the adoption guide (plan
  04) should quote it verbatim)

## Task Commits

Both commits land in `repos/security-platform` on `feature/phase-20-template-packaging`, pushed to the
remote after each task per the plan's HOST PREFLIGHT instruction.

1. **Task 1: Inline the three ecosystem detectors and correct the comment they falsify** — `3f6d343`
   (feat, in `repos/security-platform`, pushed)
2. **Task 2: Make the container job conditional on a discovered Dockerfile** — `42e204a`
   (feat, in `repos/security-platform`, pushed)

_Note: per this plan's explicit host-repo-only scope, both content commits are in
`repos/security-platform`, not this repository. This SUMMARY is the only commit in `security_solution`, per
the worktree parallel-execution protocol._

## Files Created/Modified

- `repos/security-platform/.github/workflows/security.yml` — Task 1: +81/-8 lines (inlined npm/py/tf
  detectors, corrected P-6a comment). Task 2: +64/-20 lines (Dockerfile detect step, guarded container job,
  corrected P-6b comment, `scan-fixture` → `scan-target` rename).

## Decisions Made

See `key-decisions` in frontmatter. Summary: (1) reworded one comment that collided with the plan's own
`if-no-files-found: error` literal-count acceptance criterion; (2) added `|| true` uniformly across all four
detect steps' discovery lines even where not strictly required, to satisfy `check-detector-parity.sh`'s
per-ecosystem SOURCE assertion; (3) used the 20-02-corrected five-item Dockerfile pathspec rather than
RESEARCH.md's own three-item prose example, per the explicit prior-finding note.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking, sanctioned by the worktree_branch_check step] Corrected worktree base**
- **Found during:** Pre-task setup, before Task 1
- **Issue:** This worktree's HEAD (`b4cb207`) was one commit behind the plan's expected base (`450b7d7`,
  the 20-02 merge). `git merge-base HEAD 450b7d7...` returned exit 1 with no stdout for undiagnosed reasons,
  but `git rev-parse --is-ancestor HEAD 450b7d7... → YES` confirmed the correction was a pure fast-forward.
- **Fix:** `git reset --hard 450b7d7...` per the worktree_branch_check step; verified via `git rev-parse
  HEAD` matching the target exactly.
- **Files modified:** None (branch-pointer correction only; no uncommitted work existed).
- **Committed in:** N/A (branch pointer move, not a content commit).

**2. [Rule 1 - Bug, self-inflicted acceptance-criterion collision] Reworded a comment colliding with the
plan's own `if-no-files-found: error` literal grep count**
- **Found during:** Task 2, post-edit verification
- **Issue:** A newly-written inline comment contained the literal substring `` `if-no-files-found: error` ``,
  inflating the bare `grep -c "if-no-files-found: error"` count from the expected 4 (matching
  `origin/main`) to 5.
- **Fix:** Reworded the comment to "the artifact upload's error-on-missing-file setting below" — preserves
  the explanatory content, removes the literal-string collision. Re-verified: count returns to 4; `warn`
  count stays 1.
- **Files modified:** `repos/security-platform/.github/workflows/security.yml`
- **Committed in:** `42e204a` (Task 2 commit; the fix was made before the commit, not as a follow-up)

---

**Total deviations:** 2 (1 sanctioned setup correction, 1 self-caught comment-wording fix before commit)
**Impact on plan:** Both deviations were necessary to keep the gate measurements honest and the worktree on
the correct base. No scope creep — only the plan's declared `files_modified` file was touched, in
`repos/security-platform`.

## Issues Encountered

- Several compound Bash commands (git commands with `-C`, multi-statement pipelines including `tee` +
  `PIPESTATUS`, and heredoc-quoted messages containing em dashes) were rejected by the worktree-isolation
  guard as "too complex to verify" — consistent with 20-02's prior finding. Resolved by splitting into
  single plain statements and by writing commit messages to scratch files, committing via `git commit -F`.
- `git merge-base HEAD <target>` returned exit 1 with no diagnostic output even though the two commits were
  confirmed to be in a simple ancestor relationship via `git rev-parse --is-ancestor`. Not investigated
  further since the ancestry check alone was sufficient evidence for a safe fast-forward reset; flagged here
  in case a future plan hits the same non-obvious `merge-base` behavior in this sandboxed environment.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 04 (adoption guide authoring) can now write `docs/adoption-guide.md` quoting the four `SKIP:` strings
  above verbatim (three carried from Phase 16's scripts, one new for the Docker detect step) and describing
  the multi-Dockerfile-scans-first-only behavior.
- `scripts/check-detector-parity.sh` is now green (20/20) and remains a standing regression gate for any
  future edit to these four detect steps or the container job's guard chain.
- `feature/phase-20-template-packaging` is at `42e204a` on `OttawaCloudConsulting/security-platform`; later
  plans in this phase should continue building on it directly.
- `requirements.mark-complete` deliberately NOT invoked for DIST-06/DIST-07 — plan 12 owns that closure per
  this plan's own output instruction.

---
*Phase: 20-template-packaging-and-adoption-docs*
*Completed: 2026-09-14*
