---
phase: 15
slug: five-parallel-scan-jobs
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-10
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

This is a CI-workflow phase; there is no unit-test framework in the target repo (`repos/security-platform/`). Validation is (a) static lint of the workflow YAML, (b) local execution of the exact scanner commands, (c) the live PR's check-runs.

| Property | Value |
|----------|-------|
| **Framework** | `actionlint` 1.7.12 (workflow static analysis) + direct CLI smoke runs |
| **Config file** | none — `actionlint` needs none; `.pre-commit-config.yaml` covers yamllint |
| **Quick run command** | `actionlint repos/security-platform/.github/workflows/*.yml` |
| **Full suite command** | local smoke block (below), then `gh api .../check-runs` on the live PR |
| **Estimated runtime** | ~60s local smoke; check-run confirmation depends on PR CI runtime |

Baseline confirmed this session: `actionlint` exits 0 on current workflows; `yamllint -d relaxed` emits one line-length warning (81 > 80), exits 0.

---

## Sampling Rate

- **After every task commit:** `actionlint` on the workflow + the smoke command for whichever job that task touched
- **After every plan wave:** full local smoke block
- **Before `/gsd:verify-work`:** a live PR on `OttawaCloudConsulting/security-platform` showing five `security / *` checks, all green, with `gh pr view --json mergeable` reporting `MERGEABLE`
- **Max feedback latency:** ~60s locally; live-PR confirmation is the phase gate by design

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 0 | CICD-01 | — | Workflow YAML valid, 5 jobs, no `needs:` | static | `actionlint repos/security-platform/.github/workflows/security.yml && python3 -c "import yaml,sys; w=yaml.safe_load(open('repos/security-platform/.github/workflows/security.yml')); assert len(w['jobs'])==5; assert all('needs' not in j for j in w['jobs'].values())"` | ❌ W0 | ⬜ pending |
| 15-01-02 | 01 | 0 | CICD-01 | — | Five checks appear concurrently on the PR | integration (live) | `gh api repos/OttawaCloudConsulting/security-platform/commits/$SHA/check-runs --jq '[.check_runs[]\|select(.name\|startswith("security / "))]\|length'` → `5` | ❌ W0 | ⬜ pending |
| 15-01-03 | 01 | 0 | CICD-01 (SC#5) | — | PR remains mergeable despite findings | integration (live) | `gh pr view <n> --json mergeable,statusCheckRollup` → `MERGEABLE`, all `SUCCESS` | ❌ W0 | ⬜ pending |
| 15-01-04 | 01 | 0 | CICD-01 (SC#2) | — | Each tool produces a real, non-empty result | smoke (local) | see smoke block — each asserts exit 1 and a non-empty report | ❌ W0 | ⬜ pending |
| 15-01-05 | 01 | 0 | CICD-01 (SC#4) | — | Each job writes SARIF and/or JSON | smoke (local) + log inspection | `test -s <file>` locally; `ls -l` evidence step in each job | ❌ W0 | ⬜ pending |
| 15-01-06 | 01 | 0 | SCA-04 | — | Generic Trivy fs scan finds packages, no per-ecosystem config | smoke (local) | `trivy fs fixtures --scanners vuln --format json -o /tmp/t.json; python3 -c "import json;d=json.load(open('/tmp/t.json'));assert any(r.get('Vulnerabilities') for r in d['Results'])"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `fixtures/README.md`, `fixtures/Dockerfile`, `fixtures/package.json`, `fixtures/package-lock.json`, `fixtures/main.tf` — the scan targets themselves (covers SC#2 for IaC/container/SCA). Dockerfile base image must be a **supported** distro with unpatched CVEs (e.g. `debian:12-slim` — NOT `alpine:3.14`, which is EOL and yields zero Trivy findings). `main.tf` must contain misconfigured resources (open security group, unencrypted S3) — provider pinning alone yields zero Checkov findings.
- [ ] `.pre-commit-config.yaml` — add `exclude: ^fixtures/` to `hadolint`, `npm-audit`, `terraform_fmt`, `terraform_validate` hooks (these are what actually block the fixture commit, not Gitleaks)
- [ ] A local smoke script (`bash scripts/smoke-scans.sh`, no executable bit per project rules) wrapping the smoke block below
- [ ] No test framework install needed — `actionlint` and all five scanners already present locally

---

## Local Smoke Block (Wave 0 deliverable — expected results measured this session)

```bash
cd repos/security-platform

# SAST — expect exit 1, >=2 findings (repo sources; no fixture needed)
semgrep scan --config p/default --metrics=off --error \
  --json-output=/tmp/sg.json --sarif-output=/tmp/sg.sarif . ; echo "semgrep exit=$?"   # 1

# IaC — expect exit 1, ~12 failed checks (0 without fixtures — see C-2)
checkov -d . --quiet --compact --output cli --output json --output sarif \
  --output-file-path console,/tmp/ckv.json,/tmp/ckv.sarif ; echo "checkov exit=$?"     # 1

# SCA — expect exit 1, >=9 npm vulnerabilities from fixtures/package-lock.json
trivy fs . --scanners vuln --format json -o /tmp/tfs.json --exit-code 1 \
  --severity HIGH,CRITICAL ; echo "trivy fs exit=$?"
trivy convert --format sarif -o /tmp/tfs.sarif /tmp/tfs.json

# Container — expect exit 1, >=50 HIGH/CRITICAL (0 if an EOL base slipped in — see C-1)
docker build -f fixtures/Dockerfile -t scan-fixture:local fixtures/
trivy image scan-fixture:local --scanners vuln --format json -o /tmp/timg.json \
  --exit-code 1 --severity HIGH,CRITICAL ; echo "trivy image exit=$?"
trivy convert --format sarif -o /tmp/timg.sarif /tmp/timg.json

# Secrets — expect exit 1, 9 findings from git history (dir mode returns 0!)
gitleaks git . --no-banner --redact --report-format sarif --report-path /tmp/gl.sarif
echo "gitleaks exit=$?"   # 1

# Every report must be non-empty
for f in /tmp/sg.json /tmp/sg.sarif /tmp/ckv.json /tmp/ckv.sarif \
         /tmp/tfs.json /tmp/tfs.sarif /tmp/timg.json /tmp/timg.sarif /tmp/gl.sarif; do
  test -s "$f" && echo "OK   $f" || echo "FAIL $f"
done

# Hook exclusions actually work
pre-commit run --all-files
```

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Five checks show as concurrent (not sequential) on a live PR timeline | CICD-01 | GitHub UI/API timing is the actual proof of "parallel"; local smoke can't observe scheduler behavior | Open the PR's checks tab, confirm all five `security / *` runs start within seconds of each other with overlapping durations |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (local); live-PR gate documented as phase-gate exception
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
