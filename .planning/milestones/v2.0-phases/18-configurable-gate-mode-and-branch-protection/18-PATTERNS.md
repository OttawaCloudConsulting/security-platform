# Phase 18: Configurable Gate Mode and Branch Protection - Pattern Map

**Mapped:** 2026-09-11
**Files analyzed:** 6 (2 workflow YAML modified, 1 ADR created, 3 docs modified)
**Analogs found:** 6 / 6

This phase modifies existing files and adds one new ADR. For the two workflow files the
closest analog is **the file itself** — the surrounding steps already encode every
convention the new lines must match. For the new ADR the analog is ADR-016 (the most
recent record, written by Phase 17).

## File Classification

| New/Modified File | New/Mod | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|---------|------|-----------|----------------|---------------|
| `repos/security-platform/.github/workflows/security.yml` | modified | config (callable CI workflow) | event-driven / batch | itself — `sast` job L33-68 is the canonical job shape | exact (self) |
| `repos/security-platform/.github/workflows/pr-security.yml` | modified | config (caller workflow) | event-driven | itself — L17-39 (comment voice + frozen-name convention) | exact (self) |
| `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` | **new** | doc (decision record) | n/a | `docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md` | exact |
| `docs/adr/README.md` | modified | doc (index table) | n/a | itself — L25-26 (ADR-015/016 rows added by Phases 16/17) | exact |
| `docs/development-security-stack-option-1.md` (L2019-2028) | modified | doc (blueprint) | n/a | itself — the Phase 2 deliverables block L2008-2045 | exact (self) |
| `docs/milestone-plan/milestone-2-cicd-gate.md` (L98-109) | modified | doc (milestone plan) | n/a | itself + the blueprint correction above (same defect) | exact (self) |

---

## Pattern Assignments

### `repos/security-platform/.github/workflows/security.yml` (config, event-driven)

**Analog:** itself. 962 lines, five jobs. Every convention this phase needs is already
present in the file; the planner's job is to match it exactly, not invent a new voice.

#### Edit point 1 — the `workflow_call` contract (L11-12)

Current:

```yaml
on:
  workflow_call: {}
```

Replace the `{}` with the `inputs:` block. RESEARCH.md Pattern 1 (L266-282) gives the exact
accepted YAML; declare the input with **no `default:`** so the `||` chain in edit point 2 can
fire on the empty string.

#### Edit point 2 — workflow-level `env` (insert at L25, between the `permissions:` block and `jobs:`)

The existing `permissions:` block (L17-24) is the model for how a workflow-level block is
commented in this file — every non-obvious key carries a why-comment above it:

```yaml
# Explicit FULL permission set, not a subset. A called workflow's block can
# only REDUCE what the caller granted — leaving this at `contents: read`
# would downgrade the caller's grant back out and 403 every SARIF upload.
permissions:
  contents: read
  # Required for SARIF upload to the GitHub Security tab. Re-declared here, not
  # newly granted: the caller's job-level set (pr-security.yml) is the ceiling.
  security-events: write
```

Match that shape for the new `env:` block (RESEARCH.md L280-281 supplies the expression):

```yaml
env:
  GATE_MODE: ${{ inputs.gate_mode || vars.GATE_MODE || 'report-only' }}
```

#### Edit point 3 — the stale header comment (L6-7)

```yaml
# Phase 15: report-only. Scan steps carry continue-on-error, so findings are
# visible but non-blocking. Gate mode is Phase 18 (CICD-06).
```

This sentence becomes false the moment the flag lands. It is a **required** modification
point, not an optional tidy-up — a consumer copying the file reads this before any YAML.

#### Edit point 4 — the eleven `# D-04` flip points

Each of these lines becomes `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}`
(RESEARCH.md Pattern 2, L295-301). **Every one carries a different trailing reason today:**

| Line | Job | Step | Existing trailing comment |
|------|-----|------|---------------------------|
| 47 | `sast` | Run Semgrep | `# D-04: native --error kept, step tolerated` |
| 182 | `iac` | Run Checkov | `# D-04: native failing behaviour tolerated at step level` |
| 346 | `sca` | Run Trivy filesystem scan (JSON for retention) | `# D-04` |
| 366 | `sca` | Run Trivy filesystem scan (SARIF for code scanning) | `# D-04` |
| 441 | `sca` | SCA-01 — npm audit | `# D-04: native --audit-level exit code kept` |
| 504 | `sca` | SCA-02 — pip-audit | `# D-04` |
| 569 | `sca` | SCA-03 — tflint (SARIF) | `# D-04: exit 2 means findings` |
| 575 | `sca` | SCA-03 — tflint (human-readable log) | `# D-04: exit 2 means findings` |
| 738 | `container` | Run Trivy image scan | `# D-04` |
| 866 | `secrets` | Run Gitleaks (SARIF) | `# D-04` |
| 873 | `secrets` | Run Gitleaks (JSON) | `# D-04` |

**Decision the planner must make deliberately:** preserve each step's per-tool reason suffix
(e.g. `${{ ... }}   # D-04 / Phase 18: exit 2 means findings`) or flatten all eleven to one
uniform comment. RESEARCH.md's verification grep
(`! grep -n "continue-on-error: true.*# D-04"`) passes either way, so nothing catches a
silent loss of the per-tool reasoning. This file's established voice is per-step, tool-specific
comments — preserving the suffix matches it.

Canonical before/after, using L46-51 as the shape:

```yaml
      - name: Run Semgrep
        continue-on-error: true          # D-04: native --error kept, step tolerated
        run: |
          semgrep scan --config p/default --metrics=off --error \
            --json-output=semgrep-results.json \
            --sarif-output=semgrep.sarif .
```

Note the alignment convention: the comment starts at a fixed column, padded with spaces after
the value. `${{ ... }}` is far longer than `true`, so the column alignment cannot be preserved —
pick one space-separated form and apply it to all eleven.

#### Edit point 5 — three `if:` guards gain `always() &&` (L440, L503, L568)

```yaml
      - name: SCA-01 — npm audit
        if: steps.npm.outputs.found == 'true'
        continue-on-error: true          # D-04: native --audit-level exit code kept
```

```yaml
      - name: SCA-02 — pip-audit
        if: steps.py.outputs.found == 'true'
        continue-on-error: true          # D-04
```

```yaml
      - name: SCA-03 — tflint (SARIF)
        if: steps.tf.outputs.found == 'true'
        continue-on-error: true          # D-04: exit 2 means findings
```

The target form already exists in the same job — copy it verbatim from L465, L525, L574:

```yaml
        if: always() && steps.npm.outputs.found == 'true'
```

Rationale is RESEARCH.md P-03 (L485-505). This is a behaviour change in report-only mode too
and must be recorded as a deliberate one.

#### Edit point 6 — the `gate_mode` validation step (one per job, never a sixth job)

RESEARCH.md Pattern 5 (L405-412) supplies the `case` block verbatim. Insertion points — the
first `steps:` slot of each job:

| Job | Insert after | Existing first step |
|-----|--------------|---------------------|
| `sast` | L36 (`steps:`) | L37 `- uses: actions/checkout@3d3c42e5…` |
| `iac` | L174 (`steps:`) | L175 `- uses: actions/checkout@3d3c42e5…` |
| `sca` | L293 (`steps:`) | L294 `- uses: actions/checkout@3d3c42e5…` |
| `container` | L718 (`steps:`) | L719 `- uses: actions/checkout@3d3c42e5…` |
| `secrets` | L844 (`steps:`) | L845 `- uses: actions/checkout@3d3c42e5…` |

`[VERIFIED: grep -n "^    steps:" and grep -n "actions/checkout" — all five jobs open with
checkout on the line immediately after `steps:`.]`

**Sequencing note for the planner:** placed before checkout, an invalid `GATE_MODE` fails the
job before any scan runs — correct and intended — but the downstream `if: always()` upload and
"Show scan output files" steps still fire and hit missing files. The job is red either way; the
log will additionally show upload failures. Decide and document which ordering you want rather
than discovering it in a run.

The comment voice for an intolerant step is established at L69-79 / L139-141 / L207-209 —
"Deliberately WITHOUT continue-on-error, …" followed by the reason. Example, L69-72:

```yaml
      # Deliberately WITHOUT continue-on-error, and deliberately NOT guarded on
      # the upload step itself. ADR-001 tolerates a failed upload; it does not
      # license shipping a phase whose uploads never landed, so the tolerated
      # step above is read back here and a non-success outcome turns this job
```

---

### `repos/security-platform/.github/workflows/pr-security.yml` (config, event-driven caller)

**Analog:** itself. 39 lines. Two edits.

#### Edit point 1 — correct the FROZEN comment (L19-22)

```yaml
  security:
    # FROZEN. Phase 14-02 captured the check-run string as
    # `security / <job name>`, and Phase 18 hard-codes it into the
    # branch-protection required-check list. Renaming this job would leave
    # branch protection pointing at a check that no longer exists.
    name: security
```

"Phase 18 hard-codes **it** into the required-check list" is wrong as written — RESEARCH.md Q1
(L754-768) establishes that this job emits **no check run of its own**; the string `security`
is the **prefix** of the five called-workflow check names. The FREEZE still holds (renaming the
job changes all five contexts), but the stated reason needs correcting to the prefix framing.

#### Edit point 2 — document the deliberate absence of `with:` (after L39)

```yaml
    uses: ./.github/workflows/security.yml
```

RESEARCH.md Pattern 3 (L334-347) supplies the comment block to append. The load-bearing content
is that **omitting `with:` is the mechanism**, not an oversight — a committed literal would
defeat CICD-06's "without editing workflow YAML". The file's existing comment style is exactly
this: multi-line `#` blocks that explain why something is absent or restated (L11-13, L24-26,
L35-38).

---

### `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` (doc, NEW)

**Analog:** `docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md` (65 lines).
Secondary structural analog: `docs/adr/adr015-tflint-terraform-pin-checking.md`.
**Content predecessor:** `docs/adr/adr002-require-branch-protection.md` — ADR-017 **extends**
ADR-002 (which mandated branch protection in the abstract); ADR-002 is Accepted and
append-only, so cite it, never edit it.

**Header pattern** (ADR-016 L1-5):

```markdown
# ADR-016: SARIF Upload Attribution and Scan Artifact Retention

**Status:** Accepted
**Date:** 2026-09-11
**Addresses:** CICD-02, CICD-03 — scan results reach the GitHub Security tab with per-analysis attribution, and every scan report is retained as a build artifact for a stated period
```

ADR-017's `**Addresses:**` line is `CICD-04, CICD-06 — …`.

**Context pattern** (ADR-016 L11-16): a one-line framing sentence, then **bold-lead constraint
bullets**, each stating a measured fact and its consequence:

```markdown
Four constraints shaped how that layer had to be built:

- **GitHub keys a code scanning analysis on `tool.driver.name` plus `category`, not on the file name.** Two of the six SARIF files carry the identical driver name `Trivy` …
- **The scanning workflow is a reusable `workflow_call`, so its permission set is capped by its caller.** A called workflow can only *downgrade* what it inherits …
```

**Decision pattern** (ADR-016 L20-28): bold-lead bullets, each a full decision sentence, with
the measurement or citation inline:

```markdown
- **Each SARIF file is uploaded individually under a unique, hand-assigned `category`.** The six categories are `semgrep`, `checkov`, `trivy-fs`, … These six strings are therefore a published contract, not an implementation detail.
- **`security-events: write` is granted on the CALLING JOB in `pr-security.yml` and re-declared at workflow level in `security.yml`.** The grant sits on the calling job rather than …
```

ADR-015 L26-29 shows the same shape at smaller scale, including the "X was considered and
rejected" clause that ADR-017 needs for the rejected alternatives (per-step expressions,
terminal gate step, classic branch protection).

**Consequences pattern** (ADR-016 L30-55): opens `**Improved:**` with measured before/after
numbers, then a series of `**Tradeoff — <one-line summary>.**` paragraphs:

```markdown
**Improved:** the pipeline stopped discarding its own output. On PR #8, run `34638828775`, the repository went from `total_count: 0` artifacts and a `404 "no analysis found"` to **seven analyses across the six distinct categories** …

**Tradeoff — no alert is ever associated with the default branch.** This is D-02's direct cost. …
```

**`## What was NOT verified` pattern** (ADR-016 L57-65): two paragraphs — first what *was*
measured and should not be re-litigated, then a numbered list of what remains unverified,
"recorded in those words so that Phases 18 through 20 do not build on them".

**Blind spot the planner must close:** ADR-016 L63 explicitly hands an open item to this phase —
"Whether a Dependabot-triggered run can obtain `security-events: write` is not verified. …
The observation is handed to Phase 18." ADR-017's not-verified section must acknowledge that
hand-off. RESEARCH.md Q3 (fork-PR `vars` availability, L777-795) is the same family of unknown
and is routed to Phase 19 — say so explicitly rather than dropping the thread.

**Content ADR-017 must record** (from CONTEXT.md + RESEARCH.md):
D-01..D-07; the D-06 five-not-six correction with both live observations cited (14-02's
single-job case and this session's 12-name read); the D-07 step-1 correction (red is
unobservable in report-only); the P-06 self-lockout constraint and why this repo stays
report-only; the fail-closed `== 'report-only'` choice.

---

### `docs/adr/README.md` (doc, index)

**Analog:** itself, L25-26 — the rows Phases 16 and 17 appended.

```markdown
| [ADR-015](adr015-tflint-terraform-pin-checking.md) | Adopt tflint for Terraform Provider and Module Pin Checking | 2026-09-11 | Accepted |
| [ADR-016](adr016-sarif-upload-attribution-and-artifact-retention.md) | SARIF Upload Attribution and Scan Artifact Retention | 2026-09-11 | Accepted |
```

Append exactly one row after L26, same four columns, same date format, `Accepted`. Title Case
title matching the ADR's `#` heading verbatim. Nothing else in this file changes.

---

### `docs/development-security-stack-option-1.md` — Phase 2 branch-protection passage (L2019-2028)

**Analog:** itself. The passage sits inside the Phase 2 deliverables block (L2008-2045).
CLAUDE.md's append-only rule covers `docs/adr/` only — the blueprint is editable, subject to
preserving diagrams, the 4-phase layered structure, and the tool matrices.

Current text (note: L2021-2028 are indented **two spaces**, nested under the L2019 deliverable
bullet — preserve that nesting):

```markdown
- Branch protection configured on the `main` branch (required — without this, the CI security gate is advisory-only and provides zero enforcement)

  **Configure in GitHub:** Settings → Branches → Branch protection rules → Add rule
  - Branch name pattern: `main`
  - Enable: **Require a pull request before merging**
  - Enable: **Require status checks to pass before merging** — add each security workflow job as a required check: `sast`, `iac`, `sca`, `container`, `secrets`
  - Enable: **Do not allow bypassing the above settings**
  - Enable: **Restrict who can push to matching branches** (block direct pushes to `main`)

  Without branch protection, a developer can push directly to `main` (bypassing all PR-based scanning), and failing scanner jobs have no effect on merge eligibility. The `continue-on-error` changes described above only enforce quality gates when branch protection makes those status checks required.
```

**Two defects to correct in place:**

1. **L2024 names job IDs, not check-run names** (RESEARCH.md P-08, L558-566). `sast`, `iac`,
   `sca`, `container`, `secrets` are job IDs. Following this text produces five permanently
   pending required checks. Replace with the five byte-exact contexts (see Shared Patterns).
2. **L2021 routes the reader to classic branch protection** (Settings → **Branches**). The
   target repo is on **rulesets**, and the classic `branches/main/protection` endpoint 404s
   by design. RESEARCH.md's UI path (L675-688) is Settings → Rules → Rulesets → **Default** →
   Edit → Branch rules. Rewrite the navigation and the four option bullets to the ruleset
   vocabulary.

L2028's closing paragraph is still correct and should survive the rewrite — it is the
ADR-002/P-09 point that `required_status_checks` without a PR requirement gates nothing.

**Adjacent pre-existing drift — do NOT fix as a side quest:** L2012 lists `Grype + Syft`
(not in the implemented workflow), L2016 says "and direct pushes to `main`" (the workflow is
`pull_request`-only per ADR-016 D-02), L2039 shows a `grype dir:.` command. All three are
outside this phase's boundary. Flagged only so an editor working at L2019-2028 does not
"tidy" them into the diff.

---

---

### `docs/milestone-plan/milestone-2-cicd-gate.md` — M2-F4 section (L98-109)

**Analog:** itself, and the blueprint correction above — this is the **same defect in a second
file**, found by grepping `docs/` for the job-ID list rather than trusting RESEARCH.md's single
P-08 pointer.

```markdown
- GitHub repository Settings > Branches > Branch protection rules
- Required status checks: `sast`, `iac`, `sca`, `container`, `secrets`
- Require PR before merging
- Do not allow bypassing the above settings
- Restrict direct pushes to `main`
```

```markdown
- Settings > Branches shows the protection rule active on `main` with all required checks listed
```

**L99 carries P-08 verbatim** — job IDs presented as required status checks, which produces five
permanently-pending contexts (P-07). **L98 and L109 route to classic branch protection**
(Settings > Branches), which 404s on this repo. Both need the same correction as the blueprint:
the five byte-exact `security / …` contexts and the Settings → Rules → Rulesets path.

L30 of the same file (`` `.github/workflows/security.yml` with 5 jobs: `sast`, `iac`, … ``) is
**correct** — there the strings genuinely are job IDs. Do not change it.

**Planner's call:** whether this file is in Phase 18's scope or is milestone-plan drift left to a
milestone-close task. It is listed here because it is the same user-facing defect CICD-04 exists
to fix, and a reader following it is misled identically.

## Shared Patterns

### DO NOT TOUCH — the eleven ADR-001 tolerance lines

**Source:** `repos/security-platform/.github/workflows/security.yml`
**Applies to:** every edit in that file

```yaml
        continue-on-error: true          # ADR-001: upload failures must not block
```

Lines **60, 124, 197, 244, 379, 616, 671, 755, 805, 885, 932**. These sit on SARIF-upload and
artifact-upload steps. ADR-001 (Accepted, append-only) retains them explicitly: reporting
infrastructure, not enforcement. Conditioning any of them on `gate_mode` violates an accepted
ADR and makes a transient upload hiccup block a merge. RESEARCH.md's verification grep expects
this count to remain exactly **11**.

### The five byte-exact required-check contexts

**Source:** live `gh api repos/…/commits/{sha}/check-runs` read, RESEARCH.md L594-600
**Applies to:** ADR-017, the blueprint correction, any ruleset recipe

```
security / SAST — Semgrep CE
security / IaC — Checkov
security / SCA — Trivy Filesystem
security / Container — Trivy Image
security / Secrets — Gitleaks
```

The separator is an em dash, **U+2014 (`—`)**, not a hyphen. App is `github-actions`,
`integration_id: 15368`. Copy these strings; never retype them. There is **no** check run named
`security` — that token is the caller job id acting as a prefix. `SCA — Trivy Filesystem` is
deliberately inaccurate (four scanners run in that job) and frozen anyway — see the comment at
`security.yml` L285-291.

### SHA-pin with trailing version comment (ADR-004)

**Source:** `security.yml` L37, L61
**Applies to:** any action this phase adds (none is expected)

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
        uses: github/codeql-action/upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63  # v4.38.0
```

Full 40-char commit SHA, two spaces, `# vN.N.N`.

### Frozen-name comment convention

**Source:** `security.yml` L285-291, `pr-security.yml` L19-22
**Applies to:** any new comment explaining why a string cannot change

```yaml
  sca:
    # FROZEN. 15-05-SUMMARY recorded this string as one of the five verbatim
    # check-run names Phase 18 hard-codes into its branch-protection required
    # check list. It is inaccurate now that four scanners run in this job, and
    # it stays anyway: renaming it would leave branch protection pointing at a
    # check that no longer exists — silently non-blocking.
    name: SCA — Trivy Filesystem
```

Pattern: `FROZEN.` + where the string was captured + what breaks if renamed. ADR-017 should
name these five job `name:` values and `pr-security.yml`'s `security` job id as the frozen set.

### Local verification gate (cite in plans; this agent is read-only and did not run it)

**Source:** RESEARCH.md L716-720
**Applies to:** every task touching either workflow file

```bash
cd repos/security-platform
actionlint .github/workflows/security.yml .github/workflows/pr-security.yml   # must exit 0
yamllint -d relaxed .github/workflows/security.yml .github/workflows/pr-security.yml  # must exit 0
```

Both exit 0 on the files as they stand today, so any failure after an edit is attributable to
that edit. Per `.claude/rules/defensive-protocol-v2-anti-slop.md`, any helper script this phase
adds must be invoked as `bash scripts/<name>.sh` with no executable bit.

### Intolerant-assertion comment voice

**Source:** `security.yml` L69-79 (and L139-141, L207-209, L259-261, …)
**Applies to:** the Pattern 5 `gate_mode` validation step

```yaml
      # Deliberately WITHOUT continue-on-error, and deliberately NOT guarded on
      # the upload step itself. ADR-001 tolerates a failed upload; it does not
      # license shipping a phase whose uploads never landed, so the tolerated
      # step above is read back here and a non-success outcome turns this job
      # red. …
      - name: Verify Semgrep SARIF upload landed
        if: always() && github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'
        run: |
          python3 - semgrep.sarif <<'PY'
          …
          PY
```

The new validation step is the same species: it must **not** carry `continue-on-error`, and its
comment must say why in the same voice.

---

## No Analog Found

No file in scope lacks an analog. One conditional entry:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `repos/security-platform/scripts/<ruleset-helper>.sh` (only if the planner decides to script the ruleset read-modify-write) | utility | file-I/O / API | Directory exists (`check-workflow-uploads.sh`, `detect-npm.sh`, `detect-python.sh`, `detect-terraform.sh`, `smoke-scans.sh`) and is the correct analog location, but none was read this session — no excerpt is offered rather than a fabricated one. RESEARCH.md L609-669 supplies the recipe body; RESEARCH.md P-06/Q5 require any live `PUT` to sit behind a `checkpoint:human-verify`, never an autonomous call. |

---

## Metadata

**Analog search scope:** `repos/security-platform/.github/workflows/`, `docs/adr/`, `docs/`
(recursive grep for the P-08 job-ID defect), `repos/security-platform/scripts/` (listing only)
**Files scanned:** 8 read (2 workflows — targeted ranges only for the 962-line `security.yml`,
ADR-002, ADR-015 head, ADR-016, `docs/adr/README.md`, blueprint L1985-2050), plus `.claude/skills/`
front-matter (9 skills; none applicable to GitHub Actions or ADR authoring — none loaded further)
**Source modifications made:** none. This agent is read-only; the only file written is this one.
**Pattern extraction date:** 2026-09-11
