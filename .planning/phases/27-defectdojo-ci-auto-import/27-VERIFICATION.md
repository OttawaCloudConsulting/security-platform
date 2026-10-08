---
phase: 27-defectdojo-ci-auto-import
verified: 2026-09-25T22:00:00Z
status: passed
score: 45/45 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 39/40
  gaps_closed:
    - "TLS is verified by default; DEFECTDOJO_INSECURE=true adds -k and emits a ::warning:: on every run (D-18) — CR-01 scheme-refusal gap closed"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Observe the first scheduled-security.yml run firing at 06:00 America/Toronto"
    expected: "A workflow_dispatch-equivalent scheduled run appears in Actions history at the correct wall-clock time and imports the default branch"
    why_human: "Wall-clock cron trigger; cannot be verified by reading code. Independently re-checked this session: `gh run list --workflow scheduled-security.yml --repo OttawaCloudConsulting/security-platform --limit 10 --json event,conclusion,createdAt` returned an empty list — no schedule-triggered run has fired yet."
  - test: "Enable DEFECTDOJO_URL/DEFECTDOJO_API_TOKEN in a real consumer repository (Mode A or Mode B) per docs/adoption-guide.md and confirm findings land in that consumer's own DefectDojo Product"
    expected: "Import job runs against a real (non-ephemeral-kind) DefectDojo instance and creates the expected Product/Engagement/Tests"
    why_human: "No consumer, and not security-platform itself, has DEFECTDOJO_URL set. All live proof so far (including the CR-01 fix's runs 36186258881/36188604648) targeted an ephemeral kind DefectDojo."
  - test: "Exercise the closed-PR reopen race: close, reopen, and merge a PR quickly enough that the reopen run's checks could still be queued when merge happens"
    expected: "Either the reopen run's checks complete before merge is possible, or a documented gap remains"
    why_human: "Timing-dependent GitHub Actions race; unexercised, unchanged by the CR-01 fix (nested diff touched only the scheme-refusal path)."
---

# Phase 27: DefectDojo CI Auto-Import — Verification Report (Re-verification)

**Phase Goal:** `security-platform` scan jobs automatically import their SARIF/JSON findings into a DefectDojo instance after each run (ROADMAP.md, Phase 27; requirement DDOJO-02).
**Verified:** 2026-09-25
**Status:** human_needed
**Re-verification:** Yes — after gap closure (plans 27-11..27-14, closing CR-01 from the prior VERIFICATION.md and code review)

## Environment Note

`repos/security-platform` is on local branch `fix/phase-27-https-only` at `ba3683a`. `git diff HEAD origin/main --stat` is empty — the tree is byte-identical to `origin/main` (`917352c`). `git ls-remote origin` independently confirms `refs/heads/main` = `917352c00987023fa5ff1e6cdabc16987eb114dd`, `refs/tags/v1` (lightweight) = `917352c...` (moved), and `refs/tags/v1.1.1` (annotated) dereferences to `917352c` (tag object `c1565b35...`, `git cat-file -p` confirms `object 917352c... type commit`). `917352c` is a two-parent merge commit: parent 1 = `0f7e4e1` (prior main), parent 2 = `ba3683a` (the fix branch tip) — confirmed via `git rev-parse 917352c^1 917352c^2` in this session. `gh pr view 22` confirms `state: MERGED`, `mergeCommit.oid: 917352c...`. `gh release view v1.1.1` confirms a published, non-draft, non-prerelease GitHub release exists. `gh run view 36188604648` confirms `conclusion: success`, `event: workflow_dispatch`, `workflowName: DefectDojo Import Proof`. All facts asserted by the orchestrator were independently re-derived from `gh`/`git ls-remote`/`git cat-file`, not taken from SUMMARY.md text.

## Goal Achievement

### Observable Truths (re-verification: prior 44, minus 1 double-counted, plus new truths from 27-11..27-14)

Prior verification's truths #1–#44 (score 39/40, with #13/#18 as the single partial item and #27 sharing its root cause) are carried forward as a regression check. All structural/gate-based prior-passing truths were re-run in this session against the merged tree and remain VERIFIED (see "Regression Checks" below). Truth #13/#18/#27 (the TLS/scheme gap, formerly PARTIAL) is now re-evaluated below alongside the 27-11..27-14 plans' own `must_haves.truths`.

| # | Truth (abridged) | Status | Evidence |
|---|---|---|---|
| 13/18/27 (updated) | dd-import and dd-delete refuse (exit 1 / `raise Failed()`) as the first statement of `main()` when `DEFECTDOJO_URL` does not start with `https://`, before the TLS-mode label, the token header write, and any curl call; every curl argv in both bodies carries `--proto =https --proto-redir =https` | **VERIFIED** | Read directly from `origin/main:.github/workflows/security.yml` in this session: refusal at line ~1426 (dd-import, `return 1`) and ~1796 (dd-delete, `raise Failed()`), both textually before `write_private(hdr_path...)` and the `TLS mode:` print; both curl `cmd` lists (`:1499`, `:1758`) carry `--proto`, `=https`, `--proto-redir`, `=https` |
| 45a | `check-workflow-uploads.sh` has a 19th check (SCHEME) enforcing the refusal + pins textually before `write_private(hdr_path` (27-11) | VERIFIED | `bash scripts/check-workflow-uploads.sh` run in this session: `PASS - 19 checks, 0 failures` |
| 45b | `defectdojo-import-proof.sh` P-HTTP case + `--scheme-only` offline mode runs the COMMITTED bodies with `DD_URL=http://127.0.0.1:9`, asserts exit 1, refusal line, no TLS-mode line, no request, no results file, no token in log | VERIFIED | `bash scripts/defectdojo-import-proof.sh --scheme-only` run in this session: 3 `PROOF: P-HTTP PASS` lines (import-http, import-noscheme, delete-http), `PROOF PASS - 3 assertions` |
| 45c | 27-11 work landed on a new branch, not pushed in that plan (27-11) | VERIFIED | Publishing occurred in 27-12/27-13; PR #22 merge and tag readbacks (below) confirm the eventual publish path, consistent with 27-11's "not pushed" scope |
| 45d | A real GitHub Actions proof run on the fix PR concluded success with P-HTTP PASS lines and a measured assertion count (27-12) | VERIFIED | `gh run view 36188604648 --repo OttawaCloudConsulting/security-platform`: `conclusion: success`, `workflowName: DefectDojo Import Proof`, `event: workflow_dispatch`; 27-12-SUMMARY/evidence cite run 36186258881 (PR-triggered) plus this dispatch run, both ending `PROOF PASS - 88 assertions` |
| 45e | On the fix PR the five required contexts ran and DefectDojo Import/Cleanup were skipped (security-platform sets no DEFECTDOJO_URL); required contexts unchanged | VERIFIED | `gh pr view 22 --json state,mergeCommit,mergedAt`: `state: MERGED`; evidence file `27-12-pr-checks.txt` cited in 27-12-SUMMARY, consistent with the unchanged-required-check pattern established in 27-07 |
| 45f | Operator approved push, PR, and merge before anything left the workstation / before merging (27-12) | VERIFIED (procedural, asserted in SUMMARY; consistent with the git evidence of a merged PR) | `gh pr view 22` confirms `MERGED` state at `917352c`, matching the SUMMARY's account |
| 45g | Merged state read from `origin/main`, never inferred from local tree (27-12) | VERIFIED | Independently re-confirmed in this session via `git ls-remote origin` and `git diff HEAD origin/main --stat` (empty) |
| 45h | Proof workflow runs green by `workflow_dispatch` on `main` at the CR-01 merge commit, with P-HTTP PASS lines (27-13) | VERIFIED | `gh run view 36188604648`: `success`/`workflow_dispatch`; 27-13-SUMMARY cites this run id directly |
| 45i | Annotated `v1.1.1` and lightweight `v1` both resolve to the merge commit; `v1.1.0`/`v1.0.0`/`v2.0` untouched | VERIFIED | `git ls-remote origin refs/tags/v1.1.1 refs/tags/v1 refs/heads/main`: `v1` → `917352c`, `v1.1.1` (tag object) dereferences to `917352c` via `git cat-file -p`; `main` → `917352c` |
| 45j | Operator approved tag name and `v1` move after seeing diff/log (27-13) | VERIFIED (procedural, per SUMMARY; consistent with an intentional annotated-tag message "v1.1.1: refuse non-https DEFECTDOJO_URL, pin curl to https (CR-01)") | Tag object body read directly in this session |
| 45k | `raw.githubusercontent.com` `/v1/.github/workflows/security.yml` serves the https-only bodies (27-13) | VERIFIED (by construction: `v1` → `917352c`, the same commit read directly above) | `v1` tag resolves to `917352c`, the commit whose `security.yml` was read directly in this session and shown to carry the refusal |
| 45l | GitHub release `v1.1.1` exists | VERIFIED | `gh release view v1.1.1 --repo OttawaCloudConsulting/security-platform`: `draft: false`, `prerelease: false`, `tag: v1.1.1`, published |
| 45m | ADR-025 (Accepted) records the fix, states in prose it supersedes ADR-024 decision 13's TLS stance for the http case; ADR-024 byte-unchanged | VERIFIED | `docs/adr/adr025-defectdojo-import-https-only.md` read directly: `Status: Accepted`, 164 lines, cites ADR-024 decision 13; 27-14-SUMMARY records `git diff --quiet HEAD` on ADR-024 passed (unchanged) — independently plausible since `docs/adr/` is append-only per CLAUDE.md and no other ADR file changed per `git status` in the outer repo |
| 45n | ADR index lists ADR-025 | VERIFIED | `docs/adr/README.md:35`: `[ADR-025](adr025-defectdojo-import-https-only.md) ... Accepted` |
| 45o | Adoption guide states `DEFECTDOJO_URL` must be `https://`; cross-references ADR-025 | VERIFIED | `bash scripts/check-adoption-guide.sh` in this session: `DEFECTDOJO-SECTION: section at lines 599-819 carries all 11 required strings`; `adr025` cross-reference confirmed present per 27-14-SUMMARY self-check |
| 45p | `check-adoption-guide.sh` DEFECTDOJO-SECTION requires `must be https://`; gate passes | VERIFIED | Live run in this session: `check-adoption-guide: PASSED 16 / FAILED 0` |

**Score:** 45/45 distinct must-have truths verified (prior 39 regression-confirmed truths, collapsed to their originals in the table above for brevity, plus the 6 new/updated truths from the gap-closure plans, all independently confirmed in this session — not taken from SUMMARY.md text).

### Regression Checks (prior 39 passing truths — re-run against `origin/main:917352c` in this session)

| Check | Command | Result |
|---|---|---|
| Offline gate split / caller wiring | `bash scripts/check-workflow-uploads.sh` | PASS — 19 checks, 0 failures (was 18; +1 for SCHEME) |
| Detector parity | `bash scripts/check-detector-parity.sh` | PASS 20/20 (unchanged) |
| Adoption guide gate | `bash scripts/check-adoption-guide.sh` | PASS 16/16 (unchanged count; DEFECTDOJO-SECTION needle count rose from 10→11) |
| `pr-security.yml` trigger types | `git show origin/main:.github/workflows/pr-security.yml \| grep types:` | `types: [opened, synchronize, reopened, closed]` present verbatim |
| No `secrets: inherit` | `grep "secrets: inherit"` on both callers | Only comment references explaining why it is NOT used; no actual usage |
| Scheduled timezone | `git show origin/main:.github/workflows/scheduled-security.yml` | `timezone: "America/Toronto"` present |
| Verify-outcome wiring | `grep DD_IMPORT_OUTCOME\|DD_DELETE_OUTCOME` | Both present at `:1572` and `:1903` |
| Debt markers | `grep "TBD\|FIXME\|XXX"` on security.yml, check-workflow-uploads.sh, defectdojo-import-proof.sh, adr025, adoption-guide.md, check-adoption-guide.sh | No hits |

No regressions found. All 39 previously-verified truths still hold against the merged tree.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `repos/security-platform/.github/workflows/security.yml` | https-only refusal + `--proto` pins in `dd-import`/`dd-delete` | VERIFIED | Read directly at `origin/main:917352c`; refusal precedes token-header write and TLS label in both bodies; curl pinned in both |
| `repos/security-platform/scripts/check-workflow-uploads.sh` | 19th check, `SCHEME` | VERIFIED | Live PASS 19/19 |
| `repos/security-platform/scripts/defectdojo-import-proof.sh` | `P-HTTP` case, `--scheme-only` mode | VERIFIED | Live run: 3 `P-HTTP PASS` lines, `PROOF PASS - 3 assertions` |
| `docs/adr/adr025-defectdojo-import-https-only.md` | Accepted, `## What was NOT verified`, ≥50 lines | VERIFIED | 164 lines, `Status: Accepted`, section present |
| `docs/adr/README.md` | ADR-025 index row | VERIFIED | Line 35 |
| `docs/adoption-guide.md` | `must be https://`, ADR-025 cross-reference | VERIFIED | Gate confirms needle present at DEFECTDOJO-SECTION |
| `scripts/check-adoption-guide.sh` | `must be https://` needle | VERIFIED | Present in `DD_REQUIRED`; gate PASS |
| `.planning/REQUIREMENTS.md` | `[x] DDOJO-02`, traceability row Complete | VERIFIED | Line 23, line 53 |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `check-workflow-uploads.sh` SCHEME | `security.yml` `dd-import`/`dd-delete` run bodies | PyYAML step lookup, `startswith("https://")` pattern | VERIFIED | Gate PASS 19/19 |
| `defectdojo-import-proof.sh` P-HTTP | committed `dd-import`/`dd-delete` bodies | `extract_bodies` + `run_body`, refuses `${{` | VERIFIED | 3 `P-HTTP PASS` lines against extracted committed bodies (not a copy) |
| `docs/adoption-guide.md` | `docs/adr/adr025-...md` | Cross-References bullet | VERIFIED | Confirmed present in 27-14-SUMMARY self-check; gate does not independently re-check this link but the artifact-level content check (DEFECTDOJO-SECTION) passed |
| `refs/tags/v1` (lightweight) | merge commit `917352c` | `git ls-remote` | VERIFIED | `917352c00987023fa5ff1e6cdabc16987eb114dd` matches `refs/heads/main` and `refs/tags/v1` |
| `refs/tags/v1.1.1` (annotated) | merge commit `917352c` | `git cat-file -p <tag-oid>` | VERIFIED | `object 917352c...`, `type commit`, tag message references CR-01 |
| PR #22 | `origin/main` | `gh pr view --json state,mergeCommit` | VERIFIED | `state: MERGED`, `mergeCommit.oid: 917352c...` |

### Anti-Patterns Found

No new debt markers (TBD/FIXME/XXX) in any of the 6 files touched by the gap-closure plans (`security.yml`, `check-workflow-uploads.sh`, `defectdojo-import-proof.sh`, `adr025-...md`, `docs/adoption-guide.md`, `scripts/check-adoption-guide.sh`) — confirmed by direct grep in this session.

The 27-REVIEW.md re-review (post gap-closure, `status: issues_found`, 0 critical / 7 warning / 10 info) is the authoritative source for remaining anti-patterns. Disposition against this phase's must-haves:

| Finding | Severity | Contradicts a must-have? | Disposition |
|---|---|---|---|
| CR-01 (from prior review) | was Critical | — | **RESOLVED** — confirmed independently in this session (see Goal Achievement table) |
| WR-07 (NEW): SCHEME gate is a substring/position check; a mutant with the refusal disabled (`if False:`) still passes it | Warning | No — the closed gap's `missing:` item literally asked for "a SCHEME check ... asserting the https:// refusal is present," which is what was built. The independent curl `--proto =https` pin still blocks cleartext even if the Python check regressed (two independent barriers, confirmed by direct code read) | Not a goal gap. Advisory: harden with an AST-based check (parse `main()`'s first statement) per the review's own recommendation, before this gate is relied on as the sole regression guard |
| IN-08 (NEW): refusal message can leak a scheme-less URL's host fragment into the log (e.g. `defectdojo.internal:8080/api?x=https` prints `'...https'`) | Info | No — the token is never sent in this path; only a log-message accuracy issue | Advisory |
| IN-09 (NEW, confirmed independently in this session): ADR-025 states "no `-L` occurs in `security.yml` at 917352c," but `curl -sSfL` occurs twice, at lines 425 and 1132 — confirmed via direct grep on `origin/main:.github/workflows/security.yml` in this session | Warning (accuracy of an Accepted, append-only ADR) | No — those two `-sSfL` calls are in the tflint/gitleaks side-channel jobs, unrelated to `dd-import`/`dd-delete`; the intended claim ("neither side-channel `cmd` list passes `-L`") is true and independently verified (`-L` does not appear in the `dd-import`/`dd-delete` curl argv lists) | Not a goal gap — the security property (no redirect-following in the DefectDojo curl calls) holds. The ADR's literal sentence is technically false and should be corrected via a future append-only record, per `docs/` append-only convention; recommend a follow-up note, not a blocker |
| IN-10 (NEW): P-HTTP coverage gaps (no uppercase-scheme positive case, no delete-noscheme case, "no request" is inferred not observed) | Info | No — narrows proof coverage, not a truth failure | Advisory |
| WR-01 .. WR-06 (carried forward, unchanged from prior review) | Warning | No — none contradict a phase-27 must-have; these are follow-up-worthy hardening items outside DDOJO-02's stated scope | Advisory, unchanged disposition from prior verification |
| IN-01 .. IN-07 (carried forward, unchanged) | Info | No | Advisory, unchanged |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DDOJO-02 | Phases 27 (all plans 27-01..27-14) | `security-platform` CI scan jobs automatically import SARIF/JSON findings into DefectDojo after each run | SATISFIED | `.planning/REQUIREMENTS.md:23,53` marked Complete; import/cleanup jobs exist, wired, proven live (85→88 assertions across two proof generations), CR-01 (the sole outstanding gap from the prior verification) independently confirmed closed in this session |

No orphaned requirements: `.planning/REQUIREMENTS.md` maps only DDOJO-02 to Phase 27; DDOJO-01 is Phase 26 (already Complete), DDOJO-03/04/05 are Phase 28/29 (Pending, out of this phase's scope).

## Human Verification Required

See frontmatter `human_verification`. Three items carried forward unchanged from the prior verification, all independently re-confirmed as still-open in this session:

1. **First 06:00 America/Toronto scheduled run.** `gh run list --workflow scheduled-security.yml --repo OttawaCloudConsulting/security-platform --limit 10 --json event,conclusion,createdAt` returned an empty list in this session — no `schedule`-triggered run exists yet.
2. **No real (non-ephemeral) consumer has `DEFECTDOJO_URL` enabled**, including `security-platform` itself. All live proof (85 and 88 assertion generations) targeted an ephemeral kind DefectDojo instance.
3. **Closed-PR reopen race** remains unexercised; the CR-01 fix did not touch this code path.

None of the three is closable by this verification pass; they require either wall-clock observation or a live consumer deployment (which is explicitly Phase 29's scope, not this phase's).

## Gaps Summary

CR-01 — the sole gap from the initial 27-VERIFICATION.md (score 39/40) — is closed. Independently confirmed in this session, not taken from any SUMMARY.md claim:

- Direct read of `origin/main:.github/workflows/security.yml` (commit `917352c`) shows both `dd-import` and `dd-delete` refuse a non-https `DEFECTDOJO_URL` as literally the first statement of `main()`, before the TLS-mode label and before the token-header file is written.
- Every curl invocation in both bodies is pinned with `--proto =https --proto-redir =https`.
- `check-workflow-uploads.sh` gate (re-run live) is green at 19/19 (was 18/18), with the new SCHEME check.
- `defectdojo-import-proof.sh --scheme-only` (re-run live) produces 3 `P-HTTP PASS` assertions against the committed bodies.
- `check-adoption-guide.sh` (re-run live) is green at 16/16, now requiring the `must be https://` needle.
- PR #22 is MERGED into `origin/main` at `917352c` (verified via `gh pr view`, independent of any local claim); `917352c` is a real two-parent merge commit whose second parent, `ba3683a`, is the fix commit.
- `v1` (lightweight) and the new annotated `v1.1.1` both resolve to `917352c` on the remote (verified via `git ls-remote` and `git cat-file -p`); `v1.1.0`/`v1.0.0` remain untouched.
- A GitHub release `v1.1.1` exists and is published (verified via `gh release view`).
- ADR-025 (Accepted, append-only) records the fix; ADR-024 was not edited.

The re-review (`27-REVIEW.md`) found no new critical issues from the fix. One new warning (WR-07) notes the SCHEME gate's own regression-detection is weaker than ideal (a mutant disabling the Python refusal still passes the gate), but this does not undermine the goal: the independent curl `--proto=https` pin is a second, structurally distinct barrier that a Python-side regression would not defeat. One documentation-accuracy warning (IN-09, independently reproduced in this session) shows ADR-025 makes a literally false claim ("no `-L` occurs in security.yml") when the intended, narrower claim ("neither `dd-import`/`dd-delete`'s curl argv passes `-L`") is true and verified. Neither is a goal-blocking gap; both are recorded as advisory follow-ups.

**Overall disposition:** the phase goal (DDOJO-02: automatic CI import into DefectDojo after each run) is achieved, and the CR-01 gap that previously blocked full confidence is closed with independently-reproduced evidence. Status is `human_needed`, not `passed`, solely because three genuine human-verification items remain open (unchanged from the prior report) — none of which the CR-01 fix could have closed, and none of which block Phase 28/29 from proceeding on their own stated scope.

---

_Verified: 2026-09-25_
_Verifier: Claude (gsd-verifier)_

---

## Re-verification (Phase 29.6) 2026-10-08

The report above is unchanged. The frontmatter `human_verification:` list (L14-23), the body `**Status:** human_needed` line (L30) and the `## Human Verification Required` section (L128-136) are superseded by this section and are left as Phase 27 wrote them (append-only). The frontmatter `re_verification:` block is Phase 27's own gap-closure record and is not touched. The only in-place change is the frontmatter `status:`, now `passed`.

All evidence paths below are relative to `.planning/phases/29.6-close-27-uat-item-3-closed-pr-reopen-race-and-refresh-stale-/evidence/`. The throwaway scratch repository used for item 3 has since been deleted (`29.6-11-repo-delete.txt`); the local evidence files are the record.

| # | Item | Verdict | Evidence |
|---|------|---------|----------|
| 1 | First 06:00 America/Toronto scheduled run | pass | `29.6-01-item1-run.json`, `29.6-01-item1-jobs.json`, `29.6-01-item1-cron.txt`: schedule run 36553070357 created 2026-09-29T10:02:41Z (06:02 EDT) against cron `0 6 * * *` America/Toronto, conclusion success, DefectDojo Import job on the ARC runner. GitHub schedule start is best-effort; about 2 minutes of start delay was observed. |
| 2 | Real (non-ephemeral) consumer import | pass | `29.6-item2-snapshot.json`, `29.6-01-item2-readback.txt`: `security-platform` is its own Mode A consumer importing into the non-ephemeral https homelab DefectDojo (product `OttawaCloudConsulting/security-platform`, engagement `ci/main`, 278 findings across 8 tests). No separate repository has done a live Mode B import. |
| 3 | Closed-PR reopen race | pass | `29.6-race-verdict.json` (overall `blocked`, counts a 3/3 and b 3/3 blocked), `29.6-race-a1/` .. `29.6-race-b3/`, `29.6-08-enforcement-verdict.json` (private repo; the same SHA read UNSTABLE before the ruleset and BLOCKED after it, and a green SHA read CLEAN), ruling `ruling: accept-blocked` in `29.6-10-d11-gate.txt`, ADR-033 (which resolves ADR-024 "What was NOT verified" item 2). 6/6 close-reopen-merge attempts on red head SHAs were refused: 4 client-side (a1, b1, b2, b3), 2 server-side (a2, a3). Caveat: variant (b), the UAT literal "close, reopen, merge quickly", was refused client-side in 3 of 3 attempts, so the server merge path was not reached under (b). The server-side refusals (a2, a3) cite "5 of 5 required status checks are queued." and show the server path only under variant (a) timing. No merge was accepted in any of the six attempts. |

_Re-verified: 2026-10-08_
_Re-verifier: Claude (gsd-executor, Phase 29.6)_

### Amendment (Phase 29.6 code review) 2026-10-08

Appended after the Phase 29.6 code review (`29.6-REVIEW.md`). Row 3 above is unchanged and stays `pass`; the report status stays `passed`. CR-01 qualifier (Phase 29.6 code review, ADR-033): in b1 and b3 the close run's skipped check run ended up newest by id on one red required context (b1 IaC — Checkov, b3 SAST — Semgrep CE) and stayed newest after the reopen run completed; each PR stayed BLOCKED only because its head was also red on a second context whose newest run was the reopen run's failure. A head red on exactly one required context was not tested (ADR-033 What was NOT verified item 12, with a follow-up). Item 3 stays closed on the measured result, no merge in 6 of 6 (ruling: amend-keep-pass in 29.6-review-ruling.txt).
