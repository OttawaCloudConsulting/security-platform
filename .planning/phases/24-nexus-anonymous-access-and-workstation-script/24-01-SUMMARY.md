---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 01
subsystem: infra
tags: [nexus, helm, kubernetes, rest-api, anonymous-access, docker-registry, bash, offline-gate]

# Dependency graph
requires:
  - phase: 23-nexus-generic-chart
    provides: "kubernetes/nexus wrapper chart, files/provision.sh with its HTTP helpers and exit contract, scripts/check-nexus-chart.sh (17 checks), scripts/nexus-live-smoke.sh (13 live checks)"
provides:
  - "Top-level consumer-facing `anonymous:` value block in kubernetes/nexus/values.yaml, shipped closed (enabled: false)"
  - "ANONYMOUS_ENABLED / ANONYMOUS_USER_ID / ANONYMOUS_REALM_NAME wired from values.yaml into the provisioning Job env"
  - "provision.sh steps 3 (anonymous PUT, 200) and 4 (DockerToken realm, guarded append, 204), both unconditional and idempotent"
  - "check-nexus-chart.sh ANONYMOUS-VALUE-PRESENT (wiring proof) and ANONYMOUS-DEFAULT (shipped-default proof); CHECK_COUNT 17 -> 18"
  - "run_provision() in nexus-live-smoke.sh carries the three ANONYMOUS_* variables at false, keeping ANONYMOUS-PULL-DENIED valid at this commit"
affects: [24-02, 24-05, 24-10, phase-25-nexus-live-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Declarative (unconditional) REST PUT for configuration state, versus the guarded shape reserved for legal acts like the EULA"
    - "GET-then-append-if-absent with both sides normalised through `jq -c` before `cmp -s`"
    - "Gate checks that prove WIRING by toggling a value across two renders (PASSTHROUGH-SIZE shape), not by reading a values key back"

key-files:
  created: []
  modified:
    - repos/security-platform/kubernetes/nexus/values.yaml
    - repos/security-platform/kubernetes/nexus/templates/job-provision.yaml
    - repos/security-platform/kubernetes/nexus/files/provision.sh
    - repos/security-platform/scripts/check-nexus-chart.sh
    - repos/security-platform/scripts/nexus-live-smoke.sh

key-decisions:
  - "The plan's literal `cmp -s <current> <new>` was corrected from measurement: Nexus returns the active-realms array padded (`[ \"NexusAuthenticatingRealm\" ]`, 30 bytes, no trailing newline) while `jq -c` emits 28 bytes plus a newline, so the raw comparison differs on every run. Both sides are normalised through `jq -c` first, otherwise the no-change branch is dead code and the PUT is re-issued on every helm upgrade."
  - "Both new provisioning steps are UNCONDITIONAL. The anonymous PUT must be able to CLOSE access a previous install or a human opened; the DockerToken realm governs Docker bearer-token validation generally (an ADMIN-issued token is also rejected 401 without it), so gating it on ANONYMOUS_ENABLED would break docker-proxy at the shipped default."
  - "values.yaml ships `anonymous.enabled: false` per the locked 24-CONTEXT.md decision, overturning RESEARCH Pattern 2's recommended `true` (Assumption A1)."
  - "run_provision() takes ANONYMOUS_ENABLED=false deliberately so ANONYMOUS-PULL-DENIED stays valid and PASSING at this commit; plan 24-02 owns the flip and the inversion, and the file says so."
  - "NEXUS-02 deliberately NOT marked complete (requirements-completed: []), following the 17-01 reverted-mark precedent and 23-01/23-03/23-05's withholding; plan 24-10 marks it after the work is on origin/main."

patterns-established:
  - "Pattern: a configuration REST call is made on every run so the value is declarative in both directions; only a legal act gets a consumer-opt-in guard."
  - "Pattern: a new gate check is proven non-vacuous by mutating its subject and recording the observed FAIL text, then reverting and re-running."
  - "Pattern: the literal check count moves in three places (header sentence, echo, CHECK_COUNT) in the same commit as the check that changed it."

requirements-completed: []  # NEXUS-02 withheld on purpose — see key-decisions; plan 24-10 marks it.

# Metrics
duration: ~30min
completed: 2026-09-19
---

# Phase 24 Plan 01: Anonymous Access Value and Server-Side Wiring Summary

**A wrapper-owned `anonymous.enabled` value shipped closed, wired end to end into the Nexus security REST API (anonymous PUT 200 + guarded DockerToken realm append 204), with the Phase 23 offline gate inverted from asserting the negation to asserting the wiring — 18 checks green and the live gate still green in the same commit.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-09-19T20:53Z
- **Completed:** 2026-09-19T21:25Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- `anonymous:` is now a first-class, documented, top-level chart value shipping `enabled: false`, with the `nx-anonymous` wildcard scope, the `GET /v1/repositories` inventory disclosure and the CE 40,000-component / 100,000-request-per-day ceiling all stated at the value itself.
- The value provably reaches the provisioning Job: a default render emits `ANONYMOUS_ENABLED: "false"`, `--set anonymous.enabled=true` emits `"true"`.
- `provision.sh` gained steps 3 and 4 (the upsert renumbered to 5) and was exercised live in three passes against `sonatype/nexus3:3.96.0-ubi`, proving open, no-change idempotency, and close.
- The offline gate went 17 -> 18 checks with the anonymous slot rewritten rather than deleted; both new checks were proven non-vacuous by observed failure.
- Both standing gates are green at HEAD (`PASS - 18 checks, 0 failures`; `ALL PASS - 13 live check(s), 0 skipped`), with no intermediate red-gate commit.

## Task Commits

Tasks 1-3 land in a single commit by plan design (the 15-03 precedent): a commit that lands the anonymous call while check 8 still asserts its negation would be a red gate in git history for no reason.

1. **Tasks 1-3 (values + Job env + provision.sh + both gate scripts)** — `1266279` (feat) in `OttawaCloudConsulting/security-platform`, branch `feature/phase-24-nexus-anonymous-and-workstation` (cut from `main` at `ea2770f`)

`git diff-tree --no-commit-id --name-only -r 1266279` lists exactly the five `files_modified` paths and nothing else.

## Files Created/Modified

- `repos/security-platform/kubernetes/nexus/values.yaml` — new top-level `anonymous:` block (`enabled: false`, `userId: anonymous`, `realmName: NexusAuthorizingRealm`); the superseded closing paragraph of the `nexus3.config:` comment replaced with a pointer to the new block and a do-not-put-it-back warning; header value-tree list now names `anonymous`.
- `repos/security-platform/kubernetes/nexus/templates/job-provision.yaml` — three `ANONYMOUS_*` env entries after `EULA_ACCEPTED`, all `| quote`, with the reason the quoting is load-bearing.
- `repos/security-platform/kubernetes/nexus/files/provision.sh` — environment contract and exit contract extended; step 3 (anonymous PUT) and step 4 (DockerToken realm) added; the repository upsert renumbered to step 5. 253 -> 371 lines.
- `repos/security-platform/scripts/check-nexus-chart.sh` — check 8 rewritten as `ANONYMOUS-VALUE-PRESENT`; new check 18 `ANONYMOUS-DEFAULT`; `CHECK_COUNT=18` plus both header/echo literals.
- `repos/security-platform/scripts/nexus-live-smoke.sh` — `run_provision()` carries the three `ANONYMOUS_*` variables at `false`, with the hand-off to plan 24-02 written in the file.

## Measured Evidence

### Baseline, fresh instance, before any provisioning

```
GET /service/rest/v1/security/anonymous      -> 200
{
  "enabled" : false,
  "userId" : "anonymous",
  "realmName" : "NexusAuthorizingRealm"
}

GET /service/rest/v1/security/realms/active  -> 200
raw body (od -c): [   "   N e x u s A u t h e n t i c a t i n g R e a l m   "       ]
                  = `[ "NexusAuthenticatingRealm" ]`, 30 bytes, NO trailing newline
jq -c form:       `["NexusAuthenticatingRealm"]`, 28 bytes + newline
cmp of the two:   DIFFERENT
```

That last line is the measurement behind this plan's one deviation (below).

### Pass 1 — `ANONYMOUS_ENABLED=true` (exit 0)

```
anonymous: OPEN (HTTP 200) — unauthenticated READ is now allowed across every repository on this
  instance, as user 'anonymous' via realm 'NexusAuthorizingRealm'. Idempotent: a re-run returns 200 again.
realms: appended DockerToken (HTTP 204). Every realm that was already active is preserved:
  ["NexusAuthenticatingRealm","DockerToken"]
```

Read back after pass 1:

```
GET /security/anonymous       -> { "enabled" : true, "userId" : "anonymous", "realmName" : "NexusAuthorizingRealm" }
GET /security/realms/active   -> [ "NexusAuthenticatingRealm", "DockerToken" ]
DockerToken occurrences        -> 1
```

### Pass 2 — identical invocation (exit 0)

```
anonymous: OPEN (HTTP 200) — ... Idempotent: a re-run returns 200 again.
realms: DockerToken already active — no change, and no request was made.
```

Read back after pass 2:

```
GET /security/anonymous       -> { "enabled" : true, "userId" : "anonymous", "realmName" : "NexusAuthorizingRealm" }
GET /security/realms/active   -> [ "NexusAuthenticatingRealm", "DockerToken" ]
{ "dockertoken_count": 1, "authenticating_present": 1, "list_length": 2 }
```

`DockerToken` exactly once and `NexusAuthenticatingRealm` still present after BOTH passes; pass 2 took the no-change branch and issued no request. T-24-01 and T-24-02 close by observation.

### Pass 3 — the CLOSE path, beyond the plan's acceptance criteria

`ANONYMOUS_ENABLED=false` run against the instance pass 1/2 had left OPEN:

```
anonymous: CLOSED (HTTP 200) — anonymous read is disabled and every unauthenticated fetch returns HTTP 401.
realms: DockerToken already active — no change, and no request was made.

GET /security/anonymous      -> { "enabled" : false, ... }
GET /security/realms/active  -> [ "NexusAuthenticatingRealm", "DockerToken" ]
```

This is what the unconditional design buys, measured rather than argued: the value closes as well as it opens, and the realm survives independently of it (the decoupling in the comment is now observed, not asserted).

### Non-vacuity of both new offline checks

**Mutation 1 — `anonymous.enabled: true` in values.yaml.** Two checks fire, which is correct: `ANONYMOUS-DEFAULT` reads the shipped default, and `ANONYMOUS-VALUE-PRESENT`'s default-render half reads the value the render now carries.

```
FAIL: ANONYMOUS-VALUE-PRESENT: expected the Job env ANONYMOUS_ENABLED to be 'false' on a DEFAULT render
  — the toggle has to change the render or the value is inert — got 'true' (an empty value means the env
  entry is missing entirely)
FAIL: ANONYMOUS-DEFAULT: expected .anonymous.enabled == false in kubernetes/nexus/values.yaml (the locked
  opt-in default, 24-CONTEXT.md), got 'true'
FAILED - 2 check(s)   exit=1
```

**Mutation 2 — the `ANONYMOUS_ENABLED` env entry deleted from job-provision.yaml.** Only `ANONYMOUS-VALUE-PRESENT` fires, both halves, with an empty observed value:

```
FAIL: ANONYMOUS-VALUE-PRESENT: expected the Job env ANONYMOUS_ENABLED to be 'true' when
  anonymous.enabled=true, got '' (an empty value means the env entry is missing entirely)
FAIL: ANONYMOUS-VALUE-PRESENT: expected the Job env ANONYMOUS_ENABLED to be 'false' on a DEFAULT render
  — the toggle has to change the render or the value is inert — got '' (an empty value means the env
  entry is missing entirely)
FAILED - 2 check(s)   exit=1
```

Worth recording: under mutation 2 a plain `grep -c 'ANONYMOUS_ENABLED'` on the render still returned **7**, because `configmap-provision-script.yaml` embeds `provision.sh`, which names the variable. A grep-based check would have passed with the wiring deleted. Reading the Job's env through `yq` is what discriminates.

Both mutations reverted; re-run: `PASS - 18 checks, 0 failures`.

### Standing gates at HEAD

```
bash scripts/check-nexus-chart.sh
  check-nexus-chart: asserting 18 offline invariants against kubernetes/nexus
  PASS - 18 checks, 0 failures

bash scripts/nexus-live-smoke.sh
  ALL PASS - 13 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).
  ... ANONYMOUS-PULL-DENIED: PASS - unauthenticated GET returned HTTP 401 - anonymous pull is closed
  ... KIND-JOB-COMPLETE: exit=0
```

The smoke's kind half ran to completion, so both new steps executed **inside the real `alpine/k8s:1.31.2` Job image with the template's own env wiring** — that is where a missing `cmp`/`jq` or a `set -u` slip would have surfaced. (`cmp` and `jq` confirmed present in that image separately: `/usr/bin/cmp`, `/usr/bin/jq`.) The smoke's own docker half independently reproduced the two-pass realms behaviour: pass 1 "appended DockerToken (HTTP 204)", pass 2 "already active — no change".

`pre-commit run --files <the five>` exits 0 (shellcheck and yamllint both Passed); `provision.sh` is not executable; commit hooks ran normally, no `--no-verify`.

## Decisions Made

See `key-decisions` in the frontmatter. The load-bearing one is the `jq -c` normalisation, which is a correction to the plan's own code snippet made from a measurement rather than from taste.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's `cmp -s "<cur>" "<new>"` compares a pretty-printed body against compact JSON**

- **Found during:** Task 2 (the two REST calls in provision.sh)
- **Issue:** `24-01-PLAN.md` and `24-RESEARCH.md` Pattern 1 Step B both specify `cmp -s "${realms_cur}" "${realms_new}"`, where `realms_cur` is the raw `GET /security/realms/active` body and `realms_new` is `jq -c` output. Measured on a live `sonatype/nexus3:3.96.0-ubi`: the GET body is `[ "NexusAuthenticatingRealm" ]` — 30 bytes, padded inside the brackets, no trailing newline — while `jq -c` produces the 28-byte compact form plus a newline. `cmp` reports DIFFERENT even when the content is identical. The consequence is not corruption (the `if index("DockerToken")` guard still prevents duplicates) but the "no request at all" property is lost: the PUT would be re-issued on every `helm upgrade` forever, the "already active — no change" branch would be dead code, and Task 2's own acceptance criterion (iii) would be unsatisfiable.
- **Fix:** the current list is normalised through `jq -c '.'` into `realms_norm` and the comparison is `cmp -s "${realms_norm}" "${realms_new}"`. The plan's mandated `cmp -s` construct and the `if index("DockerToken")` guard are both preserved verbatim. The comment above it records the measured byte counts so the next reader does not "simplify" it back.
- **Files modified:** `repos/security-platform/kubernetes/nexus/files/provision.sh`
- **Verification:** pass 2 and pass 3 of the live exercise both logged `realms: DockerToken already active — no change, and no request was made.`, and the smoke's own docker half reproduced it independently.
- **Committed in:** `1266279`

**2. [Rule 2 - Missing Critical] `values.yaml` header value-tree list did not name the new block**

- **Found during:** Task 1
- **Issue:** the file header enumerates which trees are wrapper-owned (`eula / provision / repos`). Leaving `anonymous` out of that list would make the file's own map wrong the moment the block landed.
- **Fix:** the list now reads `eula / anonymous / provision / repos`.
- **Files modified:** `repos/security-platform/kubernetes/nexus/values.yaml`
- **Verification:** read back in the committed file.
- **Committed in:** `1266279`

**3. [Rule 3 - Blocking] The plan's two check-count criteria were unsatisfiable as written against the file's actual state**

- **Found during:** Task 3
- **Issue:** the plan asserts `grep -c '18 offline invariants'` is 2 ("header + echo"), but the pre-existing file carried `17 offline invariants` exactly ONCE (the echo at line 78); its header literal was `PASS - 17 checks, 0 failures`, a different string. Updating only what existed would have produced a count of 1.
- **Fix:** the header now carries one sentence stating the count — "It asserts 18 offline invariants. That count is a literal in three places which must move together…" — and the `PASS - 17 checks` header literal was updated to `PASS - 18 checks` as well, since it is the other literal consumer. Result: `grep -c '18 offline invariants'` is 2, `grep -c '17 offline invariants'` is 0, `CHECK_COUNT=18`.
- **Files modified:** `repos/security-platform/scripts/check-nexus-chart.sh`
- **Verification:** the greps above, plus the gate's own stdout.
- **Committed in:** `1266279`

**4. [Rule 3 - Blocking] The replacement check-8 comment could not name its predecessor verbatim**

- **Found during:** Task 3
- **Issue:** the natural Chesterton's-fence sentence ("This check was ANONYMOUS-NOT-OPENED…") reintroduces the literal `ANONYMOUS-NOT-OPENED`, which the plan's own acceptance criterion requires to be absent (`grep -c` must be 0). A first draft did exactly that and was caught by the criterion. The same draft also line-wrapped `a gate that is not a gate` across two comment lines, dropping its grep count to 0.
- **Fix:** the comment now says "This slot used to assert the NEGATION of NEXUS-02 — that the chart shipped no anonymous-access configuration at all", and the preserved lesson sits on one line. Counts: `ANONYMOUS-NOT-OPENED` 0, `a gate that is not a gate` 1.
- **Files modified:** `repos/security-platform/scripts/check-nexus-chart.sh`
- **Verification:** the two greps, re-run after the edit.
- **Committed in:** `1266279`

---

**Total deviations:** 4 auto-fixed (1 bug, 1 missing critical, 2 blocking)
**Impact on plan:** Deviation 1 is a genuine correctness fix to the plan's published snippet, caught by measurement before it shipped. The other three are conformance fixes to the plan's own acceptance criteria. No scope creep; no file outside `files_modified` was touched.

## Issues Encountered

None that blocked. Worth handing forward: RESEARCH Pattern 2 ships `anonymous.enabled: true` and contains a sentence tying the DockerToken realm to that value ("Setting this true also appends the DockerToken realm…"). Both are superseded — by the locked CONTEXT.md decision and by the unconditional realm step respectively — and neither was carried into the chart. A future reader going back to RESEARCH Pattern 2 for the comment text will find the stale version.

## Threat Flags

None. The surface this plan adds — two admin-credentialed REST calls from the provisioning Job and three consumer-controlled strings crossing into a shell environment — is exactly the surface `<threat_model>` enumerates (T-24-01 through T-24-07), and every disposition in it is `mitigate` and implemented: guarded append with `NexusAuthenticatingRealm` preserved by construction (T-24-01/T-24-02, observed over three passes), no role or privilege created or edited (T-24-03), default closed with a gate on it (T-24-04), `jq --arg`/`--argjson` only with no string concatenation into JSON (T-24-05), `NEXUS_PASSWORD` never echoed (T-24-06), and all three check-count literals moved in one commit with both new checks proven non-vacuous (T-24-07).

## Requirements

`requirements-completed: []` — **NEXUS-02 is deliberately NOT marked complete here.** The frontmatter of `24-01-PLAN.md` carries it, but the plan's own Task 3 acceptance criteria withhold it: the requirement is marked in plan 24-10, after the work is merged to `origin/main`. This follows the 17-01 precedent (where `requirements mark-complete` flipped CICD-02/03 from plan frontmatter and had to be reverted) and the 23-01/23-03/23-05/23-06/23-07 withholding pattern. An empty list here is intentional, not a missed step.

## Next Phase Readiness

Ready for plan 24-02, which owns:

- flipping `run_provision()`'s `ANONYMOUS_ENABLED` to `true` and inverting `ANONYMOUS-PULL-DENIED` into `ANONYMOUS-PULL-ALLOWED` **in the same commit** (the hand-off note naming 24-02 is already in `nexus-live-smoke.sh`), plus `ANONYMOUS-PULL-PYPI` / `ANONYMOUS-PULL-HELM`;
- wiring `provision.readiness.*` (still inert, carried from Phase 23) into the Job env, which the smoke's `run_provision()` will also need under `set -u`.

Plan 24-05's Docker checks can rely on `DockerToken` being active unconditionally after any provisioning run, at either anonymous posture. Plan 24-03 shares this branch; both commits are on `feature/phase-24-nexus-anonymous-and-workstation` and neither pushes — plan 24-10 owns the PR.

Not done here and not in scope: no chart README or ADR text was updated (`kubernetes/nexus/README.md` still describes the Phase 23 posture), and no live anonymous fetch was attempted — plan 24-02's gate is where the 401 becomes a 200.

---
*Phase: 24-nexus-anonymous-access-and-workstation-script*
*Completed: 2026-09-19*

## Self-Check: PASSED

All five `files_modified` paths exist on disk; `24-01-SUMMARY.md` exists; commit `1266279` is
present in `repos/security-platform` (`git log --oneline --all`). `provision.sh` is 371 lines
(min_lines 290 satisfied); `check-nexus-chart.sh` is 403 lines with `CHECK_COUNT=18`.
