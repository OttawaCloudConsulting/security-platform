---
phase: 19
slug: pipeline-validation-via-branch-target-prs
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-12
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — this phase validates a live GitHub Actions pipeline (`repos/security-platform`), not application code. Verification is via `gh` CLI (PR/run/artifact inspection) and GitHub Security tab API, not a test runner. |
| **Config file** | `repos/security-platform/.github/workflows/security.yml`, `pr-security.yml` |
| **Quick run command** | `gh run list --repo OttawaCloudConsulting/security-platform --branch <branch> --limit 1` |
| **Full suite command** | `gh pr checks <PR#> --repo OttawaCloudConsulting/security-platform` |
| **Estimated runtime** | ~2-5 min per Actions run |

---

## Sampling Rate

- **After every task commit (fixture add):** Run local scan tool directly (`semgrep --config=p/default fixtures/vulnerable.py`, `gitleaks detect --source fixtures/secret.env`) to confirm deterministic detection before pushing.
- **After every PR push/re-trigger:** `gh pr checks <PR#>` and `gh run view <run-id>` to confirm job outcomes match the gate mode under test.
- **Before `/gsd:verify-work`:** All four success criteria (SC1-SC4) must have captured evidence (run URLs, `gh run view` output, Security tab `html_url`).
- **Max feedback latency:** ~5 minutes (Actions run duration).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | VAL-01 | — | `fixtures/vulnerable.py` fires Semgrep `p/default` (eval() rule) | local-scan | `semgrep --config=p/default fixtures/vulnerable.py` | ✅ | ⬜ pending |
| 19-01-02 | 01 | 1 | VAL-01 | — | `fixtures/secret.env` fires Gitleaks `aws-access-token` rule | local-scan | `gitleaks detect --source fixtures/secret.env --no-git` | ✅ | ⬜ pending |
| 19-02-01 | 02 | 2 | VAL-01 | — | Validation PR (report-only) shows detections from all 5 jobs | manual+gh | `gh pr checks <PR#>` | N/A | ⬜ pending |
| 19-02-02 | 02 | 2 | VAL-01 | — | Same PR re-run under `blocking` fails checks | manual+gh | `gh pr checks <PR#>` | N/A | ⬜ pending |
| 19-02-03 | 02 | 2 | VAL-01 | — | Same PR re-run back under `report-only` passes | manual+gh | `gh pr checks <PR#>` | N/A | ⬜ pending |
| 19-03-01 | 03 | 3 | VAL-01 | — | SAST finding traced source→Security tab→artifact | manual+api | `gh api /repos/.../code-scanning/alerts?ref=...&tool_name=Semgrep%20OSS` | N/A | ⬜ pending |
| 19-04-01 | 04 | 4 | VAL-01 | — | Clean PR (no fixture changes) — all 5 jobs green | manual+gh | `gh pr checks <PR#>` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no new test framework needed. Local scanner binaries (`semgrep`, `gitleaks`) and `gh` CLI must be available; confirm via `semgrep --version` / `gitleaks version` / `gh auth status` before Wave 1.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| GATE_MODE repo variable flip (`report-only`→`blocking`→`report-only`) | VAL-01 | Repo-settings/API action, not a code change; irreversible mid-flight if left in `blocking` (see D-09) | `gh variable set GATE_MODE --body blocking --repo OttawaCloudConsulting/security-platform`, confirm with `gh variable get GATE_MODE`; flip back after capturing SC2 |
| SC3 Security tab entry (human-visible) | VAL-01 | GitHub UI-rendered alert page; API `html_url` must be opened once to confirm it renders, per researcher's note that Phase 17 lost this criterion to exactly this ambiguity | Open the `html_url` returned by the alerts API call in a browser; confirm alert renders with correct file/line |
| Validation PR merge-vs-close decision (D-10) | VAL-01 | Irreversible action on a shared GitHub repo — requires explicit user confirmation per session-management protocol | Present both options to user before executing `gh pr merge` or `gh pr close` |

---

## Validation Sign-Off

- [ ] All tasks have automated verify (local-scan) or explicit manual-only justification
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (none — existing infra sufficient)
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s (Actions run duration)
- [ ] `nyquist_compliant: true` set in frontmatter (set by planner once plan tasks finalized)

**Approval:** pending
