# Phase 25: Nexus Live Validation - Pattern Map

**Mapped:** 2026-09-23
**Files analyzed:** 9 (5 new, 4 modified — 3 of the 9 are conditional on Open Question 2/3)
**Analogs found:** 9 / 9, all exact-match; 2 in-file partial gaps noted under *No Analog Found*

> **HANDLING NOTE — same discipline as 25-RESEARCH.md.** This file lands in tracked `.planning/` in a
> repo whose `origin` is the **public** `security-platform`. Every excerpt below is drawn from the two
> local checkouts with all `encryptedData` blobs and every homelab IP, VIP, DNS name and NAS endpoint
> **omitted or placeholdered** (`<sealed>`, `<project>`, `<commit-sha>`); no file containing such a value
> was read. Two excerpts do carry incidental private-environment detail that 25-RESEARCH.md does not
> already name — the `platform` AppProject `description:` enumerating its member apps, and the
> `sealedsecret-radius.yaml` comment mentioning RADIUS/NAS enrolment. Both are structural comments, not
> endpoints; genericise them if this file is ever published. Never `git push` from this repo.

> **BLOCKER FOR THE PLANNER — resolve before any overlay file is authored.** The orchestrator brief says
> the AppProject amendment targets the **`platform`** project; 25-RESEARCH.md Open Question 2 recommends a
> **new `security`** project instead. The two produce *different directory paths*, and the path
> permanently fixes the Application's project (renaming later = a different Application). This map
> therefore uses `<project>` as a placeholder and supplies **both** analogs: the `platform` block as the
> amend-an-existing-project analog, and the `identity` block as the new-narrow-project analog. The
> orchestrator brief is the more recent instruction; the research is the more recent measurement. Do not
> pick silently — it is a shared-`AppProject` write, which the session-management rule classes as
> irreversible-ish and requiring operator confirmation.

**Repo locations (both local, both used read-only for this map):**

| Repo | Local path | State read |
|---|---|---|
| `security-platform` (public package repo) | `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform` | clean tree, `aed14b9` (2026-09-20, Phase 24 merge) |
| `occ-k8s-app-config` (private overlay) | `/Users/christian/git-repos/OCC-github/kubernetes_stack/occ-k8s-app-config` | `88b14a7` (2026-09-21), branch `feat/identity-4.4-4.5-entra-proxy-created` |

A second, **stale** overlay clone exists at `/Users/christian/git-repos/SSC/occ-k8s-app-config`
(last commit 2025-06-04). Do not use it.

---

## File Classification

| New/Modified File | New/Mod | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|---------|------|-----------|----------------|---------------|
| `security-platform/scripts/nexus-homelab-validate.sh` | NEW | test / gate script | request-response (HTTP probes) + batch (cluster reads) | `security-platform/scripts/nexus-live-smoke.sh` | **exact** (same author, same subject, §4/5/6/6b are the extraction source) |
| `occ-k8s-app-config/application-sets/<project>/nexus/argocd-overrides.yaml` | NEW | config (Application spec strategic-merge patch) | event-driven (GitOps reconcile) | `application-sets/identity/authentik/argocd-overrides.yaml` | **exact** (only other multi-source app under the same `appset-apps` generator) |
| `occ-k8s-app-config/application-sets/<project>/nexus/Chart.yaml` | NEW *(conditional)* | config (umbrella chart metadata) | n/a (render-time) | `application-sets/identity/authentik/Chart.yaml` | **exact** |
| `occ-k8s-app-config/application-sets/<project>/nexus/templates/sealedsecret-nexus-admin.yaml` | NEW *(conditional)* | model / manifest (credential delivery) | one-way secret delivery (git → controller → Secret) | `application-sets/identity/authentik/templates/sealedsecret-radius.yaml` | **exact** |
| `occ-k8s-app-config/application-sets/automation/argocd/templates/projects.yaml` | MODIFY | config (authorization policy / allowlist) | declarative policy | the `platform` block (L265–363) **and** the `identity` block (L459–556) *in the same file* | **exact** (in-file precedent) |
| `security-platform/kubernetes/nexus/templates/job-provision.yaml` | MODIFY *(optional, OQ3)* | k8s manifest template (hook Job) | batch / event-driven (Argo Sync hook) | itself — the existing annotation block (L65–70) | **exact** (self-analog; additive edit only) |
| `security-platform/kubernetes/nexus/README.md` | MODIFY | docs | n/a | its own "Validation so far" bullet (L233) | **exact** |
| `security_solution/docs/adr/adr022-*.md` | NEW | docs (ADR) | n/a | `docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md` | **exact** |
| `security_solution/.planning/REQUIREMENTS.md` | MODIFY | docs (traceability) | n/a | its own NEXUS-01…04 rows (L14–17, L47–51) | **exact** |

**Conditional notes**

- `Chart.yaml` + `templates/sealedsecret-nexus-admin.yaml` are needed **only if** the admin credential is
  delivered through the overlay directory (the research's recommendation). If the operator instead applies
  the Secret out-of-band, the app directory collapses to the `platform/cloudnative-pg` shape — a directory
  containing **only** `argocd-overrides.yaml` + `README.md`, no `Chart.yaml`, no `templates/`
  (verified: `find application-sets/platform/cloudnative-pg -type f` returns exactly those two). That is a
  legal, in-repo precedent and the smaller diff; it is also **not** GitOps for the credential.
- `job-provision.yaml` edits belong in a **separate `security-platform` PR** with its own gates
  (CLAUDE.md: chart edits do not land in this documentation repo).

---

## Pattern Assignments

### 1. `security-platform/scripts/nexus-homelab-validate.sh` (test/gate, request-response + batch)

**Analog:** `security-platform/scripts/nexus-live-smoke.sh` (1069 lines, 25 checks)
**Secondary analog (argument parsing only):** `security-platform/workstation/nexus-setup.sh` (1637 lines)

**Header + strict-mode + repo-root pattern** (`nexus-live-smoke.sh` L1–2, L43–50):

```bash
#!/usr/bin/env bash
set -euo pipefail
# ...
# Exit codes:
#   0  every live check that ran passed, or the run was skipped (nothing ran)
#   1  at least one live check failed, or a required hard-tier binary is
#      missing, ...
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
```

The file header also carries, verbatim in shape: a WHY THIS EXISTS paragraph naming the false-pass the
script prevents, a stated runtime, the `Never set the executable bit on this file (project rule). Invoke
as: bash scripts/<name>.sh` line, and an explicit exit-code table. Copy all four.

**Accounting variables — the anti-vacuous-green core** (L78–87):

```bash
FAILURES=()
# SKIPPED: sub-checks that did not run (an optional tool is absent, or the
# subject of the check does not exist at this commit). Reported separately from
# FAILURES and separately from passes — a skip must never read as a pass — and
# it never affects the exit status.
SKIPPED=()
# CHECKS_PASSED: live checks that actually executed and passed. Counted from the
# run itself, so the summary cannot claim a pass on a run where nothing ran.
CHECKS_PASSED=0
```

**Assertion helpers** (L96–121) — copy verbatim, including the comment forbidding `|| true`:

```bash
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
```

**Terminal verdict** (L192–217) — the three-branch summary; `NOTHING RAN` is the branch that makes a
zero-check run non-green:

```bash
print_summary() {
  echo
  echo "=== Summary ==="
  if [ "${#SKIPPED[@]}" -gt 0 ]; then
    echo "SKIPPED - ${#SKIPPED[@]} sub-check(s) did not run. A SKIP IS NOT A PASS:"
    for s in "${SKIPPED[@]}"; do echo "  - ${s}"; done
    echo
  fi
  if [ "${#FAILURES[@]}" -gt 0 ]; then
    echo "FAILED - one or more live checks did not produce the expected result:"
    for f in "${FAILURES[@]}"; do echo "  - ${f}"; done
    exit 1
  elif [ "$CHECKS_PASSED" -eq 0 ]; then
    echo "NOTHING RAN - 0 live check(s) executed; ${#SKIPPED[@]} sub-check(s) skipped (not passed). Nothing was proven."
    exit 0
  else
    echo "ALL PASS - ${CHECKS_PASSED} live check(s) executed and passed; ${#SKIPPED[@]} sub-check(s) skipped (not passed)."
    exit 0
  fi
}
```

**Preflight tiering** (L219–236) — hard tier FATALs, soft tier pushes a named SKIPPED. For the homelab
script the hard tier is `curl jq` and the soft tier is `kubectl` (absent ⇒ the four cluster-side checks
skip, the HTTP checks still run against a supplied `NEXUS_HOST`):

```bash
for bin in docker curl jq yq helm; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 1
  fi
done
# ...
if [ ! -f "$PROVISION_SH" ]; then
  SKIPPED+=("live smoke: ${PROVISION_SH} does not exist yet (lands in plan 23-04); no container was booted")
  print_summary
fi
```

**Three-verdicts-per-fetch pattern** — the single most important body to extract. From the npm anonymous
check (L428–458); PyPI (L478+) and Helm (L520+) are the same three-block shape with their own floors:

```bash
# npm — measured 318,961 bytes at HTTP 200, unauthenticated; floor 100,000
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
```

Three separate labels, never an `if/elif` chain — the file's own comment (L404–412) records why: a
status check stops at the status and never reaches the size, and both the 192-byte EULA refusal and the
zero-byte 401 challenge are well-formed HTTP responses. **Do not tighten the floors**: the derivation
rule is stated at L415–424 (≥ 10× the 192-byte refusal, ≤ half the measured size).

**URL constants to lift verbatim** (L354, L478, L520, L655–656):

```bash
TARBALL_URL="${NEXUS_HOST}/repository/npm-proxy/lodash/-/lodash-4.17.21.tgz"
ANON_PYPI_URL="${NEXUS_HOST}/repository/pypi-proxy/simple/${ANON_PYPI_PROJECT}/"   # trailing slash load-bearing
ANON_HELM_URL="${NEXUS_HOST}/repository/helm-proxy/index.yaml"
DOCKER_MANIFEST_URL="${NEXUS_HOST}/v2/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG}"
DOCKER_MANIFEST_URL_WRONG="${NEXUS_HOST}/v2/repository/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG}"
```

**Multi-assertion-one-label pattern** (`DOCKER-REALM-ACTIVE`, L585–655) — a `*_ok=1` flag, a cascade of
`fail` calls each with its own diagnosis, one `pass` at the end gated on the flag:

```bash
REALMS_URL="${NEXUS_HOST}/service/rest/v1/security/realms/active"
realms_ok=1
# ... transport / status / is-it-an-array guards each set realms_ok=0 ...
  docker_realm_count="$(jq '[.[] | select(. == "DockerToken")] | length' "$OUT/realms-active.json")"
  auth_realm_count="$(jq '[.[] | select(. == "NexusAuthenticatingRealm")] | length' "$OUT/realms-active.json")"
  if [ "$docker_realm_count" -eq 0 ]; then
    fail "DOCKER-REALM-ACTIVE" "DockerToken is ABSENT from the active realms ${realms_list}; ..."
  elif [ "$docker_realm_count" -ne 1 ]; then
    fail "DOCKER-REALM-ACTIVE" "DockerToken appears ${docker_realm_count} times in ${realms_list}, expected exactly once; the API stores duplicates (measured) ..."
  fi
  if [ "$auth_realm_count" -eq 0 ]; then
    fail "DOCKER-REALM-ACTIVE" "NexusAuthenticatingRealm is GONE from the active realms ${realms_list}; PUT /security/realms/active replaces the whole list ..."
  fi
```

Under Argo CD this stops being a one-off test: Sync hooks re-run on **every** sync, so
"`DockerToken` exactly once, `NexusAuthenticatingRealm` still present" is a standing invariant.

**Both-directions routing assertion** (`DOCKER-PATH-SHAPE`, L658–721) — assert 200 on the correct shape
**and** 404 on the wrong-by-analogy shape. The comment at L666–673 is the reason and should be carried
across: npm/PyPI/Helm all use `/repository/<repo>/…`, so the Docker line gets written the same way by
analogy and every pull 404s.

**Five-leg OCI handshake** (`ANONYMOUS-PULL-DOCKER`, L722–875) — a function, because the legs are ordered
and each consumes the previous leg's output. Leg boundaries and their non-obvious expectations:

| Leg | Request | Expected | Why it is not skippable |
|---|---|---|---|
| 1 | `GET ${NEXUS_HOST}/v2/` | **401** + `WWW-Authenticate: Bearer` | a 200 here is a *failure*: no challenge was issued, so legs 2–5 measure nothing |
| 2 | parse `realm` and `service` out of the challenge | both non-empty | a header-less GET returns 200 even with `DockerToken` removed |
| 3 | `GET <realm>?service=…&scope=…`, **no credential** | 200 + non-empty `.token` | proves an anonymous client can mint a token |
| 4 | manifest GET **with** `Authorization: Bearer` | 200 + JSON carrying `manifests`/`layers` | a 401 here with 1–3 green isolates the `DockerToken` realm |
| 5 | resolve `linux/amd64` child manifest → layer blob | 200 and `> DOCKER_BLOB_MIN_BYTES` (`1000000`, L735) | a few hundred bytes is an error document, not a layer |

**Negative-test pattern with an instrument check** (`ANONYMOUS-WRITE-DENIED`, L878–967) — the shape D-05
requires. Three parts: a **structurally valid** POST asserted at **exactly 403**; an admin GET of an
*existing* repo asserted at 200 (the instrument); an admin GET of the probe name asserted at 404:

```bash
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
# ... POST with --data-binary "@$OUT/anon-write-body.json" ...
elif [ "$anon_write_code" = "200" ] || [ "$anon_write_code" = "201" ] || [ "$anon_write_code" = "204" ]; then
  fail "ANONYMOUS-WRITE-DENIED" "PRIVILEGE ESCALATION REGRESSION: an unauthenticated POST to ${ANON_WRITE_POST_URL} returned HTTP ${anon_write_code} and CREATED a repository. ..."
elif [ "$anon_write_code" != "403" ]; then
  fail "ANONYMOUS-WRITE-DENIED" "unauthenticated POST to ${ANON_WRITE_POST_URL} returned HTTP ${anon_write_code}, expected exactly 403; 400 means the body was rejected as malformed BEFORE authorisation was ever consulted, ..."
fi
```

**Adaptation for the homelab script:** `NPM_REPO_NAME` is read from `$OUT/config/000-npm.json`, a file the
kind/container half produces. On the homelab there is no such file — read the name from the cluster
instead (`kubectl -n nexus get cm nexus-repos -o jsonpath=…`) or from the rendered chart, **not**
hardcoded. The analog's own comment says why: "whose name is read from the rendered body rather than
hardcoded."

**Cluster-side check analog** (`KIND-JOB-COMPLETE`, L1053–1068) — the closest existing shape for the four
new checks (`ARGOCD-HOOK-PHASE`, `PROVISION-JOB-COMPLETE`, `PVC-DEFAULT-STORAGECLASS`,
`SECOND-SYNC-IDEMPOTENT`). Note the emptiness guard: `kubectl wait` against an empty set is not a
reliable signal, so an empty result must be an explicit `fail`, never a silent pass:

```bash
job_rows="$(kubectl --context "$KIND_CONTEXT" --namespace "$KIND_NS" get job \
  -l app.kubernetes.io/instance=t --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [ "$job_rows" -eq 0 ]; then
  fail "KIND-JOB-COMPLETE" "no Job matched app.kubernetes.io/instance=t in namespace ${KIND_NS} after install; either the chart renders no provisioning Job, it is missing that label, or its helm.sh/hook-delete-policy includes hook-succeeded and deleted the evidence"
else
  echo "    ${job_rows} Job(s) still present after install: the delete-policy left the evidence in place"
  require_success "KIND-JOB-COMPLETE" kubectl --context "$KIND_CONTEXT" --namespace "$KIND_NS" \
    wait --for=condition=complete job -l app.kubernetes.io/instance=t --timeout=300s
fi
```

Also copy the **explicit-context discipline** from the same section (L978–983): every `kubectl`/`helm`
call pins `--context` / `--kube-context`, and the incoming context is captured so the script cannot damage
the environment it runs in. On the homelab that becomes an explicit `--context` (or `KUBECONFIG`) on every
call, never an implicit current-context.

**Credential sourcing** (L246–251, and L1023–1033 for the stdin apply):

```bash
# Generated at runtime, never committed, never echoed, and `set -x` is never
# enabled anywhere in this script. gitleaks runs as a pre-push hook over the
# whole repository; a literal test password committed to a public repo is a real
# finding, not a test detail.
NEXUS_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '/+=')"
```

The homelab script does not generate it — it **reads** it from the cluster and must keep the same
never-on-argv, never-echoed rule:

```bash
PW="$(kubectl -n nexus get secret nexus-admin -o jsonpath='{.data.password}' | base64 -d)"
```

**Owned-infrastructure lifecycle — the port-forward decision** (L56–77)

The homelab script's `kubectl port-forward svc/nexus-nexus3 8081:8081 &` is the direct analog of the
smoke's `docker run` container: a background process *this run started*, which must be torn down on every
exit path and must never kill one it did not start. The analog's whole lifecycle is one trap line (L77),
with every variable it touches assigned **before** it so `set -u` cannot trip inside the cleanup path:

```bash
# Assigned BEFORE the trap so `set -u` cannot trip inside the cleanup path.
NEXUS_CONTAINER="nexus-live-smoke-$$"
# KIND_CREATED is the trap's ownership flag: it flips to 1 only AFTER
# `kind create cluster` has returned 0, so the trap can never delete a cluster
# this run did not create.
# ... KUBECTX_BEFORE="" captured because kind REWRITES the operator's kubeconfig
# current-context and this smoke must not damage the environment it runs in.
trap 'rm -rf "$OUT"; docker rm -f "$NEXUS_CONTAINER" >/dev/null 2>&1 || true; if [ "$KIND_CREATED" = "1" ]; then kind delete cluster --name "$KIND_CLUSTER" >/dev/null 2>&1 || true; fi; if [ -n "$KUBECTX_BEFORE" ]; then kubectl config use-context "$KUBECTX_BEFORE" >/dev/null 2>&1 || true; fi' EXIT
```

Three rules to carry: (a) assign every trap-referenced variable before the `trap` line; (b) claim
ownership only *after* the create call returned 0 (`KIND_CREATED=1` at L1018, never before — the guard at
L984–1004 FATALs loudly rather than deleting something it did not create); (c) `|| true` is permitted
**only** in best-effort teardown, never on an assertion — the analog says so explicitly at L74–76.

**FORK THE PLANNER MUST DECIDE — the two argument patterns below imply different lifecycles:**

| Option | Analog | Consequence |
|---|---|---|
| Script **owns** the port-forward (starts it, traps it, restores context) | `nexus-live-smoke.sh` container ownership, L56–77 + L984–1004 | Self-contained gate; needs a PID ownership flag, a readiness wait on `127.0.0.1:8081`, and a port-collision guard in the FATAL-and-name-the-fix style |
| Script **requires** `--url` to an operator-run forward | `workstation/nexus-setup.sh` L1527–1575 | No lifecycle to own and no environment to damage; the operator must start and stop the forward, and the runbook step becomes part of the phase evidence |

**`NEXUS_HOST` parameterisation** — `nexus-live-smoke.sh` derives it from a container it owns
(L287: `NEXUS_HOST="http://127.0.0.1:${NEXUS_PORT}"`) and takes **no arguments at all**. The new script
needs a host input, so take the pattern from `workstation/nexus-setup.sh`:

- Env-var-with-default constants (L177–179):
  `VERIFY_NPM_NAME="${NEXUS_VERIFY_NPM_NAME:-lodash}"` — overridable because they name upstream packages
  that can be yanked.
- A **shift loop** for options that take a value (L1527–1569), with the divergence comment intact:

```bash
# ARGUMENT PARSING DIVERGES FROM THE ANALOG, DELIBERATELY. workstation/setup.sh
# iterates 'for arg in "$@"' with a case over bare words, which cannot take an
# option ARGUMENT. This script's --url does take one, so it uses a shift loop
# instead.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      if [[ $# -lt 2 ]]; then err "--url requires a value, e.g. --url https://nexus.example.com"; usage; exit 1; fi
      NEXUS_URL_RAW="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown argument: $1"; usage; exit 1 ;;
  esac
done
# Checked AFTER the loop so --help and an unknown argument are both reachable
# without a URL. A missing --url is an error, never a default.
```

The "**never guess a default host**" rule (L1571+) transfers directly: the homelab script must refuse to
run against an unstated host rather than silently probing `127.0.0.1`.

---

### 2. `occ-k8s-app-config/application-sets/<project>/nexus/argocd-overrides.yaml` (config, event-driven)

**Analog:** `application-sets/identity/authentik/argocd-overrides.yaml` (438 lines) — the only other
multi-source app under the same `appset-apps` generator.
**Secondary analog:** `application-sets/platform/cloudnative-pg/argocd-overrides.yaml` (118 lines) — same
rules at one-quarter the size; better starting skeleton if the nexus override stays small.

> **Research cross-check.** 25-RESEARCH.md Pattern 1 marks its field *values* `[ASSUMED]`. Verified
> against the live analog: `source: null` + `sources:` (authentik L75–76 ✅), `$patch: replace` under
> `automated` (L404–408 ✅), `syncOptions` restated in full (L411–421 ✅), `retry` under
> `spec.syncPolicy` (L433–438 ✅ — authentik uses `limit: 10`, cloudnative-pg `limit: 5`; the research's
> suggested 5/30s/2/10m sits inside the range both precedents use). No `spec.project`, no
> `destination.*` in either file ✅. The research's structural claims hold against the real analog.

**Mandatory header comment block** (authentik L1–25, near-identical in cloudnative-pg L1–20) — this is
not decoration; it is the convention in both files and states the four traps:

```yaml
# LIVE -- THIS FILE IS THE APPLICATION. `appset-apps` (bootstrap/application-sets.yaml)
# discovers `application-sets/*/*/argocd-overrides.yaml` by FILE PRESENCE and merges this file
# into the generated Application through its templatePatch.
#
# DELETING THIS FILE DELETES THE APPLICATION.
# `preserveResourcesOnDeletion: true` on the generator keeps every resource ... after the
# Application goes. A rollback must therefore ... BEFORE this file is deleted.
#
# EXACTLY ONE OVERRIDE FILE, AT THIS DIRECTORY ROOT (R32). The include is the doubly-nested
# glob `application-sets/*/*/argocd-overrides.yaml`, and legacy globbing lets `*` span `/`, so
# a second file anywhere below this directory would generate a stray Application named for that
# nested directory. Never create one.
#
# spec.project is deliberately NOT set (F-10): Argo CD restores it after the patch, so an
# override that set it would be silently reverted. This app's project is `<project>`, derived
# from the directory path `application-sets/<project>/nexus`.
#
# Vocabulary and merge semantics follow docs/reference/argocd-overrides-guide.md.
argocdOverrides:
  spec:
```

**Multi-source shape** (authentik L71–76, L385–387) — `source: null` with its rationale, then `sources`:

```yaml
    # D15 -- MULTI-SOURCE. Sync waves order resources within ONE Application only, so the
    # operator and the manifests that depend on it must share an Application. `source: null`
    # is REQUIRED, not tidiness: the generator template always sets spec.source, and source
    # and sources collide if both are present (guide R8, F-11). `null` deletes the key; an
    # empty `sources: []` cannot express this because empty collections are elided (F-9).
    source: null
    sources:
      # ... source 1 ...
      # SOURCE N -- local manifests. A Helm chart in this repository.
      - repoURL: https://github.com/OttawaCloudConsulting/occ-k8s-app-config
        targetRevision: main
        path: application-sets/identity/authentik
```

**Source-entry shape with a pinned revision and an inline `valuesObject`** (authentik L96–110) — note the
`releaseName` decision is *explicitly reasoned about* in both precedents, never left implicit by accident:

```yaml
      # RELEASE NAME LEFT AT ITS DEFAULT, DELIBERATELY -- unlike source 1's explicit
      # `releaseName: cnpg`. A source with no releaseName defaults to the Application name,
      # "authentik", which renders the conventional resource names this repo's docs and
      # runbooks already use ... Verified by rendering the pinned chart with this exact
      # valuesObject -- no collision with any source 3 resource name.
      - repoURL: https://charts.goauthentik.io
        chart: authentik
        targetRevision: 2026.8.1
        helm:
          valuesObject:
            global:
              # Image tag stated explicitly (R23) -- the chart default resolves the tag to
              # its own appVersion, and an implicit pin is exactly what R23 objects to.
              image:
                repository: ghcr.io/goauthentik/server
                tag: "2026.8.1"
```

For nexus, source 1 is a **git** source (`repoURL` + `path`, no `chart:` key) — the cloudnative-pg file
has no git-source precedent, but authentik's source 3 (above) is exactly that shape. Pin
`targetRevision` to a commit SHA or tag (R23 + ADR-004), and state `releaseName: nexus` explicitly
because every runbook and port-forward assumes the rendered Service name `nexus-nexus3`.

**`syncPolicy` block** (authentik L388–438) — the complete recipe, including the three comments that
explain *why* each key is there:

```yaml
    syncPolicy:
      # R5 recipe (docs/reference/argocd-overrides-guide.md): `$patch: replace` renders
      # `automated` with exactly the keys stated here, so all three are listed.
      automated:
        $patch: replace
        enabled: true
        selfHeal: true
        prune: true
      # syncOptions REPLACES rather than appends (F-12), so the generator baseline's entries
      # are restated here in full.
      syncOptions:
        - CreateNamespace=true
        - ApplyOutOfSyncOnly=true
      # ... budget rationale ...
      # After the last retry fails, automated sync NEVER retries the same revision, even once
      # the CRDs exist and even with selfHeal -- recovery then needs one manual `argocd app
      # sync authentik`. So this budget is the window the operator must come up in, unattended.
      retry:
        limit: 10
        backoff:
          duration: 30s
          factor: 2
          maxDuration: 10m
```

`ServerSideApply=true` appears in both analogs but for a measured reason (CNPG CRDs exceeding the 262144-byte
last-applied-configuration cap). The nexus chart renders no CRD — **do not copy it by analogy**; copy the
*habit* of stating a measurement next to any option added.

**`ignoreDifferences`** (authentik L48–74) — only if something writes to a chart-managed object
out-of-band. The nexus chart has no such writer today; omit unless the first sync shows drift.

---

### 3. `occ-k8s-app-config/application-sets/<project>/nexus/Chart.yaml` (config, umbrella)

**Analog:** `application-sets/identity/authentik/Chart.yaml` — copy verbatim in shape, including the
deliberate absence of `dependencies:` and the comment saying so:

```yaml
apiVersion: v2
name: authentik
version: 0.1.0
description: OCC Homelab authentik local manifests -- blueprints, CNPG cluster, outposts
# Documentation only. This chart ships no authentik image itself: it is source 3 of the
# multi-source Application (D15) and renders local manifests. Every version this chart
# actually consumes lives under `versions:` in values.yaml.
#
# There is deliberately NO `dependencies:` block. The upstream authentik and
# CloudNativePG charts are separate ArgoCD sources with their own `targetRevision`
# (D15, D23), not subcharts -- sync waves only order resources inside one Application,
# and subcharts would collapse the wave boundaries this design depends on.
appVersion: "2026.8.1"
```

**Verified:** the file contains no `dependencies:` key. This matters twice — the overlay repo has a
`no-vendored-charts` pre-commit hook, and the `conformance` check's Helm render matrix (built by
`scripts/discover_apps.py`) requires the new directory to `helm template` cleanly **on its own**.

---

### 4. `occ-k8s-app-config/application-sets/<project>/nexus/templates/sealedsecret-nexus-admin.yaml`

**Analog:** `application-sets/identity/authentik/templates/sealedsecret-radius.yaml` (encrypted blob
redacted here; never paste one into `.planning/`):

```yaml
# Feature 5.7: worker-only blueprint input; no plaintext shared secret in Git.
# Retrieve securely from the decrypted Secret when enrolling the selected NAS.
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: authentik-radius
  namespace: authentik
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  encryptedData:
    shared-secret: <sealed>
  template:
    metadata:
      name: authentik-radius
      namespace: authentik
    type: Opaque
```

Four things to carry: (a) a leading comment naming why the value is sealed and how to retrieve it;
(b) `metadata.name`/`namespace` **and** the `spec.template.metadata` pair both stated — strict scope binds
name *and* namespace, so renaming either requires re-sealing; (c) an explicit
`argocd.argoproj.io/sync-wave` annotation (nexus uses `"-1"`, a wave earlier than the analog's `"0"`, so
the Secret's apply precedes the wave-0 StatefulSet and the wave-0 hook Job); (d) `type: Opaque`.

**Known limitation to state in the plan, not discover:** Argo CD has **no health assessment for
`bitnami.com/SealedSecret` on this cluster** (research, measured), so the wave orders the *apply* but
cannot wait for decryption. Sealing is produced by the repo's own helper, never by hand — see Shared
Patterns.

---

### 5. `occ-k8s-app-config/application-sets/automation/argocd/templates/projects.yaml` (MODIFY)

**Analog A — amend an existing project:** the `platform` block, L265–363 of the same file. Full
`AppProject` skeleton (the `roles` block at the end is per-project and must be written for a new project):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: Cluster-altering platform components (admission policies, pod-identity-webhook, reloader, homepage, cloudnative-pg)
  sourceRepos:
    - https://github.com/OttawaCloudConsulting/occ-k8s-app-config
    # CloudNativePG initiative Feature 7.1: ... Both spellings are listed
    # because ArgoCD matches the repoURL as written, and the override uses the scheme-less form
    - ghcr.io/cloudnative-pg/charts
    - oci://ghcr.io/cloudnative-pg/charts
  destinations:
    - namespace: admission-policies
      server: https://kubernetes.default.svc
      name: in-cluster
    # ... one entry per namespace, each with a comment when it breaks the
    #     basename==namespace convention ...
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    # ... etc
  namespaceResourceWhitelist:
    - group: apps
      kind: Deployment
    - group: ''
      kind: ConfigMap
    # ...
  orphanedResources:
    warn: false
  roles:
    - name: platform-observer
      description: Read-only access to platform Applications
      policies:
        - p, proj:platform:platform-observer, applications, get, platform/*, allow
    - name: platform-deployer
      description: Sync and refresh access to platform Applications
      policies:
        - p, proj:platform:platform-deployer, applications, sync, platform/*, allow
        - p, proj:platform:platform-deployer, applications, action/*, platform/*, allow
```

Gap to close if `platform` is the target (measured in research): its `namespaceResourceWhitelist` has
**no `apps/StatefulSet`, no `batch/Job`, no `bitnami.com/SealedSecret`**; its `destinations` has no
`nexus`; its `sourceRepos` has no `security-platform`. It *does* already carry `''/ServiceAccount`,
`''/ConfigMap`, `''/Service` and an **unscoped** `''/Namespace` in `clusterResourceWhitelist`.

**Analog B — a new narrow project, with the name-scoping precedent:** the `identity` block, L459–556.
This is the pattern to copy if OQ2 resolves to a new `security` project:

```yaml
  clusterResourceWhitelist:
    # Two name-scoped entries, deliberately not one unscoped entry -- see the merge-decision
    # comment above.
    - group: ''
      kind: Namespace
      name: authentik
    - group: ''
      kind: Namespace
      name: entra-federation
```

and the in-file comment that records this as measured, not assumed (L447–453):

```yaml
# MERGE DECISION, NOT A MECHANICAL UNION: occ-identity's `''/Namespace` entry was scoped
# `name: authentik` (Argo CD DOES validate a multi-source Application's
# CreateNamespace=true Namespace against this list, proven live). occ-entra-federation's
# `''/Namespace` entry was UNSCOPED. A naive union of the two would have collapsed to the
# broader, unscoped entry and silently discarded occ-identity's hardening.
```

`identity` also already lists `bitnami.com/SealedSecret` in its `namespaceResourceWhitelist` (L520–521) —
the exact entry the nexus overlay's SealedSecret needs, in the exact `group:`/`kind:` form.

**Removal-with-reason convention:** every entry that was ever removed carries a comment naming the Feature
that removed it and why (e.g. identity L469–473, L490–494). A new/amended block must follow it — comments
are load-bearing documentation in this file, not noise.

**Required kinds for the nexus chart** (from the research's fresh `helm template`, to be re-measured at
execution time before writing):
`''/ServiceAccount`, `''/ConfigMap`, `''/Service`, `apps/StatefulSet`, `batch/Job`,
`bitnami.com/SealedSecret`; cluster-scoped `''/Namespace` **name-scoped to `nexus`**. **Not** needed:
`''/PersistentVolumeClaim` (created by the StatefulSet controller) and `''/Secret` (created by the
sealed-secrets controller) — the `apps` project lists `SealedSecret` and not `Secret` for exactly this
reason.

---

### 6. `security-platform/kubernetes/nexus/templates/job-provision.yaml` (MODIFY, optional — OQ3)

**Analog:** the file's own existing annotation block (L65–70):

```yaml
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation
    "argocd.argoproj.io/hook": Sync
    "argocd.argoproj.io/sync-options": Replace=true
```

Quoted keys, quoted string values, Argo annotations after Helm ones. Any edit is **additive** — a stated
`argocd.argoproj.io/hook-delete-policy: BeforeHookCreation` and a comment on the
`ttlSecondsAfterFinished: 900` / Argo interaction. **Do not remove** `ttlSecondsAfterFinished`: the
template's own comment (L76+) records 900 as a *floor* protecting the `--timeout=300s` waits in plans
23-02 and 23-06. The in-file comment style — a stated reason next to every non-default value, e.g.
`backoffLimit: 0` at L72–75 — is the pattern for any new line.

---

### 7. `security_solution/docs/adr/adr022-*.md` (NEW)

**Analog:** `docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md`.

Filename convention (verified across `adr015`…`adr021`): `adrNNN-kebab-case-title.md`, no separator
between `adr` and the number.

Front matter and section skeleton:

```markdown
# ADR-021: Nexus Anonymous Read and Workstation Routing

**Status:** Accepted
**Date:** 2026-09-20
**Addresses:** NEXUS-02 — proxy repositories allow anonymous pull, with no authentication required for
read or proxy access — and NEXUS-04 — a workstation install script points a target repository's
package-manager configuration at a given Nexus instance

## Context

- **<Bolded claim sentence.>** <Measured evidence with byte counts and literal response bodies.>
- ...

## Decision

## Consequences

**Improved:** ...
**Tradeoff — <named tradeoff>:** ...

## What was NOT verified
```

Two house rules visible in ADR-021 and binding on ADR-022: (a) `docs/adr/` is **append-only** — ADR-020
and ADR-021 must not be edited; ADR-022 extends them in prose, as ADR-021 did to ADR-020 (see ADR-021
L22–26, L34–40); (b) the `## What was NOT verified` section is where this phase's un-closed items go —
specifically ADR-021 item 4 (no TLS/ingress) and item 1 (no real `dockerd` pull), which
25-RESEARCH.md says this phase does **not** close. Recording the exclusion explicitly is the convention;
silently skipping it is not.

---

### 8. `security-platform/kubernetes/nexus/README.md` (MODIFY)

**Analog:** its own limitation bullet at L233:

```markdown
- **Validation so far is a throwaway kind cluster plus a live container**, not a long-lived cluster. NEXUS-05 covers validation via a private ArgoCD overlay in Phase 25.
```

Bolded lead clause, then the qualifier, then the forward reference. Rewrite in place to name the homelab
result once it is measured; keep the forward-reference form for whatever remains open (TLS/ingress).

---

### 9. `security_solution/.planning/REQUIREMENTS.md` (MODIFY)

**Analog:** the NEXUS-01…04 rows in the same file.

Checklist form (L14–18):

```markdown
- [x] **NEXUS-02**: Proxy repos allow anonymous pull (no auth required for read/proxy access)
- [ ] **NEXUS-05**: Nexus chart validated live via private ArgoCD overlay deploy to the operator's homelab cluster
```

Traceability table form (L47–51):

```markdown
| NEXUS-02 | Phase 24 | Complete |
| NEXUS-05 | Phase 25 | Pending |
```

Both places must change together: `- [ ]` → `- [x]`, and `Pending` → `Complete`.

---

## Shared Patterns

### Bash gate discipline
**Source:** `security-platform/scripts/nexus-live-smoke.sh` L77–217 (accounting + helpers + summary)
**Apply to:** `scripts/nexus-homelab-validate.sh`
Four invariants, all present in the analog and all load-bearing: `pass`/`fail` never swallow a result
(no `|| true` on an assertion); `CHECKS_PASSED` is counted from the run so `ALL PASS` is unreachable when
nothing executed; `SKIPPED` is accounted separately from passes and never affects exit status; every
fetch yields three distinguishable verdicts (transport, status, size) so none masks another.

### Script file conventions (project rule)
**Source:** `.claude/rules/defensive-protocol-v2-anti-slop.md`; exemplified by every file in
`security-platform/scripts/`
**Apply to:** `scripts/nexus-homelab-validate.sh`
`#!/usr/bin/env bash` + `set -euo pipefail`; **never** set the executable bit; always invoked as
`bash scripts/<name>.sh`; an explicit exit-code table in the header; a WHY-THIS-EXISTS paragraph naming
the false pass the script prevents.

### Credential handling
**Source:** `nexus-live-smoke.sh` L246–251 (generation), L1023–1033 (stdin apply);
`occ-k8s-app-config/scripts/seal-secret.sh` L1–36 (sealing)
**Apply to:** the validation script and the SealedSecret file
Never on an argv; never echoed; `set -x` never enabled; a Secret is applied from **stdin**, not
`--from-literal`. For git delivery use the repo's own helper, which is env-driven and writes to a
gitignored output dir:

```bash
#   REQUIRED:
#     SECRET_NAME       — Kubernetes Secret name (e.g. argocd-github-scm)
#     SECRET_NAMESPACE  — Target namespace        (e.g. argocd)
#   SECRET PAYLOAD — at least one of:
#     SECRET_LITERAL_<KEY>=<value>
# The script writes:  $OUTPUT_DIR/${SECRET_NAME}-sealedsecret.yaml
# Nothing is committed — that is the developer's responsibility.
SEAL_ENV=path/to/.env bash scripts/seal-secret.sh
```

`gitleaks detect --no-git --redact` runs in the overlay repo's required `conformance` check, so the
alternative (a base64 value in a values file) fails the gate rather than shipping.

### Argo CD override-file rules (F-/R- rules)
**Source:** `application-sets/identity/authentik/argocd-overrides.yaml` and
`application-sets/platform/cloudnative-pg/argocd-overrides.yaml`; vocabulary in
`docs/reference/argocd-overrides-guide.md`
**Apply to:** the new `argocd-overrides.yaml`
`source: null` is required alongside `sources:` (F-11/R8); `spec.project` and `destination.*` are
schema-refused (F-10, G-6); `$patch: replace` is permitted only under `syncPolicy.automated` (R5/F-9);
`syncOptions` **replaces** and must restate the generator baseline in full (F-12); `retry` lives on
`spec.syncPolicy`, never `spec` (R9); exactly one override file, at the app-directory root (R32).
**Caution carried from research Pitfall 5:** `docs/reference/argocd-overrides-guide.md` documents the
*other* generator (`appset-cluster`). Treat the live `appset-apps` spec as authoritative for repo,
revision, glob depth and project derivation; the guide's merge semantics and F/R rules transfer intact.

### Comment-as-evidence style (both repos)
**Source:** `projects.yaml` L447–453; `cloudnative-pg/argocd-overrides.yaml` L100–112;
`nexus-live-smoke.sh` L415–424
**Apply to:** every file this phase writes
Every non-obvious value carries an adjacent comment naming **what was measured** and **which
feature/plan measured it** — byte counts, HTTP codes, observed retry gaps. A value with no measurement
next to it reads as a guess in both repos' review culture.

### Overlay-repo pre-merge gates
**Source:** `occ-k8s-app-config/docs/argocd/conformance/{c1.py,check_appconfig.py,check.py}` (verified
present), `scripts/discover_apps.py`, `.github/workflows/conformance.yaml`
**Apply to:** every overlay-repo file
Run `python3 docs/argocd/conformance/c1.py` and `python3 docs/argocd/conformance/check_appconfig.py`
from the overlay clone **before** opening the PR — they are the pre-commit hook and the required
`conformance` status check. `main` is protected: branch → PR → green `conformance` → merge. Direct push
is blocked (research Pitfall 6).

### Documentation-repo boundary
**Source:** `CLAUDE.md`
**Apply to:** the file-placement decision in every plan
Chart edits and the new validation script land in `security-platform`; overlay files land in
`occ-k8s-app-config`; **only** ADR-022, REQUIREMENTS traceability and blueprint/README prose land in this
documentation repo. `docs/adr/` is append-only. Run `bash scripts/check-adoption-guide.sh` if
`docs/adoption-guide.md` is touched.

---

## No Analog Found

None. Every file has an in-repo analog. Two partial gaps worth naming so the planner does not expect
more than exists:

| File | Gap | Substitute |
|------|-----|------------|
| `scripts/nexus-homelab-validate.sh` — the four new cluster-side checks (`ARGOCD-HOOK-PHASE`, `PROVISION-JOB-COMPLETE`, `PVC-DEFAULT-STORAGECLASS`, `SECOND-SYNC-IDEMPOTENT`) | No existing check reads Argo CD `Application` status; §7 of the analog talks to a kind cluster, not to Argo | Wrap the jq/kubectl one-liners in 25-RESEARCH.md "Code Examples" §4, §5 and §8 in the `KIND-JOB-COMPLETE` shape (L1053–1068): emptiness guard first, then `require_success`, verdict derived from a **measured value**, never from an exit code alone |
| `argocd-overrides.yaml` — a **git**-sourced chart from a *third-party* repo as source 1 | Both multi-source precedents use a Helm-repo/OCI chart for the upstream source; only the *local* source is git | authentik's source 3 (L385–387) is the git-source field shape (`repoURL` + `targetRevision` + `path`, no `chart:`); combine it with authentik source 2's `helm.valuesObject` + pinned-revision discipline |

---

## Metadata

**Ref the overlay line numbers are valid against:** `origin/main` @ `3d8753b`. Verified — `git diff
--stat origin/main` over `application-sets/identity/authentik`, `automation/argocd/templates/projects.yaml`,
`platform/cloudnative-pg` and `scripts/seal-secret.sh` shows changes **only** in two `authentik/blueprints/`
files, none of which is cited here. The local clone sits on branch `feat/identity-4.4-4.5-entra-proxy-created`
(`88b14a7`), but every cited file is byte-identical to `main`.
**Ref the security-platform line numbers are valid against:** `main` @ `aed14b9`, clean tree.

**Analog search scope:**
`security-platform/{scripts,workstation,kubernetes/nexus}`;
`occ-k8s-app-config/{application-sets/**,scripts,docs/argocd/conformance,docs/reference}`;
`security_solution/{docs/adr,.planning}`
**Files scanned:** 14 read (7 in full or near-full, 7 targeted-range); ~40 enumerated by listing
**Analogs selected:** 6 primary + 3 self-analogs (stopped at the strong matches; both repos' app
directories were enumerated in full, so no closer analog exists)
**Redaction applied:** all `encryptedData` values replaced with `<sealed>`; no IPs, VIPs, DNS names or
NAS endpoints appear in any excerpt (none were read); project/namespace placeholders `<project>` and
`<commit-sha>` used where the value is an open decision
**Pattern extraction date:** 2026-09-23
