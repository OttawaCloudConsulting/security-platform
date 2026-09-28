---
phase: 29-defectdojo-live-validation
plan: 10
subsystem: k8s-infrastructure
tags: [defectdojo, system-settings, deduplication, d-13, ddojo-05, idempotency]
requires:
  - "29-08: DefectDojo live, Application Synced/Healthy, first-pass gate 7 PASS"
  - "security-platform e8387a8: scripts/defectdojo-configure.sh (Phase 28 bootstrap)"
provides:
  - "evidence/29-10-configure-1.txt: CHANGED: enable_deduplication, risk_acceptance_form_default_days; VERIFIED; exit 0; pre-run findings=0"
  - "evidence/29-10-configure-2.txt: NO CHANGE on all 5 keys; exit 0; post-run findings=0"
  - "Operator-held superuser token at ~/.config/defectdojo/homelab-admin.token (0600), left in place for 29-14..29-17"
affects: [29-14, 29-15, 29-16, 29-17, 29-19]
tech-stack:
  added: []
  patterns:
    - "Token handled by path only: a scratch preflight builds a 0600 O_EXCL header file inside mktemp -d with an EXIT trap and prints only HTTP codes and counts"
key-files:
  created:
    - .planning/phases/29-defectdojo-live-validation/evidence/29-10-configure-1.txt
    - .planning/phases/29-defectdojo-live-validation/evidence/29-10-configure-2.txt
  modified: []
decisions:
  - "29-10: JIRA webhook secret rotation DESCOPED by the operator, verbatim: \"wait, we don't actually have jira in our environment, descope this from the test\". No rotation happened (plan amended in 3b74622)"
  - "29-10: the first-run drift set on a fresh 3.3.200 install was enable_deduplication and risk_acceptance_form_default_days; delete_duplicates, false_positive_history and retroactive_false_positive_history already matched upstream defaults"
  - "29-10: dedup was enabled over 0 findings, 0 products, 0 engagements and 0 tests, so ADR-026 NOT-verified item 1 stays open and unexercised"
  - "29-10: DDOJO-05 is not marked complete; the import and second-sync proofs are owned by later plans"
metrics:
  duration: "~5min for Task 2 (13:21Z-13:26Z); Task 1 was an operator checkpoint"
  completed: 2026-09-28
  tasks: 2
  files: 2
---

# Phase 29 Plan 10: DefectDojo System Settings bootstrap (D-13) Summary

The Phase 28 System Settings bootstrap is applied to the live homelab DefectDojo. It ran before any import. The first run changed `enable_deduplication` and `risk_acceptance_form_default_days` and verified all five keys. The second run reported `NO CHANGE`. The instance held zero findings the whole time, so ADR-026's "No live install with existing findings" item stays open.

## Task 1: operator token (checkpoint)

The operator created the token file and replied verbatim "done". The orchestrator checked, without reading the contents, that `~/.config/defectdojo/homelab-admin.token` exists, has mode `-rw-------` (600) and is 41 bytes. The token value never appeared in the session or in any evidence file.

**JIRA descope.** Operator decision, verbatim: "wait, we don't actually have jira in our environment, descope this from the test". The plan was amended in `3b74622`. The `jira_webhook_secret` printed during 29-08 was not rotated. JIRA is not integrated, and `defectdojo-configure.sh` manages no Jira key, so the descope does not affect the CHANGED / NO CHANGE comparison.

## Task 2: preflight and two configure runs

**Preflight** (2026-09-28, before run 1). This was a scratch script that builds a 0600 header file in `mktemp -d`, removes it with an EXIT trap, and prints only the status and count. `GET /api/v2/{findings,products,engagements,tests}/?limit=1` returned HTTP 200 with `count=0` for all four. The 200 responses also show that the operator's superuser token is accepted. The system trust store was used, with no CA file, which matches 29-08's TLS PASS.

**Run 1** (`13:23:27Z`, security-platform `e8387a8`):
```
DefectDojo host: defectdojo.infra.ottawacloudconsulting.com
CHANGED: enable_deduplication, risk_acceptance_form_default_days
VERIFIED: all 5 settings match
# exit code: 0
```

**Run 2** (`13:23:37Z`):
```
NO CHANGE: all 5 settings already match (enable_deduplication, delete_duplicates, false_positive_history, retroactive_false_positive_history, risk_acceptance_form_default_days)
# exit code: 0
```

**Post-run recheck.** The same four counts were still 0, and this is appended to `29-10-configure-2.txt`.

The CHANGED key list is `enable_deduplication` and `risk_acceptance_form_default_days`. The plan's minimum expectation was `enable_deduplication`, and it held. The second key is the D-22 90-day default. The live value differed from 90 before run 1. The prior value is not printed by the script, so it was not captured.

## Verification

- Plan automated verify: `VERIFY-PASS` (`^CHANGED:` + `enable_deduplication` in file 1, `^NO CHANGE` in file 2, no `Token <20+ chars>`)
- Hygiene: zero matches for `[A-Fa-f0-9]{40}|github_pat_|ghp_|Authorization` in both files, and zero lines with trailing whitespace
- security-platform clone: no commits, still at `e8387a8`

## Deviations from Plan

**1. [Minor] Preflight widened beyond findings.** The plan asked only for the findings count. Products, engagements and tests were also counted, and the counts were re-checked after run 2. This is read-only and makes the "no finding existed" truth stronger. No other deviations.

## Token lifecycle

The token file is left in place on purpose for plans 29-14 to 29-17 (T-29-18, accepted). Deleting or rotating it after the phase is the operator's call, to be noted in the 29-19 summary.

## Commits

- `2263d56` docs(29-10): capture defectdojo-configure CHANGED then NO CHANGE evidence

## Self-Check: PASSED

- FOUND: evidence/29-10-configure-1.txt, evidence/29-10-configure-2.txt
- FOUND: commit 2263d56
