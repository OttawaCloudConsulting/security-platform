#!/usr/bin/env bash
set -euo pipefail

# nexus-live-smoke.sh — the LIVE half of the Phase 23 evidence for the Nexus
# Helm chart (kubernetes/nexus).
#
# WHY THIS EXISTS. scripts/check-nexus-chart.sh decides every invariant that can
# be read out of the chart source. It cannot decide the one that actually breaks
# consumers: since Nexus Community Edition ships an UNACCEPTED end-user licence
# agreement, a chart can deploy green, show four correctly configured proxy
# repositories in the UI, serve repository METADATA with HTTP 200 — and return
# HTTP 403 with a ~192-byte refusal body on every real package download. A green
# `helm install` does not catch that. Neither does a green `helm template`.
#
# So this script boots a real Nexus container from the image the chart itself
# renders, runs the chart's own provisioning script against it TWICE, and then
# downloads a real package tarball and measures its size. Two passes, because a
# repeat blind POST to the repositories API returns 400 — a second exit 0 is the
# only proof the GET->PUT/POST upsert is genuinely idempotent. A size threshold,
# because the EULA refusal body is itself a valid HTTP response and would sail
# past a bare "did curl succeed" check.
#
# The second half installs the chart for real on a throwaway kind cluster and
# waits for the provisioning Job to reach `complete`. The docker half proves the
# provisioning LOGIC; only the kind half proves the chart's Kubernetes wiring —
# the hook annotations, the Secret plumbing, the Service name the Job targets.
# Neither half subsumes the other, and both are soft-gated so an absent tool is
# reported as SKIPPED rather than silently dropped.
#
# Runtime: roughly 3 minutes for the docker half, roughly 8 minutes with the
# kind half as well (image pulls excluded; Nexus first boot dominates both).
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/nexus-live-smoke.sh
#
# INTERMEDIATE-COMMIT CONVENTION — VACUOUS-PASS, the same convention
# check-nexus-chart.sh uses. This script is written in wave 2; its subject,
# kubernetes/nexus/files/provision.sh, lands in wave 4. Between those commits it
# must report neither red nor green: it pushes a named SKIPPED entry, prints the
# summary, and exits 0 WITHOUT printing ALL PASS. A skip is not a pass, and a
# run in which nothing executed is not a pass either.
#
# Exit codes:
#   0  every live check that ran passed, or the run was skipped (nothing ran)
#   1  at least one live check failed, or a required hard-tier binary is
#      missing, or the subchart tarball is not vendored. `kind`/`kubectl` are
#      SOFT tier: absent, they produce a SKIPPED entry, not a failure.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# The provisioning script this smoke drives is the one the chart's Job runs —
# the same file, not a copy of it. If these ever diverge the smoke is worthless.
PROVISION_SH="kubernetes/nexus/files/provision.sh"

# Assigned BEFORE the trap so `set -u` cannot trip inside the cleanup path.
NEXUS_CONTAINER="nexus-live-smoke-$$"
# Likewise for the kind cluster. KIND_CREATED flips to 1 the moment creation is
# ATTEMPTED, so a half-built cluster is torn down too.
KIND_CLUSTER="nexus-smoke"
KIND_NS="nexus-smoke"
KIND_CONTEXT="kind-${KIND_CLUSTER}"
KIND_CREATED=0
# `kind create cluster` REWRITES the operator's kubeconfig current-context, and
# `kind delete cluster` then leaves it UNSET — measured: `kubectl config
# current-context` reported "error: current-context is not set" after a clean
# run. This smoke must not damage the environment it runs in, so the incoming
# context is captured here and restored by the cleanup trap.
KUBECTX_BEFORE=""

OUT="$(mktemp -d)"
# Cleanup owns the container and the kind cluster as well as the temp dir: a
# failed run must not leak either. The `|| true` here is cleanup hygiene on a best-effort
# teardown, not a silenced assertion — no verdict is derived from it.
trap 'rm -rf "$OUT"; docker rm -f "$NEXUS_CONTAINER" >/dev/null 2>&1 || true; if [ "$KIND_CREATED" = "1" ]; then kind delete cluster --name "$KIND_CLUSTER" >/dev/null 2>&1 || true; fi; if [ -n "$KUBECTX_BEFORE" ]; then kubectl config use-context "$KUBECTX_BEFORE" >/dev/null 2>&1 || true; fi' EXIT

FAILURES=()
# SKIPPED: sub-checks that did not run (an optional tool is absent, or the
# subject of the check does not exist at this commit). Reported separately from
# FAILURES and separately from passes — a skip must never read as a pass — and
# it never affects the exit status.
SKIPPED=()
# CHECKS_PASSED: live checks that actually executed and passed. Counted from the
# run itself, so the summary cannot claim a pass on a run where nothing ran.
CHECKS_PASSED=0

# require_success: run a command that is expected to exit 0. provision.sh is
# contractually exit-0 on BOTH passes, so this is the correct helper.
#
# Deliberately NOT copied from smoke-scans.sh: run_scan / run_scan_rc. Their
# PASS-on-exit-1 inversion is scanner semantics — applied here it would score a
# BROKEN provisioning run as a pass, which is the exact failure mode this
# script exists to prevent.
require_success() {
  local label="$1"
  shift
  local rc=0
  "$@" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    echo "==> ${label}: exit=${rc} (PASS - completed successfully)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    echo "==> ${label}: exit=${rc} (FAIL - expected exit 0)"
    FAILURES+=("${label}: exited ${rc}, expected 0")
  fi
  return 0
}

# pass / fail: the two ends of every inline assertion below. An assertion must
# never swallow its own result with `|| true` — an assertion that ignores its
# own failure IS the false-pass mechanism this script exists to prevent.
pass() {
  echo "==> $1: PASS - $2"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
}
fail() {
  echo "==> $1: FAIL - $2"
  FAILURES+=("$1: $2")
}

# yq v4 preserves source quoting, so a YAML `image: "repo:tag"` can come back
# with its quotes attached and would be an unusable `docker run` argument.
# Measured on yq v4.53.6 here: scalars ARE unwrapped. Stripping anyway costs
# nothing and keeps the smoke working on a yq that behaves differently in CI.
unquote() {
  printf '%s' "$1" | sed -e 's/^"//' -e 's/"$//'
}

# The positive-render wrapper, identical in shape to check-nexus-chart.sh: the
# chart `required`s a Secret NAME (never a credential), so a bare render fails
# and would make every positive assertion below report a defect that is not one.
render() {
  helm template t kubernetes/nexus \
    --set nexus3.rootPassword.secret=dummy-secret-name "$@"
}

# print_summary: the terminal verdict. Skips print first, under their own
# heading, on every path — they are not failures and they are not passes.
print_summary() {
  echo
  echo "=== Summary ==="
  if [ "${#SKIPPED[@]}" -gt 0 ]; then
    echo "SKIPPED - ${#SKIPPED[@]} sub-check(s) did not run. A SKIP IS NOT A PASS:"
    for s in "${SKIPPED[@]}"; do
      echo "  - ${s}"
    done
    echo
  fi
  if [ "${#FAILURES[@]}" -gt 0 ]; then
    echo "FAILED - one or more live checks did not produce the expected result:"
    for f in "${FAILURES[@]}"; do
      echo "  - ${f}"
    done
    exit 1
  elif [ "$CHECKS_PASSED" -eq 0 ]; then
    # Zero failures on a run where zero checks executed is NOT a pass. Saying
    # ALL PASS here is the vacuous-green this convention exists to forbid.
    echo "NOTHING RAN - 0 live check(s) executed; ${#SKIPPED[@]} sub-check(s) skipped (not passed). Nothing was proven."
    exit 0
  else
    echo "ALL PASS - ${CHECKS_PASSED} live check(s) executed and passed; ${#SKIPPED[@]} sub-check(s) skipped (not passed)."
    exit 0
  fi
}

# ── Preflight, hard tier ─────────────────────────────────────────────────────
# Every binary here drives a check this smoke cannot render a verdict without.
for bin in docker curl jq yq helm; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 1
  fi
done

# ── Guard: the subject does not exist yet (pre-23-04) ────────────────────────
# Checked IMMEDIATELY after the binary loop and BEFORE the subchart-tarball
# preflight below: at this script's own creation commit kubernetes/nexus does
# not exist at all, so the tarball preflight would FATAL on a repository state
# that is correct by design.
if [ ! -f "$PROVISION_SH" ]; then
  SKIPPED+=("live smoke: ${PROVISION_SH} does not exist yet (lands in plan 23-04); no container was booted")
  print_summary
fi

# ── Preflight: the subchart must be vendored ─────────────────────────────────
# Every render() call below depends on it, and a fresh clone has an empty
# charts/ directory because the tarball is gitignored.
if ! compgen -G "kubernetes/nexus/charts/*.tgz" >/dev/null; then
  echo "FATAL: subchart not vendored — run: helm dependency build kubernetes/nexus" >&2
  exit 1
fi

# ── Credential ───────────────────────────────────────────────────────────────
# Generated at runtime, never committed, never echoed, and `set -x` is never
# enabled anywhere in this script. gitleaks runs as a pre-push hook over the
# whole repository; a literal test password committed to a public repo is a real
# finding, not a test detail.
NEXUS_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '/+=')"

echo "--- 1. Boot Nexus ---"
# Resolve the image FROM THE CHART, never from memory: the chart tracks a
# floating tag, and a hardcoded tag here would silently test something the chart
# no longer ships.
NEXUS_IMAGE="$(unquote "$(render | yq 'select(.kind=="StatefulSet") | .spec.template.spec.containers[0].image')")"
if [ -z "$NEXUS_IMAGE" ] || [ "$(printf '%s\n' "$NEXUS_IMAGE" | wc -l | tr -d ' ')" -ne 1 ]; then
  fail "NEXUS-IMAGE" "expected exactly one StatefulSet container image from the rendered chart, got: '${NEXUS_IMAGE}'"
  # Nothing downstream can run without an image; continuing would report a
  # cascade of derived failures that all have this one cause.
  print_summary
fi
echo "    image (from the chart): ${NEXUS_IMAGE}"

# The admin credential goes in a mode-600 env file inside the trap-cleaned temp
# dir rather than on the docker argv, where any local process could read it.
# The umask is SCOPED to this subshell on purpose: leaving it set globally would
# make `helm dependency build` in section 6 write mode-600 files into the
# operator's own checkout.
(
  umask 077
  cat >"$OUT/nexus.env" <<ENV_EOF
NEXUS_SECURITY_RANDOMPASSWORD=false
NEXUS_SECURITY_INITIAL_PASSWORD=${NEXUS_PASSWORD}
ENV_EOF
)

docker run -d --name "$NEXUS_CONTAINER" \
  --env-file "$OUT/nexus.env" \
  -p 127.0.0.1::8081 \
  "$NEXUS_IMAGE" >/dev/null

# `docker port` can print both the v4 and v6 mapping on newer daemons; inspect
# the first published binding directly instead of parsing two lines.
NEXUS_PORT="$(docker inspect -f '{{(index (index .NetworkSettings.Ports "8081/tcp") 0).HostPort}}' "$NEXUS_CONTAINER")"
NEXUS_HOST="http://127.0.0.1:${NEXUS_PORT}"
echo "    container: ${NEXUS_CONTAINER} -> ${NEXUS_HOST}"

if [ "$(docker inspect -f '{{.State.Running}}' "$NEXUS_CONTAINER")" = "true" ]; then
  pass "NEXUS-BOOT" "container is running (provision.sh owns the readiness poll)"
else
  fail "NEXUS-BOOT" "container ${NEXUS_CONTAINER} is not running after docker run"
  print_summary
fi
echo

echo "--- 2. Extract repo bodies from the chart ---"
# The bodies come out of the chart's own rendered ConfigMap, so this smoke
# cannot drift from what the chart actually ships. --set repos.helm.remoteUrl
# is what makes the fourth (opt-in) body appear.
mkdir -p "$OUT/config"
render --set repos.helm.remoteUrl=https://charts.jetstack.io >"$OUT/rendered.yaml"
yq -o=json 'select(.kind=="ConfigMap" and (.metadata.name|test("-repos$"))) | .data' \
  "$OUT/rendered.yaml" >"$OUT/repos-data.json"
if [ ! -s "$OUT/repos-data.json" ]; then
  fail "REPO-BODY-EXTRACT" "no ConfigMap whose name ends '-repos' rendered from the chart; provisioning cannot be attempted without repo bodies"
  print_summary
fi

jq -r 'keys[]' "$OUT/repos-data.json" >"$OUT/repo-keys.txt"
while IFS= read -r key; do
  [ -n "$key" ] || continue
  jq -r --arg k "$key" '.[$k]' "$OUT/repos-data.json" >"$OUT/config/${key}"
done <"$OUT/repo-keys.txt"

body_count="$(find "$OUT/config" -type f | wc -l | tr -d ' ')"
if [ "$body_count" -eq 4 ]; then
  pass "REPO-BODY-COUNT" "4 repo body files written to \$OUT/config"
else
  fail "REPO-BODY-COUNT" "expected 4 repo body files, got ${body_count}: $(find "$OUT/config" -type f -exec basename {} \; | tr '\n' ' ')"
fi

bad_json=""
for f in "$OUT"/config/*; do
  [ -e "$f" ] || continue
  if ! jq -e . "$f" >/dev/null 2>&1; then
    bad_json="${bad_json} $(basename "$f")"
  fi
done
if [ -z "$bad_json" ]; then
  pass "REPO-BODY-JSON" "every extracted repo body parses as JSON"
else
  fail "REPO-BODY-JSON" "repo body file(s) do not parse as JSON:${bad_json}"
fi
echo

echo "--- 3. provision.sh pass 1 ---"
require_success "PROVISION-PASS-1" env \
  NEXUS_HOST="$NEXUS_HOST" \
  NEXUS_USER=admin \
  NEXUS_PASSWORD="$NEXUS_PASSWORD" \
  EULA_ACCEPTED=true \
  REPO_CONFIG_DIR="$OUT/config" \
  bash "$PROVISION_SH"
echo

echo "--- 4. provision.sh pass 2 (idempotency) ---"
# The identical invocation. A repeat blind POST to the repositories API returns
# 400, so a second exit 0 is the only proof the GET->PUT/POST upsert is real.
require_success "PROVISION-PASS-2" env \
  NEXUS_HOST="$NEXUS_HOST" \
  NEXUS_USER=admin \
  NEXUS_PASSWORD="$NEXUS_PASSWORD" \
  EULA_ACCEPTED=true \
  REPO_CONFIG_DIR="$OUT/config" \
  bash "$PROVISION_SH"
echo

echo "--- 5. Post-EULA artifact download ---"
# Measured on a Community Edition container: 192 bytes / HTTP 403 before EULA
# acceptance, 318961 bytes / HTTP 200 after it. The refusal body is a perfectly
# well-formed HTTP response, so the SIZE assertion — not the status alone — is
# what distinguishes a real tarball from the licence refusal. No `curl -f`: the
# refusal body has to land on disk for the size assertion to measure it.
TARBALL_URL="${NEXUS_HOST}/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz"
TARBALL_MIN_BYTES=100000
curl_rc=0
http_code="$(curl -sS -o "$OUT/lodash.tgz" -w '%{http_code}' \
  -u admin:"$NEXUS_PASSWORD" "$TARBALL_URL")" || curl_rc=$?

if [ "$curl_rc" -ne 0 ]; then
  fail "ARTIFACT-TRANSPORT" "curl exited ${curl_rc} fetching ${TARBALL_URL} (transport error, not an HTTP verdict)"
else
  pass "ARTIFACT-TRANSPORT" "curl completed against ${TARBALL_URL}"
fi

if [ "$http_code" = "200" ]; then
  pass "ARTIFACT-HTTP-200" "tarball request returned HTTP 200"
else
  fail "ARTIFACT-HTTP-200" "tarball request returned HTTP ${http_code}, expected 200 (403 means the EULA was never accepted)"
fi

if [ -f "$OUT/lodash.tgz" ]; then
  tarball_bytes="$(wc -c <"$OUT/lodash.tgz" | tr -d ' ')"
else
  tarball_bytes=0
fi
if [ "$tarball_bytes" -gt "$TARBALL_MIN_BYTES" ]; then
  pass "ARTIFACT-SIZE" "${tarball_bytes} bytes downloaded (> ${TARBALL_MIN_BYTES})"
else
  fail "ARTIFACT-SIZE" "only ${tarball_bytes} bytes downloaded, expected > ${TARBALL_MIN_BYTES}; a ~192-byte body is the EULA refusal, not a tarball"
fi

echo "--- 6. kind install smoke ---"
# SOFT tier, unlike the hard-tier preflight at the top: a workstation without a
# local cluster toolchain must not hard-fail the docker half. The skip is named
# and accounted for, so it can never be mistaken for a pass.
if ! command -v kind &>/dev/null || ! command -v kubectl &>/dev/null; then
  SKIPPED+=("kind install smoke: 'kind' and/or 'kubectl' not found on PATH; the chart was never installed on a cluster")
  echo "    SKIPPED - kind and/or kubectl absent"
  print_summary
fi

# Every kubectl/helm call below pins the context explicitly. Without this, a
# failed `kind create cluster` would leave the commands pointed at whatever
# cluster the operator happens to have selected — this smoke must never touch it.
KUBECTX_BEFORE="$(kubectl config current-context 2>/dev/null || true)"
echo "    creating cluster ${KIND_CLUSTER} (this is the slow part)"
KIND_CREATED=1
kind_rc=0
kind create cluster --name "$KIND_CLUSTER" >/dev/null 2>&1 || kind_rc=$?
if [ "$kind_rc" -ne 0 ]; then
  fail "KIND-CLUSTER" "kind create cluster --name ${KIND_CLUSTER} exited ${kind_rc}"
  print_summary
fi
pass "KIND-CLUSTER" "cluster ${KIND_CLUSTER} is up"

kubectl --context "$KIND_CONTEXT" create namespace "$KIND_NS" >/dev/null

# The Secret that nexus3.rootPassword.secret names. Applied from stdin rather
# than `--from-literal` so the credential never appears on a kubectl argv, and
# never on stdout.
kubectl --context "$KIND_CONTEXT" --namespace "$KIND_NS" apply -f - >/dev/null <<SECRET_EOF
apiVersion: v1
kind: Secret
metadata:
  name: nexus-admin
type: Opaque
stringData:
  password: "${NEXUS_PASSWORD}"
SECRET_EOF

# Needs network. The offline gate deliberately does not do this; a fresh clone
# has an empty charts/ directory because the tarball is gitignored.
require_success "KIND-DEPENDENCY-BUILD" helm dependency build kubernetes/nexus

# The 15m timeout is deliberate and must not be reduced. Helm blocks on the
# post-install hook Job, and Nexus first boot plus provisioning exceeds the 5m
# default on constrained hardware: readiness alone is 1-3 minutes on homelab
# hardware, and the Job's own readiness poll is bounded at 600s.
require_success "KIND-INSTALL" helm install t kubernetes/nexus \
  --kube-context "$KIND_CONTEXT" \
  --namespace "$KIND_NS" \
  --set nexus3.rootPassword.secret=nexus-admin \
  --set eula.accepted=true \
  --set repos.helm.remoteUrl=https://charts.jetstack.io \
  --wait --timeout 15m

# The chart's hook Job carries `helm.sh/hook-delete-policy: before-hook-creation`
# WITHOUT `hook-succeeded`, so the Job still exists after a successful install
# and waiting on it is meaningful. Prove that before waiting: `kubectl wait`
# against an empty set prints "error: no matching resources found" and its exit
# code is not a reliable signal, so an empty result must be a FAILURE naming the
# delete-policy rather than a silent pass.
job_rows="$(kubectl --context "$KIND_CONTEXT" --namespace "$KIND_NS" get job \
  -l app.kubernetes.io/instance=t --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [ "$job_rows" -eq 0 ]; then
  fail "KIND-JOB-COMPLETE" "no Job matched app.kubernetes.io/instance=t in namespace ${KIND_NS} after install; either the chart renders no provisioning Job, it is missing that label, or its helm.sh/hook-delete-policy includes hook-succeeded and deleted the evidence"
else
  echo "    ${job_rows} Job(s) still present after install: the delete-policy left the evidence in place"
  require_success "KIND-JOB-COMPLETE" kubectl --context "$KIND_CONTEXT" --namespace "$KIND_NS" \
    wait --for=condition=complete job -l app.kubernetes.io/instance=t --timeout=300s
fi

print_summary
