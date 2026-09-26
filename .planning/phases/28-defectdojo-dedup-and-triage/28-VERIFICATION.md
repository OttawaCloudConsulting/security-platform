---
phase: 28-defectdojo-dedup-and-triage
verified: 2026-09-26T23:08:16Z
status: passed
score: 7/7 must-haves verified (1 by override)
overrides_applied: 1
overrides:
  - must_have: "Deduplication rules configured so repeated findings across scans/tools collapse rather than duplicate (DDOJO-03, ROADMAP Phase 28 goal, literal 'across scans and tools')"
    reason: "Cross-tool SCA collapse (Trivy/pip-audit/NPM Audit reporting the same CVE) was measured impossible in DefectDojo 3.3.200: the three SCA parsers populate hash_code fields incompatibly (vulnerability_ids/component_name/component_version format differs per parser) with no fuzzy matching available (ADR-026 Decision 3, 28-RESEARCH Cross-Tool Measurement). The operator was shown this measured finding and explicitly approved shipping within-tool + cross-branch dedup only, with cross-tool collapse formally descoped, as decision (b) of the merge approval: \"cross-tool SCA collapse not shipped — 3.3.200 cannot, measured; within-tool + cross-branch only (D-01)\" (28-08-SUMMARY Task 1 record, operator reply \"Approved — merge\", no rejected decisions)."
    accepted_by: "operator (via merge-approval record, 28-08-SUMMARY)"
    accepted_at: "2026-09-26T18:55:24Z"
---

# Phase 28: DefectDojo Dedup and Triage — Verification Report

**Phase Goal:** Deduplication rules collapse repeated findings across scans and tools, and a triage workflow for reviewing and dispositioning findings is documented and configured.
**Requirements:** DDOJO-03, DDOJO-04
**Verified:** 2026-09-26T23:08:16Z
**Status:** passed
**Re-verification:** No — initial verification

**Scope note:** Verified against `repos/security-platform` at `origin/main` = `c8027e6784ec631db128f45444c9a8092db9d0a1` (merge of PR #23, parents `917352c` and `c77e4f4`). The local checkout tree (`c77e4f4`) was confirmed byte-identical for every file checked, and `origin/main` itself was read directly (`git show origin/main:<path>`) for the load-bearing checks, not inferred from the local tree. HEAD was briefly detached during this verification to check out `c77e4f4` for a live gate run and was restored to `feature/phase-28-defectdojo-dedup-and-triage` before finishing (no working-tree changes were made or left behind).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1a | Deduplication rules collapse repeated findings across scans (repeated imports of the same branch) | ✓ VERIFIED | `evidence/28-05-local-proof.log` and `evidence/28-07-proof-run.log`: P-DEDUP-BRANCH (4 PASS lines each), P-IDEMPOTENT (1 PASS each), P-DISPOSITION (14 PASS each) — 0 `PROOF: P-* FAIL` lines in either log, all Phase 28 assertion ids have PASS coverage, run ends `PROOF PASS - 127 assertions`. |
| 1b | Deduplication rules collapse repeated findings across tools (cross-tool SCA collapse) | **PASSED (override)** | Measured impossible in DefectDojo 3.3.200 — see override in frontmatter. Within-tool dedup + cross-branch product-wide dedup shipped instead, per D-07 fallback, with operator sign-off. |
| 2 | Triage workflow for reviewing and dispositioning findings is documented and configured | ✓ VERIFIED | `kubernetes/defectdojo/TRIAGE.md` (127 new lines) defines the 6 dispositions, the default-branch-only rule, risk-acceptance procedure, and API examples; `scripts/defectdojo-configure.sh` configures `enable_deduplication=true`, `delete_duplicates=false`, `risk_acceptance_form_default_days=90` idempotently (confirmed present on `origin/main`). |
| 3 | Chart ships dedup guard defaults so a consumer install gets safe dedup behavior without extra config | ✓ VERIFIED | `origin/main:kubernetes/defectdojo/values.yaml` lines 119, 125 carry `DD_DUPLICATE_CLUSTER_CASCADE_DELETE: "False"` and `DD_DEDUPLICATION_ALGORITHM_PER_PARSER` with all 7 scan-type keys; no `DD_HASHCODE_FIELDS_PER_SCANNER` key rendered. |
| 4 | An idempotent bootstrap script exists to turn dedup on post-install (superuser-only API) | ✓ VERIFIED | `origin/main:scripts/defectdojo-configure.sh` exists, invoked with no args via `DEFECTDOJO_URL`/`DEFECTDOJO_ADMIN_TOKEN_FILE`; GET/compare/PATCH-only-drift pattern confirmed by grep for `risk_acceptance_form_default_days` at lines 28, 107, 210; proof log shows P-CONFIGURE PASS then P-IDEMPOTENT PASS (second run: no `CHANGED:` line). |
| 5 | Delete-time re-parenting resolves PR-engagement-to-default-branch duplicate orphaning (D-02) without a cleanup job | ✓ VERIFIED | `evidence/28-07-proof-run.log`: 4 `PROOF: P-REPARENT PASS` lines — ci/main holds K=6 findings with `duplicate=false, active=true` immediately after the PR engagement DELETE, 1 s after DELETE returned, no reimport. |
| 6 | Dispositions (False Positive, Out of Scope, Risk Accepted) survive reimport and are never silently reactivated | ✓ VERIFIED | P-DISPOSITION (14 PASS lines) and P-SUPPRESS (4 PASS lines) in both evidence logs; tuples match TRIAGE.md's documented "Measured" table. |
| 7 | Requirements DDOJO-03 and DDOJO-04 are marked complete and traceable to an ADR | ✓ VERIFIED | `.planning/REQUIREMENTS.md:24-25,54-55` show both `[x]`/Complete; `docs/adr/adr026-...md` exists, is indexed in `docs/adr/README.md:36`, and explicitly names both requirement IDs and the D-07 cross-tool descope in its Decision section. |

**Score:** 7/7 truths verified (6 direct + 1 override)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `kubernetes/defectdojo/values.yaml` | Dedup guard defaults (D-20) | ✓ VERIFIED | Confirmed on `origin/main`, both keys present, wired into `extraConfigs`. |
| `scripts/check-defectdojo-chart.sh` | Checks 21/22 (CASCADE-DELETE-OFF, DEDUP-ALGORITHM-MAP), `CHECK_COUNT=22` | ✓ VERIFIED | Ran live: `bash scripts/check-defectdojo-chart.sh` → `PASS - 22 checks, 0 failures`. |
| `kubernetes/defectdojo/Chart.yaml` | version 0.2.0, appVersion/dependency unchanged | ✓ VERIFIED | `version: 0.2.0`, `appVersion: "3.3.200"`, dependency `1.9.53` confirmed on `origin/main`. |
| `scripts/defectdojo-configure.sh` | Idempotent bootstrap script | ✓ VERIFIED | Present, substantive (241 new lines), exercised live in proof (P-CONFIGURE, P-IDEMPOTENT PASS). |
| `scripts/defectdojo-import-proof.sh` | Phase 28 proof block (9 assertion ids) | ✓ VERIFIED | 1476 new lines; all 9 ids have PASS coverage in both evidence logs, 0 FAIL lines. |
| `.github/workflows/defectdojo-import-proof.yml` | Path filter covers `scripts/defectdojo-configure.sh` and `kubernetes/defectdojo/**` | ✓ VERIFIED | Confirmed via `git show origin/main`, lines 45-53. |
| `kubernetes/defectdojo/TRIAGE.md` | Triage runbook | ✓ VERIFIED | 127 new lines, substantive, contains `ci/<default>` rule, all 6 dispositions, measured tuples, API examples. |
| `kubernetes/defectdojo/README.md` | Bootstrap step, recompute note, values rows, requirement rows | ✓ VERIFIED | Confirmed `DDOJO-02/03/04` rows and ADR-026 reference on `origin/main`. |
| `docs/adr/adr026-...md` + `docs/adr/README.md` row | ADR-026 decision record | ✓ VERIFIED | File exists locally, 1 appended index row, ADR-023/024/025 confirmed byte-unchanged in 28-09-SUMMARY evidence. |
| `docs/adoption-guide.md` + `scripts/check-adoption-guide.sh` | Runbook link + bootstrap needle in gate | ✓ VERIFIED | Ran live: `bash scripts/check-adoption-guide.sh` → `PASSED 16 / FAILED 0`, includes `PASS: DEFECTDOJO-SECTION`. |
| `.planning/REQUIREMENTS.md` | DDOJO-03/04 marked Complete | ✓ VERIFIED | Confirmed both rows `[x]` / Complete. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `defectdojo-import-proof.sh` mode hook | `prove_dedup_triage` | call after `prove_http_refusal`, before `proof_finish` | ✓ WIRED | Confirmed by grep on `origin/main`; Phase 27 assertions (P-COUNTS etc.) run first and pass identically. |
| `README.md` | `TRIAGE.md` | in-repo relative link, `blob/main` public link | ✓ WIRED | `gh api .../contents/kubernetes/defectdojo/TRIAGE.md?ref=main` resolved in 28-09-SUMMARY; needle enforced by `check-adoption-guide.sh`. |
| PR head `c77e4f4` | `security-platform` main | `gh pr merge 23 --merge` | ✓ WIRED | `origin/main` parents confirmed: `917352c` + `c77e4f4` → `c8027e6`. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Chart offline invariants hold on merged code | `bash scripts/check-defectdojo-chart.sh` (run live in this verification, from `repos/security-platform` at `c77e4f4`, tree identical to `origin/main`) | `PASS - 22 checks, 0 failures` | ✓ PASS |
| Adoption-guide gate reflects the Phase 28 runbook link and bootstrap needle | `bash scripts/check-adoption-guide.sh` (run live) | `PASSED 16 / FAILED 0` | ✓ PASS |
| Full kind proof (dynamic, requires a live kind cluster + DefectDojo) | `bash scripts/defectdojo-import-proof.sh <reports-dir>` | N/A — not re-run | ? SKIP (no kind cluster available in this verification session; relied on `evidence/28-05-local-proof.log` and `evidence/28-07-proof-run.log`, both of which record `PROOF PASS - 127 assertions` and 0 `FAIL` lines, and the GitHub Actions run `36261602015` / job `108458517558` independently reproduced the same result) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` convention exists in this repository, and no PLAN/SUMMARY for this phase declares one. The phase's proof mechanism is `bash scripts/defectdojo-import-proof.sh` in `security-platform`, treated above as a spot-check (SKIP — requires a live kind cluster) with independent GitHub Actions confirmation.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DDOJO-03 | 28-01 through 28-05, 28-09 | Deduplication rules configured so repeated findings across scans/tools collapse | ✓ SATISFIED (partial by override) | Within-tool + cross-branch dedup fully verified and measured; cross-tool collapse explicitly descoped and operator-accepted (see override). ADR-026 records this. |
| DDOJO-04 | 28-02, 28-04, 28-06, 28-09 | Triage workflow documented/configured for reviewing and dispositioning findings | ✓ SATISFIED | TRIAGE.md, bootstrap script, and measured disposition-survival proof all present and verified; one known documentation defect (WR-03, below) does not remove the workflow's existence. |

No orphaned requirements: `.planning/REQUIREMENTS.md` maps only DDOJO-03 and DDOJO-04 to Phase 28, and both appear in plan frontmatter (`28-01` through `28-09`).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scripts/defectdojo-configure.sh` | 37-41, 131, 144 | Header claims "TLS is always verified; there is no option to switch it off," but `api()` calls curl without `-q`/`--disable`, so an operator `~/.curlrc` (or `$CURL_HOME/.curlrc`) containing `insecure` silently disables verification for the superuser-token bootstrap. `%{ssl_verify_result}` is never checked, only the HTTP code. Reproduced in code review (CR-01) against a local self-signed TLS server. | ⚠️ WARNING | Does not defeat the literal PLAN 28-02 must-have ("no `-k` and no insecure option") — the script itself sets neither flag. It does falsify the script's own header comment and is a real, reproduced security gap in the one script that sends a superuser token. Second-order risk: Phase 29 (live homelab deployment, likely with a private/self-signed CA) is exactly the scenario where an operator's curlrc could trigger this. **Recommend fixing before Phase 29's live bootstrap runs against the homelab instance.** |
| `kubernetes/defectdojo/TRIAGE.md` | 31, 35, 42, 44, 85 | The canonical "Under Review" API query filters `verified=false`, but Trivy findings arrive `verified=true` on import (documented at line 44), so the canonical query returns zero untriaged Trivy findings — the largest SCA source. The doc self-discloses the caveat but the primary query/state table does not account for it. | ⚠️ WARNING | Does not defeat the literal PLAN 28-06 must-have (the query and disposition table exist as specified and match the plan). It is a genuine workflow design gap for the highest-volume scanner, already flagged in code review (WR-03) with a documented fix path. |
| `scripts/defectdojo-configure.sh` | 181-191, 190-203 | WR-01 (unreadable/directory token file crashes with traceback + exit 1 instead of documented exit 2) and WR-02 (multi-line token file injects extra HTTP headers) — both reproduced in code review, both edge cases of operator error rather than the documented happy path. | ⚠️ WARNING | Does not defeat any stated must-have; operator-input hardening gaps. |
| `scripts/defectdojo-import-proof.sh` | 665-677, 704 | WR-04: P-HTTP configure-case PASS text claims "refused before the token file is read" without proving the order (both cases point at a valid token file, so a regression that reordered the checks would still pass). | ℹ️ INFO | Test-assertion precision issue, not a functional gap. |

No `TBD`, `FIXME`, or `XXX` debt markers found in any file modified by this phase (checked via grep across all 9 plans' `files_modified` lists plus the diff-stat files; the one incidental `XXXXXX` match is `mktemp`'s template placeholder, not a marker).

### Human Verification Required

None. The two `<human-check>` blocks in this phase's PLANs (28-07 push/PR approval, 28-08 merge approval) are outward-facing, irreversible-action gates that were already executed and closed during the phase: both record the operator's verbatim reply ("Approved — merge" for 28-08; equivalent approval recorded in 28-07-SUMMARY for the push/PR) with no rejected decisions, and the resulting state (PR merged, checks green) is independently confirmed above from `origin/main` and the GitHub Actions API. There is nothing outstanding to route to a human for this phase.

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Live, homelab-deployed end-to-end proof of dedup/triage against a real ArgoCD-managed DefectDojo instance | Phase 29 | Phase 29 goal (ROADMAP.md line 220): "CI import (Phase 27) with dedup/triage (Phase 28) is proven live end-to-end against that deployment." |
| 2 | Risk-acceptance expiry reactivation (Celery beat, 3 h) | Not yet scheduled | TRIAGE.md and ADR-026 both state this is "read from the 3.3.200 source" but "not exercised in the proof" — explicitly and honestly documented as unverified, not a gap in this phase's scope. |

### Gaps Summary

No unresolved gaps. One must-have (cross-tool SCA collapse, part of the literal DDOJO-03/ROADMAP wording "across scans and tools") required an override because it was measured technically impossible in DefectDojo 3.3.200 and the operator explicitly accepted the narrower within-tool + cross-branch scope at merge approval, with the descoping fully documented in ADR-026. Two known, code-reviewed defects (CR-01 TLS/curlrc, WR-03 Trivy Under-Review query) do not defeat any literal stated must-have but are real, reproduced issues worth tracking — CR-01 in particular should be fixed before Phase 29 exercises the bootstrap script against a real homelab TLS endpoint. Public-facing documentation (`kubernetes/defectdojo/README.md:53`, `.planning/REQUIREMENTS.md:24`) still states the requirement as "across scans and tools" without qualifying the cross-tool descope inline — readers must consult ADR-026 for the caveat. This is a minor documentation-clarity gap, not a functional one.

---

_Verified: 2026-09-26T23:08:16Z_
_Verifier: Claude (gsd-verifier)_
