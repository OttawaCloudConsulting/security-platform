---
phase: 20
slug: template-packaging-and-adoption-docs
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-14
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (no pytest/jest/vitest; no `tests/` dir). Validation is lint + static-invariant gates + live CI runs |
| **Config file** | `.markdownlint.jsonc`, `.markdownlint-cli2.yaml` (docs); no test config |
| **Quick run command** | `actionlint <files> && yamllint -d relaxed <files> && bash scripts/check-workflow-uploads.sh` |
| **Full suite command** | Quick command, plus a live consumer PR: five `security / …` check runs present and concluding, five artifacts, gate flip measured |
| **Estimated runtime** | ~30s quick / ~5min full (live PR round trip) |

---

## Sampling Rate

- **After every task commit:** Run `actionlint` + `yamllint -d relaxed` on any touched workflow; `markdownlint-cli2` on any touched doc.
- **After every plan wave:** Run `bash scripts/check-workflow-uploads.sh` (exit 0) + em-dash byte-exactness diff on the five check-run context names.
- **Before `/gsd:verify-work`:** One live PR per consumption mode (copy-paste + `uses:`), both producing five concluding `security / …` check runs and five artifacts.
- **Max feedback latency:** ~300 seconds (live PR round trip).

---

## Per-Task Verification Map

> Regenerated against the actual 13-plan / 12-wave structure committed for this phase (was drafted against
> an earlier, coarser 4-plan sketch — task IDs below now match `20-{01..13}-PLAN.md`).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-02-01 | 02 | 1 | DIST-06 | T-20-01 | Detector-parity harness proves inlined npm/pip/tf blocks behave identically with/without each ecosystem | unit-ish | scratch git repo + assert `SKIP:`/`FOUND` output | ✅ Plan 02 Task 1 | ⬜ pending |
| 20-02-02 | 02 | 1 | DIST-06 | T-20-02 | Dockerfile pathspec (A4) matches root, nested, and `.dockerfile` variants | unit-ish | `git ls-files -- '*Dockerfile' '*Dockerfile.*' '*.dockerfile'` in a fixture tree | ✅ Plan 02 Task 1 | ⬜ pending |
| 20-03-01 | 03 | 2 | DIST-06, DIST-07 | T-20-03 | Portability pass (P-1..P-6) leaves bundle valid YAML and preserves invariants | static | `actionlint` + `yamllint -d relaxed` + `bash scripts/check-workflow-uploads.sh` (exit 0) | ✅ Plan 03 | ⬜ pending |
| 20-06-01 | 06 | 5 | DIST-06 | — | Portability-fixed bundle merged to `security-platform` main, proven on a live PR | live | PR on `security-platform`; `gh api …/check-runs` shows five names concluding | ✅ Plan 06 | ⬜ pending |
| 20-07-01 | 07 | 6 | DIST-07, DIST-02 | — | Tagged release (`v1.0.0` + moving `v1`) exists on `security-platform` | live | `gh api repos/.../git/ref/tags/v1` returns a tag object; `gh release view v1.0.0` | ✅ Plan 07 | ⬜ pending |
| 20-10-01 | 10 | 9 | DIST-06 | — | Dropping the copy-paste bundle into a public repo produces a working run (SC1) | live | PR on `terraform-pipelines`; `gh api …/check-runs` shows five names; container job logs `SKIP: no Dockerfile found` | ✅ Plan 10 Task 1 | ⬜ pending |
| 20-10-02 | 10 | 9 | DIST-07 | — | `uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1` resolves and runs (SC2) | live | consumer caller workflow on `terraform-pipelines` producing the same five contexts | ✅ Plan 10 Task 2 | ⬜ pending |
| 20-11-01 | 11 | 10 | — (Q2 follow-up) | T-20-05 | Private-repo capability guard skips the six verify steps cleanly instead of failing | live | PR on `aws-zabbix-monitoring-solution`; verify steps show `skipped`, not `failure` | ✅ Plan 11 | ⬜ pending |
| 20-08-01 | 08 | 7 | DIST-08 | T-20-04 | Every command in adoption guide §1-6 actually works | doc-exec | execute each fenced command block against a real repo, paste real output | ✅ Plan 08 | ⬜ pending |
| 20-09-01 | 09 | 8 | DIST-08 | — | Adoption guide §7-13 covers gate-mode, branch protection, Dependabot, job applicability/removal (SC3, SC4) | doc-exec + static | execute doc commands; diff five check-run contexts against `gh api …/check-runs` output, byte-dump for U+2014 | ✅ Plan 09 | ⬜ pending |
| 20-12-01 | 12 | 11 | DIST-08 | — | Guide corrected from live pilot evidence; blueprint/`cicd/` stale-template drift resolved (Q3) | doc-exec | re-run corrected commands from Plans 10/11 evidence; `scripts/check-adoption-guide.sh` (if added) | ✅ Plan 12 | ⬜ pending |
| 20-13-01 | 13 | 12 | DIST-06, DIST-07, DIST-08 | — | ADR-018 records D-01 amendment + sync/versioning/Q3 decisions; phase marked complete | static | ADR-018 file exists under `docs/adr/`; ROADMAP.md Phase 20 checkbox flips | ✅ Plan 13 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*"File Exists" column now tracks plan coverage (✅ = a committed plan implements this), not raw file presence on disk pre-execution.*

---

## Wave 0 Requirements

- [ ] Detector-parity harness for the three inlined blocks (npm/pip/terraform), with/without each ecosystem — covers DIST-06
- [ ] Dockerfile-pathspec measurement (A4) — covers DIST-06, settles an unverified research assumption
- [ ] Byte-exactness check for the five check-run contexts referenced in the new adoption doc — covers DIST-08
- [ ] A scratch git repo (or extension of `scripts/smoke-scans.sh`) as the harness host — no framework install needed
- [ ] Run `bash scripts/check-workflow-uploads.sh` against the **modified** canonical copy first (it parses step shapes with PyYAML and is `REPO_ROOT`-relative — must run inside the canonical host repo, `security-platform`)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Copy-paste template produces a working scan run in a fresh repo | DIST-06 | Requires a real GitHub repo + PR; no local emulation of Actions runners with full parity | Copy bundle into a pilot repo, open PR, confirm five `security / …` checks conclude |
| `uses:` consumption mode resolves against a tagged ref | DIST-07 | Requires a published tag/release on `security-platform` and a second consumer repo | Tag `v1` on `security-platform`, reference from a pilot repo's caller workflow, open PR |
| Private-repo code-scanning capability guard behaves correctly | — (Q2 follow-up) | GitHub Advanced Security availability differs by plan/visibility; only observable live | Open PR on `aws-zabbix-monitoring-solution` (private) and confirm the six verify steps are guarded/skip cleanly rather than failing |
| Branch protection / required-checks setup doc steps work as written | DIST-08 | `gh api` ruleset calls are destructive/idempotent-with-side-effects against real repo settings | Run doc's `gh` commands against a pilot repo, confirm required checks list matches the five frozen names |

---

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (Plan 02, wave 1)
- [x] No watch-mode flags
- [x] Feedback latency < 300s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-09-14 (post plan-checker revision pass)
