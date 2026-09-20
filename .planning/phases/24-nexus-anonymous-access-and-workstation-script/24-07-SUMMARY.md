---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 07
subsystem: infra
tags: [bash, workstation, nexus, npm, pip, helm, docker, daemon-json, jq, adr-009, verification, shellcheck]

# Dependency graph
requires:
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 06
    provides: "workstation/nexus-setup.sh — the npm/pip/Helm writers, the validated --url interface, and the deliberately-unimplemented --verify arm that left VERIFY-FAILS-LOUDLY red for this plan to turn green for real"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 04
    provides: "The operator's `daemon-opt-in` selection and the `VERDICT: A3-FALSIFIED-CANDIDATE-1` measurement — which of this plan's two pre-written Docker branches to build, and the one mirror URL shape that actually routes"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 02
    provides: "The EULA/metadata boundary: a PyPI simple page answers 200 even when the licence is unaccepted, so --verify's licence diagnosis must come from a COMPONENT download"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 03
    provides: "scripts/check-nexus-setup.sh — the twelve-check offline gate, now fully green against the real subject"
provides:
  - "--verify: a mandatory proof pass with a per-ecosystem status table, a configuration readback from the CLIENT plus a real component fetch per ecosystem, and a non-zero exit when any row is not ok"
  - "Three distinct server-side diagnoses, each naming the value responsible: transport failure (unreachable), HTTP 401 (anonymous.enabled), HTTP 403 with a body under ~1,000 bytes (eula.accepted)"
  - "--docker-daemon: the operator's `daemon-opt-in` branch, off by default, writing the MEASURED mirror URL with a timestamped backup, a jq merge that never reorders, and the ADR-009 warning"
  - "scripts/check-nexus-setup.sh fully green: ALL PASS, 12 checks, 0 failures, 0 skipped"
affects: [24-08, 24-09, 24-10, phase-25-nexus-live-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-stage verification per ecosystem — readback from the client, then a real fetch — because a wrong readback and a failed fetch are different diagnoses and a single verdict sends the developer to the wrong place"
    - "Disable the client's cache on every verification fetch: a cached artefact satisfies 'a file appeared' with zero packets, which is a green row for a service that was never contacted"
    - "Assert the client's own account of which index it used (pip's 'Looking in indexes:' line), because an environment variable can outrank the config file that the readback inspects"
    - "Name the server-side VALUE responsible in the failure message (eula.accepted, anonymous.enabled), not just the HTTP status, so a server condition is never read as a client misconfiguration"
    - "A 403 is classified by BODY SIZE, not by status alone: the licence refusal is a perfectly well-formed 192-byte response"
    - "Merge into a file someone else owns with jq and an at-most-once append that preserves order, compare CANONICALISED JSON rather than bytes, and back up with a timestamp before any write"

key-files:
  created: []
  modified:
    - repos/security-platform/workstation/nexus-setup.sh

key-decisions:
  - "MEASURED, and the plan's own prescribed command does not work: `pip config get global.index-url` exits 1 with 'ERROR: No such key' on pip 26.2.1 under every scope flag, with PIP_CONFIG_FILE pointed at a file that plainly carries the key — while `pip config list` prints it from the same file in the same shell. `get` reads the writable scopes only and cannot see the ':env:' variant PIP_CONFIG_FILE creates. 24-VALIDATION row 24-W0-11 names the command that fails; the readback uses `config list`, which is also the better question because it reports pip's MERGED view. The measurement is written into the script, not only here."
  - "MEASURED on helm v4.3.0: `helm search repo -r '^nexus/'` reports 'No results found' against an index whose every row is named 'nexus/<chart>', while `-r 'nexus/'` returns all twelve. Helm's regexp is not applied to the start of the 'repo/chart' string, so the anchored pattern the plan suggested would have produced a permanent false FAILED row. The pattern is unanchored and the anchoring is done afterwards on the JSON, where it is exact — --fail-on-no-result alone only proves SOME row matched."
  - "insecure-registries is emitted only for a plain-http Nexus, not unconditionally. The operator said 'both keys, matching exactly what was measured'; the measured A3 pair was http, and an http run ships exactly that pair. Writing a TLS bypass for an https:// URL would disable a certificate check that is working — the identical reasoning that already makes pip's trusted-host conditional, and ADR-009 governs both."
  - "SKIPPED and UNVERIFIABLE both increment FAIL_COUNT, so --verify exits non-zero when a client is missing or when npm's local prefix does not resolve here. A skip is not a pass: the operator asked for proof and did not get it."
  - "The pip verification fetch carries --no-input. MEASURED: against a 401, pip PROMPTS on the terminal ('User for <host>:'), so without it a --verify run blocks forever on a developer's TTY — and `bounded` only rescues that where timeout(1) exists."
  - "Three commits rather than the plan's single one, each listing exactly workstation/nexus-setup.sh: the executor protocol commits per task, and the third is a Rule 1 fix found during task 3's verification. Task 3 produced no file change of its own — it is a measurement task."

patterns-established:
  - "Pattern: when a plan's prescribed verification COMMAND does not work on the installed tool, measure the alternative, use it, and write the divergence into the script beside the call — the 24-02 precedent, applied twice here (pip config get, helm search -r anchoring)."
  - "Pattern: prove a gate non-vacuous against the REAL subject, not only against a stand-in — predict the red check, break the shipped file, observe exactly one red, restore byte-identically, and assert the restoration with cmp."
  - "Pattern: a verification pass must not be able to block on a TTY. An interactive credential prompt is a hang, and a hang in a proof pass is indistinguishable from a slow network."

requirements-completed: []  # NEXUS-04 is withheld ON PURPOSE — plan 24-10 marks it after the script is on origin/main. An install script on a feature branch is not published.

# Metrics
duration: ~2h05m
completed: 2026-09-20
---

# Phase 24 Plan 07: The Verification Pass and the Measured Docker Behaviour Summary

**`workstation/nexus-setup.sh` now ends on measured evidence rather than a claim: `--verify` asks each client what it resolves and then pulls a real component through it, names the three server-side conditions apart by the value responsible, reports Docker as MANUAL under every condition, and exits non-zero when anything is not `ok` — with the operator's `daemon-opt-in` Docker branch behind a flag that is off by default, and the workstation gate at `ALL PASS - 12 checks, 0 skipped`.**

## Performance

- **Duration:** ~2h05m
- **Started:** 2026-09-20T13:30Z
- **Completed:** 2026-09-20T15:35Z
- **Tasks:** 3 (all `auto`, no checkpoints)
- **File modified:** 1 (`workstation/nexus-setup.sh`, 842 → 1,637 lines, mode 644)
- **Live Nexus instances booted:** 2 (both `v-nexus` on host port 8083, torn down)
- **`--verify` runs against a live Nexus:** 6 (3 server conditions, measured twice — once before and once after the `--no-input` fix)

## Task Commits

All three in `repos/security-platform`, on `feature/phase-24-nexus-anonymous-and-workstation`. Each commit's `git diff-tree --no-commit-id --name-only -r <sha>` lists exactly `workstation/nexus-setup.sh` and nothing else.

| Task | Commit | Subject |
|------|--------|---------|
| 1 — the mandatory verification pass | `c1df999` | `feat(24-07): add the --verify proof pass to nexus-setup.sh` |
| 2 — the Docker branch the operator selected | `ec9544d` | `feat(24-07): add the measured Docker daemon-opt-in branch to nexus-setup.sh` |
| 3 — gate green, mutations, chart half | `9ec38b6` | `fix(24-07): stop the pip verification fetch blocking on a credential prompt` |

Task 3 is a MEASUREMENT task and changed no code of its own; the commit against it is the Rule 1 defect its measurements exposed (deviation 3 below).

## Accomplishments

- Every ecosystem's routing is proven by a real component fetch, not by reading back a file this script wrote: `npm pack` with an empty cache, `pip download --no-cache-dir`, `helm repo update` followed by a search that returns rows from *this* repository's entry.
- The three server conditions are distinguishable and each names the value responsible. A 403 is classified by **body size**, because the Sonatype licence refusal is a perfectly well-formed 192-byte HTTP response and is invisible to a status check alone.
- Docker reports `MANUAL` under every one of the three live conditions and under the unreachable one — never `ok`, including on runs where `--docker-daemon` wrote a mirror.
- The operator's `daemon-opt-in` branch is implemented exactly as selected, with the `VERDICT:` line quoted in the file header: timestamped backup first, malformed JSON never overwritten, each entry appended at most once without reordering the operator's priority list, a canonicalised comparison that makes a second run write nothing, the ADR-009 warning beside the directive, and no engine restart.
- The gate is green against the real subject and proven non-vacuous there: three single-defect mutations of the shipped file each produced exactly one red check, matching the prediction made before each run.
- The operator's real `~/.docker/daemon.json`, global Helm repository list and npm userconfig are byte-identical to their pre-plan state — measured directly, not inferred.

## Measured Evidence

### 1. `--verify` under all three server conditions

One Nexus, `v-nexus`, on host port 8083 (the live smoke owns 8081, plan 24-04's probe owned 8082), booted from the image the chart itself renders (`docker.io/sonatype/nexus3:3.96.0-ubi`) and provisioned by the chart's own `kubernetes/nexus/files/provision.sh` with the four repo bodies from the chart's own rendered `-repos` ConfigMap. Each transition below is a real `provision.sh` run with `READY_ATTEMPTS=60 READY_INTERVAL=10` — `provision.sh`'s EULA step can only *accept*, never revoke, so the unaccepted condition is measured **first**, on a freshly booted instance, rather than by revoking afterwards.

Paths are elided as `<repo>`; nothing else is edited.

#### 1a. `EULA_ACCEPTED=false ANONYMOUS_ENABLED=true` — the licence refusal. `exit=1`

```
ECOSYSTEM MECHANISM                                  STATUS        OBSERVED
--------- ---------                                  ------        --------
npm       .npmrc (project scope)                     FAILED        readback is correct, but the fetch failed: 'npm pack lodash@4.17.21' exited 1. SERVER-SIDE LICENCE REFUSAL: http://127.0.0.1:8083/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz answered HTTP 403 with a 192-byte body to an unauthenticated GET. A component download refused with a body that small is the Sonatype licence gate, NOT a client misconfiguration — the server-side value responsible is eula.accepted (the chart value eula.accepted, POSTed to /service/rest/v1/system/eula). Measured, plan 24-02: the refusal body is 192 bytes, metadata still answers 200 while every component download is refused, and no file in this repository can change it. npm's own output: npm error code E403 npm error 403 403 Forbidden - GET http://127.0.0.1:8083/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz […]
pip       pip.conf via PIP_CONFIG_FILE               FAILED        readback is correct, but the fetch failed: 'pip3 download six' exited 1. SERVER-SIDE LICENCE REFUSAL: pip's own COMPONENT request was answered HTTP 403 — the Sonatype licence gate, not a client misconfiguration. The server-side value responsible is eula.accepted. Measured, plan 24-02: a PyPI simple page answers 200 even while the licence is unaccepted, because it is metadata; only a component download such as this one sees the gate. pip's own output: Looking in indexes: http://127.0.0.1:8083/repository/pypi-proxy/simple Collecting six   Downloading six-1.17.0-py2.py3-none-any.whl.metadata (1.7 kB) ERROR: HTTP error 403 while getting http://127.0.0.1:8083/repository/pypi-proxy/packages/six/1.17.0/six-1.17.0-py2.py3-none-any.whl […]
helm      .helm/repositories.yaml via env redirect   FAILED        there is no <repo>/.helm/repositories.yaml, so 'helm repo add' never completed and HELM_REPOSITORY_CONFIG has nothing to point at. SERVER-SIDE LICENCE REFUSAL: http://127.0.0.1:8083/repository/helm-proxy/index.yaml answered HTTP 403 with a 192-byte body to an unauthenticated GET. […]
docker    none - no per-repo mechanism exists        MANUAL        NEXUS_DOCKER_REGISTRY=127.0.0.1:8083/docker-proxy — nothing routes until an image REFERENCE is edited to start with that prefix, e.g. 'docker pull 127.0.0.1:8083/docker-proxy/library/alpine:3.21'.

Rows: 0 ok, 3 not ok, 1 MANUAL.
```

**pip's own output corroborates plan 24-02's headline finding from the client side, live:** `Looking in indexes: …/simple` succeeded and the metadata for `six` was fetched (1.7 kB) — then the **component** under `/packages/` was refused 403. Metadata 200, component 403, in one command's output. A `--verify` that had probed the simple page would have reported a pass.

#### 1b. `EULA_ACCEPTED=true ANONYMOUS_ENABLED=true` — the healthy instance. `exit=0`

```
ECOSYSTEM MECHANISM                                  STATUS        OBSERVED
--------- ---------                                  ------        --------
npm       .npmrc (project scope)                     ok            npm resolves registry=http://127.0.0.1:8083/repository/npm-proxy/; 'npm pack lodash@4.17.21' pulled 318961 bytes through it with an empty cache
pip       pip.conf via PIP_CONFIG_FILE               ok            pip reads global.index-url=http://127.0.0.1:8083/repository/pypi-proxy/simple and reports 'Looking in indexes: http://127.0.0.1:8083/repository/pypi-proxy/simple'; downloaded six-1.17.0-py2.py3-none-any.whl with the cache disabled
helm      .helm/repositories.yaml via env redirect   ok            'helm repo list' shows 'nexus' at http://127.0.0.1:8083/repository/helm-proxy/; 'helm repo update' fetched its index and 'helm search repo -r nexus/' returned 12 chart row(s) from that repository; the global list /Users/christian/Library/Preferences/helm/repositories.yaml is unchanged (f573be9315bf7642ea29005bdfe5b8f65e784403fb8ebbbbef3d7f9ff623c5cb)
docker    none - no per-repo mechanism exists        MANUAL        NEXUS_DOCKER_REGISTRY=127.0.0.1:8083/docker-proxy — nothing routes until an image REFERENCE is edited to start with that prefix, e.g. 'docker pull 127.0.0.1:8083/docker-proxy/library/alpine:3.21'.

Rows: 3 ok, 0 not ok, 1 MANUAL.
```

The npm figure — **318,961 bytes** — is the same tarball size plan 24-02 measured through the live gate, from a different client, through a different mechanism.

#### 1c. `EULA_ACCEPTED=true ANONYMOUS_ENABLED=false` — anonymous read closed. `exit=1`

```
npm       .npmrc (project scope)                     FAILED        readback is correct, but the fetch failed: 'npm pack lodash@4.17.21' exited 1. SERVER-SIDE ANONYMOUS ACCESS: http://127.0.0.1:8083/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz answered HTTP 401 to an unauthenticated GET. Anonymous read is NOT enabled on this Nexus — the server-side value responsible is anonymous.enabled (the chart value anonymous.enabled, PUT to /service/rest/v1/security/anonymous). Nothing written into this repository can change that; the Nexus instance has to be reconfigured. […]
pip       pip.conf via PIP_CONFIG_FILE               FAILED        readback is correct, but the fetch failed: 'pip3 download six' exited 1. SERVER-SIDE ANONYMOUS ACCESS: http://127.0.0.1:8083/repository/pypi-proxy/simple/six/ answered HTTP 401 to an unauthenticated GET. […]
helm      .helm/repositories.yaml via env redirect   FAILED        there is no <repo>/.helm/repositories.yaml, so 'helm repo add' never completed […] SERVER-SIDE ANONYMOUS ACCESS: http://127.0.0.1:8083/repository/helm-proxy/index.yaml answered HTTP 401 to an unauthenticated GET. […]
docker    none - no per-repo mechanism exists        MANUAL        NEXUS_DOCKER_REGISTRY=127.0.0.1:8083/docker-proxy — […]

Rows: 0 ok, 3 not ok, 1 MANUAL.
```

All three rows name anonymous access, and none of them names the licence.

#### 1d. An unreachable endpoint. `exit=1`

`bash workstation/nexus-setup.sh --url http://127.0.0.1:9 --verify`, from a throwaway repository:

```
npm    FAILED  readback is correct, but the fetch failed: 'npm pack lodash@4.17.21' exited 1. REACHABILITY: an unauthenticated GET of http://127.0.0.1:9/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz did not complete (curl exited 7 — 6 is DNS, 7 is connection refused, 28 is a timeout). The endpoint is unreachable from this machine […]
pip    FAILED  readback is correct, but the fetch failed: 'pip3 download six' exited 1. REACHABILITY: an unauthenticated GET of http://127.0.0.1:9/repository/pypi-proxy/simple/six/ did not complete (curl exited 7 […]
helm   FAILED  there is no <repo>/.helm/repositories.yaml […] REACHABILITY: […] curl exited 7 […]
docker MANUAL  NEXUS_DOCKER_REGISTRY=127.0.0.1:9/docker-proxy […]

Rows: 0 ok, 3 not ok, 1 MANUAL.
3 row(s) above are not 'ok'. This run exits non-zero.
```

Three distinct diagnoses across 1a, 1c and 1d — licence refusal, anonymous disabled, unreachable — each naming its own cause, and **no overall success line is printed on any of them.**

### 2. The Docker branch: `daemon-opt-in`, with the verdict it rests on

Quoted in the script header, verbatim from the evidence file:

```
VERDICT: A3-FALSIFIED-CANDIDATE-1
```

Read precisely: a path-routed Nexus Docker proxy **can** serve as a `registry-mirrors` target, at the `/repository/<repo>` URL and only there. The other candidate — `HOST/<repo>`, the shape that looks right because it is the image-reference shape — produced `docker pull` exit 0 with real layer traffic and **zero** components in Nexus. That asymmetry is why the mirror URL carries `/repository/` while the `.nexus-env` prefix does not, and why "unifying" them would break one of the two.

#### 2a. `daemon.json` before and after, against a realistic seeded file

`HOME` pointed at a throwaway directory; the operator's real file was never a target. Before:

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "registry-mirrors": [
    "https://mirror.example.internal"
  ]
}
```

After `--url http://nexus.example.com:8081 --docker-daemon`:

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "registry-mirrors": [
    "https://mirror.example.internal",
    "http://nexus.example.com:8081/repository/docker-proxy"
  ],
  "insecure-registries": [
    "nexus.example.com:8081"
  ]
}
```

Every pre-existing key survives, and the operator's own mirror stays **first** — `registry-mirrors` is a priority list, so the merge appends and never sorts or de-duplicates.

#### 2b. The four daemon behaviours, measured

| Run | Condition | Observed |
|-----|-----------|----------|
| 1 | seeded realistic file, http URL | both entries appended; backup `daemon.json.nexus-setup-backup-20260920T192802Z` taken **before** the write; warning printed |
| 2 | identical re-run | `already carries the mirror … Nothing was written and no backup was taken`; file byte-identical to run 1 (`cmp`); backup count still 1; `docker-proxy` occurs exactly **once** |
| 3 | existing file is malformed JSON | `ERROR: … exists and is not valid JSON, so it was NOT modified and NOT overwritten: jq: parse error: Invalid numeric literal at line 2, column 0`; file byte-identical (`cmp`); no new backup; run exits non-zero |
| 4 | https URL | `--url is https, so no insecure-registries entry is written`; `grep -c insecure-registries` = **0**; only `registry-mirrors` added |

#### 2c. The ADR-009 warning, as printed

```
SECURITY WARNING (ADR-009) — what was just written to <path>/daemon.json:

  registry-mirrors     tells the Docker engine to try <mirror> before Docker Hub.
                       Only docker.io references are ever mirrored: ghcr.io,
                       quay.io, public.ecr.aws and every other registry
                       continue to be pulled directly, so this routes PART of
                       a typical project's images and never all of them.
  insecure-registries  does not merely permit plain HTTP. It disables TLS
                       verification for <host> entirely, so anything
                       positioned between this machine and that host can
                       substitute images and the engine will raise no
                       certificate error.

  This change is MACHINE-GLOBAL: it affects every repository and every project
  on this workstation, unlike the npm, pip and Helm configuration this script
  writes, which is scoped to one repository.
  It MUST be removed once TLS is configured on this Nexus instance.
```

Followed by the restore command with the backup path, the statement that the engine must be restarted **by the operator** before anything takes effect, and the A3 caveat that this workstation's own Docker Desktop engine was never configured with the mirror during the measurement — so its first real run is the operator's, and the components count is what to check, not the pull exit code.

`grep -c 'docker restart\|systemctl restart docker\|killall Docker' workstation/nexus-setup.sh` → **0**. The script never restarts the engine.

### 3. The gate, fully green against the real script

```
check-nexus-setup: asserting offline invariants against workstation/nexus-setup.sh
==> SETUP-NOT-EXECUTABLE: PASS - workstation/nexus-setup.sh is not executable, as the project Script Safety rule requires
==> SETUP-SHELLCHECK: PASS - shellcheck reports no findings on workstation/nexus-setup.sh
==> NPMRC-NO-REDIRECT: PASS - no '>' or '>>' redirect targets .npmrc anywhere in the non-comment source
==> HELM-NOT-HANDWRITTEN: PASS - the subject shells out to 'helm repo add' and never writes repositories.yaml itself
==> VERIFY-NO-SILENT-TRUE: PASS - no '|| true' appears anywhere in the non-comment source
==> DOCKER-DAEMON-WARNING: PASS - the daemon.json write carries the ADR-009 warning in full — the directive is named, and its machine-global scope and its removal once TLS is configured are both stated beside it
==> NPMRC-MERGE: PASS - the seeded auth-token and save-exact lines both survived and npm resolves the registry to https://nexus.example.com/repository/npm-proxy/
==> DOCKER-PREFIX-SHAPE: PASS - the emitted prefix is 'export NEXUS_DOCKER_REGISTRY="127.0.0.1:49197/docker-proxy"' — host present, docker-proxy named, no /repository/ segment
==> PIP-TRUSTED-HOST-CONDITIONAL: PASS - trusted-host appears only for plain http to a non-loopback host, and carries the ADR-009 removal sentence when it does
==> NEXUS-ENV-EXPORTS: PASS - the env file exports exactly the four contracted variables and states both the sourcing requirement and the PIP_CONFIG_FILE user-scope consequence
==> GLOBAL-CONFIG-UNTOUCHED: PASS - the operator's Helm repository config, npm userconfig and ~/.docker/daemon.json are all byte-unchanged across every fixture run
==> VERIFY-FAILS-LOUDLY: PASS - --verify exited 1 with unreachable npm and pip indexes and named the failing ecosystem

=== Summary ===
ALL PASS - 12 check(s) executed and passed; 0 sub-check(s) skipped (not passed).
```

`gate-exit=0`. **Zero skips**, not merely zero failures: `DOCKER-DAEMON-WARNING`, the one honest skip plan 24-06 left behind, now binds because the subject really does write `daemon.json`.

### 4. Three mutations of the REAL script, each predicted before the run

Plan 24-03 proved the assertion bodies fire against a scratchpad stand-in. This is the different claim: that they fire against the shipped subject. Each mutation was applied to the committed file, the gate run, and the file restored from a byte-exact snapshot with `cmp` asserting the restoration.

| Mutation | Predicted red | Observed red | Other checks |
|----------|---------------|--------------|--------------|
| `trusted-host` conditional removed (emitted unconditionally) | `PIP-TRUSTED-HOST-CONDITIONAL` | `PIP-TRUSTED-HOST-CONDITIONAL: FAIL - an https:// URL produced a trusted-host directive, which disables certificate verification for that host and downgrades a check that was working` | all green |
| `/repository/` inserted into the `NEXUS_DOCKER_REGISTRY` prefix | `DOCKER-PREFIX-SHAPE` | `DOCKER-PREFIX-SHAPE: FAIL - the emitted line is 'export NEXUS_DOCKER_REGISTRY="127.0.0.1:49161/repository/docker-proxy"' and it carries a /repository/ segment` | all green |
| `--verify` made to `exit 0` regardless of what it observed | `VERIFY-FAILS-LOUDLY` | `VERIFY-FAILS-LOUDLY: FAIL - --verify exited 0 against a URL serving nothing but the Helm index — the npm and pip fetches cannot have succeeded, so this is a success report over a routing failure` | all green |

Exactly one red per mutation, each the predicted one, `gate-exit=1` on all three, and `git diff --quiet` clean afterwards.

### 5. The chart half, unaffected

```
check-nexus-chart: asserting 18 offline invariants against kubernetes/nexus
PASS - 18 checks, 0 failures
```

```
ALL PASS - 25 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).
```

25 is the count 24-05-SUMMARY recorded. `pre-commit run --files workstation/nexus-setup.sh` exits 0; the file is mode `-rw-r--r--`.

### 6. The operator's machine, before and after

Measured directly with `shasum -a 256`, by this plan rather than by the gate:

| Target | Before | After |
|--------|--------|-------|
| `~/.docker/daemon.json` | `27369c832f1be7d067b379f3236a203993e7bec45135e58829a9273c3209f53c` | `27369c832f1be7d067b379f3236a203993e7bec45135e58829a9273c3209f53c` |
| `~/Library/Preferences/helm/repositories.yaml` | `f573be9315bf7642ea29005bdfe5b8f65e784403fb8ebbbbef3d7f9ff623c5cb` | `f573be9315bf7642ea29005bdfe5b8f65e784403fb8ebbbbef3d7f9ff623c5cb` |

Every `--docker-daemon` run in this plan had `HOME` pointed at a throwaway directory. No live 8083 run was ever passed the flag.

### 7. `|| true` accounting

`grep -c '|| true' workstation/nexus-setup.sh` → **2**, and both are prose:

- line 589, inherited from plan 24-06: a comment explaining that `helm repo add`'s caught branch is *not* a swallowed `|| true`;
- line 787, added here: the `--verify` header stating that no fetch below is ever `|| true`-ed.

Neither is on a verification fetch — neither is code at all — and `VERIFY-NO-SILENT-TRUE` reports PASS having stripped comments first. The acceptance criterion's second clause ("every occurrence carries a reason comment and is not on a verification fetch") is the one that applies.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] `pip config get` cannot read the `PIP_CONFIG_FILE` scope; the readback uses `pip config list`**

- **Found during:** Task 1, first live run of `--verify`.
- **Issue:** 24-VALIDATION row 24-W0-11 and the plan's `<interfaces>` block both prescribe `PIP_CONFIG_FILE=<repo>/pip.conf pip config get global.index-url`. Measured on pip 26.2.1, that command exits 1 with `ERROR: No such key - global.index-url` against a file that plainly carries the key — under no scope flag and under every one of `--global`, `--user`, `--site`. `pip config list` prints `global.index-url='http://…'` from the same file in the same shell, and `pip config debug` shows the value under the `env:` variant. `get` reads the writable scopes only and cannot see the `:env:` variant `PIP_CONFIG_FILE` creates. Shipping the prescribed command would have made the pip row permanently `FAILED`.
- **Fix:** the readback uses `pip config list` and parses `global.index-url='…'`, which is also the better question — it reports pip's **merged** view rather than one file's contents. The measurement is written into the script beside the call, following the 24-02 precedent, because the next reader of the script is who needs it.
- **Files modified:** `repos/security-platform/workstation/nexus-setup.sh`
- **Commit:** `c1df999`

**2. [Rule 1 — Bug] `helm search repo -r '^nexus/'` matches nothing; the anchor moved to the JSON**

- **Found during:** Task 1, against the live instance with a populated `helm-proxy`.
- **Issue:** The plan asked for `helm search repo <name>/<chart>`, and the anchored regexp `-r '^nexus/'` was the natural precise form. Measured on helm v4.3.0 against an index containing twelve `nexus/cert-manager*` charts: `-r '^nexus/'` → `No results found`, while `-r 'nexus/'` and `-r '.'` both return all twelve. Helm's regexp is not applied to the start of the `repo/chart` string. The anchored pattern would have produced a permanent false `FAILED` row on a correctly routed Helm.
- **Fix:** the pattern is unanchored, and the anchoring is done afterwards on the JSON output by counting `"name":"nexus/` occurrences — which is stricter than the anchor was, because `--fail-on-no-result` alone only proves *some* row matched and a chart in another repository could satisfy it. The measurement is recorded beside the call. A related defect was caught in the same place: `grep -c` on `-o json` output reports 1 for any non-empty result, because helm emits the whole array on one line; the count is occurrences, not lines.
- **Files modified:** `repos/security-platform/workstation/nexus-setup.sh`
- **Commit:** `c1df999`

**3. [Rule 1 — Bug] the pip verification fetch could block on a TTY credential prompt**

- **Found during:** Task 3, reading the observed column of the `ANONYMOUS_ENABLED=false` run.
- **Issue:** pip's own output carried `User for 127.0.0.1:8083:` — against a 401, pip **prompts** for a username. In the harness stdin was redirected so it failed at EOF, but on a developer's terminal a `--verify` run would sit there forever waiting for a credential it must never be given. The outer `bounded` wrapper rescues that only on a machine where `timeout(1)` exists, and a verification pass that can hang is indistinguishable from a slow network.
- **Fix:** `--no-input` (pip fails the request instead of prompting) and `--disable-pip-version-check` (an unrelated network warning was landing in the observed column). Re-measured under all three server conditions: with `--no-input`, pip's 401 output no longer carries an `HTTP error 401` line at all, so the row's diagnosis now comes from the simple-page probe — and still correctly names anonymous access.
- **Files modified:** `repos/security-platform/workstation/nexus-setup.sh`
- **Commit:** `9ec38b6`

**4. [Rule 2 — Missing security control] `insecure-registries` is conditional on a plain-http URL**

- **Found during:** Task 2, writing the daemon branch.
- **Issue:** The operator's recorded selection is "both `registry-mirrors` and `insecure-registries`, matching exactly what was measured, since `registry-mirrors` alone over plain HTTP is unmeasured". Taken unconditionally, that would write a TLS bypass for an `https://` Nexus — disabling a certificate check that is working, for no gain, which is precisely what ADR-009 forbids and precisely why the pip writer's `trusted-host` is already conditional.
- **Fix:** both keys for a plain-http URL, so an http run ships **exactly** the measured pair and the operator's reasoning is honoured where it applies; `registry-mirrors` alone for https, with a line printed saying why the second key is absent. The reasoning is stated in the source beside the branch.
- **Files modified:** `repos/security-platform/workstation/nexus-setup.sh`
- **Commit:** `ec9544d`

**5. [Rule 3 — Blocking] three commits rather than the plan's single one**

- **Found during:** Task 3.
- **Issue:** The plan places one commit in Task 3 covering all the work; the executor protocol commits per task. Task 3 is a measurement task and produces no file change of its own, so a literal reading would have left tasks 1 and 2 uncommitted until a task that changes nothing.
- **Fix:** one commit per task boundary — `c1df999` (verify pass), `ec9544d` (Docker branch) — plus `9ec38b6`, the Rule 1 fix task 3's own measurements exposed. Each commit's `git diff-tree --no-commit-id --name-only -r <sha>` lists exactly `workstation/nexus-setup.sh`, which is what the plan's singular-SHA acceptance criterion actually asserts. The gate state was predicted before each commit and observed to match: `ALL PASS - 11 checks, 1 skipped` at `c1df999` (`DOCKER-DAEMON-WARNING` still honestly skipped, no daemon code yet), `ALL PASS - 12 checks, 0 skipped` from `ec9544d` onward.
- **Files modified:** none beyond the above.

### Authentication Gates

None. Every fetch this plan made was unauthenticated on purpose — that is the property under test. The Nexus admin credential was generated at runtime into a mode-600 env file, used only by `provision.sh`, and destroyed with the container.

## Observations for the Verifier

1. **`SKIPPED` and `UNVERIFIABLE` increment `FAIL_COUNT`.** `--verify` therefore exits non-zero when npm is absent, or when the repository has no `package.json` for npm's local prefix to resolve against. That is deliberate and follows the plan's "any row that is not `ok` or `MANUAL`" wording: the operator asked for proof and did not get it. It does mean `--verify` on a Python-only repository will exit 1 on the npm row unless a `package.json` exists — worth a line in the README that plan 24-08 owns.
2. **The npm sample artefact is pinned, the pip one is not.** `lodash@4.17.21` is pinned because the licence-refusal probe has to build the tarball's component URL from the name and version; `six` is unpinned. All three are overridable through `NEXUS_VERIFY_NPM_NAME`, `NEXUS_VERIFY_NPM_VERSION` and `NEXUS_VERIFY_PIP_PACKAGE`.
3. **The helm row is the one that can fail for a legitimate reason.** The chart ships `repos.helm.remoteUrl: null` by design (D-05), so a Nexus provisioned without it has no `helm-proxy` at all and the row fails naming exactly that. The live measurement above used `--set repos.helm.remoteUrl=https://charts.jetstack.io`, as the live smoke does.
4. **`helm repo update` is the one unbounded call where `timeout(1)` is absent.** Helm v4 gives `repo update` no `--timeout` flag. `run_verify` prints a warning naming that call specifically when neither `timeout` nor `gtimeout` is on PATH, rather than claiming a bound it does not have. Both are present on this workstation.
5. **`HELM-NOT-HANDWRITTEN`'s source-level half can still be satisfied by prose** — the sensitivity plan 24-06 recorded in its own observations is unchanged here, and this plan does not own that file.

## Known Stubs

None. `--verify` is implemented, the Docker branch the operator selected is implemented, and there is no flag in this script that is recognised but inert.

## Threat Flags

None. Every trust boundary crossed is in the plan's `<threat_model>`, and each of T-24-34 through T-24-39 has an implemented, measured mitigation:

| Threat | Where it is mitigated | Evidence |
|--------|----------------------|----------|
| T-24-34 tampering with the operator's `daemon.json` | timestamped backup before any write; malformed JSON is a hard failure; jq appends at most once without reordering; canonicalised comparison no-ops a second run; restore command printed | §2b runs 1–3 |
| T-24-35 plaintext registry mirror without TLS | ADR-009 warning naming the directive's effect, the machine-global scope and the removal condition, printed beside the write; the key is not written at all for https | §2c, §2b run 4, `DOCKER-DAEMON-WARNING` PASS |
| T-24-36 a verification pass that tolerates failure | no `|| true` on any fetch (both occurrences are prose); every non-`ok`, non-`MANUAL` row increments `FAIL_COUNT`; docker can never report `ok` | §1a–§1d, §4 mutation 3, §7 |
| T-24-37 a 403 licence refusal read as a client misconfiguration | three distinct diagnoses, each naming the server-side value responsible; the 403 is classified by body size | §1a vs §1c vs §1d |
| T-24-38 the script hanging on an unresponsive endpoint | every fetch carries a client-side timeout and an outer `bounded` wall clock; the one call with no flag of its own is named in a warning when the wall clock is unavailable; the pip credential prompt — a hang by another route — is closed with `--no-input` | deviation 3, observation 4 |
| T-24-39 the script restarting the operator's Docker engine | never restarts it; prints the requirement and the restore command and leaves the action to the operator | `grep -c 'docker restart\|systemctl restart docker\|killall Docker'` → 0 |

## Self-Check: PASSED

- `repos/security-platform/workstation/nexus-setup.sh` — FOUND, 1,637 lines, mode `-rw-r--r--` (not executable)
- Commit `c1df999` — FOUND
- Commit `ec9544d` — FOUND
- Commit `9ec38b6` — FOUND
- `bash scripts/check-nexus-setup.sh` — re-run after the last commit, `ALL PASS - 12 check(s)`, exit 0
- `docker ps -a --filter name=v-` — empty; the 8083 instance is torn down
