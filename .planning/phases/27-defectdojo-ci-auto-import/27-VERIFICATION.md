---
phase: 27-defectdojo-ci-auto-import
verified: 2026-09-25T18:00:00Z
status: gaps_found
score: 39/40 must-haves verified
overrides_applied: 0
gaps:
  - truth: "TLS is verified by default; DEFECTDOJO_INSECURE=true adds -k and emits a ::warning:: on every run (D-18)"
    status: partial
    reason: >
      The https path is genuinely verified (curl's default TLS verification, `--cacert` for
      DEFECTDOJO_CA_CERT, `-k` + `::warning::` for DEFECTDOJO_INSECURE=true — all confirmed in
      security.yml and exercised by the 27-06/27-07 proof). But `dd-import` and `dd-delete` do
      no scheme check on DEFECTDOJO_URL. A plain `http://` URL falls into the `else` branch,
      is labelled `tls_mode = "verified-system"`, and the job prints "TLS mode: verified-system"
      even though no TLS exists at all. The Authorization header carrying the instance-wide
      staff token is then sent in cleartext on every import and every cleanup call. This is
      code review CR-01 (critical), confirmed independently by reading
      repos/security-platform/.github/workflows/security.yml:1424-1436 in the merged tree
      (identical on origin/main). It is not listed in ADR-024's "What was NOT verified"
      (9 items, none mention scheme/http/cleartext) or its "Consequences"/known-gaps text, and
      no VERIFICATION override was recorded. docs/adoption-guide.md's two DEFECTDOJO_URL
      examples both happen to use https://, but the guide never states https is required, and
      check-workflow-uploads.sh's INSECURE-WARNING check only greps for the literal
      DD_INSECURE/::warning:: strings, so it cannot catch a missing scheme check. This does not
      defer to Phase 28 (dedup/triage) or Phase 29 (homelab live validation) — Phase 29's
      tunnel/internal-service URL is exactly the shape most likely to be entered as http://, so
      the gap is live risk at the point DDOJO-05 begins, not something Phase 29's scope closes
      on its own.
    artifacts:
      - path: "repos/security-platform/.github/workflows/security.yml"
        issue: "dd-import (~:1384-1498) and dd-delete (~:1716-1815) accept DEFECTDOJO_URL with any scheme; no https:// refusal, no curl --proto/--proto-redir pin"
    missing:
      - "Refuse to proceed (exit 1 / raise Failed()) in both dd-import and dd-delete when DEFECTDOJO_URL does not start with https://, before the header file is written"
      - "Pin curl to https with --proto =https --proto-redir =https in both bodies"
      - "Add a SCHEME check to check-workflow-uploads.sh asserting the https:// refusal is present in both committed bodies"
      - "Add a P-HTTP proof case asserting exit 1 and that no HTTP request is made for a plain-http DEFECTDOJO_URL"
      - "Record the fix (or, if deferred, the deferral) in ADR-024 via an append — new dated entry or ADR-025, not an edit to the Accepted body"
deferred: []
human_verification:
  - test: "Observe the first scheduled-security.yml run firing at 06:00 America/Toronto"
    expected: "A workflow_dispatch-equivalent scheduled run appears in Actions history at the correct wall-clock time and imports the default branch"
    why_human: "Wall-clock cron trigger; cannot be verified by reading code or by a same-day check. ADR-024 'What was NOT verified' item 7 records this as unobserved as of 2026-09-25."
  - test: "Enable DEFECTDOJO_URL/DEFECTDOJO_API_TOKEN in a real consumer repository (Mode A or Mode B) per docs/adoption-guide.md and confirm findings land in that consumer's own DefectDojo Product"
    expected: "Import job runs against a real (non-ephemeral-kind) DefectDojo instance and creates the expected Product/Engagement/Tests"
    why_human: "No consumer, and not security-platform itself, has DEFECTDOJO_URL set (ADR-024 'What was NOT verified' item 6). All live proof so far targeted an ephemeral kind DefectDojo."
  - test: "Exercise the closed-PR reopen race: close, reopen, and merge a PR quickly enough that the reopen run's checks could still be queued when merge happens"
    expected: "Either the reopen run's checks complete before merge is possible, or a documented gap remains"
    why_human: "Timing-dependent GitHub Actions race; ADR-024 'What was NOT verified' item 2 records this as unexercised. Cannot be produced deterministically by grep or static reasoning."
---

# Phase 27: DefectDojo CI Auto-Import — Verification Report

**Phase Goal:** `security-platform` scan jobs automatically import their SARIF/JSON findings into a DefectDojo instance after each run (ROADMAP.md, Phase 27; requirement DDOJO-02).
**Verified:** 2026-09-25
**Status:** gaps_found
**Re-verification:** No — initial verification

## Environment Note

`repos/security-platform` is a separate nested git repo, checked out on `feature/phase-27-defectdojo-ci-auto-import` at `7c47270`. `git diff HEAD origin/main --stat` from that repo produced no output — the working tree is byte-identical to `origin/main` (`0f7e4e1`, the PR #21 merge commit). All file reads and gate runs below therefore reflect the real merged/released state, not an unmerged local draft. `v1` (lightweight tag) and `v1.1.0` (annotated tag, dereferenced) both resolve to `0f7e4e1`; `v1.0.0` is untouched at `fabc3e3` → `cdf2c21`.

## Goal Achievement

### Observable Truths

Consolidated from the ten plans' `must_haves.truths` (all tagged `requirements: [DDOJO-02]`). Grouped by plan; the phase goal is the union of these.

| # | Truth (abridged) | Status | Evidence |
|---|---|---|---|
| 1 | Offline gate splits 5 frozen scan jobs from 2 side-channel jobs; any other job id fails it (27-01) | VERIFIED | `check-workflow-uploads.sh` contains `SIDE_CHANNEL_JOB_IDS` (9 hits); `PASS - 18 checks, 0 failures` on live run against merged tree |
| 2 | Side-channel jobs can never enter the required-check set (27-01) | VERIFIED | Same gate run, PASS; no `set-required-checks.sh` reference to side-channel names found |
| 3 | Gate enforces side-channel shape: needs, opt-in var, no `${{` in run bodies, red verify, insecure ::warning:: (27-01) | VERIFIED | Extract/parity confirmed directly: `defectdojo-import-proof.sh --extract-only` reports "no ${{" for all 5 extracted step bodies, contract env names match |
| 4 | SHA-PIN/PERMISSIONS-FORBIDDEN cover every workflow file (27-01) | VERIFIED | `check-workflow-uploads.sh` PASS run covers 18 checks across all workflow files (no failures) |
| 5 | Adoption-guide gate derives 5 contexts from scan-job ids only (27-01) | VERIFIED | `check-adoption-guide.sh` output: "DERIVED contexts (5)" from job ids; `scripts/check-adoption-guide.sh` contains `SCAN_JOB_IDS` (2 hits) |
| 6 | Both gates exit 0 on unchanged security.yml/pr-security.yml (27-01) | VERIFIED | Both gates run PASS in this session (exit 0) |
| 7 | `defectdojo-import` job exists, needs all 5 scans, `always()`, downloads artifacts, one curl per report to `reimport-scan/` (27-02) | VERIFIED | `security.yml` contains `defectdojo-import:`; `defectdojo-import-proof.sh --extract-only` extracted `dd-import` (182 lines) referencing `reimport-scan` contract |
| 8 | Import opt-in: skipped when `vars.DEFECTDOJO_URL` empty; `dd-gate` skips cleanly without token (27-02) | VERIFIED | 27-07 evidence: PR checks show `security / DefectDojo Cleanup … skipped`/`scans / DefectDojo Cleanup … skipped` on a run where `security-platform` sets no `DEFECTDOJO_URL`; proof harness P-GATE-style cases pass locally and on GitHub |
| 9 | Token only in `dd-gate`/`dd-import` step env, never job-level, never on argv (27-02) | VERIFIED | Extractor's env-name contract check passes; code review (independent, adversarial) confirms token sent via `-H @<file>`, never echoed |
| 10 | Import step continue-on-error; dd-verify fails red unless every attempted file returned HTTP 201 + test_id; not a required check (27-02) | VERIFIED | `security.yml:1567` `DD_IMPORT_OUTCOME: ${{ steps.dd-import.outcome }}` present; job absent from required-check set per truth #2 |
| 11 | Product/Product Type/Engagement naming and per-file Test titles, `auto_create_context=true` (27-02) | VERIFIED | 27-06 local proof P-CONTEXT/P-TESTS pass; confirmed again on GitHub proof runs 36156728300 and 36160366711 |
| 12 | Each report uses its native `scan_type`; tflint imports as SARIF (27-02) | VERIFIED | 27-06/27-07 proof P-TESTS asserts expected `scan_type` per file, both local and GitHub |
| 13 | **TLS verified by default; INSECURE adds `-k` + `::warning::` on every run (D-18)** (27-02) | **PARTIAL — see Gaps** | https path independently confirmed correct (curl default verify, `--cacert`, `-k`+warning all present and proof-tested); **no scheme check** — a plain `http://` URL is silently labelled `verified-system` and sends the staff token in cleartext (CR-01, confirmed by direct code read of `security.yml:1424-1436`, present in the merged tree) |
| 14 | On `pull_request` `closed`, none of the 5 scan jobs runs; ids/names unchanged (27-02) | VERIFIED | 27-07/27-08 evidence: closed-event run skips the five `security / …` contexts (skipped check-run alongside the earlier success) |
| 15 | `defectdojo-cleanup` DELETEs the closing PR's `ci/<head-branch>` engagement on close/abandon (27-03) | VERIFIED | `security.yml` contains `defectdojo-cleanup:`; 27-06 proof P-CLEANUP passes (14 references in proof script) against a live DefectDojo |
| 16 | Delete targets exact-name engagement in the exact-name product only; refuses empty head/default branch; no-op on no match (27-03) | VERIFIED | 27-06 proof P-SCOPE/P-REFUSE/P-NOMATCH pass locally and on GitHub (36156728300); code review independently confirms guard logic is correct as written |
| 17 | Cleanup opt-in, same dd-gate, continue-on-error + red verify, never required (27-03) | VERIFIED | `DD-GATE-IDENTICAL` PASS in `check-detector-parity`-adjacent extract check; `DD_DELETE_OUTCOME: ${{ steps.dd-delete.outcome }}` present at `security.yml:1893` |
| 18 | Cleanup shares product naming/TLS/insecure-warning rules with import (27-03) | VERIFIED (with same caveat as #13) | `DD-GATE-IDENTICAL` PASS; same scheme-check gap applies symmetrically to `dd-delete` (see Gaps) |
| 19 | `pr-security.yml` triggers on `[opened, synchronize, reopened, closed]`; frozen id/name/permissions unchanged (27-04) | VERIFIED | `pr-security.yml:36` `types: [opened, synchronize, reopened, closed]` present verbatim |
| 20 | Both callers pass `DEFECTDOJO_API_TOKEN` explicitly via `secrets:`, never `inherit`, no `DEFECTDOJO_*` in `with:` (27-04) | VERIFIED | `scheduled-security.yml:70` `DEFECTDOJO_API_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }}`; no `secrets: inherit` found in either caller |
| 21 | `scheduled-security.yml` scans/imports default branch daily 06:00 America/Toronto + `workflow_dispatch` (27-04) | VERIFIED (schedule fired unobserved — see Human Verification) | `scheduled-security.yml:38` `timezone: "America/Toronto"`; cron and `workflow_dispatch` present; ADR-024 item 7 explicitly notes the first real firing is unobserved |
| 22 | Gate now REQUIRES both side-channel jobs, closed-skip, caller wiring; nothing passes vacuously (27-04) | VERIFIED | `check-workflow-uploads.sh` contains `CALLER-WIRING` (17 hits); live PASS run |
| 23 | Kind smoke gains optional post-hook, no-op when unset (27-05) | VERIFIED | `defectdojo-live-smoke.sh` contains `DD_SMOKE_POST_HOOK` (7 hits) |
| 24 | Proof harness executes the COMMITTED step bodies, never a copy; refuses any body with `${{` (27-05) | VERIFIED | `--extract-only` run in this session: "no ${{" asserted for all 5 extracted bodies from the actual merged `security.yml` |
| 25 | Import proven with dedicated `is_staff=true, is_superuser=false` user (27-05) | VERIFIED | 27-06 evidence log; ADR-024 "What was NOT verified" preamble explicitly reconfirms this as *measured*, not assumed |
| 26 | Run 1 asserts product/type/engagement/Test-per-file/counts (27-05) | VERIFIED | 27-06 local log and GitHub runs 36156728300 / 36160366711, `PROOF PASS - 85 assertions` |
| 27 | TLS verified via `DEFECTDOJO_CA_CERT`/kind CA, never `-k` except explicit insecure path, host resolution via `.curlrc` (27-05) | VERIFIED for the exercised https/CA path (same CR-01 caveat applies to the unexercised http path) | 27-06 log shows `tls_mode: insecure` only under explicit `DD_INSECURE=true`; P-TLS assertions pass |
| 28 | Token-absent and Dependabot gate paths proven via committed `dd-gate` body (27-05) | VERIFIED | Proof harness executes committed `dd-gate` (12 lines, extracted and asserted `no ${{`) |
| 29 | Reimport is idempotent: second import creates 0 findings, unchanged totals/Test count (27-06) | VERIFIED | 27-06 log: "P-RUN2: created 0 for all 8 files, 8 Tests" |
| 30 | Cleanup deletes only target engagement incl. hostile branch name, refuses default branch, no-op on non-existent branch (27-06) | VERIFIED | 27-06 log shows hostile branch name `@dd-proof/$(touch pwned)` produced a literal engagement name with no `pwned` file created (P-HOSTILE) |
| 31 | Scheduled-event import resolves branch from `GITHUB_REF_NAME`, creates `ci/<default>` (27-06) | VERIFIED | Proof script and ADR-024 evidence section both cite this case as exercised |
| 32 | `DEFECTDOJO_INSECURE=true` prints `::warning::` with zero network calls made (27-06) | VERIFIED | 27-06/27-07 logs: "P-INSECURE PASS … insecure attempted=0 skipped=8: no request was made" |
| 33 | `defectdojo-import-proof.yml` triggers on `workflow_dispatch` + path-filtered PRs; runs real scanners then the harness (27-06) | VERIFIED | `defectdojo-import-proof.yml:42` `workflow_dispatch: {}`; `:122` `run: bash scripts/defectdojo-import-proof.sh dd-reports` |
| 34 | Complete harness passed locally end-to-end against kind, evidence retained (27-06) | VERIFIED | `evidence/27-06-local-proof.log` exists, ends "PROOF PASS - 85 assertions" / "ALL PASS" |
| 35 | Real GitHub Actions proof run concluded success, recorded with run id (27-07) | VERIFIED | `evidence/27-07-proof-run.log` ends "PROOF PASS - 85 assertions"; run ids 36156728300 and 36160366711 cited in ADR-024 and 27-VALIDATION.md |
| 36 | On that PR, 5 required contexts ran and import/cleanup were skipped (opt-out proven live) (27-07) | VERIFIED | `evidence/27-07-pr-checks.txt`: `security / DefectDojo Cleanup … skipped`, all 5 `security / …` contexts `success` |
| 37 | Operator approved push/PR before anything left the workstation; approved merge; merged state read from `origin/main` (27-07) | VERIFIED (asserted in SUMMARY/evidence; procedural, not independently re-observable) | 27-07/27-08 evidence quote `git fetch origin && git rev-parse origin/main` output matching the PR merge SHA |
| 38 | Closed-event skip on merge; proof green via `workflow_dispatch` on main; v1.1.0 + v1 additive tag; operator approved tag/move (27-08) | VERIFIED | `evidence/27-08-post-merge.txt`: tag readbacks match (`v1` and `v1.1.0` → `0f7e4e1`; `v1.0.0` untouched); confirmed independently in this session via `git rev-parse v1 v1.1.0 v1.0.0` |
| 39 | Adoption guide documents the DefectDojo import switch, secret, optional vars, callers, token permission, reachability note (27-09) | VERIFIED | `bash scripts/check-adoption-guide.sh` PASS in this session: `DEFECTDOJO-SECTION: section at lines 599-813 carries all 10 required strings` |
| 40 | `check-adoption-guide.sh` stays green and asserts the section's presence/content (27-09) | VERIFIED | Live gate run in this session: `check-adoption-guide: PASSED 16 / FAILED 0` |
| 41 | ADR-024 records shape, naming, TLS stance, versioning, cites only measured values, has "What was NOT verified" (27-10) | VERIFIED | ADR file read directly: 268 lines (≥80 required), contains `## What was NOT verified` with 9 enumerated items, each citing a run id/evidence file |
| 42 | ADR index lists ADR-024; no accepted ADR edited (27-10) | VERIFIED | `docs/adr/README.md:34` lists ADR-024 row |
| 43 | DDOJO-02 marked Complete only after remote verification (27-10) | VERIFIED | `.planning/REQUIREMENTS.md:23,53`: `[x] **DDOJO-02**` and traceability row "Complete"; remote tag/commit readbacks independently reconfirmed above |
| 44 | 27-VALIDATION.md signed off only once 27-06/27-07 evidence exists (27-10) | VERIFIED | `27-VALIDATION.md` frontmatter `status: approved`, `nyquist_compliant: true`, sign-off cites run 36156728300 and local 27-06 log |

**Score:** 39/40 distinct must-have truths verified (truth #13/#18 counted once as the single partial item; #27 shares the same root cause and is not double-counted as a separate failure).

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `repos/security-platform/scripts/check-workflow-uploads.sh` | Scan/side-channel split, `SIDE_CHANNEL_JOB_IDS`, `CALLER-WIRING` | VERIFIED | Both strings present; live PASS 18/18 |
| `scripts/check-adoption-guide.sh` (parent) | `SCAN_JOB_IDS`, `DEFECTDOJO-SECTION` | VERIFIED | Both present; live PASS 16/16 |
| `repos/security-platform/.github/workflows/security.yml` | `defectdojo-import:`, `defectdojo-cleanup:` jobs | VERIFIED, with CR-01 caveat on the TLS/scheme path | Jobs present and wired; see Gaps for the scheme-check defect inside `dd-import`/`dd-delete` |
| `repos/security-platform/.github/workflows/pr-security.yml` | `types: [opened, synchronize, reopened, closed]` | VERIFIED | Present verbatim at line 36 |
| `repos/security-platform/.github/workflows/scheduled-security.yml` | `timezone:`, explicit secret pass | VERIFIED | `timezone: "America/Toronto"` and `DEFECTDOJO_API_TOKEN: ${{ secrets.DEFECTDOJO_API_TOKEN }}` present |
| `repos/security-platform/scripts/defectdojo-import-proof.sh` | ≥200 lines, `P-CLEANUP` | VERIFIED | 1359 lines; `P-CLEANUP` appears 14 times |
| `repos/security-platform/scripts/defectdojo-live-smoke.sh` | `DD_SMOKE_POST_HOOK` | VERIFIED | 7 occurrences |
| `repos/security-platform/.github/workflows/defectdojo-import-proof.yml` | `workflow_dispatch` trigger | VERIFIED | `workflow_dispatch: {}` present |
| `.planning/phases/27-defectdojo-ci-auto-import/evidence/27-06-local-proof.log` | `PROOF PASS` | VERIFIED | Present, ends "PROOF PASS - 85 assertions" |
| `.planning/phases/27-defectdojo-ci-auto-import/evidence/27-07-proof-run.log` | `PROOF PASS` | VERIFIED | Present, ends "PROOF PASS - 85 assertions" |
| `.planning/phases/27-defectdojo-ci-auto-import/evidence/27-07-pr-checks.txt` | `security / SAST — Semgrep CE` | VERIFIED | Present with that exact context row |
| `.planning/phases/27-defectdojo-ci-auto-import/evidence/27-08-post-merge.txt` | `v1.1.0` | VERIFIED | Present; tag readbacks match independent verification in this session |
| `docs/adr/adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md` | `## What was NOT verified`, ≥80 lines | VERIFIED | 268 lines; section present with 9 items |
| `docs/adr/README.md` | ADR-024 index row | VERIFIED | Line 34 |
| `.planning/REQUIREMENTS.md` | `[x] **DDOJO-02**` | VERIFIED | Line 23 + traceability row 53 |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `check-workflow-uploads.sh` | `set-required-checks.sh` | negative assertion, no side-channel name/id in CONTEXTS | VERIFIED | Gate PASS; no side-channel string found in `set-required-checks.sh` |
| `scripts/check-adoption-guide.sh` | `security.yml` | context derivation by job id | VERIFIED | Live run: "DERIVED contexts (5)" sourced from job ids, `SIXTH-CONTEXT` PASS |
| `security.yml` `dd-import` | DefectDojo `POST /api/v2/reimport-scan/` | curl multipart, `--form-string`, `-H @<header file>` | VERIFIED | Extracted body (182 lines) matches contract; live proof got HTTP 201 + test_id on both local and GitHub runs |
| `security.yml` `dd-verify` | `steps.dd-import.outcome` | `DD_IMPORT_OUTCOME` step env | VERIFIED | Present verbatim at line 1567 |
| `security.yml` `dd-delete` | DefectDojo `DELETE /api/v2/engagements/{id}/` | exact product + exact engagement lookups | VERIFIED | 27-06 P-SCOPE/P-REFUSE/P-NOMATCH pass live |
| `security.yml` `dd-cleanup-verify` | `steps.dd-delete.outcome` | `DD_DELETE_OUTCOME` step env | VERIFIED | Present verbatim at line 1893 |
| `scheduled-security.yml` | `security.yml` | `uses:` + explicit `secrets: DEFECTDOJO_API_TOKEN` | VERIFIED | Line 70 |
| `docs/adoption-guide.md` | raw.githubusercontent.com `security-platform/v1/...scheduled-security.yml` | pinned `/v1/` fetch | VERIFIED | Gate: `RAW-GITHUBUSERCONTENT-PIN: all 4 raw.githubusercontent.com URL(s) pinned at /v1/`; independently re-fetched in 27-08 evidence, HTTP 200, blob sha matches `origin/main` |
| `docs/adoption-guide.md` | `docs/adr/adr024-...md` | Cross-References bullet | VERIFIED | `adr024` appears in adoption-guide.md (1 hit, in the Cross-References section per 27-09) |

### Gates Run (this session, against the merged/released tree)

| Gate | Command | Result |
|---|---|---|
| Adoption guide | `bash scripts/check-adoption-guide.sh` (parent root) | PASS 16/16, exit 0 |
| Workflow uploads | `bash repos/security-platform/scripts/check-workflow-uploads.sh` | PASS 18 checks, 0 failures |
| Detector parity | `bash repos/security-platform/scripts/check-detector-parity.sh` | PASS 20/20 |
| DefectDojo extract | `bash repos/security-platform/scripts/defectdojo-import-proof.sh --extract-only` | EXTRACT PASS, 7/7 sub-checks, all bodies free of `${{` |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files exist in either the parent repo or `repos/security-platform` (`find … -path '*/tests/probe-*.sh'` returned nothing in both trees). Step 7c: SKIPPED (no probes declared or discovered for this phase).

### Anti-Patterns Found

`grep -n "TBD\|FIXME\|XXX"` was run across all 8 files named in `27-REVIEW.md`'s `files_reviewed_list`, plus `scripts/check-adoption-guide.sh`, `docs/adoption-guide.md`, and `docs/adr/adr024-...md`. No hits (one incidental `XXXXXX` inside a `mktemp` template string in `defectdojo-import-proof.sh:388`, which is a `mktemp` placeholder pattern, not a debt marker). No debt-marker blocker.

The independent adversarial code review (`27-REVIEW.md`, `status: issues_found`, 1 critical / 6 warning / 7 info) is the primary source of anti-pattern findings for this phase, since Step 27-verify does not re-derive a fresh code review. Classification against this phase's must-haves:

| Finding | Severity | Contradicts a must-have? | Disposition |
|---|---|---|---|
| CR-01: plain-`http://` `DEFECTDOJO_URL` sends staff token in cleartext, logs false `verified-system` | Critical | Yes — undermines the D-18 "TLS is verified by default" truth (27-02, 27-03) | **Gap** (see frontmatter) |
| WR-01: `close_old_findings=true` applied even if the producing scan step errored | Warning | No explicit must-have promises report-content validation | Risk — not a phase must-have; recommend follow-up |
| WR-02: import has no default-branch/foreign-head guard (cleanup has one) | Warning | No must-have promises import-side branch guard symmetry | Risk — recommend follow-up, note asymmetry with cleanup's guard |
| WR-03: concurrency group doesn't cover the close-while-scanning race; comment misstates semantics | Warning | Overlaps ADR-024 "What was NOT verified" item 3, but the comment-accuracy issue is unrecorded | Risk — recommend ADR-024 amendment note |
| WR-04: PR engagement keyed by branch name only, colliding across PRs from the same head | Warning | No must-have promises PR-number-level isolation | Risk — recommend follow-up (Phase 28/29 adjacent) |
| WR-05: offline gate checks `if:` shape by substring, not exact match | Warning | "the gate enforces their shape" (27-01 truth #3) is met for the cases the gate does check; substring weakness is a hardening gap, not a truth failure | Risk — recommend follow-up |
| WR-06: proof never exercises 3 of the DELETE guards or the cleanup insecure-TLS path | Warning | No must-have claims 100% guard-path coverage; "PROOF PASS — 85 assertions" overstates coverage in exactly the way IN-flagged | Risk — recommend proof extension |
| IN-01 .. IN-07 | Info | No | Noted, no action required for this verification |

## Human Verification Required

See frontmatter `human_verification`. Summary: (1) the first 06:00 America/Toronto scheduled run has not fired/been observed yet; (2) no consumer repository (including `security-platform` itself) has enabled `DEFECTDOJO_URL` against a real (non-ephemeral) DefectDojo instance; (3) the closed-PR reopen race window was not exercised. All three are already explicitly logged as unverified in ADR-024's "What was NOT verified" section — this report does not discover new unknowns, it cross-references and surfaces them per the escalation-gate pattern.

## Gaps Summary

The phase goal — CI scan jobs automatically importing findings into DefectDojo after each run — is achieved and heavily proven: 10 waves, 85-assertion proof harness run both locally against kind and on real GitHub Actions (run ids 36156728300, 36160366711), a merged PR (#21 → `0f7e4e1`), and an additive `v1.1.0`/`v1` release with verified remote readbacks. 39 of 40 must-have truths verified directly against the merged/released tree (confirmed byte-identical to the local checkout via `git diff HEAD origin/main --stat`).

One gap: the D-18 "TLS verified by default" must-have is true for the intended https path but has an unguarded failure mode — `DEFECTDOJO_URL=http://...` is silently accepted, mislabelled `verified-system`, and sends the instance-wide staff token in cleartext. This is CR-01 from the independent code review, confirmed by direct inspection of the merged workflow file. It is not acknowledged anywhere in ADR-024, not present as a documented known gap, and not covered by a verification override. Given that Phase 29 (homelab live validation) is exactly the phase where a tunnel or internal-service URL — the most likely `http://` misconfiguration — gets entered for the first time, this is live risk sitting at the boundary of the next phase, not a defect that later scope closes on its own. It should be fixed (scheme refusal + `--proto` pin in both `dd-import` and `dd-delete`, a `check-workflow-uploads.sh` SCHEME check, and a P-HTTP proof case) or explicitly accepted via a VERIFICATION override before Phase 29 begins.

---

_Verified: 2026-09-25_
_Verifier: Claude (gsd-verifier)_
