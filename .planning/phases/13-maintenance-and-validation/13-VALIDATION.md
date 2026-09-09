---
phase: 13
slug: maintenance-and-validation
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-09
updated: 2026-09-09
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Updated by the planner to match the final 7-plan structure.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Plain-bash harness at `repos/security-platform/workstation/tests/run-tests.sh`, created by plan 01. **`bats` was evaluated and rejected** — it has zero analog in the codebase and would become an undeclared dev dependency absent from `check_prerequisites`. The only shell test harness in the tree (`repos/terraform-pipelines/tests/test-terraform.sh`) is plain bash, and its counter/summary structure is the analog copied. |
| **Config file** | none — the runner glob-sources every `tests/test_*.sh`, so adding a case file requires no runner edit |
| **Quick run command** | `/bin/bash -n repos/security-platform/workstation/setup.sh && shellcheck repos/security-platform/workstation/setup.sh` |
| **Full suite command** | `bash repos/security-platform/workstation/tests/run-tests.sh` (includes syntax, shellcheck, sourceability, and all unit/integration cases) |
| **Estimated runtime** | < 5s — the suite makes **zero network calls** and installs nothing |

---

## Sampling Rate

- **After every task commit:** `/bin/bash -n setup.sh && shellcheck setup.sh` (sub-second, no network)
- **After every plan:** `bash tests/run-tests.sh` + `bash setup.sh check` + `bash setup.sh --help`
- **Before `/gsd:verify-work`:** full suite green, plus plan 07's `checkpoint:human-verify`
- **Max feedback latency:** 20 seconds

---

## Test Isolation Strategy (planner decision)

The research draft proposed integration tests driven by an "impossible pin" scratch `versions.conf`
plus a live `update trivy` run. That is **not** an automated test: it downloads a real binary into
`~/.local/bin`, burns a live API call against a 60/hr budget, and is non-deterministic.

The main-guard added in plan 01 exists precisely so tests can do this instead: **source `setup.sh`,
then redefine the boundary functions.** Every test subshell stubs some combination of:

| Boundary | Stub |
|----------|------|
| network | `gh_api_get() { cat "$FIXTURES_DIR/<fixture>.json"; }` |
| version resolution | `resolve_latest_in_major() { echo "$STUB_FALLBACK"; }` |
| installers | `_install_stub() { return 1; }` / `_install_stub_ok() { return 0; }` |
| success verification | `is_installed() { [[ "$2" = "$STUB_INSTALLED_VERSION" ]]; }` |
| filesystem | `REPO_ROOT="$(mktemp -d)"` and `INSTALL_DIR="$(mktemp -d)"`, cleaned via `trap ... RETURN` |
| doctor probes | symlinks — `ln -s /usr/bin/false scratch/trivy` → `BROKEN`, `ln -s /usr/bin/true scratch/grype` → `UNPARSEABLE` |

**Doctor stubs must be symlinks, never `chmod +x` files.** The anti-slop rule forbids setting the
executable bit, and a `chmod 000` file is invisible to `command -v` — it would report `NOT_ON_PATH`
instead of `BROKEN`, silently asserting the wrong thing.

**Token-hygiene tests use the literal `NOT-A-REAL-TOKEN-TEST`**, never a realistically-shaped
`ghp_`-prefixed string, because the repo's own gitleaks pre-commit hook scans `tests/`.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | MAINT-01/02/03 | T-13-09 | `setup.sh` sourceable without executing `check_prerequisites` or the dispatcher | syntax | `/bin/bash -c 'source setup.sh'` produces no output; all 4 existing subcommands unchanged | ⬜ plan 01 creates | ⬜ pending |
| 13-01-02 | 01 | 1 | MAINT-01/02/03 | T-13-01, T-13-08 | Test harness + both GitHub JSON style fixtures exist; no executable bit set | harness | `bash tests/run-tests.sh` | ⬜ plan 01 creates | ⬜ pending |
| 13-02-01 | 02 | 2 | MAINT-01 | T-13-03, T-13-11 | Token sent as header only, resolved lazily, never in a URL or output | unit | `bash tests/run-tests.sh` (stubbed curl argv capture) | ⬜ plan 02 creates | ⬜ pending |
| 13-02-02 | 02 | 2 | MAINT-01/02 | T-13-05, T-13-10 | Compact AND spaced JSON both parse; empty body warns and does not kill the shell | unit | `bash tests/run-tests.sh` (fixture-driven) | ⬜ plan 02 creates | ⬜ pending |
| 13-02-03 | 02 | 2 | MAINT-02 | T-13-01 | `resolve_latest_in_major` returns highest non-prerelease in major, numerically ordered | unit | `bash tests/run-tests.sh` (fixture-driven) | ⬜ plan 02 creates | ⬜ pending |
| 13-03-01 | 03 | 3 | MAINT-02 | T-13-12, T-13-13 | `pipx install --force` present; no `exit` inside `ensure_pipx`/`_install_*` | static | `grep` criteria + `shellcheck` | ⬜ plan 03 | ⬜ pending |
| 13-03-02 | 03 | 3 | MAINT-02 | T-13-12 | Success decided by `is_installed`, never the installer exit code (pipx no-op regression) | unit | `bash tests/run-tests.sh` (stubbed installer/verifier) | ⬜ plan 03 creates | ⬜ pending |
| 13-03-03 | 03 | 3 | MAINT-02 | T-13-03, T-13-14 | Failure log appends plain text, contains no token, written under a `mktemp -d` in tests | unit | `bash tests/run-tests.sh` | ⬜ plan 03 creates | ⬜ pending |
| 13-04-01 | 04 | 4 | MAINT-02 | T-13-01, T-13-04 | Two-attempt sequence; fallback status does not bump `FAIL_COUNT`; downgrade refused | integration | `bash tests/run-tests.sh` (fully stubbed) | ⬜ plan 04 creates | ⬜ pending |
| 13-04-02 | 04 | 4 | MAINT-02 | T-13-15 | One failing tool does not stop the loop; selective per-tool targeting works | integration | `bash tests/run-tests.sh` | ⬜ plan 04 creates | ⬜ pending |
| 13-04-03 | 04 | 4 | MAINT-02 | T-13-16 | `update` in help; unknown token still errors; exit 1 on double failure | smoke | `bash setup.sh --help \| grep -q update`; `bash setup.sh update bogus-tool; echo $?` | ⬜ plan 04 | ⬜ pending |
| 13-05-01 | 05 | 5 | MAINT-03 | T-13-18, T-13-19 | `tool_health` distinguishes NOT_ON_PATH / BROKEN / UNPARSEABLE / OK, preserving the tool's exit status | unit | `bash tests/run-tests.sh` (symlink stubs) | ⬜ plan 05 creates | ⬜ pending |
| 13-05-02 | 05 | 5 | MAINT-03 | T-13-05 | `run_doctor` makes zero network calls and does not export `$INSTALL_DIR` onto PATH | static + unit | `grep` criteria over the `run_doctor` body + `bash tests/run-tests.sh` | ⬜ plan 05 creates | ⬜ pending |
| 13-05-03 | 05 | 5 | MAINT-01/03 | T-13-20 | check→0/1 on version currency, doctor→0/1 on health, update unaffected by its own recheck | smoke | `bash setup.sh doctor; echo $?` and `PATH=/usr/bin:/bin bash setup.sh doctor; echo $?` | ⬜ plan 05 | ⬜ pending |
| 13-06-01 | 06 | 6 | MAINT-01/02/03 | T-13-22 | README documents both new commands, statuses, exit codes, log, and GITHUB_TOKEN | doc | `grep` criteria over README.md | ⬜ plan 06 | ⬜ pending |
| 13-06-02 | 06 | 6 | MAINT-02 | T-13-06 | Failure log is git-ignored; ARCHITECTURE reflects the shipped implementation | doc | `git -C repos/security-platform check-ignore -q update-failures.log` | ⬜ plan 06 | ⬜ pending |
| 13-07-01 | 07 | 7 | MAINT-02/03 | — | Full suite green and baseline recorded before the mutating exercise | full suite | `bash tests/run-tests.sh` + `shellcheck` + `--help` greps | ⬜ plan 07 | ⬜ pending |
| 13-07-02 | 07 | 7 | MAINT-02 | T-13-17 | `pipx install --force` really changes the installed pre-commit version, both down and up | manual | `checkpoint:human-verify` — mutates the developer's environment, cannot be sandboxed | ❌ manual by design | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements (all owned by plan 01, wave 1)

- [ ] `repos/security-platform/workstation/setup.sh` — `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` main-guard around the dispatcher so the file is sourceable without executing `check_prerequisites` or dispatching. Bash 3.2 compatible.
- [ ] `repos/security-platform/workstation/tests/run-tests.sh` — runner with assert helpers, PASS/FAIL counters, glob-sourcing of `test_*.sh`, and a `FAIL_COUNT`-driven exit gate
- [ ] `repos/security-platform/workstation/tests/test_smoke.sh` — syntax, shellcheck, sourceability, `--help`, unknown-arg, fixture-presence assertions
- [ ] `repos/security-platform/workstation/tests/fixtures/hadolint-releases-compact.json` — truncated sample preserving compact `"tag_name":"v2.15.1"` formatting, including a `v2.12.1-beta` prerelease and a `v1.23.0` cross-major entry
- [ ] `repos/security-platform/workstation/tests/fixtures/gitleaks-releases-spaced.json` — truncated sample preserving spaced `"tag_name": "v8.30.1"` formatting, including `8.2.0` and `8.10.0` so lexical-vs-numeric ordering is distinguishable

**Resolved:** `bats` is NOT adopted. The runner is plain bash, matching the only existing shell test
harness in the tree and avoiding a new undeclared dev prerequisite.

Case files added by later plans (each owned by exactly one plan, no shared-file dependency):

- `tests/test_version_resolution.sh` — plan 02
- `tests/test_update_primitives.sh` — plan 03
- `tests/test_update_fallback.sh` — plan 04
- `tests/test_doctor.sh` — plan 05

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `update` actually changes an already-installed pre-commit's version, in both directions | MAINT-02 | Mutates the developer's real pipx environment; no safe sandbox without a container. Research verified the *unforced* `pipx install` exits 0 while doing nothing, but a forced **downgrade** was never empirically executed (Assumptions Log A4) | Plan 07, task 2: pin one release back → `update pre-commit` → `check` shows the older version → confirm with `pipx list` → `git checkout -- versions.conf` → `update pre-commit` → `check` shows the original pin. Both directions must be witnessed by `pipx list`, not only by the script's own table |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or a documented Wave 0 dependency
- [x] Sampling continuity: no 3 consecutive tasks without an automated verify
- [x] Wave 0 covers all MISSING references, and wave 0 (plan 01) precedes every plan that sources `setup.sh`
- [x] No watch-mode flags
- [x] Feedback latency < 20s (suite is offline and installs nothing)
- [x] `nyquist_compliant: true`

**Approval:** planner-approved 2026-09-09; `wave_0_complete` flips to true when plan 01 lands.
