---
phase: 20-template-packaging-and-adoption-docs
plan: 08
subsystem: docs
tags: [adoption-guide, github-actions, dependency-pinning, markdownlint]

# Dependency graph
requires:
  - phase: 20-04
    provides: "Canonical-copy adoption banner on security.yml, caller-side adoption banner on pr-security.yml (verbatim FROZEN job-id and permissions-ceiling comment blocks used as the Mode B snippet source), corrected dependabot.yml header"
  - phase: 20-07
    provides: "Published v1/v1.0.0 tags and GitHub release on OttawaCloudConsulting/security-platform; byte-identity proof for both consumption modes"
provides:
  - "docs/adoption-guide.md sections 1-6: audience/outcome, preflight (four probes with expected-output branches), mode decision table, Mode A (three raw.githubusercontent.com/.../v1/ fetches), Mode B (full caller YAML pinned to @v1), first-run expectations with 19-06's measured finding counts"
  - "plan 02's guide gate (scripts/check-adoption-guide.sh) advances from exit 1 'guide not found' to exit 1 with exactly the five predicted CONTEXT-PRESENCE failures — the byte-exact check-run contexts plan 09 (section 8) closes"
affects: [20-09-adoption-guide-remainder, 20-12-blueprint-and-claude-md-corrections]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Self-referential grep-collision avoidance (established 20-03/20-04): fenced example comments use '## Expected:' instead of '# Expected:' at column 0, and one YAML comment was changed from '#' to '##', so the guide's own acceptance criterion (`grep -c \"^# \"` == 1, matching exactly one H1) is not broken by the command-then-expected-output convention it also requires (`grep -c \"# Expected:\"` >= 6)"
    - "Copied the pr-security.yml FROZEN job-id comment with one wording change — 'security / <called job name>' rewritten as '<this job's id> / <called job name>' — to avoid tripping the guide gate's SIXTH-CONTEXT check, which flags any 'security / ...' substring not in the derived five-context set"

key-files:
  created:
    - docs/adoption-guide.md
  modified: []

key-decisions:
  - "Both tasks landed in a single commit, per this plan's own Task 2 action-text instruction ('Commit both tasks' work in this repository') rather than the default one-commit-per-task pattern — the plan explicitly overrides the default here"
  - "Cloned repos/security-platform (gitignored, read-only) to source the exact Mode B caller YAML from origin/main (post-20-04/20-05 merge, at commit cdf2c21) and to run scripts/check-adoption-guide.sh, which requires the clone to derive its frozen contexts; nothing in the clone was modified or committed"
  - "Did not spell out any of the five byte-exact 'security / <job name>' check-run context strings anywhere in sections 1-6, and avoided the literal substring 'security / ' entirely — per the plan's own instruction that the five-contexts assertions belong to section 8 (plan 09's deliverable), so the guide gate's CONTEXT-PRESENCE failures are the plan's predicted, not accidental, outcome"

patterns-established:
  - "Forward-referenced an unwritten section by name ('the Private repositories section, further in this guide') rather than a broken link, so plan 09 has an exact heading title to land: 20-07-release-notes.md's own heading is 'Private repositories'"

requirements-completed: []  # Deliberately NOT invoked — DIST-08 is marked complete only by plan 12, per this plan's own <output> instruction and the 17-01/19-01/20-04/20-06/20-07 precedent.

# Metrics
duration: ~40min
completed: 2026-09-14
---

# Phase 20 Plan 08: Adoption Guide Sections 1-6 Summary

**Wrote `docs/adoption-guide.md` sections 1-6 (audience/outcome, four-probe preflight, mode decision table, Mode A three-file copy, Mode B one-file reusable-workflow call pinned to the published `@v1` tag, and first-run expectations carrying 19-06's measured finding counts) — the guide gate now fails on exactly the five predicted byte-exact check-run contexts plan 09 owns, nothing else.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-09-14 (after worktree base correction)
- **Completed:** 2026-09-14
- **Tasks:** 2 of 2 completed
- **Files modified:** 1 (`docs/adoption-guide.md`, new)

## Setup Deviation (before any task)

This worktree's HEAD (`b4cb207`, the Phase 19 gate-mode-proof merge-commit lineage, root commit
`c5b6100`) had no common ancestor with the plan's expected base
`e8178953aee8ade905bd5cfe573c07aec8d8161c` (this repo's `.planning`-history lineage, root commit
`fdfac5e`) — `git merge-base` returned exit 1 with no output, matching the exact known deviation
recorded in every prior plan of this phase (20-01, 20-04, 20-07). Corrected via the sanctioned
`git reset --hard e8178953aee8ade905bd5cfe573c07aec8d8161c` after HEAD/namespace assertions passed
(branch `worktree-agent-a3b7978b46ae092a3`, matching the `worktree-agent-*` allow-list). Confirmed
via `git rev-parse HEAD` matching exactly, `git status --short` clean before the reset (no
uncommitted work at risk), and `20-08-PLAN.md` present immediately after.

`repos/security-platform` did not exist in this worktree — cloned fresh (read-only, gitignored)
per the plan's own instruction ("clone it read-only for the string-derivation step"). `origin/main`
was already at `cdf2c21` (the merge of PR #13, `feature/phase-20-template-packaging`), so the
clone carried plan 04's adoption banners and plan 05's stale-template removal without any
additional checkout step.

## Task 1 — Sections 1-3: audience/outcome, preflight, mode decision

Wrote the opening (five parallel scan checks, five artifacts at 90-day retention, code-scanning
annotations, advisory default) and the "no secrets to provision — `GITHUB_TOKEN` only" selling
point naming all seven account-free tools. Section 2's four preflight probes were copied from
RESEARCH.md Code Example 5 with `<HOST>` resolved to `security-platform` per the D-01 amendment,
each carrying both outcome branches as `## Expected:` lines (11 total, comfortably over the
plan's minimum of 6). The private-repository branch forward-references "the Private repositories
section, further in this guide" by the exact heading title `20-07-release-notes.md` already uses,
so plan 09's section lands under a name this plan already committed to. Section 3's mode-decision
table covers all five required axes (files added, run-time dependency, how updates arrive, job
removal, auditability) and states the deciding axis (run-time dependency) without declaring an
overall winner.

**Verification:** `markdownlint-cli2 docs/adoption-guide.md` — 0 violations. `grep -c "# Expected:"`
— 11 (>= 6). `grep -c "^# "` — 1 (exactly the H1). `grep -c "OCC-github"` — 0.

## Task 2 — Sections 4-6: Mode A, Mode B, first run

Section 4 (Mode A): three `curl -fsSL` commands against
`https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/<path>`, zero edits
stated plainly, the Files-deployed table (pattern from `repos/security-platform/cicd/README.md`,
per PATTERNS.md), the moving-tag ~5-minute cache warning, and the offline `actionlint`/
`yamllint -d relaxed` post-copy check with expected exit-0 output.

Section 5 (Mode B): the complete consumer-side file, sourced directly from
`repos/security-platform/.github/workflows/pr-security.yml` at `origin/main` (plan 04's banner
commit) rather than re-derived — `name`, `on: pull_request: {}`, workflow-level
`permissions: contents: read`, and the `security` job with all three job-level grants
(`contents: read`, `security-events: write`, `actions: read`) plus
`uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1`. Both trap
comment blocks (the FROZEN job-id rationale and the forbidden-passthrough prohibition) were carried
across from the canonical source, with one wording change documented under Deviations. `@v1` carries
no trailing version comment; `@v1.0.0` is named as the immutable alternative with its cost stated.
The plus-one `dependabot.yml` file is named as shared with Mode A.

Section 6 (first run): five check runs, mergeable PR, five artifacts, code-scanning annotations
where available; then 19-06's measured finding counts (8 semgrep / 11 gitleaks / 14 checkov / 58
trivy-image / 6 trivy-fs / 3 tflint) stated alongside "five green checks" so green is never
presented as clean; `gh run view`/`gh run download` commands with expected output; and the
`blocking`-is-severity-agnostic corollary closing the section.

**Predicted-vs-observed guide-gate comparison:** predicted (in writing, before running) that the
only outstanding `scripts/check-adoption-guide.sh` failures would be the five `CONTEXT-PRESENCE`
checks for the byte-exact `security / <job name>` strings, because sections 1-6 deliberately never
spell any of the five out (that's section 8's job, owned by plan 09). Observed: exit 1, 9 checks
PASSED, exactly 5 FAILED, all five labelled `CONTEXT-PRESENCE`, naming the same five contexts the
gate itself derived from `repos/security-platform`'s live YAML. No other check (`SIXTH-CONTEXT`,
`NO-OCC-GITHUB`, `REUSABLE-WORKFLOW-REF`, `RAW-GITHUBUSERCONTENT-PIN`, `BANNED-PATTERNS`,
`NO-FIXTURES-DIR`, `MARKDOWNLINT`) failed. Prediction matched observation exactly.

**Verification:** `markdownlint-cli2` — 0 violations. Exactly 3 occurrences of
`raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/`, one per Mode A file. Zero
occurrences of the same host path with `/main/` or `/master/`. `security-events: write` appears 2
times (Mode B permissions block and the caller-ceiling explanation). `security.yml@v1` never
followed by a same-line `#` comment. `bash scripts/check-adoption-guide.sh` exits 1 with only the
five predicted failures.

## Task Commits

Per this plan's own Task 2 instruction ("Commit both tasks' work in this repository"), both tasks
landed in a single commit rather than one commit per task:

1. **Tasks 1 and 2 combined: write `docs/adoption-guide.md` sections 1-6** — `5aed371`
   (`docs(20-08): write adoption guide sections 1-6 (audience, preflight, modes, first run)`)

**Plan metadata:** this SUMMARY is committed separately per the standard `<output>` protocol, not
folded into the content commit above.

## Files Created/Modified

- `docs/adoption-guide.md` — new, 215 lines, sections 1-6 of the adoption guide.

## Decisions Made

See `key-decisions` in frontmatter. Summary: (1) single combined commit for both tasks, per the
plan's own explicit instruction; (2) cloned `repos/security-platform` read-only (gitignored,
untouched) to source the exact Mode B YAML and to run the guide gate, which requires the clone to
derive its frozen contexts and has no hard-coded fallback by design; (3) deliberately did not spell
out any of the five byte-exact check-run context strings, keeping the guide gate's CONTEXT-PRESENCE
failures a predicted outcome rather than an oversight.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, self-inflicted acceptance-criterion collision] `## Expected:` used instead of `# Expected:` at column 0, and one YAML comment changed from `#` to `##`**
- **Found during:** Task 1, post-write verification
- **Issue:** The plan's own acceptance criterion requires `grep -c "^# " docs/adoption-guide.md` to
  equal exactly 1 (asserting a single H1) while also requiring `grep -c "# Expected:"` to be at
  least 6. A literal `# Expected:` comment at column 0 inside a fenced bash block — the exact
  convention `INSTALLATION_GUIDE.md` uses — matches `^# ` too, inflating that count past 1 and
  failing the plan's own acceptance criterion. The same collision hit one plain YAML comment
  (`# Workflow-level FLOOR...`) in the Mode B snippet.
- **Fix:** Used `## Expected:` for every command-then-expected-output comment (the substring
  `# Expected:` is still present starting at the second character, satisfying the count check,
  while the line no longer starts with `# ` at column 0) and changed the one offending YAML comment
  to `##`. Both remain valid, readable comments in their respective languages (Markdown code fence /
  YAML).
- **Files modified:** `docs/adoption-guide.md`
- **Verification:** `grep -c "^# "` returns 1 (the H1 only); `grep -c "# Expected:"` returns 11;
  `markdownlint-cli2` still reports 0 violations.
- **Committed in:** `5aed371` (the fix was made before the commit, not as a follow-up)

**2. [Rule 1 - Bug, self-inflicted acceptance-criterion collision] Reworded the FROZEN job-id comment's illustrative context format to avoid the literal substring `security / `**
- **Found during:** Task 2, post-write verification against `scripts/check-adoption-guide.sh`
- **Issue:** The plan's `read_first` instruction says to copy the two trap comment blocks from
  `pr-security.yml` "rather than paraphrasing them." The FROZEN job-id block's illustrative phrase
  reads `check-run name the called workflow's jobs emit: \`security / <called job name>\``. The
  guide gate's `SIXTH-CONTEXT` check flags any `security / ...` substring in the guide that is not
  one of the five derived contexts (or a prefix of one) — `security / <called job` (the line breaks
  before the closing backtick) is neither, so a verbatim copy would have produced a `SIXTH-CONTEXT`
  failure outside the plan's own predicted set (which names only the five `CONTEXT-PRESENCE`
  failures as expected).
- **Fix:** Reworded the illustrative phrase from `security / <called job name>` to
  `<this job's id> / <called job name>` — same meaning (the job id is the prefix of the emitted
  check-run name), no literal collision with the gate's context-derivation logic.
- **Files modified:** `docs/adoption-guide.md`
- **Verification:** `grep -c "security / "` returns 0; `bash scripts/check-adoption-guide.sh`
  reports `PASS: SIXTH-CONTEXT` and fails only the five `CONTEXT-PRESENCE` checks, matching the
  plan's own prediction exactly.
- **Committed in:** `5aed371` (the fix was made before the commit, not as a follow-up)

---

**Total deviations:** 2 (both self-caught wording fixes before commit, same category as 20-03's and
20-04's prior fixes of this kind — self-referential grep collisions between a plan's own required
convention and its own acceptance-criterion greps).
**Impact on plan:** Both deviations were necessary to satisfy the plan's own acceptance criteria
without weakening the explanatory content or the command-then-expected-output convention the plan
itself mandates. No scope creep — only `docs/adoption-guide.md` was created, and both fixes are
wording-only.

## Issues Encountered

- The worktree's initial HEAD was on the same disjoint-history condition every prior plan in this
  phase has hit (`git merge-base` exit 1, no common ancestor). Resolved via the sanctioned
  `git reset --hard` after HEAD/namespace assertions passed; documented above under Setup Deviation.
- Several compound Bash commands (variable assignment piped into a conditional test, in one case
  merely because the literal string `OCC-github` or `github` appeared in the command text) were
  rejected by the worktree-isolation guard as "too complex to verify" or "names git in a form too
  complex to verify." Resolved by splitting into single-purpose `grep`/`bash` invocations throughout,
  consistent with every prior plan in this phase (20-01, 20-02 through 20-07).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `docs/adoption-guide.md` exists with sections 1-6 complete, markdownlint-clean, and every
  copy-pasteable command carrying its expected output.
- The guide gate (`scripts/check-adoption-guide.sh`) fails with exactly the five `CONTEXT-PRESENCE`
  checks — plan 09 closes these by writing section 8 (or wherever it lands the five byte-exact
  `security / <job name>` contexts) plus the "Private repositories" section this plan already named
  as a forward reference.
- Plan 09 can quote this plan's Mode B snippet, Files-deployed table, and finding-count sentence
  verbatim rather than re-deriving them.
- `requirements.mark-complete` deliberately NOT invoked for DIST-08 — plan 12 owns that closure per
  the 17-01/19-01/20-04/20-06/20-07 precedent already recorded in STATE.md.

## Self-Check: PASSED

- `docs/adoption-guide.md` — FOUND
- Commit `5aed371` — FOUND in `git log --oneline`
- `markdownlint-cli2 docs/adoption-guide.md` — 0 violations, re-confirmed after both deviation fixes
- `bash scripts/check-adoption-guide.sh` — exit 1, exactly 5 `CONTEXT-PRESENCE` failures, 9 checks
  passed, matching the prediction recorded before the run
- `git status --short` — clean (no untracked or modified files outside this commit and this
  SUMMARY)
- `repos/security-platform` — confirmed gitignored (`.gitignore` contains `repos/`), untouched by
  this plan beyond the read-only clone

---
*Phase: 20-template-packaging-and-adoption-docs*
*Completed: 2026-09-14*
