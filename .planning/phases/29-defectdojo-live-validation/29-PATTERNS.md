# Phase 29: DefectDojo Live Validation - Pattern Map

**Mapped:** 2026-09-26
**Files analyzed:** 27 new or modified files across three repositories
**Analogs found:** 25 / 27

Repository shorthands used below:
- `APP` = `~/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config`
- `CLU` = `~/git-repos/OCC-github/kubernetes_stack/occ-k8s-cluster-config`
- `SP` = `repos/security-platform` (local clone; branch `feature/phase-28-...` at `c77e4f4`, tree identical to `origin/main` `c8027e6`, measured with `git diff --stat origin/main HEAD` returning nothing)
- `DOC` = this repository root

All line numbers were read on 2026-09-26 and apply to the current files.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `APP/application-sets/platform/defectdojo/argocd-overrides.yaml` (new) | config (Argo Application) | GitOps request-response | `APP/application-sets/platform/nexus/argocd-overrides.yaml` | exact |
| `APP/.../platform/defectdojo/Chart.yaml` (new) | config (source-2 chart) | n/a | `APP/.../platform/nexus/Chart.yaml` | exact |
| `APP/.../platform/defectdojo/README.md` (new) | docs | n/a | `APP/.../platform/nexus/README.md` | exact |
| `APP/.../defectdojo/templates/sealedsecret-defectdojo.yaml` (new) | config (secret) | batch (apply wave -1) | `APP/.../nexus/templates/sealedsecret-nexus-admin.yaml` | exact |
| `APP/.../defectdojo/templates/sealedsecret-defectdojo-postgresql-specific.yaml` (new) | config (secret) | batch | same | exact |
| `APP/.../defectdojo/templates/sealedsecret-defectdojo-valkey-specific.yaml` (new) | config (secret) | batch | same | exact |
| `APP/.../defectdojo/templates/certificate.yaml` (new) | config (cert-manager) | event-driven (issuance) | `APP/.../homepage/templates/certificate.yaml` | exact |
| `APP/.../defectdojo/templates/ghostunnel-deployment.yaml` (new) | workload (L4 TLS proxy) | streaming (TCP proxy) | `APP/.../homepage/templates/deployment.yaml`, container `tls` | role-match (sidecar becomes standalone) |
| `APP/.../defectdojo/templates/service.yaml` (new) | config (LB Service) | request-response | `APP/.../homepage/templates/service.yaml` | exact |
| `APP/.../platform/arc-systems/argocd-overrides.yaml` (new) | config (CRD-owning operator App) | GitOps | `APP/.../platform/cloudnative-pg/argocd-overrides.yaml` | exact |
| `APP/.../platform/arc-systems/README.md` (new) | docs | n/a | `APP/.../cloudnative-pg/README.md` / `nexus/README.md` | role-match |
| `APP/.../platform/arc-runners/argocd-overrides.yaml` (new) | config (two-source App: OCI chart + local) | GitOps | cloudnative-pg (OCI source 1) + nexus (local source 2) | role-match (composite) |
| `APP/.../platform/arc-runners/Chart.yaml` (new) | config | n/a | `nexus/Chart.yaml` | exact |
| `APP/.../arc-runners/templates/sealedsecret-arc-github-pat.yaml` (new) | config (secret) | batch | `nexus/templates/sealedsecret-nexus-admin.yaml` | exact |
| `APP/application-sets/automation/argocd/templates/projects.yaml` (modify: `platform` AppProject) | config (RBAC) | n/a | the same file, Phase 25 / Feature 7.1 amendments at lines 273-376 | exact |
| `SP/.github/workflows/security.yml` (modify, 2 `runs-on` lines + comments) | workflow (callee) | event-driven | the same file, lines 1259-1270 and 1645-1653 | exact |
| `SP/.github/workflows/defectdojo-import-proof.yml` (modify, comments only) | workflow (caller) | event-driven | the same file, lines 21-27 and 35-38 | exact |
| `SP/scripts/check-workflow-uploads.sh` (modify: runs-on shape assertion) | test (offline gate) | transform (YAML parse) | the same file, SIDE-CHANNEL-SHAPE lines 412-450 | exact |
| `SP/scripts/defectdojo-homelab-validate.sh` (new) | test (live gate) | request-response | `SP/scripts/nexus-homelab-validate.sh` + `SP/scripts/defectdojo-live-smoke.sh` lines 660-752 | exact |
| D-11 API assertion helper (new; script such as `SP/scripts/defectdojo-lifecycle-assert.sh` or an evidence-dir runbook block) | test (live API assertions) | request-response / CRUD | `SP/scripts/defectdojo-import-proof.sh` (P-DISPOSITION, P-REPARENT) + `SP/kubernetes/defectdojo/TRIAGE.md` lines 70-110 | exact |
| `SP/kubernetes/defectdojo/README.md` (modify: row 55 + line 401) | docs | n/a | the same file, rows 51-54 | exact |
| `DOC/scripts/check-adoption-guide.sh` (modify: `DD_REQUIRED`) | test (docs gate) | transform | the same file, lines 262-298 | exact |
| `DOC/docs/adoption-guide.md` (modify: section 12) | docs | n/a | the same file, lines 599-842 | exact |
| `DOC/docs/adr/adr027-*.md` (new) | docs (ADR) | n/a | `DOC/docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md` (+ ADR-026 `### Measured evidence`) | exact |
| `DOC/docs/adr/adr028-*.md` (new, ARC) | docs (ADR) | n/a | same | role-match |
| `DOC/docs/adr/README.md` (modify: 2 rows) | docs (index) | n/a | the same file, lines 32-36 | exact |
| `DOC/.planning/REQUIREMENTS.md` (modify: lines 26 and 56) | docs (tracking) | n/a | the same file, lines 22-25 and 51-55 | exact |
| `CLU/docs/upgrade/cilium-l2-vantage-host-runbook.md` (modify: VLAN43 table) | docs (runbook) | n/a | the same file, lines 26-52 | exact (table is stale, see below) |
| Throwaway reachability pod manifest (new, evidence-only, not committed to an overlay) | test fixture | request-response | none | no analog |
| ARC scale-set `valuesObject` content (inside `arc-runners/argocd-overrides.yaml`) | config | n/a | none in either overlay repo | no analog (use RESEARCH Pattern 3) |

---

## Pattern Assignments

### `APP/application-sets/platform/defectdojo/argocd-overrides.yaml` (Argo Application, GitOps)

**Analog:** `APP/application-sets/platform/nexus/argocd-overrides.yaml` (lines 1-120, read in full)

**Header block to copy (lines 1-25).** Restate every rule with DefectDojo nouns: the file is the Application; deleting it deletes the Application; `preserveResourcesOnDeletion: true`, so rollback removes the workloads first and the file second; exactly one override file at the directory root (R32); no `spec.project` (F-10); the project comes from the path `application-sets/platform/defectdojo`.

**Multi-source shape (lines 26-53, 83-87):**
```yaml
argocdOverrides:
  spec:
    source: null          # REQUIRED with sources: (R8, F-11); comment lines 28-33 explain why
    sources:
      - repoURL: https://github.com/OttawaCloudConsulting/security-platform   # byte-identical to AppProject sourceRepos (line 286)
        targetRevision: aed14b916e9aa8ec1d0d47699b457040b99f7eac              # IMMUTABLE SHA; comment records the `git ls-remote` date
        path: kubernetes/nexus
        helm:
          releaseName: nexus
          valuesObject:
            ...
      - repoURL: https://github.com/OttawaCloudConsulting/occ-k8s-app-config
        targetRevision: main
        path: application-sets/platform/nexus
```
DefectDojo deltas:
- `path: kubernetes/defectdojo`, with `targetRevision` = the security-platform `main` SHA read with `git ls-remote` on the day of the change (`c8027e6...` today; record the full 40-character SHA and the date in the comment, as in lines 41-45).
- Nexus lines 47-49 note that the subchart tarball is not committed and the repo-server runs `helm dependency build`. Write the equivalent for the DefectDojo helm-charts repository.
- **`releaseName: defectdojo` is load-bearing.** `SP/kubernetes/defectdojo/README.md` line 67: the subchart fullname is literally `defectdojo` only when the release name contains `defectdojo`. The three pre-created Secret names (`defectdojo`, `defectdojo-postgresql-specific`, `defectdojo-valkey-specific`, README lines 67-69), the `defectdojo-django` Service targeted by ghostunnel and the `defectdojo-initializer` Job name all depend on it. Carry a "never change it" comment like Nexus lines 54-56.
- Give every value its own "OMITTED:" symptom comment (Nexus lines 57-82 style). The values come from RESEARCH Pattern 1: `host`, `alternativeHosts`, `siteUrl`, `django.ingress.enabled: false`, `extraConfigs.DD_CSRF_TRUSTED_ORIGINS`, `initializer.staticName/keepSeconds/jobAnnotations`. The `valuesObject` root key is `defectdojo:`, because the security-platform chart is a wrapper.

**syncPolicy (lines 88-120), copy verbatim with DefectDojo budget comments:**
```yaml
    syncPolicy:
      automated:
        $patch: replace
        enabled: true
        selfHeal: true
        prune: true
      syncOptions:            # REPLACES, not appends (F-12)
        - CreateNamespace=true
        - ApplyOutOfSyncOnly=true
      retry:                  # under syncPolicy, never spec (R9)
        limit: 5
        backoff:
          duration: 30s
          factor: 2
          maxDuration: 10m
```
Keep the Nexus lines 101-103 "No server-side apply option, deliberately" comment, since the DefectDojo render contains no CRD.

---

### `APP/.../platform/defectdojo/Chart.yaml` and `APP/.../platform/arc-runners/Chart.yaml`

**Analog:** `APP/.../nexus/Chart.yaml` (lines 1-16)
```yaml
apiVersion: v2
name: nexus
version: 0.1.0
description: OCC Homelab Nexus local manifests -- the admin-credential SealedSecret
# ... There is deliberately NO `dependencies:` block. ... the conformance Helm render matrix
# requires this directory to `helm template` cleanly on its own.
appVersion: "3.96.0"
```
Deltas: set `appVersion: "3.3.200"` for defectdojo and `"0.14.2"` for arc-runners. Keep the no-`dependencies:` rationale. The templates directory contains plain YAML. Do not use `{{ }}`: the two SealedSecret ciphertexts and the Certificate must render byte-identical.

---

### SealedSecrets (4 files): `defectdojo/templates/sealedsecret-defectdojo{,-postgresql-specific,-valkey-specific}.yaml`, `arc-runners/templates/sealedsecret-arc-github-pat.yaml`

**Analog:** `APP/.../nexus/templates/sealedsecret-nexus-admin.yaml` (lines 1-33)
```yaml
# <what it is>, SEALED so no plaintext credential is ever in Git. ... Retrieve with:
#   kubectl -n nexus get secret nexus-admin -o jsonpath='{.data.password}' | base64 -d
# The chart consumes it through ... -- the two names must stay in step.
# STRICT SCOPE: the ciphertext is bound to this exact name AND namespace ... Renaming either one
# means re-sealing with scripts/seal-secret.sh (controller sealed-secrets/sealed-secrets on this cluster)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: nexus-admin
  namespace: nexus
  annotations:
    # Wave -1 orders the apply ... It CANNOT wait for decryption: Argo CD has no health
    # assessment for bitnami.com/SealedSecret on this cluster (measured) ...
    argocd.argoproj.io/sync-wave: "-1"
spec:
  encryptedData:
    password: AgC...
  template:
    metadata:
      name: nexus-admin
      namespace: nexus
    type: Opaque
```
Deltas:
- Keys follow the chart README lines 65-69: `DD_ADMIN_PASSWORD`, `DD_SECRET_KEY`, `DD_CREDENTIAL_AES_256_KEY` and `METRICS_HTTP_AUTH_PASSWORD` go in `defectdojo`; `postgresql-postgres-password` and `postgresql-password` go in `defectdojo-postgresql-specific`; `valkey-password` goes in `defectdojo-valkey-specific`. The ARC Secret is `arc-github-pat` with key `github_token`, in namespace `arc-runners` (RESEARCH Pattern 3).
- Use the explicit `namespace:` in both `metadata` and `template.metadata`, as Nexus does.
- Sealing tool: `APP/scripts/seal-secret.sh`, which is env-file driven (header lines 4-25). **`CONTROLLER_NAMESPACE` defaults to `kube-system` (line 19); set `CONTROLLER_NAMESPACE=sealed-secrets`** (ADR-022 d3).
- Pitfall 9 comment for the postgres Secret: Postgres reads it only on first init, and deleting the PVC to fix auth destroys data (no backup).

---

### `APP/.../defectdojo/templates/service.yaml` (LB Service, request-response)

**Analog:** `APP/.../homepage/templates/service.yaml` (lines 1-40)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: homepage
  labels:
    app.kubernetes.io/name: homepage
    # LB-IPAM selector: vlan43-static pool (10.40.3.60-79) ... Values MUST be quoted strings
    vlan: "43"
    IPautoAssign: "false"
  annotations:
    lbipam.cilium.io/ips: 10.40.3.77
spec:
  type: LoadBalancer
  # MUST be Cluster, never Local, on an L2-announced VIP ... Enforced at admission by
  # application-sets/platform/admission-policies/l2-announced-vip-etp-policy.yaml ([Deny, Audit]).
  externalTrafficPolicy: Cluster
  ports:
    - port: 443
      targetPort: https
      protocol: TCP
      name: https
  selector:
    app.kubernetes.io/name: homepage
```
Deltas:
- The annotation value is `"10.40.3.65"`, quoted per D-03. Homepage leaves it unquoted, so follow D-03.
- **The selector must match the standalone ghostunnel Deployment's pod label** (for example `app.kubernetes.io/name: defectdojo-ghostunnel`), **not** the chart's django pods. If it selected django, the VIP would send :443 to nginx :80.
- Reword the port comment for this case. DefectDojo authenticates, so the concern is that plaintext django :80 stays reachable in-cluster with no NetworkPolicy (hardening bucket, RESEARCH Pattern 2). Homepage's NetworkPolicy is **not** copied.

---

### `APP/.../defectdojo/templates/certificate.yaml` (cert-manager, event-driven)

**Analog:** `APP/.../homepage/templates/certificate.yaml` (lines 1-54). Copy lines 26-54 verbatim and adjust the names:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: homepage-tls
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  labels:
    app.kubernetes.io/name: homepage
spec:
  secretName: homepage-tls
  secretTemplate:
    labels:
      app.kubernetes.io/name: homepage
  commonName: homepage.home.ottawacloudconsulting.com
  dnsNames:
    - homepage.home.ottawacloudconsulting.com
    - homepage.infra.ottawacloudconsulting.com
  privateKey:
    algorithm: ECDSA
    size: 256
    rotationPolicy: Always
  usages:
    - server auth
  duration: 2160h
  renewBefore: 720h
  issuerRef:
    name: letsencrypt-dns01-prod
    kind: ClusterIssuer
    group: cert-manager.io
```
Deltas: name and secret `defectdojo-tls`, with SANs `defectdojo.infra.ottawacloudconsulting.com` and `defectdojo.home.ottawacloudconsulting.com`. For `commonName`, choose `.infra`, because `siteUrl` and `host` are `.infra`. Keep the header rationale from lines 16-25: wave -1 is health-gated, DNS-01 needs no A record, and `.home` sits in the same apex zone.

---

### `APP/.../defectdojo/templates/ghostunnel-deployment.yaml` (standalone L4 proxy)

**Analog:** `APP/.../homepage/templates/deployment.yaml`. Deployment skeleton at lines 1-23. `tls` container at lines 84-163. Volume at lines 170-172.

**Container to copy (lines 91-163), keeping every comment:**
```yaml
          image: docker.io/ghostunnel/ghostunnel:v1.11.3-distroless
          imagePullPolicy: IfNotPresent
          args:
            - server
            - --listen=:8443
            - --target=127.0.0.1:3000                      # DELTA
            - --cert=/etc/ghostunnel/tls/tls.crt
            - --key=/etc/ghostunnel/tls/tls.key
            - --disable-authentication                     # lines 99-103 rationale
            - --timed-reload=300s                          # lines 105-109: ghostunnel does not watch cert files
            - --status=http://0.0.0.0:8082                 # lines 111-113: scheme mandatory, bind 0.0.0.0
            - --target-status=http://127.0.0.1:3000/       # DELTA
          ports:
            - name: https
              containerPort: 8443
            - name: status
              containerPort: 8082
          volumeMounts:
            - name: tls                                    # whole-directory, never subPath (lines 124-128)
              mountPath: /etc/ghostunnel/tls
              readOnly: true
          readinessProbe: { httpGet: { path: /_status, port: status }, initialDelaySeconds: 5, periodSeconds: 10 }
          livenessProbe:  { tcpSocket: { port: https }, initialDelaySeconds: 15, periodSeconds: 20 }   # lines 138-141 rationale
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 65532
            capabilities: { drop: ["ALL"] }
            seccompProfile: { type: RuntimeDefault }
          resources:
            requests: { cpu: 25m, memory: 32Mi }
            limits: { memory: 64Mi }   # memory limit only -- repo convention
      volumes:
        - name: tls
          secret:
            secretName: homepage-tls                       # -> defectdojo-tls
```
Deltas (RESEARCH Pattern 2):
- `--target=defectdojo-django.defectdojo.svc.cluster.local:80`. A5 says to fall back to the ClusterIP if a DNS name is refused.
- `--target-status`: either `http://defectdojo-django.defectdojo.svc.cluster.local:80/nginx_health`, which is unverified (A2) and must be measured, or drop the flag and use the TCP-dial status. Do not copy the loopback value.
- Since it is standalone, a **pod-level** `securityContext` is now safe. Homepage line 148 kept it container-only because the homepage container's UID is unknown, and that reason does not apply here.
- Drop the homepage-specific keys: `serviceAccountName: homepage`, `automountServiceAccountToken: true` (set `false`), `enableServiceLinks`, and the `homepage` container.
- `replicas: 1` minimum. Two is optional.

**Format warning:** homepage is a **Kustomize** app (`homepage/templates/kustomization.yaml` plus `configMapGenerator`, lines 1-30). DefectDojo source 2 is a **Helm chart** (`Chart.yaml`), so do **not** copy `kustomization.yaml`. Every file under `defectdojo/templates/` is rendered by Helm. Homepage templates omit `metadata.namespace` and rely on the Argo destination namespace. Either convention works under Helm-with-Argo. The Nexus SealedSecret sets it explicitly, and that is required for SealedSecrets.

---

### `APP/.../platform/arc-systems/argocd-overrides.yaml` (CRD-owning operator, GitOps)

**Analog:** `APP/.../platform/cloudnative-pg/argocd-overrides.yaml` (lines 1-118)

**Header (lines 1-23):** "DELETING THIS FILE DELETES THE APPLICATION, BUT NOT THE OPERATOR". Adapt the rollback note to RESEARCH Pitfall 5's deletion ordering: remove `arc-runners` first, then the controller, because of the finalizers on the scale-set Role, RoleBinding and Secret.

**OCI source (lines 35-57):**
```yaml
    source: null
    sources:
      - repoURL: ghcr.io/cloudnative-pg/charts      # scheme-less OCI form, also listed with oci:// in AppProject
        chart: cloudnative-pg
        targetRevision: 0.29.0
        helm:
          releaseName: cnpg                         # FIXED for the life of the initiative
          valuesObject:
            crds:
              create: true
```
ARC deltas: `repoURL: ghcr.io/actions/actions-runner-controller-charts`, `chart: gha-runner-scale-set-controller`, `targetRevision: 0.14.2`, `releaseName: arc`. **`arc` is load-bearing:** the scale set's `controllerServiceAccount.name: arc-gha-rs-controller` is derived from it (RESEARCH Pattern 3). No `destination.namespace` override is needed, because the directory name equals the namespace `arc-systems`. The CNPG D4 exception at lines 26-30 is **not** copied.

The directory-per-namespace layout is what makes this true. A single `platform/arc/` directory could not hold the controller in `arc-systems` and the runners in `arc-runners` (a separate Application) without the CNPG-style D4 recorded exception on one of them; RESEARCH lines 304 and A4 give that reasoning.

**syncPolicy: prune OFF plus SSA (lines 86-118):**
```yaml
    syncPolicy:
      # PRUNE OFF, PERMANENTLY (D5) ... an absent `prune` key means off.
      automated:
        $patch: replace
        enabled: true
        selfHeal: true
      syncOptions:
        - CreateNamespace=true
        - ApplyOutOfSyncOnly=true
        # REQUIRED, NOT DEFENSIVE, AND MEASURED ... capped at 262144 bytes ...
        - ServerSideApply=true
      retry:
        limit: 5
        backoff: { duration: 10s, factor: 2, maxDuration: 3m }
```
Replace the byte figures in the SSA comment with the measured ARC 0.14.2 CRD sizes from RESEARCH Pattern 3: autoscalingrunnersets 612,248, autoscalinglisteners 309,369, ephemeralrunners 307,754 and ephemeralrunnersets 307,683 bytes.

---

### `APP/.../platform/arc-runners/argocd-overrides.yaml` (two-source: OCI chart + local SealedSecret)

**Analog (composite):**
- source 1 uses the OCI form from `cloudnative-pg/argocd-overrides.yaml` lines 46-57, with `chart: gha-runner-scale-set`, `targetRevision: 0.14.2` and a fixed `releaseName`;
- source 2 and syncPolicy use `nexus/argocd-overrides.yaml` lines 83-120: local path `application-sets/platform/arc-runners`, `prune: true` (no CRDs here), and no SSA.

The `valuesObject` has **no codebase analog**. Use RESEARCH Pattern 3 verbatim:
- `githubConfigUrl` at repository scope (D-07 amended);
- `githubConfigSecret: arc-github-pat`;
- `runnerScaleSetName`;
- `minRunners: 0` and `maxRunners: 2`;
- an explicit `controllerServiceAccount`, because the chart's `lookup` renders empty under Argo (Pitfall 5);
- `template.spec.hostAliases` to 10.40.3.65;
- runner image `ghcr.io/actions/actions-runner:2.337.0`, exact pin (R23);
- no `containerMode`.

Also comment the 30-day runner-update rule (Pitfall 6).

---

### `APP/application-sets/automation/argocd/templates/projects.yaml` (modify `platform` AppProject)

**Analog:** the same file's Phase 25 and Feature 7.1 amendments.
- `description:` at line 273 lists the members. Append `defectdojo, arc-systems, arc-runners`.
- sourceRepos at lines 276-286. Copy the CNPG "both spellings" block (lines 276-281) for `ghcr.io/actions/actions-runner-controller-charts` and `oci://ghcr.io/actions/actions-runner-controller-charts`. `https://github.com/OttawaCloudConsulting/security-platform` is **already present** (line 286), so do not duplicate it.
- destinations at lines 287-319. Add `defectdojo`, `arc-systems` and `arc-runners`, each with a one-line phase comment, in the form of lines 315-319:
  ```yaml
    # Phase 25 / NEXUS-05: the `nexus` Application (application-sets/platform/nexus/) keeps the
    # basename==namespace convention.
    - namespace: nexus
      server: https://kubernetes.default.svc
      name: in-cluster
  ```
- namespaceResourceWhitelist at lines 343-376. Add only `policy/PodDisruptionBudget` and `actions.github.com/AutoscalingRunnerSet` (RESEARCH Pitfall 5, verified against the live AppProject). Use the "enumerated from a fresh render, <date>" comment form (lines 364-370), naming the exact `helm template` commands and the kinds deliberately NOT added. At minimum that list holds `''/Pod`, which comes from the `defectdojo-unit-tests` helm test hook that Argo skips, and `''/PersistentVolumeClaim`.
- Leave `clusterResourceWhitelist` (lines 320-342) unchanged. CRD, ClusterRole and ClusterRoleBinding are already allowed, and the `''/Namespace` entry stays unscoped (lines 321-325).
- Validate with the render/inspect steps from the overlay CLAUDE.md (RESEARCH "Project Constraints").

---

### `SP/.github/workflows/security.yml` (callee workflow, event-driven)

**Analog:** the file itself. The two edit sites are:
- `defectdojo-import`, lines 1259-1270: comment block 1262-1267, `if:` at 1268, `runs-on: ubuntu-latest` at 1269;
- `defectdojo-cleanup`, lines 1645-1653: comment 1647-1650, `if:` 1651, `runs-on` 1652.

Pattern to follow is the existing `vars` fallback comment style. Lines 1262-1267 explain that "vars resolves to the CALLER repository in both Mode A and Mode B", and line 64 uses `${{ inputs.gate_mode || vars.GATE_MODE || 'report-only' }}`. Target shape (RESEARCH Pattern 4):
```yaml
    runs-on: ${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}
```
Add a comment on each job that covers:
- D-09 (unset means hosted);
- queue-not-fail when the runner is offline or stale (D-17, Pitfalls 6 and 8);
- that the job is never a required check.

Also extend the header settings list (lines 17-20), which enumerates the `DEFECTDOJO_*` variables, with `DEFECTDOJO_RUNS_ON`. The five scan-job `runs-on` lines (83, 250, 386, 913, 1105) and every `name:` stay untouched.

---

### `SP/.github/workflows/defectdojo-import-proof.yml` (comments only)

**Analog:** the file itself. **Three** comment passes are now wrong under D-10. RESEARCH named two of them.
- Lines 21-24: "the defectdojo-import and defectdojo-cleanup jobs are skipped". After D-10 the import job runs on ARC and prints the SKIP token line. Cleanup still never runs, because `pull_request` uses the default types.
- Lines 25-27: "`scans` additionally imports into the real instance". Never true, because there is no `secrets:` block (lines 74-77).
- Lines 35-37: "no secrets are passed to `scans` (the import is skipped anyway ...)". The parenthetical must be corrected the same way.
- Lines 75-77: "DEFECTDOJO_API_TOKEN stays unset here on purpose (see OPT-OUT REGRESSION PROOF above)". This stays true but must reference the corrected paragraph.

Add a comment on the `prove-import` `needs: scans` stall risk (RESEARCH Pattern 5) near lines 79-85. There is no functional change.

---

### `SP/scripts/check-workflow-uploads.sh` (offline gate: runs-on shape)

**Analog:** the same file.
- SIDE-CHANNEL-SHAPE, lines 412-450. Pattern: `SHAPE_IF = {jid: (fragments...)}` (lines 413-416), then one `fail("SIDE-CHANNEL-SHAPE", ...)` per violation. Add a sibling `SHAPE_RUNS_ON` asserting `body.get("runs-on") == "${{ vars.DEFECTDOJO_RUNS_ON || 'ubuntu-latest' }}"` for both side-channel jobs.
- JOB-SHAPE, lines 362-388. Add a `runs-on == "ubuntu-latest"` assertion for each of `SCAN_JOB_IDS` (line 112).
- **Measured:** the gate does **not** currently read `runs-on` anywhere (`grep -n "runs-on\|ubuntu-latest"` finds only comment line 31), so the `security.yml` change cannot break an existing check. The new assertion is purely additive.
- Update the header decision map (lines 23-40) with the new assertion and its D-09 reference.

---

### `SP/scripts/defectdojo-homelab-validate.sh` (live gate, request-response)

**Primary analog:** `SP/scripts/nexus-homelab-validate.sh` (1130 lines; read 1-66, 160-375 and 1066-1130).

**Header (lines 1-66).** Copy the structure:
- WHY THIS EXISTS: Synced+Healthy proves nothing;
- runtime;
- the "Never set the executable bit ... Invoke as: bash scripts/..." line;
- an example invocation;
- the "TWO DESIGN FORKS" (the gate requires `--url` and owns no background process; it is a sibling of the kind smoke, not a parameterised version of it);
- exit codes 0/1/2;
- credentials (the admin password is read from the cluster Secret into a variable, never taken from argv, never echoed, and `set -x` is never used; no host is written into the file).

**Argument validation with no defaults (lines 160-183):**
```bash
if [[ -z "$NEXUS_HOST" ]]; then
  usage_error "--url is required and was not supplied. There is no default Nexus URL and this script will not guess one."
fi
if [[ -z "$KUBE_CONTEXT" ]]; then
  usage_error "--context is required ... the current context is never assumed."
fi
if [[ -z "$SYNC_PASS" ]]; then
  usage_error "--sync-pass is required ... so it is never defaulted."
fi
```
For D-04, consider a second host argument, or derive both hosts from one flag. Both hostnames must be tested and neither may be hard-coded.

**Accounting core, copy verbatim (lines 185-261):** `OUT="$(mktemp -d)"`, `trap 'rm -rf "$OUT" || true' EXIT` (the only `|| true`), the `FAILURES=()`, `SKIPPED=()` and `CHECKS_PASSED=0` arrays, `require_success`, `pass`, `fail` and `print_summary`, whose three branches are FAILED, NOTHING RAN and ALL PASS:
```bash
  elif [ "$CHECKS_PASSED" -eq 0 ]; then
    echo "NOTHING RAN - 0 live check(s) executed; ${#SKIPPED[@]} sub-check(s) skipped (not passed). Nothing was proven."
    exit 0
```

**Preflight tiers (lines 263-282).** `curl` and `jq` are the hard tier. `kubectl` is the soft tier, and a missing kubectl produces a named SKIPPED entry.

**kubectl discipline (lines 288-297).** Every call pins `--context "$KUBE_CONTEXT"` on the same line, and every fallible command is captured with `|| rc=$?`.

**Argo hook-phase check (lines 312-366), `check_argocd_hook_phase`.** Reuse it for the initializer Job:
- expected `kind == Job`;
- `name == defectdojo-initializer` (staticName);
- `hookType == Sync`;
- `hookPhase == Succeeded`.

The DefectDojo delta: a `PreSync` entry for the `defectdojo` ServiceAccount is **expected**, because of the helm pre-install mapping (RESEARCH Pitfall 4). Select the Job entry by kind, not with `[0]`.

**Second-sync gated check (lines 1074-1130).** Keep `if [ "$SYNC_PASS" = "second" ]; then check_second_sync_idempotent; else SKIPPED+=("SECOND-SYNC-IDEMPOTENT: not evaluated on a --sync-pass first run; ...")`. The DefectDojo assertions come from RESEARCH Pitfall 4 falsifiers and the "Second-sync measurement" code example: new initializer UID, new SA UID, the log line "Admin user already exists", no migrations applied, and equal product/finding counts. The `grep -c ... || count=0` idiom (lines 1087-1088) is the sanctioned count default.

**Secondary analog for login/celery:** `SP/scripts/defectdojo-live-smoke.sh`, lines 660-752.
- The GET /login step, CSRF token `sed` extraction, `csrftoken` cookie check, POST with `password@FILE`, the 403 reason extraction, the 302 and not-`/login` check, and `/dashboard` 200 are at lines 670-724. Copy these structurally.
- `KIND-CELERY-PING` with the log-grep fallback is at lines 727-753. Retarget it with `--context "$KUBE_CONTEXT" --namespace defectdojo`.
- **Deltas that invert the analog:**
  - Drop `--resolve ... 127.0.0.1` and `--cacert "$OUT/ca.crt"`. The Let's Encrypt prod certificate is verified against the system store.
  - **Add `-H "Origin: https://${host}"`.** The analog sends only `Referer` (line 693), and RESEARCH Pitfall 1 shows that passes even without the fix.
  - Add the negative control: the same POST with `Origin: https://evil.example` must return 403.
  - The analog's comment at lines 666-669, "Do NOT add DD_CSRF_TRUSTED_ORIGINS", is **superseded by D-05**. Do not copy it.
  - Check IDs: `HOMELAB-TLS-{INFRA,HOME}`, `HOMELAB-LOGIN-ORIGIN-{INFRA,HOME}`, `HOMELAB-CSRF-FOREIGN-403`, `HOMELAB-CELERY-PING`, `ARGOCD-HOOK-PHASE`, `SECOND-SYNC-IDEMPOTENT` (RESEARCH Validation Architecture).
- The TLS check shape is `KIND-TLS-LOGIN-200` (roughly lines 600-658; the kind-only CA-from-Secret and port-forward parts at 604-627 do not apply): `%{http_code} %{ssl_verify_result}` plus a SAN check.

File mode is `100644` (security-platform convention). Run shellcheck on it.

---

### D-11 API assertion helper (live API assertions, CRUD)

**Primary analog:** `SP/scripts/defectdojo-import-proof.sh` (2930 lines; read 385-430, 905-920, 1034-1085, 1932-1955).
- `api_call` (lines 391-395): `curl -sS --cacert ... -o "$out" -w '%{http_code} %{ssl_verify_result}' "$@"`. For the live run, drop `--cacert`.
- `mint_token` (lines 397-425): JSON body built with `jq -n --rawfile` into a 0600 file, removed after use, and the token written to a 0600 file. This is also the pattern for creating `ci-importer` (RESEARCH "ci-importer creation"). P-USER, at lines 2156-2185, shows the create plus the read-back assertion `is_staff=true is_superuser=false`.
- `disposition_write` (lines 1043-1054): admin header by path `-H "@${HDR}"`, body `--data-binary "@${body}"`, `rm -f "$body"`, and abort on an unexpected code.
- Disposition bodies (lines 1938-1950):
  ```bash
  ra_expiry="$(python3 -c 'import datetime; print((datetime.datetime.now(datetime.timezone.utc).date() + datetime.timedelta(days=90)).strftime("%Y-%m-%dT00:00:00Z"))')"
  jq -n '{false_p: true, active: false, verified: false}' > "$dbody"      # PATCH /api/v2/findings/<id>/ -> 200
  jq -n '{out_of_scope: true, active: false}' > "$dbody"                  # PATCH -> 200
  jq -n --argjson owner "$admin_id" --argjson f "$ra_id" --arg exp "$ra_expiry" \
    '{name: ..., owner: $owner, accepted_findings: [$f], expiration_date: $exp, decision: "A", decision_details: ...}'  # POST /api/v2/risk_acceptance/ -> 201
  ```
- Read-side assertions (lines 1067-1085): a Python heredoc with env-only inputs and a `PID` label. The expected per-disposition tuples are at lines 1083-1085:
  ```python
  "fp":  {"false_p": True,  "out_of_scope": False, "risk_accepted": False, "active": False, "is_mitigated": True},
  "oos": {"false_p": False, "out_of_scope": True,  "risk_accepted": False, "active": False, "is_mitigated": True},
  "ra":  {"false_p": False, "out_of_scope": False, "risk_accepted": True,  "active": False, "is_mitigated": False},
  ```
- The finding field list used for snapshots is at line 770 (`FIELDS = ["id", "test", "title", "active", "verified", "duplicate", "duplicate_finding", ...]`). The dangling-duplicate check shape is at lines 1344-1349 (`outside = [f for f in dups if f["duplicate_finding"] not in ids]`).

**Secondary analog:** `SP/kubernetes/defectdojo/TRIAGE.md`, lines 70-110. The 0600 header file idiom (lines 74-79), the Under Review filter used **verbatim** (line 85), and the FP, OOS and RA curl bodies (lines 91-109).

**Step 5 follows the CONTEXT D-11 amendment, not RESEARCH line 61.** Assert:
- (a) `engagements/?product=<id>&name=ci/<branch>` count 0;
- (b) `ci/main` finding count and every disposition unchanged;
- (c) no product finding has `duplicate_finding` pointing at a deleted id.

Re-parenting is recorded as NOT exercised live. The dispositions use the operator's admin token (RESEARCH OQ4), never the `ci-importer` token.

---

### `SP/kubernetes/defectdojo/README.md` (docs)

**Analog:** the same file.
- Line 55: `| DDOJO-05 | Chart validated live via a private ArgoCD overlay | Planned (Phase 29) |` becomes `Complete (Phase 29)`, in the same form as rows 51-54.
- Line 401: "**Resync and upgrade behaviour are not yet validated.** ... validated in a later phase (DDOJO-05) ... the Job name changes on every render and the Job is deleted 60 seconds after completion." This is now stale. Replace it with the measured second-sync result and the `staticName` + Sync-hook recommendation.
- Optional (RESEARCH Pitfall 1): correct the CSRF "mechanism not established" caveat.

Because the overlay pins a SHA, any README change on security-platform `main` needs no pin bump. The README is not rendered.

---

### `DOC/scripts/check-adoption-guide.sh` (docs gate)

**Analog:** the same file, lines 262-298. Insertion point is the `DD_REQUIRED` list at lines 268-274:
```python
# Phase 28 D-17 / D-24 — the triage runbook link and the dedup bootstrap must stay documented.
DD_REQUIRED = [
    "DEFECTDOJO_URL", "DEFECTDOJO_API_TOKEN", "DEFECTDOJO_PRODUCT_TYPE",
    "DEFECTDOJO_INSECURE", "DEFECTDOJO_CA_CERT",
    "is_staff", "reachable", "closed", "scheduled-security.yml", "secrets:",
    "must be https://",
    "blob/main/kubernetes/defectdojo/TRIAGE.md", "defectdojo-configure.sh",
]
```
Add a `# Phase 29 D-09 — ...` comment line and `"DEFECTDOJO_RUNS_ON"`. You could also add a string that pins the queue-not-fail caveat, such as `"queue"`, but the section must then carry it. Run `bash scripts/check-adoption-guide.sh` after the guide edit.

---

### `DOC/docs/adoption-guide.md` (section 12)

**Analog:** the same section, lines 599-842.
- **Lines 627-634, Prerequisites, must be rewritten, not appended to.** They currently say reachability "is not covered by this guide. That decision belongs to a later phase of this project (Phase 29)."
- The settings block (lines 664-685) uses the `gh variable set NAME --body ... -R OWNER/REPO` line followed by a `## <explanation>` comment line. Add `gh variable set DEFECTDOJO_RUNS_ON --body <scale-set-name> -R OWNER/REPO`, with a comment that unset means `ubuntu-latest`.
- "What You Will See" (lines 776-795): add that the import queues rather than fails when the runner is offline or stale, that GitHub cancels a queued job after about 24h, and that merge is unaffected.
- "Caveats" (lines 796-804): add a bullet that each consumer repo needs its own repository-scoped runner scale set on a personal account (D-07 amended). Also add the fork-PR approval setting `all_external_contributors`, which must be raised before `DEFECTDOJO_RUNS_ON` is set.
- Keep the "None of these commands was executed against any pilot repository" honesty convention (line 681), or replace it with "executed on security-platform in Phase 29" where true.

---

### `DOC/docs/adr/adr027-*.md` and `DOC/docs/adr/adr028-*.md` (ADRs)

**Analog:** `DOC/docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md` (240 lines).
- Header (lines 1-14): `# ADR-0NN: <Title>`, then `**Status:** Accepted`, `**Date:**` and `**Addresses:** DDOJO-05 — ...`. Then a provenance paragraph: every measured value is quoted from a plan summary or the `evidence/` directory, and values from earlier phases are attributed to the ADR that measured them.
- `## Context` is bullets with bold lead phrases (line 15 onward).
- `## Decision` is numbered, each item with a bold lead sentence and the operator ruling quoted (lines 96-112, for example `replying **"approve-defaults"**`). ADR-028 decision 1 records the D-07/D-08 amendment (repo scope, the personal `User` account, the Administration RW PAT) as an operator ruling on 2026-09-26.
- `## Consequences` uses `**Improved:**` and `**Tradeoff — <name>.**` paragraphs (lines 150-200). Accepted risks (public repo on a self-hosted runner, no egress policy, the PAT) go here as explicit tradeoffs.
- `## What was NOT verified` is numbered, citing evidence files and prior ADR item numbers (lines 202-240). ADR-027 items include:
  - the chart ingress path, proven only on kind (D-01);
  - ADR-026 item 1 (dedup turned on over existing findings) not exercised (D-13);
  - re-parenting not exercised live (D-11 amended);
  - the cron-fired run, unless observed (D-12).
- ADR-026 adds a `### Measured evidence` sub-heading under Decision (line 139). Use it in ADR-027 for the second-sync, CSRF, netpol and D-11 results.
- **Address-hygiene rule:** ADR-022 lines 12-14 say "No homelab address, hostname, node name or kube context name appears here; 'the homelab kube context' stands in for the context name." Unless the operator waives this rule, keep the VIP 10.40.3.65, both FQDNs, node names and the context name **out of** ADR-027/028. They belong in the overlay README and the VLAN43 runbook. Describe the design instead: "an L2 VIP in the static VLAN pool", "the `.infra` and `.home` names". Flag this to the operator if D-17's wording seems to need literals.
- ADRs are append-only. Do not edit ADR-022 to ADR-026.

---

### `DOC/docs/adr/README.md` (index)

**Analog:** rows at lines 32-36. Row form:
```markdown
| [ADR-026](adr026-defectdojo-dedup-product-wide-and-triage-on-default-branch.md) | DefectDojo Dedup Is Product-Wide and Triage Happens on the Default Branch | 2026-09-26 | Accepted |
```
Append the ADR-027 and ADR-028 rows after line 36. Filenames use `adr0NN-kebab-title.md`.

---

### `DOC/.planning/REQUIREMENTS.md`

**Analog:** the same file. There are **two** edit sites:
- line 26, `- [ ] **DDOJO-05**: ...`, becomes `- [x]`, matching lines 22-25;
- line 56, `| DDOJO-05 | Phase 29 | Pending |`, becomes `Complete`, matching lines 51-55.

---

### `CLU/docs/upgrade/cilium-l2-vantage-host-runbook.md` (VLAN43 table)

**Analog:** the same file, lines 26-52.
```markdown
| 43 | `10.40.3.0/24` | `bond0.43` | `10.40.3.60–79` | `10.40.3.80–99` | six — see below |
**VLAN 43 VIP inventory (six):**
| Service | VIP | Pool |
|---|---|---|
| `argocd-server` | 10.40.3.61 | `vlan43-static` (pinned) |
```
Add `| \`defectdojo-ghostunnel\` (or the Service name) | 10.40.3.65 | \`vlan43-static\` (pinned) |`.

**The table is stale.** It is dated `Live VIPs (2026-09-08)` and says "six" in **two** places (line 29 and the bold heading). Its correction note at lines 43-45 says homepage holds no LB IP and `.77` is `authentik-outpost-proxy`. That contradicts `APP/.../homepage/templates/service.yaml` line 18, where homepage holds `.77` and the outpost moved to `.60`. The runbook itself says "Re-read the live VIP list before every capture" (lines 47-51, `kubectl get svc -A -o wide --field-selector spec.type=LoadBalancer`). The planner should have the executor refresh the inventory from that live read and then add `.65`. Updating only one row would leave the count and the `.77` entry wrong.

Commit through `bash .claude/scripts/gcommit`. The repo's markdownlint config applies.

---

## Shared Patterns

### Overlay Application conventions (all three new `argocd-overrides.yaml`)
**Source:** `APP/.../nexus/argocd-overrides.yaml` lines 1-34 and 88-120; `APP/.../cloudnative-pg/argocd-overrides.yaml` lines 86-118.
- `source: null` with `sources:`, `$patch: replace` under `automated`, restated `syncOptions` (CreateNamespace and ApplyOutOfSyncOnly), and `retry` under `syncPolicy`.
- No `spec.project`, and one override file per directory.
- Prune is on for workload apps. For CRD-owning apps (arc-systems), prune is off and SSA is on.
- Every non-obvious value carries a comment naming the symptom if it were omitted.

### SealedSecret at wave -1
**Source:** `APP/.../nexus/templates/sealedsecret-nexus-admin.yaml` lines 13-33.
**Apply to:** all four SealedSecrets. Quote `"-1"` (F-7). The wave orders the apply only and cannot wait for decryption. Seal with `CONTROLLER_NAMESPACE=sealed-secrets`.

### LB VIP + ghostunnel + DNS-01 exposure
**Source:** `APP/.../homepage/templates/{service,certificate,deployment}.yaml`.
**Apply to:** the DefectDojo Service, Certificate and ghostunnel Deployment.
- Service: quoted `vlan`/`IPautoAssign` labels and `externalTrafficPolicy: Cluster`, which admission-policies enforce.
- Certificate: wave -1, both SANs, `letsencrypt-dns01-prod`.
- Deployment: `--timed-reload=300s` and a whole-directory secret mount.

### Live-gate accounting (FAILURES / SKIPPED / CHECKS_PASSED, NOTHING RAN)
**Source:** `SP/scripts/nexus-homelab-validate.sh` lines 185-261.
**Apply to:** `defectdojo-homelab-validate.sh` and any scripted D-11 helper.
- `pass`/`fail` never swallow a result.
- The only `|| true` is in the cleanup trap.
- Every kubectl call pins `--context`.
- Every fallible command is captured with `|| rc=$?`.

### Secret handling in scripts
**Source:** `SP/scripts/defectdojo-import-proof.sh` lines 397-425 and 1043-1054; `SP/kubernetes/defectdojo/TRIAGE.md` lines 74-79.
**Apply to:** the validate script (admin password), the D-11 helper (admin token), `ci-importer` creation, and sealing the ARC PAT.
- Tokens go in 0600 header files passed with `-H @file`.
- Bodies go through `--data-binary @file`, and the files are removed after use.
- `password@FILE` in form posts.
- Never on argv, never echoed, never `set -x`.

### Evidence capture
**Source:** CONTEXT "Established Patterns" and RESEARCH Validation Architecture.
**Apply to:** every live checkpoint. Output goes to `.planning/phases/29-defectdojo-live-validation/evidence/29-<plan>-<what>.{json,txt,log}`, with run IDs from `gh run view` and values from `kubectl`/`gh api`, never recall.

### Scripts invoked with an explicit interpreter
**Apply to:** all new scripts. Use `bash scripts/<name>.sh`, never `chmod +x`, with git mode `100644` in security-platform.

### Commits in the overlay repos
Commit messages go through a file: `.claude/scripts/gcommit` when present, else `git commit -F`. Never use heredoc or multiline `-m`. Changes go by PR to `main`, and merging deploys.

## No Analog Found

| File | Role | Data Flow | Reason / What to use instead |
|---|---|---|---|
| Throwaway reachability pod manifest (runner image 2.337.0, run with and without `hostAliases`) | test fixture | request-response | No throwaway-pod fixture exists in either overlay repo or in security-platform. Use RESEARCH Validation Architecture row "Reachability" and Pitfalls 2-3: `getent hosts` plus `curl --resolve host:443:10.40.3.65`. Keep it in `evidence/` or apply it ad hoc with operator approval, since the overlay CLAUDE.md forbids workstation `kubectl apply` for deployments. Treat it as a measurement, not a deployment, and confirm with the operator. |
| ARC scale-set `valuesObject` (inside `arc-runners/argocd-overrides.yaml`) and the ARC controller values | config | n/a | `grep -rl "actions-runner\|arc-systems"` across `kubernetes_stack` returned nothing. Use RESEARCH Pattern 3 and Pitfall 5 (`controllerServiceAccount`, SSA, deletion ordering) verbatim. Only the Application wrapper has analogs (cloudnative-pg, nexus). |

## Metadata

**Analog search scope:**
- `APP/application-sets/platform/*` (nexus, homepage, cloudnative-pg, admission-policies);
- `APP/application-sets/automation/argocd/templates/projects.yaml`;
- `APP/scripts/`;
- `CLU/docs/upgrade/`;
- `SP/.github/workflows/`, `SP/scripts/`, `SP/kubernetes/defectdojo/`;
- `DOC/docs/adr/`, `DOC/docs/adoption-guide.md`, `DOC/scripts/check-adoption-guide.sh`, `DOC/.planning/REQUIREMENTS.md`.

**Files scanned:** about 30 (read or grepped).
**Pattern extraction date:** 2026-09-26.
