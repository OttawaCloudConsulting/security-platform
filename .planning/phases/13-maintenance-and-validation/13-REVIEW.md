---
phase: 13-maintenance-and-validation
reviewed: 2026-09-09T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - repos/security-platform/.gitignore
  - repos/security-platform/workstation/ARCHITECTURE.md
  - repos/security-platform/workstation/README.md
  - repos/security-platform/workstation/setup.sh
  - repos/security-platform/workstation/tests/fixtures/gitleaks-releases-spaced.json
  - repos/security-platform/workstation/tests/fixtures/hadolint-releases-compact.json
  - repos/security-platform/workstation/tests/run-tests.sh
  - repos/security-platform/workstation/tests/test_doctor.sh
  - repos/security-platform/workstation/tests/test_smoke.sh
  - repos/security-platform/workstation/tests/test_update_fallback.sh
  - repos/security-platform/workstation/tests/test_update_primitives.sh
  - repos/security-platform/workstation/tests/test_version_resolution.sh
findings:
  critical: 0
  warning: 8
  info: 3
  total: 11
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-09-09T00:00:00Z
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

`setup.sh` is a large, carefully-commented bash bootstrap script with a genuinely
good test suite (`tests/test_*.sh`) exercising most of the update/doctor/version-
resolution state machine offline via stubs. No critical (data-loss, RCE-on-attacker-
input, auth-bypass) defects were found in the reviewed logic — the `eval` in
`attempt_install` and the version strings pulled from the GitHub API are contained
by the extraction regex (no embedded `"` can survive into the eval'd string), and
the doctor/check/update commands' exit-code contracts match their own tests and the
documentation in `ARCHITECTURE.md`/`README.md`.

I initially suspected the `hadolint`/`gitleaks` OS/arch name mapping (`get_hadolint_os`,
`get_gitleaks_os`) was wrong (lowercase `macos`/`linux` vs. the `Darwin`/`Linux` that
`uname -s` and hadolint's own README curl example use). I verified this against the
live GitHub release asset URLs before writing it up:

```
macos-x86_64: 200   Darwin-x86_64: 404   linux-x86_64: 200   Linux-x86_64: 200
macos-arm64:  200   macos-aarch64: 404
gitleaks darwin_x64: 200   gitleaks darwin_arm64: 200
```

The script's mapping (`macos`/`linux`, `x86_64`/`arm64`) is correct — my initial recall
was wrong. No finding is recorded for this; it is noted here only so the check isn't
silently re-litigated later.

What remains are real correctness gaps in the install/update paths (an unreachable
PATH warning, an inconsistent success-detection strategy between `install` and
`update` for the exact same installers) and one real security asymmetry (three of
six tools are installed via `curl | sh` from an unpinned `main` branch with no
integrity check, while the other three get SHA-256 verification), plus a few
test-portability and documentation gaps.

## Warnings

### WR-01: PATH warning in `install_all_tools`/`update_all_tools` can never fire

**File:** `repos/security-platform/workstation/setup.sh:837-858` and `:860-906`
**Issue:** Both functions do:
```bash
mkdir -p "$INSTALL_DIR"
export PATH="$INSTALL_DIR:$PATH"
...
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    warn "$INSTALL_DIR is not in your PATH. Add to your shell profile:"
    ...
esac
```
`$INSTALL_DIR` is prepended onto `$PATH` immediately before the check that tests
whether `$INSTALL_DIR` is in `$PATH`. The condition is therefore always true and the
warning can never print from `install`/`setup`/`update` — a user whose shell profile
genuinely lacks `~/.local/bin` gets no warning from the commands most likely to be
their first run, and only discovers the problem later via `doctor` (which correctly
does not export PATH first).
**Fix:** Snapshot the PATH before mutating it and test that:
```bash
local orig_path="$PATH"
export PATH="$INSTALL_DIR:$PATH"
...
case ":$orig_path:" in
  *":$INSTALL_DIR:"*) ;;
  *) warn "..." ;;
esac
```

### WR-02: `run_installer` (install path) trusts installer exit code; `attempt_install` (update path) explicitly refuses to, for the same installers

**File:** `repos/security-platform/workstation/setup.sh:578-606` (`run_installer`) vs `:690-724` (`attempt_install`)
**Issue:** `attempt_install`'s own comment block states the success criterion must be
"decided solely by re-probing the installed version afterward — never by the
installer's own exit code," citing the verified case that `pipx install` on an
already-installed package exits 0 while changing nothing. `run_installer` — used by
`bash setup.sh install` and `bash setup.sh setup`, calling the exact same
`_install_precommit`/`_install_trivy`/etc. functions — does the opposite:
```bash
if "$@"; then
  add_result "$name" "$version" "installed"
else
  ...
fi
```
This means the pipx no-op failure mode that `update` was specifically hardened
against is still live on the `install`/`setup` path: a `pre-commit==X` version
mismatch that pipx silently no-ops on will be reported as `installed` by `setup.sh
install` even though the wrong version remains on disk.
**Fix:** After the installer call, gate success on `is_installed "$name" "$version"`
(mirroring `attempt_install`), not on the installer's own exit status.

### WR-03: Trivy/Syft/Grype installed via `curl | sh` from an unpinned `main` branch, with no integrity check

**File:** `repos/security-platform/workstation/setup.sh:340-342` (URLs in the `versions.conf` template) and `:615-627` (`_install_trivy`, `_install_syft`, `_install_grype`)
**Issue:**
```
TRIVY_INSTALL_URL="https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh"
SYFT_INSTALL_URL="https://raw.githubusercontent.com/anchore/syft/main/install.sh"
GRYPE_INSTALL_URL="https://raw.githubusercontent.com/anchore/grype/main/install.sh"
```
```bash
_install_trivy() {
  curl -sfL "$TRIVY_INSTALL_URL" | sh -s -- -b "$INSTALL_DIR" "v${TRIVY_VERSION}"
}
```
These fetch a shell script from the `main` branch (not a tagged/pinned commit) and
pipe it directly to `sh` with no checksum or signature verification. Compare this to
the same file's own treatment of Gitleaks and hadolint (`:630-688`), where the binary
download is followed by an explicit SHA-256 checksum comparison against a
release-published checksums file (`verify_sha256`). If `main` on any of these three
upstream repos is compromised (or a CDN/cache-poisoning attack serves stale/malicious
content from `raw.githubusercontent.com`), every workstation that runs `setup.sh
install`/`setup`/`update` executes arbitrary code as the invoking user. This is a
real asymmetry the codebase already demonstrates it knows how to close (for the
other two tools) but did not apply here.
**Fix:** Pin the install script URL to a specific tag or commit SHA (re-resolved
alongside the tool version), or fetch + checksum the script before executing it,
rather than trusting `main` at request time.

### WR-04: `versions.conf` is sourced as executable shell with no format validation

**File:** `repos/security-platform/workstation/setup.sh:356-368` (`ensure_versions_conf`)
**Issue:** `. "$versions_file"` executes the contents of `versions.conf` as bash. A
hand-edited or tampered `versions.conf` in a cloned repository is therefore a
code-execution surface (comparable to a Makefile or a `.pre-commit-config.yaml`
`local` hook, but less obviously so to a reviewer scanning for "config files").
Additionally, none of the `*_VERSION` values are validated against a version-string
shape before being used to build download URLs / `pipx install` specs / eval'd
`attempt_install` calls — the current safety net (that `resolve_latest_version`'s own
extraction regex cannot produce an embedded `"`) is real but implicit: nothing in the
test suite asserts it, and it does not protect a manually-edited `versions.conf`,
which is a supported workflow per `README.md`'s "or edit `versions.conf` manually to
pin a specific version."
**Fix:** Validate each `*_VERSION` value against a strict `^[0-9]+(\.[0-9]+)*$`
pattern immediately after sourcing `versions.conf` (or write a minimal key=value
parser instead of `source`), and fail with a clear error rather than propagating an
unvalidated string into `eval`/URLs/`pipx install`.

### WR-05: No request timeout on GitHub API calls

**File:** `repos/security-platform/workstation/setup.sh:222-242` (`gh_api_get`)
**Issue:** `curl_args=(-sf -H "X-GitHub-Api-Version: 2022-11-28")` — no `--max-time`
or `--connect-timeout`. A hung TCP connection (dead network, captive portal,
firewall black-holing the connection) will block `setup.sh` indefinitely on `install`,
`configure`, `setup`, `check`, and `update`, with no way for a scripted/CI caller to
bound the wait.
**Fix:** Add `--max-time 15 --connect-timeout 5` (or similar) to `curl_args`.

### WR-06: `versions.conf` and hand-edits are not validated before use, risking a `set -u` crash mid-run

**File:** `repos/security-platform/workstation/setup.sh:1191-1236` (`run_check`), `:1358-1416` (`main` dispatch)
**Issue:** If a user hand-edits `versions.conf` (a documented, supported workflow —
see `README.md` "Tool Versions") and removes or misnames one of the six `*_VERSION`
assignments, every code path that references that variable (`run_check`'s `tools=(...)`
array, `update_all_tools`'s `records=(...)` array, `_install_*` functions) fails with
bash's generic `set -u` "unbound variable" error instead of the script's own
`err`/`warn` helpers, mid-table, after partial output has already been printed.
**Fix:** After sourcing `versions.conf`, explicitly check that all six expected
variables are set and non-empty, and exit with a clear, actionable error naming the
missing variable if not.

### WR-07: Dead code with an inaccurate justification comment (`detect_os`/`detect_arch`)

**File:** `repos/security-platform/workstation/setup.sh:374-390`
**Issue:**
```bash
# shellcheck disable=SC2329  # invoked by install functions
detect_os() { ... }
# shellcheck disable=SC2329  # invoked by install functions
detect_arch() { ... }
```
`grep -n "detect_os\|detect_arch"` over the file shows only these two definitions —
neither function is called anywhere in `setup.sh`. The `_install_*` functions use
`get_gitleaks_os`/`get_gitleaks_arch`/`get_hadolint_os`/`get_hadolint_arch` instead,
and Trivy/Syft/Grype's official install scripts do their own OS/arch detection
internally. The `shellcheck disable` comment's stated justification ("invoked by
install functions") is false, which will mislead the next person who edits this file
into believing removing it is unsafe when it is actually unreferenced.
**Fix:** Remove `detect_os`/`detect_arch`, or if they are meant as a currently-unused
public utility, correct the comment and add an actual call site.

### WR-08: `test_doctor.sh` hardcodes macOS-specific version strings and paths, making the suite fail (or false-pass in a misleading way) on Linux

**File:** `repos/security-platform/workstation/tests/test_doctor.sh:68-74, 93-99`
**Issue:** `ARCHITECTURE.md`/`README.md` both state the workstation stack targets
"both macOS and Linux," but:
```bash
ln -s /bin/bash "$scratch/syft"
...
assert_contains "$out" "3.2.57" "a healthy tool's record carries its parsed N.N.N version"
```
hardcodes `3.2.57`, which is specifically macOS's shipped `/bin/bash` version. On any
Linux CI runner or developer machine (bash 5.x is standard), this assertion fails
even though `tool_health` itself is working correctly — a false failure, not a real
one, but one that will train contributors to ignore `test_doctor.sh` failures on
Linux. The companion assertion at line 98-99 (`assert_not_contains "$out" "3.2.57"`)
is coupled to the same hardcoded constant and has the same portability problem.
**Fix:** Derive the expected version from the running interpreter, e.g.
`bash_ver=$(/bin/bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')`, and
assert against `$bash_ver` instead of the literal `3.2.57`.

## Info

### IN-01: README instructs users to gitignore `update-failures.log` in *their* repo, but `configure`/`setup` never adds it

**File:** `repos/security-platform/workstation/README.md:230-240`; `repos/security-platform/workstation/setup.sh:1142-1159` (`generate_all_configs`)
**Issue:** The README tells the user to manually add `update-failures.log` to the
target repository's `.gitignore` after running `update` for the first time. Since
`setup.sh` already generates several dotfiles in the target repo root
(`generate_all_configs`), it would be straightforward — and more idempotent-by-default
in spirit with the rest of the tool — to also ensure `update-failures.log` is
gitignored (e.g. append the line to `.gitignore` if not already present) rather than
relying on the user to remember a manual step documented only in prose.
**Fix:** Add a small step to `generate_all_configs` (or a dedicated helper) that
appends `update-failures.log` to the target repo's `.gitignore` if the line is not
already present.

### IN-02: `find . -name 'update-failures.log'` in a log-related test can false-positive from repo state outside the test's own sandbox

**File:** `repos/security-platform/workstation/tests/test_update_primitives.sh:195-208`
**Issue:**
```bash
stray=$(find . -name 'update-failures.log' -not -path './node_modules/*' 2>/dev/null)
assert_eq "" "$stray" "running the log tests leaves no update-failures.log anywhere under the working directory"
```
searches from the test runner's current working directory rather than being scoped
to the test's own `mktemp` sandbox. If `bash setup.sh update` has ever been run for
real from (or above) that working directory and legitimately failed once, leaving a
tracked-but-gitignored `update-failures.log` in the tree (exactly the scenario the
project's own `.gitignore` anticipates), this assertion produces a false failure
unrelated to the code under test.
**Fix:** Scope the `find` to the test's own `mktemp` sandbox directory, or to
`$TESTS_DIR`/`$WORKSTATION_DIR` explicitly rather than `.`.

### IN-03: Hardcoded fallback tool/hook versions will silently go stale

**File:** `repos/security-platform/workstation/setup.sh:319-324` (tool fallbacks), `:929-935` (hook fallbacks)
**Issue:** Every `resolve_latest_version` call site has a hardcoded fallback (e.g.
`trivy_ver=$(resolve_latest_version "$REPO_TRIVY") || trivy_ver="0.69.3"`) used when
the GitHub API is unreachable or rate-limited. These are point-in-time snapshots that
will drift further from "latest" every month with no mechanism to flag that drift —
a user on a rate-limited/air-gapped network will silently get an increasingly old
version with no warning that a fallback (rather than a resolved version) was used.
**Fix:** Not a required fix, but consider having `generate_versions_conf` annotate
the generated file when a fallback constant (vs. a live-resolved version) was used,
so the drift is at least visible to the user at generation time.

---

_Reviewed: 2026-09-09T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
