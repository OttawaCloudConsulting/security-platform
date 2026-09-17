# Phase 22: branch-protection `--apply` live exercise - Pattern Map

**Mapped:** 2026-09-16
**Files analyzed:** 13 (9 in this repo, 1 on the pilot repo, 2 inline plan constructs, 1 optional gate) —
plus one `n/a` row for the host-clone script, which is invoked, not edited
**Analogs found:** 12 / 13 (11 exact, 1 role-match, 1 none)
**Upstream input:** `22-RESEARCH.md` only — **no CONTEXT.md exists** (discuss-phase skipped). Every
"decision" in this map is therefore still an *open* decision; nothing here is locked.

---

## READ THIS FIRST — three git repositories, and the pilot clone is stale

`.gitignore` in this repo is one line: `repos/`. Three separate clones live under it, each with its
own `.git` and its own remote:

| Path | Remote | Local HEAD (measured this session) | Usable as-is? |
|---|---|---|---|
| `repos/security-platform/` | `OttawaCloudConsulting/security-platform` | `main` @ `cdf2c21` | **Yes** — this is where `scripts/set-required-checks.sh` is invoked from |
| `repos/terraform-pipelines/` | `OttawaCloudConsulting/terraform-pipelines` | **`feature/add-pre-commit` @ `ffd685c`** — not `main`, not the `c490bed0` the research measured on the remote | **No — stale, and on a feature branch.** Do not branch the exercise PR from this clone. |
| `repos/aws-zabbix-monitoring-solution/` | (pilot C — ruled out mechanically, no ruleset) | not inspected | n/a |

**Consequence for the planner.** 20-10 did not use the vendored pilot clone either — it cloned
`terraform-pipelines` **fresh into the session scratchpad**, never into the working tree
(`20-10-SUMMARY.md:91-93`). Follow that precedent exactly: the exercise branch is cut from a fresh
`origin/main` clone in the scratchpad. Using `repos/terraform-pipelines` as it stands today would
branch from a stale feature branch rather than from `origin/main` — measured: it is on
`feature/add-pre-commit` @ `ffd685c`, and the remote `main` the research read was `c490bed0`.

**And: no single commit can touch two of these repos.** The plan must state, per task, which repo
(or which remote) each action operates in. This is 20-PATTERNS' two-repo warning, now three-repo —
and the third one (the pilot) is written to over the network, not through the working tree.

---

## Reconciliation — RESEARCH.md contradicts the 18-05 record on `gh run rerun`

This is the one place where the planner must **not** inherit RESEARCH.md as written. Both claims
below are primary-source; they cannot both be acted on.

| Source | Claim |
|---|---|
| `22-RESEARCH.md:369-373` (Pattern 1) and A10 | "re-trigger with **`gh run rerun <run-id>`**, never a new push or an empty commit. 18-05 proved a rerun re-reads repository variables on the same SHA." |
| `18-05-PLAN.md:56-70` and `18-05-SUMMARY.md:26,34,78-79,119` | 18-05 **deliberately did not use `gh run rerun`**. It used two **empty commits**. Verbatim from the summary: *"The blocking run was triggered by an empty commit (`5973e8e`), not `gh run rerun` — v4 upload-artifact names must be unique per run id, and a re-run reuses the same run id, risking a 409 unrelated to gate mode."* |

**The 18-05 record wins on evidence** — it is a measured execution record, RESEARCH.md's sentence is
a mis-recollection of it. But the research's underlying *goal* (hold the comparison fixed) is right,
and 18-05 achieved it a different way:

> Three commits — `31dbb0d`, `5973e8e`, `835c43e` — all resolve to the identical tree hash
> `ce7ec652e09d07f9cee035410bbc05d47e0a79a8`; `git diff` between the first and last produced no
> output. `[18-05-SUMMARY.md:119-121]`

**What the planner does with this.** The Phase 22 three-verdict proof (`UNSTABLE` → `BLOCKED` →
`CLEAN`) does not need one head SHA — it needs **one tree hash**. Empty commits give that *and* a
fresh artifact namespace per run. But there is a Phase-22-specific cost the research is right about,
which 18-05 never faced:

- An empty commit **changes the PR head SHA**, so `--verify-sha` must be re-run against the new SHA,
  and the `mergeStateStatus` before/after pair is taken across two SHAs rather than one.
- `gh run rerun` holds the SHA but risks a 409 on all five artifact uploads, which would turn jobs
  red for a non-gate reason — **poisoning the third verdict**, where `CLEAN` requires all five green.

Surface both to the operator or resolve it in the plan; do not let a task quietly pick one. The
safest framing: **tree hash is the invariant that is asserted; the SHA is not.** Record
`git rev-parse HEAD^{tree}` at every verdict, exactly as 18-05 did.

---

## File Classification

| Repo / target | New or Modified File | Role | Data Flow | Closest Analog | Match |
|---|---|---|---|---|---|
| this | `.planning/phases/22-…/22-0X-evidence/` (NEW dir + ~9 artifacts) | evidence capture | file-I/O (API → disk) | `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/` | **exact** |
| this | `docs/adr/adr019-<slug>.md` (NEW, append-only) | ADR — decision record | append-only record | `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md` (shape) + `adr017…md:49-58` (the item it resolves) | **exact** |
| this | `docs/adr/README.md` (MOD, +1 row) | config — index table | append row | its own ADR-018 row, `README.md:28` | **exact** |
| this | `.planning/REQUIREMENTS.md` (MOD — **gated on Open Q1**) | requirements registry | append + recount | its own VAL-01 row (`:32`), traceability row (`:72`), coverage count (`:75`), footer (`:81`) | **exact** |
| this | `docs/adoption-guide.md` §8 (MOD, optional) | doc — procedural guide | surgical section edit | itself, `:340-416` | **exact** |
| this | `22-0X-PLAN.md` — `checkpoint:decision` task (target repo + end state) | plan task XML | human gate | `18-05-PLAN.md:242-315` (Task 3) | **exact** |
| this | `22-0X-PLAN.md` — `checkpoint:human-verify` task (the `--apply`) | plan task XML | human gate | `18-05-PLAN.md:196-240` (Task 2) | **exact** |
| this | `22-0X-SUMMARY.md` (NEW, per plan) | execution record | evidence-quoting narrative | `18-05-SUMMARY.md` | **exact** |
| this | `22-VERIFICATION.md` (NEW, at `/gsd:verify-work`) | verification record | offline audit | `.planning/phases/20-…/20-VERIFICATION.md` | exact |
| host clone | *(none expected)* — `set-required-checks.sh` is **invoked, not edited** (Open Q3: defer `--restore`) | — | — | `repos/security-platform/scripts/set-required-checks.sh` | n/a |
| pilot (remote) | `.github/workflows/pr-security.yml` on the exercise branch of `terraform-pipelines` | CI workflow caller | event-driven (PR trigger) | `docs/adoption-guide.md:162-205` (Mode B, verbatim) | **exact** |
| inline | rollback-body construction (`python3` heredoc in a task) | utility — JSON transform | transform | `set-required-checks.sh:237-244` (the six-key body) | **exact** |
| inline | `mergeStateStatus` settle-poll helper | utility — bounded poll | request-response w/ retry | **none in this project** | **none** |
| this or host (Wave 0, optional) | guard-regression check for exits 2/3/4/5 | test — offline gate | batch assert | `scripts/check-adoption-guide.sh:17-29` (three-way exit contract) | role-match |

---

## Pattern Assignments

### `22-0X-evidence/` (evidence capture, file-I/O)

**Analog:** `.planning/phases/20-template-packaging-and-adoption-docs/20-10-evidence/` — exact. That
directory is what made 20-10's dry run independently re-verifiable, and it is the shape to copy.

Its actual contents (measured): `rules-before.txt`, `rules-after.txt`, `merged.json`,
`check-runs-a.json`, `check-runs-b.json`, `analyses-a.json`, `artifacts-a.json`, `artifacts-b.json`,
`run-a.log.txt`, `run-b.log.txt`.

**Two files are one line each and are compared by `diff`** — that terseness is the point:

```text
# 20-10-evidence/rules-before.txt  (46 bytes, one line, trailing newline)
copilot_code_review,deletion,non_fast_forward
```

```text
# 20-10-evidence/rules-after.txt — byte-identical, which is what proved the dry run wrote nothing
copilot_code_review,deletion,non_fast_forward
```

**The command that produces that exact form** (`20-10-PLAN.md:188`, and `22-RESEARCH.md:639`):

```bash
gh api "repos/$REPO/rules/branches/main" --jq '[.[].type] | sort | join(",")' > "$E/rules-before.txt"
```

`sort` is load-bearing — the API does not guarantee rule order, and without it a `diff` against the
restored state is a false alarm waiting to happen. `22-RESEARCH.md:644` confirms
`copilot_code_review,deletion,non_fast_forward` is still the live value on `terraform-pipelines`
today and **matches `20-10-evidence/rules-before.txt` byte for byte**, so the Phase 22 restore
assertion has a pre-existing reference file to check itself against.

**`merged.json` is the forward-path reference.** `20-10-evidence/merged.json` already contains the
exact document a Phase 22 `--apply` will PUT to ruleset `12760793` — five rule types, the five
em-dash contexts each pinned to `integration_id: 15368`, `bypass_actors: []` carried forward, and
the `conditions.ref_name` exclude `refs/heads/dev**/**` preserved. **The plan should diff the new
`--out` document against it**; a difference means something changed on the pilot's ruleset since
2026-09-14 and must be understood before the write, not after.

**Naming convention for the Phase 22 additions**, extending the `-a` / `-b` suffix idiom to verdicts:

| File | Produced by | Asserted by |
|---|---|---|
| `ruleset-before.json` | `gh api repos/$REPO/rulesets/$RID` | is the **only** copy — no ruleset document exists in git anywhere (`22-RESEARCH.md:720`) |
| `rules-before.txt` | the `--jq` above | `diff` vs `rules-restored.txt` at phase gate |
| `variables-before.txt` | `gh variable list -R $REPO` | `GATE_MODE` absent before and after |
| `workflows-on-main.txt` | `gh api repos/$REPO/contents/.github/workflows` | expected **404** — this is Pitfall 1's evidence, capture it rather than assume it |
| `merge-state-unstable.json` / `-blocked.json` / `-clean.json` | `gh pr view … --json …` through the settle-poll | none may contain `UNKNOWN` (`! grep -rq UNKNOWN`) |
| `merge-attempt.txt` | `gh pr merge … --squash 2>&1 \| tee` | **the phase deliverable** |
| `rollback.json` | the six-key python transform | six keys exactly |
| `rules-restored.txt` | the `--jq` above | `diff` vs `rules-before.txt` → empty |
| `check-runs-<verdict>.json` | `commits/$SHA/check-runs` | five `app.id == 15368` entries per verdict |

**Before committing any of these:** `22-RESEARCH.md` V2/Information-Disclosure requires grepping
every evidence file for `gho_` / `ghp_`. 20-10 carried 380KB run logs safely; the precedent exists,
the grep is still mandatory.

---

### `docs/adr/adr019-<slug>.md` (ADR, append-only record)

**Analog:** `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md` — exact, and the
most recent, so it is the current form of the convention.

**Header block** (`adr018:1-6`, `adr017:1-5`) — four lines, no frontmatter, `**Addresses:**` names
requirement IDs followed by an em-dash gloss:

```markdown
# ADR-018: Workflow Packaging, Canonical Host, and Versioning

**Status:** Accepted
**Date:** 2026-09-14
**Addresses:** DIST-06, DIST-07, DIST-08 — a copy-paste template, a reusable `workflow_call` reference against a
stable published ref, and adoption docs covering both consumption modes
```

**Section order is fixed and is exactly four `##` headings** (`adr018:8, 40, 109, 149`; identical in
`adr017:49`):

```markdown
## Context
## Decision
## Consequences
## What was NOT verified
```

**Voice of `## Context`** — every bullet is a measured fact with its measurement attached, bolded
lead clause first (`adr018:9-13`):

```markdown
- **`OCC-github` is not a GitHub account.** `gh api orgs/OCC-github` and `gh api users/OCC-github` both 404;
  the identifier was never a real organisation or user. D-01's original text — "the canonical files move into
  THIS repo" — assumed a target that does not exist and cannot be created by renaming anything, because the
  actual account operating this project's GitHub presence is `OttawaCloudConsulting`, a User account, not an
  Organization.
```

**Voice of `## Consequences`** — leads with `**Improved:**` carrying the full measurement inline,
then `**Tradeoff — …**` paragraphs (`adr017` Consequences):

```markdown
**Improved:** measured on one pull request (PR #9, `OttawaCloudConsulting/security-platform`) across three commits (`31dbb0d`, `5973e8e`, `835c43e`) sharing one tree hash (`ce7ec652e09d07f9cee035410bbc05d47e0a79a8`) — one repository-variable flip, two verdicts, then a return to the first: all five `security / …` checks `success` under report-only (run `34668611172`), all five `failure` under blocking (run `34669534855`) on the byte-identical tree, then all five `success` again after the variable was deleted (run `34669700643`) …
```

ADR-019's `**Improved:**` is the same sentence shape with three merge verdicts substituted for three
check verdicts. Run ids, PR number, head SHA(s), tree hash and the literal refusal text all belong
inline, not in a linked file.

**`## What was NOT verified` opens with a "must not be re-litigated" paragraph, then a numbered
list** (`adr017:49-58`, `adr018:149-182`). ADR-019's list carries forward whatever Phase 22 still
cannot answer, and — per CLAUDE.md append-only — **resolves ADR-017 item 4 and ADR-018 item 7 by
reference, never by editing them**. The two items being closed, verbatim so the planner can quote
them:

```markdown
<!-- adr017-configurable-gate-mode-and-required-checks.md:58 -->
4. **The exact `pull_request` rule parameter set GitHub requires on `PUT /repos/{o}/{r}/rulesets/{id}` has been exercised only against a local dry run**, not against a live write — the operator's `leave-unrequired` decision (18-05 Task 3) means `scripts/set-required-checks.sh --apply` has never been run against this repository's own ruleset.
```

```markdown
<!-- adr018-workflow-packaging-canonical-host-and-versioning.md:177 -->
7. **Whether any repository has required checks actually enabled** — `security-platform`'s own `main` remains
```

Note both are scoped to **`security-platform`'s own `main`**. A Phase 22 exercise on
`terraform-pipelines` narrows them rather than fully closing them; ADR-019 must say which half it
closed and which half it did not. That distinction is the difference between an honest record and an
overclaim, and it is exactly the `## What was NOT verified` section's job.

---

### `docs/adr/README.md` (config, +1 index row)

**Analog:** its own last row, `README.md:28` — append one row, never reorder, never edit prior rows.

```markdown
| [ADR-017](adr017-configurable-gate-mode-and-required-checks.md) | Configurable Gate Mode and Required Checks | 2026-09-12 | Accepted |
| [ADR-018](adr018-workflow-packaging-canonical-host-and-versioning.md) | Workflow Packaging, Canonical Host, and Versioning | 2026-09-14 | Accepted |
```

Columns: `ADR | Title | Date | Status`. Link text is `ADR-0NN`, target is the bare filename (no
`./`), Title is Title Case with inline code only where the source file uses it, Status is `Accepted`.

---

### `.planning/REQUIREMENTS.md` (requirements registry) — **four edit points, not one**

**Gated on Open Question 1** (`22-RESEARCH.md:85-97`) — the planner must get the operator's framing
(`VAL-02` / re-open `CICD-04` / no requirement at all) before touching this file. If `VAL-02` is
chosen, the edit is **four places**, and a planner working from the "add a bullet" mental model will
miss three of them:

```markdown
<!-- 1. :30-32 — the family the new ID joins -->
### Validation

- [x] **VAL-01**: Full pipeline validated in this repo using branch-target PRs (no second repo required to prove it out)
```

```markdown
<!-- 2. :72 — traceability row, same two-column shape -->
| VAL-01 | Phase 19 | Complete |
```

```markdown
<!-- 3. :75 — the coverage count. 14 -> 15, in all three lines -->
**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14 ✓
- Unmapped: 0
```

```markdown
<!-- 4. :81 — the footer stamp -->
*Last updated: 2026-09-10 after v2.0 roadmap creation (Phases 14-20)*
```

Note the checkbox form is `- [x] **ID**: text` and every v1 requirement is already `[x]` — a new
`VAL-02` is added **unchecked** (`- [ ]`) and only ticked when the phase verifies, or added already
ticked at phase close. Pick one and be consistent; `22-RESEARCH.md:77` is explicit that adding a
requirement retroactively as complete is the thing to avoid doing silently.

---

### `docs/adoption-guide.md` §8 (doc, surgical section edit) — optional, gate-bound

**Analog:** itself, `:340-416`. §8 is already accurate about everything Phase 22 does; the only
honest edit is to replace an "unexercised" hedge with a measurement, or to add the bounded-window /
mandatory-restore procedure the phase invents.

The passage most likely to need updating after a successful apply (`:406-416`):

```markdown
**Self-lockout warning.** Rulesets do not auto-exempt repository admins: measured on
`security-platform`, `bypass_actors: []` and `current_user_can_bypass: "never"`. Under `blocking`
with the five checks required, a repository whose scanners always find something can never merge
into `main` again — including the pull request that would revert the change.
```

And the sentence Phase 22 may be able to strengthen from "guidance" to "measured" (`:394-402`) — the
exit-code list and *"These refusals are features, not friction — teach them as such, never as a
workaround to bypass."*

**Any edit here is gated:** `bash scripts/check-adoption-guide.sh` must still report
`PASSED 15 / FAILED 0`. That gate derives the five contexts from the host clone's YAML rather than
comparing against hard-coded copies (`check-adoption-guide.sh:10-16`), so an em-dash mangled by a
careless edit fails the gate rather than shipping silently.

---

### `.github/workflows/pr-security.yml` on the pilot exercise branch (CI caller, event-driven)

**Analog:** `docs/adoption-guide.md:162-205` — Mode B, quoted as "**This is the entire file**". Copy
it verbatim, comments included; the comments are the reason the file is correct.

```yaml
---
name: PR Security

on:
  pull_request: {}

## Workflow-level FLOOR. Any job added later inherits this by default.
permissions:
  contents: read

jobs:
  security:
    # FROZEN. `security` is this job's ID, and therefore the PREFIX of every
    # check-run name the called workflow's jobs emit, formed as
    # `<this job's id> / <called job name>`. This caller job itself emits NO
    # check run of its own. Renaming this job therefore renames every
    # branch-protection required context at once …
    name: security
    permissions:
      contents: read
      security-events: write
      actions: read          # required only for private repositories
    uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1
    # No `with:` block, deliberately.
```

**Three things the planner must not change:**

1. **`security` as the job id.** It composes all five required contexts. Rename it and the ruleset's
   five contexts become permanently pending.
2. **No `with:` block.** A bare `with: { gate_mode: ${{ vars.GATE_MODE }} }` passthrough is
   *forbidden* — an unset variable resolves to the empty string, which counts as **provided** and
   suppresses the callee's own `report-only` default (`adoption-guide.md:193-200`, ADR-017). Phase 22
   flips the mode by setting and deleting the repository variable; a `with:` block breaks that.
3. **`@v1`, no trailing version comment** (`adoption-guide.md:207-213`) — the tag moves, a
   hand-written `# v1.0.0` beside it rots.

**Why Mode B over Mode A here** (`22-RESEARCH.md:624-629`): one file instead of three, no SHA pins
to keep current, and 20-10 SC2 measured Mode B's five check-run names as **byte-identical** to Mode
A's (`diff` exit 0). Planner's discretion, but Mode B is the lighter touch.

---

### `checkpoint:decision` task (target repo + end state)

**Analog:** `18-05-PLAN.md:242-315` — Task 3, "Decide whether this repository's own `main` gets the
required checks". Same question class, one repo over. Copy its element skeleton:
`<name>` / `<files>` / `<read_first>` / `<action>` / `<decision>` / `<context>` / `<options>` (each
`<option id=…>` with `<name>`/`<pros>`/`<cons>`) / `<resume-signal>` / `<acceptance_criteria>` /
`<done>`.

**The prohibition, verbatim — carry it forward unchanged** (`18-05-PLAN.md:252`):

```xml
    Put the three options to the operator with the measured hazard stated plainly, and recommend
    `leave-unrequired`. Do NOT run `--apply` on your own initiative under any circumstance.
```

**The `<decision>` element states the write in API terms, not in intent terms** (`:268-271`):

```xml
  <decision>
    Whether to apply `bash scripts/set-required-checks.sh --apply` to ruleset 14243983 on
    `OttawaCloudConsulting/security-platform`, making the five `security / …` contexts required on `main`
    and adding the `pull_request` rule.
  </decision>
```

**The `<option>` shape — the recommended option is labelled inside its own `<name>`** (`:291-294`):

```xml
    <option id="leave-unrequired">
      <name>RECOMMENDED — leave `main` un-required; ship the script and the guidance</name>
      <pros>No lockout risk. CICD-04 is satisfied by provided-and-proven configuration. …</pros>
      <cons>This repository's own `main` remains pushable directly, so ADR-002's PR requirement stays unenforced here. …</cons>
    </option>
```

**The `<resume-signal>` names the exact allowed answers and any precondition** (`:307`):

```xml
  <resume-signal>Select: leave-unrequired, require-report-only, or require-and-block. If you select require-report-only, add the bypass actor in the GitHub UI first and say so — Claude will then run the script with `--verify-sha` and the lockout acknowledgement, and read back `rules/branches/main`.</resume-signal>
```

> **SUPERSEDED (2026-09-16) by `22-CONTEXT.md`.** The paragraph below was written before the
> operator's decisions were captured. `22-CONTEXT.md` LOCKS the target (`terraform-pipelines`) and
> the end state (restore); locked decisions are non-negotiable, so the A/B/C/D matrix and the
> restore/keep pair below are NOT offered as selectable options. `22-01-PLAN.md` Task 1 offers
> exactly two answers, `proceed` and `halt` — an execution-time go/no-go on acting on the record,
> not a re-opening of the choice. **The `<context>` requirements below still apply in full**: both
> measured second-order effects must be stated, and option C's mechanical exclusion is still the
> right framing for the rationale. Take the element skeleton and the `<context>` facts from here;
> take the option set from `22-CONTEXT.md`.

**Phase 22 substitutes the target-repo matrix for the three 18-05 options** — A `terraform-pipelines`
/ B `security-platform` / C `aws-zabbix-monitoring-solution` / D throwaway sandbox
(`22-RESEARCH.md:163-202`), plus a **second** decision the operator must answer in the same task
(Open Q4): end state = **restore** (recommended) or **keep required**. The `<context>` element must
carry the two measured facts that make the choice real rather than rhetorical:

- `terraform-pipelines`' `main` has **no `.github/workflows/`** (404), so left in place the five
  required checks sit permanently pending and lock every future PR (Pitfall 1);
- `terraform-pipelines`' `main` shows **direct pushes today** (`c490bed0` has zero associated PRs),
  and the script always adds a `pull_request` rule, so the exercise removes the operator's
  direct-push shortcut for its duration (`22-RESEARCH.md:204-216`).

Option C is ruled out **mechanically**, not by preference: `rulesets` returns `[]` and the script has
no `POST` create path (`adoption-guide.md:379-383`). Say that rather than framing it as a judgement.

---

### `checkpoint:human-verify` task (the `--apply` itself)

**Analog:** `18-05-PLAN.md:196-240` — Task 2. Element skeleton: `<name>` / `<files>` /
`<read_first>` / `<action>` / `<what-built>` / `<how-to-verify>` (a numbered list the operator
performs *themselves*) / `<resume-signal>` / `<acceptance_criteria>` / `<done>`.

```xml
  <how-to-verify>
    1. Open the PR's checks page and use the run history: confirm one attempt where all five
       `security / …` checks are RED and a later attempt where all five are GREEN.
    2. Confirm both attempts are on the SAME commit SHA. …
    5. Run `gh variable list -R OttawaCloudConsulting/security-platform` yourself and confirm no `GATE_MODE`
       remains. The repository must be back in report-only.
  </how-to-verify>
```

**Phase 22 inverts one thing about this analog.** In 18-05 the operator *verified* and Claude *ran*.
Here the operator **runs the write** and Claude verifies on both sides — because the executor's
auto-mode Bash classifier has denied this exact script **twice**, measured (Pitfall 6;
`20-10-SUMMARY.md:355-370` records the resolution: the orchestrator ran the exact recorded command
directly). So the task body carries the literal command text for the operator to paste:

```bash
bash repos/security-platform/scripts/set-required-checks.sh \
  --repo OttawaCloudConsulting/terraform-pipelines \
  --ruleset 12760793 \
  --verify-sha "$SHA" \
  --out /absolute/path/to/22-0X-evidence/merged.json \
  --apply --yes-i-understand-lockout
```

**Both `--repo` and `--ruleset` are mandatory in every invocation, even when one equals its default**
(Pitfall 4): the defaults are *independent* — `REPO` defaults to `…/security-platform` and
`RULESET_ID` to `14243983`, so `--repo` alone points at the wrong ruleset and fails with a bare 404.

**`--out` must be absolute.** The script does `cd` to its own repo root at line 67:

```bash
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
```

A relative `--out` therefore lands under `repos/security-platform/`, not under the caller's cwd.
20-10 hit exactly this and recorded both working invocation shapes (`20-10-SUMMARY.md:337, 366`).

**The 422 instruction, carried forward verbatim from `18-05-PLAN.md:258-261`:**

```xml
    If the PUT returns 422, report the raw error body and stop: the `pull_request` parameter set is
    an unverified assumption and a 422 changes no state.
```

---

### Rollback-body construction (inline `python3`, transform)

**Analog:** `set-required-checks.sh:237-244` — the forward path's own six-key body. The rollback must
mirror it exactly, because `GET /rulesets/{id}` returns server-owned fields the PUT schema rejects
(`id`, `node_id`, `source`, `source_type`, `created_at`, `updated_at`, `_links`,
`current_user_can_bypass`) — Pitfall 2, the single most likely way to turn a clean rollback into a
second incident.

```python
# set-required-checks.sh:237-244 — the canonical six-key PUT body
body = {
    "name": doc["name"],
    "target": doc["target"],
    "enforcement": doc["enforcement"],
    "conditions": doc["conditions"],
    "bypass_actors": doc.get("bypass_actors", []),
    "rules": kept,
}
```

Three details to carry, not paraphrase:

1. **`bypass_actors` via `.get(…, [])`, never synthesised.** V4/Elevation-of-Privilege in the
   research's threat table, and `adoption-guide.md:400` — an invented `actor_id` grants someone merge
   bypass on `main`.
2. **The heredoc is quoted (`<<'PY'`)** — `set-required-checks.sh:188-189` says why in a comment:
   *"quoted heredoc — the em dash and `$` fragments must never be shell-expanded before python sees
   them."* The same applies to the `CONTEXTS` heredoc at `:173-179`.
3. **`encoding="utf-8"` and `ensure_ascii=False` on both ends** — the five contexts contain
   U+2014. Escaped ASCII would round-trip through JSON correctly but produces unreadable evidence
   files and invites a hand-edit that breaks a codepoint.

**Drop-detection is worth mirroring too** — `set-required-checks.sh:249-254` refuses to write rather
than silently regress:

```python
dropped = set(before_types) - set(after_types)
if dropped:
    print("ABORT: merged document would DROP pre-existing rule type(s): %r — "
          "this is exactly the P-05 regression; refusing to write the output "
          "file." % sorted(dropped), file=sys.stderr)
    sys.exit(3)
```

A rollback that reconstructs from the captured document cannot drop anything by construction — but
asserting it anyway costs three lines and converts an assumption into a check.

**Read-back after the rollback PUT uses the authoritative endpoint only**
(`set-required-checks.sh:282-286`):

```bash
echo "Read-back: repos/${REPO}/rules/branches/main rule types:"
gh api "repos/${REPO}/rules/branches/main" --jq '.[].type'
```

Never `branches/main/protection` — it 404s **by design** on a ruleset-governed repo, and that 404 is
a false negative (script header `:63-66`; ADR-017; 14-02).

**Conditional restore (Pitfall 3).** The restore task must branch on whether the forward PUT actually
returned 200. A 422 means the ruleset was never modified, so re-PUTting a byte-identical document
would produce a misleading "restored" line in the evidence. The task must say which branch it took.

---

### Settle-poll helper — **no analog, see the No Analog section**

---

### `22-0X-SUMMARY.md` (execution record)

**Analog:** `18-05-SUMMARY.md` — exact. Frontmatter carries `truths` and `artifacts` lists; the body
leads with a single bolded sentence carrying the whole measurement:

```markdown
**One `gh variable set GATE_MODE=blocking` flip, followed by an empty commit, turned PR #9's five
`security / …` checks from `success` to `failure` on a byte-identical tree (hash `ce7ec652…`), with
all five artifacts, all six SARIF categories, and all eleven upload-verify assertions still landing —
then `gh variable delete` and a second empty commit restored the same five checks to `success` with
zero YAML ever touched.**
```

Also worth copying: 18-05's per-verdict comparison table with the tree hash as a row
(`18-05-SUMMARY.md:119`), and its explicit deviation log — 18-05 recorded a mid-plan surprise and
what it did about it (`:238-242`) rather than smoothing it out.

---

## Shared Patterns

### 1. Capture before anything, restore regardless of outcome

**Source:** `20-10-evidence/` shape + `18-05-PLAN.md:104-108`
**Apply to:** every live-write task in the phase

```markdown
**Delete the variable unconditionally.** `gh variable delete GATE_MODE` runs whether the measurement
succeeded, failed, or was interrupted. A repository left in blocking is the worst possible outcome of a
half-finished plan — worse than no measurement at all. If anything goes wrong mid-plan, delete the
variable FIRST, then report.
```

Phase 22 extends this to the ruleset: the restore task is **not conditional on success**, only its
*branch* is (Pitfall 3). And the capture runs **before the decision checkpoint**, not after it —
`ruleset-before.json` is the only copy of that document that will ever exist (`22-RESEARCH.md:720`).

**The exercise PR and its branch are part of the restore, not leftovers.** 20-10's PRs #12/#13 were
left **CLOSED, not merged, with their head branches deleted** (`22-RESEARCH.md:129-132, 726`) —
follow that precedent, and state it in the restore task's acceptance criteria. What is *not*
reversible and must be disclosed at the decision checkpoint: the SARIF analyses the exercise run
uploads into the target repo's code-scanning tab persist and are not trivially deletable.

### 2. Operator-executed write, Claude-executed verification — and Claude re-verifies independently

**Source:** `18-05-PLAN.md:252, 258-261`; `20-10-SUMMARY.md:370-380`
**Apply to:** the `--apply` checkpoint and the merge attempt

20-10 did not accept the orchestrator's report of the dry-run result: *"This session independently
re-verified the outcome read-only (not trusting the orchestrator's report at face value), per the
anti-slop discipline this project follows."* Phase 22 does the same after the operator's `--apply`:
re-read `rules/branches/main` and the ruleset's required contexts from the API, rather than recording
what the operator pasted.

### 3. The five byte-exact contexts are derived, never typed

**Source:** `set-required-checks.sh:173-179` and `:203-210`; `check-adoption-guide.sh:10-16`
**Apply to:** every task, every doc edit, every evidence assertion

```bash
  done <<'CONTEXTS'
security / SAST — Semgrep CE
security / IaC — Checkov
security / SCA — Trivy Filesystem
security / Container — Trivy Image
security / Secrets — Gitleaks
CONTEXTS
```

Separator is **EM DASH U+2014** — never a hyphen, never U+2013. The code-scanning `analyses`
endpoint disagrees on case for two of five (`checkov`/`Checkov`, `Gitleaks`/`gitleaks`); branch
protection matches the **check-run** name, from `app.id == 15368`. A one-codepoint error produces a
permanently-pending required check with no runtime signal anywhere.

**Five, not six.** ADR-017: *"If the number six appears anywhere else in this project as the size of
the required-check set, it is wrong."* The caller job emits no check run of its own.

### 4. Guards are features — never work around an exit code

**Source:** `set-required-checks.sh:46-66` (exit table), `:129-152` (the pre-network guards);
`adoption-guide.md:404`
**Apply to:** every invocation in every task

| Exit | Meaning |
|---|---|
| 0 | dry run produced its output, or `--apply`'s PUT **and** read-back both succeeded |
| 1 | generic failure surfaced from `gh api` / `python3` |
| 2 | fetched/input document has no `rules` key (missing ≠ empty) |
| 3 | merged document would drop a pre-existing rule type — never written anywhere |
| 4 | `--apply` without `--verify-sha` |
| 5 | `--apply` without `--yes-i-understand-lockout` |
| 6 | `--verify-sha` found a context missing, or with the wrong app id |

Exits 4 and 5 are checked **before any network call** (`:129`), which is what makes them safe to
exercise as a Wave 0 regression. *"These refusals are features, not friction — teach them as such,
never as a workaround to bypass."* A plan that routes around a guard has misunderstood the phase.

### 5. Three-way exit contract for any new offline gate

**Source:** `check-adoption-guide.sh:17-29`
**Apply to:** the optional Wave 0 guard-regression script, if the planner writes one as a file

```bash
# Exit codes — the same three-way contract as check-workflow-uploads.sh:
#   0  all checks passed
#   1  at least one assertion failed, including "guide not found" — the
#      guide is a pending deliverable at this commit, not an infra problem
#   2  the canonical host clone repos/security-platform/.github/workflows/
#      is absent, so the frozen strings cannot be derived — an
#      INFRASTRUCTURE signal; never fall back to hard-coded strings
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/check-adoption-guide.sh [path/to/guide.md]
```

Assertion failure (1) and infrastructure absence (2) are never conflated, and there is deliberately
**no hard-coded fallback** — a silent fallback that "mostly works" is the failure mode the gate
exists to prevent.

### 6. `bash script.sh`, never `./`, never `chmod +x`

**Source:** `.claude/rules/defensive-protocol-v2-anti-slop.md`; restated in both script headers
**Apply to:** every command string the plan writes, including the ones the operator pastes

### 7. No `|| true` on anything security-relevant

**Source:** anti-slop rule; `22-RESEARCH.md:705-709`
**Apply to:** every command in every task

The single tolerated exception the research identifies is `gh variable delete GATE_MODE || true`
(deleting an absent variable is not a failure) — and it suggests the cleaner form instead:

```bash
gh variable list -R "$REPO" --json name --jq '.[].name' | grep -qx GATE_MODE && \
  gh variable delete GATE_MODE -R "$REPO"
```

`--json name` and `--jq` are supported on `gh variable list` in 2.101.0 `[VERIFIED: gh variable list
--help, this session]`. If a plan prefers the plain form, `gh variable list -R "$REPO" | grep -q
'^GATE_MODE'` is equivalent.

Prefer this. It is guard-then-act rather than act-then-swallow, and it leaves a readable trace either
way.

### 8. Evidence quotes API output; it never narrates it

**Source:** anti-slop evidence standards; `18-05-SUMMARY.md` throughout
**Apply to:** SUMMARY, VERIFICATION, and ADR-019

Any evidence artifact containing `UNKNOWN` is not evidence (Pitfall 9). Any claim of the form "all
five" must be backed by output showing five.

---

## No Analog Found

| File / construct | Role | Data Flow | Reason |
|---|---|---|---|
| `mergeStateStatus` settle-poll helper (inline per task, or one small bash function) | utility | request-response with bounded retry | **Nothing in this project polls a GitHub API for an asynchronously-computed value.** 18-05 read check-run conclusions, which are settled by the time the run completes; mergeability is computed in a background job kicked off by the first query, so the first response is frequently `UNKNOWN` or stale. There is no prior art to copy. Use `22-RESEARCH.md:595-603` as the specification — bounded loop, compares against the previously-recorded value, and **fails loudly on timeout** (`exit 1`, never `\|\| true`, never a bare `sleep` plus a single read). **Fix one defect in that spec before copying it:** its loop exits on `S != UNKNOWN && S != prev`, but its post-loop guard only tests `[ "$S" != UNKNOWN ]`. If all 20 iterations exhaust with `S == prev` — settled-looking but stale — the guard passes and the task proceeds on the stale value, which is precisely what arms Pitfall 7. The post-loop assertion must be `[ "$S" != UNKNOWN ] && [ "$S" != "$prev" ] \|\| exit 1`. A stale `BLOCKED` read is what lets `gh pr merge` succeed and land `security.yml` on a real repository's `main`. |
| `gh pr merge` refusal text | — | — | Never exercised in this project; wording is `[ASSUMED]` (A5). **Capture `2>&1`, do not predict.** The refusal *is* the phase deliverable. |
| `POST /repos/{o}/{r}/rulesets` (create path) | — | — | No script implements it and `adoption-guide.md:379-383` says so plainly. Only needed if the operator picks target C or D at the decision checkpoint — in which case it is a hand-written `gh api --method POST`, unprecedented in this project, and the plan should say so rather than imply the script covers it. |

---

## Notes the planner should not have to rediscover

- **`22-VALIDATION.md` already exists** in this phase directory (`nyquist_compliant: false`,
  `wave_0_complete: false`, eight per-task rows all `TBD`/`⬜ pending`). Populate its `Task ID`,
  `Plan` and `Wave` columns rather than inventing a parallel test map.
- **`--verify-sha` would pass on `terraform-pipelines` right now** at
  `6e8975f22232659c1403de452d559d6c97ebb1eb` — all five `app.id 15368` contexts still return today
  (`22-RESEARCH.md:125-128`). That SHA belongs to a closed PR whose branch is deleted, so it is not
  the exercise SHA; it is useful as a rehearsal of the preflight that writes nothing. **But it is
  still a `set-required-checks.sh` invocation**, and Pitfall 6's two measured denials were for a
  plain `--out` dry run, not for `--apply` — so the rehearsal must be operator- or
  orchestrator-run at a checkpoint exactly like the write is. It cannot be an autonomous executor
  task.
- **Research is stamped `Valid until 2026-09-23`** and says outright: re-run the Live State reads at
  plan time rather than trusting the snapshot. A4 in particular — Semgrep's 6 findings on
  `terraform-pipelines`, measured 2026-09-14 — is what makes the phase feasible without seeding
  anything. If that number is now zero, the target choice changes.
- **`set-required-checks.sh` is invoked, never edited.** Open Q3 recommends deferring a `--restore`
  flag: it would be a commit in `repos/security-platform` (a separate repo, separate PR, separate
  tag cycle), plus an `adoption-guide.md` §8 update here, plus the standing gate re-run — scope the
  phase does not need to close the audit finding.

---

## Metadata

**Analog search scope:** `docs/adr/`, `docs/adoption-guide.md`, `scripts/`,
`repos/security-platform/scripts/`, `repos/security-platform/.github/workflows/`,
`.planning/REQUIREMENTS.md`, `.planning/phases/18-…/`, `.planning/phases/20-…/` (plans, summaries,
`20-10-evidence/`), and the three clones under `repos/`
**Files read in full or in targeted ranges:** 16
**Live GitHub state:** not re-measured — this agent is read-only and `22-RESEARCH.md` measured it on
2026-09-16
**Pattern extraction date:** 2026-09-16
