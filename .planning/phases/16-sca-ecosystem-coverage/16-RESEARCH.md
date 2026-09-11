# Phase 16: SCA Ecosystem Coverage - Research

**Researched:** 2026-09-10
**Domain:** Per-ecosystem software composition analysis (npm, Python, Terraform pinning) inside an existing GitHub Actions `workflow_call` scanning workflow
**Confidence:** HIGH (every tool claim below was measured locally against the real `repos/security-platform` fixtures or a purpose-built reproduction, not recalled)

## Summary

Phase 15 landed a single `sca` job running `trivy fs . --scanners vuln` — SCA-04's zero-config catch-all. Phase 16 adds three ecosystem-specific sub-scans to that **same job**: `npm audit` (SCA-01), `pip-audit` (SCA-02), and `tflint` (SCA-03). All three tools were run locally during this research; the exit codes, output shapes, skip behaviour, and fixture gaps below are measured facts, not documentation claims.

Three findings dominate the plan. **First, the existing Terraform fixture cannot satisfy Success Criterion 3.** `fixtures/main.tf` pins `hashicorp/aws` to the exact version `3.74.0`, which is precisely what a pinning check wants — tflint reports only `terraform_required_version` against it, never a pinning finding. The fixture needs a provider with a missing/floating constraint and an unpinned module before SCA-03 can be demonstrated. **Second, both `npm audit` and `pip-audit` return exit code 1 for "vulnerabilities found" AND for "input file missing/invalid"** — the two cases are indistinguishable by exit code alone. This is the exact failure mode Success Criterion 4 names ("no failure, no false pass"), so every sub-scan must be guarded by an explicit file-detection step, and verification must assert on report *content*, not exit status. **Third, tflint exits 2 on findings, not 1** — `scripts/smoke-scans.sh`'s `run_scan()` helper treats only rc=1 as PASS and would score every tflint finding as a tool error.

The generic Trivy sweep already parses both `package-lock.json` (9 npm vulns measured) and `requirements.txt` (11 pip vulns measured). The roadmap's split of SCA-04 from SCA-01/02/03 is a settled decision and is not reopened here; what the native tools add is a *different advisory source* (GitHub Advisory DB for npm, PyPI/OSV PYSEC for Python), native severity gating semantics, transitive resolution for unpinned Python requirements, and — for SCA-03 — a capability neither Trivy nor Checkov has at all (provider version-constraint checking).

**Primary recommendation:** Add three guarded sub-scan step-pairs (detect → run) to the existing `sca` job using preinstalled `npm`, `pip install pip-audit==2.10.1`, and a checksum-verified tflint v0.64.0 binary; extend `scripts/smoke-scans.sh` with an expected-rc parameter and a negative (empty-directory) skip test; and add a floating-constraint Terraform block plus `fixtures/requirements.txt` before writing any workflow YAML.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| npm dependency vulnerability audit (SCA-01) | CI job step (`sca` job in `security.yml`) | Pre-commit hook (already exists, `npm-audit` local hook) | Requires network access to the npm registry advisory endpoint and the repo checkout; belongs in CI, with the existing pre-commit hook as the fast local pre-check |
| Python dependency advisory audit (SCA-02) | CI job step (`sca` job) | — | No existing pre-commit equivalent; `pip-audit` needs network + the checkout |
| Terraform provider/module pin checking (SCA-03) | CI job step (`sca` job) | IaC job (Checkov CKV_TF_1/2 covers *modules* only) | Provider constraint checking exists in no other tool in the stack; module pinning partially overlaps with the existing Checkov IaC job |
| Ecosystem detection / clean skip (Criterion 4) | CI job step (bash guard writing to `$GITHUB_OUTPUT`) | — | Runner-side decision; must emit a log line, so it cannot be a step-level `if:` alone |
| Local pre-flight proof of all of the above | Workstation (`scripts/smoke-scans.sh`) | — | Phase 15's established pattern: prove locally before pushing a workflow |
| Report artifact retention / SARIF upload | **Phase 17, not this phase** | — | CICD-02/CICD-03 are explicitly Phase 17; this phase only writes files to the runner |

**Tier constraint the planner must honour:** the three sub-scans are **steps inside the existing `sca` job**, not new top-level jobs. CICD-01 ("5 parallel scan jobs") is already marked Complete; Phase 17 Success Criterion 3 says "one per scan job, **including the SCA sub-scans**"; and 15-05-SUMMARY recorded five verbatim check-run names that Phase 18 will configure as required status checks. Adding a sixth/seventh/eighth job breaks all three. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` §Phase 17, `.planning/phases/15-five-parallel-scan-jobs/15-05-SUMMARY.md`]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **SCA-01** | SCA job audits npm/Node dependencies | `npm audit --audit-level=high --json` measured against `fixtures/package-lock.json`: rc=1, 2 vulnerabilities (1 high `lodash`, 1 critical `minimist`) with explicit `severity` fields per advisory and a `metadata.vulnerabilities` severity histogram. npm 10.9.8 is preinstalled on the runner — no `setup-node` needed. See Standard Stack, Pitfall 1, Code Example 1. |
| **SCA-02** | SCA job audits Python dependencies (pip-audit or equivalent) | `pip-audit` 2.10.1 verified on PyPI + Context7 `/pypa/pip-audit`, slopcheck `[OK]`. Measured against a 3-package pinned `requirements.txt`: rc=1, 39 vulns across 5 packages, JSON with PYSEC/CVE/GHSA IDs and `fix_versions`. **No Python fixture exists yet** — must be created. Two invocation modes measured (fast/safe vs. resolving) with a real tradeoff: see Standard Stack + Open Question Q2. |
| **SCA-03** | SCA job checks Terraform provider/module pinning | tflint v0.64.0 with its bundled `terraform` ruleset. Measured to flag `terraform_required_providers` (missing version constraint), `terraform_module_version` (registry module without `version`), `terraform_module_pinned_source` (git module unpinned or on a default branch), `terraform_required_version`. Checkov (already in the IaC job) covers modules only — it has **no** provider-pinning policy. **Current fixture produces zero pinning findings**: see Pitfall 3 and Fixture Work Required. |

**Success Criterion 4** ("each sub-scan skips cleanly … no failure, no false pass") is a cross-cutting requirement. It maps to the detect-then-guard pattern (Pattern 1) plus a negative test in the smoke gate (Validation Architecture).
</phase_requirements>

## Carried-Forward Decisions from Phase 15

No `16-CONTEXT.md` exists (`/gsd:discuss-phase` has not been run for this phase), so there are no locked user decisions. The following Phase 15 decisions do or do not carry forward — the planner must not guess:

| Phase 15 decision | Carries into Phase 16? | Reason |
|---|---|---|
| **D-04** — keep the tool's native fail/exit-code behaviour, tolerate at the step level with `continue-on-error: true` | **YES** | Report-only is still in force until Phase 18 (CICD-06). Every new sub-scan step gets `continue-on-error: true` and keeps its native severity flags. [VERIFIED: `15-CONTEXT.md` §Report-only conversion] |
| **D-06** — no conditional "check for Dockerfile, skip if absent" logic; the container job builds unconditionally | **NO — explicitly inverted** | D-06 was scoped to the *container* job and was justified by Phase 15 Criterion 2 ("not a skipped or stubbed step"). Phase 16 Criterion 4 *requires* conditional skip logic. A planner inheriting D-06 would fail Criterion 4. [VERIFIED: `15-CONTEXT.md` §Container job trigger vs. `.planning/ROADMAP.md` §Phase 16 criterion 4] |
| **D-05** — SCA-04's generic sweep is Trivy only; Grype reserved, not run redundantly | **YES** | Unchanged. Grype is not introduced by this phase. |
| SHA-pin every `uses:` with a trailing version comment (ADR-004) | **YES** | Any new action reference needs a real SHA. See Standard Stack for resolved SHAs. |
| Fixtures live in `fixtures/`, excluded from four pre-commit hooks | **YES, with a gap** | `exclude: ^fixtures/` exists on `terraform_fmt`, `terraform_validate`, `hadolint`, `npm-audit`. **No hook fires on `requirements.txt`** (ruff is `types_or: [python, pyi]`), so a new Python fixture needs no new exclusion. [VERIFIED: read `repos/security-platform/.pre-commit-config.yaml`] |

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `npm audit` | bundled with npm 10.9.8 (ubuntu-24.04 runner) / 11.19.0 (ubuntu-26.04) | SCA-01 — npm lockfile audit against the GitHub Advisory Database | Zero install, already the blueprint's designated "fast npm SCA" tool and already this repo's pre-commit hook. [VERIFIED: `docs/development-security-stack-option-1.md:144,1296-1308`; runner versions VERIFIED via `gh api repos/actions/runner-images/contents/images/ubuntu/Ubuntu2404-Readme.md`] |
| `pip-audit` | **2.10.1** (latest on PyPI, verified 2026-09-10) | SCA-02 — Python requirement/project audit against the PyPI advisory database (PYSEC) | PyPA-maintained, named directly in SCA-02's requirement text. [VERIFIED: `pip index versions pip-audit`; Context7 `/pypa/pip-audit`; slopcheck `[OK]`] |
| `tflint` | **v0.64.0** (released 2026-07-17) + bundled `tflint-ruleset-terraform` (0.14.x) | SCA-03 — Terraform provider constraint + module pinning checks | The only tool in this stack that checks **provider** version constraints. Checkov (already running in the IaC job) has no provider-pinning policy. [VERIFIED: `gh api repos/terraform-linters/tflint/releases/latest`; rule behaviour measured locally with tflint 0.61.0] |
| `trivy fs` | v0.74.0 (unchanged) | SCA-04 — generic sweep, already in place | Phase 15, D-05. Not modified by this phase except that its finding count will rise when the Python fixture lands. |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `pipx` | 1.16.7 (preinstalled on runner) | PEP 668 fallback for installing `pip-audit` | Only if `pip install pip-audit==2.10.1` hits an externally-managed-environment error. This is the same A7 fallback ladder Phase 15 documented for Semgrep. [VERIFIED: runner readme] |
| `jq` / `python3` | preinstalled | Parsing report JSON in verification steps | Phase 15's `smoke-scans.sh` already uses `python3 -c` for this; follow that pattern rather than introducing `jq`. |
| `unzip` | preinstalled | tflint releases ship as `.zip`, **not `.tar.gz`** | The Gitleaks install pattern in `security.yml` uses `tar xzf` — it cannot be copy-pasted for tflint. [VERIFIED: `gh api repos/terraform-linters/tflint/releases/tags/v0.64.0 --jq '.assets[].name'`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| tflint (SCA-03) | Checkov `CKV_TF_1` / `CKV_TF_2` (already running in the IaC job) | Measured: covers **module** pinning only, and `CKV_TF_1` fails even a registry module correctly pinned to `version = "5.0.0"` because it demands a git commit hash — high false-positive rate for registry modules. **No provider-pinning policy exists in Checkov.** Cannot satisfy SCA-03's "provider and module" wording alone. |
| tflint | Hand-rolled `grep` for `version =` in `*.tf` | See Don't Hand-Roll. HCL is not line-oriented; `version` appears in provider blocks, module blocks, and unrelated resource attributes. |
| `npm audit` (SCA-01) | `osv-scanner` | Would cover npm + Python + more in one binary, but introduces a new tool with no precedent in the blueprint or `versions.conf`, and SCA-01/SCA-02 name npm audit / pip-audit. Not recommended for this phase. |
| `pip-audit` (SCA-02) | `safety`, `uv pip audit` | `safety` moved to an account-gated model (contradicts the "zero-cost, no account" core value in PROJECT.md). `uv` is not in this stack. |
| Direct binary install of tflint | `terraform-linters/setup-tflint@v6.3.1` action (SHA `1cf010d3c7aef302051ccdb68c14c5dc2efa34ef`) | The action is convenient and Dependabot-trackable, but adds a third-party action to the trust boundary. The checksum-verified direct download matches the established Gitleaks pattern in `security.yml` and keeps ADR-004's guarantee end-to-end. **Recommend the direct download; the action SHA is recorded here in case the planner/user prefers it.** [VERIFIED: `gh api repos/terraform-linters/setup-tflint/git/ref/tags/v6.3.1`] |
| Direct `pip install pip-audit` | `pypa/gh-action-pip-audit@v1.1.0` (SHA `1220774d901786e6f652ae159f7b6bc8fea6d266`) | Action last released 2024-08-08 (stale relative to pip-audit 2.10.1). Direct `pip install` matches the existing Semgrep step shape in `security.yml`. **Recommend direct install.** [VERIFIED: `gh api repos/pypa/gh-action-pip-audit/releases/latest`] |

**Installation (in the `sca` job — no `setup-node`/`setup-python` required, both are preinstalled):**

```bash
# SCA-02
pip install pip-audit==2.10.1

# SCA-03 — download, verify checksum, then extract (never curl | sh)
curl -sSfL -o tflint.zip \
  https://github.com/terraform-linters/tflint/releases/download/v0.64.0/tflint_linux_amd64.zip
echo "cca9d13e2e1d7a2c627af60ff899a3c9b74212899416aeb96ec764d2ef954537  tflint.zip" | sha256sum -c -
sudo unzip -o -d /usr/local/bin tflint.zip
```

The SHA-256 above was read directly from the official `checksums.txt` asset for v0.64.0. [VERIFIED: `curl https://github.com/terraform-linters/tflint/releases/download/v0.64.0/checksums.txt`]

**Version verification performed:**

```
pip index versions pip-audit     → 2.10.1 (latest)
gh api .../tflint/releases/latest → v0.64.0, published 2026-07-17
runner-images Ubuntu2404-Readme  → Node 22.23.2, Npm 10.9.8, Python 3.12.3, Pip 24.0, Pipx 1.16.7
runner-images Ubuntu2604-Readme  → Node 24.20.0, Npm 11.19.0, Python 3.14.4, Pipx 1.17.1
```

The ubuntu-26.04 image also carries node/npm/python/pipx, so relying on preinstalled runtimes survives the eventual `ubuntu-latest` label migration. [VERIFIED: both runner readmes via `gh api`]

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `pip-audit` 2.10.1 | PyPI | first release 0.0.1; 2.x line multi-year | n/a (not probed) | github.com/pypa/pip-audit | `[OK]` | **Approved** — discovered via Context7 `/pypa/pip-audit` (High reputation), confirmed on PyPI, slopcheck clean |
| `tflint` v0.64.0 | GitHub Releases (not a language registry) | repo long-lived; release 2026-07-17 | n/a | github.com/terraform-linters/tflint | n/a (binary release) | **Approved** — release assets + `checksums.txt` + keyless cosign signature (`checksums.txt.keyless.sig`, `checksums.txt.pem`) confirmed present via `gh api` |
| `npm audit` | bundled with npm | n/a | n/a | github.com/npm/cli | n/a | **Approved** — no install |
| `terraform-linters/setup-tflint` v6.3.1 | GitHub Actions | released 2026-09-04 | n/a | github.com/terraform-linters/setup-tflint | n/a | **Recorded, not recommended** — see Alternatives Considered |
| `pypa/gh-action-pip-audit` v1.1.0 | GitHub Actions | released 2024-08-08 | n/a | github.com/pypa/gh-action-pip-audit | n/a | **Recorded, not recommended** — stale relative to pip-audit 2.10.1 |

**Packages removed due to slopcheck `[SLOP]` verdict:** none
**Packages flagged as suspicious `[SUS]`:** none

slopcheck was available and executed: `slopcheck install pip-audit` → `[OK] pip-audit (pypi)`, `1 OK`. No `--json` flag exists in the installed slopcheck build; the human-readable verdict is recorded above verbatim.

## Architecture Patterns

### System Architecture Diagram

```
  pull_request event
        │
        ▼
  pr-security.yml  (thin caller, permissions: contents: read)
        │  uses: ./.github/workflows/security.yml
        ▼
  security.yml  (on: workflow_call)
        │
        ├── sast ──────────┐
        ├── iac ───────────┤
        ├── container ─────┤  (unchanged by Phase 16 — still parallel, still report-only)
        ├── secrets ───────┤
        │                  │
        └── sca  ◄── THIS PHASE MODIFIES ONLY THIS JOB
             │
             │  actions/checkout  →  install pip-audit + tflint
             │
             ├─[A] detect npm ────► lockfile found? ──no──► log "SKIP: no package-lock.json" ──┐
             │                           │yes                                                  │
             │                           ▼                                                     │
             │                    npm audit --json ──► npm-audit-<n>.json ─────────────────────┤
             │                                                                                 │
             ├─[B] detect python ─► req/project found? ─no─► log "SKIP: no Python deps" ───────┤
             │                           │yes                                                  │
             │                           ▼                                                     │
             │                    pip-audit -f json ──► pip-audit-<n>.json ────────────────────┤
             │                                                                                 │
             ├─[C] detect terraform ► *.tf found? ────no──► log "SKIP: no .tf files" ──────────┤
             │                           │yes                                                  │
             │                           ▼                                                     │
             │                    tflint --recursive ──► tflint.sarif / tflint.json ───────────┤
             │                                                                                 │
             └─[D] trivy fs .  (SCA-04, Phase 15, unchanged) ──► trivy-fs.json/.sarif ─────────┤
                                                                                               │
                                          ┌────────────────────────────────────────────────────┘
                                          ▼
                                "Show scan output files" step (if: always())
                                          │
                                          ▼
                              files on runner — consumed by Phase 17
```

Every `[A]`–`[C]` run step carries `continue-on-error: true` (D-04). Every detect step exits 0 unconditionally and writes `found=true|false` to `$GITHUB_OUTPUT` **plus** an explicit log line.

### Recommended File Changes

```
repos/security-platform/
├── .github/workflows/security.yml     # MODIFY — sca job gains 3 detect+run step pairs
├── fixtures/
│   ├── main.tf                        # MODIFY — add floating/unpinned provider + module (SCA-03 seed)
│   ├── requirements.txt               # CREATE — pinned old Python packages (SCA-02 seed)
│   └── README.md                      # MODIFY — fixture reference table + measured counts
└── scripts/smoke-scans.sh             # MODIFY — expected-rc param, 3 new sub-scans, negative skip test
```

### Pattern 1: Detect-then-guard (Success Criterion 4)

**What:** A detection step that always exits 0, logs an explicit message, and publishes a boolean to `$GITHUB_OUTPUT`; the scan step gates on that boolean with a step-level `if:`.

**When to use:** Every one of the three sub-scans.

**Why not a bare `if: hashFiles('**/package-lock.json') != ''` on the scan step:** a step skipped by `if:` produces *no log output at all*. Criterion 4 demands "a clear log message." The detection step is what produces it.

**Why this is the project's own precedent, not an invention:** the reference workflow `repos/security-platform/cicd/.github/workflows/security.yml` already uses exactly this shape for its container job (`Check for Dockerfile` → `$GITHUB_OUTPUT` → `echo "No Dockerfile found — skipping container scan"`). Reuse it rather than inventing a new idiom. [VERIFIED: read `cicd/.github/workflows/security.yml:126-145`]

```yaml
- name: Detect npm lockfiles
  id: npm
  run: |
    mapfile -t LOCKS < <(git ls-files -- '*package-lock.json' 'package-lock.json' \
                         | grep -v '/node_modules/' || true)
    if [ "${#LOCKS[@]}" -eq 0 ]; then
      echo "found=false" >> "$GITHUB_OUTPUT"
      echo "SKIP: no package-lock.json in this repository — npm sub-scan not applicable"
    else
      echo "found=true" >> "$GITHUB_OUTPUT"
      printf '%s\n' "${LOCKS[@]}" > npm-lockfiles.txt
      echo "FOUND ${#LOCKS[@]} npm lockfile(s):"; cat npm-lockfiles.txt
    fi

- name: SCA-01 — npm audit
  if: steps.npm.outputs.found == 'true'
  continue-on-error: true          # D-04
  run: |
    ...
```

**Anti-pattern warning:** do not put the detection and the scan in the same `run:` block. GitHub's default shell is `bash -e`; every scanner here is *expected* to exit non-zero under D-04, so a second command in the same block would be silently dropped. Phase 15 already hit this with Gitleaks and split it into two steps — the comment is in `security.yml` today.

### Pattern 2: Verify the report, not the exit code

**What:** After each sub-scan, assert the report file parses as JSON/SARIF and contains the expected structural key — rather than trusting exit status.

**When to use:** Always, for npm audit and pip-audit specifically (see Pitfall 1 and Pitfall 2 — both return rc=1 for errors *and* for findings).

```bash
python3 -c "
import json,sys
d = json.load(open('npm-audit.json'))
if 'error' in d:
    print('ERROR REPORT:', d['error']['code']); sys.exit(1)
print('npm audit severities:', d['metadata']['vulnerabilities'])
"
```

### Pattern 3: Per-file iteration for monorepo-shaped consumer repos

**What:** Discover lockfiles/requirements with `git ls-files`, iterate, and write one numbered report per input (`npm-audit-1.json`, `npm-audit-2.json`, …).

**Why:** `npm audit` operates on the working directory, not on a named file — it must be run with `cd` into each lockfile's directory. `pip-audit -r` takes a file path and can be repeated. Consumer repos in this org are not guaranteed to have a single root-level manifest, and DIST-08 targets 6+ heterogeneous repos.

**Note for Phase 17:** numbered per-input reports mean the artifact upload cannot assume a fixed filename. Flag this forward.

### Anti-Patterns to Avoid

- **Adding new top-level jobs for the sub-scans:** breaks CICD-01's "5 parallel jobs" (already Complete), Phase 17 Criterion 3's per-job artifact mapping, and the five verbatim check-run names Phase 18 needs.
- **`set -euo pipefail` in a sub-scan `run:` block:** all three tools exit non-zero by design here. Use explicit `rc=0; cmd || rc=$?` capture, as `smoke-scans.sh` already does.
- **Treating "0 findings" as a green signal without checking the tool actually ran:** the "false pass" Criterion 4 forbids.
- **Flipping the tools to soft-fail mode** (`npm audit --audit-level=none`, tflint `--force`): Phase 15's D-04 is explicit — keep native severity semantics, tolerate at the step level, so Phase 18 can turn the gate back on without re-deriving thresholds.
- **Copy-pasting the Gitleaks `tar xzf` install for tflint:** tflint ships `.zip`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Terraform provider/module pin checking | `grep -E 'version\s*=' *.tf` | `tflint --recursive` | HCL is block-structured, not line-oriented. `version =` appears in provider blocks, module blocks, and unrelated resource attributes. tflint distinguishes *missing constraint* from *loose constraint* from *exact pin*, resolves module source types (registry vs. git vs. local), and detects a git ref pointing at a default branch. Measured: it flagged `?ref=main` as "uses a default branch as ref" — no reasonable grep finds that. |
| npm advisory matching | Parsing `package-lock.json` and querying the advisory API yourself | `npm audit` | Requires the npm bulk-advisory endpoint's exact request shape, dependency-graph traversal for transitive `via` chains, and severity roll-up. |
| Python version-range → advisory matching | Comparing `requirements.txt` pins to a CVE feed | `pip-audit` | PEP 440 version ordering (epochs, pre-releases, local versions) is genuinely subtle, and PYSEC ranges are expressed in it. |
| Ecosystem detection | `ls`/`find` in a `run:` block with implicit globbing | `git ls-files` with an explicit `node_modules` exclusion | `find` descends into `node_modules`, `.terraform/`, and vendored trees, producing thousands of false inputs. `git ls-files` sees only tracked files — the same set CI is meant to gate. |

**Key insight:** all three requirements look like "grep for a pattern" and none of them are. SCA-03 is the worst offender: a hand-rolled pin check would pass the current fixture (which has an exact pin) and would have no opinion at all on the two categories of finding that matter most — missing constraints and default-branch git refs.

## Runtime State Inventory

Phase 16 is additive CI configuration, not a rename/refactor/migration. This section is included only to record the one piece of **non-code state that does change**:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore holds any string this phase changes. Verified: the only persistent artifacts are files in `repos/security-platform`. | none |
| Live service config | **Check-run names.** The `sca` job's `name:` is currently `SCA — Trivy Filesystem` (byte-exact, em-dash U+2014). It becomes misleading once four tools run in it. If renamed, GitHub's check-run name changes and **Phase 18's branch-protection required-check list must use the new name.** 15-05-SUMMARY recorded the old five names specifically for Phase 18. | decision + SUMMARY must re-record the verbatim name |
| OS-registered state | None. | none |
| Secrets/env vars | None — no new secret or env var is introduced. npm audit and pip-audit reach public registries unauthenticated. | none |
| Build artifacts | `fixtures/package-lock.json` is unchanged. A new `fixtures/requirements.txt` is source, not a build artifact; nothing installs it. | none |

**Downstream side effect to record:** adding `fixtures/requirements.txt` raises the **SCA-04 Trivy filesystem** finding count, because Trivy already parses `requirements.txt`. Measured: a 3-package old-pin requirements file yielded 11 pip vulnerabilities from `trivy fs`. `fixtures/README.md`'s measured-count table must be updated in the same commit, or it becomes stale documentation.

## Common Pitfalls

### Pitfall 1: `npm audit` exits 1 for "no lockfile" *and* for "vulnerabilities found"

**What goes wrong:** A guardless `npm audit` step in a repo with no `package-lock.json` exits 1 with `ENOLOCK`. Under `continue-on-error: true` the step is merely annotated, the job stays green, and a reader concludes "npm scan ran, nothing found." That is exactly the false pass Criterion 4 forbids.

**Measured evidence:**
```
$ cd <dir with no lockfile> && npm audit --json ; echo rc=$?
npm error code ENOLOCK
npm error audit This command requires an existing lockfile.
{"error":{"code":"ENOLOCK","summary":"This command requires an existing lockfile.", ...}}
rc=1

$ cd fixtures && npm audit --audit-level=high >/dev/null ; echo rc=$?
rc=1                                    # same code, completely different meaning
```

**How to avoid:** the detect-then-guard pattern, plus checking for the `error` key in the JSON report (Pattern 2).

**Warning signs:** an `npm-audit.json` whose top level is `{"error": …}` rather than `{"auditReportVersion": 2, …}`.

**In-repo corroboration:** this repo's own `npm-audit` pre-commit hook carries the comment `ENOLOCK exit 1 without this` next to its `exclude: ^fixtures/`. The pitfall has already bitten this project once.

### Pitfall 2: `pip-audit` exits 1 for "invalid input" *and* for "vulnerabilities found"

**Measured evidence:**
```
$ pip-audit -r requirements.txt   # file does not exist
ERROR:pip_audit._cli:invalid requirements input: requirements.txt
rc=1

$ pip-audit -r requirements.txt --require-hashes   # file exists but is unhashed
ERROR:pip_audit._cli:Failed to install packages: [...]
rc=1

$ pip-audit -r loose.txt --no-deps                 # requirement not pinned to ==
ERROR:pip_audit._cli:requirement jinja2 is not pinned to an exact version: jinja2>=2.0
rc=1
```

**How to avoid:** same as Pitfall 1 — guard on file existence, and assert the output file exists and parses with a `dependencies` key. Note that on the error paths above, `-o <file>` produces **no output file at all**, so `[ -s file ]` is a sufficient discriminator.

**Do not use `--require-hashes`** unless the consumer repo's requirements are hash-pinned; it is a hard error otherwise.

### Pitfall 3: The existing Terraform fixture cannot produce a pinning finding

**What goes wrong:** the plan assumes `fixtures/main.tf` seeds SCA-03 (15-05-SUMMARY says the `hashicorp/aws 3.74.0` pin "exists specifically to seed SCA-03"), writes the tflint step, observes findings, and ships. But the finding it observes is `terraform_required_version` — a *missing `required_version` block*, not a provider or module pinning issue. Criterion 3 ("floating or unpinned versions are reported as findings") would be unproven.

**Measured evidence — tflint against the real fixture, today:**
```
$ tflint --chdir=fixtures
1 issue(s) found:
Warning: terraform "required_version" attribute is required (terraform_required_version)
  on fixtures/main.tf line 5
rc=2
```
An exact pin (`version = "3.74.0"`) is what a pinning check *wants*. It is correctly silent.

**Measured evidence — what tflint does flag** (reproduction fixture built during this research):

| Construct | tflint rule fired? | Rule |
|---|---|---|
| `aws = { source = "hashicorp/aws", version = "3.74.0" }` (exact pin, provider used) | no | — |
| `random = { source = "hashicorp/random" }` (no `version`, provider used) | **yes** | `terraform_required_providers` — "Missing version constraint for provider" |
| `null = { source = ..., version = ">= 3.0" }` (floating range) | **no** | not flagged by the default ruleset |
| `module { source = "terraform-aws-modules/s3-bucket/aws" }` (registry, no `version`) | **yes** | `terraform_module_version` |
| `module { source = "git::https://…/mod.git" }` (no ref) | **yes** | `terraform_module_pinned_source` |
| `module { source = "git::https://…/mod.git?ref=main" }` (default branch) | **yes** | `terraform_module_pinned_source` |
| missing `required_version` in the `terraform {}` block | **yes** | `terraform_required_version` |

**Two consequences the planner must absorb:**
1. `terraform_required_providers` only fires when the provider is **actually used by a resource in the module**. In a reproduction with `required_providers` declared but no resources, the rule did not fire at all (a different rule, `terraform_unused_required_providers`, fired instead under the `all` preset). The fixture must declare *and use* the unconstrained provider.
2. **A floating range like `>= 3.0` is NOT flagged by the default ruleset.** Criterion 3's word "floating" is therefore only satisfiable via the *missing-constraint* and *unpinned-module* cases, unless a custom rule is added. State this honestly rather than claiming coverage the tool does not provide. See Open Question Q1.

**Fixture work required:** add to `fixtures/main.tf` (a) a provider in `required_providers` with **no `version` key**, plus a resource that uses it, and (b) a module block with an unpinned source. Both are additive — they do not disturb the existing Checkov findings that the IaC job depends on.

### Pitfall 4: tflint exits **2** on findings — `smoke-scans.sh` will misclassify it

**What goes wrong:** `scripts/smoke-scans.sh`'s `run_scan()` helper hard-codes `rc == 1` as PASS, `rc == 0` as "scanner found nothing," and *anything else* as "tool/infrastructure error." tflint's finding exit code is 2, so a perfectly healthy tflint run reporting real pinning findings would be recorded as a FAILURE with the message "tool/infrastructure error."

**Measured evidence:**
```
$ tflint                # findings present
rc=2
$ tflint                # clean directory
rc=0
$ tflint                # bad .tflint.hcl (preset "none")
rc=1                    # application error
$ tflint --force        # findings present, --force suppresses
rc=0
```
tflint's exit-code contract is actually the *best* of the three tools — it distinguishes findings (2) from errors (1). The problem is purely that the existing helper assumes Phase 15's tools.

**How to avoid:** add an expected-rc parameter to `run_scan()` (e.g. `run_scan_rc <expected> <label> <cmd...>`) rather than adding a tflint special case. Phase 15 already learned the adjacent lesson — 15-05 records that using the wrong helper (`run_scan` vs `require_success`) "inverted their pass/fail verdict during first live test."

### Pitfall 5: `tflint` without `--recursive` finds nothing in a subdirectory

**Measured evidence:**
```
$ cd repos/security-platform && tflint            ; echo rc=$?   # fixtures/main.tf ignored
rc=0
$ cd repos/security-platform && tflint --recursive; echo rc=$?
1 issue(s) found: ... on fixtures/main.tf line 5
rc=2
```
tflint operates on a single Terraform *module directory* by default (like `terraform` itself). A repo-root invocation sees zero `.tf` files and exits 0 — a silent false pass. `--recursive` (or `--chdir=<dir>`) is mandatory.

### Pitfall 6: tflint has no output-file flag — SARIF/JSON must be redirected

`tflint --format sarif` writes to **stdout**; there is no `-o`. Combined with the `bash -e` default shell and a non-zero exit, the redirect must be its own step or use explicit rc capture. Verified: `tflint --recursive --format sarif > tflint.sarif` produces a schema-valid SARIF 2.1.0 document — including on an empty directory (rc=0, `results: []`) and on a clean module (rc=0, `results: 0`).

### Pitfall 7: `npm audit --audit-level` gates the exit code only — it does **not** filter the report

**Measured evidence:**
```
$ npm audit --audit-level=critical --json | ...
vulns in report: ['lodash', 'minimist']       # lodash is HIGH, still present
metadata: {'high': 1, 'critical': 1, 'total': 2}
```
This is the **inverse** of Phase 15's Trivy pitfall, where `--severity HIGH,CRITICAL` *did* filter the report file (recorded as Pitfall 7 / Assumption A3 in 15-05-SUMMARY and handed to Phase 17). Phase 17 must not generalise one tool's behaviour to the other: Trivy's filter is destructive to the artifact, npm audit's is not. Record this distinction in the phase SUMMARY.

### Pitfall 8: `pip-audit -r` invokes `pip` and resolves (and downloads) transitive dependencies by default

**Measured evidence** — same `requirements.txt` containing only `jinja2==2.11.2`:

| Invocation | Wall time | Dependencies in report |
|---|---|---|
| `pip-audit -r requirements.txt` | 11.58 s | `['jinja2', 'markupsafe']` |
| `pip-audit -r requirements.txt --no-deps` | 11.56 s | `['jinja2', 'markupsafe']` |
| `pip-audit -r requirements.txt --no-deps --disable-pip` | **0.51 s** | `['jinja2']` |

`--no-deps` **alone did not prevent resolution** in pip-audit 2.10.1 — measured, twice, on distinct fixtures. Only `--no-deps --disable-pip` together bypass pip. This matters for two reasons: a 23× speed difference, and a supply-chain one — the resolving path runs `pip install --dry-run --report` in a temporary virtualenv against whatever a consumer repo's `requirements.txt` names, which is metadata-generating activity on untrusted input.

**The tradeoff is real and unresolved** — see Open Question Q2. `--no-deps --disable-pip` hard-errors (rc=1) on any requirement not pinned with `==`, which many consumer repos will have.

## Code Examples

### SCA-01 — npm audit sub-scan

```yaml
# Source: measured against repos/security-platform/fixtures/ (npm 11.7.0, 2026-09-10)
- name: Detect npm lockfiles
  id: npm
  run: |
    mapfile -t LOCKS < <(git ls-files '*package-lock.json' | grep -v '/node_modules/' || true)
    if [ "${#LOCKS[@]}" -eq 0 ]; then
      echo "found=false" >> "$GITHUB_OUTPUT"
      echo "SKIP: no package-lock.json found — npm sub-scan not applicable to this repository"
    else
      echo "found=true" >> "$GITHUB_OUTPUT"
      printf '%s\n' "${LOCKS[@]}" > npm-lockfiles.txt
      echo "FOUND ${#LOCKS[@]} npm lockfile(s):"; cat npm-lockfiles.txt
    fi

- name: SCA-01 — npm audit
  if: steps.npm.outputs.found == 'true'
  continue-on-error: true          # D-04: native --audit-level semantics kept
  run: |
    i=0
    while read -r lock; do
      i=$((i+1))
      dir="$(dirname "$lock")"
      rc=0
      ( cd "$dir" && npm audit --audit-level=high --json ) > "npm-audit-${i}.json" || rc=$?
      echo "npm audit [$dir] exit=${rc}"
      exit "$rc"     # last one wins; continue-on-error tolerates it
    done < npm-lockfiles.txt
```

Measured output shape (`fixtures/`): `rc=1`, and

```json
{"auditReportVersion": 2,
 "vulnerabilities": {"lodash": {"severity": "high", "via": [{"title": "Command Injection in lodash",
   "url": "https://github.com/advisories/GHSA-35jh-r3h4-6jhm", "severity": "high",
   "cvss": {"score": 7.2}, "range": "<4.17.21"}]}, "minimist": {...}},
 "metadata": {"vulnerabilities": {"high": 1, "critical": 1, "total": 2}}}
```

The per-advisory `severity` field and the `metadata.vulnerabilities` histogram are what satisfy Criterion 1's "with severity levels."

### SCA-02 — pip-audit sub-scan

```yaml
# Source: measured with pip-audit 2.10.1, 2026-09-10
- name: Detect Python dependency files
  id: py
  run: |
    mapfile -t REQS < <(git ls-files 'requirements*.txt' '**/requirements*.txt' || true)
    if [ "${#REQS[@]}" -eq 0 ]; then
      echo "found=false" >> "$GITHUB_OUTPUT"
      echo "SKIP: no requirements*.txt found — Python sub-scan not applicable to this repository"
    else
      echo "found=true" >> "$GITHUB_OUTPUT"
      printf '%s\n' "${REQS[@]}" > py-reqs.txt
      echo "FOUND ${#REQS[@]} Python requirements file(s):"; cat py-reqs.txt
    fi

- name: SCA-02 — pip-audit
  if: steps.py.outputs.found == 'true'
  continue-on-error: true          # D-04
  run: |
    i=0; last=0
    while read -r req; do
      i=$((i+1)); rc=0
      pip-audit -r "$req" --format json --progress-spinner=off \
        -o "pip-audit-${i}.json" || rc=$?
      echo "pip-audit [$req] exit=${rc}"
      last="$rc"
    done < py-reqs.txt
    exit "$last"
```

Measured output shape:

```json
{"dependencies": [
   {"name": "requests", "version": "2.19.1",
    "vulns": [{"id": "PYSEC-2018-28", "fix_versions": ["2.20.0"],
               "aliases": ["CVE-2018-18074"], "description": "..."}]},
   {"name": "chardet", "version": "3.0.4", "vulns": []}],
 "fixes": []}
```

**Note for Criterion 2 and for Phase 17:** pip-audit's JSON contains advisory IDs, aliases, fix versions, and descriptions — but **no severity field and no CVSS score**. Criterion 2 only requires "reports Python advisories," which this satisfies; but if Phase 18's gate mode wants a Python severity threshold, it will have to be derived externally (e.g. from OSV) or the Trivy pip results used instead. Flag forward.

**Also for Phase 17:** pip-audit formats are `columns | json | cyclonedx-json | cyclonedx-xml | markdown`. **There is no SARIF output.** Neither does `npm audit`. Phase 17's Criterion 4 ("a tool without native SARIF output still reaches the Security tab or the artifact set through a documented conversion step") therefore applies to two of this phase's three tools. tflint does emit SARIF natively. [VERIFIED: `pip-audit --help`, `npm audit --help`, `tflint --help`]

### SCA-03 — tflint sub-scan

```yaml
# Source: measured with tflint 0.61.0 + bundled ruleset 0.14.1, 2026-09-10
- name: Detect Terraform files
  id: tf
  run: |
    if [ -z "$(git ls-files '*.tf')" ]; then
      echo "found=false" >> "$GITHUB_OUTPUT"
      echo "SKIP: no .tf files found — Terraform pinning sub-scan not applicable to this repository"
    else
      echo "found=true" >> "$GITHUB_OUTPUT"
      echo "FOUND Terraform files:"; git ls-files '*.tf'
    fi

- name: SCA-03 — tflint (provider/module pinning)
  if: steps.tf.outputs.found == 'true'
  continue-on-error: true          # D-04 — NOTE: tflint exits 2 on findings, not 1
  run: |
    tflint --recursive --format sarif > tflint.sarif || rc=$?
    tflint --recursive --format default; exit $?   # human-readable in the log
```

(The two-invocation shape mirrors the Gitleaks precedent in `security.yml`: tflint has no dual-output flag and no `-o`, and a second command after a non-zero exit in a `bash -e` block would be dropped. Splitting into two steps with `if: always()` is the safer form — follow whichever the planner picks, but do not chain them in one `run:` without explicit rc capture.)

Measured SARIF (schema 2.1.0) rule IDs emitted: `terraform_required_providers`, `terraform_module_version`, `terraform_module_pinned_source`, `terraform_required_version`.

### Negative test (Criterion 4) for `smoke-scans.sh`

```bash
# Prove the skip path, not just the finding path.
TMP="$(mktemp -d)"; ( cd "$TMP" && git init -q )
for probe in npm python terraform; do
  out="$(cd "$TMP" && bash "$REPO_ROOT/scripts/detect-${probe}.sh" 2>&1)" || true
  if grep -q "^SKIP:" <<<"$out"; then
    echo "==> skip-${probe}: PASS (clean skip with message)"
  else
    FAILURES+=("skip-${probe}: no SKIP message on an empty repo")
  fi
done
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `npm audit` as the primary npm SCA | `npm audit` as a *fast, lockfile-scoped* check alongside a generic SBOM/vuln scanner | established position in this project's blueprint | The blueprint already states this explicitly — `npm audit` "is not a replacement for Grype … it is a fast, zero-setup first line of defence." Phase 16 is consistent with it. [CITED: `docs/development-security-stack-option-1.md:1296-1308`] |
| `pyup.io safety` for Python SCA | `pip-audit` (PyPA-maintained, PyPI advisory DB) | safety's account-gated model | pip-audit matches this project's zero-cost, no-account core value. |
| `tfsec` for Terraform static analysis | `tfsec` merged into Trivy's misconfig scanner; `tflint` remains the *linting/pinning* tool | Aqua acquired tfsec | Do not reach for `tfsec` — it is the misconfig lane (already Checkov's and Trivy's), not the pinning lane. `tflint` is unaffected and is the right tool here. [ASSUMED — direction is well-established but the merge date was not verified in this session] |
| `ubuntu-latest` == ubuntu-22.04 | `ubuntu-latest` currently resolves to ubuntu-24.04; ubuntu-26.04 images exist | ongoing | Relying on preinstalled node/npm/python is safe across both — both readmes list them. [VERIFIED: `gh api` on both runner readmes] |

**Deprecated/outdated:**
- `gitleaks detect` (already avoided in Phase 15) — unrelated but the same class of trap.
- `pypa/gh-action-pip-audit@v1.1.0` — last released 2024-08-08; direct `pip install` is more current.

## Project Constraints (from CLAUDE.md)

Extracted from `./CLAUDE.md` and `.claude/rules/*.md`. The planner must verify the plan complies with each.

| Constraint | Source | Bearing on this phase |
|---|---|---|
| This repo is a **reference documentation project**, not buildable software. Primary artifact is `docs/development-security-stack-option-1.md`. | CLAUDE.md | Executable work lands in `repos/security-platform/` (a separate git repo, gitignored by the outer one). Phase 16's blueprint/ADR reflection, if any, is a documentation edit in this repo. |
| Preserve ASCII architecture diagrams and the 4-phase layered structure; preserve tool coverage matrices. | CLAUDE.md | If the plan updates the blueprint's tool matrix to add pip-audit/tflint, it must preserve the surrounding structure and diagrams. |
| ADR records in `docs/adr/` are **append-only** — add new files, never modify accepted ones. | CLAUDE.md | Introducing tflint as a new stack tool arguably warrants ADR-015. Do not edit ADR-001…014. |
| **Never set the executable bit on script files.** Always invoke with an explicit interpreter (`bash scripts/x.sh`). | `.claude/rules/defensive-protocol-v2-anti-slop.md` | Any new detect/helper script must be invoked as `bash scripts/…`, never `./scripts/…`, and never `chmod +x`. |
| **Let it crash.** No silent fallbacks (`|| true`, `try/except: pass`) that convert hard failures into silent corruption. | anti-slop rule | Directly reinforces Pitfalls 1/2: a bare `|| true` on a sub-scan is the false-pass mechanism Criterion 4 forbids. Use explicit `rc=$?` capture and assert on it. |
| **On failure: STOP → REPORT → WAIT.** No silent retry. | anti-slop rule | Executor behaviour during plan execution. |
| State what was actually tested; "I don't know" is a valid output. Verification cadence: verify every 3–5 actions. | anti-slop / epistemology rules | Phase SUMMARY must report *measured* finding counts, not projected ones. |
| Chesterton's Fence — articulate why something exists before changing it. | epistemology rule | Applies squarely to `fixtures/main.tf`'s `3.74.0` pin: it exists for D-02 (and was believed to seed SCA-03). **Add** a floating construct; do not remove or loosen the existing pin — the IaC job's Checkov findings and the Phase 15 baseline depend on the file's current content. |
| Second-order effects — list what depends on a thing before changing it. | anti-slop rule | Changing the `sca` job's `name:` affects Phase 18's required-check configuration. Adding `fixtures/requirements.txt` affects the SCA-04 Trivy count and `fixtures/README.md`. |

**Project skills:** `.claude/skills/` contains `cdk-testing`, `create-prd`, `itsg-assessment`, `nist-csf-assessment`, `nist-fedramp-assessment`, `occ-skill-creator`, `occ-skill-refactor`, `rule-creator`, `terraform-testing`. None is a required workflow for this phase; `terraform-testing` may be worth a read if the planner elects to add Terraform validation beyond tflint.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Introducing **tflint** as a new tool is acceptable. It has **zero precedent** in this project — it appears nowhere in `docs/development-security-stack-option-1.md`, nowhere in `versions.conf`, and in no ADR. Verified by grep across the blueprint and the product repo. | Standard Stack | If the user wants to stay within the already-blessed toolset, SCA-03 must be re-scoped to Checkov CKV_TF_1/2 (modules only — cannot satisfy "provider" pinning) or a custom Checkov policy. **This is the single highest-value question for `/gsd:discuss-phase`.** |
| A2 | tflint should be **CI-only**, not added to `versions.conf` / `workstation/setup.sh`. | Standard Stack, Validation | If wrong, `scripts/smoke-scans.sh`'s preflight will fail on a workstation without tflint, and Phase 13's `check`/`update`/`doctor` commands won't know about it. An operator running the smoke gate on a clean machine would be blocked. |
| A3 | The `sca` job should be **renamed** from `SCA — Trivy Filesystem` to something covering four tools. | Runtime State Inventory | If renamed and Phase 18 is not told, branch protection would be configured against a check name that no longer exists — silently non-blocking. If *not* renamed, the check name misdescribes the job for the remaining life of the project. Either way the phase SUMMARY must record the final verbatim name. |
| A4 | Python detection should target `requirements*.txt` only, not `pyproject.toml` / `poetry.lock` / `Pipfile.lock` / `uv.lock`. | Code Examples | pip-audit supports a positional `project_path` (pyproject) and `--locked`, but those paths were **not measured** in this session. If a consumer repo uses Poetry or uv exclusively, SCA-02 would report a clean skip on a repo that does have Python dependencies — a defensible skip, but not full coverage. |
| A5 | Report-only (D-04) remains in force; no gate-mode work happens in this phase. | Carried-Forward Decisions | Low — explicitly stated in ROADMAP Phase 18 and 15-CONTEXT. |
| A6 | `tfsec` was merged into Trivy's misconfig scanner. | State of the Art | Very low impact — the claim is only used to explain why tfsec is *not* recommended; the recommendation stands regardless. |
| A7 | Adding a floating/unpinned provider and module to `fixtures/main.tf` will not disturb the IaC job's existing Checkov findings. | Pitfall 3 | Measured that Checkov's CKV_TF_1/CKV_TF_2 *will fire* on new unpinned module blocks — so the IaC job's failed-check count **will increase**. That is additive, not a regression, but `fixtures/README.md`'s "10 failed terraform checks" figure becomes stale. Plan must re-measure. |

## Open Questions

1. **Can "floating" provider versions actually be flagged, or only missing ones?**
   - What we know (measured): tflint's default `terraform` ruleset flags a **missing** `version` key in `required_providers`, but does **not** flag a loose range like `version = ">= 3.0"`. It flags registry modules with no `version` and git modules with no ref / a default-branch ref.
   - What's unclear: whether a tflint rule option, a custom ruleset, or a custom Checkov policy can flag loose *ranges* — and whether the project even wants that (Terraform's own best practice for root modules is `~>`, not `=`; flagging every `~>` would be very noisy).
   - Recommendation: scope Criterion 3 explicitly to **missing constraints and unpinned module sources**, state the loose-range limitation in the phase SUMMARY and adoption docs (DIST-08), and do not build a custom rule this phase.

2. **`pip-audit`: fast-and-safe, or slow-and-complete?**
   - What we know (measured): `--no-deps --disable-pip` = 0.5 s, no pip invocation, no transitive resolution — but hard-errors on any requirement not pinned with `==`. Default = ~11.5 s, resolves transitives via `pip install --dry-run --report` in a temp venv, works on loose requirements.
   - What's unclear: whether consumer repos in this org pin exactly. `repos/aws-zabbix-monitoring-solution` and `repos/terraform-pipelines` were not inspected for this.
   - Recommendation: use the **default (resolving)** invocation for consumer-repo generality, document the pip-invocation caveat in the Security Domain notes and DIST-08, and consider a `--no-deps --disable-pip` fast path as a documented opt-in. Alternatively, decide this in `/gsd:discuss-phase`.

3. **Does SCA-01's "with severity levels" require a severity *threshold*, or just severity *reporting*?**
   - What we know: `npm audit --audit-level=high` gates the exit code but does not filter the report; the report always carries per-advisory `severity`. The existing pre-commit hook uses `--audit-level=high`, and Phase 15's Trivy jobs use `--severity HIGH,CRITICAL`.
   - Recommendation: match the established `high` threshold for exit-code consistency, and note that the full-severity report is retained regardless (which is what Phase 17/DefectDojo will want).

4. **Should the blueprint document and/or an ADR be updated in this phase?**
   - What we know: CLAUDE.md makes the blueprint the primary artifact; the tool coverage matrix currently lists neither pip-audit nor tflint. ADRs are append-only.
   - Recommendation: if A1 is confirmed, add ADR-015 ("Adopt tflint for Terraform provider/module pin checking") as a new file and update the blueprint's tool matrix — but treat that as a separate plan from the workflow change so a failed CI iteration does not leave documentation half-edited.

## Environment Availability

| Dependency | Required By | Available (workstation) | Version | Available (CI runner) | Fallback |
|------------|-------------|------------------------|---------|----------------------|----------|
| `npm` | SCA-01 | ✓ | 11.7.0 | ✓ preinstalled | — |
| `node` | SCA-01 (npm) | ✓ | v25.2.1 | ✓ preinstalled | — |
| `python3` / `pip3` | SCA-02 | ✓ | 3.12.0 / 26.2.1 | ✓ preinstalled (3.12.3 / pip 24.0) | — |
| `pip-audit` | SCA-02 | ✗ → **installed during this research** via `pipx install pip-audit` | 2.10.1 | ✗ — must be installed by the job | `pipx install pip-audit==2.10.1` if PEP 668 blocks `pip install` |
| `tflint` | SCA-03 | ✓ | **0.61.0** (3 minor versions behind v0.64.0) | ✗ — must be installed by the job | checksum-verified `.zip` download; `setup-tflint@v6.3.1` as alternate |
| `terraform` | not required by tflint | ✓ | 1.15.6 | n/a | tflint does not require `terraform init` for the pinning rules measured here |
| `trivy` | SCA-04 (existing) | ✓ | 0.74.0 | ✓ via `setup-trivy@v0.3.1` | — |
| `unzip` | tflint install | ✓ (macOS built-in) | — | ✓ preinstalled | — |
| network access to registry.npmjs.org, pypi.org, api.osv.dev | SCA-01/02 | ✓ | — | ✓ | none — these tools are online-only by design |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:**
- `pip-audit` — absent from the workstation before this research; now present at 2.10.1 via `pipx`. If the smoke gate is to run on a clean machine, the plan must either add a preflight install step or add pip-audit to `versions.conf`/`workstation/setup.sh` (see Assumption A2).
- `tflint` 0.61.0 locally vs. v0.64.0 recommended for CI. This mirrors the **already-accepted** version split recorded in 15-05-SUMMARY ("Trivy 0.69.3 / Gitleaks 8.30.0 on the workstation vs Trivy v0.74.0 / Gitleaks 8.30.1 in CI … left deliberately divergent"). The rule behaviour measured here was measured on 0.61.0; the plan should re-confirm the same rule IDs fire under v0.64.0 in CI rather than assuming.

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`. This project has no unit-test framework; its validation harness is `repos/security-platform/scripts/smoke-scans.sh`, established in Phase 15-02.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `bash` + `scripts/smoke-scans.sh` (custom pass/fail gate, Phase 15-02) |
| Config file | none — the script is self-contained; preflight loop enumerates required binaries |
| Quick run command | `bash scripts/smoke-scans.sh` (from `repos/security-platform`) |
| Full suite command | `bash scripts/smoke-scans.sh` — plus `yamllint -d relaxed .github/workflows/security.yml` and `pre-commit run --all-files` |
| Static workflow check | `python3 -c "import yaml; ..."` job-id / `needs:` assertions, as used in 15-03 |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCA-01 | npm audit reports ≥1 vulnerability with a severity level against `fixtures/package-lock.json` | smoke | `run_scan_rc 1 "npm-audit" bash -c 'cd fixtures && npm audit --audit-level=high --json > "$OUT/npm-audit.json"'` then assert `metadata.vulnerabilities.high + .critical > 0` | ❌ Wave 0 — `run_scan_rc` helper does not exist |
| SCA-01 | npm report is a real report, not an `ENOLOCK` error object | smoke | `python3 -c "import json;d=json.load(open(f));assert 'error' not in d"` | ❌ Wave 0 |
| SCA-02 | pip-audit reports ≥1 advisory against `fixtures/requirements.txt` | smoke | `run_scan_rc 1 "pip-audit" pip-audit -r fixtures/requirements.txt -f json -o "$OUT/pip-audit.json"` then assert `sum(len(d['vulns'])) > 0` | ❌ Wave 0 — fixture and helper both missing |
| SCA-03 | tflint reports ≥1 **pinning** finding (rule id in `{terraform_required_providers, terraform_module_version, terraform_module_pinned_source}`) | smoke | `run_scan_rc 2 "tflint" bash -c 'tflint --recursive --format sarif > "$OUT/tflint.sarif"'` then assert the SARIF `results[].ruleId` set intersects the pinning rule set | ❌ Wave 0 — **must assert on rule ID, not just "≥1 finding"**, else `terraform_required_version` alone would false-pass Criterion 3 |
| Criterion 4 | each detector emits `SKIP:` and exits 0 in an empty git repo | smoke (negative) | run each detector in `$(mktemp -d)` with `git init`; assert stdout matches `^SKIP:` and rc=0 | ❌ Wave 0 |
| Criterion 4 | no sub-scan produces a false pass — every non-skipped sub-scan wrote a non-empty, parseable report | smoke | `require_nonempty` (exists) + a new `require_parses_json` | ❌ Wave 0 (partial — `require_nonempty` exists) |
| all | workflow YAML still declares exactly 5 jobs with zero `needs:` | static | `python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/security.yml')); assert len(d['jobs'])==5"` + `grep -c 'needs:'` == 0 | ✅ pattern exists (15-03) |
| all | workflow lints clean | static | `yamllint -d relaxed .github/workflows/security.yml` | ✅ |

### Sampling Rate

- **Per task commit:** `yamllint -d relaxed .github/workflows/security.yml` + the static job-count assertion (seconds).
- **Per wave merge:** `bash scripts/smoke-scans.sh` in full (includes the pre-existing five Phase 15 scanners plus the three new sub-scans plus the negative skip tests; expect several minutes, dominated by the Trivy DB download and `docker build`).
- **Phase gate:** full smoke gate green locally, **then** a live PR run observed with the three new sub-scans reporting, before `/gsd:verify-work`.

### Wave 0 Gaps

- [ ] `scripts/smoke-scans.sh` — add `run_scan_rc <expected_rc> <label> <cmd…>`, generalising `run_scan` (which hard-codes rc=1 as PASS). Covers SCA-03's rc=2. Re-point the existing five call sites at `run_scan_rc 1 …` or keep `run_scan` as a thin wrapper.
- [ ] `scripts/smoke-scans.sh` — add `require_parses_json <label> <file> <required_key>` so an error-object report fails loudly.
- [ ] `scripts/smoke-scans.sh` — add the three sub-scan sections (npm, pip, tflint) and add `npm`, `pip-audit`, `tflint` to the preflight binary loop.
- [ ] `scripts/smoke-scans.sh` — add the negative/empty-repo skip test block.
- [ ] `fixtures/requirements.txt` — does not exist; SCA-02 has nothing to scan without it.
- [ ] `fixtures/main.tf` — needs an unconstrained provider (declared **and used**) and an unpinned module block; without them SCA-03 has no pinning finding to report.
- [ ] `fixtures/README.md` — measured-count table needs new rows and re-measured existing rows (Trivy fs count rises once `requirements.txt` lands; Checkov count rises once unpinned modules land).

## Security Domain

`security_enforcement` is not set to `false` in `.planning/config.json` (the key is absent) — this section is therefore required.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture / SDLC | yes | This phase *is* a V1.14 (dependency management) control. The workflow itself is the artifact. |
| V2 Authentication | no | No authentication surface; all three registries are queried unauthenticated. |
| V3 Session Management | no | — |
| V4 Access Control | yes | Workflow `permissions:` stays at `contents: read`. No sub-scan needs more. A called workflow cannot self-elevate above the caller's grant (Phase 15 Pitfall 5) — do not add `security-events: write` here; that is Phase 17's change to `pr-security.yml`. |
| V5 Input Validation | yes | Fixture and consumer-repo files are untrusted input to the scanners. See threat table. |
| V6 Cryptography | yes | tflint binary integrity — SHA-256 checksum verification against the official `checksums.txt`, per the Gitleaks precedent. Never hand-roll; never `curl \| sh` (the SAST job's own `p/default` ruleset flags that pattern — recorded in `security.yml`). |
| V14 Configuration | yes | ADR-004 SHA pinning for any new `uses:`; no new secrets; no new env vars. |

### Known Threat Patterns for {GitHub Actions + multi-ecosystem SCA}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `pip-audit -r` runs `pip install --dry-run --report` against untrusted `requirements.txt`, which can trigger sdist metadata generation (`setup.py` execution) for non-wheel packages | Elevation of Privilege / Tampering | Either use `--no-deps --disable-pip` (measured: no pip invocation at all) accepting the exact-pin restriction, or accept the resolving path and document it. The job has `contents: read` only and no secrets, so blast radius is limited to the ephemeral runner. **Do not** run this step with elevated `permissions:`. |
| Script injection via `${{ }}` interpolation into a `run:` block | Tampering / EoP | No new interpolation is needed for any sub-scan. The only existing one (`${{ github.sha }}` in the container job) is not attacker-controlled. Keep it that way — pass values via `env:`, never inline, if any are added. |
| Compromised third-party action in the new steps | Tampering | ADR-004: every `uses:` SHA-pinned with a version comment. Recommended design avoids new actions entirely (direct install for both new tools). |
| tflint binary tampering in transit | Tampering | Download → `sha256sum -c` → `unzip`, never `curl \| sh`. The v0.64.0 release also ships `checksums.txt.keyless.sig` + `.pem` (cosign keyless) if stronger verification is later wanted. |
| npm lifecycle-script execution during audit | EoP | `npm audit` does not install; it reads the lockfile and queries the advisory endpoint. Verified by running it in `fixtures/` with no `node_modules` present. Do **not** add `npm ci`/`npm install` to the job. If any install is ever needed, `--ignore-scripts` is mandatory (the fixture README already documents this for lockfile regeneration). |
| False pass — a sub-scan silently not running and reading as clean | Repudiation / Information Disclosure (missed finding) | Detect-then-guard + assert-on-report-content + the negative skip test in the smoke gate. This is Criterion 4 stated as a security control. |
| Advisory-feed availability (registry outage ⇒ zero findings) | Denial of Service | Both `npm audit` and `pip-audit` fail loudly (non-zero + error text) on network failure rather than reporting clean; the report-content assertion catches it. tflint is fully offline for these rules. |
| Fixture content mistaken for real infrastructure/dependencies | Tampering | `fixtures/README.md` already carries the DO-NOT-FIX/INSTALL warning; any new fixture file must carry the same inline header comment. `fixtures/requirements.txt` must never be installed by any job. |

## Sources

### Primary (HIGH confidence)

- **Direct local measurement** (2026-09-10, this session) — every exit code, rule ID, timing, and report shape in this document. Tools used: npm 11.7.0, pip-audit 2.10.1, tflint 0.61.0 (+ bundled ruleset 0.14.1), trivy 0.74.0, checkov 3.2.396, terraform 1.15.6.
- Context7 `/pypa/pip-audit` — `--no-deps` / `--require-hashes` semantics, JSON output shape, GitHub Action usage, exit-code handling guidance.
- `gh api repos/terraform-linters/tflint/releases/latest` and `.../releases/tags/v0.64.0` — v0.64.0, published 2026-07-17; asset list including `checksums.txt`, `checksums.txt.keyless.sig`, `checksums.txt.pem`, `tflint_linux_amd64.zip`.
- `https://github.com/terraform-linters/tflint/releases/download/v0.64.0/checksums.txt` — SHA-256 `cca9d13e…4537` for `tflint_linux_amd64.zip`.
- `gh api repos/actions/runner-images/contents/images/ubuntu/Ubuntu2404-Readme.md` and `Ubuntu2604-Readme.md` — preinstalled Node/npm/Python/pip/pipx/Docker versions.
- `gh api repos/{terraform-linters/setup-tflint,pypa/gh-action-pip-audit,actions/setup-node,actions/setup-python}/git/ref/tags/…` — resolved commit SHAs.
- `pip index versions pip-audit` — 2.10.1 latest.
- `slopcheck install pip-audit` — `[OK] pip-audit (pypi)`.
- In-repo primary sources read in full: `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/phases/15-five-parallel-scan-jobs/15-CONTEXT.md`, `15-05-SUMMARY.md`, `repos/security-platform/.github/workflows/security.yml`, `.../pr-security.yml`, `.../cicd/.github/workflows/security.yml`, `.../scripts/smoke-scans.sh`, `.../fixtures/*`, `.../.pre-commit-config.yaml`, `.../versions.conf`, `./CLAUDE.md`, `.claude/rules/*.md`, `docs/adr/README.md`, `docs/development-security-stack-option-1.md` (targeted sections).

### Secondary (MEDIUM confidence)

- `checkov -l` policy listing — CKV_TF_1 / CKV_TF_2 titles and source links (measured locally with Checkov 3.2.396; CI runs 3.3.17, so re-confirm if this becomes load-bearing).
- `docs/development-security-stack-option-1.md:1296-1308` — the project's own stated rationale for retaining `npm audit`.

### Tertiary (LOW confidence)

- The `tfsec` → Trivy merge claim in State of the Art — training knowledge, not verified this session. Marked `[ASSUMED]` (A6). It affects only a negative recommendation.

## Metadata

**Confidence breakdown:**

- **Standard stack: HIGH** — all three tools installed and run locally against the real fixtures; versions confirmed against PyPI and the GitHub Releases API; runner preinstall claims confirmed against the official runner-images readmes.
- **Architecture: HIGH** — the detect-then-guard pattern is not invented; it already exists in this repo's own `cicd/.github/workflows/security.yml`. The "steps not jobs" constraint is derived from three independent in-repo documents.
- **Pitfalls: HIGH** — every one of the eight pitfalls is backed by a measured command and its output, reproduced in this document. Pitfall 8's `--no-deps` anomaly was reproduced on two distinct fixtures.
- **Fixture gap analysis: HIGH** — tflint was run against the actual `repos/security-platform/fixtures/` tree; the single `terraform_required_version` finding is a direct observation, and the seven-construct rule table is from a purpose-built reproduction.
- **Open questions: honestly open** — Q1 (loose ranges) and Q2 (pip-audit invocation mode) are genuine tradeoffs, not gaps in this research; Q3/Q4 are scoping calls for the user.
- **Assumption A1 (tflint has no precedent in this project) is the single item most in need of user confirmation before planning.**

**Research date:** 2026-09-10
**Valid until:** 2026-10-10 (30 days — tflint and pip-audit both move slowly; re-verify the tflint release SHA-256 if a newer version is chosen, and re-check runner preinstalled versions if `ubuntu-latest` migrates to 26.04)
