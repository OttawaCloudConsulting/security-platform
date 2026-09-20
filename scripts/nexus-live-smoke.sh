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
# Likewise for the kind cluster. KIND_CREATED is the trap's ownership flag: it
# flips to 1 only AFTER `kind create cluster` has returned 0, so the trap can
# never delete a cluster this run did not create. See the ownership guard in
# section 7 for why that ordering is load-bearing rather than stylistic.
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

# run_provision: invoke the chart's own provisioning script with its environment
# contract satisfied.
#
# Shell PREFIX-ASSIGNMENT rather than `env VAR=... bash ...`: one fewer process
# in the chain and one fewer binary carrying the values as ARGUMENTS. Measured,
# so the comment does not overclaim: `env` execs into bash, and exec REPLACES
# the argv, so the old form left nothing observable in `ps` either. This is a
# simplification, not the closing of a demonstrated leak.
#
# It has to be a FUNCTION. require_success runs "$@", and a prefix-assignment is
# shell SYNTAX rather than a command, so passing it through "$@" would make bash
# search for a program literally named `NEXUS_HOST=http://...` and fail.
#
# NEXUS_PASSWORD reaches provision.sh through the environment, which is exactly
# how the chart's Job supplies it (secretKeyRef -> env). The smoke exercises the
# same contract the cluster does.
#
# The anonymous posture below is set to `true`, DELIBERATELY diverging from the
# chart's own shipped default of `false` — the same deliberate divergence this
# function already makes for the EULA. A public chart must not open
# unauthenticated read for whoever installs it without reading values.yaml, and
# a gate that never opens it cannot measure whether opening it works. The three
# ANONYMOUS_* variables are read unconditionally by provision.sh, so omitting
# them would kill this smoke under `set -u` rather than test anything.
#
# Setting it back to `false` is exactly reversion 1 of this file's non-vacuity
# procedure: the three anonymous checks in section 5 must all go red with HTTP
# 401. Do not leave it flipped.
#
# READY_ATTEMPTS and READY_INTERVAL match the chart defaults
# (provision.readiness.attempts / intervalSeconds) on purpose: this smoke must
# poll with the budget a real install polls with. provision.sh reads both from
# the environment with NO default, so `set -u` kills this function without them.
#
# SC2329 is disabled because this function IS invoked — indirectly, as the
# command require_success runs through "$@", which shellcheck cannot follow.
# shellcheck disable=SC2329
run_provision() {
  NEXUS_HOST="$NEXUS_HOST" \
  NEXUS_USER=admin \
  NEXUS_PASSWORD="$NEXUS_PASSWORD" \
  EULA_ACCEPTED=true \
  ANONYMOUS_ENABLED=true \
  ANONYMOUS_USER_ID=anonymous \
  ANONYMOUS_REALM_NAME=NexusAuthorizingRealm \
  READY_ATTEMPTS=60 \
  READY_INTERVAL=10 \
  REPO_CONFIG_DIR="$OUT/config" \
    bash "$PROVISION_SH"
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
# make `helm dependency build` in section 7 write mode-600 files into the
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
require_success "PROVISION-PASS-1" run_provision
echo

echo "--- 4. provision.sh pass 2 (idempotency) ---"
# The identical invocation. A repeat blind POST to the repositories API returns
# 400, so a second exit 0 is the only proof the GET->PUT/POST upsert is real.
require_success "PROVISION-PASS-2" run_provision
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

# ── Anonymous pull must be ALLOWED (NEXUS-02) ────────────────────────────────
# This slot used to assert the NEGATION of NEXUS-02 — that an unauthenticated
# fetch of the tarball above came back 401. Read the fence before reading the
# inversion: that check exists because Phase 23's own review found the claim
# "anonymous pull is deliberately not enabled" had nothing measuring it. It
# rested on a values key (`nexus3.config.anonymous.enabled`) that the subchart
# never reads while `config.enabled` is false — flipping that key produced a
# byte-identical render. The fence is not being removed here and its reason is
# unchanged: the posture must be MEASURED, never merely stated. What changed is
# that plan 24-01 gave the chart a value that genuinely reaches the server, and
# plan 24-02 opens it, so the direction the measurement runs in flips with it.
#
# The same URL the authenticated request above just fetched with HTTP 200, now
# with NO credentials at all. HTTP 200 plus a real body is the assertion: a 401
# here would mean the provisioning run failed to open anonymous read.
#
# Deliberately placed AFTER the authenticated download: by this point the EULA
# is accepted and the repository is proven to serve a real 318,961-byte tarball
# to an authenticated client, so a 401 here isolates AUTHORISATION rather than a
# missing repository, an unaccepted licence or an upstream outage.
#
# No `-u` and no `-K -`: sending no credential is the point of the check.
#
# THREE verdicts per ecosystem, not one, copying section 5's split: a curl
# transport error is a DIFFERENT failure from an HTTP verdict, and a status is
# not a size. The size half is not decoration. A Nexus whose EULA is unaccepted
# answers a component download with a perfectly well-formed HTTP 403 carrying a
# ~192-byte body, and a closed anonymous posture answers 401 with a zero-byte
# body; both sail straight past a bare status check, and a single if/elif chain
# would stop at the status and never reach the size at all.
#
# SIZE THRESHOLDS — a judgement, and the rule that produced it. Each threshold
# below was derived from the size MEASURED in the run that landed this commit,
# under two rules:
#   (1) at least ten times the 192-byte EULA refusal, so the floor genuinely
#       discriminates a refusal (and a zero-byte 401) from real content; and
#   (2) no more than HALF the measured size, so ordinary upstream drift — a new
#       lodash release, a new project version on PyPI, a chart added to the
#       jetstack index — cannot turn this gate red on its own.
# Do not "tighten" any of them to the measured value: that converts a gate that
# discriminates content from refusals into an upstream-content tripwire.

# npm — measured 318,961 bytes at HTTP 200, unauthenticated; floor 100,000
# (>= 1,920; <= 159,480). Same floor the authenticated ARTIFACT-SIZE check
# above uses, against the same URL and the same measured size.
ANON_NPM_MIN_BYTES=100000
anon_npm_code=""
anon_npm_rc=0
anon_npm_code="$(curl -sS -o "$OUT/anon-npm.tgz" -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 "$TARBALL_URL")" || anon_npm_rc=$?

if [ "$anon_npm_rc" -ne 0 ]; then
  fail "ANONYMOUS-PULL-ALLOWED-TRANSPORT" "curl exited ${anon_npm_rc} on the unauthenticated fetch of ${TARBALL_URL} (transport error, not an HTTP verdict)"
else
  pass "ANONYMOUS-PULL-ALLOWED-TRANSPORT" "unauthenticated curl completed against ${TARBALL_URL}"
fi

if [ "$anon_npm_code" = "200" ]; then
  pass "ANONYMOUS-PULL-ALLOWED-HTTP-200" "unauthenticated GET of ${TARBALL_URL} returned HTTP 200 - anonymous pull is OPEN"
else
  fail "ANONYMOUS-PULL-ALLOWED-HTTP-200" "unauthenticated GET of ${TARBALL_URL} returned HTTP ${anon_npm_code}, expected 200; 401 means anonymous read was never opened, 403 means the EULA was never accepted"
fi

if [ -f "$OUT/anon-npm.tgz" ]; then
  anon_npm_bytes="$(wc -c <"$OUT/anon-npm.tgz" | tr -d ' ')"
else
  anon_npm_bytes=0
fi
if [ "$anon_npm_bytes" -gt "$ANON_NPM_MIN_BYTES" ]; then
  pass "ANONYMOUS-PULL-ALLOWED-SIZE" "${anon_npm_bytes} bytes pulled with no credential (> ${ANON_NPM_MIN_BYTES})"
else
  fail "ANONYMOUS-PULL-ALLOWED-SIZE" "only ${anon_npm_bytes} bytes pulled with no credential, expected > ${ANON_NPM_MIN_BYTES}; ~192 bytes is the EULA refusal body and 0 bytes is the 401 challenge, neither of which is a tarball"
fi

# PyPI — the PER-PROJECT simple page, which is what `pip download` actually
# requests; the root /simple/ index is a different (and enormous) document and
# proves nothing about serving a project. The trailing slash is load-bearing:
# without it Nexus answers a redirect whose body is a few hundred bytes, which
# would be measured instead of the page.
# MEASURED BOUNDARY, recorded because it is counter-intuitive and because this
# check's size floor does NOT discriminate the same thing the npm and Helm
# floors do. With `eula.accepted=false`, the npm tarball and the Helm
# index.yaml both come back HTTP 403 with a 192-byte refusal body — and this
# simple page still comes back HTTP 200 with its full 76,776 bytes. The EULA
# gate covers COMPONENT downloads; a PyPI simple page is METADATA, which Nexus
# serves regardless. So the floor below earns its keep against the zero-byte
# 401 challenge — observed, by disabling anonymous access — and NOT against a
# licence refusal. Do not "fix" that by raising the floor: no byte count can
# discriminate a state in which the server returns the correct content.
#
# Measured 76,776 bytes at HTTP 200 for `requests`; floor 20,000
# (>= 1,920; <= 38,388). `requests` is the project because it is the one this
# smoke can reach through the upstream proxy on every run and its simple page
# is large enough for rule (2) to leave real headroom.
ANON_PYPI_PROJECT="requests"
ANON_PYPI_URL="${NEXUS_HOST}/repository/pypi-proxy/simple/${ANON_PYPI_PROJECT}/"
ANON_PYPI_MIN_BYTES=20000
anon_pypi_code=""
anon_pypi_rc=0
anon_pypi_code="$(curl -sS -o "$OUT/anon-pypi.html" -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 "$ANON_PYPI_URL")" || anon_pypi_rc=$?

if [ "$anon_pypi_rc" -ne 0 ]; then
  fail "ANONYMOUS-PULL-PYPI-TRANSPORT" "curl exited ${anon_pypi_rc} on the unauthenticated fetch of ${ANON_PYPI_URL} (transport error, not an HTTP verdict)"
else
  pass "ANONYMOUS-PULL-PYPI-TRANSPORT" "unauthenticated curl completed against ${ANON_PYPI_URL}"
fi

if [ "$anon_pypi_code" = "200" ]; then
  pass "ANONYMOUS-PULL-PYPI-HTTP-200" "unauthenticated GET of the ${ANON_PYPI_PROJECT} simple page returned HTTP 200"
else
  fail "ANONYMOUS-PULL-PYPI-HTTP-200" "unauthenticated GET of ${ANON_PYPI_URL} returned HTTP ${anon_pypi_code}, expected 200; 401 means anonymous read was never opened, 403 means the EULA was never accepted"
fi

if [ -f "$OUT/anon-pypi.html" ]; then
  anon_pypi_bytes="$(wc -c <"$OUT/anon-pypi.html" | tr -d ' ')"
else
  anon_pypi_bytes=0
fi
if [ "$anon_pypi_bytes" -gt "$ANON_PYPI_MIN_BYTES" ]; then
  pass "ANONYMOUS-PULL-PYPI-SIZE" "${anon_pypi_bytes} bytes of simple index pulled with no credential (> ${ANON_PYPI_MIN_BYTES})"
else
  fail "ANONYMOUS-PULL-PYPI-SIZE" "only ${anon_pypi_bytes} bytes pulled with no credential, expected > ${ANON_PYPI_MIN_BYTES}; 0 bytes is the 401 challenge, and a few hundred bytes is a redirect body from a URL missing its trailing slash - neither is a simple index. A 192-byte EULA refusal is deliberately NOT named here: measured, this endpoint is not behind the EULA gate (see the comment above it)"
fi

# Helm — the chart repository index. helm-proxy exists in this smoke ONLY
# because section 2 renders with `--set repos.helm.remoteUrl=...`; the chart
# ships that value null on purpose (D-05). If that --set is ever dropped the
# repository will not exist and this check MUST go red rather than skip — an
# absent repository is exactly the condition an anonymous-read gate has to be
# able to tell apart from a closed one, and 404 is not 200.
# Measured 291,818 bytes at HTTP 200 against https://charts.jetstack.io; floor
# 100,000 (>= 1,920; <= 145,909). Unlike the PyPI simple page above, this
# document IS behind the EULA gate — measured: `eula.accepted=false` turns it
# into the same HTTP 403 / 192-byte refusal an npm tarball gets. Nexus treats
# the Helm index as a component, not as metadata, so the floor here really does
# discriminate a refusal from content.
ANON_HELM_URL="${NEXUS_HOST}/repository/helm-proxy/index.yaml"
ANON_HELM_MIN_BYTES=100000
anon_helm_code=""
anon_helm_rc=0
anon_helm_code="$(curl -sS -o "$OUT/anon-helm-index.yaml" -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 "$ANON_HELM_URL")" || anon_helm_rc=$?

if [ "$anon_helm_rc" -ne 0 ]; then
  fail "ANONYMOUS-PULL-HELM-TRANSPORT" "curl exited ${anon_helm_rc} on the unauthenticated fetch of ${ANON_HELM_URL} (transport error, not an HTTP verdict)"
else
  pass "ANONYMOUS-PULL-HELM-TRANSPORT" "unauthenticated curl completed against ${ANON_HELM_URL}"
fi

if [ "$anon_helm_code" = "200" ]; then
  pass "ANONYMOUS-PULL-HELM-HTTP-200" "unauthenticated GET of ${ANON_HELM_URL} returned HTTP 200"
else
  fail "ANONYMOUS-PULL-HELM-HTTP-200" "unauthenticated GET of ${ANON_HELM_URL} returned HTTP ${anon_helm_code}, expected 200; 401 means anonymous read was never opened, 403 means the EULA was never accepted, 404 means the helm-proxy repository was never created"
fi

if [ -f "$OUT/anon-helm-index.yaml" ]; then
  anon_helm_bytes="$(wc -c <"$OUT/anon-helm-index.yaml" | tr -d ' ')"
else
  anon_helm_bytes=0
fi
if [ "$anon_helm_bytes" -gt "$ANON_HELM_MIN_BYTES" ]; then
  pass "ANONYMOUS-PULL-HELM-SIZE" "${anon_helm_bytes} bytes of chart index pulled with no credential (> ${ANON_HELM_MIN_BYTES})"
else
  fail "ANONYMOUS-PULL-HELM-SIZE" "only ${anon_helm_bytes} bytes pulled with no credential, expected > ${ANON_HELM_MIN_BYTES}; ~192 bytes is the EULA refusal body and 0 bytes is the 401 challenge, neither of which is a chart index"
fi
echo

echo "--- 6. Docker: realms, URL shape, the anonymous handshake and the write boundary ---"
# Docker is the fourth ecosystem and the only one whose anonymous read cannot be
# proven by a single unauthenticated GET. Section 5's three ecosystems are plain
# HTTP fetches. A registry is a multi-request protocol, and the request that
# carries the authorisation decision is not the first one.
#
# THE CORRECTION THIS SECTION EXISTS TO PRESERVE (24-RESEARCH.md Pitfall 4). A
# first causal test during this phase's research fetched
# /v2/docker-proxy/library/alpine/manifests/3.21 with NO Authorization header,
# saw HTTP 200 with the DockerToken realm removed, and concluded the realm was
# unnecessary. The realm IS necessary. A header-less 200
# must never be accepted as evidence that anonymous Docker pull works,
# because no Docker client emits that request. That exact test produced a wrong
# conclusion during this phase's research and was caught by review. What a real client does — and what
# ANONYMOUS-PULL-DOCKER below does — is ping /v2/, read the Bearer challenge,
# fetch a token, and PRESENT that token on every subsequent request. The
# presented token is the thing the realm validates.
#
# Measured against sonatype/nexus3:3.96.0-ubi with the chart's own
# docker.forceBasicAuth:false throughout:
#   realms ["NexusAuthenticatingRealm","DockerToken"] : ping 401, token 200, manifest+Bearer 200
#   realms ["NexusAuthenticatingRealm"]               : ping 401, token 200, manifest+Bearer 401
# The 401 in the second row also occurs for an ADMIN-issued token, and plain
# Basic auth is unaffected — so DockerToken governs bearer-token validation in
# general rather than anonymity in particular. Removing it is this section's
# non-vacuity reversion: legs 1-3 stay green and leg 4 turns red.
#
# ONE `pass` PER CHECK HERE, unlike section 5's three-verdicts-per-ecosystem
# split. Each check below is a SEQUENCE whose later legs are meaningless if an
# earlier one failed — a token that could not be obtained cannot be presented —
# so each emits at most one pass, emits a DISTINCT fail message per assertion it
# can reach, and the ordered ones return at the first red leg instead of
# reporting a cascade of derived failures that all have a single cause.

# ── DOCKER-REALM-ACTIVE (24-W0-06) ───────────────────────────────────────────
# The state that makes the handshake below possible, read back AFTER the two
# provisioning passes sections 3 and 4 already ran. No third provisioning loop
# is added: pass 2 is the harness this check needs, because both traps it guards
# against only appear on a REPEAT run.
#
# Three assertions, three separate failure messages, because the two ways
# `PUT /security/realms/active` goes wrong are opposites (24-RESEARCH.md
# Pitfall 3):
#   1. DockerToken absent      -> provision.sh never appended it; bearer tokens
#      will not validate and anonymous docker pull is dead.
#   2. DockerToken more than once -> the endpoint stores duplicates (measured:
#      ["NexusAuthenticatingRealm","DockerToken","DockerToken"] returns 204 and
#      reads back with both), so a blind `jq '. + ["DockerToken"]'` in a hook
#      Job that reruns on every `helm upgrade` grows the list without bound.
#   3. NexusAuthenticatingRealm absent -> the endpoint is a full REPLACEMENT,
#      not a patch, so a PUT of ["DockerToken"] alone locks every user out of
#      the instance, admin included. This is that lockout in its observable
#      form, and it is the reason this check reads the list rather than trusting
#      provision.sh's own exit code.
REALMS_URL="${NEXUS_HOST}/service/rest/v1/security/realms/active"
realms_rc=0
realms_code=""
realms_code="$(curl -sS -o "$OUT/realms-active.json" -w '%{http_code}' \
  --connect-timeout 5 --max-time 30 \
  -u admin:"$NEXUS_PASSWORD" "$REALMS_URL")" || realms_rc=$?

realms_ok=1
if [ "$realms_rc" -ne 0 ]; then
  fail "DOCKER-REALM-ACTIVE" "curl exited ${realms_rc} reading ${REALMS_URL} (transport error, not an HTTP verdict)"
  realms_ok=0
elif [ "$realms_code" != "200" ]; then
  fail "DOCKER-REALM-ACTIVE" "GET /service/rest/v1/security/realms/active returned HTTP ${realms_code}, expected 200; the realms list was never read, so the three assertions below measured nothing"
  realms_ok=0
elif ! jq -e 'type == "array"' "$OUT/realms-active.json" >/dev/null 2>&1; then
  fail "DOCKER-REALM-ACTIVE" "GET /service/rest/v1/security/realms/active returned HTTP 200 but a body that is not a JSON array"
  realms_ok=0
else
  realms_list="$(jq -c . "$OUT/realms-active.json")"
  docker_realm_count="$(jq '[.[] | select(. == "DockerToken")] | length' "$OUT/realms-active.json")"
  auth_realm_count="$(jq '[.[] | select(. == "NexusAuthenticatingRealm")] | length' "$OUT/realms-active.json")"

  if [ "$docker_realm_count" -eq 0 ]; then
    fail "DOCKER-REALM-ACTIVE" "DockerToken is ABSENT from the active realms ${realms_list}; provision.sh did not append it, so no bearer token this instance issues will validate and anonymous docker pull cannot work"
    realms_ok=0
  elif [ "$docker_realm_count" -ne 1 ]; then
    fail "DOCKER-REALM-ACTIVE" "DockerToken appears ${docker_realm_count} times in ${realms_list}, expected exactly once; the API stores duplicates (measured), so an append with no index() guard grows this list on every upgrade"
    realms_ok=0
  fi

  if [ "$auth_realm_count" -eq 0 ]; then
    fail "DOCKER-REALM-ACTIVE" "NexusAuthenticatingRealm is GONE from the active realms ${realms_list}; PUT /security/realms/active replaces the whole list, and a PUT that drops this realm locks every user out of the instance, admin included"
    realms_ok=0
  fi

  if [ "$realms_ok" -eq 1 ]; then
    pass "DOCKER-REALM-ACTIVE" "after two provisioning passes the active realms are ${realms_list} - DockerToken exactly once, NexusAuthenticatingRealm intact"
  fi
fi

# The image this section pulls through the proxy, and the two Accept header
# sets a registry client sends. The image index is negotiated with the OCI
# index / Docker manifest-list types; the per-platform child manifest with the
# single-manifest types. Without them the registry can legitimately refuse on
# content negotiation, which would look like an authorisation failure.
DOCKER_REPO="docker-proxy"
DOCKER_IMAGE_PATH="${DOCKER_REPO}/library/alpine"
DOCKER_IMAGE_TAG="3.21"
DOCKER_INDEX_ACCEPT='application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json'
DOCKER_MANIFEST_ACCEPT='application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
DOCKER_MANIFEST_URL="${NEXUS_HOST}/v2/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG}"
DOCKER_MANIFEST_URL_WRONG="${NEXUS_HOST}/v2/repository/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG}"

# ── DOCKER-PATH-SHAPE (24-W0-07) ─────────────────────────────────────────────
# Two unauthenticated requests, one check, two assertions. Docker is the ONLY
# one of the four ecosystems whose URL carries no `/repository/` segment: the
# client inserts `/v2/` immediately after the host, so with `pathEnabled: true`
# the repository name must be the FIRST path segment.
#
#   docker pull HOST/docker-proxy/library/alpine:3.21
#        -> GET /v2/docker-proxy/library/alpine/manifests/3.21             200
#   docker pull HOST/repository/docker-proxy/library/alpine:3.21
#        -> GET /v2/repository/docker-proxy/library/alpine/manifests/3.21  404
#
# The second assertion is why this check exists rather than being folded into
# the handshake below. `HOST/repository/<repo>/...` is CORRECT for npm, PyPI and
# Helm — all three of section 5's URLs use it — so the Docker line gets written
# the same way by analogy, in a README or in the workstation script, and every
# pull 404s at the first request. A gate that only measured the working shape
# would never catch that; this one asserts the wrong shape stays broken.
#
# A THIRD shape, /repository/docker-proxy/v2/library/alpine/manifests/3.21,
# also returns 200 — but no Docker client can construct it, so it is a curl and
# browser URL only and must never appear anywhere as a documented pull target.
# Note that the token endpoint the challenge below advertises IS under
# /repository/: that URL is SERVER-advertised and clients follow it verbatim, so
# it is not an instance of this trap and must not be "corrected".
#
# Both requests are deliberately header-less and credential-free. On their own
# they are NOT evidence of anonymous pull (see this section's opening comment);
# they measure routing, and routing is unaffected by the DockerToken realm —
# which is exactly what makes them the control for the handshake check below.
path_ok=1
path_right_rc=0
path_right_code=""
path_right_code="$(curl -sS -o /dev/null -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 \
  -H "Accept: ${DOCKER_INDEX_ACCEPT}" \
  "$DOCKER_MANIFEST_URL")" || path_right_rc=$?

if [ "$path_right_rc" -ne 0 ]; then
  fail "DOCKER-PATH-SHAPE" "curl exited ${path_right_rc} on ${DOCKER_MANIFEST_URL} (transport error, not an HTTP verdict)"
  path_ok=0
elif [ "$path_right_code" != "200" ]; then
  fail "DOCKER-PATH-SHAPE" "${DOCKER_MANIFEST_URL} returned HTTP ${path_right_code}, expected 200; this is the path a real 'docker pull HOST/${DOCKER_IMAGE_PATH}:${DOCKER_IMAGE_TAG}' constructs, so a non-200 here means the documented pull reference does not route"
  path_ok=0
fi

path_wrong_rc=0
path_wrong_code=""
path_wrong_code="$(curl -sS -o /dev/null -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 \
  -H "Accept: ${DOCKER_INDEX_ACCEPT}" \
  "$DOCKER_MANIFEST_URL_WRONG")" || path_wrong_rc=$?

if [ "$path_wrong_rc" -ne 0 ]; then
  fail "DOCKER-PATH-SHAPE" "curl exited ${path_wrong_rc} on ${DOCKER_MANIFEST_URL_WRONG} (transport error, not an HTTP verdict)"
  path_ok=0
elif [ "$path_wrong_code" != "404" ]; then
  fail "DOCKER-PATH-SHAPE" "${DOCKER_MANIFEST_URL_WRONG} returned HTTP ${path_wrong_code}, expected 404; the '/repository/' prefix is correct for npm, PyPI and Helm and WRONG for Docker only, and this assertion exists so a documentation copy-paste that adds it by analogy is caught here instead of at pull time"
  path_ok=0
fi

if [ "$path_ok" -eq 1 ]; then
  pass "DOCKER-PATH-SHAPE" "/v2/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG} is 200 and /v2/repository/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG} is 404 - the documented Docker reference is the one that routes"
fi

# ── ANONYMOUS-PULL-DOCKER (24-W0-05) ─────────────────────────────────────────
# The request sequence a real Docker client performs, with no credential on any
# leg. A function because the legs are ORDERED and each consumes what the
# previous produced: a failed leg returns immediately rather than reporting
# four derived failures with one cause.
#
# Leg 5's byte floor: 1,000,000. Derived from the alpine 3.21 amd64 LAYER blob
# measured by this very check against this instance (see the SUMMARY for the
# run), under the same two rules section 5 states — at least ten times a refusal
# body, and no more than half the measured size, so upstream drift cannot turn
# the gate red on its own. It is deliberately NOT derived from the 8,083,968
# bytes a full `crane export` of this image streams: that number is the whole
# filesystem across every layer, and this leg fetches ONE blob.
DOCKER_BLOB_MIN_BYTES=1000000
check_anonymous_pull_docker() {
  local ping_rc=0 ping_code="" challenge="" realm="" service=""
  local token_rc=0 token_code="" token=""
  local man_rc=0 man_code="" child="" layer=""
  local child_rc=0 child_code=""
  local blob_rc=0 blob_out="" blob_code="" blob_bytes=""

  # Leg 1 — the ping. Every client starts here and every client expects to be
  # challenged. A 200 is a FAILURE, not a shortcut: it would mean the registry
  # is not issuing Bearer challenges at all, leaving legs 2-5 with nothing to
  # follow and nothing to measure.
  ping_code="$(curl -sS -o /dev/null -D "$OUT/docker-v2-ping.h" -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 "${NEXUS_HOST}/v2/")" || ping_rc=$?
  if [ "$ping_rc" -ne 0 ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 1 (GET /v2/): curl exited ${ping_rc} (transport error, not an HTTP verdict)"
    return 0
  fi
  if [ "$ping_code" != "401" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 1 (GET /v2/) returned HTTP ${ping_code}, expected 401; a 200 here is a failure rather than a shortcut, because it means the registry never issued a Bearer challenge and the remaining four legs would measure nothing"
    return 0
  fi
  if ! challenge="$(tr -d '\r' <"$OUT/docker-v2-ping.h" | grep -i '^www-authenticate: *bearer')"; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 1 (GET /v2/) returned 401 but carried no 'WWW-Authenticate: Bearer' header; a Basic-only challenge means no token endpoint is advertised and a Docker client cannot proceed"
    return 0
  fi

  # Leg 2 — parse the challenge. PARSED, never hardcoded to the values this
  # phase's research happened to observe: a hardcoded realm/service pair would
  # keep passing against a server whose challenge had changed or stopped, which
  # is precisely the failure this handshake exists to catch.
  realm="$(printf '%s' "$challenge" | sed -n 's/.*[Rr]ealm="\([^"]*\)".*/\1/p')"
  service="$(printf '%s' "$challenge" | sed -n 's/.*[Ss]ervice="\([^"]*\)".*/\1/p')"
  if [ -z "$realm" ] || [ -z "$service" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 2: could not parse both realm and service out of the challenge [${challenge}]; got realm='${realm}' service='${service}'"
    return 0
  fi

  # Leg 3 — the token, with no credential supplied. --data-urlencode because
  # both the service and the scope are values, not URL structure: service is
  # itself a URL and the scope contains ':' and '/'.
  token_code="$(curl -sS -o "$OUT/docker-token.json" -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 \
    -G --data-urlencode "service=${service}" \
       --data-urlencode "scope=repository:${DOCKER_IMAGE_PATH}:pull" \
    "$realm")" || token_rc=$?
  if [ "$token_rc" -ne 0 ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 3 (token from ${realm}): curl exited ${token_rc} (transport error, not an HTTP verdict)"
    return 0
  fi
  if [ "$token_code" != "200" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 3: the advertised token endpoint ${realm} returned HTTP ${token_code}, expected 200; an unauthenticated client cannot obtain a token, so legs 4 and 5 have nothing to present"
    return 0
  fi
  if ! jq -e 'type == "object"' "$OUT/docker-token.json" >/dev/null 2>&1; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 3: the token endpoint returned HTTP 200 with a body that is not a JSON object"
    return 0
  fi
  token="$(jq -r '.token // empty' "$OUT/docker-token.json")"
  if [ -z "$token" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 3: the token endpoint returned HTTP 200 but no non-empty .token field"
    return 0
  fi

  # Leg 4 — the manifest index, WITH the bearer token. This is the evidence.
  # A 401 here while legs 1-3 stayed green is the DockerToken-inactive
  # signature: the challenge is still issued and the token is still minted, and
  # only the PRESENTED token fails to validate.
  man_code="$(curl -sS -o "$OUT/docker-index.json" -w '%{http_code}' \
    --connect-timeout 5 --max-time 60 \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: ${DOCKER_INDEX_ACCEPT}" \
    "$DOCKER_MANIFEST_URL")" || man_rc=$?
  if [ "$man_rc" -ne 0 ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 4 (bearer manifest GET of ${DOCKER_MANIFEST_URL}): curl exited ${man_rc} (transport error, not an HTTP verdict)"
    return 0
  fi
  if [ "$man_code" != "200" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 4: ${DOCKER_MANIFEST_URL} with 'Authorization: Bearer' returned HTTP ${man_code}, expected 200; a 401 here with legs 1-3 green means the DockerToken realm is not active, since the challenge and the token are unaffected by it and only the presented token fails to validate"
    return 0
  fi
  if ! jq -e 'has("manifests") or has("layers")' "$OUT/docker-index.json" >/dev/null 2>&1; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 4: ${DOCKER_MANIFEST_URL} returned HTTP 200 but a body that does not parse as JSON carrying 'manifests' or 'layers'; a well-formed non-manifest body at 200 is exactly what a content-negotiation refusal or an error document looks like"
    return 0
  fi

  # Leg 5 — follow a reference from that document down to a real blob, so the
  # blob path is exercised and not merely the manifest. The amd64/linux entry
  # is selected by platform rather than by position: the proxy serves the full
  # upstream index regardless of the host architecture this smoke runs on, so
  # the choice is workstation-independent, and selecting by platform also skips
  # the attestation entries, whose platform is unknown/unknown.
  if jq -e 'has("manifests")' "$OUT/docker-index.json" >/dev/null 2>&1; then
    child="$(jq -r '[.manifests[]? | select(.platform.os == "linux" and .platform.architecture == "amd64")][0].digest // empty' "$OUT/docker-index.json")"
    if [ -z "$child" ]; then
      fail "ANONYMOUS-PULL-DOCKER" "leg 5: the image index carries no linux/amd64 manifest entry, so no layer digest can be resolved from it"
      return 0
    fi
    child_code="$(curl -sS -o "$OUT/docker-manifest.json" -w '%{http_code}' \
      --connect-timeout 5 --max-time 60 \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: ${DOCKER_MANIFEST_ACCEPT}" \
      "${NEXUS_HOST}/v2/${DOCKER_IMAGE_PATH}/manifests/${child}")" || child_rc=$?
    if [ "$child_rc" -ne 0 ]; then
      fail "ANONYMOUS-PULL-DOCKER" "leg 5 (bearer manifest GET of ${child}): curl exited ${child_rc} (transport error, not an HTTP verdict)"
      return 0
    fi
    if [ "$child_code" != "200" ]; then
      fail "ANONYMOUS-PULL-DOCKER" "leg 5: the linux/amd64 child manifest ${child} returned HTTP ${child_code} with 'Authorization: Bearer', expected 200"
      return 0
    fi
    layer="$(jq -r '.layers[0].digest // empty' "$OUT/docker-manifest.json")"
  else
    layer="$(jq -r '.layers[0].digest // empty' "$OUT/docker-index.json")"
  fi
  if [ -z "$layer" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 5: no layer digest could be read from the manifest, so no blob reference exists to follow"
    return 0
  fi

  blob_out="$(curl -sS -o /dev/null -w '%{http_code} %{size_download}' \
    --connect-timeout 5 --max-time 180 -L \
    -H "Authorization: Bearer ${token}" \
    "${NEXUS_HOST}/v2/${DOCKER_IMAGE_PATH}/blobs/${layer}")" || blob_rc=$?
  if [ "$blob_rc" -ne 0 ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 5 (bearer blob GET of ${layer}): curl exited ${blob_rc} (transport error, not an HTTP verdict)"
    return 0
  fi
  blob_code="${blob_out%% *}"
  blob_bytes="${blob_out##* }"
  if [ "$blob_code" != "200" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 5: the layer blob ${layer} returned HTTP ${blob_code} with 'Authorization: Bearer', expected 200; the manifest is reachable but the blob path is not, so no client could complete a pull"
    return 0
  fi
  if [ "$blob_bytes" -le "$DOCKER_BLOB_MIN_BYTES" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 5: only ${blob_bytes} bytes of layer blob streamed, expected > ${DOCKER_BLOB_MIN_BYTES}; a few hundred bytes is an error document or a challenge page, not an image layer"
    return 0
  fi

  pass "ANONYMOUS-PULL-DOCKER" "full anonymous client handshake: GET /v2/ -> 401 + Bearer challenge; token minted at ${realm} with no credential; ${DOCKER_MANIFEST_URL} -> 200 WITH Authorization: Bearer; linux/amd64 layer ${layer} streamed ${blob_bytes} bytes (> ${DOCKER_BLOB_MIN_BYTES})"
}
check_anonymous_pull_docker

# ── ANONYMOUS-WRITE-DENIED (24-W0-08) ────────────────────────────────────────
# The boundary anonymous READ must not cross. Anonymous is open across every
# repository on this instance by now; this check asserts that opening read did
# not open write.
#
# THE BODY MUST BE STRUCTURALLY VALID, and that is the whole subtlety
# (24-RESEARCH.md Pitfall 5). Nexus validates the request body BEFORE it
# authorises: measured, `{"name":"evil"}` returns 400 and the same endpoint with
# a fully valid npm proxy body returns 403. A check that accepted "not 2xx", or
# whose expected-status list read 400,401,403, would pass on the malformed body
# for a reason that has nothing to do with authorisation — and would keep
# passing on the day anonymous write was genuinely open, because the 400 would
# still come back first. So: a valid body, and EXACTLY 403.
#
# The body is built with `jq -n` in the same shape the chart's own -repos
# ConfigMap ships for the npm format, under a name that does not exist on this
# instance, and the npm proxy REMOTE URL is never contacted: a 403 is answered
# before any repository is created.
#
# The third assertion is not decoration. An admin GET of a name that was never
# created returns 404 — but so does a GET at a URL shape that does not exist,
# which would make the "nothing was created" proof vacuous in the exact way
# Pitfall 5 describes for the POST. So the same URL shape is first exercised
# against a repository that DOES exist (the chart's own npm proxy, whose name is
# read from the rendered body rather than hardcoded) and must return 200.
ANON_WRITE_REPO="anon-write-probe"
ANON_WRITE_POST_URL="${NEXUS_HOST}/service/rest/v1/repositories/npm/proxy"
NPM_REPO_NAME="$(jq -r '.name' "$OUT/config/000-npm.json")"
jq -n --arg name "$ANON_WRITE_REPO" '{
  name: $name,
  online: true,
  storage: {blobStoreName: "default", strictContentTypeValidation: true},
  proxy: {remoteUrl: "https://registry.npmjs.org", contentMaxAge: 1440, metadataMaxAge: 1440},
  negativeCache: {enabled: true, timeToLive: 1440},
  httpClient: {blocked: false, autoBlock: true}
}' >"$OUT/anon-write-body.json"

write_ok=1
anon_write_rc=0
anon_write_code=""
anon_write_code="$(curl -sS -o "$OUT/anon-write-response.txt" -w '%{http_code}' \
  --connect-timeout 5 --max-time 30 \
  -X POST -H 'Content-Type: application/json' \
  --data-binary "@$OUT/anon-write-body.json" \
  "$ANON_WRITE_POST_URL")" || anon_write_rc=$?

if [ "$anon_write_rc" -ne 0 ]; then
  fail "ANONYMOUS-WRITE-DENIED" "curl exited ${anon_write_rc} POSTing to ${ANON_WRITE_POST_URL} (transport error, not an HTTP verdict)"
  write_ok=0
elif [ "$anon_write_code" = "200" ] || [ "$anon_write_code" = "201" ] || [ "$anon_write_code" = "204" ]; then
  fail "ANONYMOUS-WRITE-DENIED" "PRIVILEGE ESCALATION REGRESSION: an unauthenticated POST to ${ANON_WRITE_POST_URL} returned HTTP ${anon_write_code} and CREATED a repository. Anonymous read has become anonymous write; remove repository '${ANON_WRITE_REPO}' from this instance and treat this as a security defect, not a flaky check"
  write_ok=0
elif [ "$anon_write_code" != "403" ]; then
  fail "ANONYMOUS-WRITE-DENIED" "unauthenticated POST to ${ANON_WRITE_POST_URL} returned HTTP ${anon_write_code}, expected exactly 403; 400 means the body was rejected as malformed BEFORE authorisation was ever consulted, which proves nothing about the write boundary, and 401 means the anonymous identity was not even resolved"
  write_ok=0
fi

npm_get_rc=0
npm_get_code=""
npm_get_code="$(curl -sS -o /dev/null -w '%{http_code}' \
  --connect-timeout 5 --max-time 30 \
  -u admin:"$NEXUS_PASSWORD" \
  "${ANON_WRITE_POST_URL}/${NPM_REPO_NAME}")" || npm_get_rc=$?

if [ "$npm_get_rc" -ne 0 ]; then
  fail "ANONYMOUS-WRITE-DENIED" "curl exited ${npm_get_rc} on the admin GET of the existing repository ${NPM_REPO_NAME} (transport error, not an HTTP verdict)"
  write_ok=0
elif [ "$npm_get_code" != "200" ]; then
  fail "ANONYMOUS-WRITE-DENIED" "the admin GET of the EXISTING repository ${NPM_REPO_NAME} returned HTTP ${npm_get_code}, expected 200; this URL shape is the instrument the non-creation assertion below depends on, and an instrument that 404s on everything would prove nothing"
  write_ok=0
fi

probe_get_rc=0
probe_get_code=""
probe_get_code="$(curl -sS -o /dev/null -w '%{http_code}' \
  --connect-timeout 5 --max-time 30 \
  -u admin:"$NEXUS_PASSWORD" \
  "${ANON_WRITE_POST_URL}/${ANON_WRITE_REPO}")" || probe_get_rc=$?

if [ "$probe_get_rc" -ne 0 ]; then
  fail "ANONYMOUS-WRITE-DENIED" "curl exited ${probe_get_rc} on the admin GET of ${ANON_WRITE_REPO} (transport error, not an HTTP verdict)"
  write_ok=0
elif [ "$probe_get_code" != "404" ]; then
  fail "ANONYMOUS-WRITE-DENIED" "the admin GET of ${ANON_WRITE_REPO} returned HTTP ${probe_get_code}, expected 404; the anonymous POST was refused but something by that name exists, so the refusal did not prevent creation"
  write_ok=0
fi

if [ "$write_ok" -eq 1 ]; then
  pass "ANONYMOUS-WRITE-DENIED" "an unauthenticated POST of a structurally valid npm proxy body returned HTTP 403 and created nothing (admin GET of ${ANON_WRITE_REPO} is 404, while the same URL shape returns 200 for the existing ${NPM_REPO_NAME}) - anonymous read does not extend to write"
fi
echo

echo "--- 7. kind install smoke ---"
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
# ── Ownership guard: never delete a cluster this run did not create ──────────
# KIND_CLUSTER is a FIXED name, so it can collide with a cluster the operator
# already owns, and the EXIT trap deletes $KIND_CLUSTER unconditionally once
# KIND_CREATED is 1. Measured on kind v0.33.0: a colliding `kind create cluster`
# exits 1 with `node(s) already exist for a cluster with the name "..."`. So
# setting the ownership flag BEFORE the call turned a mere name collision into
# the DELETION of somebody else's cluster — a failed create, then a trap that
# tore down the pre-existing cluster on the way out. Refuse the run instead.
#
# `kind get clusters` prints bare cluster names on stdout, one per line
# (measured, kind v0.33.0); the empty-list message "No kind clusters found."
# goes to STDERR, so an empty list cannot match and the guard cannot misfire.
# `grep -qx` anchors both ends: a cluster merely PREFIXED nexus-smoke is a
# different cluster and must not trip this.
if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER"; then
  echo "FATAL: cluster ${KIND_CLUSTER} already exists, refusing to touch it" >&2
  echo "       This smoke deletes the cluster it creates, and it did not create that one." >&2
  echo "       If it is a leftover from an earlier run, remove it yourself:" >&2
  echo "         kind delete cluster --name ${KIND_CLUSTER}" >&2
  exit 1
fi

echo "    creating cluster ${KIND_CLUSTER} (this is the slow part)"
kind_rc=0
kind create cluster --name "$KIND_CLUSTER" >/dev/null 2>&1 || kind_rc=$?
if [ "$kind_rc" -ne 0 ]; then
  # Deliberately NOT claiming ownership on a failed create. The cost is that a
  # HALF-built cluster is left behind rather than torn down; the benefit is that
  # a collision can never delete an operator's cluster. The leftover is loud,
  # not silent: the guard above FATALs on the next run and names the fix.
  fail "KIND-CLUSTER" "kind create cluster --name ${KIND_CLUSTER} exited ${kind_rc}; if it left a partial cluster behind, remove it with: kind delete cluster --name ${KIND_CLUSTER}"
  print_summary
fi
# Ownership claimed only now: `kind create cluster` returned 0, so the cluster
# the trap deletes is unambiguously this run's.
KIND_CREATED=1
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
