# Adoption Guide

This guide walks a maintainer of another repository through adopting the reusable CI/CD security
scanning pipeline built and validated in Phases 14-19 of this project. It covers what you get,
how to check in advance whether it will work in your repository, how to pick a consumption mode,
what each mode costs in files, and what a green first run does and does not prove.

## 1. Who This Is For and What You Get

You maintain a GitHub repository and want automated security scanning on every pull request, with
no new accounts, no secrets to manage, and no ongoing cost. After adopting this pipeline you get:

- Five parallel scan jobs on every pull request, covering static analysis (Semgrep CE), IaC
  misconfiguration (Checkov), software composition analysis (Trivy filesystem, plus npm audit,
  pip-audit, and tflint where a matching manifest exists), container vulnerabilities (Trivy image,
  conditional on a discovered Dockerfile), and secrets detection (Gitleaks).
- Five JSON/SARIF artifacts retained for 90 days on every run, downloadable from the run page.
- Code-scanning annotations on changed lines, on repositories that support code scanning.
- Advisory (report-only) behaviour by default — findings are visible but never block a merge
  until you explicitly opt in to blocking.

**There are no secrets to provision.** Every scanner in this pipeline is account-free — Semgrep CE
runs the `p/default` registry ruleset with no API key, Checkov and Trivy and tflint and Gitleaks
and npm audit and pip-audit are all local, unauthenticated tools. The pipeline's only credential is
the `GITHUB_TOKEN` GitHub already issues to every workflow run; nothing else is ever supplied.

## 2. Preflight

Run these four checks before changing anything in your repository. Each command below carries the
expected output for both branches, because every failure in this domain fails silently green — a
wrong pathspec, a dropped ruleset rule, a mistyped em dash, or a missing caller permission produces
a run that still looks fine at a glance.

### Prerequisites

| Requirement | Minimum | Verify |
|-------------|---------|--------|
| GitHub CLI (`gh`), authenticated with `repo` scope | any recent version | `gh auth status` |
| Admin on the target repository (only if you intend to set required checks later) | — | `gh api repos/OWNER/REPO --jq .permissions.admin` |

The four probes below use `OttawaCloudConsulting/terraform-pipelines` as the worked example,
because its responses were measured live against this exact pipeline.

```bash
REPO=OttawaCloudConsulting/terraform-pipelines

gh api "repos/$REPO" --jq '.private, .visibility'
  ## Expected: "false" then "public" -> SARIF uploads will land normally.
  ## Expected: "true" then "private" -> see the Private repositories section, further in this guide.

gh api "repos/$REPO/code-scanning/analyses" 2>&1 | head -2
  ## Expected: 404 "no analysis found" -> code scanning is AVAILABLE on this repository.
  ## Expected: 403 "Code scanning is not enabled ..." -> NOT available (measured on a private
  ## repository in this account; the Private repositories section explains why and what happens).

gh api "repos/$REPO/rulesets" --jq '.[] | "\(.id)\t\(.name)\t\(.enforcement)"'
  ## Expected: a row -> a ruleset already exists; you will read-modify-write that id later,
  ## never replace it wholesale.
  ## Expected: empty output -> no ruleset exists yet; one must be created before required
  ## checks can be configured.

gh variable list -R "$REPO"
  ## Expected: no GATE_MODE row -> the report-only default applies; this is the correct
  ## starting state for every new adoption.
```

## 3. Pick a Mode

There are two ways to consume this pipeline. Neither is universally better — the table below
states what actually differs, and the axis that should decide is run-time dependency: if your
repository must be able to function with zero external references at scan time, choose Mode A;
otherwise Mode B is one file instead of three and updates itself.

| Axis | Mode A (copy-paste) | Mode B (`uses:`) |
|------|---------------------|-------------------|
| Files added to your repository | Three (`security.yml`, `pr-security.yml`, `dependabot.yml`) | One (a caller workflow) |
| Run-time dependency on the canonical repository | No — the copied files are self-contained | Yes — every run resolves `uses:` against the canonical repository at the pinned ref |
| How updates arrive | Dependabot bumps roughly eight pinned action SHAs inside your copied file | Dependabot bumps the single `@v1` reference |
| Can a job be removed locally without editing the canonical source | Yes | Yes — an absent ecosystem (no Dockerfile, no `package-lock.json`, and so on) is detected and skipped cleanly, with the skip stated in the run log, so there is nothing to remove even in Mode B |
| Auditability | Pin any commit you copied; nothing to re-fetch | Can pin the immutable `@v1.0.0` tag for an audit-stable reference |

The one substitution point in either mode is `gate_mode` — see sections 4 and 5.

## 4. Mode A — Copy the Files

Fetch three files from the published tag and place them, unmodified, into your own `.github/`
directory. There are **zero edits to make**.

```bash
mkdir -p .github/workflows
curl -fsSL -o .github/workflows/security.yml \
  https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/.github/workflows/security.yml
curl -fsSL -o .github/workflows/pr-security.yml \
  https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/.github/workflows/pr-security.yml
curl -fsSL -o .github/dependabot.yml \
  https://raw.githubusercontent.com/OttawaCloudConsulting/security-platform/v1/.github/dependabot.yml
git add .github && git commit -m "ci: adopt security scanning pipeline (report-only)"
```

`pr-security.yml`'s `uses: ./.github/workflows/security.yml` line is a relative reference. It
resolves correctly precisely BECAUSE `security.yml` is copied alongside it in the same commit —
if you fetch only `pr-security.yml`, that reference has nothing to resolve against.

**Files deployed:**

| File | Destination | Description |
|------|-------------|-------------|
| `security.yml` | `.github/workflows/security.yml` | The callable workflow: five scan jobs, `gate_mode` input, SARIF upload |
| `pr-security.yml` | `.github/workflows/pr-security.yml` | The `pull_request` caller that invokes `security.yml` |
| `dependabot.yml` | `.github/dependabot.yml` | Keeps the pinned action SHAs inside your copy current |

**Moving-tag cache warning.** `raw.githubusercontent.com` caches a tag's content for roughly five
minutes. A fetch performed immediately after a brand-new release may return the *previous*
content at that tag if the tag was just repointed. Do not assume the fetch is current — verify it
with the offline check below rather than trusting the fetch alone.

**Offline post-copy check**, run once the three files are in place:

```bash
actionlint .github/workflows/security.yml .github/workflows/pr-security.yml
  ## Expected: no output, exit code 0.
yamllint -d relaxed .github/workflows/security.yml .github/workflows/pr-security.yml
  ## Expected: no output, exit code 0.
```

## 5. Mode B — Reusable Workflow Call

Add exactly one file to your repository, `.github/workflows/pr-security.yml`. This is the entire
file — every grant and every comment shown below matters and should be kept:

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
    # branch-protection required context at once, and a required context
    # with no matching check run sits permanently pending rather than
    # failing outright — which is why it is frozen.
    name: security
    # A job-level permissions block REPLACES the workflow-level set for this
    # job, so contents: read must be restated here or checkout inside the
    # called workflow loses its read scope. This block is also the CEILING
    # for the called workflow — it can only reduce what is granted here,
    # never elevate. Omitting security-events: write 403s every SARIF
    # upload while the run still reports green.
    permissions:
      contents: read
      security-events: write
      actions: read          # required only for private repositories
    uses: OttawaCloudConsulting/security-platform/.github/workflows/security.yml@v1
    # No `with:` block, deliberately. Two traps to avoid if one is ever added:
    #   - A bare passthrough, `with: { gate_mode: ${{ vars.GATE_MODE }} }`, is
    #     FORBIDDEN: an unset variable resolves to the empty string, which
    #     counts as a PROVIDED input and suppresses the callee's own
    #     "report-only" default. This is a prohibition, not an example to copy.
    #   - A public repository that genuinely needs to block on fork pull
    #     requests may need a literal `with: { gate_mode: blocking }` instead
    #     of the variable path, because whether a fork PR's job can even read
    #     repository variables at all is UNVERIFIED by this project.
```

`@v1` is deliberately given no trailing version comment. This project's SHA-pin-with-comment
convention (Phase 14) works because a SHA never moves; `@v1` does — it is repointed to each new
patch release, and a hand-written `# v1.0.0` beside it would rot silently the moment the tag
advances. Dependabot maintains comments on SHA pins, not on tag references. If you need an
immutable, audit-stable reference instead, pin `@v1.0.0` directly; that costs you an explicit pull
request every time you want to move forward, in exchange for a reference that never changes
underneath you.

**The plus-one file for Mode B** is the same `dependabot.yml` shown in Mode A — copy it verbatim
so Dependabot keeps your `@v1` reference (an external reusable-workflow reference, supported since
2023-03-13) current, exactly as it would keep Mode A's pinned action SHAs current.

## 6. First Run — What to Expect

Open a pull request after adopting either mode. You should see:

- Five check runs, prefixed by your caller job's id, on the pull request.
- The pull request stays mergeable.
- Five artifacts downloadable from the run page.
- Code-scanning annotations on changed lines, on repositories where code scanning is available.

**Green does not mean clean.** Under the default `report-only` gate mode, every scan step carries
`continue-on-error: true`, so a run that reports dozens of findings still shows five green checks.
A live measurement on this project's own validation pull request recorded 8 Semgrep findings, 11
Gitleaks findings, 14 Checkov findings, 58 Trivy image findings, 6 Trivy filesystem findings, and 3
tflint findings — across five checks that all concluded successfully. Green is report-only
tolerance, not an absence of findings.

The findings themselves live in two places: the Security tab (public repositories only) and the
run artifacts (always, regardless of visibility). To list and download them:

```bash
gh run view <RUN_ID> --json artifacts --jq '.artifacts[].name'
  ## Expected: five artifact names, one per scan job.
gh run download <RUN_ID> --dir ./scan-results
  ## Expected: the artifact contents extracted under ./scan-results, one subdirectory per artifact.
```

Before you consider switching to `blocking`, internalise this corollary: `blocking` is
severity-agnostic — it fails the run on ANY finding, regardless of severity. A repository that
already carries pre-existing HIGH or CRITICAL findings cannot go blocking until those findings are
fixed, because the very first run under `blocking` will fail on them.

## 7. Gate-Mode Selection

`report-only` is the default and needs no action — every scan step tolerates its own findings via
`continue-on-error`, so the five checks conclude green regardless of what they find. Going to
`blocking` is one command, not a YAML edit:

```bash
gh variable set GATE_MODE --body blocking -R OWNER/REPO
```

This is measured, not a hypothesis: 18-05 recorded three commits sharing one identical tree hash
across all three `gate_mode` states, and 19-05 measured that same identical tree producing five
FAILURE checks under `blocking` and five SUCCESS checks under `report-only`, with only the
repository variable changed between runs.

`gate_mode` resolves as an enum, `blocking` or `report-only`, validated by a `case` statement as
the very first step of all five jobs:

```bash
case "${GATE_MODE}" in
  blocking|report-only) echo "gate_mode=${GATE_MODE}" ;;
  *) echo "invalid gate_mode: '${GATE_MODE}' (expected blocking|report-only)"; exit 1 ;;
esac
```

A misspelling or a blank value FAILS the job rather than being silently tolerated as either
state — fail-closed by design.

Two caveats:

- **`blocking` is severity-agnostic.** It fails the run on ANY finding, from any of the four SCA
  sub-scanners (Trivy filesystem, npm audit, pip-audit, tflint) as well as from the other four jobs
  (SAST, IaC, container, secrets). There is no pipeline-level severity knob.
- **A fork pull request cannot read repository variables — UNVERIFIED.** This project's only
  source for that claim is a January 2023 GitHub staff forum answer, and it was deliberately never
  measured here (19-07). A public repository that genuinely needs `blocking` enforced on fork PRs
  must pass a literal `with: gate_mode: blocking` from its caller rather than relying on
  `vars.GATE_MODE`, because a fork PR resolving that variable to empty would silently fall through
  to `report-only` while a required check still reports green.

## 8. Branch Protection

Adopt in this order — a numbered sequence, not general advice:

1. **Run in `report-only` and confirm the five contexts appear and conclude.** This step cannot
   observe red: a report-only run is green by definition (ADR-017's correction to the original
   ordering). All it confirms is that the checks appear at all.
2. **Flip to `blocking`** (section 7's one command) **and confirm the same five contexts turn
   red** on a pull request that has findings.
3. **Only then make the five contexts required** in the repository ruleset.

Requiring a context before confirming it can actually turn red (step 3 before step 2) leaves
merges effectively un-gated while the repository settings claim otherwise.

**Reading the contexts.** Never retype them — read them from the live check-runs endpoint for a
real commit SHA:

```bash
gh api repos/$REPO/commits/$SHA/check-runs --jq '.check_runs[] | select(.app.id == 15368) | .name'
## Expected:
## security / SAST — Semgrep CE
## security / IaC — Checkov
## security / SCA — Trivy Filesystem
## security / Container — Trivy Image
## security / Secrets — Gitleaks
```

The check-runs endpoint (`app.id == 15368`, the GitHub Actions app) is the only correct source.
The code-scanning `analyses` endpoint disagrees with it on case for two of the five tools
(`checkov` vs `Checkov`, `Gitleaks` vs `gitleaks`), and branch protection matches the check-run
name, not the analysis name. The naming rule is `<caller job id> / <called workflow job name>`;
the caller job itself (`security`) emits no check run of its own, so there are five contexts here,
not six.

**Two ruleset paths.** A repository that already has a ruleset (`gh api repos/$REPO/rulesets`
returns a row) is read-modify-written at that id. A repository with `[]` — no ruleset yet — must
create one first with `POST /repos/OWNER/REPO/rulesets`; `scripts/set-required-checks.sh` does
not implement that create path, so say so plainly rather than implying the script covers it.

**What the script actually does**, run as `bash scripts/set-required-checks.sh [flags]` (never
chmod it executable):

- **Dry run by default.** Reads the ruleset, builds the merged document, writes it to `--out`
  (default `/tmp/set-required-checks-out.json`), prints a before/after rule-type comparison, and
  touches nothing on GitHub.
- **`--apply` refuses without `--verify-sha`** (exit 4) — confirms all five contexts appear live
  in `commits/<sha>/check-runs` with `app.id 15368` before any write is attempted.
- **`--apply` refuses without `--yes-i-understand-lockout`** (exit 5) — see the self-lockout
  warning below.
- **Exit 3** when the merged document would drop a pre-existing rule type — never written
  anywhere.
- **Exit 6** when `--verify-sha` finds a context missing from the live check-runs for that SHA —
  a context GitHub has never seen becomes a permanently-pending required check, not a failing one,
  so the script refuses rather than create that trap.

These refusals are features, not friction — teach them as such, never as a workaround to bypass.

**Why the read-modify-write matters.** A bare `PUT /repos/{owner}/{repo}/rulesets/{id}` carrying
only `required_status_checks` silently deletes every other rule type already on `main`, including
`deletion` and `non_fast_forward` — a security regression dressed as an improvement.
`bypass_actors` must be carried forward verbatim from the existing document, never synthesised.
Read back from `rules/branches/main` — never the classic `branches/main/protection` endpoint,
which 404s by design on a ruleset-governed repository (that 404 is a false negative, not evidence
of anything).

**Self-lockout warning.** Rulesets do not auto-exempt repository admins: measured on
`security-platform`, `bypass_actors: []` and `current_user_can_bypass: "never"`. Under `blocking`
with the five checks required, a repository whose scanners always find something can never merge
into `main` again — including the pull request that would revert the change. Add a bypass actor
first if you are unsure, and require the checks only after a clean pull request has actually gone
green under `blocking`. This is exactly why `security-platform`'s own `main` deliberately leaves
the five checks unrequired — `security-platform`'s validation-only `fixtures/` tree guarantees
findings on every run.

See the blueprint's [§Phase 2 — CI/CD Security Gate](development-security-stack-option-1.md) for
the underlying branch-protection rationale; this section does not restate it.

## 9. Dependabot Wiring

The same 13-line `dependabot.yml` file works in both modes, with one differing consequence:

- **Mode A** — Dependabot keeps roughly eight SHA-pinned actions inside your copied `security.yml`
  current.
- **Mode B** — Dependabot keeps exactly one `@v1` reference current; the canonical repository's
  own Dependabot keeps those action SHAs current on your behalf.

Both halves of the local-versus-external rule matter:

- `uses: ./.github/workflows/security.yml` (a local, relative reference) is **never** proposed for
  update, by design — Dependabot does not resolve relative workflow paths.
- `uses: OWNER/REPO/.github/workflows/<workflow>.yml@v1` (an external reusable-workflow
  reference) **is** supported and updated, since 2023-03-13.

`directory: "/"` in `dependabot.yml` is required for `.github/workflows` discovery and must not be
"corrected" to `/.github/workflows`.

**The Dependabot consequence you will meet:** a Dependabot pull request receives a read-only
token, so the SARIF uploads on that run cannot land and the verify steps that check they landed
skip by design (17-03). A Dependabot PR showing fewer annotations than a normal PR is expected
behaviour, not a broken pipeline.

## 10. Which Jobs Apply Where

The Phase 20 portability pass means, in **both modes**, an absent ecosystem now skips cleanly and
says so in the log:

```text
SKIP: no package-lock.json found — npm sub-scan not applicable to this repository
SKIP: no requirements*.txt found — Python sub-scan not applicable to this repository
SKIP: no .tf files found — Terraform pinning sub-scan not applicable to this repository
SKIP: no Dockerfile found — container sub-scan not applicable to this repository
```

Because of this, most repositories need no removal at all. The matrix below states which of the
five jobs actually does something for each repository type, and why:

| Repository type (real examples) | SAST | IaC | SCA | Container | Secrets |
|---|---|---|---|---|---|
| Terraform / IaC (`terraform-pipelines`, `occ-tg-infra-platform`) | keep | keep | keep (tflint fires) | skip — no Dockerfile | keep |
| Node/CDK (`aws-zabbix-monitoring-solution`) | keep | keep (checks GitHub Actions + any Kubernetes YAML) | keep (npm audit fires) | keep if a Dockerfile exists | keep |
| Python | keep | keep | keep (pip-audit fires) | keep if a Dockerfile exists | keep |
| Docs-only / config-only (`rss-feeds`, `CV`) | keep (cheap, near-zero findings) | keep | keep (all four sub-scans SKIP cleanly) | skip | keep |
| Kubernetes manifests (`occ-k8s-app-config`, `k8s-cluster-config`) | keep | keep | keep | skip | keep |

**Removal recipe**, for the one case that remains — Mode A only, an ecosystem with genuinely
nothing to scan and a maintainer who wants the job gone entirely rather than skipping: delete the
whole top-level job block (from its `<job-id>:` line through its last step) out of the copied
`security.yml`. Two mandatory warnings:

1. **If that check is already in a ruleset's `required_status_checks`, remove it from the
   ruleset first.** A required context with no matching check run sits permanently pending, not
   failing.
2. **Never rename a job you keep.** The five contexts are frozen byte-exact; renaming one
   silently breaks branch protection for everything pointed at the old name.

In **Mode B**, jobs cannot be removed — and per the skip behaviour above, they do not need to be:
an absent ecosystem runs, detects nothing, and skips cleanly, exactly like Mode A. No
config-driven job-selection mechanism exists here, by deliberate decision (D-04); this table and
this recipe are the entire SC4 answer.

## 11. Private Repositories

Measured, not inferred: on a private repository in this account
(`aws-zabbix-monitoring-solution`), `upload-sarif` failed with `Code scanning is not enabled for
this repository` — a GitHub Advanced Security licensing gate, not a generic token-scope 403
(Phase 20 plan 01, run id `34802848411`). Both the tolerant upload step and an in-workflow
`GITHUB_TOKEN` read (with `security-events: write`) hit the identical error, so the outcome is
confirmed, not ambiguous.

Left alone, this would turn every scan job red on a private repository even under `report-only`,
because the six `Verify … SARIF upload landed` steps have no `continue-on-error` and exist
precisely to stop a broken-but-green pipeline. Phase 20 plan 04 applied the fix directly in the
canonical `security.yml`: each of those six verify steps carries the guard

```text
&& github.event.repository.private == false
```

compounded onto its existing `if:` condition. **This never deletes a verify step** — it skips an
assertion that cannot pass on a repository with no code-scanning capability, and it never removes
a check that could pass. On a private consumer today you should see: the SARIF upload step still
runs and its verify step skips cleanly (no red job for that reason), the scan step and the
artifact upload/verify pair still work normally, and the five artifacts still land — the findings
live in the run artifacts rather than in the Security tab.

Do not tell a private consumer to delete the verify steps instead — that trades a visible,
understood skip for an invisible hole where a genuinely broken upload would go unnoticed.

**Account-level limitation.** This is a User account, not an Organization, so no repository it
owns can carry GitHub Advanced Security — this is a platform limitation, not a bug in the
pipeline. An organisation-owned repository with GHAS enabled would behave differently (its SARIF
uploads would land and its verify steps would run normally). The correct evolution there is a new
`workflow_call` boolean input naming that expectation explicitly, deliberately not built
speculatively here — a second per-repo substitution point would break D-04's "one substitution
point" guarantee.

## 12. Troubleshooting

### Private-repo SARIF verify steps skip instead of running

**Symptom:** the six `Verify … SARIF upload landed` steps show as skipped rather than passed or
failed, on a private repository.
**Cause:** the capability guard from section 11 — code scanning is unavailable on this
repository.
**Action:** this is expected, not a defect. Confirm the scan step and the artifact upload for
that job both succeeded; the findings are in the artifact, not the Security tab.

### A required check sits "Waiting for status to be reported" forever

**Symptom:** a pull request shows one or more required checks stuck at "Expected — Waiting for
status to be reported" and it never resolves, even after the workflow run completes.
**Cause:** the required context's name does not match any check run GitHub has actually seen — a
typo, a wrong dash character, or a renamed/removed job.
**Action:** re-read the five contexts from `commits/<sha>/check-runs` (section 8) and compare
byte-for-byte against what the ruleset requires; correct the ruleset entry to match exactly, or
remove it if the job was intentionally deleted (section 10's removal recipe).

### A ruleset lost rule types between reads

**Symptom:** `gh api repos/$REPO/rules/branches/main --jq '.[].type'` shows fewer rule types
after a change than it did before — for example `deletion` or `non_fast_forward` disappeared.
**Cause:** a whole-document `PUT /rulesets/{id}` was sent carrying only the new rule, replacing
everything else that existed.
**Action:** never write a ruleset by hand; use `scripts/set-required-checks.sh`, which refuses
(exit 3) to write a document that would drop a pre-existing rule type. Restore the dropped rule
type from a captured `before` document if you have one.

### Self-lockout under blocking with required checks

**Symptom:** no pull request can be merged into `main`, including the pull request meant to
revert the change that caused this.
**Cause:** rulesets do not exempt repository admins by default (`bypass_actors: []`,
`current_user_can_bypass: "never"`), and the repository's scanners always find something under
`blocking`.
**Action:** add a bypass actor (your own admin role) in Settings → Rules → Rulesets → the
ruleset → Bypass list, merge or revert from there, then only re-require the checks once a clean
pull request has gone green under `blocking`.

### Action SHAs never update

**Symptom:** Dependabot never opens a pull request bumping the pinned action SHAs inside a Mode A
copy of `security.yml`.
**Cause:** `dependabot.yml` was never copied alongside the two workflow files.
**Action:** copy `dependabot.yml` from the published tag (section 4); it is a required third
file, not optional.

### A fork or Dependabot pull request shows no annotations

**Symptom:** a pull request from a fork, or opened by Dependabot, shows five green (or red)
checks but no code-scanning annotations and no SARIF-derived comments.
**Cause:** both a fork PR and a Dependabot PR receive a read-only `GITHUB_TOKEN`, so the SARIF
upload cannot land and its verify step skips by design.
**Action:** this is expected, not broken. Check the run artifacts for the actual findings; do not
expect Security-tab annotations on these run types.

### A SKIP line appears on a repository that does have that ecosystem

**Symptom:** the log shows `SKIP: no package-lock.json found` (or the requirements/Terraform/
Dockerfile equivalent) on a repository you know has that file.
**Cause:** the detector reads `git ls-files`, so a manifest that is `.gitignore`d or simply
uncommitted is invisible to it — this is a pathspec/`.gitignore` question, not a pipeline bug.
**Action:** confirm the file is tracked with `git ls-files -- '<pattern>'` locally; commit it if
it is not.

### A job is red with a green scan step above it

**Symptom:** the scan step itself (Semgrep, Checkov, Trivy, tflint, or Gitleaks) shows green, but
the job as a whole is red.
**Cause:** the SARIF or artifact upload did not land, and its own verify step caught that and
failed.
**Action:** read the verify step's own output — it states the mechanism directly:
`upload outcome=<value> — the upload did not land. Most likely cause: security-events: write
missing from the CALLER (.github/workflows/pr-security.yml), which a called workflow cannot
elevate.` Add the missing permission to the caller's job-level `permissions:` block.

## 13. Cross-References and Validation Checklist

- The blueprint's [§Phase 2 — CI/CD Security Gate](development-security-stack-option-1.md) — the
  original branch-protection rationale this guide's section 8 implements without restating.
- [ADR-016](adr/adr016-sarif-upload-attribution-and-artifact-retention.md) — SARIF categories and
  artifact retention.
- [ADR-017](adr/adr017-configurable-gate-mode-and-required-checks.md) — the `gate_mode` enum and
  the required-checks design this guide documents.
- [ADR-018](adr/adr018-workflow-packaging-canonical-host-and-versioning.md) — this phase's
  packaging, canonical-host and versioning decisions.

**Validation checklist**, adapted from the canonical repository's own:

- [ ] Confirm the five required check-run contexts (section 8) appear on a pull request and
  conclude.
- [ ] Confirm five artifacts are downloadable from the run page.
- [ ] Confirm code-scanning annotations appear, on a public repository.
- [ ] Confirm the D-07 ordering (section 8) before making anything required: report-only green,
  then blocking red, then required.

**One explicit non-instruction:** never add anything resembling `security-platform`'s
validation-only `fixtures/` directory to a consumer repository — a consumer that copies it
inherits permanent findings and can never go blocking.
