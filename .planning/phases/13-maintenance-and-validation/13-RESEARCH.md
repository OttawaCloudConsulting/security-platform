# Phase 13: Maintenance and Validation - Research

**Researched:** 2026-09-09
**Domain:** POSIX/bash 3.2 CLI subcommand design, GitHub REST API version resolution, idempotent tool upgrade orchestration
**Confidence:** HIGH (all critical findings empirically verified against the live GitHub API and `/bin/bash` 3.2.57 on this machine)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Roadmap correction (not a discussion decision — a factual correction)**

- **D-01:** ROADMAP.md Phase 13 success criteria reference `bash dist/install.sh --check` — this path is stale. The real target is `repos/security-platform/workstation/setup.sh`, using **subcommand style** (`setup.sh check`), matching the existing `install|configure|setup|check` dispatcher — not a `--flag` style. ROADMAP.md needs a follow-up edit (`/gsd:phase edit 13`) before or during planning to correct this; not done here to keep discuss-phase in scope.
- **D-02:** `check` (MAINT-01) already exists (`run_check`, lines ~798-840 of `workstation/setup.sh`) and substantially satisfies the requirement — prints a version table (tool/expected/installed/status) and a prerequisites table (git/curl/python3/node/npm/terraform). Phase 13's real net-new scope is `update` (MAINT-02) and `doctor` (MAINT-03).

**Update failure handling (the only area discussed in depth)**

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

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. The gray areas not selected for discussion (Doctor vs check boundary, Exit code contract for check/doctor specifically, Update semantics beyond failure handling) were presented but not chosen by the user — they remain open questions for research/planning to resolve, not deferred to a future phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAINT-01 | Developer can run a check command to see installed vs expected versions for all tools | Already satisfied by `run_check` (setup.sh L798-841). Research identifies **three hardening items**: (a) whitespace-tolerant GitHub JSON parsing so `ensure_versions_conf`'s auto-generation path does not silently emit fallback versions (Pitfall 2); (b) an exit-code contract decision (Open Question 2); (c) `check` currently does NOT put `$INSTALL_DIR` on PATH, so it can report `MISSING` for installed tools (Pitfall 5) |
| MAINT-02 | Check command can update outdated tools to the pinned version | Core net-new work. Research provides: the verified `update` loop shape (Pattern 2), the **critical** finding that `pipx install` silently no-ops and exit code cannot be trusted (Pitfall 1), the verified GitHub "latest release within major" resolution pattern for D-04 attempt 2 (Pattern 3, Code Example 2), rate-limit mitigation via token passthrough (Pattern 4), and the plain-text failure log shape for D-07 (Code Example 4) |
| MAINT-03 | Health check verifies all tools are on PATH and can execute their version command | Research recommends a **distinct `doctor` subcommand** (State of the Art table — npm/brew/flutter convention: `doctor` = environment health, `check`/`outdated` = version currency). Concrete technical justification: `get_installed_version` (L310-326) swallows the version command's exit status with `|| true` and conflates "binary is broken" with "version output unparseable" as `(unknown)` — doctor needs a separate code path that captures that exit status (Pattern 5) |
</phase_requirements>

## Summary

This phase is pure bash maintenance on a single 894-line script. There is no new library, no new dependency, and no new package to install — the entire "stack" is bash 3.2 builtins, `curl`, and the GitHub REST API. The research value therefore is not "what to use" but **"what will silently break."** Three empirically-verified landmines dominate everything else in this document.

**First, and most important: `pipx install "pre-commit==X"` is a silent no-op when pre-commit is already installed, and it exits 0.** Verified on this machine (pipx 1.10.1): pipx matches by package *name*, not by the version spec, prints `'pre-commit' already seems to be installed. Not modifying existing installation`, and returns exit code 0. This means the *existing* `install` command cannot upgrade pre-commit today — `run_installer` sees exit 0 and records `installed` while the version on disk never changed. For `update` (MAINT-02) this is fatal: the D-04 attempt-1 → attempt-2 decision **cannot** be driven by the installer's exit code. Every attempt must be followed by an independent `is_installed "$tool" "$version"` verification.

**Second: GitHub returns compact (unspaced) JSON for some repositories' list endpoints.** The existing `resolve_latest_version` greps for `'"tag_name": "[^"]*"'` — with a literal space after the colon. Verified: `hadolint/hadolint/releases?per_page=100` returns `"tag_name":"v2.15.1"` with no space, consistently across repeated requests, while `gitleaks`, `trivy`, `syft`, `grype`, and `pre-commit` return the spaced form. The space-dependent pattern returns **empty** for hadolint, which means the existing `/tags` fallback in `resolve_latest_version` is already latently broken and the new D-04 major-fallback function would silently fail for hadolint specifically. Every JSON pattern in this script must become whitespace-tolerant (`[[:space:]]*:[[:space:]]*`).

**Third: `set -euo pipefail` + `curl | grep | head -1` is a script-killing SIGPIPE trap.** Verified under `/bin/bash` 3.2.57: a pipeline ending in `head -1` over a multi-megabyte body yields exit 141 and, under `set -e`, terminates the script. `resolve_latest_version` survives today *only* because every call site wraps it in `|| fallback`, which suspends `set -e` through the whole function body. Any new caller that assigns bare (`v=$(resolve_major ...)`) will kill the script on a network hiccup. The D-04 resolver must use a stream-consuming terminator (`sort | tail -1`) instead of `head -1`, and the `||`-context rule must be treated as a hard constraint.

**Primary recommendation:** Add `update` and `doctor` as two new `case` branches in the existing dispatcher. Structure `update` as a `for` loop over the same `tool:version` array shape `run_check` already uses, where each iteration is *attempt → verify with `is_installed` → on failure, resolve latest-within-major → attempt → verify → on failure, `add_result FAILED` + append to the plain-text log*, never trusting an installer's exit code. Add `pipx install --force` for the pre-commit path. Make `doctor` a distinct subcommand that tests the user's real PATH and captures each tool's `--version` exit status separately. Harden all four existing GitHub JSON grep patterns to be whitespace-tolerant, and pass `GITHUB_TOKEN`/`GH_TOKEN`/`gh auth token` through as an `Authorization: Bearer` header (verified: raises the limit from 60/hr to 5000/hr).

## Architectural Responsibility Map

This is a single-tier bash CLI, so "tier" maps to *function layer within `setup.sh`* rather than to network tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Subcommand routing (`update`, `doctor`) | Dispatcher (`for arg` + `case "$COMMAND"`, L848-888) | — | Every existing command enters here; consistency is the established pattern (CONTEXT.md "Established Patterns") |
| Per-tool update orchestration + fallback | New `update_all_tools` orchestrator | `run_installer`-style wrapper | Mirrors `install_all_tools` (L495); orchestrator owns the loop and the two-attempt policy, not the installers |
| Actual install mechanism | Existing `_install_*` functions (L414-493) | — | Already isolate per-tool mechanism; `update` must reuse, not reimplement (CONTEXT.md "Reusable Assets") |
| Success/failure determination | `is_installed` (L292-308) | — | **Not** the installer's exit code (see Pitfall 1). Verification is a distinct responsibility from execution |
| Version resolution from upstream | `resolve_latest_version` (L151) + new `resolve_latest_in_major` | GitHub REST API | Network I/O confined to two functions; everything else is offline |
| Result accumulation + summary | `add_result` / `print_summary` (L92-111) | `FAIL_COUNT` | Existing pattern, D-03 mandates reuse |
| Exit status | Tail-of-script `FAIL_COUNT` gate (L890-892) | — | Single exit point already exists; D-08 plugs into it rather than calling `exit` mid-command |
| Version currency reporting | `run_check` (L798) | — | MAINT-01; reused verbatim as D-06's post-update recheck |
| Executability / PATH diagnostics | New `run_doctor` | `command -v` + captured `--version` exit status | MAINT-03; distinct from version currency (see State of the Art) |
| Failure persistence | New log-append helper writing to `$REPO_ROOT` | — | D-07; must not leak the GitHub token into the log |

## Standard Stack

### Core

This phase adds **no new dependencies.** The stack is what `setup.sh` already uses.

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `bash` | 3.2.57 (compat target) | Script runtime | `/bin/bash` on macOS is 3.2.57 — verified on this machine. Phase 12 established this as the hard compat floor (STATE.md decision) [VERIFIED: `/bin/bash --version` on this machine] |
| `curl` | any | HTTP + GitHub API | Already a hard prerequisite (`check_prerequisites`, L131) [VERIFIED: codebase] |
| `grep` / `sed` / `sort` / `cut` | POSIX | JSON extraction without jq | Script already parses GitHub JSON this way (L156-166); no jq dependency is a deliberate zero-dependency constraint [VERIFIED: codebase] |
| GitHub REST API `/repos/{owner}/{repo}/releases` | `2022-11-28` | Latest-release-within-major resolution (D-04 attempt 2) | Same API family the script already calls [VERIFIED: live API probe, 2026-09-09] |
| `pipx` | 1.10.1 | pre-commit install mechanism | Already used by `_install_precommit` (L414) [VERIFIED: `pipx --version` on this machine] |

### Supporting

| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `shellcheck` | 0.11.x (via pre-commit hook `v0.11.0.1`) | Static analysis of the modified script | Wave 0 / every commit — already wired as a pre-commit hook with `types: [shell]` [VERIFIED: `repos/security-platform/.pre-commit-config.yaml` L35-39; `shellcheck` present at `/opt/homebrew/bin/shellcheck`] |
| `bats` | present on this machine | Optional bash unit testing | Only if planning decides to add a test harness — none exists today [VERIFIED: `command -v bats`] |
| `gh` CLI | present | Optional token source (`gh auth token`) | Rate-limit mitigation fallback, must degrade gracefully when absent [VERIFIED: `gh auth token` returned a working token; authenticated limit confirmed 5000] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| grep/sed JSON parsing | `jq` | Correct and far more robust (would trivially filter `"prerelease": false`), but adds a hard dependency the script deliberately avoids. **Do not add.** The whitespace-tolerant regex + semver-shape filter (Pattern 3) covers the actual need |
| `sort -t. -k1,1n -k2,2n -k3,3n` | `sort -V` | `sort -V` verified working on this machine's BSD sort and is available in GNU coreutils ≥7.0. But the explicit numeric-field form is POSIX-portable everywhere and was verified to produce identical ordering (`1.2.0 < 1.9.0 < 1.10.0`). **Prefer the field form** — zero portability risk for no cost |
| `GET /releases?per_page=100` | `GET /tags` | `/tags` bodies are ~14 KB vs. 0.5-5 MB for `/releases`, but tag ordering is not guaranteed semver and tags include non-release refs. `/releases` is newest-first and semantically correct. Accept the body size (see Pitfall 6) |
| Per-tool caching of resolved versions | Token passthrough | Caching adds cache-invalidation complexity and a state file for a call path that fires only on failure. Token passthrough is one header and buys an 83× limit increase. **Prefer token passthrough** |
| `local -n` nameref for generic per-tool version handling | Indirect expansion `${!varname}` | `local -n` is bash 4.3+. **Verified UNSUPPORTED under `/bin/bash` 3.2.57.** `${!varname}` verified working under 3.2 |

**Installation:** None. No packages are added by this phase.

## Package Legitimacy Audit

**This phase installs no external packages.** No npm/PyPI/crates dependency is introduced; the work is entirely edits to an existing bash script using tools already declared as prerequisites (`git`, `curl`, `python3`) or already installed by prior phases (`pipx`).

The Package Legitimacy Gate (slopcheck, registry verification, postinstall inspection) is therefore **not applicable** and was not run.

| Package | Registry | Disposition |
|---------|----------|-------------|
| *(none)* | — | Phase adds no packages |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

> Note: the *tools the script installs* (trivy, syft, grype, gitleaks, hadolint, pre-commit) were vetted in Phases 6-7 and 10 and are unchanged here. This phase changes how they are upgraded, not which ones exist.

## Architecture Patterns

### System Architecture Diagram

```
                        bash setup.sh <subcommand> [-v]
                                    │
                      ┌─────────────▼─────────────┐
                      │  for arg / case "$arg"    │   L848-855
                      │  install|configure|setup| │   ADD: update|doctor
                      │  check|update|doctor      │
                      └─────────────┬─────────────┘
                                    │
                            check_prerequisites      L857 (git/curl/python3)
                                    │
                      ┌─────────────▼─────────────┐
                      │  case "$COMMAND"          │   L859-888
                      └──┬──────────┬─────────┬───┘
                         │          │         │
          ┌──────────────┘          │         └──────────────┐
          │                         │                        │
     ╔════▼═════╗            ╔══════▼══════╗          ╔══════▼══════╗
     ║  check   ║            ║   update    ║  NEW     ║   doctor    ║  NEW
     ║ MAINT-01 ║            ║  MAINT-02   ║          ║  MAINT-03   ║
     ╚════╤═════╝            ╚══════╤══════╝          ╚══════╤══════╝
          │                         │                        │
   ensure_versions_conf      ensure_versions_conf     (NO versions.conf
   (may hit GitHub API       export PATH=$INSTALL_DIR  network read needed;
    6× if file absent)              │                  reads user's real PATH)
          │                         │                        │
          │              ┌──────────▼───────────┐            │
          │              │ for tool in tools[]  │            │
          │              └──────────┬───────────┘            │
          │                         │                        │
          │            ┌────────────▼────────────┐           │
          │            │ ATTEMPT 1: _install_X   │           │
          │            │   at pinned version     │           │
          │            └────────────┬────────────┘           │
          │                         │                        │
          │            ┌────────────▼────────────┐           │
          │            │ VERIFY: is_installed    │  ◄── NOT the installer
          │            │   tool pinned_version   │      exit code (Pitfall 1)
          │            └───┬─────────────────┬───┘           │
          │            ok  │                 │ fail          │
          │                │        ┌────────▼────────┐      │
          │                │        │ resolve_latest_ │      │
          │                │        │ in_major(repo,M)│──────┼──► GitHub REST
          │                │        │  1 API call     │      │    /releases
          │                │        └────────┬────────┘      │    ?per_page=100
          │                │                 │               │    + Bearer token
          │                │        ┌────────▼────────┐      │
          │                │        │ ATTEMPT 2:      │      │
          │                │        │ _install_X @ M.x│      │
          │                │        └────────┬────────┘      │
          │                │                 │               │
          │                │        ┌────────▼────────┐      │
          │                │        │ VERIFY again    │      │
          │                │        └───┬─────────┬───┘      │
          │                │       ok   │         │ fail     │
          │                │            │         │          │
          │                ▼            ▼         ▼          │
          │           add_result   add_result  add_result    │
          │             "ok"      "fallback"   "FAILED"      │
          │                                    FAIL_COUNT++  │
          │                                    append log ───┼──► $REPO_ROOT/
          │                         │                        │    update-failures.log
          │              ┌──────────▼───────────┐            │
          │              │   print_summary      │            │
          │              └──────────┬───────────┘            │
          │                         │                        │
          │              ┌──────────▼───────────┐            │
          └─────────────►│      run_check       │◄── D-06 auto-recheck
                         │  (version table +    │
                         │   prereq table)      │
                         └──────────┬───────────┘            │
                                    │                        │
                                    │              ┌─────────▼──────────┐
                                    │              │ per tool:          │
                                    │              │  command -v ?      │
                                    │              │  $tool --version   │
                                    │              │   → capture $?     │
                                    │              │  PATH contains     │
                                    │              │   $INSTALL_DIR ?   │
                                    │              └─────────┬──────────┘
                                    │                        │
                      ┌─────────────▼────────────────────────▼─────────────┐
                      │   tail: if FAIL_COUNT > 0 → exit 1, else exit 0    │  L890-894
                      └────────────────────────────────────────────────────┘
```

### Recommended Structure (function placement inside `setup.sh`)

```
setup.sh
├── Constants                      L20-49    ADD: GITHUB_TOKEN resolution, UPDATE_LOG name
├── Helpers (log/info/err/warn)    L51-111   unchanged
│   └── add_result/print_summary             reuse for update (D-03)
├── Prerequisites                  L113-145  unchanged
├── Version resolution             L147-175  HARDEN resolve_latest_version patterns
│   └── resolve_latest_in_major()            ADD — D-04 attempt 2
│   └── gh_api_get()                         ADD — shared curl + auth header wrapper
├── versions.conf mgmt             L177-236  unchanged
├── OS/Arch detection              L238-286  unchanged
├── Version checking               L288-348  ADD tool_is_executable() for doctor
├── pipx bootstrap                 L350-377  unchanged
├── Tool installers                L379-513  FIX _install_precommit → pipx install --force
│   └── attempt_install()                    ADD — install + verify, returns 0/1
│   └── update_all_tools()                   ADD — the D-03/D-04 loop
├── Config generation              L515-766  unchanged
├── Hook activation                L768-792  unchanged
├── Check command                  L794-841  MAY change exit contract (Open Q 2)
│   └── run_doctor()                         ADD — MAINT-03
└── Main dispatch                  L843-894  ADD update|doctor cases + usage() text
```

### Pattern 1: Subcommand registration (established, follow exactly)

**What:** New commands are added to two places — the `for arg` case list and the `case "$COMMAND"` block — plus the `usage()` heredoc.
**When to use:** For both `update` and `doctor`.

```bash
# L850 — add to the recognised-argument case
    install|configure|setup|check|update|doctor) COMMAND="$arg" ;;

# L859-888 — add branches
  update)
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"   # matches `check`, L873
    ensure_versions_conf "$REPO_ROOT"
    update_all_tools                    # exports PATH like install_all_tools does
    print_summary
    run_check                           # D-06 auto-recheck
    ;;
  doctor)
    # NOTE: deliberately does NOT call ensure_versions_conf. Doctor needs tool
    # NAMES, not versions — and ensure_versions_conf fires 6 GitHub API calls
    # when versions.conf is absent, inside the one subcommand that must stay
    # fully offline. Hardcode the six tool names in run_doctor.
    run_doctor                          # deliberately does NOT export PATH
    ;;
```

Note the dispatcher is a `for arg in "$@"` loop with last-wins semantics — `setup.sh check update` silently runs only `update`. That is pre-existing behaviour; if selective per-tool update is implemented (`setup.sh update trivy`), the `*)` catch-all at L853 currently errors on any unrecognised token and must be taught to accept a tool name **only when `COMMAND=update`**.

### Pattern 2: Attempt-then-verify update loop (the core of MAINT-02)

**What:** Never branch on an installer's exit code. Install, then independently verify with `is_installed`.
**When to use:** Every attempt in the D-04 sequence.

```bash
# Returns 0 if $tool is at $version AFTER the attempt, 1 otherwise.
attempt_install() {
  local tool="$1" version="$2" var_name="$3" installer="$4"

  # No save/restore needed: verified under /bin/bash 3.2.57 that an
  # assignment-prefix on a function call does not persist past the call.
  # Run the installer with the version global temporarily overridden.
  # VERIFIED under /bin/bash 3.2.57: assignment-prefix on a function call is
  # visible inside the function and does NOT persist after it returns.
  if [[ "$VERBOSE" = true ]]; then
    eval "${var_name}=\"\$version\" \"\$installer\"" || true
  else
    eval "${var_name}=\"\$version\" \"\$installer\"" > /dev/null 2>&1 || true
  fi

  # THE decision point — exit code above is deliberately discarded.
  is_installed "$tool" "$version"
}
```

The `|| true` is mandatory: without it, a failing installer under `set -e` terminates the script and D-03 ("continue on failure") is impossible.

The `tools=(...)` array shape is the one `run_check` already uses (L805-806) and is bash 3.2 safe. Verified under 3.2:

```bash
tools=("pre-commit:4.5.1:PRECOMMIT_VERSION:REPO_PRECOMMIT:_install_precommit"
       "trivy:0.69.3:TRIVY_VERSION:REPO_TRIVY:_install_trivy")
for entry in "${tools[@]}"; do
  IFS=':' read -r tool ver ver_var repo_var fn <<< "$entry"
  ...
done
```

`IFS=':' read <<<` (herestring) works in bash 3.2. Alternatively keep the existing `${entry%%:*}` / `${entry##*:}` idiom — also verified under 3.2 — but that only cleanly extracts the first and last fields, so for a 5-field record `read` is clearer.

### Pattern 3: Latest release within a major version (D-04 attempt 2)

**What:** One `GET /repos/{o}/{r}/releases?per_page=100`, extract `tag_name`s, filter to clean semver in the target major, sort numerically, take the highest.
**When to use:** Only on the attempt-1 failure path, per failed tool.

Verified live against all six tool repos (2026-09-09). Key details:

- **Whitespace-tolerant pattern is mandatory.** `hadolint/hadolint` returns compact JSON; the others return spaced. Use `'"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"'`.
- **Terminate with `sort | tail -1`, not `head -1`** — `head` closes the pipe early and produces SIGPIPE 141 under `pipefail` (verified).
- **Filter to `^[0-9]+\.[0-9]+\.[0-9]+$`** — this drops prereleases (`2.12.1-beta` was present in hadolint's real release list and was correctly excluded) without needing to parse the `"prerelease"` boolean, which grep cannot reliably associate with its object.
- **Releases are returned newest-first**, but sorting is still required because filtering by major can surface out-of-order backport releases.

### Pattern 4: GitHub token passthrough (rate-limit mitigation)

**What:** Resolve a token from, in order, `GITHUB_TOKEN`, `GH_TOKEN`, then `gh auth token`; send it as an `Authorization: Bearer` header. Degrade silently to unauthenticated when absent.

Verified on this machine: unauthenticated `x-ratelimit-limit: 60`; with a token from `gh auth token`, `x-ratelimit-limit: 5000`. That is an 83× increase for one header and zero cost — a perfect fit for the zero-cost-tooling constraint.

Non-negotiables:
- Header only, **never** in the URL (URLs land in shell history, `set -x` traces, and process listings).
- **Never** write the token, or any curl command containing it, to the D-07 failure log.
- No `--fail-with-body`, no echoing headers in verbose mode.

Explicitly **not** recommended: a version cache. Calls fire only on the failure path, and a cache introduces staleness plus a state file to invalidate. Token passthrough alone is sufficient.

### Pattern 5: Doctor as a distinct executability probe (MAINT-03)

**What:** For each tool, answer three separate questions and report them separately.

| Question | Mechanism | Distinguishes |
|----------|-----------|---------------|
| Is it on PATH? | `command -v "$tool"` | `NOT ON PATH` vs. everything else |
| Does the version command succeed? | run it, **capture `$?` before any pipe** | `BROKEN` (non-zero exit / not executable / dyld failure) |
| Is the output parseable? | `grep -oE '[0-9]+\.[0-9]+\.[0-9]+'` on captured output | `UNPARSEABLE` (ran fine, version format changed) |

This is the concrete reason `doctor` is a separate code path and not a column added to `run_check`: `get_installed_version` (L310-326) does `version="$("$tool" --version 2>&1 | head -1 | grep -oE ...)" || true`, which throws away the version command's own exit status and collapses "the binary is broken" and "the output format changed" into the single string `(unknown)`. MAINT-03 asks specifically whether tools "can execute their version command" — that is exactly the status `get_installed_version` discards.

```bash
tool_health() {
  local tool="$1" out rc
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "NOT_ON_PATH||"; return
  fi
  # Capture BEFORE piping so $? is the tool's, not head's/grep's.
  set +e
  if [[ "$tool" = "gitleaks" ]]; then out="$("$tool" version 2>&1)"; else out="$("$tool" --version 2>&1)"; fi
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "BROKEN|$rc|$(printf '%s' "$out" | head -1)"; return
  fi
  local ver
  ver="$(printf '%s' "$out" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  if [[ -z "$ver" ]]; then echo "UNPARSEABLE|0|$(printf '%s' "$out" | head -1)"; return; fi
  echo "OK|0|$ver"
}
```

Doctor should also report whether `$INSTALL_DIR` is actually on the user's `PATH` — that is INST-04's concern surfacing again, and `install_all_tools` already checks it (L509-512) but only warns during install.

### Anti-Patterns to Avoid

- **Branching on installer exit code.** See Pitfall 1. Always `is_installed`.
- **Exporting `$INSTALL_DIR` onto PATH inside `run_doctor`.** It would mask exactly the failure mode MAINT-03 exists to detect. `update` must export it (mirroring `install_all_tools` L497); `doctor` must not.
- **Adding a `jq` dependency.** The script's zero-dependency posture is a deliberate design decision from Phase 10.
- **Calling `exit 1` inside a command branch.** The script has a single exit gate at L890-894 driven by `FAIL_COUNT`. Mid-command `exit` would skip `print_summary` and the D-06 recheck.
- **Using `local -n` / `declare -A` / `${var,,}` / `mapfile`.** All bash 4+. `local -n` verified UNSUPPORTED under `/bin/bash` 3.2.57. `declare -A` was already removed in Phase 12 for this reason.
- **Re-implementing install logic in `update`.** Reuse `_install_*` (CONTEXT.md "Reusable Assets").
- **Writing the failure log as JSON.** D-07 mandates plain text.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Determining whether a tool reached a version | Parsing installer stdout for success strings | `is_installed "$tool" "$version"` (L292) | Already exists, already handles gitleaks' `version` (not `--version`) special case, and is the only trustworthy signal given Pitfall 1 |
| Printing the post-update state table | A new update-specific table | `run_check` (L798) | D-06 mandates it; duplicating the format guarantees drift |
| Result accumulation and summary | A new results array | `add_result` / `print_summary` (L92-111) | D-03 mandates it |
| Installing a specific tool version | New download/extract/verify code per tool | `_install_*` (L414-493) | They already handle OS/arch mapping, SHA-256 verification, and tmpdir cleanup traps |
| Semver comparison | A hand-rolled compare function with `if [[ $a -gt $b ]]` | `sort -t. -k1,1n -k2,2n -k3,3n \| tail -1` | Verified correct for `1.2.0 / 1.9.0 / 1.10.0`; a lexical compare gets `1.10.0 < 1.9.0` wrong |
| JSON field extraction | A bash JSON parser | Whitespace-tolerant `grep -o` + `sed` on one well-known field | A general parser is a large surface for a single-field need; the targeted regex is auditable |
| OS/arch → asset name mapping | New mapping logic | `get_gitleaks_os/arch`, `get_hadolint_os/arch` (L261-286) | Already correct and tool-specific (gitleaks uses `x64`, hadolint uses `x86_64`) |
| Upgrading a pipx-managed package | `pipx uninstall` then `pipx install` | `pipx install --force "pkg==VER"` | `--force` is the documented single-step reinstall-at-spec; uninstall/install leaves the tool absent if the install half fails |

**Key insight:** Nearly every capability this phase needs already exists in the script. The genuinely new code is one loop (`update_all_tools`), one API function (`resolve_latest_in_major`), one probe (`tool_health`/`run_doctor`), and one log appender. Everything else is composition. The risk in this phase is not writing too little — it is writing a parallel implementation of `run_check` or `run_installer` that drifts.

## Common Pitfalls

### Pitfall 1: `pipx install` silently no-ops and returns 0 — CRITICAL

**What goes wrong:** `update` reports pre-commit as successfully updated while the installed version is unchanged.
**Why it happens:** pipx dedupes by package **name**, ignoring the version specifier. Verified on this machine (pipx 1.10.1, pre-commit 4.5.1 installed):

```
$ pipx install "pre-commit==4.5.1"
'pre-commit' already seems to be installed. Not modifying existing
installation in '/Users/christian/.local/pipx/venvs/pre-commit'. Pass
'--force' to force installation.
$ echo $?
0
```

The same message and exit 0 occur for *any* version spec, including one pointing at a newer release. `_install_precommit` (L414-417) therefore cannot upgrade, and `run_installer` (L403) reads exit 0 and records `installed`.

**Impact beyond this phase:** the existing `install` command has this bug today. `bash setup.sh install` after bumping `PRECOMMIT_VERSION` in `versions.conf` reports success and changes nothing.

**How to avoid:**
1. Change `_install_precommit` to `pipx install --force "pre-commit==${PRECOMMIT_VERSION}"` (`--force` verified present in `pipx install --help` on 1.10.1).
2. **Independently of the fix**, make every attempt verify with `is_installed`. The fix addresses pipx; the verification addresses the whole class — any installer that succeeds-but-does-nothing.

**Warning signs:** `check` shows `MISMATCH` immediately after `update` reported `installed`. D-06's auto-recheck will surface this — which is a strong argument for D-06 being load-bearing rather than cosmetic.

**Related defect on the same code path:** `ensure_pipx` calls `exit 1` (L371) when pipx bootstrap fails. `_install_precommit` calls `ensure_pipx` (L415), so inside `update` a pipx bootstrap failure terminates the entire run — directly violating D-03 ("continue updating the remaining tools"). Change it to `return 1` and let the caller's `|| true` + `is_installed` verification record the failure normally. Note this also changes `install`'s behaviour from hard-abort to recorded-failure, which is consistent with how every other tool is already handled there.

### Pitfall 2: GitHub returns compact JSON for some repos — CRITICAL

**What goes wrong:** `resolve_latest_version`'s `/tags` fallback, and any new resolver copying its regex, return an empty string for certain repositories. Empty triggers the `|| "hardcoded-default"` path in `generate_versions_conf` (L187-192) and `resolve_hook_versions` (L536-542), so `versions.conf` is silently written with stale hardcoded versions and no error is shown.

**Why it happens:** GitHub does not uniformly pretty-print. Verified 2026-09-09 across three consecutive requests each:

| Endpoint | Body | Style |
|----------|------|-------|
| `hadolint/hadolint/releases?per_page=100` | 619 KB | `"tag_name":"v2.15.1"` — **compact** (stable across 3 requests) |
| `gitleaks/gitleaks/releases?per_page=100` | 2.4 MB | `"tag_name": "v8.30.1"` — spaced |
| `pre-commit/pre-commit/releases?per_page=100` | 471 KB | spaced |
| `aquasecurity/trivy/releases?per_page=100` | 4.5 MB | spaced |
| `anchore/syft`, `anchore/grype` `?per_page=100` | 5.1 / 3.9 MB | spaced |
| `*/tags`, `*/releases/latest` | ~14 KB | spaced |

It is not size-driven (hadolint's 619 KB is compact while pre-commit's 471 KB is spaced) and it is not random — it is stable per repository. Whatever the cause, the script must not depend on it.

**How to avoid:** Replace **all four** existing patterns plus any new one:

```bash
# before (L157, L164)
| grep -o '"tag_name": "[^"]*"'
| grep -o '"name": "[^"]*"'
# after
| grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"'
| grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"'
```

and correspondingly loosen the `sed` extraction. Verified: the tolerant pattern resolves hadolint's `2.15.1` correctly where the spaced pattern returns nothing.

**Warning signs:** `versions.conf` regenerating with versions identical to the hardcoded fallbacks in the script.

### Pitfall 3: `set -e` + `pipefail` + `head -1` = SIGPIPE 141 script death — CRITICAL

**What goes wrong:** A new bare call such as `latest=$(resolve_latest_in_major "$repo" "$major")` terminates the whole script mid-update.

**Why it happens:** Verified under `/bin/bash` 3.2.57:

```
$ /bin/bash -c 'set -euo pipefail; yes hello | grep -o hello | head -1 | sed s/h/H/; echo SURVIVED'
Hello
$ echo $?      # → 141 ; "SURVIVED" never printed
```

`head -1` closes the pipe, upstream `grep` receives SIGPIPE (128+13=141), `pipefail` propagates it as the pipeline status, `set -e` exits.

**Two distinct failure modes, one fix.** SIGPIPE is the dramatic one, but on the *actual* GitHub pipelines it is rarely the trigger — `grep -o` output for a 100-release body is only ~2.5 KB, which fits the pipe buffer, so `grep` exits before `head` ever closes anything. The mode that really fires in production is simpler: **`grep` exits 1 when it matches nothing**, which is exactly what an empty 403 rate-limit body or a changed JSON shape (Pitfall 2) produces. Under `pipefail` that is a non-zero pipeline, and under `set -e` it is fatal. Both modes are neutralised by the same rule below.

`resolve_latest_version` gets away with this today **only** because every one of its call sites is `x=$(resolve_latest_version ...) || x="default"` — `set -e` is suppressed for all but the last command of an `||` list, and that suppression propagates into the function body.

**How to avoid, two independent rules — apply both:**
1. In `resolve_latest_in_major`, terminate with `sort ... | tail -1`, which consumes the entire stream and never signals upstream. (My live probes used exactly this shape and none produced 141.)
2. **Every** call to any GitHub-touching function must sit in `||` or `if` context: `latest=$(resolve_latest_in_major "$r" "$m") || latest=""` then test `[[ -z "$latest" ]]`. Never assign bare.

**Warning signs:** `update` exits silently after the first failed tool with no summary and no log entry — the tail-of-script `FAIL_COUNT` gate never ran.

### Pitfall 4: `_install_*` functions read globals, not parameters

**What goes wrong:** D-04 attempt 2 needs to install a *different* version than the one in `versions.conf`, but `_install_trivy` (L420) reads `$TRIVY_VERSION` directly — there is no parameter to pass.

**How to avoid:** Use the assignment-prefix form. **Verified under `/bin/bash` 3.2.57** that this both takes effect inside the function and does not persist afterwards:

```
VER=1.0.0 ; f() { echo "inside VER=$VER"; } ; VER=2.0.0 f ; echo "after VER=$VER"
→ inside VER=2.0.0
→ after  VER=1.0.0
```

So `TRIVY_VERSION="$fallback" _install_trivy` is correct and self-restoring. Because the variable name differs per tool, drive it from the loop record via `eval` with an indirect name (Pattern 2), or accept an explicit per-tool `case`. Note `${!varname}` indirect *read* is verified working in 3.2; only indirect *assignment* needs `eval`.

**Caveat to document:** this non-persistence is bash-specific and would differ under POSIX mode; the script's shebang is `#!/usr/bin/env bash` and it never sets `set -o posix`, so the behaviour is safe here.

### Pitfall 5: `check` and `doctor` do not put `$INSTALL_DIR` on PATH; `update` must

**What goes wrong:** `run_check` can report `MISSING` for tools that are correctly installed in `~/.local/bin`, because unlike `install_all_tools` (L497 `export PATH="$INSTALL_DIR:$PATH"`) it never adds the install dir. And if `update` copies `run_check`'s pattern, its post-install `is_installed` verification fails for freshly installed tools, sending every tool down the attempt-2 path and burning six GitHub API calls against a 60/hr budget.

**How to avoid:**
- `update` **must** `export PATH="$INSTALL_DIR:$PATH"` before the loop, mirroring `install_all_tools`.
- `doctor` **must not** — it exists to test the user's real PATH (MAINT-03 / INST-04).
- `check`'s behaviour is a judgment call and belongs with Open Question 2.

Related: L509-512's PATH warning ends with `"Add to your shell profile:"` and a colon, but no line follows telling the user what to add. Worth fixing while in the neighbourhood.

### Pitfall 6: `?per_page=100` bodies are up to 5 MB

**What goes wrong:** Each D-04 attempt-2 resolution downloads 0.5-5 MB (trivy 4.5 MB, syft 5.1 MB). Six failing tools ≈ 20 MB of transfer.
**How to avoid:** Accept it — there is no lighter no-jq alternative that preserves correctness, and the path only fires on failure. But note the corollary: **if the pinned major is more than 100 releases behind, the target major will not appear on page one and resolution returns empty.** Do not paginate; treat empty as "attempt 2 failed" and fall through to skip + log, which is the correct D-04 step-3 outcome. Consider a slightly smaller `per_page` if body size becomes a practical problem — 30 (the API default) covers the overwhelmingly common case of "pinned major == current major".

### Pitfall 7: Rate limit is 60/hr unauthenticated and easy to exhaust

**What goes wrong:** `curl -sf` on a 403 rate-limit response produces an empty body and a non-zero exit, indistinguishable from "repo not found" or "network down". The `|| default` idiom swallows it entirely.
**Evidence:** This research session consumed 36 of 60 requests in a few minutes of probing. `ensure_versions_conf` on a repo with no `versions.conf` makes 6 calls; `resolve_hook_versions` makes 7 more.
**How to avoid:**
1. Token passthrough (Pattern 4) — verified to raise the limit to 5000.
2. When a resolution returns empty, emit an actionable hint rather than failing mutely: `warn "Could not resolve version for $repo — you may be GitHub rate-limited (60 req/hr unauthenticated). Set GITHUB_TOKEN to raise this to 5000/hr."`
3. Note that `GET /rate_limit` does **not** count against the limit (verified), so a diagnostic call inside `doctor` is free.

**Interaction with D-05:** retrying is useless against a 403 rate-limit — the reset is up to an hour away. If retry is implemented at all, scope it to the direct binary downloads in `_install_gitleaks`/`_install_hadolint` (genuine transient network failures), not to API resolution and not to pipx.

### Pitfall 8: `is_installed`'s substring version match

**What goes wrong:** `is_installed` compares `grep -oE '[0-9]+\.[0-9]+\.[0-9]+'` output against the expected string. Any tool whose `--version` line contains a *different* three-part number earlier than its own version (a build date, a Go version) matches the wrong token.
**Current status:** verified fine for the six tools today, but it is a latent fragility that `update` now depends on far more heavily than `install` did — it is the sole success criterion (Pitfall 1).
**How to avoid:** No change strictly required. If hardening: anchor the grep to `head -1` output only (already done) and, in `doctor`, print the raw first line of `--version` alongside the parsed version so a mismatch is visible to a human.

## Code Examples

### Example 1: Shared authenticated GitHub GET

```bash
# Resolve a token once, at startup. Header only — never in the URL.
GITHUB_TOKEN_VALUE="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
if [[ -z "$GITHUB_TOKEN_VALUE" ]] && command -v gh > /dev/null 2>&1; then
  GITHUB_TOKEN_VALUE="$(gh auth token 2>/dev/null)" || GITHUB_TOKEN_VALUE=""
fi

gh_api_get() {
  local url="$1"
  if [[ -n "$GITHUB_TOKEN_VALUE" ]]; then
    curl -sf -H "Authorization: Bearer ${GITHUB_TOKEN_VALUE}" \
            -H "X-GitHub-Api-Version: 2022-11-28" "$url"
  else
    curl -sf -H "X-GitHub-Api-Version: 2022-11-28" "$url"
  fi
}
```

Verified: with a token the response carries `x-ratelimit-limit: 5000`; without, `x-ratelimit-limit: 60`.

### Example 2: Latest release within a major version (D-04 attempt 2)

```bash
# resolve_latest_in_major <owner/repo> <major>
# Echoes e.g. "8.30.1", or nothing on failure.
# ALWAYS call as: v=$(resolve_latest_in_major "$r" "$m") || v=""
resolve_latest_in_major() {
  local repo="$1" major="$2" version

  version=$(gh_api_get "${GITHUB_API}/${repo}/releases?per_page=100" \
    | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed 's/.*"v\{0,1\}\([^"]*\)"$/\1/' \
    | grep -E "^${major}\.[0-9]+\.[0-9]+$" \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -1) || version=""

  [[ -z "$version" ]] && return 1
  echo "$version"
}
```

Verified live 2026-09-09 (with the whitespace-tolerant pattern) against every tool repo:

| Repo | Pinned | Major | Resolved |
|------|--------|-------|----------|
| `gitleaks/gitleaks` | 8.30.0 | 8 | `8.30.1` |
| `hadolint/hadolint` | 2.14.0 | 2 | `2.15.1` (empty with the space-only pattern — the bug in Pitfall 2) |
| `aquasecurity/trivy` | 0.69.3 | 0 | `0.74.0` |
| `anchore/syft` | 1.42.3 | 1 | `1.51.1` |
| `anchore/grype` | 0.110.0 | 0 | `0.118.0` |
| `pre-commit/pre-commit` | 4.5.1 | 4 | `4.6.2` |

Note the `^M\.[0-9]+\.[0-9]+$` anchor correctly excluded hadolint's real `v2.12.1-beta` tag without needing to parse the `prerelease` boolean.

### Example 3: Per-tool update with two-attempt fallback

```bash
update_one_tool() {
  local tool="$1" pinned="$2" ver_var="$3" repo_var="$4" installer="$5"
  local repo major fallback

  # ---- Short-circuit: already at the pinned version -------------------------
  # MAINT-02 is "update OUTDATED tools". Without this, a fully current system
  # re-downloads all six binaries and rebuilds the pipx venv on every run.
  # Mirrors run_installer's guard at L387.
  if is_installed "$tool" "$pinned"; then
    log "${tool} ${pinned} already current"
    add_result "$tool" "$pinned" "ok"
    return 0
  fi

  # ---- Attempt 1: exact pinned version -------------------------------------
  info "Updating ${tool} -> ${pinned}"
  if attempt_install "$tool" "$pinned" "$ver_var" "$installer"; then
    add_result "$tool" "$pinned" "ok"
    return 0
  fi

  # ---- Attempt 2: latest release within the pinned major -------------------
  warn "${tool} ${pinned} failed; resolving latest ${pinned%%.*}.x release"
  eval "repo=\"\${${repo_var}}\""
  major="${pinned%%.*}"
  fallback=$(resolve_latest_in_major "$repo" "$major") || fallback=""

  if [[ -z "$fallback" ]]; then
    warn "Could not resolve a ${major}.x release for ${repo}."
    warn "You may be GitHub rate-limited (60 req/hr unauthenticated); set GITHUB_TOKEN for 5000/hr."
  elif [[ "$fallback" = "$pinned" ]]; then
    log "Fallback resolved to the same version (${fallback}); not retrying."
  elif attempt_install "$tool" "$fallback" "$ver_var" "$installer"; then
    add_result "$tool" "$fallback" "fallback"     # see Open Question 1
    return 0
  fi

  # ---- Give up (D-04 step 3) ----------------------------------------------
  add_result "$tool" "$pinned" "FAILED"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  log_update_failure "$tool" "$pinned" "$fallback"
  return 1
}
```

Two subtleties worth preserving: the `fallback == pinned` short-circuit avoids a guaranteed-identical second attempt, and `return 1` is safe here only because the caller invokes this inside an `if`/`||` (otherwise `set -e` aborts the loop, breaking D-03).

### Example 4: Plain-text failure log (D-07)

```bash
UPDATE_LOG_NAME="update-failures.log"

log_update_failure() {
  local tool="$1" pinned="$2" fallback="${3:-}"
  local logfile="${REPO_ROOT}/${UPDATE_LOG_NAME}"
  {
    printf '%s  %-12s pinned=%-10s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tool" "$pinned"
    if [[ -n "$fallback" ]]; then printf ' fallback=%-10s' "$fallback"; else printf ' fallback=(unresolved)'; fi
    printf ' installed=%s\n' "$(get_installed_version "$tool")"
  } >> "$logfile"
}
```

Plain text, append-only, one line per failure, matching `print_summary`'s tabular style. `date -u +...` is POSIX and works on both BSD and GNU date. **Never** write the token or a full curl command into this file.

Planning should decide whether `$REPO_ROOT/update-failures.log` needs a `.gitignore` entry — D-07 places it at the root of whatever repo `update` is run in, so without an ignore rule it will show up as an untracked file in the user's project, and the pre-commit gitleaks hook will scan it.

### Example 5: Whitespace-hardened patch to the existing resolver

```bash
resolve_latest_version() {
  local repo="$1" version

  version=$(gh_api_get "${GITHUB_API}/${repo}/releases/latest" \
    | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed 's/.*"v\{0,1\}\([^"]*\)"$/\1/' \
    | head -1) || version=""

  if [[ -z "$version" ]]; then
    version=$(gh_api_get "${GITHUB_API}/${repo}/tags" \
      | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | sed 's/.*"v\{0,1\}\([^"]*\)"$/\1/' \
      | head -1) || version=""
  fi

  [[ -z "$version" ]] && { err "Failed to resolve latest version for ${repo}"; return 1; }
  echo "$version"
}
```

Two changes from the original: whitespace-tolerant patterns (Pitfall 2), and an explicit `|| version=""` on each assignment so a no-match `grep` (the real Pitfall 3 trigger — empty 403 body) cannot kill the script regardless of how the caller invokes it. Behaviour is otherwise identical, and all thirteen existing `|| fallback` call sites (L187-192, L536-542) continue to work unchanged.

## State of the Art

### `doctor` vs `check` — the ecosystem convention

| Tool | "health" command | "version currency" command | Semantics |
|------|------------------|---------------------------|-----------|
| npm | `npm doctor` | `npm outdated` | doctor = registry reachability, node/npm versions, git on PATH, directory permissions, cache integrity. `outdated` = which installed packages have newer versions [CITED: docs.npmjs.com/cli/v11/commands/npm-doctor] |
| Homebrew | `brew doctor` | `brew outdated` | doctor = environment problems; **exits non-zero when any warning is emitted, by design, so CI can gate on it** [CITED: github.com/Homebrew/legacy-homebrew#43879] |
| Flutter | `flutter doctor` | — | doctor = is the toolchain complete and functional [ASSUMED] |
| Rust | — | `rustup check` | check = are newer toolchains available [ASSUMED] |

The convention is consistent and maps cleanly onto this phase's requirements: **`doctor` = "does my environment work", `check`/`outdated` = "am I on the right version."** MAINT-01 is literally version currency and MAINT-03 is literally executability. **Recommendation: implement `doctor` as a distinct subcommand.** The technical justification is stronger than the naming one — `get_installed_version` structurally discards the exit status MAINT-03 asks about (Pattern 5), so a separate code path is needed regardless of what it is called.

### Exit-code convention

`brew doctor`'s explicit rationale — non-zero on warnings so scripts and CI can stop — is the strongest precedent available and matches this project's CI-gating orientation. `npm doctor`'s documentation says nothing about exit status. See Open Question 2 for how this interacts with D-06.

### Deprecated / outdated in this codebase

- `declare -A` — removed in Phase 12 for bash 3.2. Do not reintroduce.
- The space-dependent `'"tag_name": "..."'` grep pattern — demonstrably unreliable (Pitfall 2). Treat as deprecated.
- `_install_precommit`'s bare `pipx install` — cannot upgrade (Pitfall 1). Treat as a bug to fix, not a pattern to copy.
- ROADMAP.md's `dist/install.sh --check` — stale path *and* stale flag style (D-01).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `flutter doctor` and `rustup check` semantics | State of the Art | Low — npm and brew are verified via docs and are sufficient to establish the convention |
| A2 | `sort -V` is available in GNU coreutils ≥ 7.0 | Alternatives Considered | None — the recommendation is the POSIX field-sort form, which was verified on this machine; `sort -V` is mentioned only as a rejected alternative |
| A3 | GitHub's compact-vs-pretty JSON difference is a per-repository backend artifact rather than a documented, stable contract | Pitfall 2 | Low, and it argues *for* the recommendation: since the cause is unknown, the tolerant pattern is required either way. The observation itself is verified (3 consecutive requests per endpoint) |
| A4 | `pipx install --force` correctly downgrades as well as upgrades | Pitfall 1 | Medium. `--force` is verified present in `pipx install --help` (1.10.1) and documented as forcing installation over an existing venv, but a downgrade (`versions.conf` pinned *below* installed) was not empirically executed — doing so would have mutated the user's environment. Planning should include a manual verification step |
| A5 | `update-failures.log` at `$REPO_ROOT` will be picked up by the repo's gitleaks/markdownlint hooks unless ignored | Code Example 4 | Low — worth a one-line `.gitignore` decision during planning either way |
| A6 | GitHub's `releases` list is returned newest-first | Pattern 3 | None — the recommended pattern sorts explicitly and does not rely on API ordering |

## Open Questions

### 1. D-04 attempt-2 success conflicts with D-06 and D-08 — needs a planner decision

**What we know:** D-04 step 2 can succeed at a version that is *not* the `versions.conf` pin (verified: every one of the six tools has a newer release within its pinned major — e.g. trivy pinned 0.69.3, latest 0.x is 0.74.0). D-06 then runs `run_check`, which compares against the pin and prints `MISMATCH`. D-08 says `update` exits non-zero if a tool "failed to reach its pinned version" — which, read literally, a successful attempt 2 did not.

**What's unclear:** Is a successful fallback a success (exit 0, user sees a confusing MISMATCH) or a failure (exit 1, despite the tool now working)?

**Recommendation:** Report `fallback` as a distinct third status in `print_summary` (neither `ok` nor `FAILED`), do **not** increment `FAIL_COUNT` for it, do **not** silently rewrite `versions.conf`, and print an explicit follow-up line after the D-06 recheck: `NOTE: trivy installed at 0.74.0 (pinned 0.69.3 unavailable). Update versions.conf to adopt this version.` This keeps `versions.conf` an intentional, user-owned artifact — consistent with its header comment "Edit versions here, then re-run" — while making the MISMATCH self-explanatory. The alternative (auto-writing the resolved version back) is defensible but silently mutates a pinned manifest, which undercuts the whole point of pinning (INST-03).

### 2. Should `check` (and `doctor`) exit non-zero on problems?

**What we know:** `run_check` currently always exits 0. `brew doctor` deliberately exits non-zero on warnings so CI can gate. D-08 establishes that `FAIL_COUNT` drives the exit code, and the tail gate at L890 is global.

**What's unclear:** If `run_check` starts incrementing the global `FAIL_COUNT` on MISMATCH/MISSING, then D-06's auto-recheck inside `update` **double-counts** — and worse, a *successful* attempt-2 fallback would produce a MISMATCH that flips `update` to exit 1, directly contradicting Open Question 1's recommendation.

**Recommendation:** Do not let `run_check` touch the global `FAIL_COUNT`. Have it set a separate variable (e.g. `CHECK_PROBLEM_COUNT`) or return the count as its exit status, and let the **dispatcher** decide: the `check` branch maps it to `FAIL_COUNT`; the `update` branch (D-06) ignores it because `update`'s own results already determined the outcome. Same structure for `doctor`. This keeps each subcommand's exit contract independent while preserving the single tail-of-script exit gate.

Suggested contract: `check` → 0 all `ok`, 1 any MISMATCH/MISSING. `doctor` → 0 all `OK`, 1 any `NOT_ON_PATH`/`BROKEN`/`UNPARSEABLE`. `update` → per D-08.

### 3. Selective per-tool update

**What we know:** CONTEXT.md leaves this open. The dispatcher's `*)` catch-all (L853) currently rejects any unrecognised token.

**Recommendation:** Support it — `bash setup.sh update trivy`. It is a small change to the existing `for arg` loop (accept a bare tool name into an `UPDATE_TARGETS` list, validated against the known tool set), and it directly addresses Pitfall 7: after a partial failure, retrying one tool costs one API call instead of six against a 60/hr budget. Default (no tool named) remains all six.

### 4. `.gitignore` for the failure log

D-07 places `update-failures.log` at the root of the user's repo. Should `configure`/`setup` add it to `.gitignore`, or should the log go somewhere already ignored? Low stakes, but it should be a conscious decision — otherwise every user of this tooling gets an untracked file in `git status` after any failed update.

### 5. Fix `install`'s pre-commit upgrade bug in this phase?

Pitfall 1 is a pre-existing defect in `install`, not strictly in Phase 13's scope. Recommendation: **yes, fix it here** — `update` depends on `_install_precommit` and cannot work correctly without the fix, so the change is unavoidable; the only question is whether it is framed as in-scope. It is a one-flag change with a direct correctness justification.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `/bin/bash` (3.2 compat target) | Entire script | ✓ | 3.2.57 | — |
| `bash` (dev shell) | Ad-hoc testing | ✓ | 5.3.15 | — (see Pitfall note: test under `/bin/bash`) |
| `curl` | GitHub API, downloads | ✓ | system | — |
| `sort` (BSD) with `-t/-k` numeric | Semver ordering | ✓ | system | — (verified) |
| `sort -V` | Alternative semver ordering | ✓ | system | Not used; field-sort preferred |
| `pipx` | pre-commit install/update | ✓ | 1.10.1 | `ensure_pipx` bootstraps it |
| `shellcheck` | Lint the modified script | ✓ | `/opt/homebrew/bin/shellcheck` | pre-commit hook `shellcheck-py v0.11.0.1` |
| `bats` | Optional bash unit tests | ✓ | `~/.nvm/.../bin/bats` | Manual smoke tests |
| `gh` CLI | Optional token source | ✓ | `/opt/homebrew/bin/gh` | `GITHUB_TOKEN`/`GH_TOKEN` env vars, or unauthenticated 60/hr |
| GitHub REST API | D-04 attempt 2 | ✓ | `2022-11-28` | None — empty result → skip + log (correct D-04 step 3) |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** none missing. Note `gh` and a token are *optional* — the script must work unauthenticated at 60/hr.

**Rate-limit budget observed during this research:** 60 → 24 remaining after ~36 probe requests. The constraint is real and tight; this is the empirical basis for Pattern 4 and Open Question 3.

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **None exists.** No test directory, no `*.bats`, no `*test*` file anywhere under `repos/security-platform/` (verified by `find`) |
| Static analysis | `shellcheck` via pre-commit hook `shellcheck-py v0.11.0.1`, `types: [shell]` (`repos/security-platform/.pre-commit-config.yaml` L35-39) |
| Available but unwired | `bats` is installed on this machine |
| Quick run command | `/bin/bash -n repos/security-platform/workstation/setup.sh && shellcheck repos/security-platform/workstation/setup.sh` |
| Full suite command | Above, plus the manual smoke sequence below |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| — | Script parses under the real compat target | syntax | `/bin/bash -n repos/security-platform/workstation/setup.sh` | ✅ no file needed |
| — | No new shellcheck findings | static | `shellcheck repos/security-platform/workstation/setup.sh` | ✅ hook wired |
| MAINT-01 | `check` prints the version + prereq tables | smoke | `/bin/bash repos/security-platform/workstation/setup.sh check` | ✅ exists today |
| MAINT-01 | `check` exit code matches the agreed contract | smoke | `/bin/bash .../setup.sh check; echo $?` | ❌ contract undecided (Open Q 2) |
| MAINT-02 | `update` help/usage lists the new subcommand | smoke | `/bin/bash .../setup.sh --help \| grep -q update` | ✅ no file needed |
| MAINT-02 | `resolve_latest_in_major` returns the right value per repo | unit | Source the script with a guard, call the function directly — see Wave 0 | ❌ Wave 0 |
| MAINT-02 | Attempt-2 fallback fires and is recorded as `fallback` | integration | Set an impossible pin (e.g. `TRIVY_VERSION="0.69.99999"`) in a scratch `versions.conf`, run `update trivy` | ❌ Wave 0 (needs scratch fixture) |
| MAINT-02 | Failure log is written to `$REPO_ROOT` with one line per failure | integration | Same fixture; assert the file exists and is non-empty | ❌ Wave 0 |
| MAINT-02 | pre-commit actually changes version (Pitfall 1 regression) | manual | Pin `PRECOMMIT_VERSION` one release back, run `update`, confirm `check` shows the new version | ❌ manual — mutates the developer's environment; must be a `checkpoint:human-verify` |
| MAINT-02 | `update` exits non-zero when a tool fails (D-08) | integration | Impossible-pin fixture; `echo $?` == 1 | ❌ Wave 0 |
| MAINT-03 | `doctor` reports `NOT_ON_PATH` for an absent tool | integration | Run with `PATH` scrubbed of `$INSTALL_DIR` in a subshell | ❌ Wave 0 |
| MAINT-03 | `doctor` reports `BROKEN` for a non-executable stub | integration | Put a `chmod 000` / `exit 1` stub earlier on `PATH` in a scratch dir | ❌ Wave 0 |

**Critical constraint:** the script is `set -euo pipefail` with all logic at file scope, so it **cannot be `source`d for unit testing as-is** — sourcing it executes `check_prerequisites` and the dispatcher. Wave 0 must either (a) add a `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` main-guard around lines 847-894, or (b) test only via subprocess invocation. Option (a) is the standard bash idiom, is bash 3.2 compatible, and unlocks direct unit tests of `resolve_latest_in_major` — **recommended**.

### Sampling Rate

- **Per task commit:** `/bin/bash -n setup.sh && shellcheck setup.sh` (sub-second, no network)
- **Per wave merge:** above + `/bin/bash setup.sh check` + `/bin/bash setup.sh --help`
- **Phase gate:** full suite green, plus the manual pre-commit-upgrade verification (Pitfall 1 / A4), before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] Add a `main`-guard to `setup.sh` (lines ~847-894) so the file can be sourced for unit testing — covers MAINT-01/02/03 testability
- [ ] `repos/security-platform/workstation/tests/` directory — does not exist
- [ ] `tests/test_version_resolution.bats` — covers `resolve_latest_in_major` and the whitespace-tolerant parsing (Pitfall 2). **Should use recorded JSON fixtures, not live API calls** — live calls in tests will exhaust the 60/hr budget
- [ ] `tests/fixtures/hadolint-releases-compact.json` and `tests/fixtures/gitleaks-releases-spaced.json` — captured samples of both JSON styles, so the Pitfall 2 regression is permanently guarded
- [ ] `tests/test_update_fallback.bats` — impossible-pin fixture driving the D-04 attempt-2 path and the D-07 log
- [ ] `tests/test_doctor.bats` — PATH-scrubbed and broken-stub scenarios
- [ ] Decide whether `bats` becomes a declared dev dependency (it is present here but is not in `check_prerequisites`); if the answer is no, downgrade the above to a single `tests/smoke.sh` driven by plain bash asserts

## Security Domain

`security_enforcement` is not disabled in config, so this section applies. This is a local developer CLI with no server, no user input from untrusted parties, and no data store — most ASVS categories are structurally inapplicable.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Partially | GitHub token is read-only and optional. Read from env (`GITHUB_TOKEN`/`GH_TOKEN`) or `gh auth token`; never prompted for, never persisted, never written to the D-07 log |
| V3 Session Management | No | No sessions |
| V4 Access Control | No | Single local user; script writes only to `$HOME/.local/bin` and `$REPO_ROOT` |
| V5 Input Validation | Yes | Versions resolved from the API are interpolated into download URLs. The `^[0-9]+\.[0-9]+\.[0-9]+$` filter in `resolve_latest_in_major` is a security control as well as a correctness one — it prevents an arbitrary `tag_name` string from reaching a URL or a `pipx install` spec. **Do not relax it.** |
| V6 Cryptography | Yes | SHA-256 verification already implemented in `verify_sha256` (L329) and used by `_install_gitleaks`/`_install_hadolint`. `update` reuses those functions, so it inherits the verification. **Never add an update path that bypasses `_install_*`.** |
| V7 Error Handling & Logging | Yes | D-07's log must not contain the token, full curl commands, or environment dumps |
| V12 Files & Resources | Yes | `mktemp -d` + `trap 'rm -rf' RETURN` already used correctly (L446-447, L478-479); any new temp usage must follow suit |
| V14 Configuration | Yes | HTTPS-only URLs; `curl -sf`/`-sSfL` already fails closed on HTTP errors |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious/unexpected `tag_name` interpolated into a download URL or install spec | Tampering | Strict `^[0-9]+\.[0-9]+\.[0-9]+$` filter before any use (Pattern 3) |
| Supply-chain substitution of a downloaded binary | Tampering | Existing `verify_sha256` in `_install_gitleaks`/`_install_hadolint`; trivy/syft/grype delegate to vendor install scripts. Note: **checksum verification of the vendor install scripts themselves is documented as out of scope** in REQUIREMENTS.md and remains so |
| Token leakage via shell history, `set -x`, process list, or the failure log | Information Disclosure | Header not URL; never log; no `set -x` in the new code paths |
| Downgrade attack — fallback resolving to an *older* release than pinned | Tampering | The `^major\.` filter plus the recommended `fallback == pinned` short-circuit. Planning should also consider rejecting a fallback that sorts *below* the pin |
| Rate-limit exhaustion causing a silently stale `versions.conf` | Denial of Service (self-inflicted) | Pitfall 7 — actionable warning on empty resolution instead of a mute `|| default` |
| Log file written into a user repo and accidentally committed | Information Disclosure | `.gitignore` decision (Open Question 4); the log contains only tool names and versions if the token rule is followed |

## Project Constraints (from CLAUDE.md)

**Root `CLAUDE.md`** — this repository is a *reference documentation project*; the primary artifact is `development-security-stack-option-1.md`. Implications for Phase 13:

- ADR records in `docs/adr/` are **append-only**. If Phase 13's decisions (doctor-as-subcommand, exit-code contract, fallback status) warrant an ADR, add a **new** file — never modify ADR-001..014.
- Preserve ASCII architecture diagrams and the 4-phase layered structure in the primary document if it is touched.
- The implementation target lives in the **sibling** `repos/security-platform/` checkout, not in this documentation repo's own tree.

**`.claude/rules/defensive-protocol-v2-anti-slop.md`** — directly binding on execution:

- **Never set the executable bit on scripts; always invoke as `bash script.sh`.** Note `repos/security-platform/workstation/setup.sh` currently has mode `-rwxr-xr-x`. Do not add to this; all documentation, tests, and usage strings must use `bash setup.sh <cmd>` (which the existing `usage()` already does).
- **On failure: STOP → REPORT → WAIT.** No silent retries. This constrains D-05: any retry must be an explicit, bounded, logged policy — not an unreported loop.
- **"Silent fallbacks (`or {}`, `try/except: pass`) convert hard failures into silent corruption. Let it crash."** This is the rule Pitfalls 1, 2 and 7 all violate today: `|| true`, `|| "hardcoded-default"`, and trusting exit 0. Every `|| default` added in this phase must be paired with a visible `warn`.
- **Second-order effects:** before changing `resolve_latest_version` or `_install_precommit`, enumerate callers. `resolve_latest_version` has 13 call sites (L187-192 and L536-542). `_install_precommit` has 1 (L501) plus the new `update` path.
- **Verification cadence:** 3 actions then verify for unfamiliar work. Applies to the `update` loop implementation.

**`.claude/rules/defensive-protocol-v2-epistemology.md`** — Chesterton's Fence applies to the `# shellcheck disable=SC2329` comments scattered through the installer functions (L242, L251, L260, ...): they exist because the functions are invoked indirectly via `run_installer "$@"`. New indirectly-invoked functions will need the same directive; do not remove existing ones.

**Project skills present** (`.claude/skills/`): `cdk-testing`, `create-prd`, `itsg-assessment`, `nist-csf-assessment`, `nist-fedramp-assessment`, `occ-skill-creator`, `occ-skill-refactor`, `rule-creator`, `terraform-testing`. None apply to bash CLI work in this phase.

## Sources

### Primary (HIGH confidence — empirically verified in this session, 2026-09-09)

- **Live GitHub REST API** (`api.github.com/repos/*/releases`, `/releases/latest`, `/tags`, `/rate_limit`) — JSON formatting variance across the six tool repos; newest-first ordering; `X-RateLimit-Limit` 60 unauthenticated vs. 5000 with a Bearer token; `resolve_latest_in_major` output for all six repos
- **`/bin/bash` 3.2.57 on this machine** — assignment-prefix non-persistence for function calls; `local -n` unsupported; `${!var}` indirect read supported; `tools=("a:b")` array + `${e%%:*}`/`${e##*:}` extraction; `set -euo pipefail` + `head -1` → exit 141 with subsequent statements skipped
- **`pipx` 1.10.1 on this machine** — `pipx install "pre-commit==4.5.1"` on an already-installed package prints "already seems to be installed… Pass '--force'" and **exits 0**; `--force` present in `pipx install --help`
- **BSD `sort` on this machine** — both `sort -V` and `sort -t. -k1,1n -k2,2n -k3,3n` order `1.2.0 < 1.9.0 < 1.10.0` correctly
- **`repos/security-platform/workstation/setup.sh`** (894 lines, read in full) — all line references in this document
- **`repos/security-platform/versions.conf`** — current pins
- **`repos/security-platform/.pre-commit-config.yaml`** — shellcheck hook `v0.11.0.1`
- **`.planning/phases/13-maintenance-and-validation/13-CONTEXT.md`**, **`.planning/REQUIREMENTS.md`**, **`.planning/STATE.md`**, **`.planning/config.json`**
- `docs.npmjs.com/cli/v11/commands/npm-doctor` — npm doctor's check list; explicitly confirmed the docs say nothing about exit status

### Secondary (MEDIUM confidence)

- `github.com/Homebrew/legacy-homebrew/issues/43879` — `brew doctor` exits non-zero on warnings, by design, for CI gating
- WebSearch synthesis on `npm doctor` vs `npm outdated` semantics — corroborated against the official npm docs above

### Tertiary (LOW confidence — flagged, not load-bearing)

- `flutter doctor` / `rustup check` semantics (training knowledge, not verified this session; see Assumptions Log A1). These reinforce a convention already established by two verified sources and no recommendation depends on them alone.

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — no new dependencies; every existing tool version confirmed by direct invocation on this machine
- Architecture / patterns: **HIGH** — every bash-3.2 idiom recommended was executed under `/bin/bash` 3.2.57, and the `resolve_latest_in_major` pipeline was run against all six live repos
- Pitfalls: **HIGH** — Pitfalls 1, 2, 3, 4 and 7 were each reproduced empirically rather than inferred. Pitfalls 5, 6 and 8 are direct code reads
- `doctor` vs `check` recommendation: **MEDIUM-HIGH** — the ecosystem convention is MEDIUM (two verified sources), but the technical justification (`get_installed_version` discards the version command's exit status) is HIGH and independently sufficient
- Open Questions 1 and 2: deliberately unresolved — these are genuine design decisions with a stated recommendation, not research gaps

**Research date:** 2026-09-09
**Valid until:** 2026-10-09 (30 days). The pinned upstream versions will drift — re-verify the `resolve_latest_in_major` output table before relying on the specific version numbers. The bash 3.2 findings and the pipx behaviour are stable.
