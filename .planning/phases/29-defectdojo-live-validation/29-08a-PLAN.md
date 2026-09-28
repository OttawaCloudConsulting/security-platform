---
phase: 29-defectdojo-live-validation
plan: "08a"
type: execute
wave: 4
depends_on: ["29-07"]
gap_closure: true
files_modified:
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/argocd-overrides.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/service.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/ghostunnel-deployment.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/Chart.yaml
  - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/README.md
  - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-argo-op-before.txt
  - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-render-assertions.txt
  - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-runtime-arg-check.txt
  - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-application-after.json
  - .planning/phases/29-defectdojo-live-validation/evidence/29-08a-live-after.txt
autonomous: false
requirements: [DDOJO-05]
user_setup: []

must_haves:
  truths:
    - "ghostunnel runs as a native sidecar (init container with restartPolicy Always) in the defectdojo-django pod. It is added only through overlay values (defectdojo.django.extraInitContainers and defectdojo.django.extraVolumes). The security-platform chart is unchanged and the pin stays c8027e6784ec631db128f45444c9a8092db9d0a1 (operator decision B1, 2026-09-28, which supersedes D-02)"
    - "The sidecar's --target is 127.0.0.1:8080 (nginx inside the same pod), so ghostunnel accepts it without --unsafe-target. --unsafe-target appears in no container arg or other non-comment YAML line"
    - "Before merge, the pinned ghostunnel image was run locally with the exact rendered args and stayed up. A negative control using the old --target=defectdojo-django.defectdojo.svc.cluster.local:80 failed with the known error, which proves the check can tell the two apart"
    - "After merge, the standalone Deployment defectdojo-ghostunnel is gone (pruned). The LB Service defectdojo-ghostunnel still holds 10.40.3.65 and selects only the django pod, and its EndpointSlice has one ready endpoint on port 8443"
    - "TLS on 10.40.3.65:443 verifies with the system trust store for both hostnames. HTTP on both hostnames returns 200 or 302. The postgres PVC is still Bound with the same UID, and no Secret was touched"
  artifacts:
    - path: "/Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/argocd-overrides.yaml"
      provides: "the sidecar in valuesObject.defectdojo.django.extraInitContainers, plus the tls volume in extraVolumes"
      contains: "restartPolicy: Always"
    - path: "/Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/service.yaml"
      provides: "the LB VIP Service, now selecting the django pod on numeric targetPort 8443"
      contains: "defectdojo.org/component: django"
    - path: ".planning/phases/29-defectdojo-live-validation/evidence/29-08a-runtime-arg-check.txt"
      provides: "the pre-merge runtime arg check: a positive run plus a negative control"
      contains: "--target must be unix:PATH or localhost:PORT"
    - path: ".planning/phases/29-defectdojo-live-validation/evidence/29-08a-live-after.txt"
      provides: "post-merge live proof: sidecar Ready, the old Deployment pruned, the EndpointSlice, the VIP, TLS and HTTP on both hosts"
      contains: "10.40.3.65"
  key_links:
    - from: "argocd-overrides.yaml extraInitContainers[tls].args --target"
      to: "nginx container port http 8080 in the same pod"
      via: "--target=127.0.0.1:8080"
      pattern: "--target=127.0.0.1:8080"
    - from: "templates/service.yaml spec.selector"
      to: "defectdojo-django pod template labels"
      via: "defectdojo.org/component: django + app.kubernetes.io/name: defectdojo + app.kubernetes.io/instance: defectdojo"
      pattern: "defectdojo.org/component: django"
    - from: "templates/service.yaml targetPort"
      to: "sidecar containerPort 8443"
      via: "numeric targetPort 8443"
      pattern: "targetPort: 8443"
---

<objective>
Fix the ghostunnel CrashLoopBackOff that blocks plan 29-08. ghostunnel moves from the standalone Deployment `defectdojo-ghostunnel` into the `defectdojo-django` pod as a Kubernetes native sidecar, where it targets nginx at `127.0.0.1:8080`. The change is made only through overlay values, per operator decision "B1: overlay values" (2026-09-28). Merge after operator approval, then verify it live.

Purpose: the live ghostunnel v1.11.3 refuses any `--target` that is not `unix:PATH` or `localhost:PORT` unless `--unsafe-target` is set. The operator rejected `--unsafe-target`. Plan 29-05's gates (`helm template` and `kubectl --dry-run=client`) could not catch this, because neither checks what container args mean. This plan adds a runtime arg check with a negative control before merge.

Output:
- one overlay PR in `occ-k8s-app-config`, merged with operator approval;
- five evidence files under `evidence/29-08a-*`;
- `29-08a-SUMMARY.md`, which records the decision for ADR-027 (plan 29-19).
</objective>

<execution_context>
@/Users/christian/git-repos/OCC-github/development_environment/security_solution/.claude/get-shit-done/workflows/execute-plan.md
@/Users/christian/git-repos/OCC-github/development_environment/security_solution/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/29-defectdojo-live-validation/29-CONTEXT.md
@.planning/phases/29-defectdojo-live-validation/29-05-SUMMARY.md
@.planning/phases/29-defectdojo-live-validation/29-07-SUMMARY.md
@.planning/phases/29-defectdojo-live-validation/29-08-PLAN.md

**Decision fidelity.** Locked decision D-02 says ghostunnel is "a standalone Deployment ... not a sidecar injected through upstream values". The operator decision **B1: overlay values** (2026-09-28, made after the live CrashLoopBackOff) supersedes D-02 for this phase. Record it verbatim in the SUMMARY `decisions:` as the ADR-027 input. The parts of D-02's intent that still hold are:
- "the public chart is untouched": values only, no security-platform change, and the pin stays `c8027e6784ec631db128f45444c9a8092db9d0a1`;
- D-01: LB VIP + ghostunnel + DNS-01 Certificate, with chart ingress off.

`--unsafe-target` was rejected by the operator and must not appear in any non-comment YAML line (comments and README prose may name it as the rejected option). Do not edit 29-CONTEXT.md or 29-RESEARCH.md (Pattern 2 is now stale); the SUMMARY lists them as stale.

**Measured facts (2026-09-28, live, context `admin@occ-new`)**
- Application `defectdojo` is Synced/Degraded, and its operation is Running (Argo retry).
- These are Running: celery-beat, celery-worker, django 2/2 (uwsgi + nginx), postgresql-0, valkey-0. The initializer Sync hook Succeeded.
- Certificate `defectdojo-tls` is Ready with both SANs. Always use `certificates.cert-manager.io`; the bare `certificate` resolves to an azuread CRD on this cluster.
- LB ingress is 10.40.3.65, and PVC `data-defectdojo-postgresql-0` is Bound.
- Deployment `defectdojo-ghostunnel` is in CrashLoopBackOff with `error: --target must be unix:PATH or localhost:PORT (unless --unsafe-target is set)`.
- The pre-fix Application snapshot is `evidence/29-08-first-sync-application.pre-ghostunnel-fix.json`: operation Running, retry #3 of 5, pinned to revisions `[c8027e6…, cc7fbc9…]`, and the ghostunnel Deployment task Failed with "exceeded its progress deadline".
- ghostunnel image digest (homepage and pre-fix evidence): `docker.io/ghostunnel/ghostunnel@sha256:51fa619294acf716e01efcb03ad00dc11229dc1f3829cba984c5b0a4f43f4faf`, tag `v1.11.3-distroless`.
- Cluster Kubernetes v1.34.1: an init container with `restartPolicy: Always` is a native sidecar, which can carry readiness and liveness probes.

<interfaces>
Upstream chart `defectdojo-1.9.53` (`repos/security-platform/kubernetes/defectdojo/charts/defectdojo-1.9.53.tgz`), `templates/django-deployment.yaml`, measured at planning time:
- Pod template labels (lines 40-43), with fullname and name both `defectdojo` because releaseName is `defectdojo`: `defectdojo.org/component: django`, `app.kubernetes.io/name: defectdojo`, `app.kubernetes.io/instance: defectdojo`. The chart's own Service `defectdojo-django` uses exactly these three as its selector. Celery pods share name and instance, so the component label is mandatory.
- `django.extraVolumes` is rendered into pod `volumes` (line 92).
- `django.extraInitContainers` is rendered with `range` into `initContainers` BEFORE the `dbMigrationChecker` include (lines 104-117). dbMigrationChecker is enabled by default.
- `django.extraVolumeMounts` is mounted into BOTH uwsgi (line 180) and nginx (line 272). DO NOT use it: it would hand the TLS private key to both containers.
- nginx container: named `nginx`, port name `http`, containerPort 8080 when `django.nginx.tls.enabled` is false (the default, line 285). uwsgi is `http-uwsgi` 8081. The sidecar's ports `https` 8443 and `status` 8082 do not collide.
- Pod securityContext comes from `securityContext.podSecurityContext` + `django.podSecurityContext`: `runAsNonRoot: true`, `fsGroup: 1001`. `automountServiceAccountToken` is `false` for django (pod level, from the chart).
- `django.strategy: {}` and `replicas: 1`, so the default RollingUpdate surges a new pod before the old one goes. Media is emptyDir, so no RWO PVC can deadlock the rollout.
- Wrapper `security-platform/kubernetes/defectdojo/values.yaml` at the pin: root key `defectdojo:`. It sets no `extraInitContainers` or `extraVolumes`, so there is no list-replace collision.

Overlay values path (the live Application's `operation.sync.sources[0].helm.valuesObject` confirms the root): `argocdOverrides.spec.sources[0].helm.valuesObject.defectdojo.django.extraInitContainers` and `...defectdojo.django.extraVolumes`. The existing sibling key there is `django.ingress.enabled: false`.

Container to carry over into the sidecar: the current `origin/main:application-sets/platform/defectdojo/templates/ghostunnel-deployment.yaml` container `tls`, with every flag comment. Homepage's proven in-pod form, `origin/main:application-sets/platform/homepage/templates/deployment.yaml` container `tls`, uses `--target=127.0.0.1:3000`.

Argo CD CLI form (overlay CLAUDE.md): `ARGOCD_AUTH_TOKEN=$(cat ~/.config/argocd/claude.token) argocd <cmd> --server argocd.infra.ottawacloudconsulting.com --grpc-web`. Never add `--insecure` and never use a password login. If the token has expired, STOP and report BLOCKED.
</interfaces>

**Hard operational rules. The executor must follow all of them.**
- **Shared overlay checkout.** `/Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config` is used by another active session. In the shared tree, the only allowed commands are `git fetch origin`, `git worktree add ...`, `git worktree remove <own path>` and read-only commands (`show`, `log`, `rev-parse`). Never checkout, switch, reset, pull, commit, `branch -f` or `worktree prune` there. `/private/tmp/occ-5.4-outage` is a foreign prunable worktree; leave it alone. All edits, gates and commits happen in `SCRATCH/wt-29-08a`.
- `SCRATCH` = `/private/tmp/claude-501/-Users-christian-git-repos-OCC-github-development-environment-security-solution/4a04faf8-acc3-4cd1-927d-a88ede360f9f/scratchpad`.
- **Helm and Docker hang on the desktop credsStore.** For every `helm` and `docker pull`, use `DOCKER_CONFIG=SCRATCH/dockercfg-empty` (a directory holding `config.json` with `{}`). Also pass `--registry-config SCRATCH/helm-registry.json` to helm.
- **Never** touch PVC `data-defectdojo-postgresql-0`, any Secret or SealedSecret, or `DD_CREDENTIAL_AES_256_KEY`. Do not read initializer logs in this plan. The first-run log with the redacted JIRA webhook secret is already committed (a40c5a8).
- GitGuardian incident 37678807 (SealedSecret `DD_SECRET_KEY` ciphertext) is a known false positive, and `main` is unprotected. If the check fails on this PR for that finding, note it and do not block on it.
- Docs repo: about 360 unrelated dirty paths. Stage explicit paths only. Never `chmod +x`; run scripts with `bash`.
- Commit trailers (both repos): `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01FKhf6VmaBFhZGJK9WcLawZ`. The PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`, a blank line, then `https://claude.ai/code/session_01FKhf6VmaBFhZGJK9WcLawZ`.

**Anti-slop.** On any unexpected output (gate failure, render mismatch, image pull hang, positive run exiting, negative control passing, sync not starting, sidecar not Ready, TLS verify error), STOP. Report the raw output, a theory and a proposal, and wait.
</context>

<tasks>

<task type="auto">
  <name>Task 1: In an isolated worktree, move ghostunnel into the django pod via overlay values, run every gate plus the runtime arg check, then push and open the PR</name>
  <files>/Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/argocd-overrides.yaml, /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/service.yaml, /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/ghostunnel-deployment.yaml, /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/Chart.yaml, /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/README.md, .planning/phases/29-defectdojo-live-validation/evidence/29-08a-argo-op-before.txt, .planning/phases/29-defectdojo-live-validation/evidence/29-08a-render-assertions.txt, .planning/phases/29-defectdojo-live-validation/evidence/29-08a-runtime-arg-check.txt</files>
  <read_first>
    - `/Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/CLAUDE.md` (validation list, gcommit, Argo CLI)
    - `origin/main:application-sets/platform/defectdojo/argocd-overrides.yaml`, `templates/ghostunnel-deployment.yaml`, `templates/service.yaml`, `Chart.yaml` and `README.md`. Read them in the worktree after it is created.
    - `origin/main:application-sets/platform/homepage/templates/deployment.yaml`, the `tls` container
    - `.planning/phases/29-defectdojo-live-validation/29-05-SUMMARY.md`, "Gate results", and `29-07-SUMMARY.md`, "Task results" (the exact gate forms that passed)
    - `.planning/phases/29-defectdojo-live-validation/evidence/29-08-first-sync-application.pre-ghostunnel-fix.json` (operation shape)
  </read_first>
  <action>
**Step A: worktree.** Run `git -C <shared overlay> fetch origin`. Then `git -C <shared overlay> worktree add SCRATCH/wt-29-08a -b fix/defectdojo-ghostunnel-native-sidecar origin/main`. All work below happens in `SCRATCH/wt-29-08a`. Confirm with `git -C SCRATCH/wt-29-08a rev-parse HEAD` that it equals `origin/main`, and record that SHA.

**Step B: Argo operation state before the change.** Read-only: `kubectl --context admin@occ-new -n argocd get applications.argoproj.io defectdojo -o json | jq '{sync:.status.sync, health:.status.health.status, op:.status.operationState|{phase,message,retryCount,startedAt,finishedAt,revisions:.operation.sync.revisions}}'`. Save it to `evidence/29-08a-argo-op-before.txt` with a UTC timestamp header. Also append `kubectl -n defectdojo get pvc data-defectdojo-postgresql-0 -o jsonpath='{.metadata.uid} {.status.phase}'`; this is the PVC UID baseline. If `operationState.phase` is `Running`, Task 2 must offer the terminate-op option (see there).

**Step C: overlay edits (per operator decision B1).**
1. `argocd-overrides.yaml`: under `valuesObject.defectdojo.django`, next to `ingress`, add:
   - `extraVolumes`: one entry, `name: tls`, `secret.secretName: defectdojo-tls`. Leave `defaultMode` unset (0644), because the pod's `fsGroup: 1001` does not include uid 65532.
   - `extraInitContainers`: one entry, the `tls` container carried over from the deleted Deployment with every flag comment. Its fields:
     - `name: tls` and `restartPolicy: Always`, with a comment explaining the native sidecar on Kubernetes 1.29+ (cluster v1.34.1). It starts before dbMigrationChecker, runs for the pod's lifetime, and is stopped after the main containers.
     - `image: docker.io/ghostunnel/ghostunnel:v1.11.3-distroless`, `imagePullPolicy: IfNotPresent`.
     - args, in order: `server`, `--listen=:8443`, `--target=127.0.0.1:8080`, `--cert=/etc/ghostunnel/tls/tls.crt`, `--key=/etc/ghostunnel/tls/tls.key`, `--disable-authentication`, `--timed-reload=300s`, `--status=http://0.0.0.0:8082`. The target comment says it is nginx (port `http` 8080, `django.nginx.tls.enabled` false) inside the same pod. It also says that ghostunnel v1.11.3 rejects any target other than `unix:PATH` or `localhost:PORT`, measured live 2026-09-28, and that `--unsafe-target` was rejected by the operator. Use `127.0.0.1`, the homepage-proven form.
     - Keep the no-`--target-status` comment (RESEARCH A2 unmeasured).
     - ports `https` 8443 and `status` 8082.
     - `volumeMounts`: `tls` at `/etc/ghostunnel/tls`, `readOnly`, whole directory, never subPath (keep the comment).
     - readinessProbe httpGet `/_status` on `status`, livenessProbe tcpSocket on `https`, with the same delays and comment.
     - The full container securityContext from the deleted file.
     - resources: requests 25m / 32Mi, limit memory 64Mi.
   - A block comment above `extraInitContainers`. It says: why this is a sidecar (B1, which supersedes D-02); that the list is rendered before dbMigrationChecker; and never to use `django.extraVolumeMounts` for the TLS key, because it mounts into uwsgi and nginx.
   - Update stale prose: the header comment, the SOURCE 2 comment (source 2 now carries the SealedSecrets, the Certificate and the LB Service; no Deployment), and the releaseName comment that names ghostunnel's target (now the django pod, not the `defectdojo-django` Service).
2. `templates/service.yaml`:
   - Keep `metadata.name: defectdojo-ghostunnel`. It is referenced by plans 29-08, 29-09 and 29-11, and renaming it would release and re-allocate the VIP.
   - Keep every label, the annotation, `type` and `externalTrafficPolicy`.
   - Change `spec.selector` to exactly the three django pod labels.
   - Change the port's `targetPort` to the number `8443`. The comment says numeric is deliberate: resolving a named port against a port declared on an init container is version-dependent, and no dry-run can check it.
   - Rewrite the "NEVER select the django pods" comment, whose reason has inverted. The Service now selects the django pod but targets ghostunnel's 8443, never nginx's 8080 or uwsgi. It must keep all three labels, because celery pods share name and instance.
   - Update the header comment to match.
3. Delete `templates/ghostunnel-deployment.yaml` with `git rm`.
4. `Chart.yaml`: bump `version` to `0.1.1`. The description now names three credential SealedSecrets, the Certificate and the LB Service; ghostunnel runs as a sidecar in the chart's django pod via values.
5. `README.md`:
   - Update the exposure row to: LB Service `defectdojo-ghostunnel` → django pod ghostunnel native sidecar `:8443` → nginx `127.0.0.1:8080`.
   - Replace the "standalone Deployment, not a sidecar" discretion bullet with the B1 decision, dated 2026-09-28. Give the reason (v1.11.3 target restriction; `--unsafe-target` rejected) and the lesson (29-05's render and client dry-run gates do not validate container arg semantics).
   - Add a fifth `## Rollback` point: reverting this change restores the crash-looping standalone Deployment, so it is not a working rollback target. A rollback of the exposure layer needs a forward fix. The sidecar's lifecycle is tied to the django pod, so a TLS change restarts django.

**Step D: gates.** Run all of them from the worktree root, and append each command and its result to `evidence/29-08a-render-assertions.txt`. Every gate from 29-05/29-07 re-runs:
1. `python3 docs/argocd/conformance/c1.py` and `python3 docs/argocd/conformance/check_appconfig.py --base origin/main` must PASS.
2. `yamllint application-sets/platform/defectdojo`, scoped. Repo-wide `yamllint .` has 51 known pre-existing errors on `origin/main`; do not use it as a gate.
3. Source-2 render: `helm template defectdojo-local application-sets/platform/defectdojo`. Assert its kinds are exactly Service, Certificate and three SealedSecret, and zero Deployment.
4. Source-1 render with the exact valuesObject:
   - First confirm `git -C repos/security-platform diff --stat c8027e6784ec631db128f45444c9a8092db9d0a1 HEAD -- kubernetes/defectdojo` prints nothing, and that `charts/defectdojo-1.9.53.tgz` exists. Otherwise use a `git archive` of the pin in SCRATCH plus `helm dependency build`, as 29-05 did.
   - Extract `.argocdOverrides.spec.sources[0].helm.valuesObject` with yq to `SCRATCH/src1-values-08a.yaml`.
   - Run `helm template defectdojo <chart> --namespace defectdojo -f SCRATCH/src1-values-08a.yaml > SCRATCH/src1-render-08a.yaml`.
   - Assert with yq on the Deployment `defectdojo-django`:
     - (a) `initContainers[0].name=="tls"` and `restartPolicy=="Always"`, and `initContainers[1]` is the dbMigrationChecker;
     - (b) the `tls` args list equals the eight args above, and no element contains `unsafe`;
     - (c) pod `volumes` includes `tls` with secret `defectdojo-tls`;
     - (d) neither the `uwsgi` nor the `nginx` container has a volumeMount named `tls`;
     - (e) the nginx `http` containerPort is 8080;
     - (f) the pod template labels contain all three Service selector labels.
   - Also assert that, of all Deployments in the source-1 render, exactly ONE pod template matches the Service selector from `templates/service.yaml`.
   - Assert that the Service `defectdojo-django` and every 29-05 source-1 assertion (b)-(e) still hold: DD_ALLOWED_HOSTS, DD_SITE_URL, CSRF origins, cookie flags `"True"`, and the `defectdojo-initializer` Sync hook.
5. `kubectl --context admin@occ-new apply --dry-run=client -f` on each of the five remaining `templates/*.yaml`.
6. Server-side admission check. Extract the django Deployment and the new Service to SCRATCH files, then run `kubectl --context admin@occ-new -n defectdojo apply --dry-run=server -f` on each. This runs the live admission policies (namespace-boundary, L2 etp), which client dry-run skips. Record in the evidence that neither dry-run validates container arg semantics.
7. gitleaks, both forms: scoped `gitleaks detect --source application-sets --no-git --redact`, and the CI form on a `git archive HEAD` extract after Step F's commit. Both must find 0 leaks with the existing `.gitleaksignore`.

**Step E: runtime arg check. Record everything in `evidence/29-08a-runtime-arg-check.txt`.**
- Pull the image by digest: `DOCKER_CONFIG=SCRATCH/dockercfg-empty docker pull docker.io/ghostunnel/ghostunnel@sha256:51fa619294acf716e01efcb03ad00dc11229dc1f3829cba984c5b0a4f43f4faf`. Record `docker image inspect` RepoDigests.
- Generate a throwaway self-signed ECDSA cert and key into `SCRATCH/gt-tls/` with `openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 1 -subj /CN=localhost`. Files are `tls.crt` and `tls.key`, readable by uid 65532: `chmod 0644` on the files only, never `+x`.
- Positive run. Take the args verbatim from the source-1 render with yq; never retype them. Run `docker run -d --name gt-08a-pos --user 65532 -v SCRATCH/gt-tls:/etc/ghostunnel/tls:ro -p 127.0.0.1:18082:8082 <image@digest> <args...>`. After 10 seconds:
  - assert `docker inspect -f '{{.State.Running}}' gt-08a-pos` is `true`;
  - capture `docker logs gt-08a-pos`, which must not contain `--target must be`;
  - `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18082/_status` must return an HTTP code. 503 is expected, because no nginx is listening in the test.
- Negative control: the same run, with only `--target` replaced by `--target=defectdojo-django.defectdojo.svc.cluster.local:80`, in the foreground with `--rm`. It must exit non-zero, and its output must contain `--target must be unix:PATH or localhost:PORT`.
- Remove the containers and `SCRATCH/gt-tls`. If the positive run exits, or the negative control does not fail, STOP.

**Step F: commit, push, PR.** In the worktree:
- stage exactly the five changed paths;
- commit with `bash .claude/scripts/gcommit` (or plain `git commit` if absent). Message: `fix(defectdojo): run ghostunnel as a native sidecar in the django pod (Phase 29 / DDOJO-05)`, with a body giving the CrashLoop error, B1 and the gate summary, plus both trailers;
- `git push -u origin fix/defectdojo-ghostunnel-native-sidecar`;
- open the PR with `gh pr create --base main`. Its body gives: the root cause (raw error string); the B1 decision; the diff summary; the gates and the runtime check with its negative control; the expected live effects (the django pod rolls once with a surge pod; the standalone Deployment is pruned by `automated.prune: true`; the VIP is unchanged; brief HTTPS unavailability is possible while the Service selector moves, and the service is already down); the GitGuardian 37678807 false-positive note; the rollback caveat; the Claude Code footer.
- Record the PR number and head SHA, and wait for the `conformance` check result.

Do not merge. Task 2 is the operator gate.
  </action>
  <verify>
    <automated>W=/private/tmp/claude-501/-Users-christian-git-repos-OCC-github-development-environment-security-solution/4a04faf8-acc3-4cd1-927d-a88ede360f9f/scratchpad/wt-29-08a && cd "$W" && python3 docs/argocd/conformance/c1.py && python3 docs/argocd/conformance/check_appconfig.py --base origin/main && yamllint application-sets/platform/defectdojo && test ! -e application-sets/platform/defectdojo/templates/ghostunnel-deployment.yaml && yq -e '[.argocdOverrides.spec.sources[0].helm.valuesObject.defectdojo.django.extraInitContainers[] | select(.name=="tls" and .restartPolicy=="Always" and (.args|index("--target=127.0.0.1:8080"))!=null)] | length==1' application-sets/platform/defectdojo/argocd-overrides.yaml >/dev/null && yq -e '.spec.selector."defectdojo.org/component"=="django" and .spec.ports[0].targetPort==8443' application-sets/platform/defectdojo/templates/service.yaml >/dev/null && ! grep -rhv --include='*.yaml' '^\s*#' application-sets/platform/defectdojo | grep -q -- '--unsafe-target' && cd /Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/29-defectdojo-live-validation/evidence && grep -q 'target must be unix:PATH or localhost:PORT' 29-08a-runtime-arg-check.txt && test -s 29-08a-render-assertions.txt && test -s 29-08a-argo-op-before.txt</automated>
  </verify>
  <acceptance_criteria>
    - The shared overlay tree's HEAD, branch and working tree are unchanged by this task. `git -C <shared> worktree list` shows `wt-29-08a`, and the shared tree's `git status --porcelain` output matches what it was before the task
    - The source-1 render shows `tls` as initContainers[0] with `restartPolicy: Always` and the eight args, followed by dbMigrationChecker. uwsgi and nginx have no `tls` mount. Exactly one Deployment pod template matches the Service selector
    - The source-2 render has zero Deployments. Service `defectdojo-ghostunnel` keeps the VIP annotation and labels, with numeric targetPort 8443
    - The runtime evidence shows the positive run still Running after 10s with a `/_status` HTTP code, and the negative control exiting non-zero with the exact error string
    - Server-side dry-run on the django Deployment and the Service succeeds. c1, check_appconfig, scoped yamllint and both gitleaks forms pass
    - No non-comment YAML line in the directory contains `--unsafe-target`, and the security-platform pin is still `c8027e6784ec631db128f45444c9a8092db9d0a1`
    - PR opened. Its number and head SHA are recorded, along with the `conformance` result
  </acceptance_criteria>
  <done>A gate-clean, runtime-checked overlay PR moving ghostunnel into the django pod is open and awaiting operator approval.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Operator approves merging the sidecar PR (and, if needed, terminating the stale Argo operation)</name>
  <files>none (operator gate; no file changes)</files>
  <action>Present to the operator: the PR URL, head SHA and diff stat; the Task 1 gate table; the runtime arg check (positive and negative); the Argo operation state from `evidence/29-08a-argo-op-before.txt`; and the expected live effects and rollback caveat. Then STOP until the operator replies. Record the reply verbatim for the SUMMARY. Do not merge in this task. Merge happens in Task 3, pinned to the head SHA shown here. If the PR head changes after this presentation, re-present it and ask again.</action>
  <verify>
    <automated>gh pr view "$PR" -R OttawaCloudConsulting/occ-k8s-app-config --json headRefOid,state -q 'select(.state=="OPEN") | .headRefOid' | grep -Eq '^[0-9a-f]{40}$'</automated>
  </verify>
  <done>The operator replied "approve" or "approve terminate-op", and the reply and the approved head SHA are recorded.</done>
  <what-built>Overlay PR `fix/defectdojo-ghostunnel-native-sidecar` (number and head SHA from Task 1). It moves ghostunnel into the django pod as a native sidecar through overlay values only, re-points the LB Service `defectdojo-ghostunnel` at the django pod on port 8443, and deletes the standalone Deployment. All gates pass, and the runtime arg check has both its positive run and its negative control.</what-built>
  <how-to-verify>
    1. Review the PR diff: five files under `application-sets/platform/defectdojo/`, no `--unsafe-target`, and the pin unchanged at `c8027e6784ec631db128f45444c9a8092db9d0a1`.
    2. Read `evidence/29-08a-runtime-arg-check.txt`: the positive run was still up after 10s, and the negative control failed with `--target must be unix:PATH or localhost:PORT`.
    3. Expected live effects: the django pod rolls once (a surge pod first); the initializer Sync hook re-runs under BeforeHookCreation; the standalone Deployment is pruned; the VIP stays 10.40.3.65; the PVC and Secrets are untouched.
    4. Argo operation state from `evidence/29-08a-argo-op-before.txt`. If `operationState.phase` is still `Running` (the old retry loop pinned to `[c8027e6, cc7fbc9]`), an automated sync of the new commit cannot start until it ends. You may authorise `argocd app terminate-op defectdojo` (token CLI form, `--grpc-web`), to be run only if, after merge, the stale operation is still Running on the old revisions.
    5. GitGuardian: if it flags incident 37678807 (SealedSecret ciphertext), it is the known false positive, and `main` is unprotected.
  </how-to-verify>
  <resume-signal>Type "approve" to merge only, or "approve terminate-op" to merge and allow terminating a stale Running operation. Otherwise, describe the changes needed.</resume-signal>
</task>

<task type="auto">
  <name>Task 3: Merge pinned to the approved head, verify the sidecar live on both hostnames, confirm the old Deployment was pruned, and clean up the worktree</name>
  <files>.planning/phases/29-defectdojo-live-validation/evidence/29-08a-application-after.json, .planning/phases/29-defectdojo-live-validation/evidence/29-08a-live-after.txt</files>
  <read_first>
    - `.planning/phases/29-defectdojo-live-validation/evidence/29-08a-argo-op-before.txt`
    - `.planning/phases/29-defectdojo-live-validation/29-07-SUMMARY.md`, Task 3 row (merge and post-merge poll form, worktree cleanup deviation 3)
  </read_first>
  <action>
**Merge.** Check again that the PR head equals the approved SHA and that `conformance` is SUCCESS. Then run `gh pr merge <n> --merge --match-head-commit <approved sha>`. Record the merge commit SHA as `MERGE_SHA`.

**Sync.** Poll `kubectl --context admin@occ-new -n argocd get applications.argoproj.io defectdojo -o json` every 30s for up to 25 minutes.
- If `operationState.phase` is `Running` and `operation.sync.revisions[1]` is still `cc7fbc958c7928d1d640c2f9ec20a44b78a7fcfd` more than 5 minutes after the merge:
  - with the operator's reply "approve terminate-op": run `ARGOCD_AUTH_TOKEN=$(cat ~/.config/argocd/claude.token) argocd app terminate-op defectdojo --server argocd.infra.ottawacloudconsulting.com --grpc-web` once, and record it;
  - without that reply: STOP and report.
- A refresh (`argocd app get defectdojo --refresh` in the same CLI form) is allowed. A manual `argocd app sync` is NOT; if automated sync does not pick up the new revision, STOP and report.

Done when `.status.sync.status=="Synced"`, `.status.health.status=="Healthy"`, `.status.operationState.phase=="Succeeded"` and `.status.sync.revisions[1]` equals `MERGE_SHA`. Synced alone could describe the old operation. Save the JSON to `evidence/29-08a-application-after.json`.

Expected behaviour, so it does not trigger a STOP:
- during the rollout, the new pod's `tls` sidecar is not Ready until nginx is up;
- the EndpointSlice may briefly list the old pod on 8443.

Also save to the evidence, as expected facts:
- `revisions[0]` still equals the pin;
- the initializer Sync hook appears in `syncResult` again (a later run, not the first).

If the Application is not Healthy, STOP with `.status.resources[] | select(.health.status!="Healthy")` and the namespace events.

**Live proof.** Write `evidence/29-08a-live-after.txt` with a UTC timestamp and these sections:
1. `kubectl -n defectdojo get deploy,pods -o wide`. `kubectl -n defectdojo get deploy defectdojo-ghostunnel` must return NotFound (pruned by `automated.prune: true`; `preserveResourcesOnDeletion` is generator-level and applies only to deleting the Application). No pod named `defectdojo-ghostunnel-*` may remain.
2. From the django pod JSON:
   - `.status.initContainerStatuses[] | select(.name=="tls")` has `ready==true`, `started==true` and `restartCount==0`;
   - `.spec.initContainers[] | select(.name=="tls") | .restartPolicy=="Always"`;
   - every `.status.containerStatuses[].ready` is true;
   - the dbMigrationChecker status is terminated with reason Completed.
   Do not rely on the READY column string.
3. `kubectl -n defectdojo get endpointslices -l kubernetes.io/service-name=defectdojo-ghostunnel -o json`: exactly one endpoint, `conditions.ready==true`, its address equal to the django pod IP, and port 8443.
4. `kubectl -n defectdojo get svc defectdojo-ghostunnel -o jsonpath='{.status.loadBalancer.ingress[*].ip}'` equals `10.40.3.65`.
5. `kubectl -n defectdojo get certificates.cert-manager.io defectdojo-tls` Ready is True.
6. PVC `data-defectdojo-postgresql-0`: phase Bound, UID equal to the Task 1 baseline.
7. For each of `defectdojo.infra.ottawacloudconsulting.com` and `defectdojo.home.ottawacloudconsulting.com`:
   - run `openssl s_client -connect 10.40.3.65:443 -servername <host> </dev/null 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName` (both SANs present);
   - run `curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://<host>/` with the system trust store and no `-k`. It must be 200 or 302, with ssl_verify_result 0;
   - record `curl -sS -o /dev/null -w '%{http_code}' https://<host>/login`.
   Leave the full `defectdojo-homelab-validate.sh` pass to plan 29-08 Task 2.
8. `kubectl -n defectdojo logs deploy/defectdojo-django -c tls --tail=20`, which must contain no `--target must be` and no TLS load error.

Apply the evidence-hygiene grep: `grep -Ec 'github_pat_|ghp_|Authorization: Token [A-Za-z0-9]|JIRA Webhook Secret: [0-9a-f-]{36}'` returns 0 on both files.

**Cleanup.**
- `git -C <shared overlay> worktree remove SCRATCH/wt-29-08a`. It must be clean; never `--force` without reporting.
- `git -C <shared overlay> fetch origin`, then confirm `origin/main` equals `MERGE_SHA` or descends from it.
- Do not checkout, pull or prune in the shared tree.
- Delete the remote branch only if the operator asks.

**Docs commit.** In the docs repo, stage exactly the five `evidence/29-08a-*` files plus `29-08a-SUMMARY.md`, and the ROADMAP and STATE updates if the executor workflow makes them. Commit with a `docs(29-08a): ...` message and both trailers.

The SUMMARY `decisions:` must include:
- the verbatim operator decision "B1: overlay values": sidecar over `--unsafe-target`, which supersedes D-02;
- the merge SHA;
- whether terminate-op was used;
- the lesson for ADR-027: 29-05's `helm template` and `kubectl --dry-run` gates validate structure and admission, not container arg semantics, so the runtime arg check with a negative control is now the pattern.

The SUMMARY also lists 29-CONTEXT D-02 and 29-RESEARCH Pattern 2 as stale, but does not edit them.
  </action>
  <verify>
    <automated>cd /Users/christian/git-repos/OCC-github/development_environment/security_solution/.planning/phases/29-defectdojo-live-validation/evidence && jq -e '.status.sync.status=="Synced" and .status.health.status=="Healthy" and .status.operationState.phase=="Succeeded" and .status.sync.revisions[0]=="c8027e6784ec631db128f45444c9a8092db9d0a1" and .status.sync.revisions[1]!="cc7fbc958c7928d1d640c2f9ec20a44b78a7fcfd" and ([.status.resources[] | select(.kind=="Deployment" and .name=="defectdojo-ghostunnel")] | length)==0' 29-08a-application-after.json >/dev/null && grep -q '10.40.3.65' 29-08a-live-after.txt && grep -qi 'NotFound' 29-08a-live-after.txt && test "$(grep -Ec 'github_pat_|ghp_|Authorization: Token [A-Za-z0-9]|JIRA Webhook Secret: [0-9a-f-]{36}' 29-08a-live-after.txt 29-08a-application-after.json | awk -F: '{s+=$NF} END {print s}')" = "0" && ! git -C /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config worktree list | grep -q wt-29-08a</automated>
  </verify>
  <acceptance_criteria>
    - The PR was merged with `--match-head-commit` equal to the operator-approved head SHA, and the merge SHA is recorded
    - The Application is Synced, Healthy and operation Succeeded. `revisions[0]` is the unchanged pin, and `revisions[1]` is the new overlay revision, not cc7fbc9
    - The standalone Deployment `defectdojo-ghostunnel` is NotFound and absent from `.status.resources`. The Service `defectdojo-ghostunnel` still holds 10.40.3.65
    - The django pod's `tls` init container has `restartPolicy: Always`, `ready: true` and `restartCount: 0`, and the uwsgi and nginx containers are ready
    - The EndpointSlice for `defectdojo-ghostunnel` has exactly one ready endpoint: the django pod IP, port 8443
    - Both hostnames: the certificate carries both SANs, curl with the system trust store gives `ssl_verify_result` 0, and `/` returns 200 or 302
    - The PVC UID and phase match the Task 1 baseline. terminate-op was run only if the operator replied "approve terminate-op" and the stale operation blocked
    - The scratchpad worktree is removed. The shared overlay tree received only `fetch`, and its HEAD and branch are unchanged
  </acceptance_criteria>
  <done>ghostunnel runs as a Ready native sidecar in the django pod, and HTTPS works on both hostnames through 10.40.3.65. The broken standalone Deployment is pruned. Plan 29-08 can resume.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LAN client → VIP :443 → ghostunnel sidecar → nginx 127.0.0.1:8080 | TLS terminates inside the django pod. Plaintext now stays on the pod loopback instead of crossing the cluster network |
| overlay git → cluster (Argo automated sync, prune) | A merged commit changes live workloads and prunes resources |
| workstation → kube API / Argo API | Read-only reads, server-side dry-run, and one optional operator-authorised terminate-op |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-29-08a-01 | Elevation of Privilege | ghostunnel `--unsafe-target` | mitigate | The operator rejected it. The target is loopback `127.0.0.1:8080`. The Task 1 verify greps that no non-comment line contains `--unsafe-target`, and the runtime negative control proves that ghostunnel's target restriction is active |
| T-29-08a-02 | Information Disclosure | TLS private key reaching uwsgi and nginx | mitigate | The key volume goes only through `django.extraVolumes`, mounted only in the sidecar. `django.extraVolumeMounts` is forbidden. The render assertion (d) checks that uwsgi and nginx have no `tls` mount |
| T-29-08a-03 | Denial of Service | Service selecting the wrong pods (celery) or a non-listening port | mitigate | The selector has all three django labels. The render gate checks that exactly one Deployment matches. The numeric targetPort 8443 is verified live through the EndpointSlice |
| T-29-08a-04 | Tampering | prune deleting more than the standalone Deployment | mitigate | The PR diff removes only `templates/ghostunnel-deployment.yaml`. After sync, the PVC UID is compared with the baseline, and the Secrets and SealedSecrets are not in the diff |
| T-29-13 | Denial of Service | Postgres data loss | mitigate | The PVC, Secrets and `DD_CREDENTIAL_AES_256_KEY` are never touched. README Rollback point 2 still applies. The PVC UID is checked before and after |
| T-29-08a-05 | Tampering | shared overlay checkout corrupted by concurrent sessions | mitigate | Work happens only in the scratchpad worktree. The shared tree gets only `fetch` and `worktree add`/`remove` of its own path, and its porcelain status and HEAD are compared before and after |
| T-29-08a-06 | Spoofing | operator approval bypassed by a late push | mitigate | `gh pr merge --match-head-commit <approved sha>` |
| T-29-03 | Information Disclosure | JIRA webhook secret / tokens in evidence | mitigate | This plan reads no initializer log. The evidence-hygiene grep in Task 3 must return 0 |
| T-29-SC | Tampering | ghostunnel image | mitigate | Same tag and digest as homepage and the pre-fix evidence (`sha256:51fa6192…4faf`). The local test pulls by digest. No package-manager installs |
</threat_model>

<verification>
- Task 1: every 29-05/29-07 overlay gate passes on the worktree branch; the source-1 render proves the sidecar shape and mount isolation; the runtime arg check passes with a failing negative control.
- Task 2: operator approval recorded verbatim.
- Task 3: the Application is Synced and Healthy at the new overlay revision; the sidecar is Ready; the old Deployment is pruned; EndpointSlice, VIP, TLS and HTTP are proven on both hostnames; the PVC is unchanged; the worktree is removed.
</verification>

<success_criteria>
DefectDojo is reachable over verified HTTPS on both hostnames at 10.40.3.65 through a ghostunnel native sidecar that needs no `--unsafe-target`. The public chart and its pin are unchanged. Plan 29-08 can resume from its Task 1 with the resume note applied.
</success_criteria>

<output>
Create `.planning/phases/29-defectdojo-live-validation/29-08a-SUMMARY.md`. Record:
- the operator replies verbatim;
- the worktree base SHA, PR number, approved head SHA and merge SHA;
- the gate table;
- the runtime check results (positive and negative);
- the Argo operation branch taken (normal auto-sync, or terminate-op);
- the live proof values;
- the ADR-027 inputs: B1 supersedes D-02, and the lesson that dry-run gates do not validate arg semantics;
- the stale-docs list (29-CONTEXT D-02, 29-RESEARCH Pattern 2).
</output>
