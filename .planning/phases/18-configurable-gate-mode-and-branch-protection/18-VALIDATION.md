---
phase: 18
slug: configurable-gate-mode-and-branch-protection
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-11
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `actionlint` (workflow semantics) + `yamllint -d relaxed` (style) + `gh api` read-backs (live state). No unit-test framework applies — this phase produces YAML and Markdown, not code. |
| **Config file** | none for actionlint; `repos/security-platform/.pre-commit-config.yaml` carries the `yamllint` hook |
| **Quick run command** | `cd repos/security-platform && actionlint .github/workflows/security.yml .github/workflows/pr-security.yml && yamllint -d relaxed .github/workflows/*.yml` |
| **Full suite command** | quick run **+** `bash scripts/smoke-scans.sh` **+** the live PR checks below |
| **Estimated runtime** | ~5 seconds (static); live PR checkpoints are operator-timed, not automated |

---

## Sampling Rate

- **After every task commit:** Run `actionlint` + `yamllint -d relaxed` on both workflow files
- **After every plan wave:** Run the grep-based static assertions below + offline ruleset-script dry run
- **Before `/gsd:verify-work`:** One live report-only PR and one live blocking PR, both read back via `commits/{sha}/check-runs`
- **Max feedback latency:** ~5 seconds (static); live checkpoints are human-gated, not latency-bound

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | CICD-06 | — | `gate_mode` input declared and typed on `security.yml` | static | `actionlint .github/workflows/security.yml` | ✅ | ⬜ pending |
| 18-01-02 | 01 | 1 | CICD-06 | — | Caller (`pr-security.yml`) carries no `with:` block — flag driven by repo variable, not YAML edit | static | `! grep "gate_mode" .github/workflows/pr-security.yml` (outside comments) | ✅ | ⬜ pending |
| 18-01-03 | 01 | 1 | CICD-06 | — | All 11 `# D-04` `continue-on-error: true` lines conditioned on `gate_mode`, none left literal | static | `! grep -n "continue-on-error: true.*# D-04" .github/workflows/security.yml` | ✅ | ⬜ pending |
| 18-01-04 | 01 | 1 | CICD-06 | — | 3 guarded SCA scan steps (npm/pip/tflint) gain `always() &&` so they still run once an earlier step fails hard | static | `grep -c "if: always() && steps\.\(npm\|py\|tf\)\.outputs\.found" .github/workflows/security.yml` → expect ≥ 3 | ✅ | ⬜ pending |
| 18-01-05 | 01 | 1 | CICD-06 | ADR-001 | Existing ADR-001/CICD-02/CICD-03 upload/artifact tolerances untouched | static | `grep -c "continue-on-error: true .*ADR-001" .github/workflows/security.yml` → expect unchanged count (11) | ✅ | ⬜ pending |
| 18-01-06 | 01 | 1 | CICD-06 | — | Invalid `gate_mode` value fails fast and legibly | local | `case` guard step; `GATE_MODE=nonsense` exercised locally against the case block → exit 1 | ✅ | ⬜ pending |
| 18-02-01 | 02 | 2 | CICD-04 | — | Branch-protection guidance names the five (not six — D-06 corrected) contexts byte-exactly | static | `grep -c "security / " docs/<target-doc>.md` → expect 5; diff against live `gh api check-runs` names | ✅ | ⬜ pending |
| 18-02-02 | 02 | 2 | CICD-04 | — | Blueprint's existing wrong check-name guidance (~L2019–2028, job IDs not check-run names) corrected in place | static | `! grep -n "required check: \`sast\`" docs/development-security-stack-option-1.md` (adjust literal to final wording) | ✅ | ⬜ pending |
| 18-02-03 | 02 | 2 | CICD-04 | — | Ruleset read-modify-write recipe is non-destructive (`PUT` replaces whole document) | static/dry | Dry-run script against captured `/tmp/ruleset-before.json`; assert output retains `deletion` and `non_fast_forward` — no network write in this check | ✅ | ⬜ pending |
| 18-02-04 | 02 | 2 | CICD-04 | — | ADR-017 exists (append-only per CLAUDE.md) and is indexed | static | `test -f docs/adr/adr017-*.md && grep -q "ADR-017" docs/adr/README.md` | ✅ | ⬜ pending |
| 18-03-01 | 03 | 3 | CICD-06 | `checkpoint:human-verify` | report-only: all five checks conclude `success` despite seeded fixture findings | live | `gh api repos/$SLUG/commits/$SHA/check-runs --jq '[.check_runs[]|select(.app.id==15368)]|map(.conclusion)'` | ❌ | ⬜ pending |
| 18-03-02 | 03 | 3 | CICD-06 | `checkpoint:human-verify` | blocking: same fixtures, same PR pattern, all five checks conclude `failure` — flipped via repo variable only, no YAML edit | live | `gh variable set GATE_MODE --body blocking -R $SLUG` → re-run → `check-runs` read-back → `gh variable delete GATE_MODE -R $SLUG` | ❌ | ⬜ pending |
| 18-03-03 | 03 | 3 | CICD-06 | `checkpoint:human-verify` | blocking mode still uploads all SARIF + all five artifacts (ADR-001/CICD-02/CICD-03 hold under blocking) | live | `gh run view $RUN --log` + `gh api .../artifacts --jq '.total_count'` → expect 5 | ❌ | ⬜ pending |
| 18-03-04 | 03 | 3 | CICD-04 | `checkpoint:human-verify` (operator-gated, see Q5) | Required checks actually present in branch protection, if operator opts in | live | `gh api repos/$SLUG/rules/branches/main --jq '.[].type'` | ❌ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — `actionlint` 1.7.12 and `yamllint` 1.37.1 are installed and both pass on the current workflow files today, so the static gate is already green before any change.

The only "missing infrastructure" is a **live PR on `OttawaCloudConsulting/security-platform`**, which cannot be created by a test harness — plan it as explicit `checkpoint:human-verify` tasks (18-03-01 through 18-03-04 above), not as automated verification.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| report-only vs blocking check conclusions on seeded fixtures | CICD-06 | Requires a live GitHub Actions run against a real PR; no local harness reproduces GitHub's check-run app attribution or branch-variable resolution | Open a PR against `fixtures/`, read back `check-runs` in report-only, flip `vars.gate_mode`, re-run, read back again |
| SARIF/artifact upload survival under blocking | CICD-06 | Same — depends on live run outcome and artifact API | `gh run view` + `gh api .../artifacts` on the blocking run above |
| Required-checks presence in branch protection | CICD-04 | Operator decision (Q5/D-07 step 3) — this repo has `bypass_actors: []`, so requiring checks here risks locking `main`; decision deferred to operator sign-off | `gh api repos/$SLUG/rules/branches/main` after explicit operator go-ahead |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (or explicit `checkpoint:human-verify`)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none — infra already green; only gap is live-PR-dependent)
- [x] No watch-mode flags
- [x] Feedback latency < 5s (static); live checkpoints explicitly human-gated
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
