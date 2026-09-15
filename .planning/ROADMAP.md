# Roadmap: Security & Supply Chain Scanning Stack

## Milestones

- ✅ **v1.0 M1 Workstation Foundation** — Phases 1-9 (shipped 2026-03-17)
- ✅ **v1.1 Distribution Packaging** — Phases 10-13 (shipped 2026-09-10)
- 🚧 **v2.0 CI/CD Security Pipeline** — Phases 14-20 (in progress)

## Phases

<details>
<summary>✅ v1.0 M1 Workstation Foundation (Phases 1-9) — SHIPPED 2026-03-17</summary>

- [x] **Phase 1: Pre-commit Framework** - Install pre-commit and create the hook configuration file (completed 2026-03-16)
- [x] **Phase 2: Shell and Python Hooks** - ShellCheck and Ruff linting on every commit (completed 2026-03-16)
- [x] **Phase 3: Web and Config Hooks** - ESLint, hadolint, yamllint, and markdownlint on every commit (completed 2026-03-15)
- [x] **Phase 4: Infrastructure Hooks** - npm audit, terraform fmt, and terraform validate on every commit (completed 2026-03-16)
- [x] **Phase 5: Secrets Detection Gate** - Gitleaks pre-push hook blocks leaked credentials (completed 2026-03-16)
- [x] **Phase 6: SCA and Container CLI Tools** - Trivy, Syft, and Grype installed and on PATH (completed 2026-03-16)
- [x] **Phase 7: SAST and IaC CLI Tools** - Semgrep, Checkov, and Gitleaks CLI installed and on PATH (completed 2026-03-16)
- [x] **Phase 8: CLI Tool Scanning Validation** - Every CLI tool runs a real scan and produces JSON output (completed 2026-03-16)
- [x] **Phase 9: Full Stack Validation** - All hooks pass cleanly across the entire repository (completed 2026-03-17)

</details>

<details>
<summary>✅ v1.1 Distribution Packaging (Phases 10-13) — SHIPPED 2026-09-10</summary>

- [x] **Phase 10: Cross-Platform Install Script** - install.sh installs all security CLI tools on macOS and Linux without Homebrew (completed 2026-03-18)
- [x] **Phase 11: File-Pattern Hook Configuration** - Universal pre-commit config with language-aware filters for selective hook execution (completed 2026-03-22)
- [x] **Phase 12: Repo Setup Script** - setup.sh copies configs and wires hooks in any git repo with one command (completed 2026-03-22)
- [x] **Phase 13: Maintenance and Validation** - Version check, update, and health check commands for installed tools (completed 2026-09-10)

See `.planning/milestones/v1.1-ROADMAP.md` for full phase details.

</details>

### 🚧 v2.0 CI/CD Security Pipeline (In Progress)

**Milestone Goal:** Ship reusable/copy-paste GitHub Actions security scanning templates, proven in this repo and ready to adopt across all 6+ org repos.

- [x] **Phase 14: Workflow Foundation and Action Pinning** - Callable security workflow triggers on PRs with SHA-pinned actions kept current by Dependabot (completed 2026-09-10)
- [x] **Phase 15: Five Parallel Scan Jobs** - SAST, IaC, SCA, container, and secrets scans run concurrently on every PR in report-only mode (completed 2026-09-11)
- [x] **Phase 16: SCA Ecosystem Coverage** - SCA job audits npm, Python, and Terraform dependencies alongside the generic filesystem sweep (completed 2026-09-11)
- [x] **Phase 17: SARIF Upload and Artifact Retention** - Findings reach the GitHub Security tab and persist as JSON artifacts (completed 2026-09-11)
- [x] **Phase 18: Configurable Gate Mode and Branch Protection** - Each repo picks block-merge or report-only via a flag, with branch protection guidance (completed 2026-09-12)
- [x] **Phase 19: Pipeline Validation via Branch-Target PRs** - Full pipeline proven end-to-end against seeded findings in this repo (completed 2026-09-14)
- [x] **Phase 20: Template Packaging and Adoption Docs** - Both consumption modes packaged and documented for rollout to the remaining repos (completed 2026-09-14)

## Phase Details

### Phase 14: Workflow Foundation and Action Pinning

**Goal**: This repo has a callable security scanning workflow that runs on every pull request, pinned to immutable action SHAs and kept current automatically.
**Depends on**: Phase 13 (v1.1 shipped)
**Requirements**: CICD-05
**Success Criteria** (what must be TRUE):

  1. Opening a pull request in this repo triggers a security workflow run visible in the Actions tab, and the run completes without blocking the merge.
  2. The scanning workflow is defined with `on: workflow_call` and is invoked by a thin `pull_request` caller workflow in this repo, so the same file is callable from another repo without restructuring later.
  3. Every `uses:` reference in the workflows is pinned to a full commit SHA with a human-readable version comment.
  4. Dependabot opens a pull request against this repo when a pinned action publishes a newer release.

**Plans**: 3 plans

- [x] 14-01-PLAN.md — Create root `.github/` tree in `repos/security-platform/`: callable `security.yml`, `pull_request` caller `pr-security.yml`, `dependabot.yml`; static gate
- [x] 14-02-PLAN.md — Push the product-repo branch, open PR, observe the green PR-triggered run and capture the check-run name (criteria 1-2)
- [x] 14-03-PLAN.md — Human-confirmed merge to `main`, then observe and classify Dependabot's first run (criterion 4 / CICD-05)

### Phase 15: Five Parallel Scan Jobs

**Goal**: Every pull request is scanned by five independent security tools running in parallel, each reporting what it finds without blocking the merge.
**Depends on**: Phase 14
**Requirements**: CICD-01, SCA-04
**Success Criteria** (what must be TRUE):

  1. A single pull request shows five separate scan checks — SAST, IaC, SCA, container, secrets — running concurrently rather than one after another.
  2. Each job's log shows a real result from its tool run against real files in the checkout — repo sources plus the scan fixtures added for the jobs that have nothing to scan otherwise — not a skipped or stubbed step.
  3. The SCA job runs a Trivy/Grype filesystem scan across the repo and reports the packages and vulnerabilities it detects, with no per-ecosystem configuration required.
  4. Each job writes its machine-readable output (SARIF and/or JSON) to a file on the runner, even though nothing consumes those files yet.
  5. A job that reports findings still leaves the pull request mergeable.

**Plans**: 5 plans

- [x] 15-01-PLAN.md — Cut the phase branch, scope four pre-commit hooks away from `fixtures/`, and author the fixture tree (Dockerfile, main.tf, package.json + generated lock, README)
- [x] 15-02-PLAN.md — Author and run `scripts/smoke-scans.sh`, a local pass/fail gate proving all five scanner invocations yield real, non-empty results
- [x] 15-03-PLAN.md — Replace the `placeholder` job with five SHA-pinned, `needs:`-free, step-tolerated scan jobs in `security.yml`; validate statically
- [x] 15-04-PLAN.md — Push, open the PR, and collect live evidence: five concurrent `security / *` checks, all green, PR MERGEABLE
- [x] 15-05-PLAN.md — Human sign-off on concurrency and report-only behaviour, then merge to `main` and close out the phase's open questions

### Phase 16: SCA Ecosystem Coverage

**Goal**: The SCA job audits each dependency ecosystem this practice actually uses, rather than relying on the generic filesystem sweep alone.
**Depends on**: Phase 15
**Requirements**: SCA-01, SCA-02, SCA-03
**Success Criteria** (what must be TRUE):

  1. On a repo containing `package-lock.json`, the SCA job reports npm dependency vulnerabilities with severity levels.
  2. On a repo containing Python dependency files, the SCA job reports Python advisories via pip-audit or an equivalent tool.
  3. Terraform provider and module version pinning is checked, and floating or unpinned versions are reported as findings.
  4. Each sub-scan skips cleanly with a clear log message — no failure, no false pass — when the repo contains no files for that ecosystem.

**Plans**: 7 plans

- [x] 16-01-PLAN.md — Cut the phase branch and seed the missing fixtures: `fixtures/requirements.txt` plus an unconstrained-and-used provider and an unpinned module in `fixtures/main.tf`; re-measure `fixtures/README.md`
- [x] 16-02-PLAN.md — Extract `scripts/detect-{npm,python,terraform}.sh` and generalise the smoke-gate helpers (`run_scan_rc`, `require_parses_json`, soft preflight, SKIPPED accounting)
- [x] 16-03-PLAN.md — Prove npm audit, pip-audit and tflint locally with report-content assertions, plus the Criterion 4 clean-skip negative test in an empty repo
- [x] 16-04-PLAN.md — Add the three detect/scan/verify step groups and guarded evidence steps to the existing `sca` job in `.github/workflows/security.yml`; static validation
- [x] 16-05-PLAN.md — Push, open the PR, and collect live evidence for Criteria 1-3 from the SCA job log; confirm the five check-run names and MERGEABLE
- [x] 16-06-PLAN.md — Record the tflint adoption in ADR-015 and add pip-audit/tflint to the blueprint's tool tables
- [x] 16-07-PLAN.md — Human sign-off on the evidence and the Criterion 3 limitation, then merge and close SCA-01/02/03

### Phase 17: SARIF Upload and Artifact Retention

**Goal**: Scan findings surface in GitHub's Security tab and are retained as JSON so a future DefectDojo import has data to consume.
**Depends on**: Phase 16
**Requirements**: CICD-02, CICD-03
**Success Criteria** (what must be TRUE):

  1. After a workflow run, the repo's Security > Code scanning view shows findings attributed to each scanner separately, so results from one tool do not overwrite another's.
  2. Findings appear as inline annotations on the pull request diff wherever the tool reports a file and line.
  3. Every run leaves downloadable JSON artifacts — one per scan job, including the SCA sub-scans — with an explicit retention period.
  4. A tool without native SARIF output still reaches the Security tab or the artifact set through a documented conversion step.

**Plans**: 7 plans

- [x] 17-01-PLAN.md — Cut the phase branch, author the offline static upload gate, and grant `security-events: write` at the calling job and the callee
- [x] 17-02-PLAN.md — Replace the `sca` job's `trivy convert` with a direct `trivy fs --format sarif` run and mirror it in the smoke gate with a ROOTPATH regression guard
- [x] 17-03-PLAN.md — Add six `upload-sarif` steps with unique categories, each paired with an intolerant `steps.<id>.outcome` assertion
- [x] 17-04-PLAN.md — Add five per-job `upload-artifact` steps with explicit 90-day retention and glob-based SCA paths, each with a landing assertion
- [x] 17-05-PLAN.md — Construct the annotation-capable fixture edit, push, open the PR, and collect live category, artifact and check-run evidence
- [x] 17-06-PLAN.md — Record the decisions in ADR-016 and make the blueprint's CI/CD template copy-pasteable; log the deferrals
- [x] 17-07-PLAN.md — Human verification of the Security tab and PR annotations, then merge and close CICD-02/CICD-03

### Phase 18: Configurable Gate Mode and Branch Protection

**Goal**: Each consuming repo chooses whether security scans block a merge or merely report, without editing workflow YAML.
**Depends on**: Phase 17
**Requirements**: CICD-06, CICD-04
**Success Criteria** (what must be TRUE):

  1. With the gate flag set to blocking, a pull request carrying a seeded finding fails its check; with the flag set to report-only, the same pull request passes.
  2. The flag is settable in both consumption modes — as a `workflow_call` input when the workflow is referenced remotely, and as a repo-level variable or env when the template is copy-pasted.
  3. Switching a repo between blocking and report-only requires no change to workflow YAML.
  4. Written branch-protection configuration and steps exist for promoting the scan checks to required checks, including which severity threshold triggers a failure.

**Plans**: 8 plans

- [x] 18-01-PLAN.md — Cut the phase branch; declare the `gate_mode` input, resolve it once in workflow-level `env`, and validate the enum in all five jobs
- [x] 18-02-PLAN.md — Condition the eleven `# D-04` scan tolerances on the resolved mode (fail-closed), repair the three SCA `if:` guards, correct the caller's comments
- [x] 18-03-PLAN.md — Author `scripts/set-required-checks.sh` (read-modify-write, dry-run default) and prove it non-destructive offline
- [x] 18-04-PLAN.md — Live report-only run: open the PR with nothing set and measure the five green checks, artifacts and analyses
- [x] 18-05-PLAN.md — Flip to blocking via `gh variable set` on the same commit, measure five red checks and upload survival, restore, and take the operator's required-checks decision
- [x] 18-06-PLAN.md — Correct the blueprint and milestone-plan branch-protection passages: five byte-exact contexts, ruleset path, severity answer, both consumption modes, D-07 ordering
- [x] 18-07-PLAN.md — Author ADR-017 with the D-06 five-not-six and D-07 corrections, and index it
- [x] 18-08-PLAN.md — Human-confirmed merge, remote verification of `origin/main`, criterion verdicts, and CICD-04/CICD-06 closure

### Phase 19: Pipeline Validation via Branch-Target PRs

**Goal**: The complete pipeline is proven end-to-end inside this repo against deliberately seeded findings, with no second repo required.
**Depends on**: Phase 18
**Requirements**: VAL-01
**Success Criteria** (what must be TRUE):

  1. A branch-target pull request carrying seeded findings for all five scan categories produces a detection from each of the five jobs.
  2. That same pull request is observed failing its checks under blocking mode and passing under report-only mode — both runs witnessed, not inferred. (Amended 2026-09-13: PR #10 was merged out of band before SC2 and SC4 were captured, so "that same pull request" became unsatisfiable; SC2's essential claim — gate-mode-isolated opposite verdicts on a byte-identical tree — was captured on a replacement PR instead, evidence recorded in 19-05-SUMMARY.md.)
  3. A seeded finding is traced from its source file through to both the Security tab entry and the retained JSON artifact.
  4. A clean pull request with no seeded findings passes all five jobs green.

**Plans**: 7 plans

Plans:

- [x] 19-01-PLAN.md — Seed and locally verify the SAST (`fixtures/vulnerable.py`) and Secrets (`fixtures/secret.env`) fixtures
- [x] 19-02-PLAN.md — Document both fixtures in `fixtures/README.md` and add rule-id verdict assertions to the smoke gate
- [x] 19-03-PLAN.md — Open the validation PR under report-only and capture SC1: a named detection from each of the five jobs
- [x] 19-04-PLAN.md — Trace the seeded `eval()` finding source → Security tab entry → retained artifact (SC3), with a human confirming the rendered alert
- [x] 19-05-PLAN.md — Flip `GATE_MODE` to blocking, prove opposite verdicts on an identical tree (SC2), and restore unconditionally (D-09)
- [x] 19-06-PLAN.md — Open a clean PR with no fixture changes and capture SC4: five `security / …` check runs concluded success
- [x] 19-07-PLAN.md — D-10 merge-vs-close decision, verify from `origin/main`, and close the phase with VAL-01 complete

### Phase 20: Template Packaging and Adoption Docs

**Goal**: Any of the other 6+ org repos can adopt the security pipeline in either consumption mode by following documentation alone.
**Depends on**: Phase 19
**Requirements**: DIST-06, DIST-07, DIST-08
**Success Criteria** (what must be TRUE):

  1. A copy-paste workflow template exists with every per-repo substitution clearly marked, and dropping it into a repo produces a working scan run. **Evidence:** PR #12 on `terraform-pipelines` (Mode A copy-paste), run `34884582425`, five `security / …` checks concluded `success` (20-10-SUMMARY.md).
  2. Another repo can call the workflow via `uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@<ref>` against a stable published ref (corrected per the D-01 amendment and RESEARCH C-1 — the org identifier this criterion originally named was never a real GitHub account, org or user lookup both 404). **Evidence:** PR #13 on `terraform-pipelines` (Mode B `uses:` reference), run `34885287142`, `referenced_workflows[0].sha` resolved to `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` — the exact commit both `v1` and `v1.0.0` point to (20-07-SUMMARY.md, 20-10-SUMMARY.md).
  3. Adoption docs walk through both consumption modes end to end, covering gate-mode selection, branch protection setup, and Dependabot wiring. **Evidence:** `docs/adoption-guide.md` sections 1-13, corrected against all three pilot runs and passing its own standing gate, `bash scripts/check-adoption-guide.sh` (15/15 PASS) (20-08-SUMMARY.md, 20-09-SUMMARY.md, 20-12-SUMMARY.md).
  4. Docs state which scan jobs apply to which repo types and how to disable the ones that do not apply. **Evidence:** `docs/adoption-guide.md`'s applicability matrix and removal recipe (section 10), and the four measured `SKIP:`/`FOUND` detect-step lines quoted verbatim from live runs on both pilots (20-03-SUMMARY.md, 20-10-SUMMARY.md, 20-11-SUMMARY.md).

**Plans**: 13 plans

Plans:

- [x] 20-01-PLAN.md — Confirm pilot repos (Q4), measure whether upload-sarif works on a private repo (A1), decide the Q2 disposition
- [x] 20-02-PLAN.md — Wave 0 gates: detector-parity + Dockerfile-pathspec harness in the host repo, adoption-guide invariant gate here; both observed red
- [x] 20-03-PLAN.md — Portability pass P-1..P-6 on the canonical `security.yml`: inline the three detectors, make the container job Dockerfile-conditional, correct the falsified comments
- [x] 20-04-PLAN.md — Apply the Q2 capability guard, add the DIST-06 adoption banners, correct the stale comments in `pr-security.yml` and `dependabot.yml`
- [x] 20-05-PLAN.md — Delete the stale third template (`cicd/.github/workflows/security.yml`, `cicd/renovate.json`), correct `cicd/README.md` and the host front-page README
- [x] 20-06-PLAN.md — Live proof PR on the canonical host: five concluding checks, per-scanner comparison against the Phase 19 baseline, operator merge + tag authorisation
- [x] 20-07-PLAN.md — Publish `v1.0.0` (annotated) and `v1` (lightweight, moving) plus the release; prove both modes' refs resolve byte-identically
- [x] 20-08-PLAN.md — `docs/adoption-guide.md` sections 1-6: audience and outcome, preflight with expected output, mode decision table, Mode A, Mode B, first run
- [x] 20-09-PLAN.md — `docs/adoption-guide.md` sections 7-13: gate mode, branch protection, Dependabot, applicability matrix and removal recipe, private repos, troubleshooting, cross-references
- [x] 20-10-PLAN.md — Public pilot: Mode A (SC1) and Mode B (SC2) live runs following the guide, plus a write-nothing branch-protection dry run
- [x] 20-11-PLAN.md — Private pilot: observe what a private consumer sees end to end and confirm the capability guard's actual effect
- [x] 20-12-PLAN.md — Correct the guide against the three pilot runs; retitle the blueprint's illustrative workflow section (Q3) and record the structure facts in CLAUDE.md
- [x] 20-13-PLAN.md — ADR-018, ADR index row, correct the dead org-path text in ROADMAP/REQUIREMENTS, mark DIST-06/07/08 complete, decide the pilot PRs' fate

## Progress

**Execution Order:**
Phases execute in numeric order: 14 → 15 → 16 → 17 → 18 → 19 → 20

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Pre-commit Framework | v1.0 | 1/1 | Complete | 2026-03-16 |
| 2. Shell and Python Hooks | v1.0 | 1/1 | Complete | 2026-03-16 |
| 3. Web and Config Hooks | v1.0 | 2/2 | Complete | 2026-03-15 |
| 4. Infrastructure Hooks | v1.0 | 1/1 | Complete | 2026-03-16 |
| 5. Secrets Detection Gate | v1.0 | 2/2 | Complete | 2026-03-16 |
| 6. SCA and Container CLI Tools | v1.0 | 1/1 | Complete | 2026-03-16 |
| 7. SAST and IaC CLI Tools | v1.0 | 1/1 | Complete | 2026-03-16 |
| 8. CLI Tool Scanning Validation | v1.0 | 2/2 | Complete | 2026-03-16 |
| 9. Full Stack Validation | v1.0 | 2/2 | Complete | 2026-03-17 |
| 10. Cross-Platform Install Script | v1.1 | 2/2 | Complete | 2026-03-18 |
| 11. File-Pattern Hook Configuration | v1.1 | 1/1 | Complete | 2026-03-22 |
| 12. Repo Setup Script | v1.1 | 1/1 | Complete | 2026-03-22 |
| 13. Maintenance and Validation | v1.1 | 8/8 | Complete | 2026-09-10 |
| 14. Workflow Foundation and Action Pinning | v2.0 | 3/3 | Complete   | 2026-09-10 |
| 15. Five Parallel Scan Jobs | v2.0 | 5/5 | Complete   | 2026-09-11 |
| 16. SCA Ecosystem Coverage | v2.0 | 7/7 | Complete    | 2026-09-11 |
| 17. SARIF Upload and Artifact Retention | v2.0 | 7/7 | Complete    | 2026-09-11 |
| 18. Configurable Gate Mode and Branch Protection | v2.0 | 8/8 | Complete   | 2026-09-12 |
| 19. Pipeline Validation via Branch-Target PRs | v2.0 | 7/7 | Complete   | 2026-09-14 |
| 20. Template Packaging and Adoption Docs | v2.0 | 13/13 | Complete | 2026-09-14 |

### Phase 20.1: Close gap: Retroactive VERIFICATION.md for Phases 14, 17, 18 (CICD-02/03/04/05/06) (INSERTED)

**Goal:** Phases 14, 17, and 18 shipped without a VERIFICATION.md (unlike 15/16/19/20) — produce one per phase via live re-query against `origin/main` and GitHub Actions/API (same rigor as Phase 19's VERIFICATION.md), independently reconfirming CICD-02 through CICD-06 are still true today, not just re-asserting SUMMARY.md narrative.
**Requirements**: CICD-02, CICD-03, CICD-04, CICD-05, CICD-06
**Depends on:** Phase 20
**Plans:** 3/3 plans complete

**Success Criteria:**
1. `14-VERIFICATION.md`, `17-VERIFICATION.md`, `18-VERIFICATION.md` each exist in their respective phase directories with a pass/fail status, following the Phase 19 VERIFICATION.md format (Observable Truths table, live evidence, spot-checks).
2. CICD-02 (SARIF upload), CICD-03 (JSON artifact retention), CICD-04 (branch protection config/guidance), CICD-05 (Dependabot SHA-pin updates), and CICD-06 (configurable gate mode) are each independently re-confirmed against live `origin/main` / GitHub state — not merely re-stated from existing SUMMARY.md/VALIDATION.md text.
3. Any drift or defect discovered during live re-query is either fixed inline (if trivial) or recorded in that phase's Gaps Summary / `deferred-items.md` — never silently dropped.

Plans:
- [x] 20.1-01-PLAN.md — Pin the evidence snapshot, prove the local clone matches live `origin/main`, author `14-VERIFICATION.md` (CICD-05)
- [x] 20.1-02-PLAN.md — Re-query SARIF categories and artifact retention, author `17-VERIFICATION.md`, resolve Phase 17 deferred items (CICD-02, CICD-03)
- [x] 20.1-03-PLAN.md — Re-query gate mode and branch-protection guidance, author `18-VERIFICATION.md`, run the cross-document consistency gate (CICD-04, CICD-06)
