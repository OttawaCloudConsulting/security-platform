# Phase 18: Configurable Gate Mode and Branch Protection - Research

**Researched:** 2026-09-11
**Domain:** GitHub Actions reusable-workflow inputs / expression evaluation; GitHub repository rulesets and required status checks
**Confidence:** HIGH for syntax and check-run names (official docs + live API reads + local actionlint); MEDIUM for runtime-only behaviours that no local tool can prove (empty-string input default, fork-PR `vars` availability)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Flag shape**
- **D-01:** Single global flag, `gate_mode`, controls all five scan jobs uniformly (sast, iac, sca, container, secrets) — not per-job flags. Matches roadmap wording ("the gate flag").
- **D-02:** `gate_mode` is a string enum: `"blocking"` | `"report-only"` — not a boolean. Reads naturally as a `workflow_call` input and self-documents as a repo-level `vars.gate_mode` value (repo vars are strings anyway); leaves room for a future third mode without a type change.
- **D-03:** Default when unset (no input passed, no repo variable set) is `"report-only"` — matches current Phase 15–17 behavior. A repo adopting this workflow for the first time is never silently broken by an un-set flag.

**Severity semantics**
- **D-04:** `gate_mode: blocking` fails a job on ANY finding — severity-agnostic. This is achieved by flipping `continue-on-error: false` on the scan steps that today carry D-04 (Phase 15)'s `continue-on-error: true`; each tool's already-strict native exit-code behavior (Semgrep `--error`, Checkov `soft_fail: false`, Trivy/Grype `--fail-on`/exit-code, tflint exit 2 on findings) decides pass/fail. No separate severity-cutoff input. This is required for uniformity: pip-audit's JSON has no severity field to threshold on (confirmed Phase 17), so a severity-cutoff flag could not apply consistently across all five jobs.
- **D-05:** Branch-protection guidance's "which severity threshold triggers a failure" (Success Criteria #4) is answered as "any finding, per each tool's existing native detection configuration" — not a new configurable severity knob.

**Branch protection scope**
- **D-06:** Required-checks guidance covers the six job-level checks only — `security / SAST — Semgrep CE`, `security / IaC — Checkov`, `security / SCA — Trivy Filesystem`, `security / Container — Trivy Image`, `security / Secrets — Gitleaks`, and the `security` wrapper job in `pr-security.yml` (exact names frozen per 17-07-SUMMARY.md's "twelve byte-exact check-run names" — the six job-level ones, not the six code-scanning-per-driver ones). Code-scanning-per-driver checks are informational (SARIF/Security-tab) only; Phase 17 left the Security tab's UI visibility unconfirmed, so requiring those checks is deferred.

> **Research correction to D-06 — see Open Question Q1.** Two independent live observations show the `security` wrapper job produces **no check run of its own**. D-06's set is **five**, not six. The five named checks are byte-exact and confirmed; only the sixth member of the set is wrong.

**Rollout safety**
- **D-07:** The written guidance sequences adoption explicitly: (1) confirm job-level checks appear (green when clean, red when seeded) in PR runs while still in report-only, (2) THEN set `gate_mode: blocking`, (3) THEN add the job-level checks as required in branch protection settings. State plainly that doing step 3 before step 2 leaves merges un-gated even though the workflow is configured to block.

> **Research correction to D-07 step 1 — see Open Question Q2.** "Red when seeded" is unobservable in report-only: D-04 defines report-only as "no finding ever turns a scan step red". Step 1 can only confirm the checks *appear and go green*; red-on-findings is only observable after step 2.

### Claude's Discretion
- Exact GitHub Actions expression syntax for conditionally setting `continue-on-error` per scan step based on `gate_mode` (e.g. `${{ inputs.gate_mode == 'report-only' }}` vs a computed job output) — pick whatever composes cleanly with the existing `continue-on-error: true # D-04` lines across all five jobs' scan steps.
- How the copy-paste consumption mode reads `gate_mode` from a repo variable/env (`vars.gate_mode` vs `env:` block) — pick whichever is simpler to document consistently with existing copy-paste guidance (Phase 20 is the full template-packaging phase; Phase 18 just needs the flag wired and documented for this repo).
- Exact wording/location of the new branch-protection doc (new file under `docs/`, an ADR, or a section appended to `development-security-stack-option-1.md`) — pick whatever fits the existing doc structure per CLAUDE.md's editing guidelines.

### Deferred Ideas (OUT OF SCOPE)
- Severity-cutoff gating (e.g. `gate_mode=blocking` + a severity floor) — deferred, not ruled out, per D-04/D-05. Would require inconsistent per-tool wiring since pip-audit has no severity field.
- Requiring the six code-scanning-per-driver checks (in addition to the six job-level checks) — deferred per D-06 until Phase 17's open Security-tab UI visibility question is resolved.
- Per-job gate flags (independent blocking/report-only per scan job) — deferred per D-01; roadmap and success criteria describe one flag.
- Full template-packaging and copy-paste rollout guidance for other repos — explicitly Phase 20's job; Phase 18 only needs `gate_mode` wired and documented for this repo's two consumption mechanisms.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **CICD-06** | Gate mode (block merge vs report-only) is configurable per consuming repo via a flag/input, not hardcoded | §Architecture Patterns Pattern 1 (mode-resolution chain) + Pattern 2 (11 `continue-on-error` flip points) + Pattern 3 (caller threading). Syntax accepted by `actionlint` 1.7.12 and `yamllint -d relaxed` locally; context availability confirmed against the official Context availability table. |
| **CICD-04** | Branch protection config/guidance provided so scan checks can be made required (block merge) once enabled | §Architecture Patterns Pattern 4 (read-modify-write of ruleset `14243983`) + §Code Examples (`gh api --input`) + §Common Pitfalls P-05..P-09. Five byte-exact check contexts and `integration_id: 15368` read live from `commits/{sha}/check-runs`. |
</phase_requirements>

---

## Summary

This is a CI-wiring plus documentation phase with almost no unknowns left in the *mechanism* and two real
unknowns in the *rollout*. The mechanism questions the phase brief flagged as gaps are all answered and
confirmed against primary sources: a step-level `continue-on-error` **does** accept an expression, the
`inputs`, `vars` and `env` contexts are **all** available to it, the `vars` context inside a called
workflow resolves to the **caller's** repository (so a copy-paste consumer can set one repo variable and
never touch YAML), and `jobs.<job_id>.with.<with_id>` accepts `vars` but not `secrets`. Every candidate
syntax in this document was run through `actionlint` 1.7.12 and `yamllint -d relaxed` on this machine and
both exit 0.

Two findings change the plan rather than just informing it. **First, D-06's sixth check does not exist.**
A caller job that `uses:` a reusable workflow emits no check run of its own; the check runs are one per
*called-workflow job*, named `<caller-job-id> / <called-job-name>`. Phase 14-02 observed exactly one
check run (`security / Placeholder`) when the called workflow had exactly one job, and a live read of
`commits/fbe0071.../check-runs` performed during this research returns 12 names, none of which is a bare
`security`. The required-check list is **five** names, all from app `github-actions` (`integration_id`
**15368**). **Second, this repository cannot safely require those checks on its own `main`.** Its
`fixtures/` directory exists to make every scanner fire — 17-05 measured Checkov 14, Trivy image 56,
Semgrep 3, gitleaks 9, tflint 3 — so in blocking mode all five checks go red on every PR. Requiring them
here, with a ruleset that reports `bypass_actors: []` and `current_user_can_bypass: never`, would lock
`main` against every PR including the revert.

The recommended shape resolves the mode **once** at workflow level and applies it uniformly to the eleven
existing `# D-04` lines, so the semantics live in one place. The hidden cost D-04's "just flip the flag"
framing conceals is that three SCA scan steps carry an `if:` guard *without* a status function — GitHub
applies an implicit `success()` to those, so once an earlier step fails hard the npm-audit, pip-audit and
tflint steps skip, while their `always()`-guarded verify steps still run and fail on an unmatched glob.
Those three `if:` lines need `always() &&` prepended as part of this phase.

**Primary recommendation:** Declare `gate_mode` as an un-defaulted `workflow_call` string input; resolve
it once at workflow level with `env: GATE_MODE: ${{ inputs.gate_mode || vars.GATE_MODE || 'report-only' }}`;
replace all eleven `continue-on-error: true  # D-04` lines with
`continue-on-error: ${{ env.GATE_MODE == 'report-only' }}  # D-04 / Phase 18`; prepend `always() &&` to
the three guarded SCA scan steps; and write CICD-04 guidance around a read-modify-write `PUT` to
ruleset `14243983` that adds `required_status_checks` (five contexts, `integration_id: 15368`) **and** a
`pull_request` rule, while explicitly recommending this repo's own committed caller stay `report-only`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Declaring the gate flag's contract (name, type, default) | Called workflow (`security.yml`, `on.workflow_call.inputs`) | — | The reusable workflow is the API surface; an input is the only typed, actionlint-validated contract a caller can be checked against. |
| Resolving the effective mode from input + repo variable + default | Called workflow, workflow-level `env` | — | `env` at workflow level is the only scope that can see `inputs` and `vars` simultaneously and be read by every step in every job. Resolving once prevents eleven divergent expressions. |
| Applying the mode to pass/fail | Called workflow, step-level `continue-on-error` | — | D-04 locks this. The tools' native exit codes already encode "finding vs clean"; `continue-on-error` is purely the tolerate/don't-tolerate switch. |
| Supplying the mode value (this repo) | Caller workflow (`pr-security.yml`, `with:`) | — | An in-repo literal is deterministic and immune to both the empty-string trap and fork-PR `vars` unavailability. |
| Supplying the mode value (copy-paste / external consumer) | GitHub repo settings (`vars.GATE_MODE`) | Called workflow `env` chain | Docs confirm a called workflow reads the *caller repo's* variables, so no YAML edit is needed by the consumer. |
| Converting a red check into a blocked merge | GitHub repository ruleset (`required_status_checks`) | GitHub UI (Settings → Rules) | Workflow YAML cannot make a check required; this is repository configuration, outside the workflow entirely. This split is exactly why D-07's sequencing matters. |
| Preventing direct-push bypass | GitHub repository ruleset (`pull_request` rule) | — | ADR-002 (Accepted) requires it; `required_status_checks` alone does not force a PR. |

## Project Constraints (from CLAUDE.md)

| Directive | Effect on this phase |
|-----------|----------------------|
| This is a **reference documentation project**, not buildable software; primary artifact is `docs/development-security-stack-option-1.md` | The workflow lives in `repos/security-platform/` (a reference implementation). Documentation deliverables are first-class, not an afterthought. |
| Preserve ASCII architecture diagrams and the 4-phase layered structure | Any edit to the blueprint's Phase 2 section must not disturb diagrams or the phase headings. |
| Preserve tool coverage matrices and the security tools comparison table | Do not restructure those tables while adding gate-mode text. |
| **`docs/adr/` records are append-only** — add new records as new files, don't modify accepted ones | ADR-001 and ADR-002 must NOT be edited. Record D-01..D-07 and this research's corrections as a **new ADR-017**, following how Phase 16 added ADR-015 and Phase 17 added ADR-016. Add the ADR-017 row to `docs/adr/README.md`'s index table. |
| (Rules) `defensive-protocol-v2-anti-slop.md` — never set the executable bit; invoke scripts as `bash script.sh` | Applies if this phase adds any helper script for ruleset setup. |
| (Rules) Irreversible actions require explicit confirmation | Applying a required-status-check ruleset to `main` is effectively irreversible-by-self (see Pitfall P-06) and must be a `checkpoint:human-verify`, never an autonomous `gh api` call. |

## Standard Stack

No packages are installed by this phase. The "stack" is the tools already present on this machine that
gate and verify the change.

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `actionlint` | 1.7.12 | Static validation of workflow YAML, expression **type checking**, and caller-vs-callee input validation | The only local tool that catches `continue-on-error: <string>` and undeclared `with:` keys before a push. `[VERIFIED: local run]` |
| `yamllint` | 1.37.1 | YAML style gate; product repo's pre-commit hook | Already the product repo's convention (`-d relaxed`, per STATE.md Phase 14-01 decision). `[VERIFIED: local run]` |
| `gh` | 2.100.0 | Reading check-run names/app IDs; reading and writing rulesets; setting repo variables | Authenticated as `OttawaCloudConsulting` with `repo` + `workflow` scopes and `admin: true` on the target repo. `[VERIFIED: gh auth status]` |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `gh variable set` | in gh 2.100.0 | Set `GATE_MODE` at repo/org/environment level | Documenting the copy-paste consumption mode. `[VERIFIED: gh variable set --help]` |
| `gh ruleset` | in gh 2.100.0 | `check` / `list` / `view` only | **Read-only.** Cannot create or edit a ruleset — scripted setup must use `gh api`. `[VERIFIED: gh ruleset --help]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Repository **rulesets** (`/repos/{o}/{r}/rulesets`) | Classic branch protection (`/repos/{o}/{r}/branches/main/protection`) | The repo already has an active ruleset (`Default`, id `14243983`) and classic protection returns **404 "Branch not protected"**. STATE.md (Phase 14-02) explicitly records that 404 as a *false negative that must never be used as evidence*. Use rulesets; use `rules/branches/main` for verification. `[VERIFIED: live gh api]` |
| Workflow-level `env` resolution chain | Per-step `${{ inputs.gate_mode == 'report-only' }}` on all 11 lines | Per-step works and actionlint accepts it, but repeats the fallback semantics 11 times and gives the copy-paste (`vars`) mode nowhere to plug in. One resolution point is strictly easier to audit. |
| Workflow-level `env` resolution chain | `default: ${{ vars.GATE_MODE \|\| 'report-only' }}` on the input itself (actionlint-accepted; `on.workflow_call.inputs.<id>.default` permits `github, inputs, vars`) | Elegant and self-documenting, but an explicitly-passed empty string still suppresses the default (see P-01). The two compose — use the `env` chain as the load-bearing mechanism; the expression default is optional belt-and-braces. |
| Flipping `continue-on-error` (D-04, locked) | A terminal per-job "gate" step reading back `steps.*.outcome` | Would avoid the skipped-step problem in P-03 entirely, but **contradicts locked D-04**. Recorded only so the planner knows the alternative was considered and rejected on decision grounds, not technical ones. |

**Installation:** None. No package is added, removed, or upgraded by this phase.

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** No npm, PyPI, or crates dependency is
added by either the workflow change or the documentation change. `slopcheck` was therefore not run, and
no `[SLOP]`/`[SUS]` dispositions exist to report.

The only version-pinned artifacts touched are existing SHA-pinned actions in `security.yml`, none of
which this phase changes. If the planner adds any new action (none is needed), ADR-004's SHA-pin +
trailing-version-comment convention applies.

## Architecture Patterns

### System Architecture Diagram

```
 CONFIGURATION SOURCES (per consuming repo — no YAML edit needed for the vars path)
 ┌──────────────────────────────┐      ┌──────────────────────────────────┐
 │ Caller YAML `with:` literal  │      │ GitHub repo variable GATE_MODE   │
 │  (this repo's pr-security)   │      │  (Settings → Actions → Variables)│
 └──────────────┬───────────────┘      └────────────────┬─────────────────┘
                │ inputs.gate_mode                       │ vars.GATE_MODE
                │                                        │  ← resolves to the
                │                                        │    CALLER repo's vars
                ▼                                        ▼
        ┌────────────────────────────────────────────────────────┐
        │  security.yml  ·  workflow-level env  (ONE resolution)  │
        │  GATE_MODE = inputs.gate_mode                          │
        │           || vars.GATE_MODE                            │
        │           || 'report-only'          ← implements D-03  │
        └───────────────────────────┬────────────────────────────┘
                                    │ env.GATE_MODE  (string)
          ┌──────────┬──────────┬───┴──────┬───────────┬──────────┐
          ▼          ▼          ▼          ▼           ▼          ▼
      ┌───────┐ ┌───────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐
      │ sast  │ │  iac  │ │   sca   │ │container│ │ secrets │ │ validate │
      │ 1 stp │ │ 1 stp │ │ 6 steps │ │  1 stp  │ │ 2 steps │ │  value   │
      └───┬───┘ └───┬───┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬─────┘
          │         │          │           │           │           │
          └─────────┴──────────┴─ 11 × continue-on-error: ─┴───────┘
                                  ${{ env.GATE_MODE == 'report-only' }}
                                              │
          report-only ──────────┐             │           ┌────── blocking
                                ▼             ▼           ▼
                        tolerate → job     decide    do NOT tolerate →
                        concludes SUCCESS            job concludes FAILURE
                                │                            │
                                │  (SARIF + artifact steps carry `if: always()`
                                │   and still run in BOTH modes — ADR-001 holds)
                                ▼                            ▼
                  ┌──────────────────────────────────────────────────┐
                  │  5 check runs, app github-actions (id 15368):    │
                  │   security / SAST — Semgrep CE                   │
                  │   security / IaC — Checkov                       │
                  │   security / SCA — Trivy Filesystem              │
                  │   security / Container — Trivy Image             │
                  │   security / Secrets — Gitleaks                  │
                  │  (the `security` caller job emits NO check run)  │
                  └───────────────────────┬──────────────────────────┘
                                          │ context name match (byte-exact)
                                          ▼
                  ┌──────────────────────────────────────────────────┐
                  │ Repository ruleset 14243983 "Default" on main    │
                  │  rules: deletion, non_fast_forward   ← preserve!  │
                  │       + required_status_checks (5 contexts)      │
                  │       + pull_request              ← ADR-002      │
                  └───────────────────────┬──────────────────────────┘
                                          ▼
                                  MERGE BLOCKED / ALLOWED
```

### Recommended Project Structure

No new source tree. Files touched:

```
repos/security-platform/.github/workflows/
├── security.yml        # + on.workflow_call.inputs.gate_mode
│                       # + workflow-level env: GATE_MODE
│                       # ~ 11 × continue-on-error lines  (D-04 flip points)
│                       # ~ 3  × if: lines gain `always() &&`  (P-03)
│                       # + 1  × gate_mode validation step (recommended)
└── pr-security.yml     # + with: gate_mode: <literal>   (job name `security` FROZEN)

docs/
├── adr/adr017-configurable-gate-mode-and-required-checks.md   # NEW (append-only rule)
├── adr/README.md                                              # + index row for ADR-017
└── development-security-stack-option-1.md                     # ~ correct the Phase 2
                                                               #   required-check names (L2019-2028)
```

### Pattern 1: Resolve the mode once, at workflow level

**What:** Declare the input with **no `default:`**, then resolve input → repo variable → literal default
in a single workflow-level `env` entry.

**When to use:** Always, for this phase. It is the only shape that makes D-03's default hold for *both*
consumption modes without repeating the fallback logic eleven times.

**Why no `default:` on the input:** a `workflow_call` string input with no default is `""`
`[CITED: docs.github.com — "If a default value is not specified, inputs default to false for booleans, 0
for numbers, and "" for strings"]`. `""` is falsy in GitHub Actions expressions, so the `||` chain fires
and `vars.GATE_MODE` gets consulted. Setting `default: report-only` would make `inputs.gate_mode` always
truthy and the `vars` path would become dead code.

```yaml
# Source: syntax accepted by actionlint 1.7.12 + yamllint -d relaxed (local run, 2026-09-11)
on:
  workflow_call:
    inputs:
      gate_mode:
        description: >-
          "blocking" or "report-only". Omit to fall back to the caller repo's
          GATE_MODE variable, then to "report-only" (D-03).
        required: false
        type: string

# Workflow-level env is the ONLY scope that sees both `inputs` and `vars`.
# [CITED: Context availability table — env: "github, secrets, inputs, vars"]
env:
  GATE_MODE: ${{ inputs.gate_mode || vars.GATE_MODE || 'report-only' }}
```

### Pattern 2: One uniform flip per existing `# D-04` line

**What:** Every one of the eleven existing lines becomes the same expression. Use `== 'report-only'`, not
`!= 'blocking'`.

**Why `== 'report-only'`:** it **fails closed**. A typo (`reportonly`, `report_only`) yields `false`,
`continue-on-error` is off, and the job goes red — loud and safe. `!= 'blocking'` fails *open*: the same
typo silently leaves the repo un-gated while branch protection reports green, which is precisely the
failure mode CICD-06 exists to prevent. Note GitHub Actions `==` is case-insensitive for strings, so
`Blocking` and `blocking` compare equal `[ASSUMED]`; casing is therefore not the risk — misspelling is.

```yaml
# Before (all 11 occurrences)
        continue-on-error: true          # D-04

# After
        continue-on-error: ${{ env.GATE_MODE == 'report-only' }}   # D-04 / Phase 18 CICD-06
```

**The eleven flip points** in `repos/security-platform/.github/workflows/security.yml`
`[VERIFIED: grep -n "continue-on-error: true.*# D-04"]`:

| Line | Job | Step |
|------|-----|------|
| 47 | `sast` | Run Semgrep |
| 182 | `iac` | Run Checkov |
| 346 | `sca` | Run Trivy filesystem scan (JSON for retention) |
| 366 | `sca` | Run Trivy filesystem scan (SARIF for code scanning) |
| 441 | `sca` | SCA-01 — npm audit |
| 504 | `sca` | SCA-02 — pip-audit |
| 569 | `sca` | SCA-03 — tflint (SARIF) |
| 575 | `sca` | SCA-03 — tflint (human-readable log) |
| 738 | `container` | Run Trivy image scan |
| 866 | `secrets` | Run Gitleaks (SARIF) |
| 873 | `secrets` | Run Gitleaks (JSON) |

Do **not** touch the `continue-on-error: true  # ADR-001: upload failures must not block` lines on SARIF
and artifact upload steps. ADR-001 (Accepted, append-only) explicitly retains those: *"`continue-on-error:
true` is retained only on SARIF upload steps and artifact upload steps, where a failure should not block a
merge — those steps are reporting infrastructure, not enforcement."* Conditioning them on `gate_mode`
would violate an accepted ADR.

### Pattern 3: Caller threading

**What:** `pr-security.yml`'s frozen `security` job gains a `with:` block. `jobs.<job_id>.with.<with_id>`
permits `github, needs, strategy, matrix, inputs, vars` — and **not `secrets`**
`[CITED: docs.github.com Context availability]`.

```yaml
jobs:
  security:
    name: security          # FROZEN — do not rename
    permissions:
      contents: read
      security-events: write
      actions: read
    uses: ./.github/workflows/security.yml
    with:
      # For THIS repo: a literal. Deterministic, immune to the empty-string
      # trap (P-01) and to fork-PR vars unavailability (Q3).
      gate_mode: report-only
      #
      # For a copy-paste consumer that prefers a repo variable, the `with:`
      # line can be omitted ENTIRELY — the callee's env chain reads
      # vars.GATE_MODE from the CALLER's repository. Do NOT write
      #   gate_mode: ${{ vars.GATE_MODE }}
      # — an unset variable yields "" and SUPPRESSES the default (P-01).
      # If a with: line is wanted anyway, it must carry its own fallback:
      #   gate_mode: ${{ vars.GATE_MODE || 'report-only' }}
```

### Pattern 4: Required checks via read-modify-write of the existing ruleset

**What:** `PUT /repos/{owner}/{repo}/rulesets/{id}` **replaces** the ruleset. The request body must carry
the existing `deletion` and `non_fast_forward` rules or they are silently dropped.

Live state of ruleset `14243983` `[VERIFIED: gh api repos/OttawaCloudConsulting/security-platform/rulesets/14243983]`:

```json
{"id":14243983,"name":"Default","target":"branch","enforcement":"active",
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},
 "rules":[{"type":"deletion"},{"type":"non_fast_forward"}],
 "bypass_actors":[],"current_user_can_bypass":"never"}
```

See §Code Examples for the full read-modify-write recipe.

### Pattern 5: Validate the flag value explicitly

**What:** Add one cheap step per job (or one shared early step) that rejects any `GATE_MODE` value outside
the enum. Without it, D-02's "string enum" is a convention, not a constraint — GitHub does not validate
`type: string` input values against a list. (`type: choice` exists for `workflow_dispatch` only, not for
`workflow_call` `[ASSUMED]`.)

```yaml
      - name: Validate gate_mode
        run: |
          case "${GATE_MODE}" in
            blocking|report-only) echo "gate_mode=${GATE_MODE}" ;;
            *) echo "invalid gate_mode: '${GATE_MODE}' (expected blocking|report-only)"; exit 1 ;;
          esac
```

Accepted by `actionlint` and `yamllint -d relaxed` `[VERIFIED: local run]`. `env.GATE_MODE` is available
to `run:` as the shell variable `$GATE_MODE` because workflow-level `env` is exported to every step.

### Anti-Patterns to Avoid

- **`continue-on-error: ${{ inputs.gate_mode }}`** — a bare string. actionlint rejects it:
  `type of expression must be bool but found type string [expression]` `[VERIFIED: local actionlint probe]`.
  The value must be a boolean-valued *expression*, not a string that looks boolean.
- **`with: gate_mode: ${{ vars.GATE_MODE }}`** with no `||` fallback — the empty-string trap (P-01).
- **Conditioning the ADR-001 upload/artifact `continue-on-error` lines on `gate_mode`** — violates an
  accepted, append-only ADR and would make a transient SARIF-upload hiccup block a merge.
- **Requiring the six `github-advanced-security` code-scanning checks** — out of scope per D-06, and
  17-07 observed the `Checkov` code-scanning check concluding `failure` while the PR merged. Requiring it
  would have blocked that PR.
- **Building the required-check list from `code-scanning/analyses`** — the two endpoints disagree on case
  (`checkov` vs `Checkov`, `Gitleaks` vs `gitleaks`). Branch protection matches the **check-run** name
  (17-07 hand-forward #5).
- **Using `gh ruleset` to write** — it is read-only in gh 2.100.0.
- **Using classic `branches/main/protection` as evidence of anything** — it 404s on this repo by design.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Deciding pass/fail from findings | A parser that reads each tool's JSON and counts results | Each tool's existing native exit code + `continue-on-error` | D-04 locks this, and Phase 15–17 already tuned every flag (`--error`, `soft_fail: false`, `--exit-code 1`, tflint's exit 2). A hand-rolled counter would need per-tool schema knowledge and would re-open the pip-audit-has-no-severity problem. |
| Making a check block a merge | A job that calls the merge API, or a bot that comments/blocks | Repository ruleset `required_status_checks` | Server-side, unbypassable, and the mechanism ADR-002 already mandates. Anything workflow-side can be bypassed by a direct push. |
| Boolean-ising the mode string | `fromJSON(env.X)` gymnastics or a `jq` step | A direct comparison `${{ env.GATE_MODE == 'report-only' }}` | The comparison already yields a boolean; actionlint type-checks it. Extra indirection only adds failure modes. |
| Discovering check-run names | Reading job `name:` values out of the YAML and reconstructing the string | `gh api repos/{o}/{r}/commits/{sha}/check-runs` | The prefix comes from the *caller's job id*, the suffix from the *callee's job name*, and the em dash is U+2014. Reconstructing by hand is how you get a required check that never matches. |
| Enumerating the code-scanning checks | Counting SARIF categories | Enumerating `tool.driver.name` values | 17-07 hand-forward #6: the rule is per-driver, not per-category, and the count misleads (`Trivy` appears once for two categories; `tflint-errors` is a second driver in one file). |

**Key insight:** every enforcement primitive this phase needs already exists and is already tuned. The
phase's work is *routing a flag* and *writing accurate configuration guidance* — the moment a task starts
parsing scanner output or reimplementing a gate, it has left the phase's scope.

## Runtime State Inventory

This phase is not a rename or migration, but it *does* change runtime state outside git (repository
settings). Inventory of non-git state:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — verified: no datastore is touched; scan reports are per-run artifacts with 90-day retention already configured in Phase 17. | none |
| Live service config | **GitHub repository ruleset `14243983` ("Default") on `OttawaCloudConsulting/security-platform`** — lives in GitHub, not in git. Currently `rules: [deletion, non_fast_forward]`, `bypass_actors: []`. CICD-04 changes this. `[VERIFIED: gh api]` | Documented `gh api` recipe + `checkpoint:human-verify` before any write. Must be read-modify-write (P-05). |
| OS-registered state | None — verified: no scheduler, daemon, or local service is involved. | none |
| Secrets/env vars | **Repository variable `GATE_MODE`** (new, optional) — set in GitHub Settings, not in git. No *secret* is involved; `secrets` context is explicitly unavailable in `jobs.<job_id>.with` anyway. | Document `gh variable set GATE_MODE --body <value> -R <owner/repo>`; none required for this repo if the caller uses a literal. |
| Build artifacts | None — verified: no compiled or installed artifact carries the flag. The five check-run *names* are unchanged by this phase, so no required-check list can go stale as a result of it. | none |

## Common Pitfalls

### P-01: The empty-string input suppresses the declared default

**What goes wrong:** `with: gate_mode: ${{ vars.GATE_MODE }}` with `GATE_MODE` unset passes `""`. The
input is then considered *provided*, so the workflow's `default:` is **not** applied. D-03 silently fails
and `inputs.gate_mode` is `""`.
**Why it happens:** the runner distinguishes "omitted" from "provided-as-empty" when deciding whether to
apply a default; an expression that evaluates to empty counts as provided.
`[CITED: github.com/actions/runner#2907, github.com/github/docs#31513]`
**How to avoid:** never pass a bare `vars.*` into `with:`. Either omit the `with:` line entirely (letting
the callee's `||` chain run) or write `${{ vars.GATE_MODE || 'report-only' }}`. The workflow-level `env`
chain in Pattern 1 makes the whole class of failure harmless because `""` is falsy there too.
**Warning signs:** a run where `gate_mode` echoes as blank, or the Pattern 5 validation step fails with
`invalid gate_mode: ''`.

### P-02: `continue-on-error` will not accept a string-typed expression

**What goes wrong:** `continue-on-error: ${{ inputs.gate_mode }}` looks plausible and is rejected.
**Why it happens:** the key is typed boolean; a `string` expression is a type error.
**How to avoid:** always write a comparison. actionlint catches this locally:
`type of expression must be bool but found type string [expression]` `[VERIFIED: local actionlint probe]`.
**Warning signs:** actionlint exit 1 on the file; if it reaches GitHub, a workflow-level parse failure.

### P-03: Blocking mode skips three SCA scan steps and makes their verify steps fail spuriously

**What goes wrong:** when `continue-on-error` is `false` and the Trivy filesystem step (line 346) fails on
findings, the job halts. Three later scan steps carry an `if:` **without** a status function —
`if: steps.npm.outputs.found == 'true'` (line 440), `if: steps.py.outputs.found == 'true'` (503),
`if: steps.tf.outputs.found == 'true'` (568) — and GitHub applies an implicit `success()` to such
conditions, so all three **skip**. Their verify steps (`if: always() && steps.X.outputs.found == 'true'`)
still run, find no `npm-audit-*.json` / `pip-audit-*.json` / `tflint.sarif`, and fail with a
`FileNotFoundError` traceback that reads like an infrastructure fault rather than "the scan never ran".
**Why it happens:** D-04's framing ("just flip the flag") is true for the *gate* but not for *report
completeness* — `continue-on-error: true` was doing double duty as a step-sequencing guarantee.
**How to avoid:** prepend `always() &&` to those three `if:` lines so all four SCA scanners always run and
all four reports are always produced. Verify against the *entire* `sca` job, not just the first step.
**This is a deliberate behaviour change in report-only mode too:** today those three steps also skip if an
earlier *non-tolerated* step (e.g. "Verify Trivy filesystem SARIF upload landed") fails; after the change
they will run. That is an improvement — more complete reports — but it is a change, and the planner should
record it as such rather than let it surface as an unexplained diff.
**Scope note:** the gate verdict is unaffected either way (the job is red in both cases). The damage is to
report completeness and to error-message honesty.
**Warning signs:** a blocking-mode run where the SCA job's log shows "npm audit report is an error object"
or a Python traceback, with the actual scanner step greyed out as skipped.

### P-04: Nothing else in the job breaks — verify this, don't assume it

**What goes wrong (or rather, doesn't):** every SARIF upload, artifact upload, "Show scan output files"
and verify step in all five jobs already carries `if: always()` (or `always() && <guard>`)
`[VERIFIED: grep of all five jobs]`. They therefore still run after a hard scan failure, so ADR-001's
reporting guarantee and CICD-02/CICD-03's SARIF and retention guarantees survive blocking mode intact.
**How to avoid regressing it:** the plan should carry an explicit verification that in a blocking-mode run
with findings, all five artifacts and all SARIF uploads still land. Do not infer it from the report-only
run.
**Style note:** `always()` also runs on cancellation; `!cancelled()` is generally preferred. The repo's
established convention is `always()` and consistency wins here — do not mass-convert as a side quest.

### P-05: `PUT /rulesets/{id}` replaces the whole ruleset

**What goes wrong:** a `PUT` carrying only `required_status_checks` silently deletes the existing
`deletion` and `non_fast_forward` protections on `main`.
**How to avoid:** read-modify-write. `GET` the ruleset, append rules to the existing `rules` array, `PUT`
the merged document. See §Code Examples.
**Warning signs:** `gh api repos/$SLUG/rules/branches/main` afterwards shows fewer rule types than the
three-or-four expected.

### P-06: Requiring these checks on THIS repo locks `main` — including against the revert

**What goes wrong:** `fixtures/` exists specifically to make every scanner fire. 17-05 measured Checkov 14,
Trivy image 56, Semgrep 3 (as `Semgrep OSS`), gitleaks 9, tflint 3 findings on a normal PR. In blocking
mode **all five checks go red on every PR**. The ruleset reports `bypass_actors: []` and
`current_user_can_bypass: "never"` `[VERIFIED: gh api]` — rulesets do **not** auto-exempt repo admins. Add
required checks here while blocking is on and no PR can merge, including a PR that reverts the change; the
only exit is editing the ruleset through the API or UI.
**How to avoid:** keep this repo's committed caller at `gate_mode: report-only`. Demonstrate blocking on a
short-lived PR branch with an explicit `with: gate_mode: blocking`, observe the five checks turn red, then
revert. Treat "add required checks to this repo's ruleset" as an operator decision behind a
`checkpoint:human-verify`, not an autonomous step. If it is done anyway, add a bypass actor (repo admin
role) *first*.
**Warning signs:** a PR showing five red required checks and a disabled merge button with no green path.

### P-07: A required check that never runs blocks merges forever

**What goes wrong:** GitHub treats a required context with no matching check run as *pending*, not
*passing*. A context name with the wrong em dash, wrong case, or a job that got renamed produces a
permanently-pending required check.
**How to avoid:** copy the five names **byte-exact** from `commits/{sha}/check-runs` output, never retype
them. The em dash is U+2014 (`—`), not a hyphen. Pass the payload via
`gh api --input file.json`, never as an inline shell string. Pin `integration_id: 15368` so only the
GitHub Actions app can satisfy the context. This is also why `pr-security.yml`'s `security` job name and
`security.yml`'s five job `name:` values are frozen — including the deliberately-inaccurate
`SCA — Trivy Filesystem`.
**Warning signs:** a required check stuck at "Expected — Waiting for status to be reported".

### P-08: The blueprint's existing required-check names are wrong

**What goes wrong:** `docs/development-security-stack-option-1.md` (~L2019–2028) instructs the reader to
*"add each security workflow job as a required check: `sast`, `iac`, `sca`, `container`, `secrets`"*.
Those are **job IDs**, not check-run names, and they omit the `security / ` caller prefix and the display
names entirely. Following that text produces five permanently-pending required checks (P-07).
**How to avoid:** correct that passage in place as part of CICD-04's deliverable. CLAUDE.md's append-only
rule covers `docs/adr/`, not the blueprint — the blueprint is explicitly editable, subject to preserving
diagrams and matrices.
**Warning signs:** none at authoring time; this only bites a reader who follows the doc.

### P-09: `required_status_checks` alone does not require a pull request

**What goes wrong:** ruleset `14243983` has **no `pull_request` rule** today, so direct pushes to `main`
are permitted. ADR-002 (Accepted) requires *"require pull requests before merging to `main`… and block
direct pushes"*, and notes that ADR-001's gate *"has no enforcement effect whatsoever without branch
protection"*.
**How to avoid:** CICD-04 guidance should present `required_status_checks` **and** `pull_request` together,
and state why: without the latter, a developer with write access bypasses the entire gate with one push.
**Warning signs:** `gh api repos/$SLUG/rules/branches/main` lists `required_status_checks` but no
`pull_request`.

## Code Examples

### Read the five byte-exact check contexts and their app id

```bash
# Source: live run 2026-09-11 against the Phase 17 head SHA
SLUG=OttawaCloudConsulting/security-platform
SHA=fbe0071d6934d19524f5bf9345e91396080fa882

gh api "repos/$SLUG/commits/$SHA/check-runs" \
  --jq '.check_runs[] | select(.app.slug == "github-actions") | "\(.name)\t\(.app.id)"'
```

Observed output (`total_count: 12` overall; these five are the `github-actions` ones):

```
security / IaC — Checkov                    15368
security / SAST — Semgrep CE                15368
security / Secrets — Gitleaks               15368
security / Container — Trivy Image          15368
security / SCA — Trivy Filesystem           15368
```

Other apps present, for completeness: `github-advanced-security` (id **57789**) supplies
`tflint-errors`, `tflint`, `Semgrep OSS`, `Checkov`, `Trivy`, `gitleaks`; `gitguardian` (id **46505**)
supplies `GitGuardian Security Checks`. **None of these is in scope per D-06.** There is no check run
named `security`.

### Read-modify-write the ruleset to add required checks + PR requirement

```bash
SLUG=OttawaCloudConsulting/security-platform
RS=14243983

# 1. READ — capture current state (preserves deletion + non_fast_forward)
gh api "repos/$SLUG/rulesets/$RS" > /tmp/ruleset-before.json

# 2. MODIFY — build the PUT body from the existing document, never from scratch
python3 - <<'PY'
import json
doc = json.load(open('/tmp/ruleset-before.json'))
contexts = [
    "security / SAST — Semgrep CE",
    "security / IaC — Checkov",
    "security / SCA — Trivy Filesystem",
    "security / Container — Trivy Image",
    "security / Secrets — Gitleaks",
]
rules = [r for r in doc["rules"]
         if r["type"] not in ("required_status_checks", "pull_request")]
rules.append({
    "type": "required_status_checks",
    "parameters": {
        "do_not_enforce_on_create": False,
        "strict_required_status_checks_policy": False,
        "required_status_checks": [
            {"context": c, "integration_id": 15368} for c in contexts
        ],
    },
})
rules.append({
    "type": "pull_request",            # ADR-002
    "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": False,
        "require_code_owner_review": False,
        "require_last_push_approval": False,
        "required_review_thread_resolution": False,
    },
})
body = {
    "name": doc["name"],
    "target": doc["target"],
    "enforcement": doc["enforcement"],
    "conditions": doc["conditions"],
    "bypass_actors": doc.get("bypass_actors", []),
    "rules": rules,
}
json.dump(body, open('/tmp/ruleset-after.json', 'w'), ensure_ascii=False, indent=2)
PY

# 3. WRITE — --input avoids any shell mangling of the U+2014 em dash
gh api --method PUT "repos/$SLUG/rulesets/$RS" --input /tmp/ruleset-after.json

# 4. VERIFY — rules/branches/main is the authoritative read.
#    NEVER use branches/main/protection: it 404s on this repo by design (STATE.md, 14-02).
gh api "repos/$SLUG/rules/branches/main" --jq '.[].type'
gh api "repos/$SLUG/rulesets/$RS" \
  --jq '.rules[] | select(.type=="required_status_checks")
        | .parameters.required_status_checks[] | .context'
```

`[CITED: docs.github.com/en/rest/repos/rules — required_status_checks and pull_request rule schemas]`
`[VERIFIED: live GET of rulesets/14243983 confirms the document shape]`
`[ASSUMED: the exact set of pull_request parameters GitHub treats as required on PUT — schema says several are required; run the PUT behind a checkpoint and read the error body if it 422s]`

### UI equivalent (for the written guidance)

Settings → Rules → Rulesets → **Default** → Edit → Branch rules:

- ☑ **Require a pull request before merging** (approvals may stay at 0 for a solo practice)
- ☑ **Require status checks to pass** → *Add checks* → search and select each of the five
  `security / …` names, source **GitHub Actions**
- Leave *Require branches to be up to date before merging* (`strict`) **off** unless re-run churn is
  acceptable — with five jobs, `strict: true` forces a re-run on every base-branch advance.
- Keep `deletion` and `non_fast_forward` ticked (they are already on).

> A check only appears in the "Add checks" picker if GitHub has seen it recently (reported within roughly
> the last week) `[ASSUMED]`. If a name is missing, open a PR first so the checks report, then add them —
> which is exactly D-07's ordering.

### Copy-paste consumption mode (the `vars` path)

```bash
# In the CONSUMING repository — no YAML edit required.
gh variable set GATE_MODE --body blocking -R <owner>/<repo>
gh variable get GATE_MODE -R <owner>/<repo>
```

`[VERIFIED: gh variable set --help, gh 2.100.0]`. Name it `GATE_MODE`: variable names are case-insensitive
when referenced and GitHub stores them uppercase, so `vars.GATE_MODE` and `vars.gate_mode` resolve the same
variable `[CITED: docs.github.com Variables reference]`. Documenting the uppercase form avoids implying two
different variables exist. Names may contain only `[A-Za-z0-9_]`, must not start with a digit, and must not
start with `GITHUB_` `[CITED: same]`.

This works because **"For reusable workflows, the variables from the caller workflow's repository are
used. Variables from the repository that contains the called workflow are not made available to the
caller workflow."** `[CITED: docs.github.com/en/actions/reference/workflows-and-actions/variables]` — the
consumer's `GATE_MODE` reaches `security.yml` even when `security.yml` lives in another repository.

Note the companion limitation, which is why `env:` in the caller is *not* an option:
**"Any environment variables set in an `env` context defined at the workflow level in the caller workflow
are not propagated to the called workflow."**
`[CITED: docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations]`

### Local verification of any candidate YAML before pushing

```bash
cd repos/security-platform
actionlint .github/workflows/security.yml .github/workflows/pr-security.yml   # must exit 0
yamllint -d relaxed .github/workflows/security.yml .github/workflows/pr-security.yml  # must exit 0
```

Both exit 0 on the files as they stand today `[VERIFIED: local run 2026-09-11]` — yamllint emits
line-length **warnings** only, which is the repo's accepted baseline (Phase 14-01, STATE.md). actionlint
requires a git repository in an ancestor directory or it errors with "no project was found".

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Classic branch protection (`branches/{b}/protection`, `contexts: [...]`) | Repository **rulesets** (`/rulesets`, `required_status_checks` with `{context, integration_id}`) | Rulesets GA'd 2023; `required_status_checks.contexts` is marked **deprecated in favour of `checks`** even in the classic API | This repo is already on rulesets. Guidance written against classic protection would not match what an operator sees in Settings → **Rules**, and the classic GET 404s here. |
| `contexts: ["build"]` (name only) | `checks: [{context, app_id}]` / `required_status_checks: [{context, integration_id}]` | Same era | Pinning the app id prevents a third-party app from satisfying a required context with a same-named check. |
| Job-level `continue-on-error` for "experimental" matrix legs | Step-level `continue-on-error` with full expression support (`inputs`, `vars`, `env`, `steps`) | Long-standing; `vars` context added Jan 2023 | The exact capability this phase depends on. The docs' own examples still lead with the matrix case, which is why the step-level expression form looks less official than it is. |

**Deprecated/outdated:**
- `required_status_checks.contexts` (classic API) — use `checks`.
- `gh ruleset create` / `gh ruleset edit` — **never existed**; gh 2.100.0 ships `check`, `list`, `view`
  only. Any plan step assuming a write subcommand will fail.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GitHub Actions `==` string comparison is case-insensitive, so `Blocking` equals `blocking` | Pattern 2 | Low. Pattern 5's validation step rejects any value outside the enum regardless of case handling, so a wrong assumption surfaces loudly rather than silently. |
| A2 | `type: choice` is available only for `workflow_dispatch` inputs, not `workflow_call` | Pattern 5 | Low. If `choice` *is* available for `workflow_call`, it would be a strictly better way to enforce D-02's enum — worth a 2-minute check during planning; the `case` step remains a valid fallback either way. |
| A3 | A check context must have been reported recently to appear in the ruleset UI's "Add checks" picker | Code Examples (UI) | Low. Affects only a parenthetical in the written guidance; the `gh api` path does not depend on the picker. |
| A4 | The exact `pull_request` rule parameter set GitHub requires on `PUT` | Code Examples | Medium. A wrong set 422s. Mitigated by running the PUT behind a `checkpoint:human-verify` and reading the error body; no state is changed by a 422. |
| A5 | `strict_required_status_checks_policy: false` is the right default for a solo practice | Code Examples | Low. `true` only adds re-run churn; it is a documented knob either way. |
| A6 | actionlint acceptance implies GitHub's evaluator accepts the same expressions | Patterns 1–3, 5 | Medium. actionlint is a third-party static checker, not GitHub's runtime. Every pattern here needs one live PR run to confirm — which D-07 step 1 already requires. |

## Open Questions

### Q1 — D-06 says six job-level checks; the evidence says five

- **What we know:** Two independent live observations. (a) Phase 14-02: when the called workflow had a
  single `Placeholder` job, `commits/{sha}/check-runs` returned exactly **one** name,
  `security / Placeholder` — no bare `security`. (b) This research, re-reading the Phase 17 head SHA:
  `total_count: 12`, none named `security`. A caller job that `uses:` a reusable workflow emits check runs
  for the **called workflow's jobs**, prefixed with the caller's job id — not for itself.
- **What's unclear:** nothing technical. D-06's sixth member simply does not exist as a requirable
  context.
- **Recommendation:** require the **five** `security / …` names. Record the correction in ADR-017 with
  both observations cited, so the "six" in CONTEXT.md does not resurface as a discrepancy in verification.
  *Optional alternative, not recommended without user sign-off:* add a real aggregate job to
  `pr-security.yml` (e.g. `gate` with `needs: [security]`, `if: always()`, asserting
  `needs.security.result == 'success'`). That would emit one stable check run, letting branch protection
  reference a single context immune to future job renames. It adds a job to the file that carries the
  FROZEN warning — the *job name* `security` is frozen, not the file, so it is legal, but it is a design
  change beyond D-01/D-06 and belongs to a decision, not to research.

### Q2 — D-07 step 1's "red when seeded" is unobservable in report-only

- **What we know:** D-04 defines report-only as "no finding turns a scan step red". Therefore in
  report-only the five checks are green whether or not the fixtures fire. The only red available in
  report-only comes from the intolerant infra-verify steps (SARIF/artifact landing checks), which is a
  different signal entirely.
- **What's unclear:** whether the CONTEXT author meant "red when the *upload* verification fails".
- **Recommendation:** write the guidance as: (1) report-only — confirm all five checks *appear* on the PR
  and conclude green; (2) flip to blocking on a PR that carries seeded findings — confirm all five turn
  red; (3) then add them as required. Keep D-07's central warning verbatim: doing (3) before (2) leaves
  merges un-gated while the settings say otherwise.

### Q3 — Is `vars` populated for `pull_request` runs from a fork?

- **What we know:** an unset variable yields `""` `[CITED: docs]`. Community sources state configuration
  variables carry the same fork restrictions as secrets and that `vars.*` is "unlikely to be present when
  run in forks" `[LOW: community discussion #44322, actions/runner#2907 commentary]`. The official
  Variables reference says nothing about forks.
- **What's unclear:** whether a fork PR sees the base repo's variables at all.
- **Why it matters:** if not, a fork PR resolves `GATE_MODE` to `""` → falls back to `report-only` → all
  five checks go green regardless of findings → a required-check gate is satisfied by an un-gated run.
  That is a genuine bypass for a public repository, and `security-platform` is public
  `[VERIFIED: gh api .visibility == "public"]`.
- **Recommendation:** do not resolve this by reasoning. (a) For this repo, use a **literal** in
  `pr-security.yml`'s `with:` — deterministic and fork-safe; the `vars` path is documented as the Phase 20
  consumer mechanism. (b) Record the limitation explicitly in the branch-protection guidance. (c) Hand the
  empirical check to Phase 19 (VAL-01), which already owns end-to-end validation. Do not upgrade this from
  LOW confidence without a measured fork-PR run.

### Q4 — Where does the branch-protection guidance live?

- **What we know:** CLAUDE.md makes `docs/adr/` append-only but leaves the blueprint editable (subject to
  preserving diagrams and matrices). Phase 16 added ADR-015 and Phase 17 added ADR-016 — both new files
  plus an index row in `docs/adr/README.md`. The blueprint already has a branch-protection passage at
  ~L2019–2028 that is factually wrong about check names (P-08).
- **Recommendation:** do both. Correct the blueprint passage **in place** (that is the CICD-04
  user-facing deliverable and it is currently misleading), and add **ADR-017** recording D-01..D-07, the
  D-06 five-not-six correction, the D-07 sequencing correction, and the self-lockout constraint. This
  matches the established two-artifact pattern and keeps ADR-001/ADR-002 untouched.

### Q5 — Should this repo's own `main` ever get the required checks?

- **What we know:** P-06. With seeded fixtures + blocking + `bypass_actors: []`, `main` locks.
- **Recommendation:** treat as an operator decision behind a `checkpoint:human-verify`. The phase's
  success criteria are satisfiable by *providing working configuration and accurate guidance* (CICD-04's
  wording is "config/guidance provided so scan checks **can be** made required") plus a demonstrated
  blocking run — neither requires permanently gating this repository. If the operator does want it, add a
  bypass actor first.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `actionlint` | Workflow syntax + expression type gate | ✓ | 1.7.12 | `yamllint` alone (weaker — no expression type checking) |
| `yamllint` | Repo's pre-commit YAML convention | ✓ | 1.37.1 | — |
| `gh` | check-run reads, ruleset read/write, variable set | ✓ | 2.100.0 | `curl` + PAT |
| `gh` auth + admin on target repo | Ruleset write | ✓ | `OttawaCloudConsulting`, scopes `gist, read:org, repo, workflow`; repo permissions `admin: true` | — |
| `python3` | Ruleset JSON read-modify-write; existing in-workflow verify steps | ✓ | system python3 | `jq` |
| `gh ruleset` write subcommands | Scripted ruleset edit | ✗ | read-only (`check`/`list`/`view`) | **`gh api --method PUT --input`** — documented above |
| Live GitHub PR run | Confirming expression evaluation and check colours | n/a | requires a push + PR | None — this is inherently a `checkpoint:human-verify` |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** `gh ruleset` write → `gh api`.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `actionlint` (workflow semantics) + `yamllint -d relaxed` (style) + `gh api` read-backs (live state). No unit-test framework applies — this phase produces YAML and Markdown, not code. |
| Config file | none for actionlint; `repos/security-platform/.pre-commit-config.yaml` carries the `yamllint` hook |
| Quick run command | `cd repos/security-platform && actionlint .github/workflows/security.yml .github/workflows/pr-security.yml && yamllint -d relaxed .github/workflows/*.yml` |
| Full suite command | quick run **+** `bash scripts/smoke-scans.sh` (the repo's existing local scanner gate) **+** the live PR checks below |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CICD-06 | `gate_mode` input is declared and typed | static | `actionlint .github/workflows/security.yml` | ✅ |
| CICD-06 | Caller's `with:` matches the callee's declared inputs | static | `actionlint .github/workflows/pr-security.yml` (flags undeclared keys — verified behaviour) | ✅ |
| CICD-06 | All 11 `# D-04` lines are conditioned, none left literal `true` | static | `! grep -n "continue-on-error: true.*# D-04" .github/workflows/security.yml` | ✅ |
| CICD-06 | The 3 guarded SCA scan steps gained `always() &&` | static | `grep -c "if: always() && steps\.\(npm\|py\|tf\)\.outputs\.found" .github/workflows/security.yml` → expect ≥ 3 | ✅ |
| CICD-06 | ADR-001 upload/artifact tolerances untouched | static | `grep -c "continue-on-error: true .*ADR-001" .github/workflows/security.yml` → expect unchanged count (11) | ✅ |
| CICD-06 | report-only: all five checks conclude `success` despite findings | live | `gh api repos/$SLUG/commits/$SHA/check-runs --jq '[.check_runs[]\|select(.app.id==15368)]\|map(.conclusion)'` | ❌ `checkpoint:human-verify` — needs a PR |
| CICD-06 | blocking: all five checks conclude `failure` on the same fixtures | live | same command on a `gate_mode: blocking` PR | ❌ `checkpoint:human-verify` |
| CICD-06 | blocking still uploads all SARIF + all five artifacts (ADR-001 / CICD-02 / CICD-03 hold) | live | `gh run view $RUN --log` + `gh api repos/$SLUG/actions/runs/$RUN/artifacts --jq '.total_count'` → expect 5 | ❌ `checkpoint:human-verify` |
| CICD-06 | An invalid `gate_mode` fails fast and legibly | live or local | Pattern 5 `case` step; locally `GATE_MODE=nonsense bash -c '<case block>'` → exit 1 | ✅ |
| CICD-04 | Guidance names the five contexts byte-exactly | static | `grep -c "security / " docs/<target>.md` → expect 5; diff against the `gh api` output | ✅ |
| CICD-04 | Blueprint's wrong check names (L2019–2028) are corrected | static | `! grep -n "required check: \`sast\`" docs/development-security-stack-option-1.md` (adjust to final wording) | ✅ |
| CICD-04 | Ruleset recipe is non-destructive | static/dry | Run the read-modify-write script against `/tmp/ruleset-before.json` and assert the output still contains `deletion` and `non_fast_forward` — **no network write** | ✅ |
| CICD-04 | ADR-017 exists and is indexed | static | `test -f docs/adr/adr017-*.md && grep -q "ADR-017" docs/adr/README.md` | ✅ |
| CICD-04 | (Optional, operator-gated) required checks actually present | live | `gh api repos/$SLUG/rules/branches/main --jq '.[].type'` | ❌ `checkpoint:human-verify` — see Q5/P-06 |

### Sampling Rate

- **Per task commit:** `actionlint` + `yamllint -d relaxed` on both workflow files (sub-second; both pass
  on today's files, so any failure is attributable to the task).
- **Per wave merge:** add the grep assertions above + the offline ruleset-script dry run.
- **Phase gate:** one live report-only PR and one live blocking PR, both read back via
  `commits/{sha}/check-runs`, before `/gsd:verify-work`.

### Wave 0 Gaps

- None for linting — `actionlint` 1.7.12 and `yamllint` 1.37.1 are installed and both pass on the current
  workflow files, so the gate is already green before any change.
- The only "missing infrastructure" is a **PR on `OttawaCloudConsulting/security-platform`**, which cannot
  be created by a test harness. Plan it as an explicit `checkpoint:human-verify` task, not as an
  automated verification.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No authentication surface is introduced. |
| V3 Session Management | no | — |
| V4 Access Control | **yes** | The ruleset *is* the access control. `bypass_actors: []` + `pull_request` rule + `required_status_checks` enforce least privilege on merges to `main`. The workflow keeps least-privilege `permissions:` blocks unchanged by this phase (`contents: read`, `security-events: write` scoped to the caller job). |
| V5 Input Validation | **yes** | `gate_mode` is external input. GitHub does not validate a `type: string` value against D-02's enum — Pattern 5's `case` step is the validation control. Fail-closed comparison (`== 'report-only'`) is the secondary control. |
| V6 Cryptography | no | No crypto. Note `secrets` context is unavailable in `jobs.<job_id>.with` by design — do not attempt to route anything sensitive through the gate flag. |
| V14 Configuration | **yes** | Required-check contexts must be byte-exact and app-pinned (`integration_id: 15368`); ruleset writes must be read-modify-write. Misconfiguration here silently removes enforcement rather than failing loudly. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Silently un-gated repo — flag typo or unset variable resolves to report-only while branch protection reports green | Tampering / Repudiation | Fail-closed `== 'report-only'` comparison + explicit enum validation step (Pattern 5) + D-07's "verify before requiring" sequencing |
| Fork PR degrades to report-only because `vars` is unavailable | Elevation of Privilege | Literal `with:` value for this repo; limitation stated in guidance; empirical check handed to Phase 19 (Q3) |
| Permanently-pending required check from a mistyped context (em dash, case, rename) | Denial of Service | Copy names byte-exact from `commits/{sha}/check-runs`; `gh api --input` not inline strings; frozen job names |
| Direct push to `main` bypassing the PR gate entirely | Elevation of Privilege | `pull_request` rule alongside `required_status_checks` (ADR-002, P-09) |
| Ruleset `PUT` silently drops `deletion` / `non_fast_forward` | Tampering | Read-modify-write + `rules/branches/main` read-back (P-05) |
| Self-lockout of `main` making the security control itself unrevertable | Denial of Service | Keep this repo report-only; add a bypass actor before requiring; `checkpoint:human-verify` (P-06, Q5) |
| Third-party app satisfying a required context with a same-named check | Spoofing | Pin `integration_id: 15368` on every required context |

## Sources

### Primary (HIGH confidence)

- Context7 `/websites/github_en_actions` — `workflow_call` inputs (`type`, `default`), `jobs.<job_id>.with`,
  `steps[*].continue-on-error`, `vars` context usage
- https://docs.github.com/en/actions/reference/workflows-and-actions/contexts — **Context availability
  table**: `steps[*].continue-on-error` → `github, needs, strategy, matrix, job, runner, env, vars, secrets,
  steps, inputs`; `jobs.<job_id>.with.<with_id>` → `github, needs, strategy, matrix, inputs, vars`;
  workflow-level `env` → `github, secrets, inputs, vars`; `on.workflow_call.inputs.<id>.default` →
  `github, inputs, vars`
- https://docs.github.com/en/actions/reference/workflows-and-actions/variables — "For reusable workflows,
  the variables from the caller workflow's repository are used"; "If a configuration variable has not been
  set, the return value of a context referencing the variable will be an empty string"; naming rules; limits
- https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations —
  caller `env` is not propagated to the called workflow; reusable-workflow limitations
- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax — `workflow_call.inputs`
  defaults (`""` for unspecified strings); `jobs.<job_id>.with`
- https://docs.github.com/en/rest/repos/rules — ruleset create/update schema; `required_status_checks` and
  `pull_request` rule parameters
- https://docs.github.com/en/rest/branches/branch-protection — classic `required_status_checks`
  (`contexts` deprecated in favour of `checks[{context, app_id}]`); recorded as the *rejected* alternative
- **Live `gh api` reads (2026-09-11):** `commits/fbe0071…/check-runs` (12 names, five `github-actions`
  id 15368, no bare `security`); `rulesets/14243983`; `rules/branches/main`;
  `branches/main/protection` → 404
- **Local tool runs (2026-09-11):** `actionlint` 1.7.12 probes A–H; `yamllint -d relaxed`;
  `gh ruleset --help`; `gh variable set --help`; `gh auth status`
- **In-repo primary evidence:** `repos/security-platform/.github/workflows/security.yml` (11 `# D-04`
  lines; three `if:` guards lacking `always()`); `docs/adr/adr001-remove-continue-on-error.md`;
  `docs/adr/adr002-require-branch-protection.md`; `.planning/phases/14-…/14-02-SUMMARY.md`;
  `.planning/phases/16-…/16-05-SUMMARY.md`; `.planning/phases/17-…/17-07-SUMMARY.md`

### Secondary (MEDIUM confidence)

- https://github.com/actions/runner/issues/2907 — "Reusable workflow input with default string is not used
  when the calling input passed an empty string" (corroborated by github/docs#31513)
- https://github.com/github/docs/issues/31513 — "an input that is evaluated to empty will be treated as
  present and suppress your default"

### Tertiary (LOW confidence — flagged for validation)

- https://github.com/orgs/community/discussions/44322 — configuration variables and fork PRs. Community
  discussion only; the official Variables reference is silent. Drives Q3, not a recommendation.

## Metadata

**Confidence breakdown:**

- **Expression / input syntax:** HIGH — every claim traced to the official Context availability table and
  independently accepted by actionlint 1.7.12 locally. Residual risk A6 (actionlint ≠ GitHub's evaluator)
  is retired by the live PR run D-07 already mandates.
- **Check-run names and app id:** HIGH — read live from the API this session, byte-identical across three
  independent phase records (15-05, 16-05, 17-05).
- **D-06 correction (five, not six):** HIGH — two independent live observations, one of them a controlled
  single-job case (14-02) that isolates the variable.
- **Ruleset API shape:** HIGH for the read (live GET) and the `required_status_checks` schema (official
  docs); MEDIUM for the exact `pull_request` parameter set required on PUT (A4).
- **Empty-string default suppression:** MEDIUM — two corroborating upstream issues, no statement in the
  reference docs. The recommended `||` chain is correct regardless of the answer.
- **Fork-PR `vars` availability:** LOW — community sources only. Explicitly routed to Phase 19.
- **Pitfalls:** HIGH for P-01..P-05 and P-07..P-09 (each traced to a file, an API read, or a doc); HIGH for
  P-06 (fixture finding counts measured in 17-05; `bypass_actors: []` read live).

**Research date:** 2026-09-11
**Valid until:** 2026-10-11 (30 days). The GitHub Actions expression surface and the rulesets API are
stable; the five check-run names are frozen by design. Re-verify sooner only if `security.yml`'s job
`name:` values or `pr-security.yml`'s `security` job id change — both are explicitly frozen.

---

*Phase: 18-Configurable Gate Mode and Branch Protection*
*Researched: 2026-09-11*
