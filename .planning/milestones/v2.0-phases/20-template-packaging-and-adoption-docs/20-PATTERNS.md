# Phase 20: Template Packaging and Adoption Docs - Pattern Map

**Mapped:** 2026-09-13
**Files analyzed:** 14 (6 in this repo, 8 in `repos/security-platform`)
**Analogs found:** 12 / 14 (10 exact, 2 role-match, 2 none)

## READ THIS FIRST: this phase spans TWO git repositories

`.gitignore` in this repo is exactly one line: `repos/`. `repos/security-platform/` is a **separate
clone with its own `.git` and its own remote** (`OttawaCloudConsulting/security-platform`). Under the
AMENDED D-01 it is the **canonical host repo**.

Consequence for the planner: **no single commit can touch both repos.** Every plan must state which
repo it operates in. Work in `repos/security-platform/` is a separate branch → PR → merge → tag cycle
from work in `security_solution`. The `Repo` column in the classification table below is load-bearing,
not decorative.

## Reconciliation: RESEARCH.md was written BEFORE the D-01 amendment

RESEARCH.md (2026-09-13) assumed the canonical workflow moves into *this* repo. CONTEXT.md D-01 was
AMENDED (2026-09-14) to make `security-platform` the canonical host. The planner must apply these
reconciliations rather than re-opening them or planning a checkpoint for an already-decided question.

| RESEARCH.md item | Status under amended D-01 | What the planner does instead |
|---|---|---|
| **Q1** ("where does the canonical workflow live?" — BLOCKING, `checkpoint:decision` recommended) | **RESOLVED.** Host = `OttawaCloudConsulting/security-platform` (Research Q1 Option B) | Do **not** plan a Q1 checkpoint. Do not create a new GitHub repo |
| **C-2** (this repo has no GitHub home; must be created and pushed) | **MOOT.** Nothing is published from this repo | No `gh repo create`, no `origin` re-point, no 320-commit push |
| **Pitfall 7 / A6** (gitleaks: 16 findings in 320 commits; GH013 push protection) | **MOOT.** `security-platform` is already public with no history to scrub | Drop the history-scan preflight task entirely |
| **C-6** (`v1.1` tag collides with the blueprint document version) | **MOOT.** `security-platform` has **0 tags, 0 releases** | Plain `v1` + `v1.0.0` are free in the host repo. No `workflows-v1` namespace needed |
| **Pattern 4** (private-host access setting) | **MOOT.** Host is already public | No Settings → Actions → General step |
| **Q5** ("does `security-platform` become consumer #1?") | **INVERTED.** It is the *producer*. It keeps `uses: ./.github/workflows/security.yml` | Keep the relative ref (`pr-security.yml:44`). Its own PRs keep exercising workflow changes pre-tag |
| **Pattern 5 "sync consequence"** + "the cost that is easy to miss" (tag-before-proof inversion) | **MOOT.** One copy exists, in the host, and `fixtures/` still proves it on every host PR before any tag is cut | Delete that concern from the plan |
| **Pattern 5** "security-platform's own file may keep the script calls" | **VOID.** There is no second copy. P-1…P-6 apply to `security-platform`'s own `security.yml` | Portability pass lands in the host repo |
| **Pattern 5** sync-mechanism discretion (CONTEXT "Claude's Discretion" bullet 1) | **INVERTED.** The only sync burden left is: any template/snippet embedded in *this* repo's docs tracking the host's canonical YAML | Prefer "no embedded copy — link to the raw URL at a tag" (see `templates/` note below) |
| **Research "Recommended file layout"** (one tree with `.github/` + `docs/` + `templates/`) | **SPLIT.** `.github/` stays in the host; `docs/` stays here | Use the two-repo layout in the classification table |
| **C-1 / ROADMAP SC2** string `uses: OCC-github/security_solution/...` | **UNUSABLE** (`OCC-github` 404s; account is a User named `OttawaCloudConsulting`) | Every `uses:` in every deliverable reads `OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1`. Resolve every `<HOST>` placeholder in RESEARCH.md excerpts to `security-platform` |

**Still open and genuinely undecided** (keep these as checkpoints): **Q2** (private consumers go red —
needs the A1 measurement then a decision), **Q3** (blueprint §Complete GitHub Actions Workflow at
L1456), **Q4** (pilot repos), **A4** (Dockerfile pathspec must be measured before shipping).

**Tension the planner must resolve, not inherit:** amended D-01 says this repo keeps "the copy-paste
template (referencing/embedding the same canonical YAML, kept in sync manually)" **and** that it "does
not host a second copy as source of truth." A full `templates/security.yml` here would violate the
second clause. Mode A is coherent as the three `curl` commands against a tag (Research Code Example 3)
— note Mode A copies `pr-security.yml` *with* its relative `uses: ./`, which works precisely because
`security.yml` is copied alongside it. Only the Mode B caller (a 1-line diff from `pr-security.yml`)
plausibly justifies a small checked-in file here.

## File Classification

| Repo | New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| this | `docs/adoption-guide.md` (NEW, D-03) | doc — procedural guide | copy-paste + verify-output | `docs/milestone-1-workstation/INSTALLATION_GUIDE.md` | exact |
| this | `docs/adr/adr018-<slug>.md` (NEW) | ADR — decision record | append-only record | `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` | exact |
| this | `docs/adr/README.md` (MOD, +1 row) | config — index table | append row | itself, ADR-017 row (last line) | exact |
| this | `docs/development-security-stack-option-1.md` (MOD, **Q3-gated**) | doc — reference blueprint | surgical section edit | its own `## Complete GitHub Actions Workflow` (L1456) and `### Phase 2 — CI/CD Security Gate` (L2008) | role-match |
| this | `CLAUDE.md` (MOD, optional) | config — project instructions | append bullet | its own `## Project Structure` list (L9-15) | exact |
| this | `templates/pr-security.reusable.yml` (NEW, **optional** — see tension above) | workflow template | request-response (CI trigger) | `repos/security-platform/.github/workflows/pr-security.yml` | exact |
| host | `.github/workflows/security.yml` (MOD — P-1…P-6 portability pass) | CI workflow (callable) | event-driven / batch scan | `repos/security-platform/scripts/detect-npm.sh` (for the inlined detectors) + its own container job L817-909 (for the guard shape) | exact |
| host | `.github/workflows/pr-security.yml` (MOD — stale comment L58-61) | CI workflow (caller) | request-response | itself | exact |
| host | `.github/dependabot.yml` (MOD — stale comment L4-5) | config | scheduled | itself | exact |
| host | `scripts/check-detector-parity.sh` (NEW — Wave 0 harness) | test/verification script | batch assert | `scripts/check-workflow-uploads.sh` (exit-code contract, `REPO_ROOT` cd) + `scripts/smoke-scans.sh` (FAILURES array, `require_*` assertions) | role-match |
| host | `scripts/check-workflow-uploads.sh` (VERIFY, likely unmodified) | test/verification script | batch assert | itself | exact |
| host | `cicd/README.md` + `cicd/.github/workflows/security.yml` (MOD — **stale third copy**, see §New Finding) | doc + workflow template | copy-paste | itself (this IS the pre-existing DIST-06 shape) | exact |
| host | git tags `v1` / `v1.0.0` + `gh release` | release artifact | one-shot publish | **none** (0 tags, 0 releases in host) | no analog |
| host | release notes body (`--notes` vs `--notes-file`) | doc | one-shot | **none** (no `docs/` dir in host) | no analog |

## Pattern Assignments

### `docs/adoption-guide.md` (NEW, this repo) — doc, procedural

**Analog:** `docs/milestone-1-workstation/INSTALLATION_GUIDE.md` (exact: a numbered, copy-paste
rollout guide with a verify column, expected output, a summary table and a troubleshooting section).
**Secondary analog:** `docs/milestone-1-workstation/DEVELOPER_GUIDE.md` §Rolling Out to New
Repositories (L142-190) for the numbered per-repo rollout shape.

**Opening + prerequisites-with-verify pattern** (`INSTALLATION_GUIDE.md` L1-19):

```markdown
# Milestone 1: Installation Guide

Step-by-step installation of the developer workstation security stack. After completing this guide you will have pre-commit hooks enforcing code quality on every commit, ...

## Prerequisites

| Requirement | Minimum | Verify |
|-------------|---------|--------|
| macOS or Linux | macOS 13+ / Ubuntu 22.04+ | `uname -a` |
| Homebrew | 4.x | `brew --version` |

All tools installed below are free and open-source. No accounts, logins, or API keys required.

---
```

Copy this shape for §2 Preflight. The "no accounts, no API keys" line has a direct Phase 20 analogue
that RESEARCH.md calls "a genuine selling point": **no secrets to provision — `GITHUB_TOKEN` only.**

**Command-then-expected-output pattern** (`INSTALLATION_GUIDE.md` L28-35) — this is the convention
RESEARCH.md's "Key insight" demands (every failure in this domain is silently green, so commands must
ship with expected output):

````markdown
Verify:

```bash
pre-commit --version
# Expected: pre-commit 4.5.0 or higher
```
````

Apply to all four preflight probes (Research Code Example 5): `# Expected: 404 "no analysis found" → code scanning AVAILABLE`, `# Expected: 403 → private, see §11`, etc.

**Numbered rollout-steps pattern** (`DEVELOPER_GUIDE.md` L144-178) — bold imperative lead, fenced
command, prose only where a command cannot carry it:

````markdown
### Step-by-Step

1. **Copy the canonical config:**

   ```bash
   cp repos/security-platform/.pre-commit-config.yaml /path/to/new-repo/
   ```

2. **Create linter configs** (`.markdownlint.json`, ...) based on the repo's file types.
...
6. **Fix or suppress violations** — fix genuine issues in source, suppress false positives ...
7. **Commit** the config files and any fixes.
````

**Summary-table + troubleshooting pattern** (`INSTALLATION_GUIDE.md` L315-346):

````markdown
## Installed Tool Summary

| Tool | Version | Install Method | Purpose |
|------|---------|---------------|---------|
| pre-commit | 4.5.0 | pip | Hook framework |

---

## Troubleshooting

### Hook fails to download on first commit

Pre-commit downloads hook environments on first run. If it fails:

```bash
pre-commit clean    # clear cached environments
```
````

Use `### <symptom>` subsections (not a wide table) for the 8 pitfalls — the existing guide proves the
symptom-as-heading form, and it is greppable.

**"What to Expect" pattern** (`DEVELOPER_GUIDE.md` L180-187) — the exact home for 19-06's
"green ≠ clean" finding and Pitfall 5's "a consumer with pre-existing HIGH/CRITICAL cannot go blocking
until it fixes them."

**Markdown lint constraints** (`.markdownlint-cli2.yaml`, enforced per commit per RESEARCH §Sampling
Rate). Disabled: MD013 (line length — long prose lines are fine), MD022/MD031/MD032/MD036 (blank-line
and bold-as-label rules), MD024, MD029, MD040 (code fences need no language), MD060, MD018.
**Still ENABLED and must pass:** MD001 (no skipped heading level), MD009 (no trailing spaces),
MD010 (no hard tabs), MD025 (exactly one H1), MD034 (no bare URLs — wrap in `<>` or `[]()`;
this bites the `raw.githubusercontent.com` URLs in the Mode A `curl` block, which are inside a fence
and therefore exempt, but any prose URL is not).

---

### `docs/adr/adr018-<slug>.md` (NEW, this repo) — ADR

**Analog:** `docs/adr/adr017-configurable-gate-mode-and-required-checks.md` (exact — same author, same
phase-close purpose, 15 KB). ADR-016 shares the identical five-heading skeleton, so the shape is
established, not one-off.

**Header pattern** (ADR-017 L1-5):

```markdown
# ADR-017: Configurable Gate Mode and Required Checks

**Status:** Accepted
**Date:** 2026-09-12
**Addresses:** CICD-04, CICD-06 — a repository-wide switch between advisory and enforcing scan behaviour, and the required-status-check list that makes the enforcing state actually block a merge
```

ADR-018 → `**Addresses:** DIST-06, DIST-07, DIST-08 — …`.

**Section skeleton** (byte-identical across ADR-016 and ADR-017 — do not invent a sixth heading):

```markdown
## Context
## Decision
## Consequences
## What was NOT verified
```

**Context-bullet pattern** (ADR-017 L9) — bold claim sentence first, then the measured evidence and the
consequence in the same bullet:

```markdown
- **A called `workflow_call` reads the CALLING repository's variables, but a caller's workflow-level `env` is NOT propagated into the callee.** That asymmetry makes a repository variable the only mechanism that lets a copy-paste consumer switch modes without editing YAML — an `env:` block on the caller's workflow would have to be repeated inside the callee to have any effect, which defeats the "no YAML edit" goal outright.
```

**Decision-bullet pattern with rejected alternative inline** (ADR-017 L19) — every decision states what
was considered and why it lost:

```markdown
- **The flag is a single global string enum `blocking` | `report-only`, defaulting to `report-only` (D-01/D-02/D-03)** — not a boolean and not per-job flags. A boolean was considered and rejected: it reads as clear at the call site but forces every future third mode ... into a breaking rename.
```

**Correction-bullet pattern** (ADR-017 L31-32) — this is how ADR-017 recorded the five-not-six
correction without editing ADR-002/D-06, and it is exactly the shape ADR-018 needs for C-1 (the
`OCC-github` path), C-3/C-4 (the portability pass vs the "no scanning changes" boundary), C-5 (five
contexts) and the D-01 amendment itself:

```markdown
- **Correction to D-06: the required-check set is FIVE contexts, not the six D-06 originally stated, because the `security` caller job emits no check run of its own.** Three independent observations back this, cited by identifier so a reader can go and look: ...
```

**Consequences-with-measurement pattern** (ADR-017 L37) — `**Improved:**` then run IDs, SHAs and tree
hashes; then one `**Tradeoff — …**` paragraph per accepted cost.

**"What was NOT verified" pattern** (ADR-017 L51-56) — opens by fencing off what *was* measured ("What
WAS measured and must not be re-litigated: …"), then a numbered list of open items **in those words**.
ADR-018's list must carry A1 (private upload 403 inferred, not measured), A3 (fork vars, citation
only), A4 (Dockerfile pathspec) unless measured, and A5 (account plan unknown).

---

### `docs/adr/README.md` (MOD, this repo) — index

**Analog:** itself. Append exactly one row after the ADR-017 row; do not touch the preceding rows
(CLAUDE.md: ADRs are append-only).

**Row pattern** (last line of the index table):

```markdown
| [ADR-017](adr017-configurable-gate-mode-and-required-checks.md) | Configurable Gate Mode and Required Checks | 2026-09-12 | Accepted |
```

Note the file-naming convention the link encodes: `adrNNN-kebab-case-title.md`, **no** separator
between `adr` and the number. This file's own intro line ("prompted ADR-001 through ADR-012") is
**not** stale — it correctly scopes which ADRs came out of the red-team findings; leave it alone. The
stale count is in `CLAUDE.md` L10, "(ADR-001 through ADR-014)", which is a legitimate one-line MOD
there, not here.

---

### `docs/development-security-stack-option-1.md` (MOD, Q3-gated, this repo) — reference doc

**Analog:** its own structure. Two anchors, measured:

- `L1456: ## Complete GitHub Actions Workflow` — the stale illustrative template (Research
  Anti-Patterns: `@<SHA>` literal placeholders, `--config auto`, `|| true`, `on: push: branches:
  [main]`, no `gate_mode`, no `workflow_call`). Q3 recommendation (a): retitle as an illustration and
  point at the canonical file.
- `L2008: ### Phase 2 — CI/CD Security Gate (GitHub Actions)` … `L2069: ### Phase 3` — the existing
  branch-protection guidance the adoption guide **cross-references rather than restates**.

**Editing constraints (CLAUDE.md §Editing Guidelines, non-negotiable):** preserve the ASCII diagrams;
preserve the 4-phase layered structure (Workstation → CI/CD → K8s Infrastructure → Runtime) — so the
`### Phase N —` heading sequence at L2008/L2069 must survive intact; preserve the tool coverage
matrices and the comparison table. The adoption guide's new "which jobs apply to which repo type"
table is a **new table in a new file** — do not rewrite the blueprint's matrices.

---

### `CLAUDE.md` (MOD, optional, this repo) — project instructions

**Analog:** its own `## Project Structure` bullet list (L9-15):

```markdown
- `docs/adr/` — individual architectural decision records (ADR-001 through ADR-014); see `docs/adr/README.md` for index
- `docs/ARCHITECTURE_AND_DESIGN.md` — extracted architecture reference
```

Add one bullet for `docs/adoption-guide.md` in the same `- path — description` shape. RESEARCH.md also
flags that a reader arriving at a "reference documentation project" needs to be told the canonical
workflows live in `security-platform`, not here — one sentence, same section.

---

### `repos/security-platform/.github/workflows/security.yml` (MOD) — CI workflow, portability pass

**This is the highest-risk file in the phase.** 1070 lines, five FROZEN job names, eleven gated
tolerances. RESEARCH Pattern 5 gives the exact line numbers (P-1…P-6). The analogs below are the
patterns the new code must match.

**Analog for the three inlined detectors:** `scripts/detect-npm.sh` (the file being inlined). Preserve
its comment block verbatim when inlining — the pathspec rationale is load-bearing and already measured:

```bash
# scripts/detect-npm.sh L12-18
# Pathspec: '*package-lock.json'. Git's default (non-':(glob)') pathspec
# wildcards already cross '/', so a single leading '*' matches every depth.
# The two wrong forms, both measured (16-RESEARCH Pitfall 9):
#   'package-lock.json'      -> root-anchored, matches nothing in a subdirectory
#   '**/package-lock.json'   -> matches nested files ONLY, misses the repo root
# A missed manifest would produce a "SKIP:" line on a repo that really does
# have npm dependencies — a false pass that is invisible in the log.
```

The three measured pathspecs, one line each (read live from the scripts):

```bash
repos/security-platform/scripts/detect-npm.sh:39:       git ls-files -- '*package-lock.json' | grep -v -e '/node_modules/' -e '^node_modules/'
repos/security-platform/scripts/detect-python.sh:37:   git ls-files -- '*requirements*.txt'
repos/security-platform/scripts/detect-terraform.sh:35: git ls-files -- '*.tf'
```

**The two output strings are a contract, not prose** (`detect-npm.sh` L43, L51) — `smoke-scans.sh`,
the adoption guide and the SC1 live check all quote them. Keep byte-identical, em dash U+2014 included:

```bash
echo "SKIP: no package-lock.json found — npm sub-scan not applicable to this repository"
...
echo "FOUND ${count} npm lockfile(s):"
```

**The `|| true` exception is pre-authorised and scoped** (`detect-npm.sh` L30-34). The project rule
bans silent fallbacks; this is the one sanctioned instance and the inlined block must carry the same
justification comment:

```bash
# The one legitimate `|| true` here: `grep -v` exits 1 when its input is empty,
# and under `set -o pipefail` that would abort the detector on a repository
# with no lockfiles at all. grep's rc=1 means "no match", not "error". This
# `|| true` is on the discovery pipeline only — never on a branch that decides
# whether files were found.
```

**Detect-step contract to preserve** (`security.yml` L385-396) — note the explicit "no
continue-on-error on a detect step" rule, and note that P-6 must rewrite the now-false sentence about
shared scripts (highlighted below):

```yaml
      # Detection is its own step rather than a bare `if: hashFiles(…) != ''`
      # on each scan step: a step skipped by `if:` produces no log output at
      # all, and the skip path has to say out loud that the ecosystem is absent
      # (Criterion 4). The logic lives in shared scripts, not inline here, so   <-- P-6: now FALSE
      # that CI and scripts/smoke-scans.sh exercise the same implementation —   <-- P-6: now FALSE
      # the smoke gate's negative test then proves the real CI code path.       <-- P-6: now FALSE
      # No continue-on-error on a detect step: the detectors are contractually
      # exit-0 on BOTH branches, so a non-zero exit is an infrastructure
      # failure and must fail the job.
      - name: Detect npm lockfiles
        id: npm
        run: bash scripts/detect-npm.sh npm-lockfiles.txt
```

**Analog for the conditional container build (P-4/P-5):** the container job's own current shape,
L817-842. The comment at L817-818 is the third P-6 target:

```yaml
      # D-06: unconditional build. No "does a Dockerfile exist" check, no      <-- P-6: now FALSE
      # conditional skip — a skipped job fails Success Criteria #2.            <-- P-6: now FALSE
      - name: Build fixture image
        run: docker build -f fixtures/Dockerfile -t scan-fixture:${{ github.sha }} fixtures/

      - name: Run Trivy image scan
        continue-on-error: ${{ env.GATE_MODE == 'report-only' }}  # D-04 / Phase 18 CICD-06
        run: |
          trivy image scan-fixture:${{ github.sha }} --scanners vuln \
            --format json --output trivy-image.json \
            --exit-code 1 --severity HIGH,CRITICAL

      - name: Convert to SARIF
        if: always()
        run: trivy convert --format sarif --output trivy-image.sarif trivy-image.json

      - name: Show scan output files
        if: always()
        run: ls -l trivy-image.json trivy-image.sarif
```

**The `always() && <cond>` guard pattern (the 18-02 lesson) — copy this exact shape.** Every
`if: always()` step in the container job must become `if: always() && steps.docker.outputs.found == 'true'`.
The precedent for compounding `always()` with a condition already exists in this file at L864:

```yaml
      - name: Verify Trivy image SARIF upload landed
        if: always() && github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'
```

Steps in the container job needing the compound guard: L836 `Convert to SARIF`, L840 `Show scan output
files` (bare `ls -l` — fails on missing files), L844 `Upload Trivy image SARIF`, L863 `Verify Trivy
image SARIF upload landed`, L894 `Upload container reports`, L916 `Verify container artifact upload
landed`. The artifact upload's `if-no-files-found: error` (L906) is the reason this is not optional:

```yaml
          # error, not warn: the scan writes the JSON and the conversion step
          # writes the SARIF, both unconditionally, so a missing one is real.
          if-no-files-found: error
```

**Analog for the Q2 verify-step guard** (if the operator chooses mitigation (b)). There are **six**
SARIF verify steps and **five** artifact verify steps, at these exact line numbers — all eleven carry
the same fork/Dependabot guard shape and none carries `continue-on-error`:

| Step | Line |
|---|---|
| `Verify Semgrep SARIF upload landed` | 112 |
| `Verify SAST artifact upload landed` | 185 |
| `Verify Checkov SARIF upload landed` | 258 |
| `Verify IaC artifact upload landed` | 311 |
| `Verify Trivy filesystem SARIF upload landed` | 461 |
| `Verify tflint SARIF upload landed` | 712 |
| `Verify SCA artifact upload landed` | 773 |
| `Verify Trivy image SARIF upload landed` | 863 |
| `Verify container artifact upload landed` | 916 |
| `Verify Gitleaks SARIF upload landed` | 1006 |
| `Verify secrets artifact upload landed` | 1059 |

The failure text they emit is the diagnostic the adoption guide's troubleshooting table must quote
(L883-887):

```yaml
          if [ "${{ steps.sarif-trivy-image.outcome }}" != "success" ]; then
            echo "upload outcome=${{ steps.sarif-trivy-image.outcome }} — the upload did not land."
            echo "Most likely cause: security-events: write missing from the CALLER"
            echo "(.github/workflows/pr-security.yml), which a called workflow cannot elevate."
            exit 1
          fi
```

**Invariants that must survive the pass, with their source lines:**

- SHA pin + version comment, every `uses:` (ADR-004) — `L69: uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1`
- Fail-closed tolerance, never `!= 'blocking'` — `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}  # D-04 / Phase 18 CICD-06` (11 occurrences)
- The gate_mode enum validator, first step of all five jobs, before checkout (L63-68 / L805-810)
- The `env:` resolution chain, exactly once at workflow level (L40): `GATE_MODE: ${{ inputs.gate_mode || vars.GATE_MODE || 'report-only' }}`
- The full three-grant `permissions:` block at L25-32, with its "can only REDUCE" comment
- The five FROZEN `name:` values (em dash U+2014): `SAST — Semgrep CE`, `IaC — Checkov`, `SCA — Trivy Filesystem`, `Container — Trivy Image`, `Secrets — Gitleaks`
- Provenance comment markers (`# D-04`, `# ADR-001`, `# 17-03`, `# T-15-13`) — RESEARCH P-6 recommends **keep**; a divergent copy-paste copy can otherwise never be diffed against the canonical

---

### `repos/security-platform/.github/workflows/pr-security.yml` (MOD) — CI caller

**Analog:** itself (61 lines, read in full). Under the D-01 amendment this file **keeps** its relative
`uses: ./.github/workflows/security.yml` (L44) — the host is the producer, not a consumer.

Two candidate edits only:

1. **Stale comment, L58-61** — "whether a fork PR's job can even read repo `vars` at all is UNVERIFIED.
   That question is handed to Phase 19 (VAL-01)." Phase 19 answered it from a citation and
   deliberately did not test it (19-07 Q1). One-line correction; RESEARCH suggests folding it into the
   portability pass.
2. **Pattern 2 banner** (optional) — RESEARCH Pattern 2's "one banner block at the top" belongs on
   whatever file a consumer copies, not necessarily on the host's own caller.

**This file is also the exact analog for the Mode B caller template.** The Mode B variant is this file
with L44 changed and the `with:`-block comment retargeted. Copy these two comment blocks verbatim into
any template or doc snippet — they encode the two traps:

```yaml
  security:
    # FROZEN. `security` is this job's ID, and therefore the PREFIX of every
    # check-run name the called workflow's jobs emit: `security / <called job
    # name>`. This caller job itself emits NO check run of its own — verified
    # twice: Phase 14-02 saw exactly one check (`security / Placeholder`) for
    # a one-job callee, no bare `security`; Phase 18's research read of the
    # Phase 17 head SHA returned 12 check names, again none a bare `security`.
    # Renaming this job therefore renames all five required contexts at once,
    # and a required context with no matching check run sits permanently
    # pending rather than failing — which is why it is frozen.
    name: security
```

```yaml
    # Two traps to avoid if a `with:` block is ever added here:
    #   - A bare passthrough `gate_mode: ${{ vars.GATE_MODE }}` is FORBIDDEN:
    #     an unset variable resolves to "", which counts as a PROVIDED input
    #     and suppresses the callee's own default. Any literal added here
    #     must carry its own `|| 'report-only'` fallback.
    #   - A public repo that genuinely intends to run blocking may need a
    #     literal `with: gate_mode: blocking` instead of the vars path,
    #     because whether a fork PR's job can even read repo `vars` at all
    #     is UNVERIFIED.
```

Also copy the job-level permissions block and its two comments (L29-43) — `contents: read` restated
because a job-level block *replaces* the workflow-level set, `security-events: write` as THE GRANT
(the ceiling), `actions: read` "required only for private repositories … carried for Phase 20 consumer-
template portability." That last comment was written *for* this phase.

---

### `repos/security-platform/.github/dependabot.yml` (MOD) — config

**Analog:** itself (13 lines, read in full). One stale comment to correct (Pitfall 6): L4-5 says
Dependabot "ignores locally referenced reusable workflows by design" — true for `./` refs, and the
adoption guide must not let a Mode B consumer generalise it to their external `@v1` ref (supported
since 2023-03-13).

```yaml
---
# Dependabot version updates (CICD-05).
# Keeps the SHA-pinned GitHub Actions in .github/workflows/ current.
# Note: Dependabot ignores locally referenced reusable workflows by design,
# so `uses: ./.github/workflows/security.yml` is never proposed for update.

version: 2

updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

This 13-line file is also the verbatim Mode A / Mode B consumer artifact (Research Code Example 8) —
`directory: "/"` is required for `.github/workflows` discovery and must not be "corrected" to
`/.github/workflows`.

---

### `repos/security-platform/scripts/check-detector-parity.sh` (NEW) — Wave 0 harness

Covers RESEARCH Wave 0 gaps: detector parity for the three inlined blocks, and the A4 Dockerfile
pathspec measurement (**"must be measured before shipping, the same way 16-03 measured the other
three"**).

**Analog A — the exit-code contract and preamble:** `scripts/check-workflow-uploads.sh` L1-42. Copy
this three-exit-code discipline and the no-fallback stance exactly:

```bash
#!/usr/bin/env bash
set -euo pipefail

# check-workflow-uploads.sh — offline static gate for the SARIF-upload and
# artifact-retention invariants that Phase 17 rests on.
#
# Exit codes — deliberately three, not two:
#   0  every check passed
#   1  at least one assertion failed  (a workflow defect — fix the YAML)
#   2  preflight failed: pyyaml is not importable (an INFRASTRUCTURE problem
#      on this machine, not a workflow defect). The two must never be
#      conflated, and there is deliberately NO regex fallback: a silent
#      fallback that "mostly works" is exactly the failure mode this gate
#      exists to prevent.
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/check-workflow-uploads.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
```

**Analog B — the assertion-accumulator pattern:** `scripts/smoke-scans.sh` L38-137 — a `FAILURES`
array, report every failure rather than stopping at the first, and helpers that *push to FAILURES*
rather than print:

```bash
FAILURES=()
...
run_scan_rc() {
  ...
    echo "==> ${label}: exit=${rc} (PASS - finding(s) detected)"
    SCANS_PASSED=$((SCANS_PASSED + 1))
  ...
    echo "==> ${label}: exit=${rc} (FAIL - scanner found nothing)"
    FAILURES+=("${label}: scanner exited 0 (no findings)")
```

**Analog C — detect-then-guard, with the list file written outside the checkout:**
`smoke-scans.sh` L398-415. This is the harness's own call convention and the reason a parity test must
pass an explicit `$OUT` path:

```bash
# The list file is written into $OUT, never into the checkout: invoked with no
# argument the detector defaults to writing it into the current directory,
# which would leave an untracked file behind in the repository.
bash scripts/detect-npm.sh "$OUT/npm-lockfiles.txt"
if [ -s "$OUT/npm-lockfiles.txt" ]; then
```

**Project rule (both scripts state it in their headers):** never `chmod +x`; always invoke
`bash scripts/<name>.sh`.

---

### `repos/security-platform/scripts/check-workflow-uploads.sh` (VERIFY, likely unmodified)

RESEARCH's last Wave 0 bullet asks whether P-4/P-5 break this gate. Read live, the two assertions that
could plausibly interact with the container-job changes **do not**:

- **UPLOAD-VERIFY-PAIRING** (L272-288) requires every id'd upload step to be read back by a *later step
  in the same job* whose `run` contains `steps.<id>.outcome`. Adding `if:` guards changes no `run` body
  and removes no step, so the pairing survives.

```python
            needle = "steps.{}.outcome".format(step_id)
            paired = any(needle in str(later.get("run") or "") for later in steps[idx + 1:])
```

- **JOB-SHAPE** (L299-312) asserts exactly 5 callee jobs, no `needs:`, and `observed_names ==
  FROZEN_JOB_NAMES`. P-1…P-6 add steps, never jobs, and rename no job.

```python
if len(callee_jobs) != 5:
    fail("JOB-SHAPE", "... the parallel scan set is exactly 5")
...
if observed_names != FROZEN_JOB_NAMES:
    fail("JOB-SHAPE", "check-run names drifted from the frozen set Phase 18 hard-codes: ...")
```

**Planner instruction:** run `bash scripts/check-workflow-uploads.sh` against the modified file
**first**, before assuming either outcome. A failure is a *stale-gate vs real-defect* question to
answer deliberately (RESEARCH), and the script `cd`s to `REPO_ROOT` so it only ever runs from inside
`repos/security-platform/`.

---

## New Finding (not in RESEARCH.md): a THIRD stale copy already exists, in the host repo

RESEARCH.md flags the blueprint's `## Complete GitHub Actions Workflow` (L1456) as the one stale
illustrative template. There is a second, and it lives in the canonical host repo:

```text
repos/security-platform/cicd/
├── ARCHITECTURE.md                    16.8 KB
├── README.md                          8.5 KB   ← a DEPLOYMENT GUIDE, mtime Mar 22 (pre-Phase-14)
├── renovate.json                               ← Renovate, not Dependabot
├── .github/workflows/security.yml     203 lines ← a COPY-PASTE TEMPLATE
├── azure-pipelines/azure-pipelines.yml
└── gitlab-ci/.gitlab-ci.yml
```

`cicd/.github/workflows/security.yml` measured contents — every defect RESEARCH attributes to the
blueprint template is here too:

```yaml
# .github/workflows/security.yml
# Deploy this file to each target repository at .github/workflows/security.yml
# All actions are pinned to SHA digests. Renovate updates them automatically.
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
  security-events: write   # only two grants — no actions: read
...
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4   (canonical is v7.0.1)
      - run: pip install semgrep                                              (canonical pins ==1.177.0)
      - run: semgrep scan --config auto ...                                   (canonical: --config auto is a hard error with --metrics=off)
      - run: semgrep scan --config auto --sarif --output semgrep.sarif . || true   (banned silent fallback)
```

No `workflow_call`, no `gate_mode`, no verify steps, no `retention-days`, no SARIF `category`.

`cicd/README.md` contradicts the shipped pipeline in five measured ways:

| `cicd/README.md` says | Line | Live reality |
|---|---|---|
| `cp -r cicd/.github/ <target-repo>/.github/` is the deployment recipe | L41-44 | This ships the stale template — it is a DIST-06 answer that does not satisfy SC1 |
| `sca` job uses **Grype** | L22 | `security.yml` uses Trivy filesystem + npm audit + pip-audit + tflint |
| **Renovate** keeps SHAs current (+ `renovate.json`, + Mend Marketplace app) | L58-63, L197 | `.github/dependabot.yml`; the project is Dependabot-based (CICD-05) and "no external accounts" |
| Required status checks are `sast`, `iac`, `sca`, `container`, `secrets` | L125 | The five contexts are `security / SAST — Semgrep CE` … (em dash U+2014, `security /` prefix) |
| Requirements CICD-01…05 "Planned" | L29-33 | Delivered and live-validated in Phases 14-19 |

**Why this matters to the planner:** `cicd/README.md` §Deployment + §Files deployed table + §Validation
Checklist (L178-189) is the **closest existing structural analog for DIST-06 + DIST-08 in this project**
— and it is simultaneously the largest drift hazard the new adoption guide will sit next to. Two
deliverables describing one procedure is exactly the failure 18-06 had to repair. This needs the same
treatment Q3 gives the blueprint section (retitle/point/replace), and it is a **host-repo** change, so
it belongs in a host-repo plan.

Its reusable shapes — copy these into `docs/adoption-guide.md`:

```markdown
**Files deployed:**

| File | Location in target repo | Description |
|------|------------------------|-------------|
| `.github/workflows/security.yml` | `.github/workflows/security.yml` | Security scanning workflow |
```

```markdown
## Validation Checklist

After deploying to a repository (any platform):

- [ ] Open a PR/MR with a deliberate IaC misconfiguration. Verify Checkov flags it.
- [ ] Confirm JSON artifacts are downloadable from the pipeline run.
- [ ] Confirm scanner failures block the merge (requires branch protection).
```

Also note `repos/security-platform/README.md` L41 already advertises the pipeline to the world in
report-only terms and its §Milestones table marks `cicd/` "In progress" — a candidate one-line MOD once
`v1` ships, and the natural place to link the adoption guide.

## Shared Patterns

### Two-repo separation (applies to EVERY plan)

**Source:** `.gitignore` (single line `repos/`), `repos/security-platform/.git`
**Apply to:** all plans
Every plan states its repo. Host-repo work is its own branch → PR → merge → `git tag` cycle inside
`repos/security-platform/`. Doc work commits here. A plan that edits both in one commit is impossible.

### `# Expected:` output after every command

**Source:** `docs/milestone-1-workstation/INSTALLATION_GUIDE.md` L28-35, L240-267
**Apply to:** `docs/adoption-guide.md` (all fenced blocks), any harness script log lines
RESEARCH's "Key insight": every failure in this domain fails *silently green* — a wrong pathspec, a
dropped ruleset rule, a mistyped em dash, a missing caller permission. Commands without expected output
are not verification.

### Bold-lead bullets with the rejected alternative inline

**Source:** `docs/adr/adr017-...md` §Decision (L19-33)
**Apply to:** ADR-018, and the adoption guide's rationale paragraphs

### SHA pin + version comment — and its one documented exception

**Source:** `security.yml:69` (`uses: actions/checkout@3d3c42e...  # v7.0.1`), ADR-004
**Apply to:** every `uses:` of a third-party action in any file this phase touches
**Exception, stated explicitly** (RESEARCH Code Example 4): a `uses: …/security.yml@v1` reusable-workflow
ref carries **no** trailing version comment — `@v1` moves, so a hand-written `# v1.0.0` rots silently,
and Dependabot maintains comments on SHA pins, not tag refs.

### Fail-closed comparison

**Source:** `security.yml` — `continue-on-error: ${{ env.GATE_MODE == 'report-only' }}  # D-04 / Phase 18 CICD-06` (×11), and the `case` validator at L63-68
**Apply to:** any new gated step introduced by the portability pass
Never `!= 'blocking'`: a typo must block, not tolerate (ADR-017).

### `always() && <cond>` compound guards (the 18-02 lesson)

**Source:** `security.yml:864`
**Apply to:** every `if: always()` step in the container job once the build can skip
`always()` alone runs a step after a skipped build and fails on missing files — which
`if-no-files-found: error` (L906) converts into a red job on a clean skip.

### No `chmod +x`; invoke with `bash`

**Source:** `.claude/rules/defensive-protocol-v2-anti-slop.md`; restated in
`scripts/check-workflow-uploads.sh` L28-30 and `scripts/detect-npm.sh` L22-23
**Apply to:** every script this phase creates or documents, including `set-required-checks.sh`
invocations in the adoption guide

### Byte-exact frozen strings

**Source:** `security.yml` job `name:` values; `scripts/check-workflow-uploads.sh` `FROZEN_JOB_NAMES`
**Apply to:** adoption guide, ADR-018, any template
The five required contexts, em dash U+2014, `security /` prefix, exactly five (not six — C-5 /
ADR-017's correction):

```text
security / SAST — Semgrep CE
security / IaC — Checkov
security / SCA — Trivy Filesystem
security / Container — Trivy Image
security / Secrets — Gitleaks
```

Never retype them — read them from `gh api repos/O/R/commits/<SHA>/check-runs --jq '.check_runs[] | select(.app.id==15368) | .name'`.

### Markdown lint gate

**Source:** `.markdownlint-cli2.yaml`
**Apply to:** every `.md` file this phase writes
Enabled and must pass: MD001, MD009, MD010, MD025 (one H1), MD034 (no bare URLs in prose).
Disabled, so do not contort for them: MD013, MD022, MD024, MD029, MD031, MD032, MD036, MD040, MD060, MD018.

### ADR append-only

**Source:** `CLAUDE.md` §Editing Guidelines
**Apply to:** `docs/adr/`
ADR-001…017 are untouchable. New decisions and corrections go in ADR-018 using ADR-017's
`**Correction to D-NN: …**` bullet form. Index gets exactly one new row.

## No Analog Found

| Repo | File / artifact | Role | Data Flow | Reason |
|---|---|---|---|---|
| host | git tags `v1` + `v1.0.0`, `gh release create` | release artifact | one-shot publish | `security-platform` has **0 tags and 0 releases** (verified). This project has never cut a release in the host repo. Use RESEARCH Pattern 3 + Code Example 6 verbatim. Note: `git tag -a` makes an **annotated** tag, so `git/ref/tags/v1` returns a tag object, not a commit — RESEARCH recommends the moving `v1` be **lightweight** (`git tag -f v1 <commit>`, no `-a`) and only point releases annotated |
| host | release-notes body | doc | one-shot | No `docs/` directory exists in `security-platform` (only `README.md`, `cicd/`, `workstation/`, `scripts/`, `fixtures/`). RESEARCH Code Example 6's `--notes-file docs/release-notes/v1.0.0.md` would create a new tree with no precedent — `--notes` inline is the lower-ceremony choice, matching "zero-cost, low-ceremony" |
| — | ruleset **creation** path (`POST /repos/O/R/rulesets`) | script | request-response | `scripts/set-required-checks.sh` has a read-modify-write path only, and hard-codes `--repo OttawaCloudConsulting/security-platform` / `--ruleset 14243983`. A consumer with `[]` rulesets (e.g. private `aws-zabbix-monitoring-solution`) has no scripted path. Document, or extend the script — do not hand-roll a bare `PUT` (Pitfall 4) |

## Metadata

**Analog search scope:** `docs/`, `docs/adr/`, `docs/milestone-1-workstation/`, `docs/milestone-plan/`,
`CLAUDE.md`, `.markdownlint-cli2.yaml`, `repos/security-platform/{.github/,scripts/,cicd/,README.md}`
**Files read this session:** 16 (4 full, 12 targeted ranges)
**Strong analogs used:** 6 — `INSTALLATION_GUIDE.md`, `DEVELOPER_GUIDE.md`, `adr017-*.md`,
`pr-security.yml`, `detect-npm.sh`, `check-workflow-uploads.sh` (+ `smoke-scans.sh`, `cicd/README.md`)
**Not modified by this agent:** any source file. PATTERNS.md is the only write.
**Pattern extraction date:** 2026-09-13

---
*Phase: 20-template-packaging-and-adoption-docs*
