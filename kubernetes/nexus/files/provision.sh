#!/usr/bin/env bash
set -euo pipefail

# provision.sh — bring a running Nexus Repository instance to the application
# state this chart promises: the Community Edition licence agreement accepted
# (only when the consumer opted in), then one proxy repository per JSON body
# found in the repo-config directory.
#
# WHY THIS EXISTS. Every Nexus-on-Kubernetes failure in this domain is a
# sequencing or application-state problem, not a manifest problem. The
# manifests come from the pinned nexus3 subchart and are already solved. What
# is missing there is the ordered bootstrap: a Nexus that answers HTTP 200 on
# /status is not necessarily writable; a Community Edition instance whose EULA
# has not been accepted serves repository metadata happily and then returns
# HTTP 403 with a ~192-byte body on every component download; and a blind POST
# to the repositories API returns 400 the second time it runs, which under
# `backoffLimit: 0` fails the provisioning Job permanently on every upgrade.
# Each of those is invisible in a `helm install` exit code. This script makes
# all three loud.
#
# Environment contract — every variable is read from the environment, and only
# REPO_CONFIG_DIR carries a default:
#   NEXUS_HOST       http://<host>:<port>, no trailing slash
#   NEXUS_USER       the literal "admin"
#   NEXUS_PASSWORD   the admin password. Read from the environment only; it is
#                    never written to stdout or stderr, never appears in a log
#                    line, and is never placed on a curl argv (the -u value is
#                    built inside this process). The Job supplies it through a
#                    secretKeyRef, never as a literal.
#   EULA_ACCEPTED    the string "true" or "false"
#   REPO_CONFIG_DIR  directory of repository body JSON files, default /config
# An unset NEXUS_HOST, NEXUS_USER, NEXUS_PASSWORD or EULA_ACCEPTED is a hard
# failure under `set -u`: a provisioner that guesses a missing input is how a
# chart ends up silently talking to the wrong instance.
#
# Repository body files are read in glob order. The zero-padded NNN- prefixes
# in configmap-repos.yaml exist to make that order deterministic. The Nexus
# FORMAT is the basename with the NNN- prefix and the .json suffix stripped;
# the Nexus repository NAME is `jq -r .name` on the body itself.
#
# Exit contract — deliberately two codes, and 0 must hold on BOTH of two
# consecutive runs against the same instance:
#   0  every step succeeded
#   1  the readiness poll was exhausted, the EULA POST did not return 204, or a
#      repository call returned a status outside {200, 201, 204}
# There is no third "partially provisioned" code and no soft-failure path: a
# repository that did not get created must fail the Job, not be logged and
# skipped.
#
# Logs on BOTH branches of the EULA guard. The skip branch names its
# consequence rather than staying silent, because a consumer who left
# eula.accepted at its default would otherwise see a fully green install and a
# repository that 403s on first use.
#
# Invoked in-container by kubernetes/nexus/templates/job-provision.yaml as
# `args: ["/scripts/provision.sh"]`, and directly by
# scripts/nexus-live-smoke.sh, so the live smoke gate exercises the script the
# Job runs rather than a copy of it. Never set the executable bit on this file
# in git — the ConfigMap volume supplies `defaultMode: 0555` in the cluster,
# and the smoke gate invokes it as `bash .../provision.sh`.

REPO_CONFIG_DIR="${REPO_CONFIG_DIR:-/config}"

# Readiness bounds. 60 attempts at 10s = 10 minutes, which covers a cold Nexus
# first boot (measured at 1-3 minutes on homelab hardware) and still sits
# inside the Job's activeDeadlineSeconds. The upstream configure.sh loop is
# unbounded; combined with `backoffLimit: 0` that produces a Job which neither
# completes nor fails when Nexus never comes up.
READY_ATTEMPTS=60
READY_INTERVAL=10

TMP_DIR="$(mktemp -d /tmp/nexus-provision.XXXXXX)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT

# HTTP_CODE carries the status of the most recent request.
#
# It is a global rather than a value printed on stdout on purpose: a
# `code=$(http_status ...)` capture would run the helper in a subshell, where
# the `exit 1` on a transport failure could not stop the script.
HTTP_CODE=""

# http_status URL [extra curl args...]
#   Issue one authenticated request, discard the body, and leave the HTTP
#   status in HTTP_CODE. A non-zero curl exit is a TRANSPORT failure — an
#   unreachable or TLS-broken Nexus — and is fatal. It must never be folded
#   into a synthetic status code, because every caller below branches on that
#   code and would then take the wrong branch.
http_status() {
  local url="$1"
  shift
  local rc=0
  HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "$@" "${url}")" || rc=$?
  if [ "${rc}" -ne 0 ]; then
    echo "FATAL: curl exited ${rc} requesting ${url} (transport failure)" >&2
    exit 1
  fi
}

# http_body URL OUTFILE
#   As http_status, but keep the response body in OUTFILE.
http_body() {
  local url="$1" outfile="$2"
  local rc=0
  HTTP_CODE="$(curl -sS -o "${outfile}" -w '%{http_code}' \
    -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "${url}")" || rc=$?
  if [ "${rc}" -ne 0 ]; then
    echo "FATAL: curl exited ${rc} requesting ${url} (transport failure)" >&2
    exit 1
  fi
}

# ── 1. Bounded readiness poll ────────────────────────────────────────────────
# /status/writable, not /status: the latter answers 200 while Nexus is still
# starting, and the first repository POST then fails against a read-only
# instance.
echo "Waiting for Nexus to become writable at ${NEXUS_HOST} ..."
ready_code=""
for attempt in $(seq 1 "${READY_ATTEMPTS}"); do
  # The one place this script tolerates a non-zero curl exit. During Nexus
  # boot nothing is listening on the port yet and curl exits 7; under `set -e`
  # that would abort the Job before the instance ever had a chance to come up.
  # A transport error HERE means "not ready yet", not "error". The tolerance
  # sits on the readiness discovery path only — never on a branch that decides
  # whether provisioning succeeded: if 200 is never observed the loop still
  # fails hard immediately below.
  ready_code="$(curl -sS -o /dev/null -w '%{http_code}' \
    "${NEXUS_HOST}/service/rest/v1/status/writable" || true)"
  if [ "${ready_code}" = "200" ]; then
    break
  fi
  echo "Waiting for Nexus (attempt ${attempt}/${READY_ATTEMPTS}, HTTP ${ready_code})..."
  sleep "${READY_INTERVAL}"
done

if [ "${ready_code}" != "200" ]; then
  echo "FATAL: Nexus did not become writable after ${READY_ATTEMPTS} attempts at ${READY_INTERVAL}s; last status HTTP ${ready_code}" >&2
  exit 1
fi
echo "Nexus is writable (HTTP 200)."

# ── 2. EULA acceptance (D-09: explicit consumer opt-in only) ─────────────────
# The chart must not accept a legal agreement on the consumer's behalf, so the
# whole step lives inside this guard. Both branches log.
if [ "${EULA_ACCEPTED}" = "true" ]; then
  echo "EULA: eula.accepted is true — accepting the Sonatype Nexus Repository Community Edition licence agreement."
  eula_current="${TMP_DIR}/eula-current.json"
  eula_accept="${TMP_DIR}/eula-accept.json"

  http_body "${NEXUS_HOST}/service/rest/v1/system/eula" "${eula_current}"
  if [ "${HTTP_CODE}" != "200" ]; then
    echo "FATAL: GET /service/rest/v1/system/eula returned HTTP ${HTTP_CODE}, expected 200" >&2
    exit 1
  fi

  # Mutate the object Nexus returned rather than constructing a new one: the
  # `disclaimer` string has to be echoed back verbatim or the POST is rejected.
  jq '.accepted = true' "${eula_current}" >"${eula_accept}"

  http_status "${NEXUS_HOST}/service/rest/v1/system/eula" \
    -X POST -H 'Content-Type: application/json' -d "@${eula_accept}"
  if [ "${HTTP_CODE}" != "204" ]; then
    echo "FATAL: POST /service/rest/v1/system/eula returned HTTP ${HTTP_CODE}, expected 204" >&2
    exit 1
  fi
  echo "EULA: accepted (HTTP 204). The call is idempotent — a re-run returns 204 again."
else
  echo "EULA: SKIP — eula.accepted is '${EULA_ACCEPTED}', so the licence agreement was NOT accepted."
  echo "EULA: consequence — the proxy repositories below will be created and will serve metadata with HTTP 200, but every component download returns HTTP 403 until eula.accepted is set to true."
fi

# ── 3. Idempotent proxy repository upsert ────────────────────────────────────
# upsert_repo FORMAT NAME BODYFILE
#   GET first, then PUT (204) if it exists or POST (201) if it does not. The
#   GET is what makes an upgrade survivable: a blind POST returns 400 on the
#   second run, and under `backoffLimit: 0` that permanently fails the Job.
upsert_repo() {
  local fmt="$1" name="$2" body="$3"
  local existing=""

  http_status "${NEXUS_HOST}/service/rest/v1/repositories/${fmt}/proxy/${name}"
  existing="${HTTP_CODE}"

  if [ "${existing}" = "200" ]; then
    http_status "${NEXUS_HOST}/service/rest/v1/repositories/${fmt}/proxy/${name}" \
      -X PUT -H 'Content-Type: application/json' -d "@${body}"
    if [ "${HTTP_CODE}" != "204" ]; then
      echo "FATAL: update of ${fmt} repository '${name}' returned HTTP ${HTTP_CODE}, expected 204" >&2
      exit 1
    fi
    echo "repo: format=${fmt} name=${name} action=updated (HTTP 204)"
  elif [ "${existing}" = "404" ]; then
    http_status "${NEXUS_HOST}/service/rest/v1/repositories/${fmt}/proxy" \
      -X POST -H 'Content-Type: application/json' -d "@${body}"
    if [ "${HTTP_CODE}" != "201" ]; then
      echo "FATAL: creation of ${fmt} repository '${name}' returned HTTP ${HTTP_CODE}, expected 201" >&2
      exit 1
    fi
    echo "repo: format=${fmt} name=${name} action=created (HTTP 201)"
  else
    echo "FATAL: lookup of ${fmt} repository '${name}' returned HTTP ${existing}, expected 200 or 404" >&2
    exit 1
  fi
}

shopt -s nullglob
bodies=("${REPO_CONFIG_DIR}"/*.json)
shopt -u nullglob

if [ "${#bodies[@]}" -eq 0 ]; then
  echo "FATAL: no repository body files found in ${REPO_CONFIG_DIR} — nothing to provision" >&2
  exit 1
fi

echo "Provisioning ${#bodies[@]} proxy repositor(ies) from ${REPO_CONFIG_DIR} ..."
for body_file in "${bodies[@]}"; do
  base="$(basename "${body_file}")"
  fmt="${base#[0-9][0-9][0-9]-}"
  fmt="${fmt%.json}"

  name="$(jq -r '.name' "${body_file}")"
  if [ -z "${name}" ] || [ "${name}" = "null" ]; then
    echo "FATAL: ${body_file} has no usable .name field" >&2
    exit 1
  fi

  upsert_repo "${fmt}" "${name}" "${body_file}"
done

echo "Provisioning complete: ${#bodies[@]} proxy repositor(ies) present and online."
