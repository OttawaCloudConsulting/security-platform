---
phase: 20-template-packaging-and-adoption-docs
verified: 2026-09-14T00:00:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
---

# Phase 20: Template Packaging and Adoption Docs Verification Report

**Phase Goal:** Any of the other 6+ org repos can adopt the security pipeline in either consumption
mode by following documentation alone (package the canonical workflow for external adoption,
publish a versioned release, write an adoption guide, prove both consumption modes and the
private-repo failure mode + guard live on repos outside the two owned repos).

**Verified:** 2026-09-14
**Status:** passed
**Re-verification:** No — initial verification

## Method

All 13 PLAN/SUMMARY pairs were read. SUMMARY claims were **not** trusted as evidence; every load-
bearing claim was independently re-checked against live external state (`gh api`/`gh run
view`/`gh release view` against the real `OttawaCloudConsulting/security-platform`,
`terraform-pipelines`, and `aws-zabbix-monitoring-solution` repositories) and against the working
tree in this repository. One methodological correction was made mid-verification: the first run of
`scripts/check-adoption-guide.sh` derived its frozen contexts from a local `repos/security-platform`
clone that was checked out on a stale `feature/phase-19-clean-pr` branch (0 occurrences of the
private-repo guard) rather than `origin/main`. This was caught, `git checkout main && git reset
--hard origin/main` was run bringing the clone to `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` (the
exact commit `v1`/`v1.0.0` point to), and the gate was re-run — result unchanged (15/15 PASS), but
the second run is the one that counts as evidence.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A copy-paste template with a clearly marked substitution point exists and a real external repo adopting it produces a working scan run | VERIFIED | `security.yml` in `security-platform@origin/main` carries an `# ADOPTION:` banner naming the single substitution point (`gh variable set GATE_MODE`). PR terraform-pipelines#12 (public, external repo) ran `34884582425`; independently re-queried: all five `security / …` jobs show `conclusion: success` (SAST, IaC, Secrets, Container, SCA). |
| 2 | A separate repo can call the workflow via `uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@<ref>` against a stable published ref, and it resolves correctly | VERIFIED | Tags `v1` (lightweight, `object.type=commit`) and `v1.0.0` (annotated, dereferences to the same commit) both live and API-verified at `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`. PR terraform-pipelines#13 (Mode B) ran `34885287142`; independently re-queried `referenced_workflows[0].sha` == `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` — exact match to the tags. GitHub release `v1.0.0` independently confirmed live (`isDraft:false`, `publishedAt:2026-09-14T17:45:24Z`) at the real URL. |
| 3 | Adoption docs walk through both consumption modes end to end, and the docs pass their own standing gate | VERIFIED | `docs/adoption-guide.md` has all 13 sections (1–13, confirmed by heading grep). `bash scripts/check-adoption-guide.sh`, re-run against `security-platform@origin/main` (not a stale local clone), returns 15/15 PASS independently in this verification session. |
| 4 | The private-repo failure mode and its guard are proven live, and docs state which jobs apply where | VERIFIED | Guard `&& github.event.repository.private == false` independently confirmed present exactly 6 times in `security.yml` on `origin/main` (fresh clone, `/tmp/sp-verify`). Private-repo pilot PR aws-zabbix-monitoring-solution#8, run `34887388960`, independently re-queried: the SARIF-verify steps (e.g. "Verify Semgrep SARIF upload landed") show `conclusion: skipped` while the underlying `Upload Semgrep SARIF` step still ran (`success`) — exactly the designed behavior (uploads attempt and fail on a GHAS-licensing 403, verify assertions skip cleanly rather than falsely failing). Applicability matrix and removal recipe present in adoption guide section 10. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `v1` / `v1.0.0` tags on `OttawaCloudConsulting/security-platform` | Stable published refs | VERIFIED | Independently queried via `gh api .../git/ref/tags/{v1,v1.0.0}`; both point to `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`, matching `main`. |
| GitHub Release `v1.0.0` | Published, not draft | VERIFIED | `gh release view v1.0.0` confirms `isDraft:false`, live URL reachable. |
| `docs/adoption-guide.md` | 13 sections, passes standing gate | VERIFIED | 13 `## ` section headings confirmed; gate re-run 15/15 PASS against the correct commit. |
| `scripts/check-adoption-guide.sh` | Standing gate, no vacuous passes | VERIFIED | No `|| true` / `2>/dev/null` swallowing found; script does real byte/grep checks (em-dash byte verification, context presence, banned-pattern scan). |
| Private-repo capability guard in `security.yml` | `&& github.event.repository.private == false` on SARIF-verify steps only | VERIFIED | 6 occurrences confirmed on fresh clone of `origin/main`. |
| `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md` | Accepted, addresses DIST-06/07/08 | VERIFIED | File exists, `Status: Accepted`, `Addresses: DIST-06, DIST-07, DIST-08` present, 4 `## ` headings (Context/Decision/Consequences/What was NOT verified), content matches what was actually measured (guard-compounding count corrected to 8, matching 20-03's own measurement; canonical-host correction accurately describes the `OCC-github` 404). |
| `docs/adr/README.md` | ADR-018 indexed | VERIFIED | Row present. |
| Stale `cicd/.github/workflows/security.yml` and `cicd/renovate.json` | Deleted | VERIFIED | Confirmed absent on fresh `origin/main` clone. |
| `docs/development-security-stack-option-1.md` | Illustrative section retitled, 4-phase structure/diagrams/matrices preserved | VERIFIED | `## Complete GitHub Actions Workflow (Illustrative — Not the Deployable Template)` heading confirmed present; SUMMARY's `git diff` hunk-boundary claim (single hunk at the section opening) is plausible and unfalsified by spot-check. |
| `CLAUDE.md` | Reflects real structure, correct ADR range | VERIFIED | Confirmed: "ADR-001 through ADR-018", `docs/adoption-guide.md` bullet, `scripts/` bullet, and a sentence naming `security-platform` as the canonical workflow host are all present in the current working tree (a stale project-instructions snapshot shown earlier in this session, referencing ADR-014, does not reflect the actual file — the live file is current). |
| `.planning/REQUIREMENTS.md` DIST-06/07/08 | Marked complete, no dead `OCC-github` path | VERIFIED | All three `[x]` and three `Complete` Traceability rows confirmed by direct grep; zero `OCC-github` occurrences. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Mode A copy-paste files | consumer repo working scan | `raw.githubusercontent.com/.../v1/<path>` fetch + commit | WIRED | 20-07-SUMMARY's byte-identity diffs (exit 0 for all 3 files) + live PR #12 five green checks, independently re-confirmed. |
| Mode B `uses:` reference | canonical workflow at a pinned ref | `workflow_call` `@v1` | WIRED | `referenced_workflows[0].sha` independently confirmed equal to the tag-pointed commit. |
| Adoption guide | actual workflow job names (frozen contexts) | `check-adoption-guide.sh` context derivation | WIRED | Re-run against the correct `origin/main` commit; 15/15 PASS, not a stale-clone artifact. |
| Private-repo SARIF failure | guard skip | `github.event.repository.private == false` condition | WIRED | Live run `34887388960` independently shows the designed skip/upload-still-runs split. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DIST-06 | 20-04, 20-05, 20-13 | Copy-paste workflow packaged | SATISFIED | Adoption banner present in canonical file; stale competing template deleted; live PR #12 proof. |
| DIST-07 | 20-06, 20-07, 20-13 | Reusable `workflow_call` against a stable ref | SATISFIED | Tags/release independently verified live; PR #13 SHA-match proof. |
| DIST-08 | 20-08, 20-09, 20-12, 20-13 | Adoption docs cover both modes for 6+ repo rollout | SATISFIED | 13-section guide, standing gate passes, corrected against all three live pilot runs (20-12). |

No orphaned requirements found for this phase.

### Anti-Patterns Found

No `TBD`/`FIXME`/`XXX` debt markers found in any phase-modified file (`docs/adoption-guide.md`,
`docs/development-security-stack-option-1.md`, `CLAUDE.md`, `docs/adr/adr018-*.md`,
`docs/adr/README.md`, `scripts/check-adoption-guide.sh`). No `|| true` / silent-swallow patterns in
the gate script outside its own labelled banned-pattern detection list. No blockers.

### Human Verification Required

None. Every success criterion is externally, mechanically verifiable via `gh api`/`gh run view`
against real repositories and was independently re-checked in this session rather than accepted
from SUMMARY.md text.

### Gaps Summary

None. One process note: the first attempt to re-run `scripts/check-adoption-guide.sh` in this
verification session used a local `repos/security-platform` clone that was stale (checked out on
`feature/phase-19-clean-pr`, predating the phase's own portability/guard changes). This was caught
before being reported as evidence, corrected by resetting the clone to `origin/main`
(`cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`, the exact commit the published tags point to), and
re-run — result unchanged (15/15 PASS). This is noted for transparency, not as a phase gap: the
corrected run is what is cited above as evidence.

---

_Verified: 2026-09-14_
_Verifier: Claude (gsd-verifier)_
