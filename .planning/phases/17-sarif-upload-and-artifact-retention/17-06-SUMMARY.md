---
phase: 17-sarif-upload-and-artifact-retention
plan: 06
subsystem: docs
tags: [adr, documentation, sarif, code-scanning, upload-artifact, retention, blueprint, deferrals]

# Dependency graph
requires:
  - phase: 17-sarif-upload-and-artifact-retention
    provides: "17-01 through 17-04's implemented decisions (caller/callee permission grant, direct trivy-fs SARIF, six categorised uploads, five retained artifacts) and 17-05's live evidence from PR #8 / run 34638828775"
  - phase: 16-sca-ecosystem-coverage
    provides: "16-06's precedent for scoped blueprint reconciliation, invariant-based table verification, and the deferred-items.md format"
provides:
  - "docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md — Accepted, 65 lines, nine Decision bullets covering both user-locked decisions and all five planner decisions"
  - "docs/adr/README.md index row for ADR-016, appended as the file's last line"
  - "A blueprint CI/CD template that is copy-pasteable: workflow-level permissions block with a caller-side warning, category: on every upload-sarif example, retention-days: 90 on every upload-artifact example, and current major version comments"
  - "A 9-row Cross-Platform CI Compatibility table stating which tools can and cannot emit SARIF, with a note linking ADR-016"
  - ".planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md — seven deferrals, each with an owning phase"
affects: [17-07, 18-gate-mode-and-branch-protection, 19-validation, 20-distribution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "An append-only ADR states what the phase did NOT establish as explicitly as what it did — here three named unverified items, so Phases 18-20 cannot silently inherit them as settled."
    - "Blueprint edits are made by anchor text and verified by invariant (even fence count, uniform table pipe count, exact row count, all original rows asserted present) rather than by eye — carried forward from 16-06."

key-files:
  created:
    - docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md
    - .planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md
  modified:
    - docs/adr/README.md
    - docs/development-security-stack-option-1.md

key-decisions:
  - "ADR-016 records PR diff annotation rendering as OBSERVED, not as unverified. The plan (written before 17-05 ran) instructed recording it as not verified; 17-05 §7 measured three annotations on fixtures/main.tf line 38 and answered RESEARCH Q2 YES. Following the plan literally would have understated the evidence and handed Phase 19 a false open question — the exact class of error T-17-28 exists to prevent."
  - "The 'not verified' section therefore names three genuinely open items instead of two: Dependabot security-events grantability (RESEARCH Q3/A8), whether actions/upload-artifact itself succeeds on fork/Dependabot runs where ACTIONS_RUNTIME_TOKEN differs (17-05 §8, explicitly 'still unmeasured'), and how GitHub's ingester treats a ROOTPATH resolving outside the repo (RESEARCH Pitfall 3 — the direct-SARIF decision sidesteps it rather than answering it)."
  - "The measured SARIF inventory table uses the LIVE analyses-API driver names from 17-05 §3 (checkov, Gitleaks) rather than RESEARCH's locally-measured casing (Checkov, gitleaks), and footnotes the analyses-vs-check-runs case mismatch rather than silently mixing the two sets."
  - "Blueprint SARIF categories follow the tool each example actually shows: semgrep, checkov, trivy-image. The blueprint's sca job example still runs Grype, so no trivy-fs or tflint category was invented for a job that does not exist there — that drift is deferral #2, not a drive-by fix."
  - "Inline-flow rendering (`with: { sarif_file: x.sarif, category: x }`) was chosen over expanding to block style, applied consistently to all three SARIF and all five artifact examples — the minimal diff that keeps the blueprint's existing idiom."
  - "No live 40-hex SHA was pasted into the blueprint (verified: grep -cE '@[0-9a-f]{40}' returns 0). Only the version comments changed; every @<SHA> placeholder is intact, per ADR-004."

patterns-established:
  - "Pattern: when a plan's instruction pre-dates evidence collected by an earlier wave, the evidence wins and the divergence is logged as a deviation — the plan is an input, not the arbiter."
  - "Pattern: a deferral row states WHO assigned the owner. Three of the seven owners are not in the plan; they are marked 'assigned by 17-06' so a later reader does not mistake them for a prior decision."

requirements-completed: [CICD-02, CICD-03]

# Metrics
duration: 18min
completed: 2026-09-11
---

# Phase 17 Plan 06: The Decisions Leave The Plan Files — ADR-016, And A Blueprint That Would Actually Upload

**The project's primary artifact taught a workflow that 403s on every SARIF upload — zero `permissions:` blocks, zero `category:` keys, zero `retention-days` — and the phase's seven decisions lived only in plan files. Both are now fixed: a 65-line append-only ADR-016 carries every decision plus three explicitly unverified items, and the blueprint's CI/CD template shows the permission grant, the caller-side warning, six-way category attribution and an explicit 90-day retention.**

## Performance

- **Duration:** ~18 min
- **Completed:** 2026-09-11
- **Tasks:** 2
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments

- **Every decision this phase made now survives outside the plan files.** ADR-016 carries nine bold
  Decision lead-ins: category attribution, the caller-job permission grant, the `outcome`-not-`sarif-id`
  assertion, the ADR-001 tolerated/intolerant pairing, artifact names plus `retention-days: 90`, native
  JSON retention, the `sca` direct-SARIF change, D-01's Criterion 4 resolution, and D-02's trigger decision.
- **The ADR states its own limits as plainly as its conclusions.** A closing section names three things
  **not verified**, in those words, and separately records the two nearby things that *were* measured so
  they are not re-litigated.
- **The blueprint no longer teaches a broken workflow.** It now shows a workflow-level `permissions:` block
  with the caller-side warning that is the single most likely adoption failure, a `category:` on every
  SARIF upload example, and an explicit `retention-days: 90` on every artifact example.
- **Criterion 4's resolution is discoverable from the primary artifact.** The Cross-Platform CI
  Compatibility table went from 6 rows to 9, and the three new rows state the SARIF truth outright: npm
  audit JSON only, pip-audit no SARIF, tflint SARIF native.
- **Nothing was left stale silently.** Seven deferrals, each with an owning phase, and each marked as
  either plan-assigned or 17-06-assigned.

## Task Commits

1. **Task 1: Write ADR-016 and append its index row** — `553b2a2` (docs)
2. **Task 2: Make the blueprint's CI/CD template copy-pasteable, and record the deferrals** — `939b5b3` (docs)

Both committed with hooks; `--no-verify` was not used. Both commits were staged file-by-file, never with
`-a`/`-A`, because the outer repo's working tree carries an unrelated uncommitted `.claude/` tooling update.

## Files Created/Modified

- `docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md` — **created**, 65 lines. Accepted,
  dated 2026-09-11, addresses CICD-02 and CICD-03.
- `docs/adr/README.md` — **modified**, +1 line. One row appended to the single `## Index` table, now the
  file's last line. No other row touched.
- `docs/development-security-stack-option-1.md` — **modified**, +40 / -16. Permissions block, version
  comments, categories, retention, three table rows and one note.
- `.planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md` — **created**, 7 deferrals
  plus one carried-forward item and one observed-not-caused note.

## Required Output: Measured Before/After

### ADR-016's Decision bullet list (nine)

1. Per-file upload under a unique `category` — `semgrep`, `checkov`, `trivy-fs`, `tflint`, `trivy-image`,
   `gitleaks` — with the sticky/orphan warning.
2. `security-events: write` on the calling job in `pr-security.yml`, re-declared at workflow level in
   `security.yml`; `actions: read` carried only for private-repo portability.
3. Upload success asserted on `steps.<id>.outcome`, never on `sarif-id` presence.
4. `continue-on-error: true` retained on every upload **and** paired with an intolerant assertion — eleven
   of them — reconciling ADR-001 with the no-silent-fallback rule.
5. Five artifacts (`semgrep-results`, `checkov-results`, `sca-results`, `trivy-image-results`,
   `gitleaks-results`) with explicit `retention-days: 90`, and why an implicit repo default fails Criterion 3.
6. Each tool's native JSON retained unnormalised, citing the measured `dojo/tools/` parser inventory and
   the `npm_audit_7_plus` detail (runner has npm 10.x).
7. The `sca` job's direct `trivy fs --format sarif` with the measured `ROOTPATH` comparison (input JSON file
   vs scan root, trivy 0.74.0), and `trivy convert` retained in the `container` job.
8. D-01 (USER): Criterion 4 satisfied via the artifact set plus the documented conversion step; pip-audit's
   missing severity field given as the concrete fidelity cost of a hand-rolled converter.
9. D-02 (USER): `pull_request`-only trigger, with the default-branch consequence spelled out.

Consequences: one **Improved:** paragraph, the six-row measured SARIF inventory table, and **five**
`Tradeoff — …` paragraphs (default branch, npm/pip absent from the Security tab, the 90-day ceiling, the
new check runs Phase 18 must evaluate, and the private-repo Code Security licence).

### Blueprint grep counts, before and after

| Reading | Before | After |
|---|---|---|
| `upload-sarif@<SHA>` lines reading `# v3` | 3 (L1515, L1536, L1583) | **0** |
| `upload-sarif@<SHA>` lines reading `# v4` | 0 | **3** |
| `upload-artifact@<SHA>` lines reading `# v4` | 5 (L1519, L1540, L1555, L1587, L1603) | **0** |
| `upload-artifact@<SHA>` lines reading `# v7` | 0 | **5** |
| `retention-days` occurrences | **0** | 6 (5 in YAML + 1 in the explanatory comment) |
| `category:` occurrences | **0** | 4 (3 in YAML + 1 in the explanatory comment) |
| `security-events` occurrences | **0** | 2 (the grant + the caller-side warning comment) |
| Code fences | 134 | **134** (unchanged — no block broken) |
| Live 40-hex SHAs (`@[0-9a-f]{40}`) | 0 | **0** (every `@<SHA>` placeholder intact) |

### Cross-Platform CI Compatibility table

**Before: 6 rows** (Semgrep CE, Checkov, Trivy, Grype, Syft, Gitleaks).
**After: 9 rows** — all six originals unchanged, plus:

| Tool | Install Method | Output Formats |
|---|---|---|
| npm audit | bundled with Node.js | JSON only — no SARIF |
| pip-audit | `pip install pip-audit` | JSON, CycloneDX (JSON and XML), Markdown, Columns — no SARIF |
| tflint | checksum-verified `.zip` release download | SARIF, JSON, Checkstyle, JUnit, Compact, Default |

Uniform pipe count across all 11 table lines, asserted by script. The language matrix at ~L1720 and its
note — both updated by 16-06 — are byte-unchanged (`git diff` shows no `+`/`-` on any matrix row). tflint's
format list was measured from `tflint --help` locally, not recalled.

### The deferral list, with owners

| # | Item | Owner |
|---|---|---|
| 1 | `repos/security-platform/cicd/.github/workflows/security.yml` mirror template, stale since 16-04 | Phase 20 / DIST-06 (plan) |
| 2 | The blueprint's Grype-based `sca:` job example | Phase 20 / DIST-06 (assigned by 17-06) |
| 3 | The blueprint example's own `push: branches: [main]` trigger vs D-02 | Phase 19 / VAL-01 (assigned by 17-06) |
| 4 | `docs/milestone-plan/milestone-2-cicd-gate.md` M2-F3 `grype-results.json`, line 78 | Phase 20 / DIST-06 (assigned by 17-06) |
| 5 | Private-repo GitHub Code Security licence limitation | Phase 20 / DIST-08 (plan) |
| 6 | SARIF size and result limits at consumer scale | Phase 20 (plan) |
| 7 | The blueprint's seven `actions/checkout@<SHA>  # v4` comments (product repo pinned v7.0.0) | Phase 20 / DIST-06 (assigned by 17-06) |

Plus one carried forward from 16-06 (broken relative links in the blueprint, and CLAUDE.md's stale
description of the blueprint's location) and one observed-not-caused note (the uncommitted `.claude/`
tooling update in the outer repo's working tree).

## Decisions Made

See `key-decisions` in the frontmatter. The load-bearing one:

**ADR-016 records the annotation result the phase actually measured.** The plan's `<interfaces>` block and
Task 1 acceptance criteria both instruct closing the ADR by naming "whether PR diff annotations render with
no base analysis" as unverified. That instruction pre-dates 17-05, which measured three annotations on the
constructed line and recorded RESEARCH Q2 as answered YES. Writing it as unverified would have propagated a
false open question into Phase 19 — understated rather than overstated, but still the failure T-17-28
describes. The ADR states it as observed, and the unverified section names three items that genuinely are.

## Deviations from Plan

### 1. The "not verified" content diverges from the plan's list

- **Found during:** Task 1.
- **Issue:** The plan named two unverified items, one of which (annotation rendering) 17-05 had since
  measured as OBSERVED.
- **Fix:** Annotation rendering and `security_events` scope are recorded as measured; the unverified section
  names Dependabot `security-events` grantability, `upload-artifact` behaviour on fork/Dependabot runs, and
  GitHub's handling of an out-of-repo `ROOTPATH`.
- **Verification:** The plan's own automated checks still pass — `grep -qi 'not verified\|unverified'` and
  `grep -qi 'dependabot'` both hit.
- **Committed in:** `553b2a2`.

### 2. The plan's commit-scope verify commands are written against the working tree, not the commit

- **Found during:** Task 1 verification.
- **Issue:** `git diff HEAD~1 --name-only` diffs `HEAD~1` against the **working tree**. With this repo's
  pre-existing uncommitted `.claude/` tooling changes, it listed 139 files and the assertion reported
  `FAIL: files outside docs/adr/` even though the commit itself contained exactly two files.
- **Fix:** Re-ran as `git diff HEAD~1 HEAD --name-only` for both tasks. Task 1's commit contains exactly
  `docs/adr/README.md` and `docs/adr/adr016-…md`; Task 2's contains exactly
  `docs/development-security-stack-option-1.md` and the deferred-items file.
- **Verification:** Both corrected assertions pass. No file was staged that was not named in the plan.
- **Committed in:** n/a — a verification-script defect, not a content change. Recorded so a future plan does
  not copy the two-arg-less form into a repo with a dirty tree.

---

**Total deviations:** 2 — one evidence-over-plan correction, one verify-script correction.
**Impact on plan:** none on scope or file set. Both commits landed exactly the files the plan named.

## Issues Encountered

**1. `markdownlint` is not on PATH under that name; `markdownlint-cli2` is.** The plan's verify step
tolerates absence. Actual output recorded: `markdownlint-cli2 v0.21.0 (markdownlint v0.40.0)` →
`Summary: 0 error(s)` across all four touched markdown files, under the repo's `.markdownlint.jsonc`
(which disables MD013/MD024/MD036/MD040/MD060).

**2. The blueprint's `sca:` job example has no Trivy filesystem or tflint step**, so only three of the six
live categories had a home in the blueprint (`semgrep`, `checkov`, `trivy-image`). Inventing `trivy-fs` and
`tflint` categories for a Grype example would have taught something the example does not do. Recorded as
deferral #2 instead.

No unresolved issues.

## User Setup Required

None — documentation only, zero installs, zero executable content. **PR #8 on
`OttawaCloudConsulting/security-platform` remains OPEN and unmerged**; 17-07 owns it, and this plan touched
nothing under `repos/`.

## Next Phase Readiness

- **17-07** can score the phase's criteria against ADR-016 as the written record, and should read Criterion 1
  under the branch/PR filter as the ADR states.
- **Phase 18** inherits the ADR's Tradeoff paragraph naming the per-driver check-run rule, the red `Checkov`
  check, and the analyses-vs-check-runs case mismatch — plus two of the three unverified items, both about
  fork/Dependabot runs.
- **Phase 19 (VAL-01)** inherits deferral #3 (the blueprint's `push: branches: [main]` divergence) and a
  positive annotation result rather than an open question.
- **Phase 20** inherits five of the seven deferrals, including the private-repo licence limitation that
  DIST-08's adoption docs must state before a consumer commits.
- **No blockers.**

---
*Phase: 17-sarif-upload-and-artifact-retention*
*Completed: 2026-09-11*
