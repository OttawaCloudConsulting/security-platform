---
phase: 13
slug: maintenance-and-validation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-09
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None exists today. `bats` is installed on this machine but not wired into the project. Static analysis: `shellcheck` via pre-commit hook (`repos/security-platform/.pre-commit-config.yaml` L35-39). |
| **Config file** | none — Wave 0 installs `tests/` and a main-guard |
| **Quick run command** | `/bin/bash -n repos/security-platform/workstation/setup.sh && shellcheck repos/security-platform/workstation/setup.sh` |
| **Full suite command** | Quick command + `bash setup.sh check` + `bash setup.sh --help` + bats suite (once Wave 0 lands) |
| **Estimated runtime** | ~5s (syntax + shellcheck + smoke), bats suite adds ~10-20s |

---

## Sampling Rate

- **After every task commit:** `/bin/bash -n setup.sh && shellcheck setup.sh` (sub-second, no network)
- **After every plan wave:** above + `bash setup.sh check` + `bash setup.sh --help`
- **Before `/gsd:verify-work`:** Full suite green, plus the manual pre-commit-upgrade verification (Pitfall 1) as a `checkpoint:human-verify`
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-W0 | 01 | 0 | MAINT-01/02/03 | — | Script remains sourceable without executing dispatcher | syntax | `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` main-guard added around dispatcher (L847-894) | ❌ W0 | ⬜ pending |
| 13-01-01 | 01 | 1 | MAINT-01 | T-13-06 | `check` prints version + prereq tables | smoke | `bash repos/security-platform/workstation/setup.sh check` | ✅ exists today | ⬜ pending |
| 13-01-02 | 01 | 1 | MAINT-01 | T-13-06 | `check` exit code follows agreed contract (separate FAIL_COUNT from update) | smoke | `bash .../setup.sh check; echo $?` | ❌ contract to be decided by planner | ⬜ pending |
| 13-01-03 | 01 | 1 | MAINT-02 | T-13-05 | `resolve_latest_in_major` returns correct value per repo, whitespace-tolerant | unit | Source script via main-guard, call function directly | ❌ W0 fixture | ⬜ pending |
| 13-01-04 | 01 | 1 | MAINT-02 | T-13-04 | Attempt-2 fallback fires and is recorded distinctly from FAIL | integration | Impossible-pin scratch `versions.conf` (e.g. `TRIVY_VERSION="0.69.99999"`), run `update trivy` | ❌ W0 fixture | ⬜ pending |
| 13-01-05 | 01 | 1 | MAINT-02 | — | Failure log written to `$REPO_ROOT`, plain text, one line per failure, no secrets | integration | Same fixture; assert file exists, non-empty, no token substring | ❌ W0 fixture | ⬜ pending |
| 13-01-06 | 01 | 1 | MAINT-02 | — | `update` exits non-zero when a tool fails both attempts (D-08) | integration | Impossible-pin fixture; `echo $?` == 1 | ❌ W0 fixture | ⬜ pending |
| 13-01-07 | 01 | 1 | MAINT-02 | Pitfall 1 | `pipx install --force` actually upgrades an already-installed pre-commit | manual | Pin one release back, run `update`, confirm `check` shows new version | ❌ manual — mutates dev environment, must be `checkpoint:human-verify` | ⬜ pending |
| 13-01-08 | 01 | 1 | MAINT-03 | T-13-07 | `doctor` reports NOT_ON_PATH for an absent tool | integration | Run with `$INSTALL_DIR` scrubbed from `PATH` in a subshell | ❌ W0 fixture | ⬜ pending |
| 13-01-09 | 01 | 1 | MAINT-03 | T-13-07 | `doctor` reports BROKEN for a non-executable/failing stub | integration | Non-executable stub earlier on `PATH` in scratch dir | ❌ W0 fixture | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `repos/security-platform/workstation/setup.sh` — add `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` main-guard around the dispatcher (~L847-894) so the file is sourceable for unit tests without executing `check_prerequisites`/dispatch. Bash 3.2 compatible, standard idiom.
- [ ] `repos/security-platform/workstation/tests/` — directory does not exist, create it
- [ ] `tests/test_version_resolution.bats` — covers `resolve_latest_in_major` and whitespace-tolerant JSON parsing (guards the hadolint compact-JSON regression). Use recorded fixtures, not live API calls (60/hr budget).
- [ ] `tests/fixtures/hadolint-releases-compact.json` and `tests/fixtures/gitleaks-releases-spaced.json` — captured samples of both JSON styles GitHub returns
- [ ] `tests/test_update_fallback.bats` — impossible-pin fixture driving the D-04 attempt-2 path and the D-07 failure log
- [ ] `tests/test_doctor.bats` — PATH-scrubbed and broken-stub scenarios
- [ ] Decide whether `bats` becomes a declared dev prerequisite (present on this machine, not in `check_prerequisites`); if no, downgrade to a single `tests/smoke.sh` with plain bash asserts

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `update` actually upgrades an already-installed pre-commit | MAINT-02 | Mutates the developer's real environment (pipx-installed tool); no safe way to sandbox without a container | Pin `PRECOMMIT_VERSION` one release back in `versions.conf`, run `bash setup.sh update`, then `bash setup.sh check` and confirm the version now matches the current pin |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
