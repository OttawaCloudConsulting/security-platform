# ADR-034: Nexus Authentication via Authentik LDAP

**Status:** Accepted
**Date:** 2026-10-22
**Implemented in:** `OttawaCloudConsulting/security-platform` PR #44, squash-merged to `main` as
`c589e61c0b9eb9357d06f4c35eddbac9eb8eebeb` (2026-10-22)
**Addresses:** a requirements request from the app-team session (security-platform PR #44), ADR-022 decision 4 and
ADR-021 "What was NOT verified" item 4 (read for context, not amended)

**Amended before acceptance (Copilot review of PR #44), 2026-10-22.** Copilot raised three comments on the pull request.
Two were confirmed and fixed (commit `f5a98a6` on the PR branch, squashed into the merge commit above) and one was declined with evidence. The changes to this
record: Decision 6 now says the password reaches `jq` through its environment, because `--arg` had put it on `jq`'s
argv; Decision 10 is new (verify before storing); the Consequences line about a bad definition is corrected, because
the original sentence said Nexus tests a definition when it is saved and that was not true; and "What was NOT verified"
is rewritten around what a real run measured. The original text is in the git history.

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
   in values, not in a rendered ConfigMap (`server.json` has no `authPassword` field) and not in a log. The script
   reads it with `jq '.authPassword = env.LDAP_BIND_PASSWORD'` and hands the body to `curl` on a `/dev/fd` path, so it
   is on no `curl` argv, on no `jq` argv and in no file. (The first version used `jq --arg`, which puts the value on
   `jq`'s argv; Copilot caught that and `LDAP-ENV-WIRING` now fails on it.) What does hold the value for the whole run
   is the process environment, which is the `secretKeyRef` contract and cannot be hidden. Tracing (`set -x`) is not
   enabled anywhere on that path, and the gate asserts it.
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

10. **Verify the bind before storing the definition.** Measured on Nexus 3.96.0: saving an LDAP definition does not
    test it. A `POST` naming an unresolvable host returned 201 and stored it. `POST /v1/security/ldap/verify-connection`
    does test it: 204 on success, 400 with Nexus's own message otherwise (for example `LDAP error code 49 - Invalid
    Credentials`). The script calls it first and fails the Job on anything but 204. On update it reads the existing
    definition's `id` and merges it into the `PUT` body, because a `PUT` without `id` returns 400 `PARAMETER id must
    not be empty`; `GET` and `PUT` take the definition name in the path, and a `GET` by the generated id returns 404.

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
- **A bad definition fails the Job, loudly, and an upgrade needs the directory.** The connection check runs on every
  run of the hook Job. A wrong host, DN, base or password fails it before anything is stored, and under
  `backoffLimit: 0` the Job fails. So does a sync while the directory is unreachable. The proxy repositories already
  exist by then, because the LDAP step runs after `provision.sh`.
- **Defaults fit Authentik and nothing else.** `userIdAttribute: cn`, `userBaseDn: ou=users` and
  `userObjectClass: user` are tuned to its layout. Another directory needs its own values.

## What was verified, and what was not

Measured on 2026-10-22 against Sonatype Nexus Repository Community Edition 3.96.0 (`sonatype/nexus3:3.96.0-ubi`, the
version the chart resolves to) with an OpenLDAP container (`osixia/openldap:1.5.0`, plain `ldap` on a private Docker
network, a user with a password, and a bind account), running `provision-ldap.sh` inside the chart's pinned
`alpine/k8s` digest with a read-only root filesystem and `--user 65534`:

- Run 1: connection verified (204), server created (201), role created (200), `LdapRealm` already active.
  Run 2: connection verified, server updated (204), the role left unchanged, one server remains. The bind password
  appears nowhere in the output of either run.
- A wrong bind password stops the run at the check with `LDAP error code 49 - Invalid Credentials`, exit 1.
- A directory user logs in with the right password (HTTP 403 on an admin-only call, meaning authenticated but not
  privileged), is refused with a wrong one (401), and the local `admin` still works (200).
- Creating the first LDAP server already adds `LdapRealm` to the active realms, at the end of the list, and deleting
  the server removes it. The realm step therefore usually writes nothing on a first run; it stays because it makes
  the outcome independent of that behaviour.
- `GET /v1/security/ldap/{name}` is 200 and `GET .../{id}` is 404. A `PUT` without `id` in the body is 400.

Not verified:

1. **The real Authentik outpost.** The test directory is OpenLDAP with `inetOrgPerson` entries, `userObjectClass`
   set to match, and a bind account that can read the base. The Authentik-specific defaults (`cn` as the login,
   `objectClass: user`, `memberOf` as full group DNs, the per-user entry under `ou=virtual-groups`) rest on the
   `ldapsearch` result app-team reported, not on a Nexus login against Authentik. `ldaps` on 636 with a Let's Encrypt
   certificate and the JVM default truststore was not exercised either: the test used plain `ldap`.
2. **Group-to-role mapping.** Whether an Authentik user in `nx-readonly` receives the three privileges, and a member
   of `nx-admin` receives `nx-admin`, was not tested. The test directory has no `memberOf`. Neither was a user in no
   mapped group.
3. **The full hook Job in a cluster.** The script ran in the pinned image, not as the Job. `bash -c
   "/scripts/provision.sh && /scripts/provision-ldap.sh"` relies on the ConfigMap's `defaultMode: 0555`, the same
   mechanism `provision.sh` already uses, but the chained form was not run in Kubernetes. `nexus-live-smoke.sh` (kind)
   does not exercise the LDAP step.
4. **Behaviour with the directory down** after the definition exists, including how long Nexus takes to fall back to
   the local realm for a local user.
5. **Rotating the bind password.** The script sends the password on every run, so a new value reaches Nexus at the
   next sync; that was not measured with a rotated Secret.
6. **The Copilot review of PR #44 and its triage are recorded in the PR.** Declined: the comment that the image's
   Bash entrypoint would make `args` run as `/bin/bash /bin/bash -c ...`. The pinned digest
   `sha256:d489e3c7a6221af7394bc54a1498b641ada49ca51c344630966a62411b91a3df` reports `entrypoint=null` and
   `cmd=["/bin/sh"]` (`docker image inspect`), so `args` is the command.
