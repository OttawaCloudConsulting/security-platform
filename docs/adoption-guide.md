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
