#!/usr/bin/env bash
set -euo pipefail

# a3-dind-probe.sh — the measurement behind Assumption A3.
#
# THE QUESTION. 24-CONTEXT.md decides that workstation/nexus-setup.sh writes a
# Docker `registry-mirrors` entry pointing at a path-routed Nexus Docker proxy
# (`HOST/docker-proxy/...`, `docker.pathEnabled: true`). 24-RESEARCH.md records
# that decision's foundation as UNMEASURED (Assumption A3): Docker mirrors may
# only mirror Docker Hub, and may require the mirror at the registry root, in
# which case the key would configure a route that routes nothing.
#
# WHY IT IS MEASURED HERE AND NOT ON THE HOST. Answering it the obvious way
# means editing the operator's own ~/.docker/daemon.json and restarting their
# engine. This script NEVER does that. Every engine-level action happens inside
# a throwaway `docker:28.3.2-dind` container. The host daemon.json is
# checksummed on entry and re-checked in the EXIT trap; a mismatch is a loud
# failure, not a warning.
#
# WHAT COUNTS AS PROOF. Not `docker pull` exit 0. Docker's mirror logic falls
# back to the upstream registry on ANY mirror error, so a successful pull is
# equally consistent with the mirror having been ignored entirely. The verdict
# rests on the Nexus components endpoint:
#
#   GET /service/rest/v1/components?repository=docker-proxy
#
# returning zero items BEFORE the pull and items naming library/alpine AFTER it.
# That delta can only be produced by traffic that actually reached Nexus.
#
# TWO CANDIDATES, because there are two plausible mirror URLs and only a
# measurement distinguishes them (24-RESEARCH.md Pattern 6):
#
#   candidate-1  http://a3-nexus:8081/repository/docker-proxy
#                daemon appends /v2/ -> /repository/docker-proxy/v2/...  (curl: 200)
#   candidate-2  http://a3-nexus:8081/docker-proxy
#                daemon appends /v2/ -> /docker-proxy/v2/...             (not a measured shape)
#
# TWO CONTROLS, because an unattributed non-zero exit proves nothing:
#
#   control-empty  `{}`                              MUST validate  (the harness works)
#   control-query  http://a3-nexus:8081/x?y=1        MUST be rejected (--validate really
#                                                    inspects registry-mirrors; moby
#                                                    v28.3.2 ValidateMirror rejects a
#                                                    query string)
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash .planning/phases/24-.../24-evidence/a3-dind-probe.sh [--validate-only]
#
# Resource isolation (24-04-PLAN.md): this probe owns host port 8082 and the
# container/network name prefix `a3-`. The live smoke owns 8081, the --verify
# harness owns 8083.
#
# Exit codes:
#   0  the probe ran to completion; read the printed report for the verdict
#   1  the probe could not render a verdict (missing tool, dirty cache, boot
#      failure), or the host daemon.json changed underneath it

# ── Constants ────────────────────────────────────────────────────────────────

# Pinned by digest, not by tag (ADR-004 house rule). `docker:28.3.2-dind` is
# chosen over `docker:28-dind` deliberately: it is EXACTLY version-matched to
# the host engine this phase targets (Docker 28.3.2), which removes the
# "the probe measured a different engine" caveat from the evidence.
DIND_IMAGE="docker@sha256:44383404ebf0c36243f5969f0dddd23c204ea3bb185e7473a4141f6ccfd07b53"
DIND_REF_HUMAN="docker:28.3.2-dind"

NET="a3-net"
NEXUS_CONTAINER="a3-nexus"
DIND_CONTAINER="a3-dind"
VALIDATE_CONTAINER="a3-validate"

# The host-side address of the throwaway Nexus. The DIND-side address is
# different and must not be confused with it: the nested engine resolves
# `a3-nexus:8081` over the user-defined network, while this script (and
# provision.sh, which runs on the host) talks to 127.0.0.1:8082.
HOST_PORT=8082
NEXUS_URL="http://127.0.0.1:${HOST_PORT}"
DIND_NEXUS_HOST="${NEXUS_CONTAINER}:8081"

CAND1_URL="http://${DIND_NEXUS_HOST}/repository/docker-proxy"
CAND2_URL="http://${DIND_NEXUS_HOST}/docker-proxy"

PULL_REF="alpine:3.21"

# Where the chart lives. This probe drives the SHIPPED provisioning script, not
# a hand-made Nexus, so the evidence is about the chart rather than about a
# convenient approximation.
PROBE_DIR="$(cd "$(dirname "$0")" && pwd)"
SP_ROOT="${SP_ROOT:-$(cd "${PROBE_DIR}/../../../../repos/security-platform" && pwd)}"
PROVISION_SH="${SP_ROOT}/kubernetes/nexus/files/provision.sh"

VALIDATE_ONLY=0
if [ "${1:-}" = "--validate-only" ]; then
  VALIDATE_ONLY=1
fi

# ── T-24-17: the operator's daemon.json is never written ─────────────────────
# Captured BEFORE anything else runs and asserted again in the EXIT trap. A
# recorded absence is as valid a baseline as a checksum.
HOST_DAEMON_JSON="${HOME}/.docker/daemon.json"
daemon_fingerprint() {
  if [ -f "$HOST_DAEMON_JSON" ]; then
    shasum "$HOST_DAEMON_JSON" | awk '{print $1}'
  else
    echo "ABSENT"
  fi
}
DAEMON_SHA_BEFORE="$(daemon_fingerprint)"

OUT="$(mktemp -d)"

# Teardown is best-effort BY DESIGN — `|| true` here is cleanup hygiene on
# containers that may or may not exist, not a silenced assertion. No verdict is
# derived from any of it. `-v` on the removals matters: the dind image declares
# VOLUME /var/lib/docker, so a plain `docker rm -f` leaves an anonymous volume
# behind that `docker ps -a --filter name=a3-` would not reveal.
cleanup() {
  local rc=$?
  rm -rf "$OUT"
  docker rm -f -v "$DIND_CONTAINER" >/dev/null 2>&1 || true
  docker rm -f -v "$NEXUS_CONTAINER" >/dev/null 2>&1 || true
  docker rm -f -v "$VALIDATE_CONTAINER" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  local after
  after="$(daemon_fingerprint)"
  echo
  echo "=== T-24-17 host daemon.json assertion ==="
  echo "    path:   ${HOST_DAEMON_JSON}"
  echo "    before: ${DAEMON_SHA_BEFORE}"
  echo "    after:  ${after}"
  if [ "$after" != "$DAEMON_SHA_BEFORE" ]; then
    echo "    FATAL: the host daemon.json CHANGED during this run. The probe's" >&2
    echo "           central invariant is broken; treat every result above as void." >&2
    exit 1
  fi
  echo "    UNCHANGED"
  exit "$rc"
}
trap cleanup EXIT

# ── Preflight ────────────────────────────────────────────────────────────────
for bin in docker curl jq yq helm shasum; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 1
  fi
done

if [ ! -f "$PROVISION_SH" ] && [ "$VALIDATE_ONLY" -eq 0 ]; then
  echo "FATAL: ${PROVISION_SH} not found; the routing stage drives the chart's own script" >&2
  exit 1
fi

# ── Isolated client config, because the host credential helper is wedged ─────
# MEASURED on this workstation, 2026-09-19: `docker pull` produces NO output and
# never returns. Root cause, isolated by bisection:
#
#   echo "https://index.docker.io/v1/" | docker-credential-desktop get
#
# hangs indefinitely (killed at 20s). ~/.docker/config.json sets
# `"credsStore": "desktop"` with an empty `auths` entry for index.docker.io, so
# the CLI blocks on the helper BEFORE it ever contacts a registry — which is why
# the failure is silent. The Docker Desktop VM's own network is healthy
# (`getent hosts registry-1.docker.io` resolves and an in-container HTTPS request
# to /v2/ returns the expected 401 from inside a running container).
#
# The fix must not touch the operator's ~/.docker/config.json. Instead the probe
# points DOCKER_CONFIG at a throwaway directory holding `{}` — no credsStore, no
# auths — so Hub pulls proceed ANONYMOUSLY. Every image this probe pulls is a
# public library image, so anonymous is sufficient. DOCKER_HOST is resolved from
# the operator's active context FIRST, because an empty config.json carries no
# `currentContext` and the CLI would otherwise fail to find the daemon endpoint.
#
# This changes nothing on the host: DOCKER_CONFIG is a CLIENT-side directory.
# ~/.docker/daemon.json is read by the daemon and is untouched — the assertion
# above and in the EXIT trap still covers it.
if [ -z "${DOCKER_HOST:-}" ]; then
  DOCKER_HOST="$(docker context inspect "$(docker context show)" --format '{{.Endpoints.docker.Host}}')"
fi
export DOCKER_HOST
mkdir -p "${OUT}/dockercfg"
printf '{}' >"${OUT}/dockercfg/config.json"
export DOCKER_CONFIG="${OUT}/dockercfg"

echo "=== a3-dind-probe: Assumption A3 ==="
echo "    dind image:  ${DIND_REF_HUMAN}"
echo "    pinned as:   ${DIND_IMAGE}"
echo "    host engine: $(docker version --format '{{.Server.Version}}')"
echo "    mode:        $([ "$VALIDATE_ONLY" -eq 1 ] && echo '--validate-only (stage 1)' || echo 'full (stage 1 + stage 2)')"
echo "    DOCKER_HOST: ${DOCKER_HOST}"
echo "    DOCKER_CONFIG (throwaway, anonymous): ${DOCKER_CONFIG}"
echo

# ── Stage 1: does a path-bearing mirror URL even parse? ──────────────────────
# `dockerd --validate` parses the configuration and exits WITHOUT starting an
# engine, so this answers the parse question with no privileged container, no
# bind mount of the host filesystem, and no engine lifecycle at all. The config
# is handed in through the environment and written inside the container, which
# also avoids depending on Docker Desktop's host-path sharing rules.
VALIDATE_RESULTS="${OUT}/validate-results.txt"
: >"$VALIDATE_RESULTS"

validate_config() {
  local label="$1" desc="$2" json="$3"
  local out rc=0
  out="$(docker run --rm --name "$VALIDATE_CONTAINER" \
    -e "A3_CFG=${json}" \
    --entrypoint sh "$DIND_IMAGE" \
    -c 'printf "%s" "$A3_CFG" > /tmp/a3-daemon.json; dockerd --validate --config-file /tmp/a3-daemon.json' 2>&1)" || rc=$?
  echo "--- ${label} (${desc})"
  echo "    config:  ${json}"
  echo "    exit:    ${rc}"
  if [ -n "$out" ]; then
    printf '    output:  %s\n' "$out"
  else
    echo "    output:  (none)"
  fi
  echo
  printf '%s\t%s\t%s\n' "$label" "$rc" "${out//$'\n'/ }" >>"$VALIDATE_RESULTS"
}

echo "--- Stage 1: dockerd --validate ---"
# Pulled explicitly rather than implicitly by the first `docker run`, so the
# pull's progress output does not land inside the first candidate's captured
# stderr and get mistaken for a validation message.
echo "    pre-pulling the pinned dind image (quiet)"
docker pull --quiet "$DIND_IMAGE" >/dev/null
echo

validate_config "control-empty" "an empty config — MUST validate, or the harness itself is broken" \
  '{}'
validate_config "control-query" "a mirror with a query string — MUST be rejected, or --validate is not reading registry-mirrors" \
  "{\"registry-mirrors\":[\"http://${DIND_NEXUS_HOST}/x?y=1\"]}"
validate_config "candidate-1" "the /repository/-bearing mirror URL" \
  "{\"registry-mirrors\":[\"${CAND1_URL}\"],\"insecure-registries\":[\"${DIND_NEXUS_HOST}\"]}"
validate_config "candidate-2" "the path-only mirror URL" \
  "{\"registry-mirrors\":[\"${CAND2_URL}\"],\"insecure-registries\":[\"${DIND_NEXUS_HOST}\"]}"

rc_of() { awk -F'\t' -v l="$1" '$1==l {print $2}' "$VALIDATE_RESULTS"; }

CONTROL_EMPTY_RC="$(rc_of control-empty)"
CONTROL_QUERY_RC="$(rc_of control-query)"
CAND1_VALIDATE_RC="$(rc_of candidate-1)"
CAND2_VALIDATE_RC="$(rc_of candidate-2)"

echo "--- Stage 1 controls ---"
if [ "$CONTROL_EMPTY_RC" != "0" ]; then
  echo "FATAL: control-empty did not validate (exit ${CONTROL_EMPTY_RC}); the harness is broken and" >&2
  echo "       no conclusion may be drawn from the candidate rows above." >&2
  exit 1
fi
echo "    control-empty:  exit 0 as required — the harness works"
if [ "$CONTROL_QUERY_RC" = "0" ]; then
  echo "FATAL: control-query VALIDATED (exit 0). --validate is not inspecting registry-mirrors," >&2
  echo "       so a candidate passing validation would be a vacuous pass." >&2
  exit 1
fi
echo "    control-query:  exit ${CONTROL_QUERY_RC} as required — --validate really inspects registry-mirrors"
echo

# Per 24-04-PLAN.md Task 1: if BOTH candidates are rejected at validation, the
# mechanism cannot work, the routing stage has nothing to measure, and A3 is
# CONFIRMED. Do not manufacture a workaround.
if [ "$CAND1_VALIDATE_RC" != "0" ] && [ "$CAND2_VALIDATE_RC" != "0" ]; then
  echo "RESULT: BOTH candidates were REJECTED by dockerd --validate."
  echo "        A path-bearing registry-mirrors URL does not parse on this engine."
  echo "        The routing stage is SKIPPED — there is nothing left to measure."
  echo "        Suggested verdict: A3-CONFIRMED"
  exit 0
fi

if [ "$VALIDATE_ONLY" -eq 1 ]; then
  echo "Stage 1 complete (--validate-only). Re-run without the flag for the routing measurement."
  exit 0
fi

# ── Stage 2: does the mirror actually ROUTE? ─────────────────────────────────

# `if` rather than `[ … ] && SURVIVORS+=(…)`: under `set -e` a standalone
# short-circuit whose test is false exits the script, which would turn "one
# candidate was rejected at validation" into a silent abort of the whole probe.
SURVIVORS=()
if [ "$CAND1_VALIDATE_RC" = "0" ]; then SURVIVORS+=("candidate-1"); fi
if [ "$CAND2_VALIDATE_RC" = "0" ]; then SURVIVORS+=("candidate-2"); fi
echo "--- Stage 2: routing measurement for: ${SURVIVORS[*]} ---"
echo

# Credential generated at runtime, never committed, never echoed. `set -x` is
# never enabled anywhere in this script.
NEXUS_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '/+=')"

docker network create "$NET" >/dev/null
echo "    network: ${NET}"

# The image comes FROM THE CHART, never from memory: the chart tracks a tag and
# a hardcoded one here would silently measure something the chart no longer
# ships. Same `render` shape as scripts/nexus-live-smoke.sh — the chart
# `required`s a Secret NAME (never a credential), so a bare render fails.
render() {
  helm template t "${SP_ROOT}/kubernetes/nexus" \
    --set nexus3.rootPassword.secret=dummy-secret-name "$@"
}

render --set repos.helm.remoteUrl=https://charts.jetstack.io >"${OUT}/rendered.yaml"
NEXUS_IMAGE="$(yq 'select(.kind=="StatefulSet") | .spec.template.spec.containers[0].image' "${OUT}/rendered.yaml" | sed -e 's/^"//' -e 's/"$//')"
if [ -z "$NEXUS_IMAGE" ] || [ "$(printf '%s\n' "$NEXUS_IMAGE" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "FATAL: expected exactly one StatefulSet container image from the rendered chart, got: '${NEXUS_IMAGE}'" >&2
  exit 1
fi
echo "    nexus image (from the chart): ${NEXUS_IMAGE}"

# The admin credential goes in a mode-600 env file inside the trap-cleaned temp
# dir rather than on the docker argv, where any local process could read it.
(
  umask 077
  cat >"${OUT}/nexus.env" <<ENV_EOF
NEXUS_SECURITY_RANDOMPASSWORD=false
NEXUS_SECURITY_INITIAL_PASSWORD=${NEXUS_PASSWORD}
ENV_EOF
)

docker run -d --name "$NEXUS_CONTAINER" --network "$NET" \
  --env-file "${OUT}/nexus.env" \
  -p "127.0.0.1:${HOST_PORT}:8081" \
  "$NEXUS_IMAGE" >/dev/null
echo "    nexus: ${NEXUS_CONTAINER} -> ${NEXUS_URL} (host) / ${DIND_NEXUS_HOST} (on ${NET})"

echo -n "    waiting for /service/rest/v1/status/writable "
NEXUS_READY=0
for _ in $(seq 1 90); do
  if curl -fsS -u "admin:${NEXUS_PASSWORD}" "${NEXUS_URL}/service/rest/v1/status/writable" >/dev/null 2>&1; then
    NEXUS_READY=1
    break
  fi
  echo -n "."
  sleep 5
done
echo
if [ "$NEXUS_READY" -ne 1 ]; then
  echo "FATAL: Nexus never became writable; no routing verdict can be rendered" >&2
  exit 1
fi
echo "    nexus is writable"

# Repo bodies out of the chart's OWN rendered ConfigMap, exactly as the live
# smoke does it, so this probe cannot drift from what the chart ships.
mkdir -p "${OUT}/config"
yq -o=json 'select(.kind=="ConfigMap" and (.metadata.name|test("-repos$"))) | .data' \
  "${OUT}/rendered.yaml" >"${OUT}/repos-data.json"
if [ ! -s "${OUT}/repos-data.json" ]; then
  echo "FATAL: no ConfigMap whose name ends '-repos' rendered from the chart" >&2
  exit 1
fi
while IFS= read -r key; do
  [ -n "$key" ] || continue
  jq -r --arg k "$key" '.[$k]' "${OUT}/repos-data.json" >"${OUT}/config/${key}"
done < <(jq -r 'keys[]' "${OUT}/repos-data.json")
echo "    repo bodies extracted: $(find "${OUT}/config" -type f | wc -l | tr -d ' ')"

echo
echo "--- provisioning the chart's own way ---"
NEXUS_HOST="$NEXUS_URL" \
NEXUS_USER=admin \
NEXUS_PASSWORD="$NEXUS_PASSWORD" \
EULA_ACCEPTED=true \
ANONYMOUS_ENABLED=true \
ANONYMOUS_USER_ID=anonymous \
ANONYMOUS_REALM_NAME=NexusAuthorizingRealm \
READY_ATTEMPTS=60 \
READY_INTERVAL=10 \
REPO_CONFIG_DIR="${OUT}/config" \
  bash "$PROVISION_SH"
echo

# components_json: every item in docker-proxy, following continuationToken.
# The components endpoint is the ONLY thing that can distinguish a mirror that
# routed from a mirror that was silently ignored.
components_json() {
  local token="" url page all='[]' items
  while :; do
    url="${NEXUS_URL}/service/rest/v1/components?repository=docker-proxy"
    if [ -n "$token" ]; then
      url="${url}&continuationToken=${token}"
    fi
    page="$(curl -fsS -u "admin:${NEXUS_PASSWORD}" "$url")"
    items="$(printf '%s' "$page" | jq -c '.items // []')"
    all="$(jq -cn --argjson a "$all" --argjson b "$items" '$a + $b')"
    token="$(printf '%s' "$page" | jq -r '.continuationToken // ""')"
    if [ -z "$token" ] || [ "$token" = "null" ]; then
      break
    fi
  done
  printf '%s' "$all"
}

components_count() { components_json | jq 'length'; }
components_names() { components_json | jq -r '.[] | "\(.group // "-")/\(.name):\(.version // "-")"' | sort -u | tr '\n' ' '; }

# clear_components: the documented cache-clearing step between candidates. A
# second Nexus boot would cost ~90s and prove the same thing; deleting the
# cached components and re-asserting zero is cheaper and is asserted, not
# assumed.
clear_components() {
  local id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    curl -fsS -X DELETE -u "admin:${NEXUS_PASSWORD}" \
      "${NEXUS_URL}/service/rest/v1/components/${id}" >/dev/null
  done < <(components_json | jq -r '.[].id')
}

RESULTS="${OUT}/routing-results.txt"
: >"$RESULTS"

measure_candidate() {
  local label="$1" mirror="$2"
  local before after names info_raw info_json pull_out pull_rc=0

  echo "=============================================================="
  echo "--- ${label}: ${mirror}"
  echo "=============================================================="

  before="$(components_count)"
  if [ "$before" != "0" ]; then
    echo "    docker-proxy cache is NOT empty (${before} items) — clearing before measuring"
    clear_components
    before="$(components_count)"
  fi
  echo "    BEFORE: ${before} component(s) in docker-proxy"
  if [ "$before" != "0" ]; then
    echo "FATAL: could not reach a zero BEFORE state for ${label}; the measurement cannot" >&2
    echo "       discriminate a mirror that routed from a cache that was already warm." >&2
    exit 1
  fi

  # A fresh engine per candidate: dind's own image cache must not carry
  # alpine:3.21 over from the previous candidate, or the second pull would be a
  # no-op and its zero delta would be unattributable.
  docker rm -f -v "$DIND_CONTAINER" >/dev/null 2>&1 || true
  docker run -d --privileged --name "$DIND_CONTAINER" --network "$NET" \
    -e DOCKER_TLS_CERTDIR= \
    -e "A3_DAEMON_JSON={\"registry-mirrors\":[\"${mirror}\"],\"insecure-registries\":[\"${DIND_NEXUS_HOST}\"]}" \
    --entrypoint sh "$DIND_IMAGE" \
    -c 'mkdir -p /etc/docker && printf "%s" "$A3_DAEMON_JSON" > /etc/docker/daemon.json && exec dockerd-entrypoint.sh' >/dev/null

  echo -n "    waiting for the nested engine "
  local dind_ready=0 _i
  for _i in $(seq 1 40); do
    if docker exec "$DIND_CONTAINER" docker info >/dev/null 2>&1; then
      dind_ready=1
      break
    fi
    echo -n "."
    sleep 3
  done
  echo
  if [ "$dind_ready" -ne 1 ]; then
    echo "    nested engine never came up. Last 30 lines of its log:"
    docker logs --tail 30 "$DIND_CONTAINER" 2>&1 | sed 's/^/      /'
    echo "FATAL: ${label} could not be measured" >&2
    exit 1
  fi
  echo "    nested engine version: $(docker exec "$DIND_CONTAINER" docker version --format '{{.Server.Version}}')"
  echo "    daemon.json inside the nested engine:"
  docker exec "$DIND_CONTAINER" cat /etc/docker/daemon.json | sed 's/^/      /'
  echo

  info_raw="$(docker exec "$DIND_CONTAINER" docker info 2>/dev/null | sed -n '/Registry Mirrors:/,/^ [A-Z]/p' | sed '$d')"
  info_json="$(docker exec "$DIND_CONTAINER" docker info --format '{{json .RegistryConfig.Mirrors}}' 2>/dev/null)"
  echo "    docker info, Registry Mirrors (verbatim):"
  if [ -n "$info_raw" ]; then
    printf '%s\n' "$info_raw" | sed 's/^/      /'
  else
    echo "      (the Registry Mirrors section is absent from docker info output)"
  fi
  echo "    docker info, normalised (.RegistryConfig.Mirrors): ${info_json}"
  echo

  echo "    docker pull ${PULL_REF} (inside the nested engine)"
  pull_out="$(docker exec "$DIND_CONTAINER" docker pull "$PULL_REF" 2>&1)" || pull_rc=$?
  echo "    pull exit: ${pull_rc}"
  # `head` reads from a here-string rather than from a pipe fed by printf: with
  # `set -o pipefail` a head that closes the pipe early makes its upstream die on
  # EPIPE and takes the whole probe with it. sed downstream drains head fully, so
  # this direction is safe.
  head -8 <<<"$pull_out" | sed 's/^/      /'
  echo

  after="$(components_count)"
  names="$(components_names)"
  echo "    AFTER:  ${after} component(s) in docker-proxy"
  echo "    names:  ${names:-(none)}"
  echo

  if [ "$after" -gt 0 ]; then
    echo "    >>> ${label} ROUTED. The components delta is the proof: Nexus now holds"
    echo "        artefacts it did not hold before the pull."
  else
    echo "    >>> ${label} DID NOT ROUTE."
    if [ "$pull_rc" -eq 0 ]; then
      echo "        NOTE: the pull SUCCEEDED (exit 0) and the delta is still zero. That is"
      echo "        Docker's mirror fallback: the image came straight from Docker Hub and the"
      echo "        mirror was ignored. A successful pull is NOT evidence of routing."
    fi
  fi
  echo

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$mirror" "$before" "$after" "$pull_rc" "$info_json" >>"$RESULTS"

  docker rm -f -v "$DIND_CONTAINER" >/dev/null 2>&1 || true
}

for cand in "${SURVIVORS[@]}"; do
  case "$cand" in
    candidate-1) measure_candidate "candidate-1" "$CAND1_URL" ;;
    candidate-2) measure_candidate "candidate-2" "$CAND2_URL" ;;
  esac
done

echo "=============================================================="
echo "--- Routing results (label / mirror / before / after / pull-rc / mirrors) ---"
cat "$RESULTS"
echo
echo "A candidate ROUTES if and only if its AFTER count is greater than its BEFORE"
echo "count. The pull exit code is not evidence either way."
echo "=============================================================="
