---
phase: 26-defectdojo-generic-chart
plan: 01
subsystem: kubernetes/defectdojo offline gate (security-platform)
tags: [helm, defectdojo, gate, cert-manager, offline-validation]
requires: []
provides:
  - "security-platform branch feature/phase-26-defectdojo-generic-chart cut from main 61589d5"
  - "scripts/check-defectdojo-chart.sh: 20-check offline gate for kubernetes/defectdojo (vacuous SKIP until 26-03)"
affects: [26-02, 26-03, 26-04, 26-05, 26-06, 26-07]
tech-stack:
  added: []
  patterns:
    - "Standing offline chart gate cloned from check-nexus-chart.sh structure (SKIP guards, exit 0/1/2, fail() collects all, CHECK_COUNT literal in three places)"
    - "Zero-safe counting via `yq ea '[select(...)] | length'` instead of `grep -c ... || true`"
    - "grep no-match handled as `|| rc=$?` with explicit rc 0/1/other branches"
key-files:
  created:
    - repos/security-platform/scripts/check-defectdojo-chart.sh
  modified: []
decisions:
  - "Gate counts objects with `yq ea ... | length` (exits 0 at zero) rather than the analog's `grep -c ... || true`, so NO-SECRETS-RENDERED can assert 0 without a spurious pipefail failure"
  - "RENDERED-IMAGES reads the expected tag from wrapper Chart.yaml appVersion rather than hardcoding 3.3.200, same reason the tarball name is derived from Chart.yaml"
  - "DDOJO-01 NOT marked complete by 26-01: precedent (23-08, 24-10, 25-07) closes the requirement only in the phase's final plan"
metrics:
  duration: "~30 min"
  completed: 2026-09-25
  tasks: 2
  files: 1
---

# Phase 26 Plan 01: Branch refresh and offline DefectDojo chart gate Summary

The `security-platform` clone moved off the stale Phase 25 branch onto fresh `main` (`61589d5`, the PR #16 merge), and the phase branch was cut from there. `scripts/check-defectdojo-chart.sh` is a 20-check offline gate for `kubernetes/defectdojo`. It exits 0 with `SKIP: chart not present yet` until plan 26-03 lands the chart. I also ran it against a throwaway prototype chart in the scratchpad: it passed there, and it failed when I broke the chart on purpose.

## Tasks

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Refresh clone onto main, create phase branch | none (git state only, by design) | none |
| 2 | Write standing offline gate | `08b707e` (security-platform) | `scripts/check-defectdojo-chart.sh` (485 lines, mode 100644) |

## Task 1: branch state

- Clone was clean (`git status --porcelain` empty) on `feature/phase-25-nexus-live-validation`.
- `git pull --ff-only origin main` fast-forwarded `aed14b9..61589d5`.
- `git merge-base --is-ancestor 61589d5 HEAD` succeeded.
- **Branch cut from main HEAD `61589d509505442a3e26110fbc5c4bf156a6a488`**, which equals `origin/main` at cut time.
- `feature/phase-25-nexus-live-validation` is kept. `kubernetes/` lists only `nexus`. Nothing was pushed.

## Task 2: verification (measured)

Repo-level acceptance, all run from `repos/security-platform/`:
- `shellcheck` exited 0. The pre-commit shellcheck hook passed too.
- The gate prints `SKIP: chart not present yet — kubernetes/defectdojo does not exist (vacuous pass, by design)` and exits 0.
- There are 20 `^# ── N. ` banners. `--namespace defectdojo` appears 7 times (render(), lint, and the direct calls for checks 2, 3, 4 and 6). Non-comment lines contain 0 `|| true`, 0 `1.9.53`, and exactly 1 `CHECK_COUNT=20`.
- None of the ISSUER-REQUIRED, ISSUER-EITHER-KEY, ISSUER-NOT-BOTH or TLS-OFF-RENDERS blocks contains `render `.
- `git log main..HEAD` has one commit (`08b707e`). `git ls-files -s` shows mode 100644, and the working tree is clean after the commit.

Beyond acceptance, I tested a copy of the gate in the scratchpad and deleted the copy afterwards. Nothing was written into the repo.
- **Guard ladder:** an empty chart directory gives Guard 2 SKIP (exit 0). A Chart.yaml with dependency version `9.9.9` gives `PREFLIGHT FAIL ... charts/defectdojo-9.9.9.tgz` plus `run: helm dependency build kubernetes/defectdojo` (exit 2). That shows the tarball name comes from Chart.yaml.
- **Positive path:** the prototype was built from the plan's `<interfaces>` contract, with RESEARCH Pattern 1 `validate-tls.yaml`, Pattern 2 values and upstream `defectdojo-1.9.53.tgz` via `helm dependency build`. Result: `PASS - 20 checks, 0 failures` in 1.7 s (Helm v4.3.0, yq v4.53.6).
- **Mutation tests (each check can go red):** each mutation below made the named check(s) fail, and restoring the chart brought back `PASS - 20 checks`:
  - uwsgi processes=4 or maxFd removed: UWSGI-FOOTPRINT
  - valkey persistence on: VALKEY-EPHEMERAL
  - nginx tag 3.3.199: IMAGE-PIN and RENDERED-IMAGES
  - siteUrl set to http: SITEURL-MATCHES-HOST
  - `define "defectdojo.fullname"` in `_helpers.tpl`: NO-HELPER-COLLISION (both halves)
  - `occ-` hostname: PLACEHOLDER-ONLY
  - empty guard template: ISSUER-REQUIRED, ISSUER-NOT-BOTH, TLS-SECRETNAME-REQUIRED
  - guard accepting only the ClusterIssuer key: ISSUER-EITHER-KEY
  - createSecret on by default: NO-SECRETS-RENDERED
  - default ingressClassName: INGRESSCLASS-UNSET
  - default storageClass: STORAGECLASS-OMITTED
  - Postgres persistence off: POSTGRES-PERSISTENT
  - ingress off: INGRESS-ON, TLS-ON, TLS-OFF-RENDERS

  I did not mutate CHART-LINT or CREATE-SECRET-OPT-IN. Making them fail would take an upstream change or a lint-breaking edit.

## Deviations from Plan

**1. [Rule 1 - Bug avoidance] Count idiom differs from the analog**
- **Found during:** Task 2
- **Issue:** PATTERNS §7 says to reuse the analog's JOB-HOOK count shape, `grep -c '^Job$' || true`. That breaks the plan's own `|| true` = 0 acceptance. Without the `|| true`, `grep -c` exits 1 on zero matches, so under pipefail NO-SECRETS-RENDERED (which expects 0) would report a false tooling failure.
- **Fix:** INGRESS-ON, NO-SECRETS-RENDERED and TLS-OFF-RENDERS count with `yq ea '[select(...)] | length'`. The grep-based checks 19 and 20 capture the no-match exit as `|| helper_rc=$?` / `|| placeholder_rc=$?` and branch on 0 / 1 / other, so a grep error is never read as a pass.
- **Commit:** `08b707e`

**2. [Rule 2 - Robustness] Extra guards inside checks**
- NO-HELPER-COLLISION matches `define[[:space:]]+"defectdojo\.`, a superset of the plan's literal pattern that also catches extra whitespace.
- UWSGI-FOOTPRINT picks the ConfigMap by the key it carries, not by name, because the subcharts ship their own ConfigMaps.
- RENDERED-IMAGES fails if no `defectdojo/defectdojo-` image renders at all, so an empty image list cannot pass.

Otherwise the plan was executed as written.

## Known Stubs

None.

## Threat Flags

None. The gate adds no network, auth or schema surface. It reads Secret key names only (T-26-13), and every render passes `--namespace defectdojo` (T-26-14).

## Notes for later plans

- The gate works on a chart built from the interface contract. Plan 26-03 should build to the same names: `templates/validate-tls.yaml`, no `_helpers.tpl`, and a values tree under `defectdojo:`.
- DDOJO-01 is still Pending in REQUIREMENTS.md, deliberately (see decisions).

## Self-Check: PASSED

- FOUND: repos/security-platform/scripts/check-defectdojo-chart.sh
- FOUND: 08b707e in repos/security-platform (`git log main..HEAD`)
- FOUND: branch feature/phase-26-defectdojo-generic-chart at 61589d5 + 1 commit
