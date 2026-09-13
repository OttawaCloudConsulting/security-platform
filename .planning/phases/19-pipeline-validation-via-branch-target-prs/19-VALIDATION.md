---
phase: 19
slug: pipeline-validation-via-branch-target-prs
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-12
updated: 2026-09-13
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Rewritten by the planner against the seven finalised plans. Task IDs below are `19-<plan>-<task>`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None. This phase validates a live GitHub Actions pipeline plus two new scanner fixtures. Verification is local scanner runs (`semgrep`, `gitleaks`, `ruff`), two repo-local bash gates, and `gh` CLI / REST assertions — not a test runner. |
| **Config file** | `repos/security-platform/.github/workflows/security.yml` and `pr-security.yml` (read-only this phase); `repos/security-platform/.pre-commit-config.yaml` |
| **Quick run command** | `bash repos/security-platform/scripts/check-workflow-uploads.sh` (offline, seconds; needs `pyyaml`) |
| **Full suite command** | `bash repos/security-platform/scripts/smoke-scans.sh` — **hard-fails on this workstation** unless the 19-01 venv's `semgrep` is on `PATH` first; its hard-tier preflight loops `semgrep checkov trivy gitleaks docker python3 npm` and `exit 1`s on the first missing binary |
| **Estimated runtime** | local scans: seconds to ~4 min; each live Actions run: ~2-5 min |

---

## Sampling Rate

- **After every fixture edit (19-01):** `ruff check` + `ruff format --diff` BEFORE commit (the hook carries `args: [--fix]` and rewrites in place), then the byte-exact CI semgrep invocation, then `gitleaks git .` after the commit (CI scans history, so the fixture is only visible to the matching invocation once committed).
- **After every script/doc edit (19-02):** `bash -n`, `pre-commit run shellcheck`, `pre-commit run markdownlint`, and the extracted-heredoc guard tests — never a full smoke-gate run.
- **After every live run:** capture the run id, the five `security / …` conclusions, the anchored `gate_mode=` line counts and the artifact manifest IMMEDIATELY, before triggering the next run. Each measurement is destroyed by the next one.
- **Phase gate:** all four criteria evidenced with recorded run ids, alert numbers and tree hashes, and `gh variable list` empty.
- **Max feedback latency:** ~5 minutes (Actions run duration).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | VAL-01 | T-19-02, T-19-05 | Branch cut from `origin/main`; pre-fixture Semgrep/Gitleaks baselines enumerated as rule/path pairs; `.gitleaksignore` carries zero fingerprints | local-scan | `python3 -c "import json,sys; r=json.load(open(sys.argv[1]))['results']; …" "$SCRATCH/sg-baseline.json"` and `grep -vc '^#' repos/security-platform/.gitleaksignore` | ✅ | ⬜ pending |
| 19-01-02 | 01 | 1 | VAL-01 | T-19-01, T-19-03, T-19-04 | Both fixtures carry the byte-exact header on line 1; silent constructs annotated; synthetic key is non-`EXAMPLE` | source-assert | `head -1 repos/security-platform/fixtures/vulnerable.py repos/security-platform/fixtures/secret.env \| grep -c 'INTENTIONALLY VULNERABLE'` and `grep -E '^AWS_ACCESS_KEY_ID=AKIA[A-Z0-9]{16}$' repos/security-platform/fixtures/secret.env` | ✅ | ⬜ pending |
| 19-01-03 | 01 | 1 | VAL-01 | T-19-02, T-19-05 | `eval-detected` fires at `fixtures/vulnerable.py`; `aws-access-token` fires at `fixtures/secret.env`; ruff clean; committed blobs byte-identical to measured files | local-scan | `ruff check fixtures/vulnerable.py && ruff format --diff fixtures/vulnerable.py`; the two rule-id/path python assertions against `$SCRATCH/sg-fixtures.json` and `$SCRATCH/gl-fixtures.json` | ✅ | ⬜ pending |
| 19-02-01 | 02 | 2 | VAL-01 | T-19-06 | README documents both fixtures one row per consuming job; both stale claims replaced | source-assert | `pre-commit run markdownlint --files fixtures/README.md`; `! grep -q 'no fixture ever contains a real secret, so' fixtures/README.md` | ✅ | ⬜ pending |
| 19-02-02 | 02 | 2 | VAL-01 | T-19-07, T-19-08, T-19-09 | Smoke gate FAILS when `eval-detected`/`aws-access-token` are absent; assertions guarded and routed to `FAILURES+=`; no secret value matched | test-command | `bash -n scripts/smoke-scans.sh`; `pre-commit run shellcheck --files scripts/smoke-scans.sh`; extracted-heredoc runs against real / filtered / invalid reports (6 exit codes) | ✅ | ⬜ pending |
| 19-03-01 | 03 | 3 | VAL-01 | T-19-11, T-19-13, T-19-14 | Validation PR opened under report-only; five frozen check-run names present; anchored `gate_mode=report-only$` count is 5 | cli-assert | `gh variable list -R OttawaCloudConsulting/security-platform`; `gh api repos/…/commits/$SHA/check-runs --jq '[.check_runs[]\|select(.name\|startswith("security / "))\|{name,conclusion}]'`; `grep -c 'gate_mode=report-only$'` | N/A | ⬜ pending |
| 19-03-02 | 03 | 3 | VAL-01 | T-19-10, T-19-12 | SC1 — one detection per job matched on rule id AND fixture path, read from the downloaded artifacts, never from a total | cli-assert | `gh api repos/…/actions/runs/$RUN/artifacts`; five `gh run download`; the five per-job python assertions (each exits non-zero when absent) | N/A | ⬜ pending |
| 19-04-01 | 04 | 4 | VAL-01 | T-19-15, T-19-16, T-19-17 | SC3 hops 1-3 agree on rule and line; alert read through the `refs/pull/<N>/merge` ref filter; unfiltered query recorded as `[]` control | cli-assert | `gh api "repos/…/code-scanning/alerts?ref=refs/pull/$PR/merge&tool_name=Semgrep%20OSS"`; the line-agreement python assertion across grep + artifact | N/A | ⬜ pending |
| 19-04-02 | 04 | 4 | VAL-01 | T-19-15 | A human confirms the alert's own `html_url` renders an entry for `fixtures/vulnerable.py` | **manual-only** | — (see Manual-Only Verifications) | N/A | ⬜ pending |
| 19-05-01 | 05 | 5 | VAL-01 | T-19-19 | Operator authorises the repository-wide blocking window with every open PR enumerated | **manual-only** | — (see Manual-Only Verifications) | N/A | ⬜ pending |
| 19-05-02 | 05 | 5 | VAL-01 | T-19-20, T-19-21, T-19-22, T-19-23, T-19-24 | SC2 — five `failure` under blocking, five `success` after restore, three identical tree hashes, artifacts and SARIF counted under blocking, variable DELETED unconditionally | cli-assert | three-commit `git rev-parse …^{tree}` comparison + `git diff --stat HEAD~2 HEAD`; per-run `gate_mode=` anchored counts and `artifacts.total_count`; `gh variable list` empty; `rules/branches/main` unchanged | N/A | ⬜ pending |
| 19-05-03 | 05 | 5 | VAL-01 | T-19-20 | A human confirms the paired verdicts and that no `GATE_MODE` variable remains (the D-09 verification) | **manual-only** | — (see Manual-Only Verifications) | N/A | ⬜ pending |
| 19-06-01 | 06 | 6 | VAL-01 | T-19-26, T-19-27, T-19-38 | Clean branch cut from POST-merge `origin/main`; exactly one non-fixture path changed (the repo-root `README.md`); both seeded fixtures PRESENT on the branch, because PR #10's merge put them on `main` | cli-assert | `git diff origin/main --name-only`; `git diff origin/main -- fixtures/ .github/ scripts/ --stat` empty; `test -e fixtures/vulnerable.py && test -e fixtures/secret.env` | ✅ | ⬜ pending |
| 19-06-02 | 06 | 6 | VAL-01 | T-19-25, T-19-28, T-19-29 | SC4 — five `security / …` check runs concluded `success` with `GATE_MODE` absent at run time and per-job findings recorded non-zero | cli-assert | `gh api repos/…/commits/$SHA/check-runs --jq '[…\|select(.conclusion != "success")]\|length'` returns 0; `gh variable list` empty; `grep -c 'gate_mode=report-only$'` is 5 | N/A | ⬜ pending |
| 19-07-01 | 07 | 7 | VAL-01 | T-19-30 | Operator decides merge vs close (D-10); nothing executed before the reply | **manual-only** | — (see Manual-Only Verifications) | N/A | ⬜ pending |
| 19-07-02 | 07 | 7 | VAL-01 | T-19-31, T-19-33, T-19-34, T-19-35 | Outcome verified from `origin/main`; repo ends with no `GATE_MODE` and an unchanged ruleset; VAL-01 marked complete against a four-row evidence index | cli-assert | `git show origin/main:fixtures/vulnerable.py \| head -1`; `gh variable list` empty; `gh api …/rules/branches/main --jq '.[].type'`; `grep -n 'VAL-01' .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Sampling continuity check:** the longest run of consecutive manual-only tasks is 2 (`19-04-02` → `19-05-01`). No three consecutive tasks lack an automated verify.

---

## Wave 0 Requirements

No test framework is needed and none may be added. Two gaps the researcher flagged are closed by plan design rather than by new infrastructure:

- **Stale/absent inner checkout** — closed by 19-01 Task 1's preflight: clone-or-fetch, assert `origin/main` is `2e29004` or later, `git checkout -B feature/phase-19-pipeline-validation origin/main`.
- **No local `semgrep`** — closed by 19-01 Task 1's throwaway venv at the identical pinned spec (`semgrep==1.177.0`) already on `security.yml` line 70. Executor-local, never committed, no package-legitimacy checkpoint required.
- **SC3's UI observation** — closed by 19-04 Task 2's `checkpoint:human-verify`; there is no automated substitute and Phase 17 proved that inferring it from the API produces NOT OBSERVED.

Pre-Wave-1 environment confirmation: `gitleaks version` (expect 8.30.1, the exact CI pin), `ruff --version`, `python3 --version`, `gh auth status`.

---

## Manual-Only Verifications

| Task ID | Behavior | Requirement | Why Manual | Test Instructions |
|---------|----------|-------------|------------|-------------------|
| 19-04-02 | SC3's Security tab entry is seen rendered | VAL-01 | GitHub UI-rendered alert page. Phase 17 scored the equivalent criterion NOT OBSERVED for offering API evidence where a UI observation was asked for; 17-07 made that a standing rule. RESEARCH Q2. | Open the ONE `html_url` Claude provides (`https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/<id>`). Confirm it renders an alert, names `fixtures/vulnerable.py`, shows the Semgrep `eval-detected` rule, and matches Claude's line number. Never "open the Security tab" — unfiltered it is empty by design (ADR-016 D-02). |
| 19-05-01 | Authorise opening the repository-wide blocking window | VAL-01 | `GATE_MODE=blocking` gates EVERY PR and Dependabot run in the repository while set. Irreversible mid-flight risk per the session-management protocol. | Read the preflight table: `gh variable list` empty, every open PR enumerated, `rules/branches/main` showing only `deletion`/`non_fast_forward`. Reply "go" to authorise. |
| 19-05-03 | Confirm the paired verdicts and the D-09 restore | VAL-01 | "Witnessed, not inferred" (SC2) requires a human to see the red run and the green run on the same tree, and to confirm the variable is gone. This VERIFIES the restore; it does not gate it — the `gh variable delete` already ran unconditionally inside 19-05-02, because a human gate between `set` and `delete` risks leaving a live repository in blocking. | Open the PR's checks page; confirm one attempt all-red and a later one all-green on commits sharing a tree hash. Open one red job and confirm `gate_mode=blocking`, a red scan step, and green uploads below it. Run `gh variable list -R OttawaCloudConsulting/security-platform` yourself — it must print nothing. |
| 19-07-01 | D-10 merge-vs-close decision | VAL-01 | Irreversible action on a shared live public repository; CONTEXT explicitly leaves the choice to execution time. D-04 is already satisfied — PR #10's merge landed both fixtures on `main` — so "close" strands no fixture; its cost is deferred item D-19-A instead. | Claude presents the four captured criteria, the REPLACEMENT validation PR's live state (branch `feature/phase-19-gate-mode-proof`), and both options with consequences. Reply `merge` or `close` — and if `close`, name who lands the D-19-A `fixtures/README.md` push-protection correction on `main`. |

---

## Validation Sign-Off

- [x] All tasks have an automated verify (local-scan, source-assert, test-command or cli-assert) or an explicit manual-only justification
- [x] Sampling continuity: longest manual-only run is 2; no 3 consecutive tasks without automated verify
- [x] Wave 0 gaps closed by plan design (preflight clone/fetch, scratch venv, SC3 checkpoint) — no new framework added
- [x] No watch-mode flags
- [x] Feedback latency < 300s (Actions run duration)
- [x] Every threat in the plans' STRIDE registers is referenced by at least one task row
- [x] `nyquist_compliant: true`

**Approval:** approved by the planner, 2026-09-12.
