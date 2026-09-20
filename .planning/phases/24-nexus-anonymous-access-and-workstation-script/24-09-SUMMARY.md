---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 09
subsystem: docs
tags: [adr, decision-record, nexus, anonymous-access, workstation, docker, checkov, deferred-items]

# Dependency graph
requires:
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 01
    provides: "The wrapper-owned anonymous.enabled value, the unconditional anonymous PUT (200) and the guarded DockerToken realm append (204), with the jq -c normalisation measurement behind the no-change skip"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 02
    provides: "The four anonymous byte counts, the EULA/metadata boundary, and the provision.readiness.* wiring that closes Phase 23 deferred item 2"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 04
    provides: "VERDICT: A3-FALSIFIED-CANDIDATE-1, the components-delta method, and the operator's recorded daemon-opt-in selection"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 05
    provides: "The five-leg anonymous Docker handshake, the 3,626,020-byte layer blob, and the /v2/<repo> 200 vs /v2/repository/<repo> 404 path shapes that close ADR-020 item 2"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 07
    provides: "The --verify status vocabulary, the three server-side diagnoses, and the daemon-opt-in branch with its ADR-009 refinement"
provides:
  - "docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md — Accepted, ten decisions, seven not-verified items, 321 lines"
  - "ADR-020's anonymous stance superseded in prose and its `What was NOT verified` item 2 closed by reference, with ADR-020 itself untouched"
  - "One ADR-021 index row in docs/adr/README.md"
  - "Phase 23 deferred item 2 RESOLVED and item 3 ACCEPTED, both dated and citing ADR-021; items 1, 4-8 left open"
  - "Phase 25's ArgoCD overlay requirement recorded as a named hand-off (ADR-021 not-verified item 6)"
affects: [24-10, phase-25-nexus-live-validation, phase-26-defectdojo]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Supersede an append-only record in prose and close its open item by reference, never by editing the accepted file"
    - "Every status code and byte count in a decision record traces to a named SUMMARY or evidence file of the same phase; recall is not a source"
    - "When an acceptance grep forbids a literal string whose fact is load-bearing, write the fact with a placeholder (the 24-08 precedent) rather than dropping the fact"
    - "Close a deferred item by adding a dated disposition beneath it, never by deleting it — the record of what was open and why is the value"

key-files:
  created:
    - docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md
  modified:
    - docs/adr/README.md
    - .planning/phases/23-nexus-generic-chart/deferred-items.md

key-decisions:
  - "The mirror URL and the token endpoint are written with placeholders (`<host>/repository/<docker-repo>`) everywhere except decision 5's explicit '404 / no client emits this' explanation, so the plan's `grep -c 'repository/docker-proxy'` criterion is satisfiable without dropping the asymmetry that stops a reader unifying the two Docker URL shapes. This is 24-08's precedent applied to the ADR."
  - "ADR-021 records the 24-07 refinement of the operator's literal 'both keys' selection — `insecure-registries` is written only for a plain-http --url — and names it as a deliberate ADR-009-driven refinement, so a future reader comparing the script to the quoted decision does not read the difference as a defect."
  - "A seventh `What was NOT verified` item was added beyond the plan's six: no `helm upgrade` of an existing install was exercised, so the guarded realms append is proven across two provisioning passes on one instance and not across an upgrade of an instance whose PVC already carried Phase 23's state. ADR-020 item 3 (ArgoCD hook treatment) is restated there as still unobserved."
  - "`requirements-completed: []` on purpose. The plan frontmatter carries NEXUS-02 and NEXUS-04 and Task 2 explicitly withholds both; plan 24-10 marks them after the implementation is on origin/main. `requirements.mark-complete` was NOT run — the 17-01 reverted-mark precedent."
  - "Both tasks land in ONE commit by plan design: Task 2's acceptance criterion asserts `git diff-tree` on a single SHA lists exactly the three `files_modified` paths."

patterns-established:
  - "Pattern: a plan verification command that cannot run in this repository is measured, reported and substituted with what exists, rather than silently skipped — `pre-commit` has no config here and the substitutes are `bash scripts/check-adoption-guide.sh` and `markdownlint-cli2`."
  - "Pattern: before appending a table row, check the file's trailing newline — without one the append modifies the previous row and a 'one insertion, zero deletions' criterion fails."

requirements-completed: []  # NEXUS-02 and NEXUS-04 withheld ON PURPOSE — plan 24-10 marks both after merge to origin/main.

# Metrics
duration: ~40min
completed: 2026-09-20
---

# Phase 24 Plan 09: ADR-021 and the Phase 23 Deferred-Item Dispositions Summary

**The phase's ten decisions, their measured basis and seven named unmeasured edges are now in an append-only decision record that supersedes ADR-020's anonymous stance and closes its open Docker item entirely by reference — ADR-020 and `CLAUDE.md` both byte-untouched — and the two Phase 23 items handed to this phase carry dated dispositions rather than silence.**

## Performance

- **Duration:** ~40 min
- **Tasks:** 2 (both `auto`, no checkpoints)
- **Files:** 1 created, 2 modified
- **Commits:** 1 (both tasks, by plan design) plus the closeout commit
- **Diff:** 347 insertions, **0 deletions**, 3 files

## Task Commits

| Tasks | Commit | Subject |
|-------|--------|---------|
| 1 + 2 | `1245f49` | `docs(24-09): record ADR-021 and close Phase 23 deferred items 2 and 3` |

`git diff-tree --no-commit-id --name-only -r 1245f497becaf3802e9d6d7f1e62a6cfa3ea18ac` lists exactly:

```text
.planning/phases/23-nexus-generic-chart/deferred-items.md
docs/adr/README.md
docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md
```

Branch `feature/phase-12-repo-setup-script` in the parent `security_solution` repository. Nothing in `repos/security-platform/` was touched, which is why this plan ran in parallel with 24-08. Commit hooks ran normally; no `--no-verify`. `git diff --diff-filter=D --name-only HEAD~1 HEAD` is empty — no file was deleted.

## ADR-021: the ten decisions, as recorded

`docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md` — **Status: Accepted**, dated **2026-09-20**, 321 lines, four section headings matching ADR-020's (`## Context`, `## Decision`, `## Consequences`, `## What was NOT verified`).

| # | Decision | The measurement it rests on |
|---|----------|------------------------------|
| 1 | Anonymous access is a wrapper-owned top-level `anonymous.enabled`, shipped `false` | `nexus3.config.anonymous.*` measured inert (byte-identical render), removed in `a9c4f38`; `ANONYMOUS-VALUE-PRESENT` proves wiring by toggling two renders; a grep-based check still returned **7** matches with the env entry deleted |
| 2 | The anonymous PUT is unconditional, not guarded like the EULA POST | PUT returns **200** (not 204) and is idempotent; three passes measured OPEN → no-change → **CLOSED**, the property a guarded skip would lose |
| 3 | `DockerToken` is appended unconditionally, decoupled from `anonymous.enabled` | With the realm inactive a token issues 200 but the manifest carrying it returns **401 — including for an ADMIN-issued token**, so the realm governs bearer validation, not anonymity |
| 4 | The realms PUT is a guarded GET-then-append-if-absent with a no-change skip | PUT replaces the whole list (omitting `NexusAuthenticatingRealm` locks out admin); the API stores duplicates; `jq -c` on both sides before `cmp -s` because 30 bytes vs 28+newline differ on every run |
| 5 | The Docker pull path carries no `/repository/` segment — **closes ADR-020 item 2** | `/v2/<repo>/...` **200**, `/v2/repository/<repo>/...` **404**, third shape 200 but emitted by no client; full handshake with a **3,626,020**-byte layer blob; `crane` exported **8,083,968** bytes anonymously |
| 6 | "Per-repository routing" means four different things | npm native project scope (merge measured non-destructive); pip and Helm env-redirected only; Docker has no mechanism at all; `PIP_CONFIG_FILE` **replaces** the user scope; `pip config get` cannot see the `:env:` variant |
| 7 | The Docker behaviour the operator selected: `daemon-opt-in`, off by default, measured mirror URL | `VERDICT: A3-FALSIFIED-CANDIDATE-1` quoted verbatim; dind pinned to the exact host engine, operator's `daemon.json` asserted `55a16d28…` unchanged; verdict from the components delta (0→1 vs 0→0 with pull exit 0 both times) |
| 8 | Generated config is gitignored by default with a `--commit-config` escape hatch | A committed `.npmrc` is a resolution failure for unreachable contributors and an internal-hostname disclosure in a public repo; already-tracked files warned explicitly |
| 9 | The readiness knobs are wired through — **closes Phase 23 deferred item 2** | `READY_ATTEMPTS=2 READY_INTERVAL=1` exits 1 after `attempt 2/2` in two seconds; default render `"60"`/`"10"`, `--set` render `"7"`/`"3"`; no `:-` default, so a missing entry is a `set -u` hard failure |
| 10 | Checkov's zero coverage is accepted and documented — **closes Phase 23 deferred item 3** | **24** latent findings (5 wrapper, 19 subchart), none reaching CI; both alternatives create a second artefact that drifts by construction; ADR-020's prohibition on weakening the `required` guard restated |

### The `## What was NOT verified` list, as recorded

1. **No pull was performed by the operator's own Docker daemon** — three substitutes named with their sources (`crane`, `curl` speaking OCI leg by leg, and the digest-pinned dind engine), with the Docker Desktop VM boundary as the specific unmeasured step and the `overlay2` hedge removed.
2. **`forceBasicAuth`'s documented-versus-measured divergence**, carried forward from Phase 23 — with `true` the challenge is still `Bearer` and the manifest still 200 on 3.96.0.
3. **Checkov still provides zero coverage** — accepted in decision 10, not solved; the 24 latent findings are *expected* unchanged rather than *known* to be.
4. **Nothing was measured against a TLS-terminated Nexus**, and no ingress exists yet.
5. **A custom anonymous role scoped to the four proxies was not built** — the remedy for the wildcard scope is described, not implemented, and no gate asserts it.
6. **Phase 25 input, as a named hand-off: the private ArgoCD overlay must set `anonymous.enabled: true` explicitly**, or the first live deploy ships NEXUS-02 closed and nine anonymous verdicts plus the Docker handshake go red against real infrastructure.
7. **No `helm upgrade` of an existing install was exercised** — beyond the plan's six, added because both REST calls reach a deployed instance only through the post-upgrade hook Job and every measurement was against a fresh container or a fresh `kind` install. ADR-020 item 3 (ArgoCD hook treatment) restated there as still unobserved.

### The named tradeoffs in `## Consequences`

Anonymous read is all-repository and cannot be narrowed in place (`nx-anonymous` is `readOnly: true` with `nx-repository-view-*-*-read/browse`), which intersects **ADR-010's** hosted-before-proxy ordering guidance; the anonymous repository-inventory disclosure via `GET /service/rest/v1/repositories`; plaintext HTTP until Phase 25's ingress with NetworkPolicy explicitly out of scope and both plaintext directives carrying ADR-009's removal sentence; the Community Edition 40,000-component / 100,000-request-per-day ceilings becoming easier to reach once auth friction is gone; and the `/repository/` segment meaning opposite things in the mirror URL and the image reference, where the unification failure is **silent** on the mirror side.

## The index row, verbatim

```markdown
| [ADR-021](adr021-nexus-anonymous-read-and-workstation-routing.md) | Nexus Anonymous Read and Workstation Routing | 2026-09-20 | Accepted |
```

`git diff-tree --no-commit-id --numstat -r <SHA> -- docs/adr/README.md` → `1  0` — **one addition, zero deletions.** The title is the ADR's H1 with the leading `ADR-021:` label and the space after it removed, byte-for-byte; the href resolves to an existing file; no existing row was reordered or reformatted. The file already ended with a newline (`tail -c1 | xxd` → `0a`), which is what makes the one-insertion-zero-deletions result possible rather than a modified ADR-020 row.

## The two deferred-item dispositions

**Item 2 — `provision.readiness.*` dead knobs: RESOLVED 2026-09-20 by wiring them through** (plan 24-02, `security-platform` commit `07c74e2`). The disposition names the full mechanism — rendered by `job-provision.yaml` into `READY_ATTEMPTS` / `READY_INTERVAL`, named in `provision.sh`'s environment contract and hard-failure sentence, read with **no `:-` default** so a missing entry is a `set -u` failure rather than a silent 60/10 fallback, and set by the live smoke's `run_provision` — and the observation that proved it: a short-poll run exiting 1 after `attempt 2/2` in two seconds where the old hardcode would have polled for ten minutes. Cites ADR-021 decision 9.

**Item 3 — Checkov zero coverage: ACCEPTED and documented 2026-09-20, not solved**, per ADR-021 decision 10. Restates the latent count (**24**: 5 wrapper, 19 subchart) so zero in CI is not read as clean, records that **the `required` credential guard was not weakened** and that ADR-020's prohibition stands, and names the revisit trigger: the next phase that adds a second chart doubles the blind spot.

**Item 1** gained a dated note that ADR-021 widens the stale `CLAUDE.md` ADR range by one more record (now ADR-001 through ADR-021 against a file that still says ADR-018), that plan 24-09 deliberately did **not** edit `CLAUDE.md` because it is the project's own instruction file and 23-07's reasoning still applies, and that the item **stays open**.

**Items 4, 5, 6, 7 and 8 are textually unchanged.** The file's `git diff --numstat` is `25 0` — twenty-five insertions, **zero deletions** — so nothing that was open was quietly closed and nothing that was recorded was rewritten. Note that this file carries **eight** items, not the six the plan's action text describes; items 7 and 8 are SDK gotchas recorded by 23-08 and were left alone.

## Verification

| Criterion | Result |
|-----------|--------|
| ADR exists, `**Status:** Accepted`, dated, `**Addresses:**` names NEXUS-02 and NEXUS-04 | PASS |
| The four ADR-020 section headings, in order | PASS — lines 9, 41, 197, 274 |
| All ten decisions, each a bolded claim sentence then mechanism and rejected alternative | PASS |
| `## What was NOT verified` has at least six numbered, bolded items including the Phase 25 hand-off | PASS — **7** items; the hand-off is item 6 |
| `min_lines: 90` | PASS — **321** lines |
| `git status --porcelain docs/adr/adr020-*.md` empty — ADR-020 untouched | PASS |
| `git status --porcelain CLAUDE.md` empty | PASS |
| `grep -c 'repository/docker-proxy'` counts only the explicit 404 / no-client explanation | PASS — **2** occurrences, both on lines 89–90 inside decision 5; nowhere presented as a usable pull target |
| The A3 `VERDICT:` line quoted verbatim | PASS — `VERDICT: A3-FALSIFIED-CANDIDATE-1`, line 126 |
| `docs/adr/README.md` gained exactly one line, zero deletions | PASS |
| Index title matches the H1 exactly; href resolves | PASS |
| Items 2 and 3 carry dated dispositions citing ADR-021; 1, 4–8 open | PASS |
| `git diff-tree --no-commit-id --name-only -r <SHA>` lists exactly the three `files_modified` | PASS |
| `bash scripts/check-adoption-guide.sh` | PASS — `PASSED 15 / FAILED 0`, exit 0 |
| `markdownlint-cli2` on all three files | PASS — `Summary: 0 error(s)` |
| `pre-commit run --files <the three>` | **NOT RUNNABLE** — see deviation 1 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `pre-commit run --files …` cannot exit 0 in this repository — there is no `.pre-commit-config.yaml` here**

- **Found during:** Task 1 verification.
- **Issue:** Both tasks' `<verify>` blocks and both acceptance-criteria lists require `pre-commit run --files <paths>` to exit 0. `pre-commit` is installed (`/Users/christian/.local/bin/pre-commit`) but this documentation repository has **no** `.pre-commit-config.yaml` — that file lives in `repos/security-platform`, which this plan deliberately does not touch. Observed, rather than assumed: `pre-commit run --files docs/adr/README.md` exits non-zero with `An error has occurred: InvalidConfigError: .pre-commit-config.yaml is not a file`. Writing "pre-commit exits 0" into this SUMMARY would have been a claim about a command that never ran. This is the same shape as 24-01 deviation 3 — a criterion that is unsatisfiable against the repository's actual state.
- **Fix:** the criterion is recorded as a plan defect and substituted with the gates that do exist here: `bash scripts/check-adoption-guide.sh`, which is this repository's standing documentation gate (`PASSED 15 / FAILED 0`), and `markdownlint-cli2` run directly against all three changed files with the repository's own `.markdownlint-cli2.yaml` (`Summary: 0 error(s)`). The active `.git/hooks/pre-commit` — git's whitespace-checking example hook, renamed and therefore live — ran on the commit and passed; the ADR carries zero trailing-whitespace lines and zero hard tabs, checked directly.
- **Files modified:** none (a verification substitution, not a content change).
- **Commit:** n/a.

**2. [Rule 2 — Missing Critical] The daemon mirror URL and the token endpoint are written with placeholders, not literals**

- **Found during:** Task 1, drafting decisions 5 and 7 against the plan's own acceptance grep.
- **Issue:** the plan requires `grep -c 'repository/docker-proxy'` to count **only** occurrences inside the explicit "this shape returns 404 / no client emits this" explanation. Three facts worth recording contain that literal outside it: candidate-1's measured mirror URL, the Docker token endpoint the `/v2/` challenge advertises, and 24-07's `daemon.json` "after" block. Quoting any of them verbatim would have broken the criterion; dropping the mirror-URL asymmetry to satisfy it would have removed the single fact that stops a reader "unifying" the two Docker URL shapes and silently breaking the mirror.
- **Fix:** 24-08's precedent applied — the mirror shape is written as `<host>/repository/<docker-repo>` wherever it appears outside decision 5, and the token endpoint is not named at all (24-08 omitted it for the same reason, and it is server-advertised, so nothing a consumer acts on is lost). The mechanism that makes the placeholder intelligible is stated instead: moby stores the whole mirror URL path-included on the `APIEndpoint` and appends `/v2/` **after** the configured path, which is exactly why the mirror shape works and why it produces the curl-only third shape from decision 5.
- **Files modified:** `docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md`
- **Verification:** `grep -n 'repository/docker-proxy'` returns exactly two hits, both on lines 89–90 inside decision 5's 404 / no-client sentence.
- **Commit:** `1245f49`

**3. [Rule 2 — Missing Critical] ADR-021 names the 24-07 refinement of the operator's literal "both keys" selection**

- **Found during:** Task 1, reconciling 24-04's recorded decision against 24-07's shipped behaviour.
- **Issue:** the operator's verbatim reply selects "**both** `registry-mirrors` and `insecure-registries`" unconditionally. 24-07 deviation 4 made `insecure-registries` conditional on a plain-http `--url`, on ADR-009 grounds. Both are correct and the plan's decision 7 does not mention the difference. A future reader comparing the shipped script to the quoted operator decision would find a mismatch with no explanation, and the most likely reading is "the executor ignored the operator".
- **Fix:** decision 7 states the refinement explicitly, gives its reason (the measured A3 pair was http, so an http run ships exactly the measured pair; writing a TLS bypass for an https Nexus would disable a check that is working, which is what ADR-009 forbids and what already makes pip's `trusted-host` conditional), and labels it a deliberate refinement rather than a defect.
- **Files modified:** `docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md`
- **Commit:** `1245f49`

**4. [Rule 2 — Missing Critical] A seventh `What was NOT verified` item: no `helm upgrade` of an existing install**

- **Found during:** Task 1, reading 24-RESEARCH.md's runtime-state inventory against the plan's six-item list.
- **Issue:** the inventory records that an existing instance's PVC already carries `enabled: false` and `["NexusAuthenticatingRealm"]`, and that both new calls reach it **only** through the post-upgrade hook Job — with "Phase 25 must confirm on the homelab instance rather than assume" written next to it. Every measurement in this phase was against a freshly booted container or a fresh `kind` install. Omitting that would have left the record's strongest claim (the guarded append makes repeated upgrades safe) resting on two passes against one fresh instance while reading as if it covered upgrades.
- **Fix:** item 7 added, naming the exact state an existing PVC carries and deferring the confirmation to Phase 25. ADR-020's item 3 (ArgoCD hook treatment is training knowledge, not an observation) is restated in the same item as still unclosed, so the ADR does not imply this phase narrowed it.
- **Files modified:** `docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md`
- **Commit:** `1245f49`

---

**Total deviations:** 4 auto-fixed (1 blocking, 3 missing critical)
**Impact on plan:** deviation 1 substitutes an unrunnable verification with runnable ones and reports the substitution rather than claiming the original. Deviations 2–4 add fidelity to the record; none removes anything the plan asked for. No file outside `files_modified` was touched, and `CLAUDE.md` and ADR-020 are both byte-identical to their pre-plan state.

## Issues Encountered

None that blocked.

Worth handing forward: **`.planning/phases/23-nexus-generic-chart/deferred-items.md` carries eight items, not six.** The plan's Task 2 action text says "items 1 through 6" and instructs that 1, 4, 5 and 6 be left open; items 7 and 8 (SDK gotchas recorded by 23-08) exist and were also left untouched. Those two items are load-bearing for this plan's own state updates — they record that `state.record-metric` and `state.add-decision` reject positional arguments and need the flag form, and that `state.update-progress` no-ops against this STATE.md. Both were honoured below.

## Requirements

`requirements-completed: []` — **NEXUS-02 and NEXUS-04 are deliberately NOT marked complete here**, and `gsd-sdk query requirements.mark-complete` was **not run**, despite the plan frontmatter carrying both IDs and the executor's standard state-update step calling for it. `24-09-PLAN.md` Task 2 overrides that explicitly: "`requirements-completed: []` — NEXUS-02 and NEXUS-04 are marked in plan 24-10 only, after the implementation is on `origin/main`." This follows the 17-01 precedent, where `requirements mark-complete` flipped CICD-02/03 from plan frontmatter and had to be reverted, and the unbroken 23-01/24-01/24-02/24-05/24-06/24-07/24-08 withholding pattern. An empty list here is intentional, not a missed step.

## Known Stubs

None. This plan ships prose only; nothing in it is recognised-but-inert.

## Threat Flags

None. The plan's four `mitigate` dispositions are each implemented and checkable:

| Threat | Where it is mitigated |
|--------|----------------------|
| T-24-45 unverified claims recorded as verified | Every status code and byte count in ADR-021 traces to a named SUMMARY of this phase or to `24-evidence/a3-docker-daemon-routing.md`; `## What was NOT verified` carries **7** items and item 1 names all three substituted Docker clients with their sources |
| T-24-46 append-only ADR history tampered with | `git status --porcelain docs/adr/adr020-*.md` empty; supersession is in prose and item 2's closure is by reference; the commit contains **zero deletions** across all three files |
| T-24-47 residual risks left unrecorded | Wildcard anonymous scope (with its ADR-010 intersection), the `GET /v1/repositories` inventory disclosure, plaintext-until-Phase-25 with NetworkPolicy out of scope, and the CE ceilings are each a named `**Tradeoff — …**` paragraph |
| T-24-48 silently dropped deferred items | Items 2 and 3 carry dated dispositions citing ADR-021; items 1 and 4–8 are left open, with `git diff --numstat` showing `25 0` — no deletions |

## Next Phase Readiness

Ready for plan 24-10, which owns the PR, the merge to `origin/main`, and `requirements.mark-complete` for NEXUS-02 and NEXUS-04. Two inputs from this plan:

- **24-10:** the ADR is in the parent repository on `feature/phase-12-repo-setup-script`, **not** on `security-platform`'s `feature/phase-24-nexus-anonymous-and-workstation` branch. The PR 24-10 opens covers the chart and script work only; this record and the index row travel with the documentation repository's own history.
- **Phase 25:** the ArgoCD overlay must set `anonymous.enabled: true` explicitly (ADR-021 not-verified item 6), and it may need the readiness budget of decision 9 if homelab cold-boot time differs from the container measurements. The upgrade path of not-verified item 7 is the other thing to confirm there rather than assume.

Not done here and not in scope: `CLAUDE.md`'s stale ADR range (deferred item 1, left open on purpose), any edit to `REQUIREMENTS.md` or `ROADMAP.md` beyond this plan's own closeout, and anything under `repos/security-platform/`.

---
*Phase: 24-nexus-anonymous-access-and-workstation-script*
*Completed: 2026-09-20*

## Self-Check: PASSED

- `docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md` — FOUND, 321 lines, `**Status:** Accepted`
- `docs/adr/README.md` — FOUND, ADR-021 row present, href resolves
- `.planning/phases/23-nexus-generic-chart/deferred-items.md` — FOUND, items 2 and 3 dispositioned
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-09-SUMMARY.md` — FOUND
- Commit `1245f49` — FOUND in `git log --oneline --all`, `git diff-tree` lists exactly the three `files_modified` paths
- `markdownlint-cli2` on all four files — `Summary: 0 error(s)`
