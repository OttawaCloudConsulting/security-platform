# Phase 17: SARIF Upload and Artifact Retention - Research

**Researched:** 2026-09-11
**Domain:** GitHub Actions — code scanning SARIF ingestion (`github/codeql-action/upload-sarif`) and workflow artifact retention (`actions/upload-artifact`)
**Confidence:** HIGH (stack, permissions, SARIF shapes — all measured or cited); MEDIUM (GitHub-side rendering behaviour, which can only be closed by a live run)

---

## User Constraints

**No `17-CONTEXT.md` exists.** `/gsd:discuss-phase` has not been run for this phase, so there are no
locked user decisions constraining this research. Every judgement call below is therefore Claude's
discretion *pending confirmation*, and each is listed in the **Assumptions Log** so the planner or
`/gsd:discuss-phase` can convert it into a locked decision before execution.

The nearest thing to locked constraints are the **accepted ADRs** and the **Phase 16 hand-forwards**,
both of which this research treats as binding:

### Binding from accepted ADRs (append-only, do not contradict)

- **ADR-001** — `continue-on-error: true` is *removed* from scanner steps but **explicitly retained on
  SARIF upload steps and artifact upload steps**: "Upload failures (SARIF, artifact) should not block
  merges — they are reporting, not enforcement." [CITED: docs/adr/adr001-remove-continue-on-error.md]
- **ADR-004** — every third-party action is pinned to a full commit SHA with a version comment. Note the
  ADR's scope split: the **blueprint** keeps the `@<SHA>  # vN` *placeholder pattern* deliberately (so the
  document does not go stale), while the **product repo** carries live SHAs.
  [CITED: docs/adr/adr004-pin-actions-to-sha-digest.md]
- **ADR-015** — records tflint's exit-code 2 semantics and its coverage limits. Relevant only as context.

### Binding from Phase 16 hand-forwards (16-07-SUMMARY.md, do NOT re-derive)

1. npm and pip report filenames are **numbered per input** (`npm-audit-1.json`, `pip-audit-2.json`, …).
   The artifact upload **must glob, never name**. Only `trivy-fs.json`, `trivy-fs.sarif` and
   `tflint.sarif` are fixed names.
2. **Neither npm audit nor pip-audit emits SARIF; tflint does.** Re-verified locally this session.
3. pip-audit's JSON carries **no severity and no CVSS** field anywhere.
4. `--audit-level` does **not** filter npm audit's JSON report (exit code only), whereas Trivy's
   `--severity` genuinely does filter Trivy's report. Do not generalise one to the other.

### Pre-existing milestone spec (docs/milestone-plan/milestone-2-cicd-gate.md)

M2-F2 and M2-F3 already specify the shape: `if: always()` + `continue-on-error: true` on both upload
kinds, and artifact JSON named to match DefectDojo parser inputs. This phase implements M2-F2/M2-F3.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **CICD-02** | Each scan job uploads SARIF results to the GitHub Security tab | Permissions model (§Pitfall 1), per-tool SARIF inventory + mandatory distinct `category` (§Architecture Pattern 2), upload-sarif v4.38.0 pinned SHA (§Standard Stack), measured per-tool SARIF shapes (§Architecture Pattern 3) |
| **CICD-03** | Each scan job retains JSON artifact output for future DefectDojo import | `actions/upload-artifact` v7.0.1 contract incl. `retention-days` bounds and name-uniqueness rule (§Architecture Pattern 4), glob-not-name rule for SCA sub-scans, DefectDojo parser inventory confirming every retained format is natively importable (§Don't Hand-Roll) |

Success Criteria 1 and 2 are served by CICD-02; Criterion 3 by CICD-03; Criterion 4 straddles both and
is the one criterion whose resolution is a **user decision, not a research verdict** (see Open Question Q1).

---

## Project Constraints (from CLAUDE.md)

| Directive | Consequence for this phase |
|-----------|---------------------------|
| This is a **reference documentation project**, not buildable software. Primary artifact is `docs/development-security-stack-option-1.md`. | The phase has **two** deliverable surfaces: the live workflow in `repos/security-platform` **and** the blueprint/docs in this repo. A plan that changes only the workflow leaves the primary artifact stale. |
| Preserve ASCII architecture diagrams and the 4-phase layered structure | Blueprint edits must be surgical insertions into the existing CI/CD section (≈ lines 1495–1615), not restructures. |
| Preserve tool coverage matrices and the security tools comparison table | The tool table at ≈ line 1702 lists each tool's output formats — it must gain the SARIF-availability truth for npm audit / pip-audit / tflint. |
| **`docs/adr/` records are append-only** — add new files, never modify accepted ones | Any decision made here (e.g. the npm/pip SARIF-conversion question, the retention period) needs a **new ADR-016**, not an edit to ADR-001 or ADR-004. |
| `.claude/rules/defensive-protocol-v2-anti-slop.md`: "Never set the executable bit on script files"; invoke with an explicit interpreter (`bash script.sh`) | Any helper script added this phase (e.g. a JSON→SARIF converter) must be invoked as `python3 scripts/x.py` / `bash scripts/x.sh`, never `./x.sh`, and must not be `chmod +x`'d. |
| Anti-slop: "Let it crash. Crashes are data." / silent fallbacks forbidden | Directly in tension with ADR-001's `continue-on-error` on upload steps. Resolution: keep `continue-on-error` on the upload (ADR-001) **and** add an intolerant verification step after it — the exact pattern Phase 16 Plan 04 already established. See Pitfall 2. |
| Epistemology rule: high-risk actions get `DOING/EXPECT/IF MISMATCH` | Changing `permissions:` on a workflow is a security-relevant change; plans should treat it as high-risk. |

**Project skills** (`.claude/skills/`): `cdk-testing`, `create-prd`, `itsg-assessment`, `nist-csf-assessment`,
`nist-fedramp-assessment`, `occ-skill-creator`, `occ-skill-refactor`, `rule-creator`, `terraform-testing`.
None are applicable to this phase — no CDK, no Terraform authoring, no assessment deliverable.

---

## Summary

Phase 17 is a **small YAML diff sitting on top of a large, mostly-invisible permissions and data-shape
problem**. The five scan jobs already produce six SARIF files and seven-plus JSON reports on every run
(`semgrep.sarif`, `checkov.sarif`, `trivy-fs.sarif`, `tflint.sarif`, `trivy-image.sarif`,
`gitleaks.sarif`); nothing consumes them. The work is to add one `upload-sarif` step per SARIF file and
one `upload-artifact` step per job. The risk is entirely in four places that a naive diff gets wrong.

**First, permissions.** The workflow is a `workflow_call` reusable workflow invoked by `pr-security.yml`.
GitHub's rule is unambiguous: "The `GITHUB_TOKEN` permissions passed from the caller workflow can be only
downgraded (not elevated) by the called workflow." Both files currently declare
`permissions: contents: read`. **Two files must change**, not one — the caller must *grant*
`security-events: write` and the callee must not *downgrade* it away. Getting this half-right produces a
403 that `continue-on-error: true` (mandated by ADR-001) will silently swallow, leaving a green workflow
with an empty Security tab. That combination — a locked ADR requiring tolerance, plus a failure mode that
tolerance hides — is the single most likely way this phase ships broken-but-green.

**Second, attribution.** GitHub keys analyses on *tool name + category*, and the docs state that uploading
two files for the same tool and category in one run **will fail**. Measured this session: the SCA job's
`trivy-fs.sarif` and the container job's `trivy-image.sarif` both carry `tool.driver.name = "Trivy"`.
These two collide by construction. A distinct `category:` on every upload is therefore mandatory, not a
nicety, and is exactly what Success Criterion 1 is asking for.

**Third, location fidelity — measured, and it is not uniform.** Semgrep emits `%SRCROOT%`-based relative
paths (clean). Checkov emits bare relative paths (clean). tflint emits relative paths in a **two-run**
SARIF (`tflint` + `tflint-errors`). But `trivy convert` sets `originalUriBaseIds.ROOTPATH` to the path of
the **input JSON file**, not the scan root — measured — whereas `trivy fs --format sarif` sets it
correctly. And two scanners cannot produce PR annotations at all: the container scan's 56 results all
point at `library/scan-fixture` line 1 (not a repo file), and all 9 Gitleaks findings point at
`.planning/…` and `.claude/…` paths that exist only in git history and are **absent from the current
tree**. Criterion 2's wording ("wherever the tool reports a file and line") already licenses this, but the
plan must say so explicitly rather than write an unverifiable check.

**Fourth, the verification PR must be constructed, not assumed.** GitHub only annotates "new alerts on
lines of code changed in the pull request." A PR that does not touch a flagged line shows zero annotations
even with a flawless upload.

**Primary recommendation:** Add `security-events: write` to **both** `pr-security.yml` (calling job) and
`security.yml` (workflow level); add one SHA-pinned `github/codeql-action/upload-sarif@b96794f0…` (v4.38.0)
step per SARIF file with a **unique `category:`**, each followed by an intolerant
`gh api …/code-scanning/analyses` or `sarif-id`-presence verification that ADR-001's mandatory
`continue-on-error` cannot hide; add one SHA-pinned `actions/upload-artifact@043fb46d…` (v7.0.1) step per
job with a **unique `name:`**, a multi-line glob `path:` for the SCA job, and an explicit
`retention-days: 90`; replace the SCA job's `trivy convert` with a second direct
`trivy fs --format sarif` run; and close Criterion 4 for npm audit / pip-audit via the criterion's own
"**or** the artifact set" branch rather than by hand-rolling a converter — subject to user confirmation.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Producing SARIF / JSON reports | **CI job (scanner step)** | — | Already implemented Phases 15–16. Phase 17 adds no scanning. |
| Granting the upload token scope | **Caller workflow (`pr-security.yml`)** | Called workflow (`security.yml`) | Permissions flow caller → callee and can only be reduced. The *grant* can only happen at the caller; the callee can only fail to revoke it. |
| Ingesting SARIF, deduplicating, rendering alerts | **GitHub code scanning service** | — | Do not build any local alert store, dedup, or diffing. |
| Distinguishing one tool's results from another's | **`category:` input on each upload step** | SARIF `automationDetails.id` | None of the six SARIF files sets `automationDetails` (measured — all `None`), so the `category:` input is the *only* attribution mechanism available. |
| Rendering inline PR diff annotations | **GitHub code scanning check run** | — | Not a workflow concern; driven by SARIF location quality + PR diff overlap. Cannot be forced from YAML. |
| Retaining JSON for future DefectDojo import | **`actions/upload-artifact` (per job)** | Repo Actions retention setting (cap) | The workflow sets the period; the repo setting caps it. |
| Converting a non-SARIF tool's output | **CI job step (if adopted at all)** | — | See Open Question Q1 — this is a decision, not a given. |
| Documenting the pattern for consumers | **Blueprint + new ADR-016 (this repo)** | `cicd/.github/workflows/security.yml` mirror | CLAUDE.md: the docs are the primary artifact. |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `github/codeql-action/upload-sarif` | **v4.38.0** → SHA `b96794f015dfd88f77b49b1c93e0fa7110f94c63` | Uploads a SARIF file to GitHub code scanning | GitHub's own first-party action; the only supported route for third-party SARIF from Actions. Already named in ADR-004 and milestone-2 spec M2-F2. [VERIFIED: GitHub API — releases list + annotated-tag dereference] |
| `actions/upload-artifact` | **v7.0.1** → SHA `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | Retains scan JSON as a downloadable workflow artifact | GitHub first-party; the only supported artifact mechanism. Named in M2-F3. [VERIFIED: GitHub API — releases list + tag ref] |

**SHA resolution procedure used** (reproducible, and cross-checked): `gh api repos/<r>/git/ref/tags/<tag>`
returns an object whose `type` may be `commit` or `tag`. `codeql-action` v4.38.0 is an **annotated tag**
(`type: tag`) and required a second dereference via `gh api repos/<r>/git/tags/<sha>`; `upload-artifact`
v7.0.1 is a lightweight tag (`type: commit`). **Control:** the same procedure applied to
`actions/checkout@v7.0.1` returned `3d3c42e5aac5ba805825da76410c181273ba90b1`, byte-identical to the SHA
already pinned in `security.yml` — confirming the procedure, not just the answer.

> **Trap:** `actions/checkout` and `actions/upload-artifact` are **both** at version `v7.0.1` right now and
> have **different** SHAs. Do not copy one comment's SHA to the other line.

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `trivy` (already installed, v0.74.0) | pinned in workflow | Native `--format sarif` instead of `trivy convert` | Recommended for the **SCA** job — see Pitfall 3. Already present; no new dependency. |
| `python3` (preinstalled on runner) | 3.12.x | Intolerant SARIF/report verification steps | The workflow already uses this exact `python3 - file <<'PY'` heredoc pattern in four places. Reuse it; do not introduce `jq` as a new idiom. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `github/codeql-action/upload-sarif` v4 | v3.38.0 (still supported, released same day) | Both are listed as "currently supported" and no v3 deprecation date is published [CITED: github/codeql-action README]. v4 is the current major; choosing v3 buys nothing and defers a forced bump. **Use v4.** |
| One `upload-sarif` step per file | One step with `sarif_file:` pointing at a **directory** (the input accepts a directory) | Tempting, but fatal here: a directory upload is a *single* analysis with *one* category, so the two `"Trivy"` runs collide and the docs' "same tool and category in one run will fail" rule bites. Also loses per-tool attribution, which *is* Criterion 1. **Reject.** |
| One artifact per job (5 artifacts) | One artifact for the whole workflow | Impossible without a gather job: v7 defaults `overwrite: false`, so two jobs writing one artifact name fail. Criterion 3 says "one per scan job" anyway. **Keep per-job.** |
| `retention-days: 90` | Repo-level default (also 90) with no explicit key | Criterion 3 demands an **explicit** retention period. An implicit default does not satisfy it. **Set the key.** |
| Hand-rolled npm/pip → SARIF converter | Artifact-only retention for those two tools | See Open Question Q1 — genuinely a user decision. |
| `reviewdog` / `sarif-fmt` for annotations | — | Both add a third-party supply-chain dependency to a *security* stack to solve a problem the first-party path already solves. `sarif-fmt` is a terminal pretty-printer, not a converter — it does not produce SARIF from JSON. **Reject; do not install.** |

**Installation:** No package installs. Both additions are GitHub Actions referenced by SHA.

**Version verification:** performed via the GitHub Releases API this session (not npm/PyPI — neither action
is a registry package). `upload-artifact` latest = v7.0.1 (published 2026-04-10);
`codeql-action` latest = v4.38.0 (published 2026-09-09, two days before this research).

---

## Package Legitimacy Audit

**No language packages are installed by this phase.** The slopcheck gate targets registry packages
(npm/PyPI/crates); the two additions here are GitHub Actions, for which the equivalent controls are
first-party ownership verification and SHA pinning per ADR-004. Both were verified directly against the
GitHub API this session.

| Dependency | Ecosystem | Owner | Age / Currency | Source Repo | Pin | Disposition |
|-----------|-----------|-------|----------------|-------------|-----|-------------|
| `github/codeql-action/upload-sarif` | GitHub Actions | **`github`** (first-party) | v4.38.0 published 2026-09-09; v4 line active, v3 concurrently supported | github.com/github/codeql-action | `@b96794f015dfd88f77b49b1c93e0fa7110f94c63` | **Approved** |
| `actions/upload-artifact` | GitHub Actions | **`actions`** (first-party) | v7.0.1 published 2026-04-10 | github.com/actions/upload-artifact | `@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | **Approved** |

**Packages removed due to slopcheck `[SLOP]` verdict:** none — slopcheck not applicable, zero registry
packages introduced.
**Packages flagged `[SUS]`:** none.
**Third-party actions considered and rejected:** `reviewdog/*`, any community `*-to-sarif` action — rejected
on supply-chain grounds before evaluation, consistent with ADR-004's threat model.

**Residual risk carried forward (unchanged from Phase 15's T-15-13):** `bridgecrewio/checkov-action` is
SHA-pinned but internally pulls a **mutable** image tag. Phase 17 does not change this and should not
claim to.

---

## Runtime State Inventory

**Omitted — not applicable.** This is an additive feature phase, not a rename, refactor or migration. No
stored data, live service config, OS-registered state, secrets or build artifacts carry a string that this
phase changes.

One adjacent item, recorded so it is not mistaken for runtime state: the repo currently has **0 artifacts**
(`actions/artifacts` → `total_count: 0`) and **no code scanning analyses**
(`code-scanning/analyses` → HTTP 404 `"no analysis found"`). Both are the healthy *pre-implementation*
baseline, and both are the "before" measurement for this phase's verification.

---

## Architecture Patterns

### System Architecture Diagram

```
                         pull_request event
                                 │
                                 ▼
                   ┌──────────────────────────────┐
                   │  pr-security.yml (caller)    │
                   │  job: security               │
                   │  permissions:                │   ◄── GRANT happens HERE.
                   │    contents: read            │       Callee cannot elevate.
                   │    security-events: write    │
                   └──────────────┬───────────────┘
                                  │ uses: ./.github/workflows/security.yml
                                  ▼
                   ┌──────────────────────────────┐
                   │  security.yml (workflow_call)│
                   │  permissions:                │   ◄── Must RE-DECLARE, or it
                   │    contents: read            │       downgrades the grant away.
                   │    security-events: write    │
                   └──────────────┬───────────────┘
                                  │
       ┌───────────┬──────────────┼──────────────┬───────────────┐
       ▼           ▼              ▼              ▼               ▼
   ┌───────┐  ┌────────┐   ┌────────────┐  ┌──────────┐   ┌───────────┐
   │ sast  │  │  iac   │   │    sca     │  │container │   │  secrets  │
   │Semgrep│  │Checkov │   │ Trivy fs   │  │Trivy img │   │ Gitleaks  │
   │       │  │        │   │ npm audit  │  │          │   │           │
   │       │  │        │   │ pip-audit  │  │          │   │           │
   │       │  │        │   │ tflint     │  │          │   │           │
   └───┬───┘  └───┬────┘   └─────┬──────┘  └────┬─────┘   └─────┬─────┘
       │          │              │              │               │
       │  each job emits SARIF + JSON into its own workspace     │
       │          │              │              │               │
       ├──────────┴──────────────┴──────────────┴───────────────┤
       │                                                        │
       ▼  (A) SARIF path — 1 step PER FILE, unique category     ▼  (B) JSON path
┌──────────────────────────────────────────────┐   ┌───────────────────────────────┐
│ github/codeql-action/upload-sarif@<SHA>      │   │ actions/upload-artifact@<SHA> │
│   if: always()                               │   │   if: always()                │
│   continue-on-error: true      (ADR-001)     │   │   continue-on-error: true     │
│   with: sarif_file / category: <unique>      │   │   with: name: <unique>        │
└───────────────────┬──────────────────────────┘   │         path: <glob, multi>   │
                    │                              │         retention-days: 90    │
                    ▼                              └──────────────┬────────────────┘
      ┌─────────────────────────────┐                             │
      │ INTOLERANT verify step      │  ◄── required, because       ▼
      │ (no continue-on-error)      │      ADR-001's tolerance   Actions run
      │ asserts upload really landed│      hides a 403.          "Artifacts"
      └─────────────┬───────────────┘                          (downloadable
                    │                                           JSON for a
                    ▼                                           future
        GitHub code scanning service                            DefectDojo
                    │                                           import — DEFECT-01,
       ┌────────────┴─────────────┐                             out of scope)
       ▼                          ▼
  Security tab              PR "Files changed"
  (all alerts, per          inline annotations
   category)                ONLY where the SARIF
                            location is a real repo
                            file AND the PR diff
                            touches that line
```

### Pattern 1 — Grant at the caller, re-declare at the callee

**What:** `security-events: write` must appear in **both** workflow files.
**When to use:** Always, for any reusable workflow that uploads SARIF.
**Why:** "The `GITHUB_TOKEN` permissions passed from the caller workflow can be only downgraded (not
elevated) by the called workflow." [CITED: docs.github.com — Reusing workflow configurations]. The caller
currently grants only `contents: read`, so the callee's jobs cannot obtain `security-events: write` no
matter what `security.yml` says. Conversely, `security.yml`'s existing `permissions: contents: read` block
is an *explicit full set* — leaving it unchanged would strip the grant back out.

```yaml
# .github/workflows/pr-security.yml  (CALLER)
jobs:
  security:
    name: security                       # FROZEN — Phase 14-02 recorded 'security / <job name>'
    permissions:
      contents: read
      security-events: write             # NEW — the grant
    uses: ./.github/workflows/security.yml
```

```yaml
# .github/workflows/security.yml  (CALLEE)
permissions:
  contents: read
  security-events: write                 # NEW — must not downgrade the grant away
```

`actions: read` is documented as required **only for private repositories** [CITED: docs.github.com —
uploading-a-sarif-file-to-github]; this repo is public, so it is optional. Adding it is harmless and makes
the template portable to private consumer repos (relevant to DIST-07/DIST-08).

### Pattern 2 — One upload step per SARIF file, with a unique `category:`

**What:** Never batch; never omit `category`.
**Why:** GitHub keys analyses on **tool name + category**. Per the docs, when uploading more than one SARIF
file per commit you "must identify each set of results as a unique set" by specifying a category, and
uploading multiple files for the **same tool and category in one workflow run will fail**
[CITED: docs.github.com — uploading-a-sarif-file-to-github]. Measured below, two of this stack's files
carry the *identical* driver name, so this is a live collision, not a hypothetical.

### Pattern 3 — Measured SARIF inventory (this is the phase's ground truth)

Every row below was produced **this session** by running the tool against
`repos/security-platform` at `main` (`40682ce`) and parsing the output, not recalled.

| Job | SARIF file | `tool.driver.name` | runs | results | `uriBaseId` | Locations resolve to repo files? | Proposed `category` |
|-----|-----------|--------------------|------|---------|-------------|----------------------------------|---------------------|
| `sast` | `semgrep.sarif` | **`Semgrep OSS`** | 1 | 3 | `%SRCROOT%` | **Yes** — `.github/dependabot.yml`, `cicd/.github/workflows/security.yml`, `fixtures/Dockerfile`, all present | `semgrep` |
| `iac` | `checkov.sarif` | `Checkov` | 1 | 14 | *(none)* | **Yes** — `fixtures/main.tf` | `checkov` |
| `sca` | `trivy-fs.sarif` | **`Trivy`** | 1 | 6 | `ROOTPATH` | **Yes** (`fixtures/package-lock.json`) **but the base is broken under `trivy convert`** — Pitfall 3 | `trivy-fs` |
| `sca` | `tflint.sarif` | `tflint` **and** `tflint-errors` | **2** | 3 + 0 | *(none)* | **Yes** — `fixtures/main.tf` | `tflint` |
| `container` | `trivy-image.sarif` | **`Trivy`** | 1 | 56 | `ROOTPATH` (with `originalUriBaseIds: null`) | **No** — all 56 point at `library/scan-fixture` line 1:1 | `trivy-image` |
| `secrets` | `gitleaks.sarif` | `gitleaks` | 1 | 9 | *(none)* | **No** — all 4 distinct paths (`.planning/STATE.md`, `.planning/phases/05-…`, `.claude/gsd-file-manifest.json`) are **absent from the current tree**; they exist only in git history | `gitleaks` |

Four consequences the planner must build on rather than rediscover:

1. **`Trivy` appears twice.** `sca` and `container` produce the same `tool.driver.name`. Distinct
   categories are **mandatory** or the second upload in the run fails.
2. **Semgrep's driver name is `Semgrep OSS`, not `Semgrep`.** The resulting check run and Security-tab
   tool filter will read `Semgrep OSS`. Phase 18 will see this string; don't guess it.
3. **tflint emits a two-run SARIF.** Both runs go up under one category — fine (limit is 20 runs/file),
   but the second run is named `tflint-errors` and normally has zero results. A verification step that
   asserts `len(runs) == 1` would be wrong.
4. **Two scanners cannot annotate a PR diff.** Container results have no repo file; Gitleaks results point
   at files deleted from the tree. Criterion 2's "wherever the tool reports a file and line" covers this —
   but the plan must name the exempt jobs explicitly so verification isn't written against them.

Also measured: **none** of the six files sets `automationDetails` (all `None`), and only Gitleaks sets
`partialFingerprints` — and it sets `commitSha`/`author`/`date`/`commitMessage`, **not** the
`primaryLocationLineHash` that "code scanning only uses" [CITED: docs.github.com — SARIF support]. GitHub
computes its own fingerprints when absent, so this is not a blocker, but it does mean alert-dedup quality
across runs is GitHub's, not the tools'.

### Pattern 4 — One artifact per job, unique name, glob path, explicit retention

`actions/upload-artifact` v7.0.1 contract, read from the pinned `action.yml`
[VERIFIED: raw.githubusercontent.com/actions/upload-artifact/v7.0.1/action.yml]:

| Input | Default | Constraint that matters here |
|-------|---------|------------------------------|
| `name` | `artifact` | `overwrite` defaults to **`false`**, and the action "will fail if an artifact for the given name already exists". Five parallel jobs ⇒ **five distinct names**. |
| `path` | *(required)* | Accepts a file, directory or wildcard; multi-line supported. |
| `retention-days` | `0` = repo default | "Minimum 1 day. Maximum 90 days unless changed from the repository settings page." |
| `if-no-files-found` | `warn` | `warn` / `error` / `ignore`. Matters for the SCA job's conditional globs. |
| `overwrite` | `false` | Leave `false`. Unique names make it irrelevant; flipping it masks a name collision. |
| `include-hidden-files` | `false` | Irrelevant — all reports are at the workspace root. |
| `archive` | `true` | Leave `true`. `archive: false` ignores `name` and fails on multi-file globs. |

Proposed artifact map (names chosen to read as the DefectDojo import they exist to feed — M2-F3's intent):

| Job | Artifact `name` | `path` (multi-line) | `if-no-files-found` |
|-----|-----------------|---------------------|---------------------|
| `sast` | `semgrep-results` | `semgrep-results.json`, `semgrep.sarif` | `error` (always produced) |
| `iac` | `checkov-results` | `checkov-results.json`, `checkov.sarif` | `error` (always produced) |
| `sca` | `sca-results` | `trivy-fs.json`, `trivy-fs.sarif`, **`npm-audit-*.json`**, **`pip-audit-*.json`**, `tflint.sarif` | **`warn`** — the three sub-scan globs are ecosystem-conditional |
| `container` | `trivy-image-results` | `trivy-image.json`, `trivy-image.sarif` | `error` (always produced) |
| `secrets` | `gitleaks-results` | `gitleaks-results.json`, `gitleaks.sarif` | `error` (always produced) |

`if-no-files-found: warn` on the SCA job is deliberate and is the *only* correct choice there: in a
consumer repo with no `package-lock.json`, `npm-audit-*.json` matches nothing, and `error` would turn the
job red on a clean, correct skip — re-breaking the Criterion 4 skip behaviour Phase 16 spent a plan
proving. `trivy-fs.json` is unconditional, so the SCA artifact is never empty.

### Anti-Patterns to Avoid

- **A single `upload-sarif` step pointed at a directory.** Collapses six analyses into one category,
  collides the two `Trivy` runs, and destroys the per-tool attribution that *is* Criterion 1.
- **Omitting `category`** on the assumption that distinct tool names suffice. They don't — two files here
  share a tool name.
- **`continue-on-error: true` on the upload with no follow-up assertion.** ADR-001 requires the tolerance;
  an unverified tolerated upload is indistinguishable from a silent 403. Pair them.
- **Naming `npm-audit-1.json` / `pip-audit-1.json` literally.** Phase 16 hand-forward #1: glob, never name.
- **Adding a sixth job** to gather artifacts or uploads. Breaks CICD-01's "5 parallel jobs" (already
  Complete) and Phase 18's required-check list. Keep everything as steps inside the existing five jobs.
- **Renaming any job.** `security / SCA — Trivy Filesystem` (em dash U+2014) and the other four are frozen
  for Phase 18.
- **Writing files with `cat <<EOF` heredocs into the repo.** Project convention and GSD rule — use the
  editor tools.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Uploading SARIF to code scanning | A `curl` POST to `/code-scanning/sarifs` with manual gzip+base64 | `github/codeql-action/upload-sarif` | The action handles gzip+base64 encoding, ref/sha derivation for merge commits, path relativization via `checkout_path`, and `wait-for-processing` polling. Hand-rolling re-implements four things badly. |
| Knowing whether the upload succeeded | Parsing action stdout | `wait-for-processing: true` (**default**) + the `sarif-id` output + a `code-scanning/analyses` query | The default already blocks until processing completes, converting async ingestion failures into step failures. |
| Deduplicating findings across runs | A fingerprint store | GitHub code scanning | It computes `primaryLocationLineHash` itself when absent — measured: only Gitleaks sets `partialFingerprints`, and it sets the wrong keys. |
| Retaining/expiring artifacts | A cleanup workflow or external bucket | `retention-days` | Built-in expiry; a cleanup job is more code and more failure modes. |
| Converting npm audit / pip-audit JSON to SARIF | A third-party converter action | **Nothing — or ~40 lines of `python3` if the user requires SARIF** | See Q1. Every candidate third-party converter is an unvetted dependency inside a security supply-chain stack. If conversion is required, hand-rolling is genuinely the *safer* option here — the inverse of this table's usual advice — and it should be recorded in ADR-016 as such. |
| Making the retained JSON importable later | A normalisation layer / common schema | Keep each tool's **native** JSON | **Measured against the DefectDojo source tree:** `dojo/tools/` contains `checkov`, `gitleaks`, `npm_audit`, `npm_audit_7_plus`, `pip_audit`, `sarif`, `semgrep`, `tflint`, `trivy`. **Every tool in this stack already has a native parser**, plus a generic `sarif` parser. Normalising would *destroy* import fidelity. [VERIFIED: GitHub contents API on DefectDojo/django-DefectDojo] |

**Key insight:** DefectDojo's parser inventory is the strongest available evidence for how CICD-03 should
be satisfied — retain each tool's **native JSON**, unchanged, and let the future DEFECT-01 pipeline pick
the matching parser. Note the runner has npm 10.x, so the applicable parser is **`npm_audit_7_plus`**
("NPM Audit v7+ Scan"), not the legacy `npm_audit`.

---

## Common Pitfalls

### Pitfall 1: The permissions grant is made in only one of the two files

**What goes wrong:** `security.yml` gains `security-events: write`, `pr-security.yml` is left alone (or
vice-versa). Every `upload-sarif` step fails with HTTP 403 "Resource not accessible by integration."
**Why it happens:** The `permissions:` key *looks* local to the file it is written in. For
`workflow_call` it is not — the caller's set is the ceiling, and the callee's block is an explicit
(potentially reducing) restatement.
**How to avoid:** Change both files in the same task. Add a static assertion that both YAML files parse to
a permissions mapping containing `security-events: write`.
**Warning signs:** Workflow green, Security tab empty, `code-scanning/analyses` still 404. With ADR-001's
mandatory `continue-on-error: true`, **there is no red step to notice** — this is why Pitfall 2's
verification step is not optional.

### Pitfall 2: ADR-001's `continue-on-error` silently swallows every upload failure

**What goes wrong:** 403s, malformed SARIF, size-limit rejections and processing errors all become a
tolerated step. The phase ships "complete" with zero alerts.
**Why it happens:** ADR-001 *requires* `continue-on-error: true` on upload steps, for a good reason
(uploads are reporting, not enforcement). But the project's own anti-slop rule forbids silent fallbacks.
**How to avoid:** Use the pattern Phase 16 Plan 04 already established in this very workflow — *guarded
action step (tolerated) → intolerant verification step (no `continue-on-error`)*. For SARIF, assert the
`upload-sarif` step's `sarif-id` output is non-empty, and/or query
`GET /repos/{owner}/{repo}/code-scanning/analyses?ref=refs/pull/{n}/merge` and assert the expected set of
categories is present. For artifacts, assert `artifact-id` is non-empty. This satisfies both ADR-001
(the *upload* doesn't block) and anti-slop (a broken upload is *visible*).
**Warning signs:** Any plan whose only verification is "the workflow is green."

### Pitfall 3: `trivy convert` writes a `ROOTPATH` that points at the JSON file, not the scan root

**What goes wrong:** SARIF result locations resolve to a nonexistent path, so alerts land with a broken or
wrong file location and produce no annotation.
**Measured this session, same Trivy 0.74.0, same repo:**

```
trivy fs . --format json -o trivy-fs.json ; trivy convert --format sarif -o trivy-fs.sarif trivy-fs.json
  → originalUriBaseIds.ROOTPATH = "file:///…/scratchpad/sarif/trivy-fs.json/"     ← the INPUT FILE
trivy fs . --format sarif -o trivy-fs-direct.sarif
  → originalUriBaseIds.ROOTPATH = "file:///…/repos/security-platform/"            ← the SCAN ROOT
```

Both emit the same relative `uri` (`fixtures/package-lock.json`) with `uriBaseId: ROOTPATH`. On the runner
the converted form becomes `<workspace>/trivy-fs.json/` + `fixtures/package-lock.json`. `checkout_path`
relativization does **not** rescue this — it relativizes against the workspace, yielding
`trivy-fs.json/fixtures/package-lock.json`, still not a real path.
**How to avoid — recommended (Option A):** in the `sca` job, replace the `Convert to SARIF` step with a
second direct `trivy fs … --format sarif --output trivy-fs.sarif` run, following the two-step precedent
the `secrets` job already uses for Gitleaks (`if: always()` + `continue-on-error: true`, `--exit-code 0`
or tolerated). Trivy's DB is cached by `setup-trivy`, so the second run is cheap.
**Option B (smaller diff):** keep `trivy convert` and strip the bad base with
`python3 -c "…del run['originalUriBaseIds']…"`. Leaves a dangling `uriBaseId: ROOTPATH` reference —
exactly the state the *image* SARIF is already in, which is evidence GitHub tolerates it, but that is
inference, not measurement.
**Honest uncertainty:** I did **not** verify what GitHub's ingester does with a `ROOTPATH` that resolves
outside the repo — that requires a live upload. Option A sidesteps the question entirely, which is why it
is the recommendation. **Confidence that the two Trivy invocations differ: HIGH (measured). Confidence
that the difference breaks GitHub-side rendering: MEDIUM.**
**Leave the `container` job's `trivy convert` alone** — its locations are not repo files under any form,
so there is nothing to preserve.

### Pitfall 4: Criterion 2 is verified with a PR that cannot possibly show annotations

**What goes wrong:** The verification PR edits a doc file; the Security tab fills correctly; zero
annotations appear; the criterion is scored FAILED (or, worse, scored PASSED on a screenshot of the
Security tab, which is a different thing).
**Why it happens:** "Any new alerts on lines of code changed in the pull request are shown as annotations"
[CITED: docs.github.com — triaging code scanning alerts in pull requests]. Alerts on untouched lines
appear in the Security tab / "all branch alerts", **not** on the diff.
**How to avoid:** The verification PR must modify a line that a scanner flags **and whose SARIF location is
a real repo file**. From the measured inventory, the viable annotation sources are exactly three:
`fixtures/main.tf` (Checkov `CKV_AWS_23/24` at lines 26–34, `CKV_TF_1/2` at 38–40; tflint at 7/16/38),
`fixtures/Dockerfile` (Semgrep `missing-user` at line 6), `fixtures/package-lock.json` (Trivy fs, lines
15–20). Gitleaks and the container scan **cannot** contribute — do not write a check expecting them to.
**Second-order:** an alert must also be *new*. With no prior analysis on `main` there is no baseline;
consider whether a `push: branches: [main]` trigger is needed so the base branch has an analysis to diff
against. **This is Open Question Q2 — flagged, not resolved.**

### Pitfall 5: Fork PRs and (possibly) Dependabot PRs get a read-only token

**What goes wrong:** Every upload step 403s on those runs.
**Why:** "If the workflow was triggered by a pull request event other than `pull_request_target` from a
forked repository, and the 'Send write tokens to workflows from pull requests' setting is not selected,
the permissions are adjusted to change any write permissions to read only" — and this applies
**regardless of the `permissions` key** [CITED: docs.github.com — workflow syntax, permissions].
**Dependabot is different and less clear:** Dependabot-triggered runs also get a read-only `GITHUB_TOKEN`
by default, but the troubleshooting doc states you *can* use the `permissions` key to increase access
[CITED: docs.github.com — troubleshooting Dependabot on GitHub Actions]. Whether that extends to
`security-events: write` specifically is **not confirmed** — see Q3. This matters because **CICD-05
(Dependabot) is already live and will produce PRs**; Phase 14 deliberately pinned `actions/checkout` one
patch behind to *guarantee* a Dependabot bump PR appears.
**How to avoid:** ADR-001's `continue-on-error: true` already makes this non-blocking. The trap is the
*verification* step from Pitfall 2 — it must be skipped, not failed, when the token is read-only.
A guard such as `if: github.event.pull_request.head.repo.fork != true && github.actor != 'dependabot[bot]'`
on the **verification** step (never on the upload) keeps both properties.

### Pitfall 6: Artifact name collision across parallel jobs

**What goes wrong:** Two jobs upload `scan-results`; the second fails ("will fail if an artifact for the
given name already exists", `overwrite` default `false`).
**How to avoid:** Five distinct names (table above). Add a static assertion that the set of
`upload-artifact` `name:` values has no duplicates. Do **not** "fix" a collision with `overwrite: true` —
that silently discards one job's results.

### Pitfall 7: SARIF size and result limits

Limits [CITED: docs.github.com — SARIF support for code scanning]: **10 MB per gzip-compressed SARIF
file**; **20 runs per file**; **25,000 results per run**; **25,000 rules per run**; 1,000 locations per
result. Current measured sizes are trivially within bounds (largest: `gitleaks.sarif` at 59 KB; the
largest rule set is Semgrep's 1,074 rules). **But** these are fixture-scale numbers. A real consumer repo
(DIST-07/08) can plausibly exceed 25,000 results on a Semgrep `p/default` or a Trivy image scan.
Worth a note in the adoption docs; not a blocker for this repo.

---

## Code Examples

### Upload SARIF with attribution (the canonical step)

```yaml
# Source: github/codeql-action v4.38.0 upload-sarif/action.yml + docs.github.com
#         "Uploading a SARIF file to GitHub"
- name: Upload Semgrep SARIF
  id: sarif-semgrep
  if: always()                    # scanner steps exit non-zero by design (D-04)
  continue-on-error: true         # ADR-001: upload failures must not block
  uses: github/codeql-action/upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63  # v4.38.0
  with:
    sarif_file: semgrep.sarif
    category: semgrep             # MANDATORY — distinguishes this analysis
    # wait-for-processing: true is the DEFAULT — do not disable it; it is what
    # turns async ingestion failures into something this step can report.
```

### The intolerant companion (satisfies anti-slop without violating ADR-001)

```yaml
# Deliberately NO continue-on-error. ADR-001 tolerates a failed *upload*;
# it does not license shipping a phase whose uploads never landed.
# Pattern copied from the existing "Verify tflint SARIF" step in this workflow.
- name: Verify Semgrep SARIF was accepted
  if: always() && github.event.pull_request.head.repo.fork != true
  run: |
    if [ -z "${{ steps.sarif-semgrep.outputs.sarif-id }}" ]; then
      echo "upload-sarif produced no sarif-id — the upload did not land."
      echo "Most likely cause: security-events:write missing from the CALLER"
      echo "(.github/workflows/pr-security.yml), which the callee cannot elevate."
      exit 1
    fi
    echo "semgrep sarif-id=${{ steps.sarif-semgrep.outputs.sarif-id }}"
```

### Retain JSON with an explicit period (the canonical artifact step)

```yaml
# Source: actions/upload-artifact v7.0.1 action.yml
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

### Replacing `trivy convert` in the `sca` job (Pitfall 3, Option A)

```yaml
# Two steps, not one chained run: block — the workflow's own Gitleaks precedent.
# GitHub's default shell is `bash -e`; a second command after a non-zero exit is dropped.
- name: Run Trivy filesystem scan (JSON for retention)
  continue-on-error: true          # D-04
  run: |
    trivy fs . --scanners vuln --format json --output trivy-fs.json \
      --exit-code 1 --severity HIGH,CRITICAL

- name: Run Trivy filesystem scan (SARIF for code scanning)
  if: always()
  continue-on-error: true          # D-04
  run: |
    trivy fs . --scanners vuln --format sarif --output trivy-fs.sarif \
      --exit-code 1 --severity HIGH,CRITICAL
  # Direct --format sarif sets originalUriBaseIds.ROOTPATH to the SCAN ROOT.
  # `trivy convert` sets it to the INPUT JSON FILE path — measured 2026-09-11.
```

### Static assertions the plan can run without CI (verification, not vibes)

```bash
python3 - <<'PY'
import sys, yaml
wf = yaml.safe_load(open(".github/workflows/security.yml"))
cal = yaml.safe_load(open(".github/workflows/pr-security.yml"))
ok = True

# permissions present in BOTH files
for label, perms in (("callee", wf.get("permissions")),
                     ("caller job", cal["jobs"]["security"].get("permissions"))):
    if not perms or perms.get("security-events") != "write":
        print(f"FAIL {label}: security-events: write missing"); ok = False

cats, names = [], []
for job in wf["jobs"].values():
    for step in job.get("steps", []):
        u = step.get("uses", "")
        if "codeql-action/upload-sarif" in u:
            c = (step.get("with") or {}).get("category")
            if not c: print(f"FAIL: upload-sarif without category: {step.get('name')}"); ok = False
            cats.append(c)
        if "actions/upload-artifact" in u:
            w = step.get("with") or {}
            names.append(w.get("name"))
            if not w.get("retention-days"):
                print(f"FAIL: upload-artifact without retention-days: {step.get('name')}"); ok = False
        if u and "@" in u and len(u.split("@")[1]) != 40:
            print(f"FAIL: action not SHA-pinned (ADR-004): {u}"); ok = False

for label, vals in (("category", cats), ("artifact name", names)):
    if len(vals) != len(set(vals)):
        print(f"FAIL: duplicate {label}: {vals}"); ok = False

print("PASS" if ok else "FAIL"); sys.exit(0 if ok else 1)
PY
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `github/codeql-action/upload-sarif@v3` (what the blueprint's comment says) | **v4** is the current major; v3 remains supported in parallel | v4 line active; v4.38.0 and v3.38.0 both released 2026-09-09 | Blueprint's `# v3` comments should become `# v4`. No v3 deprecation date is published — this is a currency choice, not a forced migration. |
| `actions/upload-artifact@v4` (blueprint comment) | **v7.0.1** | v5 (2025-10-24, Node 24), v6 (2025-12-12, Node 24 default, runner ≥ 2.327.1), v7 (2026-02-26, ESM + `archive:` direct uploads) | Blueprint's `# v4` comments are three majors stale. v4's artifact-immutability model still applies: unique names required. |
| Artifact overwrite tolerated | `overwrite` input exists but defaults `false`; duplicate names **fail** | v4 era onward | Parallel-job artifact naming must be explicit — the dominant v4+ migration failure. |
| `mutable @v3` / `@master` tags | Full 40-char SHA pins | ADR-004 (2026-02-24) | Both new actions must be SHA-pinned; Dependabot (CICD-05) keeps them current. |

**Deprecated/outdated in this repo's own docs (fix as part of this phase):**
- `docs/development-security-stack-option-1.md` ≈ L1515/1536/1583: `upload-sarif@<SHA> # v3` → `# v4`.
- Same file ≈ L1519/1540/1555/1587/1603: `upload-artifact@<SHA> # v4` → `# v7`.
- Same file: **no `category:` appears on any `upload-sarif` example** and **no `retention-days` on any
  `upload-artifact` example** — both are the substance of this phase's criteria and both are missing from
  the primary artifact.
- Same file: no `permissions:` block is shown on the workflow at all. Anyone copy-pasting the blueprint
  today gets a 403 on every SARIF upload.
- `repos/security-platform/cicd/.github/workflows/security.yml` — stale since 16-04 (Phase 16
  hand-forward). Note Semgrep flags this very file (`gha-curl-pipe-shell`, line 102) — it is the source of
  one of the three annotation-capable Semgrep findings.
- `docs/milestone-plan/milestone-2-cicd-gate.md` M2-F3 lists `grype-results.json`; the stack uses Trivy fs,
  npm audit, pip-audit and tflint. Pre-existing drift, same class as Phase 16-06's reconciliation.

---

## Assumptions Log

No `17-CONTEXT.md` exists, so every row below is an **unconfirmed** choice. Each should be put to the user
by `/gsd:discuss-phase` or raised as a checkpoint by the planner before it becomes a locked decision.

| # | Claim / Choice | Section | Risk if Wrong |
|---|----------------|---------|---------------|
| **A1** | `retention-days: 90` is the right period (max allowed without changing repo settings). | Pattern 4 | Low/reversible. But CICD-03 exists to feed a *future* DefectDojo (M3+). If DEFECT-01 lands >90 days out, artifacts from this milestone expire before anything consumes them. A shorter period is cheaper; a longer one needs a repo-settings change. **Genuine user decision.** [ASSUMED] |
| **A2** | Criterion 4 is satisfied for npm audit / pip-audit via the "**or** the artifact set" branch — no converter is built. | Q1 | Medium. If the user reads Criterion 4 as "must reach the Security tab", the phase needs a converter task that isn't planned. **Ask before planning.** [ASSUMED] |
| **A3** | Category strings: `semgrep`, `checkov`, `trivy-fs`, `tflint`, `trivy-image`, `gitleaks`. | Pattern 3 | Low, but categories are **sticky** — changing one later orphans its historical alerts rather than updating them. Worth fixing once, deliberately. [ASSUMED] |
| **A4** | Artifact names: `semgrep-results`, `checkov-results`, `sca-results`, `trivy-image-results`, `gitleaks-results`. | Pattern 4 | Low. A future DEFECT-01 importer will hard-code these. [ASSUMED] |
| **A5** | Both SARIF *and* JSON go into each artifact (not JSON only). | Pattern 4 | Low. CICD-03 says "JSON artifact output"; including SARIF is additive and is the only retention path for tflint, which has **no** JSON output in this workflow. Without it, SCA-03's results are not retained at all. [ASSUMED] |
| **A6** | Option A (second direct `trivy fs --format sarif` run) is preferred over Option B (strip `originalUriBaseIds`). | Pitfall 3 | Medium. Option A modifies a step that Phase 15/16 verified; Option B is a smaller diff but leaves an unverified SARIF shape. [ASSUMED — the *measurement* is VERIFIED; the *choice* is not] |
| **A7** | A new **ADR-016** is written for this phase's decisions. | CLAUDE.md constraints | Low. ADRs are append-only and Phase 16 set the precedent (ADR-015). Omitting it leaves the retention period and the Criterion-4 resolution undocumented. [ASSUMED] |
| **A8** | Dependabot-triggered PR runs **can** obtain `security-events: write` via the `permissions` key. | Pitfall 5 / Q3 | Medium. If wrong, every Dependabot PR shows a tolerated-but-failed upload. Non-blocking because of ADR-001, but the verification step must be guarded either way. [ASSUMED] |
| **A9** | Code scanning SARIF upload is free on this **public** repo with nothing to enable first. | §Security Domain | High if wrong — CICD-02 would be unachievable at zero cost. Strong evidence (docs state a licence is needed *for private repos*; the live `code-scanning/analyses` probe returned `404 "no analysis found"`, the healthy pre-upload state, **not** a 403 GHAS error), but not proven until a real upload lands. [VERIFIED by probe + CITED docs — residual risk LOW] |

---

## Open Questions

1. **Q1 — How is Criterion 4 meant to be satisfied for npm audit and pip-audit?**
   - *What we know:* Criterion 4 reads "…still reaches the Security tab **or** the artifact set through a
     documented conversion step." Measured on the pinned versions: `pip-audit -f` accepts only
     `columns|json|cyclonedx-json|cyclonedx-xml|markdown`; `npm audit` offers only `--json`. Neither emits
     SARIF, and neither ships a converter. `trivy convert` is **not** a template — it is Trivy-internal.
     Meanwhile `trivy convert` (fs + image) *is* already a documented conversion step, and every retained
     JSON format has a native DefectDojo parser.
   - *What's unclear:* whether the user wants npm/pip findings **in the Security tab** (needs ~40 lines of
     hand-rolled `python3`, and note pip-audit has no severity field so every result would be
     `level: warning` — a real fidelity loss), or considers artifact retention sufficient.
   - *Recommendation:* **Satisfy Criterion 4 via `trivy convert` (the documented conversion step, already
     implemented) plus artifact retention for npm/pip, and record it in ADR-016.** Put this to the user
     before planning. Do **not** add a third-party converter action under any option.

2. **Q2 — Does `main` need its own analysis baseline (a `push:` trigger)?**
   - *What we know:* the caller triggers on `pull_request` only. Annotations are described as "new alerts
     on lines of code changed in the pull request." Alert state "only reflect[s] the state of the alert on
     the default branch," and non-default-branch alerts render as "in pull request"/"in branch."
   - *What's unclear:* whether, with **zero** analyses on `main`, PR-only uploads still produce diff
     annotations, and how the Security tab's default (default-branch) filter presents them. Criterion 1
     says "the repo's Security > Code scanning view shows findings" — if that view defaults to `main` and
     `main` has never been analysed, the literal criterion could read as unmet.
   - *Recommendation:* plan for a **live observation task** on a real PR before deciding. If the Security
     tab is empty under the default filter, adding `push: branches: [main]` to `pr-security.yml` is a
     two-line fix — but it changes trigger policy, so it should be a user checkpoint, not an executor's
     judgement call. Phase 19 (VAL-01) is the natural place for the full end-to-end proof.

3. **Q3 — Do Dependabot PR runs get `security-events: write`?**
   - *What we know:* Dependabot runs get a read-only token by default; the troubleshooting doc says
     `permissions` can increase access. Fork PRs are read-only **regardless** of `permissions`.
   - *What's unclear:* whether `security-events` specifically is grantable for Dependabot actors.
   - *Recommendation:* observe on the next Dependabot PR (one is expected — Phase 14 pinned `checkout` a
     patch behind on purpose). Guard the *verification* step, never the upload step. Hand this to Phase 18,
     which owns gate semantics.

4. **Q4 — Which surfaces must this phase update in the documentation repo?**
   - *What we know:* CLAUDE.md makes the blueprint the primary artifact; the blueprint's CI/CD template is
     three majors stale on `upload-artifact`, one major stale on `upload-sarif`, and shows **no**
     `permissions:`, **no** `category:` and **no** `retention-days`. `cicd/.github/workflows/security.yml`
     in the product repo is stale since 16-04.
   - *Recommendation:* treat the blueprint update + ADR-016 as **in scope** (Phase 16 set this precedent
     with 16-06). Keep the blueprint's `<SHA>` placeholders per ADR-004 — update the version *comments*
     and add the three missing keys, do not paste live SHAs into the blueprint.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI, authenticated | SHA resolution, live code-scanning/artifact verification | ✓ | authenticated as OCC | — |
| `gh` scope `security_events` | Reading `code-scanning/analyses` for live verification | **⚠ unverified** | — | The 404 seen was `"no analysis found"` (endpoint reachable), but `gh` also printed a misleading `admin:repo_hook` scope hint. If reads fail post-upload, run `gh auth refresh -h github.com -s security_events`. |
| `trivy` | Re-measuring SARIF shapes locally | ✓ | 0.74.0 (matches CI pin) | — |
| `checkov` | Local SARIF verification | ✓ | 3.2.396 (CI uses 3.3.17 via action image) | Minor version drift; Phase 15 assumption A6 already confirmed filename parity. |
| `semgrep` | Local SARIF verification | ✓ | 1.155.0 (**CI pins 1.177.0**) | Drift noted; structural SARIF shape is stable across minors, but re-confirm `Semgrep OSS` driver name in CI. |
| `gitleaks` | Local SARIF verification | ✓ | 8.30.1 (matches CI pin) | — |
| `tflint` | Local SARIF verification | ✓ | 0.61.0 (**CI installs 0.64.0**) | Phase 16-05 already proved identical rule-id output across this exact drift. |
| `pip-audit` | Format verification | ✓ | 2.10.1 (matches CI pin) | — |
| `npm` | Format verification | ✓ | 11.7.0 (CI runner has 10.9.8) | Both are npm 7+ → DefectDojo `npm_audit_7_plus`. |
| `docker` | Container SARIF measurement | ✓ | running | — |
| `python3` + `yaml` | Static workflow assertions | ✓ | 3.12.0 | — |
| Public repo + code scanning | CICD-02 | ✓ | `visibility: public`, owner is a **User** account | **None.** If this ever moves to a private repo, CICD-02 requires a paid GitHub Code Security licence — a zero-cost-violating hard blocker. |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** `gh` `security_events` scope (refresh if needed).

**Recorded baseline (the "before" measurement for this phase):**
`repos/.../actions/artifacts` → `total_count: 0`; `repos/.../code-scanning/analyses` → 404
`"no analysis found"`; repo Actions settings → `{"enabled": true, "allowed_actions": "all",
"sha_pinning_required": false}`.

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`, so this section applies.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **None conventional.** The project's gate is `bash scripts/smoke-scans.sh` (a hand-rolled pass/fail harness with `run_scan_rc`/`require_success`/`SKIPPED` accounting) plus inline `python3` heredoc assertions inside the workflow. No pytest/jest exists and none should be introduced. |
| Config file | `repos/security-platform/scripts/smoke-scans.sh` |
| Quick run command | `python3` static workflow assertion (see Code Examples) — sub-second, no network |
| Full suite command | `bash repos/security-platform/scripts/smoke-scans.sh` |

**Important:** `smoke-scans.sh` validates *scanners*, and its core invariant is "a scanner that exits 0
found nothing and that is a FAIL." Upload steps have the **opposite** semantics — success is exit 0.
Phase 15 already hit this exact inversion (`docker build` and `trivy convert` were initially scored with
the scanner helper, inverting their verdict) and fixed it by adding `require_success`. **Any smoke-gate
extension for this phase must use `require_success`, never `run_scan`/`run_scan_rc`.**

### Phase Requirements → Test Map

| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|--------------|
| CICD-02 | Both workflow files declare `security-events: write` | static | `python3` yaml assertion (Code Examples) | ❌ Wave 0 |
| CICD-02 | Every `upload-sarif` step has a `category`, and categories are unique | static | same assertion | ❌ Wave 0 |
| CICD-02 | Both new actions are 40-char SHA-pinned (ADR-004) | static | same assertion | ❌ Wave 0 |
| CICD-02 | Each SARIF file parses and has a top-level `runs` key before upload | in-CI | extend the existing `Verify … SARIF` `python3` pattern | ✅ pattern exists (`Verify tflint SARIF`) |
| CICD-02 | Upload actually landed (not swallowed by `continue-on-error`) | in-CI | assert `steps.<id>.outputs.sarif-id` non-empty | ❌ Wave 0 |
| CICD-02 / Crit. 1 | Six distinct categories present on the head SHA | live | `gh api repos/…/code-scanning/analyses?ref=refs/pull/<n>/merge --jq '[.[].category]\|unique'` | ❌ Wave 0 (needs a live PR) |
| CICD-02 / Crit. 2 | Inline annotations on the PR diff | live + **manual** | No reliable API for diff annotations; verify via the PR "Files changed" tab. **The PR must edit a flagged line in `fixtures/main.tf`, `fixtures/Dockerfile` or `fixtures/package-lock.json`** (Pitfall 4). | ❌ Wave 0 |
| CICD-03 | Five artifacts, unique names, all with `retention-days` | static | `python3` yaml assertion | ❌ Wave 0 |
| CICD-03 / Crit. 3 | Artifacts downloadable with the stated expiry | live | `gh api repos/…/actions/runs/<id>/artifacts --jq '.artifacts[]\|{name,expires_at,size_in_bytes}'` | ❌ Wave 0 |
| CICD-03 | SCA artifact contains the numbered npm/pip reports | live | download and list; assert `npm-audit-*.json` present | ❌ Wave 0 |
| CICD-02 / Crit. 4 | The conversion step is documented | doc review | ADR-016 + blueprint diff | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** the `python3` static workflow assertion (fast, offline, catches Pitfalls 1, 6, and
  the ADR-004 pin rule).
- **Per wave merge:** `bash scripts/smoke-scans.sh` — confirms Phase 15/16 scanners still produce findings
  after the `trivy convert` → direct-SARIF change (Pitfall 3 touches a verified step; this is the
  regression guard).
- **Phase gate:** one live PR run; then the three `gh api` live checks + the manual annotation check.

### Wave 0 Gaps

- [ ] A static workflow-assertion script (or inline plan verification) — covers CICD-02 + CICD-03 statics.
- [ ] `sarif-id`-presence verification steps (one per upload) — covers the ADR-001 blind spot.
- [ ] Live `gh api` verification commands for analyses + artifacts.
- [ ] `smoke-scans.sh` extension using `require_success` **if** the `trivy convert` → direct SARIF change
      is adopted (Option A). Must not reuse `run_scan_rc`.
- [ ] A deliberately-constructed verification PR touching a flagged fixture line (Pitfall 4).
- No framework install required.

---

## Security Domain

`security_enforcement` is not disabled in config, so this section applies. Note the meta-quality: this
phase's *subject* is security tooling, but its own *attack surface* is the workflow permission grant.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture | yes | Reusable-workflow permission boundary; least privilege at the calling job rather than repo-wide |
| V2 Authentication | no | No user auth; `GITHUB_TOKEN` only, no PAT, no secret introduced |
| V3 Session Management | no | N/A |
| V4 Access Control | **yes** | `permissions:` is the access-control surface. Grant `security-events: write` on the **calling job**, not at the caller's workflow level, so only the scan job holds it. Never add `contents: write`, `pull-requests: write`, `actions: write` or `id-token: write` — none is needed. |
| V5 Input Validation | yes | SARIF files are untrusted input to the uploader (they contain scanner-derived strings). Mitigated by GitHub-side parsing; locally, the `python3` verification steps must not `eval` or shell-interpolate SARIF content. |
| V6 Cryptography | no | None hand-rolled. SHA-256 checksum verification of tool downloads already exists (tflint, Gitleaks). |
| V12 Files & Resources | yes | Artifact globs must not sweep in secrets. `include-hidden-files` stays `false` (default). Verify no `*.env`/credential file can match `npm-audit-*.json`-style globs — current globs are tightly anchored. |
| V14 Configuration | **yes** | ADR-004 SHA pinning for both new actions; no mutable tags. |

### Known Threat Patterns for GitHub Actions SARIF/artifact upload

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Over-broad `permissions` grant (e.g. workflow-level `write-all`) | Elevation of Privilege | Enumerate the minimum set; grant `security-events: write` on the single calling job |
| Compromised action tag reassignment | Tampering | Full 40-char SHA pin (ADR-004) + Dependabot (CICD-05) |
| **Secret leakage via retained artifacts** | Information Disclosure | Artifacts are downloadable by anyone who can read the repo — and this repo is **public**. Gitleaks runs with `--redact` (already), so `gitleaks-results.json` carries `"REDACTED"` — **verified in the SARIF snippets measured this session**. The planner must not remove `--redact`, and should confirm no other report embeds raw credentials. **This is the highest-consequence security consideration in the phase.** |
| Untrusted SARIF poisoning code scanning | Tampering | Only first-party scanner output is uploaded; `pull_request` (never `pull_request_target`) keeps fork code out of a privileged context |
| Upload failure hidden by `continue-on-error` | Repudiation / Denial of Service (of the control itself) | The intolerant verification step (Pitfall 2) — a security *control* that silently stops reporting is worse than one that is absent |
| Fork PR privilege confusion | Elevation of Privilege | Fork PR tokens are forced read-only by GitHub regardless of `permissions`; do not "fix" this with `pull_request_target` |

---

## Sources

### Primary (HIGH confidence)

- **Direct measurement, this session** (2026-09-11) against `repos/security-platform` @ `40682ce`:
  Trivy 0.74.0 fs SARIF (convert **and** direct), Trivy image SARIF, Checkov 3.2.396 SARIF, Semgrep 1.155.0
  SARIF, Gitleaks 8.30.1 SARIF, tflint 0.61.0 SARIF — driver names, run counts, result counts, `uriBaseId`,
  `originalUriBaseIds`, `partialFingerprints`, and file-existence checks on every reported path.
- `pip-audit 2.10.1 --help` and `npm audit --help` (locally executed) — confirms no SARIF format in either.
- `raw.githubusercontent.com/actions/upload-artifact/v7.0.1/action.yml` — full input contract.
- `raw.githubusercontent.com/github/codeql-action/v4.38.0/upload-sarif/action.yml` — full input/output contract.
- GitHub REST API (`gh`): releases for both actions; annotated-tag dereference for SHA pins;
  `repos/…` visibility + `security_and_analysis`; `actions/permissions`; `actions/artifacts`;
  `code-scanning/analyses`; `DefectDojo/django-DefectDojo` `dojo/tools` directory listing.
- docs.github.com — *SARIF support for code scanning* (limits table, required location properties).
- docs.github.com — *Uploading a SARIF file to GitHub* (required token permissions; category semantics;
  "same tool and category in one workflow run will fail").
- docs.github.com — *Workflow syntax → permissions* (fork PR read-only rule, verbatim; scope list).
- docs.github.com — *Triaging code scanning alerts in pull requests* ("new alerts on lines of code changed
  in the pull request are shown as annotations"; check name "Code scanning results").
- Repo-internal: `docs/adr/adr001-…`, `docs/adr/adr004-…`, `docs/adr/adr015-…`,
  `docs/milestone-plan/milestone-2-cicd-gate.md`, `.planning/phases/16-…/16-07-SUMMARY.md`,
  `repos/security-platform/.github/workflows/{security,pr-security}.yml`, `scripts/smoke-scans.sh`.

### Secondary (MEDIUM confidence)

- docs.github.com — *Reusing workflow configurations* / *Reuse workflows*: "permissions can only be
  maintained or reduced—not elevated". Cross-confirmed by a second search result quoting "The
  `GITHUB_TOKEN` permissions passed from the caller workflow can be only downgraded (not elevated) by the
  called workflow." Two independent renderings of the same rule.
- docs.github.com — *Troubleshooting Dependabot on GitHub Actions* (read-only default; `permissions` can
  increase access — but not confirmed for `security-events` specifically → Q3).
- github/codeql-action README — v3 and v4 both "currently supported", no published v3 sunset date.
- Public-repo code-scanning availability: inferred from "If you want to use code scanning on private
  repositories, you need a GitHub Code Security license" **plus** the live 404 `"no analysis found"` probe
  (not a 403). Strong, but not a direct "free for public repos" quote.

### Tertiary (LOW confidence — flagged, not relied upon)

- GitHub-side rendering behaviour for a `ROOTPATH` resolving outside the repo (Pitfall 3) — **not tested**;
  the recommendation (Option A) is chosen specifically to avoid depending on this.
- Whether a default-branch analysis baseline is required for PR annotations (Q2) — **not tested**.

**No Context7 lookup was performed:** neither deliverable is a library with a Context7 entry. The
authoritative sources are the two `action.yml` files (fetched directly, pinned to the exact versions being
recommended) and docs.github.com. Fetching the pinned `action.yml` is strictly stronger than Context7 here.

---

## Metadata

**Confidence breakdown:**

- **Standard stack: HIGH** — both actions are first-party, versions and SHAs resolved from the GitHub API
  this session, and the resolution procedure was validated against a known-correct control
  (`actions/checkout@v7.0.1` reproduced the SHA already in the workflow).
- **Permissions model: HIGH** — the "cannot elevate" rule is confirmed by two independent renderings of
  GitHub's docs, and the fork read-only rule is quoted verbatim. The conclusion that **two** files must
  change follows directly from reading both files.
- **SARIF data shapes: HIGH** — every claim measured by executing the real tools at (or near) the CI-pinned
  versions against the real repo. Nothing in Pattern 3 is recalled.
- **Architecture / patterns: HIGH** — derived from the measured shapes plus patterns already proven in this
  workflow (guarded-then-intolerant, two-step dual-format output, `require_success` vs `run_scan_rc`).
- **Pitfalls: MEDIUM-HIGH** — Pitfalls 1, 3, 6, 7 are measured or cited. Pitfalls 2, 4, 5 are cited but
  their *consequences here* are inference until a live run exists.
- **GitHub-side rendering (Criteria 1 & 2 as literally worded): MEDIUM** — cannot be closed without a live
  PR. Q2 is the specific residual risk and is flagged rather than papered over.
- **Criterion 4 resolution: LOW by design** — it is a user decision (Q1/A2), not a research finding, and is
  deliberately left open rather than assumed.

**Research date:** 2026-09-11
**Valid until:** ~2026-10-11 (30 days). `codeql-action` ships roughly weekly — v4.38.0 was two days old at
research time, so the recommended SHA will likely be one or two patches behind by execution. That is
acceptable and is exactly what Dependabot (CICD-05) exists to fix; re-resolve only if the plan wants the
newest tip.
