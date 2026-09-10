---
phase: 10
slug: cross-platform-install-script
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-17
updated: 2026-09-10
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + custom test runner (describe/pass/fail/assert_* helpers) |
| **Config file** | none — plain `test_*.sh` files auto-discovered |
| **Quick run command** | `bash repos/security-platform/workstation/tests/run-tests.sh` |
| **Full suite command** | `bash repos/security-platform/workstation/tests/run-tests.sh` (195 assertions, includes phases 10/11/12/13) |
| **Estimated runtime** | ~10 seconds |

> **Provenance note (2026-09-10):** This phase's original deliverable, `dist/install.sh`,
> was deleted 2026-03-20 (commit `828f04825aeb`) and its install logic folded into
> `repos/security-platform/workstation/setup.sh` (`install`/`setup` subcommands). This
> VALIDATION.md was reconstructed against the current `setup.sh`, not the deleted file.

---

## Per-Task Verification Map

| Requirement | Test Type | Automated Command | Status |
|-------------|-----------|--------------------|--------|
| INST-01 | manual (network+fs, live install) | see Manual-Only below | manual |
| INST-02 | unit (mocked `uname`) | `bash tests/run-tests.sh` → `tests/test_os_arch_detection.sh` | ✅ green (18/18) |
| INST-03 | unit (fixture-based) | `bash tests/run-tests.sh` → `tests/test_version_resolution.sh` | ✅ green |
| INST-04 | unit (PATH env mocked) | `bash tests/run-tests.sh` → `tests/test_path_warning.sh` | ✅ green |
| INST-05 | manual (network, pipx) | see Manual-Only below | manual |
| INST-06 | manual (network, binary download) | see Manual-Only below | manual |
| INST-07 | manual (network, binary download) | see Manual-Only below | manual |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| End-to-end fresh-machine install | INST-01, INST-05, INST-06, INST-07 | Live network downloads + real filesystem installs of pipx/trivy/syft/grype/gitleaks/hadolint; cannot simulate in static/offline test | On a clean macOS or Linux machine with none of the 6 tools present, run `bash setup.sh install` (or `setup`), confirm all 6 respond to their version command |
| Idempotent re-install | INST-01 | Requires a full prior install cycle | Run install twice; second run shows "skipped" for all 6 tools, exit 0 |

---

## Validation Sign-Off

- [x] All tasks have automated verify or documented manual-only status
- [x] Wave 0 (`test_os_arch_detection.sh`) covers the one MISSING requirement found by audit
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-09-10 via `/gsd:validate-phase`

---

## Validation Audit 2026-09-10

| Metric | Count |
|--------|-------|
| Gaps found | 5 (INST-01, INST-02, INST-05, INST-06, INST-07) |
| Resolved | 1 (INST-02 — new automated test) |
| Escalated (manual-only, by design) | 4 (INST-01, INST-05, INST-06, INST-07 — network/live-install, matches original VERIFICATION.md human-verification calls) |
