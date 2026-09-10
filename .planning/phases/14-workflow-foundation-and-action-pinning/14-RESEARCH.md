# Phase 14: Workflow Foundation and Action Pinning - Research

**Researched:** 2026-09-10
**Domain:** GitHub Actions reusable workflows (`workflow_call`), action SHA pinning, Dependabot version updates for the `github-actions` ecosystem
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Placeholder job content
- **D-01:** The callable workflow's single placeholder job runs `actions/checkout` only (pinned SHA). Not a bare `echo` no-op, and not five pre-named stub jobs for sast/iac/sca/container/secrets — Phase 15 adds the real jobs from scratch.

#### SHA-pin convention
- **D-02:** Reuse the existing convention from `repos/security-platform/cicd/.github/workflows/security.yml`: `uses: <action>@<full-sha>  # v<N>` — full commit SHA with a trailing human-readable version comment.

#### Dependabot scope
- **D-03:** `.github/dependabot.yml` has a single `github-actions` ecosystem entry, weekly schedule. Do not add npm/pip/terraform ecosystem entries yet — those dependency types don't exist in this repo's workflows until later phases.

#### Caller workflow trigger scope
- **D-04:** Thin caller workflow triggers on `pull_request` only, all branches (no branch filter, no `push` trigger). Matches ROADMAP success criteria #1 verbatim ("Opening a pull request... triggers a security workflow run"). Push-to-main trigger can be added in a later phase if needed.

### Claude's Discretion
- Exact file/directory naming under `.github/workflows/` (e.g. `security.yml` for the callable file, `pr-security.yml` or similar for the caller) — not discussed, pick sensible names consistent with the reusable-workflow convention (`uses: OCC-github/security_solution/.github/workflows/<name>.yml@ref` per DIST-07/ROADMAP).

### Deferred Ideas (OUT OF SCOPE)
- Push-to-main trigger on the caller workflow — deferred, can be added later if needed (see D-04).
- Additional Dependabot ecosystems (npm, pip, terraform) — deferred until those dependency types actually appear in this repo's tree (see D-03).
- Real scan jobs (SAST, IaC, SCA, container, secrets) — explicitly Phase 15's scope, not touched here.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CICD-05 | Dependabot configured to keep GitHub Actions SHA pins updated | §Standard Stack (dependabot.yml schema, verified against `docs.github.com` source); §Pitfall 1 (Dependabot *does* update SHA pins and the trailing version comment — primary-source quote); §Pitfall 2 (default-branch-only requirement); §Pitfall 3 (locally-referenced workflows are ignored — by design here); §Validation Architecture (how to observe a Dependabot PR without waiting for an upstream release) |

**Phase 14 covers CICD-05 only.** ROADMAP success criteria 1-3 (PR triggers a run, `workflow_call` + thin caller structure, every `uses:` SHA-pinned) are structural prerequisites for CICD-01/CICD-06/DIST-07 in later phases and are not separately requirement-tagged.
</phase_requirements>

## Summary

This phase creates `.github/` from scratch in a repo that has none. Three files: a callable workflow (`on: workflow_call`), a thin `pull_request` caller that invokes it via a local relative reference, and `.github/dependabot.yml` with one `github-actions` ecosystem entry. The technical surface is small and every piece is documented on `docs.github.com` — confidence is HIGH across the board.

The single most important verified finding, because CICD-05 depends on it: **Dependabot version updates do work on SHA-pinned actions, and Dependabot rewrites the trailing version comment.** GitHub's own docs source (`data/reusables/actions/dependabot-version-updates-actions-caveats.md`) states it explicitly. A commonly-repeated claim that Dependabot "can't update SHA pins" conflates version updates with *Dependabot alerts*, which genuinely do not fire on SHA pins. Both facts are quoted below.

The second finding that shapes the plan: `actions/checkout` is at **v7.0.1** (published 2026-07-20), not v4 as in the reference workflow. v6 moved to the `node24` runtime and v7 changed fork-PR checkout defaults. The exact SHAs were resolved live via `gh api` against the canonical `actions/checkout` repo and are recorded below — the planner does not need to re-resolve them, but should re-check currency if this file is more than ~30 days old.

The third finding is a sequencing constraint the planner must design around: Dependabot only reads `dependabot.yml` from the **default branch**, so success criterion #4 cannot be observed until the phase's PR is merged to `main`. The phase is therefore inherently two-stage: open PR → observe workflow run (criteria 1-3) → merge → observe Dependabot (criterion 4).

**Primary recommendation:** Two workflow files (`security.yml` callable + `pr-security.yml` caller) plus `dependabot.yml`; pin `actions/checkout` to the **v7.0.0** SHA deliberately so Dependabot's first post-merge run produces an observable v7.0.1 bump PR that *is* the evidence for criterion #4; set `permissions: contents: read` at the top level of both workflow files now.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Scan orchestration and job definitions | CI platform — callable workflow (`security.yml`) | — | This is the artifact Phase 20 publishes for cross-repo `uses:`; all reusable logic must live here, never in the caller |
| Event/trigger binding (`pull_request`) | CI platform — caller workflow (`pr-security.yml`) | — | Triggers are repo-local policy; a callable workflow cannot define its own triggers, and baking `pull_request` into the callable file would make it non-reusable |
| Token permission scoping | CI platform — caller workflow | Callable workflow (downgrade only) | Verified: caller sets `GITHUB_TOKEN` permissions; the called workflow can only downgrade, never elevate |
| Dependency currency of action pins | Repo configuration — `.github/dependabot.yml` | — | Dependabot is a repo-level service reading only the default branch; it is not a workflow concern |
| Runner selection | Callable workflow (`runs-on`) | — | Verified: `runs-on` is **not** a legal key in a job that calls a reusable workflow; runner assignment is evaluated from the caller's *context* but declared in the called workflow |

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `actions/checkout` | **v7.0.1** (latest, `prerelease: false`) | Check out repo source in the placeholder job (D-01) | First-party GitHub action; the canonical checkout step. `[VERIFIED: gh api repos/actions/checkout/releases/latest]` |
| GitHub Actions `workflow_call` trigger | Platform feature (GA) | Makes `security.yml` callable | Documented mechanism for reusable workflows; required by ROADMAP criterion #2 and DIST-07 `[CITED: docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows]` |
| Dependabot version updates | Config schema `version: 2` | Keeps action SHA pins current (CICD-05) | GitHub-native, zero-cost, no third-party service. `[CITED: docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference]` |
| `ubuntu-latest` GitHub-hosted runner | — | Runs the placeholder job | Free tier for public repos; supports the `node24` runtime that checkout v6+ requires `[VERIFIED: action.yml at v7 SHA shows `runs: using: node24`]` |

### Resolved SHAs for `actions/checkout`

All resolved live on 2026-09-10 from the canonical `actions/checkout` repository (not a fork), per the docs caveat *"When selecting a SHA, you should verify it is from the action's repository and not a repository fork."*
`[VERIFIED: gh api repos/actions/checkout/git/refs/tags]`

| Tag | Full commit SHA | Published | Note |
|-----|-----------------|-----------|------|
| `v7.0.1` (== moving tag `v7`) | `3d3c42e5aac5ba805825da76410c181273ba90b1` | 2026-07-20 | **Current latest release** |
| `v7.0.0` | `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0` | 2026-07-20 | Recommended *initial* pin — see §Validation Architecture, criterion #4 |
| `v6.1.0` (== moving tag `v6`) | `d23441a48e516b6c34aea4fa41551a30e30af803` | 2026-07-20 | Maintenance line |
| `v5.1.0` | `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09` | 2026-07-20 | Maintenance line |
| `v4.4.0` | `11d5960a326750d5838078e36cf38b85af677262` | 2026-07-20 | Maintenance line |
| `v4.3.1` | `34e114876b0b11c390a56381ad16ebd13914f8d5` | — | The SHA used by the existing reference workflow (`# v4`) — **stale** |

> **Executor note:** if this research file is older than ~30 days at implementation time, re-resolve with
> `gh api repos/actions/checkout/git/ref/tags/v7 --jq '.object.sha'` before writing the pin. Do not
> shorten the SHA — GitHub requires the full 40-character value.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dependabot | Renovate (used by `repos/security-platform/cicd/`) | Renovate is more configurable but is a third-party GitHub App requiring installation. CICD-05 names Dependabot explicitly; Dependabot is GitHub-native and zero-config-to-enable on a public repo. **Locked by requirement — do not revisit.** |
| `actions/checkout` v7.0.x | v4/v5/v6 maintenance lines | All four lines got a coordinated release on 2026-07-20. Staying on v4 to match the reference workflow means inheriting an older runtime and missing the fork-PR checkout hardening. Use v7. |
| `uses: ./.github/workflows/security.yml` (relative) | `uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@<sha>` (absolute self-reference) | The absolute form *would* be Dependabot-trackable, but it pins the caller to a published ref — meaning changes to `security.yml` in a PR would not be exercised by that PR. Use the relative form: it resolves to the same commit as the caller, so PRs test their own changes. This is the correct choice and the Dependabot blind spot is harmless (nothing to update). |
| `on: workflow_call` (scalar) | `on: { workflow_call: {} }` (map form) | Both are valid. Use the **map form** — Phase 18's gate-mode `inputs:` block goes directly under it, so starting there avoids a structural edit later. |

**Installation:** None. No npm/pip/cargo packages are installed by this phase.

## Package Legitimacy Audit

**No registry packages are installed by this phase.** No `npm install`, `pip install`, or `cargo add` occurs. The only external dependency is the GitHub Action `actions/checkout`, which is not a package-registry artifact.

| Dependency | Source | Verification | Disposition |
|------------|--------|--------------|-------------|
| `actions/checkout` | `github.com/actions/checkout` — the canonical first-party `actions` org, **not a fork** | SHA resolved directly from the upstream repo via `gh api repos/actions/checkout/git/ref/tags/<tag>`; release confirmed `prerelease: false` via `releases/latest` `[VERIFIED: gh api]` | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none — slopcheck is not applicable (no registry packages).
**Packages flagged as suspicious [SUS]:** none.

Fork-verification is the relevant control here, per GitHub's own guidance: *"When selecting a SHA, you should verify it is from the action's repository and not a repository fork."* `[CITED: github/docs data/reusables/actions/actions-pin-commit-sha.md]`

**Optional dev tooling** (Wave 0, see §Validation Architecture): `actionlint` via Homebrew (`homebrew-core`, stable 1.7.12, bottled) — a formula, not an npm/PyPI package, so registry slopsquatting does not apply. `[VERIFIED: brew info actionlint]`

## Architecture Patterns

### System Architecture Diagram

```
  Developer opens/updates a PR
              │
              ▼
  ┌───────────────────────────────────────────────────────────────┐
  │ GitHub event: pull_request (opened | synchronize | reopened)  │
  │ GITHUB_REF = refs/pull/<N>/merge                              │
  │ GITHUB_SHA = merge commit (base ⊕ head)                       │
  │ → workflow FILES are read from that merge commit,             │
  │   so a workflow added by the PR runs on that same PR          │
  └───────────────────────────────────────────────────────────────┘
              │
              ▼
  ┌───────────────────────────────────────────────────────────────┐
  │ .github/workflows/pr-security.yml   [CALLER — repo policy]    │
  │   name: PR Security                                           │
  │   on: pull_request                                            │
  │   permissions: contents: read      ── token scope set HERE    │
  │   jobs.security:                                              │
  │     name: security               ── becomes the check prefix  │
  │     uses: ./.github/workflows/security.yml                    │
  │       (relative ⇒ same commit as caller; no @ref allowed)     │
  └───────────────────────────────────────────────────────────────┘
              │  permissions flow down (downgrade-only)
              ▼
  ┌───────────────────────────────────────────────────────────────┐
  │ .github/workflows/security.yml   [CALLABLE — reusable logic]  │
  │   on: workflow_call: {}          ── no triggers of its own    │
  │   permissions: contents: read                                 │
  │   jobs.placeholder:                                           │
  │     runs-on: ubuntu-latest       ── declared here, NOT caller │
  │     steps:                                                    │
  │       - uses: actions/checkout@<40-char-sha>  # v7            │
  └───────────────────────────────────────────────────────────────┘
              │
              ▼
  Check run surfaces on the PR as  "security / placeholder"
  Run appears in Actions tab under the CALLER's name: "PR Security"
  Merge is NOT blocked (no branch protection required checks yet — Phase 18)


  ── separate, asynchronous, default-branch-only path ──────────────

  .github/dependabot.yml  (must be on `main` to have any effect)
        │  version: 2
        │  updates: [ { package-ecosystem: github-actions,
        │               directory: "/", schedule: {interval: weekly} } ]
        ▼
  Dependabot scans  /.github/workflows/*  +  root action.yml
        │  reads  actions/checkout@<sha>  # v7
        │  (IGNORES  uses: ./.github/workflows/security.yml — local ref)
        ▼
  Newer release exists?  ──yes──▶ opens PR: bumps SHA *and* rewrites "# v7" comment
                         ──no───▶ job logs "up to date", no PR   ← criterion #4 blind spot
```

### Recommended Project Structure

```
.github/
├── dependabot.yml              # single github-actions ecosystem entry (D-03)
└── workflows/
    ├── security.yml            # CALLABLE: on: workflow_call — the reusable artifact (DIST-07)
    └── pr-security.yml         # CALLER:   on: pull_request  — thin, repo-local trigger (D-04)
```

Naming rationale (Claude's discretion per CONTEXT.md): `security.yml` matches the reference implementation's filename and the ROADMAP's `.github/workflows/<name>.yml` reusable-workflow phrasing, so Phase 20's published `uses:` string reads naturally. `pr-security.yml` makes the caller's trigger obvious from the filename and sorts adjacent.

### Pattern 1: Callable workflow (`on: workflow_call`)

**What:** A workflow whose only trigger is invocation by another workflow. It owns `runs-on`, `steps`, and all reusable logic.
**When to use:** Any workflow intended for cross-repo consumption (DIST-07). Authoring it this way from Phase 14 avoids a restructure that would invalidate Phase 19's validation.

```yaml
# Source: docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows
name: Security Scans

on:
  workflow_call: {}          # map form — Phase 18 adds `inputs:` here

permissions:
  contents: read             # baseline; may only be downgraded from caller's grant

jobs:
  placeholder:
    name: Placeholder
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0  # v7
```

### Pattern 2: Thin caller with a local relative reference

**What:** A trigger-only workflow that delegates to the callable file at the job level.
**When to use:** Whenever the callable workflow lives in the same repo and you want PRs to exercise their own changes to it.

```yaml
# Source: docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows
name: PR Security

on:
  pull_request: {}           # all branches (D-04) — no `branches:` filter

permissions:
  contents: read

jobs:
  security:                  # job id + name become the check-run prefix
    name: security
    uses: ./.github/workflows/security.yml
```

Verified constraints on this job `[CITED: docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations]`:
- Only these keys are legal: `name`, `uses`, `with`, `with.<input_id>`, `secrets`, `secrets.<secret_id>`, `secrets.inherit`, `strategy`, `needs`, `if`, `concurrency`, `permissions`.
- `runs-on` and `steps` are **illegal** here. Adding either is a parse error.
- Relative form takes **no** `@ref`: *"the called workflow is from the same commit as the caller workflow."*
- If `permissions` is omitted on the calling job, the called workflow gets the repo's default `GITHUB_TOKEN` permissions. *"The `GITHUB_TOKEN` permissions passed from the caller workflow can be only downgraded (not elevated) by the called workflow."*
- `secrets:` is unnecessary this phase — the called workflow *"is automatically granted access to `github.token` and `secrets.GITHUB_TOKEN`."*

### Pattern 3: Minimal Dependabot config for the actions ecosystem

```yaml
# Source: docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

`package-ecosystem`, `directory`, and `schedule.interval` are the three required keys. `directory: "/"` is correct and is **not** `/.github/workflows` — *"Dependabot will search the `/.github/workflows` directory, as well as the `action.yml`/`action.yaml` file from the root directory."* `[CITED: dependabot-options-reference]`

Optional keys supported for `github-actions`, all deferred as out of scope for D-03's "single entry, weekly": `schedule.day` / `schedule.time` / `schedule.timezone`, `open-pull-requests-limit` (version updates only), `groups`, `commit-message`, `labels`, `target-branch`. `interval` accepts `daily | weekly | monthly | quarterly | semiannually | yearly | cron`.

### Anti-Patterns to Avoid

- **Putting `on: pull_request` in the callable workflow.** It makes the file non-reusable and double-triggers once a caller exists. Triggers belong only in the caller (D-04, ROADMAP criterion #2).
- **Copying the reference workflow's structure.** `repos/security-platform/cicd/.github/workflows/security.yml` is `push`/`pull_request`-triggered and Renovate-managed. Borrow its *SHA-comment style* only. It is also untracked (`repos/` is gitignored) so it cannot be moved or `git mv`'d.
- **`uses:` with an abbreviated SHA.** GitHub requires the full 40-character value.
- **Pinning to the moving major tag (`@v7`) "because Dependabot will manage it."** That defeats the immutability CICD-05/ADR-004 exist to provide.
- **Pinning to a SHA that has no tag.** *"If the commit you use is not associated with any tag, Dependabot will update the Actions to the latest commit (which might differ from the latest release)."* Always pin a released tag's commit.
- **Adding `continue-on-error: true` to make the run non-blocking.** ADR-001 (`adr001-remove-continue-on-error.md`, Accepted) rejects this pattern. Non-blocking in Phase 14 comes for free from the *absence* of branch-protection required checks — nothing needs to be added. Phase 18 owns gating.
- **Adding npm/pip/terraform Dependabot ecosystems now.** Explicitly deferred (D-03); an ecosystem entry pointing at a directory with no manifests produces noisy failing Dependabot jobs.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Keeping action SHAs current | A cron workflow that queries the GitHub API and opens bump PRs | `.github/dependabot.yml` | Native, free, rewrites the version comment too, and is what CICD-05 requires |
| Checking out the repo | `run: git clone …` with a token | `actions/checkout@<sha>` | Handles merge-ref checkout, credential persistence and post-job credential cleanup |
| Making a workflow shareable | A copy-paste script that syncs YAML between repos | `on: workflow_call` + `uses:` | Phase 20's DIST-07 is a publish step only if the file is already callable |
| Resolving a tag to its commit | Hand-copying a SHA from a web page | `gh api repos/<o>/<r>/git/ref/tags/<tag> --jq '.object.sha'` | Dereferences annotated tags correctly and proves the SHA came from the canonical repo, not a fork |
| Workflow YAML validation | A bespoke schema check | `actionlint` | Catches illegal keys in reusable-workflow calls, bad expressions, and unknown `runs-on` labels |

**Key insight:** every capability this phase needs already exists as a GitHub-native primitive. The engineering effort is entirely in *correct wiring and observable verification*, not in building anything.

## Common Pitfalls

### Pitfall 1: Believing Dependabot can't update SHA-pinned actions

**What goes wrong:** The team concludes CICD-05 is unachievable with SHA pins and either drops the pins or switches to Renovate.
**Why it happens:** Two distinct Dependabot features get conflated. GitHub's docs contain both of these statements, and only the first one is about *alerts*:

> *"Dependabot only creates alerts for vulnerable actions that use semantic versioning and will not create alerts for actions pinned to SHA values."* — `content/actions/reference/security/secure-use.md` `[VERIFIED: github/docs source]`

> *"Dependabot only supports updates to Actions using the GitHub repository syntax, such as `actions/checkout@v6` or `actions/checkout@<commit>`."*
> *"Dependabot updates the version documentation of Actions when the comment is on the same line, such as `actions/checkout@<commit> #<tag or link>` or `actions/checkout@<tag> #<tag or link>`."* — `data/reusables/actions/dependabot-version-updates-actions-caveats.md` `[VERIFIED: github/docs source]`

**How to avoid:** Keep SHA pins. Keep the trailing comment **on the same line** as the `uses:` — Dependabot needs it there to rewrite the version documentation. D-02's `@<sha>  # v<N>` format satisfies this.
**Warning signs:** Someone proposing `@v7` "so Dependabot works", or moving the version comment to its own line above the `uses:`.

### Pitfall 2: Dependabot silently does nothing until the config is on the default branch

**What goes wrong:** `.github/dependabot.yml` is added in the phase PR, the PR sits open, and no Dependabot activity ever appears — the phase looks broken.
**Why it happens:** Dependabot reads its configuration from the repository's **default branch** only (`main` here `[VERIFIED: gh repo view --json defaultBranchRef]`). An unmerged config is inert.
**How to avoid:** Plan the phase in two observable stages — (1) open PR, observe the workflow run for criteria 1-3; (2) merge to `main`, then observe the Dependabot job for criterion #4. The planner must model this merge as an explicit, sequenced step, and per the project's irreversible-action rules it should be a confirm-with-user checkpoint rather than an autonomous action.
**Warning signs:** A plan whose final verification step assumes everything is provable from a single open PR.

### Pitfall 3: Expecting Dependabot to track the local caller reference

**What goes wrong:** Someone reports a bug that Dependabot "isn't seeing" `uses: ./.github/workflows/security.yml`.
**Why it happens:** By design — *"Dependabot will ignore actions or reusable workflows referenced locally (for example, `./.github/actions/foo.yml`)."* `[VERIFIED: github/docs source]`
**How to avoid:** This is correct and harmless: a local reference has no version to update. Only `actions/checkout` is a Dependabot-tracked dependency in this phase. State this in the plan so it isn't rediscovered as a defect.

### Pitfall 4: The version comment format is inconsistent across the project's own artifacts

**What goes wrong:** Executor picks one of three conventions and a later review flags it.
**Why it happens:** Three sources disagree — ADR-004 (Accepted) writes `# v4.x.y`; the reference workflow writes `# v4`; D-02 (locked) specifies `# v<N>`.
**How to avoid:** **D-02 is a locked user decision and wins.** Write `# v7`. Log the ADR-004 variance as an Open Question for the user rather than resolving it unilaterally — `docs/adr/` is append-only per CLAUDE.md, so reconciling it would require a new ADR, not an edit. Dependabot rewrites the comment correctly either way.

### Pitfall 5: Default `yamllint` rejects every GitHub Actions workflow

**What goes wrong:** The first lint run fails with `truthy value should be one of [false, true]` on the `on:` key, plus `missing document start "---"`.
**Why it happens:** YAML 1.1 treats bare `on` as a boolean. `yamllint` 's default profile flags it. `yamllint` is installed on this machine and **no `.yamllint` config exists in this repo** `[VERIFIED: command -v yamllint; ls -a]`.
**How to avoid:** Either commit a `.yamllint` with `rules: {truthy: {check-keys: false}, document-start: disable}`, or invoke inline:
```bash
yamllint -d "{extends: default, rules: {truthy: {check-keys: false}, document-start: disable}}" .github/
```
Prefer `actionlint` as the primary check — it understands Actions semantics; `yamllint` only understands YAML.

### Pitfall 6: Illegal keys in the reusable-workflow-calling job

**What goes wrong:** `runs-on: ubuntu-latest` or a `steps:` block is added to the caller's `security:` job out of habit; the workflow fails to parse and never appears in the Actions tab.
**Why it happens:** Muscle memory from normal jobs. The allowed-key list for a `uses:` job is closed (see Pattern 2).
**How to avoid:** `runs-on` belongs only in the callable workflow. Run `actionlint` before pushing.
**Warning signs:** A push produces no workflow run at all — GitHub silently drops workflows it cannot parse (check the repo's Actions tab for a red "workflow file issue" banner).

### Pitfall 7: Looking for the run under the wrong workflow name

**What goes wrong:** Criterion #1 verification checks the Actions tab for "Security Scans", finds nothing, and the phase is wrongly marked failed.
**Why it happens:** A run initiated by the caller appears under the **caller's** `name:` (`PR Security`). The called workflow's jobs appear nested inside that run. Relatedly, *"A called workflow uses the name of its caller workflow in `${{ github.workflow }}`."* `[CITED: reusing-workflow-configurations]`
**How to avoid:** Verify with `gh run list --workflow=pr-security.yml`, not the callable filename.

### Pitfall 8: Forgetting `permissions:` at the top level

**What goes wrong:** The workflows run fine now but get flagged by Phase 15's Checkov IaC job, which will scan `.github/workflows/` — the very files this phase creates.
**Why it happens:** Omission is easy; the consequence is a phase later.
**How to avoid:** Set `permissions: contents: read` at the top level of **both** files now. GitHub's baseline guidance: *"It's good security practice to set the default permission for the `GITHUB_TOKEN` to read-only access for repository contents."* `[CITED: secure-use]` Checkov has GitHub Actions policies that flag missing/overly-broad top-level `permissions` `[ASSUMED — specific policy IDs not verified this session]`. Phase 17 will need to widen the caller to `security-events: write` for SARIF upload.

### Pitfall 9 (forward-looking, Phase 17 — not this phase)

Dependabot-authored PRs trigger `pull_request` with a **read-only** `GITHUB_TOKEN` and no access to repo secrets. Once Phase 17 adds SARIF upload (`security-events: write`), it will fail on Dependabot's own PRs unless conditioned. Recording it here so it isn't discovered as a mystery failure right after Phase 14's Dependabot PR lands. `[ASSUMED — well-established platform behavior, not re-verified this session]`

## Code Examples

### Resolve a tag to its full commit SHA from the canonical repo

```bash
# Source: verified live this session
gh api repos/actions/checkout/git/ref/tags/v7 --jq '.object.sha + " " + .object.type'
# → 3d3c42e5aac5ba805825da76410c181273ba90b1 commit

# List all tags with their dereferenced type (annotated tags report type "tag", not "commit"):
gh api repos/actions/checkout/git/refs/tags --jq '.[] | "\(.ref) \(.object.type) \(.object.sha)"'

# Confirm the release is not a prerelease:
gh api repos/actions/checkout/releases/latest --jq '"\(.tag_name) prerelease=\(.prerelease)"'
# → v7.0.1 prerelease=false
```

### Confirm both workflow files registered with GitHub after push

```bash
gh api repos/OttawaCloudConsulting/security-platform/actions/workflows \
  --jq '.workflows[] | "\(.name)\t\(.path)\t\(.state)"'
```

### Observe the PR-triggered run (criterion #1)

```bash
gh run list --workflow=pr-security.yml --limit 5
gh run watch                        # live-follow the most recent run
gh run view --log                   # confirm the checkout step actually executed
```

### Confirm the check is not blocking the merge (criterion #1, second half)

```bash
gh pr view <N> --json mergeable,mergeStateStatus,statusCheckRollup
# Expect mergeable: MERGEABLE — no required checks configured (Phase 18 adds those)
gh api repos/OttawaCloudConsulting/security-platform/branches/main/protection 2>&1
# Expect 404 "Branch not protected" — confirms nothing can block the merge today
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `actions/checkout@v4` (`# v4`, SHA `34e1148…`) as in the reference workflow | `actions/checkout@v7.0.1` (`3d3c42e…`), `node24` runtime | v6.0.0 documented Node.js 24 support; v7.0.0 released, v7.0.1 on 2026-07-20 | The reference workflow's pin is a full three majors stale. Phase 14 sets a fresh v7 baseline. |
| `actions/checkout` silently checking out fork PR head on `pull_request_target` / `workflow_run` | Blocked by default; opt-in via `allow-unsafe-pr-checkout` | v7.0.0 (backported to v5.1.0/v6 as a **BREAKING** change) — see `github.blog/changelog/2026-06-18-safer-pull_request_target-defaults-for-github-actions-checkout/` | Does **not** affect this phase (plain `pull_request` trigger, no fork checkout). Relevant if any later phase reaches for `pull_request_target`. |
| Renovate for pin management (reference implementation) | Dependabot, GitHub-native | This milestone, per CICD-05 | No third-party App install; config lives in-repo |
| SHA pinning as pure convention | Enforceable platform policy at repo/org/enterprise level | Recent (`actions-blocklist-sha-pinning` feature flag in GitHub docs) | This repo currently has `sha_pinning_required: false` `[VERIFIED: gh api …/actions/permissions]`. Enabling it is a candidate for Phase 18/20, not Phase 14. |

**Deprecated/outdated:**
- `set-output` / `save-state` workflow commands — long removed; not used here, but avoid if any later phase copies old snippets.
- The `$default-branch` placeholder is a *workflow-template* feature only; it does **not** work in ordinary workflow files.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI, authenticated | SHA resolution, run observation, PR/verification commands | ✓ | 2.100.0, logged in as `OttawaCloudConsulting` | GitHub web UI (manual) |
| GitHub Actions enabled on repo | Any workflow run | ✓ | `enabled: true`, `allowed_actions: "all"` | none needed |
| Repo visibility | Free Actions minutes; Dependabot enabled by default | ✓ **PUBLIC** | `OttawaCloudConsulting/security-platform`, default branch `main` | n/a |
| `actionlint` | Pre-push workflow YAML validation | ✗ | — | `brew install actionlint` (1.7.12, bottled) — **Wave 0**; fallback is push-and-observe |
| `yamllint` | Generic YAML lint | ✓ | installed (Python 3.10 framework path) | see Pitfall 5 — needs config override |
| `pre-commit` | Repo hooks | ✓ | installed; `.git/hooks/pre-commit` present | — |
| `.yamllint` config in repo | Clean yamllint run on `.github/` | ✗ | — | inline `-d` override (Pitfall 5) |
| `.pre-commit-config.yaml` at repo root | — | ✗ (not present at root) | — | Not required by this phase; note that only one YAML file (`.markdownlint-cli2.yaml`) is currently tracked, so `.github/**.yml` will be the repo's first tracked workflow YAML |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** `actionlint` (install in Wave 0; otherwise rely on GitHub's own parse feedback after push, which is slower and noisier).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **None — this repo has no test runner.** It is a reference-documentation repo (CLAUDE.md: *"not buildable software"*). Validation is static linting plus live observation of GitHub-side state via `gh`. |
| Config file | none — see Wave 0 |
| Quick run command | `actionlint .github/workflows/*.yml && yamllint -d "{extends: default, rules: {truthy: {check-keys: false}, document-start: disable}}" .github/` |
| Full suite command | Quick run, then the `gh`-based observation sequence below |

Do **not** introduce pytest/jest here. A test framework would be scaffolding with nothing to test; the meaningful assertions are all about GitHub-side state.

### Phase Requirements → Test Map

| Req ID / Criterion | Behavior | Test Type | Automated Command | File Exists? |
|--------------------|----------|-----------|-------------------|--------------|
| Structure | Both workflow files parse and use only legal keys | static | `actionlint .github/workflows/*.yml` | ❌ Wave 0 (install actionlint) |
| Structure | `dependabot.yml` is valid YAML with `version: 2` | static | `yamllint -d "{extends: default, rules: {document-start: disable}}" .github/dependabot.yml` | ✅ yamllint present |
| Criterion #3 | Every `uses:` referencing a third-party action is a 40-char SHA with a same-line `# v` comment | static | `grep -rnE '^\s*(-\s*)?uses:' .github/workflows/ \| grep -v '^\S*:\s*uses: \./' \| grep -vE '@[0-9a-f]{40}\s+# v'` — must return no rows | ✅ grep |
| Criterion #3 | The pinned SHA belongs to the canonical repo and to a real tag | integration | `gh api repos/actions/checkout/git/refs/tags --jq '.[] \| select(.object.sha=="<SHA>") \| .ref'` — must return a `refs/tags/...` row | ✅ gh |
| Criterion #2 | Callable file declares `workflow_call`; caller invokes it locally | static | `grep -q 'workflow_call' .github/workflows/security.yml && grep -q 'uses: \./\.github/workflows/security\.yml' .github/workflows/pr-security.yml` | ✅ grep |
| Criterion #1 | Both workflows registered server-side | integration | `gh api repos/OttawaCloudConsulting/security-platform/actions/workflows --jq '.workflows[].path'` | ✅ gh |
| Criterion #1 | Opening the PR triggers a run that completes | e2e | `gh run list --workflow=pr-security.yml --limit 1 --json conclusion,status` → `completed`/`success` | ✅ gh |
| Criterion #1 | The run does not block merge | e2e | `gh pr view <N> --json mergeable,statusCheckRollup` + `gh api …/branches/main/protection` (expect 404) | ✅ gh |
| **CICD-05** / Criterion #4 | Dependabot opens a PR bumping the pinned SHA | e2e, **post-merge** | `gh pr list --author "app/dependabot" --json title,files` after the config lands on `main` | ✅ gh — but see gap below |

### The criterion #4 observability gap — and how to close it

Dependabot version-update runs cannot be triggered through the REST API; the only manual trigger is the **"Check for updates"** button under Insights → Dependency graph → Dependabot `[ASSUMED — no trigger endpoint found in the REST surface this session; not exhaustively verified]`. Combined with the default-branch-only rule (Pitfall 2), this means: if `actions/checkout` is pinned to the newest SHA (v7.0.1), Dependabot's first run finds nothing and opens **no PR** — criterion #4 becomes unobservable and can only be inferred.

**Recommended plan design:** pin the initial commit to the **v7.0.0** SHA `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0  # v7`. It is a real, canonical, tagged release commit, so every static check above passes. After the phase PR merges to `main`, Dependabot's first run has a genuine v7.0.1 upgrade available and opens a real bump PR. **That PR is the direct evidence for criterion #4**, and merging it leaves the repo on the current SHA — the intended end state — with the wiring demonstrably proven rather than assumed.

Alternative if the user prefers pinning latest immediately: accept a successful Dependabot job log showing "up to date, no updates needed" as proof of wiring, and record criterion #4 as *inferred, not witnessed*. Flag this tradeoff to the user; do not choose silently.

### Sampling Rate

- **Per task commit:** `actionlint .github/workflows/*.yml` + the SHA-format grep (both < 2s)
- **Per wave merge:** full static set + `gh api …/actions/workflows` registration check
- **Phase gate:** PR-triggered run observed green and non-blocking → merge to `main` (user-confirmed) → Dependabot PR observed → all four ROADMAP criteria witnessed

### Wave 0 Gaps

- [ ] `brew install actionlint` — required by all structural checks
- [ ] `.yamllint` (repo root) with `truthy: {check-keys: false}` and `document-start: disable`, *or* commit to the inline `-d` override in every invocation — decide once, apply everywhere
- [ ] Create a fresh branch from `main` — the current checkout is on `feature/phase-12-repo-setup-script`, a stale v1.1 branch name carrying docs commits. Phase 14's PR must not originate there.
- [ ] No test framework install — intentional; see above

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | No user-facing auth in this phase |
| V3 Session Management | no | — |
| V4 Access Control | **yes** | `permissions: contents: read` at top level of both workflows; downgrade-only inheritance to the called workflow; no branch protection changes (Phase 18) |
| V5 Input Validation | no (this phase) | No `workflow_call` inputs yet — Phase 18 adds the gate-mode input and must validate/type it |
| V6 Cryptography | **yes, indirectly** | Full 40-char SHA pinning is the integrity control: *"Pinning to a particular SHA helps mitigate the risk of a bad actor adding a backdoor to the action's repository, as they would need to generate a SHA-1 collision for a valid Git object payload."* `[VERIFIED: github/docs secure-use.md]` |
| V10 Malicious Code / Supply Chain | **yes** | SHA pinning (ADR-004), fork-verification of the SHA source, Dependabot for currency (CICD-05) |

### Known Threat Patterns for GitHub Actions

| Pattern | STRIDE | Standard Mitigation | Status this phase |
|---------|--------|---------------------|-------------------|
| Upstream tag reassignment / action repo compromise | Tampering, Elevation of Privilege | Pin to full-length commit SHA | ✅ Core deliverable (ADR-004, criterion #3) |
| SHA copied from a **fork** of the action | Tampering | Resolve via `gh api repos/<canonical-org>/<repo>/git/ref/tags/<tag>` | ✅ Done — SHAs in this doc are canonical-repo-resolved |
| Pin goes stale, misses upstream security fixes | Tampering | Dependabot version updates | ✅ CICD-05 deliverable |
| Over-broad `GITHUB_TOKEN` | Elevation of Privilege | Explicit least-privilege `permissions:` block | ✅ `contents: read` both files |
| Privilege escalation via a called workflow | Elevation of Privilege | Platform-enforced: called workflow can only downgrade caller permissions | ✅ Structural, verified |
| `pull_request_target` / fork-PR code execution ("pwn request") | Elevation of Privilege, Information Disclosure | Use plain `pull_request` (read-only token, no secrets on fork PRs); checkout v7 additionally blocks fork-PR checkout under `pull_request_target` | ✅ D-04 locks `pull_request` only |
| Script injection via `${{ github.event.* }}` in `run:` | Injection / Tampering | Never interpolate untrusted event data into shell; use `env:` indirection | ✅ N/A — no `run:` steps this phase (D-01). Becomes live in Phase 15. |
| Secrets leaked to a called workflow | Information Disclosure | Pass secrets explicitly; avoid `secrets: inherit` | ✅ No `secrets:` block needed — `GITHUB_TOKEN` is granted automatically |

## Project Constraints (from CLAUDE.md and .claude/rules/)

| Constraint | Source | Implication for this phase |
|------------|--------|----------------------------|
| Repo is reference documentation, not buildable software | `CLAUDE.md` | Do not add build/test scaffolding. Phase 14's `.github/` YAML is a genuine exception — real executable config in an otherwise docs-only repo. |
| `docs/adr/` is **append-only** — don't modify accepted records | `CLAUDE.md` | The ADR-004 comment-format variance (Pitfall 4) cannot be fixed by editing ADR-004. Raise it; don't edit. |
| Preserve ASCII architecture diagrams and the 4-phase layered structure of the primary document | `CLAUDE.md` | If the plan touches `development-security-stack-option-1.md` to document the new workflow, preserve those structures. |
| Never set the executable bit; invoke scripts with an explicit interpreter | `.claude/rules/defensive-protocol-v2-anti-slop.md` | Any helper script the plan adds must be run as `bash script.sh`; no `chmod +x`. |
| Failure response: STOP → REPORT → WAIT. No silent retry. | anti-slop rule | A failed workflow run must be reported with the raw error and a theory, not re-pushed hopefully. |
| No silent fallbacks (`\|\| true`, `try/except: pass`) | anti-slop rule | Reinforces the ADR-001 ban on `continue-on-error`. Phase 14 needs neither. |
| Irreversible actions (git history, merges, architectural commitments) require explicit user confirmation | `.claude/rules/defensive-protocol-v2-session-management.md` | **The merge-to-`main` step required for criterion #4 must be a `checkpoint:human-verify` task, not autonomous.** |
| Verification cadence: verify after 3 (unfamiliar) / 5 (routine) actions | anti-slop rule | Supports the per-task `actionlint` sampling rate above. |
| Second-order effects: list what depends on a change before making it | anti-slop rule | Creating `.github/` affects Phases 15/16/17/18/20 and becomes self-scanned input for Phase 15's Checkov job. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | There is no REST API to trigger a Dependabot version-update job; the only manual trigger is the "Check for updates" UI button | Validation Architecture | If an API exists, criterion #4 could be forced on demand and the deliberate-v7.0.0-pin strategy would be unnecessary (though still harmless) |
| A2 | Checkov's GitHub Actions policies flag missing/overly-broad top-level `permissions` | Pitfall 8 | Low — setting `permissions: contents: read` is correct on GitHub's own guidance regardless |
| A3 | Called-workflow check runs surface as `<caller-job-name> / <called-job-name>` | Architecture diagram, Pitfall 7 | Phase 18 branch protection would reference the wrong check name. **Verify on the first live run and record the exact string** — cheap to confirm, expensive to guess |
| A4 | Dependabot-authored PRs receive a read-only `GITHUB_TOKEN` with no secret access | Pitfall 9 | Forward-looking only; affects Phase 17, not Phase 14 |
| A5 | `.yamllint`-less default yamllint flags `truthy` on the `on:` key and `document-start` | Pitfall 5 | Low — the recommended override is harmless if unnecessary |
| A6 | Homebrew `actionlint` 1.7.12 works on this Darwin 25.6 / arm64 machine | Environment Availability | Low — fallback is push-and-observe |

## Open Questions

1. **Version comment granularity: `# v7` (D-02) vs `# v7.0.0` (ADR-004's `# v4.x.y` pattern)?**
   - What we know: D-02 is a locked user decision specifying `# v<N>`. ADR-004 (Accepted, append-only) shows `# v4.x.y`. The existing reference workflow uses `# v4`. Dependabot rewrites the comment correctly in all three forms.
   - What's unclear: whether the user wants the ADR reconciled. Note that `# v7` alone cannot distinguish v7.0.0 from v7.0.1 by eye — which is precisely what the criterion-#4 strategy relies on Dependabot to change.
   - Recommendation: **implement D-02 (`# v7`) as locked.** Surface the ADR-004 variance to the user during planning; if they want alignment it needs a *new* ADR (append-only), which is arguably Phase 20 scope.

2. **Repository slug mismatch: `OCC-github/security_solution` vs `OttawaCloudConsulting/security-platform`.**
   - What we know: REQUIREMENTS DIST-07 and the ROADMAP both write `uses: OCC-github/security_solution/.github/workflows/<name>.yml@ref`. The actual git remote is `https://github.com/OttawaCloudConsulting/security-platform.git` `[VERIFIED: git remote -v, gh repo view]`. `OCC-github` appears to be a local directory-path segment, not the GitHub org (`gh api /orgs/OCC-github` → 404, though the token lacks `admin:org` so this is not conclusive).
   - What's unclear: whether DIST-07's string is aspirational (a planned repo move) or simply an error.
   - Recommendation: **does not block Phase 14** — the caller uses a local relative reference with no org/repo in it. Instruct the executor **not** to hardcode `OCC-github/security_solution` in any workflow header comment or doc string. Resolve before Phase 20, which publishes the string for real.

3. **Should criterion #4 be witnessed (deliberate v7.0.0 pin) or inferred (pin latest, accept a clean Dependabot job log)?**
   - What we know: both satisfy the letter of CICD-05; only the first satisfies "Dependabot opens a pull request... when a pinned action publishes a newer release" as an *observed* fact.
   - Recommendation: witnessed — pin v7.0.0 `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0`, let Dependabot produce the v7.0.1 bump, merge it. Confirm with the user during planning; it is a visible, slightly unusual choice that deserves an explicit yes.

4. **Any org-level Actions governance that could conflict?**
   - What we know: repo-level is permissive — `enabled: true`, `allowed_actions: "all"`, `sha_pinning_required: false` `[VERIFIED: gh api …/actions/permissions]`. STATE.md flags "confirm no org-level workflow governance conflicts before authoring."
   - What's unclear: org-level policy — the current token lacks `admin:org` scope, so it could not be read this session.
   - Recommendation: repo-level permissiveness plus the fact that `actions/*` is always allowed makes a conflict very unlikely. Proceed; if the first run is blocked by policy the error message will name the policy.

## Sources

### Primary (HIGH confidence)
- **Context7 `/websites/github_en_actions`** — reusable workflows (`workflow_call` definition, caller `uses:` syntax, relative-path form, `secrets: inherit`); action SHA pinning; supported keywords for reusable-workflow-calling jobs; permission downgrade-only rule
- **`github/docs` repository source, fetched via `gh api`** (authoritative, pre-render):
  - `content/actions/reference/security/secure-use.md` — SHA-pinning rationale, `GITHUB_TOKEN` least-privilege guidance, Dependabot-alerts-vs-SHA note, SHA-pinning enforcement policies
  - `data/reusables/actions/dependabot-version-updates-actions-caveats.md` — **the decisive CICD-05 evidence:** SHA pins supported, version comment rewritten on same line, local refs ignored, untagged-commit behaviour
  - `data/reusables/actions/actions-pin-commit-sha.md` — verify the SHA is from the action's repo, not a fork
  - `content/actions/reference/workflows-and-actions/reusing-workflow-configurations.md` — closed list of allowed keys, permission inheritance, nesting/`concurrency` caveats, runner assignment, `github` context behaviour
  - `content/actions/reference/workflows-and-actions/events-that-trigger-workflows.md` — `pull_request` merge-ref semantics (`GITHUB_SHA` = merge commit, `GITHUB_REF` = `refs/pull/N/merge`), default activity types, merge-conflict behaviour
- **`gh api` live queries against `actions/checkout`** — releases, tag→SHA refs, `action.yml` runtime (`node24`), release bodies for v6.0.0/v7.0.0/v7.0.1/v5.1.0
- **`gh api`/`gh repo view` against `OttawaCloudConsulting/security-platform`** — visibility PUBLIC, default branch `main`, Actions permissions
- `docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference` (WebFetch) — dependabot.yml schema, required keys, `directory: "/"` semantics for github-actions, interval values, supported optional keys

### Secondary (MEDIUM confidence)
- `docs/adr/adr004-pin-actions-to-sha-digest.md` (in-repo, Accepted) — project's own SHA-pinning decision and rationale
- `docs/adr/adr001-remove-continue-on-error.md` (in-repo, Accepted, title only) — basis for the `continue-on-error` anti-pattern
- `repos/security-platform/cicd/.github/workflows/security.yml` (in-repo, **untracked** — `repos/` is gitignored) — existing SHA-comment convention; structurally divergent (Renovate, `push`+`pull_request`)
- `github.blog/changelog/2026-06-18-safer-pull_request_target-defaults-for-github-actions-checkout/` — referenced from the v5.1.0 release notes; not fetched directly

### Tertiary (LOW confidence)
- None. Every claim in this document traces to a primary or secondary source above, or is explicitly tagged `[ASSUMED]` in the Assumptions Log.

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — versions and SHAs resolved live from the canonical upstream repo via `gh api`, not recalled
- Architecture: **HIGH** — every structural constraint (allowed keys, permission inheritance, relative-ref commit semantics, merge-ref behaviour) quoted from `github/docs` source
- Dependabot / CICD-05: **HIGH** — the load-bearing claim is a direct quote from GitHub's own docs reusable, deliberately verified against the pre-rendered source after a summarizer produced a contradictory paraphrase
- Pitfalls: **MEDIUM-HIGH** — 1-7 are documented or locally verified; 8-9 are partly `[ASSUMED]` and logged as such
- Validation approach: **MEDIUM** — commands are sound, but check-run naming (A3) and the absence of a Dependabot trigger API (A1) need first-run confirmation

**Research date:** 2026-09-10
**Valid until:** 2026-10-10 (30 days). `actions/checkout` released four parallel lines on 2026-07-20; re-resolve the SHA if implementing after this date.
