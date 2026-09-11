---
phase: 16-sca-ecosystem-coverage
plan: 06
subsystem: documentation
tags: [adr, blueprint, tflint, pip-audit, coverage-matrix, append-only, licenses]
requires:
  - "16-05 (live run 34614017396 / PR #7) — the CI-measured tflint rule ids this ADR cites instead of the workstation ones"
  - "16-04 (f4388f8) — the sca job whose steps ADR-015 describes (checksum-verified zip, --recursive, steps-not-jobs)"
  - "16-03 (34d53ff) — the smoke gate whose verdict helper was generalised for tflint's exit code 2"
  - "16-RESEARCH Pitfall 3 — the 7-construct measured rule table reproduced in ADR-015's Tradeoff section"
provides:
  - "ADR-015 — the decision record for adopting tflint, a tool with zero prior precedent in this project"
  - "The stated, measured coverage limitation: the default ruleset does NOT flag a floating range such as version = \">= 3.0\""
  - "A primary artifact (the blueprint) that no longer contradicts what CI runs — pip-audit and tflint now appear in both tool tables"
affects:
  - "16-07 (human sign-off — the limitation the sign-off must acknowledge is now written down in two places)"
  - "Any future phase adding a custom tflint rule — ADR-015 records that as explicitly out of scope, not forgotten"
tech-stack:
  added: []
  patterns:
    - "Tool licenses resolved from the GitHub API (gh api repos/<o>/<r>/license --jq .license.spdx_id) rather than recalled"
    - "Structural edits verified by invariant rather than by eye: ``` fence-occurrence parity and per-row pipe-count parity against the header"
key-files:
  created:
    - docs/adr/adr015-tflint-terraform-pin-checking.md
    - .planning/phases/16-sca-ecosystem-coverage/16-06-SUMMARY.md
  modified:
    - docs/adr/README.md
    - docs/development-security-stack-option-1.md
    - .planning/phases/16-sca-ecosystem-coverage/deferred-items.md
key-decisions:
  - "One commit for both tasks, not two — Task 2's acceptance criteria pin `git log -1` to a single subject that must also carry Task 1's two files. Splitting would have failed the plan's own verification"
  - "The matrix note links ADR-015 as `adr/adr015-…` (the path that actually resolves from docs/), NOT the blueprint's existing `docs/adr/adr011-…` style, which is stale and broken; the broken ADR-011 link is logged to deferred-items.md rather than fixed in passing"
  - "`terraform_module_pinned_source` is described in ADR-015 as research-reproduction evidence, explicitly NOT as live-run evidence — it did not fire on run 34614017396 because the fixture's module uses a registry source"
requirements-completed: [SCA-01, SCA-02, SCA-03]
duration: ~12min
completed: 2026-09-11
---

# Phase 16 Plan 06: ADR-015 and Blueprint Reconciliation Summary

**The project's primary artifact now names every tool CI actually runs — pip-audit (Apache-2.0) and tflint (MPL-2.0) appear in both tool tables — and ADR-015 records the tflint adoption with its measured limitation stated as plainly as its benefit: the default ruleset flags *missing* provider constraints and unpinned module sources, but does NOT flag a floating range such as `version = ">= 3.0"`.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-09-11
- **Tasks:** 2 of 2
- **Files changed:** 3 documentation files (1 created, 2 modified), all in the OUTER repository

## Task Commits

| Commit | Subject | Tasks |
|---|---|---|
| `7b9b49d` | `docs(16-06): record tflint adoption in ADR-015 and add pip-audit/tflint to the blueprint tool tables` | **1 and 2** |
| `f2f8336` | `docs(16-06): complete ADR-015 and blueprint reconciliation plan` | SUMMARY / STATE / ROADMAP / deferred-items + three long-untracked planning artifacts |
| *(follow-up)* | `docs(16-06): narrow ADR-015's Checkov claim and record the remaining deviations` | post-review accuracy correction to ADR-015 |

**Why one commit rather than two.** Task 2's acceptance criteria require `git log -1`'s subject to be exactly the string above *and* require `git show --name-only HEAD` to contain both `adr015-tflint-terraform-pin-checking.md` (a Task 1 file) and `docs/development-security-stack-option-1.md` (a Task 2 file). Committing Task 1 separately would have made that criterion unsatisfiable. Task 1's three `<verify>` blocks operate on the working tree and were run — and passed — before Task 2 began, so the gate was not skipped, only the commit boundary was. Files were staged individually by name; no `git add -A` (the working tree carries dozens of unrelated `.claude/**` modifications from other work).

Nothing under `repos/security-platform/` was touched. PR #7 remains open and unmerged — 16-07 owns the merge.

## ADR-015

| Field | Value |
|---|---|
| Number | **ADR-015** |
| Filename | `docs/adr/adr015-tflint-terraform-pin-checking.md` (lowercase `adrNNN-kebab-title.md`, matching adr001–adr014) |
| Heading | `# ADR-015: Adopt tflint for Terraform Provider and Module Pin Checking` |
| Status / Date | Accepted / 2026-09-11 |
| Addresses | SCA-03 — Terraform provider and module versions checked for floating or unpinned constraints |
| Structure | Status/Date/Addresses triple → `## Context` → `## Decision` → `## Consequences` with **Improved:** and **Tradeoff:** (adr013's shape) |

**Index row appended to `docs/adr/README.md`** — exactly one line, after the ADR-014 row:

```
| [ADR-015](adr015-tflint-terraform-pin-checking.md) | Adopt tflint for Terraform Provider and Module Pin Checking | 2026-09-11 | Accepted |
```

`git diff --stat -- docs/adr/README.md` reported `1 file changed, 1 insertion(+)` — one row added, nothing else altered.

### What Context establishes

- **Checkov cannot do this job despite already running in the IaC job:** it covers **modules only**, has **no provider-pinning policy at all**, and `CKV_TF_1` additionally fails a registry module correctly pinned to `version = "5.0.0"` because it demands a git commit hash.
- **A hand-rolled `grep` for `version =` is not viable** — HCL is block-structured, so the string appears in provider blocks, module blocks and unrelated resource attributes alike, which a regex cannot distinguish.
- **tflint has zero prior precedent** in this project: not in the blueprint, not in `versions.conf`, not in any of ADR-001 through ADR-014. Adopting it is a genuine stack addition.

### What Decision records

tflint **v0.64.0** with its bundled `terraform` ruleset (**v0.15.0** under that version); installed by **checksum-verified `.zip` download**, never `curl | sh` (the Gitleaks precedent, preserving ADR-004's intent); invoked as **`tflint --recursive`** because a repo-root invocation without it sees zero `.tf` files and exits 0 — a silent false pass; run as a **step inside the existing `sca` job, not a new job**, because the five check-run names are load-bearing for branch protection; and **CI-only** — deliberately absent from `versions.conf` and the workstation installer, so the local smoke gate prints `SKIPPED:` for its tflint sub-check when the binary is missing.

### What Consequences record

**Improved** names the rule ids observed on the live run (PR #7, run `34614017396`), with file and line:

| Rule id | Live finding | Pinning rule? |
|---|---|---|
| `terraform_required_providers` | missing version constraint for provider `random`, `fixtures/main.tf:16` | **yes** |
| `terraform_module_version` | module `fixture_unpinned_module` should specify a version, `fixtures/main.tf:38` | **yes** |
| `terraform_required_version` | `terraform {}` block declares no `required_version`, `fixtures/main.tf:7` | no — hygiene only, and ADR-015 says so |

**Tradeoff** carries the honest limitation, reproducing 16-RESEARCH's measured 7-construct table and stating that SCA-03's word "floating" is satisfied **through missing constraints and unpinned module sources only**. A custom rule is recorded as explicitly out of scope, with the reason: flagging every `~>` would be very noisy, since `~>` is HashiCorp's own recommended practice for root modules. Tradeoff also records that **tflint exits 2 on findings, not 1** (1 means an application error), which is why the smoke gate's verdict helper takes the expected findings code as a parameter (`run_scan_rc 2 "tflint" …`).

Two firing caveats are recorded rather than glossed: `terraform_required_providers` only fires when the provider is **actually used by a resource**, and `terraform_module_pinned_source` **did not fire on the live run** — it is a git-source rule and the fixture's unpinned module uses a registry source. That rule's behaviour is attributed to 16-RESEARCH's reproduction, *not* to run `34614017396`.

## Blueprint edits — exactly what was added

`docs/development-security-stack-option-1.md`, two tables and one note. No restructure, no reflow, no diagram touched.

### 1. Tool Selection Summary — two rows, inserted directly after the `npm audit *(retained)*` row

| Category | Tool | License | Requires Account? | Replaces |
|---|---|---|---|---|
| **Python SCA** | **pip-audit** | Apache-2.0 | No | `safety` (account-gated model — contradicts the zero-account core value) |
| **Terraform Provider / Module Pin Checking** | **tflint** | MPL-2.0 | No | — *(nothing replaced; closes a gap no existing tool covered)* |

**Licenses resolved from the GitHub API, not recalled:**

```
gh api repos/pypa/pip-audit/license          --jq .license.spdx_id  ->  Apache-2.0
gh api repos/terraform-linters/tflint/license --jq .license.spdx_id  ->  MPL-2.0
```

The line `**Total cost: $0. Total external accounts: 0.**` is **unchanged** — both additions are account-free, so it remains true.

### 2. Language / Framework Coverage Matrix — two columns, every cell filled

Columns `pip-audit` and `tflint` appended to the right of `Gitleaks`. Header went from 11 to **13** columns (pipe count 12 → 14); the separator row gained two `---|` cells; all 11 data rows gained two cells.

| Row | pip-audit | tflint |
|---|---|---|
| Terraform (HCL) | — | **✅ provider/module pins** |
| Python | **✅ requirements** | — |
| all nine other rows | — | — |

No existing column or row was removed. Verified by invariant, not by eye: every one of the 13 table lines (header + separator + 11 rows) has exactly **14** `|` characters.

### 3. The note beneath the matrix — one sentence appended

> … npm audit supplements Grype for npm-specific projects as a fast pre-commit check. **tflint checks Terraform for missing provider version constraints and unpinned module sources — it does not flag a loose version range such as `version = ">= 3.0"`; see [ADR-015](adr/adr015-tflint-terraform-pin-checking.md).**

The `>= 3.0` limitation is now stated in **both** places the plan's threat register (T-16-24) requires, in the same terms.

### Diagram integrity

` ``` ` fence occurrences: **134 before, 134 after** — counted with `src.count('```')` (occurrences, matching the plan's verify) rather than `grep -c` (lines); both happen to agree here because every fence sits on its own line. The edit script asserted parity *before writing the file*, so a damaged block could not have been saved. No ASCII architecture diagram and no part of the four-phase layered structure (Workstation → CI/CD → K8s Infrastructure → Runtime) was altered.

## Append-only compliance

`git show --name-only HEAD` lists exactly three files:

```
docs/adr/README.md
docs/adr/adr015-tflint-terraform-pin-checking.md
docs/development-security-stack-option-1.md
```

**No accepted ADR (adr001–adr014) was modified**, including to add a cross-reference to the new one. `git diff --name-only -- docs/adr/` filtered of the new file and `README.md` returned zero lines. `git diff --diff-filter=D HEAD~1 HEAD` returned empty — nothing was deleted.

## Deviations from Plan

### 1. [Plan-directed] One commit covering both tasks

Documented above under *Task Commits*. Task 2's acceptance criteria require a single `git log -1` subject carrying files from both tasks; the default per-task commit protocol would have made the plan's own verification impossible to satisfy. Task 1's verifies were run against the working tree before Task 2 began and all passed.

### 2. [Judgement call] The matrix note uses a working relative link, not the blueprint's existing broken style

The plan says to link ADR-015 "in the existing relative-link style used elsewhere in the docs." The only existing example is line ~1427's `[ADR-011](docs/adr/adr011-precommit-bypass-warning.md)` — which is **stale**: the blueprint itself now lives under `docs/`, so that path resolves to `docs/docs/adr/…` and does not work. (CLAUDE.md still describes the blueprint as sitting at the repo root, which is where the style came from.) Copying it would have produced a second broken link in the name of consistency. The new note therefore uses `adr/adr015-tflint-terraform-pin-checking.md`, which resolves correctly from the blueprint's actual location.

**Not fixed in passing:** the ADR-011 link and the CLAUDE.md path description are outside this plan's file scope, and a drive-by edit would have added prose changes to a commit whose contents are pinned by acceptance criteria. Both are logged to `deferred-items.md` for a future docs-hygiene sweep.

### 3. [Scope boundary — resolved rather than perpetuated] Three untracked planning artifacts committed

`.planning/phases/16-sca-ecosystem-coverage/16-PATTERNS.md`, `16-PLAN-CHECK.md` and
`.planning/phases/15-five-parallel-scan-jobs/15-VERIFICATION.md` had been sitting untracked in the outer
repo since 16-01 logged them to `deferred-items.md`, and five subsequent plans each re-deferred them. They
are planning artifacts under `.planning/**`, which the final docs commit already covers, and 16-PATTERNS.md
is cited as context by this very plan — leaving it untracked risks losing a referenced input. They were
committed in `f2f8336`. Recorded as a deviation because it is outside 16-06's declared `files_modified`.

### 4. [Post-review correction] ADR-015's Improved section narrowed after an accuracy review

The first draft of ADR-015 said "Nothing in Checkov, Trivy, Semgrep or Grype reports any of these" of all
three live findings. That overclaims, and contradicts the ADR's own Context section: Checkov's `CKV_TF_1`
*would* flag the unpinned registry module — it is the *provider* finding that nothing else in the stack
reports. Since an accepted ADR becomes immutable, this was corrected before the plan closed rather than
left for a superseding record. The same follow-up commit makes the `continue-on-error: true` reference
name D-04 explicitly and note that it suspends ADR-001's removal only while the pipeline is report-only.

---

**Total deviations:** 4 (1 plan-directed commit-boundary merge, 1 link-style judgement call, 1 scope-boundary
resolution of a standing deferral, 1 post-review accuracy correction to this plan's own ADR). No Rule 1-3
auto-fix of executing code was needed; no Rule 4 architectural decision arose.

## Threat Model Compliance

| Threat ID | Disposition | Evidence |
|---|---|---|
| T-16-24 | mitigated | The literal string `>= 3.0` appears in both ADR-015's Tradeoff section (inside the measured 7-construct table *and* in prose) and in the matrix note. Neither document claims loose-range coverage; both name the two cases that *are* covered |
| T-16-25 | mitigated | `git show --name-only HEAD` lists only the new ADR, `README.md` and the blueprint. `git diff --name-only -- docs/adr/` minus those two returned 0 lines. `README.md`'s diff is `1 insertion(+)`, no deletions |
| T-16-26 | mitigated | Fence occurrences 134 → 134, asserted inside the edit script before the file was written. Per-row pipe-count parity (14 across all 13 matrix lines) asserted after. Edits confined to two named tables and one note line |
| T-16-SC | mitigated | Zero installs, zero dependencies, zero executable content — documentation only. Both licenses were resolved live from the GitHub API (`Apache-2.0`, `MPL-2.0`), not recalled |

## Carried Forward

- **PR #7 is still open, green and MERGEABLE on `OttawaCloudConsulting/security-platform`.** 16-07 owns the human sign-off and the merge. The limitation that sign-off must acknowledge — no loose-range detection, and `terraform_module_pinned_source` unfired on a registry-source fixture — is now written down in ADR-015 and in the blueprint note, so 16-07 can cite rather than restate it.
- **A custom tflint rule for loose ranges is recorded as out of scope**, not forgotten. If a later phase wants it, ADR-015's Tradeoff is the starting point and the noise argument (`~>` is recommended practice) is the counter-argument to weigh.
- **tflint remains CI-only.** If a later phase adds it to `versions.conf` and the workstation installer, ADR-015's CI-only scope statement is the thing that must be superseded — by a new ADR, not by editing this one.
- **Broken relative links in the blueprint** (ADR-011, and CLAUDE.md's repo-root description of the blueprint path) are logged in `deferred-items.md`.
- **`cicd/.github/workflows/security.yml` remains stale** (unchanged since 16-04) — carried forward unchanged from 16-05.

## Self-Check: PASSED

| Check | Result |
|---|---|
| `docs/adr/adr015-tflint-terraform-pin-checking.md` exists | FOUND |
| `.planning/phases/16-sca-ecosystem-coverage/16-06-SUMMARY.md` exists | FOUND (this file) |
| Commit `7b9b49d` exists | FOUND |
| Task 1 verify #1 (filename, `# ADR-015:` first line, Status/Context/Decision/Consequences) | PASS |
| Task 1 verify #2 (`terraform_required_providers`, `terraform_module_version`, `>= 3.0`, `recursive`, README link) | PASS |
| Task 1 verify #3 (no accepted ADR modified) | PASS — 0 other files under `docs/adr/` |
| Task 2 verify #1 (`pip-audit`, `tflint`, `MPL-2.0`, `Apache-2.0`, Total-cost line intact) | PASS |
| Task 2 verify #2 (fence parity, matrix rows present) | PASS — 134/134, pipe parity 14 across 13 lines |
| Task 2 verify #3 (`docs/` clean, subject contains `16-06`, both files in HEAD, nothing under `repos/`) | PASS |
| `test -f docs/adr/adr015-…` — the matrix note's relative link resolves from `docs/` | PASS |
