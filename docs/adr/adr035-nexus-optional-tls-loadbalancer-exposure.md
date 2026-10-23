# ADR-035: Optional TLS LoadBalancer Exposure of Nexus, in Addition to Cluster-Internal Access

**Status:** Accepted
**Date:** 2026-10-22
**Implemented in:** `OttawaCloudConsulting/security-platform` PR #46, squash-merged to `main` as
`431d71d450460210073ef2b39f0d31be8a4a88ad` (2026-10-22)
**Supersedes in part:** ADR-022 decision 4 (ingress and TLS excluded) and ADR-021 "What was NOT verified" item 4 (no TLS
anywhere in this stack). Neither record is edited; this one takes over the stance they set.
**Addresses:** a requirements request from the app-team session (E1 to E8), and ADR-034 consequence "Nexus logins cross the
network"

This record lives in this documentation repository. The code it describes is in
`OttawaCloudConsulting/security-platform`, `kubernetes/nexus/`. No address, hostname or class name from any deployment
appears here: the consuming overlay supplies them.

## Context

- **The stance being changed.** ADR-022 decision 4 left ingress and TLS out of the Nexus validation on purpose: the
  cluster had no IngressClass, a load-balancer address is the operator's to pick, and port-forward to loopback kept
  unauthenticated plaintext off the LAN. ADR-021 item 4 and ADR-022 item 2 recorded that nothing was measured over TLS.
  Nexus was reachable only through `kubectl port-forward`.
- **What changed.** ADR-034 made Nexus authenticate users against a directory. Credentials now cross the network on
  login, and a port-forward is not a way for a team, a CI runner or a package client to reach a service. Consumers need
  a network-reachable endpoint for the UI, the REST API and package clients, and it has to be TLS.
- **The chart is generic.** It is public and reused. Addresses, networks, load-balancer classes and policies belong to
  the consumer, so the chart must carry none of them.
- **Constraints from the request.** Additive and opt-in; the existing `ClusterIP` Service and port-forward unchanged;
  a render with exposure off byte-identical to the previous chart; TLS only on the new path; the certificate comes from
  an existing Secret and is never created by the chart; no templates for certificate issuance, DNS, address allocation,
  announcement or network policy.

## Decision

1. **Add an opt-in `expose:` block, `enabled: false`.** When false it renders nothing. When true the chart renders two
   objects and nothing else: a TLS-terminating proxy Deployment and a `LoadBalancer` Service in front of it. The Nexus
   `StatefulSet`, its `ClusterIP` Services and the provisioning Job are not touched. This is in addition to
   cluster-internal access and port-forward, which remain.
2. **Terminate TLS in a separate proxy, not in the Nexus pod.** An unprivileged `nginx` Deployment forwards to the
   Nexus `ClusterIP` Service. The alternatives were a sidecar in the Nexus pod and Nexus's own Jetty HTTPS. Both mean
   changing the Nexus pod, and a parent chart cannot compute the subchart's `extraInitContainers` from its own values,
   so the consumer would have had to hand-write the sidecar. A separate Deployment keeps the in-cluster path provably
   unchanged, which a check asserts (decision 8).
3. **The proxy must be HTTP-aware: it sets `X-Forwarded-Proto: https` and passes `Host` through.** Behind a
   layer-4 TLS tunnel Nexus cannot tell the client used TLS. Measured on Nexus 3.96.0: through the tunnel, `GET /v2/`
   returned `Www-Authenticate: Bearer realm="http://..."`, so a Docker client follows an `http://` realm to a TLS-only
   port and cannot authenticate; with `X-Forwarded-Proto: https` and the Host header passed through, the realm is
   `https://` (the one header, plus Host, is enough; `X-Forwarded-Host` is not needed). The mechanism is Nexus's
   `http.forwarded` capability, which is enabled on a fresh instance. This is a measured dependency: a consumer who
   disables that capability breaks the realm and the repository URLs. The chart sets nothing inside Nexus.
4. **Every port on the LoadBalancer is TLS.** The main listener and each `expose.extraPorts` item map to a proxy
   `server` block that is `listen <port> ssl` with a certificate and a key. There is no http port and no listener
   without `ssl`. Server-side TLS only; no client certificate is requested.
5. **The certificate is an existing Secret, owned by the consumer.** `expose.tls.secretName` names a
   `kubernetes.io/tls` Secret and is `required` when enabled. The chart creates no Certificate, Issuer or self-signed
   material. A renewed Secret is picked up with no manual step: the Secret is mounted as a directory, kubelet refreshes it
   in place, and nginx opens the certificate and key on every new TLS handshake because their paths are given as
   variables (a literal path would be read once at start-up). There is no timer, signal or restart. Connections already
   open keep the certificate they started with until they close.
6. **Values-driven Service, no defaults.** Annotations and labels pass through unchanged. `loadBalancerClass`,
   `loadBalancerIP` and `externalTrafficPolicy` are rendered only when set. The exposed port and extra ports are values.
   `loadBalancerIP` is deprecated in Kubernetes; a load balancer that selects an address by annotation uses `annotations`.
7. **Extra ports.** `expose.extraPorts` (empty by default) serves more connector ports, such as a Docker connector,
   through the same proxy. It does not create the connector on the Nexus side; the consumer adds that to Nexus and to the
   Nexus Service. A port `name` is 1 to 9 characters of lower-case letters, digits and `-` and must be unique, because it
   becomes the Service port name `https-<name>` (15 characters at most). An invalid or duplicate name fails the render
   rather than being truncated: truncation let two distinct names collapse into one in the first version.
8. **Seven gates guard it.** `scripts/check-nexus-chart.sh` grows from 22 to 29 invariants: `EXPOSE-DEFAULT-OFF`,
   `EXPOSE-REQUIRES-TLS-SECRET`, `EXPOSE-LB-PASSTHROUGH` (values rendered unchanged, nothing invented when unset, port
   names validated), `EXPOSE-NO-PLAINTEXT` (every `listen` is `ssl`), `EXPOSE-CLUSTERIP-UNCHANGED` (everything except
   the three new objects is identical to the default render), `EXPOSE-RELOAD` (directory mount, certificate paths as
   variables) and `EXPOSE-FORWARDED-PROTO`.
9. **Not in the chart.** Certificate issuance, DNS records, address allocation, load-balancer announcement, network
   policies and environment-specific labels or annotations. The consumer owns them in its own repository.

## Interaction with anonymous read, the local admin and LDAP

The chart forces no choice here. This is the part a consumer has to decide before turning exposure on.

- **Anonymous read (ADR-021).** `anonymous.enabled` already exists and is the switch; no new one was added. It grants
  read and browse on every repository, including repositories created later, with no credential. Before exposure that
  was reachable only through a port-forward. After exposure, `anonymous.enabled: true` makes every repository readable by
  anyone who can reach the load-balancer address. Anonymous write stays refused. If the instance should not be readable
  by the whole network, set it to `false` before enabling exposure. Setting it `false` closes it on the next provisioning
  run, because that step is declarative.
- **The local `admin` (the break-glass login).** It is a local account that works whatever the directory does, and
  ADR-034 keeps it on purpose. With exposure on, its login page is reachable from the same network, so the strength of its
  password and where it is reachable from become real questions, not theoretical ones. The chart does not disable it or
  restrict it to the cluster.
- **LDAP (ADR-034).** TLS now protects the password-only directory login on the wire. It does not change that a Nexus
  login bypasses any MFA at the identity provider.
- **The Docker bearer-token realm** is active regardless (ADR-021), so Docker clients work through the proxy as they do
  in-cluster.

## Consequences

- **A network listener exists where there was none.** The attack surface is larger, by exactly the proxy and the
  load-balancer address. The Nexus pod itself is not directly exposed.
- **The certificate is the consumer's dependency.** If the Secret is missing, the proxy pod does not start; if it expires
  and is not renewed, clients see an expired certificate. The chart cannot help, by design.
- **The hop behind the proxy is plaintext.** Anyone who can reach the Nexus `ClusterIP` Service inside the cluster can
  already speak plain HTTP to it. A `NetworkPolicy` that limits who can reach it is the consumer's to add.
- **Nexus sees the proxy as the client.** Client addresses in Nexus logs and request metadata are the proxy pod's. The
  load balancer or the proxy logs hold the real one.
- **One more image to keep current.** The proxy image is digest-pinned like the others (ADR-004), so a security update
  to nginx needs a values or chart change.
- **Cost of the separate proxy.** One more Deployment to run, with its own memory and CPU request.
- **`externalTrafficPolicy` and client addresses** behave as the consumer's load balancer defines them; the chart sets
  neither.

## What was verified, and what was not

Measured on 2026-10-22 with the chart's pinned `nginxinc/nginx-unprivileged` image
(`sha256:f5116ed4606f3eb015dd4a8e28cb9b351476dc0ad4bc6e9f93b19cec130cdf03`, nginx 1.30.6), running the configuration the
chart renders, in front of a real Nexus 3.96.0 with the Docker proxy provisioned, read-only root filesystem, UID 10101,
all capabilities dropped:

- Rendering: the default, the `expose.enabled=false` and a render with EULA, anonymous, Helm-proxy and LDAP values set are
  each byte-identical to the previous chart (`cmp`). The gate passes 29 of 29, and each new gate was turned red by a
  deliberate mutation (an invented default class, an http port on the Service, a plain `listen`, a `subPath` mount, a
  literal certificate path, a missing and a `$scheme` `X-Forwarded-Proto`, Host not passed through, a removed `required`,
  an object added outside the three, and a render when disabled).
- `nginx -t` passes on the rendered file.
- **Docker authentication through the proxy.** `GET /v2/` returned 401 with an `https://` realm; the token endpoint
  returned a token; `GET /v2/docker-proxy/library/alpine/manifests/3.21` with the Bearer returned **HTTP 200**. The same
  on an extra port (8444). `GET /service/rest/v1/repositories` returned `https://` URLs.
- **Certificate renewal.** With the certificate Secret mounted from a Linux volume and swapped atomically the way
  kubelet does it (a `..data` symlink moved to a new directory), the old certificate stopped verifying and the new one
  verified on the very next request, with the container up and not restarted. The same test on a macOS Docker bind
  mount failed with `invalid argument` for the previous proxy; that is a property of that bind mount, and is recorded so
  nobody repeats the wrong conclusion.
- A plain-HTTP request to a TLS port is not served (HTTP 400).

Two earlier results shaped this record and are kept as rejected alternatives:

- **ghostunnel, a layer-4 TLS tunnel, was the first design and was rejected.** It needs `--unsafe-target` to forward to
  a non-local address (measured: it exited at start-up without it), and, the reason it was dropped, it cannot set
  `X-Forwarded-Proto`, so Nexus advertised an `http://` Docker realm. Copilot's review of PR #46 raised that; it was
  confirmed by measurement. The status request used as the first evidence returned no absolute URL, and could not have
  shown it.
- **Setting the base URL inside Nexus** would also give `https://` URLs but means provisioning a capability from a
  hostname value, tying the chart to one name. Not chosen.

Not verified:

1. **Not run in Kubernetes.** The Deployment and the `LoadBalancer` Service were rendered and checked offline and with
   Checkov, but never applied to a cluster. The probes, the Secret mount and the Service selector were exercised only as
   far as the container test shows.
2. **No load balancer was involved.** Address assignment, class handling, annotations taking effect and
   `externalTrafficPolicy` are the consumer's load balancer's behaviour and were not exercised.
3. **A real Docker daemon pull.** The token exchange and the manifest request were done with curl. A daemon pulling
   blobs, and a push to a hosted repository, through the proxy were not run.
4. **A real second connector.** The extra port was exercised with a test route to the same Nexus port, not with a Docker
   connector listening on its own Nexus port.
5. **The real Secret refresh timing in a cluster** was not measured, so "typically within a minute" is the documented
   kubelet behaviour, not a measurement.
6. **Behaviour under load, many connections, and very large uploads** through a single proxy replica was not tested. The
   proxy does not buffer requests or responses and does not cap the body size.
7. **No `NetworkPolicy` and no pod-level restrictions** on who can reach the Nexus Service exist in this chart; Checkov's
   `CKV2_K8S_6` fires on the proxy pod for the same reason it fires on the Nexus pod.
8. **The Copilot review of the pull request and its triage are recorded in the pull request.** It raised two comments, both
   valid: the `http://` Docker realm (decision 3) and the truncated port-name collision (decision 7).
