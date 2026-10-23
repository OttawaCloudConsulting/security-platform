#!/usr/bin/env bash
set -euo pipefail

# provision-ldap.sh — put the LDAP half of the application state on a running
# Nexus: one LDAP server definition, any missing roles, and the LdapRealm in
# the active realm list. Run by the provisioning Job ONLY when ldap.enabled is
# true, and only after provision.sh succeeded (readiness, EULA, anonymous,
# DockerToken and the proxy repositories are already done by then).
#
# WHY A SEPARATE FILE. The default render of this chart must stay byte-identical
# to a chart without LDAP. provision.sh is embedded in the scripts ConfigMap, so
# any line added to it would change every default render. This file is embedded
# only when ldap.enabled is true.
#
# Environment contract — every variable is read from the environment, and only
# LDAP_CONFIG_DIR carries a default:
#   NEXUS_HOST          http://<host>:<port>, no trailing slash
#   NEXUS_USER          the literal "admin"
#   NEXUS_PASSWORD      the admin password, as in provision.sh
#   LDAP_BIND_PASSWORD  the directory bind password. Comes from a secretKeyRef.
#                       jq reads it from its own environment (`env.`), NOT from
#                       an argument: `jq --arg` would put it on jq's argv, where
#                       `ps` and /proc/<pid>/cmdline can see it for the life of
#                       the process (Copilot review of PR 44). curl then gets
#                       the body through a process substitution, so it is on no
#                       curl argv and in no file in this container. It is never
#                       printed, and `set -x` must never be turned on in this
#                       script or in the `bash -c` that calls it. What does hold
#                       it for the whole run is the process environment, which
#                       is the secretKeyRef contract and cannot be hidden.
#   LDAP_CONFIG_DIR     directory holding server.json and roles.json,
#                       default /ldap-config
#
# SAFETY. This script has NO teardown path. It never deletes or edits the local
# `NexusAuthenticatingRealm`, never touches the admin user, never edits an
# existing role, and never removes a realm. The local admin stays as the
# break-glass login. Rolling back is a manual procedure.
#
# Exit contract: 0 when every step succeeded, 1 on any other outcome. A status
# outside the expected set is fatal, never logged and skipped. Response bodies
# are discarded and only status codes are printed.

LDAP_CONFIG_DIR="${LDAP_CONFIG_DIR:-/ldap-config}"

TMP_DIR="$(mktemp -d /tmp/nexus-ldap.XXXXXX)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT

HTTP_CODE=""

# http_status URL [extra curl args...]
#   As in provision.sh: one authenticated request, body discarded, status left
#   in HTTP_CODE. A non-zero curl exit is a transport failure and is fatal.
http_status() {
  local url="$1"
  shift
  local rc=0
  HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 \
    -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "$@" "${url}")" || rc=$?
  if [ "${rc}" -ne 0 ]; then
    echo "FATAL: curl exited ${rc} requesting ${url} (transport failure)" >&2
    exit 1
  fi
}

# http_body URL OUTFILE
http_body() {
  local url="$1" outfile="$2"
  local rc=0
  HTTP_CODE="$(curl -sS -o "${outfile}" -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 \
    -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "${url}")" || rc=$?
  if [ "${rc}" -ne 0 ]; then
    echo "FATAL: curl exited ${rc} requesting ${url} (transport failure)" >&2
    exit 1
  fi
}

for f in server.json roles.json; do
  if [ ! -s "${LDAP_CONFIG_DIR}/${f}" ]; then
    echo "FATAL: ${LDAP_CONFIG_DIR}/${f} is missing or empty" >&2
    exit 1
  fi
done
if [ -z "${LDAP_BIND_PASSWORD}" ]; then
  echo "FATAL: LDAP_BIND_PASSWORD is empty — the bind Secret key holds no value" >&2
  exit 1
fi

# ── 1. LDAP server definition (verify, then upsert) ──────────────────────────
# VERIFY FIRST. Measured on Nexus 3.96.0: saving a definition does NOT test it.
# A POST naming an unresolvable host returns 201 and stores the definition. The
# bind is only tested by POST /v1/security/ldap/verify-connection, which answers
# 204 when the bind and the base lookup work and 400 with a message such as
# "Failed to connect to LDAP Server: [LDAP: error code 49 - Invalid
# Credentials]" when they do not. So the definition is verified before anything
# is written, and a bad host, DN, base or password fails the Job here instead
# of being stored and failing every user login later. Consequence: an upgrade
# while the directory is unreachable fails the hook Job. That is the intent.
#
# UPSERT. GET by NAME: 200 -> PUT (204), 404 -> POST (201). Measured: GET and
# PUT take the definition NAME in the path (a GET by the generated id is 404),
# but a PUT whose body has no `id` is rejected with 400 "PARAMETER id must not
# be empty". The id is therefore read from the GET response and merged into the
# PUT body. A POST must not carry one. The body is built by jq from the
# rendered server.json; jq reads the password from its environment, never from
# an argument, and the body goes to curl on a /dev/fd path. The password is in
# no file and on no argv.
server_json="${LDAP_CONFIG_DIR}/server.json"
ldap_name="$(jq -r '.name' "${server_json}")"
if [ -z "${ldap_name}" ] || [ "${ldap_name}" = "null" ]; then
  echo "FATAL: server.json has no usable .name field" >&2
  exit 1
fi
ldap_url="${NEXUS_HOST}/service/rest/v1/security/ldap"
ldap_name_uri="$(jq -rn --arg n "${ldap_name}" '$n|@uri')"
verify_out="${TMP_DIR}/ldap-verify.json"

rc=0
HTTP_CODE="$(curl -sS -o "${verify_out}" -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 \
  -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
  -X POST -H 'Content-Type: application/json' \
  --data-binary @<(jq '.authPassword = env.LDAP_BIND_PASSWORD' "${server_json}") \
  "${ldap_url}/verify-connection")" || rc=$?
if [ "${rc}" -ne 0 ]; then
  echo "FATAL: curl exited ${rc} requesting ${ldap_url}/verify-connection (transport failure)" >&2
  exit 1
fi
if [ "${HTTP_CODE}" != "204" ]; then
  echo "FATAL: LDAP connection check for server '${ldap_name}' returned HTTP ${HTTP_CODE}, expected 204: $(jq -r '.message // empty' "${verify_out}" 2>/dev/null)" >&2
  exit 1
fi
echo "ldap: server=${ldap_name} connection verified (HTTP 204)"

ldap_existing="${TMP_DIR}/ldap-existing.json"
http_body "${ldap_url}/${ldap_name_uri}" "${ldap_existing}"
existing="${HTTP_CODE}"
if [ "${existing}" = "200" ]; then
  ldap_id="$(jq -r '.id // empty' "${ldap_existing}")"
  if [ -z "${ldap_id}" ]; then
    echo "FATAL: the existing LDAP server '${ldap_name}' has no id in the GET response" >&2
    exit 1
  fi
  http_status "${ldap_url}/${ldap_name_uri}" \
    -X PUT -H 'Content-Type: application/json' \
    --data-binary @<(jq --arg id "${ldap_id}" '.authPassword = env.LDAP_BIND_PASSWORD | .id = $id' "${server_json}")
  if [ "${HTTP_CODE}" != "204" ]; then
    echo "FATAL: update of LDAP server '${ldap_name}' returned HTTP ${HTTP_CODE}, expected 204" >&2
    exit 1
  fi
  echo "ldap: server=${ldap_name} action=updated (HTTP 204)"
elif [ "${existing}" = "404" ]; then
  http_status "${ldap_url}" \
    -X POST -H 'Content-Type: application/json' \
    --data-binary @<(jq '.authPassword = env.LDAP_BIND_PASSWORD' "${server_json}")
  if [ "${HTTP_CODE}" != "201" ]; then
    echo "FATAL: creation of LDAP server '${ldap_name}' returned HTTP ${HTTP_CODE}, expected 201" >&2
    exit 1
  fi
  echo "ldap: server=${ldap_name} action=created (HTTP 201)"
else
  echo "FATAL: lookup of LDAP server '${ldap_name}' returned HTTP ${existing}, expected 200 or 404" >&2
  exit 1
fi

# ── 2. Roles (create only when absent) ───────────────────────────────────────
# Nexus maps the CN of an LDAP group to the role with the same id. A role that
# already exists is left exactly as it is — built-in ones such as nx-admin
# included — so this script can never weaken or rewrite a role. Only a 404
# creates. 200 on create, not 201: measured Nexus behaviour for this endpoint
# is 200 (measured on Nexus 3.96.0), and 201 is accepted too so a future change
# does not fail a good run.
roles_json="${LDAP_CONFIG_DIR}/roles.json"
role_count="$(jq 'length' "${roles_json}")"
echo "roles: ${role_count} role(s) requested"
i=0
while [ "${i}" -lt "${role_count}" ]; do
  role_id="$(jq -r --argjson i "${i}" '.[$i].id' "${roles_json}")"
  role_body="${TMP_DIR}/role-${i}.json"
  jq --argjson i "${i}" '.[$i]' "${roles_json}" >"${role_body}"
  role_id_uri="$(jq -rn --arg n "${role_id}" '$n|@uri')"

  http_status "${NEXUS_HOST}/service/rest/v1/security/roles/${role_id_uri}"
  if [ "${HTTP_CODE}" = "200" ]; then
    echo "role: id=${role_id} action=exists — left unchanged"
  elif [ "${HTTP_CODE}" = "404" ]; then
    http_status "${NEXUS_HOST}/service/rest/v1/security/roles" \
      -X POST -H 'Content-Type: application/json' -d "@${role_body}"
    if [ "${HTTP_CODE}" != "200" ] && [ "${HTTP_CODE}" != "201" ]; then
      echo "FATAL: creation of role '${role_id}' returned HTTP ${HTTP_CODE}, expected 200 or 201 (a 400 usually means an unknown privilege name)" >&2
      exit 1
    fi
    echo "role: id=${role_id} action=created (HTTP ${HTTP_CODE})"
  else
    echo "FATAL: lookup of role '${role_id}' returned HTTP ${HTTP_CODE}, expected 200 or 404" >&2
    exit 1
  fi
  i=$((i + 1))
done

# ── 3. Active realms: LdapRealm after NexusAuthenticatingRealm ───────────────
# MEASURED on Nexus 3.96.0: creating the first LDAP server already adds
# LdapRealm to the active list (at the end), so on a first run this step
# usually finds it present and writes nothing. The step stays because it makes
# the outcome independent of that behaviour, and because it is what places the
# realm when it is absent (for example after someone removed it by hand).
# The PUT REPLACES the whole list, so the list is READ first and the new one is
# derived from what was read (the same two traps provision.sh documents). The
# result must still contain NexusAuthenticatingRealm and every realm that was
# already active, DockerToken included. If NexusAuthenticatingRealm is not in
# the list, stop: guessing a position in a list that already lacks the local
# realm is how an instance gets locked.
realms_cur="${TMP_DIR}/realms-current.json"
realms_norm="${TMP_DIR}/realms-normalised.json"
realms_new="${TMP_DIR}/realms-new.json"

http_body "${NEXUS_HOST}/service/rest/v1/security/realms/active" "${realms_cur}"
if [ "${HTTP_CODE}" != "200" ]; then
  echo "FATAL: GET /service/rest/v1/security/realms/active returned HTTP ${HTTP_CODE}, expected 200" >&2
  exit 1
fi

if ! jq -e 'index("NexusAuthenticatingRealm") != null' "${realms_cur}" >/dev/null; then
  echo "FATAL: NexusAuthenticatingRealm is not in the active realm list — refusing to change realms (lockout safety)" >&2
  exit 1
fi

jq -c '.' "${realms_cur}" >"${realms_norm}"
jq -c 'if index("LdapRealm") then .
       else (index("NexusAuthenticatingRealm")) as $i | .[:$i+1] + ["LdapRealm"] + .[$i+1:]
       end' "${realms_cur}" >"${realms_new}"

# Belt and braces: every realm read must still be present, and the local realm
# must be one of them, before anything is written.
if ! jq -e --slurpfile old "${realms_cur}" \
     '. as $new | ($old[0] | all(. as $r | $new | index($r) != null)) and (index("NexusAuthenticatingRealm") != null)' \
     "${realms_new}" >/dev/null; then
  echo "FATAL: the computed realm list would drop an active realm — refusing to write it" >&2
  exit 1
fi

if cmp -s "${realms_norm}" "${realms_new}"; then
  echo "realms: LdapRealm already active — no change, and no request was made."
else
  http_status "${NEXUS_HOST}/service/rest/v1/security/realms/active" \
    -X PUT -H 'Content-Type: application/json' -d "@${realms_new}"
  if [ "${HTTP_CODE}" != "204" ]; then
    echo "FATAL: PUT /service/rest/v1/security/realms/active returned HTTP ${HTTP_CODE}, expected 204" >&2
    exit 1
  fi
  echo "realms: appended LdapRealm after NexusAuthenticatingRealm (HTTP 204). Every realm that was already active is preserved: $(cat "${realms_new}")"
fi

echo "LDAP provisioning complete: server '${ldap_name}', ${role_count} role(s) checked, LdapRealm active."
