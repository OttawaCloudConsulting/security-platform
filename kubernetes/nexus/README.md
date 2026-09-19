# Nexus Repository

Helm chart that deploys Sonatype Nexus Repository Community Edition with npm, PyPI, Docker and Helm proxy repositories preconfigured. This is Milestone 3 of the security stack — the self-hosted services layer that gives builds a cached, auditable path to upstream package registries.

The chart is a thin wrapper around the community `nexus3` chart. It adds the four things that chart does not do: it refuses to ship or invent an admin credential, it accepts the Community Edition licence agreement only when you opt in, it provisions the proxy repositories over the Nexus REST API instead of the deprecated Groovy scripting API, and it persists the data directory by default so none of that is lost on a pod restart.

## Architecture

There is no separate architecture document for this package; the shape is small enough to state here.

```text
kubernetes/nexus/
├── Chart.yaml         # this wrapper; depends on nexus3 5.26.0
├── Chart.lock         # the pin of record for the Nexus version
├── values.yaml        # the consumer value surface
├── files/
│   └── provision.sh   # REST provisioning script, run by the hook Job
└── templates/
    ├── _helpers.tpl
    ├── configmap-provision-script.yaml
    ├── configmap-repos.yaml
    └── job-provision.yaml
```

The pinned `nexus3` subchart renders the Nexus `StatefulSet`, its `Service` and its `PersistentVolumeClaim`. This wrapper renders two `ConfigMaps` — the provisioning script and one JSON body per proxy repository — and a `Job` annotated `helm.sh/hook: post-install,post-upgrade` (and `argocd.argoproj.io/hook: Sync` for ArgoCD). After the install the Job polls `/service/rest/v1/status/writable`, accepts the EULA if you opted in, and then upserts each repository with a `GET` followed by a `PUT` or a `POST`, so re-running it on every upgrade is safe.

The Nexus version is deliberately **not** pinned here. It floats with the subchart's `appVersion` — today `nexus3` 5.26.0 resolves to Nexus 3.96.0 — and `Chart.lock` is the single control point for moving it.

## What This Delivers

| Capability | How | Notes |
|---|---|---|
| npm proxy | `npm-proxy` → `https://registry.npmjs.org` | Created by the post-install Job |
| PyPI proxy | `pypi-proxy` → `https://pypi.org` | Created by the post-install Job |
| Docker proxy | `docker-proxy` → `https://registry-1.docker.io` | `docker.pathEnabled: true`, no separate connector port; `cacheForeignLayers: false` |
| Helm proxy | `helm-proxy` → **no default** | Created only when you set `repos.helm.remoteUrl` — see below |
| Durable state | `PersistentVolumeClaim` on the cluster's default StorageClass | EULA acceptance and repository definitions live in the Nexus database, not in Kubernetes objects |
| No shipped credential | Helm `required` on the admin `Secret` name | A render without it fails loudly rather than installing something that works for everyone |
| Idempotent provisioning | `GET` → `PUT`/`POST` upsert, re-run on every upgrade | Verified by running the script twice against the same live instance |

## Requirements

| ID | Requirement | Status |
|---|---|---|
| NEXUS-01 | Chart deploys Nexus with npm, PyPI, Docker and Helm proxy repos configured | Complete (Phase 23) |
| NEXUS-02 | Proxy repos allow anonymous pull | Planned (Phase 24) |
| NEXUS-03 | Chart uses the cluster's default StorageClass unless overridden | Complete (Phase 23) |
| NEXUS-04 | Workstation install script points package managers at a Nexus instance | Planned (Phase 24) |
| NEXUS-05 | Chart validated live via private ArgoCD overlay | Planned (Phase 25) |

## Before You Install

Four properties of this chart produce a confusing failure if you skip them. Each was measured against a live Nexus 3.96.0 Community Edition instance, not assumed. Read all four before the install command.

### 1. You create the admin credential; the chart never does

`nexus3.rootPassword.secret` names an existing Kubernetes `Secret` in the release namespace. There is no default, and the chart **will not render** without it — `helm template` and `helm install` both fail with an error that names the missing value. That is deliberate: a public chart must never ship a working admin credential, and must not silently invent one either.

Create the namespace and the `Secret` first. The example prompts for the value so that nothing is written to a file or left behind in shell history:

```bash
kubectl create namespace nexus

read -rsp 'Nexus admin credential: ' NEXUS_ADMIN_PW; echo
kubectl create secret \
  generic nexus-admin \
  --namespace nexus \
  --from-literal=password="${NEXUS_ADMIN_PW}"
unset NEXUS_ADMIN_PW
```

The key read from that object is `nexus3.rootPassword.key`, which defaults to `password`.

**Rotation is not just an edit of the `Secret`.** The subchart wires this object to `NEXUS_SECURITY_INITIAL_PASSWORD` on the Nexus pod, and that variable applies only on **first boot**. Changing the `Secret` later changes the credential the provisioning Job presents, but not what Nexus itself has stored — the Job then authenticates with something Nexus no longer accepts and fails with HTTP 401. Rotating means an explicit change-credential call against the running instance (or the UI) as well as an edit of the `Secret`.

### 2. The Community Edition EULA is an explicit opt-in

`eula.accepted` defaults to `false`. Since Nexus 3.77.0 the free edition is Community Edition, and it ships with an **unaccepted** end user licence agreement that blocks component downloads.

What that looks like if you leave it unaccepted — all of this was measured:

- the pod becomes `Ready` and `helm status` reports `deployed`;
- all proxy repositories are created and appear correctly in the UI;
- metadata requests return HTTP `200`;
- and every actual package download returns HTTP `403` with a 192-byte body explaining that the EULA must be accepted.

In other words the deployment looks completely healthy and every `npm install` through it fails. Setting `eula.accepted: true` makes the provisioning Job accept the agreement (`POST /service/rest/v1/system/eula` → `204`), after which the identical download returns `200`.

The agreement is here: <https://links.sonatype.com/products/nxrm/ce-eula>. This chart deliberately does not accept a licence agreement on your behalf — accepting it is a legal act, so it is yours to perform, not the chart's.

### 3. The Helm proxy has no default remote

`repos.helm.remoteUrl` is unset, on purpose. There is no responsible default to ship:

- Helm Hub has been defunct since 2020.
- Artifact Hub replaced it as a cross-repository **search index**, not a chart repository serving a single `index.yaml` — which is exactly what a Nexus `helm` proxy requires.
- Bitnami's repository, the historical fallback, is mid-deprecation through 2026.

The concrete consequence: with the value unset, **three** proxy repositories are created (npm, PyPI, Docker) and the Helm proxy is not created at all. Set it to a chart repository that is relevant to your stack, for example `https://charts.jetstack.io`, `https://prometheus-community.github.io/helm-charts`, or an ingress-nginx repository, and the fourth proxy appears.

### 4. Community Edition has a usage ceiling

Community Edition supports up to **40,000** total components and **100,000** requests per day. Beyond either threshold, its safeguards pause the addition of new components until usage falls back below **both**. That is comfortable for a single-developer practice, but it is a real ceiling rather than a soft warning.

Because the Nexus version floats with the subchart's `appVersion` rather than being pinned in this chart, a future subchart bump can change these limits with no change in this repository. `Chart.lock` is the control point: it records the exact subchart version in use, and updating it is the deliberate act that moves the Nexus version.

## Install

The subchart tarball is not committed (`kubernetes/*/charts/*.tgz` is gitignored), so a fresh clone must resolve dependencies first:

```bash
helm dependency build kubernetes/nexus
```

Then install, having already created the namespace and the admin `Secret` as shown above:

```bash
helm install nexus kubernetes/nexus \
  --namespace nexus \
  --set nexus3.rootPassword.secret=nexus-admin \
  --set eula.accepted=true \
  --set repos.helm.remoteUrl=https://charts.jetstack.io \
  --wait --timeout 15m
```

`--timeout 15m` matches `provision.activeDeadlineSeconds` (900). Helm's default of five minutes is shorter than the provisioning Job's own ceiling, so a cold first boot can time out the release while the Job is still legitimately working.

The provisioning Job survives its own success on purpose — its delete policy is `before-hook-creation` only — so there is something to inspect afterwards, up to its 900-second TTL:

```bash
kubectl -n nexus wait --for=condition=complete job/nexus-provision --timeout=15m
kubectl -n nexus logs job/nexus-provision
```

A successful log ends with one line per repository reading `action=created` (first install) or `action=updated` (any later upgrade).

## Storage

`nexus3.persistence.enabled` defaults to `true` in this chart. The upstream default is `false`, which is an `emptyDir`: every pod restart would discard the EULA acceptance and all of the proxy repositories, because that state lives in the Nexus database on disk rather than in any Kubernetes object. A package cache that forgets itself on restart is not an acceptable default.

`nexus3.persistence.storageClass` is **absent** from this chart's values, not empty. The subchart only emits a `storageClassName` field when the key has a value, so omitting it means Kubernetes substitutes the cluster's **default StorageClass** — that omission is NEXUS-03. Measured: the default render emits no `storageClassName` at all; `--set nexus3.persistence.storageClass=longhorn` emits `storageClassName: "longhorn"`.

Do not confuse that with the upstream sentinel `"-"`, which is a different thing entirely: it renders `storageClassName: ""`, which explicitly **disables** dynamic provisioning for that claim.

`nexus3.persistence.size` defaults to `8Gi` and is overridable like any other subchart value.

## Reaching Nexus

The subchart's `Service` is named `<release>-nexus3` and listens on port 8081:

```bash
kubectl -n nexus port-forward svc/nexus-nexus3 8081:8081
```

The UI is then at <http://localhost:8081>, and the proxy repositories are served under `/repository/<name>/`, for example `http://localhost:8081/repository/npm-proxy/`.

**Reads currently require authentication.** Anonymous access is closed on a default Nexus install — an unauthenticated fetch returns HTTP 401 — and this chart does not open it. Opening read-only anonymous pull is NEXUS-02, a Phase 24 decision to take deliberately. Until then, clients authenticate with the admin credential you created above. (`nexus3.config.enabled` is `false` here, which leaves the subchart's own Groovy-based configuration Job off; this chart provisions over the REST API instead.)

## Values

Everything the `nexus3` subchart exposes can be overridden under the `nexus3` key, whether or not it appears below. Only the keys whose upstream default is wrong for this stack, plus the values this wrapper owns, are restated in `values.yaml`.

| Key | Default | Description |
|---|---|---|
| `nexus3.rootPassword.secret` | *none — required* | Name of an existing `Secret` that carries the admin credential. The chart refuses to render without it. |
| `nexus3.rootPassword.key` | `password` | Key within that object. |
| `nexus3.persistence.enabled` | `true` | Persist `/nexus-data` in a PVC. Upstream defaults to `false` (an `emptyDir`). |
| `nexus3.persistence.size` | `8Gi` | Size of the `PersistentVolumeClaim`. |
| `nexus3.persistence.storageClass` | *unset* | Absent on purpose so the cluster's default StorageClass is used (NEXUS-03). Set it only to override. |
| `nexus3.config.enabled` | `false` | Leaves the subchart's Groovy-scripting configuration Job off; this chart uses the REST API. |
| `nexus3.bashImage.digest` | `sha256:d57efd5f…` | Digest pin for the subchart's bash helper containers, replacing its mutable `latest` tag. |
| `eula.accepted` | `false` | Accept the Community Edition EULA. Until `true`, every component download returns `403`. |
| `provision.enabled` | `true` | Run the post-install Job that creates the proxy repositories. |
| `provision.activeDeadlineSeconds` | `900` | Hard wall-clock ceiling on the provisioning Job. |
| `provision.image.repository` | `docker.io/alpine/k8s` | Image for the provisioning Job (supplies `curl` and `jq`). |
| `provision.image.tag` | `1.31.2` | Tag, retained for readability. |
| `provision.image.digest` | `sha256:d489e3c7…` | Digest actually used — a tag is mutable, a digest is not (ADR-004). |
| `provision.readiness.attempts` | `60` | Readiness poll attempts. **Not wired through today** — see Limitations. |
| `provision.readiness.intervalSeconds` | `10` | Seconds between poll attempts. **Not wired through today** — see Limitations. |
| `provision.resources` | 50m/64Mi requests, 500m/256Mi limits | All four are set on purpose: the CI Checkov gate runs with `soft_fail: false`, and an unset request or limit is a finding. |
| `repos.npm.name` | `npm-proxy` | Nexus repository name for the npm proxy. |
| `repos.npm.remoteUrl` | `https://registry.npmjs.org` | Upstream registry proxied. |
| `repos.pypi.name` | `pypi-proxy` | Nexus repository name for the PyPI proxy. |
| `repos.pypi.remoteUrl` | `https://pypi.org` | Upstream index proxied. |
| `repos.docker.name` | `docker-proxy` | Nexus repository name for the Docker proxy. |
| `repos.docker.remoteUrl` | `https://registry-1.docker.io` | Upstream registry proxied. |
| `repos.helm.name` | `helm-proxy` | Nexus repository name for the Helm proxy. |
| `repos.helm.remoteUrl` | *unset* | No default (see above). The Helm proxy is created only when this is set. |

## Limitations and Notes

- **Anonymous pull is not open.** Clients authenticate with the admin credential. NEXUS-02 covers read-only anonymous access in Phase 24.
- **`provision.readiness.attempts` and `provision.readiness.intervalSeconds` are not read at run time.** The provisioning script hard-codes 60 attempts at 10-second intervals (10 minutes, inside the 900-second deadline). The values are documented because they exist, not because changing them has an effect today.
- **Renaming is supported.** If you set the subchart's `nameOverride` or `fullnameOverride`, the provisioning Job resolves the Nexus `Service` name through the same helper logic the subchart uses, so it still finds the instance. This is informational — no extra step is required.
- **`docker.pathEnabled: true`** means the Docker proxy is served on the same port under a path, with no separate connector port. An actual `docker pull` through it needs ingress and TLS, which is Phase 25 work; the repository definition itself is verified.
- **No NetworkPolicy ships with this chart.** The proxy repositories cause Nexus to make outbound HTTPS requests to the configured remotes. Constraining that is a Phase 24 decision.
- **Validation so far is a throwaway kind cluster plus a live container**, not a long-lived cluster. NEXUS-05 covers validation via a private ArgoCD overlay in Phase 25.
