---
phase: 15
slug: five-parallel-scan-jobs
status: draft
nyquist_compliant: true
wave_0_complete: true
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

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| 15-01 T1 | 01 | 1 | CICD-01, SCA-04 | Branch cut from `origin/main`; exactly 4 `exclude: ^fixtures/` entries on terraform_fmt/terraform_validate/hadolint/npm-audit; Gitleaks untouched | git/static | branch/ancestor check + `pre-commit validate-config` + `yamllint` + exclude-count + gitleaks-untouched assertions (see 15-01-PLAN.md Task 1 `<verify>`) | ⬜ pending |
| 15-01 T2 | 01 | 1 | CICD-01, SCA-04 | fixtures/ tree authored; Checkov, `trivy fs`, `trivy image` each produce real non-zero findings; commit passes hooks with no bypass | smoke (local) | Checkov/`trivy fs`/`trivy image` exit-1 + non-empty-findings assertions, `pre-commit run --all-files` exit 0 (see 15-01-PLAN.md Task 2 `<verify>`) | ⬜ pending |
| 15-02 T1 | 02 | 2 | CICD-01, SCA-04 | `scripts/smoke-scans.sh` exists, no executable bit, wraps all five scanners with captured exit codes | static | script-exists + non-executable + shellcheck assertions (see 15-02-PLAN.md Task 1 `<verify>`) | ⬜ pending |
| 15-02 T2 | 02 | 2 | CICD-01, SCA-04 (SC#2, SC#3) | Running the smoke gate produces real, non-empty results for all five tools including generic Trivy fs SCA | smoke (local) | `bash scripts/smoke-scans.sh` + per-tool non-empty-report assertions (see 15-02-PLAN.md Task 2 `<verify>`) | ⬜ pending |
| 15-03 T1 | 03 | 3 | CICD-01 (SC#1, SC#5) | `security.yml` defines 5 jobs, no `needs:`, step-level `continue-on-error`, SHA-pinned actions | static | `actionlint` + `yamllint` + Python frontmatter/structure assertions (5 jobs, no needs, permissions read-only) (see 15-03-PLAN.md Task 1 `<verify>`) | ⬜ pending |
| 15-03 T2 | 03 | 3 | CICD-01 (SC#4) | Workflow re-verified against smoke gate; each job's SARIF/JSON evidence step present | static + smoke (local) | re-run smoke gate + `ls -l`-style evidence-step presence assertions (see 15-03-PLAN.md Task 2 `<verify>`) | ⬜ pending |
| 15-04 T1 | 04 | 4 | CICD-01 (SC#1) | PR opened from the phase branch against the target repo; run identified | integration (live) | `gh pr create` / `gh pr view` + run-id capture assertions (see 15-04-PLAN.md Task 1 `<verify>`) | ⬜ pending |
| 15-04 T2 | 04 | 4 | CICD-01 (SC#1, SC#5) | 5 concurrent `security / *` checks; PR remains `MERGEABLE` with all checks `SUCCESS` | integration (live) | `gh api .../check-runs` → count=5 + `gh pr view --json mergeable,statusCheckRollup` assertions (see 15-04-PLAN.md Task 2 `<verify>`) | ⬜ pending |
| 15-05 T1 | 05 | 5 | CICD-01 | Human confirms concurrency + report-only behavior from live evidence before merge (blocking checkpoint, `autonomous: false`) | manual + integration (live) | human sign-off gate (see 15-05-PLAN.md Task 1) | ⬜ pending |
| 15-05 T2 | 05 | 5 | CICD-01 | Merge on approval; `main` reflects the merge; open questions from RESEARCH.md closed | integration (live) | merge + `main` HEAD assertion (see 15-05-PLAN.md Task 2 `<verify>`) | ⬜ pending |

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
