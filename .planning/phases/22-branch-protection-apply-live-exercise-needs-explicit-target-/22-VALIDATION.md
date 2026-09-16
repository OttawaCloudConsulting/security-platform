---
phase: 22
slug: branch-protection-apply-live-exercise-needs-explicit-target
status: planned
nyquist_compliant: true
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
| 22-01-01 | 22-01 | 1 | VAL-02 | T-22-33 | No write reaches `terraform-pipelines` without a live operator `proceed`; the recorded 22-CONTEXT.md decision is re-confirmed at execution time, not merely at plan time | checkpoint (operator-answered, `gate="blocking"`) | `grep -qE '^(proceed\|halt)\b' 22-evidence/go-decision.txt` — and the file's mtime precedes every other file in `22-evidence/` | ✅ new: `22-evidence/go-decision.txt` | ⬜ pending |
| 22-01-02 | 22-01 | 1 | VAL-02 | T-22-05 | Settle-poll rejects an unsettled AND a stale merge-state read; its failure path is observed firing, not assumed | offline unit-ish | `bash -n 22-poll-merge-state.sh`; then `POLL_ITERATIONS=2 POLL_SLEEP=1` with `prev` equal to the current value → expect exit 1 | ✅ new: `22-poll-merge-state.sh` | ⬜ pending |
| 22-01-03 | 22-01 | 1 | VAL-02 | T-22-04 | Pre-exercise ruleset captured; today's read matches the independent 2026-09-14 pilot capture | offline gate | `diff 22-evidence/rules-before.txt 20-10-evidence/rules-before.txt` → empty | ✅ no new file | ⬜ pending |
| 22-01-04 | 22-01 | 1 | VAL-02 | T-22-02 | Exercise PR carries exactly five `app.id 15368` contexts; baseline verdict recorded as measured, halting if already `BLOCKED` | integration (live) | `python3 -c` over `check-runs-baseline.json` asserting `len == 5`; `! grep -q UNKNOWN merge-state-baseline.json` | ✅ no new file | ⬜ pending |
| 22-02-01 | 22-02 | 2 | VAL-02 | T-22-07, T-22-08 | One repository-variable flip turns a check red on a byte-identical tree; the window is bounded and audited | integration (live) | `diff tree-hash-baseline.txt tree-hash-blocking.txt` → empty; ≥1 `failure` among exactly 5 contexts; `gh variable list` empty afterwards | ✅ no new file | ⬜ pending |
| 22-02-02 | 22-02 | 2 | VAL-02 | T-22-18 | Control verdict: red but NOT required is not `BLOCKED`; em-dash contexts are U+2014 by codepoint | integration (live) | `python3 -c` asserting `mergeStateStatus not in (UNKNOWN, BLOCKED)`, five `app_id 15368` entries, `—` in every name | ✅ no new file | ⬜ pending |
| 22-03-01 | 22-03 | 3 | — (regression) | T-22-12 | Script guards still refuse correctly, re-proven at THIS commit by the operator — exit 4 without `--verify-sha`, exit 5 without the lockout ack, exit 2 on a document with no `rules` key. **Exit 3 is NOT offline-triggerable**: the script's own merge carries every pre-existing type forward, so it cannot construct a dropping document; exit 3 stays covered by 18-03's record, not re-proven here | offline unit-ish (operator-run) | exit codes read from `guard-rehearsal.txt`; the invocations are operator-run because the executor's Bash classifier has denied this script twice | ✅ new: `22-evidence/exit2-fixture.json` | ⬜ pending |
| 22-03-02 | 22-03 | 3 | VAL-02 | T-22-11, T-22-13 | The PUT preserves every pre-existing rule type and synthesises no bypass actor | integration (live) | `python3 -c` asserting `after == before ∪ {required_status_checks, pull_request}`, five contexts at `integration_id 15368`, `bypass_actors == []` | ✅ no new file | ⬜ pending |
| 22-04-01 | 22-04 | 4 | VAL-02 | T-22-17, T-22-19 | Red **required** check yields `BLOCKED` on the same head SHA the control read `UNSTABLE`; `gh pr merge` is refused, hard-preconditioned on a fresh `BLOCKED` read, never `--admin` | integration (live) | `python3 22-assert-verdicts.py blocked` — same `headRefOid`, control not `BLOCKED`, refusal text non-empty and `--admin`-free, PR `OPEN`/`mergedAt` null, `main` HEAD unchanged | ✅ new: `22-assert-verdicts.py` | ⬜ pending |
| 22-04-02 | 22-04 | 4 | VAL-02 | T-22-20, T-22-21 | Third verdict: five green with the contexts STILL required settles to `CLEAN`, isolating the red required check as the refusal's cause. Re-triggered by an **empty commit**, never `gh run rerun` — upload-artifact v4 requires unique names per run id and a rerun reuses it (18-05's measured reason), which would poison a verdict needing all five green. The asserted invariant is the **tree hash**, not the SHA | integration (live) | `python3 22-assert-verdicts.py clean` — three tree-hash files identical, five `success`, five contexts still required, no `UNKNOWN` anywhere in `22-evidence/` | ✅ no new file | ⬜ pending |
| 22-05-01 | 22-05 | 5 | VAL-02 | T-22-22, T-22-23 | Rollback restores the exact before-state from the six-key projection, never the raw GET response | integration (live) | `diff 22-evidence/rules-before.txt 22-evidence/rules-restored.txt` → empty. **This is the phase gate** | ✅ no new file | ⬜ pending |
| 22-05-02 | 22-05 | 5 | VAL-02 | T-22-25, T-22-26 | No evidence artifact carries a token or an unsettled read; no `GATE_MODE` remains | offline | `! grep -rqE 'gho_\|ghp_\|UNKNOWN' 22-evidence/` and `test -z "$(gh variable list -R OttawaCloudConsulting/terraform-pipelines)"` | ✅ no new file | ⬜ pending |
| 22-06-01 | 22-06 | 6 | VAL-02 | T-22-28 | ADR-019 is a NEW file in the four-heading form; ADR-017 and ADR-018 are untouched (append-only) | offline gate | `grep -c '^## ' docs/adr/adr019-*.md` → 4; `git diff -- docs/adr/adr017-*.md docs/adr/adr018-*.md` → empty | ✅ new: `docs/adr/adr019-required-check-enforcement-live-exercise.md` | ⬜ pending |
| 22-06-02 | 22-06 | 6 | DIST-08 (regression) | T-22-30 | Adoption guide section 8 still consistent after the measured-not-guidance update | offline gate | `bash scripts/check-adoption-guide.sh` → 15 passed / 0 failed | ✅ green today | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `22-evidence/` directory — capture target must exist before the first live read. Created in **22-01 Task 1** to hold `go-decision.txt`, and populated from **22-01 Task 2** onward. Phase-scoped, not plan-scoped as 20-10's `20-10-evidence/` was: one continuous live exercise produces one evidence trail, and splitting it per plan would break the `diff rules-before.txt rules-restored.txt` gate across a directory boundary.
- [ ] Guard regression exercising exits **2, 4 and 5** against `--input` fixtures, re-proven at this commit rather than inherited from 18-03. Fixture written in **22-02 Task 2** (`22-evidence/exit2-fixture.json`); the invocations run in **22-03 Task 1**, operator-executed, because the executor's Bash classifier has denied this script twice. **Exit 3 is deliberately NOT rehearsed** — the script's own merge carries every pre-existing rule type forward, so it cannot construct a document that drops one; claiming a rehearsal of exit 3 would be claiming a test that cannot be run offline.
- [ ] Settle-poll helper implementing the bounded, loudly-failing poll — **22-01 Task 2**, as `22-poll-merge-state.sh`. Every merge-state read in plans 01, 02 and 04 goes through it. Its post-loop assertion tests BOTH `!= UNKNOWN` AND `!= prev`, correcting the defect in 22-RESEARCH's published loop, and its stale path is observed exiting 1 before it is trusted.
- [ ] Verdict assertion helper `22-assert-verdicts.py` — **22-04 Task 1**, written before that task's own verify runs.
- [ ] No test framework install needed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Operator runs the three guard rehearsals and then the live `--apply` themselves (22-03 Task 1, `checkpoint:human-verify`, `gate="blocking"`) | VAL-02 | Two separate reasons, both measured: the write is irreversible-ish on a real repository's branch protection, AND the executor's auto-mode Bash classifier has denied `bash scripts/set-required-checks.sh` twice (20-07, 20-10). Planning around the denial would stall the phase mid-flight with a partially-applied ruleset | Claude presents four fully-substituted commands with expected exit codes 4, 5, 2 and 0; the operator runs them, halts before command 4 if any of 1–3 deviates, and pastes all four transcripts. Claude then re-reads the live API in 22-03 Task 2 rather than parsing the paste |

| Operator answers `proceed` or `halt` on the recorded target repository and end state before any write occurs (22-01 Task 1, `checkpoint:decision`, `gate="blocking"`) | VAL-02 | The first writes in this phase (branch push + PR create in 22-01 Task 4, the `GATE_MODE` flip in 22-02 Task 1) land on a real repository the operator uses, and `22-CONTEXT.md` records a decision taken in a planning session that may be separated from execution by arbitrary time. `.claude/rules/defensive-protocol-v2-session-management.md` requires explicit human confirmation before irreversible actions; a planning-time record is not an execution-time confirmation | Claude quotes the three locked decisions from `22-CONTEXT.md` back verbatim, states the two measured second-order effects (the `.github/workflows` 404; the always-added `pull_request` rule removing the direct-push shortcut), enumerates every write `proceed` authorises across plans 01–05, and offers exactly two answers. The operator replies `proceed` or `halt`; the answer is written verbatim to `22-evidence/go-decision.txt` |

Target repository (`terraform-pipelines`) and end state (restore, not keep) were settled by the
operator BEFORE planning and are recorded with their rationale in `22-CONTEXT.md`. Neither choice is
re-opened at any checkpoint in this phase: 22-01 Task 1 is a go/no-go on acting on that record now
(`proceed` / `halt` only, no alternative target and no alternative end state offered), and 22-03
Task 1 is not a decision point about either. A request for a different target or a different end
state is a `22-CONTEXT.md` amendment and a replan, not a checkpoint answer.

---

## Validation Sign-Off

- [x] All 14 tasks across the six plans carry an `<automated>` verify block; no task relies on narration — including both checkpoints (22-01 Task 1 greps `go-decision.txt`; 22-03 Task 1 greps the rehearsal transcripts)
- [x] Sampling continuity: every plan's final task ends in an automated assertion, so no three consecutive tasks pass without one
- [x] Wave 0 covers all MISSING references — evidence dir, settle-poll helper, verdict-assertion helper and the exit-2 fixture are each created in a named task before the task that asserts against them
- [x] No watch-mode flags. Run waits are bounded `gh run list` polls, never `gh run watch --exit-status` — the blocking run FAILS by design and an exit-status wait would score the expected outcome as a failure
- [x] Feedback latency < 30s for every offline gate; live API round-trips and workflow completion are network- and CI-bound and are bounded by explicit, loudly-failing polls
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** planned 2026-09-16 — `wave_0_complete` flips to true when 22-01 Task 2 and 22-02 Task 2 have run.
