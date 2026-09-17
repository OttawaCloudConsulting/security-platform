---
phase: 18-configurable-gate-mode-and-branch-protection
verified: 2026-09-15T00:00:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
---

# Phase 18: Configurable Gate Mode and Branch Protection Verification Report

**Phase Goal:** Each consuming repo chooses whether security scans block a merge or merely report, without editing workflow YAML.
**Verified:** 2026-09-15 (session date; live repo state read 2026-09-15 during Phase 20.1)
**Status:** passed
**Re-verification:** No — initial verification (retroactive, authored in Phase 20.1)

## Method

This verification does not trust SUMMARY.md/VALIDATION.md narrative. Every load-bearing claim in the four
ROADMAP success criteria and in CICD-04/CICD-06 was independently re-queried against the live
`OttawaCloudConsulting/security-platform` repository via `gh` (branch ruleset, `rulesets`, check-runs,
repo variables, workflow source) in this session, and the results are reproduced below next to the
original SUMMARY's claim.

This report is retroactive — authored in Phase 20.1, roughly three days after Phase 18 closed on
2026-09-12. Three days of subsequent activity (Phase 19's four PRs, Phase 20's PR #13 merge, one
Dependabot bump) have passed over this configuration without breaking it, which is itself corroborating
evidence that the `gate_mode` wiring and branch-ruleset guidance are stable, not merely once-true.

All evidence in this report cites the single pinned snapshot re-confirmed live in `20.1-01-SUMMARY.md`'s
Task 1 and reused verbatim (not re-derived) by this plan: reference PR `#13`, head
`c06d2729b123094bcbb48e03c1155b72c7727b8c`, reference run `34870572604` (`PR Security`, `success`), merge
date `2026-09-14T17:04:38Z`, `origin/main` HEAD `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`, repo
`visibility: public`. This session re-proved the local clone `repos/security-platform` is still
byte-identical to live `origin/main` for `.github/workflows/security.yml`, `.github/workflows/pr-security.yml`,
`scripts/set-required-checks.sh`, and `cicd/README.md` (`git diff origin/main -- <those 4 files>` empty,
`origin/main` rev-parse matches `cdf2c211…` exactly) before any grep in this report was trusted.

**Read-only scope, explicitly not done:** no `gh variable set`, no ruleset PUT or `--apply` to
`set-required-checks.sh`, no re-run of Phase 18's blocking/report-only experiment. `env.GATE_MODE`'s
resolution chain, the ruleset's current rule types, and the historical run triple are read as they already
exist; nothing was mutated to produce this report.

Distinguishing server-side records from the workflow-definition ref: check-run names and conclusions are
server-side records that hang off the commit/PR head (`c06d272…`); the workflow YAML source of truth
(`env:` resolution line, per-step conditionals, the enum validator) is read from `origin/main`
(`cdf2c21…`). Both are cited below and never conflated.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth (from ROADMAP.md) | Status | Evidence |
|---|---|---|---|
| SC1 | With the gate flag set to blocking, a pull request carrying a seeded finding fails its check; with the flag set to report-only, the same pull request passes. | ✓ VERIFIED | Phase 18's own historical triple, re-queried live this session, not re-run: `gh run view 34668611172 -R $R --json conclusion` → `success` (report-only, commit `31dbb0d`); `gh run view 34669534855 -R $R --json conclusion` → **`failure`** (blocking, commit `5973e8e`); `gh run view 34669700643 -R $R --json conclusion` → `success` (report-only restored, commit `835c43e`). All three runs are still queryable three days later. Corroborated by Phase 19's independent second witness, PR #11's triple (`34791497579` failure / `34790727189` and `34791562222` success), cited from `19-VERIFICATION.md:32`. The experiment was deliberately NOT re-run — re-flipping `GATE_MODE` live would be a mutating command outside this plan's read-only scope, and the historical evidence is sufficient because both bracketing runs and the failing run remain independently resolvable today. |
| SC2 | The flag is settable in both consumption modes — as a `workflow_call` input when the workflow is referenced remotely, and as a repo-level variable or env when the template is copy-pasted. | ✓ VERIFIED | Live `security.yml` line 47 (re-read this session via `contents` API): `GATE_MODE: ${{ inputs.gate_mode || vars.GATE_MODE || 'report-only' }}` — the single workflow-level `env` resolution. `inputs.gate_mode` (declared at line 22, `required: false`, `type: string`, documented as `"blocking" or "report-only". Omit to fall back to the caller repo's GATE_MODE variable, then to "report-only" (D-03)`) serves Mode B (remote `workflow_call`); `vars.GATE_MODE` serves Mode A (copy-paste + repo variable); the `||` chain makes them interchangeable under a documented default. Per-job fail-closed enum validator re-confirmed live at 4 of 5 job locations sampled (lines 70-74, 236-240, 371-375, 897+): `case "${GATE_MODE}" in blocking\|report-only) echo "gate_mode=${GATE_MODE}" ;; *) echo "invalid gate_mode: '${GATE_MODE}' (expected blocking\|report-only)"; exit 1 ;;` — ASVS V5 fail-closed input validation, preventing an arbitrary repo-variable value from silently disabling the gate. |
| SC3 | Switching a repo between blocking and report-only requires no change to workflow YAML. | ✓ VERIFIED | Live `pr-security.yml` (re-read this session via `contents` API), line 60: `uses: ./.github/workflows/security.yml`, followed immediately by line 61's comment `# No \`with:\` block, deliberately — omission is the mechanism, not an oversight.` `grep -n "gate_mode" pr-security.yml` finds only explanatory comments (lines 7, 62, 69, 70, 75), never an active `with: gate_mode:` key — the caller carries no `with:` block, confirming mode is set by repo variable, never by a YAML edit. Paired with `gh variable list -R $R` returning EMPTY this session (`GATE_MODE` unset by design, Phase 18 D-03 fallback, deleted at Phase 19 D-09 — PITFALL-5: unset is the documented steady state, not an unconfigured gate). The empty result is self-explaining precisely because SC2's `||` chain terminates at the `'report-only'` literal when the variable is unset — pairing 06-a with 06-b makes this legible rather than alarming. |
| SC4 | Written branch-protection configuration and steps exist for promoting the scan checks to required checks, including which severity threshold triggers a failure. | ✓ VERIFIED | `bash scripts/set-required-checks.sh --out <scratchpad>/ruleset-merged.json` (DRY RUN, `--apply` never passed) — re-run live this session, exit 0: `BEFORE rule types: ['deletion', 'non_fast_forward']` → `AFTER rule types: ['deletion', 'non_fast_forward', 'required_status_checks', 'pull_request']`, "Every pre-existing rule type preserved; 5 contexts added, each pinned to integration_id 15368.", literal line `DRY RUN complete. No write made to GitHub.` This is the strongest possible evidence — the helper reads live state, produces a correct merged document preserving every pre-existing rule type, and proves non-destructiveness without mutating anything. Complemented by `gh api repos/$R/rules/branches/main --jq '[.[].type]'` → `["deletion","non_fast_forward"]` (no `required_status_checks` present) — this is a PASS, not a FAIL: CICD-04's text is "can be made required ... once enabled", and Phase 18 D-07's operator decision (`18-VALIDATION.md:74`, "this repo has `bypass_actors: []`, so requiring checks here risks locking `main`; decision deferred to operator sign-off") was to leave this repo's own `main` unrequired for now — ADR-017's documented tradeoff, not an unmet requirement. `gh api repos/$R/rulesets --jq '[.[]|{id,name,target,enforcement}]'` → one ruleset, id `14243983`, name `Default`, target `branch`, `enforcement: active`. The five-document byte-exact consistency check (see below) and the per-tool severity-threshold note (`tflint` signals findings via exit code 2, `checkov`/`semgrep`/`trivy`/`gitleaks` via exit code 1, `pip-audit` carries no severity field to threshold on — from `18-06-SUMMARY.md`) complete SC4's "which severity threshold triggers a failure" clause. |

**Score:** 4/4 truths verified

### Five-document check-run context consistency (highest-value drift detector this session)

The five `security / …` context strings from live `check-runs` (filtered `app.id == 15368` on head
`c06d2729b123094bcbb48e03c1155b72c7727b8c` — PITFALL-3: the head SHA carries 12 check-runs from three
different apps; only 5 belong to this workflow) were matched **by content**, `grep -cF`, em dash U+2014
included, against all five documents that publish them:

| Document | `IaC — Checkov` | `SCA — Trivy Filesystem` | `Container — Trivy Image` | `Secrets — Gitleaks` | `SAST — Semgrep CE` |
|---|---|---|---|---|---|
| `repos/security-platform/cicd/README.md` | 1 | 1 | 1 | 1 | 1 |
| `docs/adoption-guide.md` | 1 | 1 | 1 | 1 | 1 |
| `docs/development-security-stack-option-1.md` | 2 | 1 | 1 | 2 | 2 |
| `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` | 1 | 1 | 1 | 1 | 2 |
| `docs/milestone-plan/milestone-2-cicd-gate.md` | 1 | 1 | 1 | 1 | 1 |

All five strings appear at least once, byte-identical (including the U+2014 separator, confirmed via
`hexdump -C` on the live check-run name: `e2 80 94`), in all five publishing documents. Counts above 1 in
the blueprint and ADR-017 reflect the string being referenced in more than one prose location (e.g. a
table and a narrative sentence) — not a mismatch. No rename found; a rename in any one document would
silently convert a future required check into a permanently-pending one (ADR-017's stated tradeoff).

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `.github/workflows/security.yml` `env.GATE_MODE` resolution line | `${{ inputs.gate_mode \|\| vars.GATE_MODE \|\| 'report-only' }}` at line 47 | ✓ VERIFIED | Live `contents` API read this session, matches exactly |
| `.github/workflows/security.yml` eleven `# D-04` conditionals | `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}` × 11 | ✓ VERIFIED | `grep -cF` on live-decoded file → `11`; metacharacter-free cross-check `grep -c "# D-04"` → `12` (11 conditionals + one unrelated `soft_fail: false  # D-04` comment) |
| `.github/workflows/pr-security.yml` caller | No `with:` block passing `gate_mode` | ✓ VERIFIED | Live `contents` API read; only explanatory comments mention `gate_mode`, no active key |
| `scripts/set-required-checks.sh` | Dry-run default, non-destructive read-modify-write | ✓ VERIFIED | Re-run live this session, exit 0, `DRY RUN complete. No write made to GitHub.` |
| `cicd/README.md`'s five contexts | Byte-exact match to live check-run names | ✓ VERIFIED | Five-document consistency table above |
| `.planning/REQUIREMENTS.md` | CICD-04 and CICD-06 marked complete | ✓ VERIFIED | Live grep: line 13 `[x] **CICD-04**`, line 15 `[x] **CICD-06**`; traceability rows line 62 `CICD-04 \| Phase 18 \| Complete`, line 64 `CICD-06 \| Phase 18 \| Complete` |

### Key Link Verification

The `gsd-sdk query verify.key-links` tool would report Phase 18's links as `verified: false, detail:
"Source file not found"` for live CI/API facts (a repo ruleset's rule types, a check-run's app-scoped
name, a historical run's conclusion) — a tooling-fit mismatch, not a defect, per `19-VERIFICATION.md:51-57`.
Each of those live links was independently re-verified by direct `gh`/`gh api` calls in this session
instead.

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `gh variable set GATE_MODE=blocking` | `continue-on-error` evaluating false → run conclusion `failure` | env resolution chain | ✓ WIRED (live) | Evidenced by the historical triple, not by a new mutation: `34669534855` conclusion=`failure` on commit `5973e8e`, bracketed by `34668611172`/`34669700643` both `success` |
| `inputs.gate_mode` | workflow-level `env.GATE_MODE` | `\|\|` fallback chain, line 47 | ✓ WIRED (live) | Live-read `security.yml`; `inputs.gate_mode` declared line 22, resolved into `env` line 47, consumed by the eleven step-level conditionals |
| Eleven check-run context strings | `set-required-checks.sh`'s merged ruleset | `integration_id` 15368 pin | ✓ WIRED (live) | Dry-run output: "5 contexts added, each pinned to integration_id 15368"; matches the five live `app.id == 15368` check-run names exactly |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| CICD-04 | 18-01 through 18-08 | Branch protection config/guidance provided so scan checks can be made required (block merge) once enabled | ✓ SATISFIED | Live ruleset read (`rules/branches/main`, `rulesets`), five byte-exact check-run contexts, `set-required-checks.sh` dry-run output, and the five-document consistency check all re-confirmed live this session. `.planning/REQUIREMENTS.md:13` and `:62` both read `Complete`. |
| CICD-06 | 18-01 through 18-08 | Gate mode (block merge vs report-only) is configurable per consuming repo via a flag/input, not hardcoded | ✓ SATISFIED | Live `env.GATE_MODE` resolution chain, eleven `-F`-counted conditionals, per-job enum validator, empty `gh variable list`, and the historical blocking/report-only triple all re-confirmed live this session. `.planning/REQUIREMENTS.md:15` and `:64` both read `Complete`. |

No orphaned requirements — REQUIREMENTS.md maps only CICD-04 and CICD-06 to Phase 18.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | No `TBD`/`FIXME`/`XXX` debt markers found in any Phase 18 file (`grep -rn "TBD\|FIXME\|XXX" .planning/phases/18-configurable-gate-mode-and-branch-protection/` — no hits) or in `.planning/ROADMAP.md` (`grep -n "TBD" .planning/ROADMAP.md` — no hits; the prior Phase 20.1 planning placeholder was resolved by this phase's own planning) | — | — |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Local clone matches live `origin/main` | `git -C repos/security-platform diff origin/main -- .github/workflows/security.yml .github/workflows/pr-security.yml scripts/set-required-checks.sh cicd/README.md` | empty | ✓ PASS |
| `origin/main` SHA matches pinned snapshot | `git -C repos/security-platform rev-parse origin/main` | `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` | ✓ PASS (matches 20.1-01-SUMMARY snapshot) |
| 04-a: branch ruleset rule types | `gh api repos/$R/rules/branches/main --jq '[.[].type]'` | `["deletion","non_fast_forward"]` | ✓ PASS — documented leave-unrequired starting state, not a failure |
| 04-b: ruleset metadata | `gh api repos/$R/rulesets --jq '[.[]\|{id,name,target,enforcement}]'` | `[{"enforcement":"active","id":14243983,"name":"Default","target":"branch"}]` | ✓ PASS |
| 04-c: five check-run contexts | `gh api repos/$R/commits/c06d272…/check-runs --jq '.check_runs[]\|select(.app.id==15368)\|.name'` | exactly 5, matching Phase 20.1 research verbatim | ✓ PASS |
| 04-d: em-dash separator bytes | `\| head -1 \| hexdump -C` | `e2 80 94` (U+2014 EM DASH) | ✓ PASS |
| 04-e: ruleset dry run | `bash scripts/set-required-checks.sh --out <scratch>/ruleset-merged.json` | exit 0, `DRY RUN complete. No write made to GitHub.` | ✓ PASS |
| 5-document consistency | `grep -cF` × 5 strings × 5 documents | all ≥1 hit, byte-identical | ✓ PASS |
| 06-a: repo variables | `gh variable list -R $R` | empty | ✓ PASS (D-09 confirmed still unset) |
| 06-b: env resolution line | `sed -n '47p'` on live `security.yml` | `GATE_MODE: ${{ inputs.gate_mode \|\| vars.GATE_MODE \|\| 'report-only' }}` | ✓ PASS |
| 06-c: `workflow_call.inputs.gate_mode` | `grep -n "inputs:" -A 8` | declared, `required: false`, documented enum | ✓ PASS |
| 06-d: `-F` conditional count | `grep -cF "continue-on-error: \${{ env.GATE_MODE == 'report-only' }}"` | 11 | ✓ PASS |
| 06-d (negative control): non-`-F` count | `grep -c` (same pattern, no `-F`) | 0 (PITFALL-7 reproduced live) | ✓ PASS — confirms the trap, not a defect |
| `# D-04` cross-check | `grep -c "# D-04"` | 12 | ✓ PASS |
| 06-e: enum validator | `grep -n "Validate gate_mode" -A 4` | fail-closed `case` block at 4+ job locations sampled | ✓ PASS |
| 06-f: caller has no `with:` block | `grep -n "uses:\|with:" pr-security.yml` | only `uses: ./.github/workflows/security.yml`, no `with:` | ✓ PASS |
| 06-g: historical run triple | `gh run view {34668611172,34669534855,34669700643} --json conclusion` | `success`, `failure`, `success` | ✓ PASS |
| 06-h: ADR-001 tolerances | `grep -c "continue-on-error: true .*ADR-001"` | 11 | ✓ PASS |
| Total `continue-on-error:` lines | `grep -c "continue-on-error:"` | 25 (= 11 + 11 + 3 others) | ✓ PASS |

### Probe Execution

Checked `grep -rn 'probe-' .planning/phases/18-*/18-0*-PLAN.md .planning/phases/18-*/18-VALIDATION.md`
(no hits) and `find repos/security-platform/scripts -path '*/tests/probe-*.sh'` (no hits) this session.
This phase is validated via live GitHub Actions runs, live ruleset/check-run reads, and static workflow
grep, not local probe scripts.

### Human Verification Required

None — the UI confirmations these phases required were `checkpoint:human-verify` gates closed during the
original phases, cited above; no new human verification is deferred by this report. (Phase 18's own
required-checks-adoption decision, `18-05` Task/D-07, was a `checkpoint:human-verify` gate closed during
the original phase with the operator's leave-unrequired decision recorded in `18-VALIDATION.md:74`.)

### Gaps Summary

No gaps. All four ROADMAP Phase 18 success criteria and both CICD-04/CICD-06 requirements are
independently confirmed against live GitHub state, not merely re-asserted from SUMMARY/VALIDATION prose.
Two items are worth surfacing as informational context, neither a gap, per the non-concealment discipline
this phase's `<context>` requires:

1. **The leave-unrequired operator decision (Phase 18 D-07 step 3).** `04-a`'s empty
   `required_status_checks` on this repo's own `main` is the documented, operator-approved starting state
   (`18-VALIDATION.md:74`: "this repo has `bypass_actors: []`, so requiring checks here risks locking
   `main`; decision deferred to operator sign-off"), not an unmet requirement. CICD-04's actual text is
   "can be made required ... once enabled" — satisfied by the existence of working, non-destructive
   guidance (`set-required-checks.sh`'s dry run), not by checks currently being required. Adoption of
   step 3 remains deferred past Phase 19, as it was at Phase 18's own close.
2. **The fixture-permanence limitation.** Because Phase 19's `fixtures/` are permanent on `main` (per
   `19-VERIFICATION.md:126-129`), every PR in this repository triggers non-zero findings by construction,
   which is one further reason this repo's own `main` has not been flipped to required-and-blocking —
   doing so today would lock every future PR against the permanent fixtures. This is the same limitation
   `19-VERIFICATION.md` already handed to Phase 20 as a scanner-scope decision; it is not new to this
   report and is not re-litigated here.

**Phase 18 had no pre-existing `deferred-items.md`** (confirmed: `.planning/phases/18-configurable-gate-mode-and-branch-protection/` contained no such file before this plan ran — only 14, 16, 17, and 19 carried one). No new non-trivial finding about Phase 18's own subject matter surfaced during this session's live re-query (both operator-decision items above were already recorded in `18-VALIDATION.md` at Phase 18's own close, not newly discovered here). Per the ledger convention stated in `20.1-PATTERNS.md`'s open-decision resolution (findings about the *verified phase's* subject matter go in that phase's own directory; findings about the *verification work itself* or GSD tooling go in `20.1-.../deferred-items.md`), no `18-.../deferred-items.md` ledger is created by this plan, since there is no new finding to log. This is explicitly stated rather than the paragraph being silently omitted.

---

*Verified: 2026-09-15*
*Verifier: Claude (gsd-verifier)*
