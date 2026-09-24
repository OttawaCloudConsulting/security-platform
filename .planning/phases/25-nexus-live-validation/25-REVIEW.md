---
phase: 25-nexus-live-validation
reviewed: 2026-09-24T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - repos/security-platform/scripts/nexus-homelab-validate.sh
  - repos/security-platform/kubernetes/nexus/README.md
  - occ-k8s-app-config:application-sets/automation/argocd/templates/projects.yaml
  - occ-k8s-app-config:application-sets/platform/nexus/argocd-overrides.yaml
  - occ-k8s-app-config:application-sets/platform/nexus/Chart.yaml
  - occ-k8s-app-config:application-sets/platform/nexus/README.md
  - occ-k8s-app-config:application-sets/platform/nexus/templates/sealedsecret-nexus-admin.yaml
  - occ-k8s-app-config:.gitleaksignore
  - docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md
  - docs/adr/README.md
findings:
  critical: 0
  warning: 5
  info: 11
  total: 16
status: issues_found
---

# Phase 25: Code Review Report

**Reviewed:** 2026-09-24
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Scope covered three repositories:
- security-platform: `aed14b9..61589d5`, which adds the live gate script and edits the chart README.
- occ-k8s-app-config: PR #239 (`7b7e25c`, the NEXUS-05 additions to `projects.yaml` only) and PR #241 (`a05471b`, the `platform/nexus` directory and `.gitleaksignore`). The on-disk overlay files are identical to `origin/main`; the checkout was on an unrelated feature branch.
- This docs repo: ADR-022 and the ADR index row.

The SealedSecret was read with its ciphertext redacted. It was not decrypted.

**Overall:** I found no false-pass path in `nexus-homelab-validate.sh`. Every verdict comes from a measured value, the transport, status and size verdicts are kept separate, and a failure cannot be scored as a pass. The findings below are about how the gate behaves when it is run in a different state or configuration than the one measured live:
- a sync that is still running;
- a provisioning Job that failed;
- a machine without kubectl;
- a non-default release name.

The remaining findings are about the admin credential passing through curl's argv, and small accuracy gaps in the documents.

**Spot-checks that held:**
- The overlay's `sources[0].repoURL` is byte-identical to the new `platform` `sourceRepos` entry.
- `.gitleaksignore:99` points at line 28 of the SealedSecret, which is the `password:` line under `spec.encryptedData`.
- ADR-022's claim that `job-provision.yaml` is the same blob before and after PR #16 holds (`929bc35f` at both `aed14b9` and `61589d5`).
- Every `kubectl` invocation in the script pins `--context "$KUBE_CONTEXT"` on the same line.
- The ADR's pass counts (17 on the first pass, 18 on the second) match the script's `pass` sites.

No structural findings (fallow) were supplied for this review.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: ARGOCD-HOOK-PHASE runs before the Job wait, so the advertised 900s tolerance for a still-running Job never takes effect

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:20-23, 358-361, 480-483, 394`
**Issue:** The header (lines 20-23) says the gate tolerates a provisioning Job that is still running, and waits up to 900s for it. But `check_argocd_hook_phase` runs first (line 481). It fails whenever `hookPhase != "Succeeded"` (line 358). In the middle of a sync, the Application's `operationState.syncResult` shows the hook as `Running`, or has no hook entry yet (then line 328 fails). So the gate goes red before the `kubectl wait` at line 394 runs. The wait then succeeds, but the run still exits 1 with a hook-phase failure that describes a timing issue, not a defect. The function also never checks `.status.operationState.phase`, so "operation still running" and "hook failed" produce the same message.
**Fix:** Call `check_provision_job` before `check_argocd_hook_phase` so the wait absorbs the in-flight sync. Alternatively, wait on the Application operation first:
```bash
kubectl --context "$KUBE_CONTEXT" -n "$ARGOCD_NS" wait applications.argoproj.io/"$APP_NAME" \
  --for=jsonpath='{.status.operationState.phase}'=Succeeded --timeout=900s
```
and name `operationState.phase` in the failure message when it is `Running`.

### WR-02: `kubectl wait --for=condition=complete` blocks for the full 900s when the provisioning Job has already failed

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:394`
**Issue:** The Job runs with `backoffLimit: 0` and `activeDeadlineSeconds`, so a provisioning failure is terminal at once: the Job gets `Failed=True` and will never get `Complete=True`. `kubectl wait --for=condition=complete` does not stop on the opposite condition. The gate therefore hangs for 15 minutes before it reports a failure it could have read straight away. This is the most likely failure mode on a bad overlay change, so the operator pays that cost when it matters most.
**Fix:** Before the wait, read the Job's terminal state and fail fast:
```bash
failed="$(kubectl --context "$KUBE_CONTEXT" -n "$NEXUS_NS" get job nexus-provision \
  -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)" || failed=""
if [ "$failed" = "True" ]; then
  fail "PROVISION-JOB-COMPLETE" "Job nexus-provision has condition Failed=True; see kubectl logs job/nexus-provision"
  # still fall through to the log capture below so PROVISION-JOB-REPOS reports the log
fi
```
(On kubectl 1.31 or later, `--for=condition=complete` combined with a jsonpath check, or a short poll loop over both conditions, also works.)

### WR-03: "kubectl is SOFT tier" is false against the deployed instance: without kubectl, DOCKER-REALM-ACTIVE hard-fails and the run exits 1

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:51-54, 275-283, 685, 699-701, 1102-1108`
**Issue:**
- The exit-code contract (lines 51-54) says that with kubectl absent, cluster-side checks become SKIPPED and the HTTP checks still run.
- ADR-022 (lines 84-89) records that the live instance answers the realms GET anonymously with 403.
- With kubectl absent, `ADMIN_PW_OK` stays 0, so `read_realms` (line 685) cannot fall back to admin, and DOCKER-REALM-ACTIVE fails at line 699. The same happens in SECOND-SYNC-IDEMPOTENT at lines 1106-1108.

The run exits 1 for a missing optional tool, not a defect. The preflight SKIPPED list at line 282 also does not name DOCKER-REALM-ACTIVE, even though it depends on the cluster credential. The failure message at line 700 does mention the Secret, but the check is recorded as a FAIL, not a SKIP.
**Fix:** In both realm consumers, record a named SKIP when the anonymous read returns 401 or 403 and no admin credential is available, instead of a FAIL:
```bash
if [ "$KUBECTL_OK" -ne 1 ] && { [ "$REALMS_CODE" = "401" ] || [ "$REALMS_CODE" = "403" ]; }; then
  SKIPPED+=("DOCKER-REALM-ACTIVE: realms list refused anonymously (HTTP ${REALMS_CODE}) and kubectl is absent, so no admin credential")
```
Also add DOCKER-REALM-ACTIVE to the list at line 282. The other option is to drop the soft-tier claim and make kubectl a hard-tier binary.

### WR-04: Live admin password passed on curl's command line

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:690, 1026, 1038`
**Issue:** `-u "admin:$NEXUS_PW"` puts the real, long-lived admin password for the homelab Nexus into curl's argv. Any local user or process can read it through `ps` or `/proc/<pid>/cmdline` while the call runs. curl's argv scrubbing is best-effort and leaves a race window. The header (lines 58-62) and the "Admin credential" block (lines 489-494) stress that the credential is never on argv and never echoed. That holds for the script's own argv but not for its child processes. The sibling scripts (`nexus-live-smoke.sh` lines 358/610/939/954, `provision.sh` lines 141/155) use the same pattern. In the smoke test the password is throwaway, and in `provision.sh` it is confined to a pod. Here it is a persistent credential on an operator workstation. Line 512 already names `-K -` as the alternative.
**Fix:** Send the credential through a curl config on stdin or a file descriptor:
```bash
curl -sS -o "$outfile" -w '%{http_code}' --connect-timeout 5 --max-time 30 \
  -K - "$REALMS_URL" <<<"user = \"admin:${NEXUS_PW}\""
```
(Or use `-K <(printf 'user = "admin:%s"\n' "$NEXUS_PW")`. Escape `"` and `\` in the password if the generator can produce them.) Wrap this in one `admin_curl` helper used by all three call sites.

### WR-05: Release-derived resource names are hardcoded even though namespace and app name are parameters

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:347, 379, 394, 396, 500, 1013`
**Issue:** The script exposes `--namespace` and `--app-name`, but hardcodes `nexus-provision`, `nexus-repos` and `nexus-admin`. The chart derives the first two from `nexus.fullname`, i.e. from the Helm release name (`_helpers.tpl:52-54`). The third comes from the overlay's `rootPassword.secret`. The chart README says renaming is supported (`nameOverride`/`fullnameOverride`). A second deployment with another release name, or `--app-name` pointed at a differently named Application, gets "no Job nexus-provision found" and ConfigMap errors. Those look like chart defects rather than a gate limitation.
**Fix:** Add `--release <name>` (default `nexus`) and derive `JOB_NAME="${RELEASE}-provision"` and `REPOS_CM="${RELEASE}-repos"`. Add `--admin-secret <name>` (default `nexus-admin`). At minimum, state in `usage()` that these names are fixed to release `nexus`.

## Info

### IN-01: SECOND-SYNC-IDEMPOTENT compares the realms to a hardcoded list, not to the pre-sync state; README says "unchanged"

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:1073, 1111`; `repos/security-platform/kubernetes/nexus/README.md` ("Validating an installed instance")
**Issue:** The check requires the realms to equal exactly `["NexusAuthenticatingRealm","DockerToken"]`, in that order. The README says it asserts "an unchanged realm list". The two claims differ:
- An operator who later enables another realm (LDAP, NpmToken) turns this check red even when the sync changed nothing.
- DOCKER-REALM-ACTIVE, by contrast, accepts extra realms.

The `already active` log-line assertion is the real "unchanged" signal.
**Fix:** Either compare against a snapshot taken by DOCKER-REALM-ACTIVE earlier in the same run, or reword the README and ADR to say "exactly the two-realm baseline".

### IN-02: Redundant assertion on `--sync-pass second`

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:404-416, 1086-1091`
**Issue:** On a second pass, PROVISION-JOB-REPOS already asserts exactly 4 `action=updated`, and SECOND-SYNC-IDEMPOTENT asserts it again. One cause produces two FAIL lines.
**Fix:** Drop the updated-count assertion from SECOND-SYNC-IDEMPOTENT. Keep only the `created == 0` and realms assertions there, and cite PROVISION-JOB-REPOS.

### IN-03: Check-label drift

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:282, 383, 389, 394, 1081`
**Issue:** The pass label is `PROVISION-JOB-COMPLETE-CONDITION` (line 394), but the fail messages, the SKIPPED text and the SECOND-SYNC-IDEMPOTENT cross-reference all say `PROVISION-JOB-COMPLETE`. Anyone grepping the output for one label misses the other.
**Fix:** Use a single label.

### IN-04: Duplicate SKIPPED entry when kubectl is absent

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:282, 1078`
**Issue:** The preflight SKIP already lists "the SECOND-SYNC-IDEMPOTENT log assertions", and line 1078 adds a second entry for the same sub-check. That inflates the SKIPPED count.
**Fix:** Remove one of the two entries.

### IN-05: DOCKER-PATH-SHAPE comments say "header-less", but both requests send an Accept header

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:644-649, 758-760, 766, 783`
**Issue:** The comments describe "deliberately header-less" requests, but lines 766 and 783 send `Accept: ${DOCKER_INDEX_ACCEPT}`. The ADR-021 claim that "a header-less manifest GET returns 200" is therefore not what this check measures.
**Fix:** Change the comment to "credential-less", or drop the `-H` if the header-less measurement is the one intended.

### IN-06: PVC check asserts every PVC in the namespace, not the Nexus claim

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:449-473`
**Issue:** Any unrelated PVC added to the namespace later, for example with an explicit storage class, makes NEXUS-03 fail. Default-class detection also ignores the legacy `storageclass.beta.kubernetes.io/is-default-class` annotation.
**Fix:** Select the PVC by label (`app.kubernetes.io/instance=<release>`) or by the name `data-<release>-nexus3-0`.

### IN-07: Anonymous-write probe misreports on a re-run after a real regression

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:996-1002`
**Issue:** If anonymous write was ever open, the first run creates `anon-write-probe` on the live instance. The next run then gets a 400 (duplicate name), and line 1000 says the body was "malformed". The readback at line 1043 does report the correct cause, but the first message is misleading.
**Fix:** When the POST returns 400, mention that a leftover `anon-write-probe` from an earlier regression also produces 400.

### IN-08: Blob GET follows redirects (`-L`), inherited from the smoke script

**File:** `repos/security-platform/scripts/nexus-homelab-validate.sh:928` (same as `nexus-live-smoke.sh:856`)
**Issue:** If Nexus ever answered a blob GET with a redirect to an upstream CDN, `size_download` would count bytes that never went through the proxy. The check would still pass while no longer proving the proxy served the layer. curl does not forward the Bearer header across hosts, so the credential does not leak.
**Fix:** Drop `-L`, or assert `%{num_redirects}` is 0 and `%{url_effective}` starts with `$NEXUS_HOST`.

### IN-09: The `platform` AppProject tradeoff in ADR-022 leaves out that destinations include `kube-system`, `argo` and `authentik`

**File:** `occ-k8s-app-config:application-sets/automation/argocd/templates/projects.yaml:283, 315-319, 364-376`; `docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md:166-171`
**Issue:**
- The new namespaced kinds (`batch/Job`, `apps/StatefulSet`, `bitnami.com/SealedSecret`) and the new `security-platform` source repo apply to every `platform` destination, including `kube-system`.
- A Job in `kube-system` can set `serviceAccountName` to any SA in that namespace.
- The extra risk is small, because the project already allowed `apps/Deployment`, `ClusterRole` and `ClusterRoleBinding`, so it was already cluster-admin-equivalent.
- The `sourceRepos` entry admits any path and revision of `security-platform`. The SHA pin exists only in this one override, not in the project.

The ADR's "shared AppProject is now wider" paragraph describes the kinds but not where they can land.
**Fix:** This is documentation only. Add a sentence to ADR-022 (or a follow-up ADR, since accepted ADRs are append-only) naming the destination set and that `sourceRepos` is not revision-scoped.

### IN-10: ADR-022 wording inaccuracies

**File:** `docs/adr/adr022-nexus-live-validation-via-argocd-overlay.md:33-36, 119, 145, 220-223`
**Issue:**
- (a) Line 35 states as fact that Argo CD ignores all Helm hook annotations on a resource that has an Argo hook annotation. Item 5 (lines 220-223) then lists "which source supplied BeforeHookCreation (Argo's default or the mapped `helm.sh/hook-delete-policy`)" as unverified. If the line-35 rule holds, the Helm delete-policy was ignored by definition. The two statements should be reconciled, or line 35 marked as the documented behaviour it is.
- (b) Line 119 says the ordering "relies on kubelet retrying the Secret mount". The provisioning Job reads the password through an env `secretKeyRef` (`job-provision.yaml:133-140`), which fails as `CreateContainerConfigError` and is retried. It is not a volume mount. Line 228 uses the correct error name.
- (c) Line 145 says every kubectl call pins `--context` "on its own line". The script says "on the same line as `kubectl`" (line 288), which is what the code does.

**Fix:** These are editorial. Because ADRs are append-only, record the corrections in an erratum or the next ADR.

### IN-11: Overlay `Chart.yaml` `appVersion` is hand-maintained and will drift from the pinned source

**File:** `occ-k8s-app-config:application-sets/platform/nexus/Chart.yaml:15-16`; `occ-k8s-app-config:application-sets/platform/nexus/README.md:19`
**Issue:** `appVersion: "3.96.0"` and the README's "Nexus 3.96.0 via nexus3 5.26.0" restate facts that are determined by `sources[0].targetRevision` in `argocd-overrides.yaml:51`. They will go stale silently the first time the SHA is moved (ADR-022 notes the pin is already one merge behind `main`).
**Fix:** Add a comment next to `targetRevision` in `argocd-overrides.yaml` saying `Chart.yaml appVersion` and the README table must move with it. Or add a conformance check that compares them with the pinned chart's `Chart.lock`.

---

_Reviewed: 2026-09-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
