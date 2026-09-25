---
phase: 26-defectdojo-generic-chart
plan: 03
subsystem: kubernetes/defectdojo wrapper chart (security-platform)
tags: [helm, defectdojo, wrapper-chart, cert-manager, tls, ingress, valkey, uwsgi]
requires:
  - "26-01: scripts/check-defectdojo-chart.sh (20-check offline gate)"
  - "26-02: scripts/defectdojo-live-smoke.sh (gates on templates/validate-tls.yaml)"
provides:
  - "kubernetes/defectdojo/: values-only wrapper around the official defectdojo 1.9.53 chart (DDOJO-01 artifact)"
  - "templates/validate-tls.yaml: render-time fail guard for the cert-manager issuer (D-11)"
affects: [26-04, 26-05, 26-06, 26-07]
tech-stack:
  added:
    - "defectdojo Helm chart 1.9.53 (appVersion 3.3.200) as a dependency, fetched from the DefectDojo helm-charts branch"
  patterns:
    - "Values-only wrapper: one `defectdojo:` value tree, no _helpers.tpl, no define"
    - "fail guard on the subchart annotation map instead of a wrapper `required` value"
    - "Image tags pinned in values (inverts the nexus no-image-block rule) because of Django migrations"
key-files:
  created:
    - repos/security-platform/kubernetes/defectdojo/Chart.yaml
    - repos/security-platform/kubernetes/defectdojo/Chart.lock
    - repos/security-platform/kubernetes/defectdojo/.helmignore
    - repos/security-platform/kubernetes/defectdojo/values.yaml
    - repos/security-platform/kubernetes/defectdojo/templates/validate-tls.yaml
  modified: []
decisions:
  - "Ingress enabled/activateTLS/secretName restated explicitly in values.yaml so D-09/D-10 do not rely on upstream defaults surviving a bump; ingressClassName kept absent (D-12)"
  - "Issuer kind is chosen by the annotation key itself (cluster-issuer vs issuer); no issuerKind value"
  - "check-defectdojo-chart.sh needed no edit: all 20 assertions matched the measured chart"
metrics:
  duration: "~10 min"
  completed: 2026-09-25
  tasks: 2
  files: 5
---

# Phase 26 Plan 03: DefectDojo wrapper chart Summary

`kubernetes/defectdojo/` now exists in security-platform. It is a values-only wrapper around the official `defectdojo` 1.9.53 chart and pins DefectDojo 3.3.200 at all four points. Its only template is a `fail` guard, which refuses to render with TLS on unless exactly one cert-manager issuer annotation is set and `secretName` is non-empty. The offline gate went from SKIP to `PASS - 20 checks, 0 failures`, and I did not change the gate.

## Tasks

| # | Task | Commit (security-platform) | Files |
|---|------|--------|-------|
| 1 | Chart.yaml, Chart.lock, .helmignore, values.yaml | `c3ab0cd` | Chart.yaml, Chart.lock, .helmignore, values.yaml |
| 2 | validate-tls.yaml guard; gate green | `a06393f` | templates/validate-tls.yaml |

## Dependency integrity (T-26-SC)

- `helm dependency build kubernetes/defectdojo` (Helm v4.3.0+gbec5b06) downloaded `charts/defectdojo-1.9.53.tgz`.
- Tarball sha256: `0393332d77412d2a76921f418faf933e9739088ddbf207b2a4b94867daa0657d`. This **equals** the helm-charts index digest recorded in RESEARCH, so the tarball matches.
- Chart.lock `digest: sha256:166631323235f3ee77e820d8ed144c002e33fc6affc996602cd78fc38b473b1f` is Helm's hash of the dependency list, not the tarball hash. `generated: 2026-09-24T20:41:11-04:00`.
- `git ls-files kubernetes/defectdojo/charts` prints nothing, so the tgz is still gitignored.

## RED / GREEN evidence (Task 2)

RED: `validate-tls.yaml` contained only its block comment, so the gate ran instead of printing SKIP. It exited 1:

```
check-defectdojo-chart: asserting 20 offline invariants against kubernetes/defectdojo
FAIL: ISSUER-REQUIRED: a bare 'helm template kubernetes/defectdojo' SUCCEEDED — the certificate issuer has a default (or the TLS guard is gone)
FAIL: ISSUER-NOT-BOTH: 'helm template' with BOTH cert-manager.io/cluster-issuer and cert-manager.io/issuer set SUCCEEDED — the guard must refuse an ambiguous issuer
FAIL: TLS-SECRETNAME-REQUIRED: render with an empty defectdojo.django.ingress.secretName SUCCEEDED — the TLS guard does not check it
FAILED - 3 check(s)
```

Only the three guard checks failed. The other 17 invariants passed already on the Task 1 values, so the RED failures are specific to the guard.

GREEN: after adding the guard body, the gate exited 0:

```
check-defectdojo-chart: asserting 20 offline invariants against kubernetes/defectdojo
PASS - 20 checks, 0 failures
```

## Behaviour verified (all renders with `--namespace defectdojo`)

| Case | Result |
|------|--------|
| Bare render | exit 1; message names `cert-manager.io/cluster-issuer` |
| Only `cert-manager.io/issuer=x` | exit 0 |
| Both issuer keys | exit 1, `set only one of cert-manager.io/cluster-issuer and cert-manager.io/issuer` |
| Issuer set, `secretName=` | exit 1, `... secretName must be non-empty when TLS is on ...` |
| `activateTLS=false`, no issuer | renders; the Ingress has no `spec.tls` |
| Issuer set | Ingress name `t-defectdojo`; every `# Source:` comes from `charts/`, so the wrapper adds zero objects |
| `helm lint ... --set cluster-issuer=x` | 0 failed (INFO only: icon recommended) |
| `pre-commit run --files` (Chart.yaml, values.yaml, validate-tls.yaml) | exit 0 (yamllint Passed) |

Task 1 acceptance: the dependency line and the quoted `appVersion: "3.3.200"` are correct, and `.helmignore` does not differ from the nexus copy. `values.yaml` has only the `defectdojo` key and does not set `ingressClassName`. Forbidden-key grep = 0, environment-identifier grep = 0. The gate printed `SKIP: chart incomplete` before Task 2.

## Deviations from Plan

None. The plan executed exactly as written, and `scripts/check-defectdojo-chart.sh` was not edited.

## Known Stubs

None. `defectdojo.example.com` is a deliberate placeholder (T-26-01, gate PLACEHOLDER-ONLY). The README is due in 26-04.

## Self-Check: PASSED

- FOUND: kubernetes/defectdojo/{Chart.yaml,Chart.lock,.helmignore,values.yaml,templates/validate-tls.yaml} (git ls-files)
- FOUND: c3ab0cd, a06393f on feature/phase-26-defectdojo-generic-chart
- security-platform `git status --porcelain` is empty
