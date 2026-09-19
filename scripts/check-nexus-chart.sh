#!/usr/bin/env bash
set -euo pipefail

# check-nexus-chart.sh — offline standing gate for the Nexus Helm chart
# (kubernetes/nexus) that Phase 23 builds.
#
# WHY THIS EXISTS. A Helm chart can render, lint clean and install green while
# shipping a default admin credential, an auto-accepted licence agreement, an
# unpinned helper image, or zero proxy repositories. None of those is visible
# in a `helm install` exit code: the pods come up, the chart is "working", and
# the defect ships. This script is the offline half of the evidence — a single
# command that decides PASS/FAIL for every chart invariant that can be decided
# from the chart source alone, without a cluster and without network access.
# It reports EVERY failure rather than stopping at the first, so one run tells
# you the whole story.
#
# It asserts 18 offline invariants. That count is a literal in three places
# which must move together in one commit: this line, the `check-nexus-chart:
# asserting ...` echo below, and CHECK_COUNT at the foot of the file.
#
# Exit codes — deliberately three, not two:
#   0  every check passed
#   1  at least one assertion failed  (a CHART defect — fix the chart)
#   2  preflight failed: a required binary or the vendored subchart tarball is
#      missing (an INFRASTRUCTURE problem on this machine, not a chart
#      defect). The two must never be conflated, and there is deliberately NO
#      regex/silent fallback: a fallback that "mostly works" is exactly the
#      failure mode this gate exists to prevent.
#
# Never set the executable bit on this file (project rule). Invoke as:
#   bash scripts/check-nexus-chart.sh
#
# INTERMEDIATE-COMMIT CONVENTION — VACUOUS-PASS (the 17-01 lesson, as in
# check-workflow-uploads.sh, NOT the expected-red convention of
# check-detector-parity.sh). This gate is created in plan 23-01, before the
# chart it asserts against exists, and it must exit 0 at every intermediate
# commit of the phase. It therefore opens with two named SKIP guards:
#   - kubernetes/nexus absent                        -> SKIP, exit 0
#   - kubernetes/nexus/templates/job-provision.yaml  -> SKIP, exit 0
# Both print a line beginning `SKIP:` so a vacuous pass is never mistaken for
# a real one. The anti-vacuity guard lives in plan 23-06 T1, which asserts the
# literal terminal line `PASS - 18 checks, 0 failures`. Do not add further
# SKIP conditions, and do not "complete" this script by deleting these two.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CHART_DIR="kubernetes/nexus"
VALUES="${CHART_DIR}/values.yaml"

# ── Guard 1. Chart not created yet (plans 23-01/23-02) ───────────────────────
if [ ! -d "$CHART_DIR" ]; then
  echo "SKIP: chart not present yet — ${CHART_DIR} does not exist (vacuous pass, by design)"
  exit 0
fi

# ── Guard 2. Chart present but the provisioning Job is not (pre-23-04) ───────
if [ ! -f "${CHART_DIR}/templates/job-provision.yaml" ]; then
  echo "SKIP: chart incomplete — ${CHART_DIR}/templates/job-provision.yaml does not exist yet"
  exit 0
fi

# ── Preflight 3. Required binaries. Exit 2 — infrastructure, not a defect. ───
for bin in helm yq jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "PREFLIGHT FAIL: required binary '${bin}' is not on PATH — this is a machine problem, not a chart defect"
    exit 2
  fi
done

# ── Preflight 4. Vendored subchart tarball. Exit 2 — infrastructure. ─────────
# .gitignore excludes kubernetes/*/charts/*.tgz (it is `helm dependency build`
# output, not source), so a FRESH CLONE has an empty charts/ directory and both
# `helm lint` and `helm template` fail with "found in Chart.yaml, but missing in
# charts/ directory". That is machine state, not a chart defect.
if ! compgen -G "${CHART_DIR}/charts/*.tgz" >/dev/null; then
  echo "PREFLIGHT FAIL: subchart not vendored — no ${CHART_DIR}/charts/*.tgz"
  echo "run: helm dependency build ${CHART_DIR}"
  exit 2
fi

echo "check-nexus-chart: asserting 18 offline invariants against ${CHART_DIR}"

# The admin credential is a Kubernetes Secret NAME wired through
# nexus3.rootPassword.secret; templates/job-provision.yaml wraps it in Helm's
# `required`, so a BARE render fails. Every POSITIVE assertion must therefore
# go through this one wrapper. `dummy-secret-name` is an object name, not a
# credential — there is no literal password anywhere in this chart or gate.
render() {
  helm template t kubernetes/nexus \
    --set nexus3.rootPassword.secret=dummy-secret-name "$@"
}

FAILURES=()

fail() {
  FAILURES+=("FAIL: $1: $2")
}

# yq v4 preserves source quoting, so a YAML `value: "true"` prints as `"true"`.
# Compare against the unquoted form rather than guessing which style the
# template author used.
unquote() {
  local s="$1"
  s="${s%\"}"
  s="${s#\"}"
  printf '%s' "$s"
}

# ── 1. CHART-LINT ────────────────────────────────────────────────────────────
# The chart must lint clean. `helm lint` evaluates `required` too, so it takes
# the same --set as render() — a bare lint would fail on the missing Secret
# name and report a defect that is not one.
if ! lint_out=$(helm lint "$CHART_DIR" --set nexus3.rootPassword.secret=dummy-secret-name 2>&1); then
  fail "CHART-LINT" "helm lint exited non-zero: $(printf '%s' "$lint_out" | tr '\n' ' ')"
fi

# ── 2. STORAGECLASS-OMITTED ──────────────────────────────────────────────────
# With no consumer override the StatefulSet's PVC must emit NO storageClassName
# key at all. An empty-string or explicit default value pins the chart to one
# cluster's storage; omitting the key is what lets the cluster default win.
if ! sc_omitted=$(render | yq 'select(.kind=="StatefulSet") | .spec.volumeClaimTemplates[0].spec | has("storageClassName")'); then
  fail "STORAGECLASS-OMITTED" "render or yq failed while reading the StatefulSet volumeClaimTemplate"
elif [ "$(unquote "$sc_omitted")" != "false" ]; then
  fail "STORAGECLASS-OMITTED" "expected has(\"storageClassName\") == false on the default render, got '${sc_omitted}'"
fi

# ── 3. STORAGECLASS-OVERRIDE ─────────────────────────────────────────────────
# A consumer-supplied storage class must reach the PVC verbatim.
if ! sc_value=$(render --set nexus3.persistence.storageClass=test | yq 'select(.kind=="StatefulSet") | .spec.volumeClaimTemplates[0].spec.storageClassName'); then
  fail "STORAGECLASS-OVERRIDE" "render or yq failed with nexus3.persistence.storageClass=test"
elif [ "$(unquote "$sc_value")" != "test" ]; then
  fail "STORAGECLASS-OVERRIDE" "expected storageClassName 'test' to pass through verbatim, got '${sc_value}'"
fi

# ── 4. PERSISTENCE-ENABLED ───────────────────────────────────────────────────
# D-10: persistence defaults ON. A default of false loses every repository on
# the first pod restart, silently.
if ! persist=$(yq '.nexus3.persistence.enabled' "$VALUES"); then
  fail "PERSISTENCE-ENABLED" "yq failed reading .nexus3.persistence.enabled from ${VALUES}"
elif [ "$(unquote "$persist")" != "true" ]; then
  fail "PERSISTENCE-ENABLED" "expected .nexus3.persistence.enabled == true in ${VALUES}, got '${persist}'"
fi

# ── 5. PASSTHROUGH-SIZE ──────────────────────────────────────────────────────
# D-07: the full upstream value surface stays overridable through the wrapper.
# The volume size is the canary — if it passes through, the wrapper is not
# re-declaring a narrowed subset of the subchart's keys.
if ! size=$(render --set nexus3.persistence.size=20Gi | yq 'select(.kind=="StatefulSet") | .spec.volumeClaimTemplates[0].spec.resources.requests.storage'); then
  fail "PASSTHROUGH-SIZE" "render or yq failed with nexus3.persistence.size=20Gi"
elif [ "$(unquote "$size")" != "20Gi" ]; then
  fail "PASSTHROUGH-SIZE" "expected requests.storage '20Gi' to pass through to the PVC, got '${size}'"
fi

# ── 6. IMAGE-TAG-FLOATING ────────────────────────────────────────────────────
# D-08: the Nexus image tag is deliberately NOT pinned in the wrapper — the
# subchart's appVersion supplies it, so a subchart bump is the single place a
# version changes. A tag here would silently override that and go stale.
if ! tag=$(yq '.nexus3.image.tag' "$VALUES"); then
  fail "IMAGE-TAG-FLOATING" "yq failed reading .nexus3.image.tag from ${VALUES}"
elif [ "$(unquote "$tag")" != "null" ]; then
  fail "IMAGE-TAG-FLOATING" "expected .nexus3.image.tag to be unset (null) in ${VALUES}, got '${tag}'"
fi

# ── 7. CONFIG-DISABLED ───────────────────────────────────────────────────────
# T-23-03: the subchart's config machinery turns on the Groovy scripting API
# (nexus.scripts.allowCreation), a remote-code-execution surface Sonatype
# disabled by default for cause. The wrapper must never re-enable it.
if ! cfg=$(yq '.nexus3.config.enabled' "$VALUES"); then
  fail "CONFIG-DISABLED" "yq failed reading .nexus3.config.enabled from ${VALUES}"
elif [ "$(unquote "$cfg")" != "false" ]; then
  fail "CONFIG-DISABLED" "expected .nexus3.config.enabled == false in ${VALUES} (Groovy scripting API), got '${cfg}'"
fi

# ── 8. ANONYMOUS-VALUE-PRESENT ───────────────────────────────────────────────
# This slot used to assert the NEGATION of NEXUS-02 — that the chart shipped no
# anonymous-access configuration at all — and before that it read
# `.nexus3.config.anonymous.enabled` back out of values.yaml and asserted it was
# `false`. That earlier form proved nothing. The subchart consumes
# `config.anonymous.*` ONLY from inside `{{- if .Values.config.enabled }}`, and
# this chart pins `config.enabled` to false, so the key was inert. Measured:
# rendering with `--set nexus3.config.anonymous.enabled=true` produced
# BYTE-IDENTICAL output. The check passed whatever the chart actually did, which
# is the definition of a gate that is not a gate.
#
# That lesson is precisely why this replacement asserts WIRING rather than a
# values key. NEXUS-02 gives the chart a real, consumer-facing top-level
# `anonymous.enabled`, and the only way to show a value is not inert is to
# TOGGLE it and watch the render change. So the model here is PASSTHROUGH-SIZE
# (check 5), the repo's established "toggling this changes the render" proof —
# not this check's own predecessor. Two renders, both read back from the
# provisioning Job's environment, and the PAIR is the assertion: a single read
# would pass just as happily against a hardcoded env entry.
#
# The old negative assertion — a grep of the render for
# `/service/rest/v1/security/anonymous` — is deliberately GONE rather than
# weakened. configmap-provision-script.yaml embeds files/provision.sh into the
# render, and provision.sh now calls that endpoint BY DESIGN, so the negative
# would be red on a correct chart. The shipped posture is still asserted, in two
# other places: ANONYMOUS-DEFAULT (check 18) reads the default out of
# values.yaml, and scripts/nexus-live-smoke.sh measures the consequence against
# a live instance.
anon_env_path='select(.kind=="Job") | [.spec.template.spec.containers[]?, .spec.template.spec.initContainers[]?] | .[].env[]? | select(.name=="ANONYMOUS_ENABLED") | .value'

if ! anon_on=$(render --set anonymous.enabled=true | yq "$anon_env_path"); then
  fail "ANONYMOUS-VALUE-PRESENT" "render or yq FAILED reading the Job env ANONYMOUS_ENABLED with --set anonymous.enabled=true (a tooling/template error, not a wrong value)"
elif [ "$(unquote "$anon_on")" != "true" ]; then
  fail "ANONYMOUS-VALUE-PRESENT" "expected the Job env ANONYMOUS_ENABLED to be 'true' when anonymous.enabled=true, got '${anon_on}' (an empty value means the env entry is missing entirely)"
fi

if ! anon_off=$(render | yq "$anon_env_path"); then
  fail "ANONYMOUS-VALUE-PRESENT" "render or yq FAILED reading the Job env ANONYMOUS_ENABLED on the default render (a tooling/template error, not a wrong value)"
elif [ "$(unquote "$anon_off")" != "false" ]; then
  fail "ANONYMOUS-VALUE-PRESENT" "expected the Job env ANONYMOUS_ENABLED to be 'false' on a DEFAULT render — the toggle has to change the render or the value is inert — got '${anon_off}' (an empty value means the env entry is missing entirely)"
fi

# ── 9. EULA-OPT-IN ───────────────────────────────────────────────────────────
# T-23-05 / D-09: accepting the Community Edition licence agreement on the
# consumer's behalf is a repudiation problem. It must be an explicit opt-in.
if ! eula=$(yq '.eula.accepted' "$VALUES"); then
  fail "EULA-OPT-IN" "yq failed reading .eula.accepted from ${VALUES}"
elif [ "$(unquote "$eula")" != "false" ]; then
  fail "EULA-OPT-IN" "expected .eula.accepted == false in ${VALUES} (explicit opt-in, D-09), got '${eula}'"
fi

# ── 10. HELPER-DIGESTS ───────────────────────────────────────────────────────
# T-23-SC: the two helper containers this chart pulls are supply chain. A tag
# is mutable; only a digest names one immutable image.
for digest_path in '.nexus3.bashImage.digest' '.provision.image.digest'; do
  if ! digest=$(yq "$digest_path" "$VALUES"); then
    fail "HELPER-DIGESTS" "yq failed reading ${digest_path} from ${VALUES}"
    continue
  fi
  case "$(unquote "$digest")" in
    sha256:*) ;;
    *) fail "HELPER-DIGESTS" "${digest_path} must be digest-pinned (sha256:...), got '${digest}'" ;;
  esac
done

# ── 11. REPO-BODIES ──────────────────────────────────────────────────────────
# NEXUS-01: the default render emits exactly three proxy repository bodies,
# and every body must be parseable JSON — a template that emits malformed JSON
# renders and installs fine, then fails at the provisioning API call.
repos_cm=""
if ! repos_cm=$(render | yq 'select(.kind=="ConfigMap" and (.metadata.name | test("-repos$")))'); then
  fail "REPO-BODIES" "render or yq failed while selecting the <release>-nexus-repos ConfigMap"
elif [ -z "$repos_cm" ]; then
  fail "REPO-BODIES" "no ConfigMap whose name ends '-repos' appears in the default render"
else
  if ! body_keys=$(printf '%s\n' "$repos_cm" | yq '.data | keys | sort | join(",")'); then
    fail "REPO-BODIES" "yq failed reading .data keys from the repos ConfigMap"
  elif [ "$(unquote "$body_keys")" != "000-npm.json,001-pypi.json,002-docker.json" ]; then
    fail "REPO-BODIES" "expected exactly 000-npm.json,001-pypi.json,002-docker.json on the default render, got '${body_keys}'"
  fi
  for body_key in 000-npm.json 001-pypi.json 002-docker.json; do
    if ! body=$(printf '%s\n' "$repos_cm" | yq ".data.\"${body_key}\""); then
      fail "REPO-BODIES" "yq failed extracting ${body_key}"
    elif ! printf '%s\n' "$body" | jq -e . >/dev/null 2>&1; then
      fail "REPO-BODIES" "${body_key} is not parseable JSON"
    fi
  done
fi

# ── 12. HELM-REPO-OPT-IN ─────────────────────────────────────────────────────
# D-05: the Helm proxy has NO default remote (Helm Hub is defunct and Artifact
# Hub is not a chart repository), so the fourth body appears only when a
# consumer supplies one. A baked-in default would ship a proxy pointing at a
# dead upstream.
if ! helm_keys=$(render --set repos.helm.remoteUrl=https://charts.jetstack.io | yq 'select(.kind=="ConfigMap" and (.metadata.name | test("-repos$"))) | .data | keys | sort | join(",")'); then
  fail "HELM-REPO-OPT-IN" "render or yq failed with repos.helm.remoteUrl set"
elif [ "$(unquote "$helm_keys")" != "000-npm.json,001-pypi.json,002-docker.json,003-helm.json" ]; then
  fail "HELM-REPO-OPT-IN" "expected 003-helm.json to appear only when repos.helm.remoteUrl is set, got '${helm_keys}'"
fi

# ── 13. DOCKER-BODY ──────────────────────────────────────────────────────────
# T-23-04: a docker proxy body without BOTH the `docker` and `dockerProxy`
# objects is accepted by the render and rejected by the Nexus API at run time.
if ! docker_body=$(render | yq 'select(.kind=="ConfigMap" and (.metadata.name | test("-repos$"))) | .data."002-docker.json"'); then
  fail "DOCKER-BODY" "render or yq failed extracting 002-docker.json"
elif ! printf '%s\n' "$docker_body" | jq -e '.docker and .dockerProxy' >/dev/null 2>&1; then
  fail "DOCKER-BODY" "002-docker.json must carry both the 'docker' and 'dockerProxy' objects"
fi

# ── 14. JOB-HOOK ─────────────────────────────────────────────────────────────
# T-23-01: exactly ONE Job in the rendered output, carrying both the Helm and
# the ArgoCD hook annotations. Two Jobs means a duplicate provisioning run; a
# missing annotation means the Job runs as an ordinary resource and either
# races the StatefulSet or is never pruned.
job_count=0
if ! job_count=$(render | yq 'select(.kind=="Job") | .kind' | grep -c '^Job$' || true); then
  job_count=0
fi
if [ "$job_count" != "1" ]; then
  fail "JOB-HOOK" "expected exactly 1 Job in the rendered output, found ${job_count}"
else
  if ! job_ann=$(render | yq 'select(.kind=="Job") | .metadata.annotations | keys | join(",")'); then
    fail "JOB-HOOK" "yq failed reading the Job's annotations"
  else
    for ann in 'helm.sh/hook' 'argocd.argoproj.io/hook'; do
      case "$job_ann" in
        *"$ann"*) ;;
        *) fail "JOB-HOOK" "the provisioning Job is missing the '${ann}' annotation (has: ${job_ann})" ;;
      esac
    done
  fi
fi

# ── 15. NO-DEFAULT-PASSWORD ──────────────────────────────────────────────────
# T-23-02, and the ONE check that deliberately does NOT go through render():
# a bare render must FAIL, naming the value the consumer has to supply. If this
# check ever passes silently, the chart has grown a default admin credential.
if bare_err=$(helm template t "$CHART_DIR" 2>&1 >/dev/null); then
  fail "NO-DEFAULT-PASSWORD" "a bare 'helm template ${CHART_DIR}' SUCCEEDED — the admin credential has a default"
else
  case "$bare_err" in
    *nexus3.rootPassword.secret*) ;;
    *) fail "NO-DEFAULT-PASSWORD" "bare render failed, but not for the missing Secret name; its message never mentions nexus3.rootPassword.secret: $(printf '%s' "$bare_err" | tr '\n' ' ')" ;;
  esac
fi

# ── 16. EULA-ENV ─────────────────────────────────────────────────────────────
# T-23-05: the opt-in must actually reach the provisioning Job. A values key
# nobody reads is a licence agreement the consumer thinks they accepted.
if ! eula_env=$(render --set eula.accepted=true | yq 'select(.kind=="Job") | [.spec.template.spec.containers[]?, .spec.template.spec.initContainers[]?] | .[].env[]? | select(.name=="EULA_ACCEPTED") | .value'); then
  fail "EULA-ENV" "render or yq failed reading the Job's EULA_ACCEPTED env var"
elif [ "$(unquote "$eula_env")" != "true" ]; then
  fail "EULA-ENV" "expected the Job env EULA_ACCEPTED to be 'true' when eula.accepted=true, got '${eula_env}'"
fi

# ── 17. JOB-NAME-LENGTH ──────────────────────────────────────────────────────
# A Job's metadata.name is a DNS LABEL, capped at 63 characters; the API server
# rejects a longer one AFTER `helm install` has already begun, which is the
# worst time to find out. nexus.fullname truncates at 63, and job-provision.yaml
# used to append "-provision" to that result — so a 53-character release name
# (Helm's own maximum) rendered a 69-character Job name. Both ends are asserted:
# the long name must FIT, and the short name must still render exactly
# `t-nexus-provision`, which is the binding scripts/nexus-live-smoke.sh and
# 23-02/23-06 select the Job by. A truncation that only satisfies the first is
# a different bug, not a fix.
#
# Both branches of nexus.fullname are exercised on purpose: a long RELEASE name
# takes the `printf "%s-%s"` branch, a long fullnameOverride takes the
# `.Values.fullnameOverride` branch, and a helper that bounded only one of them
# would pass a single-case check while still shipping the defect.
long_release="$(printf 'a%.0s' $(seq 1 53))"
long_override="$(printf 'b%.0s' $(seq 1 60))"

if ! rel_job=$(helm template "$long_release" "$CHART_DIR" --set nexus3.rootPassword.secret=dummy-secret-name | yq 'select(.kind=="Job") | .metadata.name'); then
  fail "JOB-NAME-LENGTH" "render or yq failed with a 53-character release name"
else
  rel_job="$(unquote "$rel_job")"
  if [ "${#rel_job}" -gt 63 ]; then
    fail "JOB-NAME-LENGTH" "a 53-character release name renders a ${#rel_job}-character Job name ('${rel_job}'); Kubernetes caps metadata.name at 63"
  fi
fi

if ! ovr_job=$(render --set fullnameOverride="$long_override" | yq 'select(.kind=="Job") | .metadata.name'); then
  fail "JOB-NAME-LENGTH" "render or yq failed with a 60-character fullnameOverride"
else
  ovr_job="$(unquote "$ovr_job")"
  if [ "${#ovr_job}" -gt 63 ]; then
    fail "JOB-NAME-LENGTH" "a 60-character fullnameOverride renders a ${#ovr_job}-character Job name ('${ovr_job}'); Kubernetes caps metadata.name at 63"
  fi
fi

if ! short_job=$(render | yq 'select(.kind=="Job") | .metadata.name'); then
  fail "JOB-NAME-LENGTH" "render or yq failed reading the Job name on the default render"
elif [ "$(unquote "$short_job")" != "t-nexus-provision" ]; then
  fail "JOB-NAME-LENGTH" "expected release 't' to still render 't-nexus-provision' — truncation must bite only on long names — got '${short_job}'"
fi

# ── 18. ANONYMOUS-DEFAULT ────────────────────────────────────────────────────
# T-24-04: the shipped anonymous posture is CLOSED, and it must not flip
# silently. That is the locked decision in 24-CONTEXT.md (§Chart default for
# anonymous access): `anonymous.enabled` ships OFF and the consumer opts in
# explicitly, because a public chart must not open unauthenticated read for
# anyone who installs it without reading values.yaml, and there is no TLS in
# front of the instance until Phase 25.
#
# Read from values.yaml DIRECTLY rather than from the render, and deliberately
# so: check 8 above proves the value is wired, this one proves what the chart
# SHIPS, which is a source-level fact. Character-for-character analog of
# EULA-OPT-IN (check 9), the repo's existing "a default must not silently flip"
# check.
if ! anon_default=$(yq '.anonymous.enabled' "$VALUES"); then
  fail "ANONYMOUS-DEFAULT" "yq failed reading .anonymous.enabled from ${VALUES}"
elif [ "$(unquote "$anon_default")" != "false" ]; then
  fail "ANONYMOUS-DEFAULT" "expected .anonymous.enabled == false in ${VALUES} (the locked opt-in default, 24-CONTEXT.md), got '${anon_default}'"
fi

# ── Terminal summary ─────────────────────────────────────────────────────────
CHECK_COUNT=18

if [ "${#FAILURES[@]}" -gt 0 ]; then
  for line in "${FAILURES[@]}"; do
    echo "$line"
  done
  echo "FAILED - ${#FAILURES[@]} check(s)"
  exit 1
fi

echo "PASS - ${CHECK_COUNT} checks, 0 failures"
exit 0
