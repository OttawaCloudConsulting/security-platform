---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 02
subsystem: infra
tags: [nexus, helm, kubernetes, bash, live-gate, anonymous-access, npm, pypi, helm-repo, readiness]

# Dependency graph
requires:
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 01
    provides: "anonymous.enabled value wired to the Job env; provision.sh steps 3 (anonymous PUT) and 4 (DockerToken realm); run_provision() carrying the three ANONYMOUS_* variables at false"
  - phase: 23-nexus-generic-chart
    provides: "scripts/nexus-live-smoke.sh with its pass/fail/require_success helpers, three-state print_summary and section 5 three-way verdict split; provision.readiness.* values keys (inert until this plan)"
provides:
  - "ANONYMOUS-PULL-ALLOWED-{TRANSPORT,HTTP-200,SIZE} — unauthenticated npm tarball measured at HTTP 200 and 318,961 bytes"
  - "ANONYMOUS-PULL-PYPI-{TRANSPORT,HTTP-200,SIZE} — unauthenticated PyPI per-project simple page (`requests`) at HTTP 200 and 76,776 bytes"
  - "ANONYMOUS-PULL-HELM-{TRANSPORT,HTTP-200,SIZE} — unauthenticated Helm index.yaml at HTTP 200 and 291,818 bytes"
  - "run_provision() on the anonymous-ENABLED path, carrying READY_ATTEMPTS / READY_INTERVAL"
  - "provision.readiness.attempts / intervalSeconds are consumer-controllable end to end (values.yaml -> Job env -> provision.sh), closing Phase 23 deferred item 2"
  - "Live gate count 13 -> 21 checks, 0 skipped"
affects: [24-05, 24-07, 24-08, 24-09, 24-10, phase-25-nexus-live-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Three verdicts per fetch (TRANSPORT / HTTP-status / SIZE) so a transport error, a wrong status and a refusal body are three distinguishable failures, and no one of them can mask another"
    - "Size floors set from a MEASURED value under two stated rules (>= 10x the 192-byte refusal; <= half the measured size), with the rule written in the file so nobody tightens the floor into an upstream-content tripwire"
    - "An inert consumer-visible values key is proven live by setting it absurdly low and observing the bound take effect, not by reading the rendered manifest"

key-files:
  created: []
  modified:
    - repos/security-platform/scripts/nexus-live-smoke.sh
    - repos/security-platform/kubernetes/nexus/files/provision.sh
    - repos/security-platform/kubernetes/nexus/templates/job-provision.yaml
    - repos/security-platform/kubernetes/nexus/values.yaml

key-decisions:
  - "THE MEASUREMENT OF THIS PLAN: under `eula.accepted=false` the PyPI per-project simple page still returns HTTP 200 with its full 76,776 bytes, while the npm tarball and the Helm index.yaml both return HTTP 403 with a 192-byte refusal. The EULA gate covers COMPONENT downloads; a PyPI simple page is METADATA and is not behind it. The plan's reversion-2 prediction (all three red on SIZE at 403) is therefore NOT satisfiable without writing a false check, and 24-RESEARCH.md Pitfall 2 already said so ('metadata returns 200'). The assertion was NOT adjusted to match the prediction; the measurement is recorded in the file instead."
  - "The Helm index.yaml IS behind the EULA gate (403 + 192 bytes when unaccepted) — Nexus treats it as a component, not as metadata. That is the opposite of the PyPI result and is written next to each check."
  - "Each ecosystem gets THREE verdicts, not one, so the live count goes 13 -> 21 rather than the plan's predicted 16. A single if/elif per ecosystem would stop at the status and never evaluate SIZE, which would have made reversion 2 unobservable — the very evidence the plan's own Task 3 demands."
  - "READY_ATTEMPTS / READY_INTERVAL are read from the environment with NO `:-` default, matching the file's stated contract that only REPO_CONFIG_DIR carries one. Deleting the env entry is a `set -u` hard failure in the Job, not a silent fallback to 60/10."
  - "The three anonymous size floors are 100,000 / 20,000 / 100,000 against measured 318,961 / 76,776 / 291,818 — each at least 10x the 192-byte refusal and at most half the measured size, with the rule stated as a comment."
  - "NEXUS-02 deliberately NOT marked complete (requirements-completed: []), continuing the 17-01 reverted-mark precedent and the 23-01/24-01 withholding; plan 24-10 marks it after the work is on origin/main."

patterns-established:
  - "Pattern: a plan's stated prediction loses to a measurement, and the divergence is written into the source file at the point it matters — not only into the SUMMARY, where the next reader of the script will never see it."
  - "Pattern: a fail-branch message must not name a discriminand it cannot actually discriminate (the PyPI SIZE message names the 401 challenge and the redirect body, and says explicitly that the EULA refusal is deliberately absent)."

requirements-completed: []  # NEXUS-02 withheld on purpose — see key-decisions; plan 24-10 marks it.

# Metrics
duration: ~55min
completed: 2026-09-19
---

# Phase 24 Plan 02: Anonymous Pull Proven Live for npm, PyPI and Helm Summary

**The live gate flipped from asserting anonymous pull is CLOSED to measuring it OPEN across three ecosystems — nine verdicts, each with a byte floor derived from a measured size under a stated rule — and the two Phase 23 readiness knobs stopped being decorative, proven by a two-attempt poll that failed in two seconds.**

## Performance

- **Duration:** ~55 min
- **Started:** 2026-09-19T23:02Z
- **Completed:** 2026-09-19T23:57Z
- **Tasks:** 3 (one commit by plan design)
- **Files modified:** 4
- **Live smoke runs:** 5 (1 measurement, 2 reversions, 2 full green)

## Accomplishments

- Anonymous pull is **measured**, not asserted, for npm, PyPI and Helm: HTTP 200 **and** a byte count, on a fetch that carries no `-u` and no `-K -`.
- `provision.readiness.attempts` / `intervalSeconds` reach `provision.sh` and change its behaviour — closing Phase 23 deferred item 2 in the "wire them through" direction (24-RESEARCH.md Open Question 2).
- The live gate went **13 -> 21 checks, 0 skipped**, `ALL PASS`, with the kind half green: the two new env entries were exercised inside the real `alpine/k8s` Job image under `set -u`, not only in a `helm template` render.
- A counter-intuitive EULA/metadata boundary was measured and written into the script, correcting the plan's own reversion prediction rather than being bent to fit it.

## Task Commits

Tasks 1-3 land in a single commit by plan design (the 24-01 / 15-03 precedent): Task 3's own acceptance criterion requires `git diff-tree` on this plan's commit to list exactly the four `files_modified` paths, and a commit that flipped `ANONYMOUS_ENABLED` while the check below still asserted 401 would be a red gate in git history for no reason.

1. **Tasks 1-3** — `07c74e2` (feat) in `OttawaCloudConsulting/security-platform`, branch `feature/phase-24-nexus-anonymous-and-workstation`

`git diff-tree --no-commit-id --name-only -r 07c74e22d0b2f591b180dc66af2f8818d2a08823` lists exactly the four `files_modified` paths and nothing else. 212 insertions, 34 deletions.

## Files Created/Modified

- `repos/security-platform/scripts/nexus-live-smoke.sh` — `run_provision()` on the anonymous-ENABLED path plus `READY_ATTEMPTS=60 READY_INTERVAL=10`; `ANONYMOUS-PULL-DENIED` rewritten in place as nine verdicts across three ecosystems. 503 -> 650 lines.
- `repos/security-platform/kubernetes/nexus/files/provision.sh` — `READY_ATTEMPTS=60` / `READY_INTERVAL=10` hardcodes deleted; both added to the environment-contract header and to its hard-failure sentence; the readiness-bounds comment gains a paragraph recording that both numbers are now consumer-supplied and that `activeDeadlineSeconds` is the one hard ceiling. 371 -> 385 lines.
- `repos/security-platform/kubernetes/nexus/templates/job-provision.yaml` — `READY_ATTEMPTS` / `READY_INTERVAL` env entries from `provision.readiness.*`, quoted, directly after the `ANONYMOUS_*` block, with the reason an absent entry is a hard failure rather than a fallback.
- `repos/security-platform/kubernetes/nexus/values.yaml` — the two readiness helm-docs comments no longer describe an intention; they name `READY_ATTEMPTS` / `READY_INTERVAL`, keep the `60 x 10s = 10 minutes` arithmetic and the cold-boot measurement, and state that the product must stay inside `provision.activeDeadlineSeconds`.

## Measured Evidence

### The one divergence from the plan's prediction — reversion 2

**Predicted by the plan:** all three anonymous checks fail on the SIZE assertion with a ~192-byte body at HTTP 403.

**Observed** (`EULA_ACCEPTED=false` in `run_provision()`, everything else unchanged):

```
==> ARTIFACT-HTTP-200: FAIL - tarball request returned HTTP 403, expected 200 (403 means the EULA was never accepted)
==> ARTIFACT-SIZE: FAIL - only 192 bytes downloaded, expected > 100000; a ~192-byte body is the EULA refusal, not a tarball
==> ANONYMOUS-PULL-ALLOWED-TRANSPORT: PASS - unauthenticated curl completed against .../npm-proxy/lodash/-/lodash-4.17.21.tgz
==> ANONYMOUS-PULL-ALLOWED-HTTP-200: FAIL - ... returned HTTP 403, expected 200; 401 means anonymous read was never opened, 403 means the EULA was never accepted
==> ANONYMOUS-PULL-ALLOWED-SIZE: FAIL - only 192 bytes pulled with no credential, expected > 100000; ~192 bytes is the EULA refusal body and 0 bytes is the 401 challenge, neither of which is a tarball
==> ANONYMOUS-PULL-PYPI-TRANSPORT: PASS - unauthenticated curl completed against .../pypi-proxy/simple/requests/
==> ANONYMOUS-PULL-PYPI-HTTP-200: PASS - unauthenticated GET of the requests simple page returned HTTP 200
==> ANONYMOUS-PULL-PYPI-SIZE: PASS - 76776 bytes of simple index pulled with no credential (> 20000)
==> ANONYMOUS-PULL-HELM-TRANSPORT: PASS - unauthenticated curl completed against .../helm-proxy/index.yaml
==> ANONYMOUS-PULL-HELM-HTTP-200: FAIL - ... returned HTTP 403, expected 200; 401 means anonymous read was never opened, 403 means the EULA was never accepted, 404 means the helm-proxy repository was never created
==> ANONYMOUS-PULL-HELM-SIZE: FAIL - only 192 bytes pulled with no credential, expected > 100000; ~192 bytes is the EULA refusal body and 0 bytes is the 401 challenge, neither of which is a chart index
```

**npm and Helm behaved exactly as predicted. PyPI stayed fully green.** The EULA gate applies to **component downloads**, and a PyPI per-project simple page is **metadata** — Nexus serves it regardless of licence state. `24-RESEARCH.md` Pitfall 2 states this in so many words ("every anonymous component download returns 403 … while metadata returns 200"); the plan's Task 3 prediction contradicted the plan's own research.

Per the plan's instruction ("If the observed behaviour differs from that prediction, stop and report rather than adjusting the assertion to match"), **no assertion was adjusted**. Instead:

- the measurement is recorded as a comment immediately above the PyPI check, stating that its floor discriminates the zero-byte 401 challenge and not a licence refusal, and that raising the floor cannot fix that because no byte count can discriminate a state in which the server returns the correct content;
- the corresponding Helm comment records the opposite result — `index.yaml` **is** behind the EULA gate, so Nexus treats it as a component rather than as metadata;
- the `ANONYMOUS-PULL-PYPI-SIZE` failure message was reworded so it no longer names the 192-byte EULA refusal as something it discriminates (it names the zero-byte 401 challenge and a trailing-slash redirect body instead, and says explicitly why the refusal is absent).

Non-vacuity of `ANONYMOUS-PULL-PYPI-SIZE` therefore rests on reversion 1, where it was observed red at 0 bytes — not on reversion 2.

**Handed forward, load-bearing for plans 24-07 and 24-08:** a PyPI simple-page HTTP 200 is **not** evidence that the server's EULA is accepted. The workstation script's `--verify` pass (24-07) and the chart README's "name both values together" prose (24-08) must derive that evidence from a component download — an npm tarball, a Helm `index.yaml`, or a PyPI file under `/packages/` — not from `/simple/<project>/`.

### Reversion 1 — `ANONYMOUS_ENABLED=false` in `run_provision()`

Predicted: all three go red with HTTP 401. Observed, exactly:

```
==> ANONYMOUS-PULL-ALLOWED-TRANSPORT: PASS - unauthenticated curl completed against .../npm-proxy/lodash/-/lodash-4.17.21.tgz
==> ANONYMOUS-PULL-ALLOWED-HTTP-200: FAIL - ... returned HTTP 401, expected 200; 401 means anonymous read was never opened, 403 means the EULA was never accepted
==> ANONYMOUS-PULL-ALLOWED-SIZE: FAIL - only 0 bytes pulled with no credential, expected > 100000; ~192 bytes is the EULA refusal body and 0 bytes is the 401 challenge, neither of which is a tarball
==> ANONYMOUS-PULL-PYPI-HTTP-200: FAIL - ... returned HTTP 401, expected 200; ...
==> ANONYMOUS-PULL-PYPI-SIZE: FAIL - only 0 bytes pulled with no credential, expected > 20000; ...
==> ANONYMOUS-PULL-HELM-HTTP-200: FAIL - ... returned HTTP 401, expected 200; ...
==> ANONYMOUS-PULL-HELM-SIZE: FAIL - only 0 bytes pulled with no credential, expected > 100000; ...
FAILED - one or more live checks did not produce the expected result:   (6 entries)
```

The three `TRANSPORT` verdicts stayed green, which is the split doing its job: nothing failed to connect, the server answered — it answered 401.

Both reversions were reverted immediately afterwards and the file restored from a byte-exact snapshot (`diff` empty) before the next run.

### Measured sizes and chosen thresholds

| Check | URL | Measured | Floor | >= 10 x 192 = 1,920 | <= half measured |
|---|---|---|---|---|---|
| `ANONYMOUS-PULL-ALLOWED` (npm) | `/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz` | **318,961 B** | 100,000 | yes | 159,480 — yes |
| `ANONYMOUS-PULL-PYPI` | `/repository/pypi-proxy/simple/requests/` | **76,776 B** | 20,000 | yes | 38,388 — yes |
| `ANONYMOUS-PULL-HELM` | `/repository/helm-proxy/index.yaml` | **291,818 B** | 100,000 | yes | 145,909 — yes |

**PyPI project used: `requests`.** Chosen because it is reachable through the upstream proxy on every run and its simple page is large enough for rule (2) to leave real headroom. The URL keeps its **trailing slash** — this is the per-project page a real `pip download` requests, and without the slash Nexus answers a redirect whose body would be measured instead.

All three measured sizes reproduced identically across the measurement run and both full green runs.

### Readiness knobs are consumer-controllable — observed short-poll failure

`helm template` with `--set provision.readiness.attempts=7 --set provision.readiness.intervalSeconds=3`:

```
- name: READY_ATTEMPTS
  value: "7"
- name: READY_INTERVAL
  value: "3"
```

Default render: `"60"` and `"10"`.

That proves the render. This proves the script reads it — `provision.sh` run directly with `READY_ATTEMPTS=2 READY_INTERVAL=1` against a `NEXUS_HOST` with nothing listening:

```
Waiting for Nexus to become writable at http://127.0.0.1:59999 ...
curl: (7) Failed to connect to 127.0.0.1 port 59999 after 0 ms: Couldn't connect to server
Waiting for Nexus (attempt 1/2, HTTP 000)...
curl: (7) Failed to connect to 127.0.0.1 port 59999 after 0 ms: Couldn't connect to server
Waiting for Nexus (attempt 2/2, HTTP 000)...
FATAL: Nexus did not become writable after 2 attempts at 1s; last status HTTP 000
EXIT=1 ELAPSED=2s
```

Two attempts, one second apart, exit 1 in two seconds. With the old hardcode this would have polled for ten minutes.

Greps: `READY_ATTEMPTS=60` in `provision.sh` → **0**; `READY_ATTEMPTS` → **6** (header name, header hard-failure sentence, the new consumer-supplied paragraph x2, the `seq` bound, the FATAL message). `provision.sh` is still not executable; `shellcheck` exits 0 on both scripts.

### Standing gates at HEAD (`07c74e2`)

```
bash scripts/check-nexus-chart.sh
  check-nexus-chart: asserting 18 offline invariants against kubernetes/nexus
  PASS - 18 checks, 0 failures

bash scripts/nexus-live-smoke.sh
  ALL PASS - 21 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).
  ... ANONYMOUS-PULL-ALLOWED-SIZE: PASS - 318961 bytes pulled with no credential (> 100000)
  ... ANONYMOUS-PULL-PYPI-SIZE:    PASS - 76776 bytes of simple index pulled with no credential (> 20000)
  ... ANONYMOUS-PULL-HELM-SIZE:    PASS - 291818 bytes of chart index pulled with no credential (> 100000)
  ... KIND-JOB-COMPLETE: exit=0
```

The green run's `scripts/nexus-live-smoke.sh` was `shasum -a 256 -c`'d against the committed file — **the run that is recorded as green ran the exact bytes that were committed.** `KIND-JOB-COMPLETE` green means the two new env entries reached `provision.sh` from the template's own wiring inside the real Job image under `set -u`, which is stronger evidence than the `helm template` render alone.

Environment left clean: `kind get clusters` → "No kind clusters found", kubectl context restored to `admin@occ-new`, no `nexus-live-smoke-*` container surviving. `pre-commit run --files <the four>` exits 0 (shellcheck and yamllint both Passed); commit hooks ran normally, no `--no-verify`.

## Decisions Made

See `key-decisions` in the frontmatter. The load-bearing one is the PyPI EULA/metadata boundary, which is a correction to the plan's own published prediction made from a measurement.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's reversion-2 acceptance criterion is not satisfiable without writing a false check**

- **Found during:** Task 3
- **Issue:** the plan asserts "Reversion 2 observed: all three red on the SIZE assertion with a ~192-byte body at HTTP 403". Measured: npm and Helm do exactly that; the PyPI per-project simple page returns HTTP 200 with its full 76,776 bytes under `eula.accepted=false`, because the EULA gate covers component downloads and a simple page is metadata. `24-RESEARCH.md` Pitfall 2 already states this. The only way to satisfy the criterion as written would be to point the PyPI check at a component under `/packages/` instead of the simple index — which would stop testing what 24-W0-04 asks for ("read the PyPI simple index") — or to weaken the check.
- **Fix:** nothing was adjusted to match the prediction. The measurement is recorded as a comment on the PyPI check (its floor discriminates the zero-byte 401, not a refusal) and on the Helm check (whose `index.yaml` IS gated, the opposite result). The `ANONYMOUS-PULL-PYPI-SIZE` failure message was reworded so it does not claim to discriminate a 192-byte EULA refusal it can never see.
- **Files modified:** `repos/security-platform/scripts/nexus-live-smoke.sh`
- **Verification:** the reversion-2 output above; the final full green run after the reword, byte-verified against the committed file.
- **Committed in:** `07c74e2`

**2. [Rule 3 - Blocking] The plan's live check count is arithmetically incompatible with its own three-way split requirement**

- **Found during:** Task 2
- **Issue:** the plan requires three separate verdicts per ecosystem ("reported as three separate verdicts exactly like section 5's split") and, in Task 3, `<N>` "three higher than plan 24-01's recorded count" — i.e. 16. Those cannot both hold: 13 minus the removed `ANONYMOUS-PULL-DENIED` plus nine new verdicts is 21. One verdict per ecosystem would give 15 and would also make reversion 2 unobservable, because a single `if/elif` chain stops at the status and never evaluates SIZE — destroying the evidence Task 3 demands.
- **Fix:** the three-way split was implemented and the count criterion recorded as planner arithmetic corrected by measurement. Observed: **21 live checks, 0 skipped** (17 in the docker tier, 4 in the kind tier). Naming is `ANONYMOUS-PULL-{ALLOWED,PYPI,HELM}-{TRANSPORT,HTTP-200,SIZE}`, so the three names the plan's acceptance criteria grep for all appear, each with both a status and a byte-count assertion.
- **Files modified:** `repos/security-platform/scripts/nexus-live-smoke.sh`
- **Verification:** `ALL PASS - 21 live check(s) executed and passed; 0 sub-check(s) skipped`.
- **Committed in:** `07c74e2`

**3. [Rule 2 - Missing Critical] The `provision.sh` environment-contract hard-failure sentence did not name the two new variables**

- **Found during:** Task 1
- **Issue:** the header sentence enumerates which unset variables are a hard failure under `set -u`. Adding `READY_ATTEMPTS` / `READY_INTERVAL` to the variable list without adding them to that sentence would leave the file's own contract lying about its own behaviour — and the behaviour is now a real Job failure mode, since deleting the env entry from the template no longer falls back to 60/10.
- **Fix:** the sentence now reads "… ANONYMOUS_REALM_NAME, READY_ATTEMPTS or READY_INTERVAL is a hard failure under `set -u`".
- **Files modified:** `repos/security-platform/kubernetes/nexus/files/provision.sh`
- **Verification:** read back in the committed file; the short-poll run confirms the variables are genuinely consumed.
- **Committed in:** `07c74e2`

---

**Total deviations:** 3 auto-fixed (1 bug, 1 blocking, 1 missing critical)
**Impact on plan:** deviation 1 is the plan's most informative outcome and is a correction to the plan made from a measurement, not a shortcut around it. Deviation 2 changes a reported number, not a behaviour. No file outside `files_modified` was touched; no scope creep.

## Issues Encountered

None that blocked.

Worth handing forward: the two reversion runs and the measurement run were executed with `kind` and `kubectl` removed from `PATH` (a symlink shim containing only `bash helm yq jq docker`), so section 6 reported its named SKIP and the run finished in ~3 minutes instead of ~10. That is a legitimate use of the script's own soft tier — the skip is named, counted separately and never reads as a pass — and it is how a future plan can iterate on the docker half cheaply. **The runs recorded as green were not run that way**: both used the full `PATH` and reported 0 skipped.

## Threat Flags

None. The surface this plan adds is exactly what `<threat_model>` enumerates, and both `mitigate` dispositions are implemented and observed:

- **T-24-08** (live gate false pass) — a byte floor on every anonymous fetch, the three-way transport/status/size split, and both a 192-byte 403 and a zero-byte 401 observed failing the SIZE verdict. The one place the floor cannot discriminate a 403 is documented at the check rather than glossed over.
- **T-24-10** (consumer-set readiness budget) — `provision.activeDeadlineSeconds` remains the hard ceiling and the relationship is stated in `values.yaml` at the knob itself.
- **T-24-09** (anonymous read scope) and **T-24-11** (plaintext HTTP on loopback) are `accept` dispositions, unchanged by this plan.

## Requirements

`requirements-completed: []` — **NEXUS-02 is deliberately NOT marked complete here.** The frontmatter of `24-02-PLAN.md` carries it and the plan's own Task 3 withholds it: it is marked in plan 24-10, after the work is merged to `origin/main`. This follows the 17-01 precedent (where `requirements mark-complete` flipped CICD-02/03 from plan frontmatter and had to be reverted) and the 23-01/23-03/23-05/24-01 withholding pattern. An empty list here is intentional, not a missed step.

## Next Phase Readiness

Ready for plan 24-05 (Docker), which owns the fourth ecosystem and must not reuse the `HOST/repository/<repo>/...` shape this plan uses. `DockerToken` is active unconditionally after any provisioning run at either anonymous posture (24-01), and this plan's two provisioning passes confirmed it again: pass 1 "appended DockerToken (HTTP 204)", pass 2 "already active — no change, and no request was made".

Inputs for later plans in this phase:

- **24-07 / 24-08:** a PyPI `/simple/<project>/` HTTP 200 is not evidence of an accepted EULA. Use a component download.
- **24-08:** `kubernetes/nexus/README.md` still carries the "present but not read" row for `provision.readiness.*`. That row is now false and 24-08 owns the edit — this plan deliberately left the README alone.
- **24-09:** the ADR can now cite measured numbers rather than intentions for both NEXUS-02 and the readiness knobs.
- **Phase 23 `deferred-items.md` item 2** is resolved in the "wire them through" direction; the tracking file itself was not edited here (it lives in this documentation repository and is outside this plan's `files_modified`).

Not done here and not in scope: no Docker anonymous check, no README or ADR text, and no anonymous WRITE probe — `ANONYMOUS-WRITE-DENIED` is plan 24-05's (24-W0-08).

---
*Phase: 24-nexus-anonymous-access-and-workstation-script*
*Completed: 2026-09-19*

## Self-Check: PASSED

All four `files_modified` paths exist on disk; `24-02-SUMMARY.md` exists; commit `07c74e2` is
present in `repos/security-platform` (`git log --oneline --all`). `nexus-live-smoke.sh` is 650 lines
and `provision.sh` is 385 lines, both verified by `wc -l` after the line counts in this document were
corrected from a first-draft estimate.
