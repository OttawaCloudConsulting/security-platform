---
phase: 26
slug: defectdojo-generic-chart
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-24
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Standing bash gates under `scripts/` in `repos/security-platform` (no Helm unit-test framework) |
| **Config file** | none — Wave 0 creates `repos/security-platform/scripts/check-defectdojo-chart.sh` and `repos/security-platform/scripts/defectdojo-live-smoke.sh` |
| **Quick run command** | `bash scripts/check-defectdojo-chart.sh` (offline, run from `repos/security-platform`) |
| **Full suite command** | `bash scripts/check-defectdojo-chart.sh && bash scripts/defectdojo-live-smoke.sh` |
| **Estimated runtime** | gate ~10 seconds; live smoke dominated by cold image pulls on kind (helm timeout 15m) |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/check-defectdojo-chart.sh` (must exit 0 at every intermediate commit — vacuous-pass SKIP guards)
- **After every plan wave:** Run the gate plus `shellcheck scripts/*defectdojo*.sh`
- **Before `/gsd:verify-work`:** Full suite green — smoke with 0 FAIL and 0 SKIPPED, kube context pinned to the throwaway kind cluster
- **Max feedback latency:** 10 seconds (offline gate)
- **Latency exception (by design, D-14):** 26-02 Task 2 and 26-05 Task 1 run the full live kind smoke as their automated verify and exceed 30 seconds (cold image pulls, helm timeout 15m). These are phase-gate evidence runs, not per-commit feedback; every other task keeps the offline gate within the 10-second budget.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 26-01-1 | 26-01 | 1 | DDOJO-01 | — | Phase branch cut from current origin/main, clean tree | git state | `cd repos/security-platform && git branch --show-current \| grep -qx 'feature/phase-26-defectdojo-generic-chart' && git merge-base --is-ancestor 61589d5 HEAD && git merge-base --is-ancestor origin/main HEAD && test -z "$(git status --porcelain)"` | ✅ | ⬜ pending |
| 26-01-2 | 26-01 | 1 | DDOJO-01 | T-26-01, T-26-02, T-26-04, T-26-09, T-26-13, T-26-14 | Offline gate exists (20 checks), SKIP-guards absent chart, mode 100644 | offline | `cd repos/security-platform && shellcheck scripts/check-defectdojo-chart.sh && out=$(bash scripts/check-defectdojo-chart.sh) && printf '%s\n' "$out" \| grep -q '^SKIP: chart not present yet' && test "$(git ls-files -s scripts/check-defectdojo-chart.sh \| cut -c1-6)" = 100644 && test "$(grep -v '^\s*#' scripts/check-defectdojo-chart.sh \| grep -c 'CHECK_COUNT=20')" = 1` | ❌ W0 | ⬜ pending |
| 26-02-1 | 26-02 | 2 | DDOJO-01 | T-26-06, T-26-08, T-26-15 | Smoke harness refuses foreign cluster, restores kube context, SKIPPED when prereqs absent | live smoke (harness) | `cd repos/security-platform && shellcheck scripts/defectdojo-live-smoke.sh && before=$(kubectl config current-context) && out=$(bash scripts/defectdojo-live-smoke.sh 2>&1) && printf '%s\n' "$out" \| grep -qE 'SKIPPED\|NOTHING RAN' && ! kind get clusters 2>/dev/null \| grep -qx dd-smoke && test "$(kubectl config current-context)" = "$before"` | ❌ W0 | ⬜ pending |
| 26-02-2 | 26-02 | 2 | DDOJO-01 | T-26-03, T-26-05, T-26-07 | Deployments Ready, PVC Bound, Certificate Ready, class defaulted, `--cacert` TLS `/login` 200, admin login 302 + `/dashboard` 200, celery ping; no `-k` | live smoke | `cd repos/security-platform && shellcheck scripts/defectdojo-live-smoke.sh && bash scripts/defectdojo-live-smoke.sh >/dev/null 2>&1 && for id in KIND-DEPLOYMENTS-READY KIND-PG-PVC-BOUND KIND-CERT-READY KIND-INGRESSCLASS-DEFAULTED KIND-TLS-LOGIN-200 KIND-LOGIN KIND-CELERY-PING; do grep -q "$id" scripts/defectdojo-live-smoke.sh \|\| exit 1; done && test "$(grep -v '^\s*#' scripts/defectdojo-live-smoke.sh \| grep -cE 'curl .*(-k\|--insecure)( \|$)')" = 0` | ❌ W0 | ⬜ pending |
| 26-03-1 | 26-03 | 3 | DDOJO-01 | T-26-01, T-26-02, T-26-04, T-26-SC | Dependency 1.9.53 / appVersion 3.3.200 pinned, maxFd 102400, Valkey ephemeral, tarball not committed | offline | `cd repos/security-platform && helm dependency build kubernetes/defectdojo >/dev/null && test -f kubernetes/defectdojo/charts/defectdojo-1.9.53.tgz && yq -e '.dependencies[0].version == "1.9.53" and .appVersion == "3.3.200"' kubernetes/defectdojo/Chart.yaml && yq -e '.defectdojo.django.uwsgi.appSettings.maxFd == 102400 and .defectdojo.valkey.persistence.enabled == false' kubernetes/defectdojo/values.yaml && bash scripts/check-defectdojo-chart.sh \| grep -q '^SKIP: chart incomplete' && test -z "$(git ls-files kubernetes/defectdojo/charts)"` | ❌ W0 | ⬜ pending |
| 26-03-2 | 26-03 | 3 | DDOJO-01 | T-26-09, T-26-16 | Bare render fails (issuer required via `fail`), no `_helpers.tpl`, gate PASS 20/0 | offline (tdd) | `cd repos/security-platform && bash scripts/check-defectdojo-chart.sh \| tail -1 \| grep -qx 'PASS - 20 checks, 0 failures' && ! helm template t kubernetes/defectdojo --namespace defectdojo >/dev/null 2>&1 && test ! -e kubernetes/defectdojo/templates/_helpers.tpl && test "$(ls kubernetes/defectdojo/templates)" = "validate-tls.yaml"` | ❌ W0 | ⬜ pending |
| 26-04-1 | 26-04 | 4 | DDOJO-01 | T-26-01, T-26-03, T-26-07, T-26-08, T-26-17 | README has Secret contract, required sections incl. External PostgreSQL / Valkey, media emptyDir limitation; no backup mention, no environment identifiers; markdownlint | doc grep + pre-commit | `cd repos/security-platform && f=kubernetes/defectdojo/README.md && test "$(grep -ciE 'backup\|pg_dump' $f)" = 0 && test "$(grep -ciE 'ottawacloudconsulting\.com\|letsencrypt-\|occ-new\|homelab' $f)" = 0 && for s in defectdojo-postgresql-specific defectdojo-valkey-specific DD_CREDENTIAL_AES_256_KEY METRICS_HTTP_AUTH_PASSWORD emptyDir 'cert-manager\.io/cluster-issuer' siteUrl defectdojo-live-smoke.sh check-defectdojo-chart.sh ADR-023 '## External PostgreSQL / Valkey' '## Validating an install'; do grep -q "$s" $f \|\| { echo "missing $s"; exit 1; }; done && pre-commit run --files $f` | ❌ W0 | ⬜ pending |
| 26-04-2 | 26-04 | 4 | DDOJO-01 | — | Root README tree + Milestones row updated; gate still PASS | doc grep + offline | `cd repos/security-platform && grep -q '└── defectdojo/' README.md && grep -q 'DefectDojo chart complete (Phase 26)' README.md && test "$(grep -c 'DefectDojo planned' README.md)" = 0 && test "$(git diff HEAD~1 --numstat -- README.md \| cut -f1-2)" = "$(printf '3\t2')" && bash scripts/check-defectdojo-chart.sh \| tail -1 \| grep -qx 'PASS - 20 checks, 0 failures'` | ❌ W0 | ⬜ pending |
| 26-05-1 | 26-05 | 5 | DDOJO-01 | T-26-05, T-26-06, T-26-07 | Evidence: gate PASS 20/0, smoke ALL PASS rc=0, 0 FAIL, no credential-shaped values, cluster deleted | live smoke (phase gate) | `E=.planning/phases/26-defectdojo-generic-chart/evidence && grep -q 'PASS - 20 checks, 0 failures' $E/26-05-offline-gate.txt && grep -q 'ALL PASS' $E/26-05-live-smoke.txt && grep -q '^rc=0$' $E/26-05-live-smoke.txt && test "$(grep -c '^FAIL' $E/26-05-live-smoke.txt)" = 0 && test "$(grep -ciE 'password[=:] *[A-Za-z0-9]{12,}' $E/26-05-live-smoke.txt)" = 0 && ! kind get clusters 2>/dev/null \| grep -qx dd-smoke` | ❌ W0 | ⬜ pending |
| 26-05-2 | 26-05 | 5 | DDOJO-01 | T-26-07, T-26-12 | Checkov measured (local + CI-equivalent), pre-push hygiene recorded, scripts 100644, no vendored tgz, clean tree | measurement | `E=.planning/phases/26-defectdojo-generic-chart/evidence && grep -qiE 'failed[^0-9]*[0-9]+' $E/26-05-checkov.txt && grep -q 'CI-equivalent' $E/26-05-checkov.txt && grep -q 'hook-stage pre-push' $E/26-05-repo-hygiene.txt && test "$(cd repos/security-platform && git ls-files -s scripts/check-defectdojo-chart.sh scripts/defectdojo-live-smoke.sh \| cut -c1-6 \| sort -u)" = 100644 && test -z "$(cd repos/security-platform && git ls-files kubernetes/defectdojo/charts)" && test -z "$(cd repos/security-platform && git status --porcelain)"` | ❌ W0 | ⬜ pending |
| 26-06-1 | 26-06 | 6 | DDOJO-01 | T-26-01, T-26-19 | PR open from phase branch, clean tree, no `charts/` path in PR | remote state | `cd repos/security-platform && test -z "$(git status --porcelain)" && git rev-parse --abbrev-ref --symbolic-full-name @{u} \| grep -qx 'origin/feature/phase-26-defectdojo-generic-chart' && gh pr view --json state -q .state \| grep -qx OPEN && ! gh pr view --json files -q '.files[].path' \| grep -q '^kubernetes/defectdojo/charts/'` | ❌ W0 | ⬜ pending |
| 26-06-2 | 26-06 | 6 | DDOJO-01 | T-26-10 | Operator explicit approval before merge (blocking checkpoint); PR still OPEN | human gate + remote state | `cd repos/security-platform && gh pr view --json state -q .state \| grep -qx OPEN` | n/a | ⬜ pending |
| 26-06-3 | 26-06 | 6 | DDOJO-01 | T-26-11, T-26-19 | Chart and smoke on origin/main, no vendored tgz, PR MERGED | remote state | `cd repos/security-platform && git fetch origin && git ls-tree -r origin/main --name-only \| grep -qx 'kubernetes/defectdojo/templates/validate-tls.yaml' && git ls-tree -r origin/main --name-only \| grep -qx 'scripts/defectdojo-live-smoke.sh' && ! git ls-tree -r origin/main --name-only \| grep -q '^kubernetes/defectdojo/charts/' && gh pr view --json state -q .state \| grep -qx MERGED` | ❌ W0 | ⬜ pending |
| 26-07-1 | 26-07 | 7 | DDOJO-01 | T-26-01, T-26-12, T-26-18 | ADR-023 Accepted with What was NOT verified, no backup/homelab identifiers, accepted ADRs untouched | doc grep | `f=docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md && test -f $f && grep -q '^\*\*Status:\*\* Accepted' $f && grep -q '^## What was NOT verified' $f && test "$(grep -ciE 'backup\|pg_dump' $f)" = 0 && test "$(grep -c '^\|' $f)" = 0 && test "$(grep -ciE 'occ-new\|ottawacloudconsulting\.com\|letsencrypt-dns01' $f)" = 0 && git diff --quiet -- docs/adr/adr006* docs/adr/adr009* docs/adr/adr020* docs/adr/adr021* docs/adr/adr022*` | ❌ W0 | ⬜ pending |
| 26-07-2 | 26-07 | 7 | DDOJO-01 | — | ADR index row added, DDOJO-01 marked Complete | doc grep | `grep -q 'adr023-defectdojo-chart-base-tls-guard-and-version-pin.md' docs/adr/README.md && grep -q '^- \[x\] \*\*DDOJO-01\*\*' .planning/REQUIREMENTS.md && grep -q '\| DDOJO-01 \| Phase 26 \| Complete \|' .planning/REQUIREMENTS.md && test "$(git show --numstat --format= HEAD -- docs/adr/README.md \| cut -f1-2)" = "$(printf '1\t0')" && git show --stat HEAD \| grep -q adr023` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Task ID format 26-0P-T (plan P, task T). Automated commands are copied verbatim from each task's `<verify><automated>`; pipes are escaped as `\|` for the table. Commands run from the documentation repo root unless they `cd repos/security-platform`.*

---

## Wave 0 Requirements

- [ ] `repos/security-platform/scripts/check-defectdojo-chart.sh` — offline gate for DDOJO-01 (check IDs in 26-RESEARCH.md)
- [ ] `repos/security-platform/scripts/defectdojo-live-smoke.sh` — live smoke for DDOJO-01; clone ownership guard, context restore and SKIPPED/FAILURES/CHECKS_PASSED accounting from `nexus-live-smoke.sh`
- [ ] Framework install: none — all tools present (helm v4.3.0, kind, kubectl, checkov, shellcheck)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Checkov count on rendered chart recorded (CI coverage = 0) | DDOJO-01 | Guard fails bare render, so CI Checkov cannot cover chart | `helm template … > r.yaml && checkov -f r.yaml --framework kubernetes`; record counts in SUMMARY |
| Chart public on `security-platform` main; CI green | DDOJO-01 | Operator approval of PR merge | `gh pr checks <n> --watch`, then operator merges |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10s (offline gate; live-smoke exception noted under Sampling Rate)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
