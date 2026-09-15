# Phase 21: Docs cleanup — close remaining Phase 20 deferred items - Research

**Researched:** 2026-09-15
**Domain:** Documentation drift reconciliation against a live GitHub Actions pipeline; GitHub code-scanning SARIF upload limits; DefectDojo parser naming
**Confidence:** HIGH

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Milestone doc Grype→SCA fix

- **D-01:** Fix all 5 Grype mentions in `docs/milestone-plan/milestone-2-cicd-gate.md` for full
  consistency, not just line 78 (the deferred-item's literal citation). Locations: L16 (feature
  table), L33 and L43 (Done Criteria examples), L78 (JSON output list), L85 (DefectDojo parser
  artifact-name row).
- **D-02:** Replace Grype with the live SCA tool set by name where the doc lists specific tools:
  "Trivy filesystem, npm audit, pip-audit, tflint" (matching how the live job/blueprint/adoption
  guide already describe it elsewhere) — not a generic "SCA scan" placeholder.
- **D-03:** JSON output filename becomes `sca-results.json` (the live artifact name), replacing
  `grype-results.json`.
- **D-04:** DefectDojo parser artifact-name row drops "Anchore Grype", becomes "Trivy Scan" (or
  the correct live artifact/parser name for the sca job — researcher to confirm exact wording
  against the live workflow/adoption-guide before planner locks the replacement text).

#### SARIF size/result ceiling documentation

- **D-05:** Add a new subsection in `docs/adoption-guide.md` near §6 ("First Run — What to
  Expect"), where SARIF/artifact counts are already discussed, covering GitHub code-scanning
  SARIF upload limits.
- **D-06:** The specific numbers (candidates from deferred-items.md #6, UNVERIFIED against live
  GitHub docs: 10 MB gzipped per file, 20 runs per file, 25,000 results per run, 25,000 rules per
  run) must be re-verified by the research phase against GitHub's current published limits before
  the planner locks the text — do not copy them from deferred-items.md as-is.
- **D-07:** Note this repo's fixture scale never approached these limits (largest run: 56 results,
  per deferred-items.md #6) as context for why it wasn't caught here, and that a consumer repo
  running Semgrep `p/default` or a large image scan can plausibly exceed them.

### Claude's Discretion

- Exact wording/formatting of the new adoption-guide.md subsection (heading level, whether it's a
  bullet list or a short paragraph) — follow the existing style of §6.
- Whether the milestone-plan doc's M2-F1 feature-table cell needs rewording beyond substituting the
  tool list (e.g., cross-referencing the live job name) — keep changes minimal, consistency is the
  goal, not a rewrite.

### Deferred Ideas (OUT OF SCOPE)

- **Blueprint's own Grype-based SCA job example** (`docs/development-security-stack-option-1.md`
  lines 41, 61, 130, 304-366, 1580-1594, 2076) — deferred-items.md #2, explicitly flagged as "an
  unbounded blueprint change" and out of scope for this phase. Not touched here.
- **Blueprint's `push: branches: [main]` trigger divergence** — deferred-items.md #3, ownership gap
  (Phase 19/VAL-01 closed without touching it). Not this phase's problem; flagged for a future
  docs-hygiene pass, no current owner.
- **Broken relative ADR links in the blueprint doc** — carried forward from Phase 16/17, still
  open, no owner assigned. Not in this phase's scope (roadmap doesn't cite it).
- **The "7 stale `# v4` action-version comments"** bullet in ROADMAP.md's Phase 21 entry — already
  CLOSED by Phase 20.1 (deferred-items.md item #7). Explicitly dropped by the user. Do not
  research, plan, or re-count it.

### Researcher-flagged constraint conflicts

Three locked decisions are contradicted or under-specified by primary-source evidence gathered this
session. Each is detailed in **Constraint Conflicts** below with the evidence and a recommended
amendment. The planner must not lock D-03's text as written.

</user_constraints>

## Summary

This phase edits two markdown files. Every factual value it needs to write down was verifiable from a
primary source in this session, and all four were checked: the live callable workflow
(`OttawaCloudConsulting/security-platform` `.github/workflows/security.yml`, fetched via `gh api` and
`diff`-confirmed byte-identical to the local clone at `repos/security-platform/.github/workflows/security.yml`),
this project's own measured-run records in `.planning/STATE.md`, GitHub's docs source repo
(`github/docs`), and DefectDojo's parser source (`DefectDojo/django-DefectDojo` `dojo/tools/*/parser.py`).
The research is therefore HIGH confidence throughout, with no LOW-confidence claims and no open
technical questions.

Three of the seven locked decisions in `21-CONTEXT.md` do not survive contact with the live pipeline and
need amendment before the planner writes task text. **D-03 is factually wrong:** `sca-results` is the
*artifact* name, not a JSON filename — no file called `sca-results.json` exists anywhere in the live
pipeline. The SCA job's JSON outputs are `trivy-fs.json`, `npm-audit-<N>.json` and `pip-audit-<N>.json`
(plus the SARIF-only `tflint.sarif`). **D-04's proposed "Trivy Scan"** is the correct DefectDojo parser
for `trivy-fs.json`, but that exact string already occupies the container slot on the same line, so a
naive substitution produces a list that reads like a typo; a per-job qualified form is needed. **D-06's
candidate numbers are all correct** (10 MB gzipped, 20 runs/file, 25,000 results/run, 25,000 rules/run)
but deferred-items.md's framing is incomplete: the number a consumer repo running Semgrep `p/default`
will actually hit first is the **5,000-result display truncation**, not the 25,000 rejection ceiling.

Two second-order effects sit outside D-01's literal five-line scope but are created *by* this phase's
edit: `docs/milestone-plan/milestone-4-defectdojo.md` carries the identical `Anchore Grype` parser list
at L75 and an impossible Trivy-vs-Grype dedup example at L105, and the line being edited
(`milestone-2-cicd-gate.md` L78) also carries a second wrong filename (`trivy-results.json`; live is
`trivy-image.json`) that D-01 does not mention.

**Primary recommendation:** Amend D-03, qualify D-04, and extend D-06's wording before planning; then
execute as two independent single-file edits, each gated by a grep assertion plus `markdownlint-cli2`,
with `bash scripts/check-adoption-guide.sh` required to stay at PASSED 15 / FAILED 0.

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIST-06 | Copy-paste workflow template packaged for manual adoption into a consumer repo | The milestone-plan doc is the requirements-level description a manual adopter reads before copying; naming a scanner (Grype) the template does not contain makes the packaged description untrue. §Live Pipeline Ground Truth supplies the five job ids, five artifact names, and every emitted filename so the doc can be made byte-accurate against the live template. |
| DIST-08 | Adoption docs cover both consumption modes, written for rollout to the remaining 6+ repos | §6 of `docs/adoption-guide.md` tells an adopter what a first run produces but states no upload ceiling, so a larger consumer repo gets no warning before a rejected SARIF upload. §GitHub SARIF Upload Limits supplies the verified numbers, the exact rejection error strings, and the truncation behaviour an adopter needs. |

</phase_requirements>

## Architectural Responsibility Map

This phase writes prose, not code. "Tier" here means *which surface owns the statement of fact*, which
is the analogous question and is the one that keeps the edit minimal.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Naming the scanners the CI gate actually runs | Live workflow (`security-platform` `security.yml`) | `docs/milestone-plan/milestone-2-cicd-gate.md` | The workflow is the sole source of truth; the milestone doc is a derived description and must be reconciled *toward* it, never the reverse. |
| Stating emitted artifact and file names | Live workflow `upload-artifact` blocks + measured run records in STATE.md | milestone-2 doc L78 | Names are already measured (STATE.md L121, live PR #8 / run 34638828775); the doc restates them. |
| DefectDojo parser/scan-type strings | DefectDojo source `dojo/tools/*/parser.py` `get_scan_types()` | milestone-2 L85, milestone-4 L75 | Parser names are DefectDojo's API contract, not this project's choice; both milestone docs are consumers of that contract. |
| GitHub platform upload ceilings | `docs.github.com` (source: `github/docs`) | new `###` subsection in `docs/adoption-guide.md` §6 | Platform limits are GitHub's to define; the adoption guide may only cite them, with a link, and must not restate them as project policy. |
| Consumer-facing "what to expect" narrative | `docs/adoption-guide.md` §6 | — | §6 already owns first-run expectations, artifact counts, and the "green does not mean clean" caveat. The limits note belongs here and nowhere else. |
| Enforcing that the adoption guide stays internally consistent | `scripts/check-adoption-guide.sh` | markdownlint-cli2 config | The standing gate owns verification; the plan must not hand-verify what the gate already asserts. |

## Constraint Conflicts

> These three items contradict or materially under-specify `21-CONTEXT.md`'s locked decisions. Evidence
> is primary-source and reproducible. The planner should treat these as required amendments, surfaced
> to the user if the planner lacks authority to amend a locked decision.

### CONFLICT-1 (blocking): D-03's `sca-results.json` does not exist

**D-03 says:** "JSON output filename becomes `sca-results.json` (the live artifact name), replacing
`grype-results.json`."

**Evidence it is wrong** [VERIFIED: live workflow source via `gh api`]:

`sca-results` is the value of `with: name:` on the SCA job's `actions/upload-artifact` step
(`security.yml:842`) — that is the **artifact** name, the label the bundle appears under on the run
page. It is not a filename, and appending `.json` to it names a file the pipeline never writes. The
`path:` list on that same step (`security.yml:843-848`) enumerates the actual files:

```text
trivy-fs.json
trivy-fs.sarif
npm-audit-*.json
pip-audit-*.json
tflint.sarif
```

Independently corroborated by a measured live download [VERIFIED: `.planning/STATE.md` L121]:
"sca-results downloads as npm-audit-1.json, pip-audit-1.json, tflint.sarif, trivy-fs.json,
trivy-fs.sarif, proving 17-04's glob."

Note also that L78 is a list of **JSON** outputs, so `tflint.sarif` and `trivy-fs.sarif` do not belong
in it — tflint contributes no JSON to this pipeline at all.

**Recommended amendment (D-03′):** on L78, replace the single token `grype-results.json` with the SCA
job's three real JSON filenames, marking the two ecosystem-conditional ones as such:

```text
`trivy-fs.json`, plus `npm-audit-<N>.json` and `pip-audit-<N>.json` where the matching ecosystem
sub-scan fires
```

`<N>` (not `*`) matches the workflow's own loop counter (`npm-audit-${i}.json`, `security.yml:619`;
`pip-audit-${i}.json`, `security.yml:681`) and the measured `npm-audit-1.json` / `pip-audit-1.json`.

### CONFLICT-2 (needs wording, not a re-decision): D-04's "Trivy Scan" collides with the container slot

**D-04 says:** the parser row "drops 'Anchore Grype', becomes 'Trivy Scan'".

`Trivy Scan` *is* the correct DefectDojo parser for `trivy-fs.json` [VERIFIED: `dojo/tools/trivy/parser.py`
`get_scan_types()` → `["Trivy Scan"]`]. But L85 already reads
`Semgrep JSON Report, Checkov Scan, Anchore Grype, Trivy Scan, Gitleaks Scan`, where the existing
`Trivy Scan` is the container job's slot. Substituting Grype→`Trivy Scan` yields
`... Checkov Scan, Trivy Scan, Trivy Scan, Gitleaks Scan` — correct in DefectDojo terms (one parser, two
imports) but indistinguishable from a copy-paste error to any reader.

Two further parsers are needed because the live SCA job emits three JSON formats, not one
[VERIFIED: DefectDojo parser source]:

| Live SCA file | DefectDojo `get_scan_types()` string | Source |
|---|---|---|
| `trivy-fs.json` | `Trivy Scan` | `dojo/tools/trivy/parser.py` |
| `npm-audit-<N>.json` | `NPM Audit v7+ Scan` | `dojo/tools/npm_audit_7_plus/parser.py` |
| `pip-audit-<N>.json` | `pip-audit Scan` | `dojo/tools/pip_audit/parser.py` |
| `tflint.sarif` | `SARIF` (generic) | `dojo/tools/sarif/parser.py` |

`NPM Audit v7+ Scan` — not `NPM Audit Scan`, and not the docs-site label "NPM Audit Version 7+" — is the
API string. The v7+ variant is the right one here [VERIFIED: `.planning/STATE.md` L115]: "The runner's
npm is 10.x, so the applicable parser is npm_audit_7_plus, not the legacy npm_audit." The legacy
`NPM Audit` parser only accepts v6-and-older output.

**Recommended amendment (D-04′)** — per-job qualification, keeping the row a single line and the
five-job shape intact:

```text
- Artifact names match the expected DefectDojo parser input: Semgrep JSON Report, Checkov Scan,
  Trivy Scan (SCA filesystem — plus NPM Audit v7+ Scan and pip-audit Scan where the ecosystem
  sub-scans fire), Trivy Scan (container image), Gitleaks Scan
```

If the planner prefers to keep the line to exactly five bare parser names, the minimum defensible form
is `Trivy Scan (filesystem), ... Trivy Scan (image)` with the npm/pip parsers named in a following
bullet. Either is within Claude's Discretion; leaving one bare duplicated `Trivy Scan` is not.

### CONFLICT-3 (extends, does not contradict, D-06/D-07): the ceiling a consumer hits first is 5,000, not 25,000

All four of D-06's candidate numbers are confirmed correct (see §GitHub SARIF Upload Limits). But
deferred-items.md #6's rationale — "can plausibly exceed 25,000 results, and the upload would be
rejected" — describes the *second* thing a large consumer repo encounters. GitHub truncates display to
the **top 5,000 results per run, prioritized by severity**, long before the 25,000 rejection ceiling
[VERIFIED: `github/docs` `data/reusables/code-scanning/sarif-limits.md`]. A Semgrep `p/default` run on a
large monorepo reaching, say, 8,000 findings uploads successfully, shows 5,000 alerts, and silently
drops 3,000 — which is exactly the failure mode D-05 exists to warn about, and it is invisible unless
documented. The planner should have the new subsection state both thresholds and the different
consequence of each.

## Live Pipeline Ground Truth

**Source:** `OttawaCloudConsulting/security-platform` `.github/workflows/security.yml`, fetched
2026-09-15 via `gh api repos/OttawaCloudConsulting/security-platform/contents/.github/workflows/security.yml`.
`diff` against the in-repo clone `repos/security-platform/.github/workflows/security.yml` reports **no
differences** — the local clone the standing gate derives its frozen strings from is current with
origin/main, so the gate is safe to treat as ground truth. [VERIFIED: `gh api` + `diff`]

### Five jobs, five artifacts, every emitted file

| Job id | `name:` (frozen check-run suffix) | Artifact name | JSON file(s) | SARIF file(s) |
|--------|-----------------------------------|---------------|--------------|---------------|
| `sast` | `SAST — Semgrep CE` | `semgrep-results` | `semgrep-results.json` | `semgrep.sarif` |
| `iac` | `IaC — Checkov` | `checkov-results` | `checkov-results.json` | `checkov.sarif` |
| `sca` | `SCA — Trivy Filesystem` | `sca-results` | `trivy-fs.json`, `npm-audit-<N>.json`, `pip-audit-<N>.json` | `trivy-fs.sarif`, `tflint.sarif` |
| `container` | `Container — Trivy Image` | `trivy-image-results` | `trivy-image.json` | `trivy-image.sarif` |
| `secrets` | `Secrets — Gitleaks` | `gitleaks-results` | `gitleaks-results.json` | `gitleaks.sarif` |

Every separator in the `name:` values is U+2014 EM DASH, not a hyphen — `scripts/check-adoption-guide.sh`
asserts this byte-exactly (`bytes: ... e2 80 94 ...`). Any doc text that reproduces a check-run context
must use U+2014. [VERIFIED: gate output, 2026-09-15]

### What the L78 list gets wrong

L78 currently reads
`` `semgrep-results.json`, `checkov-results.json`, `grype-results.json`, `trivy-results.json`, `gitleaks-results.json` ``.

| Token | Live status |
|---|---|
| `semgrep-results.json` | **correct** (`security.yml:180`) |
| `checkov-results.json` | **correct** (`security.yml:316`) |
| `grype-results.json` | **wrong** — no Grype in the pipeline; see CONFLICT-1 |
| `trivy-results.json` | **wrong** — live container JSON is `trivy-image.json` (`security.yml:1036`) |
| `gitleaks-results.json` | **correct** (`security.yml:1181`) |

**Correction to the record:** the Phase 20.1 status re-check in `deferred-items.md` states L78 lists
"5 filenames that all diverge from the live artifact names." That is inaccurate — three of the five
match live exactly. Only `grype-results.json` and `trivy-results.json` diverge. The planner should not
plan a five-token rewrite on the strength of that sentence.

`trivy-results.json` is a real, second defect on the exact line D-01 already opens, and Claude's
Discretion states "consistency is the goal." **Recommendation: fix it in the same edit** rather than
leaving a known-wrong filename on a line this phase just touched. If the user declines, it must become
a new deferred item with an owner, not an unrecorded omission.

### The SCA job's composition, verified step by step

CONTEXT.md's claim "Trivy filesystem + npm audit + pip-audit + tflint" is confirmed exactly
[VERIFIED: live workflow step names and `run:` bodies]:

| Step | Line | Command / behaviour |
|---|---|---|
| Run Trivy filesystem scan (JSON for retention) | 501 | `trivy fs . --scanners vuln --format json --output trivy-fs.json --exit-code 1 --severity HIGH,CRITICAL` |
| Run Trivy filesystem scan (SARIF for code scanning) | 520 | identical flags, `--format sarif --output trivy-fs.sarif`. Deliberately a second scan, **not** `trivy convert` |
| SCA-01 — npm audit | 607 | `npm audit --audit-level=high --json` per discovered `package-lock.json`, guarded by `steps.npm.outputs.found == 'true'` |
| SCA-02 — pip-audit | 670 | `pip-audit -r <req> --format json --progress-spinner=off -o pip-audit-<N>.json`, guarded by `steps.py.outputs.found == 'true'` |
| SCA-03 — tflint (SARIF) | 735 | SARIF only; contributes **no JSON** |

The job's `name:` is `SCA — Trivy Filesystem`, which is why the milestone doc's own M2-F4 section (L99)
*already* names `security / SCA — Trivy Filesystem` correctly. The doc is therefore internally
inconsistent today: M2-F1/F3 say Grype, M2-F4 says Trivy Filesystem. Fixing the five Grype sites
resolves that inconsistency as a side effect — worth stating in the plan's rationale.

### Measured finding counts (for D-07)

| Run | Counts | Source |
|---|---|---|
| PR #12 (Phase 19-06), quoted verbatim in `docs/adoption-guide.md` §6 | 8 Semgrep, 11 Gitleaks, 14 Checkov, **58 Trivy image**, 6 Trivy filesystem, 3 tflint | [VERIFIED: `docs/adoption-guide.md:242-245`; `.planning/STATE.md` L147] |
| deferred-items.md #6's figure | "largest run: 56 results" | [CITED: `deferred-items.md`] — a different run, not reconciled to PR #12 |

**Consistency trap:** D-07 instructs the planner to write "largest run: 56 results," but the new
subsection lands three paragraphs below §6's existing "58 Trivy image findings." Printing 56 next to 58
in the same section invites a reader to think one is wrong. **Recommendation:** cite §6's own already-published
figure — e.g. "the largest single-tool count this project has measured is 58 (Trivy image, section 6
above)" — or phrase it scale-wise ("fewer than 60 findings from any one tool"). Do not introduce 56.

## GitHub SARIF Upload Limits

All values below are read from the GitHub docs **source repository**, not from a rendered page, so the
wording is exact and the provenance is auditable.

### File size

> "For each gzip-compressed SARIF file, SARIF upload supports a maximum size of 10 MB. Any uploads over
> this limit will be rejected."

[VERIFIED: `github/docs` → `content/code-security/reference/code-scanning/sarif-files/sarif-support.md`,
line 103, fetched via `gh api` 2026-09-15]

No uncompressed-size limit is published. **D-06's "10 MB gzipped per file" is CONFIRMED.**

### The objects table

[VERIFIED: `github/docs` → `data/reusables/code-scanning/sarif-limits.md`, last modified
2024-10-18T18:40:48Z, commit `313e02ea840443079c34bac0ed033440514f81c7`]

| SARIF data | Maximum values | Data truncation limits |
|---|---|---|
| Runs per file | 20 | None |
| Results per run | 25,000 | Only the top 5,000 results will be included, prioritized by severity. |
| Rules per run | 25,000 | None |
| Tool extensions per run | 100 | None |
| Thread Flow Locations per result | 10,000 | Only the top 1,000 Thread Flow Locations will be included, using prioritization. |
| Location per result | 1,000 | Only 100 locations will be included. |
| Tags per rule | 20 | Only 10 tags will be included. |
| Alert Limit | 1,000,000 | None |

**All four of D-06's candidate numbers are CONFIRMED:** 20 runs per file, 25,000 results per run,
25,000 rules per run, and the 10 MB gzipped file size above.

### Maximum vs. truncation — the distinction the doc must get right

Two columns, two different consequences. Getting these backwards would put a false statement into a
consumer-facing guide, so both governing sentences are quoted:

> "Code scanning supports uploading a maximum number of entries for the data objects in the following
> table. **If any of these objects exceeds its maximum value the SARIF file is rejected.** For some
> objects, there is also an additional limit on the number of values that will be displayed."
> — `sarif-support.md`, line 105 (emphasis added)

And the troubleshooting page defines the two classes:

> "Soft limits which determine how much data is stored and displayed to users. Hard limits which
> determine the maximum amount of data accepted for processing."
> — `troubleshoot-sarif-uploads/results-exceed-limit.md`

Therefore, for results per run:

| Result count in one run | Outcome |
|---|---|
| ≤ 5,000 | accepted, all results displayed |
| 5,001 – 25,000 | **accepted**, upload succeeds, but only the top 5,000 are displayed, prioritized by severity; a soft-limit warning is emitted |
| > 25,000 | **rejected** — `Analysis SARIF file rejected due to result limits` |

⚠️ **A rendered-page summary read during this session mislabelled 25,000-results-per-run as a "soft
limit" that merely truncates.** The source prose above contradicts that: the *Maximum values* column is
the hard limit and exceeding it rejects the file; the *Data truncation limits* column is an additional
display ceiling that applies *below* the maximum. The planner must not write "soft limit" against the
25,000 figure. [VERIFIED: both doc sources above]

### Exact error strings (useful if the subsection tells adopters what they would see)

Rejection (hard limit) messages, verbatim from `results-exceed-limit.md`:

```text
Analysis SARIF file rejected due to result limits
Analysis SARIF file rejected due to rule limits
Analysis SARIF file rejected due to run limits
Analysis SARIF file rejected due to extension limits
Analysis SARIF file rejected due to location limit
Analysis SARIF file rejected due to rule tag limits
All analysis uploads blocked due to alert limit
```

Warning (soft limit) messages:

```text
Analysis SARIF file exceeded alert limits
Locations for an alert exceeded limits
Rule tags in SARIF file exceed limits
Alert in SARIF upload exceeded thread flow location limits
Repository is at risk of exceeding the alert limit.
```

One further fact worth a single clause, because it is the only limit with no self-service recovery:
exceeding the 1,000,000 **Alert Limit** blocks *all* further analysis uploads, and
"**There is no self-service method for deleting alerts at this time, so contacting customer support is
necessary before code-scanning can be re-enabled.**" [VERIFIED: `results-exceed-limit.md`] This is
almost certainly beyond D-05's scope; included so the planner can decide rather than not know.

### Per-hour upload ceiling: none found

A code search across `github/docs` for `"uploads per hour"` and for a code-scanning-specific rate limit
returned **zero** matching files. The only published ceilings are the 10 MB gzipped file size and the
objects table above. [VERIFIED: `gh api search/code` on `github/docs`, 2026-09-15 — negative result from
the docs source repo, not merely "not found on a rendered page"]

**Do not state or imply an uploads-per-hour limit** in the new subsection. If one exists it is
undocumented, and a documented guide must not invent it.

### Canonical URLs to cite (200, not 301)

These pages moved. Cite the current paths — all three return HTTP 200, verified by `curl` 2026-09-15:

- `https://docs.github.com/en/code-security/reference/code-scanning/sarif-files/sarif-support` — the 10 MB limit and the objects table
- `https://docs.github.com/en/code-security/reference/code-scanning/sarif-files/troubleshoot-sarif-uploads/results-exceed-limit` — soft/hard distinction, error strings
- `https://docs.github.com/en/code-security/reference/code-scanning/sarif-files/troubleshoot-sarif-uploads/file-too-large` — remediation for the size limit

**Do not cite** `https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning`
— it returns **301** to the first URL above. [VERIFIED: `curl -o /dev/null -w "%{http_code}"`]

## DefectDojo Parser Names (primary source)

All strings below are the literal return values of `get_scan_types()` in DefectDojo's own parser
modules, fetched from `DefectDojo/django-DefectDojo` `master` via `gh api` on 2026-09-15. The docs site
sometimes shows a different display label (e.g. "NPM Audit Version 7+"); the API string is what an
import call must send. [VERIFIED: DefectDojo source]

| Module | `get_scan_types()` | Note |
|---|---|---|
| `dojo/tools/semgrep/parser.py` | `["Semgrep JSON Report"]` | matches L85 today — leave as is |
| `dojo/tools/checkov/parser.py` | `["Checkov Scan"]` | matches L85 today — leave as is |
| `dojo/tools/gitleaks/parser.py` | `["Gitleaks Scan"]` | matches L85 today — leave as is |
| `dojo/tools/trivy/parser.py` | `["Trivy Scan"]` | description: "Import trivy JSON scan report." Covers both filesystem and image JSON |
| `dojo/tools/npm_audit_7_plus/parser.py` | `["NPM Audit v7+ Scan"]` | description: "NPM Audit Scan json output from v7 and above." |
| `dojo/tools/pip_audit/parser.py` | `["pip-audit Scan"]` | lowercase `p`, hyphen — not "Pip-Audit Scan" |
| `dojo/tools/sarif/parser.py` | `["SARIF"]` | the generic parser `tflint.sarif` would use |
| `dojo/tools/anchore_grype/parser.py` | `["Anchore Grype", "Anchore Grype detailed"]` | still a real parser — it is the *pipeline* that no longer runs Grype, not the parser that vanished |

That last row matters for the plan's rationale: the fix is not "the parser name was wrong," it is "the
pipeline no longer produces input for that parser."

## Second-Order Effects

> Project rule (`defensive-protocol-v2-anti-slop.md`): "Before changing anything, list what
> reads/writes/depends on it." These are the surfaces that depend on the strings this phase edits.

### SE-1 — `docs/milestone-plan/milestone-4-defectdojo.md` carries the identical drift (needs a decision)

```text
L75: - 5 scanner parsers: `Semgrep JSON Report`, `Checkov Scan`, `Anchore Grype`, `Trivy Scan`, `Gitleaks Scan`
L105: - Deduplication enabled: import the same CVE from both Trivy and Grype — DefectDojo merges them into a single finding
```

[VERIFIED: `grep -n -i grype docs/milestone-plan/milestone-4-defectdojo.md`]

L75 is the **same list** as milestone-2 L85. Fixing M2 and not M4 makes the two milestone docs
contradict each other on the same contract — replacing one inconsistency (doc vs. pipeline) with
another (doc vs. doc). L105 is worse than stale: the dedup example it describes is now *impossible*,
because there is no Grype run to import a duplicate CVE from.

CONTEXT.md's D-01 scopes the edit to `milestone-2-cicd-gate.md` only, and M4 is a future milestone whose
parser list is arguably an M4-time decision. **This needs a user decision, not a researcher's
judgement.** The two defensible outcomes:

1. Apply the identical L75 substitution in M4 in the same phase (one line, zero new reasoning), and
   reword L105's dedup example to a pair that actually co-occurs (e.g. Trivy filesystem and npm audit
   both reporting a CVE for the same npm package).
2. Record both as a new deferred item **with a named owner** in
   `.planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md` or a Phase 21
   deferred-items file.

Doing neither leaves the phase having created fresh drift. Recommend option 1 for L75 (trivial, and it
is the same contract) and option 2 for L105 (needs editorial thought about what the replacement example
should be).

### SE-2 — `trivy-results.json` on the line being edited

Covered in §Live Pipeline Ground Truth. Recommend fixing in the same edit; otherwise record it.

### SE-3 — `grype` appears in seven other `docs/` files; none are in scope

[VERIFIED: `grep -rln -i grype docs/`]

| File | In scope? | Why |
|---|---|---|
| `docs/development-security-stack-option-1.md` | **No** | deferred-items #2, explicitly deferred by CONTEXT.md |
| `docs/milestone-plan/milestone-4-defectdojo.md` | **Decision needed** | see SE-1 |
| `docs/milestone-plan/milestone-1-workstation.md` (4 hits) | **No** | M1-F3 is the *workstation* CLI tool suite; Grype is genuinely installed locally there. Not drift. |
| `docs/milestone-1-workstation/{INSTALLATION,USER,DEVELOPER}_GUIDE.md` | **No** | same — local workstation tooling |
| `docs/adr/adr001`, `adr010`, `adr015` | **No** | ADRs are append-only per repo CLAUDE.md; historical decisions are not corrected retroactively |

Explicitly listing these prevents an over-eager `grep -rl grype \| xargs sed` from wrecking M1 docs or
violating the append-only ADR rule.

## Editing Constraints (adoption-guide.md)

### Heading level is forced, not a style choice

`docs/adoption-guide.md` numbers its top-level sections `## 1.` … `## 13.` and cross-references them
**by number** in prose ("see section 6", "section 8", "section 11") in 16 places
[VERIFIED: `grep -on 'section [0-9]*' docs/adoption-guide.md`]. Inserting a new `## 7.` would force
renumbering §7–§13 *and* auditing all 16 cross-references — a large, high-risk diff for a two-paragraph
addition.

**The new content must be a `###` subsection inside `## 6.`** This is consistent with D-05 ("near §6")
and needs no renumbering and no cross-reference edits. §6 has no `###` children today, but §2 and §12
do, so the pattern is established in the file.

### Insertion point

§6 spans lines 218–262; `## 7. Gate-Mode Selection` begins at line 264.

- **Recommended:** insert after line 257 (the close of the `gh run download` fenced block plus its
  blank line), i.e. *before* the "Before you consider switching to `blocking`" paragraph at 259–262.
  That paragraph is a deliberate bridge into §7 and should stay last in the section.
- Acceptable alternative: append at line 263, immediately before `## 7.`, accepting that the §7 bridge
  is no longer the section's final paragraph.

### The standing gate must stay green

`bash scripts/check-adoption-guide.sh` currently reports **PASSED 15 / FAILED 0** (exit 0), measured
2026-09-15. [VERIFIED: executed this session] It is the phase's primary verification command for the
adoption-guide edit. Assertions the new text could plausibly break:

| Assertion | Constraint on new text |
|---|---|
| `SIXTH-CONTEXT` | Introduce **no new** `security / …` string. The gate flags any such string not in the derived five. |
| `CONTEXT-EM-DASH` / `CONTEXT-PRESENCE` | Do not alter the five existing verbatim contexts; any em dash typed as a hyphen is a failure. |
| `MARKDOWNLINT` | `markdownlint-cli2` must report **zero** violations on the guide. |
| `BANNED-PATTERNS` | `\|\| true` and `--config auto` must not appear outside labelled anti-pattern blocks. |
| `NO-OCC-GITHUB` | The string `OCC-github` must not appear (it is this working directory's path — easy to paste in by accident). |
| `RAW-GITHUBUSERCONTENT-PIN` | Any `raw.githubusercontent.com` URL must be pinned at `/v1/`. New text should add none. |
| `REUSABLE-WORKFLOW-REF` | Any reusable-workflow ref must be the canonical path at `@v1`/`@v1.0.0`. New text should add none. |

Preflight note: the gate exits **2** (infrastructure, not a doc defect) if
`repos/security-platform/.github/workflows/` is absent or `python3 -c 'import yaml'` fails. Both are
present and working here.

### markdownlint rules that actually bite

⚠️ **Two config files exist and the stricter one wins — do not read `.markdownlint-cli2.yaml` alone.**

`.markdownlint-cli2.yaml` has a `config:` block disabling ten rules (MD013, MD018, MD022, MD024, MD029,
MD031, MD032, MD036, MD040, MD060). That block is **overridden** by the repo-root `.markdownlint.jsonc`,
which is the config markdownlint-cli2 v0.21.0 actually applies. `.markdownlint.jsonc` disables only:

```json
MD024, MD036, MD040, MD060, MD013 / line-length
```

**Everything else — including MD022, MD031, MD032, MD018 and MD029 — is ENABLED.**

[VERIFIED: measured empirically this session. A three-line probe file placed in `docs/` with a heading
lacking surrounding blank lines produced `MD022/blanks-around-headings` twice, proving MD022 is live for
`docs/` despite `.markdownlint-cli2.yaml` disabling it. The same discrepancy surfaced while linting this
research document.] `scripts/check-adoption-guide.sh`'s own header comment names only "MD001, MD009,
MD010, MD025, MD034" as the enabled rules — that comment is **incomplete**; trust the probe, not the
comment.

| Rule | Why it matters for this edit |
|---|---|
| **MD034 no-bare-urls** | ⚠️ The single most likely failure. The new subsection cites `docs.github.com` URLs; they must be `[link text](url)` or `<url>`, never bare. |
| MD012 no-multiple-blanks | No double blank lines at the insertion seam. |
| MD009 no-trailing-spaces | — |
| MD047 single-trailing-newline | — |
| **MD022 blanks-around-headings** | ⚠️ Enabled despite the cli2 YAML. The new `###` heading needs a blank line **above and below**. |
| **MD031 blanks-around-fences** | ⚠️ Enabled. Any fenced block in the new text needs a blank line above and below. |
| **MD032 blanks-around-lists** | ⚠️ Enabled. A bullet list needs a blank line above and below. |
| MD004 / MD005 / MD007 | Match §6's existing `-` bullet style and indentation. |
| MD055 / MD056 | Enabled — and they also fire on a non-table line placed directly beneath a table row with no blank line between. Avoid a table here; §6 uses prose and bullets today. |
| MD028 no-blanks-blockquote | Two blockquotes separated by a blank line is a violation — put real text between them if quoting GitHub twice. |
| MD038 no-space-in-code | `` `## ` `` (trailing space inside a code span) fails; write `` `##` ``. |

MD013 (line length) is **off**, so the guide's ~100-column hand-wrapped prose is a convention to match,
not a lint requirement.

**Practical consequence for the plan:** run `markdownlint-cli2 docs/adoption-guide.md` directly after
the edit and before invoking the gate. The gate reports a markdownlint failure as a single `FAIL:
MARKDOWNLINT` line with the tool output embedded, which is harder to read than the tool's own output.

`markdownlint-cli2 v0.21.0 (markdownlint v0.40.0)` is installed at
`/Users/christian/.nvm/versions/node/v25.2.1/bin/markdownlint-cli2`. [VERIFIED: `command -v`]

### milestone-plan doc has no standing gate — but lint it anyway

No script in `scripts/` covers `docs/milestone-plan/`. The repo-wide markdownlint config still applies,
and the file is **clean today**: `markdownlint-cli2 docs/milestone-plan/milestone-2-cicd-gate.md` →
`Summary: 0 error(s)`, exit 0. [VERIFIED: executed this session] The plan should re-run it after editing
so the phase does not introduce the repo's first lint violation in that directory.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Verifying the adoption guide is internally consistent | New ad-hoc grep assertions duplicating the gate | `bash scripts/check-adoption-guide.sh` | Already asserts 15 properties, derives frozen strings from the live workflow rather than hard-coding them. A hand-written comparison copy is the exact tampering vector its header comment says it exists to prevent. |
| Checking markdown formatting | Eyeballing, or a custom line-length script | `markdownlint-cli2 <file>` | Repo-wide config already encodes which rules this project accepts. |
| Deriving check-run context strings | Retyping `security / SCA — Trivy Filesystem` | The gate's `DERIVE-CONTEXTS` output, or `yaml.safe_load` of the workflow | The separator is U+2014; a typed hyphen produces a required check that sits permanently pending with no runtime signal. |
| Confirming DefectDojo parser names | Recalling them, or trusting the docs site's display labels | `dojo/tools/<tool>/parser.py` `get_scan_types()` | Display label ≠ API string ("NPM Audit Version 7+" vs `NPM Audit v7+ Scan`). |
| Confirming GitHub's limits | Training recall, or a rendered page a summariser condensed | `github/docs` source (`gh api …/contents/…`) | The rendered-page summary in this very session mislabelled a hard limit as soft (see CONFLICT-3). Source text also yields the exact error strings and a last-modified date. |
| Finding the live pipeline's file/artifact names | Reading `docs/` | `gh api` on `security-platform` + `.planning/STATE.md` measured-run entries | `docs/` is the thing under repair; using it as ground truth is circular. STATE.md L121 records an actual artifact download. |

**Key insight:** every value this phase writes into prose already exists, measured, in either the live
workflow, a tool's source, or STATE.md. There is no place in this phase where a number or a name should
be composed rather than copied from one of those three.

## Common Pitfalls

### Pitfall 1: Treating `docs/` as ground truth for what the pipeline does

**What goes wrong:** The doc being repaired is cited as the authority for the repair, so the drift is
re-encoded in new words.
**Why it happens:** `docs/adoption-guide.md` describes the live SCA job correctly, which makes it feel
authoritative — but it is a sibling derived doc, not the source.
**How to avoid:** Use the adoption guide for *phrasing* consistency (CONTEXT.md explicitly says so) and
the workflow YAML for *facts*. Never the reverse.
**Warning signs:** A task action whose only stated source for a filename is another markdown file.

### Pitfall 2: Confusing an artifact name with a filename

**What goes wrong:** `sca-results` → `sca-results.json`. This already happened, inside a locked decision
(CONFLICT-1).
**Why it happens:** The other four jobs blur the distinction — `semgrep-results` the artifact contains
`semgrep-results.json` the file, so the pattern *looks* universal. The SCA job breaks it because it is
the only multi-tool job.
**How to avoid:** `name:` on `upload-artifact` is the artifact; `path:` lists the files. Read both.
**Warning signs:** Any `<artifact-name>.json` token for the `sca` or `container` job.

### Pitfall 3: Writing "soft limit" for the 25,000-results ceiling

**What goes wrong:** A consumer reads that exceeding 25,000 results merely truncates, ships a config
that produces 40,000, and gets a hard rejection with no alerts at all.
**Why it happens:** The GitHub table has two adjacent numeric columns, and the "Results per run" row is
the only one where both are populated with large numbers.
**How to avoid:** Maximum column = rejected. Truncation column = accepted-but-partially-displayed.
State both thresholds (5,000 display, 25,000 rejection) with their different consequences.
**Warning signs:** The new subsection mentions 25,000 without mentioning 5,000.

### Pitfall 4: Bulk `sed` across `docs/` for "grype"

**What goes wrong:** M1 workstation docs (where Grype is genuinely installed) and append-only ADRs get
rewritten, violating repo CLAUDE.md's "ADR records are append-only."
**Why it happens:** `grep -rl grype docs/` returns ten files and reads like a to-do list.
**How to avoid:** Edit by explicit file and line. SE-3 above enumerates exactly which files are and are
not in scope.
**Warning signs:** Any task action using `grep -rl … | xargs sed`.

### Pitfall 5: Renumbering the adoption guide's sections

**What goes wrong:** A new `## 7.` silently invalidates 16 "section N" prose cross-references.
**Why it happens:** "Add a new section" is the obvious reading of D-05.
**How to avoid:** `###` under `## 6.` See §Editing Constraints.
**Warning signs:** A diff touching any `##` heading line in `adoption-guide.md`.

### Pitfall 6: Markdown formatting tripping the standing gate

**What goes wrong:** The guide's `MARKDOWNLINT` assertion fails, so `check-adoption-guide.sh` drops from
15/0 — and the failure looks like a content defect rather than a formatting one.
**Why it happens:** Two causes. (a) Pasting `https://docs.github.com/...` inline is the natural way to
cite a source, and MD034 forbids bare URLs. (b) Reading `.markdownlint-cli2.yaml` and concluding that
MD022/MD031/MD032 are off — they are not; `.markdownlint.jsonc` overrides that file and re-enables them.
**How to avoid:** Use `[SARIF support for code scanning](https://docs.github.com/...)` or `<https://…>`;
and put a blank line above and below the new `###` heading, every fenced block, and every list.
**Warning signs:** `MD034`, `MD022`, `MD031` or `MD032` in markdownlint output. Run
`markdownlint-cli2 docs/adoption-guide.md` directly — do not discover it through the gate.

### Pitfall 7: Printing 56 next to §6's existing 58

Covered in §Live Pipeline Ground Truth → Measured finding counts. D-07's "56" comes from a different run
than the figures already published three paragraphs above the insertion point.

## Runtime State Inventory

> Rename/refactor-adjacent phase (string replacement across docs), so this section applies. Every
> category was checked explicitly.

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | **None.** No database, datastore, collection name, or record key contains `grype`, `grype-results.json`, or `sca-results.json`. This repository is documentation only (repo CLAUDE.md: "not buildable software") and ships no runtime datastore. Verified by repo structure and the absence of any DefectDojo deployment — M4 is unbuilt, so no DefectDojo product, engagement, or import history references the `Anchore Grype` parser yet. | None |
| Live service config | **None requiring change.** The live workflow in `OttawaCloudConsulting/security-platform` is the *source of truth* this phase reconciles toward, not a target — it already runs Trivy fs / npm audit / pip-audit / tflint and needs no edit. Verified byte-identical between origin/main and the local clone by `diff`. No dashboard, alert, or external service name embeds the strings being changed. | None |
| OS-registered state | **None.** No scheduled task, service, launchd plist, or pm2 process is involved; this is a text edit in a git working tree. | None |
| Secrets/env vars | **None.** No secret or environment variable name contains `grype` or `sca-results`. The live pipeline is credential-free by design (`docs/adoption-guide.md:35`: "There are no secrets to provision"), and `DEFECTDOJO_API_TOKEN` (milestone-4, unbuilt) is name-stable and unaffected. | None |
| Build artifacts | **None.** No compiled output, package metadata, or generated index derives from these files. Nothing imports or generates from `docs/`. | None |

**Net:** a pure text edit with no runtime state to migrate. The only "state" this phase must keep
consistent is *other documentation* — which is what §Second-Order Effects covers, and which is the real
risk surface here.

## Standard Stack

**Not applicable — no packages are installed by this phase.** It edits two markdown files in a
documentation-only repository. All tooling it needs is already present and was exercised this session:
`gh`, `git`, `grep`, `python3` with `pyyaml`, and `markdownlint-cli2`.

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** No npm, PyPI, or crates dependency is
added, so the Package Legitimacy Gate has nothing to evaluate. `slopcheck` was not run because there
are no candidate packages. No package name appears anywhere in this research as a recommendation.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| `bash` | `scripts/check-adoption-guide.sh` (project rule: explicit interpreter, never `+x`) | ✓ | system | — |
| `python3` + `pyyaml` | the gate's YAML derivation (exits **2** without it) | ✓ | `import yaml` succeeds | — |
| `markdownlint-cli2` | gate's `MARKDOWNLINT` assertion; milestone-doc lint | ✓ | v0.21.0 (markdownlint v0.40.0) | — |
| `repos/security-platform/.github/workflows/` local clone | gate preflight; frozen-string derivation | ✓ | identical to origin/main (`diff` clean) | — |
| `gh` CLI, authenticated | re-verifying live workflow / DefectDojo source if needed at plan time | ✓ | reads both public repos successfully | Facts are transcribed into this document, so no plan task strictly needs network access |
| Network access to `docs.github.com` | citing canonical URLs | ✓ | 200 on all three | URLs and quoted text recorded above |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none.

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`, so this section applies. There is no
unit-test framework in this repository and none should be added — the verification substrate is bash
assertions plus the existing standing gate.

### Test Framework

| Property | Value |
|---|---|
| Framework | bash assertions + `scripts/check-adoption-guide.sh` + `markdownlint-cli2` |
| Config file | `.markdownlint-cli2.yaml` (markdownlint); the gate is self-contained |
| Quick run command | `grep -c -i grype docs/milestone-plan/milestone-2-cicd-gate.md` (expect `0`) |
| Full suite command | `bash scripts/check-adoption-guide.sh && markdownlint-cli2 docs/milestone-plan/milestone-2-cicd-gate.md docs/adoption-guide.md` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| DIST-06 | No Grype reference survives in the milestone-2 doc | unit | `test "$(grep -c -i grype docs/milestone-plan/milestone-2-cicd-gate.md)" -eq 0` | ✅ (file exists; assertion is new, inline) |
| DIST-06 | The live SCA tool set is named where Grype was | unit | `grep -c 'pip-audit' docs/milestone-plan/milestone-2-cicd-gate.md` ≥ 1 and `grep -c 'tflint' …` ≥ 1 | ✅ |
| DIST-06 | No wrong JSON filename remains on L78 | unit | `! grep -q 'grype-results.json\|trivy-results.json' docs/milestone-plan/milestone-2-cicd-gate.md` (second token conditional on the SE-2 decision) | ✅ |
| DIST-06 | Correct SCA JSON filenames present | unit | `grep -q 'trivy-fs.json' docs/milestone-plan/milestone-2-cicd-gate.md` | ✅ |
| DIST-06 | Milestone doc introduces no lint violation | integration | `markdownlint-cli2 docs/milestone-plan/milestone-2-cicd-gate.md` → `0 error(s)` | ✅ (baseline clean, measured) |
| DIST-08 | The guide states the file-size ceiling | unit | `grep -q '10 MB' docs/adoption-guide.md` | ✅ (currently absent — this is the gap) |
| DIST-08 | The guide states the results ceilings, both thresholds | unit | `grep -q '25,000' docs/adoption-guide.md && grep -q '5,000' docs/adoption-guide.md` | ✅ |
| DIST-08 | The guide states the runs-per-file ceiling | unit | `grep -q '20 runs' docs/adoption-guide.md` (exact phrasing is Claude's Discretion — planner should fix the assertion string to whatever it writes) | ✅ |
| DIST-08 | The limits note cites a current, non-redirecting GitHub docs URL as a markdown link | unit | `grep -q 'reference/code-scanning/sarif-files/sarif-support' docs/adoption-guide.md && ! grep -qE '^[^[(]*https://docs\.github\.com' docs/adoption-guide.md` | ✅ |
| DIST-08 | No section renumbering occurred | unit | `grep -c '^## 13\. ' docs/adoption-guide.md` = 1 and `! grep -q '^## 14\. '` | ✅ |
| DIST-08 | Standing gate still fully green | integration | `bash scripts/check-adoption-guide.sh` → `PASSED 15 / FAILED 0`, exit 0 | ✅ (baseline measured this session) |
| Both | No unintended file touched | integration | `git diff --name-only` lists only the intended files | ✅ |

Every command above runs offline in well under 30 seconds. `gh`-based re-verification of the live
workflow is **not** needed at execution time — the facts are transcribed here — but is available if a
task wants to re-derive rather than trust this document.

### Sampling Rate

- **Per task commit:** the relevant grep assertion for the file just edited, plus
  `markdownlint-cli2 <that file>`.
- **Per wave merge:** `bash scripts/check-adoption-guide.sh && markdownlint-cli2 docs/milestone-plan/milestone-2-cicd-gate.md docs/adoption-guide.md`
- **Phase gate:** full suite green, `git diff --name-only` showing only intended files, before
  `/gsd:verify-work`.

### Wave 0 Gaps

None — the standing gate and markdownlint already exist and both pass at baseline. The grep assertions
are inline one-liners, not new test files. **No test framework should be installed for this phase.**

## Security Domain

`security_enforcement` is not set to `false`, so this section is included. This phase writes prose into
two markdown files in a public documentation repository; it introduces no code path, no input handling,
and no credential.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | No auth surface. The documented pipeline is credential-free by design (`docs/adoption-guide.md:35`). |
| V3 Session Management | no | No sessions. |
| V4 Access Control | no | No access-control logic. The one adjacent fact — code-scanning SARIF upload requires a paid licence on private repos — is already documented (§11, deferred-items #5 CLOSED) and is not re-opened here. |
| V5 Input Validation | no | No input is parsed. The gate's own `yaml.safe_load` (not `yaml.load`) is pre-existing and correct. |
| V6 Cryptography | no | No crypto. Action SHA pinning is the integrity control and is out of scope. |
| V14 Configuration | **yes** (documentation-integrity sense) | The edited docs instruct consumers how to configure a security gate. A doc that names a scanner the template does not contain, or omits a ceiling that silently drops findings, degrades a real control. Mitigated by `scripts/check-adoption-guide.sh` staying 15/0 and by every value being source-verified. |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Documentation drift causes a consumer to believe a scanner is running that is not | Spoofing (of assurance) | Reconcile prose to the live workflow only; assert with grep in CI-style checks. This is the phase's entire purpose. |
| A silently truncated SARIF upload creates false assurance — green checks, 3,000 findings never displayed | Repudiation / Information disclosure (of findings, by omission) | Document **both** the 5,000 display truncation and the 25,000 rejection ceiling (CONFLICT-3). |
| Editing the standing gate's assertions to make a failing doc pass | Tampering | Gate's own header names this: it derives frozen strings from the live workflow, and "a hard-coded comparison copy in this script would be exactly the tampering vector T-20-12 exists to prevent." **No plan task may modify `scripts/check-adoption-guide.sh`.** |
| Leaking the local filesystem path into a public doc | Information disclosure | Gate's `NO-OCC-GITHUB` assertion — the working directory is `…/OCC-github/…`, trivially pasted in by accident. |
| Publishing an invented platform limit that a consumer then designs around | Spoofing (of authority) | Cite only limits present in `github/docs` source; state explicitly that no per-hour upload limit is published rather than guessing one. |

## Project Constraints (from CLAUDE.md)

### From repo `CLAUDE.md`

- This is a **reference documentation project, not buildable software**. Do not add build tooling,
  test frameworks, or package manifests.
- The canonical workflows live in `OttawaCloudConsulting/security-platform`, **not** in this repo —
  "this repository documents them, it does not ship them." Confirms the direction of reconciliation.
- **`docs/adr/` records are append-only.** Do not modify accepted ADRs. Three ADRs mention Grype; all
  are out of scope (SE-3).
- Preserve ASCII architecture diagrams, the 4-phase layered structure, tool coverage matrices, and the
  security tools comparison table. The milestone-2 edit touches a feature table cell (L16) — preserve
  the table's column structure and alignment.
- `scripts/` holds standing documentation gates, including `bash scripts/check-adoption-guide.sh`.

### From `.claude/rules/defensive-protocol-v2-anti-slop.md`

- **Never set the executable bit on scripts.** Always invoke as `bash scripts/check-adoption-guide.sh`.
- Reality is the arbiter — when observations contradict the model, the model is wrong. Applied directly:
  three locked decisions are amended above on the strength of the live workflow.
- On failure: **STOP → REPORT → WAIT.** No silent retry. If the gate drops below 15/0, stop and report;
  do not adjust the gate.
- No silent fallbacks (`|| true`, `try/except: pass`). Note `|| true` is *also* a gate-banned string.
- **Second-order effects:** "Before changing anything, list what reads/writes/depends on it." §Second-Order
  Effects is this rule discharged.
- Verification cadence: verify every 3 actions for unfamiliar work, 5 for routine.

### From `.claude/rules/defensive-protocol-v2-epistemology.md`

- **Chesterton's Fence:** articulate why something exists before changing it. Applied to the `# v4`
  comments (correct, not stale — dropped from scope) and to `Anchore Grype` (a real DefectDojo parser;
  what changed is the pipeline's output, not the parser's name).
- Prediction protocol: state `INTENT` for routine actions; full `DOING/EXPECT/IF MATCH/IF MISMATCH` for
  high-risk ones. Editing a file with uncommitted changes counts as high-risk — check `git status`
  before editing either target file.

### From `.claude/rules/defensive-protocol-v2-session-management.md`

- A checkpoint is "I ran it, here's what happened," not "I believe this works." Each task must run its
  assertion and read the output.

### Project skills

`.claude/skills/` contains `cdk-testing`, `create-prd`, `itsg-assessment`, `nist-csf-assessment`,
`nist-fedramp-assessment`, `occ-skill-creator`, `occ-skill-refactor`, `rule-creator`,
`terraform-testing`. **None is applicable** to a two-file markdown edit — they cover compliance
assessment, IaC/CDK testing, and skill authoring. No skill pattern constrains this phase.
`.agents/skills/` does not exist.

## Architecture Patterns

### Recommended edit structure

```text
Two fully independent single-file edits, parallelisable:

  Edit A — docs/milestone-plan/milestone-2-cicd-gate.md
    L16  feature table cell     : Grype -> live SCA tool set (D-02)
    L33  Done Criteria bullet   : Grype --fail-on high -> live sub-scan behaviour
    L43  Done Criteria bullet   : "flagged by Grype" -> flagged by the SCA job
    L78  JSON output list       : grype-results.json -> trivy-fs.json + npm-audit-<N>/pip-audit-<N>
                                  (+ trivy-results.json -> trivy-image.json, pending SE-2 decision)
    L85  DefectDojo parser row  : drop "Anchore Grype", qualify the two "Trivy Scan" slots (D-04')
    verify: grep -c -i grype == 0 ; markdownlint-cli2 -> 0 errors

  Edit B — docs/adoption-guide.md
    new "### " subsection inside "## 6.", inserted after line 257
    content: 10 MB gzipped / 20 runs per file / 25,000 results (reject) vs top 5,000 (display)
             / 25,000 rules ; this project's measured scale ; markdown-linked canonical URLs
    verify: bash scripts/check-adoption-guide.sh -> PASSED 15 / FAILED 0

  Decision gate (before or alongside Edit A) — SE-1: milestone-4-defectdojo.md L75/L105
    fix-in-phase, or record as a deferred item with a named owner. Not "ignore".
```

No ordering dependency exists between A and B: different files, no shared strings, different
verification commands.

### Pattern: reconcile toward the executable artifact

**What:** When prose and a running system disagree, the system is right by definition; edit the prose.
**When to use:** Every drift-closure task in this phase.
**Why it is stated explicitly:** `21-CONTEXT.md` records it as an established project pattern — "Prior
doc-fix passes (Phase 17-06, Phase 20.1) always re-verify the live pipeline state before editing prose,
rather than trusting the deferred-item's original wording." This research is that re-verification, and
it caught three defects in the deferred item and the decisions derived from it.

### Pattern: quote the platform, cite the platform

**What:** For third-party limits, reproduce the vendor's number and link the vendor's page; never
paraphrase a limit into project policy.
**Example (satisfies MD034):**

```markdown
GitHub rejects any gzip-compressed SARIF file larger than 10 MB, and rejects a file whose single run
carries more than 25,000 results. Below that ceiling, only the top 5,000 results per run are displayed,
prioritized by severity — the remainder are accepted but never shown. See
[SARIF support for code scanning](https://docs.github.com/en/code-security/reference/code-scanning/sarif-files/sarif-support)
and [SARIF results exceed limits](https://docs.github.com/en/code-security/reference/code-scanning/sarif-files/troubleshoot-sarif-uploads/results-exceed-limit).
```

### Anti-Patterns to Avoid

- **Bulk regex replacement across `docs/`** — wrecks M1 workstation docs and append-only ADRs (SE-3).
- **Adding a `## 7.` to the adoption guide** — forces renumbering §7–§13 and 16 cross-references.
- **Editing `scripts/check-adoption-guide.sh`** — its header identifies this as tampering vector T-20-12.
- **Substituting a generic "SCA scan" placeholder** — D-02 forbids it; name the tools.
- **Writing `sca-results.json`** — no such file exists (CONFLICT-1).
- **Writing `Pip-Audit Scan` or `NPM Audit Scan`** — the API strings are `pip-audit Scan` and
  `NPM Audit v7+ Scan`.
- **Leaving one bare duplicated `Trivy Scan`** on L85 — technically correct, reads as a typo (CONFLICT-2).
- **Introducing the number 56** three paragraphs below §6's existing 58.

## Code Examples

### Re-derive the live SCA job's emitted files (if a task wants to verify rather than trust)

```bash
# Source: OttawaCloudConsulting/security-platform, fetched 2026-09-15
gh api repos/OttawaCloudConsulting/security-platform/contents/.github/workflows/security.yml \
  --jq '.content' | base64 -d | sed -n '836,850p'
# Expected: name: sca-results, then path: trivy-fs.json / trivy-fs.sarif /
#           npm-audit-*.json / pip-audit-*.json / tflint.sarif
```

### Confirm the local clone the gate reads is current with origin

```bash
# Source: verified clean this session
gh api repos/OttawaCloudConsulting/security-platform/contents/.github/workflows/security.yml \
  --jq '.content' | base64 -d > /tmp/origin-security.yml
diff repos/security-platform/.github/workflows/security.yml /tmp/origin-security.yml \
  && echo "clone is current"
```

### Re-derive a DefectDojo parser's API string

```bash
# Source: DefectDojo/django-DefectDojo master, fetched 2026-09-15
gh api repos/DefectDojo/django-DefectDojo/contents/dojo/tools/npm_audit_7_plus/parser.py \
  --jq '.content' | base64 -d | grep -A2 'def get_scan_types'
# Expected: return ["NPM Audit v7+ Scan"]
```

### Re-derive GitHub's limits table from the docs source

```bash
# Source: github/docs, reusable last modified 2024-10-18
gh api repos/github/docs/contents/data/reusables/code-scanning/sarif-limits.md \
  --jq '.content' | base64 -d
```

### Phase verification, both files

```bash
# milestone doc — expect 0
grep -c -i grype docs/milestone-plan/milestone-2-cicd-gate.md
markdownlint-cli2 docs/milestone-plan/milestone-2-cicd-gate.md   # expect: 0 error(s)

# adoption guide — expect PASSED 15 / FAILED 0, exit 0
bash scripts/check-adoption-guide.sh

# no collateral damage
git diff --name-only
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| SCA via Anchore Grype (`--fail-on high`), emitting `grype-results.json` | SCA job = `trivy fs --scanners vuln` (JSON + SARIF) plus ecosystem sub-scans npm audit / pip-audit / tflint, emitting `trivy-fs.json`, `npm-audit-<N>.json`, `pip-audit-<N>.json`, `trivy-fs.sarif`, `tflint.sarif` under artifact `sca-results` | Phase 15 (SCA-04 generic Trivy fs) then Phase 16 (SCA-01/02/03 sub-scans) | The drift this phase closes. Grype is no longer in the CI pipeline at all — though it remains a legitimately installed **workstation** tool per M1-F3. |
| `trivy convert` to produce the filesystem SARIF | A second direct `trivy fs … --format sarif` run with flags identical to the JSON run | Phase 17-02 | `trivy convert` sets `originalUriBaseIds.ROOTPATH` to the input JSON file path, so every result resolved to a nonexistent `trivy-fs.json/...` path in code scanning. The container job's `trivy convert` is deliberately retained. |
| GitHub docs at `/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning` | `/code-security/reference/code-scanning/sarif-files/sarif-support` (+ `troubleshoot-sarif-uploads/*`) | before 2026-09-15 (old path returns 301) | Cite the 200 URL. The old path also appears in `redirect_from:` front-matter in the docs source, confirming the move. |
| DefectDojo legacy `npm_audit` parser | `npm_audit_7_plus` → `NPM Audit v7+ Scan` | npm 7 changed the audit JSON schema; runner npm is 10.x | Legacy parser only accepts v6-and-older output. Recorded in `.planning/STATE.md` L115. |

**Deprecated/outdated in the project's own records:**

- `deferred-items.md` #6's framing "the upload would be rejected" — correct for >25,000 results, but
  omits the 5,000 display truncation that a large consumer hits first.
- `deferred-items.md` Phase 20.1 re-check, item #4: "5 filenames that all diverge" — 3 of 5 match live.
- `ROADMAP.md` Phase 21's "7 stale `# v4` comments" bullet — closed by Phase 20.1, dropped by the user.
- `21-CONTEXT.md` D-03's `sca-results.json` — no such file (CONFLICT-1).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | No per-hour SARIF upload rate limit is published by GitHub | GitHub SARIF Upload Limits | LOW. Negative claim, supported by a zero-result code search across the `github/docs` **source** repo (stronger than "not on a rendered page"), but a code search can miss content behind a template variable. Mitigation: the recommendation is to *not mention* an hourly limit, so an undiscovered one causes an omission rather than a false statement. |
| A2 | The `SARIF` generic parser is what `tflint.sarif` would use in a future DefectDojo import | DefectDojo Parser Names | LOW. `get_scan_types() → ["SARIF"]` is verified, and STATE.md L115 records "plus a generic SARIF parser," but no tflint-specific parser was searched for exhaustively. M4 is unbuilt, so nothing depends on it now; and tflint contributes no JSON, so it need not appear on L78 at all. |
| A3 | Insertion after line 257 is stylistically preferable to line 263 | Editing Constraints | LOW. Pure editorial judgement, explicitly within Claude's Discretion per CONTEXT.md. Both positions are inside §6 and neither triggers renumbering. |
| A4 | Fixing `trivy-results.json` → `trivy-image.json` is within Claude's Discretion | Live Pipeline Ground Truth / SE-2 | MEDIUM. The *fact* is verified; the *scope judgement* is an interpretation of "consistency is the goal, not a rewrite." If the user disagrees, it must become a recorded deferred item rather than an omission. Planner should confirm. |

Everything else in this document is `[VERIFIED]` against the live workflow, `github/docs` source,
DefectDojo source, an executed command, or this project's own measured-run records in `STATE.md`. There
are no `[ASSUMED]` factual values — no version number, filename, parser string, or limit relies on
training recall.

## Open Questions (RESOLVED)

All three were scope decisions, not technical gaps, and the orchestrator collected explicit user
decisions on each after this research completed. Recorded below for the plan-checker and any future
reader — the planner has already implemented all three resolutions.

1. **Does `docs/milestone-plan/milestone-4-defectdojo.md` get fixed in this phase?** (SE-1)
   - **What we know:** L75 carries the identical `Anchore Grype` parser list; L105's Trivy-vs-Grype
     dedup example is now impossible. Both verified by grep.
   - **What's unclear:** D-01 scopes the edit to milestone-2 only. M4 is an unbuilt future milestone.
   - **Recommendation:** L75 in-phase (one line, same contract, prevents doc-vs-doc contradiction);
     L105 as a recorded deferred item with an owner, since choosing a replacement dedup example is
     editorial.
   - **RESOLVED (user, 2026-09-15):** Fix in-phase — both L75 and L105. Implemented in plan 21-02.

2. **Does `trivy-results.json` get corrected on L78?** (SE-2, A4)
   - **What we know:** It is wrong; live is `trivy-image.json`. It sits on the exact line D-01 opens.
   - **What's unclear:** Whether "all 5 Grype mentions" bounds the edit to Grype tokens only.
   - **Recommendation:** Fix it. Leaving a known-wrong filename on a just-edited line is the drift this
     phase exists to end.
   - **RESOLVED (user, 2026-09-15):** Yes, fix on the same line as the D-01 edit. Implemented in plan
     21-01, Task 2.

3. **Does the new subsection mention the 1,000,000 alert limit and its no-self-service-recovery
   consequence?**
   - **What we know:** Verified and genuinely severe — it blocks *all* subsequent uploads and requires
     contacting GitHub support.
   - **What's unclear:** D-05 scopes the subsection to "size/result ceilings," which this arguably
     exceeds.
   - **Recommendation:** One clause at most, or omit.
   - **RESOLVED (user, 2026-09-15):** Include it, as a fifth data point alongside the four D-06 numbers,
     with the subsection's framing centered on the 5,000-result-per-run display truncation as the primary
     failure mode. Implemented in plan 21-03, Task 1.

**No open technical questions.** Every factual value the planner needs was resolved above at research
time. All three scope questions are now resolved per the user decisions recorded above.

## Sources

### Primary (HIGH confidence)

- `OttawaCloudConsulting/security-platform` → `.github/workflows/security.yml` — fetched via
  `gh api …/contents/…`, 2026-09-15; `diff`-confirmed identical to the in-repo clone
  `repos/security-platform/.github/workflows/security.yml`. Job ids and `name:` values, all five
  `upload-artifact` name/path blocks, SCA step bodies and line numbers.
- `github/docs` → `content/code-security/reference/code-scanning/sarif-files/sarif-support.md` (L103,
  L105) — the 10 MB gzipped limit and the "rejected if exceeded" governing sentence.
- `github/docs` → `data/reusables/code-scanning/sarif-limits.md` — the full limits table; last modified
  2024-10-18T18:40:48Z, commit `313e02ea840443079c34bac0ed033440514f81c7`.
- `github/docs` → `content/code-security/reference/code-scanning/sarif-files/troubleshoot-sarif-uploads/results-exceed-limit.md`
  — soft-vs-hard definitions and the verbatim error strings.
- `DefectDojo/django-DefectDojo` → `dojo/tools/{trivy,npm_audit_7_plus,pip_audit,sarif,anchore_grype,semgrep,checkov,gitleaks}/parser.py`
  — `get_scan_types()` return values.
- <https://docs.github.com/en/code-security/reference/code-scanning/sarif-files/sarif-support> — HTTP 200 (`curl`).
- <https://docs.github.com/en/code-security/reference/code-scanning/sarif-files/troubleshoot-sarif-uploads/results-exceed-limit> — HTTP 200.
- <https://docs.github.com/en/code-security/reference/code-scanning/sarif-files/troubleshoot-sarif-uploads/file-too-large> — HTTP 200.
- Commands executed this session: `bash scripts/check-adoption-guide.sh` (PASSED 15 / FAILED 0, exit 0);
  `markdownlint-cli2 docs/milestone-plan/milestone-2-cicd-gate.md` (0 errors);
  `markdownlint-cli2 --version` (v0.21.0 / markdownlint v0.40.0); `python3 -c 'import yaml'` (ok);
  `gh api search/code` on `github/docs` for `"uploads per hour"` (zero results);
  `curl -o /dev/null -w "%{http_code}"` on four GitHub docs URLs; a throwaway three-line markdown probe
  written to `docs/` and linted (then deleted) to establish which markdownlint rules are actually
  enabled for that directory.

### Project records (HIGH confidence — measured, not recalled)

- `.planning/STATE.md` L115 — npm 10.x on the runner ⇒ `npm_audit_7_plus` is the applicable parser;
  native formats retained deliberately for DefectDojo import fidelity.
- `.planning/STATE.md` L121 — live PR #8 / run `34638828775`: `sca-results` downloads as
  `npm-audit-1.json`, `pip-audit-1.json`, `tflint.sarif`, `trivy-fs.json`, `trivy-fs.sarif`.
- `.planning/STATE.md` L109 — why `trivy convert` was removed from the SCA job.
- `.planning/STATE.md` L147 — PR #12 finding counts (8/11/14/58/6/3).
- `.planning/phases/17-sarif-upload-and-artifact-retention/deferred-items.md` — items #4 and #6 plus the
  2026-09-14 status re-check.
- `docs/adoption-guide.md` — §1 (L24-26) live SCA tool-set phrasing to match; §6 (L218-262) insertion
  target and published finding counts; L35 credential-free claim.
- `scripts/check-adoption-guide.sh` — 15 assertions, the T-20-12 tampering rationale, exit-code contract.
- `.markdownlint.jsonc` (repo root) — the **effective** markdownlint config: disables only MD024,
  MD036, MD040, MD060 and MD013/line-length. It overrides `.markdownlint-cli2.yaml`'s `config:` block,
  which disables ten rules and is **not** what gets applied. Established by probe, not by reading.
- `.planning/REQUIREMENTS.md` L26/L28 — DIST-06, DIST-08 text.

### Secondary (MEDIUM confidence, superseded above)

- `docs.defectdojo.com/supported_tools/parsers/file/pip_audit/` and
  `docs.defectdojo.com/supported_tools/parsers/file/npm_audit_7_plus/` (via WebSearch/WebFetch) —
  display labels only; **superseded** by `parser.py` source. The docs site's "NPM Audit Version 7+"
  differs from the API string `NPM Audit v7+ Scan`, which is why source was used.
- A rendered-page summary of `results-exceed-limit` that classified 25,000-results-per-run as a soft
  limit — **contradicted** by `sarif-support.md` L105 and not relied upon. Recorded here as a warning
  (CONFLICT-3).

### Tertiary (LOW confidence)

None. No claim in this document rests on an unverified web search.

### Not used

- Context7 / `ctx7` — not applicable. This phase's subjects are a specific private-to-this-project
  workflow file, a vendor's published limits, and a tool's source code. No library API documentation
  is involved, and Context7 has no better source than the vendor's own docs repo, which was read
  directly.
- `.planning/graphs/graph.json` — absent, so no graph context was injected (`ls` confirmed missing).

## Metadata

**Confidence breakdown:**

- **Standard stack:** N/A — documentation-only phase, zero packages installed.
- **Live pipeline ground truth:** HIGH — read from the live workflow source via `gh api`, cross-checked
  against `diff` with the local clone and against measured artifact downloads in STATE.md.
- **GitHub SARIF limits:** HIGH — read from `github/docs` source markdown with a commit SHA and
  last-modified date, two pages cross-checked, canonical URLs curl-verified for 200.
- **DefectDojo parser names:** HIGH — literal `get_scan_types()` return values from source, not docs-site
  labels.
- **Editing constraints:** HIGH — gate executed (15/0), markdownlint executed (0 errors), config read,
  heading/cross-reference counts grepped.
- **Second-order effects:** HIGH on the facts (grep-verified); the scope *recommendations* are
  judgement and are flagged as open questions.
- **Pitfalls:** HIGH — each is derived from a specific verified fact in this document, not from general
  experience. Pitfall 2 and Pitfall 3 each describe an error that actually occurred during this
  session's research.

**Research date:** 2026-09-15
**Valid until:** 2026-10-15 (30 days). Re-verify sooner if `security-platform`'s `security.yml` changes
job names or artifact paths — that would invalidate §Live Pipeline Ground Truth and could break
`check-adoption-guide.sh`'s derived contexts. GitHub's limits table has been stable since 2024-10-18.
