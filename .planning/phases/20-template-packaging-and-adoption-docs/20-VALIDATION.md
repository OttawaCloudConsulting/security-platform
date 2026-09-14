---
phase: 20
slug: template-packaging-and-adoption-docs
status: draft
nyquist_compliant: false
wave_0_complete: false
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

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 01 | 0 | DIST-06 | T-20-01 | Detector-parity harness proves inlined npm/pip/tf blocks behave identically with/without each ecosystem | unit-ish | scratch git repo + assert `SKIP:`/`FOUND` output | ❌ W0 | ⬜ pending |
| 20-01-02 | 01 | 0 | DIST-06 | T-20-02 | Dockerfile pathspec (A4) matches root, nested, and `.dockerfile` variants | unit-ish | `git ls-files -- '*Dockerfile' '*Dockerfile.*' '*.dockerfile'` in a fixture tree | ❌ W0 | ⬜ pending |
| 20-02-01 | 02 | 1 | DIST-06 | T-20-03 | Copied/adapted bundle in `security-platform` is valid YAML and preserves invariants | static | `actionlint` + `yamllint -d relaxed` + `bash scripts/check-workflow-uploads.sh` (exit 0) | ⚠️ exists, needs copy to host repo | ⬜ pending |
| 20-03-01 | 03 | 2 | DIST-06 | — | Dropping the bundle into a real repo produces a working run (SC1) | live | PR on `terraform-pipelines`; `gh api …/check-runs` shows five names; container job logs `SKIP: no Dockerfile found` | ❌ live | ⬜ pending |
| 20-03-02 | 03 | 2 | DIST-07 | — | `uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1` resolves and runs (SC2) | live | `gh api repos/.../git/ref/tags/v1` + consumer PR producing the same five contexts | ❌ live | ⬜ pending |
| 20-04-01 | 04 | 3 | DIST-08 | T-20-04 | Every command in the adoption doc actually works | doc-exec | execute each fenced command block against a real repo, paste real output | ❌ W0/manual | ⬜ pending |
| 20-04-02 | 04 | 3 | DIST-08 | — | Five check-run contexts in the doc are byte-exact | static | diff doc contexts against `gh api …/check-runs` output, byte-dump for U+2014 | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

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

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
