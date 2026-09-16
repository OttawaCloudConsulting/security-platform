---
phase: 22
slug: branch-protection-apply-live-exercise-needs-explicit-target
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-16
---

# Phase 22 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash standing gates + live `gh api` re-query (no xUnit framework; none should be added) |
| **Config file** | none — gates are self-contained scripts |
| **Quick run command** | `bash scripts/check-adoption-guide.sh` |
| **Full suite command** | `bash scripts/check-adoption-guide.sh && bash repos/security-platform/scripts/check-workflow-uploads.sh && bash repos/security-platform/scripts/check-detector-parity.sh` |
| **Estimated runtime** | ~10 seconds (bash gates) + live API round-trips (variable, network-bound) |

`bash scripts/check-adoption-guide.sh` verified green this session: 15 passed / 0 failed.

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/check-adoption-guide.sh`
- **After every plan wave:** Run full suite (above)
- **Before `/gsd:verify-work`:** Full suite must be green, **plus** `rules-restored.txt` byte-identical to `rules-before.txt`

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 22-0X-0X | TBD | TBD | VAL-02 | — | Red required check yields `BLOCKED`, red non-required check yields `UNSTABLE`, same head SHA | integration (live) | `gh pr view $PR -R $REPO --json headRefOid,mergeStateStatus` before/after apply, diffed | ✅ no new file | ⬜ pending |
| 22-0X-0X | TBD | TBD | VAL-02 | — | `gh pr merge` refused while blocked | integration (live) | Preconditioned: `S=$(gh pr view … --jq .mergeStateStatus); [ "$S" = BLOCKED ] \|\| exit 1` then `gh pr merge $PR -R $REPO --squash` (never `--admin`) | ✅ | ⬜ pending |
| 22-0X-0X | TBD | TBD | VAL-02 | — | Third verdict: green + still-required settles to `CLEAN` | integration (live) | `gh variable delete GATE_MODE -R $REPO; gh run rerun <id> -R $REPO`, settle-poll `mergeStateStatus` | ✅ | ⬜ pending |
| 22-0X-0X | TBD | TBD | VAL-02 | — | No evidence artifact contains an unsettled read | offline | `! grep -rq UNKNOWN $E/*.json $E/*.txt` | ✅ | ⬜ pending |
| 22-0X-0X | TBD | TBD | VAL-02 | — | The PUT preserves every pre-existing rule type | integration (live) | `gh api repos/$REPO/rules/branches/main --jq '[.[].type]\|sort'` — expect before set ∪ `{required_status_checks, pull_request}` | ✅ | ⬜ pending |
| 22-0X-0X | TBD | TBD | VAL-02 | — | Rollback restores the exact before-state | integration (live) | `diff $E/rules-before.txt $E/rules-restored.txt` → empty | ✅ | ⬜ pending |
| 22-0X-0X | TBD | TBD | DIST-08 (regression) | — | Adoption guide §8 still consistent after any prose update | offline gate | `bash scripts/check-adoption-guide.sh` | ✅ green today | ⬜ pending |
| 22-0X-0X | TBD | TBD | — (regression) | — | Script guards still refuse correctly | offline unit-ish | `set-required-checks.sh --apply` → exit 4; `--apply --verify-sha X` → exit 5; `--input <doc without rules>` → exit 2 (re-verified this session) | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `22-0X-evidence/` directory — capture target must exist before the first live read
- [ ] Offline guard-regression check (script or inline task) exercising exits 2/3/4/5 against `--input` fixtures, re-proven at this commit rather than inherited from Phase 18-03
- [ ] Settle-poll helper (inline per task or one small bash function) implementing the bounded loudly-failing poll — every `mergeStateStatus` read in the phase must go through it
- [ ] No test framework install needed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Operator confirms target repo (`terraform-pipelines`) and accepts the bounded-window/restore plan before the live apply | VAL-02 | Irreversible-ish live write to a real repo's branch protection — requires explicit human go-ahead, not automatable | Present target repo, current ruleset state, and restore plan; operator types "approved" (`checkpoint:human-verify`) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (excluding live GitHub API round-trips)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
