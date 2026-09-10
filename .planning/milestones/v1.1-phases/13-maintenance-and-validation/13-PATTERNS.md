# Phase 13: Maintenance and Validation - Pattern Map

**Mapped:** 2026-09-09
**Files analyzed:** 1 primary script decomposed into **14 change units** + **4 test/fixture units** + **5 doc/config files**
**Analogs found:** 13 / 14 script units · 2 / 4 test units · 5 / 5 doc/config files

> **Decomposition note.** This phase modifies **one 894-line bash script**, not a set of new files. A single
> `setup.sh` row would be useless to the planner, so the table below is decomposed to **function-level change
> units** (`setup.sh :: fn_name()`). Each unit is independently assignable to a plan.

**Implementation target (sibling checkout, NOT this repo's git history):**
`repos/security-platform/workstation/setup.sh` — 894 lines, mode `-rwxr-xr-x`, `#!/usr/bin/env bash`,
`set -euo pipefail`, 2-space indent, no color codes. All invocations documented as `bash setup.sh <cmd>`.

---

## File Classification

### Primary target: `repos/security-platform/workstation/setup.sh` (14 change units)

| Change unit | Role | Data Flow | Closest Analog | Match Quality |
|-------------|------|-----------|----------------|---------------|
| `update_all_tools()` — NEW | orchestrator | batch | `install_all_tools` L495-513 | exact |
| `update_one_tool()` — NEW | service | batch / request-response | `run_installer` L383-411 | exact |
| `attempt_install()` — NEW | utility | transform | `run_installer` L393-410 (verbose/quiet `"$@"` branch) | role-match |
| `resolve_latest_in_major()` — NEW | service | request-response (HTTP) | `resolve_latest_version` L151-175 | exact |
| `gh_api_get()` — NEW | utility | request-response (HTTP) | `resolve_latest_version` L156/L163 curl lines | partial (auth header has no analog) |
| `resolve_latest_version()` — HARDEN | service | request-response (HTTP) | itself, L151-175 | in-place |
| `run_doctor()` — NEW | controller | request-response | `run_check` L798-841 | exact |
| `tool_health()` — NEW | utility | transform | `ensure_pipx` L364/L368 (status capture) + `get_installed_version` L310-326 (probe shape) | role-match |
| `log_update_failure()` — NEW | utility | file-I/O | `write_config` L519-531 + `print_summary` L101-105 (printf widths) | partial |
| `_install_precommit()` — FIX (`--force`) | installer | file-I/O | itself, L414-417 | in-place |
| `ensure_pipx()` — FIX (`exit 1` → `return 1`) | utility | file-I/O | itself, L371-372 | in-place |
| Dispatcher + `usage()` — EXTEND | route / config | event-driven | L848-888 case blocks + L55-72 heredoc | exact |
| Constants block — EXTEND | config | — | L24-49 | exact |
| `main`-guard for sourceability — NEW | config | — | **none in codebase** | no analog |

### New test units: `repos/security-platform/workstation/tests/`

| New unit | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `tests/` directory | test | — | `repos/terraform-pipelines/tests/` (sibling repo) | partial |
| Test runner — `tests/smoke.sh` **or** `tests/test_version_resolution.bats` + `tests/test_update_fallback.bats` + `tests/test_doctor.bats` (RESEARCH Wave 0 names) | test | batch | `repos/terraform-pipelines/tests/test-terraform.sh` (450 lines, plain bash) | partial — structure only, style differs |
| `tests/fixtures/hadolint-releases-compact.json` | fixture | file-I/O | **none** | no analog |
| `tests/fixtures/gitleaks-releases-spaced.json` | fixture | file-I/O | **none** | no analog |

### Secondary (documentation / config) files

| File | Role | Change | Analog / anchor |
|------|------|--------|-----------------|
| `repos/security-platform/workstation/README.md` | doc | add `update` / `doctor` to command list | L14-20 quick-start block; L155-162 "Version Management" |
| `repos/security-platform/workstation/ARCHITECTURE.md` | doc | update "Version Resolution" + "File Structure" | L138 / L227 / L248 headings |
| `repos/security-platform/.gitignore` | config | possible `update-failures.log` entry (Open Q4) | its own comment-header section style (`# OS`, `# Python`, `# pre-commit`) |
| `.planning/ROADMAP.md` (this repo) | doc | D-01 correction: `dist/install.sh --check` → `setup.sh check` | L200-217 Phase 13 block |
| `docs/adr/adr015-*.md` (this repo) | doc | optional new ADR (doctor-as-subcommand / exit contract) | `docs/adr/adr014-cosign-slsa-kyverno.md` header block + `docs/adr/README.md` L22-24 table row format — **append-only, never edit ADR-001..014** |

### Read-only inputs (do NOT modify)

| File | Why |
|------|-----|
| `repos/security-platform/versions.conf` | The pinned manifest. RESEARCH Open Q1 recommends **not** auto-writing a resolved fallback version back into it. Mark as read-only unless the planner explicitly resolves Open Q1 the other way. |

---

## Pattern Assignments

### `setup.sh :: update_all_tools()` (orchestrator, batch) — NEW

**Analog:** `install_all_tools` (setup.sh L495-513)

**Core orchestration pattern** (L495-513) — copy the shape, including the `mkdir -p` + `export PATH`
prologue (Pitfall 5: `update` **must** export; `doctor` must **not**):

```bash
install_all_tools() {
  mkdir -p "$INSTALL_DIR"
  export PATH="$INSTALL_DIR:$PATH"

  info "Installing security tools to $INSTALL_DIR"

  run_installer "pre-commit" "$PRECOMMIT_VERSION" _install_precommit
  run_installer "trivy"      "$TRIVY_VERSION"      _install_trivy
  run_installer "syft"       "$SYFT_VERSION"        _install_syft
  run_installer "grype"      "$GRYPE_VERSION"       _install_grype
  run_installer "gitleaks"   "$GITLEAKS_VERSION"    _install_gitleaks
  run_installer "hadolint"   "$HADOLINT_VERSION"    _install_hadolint

  # PATH verification
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *) warn "$INSTALL_DIR is not in your PATH. Add to your shell profile:" ;;
  esac
}
```

**Deltas required (do not copy verbatim):**
- The six flat `run_installer` calls become a loop over a 5-field `tool:version:VER_VAR:REPO_VAR:installer`
  record array, because `update_one_tool` needs the version-variable name and repo name per tool
  (RESEARCH Pattern 2). Use the array idiom from `run_check` L805-806 (below), not `declare -A`.
- L511's warning message ends in `"Add to your shell profile:"` with **nothing after the colon** — a
  pre-existing defect worth fixing while in the neighbourhood (RESEARCH Pitfall 5).

**Array + field-split idiom** — copy from `run_check` L805-810 (verified bash 3.2 safe):

```bash
  local tools=("pre-commit:$PRECOMMIT_VERSION" "trivy:$TRIVY_VERSION" "syft:$SYFT_VERSION"
               "grype:$GRYPE_VERSION" "gitleaks:$GITLEAKS_VERSION" "hadolint:$HADOLINT_VERSION")

  for entry in "${tools[@]}"; do
    local tool="${entry%%:*}"
    local expected="${entry##*:}"
```

`${entry%%:*}` / `${entry##*:}` only cleanly extract the **first and last** fields. For a 5-field record use
`IFS=':' read -r tool ver ver_var repo_var fn <<< "$entry"` (herestring — verified working under
`/bin/bash` 3.2.57, RESEARCH Pattern 2).

---

### `setup.sh :: update_one_tool()` / `attempt_install()` (service, batch) — NEW

**Analog:** `run_installer` (setup.sh L383-411)

**Full analog — this is the single closest existing function to the new code:**

```bash
run_installer() {
  local name="$1" version="$2"
  shift 2

  if is_installed "$name" "$version"; then
    log "$name $version already installed"
    add_result "$name" "$version" "ok"
    return
  fi

  log "Installing $name $version..."
  if [[ "$VERBOSE" = true ]]; then
    if "$@"; then
      add_result "$name" "$version" "installed"
    else
      err "Failed to install $name $version"
      add_result "$name" "$version" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    if "$@" > /dev/null 2>&1; then
      add_result "$name" "$version" "installed"
    else
      err "Failed to install $name $version"
      add_result "$name" "$version" "FAILED"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
}
```

**What to copy:**
- **Already-current short-circuit** (L387-391) — `update_one_tool` needs the identical guard, or a fully
  current machine re-downloads six binaries and rebuilds the pipx venv on every `update` (RESEARCH Example 3).
- **VERBOSE quiet/loud duplication** (L394-410) — the `if [[ "$VERBOSE" = true ]]` / `> /dev/null 2>&1` split
  is the project's established way of running a child command. `attempt_install` reproduces this shape.
- **`add_result` + `FAIL_COUNT++` pairing** (L399-400 / L407-408) — always incremented together, never apart.

**What to change (critical):**
- **L395 / L403 branch on the installer's exit code. `update` must NOT.** RESEARCH Pitfall 1 verified
  `pipx install "pre-commit==X"` exits 0 while changing nothing. Replace the exit-code branch with
  `"$@" ... || true` followed by an independent `is_installed "$tool" "$version"` as the sole decision point.
- `_install_*` functions read **globals**, not parameters (L416 `$PRECOMMIT_VERSION`, L421 `$TRIVY_VERSION`).
  D-04 attempt 2 installs a *different* version, so use the assignment-prefix form
  (`TRIVY_VERSION="$fallback" _install_trivy`) — verified non-persisting under bash 3.2.57 (RESEARCH Pitfall 4).
- **Where `eval` is and is not needed:** invoking a function whose *name* lives in a variable needs no eval —
  `"$installer"` (or `"$@"`, as `run_installer` L395 does) is sufficient. `eval` is needed **only** because
  the *variable name* in the assignment prefix is dynamic per tool
  (`eval "${var_name}=\"\$version\" \"\$installer\""`). Indirect *read* `${!varname}` works in bash 3.2;
  only indirect *assignment* requires `eval`. An explicit per-tool `case` is the eval-free alternative.

**Status vocabulary already in use:** `ok` (L389), `installed` (L396/L404), `FAILED` (L399/L407). RESEARCH
Open Q1 proposes a fourth, `fallback`, that does **not** increment `FAIL_COUNT` — planner decides.

---

### `setup.sh :: resolve_latest_in_major()` + `gh_api_get()` (service, request-response) — NEW

**Analog:** `resolve_latest_version` (setup.sh L151-175) — also the **harden-in-place** target

```bash
resolve_latest_version() {
  local repo="$1"
  local version

  # Try /releases/latest first (most repos)
  version=$(curl -sf "${GITHUB_API}/${repo}/releases/latest" 2>/dev/null \
    | grep -o '"tag_name": "[^"]*"' \
    | head -1 \
    | sed 's/"tag_name": "v\{0,1\}\(.*\)"/\1/')

  # Fall back to tags (some repos like shellcheck-py don't use releases)
  if [[ -z "$version" ]]; then
    version=$(curl -sf "${GITHUB_API}/${repo}/tags" 2>/dev/null \
      | grep -o '"name": "[^"]*"' \
      | head -1 \
      | sed 's/"name": "v\{0,1\}\(.*\)"/\1/')
  fi

  if [[ -z "$version" ]]; then
    err "Failed to resolve latest version for ${repo}"
    return 1
  fi

  echo "$version"
}
```

**COPY:** the overall shape — `local repo="$1"; local version`, pipeline into `$( )`, empty-check →
`err` + `return 1`, `echo "$version"` as the only stdout. `GITHUB_API` is already defined at L31 as
`https://api.github.com/repos`.

**DO NOT COPY — these four lines are the bug (RESEARCH Pitfall 2):**
- L157 `grep -o '"tag_name": "[^"]*"'` — space-dependent; returns **empty** for `hadolint/hadolint`,
  which serves compact JSON.
- L159 `sed 's/"tag_name": "v\{0,1\}\(.*\)"/\1/'` — same space dependency.
- L164 `grep -o '"name": "[^"]*"'` and L166 its `sed` — same, on the `/tags` fallback path.

Replace all four with the whitespace-tolerant form `'"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"'` and
`sed 's/.*"v\{0,1\}\([^"]*\)"$/\1/'` (RESEARCH Example 5).

**DO NOT COPY — terminator:** L158/L165 use `head -1`. In the new `resolve_latest_in_major` the pipeline
must terminate with `sort -t. -k1,1n -k2,2n -k3,3n | tail -1` (stream-consuming) — `head` triggers
SIGPIPE 141 under `set -euo pipefail`, verified fatal on bash 3.2.57 (RESEARCH Pitfall 3).

**DO NOT COPY — bare assignment:** L156/L163 assign bare. That is safe *today only because* every call site
wraps the call in `|| default` (L187-192). Add an explicit `|| version=""` on each assignment inside the
function so it is safe regardless of call site.

**Call-site convention to copy verbatim** — `generate_versions_conf` L187-192:

```bash
  local precommit_ver trivy_ver syft_ver grype_ver gitleaks_ver hadolint_ver
  precommit_ver=$(resolve_latest_version "$REPO_PRECOMMIT") || precommit_ver="4.2.0"
  trivy_ver=$(resolve_latest_version "$REPO_TRIVY") || trivy_ver="0.69.3"
  syft_ver=$(resolve_latest_version "$REPO_SYFT") || syft_ver="1.42.2"
  grype_ver=$(resolve_latest_version "$REPO_GRYPE") || grype_ver="0.109.1"
  gitleaks_ver=$(resolve_latest_version "$REPO_GITLEAKS") || gitleaks_ver="8.30.0"
  hadolint_ver=$(resolve_latest_version "$REPO_HADOLINT") || hadolint_ver="2.14.0"
```

Every GitHub-touching call **must** sit in `||` or `if` context. Note: CLAUDE.md's anti-slop rule requires
each new `|| default` to be paired with a visible `warn` — the existing lines above are silent, which is
exactly the Pitfall 7 failure mode. New code should not copy the silence.

**Repo-name constants already exist** (L35-40) — `REPO_PRECOMMIT`, `REPO_TRIVY`, `REPO_SYFT`, `REPO_GRYPE`,
`REPO_GITLEAKS`, `REPO_HADOLINT`. `update_one_tool` reads these by indirect name from the record array.

---

### `setup.sh :: run_doctor()` (controller, request-response) — NEW

**Analog:** `run_check` (setup.sh L798-841)

**Table + loop pattern** (L798-824) — copy the header/rule/printf-width structure exactly so `doctor` output
is visually consistent with `check`:

```bash
run_check() {
  echo ""
  echo "Security Tool Version Check"
  echo "----------------------------"
  printf "%-14s %-14s %-14s %s\n" "Tool" "Expected" "Installed" "Status"
  printf "%-14s %-14s %-14s %s\n" "----" "--------" "---------" "------"

  local tools=("pre-commit:$PRECOMMIT_VERSION" "trivy:$TRIVY_VERSION" "syft:$SYFT_VERSION"
               "grype:$GRYPE_VERSION" "gitleaks:$GITLEAKS_VERSION" "hadolint:$HADOLINT_VERSION")

  for entry in "${tools[@]}"; do
    local tool="${entry%%:*}"
    local expected="${entry##*:}"
    local installed
    installed="$(get_installed_version "$tool")"

    local status
    if [[ "$installed" = "(not found)" ]]; then
      status="MISSING"
    elif [[ "$installed" = "$expected" ]]; then
      status="ok"
    else
      status="MISMATCH"
    fi

    printf "%-14s %-14s %-14s %s\n" "$tool" "$expected" "$installed" "$status"
  done
```

**Secondary table pattern** (L828-840) — the prerequisites block; `doctor` should follow this shape for its
PATH-membership report:

```bash
  # Also check prerequisites
  echo "Prerequisites"
  echo "-------------"
  for prereq in git curl python3 node npm terraform; do
    if command -v "$prereq" > /dev/null 2>&1; then
      local ver
      ver="$("$prereq" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1)" || ver="(found)"
      printf "%-14s %s\n" "$prereq" "$ver"
    else
      printf "%-14s %s\n" "$prereq" "(not found)"
    fi
  done
  echo ""
}
```

**Deltas required:**
- `run_doctor` must **hardcode the six tool names** and **not** call `ensure_versions_conf` — `doctor` needs
  names, not versions, and `ensure_versions_conf` (L224-236) fires 6 GitHub API calls when `versions.conf`
  is absent, inside the one subcommand that must stay offline.
- `run_doctor` must **not** `export PATH="$INSTALL_DIR:$PATH"` — that would mask the exact failure MAINT-03
  exists to detect. (`run_check` L798 also doesn't; that is Pitfall 5 and a separate judgment call.)
- Status vocabulary is different: `run_check` uses `MISSING`/`ok`/`MISMATCH`; `doctor` uses
  `NOT_ON_PATH`/`BROKEN`/`UNPARSEABLE`/`OK` (RESEARCH Pattern 5).

---

### `setup.sh :: tool_health()` (utility, transform) — NEW

**Primary analog for the capture step:** `ensure_pipx` L364 / L368 — the codebase's existing `set -e`-safe
way to run a command, keep its exit status, **and** capture its output:

```bash
  if pip_output="$(python3 -m pip install --user pipx 2>&1)"; then
    log "pipx installed successfully"
  else
    log "pip install failed (possibly PEP 668), retrying with --break-system-packages..."
```

Putting the command substitution in an `if` condition is `set -e`-safe with no toggling, and the branch *is*
the exit status. `run_check` L834 (`ver="$(...)" || ver="(found)"`) is the same idiom in `||` form. Prefer
either over a `set +e` / `rc=$?` / `set -e` bracket (a bracket leaves `-e` disabled if anything returns
between the toggles). The essential rule is unchanged: **capture before any pipe**, so `$?` is the tool's and
not `head`'s or `grep`'s.

**Secondary analog for the probe shape:** `is_installed` (L292-308) and `get_installed_version` (L310-326):

```bash
is_installed() {
  local tool="$1"
  local expected_version="$2"

  if ! command -v "$tool" > /dev/null 2>&1; then
    return 1
  fi

  local installed_version
  if [[ "$tool" = "gitleaks" ]]; then
    installed_version="$(gitleaks version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  else
    installed_version="$("$tool" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  fi

  [[ "$installed_version" = "$expected_version" ]]
}

get_installed_version() {
  local tool="$1"

  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "(not found)"
    return
  fi

  local version
  if [[ "$tool" = "gitleaks" ]]; then
    version="$(gitleaks version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  else
    version="$("$tool" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" || true
  fi

  echo "${version:-(unknown)}"
}
```

**COPY:**
- The `command -v "$tool"` presence gate (L296-298 / L313-316).
- **The gitleaks special case** (L301-305 / L319-323): gitleaks uses `gitleaks version`, every other tool
  uses `--version`. Any new probe must reproduce this branch or it will report gitleaks as broken.
- The `head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'` semver extraction — but run it on *captured output*,
  not inline in the same pipeline as the tool invocation.

**ANTI-PATTERN — the reason `doctor` needs its own function:** the `|| true` at **L302, L304, L320, L322**
discards the version command's own exit status, and L325's `${version:-(unknown)}` collapses "the binary is
broken" and "the output format changed" into one string. MAINT-03 asks specifically whether tools "can
execute their version command" — that is precisely the status these lines throw away.

`is_installed` is nevertheless the **only** trustworthy success signal for `update` (Pitfall 1) — reuse it
unchanged there; do not fork it.

---

### `setup.sh :: log_update_failure()` (utility, file-I/O) — NEW

**Analogs:** `write_config` (L519-531) for the write-to-`$target` shape; `print_summary` (L97-111) for the
plain-text column formatting D-07 asks to match.

```bash
write_config() {
  local target="$1" description="$2"

  if [[ -f "$target" ]]; then
    log "Exists, skipping: $target"
    return
  fi

  # Content is written by the caller via stdin
  cat > "$target"
  CONFIG_COUNT=$((CONFIG_COUNT + 1))
  log "Created: $target ($description)"
}
```

```bash
print_summary() {
  echo ""
  echo "Security Tool Installation Summary"
  echo "-----------------------------------"
  printf "%-14s %-12s %s\n" "Tool" "Version" "Status"
  printf "%-14s %-12s %s\n" "----" "-------" "------"
  printf "%b" "$RESULTS" | while IFS='|' read -r tool version status; do
    [[ -z "$tool" ]] && continue
    printf "%-14s %-12s %s\n" "$tool" "$version" "$status"
  done
  echo ""
  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    warn "$FAIL_COUNT tool(s) failed to install"
  fi
}
```

**COPY:** `local target="$1" ...` signature style; `printf "%-14s %-12s %s\n"` column widths; plain text, no
JSON (D-07).

**DELTA:** `write_config` **skips if the target exists** (L522-525) — the failure log must **append**
(`>> "$logfile"`), not skip. D-07 also places the log at `$REPO_ROOT` (the user's repo), not the script's
repo. **Never** write the GitHub token or a full curl command into it (RESEARCH V7 / Security Domain).

**Two flags for the planner, not decisions:**
1. `print_summary` hardcodes `"Security Tool Installation Summary"` (L99) and `"failed to install"` (L109).
   D-03 mandates reuse, but verbatim reuse under `update` produces misleading wording. Parameterizing the
   title/verb is a planner call.
2. `update-failures.log` at `$REPO_ROOT` will appear as untracked in the user's repo and be scanned by the
   gitleaks pre-commit hook (RESEARCH Open Q4).

---

### `setup.sh :: _install_precommit()` and `ensure_pipx()` — FIX IN PLACE

```bash
# shellcheck disable=SC2329  # invoked indirectly via run_installer
_install_precommit() {
  ensure_pipx
  pipx install "pre-commit==${PRECOMMIT_VERSION}"
}
```
(L413-417) — becomes `pipx install --force "pre-commit==${PRECOMMIT_VERSION}"` (RESEARCH Pitfall 1;
`--force` verified present in pipx 1.10.1). Single call site: `install_all_tools` L501, plus the new
`update` path.

```bash
    else
      err "Failed to install pipx. Install manually: https://pipx.pypa.io/stable/installation/"
      exit 1
    fi
```
(L370-373) — `exit 1` inside `ensure_pipx` kills the whole run from inside `_install_precommit`, violating
D-03. Change to `return 1` and let the caller's `|| true` + `is_installed` verification record it as a
normal failure. **Second-order effect:** this also converts `install`'s behaviour from hard-abort to
recorded-failure — consistent with every other tool there, but call it out in the plan.

Note the surrounding style to preserve: `log` for progress (verbose-only), `err` for the terminal message,
and the `# shellcheck disable=SC2034` at L363 for the assigned-but-unused `pip_output`.

---

### `setup.sh :: dispatcher + usage()` (route/config, event-driven) — EXTEND

**Analog:** L847-894, the only dispatcher in the file.

```bash
# Parse arguments
for arg in "$@"; do
  case "$arg" in
    install|configure|setup|check) COMMAND="$arg" ;;
    -v|--verbose) VERBOSE=true ;;
    -h|--help)    usage; exit 0 ;;
    *)            err "Unknown argument: $arg"; usage; exit 1 ;;
  esac
done

check_prerequisites

case "$COMMAND" in
  install)
    REPO_ROOT="$(pwd)"
    ensure_versions_conf "$REPO_ROOT"
    install_all_tools
    print_summary
    ;;
  configure)
    require_git_repo
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    ensure_versions_conf "$REPO_ROOT"
    generate_all_configs "$REPO_ROOT"
    ;;
  check)
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    ensure_versions_conf "$REPO_ROOT"
    run_check
    ;;
  setup)
    require_git_repo
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    ensure_versions_conf "$REPO_ROOT"
    install_all_tools
    print_summary
    generate_all_configs "$REPO_ROOT"
    activate_hooks "$REPO_ROOT"
    echo ""
    info "Setup complete. Run 'pre-commit run --all-files' to validate."
    ;;
esac

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
```

**Patterns to copy:**
- Two registration points: the L850 recognised-argument case **and** a new L859-888 branch. Plus the
  `usage()` heredoc (below).
- **`REPO_ROOT` derivation has three existing variants** — L861 bare `pwd` (install), L868
  `require_git_repo` + strict `git rev-parse` (configure/setup), L873 tolerant
  `git rev-parse --show-toplevel 2>/dev/null || pwd` (check). D-07 says the failure log goes to the repo
  `update` was run in, so the **L873 tolerant form** is the one to copy for `update`.
- **Single exit gate** (L890-894). Never call `exit 1` from inside a command branch — it would skip
  `print_summary` and the D-06 recheck.
- The `for arg` loop is **last-wins** — `setup.sh check update` silently runs only `update`. Pre-existing.
  If selective per-tool update is added (RESEARCH Open Q3), the `*)` catch-all at L853 must be taught to
  accept a bare tool name **only when `COMMAND=update`**.

**Design question to surface, not resolve:** `check_prerequisites` (L857) is a hard gate that `exit 1`s if
`git`, `curl` or `python3` is missing — and it runs *before* the command `case`. A health-check subcommand
that dies without printing anything when `python3` is absent is arguably the opposite of what `doctor` is
for. Whether `doctor` should bypass or soften that gate is a planner call.

**`usage()` heredoc to extend** (L55-72) — note the quoted `<<'USAGE'` delimiter and the 2-space
command-column alignment; documented invocation is `bash setup.sh`, never `./setup.sh` (CLAUDE.md
anti-slop: never set the executable bit / never rely on it):

```bash
usage() {
  cat <<'USAGE'
Usage: bash setup.sh [COMMAND] [OPTIONS]

Bootstrap a repository with the OCC security workstation stack.
Run from inside any git repository.

Commands:
  setup       Full setup: install tools + generate configs + activate hooks (default)
  install     Install security CLI tools only
  configure   Generate configuration files only (skip tool installation)
  check       Show installed vs expected versions for all tools

Options:
  -v, --verbose    Show detailed progress output
  -h, --help       Show this help message and exit
USAGE
}
```

The same command list is duplicated in the file-header comment block at **L12-18** — update both.

---

### `setup.sh :: Constants block` — EXTEND

**Analog:** L24-49

```bash
INSTALL_DIR="$HOME/.local/bin"
VERBOSE=false
COMMAND="setup"
RESULTS=""
FAIL_COUNT=0
CONFIG_COUNT=0

GITHUB_API="https://api.github.com/repos"

# Tool GitHub repositories (for version resolution)
# Plain variables for bash 3.2 compatibility (no associative arrays)
REPO_PRECOMMIT="pre-commit/pre-commit"
REPO_TRIVY="aquasecurity/trivy"
...
```

New constants (`GITHUB_TOKEN_VALUE`, `UPDATE_LOG_NAME`, and any `CHECK_PROBLEM_COUNT`) go here, following
the same flat-variable convention. **L33-34's comment is the bash-3.2 rationale to cite** when the plan
explains why no associative array is used.

**`CONFIG_COUNT` is the in-codebase analog for RESEARCH Open Q2's proposed `CHECK_PROBLEM_COUNT`:** declared
at L29 beside `FAIL_COUNT`, incremented at L529 and L670, read only for reporting at L761-764 — and
deliberately **not** wired into the L890 exit gate. That is exactly the "second counter that reports but does
not drive the exit code" shape the planner needs for `check`/`doctor`. Copy it rather than inventing one.

---

### `tests/` — new test units

**Closest analog:** `repos/terraform-pipelines/tests/test-terraform.sh` (450 lines, plain bash, sibling repo).
There is **no test of any kind** under `repos/security-platform/` — no `tests/` directory, no `.bats` file.
Grep confirms `test-terraform.sh` contains **no bash-4 constructs** (`declare -A`, `mapfile`, `readarray`,
`local -n`, `${v,,}`), so its idioms are safe to copy under the bash 3.2 constraint.

**Copy the counter/summary STRUCTURE** (test-terraform.sh L40-70):

```bash
# Counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

print_success() {
    echo -e "${GREEN}  pass  $1${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
}

print_warning() {
    echo -e "${YELLOW}  warn  $1${NC}"
    WARN_COUNT=$((WARN_COUNT + 1))
}

print_error() {
    echo -e "${RED}  FAIL  $1${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}
```

and its summary + exit gate (L443-450):

```bash
echo ""
echo -e "${GREEN}  Results: ${PASS_COUNT} passed, ${WARN_COUNT} warnings, ${FAIL_COUNT} failed${NC}"

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
```

**Adopt `setup.sh`'s STYLE, not terraform-pipelines'.** Concrete deltas:

| Aspect | test-terraform.sh | Match `setup.sh` instead |
|--------|-------------------|--------------------------|
| Shebang | `#!/bin/bash` | `#!/usr/bin/env bash` (setup.sh L1; `cicd/lint-markdown.sh` L1 agrees — but note `cicd/pre-commit.sh` L1 uses `#!/bin/bash`, so this is "match setup.sh", not a repo-wide invariant) |
| Indent | 4 spaces | 2 spaces |
| Color | ANSI `RED`/`GREEN`/`YELLOW` | none — `setup.sh` uses plain `==> ` / `ERROR: ` / `WARNING: ` prefixes (L74-90) |
| Repo root | `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"` | same idiom, verified in `workstation/cicd/pre-commit.sh` L7 and `cicd/lint-markdown.sh` L19 — **copy this for locating `setup.sh` from `tests/`** |
| Arg parsing | `while [[ $# -gt 0 ]]; do case "$1" ...` (lint-markdown.sh L24-31) | either that or setup.sh's `for arg in "$@"` — lint-markdown's `while`/`shift` form is the better fit for a test runner taking flags |

**Header-comment convention** — both same-repo scripts open with a purpose block plus a `# Usage:` list of
`bash <path> ...` invocations (`lint-markdown.sh` L4-17, `setup.sh` L4-18). New test scripts should match.

**bats vs plain bash — a finding, not a decision.** The codebase has **zero** `.bats` files and exactly one
plain-bash harness. `tests/smoke.sh` therefore has an analog; `.bats` has none and would make `bats` a new
(undeclared) dev dependency absent from `check_prerequisites` (L125-145). RESEARCH lists both options.
Planner decides.

**Fixture files** (`tests/fixtures/*.json`) have **no analog** — no fixture directory exists anywhere in
`repos/security-platform/`. Use **truncated** samples, not raw captures: RESEARCH measured the real bodies at
619 KB (hadolint) and 2.4 MB (gitleaks). A handful of release objects is enough, provided each preserves its
source formatting — one compact (`"tag_name":"v2.15.1"`), one spaced (`"tag_name": "v8.30.1"`). That contrast
*is* the Pitfall 2 regression guard. Note the repo's gitleaks pre-commit hook will scan whatever lands in
`tests/fixtures/`.

**Sourceability blocker:** `setup.sh` is `set -euo pipefail` with all dispatch at file scope, so it **cannot
be sourced** for unit testing today — sourcing runs `check_prerequisites` and the dispatcher. The
`[[ "${BASH_SOURCE[0]}" == "${0}" ]]` main-guard around L847-894 has **no analog in this codebase**; take the
idiom from RESEARCH (Validation Architecture).

---

## Shared Patterns

### Logging / output selection
**Source:** `setup.sh` L74-90
**Apply to:** every new function

```bash
log() {
  if [[ "$VERBOSE" = true ]]; then
    echo "==> $*"
  fi
}

info() {
  echo "==> $*"
}

err() {
  echo "ERROR: $*" >&2
}

warn() {
  echo "WARNING: $*" >&2
}
```

`log` = verbose-only progress; `info` = always-on stdout milestone; `warn`/`err` = **stderr**. No color codes
anywhere in this script. New code must pick the right one — e.g. per-tool "Updating X" is `info`, "already
current" is `log`, an unresolvable fallback is `warn`.

### Result accumulation
**Source:** `setup.sh` L92-95
**Apply to:** `update_all_tools`, `update_one_tool` (D-03 mandates reuse)

```bash
add_result() {
  local tool="$1" version="$2" status="$3"
  RESULTS="${RESULTS}${tool}|${version}|${status}\n"
}
```

Pipe-delimited accumulation into a single `RESULTS` string (not an array — bash 3.2), consumed by
`print_summary`'s `printf "%b" "$RESULTS" | while IFS='|' read -r ...` at L103.

### Indirect-invocation shellcheck directive (Chesterton's Fence)
**Source:** `setup.sh` L117, L242, L251, L260, L267, L274, L281, L328, L354, L413, L419, L424, L429, L434, L464
**Apply to:** every new function invoked indirectly (via `run_installer "$@"`, `eval`, or the dispatcher)

```bash
# shellcheck disable=SC2329  # invoked indirectly via run_installer
_install_trivy() {
```
```bash
# shellcheck disable=SC2329  # invoked from main case statement
require_git_repo() {
```

These exist because shellcheck cannot see indirect calls. New indirectly-invoked functions need the same
directive with a matching justification comment. **Do not remove existing ones.**

### `set -e`-safe call convention for anything touching the network
**Source:** `setup.sh` L187-192 (and L536-542, `resolve_hook_versions`)
**Apply to:** every call to `resolve_latest_version`, `resolve_latest_in_major`, `gh_api_get`

`x=$(fn ...) || x="default"` — never a bare assignment. `set -e` is suppressed for all but the last command
of an `||` list, and that suppression propagates into the function body. A bare assignment kills the script
on a no-match `grep` (empty 403 body) or a SIGPIPE. **13 existing call sites already follow this**; keep them
working unchanged when hardening `resolve_latest_version`.

### Command-status capture under `set -e`
**Source:** `setup.sh` L364 / L368 (`if pip_output="$(...)"; then`) and L834 (`ver="$(...)" || ver="(found)"`)
**Apply to:** `tool_health`, and anywhere the *exit status* of a probed command matters.

Capture the substitution inside an `if` condition or an `||` list. Never toggle `set +e` / `set -e`, and
never pipe the invocation directly into `head`/`grep` when you need `$?` — parse the captured string
afterwards.

### Prerequisites gate (the "auth/guard" equivalent)
**Source:** `setup.sh` L125-145, invoked unconditionally at L857 before the command `case`

```bash
check_prerequisites() {
  local missing=()

  if ! command -v git > /dev/null 2>&1; then
    missing+=("git")
  fi
  ...
  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing required tools: ${missing[*]}"
    err "Install them before running setup."
    exit 1
  fi

  log "Prerequisites satisfied: git, curl, python3"
}
```

`update` and `doctor` inherit this automatically (it runs before the dispatcher) — see the `doctor` design
question above. If `bats` becomes a declared dev dependency, this is where it would be registered; it
currently is **not**.

The second guard, `require_git_repo` (L117-123), is opt-in per branch — used by `configure` and `setup`, not
by `check`. `update`'s D-07 log needs a repo root but the tolerant L873 form covers the non-repo case.

### GitHub authentication (new, no in-repo analog)
**Source:** RESEARCH Pattern 4 / Example 1 — no existing analog; `resolve_latest_version` is unauthenticated
**Apply to:** `gh_api_get`, therefore every API call

Token from `GITHUB_TOKEN` → `GH_TOKEN` → `gh auth token`, sent as an `Authorization: Bearer` **header only**
— never in the URL, never echoed in verbose mode, never written to the D-07 log. Verified: 60/hr → 5000/hr.

### Validation / integrity
**Source:** `setup.sh` L328-348 (`verify_sha256`), used by `_install_gitleaks` L458 and `_install_hadolint` L490
**Apply to:** all `update` install paths — by **reusing `_install_*` rather than reimplementing**, `update`
inherits SHA-256 verification for free. Never add an update path that bypasses `_install_*`.

The input-validation counterpart is the `^[0-9]+\.[0-9]+\.[0-9]+$` filter in `resolve_latest_in_major`: it is
a **security control**, not just correctness — it stops an arbitrary `tag_name` reaching a download URL or a
`pipx install` spec. Do not relax it.

### Temp-file handling
**Source:** `setup.sh` L446-447 and L478-479

```bash
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/gitleaks.XXXXXX")"
  trap 'rm -rf "$tmpdir"' RETURN
```

Apply to any new temp usage, including test fixtures / scratch `versions.conf` files.

### Single exit gate
**Source:** `setup.sh` L890-894 — `if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi; exit 0`
**Apply to:** D-08. Set `FAIL_COUNT`; never `exit` from inside a command branch.

---

## No Analog Found

| Unit | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `main`-guard (`[[ "${BASH_SOURCE[0]}" == "${0}" ]]`) around setup.sh L847-894 | config | — | No script in the codebase is written to be sourceable; every one executes at file scope. Use the idiom from RESEARCH (Validation Architecture) |
| `gh_api_get()`'s **auth header** (function shape itself has a partial analog) | utility | request-response | No existing GitHub call in the codebase is authenticated — `resolve_latest_version` L156/L163 uses bare `curl -sf`. Use RESEARCH Example 1 |
| `tests/fixtures/*.json` (×2) | fixture | file-I/O | No fixture directory or recorded-response file exists anywhere under `repos/security-platform/` |
| `.bats` test files (if chosen over `tests/smoke.sh`) | test | batch | Zero `.bats` files in the codebase; `bats` is installed on this machine but is not a declared prerequisite |
| Semver ordering inside `resolve_latest_in_major` | utility | transform | No semver comparison exists in the codebase today. Use `sort -t. -k1,1n -k2,2n -k3,3n \| tail -1` from RESEARCH Example 2 (POSIX field-sort, not `sort -V`) |

---

## Explicit Anti-Patterns (present in the analogs — do NOT copy forward)

| Location | What | Why not |
|----------|------|---------|
| L157, L159, L164, L166 | Space-dependent `'"tag_name": "..."'` grep/sed | Returns empty for hadolint's compact JSON (RESEARCH Pitfall 2) |
| L158, L165 | `head -1` terminating a curl pipeline | SIGPIPE 141 under `set -euo pipefail` (Pitfall 3) |
| L395, L403 | Branching on the installer's exit code | `pipx install` exits 0 while doing nothing (Pitfall 1) |
| L302, L304, L320, L322 | `\|\| true` swallowing the version command's exit status | Discards exactly what MAINT-03 must report (Pattern 5) |
| L372 | `exit 1` inside `ensure_pipx` | Aborts the whole `update` run, violating D-03 |
| L416 | bare `pipx install "pre-commit==X"` | Cannot upgrade; needs `--force` |
| L187-192 | Silent `\|\| "hardcoded-default"` | Violates CLAUDE.md anti-slop ("let it crash" / no silent fallbacks). New `\|\| default` must be paired with a visible `warn` |
| L511 | `warn "... Add to your shell profile:"` with nothing after the colon | Truncated user guidance; fix while in the neighbourhood |
| Anywhere | `declare -A`, `local -n`, `mapfile`, `${v,,}` | bash 4+. Target is `/bin/bash` 3.2.57 (L33-34 comment records this constraint) |
| Anywhere | Adding a `jq` dependency | Deliberate zero-dependency posture from Phase 10 |

---

## Open Questions — the analog each resolution would copy

These are **not** resolved here (RESEARCH Open Q1-5 leaves them to the planner). Listed with the pattern each
branch would need:

| Open Q | If resolved toward… | Copy from |
|--------|--------------------|-----------|
| Q1 fallback status | `fallback` as a 4th status, no `FAIL_COUNT` bump | `add_result` status strings L389 / L396 / L399 |
| Q1 fallback status | auto-write resolved version into `versions.conf` | `generate_versions_conf` L194-217 heredoc (**and lift the read-only marking above**) |
| Q2 exit contract | separate non-exit-driving counter | `CONFIG_COUNT` L29 / L529 / L670 / L761-764 |
| Q2 exit contract | `check` drives the exit code | `FAIL_COUNT` + L890-894 gate |
| Q3 selective update | `setup.sh update trivy` | `for arg` / `case` L848-855 (`*)` catch-all at L853 must change) |
| Q4 `.gitignore` | add `update-failures.log` | `repos/security-platform/.gitignore` comment-section style (`# OS`, `# Python`, `# pre-commit`) |
| Q5 fix `install`'s pipx bug here | yes | L413-417 + L370-373, as detailed above |
| ADR needed? | append a new record | `docs/adr/adr014-cosign-slsa-kyverno.md` header block (`# ADR-0NN: Title` / `**Status:**` / `**Date:**` / `**Addresses:**`) + a new row in `docs/adr/README.md` (see L22-24 format). **Append-only — never edit ADR-001..014.** |

---

## Metadata

**Analog search scope:**
- `repos/security-platform/workstation/` (setup.sh, cicd/, README.md, ARCHITECTURE.md)
- `repos/security-platform/` (versions.conf, .gitignore, .pre-commit-config.yaml)
- `repos/terraform-pipelines/tests/` and `repos/terraform-pipelines/examples/cicd/` (only shell test harnesses in the tree)
- `docs/adr/`, `.planning/ROADMAP.md` (this repo)
- Whole-tree `find` for `*.bats`, `test_*.sh`, `*_test.sh`, `smoke*.sh`, `*.sh` (excluding `node_modules` / `.git`)

**Files scanned:** 894-line `setup.sh` (read in full), `cicd/pre-commit.sh` (19), `cicd/lint-markdown.sh` (61),
`tests/test-terraform.sh` (450 — targeted reads + bash-4ism grep), `versions.conf`, `.gitignore`,
plus heading-level scans of `workstation/README.md`, `workstation/ARCHITECTURE.md`, `docs/adr/README.md`.

**Verification performed:** `grep -nE 'declare -A|mapfile|readarray|local -n|\$\{[a-zA-Z_]+,,\}'` on
`test-terraform.sh` → no matches (bash 3.2 safe). `grep -n CONFIG_COUNT` on setup.sh → L29, 529, 670, 761, 764
(confirmed not wired to the exit gate).

**Pattern extraction date:** 2026-09-09
