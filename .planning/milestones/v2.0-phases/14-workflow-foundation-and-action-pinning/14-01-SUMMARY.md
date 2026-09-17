---
phase: 14-workflow-foundation-and-action-pinning
plan: 01
subsystem: infra
tags: [github-actions, workflow_call, reusable-workflows, dependabot, sha-pinning, actionlint, yamllint, supply-chain]

# Dependency graph
requires:
  - phase: 12-repo-setup-script
    provides: The `repos/security-platform` product-repo checkout and its root `.pre-commit-config.yaml` (yamllint `-d relaxed`, gitleaks pre-push)
provides:
  - Callable security-scan workflow at the product repo's root `.github/workflows/security.yml` (`on: workflow_call`, checkout-only placeholder job)
  - Thin `pull_request` caller `.github/workflows/pr-security.yml` invoking it by relative path (no `@ref`)
  - `.github/dependabot.yml` with a single weekly `github-actions` ecosystem entry (CICD-05)
  - A validated SHA-pin convention: full 40-char commit SHA + two spaces + same-line `# v<semver>` comment
  - A reusable local static gate: actionlint + `yamllint -d relaxed` + SHA-pin regex + canonical-tag dereference
affects: [15-scan-jobs, 16-sca-ecosystem-scans, 18-workflow-inputs, 19-validation, 20-cross-repo-publish]

# Tech tracking
tech-stack:
  added: [actionlint 1.7.12 (Homebrew, workstation-local tooling only — not committed)]
  patterns:
    - "Callable-first workflow authoring: scan logic lives in `on: workflow_call`; trigger policy lives in a separate thin caller"
    - "Third-party actions pinned to full commit SHA with same-line human-readable version comment (Dependabot-rewritable)"
    - "Static validation gate runs locally before anything reaches GitHub"

key-files:
  created:
    - repos/security-platform/.github/workflows/security.yml
    - repos/security-platform/.github/workflows/pr-security.yml
    - repos/security-platform/.github/dependabot.yml
  modified: []

key-decisions:
  - "Used the product repo's existing `yamllint -d relaxed` convention rather than adding a `.yamllint` file — VERIFIED that RESEARCH's suggested `truthy`+`document-start` inline override errors (exit 1) on the 81-character pin line"
  - "Pinned actions/checkout to v7.0.0 (9c091bb2…) deliberately, one patch behind v7.0.1, so Dependabot's first run produces an observable bump PR for ROADMAP criterion #4"
  - "`on:` uses map form (`workflow_call: {}`, `pull_request: {}`) so Phase 18 can add an `inputs:` block without a structural edit"
  - "Split the plan's single Task-3 commit into two accurate per-task commits (workflows, then dependabot.yml) per the executor's atomic-commit convention"

patterns-established:
  - "Pattern: relative reusable-workflow reference `uses: ./.github/workflows/security.yml` takes no `@ref` and resolves to the caller's own commit — a PR therefore exercises its own workflow changes"
  - "Pattern: every workflow declares a top-level `permissions: contents: read` block (least privilege, and Phase 15's Checkov job will scan these files)"
  - "Pattern: SHA-pin gate = list `uses:` lines, drop the relative `./` reference, assert the remainder match `@<40 hex>` + same-line `# v`"

requirements-completed: [CICD-05]

# Metrics
duration: 12min
completed: 2026-09-10
---

# Phase 14 Plan 01: Workflow Foundation and Action Pinning Summary

**The product repo's root `.github/` tree now exists: a callable `on: workflow_call` security workflow with `actions/checkout` pinned to the canonical v7.0.0 commit SHA, a `pull_request`-only caller invoking it by relative path, and a weekly `github-actions` Dependabot entry — all validated locally by actionlint, yamllint, a SHA-pin regex gate, and a GitHub-API tag dereference.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-09-10T19:14Z
- **Completed:** 2026-09-10T19:26Z
- **Tasks:** 3
- **Files created:** 3 (all in the product repo)

## Target Repository and Branch

All three deliverables live in the **product repository**, not the outer documentation repo:

- **Repo:** `OttawaCloudConsulting/security-platform`, checked out at `repos/security-platform/`
- **Branch:** `feature/phase-14-workflow-foundation` (pre-existing, cut from `origin/main`, 0 ahead / 0 behind at start)
- **Pushed:** No. Plan 02 owns pushing and PR creation. Zero git commands were run against the outer repo's remote.

## Accomplishments

- **Callable-first structure landed on day one.** `security.yml` declares `on: workflow_call: {}` and nothing else, so Phase 20's cross-repo publish (DIST-07) is a publish step rather than a restructure.
- **CICD-05 satisfied structurally.** `actions/checkout` is pinned to a full 40-character SHA with a same-line version comment, and `dependabot.yml` declares exactly one weekly `github-actions` ecosystem entry to keep that pin current.
- **Provenance of the pin proven, not assumed.** `gh api repos/actions/checkout/git/ref/tags/v7.0.0` returned `object.type = commit` (a lightweight tag, no dereference needed) with SHA `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0` — confirming the SHA came from the canonical `actions` org and not a fork.
- **Full static gate passes before anything reaches GitHub.** actionlint 1.7.12 exits 0 with no output on both files; `yamllint -d relaxed` exits 0.

## Task Commits

Commits are in the **product repo** (`git -C repos/security-platform log`):

1. **Task 1: Verify product-repo preconditions and install actionlint** — no commit (verification and tooling install only; zero files changed)
2. **Task 2: Author the callable workflow and the thin pull_request caller** — `f1588d5` (feat)
3. **Task 3: Author the Dependabot config, run the full static gate, and commit** — `b09d06a` (feat)

**Plan metadata:** `30cd414` (docs, outer documentation repo — SUMMARY + STATE + ROADMAP + REQUIREMENTS).
Note the outer repo sits on its own pre-existing branch `feature/phase-12-repo-setup-script`; no branch switching was performed there.

## Files Created

| File | What it does |
|------|--------------|
| `repos/security-platform/.github/workflows/security.yml` | Callable security-scan workflow. `on: workflow_call: {}`, top-level `permissions: contents: read`, one job `placeholder` (`runs-on: ubuntu-latest`) whose only step is the SHA-pinned checkout. No `run:` steps (D-01). |
| `repos/security-platform/.github/workflows/pr-security.yml` | Thin caller. `on: pull_request: {}` with no branch filter and no `push` (D-04), `permissions: contents: read`, one job `security` with `uses: ./.github/workflows/security.yml`. No `runs-on`, no `steps`, no `secrets:`, no `continue-on-error`. |
| `repos/security-platform/.github/dependabot.yml` | `version: 2` plus exactly one `updates:` entry — `package-ecosystem: "github-actions"`, `directory: "/"`, `schedule.interval: "weekly"`. No optional keys, no other ecosystems (D-03). |

## Exact Pin String

```yaml
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0  # v7.0.0
```

- SHA: `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0` (40 hex chars), **two spaces** before `#`, comment on the **same line** — Dependabot only rewrites the version comment when it is same-line.
- Comment granularity is `# v7.0.0`, not `# v7`: ROADMAP criterion #4 turns on a v7.0.0 → v7.0.1 bump being legible by eye, which `# v7` cannot express.
- Confirmed the file does **not** contain `3d3c42e5aac5ba805825da76410c181273ba90b1` (v7.0.1). Being one patch behind is deliberate.

## Decisions Made

### `yamllint -d relaxed`, no new `.yamllint` file (empirically verified)

The product repo's `.pre-commit-config.yaml` already runs the yamllint hook with `args: [-d, relaxed]`, which overrides any `.yamllint` file anyway. RESEARCH §Pitfall 5 proposed either committing a `.yamllint` or using an inline `truthy`+`document-start` override — both were derived from the *outer* repo, which has neither a yamllint config nor a pre-commit config.

**Verified empirically during execution**, not merely assumed:

| Gate | Result |
|------|--------|
| `yamllint -d relaxed repos/security-platform/.github/` | exit **0** — `line too long (81 > 80)` reported as a *warning* |
| `yamllint -d "{extends: default, rules: {truthy: disable, document-start: disable}}" …` | exit **1** — same line reported as an *error* |

The 81-character offender is the pinned checkout line itself, which cannot be shortened without breaking the pin convention. RESEARCH's inline override is therefore unusable here. No `.yamllint` was created in either repository, and `.pre-commit-config.yaml` was not modified.

### Dependabot ignores the local reusable-workflow reference — by design, not a defect

Dependabot's `github-actions` ecosystem does not propose updates for locally referenced reusable workflows. `uses: ./.github/workflows/security.yml` will therefore **never** appear in a Dependabot PR. `actions/checkout` is the only Dependabot-tracked dependency introduced by this phase. Recorded here so it is not later rediscovered and mistaken for a misconfiguration. A note to the same effect is in the `dependabot.yml` header comment.

### Map form for triggers

`workflow_call: {}` and `pull_request: {}` are written in map form rather than as bare scalars, so Phase 18 can add an `inputs:` block directly beneath `workflow_call:` without restructuring the file.

## Deviations from Plan

### 1. [Rule 1 - Bug] Plan's `check-ignore` gate was a silent false-pass

- **Found during:** Task 3 (static gate)
- **Issue:** The plan's verification used `! git -C $R check-ignore -q <three paths>`. Git rejects `--quiet` with more than one pathname: `fatal: --quiet is only valid with a single pathname`, exit code non-zero. The leading `!` therefore reports **PASS** on a command that never actually evaluated the `.gitignore` rules. The gate could not have detected an ignored file.
- **Fix:** Re-ran the check in two correct forms — `git check-ignore` on all three paths *without* `-q` (rc=1, empty output = no matches), and `check-ignore -q` per file individually.
- **Result:** All three files confirmed **not ignored**. The intended assertion holds; only the gate was broken.
- **Files modified:** none (verification-only defect; no source change required)
- **Verification:** `git -C repos/security-platform ls-files .github` lists exactly 3 files, which independently confirms nothing was swallowed.

### 2. [Rule 2 - Accuracy] Task 3's commit split into two per-task commits

- **Found during:** Task 3
- **Issue:** The plan supplied one combined message (`feat(14): add callable security workflow, PR caller, and Dependabot config`) while also permitting per-task commits in Task 2. Using the combined message on a commit containing only `dependabot.yml` would misdescribe the change.
- **Fix:** Two accurate atomic commits — `f1588d5` for the two workflow files, `b09d06a` for `dependabot.yml`. All of the plan's aggregate assertions still hold across the pair (`ls-files .github` = 3; every commit touches only `.github/`).
- **Files modified:** none

---

**Total deviations:** 2 (1 × Rule 1 broken verification gate, 1 × Rule 2 commit-message accuracy)
**Impact on plan:** No scope creep. Neither deviation changed a deliverable file; both corrected process defects in the plan's own verification and commit mechanics.

## Issues Encountered

None. Every Task 1 precondition passed on first evaluation:

| Precondition | Result |
|---|---|
| Working tree clean | `git status --porcelain` empty |
| Branch is a fresh Phase 14 branch | `feature/phase-14-workflow-foundation` (neither `main` nor `feature/phase-12-repo-setup-script`) |
| Descends from `origin/main` | `merge-base --is-ancestor` exit 0; `rev-list --left-right --count` = `0 0` |
| No root `.github/` tree | `ls-files .github` empty; path absent on disk |
| actionlint available | 1.7.12 installed from Homebrew (bottled formula — no registry package installs occurred anywhere in this plan) |

The manual precondition flagged at planning time (repo diverged on `feature/phase-12-repo-setup-script`, 1 ahead / 28 behind) had **already been resolved by the user** before execution. No `git checkout`, `git switch`, or `git branch` was run.

**Hook behaviour (verified, not assumed):** `.git/hooks/pre-commit` is installed (`core.hooksPath` unset); there is **no** `commit-msg` hook, so the required `Co-Authored-By` / `Claude-Session` trailers pass unchallenged. Gitleaks is registered at `stages: [pre-push]` and therefore did not run on these commits — it will fire in Plan 02 at push time. Both commits passed the pre-commit run (yamllint Passed; all other hooks skipped for lack of matching file types). `--no-verify` was **not** used.

## Threat Model Coverage

| Threat ID | Disposition | Evidence in this plan |
|-----------|-------------|------------------------|
| T-14-01 | mitigated | Full 40-char SHA pin; SHA-pin regex gate returns zero offending rows |
| T-14-02 | mitigated | `gh api repos/actions/checkout/git/ref/tags/v7.0.0` → `commit 9c091bb2…` from the canonical `actions` org |
| T-14-03 | mitigated | Top-level `permissions: contents: read` in both workflow files |
| T-14-04 | mitigated | `.github/dependabot.yml`, `github-actions`, weekly |
| T-14-05 / T-14-06 / T-14-07 | accepted | Platform-enforced / D-04 plain `pull_request` / no `run:` steps exist yet |
| T-14-17 | mitigated | Every git command scoped with `git -C repos/security-platform`; nothing pushed anywhere |
| T-14-18 | mitigated | `git diff --quiet origin/main -- cicd/ .pre-commit-config.yaml` exits 0; both commits touch only `.github/` |
| T-14-SC | mitigated | No npm/pip/cargo installs. Only tooling is `actionlint` from homebrew-core (bottle, not a registry artifact) |

## Known Stubs

The `placeholder` job in `security.yml` is an **intentional** stub per D-01: it runs `actions/checkout` and nothing else, with no `echo` no-op and no pre-named sast/iac/sca/container/secrets stub jobs. This phase proves the wiring only (PR opens → workflow runs → does not block merge). **Phase 15** replaces it with the five real parallel scan jobs. This is a documented plan decision, not an unfinished implementation.

## Verification Results

| Check | Result |
|---|---|
| `actionlint .github/workflows/*.yml` | exit 0, no output |
| `yamllint -d relaxed .github/` | exit 0 (one `line-length` warning on the pin line, expected) |
| SHA-pin gate (non-`./` `uses:` lines failing `@<40 hex>` + same-line `# v`) | empty result set |
| `v7.0.0` canonical tag resolution | `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0` ✓ |
| `git check-ignore` on all three files | no matches |
| `git ls-files .github` | exactly 3 files |
| `git status --porcelain` (product repo) | empty |
| `git diff --quiet origin/main -- cicd/ .pre-commit-config.yaml` | exit 0 |
| Files across `origin/main..HEAD` | only the 3 `.github/` paths |

## User Setup Required

None — no external service configuration required by this plan.

## Next Phase Readiness

**Ready.** ROADMAP criteria **#2** (callable workflow structure) and **#3** (all third-party actions SHA-pinned) now have complete static structural evidence.

Still owed, and explicitly out of this plan's scope:

- **Criterion #1** (opening a PR triggers a run that does not block merge) — requires the branch to be pushed and a PR opened. **Plan 02.**
- **Criterion #4** (Dependabot opens an observable `actions/checkout` v7.0.0 → v7.0.1 bump PR) — requires the config on the default branch and a Dependabot run. **Plan 03.** The one-patch-behind pin was chosen specifically to guarantee this evidence exists.

Carry-forward for the next executor: `feature/phase-14-workflow-foundation` in `repos/security-platform` is 2 commits ahead of `origin/main` and unpushed. Gitleaks runs at `pre-push` and has not yet been exercised against these files.

---
*Phase: 14-workflow-foundation-and-action-pinning*
*Completed: 2026-09-10*

## Self-Check: PASSED

All 3 product-repo deliverables and this SUMMARY exist on disk; both task commits (`f1588d5`, `b09d06a`) exist in `repos/security-platform` git history.
