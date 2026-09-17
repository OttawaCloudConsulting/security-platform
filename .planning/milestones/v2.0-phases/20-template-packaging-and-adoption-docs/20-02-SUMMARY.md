---
phase: 20-template-packaging-and-adoption-docs
plan: 02
subsystem: ci-testing
tags: [github-actions, pyyaml, bash, gitleaks-adjacent, workflow-parity, dockerfile-pathspec]

# Dependency graph
requires:
  - phase: 16-sca-ecosystem-detectors
    provides: scripts/detect-{npm,python,terraform}.sh, the shared detection logic this gate proves parity against
  - phase: 18-configurable-gate-mode-and-branch-protection
    provides: the five frozen 'security / <job name>' check-run contexts this gate derives rather than retypes
provides:
  - "A standing, offline, red gate (repos/security-platform/scripts/check-detector-parity.sh) proving parity between the four workflow detect steps and scripts/detect-*.sh, observed failing for the exact predicted reason before plan 03 inlines the bodies"
  - "A measured, corrected Dockerfile pathspec (A4) that matches root/nested/.dev/.dockerfile forms and excludes a docs/ decoy — the naive 3-item form in the plan prose does not"
  - "A standing, offline, red gate (scripts/check-adoption-guide.sh) proving the not-yet-written adoption guide will carry byte-exact frozen check-run contexts and pass a fixed set of anti-drift invariants"
  - "feature/phase-20-template-packaging pushed to OttawaCloudConsulting/security-platform so later plans in this phase can find it from a fresh clone"
affects: [20-03-inline-detect-steps, 20-04-adoption-guide-authoring, 20-05, 20-12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extract-by-job-and-step-id + execute-under-runner-default-shell (16-04 technique), reused for a second workflow-parity gate"
    - "Derive-not-retype for any frozen string sourced from committed YAML (T-20-12)"
    - "Record a dependent check as 'blocked: not yet inlined' rather than fabricating a pass when its precondition (an inlined body) does not yet exist"

key-files:
  created:
    - repos/security-platform/scripts/check-detector-parity.sh
    - scripts/check-adoption-guide.sh
  modified: []

key-decisions:
  - "Worktree setup deviation: this worktree's branch (worktree-agent-aaf703e0b0c354eba) was created from the main/security-platform lineage (tip b4cb207), a history with NO common ancestor with the expected phase base c9ad948 (feature/phase-12-repo-setup-script). Verified via git merge-base (empty result both directions) and disjoint root commits. Corrected via the sanctioned first-action 'git reset --hard <expected-base>' before any work began (clean working tree, zero uncommitted work at risk)."
  - "A4 Dockerfile pathspec: the plan prose's naive three-item pathspec ('*Dockerfile' '*Dockerfile.*' '*.dockerfile') was measured, in a scratch git repo, to match a docs/ decoy (docs/notes-Dockerfile.md) because git's default pathspec wildcards cross '/' (*='docs/notes-', 'Dockerfile.', *='md'). The gate instead asserts a corrected five-item pathspec ('Dockerfile' '*/Dockerfile' 'Dockerfile.*' '*/Dockerfile.*' '*.dockerfile'), measured to match exactly the four intended paths and exclude the decoy. Plan 03 must copy the corrected form, not the plan prose's form."
  - "SOURCE assertions for npm/py/tf are folded into one failure per ecosystem (git-ls-files-present + no-delegation + pipe-placement, combined) rather than three separate failures, to keep the observed failure count aligned with the plan's predicted shape (4 SOURCE-category failures total: npm, py, tf, docker)."
  - "check-adoption-guide.sh's BANNED-PATTERNS and NO-FIXTURES-DIR checks use structural heuristics (fenced-block + preceding-label detection for anti-pattern blocks; same-line-context detection for fixtures/ mentions) rather than a blanket grep, per the plan's 'count them with comment/prose lines excluded' instruction. These heuristics are conservative and should be re-verified once the guide text (plan 04) actually exists and exercises them."
  - "requirements.mark-complete deliberately NOT invoked (plan 12 owns DIST-06/DIST-08 closure), per plan's own output instruction."

# Metrics
duration: 55min
completed: 2026-09-14
---

# Phase 20 Plan 02: Wave 0 Detector-Parity and Adoption-Guide Gates Summary

**Two standing offline gates (one per repository) that measure — rather than assume — the phase's two riskiest invariants: workflow/script detector parity plus the Dockerfile pathspec (A4), and the adoption guide's five frozen check-run contexts; both observed red for the predicted reasons before their deliverables exist.**

## Performance

- **Duration:** 55 min
- **Started:** 2026-09-14T02:41:00Z (approx, first read)
- **Completed:** 2026-09-14T03:36:10Z
- **Tasks:** 2
- **Files modified:** 2 (one per repository)

## Observed origin/main SHA

`repos/security-platform` `origin/main` resolved to `b4cb20723a158638205a01bf83d51bca4489eafc` at clone time — matches the plan's expected `b4cb207` (the Phase 19 merge). The phase branch `feature/phase-20-template-packaging` was created from this SHA and pushed; no remote copy of the branch existed beforehand (`git ls-remote --heads origin feature/phase-20-template-packaging` returned nothing pre-push).

## Predicted vs. Observed Failure Shape — Task 1 (check-detector-parity.sh)

**Prediction (written before running, from source read of security.yml, detect-*.sh, check-workflow-uploads.sh, smoke-scans.sh):**

| Check | Expected |
|---|---|
| STEP-ID-EXTRACT npm/py/tf | PASS — `jobs.sca.steps[id=npm\|py\|tf]` all exist |
| STEP-ID-EXTRACT docker | FAIL — job `container` has no step with `id: docker` (D-06 unconditional build, no detect step) |
| NO-SHELL-KEY | PASS — zero `shell:` keys, zero `defaults:` blocks anywhere in security.yml (grepped) |
| SOURCE npm/py/tf | FAIL x3 — each body is literally `bash scripts/detect-<x>.sh <list-file>`, contains no `git ls-files`, and delegates |
| BEHAVIOUR-POSITIVE/NEGATIVE/PARITY npm/py/tf | FAIL x9, recorded as "not yet inlined" rather than fabricated passes |
| NPM-EXCLUSION | FAIL x1, "not yet inlined" |
| A4-PATHSPEC | PASS (0 failures) using the corrected five-item pathspec; naive plan-prose form informationally reported as measuring the decoy |
| A4-DIRNAME | PASS — dirname of a root Dockerfile path is `.` |
| **Total** | **14 failures, exit 1** |

**Observed (actual run, `bash scripts/check-detector-parity.sh` from `repos/security-platform`):** Exit 1. 5 PASS / 14 FAIL. Failures: `STEP-ID-EXTRACT: docker: step id 'docker' not found`, `SOURCE-NPM/PY/TF: still delegates...` (x3), `BEHAVIOUR-POSITIVE/NEGATIVE-{NPM,PY,TF}` and `PARITY-{NPM,PY,TF}` (x9, all "not yet inlined"), `NPM-EXCLUSION: not yet inlined` (x1). Zero A4 failures. **Exact match to prediction** — no discrepancy, no harness bug to fix.

Exit code 2 (PyYAML hidden via `PYTHONPATH` shadow module) verified separately: `PREFLIGHT FAIL: python3 yaml module (pyyaml) not available...`, exit 2.

## Measured A4 Path Set

In a scratch git repo containing `Dockerfile`, `svc/Dockerfile`, `Dockerfile.dev`, `app.dockerfile`, and decoy `docs/notes-Dockerfile.md`:

- **Naive pathspec** (plan prose, `'*Dockerfile' '*Dockerfile.*' '*.dockerfile'`): matches **5** paths — `Dockerfile`, `Dockerfile.dev`, `app.dockerfile`, `docs/notes-Dockerfile.md` (the decoy), `svc/Dockerfile`. Git's default pathspec wildcards cross `/`, so `'*Dockerfile.*'` matches `docs/notes-` + `Dockerfile.` + `md`.
- **Corrected pathspec** (`'Dockerfile' '*/Dockerfile' 'Dockerfile.*' '*/Dockerfile.*' '*.dockerfile'`): matches exactly the intended **4** paths, decoy excluded. `dirname` of the root `Dockerfile` path is `.`, confirming the build-context derivation plan 03 needs.

**This is the A4 finding plan 03 must consume**: use the five-item corrected pathspec when inlining the Docker detect step, not the three-item form sketched in this plan's own prose.

## Predicted vs. Observed Failure Shape — Task 2 (check-adoption-guide.sh)

**Prediction:** `docs/adoption-guide.md` does not exist yet → `GUIDE-EXISTS` fails first and only reported failure (context derivation succeeds and prints before the guide-existence check, per the plan's required ordering) → exit 1.

**Observed:** `DERIVE-CONTEXTS` passes, prints all five derived contexts with UTF-8 byte dumps (each ending `e2 80 94` before the job-name suffix — the U+2014 separator), then `GUIDE-EXISTS: docs/adoption-guide.md not found` fails, `PASSED 1 / FAILED 1`, exit 1. **Exact match to prediction.**

Exit code 2 verified separately by temporarily renaming `repos/security-platform/.github/workflows` to `.github/workflows-hidden` and restoring it afterward: `PREFLIGHT FAIL: repos/security-platform/.github/workflows absent — cannot derive the frozen check-run contexts. This is an infrastructure signal...`, exit 2, message distinguishes derivation-blocked from guide-wrong as required.

The five derived contexts, byte-dumped:

```
security / SAST — Semgrep CE
security / IaC — Checkov
security / SCA — Trivy Filesystem
security / Container — Trivy Image
security / Secrets — Gitleaks
```

Every one ends with bytes `e2 80 94` immediately before the job-name suffix, confirming U+2014.

## Accomplishments

- Both Wave 0 gates required by `20-VALIDATION.md` exist, are committed, and are observed red for stated reasons — neither fabricates a pass on an unmet precondition.
- RESEARCH assumption A4 is measured, not assumed, and the plan's own prose pathspec is shown to be subtly wrong (decoy match) — corrected form recorded for plan 03.
- The phase branch `feature/phase-20-template-packaging` exists on the canonical host's remote at commit `6cd5d07`, so plan 03+ can find it from a fresh clone.

## Task Commits

1. **Task 1: Author the detector-parity and Dockerfile-pathspec gate in the canonical host repo** — `6cd5d07` (feat, in `repos/security-platform`, pushed to `origin/feature/phase-20-template-packaging`)
2. **Task 2: Author the adoption-guide invariant gate in this repo** — `ce34ef1` (feat, in this repo)

_Note: both are Task-level commits in two different git repositories per the plan's explicit two-repos/two-commits constraint. No `.planning` commit precedes them; this SUMMARY is committed separately per the worktree parallel-execution protocol._

## Files Created/Modified

- `repos/security-platform/scripts/check-detector-parity.sh` (389 lines) — Wave 0 detector-parity and Dockerfile-pathspec gate, exit 0/1/2 contract, extracts step run bodies by job+id, executes under `bash -e`
- `scripts/check-adoption-guide.sh` (this repo, 271 lines after cleanup) — Wave 0 adoption-guide invariant gate, exit 0/1/2 contract, derives frozen contexts from the host clone's YAML rather than retyping them

## Decisions Made

See `key-decisions` in frontmatter. Summary: (1) corrected a bad worktree base via the sanctioned first-action reset, documented as a setup deviation, no work lost; (2) corrected the A4 pathspec from the plan prose's naive 3-item form to a measured-accurate 5-item form, keeping the gate's assertion honest rather than weakening it to fabricate a pass; (3) folded per-ecosystem SOURCE sub-checks into one failure each to match the plan's predicted failure count; (4) used structural (not blanket-grep) heuristics for two of check-adoption-guide.sh's assertions, flagged for re-verification once the guide text exists.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking, sanctioned by the worktree_branch_check step] Corrected worktree base**
- **Found during:** Pre-task setup, before Task 1
- **Issue:** This worktree's branch was created from the `main`/security-platform lineage (tip `b4cb207`), which shares no common ancestor with the plan's expected base commit `c9ad94848da423038e3c04c85bdd730a37894c38` (on `feature/phase-12-repo-setup-script`) — confirmed via `git merge-base` (empty in both directions) and disjoint root commits (`c5b6100 chore: initialize repository` vs `fdfac5e init`). The `.planning/` directory, including this plan's own PLAN.md, did not exist on the wrong base at all.
- **Fix:** Verified the working tree was clean (zero uncommitted work), then ran the `worktree_branch_check` step's sanctioned `git reset --hard c9ad94848da423038e3c04c85bdd730a37894c38`, confirmed via `git rev-parse HEAD`.
- **Files modified:** None (branch-pointer correction only, no working-tree edits).
- **Verification:** `git rev-parse HEAD` after reset equals the target SHA; `.planning/phases/20-template-packaging-and-adoption-docs/20-02-PLAN.md` then readable.
- **Committed in:** N/A (branch pointer move, not a content commit).

**2. [Rule 1 - Bug in the plan's own stated assumption] Corrected the A4 Dockerfile pathspec**
- **Found during:** Task 1, pre-implementation hand-measurement of A4 in a scratch repo (per advisor guidance, before writing the assertion)
- **Issue:** The plan's action text specifies asserting `git ls-files -- '*Dockerfile' '*Dockerfile.*' '*.dockerfile'` returns exactly the four expected paths and excludes a `docs/` decoy. Measured: it returns **five** paths — the decoy is included, because git's default pathspec wildcards cross `/`.
- **Fix:** Implemented the gate's A4-PATHSPEC assertion against a corrected five-item pathspec (`'Dockerfile' '*/Dockerfile' 'Dockerfile.*' '*/Dockerfile.*' '*.dockerfile'`), measured to yield exactly the four intended paths with the decoy excluded. The naive form is still measured and printed as an informational (non-failing) line in the gate's output, documented in the script's header comment and here, so plan 03 does not "restore" the plan prose's literal form.
- **Files modified:** `repos/security-platform/scripts/check-detector-parity.sh`
- **Verification:** Ran both pathspecs in a scratch git repo; corrected form measured `['Dockerfile', 'Dockerfile.dev', 'app.dockerfile', 'svc/Dockerfile']` (matches expected exactly), naive form measured the same set plus `docs/notes-Dockerfile.md`.
- **Committed in:** `6cd5d07` (Task 1 commit)

---

**Total deviations:** 2 (1 sanctioned setup correction, 1 Rule-1 bug fix on the plan's own stated assumption)
**Impact on plan:** Both deviations were necessary for the gate to measure reality rather than fabricate a pass or operate on the wrong repository history. No scope creep — no files outside the plan's declared `files_modified` were touched.

## Issues Encountered

- The sandbox's worktree-isolation guard rejected several compound Bash commands (multi-statement inline scripts, `git -C <subdir>`, `mv a; cmd; mv b` chains) as "too complex to verify." Resolved by splitting every such command into single, plain statements run from the worktree root — no functional impact, only extra round-trips.
- `git commit -m "$(cat <<'EOF' ... EOF)"` with an em dash (—) in the message body failed with a heredoc/eval quoting error in this shell. Resolved by writing the message to a scratch file and committing with `git commit -F <file>`.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 03 can inline the npm/py/tf/docker detect-step bodies into `security.yml` and re-run `bash repos/security-platform/scripts/check-detector-parity.sh`; the gate will automatically stop reporting "not yet inlined" and start running the real BEHAVIOUR/PARITY/NPM-EXCLUSION assertions once each body is inlined (the script's `inlined[name]` gate is computed from the live YAML, not hard-coded).
- Plan 03 must use the corrected five-item Dockerfile pathspec recorded above and in the gate's header comment, not the plan prose's three-item form.
- Plan 04 (adoption guide authoring) can write `docs/adoption-guide.md` against the exact byte-dumped contexts printed above; `bash scripts/check-adoption-guide.sh` will confirm context presence, em-dash correctness, and the other invariants automatically once the guide exists.
- Two structural heuristics in `check-adoption-guide.sh` (BANNED-PATTERNS' anti-pattern-block detection, NO-FIXTURES-DIR's same-line-context detection) have not yet been exercised against real guide prose — plan 04's author should watch the gate's output carefully on first real content and adjust the heuristics (not weaken the invariant) if either produces a false positive/negative.
- `feature/phase-20-template-packaging` is live on `OttawaCloudConsulting/security-platform` at `6cd5d07`; later plans in this phase should build on it directly rather than re-branching from `origin/main`.

---
*Phase: 20-template-packaging-and-adoption-docs*
*Completed: 2026-09-14*

## Self-Check: PASSED

All files and commits verified present:
- scripts/check-adoption-guide.sh (this repo, commit ce34ef1)
- repos/security-platform/scripts/check-detector-parity.sh (commit 6cd5d07, pushed to origin/feature/phase-20-template-packaging)
- .planning/phases/20-template-packaging-and-adoption-docs/20-02-SUMMARY.md (commit 9148910)
