---
status: complete
phase: 27-defectdojo-ci-auto-import
source: [27-VERIFICATION.md]
started: 2026-09-26T02:33:56Z
updated: 2026-10-08T21:06:54Z
---

## Current Test

[testing complete]

## Tests

### 1. Observe the first scheduled-security.yml run firing at 06:00 America/Toronto
expected: A scheduled run appears in Actions history at the correct wall-clock time and imports the default branch
result: pass (evidence: 29.6 evidence/29.6-01-item1-run.json, 29.6-01-item1-jobs.json, 29.6-01-item1-cron.txt — schedule run 36553070357 created 2026-09-29T10:02:41Z = 06:02 EDT against cron 0 6 * * * America/Toronto, conclusion success, head 2fda1ac, DefectDojo Import on the ARC runner; ~2 min start delay observed, GitHub schedule start is best-effort)

### 2. Enable DEFECTDOJO_URL/DEFECTDOJO_API_TOKEN in a real consumer repository (Mode A or Mode B) per docs/adoption-guide.md
expected: Import job runs against a real (non-ephemeral) https DefectDojo instance and creates the expected Product/Engagement/Tests
result: pass (evidence: 29.6 evidence/29.6-item2-snapshot.json, 29.6-01-item2-readback.txt — security-platform is its own Mode A consumer importing into the non-ephemeral https homelab DefectDojo: product OttawaCloudConsulting/security-platform, engagement ci/main, 278 findings across 8 tests; no separate repository has done a live Mode B import)

### 3. Exercise the closed-PR reopen race (close, reopen, merge quickly)
expected: Either the reopen run's checks complete before merge is possible, or a documented gap remains
result: pass (evidence: 29.6 evidence/29.6-race-verdict.json, 29.6-08-enforcement-verdict.json, 29.6-race-a1..b3/ — on a ruleset proven to enforce (UNSTABLE -> BLOCKED -> CLEAN), 6/6 close-reopen-merge attempts on red head SHAs were refused (4 client-side, 2 server-side); ADR-033. Caveat: variant (b), the UAT literal "close, reopen, merge quickly", was refused client-side in 3 of 3 attempts, so the server merge path was not reached under (b); the server-side refusals (a2, a3) cite "5 of 5 required status checks are queued." and show the server path only under variant (a) timing; no merge was accepted in any attempt; ruling: accept-blocked in 29.6-10-d11-gate.txt. CR-01 qualifier (Phase 29.6 code review, ADR-033): in b1 and b3 the close run's skipped check run ended up newest by id on one red required context (b1 IaC — Checkov, b3 SAST — Semgrep CE) and stayed newest after the reopen run completed; each PR stayed BLOCKED only because its head was also red on a second context whose newest run was the reopen run's failure. A head red on exactly one required context was not tested (ADR-033 What was NOT verified item 12, with a follow-up). Item 3 stays closed on the measured result, no merge in 6 of 6 (ruling: amend-keep-pass in 29.6-review-ruling.txt).)

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
