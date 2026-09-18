---
phase: 23-nexus-generic-chart
plan: 01
subsystem: infra
tags: [helm, nexus, yamllint, pre-commit, gitignore, shellcheck, offline-gate, yq, jq]

# Dependency graph
requires:
  - phase: 14-ci-pipeline-bootstrap
    provides: "repos/security-platform .pre-commit-config.yaml with the yamllint -d relaxed convention and the `exclude:` house style"
  - phase: 17-sarif-upload-and-artifact-retention
    provides: "scripts/check-workflow-uploads.sh — the standing-gate CONTRACT (header, three-way exit codes, never-chmod note, repo-root anchoring, failure accumulator, labelled checks, counted terminal summary) and the vacuous-pass intermediate-commit convention"
provides:
  - "feature/phase-23-nexus-generic-chart branch on repos/security-platform (all of 23-01..23-06 commit here; 23-08 pushes and merges)"
  - "yamllint exclusion ^kubernetes/.*/templates/ — Helm Go templates can now be committed at all"
  - "gitignore entry kubernetes/*/charts/*.tgz — helm dependency build output never enters git"
  - "scripts/check-nexus-chart.sh — the single command that decides PASS/FAIL for all 16 offline chart invariants"
affects: [23-02, 23-03, 23-04, 23-05, 23-06, 23-07, 23-08, phase-24-nexus-hardening, phase-25-argocd]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Standing offline gate for a Helm chart: bash + helm/yq/jq, contract copied from check-workflow-uploads.sh, mechanism deliberately not (no python heredoc)"
    - "Single render() wrapper so a `required` guard does not spuriously fail every positive assertion"
    - "Vacuous-pass guards printed as SKIP, never silent"

key-files:
  created:
    - repos/security-platform/scripts/check-nexus-chart.sh
  modified:
    - repos/security-platform/.pre-commit-config.yaml
    - repos/security-platform/.gitignore

key-decisions:
  - "The `PASS - 16 checks, 0 failures` literal appears in the file only inside the header comment; the terminal echo interpolates CHECK_COUNT=16, exactly as the check-workflow-uploads.sh analog does. Runtime output was measured byte-identical to the literal, so 23-06 T1's assertion is on the output, not on a grep of the source."
  - "requirements.mark-complete was deliberately NOT invoked. NEXUS-01 and NEXUS-03 are in this plan's frontmatter, but the chart that satisfies them ships in 23-03/23-04 — this plan builds only the gate that will assert them. Follows the 17-01 and 19-01..19-04 precedent already recorded in STATE.md."
  - "`helm lint` is called directly (not through render()) but with the identical --set, because lint takes a chart path rather than a template invocation; the plan's requirement was parity of the --set, not parity of the call."
  - "EULA-ENV searches both containers[] and initContainers[] for EULA_ACCEPTED rather than only containers[], so 23-04 is free to place the EULA call in either without the gate reporting a phantom defect."

patterns-established:
  - "Prove-the-guard-fires before committing an untestable gate: a throwaway chart built in the scratchpad (never inside the repo) exercised all 16 assertion bodies, both SKIP guards, all four exit-2 branches, a full green path, and eight single-defect mutations — the 17-02 technique applied to a script whose subject does not exist yet"
  - "Negative control on a pre-commit exclusion: the same Go-template probe placed at an excluded AND a non-excluded path, because the positive test alone cannot distinguish `exclusion works` from `pre-commit skipped the file`"

requirements-completed: []

# Metrics
duration: 25min
completed: 2026-09-18
---

# Phase 23 Plan 01: Offline Feedback Loop and Repo-Gate Unblock Summary

**Helm Go templates can now be committed to `security-platform` at all, and a 305-line standing gate exists that decides PASS/FAIL for all 16 offline Nexus-chart invariants — proven green, proven red, and proven discriminating against a throwaway chart before the real one exists.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-18T11:47:00Z (approx.)
- **Completed:** 2026-09-18T12:11:27Z
- **Tasks:** 2 of 2
- **Files modified:** 3 (1 created, 2 modified) — all in `repos/security-platform`

## Accomplishments

- **Removed the hard blocker on the whole phase.** `yamllint -d relaxed` was measured exiting 1 on a Helm Go template; until this commit no chart template could be committed to the repo at all. The anchored exclusion `^kubernetes/.*/templates/` leaves `Chart.yaml` and `values.yaml` linted (both measured exit 0).
- **Built the phase's single feedback command.** `bash scripts/check-nexus-chart.sh` implements all 16 labelled invariants from `23-VALIDATION.md` rows 2 and 4–18, accumulates every failure, and separates chart defects (exit 1) from machine problems (exit 2).
- **Proved the gate works before the chart exists.** Every execution path was driven against a scratchpad fake chart (see Verification Evidence). This is what makes must-have #4 ("never reports a missing tool as a chart defect") a measurement rather than a claim.

## Task Commits

1. **Task 1: Branch the sibling repo and unblock the two repo gates** — `7854cb0` (chore)
2. **Task 2: Write the standing offline chart gate** — `16c2ea1` (feat)

Branch: `feature/phase-23-nexus-generic-chart` on `repos/security-platform`, **unpushed** (23-08 owns push/PR/merge). Working tree clean.

## Files Created/Modified

- `repos/security-platform/scripts/check-nexus-chart.sh` (new, 305 lines, mode 100644 — not executable) — the standing offline gate.
- `repos/security-platform/.pre-commit-config.yaml` — `exclude: ^kubernetes/.*/templates/` on the `yamllint` hook, with a multi-line `# ADD — Measured:` comment in the hadolint house style naming yamllint's exact exit-1 message and stating that `Chart.yaml`/`values.yaml` stay linted. Per the plan, the comment does **not** claim `Chart.lock` stays linted (`.lock` is not tagged `yaml` by `identify`, so `types: [yaml]` never selects it either way).
- `repos/security-platform/.gitignore` — new `# Helm` section with exactly `kubernetes/*/charts/*.tgz`; no broader `charts/` or `*.tgz` pattern.

## Verification Evidence

### Task 1 — measured, with a negative control

The plan's verify only tests the excluded path, which cannot distinguish "the exclusion works" from "pre-commit ignored an untracked file". A negative control was added:

| Probe | Path | Result |
|---|---|---|
| `{{- if .Values.x }}` Go template | `kubernetes/probe/probe.yaml` (**not** excluded) | **exit 1** — `1:3 error syntax error: expected the node content, but found '-' (syntax)` |
| identical Go template | `kubernetes/probe/templates/probe.yaml` (excluded) | **exit 0** — `yamllint ... (no files to check) Skipped` |
| clean `values.yaml` | `kubernetes/probe/values.yaml` | **exit 0** — still linted |

The exit-1 message is the one quoted verbatim in the config comment; it was measured here, not recalled. Probe tree removed with `rm -rf kubernetes`; `git status --short` empty afterward. `pre-commit run --all-files` exits 0 on the branch. The `exclude` key parses to exactly the string `^kubernetes/.*/templates/` (PyYAML read-back), so the trailing comment does not leak into the pattern.

### Task 2 — every execution path driven against a scratchpad fake chart

The gate's assertion bodies never execute at this commit (it prints `SKIP` and exits 0), so committing it unexercised would have shipped an unverified 305-line script. A throwaway chart was built **in the scratchpad, never inside the repo** — the script anchors to `dirname $0/..`, so placing a copy at `<scratch>/scripts/` made `<scratch>` the repo root and left `security-platform` untouched.

| Path driven | Observed |
|---|---|
| Real repo, no chart | `SKIP: chart not present yet …`, **exit 0** |
| Chart present, `templates/job-provision.yaml` absent | `SKIP: chart incomplete …`, **exit 0** |
| `helm` off PATH | `PREFLIGHT FAIL: required binary 'helm' …`, **exit 2** |
| `yq` off PATH | `PREFLIGHT FAIL: required binary 'yq' …`, **exit 2** |
| `jq` off PATH | `PREFLIGHT FAIL: required binary 'jq' …`, **exit 2** |
| No `charts/*.tgz` | `PREFLIGHT FAIL: subchart not vendored …` + `run: helm dependency build kubernetes/nexus`, **exit 2** |
| Skeleton (everything wrong) chart | **exit 1**, `FAILED - 16 check(s)` — all 16 checks ran and accumulated; **no bash abort at check 1** |
| Conforming chart | **`PASS - 16 checks, 0 failures`**, **exit 0** |

Eight single-defect mutations against the conforming chart, each producing **exactly one** red check and no spurious others:

| Mutation | Check that fired |
|---|---|
| `required` guard removed from the Secret name | `NO-DEFAULT-PASSWORD` |
| `eula.accepted: true` | `EULA-OPT-IN` |
| `nexus3.config.enabled: true` (Groovy scripting API) | `CONFIG-DISABLED` |
| helper image pinned by tag not digest | `HELPER-DIGESTS` |
| default `storageClass` baked in | `STORAGECLASS-OMITTED` |
| `argocd.argoproj.io/hook` annotation dropped | `JOB-HOOK` |
| default `repos.helm.remoteUrl` baked in | `REPO-BODIES` |
| `dockerProxy` removed from the docker body | `DOCKER-BODY` |

Also: `shellcheck scripts/check-nexus-chart.sh` exit 0; `test ! -x` succeeds (git mode `100644`); `pre-commit run --all-files` exit 0; all 16 labels present; `grep -c 'fail '` = 38 (≥ 16 required); `exit 2` appears twice; zero matches for `dummy-not-a-real-password|admin123` outside comments (the string is nowhere in the file at all).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] My own jq-preflight test was wrong, not the script**

- **Found during:** Task 2 verification
- **Issue:** Stripping `jq` by setting `PATH="$SP/bin:/usr/bin:/bin"` did not produce exit 2. The gate ran all 16 checks and exited 1.
- **Root cause:** This macOS ships `/usr/bin/jq` (1.5 MB, root:wheel, dated 2026-08-01), so `jq` was never actually absent. The observed exit 1 was the correct verdict for a fake chart with no ConfigMap.
- **Fix:** Re-ran with `PATH="$SP/bin"` containing only the binaries under test (plus `dirname`/`tr`/`grep`/`bash`, which the script and harness invoke). Both the `yq`-absent and `jq`-absent branches then fired with exit 2 naming the right binary.
- **Files modified:** none — no script change was warranted. The reported anomaly was a defect in the test, and it was investigated rather than worked around.

### Divergences from the plan text (deliberate, with reasons)

**1. `PASS - 16 checks, 0 failures` is a literal only in the header comment.**
The plan's acceptance criteria ask for both `CHECK_COUNT=16` and the literal string in the file. The analog `check-workflow-uploads.sh` sets `CHECK_COUNT = 10` and formats the line, so the literal never appears there either. This gate does the same: `CHECK_COUNT=16` at line 294, `echo "PASS - ${CHECK_COUNT} checks, 0 failures"` at the terminal, and the literal quoted at line 38 where the header explains 23-06 T1's anti-vacuity assertion. **The runtime output was measured** and is byte-identical to the required literal (see the conforming-chart row above). 23-06 T1 should assert the gate's stdout, not grep the source.

**2. `requirements.mark-complete` deliberately not invoked; `requirements-completed: []`.**
The plan frontmatter carries `[NEXUS-01, NEXUS-03]`, but neither is satisfied by this plan: NEXUS-01 (proxy repositories configured) ships in 23-04 and NEXUS-03 (storage configuration) in 23-03. Marking them here would repeat the 17-01 mistake that had to be reverted (recorded in STATE.md), and the 19-01 through 19-04 plans each withheld the mark for the same reason. An executor or verifier reading `[]` here should read it as **withheld on purpose**, not as a missed step.

**3. `PATTERNS.md`'s `render()` literal was not copied.** It uses `dummy-not-a-real-password`, superseded by the plan's `<interfaces>` block (`dummy-secret-name`) and forbidden by this plan's own acceptance grep. The superseded string was never written anywhere.

## Observations Handed Forward

1. **Helm here is v4.3.0, not v3.** Every measurement above was taken under `helm v4.3.0+gbec5b06` with `yq v4.53.6`. `helm template <release> <dir>`, `helm lint --set`, `required`, subchart tarball loading and the `Chart.yaml` dependency declaration all behaved as the plan assumes. Plans 23-03/23-04 inherit this; CI may run a different major version and that is untested.
2. **`helm lint` fails hard on an undeclared subchart in `charts/`** — `chart metadata is missing these dependencies: dummy`. Plan 23-03's `Chart.yaml` must declare the `nexus3` dependency, not merely vendor the tarball, or `CHART-LINT` goes red.
3. **The M7 mutation fired `REPO-BODIES`, not `HELM-REPO-OPT-IN`.** Baking a default `repos.helm.remoteUrl` is caught because the *default* render then emits four bodies; `HELM-REPO-OPT-IN` still passes because the `--set` case legitimately yields four. Both checks are needed, but `REPO-BODIES` is the one that actually guards D-05's no-default decision. Recorded because the prediction was "both fire" and only one did.
4. **yq writes one stderr line (`Error: cannot get keys of !!null …`) on the skeleton-chart run** before the accumulated `FAIL:` block. It is yq's own diagnostic on a `.metadata.annotations` that does not exist; the `JOB-HOOK` failure is still reported correctly. Not suppressed — a silenced stderr is the kind of fallback this gate's header forbids.
5. **`check-nexus-chart.sh` is not wired into `.pre-commit-config.yaml` or CI.** It is invoked by hand, like `check-workflow-uploads.sh`. Any future CI wiring must run `helm dependency build kubernetes/nexus` first (it needs network; the gate itself does not) or every CI run exits 2.

## Threat Model Coverage

| Threat ID | Disposition | How this plan mitigates it | Status |
|---|---|---|---|
| T-23-02 | mitigate | `render()` passes a Secret **name** (`dummy-secret-name`), never a credential; `NO-DEFAULT-PASSWORD` is the dedicated negative assertion and was observed firing when the `required` guard was removed | ✅ implemented + measured |
| T-23-07 | mitigate | Exclusion anchored `^kubernetes/.*/templates/`; `values.yaml` measured still linted; no `charts/` or `*.tgz` broad pattern in `.gitignore` | ✅ implemented + measured |
| T-23-08 | mitigate | Exactly two vacuous-pass guards, both printing `SKIP`; both observed. 23-06 T1 remains the anti-vacuity gate | ✅ implemented |
| T-23-SC | mitigate | No package-manager install occurred in this plan | ✅ n/a by construction |

## Known Stubs

None. `check-nexus-chart.sh` is complete for its 16 invariants; its `SKIP` guards are the documented vacuous-pass convention, not placeholders, and 23-06 T1 is the assertion that closes them.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern or trust-boundary schema was introduced. The one config change that widens a security surface (the yamllint exclusion) is T-23-07, already in the register and anchored as narrowly as the invariant allows.

## Self-Check: PASSED

- `repos/security-platform/scripts/check-nexus-chart.sh` — FOUND (305 lines, mode 100644)
- `repos/security-platform/.pre-commit-config.yaml` — FOUND, contains `exclude: ^kubernetes/.*/templates/`
- `repos/security-platform/.gitignore` — FOUND, contains `kubernetes/*/charts/*.tgz`
- Commit `7854cb0` — FOUND on `feature/phase-23-nexus-generic-chart`
- Commit `16c2ea1` — FOUND on `feature/phase-23-nexus-generic-chart`
- Branch `feature/phase-23-nexus-generic-chart` — current, working tree clean, unpushed
