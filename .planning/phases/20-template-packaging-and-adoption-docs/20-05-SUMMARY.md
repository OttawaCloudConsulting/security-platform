---
phase: 20-template-packaging-and-adoption-docs
plan: 05
subsystem: docs
tags: [cicd, adoption-docs, host-repo, template-deletion, dependabot, branch-protection]

# Dependency graph
requires:
  - phase: 20-04
    provides: "Canonical security.yml/pr-security.yml/dependabot.yml with adoption banners and gate_mode as the sole per-repo substitution point — the source of truth this plan's README corrections point at"
provides:
  - "The host repository (repos/security-platform) now contains exactly ONE deployable GitHub Actions security workflow — the pre-Phase-14 stale third copy under cicd/.github/workflows/security.yml is deleted, not merely annotated"
  - "cicd/README.md corrected to describe the shipped pipeline: Trivy filesystem/npm audit/pip-audit/tflint (not Grype), Dependabot (not Renovate), the ruleset-based branch-protection path with the five byte-exact security / ... contexts, and CICD-01 through CICD-06 marked Complete"
  - "repos/security-platform/README.md front page now names the root .github/ directory as the canonical workflow location and points at docs/adoption-guide.md as the procedure of record for both consumption modes"
  - "The report-only pipeline paragraph (previously only on an abandoned, closed-not-merged branch) now lands on the host repo's main-bound feature branch, re-authored against 19-06's measured facts"
affects: [20-06-merge-checkpoint, 20-08-adoption-guide, 20-09-adoption-guide]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Deletion with evidence, not assertion — a stale deployable template's specific measured defects (unpinned action version, --config auto, || true, missing permission, no gate_mode) are the deletion rationale, recorded in the commit body"
    - "Derive frozen strings from source, never retype — the five security / ... check-run contexts were extracted with grep from security.yml's job name: lines and byte-verified for the U+2014 em dash before being pasted into README prose"
    - "Chesterton's fence applied selectively — the GitHub member of cicd/ was deleted (superseded, deployable-and-dangerous); the Azure DevOps/GitLab members were kept and relabelled as unvalidated drafts (never built, never validated, no reason to delete draft work)"

key-files:
  created: []
  modified:
    - repos/security-platform/cicd/README.md
    - repos/security-platform/README.md
  deleted:
    - repos/security-platform/cicd/.github/workflows/security.yml
    - repos/security-platform/cicd/renovate.json

key-decisions:
  - "Confirmed origin/main's README.md lacks the report-only pipeline paragraph (git show origin/main:README.md byte-identical to the pre-edit working tree) — PR #12, which had added it, was CLOSED not merged (19-06-SUMMARY.md). Re-authored the paragraph fresh against 19-06's measured facts rather than cherry-picking the abandoned branch's commit, per the plan's explicit instruction."
  - "The five required-check contexts in cicd/README.md were derived via `grep -n \"^    name: \" security.yml` and piped through a script to build the table rows, then byte-verified in Python for the U+2014 em dash (\\xe2\\x80\\x94) before being committed — never retyped by hand, avoiding the exact mistake a hand-typed em dash or hyphen would introduce."
  - "One markdownlint MD038 violation (space inside a code span, \"`security / `\") was caught and fixed before commit by narrowing the span to \"`security /`\" — a trailing-space code-span issue, not a content change."

patterns-established:
  - "Byte-exact frozen strings extracted from source via grep + Python byte-dump, applied to Phase 20's remaining doc-writing plans (08/09) for the same five contexts"

requirements-completed: []  # Deliberately empty — DIST-06/DIST-08 are marked complete only by plan 12, per this plan's own <output> instruction and the 17-01/19-01 precedent it inherits.

# Metrics
duration: ~50min
completed: 2026-09-14
---

# Phase 20 Plan 05: Delete the Stale Third Template and Correct the Host READMEs Summary

**Deleted the pre-Phase-14 stale copy-paste security workflow and its Renovate config from `repos/security-platform/cicd/`, rewrote `cicd/README.md` to describe the pipeline that actually ships (Trivy filesystem/npm audit/pip-audit/tflint, Dependabot, ruleset-based branch protection with five byte-exact check contexts), and pointed the host repo's front-page README at the canonical workflow and the adoption guide.**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-09-14
- **Completed:** 2026-09-14
- **Tasks:** 2 of 2 completed
- **Files modified:** 2 (`cicd/README.md`, `README.md`); 2 deleted (`cicd/.github/workflows/security.yml`, `cicd/renovate.json`)

## Setup

`repos/security-platform` did not exist in this worktree. Cloned fresh per the plan's HOST PREFLIGHT
(`git clone https://github.com/OttawaCloudConsulting/security-platform.git`), checked out
`feature/phase-20-template-packaging` (present on the remote from plan 04's push, head `7413825`), and
confirmed plan 04's banner is present: `grep -c "gh variable set GATE_MODE" .github/workflows/pr-security.yml`
returned 2 (the plan required ≥1).

The worktree's own HEAD (base commit `71d29289284b46b7b8765687b87ea6e686292949`, "chore: merge executor
worktree (20-04)") was resolvable via `git merge-base` against the expected base with no reported issue —
no `git reset --hard` correction was needed for `security_solution` itself this time; the disjoint-history
issue prior plans (20-03, 20-04) hit only affects `repos/security-platform`'s state, which was resolved by
cloning fresh rather than by resetting.

## Task 1 — Delete the stale third template and correct `cicd/README.md`

Deleted with `git rm`:

- `cicd/.github/workflows/security.yml` (203 lines) — measured defects recorded as the deletion rationale:
  `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4` (canonical is `v7.0.1`), `pip install semgrep`
  unpinned (canonical pins `==1.177.0`), `--config auto` (a hard error with the canonical file's `--metrics=off`),
  `semgrep scan ... || true` (a banned silent fallback), only two permission grants (`contents: read`,
  `security-events: write`) versus the canonical file's three (`+ actions: read`), no `workflow_call`, no
  `gate_mode`, no verify steps reading `steps.<id>.outcome`, no `retention-days`, no SARIF `category:` key.
- `cicd/renovate.json` — pointed at a hosted Mend Marketplace app, contradicting CICD-05 (Dependabot) and
  PROJECT.md's zero-external-accounts constraint.

The Azure DevOps and GitLab members of `cicd/` were left in place per Chesterton's fence: they were never
built and never validated (unlike the deleted GitHub member, which was a superseded-but-deployable design
sketch), so this plan labels them as unvalidated drafts rather than deleting draft work the project may
still want.

Rewrote `cicd/README.md`:

- **Deployment → GitHub Actions**: replaced the `cp -r cicd/.github/` recipe with a pointer to the three
  canonical files at the repository root and to `docs/adoption-guide.md` in `security_solution` as the
  procedure of record. Kept the "Files deployed" table shape with the corrected three files.
- **What This Delivers**: the SCA row now states Trivy filesystem + npm audit + pip-audit + tflint (not
  Grype), with per-tool failure semantics: tflint signals findings with exit 2 (not exit 1), pip-audit
  emits no severity field so its gate is severity-agnostic (fails on ANY finding).
- **Requirements table**: CICD-01 through CICD-06 now read Complete (Phases 14-19); CICD-05 restated as
  Dependabot, not Renovate; CICD-06 (`gate_mode`) added as a new Complete row.
- **Renovate → Dependabot**: replaced the Mend/Renovate section content with a Dependabot description
  (`directory: "/"`, weekly, no external account).
- **Branch Protection**: GitHub's enforcement surface restated as the ruleset API (`/rulesets`,
  `rules/branches/main`), with the classic `branches/main/protection` 404 explicitly named as a false
  negative that must never be cited as evidence. The five required contexts are presented byte-exact
  (derived from source, see Deviations) rather than the old bare job-id list (`sast`/`iac`/`sca`/
  `container`/`secrets`).
- **Validation Checklist**: kept the shape, dropped the Renovate bullet, replaced "confirm scanner
  failures block the merge" with the D-07 report-only-then-blocking-then-require ordering.
- **Status note**: one line at the top noting the Azure DevOps and GitLab sections are unvalidated drafts;
  only GitHub Actions has been built and live-proven.
- **Contents table**: removed the two deleted-file rows.

**Verification:**

```
files gone: OK
cp -r cicd/.github/ (comments excluded): 0
Grype: 0
Renovate: 0
renovate.json: 0
adoption-guide: 1
.github/workflows/security.yml: 3 occurrences
sast.*iac.*sca.*container.*secrets: 0
| Planned | rows: 0
markdownlint-cli2 cicd/README.md: 0 errors (after the MD038 fix, see Deviations)
```

Byte-exact context verification (Python, comparing UTF-8 byte strings, not eyeballed):

```
b'security / SAST \xe2\x80\x94 Semgrep CE'        True
b'security / IaC \xe2\x80\x94 Checkov'            True
b'security / SCA \xe2\x80\x94 Trivy Filesystem'   True
b'security / Container \xe2\x80\x94 Trivy Image'  True
b'security / Secrets \xe2\x80\x94 Gitleaks'       True
```

`git ls-files cicd/` no longer lists either deleted path; `git log --diff-filter=D --name-only -1` on the
Task 1 commit (`916af8b`) shows both as deleted.

## Task 2 — Point the front page at the canonical workflow and the adoption guide

Compared the working tree's `README.md` against `git show origin/main:README.md` — **byte-identical**.
`origin/main` never carried the report-only pipeline paragraph: PR #12 (which added it, commit
`9483ba5265ed30bf58979b599eda3525e3afdd1e`) was **CLOSED, not merged** (confirmed from 19-06-SUMMARY.md's own
close-out table: `mergedAt: null`). Re-authored the paragraph fresh, against 19-06's measured facts (five
parallel scan jobs, report-only mode, findings published to the Security tab and retained as artifacts,
no merge block) — not cherry-picked from the abandoned branch, per the plan's explicit instruction.

Added to the Structure tree a `.github/` entry naming `workflows/security.yml` as the canonical callable
workflow, `workflows/pr-security.yml` as the local caller, and `dependabot.yml` — the tree previously listed
only `workstation/` and `cicd/`, reading as though the pipeline lived under `cicd/`.

Added one section stating this repository is the canonical host for the reusable security workflow, naming
both consumption modes (`uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1`,
or copying the three files) and pointing at `docs/adoption-guide.md` in `security_solution` as the
procedure of record. The `@v1` reference carries no trailing version comment, following the plan's explicit
instruction: `v1` is a moving tag and Dependabot maintains version comments on SHA pins, not tag refs. The
bare `raw.githubusercontent.com`-style URL risk (MD034) was avoided by using a full markdown link
(`[text](url)`) rather than a bare URL in prose.

Updated the Milestones table: `cicd/` M2 now reads "Complete (GitHub Actions)" with the Azure DevOps/GitLab
members named as unvalidated drafts in the description; the table structure itself was not restructured.

**Verification:**

```
adoption-guide: 1
OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1: 1
.github/: 3 occurrences
pr-security.yml: 2 occurrences
trailing version comment beside @v1: none found
| In progress | rows: 0
markdownlint-cli2 README.md: 0 errors
```

`git diff origin/main --name-only` on the final commit lists exactly the expected set: `.github/dependabot.yml`,
`.github/workflows/pr-security.yml`, `.github/workflows/security.yml` (all three carried forward from plan 04,
untouched by this plan), `README.md`, `cicd/.github/workflows/security.yml` (deletion), `cicd/README.md`,
`cicd/renovate.json` (deletion), `scripts/check-detector-parity.sh` (carried forward from plan 02/03,
untouched by this plan).

## Standing Gates Re-run

Neither task touched any file under `.github/`, so the plan's `<verification>` block requires re-confirming
the two standing offline gates still exit 0:

- `bash scripts/check-workflow-uploads.sh` — **PASS, 10 checks, 0 failures**
- `bash scripts/check-detector-parity.sh` — **PASSED 20 / FAILED 0**

Both confirmed unchanged from plan 04's close-out state.

## Task Commits

Both commits land in `repos/security-platform` on `feature/phase-20-template-packaging`, pushed after each
task per the plan's HOST PREFLIGHT instruction.

1. **Task 1: Delete the stale third template and correct `cicd/README.md`** — `916af8b` (feat, in
   `repos/security-platform`, pushed)
2. **Task 2: Point the front page at the canonical workflow and the adoption guide** — `c06d272` (docs, in
   `repos/security-platform`, pushed)

_Per this plan's explicit host-repo-only scope, both content commits are in `repos/security-platform`, not
this repository. This SUMMARY (and the final metadata commit) is the only commit in `security_solution`,
per the worktree parallel-execution protocol._

## Files Created/Modified/Deleted

- `repos/security-platform/cicd/.github/workflows/security.yml` — **DELETED** (Task 1, 203 lines removed)
- `repos/security-platform/cicd/renovate.json` — **DELETED** (Task 1, 15 lines removed)
- `repos/security-platform/cicd/README.md` — Task 1: rewritten GitHub-facing sections (Deployment, What
  This Delivers, Requirements, Branch Protection, Validation Checklist, Contents); Azure DevOps/GitLab
  sections relabelled as unvalidated drafts, otherwise unchanged.
- `repos/security-platform/README.md` — Task 2: +14/-2 lines (report-only paragraph, `.github/` structure
  entry, canonical-host section, Milestones table row correction).

## Decisions Made

See `key-decisions` in frontmatter. Summary: (1) confirmed via `git show origin/main:README.md` that the
report-only paragraph was never on `main` — PR #12 was closed, not merged — and re-authored it fresh
against 19-06's measured facts rather than cherry-picking the abandoned branch's commit; (2) derived the
five required-check contexts from `security.yml`'s own `name:` lines via grep, then byte-verified the em
dash in Python before pasting into `cicd/README.md` prose, rather than retyping them; (3) fixed one
markdownlint MD038 violation (space inside a code span) before commit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, markdownlint] Fixed a space-inside-code-span violation in `cicd/README.md`**
- **Found during:** Task 1, post-edit `markdownlint-cli2` run
- **Issue:** The sentence "The five required contexts (em dash U+2014, `security / ` prefix — copy exactly...)"
  used a code span with a trailing space (`` `security / ` ``), which `markdownlint` MD038 flags.
- **Fix:** Narrowed the code span to `` `security /` `` (no trailing space) and moved the space outside
  the span in the surrounding prose.
- **Files modified:** `repos/security-platform/cicd/README.md`
- **Verification:** `markdownlint-cli2 cicd/README.md` — 0 errors after the fix.
- **Committed in:** `916af8b` (Task 1 commit; the fix was made before the commit, not as a follow-up)

**Total deviations:** 1 (a self-caught lint fix before commit, same category as prior plans' self-caught
comment-wording fixes)
**Impact on plan:** No scope creep — only the two declared `files_modified` files were touched (plus the two
declared deletions), in `repos/security-platform`, and the fix is formatting-only.

## Issues Encountered

None unresolved. One worktree-tooling friction, consistent with prior plans in this phase: a compound
`git rm --cached -- . ; git reset` command (issued in error while re-running verification from the wrong
directory) was rejected by the worktree-isolation guard as "too complex to verify" before it could execute
— `git status --short` immediately after confirmed no unintended mutation had occurred (the two staged
deletions and the modified `cicd/README.md` were exactly as left by the prior `git rm`/edit steps). Resolved
by re-running the verification greps as separate, simple commands.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `repos/security-platform` is at `c06d272` on `feature/phase-20-template-packaging`, pushed to origin;
  plan 06's merge checkpoint should surface both deletions (`cicd/.github/workflows/security.yml`,
  `cicd/renovate.json`) explicitly for operator review before anything reaches `main`.
- The host repository now contains exactly one deployable GitHub Actions security workflow, and both
  READMEs beside it (`cicd/README.md`, front-page `README.md`) agree with it — satisfying this plan's
  `<success_criteria>`.
- Plans 08/09 (adoption guide authoring) can reuse this plan's derivation method for the five byte-exact
  `security / ...` contexts (grep the `name:` lines from `security.yml`, byte-verify the em dash in
  Python) rather than re-deriving it from scratch.
- `requirements.mark-complete` deliberately NOT invoked for DIST-06/DIST-08 — plan 12 owns that closure
  per this plan's own `<output>` instruction and the 17-01/19-01 precedent it carries forward.

## Self-Check: PASSED

- `.planning/phases/20-template-packaging-and-adoption-docs/20-05-SUMMARY.md` — FOUND (this file)
- Commit `916af8b` (Task 1, `repos/security-platform`) — FOUND in `git log --oneline` (repos/security-platform)
- Commit `c06d272` (Task 2, `repos/security-platform`) — FOUND in `git log --oneline` (repos/security-platform)
- `repos/security-platform` pushed to `origin/feature/phase-20-template-packaging` — confirmed via `git push`
  output for both tasks (`916af8b..c06d272` range shown on the second push)
- Both standing gates (`check-workflow-uploads.sh`, `check-detector-parity.sh`) confirmed exit 0 after both
  tasks
- `git ls-files cicd/` confirmed neither deleted path present; `cicd/README.md` and `README.md` confirmed
  present with 0 markdownlint errors each

---
*Phase: 20-template-packaging-and-adoption-docs*
*Completed: 2026-09-14*
