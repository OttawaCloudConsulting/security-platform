---
phase: 17-sarif-upload-and-artifact-retention
verified: 2026-09-15T00:00:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
---

# Phase 17: SARIF Upload and Artifact Retention Verification Report

**Phase Goal:** Scan findings surface in GitHub's Security tab and are retained as JSON so a future DefectDojo import has data to consume.
**Verified:** 2026-09-15 (session date; live repo state read 2026-09-14/15)
**Status:** passed
**Re-verification:** No — initial verification (retroactive, authored in Phase 20.1)

## Method

This verification does not trust SUMMARY.md narrative. Every load-bearing claim in the four ROADMAP
success criteria and in requirements CICD-02/CICD-03 was independently re-queried against the live
`OttawaCloudConsulting/security-platform` repository via `gh` (code-scanning analyses, workflow run
artifacts, commit check-runs, live workflow YAML) in this session, and the results are reproduced below
next to the originating SUMMARY's claim.

This report is retroactive: Phase 17 closed on 2026-09-11 with no `VERIFICATION.md`, and this document is
authored ~4 days later, by Phase 20.1, after Phase 18 (2026-09-12), Phase 19 (2026-09-13/14) and Phase 20
(2026-09-14) all ran on top of the same SARIF/artifact machinery without breaking it — that gap in time is
itself corroborating evidence, not a liability, for CICD-02/CICD-03's continued correctness.

All three retroactive reports (Phase 14, 17, 18) share one pinned evidence snapshot so they cannot
contradict each other: reference PR `#13`, PR head SHA `c06d2729b123094bcbb48e03c1155b72c7727b8c`,
reference run `34870572604` (`PR Security`, `success`, 2026-09-14T16:45:26Z), merge date
`2026-09-14T17:04:38Z`, `origin/main` HEAD `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`, repo
`visibility: public`. Server-side scan records (analyses, check-runs, artifacts) hang off the PR head
`c06d272…`; workflow YAML source-of-truth is read from `origin/main` (`cdf2c21…`) — both are cited below,
never conflated. This snapshot was re-pinned in Phase 20.1 plan 01 and reused verbatim here; it was not
re-derived.

**Read-only scope for this session:** `gh api`, `gh pr view/list`, `gh run view/list/download`, `git diff`,
`grep`, `bash scripts/check-workflow-uploads.sh`. No `gh variable set`, no `--apply`, no PR creation or
merge, no push to `security-platform`, no package install. Before any live re-query, the local clone at
`repos/security-platform` was re-proven byte-identical to live `origin/main` for `.github/workflows/security.yml`
and `.github/workflows/pr-security.yml` this session (`git diff origin/main -- <both files>` empty,
`git rev-parse origin/main` = `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`) — this identity was re-proven, not
inherited from plan 01.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth (from ROADMAP.md) | Status | Evidence |
|---|---|---|---|
| SC1 | After a workflow run, the repo's Security > Code scanning view shows findings attributed to each scanner separately, so results from one tool do not overwrite another's. | ✓ VERIFIED | `gh api "repos/$R/code-scanning/analyses?ref=refs/pull/13/merge" --jq '[.[]\|{category,results_count}]'` this session returned 7 analyses across exactly 6 distinct categories: `semgrep`(7), `checkov`(14), `trivy-fs`(6), `tflint`(0 and 3), `trivy-image`(58), `gitleaks`(11) — matches 17-05-SUMMARY's per-category evidence from PR #8 in shape (six categories, no collision). Mechanism confirmed in source: `gh api repos/$R/contents/.github/workflows/security.yml \| base64 -d \| grep -n 'category:'` returned exactly 6 hits at lines 103/268/539/788/984/1133, one per `upload-sarif` step, all unique — matching ADR-016's published six-category contract verbatim. |
| SC2 | Findings appear as inline annotations on the pull request diff wherever the tool reports a file and line. | ✓ VERIFIED (API half) + closed checkpoint (visual half) | API-verifiable half, re-queried live this session: `gh api repos/$R/commits/c06d2729b123094bcbb48e03c1155b72c7727b8c/check-runs --jq '.check_runs[] \| "\(.output.annotations_count) \(.app.id) \(.name)"'` returned non-zero `output.annotations_count` on all five of our `app.id 15368` checks: `IaC — Checkov`=10, `SCA — Trivy Filesystem`=6, `Container — Trivy Image`=2, `Secrets — Gitleaks`=2, `SAST — Semgrep CE`=1 (21 total); all third-party checks (`app.id` 57789, 46505) report 0. This proves annotations are attached to the commit, not merely that findings exist. Visual rendering on the PR diff itself was **not re-observed in this session** — that half is closed via the `checkpoint:human-verify` gate that halted 17-05/17-07 and received the operator's recorded approval during the original phase; it is not being re-claimed as freshly re-verified here. |
| SC3 | Every run leaves downloadable JSON artifacts — one per scan job, including the SCA sub-scans — with an explicit retention period. | ✓ VERIFIED | `gh api repos/$R/actions/runs/34870572604/artifacts --jq '.artifacts[]\|{name,created_at,expires_at,expired,size_in_bytes}'` this session returned exactly 5 artifacts, all `expired: false`: `semgrep-results`, `checkov-results`, `sca-results`, `trivy-image-results`, `gitleaks-results`. Retention arithmetic: `created_at 2026-09-14T16:4X` → `expires_at 2026-12-13T16:45:27Z` = exactly 90 days on every artifact. Declared intent confirmed in source: `grep -n 'retention-days'` on the live `security.yml` returned 5 occurrences, all `90`, at lines 188/323/858/1044/1188. `sca-results` (19917 B) is the SCA sub-scan bundle — see the asymmetry paragraph below. |
| SC4 | A tool without native SARIF output still reaches the Security tab or the artifact set through a documented conversion step. | ✓ VERIFIED | `gh run download 34870572604 -R $R -n sca-results --dir <session scratchpad>` this session produced exactly 5 files: `npm-audit-1.json`, `pip-audit-1.json`, `tflint.sarif`, `trivy-fs.json`, `trivy-fs.sarif`. npm audit and pip-audit emit no SARIF (confirmed against `--help` output cited in ADR-016's Context); their numbered-per-input JSON reaching the retained `sca-results` artifact is the documented conversion/fallback path (ADR-016 decision: "Criterion 4 is satisfied ... through the ARTIFACT SET plus the documented `trivy convert` step"). Files downloaded to the session scratchpad only; `git status --porcelain repos/ .planning/ docs/` after the download shows none of the five filenames in any tracked tree. |

**Score:** 4/4 truths verified

**The counting asymmetry — expected structure, not drift.** Four different numbers appear across this
report and they are not supposed to match:
- **6 SARIF categories** — `tflint` uploads its own category (`tflint`) from inside the `sca` job, alongside `trivy-fs`.
- **5 artifacts** — `sca-results` is a bundle: it contains tflint's SARIF *and* trivy-fs's JSON/SARIF *and* npm-audit's and pip-audit's JSON together, so one artifact name covers two SARIF categories' worth of source tools.
- **5 `security / …` check-runs** — one per job (`sast`, `iac`, `sca`, `container`, `secrets`); the `pr-security.yml` caller job itself emits none of its own.
- **7 analyses on PR #13** — tflint's single SARIF carries two drivers, so the `tflint` category yields two analyses (`results_count` 0 and 3) sharing one `sarif_id`, which is why 6 categories produce 7 analyses rather than 6.

**PITFALL-1, stated explicitly:** `gh api "repos/$R/code-scanning/analyses?per_page=100" --jq '[.[]\|.ref]\|unique'`
this session returned exactly `["refs/pull/10/merge","refs/pull/11/merge","refs/pull/12/merge","refs/pull/13/merge","refs/pull/8/merge","refs/pull/9/merge"]`
— **no `refs/heads/*` entry at all**. `pr-security.yml` declares `on: pull_request: {}` only, with no
`push` trigger, so `code-scanning/analyses?ref=refs/heads/main` would return `[]` if queried — this is a
designed consequence of the PR-only trigger policy (ADR-016's user decision D-02: "`main` is never
analysed"), never a CICD-02 failure.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `security.yml` — 6 `upload-sarif` steps with unique `category:` | one per scanner, codeql-action-pinned | ✓ VERIFIED | Live `contents` API read this session: 6 `category:` hits (line-cited above), 6 `upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63` hits (codeql-action v4.38.0) |
| `security.yml` — 5 `upload-artifact` steps, `retention-days: 90` | one per job, explicit period | ✓ VERIFIED | Live `contents` API read: 5 `retention-days: 90` hits (line-cited above); live artifacts API confirms 5 artifacts land per run |
| `bash scripts/check-workflow-uploads.sh` (offline static gate over CICD-02/03 invariants) | 10 checks, 0 failures | ✓ VERIFIED | Re-run this session from `repos/security-platform`: `PASS - 10 checks, 0 failures`, exit 0. This gate exists specifically because of the broken-but-green failure mode (`continue-on-error: true` on upload steps masking a 403) — its PASS is positive security evidence for CICD-02/CICD-03, not a lint result |
| `.planning/REQUIREMENTS.md` — CICD-02/CICD-03 marked complete | both tracking locations | ✓ VERIFIED | Live grep this session: line 12 `[x] **CICD-02**`, line 13 `[x] **CICD-03**`; traceability table lines 60-61 both read `Phase 17 \| Complete` |
| `docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md` | records CICD-02/CICD-03 decisions | ✓ VERIFIED | Present, `Status: Accepted`, `Addresses: CICD-02, CICD-03`. Read as evidence in this session; not edited — `docs/adr/` is append-only |

### Key Link Verification

The `gsd-sdk query verify.key-links` tool reports links like these as `verified: false, detail: "Source
file not found"` for facts that live on the GitHub server, not in this repo's working tree. This is a
tooling-fit mismatch, not a defect: Phase 17's key links are live code-scanning/artifacts/check-run facts,
not static source-file greps the tool is built to pattern-match. Each link below was independently
re-verified by direct `gh`/`gh api` calls in this session — the stronger form of verification for this
evidence type — and every one held.

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `upload-sarif` step (`category: semgrep`/`checkov`/`trivy-fs`/`tflint`/`trivy-image`/`gitleaks`) | code-scanning analysis with matching `category` | codeql-action `upload-sarif@b96794f0…` | ✓ WIRED (live) | Live `code-scanning/analyses?ref=refs/pull/13/merge` this session returns exactly those 6 category strings, 7 analyses total |
| `upload-artifact` step (`retention-days: 90`) | artifacts API entry with `expires_at` | `actions/upload-artifact@043fb46d…` | ✓ WIRED (live) | Live artifacts API this session: 5 artifacts, `expires_at - created_at` = 90 days on every one |
| `steps.<id>.outcome` intolerant assertion (ADR-016 decision) | broken-but-green mitigation | 11 paired assertions (6 SARIF + 5 artifact) | ✓ WIRED (live) | `bash scripts/check-workflow-uploads.sh` PASS this session is the offline proof these assertions exist and are correctly shaped; the live analyses/artifacts counts above are the online proof they did not silently swallow a failure on this run |

The byte-exact check-run-name consistency check across the five doc surfaces (`cicd/README.md`,
`docs/adoption-guide.md`, the blueprint, ADR-017, the milestone plan) is Phase 18's CICD-04 concern and is
owned by plan 20.1-03's `18-VERIFICATION.md`; not duplicated here.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| CICD-02 | 17-01 through 17-07 | Each scan job uploads SARIF results to the GitHub Security tab | ✓ SATISFIED | Marked complete in `.planning/REQUIREMENTS.md` (both tracking locations, live-read this session). SC1 row above independently re-verified live: 6 distinct categories arrive server-side, mechanism confirmed in source. |
| CICD-03 | 17-01 through 17-07 | Each scan job retains JSON artifact output for future DefectDojo import (import pipeline itself is out of scope this milestone) | ✓ SATISFIED | Marked complete in `.planning/REQUIREMENTS.md` (both tracking locations, live-read this session). SC3/SC4 rows above independently re-verified live: 5 unexpired artifacts, 90-day retention, SCA sub-scan bundling confirmed by file listing. |

No orphaned requirements — REQUIREMENTS.md maps only CICD-02 and CICD-03 to Phase 17.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | No `TBD`/`FIXME`/`XXX` debt markers found in any Phase 17 file this session (`grep -rn 'TBD\|FIXME\|XXX' .planning/phases/17-sarif-upload-and-artifact-retention/`) | — | — |

`.planning/ROADMAP.md` was also re-grepped for a stray `TBD`: none remains (Phase 20.1's own placeholder,
present when this phase was researched, has since been rewritten by planning). No debt markers were
introduced by or remain attributable to Phase 17.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Local clone matches live `origin/main` | `git -C repos/security-platform diff origin/main -- .github/workflows/security.yml .github/workflows/pr-security.yml` | empty | ✓ PASS |
| `origin/main` HEAD unchanged from pinned snapshot | `git -C repos/security-platform rev-parse origin/main` | `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` | ✓ PASS (matches plan 01) |
| SARIF categories on PR #13 (02-a) | `gh api code-scanning/analyses?ref=refs/pull/13/merge` | 7 analyses / 6 categories | ✓ PASS |
| Unfiltered analyses ref list (02-b) | `gh api code-scanning/analyses?per_page=100 --jq '.[]\|.ref\|unique'` | only `refs/pull/{8..13}/merge`, no `refs/heads/*` | ✓ PASS — PITFALL-1 control |
| `category:` source lines (02-c) | `grep -n 'category:'` on live `security.yml` | 6 hits, unique values | ✓ PASS |
| `upload-sarif` action pin count (02-d) | `grep -c 'upload-sarif@b96794f0…'` | 6 | ✓ PASS |
| Offline upload gate (02-e) | `bash scripts/check-workflow-uploads.sh` | `PASS - 10 checks, 0 failures`, exit 0 | ✓ PASS |
| Our check-run annotation counts (02-f) | `gh api commits/c06d272…/check-runs` filtered app.id 15368 | 10/6/2/2/1, all non-zero | ✓ PASS |
| Artifact set for run 34870572604 (03-a) | `gh api actions/runs/34870572604/artifacts` | 5 artifacts, all `expired:false` | ✓ PASS |
| Retention arithmetic (03-b) | computed from 03-a | 90 days exactly | ✓ PASS |
| `retention-days` source lines (03-c) | `grep -n 'retention-days'` on live `security.yml` | 5 hits, all `90` | ✓ PASS |
| SCA artifact file listing (03-d) | `gh run download 34870572604 -n sca-results` | 5 expected filenames, in scratchpad only | ✓ PASS |
| Deferred item 1 — stale cicd/ mirror | `gh api contents/cicd/.github/workflows/security.yml` | 404 | ✓ PASS — CLOSED |

### Probe Execution

SKIPPED (no probes declared). Checked `grep -rn 'probe-' .planning/phases/17-sarif-upload-and-artifact-retention/17-0*-PLAN.md .planning/phases/17-sarif-upload-and-artifact-retention/17-VALIDATION.md`
(no hits) and `find repos/security-platform/scripts -path '*/tests/probe-*.sh'` (no hits) this session.
Phase 17 is validated via live GitHub Actions runs and API reads, not local probe scripts.

### Human Verification Required

None — the UI confirmations this phase required were `checkpoint:human-verify` gates closed during the
original phase (17-05/17-07's Security tab and PR-annotation confirmations), cited above in SC2; no new
human verification is deferred by this report.

### Gaps Summary

No gaps against CICD-02, CICD-03, or any of the four ROADMAP success criteria — all are independently
confirmed against live GitHub state this session, not merely asserted in SUMMARY.md prose. Two items are
worth surfacing as informational context, neither a gap:

1. **SC2's visual half was not re-observed.** The inline-annotation presence is proven live via
   `output.annotations_count` (10/6/2/2/1) on this session's own re-query; the diff-rendering half rests on
   the operator's approval recorded during 17-05/17-07 and is not re-claimed as freshly verified. Not
   concealed — stated plainly in the SC2 row above.
2. **Token scope reproducibility caveat.** This session's `gh` token lacks `security_events` and succeeded
   only because `security-platform` is public (`repo` scope suffices). If the repo were ever made private,
   this same CICD-02 re-query would 403 and this report would not be reproducible as written — this
   dovetails with deferred item 5 below, which is CLOSED precisely because Phase 20 already built the
   private-repo fallback path.

**Each of Phase 17's seven `deferred-items.md` entries, current verdict:**

1. **Stale `cicd/.github/workflows/security.yml` mirror template — CLOSED.** `gh api repos/$R/contents/cicd/.github/workflows/security.yml` → `404 "Not Found"` this session. Live `cicd/` no longer carries the stale mirror; Phase 20's stale-template deletion (PR #13) removed it, consistent with the plan-01-era observation this same session's Task 1 was asked to re-run rather than inherit.
2. **Blueprint's Grype-based `sca:` example — still OPEN.** `docs/development-security-stack-option-1.md` still documents Syft+Grype as the illustrative SCA tool (lines 41, 61, 130, 304-366, 1580-1594, etc.) and the live pipeline's SCA job runs Trivy filesystem, npm audit, pip-audit and tflint, emitting `sca-results`, not `grype-results`. Rewriting the illustrative example to match is an unbounded blueprint restructuring — not a single-value fix under D-03 — and remains handed to Phase 20 / DIST-06 as originally assigned.
3. **Blueprint example's `push: branches: [main]` trigger — still OPEN, no active owner.** The illustrative workflow section (`docs/development-security-stack-option-1.md:1469-1488`) still shows `push: branches: [main]` alongside `pull_request`. This session confirms the section is now explicitly labeled "Illustrative — Not the Deployable Template" and carries an explicit divergence paragraph naming this exact trigger difference (git history: commit `a54f23c`, "retitle illustrative workflow section" — a Phase 20 change, not a Phase 19 one). Phase 19 (the originally assigned owner, VAL-01) closed without touching this trigger or file (confirmed: no `docs/development-security-stack-option-1.md` edits in any 19-0X-SUMMARY.md). The misleading-authority concern is now substantially mitigated by the explicit labeling, but the literal trigger line itself is unchanged — still OPEN, ownership unassigned since Phase 19 closed without acting; flagged for a future docs-hygiene pass.
4. **`docs/milestone-plan/milestone-2-cicd-gate.md` M2-F3 listing `grype-results.json` — still OPEN.** Live grep this session: line 78 still lists `grype-results.json` among the M2-F3 JSON outputs, and the "Done Criteria" on the same page still names the DefectDojo parser as "Anchore Grype." All five listed filenames (`semgrep-results.json`, `checkov-results.json`, `grype-results.json`, `trivy-results.json`, `gitleaks-results.json`) diverge from the live artifact names (`semgrep-results`, `checkov-results`, `sca-results`, `trivy-image-results`, `gitleaks-results`) — correcting one name without the other four would misrepresent the set, so this is a coordinated rewrite tied to item 2's underlying SCA-tool drift, not a single-value fix. Remains handed to Phase 20 / DIST-06.
5. **Private-repo GitHub Code Security licence limitation — CLOSED.** `docs/adoption-guide.md` §11 "Private Repositories" (line 448) and §12 Troubleshooting (line 494) both document the licensing gate in detail, citing measured evidence from a private pilot repo (`aws-zabbix-monitoring-solution`, PR #8, run `34887388960`) and the private-repo SARIF guard (`&& github.event.repository.private == false`) that Phase 20 plan 04 applied to `security.yml`'s verify steps. This is the "private-repo SARIF guard" PR #13's title referenced — confirmed present and documented, not merely titled. CLOSED.
6. **SARIF size/result limits at consumer scale — still OPEN (informational).** `grep -in 'SARIF.*limit\|25,000\|25000\|10 MB\|20 runs'` across the blueprint, adoption guide, and ADR-016 this session returned no hits — the limits remain undocumented. Fixture-scale runs stay well under GitHub's published caps (10 MB gzipped/file, 20 runs/file, 25,000 results/run, 25,000 rules/run), so this has not yet been exercised in practice. Remains OPEN, informational, owned by Phase 20 per the original ledger.
7. **Blueprint's seven `actions/checkout@<SHA>  # v4` version comments — CLOSED (D-03 trivial fix applied this session).** Live grep confirmed 7 occurrences of `# v4` at lines 939, 1537, 1564, 1585, 1602, 1632, 1657. The live pipeline's actual pin is now `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` (Dependabot PR #5, confirmed in `14-VERIFICATION.md`). This is a single version-comment correction, not a SHA change — the blueprint's placeholder-SHA convention (ADR-004) is untouched. Applied inline: all seven occurrences changed from `# v4` to `# v7`. See Gap Closure table below.

## Gap Closure

| Item | Was | Fixed to | File | Reason the value existed / Chesterton's Fence |
|---|---|---|---|---|
| Deferred item 7 | `actions/checkout@<SHA>  # v4 — pin to current SHA: …` (×7) | `actions/checkout@<SHA>  # v7 — pin to current SHA: …` (×7) | `docs/development-security-stack-option-1.md` (lines 939, 1537, 1564, 1585, 1602, 1632, 1657) | The `# v4` comment existed because it was accurate when Phase 14 first pinned checkout at v7.0.0-era guidance drafted against the then-current major; Dependabot PR #5 (CICD-05, merged 2026-09-10) has since bumped the live pin to v7.0.1. The comment is documentation of intent alongside a deliberate `<SHA>` placeholder (ADR-004) — updating only the human-readable version number, not the placeholder convention itself, keeps both constraints intact. |

Items 2, 3, 4 and 6 remain OPEN and unmodified: none qualifies as a single-value or single-reference fix
under D-03 — each would require restructuring an illustrative example, a coordinated multi-name rewrite,
or authoring new documentation from scratch. They are recorded here and in Phase 17's `deferred-items.md`
status re-check, with owners, rather than silently dropped or fixed out of scope.

---

*Verified: 2026-09-15*
*Verifier: Claude (gsd-verifier)*
