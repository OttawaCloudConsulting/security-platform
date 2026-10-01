# ADR-030: Standing Chart Gates Fail Closed and Run in CI

**Status:** Proposed
**Date:** 2026-09-30
**Addresses:** Phase 26 WR-05 (26-REVIEW) — the chart gates exited 0 with SKIP when the chart or its guard
template was missing and ran in no workflow — and Phase 26 WR-04 (the preflight hint did not work on a fresh clone)

This record lives in this documentation repository. The two gate script headers
(`scripts/check-defectdojo-chart.sh`, `scripts/check-nexus-chart.sh`) and the header of
`.github/workflows/chart-gates.yml` in the public `security-platform` repository cite it by number, so a reader of
the public repository cannot follow the link. That is the arrangement ADR-022 to ADR-029 recorded. Every measured
value below is quoted from a Phase 29.3 plan summary (29.3-01 to 29.3-03) or from a file in that phase's `evidence/`
directory, and each is attributed where it appears. Values that can exist only after the merge (the PR number, the
merge SHA and the live run IDs) are written as `FILL-AT-29.3-07` and are filled in when this record is accepted.
"Phase 26 WR-05" is this record's trigger; the findings called WR-05 in Phases 13, 25, 27 and 29 are unrelated.

## Context

- **The gates had a vacuous-pass convention.** Both offline chart gates were written while their charts were being
  built (plans 23-01 for Nexus and 26-01 for DefectDojo). Each began with two guards: if the chart directory was
  missing, or if the chart's guard template was missing, the gate printed `SKIP:` and exited 0. The header block
  "INTERMEDIATE-COMMIT CONVENTION — VACUOUS-PASS" told readers not to delete those guards. The convention lived only
  in the script headers. No ADR recorded it, so this record supersedes nothing.
- **The convention outlived its purpose.** Once the charts were complete and public, the guards meant that deleting
  `kubernetes/defectdojo/templates/validate-tls.yaml` (the TLS issuer guard, ADR-023) or
  `kubernetes/nexus/templates/job-provision.yaml` (the `required` rootPassword control) left the gate green. That is
  Phase 26 WR-05 (26-REVIEW). 29.3-01 reproduced it before any edit, from archive copies of `origin/main` `72cb174`
  (`evidence/29.3-01-red.txt`):
  - dd-guard: `SKIP: chart incomplete — kubernetes/defectdojo/templates/validate-tls.yaml does not exist yet`, `rc=0`
  - dd-dir: `SKIP: chart not present yet — kubernetes/defectdojo does not exist (vacuous pass, by design)`, `rc=0`
  - nexus-guard: `SKIP: chart incomplete — kubernetes/nexus/templates/job-provision.yaml does not exist yet`, `rc=0`
  - nexus-dir: `SKIP: chart not present yet — kubernetes/nexus does not exist (vacuous pass, by design)`, `rc=0`
- **Neither gate ran in CI.** 26-VERIFICATION (L44, L71) confirmed the guard code on `main` and recorded that neither
  `pr-security.yml` nor `security.yml` runs either gate. A gate that only runs on an operator's machine cannot catch a
  regression in a PR.
- **The preflight hint failed on a fresh clone.** When the subchart tarball was not vendored, each gate exited 2 and
  printed `run: helm dependency build <dir>`. On a fresh Helm configuration that command fails with
  `Error: no repository definition for <url>. Please add the missing repos via 'helm repo add'`. ADR-023 (decision 11,
  the PR #20 fix) recorded this for DefectDojo's README; the gate's own hint was left unfixed (Phase 26 WR-04).
  ADR-023 "What was NOT verified" item 8 recorded that the Nexus README probably had the same gap. The 29.3 research
  measured it with Helm v4.3.0 and isolated `HELM_*` homes: **both** charts fail the build without `helm repo add`,
  so item 8 is a verified defect (29.3-RESEARCH).
- **ADR-023 may not be edited.** `docs/adr/` is append-only per `CLAUDE.md`. The answer to item 8 is given in this
  record's prose (decision 2).

## Decision

1. **Both gates fail closed (D-01 to D-05, D-16).** The two SKIP guards are now early failures that run before
   preflight, print one stable label line in the `fail()` format and exit 1:
   - `FAIL: CHART-DIR-PRESENT:` in both gates, when `kubernetes/<chart>` does not exist;
   - `FAIL: TLS-GUARD-PRESENT:` in the DefectDojo gate, when `templates/validate-tls.yaml` does not exist;
   - `FAIL: PROVISION-JOB-PRESENT:` in the Nexus gate, when `templates/job-provision.yaml` does not exist.

   The labels are a contract: `chart-gates.yml` matches them literally, so they are renamed together or not at all.
   The vacuous-pass header block is rewritten to describe the fail-closed convention and cites this record. The check
   counts are unchanged (22 for DefectDojo, 18 for Nexus), because the guards are not counted checks and the later
   render checks do not run when a guard fails. The exit-code contract is unchanged: 0 pass, 1 chart defect (now
   including a missing chart or guard template), 2 preflight or infrastructure. The scripts stay mode-agnostic; only
   the workflow interprets the exit code (D-16). Implemented in `security-platform` commit `f6082db` (29.3-01).
2. **The preflight hint works on a fresh clone (D-17, D-24). This answers ADR-023 item 8.** When the subchart is not
   vendored, each gate reads `.dependencies[0].name` and `.dependencies[0].repository` from its `Chart.yaml` with
   `yq -r` (each read guarded, exit 2 on failure) and prints
   `run: helm repo add <name> <url> && helm dependency build <dir>`. No repository URL is written in either gate.
   `kubernetes/nexus/README.md` now runs `helm repo add nexus3 https://stevehipwell.github.io/helm-charts/` before
   `helm dependency build kubernetes/nexus` (commit `5198bc0`). `kubernetes/defectdojo/README.md` is not edited: PR
   #20 already fixed it, and editing it would trigger the 15-30 minute DefectDojo import proof. ADR-023 is untouched;
   its item 8 is closed by this decision.
3. **A dedicated workflow, `.github/workflows/chart-gates.yml` (D-07 to D-10).** It is a new workflow, not a job in
   `defectdojo-import-proof.yml` or `pr-security.yml`. Triggers: `pull_request` and `push` to `main`, both filtered
   to `kubernetes/**`, `scripts/check-*-chart.sh` and `.github/workflows/chart-gates.yml`, plus `workflow_dispatch`.
   It uses `pull_request`, never `pull_request_target`, reads and passes no secrets, sets workflow-level
   `permissions: contents: read`, and checks out with `persist-credentials: false` because the negative cases copy
   the tree including `.git`. It has two named jobs, `chart-gate-defectdojo` and `chart-gate-nexus`, not a matrix,
   so the check names are stable and each job builds only its own chart's dependencies. Neither job id is
   `security`, the frozen prefix of the required `security / <job>` contexts. The check is **not** required: no
   ruleset change and no change to `scripts/set-required-checks.sh` (D-10). Implemented in commit `36100a1` (29.3-02).
4. **Tooling is pinned or asserted (D-19).** Helm v4.3.0 is downloaded, checked against sha256
   `86584a54def73570558f66f5111cc53dfed56689637ae32c1201205d494f54fb`, extracted and version-asserted, never
   `curl | sh`; the gates depend on Helm 4 behaviour. yq and jq come from the runner image and are asserted
   (`*mikefarah*" v4."*` and `jq-1.*`), not downloaded. `actions/checkout` is pinned to
   `3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1`. The research recorded that `ubuntu-24.04` (the current
   `ubuntu-latest`) ships yq 4.53.6, jq 1.7 and Helm 3.22.0, and that `ubuntu-latest` moves to Ubuntu 26.04 between
   2026-10-19 and 2026-11-19 with yq 4.53.6, jq 1.8.1 and Helm 4.3.0. The asserts, not the label, protect the jobs
   across that migration.
5. **Dependencies are built from `Chart.yaml` (D-18).** The `deps` step iterates `.dependencies[]` of the job's own
   `Chart.yaml`, accepts only `https://` repositories, runs `helm repo add <name> <repository>` and then
   `helm dependency build kubernetes/<chart>`. No repository URL is written in the workflow YAML, so the CI step
   exercises the same derivation as the decision 2 hint. A missing `Chart.yaml` skips the build with a `::notice` so
   the gate itself reports the missing chart (RESEARCH Pitfall 1).
6. **`CHART_GATE_MODE` decides how a chart defect is reported (D-11, D-12).** It is a repository variable read only
   by the `gate` step. Unset or empty means `report-only`, the default, which needs no action. The accepted values
   are `blocking` and `report-only`. Any other value turns the job red before the gate runs, with
   `CHART_GATE_MODE=<x> is not blocking|report-only`, so a typo made while enabling blocking cannot leave blocking
   silently off. It is separate from `GATE_MODE`, which drives the five scan jobs in `security.yml`, so each can be
   changed on its own. Blocking is enabled with
   `gh variable set CHART_GATE_MODE --body blocking -R OttawaCloudConsulting/security-platform`. The variable
   concerns this host repository only, because consumers never run `chart-gates.yml`; it is documented in the
   workflow header and here, not in `docs/adoption-guide.md` or `cicd/README.md`.
7. **Buckets and the PASS definition (D-13, D-14).** A PASS is exit 0 **and** a last line that starts with
   `PASS -`; the count is not checked, so the workflow does not duplicate the 22/18 literals.
   - **Chart-defect bucket (follows the mode):** the gate exits 1 (including the three guard labels), or exits 0
     without a terminal `PASS -` line (a vacuous pass). In `report-only` the job emits one `::warning` per FAIL line
     plus a job-summary entry and stays green. In `blocking` it writes the summary, emits `::error` and is red.
   - **Always-red bucket (ignores the mode):** exit 2 (preflight failed, so the gate never ran); any other exit code;
     a failed `helm repo add` or `helm dependency build`, which includes **Chart.lock drift** (Helm v4.3.0 fails with
     `Error: the lock file (Chart.lock) is out of sync with the dependencies file (Chart.yaml)`, RESEARCH Pitfall 5);
     a **non-https dependency repository** in `Chart.yaml`; an invalid `CHART_GATE_MODE`; and any failed negative
     case.

   Raw gate output is printed between a random `::stop-commands::` token pair, so text from the chart cannot issue
   workflow commands.
8. **Standing negative cases prove the gate still discriminates (D-15).** After the positive run, the `negative` step
   (`if: ${{ !cancelled() }}`) copies the checkout into `RUNNER_TEMP` with `cp -a` and runs the **copy's** script:
   (a) with the guard template removed, the gate must exit 1 and print the guard label; (b) with the chart directory
   renamed, it must exit 1 and print `FAIL: CHART-DIR-PRESENT:`. The step compares the workspace `git status`
   before and after and is red if it changed. A failed expectation is red in every mode, so a SKIP reintroduced for
   either condition can never pass.
9. **The D-22 interaction between the negative cases and the mode.** If the PR itself already removed a case's
   precondition (the guard template for (a), the chart directory for (b)), that case cannot run. It then skips with
   a `::notice` **only if** the positive output file, `RUNNER_TEMP/chart-gate-<chart>.out`, already carries the
   matching `FAIL: <label>: ` line, and the mode decides the job colour as decision 7 says. Case (a) also accepts
   `FAIL: CHART-DIR-PRESENT: ` when, and only when, `kubernetes/<chart>` itself is absent, because deleting the chart
   removes the guard template too. A missing positive output file (the gate step stopped at the mode check, or the
   dependency build failed) counts as label absent. If the precondition is absent and the label is absent, the case
   is red in every mode (D-22, 29.3-02).
10. **Release: merged to `security-platform` `main` with no tag and no `v1` move (D-20).** `security.yml`, the caller
    workflows and the chart templates and values did not change, so consumers on `@v1` or `@main` are unaffected.
    The 29.4 release hand-off is unchanged.

### Measured evidence

- **RED before any edit (29.3-01, `evidence/29.3-01-red.txt`):** the four `SKIP:` lines quoted under Context, each
  with `rc=0`, from archive copies of `origin/main` `72cb174539cca5e3a2841f7977a221a90c41326e`.
- **GREEN (29.3-01, `evidence/29.3-01-green.txt`, HEAD `5198bc0`):** in all four cases the first line is the
  expected label, no PREFLIGHT line is printed, and `rc=1`:
  - dd-guard: `FAIL: TLS-GUARD-PRESENT: kubernetes/defectdojo/templates/validate-tls.yaml is missing — the issuer guard is gone`
  - dd-dir: `FAIL: CHART-DIR-PRESENT: kubernetes/defectdojo does not exist — the chart was deleted or renamed`
  - nexus-guard: `FAIL: PROVISION-JOB-PRESENT: kubernetes/nexus/templates/job-provision.yaml is missing — the required rootPassword guard is gone`
  - nexus-dir: `FAIL: CHART-DIR-PRESENT: kubernetes/nexus does not exist — the chart was deleted or renamed`
- **The hint on a fresh copy (29.3-01, `evidence/29.3-01-green.txt`):** with an isolated, empty Helm configuration
  each gate exited `rc=2` and printed `PREFLIGHT FAIL: subchart not vendored` followed by
  `run: helm repo add defectdojo https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts && helm dependency build kubernetes/defectdojo`
  and
  `run: helm repo add nexus3 https://stevehipwell.github.io/helm-charts/ && helm dependency build kubernetes/nexus`.
  Running each printed command with `eval` gave `eval-rc=0`, `Chart.lock` was byte-identical to the committed file,
  and the rerun ended `PASS - 22 checks, 0 failures` and `PASS - 18 checks, 0 failures`, `rc=0`.
- **Offline proof of the committed workflow bodies (29.3-03, `evidence/29.3-03-proof.log`):**
  `PROOF PASS - 95 checks`, 0 FAIL lines, at `fix/phase-29.3-chart-gates`
  `36100a18d214d9d4e73088c290925963dd0ffd45`, unfixed baseline `72cb174`, under bash 5.3.20, Helm v4.3.0, yq
  v4.54.1 and jq 1.8.2. The `tools`, `deps`, `gate` and `negative` bodies are extracted by step id from the
  committed blob and run as the runner runs them (`bash -e`, from the workspace root). By section:
  - **1 EXTRACT, 54 checks:** each body non-empty, free of `${{`, with no `shell:` key, clean under `bash -n` and
    shellcheck, byte-identical across the two jobs; the env contracts; the negative step's `if: ${{ !cancelled() }}`.
  - **2 GATE, 21 checks:** 5 modes (unset, empty, `report-only`, `blocking`, typo `Blocking`) x 4 stub outcomes
    (exit 0 with PASS, exit 0 without PASS, exit 1, exit 2), plus unset x exit 3. The typo rows exit 1 with the
    `is not blocking|report-only` error and never invoke the gate.
  - **3 DEPS, 7 checks (five `DEPS-` and two `REAL-GATE-`):** a missing `Chart.yaml` skips with a `::notice`; an
    `oci://` repository is red before any `helm repo add`; a fresh clone builds `defectdojo-1.9.53.tgz` and
    `nexus3-5.26.0.tgz` with `Chart.lock` identical to the committed blob; the real gates then end
    `PASS - 22 checks, 0 failures` and `PASS - 18 checks, 0 failures`.
  - **4 NEGATIVE, 13 checks:** both negative cases pass against the fixed `36100a1`; against the unfixed `72cb174`
    the step itself is red (`rc 1`) because the SKIP exits 0; the D-22 label paths skip with `::notice`; the
    no-label, no-file, wrong-label and chart-label-with-directory-present paths are red. The workspace status is
    unchanged in every case.
- **Live PR run (29.3-07):** security-platform PR #FILL-AT-29.3-07, Chart Gates run FILL-AT-29.3-07 under the
  default (unset) mode: both jobs and all four negative cases.
- **Merge (29.3-07):** merge commit `FILL-AT-29.3-07`; push-to-`main` Chart Gates run FILL-AT-29.3-07.

## Consequences

**Improved:** deleting or renaming a chart, `validate-tls.yaml` or `job-provision.yaml` can no longer pass a chart
gate. Both gates run on every PR and push that touches a chart, a gate script or the workflow, and every run proves
the gates still discriminate.

**Improved:** a fresh clone gets a preflight hint that works, and the Nexus README install step works on a fresh
Helm configuration.

**Tradeoff — a deleted guard or chart is red only in blocking mode.** In the default `report-only` mode, a PR that
deletes a guard template or a chart gets a `::warning` and a job-summary entry, and the job stays green. It is red in
`blocking` mode. This follows from D-22: the negative cases skip because the positive run already reports the label.
Deletion is therefore not always red.

**Tradeoff — vacuous pass is not fully covered.** A SKIP reintroduced for the guard-template or chart-directory
condition is always red, because negative case (a) or (b) then exits 0. A SKIP (or any exit 0 without a `PASS -`
line) added for **any other** condition fires in the positive run, lands in the chart-defect bucket and is only a
warning in `report-only` mode. The operator accepted this tradeoff (29.3-CONTEXT, specifics).

**Tradeoff — a chart directory without `Chart.yaml` is always red.** If `kubernetes/<chart>` exists but `Chart.yaml`
is gone, the guards pass, the `deps` step skips, and the gate's guarded `yq` read exits 2. That is the always-red
bucket in every mode (RESEARCH Pitfall 1). The chart is then broken in a way that is not a gate decision.

**Tradeoff — the hint can collide with an operator's existing Helm repository.** Re-adding the same name and URL is
a no-op, but an operator whose local `defectdojo` or `nexus3` repository name points at a different URL gets a
`helm repo add` error from the printed hint (RESEARCH Pitfall 5). A fresh runner is not affected.

**Tradeoff — blocking turns the check red but does not block merging.** `chart-gate-defectdojo` and
`chart-gate-nexus` are not required status checks. A path-filtered required check stays pending forever on a PR that
does not touch the paths, so making them required needs an always-reporting job shape and is left to a later phase.

## What was NOT verified

What WAS measured and must not be re-litigated: the RED and GREEN runs and the fresh-copy hint runs (29.3-01), the
offline proof `PROOF PASS - 95 checks` against the committed workflow bodies (29.3-03), and the measurement that both
charts fail `helm dependency build` on a fresh Helm configuration without `helm repo add` (29.3-RESEARCH).

1. **`CHART_GATE_MODE=blocking` and a typo value were not exercised live.** The repository variable was not set
   during this phase. The mode logic is proven only by the offline proof against the extracted bodies (D-21).
2. **`vars` on fork PRs (RESEARCH A1).** Whether `vars.CHART_GATE_MODE` is available to `pull_request` runs from
   forks is not documented and was not tested. If it is empty, the mode falls back to `report-only`, never to
   blocking.
3. **Annotation escaping (RESEARCH A2).** The workflow encodes `%` as `%25` in annotation data. The offline proof
   checks the encoding; that the runner decodes it back was assumed, not observed.
4. **The Ubuntu 26.04 image.** The jobs have run (FILL-AT-29.3-07) only on the current `ubuntu-latest`. Behaviour
   after the 26.04 migration is covered by the version asserts, not by a run.
5. **Lock digest verification.** That `helm dependency build` verifies the downloaded tarball against the
   `Chart.lock` digest is a research assumption. What was measured is that `Chart.lock` stays byte-identical after
   the build and that lock drift fails the build.
6. **Making the check required** is deferred (decision 3 and the last tradeoff).
7. **CI for the other standing gates** (`check-workflow-uploads.sh`, `check-detector-parity.sh`,
   `check-nexus-setup.sh`) is deferred. They are also not in CI.
8. **The other Phase 26 warnings** (WR-01, WR-02, WR-03) are deferred. Only WR-04 was folded in.
