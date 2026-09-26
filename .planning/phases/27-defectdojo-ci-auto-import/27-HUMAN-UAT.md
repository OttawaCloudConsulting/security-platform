---
status: partial
phase: 27-defectdojo-ci-auto-import
source: [27-VERIFICATION.md]
started: 2026-09-26T02:33:56Z
updated: 2026-09-26T02:33:56Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Observe the first scheduled-security.yml run firing at 06:00 America/Toronto
expected: A scheduled run appears in Actions history at the correct wall-clock time and imports the default branch
result: [pending]

### 2. Enable DEFECTDOJO_URL/DEFECTDOJO_API_TOKEN in a real consumer repository (Mode A or Mode B) per docs/adoption-guide.md
expected: Import job runs against a real (non-ephemeral) https DefectDojo instance and creates the expected Product/Engagement/Tests
result: [pending]

### 3. Exercise the closed-PR reopen race (close, reopen, merge quickly)
expected: Either the reopen run's checks complete before merge is possible, or a documented gap remains
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
