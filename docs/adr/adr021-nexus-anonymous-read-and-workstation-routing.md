# ADR-021: Nexus Anonymous Read and Workstation Routing

**Status:** Accepted
**Date:** 2026-09-20
**Addresses:** NEXUS-02 — proxy repositories allow anonymous pull, with no authentication required for
read or proxy access — and NEXUS-04 — a workstation install script points a target repository's
package-manager configuration at a given Nexus instance

## Context

- **Anonymous read is closed on a default Nexus install, and Phase 23 shipped it closed deliberately.**
  Measured on a fresh `sonatype/nexus3:3.96.0-ubi` container: `GET /service/rest/v1/security/anonymous`
  returns 200 with `{"enabled": false, "userId": "anonymous", "realmName": "NexusAuthorizingRealm"}`, and
  `GET /service/rest/v1/security/realms/active` returns `[ "NexusAuthenticatingRealm" ]` — 30 bytes,
  padded inside the brackets, no trailing newline. Both facts are the starting state this record changes.
- **Two standing gates were written in Phase 23 specifically to make the closed posture measurable, not
  as decoration.** `check-nexus-chart.sh` check 8 (`ANONYMOUS-NOT-OPENED`) failed if the render emitted
  any anonymous configuration at all, and `nexus-live-smoke.sh`'s `ANONYMOUS-PULL-DENIED` asserted that
  an unauthenticated tarball fetch returned **401**. Both assert the negation of NEXUS-02. Per this
  project's Chesterton's-fence rule they were **inverted in the same commit as the calls that made them
  false**, never deleted — a red gate in git history would have been a lie about what the commit did.
- **ADR-020 states the posture stays closed, and ADR-020 may not be edited.** `docs/adr/` is append-only
  per `CLAUDE.md`. ADR-020 says "Opening read-only anonymous pull is NEXUS-02, a Phase 24 decision" and
  carries, as item 2 of its `## What was NOT verified`, "the Docker proxy's `docker.pathEnabled: true`
  shape is accepted and stored, but no image was ever pulled through it". This record supersedes the
  first **in prose** and closes the second **by reference**. ADR-020 is untouched.
- **Eight artefacts asserted the closed posture, only two of which were executable.** 24-RESEARCH.md's
  runtime-state inventory enumerated them: the two gates above, the `nexus3.config:` comment block in
  `values.yaml`, the chart README, ADR-020, the ADR index, `REQUIREMENTS.md`, and the body of merged PR
  #14 on `security-platform`. The last is a historical record of what was true when written and was
  deliberately left alone; ADR-020 is superseded here rather than edited; the rest were updated in this
  phase. The grep-visible surface was small and the state asserting the old behaviour was not, which is
  why the inventory exists at all.
- **This record extends three accepted decisions rather than reopening any of them.** ADR-020 established
  the chart base, the EULA opt-in and the `required` credential guard, all of which stand. ADR-009
  governs the warning wording for any plaintext-TLS-bypass directive, and this phase ships two of them.
  ADR-010 established that Nexus is a caching proxy with a single audit point rather than a supply-chain
  policy engine, and that a group repository must order hosted before proxy — guidance that opening
  anonymous read makes more consequential, not less. None of those files were edited.

## Decision

1. **Anonymous access is a wrapper-owned top-level `anonymous.enabled`, and it ships `false`.** The block
   carries `enabled`, `userId` and `realmName`, each rendered `| quote` into the provisioning Job's
   environment as `ANONYMOUS_ENABLED` / `ANONYMOUS_USER_ID` / `ANONYMOUS_REALM_NAME`. The rejected
   alternative is the subchart's `nexus3.config.anonymous.*`, which was **measured inert** in Phase 23 —
   toggling it produced a byte-identical render — and removed in `security-platform` commit `a9c4f38`;
   putting it back would ship a value that reads like a control and changes nothing. The default is
   opt-in because a public chart must not open unauthenticated read for someone who installs it without
   reading `values.yaml`, and because there is no TLS in front of the instance until Phase 25. Two
   offline checks hold the line: `ANONYMOUS-DEFAULT` asserts the shipped default, and
   `ANONYMOUS-VALUE-PRESENT` proves the **wiring** by toggling across two renders — a default render
   emits `"false"`, `--set anonymous.enabled=true` emits `"true"`. The wiring check reads the Job's env
   through `yq` rather than grepping the render, because with the env entry deleted a plain
   `grep -c 'ANONYMOUS_ENABLED'` still returned **7** matches from the embedded `provision.sh`.
2. **The anonymous PUT is unconditional, not guarded like the EULA POST.** The EULA guard exists because
   accepting a licence is a legal act performed on the consumer's behalf; anonymous access is declarative
   configuration persisted in the PVC. A guarded skip would leave `anonymous.enabled: false` unable to
   **close** access that a previous install, or a human in the UI, had opened. Measured across three
   consecutive runs against one instance: the PUT returns **200** (not 204 — the endpoint echoes the
   resulting object back), pass 1 logged `anonymous: OPEN (HTTP 200)`, pass 2 logged the same and read
   back `"enabled": true`, and pass 3 with `ANONYMOUS_ENABLED=false` logged `anonymous: CLOSED (HTTP 200)`
   and read back `"enabled": false`. The value closes as well as it opens, which is the property the
   unconditional shape buys.
3. **The `DockerToken` realm is appended unconditionally, decoupled from `anonymous.enabled`.** This
   diverges from 24-RESEARCH.md Pattern 2, which tied the realm to the anonymous value, and it rests on
   the research's own measurement: with the realms list at `["NexusAuthenticatingRealm"]` the token
   endpoint still returns 200 with a 48-character token, and the manifest request **carrying that token**
   returns 401 — and the identical 401 occurs for a token issued to the ADMIN user. The realm therefore
   governs Docker bearer-token validation generally rather than anonymity; Basic auth is unaffected,
   which is exactly why a curl-only test can miss it. Gating the realm on `ANONYMOUS_ENABLED` would have
   made the docker-proxy repository unusable by every Docker client whenever anonymous is off — the
   shipped default — which is a NEXUS-01 defect, not an anonymity posture.
4. **The realms PUT is a guarded GET-then-append-if-absent with a no-change skip.** Both traps were
   measured rather than assumed. The PUT **replaces the entire list**, so a body omitting
   `NexusAuthenticatingRealm` locks out every user including admin; and the API **stores duplicates**, so
   a blind `. + ["DockerToken"]` in a Job that reruns on every `helm upgrade` grows the list without
   bound. The implementation is `jq 'if index("DockerToken") then . else . + ["DockerToken"] end'` with
   **both sides normalised through `jq -c` before `cmp -s`** — the raw GET body is 30 bytes with no
   trailing newline while `jq -c` emits 28 bytes plus one, so an un-normalised comparison differs on
   every run, the no-change branch becomes dead code and the PUT is re-issued on every upgrade forever.
   The PUT returns 204. The live gate's `DOCKER-REALM-ACTIVE` reads the list back **after two consecutive
   provisioning passes** and asserts `["NexusAuthenticatingRealm","DockerToken"]` — `DockerToken` exactly
   once and `NexusAuthenticatingRealm` still present — with pass 2 logging `realms: DockerToken already
   active — no change, and no request was made`.
5. **The Docker pull path carries no `/repository/` segment, and this closes ADR-020's `## What was NOT
   verified` item 2** — by reference, without editing ADR-020. Measured unauthenticated against a
   provisioned instance: `/v2/docker-proxy/library/alpine/manifests/3.21` returns **200**, while
   `/v2/repository/docker-proxy/library/alpine/manifests/3.21` — the prefix copied from npm, PyPI and
   Helm by analogy — returns **404**. A third shape, `/repository/docker-proxy/v2/library/alpine/manifests/3.21`,
   returns 200 but **no Docker client can be made to emit it**, so it must never be documented as a pull
   target; it is named in the gate's own comment as a shape that works and must not be published. Item 2
   said no image was ever pulled through the proxy. One has been, twice over: the live gate's
   `ANONYMOUS-PULL-DOCKER` performs the full anonymous client handshake — `GET /v2/` returns 401 with a
   `Bearer` challenge, a token is minted **with no credential** at the endpoint the challenge itself
   advertises, the manifest returns 200 **with** `Authorization: Bearer`, and the `linux/amd64` layer
   blob `sha256:16333ee0…b8e5a` streams **3,626,020 bytes** — and `crane`, a real OCI client, exported
   **8,083,968 bytes** anonymously through the same repository and returned `404 Not Found` on the
   `/repository/`-prefixed reference. The check is red for the right reason when it should be: with the
   realm removed, leg 4 returns 401 while a header-less GET of the same URL still returns 200. That
   header-less 200 is recorded in the gate as evidence that must never be accepted.
6. **"Per-repository routing" means four different things, and the script says which one applies where.**
   npm has a native project scope: `.npmrc` is read as project configuration and is merged with
   `npm config set --location=project`, measured non-destructive — a seeded `_authToken` line and a
   `save-exact` line both survived byte-identically while the registry line was appended. pip and Helm
   have **no project scope at all**, so their files are inert until `PIP_CONFIG_FILE` and
   `HELM_REPOSITORY_CONFIG` / `HELM_REPOSITORY_CACHE` point at them — which is why one sourceable
   `.nexus-env` exists rather than four scattered exports, and why the Helm file is written by
   `helm repo add` under those variables instead of by hand. Docker has **no per-repository mechanism of
   any kind**: `NEXUS_DOCKER_REGISTRY` is a prefix string, routing an image is a manual edit of an image
   reference, and `--verify` reports Docker as `MANUAL` under every condition — including runs where
   `--docker-daemon` wrote a mirror. The `PIP_CONFIG_FILE` user-scope **replacement** is a measured
   consequence, not a caveat: with it set, `pip config list -v` no longer lists either user-scope
   variant, so a developer's own corporate CA bundle or extra index silently stops applying in that
   shell. It is stated in the generated file, in `--help`, and in the workstation README, and the file is
   never suggested for a shell rc. One further measurement shaped the verification pass: `pip config get
   global.index-url` exits 1 with `ERROR: No such key` on pip 26.2.1 under every scope flag against a
   file that plainly carries the key, because `get` reads only the writable scopes and cannot see the
   `:env:` variant `PIP_CONFIG_FILE` creates — the readback uses `pip config list`, which reports pip's
   merged view.
7. **Docker is configured by an opt-in `--docker-daemon` flag that writes the one mirror URL shape that
   was measured to route.** The operator selected `daemon-opt-in` at a blocking checkpoint with the
   evidence in front of them, and the evidence file records the verdict verbatim:

   ```
   VERDICT: A3-FALSIFIED-CANDIDATE-1
   ```

   Read precisely: a path-routed Nexus Docker proxy **can** serve as a Docker daemon `registry-mirrors`
   target, at the `<host>/repository/<docker-repo>` URL and only there. **Method matters here.** The
   measurement ran in Docker-in-Docker — `docker:28.3.2-dind`, pinned by manifest-list digest to the
   **exact** host engine version — and never on the operator's daemon, whose `~/.docker/daemon.json` the
   probe asserted byte-identical (`55a16d28…`) before and after every run from its own EXIT trap. The
   verdict rests on the **Nexus components-endpoint delta**, never on the pull exit code, because
   `registry-mirrors` falls back to Docker Hub silently: the path-only candidate `<host>/<docker-repo>`
   pulled successfully, exit 0, with real layer traffic on an image store that had just been destroyed —
   and Nexus went from 0 components to **0**. The `/repository/`-bearing candidate went from 0 to **1**,
   with `/library/alpine:3.21` appearing. A `docker pull` that succeeds with no components delta is not
   routing. The mechanism is in moby v28.3.2's own source: `lookupV2Endpoints` stores the whole mirror
   URL, path included, on the `APIEndpoint`, and the `/v2/` route is appended **after** the configured
   path — producing exactly the curl-only third shape from decision 5, which a daemon can emit even
   though no image reference can. The rejected alternative is the intuitive one, and it fails silently.
   Three obligations ship with the branch. **ADR-009** governs the printed warning: it names what
   `insecure-registries` does (it does not merely permit plain HTTP — it disables TLS verification for
   that host entirely), states that the change is **machine-global** unlike everything else this script
   writes, prints the timestamped backup path and the restore command, and says the directive must be
   removed once TLS is configured. The same obligation is carried by the `trusted-host` line in the
   generated `pip.conf`, which is emitted **only** for plain http to a non-loopback host because pip's
   own `SECURE_ORIGINS` already trusts https anywhere and any scheme to loopback. **The operator's
   literal words were refined, deliberately:** they asked for "both keys, matching exactly what was
   measured", and `insecure-registries` is therefore written for a plain-http `--url` — the pair that
   was measured — and **not** for an https one, where it would disable a certificate check that is
   working. That refinement is named here so a future reader comparing the script to the quoted decision
   does not read the difference as a defect. Finally, the script never restarts the engine — it prints
   that the operator must — and never claims Docker is fully routed: per moby's `loadMirrors`, the mirror
   list is attached to the `docker.io` index and every other index is built with an empty list, so
   `ghcr.io`, `quay.io`, `public.ecr.aws` and every other registry are untouched by any mirror value.
   This is the **one global-workstation-default exception** carved out of `REQUIREMENTS.md`'s Out of
   Scope row, an amendment the user made knowingly during context gathering; the flag being off by
   default keeps a plain run per-repository only.
8. **Generated configuration is gitignored by default, with a `--commit-config` escape hatch.** A
   committed `.npmrc` or `pip.conf` pointing at one operator's Nexus is a dependency-resolution failure
   for every contributor who cannot reach that host, and an internal-hostname disclosure if the
   repository is public. The escape hatch exists because a team that all share one reachable Nexus has a
   legitimate reason to commit the files, and it prints its rationale rather than silently skipping.
   Where `.npmrc` is **already** git-tracked, gitignoring is a no-op and the script says so explicitly
   instead of leaving the developer believing they are covered.
9. **The `provision.readiness.*` knobs are wired through, which closes Phase 23 deferred item 2.** They
   are rendered from `values.yaml` into the Job as `READY_ATTEMPTS` / `READY_INTERVAL`, named in
   `provision.sh`'s environment contract and in its hard-failure sentence, and set by the live smoke's
   `run_provision`. They are read with **no `:-` default**, so deleting the env entry from the template
   is a `set -u` hard failure in the Job rather than a silent fallback to 60/10 — the same let-it-crash
   discipline the rest of the script follows. Measured end to end: a default render emits `"60"` and
   `"10"`, `--set provision.readiness.attempts=7 --set provision.readiness.intervalSeconds=3` emits
   `"7"` and `"3"`, and `provision.sh` run directly with `READY_ATTEMPTS=2 READY_INTERVAL=1` against a
   port with nothing listening exits 1 after `attempt 2/2` in two seconds where the old hardcode would
   have polled for ten minutes. The rejected alternative was deleting the keys and the README's values
   table and limitations bullet together; wiring them through was chosen because the poll budget is a
   real consumer concern on a cold-booting instance. `provision.activeDeadlineSeconds` remains the one
   hard ceiling and the relationship is stated at the knob.
10. **Checkov's zero coverage of `kubernetes/nexus` is accepted and documented rather than solved, which
    closes Phase 23 deferred item 3.** The measurement stands as ADR-020 recorded it: the pinned
    `ghcr.io/bridgecrewio/checkov:3.3.17` container ships its own Helm, so the helm runner **does**
    engage, runs `helm dependency update` successfully, and then fails at `helm template` on the chart's
    own `required` credential guard — logged at `WARNI`, not raising the exit code. **24**
    kubernetes-framework findings exist latently (5 on the wrapper's own resources, 19 on the subchart's
    StatefulSet, Services, ServiceAccount and ConfigMaps) and none of them reach the pipeline, so zero
    findings in CI must not be read as a clean bill of health. Both alternatives were rejected for the
    same reason: a scanner-only values file and a committed rendered manifest each create a **second
    artefact that drifts from the real one by construction**, and a scanner passing against a stale
    rendering is worse than a scanner that is honestly absent. This phase also adds no Kubernetes
    resource — it adds environment variables to an existing Job — so the blind spot is not widened here.
    **ADR-020's prohibition stands: the `required` credential guard must not be weakened to obtain
    coverage.** Trading a no-default-credential guarantee for a scanner's convenience is the wrong
    direction, and the guard is a locked mitigation of Phase 23's threat model.

## Consequences

**Improved:** NEXUS-02 is measured rather than asserted, in four ecosystems, with byte counts. Against a
provisioned instance with no credential presented anywhere: an npm tarball at **318,961** bytes, a PyPI
per-project simple page at **76,776** bytes, a Helm `index.yaml` at **291,818** bytes, and a Docker layer
blob at **3,626,020** bytes through the full bearer handshake. Every one of those fetches is a standing
live check with a byte floor derived from the measured size under a stated rule, split so that a
transport failure, a wrong status and a refusal body are three distinguishable failures and none can mask
another. The live gate went **13 → 25 checks, 0 skipped, ALL PASS**, and the offline gate **17 → 18
checks, 0 failures**, with the two Phase 23 negation checks inverted in the same commits as the calls
that made them false.

**Improved:** NEXUS-04 ends on evidence rather than on a claim. `--verify` is mandatory in the sense that
matters — nothing in the script prints a success line — and for each ecosystem it asks the **client**
what it resolves and then pulls a **real component** through it with the cache disabled, because a cached
artefact satisfies "a file appeared" with zero packets. Three server-side conditions are distinguishable
and each names the value responsible: an unreachable endpoint (curl exit 7), HTTP 401 naming
`anonymous.enabled`, and HTTP 403 with a body under ~1,000 bytes naming `eula.accepted`. The 403 is
classified by **body size** rather than by status alone, because the licence refusal is a perfectly
well-formed 192-byte response. `SKIPPED` and `UNVERIFIABLE` both count as failures, so a repository with
no `package.json` — where npm's local prefix resolves somewhere else up the tree and the readback agrees
for the wrong reason — is never reported as a pass. The workstation gate reads `ALL PASS - 12 checks, 0
skipped`, and its assertions were proven non-vacuous against the shipped file: three single-defect
mutations each produced exactly one red check, each the predicted one.

**Improved:** the EULA and anonymous gates are now known to be **independent**, and the boundary between
them is written where it is load-bearing. Under `eula.accepted: false` with anonymous open, the npm
tarball and the Helm `index.yaml` both return **403 at 192 bytes** while the PyPI per-project simple page
returns **200 with its full 76,776 bytes** — the licence gate covers component *downloads*, and a simple
page is metadata. pip's own output corroborates it from the client side in a single command: `Looking in
indexes:` succeeds, the metadata for the sample package is fetched, and the component under `/packages/`
is refused 403. The practical consequence is a rule the script obeys: a PyPI simple-page 200 is **not**
evidence of an accepted licence, so the licence diagnosis is derived from a component download.

**Tradeoff — anonymous read is all-repository and cannot be narrowed in place.** The built-in
`nx-anonymous` role is `readOnly: true` and its privileges are `nx-repository-view-*-*-read` and
`nx-repository-view-*-*-browse` — wildcards on format **and** repository name — so a hosted repository
added in a future phase is world-readable from the moment it is created, silently, with no change to any
value in this chart. What is mitigated: the property is documented as a property of NEXUS-02 at the value
itself, in the chart README and here, and the remedy is named — create a custom role limited to the four
proxies and rebind the anonymous user to it. What is not mitigated: nothing enforces any of that, and
this intersects **ADR-010's** dependency-confusion guidance directly. That record requires a group
repository to order hosted before proxy; a world-readable hosted repository makes an ordering mistake
more consequential, because the internal package names an attacker needs in order to exploit it are now
readable by anyone who can reach the instance.

**Tradeoff — the repository inventory is anonymously readable.** `GET /service/rest/v1/repositories`
answers 200 with no credential: repository names, formats, types and this instance's own URLs. The
disclosure is bounded — no remote URLs, no credentials — but it is a list of what the instance proxies
and, combined with the wildcard scope above, a list of what can be read. Accepted and recorded rather
than fixed; narrowing it is the same custom-role work.

**Tradeoff — everything here is plaintext HTTP until Phase 25's ingress.** Every status code, byte count
and handshake in this record was measured over `http://` to loopback or to a throwaway container network.
Unauthenticated read over plaintext on a shared network is an information disclosure whose only control
is network reach, and NetworkPolicy namespace isolation is **explicitly out of scope** for this milestone
(ADR-008 carries the guidance; `REQUIREMENTS.md` defers the implementation). The two plaintext directives
the workstation script can emit — pip's `trusted-host` and Docker's `insecure-registries` — are each
written only where the client genuinely refuses otherwise, and each carries ADR-009's removal sentence
beside it in the generated file rather than only in the generator. That mitigates the symptom, not the
cause.

**Tradeoff — Community Edition's usage ceilings get easier to reach.** ADR-020 recorded them: **40,000**
total components and **100,000** requests per day, beyond which Community Edition's safeguards pause the
addition of new components. Removing the authentication friction is precisely what makes it easy to point
a CI fleet at the instance, so this decision moves the instance toward those ceilings rather than away.
No chart value raises them; the counter is documented beside the `anonymous` value so a consumer meets
the limit in the values file rather than in production.

**Tradeoff — the `/repository/` segment means opposite things in two places.** The daemon mirror URL
**requires** it; the image reference **forbids** it. Both were measured, and the intuitive unification is
wrong in both directions. What is mitigated: the asymmetry is stated together in the generated
`.nexus-env`, in both READMEs and in the live gate, where `DOCKER-PATH-SHAPE` fails if the 404 shape ever
starts working or the 200 shape stops. What is not mitigated: a reader who "corrects" one to match the
other breaks it — and in the mirror's case breaks it **silently**, because the pull still succeeds
against Docker Hub.

## What was NOT verified

1. **No pull was performed by the operator's own Docker daemon.** Three substitutes stand in, and each is
   named rather than blurred into "a Docker client": `crane`, a real OCI client, run anonymously inside
   the Nexus container's network namespace; `curl` speaking the OCI distribution protocol leg by leg,
   which is what the live gate asserts; and a privileged `docker:28.3.2-dind` engine pinned to the exact
   host version, which is what produced the A3 verdict. What remains unmeasured is the **Docker Desktop
   VM boundary** — the operator's own engine was never configured with either mirror and was never
   restarted. One hedge is removed: this host reports `Storage Driver: overlay2`, the same classic image
   store dind used, so the containerd-snapshotter path (where mirrors are configured through
   `hosts.toml` instead) does not apply here. The `--docker-daemon` branch's first real run is the
   operator's, and the thing to check afterwards is the Nexus components count, not the pull exit code.
2. **`forceBasicAuth`'s documented-versus-measured divergence, carried forward from Phase 23 and still
   unresolved.** Sonatype documents that Docker pulls "also require enabling a repository-level setting
   on each Docker repository". That did **not** reproduce on 3.96.0: with `docker.forceBasicAuth: true`
   the `/v2/` challenge is still `Bearer` rather than `Basic`, the token still issues, and the manifest
   carrying that token still returns 200. The chart's `forceBasicAuth: false` is semantically correct and
   stays, but it must **not** be documented as the control that makes anonymous Docker pull work — the
   `DockerToken` realm is. Recorded as a divergence between documentation and measurement, not settled.
3. **Checkov still provides zero coverage of this chart.** Decision 10 accepts the blind spot and
   documents it; it does not close it. The 24 latent findings were measured once, locally, against a
   render with a dummy Secret name, and have **not** been re-measured against the chart as this phase
   leaves it. This phase adds no Kubernetes resource, so the count is *expected* to be unchanged rather
   than *known* to be. The revisit trigger is a second chart in the repository, which doubles the blind
   spot without changing any of the reasoning.
4. **Nothing was measured against a TLS-terminated Nexus, and no ingress exists yet.** Every measurement
   in this record is plaintext. The daemon's own TLS and insecure-registry handling against a real
   hostname, certificate verification by any of the four clients, and the behaviour of the mirror URL
   under https are all untested, and Phase 25's ingress is the first TLS anywhere in this stack.
5. **A custom anonymous role scoped to the four proxy repositories was not built.** The remedy for the
   wildcard scope is described here and in the chart README, and it is not implemented: no role is
   created by the chart, the anonymous user is not rebound, and no gate asserts anything about the
   scope. It is a described remedy, not a shipped one.
6. **Phase 25 input, stated as a named hand-off so the overlay is written once: the private ArgoCD
   overlay must set `anonymous.enabled: true` explicitly.** The chart ships the value `false` by decision
   1. If the overlay omits it, the first live deploy ships NEXUS-02 **closed**, and the live gate's nine
   anonymous verdicts plus the full Docker handshake go red against real infrastructure — correct
   behaviour for a closed instance, and a confusing first result to debug on a homelab cluster. The
   overlay also needs the readiness budget of decision 9 if the cold-boot time there differs from the
   container measurements.
7. **No `helm upgrade` of an existing install was exercised.** Both new REST calls reach an already-
   deployed instance only through the post-upgrade hook Job, and every measurement in this phase was made
   against a freshly booted container or a fresh `kind` install. The guarded realms append is what makes
   a repeated upgrade safe, and it was proven across two consecutive provisioning passes on one instance
   — not across an upgrade of an instance whose PVC already carried Phase 23's state, including its
   `["NexusAuthenticatingRealm"]` realms list and its `enabled: false` anonymous setting. Phase 25
   confirms it on the homelab instance rather than assuming it. ADR-020's item 3 is likewise unchanged:
   ArgoCD's treatment of this chart's hook annotations remains training knowledge, not an observation.
