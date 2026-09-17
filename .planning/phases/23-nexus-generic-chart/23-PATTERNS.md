# Phase 23: Nexus Generic Chart - Pattern Map

**Mapped:** 2026-09-17
**Files analyzed:** 17 (9 new chart files, 2 new gate scripts, 1 new ADR, 5 modified)
**Analogs found:** 15 / 17 (9 exact, 1 role-match, 1 partial, 4 external-analog, 2 none)

> **Two repos are in play.** Files 1-14 land in `repos/security-platform/` (the sibling
> repo, **present locally** at
> `/Users/christian/git-repos/OCC-github/development_environment/security_solution/repos/security-platform`).
> Files 15-17 land in this docs repo (`security_solution`). Every excerpt below was read
> from a real file in one of those two trees, or from the upstream `stevehipwell/nexus3`
> 5.26.0 chart untarred into the session scratchpad.

---

## READ THIS FIRST: Superseded Research Items

`23-RESEARCH.md` was written against the **pre-revision** CONTEXT.md. Its
`<user_constraints>` block and parts of `## Code Examples` are stale. The planner must
treat `23-CONTEXT.md` (revised 2026-09-17) as authoritative where they conflict:

| Research says | CONTEXT.md (authoritative) says | Effect on the pattern |
|---|---|---|
| RESEARCH `<user_constraints>` D-01: "Sonatype's official upstream `nexus3` chart" | **D-01 REVISED:** wrap **community `stevehipwell/nexus3`** as a subchart | Chart.yaml dependency is settled — A1 is closed, no user-confirmation gate needed |
| RESEARCH Code Examples, helm body: `"remoteUrl":"https://charts.helm.sh/stable"` | **D-05 REVISED:** Helm proxy upstream has **no default**; consumer must set it | **Do NOT copy the helm JSON body verbatim.** `values.yaml` leaves the helm `remoteUrl` unset; README documents it |
| RESEARCH Q4/A9: "should the chart auto-accept the EULA? — needs user decision" | **D-09 NEW:** locked — `eula.accepted: false` default, explicit opt-in; Job calls the endpoint only when `true` | The EULA step is conditional, not unconditional |
| RESEARCH Pitfall 5: "the wrapper must set `persistence.enabled: true`" (advisory) | **D-10 NEW:** locked as a requirement | `values.yaml` sets it; `23-VALIDATION.md` asserts it |
| RESEARCH §Project Constraints: "new ADR must be the next free number after ADR-018" | `docs/adr/adr019-required-check-enforcement-live-exercise.md` **exists** | The new record is **ADR-020**, not ADR-019 |

The npm / pypi / docker JSON bodies in RESEARCH §Code Examples **are** still current and
were verified live — copy those.

---

## File Classification

| New/Modified File | Repo | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|---|
| `kubernetes/nexus/Chart.yaml` | security-platform | config (chart manifest) | declarative | RESEARCH §Code Examples (verified build) | none-in-repo |
| `kubernetes/nexus/Chart.lock` | security-platform | config (generated lockfile) | declarative | — (`helm dependency build` writes it) | none |
| `kubernetes/nexus/values.yaml` | security-platform | config | declarative | upstream `nexus3/values.yaml` (helm-docs `# --` style) | external-analog |
| `kubernetes/nexus/README.md` | security-platform | docs | — | `cicd/README.md` | exact |
| `kubernetes/nexus/.helmignore` | security-platform | config | — | `.gitignore` (sectioned-comment style) | partial |
| `kubernetes/nexus/files/provision.sh` | security-platform | utility / bootstrap script | request-response (REST) | `scripts/detect-npm.sh` (header) + `scripts/smoke-scans.sh` (rc-capture) | role-match |
| `kubernetes/nexus/templates/job-provision.yaml` | security-platform | k8s template | batch / event-driven (hook) | upstream `nexus3/templates/job-config.yaml` | external-analog |
| `kubernetes/nexus/templates/configmap-provision-script.yaml` | security-platform | k8s template | file-I/O (`.Files`) | upstream `nexus3/templates/configmap-config-scripts.yaml` | external-analog (exact shape) |
| `kubernetes/nexus/templates/configmap-repos.yaml` | security-platform | k8s template | transform (values → JSON) | upstream `nexus3/templates/configmap-config.yaml` | external-analog (exact shape) |
| `scripts/check-nexus-chart.sh` | security-platform | test (standing offline gate) | batch / assert-many | `scripts/check-workflow-uploads.sh` | exact |
| `scripts/nexus-live-smoke.sh` | security-platform | test (live smoke) | batch / docker-driven | `scripts/smoke-scans.sh` | exact |
| `.pre-commit-config.yaml` | security-platform | config | declarative | itself — the `exclude: ^fixtures/` entries | exact |
| `.gitignore` | security-platform | config | declarative | itself — sectioned comment blocks | exact |
| `README.md` (root) | security-platform | docs | — | itself — lines 30, 40 (**conflict, see below**) | exact |
| `CLAUDE.md` | security_solution | docs / project instructions | — | itself — §What This Repository Is | exact |
| `docs/adr/adr020-*.md` | security_solution | docs (ADR) | — | `docs/adr/adr019-required-check-enforcement-live-exercise.md` | exact |
| `docs/adr/README.md` | security_solution | docs (index) | — | itself — the index table | exact |

Not a file: the **Checkov delta measurement** (VALIDATION Wave 0 item 5) is a
verification task against `ghcr.io/bridgecrewio/checkov:3.3.17`, producing no committed
artifact. See §Metadata.

---

## Pattern Assignments

### `scripts/check-nexus-chart.sh` (test, offline standing gate)

**Analog:** `repos/security-platform/scripts/check-workflow-uploads.sh` (326 lines — read in full)

> **Copy the CONTRACT, not the MECHANISM.** The analog parses YAML with a quoted
> `python3 - <<'PY'` heredoc because its subject is two workflow files. This gate's
> assertions (per `23-VALIDATION.md`) are all `helm template … | yq …`, so the body
> should be plain bash + `helm`/`yq`/`jq`. Everything below is the reusable part.

**Header convention** (lines 1-33) — every standing gate in this repo opens with
shebang, `set -euo pipefail`, a WHY THIS EXISTS paragraph, the exit-code contract, the
never-chmod note, and a scope note:

```bash
#!/usr/bin/env bash
set -euo pipefail

# check-workflow-uploads.sh — offline static gate for the SARIF-upload and
# artifact-retention invariants that Phase 17 rests on.
#
# WHY THIS EXISTS. ADR-001 makes `continue-on-error: true` mandatory on every
# scan and upload step, so a SARIF upload that 403s ... leaves NO red step in
# the run. The pipeline ships broken-but-green. This script is the offline half
# of the evidence: a single command that decides PASS/FAIL for every invariant
# that can be decided from the workflow source alone, without a CI run and
# without network access.
```

**Three-way exit-code contract** (lines 18-25) — copy verbatim in spirit; substitute the
preflight subject:

```bash
# Exit codes — deliberately three, not two:
#   0  every check passed
#   1  at least one assertion failed  (a workflow defect — fix the YAML)
#   2  preflight failed: pyyaml is not importable (an INFRASTRUCTURE problem
#      on this machine, not a workflow defect). The two must never be
#      conflated, and there is deliberately NO regex fallback: a silent
#      fallback that "mostly works" is exactly the failure mode this gate
#      exists to prevent.
```

**Never-chmod note** (lines 27-28) — mandated by
`.claude/rules/defensive-protocol-v2-anti-slop.md` §Script Safety:

```bash
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/check-workflow-uploads.sh
```

**Repo-root anchoring + preflight → exit 2** (lines 35-42). For this gate the preflight
subjects are `helm`, `yq`, `jq` (all confirmed present on this workstation per RESEARCH
§Environment Availability):

```bash
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Preflight. Distinct exit code 2 — see the header.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "PREFLIGHT FAIL: python3 yaml module (pyyaml) not available — install with: python3 -m pip install pyyaml"
  exit 2
fi
```

**PREFLIGHT MUST ALSO CHECK THE SUBCHART TARBALL — exit 2, not 1.** Once `.gitignore`
excludes `kubernetes/*/charts/*.tgz` (Wave 0 item 4), a fresh clone has an empty `charts/`
directory, and both `helm lint` and `helm template` fail with *"found in Chart.yaml, but
missing in charts/ directory"*. That is an infrastructure state, not a chart defect — the
exact distinction the three-way contract exists for. Add a second preflight branch:

```bash
if ! compgen -G "kubernetes/nexus/charts/*.tgz" >/dev/null; then
  echo "PREFLIGHT FAIL: subchart not vendored — run: helm dependency build kubernetes/nexus"
  exit 2
fi
```

**CI implication:** any workflow or hook that runs this gate must run
`helm dependency build kubernetes/nexus` first (it needs network; the gate itself does not).

**A SINGLE RENDER WRAPPER — otherwise the gate scores ~10 spurious failures.**
`23-VALIDATION.md` row 11 asserts `helm template` **fails** when the admin-password value is
unset (a `required` guard). Rows 1-10 and 12-13 all invoke `helm template kubernetes/nexus`
with no such value — so under that same guard, **every one of them also fails**, and the
gate reports a defect in each. Define one wrapper used by every positive assertion:

```bash
render() {   # every positive assertion goes through this
  helm template t kubernetes/nexus --set <password-key>=dummy-not-a-real-password "$@"
}
```

and make the row-11 negative check the **one** call that deliberately omits it (asserting a
non-zero exit and a message naming the missing value). This shape holds whichever key wins
the `auth.adminPassword` / `nexus3.rootPassword.secret` reconciliation below.

**Accumulate-all-failures, never stop at the first** (lines 15-16 + 100-104). The bash
equivalent is `FAILURES=()` + `FAILURES+=("LABEL: msg")` (see `smoke-scans.sh` line 38):

```python
failures = []

def fail(label, message):
    failures.append("FAIL: {}: {}".format(label, message))
```

**Labelled checks.** Each assertion carries a stable UPPERCASE label
(`PERMISSIONS-CALLER`, `SHA-PIN`, `ARTIFACT-PATH-SAFETY`, …) introduced by a
`# ── N. LABEL ───` banner with a comment explaining the invariant, e.g. lines 126-128.
For this gate the natural labels map 1:1 onto `23-VALIDATION.md`'s rows:
`STORAGECLASS-OMITTED`, `STORAGECLASS-OVERRIDE`, `PERSISTENCE-ENABLED`, `JOB-HOOK`,
`REPO-BODIES`, `DOCKER-BODY`, `NO-DEFAULT-PASSWORD`, `CONFIG-DISABLED`,
`ANONYMOUS-DISABLED`, `CHART-LINT`.

**Terminal summary + counted checks** (lines 314-323):

```python
CHECK_COUNT = 10

if failures:
    for line in failures:
        print(line)
    print("FAILED - {} check(s)".format(len(failures)))
    sys.exit(1)

print("PASS - {} checks, 0 failures".format(CHECK_COUNT))
sys.exit(0)
```

**PLANNER DECISION — the intermediate-commit problem.** The chart does not exist at the
Wave 0 commit where this gate is created. The repo has **two established conventions**
and the planner must pick one explicitly:

- **(a) Vacuous-pass** — `check-workflow-uploads.sh` lines 30-33: *"this gate deliberately
  asserts NO counts of upload steps. It must pass at every intermediate commit of Phase 17
  … Do not 'complete' this script by adding a count."* Applied here: guard the whole body
  on `[ -d kubernetes/nexus ] || { echo "SKIP: chart not present yet"; exit 0; }`.
- **(b) Expected-red** — `check-detector-parity.sh` lines 30-34: *"AT THIS PLAN'S COMMIT
  (20-02) all four detect steps still delegate to their scripts — this gate is EXPECTED to
  be red. Plan 03 inlines the bodies and turns it green. See 20-02-SUMMARY.md for the
  predicted-vs-observed failure shape recorded at this commit."*

RESEARCH §Validation Architecture names "the 17-01 lesson" (pass at every intermediate
commit) and "the 17-02 lesson" (distinct exit codes per check), which points at (a). Either
way the choice must be written into the script header, as both analogs do.

---

### `scripts/nexus-live-smoke.sh` (test, docker-driven live smoke)

**Analog:** `repos/security-platform/scripts/smoke-scans.sh` (758 lines — read in targeted sections)

**Temp dir + cleanup trap** (lines 31-35). **Extend the trap** to also `docker rm -f` the
Nexus container, otherwise a failed run leaks a container:

```bash
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
```

**Failure accumulator + skip channel** (lines 37-49) — note the explicit doctrine that a
skip is never a pass:

```bash
FAILURES=()
# SKIPPED: sub-checks that did not run (optional tool absent, or the ecosystem
# is not present in this repository). Reported separately from FAILURES and
# separately from passes — a skip must never read as a pass — and it never
# affects the exit status.
SKIPPED=()
SCANS_PASSED=0
```

**`require_success` — the exact idiom for `provision.sh`** (lines 89-105). `provision.sh`
is expected to exit 0 on both passes, so this is the right helper:

```bash
# require_success: run a command that is expected to exit 0 (e.g. a docker
# build, or `trivy convert`, which are infrastructure/format-conversion steps,
# not scan verdicts). Any non-zero exit is a hard failure, distinct from
# run_scan's inverted PASS-on-1 semantics for actual scanners.
require_success() {
  local label="$1"
  shift
  local rc=0
  "$@" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    echo "==> ${label}: exit=${rc} (PASS - completed successfully)"
  else
    echo "==> ${label}: exit=${rc} (FAIL - expected exit 0)"
    FAILURES+=("${label}: exited ${rc}, expected 0")
  fi
  return 0
}
```

**Do NOT copy `run_scan` / `run_scan_rc`** (lines 51-84). Their PASS-on-exit-1 inversion is
scanner semantics; applying it here would score a *broken* provisioning run as a pass.

**Assertion helpers that push to `FAILURES` and never swallow their own result**
(lines 108-135). The comment on `require_parses_json` is the doctrine to carry into the
post-EULA artifact assertion (>100 KB tarball, per VALIDATION row 8):

```bash
# This is an assertion, not a print helper. It pushes to FAILURES exactly like
# require_nonempty and must never swallow its own result with `|| true` — an
# assertion that ignores its own failure IS the false-pass mechanism this
# script exists to prevent.
```

**Hard-tier preflight loop** (lines 202-207). Substitute `docker curl jq` (and `helm`/
`kubectl`/`kind` only if the plan keeps the kind smoke in this same script):

```bash
for bin in semgrep checkov trivy gitleaks docker python3 npm; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 1
  fi
done
```

**Section banners** (line 594 and peers): `echo "--- Container (docker build + Trivy image) ---"`.
Here: `--- 1. Boot Nexus ---`, `--- 2. provision.sh pass 1 ---`, `--- 3. provision.sh pass 2 (idempotency) ---`, `--- 4. Post-EULA artifact download ---`.

**Summary block** (lines 740-758) — copy verbatim in shape:

```bash
echo "=== Summary ==="
if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo "SKIPPED - ${#SKIPPED[@]} sub-check(s) did not run. A SKIP IS NOT A PASS:"
  for s in "${SKIPPED[@]}"; do echo "  - ${s}"; done
  echo
fi
if [ "${#FAILURES[@]}" -gt 0 ]; then
  echo "FAILED - one or more scanners did not produce the expected result:"
  for f in "${FAILURES[@]}"; do echo "  - ${f}"; done
  exit 1
else
  echo "ALL PASS - ${SCANS_PASSED} gated scan run(s) produced real, non-empty findings; ${#SKIPPED[@]} sub-check(s) skipped (not passed)."
  exit 0
fi
```

**Hard constraint — no literal password in this script.** `gitleaks` runs as a `pre-push`
hook (`.pre-commit-config.yaml` lines 103-108) over the whole repo. RESEARCH's live runs
used `admin123`; a committed literal is a finding. Generate at runtime, e.g.
`NEXUS_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '/+=')"`, and never `echo` it.

---

### `kubernetes/nexus/files/provision.sh` (utility, request-response REST)

**No single analog — decompose across three sources.**

**(1) Header convention** — `repos/security-platform/scripts/detect-npm.sh` lines 1-23.
Note the WHY, the both-branch logging contract, and the invoke-as line:

```bash
#!/usr/bin/env bash
set -euo pipefail

# detect-npm.sh — report whether this repository contains npm lockfiles.
#
# Writes the discovered paths, one per line, to the list file named by $1
# ... and logs on BOTH branches: "FOUND n ..." when lockfiles exist,
# "SKIP: ..." when none do. Always exits 0 — "no npm in this repo" is a valid
# answer, not an error ...
#
# Invoked both by .github/workflows/security.yml (SCA-01) and by
# scripts/smoke-scans.sh, so the smoke gate tests the logic CI runs rather
# than a copy of it. Never set the executable bit: invoke as
# `bash scripts/detect-npm.sh`, never `./scripts/detect-npm.sh`.
```

For this file the equivalent last paragraph is: *invoked in-container as
`args: ["/scripts/provision.sh"]`, and directly by `scripts/nexus-live-smoke.sh`, so the
smoke gate tests the script the Job runs rather than a copy of it. Never set the
executable bit — the ConfigMap volume sets `defaultMode: 0555` instead.*

**(2) The `|| true` justification convention** — `detect-npm.sh` lines 30-34. RESEARCH's
readiness poll uses `curl … || true`; it **must** carry the same inline justification, and
must never sit on a branch that decides success:

```bash
# The one legitimate `|| true` here: `grep -v` exits 1 when its input is empty,
# and under `set -o pipefail` that would abort the detector on a repository
# with no lockfiles at all. grep's rc=1 means "no match", not "error". This
# `|| true` is on the discovery pipeline only — never on a branch that decides
# whether files were found.
```

**(3) rc-capture idiom** — `smoke-scans.sh` `require_success` (above): `local rc=0; "$@" || rc=$?`.

**Core logic** — copy from `23-RESEARCH.md` §Code Examples (all three blocks were verified
live against `sonatype/nexus3:3.96.0-ubi`): bounded readiness poll on
`/service/rest/v1/status/writable` (60 × 10s, `exit 1` on exhaustion — *not* the unbounded
upstream loop, RESEARCH Pitfall 4); idempotent EULA `GET → jq '.accepted = true' → POST`
expecting **204**, wrapped in a `[ "${EULA_ACCEPTED}" = "true" ]` guard per **D-09**; and
`upsert_repo()` doing `GET → 200?PUT(204):POST(201)` with a hard `exit 1` on any other code.

**Never `|| true` a provisioning failure, never `set -x`, never echo `NEXUS_PASSWORD`**
(project rule §Error Handling + RESEARCH §Security Domain V7). The password arrives via
`secretKeyRef` env only; all curls use `-sS -o /dev/null -w '%{http_code}'`.

**shellcheck will lint this file** — the `.pre-commit-config.yaml` shellcheck hook is
`types: [shell]` with **no exclude** (lines 37-41). Keeping the script under `files/` as a
real file rather than inline in a template is deliberate for exactly this reason.

---

### `kubernetes/nexus/templates/configmap-provision-script.yaml` (template, file-I/O)

**Analog:** upstream `nexus3/templates/configmap-config-scripts.yaml` (15 lines, complete):

```yaml
{{- if and .Values.config.enabled .Values.rootPassword.secret -}}
{{- $root := . }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "nexus3.configScriptsConfigMapName" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "nexus3.labels" . | nindent 4 }}
data:
{{- range $path, $bytes := .Files.Glob "scripts/*" }}
  {{ $path | base }}: |
    {{- $root.Files.Get $path | nindent 4 }}
{{- end }}
{{- end -}}
```

Adapt: `.Files.Glob "files/*"` (or a single `.Files.Get "files/provision.sh"`), wrapper's
own `nexus.labels` helper, and the wrapper's own fullname prefix. Note `$root := .` is
required because `range` rebinds `.`.

---

### `kubernetes/nexus/templates/configmap-repos.yaml` (template, values → JSON transform)

**Analog:** upstream `nexus3/templates/configmap-config.yaml` lines 55-58 — the exact
`toJson` render RESEARCH §Security Domain V5 requires (never string concatenation, so a
hostile `remoteUrl` override cannot break out of the JSON body):

```yaml
{{- range $index, $repo := .Values.config.repos }}
  {{ $index | add 1000 | toString | substr 1 -1 }}-repo.json: |
    {{- omit $repo "password" "bearerToken" | toJson | nindent 4 }}
{{- end }}
```

Two things to carry over:
- `omit $repo "password" "bearerToken"` — secrets never render into a ConfigMap.
- `$index | add 1000 | toString | substr 1 -1` — zero-padded ordinal keys (`000-`, `001-`)
  so the consuming script's `for f in /config/*.json` glob is **deterministically ordered**.

Also see lines 10-11 for the simplest literal form (`anonymous.json`) — useful if the
planner prefers four fixed keys (`npm-repo.json`, `pypi-repo.json`, …) over ordinals.

**D-05 constraint:** the helm entry must render **only when the consumer has set a
`remoteUrl`** — guard it, do not emit a body with an empty/absent `remoteUrl`.

---

### `kubernetes/nexus/templates/job-provision.yaml` (template, batch / hook)

**Analog:** upstream `nexus3/templates/job-config.yaml` (163 lines).

**Copy — env wiring, image helper, args, volumes** (lines 43-62, 101-111). Note the
Service hostname is built from `nexus3.serviceName`, and the script is mounted `0555`:

```yaml
          env:
            - name: NEXUS_HOST
              value: {{ printf "http://%s.%s.svc.cluster.local:%s" (include "nexus3.serviceName" .) .Release.Namespace (toString .Values.service.port) }}
            - name: NEXUS_USER
              value: admin
            - name: NEXUS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.rootPassword.secret }}
                  key: {{ .Values.rootPassword.key }}
          args: ["/scripts/configure.sh"]
          volumeMounts:
            - mountPath: /tmp
              name: temp
            - mountPath: /scripts
              name: scripts
      volumes:
        - name: temp
          emptyDir: {}
        - name: scripts
          configMap:
            name: {{ include "nexus3.configScriptsConfigMapName" . }}
            defaultMode: 0555
```

**Copy — job spec tail** (lines 30, 159-162): `restartPolicy: Never`, `backoffLimit: 0`,
`ttlSecondsAfterFinished`. **Add** `activeDeadlineSeconds` (RESEARCH Pitfall 4 — upstream
exposes no such knob).

**Optional — config checksum annotations** (lines 22-24). Upstream uses these to force a
pod-template change when values move. Note the rationale does **not** transfer: once the
wrapper carries `helm.sh/hook-delete-policy: before-hook-creation`, the Job is deleted and
recreated on every upgrade regardless. Keep them only as a cheap provenance marker:

```yaml
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap-config.yaml") . | sha256sum }}
        checksum/scripts: {{ include (print $.Template.BasePath "/configmap-scripts.yaml") . | sha256sum }}
```

**DO NOT copy — the annotations block at lines 9-12.** Upstream renders Job annotations
only `{{- with .Values.config.job.annotations }}`, i.e. **absent by default**, and names the
Job `…-config-{{ .Release.Revision }}`. That is RESEARCH Pitfall 3 (breaks under ArgoCD,
where `.Release.Revision` is pinned at 1). The wrapper hard-codes real hooks instead
(from RESEARCH Pitfall 3, and asserted by `23-VALIDATION.md` row 4):

```yaml
annotations:
  "helm.sh/hook": post-install,post-upgrade
  "helm.sh/hook-weight": "0"
  "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
  "argocd.argoproj.io/hook": Sync
  "argocd.argoproj.io/sync-options": Replace=true
```

**Service-name hazard.** `nexus3.serviceName` → `nexus3.fullname`, which reads
`.Values.fullnameOverride` / `.Values.nameOverride` (`_helpers.tpl` lines 14-24) — both
inside D-07's passthrough surface. A hardcoded `{{ .Release.Name }}-nexus3` breaks when a
consumer sets either. Prefer re-deriving via the same logic under the `nexus3.` values
subtree, or document the limitation in the chart README.

---

### `kubernetes/nexus/values.yaml` (config)

**Analog:** upstream `nexus3/values.yaml` — adopt its **helm-docs `# --` annotation style**
so a future `helm-docs` run produces a values table:

```yaml
persistence:
  # -- If `true`, persistence should be enabled for the `StatefulSet`.
  enabled: false
  # -- Access mode for the `PersistentVolumeClaim`.
  accessMode: ReadWriteOnce
  # -- Storage class for the `PersistentVolumeClaim`, if not set the default will be used.
  storageClass:
  # -- Size of the `PersistentVolumeClaim`.
  size: 8Gi
```

Secondary in-repo analog for "pinned values with an inline rationale":
`repos/security-platform/versions.conf` (a header naming what regenerates it, then one
`# comment` per pinned value).

**Locked keys the planner must not rename** — `23-VALIDATION.md` hardcodes these paths in
its automated commands:

| Key path | Required value | Source |
|---|---|---|
| `nexus3.persistence.enabled` | `true` | D-10, VALIDATION row 3 |
| `nexus3.persistence.storageClass` | **omitted entirely** (not `""`) | D-06, VALIDATION rows 1-2 |
| `nexus3.config.enabled` | `false` | RESEARCH Pitfall 2, VALIDATION row 12 |
| `nexus3.config.anonymous.enabled` | `false` | VALIDATION row 13 (NEXUS-02 is Phase 24) |
| `eula.accepted` | `false` | D-09 |

**Reconciliation the planner must resolve (not a pattern — a genuine conflict):**
`23-VALIDATION.md` row 11 asserts the admin password value is **`auth.adminPassword`**
("`helm template` with no `auth.adminPassword` override fails (required value)"), while
RESEARCH §Pattern 3 and the upstream chart wire it as **`nexus3.rootPassword.secret`** —
a Secret *name*, not a password. These are different designs: a `required`-guarded
Secret-name passthrough cannot leak a credential into values, a literal `auth.adminPassword`
can. Pick one, and update whichever document is wrong. The upstream shape (lines 345-349 of
`nexus3/values.yaml`) is:

```yaml
rootPassword:
  # -- (string) Name of the secret containing the root password.
  secret:
  # -- Key in the secret containing the root password.
  key: password
```

**Digest-pin knobs** (RESEARCH Pitfall 6 — ADR-004 SHA-pin convention). Both helper images
expose `digest:` and both ship unpinned upstream:

```yaml
bashImage:
  repository: cgr.dev/chainguard/bash
  tag: latest          # ← mutable; pin via digest
  digest:
config:
  job:
    image:
      repository: docker.io/alpine/k8s
      tag: 1.31.2      # ← tag, not digest
      digest:
```

Digests measured in RESEARCH §Package Legitimacy Audit:
`chainguard/bash` → `sha256:d57efd5fbb52ca2092c6a4ef80ebe45db24bc496ad3a3103eeab15871a33dd95`;
`alpine/k8s:1.31.2` → `sha256:d489e3c7a6221af7394bc54a1498b641ada49ca51c344630966a62411b91a3df`.
The **Nexus** image tag stays floating per D-08 — these are incidental helper images, no conflict.

---

### `kubernetes/nexus/README.md` (docs)

**Analog:** `repos/security-platform/cicd/README.md` lines 1-40.

Structure to mirror: `# Title` → one-paragraph scope statement naming the milestone →
`## Architecture` (link out) → `## What This Delivers` with a **capability table** →
`## Requirements` with an **ID / Requirement / Status table** keyed to the requirement IDs:

```markdown
# CI/CD Security Gate

Security scanning pipelines for OttawaCloudConsulting repositories. This is Milestone 2 of
the security stack — the server-side enforcement layer that cannot be bypassed from a
developer workstation.

## Requirements

| ID | Requirement | Status |
|---|---|---|
| CICD-01 | Security pipeline with 5 parallel scan jobs | Complete (Phases 14-19) |
```

Here: `NEXUS-01` / `NEXUS-03` = Complete; `NEXUS-02` / `NEXUS-04` / `NEXUS-05` = Planned
(Phases 24/25). The README is also the home for the four consumer-facing facts RESEARCH
flags: the required admin Secret, the `eula.accepted` opt-in with the EULA URL
(`https://links.sonatype.com/products/nxrm/ce-eula`), the **unset Helm proxy `remoteUrl`**
(D-05) with example repos, and the CE ceiling (40,000 components / 100,000 requests per day).
markdownlint runs on it (`.pre-commit-config.yaml` lines 65-69, `types: [markdown]`, no exclude).

---

### `.pre-commit-config.yaml` (config, modified — **blocks all other work**)

**Analog:** the file's own `exclude:` entries. The convention is an inline `# ADD — <measured
reason>` comment, never a bare exclude (lines 19-24, 46-55, 89-91):

```yaml
      - id: terraform_fmt
        types: [terraform]
        exclude: ^fixtures/          # ADD
      - id: terraform_validate
        types: [terraform]
        exclude: ^fixtures/          # ADD — also avoids `terraform init` on an old provider
```

**The edit** — the `yamllint` hook currently sits at lines 56-62 with **no exclude**:

```yaml
  # --- YAML / Kubernetes manifests: yamllint ---
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.38.0
    hooks:
      - id: yamllint
        args: [-d, relaxed]
        types: [yaml]
```

Add, in the house style, citing the measurement from RESEARCH §Second-Order Effects
(`yamllint -d relaxed nexus3/templates/job-config.yaml` → `1:3 error syntax error … exit=1`):

```yaml
        exclude: ^kubernetes/.*/templates/   # ADD — Helm Go templates are not
                                             # valid YAML. Measured: `yamllint -d
                                             # relaxed` exits 1 on a rendered-at-
                                             # install-time template. Chart.yaml
                                             # and values.yaml stay linted.
```

`Chart.lock` is **not** covered either way: pre-commit types files by extension via
`identify`, and `.lock` is not tagged `yaml`, so the hook's `types: [yaml]` filter never
selects it. Do not claim the exclusion "keeps Chart.lock linted".

---

### `.gitignore` (config, modified)

**Analog:** the file itself (21 lines) — blank-line-separated sections, each with a
`# Category` comment, most-specific patterns only:

```gitignore
# Node
node_modules/

# pre-commit
.pre-commit-cache/
```

Append a new section (VALIDATION Wave 0 item 4):

```gitignore
# Helm — `helm dependency build` output; Chart.lock is committed instead
kubernetes/*/charts/*.tgz
```

Two consequences to carry into the plan:
- **The offline gate needs the tgz present** — see the exit-2 preflight under
  `check-nexus-chart.sh`. A fresh clone cannot `helm lint`/`helm template` until
  `helm dependency build` has run.
- **RESEARCH A8 is unverified**: if ArgoCD turns out **not** to rebuild dependencies itself,
  the tarball must be committed after all — verify in Phase 25 before relying on this.

---

### `README.md` (security-platform root, modified) — **CONFLICT, flag to planner**

The root README already commits to a **different directory name** for this exact content.
Line 30 (tree block) and line 40 (milestone table):

```
    ├── infrastructure/   # M3: Nexus, DefectDojo, Helm values
    └── runtime/          # M4: Trivy Operator, Falco, Kyverno
```

```markdown
| `infrastructure/` | M3 — Self-Hosted Services | Planned | Nexus, DefectDojo, Helm values, K8s manifests |
```

**D-03 locks `kubernetes/`**, and the user explicitly cares about this naming ("well-named
sub-directories", CONTEXT §Specific Ideas). Both lines must be updated to `kubernetes/`, and
the `Planned` status on the M3 row changes for the Nexus part. Pattern to copy for the tree
block is the existing per-file annotated-tree style at lines 22-32:

```
├── .github/              # Canonical CI/CD security-scanning workflow (Milestone 2)
│   ├── workflows/security.yml       # Callable workflow — the canonical copy a consumer adopts
```

---

### `CLAUDE.md` (security_solution, modified)

**Analog:** the file's own §What This Repository Is. The sentence to amend:

> The canonical, live-validated GitHub Actions workflows that implement Phase 2 of that
> blueprint live in `OttawaCloudConsulting/security-platform`, not in this repository —
> this repository documents them, it does not ship them.

Per D-02 / RESEARCH §Project Constraints this is an **explicit phase deliverable**: extend it
so `security-platform` is named as the host of **K8s packages** (`kubernetes/<service>/` Helm
charts) as well as the CI workflow. Keep the existing two-clause shape ("live in X, not in
this repository — this repository documents them, it does not ship them").

**Scope of the edit is the scope sentence only.** Do **not** add a `kubernetes/` bullet to
§Project Structure — that section enumerates *this* repository's own directories, and
`kubernetes/` is not one of them.

---

### `docs/adr/adr020-*.md` (new ADR) + `docs/adr/README.md` (index row)

**Analog:** `docs/adr/adr019-required-check-enforcement-live-exercise.md`.
**Number: ADR-020** — ADR-019 exists (RESEARCH's "next free after ADR-018" is stale).
Filename convention: `adrNNN-kebab-slug.md`, zero-padded, no hyphen after `adr`.

**Front matter + section skeleton:**

```markdown
# ADR-019: Required-Check Enforcement, Live-Exercised

**Status:** Accepted
**Date:** 2026-09-16
**Addresses:** VAL-02 — required-check enforcement exercised live, on a real repository's
ruleset, with GitHub's refusal of a merge captured verbatim ...

## Context
- **Bolded lead clause, then measured detail.** ...

## Decision
- **Bolded lead clause, then the decision.** ...

## Consequences

**Improved:** <measured outcome, with commands/values>

**Tradeoff — <one-line name>.** <what it costs>

## What was NOT verified

What WAS measured and must not be re-litigated: ...

1. **Claim.** <what remains open and why>
```

The ADR-019 house style is strict: every `## Context` and `## Decision` bullet opens with a
**bolded lead clause**; `## Consequences` is `**Improved:**` / `**Tradeoff — …**` paragraphs,
not a table; `## What was NOT verified` opens with a "what WAS measured" sentence then a
numbered list. RESEARCH's Assumptions **A1** (community chart substitution) and **A9** (EULA
consent) map directly into that last section, as do **A3** (Checkov), **A5** (`docker.pathEnabled`),
**A6** (ArgoCD hooks) and **A8** (ArgoCD dependency rebuild).

**Append-only rule** (CLAUDE.md §Editing Guidelines): do not touch ADR-007
(`externalize-helm-values`) or ADR-010 (`correct-nexus-framing`) even though both are
topically adjacent — reference them from the new record instead.

**Index row** — `docs/adr/README.md`, append one row in the existing format:

```markdown
| [ADR-019](adr019-required-check-enforcement-live-exercise.md) | Required-Check Enforcement, Live-Exercised | 2026-09-16 | Accepted |
```

---

### `kubernetes/nexus/Chart.yaml` / `Chart.lock` / `.helmignore`

No in-repo analog — this is the repo's first Helm chart. Use the **verified-to-build**
`Chart.yaml` from `23-RESEARCH.md` §Code Examples (it produced
`1 chart(s) linted, 0 chart(s) failed`):

```yaml
apiVersion: v2
name: nexus
version: 0.1.0
appVersion: "3.96.0"
description: Nexus Repository with npm, PyPI, Docker and Helm proxy repositories preconfigured.
dependencies:
  - name: nexus3
    version: 5.26.0
    repository: https://stevehipwell.github.io/helm-charts/
```

`Chart.lock` is written by `helm dependency build` and **committed**. `.helmignore` follows
the `.gitignore` sectioned-comment convention above; at minimum exclude `charts/*.tgz`,
`*.md` and editor/OS cruft.

---

## Shared Patterns

### Script safety (applies to `provision.sh`, `check-nexus-chart.sh`, `nexus-live-smoke.sh`)
**Source:** `.claude/rules/defensive-protocol-v2-anti-slop.md` §Script Safety, realised in
`scripts/check-workflow-uploads.sh` lines 27-28 and `scripts/detect-npm.sh` lines 22-23.
Every script: `#!/usr/bin/env bash` + `set -euo pipefail`, **never** `chmod +x`, always
invoked as `bash scripts/x.sh`. In-container, the executable bit is supplied by the
ConfigMap volume's `defaultMode: 0555`, not by git.

### Loud failure, no silent fallback (applies to all three scripts)
**Source:** `.claude/rules/defensive-protocol-v2-anti-slop.md` §Error Handling +
`smoke-scans.sh` lines 122-129.
No `|| true` on a branch that decides success; any `|| true` that does survive carries an
inline justification in the `detect-npm.sh` lines 30-34 style. An assertion helper must push
to `FAILURES` — never print and return.

### Three-way exit codes: pass / assertion-failure / infrastructure-failure
**Source:** `check-workflow-uploads.sh` lines 18-25, restated verbatim in
`check-detector-parity.sh` lines 20-25. `0` pass, `1` a real defect, `2` preflight/tooling
problem on this machine. Never conflate 1 and 2. For `check-nexus-chart.sh` the exit-2 set
is: missing `helm`/`yq`/`jq`, **and** an unvendored subchart (`charts/*.tgz` absent).

### Accumulate every failure, report them all, then exit
**Source:** `check-workflow-uploads.sh` lines 15-16 + 100-104 + 316-323;
`smoke-scans.sh` `FAILURES=()` (line 38) + summary (lines 740-758).
Applies to both new gate scripts.

### Secrets never in the repo, never in a ConfigMap, never in a log
**Source:** `.pre-commit-config.yaml` lines 103-108 (gitleaks, `pre-push`);
upstream `configmap-config.yaml` line 57 (`omit $repo "password" "bearerToken"`);
`job-config.yaml` lines 48-52 (`secretKeyRef`).
Applies to `values.yaml`, `configmap-repos.yaml`, `job-provision.yaml`, `provision.sh`,
`nexus-live-smoke.sh`, and both READMEs.

### `toJson`, never string concatenation, for consumer-supplied values
**Source:** upstream `configmap-config.yaml` lines 14, 20, 24, 32, 49, 53, 57.
Applies to `configmap-repos.yaml` — `remoteUrl` is a consumer-overridable trust boundary
(RESEARCH §Security Domain V5).

### Inline `# ADD — <measured reason>` on every config exclusion
**Source:** `.pre-commit-config.yaml` lines 21, 24, 49-55, 90-91.
Applies to the `yamllint` exclude and, by extension, to any `.gitignore` entry whose reason
is non-obvious.

### Documentation tables keyed to requirement IDs
**Source:** `cicd/README.md` lines 35-41; root `README.md` lines 38-41.
Applies to `kubernetes/nexus/README.md` and the root `README.md` milestone-table edit.

---

## No Analog Found

| File | Role | Data Flow | Reason | Planner falls back to |
|---|---|---|---|---|
| `kubernetes/nexus/Chart.yaml` | config | declarative | First Helm chart in either repo | `23-RESEARCH.md` §Code Examples — the exact file that built and linted clean |
| `kubernetes/nexus/Chart.lock` | config | declarative | Generated by `helm dependency build`; nothing to pattern | n/a — commit as generated |

Four further files (`values.yaml`, and the three `templates/*.yaml`) have **no in-repo**
analog but a strong **external** one in the upstream `stevehipwell/nexus3` 5.26.0 chart; all
four are covered with concrete excerpts above. They are counted as external-analog, not
no-analog.

---

## Metadata

**Analog search scope:**
- `repos/security-platform/` — `scripts/`, `.github/workflows/`, `cicd/`, `workstation/`,
  `.pre-commit-config.yaml`, `.gitignore`, `README.md`, `versions.conf`
  (full tree enumerated; **no `kubernetes/`, no Helm chart, no k8s manifest exists** —
  confirmed by `find . -name '*.yaml' -o -name '*.yml'`, which returned exactly four files,
  none of them a manifest)
- `security_solution/` — `CLAUDE.md`, `docs/adr/` (20 records), `.claude/rules/`
- Upstream `stevehipwell/nexus3` 5.26.0, untarred to the session scratchpad —
  `templates/job-config.yaml`, `templates/configmap-config-scripts.yaml`,
  `templates/configmap-config.yaml`, `templates/_helpers.tpl`, `values.yaml`

**Files read in full:** `scripts/check-workflow-uploads.sh` (326),
`scripts/detect-npm.sh` (56), `templates/job-config.yaml` (163),
`templates/configmap-config-scripts.yaml` (15), `templates/configmap-config.yaml` (63),
`.pre-commit-config.yaml` (108), `.gitignore` (21)
**Files read in targeted sections:** `scripts/smoke-scans.sh` (758 — header, helpers,
preflight, summary), `scripts/check-detector-parity.sh` (389 — header),
`templates/_helpers.tpl` (212 — name/fullname/image/serviceName),
`nexus3/values.yaml` (grep + three windows), `README.md` ×2, `cicd/README.md`,
`docs/adr/adr019-*.md`, `docs/adr/README.md`

**Not a file, tracked as a task:** Checkov delta measurement against
`ghcr.io/bridgecrewio/checkov:3.3.17` (VALIDATION Wave 0 item 5; RESEARCH A3, MEDIUM
confidence — the local Checkov 3.2.396 helm runner would not load against Helm v4.3.0).
`.github/workflows/security.yml` runs Checkov with `directory: .`, no `framework:` filter
and `soft_fail: false`, so a new `CKV_K8S_*` finding would hard-fail the CI gate.
Measure before asserting no impact; if findings appear, the workflow edit becomes an
18th file and should be surfaced back to the user.

**Pattern extraction date:** 2026-09-17

---

*Phase: 23-Nexus Generic Chart*
