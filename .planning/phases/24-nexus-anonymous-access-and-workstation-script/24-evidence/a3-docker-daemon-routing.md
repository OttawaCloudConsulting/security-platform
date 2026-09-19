# Assumption A3, measured: can a path-routed Nexus Docker proxy serve as a Docker daemon `registry-mirrors` target?

**Phase:** 24-nexus-anonymous-access-and-workstation-script
**Plan:** 24-04
**Measured:** 2026-09-19
**Probe:** [`a3-dind-probe.sh`](./a3-dind-probe.sh) (non-executable; `bash a3-dind-probe.sh [--validate-only]`)
**Consumer:** [`../24-07-PLAN.md`](../24-07-PLAN.md) — the named verdict below selects which of
that plan's pre-written implementation branches is built.

## The assumption under test

24-RESEARCH.md §Assumptions Log:

> **A3** — Docker's `registry-mirrors` only mirrors Docker Hub and requires the mirror at the
> registry root, so a path-routed Nexus repo cannot serve as a daemon mirror.
> *Confidence: Medium. Not measured — editing the operator's global `daemon.json` was out of scope.*

24-CONTEXT.md's locked Docker decision ("the script still writes the Docker global config
`~/.docker/daemon.json`") rests entirely on A3 being FALSE. If A3 is true, the script would write a
key that routes nothing — a configuration knob that reads like a control and changes nothing.

## Environment

| Item | Value |
|------|-------|
| Host engine | Docker 28.3.2, Docker Desktop, darwin/arm64 |
| Probe engine | `docker:28.3.2-dind`, pinned `docker@sha256:44383404ebf0c36243f5969f0dddd23c204ea3bb185e7473a4141f6ccfd07b53` |
| Nexus | resolved from the chart's own rendered StatefulSet, `sonatype/nexus3:3.96.0-ubi` |
| Host `~/.docker/daemon.json` | `55a16d289b1bd748b186117e8bc1937c5c65ff4e` — asserted identical before and after every run |

The dind image is pinned to the **exact** host engine version rather than the floating `28-dind`
tag, so "the probe measured a different engine than the one this phase targets" is not available as
an objection.

---

## 1. Documentary reading (NOT a verdict)

Two sources, read this session. Labelled explicitly for version match, because "the docs say" and
"this engine does" are different claims.

### 1a. moby `registry` package — VERSION-MATCHED to 28.3.2

Source: `https://raw.githubusercontent.com/moby/moby/v28.3.2/registry/config.go` (the `v28.3.2` tag,
i.e. exactly the engine version installed here) and
`https://raw.githubusercontent.com/moby/moby/v28.3.2/registry/service_v2.go`.

**(i) `ValidateMirror` does NOT reject a path.** The complete rejection set in v28.3.2 is: no
scheme, a scheme other than `http`/`https`, a query string or fragment, and userinfo. A path is
accepted and the value is normalised by appending a trailing `/`:

```go
	if uri.RawQuery != "" || uri.Fragment != "" {
		return "", invalidParamf("invalid mirror: query or fragment at end of the URI %q", uri)
	}
	if uri.User != nil { … }
	return strings.TrimSuffix(mirrorURL, "/") + "/", nil
```

So the "requires the mirror at the registry root" half of A3 is **not enforced at configuration
parse time** on this engine. Whether the path survives into the request the daemon actually makes
is a separate question, which §2 and §3 answer.

**(ii) Mirrors are attached to Docker Hub and to nothing else.** `loadMirrors` and
`loadInsecureRegistries` both build `config.IndexConfigs`, and in both the mirror list is assigned
to exactly one index — `IndexName`, i.e. `docker.io`. Every other index is constructed with
`Mirrors: []string{}`:

```go
	config.IndexConfigs = map[string]*registry.IndexInfo{
		IndexName: {Name: IndexName, Mirrors: unique, Secure: true, Official: true},
	}
	…
			indexConfigs[r] = &registry.IndexInfo{
				Name: r, Mirrors: []string{}, Secure: false, Official: false,
			}
```

`lookupV2Endpoints` corroborates it from the other end: mirror endpoints are appended **only** on
the `hostname == DefaultNamespace || hostname == IndexHostname` branch.

This makes the **Hub-only half of A3 CONFIRMED from version-matched source**, independent of any
measurement below. A `registry-mirrors` entry can never route `ghcr.io/…`, `quay.io/…`,
`public.ecr.aws/…` or any other non-Hub reference.

**(iii) The mirror's path IS carried into the endpoint.** `lookupV2Endpoints` parses the mirror
string into a `*url.URL` and stores the whole URL, path included, on the `APIEndpoint`:

```go
			mirrorURL, err := url.Parse(mirror)
			…
			endpoints = append(endpoints, APIEndpoint{URL: mirrorURL, Mirror: true, …})
```

That is why there are **two** candidate URLs below and not one: a path-bearing mirror is at least
structurally plausible on this engine, which is precisely what makes recall an unsafe basis for the
decision.

### 1b. Docker documentation — NOT version-matched (docs `main` branch, product-wide)

Retrieved via Context7 (`/docker/docs`).

- `content/manuals/docker-hub/image-library/mirror.md` — *"It's currently not possible to mirror
  another private registry. Only the central Hub can be mirrored."* Corroborates §1a(ii).
- `content/manuals/docker-hub/image-library/mirror.md` — the documented `daemon.json` example is a
  bare host with **no path**: `{"registry-mirrors": ["https://<my-docker-mirror-host>"]}`.
- `content/manuals/ai/sandboxes/configuration/registry-mirror.md` — *"Docker pulls inside the
  sandbox will not be mirrored when a path prefix is present."* **This is Docker Sandboxes, a
  different product with its own `platform.images.registryMirror` setting — it is NOT the engine's
  `registry-mirrors` key.** It is recorded here because it is the only Docker-authored statement
  found about path prefixes in a mirror, and because it shows a sibling product explicitly
  degrading on exactly the shape this plan is testing. It is evidence of intent, not of engine
  behaviour.

**Nothing in the documentation states whether the engine's own `registry-mirrors` accepts or
honours a path.** That silence is the reason this plan exists.

---

## 2. Validation stage — does a path-bearing mirror URL even parse?

`dockerd --validate --config-file <tmp>` inside a throwaway `docker:28.3.2-dind` container. This
parses the configuration and exits without starting an engine, so it answers the parse question
with no privileged container and no host daemon involvement at all.

Run: `bash a3-dind-probe.sh --validate-only`, 2026-09-19.

| Row | Config | Exit | Output |
|-----|--------|------|--------|
| **control-empty** | `{}` | **0** | `configuration OK` |
| **control-query** | `{"registry-mirrors":["http://a3-nexus:8081/x?y=1"]}` | **1** | `unable to configure the Docker daemon with file /tmp/a3-daemon.json: merged configuration validation from file and command line flags failed: invalid mirror: query or fragment at end of the URI "http://a3-nexus:8081/x?y=1"` |
| **candidate-1** | `{"registry-mirrors":["http://a3-nexus:8081/repository/docker-proxy"],"insecure-registries":["a3-nexus:8081"]}` | **0** | `configuration OK` |
| **candidate-2** | `{"registry-mirrors":["http://a3-nexus:8081/docker-proxy"],"insecure-registries":["a3-nexus:8081"]}` | **0** | `configuration OK` |

The two controls are what make the two candidate rows mean anything:

- **control-empty exit 0** proves the harness runs `dockerd` correctly. Without it, a candidate
  exit 1 would be unattributable — it could be a broken container invocation rather than a rejected
  mirror.
- **control-query exit 1** proves `--validate` genuinely inspects `registry-mirrors`. Without it, a
  candidate exit 0 would be a vacuous pass — `--validate` might simply not be looking at the key.

**Result: both candidates PARSE.** A path-bearing `registry-mirrors` URL is accepted by Docker
28.3.2. The `--validate` stage therefore does **not** settle A3, and the routing stage below is the
discriminating measurement. (Had both candidates been rejected here, A3 would have been CONFIRMED
at this point and the routing stage would have had nothing to measure.)

---

## 3. Routing stage — does the mirror actually route?

Run: `bash a3-dind-probe.sh`, 2026-09-19. One throwaway Nexus (`a3-nexus`, host port 8082),
provisioned by **the chart's own `kubernetes/nexus/files/provision.sh`** with the four repo bodies
extracted from the chart's own rendered `-repos` ConfigMap — so this is evidence about the shipped
chart, not about a hand-made Nexus:

```
EULA: accepted (HTTP 204).
anonymous: OPEN (HTTP 200) — unauthenticated READ is now allowed across every repository ...
realms: appended DockerToken (HTTP 204). ["NexusAuthenticatingRealm","DockerToken"]
repo: format=docker name=docker-proxy action=created (HTTP 201)
Provisioning complete: 4 proxy repositor(ies) present and online.
```

Each candidate then got a **freshly created** privileged `docker:28.3.2-dind` container (removed
with `docker rm -f -v` between candidates, so its `/var/lib/docker` anonymous volume — and with it
any cached layer — was destroyed, not reused).

### The verdict criterion, stated before the numbers

**The verdict is the Nexus components delta, never the pull exit code.** Docker's mirror logic
falls back to the upstream registry on any mirror error, so `docker pull` exit 0 is equally
consistent with the mirror having worked and with the mirror having been ignored entirely. Only

```
GET /service/rest/v1/components?repository=docker-proxy
```

going from zero items to items naming `library/alpine` proves that traffic reached Nexus.

### candidate-1 — `http://a3-nexus:8081/repository/docker-proxy`

| Measurement | Value |
|-------------|-------|
| `docker info` Registry Mirrors (verbatim) | ` Registry Mirrors:`<br>`  http://a3-nexus:8081/repository/docker-proxy/` |
| `docker info --format '{{json .RegistryConfig.Mirrors}}'` | `["http://a3-nexus:8081/repository/docker-proxy/"]` |
| components BEFORE | **0** |
| `docker pull alpine:3.21` exit | **0** |
| pull output, first lines | `3.21: Pulling from library/alpine` / `248d4d6535e8: Pulling fs layer` / `248d4d6535e8: Download complete` / `Digest: sha256:ce64758a109eb420d874a118f87920e625e12d3634e03b4a5573fd9f6e5d3507` / `Status: Downloaded newer image for alpine:3.21` / `docker.io/library/alpine:3.21` |
| components AFTER | **1** |
| components that appeared | `/library/alpine:3.21` |

**candidate-1 ROUTED.** Nexus's `docker-proxy` holds an artefact it did not hold before the pull.
Note that the client still reports the image as `docker.io/library/alpine:3.21` — the mirror is
transparent to the reference, which is exactly the property a workstation script would want and
exactly the property that makes a *non-working* mirror invisible.

The normalised mirror value shows the path **survived** into the daemon's own registry config,
confirming §1a(iii) empirically: moby stores the whole mirror URL, and the `/v2/` route is appended
after the configured path, producing `/repository/docker-proxy/v2/...` — one of the three shapes
24-RESEARCH.md Pattern 6 measured as HTTP 200.

### candidate-2 — `http://a3-nexus:8081/docker-proxy`

| Measurement | Value |
|-------------|-------|
| `docker info` Registry Mirrors (verbatim) | ` Registry Mirrors:`<br>`  http://a3-nexus:8081/docker-proxy/` |
| `docker info --format '{{json .RegistryConfig.Mirrors}}'` | `["http://a3-nexus:8081/docker-proxy/"]` |
| components BEFORE | **0** (the single component cached by candidate-1 was DELETEd via `/service/rest/v1/components/{id}` and the zero re-asserted, not assumed) |
| `docker pull alpine:3.21` exit | **0** |
| pull output, first lines | `3.21: Pulling from library/alpine` / `248d4d6535e8: Pulling fs layer` / `248d4d6535e8: Download complete` / `Status: Downloaded newer image for alpine:3.21` |
| components AFTER | **0** |
| components that appeared | none |

**candidate-2 DID NOT ROUTE — and this is the row that matters most.** The pull *succeeded*, exit
0, with real layer traffic (`Pulling fs layer` … `Download complete` on a freshly created engine
whose image store had just been destroyed). It succeeded because Docker silently fell back to
Docker Hub. Had this probe scored routing on the pull exit code, candidate-2 would have been
recorded as a working mirror. It is not one. **A `docker pull` that succeeds with no components
delta is NOT routing.**

That asymmetry is the whole reason the `/repository/` question had to be measured rather than
reasoned: `HOST/docker-proxy/...` is the correct *image reference* shape (Pattern 6), and
`HOST/repository/docker-proxy` is the correct *mirror URL* shape. They are different, and the
intuitive one is the wrong one.

### Teardown and the host-daemon assertion

```
=== T-24-17 host daemon.json assertion ===
    path:   /Users/christian/.docker/daemon.json
    before: 55a16d289b1bd748b186117e8bc1937c5c65ff4e
    after:  55a16d289b1bd748b186117e8bc1937c5c65ff4e
    UNCHANGED
```

After the run: `docker ps -a --filter name=a3-` empty, `docker network ls --filter name=a3-net`
empty. All container removals used `-v`, so the dind image-store volumes went with them.

---

VERDICT: A3-FALSIFIED-CANDIDATE-1

Read precisely, that verdict means: **a path-routed Nexus Docker proxy CAN serve as a Docker daemon
`registry-mirrors` target, at the `/repository/<repo>` URL and only at that URL.** The "requires the
mirror at the registry root" half of A3 is falsified. The "only mirrors Docker Hub" half of A3 is
**confirmed** — by version-matched source (§1a(ii)), not by this measurement — and continues to
apply.

---

## What this evidence does NOT establish

1. **The dind engine is not Docker Desktop's engine.** The measurement ran inside a privileged
   `docker:28.3.2-dind` container — the same dockerd version as the host, but a *nested Linux
   engine with its own classic image store*. Docker Desktop runs its engine inside a LinuxKit VM
   and may use the containerd image store, whose registry-mirror handling is configured differently
   (`hosts.toml`) and was not exercised here. **The operator's own Docker Desktop engine was never
   configured with either candidate mirror and was never restarted.** If plan 24-07 ships a
   daemon-writing branch, the first real run on Docker Desktop is still an unmeasured step.
2. **No TLS anywhere.** Both candidates were plaintext `http://` to a non-loopback container name,
   with `insecure-registries` carrying `a3-nexus:8081`. Nothing here was measured against a
   TLS-terminated Nexus, which is what Phase 25's ingress will produce. ADR-009 governs the warning
   text for `insecure-registries` in any shipped code.
3. **The two `daemon.json` keys were never separated.** Every candidate config carried
   `registry-mirrors` *and* `insecure-registries` together. The probe therefore cannot say whether
   `registry-mirrors` alone would route over plain HTTP, nor whether `insecure-registries` alone is
   enough. If 24-07 writes only one key, that combination is unmeasured.
4. **The Nexus under test had anonymous access OPEN.** `provision.sh` ran with
   `ANONYMOUS_ENABLED=true`, diverging from the chart's shipped default of `false` (24-01). Whether
   the mirror routes against a closed instance — it should not, and should fall back silently to
   Docker Hub, which is the same invisible-failure shape as candidate-2 — was not measured.
5. **One image, one tag, one pull, one run per candidate.** `alpine:3.21` from `library/`. No
   multi-arch selection behaviour, no large image, no rate-limit behaviour, no repeat run.
6. **Non-Hub references are out of reach and always will be.** Per §1a(ii), `ghcr.io/...`,
   `quay.io/...`, `public.ecr.aws/...` and every other non-`docker.io` reference is unaffected by
   any `registry-mirrors` value. A workstation script that sets a mirror routes *part* of a typical
   project's images and must say so.
7. **Nexus ran on the host engine, not inside dind.** 24-04-PLAN.md's ordering note (boot Nexus
   after the dind engine "so a dind restart cannot kill it") does not apply to this arrangement:
   `a3-nexus` is a sibling container on the host engine, sharing the `a3-net` user-defined network
   with the nested engine's *container*, so recreating the dind container between candidates cannot
   disturb Nexus. The plan's numbered step order (network → Nexus → provision → per-candidate dind)
   is what was executed.

---

## Consequence for plan 24-07

A `registry-mirrors` entry at `HOST/docker-proxy` — the shape that looks right because it is the
image-reference shape — is a key that **reads like a control and routes nothing**, the same defect
Phase 23 removed in commit `a9c4f38`. If a daemon-writing branch is built, the URL must be
`HOST/repository/docker-proxy`, and the script must not present the Docker ecosystem as fully
routed: non-Hub references are never mirrored.

## Decision

*(pending — the operator selects at the 24-04 Task 3 checkpoint, with this evidence in front of
them; the reply and its date are appended verbatim here, and plan 24-07 reads the selection from
this file rather than from a chat transcript)*
