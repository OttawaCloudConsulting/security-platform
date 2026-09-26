# DefectDojo

Helm chart that deploys DefectDojo behind an external Ingress, with a TLS certificate issued by cert-manager. It is part of Milestone 3 of the security stack, the self-hosted services layer. DefectDojo is where scan findings are collected, deduplicated and triaged.

The chart is a thin wrapper around the official `defectdojo` chart, version 1.9.53, which ships DefectDojo 3.3.200. It adds four things the upstream chart does not do by default. It pins the DefectDojo image to one release. It refuses to render with TLS on until you name a cert-manager issuer. It sets small-footprint uwsgi values so the web container does not get OOMKilled. And it keeps Valkey ephemeral, since Valkey is only the Celery broker here. Every environment-specific value is yours to supply: the hostname, the issuer, and any StorageClass or IngressClass override. The chart ships none of them.

## Architecture

There is no separate architecture document for this package; the shape is small enough to state here.

```text
kubernetes/defectdojo/
├── Chart.yaml             # this wrapper; depends on defectdojo 1.9.53, appVersion 3.3.200
├── Chart.lock             # the pin of record for the subchart version
├── values.yaml            # the consumer value surface, all under the `defectdojo` key
└── templates/
    └── validate-tls.yaml  # render-time guard; renders nothing on success
```

The pinned `defectdojo` subchart renders every Kubernetes object in a release. That covers:

- the django Deployment (uwsgi and nginx containers), the Celery worker and Celery beat Deployments, and their Service and ConfigMap;
- the initializer Job, which runs migrations and first-boot setup;
- the Ingress;
- the bundled PostgreSQL and Valkey subcharts.

The wrapper renders **zero** objects. Its only template, `validate-tls.yaml`, inspects the Ingress values and aborts the render when the TLS path is misconfigured. In a successful render, every `# Source:` line points under `charts/`.

The wrapper ships no `_helpers.tpl`, and that is deliberate. Helm's template namespace is global across a parent chart and its subcharts, so a `define "defectdojo.*"` in the wrapper would silently rename every subchart object.

**The DefectDojo version is pinned here**, which is the opposite of the Nexus chart. There the Nexus version floats with the subchart's `appVersion`. Here four pin points move together: the `Chart.yaml` dependency version (recorded in `Chart.lock`), the `Chart.yaml` `appVersion`, and the django and nginx image tags in `values.yaml`. The reason is that DefectDojo runs Django schema migrations on upgrade. A floating tag could migrate the findings database without anyone deciding to, so a version change must be an explicit, reviewed act. The procedure is in Limitations and Notes.

## What This Delivers

| Capability | How | Notes |
|---|---|---|
| External Ingress | Upstream `django.ingress.enabled: true`, restated in this chart | One Ingress rule for `defectdojo.host` |
| TLS via cert-manager | `django.ingress.activateTLS: true` plus an issuer annotation you supply | cert-manager's ingress-shim creates the `Certificate` from the annotation. This chart has no `Certificate` template. |
| Issuer is required | `templates/validate-tls.yaml` fails the render | No default issuer exists. See §2. |
| Cluster default IngressClass | `ingressClassName` is absent from `values.yaml` | The Ingress carries no class, so the API server applies the cluster's default IngressClass. Set a class only to override. |
| Durable findings database | Bundled PostgreSQL with a `PersistentVolumeClaim` on the cluster's default StorageClass | Upstream default, left in place |
| Ephemeral broker | Bundled Valkey with `persistence.enabled: false` | Queued Celery tasks are transient. Upstream defaults to an 8Gi PVC. |
| No shipped credentials | Upstream `createSecret`, `createPostgresqlSecret` and `createValkeySecret` stay `false` | The default render contains zero `Secret` objects. You pre-create three Secrets. See §1. |
| Pinned version | Chart dependency, `appVersion` and both image tags at 3.3.200 | The offline gate's IMAGE-PIN check fails if they disagree |

## Requirements

| ID | Requirement | Status |
|---|---|---|
| DDOJO-01 | Public Helm chart deploys DefectDojo with external ingress and cert-manager-issued TLS | Complete (Phase 26) |
| DDOJO-02 | CI scan jobs import SARIF/JSON findings into DefectDojo after each run | Planned (Phase 27) |
| DDOJO-03 | Deduplication rules collapse repeated findings across scans and tools | Planned (Phase 28) |
| DDOJO-04 | Triage workflow for reviewing and dispositioning findings | Planned (Phase 28) |
| DDOJO-05 | Chart validated live via a private ArgoCD overlay | Planned (Phase 29) |

## Before You Install

Four properties of this chart produce a confusing failure if you skip them. Each was measured on a live DefectDojo 3.3.200 install or read from the pinned 1.9.53 templates; none is assumed. Read all four before running the install command.

### 1. You pre-create three Secrets; the chart never generates them

The chart renders no `Secret`. It expects three to exist already in the release namespace:

| Secret name | Keys | If it is absent |
|---|---|---|
| The subchart fullname: literally `defectdojo` when the release name contains `defectdojo`, otherwise `<release>-defectdojo` | `DD_ADMIN_PASSWORD`, `DD_SECRET_KEY`, `DD_CREDENTIAL_AES_256_KEY`, `METRICS_HTTP_AUTH_PASSWORD` | The nginx container reads `METRICS_HTTP_AUTH_PASSWORD` without `optional: true`, so the django pod stops at `CreateContainerConfigError`. `DD_SECRET_KEY` and `DD_CREDENTIAL_AES_256_KEY` are `optional: true`, so a missing key only surfaces at runtime, when the settings fall back to `DD_SECRET_KEY=""` and `DD_CREDENTIAL_AES_256_KEY="."`. |
| `defectdojo-postgresql-specific` | `postgresql-postgres-password`, `postgresql-password` | PostgreSQL does not start, and every database client fails |
| `defectdojo-valkey-specific` | `valkey-password` | The Celery broker rejects authentication |

Three of those keys need extra care:

- **Always supply `DD_ADMIN_PASSWORD`.** Without it, the initializer generates an admin password and **prints it to the initializer pod's log**. Anyone who can read pod logs in that namespace then has the admin credential.
- **The admin password is read on first boot only.** Once the admin user exists, the initializer logs `Admin user already exists; skipping first-boot setup`. Changing the Secret afterwards does not change the password DefectDojo has stored. To rotate it, change it in DefectDojo itself.
- **`DD_CREDENTIAL_AES_256_KEY` must never change.** DefectDojo encrypts the credentials it stores with this key. Replace the key and every credential already in the database becomes unreadable.

That last property is why this chart does not generate secrets. A chart-generated value can be regenerated on a `helm upgrade` or an ArgoCD sync, which would replace the AES key.

Create the namespace and the three Secrets first. The example uses a release named `defectdojo`, so the application Secret is literally named `defectdojo`. The admin password is prompted for, and the other values are generated at the lengths upstream's own generator uses (22, 128, 128 and 32 alphanumeric characters). Everything reaches `kubectl` on stdin, so no secret value lands in shell history, a file or a process argument list. The values are placed inside double-quoted YAML strings, so do not use `"` or `\` in the admin password:

```bash
kubectl create namespace defectdojo

gen() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$1"; }

read -rsp 'DefectDojo admin password: ' DD_ADMIN_PW; echo
DD_SECRET="$(gen 128)"; DD_AES="$(gen 128)"; DD_METRICS="$(gen 32)"
PG_ADMIN_PW="$(gen 32)"; PG_USER_PW="$(gen 32)"; VALKEY_PW="$(gen 32)"

kubectl apply --namespace defectdojo -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: defectdojo
type: Opaque
stringData:
  DD_ADMIN_PASSWORD: "${DD_ADMIN_PW}"
  DD_SECRET_KEY: "${DD_SECRET}"
  DD_CREDENTIAL_AES_256_KEY: "${DD_AES}"
  METRICS_HTTP_AUTH_PASSWORD: "${DD_METRICS}"
---
apiVersion: v1
kind: Secret
metadata:
  name: defectdojo-postgresql-specific
type: Opaque
stringData:
  postgresql-postgres-password: "${PG_ADMIN_PW}"
  postgresql-password: "${PG_USER_PW}"
---
apiVersion: v1
kind: Secret
metadata:
  name: defectdojo-valkey-specific
type: Opaque
stringData:
  valkey-password: "${VALKEY_PW}"
EOF

unset DD_ADMIN_PW DD_SECRET DD_AES DD_METRICS PG_ADMIN_PW PG_USER_PW VALKEY_PW
```

Keep a copy of `DD_CREDENTIAL_AES_256_KEY` somewhere you control, such as a SealedSecret or an external secret store. A reinstall that gets a new key cannot read the credentials encrypted with the old one.

For a throwaway local try only, the upstream opt-ins `defectdojo.createSecret=true`, `defectdojo.createPostgresqlSecret=true` and `defectdojo.createValkeySecret=true` make the chart generate the Secrets instead. Do not use them for an instance you intend to keep, for the reason above.

### 2. The certificate issuer is required

With the Ingress and TLS on (both are defaults), the render fails until you set exactly one cert-manager issuer annotation. A bare `helm template` or `helm install` stops with:

```text
defectdojo.django.ingress.activateTLS is true but no cert-manager issuer is set: set defectdojo.django.ingress.annotations."cert-manager.io/cluster-issuer" (or "cert-manager.io/issuer"), or set defectdojo.django.ingress.activateTLS=false
```

There is deliberately no default. An issuer name is specific to one cluster, so it belongs in your overlay, not in a public chart. The annotation key selects the issuer kind:

- `cert-manager.io/cluster-issuer` for a `ClusterIssuer`;
- `cert-manager.io/issuer` for a namespaced `Issuer` in the release namespace.

In an overlay values file, the annotation key is simply quoted:

```yaml
defectdojo:
  django:
    ingress:
      annotations:
        "cert-manager.io/cluster-issuer": NAME
```

On the command line, the dots inside the annotation key must be escaped:

```bash
--set 'defectdojo.django.ingress.annotations.cert-manager\.io/cluster-issuer=NAME'
```

Set **exactly one** of the two keys. Setting both fails with `set only one of cert-manager.io/cluster-issuer and cert-manager.io/issuer`.

`defectdojo.django.ingress.secretName` (default `defectdojo-tls`) must also be non-empty while TLS is on. ingress-shim names the `Certificate` after it, and upstream omits it from the Ingress when it is empty. To run a plaintext Ingress instead, set `defectdojo.django.ingress.activateTLS=false`. The guard then stands down and the Ingress has no `spec.tls`.

### 3. Set `siteUrl` together with `host`

`defectdojo.host` is the Ingress hostname and the certificate name. `defectdojo.siteUrl` becomes `DD_SITE_URL`, which DefectDojo writes into links in notifications and integrations. They are separate values, and overriding only `host` leaves `siteUrl` at the placeholder. Links then point at `https://defectdojo.example.com`, and nothing fails loudly.

Always set both, keeping the `https://` scheme while TLS is on:

```bash
--set defectdojo.host=defectdojo.example.org \
--set defectdojo.siteUrl=https://defectdojo.example.org
```

The shipped placeholder, `defectdojo.example.com`, is reserved by RFC 2606, and ACME certificate authorities refuse to issue for it. A forgotten `host` override therefore fails at certificate issuance rather than publishing under a wrong name.

### 4. The uwsgi footprint is set on purpose

With upstream's uwsgi defaults, the django pod was measured ending in `CrashLoopBackOff` with `OOMKilled` (exit 137), so `helm install --wait` never succeeded. Two causes were isolated on a kind cluster:

- With `maxFd: 0`, the container was OOMKilled at startup, and the uwsgi log reported a detected max file descriptor number of 1073741816. Setting `maxFd` alone fixed the startup OOM; setting `processes: 2` alone did not. The mechanism, that uwsgi sizes its descriptor table from that limit, is inferred from the log line, not proven. The fix is measured.
- With upstream's four processes, Django sits at about 440 MiB idle under a 512Mi limit, and the first admin login pushed it over the limit. A `GET /login` still returned 200 in that state, so a login-page check alone does not rule this out.

This chart therefore sets:

| Value | This chart | Upstream |
|---|---|---|
| `defectdojo.django.uwsgi.appSettings.processes` | `2` | `4` |
| `defectdojo.django.uwsgi.appSettings.maxFd` | `102400` | `0` (auto) |
| `defectdojo.django.uwsgi.resources` | requests 100m CPU / 384Mi, limits 2000m CPU / 1Gi | limit 512Mi |

With these settings, peak uwsgi memory after an admin login was measured at 388-430 MiB. The 1Gi limit leaves headroom above that. **Do not lower the limit below 512Mi with two processes.** If you raise `processes`, raise the limit with it.

## Install

The subchart tarball is not committed (`kubernetes/*/charts/*.tgz` is gitignored), so a fresh clone must resolve dependencies first. `helm dependency build` only downloads from repositories registered with `helm repo add`, so register the DefectDojo chart repository once per machine:

```bash
helm repo add defectdojo https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts
helm dependency build kubernetes/defectdojo
```

Then install, having already created the namespace and the three Secrets as shown above:

```bash
helm install defectdojo kubernetes/defectdojo \
  --namespace defectdojo \
  --set defectdojo.host=defectdojo.example.org \
  --set defectdojo.siteUrl=https://defectdojo.example.org \
  --set 'defectdojo.django.ingress.annotations.cert-manager\.io/cluster-issuer=NAME' \
  --wait --timeout 15m
```

Replace `defectdojo.example.org` with your hostname and `NAME` with your issuer. For anything longer-lived than a trial, put the same values in an overlay values file and pass it with `-f`.

`--timeout 15m` is needed because Helm's five-minute default is too short for a first install. The install has to pull the DefectDojo, PostgreSQL and Valkey images. The django pod's `db-migration-checker` init container then waits until the initializer has migrated a fresh database. The install alone was measured at 101 s with every image already cached, and cold image pulls add minutes on top of that.

Do not wait on the initializer Job as a readiness signal. Upstream sets `ttlSecondsAfterFinished: 60`, so the Job is deleted about a minute after it completes. The signal that matters is the django Deployment becoming Available, together with the `Certificate` becoming Ready:

```bash
kubectl -n defectdojo wait --for=condition=Available deploy/defectdojo-django --timeout=15m
kubectl -n defectdojo wait --for=condition=Ready certificate/defectdojo-tls --timeout=5m
```

DefectDojo is then served at `https://<your host>/`. Log in as `admin` with the password you put in `DD_ADMIN_PASSWORD`.

## Storage

The bundled PostgreSQL keeps its data in a `PersistentVolumeClaim`, the upstream default, left in place so findings survive a pod restart. `defectdojo.postgresql.primary.persistence.storageClass` is **absent** from this chart's values, not empty. The rendered claim therefore carries no `storageClassName` field, and Kubernetes substitutes the cluster's **default StorageClass**. To use a different class, set it explicitly:

```bash
--set defectdojo.postgresql.primary.persistence.storageClass=NAME
```

The bundled Valkey is ephemeral. `defectdojo.valkey.persistence.enabled` is `false` here, overriding the upstream subchart's 8Gi PVC. Valkey is only the Celery broker, so a restart loses in-flight tasks and nothing else.

Uploaded files and finding attachments are **not** persisted by default. They live in an upstream `emptyDir` volume. See Limitations and Notes.

## External PostgreSQL / Valkey

The bundled PostgreSQL and Valkey are on by default so that one install brings up a working stack. Either can be switched off and replaced with an instance you already run. The keys below come from the pinned 1.9.53 chart's `values.yaml` and templates. The recipe was checked by rendering the chart offline; it has not been run against a live external database.

**PostgreSQL:**

```yaml
defectdojo:
  postgresql:
    enabled: false
    auth:
      username: defectdojo                           # DD_DATABASE_USER
      database: defectdojo                           # DD_DATABASE_NAME
      existingSecret: defectdojo-postgresql-specific # Secret holding the user password
      secretKeys:
        userPasswordKey: postgresql-password         # key within that Secret
    primary:
      service:
        ports:
          postgresql: 5432                           # DD_DATABASE_PORT
  postgresServer: db.example.org                     # DD_DATABASE_HOST
```

- The port is not a separate top-level key. `DD_DATABASE_PORT` is always read from `postgresql.primary.service.ports.postgresql`, even when the bundled database is off.
- If `postgresServer` is left unset with `postgresql.enabled: false`, the host falls back to `127.0.0.1`. Always set it.
- With the bundled database off, the clients read only the `userPasswordKey`. `postgresql-postgres-password` is consumed only by the bundled PostgreSQL, so an external setup does not need it. Measured offline: that key is referenced zero times in such a render.

**Valkey / Redis:**

```yaml
defectdojo:
  valkey:
    enabled: false
    auth:
      existingSecret: defectdojo-valkey-specific # Secret holding the broker password
      existingSecretPasswordKey: valkey-password # key within that Secret
  redisServer: cache.example.org                 # DD_CELERY_BROKER_HOST
  redisPort: 6379                                # DD_CELERY_BROKER_PORT
  redisScheme: redis                             # or rediss for TLS
  redisParams: ""                                # rediss defaults to ssl_cert_reqs=optional
```

- The broker password is still read from `valkey.auth.existingSecret` and its key, even with the bundled Valkey off.
- The old `redis:` value block and `createRedisSecret` are no longer supported. Upstream fails the render on `createRedisSecret`, so do not set it.

In both cases the Secrets are still yours to create, exactly as in §1. The upstream chart's README ends its external-database recipe with `--set createSecret=true --set createValkeySecret=true`. This chart does not follow that step, for the `DD_CREDENTIAL_AES_256_KEY` reason given in §1.

## Validating an install

Two scripts in this repository check the chart. Run both from the repository root, with an explicit interpreter.

**Offline gate.** `bash scripts/check-defectdojo-chart.sh` asserts 22 invariants against the chart source with no cluster and no network, and prints `PASS - 22 checks, 0 failures` when all hold. They include:

- the issuer guard: a bare render fails, a render with either issuer key succeeds, and a render with both keys or an empty `secretName` fails;
- Ingress and TLS are on, and neither `ingressClassName` nor the PostgreSQL `storageClassName` is emitted;
- PostgreSQL is persistent and Valkey is not;
- the default render contains no `Secret`;
- the four version pins agree (IMAGE-PIN);
- the default `siteUrl` matches `host`;
- the uwsgi footprint is set;
- the wrapper has no `defectdojo.*` helper, and `values.yaml` names no real environment;
- the D-20 dedup guards (CASCADE-DELETE-OFF and DEDUP-ALGORITHM-MAP): `DD_DUPLICATE_CLUSTER_CASCADE_DELETE` renders as `"False"`, the per-parser algorithm map parses as JSON with the expected scan types, and no hash-field override ships.

Exit code 1 means a chart defect. Exit code 2 means the machine is missing a tool or the vendored subchart; resolve the dependency as described under [Install](#install) and retry.

**Live smoke.** `bash scripts/defectdojo-live-smoke.sh` builds a throwaway kind cluster named `dd-smoke`, installs the chart once, and asserts the following:

- the three DefectDojo Deployments are ready, and the PostgreSQL claim is bound;
- the `defectdojo-tls` Certificate is Ready;
- the classless Ingress was given the cluster's default IngressClass by the API server;
- `GET /login` over HTTPS returns 200, with the served certificate verified against the issuing CA (never `curl -k`);
- a real admin login succeeds: a CSRF-token `POST`, then `/dashboard` as that user;
- a Celery worker answers `celery inspect ping` through the Valkey broker.

The login and the Celery ping are there because neither a login-page 200 nor a Running worker proves the stack works (§4). The smoke covers a first install only; there is no upgrade pass.

Inside kind, the smoke installs cert-manager with a self-signed CA `ClusterIssuer`, and **ingress-nginx**, purely as a throwaway test harness. Neither that issuer nor ingress-nginx is a recommendation for a real cluster (see Limitations and Notes). The smoke never touches your current kube context, which it restores on exit, and a cold run takes roughly 10-20 minutes.

## Values

Everything the `defectdojo` subchart exposes can be overridden under the `defectdojo` key, whether or not it appears below. `values.yaml` restates only the keys whose upstream default is wrong for this stack, or which must not drift silently on a chart bump. Read the full upstream surface with `tar -xOzf kubernetes/defectdojo/charts/defectdojo-1.9.53.tgz defectdojo/values.yaml`.

| Key | Default | Description |
|---|---|---|
| `defectdojo.host` | `defectdojo.example.com` | Ingress hostname and certificate name. **Placeholder, override it.** |
| `defectdojo.siteUrl` | `https://defectdojo.example.com` | `DD_SITE_URL`. Must move together with `host` (§3). |
| `defectdojo.images.django.image.tag` | `3.3.200` | Pinned django image tag. Must equal the subchart `appVersion` (IMAGE-PIN). |
| `defectdojo.images.nginx.image.tag` | `3.3.200` | Pinned nginx image tag. Must equal the subchart `appVersion` (IMAGE-PIN). |
| `defectdojo.django.ingress.enabled` | `true` | Render the Ingress. Restated so it does not depend on the upstream default surviving a bump. |
| `defectdojo.django.ingress.activateTLS` | `true` | Emit `spec.tls` for `host`. `false` gives a plaintext Ingress and turns the issuer guard off. |
| `defectdojo.django.ingress.secretName` | `defectdojo-tls` | TLS Secret name. ingress-shim names the `Certificate` after it. Must be non-empty while TLS is on. |
| `defectdojo.django.ingress.annotations` | `{}` | Ingress annotations. Put **exactly one** of `cert-manager.io/cluster-issuer` or `cert-manager.io/issuer` here (§2). No default. |
| `defectdojo.django.uwsgi.appSettings.processes` | `2` | uwsgi worker processes. Upstream is `4`, which was measured OOMKilled at a 512Mi limit (§4). |
| `defectdojo.django.uwsgi.appSettings.maxFd` | `102400` | uwsgi file-descriptor ceiling. Upstream `0` was measured OOMKilled at startup (§4). |
| `defectdojo.django.uwsgi.resources` | requests 100m / 384Mi, limits 2000m / 1Gi | uwsgi container resources. Do not lower the limit below 512Mi with two processes. |
| `defectdojo.valkey.persistence.enabled` | `false` | Valkey is only the Celery broker. Upstream valkey 0.25.8 defaults to an 8Gi PVC. |

The following are deliberately **not** in `values.yaml`, because the upstream defaults already give the behaviour this chart wants:

- `defectdojo.django.ingress.ingressClassName` is absent, so the cluster default IngressClass applies. Set a real class name to override. Never set it to `null`, because the upstream schema types it as a string.
- `defectdojo.postgresql.primary.persistence.storageClass` is absent, so the cluster default StorageClass applies (see Storage).
- `defectdojo.createSecret`, `defectdojo.createPostgresqlSecret` and `defectdojo.createValkeySecret` are `false` upstream. They are an opt-in for throwaway tries only (§1).
- Upstream already runs a single replica of django, the Celery worker and Celery beat, with autoscaling off.

## Limitations and Notes

- **Uploaded files and attachments are lost on pod restart.** Upstream mounts DefectDojo's media directory as an `emptyDir` (`defectdojo.django.mediaPersistentVolume.type: emptyDir`). This chart keeps that default: it is a thin wrapper, and no decision to change it has been made. Findings live in PostgreSQL and survive a restart; files uploaded alongside them do not. To persist media, override `defectdojo.django.mediaPersistentVolume.*`: set `type: pvc` and either point `persistentVolumeClaim.name` at an existing claim or set `persistentVolumeClaim.create: true`. The upstream PVC option defaults to `accessModes: [ReadWriteMany]`, which many StorageClasses cannot provide. Check that yours can, or override `accessModes`, before switching.
- **CI Checkov does not cover this chart.** The pinned CI Checkov container renders charts without values. The issuer guard fails that bare render, so the chart is scanned zero times in CI. This is the same situation as the Nexus chart, and the guard is not weakened to change it. Checkov was measured locally against a render with values supplied, and the result is recorded in the phase record in the documentation repository. Every finding there is on upstream-rendered objects; the wrapper contributes no resources.
- **ingress-nginx is used only by the live smoke, and is not recommended.** The ingress-nginx project was archived in March 2026. Put this chart behind any maintained Ingress controller; it relies only on standard Ingress behaviour and the cluster's default IngressClass.
- **CSRF was measured behind one proxy only.** During research, the admin login `POST` succeeded behind ingress-nginx 1.15.1 on kind, with neither `DD_CSRF_TRUSTED_ORIGINS` nor `DD_SECURE_PROXY_SSL_HEADER` set. Why Django accepted the proxied request there was not established. If a login `POST` returns 403 behind a different controller or proxy, set `defectdojo.extraConfigs.DD_CSRF_TRUSTED_ORIGINS: https://<your host>` in your overlay, and if needed `DD_SECURE_PROXY_SSL_HEADER: "True"` as well. Neither requires a chart change.
- **Version bumps are manual.** There is no automated dependency update for this chart. To move DefectDojo to a new release:
  1. update the dependency `version` and the `appVersion` in `Chart.yaml`, and both image tags in `values.yaml`;
  2. run `helm dependency update kubernetes/defectdojo` to refresh `Chart.lock` and the vendored tarball;
  3. run `bash scripts/check-defectdojo-chart.sh`. IMAGE-PIN fails if the four pins disagree.

  Read the DefectDojo release notes before upgrading, because the upgrade runs Django migrations against your findings database.
- **Resync and upgrade behaviour are not yet validated.** The smoke covers a first install only. A second `helm upgrade` or ArgoCD sync against an instance that already holds state is validated in a later phase (DDOJO-05). That phase also covers the initializer Job's interaction with ArgoCD, since the Job name changes on every render and the Job is deleted 60 seconds after completion.
- **The decisions behind this chart** are recorded in ADR-023 in the `security_solution` documentation repository: the wrapper shape, the version pin, the issuer guard, the Secret contract and the storage defaults.
