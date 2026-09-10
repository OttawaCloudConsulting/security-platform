# Phase 15: Five Parallel Scan Jobs - Research

**Researched:** 2026-09-10
**Domain:** GitHub Actions CI security scanning (SAST / IaC / SCA / container / secrets), reusable `workflow_call` workflows, scan fixtures
**Confidence:** HIGH — nearly every claim below was verified by running the actual tool locally or querying the GitHub API in this session.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Fixture strategy
- **D-01:** New top-level `fixtures/` directory, NOT gitignored (distinct from the gitignored `repos/` tree), containing a minimal Dockerfile, `package-lock.json`, and `.tf` file so IaC/container/SCA jobs have real files in the checkout.
- **D-02:** Fixture content is deliberately vulnerable, not just structurally valid — an old/vulnerable npm dependency pin, an unpinned/old Terraform provider version, and a Dockerfile `FROM` an old base image with known CVEs. Guarantees each tool finds a real, reportable result (Phase 15 Success Criteria #2).
- **D-03:** This repo's own Gitleaks pre-push and npm-audit pre-commit hooks will reject this content by default — scope a `.gitleaksignore` entry / hook `exclude:` pattern to the `fixtures/` path specifically (not a blanket bypass) so the repo's own protection stays intact elsewhere.

#### Report-only conversion
- **D-04:** Each scan job keeps the tool's native fail/exit-code behavior (Semgrep `--error`, Checkov `soft_fail: false`, Grype/Trivy `--fail-on`/`exit-code`), but the step invoking the tool is marked `continue-on-error: true`. The step (and job) shows the finding in logs but the overall PR check still passes. Do not flip tool flags to soft-fail/non-blocking natively — keep native severity semantics intact for when gate mode (Phase 18) turns blocking back on.

#### SCA tool choice
- **D-05:** SCA-04's "generic Trivy/Grype filesystem scan" is satisfied with Trivy only: `trivy fs .`. Single tool, single SARIF+JSON output for the generic sweep. Grype is not used in this phase — reserved as a future option, not run redundantly alongside Trivy.

#### Container job trigger
- **D-06:** No conditional "check for Dockerfile, skip if absent" logic. The container job always builds and scans `fixtures/Dockerfile` (see D-01/D-02 — deliberately old base image with known CVEs). Satisfies Success Criteria #2 (real result, not skipped/stubbed) unconditionally, with no branch logic to get wrong.

### Claude's Discretion
- Exact fixture file contents (which specific old npm package/version, which Terraform provider/version, which Docker base image tag) — pick something clearly vulnerable and well-documented (e.g. an old `lodash`/`handlebars` version, an old `alpine`/`node` tag) during planning/research.
- Exact `.gitleaksignore` / pre-commit `exclude:` regex syntax for scoping the fixtures exemption.
- Job/step naming and ordering within `security.yml` beyond what's already implied by the reference workflow.

### Deferred Ideas (OUT OF SCOPE)
- Per-ecosystem SCA coverage (npm-audit, pip-audit, Terraform pin checks) — explicitly Phase 16 (SCA-01/02/03).
- SARIF upload to GitHub Security tab and JSON artifact retention with explicit retention periods — explicitly Phase 17 (CICD-02/03). Phase 15 jobs still write the files, per Success Criteria #4, but upload/retention polish is deferred.
- Configurable gate mode (block vs report-only via flag/input) and branch protection guidance — explicitly Phase 18 (CICD-06/CICD-04). Phase 15 hardcodes report-only via D-04; making it a flag is Phase 18's job.
- Grype as a second SCA tool alongside Trivy — deferred, not ruled out, per D-05.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CICD-01 | GitHub Actions security workflow runs 5 parallel scan jobs (SAST, IaC, SCA, container, secrets) on every PR | §Architecture Patterns (five sibling jobs, no `needs:`), §Verified check-run naming (`security / <job name>`), §Code Examples (full workflow shape), §Pitfall 8 (parallelism is default; `needs:` breaks it) |
| SCA-04 | SCA job runs a generic Trivy/Grype filesystem scan as a catch-all for ecosystems not covered above | §Standard Stack (Trivy 0.74.0), §Code Examples SCA job (`trivy fs . --scanners vuln`), §Verified: `trivy fs` reads `package-lock.json` with no sibling `package.json` and reports 9 npm vulns |
</phase_requirements>

---

## Summary

This phase converts a one-job placeholder `workflow_call` workflow into five concurrent, report-only scan jobs in `repos/security-platform/.github/workflows/security.yml`. The reference implementation at `repos/security-platform/cicd/.github/workflows/security.yml` is a good structural template, but **five of its specific commands are stale or wrong against current tool versions** and must not be copied verbatim. Every tool in scope (Semgrep 1.155/1.177, Checkov 3.2.396, Trivy 0.74.0, Gitleaks 8.30.1, hadolint 2.15.1, actionlint 1.7.12, Docker 28.3.2) is installed on this workstation, so the whole job matrix can be smoke-tested locally before the PR round-trip.

Three of the six locked CONTEXT decisions rest on assumptions that empirical testing falsified. Most importantly, **D-02's "old base image with known CVEs" produces zero container findings**: an EOL distro (alpine:3.14) has no advisory feed, so Trivy reports 0 vulnerabilities and warns that detection is insufficient. The correct fixture criterion is a *currently supported* distro carrying unpatched CVEs — `debian:12-slim` yields 222 findings (4 CRITICAL, 52 HIGH) today. Likewise, D-02's "unpinned/old Terraform provider" yields zero Checkov findings on its own; the IaC job's findings must come from misconfigured *resources*. And D-03's Gitleaks exemption is both unnecessary (no secret is being seeded) and mechanically wrong (`.gitleaksignore` accepts fingerprints, not path globs).

The good news is that two of the five jobs need no fixture at all: Semgrep finds 2 real issues in the repo as-is, and `gitleaks git .` finds 9 real findings in the repo's own history (Phase-05 AKIA test strings). Fixtures are required only for IaC, container, and SCA.

**Primary recommendation:** Build the five jobs as sibling jobs with no `needs:` edges; install Trivy via `aquasecurity/setup-trivy` and drive it with raw CLI commands (every flag combination below was verified locally); use `--config p/default --metrics=off` for Semgrep (not `--config auto`, which is a hard error with metrics off); use `gitleaks git` over a `fetch-depth: 0` checkout; put `continue-on-error: true` on the scanning step only; and add `exclude: ^fixtures/` to four pre-commit hooks (hadolint, npm-audit, terraform_fmt, terraform_validate) — not to Gitleaks.

---

## Corrections to CONTEXT.md

> These are pivot signals for the planner, not nitpicks. Each contradicts a locked decision or its stated rationale, and each is backed by a command run in this session.

### C-1 — D-02: "old base image with known CVEs" produces ZERO container findings

`FROM alpine:3.14` builds and scans clean:

```
INFO  Detected OS  family="alpine" version="3.14.10"
WARN  This OS version is no longer supported by the distribution
WARN  The vulnerability detection may be insufficient because security updates are not provided
gsd-fixture:test (alpine 3.14.10)  alpine  0 vulnerabilities
```

`[VERIFIED: local docker build + trivy image 0.74.0]`

EOL distributions have no advisory feed, so "older" is exactly backwards. The correct criterion is **a currently supported distro with unpatched CVEs**. Measured today:

| Base image | Total | CRITICAL | HIGH | Verdict |
|------------|-------|----------|------|---------|
| `alpine:3.14` (EOL) | **0** | 0 | 0 | Unusable — violates Success Criteria #2 |
| `alpine:3.19` | 10 | 0 | 2 | Thin |
| `debian:12-slim` | **222** | 4 | 52 | **Recommended** |
| `node:18-bookworm-slim` | 312 | 7 | 83 | Also fine, larger pull |
| `python:3.9-slim` | 405 | 6 | 106 | Also fine |

`[VERIFIED: trivy image --scanners vuln, all five images, 2026-09-10]`

**Planner action:** replace "old base image" with `public.ecr.aws/docker/library/debian:12-slim` pinned by digest (see §Code Examples). This reinterprets D-02's wording while preserving its intent (guaranteed real findings). Flag it in discuss-phase if D-02's literal wording is considered binding.

### C-2 — D-02: "unpinned/old Terraform provider" produces ZERO Checkov findings

Checkov against the target repo as it stands today:

```
gitlab_ci       passed 22   failed 0
github_actions  passed 144  failed 0
azure_pipelines passed 5    failed 0
checkov exit=0
```

`[VERIFIED: checkov 3.2.396 -d repos/security-platform]`

A `required_providers` block with an old version pin is invisible to Checkov — provider/module pinning is Phase 16's SCA-03, enforced by a different check entirely. The 10 terraform failures in the tested fixture came from **resources**: `aws_s3_bucket` with no encryption/versioning/logging (CKV_AWS_18/19/21/145...) and `aws_security_group` with `0.0.0.0/0` on port 22 (CKV_AWS_24).

**Planner action:** keep the old provider pin (it satisfies D-02 literally and seeds Phase 16's SCA-03), but the fixture `.tf` **must also contain misconfigured resources** or the IaC job reports nothing.

### C-3 — D-03: the Gitleaks exemption is unnecessary AND its mechanism is wrong

Two separate problems:

1. **Unnecessary.** D-01/D-02 seed a Dockerfile, a lockfile, and a `.tf` — none contain a secret. The pre-push Gitleaks hook scans the diff and will not fire. Verified: `gitleaks dir repos/security-platform` → `no leaks found`, exit 0. `[VERIFIED: gitleaks 8.30.1]`
2. **Wrong mechanism.** `.gitleaksignore` accepts *fingerprints only* — 3-part `file:rule-id:start-line` or 4-part `commit:file:rule-id:start-line`. Anything else logs `Invalid .gitleaksignore entry` and is ignored. Path-glob exclusion requires a `.gitleaks.toml` with an `[allowlist] paths = [...]` block — which, being repo-root config, would also blind the **CI** secrets job, not just the hook. `[VERIFIED: Context7 /gitleaks/gitleaks, detect/detect.go AddGitleaksIgnore + AddFinding]`

**Planner action:** make no Gitleaks config change this phase. Document the fingerprint-vs-path distinction so Phase 18 (gate mode) doesn't rediscover it.

### C-4 — The hooks that actually block fixtures are hadolint, npm-audit, and the two terraform hooks

| Hook | Fires on fixture? | Evidence |
|------|-------------------|----------|
| `hadolint` (`types: [dockerfile]`) | **YES — exit 1** | `Dockerfile:2 DL3018 warning: Pin versions in apk add` `[VERIFIED: hadolint 2.15.1]` |
| `npm-audit` (`files: package-lock\.json$`, `pass_filenames: false`) | **YES — exit 1, unconditionally** | Hook runs `npm audit` from repo *root*. With a vulnerable lock: `2 vulnerabilities (1 high, 1 critical)`, exit 1. With no root lockfile at all: `npm error code ENOLOCK`, exit 1. It fails either way. `[VERIFIED: npm 11.7.0]` |
| `terraform_fmt` (`files: \.(tf\|tofu\|tfvars\|...)$`) | YES (matches path) | `[CITED: antonbabenko/pre-commit-terraform .pre-commit-hooks.yaml]` |
| `terraform_validate` (same regex, `require_serial: true`) | YES — runs `terraform init`, needs network + provider download; an old provider constraint may fail or hang | `[CITED: same]` |
| `gitleaks` (pre-push) | **NO** | No secret in fixture content (C-3) |

**Planner action:** add `exclude: ^fixtures/` to exactly those four hooks in `repos/security-platform/.pre-commit-config.yaml`. Leave Gitleaks alone.

### C-5 — The secrets job's "real result" comes from git history, not a fixture

```
gitleaks git  repos/security-platform  ->  9 findings, EXIT 1
gitleaks dir  repos/security-platform  ->  0 findings, EXIT 0
```

`[VERIFIED: gitleaks 8.30.1]`

All 9 are `aws-access-token` / `discord-api-token` hits inside `.planning/` docs from the **Phase 05 secrets-detection verification** — files that no longer exist in the working tree but remain in history (115 commits scanned). Success Criteria #2 is therefore satisfied for the secrets job with zero fixture work, **provided** the job checks out full history and uses `gitleaks git` (not `dir`).

**Open question for the user (see §Open Questions Q1):** these findings are harmless report-only noise now, but Phase 18's gate mode will block on them. A `--baseline-path` or fingerprint `.gitleaksignore` will be needed then.

### C-6 — STATE.md is stale on one point

STATE.md §Blockers says the Phase 14 branch is "unpushed." It was merged: `git log` in `repos/security-platform` shows `51714df Merge pull request #5` and `5c4188a Merge pull request #4`. `main` is current. Non-blocking; correct it when STATE.md is next updated.

---

## Target Repository — Read This First

**The implementation does not land in the repo this RESEARCH.md lives in.**

| | Outer repo (`security_solution`) | Target repo (`repos/security-platform`) |
|---|---|---|
| Path | `/Users/christian/git-repos/OCC-github/development_environment/security_solution` | `.../security_solution/repos/security-platform` |
| Role | Planning + reference docs. `repos/` is gitignored (`.gitignore:1`). | The product. Independent git repo. |
| Remote | (this project) | `https://github.com/OttawaCloudConsulting/security-platform.git` |
| Gets in this phase | `.planning/**` docs only | `.github/workflows/security.yml`, `fixtures/**`, `.pre-commit-config.yaml` |

`[VERIFIED: git rev-parse --show-toplevel + git remote -v]`

Consequences for the planner:

- **`fixtures/` means `repos/security-platform/fixtures/`** — top level of the *target* repo, because that is what CI checks out.
- The verification for CICD-01 is a **live pull request against `OttawaCloudConsulting/security-platform`**. Nothing observable happens in the outer repo.
- Commits to the target repo need their own feature branch there; the outer repo's `feature/phase-15-*` branch is a separate thing.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| PR trigger policy (`on: pull_request`) | Caller workflow (`pr-security.yml`) | — | Phase 14 D-01 split trigger from logic so external repos can supply their own trigger (Phase 20 DIST-*) |
| Scan orchestration (5 parallel jobs) | Callable workflow (`security.yml`) | — | The reusable unit; must remain trigger-agnostic (`on: workflow_call`) |
| Tool execution | Runner (`ubuntu-latest`) | — | Each job is an isolated VM; no shared state between the five |
| Scan targets (real files to scan) | Repo checkout (`fixtures/` + repo sources) | — | CI has no network-mounted target; everything scanned must be in the checkout |
| Machine-readable output | Runner filesystem (`*.json`, `*.sarif`) | — | Phase 15 writes files only. Upload/retention is Phase 17 |
| Findings ingestion (SARIF → Security tab) | **Out of scope — Phase 17** | — | Requires `security-events: write`, which the callable workflow cannot self-grant (see §Pitfall 5) |
| Merge gating | **Out of scope — Phase 18** | — | `continue-on-error` today; branch protection + gate flag later |
| Fixture protection bypass | Local pre-commit hooks | — | Client-side only; CI is unaffected by hook `exclude:` entries |

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Semgrep CE | `1.177.0` (PyPI, published 2026-09-10) `[VERIFIED: pypi.org/pypi/semgrep/json]` | SAST | Free, no account, community rules; already the reference workflow's choice and ADR-aligned |
| Checkov | `3.3.17` (pinned inside checkov-action v12.3123.0) `[VERIFIED: action.yml image ref]` | IaC | 1,000+ built-in policies covering Terraform, Dockerfile, K8s, and GitHub Actions in one pass |
| Trivy | `0.74.0` (released 2026-08-14) `[VERIFIED: gh api repos/aquasecurity/trivy/releases/latest]` | SCA filesystem sweep **and** container image scan | SCA-04 names it; one binary covers both jobs; no per-ecosystem config (verified below) |
| Gitleaks | `8.30.1` (released 2026-03-21) `[VERIFIED: gh api releases/latest]` | Secrets | Same version as the repo's own pre-push hook (`.pre-commit-config.yaml` rev `v8.30.0` — consider bumping for parity) |

### Supporting — GitHub Actions (SHA-pinned per ADR-004)

All SHAs resolved this session via `gh api repos/<r>/git/ref/tags/<tag>` with annotated-tag dereferencing. `[VERIFIED: gh api]`

| Action | Pin | Purpose | Notes |
|--------|-----|---------|-------|
| `actions/checkout` | `@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` | Checkout | **Already pinned in the repo and still the latest release.** Do not change. |
| `aquasecurity/setup-trivy` | `@81e514348e19b6112ce2a7e3ecbafe19c1e1f567  # v0.3.1` | Install Trivy | Composite action. Inputs: `version` (default `latest` — **pin to `v0.74.0`**), `cache` (default `false`), `path`, `token`. |
| `bridgecrewio/checkov-action` | `@a8664e3a0549367977f0cda990a34311835c87c0  # v12.3123.0` | Checkov | **Docker action** (`image: docker://ghcr.io/bridgecrewio/checkov:3.3.17`) — Linux runners only. |
| `actions/upload-artifact` | `@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1` | JSON/SARIF artifacts | Optional this phase (retention is Phase 17). |
| `github/codeql-action/upload-sarif` | — | SARIF → Security tab | **Do NOT add this phase.** Needs `security-events: write`, impossible here (§Pitfall 5). Phase 17. |

Note: `bridgecrewio/checkov-action`'s SHA pin protects the *action*, but the action then pulls `ghcr.io/bridgecrewio/checkov:3.3.17` **by mutable tag**. ADR-004's guarantee stops at the action boundary. Worth a one-line comment in the workflow; not worth solving this phase.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `setup-trivy` + raw CLI | `aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25  # v0.36.0` | **Recommended against.** Its `version` input defaults to `v0.70.0`, not 0.74.0. It has no `convert` mode, so producing JSON+SARIF means two action invocations (`cache: true` mitigates the DB re-pull). Raw CLI matches the exact commands verified locally, one-for-one. |
| Pinned Gitleaks binary | `gitleaks/gitleaks-action` | **Recommended against.** README: `GITLEAKS_LICENSE` is *"required for organizations, not required for user accounts."* `OttawaCloudConsulting` is an org → needs a license key + repo secret. `[VERIFIED: gh api repos/gitleaks/gitleaks-action/readme]` Contradicts the project's zero-cost/no-account premise. |
| Trivy for SCA (D-05) | Grype | Deferred per D-05, correctly. Trivy `fs` already covers npm/pip/Go/Rust/Java in one sweep. |
| `--config p/default` | `--config auto` | `auto` is a **hard error** with `--metrics=off` (§Pitfall 1). Choose `p/default` + metrics off, or `auto` + telemetry to semgrep.dev. |

### Installation (on the runner)

```bash
# SAST
pip install semgrep==1.177.0

# SCA + container (via setup-trivy action, or:)
# aquasecurity/setup-trivy@81e5143... with version: v0.74.0

# Secrets — checksum-verified, NOT curl|sh (see Pitfall 6)
curl -sSfL -o gitleaks.tar.gz \
  https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks.tar.gz" | sha256sum -c -
sudo tar xzf gitleaks.tar.gz -C /usr/local/bin gitleaks
```

`[VERIFIED: gh api releases/tags/v8.30.1 assets + curl of gitleaks_8.30.1_checksums.txt]`

---

## Package Legitimacy Audit

Only one third-party *package* is installed in this phase (`semgrep` from PyPI). GitHub Actions are pinned by commit SHA and are not registry packages; Gitleaks and Trivy are binaries from their projects' own GitHub releases.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `semgrep` | PyPI | 1.177.0 published 2026-09-10; project since 2020 | very high (industry-standard SAST) | github.com/semgrep/semgrep | **[OK]** | Approved |
| `lodash` (fixture dep) | npm | current 4.18.1; fixture pins 4.17.15 | ~50M/wk | github.com/lodash/lodash | n/a (fixture, never installed in CI) | Approved as fixture |
| `minimist` (fixture dep) | npm | current 1.2.8; fixture pins 1.2.0 | very high | github.com/minimistjs/minimist | n/a (fixture, never installed in CI) | Approved as fixture |

`[VERIFIED: slopcheck 0.6.1 `slopcheck install semgrep` → `[OK] semgrep (pypi)`; `npm view lodash version` → 4.18.1; `npm view minimist version` → 1.2.8]`

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

Fixture npm dependencies are declared in `fixtures/package-lock.json` for scanners to read. **They are never installed** in CI (`trivy fs` parses the lockfile statically), so their known vulnerabilities are inert.

---

## Architecture Patterns

### System Architecture Diagram

```
  Developer opens PR on OttawaCloudConsulting/security-platform
                          │
                          ▼
        ┌──────────────────────────────────────┐
        │  pr-security.yml  (on: pull_request) │   ← Phase 14, unchanged
        │  job id: security                    │
        │  uses: ./.github/workflows/security  │
        │  permissions: contents: read         │
        └───────────────┬──────────────────────┘
                        │  workflow_call (permissions may only be DOWNGRADED)
                        ▼
        ┌──────────────────────────────────────┐
        │       security.yml  (workflow_call)  │   ← Phase 15 edits this
        └───────────────┬──────────────────────┘
                        │
     ┌──────────┬───────┴────┬──────────┬──────────────┐
     ▼          ▼            ▼          ▼              ▼      (no `needs:` — all concurrent)
 ┌────────┐ ┌────────┐  ┌────────┐ ┌──────────┐  ┌──────────┐
 │  SAST  │ │  IaC   │  │  SCA   │ │Container │  │ Secrets  │
 │Semgrep │ │Checkov │  │Trivy fs│ │docker    │  │ Gitleaks │
 │        │ │        │  │        │ │build +   │  │ (needs   │
 │        │ │        │  │        │ │trivy img │  │ depth 0) │
 └───┬────┘ └───┬────┘  └───┬────┘ └────┬─────┘  └────┬─────┘
     │          │           │           │             │
     │  each: checkout → install tool → SCAN (continue-on-error: true)
     │                                  → convert/emit SARIF (if: always())
     │                                  → ls -l evidence step (if: always())
     ▼          ▼           ▼           ▼             ▼
 semgrep.*  checkov.*   trivy-fs.*  trivy-image.*  gitleaks.*
 (.json+.sarif on the runner filesystem — nothing consumes them yet, per SC#4)
     │          │           │           │             │
     └──────────┴───────────┴─────┬─────┴─────────────┘
                                  ▼
                 5 green checks:  security / SAST — Semgrep CE
                                  security / IaC — Checkov
                                  security / SCA — Trivy Filesystem
                                  security / Container — Trivy Image
                                  security / Secrets — Gitleaks
                                  → PR remains mergeable (SC#5)

  ══════════ Phase 17 adds → upload-sarif ══════════
  ══════════ Phase 18 adds → gate flag / branch protection ══════════
```

### Recommended Project Structure (in `repos/security-platform/`)

```
.github/
└── workflows/
    ├── security.yml          # MODIFIED — placeholder job → 5 scan jobs
    └── pr-security.yml       # unchanged (Phase 14)
fixtures/
├── README.md                 # NEW — "intentionally vulnerable, do not fix"
├── Dockerfile                # NEW — supported distro w/ unpatched CVEs (C-1)
├── package-lock.json         # NEW — generated, not hand-written
├── package.json              # NEW — source of truth for regenerating the lock
└── main.tf                   # NEW — old provider pin + misconfigured resources (C-2)
.pre-commit-config.yaml       # MODIFIED — exclude: ^fixtures/ on 4 hooks (C-4)
```

### Pattern 1: Five sibling jobs — parallelism is the default

**What:** Jobs with no `needs:` dependency run concurrently. There is no opt-in keyword.
**When to use:** Always here. CICD-01 *requires* concurrency, and the way to break it is to accidentally add `needs:`.
**Capacity:** GitHub Free allows **20 concurrent standard GitHub-hosted jobs**. Five is well inside the limit. `[CITED: docs.github.com/en/actions/reference/limits]`

### Pattern 2: Report-only via step-level `continue-on-error` (D-04)

**What:** The tool keeps its native failing exit code; the *step* is marked `continue-on-error: true`. The step renders with a warning annotation, the job concludes `success`, the check is green, the PR stays mergeable.
**Critical distinction:** put it on the **step**, never the **job**.

| Placement | Step conclusion | Job conclusion | Check shown | Phase 18 impact |
|-----------|-----------------|----------------|-------------|-----------------|
| `steps[*].continue-on-error: true` | failure (annotated) | **success** | green | Flipping the flag later restores blocking cleanly |
| `jobs.<id>.continue-on-error: true` | failure | **failure** (workflow not failed) | **red** | A red check can't be made a required check without confusing UX |

`[CITED: docs.github.com — Workflow syntax, continue-on-error]`

**Follow-up steps must carry `if: always()`** — otherwise a failed (but tolerated) scan step short-circuits SARIF conversion and the evidence step, and Success Criteria #4 fails.

### Pattern 3: One scan → both formats

Running each tool twice (as the reference workflow does for Semgrep and Trivy) doubles runtime, re-pulls databases, and risks JSON/SARIF disagreeing. All three tools support single-invocation dual output:

| Tool | Single-run dual output | Verified |
|------|------------------------|----------|
| Semgrep | `--json-output=x.json --sarif-output=x.sarif` in one `scan` | 1 finding in both files from one run `[VERIFIED: semgrep 1.155.0]` |
| Checkov | `--output json --output sarif --output-file-path console,ckv.json,ckv.sarif` | Both named files written; JSON 10+2 failed checks, SARIF 12 results `[VERIFIED: checkov 3.2.396]` |
| Trivy | `--format json -o x.json`, then `trivy convert --format sarif -o x.sarif x.json` | Converted SARIF: 22 results — **identical** to a direct `--format sarif` run `[VERIFIED: trivy 0.74.0]` |

### Anti-Patterns to Avoid

- **Copying the reference workflow verbatim.** Five of its commands are wrong against current versions: `gitleaks detect` (removed from help), `--config auto` (blocks metrics-off), running Semgrep and Trivy twice, `curl | sh` for Grype (Semgrep itself flags this — see §Pitfall 6), and `if: steps.dockerfile.outputs.exists == 'true'` conditional skipping (D-06 explicitly removes this).
- **`needs:` between scan jobs.** Serializes them; directly violates CICD-01.
- **`upload-sarif` this phase.** Silently fails without `security-events: write`, which cannot be granted here (§Pitfall 5).
- **Hand-writing `package-lock.json`.** Generate it: `npm install --package-lock-only --ignore-scripts`.
- **A blanket `SKIP=` or `--no-verify` for the fixture commit.** D-03's scoping intent is right even though its Gitleaks target was wrong; use per-hook `exclude: ^fixtures/`.
- **Mutable image tags in the fixture Dockerfile.** Pin by digest so the container job's finding count is stable and monotonic.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON → SARIF conversion | A jq/python transform | `trivy convert --format sarif` | Verified byte-equivalent result count (22 = 22) to a native SARIF run; SARIF 2.1.0 schema is large and easy to get subtly wrong |
| "Does a Dockerfile exist" branching | `if [ -f Dockerfile ]` + step `if:` guards | D-06: always build `fixtures/Dockerfile` | The reference's conditional is exactly the "skipped, not real" failure Success Criteria #2 forbids |
| Per-ecosystem SCA dispatch | Detect npm/pip/go, run the right auditor | `trivy fs . --scanners vuln` | SCA-04 says "no per-ecosystem configuration required." Verified: Trivy read `package-lock.json` with **no sibling `package.json`** and reported 9 npm vulns |
| Fixture lockfile | Hand-crafted JSON | `npm install --package-lock-only --ignore-scripts` | npm lockfile v3 has `packages` + `dependencies` dual structure; scanners reject malformed locks silently |
| Binary integrity for Gitleaks | `curl \| sh` | Download + `sha256sum -c` against the published checksums file | The project's own SAST rule (`gha-curl-pipe-shell`) flags the pipe-to-shell pattern in the reference workflow |
| Trivy DB mirror config | `TRIVY_DB_REPOSITORY` overrides | Nothing — defaults are already correct | Trivy 0.74 defaults to `[mirror.gcr.io/aquasec/trivy-db:2, ghcr.io/aquasecurity/trivy-db:2]`, GCR first. The old ghcr.io `TOOMANYREQUESTS` pitfall is largely designed out |

**Key insight:** the reference workflow at `cicd/.github/workflows/security.yml` is a *shape* to follow, not a source to copy. Its structure (job names, SHA-pin comment convention, artifact step placement) is sound; its specific commands are 1–2 tool-major-versions stale.

---

## Common Pitfalls

### Pitfall 1: `semgrep --config auto` cannot be combined with `--metrics=off`

**What goes wrong:** `[ERROR]: Cannot create auto config when metrics are off. Please allow metrics or run with a specific config.` The scan produces nothing.
**Why:** `auto` resolves the ruleset server-side from the semgrep.dev registry, which the metrics channel is part of.
**How to avoid:** use `--config p/default --metrics=off`. Verified working end-to-end: exit 1 with `--error`, both output files written.
**Trade-off to surface:** keeping `--config auto` means pseudonymous telemetry to semgrep.dev on every PR. That is a policy decision for a security-stack reference project — see §Open Questions Q2.
`[VERIFIED: semgrep 1.155.0, both variants run locally]`

### Pitfall 2: `--json` and `--sarif` are mutually exclusive; the `*-output=` flags are not

**What goes wrong:** `[ERROR]: Mutually exclusive options --json/--emacs/--vim/--sarif/...`, exit 2, no files.
**Why:** the bare flags set the *stdout display* format (one only). `--json-output=` / `--sarif-output=` are separate file sinks and compose freely.
**How to avoid:** omit the bare format flags entirely; use only `--json-output=` and `--sarif-output=`.
`[VERIFIED: both the failing and passing invocations run locally]`

### Pitfall 3: EOL base images yield zero container findings

Covered in full at §Corrections C-1. Warning sign: Trivy logs `This OS version is no longer supported by the distribution`.

### Pitfall 4: `gitleaks detect` is gone from the CLI surface

**What goes wrong:** the reference uses `gitleaks detect --source .`. On 8.30.1, `detect` no longer appears in `--help`; available commands are `completion / dir / git / help / stdin / version`.
**Current status:** `detect` still *functions* as an undocumented alias (verified: exit 1, 9 findings) — but it is one release from removal.
**How to avoid:** use `gitleaks git . --report-format sarif --report-path ...`.
**Second trap:** `gitleaks dir` (working tree) finds **0** in this repo while `gitleaks git` (history) finds **9**. Choosing `dir`, or forgetting `fetch-depth: 0` on checkout, silently produces an empty report and fails Success Criteria #2.
`[VERIFIED: Context7 /gitleaks/gitleaks README + local gitleaks 8.30.1]`

### Pitfall 5: A called workflow cannot grant itself `security-events: write`

**What goes wrong:** adding `permissions: security-events: write` to `security.yml` has no effect when invoked from `pr-security.yml` (which grants `contents: read`). `upload-sarif` then fails with a 403 — or worse, succeeds under `continue-on-error` and silently uploads nothing.
**Why:** "The `GITHUB_TOKEN` permissions passed from the caller workflow can be only downgraded (not elevated) by the called workflow." `[CITED: docs.github.com — Reusing workflow configurations]`
**How to avoid:** keep `permissions: contents: read` and do not add `upload-sarif`. Phase 17 must widen `pr-security.yml` first. Success Criteria #4 only requires files on the runner — satisfy it with an `ls -l` evidence step.

### Pitfall 6: `curl | sh` installers

**What goes wrong:** Semgrep's own `p/default` ruleset flags the reference workflow: `yaml.github-actions.security.gha-curl-pipe-shell` at `cicd/.github/workflows/security.yml:103` (the Grype installer). Ironic in a security-stack reference repo, and it will keep showing up in the SAST job's own results.
**How to avoid:** download to a file, verify SHA-256 against the release checksums, then extract. See §Installation.
`[VERIFIED: semgrep scan of repos/security-platform, 2 findings]`

### Pitfall 7: `severity: HIGH,CRITICAL` filters the report file, not just the exit code

**What goes wrong:** the reference's Trivy container step passes `severity: 'HIGH,CRITICAL'`. That filter applies to the JSON/SARIF **output** too — MEDIUM/LOW findings vanish from the artifact that Phase 17 will feed to DefectDojo.
**How to avoid:** for the container job, emit the full-severity report and use `--exit-code 1 --severity HIGH,CRITICAL` semantics deliberately, or split: full report for the file, filtered run for the gate. Given report-only + Phase 17 artifact intent, prefer a **full-severity report file**.
`[CITED: trivy CLI --severity semantics]` `[ASSUMED: that Phase 17/DefectDojo wants full severity — confirm]`

### Pitfall 8: `needs:` silently serializes the matrix

**What goes wrong:** any `needs:` edge (e.g. "let SCA wait for the container build") turns five parallel checks into a chain, failing CICD-01's observable criterion while every job still passes.
**Warning sign:** the PR checks list shows jobs entering `queued` at staggered times. Verify with the check-run command in §Validation Architecture.

### Pitfall 9: `checkov-action` is a Docker action

Docker-container actions run only on Linux runners. `runs-on: ubuntu-latest` is required — fine here, but it means the IaC job can never be moved to macOS/Windows runners without swapping to `pip install checkov`.
`[VERIFIED: action.yml `runs: using: 'docker'`]`

### Pitfall 10: `npm audit` pre-commit hook fails even with no lockfile at root

Covered at §Corrections C-4. The hook's `pass_filenames: false` means it ignores which file matched and always runs `npm audit` from the repo root — producing `ENOLOCK` exit 1 when there is no root lockfile. `exclude: ^fixtures/` is mandatory, not optional.

---

## Code Examples

### The five jobs (verified command shapes)

```yaml
# repos/security-platform/.github/workflows/security.yml
---
# Callable security scanning workflow.
# All third-party actions are pinned to full commit SHAs (ADR-004).
# Report-only (Phase 15): scan steps carry continue-on-error, so findings are
# visible but non-blocking. Gate mode is Phase 18 (CICD-06).

name: Security Scans

on:
  workflow_call: {}

permissions:
  contents: read      # A called workflow may only DOWNGRADE the caller's
                      # permissions. security-events: write requires changing
                      # pr-security.yml first — that is Phase 17 (CICD-02).

jobs:

  sast:
    name: SAST — Semgrep CE
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
      - run: pip install semgrep==1.177.0

      # NOTE: --config auto is a hard error with --metrics=off. p/default is the
      # metrics-free equivalent. --json-output/--sarif-output compose; the bare
      # --json/--sarif display flags do not.
      - name: Run Semgrep
        continue-on-error: true          # D-04: native --error kept, step tolerated
        run: |
          semgrep scan --config p/default --metrics=off --error \
            --json-output=semgrep-results.json \
            --sarif-output=semgrep.sarif .

      - name: Show scan output files
        if: always()
        run: ls -l semgrep-results.json semgrep.sarif

  iac:
    name: IaC — Checkov
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1

      # Docker action; internally pulls ghcr.io/bridgecrewio/checkov:3.3.17 by tag.
      - name: Run Checkov
        uses: bridgecrewio/checkov-action@a8664e3a0549367977f0cda990a34311835c87c0  # v12.3123.0
        continue-on-error: true          # D-04
        with:
          directory: .
          output_format: cli,json,sarif
          output_file_path: console,checkov-results.json,checkov.sarif
          quiet: true
          soft_fail: false               # D-04: native failing behaviour preserved

      - name: Show scan output files
        if: always()
        run: ls -l checkov-results.json checkov.sarif

  sca:
    name: SCA — Trivy Filesystem
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
      - uses: aquasecurity/setup-trivy@81e514348e19b6112ce2a7e3ecbafe19c1e1f567  # v0.3.1
        with:
          version: v0.74.0
          cache: true

      # SCA-04: generic filesystem sweep, no per-ecosystem config.
      # --scanners vuln only: misconfig is the IaC job's remit, secret is Gitleaks'.
      - name: Run Trivy filesystem scan
        continue-on-error: true          # D-04
        run: |
          trivy fs . --scanners vuln \
            --format json --output trivy-fs.json \
            --exit-code 1 --severity HIGH,CRITICAL

      - name: Convert to SARIF
        if: always()
        run: trivy convert --format sarif --output trivy-fs.sarif trivy-fs.json

      - name: Show scan output files
        if: always()
        run: ls -l trivy-fs.json trivy-fs.sarif

  container:
    name: Container — Trivy Image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
      - uses: aquasecurity/setup-trivy@81e514348e19b6112ce2a7e3ecbafe19c1e1f567  # v0.3.1
        with:
          version: v0.74.0
          cache: true

      # D-06: unconditional build. No "does a Dockerfile exist" branching.
      - name: Build fixture image
        run: docker build -f fixtures/Dockerfile -t scan-fixture:${{ github.sha }} fixtures/

      - name: Run Trivy image scan
        continue-on-error: true          # D-04
        run: |
          trivy image scan-fixture:${{ github.sha }} --scanners vuln \
            --format json --output trivy-image.json \
            --exit-code 1 --severity HIGH,CRITICAL

      - name: Convert to SARIF
        if: always()
        run: trivy convert --format sarif --output trivy-image.sarif trivy-image.json

      - name: Show scan output files
        if: always()
        run: ls -l trivy-image.json trivy-image.sarif

  secrets:
    name: Secrets — Gitleaks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
        with:
          fetch-depth: 0   # REQUIRED: `gitleaks git` finds 9 findings in history,
                           # `gitleaks dir` finds 0 in the working tree.

      # Checksum-verified download, not curl|sh (Semgrep flags the pipe pattern).
      - name: Install Gitleaks
        run: |
          curl -sSfL -o gitleaks.tar.gz \
            https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
          echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks.tar.gz" \
            | sha256sum -c -
          sudo tar xzf gitleaks.tar.gz -C /usr/local/bin gitleaks

      # `detect` is deprecated (absent from --help on 8.30.1); `git` is current.
      - name: Run Gitleaks
        continue-on-error: true          # D-04
        run: |
          gitleaks git . --no-banner --redact \
            --report-format sarif --report-path gitleaks.sarif
          gitleaks git . --no-banner --redact \
            --report-format json --report-path gitleaks-results.json

      - name: Show scan output files
        if: always()
        run: ls -l gitleaks-results.json gitleaks.sarif
```

### Fixture: `fixtures/Dockerfile`

```dockerfile
# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"
# Supported distro (advisories still published) carrying unpatched CVEs.
# Measured 2026-09-10: 222 vulnerabilities (4 CRITICAL, 52 HIGH).
# Pinned by digest so the finding count is stable and monotonic non-decreasing.
FROM public.ecr.aws/docker/library/debian:12-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171
CMD ["/bin/sh"]
```

`[VERIFIED: digest via docker buildx imagetools inspect; CVE counts via trivy image --scanners vuln]`

Registry choice: `public.ecr.aws/docker/library/*` mirrors Docker Hub without anonymous pull-rate limits on shared runner IPs. Verified the path resolves for `debian:12-slim`, `node:18-bookworm-slim`, `python:3.9-slim`, and `alpine:3.14`.

### Fixture: `fixtures/main.tf`

```hcl
# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"
# Old provider pin: satisfies D-02 and seeds Phase 16 / SCA-03.
# NOTE: the provider pin alone produces ZERO Checkov findings. The misconfigured
# resources below are what make the IaC job non-empty (see RESEARCH C-2).
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
    }
  }
}

resource "aws_s3_bucket" "fixture" {
  bucket = "scan-fixture-insecure-bucket"
}

resource "aws_security_group" "fixture" {
  name = "scan-fixture-open"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Measured against this exact content: Checkov **10 failed terraform checks** (CKV_AWS_24 open SSH, CKV_AWS_23 missing description, CKV2_AWS_5 unattached SG, plus S3 encryption/versioning/logging) plus **2 failed dockerfile checks** (CKV_DOCKER_2 no HEALTHCHECK, CKV_DOCKER_3 no USER) → 12 SARIF results, exit 1. `[VERIFIED: checkov 3.2.396]`

### Fixture: `fixtures/package.json` + generated lock

```json
{
  "name": "scan-fixture",
  "version": "0.0.0",
  "private": true,
  "description": "INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT FIX OR INSTALL",
  "dependencies": {
    "lodash": "4.17.15",
    "minimist": "1.2.0"
  }
}
```

```bash
# Generate the lock — do not hand-write it
cd fixtures && npm install --package-lock-only --ignore-scripts --no-audit --no-fund
```

Measured: `trivy fs` reports **9 npm vulnerabilities** from this lockfile — including with **no sibling `package.json`**, confirming SCA-04's "no per-ecosystem configuration required." `npm audit --audit-level=high` on it reports `2 vulnerabilities (1 high, 1 critical)` (minimist prototype pollution GHSA-vh95-rmgr-6w4m / GHSA-xvch-5gv4-984h) — the exact behaviour Phase 16's SCA-01 will formalize. `[VERIFIED: trivy 0.74.0, npm 11.7.0]`

### Pre-commit hook exemptions (`repos/security-platform/.pre-commit-config.yaml`)

```yaml
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.105.0
    hooks:
      - id: terraform_fmt
        types: [terraform]
        exclude: ^fixtures/          # ADD
      - id: terraform_validate
        types: [terraform]
        exclude: ^fixtures/          # ADD — also avoids `terraform init` on an old provider

  - repo: https://github.com/hadolint/hadolint
    rev: v2.14.0
    hooks:
      - id: hadolint
        types: [dockerfile]
        exclude: ^fixtures/          # ADD — fixture Dockerfile trips DL3006/DL3007/DL3018

  - repo: local
    hooks:
      - id: npm-audit
        name: npm audit
        entry: npm audit --audit-level=high
        language: system
        files: package-lock\.json$
        exclude: ^fixtures/          # ADD — hook is pass_filenames:false and runs at
        pass_filenames: false        #       repo root; ENOLOCK exit 1 without this

  # Gitleaks: NO CHANGE. No secret is seeded, so the pre-push hook never fires on
  # fixtures. And .gitleaksignore takes fingerprints, not paths — a path allowlist
  # would need .gitleaks.toml, which would also blind the CI secrets job.
```

### Verifying the five parallel checks (CICD-01 acceptance)

```bash
gh api repos/OttawaCloudConsulting/security-platform/commits/<pr-head-sha>/check-runs \
  --jq '.check_runs[] | "\(.name)  ->  \(.conclusion)  started=\(.started_at)"'
```

Expected: five entries named `security / <job name>`, all `success`, with `started_at` values clustered within seconds of each other (proving concurrency, not a chain).

The `security / <name>` format is verified, not assumed — PR #5's head commit produced exactly:

```
security / Placeholder  ->  success
```

i.e. `<caller job id>` + ` / ` + `<called job name>`. `[VERIFIED: gh api repos/.../commits/f83e950/check-runs]`

---

## State of the Art

| Old approach (in the reference workflow) | Current approach | When changed | Impact |
|------------------------------------------|------------------|--------------|--------|
| `gitleaks detect --source .` | `gitleaks git .` / `gitleaks dir .` | Gitleaks v8.19+ command split; absent from `--help` on 8.30.1 | Still works as an alias, but undocumented and removable |
| Two Semgrep runs (JSON then SARIF) | One run: `--json-output= --sarif-output=` | Semgrep 1.x output-flag redesign | ~50% SAST runtime cut; guaranteed consistent files |
| Two Trivy action invocations (JSON then SARIF) | One `--format json` run + `trivy convert` | `trivy convert` subcommand | One DB pull; verified byte-equivalent result count |
| `TRIVY_DB_REPOSITORY` workarounds for ghcr.io `TOOMANYREQUESTS` | Nothing — defaults handle it | Trivy default became `[mirror.gcr.io/aquasec/trivy-db:2, ghcr.io/aquasecurity/trivy-db:2]` | Pitfall largely designed out; do not add the override |
| `actions/checkout@34e1148…  # v4`, `upload-artifact  # v4`, `trivy-action  # v0.35.0` | checkout v7.0.1, upload-artifact v7.0.1, trivy-action v0.36.0 / setup-trivy v0.3.1 | 2026 releases | The reference's SHAs are 3 majors stale — resolve fresh, do not copy |
| `if: steps.dockerfile.outputs.exists == 'true'` conditional container job | Unconditional build of `fixtures/Dockerfile` | D-06 | Removes the "skipped, not stubbed" ambiguity |

**Deprecated/outdated:**
- `gitleaks detect` — use `git` or `dir`.
- `semgrep --enable-metrics` / `--disable-metrics` — removed Aug 2023; use `--metrics=on|off|auto`. `[CITED: semgrep-docs release-notes/august-2023]`
- `gitleaks/gitleaks-action` for organization repos without a `GITLEAKS_LICENSE` secret.

---

## Project Constraints (from CLAUDE.md and `.claude/rules/`)

| Constraint | Source | Implication for this phase |
|------------|--------|----------------------------|
| Preserve ASCII architecture diagrams and the 4-phase layered structure | `CLAUDE.md` | If `development-security-stack-option-1.md` is touched, preserve its diagrams. This phase should not need to. |
| `docs/adr/` is **append-only** — never modify accepted ADRs | `CLAUDE.md` | The SHA-pin convention comes from ADR-004; follow it, don't edit it. New decisions → new ADR file. |
| **Never set the executable bit on scripts**; always invoke with an explicit interpreter (`bash script.sh`, not `./script.sh`) | `defensive-protocol-v2-anti-slop.md` | Any helper script for fixture generation must be run as `bash scripts/x.sh`. No `chmod +x`. |
| No silent fallbacks (`or {}`, `try/except: pass`) — let it crash | same | `continue-on-error` is a *deliberate, documented* tolerance required by D-04, not a silent fallback. The `ls -l` evidence step keeps the failure visible. |
| Failure response: STOP → REPORT → WAIT (no silent retry) | same | If a scan job fails for an infrastructure reason (not a finding), stop and report rather than re-running. |
| Second-order effects: list what depends on a change before making it | `defensive-protocol-v2-epistemology.md` | Editing `.pre-commit-config.yaml` affects every future commit in the target repo. Scope excludes to `^fixtures/`. |
| Chesterton's Fence | same | The reference workflow's `soft_fail: false` / `--error` flags exist to make findings blocking. D-04 keeps them and tolerates at the step — do not delete them. |
| Verification cadence: verify every 3–5 actions | `defensive-protocol-v2-anti-slop.md` | Run the local smoke commands (§Validation Architecture) after each fixture file lands, before opening the PR. |
| Use Context7 for library/CLI docs over web search | `~/.claude/rules/context7.md` | Applied: Trivy, Gitleaks, and Semgrep docs were fetched via Context7 for this research. |

---

## Runtime State Inventory

> This is a greenfield CI-wiring phase, not a rename/refactor/migration. Section retained only because the phase touches a live GitHub repository with server-side state.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no databases involved. | None |
| Live service config | GitHub repo settings on `OttawaCloudConsulting/security-platform`: (a) branch protection — **none required this phase**, checks stay non-required (Phase 18 / CICD-04); (b) a `GitGuardian Security Checks` app is installed and posts a check on PRs — unrelated to the five jobs, but it will appear alongside them in the checks list; (c) Dependabot **alerts**/dependency-graph may be enabled and would flag `fixtures/package-lock.json`. `[VERIFIED: gh api check-runs on f83e950]` | Verify Dependabot alerts behaviour after the fixture lands; see Q3 |
| OS-registered state | None. | None |
| Secrets/env vars | None needed. Explicitly **not** needed: `GITLEAKS_LICENSE` (avoided by using the pinned binary rather than gitleaks-action), Semgrep app token (CE + `p/default` needs none). | None |
| Build artifacts | Local pre-commit hook environments cached in `.pre-commit-cache/` (gitignored) — will re-resolve after the config edit. Harmless. | None |
| Dependabot config | `repos/security-platform/.github/dependabot.yml` declares **only** `package-ecosystem: github-actions`. Adding `fixtures/package-lock.json` will **not** trigger Dependabot version-update PRs against the fixture. `[VERIFIED: cat dependabot.yml]` | None — but do not add an `npm` ecosystem entry in future phases without excluding `/fixtures` |

---

## Environment Availability

Every tool needed to smoke-test all five jobs locally is installed.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `docker` | Container job local smoke; fixture image build | ✓ | 28.3.2 | — |
| `trivy` | SCA + container job smoke | ✓ | 0.74.0 (matches recommended CI pin) | — |
| `checkov` | IaC job smoke | ✓ | 3.2.396 (CI uses 3.3.17 via action) | — |
| `semgrep` | SAST job smoke | ✓ | 1.155.0 (CI pins 1.177.0) | — |
| `gitleaks` | Secrets job smoke | ✓ | 8.30.1 (matches recommended CI pin) | — |
| `actionlint` | Workflow lint (Wave 0) | ✓ | 1.7.12 | — |
| `yamllint` | Workflow lint (pre-commit) | ✓ | 1.37.1 | — |
| `hadolint` | Confirming the fixture Dockerfile trips the hook | ✓ | 2.15.1 | — |
| `terraform` | `terraform fmt` on the fixture `.tf` | ✓ | 1.15.6 | — |
| `npm` | Generating `fixtures/package-lock.json` | ✓ | 11.7.0 | — |
| `pre-commit` | Verifying the `exclude:` edits work | ✓ | 4.5.1 | — |
| `gh` | PR creation + check-run verification | ✓ | 2.100.0, authenticated as `OttawaCloudConsulting` | — |
| `grype` | Not used (D-05) | ✓ (0.117.0) | — | n/a |
| Network: `public.ecr.aws` | Fixture base image | ✓ | digest resolved | Docker Hub (rate-limited) |
| Network: GitHub Actions minutes | Live PR verification | ✓ | Free plan, 20 concurrent jobs | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none.

---

## Validation Architecture

### Test Framework

This is a CI-workflow phase; there is no unit-test framework in the target repo. Validation is (a) static lint of the workflow YAML, (b) local execution of the exact scanner commands, (c) the live PR's check-runs.

| Property | Value |
|----------|-------|
| Framework | `actionlint` 1.7.12 (workflow static analysis) + direct CLI smoke runs |
| Config file | none — `actionlint` needs none; `.pre-commit-config.yaml` covers yamllint |
| Quick run command | `actionlint repos/security-platform/.github/workflows/*.yml` |
| Full suite command | `bash` the smoke block below, then `gh api .../check-runs` on the live PR |

Baseline confirmed: `actionlint` exits 0 on the current workflows; `yamllint -d relaxed` emits one line-length warning (81 > 80) and exits 0 (relaxed treats it as a warning). `[VERIFIED: run locally]`

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Exists? |
|--------|----------|-----------|-------------------|---------|
| CICD-01 | Workflow YAML is valid and defines 5 jobs with no `needs:` | static | `actionlint repos/security-platform/.github/workflows/security.yml && python3 -c "import yaml,sys; w=yaml.safe_load(open('repos/security-platform/.github/workflows/security.yml')); assert len(w['jobs'])==5; assert all('needs' not in j for j in w['jobs'].values())"` | ❌ Wave 0 |
| CICD-01 | Five checks appear concurrently on the PR | integration (live) | `gh api repos/OttawaCloudConsulting/security-platform/commits/$SHA/check-runs --jq '[.check_runs[]|select(.name|startswith("security / "))]|length'` → `5` | ❌ Wave 0 |
| CICD-01 / SC#5 | PR remains mergeable despite findings | integration (live) | `gh pr view <n> --json mergeable,statusCheckRollup` → `MERGEABLE`, all `SUCCESS` | ❌ Wave 0 |
| CICD-01 / SC#2 | Each tool produces a real, non-empty result | smoke (local) | see block below — each asserts exit 1 and a non-empty report | ❌ Wave 0 |
| CICD-01 / SC#4 | Each job writes SARIF and/or JSON | smoke (local) + log inspection | `test -s <file>` locally; `ls -l` evidence step in each job | ❌ Wave 0 |
| SCA-04 | Generic Trivy filesystem scan finds packages with no per-ecosystem config | smoke (local) | `trivy fs fixtures --scanners vuln --format json -o /tmp/t.json; python3 -c "import json;d=json.load(open('/tmp/t.json'));assert any(r.get('Vulnerabilities') for r in d['Results'])"` | ❌ Wave 0 |

### Local smoke block (Wave 0 deliverable — expected results measured this session)

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

### Sampling Rate

- **Per task commit:** `actionlint` on the workflow + the smoke command for whichever job that task touched.
- **Per wave merge:** the full local smoke block above.
- **Phase gate:** a live PR on `OttawaCloudConsulting/security-platform` showing five `security / *` checks, all green, with `gh pr view --json mergeable` reporting `MERGEABLE`.

### Wave 0 Gaps

- [ ] `fixtures/README.md`, `fixtures/Dockerfile`, `fixtures/package.json`, `fixtures/package-lock.json`, `fixtures/main.tf` — the scan targets themselves (covers SC#2 for IaC/container/SCA)
- [ ] `.pre-commit-config.yaml` `exclude: ^fixtures/` on 4 hooks — without this the fixture commit cannot land (covers C-4)
- [ ] A local smoke script (invoked as `bash scripts/smoke-scans.sh`, **no executable bit** per project rules) wrapping the block above
- [ ] No test framework install needed — `actionlint` and all five scanners are already present

---

## Security Domain

### Applicable ASVS Categories

This phase builds security tooling rather than an application, so most ASVS categories are N/A. The relevant threat surface is the CI supply chain itself.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture | yes | Least-privilege workflow `permissions: contents: read`; called workflow cannot escalate |
| V2 Authentication | no | No auth code. Notably, no tokens/secrets are required at all (gitleaks-action's license key is deliberately avoided) |
| V3 Session Management | no | — |
| V4 Access Control | partial | `GITHUB_TOKEN` scoped to `contents: read`; no write permissions anywhere in the phase |
| V5 Input Validation | no | No user input processed |
| V6 Cryptography | yes | SHA-256 verification of the Gitleaks binary; SHA-pinned actions; digest-pinned base image. Nothing hand-rolled |
| V10 Malicious Code | yes | ADR-004 SHA pinning of all third-party actions; `--ignore-scripts` when generating the fixture lockfile |
| V14 Configuration | yes | The workflow *is* the configuration; `actionlint` + `yamllint` validate it |

### Known Threat Patterns for GitHub Actions CI

| Pattern | STRIDE | Standard Mitigation | Status this phase |
|---------|--------|---------------------|-------------------|
| Mutable action tag hijack (`@v4` retargeted) | Tampering / Elevation | Full commit SHA pins (ADR-004) + Dependabot (CICD-05) | Applied to all four actions |
| `curl \| sh` installer compromise | Tampering | Download + checksum verify | Applied to Gitleaks; Semgrep flags the reference's Grype installer as `gha-curl-pipe-shell` |
| Transitive image-tag drift inside a pinned action | Tampering | Nothing available — `checkov-action` pulls `checkov:3.3.17` by tag | **Documented, not mitigated.** Accepted residual risk |
| Malicious npm postinstall during fixture install | Elevation | Fixture deps are **never installed** in CI; local lock generation uses `--ignore-scripts` | Applied |
| Excessive `GITHUB_TOKEN` scope | Elevation | Least privilege at workflow level | `contents: read` only |
| Untrusted-input script injection (`${{ github.event.* }}` in `run:`) | Injection | Never interpolate PR-controlled fields into shell | Only `${{ github.sha }}` is interpolated — not attacker-controlled |
| Fixture vulnerabilities mistaken for real exposure | Repudiation / noise | `fixtures/README.md` stating intent; findings are report-only | Recommended |
| Scan results silently absent (empty report treated as "clean") | Repudiation | `ls -l` evidence step + local smoke asserting non-empty reports and exit 1 | Applied — this is the direct defense for SC#2 |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `debian:12-slim` will continue to carry ≥1 HIGH/CRITICAL unpatched CVE over the life of this fixture | C-1, Code Examples | Container job could report zero and fail SC#2. **Mitigated** by digest pinning — a pinned digest's finding count is monotonic non-decreasing as new CVEs are published |
| A2 | Trivy 0.70.0 (trivy-action's default) also defaults to the GCR-first DB mirror | Standard Stack / Alternatives | Only matters if the planner chooses trivy-action over setup-trivy; the recommendation pins 0.74.0 where this **is** verified |
| A3 | Phase 17 / DefectDojo will want full-severity reports rather than HIGH/CRITICAL-filtered ones | Pitfall 7 | Filtered artifacts would need regenerating in Phase 17. Cheap to fix; flagged so the choice is deliberate |
| A4 | The 9 Gitleaks history findings are fake Phase-05 test strings, not live credentials | C-5, Q1 | If any is a real key, this is an active incident, not CI noise. Strong indirect evidence they are fake (they sit in `05-VERIFICATION.md` / `05-02-SUMMARY.md` from a secrets-detection *test*, and GitGuardian's check on PR #5 passed) — **but not directly confirmed with the user** |
| A5 | `ubuntu-latest` runners have Docker available for the container job's `docker build` | Code Examples | Standard on GitHub-hosted Ubuntu runners; would fail loudly and immediately if not |
| A6 | Checkov 3.3.17 (CI, via action) has the same `--output-file-path` comma semantics as 3.2.396 (verified locally) | Pattern 3, C-corrections | Files land under different names; the `ls -l` evidence step catches this on the first PR run |

Everything else in this document is `[VERIFIED]` by a command run in this session or `[CITED]` to official documentation.

---

## Open Questions

1. **The 9 Gitleaks findings in the target repo's git history — accept as noise, or baseline them?**
   - What we know: `gitleaks git .` reports 9 findings (8 `aws-access-token`, 1 `discord-api-token`) in `.planning/` files from Phase 05's secrets-detection verification. The files no longer exist in the working tree. Report-only means they don't block anything this phase, and they satisfy SC#2.
   - What's unclear: whether they are confirmed-fake test fixtures (very likely — see A4), and whether the user wants them suppressed now or when Phase 18 turns on gating.
   - Recommendation: **accept them this phase** (they are the secrets job's proof of a real result). Log for Phase 18 that a `--baseline-path` or fingerprint-based `.gitleaksignore` will be needed before gate mode. Ask the user to confirm the strings are fake.

2. **Semgrep `--config auto` (telemetry to semgrep.dev) vs `--config p/default --metrics=off`?**
   - What we know: `auto` + `metrics=off` is a hard error. `auto` sends pseudonymous usage metrics on every scan. `p/default` is a fixed registry ruleset that works with metrics disabled.
   - What's unclear: whether the reference blueprint's "no account required" stance also implies "no telemetry," and whether `p/default`'s narrower rule set materially reduces coverage versus `auto`'s language auto-detection.
   - Recommendation: **`p/default --metrics=off`** — it is verified working and telemetry-free, appropriate for a security-stack reference. Surface the coverage trade-off to the user; if `auto` is preferred, document the telemetry explicitly in the blueprint.

3. **Will GitHub Dependabot *alerts* fire on `fixtures/package-lock.json`?**
   - What we know: `dependabot.yml` declares only the `github-actions` ecosystem, so no version-update PRs will target the fixture. But Dependabot **alerts** are a separate repo-level setting driven by the dependency graph.
   - What's unclear: whether alerts are enabled on `OttawaCloudConsulting/security-platform`.
   - Recommendation: add `fixtures/README.md` documenting intent; check `gh api repos/OttawaCloudConsulting/security-platform/vulnerability-alerts` after the fixture merges. If noisy, `fixtures/` can be excluded via `.github/dependabot.yml` `ignore` rules in a later phase.

4. **`fixtures/` at the target-repo root, or nested under an existing directory?**
   - What we know: D-01 says "top-level," and top-level maximizes the chance every scanner finds it with default `.`-rooted invocations (verified: Trivy, Checkov, and Semgrep all traverse from `.`).
   - What's unclear: whether a `fixtures/` directory at the root of a repo that will later be *distributed* as a reusable workflow (Phase 20, DIST-*) is confusing to consumers.
   - Recommendation: **top-level as decided**, with a clear README. Revisit at Phase 20 if distribution packaging changes the layout.

---

## Sources

### Primary (HIGH confidence — verified by execution or authoritative API in this session)

- **Local tool execution** — semgrep 1.155.0, checkov 3.2.396, trivy 0.74.0, gitleaks 8.30.1, hadolint 2.15.1, npm 11.7.0, terraform 1.15.6, docker 28.3.2, actionlint 1.7.12, yamllint 1.37.1, slopcheck 0.6.1. Every command in §Code Examples and §Validation Architecture was run.
- **`gh api`** — release tags, annotated-tag SHA dereferencing, `action.yml` contents for checkov-action / trivy-action / setup-trivy, gitleaks-action README, gitleaks release assets + checksums, and `commits/f83e950/check-runs` (source of the verified `security / <name>` check-name format).
- **Context7 `/aquasecurity/trivy`** — `trivy convert` usage; `pkg/db/db.go` default DB repository ordering (`mirror.gcr.io` first, `ghcr.io` fallback).
- **Context7 `/gitleaks/gitleaks`** — CLI command surface (`git`/`dir`/`stdin`); `detect/detect.go` `AddGitleaksIgnore` + `AddFinding` (fingerprint-only ignore semantics).
- **Context7 `/semgrep/semgrep-docs`** — `--error` exit codes, `--sarif-output`/`--json-output`, `--metrics` flag history, registry-ruleset metrics behaviour.
- **Repository inspection** — `repos/security-platform/{.github/workflows/*,.pre-commit-config.yaml,.gitleaksignore,.gitignore,.github/dependabot.yml}`, `cicd/.github/workflows/security.yml`, `git log`, `git remote -v`.

### Secondary (MEDIUM confidence — official docs via search/fetch)

- [GitHub Docs — Actions limits](https://docs.github.com/en/actions/reference/limits) — 20 concurrent jobs on Free; 6h job limit.
- [GitHub Docs — Reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations) — permissions may only be downgraded by a called workflow.
- [GitHub Docs — Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions) — step-level vs job-level `continue-on-error`.
- [antonbabenko/pre-commit-terraform `.pre-commit-hooks.yaml`](https://raw.githubusercontent.com/antonbabenko/pre-commit-terraform/master/.pre-commit-hooks.yaml) — `terraform_fmt` / `terraform_validate` file regexes.
- [PyPI semgrep JSON API](https://pypi.org/pypi/semgrep/json) — 1.177.0, published 2026-09-10.

### Tertiary (LOW confidence — flagged for validation)

- None. Every claim in this document traces to a primary or secondary source above, or is listed in §Assumptions Log.

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| Standard stack + versions | **HIGH** | Every version and SHA resolved via `gh api` / PyPI in this session; every tool run locally |
| Architecture (5 parallel jobs, report-only, workflow_call) | **HIGH** | Check-name format verified against a real check-run on this repo; permissions rule cited to official docs; `continue-on-error` semantics cited |
| Tool commands + flags | **HIGH** | Each command executed locally with its exit code and output file recorded — including the failing variants (`--config auto --metrics=off`, `--json --sarif`) |
| Fixture design | **HIGH** | CVE counts measured across five candidate base images; Checkov finding counts measured with and without fixtures; lockfile behaviour measured with and without `package.json` |
| Pre-commit hook impact | **HIGH** | hadolint and npm-audit exit codes reproduced locally; terraform hook regexes read from the upstream hooks manifest |
| Live PR behaviour (concurrency timing, five green checks) | **MEDIUM** | Naming and mergeability inferred from PR #5's single-job precedent; the five-job case is only observable once the PR exists. This is the phase gate, by design |

**Research date:** 2026-09-10
**Valid until:** 2026-10-10 (30 days). Re-verify sooner if: Trivy or Gitleaks cuts a minor release; `checkov-action` bumps its pinned checkov image; or the `debian:12-slim` digest is intentionally refreshed.
