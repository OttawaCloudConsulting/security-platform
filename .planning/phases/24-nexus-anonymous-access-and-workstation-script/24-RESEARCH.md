# Phase 24: Nexus Anonymous Access and Workstation Script - Research

**Researched:** 2026-09-19
**Domain:** Nexus Repository 3 security/authorization REST API; per-repository package-manager client configuration (npm / pip / Helm / OCI)
**Confidence:** HIGH. Every finding was measured against a live Nexus 3.96.0 CE instance, this workstation's own package-manager clients, and — for the Docker half — a real OCI client (`crane`) executing complete anonymous pulls through the chart's own proxy.

---

<user_constraints>
## User Constraints

**No `24-CONTEXT.md` exists.** `/gsd:discuss-phase` has not been run for Phase 24, so there are
no locked user decisions for this phase. Everything below marked as a recommendation is the
researcher's reading of the requirements, not a user decision — the Assumptions Log names each
one that discuss-phase should confirm or overturn.

In the absence of CONTEXT.md, the binding constraints are the two **Out of Scope** rows in
`.planning/REQUIREMENTS.md` that name this phase's subject matter. Copied verbatim:

| Feature | Reason |
|---------|--------|
| Nexus authenticated push/publish | Anonymous pull only for v3.0; authenticated publish deferred |
| Workstation pkg managers routed through Nexus outside the per-repo config | Per-repo config + install script only, not global workstation defaults |

Two further Out of Scope rows constrain what this phase may reach for as a mitigation:

| Feature | Reason |
|---------|--------|
| NetworkPolicy namespace isolation for Nexus/DefectDojo | Hardening bucket, separate from this milestone's Infra & Dashboards scope |
| Backup automation (DefectDojo PostgreSQL, Nexus PVC) | Hardening bucket, deferred |

**Consequence for the planner.** The second row is the single most design-shaping constraint in
this phase. "Per-repo config + install script only, not global workstation defaults" is
**satisfiable for npm, pip and Helm and not satisfiable for Docker** — Docker has no per-repository
configuration mechanism at all (§Architecture Patterns, Pattern 4). That is a measured property of
the Docker client, not an implementation shortfall. Open Question 1 asks the user to choose how
NEXUS-04's words "Docker/Helm registry config" should be read given that.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (verbatim from REQUIREMENTS.md) | Research Support |
|----|---------------------------------------------|------------------|
| **NEXUS-02** | Proxy repos allow anonymous pull (no auth required for read/proxy access) | Measured end to end: the two REST calls required, their bodies, status codes and idempotency traps, the four resulting anonymous fetches with byte counts, the complete anonymous Docker client handshake, and the full set of things anonymous is still refused. §Code Examples 1-4, §Security Domain. |
| **NEXUS-04** | Workstation install script configures a target repo's package manager files (`.npmrc`, `pip.conf`, Docker/Helm registry config) to route through a given Nexus instance | Measured per-ecosystem: which config scopes exist, which are genuinely per-repo, the exact URL shape each client needs, and a real anonymous fetch through each. §Architecture Patterns, §Code Examples 5-8. Docker is the outlier — see Open Question 1. |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

Both the project `CLAUDE.md` and the `.claude/rules/` files it pulls in carry directives the
planner must honour. Extracted:

| Directive | Source | Effect on this phase |
|-----------|--------|----------------------|
| This repository is **reference documentation, not buildable software**. The canonical Helm charts and workflows live in `OttawaCloudConsulting/security-platform`, in `kubernetes/<service>/`. | CLAUDE.md §What This Repository Is | Every chart edit and every script this phase writes lands in `security-platform` (working copy at `repos/security-platform`, currently on `main` at `ea2770f`, clean). This repository gets the ADR, the requirement checkbox and the roadmap row. This is exactly the split Phase 23 used. |
| `docs/adr/` records are **append-only** — add new files, do not modify accepted ones. | CLAUDE.md §Editing Guidelines | ADR-020 asserts anonymous access is deliberately not opened. It **must not be edited**. Phase 24 writes **ADR-021** and adds one index row. Next free number confirmed: ADR-020 is the last row in `docs/adr/README.md`. |
| Preserve ASCII architecture diagrams, the 4-phase layered structure, tool coverage matrices. | CLAUDE.md §Editing Guidelines | Any edit to `docs/development-security-stack-option-1.md` keeps those intact. |
| **Never set the executable bit on script files.** Always invoke with an explicit interpreter: `bash scripts/x.sh`. | rules/anti-slop §Script Safety | The new workstation script ships **non-executable** and is documented as `bash workstation/<name>.sh`. `kubernetes/nexus/files/provision.sh` already follows this — the ConfigMap supplies `defaultMode: 0555` in-cluster. |
| Silent fallbacks (`\|\| true`, `try/except: pass`) convert hard failure into silent corruption. **Let it crash.** | rules/anti-slop §Error Handling | The new REST calls in `provision.sh` get the same hard-fail treatment as the EULA call: an unexpected status code exits 1. The workstation script must not `\|\| true` a failed verification fetch. |
| Before changing anything, list what reads/writes/depends on it. "Nothing else uses this" is usually wrong. | rules/anti-slop §Second-Order Effects | §Runtime State Inventory is that list. Eight artefacts currently assert the opposite of NEXUS-02. |
| **Chesterton's Fence** — articulate why a thing exists before removing or changing it. | rules/epistemology | `ANONYMOUS-NOT-OPENED` and `ANONYMOUS-PULL-DENIED` are not stale cruft; they were deliberately written in Phase 23 to make a claim measurable. They get **inverted**, not deleted. |
| Evidence standards: state what was actually tested, never "all items show X" from a sample. | rules/anti-slop §Evidence Standards | Every status code and byte count in this document was observed in this session. Where a first measurement was later shown to have skipped a leg of the real client protocol, the correction is recorded in the open rather than quietly replaced — see §State of the Art row 1. |

---

## Summary

Phase 24 has two halves that share exactly one thing — a URL — and almost nothing else.

**The Nexus half is two REST calls with a large blast radius, not one.** Enabling anonymous pull is
an idempotent `PUT /service/rest/v1/security/anonymous`, measured returning **HTTP 200** on both a
first and a repeat call. After it, npm, PyPI and Helm serve real artefacts to a completely
unauthenticated client — measured: a 318,961-byte npm tarball, a 76,776-byte PyPI simple index, a
291,818-byte Helm `index.yaml`. **Docker needs a second call.** Phase 23's hand-off note that
anonymous `docker pull` also requires activating the `DockerToken` realm is **correct, and this
research initially contradicted it in error**: a first causal test fetched the Docker manifest with
no `Authorization` header and saw 200 with the realm removed, which looked like proof the realm was
unnecessary. It is not, because no Docker client ever makes that request. A real client pings
`/v2/`, receives a 401 with a `Bearer` challenge, fetches a token, and **presents it**. Measured
with the realm removed: token issuance still returns 200, and the manifest request carrying that
token returns **401**. The same holds for an admin-issued token, so the realm governs bearer-token
validation generally, not anonymity. Both calls are required, and the realms call carries two traps
— a PUT replaces the entire list (omitting `NexusAuthenticatingRealm` locks out every user), and
the API **stores duplicates** (a blind `. + ["DockerToken"]` in an idempotent hook Job grows the
list on every upgrade; measured).

The rest of the Nexus half is that eight existing artefacts — two standing gate scripts, a
values.yaml comment block, a chart README, an ADR, a requirements table, a roadmap row and a PR
body — all currently assert that anonymous access is closed, several with prose written
specifically to make that claim measurable. Two of them are **assertions that will go red** the
moment the calls land. Inverting them is most of the phase's real surface area.

**The workstation half is constrained by a fact about package managers the requirement's wording
does not anticipate.** "Per-repo config" means four different things across the four ecosystems,
and for one it means *nothing at all*. npm is native — `.npmrc` at a project root is first-class
"project" config, confirmed by `npm config list`. pip has no project scope whatsoever —
`pip config list -v` enumerates global, user and site paths and no cwd-relative path exists — so a
repo-local `pip.conf` only takes effect through `PIP_CONFIG_FILE`. Helm is the same shape:
`helm repo add` writes a global `repositories.yaml` unless `HELM_REPOSITORY_CONFIG` redirects it,
which it does, measured, with the operator's real global repo list left untouched. **Docker has no
per-repository mechanism at all**: `registry-mirrors` and `insecure-registries` are daemon-global
keys in `daemon.json`, and the only per-repo lever is rewriting image references — which collides
directly with the REQUIREMENTS.md row forbidding global workstation defaults.

**Primary recommendation:** ship a new wrapper-owned top-level `anonymous.enabled` value (**not**
under `nexus3.config.*`, which Phase 23 measured to be inert); have `provision.sh` perform both the
anonymous PUT and a guarded GET-then-append-if-absent realms PUT; invert the two gates in the same
commit that lands the calls; and write `workstation/nexus-setup.sh` that produces a repo-local
`.npmrc` + `pip.conf` + `.helm/repositories.yaml` plus one sourceable `.nexus-env` carrying
`PIP_CONFIG_FILE`, `HELM_REPOSITORY_CONFIG` and a `NEXUS_DOCKER_REGISTRY` prefix — treating Docker
as an explicitly documented partial, not a silently missing feature.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Anonymous read enablement | **Nexus application state** (REST API) | Helm post-install hook Job | Not a manifest property. It survives in the PVC, not in the render. Phase 23 already established the hook Job as the only place this chart mutates application state; adding calls there is an extension, not a new mechanism. |
| The `anonymous.enabled` **decision** | Helm values (wrapper-owned) | Chart README | A consumer of a public chart must be able to refuse anonymous access. Same shape as `eula.accepted`. |
| Anonymous **authorization scope** (which repos) | Nexus roles/privileges | — | Governed by the built-in `nx-anonymous` role, which is `readOnly: true` and wildcards **all** repositories. Narrowing it means creating a new role, not editing that one. See §Security Domain. |
| **Docker bearer-token validation** | **Nexus active-realms list** (`DockerToken`) | Helm hook Job | **Required** — measured. Without it every bearer token, anonymous or admin-issued, is refused 401 on the manifest request, which is the request every Docker client makes. Basic auth is unaffected, which is why a curl-only test can miss it. |
| npm registry routing | **Repo working tree** (`.npmrc`) | — | Genuinely per-repo; npm reads it as "project" config. |
| PyPI index routing | Repo working tree (`pip.conf`) + **shell environment** (`PIP_CONFIG_FILE`) | venv-local `pip.conf` | pip has no project config scope. The env var is load-bearing, not convenience. |
| Helm chart repo routing | Repo working tree (`.helm/repositories.yaml`) + **shell environment** (`HELM_REPOSITORY_CONFIG`) | — | Same shape as pip. The file must be written by `helm repo add`, not by hand. |
| Docker registry routing (client side) | **Image references in source** (Dockerfile / compose) | Docker daemon (global, out of scope) | No per-repo config file exists. This is the tier mismatch Open Question 1 exists to resolve. |
| Gate/assertion inversion | `security-platform/scripts/` | — | Both gates live beside the chart and are run by hand per Phase 23's convention. |
| Decision record | **This repository** (`docs/adr/adr021-*.md`) | `docs/adr/README.md` index | ADR-020 is accepted and append-only. |

---

## Standard Stack

### Core

This phase **installs no new packages in any ecosystem.** Everything it needs is already present
in `security-platform` or already on the operator's workstation.

| Component | Version | Purpose | Why it is the standard here |
|-----------|---------|---------|------------------------------|
| Nexus Repository CE | 3.96.0 (resolved from `stevehipwell/nexus3` 5.26.0 `appVersion`) | The subject | Fixed by ADR-020; not a choice this phase reopens. [VERIFIED: rendered from `kubernetes/nexus` and booted this session] |
| Nexus Security REST API v1 | `/service/rest/v1/security/anonymous` (`get`, `put`) and `/service/rest/v1/security/realms/active` (`get`, `put`) | Anonymous enablement; Docker bearer-token realm | The only non-deprecated mechanism. The Groovy scripting API answers **410** (Phase 23) and `nexus.scripts.allowCreation` stays off. [VERIFIED: `/service/rest/swagger.json` on the live instance lists exactly those methods for those paths] |
| `kubernetes/nexus/files/provision.sh` | in-repo | Where both new calls go | Already owns EULA acceptance and repo upsert; already has bounded `curl`, a `HTTP_CODE` global, and hard-fail semantics. Extending it costs ~30 lines. |
| `bash` + `curl` + `jq` | `alpine/k8s:1.31.2` @ `sha256:d489e3c…` | Job runtime | Already pinned in `values.yaml`. `jq` is what makes the guarded realm append possible. |
| `bash` (workstation) | 3.2+ / 5.x | Install script | `workstation/setup.sh` is bash and already the convention. |
| `helm` CLI | 4.3.0 measured locally; any v3+ | Writes `repositories.yaml` | See §Don't Hand-Roll — the file format is Helm's, not ours. |
| `npm` CLI | 11.7.0 measured | Merges `.npmrc` | `npm config set --location=project` merges non-destructively. See §Don't Hand-Roll. |

### Supporting

| Component | Purpose | When to use |
|-----------|---------|-------------|
| `scripts/check-nexus-chart.sh` | Offline chart gate, 17 checks | Extend + invert check 8. |
| `scripts/nexus-live-smoke.sh` | Live gate, 13 checks | Extend + invert `ANONYMOUS-PULL-DENIED`. |
| `shellcheck` | Lint the new script | Already a pre-commit hook in `security-platform`. |
| `docker` 28.3.2 + `kind` 0.33.0 | Live smoke substrate | Both present; the live gate's two halves both run here. |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| `PUT /security/anonymous` from `provision.sh` | The subchart's own `config.anonymous.*` values | **Rejected on measured evidence.** Phase 23 rendered the chart with that key flipped and got byte-identical output — it is read only inside `{{- if .Values.config.enabled }}`, which this wrapper pins to `false`. Enabling `config.enabled` to reach it would turn the Groovy scripting API back on, which ADR-020 forbids. |
| A guarded GET-then-append realms PUT | A literal `PUT ["NexusAuthenticatingRealm","DockerToken"]` | Shorter, and wrong twice over: it silently discards any realm a consumer added (LDAP, NpmToken, a future SSO realm), and it hardcodes an assumption about the pre-existing list. Both are one `helm upgrade` away from an outage. |
| A guarded append | A blind `jq '. + ["DockerToken"]'` | **Rejected on measured evidence.** The API accepts and *stores* duplicates: PUT `["NexusAuthenticatingRealm","DockerToken","DockerToken"]` → 204, and the readback contains both. In a Job that reruns on every upgrade the list grows without bound. Guard with `if index("DockerToken") then . else . + ["DockerToken"] end`. |
| Built-in `nx-anonymous` role as-is | A custom role scoped to the four proxy repos | The built-in role wildcards **all** repositories (`nx-repository-view-*-*-read`). A custom role is the correct long-term answer if hosted repos ever appear, but it is additional Nexus state this phase has no requirement for. Recommended as documented follow-up, not as scope. See Assumption A4. |
| Repo-local `pip.conf` + `PIP_CONFIG_FILE` | `--index-url` line inside `requirements.txt` | The requirements-file form travels with the repo and needs no env var, but it hardcodes one operator's Nexus hostname into a committed dependency manifest and breaks every other consumer of that repo. Rejected. |
| Repo-local `pip.conf` + `PIP_CONFIG_FILE` | A venv-local `<venv>/pip.conf` | Genuinely per-project and needs no env var, but requires a venv to exist and is destroyed by `rm -rf .venv`. Worth offering as a `--venv` mode; not the default. |
| Docker daemon `registry-mirrors` | Image-reference rewriting | The daemon key is global and is the exact thing REQUIREMENTS.md puts out of scope. See Open Question 1. |

**Installation:** none. No `npm install`, no `pip install`, no `helm repo add` of a new dependency,
no change to `Chart.yaml` or `Chart.lock`.

---

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.**

The slopcheck gate was not run because there is nothing for it to check: no new npm, PyPI, crates
or Helm dependency is introduced. `Chart.lock` is untouched (`stevehipwell/nexus3` stays pinned at
5.26.0), and both container images referenced by the chart (`cgr.dev/chainguard/bash` and
`docker.io/alpine/k8s:1.31.2`) remain digest-pinned at the values Phase 23 measured. If a plan in
this phase does introduce a dependency, that plan must run the Package Legitimacy Gate before the
install task.

---

## Architecture Patterns

### System architecture diagram

```
 WORKSTATION (per-repo scope)                          CLUSTER
 ───────────────────────────                           ───────
                                                       ┌──────────────────────────────┐
  developer runs:                                      │  helm install / ArgoCD sync  │
  bash workstation/nexus-setup.sh --url $NEXUS         └──────────────┬───────────────┘
        │                                                             │ post-install/upgrade hook
        │ writes into $(git rev-parse --show-toplevel)                ▼
        │                                              ┌──────────────────────────────┐
        ├──► .npmrc         registry=$NEXUS/repository/npm-proxy/     provision Job    │
        │                     (npm reads natively — "project" config) │                │
        │                                              │  1. poll /status/writable     │
        ├──► pip.conf       [global] index-url=…/simple│  2. EULA  (opt-in)  → 204     │
        │                     (+ trusted-host if http  │  3. ANONYMOUS (NEW) → 200  ◄── NEXUS-02
        │                      and NOT loopback)       │     PUT /v1/security/anonymous│
        │                                              │  4. REALMS   (NEW)  → 204  ◄── NEXUS-02
        ├──► .helm/repositories.yaml                   │     GET, append DockerToken   │
        │      written by `helm repo add`, never by hand│     IF ABSENT, PUT full list │
        │                                              │  5. upsert 4 proxy repos      │
        └──► .nexus-env   (must be `source`d)          └──────────────┬───────────────┘
               export PIP_CONFIG_FILE=…/pip.conf                      │
               export HELM_REPOSITORY_CONFIG=…         ┌──────────────▼───────────────┐
               export HELM_REPOSITORY_CACHE=…          │      Nexus Repository CE      │
               export NEXUS_DOCKER_REGISTRY=host/docker-proxy                          │
                        │                              │  anonymous ──► nx-anonymous   │
                        │                              │       (read + browse, ALL)    │
                        ▼                              │  realms: NexusAuthenticating  │
         Docker: NO per-repo config exists.            │        + DockerToken          │
         Only lever = image reference prefix           │                               │
         FROM ${NEXUS_DOCKER_REGISTRY}/library/alpine  │  npm-proxy  pypi-proxy        │
         ──► see Open Question 1                       │  docker-proxy  helm-proxy     │
                                                       └──────────────┬───────────────┘
                                                                      │ (cache miss)
                                                                      ▼
                                                        registry.npmjs.org · pypi.org
                                                        registry-1.docker.io · <helm remote>

 ── request shapes, all measured anonymous ──
   npm    GET  $NEXUS/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz     200  318,961 B
   pypi   GET  $NEXUS/repository/pypi-proxy/simple/requests/               200   76,776 B
   helm   GET  $NEXUS/repository/helm-proxy/index.yaml                     200  291,818 B
   docker GET  $NEXUS/v2/                                     401 + Bearer challenge
          GET  $NEXUS/repository/docker-proxy/v2/token        200  (48-char token)
          GET  $NEXUS/v2/docker-proxy/…/manifests/3.21        200  (Bearer)  ⚠ NO /repository/
          GET  $NEXUS/v2/docker-proxy/…/blobs/sha256:16333…   200  3,626,020 B
```

### Pattern 1: Both Nexus calls go in the existing hook Job, in order

**What:** Add two ordered steps to `provision.sh`, between EULA acceptance and repository upsert.

**When to use:** Whenever `anonymous.enabled` is set by the consumer.

**Why before the upsert:** anonymous read of a repository that does not exist yet is meaningless,
and anonymous read with an unaccepted EULA is a 403 (Pitfall 2). Ordering the security state before
the content keeps the shape the script already has.

**Step A — anonymous access.**

```bash
# Source: measured against sonatype/nexus3:3.96.0-ubi this session.
# Style matches kubernetes/nexus/files/provision.sh — HTTP_CODE global, hard fail, both branches log.

anon_body="${TMP_DIR}/anonymous.json"
# userId and realmName are echoed at Nexus's own defaults rather than invented:
# GET /service/rest/v1/security/anonymous on a fresh instance returns
#   {"enabled": false, "userId": "anonymous", "realmName": "NexusAuthorizingRealm"}
jq -n --argjson enabled "${ANONYMOUS_ENABLED}" \
      --arg userId "${ANONYMOUS_USER_ID}" \
      --arg realmName "${ANONYMOUS_REALM_NAME}" \
      '{enabled: $enabled, userId: $userId, realmName: $realmName}' >"${anon_body}"

http_status "${NEXUS_HOST}/service/rest/v1/security/anonymous" \
  -X PUT -H 'Content-Type: application/json' -d "@${anon_body}"

# 200, NOT 204. The endpoint echoes the resulting object back.
if [ "${HTTP_CODE}" != "200" ]; then
  echo "FATAL: PUT /service/rest/v1/security/anonymous returned HTTP ${HTTP_CODE}, expected 200" >&2
  exit 1
fi
echo "anonymous: set enabled=${ANONYMOUS_ENABLED} (HTTP 200). Idempotent — a re-run returns 200 again."
```

**Step B — the `DockerToken` realm, appended only if absent.**

```bash
# WHY THIS EXISTS. Every Docker client pings /v2/, receives 401 with a Bearer challenge,
# fetches a token, and PRESENTS it. Measured with DockerToken inactive: the token endpoint
# still returns 200, and the manifest request carrying that token returns 401. Anonymous
# pull therefore fails for a real client even though a header-less curl of the same URL
# returns 200. The same 401 occurs for an ADMIN-issued token, so this realm governs bearer
# validation generally — Basic auth is unaffected, which is exactly why a curl-only test
# can miss it.
#
# TWO TRAPS, both measured:
#   1. PUT REPLACES the entire list. A body omitting NexusAuthenticatingRealm locks every
#      user out of the instance, admin included.
#   2. The API STORES DUPLICATES. PUT ["NexusAuthenticatingRealm","DockerToken","DockerToken"]
#      returns 204 and reads back with both. A blind `. + ["DockerToken"]` in a Job that
#      reruns on every helm upgrade grows the list without bound.
realms_cur="${TMP_DIR}/realms-current.json"
realms_new="${TMP_DIR}/realms-new.json"

http_body "${NEXUS_HOST}/service/rest/v1/security/realms/active" "${realms_cur}"
if [ "${HTTP_CODE}" != "200" ]; then
  echo "FATAL: GET /service/rest/v1/security/realms/active returned HTTP ${HTTP_CODE}, expected 200" >&2
  exit 1
fi

jq -c 'if index("DockerToken") then . else . + ["DockerToken"] end' "${realms_cur}" >"${realms_new}"

if cmp -s "${realms_cur}" "${realms_new}"; then
  echo "realms: DockerToken already active — no change."
else
  http_status "${NEXUS_HOST}/service/rest/v1/security/realms/active" \
    -X PUT -H 'Content-Type: application/json' -d "@${realms_new}"
  if [ "${HTTP_CODE}" != "204" ]; then
    echo "FATAL: PUT /service/rest/v1/security/realms/active returned HTTP ${HTTP_CODE}, expected 204" >&2
    exit 1
  fi
  echo "realms: appended DockerToken (HTTP 204). Existing realms preserved."
fi
```

Note the asymmetry the planner must not smooth over: the anonymous PUT returns **200**, the realms
PUT returns **204**. Both measured.

### Pattern 2: The value belongs in a wrapper-owned top-level block

**What:** A new top-level `anonymous:` tree in `kubernetes/nexus/values.yaml`.

```yaml
anonymous:
  # -- Enable unauthenticated READ access to every repository (NEXUS-02).
  # Grants the built-in, read-only `nx-anonymous` role: repository read + browse
  # across ALL formats and ALL repositories, plus search and healthcheck. It does
  # NOT grant write, upload, or any administrative endpoint — measured: an
  # anonymous POST of a fully valid repository body returns 403 and creates
  # nothing, and every admin endpoint tested returns 403.
  #
  # One exception worth knowing before you set this: GET /service/rest/v1/repositories
  # returns 200 anonymously, disclosing the NAME, FORMAT, TYPE and URL of every
  # repository (not remote URLs, not credentials). See the chart README.
  #
  # Setting this true also appends the DockerToken realm to the active realms list
  # (append-if-absent; existing realms are preserved). Without it, `docker pull`
  # fails with 401 even though npm/pip/helm succeed. See the chart README.
  enabled: true
  # -- Nexus user the anonymous identity maps to. Nexus's own default.
  userId: anonymous
  # -- Realm that resolves that user. Nexus's own default.
  realmName: NexusAuthorizingRealm
```

**Why top-level and not `nexus3.config.anonymous.*`:** that path is **inert**. Phase 23 measured it
— rendering the chart with it flipped to `true` produced byte-identical output, because the
subchart only reads it inside `{{- if .Values.config.enabled }}` and this wrapper pins that to
`false`. It was removed from `values.yaml` in commit `a9c4f38` precisely because a value that
changes nothing reads like a control and is not one. **Do not put it back.**

**Default value — recommendation and flag.** The block above ships `enabled: true`, which is the
recommendation. The parallel with `eula.accepted: false` is tempting and, on reflection, wrong: the
EULA default is `false` because accepting a licence agreement is a *legal act performed on the
consumer's behalf*, which a chart must never do. Opening read-only anonymous pull is a *functional
posture*, it is the literal text of NEXUS-02, and a chart whose headline requirement is off by
default ships a requirement it does not meet. Against that: a public chart that opens
unauthenticated read by default is a surprising default for anyone who installs it without reading
`values.yaml`, and there is no TLS in front of it until Phase 25. **This is Assumption A1 — the
single most important thing for discuss-phase to settle.** If it flips to `false`, the YAML block
above and the `ANONYMOUS-DEFAULT` gate check both change with it.

### Pattern 3: Invert the two gates in the same commit as the calls

**What:** `ANONYMOUS-NOT-OPENED` (offline, check 8) and `ANONYMOUS-PULL-DENIED` (live) currently
assert the negation of NEXUS-02. They must be rewritten, not deleted — Chesterton's fence: they
exist because Phase 23's post-review found the original anonymous claim was asserted by an inert
key and nothing measured it (commit `a9c4f38`).

Suggested replacements, keeping Phase 23's naming and non-vacuity discipline:

| Old | New | Asserts |
|-----|-----|---------|
| `ANONYMOUS-NOT-OPENED` (render ships no anonymous config) | `ANONYMOUS-VALUE-PRESENT` | `yq '.anonymous.enabled'` is a real boolean in `values.yaml`, and the rendered Job env carries it — i.e. the value is *wired*, not inert. Toggling it must change the render. |
| — (new) | `ANONYMOUS-DEFAULT` | The shipped default matches whatever A1 resolves to, so a silent flip is caught. |
| `ANONYMOUS-PULL-DENIED` (unauth tarball → 401) | `ANONYMOUS-PULL-ALLOWED` | Unauth tarball → 200 **and** size > 300,000 bytes (a 403 EULA body is 192 bytes and would sail past a bare 200 check — Phase 23's own lesson). |
| — (new) | `ANONYMOUS-PULL-DOCKER` | The **full client handshake**: ping → 401 + Bearer challenge → token → manifest **with the `Authorization: Bearer` header** → 200. A header-less manifest GET must not be accepted as evidence — that is the exact test that produced a wrong conclusion in this research. |
| — (new) | `DOCKER-REALM-ACTIVE` | `GET /v1/security/realms/active` contains `DockerToken` **exactly once** after two consecutive provisioning passes. Catches both the missing realm and the duplicate-append bug. |
| — (new) | `DOCKER-PATH-SHAPE` | `/v2/<repo>/…/manifests/<tag>` → 200 **and** `/v2/repository/<repo>/…` → 404. |
| — (new) | `ANONYMOUS-WRITE-DENIED` | Unauth POST of a **fully valid** repository body → 403, and an admin GET of that repo name → 404. See Pitfall 5 for why the body must be valid. |

Phase 23's convention requires proving a new check non-vacuous by reverting the fix and watching it
go red. Apply it here — `ANONYMOUS-PULL-DOCKER` in particular, by removing `DockerToken` and
confirming it goes red (it will; measured).

### Pattern 4: Per-repo package-manager config has four different shapes

All measured on this workstation against the live Nexus instance.

| Ecosystem | Is there a project scope? | Mechanism | Measured evidence |
|-----------|---------------------------|-----------|-------------------|
| **npm** 11.7.0 | **Yes, native** | `.npmrc` at the repo root | `npm config list` printed `; "project" config from …/repo/.npmrc` and `npm config get registry` returned the Nexus URL. |
| **pip** 26.2.1 | **No** | repo-local `pip.conf` + `PIP_CONFIG_FILE` | `pip config list -v` enumerates exactly four candidate paths — global `/Library/Application Support/pip/pip.conf`, user `~/.pip/pip.conf`, user `~/.config/pip/pip.conf`, site `<prefix>/pip.conf`. **No cwd-relative path.** With `PIP_CONFIG_FILE` set, an `env` variant appears **and both user variants vanish from the search list.** |
| **Helm** 4.3.0 | **No** | repo-local `repositories.yaml` + `HELM_REPOSITORY_CONFIG` | `helm env` exposes `HELM_REPOSITORY_CONFIG` and `HELM_REPOSITORY_CACHE`; setting both made `helm repo add` write only the repo-local file, and the operator's real global repo list (rook-release, longhorn, concourse, metrics-server…) was verified untouched afterwards. |
| **Docker** 28.3.2 | **No, and no equivalent** | image-reference prefix only | `registry-mirrors` / `insecure-registries` are daemon-global keys in `daemon.json` (present on this machine at `~/.docker/daemon.json`). `DOCKER_CONFIG` redirects `config.json`, which holds auth and credHelpers — **not** mirrors. |

**The npm subtlety worth a line in the script's docs:** `.npmrc` is read from npm's *local prefix*,
which is the nearest ancestor directory containing `package.json` or `node_modules` — not from the
current directory. Measured: from a subdirectory with no `package.json` anywhere up the tree, npm
fell back to `https://registry.npmjs.org/`. In a real repo with a root `package.json` this is
invisible; in an empty scaffold it is a confusing "the script did nothing" report.

### Pattern 5: One sourceable env file, not four scattered exports

Because pip and Helm both need an environment variable, and Docker needs a prefix string a
Dockerfile or compose file can interpolate, the script's honest output is one file the developer
sources:

```bash
# .nexus-env — generated by workstation/nexus-setup.sh. source this, do not execute it.
export PIP_CONFIG_FILE="${REPO_ROOT}/pip.conf"
export HELM_REPOSITORY_CONFIG="${REPO_ROOT}/.helm/repositories.yaml"
export HELM_REPOSITORY_CACHE="${REPO_ROOT}/.helm/cache"
export NEXUS_DOCKER_REGISTRY="nexus.example.com/docker-proxy"
```

This is where the phase must be honest rather than clever: **npm works with no environment at all,
pip and Helm work only if this file is sourced, and Docker works only if someone edits an image
reference.** A script that writes four files and prints "done" without saying that has produced
exactly the silent-corruption failure mode this project's rules exist to prevent. The script should
end with a verification pass (§Validation Architecture) that proves each ecosystem, and report the
Docker line as a manual step rather than a success.

### Pattern 6: The Docker URL shape has no `/repository/` segment

This closes **ADR-020 §What was NOT verified, item 2** ("the Docker proxy's `docker.pathEnabled:
true` shape is accepted and stored, but no image was ever pulled through it").

With `pathEnabled: true`, the repository name is the **first path segment**, and the standard
`/v2/` registry prefix comes before it:

```
correct    docker pull  NEXUSHOST[:PORT]/docker-proxy/library/alpine:3.21
                 →  HEAD /v2/docker-proxy/library/alpine/manifests/3.21     → 200 ✓

wrong      docker pull  NEXUSHOST[:PORT]/repository/docker-proxy/library/alpine:3.21
                 →  HEAD /v2/repository/docker-proxy/library/alpine/manifests/3.21 → 404 ✗
```

Both URL translations were observed directly — `docker buildx imagetools inspect` printed the exact
`HEAD` URL it constructed for each reference — and both target paths were then measured with `curl`.
`/repository/docker-proxy/v2/library/alpine/manifests/3.21` also returns 200, but **no Docker client
can produce that shape**, so it is a browser/`curl` URL only and must not appear in documentation as
a pull target.

Confirmed with a real OCI client: `crane manifest localhost:8081/docker-proxy/library/alpine:3.21`
returns the image index and exits 0, while the `/repository/`-prefixed reference fails with
`unexpected status code 404 Not Found`. A full `crane export` of the correct reference streamed
8,083,968 bytes.

**This makes Docker the only one of the four where the `/repository/` prefix is wrong.** npm, pip
and Helm all use `HOST/repository/<repo-name>/…`. That asymmetry is a documentation trap and
belongs in the chart README, the workstation script's help text, and a gate check.

### Anti-patterns to avoid

- **Putting `anonymous` under `nexus3.config.*`.** Measured inert; deliberately removed in `a9c4f38`.
- **A literal or blind realms PUT.** Replaces the list (lockout) or stores duplicates. Both measured.
- **Deleting the two anonymous gate checks instead of inverting them.** They encode a lesson.
- **Testing anonymous Docker access with a header-less `curl`.** Returns 200 even when a real client
  would get 401. This mistake was made *in this research* and caught by review; do not repeat it in
  a gate.
- **Hand-writing `.helm/repositories.yaml`.** It is Helm's internal format, with a `generated`
  timestamp and per-entry fields. Shell out to `helm repo add`.
- **Truncating an existing `.npmrc`.** A repo `.npmrc` may already carry `//registry/:_authToken`
  lines. See §Don't Hand-Roll.
- **Documenting `HOST/repository/docker-proxy/image` as a pull target.** Measured 404.
- **Asserting "anonymous write is denied" with a malformed request body.** Returns 400, not 403 —
  the assertion would pass for the wrong reason. See Pitfall 5.
- **Weakening the chart's `required` credential guard** to obtain Checkov coverage. Explicitly
  forbidden by ADR-020 and by `deferred-items.md` item 3.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Merging a `registry=` line into an existing `.npmrc` | A `sed`/`grep -v` rewrite | `npm config set registry=<url> --location=project` | **Measured non-destructive.** Starting from an `.npmrc` containing an auth-token line and `save-exact=true`, the command preserved both and appended the registry line. A hand-rolled rewrite that clobbers a developer's `_authToken` is a credential-loss bug with no error message. |
| Appending to Nexus's active-realms list | `jq '. + ["DockerToken"]'` | `jq 'if index("DockerToken") then . else . + ["DockerToken"] end'` | **Measured:** the API stores duplicates (204, readback shows both). A hook Job that reruns on every upgrade would grow the list indefinitely. |
| Writing Helm's `repositories.yaml` | A YAML heredoc | `HELM_REPOSITORY_CONFIG=… helm repo add <name> <url>` | The format is Helm's, includes a `generated` timestamp and per-entry cert/auth fields, and has changed across major versions. Measured working on Helm 4.3.0 with the global file untouched. |
| Writing `pip.conf` | *(no alternative — you must write it)* | Write the INI by hand, but **do not** try to drive `pip config set` | **Measured:** `PIP_CONFIG_FILE=<file> pip3 config set global.index-url <url>` on pip 26.2.1 exits with `ERROR: Fatal Internal error [id=2]. Please report as a bug.` and writes nothing. pip's own writer has no "write to the env-var file" scope. A hand-written two-line INI is the correct answer here, and the clobber risk is low because a repo-root `pip.conf` is a file this script invents. |
| Deciding whether plain HTTP needs `trusted-host` | Guessing, or always setting it | Branch on loopback | **Verified from pip's source** (`pip/_internal/network/session.py`): `SECURE_ORIGINS` is `[("https","*","*"), ("*","localhost","*"), ("*","127.0.0.0/8","*"), ("*","::1/128","*"), ("file","*",None), ("ssh","*","*")]`. So `http://` to a **non-loopback** host requires `trusted-host`; to loopback it does not. Measured both ways. Always setting `trusted-host` on an `https://` URL is a needless downgrade of a real check. |
| Detecting the repo root | `pwd` | `git rev-parse --show-toplevel` | Already the convention in `workstation/setup.sh` (`REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null \|\| pwd)"`). |
| Idempotent config writes | Bespoke exists-checks | `workstation/setup.sh`'s `write_config()` (lines 522-534) | Skip-if-exists, counts what it created, logs under `--verbose`. Reuse it — a second convention in the same directory is churn. Add `--force` for deliberate overwrite. |
| Polling Nexus for readiness | A new loop | `provision.sh`'s existing bounded poll on `/status/writable` | Already bounded, already hard-fails, already explains why `/status` is the wrong endpoint. |

**Key insight:** every hand-rolled option in this table fails the same way — it silently damages
state the operator already had, or it produces a config that looks right and routes nowhere. Both
are invisible until a build breaks days later. Each tool's own CLI or API already knows how to
merge its own state; the one that does not (pip) is also the one where hand-writing is safe.

---

## Runtime State Inventory

This is a behaviour-flip phase, not a greenfield one. The grep-visible surface is small; the
state that asserts the old behaviour is not.

| Category | Items found | Action required |
|----------|-------------|------------------|
| **Stored data** | **Nexus application state**, persisted in the chart's PVC: the anonymous-access setting (`enabled: false` on every existing install), the **active-realms list** (`["NexusAuthenticatingRealm"]` — `DockerToken` absent), and the `anonymous` user's role binding (`roles: ["nx-anonymous"]`). None of this is in git, none is in the render, and none changes on upgrade unless the hook Job changes it. | **Data migration via the hook Job.** The post-upgrade hook already fires on `helm upgrade`, so an existing install picks both changes up. The realms append must be guarded (Pattern 1 Step B) or repeated upgrades corrupt the list. Phase 25 must confirm on the homelab instance rather than assume. |
| **Live service config** | No live Nexus instance exists yet — NEXUS-05 / Phase 25 is the first deploy. The **private ArgoCD overlay repo** will carry environment values (hostname, StorageClass, admin Secret name) and will need `anonymous.enabled` added if A1 resolves to a `false` default. | **None in this phase**, but record it as a Phase 25 input so the overlay is not written twice. |
| **OS-registered state** | None. No launchd/systemd/Task Scheduler registration exists for anything in this phase. Verified: `security-platform` contains no service-unit or plist files; the workstation script writes only into a repo working tree and a sourceable env file. | None. |
| **Secrets / env vars** | The chart's admin Secret (`nexus3.rootPassword.secret`) is **unchanged** — anonymous read does not replace or weaken it, and `provision.sh` still authenticates as admin to make both calls. The workstation script introduces **new** env var names (`PIP_CONFIG_FILE`, `HELM_REPOSITORY_CONFIG`, `HELM_REPOSITORY_CACHE`, `NEXUS_DOCKER_REGISTRY`); three of four are names pip and Helm already define, so nothing is invented. `provision.sh`'s environment contract gains `ANONYMOUS_ENABLED`, `ANONYMOUS_USER_ID`, `ANONYMOUS_REALM_NAME` — which the live smoke's `run_provision()` must also set, or the smoke breaks under `set -u`. | None to migrate. Document the names; update `run_provision()` in the smoke. |
| **Build artifacts** | None. No compiled artefact, no `egg-info`, no vendored tarball changes. `kubernetes/nexus/charts/nexus3-5.26.0.tgz` stays as-is (gitignored, rebuilt by `helm dependency build`). | None. |
| **Assertions and prose that state the opposite** *(the real inventory for this phase)* | **Eight artefacts.** See table below. | Six edits, one new ADR, one historical record left alone. |

### The eight artefacts that currently assert anonymous access is closed

| # | Artefact | What it says today | Disposition |
|---|----------|--------------------|-------------|
| 1 | `security-platform/scripts/check-nexus-chart.sh` check 8 `ANONYMOUS-NOT-OPENED` (lines ~171-203) | **Fails** if the render emits an `anonymous.json` object or any call to `/service/rest/v1/security/anonymous` | **Will go red.** Invert — Pattern 3. |
| 2 | `security-platform/scripts/nexus-live-smoke.sh` `ANONYMOUS-PULL-DENIED` | Asserts an unauthenticated tarball fetch returns **401** | **Will go red.** Invert — Pattern 3. Also update `run_provision()`'s env contract. |
| 3 | `security-platform/kubernetes/nexus/values.yaml`, the `nexus3.config:` comment block | ~20 lines of prose: "Anonymous access is closed because NEXUS ships it closed… Opening read-only anonymous pull is NEXUS-02, a Phase 24 decision." | Rewrite. Keep the "`nexus3.config.anonymous.*` is inert, do not put it back" warning — that lesson stays true. |
| 4 | `security-platform/kubernetes/nexus/README.md` | States reads require authentication (401), and lists `NEXUS-02 … — Planned (Phase 24)` | Rewrite the row and the section; add the four URL shapes, the Docker `/repository/` trap, and the DockerToken dependency. |
| 5 | `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md` (this repo) | "Anonymous stays disabled in this phase"; §What was NOT verified item 2 (Docker pull never exercised) | **Do not edit — append-only.** Write **ADR-021**, which supersedes the anonymous stance and *closes* item 2 with Pattern 6's measurement. |
| 6 | `docs/adr/README.md` (this repo) | Index ends at ADR-020 | Add one ADR-021 row. |
| 7 | `.planning/REQUIREMENTS.md` | `- [ ] NEXUS-02`, `- [ ] NEXUS-04`; traceability rows "Phase 24 \| Pending" | Flip both on completion. |
| 8 | PR #14 body on `security-platform` ("anonymous pull (NEXUS-02) is deliberately **not** enabled by this PR") | Historical record of a merged PR | **Leave alone.** It was true when written. The new PR references it. |

Additionally, **grep this repository's long-form docs before planning**:
`docs/development-security-stack-option-1.md` and `docs/ARCHITECTURE_AND_DESIGN.md` both describe
the Nexus layer and may assert authenticated access. A `grep -rn -i 'anonymous\|nexus.*auth'` task
over `docs/` belongs in the plan; CLAUDE.md requires the ASCII diagrams and coverage matrices
survive any edit there.

---

## Common Pitfalls

### Pitfall 1: The two existing gates go red and look like the phase broke something

**What goes wrong:** the anonymous PUT lands, `check-nexus-chart.sh` reports a `FAIL` on
`ANONYMOUS-NOT-OPENED`, and the natural reaction is to treat it as a regression.
**Why:** Phase 23 wrote those checks deliberately to make the "closed" claim measurable.
**How to avoid:** sequence the gate inversion into the **same plan** as the REST calls, ideally the
same commit. A commit that lands the call and leaves the gate asserting its negation is a red gate
in git history for no reason.
**Warning sign:** a plan whose task list contains "add the anonymous call" with no matching
"invert check 8".

### Pitfall 2: Anonymous pull still returns 403 when the EULA is unaccepted

**What goes wrong:** `anonymous.enabled: true`, `eula.accepted: false` → every anonymous component
download returns **403** with a ~192-byte body, while metadata returns 200.
**Why:** the two gates are independent. NEXUS-02 does not remove ADR-020's EULA gate.
**How to avoid:** the chart README must name both values together; the workstation script's
verification pass must treat a 403 with a small body as "EULA not accepted on the server", not as
"config wrong"; and any smoke check must assert a **byte-count threshold**, not just `200`.
**Warning sign:** a "200 OK" assertion with no size check — the exact false-pass Phase 23's live
smoke was built to catch.

### Pitfall 3: `PUT /security/realms/active` replaces the whole list, and stores duplicates

**This phase must make that call, so this pitfall is load-bearing rather than hypothetical.**

**What goes wrong, two ways:**
1. PUTting `["DockerToken"]` to "add" the realm **removes** `NexusAuthenticatingRealm` and locks
   every user out of the instance, admin included. The endpoint is a full replacement, not a patch.
2. PUTting a list that already contains `DockerToken` again **stores the duplicate**. Measured:
   `["NexusAuthenticatingRealm","DockerToken","DockerToken"]` → 204, and the readback contains both.
   In a hook Job that reruns on every `helm upgrade`, a blind `jq '. + ["DockerToken"]'` grows the
   list without bound.

**How to avoid:** GET first; append only if absent; PUT the full resulting list; skip the PUT
entirely when nothing changed (Pattern 1 Step B). Never write a realm array literal.
**Warning sign:** any literal realm array in a script, or a `jq '. + [...]'` with no `index()` guard.

### Pitfall 4: Proving anonymous Docker access with a header-less request

**This mistake was made during this research and caught in review. It is documented here so the
planner does not repeat it in a gate.**

**What goes wrong:** a test fetches `/v2/docker-proxy/library/alpine/manifests/3.21` with plain
`curl` and no `Authorization` header, sees **200**, and concludes the `DockerToken` realm is
unnecessary. A gate written that way passes with the realm removed, and then `docker pull` fails in
Phase 25 against real infrastructure.
**Why:** no Docker client ever makes that request. The client pings `/v2/`, gets 401 with a
`Bearer realm=…` challenge, fetches a token, and **presents it on every subsequent request.** That
presented token is what the realm validates.

Measured, with `forceBasicAuth: false` (the chart's default) throughout:

| Condition | ping `/v2/` | token endpoint | manifest, **no** header | manifest, **with** `Bearer` |
|-----------|-------------|----------------|--------------------------|------------------------------|
| realms `["NexusAuthenticatingRealm","DockerToken"]` | 401 + Bearer challenge | 200 (48-char token) | 200 | **200** |
| realms `["NexusAuthenticatingRealm"]` | 401 + identical challenge | 200 (48-char token) | 200 | **401** |

The realm is not about anonymity: an **admin-issued** token also returns 401 on the manifest with
`DockerToken` inactive, while plain Basic auth returns 200. It governs bearer-token validation.
**Phase 23's hand-off note was right.**

**How to avoid:** the `ANONYMOUS-PULL-DOCKER` gate must perform the full handshake and send the
`Authorization: Bearer` header, and `DOCKER-REALM-ACTIVE` must assert the realm is present exactly
once. Prove both non-vacuous by removing the realm and watching them go red.
**Confirmed by a real OCI client, not only by curl.** `crane`, running anonymously in the Nexus
container's own network namespace, was used as the control:

| Realms | `crane manifest localhost:8081/docker-proxy/library/alpine:3.21` |
|--------|------------------------------------------------------------------|
| `["NexusAuthenticatingRealm","DockerToken"]` | **exit 0**, full OCI image index returned |
| `["NexusAuthenticatingRealm"]` | `Error: … unexpected status code 401 Unauthorized` |
| restored to include `DockerToken` | **exit 0** again |

`crane export` of the same reference streamed **8,083,968 bytes** of filesystem tarball, so the
blob path is exercised end to end and not merely the manifest. This is the non-vacuity proof the
`ANONYMOUS-PULL-DOCKER` and `DOCKER-REALM-ACTIVE` gates need, already performed once.

**One residual, stated plainly:** the client here was `crane`, not `dockerd`. Docker Desktop's VM
cannot reach a host-published `127.0.0.1` port, and adding a non-loopback host to
`insecure-registries` would have meant editing the operator's global `daemon.json`, which this
phase's own scope forbids. `crane` implements the same OCI distribution protocol and resolves
references identically (proven by test C below), so the remaining gap is daemon-specific
TLS/insecure-registry handling against a real hostname — which is exactly what Phase 25 exercises.

### Pitfall 5: "Anonymous write is denied" asserted with a malformed body passes for the wrong reason

**What goes wrong:** a gate POSTs `{"name":"evil"}` anonymously, gets **400**, and concludes
authorization denied it.
**Why:** Nexus validates the request body *before* authorization. Measured: `{"name":"evil"}` → 400;
the **same endpoint with a fully valid npm proxy body** → **403**, and an admin GET of that name →
404 (nothing created).
**How to avoid:** assert denial with a valid body and expect exactly 403, and confirm non-creation
with an authenticated GET.
**Warning sign:** an expected-status list of `400,401,403` — three different meanings collapsed
into "not 201".

### Pitfall 6: The Docker reference gains a `/repository/` segment by analogy

**What goes wrong:** npm, pip and Helm all use `HOST/repository/<repo>/…`, so the Docker line gets
written the same way and every pull 404s.
**Why:** the Docker client inserts `/v2/` immediately after the host, so the repository name must be
the first path segment. Measured both shapes (Pattern 6).
**How to avoid:** one gate check asserting the `NEXUS_DOCKER_REGISTRY` string the script emits
contains no `/repository/`.
**Warning sign:** `${NEXUS_URL}/repository/docker-proxy` anywhere in the script or docs.

### Pitfall 7: Clobbering a developer's existing `.npmrc` auth token

**What goes wrong:** the script overwrites `.npmrc` with a single `registry=` line and destroys a
`//registry/:_authToken=` entry that was the only copy of a private-registry credential.
**Why:** a naive `cat > .npmrc`.
**How to avoid:** `npm config set registry=<url> --location=project`, measured non-destructive; plus
`write_config()`'s skip-if-exists and an explicit `--force`.
**Warning sign:** any `>` redirect onto `.npmrc` in the script.

### Pitfall 8: `PIP_CONFIG_FILE` silently drops the developer's user-level pip config

**What goes wrong:** sourcing `.nexus-env` makes an unrelated pip setting (a corporate CA bundle, an
`--extra-index-url`) stop applying, in a shell the developer keeps using for other projects.
**Why:** measured — with `PIP_CONFIG_FILE` set, `pip config list -v` no longer lists **either** user
variant. The env file is not additive; it replaces user scope.
**How to avoid:** say so in the generated `.nexus-env` header and in `--help`; have the script read
the developer's existing user `pip.conf` and warn if it contains keys the generated file does not
carry. Recommend sourcing per-shell, never from `.bashrc`.
**Warning sign:** documentation telling the developer to add `source .nexus-env` to a shell rc file
— precisely the "global workstation default" REQUIREMENTS.md puts out of scope.

### Pitfall 9: Anonymous read is granted across **all** repositories, forever, including ones that do not exist yet

**What goes wrong:** a hosted repository for internal packages is added later and is world-readable
from the moment it is created, silently.
**Why:** the built-in `nx-anonymous` role's privileges are `nx-repository-view-*-*-read` and
`nx-repository-view-*-*-browse` — wildcards on format *and* repository name. Measured, and the role
is `readOnly: true`, so it cannot be narrowed in place.
**How to avoid:** document it in the chart README as a property of NEXUS-02, and note the remedy
(create a custom role limited to the four proxies and `PUT /service/rest/v1/security/users/anonymous`
with `roles: ["<custom>"]`). This also intersects ADR-010's dependency-confusion guidance: a group
repository must order hosted before proxy, and a world-readable hosted repo makes that ordering
mistake more consequential.
**Warning sign:** a future phase adding a hosted repo with no accompanying role decision.

### Pitfall 10: The script reports success while routing nothing

**What goes wrong:** four files written, "Setup complete" printed, and pip/Helm still hit the
public internet because `.nexus-env` was never sourced — or npm still does, because the repo has no
`package.json` and npm's local prefix resolved elsewhere.
**Why:** writing a file is not the same as a client reading it.
**How to avoid:** a mandatory verification pass that runs a real fetch per ecosystem and reports
per-ecosystem status, with Docker reported as MANUAL rather than as a pass. Never `|| true` it.
**Warning sign:** a script whose last action is an `info "done"`.

---

## Code Examples

All examples below were executed in this session against a live `sonatype/nexus3:3.96.0-ubi`
container booted from the image `kubernetes/nexus` itself renders, provisioned by the chart's own
`files/provision.sh` with `EULA_ACCEPTED=true` and `repos.helm.remoteUrl=https://charts.jetstack.io`.

### 1. Read the default anonymous state and the role it grants

```console
$ curl -sS -u admin:$PW "$NEXUS/service/rest/v1/security/anonymous"
{
  "enabled" : false,
  "userId" : "anonymous",
  "realmName" : "NexusAuthorizingRealm"
}

$ curl -sS -u admin:$PW "$NEXUS/service/rest/v1/security/roles/nx-anonymous"
{
  "id": "nx-anonymous", "source": "default", "name": "nx-anonymous",
  "description": "Anonymous Role", "readOnly": true,
  "privileges": [
    "nx-healthcheck-read", "nx-search-read",
    "nx-repository-view-*-*-read", "nx-repository-view-*-*-browse"
  ],
  "roles": []
}

$ curl -sS -u admin:$PW "$NEXUS/service/rest/v1/security/users?userId=anonymous"
{"userId":"anonymous", …, "roles":["nx-anonymous"], "externalRoles":[]}

$ curl -sS -u admin:$PW "$NEXUS/service/rest/v1/security/realms/active"
[ "NexusAuthenticatingRealm" ]                    # DockerToken absent by default
```

### 2. The two calls that constitute NEXUS-02's server-side change

```console
$ curl -sS -u admin:$PW -X PUT -H 'Content-Type: application/json' \
    -d '{"enabled":true,"userId":"anonymous","realmName":"NexusAuthorizingRealm"}' \
    -w '\nHTTP %{http_code}\n' "$NEXUS/service/rest/v1/security/anonymous"
{ "enabled" : true, "userId" : "anonymous", "realmName" : "NexusAuthorizingRealm" }
HTTP 200
$ # repeat → HTTP 200 (idempotent)

$ CUR=$(curl -sS -u admin:$PW "$NEXUS/service/rest/v1/security/realms/active")
$ NEW=$(echo "$CUR" | jq -c 'if index("DockerToken") then . else . + ["DockerToken"] end')
$ curl -sS -u admin:$PW -X PUT -H 'Content-Type: application/json' -d "$NEW" \
    -w 'HTTP %{http_code}\n' "$NEXUS/service/rest/v1/security/realms/active"
HTTP 204
$ curl -sS -u admin:$PW "$NEXUS/service/rest/v1/security/realms/active"
[ "NexusAuthenticatingRealm", "DockerToken" ]

$ # the trap the guard exists for:
$ curl -sS -u admin:$PW -X PUT -H 'Content-Type: application/json' \
    -d '["NexusAuthenticatingRealm","DockerToken","DockerToken"]' \
    -w 'HTTP %{http_code}\n' "$NEXUS/service/rest/v1/security/realms/active"
HTTP 204
$ curl -sS -u admin:$PW "$NEXUS/service/rest/v1/security/realms/active"
[ "NexusAuthenticatingRealm", "DockerToken", "DockerToken" ]     # duplicate STORED
```

### 3. Before and after, unauthenticated

```
                                                     BEFORE          AFTER
GET /repository/npm-proxy/lodash/-/lodash-4.17.21.tgz   401    →   200  318,961 B
GET /repository/npm-proxy/lodash                        401    →   200  249,667 B
GET /repository/pypi-proxy/simple/requests/             401    →   200   76,776 B
GET /repository/helm-proxy/index.yaml                   401    →   200  291,818 B
```

And what anonymous is still refused, after enabling:

```
POST /service/rest/v1/repositories/npm/proxy  (FULL VALID BODY)   → 403   (admin GET of the name → 404: nothing created)
PUT  /service/rest/v1/security/anonymous                          → 403
GET  /service/rest/v1/security/users                              → 403
GET  /service/rest/v1/security/anonymous                          → 403
GET  /service/rest/v1/security/realms/active                      → 403
GET  /service/rest/v1/system/eula                                 → 403
GET  /service/rest/v1/blobstores                                  → 403
GET  /service/rest/v1/tasks                                       → 403
PUT  /repository/npm-proxy/evil-pkg/-/evil-pkg-1.0.0.tgz          → 404   (proxy repos accept no writes)

GET  /service/rest/v1/repositories                                → 200   ⚠ see below
```

The one anonymous 200 outside a repository path returns the inventory — `name`, `format`, `type`,
`url` for all 11 repositories (the 4 provisioned plus Nexus's 7 defaults). It does **not** expose
`remoteUrl`, credentials, or blob store detail. Bounded, but it is information disclosure and
belongs in the README and in ADR-021's Consequences.

### 4. The complete anonymous Docker client handshake — the thing a gate must assert

```console
# 1. ping — the client always starts here
$ curl -sS -o /dev/null -w '%{http_code}\n' "$NEXUS/v2/"
401
$ curl -sSI "$NEXUS/v2/" | grep -i www-authenticate
WWW-Authenticate: Bearer realm="…/repository/docker-proxy/v2/token",service="…/repository/docker-proxy/v2/token"

# 2. token — no credentials supplied
$ TOK=$(curl -sS "$NEXUS/repository/docker-proxy/v2/token" | jq -r .token)   # 48 chars

# 3. manifest index — WITH the bearer header
$ curl -sS -H "Authorization: Bearer $TOK" \
    -H 'Accept: application/vnd.oci.image.index.v1+json' \
    "$NEXUS/v2/docker-proxy/library/alpine/manifests/3.21"            # 9,219 bytes
# child = sha256:3c81aa9a3d770b316568f4499e30461a5cd3fbd7180bd89e28e34894c7845832

# 4. child manifest → layer digest
# layer = sha256:16333ee0c00fc65e025a2a4f839703ad37a74728832977fbdf080984de1b8e5a

# 5. layer blob
$ curl -sS -o /dev/null -w '%{http_code} size=%{size_download}\n' -L \
    -H "Authorization: Bearer $TOK" \
    "$NEXUS/v2/docker-proxy/library/alpine/blobs/$LAYER"
200 size=3626020
```

With `DockerToken` removed from active realms, steps 1 and 2 are **identical** and step 3 returns
**401**. That is the whole reason the second REST call exists.

The same sequence, driven by a real OCI client rather than by hand:

```console
# A. correct reference, anonymous, DockerToken active
$ crane manifest --insecure localhost:8081/docker-proxy/library/alpine:3.21
{"manifests":[{"annotations":{"com.docker.official-images.bashbrew.arch":"amd64", …   # exit 0

# B. full pull — forces every blob
$ crane export --insecure localhost:8081/docker-proxy/library/alpine:3.21 - | wc -c
8083968

# C. wrong reference shape
$ crane manifest --insecure localhost:8081/repository/docker-proxy/library/alpine:3.21
Error: fetching manifest …: GET http://localhost:8081/v2/repository/docker-proxy/library/alpine/manifests/3.21:
       unexpected status code 404 Not Found

# D. correct reference, DockerToken REMOVED
$ crane manifest --insecure localhost:8081/docker-proxy/library/alpine:3.21
Error: fetching manifest …: GET http://localhost:8081/v2/docker-proxy/library/alpine/manifests/3.21:
       unexpected status code 401 Unauthorized
```

### 5. npm — native project scope, non-destructive merge

```console
$ npm config set registry=http://NEXUS/repository/npm-proxy/ --location=project
$ npm config list
; "project" config from /path/to/repo/.npmrc
registry = "http://NEXUS/repository/npm-proxy/"

$ npm pack lodash@4.17.21           # anonymous, through the proxy
lodash-4.17.21.tgz                  # 318,961 bytes
```

Merge proof — the starting `.npmrc` contained an auth-token line and `save-exact=true`; after the
command both survived and `registry=` was appended.

### 6. pip — no project scope, so the env var is the mechanism

```console
$ pip3 config list -v
For variant 'global', will try loading '/Library/Application Support/pip/pip.conf'
For variant 'user',   will try loading '/Users/…/.pip/pip.conf'
For variant 'user',   will try loading '/Users/…/.config/pip/pip.conf'
For variant 'site',   will try loading '/Users/…/3.12.0/pip.conf'
                                             ← no cwd-relative path exists

$ cat repo/pip.conf
[global]
index-url = http://NEXUS/repository/pypi-proxy/simple
trusted-host = NEXUS          # only when the URL is http:// AND the host is not loopback

$ PIP_CONFIG_FILE=repo/pip.conf pip3 config list -v
For variant 'global', …
For variant 'site',   …
For variant 'env',    will try loading 'repo/pip.conf'      ← both 'user' variants are GONE

$ PIP_CONFIG_FILE=repo/pip.conf pip3 download requests==2.32.3 --no-deps -d dl
Saved ./dl/requests-2.32.3-py3-none-any.whl                  # anonymous, through the proxy
```

### 7. Helm — env-redirected repo config, global list untouched

```console
$ export HELM_REPOSITORY_CONFIG=repo/.helm/repositories.yaml
$ export HELM_REPOSITORY_CACHE=repo/.helm/cache
$ helm repo add nexus http://NEXUS/repository/helm-proxy/
"nexus" has been added to your repositories

$ helm search repo nexus/cert-manager --versions | head -2
nexus/cert-manager   v1.21.2   v1.21.2   A Helm chart for cert-manager

$ helm repo list --repository-config ~/Library/Preferences/helm/repositories.yaml
rook-release … longhorn … concourse … metrics-server …      # operator's real list, unchanged
```

### 8. Docker — the reference shape, proven by a real client's own URL construction

```console
$ docker buildx imagetools inspect NEXUS/docker-proxy/library/alpine:3.21
ERROR: failed to do request: Head "http://NEXUS/v2/docker-proxy/library/alpine/manifests/3.21": …
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ the client builds THIS

$ docker buildx imagetools inspect NEXUS/repository/docker-proxy/library/alpine:3.21
ERROR: failed to do request: Head "http://NEXUS/v2/repository/docker-proxy/library/alpine/manifests/3.21": …

$ # and those two paths, measured directly:
/v2/docker-proxy/library/alpine/manifests/3.21              → 200   (HEAD and GET)
/v2/repository/docker-proxy/library/alpine/manifests/3.21   → 404
/repository/docker-proxy/v2/library/alpine/manifests/3.21   → 200   (curl-only; no client emits it)
```

The `inspect` calls themselves did not complete — the buildx builder runs inside Docker Desktop's
VM and cannot reach a host-published loopback port — but the error text is emitted **after** URL
construction, which is precisely the fact being established. `crane`, which *can* reach the
instance (Code Example 4), then confirmed the same conclusion by succeeding on the first reference
and failing 404 on the second.

---

## State of the Art

| Old understanding | Current, measured | When / where it changed | Impact |
|-------------------|-------------------|--------------------------|--------|
| Anonymous Docker pull requires activating the `DockerToken` realm (Phase 23 hand-off, `[VERIFIED]`) | **Confirmed, with the mechanism now precise:** the realm validates the **bearer token a client presents**. Without it, a presented token — anonymous or admin-issued — returns 401 on the manifest; Basic auth is unaffected. **This research first concluded the opposite and was wrong**: the initial causal test fetched the manifest with no `Authorization` header, a request no Docker client makes. Corrected on re-measurement. | Phase 23 inferred it from the realm listing; measured properly here after review | The realms call **is required**. Pitfall 3 becomes load-bearing, and the gate must send the `Bearer` header or it will pass with the realm removed |
| Anonymous Docker pull requires `docker.forceBasicAuth: false` on the repository (Sonatype docs: "a repository-level setting on each Docker repository") | **Not reproduced on 3.96.0.** With `forceBasicAuth: true` the `/v2/` challenge is still `Bearer` (not `Basic`), the token still issues, and the manifest with that token still returns 200 | Measured this session, both header-less and full-handshake | The chart's existing `forceBasicAuth: false` is semantically correct and stays, but must **not** be documented as the control that makes anonymous pull work. Treat as a documented-vs-measured divergence, not a settled fact |
| Path-routed Docker repos are reached at `HOST/repository/<repo>/<image>` | `HOST/<repo>/<image>` — no `/repository/` segment | Measured; closes ADR-020 §What was NOT verified item 2 | Changes the string the workstation script emits and the chart README documents |
| `nexus3.config.anonymous.enabled` is the chart's anonymous control | Inert — byte-identical render when toggled | `security-platform` commit `a9c4f38` (Phase 23 post-review) | The new value must be top-level and wired through the Job env |
| Sonatype publishes a Helm chart named `nexus3` | It does not | ADR-020 | Settled; not reopened |

**Deprecated / not to be used:**
- The Groovy scripting API (`POST /service/rest/v1/script`) — answers **410**; requires
  `nexus.scripts.allowCreation=true`, an RCE surface. ADR-020 forbids enabling it.
- The subchart's own `config`-gated configuration Job — same reason, and it cannot accept the EULA.

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| **A1** | `anonymous.enabled` should default to **`true`** in the public chart | Pattern 2 | **Highest-value item for discuss-phase.** If wrong, a public chart opens unauthenticated read for anyone who installs it without reading `values.yaml`, with no TLS until Phase 25. If overturned, NEXUS-02 is satisfied by a documented one-value opt-in — the same shape as `eula.accepted` — and the `ANONYMOUS-DEFAULT` gate must assert `false` instead. |
| **A2** | The workstation script belongs in `security-platform/workstation/` as a **new** script rather than a subcommand of the existing 878-line `setup.sh` | Standard Stack | Low. Separating concerns (security CLI tooling vs. package routing) seems right, but v1.1 valued "one command" ergonomics; a `setup.sh nexus` subcommand is defensible. |
| **A3** | Docker's `registry-mirrors` only mirrors Docker Hub and requires the mirror at the registry root, so a path-routed Nexus repo cannot serve as a daemon mirror | Pattern 4 / Open Question 1 | Medium. Not measured — editing the operator's global `daemon.json` was out of scope. If wrong, a global-mirror option becomes viable, but REQUIREMENTS.md still puts it out of scope. |
| **A4** | Narrowing anonymous read to only the four proxy repositories (a custom role) is **out of scope** for this phase | Alternatives Considered / Pitfall 9 | Medium. If the user considers org-wide anonymous read unacceptable, a custom role + `PUT /v1/security/users/anonymous` becomes required scope and adds two more REST calls plus state to `provision.sh`. |
| **A5** | `deferred-items.md` items 2 (dead `provision.readiness.*` knobs) and 3 (Checkov zero coverage), both explicitly handed to Phase 24, are in scope | §Open Questions 2 and 3 | Medium. Not in the phase goal and not in NEXUS-02/04. If deferred again they need an explicit disposition, not silence — ADR-020 already records them as open. |
| **A6** | The post-upgrade hook Job firing on `helm upgrade` is sufficient to migrate an already-installed Nexus to `anonymous.enabled: true` **and** to append the realm | Runtime State Inventory | Low-medium. Consistent with how EULA acceptance and repo upsert already behave, but no `helm upgrade` against a pre-existing Nexus with data was performed this session. Phase 25 confirms. |
| **A7** | Anonymous read is acceptable given the instance is reachable only inside the homelab network, with NetworkPolicy explicitly out of scope | Security Domain | Medium. Depends on the operator's ingress posture, which is a Phase 25 artefact in a private repo this research cannot see. |
| **A8** | ~~A `docker pull` executed by a real client will succeed~~ — **CLOSED, no longer an assumption.** Measured with `crane`: anonymous `manifest` exits 0 with `DockerToken` active and fails 401 without it; anonymous `export` streamed 8,083,968 bytes; the `/repository/`-prefixed reference fails 404 | Pitfall 4 / Code Example 4 / Pattern 6 | **Low.** The only untested client is `dockerd` itself, blocked by Docker Desktop's VM network boundary. `crane` speaks the same OCI distribution protocol; the residue is daemon-specific TLS/insecure-registry handling against a real hostname, which Phase 25 exercises. |

---

## Open Questions

1. **What does NEXUS-04's "Docker/Helm registry config" mean, given Docker has no per-repo scope?**
   - *What we know:* Helm is solvable per-repo via `HELM_REPOSITORY_CONFIG` (measured). Docker's
     only routing controls — `registry-mirrors`, `insecure-registries` — are daemon-global keys in
     `daemon.json`, and REQUIREMENTS.md explicitly excludes "workstation pkg managers routed through
     Nexus outside the per-repo config."
   - *What's unclear:* whether the requirement intends (a) the script emits a
     `NEXUS_DOCKER_REGISTRY` prefix plus documentation for rewriting image references, treating
     Docker as a documented partial; (b) an opt-in `--docker-daemon` flag that edits `daemon.json`,
     accepting that it contradicts the Out of Scope row; or (c) Docker is descoped from NEXUS-04
     with a note.
   - *Recommendation:* **(a).** The only reading that satisfies both the requirement's word
     "configures" and the Out of Scope row, and it keeps the script from touching a global file on
     the operator's machine. Surface to the user before planning.

2. **Disposition of `provision.readiness.attempts` / `intervalSeconds` (deferred item 2).**
   - *What we know:* both are in `values.yaml` with helm-docs annotations and honest "not read"
     README prose; `provision.sh` hardcodes `READY_ATTEMPTS=60` / `READY_INTERVAL=10`. ADR-020
     records it as item 5 of §What was NOT verified; `deferred-items.md` says "Phase 24 owns the
     choice."
   - *What's unclear:* wire them through, or delete them.
   - *Recommendation:* **wire them through.** This phase is already editing `provision.sh`'s
     environment contract to add three `ANONYMOUS_*` variables, editing `job-provision.yaml`'s env
     block, and editing the live smoke's `run_provision()` — the three files that would need
     touching anyway. Marginal cost ~6 lines; deletion costs a README table edit and removes a
     consumer-visible knob. Confirm with the user, since it is scope beyond NEXUS-02/04.

3. **Disposition of Checkov's zero coverage of `kubernetes/nexus` (deferred item 3).**
   - *What we know:* measured in Phase 23 — the pinned `ghcr.io/bridgecrewio/checkov:3.3.17`
     container's helm runner engages, runs `helm dependency update`, then fails at `helm template`
     on the chart's `required` credential guard, logged at `WARNI` without raising the exit code.
     24 kubernetes-framework findings exist latently (5 wrapper, 19 subchart). ADR-020 forbids
     weakening the guard to obtain coverage.
   - *What's unclear:* accept the blind spot with the latent set documented; feed the scanner a
     values file naming a dummy Secret; or commit a rendered manifest.
   - *Recommendation:* **accept and document**, for this phase. Both alternatives create a second
     artefact that drifts from the real one by construction, and this phase adds no new Kubernetes
     resources — it adds env vars to an existing Job. Revisit when Phase 26 adds a second chart and
     the blind spot doubles.

4. **Does the private ArgoCD overlay need `anonymous.enabled` set explicitly?**
   - *What we know:* the overlay repo is not visible from here; Phase 25 is the first live deploy.
   - *What's unclear:* depends entirely on A1's resolution.
   - *Recommendation:* record it as a Phase 25 input in the plan so the overlay is written once.

5. **Should the generated `.npmrc` / `pip.conf` / `.helm/` / `.nexus-env` be gitignored?**
   - *What we know:* they contain an internal hostname, no credentials.
   - *What's unclear:* committing them makes routing reproducible for anyone with network reach to
     the homelab, and breaks every other consumer of the repo; gitignoring means each developer
     re-runs the script.
   - *Recommendation:* **gitignore by default**, with a `--commit-config` escape hatch. A committed
     `.npmrc` pointing at one operator's Nexus is a dependency-resolution failure for every
     contributor who cannot reach it, and an internal-hostname disclosure if the repo is public.

---

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `docker` | Live smoke docker half; the measurements in this document | ✓ | 28.3.2 | — |
| `kind` | Live smoke kind half | ✓ | 0.33.0 | Soft tier in the smoke — reports SKIPPED |
| `kubectl` | Live smoke kind half | ✓ | client build 2026-08-26 | Soft tier |
| `helm` | Chart render, gates, `helm repo add` | ✓ | **4.3.0** | — |
| `npm` | `.npmrc` merge + verification fetch | ✓ | 11.7.0 | — |
| `pip3` | `pip.conf` verification fetch | ✓ | 26.2.1 (Python 3.12.0, pyenv) | — |
| `jq` | REST bodies and the guarded realm append | ✓ | 1.8.2 | — |
| `yq` | Chart-value assertions in gates | ✓ | 4.53.6 | — |
| `curl` | Every HTTP assertion | ✓ | 8.7.1 | — |
| `shellcheck` | Lint the new script | ✓ | present | — |
| `gh` | PR creation (Phase 23 pattern) | ✓ (used in Phase 23) | — | — |
| Live Nexus instance | End-to-end NEXUS-02 proof on real infrastructure | ✗ | — | Ephemeral `docker run` of the chart's own image — used for every measurement here, and already the live smoke's method. Real-infrastructure proof is **Phase 25 / NEXUS-05**, by design. |
| Private ArgoCD overlay repo | Phase 25 deploy values | ✗ (not visible here) | — | Out of scope for this phase |

**Missing dependencies with no fallback:** none — nothing blocks Phase 24 execution.

**Missing dependencies with fallback:** a live Nexus. The ephemeral-container substitute is not a
degradation; it is the same method `scripts/nexus-live-smoke.sh` already uses and it produced every
measurement in this document.

**One constraint worth flagging to the planner:** `helm` here is **4.3.0**, while ADR-020 records
that CI's pinned `checkov:3.3.17` container ships its own **Helm v3.22.0**. Any chart construct the
new work introduces must render on both. Nothing in this phase's recommended changes uses a
version-sensitive template feature — the additions are env entries and a values block — but a plan
that reaches for a newer template function should verify against v3.

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`, so this section applies.

### Test framework

| Property | Value |
|----------|-------|
| Framework | **None conventional.** `security-platform` has no pytest/jest/bats suite. Validation is two hand-written, hand-run gate scripts plus `pre-commit`. This is the established Phase 23 convention and this phase extends it rather than introducing a framework. |
| Config file | `security-platform/.pre-commit-config.yaml` (shellcheck, yamllint with `exclude: ^kubernetes/.*/templates/`, gitleaks) |
| Quick run command | `bash scripts/check-nexus-chart.sh` — offline, currently 17 checks, seconds |
| Full suite command | `bash scripts/check-nexus-chart.sh && bash scripts/nexus-live-smoke.sh` — currently 13 live checks; ~3 min docker half, ~8 min with the kind half |

Both scripts follow a **VACUOUS-PASS** convention worth preserving: a run in which nothing executed
prints `NOTHING RAN`, not `ALL PASS`, and a SKIP is never counted as a pass.

### Phase requirements → test map

| Req | Behaviour | Type | Automated command | Exists? |
|-----|-----------|------|-------------------|---------|
| NEXUS-02 | `anonymous.enabled` is a real, wired value (toggling changes the render) | offline gate | `bash scripts/check-nexus-chart.sh` → `ANONYMOUS-VALUE-PRESENT` | ❌ Wave 0 — **replaces** `ANONYMOUS-NOT-OPENED` |
| NEXUS-02 | Shipped default matches the A1 decision | offline gate | same → `ANONYMOUS-DEFAULT` | ❌ Wave 0 |
| NEXUS-02 | Unauthenticated npm tarball → 200 **and** > 300,000 bytes | live gate | `bash scripts/nexus-live-smoke.sh` → `ANONYMOUS-PULL-ALLOWED` | ❌ Wave 0 — **replaces** `ANONYMOUS-PULL-DENIED` |
| NEXUS-02 | Unauthenticated PyPI simple index and Helm `index.yaml` → 200 with non-trivial size | live gate | same → `ANONYMOUS-PULL-PYPI`, `ANONYMOUS-PULL-HELM` | ❌ Wave 0 |
| NEXUS-02 | **Full Docker handshake**: ping 401 + Bearer challenge → token → manifest **with `Authorization: Bearer`** → 200 → layer blob → 200 | live gate | same → `ANONYMOUS-PULL-DOCKER` | ❌ Wave 0 — must send the header; a header-less GET is not evidence |
| NEXUS-02 | `DockerToken` appears in active realms **exactly once** after two consecutive provisioning passes | live gate | same → `DOCKER-REALM-ACTIVE` | ❌ Wave 0 — catches both the missing realm and the duplicate-append bug |
| NEXUS-02 | `/v2/<repo>/…` → 200 and `/v2/repository/<repo>/…` → 404 | live gate | same → `DOCKER-PATH-SHAPE` | ❌ Wave 0 |
| NEXUS-02 | Anonymous **write** denied: valid-body POST → 403 **and** admin GET of the name → 404 | live gate | same → `ANONYMOUS-WRITE-DENIED` | ❌ Wave 0 |
| NEXUS-02 | Both new calls are idempotent — two consecutive provisioning runs both exit 0 | live gate | existing two-pass `run_provision` | ✅ extend only (add the three `ANONYMOUS_*` env vars to `run_provision()`) |
| NEXUS-04 | Script writes `.npmrc` and `npm config get registry` returns the Nexus URL | script self-verify | `bash workstation/nexus-setup.sh --url … --verify` | ❌ Wave 0 |
| NEXUS-04 | Script writes `pip.conf`; `PIP_CONFIG_FILE=… pip config get global.index-url` returns it | same | same | ❌ Wave 0 |
| NEXUS-04 | Script writes `.helm/repositories.yaml` via `helm repo add`; `helm repo list` shows it and the **global** file is unchanged | same | same | ❌ Wave 0 |
| NEXUS-04 | Emitted `NEXUS_DOCKER_REGISTRY` contains **no** `/repository/` segment | offline gate | `scripts/check-nexus-chart.sh` or a new `scripts/check-nexus-setup.sh` → `DOCKER-PREFIX-SHAPE` | ❌ Wave 0 |
| NEXUS-04 | Existing `.npmrc` content (including an auth-token line) survives a re-run | script test | fixture dir + `npm config set --location=project` + grep | ❌ Wave 0 |
| NEXUS-04 | Script is not executable and passes shellcheck | pre-commit | `pre-commit run --all-files`; `test ! -x workstation/nexus-setup.sh` | ✅ hook exists, ❌ the `-x` assertion |

### Sampling rate

- **Per task commit:** `bash scripts/check-nexus-chart.sh` (offline, seconds) + `pre-commit run --files <changed>`
- **Per wave merge:** full offline gate + `bash scripts/nexus-live-smoke.sh` docker half
- **Phase gate:** both gates green, `ALL PASS`, zero SKIPPED, **and** each newly added check proven
  non-vacuous by reverting its subject and observing red. For `ANONYMOUS-PULL-DOCKER` and
  `DOCKER-REALM-ACTIVE` the revert is "remove `DockerToken` from active realms" — measured to
  produce 401 on the bearer-authenticated manifest, so both will go red.

### Wave 0 gaps

- [ ] Rewrite `scripts/check-nexus-chart.sh` check 8 → `ANONYMOUS-VALUE-PRESENT`; add `ANONYMOUS-DEFAULT`, `DOCKER-PREFIX-SHAPE`
- [ ] Rewrite `scripts/nexus-live-smoke.sh` `ANONYMOUS-PULL-DENIED` → `ANONYMOUS-PULL-ALLOWED`; add `ANONYMOUS-PULL-PYPI`, `ANONYMOUS-PULL-HELM`, `ANONYMOUS-PULL-DOCKER` (full handshake), `DOCKER-REALM-ACTIVE`, `DOCKER-PATH-SHAPE`, `ANONYMOUS-WRITE-DENIED`
- [ ] Update `run_provision()` in the live smoke with the three new `ANONYMOUS_*` env vars — without them the smoke fails under `set -u` the moment `provision.sh` changes
- [ ] `workstation/nexus-setup.sh` with a `--verify` mode performing one real fetch per ecosystem
- [ ] A fixture-based test for the `.npmrc` merge (pre-existing auth-token line must survive)
- [ ] No framework install needed

---

## Security Domain

`security_enforcement` is not set to `false`, so this section applies.

### Applicable ASVS categories

| ASVS category | Applies | Standard control |
|---------------|---------|------------------|
| **V2 Authentication** | **yes** | Admin credential still comes from a consumer-supplied Secret via `NEXUS_SECURITY_INITIAL_PASSWORD`; `nexus3.rootPassword.secret` remains `required` at render time with no default. **NEXUS-02 does not weaken this** — `provision.sh` still authenticates as admin to make both calls, and anonymous PUT of the anonymous config is refused (403, measured). |
| **V3 Session Management** | **yes, newly** | Activating `DockerToken` turns on Nexus's bearer-token issuance for Docker clients. The tokens are Nexus-issued and short-lived; nothing in this phase manages, stores or logs them. Worth naming because the phase deliberately enables a token realm that was previously inactive. |
| **V4 Access Control** | **yes — the core of this phase** | Anonymous maps to the built-in `nx-anonymous` role: `nx-repository-view-*-*-read`, `nx-repository-view-*-*-browse`, `nx-search-read`, `nx-healthcheck-read`. Measured read-only. **Never** grant the anonymous user an `*-add`/`*-edit`/`*-delete` privilege or a second role. |
| **V5 Input Validation** | **yes** | Both new bodies are built with `jq -n --arg/--argjson` and `jq` filters over a GET response — never string concatenation, same discipline as the ConfigMap's `toJson`. The workstation script's `--url` argument crosses into config files and must be validated (scheme is `http`/`https`, no shell metacharacters, no trailing-slash ambiguity) before interpolation. |
| **V6 Cryptography** | no | None implemented. TLS termination is Phase 25's ingress. |
| **V7 Error Handling & Logging** | **yes** | `set -euo pipefail`; never `\|\| true` a provisioning result; never echo `NEXUS_PASSWORD`; the anonymous PUT hard-fails on anything but 200 and the realms PUT on anything but 204. |
| **V10 Malicious Code** | **yes** | No new dependency (§Package Legitimacy Audit). Anonymous read does **not** introduce a write path an attacker could use to poison the cache — measured: valid-body POST 403, repository PUT upload 404. |
| **V14 Configuration** | **yes** | `anonymous.enabled` is a first-class documented value with a gate asserting its default. The realms append is guarded so configuration cannot drift on repeated upgrades. `strictContentTypeValidation: true` and `cacheForeignLayers: false` stay as Phase 23 set them. |

### Known threat patterns for this stack

| Pattern | STRIDE | Standard mitigation | Status |
|---------|--------|---------------------|--------|
| Anonymous read escalated to anonymous write | Tampering / EoP | Grant only the built-in read-only `nx-anonymous`; gate-assert that a valid-body anonymous POST returns 403 and creates nothing | Measured 403; gate is a Wave 0 item |
| Anonymous read of a **future hosted** repo containing internal packages | Information disclosure | `nx-anonymous` wildcards all repos — document it; remedy is a custom role bound to the anonymous user | **Open — Assumption A4 / Pitfall 9** |
| Repository inventory disclosure via `GET /v1/repositories` | Information disclosure | Bounded: names/formats/types/URLs only, no remote URLs or credentials. Document in README + ADR-021 | Measured 200; accepted with disclosure |
| **Realms PUT locking every user out of the instance** | Denial of service | GET-then-append-if-absent, never a literal array; skip the PUT when nothing changed | **Now in scope** — this phase makes the call. Pitfall 3 |
| **Realms list corruption by duplicate append on every upgrade** | Denial of service / integrity | `jq 'if index("DockerToken") then . else . + ["DockerToken"] end'`; gate asserts the realm appears exactly once after two passes | Measured that duplicates are stored. Pitfall 3 |
| Unauthenticated read over plaintext HTTP on a shared network | Information disclosure | TLS at ingress — **Phase 25**. Until then, network reach is the only control, and NetworkPolicy is explicitly out of scope | **Residual risk — Assumption A7** |
| Cache poisoning via a hostile `remoteUrl` override | Tampering | `toJson`-rendered bodies; `strictContentTypeValidation: true`; `remoteUrl` documented as a trust boundary | Unchanged from Phase 23 |
| Credential loss from a clobbered `.npmrc` | Information disclosure / availability | `npm config set --location=project` (measured non-destructive) + skip-if-exists + explicit `--force` | Pitfall 7 |
| `PIP_CONFIG_FILE` silently suppressing a developer's user-level pip config (e.g. a corporate CA bundle) | Tampering / availability | Warn in the generated file and in `--help`; never suggest adding it to a shell rc | Pitfall 8 |
| CE usage ceiling exhaustion once auth friction is removed | Denial of service | Document the 40,000-component / 100,000-request-per-day CE limits beside the anonymous value — anonymous pull makes the instance easier to point CI at | README note |
| Internal hostname committed to a public repo via generated config | Information disclosure | Gitignore generated files by default | Open Question 5 |

---

## Sources

### Primary (HIGH confidence — measured in this session)

- **Live `sonatype/nexus3:3.96.0-ubi` container** (booted twice), rendered from `helm template kubernetes/nexus` and provisioned by the chart's own `files/provision.sh` with `EULA_ACCEPTED=true`:
  anonymous GET/PUT status codes, bodies and idempotency; `nx-anonymous` role privileges; the `anonymous` user object; active/available realms; the before/after 401→200 matrix with byte counts for npm, PyPI and Helm; the **full anonymous Docker handshake** (ping → challenge → token → bearer manifest → child manifest → 3,626,020-byte layer blob); the four-state DockerToken × header-present causal matrix; the `forceBasicAuth` true/false comparison including the `WWW-Authenticate` header; the realms duplicate-append reproduction; the anonymous denial matrix across eight admin endpoints and two write paths; `/service/rest/swagger.json` path/method listing for `/v1/security/anonymous` and `/v1/security/realms/*`
- **A real OCI client, `gcr.io/go-containerregistry/crane`**, run anonymously inside the Nexus container's network namespace: `manifest` exit 0 with `DockerToken` active, `401 Unauthorized` with it removed, exit 0 again when restored; `export` streaming 8,083,968 bytes; `404 Not Found` on the `/repository/`-prefixed reference
- **This workstation's package-manager clients:** `npm config list` / `config get registry` / `config set --location=project` (11.7.0); `pip3 config list -v` with and without `PIP_CONFIG_FILE`, and the `pip config set` internal-error reproduction (26.2.1); `helm env` / `repo add` / `repo list` / `search repo` (4.3.0); `docker buildx imagetools inspect` URL construction for both reference shapes (28.3.2)
- **pip source, read directly:** `…/site-packages/pip/_internal/network/session.py` `SECURE_ORIGINS` and `is_secure_origin` — the loopback exemption that decides whether `trusted-host` is needed
- **Local working copy `repos/security-platform`** @ `ea2770f` (main, clean): `kubernetes/nexus/{values.yaml,templates/configmap-repos.yaml,files/provision.sh}`, `scripts/check-nexus-chart.sh`, `scripts/nexus-live-smoke.sh`, `workstation/setup.sh`
- **This repository:** `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/config.json`, `CLAUDE.md`, `.claude/rules/defensive-protocol-v2-*.md`, `docs/adr/{README.md,adr010-*,adr020-*}`, `.planning/phases/23-nexus-generic-chart/{23-RESEARCH.md,23-CONTEXT.md,23-03-PLAN.md,23-05-SUMMARY.md,23-08-SUMMARY.md,deferred-items.md}`

### Secondary (MEDIUM-HIGH — official documentation, corroborating)

- [help.sonatype.com/en/anonymous-access.html](https://help.sonatype.com/en/anonymous-access.html) — confirms the `nx-anonymous` role's privilege set **exactly** as measured, and advises against format-specific realms for anonymous accounts. Its statement that "Docker pulls also require enabling a repository-level setting on each Docker repository" did **not** reproduce here for `forceBasicAuth` (§State of the Art row 2) — recorded as a documented-vs-measured divergence rather than resolved.
- [help.sonatype.com/en/docker-repository-reverse-proxy-strategies.html](https://help.sonatype.com/en/docker-repository-reverse-proxy-strategies.html) — enumerates port-mapping, subdomain and reverse-proxy connector strategies, and warns that >20 port connectors degrade performance. **Does not document the path-routed client URL shape**, which is why Pattern 6 was established by measurement.
- [help.sonatype.com/en/eula-rest-api.html](https://help.sonatype.com/en/eula-rest-api.html), [help.sonatype.com/en/ce-onboarding.html](https://help.sonatype.com/en/ce-onboarding.html) — EULA endpoints and the CE 40,000-component / 100,000-request-per-day ceilings (carried forward from Phase 23, unchanged)

### Tertiary (LOW — unverified this session, flagged)

- Docker's `registry-mirrors` semantics — Hub-only, root-path-only (Assumption A3). Not measured; editing the operator's global `daemon.json` was out of this phase's scope.
- A `docker pull` executed by **`dockerd` specifically**. `crane` — a real OCI client speaking the same distribution protocol — completed anonymous manifest and blob fetches through the proxy (promoted to Primary above); only the daemon's own TLS/insecure-registry handling against a real hostname is untested, and Phase 25 covers it.
- ArgoCD's treatment of the chart's hook annotations — still training knowledge, unchanged from ADR-020 item 3. Phase 25's problem.

---

## Metadata

**Confidence breakdown:**

- **NEXUS-02 server-side mechanism: HIGH** — both calls, their bodies, status codes (200 and 204 respectively), idempotency behaviour and failure modes observed on a live 3.96.0 CE instance booted from the chart's own render
- **DockerToken realm requirement: HIGH** — established by a four-state causal matrix (realm present/absent × bearer header present/absent) plus the admin-token control; a first, weaker test reached the opposite conclusion and is documented as corrected rather than removed
- **Realms duplicate-append trap: HIGH** — reproduced directly
- **NEXUS-02 authorization boundary: HIGH** — eight admin endpoints and two write paths measured as denied, with the valid-body-vs-malformed-body distinction established
- **Docker path shape (ADR-020 item 2): HIGH** — a real OCI client's own URL construction was observed for both reference forms, both target paths were measured, and `crane` then succeeded on the correct reference and failed 404 on the `/repository/`-prefixed one
- **End-to-end anonymous Docker pull: HIGH** — `crane export` streamed an 8,083,968-byte filesystem tarball anonymously through the path-routed proxy, and the same command failed 401 with `DockerToken` removed and recovered when it was restored
- **`forceBasicAuth` having no effect: MEDIUM** — measured both ways including the challenge header, but it contradicts Sonatype's documentation, so it is reported as a divergence rather than a settled fact and the chart's existing value is left alone
- **Per-repo config scoping for npm / pip / Helm: HIGH** — each mechanism exercised end to end with a real anonymous package fetch, and Helm's global-file non-interference verified
- **Docker per-repo impossibility: HIGH for the negative claim** (`registry-mirrors`/`insecure-registries` are daemon-global; `DOCKER_CONFIG` does not carry mirrors), **MEDIUM for the mirror-semantics detail** (A3)
- **Second-order effects inventory: HIGH** — every one of the eight artefacts was read in this session, not recalled
- **`anonymous.enabled` default recommendation: LOW as a decision** — a judgement call with a real tradeoff that belongs to the user (A1)
- **Deferred-item dispositions: LOW as decisions** — recommendations only (A5, Open Questions 2-3)

**Research date:** 2026-09-19
**Valid until:** ~2026-10-19 (30 days). The volatile input is the Nexus version: `Chart.lock` pins
`stevehipwell/nexus3` 5.26.0 → Nexus 3.96.0, and nothing in `security-platform` bumps it
automatically (ADR-020, subchart pin freshness). Every measurement here is against 3.96.0
specifically — the `forceBasicAuth` divergence from Sonatype's own documentation in particular
should be re-measured after any subchart bump rather than assumed to carry forward.

---

*Phase: 24-Nexus Anonymous Access and Workstation Script*
*Researched: 2026-09-19*
