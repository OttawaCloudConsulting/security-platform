# ADR-034: Nexus Authentication via Authentik LDAP

**Status:** Accepted
**Date:** 2026-10-22
**Addresses:** a requirements request from the app-team session (security-platform PR #44), ADR-022 decision 4 and
ADR-021 "What was NOT verified" item 4 (read for context, not amended)

This record lives in this documentation repository. The code it describes is in
`OttawaCloudConsulting/security-platform`, `kubernetes/nexus/`. No homelab address or kube context name appears here
beyond the directory hostname the request itself named.

## Context

- **Community Edition has one external-identity path.** Nexus Repository Community Edition 3.96.0 offers local users
  and LDAP. SAML and OIDC are Pro-only (app-team, verified 2026-10-22). The instance had no LDAP server defined
  (`GET /v1/security/ldap` returned `[]`) and two active realms, `NexusAuthenticatingRealm` and `DockerToken`.
- **The directory already exists.** The homelab runs Authentik with an LDAP outpost at `ldaps://ldap.infra.ottawacloudconsulting.com:636`
  (Let's Encrypt certificate, so the JVM default truststore is enough). A service account `svc-nexus-ldap` binds to
  it. app-team confirmed the attribute layout with an `ldapsearch` bind test: `cn` is the login name, `uid` is a hash,
  users sit under `ou=users` with object class `user`, `memberOf` carries full group DNs, and Authentik also emits a
  per-user entry under `ou=virtual-groups` with the same `cn`.
- **The chart's exposure stance is unchanged.** ADR-022 decision 4 deferred ingress and TLS for Nexus on purpose, and
  ADR-021 item 4 and ADR-022 item 2 still stand: Nexus is reached over `kubectl port-forward`, in plaintext, on
  loopback. LDAP login therefore works, and inherits that stance. It adds a directory dependency; it does not add an
  exposure path.
- **ADR-022 is accepted and append-only here.** The request asked for a cross-reference in ADR-022. Accepted records
  are not edited in this repository, so the cross-reference lives in this record instead (see Decision 8).

## Decision

1. **Use the LdapRealm over `ldaps`, against the Authentik outpost.** The chart gains an opt-in `ldap:` block,
   `enabled: false` by default. When enabled, the provisioning Job upserts one LDAP server definition, creates any
   missing roles and appends `LdapRealm` to the active realms.
2. **Group to role by name.** Nexus maps the CN of an LDAP group to the role with the same id, with
   `groupType: dynamic` reading `memberOf` from the user entry. The built-in `nx-admin` role already exists, so the
   Authentik `nx-admin` group maps with no Nexus-side work. The overlay passes one extra role, `nx-readonly`
   (`nx-repository-view-*-*-read`, `nx-repository-view-*-*-browse`, `nx-search-read`).
3. **Roles are create-only.** A role is created only when `GET /v1/security/roles/{id}` returns 404. An existing
   role, built-in or not, is never modified. The cost: changing `privileges` in values later does not update a role
   that exists.
4. **Keep the local realm and the local admin as break-glass.** The step appends `LdapRealm` directly after
   `NexusAuthenticatingRealm`, preserves every realm that was active (`DockerToken` included), and refuses to write
   the realm list if `NexusAuthenticatingRealm` is not in the list it read. It never touches the admin user.
5. **No teardown path.** `ldap.enabled: false` skips the LDAP steps; it does not remove the server, the roles or the
   realm. Rollback is a documented manual procedure on the operator side. An automatic teardown is the one piece of
   this feature that could lock an instance out, so it does not exist.
6. **The bind password is a `secretKeyRef` and nothing else.** It reaches the Job as `LDAP_BIND_PASSWORD`. It is not
   in values, not in a rendered ConfigMap (`server.json` has no `authPassword` field) and not in a log; the script
   adds it with `jq --arg` and hands the body to `curl` on a `/dev/fd` path, so it is on no argv and in no file.
   Tracing (`set -x`) is not enabled anywhere on that path, and the gate asserts it.
7. **The LDAP step is a separate script, not an edit to `provision.sh`.** `provision.sh` is embedded in the scripts
   ConfigMap, so any change to it changes every default render. A second file, `files/provision-ldap.sh`, is embedded
   and run only when `ldap.enabled` is true (`bash -c "/scripts/provision.sh && /scripts/provision-ldap.sh"`). With
   `ldap.enabled: false` the render is byte-identical to the chart before this change, measured with `cmp` against
   `origin/main` for the default render and for a render with the EULA, anonymous and Helm-proxy options set. The
   request named `files/provision.sh`; this is a deliberate deviation made to meet its stronger requirement.
8. **Anonymous read is retained, and the ADR-022 stance stands.** `anonymous.enabled` is independent of this setting.
   This record is the cross-reference ADR-022 would otherwise receive: authentication to Nexus is now LDAP-backed when
   enabled, and ADR-022 decision 4 (no ingress, no TLS in this stack yet) and its open items are unchanged.
9. **Four gates guard it.** `scripts/check-nexus-chart.sh` grows from 18 to 22 invariants: `LDAP-DEFAULT-OFF` (ships
   off, explicit off equals default, no LDAP text in a default render), `LDAP-REQUIRES-BINDSECRET` (the render fails
   and names the missing value), `LDAP-ENV-WIRING` (a `secretKeyRef`, the mount, the script chain, no password field,
   no tracing) and `LDAP-OVERLAY` (the values the private overlay passes produce the expected Job and bodies).

## Consequences

- **Human logins depend on Authentik.** If the directory is unreachable, directory users cannot sign in. The local
  `admin` still can. Anonymous read and package clients using anonymous access are not affected.
- **Nexus logins bypass Authentik MFA.** Nexus binds to the directory with the user's password, so the LDAP flow is
  password-only; the Authentik flow behind the outpost is configured with `mfa_support: false` by design in
  `55-ldap.yaml`. The owner accepts this trade-off (app-team request, 2026-10-22). A second factor on the
  directory login would need a different mechanism, and CE has none.
- **Package clients may use LDAP credentials or Nexus user tokens.** Which of the two clients should hold is not
  decided here.
- **The password crosses the network to the directory under TLS only.** `ldap.protocol: ldap` is allowed by the
  chart and sends the password in clear text; the README says so. The overlay uses `ldaps`.
- **A bad definition fails the Job, loudly.** Nexus tests the connection and the bind when it saves the definition,
  so a wrong host, DN or password returns HTTP 400, and under `backoffLimit: 0` the hook Job fails. That is the
  intent. The ordering means the proxy repositories already exist by then.
- **Defaults fit Authentik and nothing else.** `userIdAttribute: cn`, `userBaseDn: ou=users` and
  `userObjectClass: user` are tuned to its layout. Another directory needs its own values.

## What was NOT verified

1. **Nothing was run against a real Nexus 3.96.0 or the real Authentik outpost by the author of this change.** The
   gate (22 checks, 0 failures) and a run of `provision-ldap.sh` against a mock Nexus API are the evidence. The mock
   showed: first run creates the server, the role and the realm (`["NexusAuthenticatingRealm","LdapRealm","DockerToken"]`);
   a second run makes no realm request and leaves the role unchanged; a realm list without `NexusAuthenticatingRealm`
   exits 1 before any realm write; and the bind password does not appear in the output. The mock was written by the
   same hand as the script, so it shares the author's reading of the Nexus API.
2. **The HTTP status codes are from documentation and the mock, not measured.** In particular, 200 (accepted: 201
   too) on role creation, 201 on LDAP server creation and 204 on update. A live run on the homelab is the first
   measurement.
3. **A real group-to-role login was not performed.** That an Authentik user in `nx-readonly` signs in and gets the
   three privileges, and that a member of `nx-admin` gets `nx-admin`, is untested. So is a user in no mapped group.
4. **Behaviour with the directory down was not measured**, including how long Nexus takes to fall back to the local
   realm for a local user.
5. **Whether `PUT` on an existing definition re-tests the bind** was not measured. The script sends the password on
   every run, so the question only affects how a rotated password shows up (as an HTTP 400 at the next upgrade).
6. **`nexus-live-smoke.sh` (kind) does not exercise the LDAP step**, and `check-nexus-setup.sh`, the workstation
   routing gate, is unchanged and unrelated.
7. **The Copilot review of PR #44 and its triage are recorded in the PR**, not here.
