# Phase 17: SARIF Upload and Artifact Retention - Pattern Map

**Mapped:** 2026-09-11
**Files analyzed:** 9 (2 certain modified workflows, 1 conditional modified script, 1 candidate new assertion script, 1 conditional modified mirror template, 3 outer-repo docs (1 new ADR, 2 modified), 1 conditional outer-repo milestone doc) + 4 explicitly NOT modified
**Analogs found:** 8 / 9 (only the "did the tolerated upload actually land?" step has no in-repo analog — nothing in `security.yml` reads `steps.<id>.outcome` today)

**Source:** `17-RESEARCH.md` and `17-VALIDATION.md` only. **No `17-CONTEXT.md` exists** — `/gsd:discuss-phase` has not been run. Every RESEARCH assumption A1–A9 and open question Q1–Q4 is therefore still open; this map carries them forward and **does not resolve any of them**.

---

## Path Convention (read this first)

The implementation lands in the **target repo**, an independent git repo checked out at
`repos/security-platform/` (remote `OttawaCloudConsulting/security-platform`). `repos/` is gitignored by
the outer docs repo.

| In this document | Means |
|---|---|
| Paths starting `.github/`, `cicd/`, `scripts/`, `fixtures/` | **Target repo** root — what CI checks out |
| Paths starting `repos/security-platform/` | The same files as seen from the outer repo (how you `Read` them locally) |
| Paths starting `docs/adr/`, `docs/development-security-stack-option-1.md`, `docs/milestone-plan/` | **Outer docs repo** (this repo) — documentation only, no CI effect |

Nothing in this phase is created in the outer docs repo except `.planning/**` and one new ADR file.

---

## File Classification

| File (target-repo relative unless noted) | New/Mod | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| `.github/workflows/pr-security.yml` — job-level `permissions:` | MODIFIED | config / CI trigger policy | event-driven (permission grant) | `cicd/.github/workflows/security.yml:15-17` (workflow-level form) + blueprint `docs/…-option-1.md:1615-1619` (job-level form) | **role-match** — the caller has no job-level `permissions:` today |
| `.github/workflows/security.yml` — workflow-level `permissions:` | MODIFIED | config | event-driven | `cicd/.github/workflows/security.yml:15-17` | **exact** (same key, same trailing-comment idiom) |
| `.github/workflows/security.yml` — 6 × `upload-sarif` steps | MODIFIED | config / CI reporting | request-response (HTTP upload) | `cicd/.github/workflows/security.yml:40-45` (unguarded) and `:160-166` (guarded) | **shape-only — see Analog Warning** (stale SHA, no `category:`) |
| `.github/workflows/security.yml` — 6 × intolerant "upload landed" verify steps | MODIFIED | config / CI assertion | request-response (step-outcome read) | `security.yml:316-334` (`Verify tflint SARIF`) for the *shape only* | **role-match, no exact analog** — see §No Analog Found |
| `.github/workflows/security.yml` — 5 × `upload-artifact` steps | MODIFIED | config / CI retention | file-I/O (glob → archive) | `cicd/.github/workflows/security.yml:47-53`, `:108-115`, `:167-173` | **shape-only** (stale SHA, no `retention-days`, single-path not multi-line glob) |
| `.github/workflows/security.yml` — `sca` job `Convert to SARIF` → direct `trivy fs --format sarif` | MODIFIED (**conditional on A6 / Pitfall 3 Option A**) | config / CI orchestration | transform → file-I/O | `security.yml:405-416` (Gitleaks two-invocation split) | **exact** — same "no dual-output flag, so two steps not one `run:` block" precedent |
| `scripts/smoke-scans.sh` | MODIFIED (**conditional on A6**) | utility / test harness | batch (sequential CLI, rc capture) | itself — `require_success` L65-77, the trivy-fs block L281-287 | **exact** |
| Static workflow-assertion (inline in plan **or** `scripts/check-workflow-uploads.py`) | **CANDIDATE — NEW; see Open Decision 3** | utility / test harness | transform (YAML → assertions) | `scripts/detect-*.sh` for the shared-script + explicit-interpreter convention; `security.yml:200-217` for the `python3` heredoc assertion form | **role-match** — no `.py` file exists anywhere in `scripts/` |
| `cicd/.github/workflows/security.yml` (mirror template) | **CONDITIONAL — MODIFIED; Q4** | config / distributable template | event-driven | itself (stale since 16-04) | **exact** — it is its own analog |
| `docs/adr/adr016-<kebab-title>.md` *(outer repo)* | **NEW** (A7) | documentation / decision record | n/a | `docs/adr/adr015-tflint-terraform-pin-checking.md` | **exact** |
| `docs/adr/README.md` *(outer repo)* | MODIFIED (same condition as ADR-016) | documentation | n/a | itself — index table, one row per ADR, ADR-015 row is the template | **exact** |
| `docs/development-security-stack-option-1.md` *(outer repo)* | **MODIFIED** (Q4) | documentation / primary artifact | n/a | itself — L1462-1649 workflow block (fenced `yaml`), L1700-1707 output-formats table | **exact** |
| `docs/milestone-plan/milestone-2-cicd-gate.md` *(outer repo)* | **CONDITIONAL — MODIFIED; Q4** | documentation | n/a | 16-06's reconciliation precedent | **role-match** — M2-F3 still lists `grype-results.json`; pre-existing drift |
| `fixtures/**` | **NOT MODIFIED** | fixture | n/a | n/a | Phase 17 adds no scanning. The *verification PR* (Pitfall 4) edits a flagged fixture line, but that is a verification artefact, not a phase deliverable. |
| `security.yml` job **names** and job **count** | **NOT MODIFIED** | config | n/a | n/a | Five jobs, zero `needs:`. `SCA — Trivy Filesystem` (em dash U+2014) and its four siblings are **FROZEN** for Phase 18. No gather job (RESEARCH §Anti-Patterns). |
| `.pre-commit-config.yaml`, `versions.conf`, `workstation/**` | **NOT MODIFIED** | config | n/a | n/a | No new local tool. Both new dependencies are GitHub Actions, which have no workstation presence. |
| `docs/adr/adr001-*.md`, `adr004-*.md` | **NOT MODIFIED** | documentation | n/a | n/a | CLAUDE.md: `docs/adr/` is **append-only**. Every decision this phase makes goes in ADR-016. |

---

## Analog Warning — `cicd/.github/workflows/security.yml` is shape-only (third phase running)

Phases 15 and 16 both ruled this file "a shape to follow, not a source to copy." For Phase 17 it is the
**closest role + data-flow match in the entire repo** — it is the only file here that already contains
`upload-sarif` and `upload-artifact` steps — so the planner *will* reach for it. Copy the step-name and
comment idiom; copy nothing else.

| Detail at `cicd/.../security.yml` | Why it cannot be copied for Phase 17 |
|---|---|
| `upload-sarif@ebcb5b36ded6beda4ceefea6a8bc4cc885255bb3  # v3` (L41, 76, 162) | **Stale by one major.** RESEARCH §Standard Stack resolves v4.38.0 → `b96794f015dfd88f77b49b1c93e0fa7110f94c63`. |
| `upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4` (L48, 83, 110, 169, 198) | **Stale by three majors.** v7.0.1 → `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`. **Trap:** `actions/checkout` is *also* v7.0.1 with a *different* SHA (`3d3c42e5…`) — do not cross-copy. |
| No `category:` on any `upload-sarif` step | Two files in the live workflow carry `tool.driver.name = "Trivy"` (measured). Without distinct categories the second upload in the run **fails** (RESEARCH Pattern 2). Category is the substance of Criterion 1. |
| No `retention-days:` on any `upload-artifact` step | Criterion 3 requires an **explicit** period; an implicit repo default does not satisfy it. |
| `path: semgrep-results.json` — single literal path | The SCA job needs a **multi-line glob** (`npm-audit-*.json`, `pip-audit-*.json`). Phase 16 hand-forward #1: **glob, never name**. |
| `permissions:` at **workflow** level (L15-17) | RESEARCH §Security V4 wants the *grant* scoped to the calling **job** in `pr-security.yml` so only the scan job holds it. The callee's block stays workflow-level. See Open Decision 1. |
| `semgrep … || true` (L38), `gitleaks detect` (L191), `curl … \| sh -s --` (L102-104) | Stale/forbidden commands. `|| true` is the silent-fallback the anti-slop rule bans; `detect` is deprecated; the pipe-to-shell form is flagged by the SAST job's own `gha-curl-pipe-shell` rule. **Never copy.** |
| `if: always() && steps.dockerfile.outputs.exists == 'true'` (L153, 161, 168) | The **guard shape is correct and should be copied**; only the output name changes (`steps.tf.outputs.found == 'true'`). This is the one line worth lifting verbatim in structure. |

**Authoritative source for the new steps:** `17-RESEARCH.md` §Code Examples (L571-650) — both action SHAs
were resolved against the GitHub API this session and the procedure was validated against a known-correct
control.

---

## Pattern Assignments

### 1. `.github/workflows/pr-security.yml` (config, event-driven — MODIFIED)

**Current full text of the relevant part** (`repos/security-platform/.github/workflows/pr-security.yml:11-17`) —
the whole file is 17 lines:

```yaml
permissions:
  contents: read

jobs:
  security:
    name: security
    uses: ./.github/workflows/security.yml
```

**Analog for the job-level grant** — blueprint `docs/development-security-stack-option-1.md:1615-1619`
(`sign` job). This is the project's own idiom for a job-level `permissions:` block: one scope per line,
each non-obvious scope carrying a `# Required for …` trailing comment:

```yaml
    permissions:
      contents: read
      id-token: write   # Required for keyless Cosign OIDC signing
      packages: write   # Required for pushing attestation to GHCR
      actions: read     # Required by slsa-github-generator
```

**Target shape** (RESEARCH Pattern 1, L301-310) — note `name: security` is **FROZEN** (Phase 14-02
recorded the check-run string `security / <job name>`):

```yaml
jobs:
  security:
    name: security                       # FROZEN — Phase 14-02 recorded 'security / <job name>'
    permissions:
      contents: read
      security-events: write             # NEW — the grant; a called workflow cannot elevate
    uses: ./.github/workflows/security.yml
```

**Load-bearing:** the caller's permission set is the **ceiling**. Granting only in `security.yml` yields a
403 on every upload that `continue-on-error: true` then hides (Pitfall 1 + Pitfall 2 compounded).

---

### 2. `.github/workflows/security.yml` — workflow-level `permissions:` (config — MODIFIED)

**Current** (`security.yml:11-15`):

```yaml
on:
  workflow_call: {}

permissions:
  contents: read
```

**Analog — `cicd/.github/workflows/security.yml:15-17`** (exact key, exact comment idiom; this file already
has the line the live workflow is missing):

```yaml
permissions:
  contents: read
  security-events: write  # Required for SARIF upload to GitHub Security tab
```

The callee's block is an **explicit full set** — leaving it as `contents: read` *downgrades the caller's
grant back out*. `actions: read` is required only for private repos (this repo is public); adding it is
harmless and improves portability to the Phase 20 consumer template — RESEARCH L319-322 flags it as
optional, so it is a plan decision, not a given.

---

### 3. `.github/workflows/security.yml` — the six `upload-sarif` steps (config, request-response — MODIFIED)

**Step-placement convention:** every job currently ends with a `Show scan output files` step under
`if: always()` (`security.yml:44-46`, `72-74`, `156-158`, `373-375`, `418-420`; plus the guarded per-tool
variants at `221-223`, `285-287`, `336-338`). **Upload steps slot in after the `Show …` step** for that
job's outputs, so the file listing still prints even when an upload fails.

**Analog — `cicd/.github/workflows/security.yml:40-45`** (unguarded form) and **`:160-166`** (guarded form; the `if:` lines in that file are L153, 161, 168) — step name, key order, trailing rationale comment:

```yaml
      - name: Upload SARIF to GitHub Security tab
        uses: github/codeql-action/upload-sarif@ebcb5b36ded6beda4ceefea6a8bc4cc885255bb3  # v3
        if: always()
        continue-on-error: true  # SARIF upload failure should not block the PR
        with:
          sarif_file: semgrep.sarif
```

**Target shape** (RESEARCH §Code Examples L574-583) — adds `id:`, `category:`, the current SHA, and the
ADR citation in the comment:

```yaml
      - name: Upload Semgrep SARIF
        id: sarif-semgrep
        if: always()                    # scanner steps exit non-zero by design (D-04)
        continue-on-error: true         # ADR-001: upload failures must not block
        uses: github/codeql-action/upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63  # v4.38.0
        with:
          sarif_file: semgrep.sarif
          category: semgrep             # MANDATORY — distinguishes this analysis
          # wait-for-processing: true is the DEFAULT — do not disable it.
```

**The six uploads and their measured inputs** (RESEARCH Pattern 3 — measured this session, do not re-derive):

| Job | SARIF file | `tool.driver.name` | `category` | Guard on the upload step |
|---|---|---|---|---|
| `sast` | `semgrep.sarif` | `Semgrep OSS` | `semgrep` | `if: always()` |
| `iac` | `checkov.sarif` | `Checkov` | `checkov` | `if: always()` |
| `sca` | `trivy-fs.sarif` | **`Trivy`** | `trivy-fs` | `if: always()` |
| `sca` | `tflint.sarif` | `tflint` + `tflint-errors` (**2 runs**) | `tflint` | `if: always() && steps.tf.outputs.found == 'true'` |
| `container` | `trivy-image.sarif` | **`Trivy`** | `trivy-image` | `if: always()` |
| `secrets` | `gitleaks.sarif` | `gitleaks` | `gitleaks` | `if: always()` |

`Trivy` appears **twice** — distinct categories are mandatory, not stylistic. `tflint.sarif` is the only
conditional SARIF; its guard comes from the existing steps at `security.yml:300-338`.

---

### 4. `.github/workflows/security.yml` — the intolerant "did it land?" verify steps (config, assertion — MODIFIED)

**Analog for the SHAPE only — `security.yml:316-334` (`Verify tflint SARIF`).** This is the project's
established *guarded action step (tolerated) → intolerant verification step* pair, and the comment block is
the convention to match (state **why** the step has no `continue-on-error`):

```yaml
      # Report-content check, deliberately WITHOUT continue-on-error: the SARIF
      # is produced by shell redirection, so a tflint that died before writing
      # anything still leaves a file behind. A SARIF without a top-level `runs`
      # key is an infrastructure failure, not a finding.
      - name: Verify tflint SARIF
        if: always() && steps.tf.outputs.found == 'true'
        run: |
          python3 - tflint.sarif <<'PY'
          import json
          import sys

          path = sys.argv[1]
          with open(path) as handle:
              data = json.load(handle)
          if "runs" not in data:
              print("tflint SARIF has no runs key: {}".format(path))
              sys.exit(1)
          …
          PY
```

**What does NOT transfer:** that step asserts *file content*. The new step asserts *step outcome*.
**Nothing in `security.yml` reads `steps.<id>.outcome` anywhere** — grep confirms zero occurrences. The
content source is RESEARCH §Code Examples L588-609:

```yaml
      - name: Verify Semgrep SARIF was accepted
        # Fork PRs get a read-only token regardless of `permissions`, so the upload
        # CANNOT succeed there. Guard the VERIFY step, never the upload step.
        if: always() && github.event.pull_request.head.repo.full_name == github.repository
        run: |
          if [ "${{ steps.sarif-semgrep.outcome }}" != "success" ]; then
            echo "upload-sarif outcome=${{ steps.sarif-semgrep.outcome }} — the upload did not land."
            echo "Most likely cause: security-events:write missing from the CALLER"
            echo "(.github/workflows/pr-security.yml), which the callee cannot elevate."
            exit 1
          fi
          # Secondary, for the log only — never the sole assertion.
          echo "semgrep sarif-id=${{ steps.sarif-semgrep.outputs.sarif-id }}"
```

**Guard composition for the tflint one** — both conditions, or a clean ecosystem skip turns the job red:
`if: always() && steps.tf.outputs.found == 'true' && github.event.pull_request.head.repo.full_name == github.repository`.

**Note a gap between RESEARCH's two renderings of this guard:** Pitfall 5 (L546) proposes
`if: github.event.pull_request.head.repo.fork != true && github.actor != 'dependabot[bot]'`, while the
Code Example copied above (L596) uses only the same-repo test and omits the Dependabot clause. Whether
Dependabot runs can obtain `security-events: write` at all is **Q3/A8 — unconfirmed** — and a Dependabot PR
is *expected* (Phase 14 pinned `actions/checkout` one patch behind on purpose). **Planner: pick one guard
expression and use it on all six verify steps.**

**⚠ RESEARCH and VALIDATION disagree here — see Open Decision 2. Do not copy VALIDATION's wording.**

---

### 5. `.github/workflows/security.yml` — the five `upload-artifact` steps (config, file-I/O — MODIFIED)

**Analog — `cicd/.github/workflows/security.yml:47-53`:**

```yaml
      - name: Upload JSON artifact
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4
        if: always()
        continue-on-error: true  # Artifact upload failure should not block the PR
        with:
          name: semgrep-results
          path: semgrep-results.json
```

**Target shape** (RESEARCH §Code Examples L615-628) — the SCA job is the hard one and is shown because the
other four are strictly simpler:

```yaml
      - name: Upload SCA reports
        if: always()
        continue-on-error: true         # ADR-001
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1
        with:
          name: sca-results             # unique across the five parallel jobs
          path: |
            trivy-fs.json
            trivy-fs.sarif
            npm-audit-*.json            # GLOB — Phase 16 hand-forward #1: numbered per input
            pip-audit-*.json            # GLOB — never name these literally
            tflint.sarif
          if-no-files-found: warn       # sub-scan globs are ecosystem-conditional
          retention-days: 90            # explicit — Criterion 3 requires a stated period
```

**Artifact map** (RESEARCH Pattern 4, A4 — names are unconfirmed, see Open Decision 4):

| Job | `name` | `path` | `if-no-files-found` | Guard |
|---|---|---|---|---|
| `sast` | `semgrep-results` | `semgrep-results.json`, `semgrep.sarif` | `error` | `if: always()` |
| `iac` | `checkov-results` | `checkov-results.json`, `checkov.sarif` | `error` | `if: always()` |
| `sca` | `sca-results` | 5 paths above | **`warn`** | `if: always()` — **no `tf`/`npm`/`py` guard**; `trivy-fs.json` is unconditional so the artifact is never empty |
| `container` | `trivy-image-results` | `trivy-image.json`, `trivy-image.sarif` | `error` | `if: always()` |
| `secrets` | `gitleaks-results` | `gitleaks-results.json`, `gitleaks.sarif` | `error` | `if: always()` |

`overwrite` stays at its `false` default — flipping it masks a name collision rather than fixing one
(Pitfall 6). `include-hidden-files` stays `false` (V12 — artifacts on a **public** repo are
world-downloadable).

---

### 6. `.github/workflows/security.yml` — `sca` job: `trivy convert` → direct SARIF (CONDITIONAL on A6)

**Current** (`security.yml:145-154`):

```yaml
      - name: Run Trivy filesystem scan
        continue-on-error: true          # D-04
        run: |
          trivy fs . --scanners vuln \
            --format json --output trivy-fs.json \
            --exit-code 1 --severity HIGH,CRITICAL

      - name: Convert to SARIF
        if: always()
        run: trivy convert --format sarif --output trivy-fs.sarif trivy-fs.json
```

**Analog for the replacement — `security.yml:400-416` (`secrets` job).** This is the exact precedent
RESEARCH cites: a tool with no dual-output flag gets **two invocations, not one chained `run:` block**,
because GitHub's default shell is `bash -e` and every scanner here exits non-zero by design:

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

Target form in RESEARCH §Code Examples L636-650. **Leave the `container` job's `Convert to SARIF`
(`security.yml:369-371`) alone** — its 56 results point at `library/scan-fixture` 1:1 under any form, so
there is no location fidelity to preserve.

---

### 7. `scripts/smoke-scans.sh` (utility / test harness, batch — MODIFIED, conditional on A6)

**Analog — itself, L281-287.** The block that must change if the direct-SARIF form is adopted:

```bash
run_scan "trivy-fs" trivy fs . --scanners vuln --format json \
  -o "$OUT/trivy-fs.json" --exit-code 1 --severity HIGH,CRITICAL
require_nonempty "trivy-fs-json" "$OUT/trivy-fs.json"
require_success "trivy-fs-convert" trivy convert --format sarif -o "$OUT/trivy-fs.sarif" "$OUT/trivy-fs.json"
require_nonempty "trivy-fs-sarif" "$OUT/trivy-fs.sarif"
```

**Helper-selection rule (load-bearing — RESEARCH §Validation Architecture and 17-VALIDATION both state it):**
a *scanner* that exits 0 is a FAIL; an *infrastructure* step that exits non-zero is a FAIL. These are
opposite. A second `trivy fs … --format sarif` run is a **scanner** invocation (`--exit-code 1` — it
exits 1 on findings), so it takes `run_scan`, while the *report* assertions take `require_nonempty` /
`require_parses_json`. `require_success` is correct only for genuinely exit-0 steps (`docker build`,
`trivy convert`) — see its own docstring at L61-64:

```bash
# require_success: run a command that is expected to exit 0 (e.g. a docker
# build, or `trivy convert`, which are infrastructure/format-conversion steps,
# not scan verdicts). Any non-zero exit is a hard failure, distinct from
# run_scan's inverted PASS-on-1 semantics for actual scanners.
```

**⚠ Which helper applies is NOT settled — it is downstream of an exit-code choice, and PATTERNS must not
pick it. See Open Decision 7.** Dropping `trivy convert` from CI leaves `require_success "trivy-fs-convert"`
without a subject, and the replacement helper depends entirely on the flag the new SARIF run carries:

| New SARIF run carries | Semantics | Correct helper | Note |
|---|---|---|---|
| `--exit-code 1` (RESEARCH §Code Examples L639-647) | **scanner** — exits 1 on findings | `run_scan "trivy-fs-sarif" …` | `require_success` would score a healthy findings run as a FAIL. Increments `SCANS_PASSED`; counting one tool twice is already precedented (the header at L17-20 documents Gitleaks being scanned twice). |
| `--exit-code 0` (RESEARCH Pitfall 3 Option A: "`--exit-code 0` or tolerated") | **infrastructure** — expected exit 0 | `require_success "trivy-fs-sarif" …` | This is the branch under which `17-VALIDATION.md`'s and RESEARCH §Validation Architecture's rule — *"must use `require_success`, never `run_scan`/`run_scan_rc`"* — is literally correct. |

RESEARCH is **internally split** on the flag (Code Example vs Pitfall 3 prose), which is why the upstream
"never `run_scan`" instruction and the mechanics of `run_scan_rc`/`require_success` appear to disagree. They
do not: the upstream rule is about *upload* steps (unambiguously exit-0 infrastructure) and about the
`--exit-code 0` form of this one. **Planner: settle the flag first, then the helper follows.**
The `container` block's `require_success "trivy-image-convert"` (L517) is unaffected either way.

---

### 8. `docs/adr/adr016-<kebab-title>.md` *(outer repo — NEW, per A7)*

**Analog — `docs/adr/adr015-tflint-terraform-pin-checking.md`** (61 lines, written last phase, same author,
same format). Header block, verbatim shape:

```markdown
# ADR-015: Adopt tflint for Terraform Provider and Module Pin Checking

**Status:** Accepted
**Date:** 2026-09-11
**Addresses:** SCA-03 — Terraform provider and module versions are checked for floating or unpinned constraints

## Context
…
## Decision

**tflint v0.64.0 is adopted as the Terraform provider and module pin checker**, running in CI with …

- **Installed by checksum-verified `.zip` download**, never `curl | sh`. …
- **Invoked as `tflint --recursive`.** …
- **Runs as a step inside the existing `sca` job, not as a new job.** …
- **CI-only for now.** …

## Consequences

**Improved:** …

**Tradeoff — the default ruleset does not flag loose ranges.** …

| Construct | Flagged? | Rule |
|---|---|---|
```

Conventions to carry: bold lead-in per Decision bullet; Consequences split into **Improved:** and one or
more **Tradeoff — …:** paragraphs; a measured table where a claim is measured; explicit statements of what
was *not* verified (ADR-015 L59: "the live evidence covers … only"). ADR-016's likely subjects: the
retention period (A1), the Criterion-4 resolution for npm/pip (Q1/A2), the category strings (A3), the
`trivy convert` → direct-SARIF choice (A6), and the Q2 trigger-policy choice.

**Index row — `docs/adr/README.md`**, copy the ADR-015 row's exact column shape:

```markdown
| [ADR-015](adr015-tflint-terraform-pin-checking.md) | Adopt tflint for Terraform Provider and Module Pin Checking | 2026-09-11 | Accepted |
```

`docs/adr/README.md` is **25 lines total** with a single `## Index` table (heading at L7). The ADR-015 row
is the **last line of the file (L25)** — append the ADR-016 row after it. There is no second table and no
trailing prose to work around. [Re-measured this session: `grep -c '^## Index'` → 1, `wc -l` → 25.]

---

### 9. `docs/development-security-stack-option-1.md` *(outer repo — MODIFIED, Q4)*

CLAUDE.md: this is the **primary artifact**, edits must be **surgical insertions**, ASCII diagrams and the
matrices are preserved. Exact targets, all line numbers verified this session:

| Location | Current text | Change |
|---|---|---|
| L1462-1471 (workflow header, `name:` … `on:`; the fenced block runs L1462-1649) | **No `permissions:` block anywhere at workflow level** — the only one in the file is the `sign` job's at L1615-1619 | Insert a workflow-level `permissions:` block. Anyone copy-pasting the blueprint today gets a 403 on every SARIF upload. |
| L1515, 1536, 1583 | `- uses: github/codeql-action/upload-sarif@<SHA>  # v3 — pin to current SHA: https://…/releases` | `# v3` → `# v4`. **Keep the `<SHA>` placeholder** — ADR-004 deliberately keeps the blueprint placeholder-based so it cannot go stale. |
| L1519, 1540, 1555, 1587, 1603 | `- uses: actions/upload-artifact@<SHA>  # v4 — pin to current SHA: …` | `# v4` → `# v7`. Same placeholder rule. |
| L1518, 1539, 1586 | `with: { sarif_file: semgrep.sarif }` (inline-flow mapping) | Add `category:`. The flow-mapping style is the blueprint's own; expanding to block style is a formatting decision the planner should make once and apply consistently. |
| L1522, 1543, 1558, 1590, 1606 | `with: { name: semgrep-results, path: semgrep-results.json }` | Add `retention-days:`. |
| L1700-1707 (`## Cross-Platform CI Compatibility`, `\| Tool \| Install Method \| Output Formats \|`) | Rows for Semgrep CE, Checkov, Trivy, Grype, Syft, Gitleaks | Must gain the SARIF-availability truth for **npm audit**, **pip-audit** (neither emits SARIF) and **tflint** (does). This is the matrix CLAUDE.md says to preserve — **add rows, do not restructure**. |
| L1545-1558 (`sca:` job, `name: SCA — Grype`) | Grype-based | Pre-existing drift vs the live Trivy/npm/pip/tflint stack. **Same 16-06 reconciliation class — flag, scope explicitly, do not silently expand this phase into a blueprint rewrite.** |

---

## Shared Patterns

### Shared Pattern 1 — the tolerated/intolerant pair (this phase's defining pattern)

**Source:** `security.yml:300-334` (tflint run → `Verify tflint SARIF`) — the precedent Phase 16 Plan 04 set.
**Apply to:** every one of the six SARIF uploads.

ADR-001 **requires** `continue-on-error: true` on upload steps ("Upload failures should not block merges —
they are reporting, not enforcement", `adr001-remove-continue-on-error.md:13`). The project's anti-slop rule
**forbids** silent fallbacks. These are reconciled — not traded off — by pairing a tolerated action step
with an intolerant assertion step. Never put `continue-on-error` on the verify step; never remove it from
the upload step.

### Shared Pattern 2 — guard the verify, never the upload

**Source:** RESEARCH Pitfall 5 + `cicd/.../security.yml:153, 161, 168` for the guard shape.
Fork PRs get a read-only `GITHUB_TOKEN` **regardless of the `permissions` key**. The upload must still run
(and be tolerated); the *verification* is what must be skipped, not failed. Same rule for the
ecosystem-conditional tflint upload: `if: always() && steps.tf.outputs.found == 'true'` on **both** the
upload and its verify, or a clean skip turns the job red — re-breaking what Phase 16 spent a plan proving.

### Shared Pattern 3 — `if: always()` on every reporting step

**Source:** `security.yml:45, 73, 153, 157, 198, 222, 258, 286, 307, 317, 337, 370, 374, 412, 419`.
Every scanner step in this workflow is *expected* to exit non-zero (D-04). A reporting step without
`if: always()` never runs on the normal path. This is not defensive — it is the load-bearing default here.

### Shared Pattern 4 — ADR-004 SHA pinning with a version comment

**Source:** `security.yml:28, 63, 95, 349, 350, 385`.

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
```

Full 40-char SHA, two spaces, `# vN.N.N`. **Product repo carries live SHAs; the blueprint keeps
`@<SHA>  # vN` placeholders** — ADR-004's deliberate scope split. The two new SHAs (RESEARCH §Standard
Stack, resolved this session): `upload-sarif` v4.38.0 → `b96794f015dfd88f77b49b1c93e0fa7110f94c63`;
`upload-artifact` v7.0.1 → `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`.

### Shared Pattern 5 — trailing "why" comment on every non-obvious key

**Source:** `security.yml:38, 64, 70, 146, 174, 302, 387, 412` — e.g. `continue-on-error: true          # D-04: native --error kept, step tolerated`,
`soft_fail: false               # D-04: keep native failing exit code`,
`fetch-depth: 0   # REQUIRED: gitleaks git finds findings in history`.
The planner copies these literally. New keys get the same treatment: `# ADR-001` on every
`continue-on-error`, `# MANDATORY — distinguishes this analysis` on every `category`,
`# explicit — Criterion 3 requires a stated period` on every `retention-days`, and `# FROZEN` on
`name: security`.

### Shared Pattern 6 — `python3 - <file> <<'PY'` heredoc for in-CI assertions

**Source:** `security.yml:200-217`, `260-283`, `319-334` (three instances).
Quoted heredoc delimiter (`<<'PY'`), arguments passed as `sys.argv`, plain `import json` / `import sys`,
`print(...)` then `sys.exit(1)` on failure. **Do not introduce `jq`** — it is not an idiom in this repo
(RESEARCH §Standard Stack). V5: these blocks must never `eval` or shell-interpolate SARIF content.

### Shared Pattern 7 — job/step comment banner style

**Source:** `security.yml:19-23`, `76-84`, `340-344`.

```yaml
  # ─────────────────────────────────────────────────────────────────────────
  # Container — Trivy Image
  # Builds the fixture image and scans it for OS package and language
  # dependency vulnerabilities. Runs unconditionally (D-06).
  # ─────────────────────────────────────────────────────────────────────────
```

Box-drawn rule (U+2500), job title with em dash, requirement ID, one-line rationale.

### Shared Pattern 8 — "Show scan output files" placement

**Source:** `security.yml:44-46, 72-74, 156-158, 373-375, 418-420` (unguarded, one per job) and
`221-223, 285-287, 336-338` (guarded, per conditional sub-scan).
These stay exactly as they are. New upload steps go **after** them, so the `ls -l` listing is still in the
log when an upload fails. Do not fold the listing into an upload step.

---

## Decision Conflicts / Open Decisions for the Planner

No `17-CONTEXT.md` exists. These are unresolved and must be surfaced to the user, not guessed.

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **Where does the caller's grant live — workflow level or job level?** `pr-security.yml` has a workflow-level `permissions: contents: read` (L11-12) and its single job has none. RESEARCH §Security V4 wants `security-events: write` on the **calling job** "so only the scan job holds it"; RESEARCH Pattern 1's own snippet (L303-309) shows the job-level form but does not say whether the workflow-level block stays, is reduced, or is removed. | `pr-security.yml:11-12` vs RESEARCH L303-309 / §Security V4 | With one job the two forms are functionally identical today, but the file is a **distribution template** (Phase 20). Job-level is the least-privilege form and the one the blueprint's `sign` job already models. **Planner must state which, and what happens to the workflow-level block.** |
| 2 | **What does the upload-verify step assert?** `17-VALIDATION.md` task 17-01-05 says "`steps.<id>.outputs.sarif-id` non-empty via `require_success`". `17-RESEARCH.md` Pitfall 2 (L460-468) says the primary assertion **must** be `steps.<id>.outcome == 'success'` because `sarif-id` is populated *before* `wait-for-processing` can reject the SARIF — so a rejected upload can leave `sarif-id` set on a failed step. Separately, `require_success` is a `smoke-scans.sh` bash helper; a workflow step cannot call it. | RESEARCH L460-468 (reasoned, cites the action's output timing) vs `17-VALIDATION.md:47` (task 17-01-05) | RESEARCH is the later and better-argued document and its reasoning is checkable. **Recommend `outcome` primary, `sarif-id` echoed for the log only** — and update VALIDATION's wording rather than implementing it. **Do not copy VALIDATION verbatim.** |
| 3 | **Is the static workflow assertion a file or inline?** RESEARCH §Code Examples L654-689 gives a 35-line `python3` block; VALIDATION calls it the "quick run command" run "after every task commit". As a file it would be the **first `.py` in `scripts/`** (all four existing scripts are `.sh`). | RESEARCH L654-689; `scripts/` contains `smoke-scans.sh`, `detect-npm.sh`, `detect-python.sh`, `detect-terraform.sh` | A repeatable per-commit check argues for a file; a one-off plan verification argues for inline. If a file: **`python3 scripts/<name>.py`, never `./<name>.py`, and never `chmod +x`** (anti-slop §Script Safety). It also needs `pyyaml`, which is **not** guaranteed on a clean workstation — the CI runner has it, a local `python3 -c 'import yaml'` should be preflighted the way `smoke-scans.sh` preflights its tools. |
| 4 | **A1/A3/A4 — retention period, category strings, artifact names are all unconfirmed.** Categories are **sticky**: changing one later orphans its historical alerts instead of updating them. Artifact names will be hard-coded by a future DEFECT-01 importer. `retention-days: 90` is the max without a repo-settings change, but CICD-03 exists to feed a DefectDojo that may land >90 days out. | RESEARCH A1, A3, A4 | All three are cheap to decide now and expensive to change later. **Put them to the user together and record the answers in ADR-016.** |
| 5 | **Q1 — how is Criterion 4 satisfied for npm audit and pip-audit?** Neither emits SARIF; neither ships a converter. RESEARCH recommends the criterion's own "**or** the artifact set" branch plus the already-implemented `trivy convert` as the documented conversion step. The alternative is ~40 lines of hand-rolled `python3` — and pip-audit's JSON has **no severity field at all**, so every converted result would be `level: warning`. | RESEARCH Q1, hand-forward #3 | **User decision. Do not add a third-party converter action under any option** (supply-chain grounds, ADR-004 threat model). |
| 6 | **Q2 — does the workflow also run on `push: branches: [main]`?** The caller triggers on `pull_request` only, so `main` is **never analysed** — by construction, no alert this phase produces is ever associated with the default branch. Option (i) keep PR-only and verify Criterion 1 through the Security tab's branch/PR filter; option (ii) add the push trigger, which roughly doubles run count and propagates to the Phase 20 consumer template. Note the `cicd/` mirror **already** has `push: branches: [main]` (L11-13) — the two files already disagree. **Second-order:** the verify-step guard `github.event.pull_request.head.repo.full_name == github.repository` evaluates to `'' == <repo>` (false) on a `push` event, so under option (ii) every intolerant verify step would silently **skip** on `main` pushes — exactly the blind spot Pattern 4 exists to close. If (ii) is chosen, the guard expression must change with it. | RESEARCH Q2; `cicd/.../security.yml:10-13` vs `.github/workflows/pr-security.yml:8-9` | **User checkpoint.** RESEARCH defaults to (i). Whichever is chosen, the mirror and the live caller should stop disagreeing silently, and the choice belongs in ADR-016. |
| 7 | **A6 — replace `trivy convert` in the `sca` job, or strip `originalUriBaseIds`?** Option A modifies a step Phases 15 and 16 both verified (and drags `smoke-scans.sh` with it); Option B is a smaller diff that leaves a dangling `uriBaseId: ROOTPATH`. The *measurement* is HIGH confidence; whether it breaks GitHub-side rendering is **MEDIUM and untested**. **Sub-decision, and the tiebreaker for a real upstream conflict:** does the new SARIF run carry `--exit-code 1` or `--exit-code 0`? RESEARCH's Code Example (L639-647) uses `1`; Pitfall 3 Option A says "`--exit-code 0` or tolerated". The smoke-gate helper follows from that flag — `run_scan` under `1`, `require_success` under `0` — so `17-VALIDATION.md`'s blanket *"never `run_scan`/`run_scan_rc`"* holds only on the `--exit-code 0` branch. | RESEARCH Pitfall 3 (measured twice, byte-exact CI invocation) vs RESEARCH §Code Examples L639-647; `smoke-scans.sh:35-77` helper contracts | RESEARCH recommends A precisely because it sidesteps the untested question. **The cost — a regression-guard smoke run and a `smoke-scans.sh` edit — must be in the plan, not discovered during execution.** Decide the exit code explicitly; do not let the helper choice be made implicitly by whichever document is copied last. |
| 8 | **Q4 — which documentation surfaces are in scope?** The blueprint, ADR-016 + README, the `cicd/` mirror (stale since 16-04), and `docs/milestone-plan/milestone-2-cicd-gate.md` (M2-F3 still lists `grype-results.json`). | RESEARCH Q4; CLAUDE.md "the docs are the primary artifact" | 16-06 set the precedent: reconciliation is in scope but lives in its **own plan**, separate from the workflow change. **Scope it explicitly — an unbounded blueprint rewrite is the failure mode here.** |

---

## No Analog Found

| File / element | Role | Data Flow | Reason |
|---|---|---|---|
| "Did the tolerated upload land?" verify step | config / CI assertion | request-response | **Nothing in `security.yml` reads `steps.<id>.outcome`** — verified by grep across all 420 lines. The three existing intolerant verify steps (L197, L257, L316) all assert *report content*, which is a different question. Shape from L316-334; content from RESEARCH §Code Examples L588-609. |
| Multi-line glob `path:` on an artifact upload | config | file-I/O | Every `upload-artifact` in the repo (`cicd/…:47-53, 82-88, 108-115, 167-173, 196-202`) uses a single literal path. The multi-line + glob form is new; source is the `actions/upload-artifact` v7.0.1 `action.yml` contract as read in RESEARCH Pattern 4. |
| `category:` / `retention-days:` inputs | config | — | Neither key appears anywhere in this repo (grep across `.github/`, `cicd/`, and the blueprint: zero hits). They are the substance of Criteria 1 and 3 and have **no precedent to copy**. |
| Fork-PR / same-repo guard expression | config | event-driven | `github.event.pull_request.head.repo.full_name == github.repository` appears nowhere in the repo. The existing guards are all `steps.X.outputs.<key> == 'true'`. Source: RESEARCH L596. |
| A live `gh api` verification recipe | verification | request-response | No phase has yet queried `code-scanning/analyses` or `actions/runs/<id>/artifacts` as a gate. RESEARCH §Phase Requirements → Test Map supplies the three exact commands; the `gh` `security_events` scope is flagged **unverified** (RESEARCH §Environment Availability) — preflight it, and `gh auth refresh -h github.com -s security_events` if reads fail. |

---

## Metadata

**Analog search scope:**
`repos/security-platform/.github/workflows/` (both files, read in full),
`repos/security-platform/cicd/.github/workflows/security.yml` (targeted: L1-60, L100-120, L155-203 + full grep),
`repos/security-platform/scripts/` (4 files enumerated; `smoke-scans.sh` targeted L20-140, L281-300 + structural grep),
`docs/adr/` (16 entries listed; `adr015` read in full, `adr001` L1-19, `README.md` head + tail),
`docs/development-security-stack-option-1.md` (targeted: L1456-1480, L1490-1625, L1690-1730 + full grep for `upload-*`/`permissions`/`retention`),
`.planning/phases/16-sca-ecosystem-coverage/16-PATTERNS.md` (format reference: L1-120, L380-484, header index),
`.planning/phases/17-…/17-RESEARCH.md` (1,031 L, full), `17-VALIDATION.md` (L1-60).

**Files scanned:** 12 read in full or by targeted non-overlapping range.

**Load-bearing negative results (measured this session, not inherited):**
- `grep -n "category:\|retention-days"` across `docs/development-security-stack-option-1.md` → **zero hits**. The blueprint models neither key.
- `grep` for `steps\..*\.outcome` across `.github/workflows/security.yml` → **zero hits**. The outcome-assertion pattern is genuinely new to this codebase.
- `.github/workflows/security.yml` has **no** `security-events` anywhere; `cicd/.github/workflows/security.yml:17` **does**. The distributable template is already correct on the one line the live workflow is missing.
- `docs/adr/README.md` is 25 lines with **one** index table (`grep -c '^## Index'` → 1); the ADR-015 row is the file's last line (L25). An earlier head/tail read overlapped and looked like two tables — it is one. Corrected here so the planner does not chase a duplicate.
- `.github/workflows/pr-security.yml` is 17 lines total; its single job has **no** `permissions:` key at all.

**Pattern extraction date:** 2026-09-11
