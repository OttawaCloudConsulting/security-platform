---
phase: 29-defectdojo-live-validation
plan: 05
subsystem: k8s-overlay
tags: [defectdojo, argocd, sealed-secrets, ghostunnel, cert-manager, cilium-lb, occ-k8s-app-config, ddojo-05]
requires:
  - "29-02: live `platform` AppProject admits destination defectdojo, policy/PodDisruptionBudget, and the security-platform repoURL"
provides:
  - "Local overlay branch feat/defectdojo-app-directory at a783559 carrying application-sets/platform/defectdojo/ (not pushed)"
  - "Two-source Application patch pinned to security-platform c8027e6784ec631db128f45444c9a8092db9d0a1"
  - "Three wave -1 SealedSecrets (7 credentials) sealed to sealed-secrets/sealed-secrets"
  - "Certificate defectdojo-tls (both SANs), standalone ghostunnel Deployment, LB Service on the vlan43-static VIP"
  - "README with homelab literals and the Rollback plan"
affects: [29-07, 29-17, 29-19]
tech-stack:
  added: []
  patterns:
    - "Hyphenated Secret keys are sealed with `kubectl create secret generic --from-file ... --dry-run=client | kubeseal`, because seal-secret.sh's SECRET_LITERAL_<KEY> form cannot express them"
    - "Each OMITTED symptom comment that names a render effect was confirmed by a counter-render with that one value removed"
key-files:
  created:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/argocd-overrides.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/Chart.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/README.md
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/sealedsecret-defectdojo.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/sealedsecret-defectdojo-postgresql-specific.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/sealedsecret-defectdojo-valkey-specific.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/certificate.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/ghostunnel-deployment.yaml
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/application-sets/platform/defectdojo/templates/service.yaml
  modified:
    - /Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config/.gitleaksignore
decisions:
  - "29-05: sources[0].targetRevision pinned to security-platform main c8027e6784ec631db128f45444c9a8092db9d0a1, read by git ls-remote on 2026-09-27 20:15 UTC"
  - "29-05: DD_CREDENTIAL_AES_256_KEY sealed at 128 characters (the chart README's upstream length), not the plan's 32"
  - "29-05: postgres and valkey Secrets sealed with kubectl --from-file piped to kubeseal, because their hyphenated key names cannot be bash identifiers in seal-secret.sh's env-file form"
  - "29-05: ghostunnel runs with no --target-status (TCP-dial status); RESEARCH A2 (/nginx_health without host validation) is unmeasured"
  - "29-05: initializer staticName true + Argo Sync hook + BeforeHookCreation + keepSeconds 0, for plan 29-17 to measure"
  - "29-05: .gitleaksignore gained 7 fingerprints, one per encryptedData line"
  - "29-05: the overlay commit landed on a concurrent actor's branch docs/authentik-7.1-closeout; feat/defectdojo-app-directory was moved to it with branch -f and the other branch was left untouched for the operator"
metrics:
  duration: "~15min"
  completed: 2026-09-27
  tasks: 3
  files: 10
---

# Phase 29 Plan 05: DefectDojo overlay app directory Summary

The private overlay now has `application-sets/platform/defectdojo/`. It holds a two-source Application patch that pins the public security-platform chart to `c8027e6784ec631db128f45444c9a8092db9d0a1`, seven credentials sealed into three wave -1 SealedSecrets, a two-SAN DNS-01 Certificate, a standalone ghostunnel Deployment and an LB Service on `10.40.3.65`. Every local gate passes. The work is committed as `a783559` on `feat/defectdojo-app-directory` and has not been pushed.

## BLOCKER: the overlay commit also sits on another actor's branch

The overlay working tree is shared with a concurrent session. The reflog shows the sequence:

| Time (local, -0400) | Reflog entry |
| --- | --- |
| 16:17:42 | `checkout: moving from main to feat/defectdojo-app-directory` (this plan) |
| 16:24:06 | `checkout: moving from feat/defectdojo-app-directory to docs/authentik-7.1-closeout` (**not this plan**) |
| 16:24:55 | `commit: feat(defectdojo): add DefectDojo overlay app directory (Phase 29 / DDOJO-05)` (this plan's `gcommit`) |

The other session created and checked out `docs/authentik-7.1-closeout` from `e965581` 49 seconds before this plan's commit. Untracked files survive a branch switch, so this plan's staged directory rode along, and `a783559` was created on that branch.

What this plan did: it ran exactly one ref update, `git branch -f feat/defectdojo-app-directory a783559`. That branch is this plan's own, created minutes earlier, never pushed and not checked out. The deliverable now sits where plan 29-07 expects it. This plan did **not** check out, reset or otherwise change `docs/authentik-7.1-closeout`, the working tree, or HEAD, which still belongs to the other session.

**Operator action before plan 29-07 pushes anything:** remove `a783559` from `docs/authentik-7.1-closeout`. If nothing else has been committed on that branch since, `git branch -f docs/authentik-7.1-closeout e965581` does it, but only when that branch is not checked out, or with `git reset --hard e965581` from inside it. If the other session has committed on top, rebase its commits onto `e965581` without `a783559`. Later Phase 29 plans must not assume the shared overlay checkout stays on the branch they created.

## What was built

| File | Content |
| --- | --- |
| `argocd-overrides.yaml` | `source: null` plus two sources: security-platform `kubernetes/defectdojo` at the pinned SHA with `releaseName: defectdojo`, and this directory at `main`. The `valuesObject.defectdojo` values are `host`, `alternativeHosts`, `siteUrl`, `django.ingress.enabled: false`, `extraConfigs.DD_CSRF_TRUSTED_ORIGINS`, and `initializer` (`staticName: true`, `keepSeconds: 0`, Sync hook + BeforeHookCreation). The `syncPolicy` is the Nexus one verbatim. |
| `Chart.yaml` | `defectdojo` 0.1.0, `appVersion: "3.3.200"`, and no `dependencies:`, with the rationale comment |
| `README.md` | the homelab literals (VIP, both FQDNs, the Pi-hole entries on `10.40.1.53`, the open `10.30.1.53` VLAN30 question), the discretion choices, the rules, and a four-point `## Rollback` |
| `templates/sealedsecret-defectdojo.yaml` | `DD_ADMIN_PASSWORD` (22), `DD_SECRET_KEY` (128), `DD_CREDENTIAL_AES_256_KEY` (128), `METRICS_HTTP_AUTH_PASSWORD` (32) |
| `templates/sealedsecret-defectdojo-postgresql-specific.yaml` | `postgresql-postgres-password`, `postgresql-password` (32 each), with the Pitfall 9 never-delete-the-PVC comment |
| `templates/sealedsecret-defectdojo-valkey-specific.yaml` | `valkey-password` (32) |
| `templates/certificate.yaml` | `defectdojo-tls`, CN `.infra`, SANs `.infra` and `.home`, ECDSA 256, `letsencrypt-dns01-prod`, wave `"-1"` |
| `templates/ghostunnel-deployment.yaml` | `defectdojo-ghostunnel`, 1 replica, `--target=defectdojo-django.defectdojo.svc.cluster.local:80`, `--timed-reload=300s`, no `--target-status`, whole-directory TLS mount, pod-level non-root securityContext, `automountServiceAccountToken: false` |
| `templates/service.yaml` | `defectdojo-ghostunnel` LoadBalancer with `vlan: "43"`, `IPautoAssign: "false"`, `lbipam.cilium.io/ips: "10.40.3.65"`, `externalTrafficPolicy: Cluster`, 443 to `https`, selecting the ghostunnel pods only |
| `.gitleaksignore` | 7 new fingerprints under a `# Phase 29 / DDOJO-05` comment |

**Pin:** `c8027e6784ec631db128f45444c9a8092db9d0a1`, read with `git ls-remote https://github.com/OttawaCloudConsulting/security-platform refs/heads/main` at 2026-09-27 20:15 UTC. The local security-platform clone's `kubernetes/defectdojo` tree equals the pin (`git diff --stat <pin> HEAD -- kubernetes/defectdojo` printed nothing).

**Vendored-chart check:** `git ls-files kubernetes/defectdojo` lists no `charts/*.tgz`, so the `helm dependency build` comment is written for `https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts`.

## Credentials: where the operator retrieves them

No value was printed, logged or written to any committed file. Each value was generated by `python3 secrets` straight into a 0600 scratchpad file under `umask 077`. The files were removed by an EXIT trap right after sealing, and `ls` of the scratchpad confirmed that no `.env`, value file or unsealed manifest remains. Lengths were checked by counting characters, never by printing. The values exist in the clear only in the cluster, once the controller decrypts the SealedSecrets after 29-07 merges. They can be retrieved there:

```sh
kubectl -n defectdojo get secret defectdojo -o jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 -d
kubectl -n defectdojo get secret defectdojo-postgresql-specific -o jsonpath='{.data.postgresql-password}' | base64 -d
kubectl -n defectdojo get secret defectdojo-valkey-specific -o jsonpath='{.data.valkey-password}' | base64 -d
```

The rendered `DD_ADMIN_USER` is `admin`. `seal-secret.sh`, used for the `defectdojo` Secret, passes values briefly as `--from-literal` arguments to a client-side `kubectl create secret --dry-run=client`, which puts them in that process's argv, as in 25-03. The two hyphenated-key Secrets used `--from-file`, which keeps the values off argv.

## Gate results (Task 3)

| Gate | Result |
| --- | --- |
| `yamllint .` (repo-wide) | exits 1, but the failure is **pre-existing**. There are 51 error lines on a `git archive origin/main` extract and 51 on a `git archive a783559` extract, so the change adds none. The working tree adds more from the gitignored `temp/`. `yamllint application-sets/platform/defectdojo` exits 0, and the pre-commit yamllint hook passed. |
| `helm template defectdojo-local application-sets/platform/defectdojo` | exits 0. It renders Service, Deployment, Certificate and 3 SealedSecret. |
| Source 1 render (pinned chart, exact overlay `valuesObject`, `helm dependency build` in a scratchpad `git archive` of the pin) | exits 0. See the assertions below. |
| `python3 docs/argocd/conformance/c1.py` | `PASS C-1: 0 violation(s) across 21 file(s)` |
| `python3 docs/argocd/conformance/check_appconfig.py --base origin/main` | `PASS check-appconfig: 0 check(s) failed ... 22 application(s)` (after the commit; 21 before it) |
| `kubectl --context admin@occ-new apply --dry-run=client -f` on each of the six templates | all `created (dry run)` |
| gitleaks, scoped `--source application-sets --no-git --redact` | 7 findings before pinning (all `generic-api-key` on `encryptedData` lines), 0 after |
| gitleaks, CI form (`--source .` on a `git archive a783559` extract) | `no leaks found`, rc 0 |
| pre-commit hooks at commit time | yamllint, markdownlint, c1 and check_appconfig all passed |
| `git diff origin/main a783559 --name-only` | exactly the 9 directory files plus `.gitleaksignore` |
| `git log origin/main..a783559 -p \| grep -Ec 'DD_ADMIN_PASSWORD: [A-Za-z0-9]{10,}$'` | `0` |

**Source 1 render assertions:**
- (a) Ingress: 0.
- (b) The ConfigMap `defectdojo` has `DD_ALLOWED_HOSTS=defectdojo.infra...,defectdojo.home...`, `DD_SITE_URL=https://defectdojo.infra.ottawacloudconsulting.com` and `DD_CSRF_TRUSTED_ORIGINS` with both https origins. The wrapper's `DD_DUPLICATE_CLUSTER_CASCADE_DELETE` and `DD_DEDUPLICATION_ALGORITHM_PER_PARSER` survive the map merge. Each of `DD_ALLOWED_HOSTS:` and `DD_SITE_URL:` occurs once. `DD_SECURE_PROXY_SSL_HEADER` is absent.
- (c) `DD_SESSION_COOKIE_SECURE` and `DD_CSRF_COOKIE_SECURE` are `"True"`. They render as **env vars on the django Deployment**, not as ConfigMap keys as the plan's wording implied.
- (d) The Job is exactly `defectdojo-initializer`, with `argocd.argoproj.io/hook: Sync` and `hook-delete-policy: BeforeHookCreation`, and `ttlSecondsAfterFinished` is null.
- (e) Service `defectdojo-django` exposes port 80 (`http`).

**Counter-renders confirming the OMITTED comments (measured, one value removed at a time):**
- Without `keepSeconds`: the Job gets `ttlSecondsAfterFinished: 60`.
- Without the `django.ingress` override: the render aborts at `validate-tls.yaml:39` ("activateTLS is true but no cert-manager issuer is set").
- Without `staticName`: the Job is named `defectdojo-initializer-2026-09-27-16-24`.

## Discretion choices (as recorded in the README)

- The directory is `platform/defectdojo/`, following the Nexus precedent.
- The ghostunnel image is `docker.io/ghostunnel/ghostunnel:v1.11.3-distroless`, the homepage pin. Certificates reload via `--timed-reload=300s`.
- `--target-status` is omitted, so ghostunnel uses its TCP-dial status. RESEARCH A2 is unmeasured.
- The initializer uses `staticName: true` + Sync hook + `BeforeHookCreation` + `keepSeconds: 0`. Plan 29-17 measures it.
- The Certificate `commonName` is `.infra`, because `host` and `siteUrl` are `.infra`.

## Observations for plan 29-17 (flagged, not asserted)

- The render includes `Pod/defectdojo-unit-tests` with `helm.sh/hook: test-success`. 29-02 recorded that Argo CD skips it. That was not re-measured here.
- ServiceAccount `defectdojo` carries `helm.sh/hook: pre-install` + `before-hook-creation`. This is the PreSync delete-and-recreate predicted by RESEARCH Pitfall 4.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Hyphenated Secret keys cannot pass through `seal-secret.sh`**
- **Found during:** Task 1
- **Issue:** The script derives each key from a bash variable name (`SECRET_LITERAL_<KEY>`, via `source` and `compgen -v`). `postgresql-postgres-password`, `postgresql-password` and `valkey-password` contain `-`, which is not a valid identifier.
- **Fix:** Those two Secrets were built with `kubectl --context admin@occ-new create secret generic <name> -n defectdojo --from-file=<key>=<0600 file> --dry-run=client -o yaml | kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets --format yaml`. The value files were written with no trailing newline. `seal-secret.sh` was used unchanged for the `defectdojo` Secret. The two SealedSecret headers document the re-seal path.
- **Commit:** a783559

**2. [Rule 1 - Bug] `DD_CREDENTIAL_AES_256_KEY` length**
- **Found during:** Task 1
- **Issue:** The plan said N=32 "per the chart README's upstream lengths". The chart README says 22/128/128/32, and its example uses `gen 128` for the AES key. The plan itself says the README wins.
- **Fix:** The key was sealed at 128 characters.
- **Commit:** a783559

**3. [Rule 1 - Bug] Task 1 verify command has a yq precedence bug**
- **Issue:** `.spec.encryptedData | has("A") and has("B") ...` binds as `(.spec.encryptedData | has("A")) and has("B")`, so it returns false for a correct file.
- **Fix:** The check was run in the parenthesized form `.spec.encryptedData | (has(...) and ...)`, which returns `true`. `(.spec.encryptedData|keys|length)==4` also holds. The plan file was not edited.

**4. [Rule 1 - Bug] Stale doc references in the homepage precedent**
- **Issue:** The homepage comments cite `docs/homepage/ARCHITECTURE_AND_DESIGN.md` and `docs/cert-manager/route53-zone-coverage.md`, and neither is tracked in the overlay repo.
- **Fix:** The new files point at the homepage templates instead, so the stale paths were not propagated. Homepage itself was left untouched as out of scope.

**5. Commit granularity:** the plan specifies one overlay commit in Task 3 for all three tasks, so there are no per-task commits. That was the plan's instruction, not a deviation choice.

### Out of scope (not fixed)

- Repo-wide `yamllint .` fails on `origin/main` (51 error lines, documented in the header of `.yamllint-precommit.yaml`), plus gitignored `temp/` content in the working tree.

## Threat Flags

None. All surface (the LB VIP, plaintext django :80 in-cluster, and the sealed credentials) is in the plan's threat register: T-29-03/05/06/13/14/SC.

## Known Stubs

None.

## Self-Check: PASSED

- All 9 directory files and `.gitleaksignore` exist in commit `a783559` (`git diff origin/main a783559 --name-only`).
- `git -C <overlay> log --oneline -1 feat/defectdojo-app-directory` returns `a783559`.
- Nothing was pushed. `origin/main` is still `e965581`, and no `origin/feat/defectdojo-app-directory` exists.
