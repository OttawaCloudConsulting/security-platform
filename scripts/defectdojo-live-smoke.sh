#!/usr/bin/env bash
set -euo pipefail

# defectdojo-live-smoke.sh — the LIVE half of the Phase 26 evidence for the
# DefectDojo Helm chart (kubernetes/defectdojo).
#
# WHY THIS EXISTS. scripts/check-defectdojo-chart.sh decides every invariant that
# can be read out of the chart source. It cannot decide the ones that actually
# break consumers, and the research for this phase measured two of them:
#
#   1. A GET /login returned HTTP 200 while uwsgi was one login POST away from
#      OOMKill. The login PAGE is cheap; the first authenticated request is not.
#      So a "login page returns 200" check is necessary but proves little on its
#      own. This smoke performs a real CSRF-token admin login POST and then loads
#      /dashboard as that user.
#   2. Upstream ships no probes for the Celery worker, so a worker that is
#      Running 1/1 proves nothing about the broker. This smoke asks the worker
#      for a broker round-trip (celery inspect ping).
#
# And the TLS claim of DDOJO-01 ("external ingress and cert-manager-issued TLS")
# is only evidence when the served certificate is VERIFIED against the issuing
# CA. `curl -k` would sail past the ingress controller's fake default
# certificate, so every HTTPS call here uses --cacert with the CA taken from the
# Secret cert-manager itself issued. Only a verified-TLS login plus a broker
# ping is evidence; everything else is a precondition.
#
# D-14 names only "HTTPS request to the login page returns 200". KIND-LOGIN and
# KIND-CELERY-PING go beyond that literal text on purpose (RESEARCH Open
# Question 5), for the two reasons above.
#
# D-15: first install only. Exactly one install and no upgrade/idempotency pass.
#
# Infrastructure pinned for the smoke ONLY: cert-manager v1.21.2 and
# ingress-nginx controller-v1.15.1. ingress-nginx is archived upstream; it is
# used here inside a throwaway kind cluster and is NOT a recommendation to
# consumers of the chart.
#
# Runtime: a fresh kind node pulls every image cold (kind node, cert-manager,
# ingress-nginx, DefectDojo django/nginx/celery, Postgres, Valkey). Expect
# roughly 10-20 minutes on a cold cache; the install alone measured 101 s with
# warm images. The helm timeout is 15m for that reason and must not be reduced.
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/defectdojo-live-smoke.sh
#
# INTERMEDIATE-COMMIT CONVENTION — VACUOUS-PASS, the same convention
# check-defectdojo-chart.sh uses. This script is written in wave 2; its subject,
# kubernetes/defectdojo (keyed on templates/validate-tls.yaml), lands in a later
# plan. Between those commits it must report neither red nor green: it pushes a
# named SKIPPED entry, prints the summary, and exits 0 WITHOUT printing ALL PASS
# and WITHOUT touching kind or any kube context. A skip is not a pass, and a run
# in which nothing executed is not a pass either.
#
# Exit codes:
#   0  every live check that ran passed, or the run was skipped (nothing ran)
#   1  at least one live check failed
#   2  preflight failure: a required hard-tier binary is missing, or the
#      subchart could not be vendored. `kind`/`kubectl` are SOFT tier: absent,
#      they produce a SKIPPED entry, not a failure.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CHART_DIR="kubernetes/defectdojo"
# The subject guard keys on the TLS guard template: it is the file that makes
# the chart a DefectDojo-with-TLS chart rather than an empty directory.
SUBJECT_FILE="${CHART_DIR}/templates/validate-tls.yaml"

# ── Pinned smoke infrastructure (smoke-only) ─────────────────────────────────
readonly CERT_MANAGER_VERSION="v1.21.2"
readonly CERT_MANAGER_URL="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
readonly INGRESS_NGINX_VERSION="controller-v1.15.1"
readonly INGRESS_NGINX_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml"
# Release name MUST be `defectdojo`: the subchart's fullname collapses to the
# release name when it contains "defectdojo", so the app Secret the chart reads
# is literally named `defectdojo` (RESEARCH Pattern 3).
readonly RELEASE="defectdojo"
readonly SMOKE_HOST="defectdojo.smoke.test"
readonly ISSUER_NAME="smoke-ca"

# Assigned BEFORE the trap so `set -u` cannot trip inside the cleanup path.
# KIND_CREATED is the trap's ownership flag: it flips to 1 only AFTER
# `kind create cluster` has returned 0, so the trap can never delete a cluster
# this run did not create. See the ownership guard below for why that ordering
# is load-bearing rather than stylistic.
KIND_CLUSTER="dd-smoke"
KIND_NS="defectdojo"
KIND_CONTEXT="kind-${KIND_CLUSTER}"
KIND_CREATED=0
# `kind create cluster` REWRITES the operator's kubeconfig current-context, and
# `kind delete cluster` then leaves it UNSET (measured in the Nexus smoke). This
# smoke must not damage the environment it runs in — the operator's current
# context is a real cluster — so the incoming context is captured and restored
# by the cleanup trap.
KUBECTX_BEFORE=""
# The background port-forward to the ingress controller. Killed by the trap so
# a failed run cannot leave an orphaned process holding the port.
PF_PID=""

OUT="$(mktemp -d)"
# Cleanup owns the port-forward and the kind cluster as well as the temp dir
# (which holds the admin password file, the CA and the cookie jar): a failed run
# must not leak any of them. The `|| true` here is cleanup hygiene on a
# best-effort teardown, not a silenced assertion — no verdict is derived from it.
trap 'if [ -n "$PF_PID" ]; then kill "$PF_PID" >/dev/null 2>&1 || true; fi; rm -rf "$OUT"; if [ "$KIND_CREATED" = "1" ]; then kind delete cluster --name "$KIND_CLUSTER" >/dev/null 2>&1 || true; fi; if [ -n "$KUBECTX_BEFORE" ]; then kubectl config use-context "$KUBECTX_BEFORE" >/dev/null 2>&1 || true; fi' EXIT

FAILURES=()
# SKIPPED: sub-checks that did not run (an optional tool is absent, or the
# subject of the check does not exist at this commit). Reported separately from
# FAILURES and separately from passes — a skip must never read as a pass — and
# it never affects the exit status.
SKIPPED=()
# CHECKS_PASSED: live checks that actually executed and passed. Counted from the
# run itself, so the summary cannot claim a pass on a run where nothing ran.
CHECKS_PASSED=0

# require_success: run a command that is expected to exit 0.
#
# Deliberately NOT copied from smoke-scans.sh: run_scan / run_scan_rc. Their
# PASS-on-exit-1 inversion is scanner semantics — applied here it would score a
# BROKEN install as a pass, which is the exact failure mode this script exists
# to prevent.
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

# yq v4 preserves source quoting, so a YAML scalar can come back with its quotes
# attached. Measured on yq v4.53.6: scalars ARE unwrapped. Stripping anyway
# costs nothing and keeps the smoke working on a yq that behaves differently.
unquote() {
  printf '%s' "$1" | sed -e 's/^"//' -e 's/"$//'
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

# gen_secret LENGTH: an alphanumeric credential of exactly LENGTH characters.
#
# Lengths and charset match the upstream chart's own generator
# (defectdojo/templates/secret.yaml in the vendored defectdojo-1.9.53.tgz, read
# with `tar -xOzf` when this script was written): randAlphaNum 22 for
# DD_ADMIN_PASSWORD, 128 for DD_SECRET_KEY and DD_CREDENTIAL_AES_256_KEY, 32 for
# METRICS_HTTP_AUTH_PASSWORD. The same `head -c | base64 | tr -d` form as the
# Nexus smoke; `\n` is deleted too because GNU base64 wraps at 76 columns.
# Twice the requested bytes are read so the alphanumeric residue always exceeds
# LENGTH, and the result is cut in bash rather than with `head -c` on a pipe
# (which would SIGPIPE the producer under pipefail). Never echoed; `set -x` is
# never enabled anywhere in this script.
gen_secret() {
  local want="$1" raw
  raw="$(head -c $((want * 2)) /dev/urandom | base64 | tr -d '/+=\n')"
  if [ "${#raw}" -lt "$want" ]; then
    echo "FATAL: credential generator produced ${#raw} chars, needed ${want}" >&2
    exit 2
  fi
  printf '%s' "${raw:0:want}"
}

# ── Preflight, hard tier ─────────────────────────────────────────────────────
# Every binary here drives a check this smoke cannot render a verdict without.
# docker is required by kind; openssl reads the served certificate's issuer/SAN.
for bin in curl jq yq helm docker openssl; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 2
  fi
done

# Every measurement behind this smoke used Helm v4.3.0 (RESEARCH Pitfall 3).
# Helm 3 wait semantics were not measured, so the version is part of the record.
echo "helm client: $(helm version --short)"

# ── Guard: the subject does not exist yet ────────────────────────────────────
# Checked BEFORE the subchart preflight and BEFORE any kind/kube call: at this
# script's own creation commit kubernetes/defectdojo does not exist at all.
if [ ! -f "$SUBJECT_FILE" ]; then
  SKIPPED+=("live smoke: ${SUBJECT_FILE} does not exist yet (the chart lands in a later plan); no cluster was created and no kube context was touched")
  print_summary
fi

# ── Preflight: the subchart must be vendored ─────────────────────────────────
# The tarball name is derived from Chart.yaml, never hardcoded, so a dependency
# bump cannot leave this check pointing at the old version. This is PREFLIGHT,
# not a live check: it does not increment CHECKS_PASSED, so a run that vendors
# the subchart and then skips the cluster half still reads NOTHING RAN.
DD_CHART_VERSION="$(unquote "$(yq '.dependencies[0].version' "${CHART_DIR}/Chart.yaml")")"
if [ -z "$DD_CHART_VERSION" ] || [ "$DD_CHART_VERSION" = "null" ]; then
  echo "FATAL: could not read .dependencies[0].version from ${CHART_DIR}/Chart.yaml" >&2
  exit 2
fi
DD_TARBALL="${CHART_DIR}/charts/defectdojo-${DD_CHART_VERSION}.tgz"
if [ ! -f "$DD_TARBALL" ]; then
  echo "    ${DD_TARBALL} not vendored; running helm dependency build (needs network)"
  if ! helm dependency build "$CHART_DIR"; then
    echo "FATAL: helm dependency build ${CHART_DIR} failed; ${DD_TARBALL} is still absent" >&2
    exit 2
  fi
  if [ ! -f "$DD_TARBALL" ]; then
    echo "FATAL: helm dependency build succeeded but ${DD_TARBALL} is absent (Chart.yaml/Chart.lock mismatch?)" >&2
    exit 2
  fi
fi

# ── Soft tier ────────────────────────────────────────────────────────────────
# A workstation without a local cluster toolchain gets a named SKIP, never a
# silent pass.
for bin in kind kubectl; do
  if ! command -v "$bin" &>/dev/null; then
    SKIPPED+=("kind install smoke: '${bin}' not found on PATH; the chart was never installed on a cluster")
    echo "    SKIPPED - ${bin} absent"
    print_summary
  fi
done

# ── Credentials ──────────────────────────────────────────────────────────────
# Generated at runtime, never committed, never echoed, never on an argv.
# gitleaks runs as a pre-push hook over the whole repository; a literal test
# credential committed to a public repo is a real finding, not a test detail.
DD_ADMIN_PW="$(gen_secret 22)"
DD_SECRET_KEY_VAL="$(gen_secret 128)"
DD_AES_KEY_VAL="$(gen_secret 128)"
DD_METRICS_PW="$(gen_secret 32)"
PG_POSTGRES_PW="$(gen_secret 32)"
PG_APP_PW="$(gen_secret 32)"
VALKEY_PW="$(gen_secret 32)"
# The login POST reads the admin password from this file via
# `--data-urlencode password@FILE`, so it never reaches curl's argv. umask in a
# subshell: the file is created 600, never world-readable even momentarily.
# printf without a newline: `@FILE` would URL-encode a trailing newline into it.
( umask 077; printf '%s' "$DD_ADMIN_PW" > "$OUT/admin-pw" )

echo "--- 1. kind cluster ---"
# Every kubectl/helm call below pins the context explicitly, on the same line as
# the command word. Without this, a failed `kind create cluster` would leave the
# commands pointed at whatever cluster the operator has selected — this smoke
# must never touch it.
if ! KUBECTX_BEFORE="$(kubectl config current-context 2>/dev/null)"; then
  # No current context is a legitimate starting state; there is nothing to
  # restore, and the trap's restore clause is keyed on a non-empty value.
  KUBECTX_BEFORE=""
fi

# ── Ownership guard: never delete a cluster this run did not create ──────────
# KIND_CLUSTER is a FIXED name, so it can collide with a cluster the operator
# already owns, and the EXIT trap deletes $KIND_CLUSTER once KIND_CREATED is 1.
# Measured on kind v0.33.0 (Nexus smoke): a colliding `kind create cluster`
# exits 1 with `node(s) already exist for a cluster with the name "..."`. So
# setting the ownership flag BEFORE the call would turn a mere name collision
# into the DELETION of somebody else's cluster. Refuse the run instead.
#
# `kind get clusters` prints bare cluster names on stdout, one per line; the
# empty-list message "No kind clusters found." goes to STDERR, so an empty list
# cannot match and the guard cannot misfire. `grep -qx` anchors both ends: a
# cluster merely PREFIXED dd-smoke is a different cluster and must not trip it.
if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER"; then
  fail "KIND-CLUSTER" "cluster ${KIND_CLUSTER} already exists and this run did not create it; refusing to touch it. If it is a leftover from an earlier run, remove it yourself: kind delete cluster --name ${KIND_CLUSTER}"
  print_summary
fi

echo "    creating cluster ${KIND_CLUSTER} (cold image pulls follow; this is the slow part)"
kind_rc=0
kind create cluster --name "$KIND_CLUSTER" >/dev/null 2>&1 || kind_rc=$?
if [ "$kind_rc" -ne 0 ]; then
  # Deliberately NOT claiming ownership on a failed create. The cost is that a
  # HALF-built cluster is left behind rather than torn down; the benefit is that
  # a collision can never delete an operator's cluster. The leftover is loud,
  # not silent: the guard above FAILs on the next run and names the fix.
  fail "KIND-CLUSTER" "kind create cluster --name ${KIND_CLUSTER} exited ${kind_rc}; if it left a partial cluster behind, remove it with: kind delete cluster --name ${KIND_CLUSTER}"
  print_summary
fi
# Ownership claimed only now: `kind create cluster` returned 0, so the cluster
# the trap deletes is unambiguously this run's.
KIND_CREATED=1
pass "KIND-CLUSTER" "cluster ${KIND_CLUSTER} is up (context ${KIND_CONTEXT})"

echo "--- 2. cert-manager ${CERT_MANAGER_VERSION} ---"
cm_ok=1
if ! kubectl --context "$KIND_CONTEXT" apply -f "$CERT_MANAGER_URL" >/dev/null; then
  cm_ok=0
  fail "KIND-CERT-MANAGER" "applying ${CERT_MANAGER_URL} failed"
else
  for d in cert-manager cert-manager-webhook cert-manager-cainjector; do
    if ! kubectl --context "$KIND_CONTEXT" -n cert-manager rollout status "deploy/${d}" --timeout=300s >/dev/null; then
      cm_ok=0
      fail "KIND-CERT-MANAGER" "deployment ${d} in namespace cert-manager did not roll out within 300s"
    fi
  done
fi
if [ "$cm_ok" -eq 1 ]; then
  pass "KIND-CERT-MANAGER" "cert-manager ${CERT_MANAGER_VERSION} applied; cert-manager, cert-manager-webhook and cert-manager-cainjector rolled out"
else
  # Nothing downstream can issue a certificate; continuing would only pile
  # consequential failures on top of the real one.
  print_summary
fi

echo "--- 3. ingress-nginx ${INGRESS_NGINX_VERSION} (smoke-only; archived upstream) ---"
in_ok=1
if ! kubectl --context "$KIND_CONTEXT" apply -f "$INGRESS_NGINX_URL" >/dev/null; then
  in_ok=0
  fail "KIND-INGRESS-NGINX" "applying ${INGRESS_NGINX_URL} failed"
# The controller rollout finishing is the gate for applying Ingresses: its
# admission webhook refuses them until then (RESEARCH Pitfall 9).
elif ! kubectl --context "$KIND_CONTEXT" -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s >/dev/null; then
  in_ok=0
  fail "KIND-INGRESS-NGINX" "deployment ingress-nginx-controller did not roll out within 300s"
# The kind manifest's IngressClass `nginx` is NOT annotated as the default, and
# the controller runs --watch-ingress-without-class=true, so a classless Ingress
# is served either way. Without this annotation the D-12 assertion later
# (KIND-INGRESSCLASS-DEFAULTED) would prove nothing (RESEARCH Pitfall 8).
elif ! kubectl --context "$KIND_CONTEXT" annotate ingressclass nginx ingressclass.kubernetes.io/is-default-class=true >/dev/null; then
  in_ok=0
  fail "KIND-INGRESS-NGINX" "could not annotate IngressClass nginx as the cluster default"
fi
if [ "$in_ok" -eq 1 ]; then
  pass "KIND-INGRESS-NGINX" "ingress-nginx ${INGRESS_NGINX_VERSION} rolled out; IngressClass nginx annotated is-default-class=true"
else
  print_summary
fi

echo "--- 4. CA ClusterIssuer ---"
# SelfSigned ClusterIssuer -> isCA Certificate smoke-ca (secret smoke-ca in
# namespace cert-manager, the ClusterIssuer resource namespace) -> CA
# ClusterIssuer smoke-ca. Everything the CA issues carries ca.crt in its Secret,
# which is what lets curl VERIFY the served certificate instead of using -k.
apply_ca_issuers() {
  kubectl --context "$KIND_CONTEXT" apply -f - >/dev/null <<CA_EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${ISSUER_NAME}
  namespace: cert-manager
spec:
  isCA: true
  commonName: ${ISSUER_NAME}
  secretName: ${ISSUER_NAME}
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${ISSUER_NAME}
spec:
  ca:
    secretName: ${ISSUER_NAME}
CA_EOF
}
# The cert-manager webhook can briefly refuse connections right after its
# rollout reports done (RESEARCH Pitfall 9 / A3; the measured run succeeded
# first try). Bounded retry, and the final outcome is still asserted.
ca_applied=0
for attempt in 1 2 3 4 5; do
  if apply_ca_issuers; then
    ca_applied=1
    break
  fi
  echo "    CA issuer apply attempt ${attempt}/5 refused; retrying in 5s"
  sleep 5
done
if [ "$ca_applied" -ne 1 ]; then
  fail "KIND-CA-ISSUER" "the SelfSigned/CA ClusterIssuer chain could not be applied after 5 attempts (cert-manager webhook refusing?)"
  print_summary
fi
if kubectl --context "$KIND_CONTEXT" -n cert-manager wait --for=condition=Ready "certificate/${ISSUER_NAME}" --timeout=120s >/dev/null; then
  pass "KIND-CA-ISSUER" "ClusterIssuer selfsigned -> Certificate ${ISSUER_NAME} (isCA, Ready) -> ClusterIssuer ${ISSUER_NAME}"
else
  fail "KIND-CA-ISSUER" "Certificate ${ISSUER_NAME} in namespace cert-manager did not become Ready within 120s"
  print_summary
fi

echo "--- 5. namespace and pre-created Secrets ---"
kubectl --context "$KIND_CONTEXT" create namespace "$KIND_NS" >/dev/null

# The three Secrets the chart consumes (D-13: consumer pre-created, the chart
# renders none by default). Applied from stdin rather than `--from-literal` so no
# credential ever appears on a kubectl argv, and never on stdout.
#
# DD_ADMIN_PASSWORD is ALWAYS supplied: when it is absent the upstream
# initializer generates one and prints it to the pod log (T-26-03).
kubectl --context "$KIND_CONTEXT" --namespace "$KIND_NS" apply -f - >/dev/null <<SECRET_EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${RELEASE}
type: Opaque
stringData:
  DD_ADMIN_PASSWORD: "${DD_ADMIN_PW}"
  DD_SECRET_KEY: "${DD_SECRET_KEY_VAL}"
  DD_CREDENTIAL_AES_256_KEY: "${DD_AES_KEY_VAL}"
  METRICS_HTTP_AUTH_PASSWORD: "${DD_METRICS_PW}"
---
apiVersion: v1
kind: Secret
metadata:
  name: defectdojo-postgresql-specific
type: Opaque
stringData:
  postgresql-postgres-password: "${PG_POSTGRES_PW}"
  postgresql-password: "${PG_APP_PW}"
---
apiVersion: v1
kind: Secret
metadata:
  name: defectdojo-valkey-specific
type: Opaque
stringData:
  valkey-password: "${VALKEY_PW}"
SECRET_EOF
echo "    Secrets ${RELEASE}, defectdojo-postgresql-specific, defectdojo-valkey-specific applied from stdin"

echo "--- 6. install (D-15: first install only) ---"
# The 15m timeout is deliberate and must not be reduced: cold image pulls on a
# fresh kind node dominate. This is the ONLY install in this script, and there
# is no upgrade pass (D-15 defers upgrade/resync behaviour).
require_success "KIND-INSTALL" helm install "$RELEASE" "$CHART_DIR" --kube-context "$KIND_CONTEXT" \
  --namespace "$KIND_NS" \
  --set "defectdojo.host=${SMOKE_HOST}" \
  --set "defectdojo.siteUrl=https://${SMOKE_HOST}" \
  --set "defectdojo.django.ingress.annotations.cert-manager\\.io/cluster-issuer=${ISSUER_NAME}" \
  --wait --timeout 15m

print_summary
