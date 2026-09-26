---
phase: 28-defectdojo-dedup-and-triage
plan: 06
subsystem: docs
tags: [defectdojo, triage, dedup, runbook, readme]
requires:
  - phase: 28-05
    provides: measured disposition tuples, re-parent timing, P-SUPPRESS, CROSSTOOL, Trivy verified=true
provides:
  - kubernetes/defectdojo/TRIAGE.md triage runbook (D-13..D-16, D-21..D-23)
  - chart README Dedup and triage section, recompute note, extraConfigs rows, current requirement rows
affects: [28-07, 28-08, 28-09]
tech-stack:
  added: []
  patterns: ["runbook states measured tuples, labels source-only behaviour as unmeasured"]
key-files:
  created:
    - repos/security-platform/kubernetes/defectdojo/TRIAGE.md
  modified:
    - repos/security-platform/kubernetes/defectdojo/README.md
key-decisions:
  - "Under Review keeps the D-23 verified=false query, with a measured caveat that Trivy findings arrive verified=true so the Trivy untriaged queue is the same query without verified=false"
  - "FP/OOS are documented as Mitigated from the moment they are dispositioned (measured before any reimport), not as becoming Mitigated at the next scan"
  - "RA expiry is documented as upstream source behaviour returning the finding to the untriaged queue, not as measured"
metrics:
  duration: ~15 min
  completed: 2026-09-26
---

# Phase 28 Plan 06: Triage runbook and chart README Summary

The DefectDojo triage runbook (`TRIAGE.md`) and an updated chart README now document the dedup bootstrap, the hash recompute, the default-branch-only triage rule and six dispositions. Every tuple and example comes from the 28-05 local proof log.

## Tasks

| Task | Name | Commit (security-platform) | Files |
|---|---|---|---|
| 1 | Write kubernetes/defectdojo/TRIAGE.md | `24f56f6` | kubernetes/defectdojo/TRIAGE.md (new) |
| 2 | README Dedup and triage section, recompute note, values rows, requirement rows | `c77e4f4` | kubernetes/defectdojo/README.md |

Both commits are local on `feature/phase-28-defectdojo-dedup-and-triage`. Nothing was pushed.

## Verification

- Task 1 verify block: all 18 needles present, no environment identifiers, no inline `-H "Authorization: Token` header, tree clean after commit. markdownlint pre-commit hook: Passed.
- Task 2 verify block: `VERIFY-OK`, and `bash scripts/check-defectdojo-chart.sh` printed `PASS - 22 checks, 0 failures` before and after the edit. markdownlint: Passed. `## Dedup and triage` sits at line 223, between `## Install` (190) and `## Storage` (270).

## What the docs state, and where it comes from

- **Re-parent:** K=6 non-duplicate and active, read 1 s after the DELETE returned, with no reimport (P-REPARENT).
- **Suppression:** PR copies #540, #541 and #542 were `dup=True active=False` and pointed at #231, #232 and #233. The PR engagement had 0 active findings (P-SUPPRESS).
- **Tuples:** FP `false_p=True active=False is_mitigated=True`, OOS `out_of_scope=True active=False is_mitigated=True`, RA `risk_accepted=True active=False is_mitigated=False`. These held after two reimports, with `reactivated.total = 0` both times.
- **Cross-tool:** for `requests`, Trivy reported `CVE-2018-18074` and pip-audit reported five PYSEC ids, `shared=[]`. The NPM Audit findings had 0 `vulnerability_ids`, and 0 duplicate links crossed scan types.
- **Bootstrap:** the first run returned `CHANGED: enable_deduplication, risk_acceptance_form_default_days` and the rerun returned `NO CHANGE`. SLA was left alone.
- **Dedup delta:** 155 PR findings, 154 duplicates and 1 active delta.

## Deviations from Plan

### Wording adjusted to match measured evidence

**1. [Rule 1 - Accuracy] Under Review and Trivy's verified=true**
- **Found during:** Task 1
- **Issue:** 28-05 measured that the Trivy Scan originals land `verified=true`. The D-23 query (`verified=false`) is therefore empty for Trivy findings.
- **Fix:** The D-23 filter and API query are kept verbatim, as the plan and the verify block require. A paragraph after them states the measured Trivy fact, scoped as 28-05 scopes it (other parsers were not read). It says Verified is not a triage signal for Trivy, and that the Trivy untriaged queue is the same query without `verified=false`. The FP example sends `verified:false`, and the paragraph gives the 3.3.200 reason.
- **Commit:** `24f56f6`

**2. [Rule 1 - Accuracy] FP/OOS Mitigated timing**
- **Found during:** Task 1
- **Issue:** The plan text says FP/OOS "are additionally shown as Mitigated from the next scan". Evidence log lines 365-366 show `is_mitigated=True` before any reimport. The mitigated timestamps (14:28:55/56) are the disposition time, and they did not change across two reimports.
- **Fix:** The disposition table says the state holds "from the moment it is dispositioned" and was unchanged by two reimports.
- **Commit:** `24f56f6`

**3. [Rule 1 - Accuracy] RA expiry labelled as unmeasured**
- **Issue:** The expiry handler (Celery beat every 3 h) comes from RESEARCH, which read it in source. 28-05 did not exercise it. For Trivy findings, "returns to Under Review because verified stays false" would be wrong.
- **Fix:** The runbook says the handler sets the finding active and not risk accepted, which returns it to the untriaged queue. It labels this as upstream behaviour that the proof did not exercise.

**4. [Rule 2 - Completeness] Legacy-hash consequence on the default branch**
- The Expected noise bullet adds that a line-shifting change, once merged, can bring an issue already dispositioned on `ci/<default>` back as a new finding. That follows from the same line-inclusive hash (Pitfall 8), and the bullet says to disposition it again.

**5. README version-bump step and gate reference.** The CSRF overlay sentence cites check 21 by name (CASCADE-DELETE-OFF, which contains the overlay map-merge render). The version-bump list gains step 3, re-reading `DEDUPLICATION_ALGORITHM_PER_PARSER`. The old step 3 is renumbered to 4.

## Notes

- ADR-026 is cited by number. It does not exist yet in `docs/adr/`; D-18 is written in a later plan.
- `docs/adoption-guide.md` (D-24) was not touched and belongs to a later plan.
- DDOJO-03/04 were not marked complete in REQUIREMENTS.md, as the orchestrator instructed. Only the README rows changed.

## Known Stubs

None.

## Threat Flags

None. T-28-22..25 are mitigated as planned: superuser token is operator-held, mode 0600 and never a GitHub secret; examples use `-H @"$HDR"`; triage on `ci/<default>` is a hard rule; only example.com placeholders appear.

## Self-Check: PASSED

- FOUND: repos/security-platform/kubernetes/defectdojo/TRIAGE.md
- FOUND: repos/security-platform/kubernetes/defectdojo/README.md (modified)
- FOUND: 24f56f6, c77e4f4 in security-platform
