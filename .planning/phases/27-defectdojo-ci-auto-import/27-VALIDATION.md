---
phase: 27
slug: defectdojo-ci-auto-import
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-25
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash + inline python3 gates (project convention, 0/1/2 exit contract) + live GitHub Actions run |
| **Config file** | none — the gates are self-contained scripts |
| **Quick run command** | `bash repos/security-platform/scripts/check-workflow-uploads.sh && bash scripts/check-adoption-guide.sh && (cd repos/security-platform && actionlint)` |
| **Full suite command** | quick run + `bash repos/security-platform/scripts/check-detector-parity.sh` + `bash repos/security-platform/scripts/defectdojo-import-proof.sh` (local kind, ~15-20 min) + `gh workflow run defectdojo-import-proof.yml` then `gh run watch --exit-status` |
| **Estimated runtime** | quick: ~10 seconds; full: ~20-30 minutes (kind + chart bring-up dominates) |

---

## Sampling Rate

- **After every task commit:** Run the quick run command (three static gates).
- **After every plan wave:** Add `check-detector-parity.sh` and a local `defectdojo-import-proof.sh` when kind is available.
- **Before `/gsd:verify-work`:** The GitHub Actions proof run is green (run id recorded) and both gates are green on the final tree.
- **Max feedback latency:** ~10 seconds for static gates; live proof is per-wave / phase-gate only.

---

## Per-Task Verification Map

Task IDs are assigned by the planner; this map lists the behaviors each plan's tasks must verify.

| Behavior | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|----------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| Workflow shape: 5 frozen scan jobs unchanged in name/order, needs-free; import/cleanup allow-listed; secret declared optional; SHA pins in all workflow files | DDOJO-02 | — | Required-check set unchanged; actions SHA-pinned | static | `bash repos/security-platform/scripts/check-workflow-uploads.sh` (extended) | ✅ needs extension | ⬜ pending |
| Adoption guide lists exactly the 5 contexts; new "Enable DefectDojo import" section present; no sixth `security / ...` string | DDOJO-02 | — | N/A | static | `bash scripts/check-adoption-guide.sh` (extended to filter by the 5 ids) | ✅ needs extension | ⬜ pending |
| Workflow syntax incl. `timezone:`, `secrets:` in `workflow_call`, job-level `if` contexts | DDOJO-02 | — | N/A | static | `(cd repos/security-platform && actionlint)` | ✅ tool present | ⬜ pending |
| Step bodies contain no `${{` (extractable) and reference only env | DDOJO-02 | injection via branch name | Branch names never interpolated into `run:` | static | extractor assertion in `defectdojo-import-proof.sh` or uploads gate | ❌ W0 | ⬜ pending |
| Run 1: product, product type, `ci/<branch>` engagement, one Test per report file with expected `scan_type` + `title` | DDOJO-02 | — | N/A | live | `bash repos/security-platform/scripts/defectdojo-import-proof.sh` | ❌ W0 | ⬜ pending |
| Run 1 counts: exact equality for checkov/trivy-fs/trivy-image/pip-audit; bounded for semgrep/gitleaks/npm/SARIF | DDOJO-02 | — | N/A | live | same | ❌ W0 | ⬜ pending |
| Run 2 reimport: zero findings created per file; totals and Test count unchanged | DDOJO-02 | — | N/A | live | same | ❌ W0 | ⬜ pending |
| Cleanup deletes only `ci/<other>`; refuses default branch; no-match exits 0 with "nothing to delete" | DDOJO-02 | irreversible delete | Exact-name + product-scoped delete; default-branch refusal | live | same | ❌ W0 | ⬜ pending |
| Token user is staff, not superuser | DDOJO-02 | over-privileged token | Minimum permission set proven | live | same | ❌ W0 | ⬜ pending |
| TLS verified: no `-k` in proof path; `DEFECTDOJO_INSECURE` unset; CA variable used | DDOJO-02 | MITM | TLS verified by default | live + static | grep in proof script + ssl_verify_result assertion | ❌ W0 | ⬜ pending |
| Opt-out regression: `DEFECTDOJO_URL` unset → import/cleanup skipped, 5 checks unchanged | DDOJO-02 | — | Opt-in only | live (GitHub) | proof workflow `scans` job + `gh api .../check-runs` | ✅ implicit | ⬜ pending |
| Real Actions run green | DDOJO-02 | — | N/A | live (GitHub) | `gh workflow run defectdojo-import-proof.yml` then `gh run watch --exit-status` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `repos/security-platform/scripts/check-workflow-uploads.sh`: split JOB-SHAPE into scan jobs vs side-channel jobs; extend SHA-PIN to all workflow files.
- [ ] Extend `scripts/check-adoption-guide.sh`: derive contexts from the five scan-job ids only.
- [ ] `repos/security-platform/scripts/defectdojo-import-proof.sh`: token minting, step extractor, assertions.
- [ ] Minimal post-hook in `repos/security-platform/scripts/defectdojo-live-smoke.sh`, or a documented standalone bring-up.
- [ ] `repos/security-platform/.github/workflows/defectdojo-import-proof.yml`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Closed PR leaves "skipped" (passing) versions of the five required checks | DDOJO-02 | Needs a real PR close on GitHub | Open and close a test PR in security-platform; inspect check-runs on the head commit |
| Scheduled run fires at 06:00 America/Toronto | DDOJO-02 | Wall-clock trigger | Inspect the first scheduled run's timestamp after merge |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s for static gates
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
