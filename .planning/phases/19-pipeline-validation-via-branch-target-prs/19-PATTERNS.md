# Phase 19: Pipeline Validation via Branch-Target PRs - Pattern Map

**Mapped:** 2026-09-12
**Files analyzed:** 6 (2 new fixtures, 1 modified doc, 1 discretionary script, 2 new outer-repo planning docs)
**Analogs found:** 6 / 6 — every file to be created or modified has a close in-repo analog (5 exact, 1 self-analog). The two entries under §No Analog Found are *concerns* on already-mapped files, not unmapped files.
**Analog scope:** `repos/security-platform/` at local HEAD `fbe0071` (fixtures + scripts + pre-commit config are **byte-identical to `origin/main` `2e29004`** — verified: `git diff HEAD origin/main -- fixtures/ scripts/` reports only `scripts/set-required-checks.sh`, added on main and not touched by this phase) and `.planning/phases/18-…/` for the evidence-document stream.

> **Read this before planning:** this phase writes almost no code. Two of its four criteria are satisfied by *documents* recording live observations, so §Pattern Assignments covers the `18-05-*` evidence and checkpoint shapes with the same weight as the fixture files.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `repos/security-platform/fixtures/vulnerable.py` | fixture / scanner input (never executed) | static input — batch (read by Semgrep at scan time) | `fixtures/main.tf` (+ `fixtures/Dockerfile` for the dated-measurement line) | exact |
| `repos/security-platform/fixtures/secret.env` | fixture / scanner input (never read) | static input — batch (read by Gitleaks *from git history*, and by Semgrep from the tree) | `fixtures/requirements.txt` (+ `fixtures/main.tf` for the multi-tool annotation) | exact |
| `repos/security-platform/fixtures/README.md` | doc / index | reference | itself — L10-19 tree, L21-31 table, L43-47 versions+drift, L49-67 pre-commit scoping | exact (self-analog) |
| `repos/security-platform/scripts/smoke-scans.sh` — SAST section | test harness / local gate | batch assert | its own tflint block L493-547 (rule-id verdict assertion) | exact — **DISCRETIONARY, planner decision, see below** |
| `.planning/phases/19-…/19-0X-PLAN.md` (live-run tasks) | plan / checkpoint | human-in-loop | `18-05-PLAN.md` L196-241 (`checkpoint:human-verify`), L242+ (`checkpoint:decision`) | exact |
| `.planning/phases/19-…/19-0X-SUMMARY.md` (evidence) | doc / evidence record | observation capture | `18-05-SUMMARY.md` L89-135 (`## Required Output: Observed Evidence`) | exact |

**Explicitly NOT modified** (each has a reason the plan should state, not discover):

| File | Why untouched |
|---|---|
| `repos/security-platform/scripts/check-workflow-uploads.sh` | Static YAML invariant gate; its own scope note says it *"deliberately asserts NO counts"*. Fixture files are invisible to it. Run it as a regression check (`bash scripts/check-workflow-uploads.sh`), never edit it. |
| `repos/security-platform/.gitleaksignore` | Adding a fingerprint here silences **CI as well as the local hook** and destroys the SC1 detection this phase exists to produce. See §Shared Patterns → Anti-pattern 1. |
| `repos/security-platform/.pre-commit-config.yaml` | No fifth `exclude: ^fixtures/` is needed — `ruff` passes on the fixture as authored. See §Shared Patterns → Pattern S-3. |
| `.github/workflows/security.yml`, `pr-security.yml` | CONTEXT boundary: no scan-job logic, gate-mode wiring, or SARIF changes (Phase 15/17/18 territory). The `security` job name is FROZEN. |
| `docs/adr/*` | Append-only per CLAUDE.md, and this phase records evidence, not decisions. If something warrants a record it is a **new** ADR file. |

---

## Preflight facts that change the plan (verified this session)

| Check | Result | Consequence |
|---|---|---|
| `cat repos/security-platform/.gitignore` | 21 lines: OS, editor, `__pycache__/`, `*.pyc`, `.venv/`, `node_modules/`, `.pre-commit-cache/`. **No `*.env` / `.env` entry.** | `fixtures/secret.env` is committable as named. D-02's filename is safe. |
| `grep 'detect-aws-credentials\|detect-private-key\|detect-secrets' .pre-commit-config.yaml` | no matches | The **only** secret gate is the gitleaks hook at L103-107 (`- id: gitleaks` L106) with `stages: [pre-push]` L107. It fires on `git push`, not `git commit` — bypass is `git push --no-verify`, which the config's own comment (L101) documents as intended, with CI as the compensating control. |
| `markdownlint` hook | L65-69 (`- id: markdownlint` L68, `types: [markdown]` L69), **no `exclude: ^fixtures/`** | It **fires on `fixtures/README.md`**. Config is `.markdownlint.jsonc`: MD013/MD024/MD036/MD040/MD060 and `line-length` are OFF (wide tables are fine), but **MD022 (headings), MD031 (fences) and MD058 (tables) are NOT disabled** — keep a blank line around every heading, fence and table in the README edit. (`.markdownlint-cli2.yaml` disables more, but the pre-commit hook is `markdownlint-cli`, which reads `.markdownlint.jsonc`.) |
| `ruff` hook | L30-32 `- id: ruff` with **`args: [--fix]`**, `types_or: [python, pyi]`, no fixtures exclude | The hook **rewrites the file in place** on commit. Per ruff's documented defaults (no `ruff.toml` or `pyproject.toml` exists in the inner repo root, so defaults apply) the rule set includes `F401` unused-import, which is auto-fixable — so if a plan trims a function from the fixture and leaves `import os` or `import subprocess` unused, the hook will delete the import and change the committed fixture. (Inferred from ruff defaults, not measured — the mitigation is the same either way.) Every import in `vulnerable.py` must stay used. Gate with `ruff check fixtures/vulnerable.py && ruff format --diff fixtures/vulnerable.py` before the commit, not after. |
| gitleaks pin drift | pre-commit `rev: v8.30.0` (L104) vs CI `v8.30.1` | Cosmetic; both detect `aws-access-token`. Do not "fix" it in this phase. |

---

## Pattern Assignments

### `repos/security-platform/fixtures/vulnerable.py` (fixture, static-input/batch) — NEW

**Analog:** `fixtures/main.tf` (header + deliberately-silent annotation convention), `fixtures/Dockerfile` (dated measurement line)

**Header pattern** — `fixtures/main.tf` L1-6. The first line is byte-exact and load-bearing: the validation check is `head -1 … | grep -c 'INTENTIONALLY VULNERABLE'`, so **line 1 must be the header, not a shebang and not a blank line**. Note the em-dash (U+2014) and the straight double quotes around `FIX`:

```terraform
# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"
# Old provider pin: satisfies D-02 only. An exact `3.74.0` pin is correctly SILENT
# under tflint — a pinning check WANTS an exact pin. What seeds SCA-03 is the
# unconstrained `random` provider and the unpinned module block below.
# NOTE: the provider pin alone produces ZERO Checkov findings. The misconfigured
# resources below are what make the IaC job non-empty (see RESEARCH C-2).
```

Two conventions to copy verbatim from this block:
1. **Name the rule/tool each construct trips**, not just "this is insecure".
2. **Name what is deliberately SILENT and forbid fixing it.** This is the established precedent for RESEARCH's measured finding that `os.system()` / `os.popen()` produce zero `p/default` results. Keep them for shape, annotate them as silent — exactly as `main.tf` does for its exact provider pin.

**Inline per-construct annotation pattern** — `fixtures/main.tf` L13-15 and L36-37:

```terraform
    # No `version` key on purpose — an unconstrained provider is what trips tflint's
    # terraform_required_providers rule, and it only fires when the provider is
    # actually USED by a resource (see random_id.fixture below). Do NOT "fix" this.
```

```terraform
# Registry module with NO `version` argument on purpose — seeds tflint's
# terraform_module_version rule. Nothing ever runs `terraform init` on fixtures/.
```

**Dated-measurement pattern** — `fixtures/Dockerfile` L1-4. Every count in this repo carries a date and the reason it is stable:

```dockerfile
# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"
# Supported distro (advisories still published) carrying unpatched CVEs.
# Measured 2026-09-10: 222 vulnerabilities (4 CRITICAL, 52 HIGH).
# Pinned by digest so the finding count is stable and monotonic non-decreasing.
```

**"Nothing ever runs this" pattern** — `fixtures/requirements.txt` L1-3 (the `OR INSTALL` header variant plus the explicit disclaimer sentence):

```text
# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX" OR INSTALL
# Nothing in this repository ever runs `pip install -r` against this file; it exists
# solely as pip-audit / Trivy filesystem input for SCA-02. Exact `==` pins only.
```

For a `.py` fixture the equivalent is `DO NOT "FIX" OR RUN` + "nothing imports or executes this file". RESEARCH's recommended body (19-RESEARCH.md L402-443) already composes all four conventions and is measured ruff-clean and `ruff format`-clean; use it as the starting text rather than re-deriving one.

**Ruff constraint (no analog — new to this repo, first `.py` file outside `scripts/`):** the fixture must pass `ruff check` and `ruff format --diff` as committed. `fixtures/README.md` L63-67 currently asserts *"No hook fires on `requirements.txt`, and the four-hook list above is deliberately unchanged… Do not 'fix' this by adding a fifth `exclude: ^fixtures/` entry — there is nothing to exclude."* That sentence becomes half-stale — see the README edit points below. This is a Chesterton's-fence call the planner should **decide and record**, not silently override: the correct resolution is to keep the four-hook list unchanged and document that ruff fires and passes.

---

### `repos/security-platform/fixtures/secret.env` (fixture, static-input/batch) — NEW

**Analog:** `fixtures/requirements.txt` L1-3 (header + "nothing reads it"), `fixtures/main.tf` L1-6 (multi-tool / silent-construct annotation)

Same four header conventions as above. Three things are specific to this file and have no fixture analog, so the header must carry them explicitly (RESEARCH's recommended body at 19-RESEARCH.md L449-467 already does):

1. **The values are synthetic** and have never existed. Never a real, revoked, or "probably expired" credential.
2. **Do not substitute `AKIAIOSFODNN7EXAMPLE`** — measured, gitleaks 8.30.1 allowlists `EXAMPLE`-suffixed keys and produces **zero** findings. This is the same "do not fix this, it looks wrong but is deliberate" voice as `main.tf` L13-15.
3. **Do not add this file's fingerprint to `.gitleaksignore`** — CI reads that file too.

**Two-tool annotation precedent:** `fixtures/main.tf` is consumed by *two* jobs and carries a row for each in the README table (L26 Checkov, L27 tflint). `secret.env` is the same shape — Gitleaks (`aws-access-token`, named/deterministic; `generic-api-key`, entropy-based and **not** version-stable) plus Semgrep (`generic.secrets.security.detected-aws-access-key-id-value`, `.detected-aws-secret-access-key`). Copy `main.tf`'s handling: one README row per consuming job, and an inline note distinguishing the deterministic match from the entropy match so a future reader never mistakes one for the other.

**Comment syntax:** `#` line comments, same as `requirements.txt` — a `.env` file is not executed, so no shebang. Line 1 is the header.

---

### `repos/security-platform/fixtures/README.md` (doc, reference) — MODIFIED

**Analog:** itself. Five edit points — this is **not** "add two table rows"; two existing prose claims go stale the moment the fixtures land.

**Edit point 1 — structure tree (L10-19).** Two new leaves; `requirements.txt` moves from `└──` to `├──` (or the new entries sort after it — either way the box-drawing characters must be re-terminated). Existing convention: one-line purpose comment naming the consuming scan, continuation lines indented under it:

```text
├── main.tf               # IaC/pinning-scan target: old AWS provider pin + misconfigured S3 bucket/security
│                         #   group + unconstrained `random` provider + unpinned registry module
├── package.json          # SCA-scan target: vulnerable lodash + minimist pins
├── package-lock.json     # Generated lockfile — never hand-write this file
└── requirements.txt      # SCA-scan target: vulnerable requests + jinja2 pins — nothing installs it
```

**Edit point 2 — Fixture Reference table (L21-31).** Three-column format, one row **per consuming job** (not per file — `main.tf` has two rows, `package.json` has two):

```markdown
| File | Consuming Job | Measured Finding Count (2026-09-11) |
|---|---|---|
| `main.tf` | IaC scan (Checkov) | 12 failed terraform checks (was 10 — the unpinned module adds `CKV_TF_1` + `CKV_TF_2`) |
| `main.tf` | Pinning sub-scan (tflint) | 3 issues: `terraform_required_providers` (unconstrained `random`), `terraform_module_version` (`fixture_unpinned_module`), `terraform_required_version` (pre-existing, not a pinning issue) |
```

New rows needed: `vulnerable.py` → SAST (Semgrep CE) — 3 findings, named by rule id; `secret.env` → Secrets (Gitleaks) — `aws-access-token` + `generic-api-key`; `secret.env` → SAST (Semgrep CE) — the two `generic.secrets.security.*` rules. Note the header carries a single measurement date; adding rows measured on a different date means either a second dated header or a per-row date note — planner's call, but it must not silently imply 2026-09-11.

**Edit point 3 — tool-versions line (L43-44).** Currently: *"Tool versions used for the 2026-09-11 measurement: Trivy 0.74.0, Checkov 3.2.396, tflint 0.61.0 (ruleset.terraform 0.14.1-bundled), pip-audit 2.10.1, npm 11.7.0."* Must gain `semgrep 1.177.0` and `gitleaks 8.30.1`. The drift disclaimer immediately below (L46-47 — *"Counts will drift upward over time… that is expected and does not indicate a broken fixture"*) already covers RESEARCH Pitfall 8 (`p/default` resolves rules from the registry at scan time) — **do not duplicate it**, but a one-clause extension noting that the *ruleset*, not just the CVE feed, is the drift source is in keeping with the file's voice.

**Edit point 4 — the Gitleaks claim (L60-61) goes STALE.** Current text:

```markdown
The Gitleaks secrets hook is NOT excluded — no fixture ever contains a real secret, so
it is unaffected and continues to run normally.
```

After `secret.env` lands, the hook *does* fire on `git push`. The replacement must keep the "not excluded, and that is deliberate" stance and add the bypass mechanics, borrowing the voice of `.pre-commit-config.yaml` L101: *"Bypass: git push --no-verify skips this hook — CI is the compensating control."* It must also state that the fixture contains **synthetic** values (so "no fixture contains a real secret" remains true) and that no fingerprint may be added to `.gitleaksignore`.

**Edit point 5 — the "no hook fires / no fifth exclude" claim (L63-67) goes HALF-STALE.** Current text:

```markdown
**No hook fires on `requirements.txt`, and the four-hook list above is deliberately unchanged.**
Verified, not assumed: `ruff`/`ruff-format` are `types_or: [python, pyi]`, which does not match a
bare `requirements.txt`… Do not "fix" this by adding a
fifth `exclude: ^fixtures/` entry — there is nothing to exclude.
```

Still true for `requirements.txt`; but `ruff`/`ruff-format` **now match `fixtures/vulnerable.py`** and pass. Add a sentence recording that the fixture is authored ruff-clean *on purpose* so the four-hook list stays at four, and note `args: [--fix]` means an un-clean fixture would be silently rewritten. Also worth recording here, per RESEARCH Pitfall 6: the secrets job runs `gitleaks git .` with `fetch-depth: 0` — a **history** scan — so once `secret.env` is on `main` it is in the history of every future branch and the secrets job will report it forever. Document it so nobody "cleans up" the history later.

---

### `repos/security-platform/scripts/smoke-scans.sh` (test harness, batch assert) — DISCRETIONARY

**Planner decision, not assigned work.** RESEARCH flags a one-line-ish improvement: the SAST block prints findings but does not assert *which* file produced them, so a registry drift (Pitfall 8) that silences `eval-detected` would pass the local gate. It is a script change, not a workflow change, so it is arguably inside the CONTEXT's "no scan-job logic changes" boundary — but it touches a Phase 15/16 artifact. Decide it explicitly.

**Do NOT bolt an assertion onto the existing print.** The current SAST block ends in `|| true` (L248) — that is deliberately informational:

```bash
# --- 1. SAST: Semgrep ---------------------------------------------------   (L232)
echo "--- SAST (Semgrep) ---"
run_scan "semgrep" semgrep scan --config p/default --metrics=off --error \
  --json-output="$OUT/semgrep-results.json" \
  --sarif-output="$OUT/semgrep.sarif" \
  .
require_nonempty "semgrep-json" "$OUT/semgrep-results.json"                    # L238
require_nonempty "semgrep-sarif" "$OUT/semgrep.sarif"                          # L239
python3 -c "
import json
with open('$OUT/semgrep-results.json') as f:
    data = json.load(f)
results = data.get('results', [])
print(f'    semgrep findings: {len(results)}')
for r in results:
    print(f\"      rule={r.get('check_id')} path={r.get('path')}\")
" || true                                                                      # L248
```

The script's own helper doc (L119-127) states the rule plainly: *"an assertion that ignores its own failure IS the false-pass mechanism this script exists to prevent."*

**Analog to copy — the tflint rule-id verdict block, L493-547.** This is the exact shape: a *separate* `python3 - "$file" <<'PY' || rc=$?` heredoc that exits non-zero, followed by `FAILURES+=`. Note the comment explains *why the assertion is on rule ids and not on a count*, which is precisely the property RESEARCH asks for (assert `eval-detected` at `fixtures/vulnerable.py`, never a total):

```bash
# The verdict below is asserted on the RULE IDS, not on a finding count, and    (L495)
# the missing-required_version rule (terraform_required_version) is
# deliberately NOT in the accepted set… A bare "at least one finding" check would
# therefore pass with SCA-03 completely unproven.
    tf_rc=0
    python3 - "$OUT/tflint.sarif" <<'PY' || tf_rc=$?                             (~L517)
import json
import sys

path = sys.argv[1]
PINNING = {
    "terraform_required_providers",
    "terraform_module_version",
    "terraform_module_pinned_source",
}
try:
    with open(path) as handle:
        data = json.load(handle)
except Exception as exc:  # noqa: BLE001 - any parse/IO failure is a hard fail
    print("    tflint SARIF unreadable: {} ({})".format(path, exc))
    sys.exit(2)
…
hits = sorted(PINNING & found)
print("    tflint pinning rule ids: {}".format(hits))
if not hits:
    print("    tflint reported no pinning rule id from {}".format(sorted(PINNING)))
    sys.exit(3)
PY
    if [ "$tf_rc" -ne 0 ]; then
      FAILURES+=("tflint: no pinning rule id in the SARIF results (${OUT}/tflint.sarif)")   (L546)
    fi
```

The `npm audit` block (L383-400) is the second instance of the same shape — *"Verdict assertion, not an informational print"* — so the convention is established twice and safe to follow.

**Constraints if the planner takes it:** `set -euo pipefail` is in force (L2), so every assertion must be `|| rc=$?`-guarded and routed through `FAILURES+=`, never allowed to abort the run; the `shellcheck` pre-commit hook runs on this file; and the script's hard-tier preflight loop (L203: `for bin in semgrep checkov trivy gitleaks docker python3 npm`) `exit 1`s when `semgrep` is absent — **this workstation has no semgrep**, so the whole gate cannot run without the venv on `PATH` first. Any verification field that claims to have run it must say how semgrep got there.

**Invocation, always:** `bash scripts/smoke-scans.sh` / `bash scripts/check-workflow-uploads.sh`. Never `./`, never `chmod +x` (project rule, `.claude/rules/…anti-slop.md`).

---

### `.planning/phases/19-…/19-0X-SUMMARY.md` (doc, evidence capture) — the SC1–SC4 deliverable

**Analog:** `18-05-SUMMARY.md` §`## Required Output: Observed Evidence` (L89-135). This section *is* the format "witnessed, not inferred" means. Four sub-tables, in this order:

**Preflight table** (L93-99) — the repo state *before* the change, so the restore can be proven:

```markdown
| Check | Result |
|---|---|
| `gh variable list -R OttawaCloudConsulting/security-platform` | empty — no `GATE_MODE` |
| `gh api rules/branches/main --jq '.[].type'` | `deletion`, `non_fast_forward` |
| PR #9 state | `OPEN`, `MERGEABLE`, head `31dbb0d76749900b82f59fd4e2e4601dec485289` |
```

**Flip-window table** (L103-108) — timestamps read back from the API plus the collateral-run query:

```markdown
| Event | Timestamp |
|---|---|
| `gh variable set GATE_MODE --body blocking` | `2026-09-12T03:06:56Z` (read back via `gh variable list`) |
| `gh variable delete GATE_MODE` | `2026-09-12T03:09:26Z` |
| **Window length** | **~2.5 minutes** |
| Other runs (any branch/repo) inside the window | **None** — queried the full run list filtered to `createdAt` between the two timestamps |
```

**Run-identity table** (L114-119) — the SC2 proof. One column per measurement; commit / run id / conclusion / **tree hash**. Identical tree hash + empty `git diff` + opposite conclusions is the whole argument:

```markdown
| Item | Report-only baseline | Blocking | Restore |
|---|---|---|---|
| Commit | `31dbb0d…` | `5973e8e…` | `835c43e…` |
| Run id | 34668611172 | 34669534855 | 34669700643 |
| Conclusion | `success` | `failure` | `success` |
| Tree hash | `ce7ec65…` | `ce7ec65…` | `ce7ec65…` |
```

**Check-run table** (L125-131) — always the five byte-exact frozen names, never a paraphrase:

```markdown
| Check name | Conclusion |
|---|---|
| `security / SAST — Semgrep CE` | failure |
| `security / IaC — Checkov` | failure |
| `security / SCA — Trivy Filesystem` | failure |
| `security / Container — Trivy Image` | failure |
| `security / Secrets — Gitleaks` | failure |
```

Plus (L135) the `gate_mode=` log-line count — must be 5, one per job.

---

### `.planning/phases/19-…/19-0X-PLAN.md` — checkpoint tasks

**Analog:** `18-05-PLAN.md` L196-241 (`<task type="checkpoint:human-verify" gate="blocking">`) and L242+ (`<task type="checkpoint:decision" gate="blocking">`). RESEARCH is explicit that carrying these forward is a **CLAUDE.md requirement**, not a Phase 18 stylistic choice: irreversible / repo-wide actions pause for the operator.

Three checkpoints are indicated for Phase 19:

| Checkpoint | Type | Why | Analog |
|---|---|---|---|
| The repo-wide `GATE_MODE=blocking` flip and its evidence | `checkpoint:human-verify` | Gates every PR and Dependabot run in the repo while set | 18-05-PLAN L196-241 |
| D-10 merge-vs-close of the validation PR | `checkpoint:decision` | Irreversible; CONTEXT explicitly leaves it to execution time | 18-05-PLAN L242+ |
| SC3's rendered alert page (RESEARCH Q2) | `checkpoint:human-verify` | Phase 17 scored the equivalent criterion NOT OBSERVED for offering API evidence where a UI observation was asked | 18-05-PLAN L196-241 |

Structural elements to copy from L196-241: `<read_first>` naming the exact SUMMARY files the operator needs; `<action>` that **ends in "then stop and wait"** and forbids adjacent actions ("Do not merge and do not touch the ruleset"); `<how-to-verify>` as numbered single-click steps; `<resume-signal>`; `<acceptance_criteria>` requiring the operator's reply be *recorded verbatim*; a one-line `<done>`. Note L238 — *"If the operator reports a mismatch, record it verbatim and stop"* — which is the anti-slop STOP → REPORT → WAIT rule expressed as plan text.

For the SC3 checkpoint specifically, the question handed to the human must be a single `html_url` and a yes/no ("does this page render an alert for `fixtures/vulnerable.py`?"), **never** "open the Security tab" — see Anti-pattern 2.

---

## Shared Patterns

### S-1: The fixture header (applies to both new fixture files)

**Source:** `fixtures/main.tf` L1, `fixtures/Dockerfile` L1, `fixtures/requirements.txt` L1, `fixtures/package.json` L5
**Byte-exact, line 1, no shebang or blank line above it:**

```text
# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX"
```

Em-dash is U+2014; quotes are straight ASCII `"`. Variants in use: `— DO NOT "FIX" OR INSTALL` (`requirements.txt` L1), `DO NOT FIX OR INSTALL` (`package.json` L5, inside a JSON string with no comment syntax available). A `.py` fixture wants `OR RUN`. The verification command is `head -1 fixtures/vulnerable.py fixtures/secret.env | grep -c 'INTENTIONALLY VULNERABLE'`.

### S-2: Annotate what is deliberately silent, and forbid fixing it

**Source:** `fixtures/main.tf` L2-6 (exact provider pin is *correctly* silent under tflint), L13-15, L44-45
**Apply to:** `vulnerable.py` (`os.system()` / `os.popen()` — measured zero findings under `p/default`), `secret.env` (the `EXAMPLE`-key trap)

The repo already has a convention for "this looks like a bug but was measured and kept". Use it rather than deleting the silent constructs or, worse, leaving them unexplained for a future reader to "fix".

### S-3: Verified-not-assumed voice in fixture docs

**Source:** `fixtures/README.md` L63-67 (*"Verified, not assumed: `ruff`/`ruff-format` are `types_or: [python, pyi]`, which does not match a bare `requirements.txt`"*), L33-41 (the two `requirements.txt` rows explained in full so the discrepancy is never read as a broken scan)
**Apply to:** every README claim added by this phase

Claims in this repo state the evidence inline. "Measured YYYY-MM-DD against <tool> <version>" is the house style; an unqualified count is not.

### S-4: Scanner assertions target rule ids and paths, never totals

**Source:** `scripts/smoke-scans.sh` L495-501 (tflint rationale), L383-385 (npm "verdict assertion, not an informational print"), L119-127 (`require_parses_json` doc: an assertion that swallows its own failure is the false-pass mechanism)
**Apply to:** every SC1/SC3 evidence step in every Phase 19 plan

Scope every assertion to `path == "fixtures/vulnerable.py"` / `RuleID == "aws-access-token" and File contains "secret.env"`. A bare "the semgrep job found something" passes against the **3-finding pre-existing baseline** (`.github/dependabot.yml`, `cicd/.github/workflows/security.yml`, `fixtures/Dockerfile`) and proves nothing. This is also the project's no-silent-fallbacks rule: evidence parsing must exit non-zero on a missing artifact or alert, never default to an empty list.

### S-5: Two commit streams

**Source:** CLAUDE.md (this repo is reference documentation; `repos/` is gitignored here), RESEARCH Pitfall 7
Fixture and script commits → `OttawaCloudConsulting/security-platform`. PLAN / SUMMARY / RESEARCH / PATTERNS commits → this outer docs repo. Every plan touching the inner repo needs a preflight that clones-or-fetches, `git checkout -B feature/phase-19-… origin/main`, and asserts `git rev-parse origin/main` — the local checkout is currently on `feature/phase-17-…` (`fbe0071`) and may be **absent entirely** in a fresh worktree (18-05 found it missing and cloned).

### Anti-pattern 1: Adding a fingerprint to `.gitleaksignore`

**Source:** `repos/security-platform/.gitleaksignore` — the entire file today is three comment lines and **zero fingerprints**:

```text
# .gitleaksignore — Gitleaks false positive suppressions
# Format: fingerprint from gitleaks JSON output
# Generate: gitleaks detect --source . --report-format json
```

Gitleaks reads this file from the repo root automatically **in CI as well as locally**. A fingerprint added to quiet the pre-push hook would also silence the `secrets` job and destroy the SC1 detection this phase exists to produce. The correct bypass is `git push --no-verify`, which `.pre-commit-config.yaml` L101 documents as intended.

### Anti-pattern 2: Reading code-scanning evidence from the unfiltered Security tab

Measured: `gh api repos/…/code-scanning/alerts?per_page=3` → `[]`, always, by design (ADR-016 D-02 keeps the trigger `pull_request`-only, so `main` is never analysed). Use `?ref=refs/pull/<N>/merge&tool_name=Semgrep%20OSS`, and hand a human the alert's own `html_url`. Do **not** "fix" the empty tab by adding a `push:` trigger — that silently reverses a locked ADR.

### Anti-pattern 3: `gh run rerun` to re-trigger a measurement

Use `git commit --allow-empty && git push`. A re-run reuses the run id, putting the five fixed artifact names (`semgrep-results`, `checkov-results`, `sca-results`, `trivy-image-results`, `gitleaks-results`) at risk against `upload-artifact@v4` immutability — a confound with nothing to do with gate mode. The empty commit also *is* the SC2 evidence: identical tree hash, empty `git diff`, opposite verdicts.

### Anti-pattern 4: Phrasing SC4 as "zero findings"

`fixtures/` is permanent and lives on `main`, so **every** PR in this repo produces findings in all five jobs, forever. A job is green only because report-only sets `continue-on-error: true`. Phrase SC4 as *"five `security / …` check runs concluded `success`"*, and sequence the clean PR strictly outside the blocking window with `gh variable list` verified empty at run time.

### Anti-pattern 5: Renaming the `security` job in `pr-security.yml`

FROZEN — it is the prefix of all five check-run names, which is what every evidence query in this phase matches on (`select(.name | startswith("security / "))`).

---

## No Analog Found

| File / concern | Role | Data Flow | Reason |
|---|---|---|---|
| `fixtures/vulnerable.py` — ruff interaction | fixture | static input | First `.py` file under `fixtures/`; no prior fixture is matched by a *formatting* hook, and none has ever had to be authored lint-clean. Closest guidance is `fixtures/README.md` L63-67, which is written from the opposite premise ("no hook fires"). Handle with the S-3 verified-not-assumed voice and a `ruff check` + `ruff format --diff` gate before the commit. |
| `fixtures/secret.env` — file extension | fixture | static input | No `.env` fixture exists. Confirmed safe: the inner `.gitignore` has no `*.env` entry, and GitHub secret-scanning push protection is disabled on the repo. Comment syntax follows `requirements.txt` (`#`, no shebang). |

Everything else in scope has a direct in-repo analog; no file needs to fall back to RESEARCH's generic patterns.

---

## Metadata

**Analog search scope:** `repos/security-platform/fixtures/`, `repos/security-platform/scripts/`, `repos/security-platform/.pre-commit-config.yaml`, `.gitleaksignore`, `.gitignore`, `.markdownlint*`, `.planning/phases/18-configurable-gate-mode-and-branch-protection/`
**Files read in full or in targeted ranges:** 13
**Analogs selected:** 5 primary (`fixtures/main.tf`, `fixtures/Dockerfile`, `fixtures/requirements.txt`, `scripts/smoke-scans.sh`, `18-05-SUMMARY.md`/`18-05-PLAN.md`) + 1 self-analog (`fixtures/README.md`)
**Line numbers:** absolute, from `cat -n` / `grep -n` against the files named above at local HEAD `fbe0071`; the fixture and script trees are byte-identical to `origin/main` `2e29004`
**Pattern extraction date:** 2026-09-12
