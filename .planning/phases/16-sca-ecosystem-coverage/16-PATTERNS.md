# Phase 16: SCA Ecosystem Coverage - Pattern Map

**Mapped:** 2026-09-10
**Files analyzed:** 5 certain (1 modified workflow, 1 modified script, 2 modified fixtures, 1 new fixture) + 3 candidate detector scripts + 3 conditional outer-repo docs + 5 explicitly NOT modified
**Analogs found:** 9 / 10 (only `fixtures/requirements.txt` has no file-level analog; its header-comment convention does)

**Source:** `16-RESEARCH.md` only. **No `16-CONTEXT.md` exists** — `/gsd:discuss-phase` has not been run for this phase. Every "Open Decision" below is therefore genuinely open and must not be silently resolved by the planner.

## Path Convention (read this first)

The implementation lands in the **target repo**, an independent git repo checked out at
`repos/security-platform/` (remote `OttawaCloudConsulting/security-platform`). `repos/` is
gitignored by the outer docs repo.

| In this document | Means |
|---|---|
| Paths starting `.github/`, `fixtures/`, `scripts/`, `cicd/`, `versions.conf` | **Target repo** root — what CI checks out |
| Paths starting `repos/security-platform/` | The same files as seen from the outer repo (how you `Read` them locally) |
| Paths starting `docs/adr/`, `docs/development-security-stack-option-1.md` | **Outer docs repo** (this repo) — documentation only, no CI effect |

`fixtures/` = `repos/security-platform/fixtures/`. Nothing in this phase is created in the outer docs repo except `.planning/**` and (conditionally, see A1) one new ADR file.

---

## File Classification

| File (target-repo relative unless noted) | New/Mod | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| `.github/workflows/security.yml` — `sca` job install steps | MODIFIED | config / CI orchestration | request-response (tool install) | same file, `sast` job L29-32 (pip install) and `secrets` job L158-166 (download+checksum+extract) | **exact** (pip) / **shape-only** (tflint — `.zip`, not `.tar.gz`) |
| `.github/workflows/security.yml` — 3 detect steps | MODIFIED | config / CI guard | event-driven (bash → `$GITHUB_OUTPUT`) | `cicd/.github/workflows/security.yml:128-136` (`Check for Dockerfile`) | **shape-only — see Analog Warning** |
| `.github/workflows/security.yml` — 3 sub-scan run steps | MODIFIED | config / CI orchestration | batch (per-input iteration, exit-code capture) | same file, `secrets` job L168-184 (two-invocation split, `if: always()` + `continue-on-error`) | **role-match** |
| `.github/workflows/security.yml` — `Show scan output files` | MODIFIED | config | file-I/O | `cicd/.github/workflows/security.yml:153,161,168` (`if: always() && steps.X.outputs.exists == 'true'`) | **exact** — and it is a *required* fix, not optional (see Shared Pattern 4) |
| `scripts/smoke-scans.sh` | MODIFIED | utility / test harness | batch (sequential CLI, exit-code capture) | itself — `run_scan` L22-41, `require_nonempty` L61-71, preflight L73-80, explicit rc capture L130-132 | **exact** |
| `fixtures/requirements.txt` | **NEW** | fixture / test data | file-I/O (scan input) | none as a file; header convention from `fixtures/package.json:5` + `fixtures/main.tf:1-4` | **no analog (convention-match only)** |
| `fixtures/main.tf` | MODIFIED (additive) | fixture / test data | file-I/O (scan input) | itself — L5-12 `terraform{}`/`required_providers`, L14-26 resource blocks | **exact** |
| `fixtures/README.md` | MODIFIED | documentation | n/a | itself — tree L10-17, count table L21-25, pre-commit section L30-42 | **exact** |
| `scripts/detect-npm.sh`, `detect-python.sh`, `detect-terraform.sh` | **CANDIDATE — NEW** | utility / shared guard | event-driven (stdout + `$GITHUB_OUTPUT`) | `scripts/smoke-scans.sh:1-2` (shebang + `set -euo pipefail`) | **role-match** — existence is an **open decision**, see Open Decision 1 |
| `docs/adr/adr015-<kebab-title>.md` *(outer repo)* | **CONDITIONAL — NEW** | documentation / decision record | n/a | `docs/adr/adr013-falco-runtime-detection.md` | **exact** — conditional on Assumption A1 |
| `docs/adr/README.md` *(outer repo)* | CONDITIONAL — MODIFIED | documentation | n/a | itself — index table, one row per ADR | **exact** — same condition |
| `.pre-commit-config.yaml` | **NOT MODIFIED** | config | n/a | n/a | **No hook matches `requirements.txt`** — `ruff` is `types_or: [python, pyi]`; the `npm-audit` hook (L82-91) is `files: package-lock\.json$`. No new `exclude: ^fixtures/` needed. [filter list re-measured this session — see Metadata] |
| `.github/workflows/pr-security.yml` | **NOT MODIFIED** | config | event-driven | n/a | Permissions widening to `security-events: write` is **Phase 17 (CICD-02)**, not this phase. A called workflow cannot self-elevate. |
| `security.yml` jobs `sast`/`iac`/`container`/`secrets` | **NOT MODIFIED** | config | n/a | n/a | Phase 16 touches **only** the `sca` job. Job count must remain exactly 5 with zero `needs:`. |
| `versions.conf` / `workstation/setup.sh` | **NOT MODIFIED (per A2) — but contested** | config | n/a | n/a | See Open Decision 3. `versions.conf` is generated by `setup.sh`; hand-editing is out of scope (same ruling as 15-PATTERNS.md). |
| `fixtures/package.json` / `package-lock.json` | **NOT MODIFIED** | fixture | n/a | n/a | Already measured to produce 2 npm-audit findings (1 high `lodash`, 1 critical `minimist`). No regeneration needed. |
| `docs/development-security-stack-option-1.md` *(outer repo)* | **CONDITIONAL — MODIFIED** | documentation | n/a | its own tool coverage matrix | Conditional on A1 + Q4. CLAUDE.md requires preserving ASCII diagrams and matrix structure. Keep in a **separate plan** from the workflow change. |

---

## Analog Warning — `cicd/.github/workflows/security.yml` is shape-only (again, for new reasons)

Phase 15 already ruled this file "a shape to follow, not a source to copy" because its commands were stale. Phase 16 must reuse its **detect-then-guard idiom** (that is the whole point of citing it — the pattern is the project's own precedent, not an invention), but three of its concrete details are wrong here:

| Detail at `cicd/.../security.yml` | Why it cannot be copied for Phase 16 |
|---|---|
| `if [ -f Dockerfile ]` (L131) | Root-anchored single-file test. RESEARCH Pitfall 9 measured that detection must use `git ls-files -- '*package-lock.json'` / `'*requirements*.txt'` / `'*.tf'` — a **leading-wildcard pathspec**, because `requirements*.txt` misses subdirectories and `**/requirements*.txt` misses the repo root. |
| Output key `exists=` (L132/134) | Cosmetic, but RESEARCH's code examples standardise on `found=`. Pick one and use it for all three detectors; do not mix. |
| Logs **only on the skip path** (L135) | Criterion 4 requires a clear log line either way, and the smoke gate's positive path needs a `FOUND …` line to assert on. Both branches must echo. |
| `curl … | sh -s --` Grype install at L101-104 (directly above the block you are copying from) | **Never copy.** The SAST job's own `p/default` ruleset flags `gha-curl-pipe-shell`. Use the `secrets` job's download→checksum→extract form instead. |

**Authoritative command source:** `16-RESEARCH.md` §Code Examples (L444-566) and §Standard Stack install block (L86-95). Every exit code, rule ID, and pathspec there was measured locally this session.

---

## Pattern Assignments

### 1. `.github/workflows/security.yml` — `sca` job (config, event-driven — MODIFIED)

**Job being modified** (`repos/security-platform/.github/workflows/security.yml:76-106`). Its current full text is the envelope you extend — banner comment, checkout, setup-trivy, run, convert, show:

```yaml
  # ─────────────────────────────────────────────────────────────────────────
  # SCA — Trivy Filesystem
  # SCA-04: generic filesystem sweep, no per-ecosystem configuration.
  # ─────────────────────────────────────────────────────────────────────────
  sca:
    name: SCA — Trivy Filesystem          # L81 — see Open Decision 4 (rename?)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
      - uses: aquasecurity/setup-trivy@81e514348e19b6112ce2a7e3ecbafe19c1e1f567  # v0.3.1
        with:
          version: v0.74.0
          cache: true
```

Keep the banner-comment style (box-drawn rule, job title, requirement ID, one-line rationale) when adding the new sub-scan sections. Keep the `# vN.N.N` trailing comment on every SHA (ADR-004).

---

**Analog A — pip-based tool install** (`.github/workflows/security.yml:29-32`, `sast` job). Copy verbatim, swap the package:

```yaml
      - run: pip install semgrep==1.177.0
      # Assumption A7 fallback ladder if PEP 668 blocks the pip install above:
      #   1) pipx install semgrep==1.177.0   (pipx is preinstalled on GitHub-hosted ubuntu-latest)
      #   2) python -m pip install --break-system-packages semgrep==1.177.0
```

→ becomes `pip install pip-audit==2.10.1` with the same two-line fallback comment. **No `actions/setup-python`** — Python 3.12.3/pip 24.0 are preinstalled (RESEARCH §Standard Stack, verified against both runner readmes). Likewise **no `actions/setup-node`** for SCA-01 — npm 10.9.8 is preinstalled.

---

**Analog B — checksum-verified binary install** (`.github/workflows/security.yml:158-166`, `secrets` job). **Shape-only:** the final line changes because tflint ships `.zip`:

```yaml
      # Download-then-verify-then-extract, never curl | sh — the SAST job's own
      # p/default ruleset (gha-curl-pipe-shell) flags the pipe pattern.
      - name: Install Gitleaks
        run: |
          curl -sSfL -o gitleaks.tar.gz \
            https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
          echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks.tar.gz" \
            | sha256sum -c -
          sudo tar xzf gitleaks.tar.gz -C /usr/local/bin gitleaks
```

→ for tflint, keep the comment, keep `curl -sSfL -o` + `sha256sum -c -`, and replace the extract line with `sudo unzip -o -d /usr/local/bin tflint.zip`. The measured SHA-256 for `tflint_linux_amd64.zip` v0.64.0 is in RESEARCH L93: `cca9d13e2e1d7a2c627af60ff899a3c9b74212899416aeb96ec764d2ef954537`. `unzip` is preinstalled. Do **not** substitute `terraform-linters/setup-tflint` without a user decision (RESEARCH §Alternatives records its SHA `1cf010d3c7aef302051ccdb68c14c5dc2efa34ef` in case the user prefers it).

---

**Analog C — detect-then-guard** (`cicd/.github/workflows/security.yml:128-140`). This is the idiom; see the Analog Warning for the three details that must change:

```yaml
      - name: Check for Dockerfile
        id: dockerfile
        run: |
          if [ -f Dockerfile ]; then
            echo "exists=true" >> "$GITHUB_OUTPUT"
          else
            echo "exists=false" >> "$GITHUB_OUTPUT"
            echo "No Dockerfile found — skipping container scan"
          fi

      - name: Build container image
        if: steps.dockerfile.outputs.exists == 'true'
        run: docker build -t app:${{ github.sha }} .
```

The Phase 16 form (RESEARCH L449-460, L495-508, L545-554) replaces the file test with `git ls-files -- '<leading-wildcard-pathspec>'`, echoes on **both** branches (`SKIP: …` / `FOUND N …`), and writes the discovered paths to a scratch list file that the run step iterates.

**Anti-pattern, stated in the workflow's own comments** (`security.yml:168-172`): do not put detection and scan in one `run:` block. Default shell is `bash -e`; every scanner here is *expected* to exit non-zero under D-04.

---

**Analog D — a tool with no dual-output flag → two steps** (`.github/workflows/security.yml:168-184`, `secrets` job). This is the analog for tflint (RESEARCH Pitfall 6: `--format sarif` writes to **stdout**, there is no `-o`):

```yaml
      # `git`, never the deprecated `detect` subcommand and never `dir`.
      # No dual-output flag exists, so this is TWO steps rather than one chained
      # run: block — GitHub's default shell is bash -e, every scanner here is
      # *expected* to exit 1 under D-04, and a two-command run: would silently
      # drop the second command once the first exits non-zero.
      - name: Run Gitleaks (SARIF)
        continue-on-error: true          # D-04
        run: |
          gitleaks git . --no-banner --redact \
            --report-format sarif --report-path gitleaks.sarif

      - name: Run Gitleaks (JSON)
        if: always()                     # previous step exits 1 on findings
        continue-on-error: true          # D-04
        run: |
          gitleaks git . --no-banner --redact \
            --report-format json --report-path gitleaks-results.json
```

→ For tflint: step 1 `tflint --recursive --format sarif > tflint.sarif`, step 2 (human-readable log) `tflint --recursive --format default`, gated `if: always() && steps.tf.outputs.found == 'true'`. **Prefer this two-step form over RESEARCH's single-block example at L559-562** — that snippet chains two commands after an `|| rc=$?` capture whose `rc` is never used, which is exactly the shape the comment above warns against. `--recursive` is mandatory (Pitfall 5: a repo-root `tflint` sees zero `.tf` files and exits 0 — a silent false pass).

**tflint exit codes (measured):** 0 = clean, **2 = findings**, 1 = application error. This inverts the assumption baked into `smoke-scans.sh` (see file 2).

---

**Analog E — per-input iteration** (no in-repo analog; RESEARCH Pattern 3, L237-243). `npm audit` operates on a working directory, not a named file, so it must `cd` per lockfile and write numbered reports `npm-audit-1.json`, `npm-audit-2.json`, …. Consequence the planner must carry forward: **Phase 17's artifact upload cannot assume fixed filenames.**

---

### 2. `scripts/smoke-scans.sh` (utility / test harness, batch — MODIFIED)

**Analog: itself.** Four existing helpers define the house style; the new work generalises two of them and adds two.

**Existing `run_scan` — hard-codes rc=1 as PASS** (`scripts/smoke-scans.sh:22-41`):

```bash
# run_scan: capture a scanner's exit code without tripping `set -e`. Exit
# code 1 is the expected PASS (a real finding was made). Exit code 0 means
# the tool found nothing — the exact failure this script exists to catch.
# Anything else is a tool/infrastructure error, not a scan verdict.
run_scan() {
  local label="$1"
  shift
  local rc=0
  "$@" || rc=$?
  if [[ "$rc" -eq 1 ]]; then
    echo "==> ${label}: exit=${rc} (PASS - finding(s) detected)"
  elif [[ "$rc" -eq 0 ]]; then
    echo "==> ${label}: exit=${rc} (FAIL - scanner found nothing)"
    FAILURES+=("${label}: scanner exited 0 (no findings)")
  else
    echo "==> ${label}: exit=${rc} (FAIL - tool/infrastructure error)"
    FAILURES+=("${label}: scanner exited ${rc} (tool/infrastructure error)")
  fi
  return 0
}
```

→ Generalise to `run_scan_rc <expected_rc> <label> <cmd…>` (RESEARCH Pitfall 4): tflint's finding exit code is **2**, so the current helper would score a healthy tflint run as "tool/infrastructure error." Keep `run_scan` as a thin wrapper (`run_scan_rc 1 "$@"`) or re-point the six existing call sites (L87, L106, L145, L176, L202, L205 — Gitleaks calls it twice). Preserve the message format `==> ${label}: exit=${rc} (PASS|FAIL - reason)` verbatim — 15-05 records that mixing up `run_scan` vs `require_success` "inverted their pass/fail verdict during first live test."

**Existing `require_nonempty` — the shape for the new `require_parses_json`** (`scripts/smoke-scans.sh:61-71`):

```bash
# require_nonempty: assert a report file exists and has non-zero size.
require_nonempty() {
  local label="$1"
  local file="$2"
  if [[ -s "$file" ]]; then
    echo "    report OK: ${file} ($(wc -c <"$file" | tr -d ' ') bytes)"
  else
    echo "    report MISSING/EMPTY: ${file}"
    FAILURES+=("${label}: report missing or empty (${file})")
  fi
}
```

→ `require_parses_json <label> <file> <required_key>` follows **this** shape (push to `FAILURES`), **not** the informational `python3 -c "…" || true` print blocks at L93-101 / L111-125 / L150-161. Those `|| true` blocks exist to print counts; an assertion that swallows its own failure with `|| true` *is* the false-pass mechanism Criterion 4 and the anti-slop rule forbid. RESEARCH Pattern 2: npm audit's error object is `{"error":{"code":"ENOLOCK",…}}` where a real report has `auditReportVersion`; pip-audit writes **no file at all** on its error paths, so `[ -s file ]` discriminates there.

**Existing explicit rc capture for a redirect** (`scripts/smoke-scans.sh:130-132`) — the analog for tflint's stdout redirect under `set -euo pipefail`:

```bash
rc=0
trivy fs . --scanners vuln --format json -o "$OUT/trivy-fs-all.json" || rc=$?
echo "==> trivy-fs-unfiltered: exit=${rc} (not gated, informational only)"
```

**Existing preflight loop** (`scripts/smoke-scans.sh:73-80`) — extend with `npm`, `pip-audit`, `tflint`, but see Open Decision 3 first:

```bash
for bin in semgrep checkov trivy gitleaks docker python3; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 1
  fi
done
```

**Section shape to copy for each new sub-scan** (`scripts/smoke-scans.sh:85-102`): `echo "--- <NAME> ---"` → `run_scan…` → `require_nonempty` (+ new `require_parses_json`) → `python3 -c` count print → blank `echo`.

**Stale strings that must be updated in the same edit:** header comment L4-9 ("the five Phase 15 CI scan jobs") and the summary line L227 (`"ALL PASS - all five scanners produced real, non-empty findings."`).

**Negative/skip test block** (RESEARCH L568-583) — no in-repo analog; appends to `FAILURES` in the established way. Note it invokes `bash "$REPO_ROOT/scripts/detect-<probe>.sh"`, which presumes Open Decision 1 is resolved toward extracted scripts.

**bash version constraint (Pitfall 10):** the existing script is bash-3 compatible (`FAILURES+=()` only). Introducing `mapfile -t` raises its minimum to bash 4 — `/bin/bash` on this workstation is 3.2.57. Either accept that (the script already declares `#!/usr/bin/env bash` and the project rule mandates `bash scripts/…`, never `./` and never `sh`), or use `while read -r` instead of `mapfile` in shared code. CI runners are bash 5.x, so workflow-inline `mapfile` is safe.

---

### 3. `fixtures/requirements.txt` (fixture / test data, file-I/O — NEW)

**No file analog.** The convention analog is the fixture header comment, which every fixture carries:

`fixtures/package.json:5`:
```json
  "description": "INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT FIX OR INSTALL",
```

`fixtures/main.tf:1-4`:
```hcl
# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"
# Old provider pin: satisfies D-02 and seeds Phase 16 / SCA-03.
# NOTE: the provider pin alone produces ZERO Checkov findings. The misconfigured
# resources below are what make the IaC job non-empty (see RESEARCH C-2).
```

→ `requirements.txt` supports `#` comments; open with the same DO-NOT-FIX-OR-INSTALL line plus a note that nothing ever installs this file. Pin exact old versions with `==` (RESEARCH measured `requests==2.19.1` + friends → 39 vulns; a 3-package old-pin file also yielded 11 Trivy pip vulnerabilities). Exact `==` pins also keep the `--no-deps --disable-pip` fast path viable if Open Decision 2 goes that way.

**Second-order effect:** this file raises the **SCA-04 Trivy fs** finding count. `fixtures/README.md`'s measured-count table must be re-measured in the same commit or it becomes stale documentation.

---

### 4. `fixtures/main.tf` (fixture / test data, file-I/O — MODIFIED, additive only)

**Analog: itself** (`fixtures/main.tf:5-26`):

```hcl
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
```

**Chesterton's Fence (project rule, and RESEARCH says so explicitly): keep the `3.74.0` pin.** It exists for D-02 and the Phase 15 Checkov baseline depends on the file's current content. The change is **additive**:

1. A provider in `required_providers` with **no `version` key** — *and a resource that actually uses it*. Measured consequence (Pitfall 3, consequence 1): `terraform_required_providers` only fires when the provider is used by a resource in the module; with `required_providers` declared but unused, a different rule (`terraform_unused_required_providers`) fires instead under the `all` preset.
2. A module block with an unpinned source — registry module with no `version` (→ `terraform_module_version`) or a git source with no ref / a default-branch ref (→ `terraform_module_pinned_source`).

**Measured today, against the file as it stands:** `tflint --chdir=fixtures` → rc=2, **one** issue, `terraform_required_version` (a missing `required_version` block). That is *not* a pinning finding. Criterion 3 is unproven without the additions above. A floating range like `>= 3.0` is **not** flagged by the default ruleset — do not claim coverage the tool does not provide (Open Question Q1).

**Second-order effect (A7, measured):** Checkov `CKV_TF_1`/`CKV_TF_2` **will** fire on the new unpinned module block, so the IaC job's failed-check count rises above the documented 10. Additive, not a regression — but re-measure.

---

### 5. `fixtures/README.md` (documentation — MODIFIED)

**Analog: itself.** Three regions need edits, all with an existing shape to match.

Structure tree (`fixtures/README.md:10-17`) — add a `requirements.txt` line in the same aligned-comment style, and update L14's `main.tf` description (it currently says "old AWS provider pin + misconfigured S3 bucket/security group"):

```
fixtures/
├── README.md            # This file
├── Dockerfile            # Container-scan target: digest-pinned debian:12-slim with unpatched CVEs
├── main.tf               # IaC-scan target: old AWS provider pin + misconfigured S3 bucket/security group
├── package.json          # SCA-scan target: vulnerable lodash + minimist pins
└── package-lock.json     # Generated lockfile — never hand-write this file
```

Measured-count table (`fixtures/README.md:21-25`) — **add rows and re-measure existing ones**:

```markdown
| File | Consuming Job | Measured Finding Count (2026-09-10) |
|---|---|---|
| `Dockerfile` | Container scan (Trivy image) | 222 vulnerabilities (4 CRITICAL, 52 HIGH) |
| `main.tf` | IaC scan (Checkov) | 10 failed terraform checks |
| `package.json` + `package-lock.json` | SCA scan (Trivy fs) | 9 npm vulnerabilities |
```

Rows affected: `main.tf` (Checkov count rises — A7), `package-lock.json` (new npm-audit consumer: 1 high + 1 critical), plus new rows for `requirements.txt` (pip-audit + Trivy fs) and `main.tf` under tflint. Keep the existing caveat sentence at L27-28 ("Counts will drift upward over time…").

Pre-commit scoping section (`fixtures/README.md:30-42`) — state that **no hook fires on `requirements.txt`**, so the four-hook exclusion list is unchanged. That is a verified negative worth recording so a later reader does not "fix" it.

---

### 6. `scripts/detect-{npm,python,terraform}.sh` (utility / shared guard — CANDIDATE NEW; see Open Decision 1)

**Analog: `scripts/smoke-scans.sh:1-2`**:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Project rule (`.claude/rules/defensive-protocol-v2-anti-slop.md`): **never set the executable bit**; always invoke as `bash scripts/detect-npm.sh`. Shebang is documentation only.

**Trap if these scripts are shared between CI and the smoke gate:** a script that writes `>> "$GITHUB_OUTPUT"` fails locally where that variable is unset (`set -u`). Either the smoke gate exports `GITHUB_OUTPUT=/dev/null` before calling, or the script guards `[ -n "${GITHUB_OUTPUT:-}" ]`. Whichever is chosen must be consistent across all three scripts.

---

### 7. `docs/adr/adr015-<kebab-title>.md` *(outer repo — CONDITIONAL on A1)*

**Analog: `docs/adr/adr013-falco-runtime-detection.md`.** Note the **filename convention is lowercase `adrNNN-kebab-title.md`** — not `ADR-015-…`. Header shape:

```markdown
# ADR-013: Add Falco CE + FalcoSidekick for Kubernetes Runtime Anomaly Detection

**Status:** Accepted
**Date:** 2026-02-26
**Addresses:** Known Gap — Security Logging, Monitoring, and SIEM

## Context
…
## Decision
…
## Consequences

**Improved:** …
**Tradeoff:** …
```

Plus one appended row in `docs/adr/README.md`'s index table (`| [ADR-014](adr014-cosign-slsa-kyverno.md) | Title | 2026-02-26 | Accepted |`). **ADRs are append-only** (CLAUDE.md) — never edit adr001–adr014. RESEARCH Q4 recommends this be a **separate plan** from the workflow change, so a failed CI iteration does not leave documentation half-edited.

---

## Shared Patterns

### Shared Pattern 1 — D-04 report-only: `continue-on-error: true` on every scan step
**Source:** `.github/workflows/security.yml:38, 64, 94, 131, 174, 181`
**Apply to:** all three new sub-scan run steps.
```yaml
        continue-on-error: true          # D-04: native --error kept, step tolerated
```
Keep each tool's **native** severity semantics (`npm audit --audit-level=high`, tflint's default ruleset). Do **not** soft-fail (`--audit-level=none`, `tflint --force`, `soft_fail: true`) — Phase 18 turns the gate back on and must not re-derive thresholds. Note the comment convention: the reason (`# D-04`) is on the same line.

### Shared Pattern 2 — detect-then-guard emits a log line on both branches
**Source:** `cicd/.github/workflows/security.yml:128-136` (idiom) + RESEARCH L449-460 (corrected form)
**Apply to:** all three sub-scans.
A step skipped by a bare `if: hashFiles(...) != ''` produces **no log output at all**; Criterion 4 demands a clear message. The detection step is what produces it. Detection step always exits 0.

### Shared Pattern 3 — explicit rc capture, never `set -euo pipefail`, never bare `|| true`
**Source:** `scripts/smoke-scans.sh:130-131` (local) + `security.yml:168-172` comment (CI)
```bash
rc=0
<scanner> … || rc=$?
```
All three tools exit non-zero by design. A bare `|| true` on a *scan* or an *assertion* converts a hard failure into a silent clean read — the false pass Criterion 4 forbids and the anti-slop rule names explicitly. `|| true` is acceptable **only** on the informational count-printing `python3 -c` blocks that already use it.

### Shared Pattern 4 — `Show scan output files` must be guarded, not just `if: always()`
**Source:** `cicd/.github/workflows/security.yml:153, 161, 168`
```yaml
        if: always() && steps.dockerfile.outputs.exists == 'true'
```
**This is a required change, not a nicety.** The current step (`security.yml:104-106`) is `ls -l trivy-fs.json trivy-fs.sarif` under `if: always()`. In a consumer repo where the npm sub-scan skipped, `npm-audit-*.json` does not exist, `ls` exits 2, the step fails, and the job goes red **on a clean skip** — a failure mode Criterion 4 forbids from the other direction. Compounding it: RESEARCH Pattern 3's numbered per-input reports are not fixed filenames. Either guard each `ls` with the matching `steps.X.outputs.found` condition, or list a glob tolerantly.

### Shared Pattern 5 — assert on report content, not exit status
**Source:** RESEARCH Pattern 2 (L221-235); local analog `scripts/smoke-scans.sh:61-71`
Both `npm audit` and `pip-audit` return exit code 1 for **"vulnerabilities found"** *and* for **"input missing/invalid"** — indistinguishable by exit code (Pitfalls 1 & 2, both measured). Warning sign for npm: a report whose top level is `{"error": …}` instead of `{"auditReportVersion": 2, …}`. For SCA-03, assert the SARIF `results[].ruleId` set intersects `{terraform_required_providers, terraform_module_version, terraform_module_pinned_source}` — asserting "≥1 finding" would false-pass on `terraform_required_version` alone.

### Shared Pattern 6 — ADR-004 SHA pinning
**Source:** `.github/workflows/security.yml:28, 63, 85`
```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
```
The recommended design adds **no new actions at all** (direct install for both new tools), so this applies only if the planner elects `setup-tflint` or `gh-action-pip-audit` — both SHAs are recorded in RESEARCH §Alternatives.

### Shared Pattern 7 — `git ls-files` with a leading-wildcard pathspec
**Source:** RESEARCH Pitfall 9 (measured matrix, L414-433)
Use `'*package-lock.json'`, `'*requirements*.txt'`, `'*.tf'`. **Not** `requirements*.txt` (root-anchored, misses subdirectories) and **not** `**/requirements*.txt` (misses the repo root; `**` only has recursive meaning under explicit `:(glob)` magic). Exclude `node_modules` explicitly for the npm case. `find` is the wrong tool — it descends into `node_modules/`, `.terraform/`, and vendored trees.

### Shared Pattern 8 — job/step comment banner style
**Source:** `.github/workflows/security.yml:76-79`
```yaml
  # ─────────────────────────────────────────────────────────────────────────
  # SCA — Trivy Filesystem
  # SCA-04: generic filesystem sweep, no per-ecosystem configuration.
  # ─────────────────────────────────────────────────────────────────────────
```
Every non-obvious flag in this workflow carries a *why* comment (`--scanners vuln only, deliberately: …`; `# REQUIRED: gitleaks git finds findings in history`). Match that density for `--recursive`, `--audit-level=high`, and the pip-audit invocation mode.

---

## Decision Conflicts / Open Decisions for the Planner

No `16-CONTEXT.md` exists. These are unresolved and must be surfaced to the user, not guessed.

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **Are the detectors inline or extracted scripts?** RESEARCH's file tree (L176-184) lists only `security.yml` + 2 fixtures + `smoke-scans.sh`, but its negative-test snippet (L574) calls `bash "$REPO_ROOT/scripts/detect-${probe}.sh"` — three files the tree omits. | RESEARCH internally inconsistent | Inline duplication means the smoke gate tests a *copy* of the CI logic, not the CI logic. Extraction means three new files and the `$GITHUB_OUTPUT`-unset trap (see §6). **Planner must pick one and say why**; extraction is the only form that makes the Criterion-4 negative test meaningful. |
| 2 | **pip-audit: resolving or `--no-deps --disable-pip`?** Measured: 11.58 s with transitive resolution vs **0.51 s** without — but the fast path hard-errors on any requirement not pinned with `==`. `--no-deps` alone does **not** prevent resolution (reproduced on two fixtures). | RESEARCH Pitfall 8, Q2 | The resolving path runs `pip install --dry-run --report` in a temp venv against untrusted input (sdist metadata generation ⇒ `setup.py` execution). RESEARCH recommends the resolving default for consumer-repo generality, documented. **User decision.** |
| 3 | **Does the smoke gate's preflight gain `pip-audit` and `tflint`?** A2 says both are CI-only. But adding them to `scripts/smoke-scans.sh:75` makes `bash scripts/smoke-scans.sh` hard-fail on a clean workstation. | A2 vs preflight L73-80 | Two coherent options: (a) CI-only + preflight skips/warns for the two new tools, or (b) add to `versions.conf` + `workstation/setup.sh` so Phase 13's `check`/`update`/`doctor` know about them. 15-PATTERNS.md already ruled `versions.conf` is `setup.sh`-generated and hand-editing is out of scope — which pushes toward (a) or toward a `setup.sh` change. **Do not resolve silently.** |
| 4 | **Is the `sca` job renamed?** L81 is `SCA — Trivy Filesystem` (byte-exact, em-dash U+2014). It misdescribes a job running four tools. | `15-05-SUMMARY.md:131-137` recorded the five verbatim check names **specifically for Phase 18's branch protection** | If renamed, Phase 18's required-check list must use the new name or branch protection is silently non-blocking. Either way the phase SUMMARY **must re-record the final verbatim name.** User decision (A3). |
| 5 | **A1 — tflint has zero precedent in this project.** Absent from the blueprint, `versions.conf`, and every ADR. | RESEARCH A1, "the single highest-value question for `/gsd:discuss-phase`" | If the user wants to stay inside the blessed toolset, SCA-03 collapses to Checkov CKV_TF_1/2 — **modules only, no provider-pinning policy exists in Checkov** — and cannot satisfy SCA-03's wording. Confirm before planning the tflint install step. |
| 6 | **Criterion 3's word "floating."** tflint's default ruleset flags *missing* constraints and unpinned module sources; it does **not** flag `version = ">= 3.0"`. | Measured 7-construct table, RESEARCH Pitfall 3 | Scope Criterion 3 explicitly to missing constraints + unpinned module sources, state the loose-range limitation in the SUMMARY and adoption docs. Do not build a custom rule this phase. |
| 7 | **Phase 17 hand-forwards.** Neither `npm audit` nor `pip-audit` emits SARIF (tflint does). pip-audit JSON carries no severity/CVSS. `--severity` filters Trivy's *report file* but `--audit-level` does **not** filter npm's. | RESEARCH L536-538, Pitfall 7 | Not a Phase 16 change, but the SUMMARY must record all three, or Phase 17 will generalise one tool's behaviour to another. |

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `fixtures/requirements.txt` | fixture / test data | file-I/O | No Python file of any kind exists in the target repo. Only the fixture header-comment convention transfers (`fixtures/package.json:5`, `fixtures/main.tf:1-4`). Content shape comes from RESEARCH's measured pip-audit fixture, not from this codebase. |
| Per-input numbered report iteration (`npm-audit-<n>.json`) | CI orchestration | batch | No existing job iterates over discovered inputs — all five Phase 15 scanners take a single whole-repo target. Use RESEARCH Pattern 3 (L237-243). |
| `require_parses_json` / `run_scan_rc` helper bodies | utility | batch | New helpers; `require_nonempty` (L61-71) and `run_scan` (L22-41) supply the shape, but the logic is new. |

---

## Metadata

**Analog search scope:**
`repos/security-platform/` (all tracked files enumerated via `find`, `node_modules`/`.git` excluded),
`repos/security-platform/.github/workflows/`, `.../cicd/.github/workflows/`, `.../scripts/`, `.../fixtures/`,
`docs/adr/` (15 files listed, 1 read + index tail), `.planning/phases/15-*/` (PATTERNS format + SUMMARY check names).

**Files scanned:** 14 read in full or by targeted range —
`.github/workflows/security.yml` (188 L, full),
`cicd/.github/workflows/security.yml` (203 L, L100-175 + targeted grep),
`scripts/smoke-scans.sh` (229 L, full),
`fixtures/main.tf` (26 L, full), `fixtures/README.md` (51 L, full), `fixtures/package.json` (10 L, full),
`versions.conf` (22 L, full), `.pre-commit-config.yaml` (npm-audit hook block L82-91),
`docs/adr/adr013-falco-runtime-detection.md` (L1-45), `docs/adr/README.md` (index tail),
`15-05-SUMMARY.md` (targeted grep — check-run names L131-137), `15-PATTERNS.md` (head + tail, format reference),
`16-RESEARCH.md` (774 L, full), `16-VALIDATION.md` (unfilled template — carries no content for this map).

**Load-bearing negative results (all three measured in this session, not inherited):**
- `git ls-files | grep -Ei '\.py$|requirements|pyproject|Pipfile|uv\.lock'` in `repos/security-platform` → **no matches**. The Python fixture is genuinely greenfield.
- `versions.conf` read in full (22 L) → no `tflint`, no `pip-audit`, no `PIPAUDIT_VERSION`/`TFLINT_VERSION` key.
- `grep -nE '^\s+(files|types|types_or|exclude):' .pre-commit-config.yaml` → the only filters are `types: [terraform|shell|dockerfile|yaml|markdown]`, `types_or: [python, pyi]` (L32, L34), `types_or: [javascript, jsx, ts, tsx]` + `files: \.(js|jsx|ts|tsx)$` (L78-79), and `files: package-lock\.json$` (L89). **None matches `requirements.txt`** — a bare `requirements.txt` is not typed `python` by pre-commit's `identify` [that last inference per 16-RESEARCH §Carried-Forward, VERIFIED there].

**Pattern extraction date:** 2026-09-10
