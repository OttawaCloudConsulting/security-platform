# Phase 20: Template Packaging and Adoption Docs - Research

**Researched:** 2026-09-13
**Domain:** GitHub Actions reusable-workflow distribution, versioning/tagging, and adoption documentation
**Confidence:** HIGH on the local/codebase facts (all read live this session); MEDIUM on two GitHub-platform behaviours flagged in the Assumptions Log

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Reusable workflow location**
- **D-01:** The canonical reusable workflow files move into THIS repo — `security_solution/.github/workflows/` —
  not left only in `security-platform`. DIST-07's `uses: OCC-github/security_solution/.github/workflows/<name>.yml@ref`
  requires the file to physically exist at that path. `security-platform`'s copies (`security.yml`, `pr-security.yml`)
  were the build/validation ground (Phases 14-19); Phase 20 copies the validated version into `security_solution`
  as the new canonical source repeat repos call. Keep them in sync going forward — planner's call on whether
  `security-platform` re-points to `uses:` the new canonical copy or keeps its own local copy for self-scanning.

**Versioning / ref strategy**
- **D-02:** Consumer repos pin to tagged releases (`@v1`, `@v2`, ...), not `@main` and not a raw SHA. Matches
  this project's existing pin-with-version-comment convention (Phase 14) applied at the repo-release level
  instead of the individual-action level. Planner/executor must establish a tagging/release mechanism
  (e.g. `git tag v1` on the commit that ships the reusable workflow) as part of this phase.

**Docs location**
- **D-03:** Adoption docs go in a **new standalone file under `docs/`** (e.g. `docs/adoption-guide.md`),
  not appended to the already ~2,300-line `development-security-stack-option-1.md`. Keeps the main reference
  blueprint from growing further and gives other repos' maintainers a single focused doc to follow.

**Per-repo substitutions (copy-paste template)**
- **D-04:** `gate_mode` (Phase 18's flag/var) is the ONLY per-repo substitution point. No other placeholders
  needed — the five scan jobs auto-detect what's in the repo (npm/pip/terraform/Dockerfile paths), and branch
  names are not hardcoded anywhere that needs per-repo substitution. SC4's "docs state which scan jobs apply
  to which repo types and how to disable the ones that do not apply" is a **documentation** concern (guidance
  on removing/commenting out job blocks for repo types that don't need them, e.g. a pure-frontend repo skipping
  Checkov/IaC) — not a templated substitution mechanism. Do not over-engineer a config-driven job-selection system.

### Claude's Discretion
- Exact mechanism for keeping `security-platform`'s workflow files in sync with the new `security_solution`
  canonical copies (manual copy, symlink note in docs, or `security-platform` switching to `uses:` its own
  org's new reusable workflow) — pick whatever is simplest and most maintainable; document the choice.
- Exact release/tagging automation (manual `git tag` + `gh release create`, or a lightweight GitHub Actions
  release workflow) — pick whatever fits the project's zero-cost, low-ceremony philosophy (see PROJECT.md
  "zero-cost, open-source... no external accounts").
- Adoption doc's internal structure (single doc vs a doc + quick-reference table) — pick whatever best serves
  SC3's "walk through both consumption modes end to end, covering gate-mode selection, branch protection
  setup, and Dependabot wiring."

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. (Note: several small tooling/doc-accuracy items were deferred
from Phase 19 to "Phase 20" in its deferred-items.md — D-19-B through D-19-E — but on inspection these are
GSD-tooling quirks (stale gsd-sdk positional-arg docs, a no-op pre-push Gitleaks hook config, a STATE.md
percent-field cosmetic mismatch), not Template Packaging / Adoption Docs domain items. They don't belong in
this phase's scope; flagging here so they aren't silently lost, but not folding them in.)
</user_constraints>

## Research Corrections to Locked Decisions

These are **not** re-litigations of the decisions. Each is a factual premise inside a locked decision that was
measured false this session. The planner must surface them, not quietly work around them.

| # | Decision | Stated premise | Measured reality | Consequence |
|---|----------|----------------|------------------|-------------|
| C-1 | D-01 / DIST-07 / ROADMAP SC2 | `OCC-github/security_solution` is a repo path | `gh api orgs/OCC-github` → 404; `gh api repos/OCC-github/security_solution` → 404; account is `OttawaCloudConsulting`, type **User** | The literal `uses:` string in DIST-07 and SC2 is unusable. Correct form is `OttawaCloudConsulting/<repo>/.github/workflows/security.yml@<ref>` |
| C-2 | D-01 "THIS repo" | This repo is a publishable GitHub repo | `origin` = `…/security-platform.git`; `git merge-base HEAD origin/main` → empty (disjoint); current branch 404s on the remote | The docs repo must be **created and pushed** before D-01 is physically possible. See Q1 |
| C-3 | D-04 rationale | "the five scan jobs auto-detect what's in the repo (npm/pip/terraform/**Dockerfile** paths)" | npm/pip/tf: yes, via `scripts/detect-*.sh`. Docker: **no** — `security.yml:827` hard-codes `fixtures/Dockerfile` under Phase 15 D-06 "unconditional build. No 'does a Dockerfile exist' check" | The container job must gain a detection step for D-04's premise to hold. Framed as *implementing* D-04, not changing it |
| C-4 | CONTEXT §Phase Boundary | "This phase does NOT modify the pipeline's scanning behavior" | SC1 requires "dropping it into a repo produces a working scan run". Unmodified, it does not run at all on a repo without `scripts/detect-*.sh` + `fixtures/Dockerfile` | The boundary and SC1 are mutually unsatisfiable. The minimum-diff portability pass is listed below; nothing else in scanning semantics changes |
| C-5 | CONTEXT canonical_refs | "required-checks cover six frozen check-run names" (quoting 18 D-06) | Phase 18 corrected this to **five** — the `security` wrapper job emits no check run of its own (verified twice: 14-02 and 18-04; `scripts/set-required-checks.sh` carries exactly five contexts; ADR-017 records the "five-not-six correction") | Adoption docs must list **five** contexts. A sixth would sit permanently pending |
| C-6 | D-02 `@v1` | `v1` is a free tag namespace | `git tag -l` in this repo already returns **`v1.1`** (the blueprint *document* version, Phase 13 "v1.1 shipped", at commit `75241dd`) | `@v1` / `@v1.1` would be ambiguous between "document version" and "workflow version". Recommend a distinct namespace — see Pattern 3 |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIST-06 | Copy-paste workflow template packaged for manual adoption into a consumer repo | Pattern 2 (substitution markers), Pattern 5 (portability pass — without it the template does not run), Code Example 1-3, Pitfall 2 (copy-paste mode must remain self-contained: no cross-repo checkout) |
| DIST-07 | Reusable workflow callable via `uses: <owner>/<repo>/.github/workflows/<name>.yml@ref` from other repos | **Blocked on Q1** (host repo does not exist). Pattern 1 (`uses:` wiring + permissions ceiling), Pattern 3 (tagging), Pattern 4 (private-repo access setting), Code Example 4-6 |
| DIST-08 | Adoption docs covering both consumption modes, for rollout to the remaining 6+ repos | Pattern 6 (doc structure: public/private branch first), Code Example 7-9 (branch protection, Dependabot), Pitfalls 1-7, Environment Availability (per-repo-type applicability matrix) |
</phase_requirements>

## Summary

Phase 20 is not a "copy two files and write a doc" phase. Three facts measured live this session change the
shape of the work:

1. **The destination repository does not exist.** `gh api repos/OCC-github/security_solution` returns 404 and
   `gh api orgs/OCC-github` returns 404. `OCC-github` is the local filesystem parent directory
   (`/Users/christian/git-repos/OCC-github/…`), not a GitHub org. The real account is
   **`OttawaCloudConsulting`, and it is a User account, not an Organization** (`gh api
   users/OttawaCloudConsulting --jq .type` → `User`). Worse, this documentation repo's `origin` points at
   `https://github.com/OttawaCloudConsulting/security-platform.git` — the *product* repo — while its history is
   **completely disjoint** from it (`git merge-base HEAD origin/main` returns empty) and its current branch does
   not exist on the remote (`gh api …/contents?ref=feature/phase-12-repo-setup-script` → 404). **This repo has no
   GitHub home today.** DIST-07 cannot be satisfied until one is created or the host repo is re-chosen. This is
   Open Question Q1 and it is BLOCKING — it needs a `checkpoint:decision`, not a guess.

2. **The validated workflow is not portable as written.** `security.yml` calls three repo-local helper scripts
   (`bash scripts/detect-{npm,python,terraform}.sh`, lines 396/400/404) and hard-codes
   `docker build -f fixtures/Dockerfile … fixtures/` (line 827). A relative path inside a *called* workflow
   resolves against the **caller's** workspace [CITED: github.com/orgs/community/discussions/107558], so in
   `uses:` mode all four break on any consumer that lacks those exact paths — and in copy-paste mode they break
   unless the consumer also copies three scripts and invents a `fixtures/` tree. `fixtures/` is explicitly
   validation-only scaffolding local to `security-platform` (19-06-SUMMARY). CONTEXT.md's claim that the jobs
   "auto-detect … Dockerfile paths" (D-04 rationale) is **true for npm/pip/terraform and false for Docker**.

3. **SARIF upload will not work on private consumer repos, and the pipeline fails loudly when it doesn't.**
   Probed live: public `terraform-pipelines` → `code-scanning/analyses` 404 "no analysis found" (feature
   available); private `aws-zabbix-monitoring-solution` → **403 "Code scanning is not enabled for this
   repository"**. The six `Verify … SARIF upload landed` steps carry **no** `continue-on-error` and are guarded
   only on fork/Dependabot, so on a private same-repo PR they run, read `outcome != success`, and turn the job
   **red regardless of `gate_mode`**. **37 of the account's 60 repos are private** (`gh repo list --limit 200`).
This is the
   single most likely adoption failure after the missing repo.

Everything else is in good shape: `gate_mode` genuinely needs no YAML edit (Phase 18 measured identical tree
hashes across a report-only→blocking→report-only flip), the five required check contexts are byte-frozen and
already scripted, and Phase 18 already wrote branch-protection guidance into the blueprint — Phase 20's doc
should **cross-reference** `docs/development-security-stack-option-1.md` §Phase 2 (L2008-2068), not restate it.

**Primary recommendation:** Resolve Q1 at a checkpoint first. Then land a *portability pass* on the canonical
copy (inline the three detectors as `git ls-files` blocks; make the container job's build conditional on a
discovered Dockerfile), publish it at the decided path, cut both a moving `v1` and an immutable `v1.0.0` tag,
and write `docs/adoption-guide.md` as a decision-tree doc whose first branch is **public vs private consumer**,
not copy-paste vs `uses:`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Scan execution (5 jobs) | Canonical reusable workflow (`security.yml`) | — | Already built and validated Phases 14-19; unchanged in substance |
| Trigger policy (`on: pull_request`) | Consumer repo caller (`pr-security.yml`) | — | Each repo owns when scans run; also owns the FROZEN `security` job id |
| Gate mode selection | Consumer repo settings (`gh variable set GATE_MODE`) or caller `with:` | Canonical workflow default (`report-only`) | Phase 18 D-03: no YAML edit to switch; callee resolves caller's `vars` |
| Ecosystem detection (npm/pip/tf/Docker) | Canonical workflow, inline | — | Must work with zero consumer-side files; cannot depend on `scripts/` or `fixtures/` |
| Required-status-check enforcement | Consumer repo ruleset (GitHub API) | Adoption doc procedure | Rulesets are per-repo; `set-required-checks.sh` hard-codes one ruleset id |
| Version pinning of the workflow | Consumer repo `uses: …@<ref>` + Dependabot | Canonical repo git tags/releases | Tag is published by the host; the pin lives in the consumer |
| Dependency currency (action SHAs) | Consumer `.github/dependabot.yml` (copy-paste mode) / canonical repo's own Dependabot (`uses:` mode) | — | Dependabot never proposes updates for `uses: ./…` local refs |
| Adoption procedure / repo-type guidance | `docs/adoption-guide.md` (new, D-03) | Blueprint §Phase 2 (cross-reference only) | CLAUDE.md forbids growing the 2,428-line blueprint further |

## Project Constraints (from CLAUDE.md)

| Directive | Source | Effect on this phase |
|-----------|--------|----------------------|
| This is a **reference documentation project**, not buildable software | CLAUDE.md §What This Repository Is | Phase 20 adding `.github/workflows/` makes it *also* a workflow-hosting repo. Worth a README/CLAUDE.md note so the next reader isn't surprised |
| Preserve ASCII architecture diagrams and the 4-phase layered structure | CLAUDE.md §Editing Guidelines | Any edit to `docs/development-security-stack-option-1.md` §Phase 2 or §Complete GitHub Actions Workflow must not disturb the layering or the diagrams |
| Preserve tool coverage matrices and the comparison table | CLAUDE.md §Editing Guidelines | The adoption guide's "which jobs apply to which repo type" table is a **new** table in a **new** file; do not rewrite the blueprint's matrices |
| `docs/adr/` is **append-only** — add new records, never modify accepted ones | CLAUDE.md §Editing Guidelines | ADR-017 (and 001/002/004/016) must not be edited. A new **ADR-018** is the right home for the packaging/host/versioning decisions. Add its row to `docs/adr/README.md` after ADR-017 |
| Never set the executable bit on scripts; always `bash script.sh` | `.claude/rules/defensive-protocol-v2-anti-slop.md` | Any release/tag helper script must be invoked `bash …`; no `chmod +x`. Both existing helpers state this in their headers |
| Let it crash — no silent fallbacks (`|| true`, `except: pass`) | same rule file | The blueprint's illustrative template uses `|| true` (L1526). Do not carry that pattern into the canonical/copy-paste template |
| Irreversible actions pause for confirmation | `…-session-management.md` | Creating a public GitHub repo, pushing 320 commits of history, and tagging are all effectively irreversible → checkpoints |

## Standard Stack

### Core

No new libraries or packages are introduced by this phase. The "stack" is the already-pinned tool set inside
`security.yml` plus the local CLI tooling used to publish and verify.

| Tool | Version (verified live) | Purpose | Why standard |
|------|------------------------|---------|--------------|
| `gh` (GitHub CLI) | 2.100.0 | repo create, variable set, ruleset read/write, release create | Already the project's only GitHub API surface (Phases 14-19) [VERIFIED: `gh --version`] |
| `git` | 2.50.1 (Apple Git-155) | tagging, push, disjoint-history publish | — [VERIFIED: `git --version`] |
| `actionlint` | 1.7.12 | static workflow validation | Used as a merge gate in 18-08 [VERIFIED: `actionlint --version`] |
| `yamllint` | 1.37.1 | `-d relaxed` YAML validation | Used as a merge gate in 18-08 [VERIFIED: `yamllint --version`] |
| `gitleaks` | 8.30.1 | pre-publication history scan | Same version the CI `secrets` job pins [VERIFIED: `gitleaks version`] |
| `python3` | 3.12.0 | `check-workflow-uploads.sh` (PyYAML invariant gate) | Existing offline gate [VERIFIED: `python3 --version`] |

### Supporting

| Asset | Location | Purpose | When to use |
|-------|----------|---------|-------------|
| `security.yml` (1070 lines) | `repos/security-platform/.github/workflows/security.yml` | The validated callable workflow — source of truth to copy | Always: this is the file Phase 20 packages |
| `pr-security.yml` (61 lines) | `repos/security-platform/.github/workflows/pr-security.yml` | The `pull_request` caller; `security` job id FROZEN | Copy-paste mode ships it verbatim; `uses:` mode ships a 1-line-different variant |
| `dependabot.yml` (13 lines) | `repos/security-platform/.github/dependabot.yml` | `github-actions` weekly updates, `directory: "/"` | Both modes; see Pitfall 6 for the `uses:`-mode difference |
| `scripts/set-required-checks.sh` (12 KB) | `repos/security-platform/scripts/` | Read-modify-write helper for `required_status_checks` + `pull_request` rules; dry-run by default, 7 documented exit codes | Reference for the adoption doc's branch-protection section — **but** it hard-codes `--repo OttawaCloudConsulting/security-platform` and `--ruleset 14243983` |
| `scripts/check-workflow-uploads.sh` (15 KB) | `repos/security-platform/scripts/` | Offline PyYAML gate for SARIF/artifact invariants; exit 0/1/2 | Run against the new canonical copy after the portability pass |
| `scripts/detect-{npm,python,terraform}.sh` | `repos/security-platform/scripts/` | `git ls-files` pathspec detectors, exit 0 on both branches, write `found=true|false` to `$GITHUB_OUTPUT` | Their **logic** is inlined into the canonical copy (Pattern 5); the files stay in `security-platform` for `smoke-scans.sh` |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| Inlining the three detectors | Second `actions/checkout` of the canonical repo at `${{ job.workflow_sha }}` into `path:` | Works in `uses:` mode only. In copy-paste mode `job.workflow_repository` resolves to the *consumer's* own repo, so the scripts are still missing; and a hard-coded `repository:` makes copy-paste mode network-dependent on the canonical repo, defeating its point. Rejected |
| Inlining the three detectors | Ship them as a composite action in the canonical repo | `uses: ./…` inside a called workflow resolves to the **caller's** workspace [CITED: community discussion 107558], so the consumer would need `uses: OttawaCloudConsulting/<repo>/.github/actions/detect@v1` — a second pinned reference to keep in sync, for ~40 lines of `git ls-files`. Rejected as over-engineering |
| Moving `v1` tag | Immutable tags only (`v1.0.0`), consumers pin exact | Safer but every canonical change requires a PR in all 6+ consumers. Recommendation: publish **both** (Pattern 3) |
| Creating a new host repo | Host the canonical copy in `security-platform` (already public, already has the files at `b4cb207`) | Zero new infrastructure and satisfies DIST-07's *substance* immediately — but contradicts D-01's "not left only in `security-platform`" and couples every consumer to a repo containing deliberately-vulnerable `fixtures/`. Fallback only; see Q1 Option B |

**Installation:** none. No package is added to any manifest by this phase.

## Package Legitimacy Audit

**N/A — this phase installs no external packages.** No npm, PyPI, or crates dependency is added; the only new
artifacts are YAML workflow files, git tags, and Markdown docs. The action SHAs already present in
`security.yml` were pinned and reviewed in Phases 14-17 (ADR-004) and are **not** re-resolved by this phase —
re-resolving them would silently change the validated tree.

`slopcheck` was therefore not run. If a future plan adds a package, the Package Legitimacy Gate applies.

## Architecture Patterns

### System Architecture Diagram — the two consumption modes

```text
                       CANONICAL HOST REPO  (Q1: which repo? must be decided)
                       ┌──────────────────────────────────────────────────────────┐
                       │ .github/workflows/security.yml    ← on: workflow_call    │
                       │   inputs: gate_mode                                      │
                       │   env: GATE_MODE = inputs || vars.GATE_MODE ||           │
                       │                    'report-only'                        │
                       │   5 jobs: sast · iac · sca · container · secrets         │
                       │ .github/workflows/pr-security.yml ← local caller         │
                       │ git tags:  v1  (moving)  +  v1.0.0 (immutable)           │
                       └───────────┬──────────────────────────────────┬───────────┘
                                   │                                  │
        MODE B ── uses: …@v1 ──────┘                                  └──── MODE A ── copy-paste
                                   │                                  │
   ┌───────────────────────────────▼──────────┐   ┌───────────────────▼──────────────────────┐
   │ CONSUMER REPO (Mode B)                   │   │ CONSUMER REPO (Mode A)                   │
   │ .github/workflows/pr-security.yml  ONLY  │   │ .github/workflows/pr-security.yml        │
   │   on: pull_request                       │   │ .github/workflows/security.yml   (copy)  │
   │   jobs.security:                         │   │   ↑ gate_mode is the ONLY substitution   │
   │     name: security      ← FROZEN         │   │ .github/dependabot.yml           (copy)  │
   │     permissions: contents: read          │   │                                          │
   │                 security-events: write ← │   │ NOTE: self-contained. No network          │
   │                 actions: read     CEILING│   │ dependency on the canonical repo.        │
   │     uses: OWNER/REPO/.github/workflows/  │   │ Dependabot updates the action SHAs here. │
   │           security.yml@v1                │   │                                          │
   │ .github/dependabot.yml ← updates the @v1 │   └──────────────────┬───────────────────────┘
   └──────────────────┬───────────────────────┘                      │
                      │                                             │
                      └──────────────┬──────────────────────────────┘
                                     ▼
              ┌───────────────────────────────────────────────────────────┐
              │ RUN ON THE CONSUMER'S CHECKOUT                            │
              │  github.repository  = CONSUMER  (always, both modes)      │
              │  actions/checkout   = CONSUMER's code                     │
              │  vars.GATE_MODE     = CONSUMER's repo variable            │
              │  relative paths ./  = CONSUMER's workspace ← portability  │
              └──────────┬───────────────────────┬────────────────────────┘
                         │                       │
              ┌──────────▼─────────┐   ┌─────────▼──────────────────────────┐
              │ 5 job check runs   │   │ SARIF → code scanning              │
              │ 'security / …'     │   │  PUBLIC repo  → lands (404→alerts) │
              │ → ruleset required │   │  PRIVATE repo → 403, verify step   │
              │   status checks    │   │    turns job RED  ← Pitfall 1      │
              └────────────────────┘   │ JSON/SARIF → 90-day artifacts (OK) │
                                       └────────────────────────────────────┘
```

### Recommended file layout (canonical host repo, after this phase)

```text
<canonical host repo>/
├── .github/
│   ├── workflows/
│   │   ├── security.yml          # canonical callable workflow (portability pass applied)
│   │   └── pr-security.yml       # self-scan caller (uses: ./ — stays relative)
│   └── dependabot.yml            # github-actions, directory: "/", weekly
├── docs/
│   ├── adoption-guide.md         # NEW (D-03) — both modes, both repo visibilities
│   └── adr/
│       ├── adr018-<packaging-host-and-versioning>.md   # NEW
│       └── README.md             # +1 index row after ADR-017
└── templates/                    # OPTIONAL — see Pattern 2
    ├── pr-security.copy-paste.yml
    └── pr-security.reusable.yml
```

### Pattern 1: `uses:`-mode caller — the permissions ceiling is the whole trick

**What:** In Mode B the consumer ships only a caller. The caller's **job-level** `permissions` block is the
**ceiling** for the called workflow: a called workflow can maintain or reduce, never elevate
[CITED: docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows].

**When to use:** Every Mode B consumer. Omitting `security-events: write` on the caller 403s every SARIF
upload while the run still reports green — the failure mode the blueprint already calls "the single most likely
adoption failure" (L1474-1481).

**Example:** see Code Example 4. The three grants (`contents: read`, `security-events: write`, `actions: read`)
must be restated at **job** level, because a job-level `permissions` block *replaces* the workflow-level set
(`pr-security.yml` L29-31 documents this).

### Pattern 2: Substitution markers — one marker, in the caller, not the callee

**What:** D-04 fixes `gate_mode` as the only per-repo substitution. The cleanest expression of that is: the
copy-paste bundle contains **no placeholder tokens at all**, and the one adjustable thing is documented as a
`gh` command rather than a YAML edit.

**Why:** Phase 18 proved (18-05, three commits sharing tree `ce7ec652…`) that switching modes needs **no YAML
edit** — `gh variable set GATE_MODE --body blocking`. A `<YOUR_GATE_MODE>` placeholder would invite an edit
where none is needed, and a bare passthrough `gate_mode: ${{ vars.GATE_MODE }}` in the caller is explicitly
**FORBIDDEN** (`pr-security.yml` L54-57): an unset variable resolves to `""`, which counts as a *provided*
input and suppresses the callee's own default.

**Recommended marker convention** — a single banner block at the top of each shipped file, plus one inline
marker at the only decision point:

```yaml
# ─────────────────────────────────────────────────────────────────────
# COPY-PASTE TEMPLATE — per-repo substitutions: 1 (gate_mode), and it is
# NOT edited here. Leave this file byte-identical to the canonical copy.
#   report-only (default): do nothing.
#   blocking:  gh variable set GATE_MODE --body blocking -R OWNER/REPO
# ONE line in this file must never be renamed: `name: security` below.
# ─────────────────────────────────────────────────────────────────────
```

**Anti-pattern:** a `<OWNER>`/`<REPO>`/`<BRANCH>` placeholder set. Nothing in the validated workflow needs
them — branch names appear nowhere (`on: pull_request: {}`, all branches), and `github.repository` is resolved
by the runner.

### Pattern 3: Versioning — publish a moving major tag **and** an immutable point tag

**What:** GitHub's own release-management guidance for reusable components: create a release with a semver tag
(`v1.0.1`), and **move the major tag (`v1`) to the current release**; introduce a new major only for breaking
changes [CITED: docs.github.com/en/actions/how-tos/create-and-publish-actions/manage-custom-actions]. `@ref`
accepts a SHA, a release tag, or a branch name; if a tag and branch share a name the **tag wins**; the SHA is
"the safest option for stability and security" [CITED: same doc set, reuse-workflows].

**Why both:** D-02 asks for `@v1`, but a moving tag is mutable — the exact risk class ADR-004 addressed at the
action level. Publishing `v1` (moving, what the docs tell consumers to pin) *and* `v1.0.0` (immutable, what a
security-sensitive consumer or an audit pins) costs one extra command and resolves the tension honestly.

**Namespace warning (C-6):** `v1.1` already exists in this repo as the *blueprint document* version. If the
canonical host is this repo, use a distinct namespace — `workflows-v1` / `workflows-v1.0.0`, or `pipeline/v1` —
and say so in ADR-018. If the host is `security-platform` (which has **zero** tags and **zero** releases,
verified live), plain `v1` is free.

**Automation:** manual `git tag` + `gh release create` (Code Example 6). A release *workflow* is not warranted:
the release is a two-command, human-gated, irreversible act on a repo with ~1 release per phase.

### Pattern 4: Access — public host is the only configuration-free option

**What:** A reusable workflow in a **private** repo is callable by other repos only after the host repo's
**Settings → Actions → General → Access** is set to "Accessible from repositories owned by the
'OttawaCloudConsulting' user" [CITED: docs.github.com/en/actions/how-tos/reuse-automations/share-across-private-repositories].
Because the account is a **User**, not an Organization, the org-level wording and org-level rulesets in most
tutorials do not apply here.

**When:** If the canonical host ends up private, this setting is a mandatory adoption-doc step and a mandatory
verification (a missing setting produces a workflow-not-found error in every consumer). A **public** host needs
no setting at all. `security-platform` is already public; a new `security_solution` would need to be created
public to avoid this (which triggers the history-scan preflight — see Q1 and Pitfall 7).

### Pattern 5: The portability pass — minimum diff, by line number

**What:** Four edits to the canonical copy (and **only** the canonical copy; `security-platform`'s own file may
keep the script calls if it stays on a local copy). Nothing about scanner selection, severity, `gate_mode`,
SARIF categories, artifact names, or retention changes.

| # | Line(s) in `security.yml` | Today | Change | Why |
|---|---------------------------|-------|--------|-----|
| P-1 | 396 | `run: bash scripts/detect-npm.sh npm-lockfiles.txt` | inline `git ls-files -- '*package-lock.json' \| grep -v node_modules` block (Code Example 1) | Consumer has no `scripts/` |
| P-2 | 400 | `run: bash scripts/detect-python.sh py-reqs.txt` | inline `git ls-files -- '*requirements*.txt'` block | same |
| P-3 | 404 | `run: bash scripts/detect-terraform.sh tf-files.txt` | inline `git ls-files -- '*.tf'` block | same |
| P-4 | 826-827 | `- name: Build fixture image` / `docker build -f fixtures/Dockerfile … fixtures/` | add a `Detect Dockerfile` step (id `docker`) before it; rename to `Build image from discovered Dockerfile`; guard on `steps.docker.outputs.found == 'true'` (Code Example 2) | `fixtures/` is `security-platform`-only (19-06) |
| P-5 | 829-842, 844, 863, 894 | container-job scan/convert/`ls -l`/upload/verify steps run unconditionally or on `always()` | compound each with `steps.docker.outputs.found == 'true'` | Once the build can skip, `trivy image` has no image, `ls -l` fails on missing files, and `if-no-files-found: error` fails the artifact upload. This is exactly the 18-02 `always() && <cond>` lesson |
| P-6 | 388-390, 502, 817-818 | comments asserting "the logic lives in shared scripts … so that CI and `scripts/smoke-scans.sh` exercise the same implementation", "(measured in `scripts/smoke-scans.sh`, 16-03)", and D-06's "unconditional build. No 'does a Dockerfile exist' check" | rewrite to describe what the canonical copy actually does | A comment that is false in the shipped file is worse than no comment — and these three are the exact rationales P-1..P-5 invalidate |

**Planner decision — provenance comments.** `security.yml` carries hundreds of `# D-04 / Phase 18 CICD-06`,
`# ADR-001`, `# 17-03`, `# T-15-13` markers. They are this project's traceability record and they are also
meaningless to an external consumer reading a copied file. Keep them (traceability, and the copy stays
diff-able against the canonical) or strip them for the copy-paste bundle only (clarity, at the cost of a
non-trivial diff)? **Recommend keep**, with a one-paragraph "how to read the comments" note in the adoption
guide: a divergent copy-paste copy cannot be diffed against the canonical, which is the only cheap way a
consumer can tell whether their copy is stale.

**Pathspec correctness is load-bearing** and already solved — preserve the detectors' comments verbatim when
inlining. `git ls-files -- '*package-lock.json'` matches every depth **including the root**;
`package-lock.json` is root-anchored only and `**/package-lock.json` matches nested only. A wrong pathspec
produces a `SKIP:` line on a repo that really does have dependencies — a false pass invisible in the log
(measured, 16-RESEARCH Pitfall 9).

**Sync consequence (Claude's Discretion item):** after P-1..P-5 the canonical copy and `security-platform`'s
copy legitimately differ. The cleanest resolution — **recommended** — is for `security-platform` to switch its
`pr-security.yml` to `uses: OttawaCloudConsulting/<host>/.github/workflows/security.yml@v1`, deleting its local
`security.yml`. Then there is exactly one copy in the world, `security-platform` becomes consumer #1 (and a
continuous live test of Mode B), and `scripts/detect-*.sh` demote to `smoke-scans.sh`-only helpers. Cost:
`security-platform`'s own PRs no longer exercise its own workflow changes in-place (the relative-ref property
its L3-5 comment values), and a broken canonical breaks self-scanning too.

**The cost that is easy to miss:** `security-platform` is the *only* repo where all five scanners reliably fire
(`fixtures/` is permanent, 19-06). Once it pins `@v1`, a change to the canonical workflow can no longer be
proven against that fixture set **before** being tagged — the proof would require tagging first, which inverts
the order. **Mitigation to document in ADR-018:** for pre-release validation, temporarily point
`security-platform`'s caller at the candidate branch or SHA
(`uses: OttawaCloudConsulting/<HOST>/.github/workflows/security.yml@<branch-or-sha>`), merge the proof PR, tag,
then flip the caller back to `@v1`. That is a deliberate, documented, temporary un-pin — not a policy exception
to D-02, which governs *consumer* repos.

### Pattern 6: Adoption-doc structure — branch on repo visibility first

**What:** SC3 asks for both modes end to end. The measured blocker is orthogonal to mode: **public vs private**
decides whether SARIF upload works at all. Recommended outline:

```text
docs/adoption-guide.md
 1. Who this is for / what you get (5 checks, 5 artifacts, SARIF where available)
 2. Preflight — 4 commands, with expected output
      gh api repos/O/R/code-scanning/analyses     → 404 = OK, 403 = private path
      gh api repos/O/R/rulesets --jq '.[].id'     → [] means you must CREATE one
      gh variable list -R O/R                     → GATE_MODE must be absent
      gh api repos/O/R --jq .private
 3. Pick a mode (decision table: Mode A copy-paste vs Mode B uses:)
 4. Mode A — copy 3 files, verbatim, no edits
 5. Mode B — copy 1 caller file, set the @ref
 6. First run: what green means (green ≠ clean — 19-06's finding)
 7. Gate-mode selection: report-only → blocking, the gh command, the fork caveat
 8. Branch protection: the FIVE byte-exact contexts, integration_id 15368,
    read-modify-write warning, D-07 ordering, self-lockout warning
 9. Dependabot wiring (differs by mode — Pitfall 6)
10. Which jobs apply to which repo type + how to remove one (SC4)
11. Private-repo limitations (SARIF 403, the verify-step consequence)
12. Troubleshooting table (7 rows = the 7 pitfalls below)
13. Cross-references: blueprint §Phase 2 (L2008-2068), ADR-016, ADR-017, ADR-018
```

Keep it a **single file**. A doc + separate quick-reference invites drift between two documents describing one
procedure — the exact failure 18-06 had to repair between the blueprint and the milestone plan.

### Pattern 7: SC4's applicability matrix — documentation, not mechanism

**What:** D-04 forbids a config-driven job-selection system. Express SC4 as a table plus one removal recipe.

| Repo type (real examples in this account) | sast | iac | sca | container | secrets |
|---|---|---|---|---|---|
| Terraform / IaC (`terraform-pipelines`, `occ-tg-infra-platform`) | keep | **keep** | keep (tflint fires) | skip — no Dockerfile | keep |
| Node/CDK (`aws-zabbix-monitoring-solution`) | keep | keep (checks GH Actions + any k8s YAML) | keep (npm audit fires) | keep if a Dockerfile exists | keep |
| Python | keep | keep | keep (pip-audit fires) | keep if a Dockerfile exists | keep |
| Docs-only / config-only (`rss-feeds`, `CV`) | keep (cheap, near-zero findings) | keep | keep (all sub-scans SKIP cleanly) | skip | **keep** |
| Kubernetes manifests (`occ-k8s-app-config`, `k8s-cluster-config`) | keep | **keep** | keep | skip | keep |

**Removal recipe:** delete the whole top-level job block (`container:` through its last step) from the copied
`security.yml` in Mode A. Two mandatory warnings: (1) if that check is already in a ruleset's
`required_status_checks`, **remove it from the ruleset first** — a required context with no matching check run
sits permanently pending rather than failing (RESEARCH P-07 via `set-required-checks.sh` header); (2) **never**
rename a job you keep — the five contexts are frozen byte-exact. In Mode B, jobs cannot be removed; the correct
answer for a Mode B consumer is "the job runs, detects nothing, and skips cleanly" — which after P-4/P-5 is
true for the container job too.

### Anti-Patterns to Avoid

- **Publishing the blueprint's `## Complete GitHub Actions Workflow` (L1456-1698) as the copy-paste template.**
  It is illustrative and **stale**: `actions/checkout@<SHA>` literal placeholders, `--config auto` (which the
  live workflow's own comment says is a hard error with `--metrics=off`), `|| true` silent fallbacks, no
  `gate_mode`, no `workflow_call`, `on: push: branches: [main]`. Dropping it in a repo does **not** produce a
  working scan run, so it cannot satisfy SC1. Either retitle it as an illustration pointing at the canonical
  file, or replace its body with a pointer — either way a deliberate decision, recorded.
- **Adding a `<GATE_MODE>` placeholder to the caller.** Forbidden by `pr-security.yml` L54-57 reasoning: `""`
  counts as provided and kills the callee default.
- **Renaming the `security` job, or any of the five scan-job `name:` values.** Frozen. Em dash U+2014.
- **Requiring the six code-scanning per-driver checks** (`Semgrep OSS`, `Checkov`, `Trivy`, `gitleaks`,
  `tflint`, `tflint-errors`). Deferred by 18 D-06; and `Checkov` concluded `failure` on a PR that legitimately
  merged (17-07 hand-forward #4).
- **Telling consumers to add anything resembling `fixtures/`.** Validation-only scaffolding local to
  `security-platform` (19-06). A consumer with `fixtures/` inherits permanent findings and can never go
  blocking.
- **Running `set-required-checks.sh --apply` against a consumer without `--verify-sha`.** The script refuses
  (exit 4) by design; the docs must teach the refusal, not a workaround.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Detecting npm/pip/tf files | A `find`/`ls` walk | `git ls-files -- '*<pat>'` with the measured pathspec + `found=true|false` to `$GITHUB_OUTPUT` | Three wrong pathspec forms already measured; `git ls-files` respects `.gitignore` and skips `node_modules` correctly |
| Adding required status checks | `PUT /rulesets/{id}` with only the new rule | `scripts/set-required-checks.sh` pattern (GET → keep every other rule type → append → assert nothing dropped → PUT) | `PUT` **replaces the whole document**: a naive body silently deletes `deletion` + `non_fast_forward` — a security regression dressed as an improvement (18-03, proven negatively) |
| Verifying a check name before requiring it | Retyping from docs | `gh api repos/O/R/commits/<SHA>/check-runs --jq '.check_runs[] \| select(.app.id==15368) \| .name'` | The five contexts contain em dash U+2014; analyses and check-runs endpoints **disagree on case** (`checkov` vs `Checkov`, `Gitleaks` vs `gitleaks`). Branch protection matches the **check-run** name (17-07 #5) |
| Switching gate mode | A YAML edit / a second workflow file | `gh variable set GATE_MODE --body blocking -R O/R` | Measured: identical tree hash, 5 green → 5 red → 5 green (18-05) |
| Keeping action SHAs current | A manual audit calendar | `dependabot.yml` `github-actions`, `directory: "/"` | Also updates external `uses: owner/repo/.github/workflows/x.yml@ref` refs [CITED: github.blog changelog 2023-03-13] |
| Version pinning policy | Inventing a scheme | GitHub's release-management guidance: semver tag + moving major tag | [CITED: manage-custom-actions] |
| Proving the copied workflow is still valid | Eyeballing the diff | `actionlint` + `yamllint -d relaxed` + `bash scripts/check-workflow-uploads.sh` | The exact three gates 18-08 ran against the merged state |

**Key insight:** every hand-rolled alternative in this domain fails *silently green*. A wrong pathspec, a
dropped ruleset rule, a mistyped em dash, a missing caller permission — none produces a red step. That is why
the existing scripts assert rather than print, and why the adoption doc must give commands with **expected
output**, not just commands.

## Runtime State Inventory

D-01 is a canonical-location migration, so live state outside git matters.

| Category | Items found | Action required |
|----------|-------------|------------------|
| Stored data | **None.** No database, no cache, no datastore holds a path or repo name for this pipeline. Verified: the pipeline's only persistence is run artifacts (90-day) and code-scanning analyses, both keyed by run/repo, neither containing the canonical path | none |
| Live service config | **`OttawaCloudConsulting/security-platform` ruleset id `14243983`** ("Default", branch target) — live, currently carrying only `deletion` + `non_fast_forward` (no `required_status_checks`; 18-05 "leave-unrequired" decision, re-confirmed at 19-07 close). **`terraform-pipelines` ruleset id `12760793`** exists and is `active` — a Mode A/B pilot there must read-modify-write it, never replace it. Private `aws-zabbix-monitoring-solution` has **`[]`** — no ruleset; a pilot there must **create** one (`POST /repos/O/R/rulesets`), a path `set-required-checks.sh` does not implement | Document both paths (modify existing vs create new) in the adoption doc; do not change `security-platform`'s ruleset in this phase |
| OS-registered state | **None.** No cron, launchd, Task Scheduler, or pm2 entry references this pipeline | none |
| Secrets / env vars | **`GATE_MODE` repository variable: confirmed ABSENT** on `security-platform` (`gh variable list` empty at 19-07 close; REST 404). No secrets are used by the pipeline — every tool is account-free (Semgrep CE `p/default`, Checkov, Trivy, tflint, Gitleaks, npm/pip audit). `GITHUB_TOKEN` only | None. Adoption doc must state "no secrets to provision" — a genuine selling point |
| Build artifacts / installed packages | **Stale local remote-tracking ref** `origin/feature/phase-12-repo-setup-script` at `2b48f6c` exists locally but **not** on the remote (`git ls-remote` omits it; `gh api …/contents?ref=…` 404). Existing tag **`v1.1`** at `75241dd` in this repo (document version — C-6). `security-platform`: **0 tags, 0 releases** | Prune the stale ref before publishing (`git remote prune origin`); decide the tag namespace (Pattern 3) |
| Git remote (added category) | **`origin` of this docs repo points at `security-platform.git` with disjoint history.** Pushing this repo's current branch to `origin` would push 320 commits of unrelated documentation history into the product repo | If Q1 Option A: create the new repo and **re-point `origin`** before any push. Treat as irreversible → checkpoint |

## Common Pitfalls

### Pitfall 1: Private consumer repos go permanently red — regardless of `gate_mode`

**What goes wrong:** On a private repo the code-scanning API returns **403 "Code scanning is not enabled for
this repository"** (measured: `aws-zabbix-monitoring-solution`). `upload-sarif` carries
`continue-on-error: true` (ADR-001) so it tolerates the 403 — but the six `Verify … upload landed` steps have
**no** `continue-on-error`, are guarded only on `head.repo.full_name == github.repository && actor != dependabot`
(which a same-repo private PR **passes**), and `exit 1` on `outcome != success`. Every affected job turns red
even in `report-only`.

**Why it happens:** the verify steps exist precisely to stop a "broken but green" pipeline (17-03/17-04). They
assume SARIF ingestion is available. On a personal-account private repo it is not.

**How to avoid:** decide and document one of —
(a) document it, and have private consumers delete the six verify steps (Mode A only; a documented, marked
edit — note this weakens D-04's "one substitution" claim, so the doc must own it);
(b) add a capability guard to the canonical copy, e.g. `&& github.event.repository.private == false`, or a new
`workflow_call` input `expect_code_scanning` defaulting to `true`;
(c) scope Phase 20's SC2 pilot to **public** consumers only and record private-repo adoption as a follow-up.
Option (b) is the only one that works in Mode B. **This needs a decision — see Q2.**

**Warning signs:** job red with `upload outcome=failure — the upload did not land.` and a green scan step above it.

### Pitfall 2: `uses:` mode silently makes the pipeline non-portable if you "fix" scripts with a cross-repo checkout

**What goes wrong:** the obvious fix for the missing `scripts/detect-*.sh` is a second `actions/checkout` with
`repository: <canonical>` / `ref: ${{ job.workflow_sha }}`. It works in Mode B and **breaks Mode A**: in Mode A
the job is defined by the *consumer's own* copy, so `job.workflow_repository` is the consumer, and a hard-coded
`repository:` turns a self-contained copy-paste bundle into a network dependency on the canonical repo.

**How to avoid:** inline the detectors (Pattern 5). One file, both modes, no extra refs.

**Warning signs:** any `repository:` input on `actions/checkout` inside `security.yml`.

### Pitfall 3: A required context that GitHub has never seen sits permanently pending

**What goes wrong:** adding `security / Container — Trivy Image` as required on a repo where that job has never
produced a check run (or where the job was deleted per SC4) blocks every PR forever — pending, not failing.

**How to avoid:** D-07 ordering, verbatim: (1) run in `report-only` and confirm the contexts **appear** and
conclude green; (2) flip to `blocking` and confirm they turn **red**; (3) only then add them as required.
`set-required-checks.sh` enforces this with a mandatory `--verify-sha` preflight (exit 6 on a missing context).
ADR-017 records the correction that step 1 cannot observe red — a report-only run is green by definition.

**Warning signs:** "Expected — Waiting for status to be reported" that never resolves.

### Pitfall 4: `PUT /rulesets/{id}` deletes the rules you didn't send

**What goes wrong:** a body containing only `required_status_checks` silently removes `deletion` and
`non_fast_forward` from `main`.

**How to avoid:** GET → keep every rule whose type you are not replacing → append → assert no pre-existing
type was dropped → PUT. Proven both positively and negatively in 18-03. Give consumers the script, not the raw
`PUT`. Also: `bypass_actors` must be carried forward **verbatim**, never synthesised.

**Warning signs:** `rules/branches/main` losing rule types between before/after reads.

### Pitfall 5: Self-lockout on `blocking` + required checks, with no bypass

**What goes wrong:** rulesets do **not** auto-exempt repo admins (`bypass_actors: []`,
`current_user_can_bypass: "never"` measured on `security-platform`). Under `blocking` with the five checks
required, a repo whose scanners always find something can never merge — including the PR that would revert the
change. This is why `security-platform`'s own `main` was deliberately **left unrequired** (18-05; `fixtures/` is
permanent).

**How to avoid:** doc must state, for each consumer: add a bypass actor **first** if you are unsure, and only
require checks once a clean PR has actually gone green under `blocking`. Also note the corollary: a consumer
with pre-existing HIGH/CRITICAL findings cannot go blocking until it fixes them — `blocking` is severity-agnostic
(fails on ANY finding, ADR-017 / 18 D-04).

**Warning signs:** `required_approving_review_count > 0` on a solo account is the other lockout vector
(18-03 chose `0` deliberately).

### Pitfall 6: Dependabot wiring differs by mode, and never updates a local ref

**What goes wrong:** Mode A consumers who skip `dependabot.yml` freeze their action SHAs forever. Mode B
consumers who copy `security-platform`'s `dependabot.yml` comment verbatim will read "Dependabot ignores
locally referenced reusable workflows" and wrongly conclude their `@v1` ref won't be updated.

**How to avoid:** state both facts. `uses: ./.github/workflows/security.yml` (local, relative) is **never**
proposed for update — by design. `uses: OWNER/REPO/.github/workflows/security.yml@v1` (external) **is**
supported since 2023-03-13 [CITED: github.blog/changelog/2023-03-13-dependabot-updates-support-reusable-workflows-for-github-actions].
`directory: "/"` is required for `.github/workflows` discovery. Mode A: Dependabot keeps ~8 action SHAs current.
Mode B: Dependabot keeps exactly one `@ref` current, and the canonical repo's own Dependabot keeps the SHAs.

### Pitfall 7: Publishing this repo's history will be blocked by GitHub Push Protection

**What goes wrong:** `gitleaks git .` on this documentation repo, run live this session: **16 findings across
320 commits** — 13 `aws-access-token`, 2 `generic-api-key`, 1 `discord-api-token` — in
`.planning/phases/05-secrets-detection-gate/05-02-SUMMARY.md` (5), `19-RESEARCH.md` (4), `19-01-PLAN.md` (3),
`05-VERIFICATION.md` (2), `STATE.md` (1), `.claude/gsd-file-manifest.json` (1). Free push protection for
**public** repos is account-level, not the repo's `security_and_analysis` block (D-19-B), so it will fire on a
first push to a new public repo — exactly as `GH013` did in 19-03.

**How to avoid:** expect it and plan for it. 19-03's precedent: the operator approved per-secret unblock URLs
with reason "used in tests" — no history rewrite, no `.gitleaksignore` fingerprints. Budget a human step.
Alternatively push only a subset (a fresh-history repo containing `.github/`, `docs/`, `README.md`), which
sidesteps the issue entirely and is worth offering as Q1 Option A-variant.

**Warning signs:** `remote: error: GH013: Repository rule violations found` naming a commit and a blob.

### Pitfall 8: Fork PRs silently fail open

**What goes wrong:** a fork-triggered workflow cannot read repository variables, so `vars.GATE_MODE` is `""`,
the `||` chain falls through to `'report-only'`, and a repo configured to block runs report-only while its
required checks still report green. [CITED: github.com/orgs/community/discussions/44322 — GitHub staff answer,
**not** a docs page, unresolved since Jan 2023; never measured by this project (19-07 Q1)]

**How to avoid:** a **public** consumer that genuinely needs blocking on fork PRs must pass a literal
`with: gate_mode: blocking` from its caller rather than relying on the variable. Document it as the caveat it
is — including that it is unverified.

## Code Examples

### 1. Inlined npm detector (replaces `security.yml:394-396`)

```yaml
# Source: derived from repos/security-platform/scripts/detect-npm.sh (measured pathspec, 16-02/16-03)
      # Pathspec: '*package-lock.json'. Git's default (non-':(glob)') pathspec wildcards
      # already cross '/', so a single leading '*' matches every depth INCLUDING the root.
      # The two wrong forms, both measured (16-RESEARCH Pitfall 9):
      #   'package-lock.json'    -> root-anchored, misses subdirectories
      #   '**/package-lock.json' -> nested only, misses the repo root
      # Exits 0 on BOTH branches: "no npm in this repo" is a valid answer, not an error.
      - name: Detect npm lockfiles
        id: npm
        run: |
          # grep -v exits 1 on empty input; under pipefail that would abort the detector.
          # This is the one legitimate `|| true` — on the discovery pipeline only.
          git ls-files -- '*package-lock.json' \
            | grep -v -e '/node_modules/' -e '^node_modules/' > npm-lockfiles.txt || true
          count=$(grep -c . npm-lockfiles.txt || true)
          if [ "${count:-0}" -eq 0 ]; then
            echo "SKIP: no package-lock.json found — npm sub-scan not applicable to this repository"
            echo "found=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          echo "FOUND ${count} npm lockfile(s):"
          cat npm-lockfiles.txt
          echo "found=true" >> "$GITHUB_OUTPUT"
```

Python and Terraform are the same shape with `git ls-files -- '*requirements*.txt'` → `py-reqs.txt` and
`git ls-files -- '*.tf'` → `tf-files.txt`. Keep the `SKIP:`/`FOUND` strings byte-identical — `smoke-scans.sh`
and the adoption doc both quote them.

### 2. Conditional container build (replaces `security.yml:826-827`, guards 829-894)

```yaml
      # Phase 15 D-06's "unconditional build" was correct for security-platform, whose
      # fixtures/Dockerfile always exists. A consumer repo may have no Dockerfile at all;
      # an unconditional `docker build -f fixtures/Dockerfile` fails there 100% of the time.
      - name: Detect Dockerfile
        id: docker
        run: |
          git ls-files -- '*Dockerfile' '*Dockerfile.*' '*.dockerfile' > dockerfiles.txt || true
          count=$(grep -c . dockerfiles.txt || true)
          if [ "${count:-0}" -eq 0 ]; then
            echo "SKIP: no Dockerfile found — container sub-scan not applicable to this repository"
            echo "found=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          first=$(head -1 dockerfiles.txt)
          echo "FOUND ${count} Dockerfile(s); building the first: ${first}"
          { echo "found=true"; echo "path=${first}"; } >> "$GITHUB_OUTPUT"

      - name: Build image from discovered Dockerfile
        if: steps.docker.outputs.found == 'true'
        run: |
          ctx=$(dirname "${{ steps.docker.outputs.path }}")
          docker build -f "${{ steps.docker.outputs.path }}" \
            -t scan-target:${{ github.sha }} "$ctx"

      # Every downstream step in this job gains the same guard. Note the 18-02 lesson:
      # `if: always()` alone would run these after a skipped build and fail on missing files.
      - name: Run Trivy image scan
        if: steps.docker.outputs.found == 'true'
        continue-on-error: ${{ env.GATE_MODE == 'report-only' }}  # D-04 / Phase 18 CICD-06
        run: |
          trivy image scan-target:${{ github.sha }} --scanners vuln \
            --format json --output trivy-image.json \
            --exit-code 1 --severity HIGH,CRITICAL
      # …Convert to SARIF / Show scan output files / Upload SARIF / Verify / Upload artifact:
      # each becomes `if: always() && steps.docker.outputs.found == 'true'`
```

`if-no-files-found: error` on the artifact upload (L~905) **must** keep its guard — without it a clean skip
fails the job, the precise pattern 18-02 fixed for the three SCA sub-scans.

### 3. Mode A (copy-paste) — what the consumer does, in full

```bash
# Source: measured behaviour, Phases 14-19. Three files, zero edits.
mkdir -p .github/workflows
curl -fsSL -o .github/workflows/security.yml \
  https://raw.githubusercontent.com/OttawaCloudConsulting/<HOST>/v1/.github/workflows/security.yml
curl -fsSL -o .github/workflows/pr-security.yml \
  https://raw.githubusercontent.com/OttawaCloudConsulting/<HOST>/v1/.github/workflows/pr-security.yml
curl -fsSL -o .github/dependabot.yml \
  https://raw.githubusercontent.com/OttawaCloudConsulting/<HOST>/v1/.github/dependabot.yml
git add .github && git commit -m "ci: adopt security scanning pipeline (report-only)"
# Open a PR. Expect five checks named `security / …`, all green, and a mergeable PR.
# Later, when ready to gate:  gh variable set GATE_MODE --body blocking -R OWNER/REPO
```

### 4. Mode B (`uses:`) — the entire consumer-side file

```yaml
---
# .github/workflows/pr-security.yml — the ONLY file a Mode B consumer needs.
name: PR Security

on:
  pull_request: {}

permissions:
  contents: read          # workflow-level FLOOR

jobs:
  security:
    # FROZEN. This job id is the PREFIX of every check-run name the called
    # workflow emits (`security / <job name>`), and the five branch-protection
    # contexts depend on it byte-exactly. Renaming it renames all five at once.
    name: security
    # A job-level permissions block REPLACES the workflow-level set, and the
    # caller's set is the CEILING for a called workflow — a callee can reduce
    # but never elevate. Omit security-events: write and every SARIF upload
    # 403s while the run still reports green.
    permissions:
      contents: read
      security-events: write
      actions: read                 # required for private repositories
    # `@v1` is a MOVING tag — it is the ref GitHub's own guidance tells consumers to
    # pin, and it will advance to v1.0.1, v1.0.2, … A trailing `# v1.0.0` comment here
    # would go stale the moment the tag moves and imply an immutability this ref does
    # not have. A consumer that needs an audit-stable record pins the immutable point
    # tag instead: `…/security.yml@v1.0.0`.
    uses: OttawaCloudConsulting/<HOST>/.github/workflows/security.yml@v1
    # No `with:` block, deliberately: gate_mode stays unset so the callee's
    # chain resolves vars.GATE_MODE (THIS repo's variable) then 'report-only'.
    # NEVER write `with: {gate_mode: ${{ vars.GATE_MODE }}}` — an unset variable
    # resolves to "", which counts as PROVIDED and suppresses the default.
    # A PUBLIC repo that must block on FORK PRs needs a literal
    # `with: {gate_mode: blocking}` instead (fork PRs cannot read vars).
```

Deliberately **no** trailing version comment on the `uses:` line. This project's SHA-pin-with-version-comment
convention (Phase 14) works because a SHA never moves; `@v1` does. Dependabot maintains version comments on SHA
pins, not on tag refs, so a hand-written `# v1.0.0` here would rot silently. Consumers choose one ref shape:
`@v1` (tracks patches, what the docs recommend) or `@v1.0.0` (immutable, auditable, requires a PR to advance).

### 5. Preflight the consumer before adopting anything

```bash
# Source: all four probed live this session against real repos in this account.
REPO=OttawaCloudConsulting/terraform-pipelines

gh api "repos/$REPO" --jq '.private, .visibility'
# false public  -> SARIF will land.  true private -> see Pitfall 1.

gh api "repos/$REPO/code-scanning/analyses" 2>&1 | head -2
# 404 "no analysis found"                        -> code scanning AVAILABLE (public repo)
# 403 "Code scanning is not enabled ..."         -> NOT available (private repo, this account)

gh api "repos/$REPO/rulesets" --jq '.[] | "\(.id)\t\(.name)\t\(.enforcement)"'
# a row  -> read-modify-write THAT id (never PUT a fresh document)
# empty  -> no ruleset exists; you must POST /repos/OWNER/REPO/rulesets first

gh variable list -R "$REPO"
# GATE_MODE must be ABSENT for the report-only default to apply
```

### 6. Publish a version (manual, human-gated)

```bash
# Source: docs.github.com release-management guidance for actions/workflows.
# Run from the canonical host repo, on the commit that ships the workflows.
git tag -a v1.0.0 -m "Security scanning pipeline v1.0.0 (5 jobs, gate_mode, SARIF, 90d artifacts)"
git tag -a v1     -m "Security scanning pipeline v1 (moving major tag -> v1.0.0)"
git push origin v1.0.0 v1
gh release create v1.0.0 --title "Security pipeline v1.0.0" --notes-file docs/release-notes/v1.0.0.md

# Later, shipping v1.0.1 — move the major tag:
git tag -a v1.0.1 -m "…" && git push origin v1.0.1
git tag -f v1 v1.0.1 && git push --force origin v1      # moving tag: mutable BY DESIGN
gh release create v1.0.1 --title "…" --notes "…"
```

Verify consumers can resolve it — and note that `git tag -a` creates an **annotated** tag, so the ref endpoint
returns the *tag object*, not the commit:

```bash
gh api repos/OWNER/HOST/git/ref/tags/v1 --jq '.object.type, .object.sha'
# type: tag    -> annotated; deref the commit with:
#   gh api repos/OWNER/HOST/git/tags/<that-sha> --jq '.object.sha'
# type: commit -> lightweight; the sha IS the commit
```

Simplest alternative: make the **moving** `v1` a **lightweight** tag (`git tag -f v1 <commit>`, no `-a`) so it
always dereferences in one call, and keep `-a` annotated tags for the immutable point releases where the
message is part of the record.

### 7. Required status checks — the five byte-exact contexts

```bash
# Source: repos/security-platform/scripts/set-required-checks.sh (18-03), re-verified in 18-07.
# ALWAYS read the names from the live check-runs endpoint; NEVER retype them.
# The separator is EM DASH U+2014 — a hyphen or en dash is invisible in most renderers
# and produces a permanently-pending required check.
SHA=$(gh api "repos/$REPO/pulls/<N>" --jq .head.sha)
gh api "repos/$REPO/commits/$SHA/check-runs" \
  --jq '.check_runs[] | select(.app.id == 15368) | .name'
# Expect exactly these five (app.id 15368 = the GitHub Actions app):
#   security / SAST — Semgrep CE
#   security / IaC — Checkov
#   security / SCA — Trivy Filesystem
#   security / Container — Trivy Image
#   security / Secrets — Gitleaks
# There is NO bare `security` check run — the caller job emits none (verified 14-02 and 18-04).

# Then: read-modify-write the ruleset (never a bare PUT of one rule).
bash scripts/set-required-checks.sh --repo "$REPO" --ruleset <ID> --out /tmp/merged.json     # dry run
bash scripts/set-required-checks.sh --repo "$REPO" --ruleset <ID> \
  --verify-sha "$SHA" --apply --yes-i-understand-lockout                                    # live
# Read back from rules/branches/main — NEVER from the classic protection endpoint,
# which 404s by design on a rulesets-only repo (recorded as a false negative, 14-02).
gh api "repos/$REPO/rules/branches/main" --jq '.[].type'
```

The script's defaults (`--repo OttawaCloudConsulting/security-platform`, `--ruleset 14243983`) must be
overridden per consumer, and it has **no create path** — a repo with `[]` rulesets needs
`POST /repos/OWNER/REPO/rulesets` first (`aws-zabbix-monitoring-solution` is in this state).

### 8. Consumer Dependabot config (both modes)

```yaml
---
# .github/dependabot.yml
# Mode A: keeps the ~8 SHA-pinned actions inside your copied security.yml current.
# Mode B: keeps your single `uses: OWNER/HOST/...@v1` reference current
#         (external reusable workflows supported since 2023-03-13).
# Either way: `uses: ./.github/workflows/security.yml` (a LOCAL relative ref) is
# never proposed for update, by design.
version: 2

updates:
  - package-ecosystem: "github-actions"
    directory: "/"            # required for .github/workflows discovery
    schedule:
      interval: "weekly"
```

### 9. Post-copy validation the consumer (or the executor) can run offline

```bash
# Source: the exact three gates 18-08 ran against the merged state.
actionlint .github/workflows/security.yml .github/workflows/pr-security.yml
yamllint -d relaxed .github/workflows/security.yml .github/workflows/pr-security.yml
bash scripts/check-workflow-uploads.sh      # exit 0 pass / 1 workflow defect / 2 pyyaml missing
```

## State of the Art

| Old approach | Current approach | When changed | Impact here |
|--------------|------------------|--------------|-------------|
| Reusable workflows callable only from the same repo | Callable cross-repo via `owner/repo/.github/workflows/f.yml@ref`; local refs also allowed | Local refs added 2022-01-25 [CITED: github.blog changelog] | Both modes are first-class; `pr-security.yml`'s `./` form is the documented local form |
| Dependabot updated only action refs | Also updates external reusable-workflow refs, by tag or SHA | 2023-03-13 [CITED: github.blog changelog] | Mode B's `@v1` stays current automatically — correct the stale implication in `security-platform`'s `dependabot.yml` comment |
| Classic branch protection (`branches/*/protection`) | **Rulesets** (`/rulesets`, `/rules/branches/main`) | Rulesets GA 2023 | `security-platform`'s classic endpoint 404s **by design**; the adoption doc must never present that 404 as evidence of anything (14-02) |
| Nesting limit "4 levels" | **Ten** levels (top caller + 9 reusable) | current docs | Non-issue at depth 2 |
| `github.job_workflow_sha` (OIDC-claim-only) | `job.workflow_sha`, `job.workflow_repository`, `job.workflow_file_path` in the `job` context | current docs; `job.workflow_sha` "not available on GitHub Enterprise Server" | Enables the cross-repo-checkout alternative — deliberately **not** used (Pitfall 2) |

**Deprecated / stale inside this project:**
- The blueprint's `## Complete GitHub Actions Workflow` (L1456-1698): `@<SHA>` placeholders, `--config auto`,
  `|| true`, no `gate_mode`. Illustrative only — **not** the SC1 template.
- `security-platform`'s `dependabot.yml` comment implies reusable workflows are never updated; true for local
  refs only.
- `pr-security.yml` L58-61's "whether a fork PR can read repo `vars` … is UNVERIFIED. That question is handed
  to Phase 19 (VAL-01)" — Phase 19 answered it from a citation and deliberately did not test it (19-07 Q1). The
  comment is stale; correcting it is a one-line workflow edit the planner may fold into the portability pass.

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | `upload-sarif` **will 403** on a private repo in this personal account, not just the analyses **read** endpoint. Only the read was measured (403) | Pitfall 1 | If uploads actually succeed, the verify-step mitigation is unnecessary work. If they fail as predicted and it is not handled, every private consumer goes red. Cheap to settle: one pilot PR on a private repo |
| A2 | Rulesets are creatable on a private repo in this account (the `/rulesets` GET returned `[]`, not 403 — availability inferred from a successful read, not from a create) | Runtime State Inventory, Pitfall 3 | If create is gated by plan, SC3's branch-protection walkthrough applies to public consumers only |
| A3 | Fork PRs cannot read repository variables | Pitfall 8 | Single non-docs source (GitHub staff forum post, Jan 2023, unresolved), never measured here. If wrong, the fork caveat is unnecessary but harmless |
| A4 | `git ls-files -- '*Dockerfile' '*Dockerfile.*' '*.dockerfile'` is the right Dockerfile pathspec set | Code Example 2 | Untested (the three existing detectors' pathspecs **were** measured; this one is new). A wrong pathspec yields a silent `SKIP:` on a repo that does have a Dockerfile. **Must be measured before shipping**, the same way 16-03 measured the other three |
| A5 | The account's plan does not gate any of the above (`gh api user --jq .plan` returned empty — the token lacks the `user` scope, so the plan name is **unknown**) | Environment Availability | Private-repo feature availability could differ from A1/A2 |
| A6 | Publishing this repo publicly is acceptable to the operator (it contains `.planning/`, `red-team/`, and 16 gitleaks findings in history) | Q1 Option A, Pitfall 7 | A privacy objection would force Option B or a fresh-history variant. **Operator decision, not an inference** |
| A7 | `job.workflow_repository` / `job.workflow_file_path` are usable in `if:`/`with:` expressions (they appear in the contexts table; not exercised here) | Alternatives Considered | Only affects the rejected alternative |

## Open Questions

### Q1 — Where does the canonical reusable workflow physically live? **BLOCKING for DIST-07 / SC2**

- **What we know:** `OCC-github` is not a GitHub account (404). `OttawaCloudConsulting` is a **User** account.
  This documentation repo has no GitHub home: `origin` points at `security-platform.git`, history is disjoint
  (`git merge-base` empty), and its branch is absent from the remote. `security-platform` **is** public, already
  contains both validated workflow files at `origin/main` = `b4cb207`, and has zero tags and zero releases.
- **What's unclear:** whether the operator wants a new repo created and this documentation history published.
- **Options:**
  - **A (honors D-01):** create `OttawaCloudConsulting/security_solution` **public**
    (`gh repo create … --public`), re-point `origin`, push, tag. Requires: the gitleaks/GH013 preflight
    (Pitfall 7), accepting `.planning/` + `red-team/` being public, and the `v1.1` tag-namespace decision (C-6).
  - **A-variant:** create the repo but push only a curated tree (`.github/`, `docs/`, `README.md`) with fresh
    history — no secret-scanning wall, no `.planning/` exposure; costs the loss of a single-repo history.
  - **B (fallback):** host the canonical copy in `security-platform` at the already-public, already-validated
    `b4cb207`, tag `v1`, and point consumers there. Fastest and lowest-risk, but contradicts D-01's "not left
    only in `security-platform`" and couples consumers to a repo containing deliberately-vulnerable `fixtures/`.
- **Recommendation:** **A**, with A-variant as the fallback if publishing the planning history is unacceptable.
  Plan a `checkpoint:decision` as the phase's first task; do not let an executor pick. Every later task
  (tagging, doc URLs, `uses:` strings, ADR-018) depends on the answer.

### Q2 — How do private consumer repos avoid going permanently red?

- **What we know:** private repos in this account return 403 on code scanning (measured); the six verify steps
  have no `continue-on-error` and fail on a non-success upload outcome (read from source).
- **What's unclear:** whether the *upload* 403s (A1), and which of the three mitigations the operator wants.
- **Recommendation:** measure it with one pilot PR on a private repo early in the phase, then take mitigation
  (b) in its **simplest** form: guard the six verify steps with `&& github.event.repository.private == false`.
  Rationale: this is a **User** account, so no repo it owns can have GitHub Advanced Security — `private == true`
  and "code scanning unavailable" are equivalent for every consumer that exists today. It adds **zero**
  substitution points, so D-04 survives intact, and it is the only option that works in Mode B. The alternative
  `expect_code_scanning` input is only worth adding if a GHAS-bearing org consumer ever appears; do not build it
  speculatively. Still a `checkpoint:decision`, gated on the measurement.

### Q3 — What happens to the blueprint's `## Complete GitHub Actions Workflow` section?

- **What we know:** it is stale and non-functional as a drop-in (L1456-1698). 17-07 described Phase 20 as
  inheriting "a blueprint CI/CD template that is copy-pasteable as of 17-06" — that description is optimistic.
- **Options:** (a) retitle as an illustration + point at the canonical file; (b) replace the body with a
  pointer; (c) leave untouched and accept three copies drifting.
- **Recommendation:** (a). Smallest diff, preserves CLAUDE.md's 4-phase structure, kills the drift risk. Record
  in ADR-018.

### Q4 — Which repo is the SC1/SC2 pilot?

- **Recommendation:** two pilots, both already cloned under `repos/`. **`terraform-pipelines`** (public, has
  `.tf`, no Dockerfile) exercises the public/SARIF path, tflint findings, the container clean-skip, and has an
  existing ruleset (`12760793`) to read-modify-write. **`aws-zabbix-monitoring-solution`** (private, has
  `package-lock.json`, has `templates/`) exercises the private path (A1/A2) and ruleset creation. Use
  `terraform-pipelines` for the SC1/SC2 proof and `aws-zabbix-monitoring-solution` only to measure Q2.

### Q5 — Does `security-platform` become consumer #1?

- **Recommendation:** yes (Pattern 5). One copy in the world, and `security-platform`'s own PRs continuously
  prove Mode B works. Cost: it loses the self-testing property of a relative ref, and a broken canonical breaks
  its self-scan. Record in ADR-018 as the D-01 sync decision. If the operator prefers safety, keep
  `security-platform` on its local copy and accept a documented two-copy sync burden — but then a drift check
  belongs in the adoption doc.

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` | repo create, variables, rulesets, releases | ✓ | 2.100.0 | none needed |
| `git` | tag/push/publish | ✓ | 2.50.1 | — |
| `actionlint` | workflow validation gate | ✓ | 1.7.12 | — |
| `yamllint` | YAML validation gate | ✓ | 1.37.1 | — |
| `gitleaks` | pre-publication history scan (Pitfall 7) | ✓ | 8.30.1 | — |
| `python3` + PyYAML | `check-workflow-uploads.sh` | ✓ | 3.12.0 (script exits 2 if PyYAML missing — verify) | none; exit 2 is an infrastructure signal, not a defect |
| `jq` | API response inspection | ✓ | 1.8.2 | `gh --jq` |
| `docker` | local Dockerfile-detection sanity check (optional) | ✓ | 28.3.2 | CI |
| GitHub token scopes | repo create / ruleset write / release | **partial** | `gist, read:org, repo, workflow` | **`admin:org` absent** (harmless — no org exists). `user` absent, so plan name unreadable (A5). `admin:repo_hook` absent — surfaced on one probe. `gh auth refresh -s <scope>` if a write path 403s |
| `OttawaCloudConsulting/security_solution` | DIST-07 `uses:` path | **✗ does not exist** | — | **No fallback — Q1 must be decided** |
| Code scanning on private repos | SARIF upload on the 37 private repos | **✗ 403** | — | Artifacts still retained (90 days); see Q2 |

**Missing dependencies with no fallback:**
- The canonical host repository (Q1). Blocks DIST-07 and ROADMAP SC2 entirely.

**Missing dependencies with fallback:**
- Code scanning on private repos → JSON/SARIF artifacts at 90-day retention still work; the Security tab does not.
- `admin:org` / `user` token scopes → not needed for any planned action; only limited the plan-name probe.

## Validation Architecture

`nyquist_validation` is `true` in `.planning/config.json`. This repo has **no test framework** — it is a
documentation project, and the workflow files live in a gitignored nested clone.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (no pytest/jest/vitest; no `tests/` dir). Validation is lint + static-invariant gates + live CI runs |
| Config file | `.markdownlint.jsonc`, `.markdownlint-cli2.yaml` (docs); no test config |
| Quick run command | `actionlint <files> && yamllint -d relaxed <files> && bash scripts/check-workflow-uploads.sh` |
| Full suite command | The above, plus a live consumer PR: five `security / …` check runs present and concluding, five artifacts, gate flip measured |

### Phase Requirements → Test Map

| Req | Behavior | Test type | Automated command | Exists? |
|-----|----------|-----------|-------------------|---------|
| DIST-06 | Copied bundle is valid YAML and preserves all invariants | static | `actionlint` + `yamllint -d relaxed` + `bash scripts/check-workflow-uploads.sh` (exit 0) | ⚠️ exists, but see the caveat below — it must be copied into the host repo and may need updating for the guarded container steps |
| DIST-06 | Inlined detectors behave identically to the scripts they replace | unit-ish | run the inlined block against a repo **with** and **without** each ecosystem; assert `SKIP:`/`FOUND` and `found=` output. Extend `scripts/smoke-scans.sh` or a scratch git repo | ❌ Wave 0 — new |
| DIST-06 | Dockerfile pathspec is correct (A4) | unit-ish | `git ls-files -- '*Dockerfile' '*Dockerfile.*' '*.dockerfile'` in a fixture tree with root, nested, and `.dockerfile` variants | ❌ Wave 0 — new |
| DIST-06 | Dropping the bundle into a real repo produces a working run (SC1) | live | PR on `terraform-pipelines`; `gh api …/check-runs --jq '…app.id==15368…'` = the five names; container job logs `SKIP: no Dockerfile found` | ❌ live, needs Q1/Q4 |
| DIST-07 | `uses: OWNER/HOST/.github/workflows/security.yml@v1` resolves and runs (SC2) | live | `gh api repos/OWNER/HOST/git/ref/tags/v1 --jq '.object.type, .object.sha'` (annotated tags return a tag object, not a commit); then a consumer PR producing the same five contexts | ❌ blocked on Q1 |
| DIST-08 | Every command in the adoption doc actually works | doc-exec | execute each fenced command block against a real repo and paste real output | ❌ Wave 0 — manual/scripted |
| DIST-08 | The five contexts in the doc are byte-exact | static | `diff <(grep -A5 'contexts' docs/adoption-guide.md) <(gh api …/check-runs --jq …)` + a UTF-8 byte dump for U+2014 (18-07's method) | ❌ Wave 0 — new |

### Sampling Rate

- **Per task commit:** `actionlint` + `yamllint -d relaxed` on any touched workflow; `markdownlint-cli2` on any
  touched doc.
- **Per wave merge:** `bash scripts/check-workflow-uploads.sh` (exit 0) + the em-dash byte-exactness diff.
- **Phase gate:** one live PR per consumption mode, both producing five concluding `security / …` check runs and
  five artifacts, before `/gsd:verify-work`.

### Wave 0 Gaps

- [ ] Detector-parity harness for the three inlined blocks (with/without each ecosystem) — covers DIST-06
- [ ] Dockerfile-pathspec measurement (A4) — covers DIST-06 and settles an unverified assumption
- [ ] Byte-exactness check for the five contexts in the new doc — covers DIST-08
- [ ] A scratch git repo (or extension of `scripts/smoke-scans.sh`) as the harness host — no framework install needed
- [ ] Run `bash scripts/check-workflow-uploads.sh` against the **modified** canonical copy **first**. It parses
      step shapes with PyYAML, and P-4/P-5 change the container job's step list and `if:` expressions
      (`if: always() && steps.docker.outputs.found == 'true'`). A failure there is a *stale-gate vs. real-defect*
      question to answer deliberately — not automatically a workflow defect. It also does
      `cd "$(dirname "$0")/.."` (`REPO_ROOT`-relative), so it must be **copied into the canonical host repo**
      to run against the canonical files at all

## Security Domain

`security_enforcement` is not set to `false`, so this section applies. Note that this phase ships **no
application code** — the threat surface is supply chain and CI configuration.

### Applicable ASVS Categories

| ASVS category | Applies | Standard control |
|---------------|---------|------------------|
| V2 Authentication | no | No auth surface; `GITHUB_TOKEN` only, no secrets provisioned |
| V3 Session Management | no | — |
| V4 Access Control | **yes** | Least-privilege `permissions:` blocks; caller set is the CEILING; `actions: read` only for private repos; private-host access setting (Pattern 4); ruleset `bypass_actors` carried forward verbatim, never synthesised |
| V5 Input Validation | **yes** | `gate_mode` enum validated by a `case` statement as step 0 of all five jobs (the empty string is rejected on purpose); the only context interpolations in `run:` blocks are `github.sha` and server-generated step outputs — none attacker-controlled |
| V6 Cryptography | **yes** | SHA-256 checksum verification on the tflint and Gitleaks downloads (`sha256sum -c -`), download-then-verify-then-extract, never `curl | sh`; action SHA pinning (ADR-004) |
| V14 Configuration | **yes** | SHA-pinned actions with version comments; immutable point tags alongside the moving major tag; Dependabot for currency |

### Known Threat Patterns for GitHub Actions distribution

| Pattern | STRIDE | Standard mitigation |
|---------|--------|---------------------|
| Mutable ref hijack (`@main`, or a moved `@v1`) | Tampering | D-02 forbids `@main`; publish an immutable `v1.0.0` alongside the moving `v1` and record it in the consumer's ref comment (Pattern 3) |
| Compromised upstream action tag | Tampering / Supply chain | Full-SHA pins with version comments (ADR-004), already in place; Dependabot for currency. Residual, accepted: `checkov-action` internally pulls `ghcr.io/bridgecrewio/checkov:3.3.17` by **mutable tag** — the SHA-pin guarantee stops at the action boundary (T-15-13) |
| Gate silently fails open | Elevation of privilege | Fail-closed comparison `== 'report-only'` (never `!= 'blocking'`), so a typo or blank blocks rather than permits (18-02); fork-PR caveat documented (Pitfall 8) |
| Broken-but-green pipeline | Repudiation | The six SARIF + five artifact verify steps with no `continue-on-error` — the reason Pitfall 1 exists, and the reason it must be solved by a *capability guard* rather than by deleting the assertions |
| Required-check theatre (settings claim gating that isn't in force) | Elevation of privilege | D-07 ordering; `--verify-sha` preflight; read back from `rules/branches/main`, never the classic 404 endpoint |
| Ruleset regression via whole-document PUT | Tampering | Read-modify-write with a dropped-rule-type assertion (exit 3) — 18-03 |
| Secret exposure on publication | Information disclosure | `gitleaks git .` preflight before any push to a public repo; GH013 push protection as the server-side backstop (Pitfall 7) |
| Outside-collaborator log exposure via a private reusable workflow | Information disclosure | Documented GitHub warning for the private-host path (Pattern 4); prefer a public host |

## Sources

### Primary (HIGH confidence)
- **Live codebase reads (this session):** `repos/security-platform/.github/workflows/security.yml` (1070 lines,
  read in full at the relevant regions), `pr-security.yml` (61 lines, full), `.github/dependabot.yml` (13 lines,
  full), `scripts/detect-{npm,python,terraform}.sh` (full), `scripts/set-required-checks.sh` (lines 1-240),
  `scripts/check-workflow-uploads.sh` (header), `docs/development-security-stack-option-1.md`
  (§Complete GitHub Actions Workflow L1456-1530, §Phase 2 L2008-2068, heading map), `CLAUDE.md`,
  `.claude/rules/defensive-protocol-v2-*.md`, `docs/adr/README.md`, `.planning/{REQUIREMENTS,ROADMAP,STATE}.md`,
  `.planning/phases/{17,18,19}-*/…SUMMARY.md`, `19-RESEARCH.md`, `19-*/deferred-items.md`, `20-CONTEXT.md`
- **Live GitHub API probes (this session, `gh` 2.100.0):** `orgs/OCC-github` → 404;
  `repos/OCC-github/security_solution` → 404; `users/OttawaCloudConsulting` → `type: User`;
  `repo list OttawaCloudConsulting --limit 200` (60 repos: 37 private, 23 public); `repos/…/aws-zabbix-monitoring-solution/code-scanning/analyses`
  → 403 "Code scanning is not enabled"; `repos/…/terraform-pipelines/code-scanning/analyses` → 404 "no analysis
  found"; `repos/…/aws-zabbix-monitoring-solution/rulesets` → `[]`; `repos/…/terraform-pipelines/rulesets` →
  id 12760793 active; `repos/…/security-platform` → `private: false`, `secret_scanning: disabled`;
  `release list` → empty; `git ls-remote origin`; `git merge-base HEAD origin/main` → empty; `git tag -l` → `v1.1`
- **Live local tool runs:** `gitleaks git .` on this repo → 16 findings / 320 commits; version probes for 10 tools
- docs.github.com — Reuse workflows (`@ref` values = SHA/tag/branch, tag beats branch, SHA safest, 10-level
  nesting, permissions maintained-or-reduced, environment secrets not passable)
- docs.github.com — Contexts reference (`job.workflow_ref`, `job.workflow_sha` ["not available on GitHub
  Enterprise Server"], `job.workflow_repository`, `job.workflow_file_path`; `github.repository` = **caller**)
- docs.github.com — Manage custom actions / release management (semver tag + move the major tag; new major only
  for breaking changes; tags recommended over branches; SHA = no further updates)
- docs.github.com — Share across private repositories (Settings → Actions → General → Access; outside-collaborator
  log-visibility warning; 1-hour scoped installation token)
- github.blog changelog 2023-03-13 — Dependabot updates support reusable workflows (external refs, by tag or SHA)
- github.blog changelog 2022-01-25 — Reusable workflows can be referenced locally

### Secondary (MEDIUM confidence)
- github.com/orgs/community/discussions/107558 and /63863 — relative `./` paths inside a called workflow resolve
  against the **caller's** workspace; the documented workaround is a fully-qualified reference. Consistent across
  two independent discussions and with the documented `github.repository` semantics, but **not** stated on a docs
  page
- github.com/orgs/community/discussions/44322 — GitHub staff: "Variables are not passed to workflows that are
  triggered by a pull request from a fork." Official forum, unresolved since Jan 2023, no docs page (A3)

### Tertiary (LOW confidence — flagged, not relied upon)
- dhiwise.com "Ultimate Guide to GitHub Reusable Workflows" — surfaced by search, not used for any claim
- dependabot-core issues #4327 / #8451 — monorepo reusable-workflow discovery gaps; not applicable (canonical
  path is root `.github/workflows/`)

## Metadata

**Confidence breakdown:**

- **Standard stack:** HIGH — no new packages; every tool version verified by direct invocation; every source
  file read in this session
- **Architecture / portability findings:** HIGH — the four non-portable references are exact line numbers read
  from the file; the relative-path semantics are corroborated by two community sources and by the documented
  `github.repository` behaviour
- **Host-repo blocker (Q1):** HIGH — four independent probes (org 404, repo 404, empty merge-base, remote-ref 404)
- **Private-repo SARIF consequence (Pitfall 1):** MEDIUM — the 403 on the read endpoint is measured; that the
  *upload* also 403s is inferred (A1). The verify-step failure path is read from source and is deterministic
  *given* the 403
- **Pitfalls generally:** HIGH — six of eight are measured facts from Phases 14-19 summaries; Pitfall 8 is
  MEDIUM (A3) and Pitfall 1 is MEDIUM (A1)
- **Versioning / tagging:** HIGH for the mechanism (official docs), MEDIUM for the namespace recommendation
  (depends on Q1)

**Research date:** 2026-09-13
**Valid until:** 2026-10-13 (30 days) for the GitHub-platform behaviours. The **local** facts (missing host repo,
private-repo 403, ruleset ids, tag state) are point-in-time and must be re-probed if the phase starts more than a
few days from now — Q1's answer changes them all.

---
*Phase: 20-template-packaging-and-adoption-docs*
*Researched: 2026-09-13*
