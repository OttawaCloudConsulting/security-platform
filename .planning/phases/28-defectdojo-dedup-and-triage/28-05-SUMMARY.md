---
phase: 28-defectdojo-dedup-and-triage
plan: 05
subsystem: DefectDojo live proof, local kind run (security-platform harness, evidence in this repository)
tags: [defectdojo, deduplication, triage, proof, kind, evidence, DDOJO-03, DDOJO-04]
requires:
  - "28-04: the complete Phase 28 --hook block (P-DISPOSITION, P-SUPPRESS, P-REPARENT) on top of 28-03's"
provides:
  - "evidence/28-05-local-proof.log: full local kind proof, PROOF PASS - 127 assertions, smoke ALL PASS, exit code 0"
  - "Measured values for the 3.3.200 claims that had only been derived from source: the disposition tuples, the statistics shape, the delete-time re-parent, the cross-tool table, and the timing"
  - "Measured: Trivy Scan originals imported through the committed dd-import body land verified=true (other parsers not read)"
affects: [28-06, 28-07, 28-09]
tech-stack:
  added: []
  patterns: ["timestamp the proof output through a perl prefix on a tee'd copy; the evidence log itself stays unprefixed so its ^PROOF greps keep working"]
key-files:
  created:
    - .planning/phases/28-defectdojo-dedup-and-triage/evidence/28-05-local-proof.log
  modified:
    - repos/security-platform/scripts/defectdojo-import-proof.sh
decisions:
  - "Verified is not a P-DISPOSITION selection criterion: 3.3.200 lands the committed body's imports verified=true, and no RESEARCH claim or tuple depends on verified"
  - "The evidence log is force-added (git add -f) because the user's global ~/.gitignore ignores *.log. The Phase 27 evidence logs are tracked the same way."
metrics:
  duration: ~20 min (14:10-14:31 UTC, three kind runs)
  completed: 2026-09-26
  tasks: 2
  files: 2
---

# Phase 28 Plan 05: Local kind proof of dedup and triage Summary

The complete proof, Phase 27 plus the Phase 28 block, passes locally on kind. It ran with real scanner reports and ended in `PROOF PASS - 127 assertions` and `ALL PASS - 13 live check(s)`. That is the source-derived engine behaviour measured for the first time. Every RESEARCH expectation held. The only failures were two harness problems in the P-DISPOSITION selection precondition, and both were fixed.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Obtain real reports and run the full local proof | security-platform `beca762`, `13b1402` (harness fixes) | scripts/defectdojo-import-proof.sh |
| 2 | Scrub and commit the evidence | outer repo `65619d7` | evidence/28-05-local-proof.log |

Nothing was pushed, and no workflow_dispatch was triggered. The reports came from the read-only `gh run download 36188604648`, the latest successful `DefectDojo Import Proof` run on main (2026-09-25). The download contained every required file: semgrep-results.json, checkov-results.json, trivy-fs.json, trivy-image.json, gitleaks-results.json, npm-audit-1.json and pip-audit-1.json, plus tflint.sarif and the SARIFs. All three runs removed their kind cluster, and `kind get clusters` now reports none.

## Measured facts

Everything below is copied from `evidence/28-05-local-proof.log`, which is attempt 3 at security-platform `13b1402`.

**Assertion count**
```
PROOF PASS - 127 assertions
ALL PASS - 13 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).
```
The Phase 28 block, from its banner to the end, holds 35 PROOF lines, the number 28-04 predicted. The remaining 92 are Phase 27 lines.

**Configure script (P-CONFIGURE / P-IDEMPOTENT)**
```
    | CHANGED: enable_deduplication, risk_acceptance_form_default_days
    | NO CHANGE: all 5 settings already match (enable_deduplication, delete_duplicates, false_positive_history, retroactive_false_positive_history, risk_acceptance_form_default_days)
```
The before state on a fresh install was `enable_deduplication:false` and `risk_acceptance_form_default_days:180`. After the bootstrap they were `true` and `90`, and `enable_finding_sla` stayed `true`.

**P-DEDUP-BRANCH count line and delta identity**
```
    delta: removed CVE-2020-8203 lodash 4.17.15 (HIGH, 'fixtures/package-lock.json') from the ci/main copy of trivy-fs.json
    dedup settled after 7 s: 154 duplicate of 155 findings in proof/dedup / ci/proof/pr-delta (unchanged across two snapshots 5 s apart)
    counts: PR total 155, PR duplicates 154, main total 154, main duplicates 23
PROOF: P-DEDUP-BRANCH PASS exactly one PR finding is non-duplicate and it is the active delta CVE-2020-8203 lodash 4.17.15: 1 non-duplicate (#385 Trivy Scan 'CVE-2020-8203 Lodash 4.17.15' dup=False active=True dup_of=None)
```

**CROSSTOOL**
```
PROOF: P-CROSSTOOL PASS 23 duplicate link(s) touch an SCA finding in ci/main; 0 cross scan types
CROSSTOOL: scan_type='Trivy Scan' findings=64 with_vulnerability_ids=64 with_component_version=64 sample_components=['bsdutils', 'gzip', 'libacl1']
CROSSTOOL: scan_type='pip-audit Scan' findings=46 with_vulnerability_ids=46 with_component_version=46 sample_components=['idna', 'jinja2', 'requests']
CROSSTOOL: scan_type='NPM Audit v7+ Scan' findings=2 with_vulnerability_ids=0 with_component_version=0 sample_components=['node_modules/lodash', 'node_modules/minimist']
CROSSTOOL: package=requests trivy_ids=['CVE-2018-18074'] pip_audit_ids=['PYSEC-2018-28', 'PYSEC-2023-74', 'PYSEC-2026-1872', 'PYSEC-2026-1873', 'PYSEC-2026-2275'] shared=[]
```

**Disposition tuples.** The selected findings were FP #231 CVE-2021-23337, OOS #232 CVE-2026-4800 and RA #233 NSWG-ECO-516, all Lodash 4.17.15 in trivy-fs. The RA `expiration_date` was 2026-12-25T00:00:00Z.
```
PROOF: P-DISPOSITION PASS after reimport 1: FP #231 is false_p=True out_of_scope=False risk_accepted=False active=False is_mitigated=True (expected ...), mitigated=2026-09-26T14:28:55.922264Z
PROOF: P-DISPOSITION PASS after reimport 1: OOS #232 is false_p=False out_of_scope=True risk_accepted=False active=False is_mitigated=True (expected ...), mitigated=2026-09-26T14:28:56.086078Z
PROOF: P-DISPOSITION PASS after reimport 1: RA #233 is false_p=False out_of_scope=False risk_accepted=True active=False is_mitigated=False (expected ...), mitigated=None
PROOF: P-DISPOSITION PASS reimport 1: trivy-fs statistics.delta.reactivated.total = 0 (expected 0)
PROOF: P-DISPOSITION PASS after reimport 2: FP #231 is false_p=True out_of_scope=False risk_accepted=False active=False is_mitigated=True (expected ...), mitigated=2026-09-26T14:28:55.922264Z
PROOF: P-DISPOSITION PASS after reimport 2: OOS #232 is false_p=False out_of_scope=True risk_accepted=False active=False is_mitigated=True (expected ...), mitigated=2026-09-26T14:28:56.086078Z
PROOF: P-DISPOSITION PASS after reimport 2: RA #233 is false_p=False out_of_scope=False risk_accepted=True active=False is_mitigated=False (expected ...), mitigated=None
PROOF: P-DISPOSITION PASS reimport 2: trivy-fs statistics.delta.reactivated.total = 0 (expected 0)
PROOF: P-DISPOSITION PASS reimport 2 vs reimport 1: the three tuples and the FP/OOS mitigated timestamps (FP=2026-09-26T14:28:55.922264Z, OOS=2026-09-26T14:28:56.086078Z) are unchanged
```
`(expected ...)` is shortened here. In the log, each expected tuple equals the measured one.

Statistics shape: the log prints `statistics.delta` cut to 800 characters, so only the `closed` bucket is visible. That bucket has `critical`, `high`, `info`, `low`, `medium` and `total` sub-objects, and each sub-object has `active`, `duplicate`, `false_p`, `is_mitigated`, `out_of_scope`, `risk_accepted`, `total` and `verified`. The `reactivated.total = 0` line passed. The harness reads `.total.total` when `.total` is a dict, which is 28-04's nested-path fix. The line would have failed if neither shape were present, so the nested shape is confirmed indirectly.

**P-SUPPRESS.** PR copies #540, #541 and #542 are each `dup=True active=False`, and they point at 231, 232 and 233. The PR holds 154 findings and 0 of them are active.

**K and the re-parent**
```
PROOF: P-REPARENT PASS precondition: ci/proof/pr-first holds 6 findings, K=6 non-duplicate (0 of them not active); ci/main holds 6 findings, 0 not a duplicate of a PR finding
    P-REPARENT timing: read 1 s after the DELETE returned
PROOF: P-REPARENT PASS immediately after the delete (no reimport): ci/main has 6 findings with duplicate=false and active=true (expected K=6); 6 total, 6 non-duplicate, 0 duplicate
```
DefectDojo re-parented at DELETE time, as RESEARCH Pattern 3 predicted. The findings were already re-parented when they were read 1 s later, with no reimport.

**Additional measured fact, not predicted by RESEARCH.** The five trivy-fs originals (Trivy Scan parser) imported through the committed dd-import body all landed with `verified=True`. The body sends no `verified` field (see attempt 2 under `# previous attempt`). Originals from other parsers were not read. The 3.3.200 serializer says the field defaults to the original tool, so this may depend on the parser. 28-06's runbook should say that Trivy originals are already Verified on import, so an operator cannot treat Verified as a triage signal for them. The FP PATCH has to send `verified:false`, because DefectDojo 3.3.200 rejects a verified false positive (`dojo/finding/api/serializer.py`, "False positive findings cannot be verified.").

**Timing**
```
# wall-clock: 281 s
# phase-28 block: 68 s (from the '=== Phase 28: dedup and triage' banner to the PROOF PASS line, ...)
```
The CI estimate against the 60-minute `timeout-minutes` cap of defectdojo-import-proof.yml is presented here, not acted on. It is for the 28-07 push gate.
- **Plan's scaling (8x from 27-06's "225 s local vs 20-40 min"):** 281 s × 8 ≈ 37 min. The Phase 28 block adds 68 s × 8 ≈ 9 min.
- **Measured CI durations conflict with that premise.** `gh run list` shows the real `DefectDojo Import Proof` workflow on GitHub taking 5m52s to 7m00s: runs 36156728300, 36159160216, 36160366711, 36186258881 and 36188604648. Scaling this run by that ratio (about 1.7-1.9x) gives about 8-9 min in CI.
- Both estimates are under the 60-minute cap. The discrepancy is recorded, not resolved.

**Harness fix commits (security-platform, local, not pushed)**
- `beca762` fix(28-05): print a per-candidate breakdown when the P-DISPOSITION selection fails
- `13b1402` fix(28-05): drop the unverified criterion from the P-DISPOSITION selection

## Deviations from Plan

**1. [Rule 1 - Harness bug] P-DISPOSITION selection printed no per-criterion data**
- **Found during:** Task 1, attempt 1. The run failed with `PROOF FAIL - 1 of 106` and `trivy-fs Test 14: 5 findings, 0 eligible`.
- **Issue:** The failure branch printed only totals. The snapshot is under the trap-removed `DD_SMOKE_OUT`, so it was gone and the failure could not be classified under the FAILURE RULE.
- **Fix:** On SELECT-FAIL the selection now prints every candidate with active, duplicate, verified, the disposition flags, the title count and the pointed-at state. No assertion changed. The offline gates were rerun: EXTRACT PASS, `--scheme-only` 7/7, chart 22/22, and shellcheck clean.
- **Commit:** security-platform `beca762`

**2. [Rule 1 - Harness bug] The selection required verified=false**
- **Found during:** Task 1, attempt 2. The diagnostic showed all 5 candidates as `active=True duplicate=False verified=True ... title_count=1 pointed_at=False`.
- **Issue:** The 28-04 selection added `verified is False`. That criterion was not in 28-04-PLAN and does not come from RESEARCH. RESEARCH's `verified=False` refers to dedup-marked duplicates, not to originals. Live 3.3.200 lands originals verified, so 0 candidates were eligible.
- **Classification:** This is a harness assumption, not DefectDojo behaviour that contradicts RESEARCH. None of the FAILURE RULE's stop conditions applied: no disposition tuple, re-parent, cross-type link, dedup enablement, delta or reactivation was involved. No tuple asserts `verified`. The OOS PATCH and the RA POST have no verified constraint in the 3.3.200 serializer, and the FP PATCH already sends `verified:false`.
- **Fix:** The criterion was removed, and a comment records the measured fact. The selection's own synthetic test picked FP/OOS/RA from `verified=true` candidates. The offline gates were rerun and all passed.
- **Commit:** security-platform `13b1402`

**3. [Process] Evidence log inode swap during attempt 1**
- **Issue:** I fixed a missing `helm` prefix in the header with `sed -i` while the proof was writing to the log through `tee -a`. The edit replaced the file's inode, and `tee` kept writing to the old one.
- **Fix:** Attempt 1's log was rebuilt from the full timestamped copy (`ts.log`). Attempts 2 and 3 did not touch the file until the run had exited. Before the whitespace strip in deviation 4, attempt 3's log was diffed against its timestamped copy and was identical.

**4. [Rule 3 - Blocking] Evidence log ignored by the user's global gitignore**
- **Issue:** `~/.gitignore` has a line `*.log`, so `gsd-sdk query commit` refused the path.
- **Fix:** `git add -f` on that one file, the same way the Phase 27 evidence logs are tracked. The pre-commit hook then refused 2 lines with trailing whitespace. I stripped trailing whitespace from the log, which changed no content, and committed normally with hooks.

**FAILURE RULE outcome:** No DefectDojo behaviour contradicted RESEARCH. All 35 Phase 28 PROOF lines and all 92 Phase 27 PROOF lines passed on attempt 3. No assertion expectation was edited.

## Scrub

`grep -cE 'Authorization: Token|aA1!'` found 0. A grep for a 40-hex token after `Token`, and for any bare 40-hex string, also found 0. There were 0 redactions.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: .planning/phases/28-defectdojo-dedup-and-triage/evidence/28-05-local-proof.log (committed in 65619d7)
- FOUND: security-platform beca762 and 13b1402 on feature/phase-28-defectdojo-dedup-and-triage
- Task 1 `<automated>` verify: VERIFY1-OK. Task 2 `<automated>` verify: VERIFY2-OK.
