---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 03
subsystem: testing
tags: [bash, shellcheck, nexus, npm, pip, helm, docker, offline-gate, mutation-testing]

# Dependency graph
requires:
  - phase: 23-nexus-generic-chart
    provides: "scripts/check-nexus-chart.sh (gate-before-subject precedent) and scripts/nexus-live-smoke.sh (three-state runtime verdict, SKIPPED-is-not-a-pass accounting)"
  - phase: 16-sca-ecosystem-subscans
    provides: "scripts/smoke-scans.sh soft-preflight tier — one absent tool is exactly one skipped sub-check"
provides:
  - "scripts/check-nexus-setup.sh — twelve-check offline gate for workstation/nexus-setup.sh, green-by-skip until plan 24-06 lands"
  - "A binding name contract for plans 24-06 and 24-07: six source-level and six behavioural check names"
  - "A binding ORDERING contract on the subject: .npmrc and pip.conf must be written BEFORE `helm repo add`"
  - "The NEXUS_SETUP_GATE_SUBJECT test hook, so 24-06/24-07 can iterate against the gate without committing"
  - "Homes for 24-VALIDATION.md rows 24-W0-13, 24-W0-14 and the -x half of 24-W0-15"
affects: [24-06, 24-07, 24-04, 24-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Check-name registry: every check name is a literal exactly once, at the top, referenced by variable thereafter"
    - "Loopback python3 -m http.server stub to make a non-offline `helm repo add` usable inside an offline gate"
    - "Windowed source assertions anchored on the directive they govern, rather than whole-file greps"

key-files:
  created:
    - repos/security-platform/scripts/check-nexus-setup.sh
  modified: []

key-decisions:
  - "VERIFY-FAILS-LOUDLY runs against the loopback stub, not a closed port — a closed port kills the subject at `helm repo add` and the non-zero exit proves nothing about --verify"
  - "The two ADR-009 wording assertions are WINDOWED on the `insecure-registries` mention; whole-file scope was measured to be satisfiable by the pip writer's own removal sentence"
  - "No compile-time check count — the number is counted at runtime, because 24-06 and 24-07 both add behaviour to the subject"
  - "Every check name is a literal exactly once, so `grep -c '<NAME>'` is a reliable is-it-implemented test"
  - "NEXUS-04 deliberately NOT marked complete — plan 24-10 marks it"

patterns-established:
  - "Gate-before-subject with a documented SUBJECT override, because a gate whose SKIP guard is active exercises zero assertion bodies and could ship broken"
  - "Single-defect mutation testing as the acceptance evidence for a gate that cannot yet run against its real subject"

# Metrics
duration: 70min
completed: 2026-09-19
requirements-completed: []
---

# Phase 24 Plan 03: Offline Gate for the Workstation Nexus Routing Script Summary

**A twelve-check offline gate for `workstation/nexus-setup.sh` written before the script exists — six source-level hazard checks plus six behavioural checks that run the subject inside throwaway `git init` repos under `mktemp -d`, with a three-state runtime verdict in which a skip is never a pass.**

## Performance

- **Duration:** ~70 min
- **Started:** 2026-09-19T21:33Z (approx.)
- **Completed:** 2026-09-19T22:43Z (approx.)
- **Tasks:** 3
- **Files modified:** 1 (created)

## Accomplishments

- `scripts/check-nexus-setup.sh` (735 lines) exists in `repos/security-platform` on `feature/phase-24-nexus-anonymous-and-workstation`, commit `f008707`, mode `100644`.
- All twelve assertion bodies were **observed executing and passing** against a throwaway conforming subject: `ALL PASS - 12 check(s) executed and passed; 0 sub-check(s) skipped (not passed)`.
- **Nine** single-defect mutations each produced **exactly one** predicted red check — prediction matched observation in every case.
- The `DOCKER-DAEMON-WARNING` SKIP path was separately observed: `ALL PASS - 11 check(s) executed and passed; 1 sub-check(s) skipped (not passed)`.
- Both preflight tiers were observed firing: `shellcheck` off PATH → exit 2 with an infrastructure message; `npm`/`helm`/`python3` off PATH → 6 passed, 6 skipped, exit 0, each skip naming its missing tool.
- In this repository, with the subject absent: `NOTHING RAN - 0 check(s) executed; 1 sub-check(s) skipped (not passed). Nothing was proven.` exit 0.

## Task Commits

The plan directs a **single commit at Task 3** ("Commit one file"), and its own acceptance criterion requires `git diff-tree` on that commit to list exactly `scripts/check-nexus-setup.sh`. Tasks 1 and 2 both build the same file, so per-task commits would have violated the plan's own gate. This follows the Phase 15-03 precedent already recorded in STATE.md ("Task 1 has no separate commit by plan design").

1. **Tasks 1-3 (scaffold, guards, preflight, six source checks, six behavioural checks, mutation exercise)** — `f008707` (test)

**Plan metadata:** see the `docs(24-03)` commit in the parent repository.

## The Check List

Twelve checks. Every name is a literal exactly once in the source (the check-name registry at the top), so `grep -c '<NAME>' scripts/check-nexus-setup.sh` is `1` for each.

### Source-level (Task 1) — read the subject, never run it

| # | Check | Asserts | Encodes |
|---|-------|---------|---------|
| 1 | `SETUP-NOT-EXECUTABLE` | `test ! -x` on the subject | Project Script Safety rule; 24-W0-15 (the `-x` half). Failure message names `workstation/setup.sh` at 755 as the analog violating it, deliberately not copied |
| 2 | `SETUP-SHELLCHECK` | `shellcheck <subject>` exits 0 | 24-W0-15 |
| 3 | `NPMRC-NO-REDIRECT` | no `>`/`>>` redirect targets `.npmrc` in the comment-stripped source | Pitfall 7 — a clobbered `_authToken` is credential loss with no error message |
| 4 | `HELM-NOT-HANDWRITTEN` | `helm repo add` present **and** no heredoc/redirect writes `repositories.yaml` | Helm's internal format carries a `generated` timestamp and has changed across major versions |
| 5 | `VERIFY-NO-SILENT-TRUE` | no `\|\| true` on a line that also performs a verification fetch (`curl`, `npm view`, `pip download`, `helm repo update`, `helm search`) | Pitfall 10 + the project Error Handling rule |
| 6 | `DOCKER-DAEMON-WARNING` | **conditional.** No `daemon.json` write → SKIPPED (24-04's A3 verdict may forbid it). A write → `insecure-registries` named, machine-global scope stated, removal-once-TLS stated, all within 14 lines of the directive | ADR-009 (`docs/adr/adr009-tls-guidance.md`) |

### Behavioural (Task 2) — run the subject in throwaway repos under `mktemp -d`

Every fixture is `git init`-ed (so `git rev-parse --show-toplevel` resolves) and carries a `package.json` (so npm's local prefix resolves there — 24-RESEARCH Pattern 4; without it npm silently falls back to `registry.npmjs.org` and the whole section would measure nothing). The EXIT trap removes the scratch dir and stops the stub.

| # | Check | Asserts | Validation row |
|---|-------|---------|----------------|
| 7 | `NPMRC-MERGE` | seeded `_authToken` line survives byte-identically, `save-exact=true` survives, and **npm itself** (`npm config list --json \| jq -r .registry`) resolves to `https://nexus.example.com/repository/npm-proxy/` | 24-W0-14 |
| 8 | `DOCKER-PREFIX-SHAPE` | the emitted `.nexus-env` `NEXUS_DOCKER_REGISTRY=` line **only** — contains the host, contains `docker-proxy`, contains **no** `/repository/` | 24-W0-13 |
| 9 | `PIP-TRUSTED-HOST-CONDITIONAL` | three runs: `https://` → no `trusted-host`; `http://` non-loopback → `trusted-host` **plus** the ADR-009 removal sentence; `http://127.0.0.1:<port>` → no `trusted-host` | pip `SECURE_ORIGINS` |
| 10 | `NEXUS-ENV-EXPORTS` | exactly `PIP_CONFIG_FILE`, `HELM_REPOSITORY_CONFIG`, `HELM_REPOSITORY_CACHE`, `NEXUS_DOCKER_REGISTRY`; header states sourcing-not-executing and the Pitfall 8 user-scope replacement | Pattern 5 / Pitfall 8 |
| 11 | `GLOBAL-CONFIG-UNTOUCHED` | sha256 of the operator's Helm repo config, npm userconfig and `~/.docker/daemon.json` unchanged before/after every fixture run | T-24-13 |
| 12 | `VERIFY-FAILS-LOUDLY` | `--verify` against the stub exits non-zero and names the failing ecosystem | Pitfall 10 |

## Mutation Prediction/Observation Table

Driver: `<scratchpad>/mutate.py`. Each mutation is applied to a fresh copy of the conforming subject, the gate is pointed at it via `NEXUS_SETUP_GATE_SUBJECT`, and the `FAIL` check names are collected. **Nine for nine.**

| # | Mutation | Predicted red | Observed red | Other checks |
|---|----------|---------------|--------------|--------------|
| 1 | `chmod +x` the subject | `SETUP-NOT-EXECUTABLE` | `SETUP-NOT-EXECUTABLE` | 11 passed, 0 skipped |
| 2 | `printf '' >> "$REPO_ROOT/.npmrc"` appended (content-preserving, so only the mechanism is the defect) | `NPMRC-NO-REDIRECT` | `NPMRC-NO-REDIRECT` | 11 passed, 0 skipped |
| 3 | `helm repo add` replaced by a `repositories.yaml` heredoc | `HELM-NOT-HANDWRITTEN` | `HELM-NOT-HANDWRITTEN` | 11 passed, 0 skipped |
| 4 | `\|\| true` on the npm verification fetch (pip fetch left intact) | `VERIFY-NO-SILENT-TRUE` | `VERIFY-NO-SILENT-TRUE` | 11 passed, 0 skipped |
| 5 | `/repository/` inserted into `NEXUS_DOCKER_REGISTRY` | `DOCKER-PREFIX-SHAPE` | `DOCKER-PREFIX-SHAPE` | 11 passed, 0 skipped |
| 6 | `trusted-host` branched on `https` instead of `http` | `PIP-TRUSTED-HOST-CONDITIONAL` | `PIP-TRUSTED-HOST-CONDITIONAL` | 11 passed, 0 skipped |
| 7 | `--verify` verdict changed from `exit 1` to `exit 0` | `VERIFY-FAILS-LOUDLY` | `VERIFY-FAILS-LOUDLY` | 11 passed, 0 skipped |
| 8 | `_authToken` line stripped after the `.npmrc` write (via `sed -i`, no redirect) | `NPMRC-MERGE` | `NPMRC-MERGE` | 11 passed, 0 skipped |
| 9 | ADR-009 removal sentence deleted from the `daemon.json` warning | `DOCKER-DAEMON-WARNING` | `DOCKER-DAEMON-WARNING` | 11 passed, 0 skipped |
| 10 (probe, not a defect) | `daemon.json` write removed entirely | `DOCKER-DAEMON-WARNING` **SKIPPED** | `DOCKER-DAEMON-WARNING` SKIPPED | 11 passed, 1 skipped, exit 0 |

Mutations 2, 4 and 8 were deliberately designed to be **decoupled** from their neighbours: mutation 2 appends nothing so `NPMRC-MERGE` stays green; mutation 4 leaves the pip fetch failing so `VERIFY-FAILS-LOUDLY` stays green; mutation 8 uses `sed -i` rather than a redirect so `NPMRC-NO-REDIRECT` stays green. Without that care each would have produced two reds and proved less.

## Observed Terminal Output

**SKIP path, in this repository, subject absent (the committed state):**

```
==> check-nexus-setup: SKIPPED - workstation/nexus-setup.sh does not exist yet — the workstation
    routing script is created in plan 24-06; no assertion could run

=== Summary ===
SKIPPED - 1 sub-check(s) did not run. A SKIP IS NOT A PASS:
  - check-nexus-setup: workstation/nexus-setup.sh does not exist yet …

NOTHING RAN - 0 check(s) executed; 1 sub-check(s) skipped (not passed). Nothing was proven.
```
exit 0. `ALL PASS` is **not** printed.

**Conforming scratchpad subject:** `ALL PASS - 12 check(s) executed and passed; 0 sub-check(s) skipped (not passed).` exit 0.

**Hard preflight, `shellcheck` off PATH:** `PREFLIGHT FAIL: required binary 'shellcheck' is not on PATH — this is a machine problem, not a defect in …` exit **2**.

**Soft preflight, `npm`/`helm`/`python3` off PATH:** three `NOTE:` lines, then 6 passed and 6 skipped, exit 0. Each skip names the missing tool; none is counted as a pass.

## The `SUBJECT` Override — for plans 24-06 and 24-07

```bash
NEXUS_SETUP_GATE_SUBJECT=/abs/path/to/nexus-setup.sh bash scripts/check-nexus-setup.sh
```

One environment variable, absolute path, documented in the gate's header. It exists because the SKIP guard means the gate exercises **zero** assertion bodies in this repository until 24-06 lands — so without it the gate could ship broken and nobody would know. 24-06 and 24-07 can iterate against the real contract without committing. **It is a test hook, not a configuration knob:** CI and pre-commit must invoke the script with it unset.

## Contracts Imposed on Plan 24-06 (read before writing the script)

1. **Ordering is binding:** the subject must write `.npmrc` and `pip.conf` **before** it invokes `helm repo add`. `helm repo add` is not an offline operation — Helm 3 and 4 fetch `index.yaml` during `repo add` and error on an unreachable repository, with no `--no-update` escape. Two fixture runs point at hostnames that do not resolve and are **expected** to end non-zero at the Helm writer; they assert on the files written before that point.
2. **Exit codes:** runs against an unreachable Helm repository ending non-zero is the behaviour this gate assumes 24-06 implements deliberately. `--verify` must exit non-zero when an ecosystem is unreachable and must name which one.
3. **Docker asymmetry:** `NEXUS_DOCKER_REGISTRY` is `<HOST[:PORT]>/docker-proxy`, with **no** `/repository/` segment. npm, pip and Helm all keep it. The gate asserts this on the `.nexus-env` line only, so a `daemon.json` mirror URL containing `/repository/` (should 24-04's A3 verdict be positive) will not fight correct code.
4. **`.nexus-env`** must export exactly the four contracted names and its header must state both the sourcing requirement and the Pitfall 8 consequence (with `PIP_CONFIG_FILE` set, pip reads **neither** user-scope `pip.conf`).

## Decisions Made

1. **`VERIFY-FAILS-LOUDLY` runs against the loopback stub, not a closed port.** The plan specified "a closed high port on loopback". Against a closed port the subject dies at `helm repo add` before `--verify` is ever reached, so a non-zero exit and a message naming Helm would have proved nothing about the verify pass — the plan's own "helm repo add is not offline" warning, applied to itself. The stub serves `repository/helm-proxy/index.yaml` and nothing else, so the write phase completes and the npm and pip fetches 404: a genuine verify-phase failure. Recorded as a deviation below.
2. **The ADR-009 wording assertions are windowed, not whole-file.** Measured during the mutation run: the pip writer emits its own ADR-009 removal sentence for `trusted-host`, which satisfies a whole-file grep. With whole-file scope the entire Docker warning could be deleted without turning the check red. The two wording sub-conditions are now asserted within 14 lines of an `insecure-registries` mention, and a comment in the gate records why.
3. **No compile-time count constant.** Per the plan's contract. `grep -c 'CHECK_COUNT' scripts/check-nexus-setup.sh` is `0`, including in prose. Counts are runtime, so 24-06 and 24-07 adding behaviour does not create a merge point.
4. **Check-name registry.** Every check name is a literal exactly once, at the top, referenced by variable everywhere else — so the plan's "appears exactly once" criterion holds strictly, and a check whose skip entry and whose assertion spell its name differently cannot exist.
5. **`jq` is hard-tier because it is load-bearing.** `NPMRC-MERGE` reads `npm config list --json | jq -r .registry` rather than grepping `.npmrc`: writing a file is not the same as a client reading it (Pitfall 10), and only npm can say what npm reads.
6. **`python3` added to the soft preflight tier.** Not in the plan's tier list, but the loopback stub requires it; absent, the four stub-dependent checks record SKIPPED naming it.
7. **NEXUS-04 not marked complete** (`requirements-completed: []`). Plan 24-10 marks it. Follows the 17-01 reverted-mark precedent and the 23-01/23-03/23-05/23-06/23-07 and 24-01 withholding pattern — withheld on purpose, not a missed step.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `VERIFY-FAILS-LOUDLY` would have passed for the wrong reason**
- **Found during:** Task 2 (design), confirmed by the plan's own Helm warning
- **Issue:** The plan specifies running `--verify` "against a URL that is not listening (a closed high port on loopback)". The subject reaches `helm repo add` before `--verify`, and `helm repo add` errors on an unreachable repository. The run would have exited non-zero at the Helm writer, never reaching the verify pass — a green check proving nothing.
- **Fix:** The `--verify` run targets the loopback stub, which serves only `repository/helm-proxy/index.yaml`. `helm repo add` succeeds, the write phase completes, and the npm and pip fetches 404. The assertion is exit non-zero **and** the output names `npm` or `pip`. Rationale recorded in a comment in the gate.
- **Files modified:** `repos/security-platform/scripts/check-nexus-setup.sh`
- **Verification:** Conforming subject → `VERIFY-FAILS-LOUDLY: PASS - --verify exited 1 …`; mutation 7 (`exit 1` → `exit 0`) → exactly one red, `VERIFY-FAILS-LOUDLY`.
- **Committed in:** `f008707`

**2. [Rule 1 - Bug] `[^\n]` is not a newline class in POSIX ERE**
- **Found during:** Task 3 (first run against the conforming subject)
- **Issue:** The ADR-009 removal-sentence regex was written `remov[a-z]*[^\n]*TLS`. In a POSIX bracket expression `[^\n]` means "not backslash and not the letter n", so any sentence containing an `n` failed to match. Two checks (`DOCKER-DAEMON-WARNING`, `PIP-TRUSTED-HOST-CONDITIONAL`) went red against a subject that was correct.
- **Fix:** `remov[a-z]*.*TLS` — grep is line-based, so `.*` is both correct and sufficient.
- **Files modified:** `repos/security-platform/scripts/check-nexus-setup.sh`
- **Verification:** Both checks green against the conforming subject; mutations 6 and 9 still produce exactly one red each, so the fix did not disarm them.
- **Committed in:** `f008707`

**3. [Rule 2 - Missing Critical] Whole-file ADR-009 scope made `DOCKER-DAEMON-WARNING` unable to fail**
- **Found during:** Task 3 (mutation design)
- **Issue:** The plan says the ADR-009 strings must be present "within the same source". Measured: the pip writer emits its own removal-once-TLS sentence for `trusted-host`, so a whole-file grep is satisfied by a sentence about a *different* directive. The entire Docker warning could be deleted with the check staying green — a false-pass mechanism in a check whose whole purpose is to prevent one.
- **Fix:** Both wording sub-conditions are now asserted within a ±14-line window anchored on an `insecure-registries` mention; a missing `insecure-registries` is a separate, earlier failure branch. The reason is recorded in a comment so nobody "simplifies" it back.
- **Files modified:** `repos/security-platform/scripts/check-nexus-setup.sh`
- **Verification:** Mutation 9 (removal sentence deleted from the Docker block only, pip's copy left in place) produces exactly one red, `DOCKER-DAEMON-WARNING`. Before the fix it produced zero.
- **Committed in:** `f008707`

**4. [Rule 3 - Blocking] `shellcheck` SC1073 on a prose comment, and SC2012/SC2030/SC2031**
- **Found during:** Tasks 1 and 2
- **Issue:** A comment line beginning `# shellcheck drives an assertion…` is parsed by shellcheck as a malformed directive to itself (SC1073/SC1072). Separately: `ls -l | cut` for the file mode (SC2012), and the deliberately subshell-local `export npm_config_cache` (SC2030/SC2031).
- **Fix:** Comment reworded (with the reason stated in the comment itself); mode read via BSD `stat -f '%Sp'` with a GNU `stat -c '%A'` fallback; a scoped `# shellcheck disable=SC2030,SC2031` with a comment explaining that subshell-locality is the property being relied on, not an accident.
- **Files modified:** `repos/security-platform/scripts/check-nexus-setup.sh`
- **Verification:** `shellcheck scripts/check-nexus-setup.sh` exits 0; `pre-commit run --files scripts/check-nexus-setup.sh` exits 0 (shellcheck hook Passed).
- **Committed in:** `f008707`

**5. [Plan-directed] One commit for three tasks**
- **Issue:** The executor protocol commits each task atomically, but all three tasks build the same single file and the plan's Task 3 acceptance criterion requires `git diff-tree` on the commit to list exactly `scripts/check-nexus-setup.sh`.
- **Fix:** Followed the plan. Single `test(24-03)` commit, matching the Phase 15-03 precedent recorded in STATE.md.

---

**Total deviations:** 5 (2 bugs, 1 missing-critical, 1 blocking, 1 plan-directed)
**Impact on plan:** No scope creep. Deviations 1 and 3 are the difference between a gate that measures something and a gate that cannot fail; deviation 2 was a defect in this plan's own code caught by its own exercise step.

## Issues Encountered

- **Two defects in the test harness, not the gate, both caught by reading the numbers rather than the verdict.** (a) The SKIP-path probe initially reported a mismatch: removing the `daemon.json` block left `DO_DOCKER_DAEMON` assigned-but-unused, so `shellcheck` fired SC2034 and `SETUP-SHELLCHECK` went red — the gate was correct, the mutation was malformed. Spotted because 10 passes + 1 skip is only 11 of 12. (b) A restricted-PATH test silently did not restrict anything, because `local IFS=:` in the harness made `" $* "` join the exclusion list with colons so the pattern never matched. Both corrected and re-measured.
- **`helm repo add` against a `python3 -m http.server` stub was confirmed in the scratchpad BEFORE the gate was built**, as the plan required: `helm repo add nexus-helm http://127.0.0.1:<port>/repository/helm-proxy/` returned `"nexus-helm" has been added to your repositories`, rc 0, on helm **v4.3.0**, with `HELM_REPOSITORY_CONFIG` scoped to the temp dir and the operator's global list untouched.

## Known Stubs

None. The gate is complete as specified; its `NOTHING RAN` state in this repository is the designed green-by-skip behaviour of a gate committed before its subject, not a stub.

## Scope Note Handed to the Verifier

`VERIFY-FAILS-LOUDLY`'s "names the ecosystem" sub-condition greps the run output for `npm` or `pip`. A subject that prints the word `npm` for an unrelated reason (for example an `npm config set` progress line) would satisfy it without naming the *failing* ecosystem. Tightening it requires knowing 24-06's actual message format, so it is deliberately left loose here; 24-07 may narrow it once the real wording exists.

## Next Phase Readiness

- **Plan 24-06** has a complete, exercised contract to build against: twelve check names, a binding write-ordering requirement, the four `.nexus-env` exports, the Docker prefix shape, and a `NEXUS_SETUP_GATE_SUBJECT` hook for iterating before commit.
- **Plan 24-04** is unaffected: `DOCKER-DAEMON-WARNING` skips cleanly if its A3 verdict is that the Docker daemon must not be touched, and `DOCKER-PREFIX-SHAPE` asserts on the `.nexus-env` line only, so a `daemon.json` mirror URL containing `/repository/` will not fight it.
- **Plan 24-10** owns the PR and marks NEXUS-04. Nothing was pushed. Branch `feature/phase-24-nexus-anonymous-and-workstation` now carries `1266279` (24-01) and `f008707` (24-03).
- **Regression check:** `bash scripts/check-nexus-chart.sh` still reports `PASS - 18 checks, 0 failures`.

---
*Phase: 24-nexus-anonymous-access-and-workstation-script*
*Completed: 2026-09-19*

## Self-Check: PASSED

- `repos/security-platform/scripts/check-nexus-setup.sh` — FOUND (mode 100644, 735 lines)
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-03-SUMMARY.md` — FOUND
- Commit `f008707` — FOUND on `feature/phase-24-nexus-anonymous-and-workstation`
- `git diff-tree --no-commit-id --name-only -r f008707` → `scripts/check-nexus-setup.sh` (exactly one path)
- `git diff --diff-filter=D --name-only HEAD~1 HEAD` → empty (no deletions)
