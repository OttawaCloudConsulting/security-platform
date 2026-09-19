---
phase: 24
slug: nexus-anonymous-access-and-workstation-script
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-19
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None conventional. `security-platform` has no pytest/jest/bats suite. Validation is two hand-written, hand-run gate scripts plus `pre-commit` — the established Phase 23 convention, extended here. |
| **Config file** | `security-platform/.pre-commit-config.yaml` (shellcheck, yamllint with `exclude: ^kubernetes/.*/templates/`, gitleaks) |
| **Quick run command** | `bash scripts/check-nexus-chart.sh` (17 checks today, 18 after plan 24-01) plus `bash scripts/check-nexus-setup.sh` (new in plan 24-03) — offline, seconds |
| **Full suite command** | `bash scripts/check-nexus-chart.sh && bash scripts/check-nexus-setup.sh && bash scripts/nexus-live-smoke.sh` — ~3 min docker half, ~8 min with kind half |
| **Estimated runtime** | ~10 seconds (quick) / ~11 minutes (full) |

Both scripts follow a **VACUOUS-PASS** convention — a run in which nothing executed prints `NOTHING RAN`, not `ALL PASS`; SKIP is never counted as a pass. Preserve this.

---

## Sampling Rate

- **After every task commit:** `bash scripts/check-nexus-chart.sh` + `pre-commit run --files <changed>`
- **After every plan wave:** full offline gate + `bash scripts/nexus-live-smoke.sh` docker half
- **Before `/gsd:verify-work`:** both gates green, `ALL PASS`, zero SKIPPED, and each newly added check proven non-vacuous by reverting its subject and observing red
- **Max feedback latency:** ~660 seconds (full suite worst case)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 24-W0-01 | 01 | 1 | NEXUS-02 | — | `anonymous.enabled` is a real, wired value (toggling changes the render) | offline gate | `bash scripts/check-nexus-chart.sh` → `ANONYMOUS-VALUE-PRESENT` (replaces `ANONYMOUS-NOT-OPENED`) | ❌ W0 | ⬜ pending |
| 24-W0-02 | 01 | 1 | NEXUS-02 | — | Shipped default matches the locked "OFF, opt-in" decision | offline gate | same → `ANONYMOUS-DEFAULT` | ❌ W0 | ⬜ pending |
| 24-W0-03 | 02 | 3 | NEXUS-02 | — | Unauthenticated npm tarball → 200 and > 300,000 bytes | live gate | `bash scripts/nexus-live-smoke.sh` → `ANONYMOUS-PULL-ALLOWED` (replaces `ANONYMOUS-PULL-DENIED`) | ❌ W0 | ⬜ pending |
| 24-W0-04 | 02 | 3 | NEXUS-02 | — | Unauthenticated PyPI simple index and Helm `index.yaml` → 200, non-trivial size | live gate | same → `ANONYMOUS-PULL-PYPI`, `ANONYMOUS-PULL-HELM` | ❌ W0 | ⬜ pending |
| 24-W0-05 | 05 | 4 | NEXUS-02 | — | Full Docker handshake (ping 401 + Bearer challenge → token → manifest with `Authorization: Bearer` → 200 → layer blob → 200) | live gate | same → `ANONYMOUS-PULL-DOCKER` | ❌ W0 | ⬜ pending |
| 24-W0-06 | 05 | 4 | NEXUS-02 | — | `DockerToken` appears in active realms exactly once after two consecutive provisioning passes | live gate | same → `DOCKER-REALM-ACTIVE` | ❌ W0 | ⬜ pending |
| 24-W0-07 | 05 | 4 | NEXUS-02 | — | `/v2/<repo>/…` → 200 and `/v2/repository/<repo>/…` → 404 | live gate | same → `DOCKER-PATH-SHAPE` | ❌ W0 | ⬜ pending |
| 24-W0-08 | 05 | 4 | NEXUS-02 | — | Anonymous write denied: valid-body POST → 403, admin GET of the name → 404 | live gate | same → `ANONYMOUS-WRITE-DENIED` | ❌ W0 | ⬜ pending |
| 24-W0-09 | 02 | 3 | NEXUS-02 | — | Both new provisioning calls are idempotent across two consecutive runs | live gate | existing two-pass `run_provision` extended with `ANONYMOUS_*` env vars | ✅ extend only | ⬜ pending |
| 24-W0-10 | 07 | 4 | NEXUS-04 | — | Script writes `.npmrc`; `npm config get registry` returns the Nexus URL | script self-verify | `bash workstation/nexus-setup.sh --url … --verify` | ❌ W0 | ⬜ pending |
| 24-W0-11 | 07 | 4 | NEXUS-04 | — | Script writes `pip.conf`; `PIP_CONFIG_FILE=… pip config get global.index-url` returns it | script self-verify | same | ❌ W0 | ⬜ pending |
| 24-W0-12 | 07 | 4 | NEXUS-04 | — | Script writes `.helm/repositories.yaml` via `helm repo add`; `helm repo list` shows it, global file unchanged | script self-verify | same | ❌ W0 | ⬜ pending |
| 24-W0-13 | 03 | 1 | NEXUS-04 | — | Emitted `NEXUS_DOCKER_REGISTRY` contains no `/repository/` segment | offline gate | `bash scripts/check-nexus-setup.sh` → `DOCKER-PREFIX-SHAPE` (asserted on the emitted `.nexus-env` line only) | ❌ W0 | ⬜ pending |
| 24-W0-14 | 03 | 1 | NEXUS-04 | — | Existing `.npmrc` content (incl. auth-token line) survives a re-run | script test | fixture dir + `npm config set --location=project` + grep | ❌ W0 | ⬜ pending |
| 24-W0-15 | 03 | 1 | NEXUS-04 | — | Script is not executable and passes shellcheck | pre-commit | `pre-commit run --all-files`; `test ! -x workstation/nexus-setup.sh` | ❌ (the `-x` assertion) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Rewrite `scripts/check-nexus-chart.sh` check 8 → `ANONYMOUS-VALUE-PRESENT`; add `ANONYMOUS-DEFAULT` (plan 24-01, `CHECK_COUNT` 17 → 18)
- [ ] New `scripts/check-nexus-setup.sh` owns `DOCKER-PREFIX-SHAPE` and the `.npmrc` merge fixture test (plan 24-03) — homed there rather than in `check-nexus-chart.sh` so the two gate scripts have one owning plan each and `CHECK_COUNT` is never a merge point
- [ ] Rewrite `scripts/nexus-live-smoke.sh` `ANONYMOUS-PULL-DENIED` → `ANONYMOUS-PULL-ALLOWED`; add `ANONYMOUS-PULL-PYPI`, `ANONYMOUS-PULL-HELM`, `ANONYMOUS-PULL-DOCKER` (full handshake), `DOCKER-REALM-ACTIVE`, `DOCKER-PATH-SHAPE`, `ANONYMOUS-WRITE-DENIED`
- [ ] Update `run_provision()` in the live smoke with the three new `ANONYMOUS_*` env vars (plan 24-01, at `false` so `ANONYMOUS-PULL-DENIED` stays valid at that commit; plan 24-02 flips it to `true` and inverts the check in the same commit) and with `READY_ATTEMPTS` / `READY_INTERVAL` (plan 24-02) — without them the smoke fails under `set -u` the moment `provision.sh` changes
- [ ] `workstation/nexus-setup.sh` with a `--verify` mode performing one real fetch per ecosystem
- [ ] A fixture-based test for the `.npmrc` merge (pre-existing auth-token line must survive)
- [ ] No test framework install needed

---

## Manual-Only Verifications

*None — all phase behaviors have automated (offline or live-gate) verification per RESEARCH.md.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 660s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
