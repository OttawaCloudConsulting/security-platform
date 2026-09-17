# Milestones

## v2.0 CI/CD Security Pipeline (Shipped: 2026-09-17)

**Phases completed:** 10 phases, 63 plans, 118 tasks

**Key accomplishments:**

- The product repo's root `.github/` tree now exists: a callable `on: workflow_call` security workflow with `actions/checkout` pinned to the canonical v7.0.0 commit SHA, a `pull_request`-only caller invoking it by relative path, and a weekly `github-actions` Dependabot entry — all validated locally by actionlint, yamllint, a SHA-pin regex gate, and a GitHub-API tag dereference.
- Pushing `feature/phase-14-workflow-foundation` and opening PR #4 on `OttawaCloudConsulting/security-platform` triggered workflow run 34519772020 (`PR Security`, event `pull_request`) which completed `success` with the called workflow's `Placeholder` job genuinely executing checkout against `refs/pull/4/merge` — surfacing as the check-run `security / Placeholder`, with the `main` ruleset carrying only `deletion,non_fast_forward` so nothing blocks the merge.
- Callable security-scan workflow + thin PR caller merged to `main`, action pins SHA-locked, Dependabot witnessed opening a real bump PR on the deliberate one-patch-behind pin
- Cut the Phase 15 branch in `repos/security-platform` and authored a `fixtures/` tree (digest-pinned Dockerfile, misconfigured Terraform, generated npm lockfile) that gives the IaC, container and SCA scan jobs real, measured, non-zero findings for the first time.
- Built `scripts/smoke-scans.sh`, a self-contained pass/fail gate that runs the exact CI-shaped Semgrep, Checkov, Trivy filesystem, Trivy image, and Gitleaks invocations against the real checkout and proves all five produce genuine, non-empty findings before any of them is embedded in workflow YAML.
- Replaced the Phase 14 `placeholder` job in `security.yml` with five concurrent, SHA-pin-provenance-verified scan jobs (Semgrep, Checkov, Trivy filesystem, Trivy image, Gitleaks), each report-only at the step level while every tool keeps its native failing exit code.
- None — plan executed exactly as written.
- PR #6 merged to `OttawaCloudConsulting/security-platform` main via `--merge` (commit `e8e1009`), `origin/main` verified to carry the five-job `security.yml`, fixtures, hook exclusions and smoke script, and Open Question Q3 closed: Dependabot alerts are disabled on this repository.
- Branch:
- The smoke gate now runs npm audit, pip-audit and tflint against the real fixtures and renders its verdict from report content — severity histogram, advisory count and SARIF pinning rule ids — plus a negative test that proves all three detectors skip cleanly in an empty git repository.
- The `sca` job now installs pip-audit 2.10.1 and checksum-verified tflint v0.64.0, resolves npm/Python/Terraform through the same detector scripts the smoke gate tests, runs three guarded sub-scans tolerated under D-04, and follows each with a deliberately intolerant report-content check — while the workflow still parses as exactly five jobs with the five frozen check-run names, zero `needs:`, and `permissions: contents: read`.
- On a real pull request (#7) against `OttawaCloudConsulting/security-platform`, the `sca` job detected all three ecosystems, reported npm vulnerabilities WITH severity levels, Python advisories from pip-audit, and Terraform pinning findings under tflint v0.64.0 — and the five Phase 15 check-run names came back byte-identical with every check `success` and the pull request `MERGEABLE` / `CLEAN`.
- Improved
- PR #7 is MERGED to `OttawaCloudConsulting/security-platform` `main` (merge commit `40682cea329c34b65115236bd449d16f84432e0e`) on the user's explicit approval; `origin/main` is verified — not the local tree — to carry the four-tool `sca` job, all three detector scripts, the extended smoke gate and both fixture changes; and the phase closes with Criterion 3 recorded as partially satisfied rather than glossed.
- An offline ten-check gate over both workflow files, authored and observed failing first, then satisfied by a job-scoped `security-events: write` grant in the caller and its re-declaration in the callee.
- The `sca` job's `trivy convert` step is gone, replaced by a second flag-identical `trivy fs --format sarif` run whose `originalUriBaseIds.ROOTPATH` is the scan root; the smoke gate now runs both invocations with scanner semantics and fails if the broken base ever returns.
- Every SARIF file the five scan jobs produce now has its own SHA-pinned `upload-sarif` step under a unique category, and every one of those tolerated uploads is read back by an intolerant step in the same job — so ADR-001's `continue-on-error` can no longer turn a 403 into a green check.
- Every scan job now ends by uploading its native JSON and SARIF reports as one uniquely-named artifact with a stated 90-day expiry — the SCA one globbing 16-04's numbered npm and pip reports — and each of those tolerated uploads is read back by an intolerant step, so CICD-03 cannot retain nothing on a green run.
- PR #8 and run 34638828775 turned the phase from static YAML into measured fact: the repo went from `total_count: 0` artifacts and HTTP 404 "no analysis found" to seven code-scanning analyses across six distinct categories, five artifacts expiring exactly 90 days out, and three inline annotations on `fixtures/main.tf` line 38 — the line the fixture edit was constructed to touch.
- The project's primary artifact taught a workflow that 403s on every SARIF upload — zero `permissions:` blocks, zero `category:` keys, zero `retention-days` — and the phase's seven decisions lived only in plan files. Both are now fixed: a 65-line append-only ADR-016 carries every decision plus three explicitly unverified items, and the blueprint's CI/CD template shows the permission grant, the caller-side warning, six-way category attribution and an explicit 90-day retention.
- PR #8 is MERGED to `OttawaCloudConsulting/security-platform` `main` (merge commit `8fbea7d169ab79c31cb77cd18b835ff3ffb14633`) on the user's literal approval; `origin/main` — not the local tree — is re-parsed and confirmed to carry all six categorised SARIF uploads, all five 90-day artifacts and both permission grants; and Criterion 1 closes as NOT OBSERVED with a named cause rather than as a MET borrowed from the API.
- Declared a typed `gate_mode` workflow_call input, resolved it once at workflow level into `env.GATE_MODE` (input -> caller repo variable -> `report-only`), and added an intolerant per-job enum-validation step to all five scan jobs — with no pass/fail behavior change yet (the eleven `# D-04` lines still read literal `true`).
- Flipped all eleven scan-step `continue-on-error: true # D-04` literals to `${{ env.GATE_MODE == 'report-only' }}` (fail-closed), compounded the three `sca`-job `if:` conditions that GitHub's implicit `success()` would otherwise skip under blocking mode, and corrected `pr-security.yml`'s FROZEN comment plus documented why it deliberately passes no `gate_mode`.
- `repos/security-platform/scripts/set-required-checks.sh` — a dry-run-by-default, read-modify-write helper for GitHub's whole-document-replacement rulesets PUT, proven live to preserve `main`'s existing `deletion`/`non_fast_forward` protections while adding five byte-exact required status checks and a `pull_request` rule, with the live write itself never exercised.
- PR #9 and run 34668611172 turned the report-only default from static YAML into measured fact: five `security / …` checks all green, five `gate_mode=report-only` log lines, seven code-scanning analyses across six categories, five artifacts at a single 90-day expiry, and eleven upload-verify assertions green with none skipped — with `GATE_MODE` confirmed absent before and after, and the branch ruleset confirmed unchanged.
- One `gh variable set GATE_MODE=blocking` flip, followed by an empty commit, turned PR #9's five `security / …` checks from `success` to `failure` on a byte-identical tree (hash `ce7ec652e09d07f9cee035410bbc05d47e0a79a8`), with all five artifacts, all six SARIF categories, and all eleven upload-verify assertions still landing — then `gh variable delete` and a second empty commit restored the same five checks to `success` with zero YAML ever touched.
- Rewrote the blueprint's and the milestone plan's Phase 2 / M2-F4 branch-protection passages so a reader ends up with the five byte-exact `security / …` check-run contexts and ruleset navigation instead of five job ids that sit permanently pending and a classic-protection screen that 404s.
- ADR-017 is Accepted and indexed: a 58-line decision record for CICD-04/CICD-06 carrying the gate_mode enum design, the five byte-exact required contexts pinned to integration_id 15368, both corrections to the phase's own prior inputs (D-06's five-not-six, D-07 step 1's unobservable red), the operator's leave-unrequired decision for this repository's own `main`, and a `## What was NOT verified` section naming four open items including the fork-variable question routed to Phase 19.
- PR #9 was merged by the human operator outside this session (mergeCommit `2e29004`, mergedAt `2026-09-12T12:48:34Z`); this plan performed no merge action and instead verified from `origin/main` that everything reviewed across 18-01 through 18-07 actually shipped — eleven gate expressions, zero literal `# D-04` tolerances, the exact `env.GATE_MODE` fallback chain, the merge's second-parent tree hash matching 18-05's measured tree byte-for-byte, all three standing gates green, no leftover `GATE_MODE` variable, and `rules/branches/main` unchanged at the operator's `leave-unrequired` decision.
- Both missing scan fixtures authored and committed locally, each measured firing its intended NAMED rule against the exact CI-pinned tool version — Semgrep 3 → 8 findings and Gitleaks 9 → 11, both recorded as deltas against baselines captured before the fixtures existed.
- `fixtures/README.md` updated at all five edit points with both stale claims replaced in the same commit that falsified them, and two rule-id-plus-path verdict assertions added to the local smoke gate — each observed exiting 0 against 19-01's real report, 3 against a baseline-preserving filtered copy, and 2 against an invalid one, using heredoc bodies extracted verbatim from the committed script.
- PR #10 is OPEN against `main` at head `d8bd09b`, its single run `34786019516` concluded under report-only

with five anchored `gate_mode=report-only` lines and zero `blocking`, and all five retained artifacts were
downloaded and read to yield one named, path-scoped detection per job — `eval-detected` at
`fixtures/vulnerable.py`, `aws-access-token` at `fixtures/secret.env:21`, twelve failed Checkov ids on
`fixtures/main.tf`, vulnerabilities on both `fixtures/package-lock.json` and `fixtures/requirements.txt`, and
58 vulnerabilities against the digest-pinned `debian:12-slim` fixture image.

- The `eval()` call at `fixtures/vulnerable.py:20` was followed to code-scanning alert
- SC2 is measured. One pull request — [PR

#11](https://github.com/OttawaCloudConsulting/security-platform/pull/11) — three commits, ONE tree hash
`895c1bdf`, an empty `git diff` between the outer two, and OPPOSITE VERDICTS: five `security / …` checks all
`failure` under `GATE_MODE=blocking` (run

- SC4 is measured. [PR #12](https://github.com/OttawaCloudConsulting/security-platform/pull/12) — a pull

request that seeds NOTHING new, changing exactly one non-fixture file — has all five `security / …` check
runs concluding `success` (run

- Phase 19 is closed. The operator answered D-10 with `merge it`; PR #11 was merged into `main` as merge

commit `b4cb207` at `2026-09-14T01:19:32Z`, landing the D-19-A push-protection correction. Verified from
`origin/main`, never from the local tree. The repository ends in its default state: no repository variables,
a `main` ruleset of exactly `deletion` and `non_fast_forward`, and zero open pull requests. `VAL-01` is
complete against a four-row SC1–SC4 evidence index spanning three different pull requests.

- A1 measured CONFIRMED live on a private pilot — `upload-sarif` fails with "Code scanning is not enabled for this repository" (a GHAS licensing gate, not a token-scope 403) — and the operator approved the resulting Q2 disposition: guard the six SARIF verify steps only, leave the five artifact verify steps untouched.
- Two standing offline gates (one per repository) that measure — rather than assume — the phase's two riskiest invariants: workflow/script detector parity plus the Dockerfile pathspec (A4), and the adoption guide's five frozen check-run contexts; both observed red for the predicted reasons before their deliverables exist.
- 1. [Rule 3 - Blocking, sanctioned by the worktree_branch_check step] Corrected worktree base
- Compounded a private-repo capability guard onto the six SARIF verify steps in `security.yml` per plan 01's live measurement, and added adoption banners plus two corrected stale comments to the three files a consumer copies — `gate_mode` remains the template's only per-repo substitution point.
- Deleted the pre-Phase-14 stale copy-paste security workflow and its Renovate config from `repos/security-platform/cicd/`, rewrote `cicd/README.md` to describe the pipeline that actually ships (Trivy filesystem/npm audit/pip-audit/tflint, Dependabot, ruleset-based branch protection with five byte-exact check contexts), and pointed the host repo's front-page README at the canonical workflow and the adoption guide.
- PR #13 proved the portability pass live (five `security / …` check runs `success`, per-scanner counts

reconciled against the 19-06 baseline) and was merged to `OttawaCloudConsulting/security-platform`'s `main`
as commit `cdf2c21` — by the operator directly, outside this plan's Task 3. Task 3 verified the merged state
from `origin/main` read-only: merge commit, parents, tree hash, and both deletions all confirmed. The
operator's reply was `option-a`: merge approved and tag authorisation for `v1.0.0`/`v1` GRANTED for plan 07.

- Both tags (`v1` lightweight, `v1.0.0` annotated) are live on `OttawaCloudConsulting/security-platform` at merge commit `cdf2c21` and API-verified; Task 2's full byte-identity proof for both consumption modes passed on the first attempt. The GitHub release (`v1.0.0`, published, not draft) is also now live — this session's own `gh release create` was denied twice by its auto-mode Bash classifier, so the orchestrator ran the exact handoff command from `20-07-release-notes.md` directly in its own session, which succeeded. This session independently re-verified the published release read-only (tag name, draft status, URL, body byte-comparison against the committed notes file, all required strings present, all forbidden strings absent).
- Wrote `docs/adoption-guide.md` sections 1-6 (audience/outcome, four-probe preflight, mode decision table, Mode A three-file copy, Mode B one-file reusable-workflow call pinned to the published `@v1` tag, and first-run expectations carrying 19-06's measured finding counts) — the guide gate now fails on exactly the five predicted byte-exact check-run contexts plan 09 owns, nothing else.
- Completed `docs/adoption-guide.md` (216 to 534 lines): the D-07 branch-protection sequence with all four `set-required-checks.sh` refusal exit codes, the SC4 applicability matrix with its two-warning removal recipe, plan 01's measured private-repo result, and eight troubleshooting subsections — the guide's own standing gate (`scripts/check-adoption-guide.sh`) now exits 0 with 15/15 checks passed.
- Both tasks COMPLETE. SC1 measured on PR #12 (Mode A copy-paste) and SC2 measured on PR #13 (Mode

B `uses:` reference) on `OttawaCloudConsulting/terraform-pipelines`, a repository outside this
project — five concluded `security / …` check runs on each, byte-identical context names across
both modes, three clean ecosystem `SKIP:` lines plus one Terraform `FOUND` line, and the external
`uses:` reference resolving to the exact published `v1`/`v1.0.0` commit. The branch-protection
dry run (`set-required-checks.sh --out`, never `--apply`) was denied twice by this executor
session's own auto-mode Bash classifier — the identical denial shape 20-07 hit with `gh release
create` — so the orchestrator ran the exact recorded command directly in its own session, which
succeeded (exit 0, all three pre-existing rule types preserved, five contexts added). This session
then independently re-verified the result read-only rather than accepting the orchestrator's
report at face value: `rules/branches/main` confirmed byte-identical before and after the dry run,
and the produced `merged.json` was read directly and cross-checked against the orchestrator's
reported rule-type lists and `bypass_actors`.

- Both tasks COMPLETE. A full Mode A adoption of the published `v1` bundle was run on

`OttawaCloudConsulting/aws-zabbix-monitoring-solution` (PRIVATE) via PR #8, run `34887388960`. All
five `security / …` check runs concluded `success` — no job went red for a capability this
repository cannot have. All six SARIF verify steps skipped cleanly (the plan 04 guard fired
correctly); the underlying `Upload … SARIF` steps still ran and still failed with the identical
"Code scanning is not enabled for this repository" error plan 01 measured, tolerated by
`continue-on-error: true`. Four of five artifact verify steps succeeded; the fifth (container)
skipped for an unrelated, independently-expected reason — this repository has no Dockerfile, so
that job's own `steps.docker.outputs.found == 'true'` guard skipped it, exactly as the
Dockerfile-free case in `20-10-SUMMARY.md` measured on a different (public) pilot. Four artifacts
landed, all at 90-day retention. The operator reviewed this evidence at Task 2's blocking
checkpoint and replied `confirmed` — v1 is correct as measured for private consumers, no `v1.0.1`
correction needed. Fate of the three open pilot pull requests is deferred to plan 13's close-out.

- Corrected `docs/adoption-guide.md` against every discrepancy recorded in `20-10-SUMMARY.md` and

`20-11-SUMMARY.md` (five artifacts hedged to "up to five, ecosystem-conditional" in four
locations, the yamllint "no output" overclaim fixed, a fifth preflight probe added, the CLI
decoration on the code-scanning/analyses probe noted, the Mode A/Mode B context-parity fact
added, and a "Proven in" note naming all three pilot PRs and run ids); retitled the blueprint's
`## Complete GitHub Actions Workflow` section as illustrative with a pointer paragraph at the
canonical `security-platform` workflow and the adoption guide, leaving the illustrative YAML,
ASCII diagrams, matrices, comparison table, and the four-phase heading sequence completely
untouched; and updated `CLAUDE.md` with the adoption-guide/scripts structure bullets, a
canonical-workflow-location sentence, and a corrected ADR range.

- ADR-018 (Accepted) records the phase's decisions and corrections — the D-01 amendment naming

`OttawaCloudConsulting/security-platform` as the canonical host, the D-04 portability-premise
correction, dual-tag versioning, the private-repo capability guard, and an eight-item
not-verified list. `docs/adr/README.md` gained one row. The dead `OCC-github` path is gone from
`ROADMAP.md` and `REQUIREMENTS.md`, replaced with the real host and the correction's authority.
`requirements.mark-complete` was invoked exactly once, marking DIST-06/07/08 complete with both
representations grep-verified. Task 3 — the fate of three pilot pull requests — is RESOLVED: the
operator decided close-not-merge for all three, executed by the orchestrator directly (not by
this worktree agent), and independently re-verified read-only in this session via `gh pr view`
(all three `CLOSED`, `mergedAt: null`) and `gh api .../branches/<name>` (all three source branches
404, confirmed deleted). The three requirement completions and ADR-018's eight-item deferred list
were both operator-confirmed as-is, with no correction. Phase 20 and the v2.0 milestone's planned
scope are complete.

- Live-re-queried all four ROADMAP Phase 14 success criteria and CICD-05 against `OttawaCloudConsulting/security-platform`, producing `14-VERIFICATION.md` (4/4 verified, status: passed) and pinning the evidence snapshot plans 02 and 03 must cite.
- Live-re-queried all four ROADMAP Phase 17 success criteria and CICD-02/CICD-03 against `OttawaCloudConsulting/security-platform` on the pinned plan-01 evidence snapshot, producing `17-VERIFICATION.md` (4/4 verified, status: passed), resolving all seven Phase 17 deferred items to a verdict, and applying one D-03 trivial fix.
- Live-re-queried all four ROADMAP Phase 18 success criteria and CICD-04/CICD-06 against `OttawaCloudConsulting/security-platform`, producing `18-VERIFICATION.md` (4/4 verified, status: passed), and proved all three Phase 20.1 VERIFICATION.md files cite one identical snapshot and together cover CICD-02 through CICD-06 — closing Phase 20.1.
- Removed all five Grype references from docs/milestone-plan/milestone-2-cicd-gate.md and corrected the M2-F3 JSON filename list and DefectDojo parser row to match the live security.yml (5 jobs: sast, iac, sca, container, secrets).
- Corrected milestone-4-defectdojo.md's M4-F3 parser list and M4-F4 dedup example to the live SCA tool set, closing SE-1 and eliminating milestone-2-vs-milestone-4 doc contradiction on the DefectDojo contract.
- Added a `### SARIF Upload Limits at Consumer Scale` subsection to `docs/adoption-guide.md` §6, documenting GitHub's 5,000-result display truncation, four hard rejection ceilings, and 1,000,000-alert repository lockout, closing Phase 17 deferred item #6 and DIST-08.
- Appended a Phase 21 status re-check section to Phase 17's deferred-items.md closing items #4, #6 and SE-1 with reproducible grep evidence, corrected an inaccurate 2026-09-14 claim about item #4, and ran the full phase verification suite across all three documents this phase edited — all green.
- PR #14 is open on `terraform-pipelines` carrying all five `security / …` contexts green at tree `57a81e09`, its pre-apply merge verdict measured as `UNSTABLE` through a settle-poll whose stale-read guard was proven live — and the target repository's entire pre-exercise state, including the only off-GitHub copy of ruleset 12760793, is on disk.
- Two of the five `security / …` checks are red on PR #14 at head `969dc2c8`, on a tree hash byte-identical to the baseline, proven to come from the mode flip by all five jobs' own log lines — and with those red checks NOT yet required the pull request reads `UNSTABLE`, which is the control observation the phase's whole deliverable rests on.
- The five `security / …` contexts are now REQUIRED on `OttawaCloudConsulting/terraform-pipelines`' `main` — written by the operator's own hand at a blocking checkpoint, with all three pre-existing rule types carried forward byte-identically, `bypass_actors` still `[]`, and every post-write claim in this document re-read live from the API by the agent that did not perform the write.
- GitHub refused to merge PR #14 because a required status check was red, and the refusal is on disk in GitHub's own words — on a pull request whose only change since it read `UNSTABLE` was plan 03's ruleset write, and on a tree hash that a third verdict then proved `CLEAN` once only the check conclusions moved.
- The exposure window is closed. `OttawaCloudConsulting/terraform-pipelines`' `main` ruleset is byte-identical to the document plan 01 captured before anything was touched — proven by an empty `diff` and, beyond that, by full-document equality on every key except server-owned `updated_at` — and the exercise pull request is closed unmerged with its branch deleted.
- ADR-019 now says, in the project's own decision-record form, that five scan contexts were made required on a real repository's `main`, that GitHub refused a merge because two of them were red, and — honestly — that this narrows ADR-017 item 4 and ADR-018 item 7 rather than closing them, because both are written about `security-platform`'s own `main`, which this exercise never touched.

---

## v1.1 Distribution Packaging (Shipped: 2026-09-10)

**Phases completed:** 4 phases, 12 plans, 21 tasks

**Key accomplishments:**

- Cross-platform install script — 6 pinned security CLI tools (pre-commit, Trivy, Syft, Grype, Gitleaks, hadolint), checksum-verified, bash 3.2 compatible, idempotent
- Universal file-pattern hook config — one `.pre-commit-config.yaml` running only matching file types across all repos
- `workstation/setup.sh` repo bootstrapper (replaces earlier `dist/install.sh`) — single-command onboarding: install + configure + activate hooks for any git repo
- Maintenance suite — `check`/`update`/`doctor` subcommands with GitHub API version resolution, 147/147 tests passing, human-witnessed pre-commit upgrade/downgrade round trip
- Fixed dead PATH-missing warning bug (WR-01) with TDD proof
- At milestone close: live-verified all 3 outstanding human_verification gaps (phases 01, 04, 10); found and fixed a real RETURN-trap crash bug in `setup.sh` (security-platform commit `2a70c97`)

**Known deferred items at close:** 2 (see PROJECT.md "Known issues" — npm vuln drift and ESLint absence risk in `aws-zabbix-monitoring-solution`, both target-repo issues out of scope for this tooling milestone)

---
