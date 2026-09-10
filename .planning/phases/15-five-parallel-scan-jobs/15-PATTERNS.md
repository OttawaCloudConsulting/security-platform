# Phase 15: Five Parallel Scan Jobs - Pattern Map

**Mapped:** 2026-09-10
**Files analyzed:** 8 touched (2 modified, 6 new) + 4 explicitly NOT touched
**Analogs found:** 4 / 8 (4 fixture/new-artifact files have no in-repo analog)

## Path Convention (read this first)

The implementation lands in the **target repo**, an independent git repo checked out at
`repos/security-platform/` (remote `OttawaCloudConsulting/security-platform`). `repos/` is
gitignored by the outer docs repo.

| In this document | Means |
|---|---|
| Paths starting `.github/`, `fixtures/`, `scripts/`, `.pre-commit-config.yaml` | **Target repo** root — what CI checks out |
| Paths starting `repos/security-platform/` | The same files as seen from the outer repo (how you `Read` them locally) |

`fixtures/` = `repos/security-platform/fixtures/`. Nothing in this phase is created in the outer docs repo except `.planning/**`.

---

## File Classification

| New/Modified File (target-repo relative) | New/Mod | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| `.github/workflows/security.yml` | MODIFIED | config / CI orchestration | event-driven (workflow_call fan-out, 5 concurrent jobs) | `repos/security-platform/cicd/.github/workflows/security.yml` | **partial — SHAPE ONLY, see warning below** |
| `.github/workflows/security.yml` (header + envelope) | MODIFIED | config | event-driven | `repos/security-platform/.github/workflows/security.yml` (its own current content, Phase 14) | exact |
| `.pre-commit-config.yaml` | MODIFIED | config | batch (file-filtered hook dispatch) | itself (existing hook blocks, lines 15-23, 41-46, 74-82) | exact |
| `scripts/smoke-scans.sh` | NEW | utility / test harness | batch (sequential CLI invocations, exit-code capture) | `repos/security-platform/workstation/cicd/lint-markdown.sh` | role-match (**with a `set -e` trap — see below**) |
| `fixtures/README.md` | NEW | documentation | n/a | `repos/security-platform/cicd/README.md` / root `README.md` | role-match |
| `fixtures/Dockerfile` | NEW | fixture / test data | file-I/O (scan input) | none | **no analog** |
| `fixtures/main.tf` | NEW | fixture / test data | file-I/O (scan input) | none | **no analog** |
| `fixtures/package.json` | NEW | fixture / test data | file-I/O (scan input) | none | **no analog** |
| `fixtures/package-lock.json` | NEW (generated) | fixture / test data | file-I/O (scan input) | none | **no analog** |
| `.gitleaksignore` | **NOT MODIFIED** | config | n/a | n/a | see Decision Conflicts |
| `.github/workflows/pr-security.yml` | **NOT MODIFIED** | config | event-driven | n/a | Unchanged this phase (CONTEXT line 51). Do **not** widen its permissions to `security-events: write` here either — that is Phase 17 (CICD-02), and the caller is the only place the widening can legally happen |
| `.gitignore` | **NOT MODIFIED** | config | n/a | n/a | `fixtures/` must stay tracked (D-01); only `node_modules/` is ignored (line 18), which is correct as-is |
| `versions.conf` | **NOT MODIFIED (recommended)** | config | n/a | n/a | see Decision Conflicts |

---

## Analog Warning — the closest analog is the one you must NOT copy

`cicd/.github/workflows/security.yml` is a **shape** to follow, not a source to copy.
CONTEXT.md line 61 says its jobs "can be adapted almost verbatim"; RESEARCH.md line 55
falsified that — **five of its commands are stale or wrong** against current tool versions,
and it was written for `on: pull_request` with `security-events: write`, neither of which is
legal here.

**The authoritative command source is `15-RESEARCH.md` §Code Examples, lines 453-608.**
That YAML was extracted to a scratch file and run through `actionlint` 1.7.12 (shellcheck
integration active) → exit 0, plus structural assertions (5 jobs, no `needs:`,
`permissions: {contents: read}`). Treat it as the analog for *commands*; treat
`cicd/.../security.yml` as the analog for *structure and comment style* only.

---

## Pattern Assignments

### 1. `.github/workflows/security.yml` (config, event-driven — MODIFIED)

**Primary analog (envelope):** `repos/security-platform/.github/workflows/security.yml` — its own current Phase 14 content
**Secondary analog (job shape):** `repos/security-platform/cicd/.github/workflows/security.yml`
**Command source:** `15-RESEARCH.md` §Code Examples lines 453-608 (actionlint-verified)

#### Preserve, do not regenerate — current file lines 1-13

```yaml
---
# Callable security scanning workflow.
# Invoked by repo-local callers (see pr-security.yml) and, from Phase 20,
# by external repositories as a reusable workflow.
# All third-party actions are pinned to full commit SHAs (ADR-004).

name: Security Scans

on:
  workflow_call: {}

permissions:
  contents: read
```

RESEARCH's §Code Examples header (lines 456-459) **drops** the "Invoked by repo-local callers
… from Phase 20, by external repositories" line. Keep the existing lines 1-13 verbatim and
*append* the report-only note to the header comment. Replace only current lines 15-20
(`jobs:` + the `placeholder` job).

Suggested header addition (append after the ADR-004 line):

```
# Report-only (Phase 15): scan steps carry continue-on-error, so findings are
# visible but non-blocking. Gate mode is Phase 18 (CICD-06).
```

#### COPY from `cicd/.github/workflows/security.yml` — structural patterns

| What | Analog lines | Notes |
|---|---|---|
| Banner comment block per job (`# ─────` box with tool + purpose) | 21-25, 55-59, 90-94, 117-121, 175-179 | Keep the box-drawing style; rewrite the SCA box (Grype→Trivy) and the Container box (drop "Only runs if a Dockerfile exists") |
| Job ids + `name:` values | 26-27, 60-61, 95-96, 122-123, 180-181 | `sast`/`iac`/`sca`/`container`/`secrets`; names `SAST — Semgrep CE`, `IaC — Checkov`, `SCA — Trivy Filesystem`, `Container — Trivy Image`, `Secrets — Gitleaks` (em-dash, matching existing style). Check-run names render as `security / <job name>` (verified on PR #5) |
| Checkov `with:` block | 68-73 | Copy verbatim including `soft_fail: false` — D-04 keeps native semantics |
| `fetch-depth: 0` on the secrets checkout | 185-186 | Mandatory: `gitleaks git` finds 9 in history, `gitleaks dir` finds 0 in the tree |
| `if: always()` + `continue-on-error: true` on follow-up steps | 37-43, 49-50, 77-78 | The pattern already exists — **extend it to the scan step itself** per D-04 |
| `runs-on: ubuntu-latest` on every job | 28, 62, 97, 124, 182 | Required: `checkov-action` is a Docker action (Linux only) |

Verbatim excerpt of the `continue-on-error` / `if: always()` shape to extend (lines 36-43):

```yaml
      - name: Run Semgrep (SARIF output for GitHub Security tab)
        if: always()
        run: semgrep scan --config auto --sarif --output semgrep.sarif . || true

      - name: Upload SARIF to GitHub Security tab
        uses: github/codeql-action/upload-sarif@ebcb5b36ded6beda4ceefea6a8bc4cc885255bb3  # v3
        if: always()
        continue-on-error: true  # SARIF upload failure should not block the PR
```

Verbatim Checkov `with:` block to reuse (lines 66-73):

```yaml
      - name: Run Checkov
        uses: bridgecrewio/checkov-action@2fd3901c8feb52417f27f0d9800259a106c1ec1e  # v12
        with:
          directory: .
          output_format: cli,json,sarif
          output_file_path: console,checkov-results.json,checkov.sarif
          quiet: true
          soft_fail: false  # Any policy violation fails the job
```

(Reuse the `with:` keys and the `soft_fail: false` comment; **replace the SHA** with
`a8664e3a0549367977f0cda990a34311835c87c0  # v12.3123.0`.)

#### DO NOT COPY — line-by-line prohibitions

| Analog line(s) | Content | Why not | Do instead |
|---|---|---|---|
| 10-13 | `on: pull_request` / `push: branches: [main]` | Callable workflow takes no triggers | Keep `on: workflow_call: {}` (current file line 9-10) |
| 17 | `security-events: write` | A called workflow can only **downgrade** caller permissions; `pr-security.yml` grants `contents: read` (Pitfall 5) | Keep `permissions: contents: read` only |
| 30, 64, 99, 126, 184 | `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4` | 3 majors stale | `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` — already in the live file, still latest, do not change |
| 31 | bare `pip install semgrep` | Unpinned | `pip install semgrep==1.177.0` (fallback if PEP 668 bites: `pipx install semgrep==1.177.0`, RESEARCH A7) |
| 34, 38 | `--config auto`, two separate Semgrep runs, `--json`/`--sarif` bare flags | `auto` is a hard error with `--metrics=off`; bare format flags are mutually exclusive (Pitfalls 1-2) | One run: `semgrep scan --config p/default --metrics=off --error --json-output=… --sarif-output=… .` |
| 41, 76, 162 | `github/codeql-action/upload-sarif` | Silently fails without `security-events: write` — Phase 17 | Omit entirely; prove file existence with an `ls -l` evidence step |
| 47-53, 82-88, 109-115, 167-173, 197-203 | `actions/upload-artifact` blocks | Retention is Phase 17 (CICD-03) | Optional; if kept, pin `@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1` |
| 101-104 | `curl -sSfL … install.sh \| sh` (Grype) | Semgrep's own `p/default` flags this as `gha-curl-pipe-shell` at this exact line; and D-05 drops Grype | Trivy via `aquasecurity/setup-trivy@81e514348e19b6112ce2a7e3ecbafe19c1e1f567  # v0.3.1` with `version: v0.74.0`, `cache: true` |
| 95-107 (whole SCA job) | Grype `dir:.` | D-05: Trivy only | `trivy fs . --scanners vuln --format json --output trivy-fs.json --exit-code 1 --severity HIGH,CRITICAL` then `trivy convert` |
| 128-139 | `Check for Dockerfile` step + `if: steps.dockerfile.outputs.exists == 'true'` guards (repeated at 143, 153, 161, 168) | D-06 removes all branching; a skipped job fails SC#2 | Unconditional `docker build -f fixtures/Dockerfile -t scan-fixture:${{ github.sha }} fixtures/` |
| 144, 154 | `aquasecurity/trivy-action` invoked twice (JSON then SARIF) | Action's `version` default is v0.70.0; no `convert` mode | `setup-trivy` + raw CLI, one `--format json` run + `trivy convert --format sarif` |
| 190-192 | `curl … \| tar xz -C /usr/local/bin` | No integrity check | Download to file → `sha256sum -c` → extract (see Shared Pattern: Checksum-verified binary install) |
| 195 | `gitleaks detect --source .` | `detect` is absent from `--help` on 8.30.1 (undocumented alias, one release from removal) | `gitleaks git . --no-banner --redact --report-format sarif --report-path gitleaks.sarif` |

#### Report-only conversion (D-04) — the placement rule

`continue-on-error: true` goes on the **step**, never the **job**:

| Placement | Step conclusion | Job conclusion | Check color | Phase 18 impact |
|---|---|---|---|---|
| `steps[*].continue-on-error: true` | failure (annotated) | **success** | green | Flipping the flag later restores blocking cleanly |
| `jobs.<id>.continue-on-error: true` | failure | **failure** | **red** | A red check can't cleanly become a required check |

Corollary the planner must enforce in every `run:` block: GitHub's default shell is `bash -e`
and every scanner is *expected* to exit 1. **Never chain two natively-failing commands in one
`run:`.** This bites Gitleaks specifically (no dual-output flag) — it must be two steps, the
second carrying `if: always()`. `continue-on-error` tolerates the step; it does not disable
`-e` inside it.

#### Anti-pattern with a dedicated check

No `needs:` on any of the five jobs. Parallelism is the default; `needs:` is the only way to
break CICD-01 while every job still passes. Static assertion (RESEARCH line 836):

```bash
actionlint repos/security-platform/.github/workflows/security.yml && \
python3 -c "import yaml; w=yaml.safe_load(open('repos/security-platform/.github/workflows/security.yml')); \
assert len(w['jobs'])==5; assert all('needs' not in j for j in w['jobs'].values())"
```

---

### 2. `.pre-commit-config.yaml` (config, batch — MODIFIED)

**Analog:** itself. The file already establishes the convention — every hook carries an
explicit `types:`/`files:` filter (header comment lines 5-6). `exclude:` is the matching
sibling key and is not yet used anywhere in the file, so there is no in-file precedent for
its indentation: it sits at the same level as `types:`/`files:`, two spaces inside the hook
item.

**Four hooks get `exclude: ^fixtures/`** — hadolint, npm-audit, terraform_fmt,
terraform_validate. Exact target blocks as they exist today:

```yaml
  # --- Terraform: formatting and validation ---     (lines 15-22)
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.105.0
    hooks:
      - id: terraform_fmt
        types: [terraform]
      - id: terraform_validate
        types: [terraform]

  # --- Dockerfile: hadolint ---                     (lines 41-46)
  - repo: https://github.com/hadolint/hadolint
    rev: v2.14.0
    hooks:
      - id: hadolint
        types: [dockerfile]

  # --- npm: lightweight dependency audit ---        (lines 74-82)
  - repo: local
    hooks:
      - id: npm-audit
        name: npm audit
        entry: npm audit --audit-level=high
        language: system
        files: package-lock\.json$
        pass_filenames: false
```

**Do NOT touch the Gitleaks block (lines 91-98).** It is `stages: [pre-push]` and scans the
diff; no fixture file contains a secret, so it never fires. See Decision Conflicts.

The exact annotated diff — including the rationale comment for each `exclude:` — is in
`15-RESEARCH.md` §Code Examples lines 682-718. Copy those comments; they carry the
verification evidence (hadolint DL3018, npm-audit `ENOLOCK`).

**Second-order effect the planner must state in the plan:** this file governs every future
commit in the target repo. Excludes must be `^fixtures/`-anchored, never blanket, and never
`SKIP=`/`--no-verify` at commit time (that is the anti-pattern D-03's scoping intent rules out).

---

### 3. `scripts/smoke-scans.sh` (utility, batch — NEW)

**Analog:** `repos/security-platform/workstation/cicd/lint-markdown.sh`

**Header + strict-mode pattern** (lines 1-17):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Lint markdown files using markdownlint-cli2.
# Installs markdownlint-cli2 via npx if not available.
#
# Usage:
#   bash scripts/lint-markdown.sh                    # lint *.md in current directory
#   bash scripts/lint-markdown.sh -r                 # lint *.md recursively
```

Same shape in `workstation/setup.sh` lines 1-18 (shebang, `set -euo pipefail`, purpose block,
`Usage:` block invoking via `bash …`, never `./…`).

**Placement is a planner call — and RESEARCH.md assumes the outer repo.** The smoke block
at RESEARCH lines 845-879 opens with `cd repos/security-platform`, an **outer-repo** path. If
the script lands in the target repo (recommended — it ships with the thing it tests, and the
`shellcheck` pre-commit hook then covers it), that `cd` is wrong. Either way, replace the
literal `cd` with the repo-root idiom already used in-repo (`lint-markdown.sh:19`):

```bash
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
```

**TRAP — `set -e` and expected-failure scanners.** Every one of the five smoke commands is
*expected* to exit 1 (that is the SC#2 assertion). Under `set -euo pipefail`,
`semgrep … ; echo "exit=$?"` aborts the script at semgrep and the remaining four never run.
This is the same failure class as the workflow's "never chain two natively-failing commands"
rule. The planner must specify one of:

```bash
rc=0; semgrep scan … || rc=$?; echo "semgrep exit=$rc"     # preferred — keeps set -e elsewhere
```

or a narrowly scoped `set +e` / `set -e` pair around the scanner block. The in-repo precedent
for tolerating a known-failing command is `lint-markdown.sh:53` (`… --fix "$PATTERN" … || true`)
and `setup.sh:325` (`|| true`) — but `|| true` discards the exit code the smoke test needs to
assert, so prefer `|| rc=$?`.

**Shellcheck-suppression comment convention** (when needed), from `lint-markdown.sh:52` and
`setup.sh:331`:

```bash
# shellcheck disable=SC2086
# shellcheck disable=SC2329  # invoked by _install_gitleaks, _install_hadolint
```

(The `shellcheck` pre-commit hook, `types: [shell]`, will run on this file — it is not in
`fixtures/`, so it is not excluded.)

**Project rule — no executable bit.** Per `.claude/rules/defensive-protocol-v2-anti-slop.md`
§Script Safety: never `chmod +x`; always invoke as `bash scripts/smoke-scans.sh`. The shebang
is documentation only. Both in-repo scripts follow this (`README.md:36` invokes
`bash path/to/…/setup.sh`).

**Contents:** the smoke block with expected results is `15-RESEARCH.md` lines 845-879.

---

### 4. `fixtures/README.md` (documentation — NEW)

**Analog:** `repos/security-platform/cicd/README.md` and the root `README.md`

Root `README.md` conventions to mirror (lines 1-6, 22-29): `# <name>` H1, one-paragraph
purpose, `## Structure` fenced tree, `## <topic>` tables with `|---|---|---|` separators.

**Lint constraints (verified from config, not assumed):** the `markdownlint` pre-commit hook
(`types: [markdown]`, line 57-61) runs on this file — `fixtures/` exclusion is **not** applied
to it (only the four hooks above). `.markdownlint.jsonc` disables `MD013`, `MD024`, `MD036`,
`MD040`, `MD060`, `line-length`, so long lines and bare (unlabeled) code fences are fine.

**Required content** (RESEARCH §Security Domain, "Fixture vulnerabilities mistaken for real
exposure"): state that every file in `fixtures/` is intentionally vulnerable, must not be
fixed, must never be installed or deployed, and exists solely as scanner input. Mirror the
in-file banner used by the fixture sources themselves:
`# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"`.

---

## Shared Patterns

### SHA-pin comment convention (applies to every `uses:` line in `security.yml`)

**Source:** `repos/security-platform/.github/workflows/security.yml:20` (live, Phase 14) and
`cicd/.github/workflows/security.yml:30,144` (older precedent). Mandated by ADR-004.

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
```

Rules, from `14-01-PLAN.md`: full 40-char commit SHA, **two spaces** before `#`, version
comment on the **same line** as `uses:` (Dependabot only rewrites same-line comments).
Verification regex the prior plan used: `<action>@<40-hex>[[:space:]]+# v<version>`.

Pins resolved for this phase (RESEARCH §Standard Stack lines 204-210):

| Action | Pin |
|---|---|
| `actions/checkout` | `@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` |
| `aquasecurity/setup-trivy` | `@81e514348e19b6112ce2a7e3ecbafe19c1e1f567  # v0.3.1` |
| `bridgecrewio/checkov-action` | `@a8664e3a0549367977f0cda990a34311835c87c0  # v12.3123.0` |
| `actions/upload-artifact` (optional) | `@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1` |

Worth one inline comment: the checkov-action SHA pin protects the *action*, but the action then
pulls `ghcr.io/bridgecrewio/checkov:3.3.17` by **mutable tag**. ADR-004's guarantee stops at the
action boundary — documented residual risk, not solved this phase.

### Checksum-verified binary install (applies to the Gitleaks step)

**Source:** `repos/security-platform/workstation/setup.sh` — this repo already rejects
`curl | sh` in its own tooling. The CI step is the Actions-flavored port of this.

`verify_sha256()` (lines 331-351):

```bash
# shellcheck disable=SC2329  # invoked by _install_gitleaks, _install_hadolint
verify_sha256() {
  local file="$1" expected="$2"
  local actual

  if command -v sha256sum > /dev/null 2>&1; then
    actual="$(sha256sum "$file" | cut -d' ' -f1)"
  elif command -v shasum > /dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  else
    err "No sha256sum or shasum found; cannot verify checksum"
    return 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    err "Checksum mismatch for $file"
    err "  Expected: $expected"
    err "  Actual:   $actual"
    return 1
  fi
}
```

`_install_gitleaks()` (lines 437-465) — download-then-verify-then-extract, never piped:

```bash
_install_gitleaks() {
  ...
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/gitleaks.XXXXXX")"
  trap 'rm -rf "$tmpdir"' RETURN

  curl -sfL -o "$tmpdir/gitleaks.tar.gz" "$url"
  curl -sfL -o "$tmpdir/checksums.txt" "$checksums_url"

  expected_hash="$(grep "gitleaks_${GITLEAKS_VERSION}_${os}_${arch}.tar.gz" "$tmpdir/checksums.txt" | cut -d' ' -f1)"
  ...
  verify_sha256 "$tmpdir/gitleaks.tar.gz" "$expected_hash"
  tar -xzf "$tmpdir/gitleaks.tar.gz" -C "$tmpdir"
```

CI equivalent (RESEARCH lines 581-587; hash `[VERIFIED: gh api releases/tags/v8.30.1 assets +
published checksums file]`):

```yaml
      - name: Install Gitleaks
        run: |
          curl -sSfL -o gitleaks.tar.gz \
            https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
          echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks.tar.gz" \
            | sha256sum -c -
          sudo tar xzf gitleaks.tar.gz -C /usr/local/bin gitleaks
```

### One scan → both output formats (applies to SAST, IaC, SCA, Container)

Never run a tool twice (the reference does this for Semgrep at lines 34/38 and Trivy at
144/154 — doubles runtime, re-pulls the DB, risks JSON/SARIF disagreement).

| Tool | Single-run dual output |
|---|---|
| Semgrep | `--json-output=x.json --sarif-output=x.sarif` in one `scan` |
| Checkov | `--output json --output sarif --output-file-path console,ckv.json,ckv.sarif` (the action's `output_format`/`output_file_path` keys, already in the analog `with:` block) |
| Trivy | `--format json -o x.json`, then a separate `trivy convert --format sarif -o x.sarif x.json` step with `if: always()` |
| Gitleaks | **No dual-output flag** — two separate steps, second with `if: always()` + `continue-on-error: true` |

### Evidence step (applies to all five jobs — satisfies SC#4)

Because `upload-sarif` and artifact retention are deferred, the only proof the files exist is
a terminal step in each job:

```yaml
      - name: Show scan output files
        if: always()
        run: ls -l <json> <sarif>
```

`if: always()` is mandatory — the scan step is expected to have "failed" under D-04. This step
is also the deliberate counterweight to the anti-slop rule against silent fallbacks: an empty
or missing report fails loudly instead of reading as "clean."

### Comment-density convention (applies to every file this phase touches)

Both workflow files and `.pre-commit-config.yaml` carry a purpose header and per-section
rationale comments explaining *why*, with phase/ADR references (`# All third-party actions are
pinned to full commit SHAs (ADR-004)`, `# Bypass: git push --no-verify skips this hook — CI is
the compensating control`). Every non-obvious choice in the new workflow — `p/default` over
`auto`, `git` over `detect`, `fetch-depth: 0`, unconditional container build, step-level
`continue-on-error` — needs an inline comment naming the decision (D-0x) or pitfall it encodes.
Chesterton's Fence applies in reverse here: the next phase must be able to tell which flags are
load-bearing.

---

## No Analog Found

The target repo has **no** Dockerfile, `.tf`, or `package*.json` anywhere
(`git ls-files` confirms 21 tracked files; `find` for those patterns returns nothing). All four
fixture artifacts are greenfield — use RESEARCH's measured content, not invention.

| File | Role | Data Flow | Reason / Source to use |
|---|---|---|---|
| `fixtures/Dockerfile` | fixture | file-I/O | No Dockerfile exists in the repo. Content: RESEARCH §Code Examples lines 612-619. **C-1 overrides D-02's literal wording** — an EOL base (`alpine:3.14`) yields **0** findings; use `public.ecr.aws/docker/library/debian:12-slim` **pinned by digest** (222 vulns, 4 CRITICAL / 52 HIGH, measured 2026-09-10) |
| `fixtures/main.tf` | fixture | file-I/O | No `.tf` exists. Content: RESEARCH lines 627-654. **C-2:** the old provider pin alone yields **0** Checkov findings; the misconfigured `aws_s3_bucket` + `aws_security_group` resources are what make the IaC job non-empty (12 failed checks measured). Keep the old provider pin anyway — it seeds Phase 16 / SCA-03 |
| `fixtures/package.json` | fixture | file-I/O | No npm project exists. Content: RESEARCH lines 660-671 (`lodash@4.17.15`, `minimist@1.2.0`) |
| `fixtures/package-lock.json` | fixture (generated) | file-I/O | **Do not hand-write** — `cd fixtures && npm install --package-lock-only --ignore-scripts --no-audit --no-fund`. `--ignore-scripts` is the supply-chain control; deps are never installed in CI (Trivy parses the lock statically) |

Skills check: `.claude/skills/` contains 9 skills (cdk-testing, create-prd, itsg/nist/fedramp
assessments, occ-skill-creator/refactor, rule-creator, terraform-testing); `.agents/skills/`
does not exist. None supply CI-workflow patterns. **`terraform-testing` must NOT be invoked on
`fixtures/main.tf`** — it runs `terraform init/validate/plan` against real infrastructure code,
which is exactly what `exclude: ^fixtures/` on `terraform_validate` exists to prevent.

---

## Decision Conflicts the Planner Must Resolve Explicitly

These are surfaced, not resolved. Each is a locked CONTEXT decision contradicted by verified
research. Do not let a plan silently pick a side.

| # | CONTEXT says | RESEARCH verified | Recommendation |
|---|---|---|---|
| 1 | **D-03:** scope a `.gitleaksignore` entry / hook `exclude:` for `fixtures/` | **C-3:** unnecessary (no secret is seeded; `gitleaks dir` → 0 findings, exit 0) **and** mechanically wrong (`.gitleaksignore` takes *fingerprints* — `file:rule-id:start-line` — not path globs; a path allowlist needs `.gitleaks.toml`, which would also blind the CI secrets job) | **Make no Gitleaks config change.** D-03's *scoping intent* is honored by the four `exclude: ^fixtures/` entries (C-4). Document the fingerprint-vs-path distinction so Phase 18 doesn't rediscover it |
| 2 | **D-02:** Dockerfile `FROM` an **old** base image with known CVEs | **C-1:** EOL distros have no advisory feed → 0 findings, violating SC#2 | Use a **currently supported** distro with unpatched CVEs (`debian:12-slim`, digest-pinned). Preserves D-02's intent, contradicts its literal wording — flag to the user if the wording is binding |
| 3 | **D-02:** unpinned/old Terraform provider version | **C-2:** provider pins are invisible to Checkov → 0 findings | Keep the old pin **and** add misconfigured resources |
| 4 | Pitfall 7 (RESEARCH 426-431): `--severity HIGH,CRITICAL` filters the **report file**, not just the exit code | Deliberate: D-04 says preserve the reference's native severity semantics (`severity: 'HIGH,CRITICAL'` at analog line 150) | Keep the filter, and carry a note into Phase 17: DefectDojo may want full-severity data. **Do not "fix" it silently in Phase 15** |
| 5 | — | `versions.conf` pins `TRIVY_VERSION="0.69.3"`, `GITLEAKS_VERSION="8.30.0"`; the workflow will pin Trivy `v0.74.0` / Gitleaks `8.30.1`; `.pre-commit-config.yaml:95` pins gitleaks hook `v8.30.0` | `versions.conf` is the **workstation** SSOT and is *generated by `setup.sh`* — editing it by hand is out of scope and would be overwritten. Recommend: leave it, note the CI-vs-workstation version split explicitly in the workflow header or plan, and let a later phase decide whether the two should converge |

---

## Metadata

**Analog search scope:**
`repos/security-platform/` (all 21 tracked files enumerated via `git ls-files`),
`repos/security-platform/.github/workflows/`, `repos/security-platform/cicd/`,
`repos/security-platform/workstation/`, `.planning/phases/14-*/` (plan conventions),
`.claude/skills/` (9 skill frontmatters), root `CLAUDE.md` + `.claude/rules/`.

**Files scanned:** 14 read in full or by targeted range —
`cicd/.github/workflows/security.yml` (203 L),
`.github/workflows/security.yml` (20 L), `.github/workflows/pr-security.yml` (17 L),
`.pre-commit-config.yaml` (98 L), `.github/dependabot.yml`, `.gitignore`, `.gitleaksignore`,
`versions.conf`, `README.md`, `.markdownlint.jsonc`, `.markdownlint-cli2.yaml`,
`workstation/cicd/lint-markdown.sh` (61 L), `workstation/setup.sh` (3 targeted ranges),
`14-01-PLAN.md` (frontmatter + context block).

**`find` negative results (load-bearing):** no `Dockerfile*`, no `*.tf`, no `package*.json`
anywhere in the target repo — the four fixture files are genuinely greenfield.

**Pattern extraction date:** 2026-09-10
