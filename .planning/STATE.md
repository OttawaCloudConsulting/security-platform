---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: CI/CD Security Pipeline
status: executing
stopped_at: HALTED at 19-05-PLAN.md Task 3 checkpoint (SC2 measured, GATE_MODE deleted; awaiting operator confirmation of the paired verdicts)
last_updated: "2026-09-14T00:12:02.582Z"
last_activity: 2026-09-14
progress:
  total_phases: 7
  completed_phases: 5
  total_plans: 37
  completed_plans: 35
  percent: 71
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-10)

**Core value:** Every code change is automatically scanned for security issues, secrets, and supply chain vulnerabilities before it can reach production -- with zero ongoing cost and zero vendor lock-in.
**Current focus:** Phase 19 — pipeline-validation-via-branch-target-prs

## Current Position

Phase: 19 (pipeline-validation-via-branch-target-prs) — EXECUTING
Plan: 5 of 7
Status: Ready to execute
Last activity: 2026-09-14

Progress: [██████████] 95%

## Performance Metrics

**Velocity:**

- Total plans completed: 25 (v1.0 + v1.1)
- Total execution time: ~2h 40min

**Recent Trend:**

- Phase 13 P04: ~40min
- Phase 13 P05: ~35min
- Phase 13 P06: ~30min
- Trend: Stable

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions. Recent decisions affecting current work:

- [v2.0 roadmap]: Scanning workflow is authored as `on: workflow_call` from Phase 14, invoked by a thin `pull_request` caller in this repo — so DIST-07 (reusable mode) is a publish step, not a late restructure that would invalidate Phase 19's validation.
- [v2.0 roadmap]: SCA split across two phases — SCA-04 (generic Trivy/Grype filesystem scan) lands in Phase 15 as the zero-config first cut of the 5th job, so CICD-01 ("5 parallel jobs") is genuinely true there; SCA-01/02/03 ecosystem sub-scans follow in Phase 16.
- [v2.0 roadmap]: Gate mode (CICD-06) must work as both a `workflow_call` input and a repo variable/env, since the two consumption modes configure differently.
- [Phase 13]: check/update/doctor split — doctor is a distinct subcommand, update success determined by re-probing not installer exit code, successful fallback never rewrites versions.conf.
- [Phase 12]: Replaced `dist/install.sh` with `workstation/setup.sh` bootstrapper (install + configure + activate).
- [Phase 14-01]: Product repo uses yamllint -d relaxed (its existing pre-commit convention) as the phase gate — no .yamllint added; RESEARCH's truthy+document-start override VERIFIED to error on the 81-char SHA-pin line.
- [Phase 14-01]: actions/checkout pinned to v7.0.0 (9c091bb2) one patch behind v7.0.1 on purpose, so Dependabot's first run yields an observable bump PR (ROADMAP criterion #4).
- [Phase 14-02]: Verbatim check-run name for a reusable-workflow call is 'security / Placeholder' (<caller-job-id> / <called-job-name>) — assumption A3 CONFIRMED; Phase 18 must re-read it after Phase 15 replaces the placeholder with five scan jobs.
- [Phase 14-02]: Merge-blocking evidence on security-platform comes from the rulesets endpoint (rules/branches/main = deletion,non_fast_forward); the 404 on classic branches/main/protection is a false negative and must never be used as evidence.
- [Phase 15-01]: D-02 corrected: currently-supported debian:12-slim digest pin used instead of EOL distro so Trivy reports real, non-decreasing CVE counts (222 vulns, 4 CRITICAL, 52 HIGH measured)
- [Phase 15-01]: D-02 corrected: Checkov findings for main.tf come from misconfigured aws_s3_bucket/aws_security_group resources, not the old provider pin, which produces zero findings alone
- [Phase 15-01]: D-03 corrected: no Gitleaks or .gitleaksignore change made — scoping intent satisfied entirely by four exclude: ^fixtures/ hook entries on terraform_fmt, terraform_validate, hadolint, npm-audit
- [Phase 15]: Split scanner-verdict logic (run_scan, PASS on exit 1) from infra-step logic (require_success, PASS on exit 0) in smoke-scans.sh; docker build and trivy convert both signal success via exit 0, and using the wrong helper on them inverted their pass/fail verdict during first live test.
- [Phase 15]: Assumption A6 confirmed: Checkov 3.3.17 (the exact image bridgecrewio/checkov-action runs in CI) writes identical filenames (checkov-results.json, checkov.sarif) under the comma-mapped --output-file-path syntax as local Checkov 3.2.396 — no filename drift for Plan 03.
- [Phase 15]: Task 1 has no separate commit by plan design — both tasks land in a single feat(15-03) commit at Task 2 step 4, matching 15-01/15-02's verification-then-commit pattern.
- [Phase 15]: Reworded two inline comments to avoid literal substrings ('config auto', 'gitleaks dir') that the plan's own negative-grep verify checks for — RESEARCH's authoritative example uses those exact substrings in comments, so a verbatim copy would have failed the plan's own verification.
- [Phase 15]: No .gitleaksignore change made in 15-03 — smoke gate re-run pre- and post-commit produced the identical 9-finding list from 15-02, none pointing at security.yml.
- [Phase 15]: Phase 15-04: Trivy JSON-format output prints no inline finding count; non-zero evidence rests on --exit-code 1 plus non-empty file sizes, cross-checked against 15-02/15-03 local baselines
- [Phase 15-05]: PR #6 merged to OttawaCloudConsulting/security-platform main via --merge (commit e8e1009); origin/main verified via git show, not local working tree
- [Phase 15-05]: Open Question Q3 closed — Dependabot vulnerability-alerts are disabled on OttawaCloudConsulting/security-platform (404 plus explicit 403 disabled message); dependabot.yml left unmodified
- [Phase 15-05]: D-02/D-03 RESEARCH-corrected forms (C-1, C-2, C-3) confirmed as deliberate implementation choices, not drift from CONTEXT.md
- [Phase 16-01]: fixtures/main.tf needs BOTH an unconstrained random provider AND a random_id resource that uses it — tflint terraform_required_providers does not fire on a declared-but-unused provider
- [Phase 16-01]: No floating range (>= 3.0) added to the fixture — measured NOT flagged by tflint default ruleset, so Criterion 3 is satisfiable only via missing-constraint and unpinned-module cases
- [Phase 16-01]: Measured side effects recorded not predicted — Checkov terraform 10 to 12 failed (CKV_TF_1/CKV_TF_2 on unpinned module), Trivy fs 9 to 19 (10 new pip vulns), Trivy image re-measured identical at 222
- [Phase 16]: 16-02: ecosystem detectors extracted as shared scripts (detect-npm/python/terraform.sh) — CI and the smoke gate call one implementation, so the negative skip test exercises the logic CI runs rather than a copy of it
- [Phase 16]: 16-02: run_scan generalised to run_scan_rc <expected_rc> — tflint signals findings with exit 2 and reserves 1 for application errors; the hardcoded rc=1 PASS would have scored a healthy tflint run as a tool error
- [Phase 16]: 16-02: pip-audit and tflint moved to a soft preflight tier with SKIPPED accounting — A clean workstation without them must not hard-fail the gate, but a skip must never be counted or printed as a pass
- [Phase 16]: 16-03: smoke-gate verdicts read report content, not exit codes — npm audit and pip-audit both exit 1 for findings AND for bad input, so auditReportVersion / dependencies keys plus count assertions are what discriminate
- [Phase 16]: 16-03: SCA-03 asserted on the tflint rule-id set, not a finding count — local tflint 0.61.0 emits 3 ids of which 2 are pinning ids; terraform_module_pinned_source does NOT fire on this fixture, so 16-05 compares CI against three ids
- [Phase 16]: 16-03: SKIPPED bookkeeping moved from the preflight into each sub-scan section so one absent tool is exactly one skipped sub-check (verified: restricted-PATH run reports 2 skips, 7 gated runs instead of 9)
- [Phase 16]: 16-04: sub-scans wired as STEPS inside the existing sca job — job count stays 5, zero needs:, and the sca check-run name stays the inaccurate 'SCA — Trivy Filesystem' because Phase 18 hard-codes it
- [Phase 16]: 16-04: each sub-scan is guarded scan (continue-on-error, D-04) -> intolerant report-content check (no continue-on-error) -> guarded ls evidence; an error-shaped report now turns a step red instead of reading as clean
- [Phase 16]: 16-04: npm and pip reports are NUMBERED per input (npm-audit-<n>.json / pip-audit-<n>.json) — Phase 17's artifact upload must glob, not name
- [Phase 16]: 16-04: the three CI verification bodies were extracted from the committed YAML and executed locally against real and corrupted reports (4 negative cases, all rc=1) rather than trusting the plan's static 'python3 appears in run' check
- [Phase 16]: 16-05: live run 34614017396 on PR #7 confirms tflint v0.64.0 fires the SAME three rule ids as workstation 0.61.0 despite a bundled-ruleset bump 0.14.1 to v0.15.0 — no drift; terraform_module_pinned_source still does not fire
- [Phase 16]: 16-05: the check-runs API returns SIX checks on the head SHA — the five security/* jobs plus an external GitGuardian App check; Phase 18 must decide explicitly whether it belongs in the required-check list
- [Phase 16]: 16-05: tflint version evidenced from the install step's v0.64.0 download URL and the v0.15.0 ruleset doc links, because the job never runs 'tflint --version' and this plan may not modify source
- [Phase 16]: 16-05: Criterion 4 recorded as NOT observed live (the repo has all three ecosystems) — its evidence remains 16-03's empty-repo negative test plus 16-04's static guard assertions; no fixture was deleted to manufacture a skip
- [Phase 16-06]: ADR-015 records tflint adoption with its limit stated as plainly as its benefit — the default ruleset flags MISSING provider constraints and unpinned module sources, but does NOT flag a floating range like >= 3.0; a custom rule is explicitly out of scope
- [Phase 16-06]: pip-audit (Apache-2.0) and tflint (MPL-2.0) added to both blueprint tool tables, licenses resolved from the GitHub API rather than recalled; the zero-cost/zero-account line remains true and unchanged
- [Phase 16-07]: PR #7 merged to OttawaCloudConsulting/security-platform main via --merge (commit 40682ce) on the user's literal 'Approved — merge'; origin/main verified via git show, never the local tree
- [Phase 16-07]: Criterion 3 closed as PARTIALLY satisfied with explicit user acceptance — tflint flags missing provider constraints and unpinned module sources but NOT floating ranges like version = '>= 3.0'; a custom rule stays out of scope per ADR-015
- [Phase 16-07]: the sca check-run name is frozen at 'security / SCA — Trivy Filesystem' (em dash U+2014, re-read from origin/main by yaml parse and byte-dumped) despite the job now running four tools, because Phase 18 hard-codes it
- [Phase 16-07]: Criterion 4 recorded as met by 16-03's empty-repo negative test plus 16-04's static guard assertions, NOT by a live skip — the product repo carries all three ecosystems
- [Phase 17-sarif-upload-and-artifact-retention]: 17-01: the phase's standing offline gate is scripts/check-workflow-uploads.sh in repos/security-platform — ten static checks over BOTH workflow files, exit 0 pass / 1 workflow defect / 2 pyyaml missing, and it was observed FAILING (exit 1, PERMISSIONS-CALLER + PERMISSIONS-CALLEE) before the grant that satisfies it was made
- [Phase 17-sarif-upload-and-artifact-retention]: 17-01: security-events: write now exists on BOTH sides of the workflow_call boundary — job-scoped on jobs.security in pr-security.yml (OD-1) and re-declared at workflow level in security.yml; all three permission mappings parse to exactly {contents: read, security-events: write, actions: read} except the caller's workflow-level floor, which stays {contents: read}
- [Phase 17-sarif-upload-and-artifact-retention]: 17-01: the gate's REDACT-RETAINED check matches an ANCHORED gitleaks invocation line, not the substring 'gitleaks' — the Install Gitleaks step mentions the binary three times and redacts nothing, so a substring test would fail permanently; likewise ARTIFACT-PATH-SAFETY tests '**' separately because the plan's own regex character class admits '*'
- [Phase 17-sarif-upload-and-artifact-retention]: 17-01: the gate deliberately asserts NO counts of upload steps so it passes at every intermediate commit of the phase; 17-03/17-04 assert counts inline, and they inherit UPLOAD-VERIFY-PAIRING (every upload needs an id: and a later same-job step reading steps.<id>.outcome) plus ARTIFACT-PATH-SAFETY (bare-basename *.json/*.sarif globs only, so 16-04's numbered npm-audit-<n>.json must be globbed as npm-audit-*.json)
- [Phase 17-sarif-upload-and-artifact-retention]: 17-01: CICD-02 and CICD-03 were NOT marked complete. requirements.mark-complete flipped both to Complete from this plan's frontmatter and the change was reverted — no SARIF upload step and no artifact upload step exists yet; they ship in 17-03/17-04. Mark them there, not here.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-02: the sca job's `trivy convert` step is GONE — replaced by a second direct `trivy fs . --scanners vuln --format sarif` run with flags identical to the JSON run. Live-confirmed: the gate printed originalUriBaseIds.ROOTPATH = the repo root, not `.../trivy-fs.json/`. The container job's `trivy convert` (security.yml:394-396) is deliberately untouched — it is the conversion step D-01 rests on and ADR-016 (17-06) will record it as the only survivor. — `trivy convert` writes ROOTPATH = the INPUT JSON FILE path, so every uploaded result would resolve to a nonexistent `<workspace>/trivy-fs.json/...` path in code scanning; checkout_path relativization does not rescue it. Landing this before any upload step exists means the first SARIF the repo ever uploads is correctly based.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-02: OD-7 flag parity means the new SARIF invocation is a SCANNER (exit 1 on findings), so in smoke-scans.sh it takes `run_scan`, NOT `require_success` — 17-VALIDATION's blanket "must use require_success" applies only to genuinely exit-0 infrastructure steps. `require_success "trivy-image-convert"` stays. Smoke gate baseline is now 10 gated runs, not 9. — Identical --scanners/--exit-code/--severity on both runs is the only way the retained JSON artifact and the uploaded SARIF can be guaranteed to describe the same finding set (T-17-09). The consequence is scanner semantics; require_success would have scored a healthy findings run as FAIL — the exact inversion Phase 15 hit with docker build and trivy convert.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-02: the smoke gate now carries a ROOTPATH regression guard that fails when runs[0].originalUriBaseIds.ROOTPATH is absent or points at a .json input file (trailing slash or not), with distinct exit codes 3/4/5 per failure mode. All three modes were observed firing against crafted fixtures in a scratchpad, with the heredoc body extracted verbatim from the committed script — no second full-gate run was spent. — The guard is what stops a future "simplify this back to trivy convert" from silently reintroducing RESEARCH Pitfall 3. Proving a guard fires without re-running a 4-minute gate is the reusable technique.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-03: all six SARIF files now upload with a UNIQUE category (semgrep, checkov, trivy-fs, tflint, trivy-image, gitleaks), each pinned to github/codeql-action/upload-sarif@b96794f015dfd88f77b49b1c93e0fa7110f94c63 (v4.38.0), each paired with an intolerant step reading steps.<id>.outcome. wait-for-processing is set NOWHERE — its default true is what makes an async ingestion rejection visible to the assertion. — trivy-fs.sarif and trivy-image.sarif carry the identical tool.driver.name `Trivy`, so GitHub would fail the second upload of the same tool+category in one run; distinct categories are mandatory, not stylistic. ADR-001 requires continue-on-error on the uploads, which alone would turn a 403 into a green check — the intolerant outcome assertion is what reconciles it with the anti-slop rule rather than trading one off against the other. steps.<id>.outcome did not appear anywhere in this repo before this plan.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-03: ONE guard expression on all six verify steps — `always() && github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'` — on the VERIFY step and never on the upload; the tflint pair ANDs `steps.tf.outputs.found == 'true'` into BOTH its upload and its verify. — This settles 17-PATTERNS' flagged disagreement between RESEARCH Pitfall 5 and RESEARCH Code Examples. Fork PRs and Dependabot PRs both get a read-only GITHUB_TOKEN regardless of the permissions key, so the upload cannot succeed there — guarding the UPLOAD would silently publish nothing, guarding the VERIFY skips the check instead. The Dependabot clause is not redundant with the same-repo test: a Dependabot PR is raised on a branch in the SAME repo, so the same-repo test is true for it while its token is still read-only. Consequence for 17-05: the live run must be a same-repo, non-Dependabot PR or all six verifies skip rather than prove anything.

- [Phase 17-sarif-upload-and-artifact-retention]: 17-04: all five scan jobs now leave exactly one artifact — semgrep-results, checkov-results, sca-results, trivy-image-results, gitleaks-results — each pinned to actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a (v7.0.1), each with retention-days: 90 stated EXPLICITLY rather than left to the repo default (Criterion 3 requires a stated period; 90 is the ceiling without a repo-settings change), and each read back by an intolerant steps.<id>.outcome assertion that also echoes artifact-id and artifact-url for 17-05 to cross-check. overwrite / include-hidden-files / archive are absent and asserted absent: overwrite: true would MASK a name collision, include-hidden-files: true would sweep dotfiles into a world-downloadable archive on this PUBLIC repo, archive: false ignores `name` and fails on a multi-file glob. — Formats are each tool's NATIVE output, unnormalised: DefectDojo's dojo/tools/ already ships parsers for every tool in this stack plus a generic SARIF parser, so a common-schema layer would destroy import fidelity for DEFECT-01. The runner's npm is 10.x, so the applicable parser is npm_audit_7_plus, not the legacy npm_audit.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-04: the sca artifact takes if-no-files-found: warn and is the ONLY job where warn is correct — its npm-audit-*.json, pip-audit-*.json and tflint.sarif entries are ecosystem-conditional, so `error` would turn a clean skip red and re-break Criterion 4; trivy-fs.json is unconditional so the artifact is never empty. The other four take `error`.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-04: the Phase 16 glob note CANNOT be a trailing comment on the npm/pip path lines as RESEARCH and PATTERNS both show it — a YAML literal block scalar has no comment syntax, so `npm-audit-*.json  # GLOB …` parses as ONE path string containing the comment and fails both the inline safe-path assertion and 17-01's ARTIFACT-PATH-SAFETY gate. It sits above `path: |` instead, and the reason is recorded in the file so nobody "restores" the canonical snippet verbatim.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-04: scripts/check-workflow-uploads.sh CANNOT exit 0 after Task 1 alone — check 8 (UPLOAD-VERIFY-PAIRING) fires on every id'd upload whose steps.<id>.outcome reader is Task 2's deliverable, contradicting Task 1's own acceptance criterion and 17-01's "passes at every intermediate commit" scope note. Resolved by verifying the FAILURE SHAPE instead: predicted and observed exactly 5 failures, all UPLOAD-VERIFY-PAIRING, one per artifact-* id, nothing from ARTIFACT-RETENTION or ARTIFACT-PATH-SAFETY; the gate is not a pre-commit hook (checked), so no --no-verify was needed and the two-commit structure held.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-04: the fork/Dependabot guard on the five ARTIFACT verify steps is applied for UNIFORMITY with 17-03's six SARIF verifies, NOT because it was measured — upload-artifact authenticates with ACTIONS_RUNTIME_TOKEN rather than GITHUB_TOKEN and may well succeed on fork and Dependabot runs. Stated in the file as an open observation handed to Phase 18, never as a fact.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-04: the container job's stale comment claiming github.sha is the only context interpolation in any run: block (17-03-SUMMARY issue #3) was reworded inside Task 2's commit, since Task 2 adds twenty more step-outcome/artifact-id interpolations to that file. The security claim was already true and is unchanged; only the count was wrong.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-05: the live run is PR #8 / run 34638828775 on OttawaCloudConsulting/security-platform. Measured before/after pair: artifacts total_count 0 -> 5, code-scanning/analyses HTTP 404 "no analysis found" -> 7 analyses across the six distinct categories semgrep, checkov, trivy-fs, tflint, trivy-image, gitleaks on refs/pull/8/merge. Five artifacts (semgrep-results, checkov-results, sca-results, trivy-image-results, gitleaks-results), all non-zero, all expires_at 2026-12-10T19:26:17Z = EXACTLY 90 days after the run created_at. sca-results downloads as npm-audit-1.json, pip-audit-1.json, tflint.sarif, trivy-fs.json, trivy-fs.sarif, proving 17-04's glob. All ELEVEN intolerant .outcome assertions green, zero skipped. PR left OPEN and unmerged. — Everything before 17-05 was static YAML. This is the first time the caller-side permission grant, the six categories and the retention keys met the real GitHub API, and every value is read from gh api rather than recalled (T-17-21).
- [Phase 17-sarif-upload-and-artifact-retention]: 17-05: Criterion 2 is OBSERVED, not the pre-authorised NOT OBSERVED. The fixture edit was placed on fixtures/main.tf line 38 (the `module "fixture_unpinned_module" {` header) because it is the reported startLine for Checkov CKV_TF_1 and CKV_TF_2 AND the exact single line for tflint terraform_module_version. Three code-scanning annotations rendered there (tflint warning 38-38; Checkov failure 38-42 x2) and ZERO annotations on the other four github-advanced-security check runs, despite the run carrying 91 results in total (0+3+3+6+14+56+9) of which 88 went unannotated. RESEARCH Open Question Q2 is answered YES: annotations DO render with no base analysis on main to diff against, so D-02's pull_request-only trigger needs no push: branches: [main] companion. — Pre- and post-edit rule-id sets were measured identical (Checkov 14 total / 12 on main.tf both times; tflint the same three ids at the same lines), so the edit provably could not delete the finding the annotation depends on (T-17-24). The absence on the other checks is what makes the presence informative — Pitfall 4's discrimination worked exactly as described.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-05: code scanning creates ONE check run per tool.driver.name, NOT per category — Phase 18's open question, resolved. `Trivy` appears exactly ONCE on the head SHA despite owning both trivy-fs and trivy-image. Six new checks appeared, which is the number the per-category hypothesis predicted, but the sixth is `tflint-errors` — tflint's single SARIF carries TWO drivers, so it yields two analyses and two check runs under one category. The head SHA now carries 12 checks byte-exactly: 'tflint-errors', 'tflint', 'Semgrep OSS', 'Checkov', 'Trivy', 'gitleaks', 'security / IaC — Checkov', 'security / SAST — Semgrep CE', 'security / Secrets — Gitleaks', 'security / Container — Trivy Image', 'security / SCA — Trivy Filesystem', 'GitGuardian Security Checks' (16-05's six, unchanged, plus six from github-advanced-security). Nothing added to any required-check list. — Matching the predicted count would have been a false confirmation — the rule must be read off WHICH members produce the count. Two further Phase 18 inputs: the `Checkov` code-scanning check concluded FAILURE while all five job checks were green and the PR stayed MERGEABLE, so making these checks required would block a PR carrying deliberately vulnerable fixtures; and the analyses endpoint and check-runs endpoint DISAGREE ON CASE (analyses `checkov`/`Gitleaks` vs check runs `Checkov`/`gitleaks`), so a required-check list must be built from commits/{sha}/check-runs, never from code-scanning/analyses.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-06: ADR-016 (docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md) is Accepted and carries all nine decisions: six sticky categories; caller-job security-events: write + callee re-declaration + actions: read for private-repo portability; outcome-not-sarif-id assertion; ADR-001 tolerated-upload/intolerant-assertion pairing; five artifact names + explicit retention-days: 90; native JSON retained unnormalised (dojo/tools parser inventory, npm_audit_7_plus); sca direct trivy fs --format sarif with the measured ROOTPATH comparison and trivy convert retained in the container job; D-01's Criterion 4 via the artifact set (pip-audit has NO severity field, so a hand-rolled converter would emit level: warning for everything); D-02's pull_request-only trigger with the default-branch consequence stated. — Deliberate divergence from the plan: the plan (written before 17-05 ran) told 17-06 to record annotation rendering as UNVERIFIED. 17-05 measured it as OBSERVED, so the ADR says observed, and the not-verified section instead names three genuinely open items: Dependabot security-events grantability, whether upload-artifact itself succeeds on fork/Dependabot runs (ACTIONS_RUNTIME_TOKEN differs), and how GitHub's ingester treats an out-of-repo ROOTPATH. Evidence outranks a plan written before the evidence existed.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-06: blueprint before/after, measured by grep — upload-sarif '# v3' 3->0 and '# v4' 0->3; upload-artifact '# v4' 5->0 and '# v7' 0->5; retention-days 0->6; category: 0->4; security-events 0->2; code fences 134->134 (unchanged); live 40-hex SHAs 0->0 (every `@<SHA>` placeholder intact per ADR-004). Cross-Platform CI Compatibility table 6->9 rows, uniform pipe count, all six originals byte-unchanged; the language matrix 16-06 updated is untouched. Seven deferrals logged in .planning/phases/17-.../deferred-items.md, three of whose owners were assigned by 17-06 rather than by the plan and are labelled as such. — The plan's own verify commands use `git diff HEAD~1 --name-only`, which diffs against the WORKING TREE; with this repo's pre-existing uncommitted .claude/ tooling changes it reported 139 files and a false FAIL. The correct form is `git diff HEAD~1 HEAD --name-only`; both commits confirmed to contain exactly the named files.
- [Phase 17-sarif-upload-and-artifact-retention]: 17-05: `gh auth refresh -h github.com -s security_events` was NOT run and was not needed. The local token carries only 'gist', 'read:org', 'repo', 'workflow' — no security_events — yet every code-scanning read succeeded, because that scope is required only for PRIVATE repos and security-platform is PUBLIC. The pre-upload 404 also carries a misleading `gh: This API operation needs the "admin:repo_hook" scope` decoration. VERIFIED: it was not a permission problem (no 403 at any point on a token with no security_events scope). BELIEF, not verified: that the line is the CLI's generic error hint rather than the API's own complaint — the mechanism was not investigated. — gh auth refresh is an interactive device-code flow that would have blocked an autonomous run; firing the documented fallback pre-emptively would have hung the plan on a problem that did not exist. T-17-22 closes by evidence (no 403 at any point) rather than by mitigation.
- [Phase 18]: [Phase 18-06]: Corrected the blueprint's and milestone plan's Phase 2/M2-F4 branch-protection passages -- five byte-exact security / ... check-run contexts (not job ids), ruleset navigation (not classic branch protection), gate_mode documented in both consumption modes, and the D-07 report-only-then-blocking-then-require adoption order
- [Phase 18]: [Phase 18-06]: Milestone plan's Done Criteria line could not contain the literal substring 'Settings > Branches' even as a negative example -- reworded to 'the classic branch-protection settings screen' to satisfy the plan's own negative-grep verify check while preserving the 404 caveat's meaning
- [Phase 18]: Phase 18-07: ADR-017 recorded (Accepted) for CICD-04/CICD-06 -- gate_mode enum, five required contexts pinned to integration_id 15368, D-06 five-not-six correction, D-07 step 1 unobservable-red correction, leave-unrequired for this repo's own main
- [Phase 18]: Phase 18-07: discovered PR #9 was already merged (2026-09-12T12:48:34Z, commit 2e29004) before this plan's live cross-check ran -- handed to 18-08 to reconcile, not resolved here
- [Phase 18]: Phase 18 closed: PR #9 already merged by human operator (mergeCommit 2e29004) before 18-08 began; verification confirmed from origin/main that the merged tree hash (ce7ec652...) matches 18-05's measured tree exactly, all standing gates pass, no leftover GATE_MODE variable, rules/branches/main unchanged at operator's leave-unrequired decision
- [Phase 19]: 19-01: the Gitleaks pre-fixture baseline ALREADY carries 8 aws-access-token findings in .planning/ history (05-02-SUMMARY, 05-VERIFICATION, STATE.md L82), so every Secrets assertion from 19-03 onward must AND the rule id with secret.env in File — An SC1 check of the form "gitleaks-results.json contains a finding with RuleID == aws-access-token" passes against the UNTOUCHED baseline and proves nothing. PATTERNS S-4 is now a measured necessity for Gitleaks, not just a Semgrep convention. Measured: baseline 9 findings, 8 of them aws-access-token, zero on secret.env.
- [Phase 19]: 19-01: VAL-01 deliberately NOT marked complete — local fixture seeding cannot satisfy "full pipeline validated in this repo using branch-target PRs"; it needs the live PR runs in 19-03+ — Follows the 17-01 precedent already recorded in this file, where requirements.mark-complete flipped CICD-02/03 to Complete from plan frontmatter and the change had to be reverted because the deliverable actually shipped in a later plan.
- [Phase 19]: 19-01: measured deltas 2026-09-12 — semgrep p/default 3 to 8 (3 new on fixtures/vulnerable.py, 2 on fixtures/secret.env) and gitleaks 9 to 11 (aws-access-token line 21, generic-api-key line 22); committed blobs verified byte-identical to the measured files — No registry drift from RESEARCH predictions — the 3-rule Semgrep baseline reproduced exactly and the 2/2 Gitleaks split held. ruff --fix did NOT rewrite the fixture at commit (sha256 unchanged, git show piped to diff empty), and the pinned v0.15.7 hook agreed with the local 0.14.8 binary. The semgrep binary self-reports 1.155.0 while pip metadata says 1.177.0 (assumption A5 confirmed, deliberately not resolved).
- [Phase 19]: 19-02: smoke-gate rule-id assertions were discretionary per RESEARCH and taken deliberately — p/default resolves from the registry at scan time, so an informational print that swallows its own result is a live false-pass mechanism
- [Phase 19]: 19-02: VAL-01 still not marked complete — it needs the live branch-target PR runs in 19-03+, following the 17-01 reverted-mark precedent
- [Phase 19-03]: The push blocker was SERVER-SIDE GitHub Push Protection (GH013) on fixtures/secret.env lines 21-22, not the local pre-push hook — --no-verify is client-side and cannot reach it. Cleared by the user approving two per-secret unblock URLs (reason: used in tests); no .gitleaksignore fingerprint, no rebase, no fixture edit.
- [Phase 19-03]: Approving the unblock allowances did NOT enable Secret Scanning — security_and_analysis still reports secret_scanning and secret_scanning_push_protection disabled, so the allowance is a per-blob bypass and the measurement conditions for plans 19-04..06 are unchanged.
- [Phase 19-03]: PR #10 is the long-lived D-05 validation PR, OPEN at head d8bd09b with exactly ONE run (34786019516) — plan 19-04's SC3 trace and plan 19-05's blocking re-run must both reference that run id.
- [Phase 19-03]: Five green 'security / ' checks are report-only tolerance (continue-on-error: true), NOT zero findings — the Secrets step itself exited 1 while its check concluded success; SC1 rests on rule-id-plus-path reads from all five downloaded artifacts.
- [Phase 19-03]: VAL-01 still NOT marked complete (19-01/19-02/17-01 precedent) — SC2 and SC3 remain unmeasured until plans 19-05 and 19-04.
- [Phase 19]: [19-04]: SC3 closed on BOTH halves — the eval() finding traced source line 20 -> code-scanning alert 98 -> semgrep-results.json line 20, and the operator replied 'approved' at alert 98's own html_url. — RESEARCH Q2's remedy for what cost Phase 17 a criterion: capture the full API evidence AND hand the human exactly one URL with one yes/no question, rather than offering API evidence where a UI observation was asked for. The unfiltered alerts list returning [] was recorded as a deliberate CONTROL (by design under ADR-016 D-02), not treated as a fault.
- [Phase 19]: [19-04]: code-scanning endpoint-shape quirk — the LIST endpoint returns state:'open' for alert 98 while the SINGLE-alert endpoint code-scanning/alerts/98 returns state:null for the same alert in the same minute. — A difference in the reader, not in the finding: number, rule.id, path, start_line, ref and html_url are identical across both responses. Plan 05 re-queries alerts after the GATE_MODE flip — do not read a null state from the single-alert endpoint as drift or as an alert having been dismissed.
- [Phase 19]: [19-04]: VAL-01 still NOT marked complete, superseding the 19-03 note. SC1 (19-03) and SC3 (19-04, both halves) are closed; SC2 is unmeasured until plan 05 and SC4 until plan 06. Plan 07 owns VAL-01's closure. — Follows the 19-01/19-02/19-03 and 17-01 precedent. requirements.mark-complete was deliberately not invoked by 19-04 — an executor or verifier reading requirements-completed: [] on 19-04-SUMMARY should read it as withheld on purpose, not as a missed step.

### Pending Todos

None.

### Blockers/Concerns

- ~~Scan fixtures are needed from Phase 15, not just Phase 19.~~ — RESOLVED in Phase 15 (merged to `main` in
  Plan 05, commit `e8e1009`): `fixtures/Dockerfile`, `fixtures/main.tf`, `fixtures/package.json`,
  `fixtures/package-lock.json`, and `fixtures/README.md` now exist on `OttawaCloudConsulting/security-platform`
  `main`, giving the IaC, container, and SCA jobs real content to scan.

- ~~This repo's own hooks will block committing those fixtures.~~ — RESOLVED in Phase 15 (merged to `main` in
  Plan 05): four `exclude: ^fixtures/` entries on `terraform_fmt`, `terraform_validate`, `hadolint`, and
  `npm-audit` in `.pre-commit-config.yaml` scope the exemption to `fixtures/` only, leaving the repo's
  protection intact elsewhere. No Gitleaks/`.gitleaksignore` change was needed (RESEARCH C-3).

- ~~No `.github/` directory exists yet~~ — RESOLVED in Phase 14 Plan 01, merged in Phase 14 Plan 03 (not
  "unpushed" — RESEARCH C-6 found this note stale): the product repo (`repos/security-platform`) has had
  `.github/workflows/security.yml`, `.github/workflows/pr-security.yml`, and `.github/dependabot.yml` on
  `main` since Phase 14, and `security.yml` now carries Phase 15's five parallel scan jobs.

- 18-08 must reconcile: PR #9 (OttawaCloudConsulting/security-platform) was found already merged (mergedAt 2026-09-12T12:48:34Z, merge commit 2e290042a775ff1c442bac75757ef8d0106d7dc3) when 18-07's live cross-check ran, before 18-08 had executed -- 18-05 recorded PR #9 as OPEN/MERGEABLE at that plan's end, so the merge happened outside any plan this executor could see

## Deferred Items

Carried forward from v1.1 close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Target-repo issue | `aws-zabbix-monitoring-solution` package-lock.json has 16 real npm vulns (1 critical: handlebars, 10 high); npm-audit hook correctly blocks commits | Deferred — target-repo remediation, not tooling | v1.1 close (2026-09-10) |
| Known gap | ESLint hook uses `language: system`; if eslint is absent and a `.js`/`.ts` file is staged, hook errors rather than skipping | Accepted, not fixed | v1.1 close (2026-09-10) |
| Phase 14 P01 | 12min | 3 tasks | 3 files |
| Phase 14 P02 | 7min | 2 tasks | 1 files |
| Phase 15 P01 | 20min | 2 tasks | 6 files |
| Phase 15 P02 | 25min | 2 tasks | 1 files |
| Phase 15-five-parallel-scan-jobs P03 | 20min | 2 tasks | 1 files |
| Phase 15 P04 | 25min | 2 tasks | 0 files |
| Phase 15 P05 | 20min | 2 tasks | 0 files |
| Phase 16 P01 | 18min | 2 tasks | 3 files |
| Phase 16 P02 | ~56min | 2 tasks | 4 files |
| Phase 16 P03 | ~35min | 2 tasks | 2 files |
| Phase 16 P04 | 25min | 3 tasks | 1 files |
| Phase 16 P05 | ~15min | 2 tasks | 0 files |
| Phase 16 P06 | ~12min | 2 tasks | 3 files |
| Phase 16 P07 | ~10min | 2 tasks | 0 files |
| Phase 17-sarif-upload-and-artifact-retention P01 | 20min | 2 tasks | 3 files |
| Phase 17-sarif-upload-and-artifact-retention P02 | 5min | 2 tasks | 2 files |
| Phase 17-sarif-upload-and-artifact-retention P03 | 12min | 2 tasks | 1 files |
| Phase 17-sarif-upload-and-artifact-retention P04 | 14min | 2 tasks | 1 files |
| Phase 17-sarif-upload-and-artifact-retention P05 | 11 min | 2 tasks | 1 files |
| Phase 17-sarif-upload-and-artifact-retention P06 | 18 min | 2 tasks | 4 files |
| Phase 18 P06 | 15min | 2 tasks | 2 files |
| Phase 18 P07 | 35min | 2 tasks | 2 files |
| Phase 18 P08 | 25min | 2 tasks | 1 files |
| Phase 19 P01 | 18min | 3 tasks | 2 files |
| Phase 19 P02 | 24min | 2 tasks | 2 files |
| Phase 19 P03 | 22min | 2 tasks | 1 files |
| Phase 19 P04 | 11min | 2 tasks | 1 files |

## Session Continuity

Last session: 2026-09-14T00:12:02.379Z
Stopped at: HALTED at 19-05-PLAN.md Task 3 checkpoint (SC2 measured, GATE_MODE deleted; awaiting operator confirmation of the paired verdicts)
Resume file: .planning/phases/19-pipeline-validation-via-branch-target-prs/19-05-PLAN.md

## Operator Next Steps

- **Phase 16 is complete and merged.** PR #7 merged to `OttawaCloudConsulting/security-platform` `main`
  as merge commit `40682cea329c34b65115236bd449d16f84432e0e`; `origin/main` carries the four-tool `sca`
  job, `scripts/detect-{npm,python,terraform}.sh`, the extended `scripts/smoke-scans.sh`,
  `fixtures/requirements.txt` and the extended `fixtures/main.tf`. The local checkout of
  `repos/security-platform` is on a clean `main` at `40682ce`; the merged local feature branch was
  deleted, the remote one was left in place (non-blocking loose end).

- **Next:** verify Phase 16, then Phase 17 (SARIF upload and artifact retention). Phase 17 must not
  re-derive the four facts recorded in `16-07-SUMMARY.md`: npm/pip report filenames are numbered per
  input (glob, never name), neither npm audit nor pip-audit emits SARIF while tflint does,
  pip-audit's JSON carries no severity or CVSS field, and `--audit-level` does not filter npm's report
  even though Trivy's `--severity` does filter Trivy's.

- **Phase 18** inherits the frozen check-run name `security / SCA — Trivy Filesystem` (em dash U+2014,
  re-read from `origin/main`) and must express any gate per tool — tflint signals findings with exit 2,
  the others with exit 1, and pip-audit has no severity field to threshold on.
