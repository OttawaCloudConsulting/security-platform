#!/usr/bin/env bash
set -euo pipefail

# nexus-homelab-validate.sh — the LIVE gate for the Nexus chart (kubernetes/nexus)
# once it is deployed by Argo CD onto a real cluster, rather than by the
# throwaway container and kind cluster that scripts/nexus-live-smoke.sh owns.
#
# WHY THIS EXISTS. Argo CD decides a hook phase purely from the Job's exit code:
# a provisioning Job that exits 0 marks the Sync phase Succeeded and the
# Application goes Synced + Healthy, whatever state Nexus was actually left in.
# So Synced + Healthy proves nothing about the four proxy repositories. A Nexus
# whose EULA was never accepted still deploys green, still shows four correctly
# configured proxies in the UI, still serves repository METADATA with HTTP 200 —
# and answers every real package download with HTTP 403 and a ~192-byte refusal
# body. This gate therefore derives every verdict from a MEASURED value: a hook
# phase read back out of the Application's status, a log line count, a bound PVC
# on the measured default StorageClass, a downloaded byte count, a parsed Docker
# Bearer challenge, an exact HTTP status on a write that must be refused.
#
# Runtime: roughly 1-2 minutes against a warm instance (the first run through a
# cold proxy cache is dominated by upstream fetches), plus up to 15 minutes if
# the provisioning Job is still running when the gate starts — the
# `kubectl wait` below is bounded at 900s.
#
# Never set the executable bit on this file (project rule). Invoke as: bash scripts/nexus-homelab-validate.sh
#
# Example:
#   bash scripts/nexus-homelab-validate.sh \
#     --url http://127.0.0.1:8081 --context <kube-context> --sync-pass first
#
# TWO DESIGN FORKS, resolved in plan 25-01 and recorded here so a future reader
# does not re-open them:
#
#   1. This script REQUIRES --url and owns NO background process. A
#      `set -euo pipefail` gate that owned a backgrounded `kubectl port-forward`
#      would need PID ownership, a readiness poll and a port-collision guard,
#      and it would still have nothing to fall back on when the forward died.
#      Taking a URL instead means the operator runs the forward (or points the
#      gate at a LoadBalancer VIP / ingress once one exists — ADR-021 item 4
#      leaves that open) and the same gate is re-pointed with no code change.
#
#   2. This is a SIBLING of scripts/nexus-live-smoke.sh, not a parameterised
#      version of it. That script keeps its 25 green checks untouched; changing
#      it in place would put a passing gate at risk in the middle of the phase
#      that depends on it. The accounting discipline below (FAILURES / SKIPPED /
#      CHECKS_PASSED and the three-branch summary) is lifted from it verbatim.
#
# Exit codes:
#   0  every live check that ran passed, or nothing ran (the summary then says
#      NOTHING RAN, never ALL PASS)
#   1  at least one live check failed, or a required hard-tier binary
#      (curl, jq) is missing. `kubectl` is SOFT tier: absent, the cluster-side
#      checks produce SKIPPED entries, not failures, and the HTTP checks still
#      run against --url.
#   2  usage error (a required argument is missing, a value is invalid, or an
#      argument is unknown)
#
# Credentials: the only credential this script touches is the Nexus admin
# password, read from the cluster Secret `nexus-admin` into a shell variable. It
# is never taken from argv, never echoed, and `set -x` is never enabled anywhere
# in this file. No host, VIP, DNS name or password is written into this file:
# the only host input is --url at runtime.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'USAGE_EOF'
Usage: bash scripts/nexus-homelab-validate.sh --url <URL> --context <kube-context> --sync-pass <first|second> [options]

Required (there are NO defaults for these three — the gate refuses to guess):
  --url <URL>                  Base URL of the Nexus instance under test, e.g. the
                               local end of an operator-run `kubectl port-forward`.
  --context <kube-context>     kubeconfig context every kubectl call is pinned to.
                               KUBECONFIG is honoured from the environment.
  --sync-pass <first|second>   Which Argo CD sync this run follows. `first` expects
                               the provisioning Job to log action=created for all
                               four repositories; `second` expects action=updated
                               and evaluates SECOND-SYNC-IDEMPOTENT.

Optional:
  --namespace <ns>             Namespace Nexus is deployed in (default: nexus)
  --argocd-namespace <ns>      Namespace Argo CD runs in (default: argocd)
  --app-name <name>            Argo CD Application name (default: nexus)
  -h, --help                   Print this help and exit 0

Environment overrides for the upstream packages probed (an upstream yank must
not be indistinguishable from a proxy failure):
  NEXUS_VERIFY_NPM_NAME        (default: lodash)
  NEXUS_VERIFY_NPM_VERSION     (default: 4.17.21)
  NEXUS_VERIFY_PYPI_PROJECT    (default: requests)
  NEXUS_VERIFY_DOCKER_PATH     (default: docker-proxy/library/alpine)
  NEXUS_VERIFY_DOCKER_TAG      (default: 3.21)

Exit codes: 0 all checks that ran passed (or NOTHING RAN), 1 a check failed or
a hard-tier binary is missing, 2 usage error.
USAGE_EOF
}

usage_error() {
  echo "ERROR: $1" >&2
  usage >&2
  exit 2
}

# ── Arguments ────────────────────────────────────────────────────────────────
# ARGUMENT PARSING USES A SHIFT LOOP, DELIBERATELY. `for arg in "$@"` with a case
# over bare words (the shape scripts/nexus-live-smoke.sh would suggest, since it
# takes no arguments at all) cannot take an option ARGUMENT. --url, --context
# and --sync-pass all take one. Same shape as workstation/nexus-setup.sh.
NEXUS_HOST=""
KUBE_CONTEXT=""
SYNC_PASS=""
NEXUS_NS="nexus"
ARGOCD_NS="argocd"
APP_NAME="nexus"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      if [[ $# -lt 2 ]]; then usage_error "--url requires a value, e.g. --url http://127.0.0.1:8081"; fi
      NEXUS_HOST="$2"
      shift 2
      ;;
    --context)
      if [[ $# -lt 2 ]]; then usage_error "--context requires a kube-context name"; fi
      KUBE_CONTEXT="$2"
      shift 2
      ;;
    --sync-pass)
      if [[ $# -lt 2 ]]; then usage_error "--sync-pass requires a value: first or second"; fi
      SYNC_PASS="$2"
      shift 2
      ;;
    --namespace)
      if [[ $# -lt 2 ]]; then usage_error "--namespace requires a value"; fi
      NEXUS_NS="$2"
      shift 2
      ;;
    --argocd-namespace)
      if [[ $# -lt 2 ]]; then usage_error "--argocd-namespace requires a value"; fi
      ARGOCD_NS="$2"
      shift 2
      ;;
    --app-name)
      if [[ $# -lt 2 ]]; then usage_error "--app-name requires a value"; fi
      APP_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage_error "Unknown argument: $1"
      ;;
  esac
done

# Checked AFTER the loop so --help and an unknown argument are both reachable
# without a URL. A missing required argument is an error, never a default: this
# gate must refuse to run against an unstated host rather than silently probing
# 127.0.0.1, and must refuse to run against an unstated cluster rather than
# silently using whatever the current kubeconfig context happens to be.
if [[ -z "$NEXUS_HOST" ]]; then
  usage_error "--url is required and was not supplied. There is no default Nexus URL and this script will not guess one."
fi
if [[ -z "$KUBE_CONTEXT" ]]; then
  usage_error "--context is required and was not supplied. Every kubectl call is pinned to an explicit context; the current context is never assumed."
fi
# --sync-pass has no default FOR A REASON. It switches the provisioning token
# this gate expects between action=created (first sync, empty PVC) and
# action=updated (second sync, PVC carrying prior state). A silent default of
# `first` on a second-sync run would assert the wrong thing and pass vacuously —
# exactly the failure mode SECOND-SYNC-IDEMPOTENT exists to catch.
if [[ -z "$SYNC_PASS" ]]; then
  usage_error "--sync-pass is required and was not supplied (first or second). It selects which provisioning outcome is asserted, so it is never defaulted."
fi
if [[ "$SYNC_PASS" != "first" && "$SYNC_PASS" != "second" ]]; then
  usage_error "--sync-pass must be 'first' or 'second', got '${SYNC_PASS}'"
fi
# One trailing slash stripped, so "${NEXUS_HOST}/repository/..." never doubles it.
NEXUS_HOST="${NEXUS_HOST%/}"

# ── Scratch space ────────────────────────────────────────────────────────────
# Assigned BEFORE the trap so `set -u` cannot trip inside the cleanup path. The
# `|| true` here is cleanup hygiene on a best-effort teardown, not a silenced
# assertion — no verdict is derived from it. It is the ONLY `|| true` in this
# file.
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT" || true' EXIT

FAILURES=()
# SKIPPED: sub-checks that did not run (an optional tool is absent, or the
# subject of the check does not apply to this run). Reported separately from
# FAILURES and separately from passes — a skip must never read as a pass — and
# it never affects the exit status.
SKIPPED=()
# CHECKS_PASSED: live checks that actually executed and passed. Counted from the
# run itself, so the summary cannot claim a pass on a run where nothing ran.
CHECKS_PASSED=0

# require_success: run a command that is expected to exit 0.
#
# Deliberately NOT copied from smoke-scans.sh: run_scan / run_scan_rc. Their
# PASS-on-exit-1 inversion is scanner semantics — applied here it would score a
# BROKEN provisioning run as a pass, which is the exact failure mode this
# script exists to prevent.
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

# print_summary: the terminal verdict. Skips print first, under their own
# heading, on every path — they are not failures and they are not passes.
print_summary() {
  echo
  echo "=== Summary ==="
  if [ "${#SKIPPED[@]}" -gt 0 ]; then
    echo "SKIPPED - ${#SKIPPED[@]} sub-check(s) did not run. A SKIP IS NOT A PASS:"
    for s in "${SKIPPED[@]}"; do
      echo "  - ${s}"
    done
    echo
  fi
  if [ "${#FAILURES[@]}" -gt 0 ]; then
    echo "FAILED - one or more live checks did not produce the expected result:"
    for f in "${FAILURES[@]}"; do
      echo "  - ${f}"
    done
    exit 1
  elif [ "$CHECKS_PASSED" -eq 0 ]; then
    # Zero failures on a run where zero checks executed is NOT a pass. Saying
    # ALL PASS here is the vacuous-green this convention exists to forbid.
    echo "NOTHING RAN - 0 live check(s) executed; ${#SKIPPED[@]} sub-check(s) skipped (not passed). Nothing was proven."
    exit 0
  else
    echo "ALL PASS - ${CHECKS_PASSED} live check(s) executed and passed; ${#SKIPPED[@]} sub-check(s) skipped (not passed)."
    exit 0
  fi
}

# ── Preflight, hard tier ─────────────────────────────────────────────────────
# Every binary here drives a check this gate cannot render a verdict without.
# Run AFTER argument parsing so --help works on a machine without them.
for bin in curl jq; do
  if ! command -v "$bin" &>/dev/null; then
    echo "FATAL: required binary '${bin}' not found on PATH" >&2
    exit 1
  fi
done

# ── Preflight, soft tier ─────────────────────────────────────────────────────
# Without kubectl the three cluster-side checks cannot run, but the protocol
# checks against --url still can. The skip is named and accounted for, so it
# can never be mistaken for a pass.
KUBECTL_OK=1
if ! command -v kubectl &>/dev/null; then
  KUBECTL_OK=0
  SKIPPED+=("cluster-side checks (ARGOCD-HOOK-PHASE, PROVISION-JOB-COMPLETE, PROVISION-JOB-REPOS, PVC-DEFAULT-STORAGECLASS, the ANONYMOUS-WRITE-DENIED instrument and readback, the SECOND-SYNC-IDEMPOTENT log assertions): 'kubectl' not found on PATH")
fi

echo "=== nexus-homelab-validate: ${NEXUS_HOST} (context ${KUBE_CONTEXT}, namespace ${NEXUS_NS}, sync pass ${SYNC_PASS}) ==="
echo

# EVERY kubectl CALL IN THIS FILE PINS --context "$KUBE_CONTEXT" ON THE SAME LINE
# AS `kubectl`. None may rely on the current context: the operator's current
# context may be a different cluster entirely, and a gate that read the wrong
# cluster's state would pass or fail for reasons unrelated to this Nexus.
# KUBECONFIG is honoured from the environment and never set here.
#
# EVERY command that can fail is captured with `|| rc=$?` into an explicit
# verdict, never left bare. Under `set -euo pipefail` a bare failing kubectl
# (wrong context, missing resource) would kill the run before print_summary,
# which is a crash rather than a verdict.

echo "--- 1. Cluster-side: Argo CD hook phase, provisioning Job, PVC ---"

# ── ARGOCD-HOOK-PHASE ────────────────────────────────────────────────────────
# Converts "how Argo CD treats this chart's hook annotations" from training
# knowledge into an observation. Argo CD's documentation says that if a resource
# carries ANY Argo CD hook annotation, ALL Helm hook annotations are ignored
# (25-RESEARCH Pitfall 1). job-provision.yaml carries `argocd.argoproj.io/hook:
# Sync` alongside `helm.sh/hook: post-install,post-upgrade`, so the Job must
# appear here as a Sync hook. A PostSync hook would mean the Helm annotation won,
# which falsifies that reading and must be reported, not rationalised.
#
# One `pass` at the end, gated on a flag, so each wrong field gets its own
# diagnosis and exactly one pass fires when all four are right.
check_argocd_hook_phase() {
  local app_rc=0 hooks="" hook_count="" job_hook="" kind="" name="" hook_type="" hook_phase=""
  local hook_ok=1

  kubectl --context "$KUBE_CONTEXT" -n "$ARGOCD_NS" get applications.argoproj.io "$APP_NAME" -o json >"$OUT/app.json" 2>"$OUT/app.err" || app_rc=$?
  if [ "$app_rc" -ne 0 ]; then
    fail "ARGOCD-HOOK-PHASE" "kubectl exited ${app_rc} reading Application ${ARGOCD_NS}/${APP_NAME} on context ${KUBE_CONTEXT}: $(head -c 300 "$OUT/app.err")"
    return 0
  fi
  if ! hooks="$(jq -c '[.status.operationState.syncResult.resources[]? | select(.hookType != null)]' "$OUT/app.json" 2>/dev/null)"; then
    fail "ARGOCD-HOOK-PHASE" "Application ${APP_NAME} JSON could not be parsed for .status.operationState.syncResult.resources"
    return 0
  fi
  hook_count="$(printf '%s' "$hooks" | jq 'length')"
  # Emptiness guard FIRST: an empty hook list is not "nothing wrong", it is the
  # provisioning Job never having been treated as a hook at all.
  if [ "$hook_count" -eq 0 ]; then
    fail "ARGOCD-HOOK-PHASE" "the last sync operation of Application ${APP_NAME} recorded NO hook resources; the provisioning Job was not treated as a hook at all (or no sync operation has completed yet), so nothing about the provisioning phase was observed"
    return 0
  fi

  job_hook="$(printf '%s' "$hooks" | jq -c '[.[] | select(.kind == "Job")][0] // empty')"
  if [ -z "$job_hook" ]; then
    fail "ARGOCD-HOOK-PHASE" "the sync recorded ${hook_count} hook resource(s) but none of kind Job: ${hooks}"
    return 0
  fi
  kind="$(printf '%s' "$job_hook" | jq -r '.kind // ""')"
  name="$(printf '%s' "$job_hook" | jq -r '.name // ""')"
  hook_type="$(printf '%s' "$job_hook" | jq -r '.hookType // ""')"
  hook_phase="$(printf '%s' "$job_hook" | jq -r '.hookPhase // ""')"

  if [ "$kind" != "Job" ]; then
    fail "ARGOCD-HOOK-PHASE" "hook resource kind is '${kind}', expected 'Job'"
    hook_ok=0
  fi
  if [ "$name" != "nexus-provision" ]; then
    fail "ARGOCD-HOOK-PHASE" "hook Job is named '${name}', expected 'nexus-provision'; the rendered Job name has drifted from the one every other check in this gate reads"
    hook_ok=0
  fi
  if [ "$hook_type" = "PostSync" ]; then
    fail "ARGOCD-HOOK-PHASE" "hookType is PostSync, expected Sync. This FALSIFIES 25-RESEARCH Pitfall 1 (Argo CD ignores all Helm hooks on a resource carrying an Argo CD hook annotation): the helm.sh/hook annotation was honoured. Report this; do not rationalise it"
    hook_ok=0
  elif [ "$hook_type" != "Sync" ]; then
    fail "ARGOCD-HOOK-PHASE" "hookType is '${hook_type}', expected 'Sync' (the argocd.argoproj.io/hook annotation on job-provision.yaml)"
    hook_ok=0
  fi
  if [ "$hook_phase" != "Succeeded" ]; then
    fail "ARGOCD-HOOK-PHASE" "hookPhase is '${hook_phase}', expected 'Succeeded'; the provisioning Job did not complete successfully in the last sync"
    hook_ok=0
  fi

  if [ "$hook_ok" -eq 1 ]; then
    pass "ARGOCD-HOOK-PHASE" "Application ${APP_NAME}: Job nexus-provision ran as a Sync hook and its hookPhase is Succeeded"
  fi
}

# ── PROVISION-JOB-COMPLETE / PROVISION-JOB-REPOS ─────────────────────────────
# `kubectl wait` against an empty set prints "error: no matching resources
# found" and its exit code is not a reliable signal, so the Job's existence is
# proven FIRST and an empty result is an explicit failure naming its causes.
#
# The log count is the measured value. The `kubectl wait` exit code alone only
# says the Job's container exited 0 — the same signal Argo CD uses, which is
# exactly the signal this gate exists not to trust (25-RESEARCH Pitfall 11).
check_provision_job() {
  local rows_rc=0 job_rows="" logs_rc=0 token="" token_count=""

  kubectl --context "$KUBE_CONTEXT" -n "$NEXUS_NS" get job nexus-provision --no-headers >"$OUT/job.txt" 2>"$OUT/job.err" || rows_rc=$?
  # A kubectl that could not talk to the cluster at all is a different failure
  # from a Job that is not there, and gets its own diagnosis.
  if [ "$rows_rc" -ne 0 ] && ! grep -q 'NotFound' "$OUT/job.err"; then
    fail "PROVISION-JOB-COMPLETE" "kubectl exited ${rows_rc} looking up Job ${NEXUS_NS}/nexus-provision on context ${KUBE_CONTEXT}: $(head -c 300 "$OUT/job.err")"
    SKIPPED+=("PROVISION-JOB-REPOS: the Job could not be read, so there are no provisioning logs to count")
    return 0
  fi
  job_rows="$(wc -l <"$OUT/job.txt" | tr -d ' ')"
  if [ "$job_rows" -eq 0 ]; then
    fail "PROVISION-JOB-COMPLETE" "no Job nexus-provision found in namespace ${NEXUS_NS} on context ${KUBE_CONTEXT}; either the chart renders no provisioning Job, a hook-delete-policy removed the evidence, or ttlSecondsAfterFinished: 900 reaped it before this gate ran (25-RESEARCH Pitfall 2 - run the gate within 15 minutes of the sync)"
    SKIPPED+=("PROVISION-JOB-REPOS: no Job nexus-provision exists, so there are no provisioning logs to count")
    return 0
  fi

  require_success "PROVISION-JOB-COMPLETE-CONDITION" kubectl --context "$KUBE_CONTEXT" -n "$NEXUS_NS" wait --for=condition=complete job/nexus-provision --timeout=900s

  kubectl --context "$KUBE_CONTEXT" -n "$NEXUS_NS" logs job/nexus-provision >"$OUT/provision.log" 2>"$OUT/provision.err" || logs_rc=$?
  if [ "$logs_rc" -ne 0 ]; then
    fail "PROVISION-JOB-REPOS" "kubectl logs job/nexus-provision exited ${logs_rc}: $(head -c 300 "$OUT/provision.err")"
    # An unreadable log must not be mistaken for an empty one downstream.
    rm -f "$OUT/provision.log"
    return 0
  fi

  if [ "$SYNC_PASS" = "first" ]; then
    token="action=created"
  else
    token="action=updated"
  fi
  # grep -c exits 1 on zero matches while still printing 0; the fallback keeps
  # that from killing the run. It is a count default, not a silenced assertion.
  token_count="$(grep -c -- "$token" "$OUT/provision.log")" || token_count=0
  if [ "$token_count" -eq 4 ]; then
    pass "PROVISION-JOB-REPOS" "provisioning log records ${token} exactly 4 times (npm, pypi, docker, helm) on the ${SYNC_PASS} sync"
  else
    fail "PROVISION-JOB-REPOS" "provisioning log records ${token} ${token_count} time(s), expected exactly 4 (npm, pypi, docker, helm) on the ${SYNC_PASS} sync; 3 usually means repos.helm.remoteUrl is unset so helm-proxy was never provisioned, and the other token (created vs updated) means --sync-pass does not match the PVC's actual state"
  fi
}

# ── PVC-DEFAULT-STORAGECLASS ─────────────────────────────────────────────────
# NEXUS-03's live proof: the chart ships no storageClassName, so the PVC must
# land on whatever the cluster's default StorageClass is. The default's NAME is
# MEASURED here, never hardcoded — a hardcoded name would keep passing on a
# cluster whose default had changed.
#
# The homelab's default StorageClass is WaitForFirstConsumer, so a PVC that is
# still Pending before the StatefulSet pod is scheduled is not a defect. It is
# only a defect at the point this check runs, which is after the Application is
# Healthy — by then the pod has been scheduled and the claim must be Bound.
check_pvc_default_storageclass() {
  local sc_rc=0 default_sc="" default_count="" pvc_rc=0 pvc_count="" pvc_ok=1
  local pvc_name="" pvc_phase="" pvc_sc="" i=0

  kubectl --context "$KUBE_CONTEXT" get storageclass -o json >"$OUT/sc.json" 2>"$OUT/sc.err" || sc_rc=$?
  if [ "$sc_rc" -ne 0 ]; then
    fail "PVC-DEFAULT-STORAGECLASS" "kubectl exited ${sc_rc} listing StorageClasses on context ${KUBE_CONTEXT}: $(head -c 300 "$OUT/sc.err")"
    return 0
  fi
  default_sc="$(jq -r '.items[] | select(.metadata.annotations["storageclass.kubernetes.io/is-default-class"] == "true") | .metadata.name' "$OUT/sc.json")"
  if [ -z "$default_sc" ]; then
    default_count=0
  else
    default_count="$(printf '%s\n' "$default_sc" | wc -l | tr -d ' ')"
  fi
  if [ "$default_count" -ne 1 ]; then
    fail "PVC-DEFAULT-STORAGECLASS" "the cluster has ${default_count} default StorageClass(es) (${default_sc//$'\n'/, }), expected exactly 1; with zero a chart that sets no storageClassName leaves its PVC unbound forever, and with more than one the choice is undefined"
    return 0
  fi

  kubectl --context "$KUBE_CONTEXT" -n "$NEXUS_NS" get pvc -o json >"$OUT/pvc.json" 2>"$OUT/pvc.err" || pvc_rc=$?
  if [ "$pvc_rc" -ne 0 ]; then
    fail "PVC-DEFAULT-STORAGECLASS" "kubectl exited ${pvc_rc} listing PVCs in namespace ${NEXUS_NS}: $(head -c 300 "$OUT/pvc.err")"
    return 0
  fi
  pvc_count="$(jq '.items | length' "$OUT/pvc.json")"
  if [ "$pvc_count" -eq 0 ]; then
    fail "PVC-DEFAULT-STORAGECLASS" "no PersistentVolumeClaim exists in namespace ${NEXUS_NS}; Nexus is running without persistent storage, or its StatefulSet never created its volumeClaimTemplate"
    return 0
  fi

  while [ "$i" -lt "$pvc_count" ]; do
    pvc_name="$(jq -r ".items[${i}].metadata.name" "$OUT/pvc.json")"
    pvc_phase="$(jq -r ".items[${i}].status.phase // \"\"" "$OUT/pvc.json")"
    pvc_sc="$(jq -r ".items[${i}].spec.storageClassName // \"\"" "$OUT/pvc.json")"
    if [ "$pvc_phase" != "Bound" ]; then
      fail "PVC-DEFAULT-STORAGECLASS" "PVC ${pvc_name} is '${pvc_phase}', expected Bound; WaitForFirstConsumer only excuses Pending BEFORE the pod is scheduled, and this gate runs after the Application is Healthy"
      pvc_ok=0
    fi
    if [ "$pvc_sc" != "$default_sc" ]; then
      fail "PVC-DEFAULT-STORAGECLASS" "PVC ${pvc_name} uses StorageClass '${pvc_sc}', expected the measured cluster default '${default_sc}'"
      pvc_ok=0
    fi
    i=$((i + 1))
  done

  if [ "$pvc_ok" -eq 1 ]; then
    pass "PVC-DEFAULT-STORAGECLASS" "${pvc_count} PVC(s) in ${NEXUS_NS} are Bound on the measured cluster default StorageClass '${default_sc}'"
  fi
}

if [ "$KUBECTL_OK" -eq 1 ]; then
  check_argocd_hook_phase
  check_provision_job
  check_pvc_default_storageclass
else
  echo "    SKIPPED - kubectl absent"
fi
echo

# ── Admin credential ─────────────────────────────────────────────────────────
# Read from the cluster Secret, never from argv. Never echoed, and `set -x` is
# never enabled anywhere in this file. gitleaks runs as a pre-push hook over the
# whole repository; a literal password in this public repo would be a real
# finding. ADMIN_PW_OK stays 0 unless the read produced a non-empty value, and
# every consumer below checks it rather than assuming.
NEXUS_PW=""
ADMIN_PW_OK=0
ADMIN_PW_ERR=""
if [ "$KUBECTL_OK" -eq 1 ]; then
  pw_rc=0
  NEXUS_PW="$(kubectl --context "$KUBE_CONTEXT" -n "$NEXUS_NS" get secret nexus-admin -o jsonpath='{.data.password}' 2>"$OUT/pw.err" | base64 -d 2>/dev/null)" || pw_rc=$?
  if [ "$pw_rc" -eq 0 ] && [ -n "$NEXUS_PW" ]; then
    ADMIN_PW_OK=1
  else
    NEXUS_PW=""
    ADMIN_PW_ERR="could not read a non-empty .data.password from Secret ${NEXUS_NS}/nexus-admin on context ${KUBE_CONTEXT} (rc=${pw_rc}): $(head -c 300 "$OUT/pw.err")"
  fi
fi

echo "--- 2. Anonymous pull: npm, PyPI, Helm ---"
# The four client URLs, lifted from scripts/nexus-live-smoke.sh with NEXUS_HOST
# now coming from --url instead of a container this script owns.
#
# No `-u` and no `-K -`: sending no credential is the point of every check in
# this section.
#
# Upstream package names are env-overridable (the workstation/nexus-setup.sh
# convention): a package can be yanked upstream, and a gate that then reported a
# proxy failure would be lying about the cause.
ANON_NPM_NAME="${NEXUS_VERIFY_NPM_NAME:-lodash}"
ANON_NPM_VERSION="${NEXUS_VERIFY_NPM_VERSION:-4.17.21}"
TARBALL_URL="${NEXUS_HOST}/repository/npm-proxy/${ANON_NPM_NAME}/-/${ANON_NPM_NAME}-${ANON_NPM_VERSION}.tgz"
# PyPI — the PER-PROJECT simple page, which is what `pip download` actually
# requests; the root /simple/ index is a different (and enormous) document. The
# trailing slash is load-bearing: without it Nexus answers a redirect whose body
# is a few hundred bytes, which would be measured instead of the page.
ANON_PYPI_PROJECT="${NEXUS_VERIFY_PYPI_PROJECT:-requests}"
ANON_PYPI_URL="${NEXUS_HOST}/repository/pypi-proxy/simple/${ANON_PYPI_PROJECT}/"
ANON_HELM_URL="${NEXUS_HOST}/repository/helm-proxy/index.yaml"

# THREE verdicts per ecosystem, not one: a curl transport error is a DIFFERENT
# failure from an HTTP verdict, and a status is not a size. A Nexus whose EULA is
# unaccepted answers a component download with a well-formed HTTP 403 carrying a
# ~192-byte body, and a closed anonymous posture answers 401 with a zero-byte
# body; both sail straight past a bare status check, and a single if/elif chain
# would stop at the status and never reach the size at all.
#
# SIZE THRESHOLDS — unchanged from nexus-live-smoke.sh, and the rule that
# produced them. Each floor is:
#   (1) at least ten times the ~192-byte EULA refusal body, so it genuinely
#       discriminates a refusal (and a zero-byte 401) from real content; and
#   (2) no more than HALF the size measured in Phase 24 / ADR-021 — npm tarball
#       318,961 B, PyPI simple page 76,776 B, Helm index.yaml 291,818 B — so
#       ordinary upstream drift cannot turn this gate red on its own.
# Do not "tighten" any of them to the measured value: that converts a gate that
# discriminates content from refusals into an upstream-content tripwire.
ANON_NPM_MIN_BYTES=100000
ANON_PYPI_MIN_BYTES=20000
ANON_HELM_MIN_BYTES=100000

# npm
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

# PyPI. MEASURED BOUNDARY (Phase 24): this simple page is METADATA and is NOT
# behind the EULA gate — with eula.accepted=false it still returns HTTP 200 and
# its full size. So this floor discriminates the zero-byte 401 challenge, not a
# licence refusal, and a 200 here is no evidence the EULA was accepted.
anon_pypi_code=""
anon_pypi_rc=0
anon_pypi_code="$(curl -sS -o "$OUT/anon-pypi.html" -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 "$ANON_PYPI_URL")" || anon_pypi_rc=$?

if [ "$anon_pypi_rc" -ne 0 ]; then
  fail "ANONYMOUS-PULL-PYPI-TRANSPORT" "curl exited ${anon_pypi_rc} on the unauthenticated fetch of ${ANON_PYPI_URL} (transport error, not an HTTP verdict)"
else
  pass "ANONYMOUS-PULL-PYPI-TRANSPORT" "unauthenticated curl completed against ${ANON_PYPI_URL}"
fi

if [ "$anon_pypi_code" = "200" ]; then
  pass "ANONYMOUS-PULL-PYPI-HTTP-200" "unauthenticated GET of the ${ANON_PYPI_PROJECT} simple page returned HTTP 200"
else
  fail "ANONYMOUS-PULL-PYPI-HTTP-200" "unauthenticated GET of ${ANON_PYPI_URL} returned HTTP ${anon_pypi_code}, expected 200; 401 means anonymous read was never opened, 403 means the EULA was never accepted"
fi

if [ -f "$OUT/anon-pypi.html" ]; then
  anon_pypi_bytes="$(wc -c <"$OUT/anon-pypi.html" | tr -d ' ')"
else
  anon_pypi_bytes=0
fi
if [ "$anon_pypi_bytes" -gt "$ANON_PYPI_MIN_BYTES" ]; then
  pass "ANONYMOUS-PULL-PYPI-SIZE" "${anon_pypi_bytes} bytes of simple index pulled with no credential (> ${ANON_PYPI_MIN_BYTES})"
else
  fail "ANONYMOUS-PULL-PYPI-SIZE" "only ${anon_pypi_bytes} bytes pulled with no credential, expected > ${ANON_PYPI_MIN_BYTES}; 0 bytes is the 401 challenge, and a few hundred bytes is a redirect body from a URL missing its trailing slash - neither is a simple index"
fi

# Helm. Unlike the PyPI page, index.yaml IS behind the EULA gate (measured), so
# this floor really does discriminate a refusal from content. helm-proxy exists
# only when repos.helm.remoteUrl is set — the chart ships it null on purpose.
anon_helm_code=""
anon_helm_rc=0
anon_helm_code="$(curl -sS -o "$OUT/anon-helm-index.yaml" -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 "$ANON_HELM_URL")" || anon_helm_rc=$?

if [ "$anon_helm_rc" -ne 0 ]; then
  fail "ANONYMOUS-PULL-HELM-TRANSPORT" "curl exited ${anon_helm_rc} on the unauthenticated fetch of ${ANON_HELM_URL} (transport error, not an HTTP verdict)"
else
  pass "ANONYMOUS-PULL-HELM-TRANSPORT" "unauthenticated curl completed against ${ANON_HELM_URL}"
fi

if [ "$anon_helm_code" = "200" ]; then
  pass "ANONYMOUS-PULL-HELM-HTTP-200" "unauthenticated GET of ${ANON_HELM_URL} returned HTTP 200"
else
  fail "ANONYMOUS-PULL-HELM-HTTP-200" "unauthenticated GET of ${ANON_HELM_URL} returned HTTP ${anon_helm_code}, expected 200; 401 means anonymous read was never opened, 403 means the EULA was never accepted, 404 means the helm-proxy repository was never created"
fi

if [ -f "$OUT/anon-helm-index.yaml" ]; then
  anon_helm_bytes="$(wc -c <"$OUT/anon-helm-index.yaml" | tr -d ' ')"
else
  anon_helm_bytes=0
fi
if [ "$anon_helm_bytes" -gt "$ANON_HELM_MIN_BYTES" ]; then
  pass "ANONYMOUS-PULL-HELM-SIZE" "${anon_helm_bytes} bytes of chart index pulled with no credential (> ${ANON_HELM_MIN_BYTES})"
else
  fail "ANONYMOUS-PULL-HELM-SIZE" "only ${anon_helm_bytes} bytes pulled with no credential, expected > ${ANON_HELM_MIN_BYTES}; ~192 bytes is the EULA refusal body and 0 bytes is the 401 challenge, neither of which is a chart index. On the homelab, an HTTP 404 means repos.helm.remoteUrl was never set in the overlay, so the helm-proxy repository was never created (25-RESEARCH Pitfall 7)"
fi
echo

echo "--- 3. Docker: realms, URL shape ---"
# Docker is the only ecosystem whose anonymous read cannot be proven by a single
# unauthenticated GET: a registry is a multi-request protocol, and the request
# that carries the authorisation decision is not the first one. A header-less
# manifest GET returns 200 even with the DockerToken realm removed (ADR-021
# decision 5), so no single GET in this section is evidence of anonymous pull on
# its own — ANONYMOUS-PULL-DOCKER is.

# ── DOCKER-REALM-ACTIVE ──────────────────────────────────────────────────────
# Under Argo CD this is a STANDING PRODUCTION INVARIANT, not a one-off test: the
# provisioning Job is a Sync hook, Sync hooks re-run on EVERY sync, and
# `ApplyOutOfSyncOnly=true` does not suppress them. So the realms PUT runs again
# on every sync of this Application, and both traps below only appear on a
# repeat run.
#
# Three assertions, three separate failure messages, because the two ways
# `PUT /security/realms/active` goes wrong are opposites:
#   1. DockerToken absent      -> bearer tokens will not validate and anonymous
#      docker pull is dead.
#   2. DockerToken more than once -> the endpoint stores duplicates (measured),
#      so an unguarded append grows the list on every sync.
#   3. NexusAuthenticatingRealm absent -> the endpoint REPLACES the whole list,
#      so a body that omits it locks every user out, admin included.
#
# The read is attempted UNAUTHENTICATED first. The realms list is a security
# setting, and the anonymous identity may legitimately be refused it (401/403)
# — that says nothing about the list itself. So on 401/403, and only then, the
# same GET is repeated as admin with the credential read from the cluster, and
# the pass message records which identity performed the read.
REALMS_URL="${NEXUS_HOST}/service/rest/v1/security/realms/active"

# read_realms <outfile>: sets REALMS_RC, REALMS_CODE and REALMS_IDENTITY.
REALMS_RC=0
REALMS_CODE=""
REALMS_IDENTITY=""
read_realms() {
  local outfile="$1"
  REALMS_RC=0
  REALMS_CODE=""
  REALMS_IDENTITY="anonymous"
  REALMS_CODE="$(curl -sS -o "$outfile" -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 "$REALMS_URL")" || REALMS_RC=$?
  if [ "$REALMS_RC" -eq 0 ] && { [ "$REALMS_CODE" = "401" ] || [ "$REALMS_CODE" = "403" ]; } && [ "$ADMIN_PW_OK" -eq 1 ]; then
    REALMS_IDENTITY="admin (anonymous read returned HTTP ${REALMS_CODE})"
    REALMS_RC=0
    REALMS_CODE="$(curl -sS -o "$outfile" -w '%{http_code}' \
      --connect-timeout 5 --max-time 30 \
      -u "admin:$NEXUS_PW" "$REALMS_URL")" || REALMS_RC=$?
  fi
}

read_realms "$OUT/realms-active.json"
realms_ok=1
if [ "$REALMS_RC" -ne 0 ]; then
  fail "DOCKER-REALM-ACTIVE" "curl exited ${REALMS_RC} reading ${REALMS_URL} as ${REALMS_IDENTITY} (transport error, not an HTTP verdict)"
  realms_ok=0
elif [ "$REALMS_CODE" != "200" ]; then
  fail "DOCKER-REALM-ACTIVE" "GET ${REALMS_URL} as ${REALMS_IDENTITY} returned HTTP ${REALMS_CODE}, expected 200; the realms list was never read, so the three assertions measured nothing (a 401/403 with no admin credential available means the Secret nexus-admin could not be read)"
  realms_ok=0
elif ! jq -e 'type == "array"' "$OUT/realms-active.json" >/dev/null 2>&1; then
  fail "DOCKER-REALM-ACTIVE" "GET ${REALMS_URL} returned HTTP 200 but a body that is not a JSON array"
  realms_ok=0
else
  realms_list="$(jq -c . "$OUT/realms-active.json")"
  docker_realm_count="$(jq '[.[] | select(. == "DockerToken")] | length' "$OUT/realms-active.json")"
  auth_realm_count="$(jq '[.[] | select(. == "NexusAuthenticatingRealm")] | length' "$OUT/realms-active.json")"

  if [ "$docker_realm_count" -eq 0 ]; then
    fail "DOCKER-REALM-ACTIVE" "DockerToken is ABSENT from the active realms ${realms_list}; provision.sh did not append it, so no bearer token this instance issues will validate and anonymous docker pull cannot work"
    realms_ok=0
  elif [ "$docker_realm_count" -ne 1 ]; then
    fail "DOCKER-REALM-ACTIVE" "DockerToken appears ${docker_realm_count} times in ${realms_list}, expected exactly once; the API stores duplicates (measured), so an append with no index() guard grows this list on every sync"
    realms_ok=0
  fi

  if [ "$auth_realm_count" -eq 0 ]; then
    fail "DOCKER-REALM-ACTIVE" "NexusAuthenticatingRealm is GONE from the active realms ${realms_list}; PUT /security/realms/active replaces the whole list, and a PUT that drops this realm locks every user out of the instance, admin included"
    realms_ok=0
  fi

  if [ "$realms_ok" -eq 1 ]; then
    pass "DOCKER-REALM-ACTIVE" "active realms are ${realms_list} (read as ${REALMS_IDENTITY}) - DockerToken exactly once, NexusAuthenticatingRealm intact"
  fi
fi

# The image this gate pulls through the proxy, env-overridable for the same
# upstream-yank reason as the packages above, and the two Accept header sets a
# registry client sends. Without them the registry can legitimately refuse on
# content negotiation, which would look like an authorisation failure.
DOCKER_IMAGE_PATH="${NEXUS_VERIFY_DOCKER_PATH:-docker-proxy/library/alpine}"
DOCKER_IMAGE_TAG="${NEXUS_VERIFY_DOCKER_TAG:-3.21}"
DOCKER_INDEX_ACCEPT='application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json'
DOCKER_MANIFEST_ACCEPT='application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
DOCKER_MANIFEST_URL="${NEXUS_HOST}/v2/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG}"
DOCKER_MANIFEST_URL_WRONG="${NEXUS_HOST}/v2/repository/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG}"

# ── DOCKER-PATH-SHAPE ────────────────────────────────────────────────────────
# Two unauthenticated requests, one check, both directions asserted. Docker is
# the ONLY one of the four ecosystems whose URL carries no `/repository/`
# segment: the client inserts `/v2/` immediately after the host, so with
# `pathEnabled: true` the repository name must be the FIRST path segment.
#
#   docker pull HOST/docker-proxy/library/alpine:3.21
#        -> GET /v2/docker-proxy/library/alpine/manifests/3.21             200
#   docker pull HOST/repository/docker-proxy/library/alpine:3.21
#        -> GET /v2/repository/docker-proxy/library/alpine/manifests/3.21  404
#
# The second assertion is why this check exists rather than being folded into
# the handshake below. `HOST/repository/<repo>/...` is CORRECT for npm, PyPI and
# Helm — all three of section 2's URLs use it — so the Docker line gets written
# the same way by analogy, in a README or in the workstation script, and every
# pull 404s at the first request. A gate that only measured the working shape
# would never catch that; this one asserts the wrong shape stays broken, which is
# what catches a documentation copy-paste.
#
# Both requests are deliberately header-less and credential-free. They measure
# ROUTING, which the DockerToken realm does not affect — the control for the
# handshake check below.
path_ok=1
path_right_rc=0
path_right_code=""
path_right_code="$(curl -sS -o /dev/null -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 \
  -H "Accept: ${DOCKER_INDEX_ACCEPT}" \
  "$DOCKER_MANIFEST_URL")" || path_right_rc=$?

if [ "$path_right_rc" -ne 0 ]; then
  fail "DOCKER-PATH-SHAPE" "curl exited ${path_right_rc} on ${DOCKER_MANIFEST_URL} (transport error, not an HTTP verdict)"
  path_ok=0
elif [ "$path_right_code" != "200" ]; then
  # Stricter than "not 404", deliberately: a header-less GET of this path was
  # measured at 200 (Phase 24), and a 5xx or a 401 here is not "routes".
  fail "DOCKER-PATH-SHAPE" "${DOCKER_MANIFEST_URL} returned HTTP ${path_right_code}, expected 200; this is the path a real 'docker pull HOST/${DOCKER_IMAGE_PATH}:${DOCKER_IMAGE_TAG}' constructs, so a 404 means the documented pull reference does not route (a 401 means anonymous read is closed)"
  path_ok=0
fi

path_wrong_rc=0
path_wrong_code=""
path_wrong_code="$(curl -sS -o /dev/null -w '%{http_code}' \
  --connect-timeout 5 --max-time 60 \
  -H "Accept: ${DOCKER_INDEX_ACCEPT}" \
  "$DOCKER_MANIFEST_URL_WRONG")" || path_wrong_rc=$?

if [ "$path_wrong_rc" -ne 0 ]; then
  fail "DOCKER-PATH-SHAPE" "curl exited ${path_wrong_rc} on ${DOCKER_MANIFEST_URL_WRONG} (transport error, not an HTTP verdict)"
  path_ok=0
elif [ "$path_wrong_code" != "404" ]; then
  fail "DOCKER-PATH-SHAPE" "${DOCKER_MANIFEST_URL_WRONG} returned HTTP ${path_wrong_code}, expected 404; the '/repository/' prefix is correct for npm, PyPI and Helm and WRONG for Docker only, and this assertion exists so a documentation copy-paste that adds it by analogy is caught here instead of at pull time"
  path_ok=0
fi

if [ "$path_ok" -eq 1 ]; then
  pass "DOCKER-PATH-SHAPE" "/v2/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG} is 200 and /v2/repository/${DOCKER_IMAGE_PATH}/manifests/${DOCKER_IMAGE_TAG} is 404 - the documented Docker reference is the one that routes"
fi
echo

echo "--- 4. Docker anonymous handshake, write boundary ---"

# ── ANONYMOUS-PULL-DOCKER ────────────────────────────────────────────────────
# The request sequence a real Docker client performs, with no credential on any
# leg. A FUNCTION because the legs are ORDERED and each consumes what the
# previous one produced: a failed leg returns immediately rather than reporting
# four derived failures with one cause. One `pass` at the end; a distinct `fail`
# message per assertion it can reach.
#
# Leg 5's byte floor, unchanged from nexus-live-smoke.sh: 1,000,000, under the
# same two rules as section 2's floors against the 3,626,020-byte alpine 3.21
# linux/amd64 layer blob measured in Phase 24 (ADR-021).
DOCKER_BLOB_MIN_BYTES=1000000
check_anonymous_pull_docker() {
  local ping_rc=0 ping_code="" challenge="" realm="" service=""
  local token_rc=0 token_code="" token=""
  local man_rc=0 man_code="" child="" layer=""
  local child_rc=0 child_code=""
  local blob_rc=0 blob_out="" blob_code="" blob_bytes=""

  # Leg 1 — the ping. Every client starts here and expects to be challenged. A
  # 200 is a FAILURE, not a success: no challenge was issued, so legs 2-5 would
  # have nothing to follow and would measure nothing.
  ping_code="$(curl -sS -o /dev/null -D "$OUT/docker-v2-ping.h" -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 "${NEXUS_HOST}/v2/")" || ping_rc=$?
  if [ "$ping_rc" -ne 0 ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 1 (GET /v2/): curl exited ${ping_rc} (transport error, not an HTTP verdict)"
    return 0
  fi
  if [ "$ping_code" != "401" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 1 (GET /v2/) returned HTTP ${ping_code}, expected 401; a 200 here is a failure rather than a shortcut, because it means the registry never issued a Bearer challenge and the remaining four legs would measure nothing"
    return 0
  fi
  if ! challenge="$(tr -d '\r' <"$OUT/docker-v2-ping.h" | grep -i '^www-authenticate: *bearer')"; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 1 (GET /v2/) returned 401 but carried no 'WWW-Authenticate: Bearer' header; a Basic-only challenge means no token endpoint is advertised and a Docker client cannot proceed"
    return 0
  fi

  # Leg 2 — parse the challenge. PARSED, never hardcoded: a hardcoded
  # realm/service pair would keep passing against a server whose challenge had
  # changed. Both must be non-empty. (A header-less manifest GET returns 200
  # even with the DockerToken realm removed — ADR-021 decision 5 — which is why
  # the handshake, not a bare GET, is the evidence.)
  realm="$(printf '%s' "$challenge" | sed -n 's/.*[Rr]ealm="\([^"]*\)".*/\1/p')"
  service="$(printf '%s' "$challenge" | sed -n 's/.*[Ss]ervice="\([^"]*\)".*/\1/p')"
  if [ -z "$realm" ] || [ -z "$service" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 2: could not parse both realm and service out of the challenge [${challenge}]; got realm='${realm}' service='${service}'"
    return 0
  fi

  # Leg 3 — the token, with NO credential supplied. --data-urlencode because
  # the service is itself a URL and the scope contains ':' and '/'.
  token_code="$(curl -sS -o "$OUT/docker-token.json" -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 \
    -G --data-urlencode "service=${service}" \
       --data-urlencode "scope=repository:${DOCKER_IMAGE_PATH}:pull" \
    "$realm")" || token_rc=$?
  if [ "$token_rc" -ne 0 ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 3 (token from ${realm}): curl exited ${token_rc} (transport error, not an HTTP verdict)"
    return 0
  fi
  if [ "$token_code" != "200" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 3: the advertised token endpoint ${realm} returned HTTP ${token_code}, expected 200; an unauthenticated client cannot obtain a token, so legs 4 and 5 have nothing to present"
    return 0
  fi
  if ! jq -e 'type == "object"' "$OUT/docker-token.json" >/dev/null 2>&1; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 3: the token endpoint returned HTTP 200 with a body that is not a JSON object"
    return 0
  fi
  token="$(jq -r '.token // empty' "$OUT/docker-token.json")"
  if [ -z "$token" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 3: the token endpoint returned HTTP 200 but no non-empty .token field"
    return 0
  fi

  # Leg 4 — the manifest index, WITH the bearer token. This is the evidence. A
  # 401 here while legs 1-3 stayed green isolates the DockerToken realm: the
  # challenge and the token are unaffected by it, and only the PRESENTED token
  # fails to validate.
  man_code="$(curl -sS -o "$OUT/docker-index.json" -w '%{http_code}' \
    --connect-timeout 5 --max-time 60 \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: ${DOCKER_INDEX_ACCEPT}" \
    "$DOCKER_MANIFEST_URL")" || man_rc=$?
  if [ "$man_rc" -ne 0 ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 4 (bearer manifest GET of ${DOCKER_MANIFEST_URL}): curl exited ${man_rc} (transport error, not an HTTP verdict)"
    return 0
  fi
  if [ "$man_code" != "200" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 4: ${DOCKER_MANIFEST_URL} with 'Authorization: Bearer' returned HTTP ${man_code}, expected 200; a 401 here with legs 1-3 green means the DockerToken realm is not active, since the challenge and the token are unaffected by it and only the presented token fails to validate"
    return 0
  fi
  if ! jq -e 'has("manifests") or has("layers")' "$OUT/docker-index.json" >/dev/null 2>&1; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 4: ${DOCKER_MANIFEST_URL} returned HTTP 200 but a body that does not parse as JSON carrying 'manifests' or 'layers'; a well-formed non-manifest body at 200 is what a content-negotiation refusal or an error document looks like"
    return 0
  fi

  # Leg 5 — resolve the linux/amd64 child manifest (selected by platform, not
  # position, which also skips attestation entries) and fetch its first layer
  # blob, so the blob path is exercised and not merely the manifest.
  if jq -e 'has("manifests")' "$OUT/docker-index.json" >/dev/null 2>&1; then
    child="$(jq -r '[.manifests[]? | select(.platform.os == "linux" and .platform.architecture == "amd64")][0].digest // empty' "$OUT/docker-index.json")"
    if [ -z "$child" ]; then
      fail "ANONYMOUS-PULL-DOCKER" "leg 5: the image index carries no linux/amd64 manifest entry, so no layer digest can be resolved from it"
      return 0
    fi
    child_code="$(curl -sS -o "$OUT/docker-manifest.json" -w '%{http_code}' \
      --connect-timeout 5 --max-time 60 \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: ${DOCKER_MANIFEST_ACCEPT}" \
      "${NEXUS_HOST}/v2/${DOCKER_IMAGE_PATH}/manifests/${child}")" || child_rc=$?
    if [ "$child_rc" -ne 0 ]; then
      fail "ANONYMOUS-PULL-DOCKER" "leg 5 (bearer manifest GET of ${child}): curl exited ${child_rc} (transport error, not an HTTP verdict)"
      return 0
    fi
    if [ "$child_code" != "200" ]; then
      fail "ANONYMOUS-PULL-DOCKER" "leg 5: the linux/amd64 child manifest ${child} returned HTTP ${child_code} with 'Authorization: Bearer', expected 200"
      return 0
    fi
    layer="$(jq -r '.layers[0].digest // empty' "$OUT/docker-manifest.json" 2>/dev/null)" || layer=""
  else
    layer="$(jq -r '.layers[0].digest // empty' "$OUT/docker-index.json")"
  fi
  if [ -z "$layer" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 5: no layer digest could be read from the manifest, so no blob reference exists to follow"
    return 0
  fi

  blob_out="$(curl -sS -o /dev/null -w '%{http_code} %{size_download}' \
    --connect-timeout 5 --max-time 180 -L \
    -H "Authorization: Bearer ${token}" \
    "${NEXUS_HOST}/v2/${DOCKER_IMAGE_PATH}/blobs/${layer}")" || blob_rc=$?
  if [ "$blob_rc" -ne 0 ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 5 (bearer blob GET of ${layer}): curl exited ${blob_rc} (transport error, not an HTTP verdict)"
    return 0
  fi
  blob_code="${blob_out%% *}"
  blob_bytes="${blob_out##* }"
  if [ "$blob_code" != "200" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 5: the layer blob ${layer} returned HTTP ${blob_code} with 'Authorization: Bearer', expected 200; the manifest is reachable but the blob path is not, so no client could complete a pull"
    return 0
  fi
  if [ "$blob_bytes" -le "$DOCKER_BLOB_MIN_BYTES" ]; then
    fail "ANONYMOUS-PULL-DOCKER" "leg 5: only ${blob_bytes} bytes of layer blob streamed, expected > ${DOCKER_BLOB_MIN_BYTES}; a few hundred bytes is an error document or a challenge page, not an image layer"
    return 0
  fi

  pass "ANONYMOUS-PULL-DOCKER" "full anonymous client handshake: GET /v2/ -> 401 + Bearer challenge; token minted at ${realm} with no credential; ${DOCKER_MANIFEST_URL} -> 200 WITH Authorization: Bearer; linux/amd64 layer ${layer} streamed ${blob_bytes} bytes (> ${DOCKER_BLOB_MIN_BYTES})"
}
check_anonymous_pull_docker

# ── ANONYMOUS-WRITE-DENIED ───────────────────────────────────────────────────
# The boundary anonymous READ must not cross. Three parts, all required:
#
#   1. The POST. THE BODY MUST BE STRUCTURALLY VALID (24-RESEARCH Pitfall 5).
#      Nexus validates the request body BEFORE it authorises: measured,
#      `{"name":"evil"}` returns 400 and a fully valid npm proxy body returns
#      403. A check that accepted "not 2xx", or 400, would pass on a malformed
#      body for a reason unrelated to authorisation — and would keep passing on
#      the day anonymous write was genuinely open. So: a valid body, and
#      EXACTLY 403.
#   2. The instrument. An admin GET of a name that was never created returns
#      404 — but so does a GET at a URL shape that does not exist. So the same
#      URL shape is first exercised against a repository that DOES exist (the
#      chart's npm proxy, whose NAME is read from the cluster's nexus-repos
#      ConfigMap, never hardcoded) and must return 200.
#   3. The readback. An admin GET of anon-write-probe must return 404: the POST
#      was refused AND created nothing.
#
# Parts 2 and 3 need the admin credential, which comes only from the cluster.
# Without it they are SKIPPED by name and the check emits no pass: a 403 on its
# own, with the instrument unproven, is not the whole claim.
ANON_WRITE_REPO="anon-write-probe"
ANON_WRITE_POST_URL="${NEXUS_HOST}/service/rest/v1/repositories/npm/proxy"
ANON_WRITE_GET_BASE="${NEXUS_HOST}/service/rest/v1/repositories"
jq -n --arg name "$ANON_WRITE_REPO" '{
  name: $name,
  online: true,
  storage: {blobStoreName: "default", strictContentTypeValidation: true},
  proxy: {remoteUrl: "https://registry.npmjs.org", contentMaxAge: 1440, metadataMaxAge: 1440},
  negativeCache: {enabled: true, timeToLive: 1440},
  httpClient: {blocked: false, autoBlock: true}
}' >"$OUT/anon-write-body.json"

check_anonymous_write_denied() {
  local write_ok=1 anon_write_rc=0 anon_write_code=""
  local cm_rc=0 npm_repo_name="" npm_get_rc=0 npm_get_code="" probe_get_rc=0 probe_get_code=""

  anon_write_code="$(curl -sS -o "$OUT/anon-write-response.txt" -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 \
    -X POST -H 'Content-Type: application/json' \
    --data-binary "@$OUT/anon-write-body.json" \
    "$ANON_WRITE_POST_URL")" || anon_write_rc=$?

  if [ "$anon_write_rc" -ne 0 ]; then
    fail "ANONYMOUS-WRITE-DENIED" "curl exited ${anon_write_rc} POSTing to ${ANON_WRITE_POST_URL} (transport error, not an HTTP verdict)"
    write_ok=0
  elif [ "$anon_write_code" = "200" ] || [ "$anon_write_code" = "201" ] || [ "$anon_write_code" = "204" ]; then
    fail "ANONYMOUS-WRITE-DENIED" "PRIVILEGE ESCALATION REGRESSION: an unauthenticated POST to ${ANON_WRITE_POST_URL} returned HTTP ${anon_write_code} and CREATED a repository. Anonymous read has become anonymous write; remove repository '${ANON_WRITE_REPO}' from this instance and treat this as a security defect, not a flaky check"
    write_ok=0
  elif [ "$anon_write_code" != "403" ]; then
    fail "ANONYMOUS-WRITE-DENIED" "unauthenticated POST to ${ANON_WRITE_POST_URL} returned HTTP ${anon_write_code}, expected exactly 403; 400 means the body was rejected as malformed BEFORE authorisation was ever consulted, which proves nothing about the write boundary, and 401 means the anonymous identity was not even resolved"
    write_ok=0
  fi

  if [ "$KUBECTL_OK" -ne 1 ]; then
    SKIPPED+=("ANONYMOUS-WRITE-DENIED instrument + readback: kubectl absent, so the admin credential and the npm repository name could not be read; the POST verdict above stands alone and is NOT a pass of this check")
    return 0
  fi
  if [ "$ADMIN_PW_OK" -ne 1 ]; then
    fail "ANONYMOUS-WRITE-DENIED" "instrument check could not run: ${ADMIN_PW_ERR}"
    return 0
  fi

  kubectl --context "$KUBE_CONTEXT" -n "$NEXUS_NS" get configmap nexus-repos -o json >"$OUT/nexus-repos.json" 2>"$OUT/nexus-repos.err" || cm_rc=$?
  if [ "$cm_rc" -ne 0 ]; then
    fail "ANONYMOUS-WRITE-DENIED" "kubectl exited ${cm_rc} reading ConfigMap ${NEXUS_NS}/nexus-repos, so the existing npm repository name for the instrument check is unknown: $(head -c 300 "$OUT/nexus-repos.err")"
    return 0
  fi
  npm_repo_name="$(jq -r '.data["000-npm.json"] // empty | fromjson | .name // empty' "$OUT/nexus-repos.json" 2>/dev/null)" || npm_repo_name=""
  if [ -z "$npm_repo_name" ]; then
    fail "ANONYMOUS-WRITE-DENIED" "ConfigMap ${NEXUS_NS}/nexus-repos carries no parseable 000-npm.json body with a .name, so the instrument check has no existing repository to probe"
    return 0
  fi

  npm_get_code="$(curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 \
    -u "admin:$NEXUS_PW" \
    "${ANON_WRITE_GET_BASE}/${npm_repo_name}")" || npm_get_rc=$?
  if [ "$npm_get_rc" -ne 0 ]; then
    fail "ANONYMOUS-WRITE-DENIED" "curl exited ${npm_get_rc} on the admin GET of the existing repository ${npm_repo_name} (transport error, not an HTTP verdict)"
    write_ok=0
  elif [ "$npm_get_code" != "200" ]; then
    fail "ANONYMOUS-WRITE-DENIED" "the admin GET of the EXISTING repository ${npm_repo_name} returned HTTP ${npm_get_code}, expected 200; this URL shape is the instrument the non-creation assertion depends on, and an instrument that 404s on everything would prove nothing"
    write_ok=0
  fi

  probe_get_code="$(curl -sS -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 \
    -u "admin:$NEXUS_PW" \
    "${ANON_WRITE_GET_BASE}/${ANON_WRITE_REPO}")" || probe_get_rc=$?
  if [ "$probe_get_rc" -ne 0 ]; then
    fail "ANONYMOUS-WRITE-DENIED" "curl exited ${probe_get_rc} on the admin GET of ${ANON_WRITE_REPO} (transport error, not an HTTP verdict)"
    write_ok=0
  elif [ "$probe_get_code" != "404" ]; then
    fail "ANONYMOUS-WRITE-DENIED" "the admin GET of ${ANON_WRITE_REPO} returned HTTP ${probe_get_code}, expected 404; something by that name exists, so the refusal did not prevent creation"
    write_ok=0
  fi

  if [ "$write_ok" -eq 1 ]; then
    pass "ANONYMOUS-WRITE-DENIED" "an unauthenticated POST of a structurally valid npm proxy body returned exactly 403 and created nothing (admin GET of ${ANON_WRITE_REPO} is 404, while the same URL shape returns 200 for the existing ${npm_repo_name}) - anonymous read does not extend to write"
  fi
}
check_anonymous_write_denied
echo

echo "--- 5. Second-sync idempotency ---"

# ── SECOND-SYNC-IDEMPOTENT ───────────────────────────────────────────────────
# Closes ADR-021 `## What was NOT verified` item 7: the provisioning path had
# never met an instance whose PVC already carried prior state. On the SECOND
# sync the Sync hook re-runs provision.sh against that state, and three measured
# facts must all hold:
#   1. every repository is updated, none is created: exactly 4 action=updated
#      and ZERO action=created in the provisioning log;
#   2. the guarded realms append took its no-change path — the literal line
#      provision.sh emits is "realms: DockerToken already active — no change,
#      and no request was made." (matched as a fixed-string prefix);
#   3. the active realms list is EXACTLY ["NexusAuthenticatingRealm","DockerToken"],
#      compared after `jq -c` normalisation so whitespace is not read as drift.
#
# On a first-pass run this is not evaluated, and says so as a named SKIP — never
# a pass. --sync-pass is required precisely so a first-sync run cannot satisfy
# this assertion.
EXPECTED_REALMS='["NexusAuthenticatingRealm","DockerToken"]'
check_second_sync_idempotent() {
  local idem_ok=1 updated_count="" created_count="" realms_actual=""

  if [ "$KUBECTL_OK" -ne 1 ]; then
    SKIPPED+=("SECOND-SYNC-IDEMPOTENT log assertions (4x action=updated, 0x action=created, realms no-change line): kubectl absent, no provisioning log")
    idem_ok=0
  elif [ ! -f "$OUT/provision.log" ]; then
    fail "SECOND-SYNC-IDEMPOTENT" "no provisioning log was captured (see PROVISION-JOB-COMPLETE / PROVISION-JOB-REPOS above), so the second-sync log assertions measured nothing"
    idem_ok=0
  else
    # grep -c exits 1 on zero matches; the fallback is a count default, not a
    # silenced assertion.
    updated_count="$(grep -c -- 'action=updated' "$OUT/provision.log")" || updated_count=0
    created_count="$(grep -c -- 'action=created' "$OUT/provision.log")" || created_count=0
    if [ "$updated_count" -ne 4 ]; then
      fail "SECOND-SYNC-IDEMPOTENT" "second-sync provisioning log records action=updated ${updated_count} time(s), expected exactly 4 (npm, pypi, docker, helm)"
      idem_ok=0
    fi
    if [ "$created_count" -ne 0 ]; then
      fail "SECOND-SYNC-IDEMPOTENT" "second-sync provisioning log records action=created ${created_count} time(s), expected 0; a repository was re-created against a PVC that should already carry it, so prior state was lost or not found"
      idem_ok=0
    fi
    if ! grep -qF 'realms: DockerToken already active' "$OUT/provision.log"; then
      fail "SECOND-SYNC-IDEMPOTENT" "second-sync provisioning log does not contain 'realms: DockerToken already active'; the guarded realms append did not take its no-change path, so the realms list was rewritten on a sync that should have left it alone"
      idem_ok=0
    fi
  fi

  read_realms "$OUT/realms-second.json"
  if [ "$REALMS_RC" -ne 0 ]; then
    fail "SECOND-SYNC-IDEMPOTENT" "curl exited ${REALMS_RC} reading ${REALMS_URL} as ${REALMS_IDENTITY} (transport error, not an HTTP verdict)"
    idem_ok=0
  elif [ "$REALMS_CODE" != "200" ]; then
    fail "SECOND-SYNC-IDEMPOTENT" "GET ${REALMS_URL} as ${REALMS_IDENTITY} returned HTTP ${REALMS_CODE}, expected 200"
    idem_ok=0
  else
    realms_actual="$(jq -c . "$OUT/realms-second.json" 2>/dev/null)" || realms_actual=""
    if [ "$realms_actual" != "$(printf '%s' "$EXPECTED_REALMS" | jq -c .)" ]; then
      fail "SECOND-SYNC-IDEMPOTENT" "active realms after the second sync are '${realms_actual}', expected exactly ${EXPECTED_REALMS}"
      idem_ok=0
    fi
  fi

  if [ "$idem_ok" -eq 1 ]; then
    pass "SECOND-SYNC-IDEMPOTENT" "second sync against a PVC carrying prior state: 4x action=updated, 0x action=created, realms append took its no-change path, and active realms are exactly ${EXPECTED_REALMS} (read as ${REALMS_IDENTITY})"
  fi
}

if [ "$SYNC_PASS" = "second" ]; then
  check_second_sync_idempotent
else
  SKIPPED+=("SECOND-SYNC-IDEMPOTENT: not evaluated on a --sync-pass first run; re-run this gate with --sync-pass second after the second Argo CD sync")
  echo "    SKIPPED - --sync-pass first"
fi
echo

print_summary
