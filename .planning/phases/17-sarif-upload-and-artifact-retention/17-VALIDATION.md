---
phase: 17
slug: sarif-upload-and-artifact-retention
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-11
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None conventional. Gate is `bash scripts/smoke-scans.sh` (hand-rolled pass/fail harness: `run_scan_rc`/`require_success`/`SKIPPED` accounting) plus inline `python3` heredoc assertions inside the workflow. No pytest/jest — none should be introduced. |
| **Config file** | `repos/security-platform/scripts/smoke-scans.sh` |
| **Quick run command** | `python3` static workflow assertion (yaml/permissions/category checks) — sub-second, no network |
| **Full suite command** | `bash repos/security-platform/scripts/smoke-scans.sh` |
| **Estimated runtime** | ~30-60s for static assertions; smoke-scans.sh varies by scanner count |

**Important:** `smoke-scans.sh` validates *scanners* — its invariant is "a scanner that exits 0 found nothing = FAIL." Upload steps have the **opposite** semantics (success = exit 0). Phase 15 hit this exact inversion and fixed it with `require_success`. **Any smoke-gate extension for this phase must use `require_success`, never `run_scan`/`run_scan_rc`.**

---

## Sampling Rate

- **After every task commit:** `python3` static workflow assertion (fast, offline — catches permission grant, category uniqueness, SHA-pin regressions)
- **After every plan wave:** `bash scripts/smoke-scans.sh` — confirms Phase 15/16 scanners still produce findings after any `trivy convert` → direct-SARIF changes
- **Before `/gsd:verify-work`:** one live PR run (constructed against a flagged fixture line per Pitfall 4) + the three `gh api` live checks + manual annotation check
- **Max feedback latency:** ~60s for static checks; live PR check is manual/out-of-band

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 0 | CICD-02 | V4 | Both workflow files declare `security-events: write` at the calling job, not repo-wide | static | `python3` yaml assertion | ❌ Wave 0 | ⬜ pending |
| 17-01-02 | 01 | 0 | CICD-02 | V14 | Every `upload-sarif` step has a `category`, categories unique across all uploads | static | same assertion | ❌ Wave 0 | ⬜ pending |
| 17-01-03 | 01 | 0 | CICD-02 | ADR-004 | Both new actions (upload-sarif, upload-artifact) are 40-char SHA-pinned | static | same assertion | ❌ Wave 0 | ⬜ pending |
| 17-01-04 | 01 | 1 | CICD-02 | — | Each SARIF file parses, has top-level `runs` key before upload | in-CI | extend existing `Verify … SARIF` python3 pattern (tflint precedent) | ✅ pattern exists | ⬜ pending |
| 17-01-05 | 01 | 1 | CICD-02 | — | Upload landed (not swallowed by `continue-on-error`) | in-CI | assert `steps.<id>.outputs.sarif-id` non-empty via `require_success` | ❌ Wave 0 | ⬜ pending |
| 17-01-06 | 01 | 2 | CICD-02 / Crit.1 | — | Six distinct categories present on head SHA | live | `gh api repos/.../code-scanning/analyses?ref=refs/pull/<n>/merge --jq '[.[].category]\|unique'` | ❌ Wave 0 (live PR) | ⬜ pending |
| 17-01-07 | 01 | 2 | CICD-02 / Crit.2 | — | Inline annotations on PR diff for tools that report file+line | live + manual | verify via PR "Files changed" tab; PR must edit a flagged line in `fixtures/main.tf`/`Dockerfile`/`package-lock.json` | ❌ Wave 0 | ⬜ pending |
| 17-02-01 | 02 | 0 | CICD-03 | V12 | Five artifacts, unique names, all with `retention-days`, no secret-bearing globs | static | `python3` yaml assertion | ❌ Wave 0 | ⬜ pending |
| 17-02-02 | 02 | 2 | CICD-03 / Crit.3 | — | Artifacts downloadable with stated expiry | live | `gh api repos/.../actions/runs/<id>/artifacts --jq '.artifacts[]\|{name,expires_at,size_in_bytes}'` | ❌ Wave 0 | ⬜ pending |
| 17-02-03 | 02 | 2 | CICD-03 | — | SCA artifact contains numbered npm/pip reports | live | download and list; assert `npm-audit-*.json` present | ❌ Wave 0 | ⬜ pending |
| 17-03-01 | 03 | 1 | CICD-02 / Crit.4 | — | Conversion step (trivy convert) documented for npm-audit/pip-audit | doc review | ADR-016 + blueprint diff | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Static workflow-assertion script (or inline plan verification) covering CICD-02 + CICD-03 static checks (permissions, category uniqueness, SHA pins, retention-days, artifact-name uniqueness)
- [ ] `sarif-id`-presence verification steps (one per upload) using `require_success` — covers the ADR-001 continue-on-error blind spot
- [ ] Live `gh api` verification commands for analyses + artifacts (run manually against the verification PR)
- [ ] `smoke-scans.sh` extension using `require_success` if `trivy convert` is added for npm-audit/pip-audit — must not reuse `run_scan_rc`
- [ ] A deliberately-constructed verification PR touching a flagged fixture line (Pitfall 4) — required to observe Criteria 1 and 2 live

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Inline PR diff annotations render per-scanner | CICD-02 / Crit.2 | No reliable API for diff-annotation rendering; GitHub only annotates "new alerts on lines of code changed in the pull request" | Open verification PR's "Files changed" tab, confirm annotations appear on the edited fixture line for each applicable scanner |
| Security tab shows six distinct scanner categories, no overwrite | CICD-02 / Crit.1 | Confirms real GitHub-side rendering, not just upload success | After PR run, visit repo Security > Code scanning, confirm each scanner's findings listed separately |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (static tier)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
