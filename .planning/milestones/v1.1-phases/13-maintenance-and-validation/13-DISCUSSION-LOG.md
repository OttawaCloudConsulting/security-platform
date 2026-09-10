# Phase 13: Maintenance and Validation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-09
**Phase:** 13-Maintenance and Validation
**Areas discussed:** Update failure handling

---

## Gray Areas Presented (not all selected)

| Area | Selected for discussion |
|---|---|
| Update semantics | No |
| Doctor vs check boundary | No |
| Exit code contract | No |
| Update failure handling | **Yes** |

---

## Update Failure Handling

### Round 1 — initial framing

| Question | Options presented | Selected |
|---|---|---|
| What happens to remaining tools on a single tool's update failure? | Continue, report at end (recommended) / Abort immediately / You decide | Free-text (see below) |
| Retry before marking failed? | No retry (recommended) / Retry once / You decide | You decide |
| Auto re-check after update? | Yes, auto re-check (recommended) / No, separate step | Yes, auto re-check |
| Exit non-zero on any update failure? | Yes (recommended) / No, always exit 0 | Yes |

**User's free-text answer to Q1:** "Assuming a semver for tooling, fail back to Major version, if second failure then skip. Log error and generate a failed manifest in the project root"

This introduced a specific fallback mechanism not covered by the original options — required follow-up before it could be captured cleanly.

### Round 2 — clarifying the free-text answer

| Question | Options presented | Selected |
|---|---|---|
| What does "fail back to major version" mean as a fallback target? | Latest release of prior major (API) / Hardcoded prior major in versions.conf / Strip pinned version to bare major | Strip pinned version to bare major |
| What counts as "second failure"? | Pinned version, then major fallback — 2 attempts total (recommended) / Something else | Pinned version, then major fallback — 2 attempts total |
| What should the "failed manifest" contain and where? | JSON file, per-tool detail / Plain text log / Something else | Plain text log |

**Notes:** "Strip pinned version to bare major" was selected, but before locking it in, verified against the actual `setup.sh` install functions:
- gitleaks/hadolint substitute `{VERSION}` literally into a GitHub release tag URL — no floating major tags exist (e.g. no `v8` release for gitleaks)
- `pipx install pre-commit==4` requires an exact PyPI release named `4` — doesn't exist
- trivy/syft/grype's upstream install scripts require exact release tags

This meant the literal "bare major" answer would fail for all 6 tools as specified. Surfaced this contradiction to the user rather than silently implementing or silently overriding.

### Round 3 — resolving the technical conflict

| Question | Options presented | Selected |
|---|---|---|
| Given bare-major doesn't resolve for any tool, how should the fallback actually work? | Latest patch within the pinned major (recommended, needs one API call on failure path) / Drop major-fallback entirely / Something else | Latest patch within the pinned major |

**Final decision (captured in CONTEXT.md as D-04):** Two-attempt sequence — (1) exact pinned version, (2) latest actual release matching the pinned major (via `resolve_latest_version`, on the failure path only) — then skip and log if attempt 2 also fails.

---

## Claude's Discretion

- Retry-before-marking-failed for transient network errors on a single attempt (D-05)
- Exact filename/internal structure of the plain-text failure log (D-07)
- `doctor` vs `check` boundary — not discussed this session, left open for research/planning
- `check`/`doctor` exit-code contract — not discussed this session, left open for research/planning
- Per-tool selective update vs. always-all — not discussed this session, left open for research/planning

## Deferred Ideas

None — no scope creep occurred during this discussion.

## Roadmap Correction Noted (not a discussion topic, a factual finding)

ROADMAP.md Phase 13 success criteria reference `bash dist/install.sh --check`. The actual script location is `repos/security-platform/workstation/setup.sh`, using subcommand style (`setup.sh check`) — not the `--flag` style the roadmap describes, and not the `dist/` path (relocated in commit `e045444`). Flagged for a follow-up `/gsd:phase edit 13` — not corrected during this discussion to keep it in scope.
