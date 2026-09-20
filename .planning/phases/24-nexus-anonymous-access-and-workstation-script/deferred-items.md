# Phase 24 — Deferred Items

Out-of-scope discoveries logged during execution. Nothing here was fixed in this phase.

## From 24-09 (documentation repository, `security_solution`)

1. **`gsd-sdk query state.record-session` silently ignores positional arguments.**
   The executor workflow documents a positional form
   (`state.record-session "" "<stopped-at>" "<resume-file>"`). Run that way it returns
   `{"recorded": true, "updated": ["Last session", ...]}` and updates **only** the timestamp —
   `stopped_at` in the frontmatter and `Stopped at:` in §Session Continuity both keep the
   *previous* plan's text, so STATE.md reads as though the prior plan were the last one
   executed. The failure is silent: `recorded` is `true` either way. Only the flag form works:
   `--stopped-at "<text>" --resume-file "None"`, which reports
   `"updated": ["Last session", "Stopped At", "Resume File"]`. This extends Phase 23 deferred
   item 7 (which recorded the same positional-argument defect for `state.record-metric` and
   `state.add-decision`) to a third handler — and this one is worse, because `record-metric`
   and `add-decision` fail loudly with an `error` key while `record-session` reports success.
   Observed 2026-09-20 during 24-09's state updates; corrected in place by re-running with the
   flag form.

2. **`state.add-decision` writes a literal `[Phase ?]` prefix on every entry.**
   Every decision in STATE.md §Decisions added by this handler — including all of Phase 24's —
   reads `- [Phase ?]: …` rather than `- [Phase 24]: …`. The handler does not appear to derive
   the phase number from STATE.md's Current Position or from its own arguments. Harmless to
   read and consistent across the file, so it was **not** hand-corrected beyond normalising
   24-09's own two entries to match the surrounding `[Phase ?]: <plan>: <text>` shape. Whoever
   owns the SDK should decide whether the prefix is meant to be filled in or dropped.

3. **`state.update-progress` still no-ops against this STATE.md**, exactly as Phase 23 deferred
   item 6 recorded: `{"updated": false, "reason": "Progress field not found in STATE.md"}`.
   Harmless again — `state.advance-plan` recalculated `completed_plans` 16 → 17 correctly in
   the same run — but the item is unchanged and still open, now confirmed on a second phase.

4. **This documentation repository has no `.pre-commit-config.yaml`, so `pre-commit run` can
   never exit 0 here.**
   `24-09-PLAN.md` made `pre-commit run --files <paths>` a verification step and an acceptance
   criterion for both of its tasks. Measured: `pre-commit` is installed at
   `/Users/christian/.local/bin/pre-commit`, and running it in this repository exits non-zero
   with `An error has occurred: InvalidConfigError: .pre-commit-config.yaml is not a file`. The
   config lives in `repos/security-platform`, which documentation-repository plans do not
   touch. 24-09 substituted `bash scripts/check-adoption-guide.sh` and `markdownlint-cli2`,
   both of which exist here and both of which passed. **Any future plan whose `files_modified`
   are all in this repository should stop writing `pre-commit` into its verification blocks**;
   the standing gates here are `scripts/check-adoption-guide.sh`, `markdownlint-cli2` with the
   repository's own `.markdownlint-cli2.yaml`, and the active `.git/hooks/pre-commit`
   whitespace hook. Not fixed here because editing plan files mid-phase is out of an executor's
   scope.

5. **`CLAUDE.md` §Project Structure still says `docs/adr/` holds "ADR-001 through ADR-018".**
   Carried forward from Phase 23 deferred item 1, and now **three** records stale after
   ADR-021. A dated note was added under that item rather than editing `CLAUDE.md`, for the
   reason 23-07 gave and 24-09 repeats: it is the project's own instruction file and the
   correction is the operator's call. The durable fix is to replace the hard-coded range with
   the pointer to `docs/adr/README.md` that the same line already carries.
