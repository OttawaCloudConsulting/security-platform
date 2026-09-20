---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 04
subsystem: infra
tags: [docker, registry-mirrors, nexus, dind, measurement, assumption-a3, evidence, bash]

# Dependency graph
requires:
  - phase: 24-nexus-anonymous-access-and-workstation-script
    provides: "provision.sh with ANONYMOUS_ENABLED / ANONYMOUS_USER_ID / ANONYMOUS_REALM_NAME and the unconditional DockerToken realm step (plan 24-01); nexus-live-smoke.sh's boot -> extract-repo-bodies -> run_provision sequence, reused verbatim"
provides:
  - "A reproducible, non-destructive Docker-in-Docker probe of registry-mirrors against a path-routed Nexus Docker proxy (24-evidence/a3-dind-probe.sh)"
  - "VERDICT: A3-FALSIFIED-CANDIDATE-1 — a path-routed Nexus proxy CAN be a daemon mirror, at HOST/repository/<repo> and only there"
  - "Version-matched moby v28.3.2 source proof that registry-mirrors is attached to the docker.io index and to no other (the Hub-only half of A3 CONFIRMED)"
  - "The operator's recorded decision (daemon-opt-in, both keys) under a `## Decision` heading in the evidence file, which plan 24-07 reads instead of a chat transcript"
affects: [24-07, 24-09, 24-10, phase-25-nexus-live-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Measure an assumption in a throwaway nested engine rather than on the operator's own, and assert the operator's config byte-identical in the EXIT trap"
    - "Every candidate row gets two CONTROL rows (one that must pass, one that must fail) so no exit code is unattributable"
    - "Score routing on the server-side artefact delta, never on the client's exit code, when the client has a silent fallback path"
    - "Pin a probe's image to the EXACT host version rather than a floating major tag, so 'you measured a different engine' is not available as an objection"

key-files:
  created:
    - .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-evidence/a3-dind-probe.sh
    - .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-evidence/a3-docker-daemon-routing.md
  modified: []

key-decisions:
  - "VERDICT: A3-FALSIFIED-CANDIDATE-1. The /repository/-bearing mirror URL routes (components 0 -> 1, /library/alpine:3.21 appeared); the path-only URL does not (components 0 -> 0 with pull exit 0). Assumption A3's 'requires the mirror at the registry root' half is falsified; its 'only mirrors Docker Hub' half is confirmed from version-matched source."
  - "The /repository/ segment is REQUIRED in the mirror URL and FORBIDDEN in the image reference (24-RESEARCH.md Pattern 6). The intuitive shape is the wrong one, and it fails silently."
  - "Operator selected `daemon-opt-in` with both `registry-mirrors` and `insecure-registries`, matching exactly the pair that was measured. Recorded verbatim in the evidence file under `## Decision`."
  - "Two controls were added to the validation stage beyond the plan's letter: an empty config that must validate, and a query-string mirror that must be rejected. Without them a candidate exit code proves nothing about the candidate."
  - "The probe never writes or restarts the operator's Docker daemon; the workaround for a wedged host credential helper is client-side (throwaway DOCKER_CONFIG), not a repair of the operator's config."

patterns-established:
  - "Pattern: a measurement that could be faked by a fallback path must name the fallback in the script's own comments AND print the 'this is NOT routing' verdict inline when the fallback fires."
  - "Pattern: the cache-clearing step between candidates is asserted (DELETE, then re-read the count and hard-fail if non-zero), never assumed."
  - "Pattern: an operator decision that a later plan depends on is appended to the evidence file, not left in the conversation."

requirements-completed: []  # NEXUS-04 withheld on purpose — plan 24-10 marks it after merge.

# Metrics
duration: ~45min active (~3h10m wall clock, including the blocking operator checkpoint)
completed: 2026-09-19
---

# Phase 24 Plan 04: Measuring Assumption A3 Summary

**A3 is falsified, but only halfway and only at one URL: a Nexus Docker proxy CAN serve as a Docker daemon `registry-mirrors` target at `HOST/repository/docker-proxy` (components 0 → 1), while the intuitive `HOST/docker-proxy` pulls successfully and routes nothing (components 0 → 0, pull exit 0) — and `registry-mirrors` never touches a non-Docker-Hub reference at all, proven from version-matched moby v28.3.2 source.**

## Performance

- **Duration:** ~45 min of execution; ~3h10m wall clock, the difference being the blocking operator checkpoint
- **Started:** 2026-09-19T23:10Z
- **Tasks 1-2 committed:** 2026-09-19T23:50Z / 23:53Z
- **Decision recorded:** 2026-09-20T02:22Z
- **Tasks:** 3 (2 auto, 1 blocking decision checkpoint)
- **Files created:** 2

## Accomplishments

- Assumption A3 is no longer an assumption. It was split into two claims and each was settled by a different kind of evidence: the Hub-only claim from version-matched source, the root-path claim by live measurement.
- The probe is reproducible, self-contained, shellcheck-clean, non-executable, and pinned by digest to the **exact** host engine version.
- The one failure mode that could have faked a positive result — Docker's silent fallback to Docker Hub on any mirror error — was excluded by construction, and then actually fired on candidate-2, where it was caught and scored correctly.
- The operator's Docker daemon was never written and never restarted. Its `daemon.json` checksum is identical before and after every run, asserted by the script itself rather than by a human afterwards.
- A wedged Docker Desktop credential helper on the workstation was diagnosed by bisection and worked around client-side, without repairing or editing the operator's config.
- The operator chose the workstation script's Docker behaviour with the measurement in front of them, and the choice is recorded where plan 24-07 will read it.

## Task Commits

1. **Task 1 (probe script + documentary and validation evidence)** — `79c543f` (test)
2. **Task 2 (routing measurement + verdict + caveats)** — `c39db9b` (docs)
3. **Task 3 (operator decision recorded verbatim + two evidence corrections)** — `ca78608` (docs)

All three are in the parent `security_solution` repository on `feature/phase-12-repo-setup-script`. **Nothing in `repos/security-platform/` was modified** — 24-04-PLAN.md's `<context>` states this explicitly, and `git diff-tree` on each commit lists only paths under `.planning/phases/24-.../24-evidence/`.

## Files Created

- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-evidence/a3-dind-probe.sh` — 526 lines, mode 644, `shellcheck` exit 0. Two stages: `--validate-only` runs `dockerd --validate` per candidate inside a throwaway container; the full run boots Nexus, provisions it with the chart's own `provision.sh`, and measures the components delta per candidate against a freshly created dind engine.
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-evidence/a3-docker-daemon-routing.md` — 353 lines. Documentary reading (§1), validation table (§2), per-candidate routing tables (§3), the single `VERDICT:` line, seven "what this does NOT establish" items, the consequence for 24-07, and the operator's decision verbatim.

## Measured Evidence

### The verdict

```
VERDICT: A3-FALSIFIED-CANDIDATE-1
```

### Validation stage — `dockerd --validate` in `docker:28.3.2-dind`

| Row | Config | Exit | Output |
|-----|--------|------|--------|
| control-empty | `{}` | 0 | `configuration OK` |
| control-query | `{"registry-mirrors":["http://a3-nexus:8081/x?y=1"]}` | 1 | `invalid mirror: query or fragment at end of the URI "http://a3-nexus:8081/x?y=1"` |
| candidate-1 | `…/repository/docker-proxy` + `insecure-registries` | 0 | `configuration OK` |
| candidate-2 | `…/docker-proxy` + `insecure-registries` | 0 | `configuration OK` |

Both candidates parse, so validation did **not** settle A3. The two controls are what make that statement meaningful: control-empty proves the harness runs `dockerd` correctly (a candidate exit 1 would otherwise be unattributable), and control-query proves `--validate` genuinely inspects `registry-mirrors` (a candidate exit 0 would otherwise be vacuous).

### Routing stage — the discriminating measurement

One throwaway Nexus (`sonatype/nexus3:3.96.0-ubi`, resolved from the chart's own rendered StatefulSet, host port 8082), provisioned by `kubernetes/nexus/files/provision.sh` with the four repo bodies extracted from the chart's own `-repos` ConfigMap:

```
EULA: accepted (HTTP 204).
anonymous: OPEN (HTTP 200) ...
realms: appended DockerToken (HTTP 204). ["NexusAuthenticatingRealm","DockerToken"]
repo: format=docker name=docker-proxy action=created (HTTP 201)
Provisioning complete: 4 proxy repositor(ies) present and online.
```

| Candidate | mirror URL | `docker info` `.RegistryConfig.Mirrors` | BEFORE | pull rc | AFTER | appeared |
|-----------|-----------|------------------------------------------|--------|---------|-------|----------|
| **candidate-1** | `http://a3-nexus:8081/repository/docker-proxy` | `["http://a3-nexus:8081/repository/docker-proxy/"]` | **0** | 0 | **1** | `/library/alpine:3.21` |
| **candidate-2** | `http://a3-nexus:8081/docker-proxy` | `["http://a3-nexus:8081/docker-proxy/"]` | **0** | 0 | **0** | none |

`docker info` Registry Mirrors, verbatim:

```
candidate-1     Registry Mirrors:
                 http://a3-nexus:8081/repository/docker-proxy/

candidate-2     Registry Mirrors:
                 http://a3-nexus:8081/docker-proxy/
```

**candidate-2 is the row that earns this plan its existence.** Its pull SUCCEEDED, exit 0, with real layer traffic (`Pulling fs layer` … `Download complete`) on an engine whose image store had just been destroyed with `docker rm -f -v`. It succeeded because Docker fell back to Docker Hub. A probe that scored routing on the pull exit code would have recorded a non-mirror as a working mirror — which is exactly the silent-corruption failure mode this phase's rules exist to prevent. The evidence file states it explicitly: a `docker pull` that succeeds with no components delta is **not** routing.

candidate-2's BEFORE zero was reached by DELETEing candidate-1's cached component through `/service/rest/v1/components/{id}` and then **re-reading the count and hard-failing if it were non-zero** — asserted, not assumed.

### Documentary reading, version-matched to the installed engine

From `https://raw.githubusercontent.com/moby/moby/v28.3.2/registry/config.go` — the tag exactly matching the host's Docker 28.3.2:

- `ValidateMirror` rejects only: missing scheme, a scheme other than http/https, a query string or fragment, and userinfo. **A path is accepted**, and the value is normalised with a trailing `/`.
- `loadMirrors` / `loadInsecureRegistries` assign the mirror list to exactly one index, `IndexName` (`docker.io`); every other index is built with `Mirrors: []string{}`. `lookupV2Endpoints` corroborates from the other end — mirror endpoints are appended only on the `hostname == DefaultNamespace || hostname == IndexHostname` branch.
- `lookupV2Endpoints` stores the **whole** mirror URL, path included, on the `APIEndpoint` — which is why a path-bearing mirror is structurally plausible at all, and why recall would have been an unsafe basis for the decision.

Docker's own documentation (Context7, `/docker/docs`, `main` branch, **not** version-matched) corroborates the Hub-only half — *"It's currently not possible to mirror another private registry. Only the central Hub can be mirrored."* — and is silent on paths in the engine's `registry-mirrors` key.

### Non-mutation of the operator's environment

```
=== T-24-17 host daemon.json assertion ===
    path:   /Users/christian/.docker/daemon.json
    before: 55a16d289b1bd748b186117e8bc1937c5c65ff4e
    after:  55a16d289b1bd748b186117e8bc1937c5c65ff4e
    UNCHANGED
```

Asserted by the script's own EXIT trap on every run, including the `--validate-only` runs. After the full run, `docker ps -a --filter name=a3-` and `docker network ls --filter name=a3-net` are both empty; all removals used `-v`, so the dind image-store volumes went with their containers.

## Decisions Made

See `key-decisions` in the frontmatter. The operator's checkpoint reply, recorded verbatim in the evidence file under `## Decision` and reproduced here as the plan's `<output>` requires:

> Operator decision: **daemon-opt-in** — write daemon.json behind an opt-in `--docker-daemon` flag, off by default (matches locked 24-CONTEXT.md decision). Key(s) to write when the flag is used: **both `registry-mirrors` and `insecure-registries`** (matching exactly what was measured, since `registry-mirrors` alone over plain HTTP is unmeasured).

The keys named are therefore **both** `registry-mirrors` and `insecure-registries`, and the mirror URL plan 24-07 must write is `http://<nexus-host>/repository/<docker-repo>` — with the `/repository/` segment. The path-only form must never be written: it is candidate-2.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The workstation's Docker credential helper hangs, so every `docker pull` blocks silently**

- **Found during:** Task 1, on the probe's first real run
- **Issue:** `docker pull` produced **no output at all** and never returned (killed at 120s, then at 180s, then at 240s). Bisected: the Docker Desktop VM's network is healthy (`getent hosts registry-1.docker.io` resolves from inside a running container, and an in-container HTTPS request to `/v2/` returns the expected 401), but `echo "https://index.docker.io/v1/" | docker-credential-desktop get` hangs indefinitely (killed at 20s). `~/.docker/config.json` carries `"credsStore": "desktop"` with an empty `auths` entry for `index.docker.io`, so the CLI blocks on the credential helper **before** contacting any registry — which is why the failure is silent rather than an error.
- **Fix:** the probe points `DOCKER_CONFIG` at a throwaway directory containing `{}` (no `credsStore`, no `auths`) so Hub pulls proceed anonymously, resolving `DOCKER_HOST` from the operator's active context first because an empty config carries no `currentContext`. `DOCKER_CONFIG` is a **client-side** directory; `~/.docker/daemon.json` is read by the daemon and is unaffected. The operator's `config.json` was not repaired, edited, or read-modified-written, and Docker Desktop was not restarted — an engine restart is an operator action, not an executor's.
- **Files modified:** `24-evidence/a3-dind-probe.sh` (the isolation block and its measured justification), `24-evidence/a3-docker-daemon-routing.md` (Environment table)
- **Verification:** `DOCKER_CONFIG=<throwaway> DOCKER_HOST=<resolved> docker pull alpine:3.21` completes in seconds; the full probe then ran end to end.
- **Committed in:** `79c543f` (script), `ca78608` (evidence note)
- **Handed to the operator:** surfaced at the checkpoint as an environment finding independent of this plan. Their Docker Desktop credential store is in a degraded state right now, which matters more than usual given they selected a daemon-writing branch.

**2. [Rule 2 - Missing Critical] The validation stage had no controls, so neither candidate exit code would have meant anything**

- **Found during:** Task 1, while writing the probe
- **Issue:** 24-04-PLAN.md's Task 1 specifies `dockerd --validate` once per candidate and nothing else. With only the two candidate rows, a candidate exit 1 is indistinguishable from a broken container invocation, and a candidate exit 0 is indistinguishable from `--validate` not inspecting `registry-mirrors` at all. Either way the row is unattributable — the same vacuous-pass defect 24-01 spent Task 3 proving its new gate checks did not have.
- **Fix:** two control rows added. `control-empty` (`{}`) MUST validate or the harness is broken; `control-query` (a mirror with `?y=1`) MUST be rejected or `--validate` is not reading the key. Both are hard-failing preconditions in the script — the probe exits 1 and refuses to draw a conclusion if either control misbehaves.
- **Files modified:** `24-evidence/a3-dind-probe.sh`
- **Verification:** measured — control-empty exit 0, control-query exit 1 with `invalid mirror: query or fragment at end of the URI`, which is the moby v28.3.2 rejection path read in §1a.
- **Committed in:** `79c543f`

**3. [Rule 1 - Bug] Three `set -euo pipefail` traps in the probe's own first draft**

- **Found during:** Task 1, review before the first full run
- **Issue:** (i) `[ "$CAND1_VALIDATE_RC" = "0" ] && SURVIVORS+=("candidate-1")` as a standalone statement returns 1 when the test is false, which under `set -e` aborts the whole probe — turning "one candidate was rejected at validation" into a silent abort with no verdict. (ii) `printf '%s\n' "$pull_out" | head -8` lets `head` close the pipe early, killing `printf` with EPIPE, which `set -o pipefail` promotes to a script-ending failure on any pull output longer than 8 lines. (iii) `sed 's/…/…/' <<<"$(head …)"` fixed (ii) but tripped shellcheck SC2001.
- **Fix:** (i) rewritten as `if … then … fi` with the reason in a comment; (ii)/(iii) rewritten as `head -8 <<<"$pull_out" | sed …`, where the here-string removes the EPIPE source and `sed` drains `head` fully.
- **Files modified:** `24-evidence/a3-dind-probe.sh`
- **Verification:** `shellcheck` exit 0; the full probe ran to completion with a 9-line pull output.
- **Committed in:** `79c543f`

**4. [Rule 2 - Missing Critical] `docker rm` without `-v` would have leaked the dind image store, and the plan's own acceptance check could not have caught it**

- **Found during:** Task 2, while writing the teardown
- **Issue:** `docker:28.3.2-dind` declares `VOLUME /var/lib/docker`. A plain `docker rm -f` leaves an anonymous volume per candidate, invisible to `docker ps -a --filter name=a3-`, which is the plan's stated cleanliness criterion. Worse for the measurement itself: a reused image store would have let candidate-2 satisfy its pull from candidate-1's cached layers, producing a zero components delta that meant "already cached" rather than "did not route" — an unattributable result presented as a verdict.
- **Fix:** every removal in the probe uses `docker rm -f -v`, and a fresh dind container is created per candidate rather than reconfiguring one.
- **Files modified:** `24-evidence/a3-dind-probe.sh`
- **Verification:** candidate-2's pull output shows `Pulling fs layer` … `Download complete`, i.e. a real download on an empty store, so its zero delta is genuine non-routing.
- **Committed in:** `79c543f`

**5. [Rule 2 - Missing Critical] The dind image was pinned to the floating major tag the plan named**

- **Found during:** Task 1
- **Issue:** the plan specifies `docker:28-dind`. That tag floats within the 28.x line, so the evidence would have carried a permanent "the probe measured a different engine than the host's 28.3.2" caveat for no reason.
- **Fix:** `docker:28.3.2-dind` resolved and pinned by manifest-list digest `sha256:44383404ebf0c36243f5969f0dddd23c204ea3bb185e7473a4141f6ccfd07b53` — the exact host engine version. The digest is recorded in the evidence file as ADR-004 requires, and the nested engine's own `docker version` is printed per candidate (`28.3.2` both times) so the match is observed rather than asserted.
- **Files modified:** `24-evidence/a3-dind-probe.sh`, `24-evidence/a3-docker-daemon-routing.md`
- **Verification:** printed in the probe output for both candidates.
- **Committed in:** `79c543f`

### Departures from the plan's letter, recorded rather than fixed

- **Task 2's preamble asks for Nexus to boot AFTER the dind engine "so a dind restart cannot kill it"; the numbered steps place Nexus first.** The numbered steps were executed. The preamble's concern does not apply to this arrangement: `a3-nexus` is a sibling container on the **host** engine sharing the `a3-net` user-defined network, not a container inside the nested engine, so recreating dind between candidates cannot disturb it. Recorded as caveat 7 in the evidence file rather than silently ignored.
- **The evidence file was created in Task 1, not Task 2.** Task 1's `<files>` names only the probe script, but its acceptance criteria require the documentary reading to be recorded with source URLs and version-match notes. The file was therefore created in the Task 1 commit carrying §1 and §2 only, with **no** `VERDICT:` line; Task 2 appended §3 and the verdict. `grep -c '^VERDICT:'` is 1 at `c39db9b` and remains 1 at `ca78608`.

---

**Total deviations:** 5 auto-fixed (1 bug, 3 missing critical, 1 blocking), 2 recorded departures
**Impact on plan:** none negative. Deviations 2 and 4 are the difference between a verdict and an unattributable number — deviation 4 in particular is what makes candidate-2's zero delta mean "did not route" rather than "was already cached". Deviation 1 is an environment fault that would have blocked the plan entirely and was handed to the operator rather than papered over. No file outside the plan's `files_modified` was touched.

## Issues Encountered

**Handed forward, and load-bearing for plan 24-07:** the `/repository/` segment is **required** in the daemon's mirror URL and **forbidden** in the image reference. 24-RESEARCH.md Pattern 6 establishes the second half and calls the `/repository/`-prefixed reference a documentation trap; this plan establishes that the mirror URL is the exact inverse. A reader who applies Pattern 6's rule to the mirror URL produces candidate-2, which pulls successfully and routes nothing. That inversion needs to be stated wherever 24-07 writes the URL, not left to be rediscovered.

**Workstation fault, not a project defect:** `docker-credential-desktop get` for `index.docker.io` hangs on this machine (deviation 1). The probe works around it client-side. Nothing in the repository needs changing, but a daemon-writing branch will be exercised first on a Docker Desktop whose credential store is currently wedged.

## Threat Flags

None. The surface this plan adds is a probe script in the planning tree that creates and destroys throwaway containers; it ships no code. Every `mitigate` disposition in the plan's `<threat_model>` is implemented and observed: `~/.docker/daemon.json` never written and asserted byte-identical by the script's own EXIT trap (T-24-17); the verdict rests on the Nexus components delta with the BEFORE count asserted zero for every candidate, never on the pull exit code (T-24-18); the dind image pinned by `@sha256:` digest and recorded in the evidence file (T-24-19). The two `accept` dispositions are unchanged and bounded as described — plaintext `insecure-registries` on a throwaway network for the lifetime of one probe (T-24-20), and a `--privileged` dind container from a digest-pinned image with no host mounts, removed with `-v` on EXIT (T-24-21).

## Requirements

`requirements-completed: []` — **NEXUS-04 is deliberately NOT marked complete here.** The plan's frontmatter carries it, but this plan measures an assumption and records a decision; it ships no part of `workstation/nexus-setup.sh`. Marking follows the 24-01 precedent: plan 24-10 marks it after the work is on `origin/main`.

## Next Phase Readiness

Plan 24-07 has a named branch to implement, chosen by the operator with the evidence in front of them, and reads it from `24-evidence/a3-docker-daemon-routing.md` §Decision rather than from a transcript. Six things that section commits it to:

1. `--docker-daemon` flag, **default off**; `NEXUS_DOCKER_REGISTRY` ships on every run regardless.
2. With the flag, write **both** keys: `registry-mirrors` at `http://<nexus-host>/repository/<docker-repo>` (**with** `/repository/`) and `insecure-registries` at the bare `host:port` (**no** scheme).
3. Never write the path-only mirror form — that is candidate-2, measured as routing nothing.
4. ADR-009 governs the `insecure-registries` warning wording, alongside the `trusted-host` line in the generated `pip.conf`.
5. The script must not present Docker as fully routed: only `docker.io` references are mirrored, never `ghcr.io/…`, `quay.io/…`, `public.ecr.aws/…`.
6. A manual daemon restart is required after the write, and the flag's help text must say so.

The REQUIREMENTS.md Out-of-Scope carve-out added this session stays and is now used rather than annotated-as-unused — `daemon-opt-in` is exactly the global-workstation-default exception it carves out.

Still unmeasured and named as such in the evidence file: the operator's own Docker Desktop engine was never configured with either mirror and never restarted, so 24-07's first real run remains an unmeasured step (the containerd-snapshotter half of that concern is now excluded — this host reports `Storage Driver: overlay2`, the same classic image store dind used); nothing was measured against a TLS-terminated Nexus, which is Phase 25's ingress; and the mirror was measured only against a Nexus with anonymous access OPEN, diverging from the chart's shipped default of `false`.

---
*Phase: 24-nexus-anonymous-access-and-workstation-script*
*Completed: 2026-09-19*

## Self-Check: PASSED

All three artefact paths exist on disk. All three commit hashes (`79c543f`, `c39db9b`, `ca78608`)
are present in `git log --oneline --all`. `a3-dind-probe.sh` is 526 lines (min_lines 60 satisfied),
mode 644 (not executable), `shellcheck` exit 0, and contains `registry-mirrors` (10 occurrences).
`a3-docker-daemon-routing.md` contains exactly one `^VERDICT:` line and names `24-07-PLAN.md`,
satisfying the plan's `key_links` entry.
