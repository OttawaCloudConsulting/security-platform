# Phase 13: Maintenance and Validation - Context

**Gathered:** 2026-09-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend `workstation/setup.sh` (in the `security-platform` repo) with an `update` subcommand (MAINT-02) and a `doctor` subcommand (MAINT-03). `check` (MAINT-01) already exists as `run_check` and needs no new subcommand — only possible hardening, deferred to research/planning since it wasn't discussed here.

</domain>

<decisions>
## Implementation Decisions

### Roadmap correction (not a discussion decision — a factual correction)
- **D-01:** ROADMAP.md Phase 13 success criteria reference `bash dist/install.sh --check` — this path is stale. The real target is `repos/security-platform/workstation/setup.sh`, using **subcommand style** (`setup.sh check`), matching the existing `install|configure|setup|check` dispatcher — not a `--flag` style. ROADMAP.md needs a follow-up edit (`/gsd:phase edit 13`) before or during planning to correct this; not done here to keep discuss-phase in scope.
- **D-02:** `check` (MAINT-01) already exists (`run_check`, lines ~798-840 of `workstation/setup.sh`) and substantially satisfies the requirement — prints a version table (tool/expected/installed/status) and a prerequisites table (git/curl/python3/node/npm/terraform). Phase 13's real net-new scope is `update` (MAINT-02) and `doctor` (MAINT-03).

### Update failure handling (the only area discussed in depth)
- **D-03:** On a tool update failure, **continue updating the remaining tools** rather than aborting the whole run. Collect per-tool results and report a summary at the end (reuse the existing `add_result`/`print_summary` pattern already used by `install_all_tools`).
- **D-04:** Two-attempt fallback sequence per tool:
  1. Attempt 1 — install the exact pinned version from `versions.conf`.
  2. If that fails, Attempt 2 — resolve the **latest actual release matching the pinned major version** (not a literal bare-major string — verified none of the 6 tools' install mechanisms accept a bare major tag/version: gitleaks/hadolint substitute `{VERSION}` into a literal GitHub release tag URL with no floating major tags; `pipx install pre-commit==4` requires an exact PyPI release named `4`, which doesn't exist; trivy/syft/grype's upstream install scripts require exact tags). Resolving "latest patch within major" requires one GitHub API call — only on the failure path, per failed tool, not on every run.
  3. If Attempt 2 also fails, skip the tool and log it — do not attempt a third time.
- **D-05:** Retry-before-marking-failed for a single attempt (network transient errors) — Claude's discretion. No blanket instruction; may vary by install method (e.g. retry direct binary downloads, not pipx installs) if it's implemented at all.
- **D-06:** After `update` completes (regardless of failures), automatically re-run the same version-check logic used by `check`/`doctor` so the user sees confirmed before/after state in one command. Reuse `run_check` directly rather than duplicating table-printing logic.
- **D-07:** Log failed-update tools to a **plain-text log file** (matches the existing `print_summary` plain-text style) at the project root of the repo `update` was run in (`REPO_ROOT`, i.e. wherever the git repo running `setup.sh` lives — not the security-platform script's own repo root). Exact filename/format left to planning (e.g. `update-failures.log`), but format is plain text, not JSON.
- **D-08:** `update` exits non-zero if any tool failed to reach its pinned version after both attempts (consistent with how `install`/`setup` already use `FAIL_COUNT` to set the exit code at the tail of the script).

### Claude's Discretion
- Retry-before-marking-failed for transient network errors during a single install attempt (D-05) — implement if it fits cleanly, no strong requirement either way.
- Exact filename and internal structure of the plain-text failure log (D-07).
- `doctor` vs `check` boundary — not discussed in this session (user only selected "Update failure handling" from the presented gray areas). Research/planning should treat `check` as the existing baseline and figure out whether `doctor` (PATH + can-execute verification per MAINT-03's exact wording) is a distinct subcommand or folds into `check`.
- `check`/`doctor` exit-code contract — not discussed. `run_check` currently always exits 0 regardless of MISMATCH/MISSING; whether to change that is left open for planning to decide, informed by the `update` exit-code precedent above (D-08).
- Whether `update` supports per-tool selective updates vs. always updating all six — not discussed; left to planning.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` (MAINT-01, MAINT-02, MAINT-03) — the three requirements this phase satisfies

### Prior phase context
- `.planning/phases/10-cross-platform-install-script/10-CONTEXT.md` — original --check/--update naming discussion (predates the subcommand-style implementation actually shipped); notes GitHub API rate-limiting concern and hadolint checksum gap
- `.planning/STATE.md` — Accumulated Context / Blockers section carries the GitHub API rate-limiting concern forward

### Implementation target (security-platform repo, sibling checkout at `repos/security-platform/`)
- `repos/security-platform/workstation/setup.sh` — the script to extend; contains `run_check` (existing, ~L798), `resolve_latest_version` (~L151, hits GitHub API), `get_installed_version`/`is_installed` (~L292-325), `_install_*` functions per tool (~L414-490), `install_all_tools` (~L495), `add_result`/`print_summary` (~L92-117), and the argument dispatcher at the tail of the file
- `repos/security-platform/versions.conf` — pinned tool versions this phase reads/updates against

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `add_result` / `print_summary` (setup.sh ~L92-117) — existing pass/fail accumulation and summary-table printing pattern; reuse for `update`'s end-of-run report rather than inventing a new format
- `run_check` (setup.sh ~L798) — version table + prerequisites table; reuse directly as the post-update auto-recheck (D-06) rather than duplicating
- `_install_*` functions (one per tool, ~L414-490) — already isolate the install mechanism per tool; `update` should call these same functions rather than reimplementing install logic
- `get_installed_version` / `is_installed` (~L292-325) — already used by `check`; reuse for verifying update success

### Established Patterns
- **Subcommand dispatch, not flags** — `install|configure|setup|check` via a `case "$arg"` loop at the tail of the script. Any new `update`/`doctor` commands should follow this same pattern for consistency.
- **Plain variables, not associative arrays** — bash 3.2 compatibility constraint established in Phase 12 (`declare -A` replaced with plain variables). Any new per-tool iteration logic in `update`/`doctor` must follow the same constraint.
- **`FAIL_COUNT` drives exit code** — set at the tail of the script (`if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi`). `update`'s exit-code decision (D-08) plugs into this existing mechanism.

### Integration Points
- `update` and `doctor` are new `case` branches in the same argument-parsing block that already handles `install|configure|setup|check` (setup.sh, tail of file)
- `resolve_latest_version` (setup.sh ~L151) is the existing GitHub API call point — the major-fallback logic (D-04) is a new caller of this function, scoped to only fire on the failure path

</code_context>

<specifics>
## Specific Ideas

No specific UI/output-format requirements beyond what's captured in decisions above (plain-text log, reuse of `run_check`'s table format for the post-update recheck).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The gray areas not selected for discussion (Doctor vs check boundary, Exit code contract for check/doctor specifically, Update semantics beyond failure handling) were presented but not chosen by the user — they remain open questions for research/planning to resolve, not deferred to a future phase.

</deferred>

---

*Phase: 13-Maintenance and Validation*
*Context gathered: 2026-09-09*
