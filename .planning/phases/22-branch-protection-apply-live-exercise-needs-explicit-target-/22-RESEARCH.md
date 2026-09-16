# Phase 22: branch-protection `--apply` live exercise — Research

**Researched:** 2026-09-16
**Domain:** GitHub repository rulesets (REST `PUT /repos/{o}/{r}/rulesets/{id}`), required status checks, merge-gate enforcement, irreversible-operation safety design
**Confidence:** HIGH on current live state and on what the existing tooling does; MEDIUM on the one thing that cannot be known without a write (whether GitHub's PUT accepts the merged body — specifically `copilot_code_review` and the `pull_request` parameter set)

---

## Summary

Phase 22 exists to close exactly one hole. The v2.0 milestone audit lists every end-to-end flow
as WIRED except one: **"Blocking gate → required check → merge blocked — ✗ UNVERIFIED — dry-run
only, never applied"** (`.planning/v2.0-MILESTONE-AUDIT.md:156`). ADR-017's "What was NOT
verified" item 4 and ADR-018's item 7 say the same thing in the ADR record:
`scripts/set-required-checks.sh --apply` has never been run against any repository. Everything
around it is proven — the five byte-exact check contexts, the `GATE_MODE` flip changing five
verdicts on a byte-identical tree, the read-modify-write merge that preserves pre-existing rule
types — but nobody has ever *witnessed GitHub refuse a merge* because one of those checks was
required and red.

So the deliverable is **not a successful PUT**. A successful PUT proves the API accepts the body.
The deliverable is a *witnessed refusal*: a pull request whose GraphQL `mergeStateStatus` moves
from `UNSTABLE` (red check, not required, still mergeable) to `BLOCKED` (red check, required,
merge refused), plus the literal text `gh pr merge` emits when it declines. That before/after
pair is the only observation that discriminates "a check is required" from "a check is red."

The phase is "irreversible-ish", not irreversible. The critical insight the planner must build
on: **ruleset administration is not governed by the ruleset.** `bypass_actors: []` and
`current_user_can_bypass: "never"` control *ref updates*, not *ruleset writes*. An operator with
`admin: true` can always PUT the previous document back, even from inside a fully locked
repository. Rollback is therefore reliable — **provided the before-document was captured first,
and provided the plan knows the raw GET response is not a valid PUT body.** That second clause is
the real trap and is documented under Pitfall 2.

**Primary recommendation:** Structure the phase as *capture → decide → apply → witness → restore*,
with the target repository chosen by the operator at a `checkpoint:decision` (never by Claude),
with `--apply` itself executed by the operator at a `checkpoint:human-verify` (Claude's Bash
classifier has already denied this exact script twice, in dry-run — see Pitfall 6), and with a
mandatory restore task that runs regardless of outcome. Recommend **`terraform-pipelines`** as
the target, for the measured reasons in the matrix below — but present the matrix and let the
operator pick.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Required-status-check enforcement / merge refusal | **GitHub platform (repository ruleset)** | — | The gate lives in GitHub's ruleset engine, not in any workflow YAML. No amount of workflow authoring makes a check required. |
| Producing the five check runs whose names the ruleset references | **GitHub Actions (CI/CD tier)** | — | `pr-security.yml` caller job id `security` + five `security.yml` job `name:` values compose the contexts. |
| Advisory-vs-enforcing scan semantics (`GATE_MODE`) | **Repository variable (GitHub config)** | CI/CD tier (11 gated step tolerances) | ADR-017: resolved once at workflow level; a repository variable is the only mechanism that avoids a YAML edit. |
| Read-modify-write of the ruleset document | **Operator workstation (`bash` + `gh` + `python3`)** | — | `scripts/set-required-checks.sh` in the canonical host clone. Nothing about this runs in CI. |
| Before-state capture / rollback | **Operator workstation (evidence dir + `gh api` PUT)** | — | Not implemented in any script today. See Don't Hand-Roll and Open Question Q3. |
| Recording the outcome as an architectural decision | **This repository (`docs/adr/`, append-only)** | `docs/adoption-guide.md` §8 | ADRs are append-only per CLAUDE.md — resolving ADR-017 item 4 means a *new* ADR-019, never an edit. |

---

## Project Constraints (from CLAUDE.md and `.claude/rules/`)

These are binding on the plan, with the same authority as a locked decision.

| Constraint | Source | Consequence for Phase 22 |
|------------|--------|--------------------------|
| **ADRs in `docs/adr/` are append-only.** Add new records as new files; don't modify accepted ones. | `CLAUDE.md` | Closing ADR-017 "not verified" item 4 and ADR-018 item 7 requires **ADR-019**, not an edit to 017/018. The plan must create a new file. |
| Preserve ASCII architecture diagrams, the 4-phase layered structure, and tool coverage matrices in the blueprint. | `CLAUDE.md` | Any blueprint edit (§Phase 2 branch-protection prose, `docs/development-security-stack-option-1.md:2050`) must be surgical. |
| **Never set the executable bit on scripts.** Always `bash script.sh`. | `defensive-protocol-v2-anti-slop.md` | Every invocation in every task must be written `bash scripts/set-required-checks.sh …`. Never `./`. Never `chmod +x`. |
| **When anything fails: STOP → REPORT → WAIT.** No silent retry. | `defensive-protocol-v2-anti-slop.md` | A 422 from the PUT must be reported with its raw body and halt the plan — this is already the standing instruction in 18-05 Task 3 and must be carried forward verbatim. |
| **Irreversible actions require explicit human confirmation before proceeding.** | `defensive-protocol-v2-session-management.md` | Both the target-repo choice and the `--apply` invocation are blocking gates. Neither is an executor decision. |
| **Let it crash — no silent fallbacks.** | `defensive-protocol-v2-anti-slop.md` | Do not wrap the PUT in `|| true`. The script's `set -euo pipefail` is correct as-is. |
| Evidence standards: state what was *actually tested*, not what was assumed. | `defensive-protocol-v2-anti-slop.md` | VERIFICATION.md for this phase must quote live API output, not narrate. |
| Standing docs gate: `bash scripts/check-adoption-guide.sh` | `CLAUDE.md`, `scripts/` | **Verified green right now: 15 passed / 0 failed.** Must stay green after any §8 edit. |

---

## Phase Requirements

**No requirement IDs are assigned to Phase 22, and every v2.0 requirement in
`.planning/REQUIREMENTS.md` is already `[x]` complete** — including CICD-04, CICD-06 and VAL-01,
the three the audit names as "wired but never witnessed."

| ID | Description | Research Support |
|----|-------------|------------------|
| *(none assigned)* | ROADMAP says `**Requirements**: TBD` | See Open Question Q1 — the planner must get an ID from the operator before writing acceptance criteria that "complete" anything |

**Candidate framings for the operator to choose between (do not pick one unilaterally):**

1. **New requirement `VAL-02`** — "Required-check enforcement exercised live: a pull request with a
   red required check is observably refused by GitHub." Cleanest: the gap is a *validation* gap, and
   VAL-01 is already the validation family.
2. **Re-open `CICD-04`** — arguably CICD-04 ("branch protection config/guidance provided so scan
   checks *can be* made required") was honestly satisfied by the dry-run-proven script, per
   ADR-017's explicit reasoning. Re-opening it contradicts that ADR's recorded position.
3. **No requirement; audit-remediation phase only** — the phase closes a milestone-audit finding
   and produces ADR-019, without touching `REQUIREMENTS.md`.

Recommendation: **option 1 (`VAL-02`)**. It does not relitigate ADR-017, and it names the thing
that is actually missing. `[ASSUMED]` — needs operator confirmation.

---

## Live State — measured 2026-09-16, read-only

Everything in this section was read from the GitHub API during this research session. Nothing was
written.

### Candidate target repositories

| | `security-platform` | `terraform-pipelines` | `aws-zabbix-monitoring-solution` |
|---|---|---|---|
| Visibility | public | public | **private** |
| Our permission | `admin: true` | `admin: true` | `admin: true` |
| Default branch | `main` | `main` | `main` |
| Ruleset | **id 14243983** "Default", active | **id 12760793** "Default", active | **`[]` — none exists** |
| Rule types on `main` | `deletion`, `non_fast_forward` | `deletion`, `non_fast_forward`, `copilot_code_review` | — |
| `bypass_actors` | `[]` | `[]` | — |
| `current_user_can_bypass` | `"never"` | `"never"` | — |
| Ruleset `conditions.ref_name` | include `~DEFAULT_BRANCH` | include `~DEFAULT_BRANCH`, `refs/heads/main`; **exclude `refs/heads/dev**/**`** | — |
| `.github/workflows/` on `main` | present (canonical host) | **404 — absent** | not checked |
| `GATE_MODE` variable | not set | not set | not checked |

`[VERIFIED: gh api, this session]` for every cell above.

### Pilot evidence still live

- `gh api repos/OttawaCloudConsulting/terraform-pipelines/commits/6e8975f22232659c1403de452d559d6c97ebb1eb/check-runs`
  **still returns all five `app.id 15368` contexts today** — byte-identical names to the frozen set.
  This means a `--verify-sha 6e8975f2…` preflight would pass right now, on that repo, without
  opening anything. `[VERIFIED: gh api, this session]`
- PR #12 (Mode A) and PR #13 (Mode B) on `terraform-pipelines` are both **CLOSED, not merged**, and
  their head branches (`chore/adopt-security-pipeline-mode-a`/`-mode-b`) **no longer exist** —
  `gh api repos/.../branches` returns `main` only. They cannot be reopened; a fresh branch is
  required. `[VERIFIED: gh api, this session]`
- All five checks concluded `success` on both pilot PRs — but that was **report-only**, where
  `continue-on-error: true` makes green meaningless as evidence of "no findings".
  `[VERIFIED: 20-10-evidence/check-runs-a.json, check-runs-b.json]`

### The load-bearing finding: `terraform-pipelines` has real findings

From `20-10-evidence/run-a.log.txt`, the Mode A pilot run on `terraform-pipelines`:

| Scanner | Result on `terraform-pipelines` | Under `GATE_MODE=blocking` |
|---------|--------------------------------|---------------------------|
| **Semgrep CE** | `Ran 190 rules on 66 files: 6 findings.` / `Findings: 6 (6 blocking)` | **RED** |
| Checkov | `Passed checks: 248, Failed checks: 0` and `296/0` | green |
| Gitleaks | `no leaks found` | green |
| Trivy Filesystem | npm/Python sub-scans SKIP (no lockfiles) | green |
| Trivy Image | `SKIP: no Dockerfile found` | green |

`[VERIFIED: .planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/run-a.log.txt]`

**This is what makes the phase feasible without seeding anything.** `terraform-pipelines` produces
a natural red check under blocking — exactly one of five, from real Semgrep findings in its own
Terraform/Python tree. No fixture needs to be planted, no synthetic vulnerability committed. One
red required check is all the audit's unverified flow needs.

---

## Target Repository Decision Matrix

> **This is a `checkpoint:decision` for the operator. Claude must not pick.** The phase title
> itself says "needs explicit target-repo confirm."

| Option | Blast radius | Can produce a red check? | Lockout exposure | Verdict |
|--------|-------------|--------------------------|------------------|---------|
| **A. `terraform-pipelines`** (public pilot) | Real repo, one active ruleset, 5 commits on `main`, low traffic | **Yes, naturally** — Semgrep, 6 findings, measured | **Real but bounded** — see the trap below | **Recommended** |
| **B. `security-platform`** (own canonical host) | The repo the whole project depends on | Yes — `fixtures/` guarantees all five go red | **Severe.** ADR-017 rejected this on measured grounds: `fixtures/` + `bypass_actors: []` means `main` locks against every PR including the revert PR | **Do not relitigate ADR-017.** Only if the operator explicitly overrides |
| **C. `aws-zabbix-monitoring-solution`** (private pilot) | Private, lower visibility | Unknown — not measured | N/A | **Ruled out mechanically.** `rulesets` returns `[]`; `set-required-checks.sh` has no `POST` create path, and `docs/adoption-guide.md:353` says so plainly. Would require a script change first |
| **D. Fresh throwaway sandbox repo** | Effectively zero | Only after seeding | None | **Cleanest, but most setup.** See cost below |

### The `terraform-pipelines` trap the planner must design around

`terraform-pipelines`' `main` has **no `.github/workflows/` directory at all** (404, verified).
The pilot PRs that carried `security.yml` were closed, not merged. Therefore:

> If the five contexts are made required on `terraform-pipelines`' `main` and left there, **every
> future PR that does not itself carry `security.yml` produces zero `security / …` check runs.**
> Five required checks that never report sit permanently *pending*, and a pending required check
> blocks a merge exactly as a failing one does. That is a real, indefinite lockout — not of the
> exercise PR, but of every unrelated PR afterwards.

Three ways to design around it, in order of preference:

1. **Bounded window + mandatory restore (recommended).** The required checks exist only for the
   duration of the exercise. The final task PUTs the captured before-document back and verifies
   `rules/branches/main` returns exactly `deletion, non_fast_forward, copilot_code_review` again.
   This is the smallest-blast-radius option and it still fully closes the audit finding — the
   audit asks for the refusal to be *witnessed*, not to be *permanent*.
2. **Merge the adoption PR into `main` first**, so `security.yml` is inherited by every future
   branch, then leave the required checks in place. Larger commitment, changes the pilot repo's
   steady state, and is really a separate adoption decision.
3. **Add a bypass actor first** (Repository admin role, `bypass_mode: "always"`). Reduces the
   sharpness of the lockout but also weakens what the exercise proves — if the operator can
   bypass, the refusal is advisory. Use only as an emergency hatch, not as the design.

### Cost of option D, stated honestly

A throwaway sandbox repo needs, before `--verify-sha` can pass even once: repo creation, a
`POST /repos/{o}/{r}/rulesets` to create a ruleset (a path the script does not implement — this
would be `gh api --method POST` by hand), the Mode A file set copied in, a first PR, a completed
workflow run producing all five contexts, and a seeded finding to make one go red. Roughly the
whole of plan 20-10 again. It is the safest option and the slowest; the operator should be told
both halves.

### Second-order effect the operator needs before choosing A

`terraform-pipelines`' `main` shows **direct pushes today**. Commit `c490bed0` ("update ARCH doc")
has **zero associated pull requests** (`gh api repos/.../commits/c490bed0/pulls` → `0`), while
`f276a1c1` has one. `[VERIFIED: gh api, this session]`

`set-required-checks.sh` always adds a `pull_request` rule alongside the required checks — by
design, per ADR-002 and the script's own header ("`required_status_checks` alone also does not
require a pull request … this helper always adds both rules together, never one alone"). So the
exercise will, for its duration, **take away the operator's direct-push shortcut on that repo.**
Under design option 1 (bounded window) this lasts minutes. Under option 2 it is permanent. Say so
before asking.

---

## Standard Stack

No packages are installed by this phase. The stack is what is already on the workstation.

### Core

| Tool | Version | Purpose | Why standard |
|------|---------|---------|--------------|
| `gh` (GitHub CLI) | **2.101.0** (released 2026-09-15) | Every read, the PUT, the merge attempt, the variable flip | Already the project's sole GitHub interface across Phases 14–21. `gh api` handles auth, pagination and `--jq` in one. `[VERIFIED: gh --version, this session]` |
| `bash` | system | Invoking `set-required-checks.sh` (never `./`, never `chmod +x`) | Project rule |
| `python3` | **3.12.0** | The read-modify-write merge inside the script; JSON body construction for rollback | Already the script's engine `[VERIFIED: python3 --version]` |
| `jq` | **1.8.2** | Evidence extraction from captured JSON | Already used throughout the evidence dirs `[VERIFIED: jq --version]` |
| `git` | 2.50.1 (Apple Git-155) | Branch/PR mechanics for the exercise PR | `[VERIFIED: git --version]` |

### The one script that matters

`repos/security-platform/scripts/set-required-checks.sh` (12,219 bytes, 2026-09-12).
**Read it before planning anything.** Its header comment is the authoritative spec; the adoption
guide §8 paraphrases it and the paraphrase is accurate.

### Auth posture

`gh auth status`: logged in as `OttawaCloudConsulting`, token scopes `gist, read:org, repo, workflow`.
`GET /repos/{o}/{r}/rulesets/{id}` succeeded on both candidate repos — that endpoint requires
repository-admin read, so the `repo` scope plus `admin: true` is sufficient for ruleset *reads*.
Write sufficiency is inferred, not proven. `[VERIFIED: gh auth status + successful GET]` /
`[ASSUMED]` for the write half — see Open Question Q2.

### Alternatives considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| Rulesets API | Classic branch protection (`branches/main/protection`) | **Rejected as a mechanism, not merely undocumented** — ADR-017 and the script header both record that this endpoint 404s *by design* on a ruleset-governed repo, and that the 404 is a false negative. Never read it as evidence of anything. |
| `--apply` via the script | Hand-written `gh api --method PUT` | Loses the exit-3 drop-detection guard, the `--verify-sha` preflight, and the lockout acknowledgement. The script exists precisely to prevent the naive body. Use the script for the forward path. |
| `gh api` for ruleset writes | GitHub web UI (Settings → Rules) | The UI is the documented escape hatch for adding a bypass actor and is fine there, but it produces no captureable evidence. Every measured step must be API. |

**Installation:** none. This phase installs nothing.

---

## Package Legitimacy Audit

**No external packages are installed by this phase.** No npm, PyPI, or crates dependency is added,
upgraded, or introduced. The Package Legitimacy Gate is therefore not applicable — there is
nothing to slopcheck.

| Package | Registry | Disposition |
|---------|----------|-------------|
| *(none)* | — | — |

**Packages removed due to slopcheck `[SLOP]` verdict:** none
**Packages flagged as suspicious `[SUS]`:** none

---

## Architecture Patterns

### The exercise, end to end

```
                        ┌─────────────────────────────────────────┐
                        │  PRE:  capture before-state to evidence/ │
                        │  • rulesets/{id}          (full JSON)    │
                        │  • rules/branches/main    (rule types)   │
                        │  • gh variable list       (GATE_MODE?)   │
                        └───────────────────┬─────────────────────┘
                                            │
                        ┌───────────────────▼─────────────────────┐
                        │  checkpoint:decision — OPERATOR picks    │
                        │  target repo + end-state (restore/keep)  │
                        └───────────────────┬─────────────────────┘
                                            │
       ┌────────────────────────────────────▼────────────────────────────────────┐
       │  1. OPEN exercise PR carrying the Mode A file set (GATE_MODE unset)     │
       │     → five checks run → all five SUCCESS (report-only)                  │
       │     → record mergeStateStatus == CLEAN                                  │
       └────────────────────────────────────┬────────────────────────────────────┘
                                            │
       ┌────────────────────────────────────▼────────────────────────────────────┐
       │  2. FLIP  gh variable set GATE_MODE --body blocking                     │
       │     → re-run → Semgrep RED, four green                                  │
       │     → record mergeStateStatus == UNSTABLE   ◄── red but NOT required    │
       │        THIS IS THE CONTROL OBSERVATION. Without it the next step        │
       │        proves nothing.                                                  │
       └────────────────────────────────────┬────────────────────────────────────┘
                                            │
       ┌────────────────────────────────────▼────────────────────────────────────┐
       │  3. checkpoint:human-verify — OPERATOR runs, Claude does not:           │
       │     bash scripts/set-required-checks.sh \                               │
       │       --repo OWNER/REPO --ruleset ID \                                  │
       │       --verify-sha <PR head SHA> \                                      │
       │       --apply --yes-i-understand-lockout                                │
       │     → 422?  raw body, STOP.   → 200? continue                           │
       └────────────────────────────────────┬────────────────────────────────────┘
                                            │
       ┌────────────────────────────────────▼────────────────────────────────────┐
       │  4. READ BACK  rules/branches/main  →  5 rule types, none dropped       │
       │     rulesets/{id} → five contexts, integration_id 15368                 │
       └────────────────────────────────────┬────────────────────────────────────┘
                                            │
       ┌────────────────────────────────────▼────────────────────────────────────┐
       │  5. WITNESS  mergeStateStatus == BLOCKED   ◄── THE DELIVERABLE          │
       │     gh pr merge --squash → refusal text captured verbatim               │
       │     (optional, zero-blast-radius) git push origin main → rejected       │
       └────────────────────────────────────┬────────────────────────────────────┘
                                            │
       ┌────────────────────────────────────▼────────────────────────────────────┐
       │  6. RESTORE (runs regardless of outcome, including on failure)          │
       │     gh variable delete GATE_MODE                                        │
       │     PUT rulesets/{id}  ←  reconstructed body from the captured doc      │
       │     verify rules/branches/main == before-state, byte for byte           │
       └─────────────────────────────────────────────────────────────────────────┘
```

### Pattern 1: The control observation (`UNSTABLE` before `BLOCKED`)

**What:** Measure the PR's merge state with the check *red but not required* before applying, and
again with it *red and required* after.
**Why it is not optional:** A `BLOCKED` reading on its own is ambiguous — it could come from the
`pull_request` rule, from `copilot_code_review`, from anything. The `UNSTABLE → BLOCKED`
transition on the **same PR, same head SHA, same red check** is what isolates required-status-check
enforcement as the cause. This is the same discipline 18-05 used (one tree hash, three verdicts).

```bash
# Before apply (red Semgrep, not required) — expect UNSTABLE
gh pr view <N> -R OWNER/REPO --json number,headRefOid,mergeable,mergeStateStatus

# After apply (same head SHA) — expect BLOCKED
gh pr view <N> -R OWNER/REPO --json number,headRefOid,mergeable,mergeStateStatus
```

`mergeStateStatus` semantics: `UNSTABLE` = mergeable with a non-passing, non-required commit
status; `BLOCKED` = an unmet required review or status check; `CLEAN` = all green.
`[CITED: docs.github.com/en/graphql/reference/enums — MergeStateStatus]`, corroborated by two
independent community sources. **MEDIUM confidence on the doc wording — but the phase does not
depend on it**, because the exercise measures the transition empirically. Treat the enum
description as a prediction to be confirmed, not a fact to be cited.

Note `gh pr view --json merged` is **not a valid field** in `gh` 2.101.0 (`Unknown JSON field`) —
use `state` and `mergedAt`. `[VERIFIED: gh pr view, this session]`

### Pattern 2: Capture-before-anything, restore-regardless

**What:** A dedicated evidence directory populated *before* the decision checkpoint, and a restore
task that is not conditional on success.
**Where the precedent lives:** `20-10-evidence/` (`rules-before.txt`, `rules-after.txt`,
`merged.json`, `check-runs-*.json`, `run-*.log.txt`). Follow that exact shape — it is what made
20-10's dry run independently re-verifiable.

```bash
E=.planning/phases/22-.../22-0X-evidence
mkdir -p "$E"
gh api "repos/$REPO/rulesets/$RID"            > "$E/ruleset-before.json"
gh api "repos/$REPO/rules/branches/main" --jq '[.[].type]|sort|join(",")' > "$E/rules-before.txt"
gh variable list -R "$REPO"                   > "$E/variables-before.txt"
```

### Pattern 3: Operator-executed write, Claude-executed verification

Every prior live-write task in this project used this split, and 18-05 Task 3 states the rule in
the words the plan should reuse verbatim:

> "Do NOT run `--apply` on your own initiative under any circumstance."
> "If the PUT returns 422, report the raw error body and stop: the `pull_request` parameter set is
> an unverified assumption and a 422 changes no state."

Claude's job on either side of that gate is read-only measurement, then independent re-verification
rather than accepting the operator's report at face value — which is exactly what 20-10 did after
the orchestrator ran the dry run for it.

### Anti-patterns to avoid

- **PUTting the raw GET response back.** See Pitfall 2. It is the single most likely way to turn a
  clean rollback into a second incident.
- **Treating the `--apply` PUT's 200 as the phase deliverable.** It is a precondition. The
  deliverable is the refusal.
- **Reading `branches/main/protection` for anything.** 404 by design on a ruleset-governed repo.
  ADR-017 and 14-02 both record this as a false negative.
- **Seeding a synthetic finding on `terraform-pipelines`.** Unnecessary — Semgrep already returns 6.
  Seeding adds a commit to a real repo for no evidentiary gain.
- **Leaving `GATE_MODE=blocking` set.** It is repository-wide and governs every run for as long as
  it is set (ADR-017 tradeoff). 18-05 kept its window to ~2.5 minutes and recorded that no
  unrelated run fired inside it. Do the same, and record the window's start and end.
- **Relitigating ADR-017's `leave-unrequired` decision for `security-platform`.** It was made on
  measured grounds. If the operator wants to override it, that is a new decision recorded in
  ADR-019 — not a correction of ADR-017.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Merging required checks into an existing ruleset | A `gh api --method PUT` with a body containing only `required_status_checks` | `bash repos/security-platform/scripts/set-required-checks.sh` | PUT **replaces the whole document**. A partial body silently deletes `deletion`, `non_fast_forward` and `copilot_code_review` — "a security regression dressed as a security improvement" (script header). The script's exit-3 guard catches exactly this. |
| Confirming the five contexts exist before requiring them | Eyeballing the checks tab | `--verify-sha <SHA>` (mandatory under `--apply`, exit 4 if absent) | A context GitHub has never seen becomes a *permanently-pending* required check, not a failing one. Exit 6 exists to refuse creating that trap. |
| Typing the five context strings | Retyping from docs or from a code-scanning analysis name | The frozen strings in the script / derived by `bash scripts/check-adoption-guide.sh` | Separator is **EM DASH U+2014**, never a hyphen, never en dash. The code-scanning `analyses` endpoint disagrees on case for two of five (`checkov`/`Checkov`, `Gitleaks`/`gitleaks`) — branch protection matches the **check-run** name. A one-codepoint error produces a permanently-pending check with no runtime signal anywhere. |
| Deciding which repo to write to | Claude inferring from context | `checkpoint:decision` with the matrix above | The phase title says "needs explicit target-repo confirm." |
| Knowing whether a merge was actually blocked | Reading the checks tab | `mergeStateStatus` before/after + `gh pr merge` refusal text | The checks tab shows red; it does not show *required*. |

**Key insight:** every guard in `set-required-checks.sh` (exits 3, 4, 5, 6) encodes a failure this
project already reasoned through. The adoption guide says it outright: *"These refusals are
features, not friction — teach them as such, never as a workaround to bypass."* A plan that works
around a guard has misunderstood the phase.

---

## Common Pitfalls

### Pitfall 1: A pending required check locks the repo indefinitely

**What goes wrong:** Required checks are added to `main`, but `main` has no `security.yml`, so
future PR branches never produce the five contexts. They sit pending forever and every PR is
unmergeable.
**Why it happens:** `terraform-pipelines`' `main` genuinely has no `.github/workflows/` (404,
verified today) because PRs #12/#13 were closed rather than merged.
**How to avoid:** design option 1 (bounded window + mandatory restore), or merge the adoption PR
into `main` first.
**Warning signs:** a new PR on the target repo whose five `security / …` checks show "Expected —
Waiting for status to be reported" and never resolve.

### Pitfall 2: The raw GET response is not a valid PUT body

**What goes wrong:** Rollback is attempted as
`gh api repos/../rulesets/ID > before.json` then `gh api --method PUT … --input before.json`, and
it 422s — or worse, partially applies.
**Why it happens:** `GET /rulesets/{id}` returns server-owned fields the PUT schema does not
accept — `id`, `node_id`, `source`, `source_type`, `created_at`, `updated_at`, `_links`,
`current_user_can_bypass`. The documented PUT body is exactly six keys: `name`, `target`,
`enforcement`, `bypass_actors`, `conditions`, `rules`.
`[CITED: docs.github.com/en/rest/repos/rules — PUT /repos/{owner}/{repo}/rulesets/{ruleset_id}]`
**How to avoid:** reconstruct the rollback body the same way the script's own Python does for the
forward path — pick exactly those six keys out of the captured document, nothing more:

```python
# rollback body construction — mirrors set-required-checks.sh's forward path
import json
d = json.load(open("ruleset-before.json", encoding="utf-8"))
body = {k: d[k] if k in d else ([] if k == "bypass_actors" else None)
        for k in ("name","target","enforcement","conditions","bypass_actors","rules")}
json.dump(body, open("rollback.json","w",encoding="utf-8"), ensure_ascii=False, indent=2)
```

**Warning signs:** a 422 on rollback. That is the moment to stop and report, not to start deleting
keys by trial and error against a live repo.

### Pitfall 3: `copilot_code_review` may not round-trip through PUT

**What goes wrong:** the merged body for `terraform-pipelines` carries five rule types including
`copilot_code_review` (confirmed present in `20-10-evidence/merged.json`), and the PUT 422s on a
rule type the write schema does not accept even though the read schema emits it.
**Why it happens:** newer/preview rule types sometimes appear in GET before they are writable via
PUT. **This cannot be determined without a write** — it is the exact thing the dry run could never
test.
**How to avoid:** you cannot pre-empt it; you can only fail safely. A 422 changes no state
(confirmed by the PUT-replaces-document semantics: a rejected request writes nothing). Carry
18-05's instruction forward: raw body, stop.
**Warning signs:** HTTP 422 naming `rules[2].type`. If this fires, the finding itself is valuable
and belongs in ADR-019 — it is a genuine limitation of the read-modify-write approach on any repo
carrying a preview rule type.

### Pitfall 4: `--repo X` without `--ruleset` silently targets the wrong ruleset id

**What goes wrong:** the defaults are **independent** — `REPO` defaults to
`OttawaCloudConsulting/security-platform` and `RULESET_ID` defaults to `14243983`. Passing
`--repo OttawaCloudConsulting/terraform-pipelines` alone leaves the ruleset id pointing at
`security-platform`'s.
**Why it happens:** the flags were written for a single-repo tool and generalised later.
**Actual behaviour:** the GET 404s, `set -euo pipefail` aborts, exit 1. **It fails safe** — but
silently in the sense that the error is a bare `gh` 404 with no hint that the id is mismatched.
**How to avoid:** every invocation in every task must pass **both** `--repo` and `--ruleset`
explicitly, even when one of them equals the default. Write them out in the plan.

### Pitfall 5: `GATE_MODE` is repository-wide, not scoped to the exercise PR

**What goes wrong:** the blocking window catches an unrelated PR or push on the target repo.
**Why it happens:** ADR-017 records this as an accepted structural tradeoff — the flag "governs
every run in the repository for as long as it is set; it cannot be varied per branch, per PR, or
per actor."
**How to avoid:** keep the window minutes long, record its start and end timestamps, and after
closing it run `gh run list -R $REPO` over the window to confirm no unrelated run executed inside
it — exactly 18-05's acceptance criterion. Delete the variable, never set it to `report-only`
(18-05 proved deletion restores green).

### Pitfall 6: The executor's Bash classifier will refuse to run the script

**What goes wrong:** the executor agent's auto-mode Bash classifier denies
`bash scripts/set-required-checks.sh …`, and the plan stalls mid-flight with a partially-applied
ruleset.
**Why it happens:** measured, twice. 20-10-SUMMARY:
*"the dry run … was denied twice by this executor session's own auto-mode Bash classifier — the
identical denial shape 20-07 hit with `gh release create` — so the orchestrator ran the exact
recorded command directly in its own session."* This was for `--out`. `--apply` will certainly be
denied. `[VERIFIED: 20-10-SUMMARY.md lines 54-61, 20-07 precedent]`
**How to avoid:** do not put the write in an executor task at all. Put the literal command text in
a `checkpoint:human-verify` for the operator to run, and give the executor only the read-only
verification on either side. This is a plan-structure requirement, not a nice-to-have.

### Pitfall 7: `gh pr merge` may be interactive

**What goes wrong:** the merge-attempt task hangs waiting on a TTY prompt for merge method.
**How to avoid:** always pass an explicit method and non-interactive flags —
`gh pr merge <N> -R OWNER/REPO --squash` — and capture both stdout and stderr
(`2>&1 | tee evidence/merge-attempt.txt`). The refusal text is the evidence; losing it to stderr
discard loses the deliverable. **`[ASSUMED]`** — not exercised in this session.

### Pitfall 8: Two git repositories, one working tree

`scripts/set-required-checks.sh` lives in `repos/security-platform/`, which is a **separate git
repository** vendored into this one. Any change to the script (e.g. adding `--restore`) is a commit
*there*, plus an `docs/adoption-guide.md` §8 update *here*, plus
`bash scripts/check-adoption-guide.sh` staying green. Do not plan a script edit as if it were a
one-repo change.

---

## Code Examples

All commands below are read-only unless explicitly marked. Substitute `$REPO` / `$RID` / `$PR`.

### Capture before-state

```bash
REPO=OttawaCloudConsulting/terraform-pipelines
RID=12760793
E=".planning/phases/22-.../22-0X-evidence"; mkdir -p "$E"

gh api "repos/$REPO/rulesets/$RID"                                  > "$E/ruleset-before.json"
gh api "repos/$REPO/rules/branches/main" --jq '[.[].type]|sort|join(",")' > "$E/rules-before.txt"
gh variable list -R "$REPO"                                         > "$E/variables-before.txt"
gh api "repos/$REPO/contents/.github/workflows" --jq '[.[].name]'   > "$E/workflows-on-main.txt" 2>&1
```

Expected `rules-before.txt` today: `copilot_code_review,deletion,non_fast_forward`
`[VERIFIED: gh api, this session — matches 20-10-evidence/rules-before.txt exactly]`

### Merge-state measurement (the control and the deliverable)

```bash
gh pr view "$PR" -R "$REPO" \
  --json number,state,headRefOid,mergeable,mergeStateStatus,baseRefName
```

### Preflight that the five contexts are live at the head SHA

```bash
gh api "repos/$REPO/commits/$SHA/check-runs" \
  --jq '.check_runs[] | select(.app.id == 15368) | "\(.name) => \(.conclusion)"'
```

Sample output verified on `terraform-pipelines` at `6e8975f2…` this session — all five present.

### The live write — OPERATOR ONLY, at a blocking checkpoint

```bash
bash repos/security-platform/scripts/set-required-checks.sh \
  --repo "$REPO" \
  --ruleset "$RID" \
  --verify-sha "$SHA" \
  --out /tmp/22-merged.json \
  --apply --yes-i-understand-lockout
```

Both `--repo` and `--ruleset` are mandatory in the plan text (Pitfall 4). The script performs its
own read-back of `rules/branches/main` and the required contexts after the PUT.

### Authoritative read-back (never the classic endpoint)

```bash
gh api "repos/$REPO/rules/branches/main" --jq '.[].type'
gh api "repos/$REPO/rulesets/$RID" --jq \
  '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'
```

### Restore — runs regardless of outcome

```bash
gh variable delete GATE_MODE -R "$REPO" 2>/dev/null || true   # absent is fine; see note
python3 - "$E/ruleset-before.json" "$E/rollback.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
body = {
    "name": d["name"], "target": d["target"], "enforcement": d["enforcement"],
    "conditions": d["conditions"], "bypass_actors": d.get("bypass_actors", []),
    "rules": d["rules"],
}
json.dump(body, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("rollback body:", [r["type"] for r in body["rules"]])
PY
gh api --method PUT "repos/$REPO/rulesets/$RID" --input "$E/rollback.json"
gh api "repos/$REPO/rules/branches/main" --jq '[.[].type]|sort|join(",")' > "$E/rules-restored.txt"
diff "$E/rules-before.txt" "$E/rules-restored.txt" && echo "RESTORED: byte-identical"
```

The `|| true` on `gh variable delete` is the **one** place a tolerance is justified (deleting an
absent variable is not a failure) and it is scoped to a single non-security command. Do not
generalise it. Consider `gh variable list | grep -q GATE_MODE && gh variable delete …` instead if
the project's no-silent-fallback rule is read strictly — that is the cleaner form and the planner
should prefer it.

---

## Runtime State Inventory

This is a live-target operation, not a rename — but the same discipline applies. What holds state
outside git that this phase touches:

| Category | Items found | Action required |
|----------|-------------|-----------------|
| **Live service config (not in git)** | `terraform-pipelines` ruleset **12760793** (`deletion, non_fast_forward, copilot_code_review`, `bypass_actors: []`); `security-platform` ruleset **14243983** (`deletion, non_fast_forward`, `bypass_actors: []`). Neither ruleset document exists anywhere in git. | **Capture to the evidence dir before any write.** This is the only copy that will exist. |
| **Live service config (not in git)** | Repository variable `GATE_MODE` — currently **unset** on both `security-platform` and `terraform-pipelines`. | Set during the blocking window; **deleted** (not set to `report-only`) at restore. 18-05 proved deletion restores green. |
| **Stored data** | None. No database, no datastore keyed on anything this phase changes. | None — verified: this repo is documentation-only and the pipeline persists nothing outside GitHub. |
| **OS-registered state** | None — verified: no scheduled tasks, no launchd/pm2 entries reference this workflow. | None |
| **Secrets / env vars** | None added or renamed. `gh` uses the existing keyring token (`OttawaCloudConsulting`, scopes `gist, read:org, repo, workflow`). No `GITHUB_TOKEN` change. | None |
| **Build artifacts** | None. Nothing is compiled or packaged. | None |
| **GitHub-side artifacts created by the exercise** | A new branch + PR on the target repo; workflow runs; check runs; SARIF uploads to the target repo's Security tab; up to 4–5 artifacts per run. | PRs #12/#13 were left CLOSED with branches deleted — follow that precedent. **SARIF analyses in the target's code-scanning tab persist** and are not trivially deletable; note this before choosing a target. |

**The canonical question — after the exercise, what is still changed on GitHub that no git revert
touches?** Answer: the ruleset (restored explicitly by the rollback task), the `GATE_MODE`
variable (deleted explicitly), and the code-scanning analyses + PR history on the target repo
(permanent, low-impact, same as the 20-10 pilots already left behind).

---

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | every step | ✓ | 2.101.0 | none needed |
| `gh` auth, admin on target | the PUT | ✓ | `OttawaCloudConsulting`, `admin: true` on both candidates | none |
| `python3` | script merge + rollback body | ✓ | 3.12.0 | none needed |
| `jq` | evidence extraction | ✓ | 1.8.2 | `--jq` in `gh` |
| `git` | exercise branch/PR | ✓ | 2.50.1 | none needed |
| `repos/security-platform/` clone present | the script; also `check-adoption-guide.sh` exit 2 preflight | ✓ | present, script dated 2026-09-12 | **none — hard blocker.** The gate exits 2 without it, deliberately, with no hard-coded fallback |
| `markdownlint-cli2` | `check-adoption-guide.sh` MARKDOWNLINT assertion | ✓ | gate ran green: 15/0 | none |
| A ruleset on the target repo | `set-required-checks.sh` (no create path) | ✓ on A and B / ✗ on C | — | For C only: hand-written `POST /repos/{o}/{r}/rulesets` first |
| Executor able to run the script | `--apply` | **✗ — measured denial, twice, in 20-07 and 20-10** | — | **Operator runs it at a `checkpoint:human-verify`.** This is the fallback and it must be the plan's default path |

**Missing with no fallback:** none, given the operator-executed write.
**Missing with fallback:** executor script execution → operator checkpoint (Pitfall 6).

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`. This project has **no unit
test framework** — validation is standing bash gates plus live API re-query, and that is the
correct shape here.

### Test framework

| Property | Value |
|----------|-------|
| Framework | Bash standing gates + live `gh api` re-query (no xUnit framework; none should be added) |
| Config file | none — gates are self-contained scripts |
| Quick run command | `bash scripts/check-adoption-guide.sh` |
| Full suite command | `bash scripts/check-adoption-guide.sh && bash repos/security-platform/scripts/check-workflow-uploads.sh && bash repos/security-platform/scripts/check-detector-parity.sh` |

`bash scripts/check-adoption-guide.sh` **verified green this session: 15 passed / 0 failed.**

### Phase requirements → test map

| Req | Behavior | Test type | Automated command | Exists? |
|-----|----------|-----------|-------------------|---------|
| VAL-02 *(proposed)* | A red **required** check yields `BLOCKED`, a red **non-required** check yields `UNSTABLE`, on the same head SHA | integration (live) | `gh pr view $PR -R $REPO --json headRefOid,mergeStateStatus` run before and after the apply, diffed | ✅ no new file |
| VAL-02 *(proposed)* | `gh pr merge` is refused while blocked | integration (live) | `gh pr merge $PR -R $REPO --squash 2>&1 \| tee $E/merge-attempt.txt` | ✅ |
| VAL-02 *(proposed)* | The PUT preserves every pre-existing rule type | integration (live) | `gh api repos/$REPO/rules/branches/main --jq '[.[].type]\|sort'` — expect the before set ∪ `{required_status_checks, pull_request}` | ✅ |
| VAL-02 *(proposed)* | Rollback restores the exact before-state | integration (live) | `diff $E/rules-before.txt $E/rules-restored.txt` → empty | ✅ |
| DIST-08 (regression) | Adoption guide §8 still consistent after any prose update | offline gate | `bash scripts/check-adoption-guide.sh` | ✅ green today |
| — (regression) | Script guards still refuse correctly | offline unit-ish | `bash repos/security-platform/scripts/set-required-checks.sh --apply` → exit 4; `… --apply --verify-sha X` → exit 5; `… --input <doc without rules>` → **exit 2, verified this session** | ✅ |

### Sampling rate

- **Per task commit:** `bash scripts/check-adoption-guide.sh`
- **Per wave merge:** full suite above
- **Phase gate:** full suite green, **plus** `rules-restored.txt` byte-identical to
  `rules-before.txt`, before `/gsd:verify-work`

### Wave 0 gaps

- [ ] `22-0X-evidence/` directory — the capture target must exist before the first live read
- [ ] An offline guard-regression script (or inline task) exercising exits 2/3/4/5 against
      `--input` fixtures, so the guards are re-proven at *this* commit rather than inherited from
      18-03. Exit 2 and exit 4/5 are cheap; **exit 2 already re-verified in this research session**
- [ ] No framework install needed

---

## Security Domain

### Applicable ASVS categories

| ASVS category | Applies | Standard control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `gh` keyring token; no token is written to any file, log, or evidence artifact. Evidence dirs must be grepped for `gho_` before commit |
| V3 Session Management | no | No sessions |
| V4 Access Control | **yes — central** | The entire phase is an access-control change: who may merge into `main`. `bypass_actors` must be carried forward verbatim, never synthesised (script header; adoption guide L400) |
| V5 Input Validation | yes | The ruleset JSON is parsed by `python3`, never `eval`'d; the em-dash contexts are quoted-heredoc'd so the shell never expands them |
| V6 Cryptography | no | None hand-rolled |
| V7 Error Handling & Logging | yes | `set -euo pipefail`; no `\|\| true` on any security-relevant command; a 422 halts rather than retries |
| V14 Configuration | **yes** | The whole deliverable is a configuration change to a live repository, with capture + restore as the control |

### Known threat patterns for this phase

| Pattern | STRIDE | Standard mitigation |
|---------|--------|---------------------|
| Partial PUT silently drops `deletion` / `non_fast_forward` / `copilot_code_review`, weakening `main` under cover of "adding security" | **Tampering** | Never a hand-written PUT. `set-required-checks.sh` read-modify-write + exit-3 drop guard; read-back `rules/branches/main` and diff against `rules-before.txt` |
| A one-codepoint context typo creates a permanently-pending required check that looks like a working gate but blocks everything | **Denial of Service** | `--verify-sha` (exit 6); frozen strings derived, never retyped; `check-adoption-guide.sh` CONTEXT-EM-DASH assertion |
| Required checks left on a repo whose `main` lacks the workflow → indefinite lockout of unrelated PRs | **Denial of Service** | Bounded window + mandatory restore (design option 1); or merge adoption to `main` first |
| `bypass_actors` synthesised rather than carried forward → an unintended actor gains merge bypass on `main` | **Elevation of Privilege** | Script copies `bypass_actors` verbatim from the fetched doc; rollback body does the same; read back and confirm `[]` both before and after |
| An agent performs the irreversible-ish write without human authorisation | **Elevation of Privilege** | `checkpoint:decision` for target selection + `checkpoint:human-verify` for the write, both `gate="blocking"`; 18-05 Task 3's "Do NOT run `--apply` on your own initiative" carried verbatim |
| Adding a bypass actor "to be safe" quietly converts the proof into a no-op | **Repudiation** | Bypass actor is an emergency hatch only; if one is added, ADR-019 must record it, because it changes what the exercise proves |
| Token or PR content leaked into a committed evidence file | **Information Disclosure** | Grep every evidence file for `gho_`/`ghp_` before commit; evidence dirs in this project have carried run logs safely before (20-10) |

---

## State of the Art

| Old approach | Current approach | When changed | Impact |
|--------------|------------------|--------------|--------|
| Classic branch protection (`PUT /repos/{o}/{r}/branches/{b}/protection`) | **Repository rulesets** (`/rulesets`, read at `/rules/branches/{b}`) | Rulesets GA'd in 2023; this project standardised on them from Phase 14 | The classic endpoint **404s by design** on a ruleset-governed repo. That 404 is a false negative. Never cite it |
| `required_status_checks` alone as "the gate" | `required_status_checks` **+ `pull_request`** rule, always together | ADR-002 → ADR-017 | Status checks alone do not require a PR to exist; without the `pull_request` rule, one direct push bypasses everything |
| Six required contexts (D-06 as originally written) | **Five** — the caller job emits no check run of its own | ADR-017's correction to D-06 | "If the number six appears anywhere else in this project as the size of the required-check set, it is wrong" |
| Hardcoded report-only (`continue-on-error: true` everywhere) | `GATE_MODE` enum resolved once at workflow level, compared as `== 'report-only'` (fails closed) | ADR-017 / Phase 18 | A typo'd mode is treated as blocking, not tolerated |

**Deprecated / do not use:**
- `branches/main/protection` — as above.
- `gh pr view --json merged` — not a field in `gh` 2.101.0. Use `state` / `mergedAt`.
  `[VERIFIED: this session]`

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | `VAL-02` is the right requirement framing for this phase | Phase Requirements | Acceptance criteria attach to the wrong ID; REQUIREMENTS.md drifts from reality |
| A2 | `terraform-pipelines` is an acceptable live target (public, low-traffic, operator-owned) | Decision Matrix | Writing to a repo the operator considers production. **Mitigated by the mandatory `checkpoint:decision`** |
| A3 | The `repo` OAuth scope permits ruleset **writes**, not just reads (reads confirmed) | Standard Stack | The `--apply` returns 403 and the phase stalls at the write checkpoint. Cheap to discover, changes no state |
| A4 | Semgrep still returns 6 findings on `terraform-pipelines` today (measured 2026-09-14, two days ago) | Live State | No natural red check; a finding would have to be seeded, or a different target chosen. **Re-measure at plan time** |
| A5 | `gh pr merge --squash` on a blocked PR emits a capturable non-interactive refusal | Pitfall 7 | The merge-attempt task hangs on a TTY prompt |
| A6 | `mergeStateStatus` will read `UNSTABLE` (not `BLOCKED`) with a red non-required check and `copilot_code_review` present on the ruleset | Pattern 1 | The control observation is not clean and the before/after loses discriminating power. **Measure it; don't assume it** |
| A7 | A 422 on the PUT changes no state (atomic document replace) | Pitfall 3 | A partially-applied ruleset. Mitigated by the capture-first design either way |
| A8 | The operator wants the ruleset **restored** at phase end rather than left required | Decision Matrix | Wrong end state on a real repo. **Ask at the decision checkpoint** |

---

## Open Questions

1. **Which requirement ID does this phase close?**
   - Known: ROADMAP says TBD; every v2.0 ID is already `[x]`; the audit names an unverified flow,
     not an unmet requirement.
   - Unclear: whether the operator wants a new ID, a re-opened one, or none.
   - Recommendation: propose `VAL-02` at the discuss/decision checkpoint; do not write it into
     `REQUIREMENTS.md` without confirmation.

2. **Does the current token scope permit ruleset writes?**
   - Known: `repo` scope + `admin: true`; GET on `/rulesets/{id}` (admin-read) succeeds on both
     candidates.
   - Unclear: whether GitHub requires anything beyond `repo` for the PUT.
   - Recommendation: discover at the write checkpoint. A 403 changes no state and costs one
     command. Do not pre-emptively broaden the token.

3. **Should `set-required-checks.sh` gain a `--restore FILE` flag?**
   - Known: no rollback path exists in any script; rollback is currently a hand-built PUT.
   - Unclear: whether the operator wants the canonical repo touched in this phase.
   - Recommendation: **do the rollback inline in the plan for this phase**, and record
     `--restore` as a deferred item. Adding a flag means a commit in `repos/security-platform`, an
     adoption-guide §8 update here, and re-running the standing gate — scope the phase does not
     need in order to close the audit finding.

4. **What is the target repo's end state?**
   - Known: restoring is the smallest blast radius; leaving it required is the stronger adoption
     statement but creates Pitfall 1 on a repo whose `main` has no workflow.
   - Recommendation: default to restore; surface "keep it" as an explicit option at the decision
     checkpoint.

5. **Will `copilot_code_review` round-trip through PUT?**
   - Known: it is present on `terraform-pipelines`' ruleset and in `20-10-evidence/merged.json`.
   - Unclear: unanswerable without a write — the exact blind spot a dry run cannot cover.
   - Recommendation: treat as the first thing the `--apply` tests. A 422 here is a *finding*, not
     a failure, and belongs in ADR-019.

6. **Does ADR-019 supersede, or merely append to, ADR-017 item 4 and ADR-018 item 7?**
   - Known: ADRs are append-only per CLAUDE.md.
   - Recommendation: ADR-019 references both by identifier and records the new measurement.
     Do not edit 017 or 018. Check `docs/adr/README.md` for the index convention before writing.

---

## Sources

### Primary (HIGH confidence)

- **Live GitHub API, this session** (`gh api`, read-only): repository metadata, rulesets, rules,
  check-runs, commits, branches, variables, PR state on `security-platform`,
  `terraform-pipelines`, `aws-zabbix-monitoring-solution`
- `repos/security-platform/scripts/set-required-checks.sh` — full source read; header comment is
  the authoritative spec for flags, guards and exit codes 0–6
- **Empirical:** exit code 2 reproduced this session against a `rules`-less `--input` document
- `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` — the five frozen contexts,
  `integration_id` 15368, the `leave-unrequired` decision, "What was NOT verified" item 4
- `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md` — "`--out`, never
  `--apply`" on both pilots; item 7
- `docs/adr/adr002-require-branch-protection.md` — why `pull_request` must accompany required checks
- `docs/adoption-guide.md` §8 (L340–416) and §12 (L554–566) — the two-ruleset-paths note, the
  no-create-path limitation, the self-lockout warning and its documented remedy
- `.planning/v2.0-MILESTONE-AUDIT.md` L39/57/59/63/85/146/156 — the single UNVERIFIED flow
- `.planning/phases/20-template-packaging-and-adoption-docs/20-10-SUMMARY.md` and
  `20-10-evidence/` — the dry-run evidence shape, the Semgrep finding count, the classifier-denial
  precedent, `rules-before.txt` / `rules-after.txt` / `merged.json`
- `.planning/phases/18-configurable-gate-mode-and-branch-protection/18-05-PLAN.md` Tasks 1–3 —
  the checkpoint pattern to reuse verbatim
- Context7 `/websites/github_en_rest` → `docs.github.com/en/rest/repos/rules` — PUT/POST body
  schema (six keys), `bypass_actors.bypass_mode` values `always` / `pull_request` / `exempt`
- Local tool versions: `gh 2.101.0`, `jq 1.8.2`, `python3 3.12.0`, `git 2.50.1`

### Secondary (MEDIUM confidence)

- `MergeStateStatus` enum semantics (`BLOCKED` / `UNSTABLE` / `CLEAN`) — Context7 GraphQL docs
  returned only the `DRAFT` removal note; enum descriptions corroborated across two independent
  community sources. `docs.github.com/en/graphql/reference/enums` did not render the enum body to
  WebFetch. **The phase does not depend on this — it measures the transition directly.**

### Tertiary (LOW confidence)

- `gh pr merge` refusal text format on a ruleset-blocked PR — not exercised; treat as `[ASSUMED]`
  (A5) and capture `2>&1` rather than predicting the wording

---

## Metadata

**Confidence breakdown:**

- **Live state:** HIGH — every fact read from the GitHub API during this session, not inherited
- **What the tooling does:** HIGH — full script source read; one exit path reproduced empirically
- **Target-repo matrix:** HIGH on the measured discriminators (no ruleset on C, no workflow on A's
  `main`, direct pushes on A's `main`, 6 Semgrep findings, `fixtures/` on B); the *choice* is
  deliberately left open
- **Pitfalls:** HIGH for 1, 2, 4, 5, 6, 8 (all measured or read from primary sources);
  MEDIUM for 3 (unanswerable without a write, by construction); LOW for 7
- **Merge-state enum wording:** MEDIUM — corroborated, not read from a rendered official page
- **Requirement mapping:** LOW — genuinely undecided, flagged as Open Question 1

**Research date:** 2026-09-16
**Valid until:** 2026-09-23 (7 days). Live GitHub state — rulesets, check-run retention, the
Semgrep finding count on `terraform-pipelines`, and PR/branch existence — can all change. **Re-run
the Live State reads at plan time rather than trusting this snapshot.**
