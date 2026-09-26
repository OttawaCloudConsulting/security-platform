---
phase: 28-defectdojo-dedup-and-triage
plan: 01
subsystem: kubernetes/defectdojo chart + offline chart gate (security-platform)
tags: [defectdojo, deduplication, helm, gate, DDOJO-03]
requires: []
provides:
  - "security-platform branch feature/phase-28-defectdojo-dedup-and-triage (local, unpushed) cut from origin/main 917352c"
  - "defectdojo.extraConfigs dedup guards shipped as chart defaults (D-20)"
  - "check-defectdojo-chart.sh checks 21 CASCADE-DELETE-OFF and 22 DEDUP-ALGORITHM-MAP (22 checks)"
affects: [28-02, 28-03, 28-04, 28-05, 28-06, 28-08]
tech-stack:
  added: []
  patterns: ["per-check problem accumulation -> one FAIL line per check", "yq selects ConfigMap by key, jq -e validates JSON value"]
key-files:
  created: []
  modified:
    - repos/security-platform/scripts/check-defectdojo-chart.sh
    - repos/security-platform/kubernetes/defectdojo/values.yaml
    - repos/security-platform/kubernetes/defectdojo/Chart.yaml
    - repos/security-platform/kubernetes/defectdojo/README.md
decisions:
  - "Gate checks 21/22 accumulate their sub-problems and emit one FAIL line each, so RED shows exactly two FAIL lines"
  - "Check 21 toggle half does the key logic in jq (slurped yq JSON output) and also requires exactly one ConfigMap carrying the overlay key"
metrics:
  duration: ~15 min
  completed: 2026-09-26
  tasks: 2
  files: 4
---

# Phase 28 Plan 01: DefectDojo dedup guard defaults and gate checks Summary

The wrapper chart now ships `DD_DUPLICATE_CLUSTER_CASCADE_DELETE: "False"` and a 7-entry `DD_DEDUPLICATION_ALGORITHM_PER_PARSER` JSON map (the 3.3.200 algorithms) as `defectdojo.extraConfigs` defaults. The offline gate enforces both with checks 21 and 22. Check 22 parses the rendered value with `jq -e` and forbids `DD_HASHCODE_FIELDS_PER_SCANNER`.

## Branch baseline (for 28-08)

- security-platform branch: `feature/phase-28-defectdojo-dedup-and-triage` (local only, not pushed; `git ls-remote --heads origin <branch>` returns nothing)
- Base: `origin/main` = `917352c00987023fa5ff1e6cdabc16987eb114dd` (merge of PR #22). `ba3683a` is an ancestor.
- `v1` tag: `git ls-remote --tags origin` returns only `917352c00987023fa5ff1e6cdabc16987eb114dd refs/tags/v1`, with no `^{}` peeled line, so it is a lightweight tag on the base commit.

## Tasks

| Task | Name | Commit (security-platform) | Files |
| ---- | ---- | ------ | ----- |
| 1 | Cut branch; gate checks 21-22 (RED) | 0e8f01f | scripts/check-defectdojo-chart.sh |
| 2 | extraConfigs guards, chart 0.2.0, README count (GREEN) | 8eadfd0 | kubernetes/defectdojo/values.yaml, Chart.yaml, README.md |

## Evidence

- RED (at 0e8f01f): the gate exited 1 with exactly two lines, `FAIL: CASCADE-DELETE-OFF` and `FAIL: DEDUP-ALGORITHM-MAP`, followed by `FAILED - 2 check(s)`.
- GREEN (at 8eadfd0): the gate printed `PASS - 22 checks, 0 failures` and exited 0. The plan's confirm command (`helm template ... | yq ... | jq -e 'length == 7'`) printed `true`. yq returns the single-quoted JSON value unwrapped.
- Mutation tests: each mutation was applied to values.yaml, the gate was run, and the file was restored byte-for-byte. Each mutation failed only the intended check.
  - cascade `"True"` failed CASCADE-DELETE-OFF.
  - Malformed JSON (a missing `}`) failed DEDUP-ALGORITHM-MAP.
  - A wrong algorithm (Trivy set to `legacy`) failed DEDUP-ALGORITHM-MAP.
  - An extra scan-type key failed DEDUP-ALGORITHM-MAP.
  - An added `DD_HASHCODE_FIELDS_PER_SCANNER` failed DEDUP-ALGORITHM-MAP.
- Regression: `check-workflow-uploads.sh` printed PASS - 19 checks. `check-detector-parity.sh` printed PASSED 20 / FAILED 0.
- shellcheck passed, and so did the pre-commit hooks (shellcheck, yamllint, markdownlint). The script mode is `-rw-r--r--`, so the executable bit is not set.
- Chart.yaml is at version 0.2.0. appVersion "3.3.200" and dependency 1.9.53 are unchanged. values.yaml cites ADR-026 5 times and has no placeholder-forbidden words.

## Deviations from Plan

**1. [Rule 1 - Bug] Replaced the first-draft toggle-half yq expression.**
- **Found during:** Task 1
- **Issue:** The first version of the toggle half built the has() array inside yq. It printed one boolean per document instead of filtering to the ConfigMap, because the yq expression did not group the way it would in jq.
- **Fix:** yq now only selects the ConfigMap and prints its data as compact JSON. `jq -e -s` does the key check and also requires exactly one matching ConfigMap.
- **Commit:** 0e8f01f. The bad draft was never committed.

**2. [Design choice within spec] One FAIL line per check.**
- The plan's verify requires exactly two FAIL lines at RED. On today's values, check 21's default half and toggle half would both fail.
- Each check therefore collects its sub-problems and emits a single `fail` with the details joined by `; `.

## Known Stubs

None.

## Threat Flags

None. T-28-01 to T-28-04 are mitigated as the threat register specifies.

## Self-Check: PASSED

- The four modified files exist on the branch.
- Commits 0e8f01f and 8eadfd0 are present in the security-platform `git log`.
