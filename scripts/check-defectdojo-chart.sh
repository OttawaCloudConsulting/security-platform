#!/usr/bin/env bash
set -euo pipefail

# check-defectdojo-chart.sh — offline standing gate for the DefectDojo Helm
# chart (kubernetes/defectdojo) that Phase 26 builds.
#
# WHY THIS EXISTS. A DefectDojo chart can lint clean and install green while
# shipping an Ingress with no certificate issuer, chart-generated secrets that
# regenerate on every sync and orphan the AES-encrypted credentials already in
# the database, a floating image tag that migrates the findings schema
# unannounced, or a wrapper helper that silently renames every subchart object.
# None of those is visible in a `helm install` exit code: the pods come up, the
# chart is "working", and the defect ships. This script is the offline half of
# the evidence — a single command that decides PASS/FAIL for every chart
# invariant that can be decided from the chart source alone, without a cluster
# and without network access. It reports EVERY failure rather than stopping at
# the first, so one run tells you the whole story.
#
# It asserts 20 offline invariants. That count is a literal in three places
# which must move together in one commit: this line, the `check-defectdojo-chart:
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
#   bash scripts/check-defectdojo-chart.sh
#
# INTERMEDIATE-COMMIT CONVENTION — VACUOUS-PASS (as in check-nexus-chart.sh,
# NOT the expected-red convention of check-detector-parity.sh). This gate is
# created in plan 26-01, before the chart it asserts against exists, and it
# must exit 0 at every intermediate commit of the phase. It therefore opens
# with two named SKIP guards:
#   - kubernetes/defectdojo absent                         -> SKIP, exit 0
#   - kubernetes/defectdojo/templates/validate-tls.yaml    -> SKIP, exit 0
# Both print a line beginning `SKIP:` so a vacuous pass is never mistaken for
# a real one. The anti-vacuity guard lives later in the phase, which asserts
# the literal terminal `PASS - ... checks, 0 failures` line. Do not add further
# SKIP conditions, and do not "complete" this script by deleting these two.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CHART_DIR="kubernetes/defectdojo"
VALUES="${CHART_DIR}/values.yaml"

# ── Guard 1. Chart not created yet (plans 26-01/26-02) ───────────────────────
if [ ! -d "$CHART_DIR" ]; then
  echo "SKIP: chart not present yet — ${CHART_DIR} does not exist (vacuous pass, by design)"
  exit 0
fi

# ── Guard 2. Chart present but the TLS guard template is not (pre-26-03) ─────
if [ ! -f "${CHART_DIR}/templates/validate-tls.yaml" ]; then
  echo "SKIP: chart incomplete — ${CHART_DIR}/templates/validate-tls.yaml does not exist yet"
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
#
# The tarball name is DERIVED from Chart.yaml rather than hardcoded, so a
# deliberate subchart bump (the README's manual bump procedure) needs no edit
# here — and a Chart.yaml that no longer matches the vendored tarball is caught
# as the machine problem it is.
if ! DEP_VERSION=$(yq '.dependencies[0].version' "${CHART_DIR}/Chart.yaml"); then
  echo "PREFLIGHT FAIL: yq could not read .dependencies[0].version from ${CHART_DIR}/Chart.yaml"
  exit 2
fi
DEP_VERSION="${DEP_VERSION%\"}"
DEP_VERSION="${DEP_VERSION#\"}"
DEP_TGZ="${CHART_DIR}/charts/defectdojo-${DEP_VERSION}.tgz"
if [ ! -f "$DEP_TGZ" ]; then
  echo "PREFLIGHT FAIL: subchart not vendored — ${DEP_TGZ} does not exist"
  echo "run: helm dependency build ${CHART_DIR}"
  exit 2
fi

echo "check-defectdojo-chart: asserting 20 offline invariants against ${CHART_DIR}"

# templates/validate-tls.yaml aborts the render when ingress + TLS are on and no
# cert-manager issuer annotation is set, so a BARE render fails by design. Every
# POSITIVE assertion therefore goes through this one wrapper, which supplies a
# ClusterIssuer annotation. `gate-issuer` is an object name, not a credential.
#
# --namespace defectdojo is load-bearing, not cosmetic: Helm 4 `helm template`
# otherwise stamps the operator's CURRENT kube-context namespace into the
# output (measured: `namespace: argocd`), which makes this "offline" gate
# depend on whoever last ran `kubectl config set-context`.
render() {
  helm template t kubernetes/defectdojo --namespace defectdojo \
    --set 'defectdojo.django.ingress.annotations.cert-manager\.io/cluster-issuer=gate-issuer' "$@"
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

# Release `t` names subchart objects `t-defectdojo*`, `t-postgresql*` and
# `t-valkey*`. Objects are therefore selected by name PATTERN, never by an
# exact name that a future subchart naming change would silently miss.
PG_STS='select(.kind=="StatefulSet" and (.metadata.name | test("postgresql")))'
VALKEY_STS='select(.kind=="StatefulSet" and (.metadata.name | test("valkey")))'

# ── 1. CHART-LINT ────────────────────────────────────────────────────────────
# The chart must lint clean. `helm lint` evaluates the validate-tls.yaml guard
# too, so it takes the same issuer --set as render() — a bare lint would fail on
# the missing issuer and report a defect that is not one.
if ! lint_out=$(helm lint "$CHART_DIR" --namespace defectdojo --set 'defectdojo.django.ingress.annotations.cert-manager\.io/cluster-issuer=gate-issuer' 2>&1); then
  fail "CHART-LINT" "helm lint exited non-zero: $(printf '%s' "$lint_out" | tr '\n' ' ')"
fi

# ── 2. ISSUER-REQUIRED ───────────────────────────────────────────────────────
# D-11, and the first of FOUR checks (2, 3, 4, 6) that deliberately do NOT go
# through render(). render() injects `cert-manager.io/cluster-issuer=gate-issuer`,
# which would make the bare case un-bare, the issuer-only case a both-keys case,
# and the TLS-off case not issuer-free. So these call `helm template` directly.
#
# Helm's `required` cannot reach a key inside the subchart's annotation MAP, so
# the only mechanism that proves "no default issuer" is the fail guard in
# templates/validate-tls.yaml: a bare `helm template` must FAIL, and its message
# must name the value the consumer has to supply. If this check ever passes
# silently, the chart has grown a default issuer — which, for a public chart,
# is somebody else's environment baked into everyone's install.
if bare_err=$(helm template t "$CHART_DIR" --namespace defectdojo 2>&1 >/dev/null); then
  fail "ISSUER-REQUIRED" "a bare 'helm template ${CHART_DIR}' SUCCEEDED — the certificate issuer has a default (or the TLS guard is gone)"
else
  case "$bare_err" in
    *cert-manager.io/cluster-issuer*) ;;
    *) fail "ISSUER-REQUIRED" "bare 'helm template' failed, but not for the missing issuer; its message never mentions cert-manager.io/cluster-issuer: $(printf '%s' "$bare_err" | tr '\n' ' ')" ;;
  esac
fi

# ── 3. ISSUER-EITHER-KEY ─────────────────────────────────────────────────────
# The annotation KEY is the issuer-kind selector: a namespaced (or external)
# Issuer is `cert-manager.io/issuer`. A guard that only accepts the
# ClusterIssuer key would force every such consumer to disable TLS. Direct
# `helm template` call — see the comment on check 2 for why not render().
if ! ns_issuer_err=$(helm template t "$CHART_DIR" --namespace defectdojo \
  --set 'defectdojo.django.ingress.annotations.cert-manager\.io/issuer=gate-issuer' 2>&1 >/dev/null); then
  fail "ISSUER-EITHER-KEY" "'helm template' with only cert-manager.io/issuer set FAILED — the namespaced-issuer path is rejected: $(printf '%s' "$ns_issuer_err" | tr '\n' ' ')"
fi

# ── 4. ISSUER-NOT-BOTH ───────────────────────────────────────────────────────
# Setting both annotation keys hands cert-manager an ambiguous instruction; the
# guard must refuse it and say why. Direct `helm template` call — through
# render() the both-keys case would pass for the wrong reason.
if both_err=$(helm template t "$CHART_DIR" --namespace defectdojo \
  --set 'defectdojo.django.ingress.annotations.cert-manager\.io/cluster-issuer=gate-issuer' \
  --set 'defectdojo.django.ingress.annotations.cert-manager\.io/issuer=gate-issuer' 2>&1 >/dev/null); then
  fail "ISSUER-NOT-BOTH" "'helm template' with BOTH cert-manager.io/cluster-issuer and cert-manager.io/issuer set SUCCEEDED — the guard must refuse an ambiguous issuer"
else
  case "$both_err" in
    *"set only one of"*) ;;
    *) fail "ISSUER-NOT-BOTH" "both-keys 'helm template' failed, but its message never says 'set only one of': $(printf '%s' "$both_err" | tr '\n' ' ')" ;;
  esac
fi

# ── 5. TLS-SECRETNAME-REQUIRED ───────────────────────────────────────────────
# cert-manager ingress-shim names the Certificate after spec.tls.secretName,
# and upstream omits secretName entirely when it is empty — so an empty value
# yields an Ingress whose TLS block no issuer will ever fill. The guard must
# fail the render instead. This one goes through render() on purpose: the
# issuer must be present so that secretName is the ONLY thing wrong.
if sn_err=$(render --set defectdojo.django.ingress.secretName= 2>&1 >/dev/null); then
  fail "TLS-SECRETNAME-REQUIRED" "render with an empty defectdojo.django.ingress.secretName SUCCEEDED — the TLS guard does not check it"
else
  case "$sn_err" in
    *"secretName must be non-empty"*) ;;
    *) fail "TLS-SECRETNAME-REQUIRED" "empty-secretName render failed, but its message never says 'secretName must be non-empty': $(printf '%s' "$sn_err" | tr '\n' ' ')" ;;
  esac
fi

# ── 6. TLS-OFF-RENDERS ───────────────────────────────────────────────────────
# The guard must bite ONLY when TLS is on: a consumer terminating TLS elsewhere
# sets activateTLS=false and needs no issuer at all. Direct `helm template`
# call with NO issuer — through render() this would not be issuer-free and
# would prove nothing. The Ingress must still exist, without spec.tls.
if ! tls_off=$(helm template t "$CHART_DIR" --namespace defectdojo --set defectdojo.django.ingress.activateTLS=false); then
  fail "TLS-OFF-RENDERS" "'helm template' with activateTLS=false and no issuer FAILED — the TLS guard bites even when TLS is off"
elif ! tls_off_count=$(printf '%s\n' "$tls_off" | yq ea '[select(.kind=="Ingress")] | length'); then
  fail "TLS-OFF-RENDERS" "yq failed counting Ingresses in the activateTLS=false output"
elif [ "$(unquote "$tls_off_count")" != "1" ]; then
  fail "TLS-OFF-RENDERS" "expected exactly 1 Ingress with activateTLS=false, found ${tls_off_count}"
elif ! tls_off_has=$(printf '%s\n' "$tls_off" | yq 'select(.kind=="Ingress") | .spec | has("tls")'); then
  fail "TLS-OFF-RENDERS" "yq failed reading the Ingress spec in the activateTLS=false output"
elif [ "$(unquote "$tls_off_has")" != "false" ]; then
  fail "TLS-OFF-RENDERS" "expected the Ingress to carry no spec.tls with activateTLS=false, got has(\"tls\") == '${tls_off_has}'"
fi

# ── 7. INGRESS-ON ────────────────────────────────────────────────────────────
# D-09: the default render exposes DefectDojo through exactly one Ingress, on
# the placeholder host. Zero means the UI is unreachable; two means a stray
# duplicate route. Counted with `yq ea ... | length`, which exits 0 at zero.
if ! ing_count=$(render | yq ea '[select(.kind=="Ingress")] | length'); then
  fail "INGRESS-ON" "render or yq failed counting Ingresses on the default render"
elif [ "$(unquote "$ing_count")" != "1" ]; then
  fail "INGRESS-ON" "expected exactly 1 Ingress on the default render, found ${ing_count}"
elif ! ing_host=$(render | yq 'select(.kind=="Ingress") | .spec.rules[0].host'); then
  fail "INGRESS-ON" "render or yq failed reading spec.rules[0].host from the Ingress"
elif [ "$(unquote "$ing_host")" != "defectdojo.example.com" ]; then
  fail "INGRESS-ON" "expected spec.rules[0].host == defectdojo.example.com (the placeholder), got '${ing_host}'"
fi

# ── 8. TLS-ON ────────────────────────────────────────────────────────────────
# D-10: TLS defaults ON, and the three things cert-manager ingress-shim reads
# must all be present on the rendered Ingress — the TLS host, the Secret name
# it will write the certificate into, and the issuer annotation itself.
if ! tls_host=$(render | yq 'select(.kind=="Ingress") | .spec.tls[0].hosts[0]'); then
  fail "TLS-ON" "render or yq failed reading spec.tls[0].hosts[0] from the Ingress"
elif [ "$(unquote "$tls_host")" != "defectdojo.example.com" ]; then
  fail "TLS-ON" "expected spec.tls[0].hosts[0] == defectdojo.example.com, got '${tls_host}'"
fi
if ! tls_secret=$(render | yq 'select(.kind=="Ingress") | .spec.tls[0].secretName'); then
  fail "TLS-ON" "render or yq failed reading spec.tls[0].secretName from the Ingress"
elif [ "$(unquote "$tls_secret")" != "defectdojo-tls" ]; then
  fail "TLS-ON" "expected spec.tls[0].secretName == defectdojo-tls, got '${tls_secret}'"
fi
if ! tls_issuer=$(render | yq 'select(.kind=="Ingress") | .metadata.annotations."cert-manager.io/cluster-issuer"'); then
  fail "TLS-ON" "render or yq failed reading the cert-manager.io/cluster-issuer annotation from the Ingress"
elif [ "$(unquote "$tls_issuer")" != "gate-issuer" ]; then
  fail "TLS-ON" "expected the Ingress annotation cert-manager.io/cluster-issuer == gate-issuer (the value render() supplies), got '${tls_issuer}'"
fi

# ── 9. INGRESSCLASS-UNSET ────────────────────────────────────────────────────
# D-12: no ingressClassName by default, so the cluster's DEFAULT IngressClass
# wins. Pinning one controller's class name pins the chart to one cluster.
# The toggle half proves the value is wired, not inert: a consumer override
# must reach the Ingress verbatim.
if ! ic_has=$(render | yq 'select(.kind=="Ingress") | .spec | has("ingressClassName")'); then
  fail "INGRESSCLASS-UNSET" "render or yq failed reading the Ingress spec on the default render"
elif [ "$(unquote "$ic_has")" != "false" ]; then
  fail "INGRESSCLASS-UNSET" "expected has(\"ingressClassName\") == false on the default render, got '${ic_has}'"
fi
if ! ic_value=$(render --set defectdojo.django.ingress.ingressClassName=x | yq 'select(.kind=="Ingress") | .spec.ingressClassName'); then
  fail "INGRESSCLASS-UNSET" "render or yq failed with defectdojo.django.ingress.ingressClassName=x"
elif [ "$(unquote "$ic_value")" != "x" ]; then
  fail "INGRESSCLASS-UNSET" "expected ingressClassName 'x' to pass through verbatim, got '${ic_value}'"
fi

# ── 10. STORAGECLASS-OMITTED ─────────────────────────────────────────────────
# D-08: with no consumer override the Postgres StatefulSet's PVC must emit NO
# storageClassName key at all. An empty-string or explicit default value pins
# the chart to one cluster's storage; omitting the key lets the cluster default
# win. The toggle half proves a consumer storage class reaches the PVC verbatim.
if ! sc_omitted=$(render | yq "${PG_STS} | .spec.volumeClaimTemplates[0].spec | has(\"storageClassName\")"); then
  fail "STORAGECLASS-OMITTED" "render or yq failed while reading the Postgres StatefulSet volumeClaimTemplate"
elif [ "$(unquote "$sc_omitted")" != "false" ]; then
  fail "STORAGECLASS-OMITTED" "expected has(\"storageClassName\") == false on the Postgres StatefulSet's default render, got '${sc_omitted}' (empty means no StatefulSet named *postgresql* rendered)"
fi
if ! sc_value=$(render --set defectdojo.postgresql.primary.persistence.storageClass=test | yq "${PG_STS} | .spec.volumeClaimTemplates[0].spec.storageClassName"); then
  fail "STORAGECLASS-OMITTED" "render or yq failed with defectdojo.postgresql.primary.persistence.storageClass=test"
elif [ "$(unquote "$sc_value")" != "test" ]; then
  fail "STORAGECLASS-OMITTED" "expected storageClassName 'test' to pass through verbatim to the Postgres PVC, got '${sc_value}'"
fi

# ── 11. POSTGRES-PERSISTENT ──────────────────────────────────────────────────
# D-08: the findings database is persistent. A Postgres StatefulSet with no
# volumeClaimTemplate loses every finding on the first pod restart, silently.
if ! pg_vct=$(render | yq "${PG_STS} | .spec.volumeClaimTemplates | length"); then
  fail "POSTGRES-PERSISTENT" "render or yq failed counting the Postgres StatefulSet's volumeClaimTemplates"
elif [ "$(unquote "$pg_vct")" != "1" ]; then
  fail "POSTGRES-PERSISTENT" "expected exactly 1 volumeClaimTemplate on the Postgres StatefulSet, got '${pg_vct}' (empty means no StatefulSet named *postgresql* rendered)"
fi

# ── 12. VALKEY-EPHEMERAL ─────────────────────────────────────────────────────
# D-08: Valkey is only the Celery broker; its queue is rebuildable, so it
# carries no PVC. Upstream defaults valkey persistence ON (an 8Gi claim per
# install), which the wrapper turns off.
if ! vk_vct=$(render | yq "${VALKEY_STS} | .spec.volumeClaimTemplates | length"); then
  fail "VALKEY-EPHEMERAL" "render or yq failed counting the Valkey StatefulSet's volumeClaimTemplates"
elif [ "$(unquote "$vk_vct")" != "0" ]; then
  fail "VALKEY-EPHEMERAL" "expected 0 volumeClaimTemplates on the Valkey StatefulSet, got '${vk_vct}' (empty means no StatefulSet named *valkey* rendered)"
fi

# ── 13. NO-SECRETS-RENDERED ──────────────────────────────────────────────────
# D-13 / T-26-02: the default render contains NO Secret. Chart-generated secrets
# regenerate on every ArgoCD sync, and a regenerated DD_CREDENTIAL_AES_256_KEY
# orphans every credential already encrypted in the database. The consumer
# pre-creates the Secrets; the chart only references them.
if ! secret_count=$(render | yq ea '[select(.kind=="Secret")] | length'); then
  fail "NO-SECRETS-RENDERED" "render or yq failed counting Secrets on the default render"
elif [ "$(unquote "$secret_count")" != "0" ]; then
  fail "NO-SECRETS-RENDERED" "expected 0 Secrets on the default render (existingSecret contract, D-13), found ${secret_count}"
fi

# ── 14. CREATE-SECRET-OPT-IN ─────────────────────────────────────────────────
# D-13: generation stays available as an explicit opt-in (throwaway installs),
# and when opted into it must produce the four keys the workloads read. Only
# key NAMES are read and printed — never a data value (T-26-13).
required_secret_keys="DD_ADMIN_PASSWORD DD_SECRET_KEY DD_CREDENTIAL_AES_256_KEY METRICS_HTTP_AUTH_PASSWORD"
if ! secret_keysets=$(render --set defectdojo.createSecret=true | yq 'select(.kind=="Secret") | [((.data // {}) | keys | .[]), ((.stringData // {}) | keys | .[])] | join(",")'); then
  fail "CREATE-SECRET-OPT-IN" "render or yq failed reading Secret key names with defectdojo.createSecret=true"
else
  found_secret=false
  while IFS= read -r keyset; do
    keyset="$(unquote "$keyset")"
    all_present=true
    for k in $required_secret_keys; do
      case ",${keyset}," in
        *",${k},"*) ;;
        *) all_present=false ;;
      esac
    done
    if [ "$all_present" = "true" ]; then
      found_secret=true
    fi
  done <<< "$secret_keysets"
  if [ "$found_secret" != "true" ]; then
    fail "CREATE-SECRET-OPT-IN" "with defectdojo.createSecret=true no single Secret carries all of ${required_secret_keys}; key names seen per Secret: $(printf '%s' "$secret_keysets" | tr '\n' ' ')"
  fi
fi

# ── 15. IMAGE-PIN ────────────────────────────────────────────────────────────
# D-03 / T-26-04: DefectDojo runs schema migrations on start, so a floating tag
# is an unannounced migration of the findings database. Four pin points must
# agree (today 3.3.200): the django and nginx image tags in values.yaml, the
# wrapper Chart.yaml appVersion, and the appVersion inside the vendored
# subchart tarball. Any drift between them is a half-done version bump.
pin_ok=true
if ! pin_django=$(yq '.defectdojo.images.django.image.tag' "$VALUES"); then
  fail "IMAGE-PIN" "yq failed reading .defectdojo.images.django.image.tag from ${VALUES}"
  pin_ok=false
fi
if ! pin_nginx=$(yq '.defectdojo.images.nginx.image.tag' "$VALUES"); then
  fail "IMAGE-PIN" "yq failed reading .defectdojo.images.nginx.image.tag from ${VALUES}"
  pin_ok=false
fi
if ! pin_wrapper=$(yq '.appVersion' "${CHART_DIR}/Chart.yaml"); then
  fail "IMAGE-PIN" "yq failed reading .appVersion from ${CHART_DIR}/Chart.yaml"
  pin_ok=false
fi
if ! pin_subchart=$(tar -xOzf "$DEP_TGZ" defectdojo/Chart.yaml | yq '.appVersion'); then
  fail "IMAGE-PIN" "tar or yq failed reading defectdojo/Chart.yaml appVersion from ${DEP_TGZ}"
  pin_ok=false
fi
if [ "$pin_ok" = "true" ]; then
  pin_django="$(unquote "$pin_django")"
  pin_nginx="$(unquote "$pin_nginx")"
  pin_wrapper="$(unquote "$pin_wrapper")"
  pin_subchart="$(unquote "$pin_subchart")"
  if [ -z "$pin_django" ] || [ "$pin_django" = "null" ]; then
    fail "IMAGE-PIN" ".defectdojo.images.django.image.tag is unset in ${VALUES} — the django image floats"
  elif [ "$pin_django" != "$pin_nginx" ] || [ "$pin_django" != "$pin_wrapper" ] || [ "$pin_django" != "$pin_subchart" ]; then
    fail "IMAGE-PIN" "pin points disagree: values django='${pin_django}' nginx='${pin_nginx}', wrapper Chart.yaml appVersion='${pin_wrapper}', subchart ${DEP_TGZ} appVersion='${pin_subchart}'"
  fi
fi

# ── 16. RENDERED-IMAGES ──────────────────────────────────────────────────────
# D-03: IMAGE-PIN proves the values agree; this proves they are the values
# the workloads actually RUN. Every rendered defectdojo/defectdojo-* image must
# end in :<wrapper Chart.yaml appVersion> (today 3.3.200), and at least one
# must exist — zero matches would make the loop below vacuously green.
if ! expected_tag=$(yq '.appVersion' "${CHART_DIR}/Chart.yaml"); then
  fail "RENDERED-IMAGES" "yq failed reading .appVersion from ${CHART_DIR}/Chart.yaml"
elif expected_tag="$(unquote "$expected_tag")" && { [ -z "$expected_tag" ] || [ "$expected_tag" = "null" ]; }; then
  fail "RENDERED-IMAGES" "${CHART_DIR}/Chart.yaml has no appVersion to compare rendered images against"
elif ! rendered_images=$(render | yq '.. | select(tag == "!!map") | select(has("image")) | .image | select(tag == "!!str")'); then
  fail "RENDERED-IMAGES" "render or yq failed collecting image references from the default render"
else
  dd_image_count=0
  while IFS= read -r img; do
    img="$(unquote "$img")"
    case "$img" in
      *defectdojo/defectdojo-*)
        dd_image_count=$((dd_image_count + 1))
        case "$img" in
          *":${expected_tag}") ;;
          *) fail "RENDERED-IMAGES" "rendered image '${img}' is not pinned to :${expected_tag}" ;;
        esac
        ;;
    esac
  done <<< "$rendered_images"
  if [ "$dd_image_count" -eq 0 ]; then
    fail "RENDERED-IMAGES" "no rendered image matches defectdojo/defectdojo- — nothing to check, which is itself a defect"
  fi
fi

# ── 17. SITEURL-MATCHES-HOST ─────────────────────────────────────────────────
# DD_SITE_URL does not follow the host: override one without the other and
# every link in notifications and Jira points at the wrong place. The shipped
# placeholder pair must therefore be consistent, so a consumer who copies the
# pattern copies a correct one.
if ! dd_host=$(yq '.defectdojo.host' "$VALUES"); then
  fail "SITEURL-MATCHES-HOST" "yq failed reading .defectdojo.host from ${VALUES}"
elif ! dd_site=$(yq '.defectdojo.siteUrl' "$VALUES"); then
  fail "SITEURL-MATCHES-HOST" "yq failed reading .defectdojo.siteUrl from ${VALUES}"
elif [ "$(unquote "$dd_host")" = "null" ] || [ -z "$(unquote "$dd_host")" ]; then
  fail "SITEURL-MATCHES-HOST" ".defectdojo.host is unset in ${VALUES}"
elif [ "$(unquote "$dd_site")" != "https://$(unquote "$dd_host")" ]; then
  fail "SITEURL-MATCHES-HOST" "expected .defectdojo.siteUrl == 'https://$(unquote "$dd_host")' in ${VALUES}, got '${dd_site}'"
fi

# ── 18. UWSGI-FOOTPRINT ──────────────────────────────────────────────────────
# Measured: upstream uwsgi defaults OOMKill the django pod — maxFd 0 sizes the
# fd table from RLIMIT_NOFILE, and 4 processes overrun a 512Mi limit on the
# first login. The wrapper's values must reach the ConfigMap uwsgi reads. The
# ConfigMap is selected by the key it carries, not by name, because the
# Postgres and Valkey subcharts ship ConfigMaps of their own.
uwsgi_cm='select(.kind=="ConfigMap" and ((.data // {}) | has("DD_UWSGI_NUM_OF_PROCESSES")))'
if ! uwsgi_procs=$(render | yq "${uwsgi_cm} | .data.DD_UWSGI_NUM_OF_PROCESSES"); then
  fail "UWSGI-FOOTPRINT" "render or yq failed reading DD_UWSGI_NUM_OF_PROCESSES from the ConfigMap"
elif [ "$(unquote "$uwsgi_procs")" != "2" ]; then
  fail "UWSGI-FOOTPRINT" "expected DD_UWSGI_NUM_OF_PROCESSES == \"2\" in the rendered ConfigMap, got '${uwsgi_procs}' (empty means no ConfigMap carries the key)"
fi
if ! uwsgi_maxfd=$(render | yq "${uwsgi_cm} | .data.DD_UWSGI_MAX_FD"); then
  fail "UWSGI-FOOTPRINT" "render or yq failed reading DD_UWSGI_MAX_FD from the ConfigMap"
else
  uwsgi_maxfd="$(unquote "$uwsgi_maxfd")"
  if [ -z "$uwsgi_maxfd" ] || [ "$uwsgi_maxfd" = "null" ]; then
    fail "UWSGI-FOOTPRINT" "expected DD_UWSGI_MAX_FD to be non-empty in the rendered ConfigMap, got '${uwsgi_maxfd}'"
  fi
fi

# ── 19. NO-HELPER-COLLISION ──────────────────────────────────────────────────
# T-26-09: Helm's named-template namespace is global across parent and
# subcharts. A wrapper `define "defectdojo.fullname"` silently overrides the
# subchart's helper and renames every subchart object (measured). The wrapper
# ships no _helpers.tpl at all; any helper it ever needs takes a distinct
# prefix. grep exit 1 means "no match" (the pass); exit 2 is a real error.
helper_rc=0
helper_hits=$(grep -rnE 'define[[:space:]]+"defectdojo\.' "${CHART_DIR}/templates") || helper_rc=$?
if [ "$helper_rc" -eq 0 ]; then
  fail "NO-HELPER-COLLISION" "wrapper templates define a defectdojo.* named template, which overrides the subchart's: $(printf '%s' "$helper_hits" | tr '\n' ' ')"
elif [ "$helper_rc" -ne 1 ]; then
  fail "NO-HELPER-COLLISION" "grep exited ${helper_rc} while scanning ${CHART_DIR}/templates"
fi
if [ -e "${CHART_DIR}/templates/_helpers.tpl" ]; then
  fail "NO-HELPER-COLLISION" "${CHART_DIR}/templates/_helpers.tpl exists — the wrapper is values-only by design"
fi

# ── 20. PLACEHOLDER-ONLY ─────────────────────────────────────────────────────
# T-26-01: this is a PUBLIC, generic-first chart. Its values and Chart.yaml
# carry placeholders only — no real hostname, issuer name or environment
# identifier. Those belong in a consumer's overlay, never in the chart.
placeholder_rc=0
placeholder_hits=$(grep -inE 'ottawacloudconsulting|letsencrypt|occ-|homelab' "$VALUES" "${CHART_DIR}/Chart.yaml") || placeholder_rc=$?
if [ "$placeholder_rc" -eq 0 ]; then
  fail "PLACEHOLDER-ONLY" "environment identifiers found in ${VALUES} or ${CHART_DIR}/Chart.yaml: $(printf '%s' "$placeholder_hits" | tr '\n' ' ')"
elif [ "$placeholder_rc" -ne 1 ]; then
  fail "PLACEHOLDER-ONLY" "grep exited ${placeholder_rc} while scanning ${VALUES} and ${CHART_DIR}/Chart.yaml"
fi

# ── Terminal summary ─────────────────────────────────────────────────────────
CHECK_COUNT=20

if [ "${#FAILURES[@]}" -gt 0 ]; then
  for line in "${FAILURES[@]}"; do
    echo "$line"
  done
  echo "FAILED - ${#FAILURES[@]} check(s)"
  exit 1
fi

echo "PASS - ${CHECK_COUNT} checks, 0 failures"
exit 0
