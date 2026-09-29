---
phase: 29-defectdojo-live-validation
verified: 2026-09-30T00:20:00Z
status: passed
score: 8/8
overrides_applied: 0
---

# Phase 29: DefectDojo Live Validation Verification Report

**Phase Goal:** The DefectDojo generic chart (Phase 26) is deployed to the operator's homelab cluster via a private ArgoCD overlay, and CI import (Phase 27) with dedup/triage (Phase 28) is proven live end-to-end against that deployment.
**Requirement:** DDOJO-05
**Verified:** 2026-09-30T00:20:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Must-Have Sourcing

All 19 PLAN.md files that carry a `must_haves:` key have an **empty** `must_haves:` block (checked via `grep -l "must_haves:" .planning/phases/29-*/*-PLAN.md` — all 19 non-29-19 plans match, and every match's `must_haves:` line is followed by no list items). No plan declares a `<verify><human-check>` block (`grep -l "<human-check>"` returned zero files). This phase's must-haves are therefore derived from ROADMAP's Phase 29 goal statement and `29-CONTEXT.md`'s Implementation Decisions (Option C, per the verification process), cross-checked against `29-REVIEW.md` and `deferred-items.md`. `requirements: [DDOJO-05]` is declared identically across all 20 plans and matches `.planning/REQUIREMENTS.md`; no orphaned requirement IDs.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | DefectDojo chart is deployed live to the homelab cluster via a private ArgoCD overlay (two-source Application, pinned SHA, SealedSecrets) | ✓ VERIFIED | Overlay repo `occ-k8s-app-config` local clone `git log` confirms commits `db5aae1` (overlay dir), `b2cacd0` (ghostunnel native sidecar), merges `e965581`/`08ce26b`. `evidence/29-08-first-sync-application.json` and `29-17-second-sync-application.json` are real ArgoCD Application object dumps (verified structure, not placeholders). |
| 2 | The chart's ingress-off / LB-VIP + ghostunnel + cert-manager TLS exposure works live on both hostnames | ✓ VERIFIED | Read the actual verdict lines: `evidence/29-08-homelab-validate-first.txt:30` → `ALL PASS - 7 live check(s) executed and passed; 1 sub-check(s) skipped` (the 1 skip is the expected first-pass SECOND-SYNC-IDEMPOTENT skip); `29-17-homelab-validate-second.txt:35` → `ALL PASS - 8 live check(s) executed and passed; 0 sub-check(s) skipped`. Both match ADR-027's quoted counts exactly. |
| 3 | Self-hosted ARC runner (repo-scoped) carries the `defectdojo-import`/`defectdojo-cleanup` jobs to the private instance | ✓ VERIFIED | Live `gh api .../contents/.github/workflows/security.yml?ref=fdabac9...` shows `runs-on: ${{ vars.DEFECTDOJO_RUNS_ON \|\| 'ubuntu-latest' }}` at lines 1282/1677, five scan jobs unchanged at `ubuntu-latest`. Live `gh api .../actions/variables` confirms `DEFECTDOJO_RUNS_ON=occ-homelab-defectdojo`, `DEFECTDOJO_URL=https://defectdojo.infra...`; `gh api .../actions/secrets` confirms `DEFECTDOJO_API_TOKEN` exists. Overlay commits `ad8c5db` (arc-systems), `1070fac` (arc-runners) confirmed in local clone. |
| 4 | CI import (Phase 27) works end to end against the live instance | ✓ VERIFIED | Independently re-read run conclusions live (not just evidence files): `gh api .../actions/runs/36502430372` (baseline) → `success`, job `security / DefectDojo Import` ran on `occ-homelab-defectdojo-qqrsp-runner-tbt47`; `gh api .../actions/runs/36553070357` (cron `schedule` event) → `success`, import job on `occ-homelab-defectdojo-qqrsp-runner-hqpfs`. Runner names match the `occ-homelab-defectdojo` scale set exactly. |
| 5 | Dedup/triage (Phase 28) work end to end against a real PR lifecycle | ✓ VERIFIED (with a pre-approved, documented scope amendment) | Fixture PR #25 confirmed closed/unmerged via `gh api pulls/25` → `{"merged":false,"state":"closed"}`. Read the actual step verdicts, not just filenames: `evidence/29-16-step3.txt` → `ALL PASS - 5 live check(s)`; `step4.txt` → `ALL PASS - 4 live check(s)` with the exact FP/OOS/RA disposition tuples cited in ADR-027; `step5.txt` → `ALL PASS - 4 live check(s)`, including `D11-STEP5-NO-DANGLING-DUPLICATE: PASS - all 23 duplicate(s) ... reference a finding that exists in the product`. Independently re-read via `gh api`: reimport run `36510481745` (`workflow_dispatch`, `success`, import job on `occ-homelab-defectdojo-qqrsp-runner-flpl2`) and cleanup run `36510679451` (`pull_request`, `success`, cleanup job on `occ-homelab-defectdojo-qqrsp-runner-95kkb`). The amended step-2 scope (excluding trivy-image from the cross-branch duplicates assertion) matches the pre-approved operator ruling supplied in this verification task's brief. |
| 6 | `security.yml` `DEFECTDOJO_RUNS_ON` change shipped as an additive v1.x tag with `v1` moved (ADR-018 convention) | ✓ VERIFIED | Live: `gh api .../git/refs/tags/v1.2.0` → annotated tag `b8ae59d`, which dereferences (`gh api .../git/tags/b8ae59d`) to commit `fdabac9`; `gh api .../git/refs/tags/v1` → `fdabac9` directly. `gh api .../pulls/26` → `merged: true, merge_commit_sha: fdabac9...`. All match ADR-027 §5. |
| 7 | ADR-027 and ADR-028 written, indexed, and DDOJO-05 marked Complete | ✓ VERIFIED | `docs/adr/README.md:37-38` lists both Accepted 2026-09-29; both ADR files are substantive (300+ lines, measured-evidence citations, not stubs); `.planning/REQUIREMENTS.md:26,56` and `repos/security-platform/kubernetes/defectdojo/README.md:55` mark DDOJO-05 Complete (Phase 29). |
| 8 | `bash scripts/check-adoption-guide.sh` stays green after the section-12 `DEFECTDOJO_RUNS_ON` additions | ✓ VERIFIED | Ran locally: `check-adoption-guide: PASSED 16 / FAILED 0`, exit 0. |

**Score:** 8/8 truths verified against the codebase and independent, read-only `gh api`/`git log` checks against the live GitHub repository and the local overlay-repo clones.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `docs/adr/adr027-defectdojo-homelab-live-validation.md` | Records live validation decisions and evidence | ✓ VERIFIED | Substantive, Accepted, indexed |
| `docs/adr/adr028-repo-scoped-arc-runner-for-private-defectdojo-import.md` | Records ARC runner mechanics | ✓ VERIFIED | Substantive, Accepted, indexed |
| `docs/adr/README.md` | Index rows for ADR-027/028 | ✓ VERIFIED | Rows present |
| `.planning/REQUIREMENTS.md` | DDOJO-05 marked Complete | ✓ VERIFIED | Line 26, 56 |
| `repos/security-platform/kubernetes/defectdojo/README.md` | DDOJO-05 row updated | ✓ VERIFIED | Line 55 |
| `repos/security-platform/kubernetes/defectdojo/TRIAGE.md` | Corrected dedup bullet (trivy-image exception) | ✓ VERIFIED | Line 14, matches `deferred-items.md` text |
| `repos/security-platform/scripts/defectdojo-lifecycle-assert.sh` | Trivy-image exclusion (`D11-STEP2-EXCLUSION-KEY`) ported into the canonical helper | ✓ VERIFIED | Present at lines 612-684; see WR-01 discussion below for a documentation-only caveat |
| `.planning/phases/29-defectdojo-live-validation/evidence/*` (63 files) | Measured evidence for every claim | ✓ VERIFIED | Verdict lines spot-checked directly (not just filenames) for 29-08, 29-17, 29-16 step3/4/5; ArgoCD JSON confirmed structurally real |
| Overlay repo commits (`occ-k8s-app-config`, `occ-k8s-cluster-config`) | Real merged PRs for defectdojo/arc-systems/arc-runners/runbook | ✓ VERIFIED | `git log` in local clones confirms all cited commit hashes with matching messages |
| `security.yml` `DEFECTDOJO_RUNS_ON` routing | Shipped at `fdabac9`, tagged `v1.2.0`/`v1` | ✓ VERIFIED | Live `gh api` read of file content at that SHA, and live tag refs |
| Live GitHub repo settings (`DEFECTDOJO_RUNS_ON`, `DEFECTDOJO_URL` vars, `DEFECTDOJO_API_TOKEN` secret) | Set on `security-platform` | ✓ VERIFIED | Live `gh api actions/variables` and `actions/secrets` read |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `security.yml` defectdojo-import/cleanup jobs | ARC runner scale set | `runs-on: vars.DEFECTDOJO_RUNS_ON` | ✓ WIRED | Confirmed live both in file content at the merge SHA and in independently re-fetched run-job `runner_name` values for 4 separate runs (baseline, cron, reimport, cleanup) |
| ArgoCD Application (`defectdojo`) | `security-platform` chart at pinned SHA | two-source Application | ✓ WIRED | `evidence/29-08-first-sync-application.json` real object; overlay repo commit history confirms the source |
| `defectdojo-lifecycle-assert.sh assert-pr-duplicates` | trivy-image exclusion | scan_type+title read live from Tests | ✓ WIRED (logic present and correct) | See WR-01 note below — the exclusion logic is present and correct in the shipped script; the caveat is about which check-ID labels a prior ADR paragraph attributes to it, not about the exclusion's function |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | TBD/FIXME/XXX debt markers | none found | Grep across both ADRs, both new helper scripts, TRIAGE.md and README.md returned zero matches |
| `docs/adr/adr027-defectdojo-homelab-live-validation.md:183-189` | — | Attributes `D11-STEP2A-*` check-ID labels (emitted by the one-off planning helper `29-16-step2-amended.sh`) to the same paragraph that also correctly names the shipped script's actual IDs at `:286-288` (`D11-STEP2-EXCLUSION-KEY`) | ℹ️ INFO (does not block) | Read both ADR paragraphs together: the record is internally traceable (the shipped-script IDs are named correctly a few paragraphs later, and 29-18-SUMMARY:92 already discloses that the exclusion was verified by "offline replay"). This is a readability/erratum nit in an Accepted, append-only record, not a functional gap — the exclusion logic in the shipped script (verified above, lines 612-684) works correctly and was validated by offline replay against real captured PR data plus a negative control. Does not affect DDOJO-05 completeness. No action required to close this phase; an erratum is optional future cleanup. |
| `kubernetes/defectdojo/TRIAGE.md:14`, `README.md:242` | — | States the trivy-image dedup gap as "across branches" only; disposition survival on the *same* branch across a new default-branch SHA is inferred, not measured (WR-04) | ℹ️ INFO (does not block) | This is an inferred corollary explicitly labelled "Inferred, not measured" in 29-REVIEW.md, with a named follow-up and a concrete verification recipe already written down (`deferred-items.md`, `29-REVIEW.md` WR-04). D-11 step 4's own success criterion was same-SHA reimport, which is what was measured and passed; testing disposition survival across a *new* SHA was never in this phase's scope (every `ci/main` import in the phase ran at head `2fda1ac`). Disclosure is present and adequate for phase close; verifying the inference is correctly deferred to the next scheduled import at a new SHA. |

### Requirements Coverage

| Requirement | Source | Description | Status | Evidence |
|-------------|--------|-------------|--------|----------|
| DDOJO-05 | 29-CONTEXT.md, all 20 plans | Chart validated live via private ArgoCD overlay deploy | ✓ SATISFIED | Full chain verified above: overlay deploy, TLS/exposure, ARC reachability, CI import, dedup/triage real-PR lifecycle, ADRs, requirements/README rows |

No orphaned requirements — DDOJO-05 is the sole requirement ID for this phase, declared identically in all 20 plans, and fully accounted for.

### Human Verification Required

None. Both findings carried over from 29-REVIEW.md (WR-01, WR-04) were evaluated against the phase goal and determined not to block: WR-01 is a documentation clarity issue in an already-traceable Accepted ADR (the correct check IDs appear a few paragraphs after the ones under discussion, and the offline-replay caveat is already disclosed in 29-18-SUMMARY), and WR-04 is an explicitly-labelled inference outside this phase's tested scope (same-SHA reimport was the tested criterion; a new-SHA measurement is correctly deferred to a future scheduled run). Neither requires an operator decision to close Phase 29; both are candidates for optional follow-up hardening, already tracked in `deferred-items.md`.

### Gaps Summary

No gaps. All 8 derived observable truths for the phase goal — live ArgoCD overlay deployment of the DefectDojo chart, working TLS/exposure, a working repo-scoped ARC runner, CI import proven end-to-end via real GitHub Actions runs (re-confirmed independently via live `gh api` run/job reads, not just evidence files), dedup/triage proven end-to-end via a real PR lifecycle (fixture PR #25, confirmed closed/unmerged live), the additive v1.x tag/`v1` move (confirmed live against tag refs), and the ADR/requirements closure records — are verified against the actual codebase and against live, read-only GitHub API state, not merely against SUMMARY.md claims. The two WARNING-level findings surfaced by the independent code review (29-REVIEW.md WR-01, WR-04) were evaluated and determined to be non-blocking documentation/inference notes, already disclosed and tracked, rather than must-have failures.

---

_Verified: 2026-09-30T00:20:00Z_
_Verifier: Claude (gsd-verifier)_
