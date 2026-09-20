---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 05
subsystem: infra
tags: [nexus, docker, oci-registry, bearer-token, live-gate, anonymous-access, realms, authorization]

# Dependency graph
requires:
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 02
    provides: "run_provision() on the anonymous-ENABLED path; the two-pass PROVISION-PASS-1/2 harness; the three-verdict anonymous block in section 5; live gate at 21 checks"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 01
    provides: "provision.sh step 4 — the guarded GET->append->PUT of the active realms list that appends DockerToken exactly once"
provides:
  - "ANONYMOUS-PULL-DOCKER — the full five-leg anonymous Docker client handshake, measured: /v2/ 401 + Bearer challenge -> token -> manifest index 200 WITH Authorization: Bearer -> linux/amd64 layer blob 3,626,020 bytes"
  - "DOCKER-REALM-ACTIVE — active realms read back after two provisioning passes: DockerToken present exactly once AND NexusAuthenticatingRealm still present"
  - "DOCKER-PATH-SHAPE — /v2/<repo>/... is 200 and /v2/repository/<repo>/... is 404, both unauthenticated"
  - "ANONYMOUS-WRITE-DENIED — unauthenticated POST of a structurally valid npm proxy body is exactly 403, creates nothing, and the non-creation instrument is itself proven by a 200 on an existing repository"
  - "Live gate count 21 -> 25 checks, 0 skipped"
  - "Measured non-vacuity: removing DockerToken turns DOCKER-REALM-ACTIVE and ANONYMOUS-PULL-DOCKER (leg 4, HTTP 401) red while legs 1-3 and DOCKER-PATH-SHAPE stay green"
affects: [24-07, 24-08, 24-09, 24-10, phase-25-nexus-live-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A protocol check emits ONE pass and many distinct fails: ordered legs return at the first red leg instead of reporting a cascade of derived failures that share one cause"
    - "Challenge values (realm, service) are PARSED from the server's own WWW-Authenticate header, never hardcoded to the values research happened to observe"
    - "A negative assertion needs its instrument proven: the admin GET that returns 404 for a name that was never created is first exercised against a name that DOES exist and must return 200"
    - "A correction that review caught is written into the source file at the point it matters, not only into the research document"

key-files:
  created: []
  modified:
    - repos/security-platform/scripts/nexus-live-smoke.sh

key-decisions:
  - "ONE `pass` per check in the new section, deliberately NOT section 5's three-verdicts-per-ecosystem split. Section 5's ecosystems are single independent fetches, so splitting transport/status/size makes three failures distinguishable. Section 6's checks are SEQUENCES — a token that could not be obtained cannot be presented — so a split would print four derived failures with one cause. The plan's own count criterion (exactly four higher than 24-02's 21) is only satisfiable this way, and it was satisfied exactly: 25."
  - "The blob floor is 1,000,000, derived from the layer blob THIS check measured (3,626,020 bytes) under the file's existing two rules (>= 10x a 192-byte refusal; <= half the measured size). It is explicitly NOT derived from the 8,083,968-byte `crane export` figure in 24-RESEARCH.md: that number is the whole filesystem across every layer and this leg fetches one blob. The comment says so, so nobody later 'corrects' the floor toward the bigger number."
  - "Leg 5 selects the linux/amd64 child manifest BY PLATFORM, not by array position. The proxy serves the full upstream index regardless of the host architecture the smoke runs on, so the choice is workstation-independent, and selecting by platform also skips the attestation entries whose platform is unknown/unknown."
  - "ANONYMOUS-WRITE-DENIED carries a THIRD assertion the plan did not ask for — an admin GET of the EXISTING npm-proxy must return 200 on the same URL shape. Without it the 404 that proves non-creation could be a wrong URL shape returning 404 for everything, which is Pitfall 5's failure mode moved from the POST to the GET. Logged as a Rule 2 deviation."
  - "Tasks 1-3 land in ONE commit by plan design (the 24-01 / 24-02 / 15-03 precedent). Task 3's own acceptance criterion reads `git diff-tree` on 'this plan's commit', singular."
  - "NEXUS-02 deliberately NOT marked complete (requirements-completed: []), continuing the 17-01 reverted-mark precedent and the 23-01/24-01/24-02 withholding; plan 24-10 marks it after the work is on origin/main."

patterns-established:
  - "Pattern: when a check's later legs depend on its earlier ones, a FUNCTION with early `return` is the correct shape — it keeps every failure message specific to the leg that produced it while guaranteeing at most one pass for the check's name."
  - "Pattern: a gate can carry the record of the wrong test as well as the right one. The header-less manifest GET returns 200 with the realm removed; that fact is written into the file as the thing that must never be accepted as evidence, so a future simplification has to argue with it."

requirements-completed: []  # NEXUS-02 withheld on purpose — see key-decisions; plan 24-10 marks it.

# Metrics
duration: ~50min
completed: 2026-09-19
---

# Phase 24 Plan 05: The Anonymous Docker Handshake, Proven Live Summary

**The Docker half of NEXUS-02 is now measured the way a real client experiences it — ping, challenge, token, and a bearer-carrying manifest and blob — and the check is proven to go red exactly where a header-less test would have stayed green.**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-09-20T02:35Z
- **Completed:** 2026-09-20T03:25Z
- **Tasks:** 3 (one commit by plan design)
- **Files modified:** 1
- **Live smoke runs:** 3 (A measurement + admin control, B realm-removal reversion, C full green)

## Accomplishments

- Anonymous Docker pull is **measured through the protocol a client actually speaks**, not through a request no client emits: five ordered legs, `Authorization: Bearer` on both the manifest and the blob, and a real 3.6 MB image layer streamed with no credential anywhere in the sequence.
- The realm that makes it possible is read back **after two provisioning passes** and asserted three ways — present, present exactly once, and not having taken `NexusAuthenticatingRealm` down with it.
- The documented Docker pull path is proven to be the one that works, **and the one that looks right by analogy is proven to 404**.
- Anonymous read is proven **not** to extend to write, with the Pitfall 5 trap closed on both the request body and the instrument that proves non-creation.
- The live gate went **21 -> 25 checks, 0 skipped**, `ALL PASS`, kind half included.
- The research correction that review caught is now **in the source file**, phrased so that a later "simplification" back to a header-less test has to overwrite an explicit warning.

## Task Commits

Tasks 1-3 land in a single commit by plan design (the 24-01 / 24-02 / 15-03 precedent): Task 3's own acceptance criterion requires `git diff-tree` on *this plan's commit*, singular, and an intermediate commit would have put four never-executed live checks into git history with nothing measured behind them.

1. **Tasks 1-3** — `9b670c4` (test) in `OttawaCloudConsulting/security-platform`, branch `feature/phase-24-nexus-anonymous-and-workstation`

`git diff-tree --no-commit-id --name-only -r 9b670c496d913a99eedf858eaaeca26a98a6b30c` lists exactly `scripts/nexus-live-smoke.sh` and nothing else. 422 insertions, 3 deletions.

## Files Created/Modified

- `repos/security-platform/scripts/nexus-live-smoke.sh` — new section 6 ("Docker: realms, URL shape, the anonymous handshake and the write boundary") carrying the four checks in state-then-consequence order, plus the kind section renumbered `6 -> 7` and its two in-file cross-references updated (lines 61 and 269). **650 -> 1,069 lines.**

## Measured Evidence

### Run C — the full gate at the committed bytes

```
--- 6. Docker: realms, URL shape, the anonymous handshake and the write boundary ---
==> DOCKER-REALM-ACTIVE: PASS - after two provisioning passes the active realms are ["NexusAuthenticatingRealm","DockerToken"] - DockerToken exactly once, NexusAuthenticatingRealm intact
==> DOCKER-PATH-SHAPE: PASS - /v2/docker-proxy/library/alpine/manifests/3.21 is 200 and /v2/repository/docker-proxy/library/alpine/manifests/3.21 is 404 - the documented Docker reference is the one that routes
==> ANONYMOUS-PULL-DOCKER: PASS - full anonymous client handshake: GET /v2/ -> 401 + Bearer challenge; token minted at http://127.0.0.1:53003/repository/docker-proxy/v2/token with no credential; http://127.0.0.1:53003/v2/docker-proxy/library/alpine/manifests/3.21 -> 200 WITH Authorization: Bearer; linux/amd64 layer sha256:16333ee0c00fc65e025a2a4f839703ad37a74728832977fbdf080984de1b8e5a streamed 3626020 bytes (> 1000000)
==> ANONYMOUS-WRITE-DENIED: PASS - an unauthenticated POST of a structurally valid npm proxy body returned HTTP 403 and created nothing (admin GET of anon-write-probe is 404, while the same URL shape returns 200 for the existing npm-proxy) - anonymous read does not extend to write

--- 7. kind install smoke ---
==> KIND-CLUSTER: PASS - cluster nexus-smoke is up
==> KIND-DEPENDENCY-BUILD: exit=0 (PASS - completed successfully)
==> KIND-INSTALL: exit=0 (PASS - completed successfully)
==> KIND-JOB-COMPLETE: exit=0 (PASS - completed successfully)

=== Summary ===
ALL PASS - 25 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).
```

**Live check count: 21 before this plan (24-02-SUMMARY.md), 25 after — exactly four higher**, one per new named check. Section 5's nine verdicts are unchanged and all still green (npm 318,961 B, PyPI 76,776 B, Helm 291,818 B — identical to 24-02's measurements).

The run recorded as green ran the **exact committed bytes**: `shasum -a 256 scripts/nexus-live-smoke.sh` was `1a478fabf31091e407128b3097bc41133f681e78c0a27ee8ba756c1f911ea99e` before the run, and `diff` against the pre-run snapshot was empty afterwards.

### The realms array

```json
["NexusAuthenticatingRealm","DockerToken"]
```

Read from `GET /service/rest/v1/security/realms/active` with the admin credential, **after both** `PROVISION-PASS-1` and `PROVISION-PASS-2`. `DockerToken` count = 1, `NexusAuthenticatingRealm` count = 1. `provision.sh` logged `realms: DockerToken already active — no change, and no request was made` on pass 2, so the exact-count-of-one assertion is measuring the guard, not an accident of a single run. No third `run_provision` was added — `grep -c 'run_provision'` is **4**, unchanged from 24-02.

### Blob byte count and the chosen floor

| Quantity | Value | Source |
|---|---|---|
| linux/amd64 layer blob `sha256:16333ee0…b8e5a` | **3,626,020 B** | measured by leg 5 in every run |
| Floor asserted | **1,000,000** | `>= 10 x 192 = 1,920` ✓ ; `<= half of 3,626,020 = 1,813,010` ✓ |
| `crane export` of the whole image (24-RESEARCH.md) | 8,083,968 B | **deliberately not used** — that is every layer's filesystem, not one blob |

Reproduced identically in run A and run C (3,626,020 both times), and identical to 24-RESEARCH.md Code Example 4's `size=3626020`.

### Reversion — DockerToken removed (run B)

`PUT ["NexusAuthenticatingRealm"]` inserted immediately after `PROVISION-PASS-2`, everything else the committed bytes:

```
### TEMP REVERSION (run B only, not committed): PUT realms back to [NexusAuthenticatingRealm] ###
### realms PUT: 204
### realms readback: ["NexusAuthenticatingRealm"]

--- 6. Docker: realms, URL shape, the anonymous handshake and the write boundary ---
==> DOCKER-REALM-ACTIVE: FAIL - DockerToken is ABSENT from the active realms ["NexusAuthenticatingRealm"]; provision.sh did not append it, so no bearer token this instance issues will validate and anonymous docker pull cannot work
==> DOCKER-PATH-SHAPE: PASS - /v2/docker-proxy/library/alpine/manifests/3.21 is 200 and /v2/repository/docker-proxy/library/alpine/manifests/3.21 is 404 - the documented Docker reference is the one that routes
==> ANONYMOUS-PULL-DOCKER: FAIL - leg 4: http://127.0.0.1:52926/v2/docker-proxy/library/alpine/manifests/3.21 with 'Authorization: Bearer' returned HTTP 401, expected 200; a 401 here with legs 1-3 green means the DockerToken realm is not active, since the challenge and the token are unaffected by it and only the presented token fails to validate
==> ANONYMOUS-WRITE-DENIED: PASS - ... anonymous read does not extend to write
```

**Exactly the prediction, including the contrast that is the whole point of the check.** The leg-by-leg probe run alongside it, against the same realm-stripped instance:

```
### leg 1 GET /v2/ : 401 ; WWW-Authenticate: Bearer realm="http://127.0.0.1:52926/repository/docker-proxy/v2/token",service="http://127.0.0.1:52926/repository/docker-proxy/v2/token"
### leg 3 token : 200 ; token length 49
### leg 4 manifest WITH bearer : 401
### leg 4 manifest WITHOUT any header : 200  <- the wrong test; 200 proves nothing
```

That last line is the whole reason this plan exists, reproduced live: **with the realm removed, the header-less manifest request still returns 200.** A gate written that way would have been green on a server where no Docker client can pull. `ANONYMOUS-PULL-DOCKER` is red on the same server, at leg 4, for the right reason.

`ANONYMOUS-WRITE-DENIED` and `DOCKER-PATH-SHAPE` staying green through the reversion is also evidence: it isolates the failure to bearer-token validation and rules out "the repository disappeared" and "anonymous read closed" as explanations. Run B exited 1.

The realm was not restored in place because the reversion container is torn down by the script's own EXIT trap. Restoration is demonstrated by **run C on a fresh instance**, where `provision.sh` appended `DockerToken` on pass 1, made no request on pass 2, and the whole gate came back green — which is the same claim ("re-run provision.sh and the realm comes back") measured on a clean instance rather than a hand-edited one.

### Admin-credentialed control for the write boundary (run A)

Same request body, same endpoint, the only difference being the credential:

```
### ANON POST observed code: 403
### ANON probe admin GET code: 404
### EXISTING npm repo admin GET code: 200
### ADMIN POST (same body, admin credential): 201
### ADMIN GET after create: 200
### ADMIN DELETE: 204
### ADMIN GET after delete: 404
```

**403 without credentials, 201 with them.** The endpoint is real, the body is structurally valid, and the 403 is therefore about **authorisation** — not about a malformed request, which is what a 400 would have meant (Pitfall 5). The probe repository `anon-write-probe-admin` was deleted (`204`) and its absence confirmed (`404`); no probe repository exists on any surviving instance, and every instance in these runs was a throwaway container torn down by the trap.

### Path shape, both directions

| URL | Credential | Observed | Meaning |
|---|---|---|---|
| `/v2/docker-proxy/library/alpine/manifests/3.21` | none | **200** | the path a real `docker pull HOST/docker-proxy/library/alpine:3.21` constructs |
| `/v2/repository/docker-proxy/library/alpine/manifests/3.21` | none | **404** | the `/repository/` prefix copied from npm/PyPI/Helm by analogy |
| `/repository/docker-proxy/v2/library/alpine/manifests/3.21` | — | 200 (24-RESEARCH.md) | curl/browser-only; **named in the file as never-document** |

The third shape is not asserted — it is *named* in the check's comment as a shape that works but that no client can emit, so it must never appear as a documented pull target. Separately, the comment records that the **token endpoint** the challenge advertises *is* under `/repository/` and is server-advertised, so it is not an instance of this trap and must not be "corrected".

### Standing gates at HEAD (`9b670c4`)

```
bash scripts/check-nexus-chart.sh
  check-nexus-chart: asserting 18 offline invariants against kubernetes/nexus
  PASS - 18 checks, 0 failures

bash scripts/nexus-live-smoke.sh
  ALL PASS - 25 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).

shellcheck scripts/nexus-live-smoke.sh            -> exit 0
pre-commit run --files scripts/nexus-live-smoke.sh -> shellcheck Passed, exit 0
```

Acceptance greps: `DOCKER-REALM-ACTIVE|DOCKER-PATH-SHAPE` → 14; `Authorization: Bearer` → 7; `must never be accepted as evidence` → **1**; `run_provision` → 4 (unchanged); `|| true` → 4, all pre-existing (trap, `KUBECTX_BEFORE`, `find -exec`) and **none inside the new section**.

Environment left clean: `kind get clusters` → "No kind clusters found", kubectl context restored to `admin@occ-new`, no surviving `nexus-live-smoke-*` container. Commit hooks ran normally; no `--no-verify`. Nothing was pushed — plan 24-10 owns the PR.

## Decisions Made

See `key-decisions` in the frontmatter. The load-bearing ones are the one-pass-per-check shape (which is what makes the plan's own count criterion satisfiable and keeps failure messages specific) and the blob floor's derivation from the layer this check measures rather than from the export figure in the research.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] `ANONYMOUS-WRITE-DENIED`'s non-creation proof needed its instrument validated**

- **Found during:** Task 2
- **Issue:** the plan specifies two assertions — anonymous POST is exactly 403, admin GET of the probe name is 404. But a 404 from an admin GET proves "nothing was created" only if that URL shape returns something other than 404 for a repository that *does* exist. `GET /service/rest/v1/repositories/{format}/{type}/{name}` is one of several plausible shapes on this API, and a wrong one would 404 for everything — which is Pitfall 5's failure mode (passing for the wrong reason) moved from the POST to the GET. The plan closes that hole for the request body and leaves it open for the readback.
- **Fix:** a third assertion inside the same check — an admin GET of the chart's own existing npm proxy on the identical URL shape must return **200**. The repository name is read from the rendered body (`jq -r .name "$OUT/config/000-npm.json"`), not hardcoded, so it cannot drift from what the chart provisions. The comment states why the assertion exists. The check still emits exactly one `pass`, so the plan's count criterion is unaffected.
- **Files modified:** `repos/security-platform/scripts/nexus-live-smoke.sh`
- **Verification:** observed `200` for `npm-proxy` and `404` for `anon-write-probe` on the same shape in runs A, B and C; the admin control independently confirmed the shape returns 200 after a create and 404 after a delete.
- **Committed in:** `9b670c4`

**2. [Rule 3 - Blocking] Leg 5 needs one intermediate manifest fetch to resolve a layer digest**

- **Found during:** Task 2
- **Issue:** the plan's leg 5 says "follow one layer or one manifest reference to a blob". `alpine:3.21` resolves to an image **index**, whose entries are manifest references, not layer digests — `/blobs/<manifest-digest>` would fetch a ~1 KB document, far too small to carry a meaningful floor and not an exercise of the layer path at all.
- **Fix:** leg 5 resolves the linux/amd64 child manifest first (a bearer-authenticated GET with the single-manifest `Accept` types), reads `.layers[0].digest` from it, and then fetches that blob. The resolution step carries its own failure messages and is documented as part of leg 5. The check also handles the case where the top document is itself a manifest with `layers`, so it does not depend on the tag always resolving to an index.
- **Files modified:** `repos/security-platform/scripts/nexus-live-smoke.sh`
- **Verification:** leg 5 measured 3,626,020 bytes, identical to 24-RESEARCH.md Code Example 4's `size=3626020` for the same layer digest.
- **Committed in:** `9b670c4`

**3. [Rule 3 - Blocking] The new section is numbered 6 and the kind section moved to 7**

- **Found during:** Task 1
- **Issue:** the plan requires the new checks "after the existing anonymous-pull block" (section 5) in a new numbered section, but section 6 was already the kind install smoke. Appending after kind would have put the Docker evidence after a soft-gated section that calls `print_summary` and exits when `kind` is absent — the Docker checks would silently never run on a workstation without a cluster toolchain.
- **Fix:** the new section is 6, kind is renumbered 7, and the two in-file comments that reference the kind section by number (the trap's ownership-guard pointer at line 61 and the `umask` comment at line 269) were updated with it, so no comment points at the wrong section.
- **Files modified:** `repos/security-platform/scripts/nexus-live-smoke.sh`
- **Verification:** `grep -n 'section [0-9]'` shows both references reading "section 7"; run A confirmed the Docker checks execute and report before the kind skip.
- **Committed in:** `9b670c4`

---

**Total deviations:** 3 auto-fixed (2 blocking, 1 missing critical)
**Impact on plan:** none change what is measured; deviations 1 and 2 make two assertions mean what the plan says they mean. No file outside `files_modified` was touched; no scope creep. **Every prediction the plan published was observed as predicted** — unlike 24-02, this plan's reversion prediction needed no correction.

## Issues Encountered

None that blocked.

Worth handing forward: runs A and B were executed with `kind` and `kubectl` removed from `PATH` (a shim directory plus `/usr/bin:/bin`), so section 7 reported its named SKIP and each run finished in ~3 minutes instead of ~12. That is 24-02's documented technique and a legitimate use of the script's own soft tier — the skip is named, counted separately and never reads as a pass. **The run recorded as green (run C) was not run that way:** full `PATH`, 25 checks, 0 skipped.

One `set -e` hazard worth naming for anyone extending this section: `count="$(jq -e …)"` and `n="$(grep -c …)"` exit the script on a legitimate negative answer instead of reaching `fail`. Every new assertion here uses un-`-e`'d `jq` with a string comparison, `if ! cmd`, or `|| rc=$?` — and adds no `|| true`.

## Threat Flags

None. The surface this plan adds is exactly what `<threat_model>` enumerates, and all five `mitigate` dispositions are implemented and observed:

- **T-24-22** (anonymous POST to the repositories API) — exactly `403` on a structurally valid body, admin GET `404`, a 2xx branch that names privilege escalation explicitly, and the readback instrument itself validated at `200`. Admin control: `201`.
- **T-24-23** (header-less manifest read as proof) — five legs, `Authorization: Bearer` on the manifest and the blob, and the failure mode recorded in the file (`grep -c 'must never be accepted as evidence'` = 1). Observed live: header-less 200 vs bearer 401 on the same realm-stripped instance.
- **T-24-24** (realms list losing `NexusAuthenticatingRealm`) — asserted present after two provisioning passes, with the lockout consequence in the failure message.
- **T-24-25** (duplicate realms across upgrades) — exact-count-of-one after two consecutive passes; `provision.sh` made no request on pass 2.
- **T-24-26** (a documented pull path that 404s) — both shapes measured, and the curl-only third shape named in the comment as never-document.

## Requirements

`requirements-completed: []` — **NEXUS-02 is deliberately NOT marked complete here.** The frontmatter of `24-05-PLAN.md` carries it and the plan's own Task 3 withholds it: it is marked in plan 24-10, after the work is merged to `origin/main`. This follows the 17-01 precedent and the 23-01/23-03/23-05/24-01/24-02 withholding pattern. An empty list here is intentional, not a missed step.

## Next Phase Readiness

The Docker half of NEXUS-02 is closed in the live gate. Inputs for later plans in this phase:

- **24-07 (workstation script):** the emitted Docker registry string must be `HOST[:PORT]/docker-proxy` with **no** `/repository/` segment. `DOCKER-PATH-SHAPE` now fails the gate if that ever stops being true, so the script and the gate agree by construction rather than by review.
- **24-08 (chart README):** three facts are now measured and quotable — the Docker URL asymmetry against the other three ecosystems, the `DockerToken` realm as the control that makes bearer validation work (**not** `forceBasicAuth`, which 24-RESEARCH.md could not reproduce as the control on 3.96.0), and the write boundary at exactly 403.
- **24-09 (ADR-021):** can cite measured numbers — 3,626,020 bytes anonymously through the proxy, `["NexusAuthenticatingRealm","DockerToken"]`, 403-vs-201 on the same body — and can close ADR-020 §What was NOT verified item 2 with them.
- **Phase 25:** the one residual is unchanged and is not narrowed by this plan — the client here is `curl` speaking the OCI distribution protocol, not `dockerd`. Daemon-specific TLS/insecure-registry handling against a real hostname is still Phase 25's to exercise.

Not done here and not in scope: no README, ADR or workstation-script text; no `requirements mark-complete`; nothing pushed.

---
*Phase: 24-nexus-anonymous-access-and-workstation-script*
*Completed: 2026-09-19*

## Self-Check: PASSED

`repos/security-platform/scripts/nexus-live-smoke.sh` exists on disk at 1,069 lines;
`24-05-SUMMARY.md` exists; commit `9b670c4` is present in `repos/security-platform`
(`git log --oneline --all`) and its `git diff-tree` lists exactly the one `files_modified` path.
