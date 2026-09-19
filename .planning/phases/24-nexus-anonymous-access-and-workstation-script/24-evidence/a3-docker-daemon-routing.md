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

*(filled in by Task 2)*

---

## What this evidence does NOT establish

*(filled in by Task 2)*
