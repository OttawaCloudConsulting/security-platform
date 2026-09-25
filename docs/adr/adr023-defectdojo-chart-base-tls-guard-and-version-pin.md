# ADR-023: DefectDojo Chart Base, cert-manager Issuer Guard and Pinned Version

**Status:** Accepted
**Date:** 2026-09-24
**Addresses:** DDOJO-01 — a public Helm chart deploys DefectDojo with external ingress and
cert-manager-issued TLS

This record lives in this documentation repository. The public `security-platform` chart README cites it
by number since PR #19 (merge commit `e097381`), so a reader of the public repository cannot follow the
link. That is the same arrangement ADR-022 recorded for the Nexus chart. Every measured value below is
quoted from a Phase 26 plan summary, from a file in that phase's `evidence/` directory, or from a
statement 26-RESEARCH marks `[VERIFIED]`; each is attributed where it appears. A value that does not
trace to one of those sources is labelled as recorded by the orchestrator or as unmeasured. No homelab
address, hostname, node name, kube context name or issuer name appears here.

## Context

- **The upstream chart already does most of what DDOJO-01 needs.** The official `defectdojo` chart
  1.9.53 (appVersion 3.3.200) defaults to `django.ingress.enabled: true`, `activateTLS: true` and
  `secretName: defectdojo-tls`, guards `ingressClassName` with `if` so an unset class is omitted, and
  copies `django.ingress.annotations` into the Ingress verbatim, so a consumer-supplied
  `cert-manager.io/cluster-issuer` annotation is all cert-manager's ingress-shim needs (26-RESEARCH,
  `[VERIFIED: tarball read + render]`).
- **A parent chart cannot inject Helm's `required` into a subchart's annotation map.** The issuer name
  lives inside `defectdojo.django.ingress.annotations`; Helm values are static and upstream does not run
  `tpl` over annotations, so a wrapper value such as `tls.clusterIssuer` plus `required` cannot reach the
  place the issuer must be written (26-RESEARCH, Alternatives). D-11's "required" had to be enforced by
  another mechanism.
- **Same-named wrapper helpers silently override the subchart.** Wrapper and subchart are both named
  `defectdojo`, and Helm named templates are global. A wrapper `_helpers.tpl` defining
  `defectdojo.fullname` renamed the subchart's Ingress and ConfigMap to the wrapper's output
  (26-RESEARCH Pitfall 1, `[VERIFIED: measured]`).
- **Upstream defaults OOMKilled uwsgi on kind at first login.** Measured in 26-RESEARCH Pitfall 2: 4
  uwsgi processes were OOMKilled at the upstream 512Mi limit on startup. `maxFd: 102400` alone fixed the
  startup OOM, but the first login POST OOMKilled the pod again. With `processes: 2` plus `maxFd: 102400`,
  idle memory was 286 MiB and the peak after login was 388-430 MiB. A GET of `/login` returned 200
  while the app was one POST away from crashing. The fd-table mechanism behind the startup OOM is
  inferred (RESEARCH A6), not proven; the fix is measured. These are prototype measurements; 26-05's
  live smoke on the final chart did not re-measure uwsgi memory and neither confirms nor contradicts them.
- **Chart-generated secrets that regenerate would orphan encrypted data.** Upstream can generate the
  Django secret key, `DD_CREDENTIAL_AES_256_KEY`, the admin password and the PostgreSQL and Valkey
  passwords. If those regenerate on an ArgoCD sync or `helm upgrade`, credentials already stored under
  the old AES key can no longer be decrypted (26-CONTEXT D-13).
- **This record extends four accepted decisions rather than editing any of them.** ADR-006 pins the
  DefectDojo version; its `2.x.y` example is superseded in practice by the 3.x line (3.3.200 here), and
  ADR-006 is left unchanged because the ADR directory is append-only. ADR-009's TLS guidance is applied
  here as TLS on by default with a render-time guard. ADR-020's wrap-an-upstream-chart pattern is reused
  with one deliberate inversion, the pinned image tag below. ADR-022 decision 3 (the credential as a
  SealedSecret at sync-wave `-1`) is the model for the Secret contract, and ADR-022 decision 4 (no
  IngressClass found on the homelab) is why the chart leaves the class unset. None of those files was
  edited.

## Decision

1. **Wrap the official `defectdojo` chart 1.9.53 as a `Chart.yaml` dependency, pinned by a committed
   `Chart.lock`; do not fork and do not vendor it (D-01).** The dependency is fetched from the
   DefectDojo `helm-charts` branch. The tarball `defectdojo-1.9.53.tgz` is gitignored; its sha256
   `0393332d77412d2a76921f418faf933e9739088ddbf207b2a4b94867daa0657d` equals the helm-charts index
   digest (26-03). The wrapper ships no `_helpers.tpl` and no `define "defectdojo.*"`; the gate's
   NO-HELPER-COLLISION check enforces that.
2. **Pin the subchart version and both DefectDojo image tags to 3.3.200, with an IMAGE-PIN drift
   check; pin by tag, not by digest (D-03, RESEARCH A1).** This departs from the Nexus chart's floating
   image tag (ADR-020) on purpose: DefectDojo runs Django schema migrations on upgrade, so a floating tag
   could migrate the findings schema unannounced. A bump changes four pin points together (Chart.yaml
   `appVersion`, the dependency version via `Chart.lock`, and the `django` and `nginx` image tags), and
   the offline gate's IMAGE-PIN check fails if they disagree.
3. **Keep `values.yaml` thin (D-04).** Only the keys whose upstream default is wrong for this stack, or
   must not silently drift, are restated: host and `siteUrl`, the two image tags, the ingress block, the
   uwsgi settings and resources, and Valkey persistence. Everything else passes through to the subchart.
4. **Bundled PostgreSQL persistent, bundled Valkey ephemeral, subchart images as-is (D-05, D-07,
   D-08).** PostgreSQL persistence is the upstream default and is not restated. Valkey is only the
   Celery broker, so `defectdojo.valkey.persistence.enabled: false` overrides the upstream valkey 0.25.8
   default of an 8Gi PVC. No image `repository` is overridden anywhere.
5. **Ingress and TLS on by default, a placeholder host, `ingressClassName` and StorageClass omitted
   (D-09, D-10, D-12).** The host is `defectdojo.example.com` (RFC 2606 reserved; ACME CAs refuse it,
   so a forgotten override fails loudly; RESEARCH A2). `ingressClassName` is absent from `values.yaml`,
   not empty, so the cluster's default IngressClass applies. The PostgreSQL `storageClass` key is absent,
   so no `storageClassName` field is rendered and the cluster's default StorageClass applies. Neither
   key is written as `""` or `null`.
6. **The issuer is required through a `fail` guard, and the annotation key is the issuer-kind selector
   (D-11).** `templates/validate-tls.yaml` renders no object. It aborts the render when
   `activateTLS` is true and neither `cert-manager.io/cluster-issuer` nor `cert-manager.io/issuer` is set,
   when both are set, or when `secretName` is empty. There is no `issuerKind` value: the consumer writes
   the annotation it means. 26-03 measured every case: a bare render exits 1 with a message naming
   `cert-manager.io/cluster-issuer`; only `cert-manager.io/issuer=x` exits 0; both keys exit 1; an empty
   `secretName` exits 1; `activateTLS=false` with no issuer renders an Ingress with no `spec.tls`.
7. **Secrets default to pre-created (`existingSecret`); chart-generated secrets are an opt-in (D-13).**
   `createSecret`, `createPostgresqlSecret` and `createValkeySecret` all default to `false` upstream, so
   the chart renders zero Secrets and the consumer pre-creates them, in the homelab as SealedSecrets at
   sync-wave `-1` per ADR-022 decision 3. Setting any of the three to `true` is available for a quick
   local try.
8. **uwsgi sized from the measurement: `processes: 2`, `maxFd: 102400`, requests 384Mi, limit 1Gi.**
   These close the OOM described in the Context. The README tells consumers not to lower the limit below
   512Mi with 2 processes, the floor 26-RESEARCH measured.
9. **Media stays at the upstream `emptyDir`.** Uploaded files and finding attachments are lost on pod
   restart; findings themselves live in PostgreSQL. The chart README's Limitations section names the
   `defectdojo.django.mediaPersistentVolume.*` override and its RWX caveat. This was presented to the
   operator as decision (a) of seven (a-g) at the 26-06 checkpoint. The operator merged PR #19 themselves
   and replied, verbatim: "PR#19 is merged, PR17 and PR18 are not - tell me if I need to". That reply
   does not address the media decision, or any of a-g, item by item. The decisions are recorded as
   accepted by the operator's merge with a-g in front of them; no per-item approval exists and none
   was rejected (26-06).
10. **Validation is an offline gate plus a first-install kind smoke that includes a real login and a
    Celery broker ping (D-14, D-15).** The smoke goes beyond D-14's literal "login page returns 200"
    because a GET `/login` 200 did not rule out the OOM (RESEARCH OQ5). On the committed chart at
    `security-platform` `60205bd`, 26-05 recorded the offline gate as `PASS - 20 checks, 0 failures` and
    the live smoke as `ALL PASS - 12 live check(s) executed and passed; 0 sub-check(s) skipped`, `rc=0`,
    196 s wall-clock from cluster creation to teardown. That run includes a verified-TLS `/login` 200
    (issuer `CN=smoke-ca`, SAN `DNS:defectdojo.smoke.test`, `ssl_verify_result 0`), an admin login
    followed by `/dashboard` 200, and `celery -A dojo inspect ping` returning pong. Resync and second-sync
    idempotency are left to Phase 29 (D-15).
11. **Published in PR #19, corrected in PR #20.** PR #19 merged at 2026-09-25T02:20:25Z as the
    two-parent merge commit `e097381c72fab2534199e8c63cc3f3f6d198e3a2`, with 12/12 CI checks passing
    (26-06). After that merge, the orchestrator found that on a clean copy of `origin/main`
    `helm dependency build kubernetes/defectdojo` failed with "Error: no repository definition for
    https://raw.githubusercontent.com/DefectDojo/django-DefectDojo/helm-charts. Please add the missing
    repos via 'helm repo add'". Neither the README install step nor the live smoke's vendoring fallback
    ran `helm repo add`. The gap had been masked because the development machine already had the tarball
    vendored. 26-06 hit the same error in its own `origin/main` gate run and worked around it with the
    local tarball rather than fixing the instructions. The operator chose to fix it now. PR #20,
    "fix(defectdojo): register the chart repo before helm dependency build" (commit `e07926f`), merged at
    2026-09-25T02:56:57Z as merge commit `71a112e02bf974f27d8d8778d045be2f89e1b018`. It adds
    `helm repo add defectdojo <url>` before the build in the README's install section, and makes the
    smoke register the repository in a throwaway `HELM_REPOSITORY_CONFIG` / `HELM_REPOSITORY_CACHE`
    under its temporary directory. No chart, values or `Chart.lock` change. As recorded by the
    orchestrator for PR #20: the README steps on a fresh copy downloaded `defectdojo-1.9.53.tgz` with the
    same sha256 as 26-03 and left `Chart.lock` unchanged; the live smoke from a clean worktree with no
    vendored tarball printed `ALL PASS - 12 live check(s) executed and passed; 0 sub-check(s) skipped`,
    `rc=0`, restored the kube context, left no cluster behind and did not touch the operator's
    `helm repo list`; 12/12 CI checks passed.

## Consequences

**Improved:** the chart is generic. `values.yaml` carries no environment value: the host is an RFC 2606
placeholder, and no issuer, IngressClass or StorageClass name appears. Issuer, class and real host
live only in a consumer's overlay.

**Improved:** TLS cannot be forgotten. With TLS on by default and the guard in place, the only way to
render without an issuer is to turn TLS off explicitly. A consumer cannot ship a plaintext or
certificate-less Ingress by omission.

**Improved:** schema changes are deliberate. Because the subchart and both image tags are pinned together
and IMAGE-PIN checks their agreement, a DefectDojo version change is a reviewed edit, never a side
effect.

**Tradeoff — a bare install fails until an issuer is set.** `helm install` with no values stops at the
guard. This was accepted in D-11: the placeholder host saves one flag, the issuer does not. It is also
why the README's install command carries the issuer `--set`.

**Tradeoff — CI's Checkov covers this chart zero times.** 26-05 measured this as
MEASURED-ZERO-WITH-A-NAMED-CAUSE. Using the CI-equivalent method, with the then-pinned
`ghcr.io/bridgecrewio/checkov:3.3.17` container, which ships Helm v3.22.0, the helm runner fetched
`defectdojo-1.9.53.tgz` and then logged `[WARNI] Failed processing helm chart defectdojo` with the
issuer guard's own message. The exit code was unaffected. Both the pre-chart and post-chart trees gave
14 failed checks, all in `fixtures/`, with an identical check_id plus file_path set. Rendered locally with
gate values, Checkov 3.2.396 reports 66 failed, 568 passed over 26 resources, with 0 failures on
wrapper-owned resources; 15 of the 66 fall on the upstream helm-test Pod. None of those 66 reach the
pipeline today. As with the Nexus chart (ADR-020), the guard is not weakened to obtain coverage, and no
suppression was added. The CI container has since moved: PR #17, the Dependabot bump of
`checkov-action` to v12.3125.0 (container 3.3.17 to 3.3.19 per 26-06), merged at
2026-09-25T02:46:50Z (merge commit `785d807`). 26-05's CI-equivalent measurement has not been repeated
on 3.3.19.

**Tradeoff — the pin ages quickly and bumps are manual.** Upstream moved from chart 1.9.39 to 1.9.53 in
eight weeks (26-RESEARCH, State of the Art). No Dependabot `helm` ecosystem was added (RESEARCH OQ3):
a community report says chart and image name collisions can overwrite values image tags, and here the
dependency `defectdojo` and the images `defectdojo/defectdojo-*` might collide, splitting the pins (A4,
unmeasured). The README documents the manual procedure: edit the Chart.yaml dependency, `appVersion` and
both image tags, run `helm dependency update`, then run the gate. IMAGE-PIN catches a partial bump either
way.

**Tradeoff — uploaded files are not persisted.** With media at `emptyDir`, attachments are lost on pod
restart. Persisting them is a consumer override, and the upstream PVC option defaults to ReadWriteMany,
which many StorageClasses cannot provide.

## What was NOT verified

What WAS measured in this phase and must not be re-litigated: the issuer guard's five render cases and
the gate at `PASS - 20 checks, 0 failures` (26-03, 26-05); the live kind smoke at 12 checks, 0 skipped,
`rc=0`, including cert-manager issuing a Certificate through ingress-shim, a verified-TLS `/login` 200,
an admin login with `/dashboard` 200 and a Celery broker ping (26-05); the tarball sha256 matching the
index digest (26-03); the local and CI-equivalent Checkov counts above (26-05); the `origin/main` tree
after PR #19 carrying all eight chart and script files and no tarball (26-06); and, as recorded by the
orchestrator, the PR #20 fresh-copy install and clean-worktree smoke.

1. **The CSRF mechanism behind other proxies.** The login POST passed CSRF behind ingress-nginx 1.15.1 on
   kind with neither `DD_SECURE_PROXY_SSL_HEADER` nor `DD_CSRF_TRUSTED_ORIGINS` set, and the reason was
   not identified (RESEARCH OQ4). Phase 29 runs behind whatever proxy the homelab ends up with and must
   re-run the login POST there. If it returns 403, the documented fallback is
   `defectdojo.extraConfigs.DD_CSRF_TRUSTED_ORIGINS` in the overlay, with no chart change.
2. **The homelab has no ingress path yet, as far as the config repositories show.** No live IngressClass,
   ingress controller or Gateway was found in the homelab config repositories; the only
   `ingressClassName` found was in archived configuration. cert-manager with Route53 DNS-01
   ClusterIssuers does exist for other applications (RESEARCH OQ6). This was read from repositories, not
   from the cluster. Phase 29 must check IngressClasses and ClusterIssuers live and decide how DDOJO-05
   gets an ingress controller.
3. **Helm 3 `--wait` semantics.** Every `helm install --wait` in this phase ran under Helm v4.3.0 (kstatus
   watcher). Helm v3.22.0 was exercised only for rendering, inside the Checkov container (26-05). Whether
   the install waits behave the same under Helm 3 was not measured.
4. **Upgrade and resync idempotency under ArgoCD, including `initializer.staticName`.** The smoke covers
   first install only (D-15). `initializer.staticName` stays at the upstream default (`false`), which
   gives the initializer Job a new name on every render; whether ArgoCD then shows it as perpetually
   OutOfSync, and whether `true` with the Job's TTL is better, is left to Phase 29 (RESEARCH OQ2).
5. **The bundled Bitnami PostgreSQL NetworkPolicy on Cilium.** It renders by default
   (`primary.networkPolicy.enabled`, `allowExternal: true`, egress `{}`) and is inert on kind's kindnet.
   On the homelab's Cilium it would be enforced; its effect there was not observed (RESEARCH OQ7).
6. **Footprint on non-arm64 hardware and on the final chart.** All memory figures come from the
   26-RESEARCH prototype on the development machine. 26-05 did not time `helm install` separately and did
   not measure uwsgi memory, so the README's 101 s install and 388-430 MiB peak are prototype numbers.
7. **Why 26-03's `helm dependency build` succeeded without `helm repo add`.** 26-03 recorded a successful
   build and the orchestrator found a clean copy failing; the difference was not established. PR #20
   removes the dependency on it.
8. **The Nexus chart README likely has the same install gap.** `kubernetes/nexus/README.md` uses the same
   build-only instruction (`helm dependency build kubernetes/nexus` with no `helm repo add`). The failure
   was not reproduced for Nexus. It is recorded as a follow-up, not as a verified defect.
