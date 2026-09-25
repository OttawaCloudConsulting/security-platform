---
phase: 26-defectdojo-generic-chart
plan: 04
subsystem: kubernetes/defectdojo documentation (security-platform)
tags: [docs, readme, defectdojo, helm, cert-manager, secrets]
requires:
  - "26-01: scripts/check-defectdojo-chart.sh (20-check offline gate)"
  - "26-02: scripts/defectdojo-live-smoke.sh"
  - "26-03: kubernetes/defectdojo wrapper chart"
provides:
  - "kubernetes/defectdojo/README.md: consumer contract (Secrets, issuer, host/siteUrl, uwsgi footprint, external DB recipe, limitations)"
  - "security-platform root README lists kubernetes/defectdojo/"
affects: [26-05, 26-06, 26-07]
tech-stack:
  added: []
  patterns:
    - "Nexus README section order and 'measured, not assumed' register reused"
    - "Secret example feeds all values over stdin (kubectl apply -f - heredoc); admin password via read -rsp; generated keys at upstream randAlphaNum lengths"
key-files:
  created:
    - repos/security-platform/kubernetes/defectdojo/README.md
  modified:
    - repos/security-platform/README.md
decisions:
  - "Media stays upstream emptyDir (RESEARCH OQ1); documented as a Limitations bullet with the defectdojo.django.mediaPersistentVolume.* override; operator acceptance is 26-06"
  - "External PostgreSQL / Valkey recipe written from the pinned 1.9.53 values/templates and checked by an offline render, not copied from upstream README (which ends with createSecret=true, contradicting D-13)"
  - "README states no Checkov count for this chart; it points at the phase record, because the RESEARCH 66/568 figure was a prototype render"
metrics:
  duration: "~20 min"
  completed: 2026-09-25
  tasks: 2
  files: 2
---

# Phase 26 Plan 04: DefectDojo chart README Summary

`kubernetes/defectdojo/README.md` (349 lines) is now the consumer contract for the chart. It covers the three pre-created Secrets and their exact keys, the required issuer annotation, setting `host` and `siteUrl` together, and the measured uwsgi footprint. It also has an external PostgreSQL / Valkey recipe checked against the pinned chart, and a Limitations section: media is `emptyDir`, CI Checkov covers the chart zero times, ingress-nginx is smoke-only and archived, there is a CSRF fallback, and version bumps are manual. The security-platform front page now lists the chart.

## Tasks

| # | Task | Commit (security-platform) | Files |
|---|------|--------|-------|
| 1 | Chart README for kubernetes/defectdojo | `2b039c5`, fix `60205bd` | `kubernetes/defectdojo/README.md` |
| 2 | Root README tree and Milestones row | `56fa939` | `README.md` |

## Verification (measured, from repos/security-platform/)

- Task 1 `<automated>` block exits 0:
  - forbidden `backup|pg_dump` = 0;
  - environment identifiers (`ottawacloudconsulting.com`, `letsencrypt-`, `occ-new`, `homelab`) = 0;
  - all required strings are present;
  - markdownlint Passed.
- All ten required `##` sections are present, in the Nexus order. `emptyDir` appears inside `## Limitations and Notes` (line 338). The keys `DD_ADMIN_PASSWORD`, `DD_SECRET_KEY`, `postgresql-postgres-password`, `postgresql-password` and `valkey-password` are all present.
- `ingress-nginx` appears on 3 lines. One is in `## Validating an install` (harness only). The other two are in `## Limitations and Notes` (the not-recommended bullet and the CSRF bullet). None tells the reader to install it.
- No literal secret values appear. The admin password is entered with `read -rsp`, the other values are generated, and everything goes through a stdin heredoc and is then unset.
- Task 2 `<automated>` block exits 0. `git diff HEAD~1 --numstat -- README.md` = `3	2`. `bash scripts/check-defectdojo-chart.sh` prints `PASS - 20 checks, 0 failures`. security-platform `git status --porcelain` is empty.
- External-DB recipe: `helm template` with `postgresql.enabled=false`, `postgresServer`, `valkey.enabled=false` and `redisServer` exits 0. The render contains no PostgreSQL or Valkey objects. The ConfigMap has `DD_DATABASE_HOST`/`DD_CELERY_BROKER_HOST` set to the external hosts and `DD_DATABASE_PORT` `'5432'`. Clients read `postgresql-password` (8 references) and never `postgresql-postgres-password` (0). This was checked by render only; no live external database was used.

## Deviations from Plan

None that change scope. Two editorial choices were made within the plan's latitude:

- The Requirements table phrases DDOJO-05 as "validated live via a private ArgoCD overlay". The REQUIREMENTS.md text contains "homelab", which the acceptance grep forbids.
- The Checkov Limitations bullet gives no finding count. RESEARCH's 66 failed / 568 passed was measured on the prototype render, not on the committed chart, so the README points at the phase record instead. 26-06 or 26-07 should re-measure against the final chart if a number is wanted.

**Post-task fix (`60205bd`, found in review).** §4 had stated the uwsgi fd-table mechanism as fact, but RESEARCH A6 marks it as assumed. It now says the mechanism is inferred from the log line and that only the `maxFd` fix is measured. The same commit adds a caveat that the admin password must not contain `"` or `\`, because the Secret heredoc puts it in a double-quoted YAML string. The Task 1 `<automated>` block was re-run against this commit and exited 0, with markdownlint Passed.

## Notes for later plans

- 26-05: the README quotes these measurements, all from RESEARCH and all taken on kind: the 101 s warm install, the uwsgi peak of 388-430 MiB, and the OOM causes. If the live smoke measures different values, update them. The README does not claim the smoke has passed.
- 26-06: surface decision (a), media `emptyDir`, for operator acceptance. The README states it as a Limitation together with its override keys.
- 26-07: the README cites ADR-023 by number, so the ADR must land under that number.

## Known Stubs

None. `defectdojo.example.com`/`.org`, `NAME`, `db.example.org` and `cache.example.org` are deliberate placeholders (T-26-01).

## Self-Check: PASSED

- FOUND: repos/security-platform/kubernetes/defectdojo/README.md
- FOUND: 2b039c5, 56fa939, 60205bd on feature/phase-26-defectdojo-generic-chart
