# Phase 24: Nexus Anonymous Access and Workstation Script - Pattern Map

**Mapped:** 2026-09-19
**Files analyzed:** 15 (10 in `security-platform`, 5 in `security_solution`)
**Analogs found:** 13 / 15 (2 no-analog rows, both inside the new workstation script)

> **Two-repository split, confirmed on disk.** This repository (`security_solution`) is
> documentation-only. Every chart/script file this phase touches is **present in the working tree**
> at `repos/security-platform/` (clean, `main` @ `ea2770f`, "Merge pull request #14 …phase-23-nexus-generic-chart").
> All `security-platform/…` paths below are real files that were read for this map, not reconstructions
> from Phase 23 plan documents. Absolute prefix:
> `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform/`
>
> **CONTEXT.md overrides RESEARCH.md in two places. Both are baked into the excerpts below:**
> 1. `anonymous.enabled` ships **`false`** (opt-in). RESEARCH.md Pattern 2 shows `true` (Assumption A1);
>    the user overturned it. `ANONYMOUS-DEFAULT` therefore asserts `false`.
> 2. The workstation script **does** write the Docker global config with an explicit warning.
>    RESEARCH.md Open Question 1 recommended option (a) — do not touch `daemon.json`. The user chose
>    a variant of (b). See the No-Analog section: this is the one change in the phase with no
>    in-repo precedent and an unresolved collision with a REQUIREMENTS.md Out-of-Scope row.

---

## File Classification

### `security-platform` (canonical code — where the phase's executable work lands)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `kubernetes/nexus/files/provision.sh` (MOD) | provisioning script | request-response (REST) | itself — EULA block, lines 165-193 | exact (self) |
| `kubernetes/nexus/values.yaml` (MOD) | config | n/a | itself — `eula:` block, lines 86-96 | exact (self) |
| `kubernetes/nexus/templates/job-provision.yaml` (MOD) | template / config | n/a | itself — `EULA_ACCEPTED` env, lines 142-146 | exact (self) |
| `scripts/check-nexus-chart.sh` (MOD) | test (offline gate) | batch assertion | itself — checks 5, 8, 9 + terminal summary | exact (self) |
| `scripts/nexus-live-smoke.sh` (MOD) | test (live gate) | request-response | itself — section 5 + `ANONYMOUS-PULL-DENIED` | exact (self) |
| `workstation/nexus-setup.sh` (**NEW**) | utility / CLI installer | file-I/O + verification fetch | `workstation/setup.sh` | role-match |
| `kubernetes/nexus/README.md` (MOD) | docs | n/a | itself — §2 EULA opt-in, lines 76-90 | exact (self) |
| `workstation/README.md` (MOD) | docs | n/a | itself — §Quick Start, lines 9-31 | exact (self) |
| `.gitignore` in the **consumer's** repo (written by the new script) | config | file-I/O | — | **no analog** |
| `~/.docker/daemon.json` merge (inside the new script) | config | file-I/O (JSON merge) | `provision.sh` realms guard *(shape only)* | **partial / no analog** |

### `security_solution` (this repo — documentation and tracking)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `docs/adr/adr021-*.md` (**NEW**) | ADR | n/a | `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md` | exact |
| `docs/adr/README.md` (MOD) | index | n/a | the ADR-020 row (last row of the table) | exact |
| `.planning/REQUIREMENTS.md` (MOD) | tracking | n/a | lines 15, 17 (checkboxes) + 49, 50 (traceability) | exact |
| `.planning/phases/23-nexus-generic-chart/deferred-items.md` (MOD) | tracking | n/a | items 2 (line 16) and 3 (line 26), under §From 23-07 | exact |
| `docs/development-security-stack-option-1.md`, `docs/ARCHITECTURE_AND_DESIGN.md` | docs | n/a | — | **verified no-op** |

**Verified no-op, so the planner does not spend a task on it.** RESEARCH.md line 520 asks for a grep
of this repository's long-form docs. Run: `grep -rn -i 'anonymous' docs/development-security-stack-option-1.md docs/ARCHITECTURE_AND_DESIGN.md`
→ **zero matches**. Neither document asserts anything about anonymous access. The CLAUDE.md
ASCII-diagram/coverage-matrix preservation rule is not engaged by this phase.

---

## Pattern Assignments

### `kubernetes/nexus/files/provision.sh` (provisioning script, request-response)

**Analog:** itself. The EULA step is the exact shape the two new steps must take — a value-guarded
block, one REST call, a status check that hard-fails, and a log line on **both** branches.

**Environment-contract header pattern** (lines 21-47) — three new variables join it:

```bash
# Environment contract — every variable is read from the environment, and only
# REPO_CONFIG_DIR carries a default:
#   NEXUS_HOST       http://<host>:<port>, no trailing slash
#   NEXUS_USER       the literal "admin"
#   NEXUS_PASSWORD   the admin password. …
#   EULA_ACCEPTED    the string "true" or "false"
#   REPO_CONFIG_DIR  directory of repository body JSON files, default /config
# An unset NEXUS_HOST, NEXUS_USER, NEXUS_PASSWORD or EULA_ACCEPTED is a hard
# failure under `set -u`: a provisioner that guesses a missing input is how a
# chart ends up silently talking to the wrong instance.
```

Add `ANONYMOUS_ENABLED`, `ANONYMOUS_USER_ID`, `ANONYMOUS_REALM_NAME` to this block **in the same
style** (string `"true"`/`"false"` for the first — it is compared as a string, like `EULA_ACCEPTED`).
Also update the exit-contract paragraph (lines 54-61), which currently enumerates only the EULA POST
and the repository calls.

**HTTP helper pattern — use these, do not add a third** (lines 102-133):

```bash
# HTTP_CODE carries the status of the most recent request.
# It is a global rather than a value printed on stdout on purpose: a
# `code=$(http_status ...)` capture would run the helper in a subshell, where
# the `exit 1` on a transport failure could not stop the script.
HTTP_CODE=""

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
#   As http_status, but keep the response body in OUTFILE.
http_body() { … }
```

Both new steps use these verbatim: `http_body` for the realms GET, `http_status` for both PUTs.
Every request is already bounded (`--connect-timeout 5 --max-time 30`) — commit `ace66f2` exists to
make that true; do not add an unbounded curl.

**Value-guarded step + hard-fail + both-branches-log pattern** (lines 165-193) — copy this shape:

```bash
# ── 2. EULA acceptance (D-09: explicit consumer opt-in only) ─────────────────
# The chart must not accept a legal agreement on the consumer's behalf, so the
# whole step lives inside this guard. Both branches log.
if [ "${EULA_ACCEPTED}" = "true" ]; then
  echo "EULA: eula.accepted is true — accepting the … licence agreement."
  …
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
```

**The new code goes between this block and `# ── 3. Idempotent proxy repository upsert`.** Renumber
the upsert to `# ── 5.` (RESEARCH.md §Architecture Patterns numbers the steps 1-5). Bodies for both
new steps are in RESEARCH.md Pattern 1 Steps A and B (lines 252-317) — copy them from there, they
are already written in this file's house style. Two asymmetries the planner must not smooth over:
**the anonymous PUT returns 200, the realms PUT returns 204.**

The `else` branch for `ANONYMOUS_ENABLED != "true"` must exist and must name its consequence, exactly
as the EULA skip branch does — with CONTEXT.md locking the default to `false`, **the skip branch is
the default path** and is what most consumers will see in their Job logs.

**Idempotent-mutation pattern** (lines 195-227, `upsert_repo`): GET first, branch on the observed
state, never blind-write. The realms append is the same discipline expressed with `jq`:
`if index("DockerToken") then . else . + ["DockerToken"] end`, then `cmp -s` and skip the PUT when
nothing changed. The comment on lines 197-199 explains *why* the GET exists; write the equivalent
sentence for the realms guard (the API stores duplicates — measured).

---

### `kubernetes/nexus/values.yaml` (config)

**Analog:** the `eula:` block (lines 86-96). With CONTEXT.md locking `anonymous.enabled: false`,
this is now an **exact structural analog**: a top-level, wrapper-owned, opt-in boolean whose
comment states the measured consequence of leaving it at its default.

```yaml
eula:
  # -- Accept the Sonatype Nexus Repository Community Edition licence
  # agreement: https://links.sonatype.com/products/nxrm/ce-eula
  #
  # Explicit opt-in, and it stays that way (D-09): a chart must not accept a
  # legal agreement on a consumer's behalf. Measured consequence of leaving it
  # `false` — the four proxy repositories configure fine and metadata requests
  # return HTTP 200, but every actual component download returns HTTP 403 with
  # a ~192-byte body. The provisioning Job calls the EULA endpoint only when
  # this is `true`.
  accepted: false
```

House style to carry over: helm-docs `# --` on the documented key, prose rationale in a plain `#`
block above it, and **a measured consequence rather than a description**. The new block (RESEARCH.md
Pattern 2, lines 326-347) goes in with `enabled: false` and its comment rewritten to state the
default the user chose:

```yaml
anonymous:
  # -- Enable unauthenticated READ access to every repository (NEXUS-02).
  # Ships OFF. Anonymous pull is an explicit consumer opt-in, not a default:
  # a public chart must not open unauthenticated read for anyone who installs
  # it without reading this file, and there is no TLS in front of the instance
  # until Phase 25. Set it to `true` to enable.
  #
  # When true, grants the built-in, read-only `nx-anonymous` role: repository
  # read + browse across ALL formats and ALL repositories … [keep the rest of
  # RESEARCH.md Pattern 2's comment verbatim — the 403/repository-disclosure and
  # DockerToken paragraphs are measured facts]
  enabled: false
  # -- Nexus user the anonymous identity maps to. Nexus's own default.
  userId: anonymous
  # -- Realm that resolves that user. Nexus's own default.
  realmName: NexusAuthorizingRealm
```

**Phase 25 input — direct consequence of the `false` default (CONTEXT.md §Claude's Discretion,
RESEARCH.md Runtime State row 2 / Open Q4).** The private ArgoCD overlay repo must carry
`anonymous.enabled: true`, or Phase 25's first live deploy ships NEXUS-02 closed and the live gate
goes red against real infrastructure. The overlay is not visible from this repository, so the plan
must **record it as a named Phase 25 input** rather than assume it — so the overlay is written once.

**Comment block to REWRITE, not delete** (lines 59-84, under `nexus3.config:`). The last three
sentences become false the moment the calls land; the inert-key lesson above them stays true:

```yaml
  config:
    # -- Leave the subchart's own configuration Job OFF. …
    #
    # NOTE ON ANONYMOUS ACCESS — there is deliberately NO `anonymous:` key
    # here any more. One used to sit under this block … It did nothing: the
    # subchart reads `config.anonymous.*` only from inside
    # `{{- if .Values.config.enabled }}` … byte-identical output. A value that
    # changes nothing is worse than no value, because it reads like a control.
    #
    # Anonymous access is closed because NEXUS ships it closed …   <-- REWRITE
    # … `scripts/check-nexus-chart.sh` asserts the render ships       from here
    # no anonymous-access configuration at all, and
    # `scripts/nexus-live-smoke.sh` asserts the 401 against a live instance.
    # Opening read-only anonymous pull is NEXUS-02, a Phase 24 decision.
    enabled: false
```

Keep everything down to "…reads like a control." Replace the final paragraph with a pointer to the
new top-level `anonymous:` block and the **"do not put it back here"** warning.

**Optional (CONTEXT.md §Claude's Discretion / RESEARCH.md Open Q2):** `provision.readiness.attempts`
and `intervalSeconds` (lines 116-122) are present-but-unread. The recommended disposition is to wire
them through — this phase is already editing all three files that would need touching
(`provision.sh` hardcodes `READY_ATTEMPTS=60` / `READY_INTERVAL=10` at lines 89-90,
`job-provision.yaml`'s env block, and the smoke's `run_provision()`).

---

### `kubernetes/nexus/templates/job-provision.yaml` (template / config)

**Analog:** the `EULA_ACCEPTED` env entry (lines 142-146). Exact pattern, including the reason the
value is quoted:

```yaml
            # Quoted on purpose: a bare YAML bool would reach the container as
            # `true`/`false` anyway, but provision.sh compares it as a string
            # and the offline gate reads it as one.
            - name: EULA_ACCEPTED
              value: {{ .Values.eula.accepted | quote }}
```

Three new entries in the same shape:

```yaml
            - name: ANONYMOUS_ENABLED
              value: {{ .Values.anonymous.enabled | quote }}
            - name: ANONYMOUS_USER_ID
              value: {{ .Values.anonymous.userId | quote }}
            - name: ANONYMOUS_REALM_NAME
              value: {{ .Values.anonymous.realmName | quote }}
```

Note for the planner: `ANONYMOUS_ENABLED` is consumed by `jq -n --argjson enabled` in Pattern 1
Step A, which needs a JSON boolean, not a string — the string→`--argjson` conversion happens inside
`provision.sh`. Keep `| quote` here (the offline gate reads the rendered env as a string, and
`unquote()` in the gate exists for exactly that) and let the script convert.

Nothing else in this template changes. No new volume, no new securityContext key, no new resource
— which is why RESEARCH.md's recommended Checkov disposition ("accept and document") holds: this
phase adds no Kubernetes resource for the scanner to have an opinion about.

---

### `scripts/check-nexus-chart.sh` (test — offline gate, batch assertion)

**Analog:** itself. Three distinct existing checks are the templates for the three kinds of new
assertion.

**(a) Inverting check 8** (lines 171-203). The check currently greps the render for the *absence* of
anonymous configuration:

```bash
# ── 8. ANONYMOUS-NOT-OPENED ───────────────────────────────────────────────────
# This check used to read `.nexus3.config.anonymous.enabled` back out of
# values.yaml and assert it was `false`. That proved nothing. … Measured:
# rendering with `--set nexus3.config.anonymous.enabled=true` produced
# BYTE-IDENTICAL output. The check passed whatever the chart actually did, which
# is the definition of a gate that is not a gate.
…
if ! anon_render=$(render --set repos.helm.remoteUrl=https://charts.jetstack.io --set eula.accepted=true); then
  fail "ANONYMOUS-NOT-OPENED" "render failed while checking for anonymous-access configuration"
else
  if printf '%s\n' "$anon_render" | grep -q '/service/rest/v1/security/anonymous'; then
    fail "ANONYMOUS-NOT-OPENED" "the render ships a call to /service/rest/v1/security/anonymous …"
  fi
fi
```

**Chesterton's fence: rewrite, never delete.** The "a gate that is not a gate" paragraph is the
lesson from commit `a9c4f38` and must survive into the replacement comment, reframed as *why the
new check asserts wiring rather than a values key*.

**(b) `ANONYMOUS-VALUE-PRESENT` — prove the value is wired, not inert.** The correct analog is
**not** check 8; it is `PASSTHROUGH-SIZE` (lines 141-149), the repo's established "toggling this
changes the render" proof. `values.yaml` line 35 names it by name as the proof of passthrough:

```bash
# ── 5. PASSTHROUGH-SIZE ──────────────────────────────────────────────────────
# D-07: the full upstream value surface stays overridable through the wrapper.
# The volume size is the canary — if it passes through, the wrapper is not
# re-declaring a narrowed subset of the subchart's keys.
if ! size=$(render --set nexus3.persistence.size=20Gi | yq 'select(.kind=="StatefulSet") | .spec.volumeClaimTemplates[0].spec.resources.requests.storage'); then
  fail "PASSTHROUGH-SIZE" "render or yq failed with nexus3.persistence.size=20Gi"
elif [ "$(unquote "$size")" != "20Gi" ]; then
  fail "PASSTHROUGH-SIZE" "expected requests.storage '20Gi' to pass through to the PVC, got '${size}'"
fi
```

Apply verbatim in shape: `render --set anonymous.enabled=true | yq '…Job… | .spec.template.spec.containers[0].env[] | select(.name=="ANONYMOUS_ENABLED") | .value'` must read back `true`, and the
default render must read back `false`. That is the assertion the inert `nexus3.config.anonymous.*`
key could never have passed.

**(c) `ANONYMOUS-DEFAULT` — assert the shipped default.** Analog: `EULA-OPT-IN` (check 9,
~lines 205-213), the repo's existing "a default must not silently flip" check:

```bash
if ! eula=$(yq '.eula.accepted' "$VALUES"); then
  fail "EULA-OPT-IN" "yq failed reading .eula.accepted from ${VALUES}"
elif [ "$(unquote "$eula")" != "false" ]; then
  fail "EULA-OPT-IN" "expected .eula.accepted == false in ${VALUES} (explicit opt-in, D-09), got '${eula}'"
fi
```

With CONTEXT.md's decision, `ANONYMOUS-DEFAULT` is a **character-for-character analog** of this,
reading `.anonymous.enabled` and expecting `false`. Note the `unquote()` helper (lines 99-106) and
the `render()` wrapper (lines 85-89, `--set nexus3.rootPassword.secret=dummy-secret-name`) — every
positive assertion must go through `render()` or it fails on the `required` credential guard.

**(d) Terminal-summary coupling** (lines 360-372) — **must be edited in the same commit as any new check**:

```bash
# ── Terminal summary ─────────────────────────────────────────────────────────
CHECK_COUNT=17

if [ "${#FAILURES[@]}" -gt 0 ]; then
  …
  echo "FAILED - ${#FAILURES[@]} check(s)"
  exit 1
fi

echo "PASS - ${CHECK_COUNT} checks, 0 failures"
exit 0
```

Also update the file header (lines 34-40), which states `17 offline invariants`, and line 78's
`echo "check-nexus-chart: asserting 17 offline invariants …"`. See §Shared Patterns for the full
list of literal-line consumers elsewhere in the two repos.

**Do not touch** the two SKIP guards (lines 47-58) or add a third — the header forbids it explicitly.

---

### `scripts/nexus-live-smoke.sh` (test — live gate, request-response)

**Analog:** itself. Four existing constructs cover everything the new checks need.

**(a) `run_provision()` env contract** (lines 159-166) — **breaks under `set -u` if not updated**:

```bash
# shellcheck disable=SC2329
run_provision() {
  NEXUS_HOST="$NEXUS_HOST" \
  NEXUS_USER=admin \
  NEXUS_PASSWORD="$NEXUS_PASSWORD" \
  EULA_ACCEPTED=true \
  REPO_CONFIG_DIR="$OUT/config" \
    bash "$PROVISION_SH"
}
```

Add `ANONYMOUS_ENABLED=true ANONYMOUS_USER_ID=anonymous ANONYMOUS_REALM_NAME=NexusAuthorizingRealm`.
The smoke deliberately sets `EULA_ACCEPTED=true` rather than the chart default, and does the same
here: it exercises the *enabled* path even though the shipped default is off. The function is
invoked twice (`PROVISION-PASS-1` at line 317, `PROVISION-PASS-2` at line 323) — that second pass is
already the harness for `DOCKER-REALM-ACTIVE`'s "exactly once after two consecutive passes"
assertion; no new provisioning loop is needed.

**(b) Status **and** size, never a bare 200** (lines 326-358). This is the single most important
pattern to copy into `ANONYMOUS-PULL-ALLOWED`:

```bash
echo "--- 5. Post-EULA artifact download ---"
# Measured on a Community Edition container: 192 bytes / HTTP 403 before EULA
# acceptance, 318961 bytes / HTTP 200 after it. The refusal body is a perfectly
# well-formed HTTP response, so the SIZE assertion — not the status alone — is
# what distinguishes a real tarball from the licence refusal. No `curl -f`: the
# refusal body has to land on disk for the size assertion to measure it.
TARBALL_URL="${NEXUS_HOST}/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz"
TARBALL_MIN_BYTES=100000
…
if [ "$tarball_bytes" -gt "$TARBALL_MIN_BYTES" ]; then
  pass "ARTIFACT-SIZE" "${tarball_bytes} bytes downloaded (> ${TARBALL_MIN_BYTES})"
else
  fail "ARTIFACT-SIZE" "only ${tarball_bytes} bytes downloaded, expected > ${TARBALL_MIN_BYTES}; a ~192-byte body is the EULA refusal, not a tarball"
fi
```

Note the three-way split into `ARTIFACT-TRANSPORT` / `ARTIFACT-HTTP-200` / `ARTIFACT-SIZE`: a curl
transport error is reported as a *different* failure from an HTTP verdict. Copy that separation.

**(c) The block to invert** (lines 361-389). Keep the placement and the reasoning; flip the verdict:

```bash
# ── Anonymous pull must be DENIED ────────────────────────────────────────────
# The claim "anonymous pull is deliberately NOT enabled" had nothing measuring
# it. It rested on a values key … flipping that key produced a byte-identical
# render. This is the check that makes the claim true rather than merely stated.
#
# Deliberately placed AFTER the authenticated download: by this point the EULA
# is accepted and the repository is proven to serve a real 318,961-byte tarball
# to an authenticated client, so a 401 here isolates AUTHORISATION rather than a
# missing repository, an unaccepted licence or an upstream outage.
#
# No `-u` and no `-K -`: sending no credential is the point of the check.
anon_code="$(curl -sS -o "$OUT/anon-unauth.out" -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 "$TARBALL_URL")" || anon_rc=$?
if [ "$anon_rc" -ne 0 ]; then
  fail "ANONYMOUS-PULL-DENIED" "curl exited ${anon_rc} … (transport error, not an HTTP verdict)"
elif [ "$anon_code" = "401" ]; then
  pass "ANONYMOUS-PULL-DENIED" "… returned HTTP 401 - anonymous pull is closed"
else
  fail "ANONYMOUS-PULL-DENIED" "… expected 401; HTTP 200 would mean anonymous pull is OPEN …"
fi
```

The "AFTER the authenticated download … isolates AUTHORISATION" paragraph and the "No `-u` and no
`-K -`" line stay **verbatim** — both are still exactly the reason the check works. Only the
expected code, the name, and the message text change, plus a **byte-count assertion** on the
anonymous body (a 403 EULA refusal is 192 bytes and would sail past a bare 200 check).

**(d) Verdict helpers** (lines ~113-123 and the summary at ~168-195) — use these, do not invent:

```bash
pass() { echo "==> $1: PASS - $2"; CHECKS_PASSED=$((CHECKS_PASSED + 1)); }
fail() { echo "==> $1: FAIL - $2"; FAILURES+=("$1: $2"); }
```

and the three-state `print_summary` (`FAILED` / `NOTHING RAN - 0 live check(s)` / `ALL PASS - N live
check(s)`). `CHECKS_PASSED` is counted from the run, not hardcoded, so new checks raise the reported
count automatically — but the 23-0x SUMMARY files quote the literal `ALL PASS - 12 live check(s)`;
see §Shared Patterns.

**New checks and what each must assert** (from RESEARCH.md Pattern 3 and Pitfalls 4-6):
`ANONYMOUS-PULL-ALLOWED` (200 + >300,000 bytes) · `ANONYMOUS-PULL-DOCKER` (**full handshake**:
ping `/v2/` → 401 + Bearer challenge → token → manifest **carrying `Authorization: Bearer`** → 200;
a header-less manifest GET returns 200 even with the realm removed and must never be accepted as
evidence) · `DOCKER-REALM-ACTIVE` (`DockerToken` present **exactly once** after pass 2) ·
`DOCKER-PATH-SHAPE` (`/v2/<repo>/…` → 200 **and** `/v2/repository/<repo>/…` → 404) ·
`ANONYMOUS-WRITE-DENIED` (anonymous POST of a **fully valid** repository body → exactly 403, plus an
authenticated GET of that name → 404; a malformed body returns 400 and would pass for the wrong reason).

---

### `workstation/nexus-setup.sh` (**NEW** — utility / CLI, file-I/O + verification fetch)

**Analog:** `workstation/setup.sh` (878 lines). Role-match: same directory, same interpreter, same
"run from inside a target repo and write config into it" job. Copy the scaffolding; the per-ecosystem
write mechanisms are **not** all `write_config`.

> **Copy the code, not the file mode.** `workstation/setup.sh` is `-rwxr-xr-x` in the tree, which
> violates the project's Script Safety rule. The new script ships **non-executable** and is
> documented as `bash workstation/nexus-setup.sh …`.
>
> **Copy `write_config`, do not `source` setup.sh.** setup.sh runs its main body at load (argument
> parsing at line 836, dispatch at 848) with no `main()` guard, so sourcing it would execute a tool
> installer.

**Header + usage pattern** (lines 1-76):

```bash
#!/usr/bin/env bash
set -euo pipefail

# setup.sh — Bootstrap a repository with the OCC security workstation stack
#
# Usage:
#   bash setup.sh                     # full setup (install + configure + activate)
#   bash setup.sh configure           # generate config files only (no install)
#   bash setup.sh --verbose           # verbose output
#   bash setup.sh --help              # show help

usage() {
  cat <<'USAGE'
Usage: bash setup.sh [COMMAND] [OPTIONS]
…
Options:
  -v, --verbose    Show detailed progress output
  -h, --help       Show this help message and exit
USAGE
}
```

**Logging pattern** (lines 77-93) — four functions, `log` gated on `$VERBOSE`, errors to stderr:

```bash
log()  { if [[ "$VERBOSE" = true ]]; then echo "==> $*"; fi; }
info() { echo "==> $*"; }
err()  { echo "ERROR: $*" >&2; }
warn() { echo "WARNING: $*" >&2; }
```

`warn()` is the carrier for the Docker-global callout CONTEXT.md requires and for the
`PIP_CONFIG_FILE` user-scope-replacement warning (Pitfall 8).

**Idempotent config write** (lines 522-534) — reuse this, and add `--force`:

```bash
write_config() {
  local target="$1" description="$2"

  if [[ -f "$target" ]]; then
    log "Exists, skipping: $target"
    return
  fi

  # Content is written by the caller via stdin
  cat > "$target"
  CONFIG_COUNT=$((CONFIG_COUNT + 1))
  log "Created: $target ($description)"
}
```

Callers supply content by heredoc (lines 680-730 show the existing call sites,
e.g. `write_config "$target" "markdownlint enforced rules" <<'MDLINT'`).

**Repo-root detection** (line 846) — the established convention, do not use `pwd`:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

**Argument parsing + dispatch** (lines 836-872):

```bash
for arg in "$@"; do
  case "$arg" in
    install|configure|setup|check) COMMAND="$arg" ;;
    -v|--verbose) VERBOSE=true ;;
    -h|--help)    usage; exit 0 ;;
    *)            err "Unknown argument: $arg"; usage; exit 1 ;;
  esac
done
```

This loop takes **no option arguments** — `--url $NEXUS`, `--force`, `--commit-config`, `--venv`
need a `while [[ $# -gt 0 ]]` / `shift` form instead. That is a deliberate divergence from the
analog, not an oversight; note it in the script's comments.

**Per-file write mechanism — this is where the analog stops and §Don't Hand-Roll takes over:**

| Generated file | Mechanism | Never |
|---|---|---|
| `.npmrc` | `npm config set registry=<url> --location=project` (measured non-destructive: preserves an existing `_authToken` line) | `write_config`, or any `>` redirect onto `.npmrc` — Pitfall 7 is a credential-loss bug |
| `pip.conf` | `write_config` + `--force`; hand-written two-line INI; `trusted-host` **only** when the URL is `http://` and the host is **not** loopback | `pip config set` — measured `ERROR: Fatal Internal error [id=2]` on pip 26.2.1, writes nothing |
| `.helm/repositories.yaml` | `HELM_REPOSITORY_CONFIG=… HELM_REPOSITORY_CACHE=… helm repo add <name> <url>` | a YAML heredoc — the format is Helm's, with a `generated` timestamp |
| `.nexus-env` | `write_config` + `--force`; header says "source this, do not execute it" and names the `PIP_CONFIG_FILE` user-scope-replacement consequence | telling the developer to add it to a shell rc file — that is the global default REQUIREMENTS.md forbids |
| `~/.docker/daemon.json` | see No-Analog below | `write_config` — skip-if-exists would silently no-op on a file that already exists on the operator's machine |

**Mandatory verification pass** (Pitfall 10 — the script must not end on an `info "done"`). The
closest in-repo analog is `run_check()` (lines 786-830), which prints a per-tool status table:

```bash
  printf "%-14s %-14s %-14s %s\n" "Tool" "Expected" "Installed" "Status"
  …
    if [[ "$installed" = "(not found)" ]]; then status="MISSING"
    elif [[ "$installed" = "$expected" ]]; then status="ok"
    else status="MISMATCH"; fi
```

Copy the per-row-status shape, with one row per ecosystem, a **real fetch** behind each, and Docker
reported as `MANUAL` — never as a pass. No `|| true` on a verification fetch. `FAIL_COUNT` →
`exit 1` at the end of setup.sh (lines 874-877) is the existing exit-code convention.

**npm subtlety for the `--help` text:** `.npmrc` is read from npm's *local prefix* — the nearest
ancestor containing `package.json` or `node_modules`, not the cwd. In a repo with no `package.json`
anywhere up the tree, npm falls back to `https://registry.npmjs.org/` and the script appears to have
done nothing.

---

### `kubernetes/nexus/README.md` (docs)

**Analog:** itself. Three spots assert the old behaviour, and §2 is the shape the new section takes.

- **Line 46** (requirements table): `| NEXUS-02 | Proxy repos allow anonymous pull | Planned (Phase 24) |`
  → delivered, with the opt-in named.
- **Line 157** (§Reaching Nexus): *"**Reads currently require authentication.** Anonymous access is
  closed on a default Nexus install — an unauthenticated fetch returns HTTP 401 — and this chart does
  not open it. Opening read-only anonymous pull is NEXUS-02, a Phase 24 decision to take
  deliberately."* → rewrite. Keep the parenthetical about `nexus3.config.enabled` / the Groovy Job.
- **Line 192** (§Limitations and Notes): *"**Anonymous pull is not open.** …"* → rewrite to the
  post-change limitations: anonymous read is **all-repository and cannot be narrowed in place**
  (`nx-anonymous` is `readOnly: true` with `nx-repository-view-*-*-read/browse` wildcards, Pitfall 9),
  and `GET /service/rest/v1/repositories` discloses every repository's name/format/type/URL anonymously.
- **New section, modelled on §2** (lines 76-90, the EULA opt-in section): name the value, the
  measured symptom, and the one-line fix together. It must state **both gates in the same breath** —
  `anonymous.enabled: true` with `eula.accepted: false` still returns 403 on every component
  download (Pitfall 2) — and carry the **four URL shapes** with the Docker `/repository/` trap
  called out (Pattern 6): npm/pip/Helm are `HOST/repository/<repo>/…`, Docker is `HOST/<repo>/<image>`.

---

### `docs/adr/adr021-*.md` (**NEW**, this repo) + `docs/adr/README.md`

**Analog:** `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md`. Structure to copy exactly:

```markdown
# ADR-020: Nexus Chart Base, EULA Opt-In and the Unset Helm Proxy Remote

**Status:** Accepted
**Date:** 2026-09-18
**Addresses:** NEXUS-01 — … — and NEXUS-03 — …

## Context
- **Bold claim sentence.** Followed by measured evidence with exact status codes and byte counts.
## Decision
- **Bold decision sentence.** Followed by the mechanism and why the alternative was rejected.
## Consequences
**Improved:** …
**Tradeoff — <named tradeoff>.** … What is mitigated … What is not mitigated …
## What was NOT verified
1. **<numbered, bolded gap>.** …
```

ADR-020 §What was NOT verified is **append-only and must not be edited**. ADR-021 *supersedes* its
anonymous stance in prose and *closes* its item 2 ("the Docker proxy's `docker.pathEnabled: true`
shape is accepted and stored, but no image was ever pulled through it") with the Pattern 6 / `crane`
measurement. ADR-021's own §What was NOT verified must carry forward: the `dockerd`-executed pull
(blocked by Docker Desktop's VM network boundary — `crane` is the closest proxy), the `forceBasicAuth`
documented-vs-measured divergence, and the Checkov zero-coverage acceptance.

**Index row** — append one line to the end of the table in `docs/adr/README.md`, matching:

```markdown
| [ADR-020](adr020-nexus-chart-base-and-eula-opt-in.md) | Nexus Chart Base, EULA Opt-In and the Unset Helm Proxy Remote | 2026-09-18 | Accepted |
```

---

### `.planning/REQUIREMENTS.md` (tracking)

Four exact edits, on completion only:

```markdown
15: - [ ] **NEXUS-02**: Proxy repos allow anonymous pull (no auth required for read/proxy access)
17: - [ ] **NEXUS-04**: Workstation install script configures a target repo's package manager files …
49: | NEXUS-02 | Phase 24 | Pending |
50: | NEXUS-04 | Phase 24 | Pending |
```

---

## Shared Patterns

### Hard-fail HTTP discipline (no silent fallbacks)
**Source:** `security-platform/kubernetes/nexus/files/provision.sh` lines 108-133
**Apply to:** every new REST call in `provision.sh`, every assertion in both gate scripts, every
verification fetch in `nexus-setup.sh`

```bash
  if [ "${rc}" -ne 0 ]; then
    echo "FATAL: curl exited ${rc} requesting ${url} (transport failure)" >&2
    exit 1
  fi
```

A non-zero curl exit is a **transport** failure and must never be folded into a synthetic status
code — every caller branches on that code and would take the wrong branch. The only tolerated
`|| true` in the whole file is the readiness-discovery loop (lines 142-151), which documents at
length why the tolerance is safe there and nowhere else. The smoke's trap (line 78) carries a second
documented `|| true` — teardown hygiene, from which no verdict is derived.

### Assert status **and** size — never a bare 200
**Source:** `security-platform/scripts/nexus-live-smoke.sh` lines 326-358
**Apply to:** `ANONYMOUS-PULL-ALLOWED`, `ANONYMOUS-PULL-DOCKER`, and the workstation script's
verification pass
A 403 EULA refusal is a well-formed 192-byte HTTP response. A status-only assertion passes on it.

### Invert assertions, never delete them (Chesterton's fence)
**Source:** `check-nexus-chart.sh` lines 172-194 and `nexus-live-smoke.sh` lines 362-375
**Apply to:** `ANONYMOUS-NOT-OPENED`, `ANONYMOUS-PULL-DENIED`, and the `values.yaml` /
chart-README prose
Both check comments record *why the previous version of the check was wrong*. That history is the
value. Rewrite the verdict; keep the lesson.

### Land the call and its gate inversion in the same commit
**Source:** RESEARCH.md Pitfall 1 · both gates currently assert the negation of NEXUS-02
**Apply to:** plan sequencing
A commit that adds the anonymous PUT while `ANONYMOUS-NOT-OPENED` still asserts its negation leaves
a red gate in git history for no reason. A plan whose task list contains "add the anonymous call"
with no matching "invert check 8" is malformed.

### Literal terminal lines are load-bearing — update every consumer in the same commit
**Source:** `check-nexus-chart.sh` header lines 34-40; verified consumers below
**Apply to:** any plan that adds a gate check

| Consumer | Literal |
|---|---|
| `security-platform/scripts/check-nexus-chart.sh` line 38 (header), line 78 (`echo`), line 361 (`CHECK_COUNT=17`), line 371 | `17 checks` / `17 offline invariants` |
| `.planning/phases/23-nexus-generic-chart/23-04-SUMMARY.md` lines 22, 78, 129, 246, 314 | `PASS - 16 checks` / `ALL PASS - 12 live check(s)` |
| `.planning/phases/23-nexus-generic-chart/23-06-SUMMARY.md` lines 25, 63, 203, 369, 434 | same |
| `.planning/phases/24-…/24-RESEARCH.md` lines 156, 1043, 1044 | `17 checks` / `13 live checks` |

The 23-0x SUMMARY files are **historical records — leave them alone** (same disposition as PR #14).
The gate's own three self-references and any new SUMMARY must move together. `nexus-live-smoke.sh`
counts `CHECKS_PASSED` from the run, so it needs no constant bump.

### Non-executable scripts, explicit interpreter
**Source:** project rule `.claude/rules/defensive-protocol-v2-anti-slop.md` §Script Safety;
`provision.sh` header lines 71-73
**Apply to:** `workstation/nexus-setup.sh` (new) — and note `workstation/setup.sh` is `755` in the
tree, i.e. the analog violates the rule. Copy its code, not its mode. `defaultMode: 0555` on the
ConfigMap volume (`job-provision.yaml` line 162) is how the in-cluster case is handled.

### helm-docs `# --` annotation + measured-consequence prose
**Source:** `values.yaml` lines 11-13 (style note), 86-96 (`eula:` exemplar)
**Apply to:** the new `anonymous:` block
Every documented key gets `# --`; every non-obvious default gets an inline rationale stating a
*measured consequence*, not a description.

### `render()` through the credential guard
**Source:** `check-nexus-chart.sh` lines 85-89, `nexus-live-smoke.sh` lines 134-138 (identical shape)
**Apply to:** every new offline assertion
```bash
render() {
  helm template t kubernetes/nexus \
    --set nexus3.rootPassword.secret=dummy-secret-name "$@"
}
```
A bare render fails on the `required` guard in `job-provision.yaml` line 44 and would report a
defect that is not one. `dummy-secret-name` is an object name, not a credential.

### shellcheck / pre-commit
**Source:** `security-platform/.pre-commit-config.yaml` (shellcheck; yamllint with
`exclude: ^kubernetes/.*/templates/`; gitleaks)
**Apply to:** the new script and both edited gates. `# shellcheck disable=SCxxxx` carries a reason
comment on the same or preceding line everywhere in this repo (e.g. smoke line 158:
`# shellcheck disable=SC2329` with a three-line explanation of why the function *is* invoked).

---

## No Analog Found

| File / behaviour | Role | Data Flow | Reason |
|------------------|------|-----------|--------|
| `~/.docker/daemon.json` merge inside `workstation/nexus-setup.sh` | config | file-I/O (JSON merge into an existing user-owned file) | Nothing in either repository mutates a file outside the target repo. `write_config()`'s skip-if-exists is the **wrong** pattern — `~/.docker/daemon.json` already exists on the operator's machine and the write would silently no-op. |
| `.gitignore` handling in the consumer's repo | config | file-I/O (append-if-absent) | `grep -n -i gitignore workstation/setup.sh` → **zero matches**. setup.sh writes `.gitleaksignore`, markdownlint configs and `versions.conf` and never touches `.gitignore`. RESEARCH.md Open Q5 recommends gitignore-by-default with a `--commit-config` escape hatch; there is no precedent to copy. |

**Closest available shape for the `daemon.json` merge** — `provision.sh` Pattern 1 Step B (the
realms guard): read the current state, compute the new state with a `jq` guard, compare, and write
**only if it changed**. Mechanically:

```bash
jq -c 'if index("DockerToken") then . else . + ["DockerToken"] end' "${realms_cur}" >"${realms_new}"

if cmp -s "${realms_cur}" "${realms_new}"; then
  echo "realms: DockerToken already active — no change."
else
  … write …
fi
```

**Four things the planner must resolve before writing that code — none are settled by CONTEXT.md:**

1. **Which key.** CONTEXT.md says "writes the Docker global config" without naming
   `registry-mirrors` or `insecure-registries`. They do different things.
2. **Whether it works at all.** RESEARCH.md **Assumption A3** (unmeasured): `registry-mirrors` only
   mirrors Docker Hub and requires the mirror at the registry **root**, so a path-routed Nexus repo
   (`HOST/docker-proxy/…`, Pattern 6) may not be usable as a daemon mirror. Measuring this was out
   of scope for research because it meant editing the operator's own `daemon.json`. **If A3 holds,
   the script would write a key that routes nothing** — the exact silent-corruption failure mode the
   project rules exist to prevent. Verify before implementing.
3. **The Out-of-Scope collision.** `.planning/REQUIREMENTS.md` states *"Workstation pkg managers
   routed through Nexus outside the per-repo config — Per-repo config + install script only, not
   global workstation defaults."* CONTEXT.md's decision writes a global workstation default. The
   user made the call knowingly ("explicit warning/doc callout that this change is global"); the
   plan should **record the tension rather than re-litigate it**, and an opt-in flag
   (`--docker-daemon`, off by default) is the reading most consistent with both documents.
4. **Warning text source.** `docs/adr/adr009-tls-guidance.md` — "Add TLS Guidance; Warn on
   `insecure-registries` and `trusted-host`" — is an **Accepted** ADR of this project that already
   governs the wording: *"The existing `trusted-host` and `insecure-registries` configuration
   examples are annotated with explicit security warnings explaining what these directives do and
   stating that they must be removed once TLS is configured on the corresponding service."* The
   script's warning and the README callout must satisfy ADR-009, and the same applies to the
   `trusted-host` line in the generated `pip.conf`.

---

## Metadata

**Analog search scope:**
`repos/security-platform/{kubernetes/nexus/**, scripts/, workstation/, .gitignore, .pre-commit-config.yaml}`;
`docs/adr/`; `docs/`; `.planning/`

**Files read in full:** `kubernetes/nexus/files/provision.sh` (253), `kubernetes/nexus/values.yaml` (167),
`kubernetes/nexus/templates/job-provision.yaml` (169)
**Files read in targeted ranges:** `scripts/check-nexus-chart.sh` (1-120, 120-150, 150-230, 330-372),
`scripts/nexus-live-smoke.sh` (60-200, 300-400, 440-491), `workstation/setup.sh` (1-100, 510-560, 780-878)
**Files surveyed by grep:** `kubernetes/nexus/README.md`, `workstation/README.md`,
`docs/adr/adr009-tls-guidance.md`, `docs/adr/README.md`, `.planning/REQUIREMENTS.md`,
`docs/development-security-stack-option-1.md`, `docs/ARCHITECTURE_AND_DESIGN.md`

**Repository state at mapping time:** `security-platform` on `main` @ `ea2770f`, working tree clean.
`security_solution` on `feature/phase-12-repo-setup-script`.

**Pattern extraction date:** 2026-09-19
