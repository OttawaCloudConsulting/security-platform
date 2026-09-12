# Phase 19: Pipeline Validation via Branch-Target PRs - Research

**Researched:** 2026-09-12
**Domain:** GitHub Actions live pipeline validation — scanner fixture seeding (Semgrep CE, Gitleaks), repo-variable gate flipping, code-scanning alert tracing
**Confidence:** HIGH (every load-bearing claim measured locally against the CI-pinned tool versions, or read live from the `OttawaCloudConsulting/security-platform` API)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Fixture completion (SAST + Secrets)**
- **D-01:** Add `fixtures/vulnerable.py` seeding a Semgrep CE `p/default`-flaggable pattern using `eval()`/`os.system()` on unsanitized input — matches the Python ecosystem already present via `fixtures/requirements.txt`.
- **D-02:** Add a new fixture file (e.g. `fixtures/secret.env`) containing a fake AWS access key ID + secret matching Gitleaks' built-in `aws-access-token` rule — a named, deterministic rule rather than a generic entropy match. Not a real credential.
- **D-03:** Both new fixtures follow the existing "INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT FIX" header convention (see `fixtures/main.tf`, `fixtures/Dockerfile`, `fixtures/requirements.txt`).
- **D-04:** After validation, both new fixtures join the permanent `fixtures/` set alongside the existing IaC/Container/SCA fixtures — not reverted. `fixtures/README.md`'s structure table and Fixture Reference table are updated to include them (new rows/columns for SAST and Secrets, consuming job, measured finding count).

**Validation PR lifecycle**
- **D-05:** One long-lived branch-target validation PR carries all five seeded findings (the three existing fixtures + the two new ones from D-01/D-02) and stays open through the phase:
  1. Opened while `GATE_MODE` is `report-only` — observed producing a detection from each of the five jobs (SC1) and used as the SC3 trace source.
  2. `GATE_MODE` repo variable flipped to `blocking`; the SAME PR re-run (re-trigger, not a new PR) — observed failing its checks (SC2, first half).
  3. `GATE_MODE` flipped back to `report-only`; the SAME PR re-run again — observed passing (SC2, second half, and consistent with D-08 below).
- **D-06:** A second, separate PR with no seeded findings (clean branch, no fixture changes) proves SC4 — all five jobs green.
- **D-07:** Both PRs target `repos/security-platform`'s `main` via GitHub (real PRs, real Actions runs) — "witnessed, not inferred" per SC2 means actual run URLs/check results captured, not simulated.

**Trace target (SC3)**
- **D-08:** The single finding traced end-to-end (source file → Security tab entry → retained JSON artifact) is the newly-seeded SAST finding from `fixtures/vulnerable.py` (D-01) — exercises the new fixture and closes the gap that Phase 17 never traced a SAST finding through to the Security tab.

**End state**
- **D-09:** After the blocking-mode observation (D-05 step 2) is captured, `GATE_MODE` is reverted to `report-only` before the phase closes. This matches Phase 18 D-07's rollout sequencing: branch-protection required-checks were never set up as part of Phase 18/19, so leaving the repo in `blocking` would gate merges without the required-checks safety net that sequencing calls for. Phase 19 proves blocking works; it does not adopt it live.
- **D-10:** The validation PR itself (D-05) is closed/merged (not left open indefinitely) once all four success criteria are captured — exact merge-vs-close choice left to Claude's discretion at execution time, noted below.

### Claude's Discretion
- Whether the validation PR (D-05) is ultimately merged into `main` or closed without merging once observations are captured — either is fine since the new fixtures (D-04) must land on `main` regardless (via this PR or a follow-up), but the mechanics of GitHub PR re-triggering (re-push vs "Re-run all jobs" vs empty commit) are left to the executor.
- Exact wording/format of the `fixtures/README.md` updates for the two new fixture rows (D-04) — follow the existing table conventions in that file.
- How "witnessed, not inferred" (SC2) is captured as evidence for the phase's SUMMARY/VERIFICATION docs (e.g., pasted run URLs, `gh run view` output, screenshots) — pick whatever is most verifiable and lightweight.

### Deferred Ideas (OUT OF SCOPE)
- Branch-protection required-checks adoption (Phase 18 D-07 step 3) — explicitly deferred past this phase; Phase 19 ends with `GATE_MODE` back at `report-only` (D-09).
- Any changes to scan-job logic, SARIF categorization, or gate-mode wiring itself — all Phase 18/17/15 territory, out of scope here.
- Template packaging / other-repo rollout — Phase 20's job.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VAL-01 | Full pipeline validated in this repo using branch-target PRs (no second repo required to prove it out) | The whole document. Specifically: §Standard Stack fixes the exact fixture content that fires deterministically (F-1…F-5); §Architecture Patterns gives the measured PR/gate-flip lifecycle (P-1…P-4); §Code Examples gives the byte-exact `gh` commands that produce SC1–SC4 evidence; §Common Pitfalls names the eight ways this phase can silently produce a false pass. |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

`./CLAUDE.md` and four `.claude/rules/*.md` files are in force as project instructions. The directives that bite on Phase 19, with what they mean for the plan:

| Source | Directive | Consequence for this phase |
|---|---|---|
| `rules/…anti-slop.md` | **Never `chmod +x` a script; always invoke with an explicit interpreter** (`bash scripts/x.sh`, never `./scripts/x.sh`) | Every verification field that runs a repo script must read `bash scripts/smoke-scans.sh` / `bash scripts/check-workflow-uploads.sh`. Both are `#!/usr/bin/env bash`. |
| `rules/…anti-slop.md` | **On any failure: STOP → REPORT → WAIT.** No silent retry. | A live run that concludes unexpectedly (e.g. a job green under blocking) is a *finding*, not something to re-trigger until it looks right. Re-running destroys the signal. Plans should say this explicitly for the three D-05 runs. |
| `rules/…anti-slop.md` | **No silent fallbacks** (`or {}`, `except: pass`). Let it crash. | Evidence-parsing steps must assert and exit non-zero, never default to an empty list when an artifact or alert is missing. Mirrors `security.yml`'s own eleven intolerant verify steps. |
| `rules/…anti-slop.md` | **Second-order effects: list what depends on a thing before changing it. "Nothing else uses this" is usually wrong.** | Directly why §Common Pitfalls 5 and 6 exist — the permanent fixtures change every future PR in the repo, not just this one. |
| `rules/…session-management.md` | **Irreversible actions require a pause and explicit user confirmation**: data deletion, git history modification, architectural commitments. | Two qualify here: the repo-wide `GATE_MODE=blocking` flip (affects every PR and Dependabot run while set) and D-10's merge-vs-close of the validation PR. Phase 18-05 handled exactly these as `checkpoint:human-verify` / `checkpoint:decision` tasks and explicitly refused to resolve them autonomously. **That was a CLAUDE.md requirement, not a Phase 18 stylistic choice — the planner must carry the same checkpoints forward.** |
| `rules/…session-management.md` | A checkpoint is "I ran it, here's what happened", not "I believe this works". | "Witnessed, not inferred" (SC2) and this rule are the same requirement. Record run ids and conclusions; never a paraphrase. |
| `rules/…epistemology.md` | **Chesterton's Fence** — articulate why something exists before changing it. | Applies to `.gitleaksignore`, the four `exclude: ^fixtures/` entries, the frozen `security` job name, and `fixtures/README.md`'s "do not add a fifth exclude" sentence. The `.py` fixture is genuinely new information about that last one; the planner should *decide* it, not silently override it. |
| `rules/…epistemology.md` | **High-risk actions use the full DOING/EXPECT/IF-MISMATCH format.** | The gate flip, the pushes, and the merge all qualify. |
| `CLAUDE.md` | **`docs/adr/` records are append-only** — add new files, never modify accepted ones. | ADR-016 and ADR-017 are read-only inputs here. If this phase's measurements warrant a decision record, it is a **new** ADR, not an edit. (Nothing found suggests one is needed — this phase records evidence, not decisions.) |
| `CLAUDE.md` | Preserve the ASCII architecture diagrams, the 4-phase layered structure, and the tool coverage matrices in `development-security-stack-option-1.md` | Only relevant if a plan touches the primary document. Nothing in Phase 19's scope requires it. |
| `CLAUDE.md` | This repo is reference documentation; `repos/security-platform` is a separate, real checkout with its own remote | Two commit streams. Fixture/workflow commits → `OttawaCloudConsulting/security-platform`; PLAN/SUMMARY/RESEARCH commits → this repo. `repos/` is gitignored here (see Pitfall 7). |

**Project skills** (`.claude/skills/`): `cdk-testing`, `create-prd`, `itsg-assessment`, `nist-csf-assessment`, `nist-fedramp-assessment`, `occ-skill-creator`, `occ-skill-refactor`, `rule-creator`. None applies to this phase — there is no CDK code, no PRD to author, and no compliance assessment in scope.

---

## Summary

This phase is **measurement, not construction**. The pipeline already works — Phase 17 proved SARIF upload and artifact retention live on PR #8, Phase 18 proved the gate flip live on PR #9 with a byte-identical tree. What Phase 19 adds is two missing fixtures and one coherent end-to-end observation. The engineering risk is therefore concentrated almost entirely in **fixture determinism** (do the seeded files actually trip the scanners?) and in **evidence plumbing** (does the observation prove what the criterion asks, or something adjacent?).

Both risks were probed empirically rather than assumed, and both produced a surprise that would have broken the phase if planned from training knowledge:

1. **The canonical AWS example key does not work.** `AKIAIOSFODNN7EXAMPLE` — the key ID that appears in every AWS document ever written — produces **zero** Gitleaks findings under the exact CI-pinned version (8.30.1). Gitleaks' default config allowlists `EXAMPLE`-suffixed keys. A non-`EXAMPLE` synthetic key fires `aws-access-token` reliably.
2. **`os.system()` is not flagged by Semgrep `p/default`.** D-01 names `eval()`/`os.system()`. Measured against `semgrep==1.177.0` with the byte-exact CI invocation: `eval()` fires `eval-detected`, `exec()` fires `exec-detected`, `subprocess(..., shell=True)` fires `subprocess-shell-true` — but `os.system()` and `os.popen()` produce **nothing**. D-01 is satisfiable via its `eval()` half; its `os.system()` half is a no-op and must be documented as deliberately-silent (the same way `fixtures/main.tf` documents its silent provider pin) rather than relied on.

Beyond fixtures, the highest-value finding is that the **complete SC3 trace path is already verified working** against Phase 17's merged PR #8: `code-scanning/alerts?ref=refs/pull/<N>/merge&tool_name=Semgrep%20OSS` returns the alert with an `html_url` that *is* the Security tab entry, and `gh run download <run> -n semgrep-results` returns the retained JSON containing the identical `check_id`/`path` set. No new tooling is required. The unfiltered Security tab reads `[]` and always will — ADR-016 D-02 keeps the trigger `pull_request`-only, so `main` is never analysed. **Any plan that asks a human to "open the Security tab" without a ref filter will record a false negative**, exactly as Phase 17 Criterion 1 did.

**Primary recommendation:** Seed `fixtures/vulnerable.py` with `eval()` + `exec()` + `subprocess(shell=True)` (3 measured Semgrep findings) and `fixtures/secret.env` with a non-`EXAMPLE` `AKIA…` key (1 measured `aws-access-token` finding); drive all three gate-mode runs on one PR using Phase 18-05's `gh variable set` + `git commit --allow-empty` pattern (never `gh run rerun`); and capture every SC3 artifact through the `ref`-filtered alerts API plus `gh run download`, never through the unfiltered Security tab UI.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Seeded vulnerable content (SAST, Secrets) | Repository source tree (`fixtures/`) | — | Scanners run against the checkout; the fixture is data, not code that executes. |
| Gate-mode selection | GitHub repo settings (Actions variable `GATE_MODE`) | Workflow `env` resolution chain | Phase 18 D-03 deliberately placed the switch outside YAML so mode changes need no commit. It is a repo-settings API action. |
| Scan execution + exit-code semantics | GitHub-hosted runner (`ubuntu-latest`) | — | Five parallel jobs in `security.yml`; `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}` per scan step. |
| Finding persistence — alerts | GitHub Code Scanning service (`refs/pull/<N>/merge`) | — | `upload-sarif` keys an analysis on `tool.driver.name` + `category`. Never associated with `main` (ADR-016 D-02). |
| Finding persistence — raw reports | GitHub Actions artifact store (90-day retention) | — | Five named artifacts; `upload-artifact@v4` immutability applies. |
| PR lifecycle + re-trigger | Local git → GitHub PR (`push` of an empty commit) | `gh pr` CLI | A new run id per measurement is required; see P-2. |
| Evidence capture | `gh` CLI on the workstation | GitHub REST API | "Witnessed, not inferred" (SC2) = recorded run ids, conclusions and alert numbers, not UI impressions. |
| Pre-push secret gate | Workstation `pre-commit` (`stages: [pre-push]`) | — | Gitleaks hook fires on `git push`, not `git commit`. This is a workstation-tier obstacle to landing the secret fixture, not a CI concern. |

---

## Standard Stack

No new packages, actions, or tools are introduced by this phase. Everything below already exists in `repos/security-platform` at `origin/main` (`2e29004`).

### Core — versions the CI pins, and what is on this workstation

| Tool | CI-pinned version | Local version | Purpose in this phase | Status |
|------|-------------------|---------------|----------------------|--------|
| Semgrep CE | `semgrep==1.177.0` (`pip install`, security.yml:70) | absent → installed to scratch venv | Fires the D-01/D-08 SAST fixture | [VERIFIED: read from `security.yml` at `origin/main`; local venv measurement] |
| Gitleaks | `v8.30.1` (SHA-verified tarball, security.yml:962-966) | **8.30.1 — exact match** | Fires the D-02 secrets fixture | [VERIFIED: `gitleaks version` + workflow read] |
| Trivy | `v0.74.0` (`setup-trivy`) | **0.74.0 — exact match** | Unchanged (SCA + container) | [VERIFIED] |
| Checkov | `3.3.17` (pulled by `checkov-action` v12.3123.0) | 3.2.396 — **drift** | Unchanged (IaC) | [VERIFIED: version drift noted, impact measured as nil — see F-4] |
| tflint | `v0.64.0` (release tarball, security.yml:380) | 0.61.0 — **drift** | Unchanged (SCA sub-scan) | [VERIFIED] |
| `gh` CLI | n/a (workstation) | 2.100.0, authed as `OttawaCloudConsulting`, scopes `gist, read:org, repo, workflow` | Gate flip, PR lifecycle, all evidence capture | [VERIFIED: `gh auth status`] |
| ruff (pre-commit) | `ruff-pre-commit v0.15.7` | 0.14.8 — minor drift | Gates the new `.py` fixture on commit | [VERIFIED: `.pre-commit-config.yaml` read] |
| Docker | n/a (runner + workstation) | 28.3.2 | Unchanged (container fixture build) | [VERIFIED] |

### Actions already pinned in `security.yml` (unchanged this phase)

| Action | Pin | Role |
|--------|-----|------|
| `actions/checkout` | `3d3c42e…` v7.0.1 | `fetch-depth: 0` in the secrets job — **required**, see F-3 |
| `github/codeql-action/upload-sarif` | `b96794f…` v4.38.0 | Six categories: `semgrep`, `checkov`, `trivy-fs`, `tflint`, `trivy-image`, `gitleaks` |
| `actions/upload-artifact` | `043fb46…` v7.0.1 | Five artifacts at `retention-days: 90` |
| `bridgecrewio/checkov-action` | `a8664e3…` v12.3123.0 | `soft_fail: false`, `directory: .` |
| `aquasecurity/setup-trivy` | `81e5143…` v0.3.1 | `version: v0.74.0`, `cache: true` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `git commit --allow-empty` re-trigger | `gh run rerun <id>` | **Rejected.** 18-05 rejected it on `upload-artifact@v4` immutability grounds; a re-run reuses the run id, so re-uploading `semgrep-results` into the same run conflicts. An empty commit yields a fresh run id on a byte-identical tree, which is also the *stronger* proof that no YAML changed. |
| `git commit --allow-empty` re-trigger | `gh workflow run` (`workflow_dispatch`) | **Not available.** `pr-security.yml` is `on: pull_request: {}` only — there is no `workflow_dispatch` trigger, so `gh workflow run` cannot drive it. |
| Non-`EXAMPLE` synthetic AWS key | `AKIAIOSFODNN7EXAMPLE` | **Rejected on measurement** — produces zero findings (F-2). |
| `eval()` + `exec()` + `subprocess(shell=True)` | `os.system()` alone | **Rejected on measurement** — zero findings under `p/default` (F-1). |
| `ref`-filtered alerts API | Unfiltered Security tab UI | **Rejected on measurement** — the unfiltered alerts list returns `[]` (F-6). This is precisely how Phase 17 Criterion 1 became NOT OBSERVED. |

**Installation:** None. `pip install semgrep==1.177.0` into a throwaway venv is needed only if a plan wants to *pre-verify* the SAST fixture locally before pushing; CI installs its own.

---

## Package Legitimacy Audit

**This phase installs no external packages into `repos/security-platform`.** No `package.json`, `requirements.txt` (outside the existing intentionally-vulnerable fixture), `Cargo.toml` or action reference is added or changed. The two new files are inert fixture data.

| Package | Registry | Disposition |
|---------|----------|-------------|
| *(none added)* | — | N/A — no dependency surface change |

**Packages removed due to slopcheck `[SLOP]` verdict:** none — no packages proposed.
**Packages flagged as suspicious `[SUS]`:** none.

One optional, executor-local install exists: `semgrep==1.177.0` in a throwaway venv for pre-flight fixture verification. It is the **identical pinned spec already in `security.yml` line 70** — not a newly-chosen package — and it never enters the repository. If a plan includes it, it needs no checkpoint.

> Caveat: `fixtures/requirements.txt` pins `requests==2.19.1` and `jinja2==2.11.2`, both knowingly vulnerable. Nothing installs it (the file's own header says so, and the SCA job only *reads* it). Do not let any new plan step `pip install -r fixtures/requirements.txt`.

---

## Architecture Patterns

### System Architecture Diagram — the Phase 19 measurement loop

```
 WORKSTATION                          GITHUB                                   EVIDENCE
 ───────────                          ──────                                   ────────

 fixtures/vulnerable.py ─┐
 fixtures/secret.env ────┼─ git commit ─→ [pre-commit hooks]
 fixtures/README.md ─────┘                 ruff / ruff-format  (FIRES on .py — P-3)
                                           gitleaks            (pre-PUSH stage — P-3)
                                                │
                                         git push --no-verify
                                                ↓
                                    branch: feature/phase-19-…
                                                ↓
                                          gh pr create  ──────→  PR #N  (branch-target, same-repo)
                                                                   │
                    ┌──────────────────────────────────────────────┤
                    │                                              ↓
         gh variable set/delete GATE_MODE          on: pull_request  →  pr-security.yml
                    │                                    job `security` (FROZEN name)
                    │                                        │ uses: ./security.yml   (no `with:`)
                    │                                        ↓
                    │                     env.GATE_MODE = inputs || vars.GATE_MODE || 'report-only'
                    │                                        ↓
                    │        ┌───────────┬───────────┬──────┴────┬───────────┬───────────┐
                    │      sast         iac         sca       container    secrets
                    │    Semgrep      Checkov    Trivy fs +    Trivy img   Gitleaks
                    │   (vulnerable   (main.tf)  npm/pip/tflint (Dockerfile) (secret.env
                    │      .py)                  (package.json,              via git
                    │                            requirements)               history)
                    │        └─── each scan step: continue-on-error: ${{ GATE_MODE == 'report-only' }}
                    │                                        │
        git commit --allow-empty                             ├──→ upload-sarif (6 categories)
        git push  ── re-trigger ──┘                          │        ↓
        (NEVER gh run rerun — P-2)                           │    code-scanning analyses
                                                             │    on refs/pull/N/merge  ──→ SC1, SC3
                                                             │        ↓
                                                             │    alert html_url
                                                             │    /security/code-scanning/<id>
                                                             │
                                                             └──→ upload-artifact (5 names, 90d)
                                                                      ↓
                                                                  gh run download  ──────→ SC3
                                                             │
                                                     check-run conclusions
                                                     `security / <job name>` ×5  ──────→ SC2, SC4
```

### Pattern P-1: Gate-mode flip as a repo-settings action, measured on an identical tree

**What:** `GATE_MODE` is an Actions *variable*, not a file. Flipping it is `gh variable set` / `gh variable delete`; re-measuring it is an empty commit.
**When to use:** D-05 steps 2 and 3.
**Measured precedent (Phase 18-05, 2026-09-12):** three commits `31dbb0d` → `5973e8e` → `835c43e` all resolve to tree `ce7ec652e09d07f9cee035410bbc05d47e0a79a8`; `git diff 31dbb0d 835c43e` produces no output; conclusions were `success` → `failure` → `success`. [VERIFIED: `.planning/phases/18-…/18-05-SUMMARY.md`]

```bash
R=OttawaCloudConsulting/security-platform

# --- to blocking ---
gh variable set GATE_MODE --body blocking -R "$R"
gh variable list -R "$R"                          # read back; record the timestamp
git commit --allow-empty -m "chore(19-0X): trigger a blocking-mode run on an identical tree"
git push

# --- back to report-only (D-09): DELETE, do not set to the string ---
gh variable delete GATE_MODE -R "$R"
gh variable list -R "$R"                          # must be empty
git commit --allow-empty -m "chore(19-0X): restore report-only after the blocking measurement"
git push
```

**Why `delete` rather than `set --body report-only`:** the current live state is **no variable at all** (`gh variable list` returns empty, measured 2026-09-12), and Phase 18 D-03's fallback chain terminating at the literal `'report-only'` is what that state exercises. Deleting restores the repo byte-for-byte; setting the string leaves a variable that did not exist before and quietly stops testing the fallback. 18-05 deleted. [VERIFIED: live `gh variable list`; 18-05-SUMMARY]

**Blast radius — this is repo-wide.** `GATE_MODE=blocking` gates *every* PR and every Dependabot run in `OttawaCloudConsulting/security-platform` for as long as it is set. 18-05's mitigation, which this phase should repeat: keep the window to minutes, and afterwards query every run created inside the window to prove nothing collateral executed under blocking.

```bash
gh run list -R "$R" --limit 50 \
  --json databaseId,createdAt,headBranch,conclusion,event \
  --jq "[.[] | select(.createdAt >= \"$SET_TS\" and .createdAt <= \"$DEL_TS\")]"
```

### Pattern P-2: Re-trigger with an empty commit, never `gh run rerun`

**What:** each of D-05's three measurements needs its own run id.
**Why not `gh run rerun`:** `upload-artifact@v4` artifacts are immutable and name-unique — *"Artifact names must be unique since each created artifact is idempotent so multiple jobs cannot modify the same artifact"* [CITED: github.com/actions/upload-artifact README]. A re-run reuses the run id, so the five fixed artifact names (`semgrep-results`, `checkov-results`, `sca-results`, `trivy-image-results`, `gitleaks-results`) risk a conflict that has **nothing to do with gate mode** — a confound that would corrupt the SC2 measurement. 18-05 chose the empty commit for exactly this reason. [VERIFIED: 18-05 key-decisions; the artifact-immutability half CITED, the specific 409-on-rerun half is MEDIUM confidence and was never measured here — but the empty commit sidesteps the question entirely at zero cost.]
**Bonus:** it is also the strongest possible SC2 evidence. Identical tree hash + empty `git diff` + two opposite verdicts is what "the gate, and only the gate, changed the outcome" looks like.

### Pattern P-3: Land the fixtures through the repo's own gates without weakening them

Three workstation gates sit between the new fixtures and GitHub. All three were checked against `.pre-commit-config.yaml` at `origin/main`.

| Gate | Fires on the new fixtures? | Correct handling |
|------|---------------------------|------------------|
| `gitleaks` pre-commit hook | **Yes — on `git push`, not `git commit`.** `stages: [pre-push]`. | `git push --no-verify`. The config's own comment documents this: *"Bypass: git push --no-verify skips this hook — CI is the compensating control."* [VERIFIED: `.pre-commit-config.yaml` read] |
| `ruff` + `ruff-format` | **Yes — `types_or: [python, pyi]`, and `fixtures/` is NOT in their exclude list.** Only `terraform_fmt`, `terraform_validate`, `hadolint` and `npm-audit` carry `exclude: ^fixtures/`. | Author `vulnerable.py` already ruff-clean. **Measured:** the recommended fixture body passes `ruff check` (`All checks passed!`) and `ruff format --diff` (`1 file already formatted`). No fifth exclude is needed. |
| GitHub secret-scanning push protection | **No.** Repo `security_and_analysis` shows `secret_scanning: disabled`, `secret_scanning_push_protection: disabled`. | Nothing to do. No GH013 rejection risk. [VERIFIED: `gh api repos/OttawaCloudConsulting/security-platform`] |

**Do NOT add a fingerprint to `.gitleaksignore`.** The file currently contains only comments (no fingerprints). Gitleaks reads `.gitleaksignore` from the repo root automatically — in CI as well as locally — so a fingerprint added to silence the pre-push hook would *also* silence the CI `secrets` job and destroy the SC1 detection this phase exists to produce. [VERIFIED: `.gitleaksignore` read; CONTEXT canonical_refs makes the same point]

### Pattern P-4: Read code-scanning evidence through a `ref` filter, never the bare Security tab

Measured live against Phase 17's merged PR #8, 2026-09-12:

```bash
R=OttawaCloudConsulting/security-platform

gh api "repos/$R/code-scanning/alerts?per_page=3"                # → []      ← ALWAYS empty
gh api "repos/$R/code-scanning/alerts?ref=refs/pull/8/merge"      # → 5+ alerts with tool/path/line
gh api "repos/$R/code-scanning/alerts?ref=refs/pull/8/merge&tool_name=Semgrep%20OSS"
```

The unfiltered list is empty **by design**, not by fault: ADR-016 records D-02's tradeoff plainly — the trigger is `pull_request`-only, `main` is never analysed, so no alert is ever associated with the default branch. Phase 17 Criterion 1 closed as NOT OBSERVED for precisely this reason.

### Anti-Patterns to Avoid

- **Asking a human to "check the Security tab" unfiltered.** Guaranteed false negative. If a human observation is wanted for SC3, hand them the alert's `html_url` (which resolves to a single alert page and *does* render), not the tab root.
- **Counting analyses and expecting six.** Six categories produce **seven** analyses — `tflint.sarif` carries two `runs[]` drivers (`tflint` and `tflint-errors`). [VERIFIED: ADR-016]
- **Building any required-check list from the analyses endpoint.** `tool.name` differs in case between endpoints (`checkov`/`Checkov`, `Gitleaks`/`gitleaks`). Branch protection matches check-run names. Out of scope this phase (D-09 defers required checks) but do not let a plan drift into it.
- **Renaming the `security` job in `pr-security.yml`.** It is FROZEN — it is the prefix of all five check-run names.
- **Reverting the fixtures after measurement.** D-04 makes them permanent.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Proving a finding reached code scanning | A SARIF parser that asserts the file contains the rule | `gh api …/code-scanning/alerts?ref=refs/pull/N/merge` | The SARIF file existing proves the *scanner* worked. Only the API proves the *upload* worked — the exact failure ADR-016 was written about (a green run with an empty Security tab). |
| Proving the artifact is retained | Asserting the `upload-artifact` step is green | `gh run download <run> -n <name>` + read the JSON | The workflow already asserts step outcomes in eleven intolerant verify steps. SC3 asks for the artifact *contents*, which only a download shows. |
| A "clean" branch for SC4 | Deleting fixtures on a branch | A branch that changes something inert (e.g. a docs line) and touches no fixture | D-06 says "no fixture changes", not "no fixtures". Deleting fixtures would also destroy the finding baseline. |
| Re-triggering a PR | Force-push, rebase, or reopen/close cycles | `git commit --allow-empty && git push` | Preserves the tree hash, which is itself the SC2 evidence. |
| Choosing a fake secret | Inventing a plausible key from memory | A synthetic key **measured** against gitleaks 8.30.1 first | See F-2 — the most obvious choice silently produces nothing. |

**Key insight:** in a validation phase, every shortcut that substitutes a *nearby* observation for the *asked* observation converts a measurement into an assumption. Phase 17 already burned one criterion on exactly that (API evidence offered in place of a UI observation, correctly scored NOT OBSERVED). Plan the probe that answers the criterion literally.

---

## Common Pitfalls

### Pitfall 1: The canonical AWS example key produces zero findings
**What goes wrong:** `fixtures/secret.env` is seeded with `AKIAIOSFODNN7EXAMPLE`; the `secrets` job runs green with an empty report; SC1 fails and looks like a broken Gitleaks install.
**Why it happens:** Gitleaks' default config allowlists `EXAMPLE`-style keys to suppress documentation false positives.
**Measured, not assumed (gitleaks 8.30.1, the exact CI-pinned version):**

| Fixture content | Findings | Rules |
|---|---|---|
| `AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE` + `AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` | **0** — `no leaks found`, rc=0 | — |
| `AWS_ACCESS_KEY_ID=AKIAQYLPMN5HZR7ARWB4` (synthetic, no `EXAMPLE`) | **1**, rc=1 | `aws-access-token` |
| …plus `AWS_SECRET_ACCESS_KEY=<40-char random>` | **2**, rc=1 | `aws-access-token`, `generic-api-key` (entropy 5.22) |
| Placed at `fixtures/secret.env` rather than repo root | **unchanged** — `fixtures/` is not path-allowlisted | `aws-access-token` |

**How to avoid:** use a non-`EXAMPLE` synthetic `AKIA` + 16 uppercase-alphanumeric key ID. Verify locally with `gitleaks git .` in a throwaway repo *before* pushing.
**Warning sign:** `gitleaks … ; echo $?` returns 0.

**D-02 nuance the planner must decide:** D-02 asks for "a fake AWS access key ID + secret matching Gitleaks' built-in `aws-access-token` rule". Measurement shows only the **ID** matches `aws-access-token`; the secret value matches `generic-api-key`, which is entropy-based and therefore the exact kind of non-deterministic match D-02's rationale argues against. Two viable readings: (a) include both lines and document that the fixture produces 2 findings under 2 rules, one named and one entropy-based; (b) include only the ID line for a clean 1-finding, 1-named-rule fixture. **Recommendation: (a)** — it is the more literal reading of D-02's wording ("ID + secret"); a `.env` carrying only half a credential pair looks like a mistake to a future reader; and the secret line is not purely an entropy match after all — Semgrep independently flags it under the **named** rule `generic.secrets.security.detected-aws-secret-access-key`, so keeping it adds a deterministic detection rather than only a fragile one. Record the 2/2 split explicitly in the `fixtures/README.md` row so the entropy match is never mistaken for the deterministic one.

### Pitfall 2: `os.system()` is not a Semgrep `p/default` finding
**What goes wrong:** `vulnerable.py` is written around `os.system(...)` per a literal reading of D-01; the `sast` job reports the same 3 pre-existing findings it already reports; SC1's SAST detection is indistinguishable from the baseline and D-08's trace target does not exist.
**Why it happens:** `p/default` is a curated registry ruleset, not "all Python security rules". `dangerous-system-call`-style rules live in other packs.
**Measured, not assumed** (`semgrep==1.177.0` venv, byte-exact CI invocation `semgrep scan --config p/default --metrics=off --error --json-output=… --sarif-output=… .`):

| Construct in `fixtures/vulnerable.py` | Fires? | Rule ID | Severity |
|---|---|---|---|
| `eval(user_input)` | **Yes** | `python.lang.security.audit.eval-detected.eval-detected` | WARNING |
| `exec(user_input)` | **Yes** | `python.lang.security.audit.exec-detected.exec-detected` | WARNING |
| `subprocess.run("ls " + x, shell=True)` | **Yes** | `python.lang.security.audit.subprocess-shell-true.subprocess-shell-true` | ERROR |
| `os.system("echo " + x)` | **No** | — | — |
| `os.popen("cat " + x)` | **No** | — | — |

**How to avoid:** build the fixture on `eval()` (D-01's satisfiable half). Keep an `os.system()` line if D-01 fidelity matters, but annotate it as deliberately silent — `fixtures/main.tf` already establishes that convention for its provider pin (*"An exact `3.74.0` pin is correctly SILENT under tflint"*).
**Warning sign:** the `sast` job's finding count is 3, not 8.

### Pitfall 3: Confusing the SAST baseline with the seeded finding
**What goes wrong:** SC1 is recorded as "the SAST job produced a detection" using findings that were already there before the fixture existed.
**Measured baseline** — `origin/main` (`2e29004`) with **no** `.py` fixture, semgrep `p/default`, rc=1, **3 findings**:

| Rule | Path |
|---|---|
| `package_managers.dependabot.dependabot-missing-cooldown…` | `.github/dependabot.yml` |
| `yaml.github-actions.security.gha-curl-pipe-shell…` | `cicd/.github/workflows/security.yml` |
| `dockerfile.security.missing-user.missing-user` | `fixtures/Dockerfile` |

These three are confirmed **live** — the same three appear as Semgrep OSS alerts on `refs/pull/8/merge` (alerts 86, 87, 88) and in the retained `semgrep-results.json` from run `34638828775`. The local measurement and production agree exactly.

**With BOTH new fixtures present the count goes 3 → 8**, measured in one run with `vulnerable.py` and `secret.env` together — not 3 → 6. `secret.env` fires Semgrep as well as Gitleaks:

| Path | Rule | Source |
|---|---|---|
| `fixtures/vulnerable.py` | `python.lang.security.audit.eval-detected.eval-detected` | D-01 |
| `fixtures/vulnerable.py` | `python.lang.security.audit.exec-detected.exec-detected` | D-01 |
| `fixtures/vulnerable.py` | `python.lang.security.audit.subprocess-shell-true.subprocess-shell-true` | D-01 |
| `fixtures/secret.env` | `generic.secrets.security.detected-aws-access-key-id-value…` | D-02 side effect |
| `fixtures/secret.env` | `generic.secrets.security.detected-aws-secret-access-key…` | D-02 side effect |

This is a **benefit, not a problem** — it gives the secret fixture a second, independent named-rule detection under a different tool — but it means `fixtures/README.md`'s Fixture Reference table needs a `secret.env` → SAST (Semgrep) row alongside its Secrets (Gitleaks) row, exactly as `main.tf` already carries both a Checkov row and a tflint row.
**How to avoid:** every SC1/SC3 assertion must be scoped to `path == "fixtures/vulnerable.py"`, never to "the semgrep job found something" and never to a bare total.

### Pitfall 4: The unfiltered Security tab reads empty
**What goes wrong:** SC3's "Security tab entry" is checked in the UI, nothing is there, and the criterion is scored as failed or — worse — the phase "fixes" it by adding `push: branches: [main]`, silently reversing ADR-016's locked D-02.
**Measured:** `gh api repos/…/code-scanning/alerts?per_page=3` → `[]`. With `?ref=refs/pull/8/merge` → alerts returned.
**How to avoid:** use the ref filter. The alert's own `html_url` (`https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/<id>`) is a real, renderable Security-tab page and is the right artifact to paste as SC3 evidence.
**Do not** add a `push` trigger. It is ADR-016 D-02, locked, and the CONTEXT defers trigger changes.

### Pitfall 5: SC4 "green" is only achievable under report-only — and the fixtures make that permanent
**What goes wrong:** the clean PR (D-06) is run while `GATE_MODE=blocking` is still set, or someone expects "clean PR" to mean "zero findings".
**Why it happens:** `fixtures/` is permanent (D-04) and lives on `main`. Every PR checks out a tree containing `main.tf`, `Dockerfile`, `package.json`, `requirements.txt` and — after this phase — `vulnerable.py` and `secret.env`. **Every PR in this repository produces findings in all five jobs, forever.** A job is green only because report-only sets `continue-on-error: true` on its scan step.
**How to avoid:** sequence D-06's clean PR strictly outside the blocking window, and phrase SC4's evidence as *"five `security / …` check runs concluded `success`"* — never as *"zero findings"*.
**Second-order effect the plan should surface rather than solve:** this is why `repos/security-platform` cannot itself adopt blocking mode live (Phase 18 D-07 step 3) without first excluding `fixtures/` from the scanners. Phase 19's D-09 revert is therefore not merely cautious sequencing — it is currently the only state in which this repo's own PRs can merge green. Worth a line in the phase SUMMARY as an input to Phase 20.

### Pitfall 6: The secret fixture is permanent in git history
**What goes wrong:** nobody expects the secrets job to keep reporting the fixture after the validation PR closes.
**Why it happens:** the secrets job checks out with `fetch-depth: 0` and runs `gitleaks git .` — a **history** scan, not a working-tree scan. The workflow comments say so explicitly: *"REQUIRED: `gitleaks git` finds findings in history; the working-tree-only dir subcommand of gitleaks finds zero."* Once `secret.env` is on `main`, it is in the history of every future branch.
**How to avoid:** nothing to avoid — this is intended by D-04. Document it in `fixtures/README.md` so a future reader does not "clean up" the history. Note also that this means the secrets job would fire on the D-06 clean PR too (see Pitfall 5) **if** the fixture has already merged; if the clean PR is cut from a `main` that predates the merge, it will not. Either is fine for SC4 under report-only — but the plan should state which it is, because the two give different `gitleaks-results.json` contents.

### Pitfall 7: The local `repos/security-platform` checkout is stale and gitignored
**What goes wrong:** an executor edits fixtures on top of the Phase 17 branch and produces a PR carrying unrelated diffs, or an agent in a fresh worktree finds no `repos/` directory at all.
**Measured:** local HEAD is `feature/phase-17-sarif-upload-and-artifact-retention` (`fbe0071`); `origin/main` is `2e29004` (the Phase 18 merge). `repos/` is gitignored in the outer docs repo — 18-05 found it *absent* in its worktree and cloned fresh.
**How to avoid:** every plan touching the inner repo needs a preflight: clone-or-fetch, `git checkout -B feature/phase-19-… origin/main`, and assert `git rev-parse origin/main`. And every plan must keep **two commit streams straight** — fixture/workflow commits go to `OttawaCloudConsulting/security-platform`; PLAN/SUMMARY commits go to the outer docs repo.

### Pitfall 8: `p/default` rule content is fetched from the registry at scan time
**What goes wrong:** the fixture's measured finding count drifts without any version change.
**Why it happens:** `--config p/default` resolves against `semgrep.dev` on every run. The *tool* is pinned (`semgrep==1.177.0`); the *rules* are not.
**How to avoid:** treat the three-finding count as a measurement with a date, exactly as `fixtures/README.md` already does for the other fixtures (*"Counts will drift upward over time… that is expected and does not indicate a broken fixture"*). Assert on the presence of `eval-detected` at `fixtures/vulnerable.py`, never on an exact total. Same logic applies to Gitleaks' bundled default config.

---

## Code Examples

### The recommended `fixtures/vulnerable.py`

Measured: **3 Semgrep findings** attributable to this file; passes `ruff check` and `ruff format --diff` clean; adds **0** Checkov findings.

```python
# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX" OR RUN
# Seeds the SAST job (Semgrep CE, --config p/default). Nothing in this repository
# ever imports or executes this file; it exists solely as scanner input.
#
# Measured 2026-09-12 against semgrep==1.177.0 with the exact CI invocation — three
# findings, all on this file:
#   python.lang.security.audit.eval-detected.eval-detected                (WARNING)
#   python.lang.security.audit.exec-detected.exec-detected                (WARNING)
#   python.lang.security.audit.subprocess-shell-true.subprocess-shell-true (ERROR)
#
# NOTE, and do not "fix" it: os.system() and os.popen() below are DELIBERATELY
# SILENT under p/default — measured, zero findings. They are kept for shape, not
# for signal. The same convention as fixtures/main.tf's exact provider pin.
import os
import subprocess
import sys


def run_expression(user_input):
    return eval(user_input)


def run_exec(user_input):
    exec(user_input)


def run_shell(user_input):
    os.system("echo " + user_input)


def run_subprocess(user_input):
    subprocess.run("ls " + user_input, shell=True, check=False)


def run_popen(user_input):
    return os.popen("cat " + user_input).read()


if __name__ == "__main__":
    run_expression(sys.argv[1])
```

### The recommended `fixtures/secret.env`

Measured: **Gitleaks `aws-access-token` fires** (plus `generic-api-key` on the secret line), **and Semgrep independently fires two named `generic.secrets.security.*` rules on the same two lines**; adds **0** Checkov findings.

```bash
# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"
# Seeds the Secrets job (Gitleaks). These credentials are SYNTHETIC and have never
# existed in any AWS account. Nothing reads this file.
#
# Measured 2026-09-12 against gitleaks 8.30.1 (the CI-pinned version):
#   AWS_ACCESS_KEY_ID     -> aws-access-token   (named rule, deterministic)
#   AWS_SECRET_ACCESS_KEY -> generic-api-key    (entropy 5.22, NOT version-stable)
# This file ALSO lands in the SAST job — semgrep p/default 1.177.0 flags both
# lines under generic.secrets.security.detected-aws-access-key-id-value and
# .detected-aws-secret-access-key. Two tools, four findings, one fixture.
#
# DO NOT substitute AWS's canonical AKIAIOSFODNN7EXAMPLE key: gitleaks allowlists
# EXAMPLE-suffixed keys and it produces ZERO findings — measured, not assumed.
# DO NOT add this file's fingerprint to .gitleaksignore: CI reads that file too and
# the suppression would silence the detection this fixture exists to produce.
AWS_ACCESS_KEY_ID=AKIAQYLPMN5HZR7ARWB4
AWS_SECRET_ACCESS_KEY=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
```

> The planner may substitute a different synthetic key — but it must be **re-measured**, not swapped in on the assumption that any `AKIA…` string works.

### Pre-flight: verify both fixtures locally before opening the PR

```bash
# Semgrep — needs a throwaway venv; the workstation has no semgrep
python3 -m venv /tmp/sgvenv && /tmp/sgvenv/bin/pip install -q semgrep==1.177.0
cd repos/security-platform
/tmp/sgvenv/bin/semgrep scan --config p/default --metrics=off --error \
  --json-output=/tmp/sg.json --sarif-output=/tmp/sg.sarif .   # rc=1 expected
python3 -c "import json;r=json.load(open('/tmp/sg.json'))['results'];\
print([x['check_id'] for x in r if 'vulnerable.py' in x['path']])"

# Gitleaks — the workstation already has the exact CI version
gitleaks git . --no-banner --redact --report-format json --report-path /tmp/gl.json  # rc=1 expected
python3 -c "import json;print([(x['RuleID'],x['File']) for x in json.load(open('/tmp/gl.json'))])"

# ruff — must be clean, or the pre-commit hooks rewrite the fixture
ruff check fixtures/vulnerable.py && ruff format --diff fixtures/vulnerable.py
```

### SC1 — a detection from each of the five jobs

```bash
R=OttawaCloudConsulting/security-platform
PR=<N>; RUN=<run-id>

# (a) all five jobs ran and their gate mode is on the record
gh run view "$RUN" -R "$R" --json jobs \
  --jq '[.jobs[] | {name, conclusion}]'
gh run view "$RUN" -R "$R" --log | grep -c 'gate_mode=report-only'    # expect 5

# (b) one detection per category, read from the artifacts (all five, incl. npm/pip)
for a in semgrep-results checkov-results sca-results trivy-image-results gitleaks-results; do
  rm -rf "/tmp/19-$a"; gh run download "$RUN" -R "$R" -n "$a" -D "/tmp/19-$a"; ls -l "/tmp/19-$a";
done

# (c) the two NEW fixtures specifically
python3 -c "import json;r=json.load(open('/tmp/19-semgrep-results/semgrep-results.json'))['results'];\
assert any('fixtures/vulnerable.py' in x['path'] for x in r), 'SAST fixture did not fire'; print('SAST ok')"
python3 -c "import json;d=json.load(open('/tmp/19-gitleaks-results/gitleaks-results.json'));\
assert any(x['RuleID']=='aws-access-token' and 'secret.env' in x['File'] for x in d), 'secret fixture did not fire'; print('secrets ok')"
```

### SC2 — same PR, opposite verdicts, identical tree

```bash
# after each of the three runs
gh api "repos/$R/commits/$(git rev-parse HEAD)/check-runs" \
  --jq '[.check_runs[] | select(.name | startswith("security / ")) | {name, conclusion}]'

# the tree-identity proof (18-05's pattern)
git rev-parse "$REPORT_ONLY_SHA^{tree}" "$BLOCKING_SHA^{tree}" "$RESTORE_SHA^{tree}"   # all equal
git diff "$REPORT_ONLY_SHA" "$RESTORE_SHA"                                              # no output
```

### SC3 — one finding, three hops (this exact path is already proven working on PR #8)

```bash
R=OttawaCloudConsulting/security-platform; PR=<N>

# hop 1 — source file
grep -n 'eval(' repos/security-platform/fixtures/vulnerable.py

# hop 2 — Security tab entry (ref-filtered; tool name is "Semgrep OSS", space encoded)
gh api "repos/$R/code-scanning/alerts?ref=refs/pull/$PR/merge&tool_name=Semgrep%20OSS" \
  --jq '.[] | select(.most_recent_instance.location.path=="fixtures/vulnerable.py")
        | {number, rule:.rule.id, line:.most_recent_instance.location.start_line, html_url}'
# html_url → https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/<id>

# hop 3 — retained JSON artifact
gh run download "$RUN" -R "$R" -n semgrep-results -D /tmp/19-trace && ls -l /tmp/19-trace
python3 -c "import json;r=json.load(open('/tmp/19-trace/semgrep-results.json'))['results'];\
print([(x['check_id'],x['path'],x['start']['line']) for x in r if 'vulnerable.py' in x['path']])"
```

**Verification that this path works** — run against Phase 17's PR #8, 2026-09-12:
- `alerts?ref=refs/pull/8/merge&tool_name=Semgrep%20OSS` returned 3 alerts (86, 87, 88) with `html_url`s.
- `gh run download 34638828775 -n semgrep-results` returned `semgrep-results.json` (38 KB) + `semgrep.sarif` (2.1 MB).
- The artifact's three `check_id`/`path` pairs match the three alerts exactly.

### SC4 — clean PR, five green

```bash
gh api "repos/$R/commits/<clean-head-sha>/check-runs" \
  --jq '[.check_runs[] | select(.name|startswith("security / ")) | {name, conclusion}]'
# expect five entries, every conclusion "success" — under report-only (see Pitfall 5)
gh variable list -R "$R"     # must be EMPTY at the time this run executes
```

---

## Repo-Local Scripts: do they need updating?

Both were read in full at `origin/main`. **Neither requires a change for the two new fixtures**, and the plan should say so explicitly rather than leaving it open.

| Script | Why it is unaffected |
|---|---|
| `scripts/smoke-scans.sh` | Its SAST and Secrets sections run `semgrep scan … .` and `gitleaks git . …` at the **repo root** with no per-fixture paths, so the new files are picked up automatically. Both sections use `run_scan` (rc=1 == PASS), and both already pass on the current tree (semgrep baseline 3, gitleaks non-empty on existing history) — adding fixtures only increases the counts (semgrep 3 → 8, measured). Note its hard-tier preflight `exit 1`s if `semgrep` is not on `PATH`, so this script cannot run on the current workstation without the venv on `PATH` first. The "Criterion 4 clean-skip negative test" section exercises `detect-{npm,python,terraform}.sh` inside a throwaway repo and is untouched by fixture content. |
| `scripts/check-workflow-uploads.sh` | A **static YAML gate**, not a scanner (a `#!/usr/bin/env bash` wrapper around a `python3 - <<'PY'` heredoc; run it as `bash scripts/check-workflow-uploads.sh`). Its own scope note states it *"deliberately asserts NO counts"*; it checks SARIF category presence/uniqueness, artifact-name uniqueness, `--redact` on gitleaks invocations, and retention. Fixture files are invisible to it. |

**Optional improvement, not required:** `smoke-scans.sh`'s semgrep block prints a finding count but does not assert *which* files produced it. A one-line assertion that `fixtures/vulnerable.py` appears would make the local gate catch a registry drift (Pitfall 8) before CI does. Flagged as a discretionary addition — it changes a Phase 15/16 artifact, so the planner should weigh it against the CONTEXT's "no scan-job logic changes" boundary. It is a *script* change, not a *workflow* change, so it is arguably in scope; treat as a planner decision.

---

## State of the Art

| Old (pre-Phase 18) | Current | When changed | Impact on this phase |
|---|---|---|---|
| Gate behaviour hard-coded in YAML | `env.GATE_MODE: ${{ inputs.gate_mode \|\| vars.GATE_MODE \|\| 'report-only' }}` | Phase 18 (`ebf228c`) | D-05's flips are `gh variable` calls, zero commits of YAML |
| Reports discarded at job end | 6 categorised SARIF uploads + 5 artifacts @ 90 days | Phase 17 (`8fbea7d`) | SC3's two destinations already exist and are proven |
| `upload-artifact` reused names | v4 immutability, name-unique per run | actions/upload-artifact v4 | Forces the empty-commit re-trigger (P-2) |
| `trivy convert` for the fs scan | Direct `trivy fs --format sarif` | Phase 17-02 | Unrelated to this phase, but explains why `sca` runs trivy twice |

**Current live state of `OttawaCloudConsulting/security-platform`, measured 2026-09-12:**

| Property | Value |
|---|---|
| `origin/main` | `2e29004` (Phase 18 merge, PR #9) |
| Visibility | **public** (code scanning free; `security_events` scope not required to read alerts) |
| `gh variable list` | **empty** — `GATE_MODE` unset, so the chain resolves to `'report-only'` |
| `rules/branches/main` | `deletion`, `non_fast_forward` — **no required checks, no required review**; PRs merge freely |
| `secret_scanning` / push protection | **disabled** — no GH013 risk when pushing the secret fixture |
| Dependabot security updates | disabled |
| Last PR | #9 MERGED; #1–#9 all closed. The next PR number is **≥ 10** — PRs and issues share one counter, so do not hard-code it; read it back with `gh pr view --json number`. |
| Unfiltered code-scanning alerts | `[]` |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | `gh run rerun` would 409 on the five fixed artifact names. Artifact immutability is CITED from the upstream README; the *409-on-rerun* specific is 18-05's stated rationale and was never measured. | P-2 / Alternatives | None material — the empty-commit path avoids the question at zero cost and carries independent benefits. |
| A2 | Checkov in CI (3.3.17, via the action) produces the same 14 findings as locally measured with 3.2.396, i.e. the new fixtures add zero IaC findings. | F-4 / Pitfall 2 | Low. If CI's newer Checkov adds a `CKV_SECRET_*` on `secret.env`, the IaC count rises — harmless for every criterion, but `fixtures/README.md`'s measured row would need the real CI number. Re-read `checkov-results.json` from the run rather than trusting the local figure. |
| A3 | tflint 0.64.0 (CI) behaves as 0.61.0 (local) on the unchanged Terraform fixture. | Standard Stack | Negligible — no Terraform fixture changes this phase. |
| A4 | Repository variables are not passed to fork-PR workflows. Sourced from a GitHub staff answer in an official community discussion, **not** from a docs page. | Open Question Q1 | Low for this phase (D-07 makes both PRs same-repo). Material for Phase 20's consumer template. |
| A5 | The local venv's semgrep self-reports `1.155.0` while pip metadata says `1.177.0`. The discrepancy is unexplained. | Standard Stack | Low — the local 3-finding baseline matches the live production alerts on PR #8 exactly, which independently validates the measurement regardless of which version string is authoritative. |
| A6 | The synthetic key `AKIAQYLPMN5HZR7ARWB4` and the 40-char secret in the Code Examples are not real and collide with no live AWS credential. | Code Examples | Low, but non-zero. Generated as random uppercase-alphanumeric; the planner may regenerate. Never reuse a string found in a public blog post — those are the ones vendors allowlist or, worse, that are real. |

---

## Open Questions

1. **Q1 — Can a fork PR read `vars.GATE_MODE`?** *(This is the question `pr-security.yml` explicitly hands to Phase 19.)*
   - What we know: GitHub staff stated *"Variables are not passed to workflows that are triggered by a pull request from a fork"* and marked the area as still under exploration. [CITED: github.com/orgs/community/discussions/44322] Consequence: on a fork PR, `vars.GATE_MODE` is `""`, the `||` chain falls through to `'report-only'`, and the gate **silently fails open**. Separately, a fork PR's `GITHUB_TOKEN` is read-only, which is why every `Verify … upload landed` step in `security.yml` is already guarded on `github.event.pull_request.head.repo.full_name == github.repository`.
   - What's unclear: whether this is still accurate (no docs page states it; the discussion is unresolved since Jan 2023), and whether it is observable without creating a fork.
   - Recommendation: **record the answer and the citation in the phase SUMMARY, and explicitly do not test it.** D-07 scopes both PRs to the same repo. Hand the consumer-template consequence to Phase 20: a consumer repo that genuinely needs blocking on fork PRs must use a literal `with: gate_mode: blocking` (which `pr-security.yml`'s comment already anticipates), not the `vars` path. Removing the stale "UNVERIFIED / handed to Phase 19" comment from `pr-security.yml` is a one-line doc fix the planner may or may not want to include — it is a workflow-file edit, which the CONTEXT's boundary discourages.

2. **Q2 — Does SC3's "Security tab entry" require a human UI observation, or does the alert's `html_url` suffice?**
   - What we know: Phase 17 scored its equivalent criterion NOT OBSERVED specifically because API evidence was offered where a UI observation was asked for, and 17-07 established the pattern *"a criterion whose only evidence path is a UI observation gets a NOT OBSERVED verdict with a named cause, not a MET inferred from the API"*. SC3's wording is "traced from its source file through to both the Security tab entry and the retained JSON artifact" — "entry", singular, which the `html_url` resolves to directly.
   - What's unclear: whether the phase owner reads "Security tab entry" as "the alert exists server-side" (API-satisfiable) or "a human saw it rendered" (UI-only).
   - Recommendation: **do both, cheaply.** Capture the API evidence (alert number, rule, path, line, `html_url`) *and* put the `html_url` in front of a human as a `checkpoint:human-verify` asking only "does this page render an alert for `fixtures/vulnerable.py`?". That is a single-click question against a URL known to work, unlike Phase 17's open-ended "check the Security tab", and it forecloses the NOT-OBSERVED outcome for the cost of one checkpoint.

3. **Q3 — Should the D-06 clean PR be cut before or after the fixtures merge to `main`?**
   - What we know: either satisfies SC4 under report-only. Before → `gitleaks-results.json` contains only the pre-existing history findings; after → it also contains `secret.env`. Neither changes the check-run conclusions.
   - What's unclear: nothing technical; it is a sequencing choice interacting with D-10 (merge vs close the validation PR).
   - Recommendation: cut the clean PR **after** the validation PR merges, from an up-to-date `main`. It then demonstrates the steady-state every future PR in this repo will experience, which is the more useful thing to have on record — and it makes D-10's "merge" branch the natural choice.

---

## Runtime State Inventory

Not applicable — this is not a rename, refactor, or migration phase. One item is worth naming anyway because it is genuinely runtime state that no grep would find:

| Category | Item | Action |
|---|---|---|
| Live service config | `vars.GATE_MODE` on `OttawaCloudConsulting/security-platform` — a GitHub repo setting, not a file. Currently **unset**. | Set → measure → **delete** (not "set to report-only"). D-09. Verify absence with `gh variable list` before the phase closes. |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| `gh` CLI, authenticated | every criterion | ✓ | 2.100.0, `OttawaCloudConsulting`, scopes `gist, read:org, repo, workflow` | — |
| Network to github.com | every criterion | ✓ | — | — |
| gitleaks | local pre-verification of the D-02 fixture | ✓ | **8.30.1 — exact CI match** | — |
| ruff | pre-commit compliance of the D-01 fixture | ✓ | 0.14.8 (pre-commit pins 0.15.7) | pre-commit installs its own pinned copy |
| python3 | evidence parsing | ✓ | 3.12.0 | — |
| semgrep | local pre-verification of the D-01 fixture | ✗ | — | **Verified working:** `python3 -m venv … && pip install semgrep==1.177.0`. Or skip local verification and read `semgrep-results.json` from the CI run — this research already measured the fixture, so a plan may reasonably rely on that measurement rather than repeating it. |
| trivy / checkov / tflint / docker | not needed (no fixture changes in those categories) | ✓ | 0.74.0 / 3.2.396 / 0.61.0 / 28.3.2 | — |
| `repos/security-platform` checkout | all fixture and PR work | ⚠ **stale** | on `feature/phase-17…` (`fbe0071`); `origin/main` is `2e29004`; gitignored by the outer repo and may be **absent** in an agent worktree | Clone or fetch in a preflight step, then branch from `origin/main`. 18-05's precedent. |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** semgrep (venv); the stale/absent inner checkout (preflight clone).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **No unit-test framework.** This is a documentation repo; the inner repo's validation is `bash scripts/smoke-scans.sh` (a local pass/fail scanner gate), `python3 scripts/check-workflow-uploads.sh` (a static YAML invariant gate), and live `gh` API assertions. |
| Config file | none — both gates are self-contained scripts |
| Quick run command | `cd repos/security-platform && bash scripts/check-workflow-uploads.sh` (offline, seconds; needs `pyyaml` — it preflights for it and fails with an install hint) |
| Full suite command | `cd repos/security-platform && bash scripts/smoke-scans.sh` (runs every scanner locally; minutes). **It HARD-FAILS on this workstation:** its hard-tier preflight loops `semgrep checkov trivy gitleaks docker python3 npm` and `exit 1`s on the first missing binary — semgrep is missing, so the gate never starts. Verified by reading lines 202-208. Only `pip-audit` and `tflint` are soft-tier (SKIPPED, and a skip is never a pass). To run it, put the venv's semgrep on `PATH` first. |

### Phase Requirements → Test Map

| Req | Behavior | Test type | Automated command | Exists? |
|---|---|---|---|---|
| VAL-01 / SC1 | Five jobs each produce a detection | live API | `gh run view "$RUN" --json jobs` + `gh run download` ×5 + the two new-fixture assertions in §Code Examples | ✅ pattern proven on run 34638828775 |
| VAL-01 / SC1 (new SAST fixture) | `fixtures/vulnerable.py` fires Semgrep | local pre-flight | `/tmp/sgvenv/bin/semgrep scan --config p/default --metrics=off --error --json-output=… .` → assert `fixtures/vulnerable.py` in results | ✅ measured: 3 findings |
| VAL-01 / SC1 (new secrets fixture) | `fixtures/secret.env` fires `aws-access-token` | local pre-flight | `gitleaks git . --no-banner --redact --report-format json --report-path …` → assert `RuleID=="aws-access-token"` | ✅ measured: fires |
| VAL-01 / SC2 | Same PR fails under blocking, passes under report-only | live API ×3 | `gh api repos/…/commits/$SHA/check-runs --jq '[.check_runs[]\|select(.name\|startswith("security / "))\|{name,conclusion}]'` + tree-hash identity | ✅ proven on PR #9 |
| VAL-01 / SC3 | One finding → Security tab entry → retained artifact | live API | the three-hop block in §Code Examples | ✅ proven end-to-end on PR #8 |
| VAL-01 / SC3 | Human sees the rendered alert page | `checkpoint:human-verify` | manual — hand over the alert `html_url` | ❌ checkpoint task needed (see Q2) |
| VAL-01 / SC4 | Clean PR: five green | live API | same check-runs query + `gh variable list` must be empty | ✅ |
| D-03/D-04 | Fixtures carry the header convention; README tables updated | static | `head -1 fixtures/vulnerable.py fixtures/secret.env \| grep -c 'INTENTIONALLY VULNERABLE'` and a row-count check on the Fixture Reference table | ✅ trivial |
| D-04 regression | New fixtures break no existing gate | static + local | `bash scripts/check-workflow-uploads.sh` (must stay green) and `ruff check fixtures/vulnerable.py && ruff format --diff fixtures/vulnerable.py` | ✅ measured green |
| D-09 | Repo restored | live API | `gh variable list -R … ` must print nothing | ✅ |

### Sampling Rate

- **Per task commit (inner repo):** `ruff check fixtures/ && ruff format --diff fixtures/` and `bash scripts/check-workflow-uploads.sh` — both offline and fast. Invoke with an explicit interpreter; never `chmod +x` (project rule).
- **Per live run:** capture run id, the five `security / …` conclusions, and the `gate_mode=` log line count (must be 5) *immediately*, before triggering the next run. Each measurement is destroyed by the next one.
- **Phase gate:** all four criteria evidenced with recorded run ids + alert numbers, and `gh variable list` empty.

### Wave 0 Gaps

- [ ] `checkpoint:human-verify` task for SC3's rendered alert page (Q2) — no automated substitute exists, and Phase 17 proved that inferring it from the API produces a NOT OBSERVED.
- [ ] A preflight task that clones/fetches `repos/security-platform` and asserts `origin/main == 2e29004` (or later) before any fixture edit — the local checkout is stale and may be absent (Pitfall 7).
- [ ] No framework install is needed. Do **not** add one.

---

## Security Domain

`security_enforcement` is not disabled in `.planning/config.json`, so this section applies. Note the inversion peculiar to this phase: the deliverables are *deliberately insecure artifacts*, and the security question is about blast radius, not about hardening the fixtures.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | No auth surface introduced |
| V3 Session Management | no | — |
| V4 Access Control | **yes** | Least privilege is already enforced: `pr-security.yml` grants `security-events: write` at the **job** level only; the workflow floor stays `contents: read`. This phase adds no permission. `GATE_MODE` flipping requires repo-admin, which the `repo` token scope covers. |
| V5 Input Validation | **yes** | `security.yml`'s `Validate gate_mode` step allowlists the enum and `exit 1`s on anything else, in every one of the five jobs — a fail-closed gate that this phase must not weaken. The only `${{ }}` interpolations inside `run:` blocks are `github.sha` and server-generated step outputs; the new fixtures introduce no new interpolation. |
| V6 Cryptography | **yes (inverted)** | The secret fixture must be **synthetic**. Never commit a real, revoked, or "probably expired" credential — a revoked key is still an identifier that leaks account structure. Generate randomly; never copy from a blog or a vendor doc. |
| V7 Error Handling / Logging | **yes** | `gitleaks … --redact` is mandatory and already asserted by `check-workflow-uploads.sh` (*"invokes gitleaks without `--redact` — its report becomes a world-downloadable artifact"*). The repo is **public**; `gitleaks-results.json` is world-downloadable for 90 days. Do not remove `--redact` to make the fixture easier to trace — trace via `RuleID` + `File` + `StartLine`, which are unredacted. |
| V14 Configuration | **yes** | All actions SHA-pinned (ADR-004); tarball installs checksum-verified. Unchanged this phase. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation | Status in this phase |
|---|---|---|---|
| Committed credential becomes a real leak | Information Disclosure | Synthetic values only; `--redact` on every gitleaks invocation | Enforced — synthetic key measured, `--redact` already asserted by the static gate |
| Suppression file silently disables the control it was meant to scope | Tampering | Never add a fixture fingerprint to `.gitleaksignore`; CI reads it too | Called out in P-3 and in the fixture header |
| Repo-wide gate flip catches unrelated PRs | Denial of Service | Short window + post-hoc collateral-run query | 18-05 pattern documented in P-1 |
| Vulnerable fixture code is imported or executed | Tampering / RCE | Header convention, no imports anywhere, `if __name__` guard only | D-03 convention + explicit "never runs" comment |
| Fixture permanence blocks the repo's own blocking-mode adoption | (operational) | Documented, not solved | Pitfall 5, second-order effect |
| Fork PR silently runs report-only when blocking is intended | Elevation of Privilege (gate bypass) | Literal `with: gate_mode:` in consumer templates | Q1 — answered, deferred to Phase 20 |

---

## Sources

### Primary — HIGH confidence (measured or read live in this session, 2026-09-12)

- `repos/security-platform` @ `origin/main` `2e29004`: `scripts/check-workflow-uploads.sh` (bash wrapper + python heredoc, pyyaml preflight), `scripts/smoke-scans.sh` hard-tier binary preflight (lines 202-208, `exit 1` on a missing scanner), `.github/workflows/security.yml` (1070 lines), `.github/workflows/pr-security.yml`, `.pre-commit-config.yaml`, `.gitleaksignore`, `.gitignore`, `fixtures/*`, `scripts/smoke-scans.sh`, `scripts/check-workflow-uploads.sh`
- Local measurement, gitleaks **8.30.1** (exact CI pin): `EXAMPLE` key → 0 findings; synthetic `AKIA` key → `aws-access-token`; `+` secret line → `generic-api-key`; `fixtures/` path not allowlisted
- Local measurement, **semgrep 1.177.0** venv, byte-exact CI invocation: baseline 3 findings; with **both** new fixtures present → 8 (`eval`/`exec`/`subprocess-shell-true` on `vulnerable.py`, plus two `generic.secrets.security.*` rules on `secret.env`); `os.system`/`os.popen` produce nothing
- Local measurement, **checkov 3.2.396**: 14 failed checks (12 terraform + 2 dockerfile) with both new fixtures present — identical to ADR-016's recorded 14; secrets framework → 0
- Local measurement, **ruff 0.14.8**: recommended `vulnerable.py` passes `check` and `format --diff`
- Live API: `gh api repos/OttawaCloudConsulting/security-platform` (public, secret scanning + push protection disabled); `gh variable list` (empty); `rules/branches/main` (`deletion`, `non_fast_forward`); `code-scanning/alerts` unfiltered (`[]`) vs `?ref=refs/pull/8/merge` (populated) vs `&tool_name=Semgrep%20OSS` (3 alerts, 86/87/88); `gh run download 34638828775 -n semgrep-results` (artifact retrieved, contents match the alerts)
- `.planning/phases/18-…/18-05-SUMMARY.md` — the `gh variable set` + empty-commit pattern, the `gh run rerun` rejection, the tree-hash identity proof, the collateral-run window check
- `.planning/phases/17-…/17-05-SUMMARY.md`, `17-07-SUMMARY.md` — the analyses-API trace commands, the NOT-OBSERVED verdict on the UI criterion, the driver-name case mismatch, one-check-per-driver
- `docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md` — six categories / seven analyses, the `pull_request`-only trigger tradeoff, the measured SARIF inventory
- `.planning/ROADMAP.md` §Phase 19; `.planning/REQUIREMENTS.md` VAL-01; `.planning/STATE.md`

### Secondary — MEDIUM confidence

- github.com/actions/upload-artifact README — v4 artifact immutability and name uniqueness [CITED]
- github.com/orgs/community/discussions/44322 — GitHub staff: *"Variables are not passed to workflows that are triggered by a pull request from a fork."* Official staff answer in an official forum, but **not** a docs page, and the discussion is unresolved since Jan 2023 [CITED]

### Tertiary — LOW confidence

- The specific claim that `gh run rerun` returns **409** on duplicate artifact names (as opposed to some other failure mode) — 18-05's stated rationale, never measured. Immaterial: the recommended path avoids re-runs entirely.

*Note:* `docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/store-information-in-variables` returned HTTP 404 — the docs URL structure has changed. The fork-variable question was answered from the community discussion instead, and is flagged A4 accordingly.

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|---|---|---|
| Fixture determinism (D-01, D-02) | **HIGH** | Measured against the exact CI-pinned gitleaks and the CI-pinned semgrep spec; the semgrep baseline independently cross-validated against live production alerts on PR #8 |
| SC3 trace mechanics | **HIGH** | The full three-hop path was executed end-to-end against a real merged PR in this session |
| Gate-flip and re-trigger mechanics | **HIGH** | Phase 18-05 performed exactly this sequence live 2026-09-12 and recorded run ids, tree hashes and conclusions |
| Live repo state | **HIGH** | Read directly from the API this session |
| Pre-commit / push-gate interaction | **HIGH** | Config read; stages and excludes verified; ruff behavior measured on the actual candidate file |
| Checkov side effects of the new fixtures | **MEDIUM** | Measured locally at 3.2.396; CI runs 3.3.17 (A2). Impact is cosmetic either way. |
| Fork-PR variable behavior | **MEDIUM** | GitHub staff answer, no docs page, 2023 vintage (A4). Not load-bearing for this phase. |
| `gh run rerun` failure mode | **LOW** | Never measured; deliberately routed around |

**Research date:** 2026-09-12
**Valid until:** 2026-10-12 for the live repo state (variables, rulesets, PR numbers change), and **per-run** for the finding counts — `p/default` and Gitleaks' bundled config resolve at scan time, so treat every count as a dated measurement, exactly as `fixtures/README.md` already instructs.
