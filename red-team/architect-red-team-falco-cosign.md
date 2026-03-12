# Architect Red-Team: Falco + Cosign/SLSA/Kyverno Additions

**Author:** Senior Platform Architect (red-team persona)
**Date:** 2026-02-26
**Scope:** Tool Details sections 11 and 12, the `sign` job in `security.yml`, Phase 4 additions, ADR-013, ADR-014, and the K8s Services Summary table.

---

## 1. Executive Summary

The Falco and Cosign/SLSA/Kyverno additions represent a genuine architectural improvement over the static-analysis-only baseline. The core design choices are defensible: keyless Cosign signing is the right call for a single-developer practice, Kyverno's native `verifyImages` is the cleanest path to admission control, and Falco is proportionate for this scale. However, the additions contain several technical defects that will cause a developer following this document to produce a broken or misleading implementation. The most serious finding is a security integrity violation: the `sign` job rebuilds the Docker image from scratch in a separate job rather than pushing and signing the image already built and scanned by the `container` job, meaning the signed image is categorically not the scanned image. A secondary critical finding is that the `allowed_outbound_destinations_map` macro referenced in the Falco network rule does not exist in any default Falco configuration, causing the rule to fail with a compilation error at load time. A single-replica Kyverno installation with `validationFailureAction: Enforce` creates a cluster-wide admission control single point of failure that the document does not adequately warn against. The workflow is also structurally incomplete: the `Generate SLSA provenance` step uses a reusable workflow reference inside a regular `steps:` block, which is not valid GitHub Actions syntax.

---

## 2. Findings

---

### ARCH-001
**Severity:** Critical
**Component:** Cosign/SLSA — `sign` job workflow
**Title:** Signed image is not the scanned image — the `sign` job rebuilds Docker from scratch

**Finding:**

The `sign` job contains a step labeled "Build and push image":

```yaml
- name: Build and push image
  id: build
  run: |
    IMAGE="ghcr.io/${{ github.repository }}:${{ github.sha }}"
    docker build -t "${IMAGE}" .
    docker push "${IMAGE}"
```

This step runs `docker build` again from the Dockerfile. The `container` job, which this job depends on via `needs: [container]`, also runs `docker build -t app:${{ github.sha }} .`. These are two separate `docker build` invocations in two separate job runners.

The document states in the `sign` job comment: "Only runs after container job passes — signs the same image Trivy scanned." This claim is false. The `container` job builds `app:<sha>` on runner A and discards it when the job completes. The `sign` job builds `ghcr.io/<repo>:<sha>` on runner B. These are different Docker build executions, on different runner instances, with different build contexts (the runner's fresh checkout), and potentially different Docker layer cache states.

Even with a deterministic Dockerfile, the two builds do not produce the same image digest in the general case. Many Dockerfiles include `apt-get` commands, `pip install` without hash-pinning, `COPY` of files that may differ in metadata, or embedded timestamps. If the build is non-deterministic, the `sign` job signs and attests a different artifact than the one Trivy scanned. A vulnerability found by Trivy in the first build may be absent in the second (e.g., a fixed package version was published between the two runner executions), or a new vulnerability may be present. The signed artifact has no cryptographic relationship to the scanned artifact.

ADR-014 reinforces this false claim: "The entire signing workflow is three lines added to an existing GitHub Actions job." The implementation adds a full rebuild, not three lines.

**Consequence:**

The core integrity guarantee of this section — "Every image deployed to production namespaces is verifiably built from a specific commit by the CI pipeline" — is undermined. The more accurate statement is: every image deployed is verifiably built from *a* build of that commit SHA, but not necessarily the one that was scanned. The Kyverno admission control enforces that an image was signed by the CI workflow, not that it was scanned. An image that passed signing but was not scanned (because it was rebuilt with a different dependency snapshot) can be admitted to production.

**Recommendation:**

The `container` job should build, tag with the registry reference (`ghcr.io/<repo>:<sha>`), push, and output the registry digest. The `sign` job should receive the digest as a job output and sign it without rebuilding. The correct pattern is:

```yaml
container:
  outputs:
    image: ${{ steps.push.outputs.image }}
    digest: ${{ steps.push.outputs.digest }}
  steps:
    - name: Build and push
      id: push
      run: |
        IMAGE="ghcr.io/${{ github.repository }}:${{ github.sha }}"
        docker build -t "${IMAGE}" .
        docker push "${IMAGE}"
        DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE}" | cut -d@ -f2)
        echo "image=${IMAGE}" >> "$GITHUB_OUTPUT"
        echo "digest=${DIGEST}" >> "$GITHUB_OUTPUT"

sign:
  needs: [container]
  steps:
    - name: Sign image
      run: |
        cosign sign --yes \
          --rekor-url https://rekor.sigstore.dev \
          "${{ needs.container.outputs.image }}@${{ needs.container.outputs.digest }}"
```

This pattern signs the exact digest produced and scanned by the `container` job. The Trivy scan in that job already has the image present in Docker's local layer cache, so no second push is needed.

---

### ARCH-002
**Severity:** Critical
**Component:** Cosign/SLSA — `sign` job workflow (SLSA provenance step)
**Title:** `slsa-github-generator` reusable workflow used inside a `steps:` block — invalid GitHub Actions syntax

**Finding:**

The `sign` job code block in section 12 and in the workflow at line 949–956 contains:

```yaml
      - name: Generate SLSA provenance
        uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@<SHA>
        with:
          image: ${{ steps.build.outputs.image }}
          digest: ${{ steps.build.outputs.digest }}
          registry-username: ${{ github.actor }}
          registry-password: ${{ secrets.REGISTRY_PASSWORD }}
```

This is not valid GitHub Actions syntax. Reusable workflows (`slsa-github-generator/.github/workflows/...`) are invoked as top-level jobs via the `uses:` key on a job, not as steps within a job. The `uses:` key at the step level is for individual actions (JavaScript or composite actions), not for entire reusable workflow files. Attempting to run this will produce a parse error or will silently be treated as an unsupported step type depending on the GitHub Actions runner version.

The correct invocation requires a separate job declaration:

```yaml
provenance:
  needs: [container]
  uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@<SHA>
  with:
    image: ${{ needs.container.outputs.image }}
    digest: ${{ needs.container.outputs.digest }}
    registry-username: ${{ github.actor }}
  secrets:
    registry-password: ${{ secrets.REGISTRY_PASSWORD }}
```

Additionally, the correct reusable workflow name for SLSA Level 2 container provenance as of the `slsa-github-generator` v2.x release series is `generator_container_slsa3.yml`. Despite the `slsa3` in the name, this workflow generates Level 2 provenance when invoked outside of an isolated builder environment. The document says "SLSA Level 2 provenance" in the text but uses the `slsa3` workflow filename without explaining this inconsistency. This will confuse an implementer who reads the SLSA specification.

**Consequence:**

The workflow as written will fail to parse or execute the SLSA provenance step. A developer who copies this configuration will have a `sign` job that either fails at runtime or produces no provenance attestation at all, with no indication of why. ADR-014 states "SLSA Level 2 provenance — `slsa-github-generator` produces a signed provenance attestation" — this capability does not work as documented.

**Recommendation:**

Move the SLSA provenance generation into a separate top-level job in the workflow. Add a note explaining that `generator_container_slsa3.yml` generates SLSA Level 2 provenance (not Level 3) unless specific isolated builder requirements are met, and link to the `slsa-github-generator` documentation on level requirements.

---

### ARCH-003
**Severity:** Critical
**Component:** Falco — custom rules
**Title:** `allowed_outbound_destinations_map` is undefined — the outbound connection rule will fail to load

**Finding:**

The custom Falco rule "Unexpected Outbound Connection from Security Namespace" (lines 841–852 of the document) contains:

```yaml
    condition: >
      outbound and
      container and
      k8s.ns.name in (defectdojo, nexus) and
      not fd.sip.name in (allowed_outbound_destinations_map)
```

The macro `allowed_outbound_destinations_map` does not exist in Falco's default rule set and is not defined anywhere in the custom rules block provided. Falco rule compilation fails on undefined macros or lists — the entire custom rules file will fail to load, silently disabling all four custom rules including the shell-spawn and kubectl-exec rules.

The correct Falco syntax for an allowlist would be a `list` definition followed by an `in` check:

```yaml
- list: allowed_outbound_destinations
  items: ["kube-dns", "metrics-server"]

- rule: Unexpected Outbound Connection from Security Namespace
  condition: >
    outbound and container and
    k8s.ns.name in (defectdojo, nexus) and
    not fd.sip.name in (allowed_outbound_destinations)
```

Additionally, `fd.sip.name` performs a reverse DNS lookup on the destination IP. In practice, most outbound connections from DefectDojo and Nexus (e.g., to GitHub for update checks, to upstream package registries) will not have stable reverse DNS names in all environments. A list-based IP allowlist (`fd.rip`) is more reliable, though it requires more upfront configuration.

**Consequence:**

A developer who deploys this configuration will have Falco running with zero custom rules active. The DaemonSet will be healthy, the FalcoSidekick UI will be accessible, and there will be no indication that the rules failed to load unless the developer inspects Falco logs specifically for compilation errors. The document's verification step (`kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=50`) would reveal the error, but the document does not instruct the reader to look for rule compilation errors specifically. The "verify Falco is running" guidance checks pod health, not rule load status.

**Recommendation:**

Define `allowed_outbound_destinations` as a Falco `list` in the custom rules block. Add a verification step to the Falco deployment instructions: `kubectl logs -n falco-system -l app.kubernetes.io/name=falco | grep -E "Error|Warning|rule"` to surface rule compilation failures explicitly. Note that the allowlist requires site-specific tuning.

---

### ARCH-004
**Severity:** High
**Component:** Falco — `kubectl exec` rule
**Title:** The k8s_audit source rule requires audit log plugin configuration that the document does not adequately explain

**Finding:**

The rule "kubectl exec into Security Namespace" uses `source: k8s_audit`. This source requires:

1. The Kubernetes API server configured with an audit webhook pointing to Falco's audit endpoint
2. The Falco `k8saudit` plugin installed and enabled
3. The `falco-values.yaml` must explicitly enable the k8saudit plugin

None of these three requirements are represented in the `falco-values.yaml` provided in the document. The document contains only:

```yaml
driver:
  kind: ebpf

falcosidekick:
  enabled: true
  ...

customRules:
  ...
```

The k8saudit plugin is not enabled in this values file. Without it, any rule using `source: k8s_audit` is silently ignored — it does not generate a load error, it simply never fires. This compounds with ARCH-003: even if the custom rules file loads correctly, the kubectl-exec rule will never produce an alert regardless of how many times a developer execs into a security namespace pod.

The document does say: "The Kubernetes audit log plugin requires cluster-level configuration (API server audit webhook) that is provider-specific — the document describes the requirement but cannot provide a universal configuration." However, it does not explain that the Falco Helm chart itself also needs configuration to activate the plugin, nor does it note that the kubectl-exec rule is effectively non-functional without this configuration.

**Consequence:**

One of the four custom rules — the one covering the most operationally-relevant threat for this stack (administrative access to security tool pods via kubectl exec) — is inert as deployed. The document's verification test (`kubectl exec test-pod -- ls /etc`) tests the syscall-based rules, not the k8s_audit-based rules, so the test passes even when kubectl-exec detection is broken.

**Recommendation:**

Add the k8saudit plugin configuration to `falco-values.yaml`:

```yaml
plugins:
  - name: k8saudit
    library_path: libk8saudit.so
    init_config:
      maxEventSize: 262144
    open_params: "http://:9765/k8s-audit"
  - name: json
    library_path: libjson.so

load_plugins: [k8saudit, json]
```

Add a note that the kubectl-exec rule requires both the Falco plugin AND the API server audit webhook to be configured, and that the rule is inert without both. Provide a separate verification step specifically for k8s_audit: trigger a `kubectl exec` after both are configured and confirm the rule fires.

---

### ARCH-005
**Severity:** High
**Component:** Falco — eBPF driver
**Title:** `driver.kind: ebpf` assumption is unsafe on managed K8s providers and older kernels

**Finding:**

The `falco-values.yaml` specifies `driver.kind: ebpf` with the comment "preferred; falls back to kernel module if eBPF unavailable." The ADR-013 describes this as "eBPF driver (preferred; falls back to kernel module)." This fallback description is not accurate for how Falco Helm chart v4.x works in practice.

The Falco Helm chart does not automatically fall back from eBPF to the kernel module. `driver.kind` is a static configuration value. If `ebpf` is specified and the eBPF probe cannot be loaded (kernel < 4.14, locked-down secure boot, managed K8s provider that restricts eBPF such as EKS Fargate, GKE Autopilot, or hardened node pools), the Falco DaemonSet pods will enter `CrashLoopBackOff`. Falco will appear to be running from a pod count perspective, but no syscall events will be captured.

On AWS EKS standard nodes (EC2-based), eBPF typically works but requires kernel >= 5.8 for the modern eBPF probe. On EKS Fargate, Falco cannot run at all — Fargate nodes do not permit DaemonSets or privileged containers.

**Consequence:**

A developer deploying to a managed K8s environment where eBPF is restricted will see Falco pods in `CrashLoopBackOff` or in a running state that captures no events. The document's verification step checks `kubectl get pods -n falco-system` (pod status) but does not verify that events are actually being captured. The developer may believe Falco is operational when it is not.

**Recommendation:**

Remove the fallback claim from both the document text and the ADR. Document that eBPF requires kernel >= 5.8 (for the modern probe) or >= 4.14 (for the legacy probe). Note that EKS Fargate, GKE Autopilot, and other serverless-node managed offerings do not support Falco at all. For environments where eBPF is unavailable, specify `driver.kind: kmod` with the caveat that the kernel module approach requires matching kernel headers at install time. The auto-detection option (`driver.kind: auto`) is available in Falco Helm chart v4.x and is a better default for a reference document.

---

### ARCH-006
**Severity:** High
**Component:** Cosign/SLSA — `docker inspect` digest extraction
**Title:** `docker inspect --format='{{index .RepoDigests 0}}'` may return an empty string or local image ID

**Finding:**

The "Build and push image" step in the `sign` job extracts the registry digest with:

```bash
DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE}" | cut -d@ -f2)
```

`docker inspect` returns `RepoDigests` only after an image has been pulled from or pushed to a registry and the registry digest has been returned. Immediately after `docker push`, this field should be populated — but its availability depends on the Docker daemon version and the registry implementation. If the push succeeds but the registry returns a `202 Accepted` without a digest in the response headers (as some registries do under load or with certain authentication configurations), `RepoDigests` will be empty or contain the local content-addressable digest rather than the registry digest.

If `RepoDigests` is empty, `index .RepoDigests 0` produces an empty string or a template error. The `cut -d@ -f2` then produces an empty string. The `cosign sign` command then receives `"${IMAGE}@"` which is an invalid reference and will fail. However, if the step does not have `set -e` or explicit error checking (the document does not show `set -euo pipefail`), the failure may be silent and the DIGEST output may be empty, causing `cosign sign` to attempt signing the image by tag rather than by digest — which is a weaker security posture (tags are mutable).

**Consequence:**

The signing step may operate on a mutable tag reference rather than an immutable digest reference, which defeats the purpose of digest-pinned signing. The Kyverno admission control verifies signatures against the digest in the attestation; if the attestation was created against a mutable tag, the verification semantics differ.

**Recommendation:**

Use `docker buildx build --push` with `--metadata-file` to capture the digest directly from the build+push output, which is more reliable:

```bash
docker buildx build --push \
  --metadata-file metadata.json \
  -t "${IMAGE}" .
DIGEST=$(jq -r '."containerimage.digest"' metadata.json)
```

Alternatively, use `crane digest "${IMAGE}"` after the push, which queries the registry directly. Add `set -euo pipefail` at the top of the run block to ensure the step fails loudly if digest extraction returns empty.

---

### ARCH-007
**Severity:** High
**Component:** Kyverno — admission control single point of failure
**Title:** `replicaCount: 1` with `validationFailureAction: Enforce` creates a cluster-wide admission control outage on pod crash

**Finding:**

The `kyverno-values.yaml` specifies `replicaCount: 1`. The document notes "Increase to 3 for production HA" in a comment. The ClusterPolicy uses `validationFailureAction: Enforce`.

Kyverno runs as a Kubernetes admission webhook. When `failurePolicy` is set to `Fail` (Kyverno's default), and the Kyverno webhook endpoint is unavailable (because the single pod has crashed, is being evicted, or is being updated), all pod admission requests in namespaces covered by the policy will fail. New pods cannot be scheduled, existing pods that are deleted cannot be recreated, and rolling deployments will stall cluster-wide.

The document does not state what Kyverno's default `failurePolicy` is. It does not explain the consequence of a single-replica admission webhook being unavailable. The `replicaCount: 1` comment "Increase to 3 for production HA" implies this is an optimization; it is actually a correctness and availability requirement for any `Enforce` mode policy in a production or staging context.

**Consequence:**

During a Kyverno pod restart (which happens during Helm upgrades, node evictions, or OOM conditions), the cluster cannot schedule any new pods in the covered namespaces. If a developer is simultaneously deploying an application to `production` namespace while Kyverno is restarting, the deployment will stall. More seriously: if the Kyverno pod crashes and does not recover, the cluster is effectively frozen for new workloads in production/staging until Kyverno is restored. This is a self-inflicted denial of service from the security tooling itself.

**Recommendation:**

Change `replicaCount` to 3 in the reference `kyverno-values.yaml`, or document that `replicaCount: 1` must not be used with `Enforce` mode policies in namespaces where workload scheduling availability matters. Add an explicit note explaining the `failurePolicy: Fail` default and its consequences. The rollout recommendation should state: "Do not switch from Audit to Enforce until Kyverno has at least 3 replicas."

---

### ARCH-008
**Severity:** High
**Component:** Falco — Falco/DefectDojo integration gap
**Title:** Falco alerts go to Slack/FalcoSidekick but not to DefectDojo — the unified dashboard claim is broken for runtime alerts

**Finding:**

The document states in multiple places that DefectDojo is the "unified dashboard" for the security stack. The Data Flow Summary and Viewing Results table show all findings going to DefectDojo. The Phase 4 deliverables say: "All optional service findings feeding into DefectDojo."

However, Falco alerts are sent via FalcoSidekick to Slack or a generic webhook (Alertmanager). There is no FalcoSidekick output configured for DefectDojo, and DefectDojo does not have a native Falco event parser. The document provides no mechanism for Falco runtime alerts to appear in DefectDojo.

The Viewing Results table does not include a row for "Runtime anomaly alerts" or "Falco alerts." This is an omission in the results table, but the broader claim that "All optional service findings feeding into DefectDojo" (Phase 4 deliverables) is inaccurate as written.

FalcoSidekick does support a generic webhook output that could theoretically post to DefectDojo's generic API, but DefectDojo does not have a Falco scan type parser — importing Falco JSON into DefectDojo would require a custom parser or a manual integration step that is not described anywhere in the document.

**Consequence:**

A developer who builds this stack expecting Falco runtime events to appear in the DefectDojo unified dashboard alongside Semgrep, Trivy, and Grype findings will be disappointed. The DefectDojo dashboard will not show runtime anomalies. Falco alerts will exist only in the FalcoSidekick UI and Slack. The split-brain result dashboard undermines the "single pane of glass" framing.

**Recommendation:**

One of the following corrections is needed:
1. Explicitly document that Falco runtime alerts are out-of-band from DefectDojo and will only appear in FalcoSidekick/Slack. Update the "unified dashboard" framing accordingly.
2. Add FalcoSidekick webhook integration guidance that formats Falco alerts into DefectDojo's generic findings import format, with a note that this requires a custom integration script.
3. Update the Phase 4 deliverables list to remove "All optional service findings feeding into DefectDojo" and replace it with a more accurate per-tool statement.

---

### ARCH-009
**Severity:** High
**Component:** Falco — verification test
**Title:** The verification test does not test the security namespace rules — it tests a different namespace

**Finding:**

The document's verification step is:

```bash
# Trigger a test alert — exec into a non-security pod to confirm rules fire
kubectl run test-pod --image=alpine --restart=Never -- sleep 60
kubectl exec test-pod -- ls /etc
# → Should appear in Falco logs as a write/exec event
```

The comment says "exec into a non-security pod." The custom shell-spawn rule fires only when `k8s.ns.name in (defectdojo, nexus, falco-system, kyverno, trivy-system)`. Running the test pod in the default namespace will not trigger the "Shell Spawned in Security Namespace Pod" rule. It may trigger Falco's built-in rules (e.g., `Launch Package Management Process in Container`), but it will not verify that the custom rules are working.

Furthermore, `kubectl exec test-pod -- ls /etc` is not executing a shell binary (`sh`, `bash`, `zsh`). The `ls` binary does not match `proc.name in (shell_binaries)`. The test would not trigger the shell-spawn rule even if it were run in the correct namespace.

The "write/exec event" comment implies the Write-to-/etc rule fires. `ls /etc` is a read, not a write. No write to /etc occurs. This test would not trigger the "Write to /etc in Container" rule either.

The net result: the verification test produces output (Falco's built-in rules may fire on `ls` inside a container) that looks like confirmation the system works, but none of the custom rules have been verified.

**Consequence:**

A developer following the verification steps will observe Falco log output and conclude the custom rules are working. They are not. The security namespace rules are unverified, and as noted in ARCH-004, the kubectl-exec rule is structurally inert without additional configuration. The verification creates false confidence.

**Recommendation:**

Replace the verification test with rule-specific tests:

```bash
# Test shell-spawn rule: run a shell inside a security namespace pod
kubectl exec -n defectdojo deployment/defectdojo-django -- /bin/sh -c "id"
# → Should fire "Shell Spawned in Security Namespace Pod"

# Test write-to-/etc rule: attempt a write to /etc (this will likely fail due to
# read-only filesystem but Falco detects the syscall attempt)
kubectl exec -n defectdojo deployment/defectdojo-django -- \
  /bin/sh -c "touch /etc/test-falco 2>/dev/null || true"
# → Should fire "Write to /etc in Container"
```

Note that the kubectl-exec rule requires separate verification after the k8s_audit plugin is configured (see ARCH-004).

---

### ARCH-010
**Severity:** Medium
**Component:** Kyverno — `background: false` policy behavior for existing pods
**Title:** `background: false` means the policy does not scan existing pods — pre-existing unsigned images are never reported

**Finding:**

The ClusterPolicy specifies `background: false`. In Kyverno, `background: false` disables background scanning of existing resources. This means:

- Pods already running in `production` or `staging` namespaces when the policy is applied are never evaluated
- The `kubectl get policyreport -A` command (the recommended audit step before switching to `Enforce`) will show zero violations for any existing unsigned images — not because those images are signed, but because background scanning is disabled and they were never evaluated
- The Audit-then-Enforce rollout recommendation is therefore broken: a developer following the document will run `kubectl get policyreport -A`, see no violations, and switch to `Enforce` mode, only to have Kyverno begin blocking deployments of images that were already running unsigned

**Consequence:**

The Audit-to-Enforce rollout recommendation, which is presented as the safe way to roll out admission control, is unreliable with `background: false`. The audit period provides false assurance that no unsigned images are in use.

**Recommendation:**

Change `background: false` to `background: true` in the ClusterPolicy, or add a prominent note explaining what `background: false` means: "With `background: false`, the policy report will not include existing pods — it only surfaces violations from new admission requests during the audit window. To get a complete picture of unsigned image usage before switching to Enforce, set `background: true` during the audit period, or audit existing deployments manually with `cosign verify` against each running image."

---

### ARCH-011
**Severity:** Medium
**Component:** Kyverno — ClusterPolicy glob pattern
**Title:** `"ghcr.io/<org>/*"` is a placeholder that will not match any real image — policy will fail to enforce correctly until edited

**Finding:**

The ClusterPolicy `imageReferences` contains:

```yaml
        - imageReferences:
            - "ghcr.io/<org>/*"
```

This is a literal placeholder string. If a developer applies this YAML without substituting `<org>` with their actual GitHub organization name, Kyverno will apply the signature verification rule only to images matching the literal pattern `ghcr.io/<org>/*` — which will never match any real image. The policy will appear to be in Enforce mode but will silently pass all images because none match the pattern.

The document does not include a note that `<org>` must be replaced before applying. Other placeholder substitutions in the document (e.g., `<SHA>` in action references) are consistently noted. This one is not.

**Consequence:**

A developer who applies the ClusterPolicy verbatim will believe they have image signing enforcement active. They do not. Unsigned images will be admitted to production namespaces without warning. The test step (`kubectl run unsigned-test --image=alpine:latest -n production`) will also not be blocked because `alpine:latest` does not match `ghcr.io/<org>/*` — so the test will appear to show the policy working (alpine runs without a signature error) but for the wrong reason.

**Recommendation:**

Add an explicit pre-application note: "Replace `<org>` with your GitHub organization name before applying this policy. After substitution, verify the pattern using: `kubectl describe clusterpolicy require-signed-images` and confirm the imageReferences field shows your organization name." Alternatively, document that the test step should use an image that matches the intended pattern, not `alpine:latest`.

---

### ARCH-012
**Severity:** Medium
**Component:** Cosign/SLSA — Rekor privacy and availability
**Title:** The document does not address Rekor public log privacy implications or Rekor unavailability

**Finding:**

The document says keyless signing "relies on Rekor (public transparency log)" but does not explain two significant operational implications:

1. **Privacy:** Every `cosign sign` invocation publishes the image digest, the signing certificate (which contains the GitHub repository URL, the workflow path, and the OIDC subject), and a timestamp to the public Rekor log at `rekor.sigstore.dev`. This information is permanently public and cannot be deleted. For a developer working on private repositories, this means repository names and internal workflow paths are disclosed to the public internet on every push to main. The document's claim "All tools are free, open-source, and require no sign-ups, logins, or authentication to any external service" is accurate for authentication, but does not disclose the data disclosure implication of publishing to a public log.

2. **Availability:** `cosign sign` and `cosign verify` both require network access to `rekor.sigstore.dev`. If Rekor is unavailable (outage, DNS failure, egress restriction), the `sign` job will fail. The Kyverno policy, if configured with `rekor.url`, will also fail to verify signatures at admission time if Rekor is unreachable. This creates an operational dependency on an external public service for cluster admission control — a pod cannot be scheduled if Rekor is down and Kyverno cannot verify the signature.

ADR-014 claims the "no key management burden" advantage but does not acknowledge this tradeoff: you exchange key management burden for an external service dependency in your admission control path.

**Consequence:**

A developer who deploys this without understanding the Rekor dependency will face cluster admission failures during Rekor outages. A developer who does not understand the public log disclosure will inadvertently publish their private repository metadata to a public transparency log.

**Recommendation:**

Add a "Rekor considerations" note in section 12 covering:
- What data is published to the public Rekor log on every signing operation
- The operational dependency: if Rekor is unavailable, the sign job fails and Kyverno admission may fail
- That `cosign sign --insecure-skip-verify` or a private Rekor instance are alternatives for environments with egress restrictions or strict privacy requirements

---

### ARCH-013
**Severity:** Medium
**Component:** Kyverno — Helm chart name
**Title:** `kyverno/kyverno` Helm chart name changed in Kyverno v3.x — the reference may install the wrong chart

**Finding:**

The document installs Kyverno with:

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno \
  --namespace kyverno ...
```

As of Kyverno v3.x (released in 2024 and the current major version as of early 2026), the Helm chart is named `kyverno/kyverno` but the chart repository was reorganized. More importantly, Kyverno v3.x changed the CRD API version for `ClusterPolicy` from `kyverno.io/v1` to `kyverno.io/v2beta1` for `verifyImages` with significant schema changes. The `verifyImages` field structure in the ClusterPolicy shown in the document uses the v1 syntax.

Specifically, in Kyverno v3.x, the `verifyImages` block structure changed: `attestors` with nested `entries` using `keyless:` is the v1/v2beta1 syntax. The current v3.x syntax for the same policy uses a different structure under the `spec.rules[].verifyImages` field.

I am not certain of the exact schema change details without running both versions — but the risk is real enough to flag: the ClusterPolicy in the document may not apply correctly to a Kyverno v3.x installation, and the document does not specify a Kyverno version.

**Consequence:**

A developer installing the current Kyverno release and applying the ClusterPolicy may encounter CRD validation errors, or the policy may apply but not function as expected because the `verifyImages` attestor syntax has changed.

**Recommendation:**

Add a Kyverno version pin to the Helm install command. Specify the minimum Kyverno version the ClusterPolicy has been tested against. Link to the Kyverno migration guide for v2.x → v3.x CRD changes.

---

### ARCH-014
**Severity:** Medium
**Component:** ADR-013 — Falco operational complexity claim
**Title:** "80% of runtime detection value at 20% of operational complexity" is not supportable for a developer new to Falco

**Finding:**

ADR-013 states: "For a single-developer practice, Falco provides 80% of the runtime detection value at 20% of the operational complexity."

This claim is not supported by evidence in the ADR. The four custom rules in the document are narrow (shell spawn in specific namespaces, kubectl exec, outbound connections, writes to /etc). These are valuable detection rules, but:

- Falco's default rule set generates substantial false positives in typical Kubernetes environments (legitimate container management operations, package manager invocations, init processes that look like shell spawns). A developer who has never tuned Falco rules will spend significant time either silencing noise or ignoring alerts — a situation indistinguishable from having no detection.
- Rule tuning requires understanding of Falco's field names, the macro/list/rule structure, the difference between syscall sources and audit sources, and familiarity with the Falco rule language. This is non-trivial for someone deploying Falco for the first time.
- The document acknowledges this briefly: "Custom rule tuning is required to suppress false positives from legitimate tooling behavior." But the framing "80% of value at 20% of complexity" implies Falco is easy. It is not easy to operate correctly.

The 80/20 framing creates an expectation that Falco will immediately provide actionable alerts with minimal tuning. A more honest framing is: "Falco provides meaningful runtime detection coverage once the initial false positive tuning is complete. Expect 4–8 hours of initial rule tuning before the alert stream becomes actionable."

**Consequence:**

A developer who deploys Falco expecting low operational burden will encounter high false positive rates from default rules (e.g., every Helm chart install or kubectl command on the node will trigger rules), lose confidence in Falco, and either disable the custom rules or stop reviewing alerts. The resulting state is worse than no Falco: the developer believes they have runtime detection when they do not.

**Recommendation:**

Replace the 80/20 claim with a realistic estimate of initial tuning effort. Recommend that the developer deploy Falco with `priority: WARNING` on custom rules but `priority: DEBUG` on default rules initially, or use the Falco rule set filtering (`falco.rules_file`) to load only the custom rules during the initial tuning period.

---

### ARCH-015
**Severity:** Medium
**Component:** ADR-014 — "no structural changes to existing pipeline" claim
**Title:** ADR-014's claim of no structural changes is inaccurate — the sign job adds a full image rebuild

**Finding:**

ADR-014 states: "The SLSA pipeline restructuring objection was also overstated for Level 2: `slsa-github-generator` implements SLSA Level 2 provenance as a reusable workflow — it requires no structural changes to the existing pipeline, only an additional job declaration."

And: "The entire signing workflow is three lines added to an existing GitHub Actions job."

The implemented workflow shows a full new job with six steps including a complete `docker build` and `docker push`. This is not "three lines" and it is not "no structural changes." The container job also required changes to output the image digest for the sign job to consume (or should have — see ARCH-001 for why it does not). The statement in the ADR is inaccurate relative to the implementation.

**Consequence:**

The ADR establishes the rationale for accepting the implementation. An inaccurate ADR rationale means the implementation was not properly evaluated against the objection it claims to address. The SLSA pipeline restructuring concern (from the original gap analysis) was about isolated build environments, not about pipeline complexity — and the ADR's rebuttal does not fully engage with that concern.

**Recommendation:**

Correct ADR-014 to accurately describe what was implemented: a new job with a full image rebuild and push. Separately address the SLSA Level 2 vs Level 3 distinction and whether the `generator_container_slsa3.yml` workflow (when invoked correctly as a separate job) achieves Level 2 or Level 3.

---

### ARCH-016
**Severity:** Low
**Component:** FalcoSidekick — blank alert destinations
**Title:** Blank `webhookurl` and `address` fields in FalcoSidekick config result in zero alert delivery, but the document does not explain this

**Finding:**

The `falco-values.yaml` shows:

```yaml
    slack:
      webhookurl: ""          # Set to your Slack incoming webhook URL, or leave blank
    webhook:
      address: ""             # Generic webhook endpoint (e.g. Alertmanager)
```

If both fields are blank, FalcoSidekick starts successfully and accepts events from Falco, but delivers zero alerts to any destination. Alerts are dropped silently. The FalcoSidekick web UI will show events (if the web UI is accessible), but nothing is delivered externally. The comment "or leave blank" does not explain the consequence of leaving blank: no alerts will be received anywhere except the web UI.

**Consequence:**

A developer who deploys this configuration without a Slack webhook will believe FalcoSidekick is routing alerts when it is not. The only way to see Falco alerts is to port-forward the web UI, which is not a sustainable operational model.

**Recommendation:**

Change the comment to: "If both destinations are left blank, alerts are only visible in the FalcoSidekick web UI (port 2802) and are not delivered anywhere persistently. At minimum, configure one destination before relying on Falco for operational alerting."

---

### ARCH-017
**Severity:** Low
**Component:** Falco — resource estimates
**Title:** 512Mi per node is a minimum, not a typical operating value for eBPF Falco on a loaded node

**Finding:**

The K8s Services Summary table lists Falco as "512 Mi per node (DaemonSet)" and the Core stack estimate includes "+Falco DaemonSet overhead per node."

512Mi is the `requests.memory` value appropriate for small clusters with low syscall volume. On a node running multiple active workloads, Falco's eBPF probe processes every syscall on every process on the node — the actual memory consumption scales with syscall throughput. In practice, Falco on an active production node typically uses 200–400Mi at rest, but can spike to 1–2Gi under high syscall load (e.g., during a CI build running on the same node, or when Nexus is actively proxying packages). Setting `requests.memory: 512Mi` with no `limits.memory` means Kubernetes will not constrain Falco's memory, which can lead to OOM conditions on memory-constrained nodes.

**Consequence:**

Minor: a developer on a resource-constrained single-node cluster may encounter OOM pressure from Falco during peak load. The 512Mi figure in the table may underrepresent actual cluster capacity requirements.

**Recommendation:**

Note that 512Mi is the minimum request, not the typical working set, and that Falco should have a memory limit configured. Suggest `limits.memory: 1Gi` as a starting value for a single-node development cluster.

---

### ARCH-018
**Severity:** Low
**Component:** Cosign/SLSA — `REGISTRY_PASSWORD` secret documentation
**Title:** `REGISTRY_PASSWORD` is used in the `sign` job but is not documented anywhere in the document

**Finding:**

The `sign` job uses `${{ secrets.REGISTRY_PASSWORD }}` in two places: the `docker login` step and the `registry-password` field of the SLSA provenance step. The existing workflow uses `DEFECTDOJO_API_TOKEN` which is documented in the DefectDojo section with explicit setup instructions: "Settings → Secrets and variables → Actions → New repository secret."

`REGISTRY_PASSWORD` has no equivalent documentation. There is no mention of what registry this refers to, whether it is a GitHub personal access token (PAT) with `write:packages` scope or a registry-specific credential, or how to create it.

**Consequence:**

A developer following the document will encounter authentication failure in the sign job without knowing what secret to create or what value to use.

**Recommendation:**

Add a setup note in section 12: "Before the `sign` job can run, create a GitHub repository secret named `REGISTRY_PASSWORD` containing a GitHub personal access token (classic) with `write:packages` scope, or a GitHub Actions fine-grained token with packages write permission. For GHCR, the `GITHUB_TOKEN` automatically provided by GitHub Actions typically has `packages: write` permission — if so, you can replace `secrets.REGISTRY_PASSWORD` with `secrets.GITHUB_TOKEN` and remove the separate secret."

---

### ARCH-019
**Severity:** Info
**Component:** Kyverno — `kubectl get policyreport -A` vs v2.x API
**Title:** `kubectl get policyreport -A` is correct for Kyverno v2.x but the resource name changed

**Finding:**

The document recommends: `kubectl get policyreport -A` to check audit results. In Kyverno v1.x the resource was `policyreport`. In Kyverno v2.x+ (using the Wgpolicyk8s API), the resource name remains `policyreport` but the API group changed to `wgpolicyk8s.io/v1alpha2`. The command `kubectl get policyreport -A` continues to work if the CRD is installed, but the full qualified form is `kubectl get policyreport.wgpolicyk8s.io -A`. This is a minor technical note, not a defect — the short form works.

**Recommendation:**

No change required. Informational only.

---

## 3. Risk Summary Table

| ID | Severity | Component | Title |
|----|----------|-----------|-------|
| ARCH-001 | Critical | Cosign/SLSA — `sign` job | Signed image is not the scanned image — sign job rebuilds Docker from scratch |
| ARCH-002 | Critical | Cosign/SLSA — SLSA provenance step | `slsa-github-generator` reusable workflow used inside `steps:` block — invalid syntax |
| ARCH-003 | Critical | Falco — custom rules | `allowed_outbound_destinations_map` is undefined — outbound rule causes load failure, disabling all custom rules |
| ARCH-004 | High | Falco — kubectl exec rule | k8s_audit source requires plugin + API server webhook configuration absent from values.yaml |
| ARCH-005 | High | Falco — eBPF driver | eBPF fallback claim is inaccurate; managed K8s providers may not support eBPF |
| ARCH-006 | High | Cosign/SLSA — digest extraction | `docker inspect RepoDigests` may return empty string; digest may be missing or wrong |
| ARCH-007 | High | Kyverno — HA | `replicaCount: 1` with Enforce mode is a cluster-wide admission control single point of failure |
| ARCH-008 | High | Falco — DefectDojo gap | Falco alerts go to Slack/FalcoSidekick only; DefectDojo unified dashboard claim is broken for runtime events |
| ARCH-009 | High | Falco — verification | Verification test does not test the custom security namespace rules; creates false confidence |
| ARCH-010 | Medium | Kyverno — background scanning | `background: false` makes audit mode unreliable for detecting pre-existing unsigned images |
| ARCH-011 | Medium | Kyverno — ClusterPolicy glob | `ghcr.io/<org>/*` is an unsubstituted placeholder that silently passes all images |
| ARCH-012 | Medium | Cosign/SLSA — Rekor | Rekor public log privacy implications and availability dependency not documented |
| ARCH-013 | Medium | Kyverno — chart naming | Kyverno v3.x CRD schema changes may break the ClusterPolicy as written |
| ARCH-014 | Medium | ADR-013 — complexity claim | "80% value at 20% complexity" claim is unsupported and likely to create unrealistic expectations |
| ARCH-015 | Medium | ADR-014 — pipeline claim | "No structural changes" and "three lines" claims are inaccurate relative to the implementation |
| ARCH-016 | Low | FalcoSidekick — blank config | Blank webhook URLs result in silent alert discard with no documentation of consequence |
| ARCH-017 | Low | Falco — resource estimates | 512Mi per node is a minimum, not typical; memory limits not specified |
| ARCH-018 | Low | Cosign/SLSA — secrets | `REGISTRY_PASSWORD` secret used in workflow but not documented |
| ARCH-019 | Info | Kyverno — policyreport | `kubectl get policyreport -A` API group changed in v2.x; short form still works |

---

## 4. Verdict

**This addition is not ready to ship as written.** The three Critical findings (ARCH-001, ARCH-002, ARCH-003) each independently produce an implementation that is broken or dangerous. They are not minor inaccuracies:

- ARCH-001 means the signed image is not the scanned image — the core security guarantee of the Cosign section is structurally false.
- ARCH-002 means the SLSA provenance step is invalid syntax and will not execute; SLSA provenance will not be generated.
- ARCH-003 means all four custom Falco rules are disabled at load time due to an undefined macro reference.

A developer who follows this document exactly will end up with:
- Kyverno enforcing that images were signed by CI, but not that they were scanned
- No SLSA provenance attestations
- Falco running with zero custom rules active and a verification test that appears to pass
- Kyverno admission control operating on an unsubstituted placeholder pattern that matches no real images

**Blockers (must fix before use):**

ARCH-001, ARCH-002, ARCH-003 are blockers. ARCH-007 (single-replica Kyverno in Enforce mode) should also be treated as a blocker for any environment where the `production` or `staging` namespace is actively used.

**High-priority improvements (should fix before use):**

ARCH-004, ARCH-005, ARCH-006, ARCH-008, ARCH-009 should be addressed before a developer invests time deploying this section. The kubectl-exec rule is inert (ARCH-004), the verification creates false confidence (ARCH-009), and the DefectDojo integration gap (ARCH-008) means the "unified dashboard" promise is broken for runtime events.

**Medium improvements (fix before treating as production-grade):**

ARCH-010 through ARCH-015 should be addressed before switching Kyverno to Enforce mode or treating this as a complete implementation.

The architectural decisions in ADR-013 and ADR-014 are sound at the conceptual level — keyless Cosign is the right choice, Kyverno is the right admission controller, and Falco is the right runtime detection tool for this scale. The failure is in the implementation details: the workflow construction, the Falco rule syntax, and several claims in the ADRs that are contradicted by the code they describe.
