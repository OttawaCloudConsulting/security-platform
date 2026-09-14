# ADR-018: Workflow Packaging, Canonical Host, and Versioning

**Status:** Accepted
**Date:** 2026-09-14
**Addresses:** DIST-06, DIST-07, DIST-08 — a copy-paste template, a reusable `workflow_call` reference against a
stable published ref, and adoption docs covering both consumption modes

## Context

- **`OCC-github` is not a GitHub account.** `gh api orgs/OCC-github` and `gh api users/OCC-github` both 404;
  the identifier was never a real organisation or user. D-01's original text — "the canonical files move into
  THIS repo" — assumed a target that does not exist and cannot be created by renaming anything, because the
  actual account operating this project's GitHub presence is `OttawaCloudConsulting`, a User account, not an
  Organization.
- **This repository's own history is disjoint from any remote it could be pushed to.** `gitleaks git .` run
  live against this repository's full history measured 16 findings across 320 commits (RESEARCH C-1) — publishing
  this repository's `.planning/`, `red-team/`, and full commit history as the new canonical host (RESEARCH Q1
  Option A) would have shipped those 16 findings publicly as a side effect of a packaging decision, not a
  security decision made on its own merits.
- **A `workflow_call` reads the CALLING repository's variables, but a caller's workflow-level `env` does not
  propagate into the callee** — the identical asymmetry ADR-017 recorded for `gate_mode` (D-02/D-03), now
  bearing on where the callee itself may live: a second, drifted copy of `security.yml` checked into this repo
  would have no mechanism to detect that it disagreed with the canonical file.
- **The container job's `Upload container reports` step already carried `if: always() &&
  steps.docker.outputs.found == 'true'`** (D-04, Phase 16) — but nothing upstream of Phase 20 had ever made the
  container *build* itself conditional; the job's Docker build step ran unconditionally, so a consumer
  repository with no Dockerfile would have hit a hard `docker build` failure, not a clean skip.
- **The `v1` moving tag and `v1.0.0` immutable tag point at the same commit, but a tag object dereferences
  differently from a commit object.** `gh api repos/.../git/ref/tags/v1.0.0 --jq .object.type` returns `tag`
  (one extra dereference to reach the commit); the same call against `v1` returns `commit` directly. An
  annotated moving tag would force that second dereference on every consumer-side check, on every run, forever.
- **`gh api repos/OttawaCloudConsulting/aws-zabbix-monitoring-solution/code-scanning/analyses` returned `403
  Code scanning is not enabled for this repository`** (20-01 Task 2, run `34802848411`) — a GHAS-licensing
  gate on a private repository, not a token-scope problem: both the tolerant `upload-sarif` step and an
  in-workflow `GITHUB_TOKEN` read with `security-events: write` hit the identical error.
- **This repository has no `docs/` tree in `security-platform`** to hold a release-notes file with a second
  reader, and `gate_mode` was already the only per-repo substitution point ADR-017 established — any packaging
  decision in this phase had to preserve that property rather than introduce a second one.

## Decision

- **`OttawaCloudConsulting/security-platform` is the canonical host** (**Correction to D-01**: D-01 originally
  stated the canonical files move into this repository; that premise is impossible, not merely inconvenient —
  `OCC-github` returns a 404 as both an org and a user lookup, and this repository's own history is disjoint
  from any remote it could safely become public through). Rejected alternative: RESEARCH Q1 Option A, creating
  a new public repository from this repository's own history and publishing the 16 `gitleaks git .` findings
  measured across its 320 commits as a side effect.
- **Exactly one copy of the workflow exists.** No `templates/` directory in this repository; Mode A (copy-paste)
  fetches three files at the published tag directly from `security-platform`; the Mode B (`workflow_call`)
  caller is documented inline in `docs/adoption-guide.md`. Rejected: a checked-in template copy in this
  repository, because a second source of truth cannot be diffed against the canonical file and would drift
  silently, the same class of failure ADR-017 avoided for `gate_mode` by refusing a caller-side `with:` block.
- **The host keeps `uses: ./.github/workflows/security.yml`** (RESEARCH Q5 inverted from its original
  recommendation): `security-platform` is the workflow's producer, so its own pull requests keep proving the
  canonical file correct BEFORE any tag is cut, removing the tag-before-proof inversion RESEARCH Pitfall 5
  described and the temporary un-pin procedure that inversion would have required at every release.
- **Dual tagging: annotated immutable `v1.0.0` plus a LIGHTWEIGHT moving `v1`.** The moving tag is deliberately
  lightweight, not annotated: an annotated tag makes `git/ref/tags/v1` return a tag object (`object.type ==
  "tag"`), forcing a second dereference to reach the commit on every consumer-side check; a lightweight tag
  returns `object.type == "commit"` directly. Release notes are inline in the GitHub release body rather than
  `--notes-file`, because the host has no `docs/` tree and a release-notes file there would have no second
  reader. No version comment sits beside any tag reference in the consumer-facing files — `gate_mode` remains
  the only substitution point, and a version comment would be a second one.
- **The portability pass implements D-04's premise rather than changing scanning behaviour** (**Correction to
  D-04's stated premise**: D-04 stated the container job auto-detects a Dockerfile; before Phase 20's plan 03,
  no such detection existed — the build step ran unconditionally and a Dockerfile-free consumer would have hit
  a hard failure, not a skip). The fix: the three ecosystem detectors (npm, Python, Terraform) inlined into
  `security.yml` itself, and the container job made conditional on a `Detect Dockerfile` step whose
  `steps.docker.outputs.found == 'true'` output was compounded onto six downstream steps, reusing the identical
  `always() &&`-after-a-guard pattern ADR-017's own Phase 18 blocking-mode work established for a sibling
  problem. Plan 02's A4 pathspec measurement (the naive three-item Dockerfile pathspec matched a `docs/`
  decoy; the corrected five-item form did not) and plan 06's live finding-count comparison against the Phase 19
  baseline (semgrep 8 → 7, traced to the exact deleted file that carried the one non-reproduced finding, not an
  unexplained drift) both show WHERE detection happens changed while WHAT is found did not.
- **The private-repository capability disposition** (plans 01, 04, 11), stated as measured: probe run
  `34802848411` on `aws-zabbix-monitoring-solution` confirmed `upload-sarif` fails with "Code scanning is not
  enabled for this repository" on a private consumer; the guard `&& github.event.repository.private == false`
  was compounded onto the six SARIF verify steps only, never onto the six upload steps and never onto the five
  artifact verify steps (artifact upload authenticates via `ACTIONS_RUNTIME_TOKEN`, unaffected by GHAS
  licensing). No verify step was deleted — a guard skips an assertion that cannot pass; deleting it would hide
  that the capability is absent. Plan 11's live proof on `aws-zabbix-monitoring-solution` (PR #8, run
  `34887388960`) confirmed all six SARIF verifies skip cleanly while the underlying uploads still ran and still
  failed with the identical 403, exactly as designed. Recorded as a deliberate non-decision: no
  `expect_code_scanning` boolean `workflow_call` input was added, because it would be a second per-repo
  substitution point and would reintroduce the same drift risk `gate_mode` was designed to avoid; a consumer
  that needs this input does not yet exist.
- **`gate_mode` remains the only per-repo substitution point and the only `workflow_call` input**, expressed in
  the consumer-facing files as a header-comment adoption banner plus a `gh variable set GATE_MODE` command,
  never as a placeholder token requiring a YAML edit — carrying forward ADR-017's `""`-counts-as-provided
  mechanism (D-... in ADR-017) that makes a caller-side passthrough forbidden. Rejected: a placeholder-token
  substitution scheme (e.g. `<OWNER>/<REPO>`), because it would require every consumer to edit YAML, defeating
  the property `gate_mode`-only substitution exists to preserve.
- **Two stale artifacts were deleted**: `repos/security-platform/cicd/.github/workflows/security.yml` (203
  lines; measured defects recorded as the deletion rationale — unpinned action version, `--config auto`, a
  bare `|| true` masking failures, a missing permission, no `gate_mode`) and
  `repos/security-platform/cicd/renovate.json` (superseded by the shipped `dependabot.yml`). The blueprint's
  illustrative GitHub Actions section in `docs/development-security-stack-option-1.md` was retitled — "##
  Complete GitHub Actions Workflow (Illustrative — Not the Deployable Template)" — rather than replaced or
  deleted (RESEARCH Q3 option (a)): the four-phase structure, ASCII diagrams, tool coverage matrices, and
  comparison table this project's `CLAUDE.md` requires be preserved are all outside that section's edited hunk
  and remain byte-unchanged. The three-copies-become-one outcome: before this phase, the workflow existed as a
  deployable `cicd/` copy, an illustrative blueprint section, and the canonical `security-platform` file; after
  it, exactly one deployable copy exists, and the illustrative section is unambiguously labelled as such.
- **Inherited correction restated, not re-decided: the required-check set is FIVE contexts, not six.**
  ADR-017 records this (its own Correction to D-06); this ADR cites it by name so a reader of ADR-018 alone
  does not reintroduce a sixth context into a required-check list built from this phase's adoption guide.

## Consequences

**Improved:** measured across three live pilot pull requests outside this repository, none of which existed
before this phase. PR #12 on `terraform-pipelines` (public, Mode A copy-paste, run `34884582425`): five
`security / …` checks `success`, four artifacts (not five — Dockerfile-free, derived from the guard structure
before running and confirmed exactly). PR #13 on `terraform-pipelines` (public, Mode B `uses:` reference, run
`34885287142`): five checks `success`, the external `uses:` reference resolved to
`cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef` — the exact commit both `v1` and `v1.0.0` point to — and the sorted
check-run name list is byte-identical to Mode A's (`diff` exit 0). PR #8 on
`aws-zabbix-monitoring-solution` (private, Mode A, run `34887388960`): five checks `success`, all six SARIF
verify steps skipped cleanly, four artifacts landed at 90-day retention, `code-scanning/analyses` still `403`
after the run. The host's own PR #13 (`security-platform`, run `34870572604`) merged the portability pass as
commit `cdf2c21`, and both `v1`/`v1.0.0` were cut from that exact commit and API-verified.

**Improved:** a `gh variable set`/`gh variable delete` flip on `security-platform`'s own PR #9 (ADR-017,
inherited) plus this phase's independent branch-protection dry run (`scripts/set-required-checks.sh --out`,
never `--apply`) on `terraform-pipelines`'s live ruleset — confirmed pre- and post-run identical
(`rules/branches/main` unchanged, `bypass_actors: []` carried forward verbatim) — together demonstrate the
required-check mechanism works against a real external ruleset, not only against this project's own.

**Tradeoff — a moving `v1` is mutable by design.** Any future push to `v1` changes what every Mode A
copy-paste and Mode B `uses: …@v1` consumer resolves to, without their own repository's history recording the
change. `v1.0.0` exists specifically as the immutable escape hatch for a consumer that cannot tolerate that.

**Tradeoff — a Mode B consumer takes a run-time dependency on a repository containing deliberately vulnerable
`fixtures/`.** `security-platform`'s own `main` permanently carries `fixtures/Dockerfile`, `fixtures/main.tf`,
and the npm/Python fixtures Phase 15/16/19 seeded; a Mode B consumer's CI run fetches and executes YAML from
that repository at the pinned ref on every run. The fixtures do not execute against the consumer's own
checkout, but the dependency itself is real and is the price of the reusable-workflow consumption mode ADR-017
and this ADR both require.

**Tradeoff — the adoption guide and the canonical YAML are two artifacts that can drift.** Plan 12 corrected
every discrepancy this phase's own live pilots found between `docs/adoption-guide.md` and the measured
behaviour of `security.yml`/`pr-security.yml` (the `yamllint` "no output" overclaim, the "five artifacts still
land" overclaim now hedged to "the applicable artifacts," a fifth preflight probe). The only mitigation against
future drift is `scripts/check-adoption-guide.sh`, which derives its frozen check-run contexts from the
workflow source via `grep` rather than from a copy pasted into the script — a wording drift in prose that the
script does not assert against remains possible.

## What was NOT verified

What WAS measured and must not be re-litigated: the canonical host's tag identity (`v1` and `v1.0.0` both
resolve to `cdf2c211ed4c4397e8b3fed9e25cec93ffaca5ef`, API-verified); byte-identity of all three Mode A files
against `origin/main` on three separate pilot runs; the Mode A/Mode B check-run name parity (`diff` exit 0);
the private-repository guard's actual effect (six verifies skip, uploads still run and still fail with the
identical 403); and the five-not-six required-check-context correction ADR-017 already recorded.

1. **Whether a fork pull request can read repository `vars` at all** — one non-docs source (a GitHub staff
   forum post, January 2023), never measured in this project. The literal `with: gate_mode: blocking` form
   documented in the adoption guide exists specifically so a public-repository operator does not have to
   depend on the answer.
2. **The account's actual GitHub plan is unknown** — `gh api user --jq .plan` returns empty because the local
   token lacks the `user` scope, so private-repository feature availability was inferred from the A1 measurement
   alone, not from a read plan tier.
3. **Whether `job.workflow_repository` / `job.workflow_file_path` are usable in `if:`/`with:` expressions** was
   never exercised — it only bears on an alternative this phase rejected, not on the shipped design.
4. **Whether a GHAS-bearing organisation consumer behaves differently from the two pilots measured here** — both
   pilots (`terraform-pipelines`, `aws-zabbix-monitoring-solution`) sit under the same personal account this
   project's own host repository does; no organisation-owned, GHAS-licensed consumer was available to test
   against.
5. **Whether the Dockerfile detection pathspec matches `Containerfile`** — the five-item pathspec measured in
   plan 02 matches `Dockerfile`, `*/Dockerfile`, `Dockerfile.*`, `*/Dockerfile.*`, and `*.dockerfile`; it was
   never tested against the Podman-style `Containerfile` naming convention, and no consumer repository using
   that convention was available.
6. **Whether the `cicd/` Azure DevOps and GitLab pipeline members were ever built or validated** — they were not
   deleted (Chesterton's fence: unvalidated draft work, not superseded-and-dangerous like the deleted GitHub
   copy) but this phase did not build or run either of them; they remain unvalidated drafts.
7. **Whether any repository has required checks actually enabled** — `security-platform`'s own `main` remains
   `leave-unrequired` per ADR-017's own recorded operator decision, and this phase's branch-protection work on
   both pilot repositories stayed a dry run (`--out`, never `--apply`). Required-check adoption stays deferred
   past this phase, as it has been since ADR-017 / 18-05 and reaffirmed at 19-07.
8. **Whether `actions/upload-artifact` itself succeeds on a fork or Dependabot-triggered run** — inherited
   unresolved from ADR-016/ADR-017; no fork or Dependabot run was measured in this phase either.
