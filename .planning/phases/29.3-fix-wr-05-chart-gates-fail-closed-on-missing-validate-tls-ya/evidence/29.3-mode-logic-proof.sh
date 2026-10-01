#!/usr/bin/env bash
set -euo pipefail

# 29.3-mode-logic-proof.sh — offline proof of the committed chart-gates.yml
# step bodies (Phase 29.3; D-21(2), D-23, P-EXTRACT).
#
# WHY. The live PR run (plan 29.3-05) can only show the default-mode happy
# path, because CHART_GATE_MODE is never flipped live (D-21). Every other mode,
# gate outcome bucket, dependency-build path and negative-case path is proven
# here instead, and it is proven against the exact text GitHub runs: the run:
# bodies are extracted by step id from the COMMITTED workflow blob
# (`git show <sha>:.github/workflows/chart-gates.yml`), never from a hand copy
# and never from the working tree (29.2 P-EXTRACT principle). Each body is run
# the way the runner runs a step with no shell: key, `bash -e <body>`, from the
# workspace root, with only the runner-provided variables and the job env set.
#
# Nothing is committed to, or mutated in, the operator's security-platform
# clone: every mutation happens in `git clone --no-local` copies under a
# private mktemp -d directory that the EXIT trap removes (T-29.3-14). Helm
# runs with isolated HELM_CONFIG_HOME / HELM_CACHE_HOME / HELM_DATA_HOME under
# that directory, so it never writes to ~/.config/helm.
#
# Sections:
#   0 PREFLIGHT  tools and versions (exit 2 on failure)
#   1 EXTRACT    extraction contract per job and step id
#   2 GATE       16+1 mode x outcome matrix on the gate body against a stub
#   3 DEPS       dependency-build body (D-18) and the real gate after it
#   4 NEGATIVE   negative-case body (D-15) and every D-22 skip/red case
#
# Usage (no executable bit; always via bash 5 from PATH):
#   bash 29.3-mode-logic-proof.sh [--ref <git-ref>]
#   (default ref: fix/phase-29.3-chart-gates)
#
# Output: one `PASS: <LABEL>: <text>` or `FAIL: <LABEL>: <text>` line per
# check, never stopping at the first FAIL, then `PROOF PASS - <n> checks` or
# `PROOF FAIL - <k> of <n> checks failed`.
#
# Exit: 0 every check PASS; 1 a check failed; 2 preflight or usage error.

# ── 0. PREFLIGHT ─────────────────────────────────────────────────────────────
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 5 ]; then
  echo "PREFLIGHT FAIL: bash >= 5 required, this is ${BASH_VERSION:-unknown}; run with bash 5 from PATH"
  exit 2
fi

REF="fix/phase-29.3-chart-gates"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ref)
      [ "$#" -ge 2 ] || { echo "usage: bash 29.3-mode-logic-proof.sh [--ref <git-ref>]"; exit 2; }
      REF="$2"; shift 2 ;;
    *) echo "usage: bash 29.3-mode-logic-proof.sh [--ref <git-ref>]"; exit 2 ;;
  esac
done

for bin in git yq jq helm shellcheck od; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "PREFLIGHT FAIL: required binary '${bin}' is not on PATH"
    exit 2
  fi
done
path_bash_major="$(bash -c 'echo "${BASH_VERSINFO[0]}"')"
if [ "$path_bash_major" -lt 5 ]; then
  echo "PREFLIGHT FAIL: the bash on PATH ($(command -v bash)) is major version ${path_bash_major}; the bodies need bash >= 5"
  exit 2
fi
yq_version="$(yq --version)"
case "$yq_version" in
  *mikefarah*" v4."*) ;;
  *) echo "PREFLIGHT FAIL: expected mikefarah yq v4, found: ${yq_version}"; exit 2 ;;
esac
helm_version="$(helm version --short)"
case "$helm_version" in
  v4.*) ;;
  *) echo "PREFLIGHT FAIL: expected Helm v4, found: ${helm_version}"; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! CLONE="$(cd "${SCRIPT_DIR}/../../../../repos/security-platform" 2>/dev/null && pwd)"; then
  echo "PREFLIGHT FAIL: security-platform clone not found at ${SCRIPT_DIR}/../../../../repos/security-platform"
  exit 2
fi
if ! SHA="$(git -C "$CLONE" rev-parse --verify --quiet "${REF}^{commit}")"; then
  echo "PREFLIGHT FAIL: ref '${REF}' does not resolve to a commit in ${CLONE}"
  exit 2
fi
UNFIXED_SHA="72cb174539cca5e3a2841f7977a221a90c41326e"
if ! git -C "$CLONE" cat-file -e "${UNFIXED_SHA}^{commit}" 2>/dev/null; then
  echo "PREFLIGHT FAIL: unfixed baseline ${UNFIXED_SHA} is not present in ${CLONE}"
  exit 2
fi

echo "# 29.3-03 offline proof of chart-gates.yml step bodies (D-21(2), D-23, P-EXTRACT)"
echo "# date:       $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "# clone:      ${CLONE}"
echo "# ref:        ${REF}"
echo "# sha:        ${SHA}"
echo "# unfixed:    ${UNFIXED_SHA} (origin/main baseline)"
echo "# bash:       $(command -v bash) ${BASH_VERSION}"
echo "# helm:       ${helm_version}"
echo "# yq:         ${yq_version}"
echo "# jq:         $(jq --version)"
echo "# shellcheck: $(shellcheck --version | sed -n 's/^version: //p')"
echo "# git:        $(git --version)"

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/bodies"

# ── Result bookkeeping ───────────────────────────────────────────────────────
N=0
F=0
errs=()
pass() { N=$((N + 1)); echo "PASS: $1: $2"; }
fail() { N=$((N + 1)); F=$((F + 1)); echo "FAIL: $1: $2"; }
err() { errs+=("$1"); }
# verdict <LABEL> <description>: PASS if no err was recorded since the last
# verdict, otherwise FAIL listing every recorded reason.
verdict() {
  if [ "${#errs[@]}" -eq 0 ]; then
    pass "$1" "$2"
  else
    local joined
    joined="$(printf '%s; ' "${errs[@]}")"
    fail "$1" "$2 -- ${joined%; }"
  fi
  errs=()
}
# has <file> <fixed string>: the file exists and contains the string.
has() { [ -f "$1" ] && grep -qF -- "$2" "$1"; }
# has_prefix <file> <fixed prefix>: some line of the file starts with prefix.
has_prefix() { [ -f "$1" ] && awk -v p="$2" 'index($0, p) == 1 { f = 1 } END { exit !f }' "$1"; }
# count_prefix <file> <fixed prefix>: number of lines starting with prefix.
count_prefix() {
  if [ -f "$1" ]; then awk -v p="$2" 'index($0, p) == 1 { n++ } END { print n + 0 }' "$1"; else echo 0; fi
}
# enclosed <file> <line>: the exact line appears strictly between a
# `::stop-commands::<32 hex>` line and its matching `::<token>::` line.
enclosed() {
  awk -v want="$2" '
    st == 0 && /^::stop-commands::[0-9a-f]+$/ { tok = substr($0, 18); if (length(tok) == 32) st = 1; next }
    st == 1 && $0 == "::" tok "::" { st = 2; next }
    st == 1 && $0 == want { seen = 1 }
    END { exit !(st == 2 && seen) }
  ' "$1"
}

# ── 1. EXTRACT ───────────────────────────────────────────────────────────────
echo "== 1 EXTRACT: committed blob ${SHA}:.github/workflows/chart-gates.yml =="
WF="$W/chart-gates.yml"
git -C "$CLONE" show "${SHA}:.github/workflows/chart-gates.yml" > "$WF"

JOBS=(chart-gate-defectdojo chart-gate-nexus)
IDS=(tools deps gate negative)
EXPR="\${{"

for job in "${JOBS[@]}"; do
  for id in "${IDS[@]}"; do
    body="$W/bodies/${job}__${id}.sh"
    count="$(JOB="$job" ID="$id" yq -r '[.jobs[strenv(JOB)].steps[] | select(.id == strenv(ID))] | length' "$WF")"
    JOB="$job" ID="$id" yq -r '.jobs[strenv(JOB)].steps[] | select(.id == strenv(ID)) | .run' "$WF" > "$body"
    chmod 600 "$body"

    [ "$count" = 1 ] || err "expected exactly 1 step with id ${id}, found ${count}"
    if [ ! -s "$body" ] || [ "$(tr -d '[:space:]' < "$body")" = "null" ]; then err "run body is empty or null"; fi
    verdict "EXTRACT-${job}-${id}-NONEMPTY" "exactly one step with id ${id} and a non-empty run body ($(wc -l < "$body" | tr -d ' ') lines)"

    if grep -qF -- "$EXPR" "$body"; then err "run body contains an expression"; fi
    verdict "EXTRACT-${job}-${id}-NO-EXPR" "run body contains no \${{ expression"

    has_shell="$(JOB="$job" ID="$id" yq -r '.jobs[strenv(JOB)].steps[] | select(.id == strenv(ID)) | has("shell")' "$WF")"
    [ "$has_shell" = false ] || err "step has a shell: key"
    verdict "EXTRACT-${job}-${id}-NO-SHELL" "step has no shell: key (runner default bash -e)"

    if ! bash -n "$body" 2>"$W/bash-n.err"; then err "bash -n: $(tr '\n' ' ' < "$W/bash-n.err")"; fi
    verdict "EXTRACT-${job}-${id}-BASH-N" "bash -n clean"

    if ! shellcheck -s bash "$body" > "$W/sc.out" 2>&1; then err "shellcheck: $(grep -o 'SC[0-9]*' "$W/sc.out" | sort -u | tr '\n' ' ')"; fi
    verdict "EXTRACT-${job}-${id}-SHELLCHECK" "shellcheck -s bash clean"
  done
done

for id in "${IDS[@]}"; do
  if ! cmp -s "$W/bodies/${JOBS[0]}__${id}.sh" "$W/bodies/${JOBS[1]}__${id}.sh"; then err "bodies differ"; fi
  verdict "BODY-IDENTICAL-${id}" "${id} body byte-identical across ${JOBS[0]} and ${JOBS[1]}"
done

declare -A JENV
for job in "${JOBS[@]}"; do
  keys="$(JOB="$job" yq -r '.jobs[strenv(JOB)].steps[] | select(.id == "gate") | .env | keys | sort | join(",")' "$WF")"
  val="$(JOB="$job" yq -r '.jobs[strenv(JOB)].steps[] | select(.id == "gate") | .env.CHART_GATE_MODE' "$WF")"
  [ "$keys" = CHART_GATE_MODE ] || err "gate env keys are '${keys}'"
  [ "$val" = "${EXPR} vars.CHART_GATE_MODE }}" ] || err "CHART_GATE_MODE value is '${val}'"
  verdict "ENV-GATE-${job}" "gate step env keys == [CHART_GATE_MODE], value == \${{ vars.CHART_GATE_MODE }}"

  for id in deps negative; do
    h="$(JOB="$job" ID="$id" yq -r '.jobs[strenv(JOB)].steps[] | select(.id == strenv(ID)) | has("env")' "$WF")"
    [ "$h" = false ] || err "step has an env: key"
    verdict "ENV-NONE-${job}-${id}" "${id} step has no env: key"
  done

  keys="$(JOB="$job" yq -r '.jobs[strenv(JOB)].env | keys | sort | join(",")' "$WF")"
  [ "$keys" = "CHART,CHART_LABEL,GUARD_LABEL,GUARD_TEMPLATE" ] || err "job env keys are '${keys}'"
  for k in CHART CHART_LABEL GUARD_LABEL GUARD_TEMPLATE; do
    tag="$(JOB="$job" K="$k" yq -r '.jobs[strenv(JOB)].env[strenv(K)] | tag' "$WF")"
    v="$(JOB="$job" K="$k" yq -r '.jobs[strenv(JOB)].env[strenv(K)]' "$WF")"
    [ "$tag" = '!!str' ] || err "${k} is ${tag}, not a string literal"
    case "$v" in *"$EXPR"*|'') err "${k} value '${v}' is empty or an expression" ;; esac
    JENV["${job}.${k}"]="$v"
  done
  [ "${JENV[${job}.CHART]:-}" = "${job#chart-gate-}" ] || err "CHART '${JENV[${job}.CHART]:-}' does not match job id ${job}"
  verdict "ENV-JOB-${job}" "job env keys == [CHART, CHART_LABEL, GUARD_LABEL, GUARD_TEMPLATE], literal values (CHART=${JENV[${job}.CHART]:-} GUARD_LABEL=${JENV[${job}.GUARD_LABEL]:-} GUARD_TEMPLATE=${JENV[${job}.GUARD_TEMPLATE]:-} CHART_LABEL=${JENV[${job}.CHART_LABEL]:-})"

  cond="$(JOB="$job" yq -r '.jobs[strenv(JOB)].steps[] | select(.id == "negative") | .if' "$WF")"
  [ "$cond" = "${EXPR} !cancelled() }}" ] || err "negative if: is '${cond}'"
  verdict "NEG-IF-${job}" "negative step if: == \${{ !cancelled() }}"
done

# job_env <job>: the job env as NAME=value words for env -i.
job_env() {
  local k
  for k in CHART CHART_LABEL GUARD_LABEL GUARD_TEMPLATE; do
    printf '%s=%s\n' "$k" "${JENV[${1}.${k}]}"
  done
}

# ── 2. GATE MATRIX ───────────────────────────────────────────────────────────
# The defectdojo gate body runs against a stub check-defectdojo-chart.sh; the
# nexus body is the same bytes (BODY-IDENTICAL-gate).
echo "== 2 GATE: mode x outcome matrix on the extracted gate body =="
GJOB="chart-gate-defectdojo"
GATE_BODY="$W/bodies/${GJOB}__gate.sh"
GCHART="${JENV[${GJOB}.CHART]}"
mapfile -t GJOB_ENV < <(job_env "$GJOB")

# stub_lines <outcome>: the stub's stdout lines; stub_rc <outcome>: its exit.
stub_lines() {
  case "$1" in
    P) printf '%s\n' 'stub ok' 'PASS - 3 checks, 0 failures' ;;
    V) printf '%s\n' 'SKIP: vacuous' ;;
    F) printf '%s\n' 'FAIL: STUB-LABEL: 100% broken' 'FAILED - 1 check(s)' ;;
    I) printf '%s\n' 'PREFLIGHT FAIL: stub' ;;
    O) printf '%s\n' 'odd' ;;
  esac
}
stub_rc() { case "$1" in P|V) echo 0 ;; F) echo 1 ;; I) echo 2 ;; O) echo 3 ;; esac; }
GATE_SEQ=0

# run_gate <mode|UNSET|EMPTY> <outcome>: sets C (case dir) and RC.
run_gate() {
  local mode="$1" oc="$2" line
  # Numbered case dirs: macOS APFS is case-insensitive, so `Blocking-P` and
  # `blocking-P` would otherwise be the same directory.
  GATE_SEQ=$((GATE_SEQ + 1))
  C="$W/gate/${GATE_SEQ}-${mode}-${oc}"
  mkdir -p "$C/ws/scripts" "$C/rt"
  {
    echo '#!/usr/bin/env bash'
    printf ': > %q\n' "$C/marker"
    while IFS= read -r line; do printf 'printf %%s\\\\n %q\n' "$line"; done < <(stub_lines "$oc")
    echo "exit $(stub_rc "$oc")"
  } > "$C/ws/scripts/check-${GCHART}-chart.sh"
  local envs=(PATH="$PATH" HOME="$HOME" "${GJOB_ENV[@]}"
    GITHUB_WORKSPACE="$C/ws" RUNNER_TEMP="$C/rt" GITHUB_STEP_SUMMARY="$C/summary")
  case "$mode" in
    UNSET) ;;
    EMPTY) envs+=(CHART_GATE_MODE=) ;;
    *) envs+=(CHART_GATE_MODE="$mode") ;;
  esac
  RC=0
  (cd "$C/ws" && env -i "${envs[@]}" bash -e "$GATE_BODY") > "$C/stdout" 2>&1 || RC=$?
}

gate_case() {
  local mode="$1" oc="$2" eff last out
  run_gate "$mode" "$oc"
  out="$C/rt/chart-gate-${GCHART}.out"
  last="$(stub_lines "$oc" | tail -n 1)"
  case "$mode" in
    UNSET|EMPTY|report-only) eff=report-only ;;
    blocking) eff=blocking ;;
    *) eff=TYPO ;;
  esac

  if [ "$eff" = TYPO ]; then
    [ "$RC" = 1 ] || err "rc ${RC}, expected 1"
    has_prefix "$C/stdout" "::error::CHART_GATE_MODE=${mode} is not blocking|report-only" || err "no ::error::CHART_GATE_MODE=${mode} is not blocking|report-only"
    [ ! -e "$C/marker" ] || err "stub was invoked"
    [ ! -e "$out" ] || err ".out was written"
    ! has_prefix "$C/stdout" "chart gate mode:" || err "printed a chart gate mode line"
    verdict "GATE-${mode}-${oc}" "typo mode exits 1 before the gate runs (rc ${RC}, stub not invoked, no .out)"
    return 0
  fi

  [ -e "$C/marker" ] || err "stub was not invoked"
  [ -f "$out" ] || err ".out absent"
  has_prefix "$C/stdout" "chart gate mode: ${eff}" || err "no 'chart gate mode: ${eff}'"
  enclosed "$C/stdout" "$last" || err "stub output not enclosed by a ::stop-commands:: token pair"
  case "$oc" in
    P)
      [ "$RC" = 0 ] || err "rc ${RC}, expected 0"
      has_prefix "$C/stdout" "chart-gate-${GCHART}: PASS" || err "no chart-gate-${GCHART}: PASS"
      ! has_prefix "$C/stdout" "::warning" || err "::warning emitted"
      ! has_prefix "$C/stdout" "::error" || err "::error emitted"
      [ ! -s "$C/summary" ] || err "summary written"
      verdict "GATE-${mode}-${oc}" "mode ${eff}, gate rc0 + PASS line: rc ${RC}, PASS, no annotations, no summary, stop-commands enclosed"
      ;;
    V|F)
      has_prefix "$C/summary" "### chart-gate-${GCHART}:" || err "summary header absent"
      if [ "$oc" = V ]; then
        has "$C/summary" "vacuous pass" || err "summary does not name the vacuous pass"
      else
        has "$C/summary" "FAIL: STUB-LABEL: 100% broken" || err "summary lacks the FAIL line"
      fi
      if [ "$eff" = blocking ]; then
        [ "$RC" = 1 ] || err "rc ${RC}, expected 1"
        has_prefix "$C/stdout" "::error::chart-gate-${GCHART}:" || err "no ::error::chart-gate-${GCHART}:"
        ! has_prefix "$C/stdout" "::warning" || err "::warning emitted in blocking mode"
        verdict "GATE-${mode}-${oc}" "mode blocking, chart-defect bucket ($([ "$oc" = V ] && echo 'rc0 without PASS' || echo 'rc1')): rc ${RC}, ::error, summary written"
      else
        [ "$RC" = 0 ] || err "rc ${RC}, expected 0"
        has_prefix "$C/stdout" "::warning title=chart-gate-${GCHART}::" || err "no ::warning title=chart-gate-${GCHART}::"
        ! has_prefix "$C/stdout" "::error" || err "::error emitted in report-only mode"
        if [ "$oc" = F ]; then
          has_prefix "$C/stdout" "::warning title=chart-gate-${GCHART}::FAIL: STUB-LABEL: 100%25 broken" || err "FAIL warning missing or % not encoded as %25"
        fi
        verdict "GATE-${mode}-${oc}" "mode report-only, chart-defect bucket ($([ "$oc" = V ] && echo 'rc0 without PASS' || echo 'rc1')): rc ${RC}, $(count_prefix "$C/stdout" '::warning') ::warning line(s)$([ "$oc" = F ] && echo ' incl. 100%25 encoding'), summary written"
      fi
      ;;
    I)
      [ "$RC" = 1 ] || err "rc ${RC}, expected 1"
      has_prefix "$C/stdout" "::error::check-${GCHART}-chart.sh preflight failed (exit 2)" || err "no preflight ::error"
      verdict "GATE-${mode}-${oc}" "mode ${eff}, always-red bucket (gate rc2): rc ${RC}, preflight ::error"
      ;;
    O)
      [ "$RC" = 1 ] || err "rc ${RC}, expected 1"
      has_prefix "$C/stdout" "::error::check-${GCHART}-chart.sh exited 3" || err "no 'exited 3' ::error"
      verdict "GATE-${mode}-${oc}" "mode ${eff}, always-red bucket (gate rc3): rc ${RC}, 'exited 3' ::error"
      ;;
  esac
}

for mode in UNSET EMPTY report-only blocking Blocking; do
  for oc in P V F I; do
    gate_case "$mode" "$oc"
  done
done
gate_case UNSET O

# ── Real-workspace helpers for Sections 3 and 4 ──────────────────────────────
# new_case <sha>: a fresh `git clone --no-local` of the operator clone checked
# out detached at <sha>, so `git status` works inside the bodies. Sets WS (the
# workspace), RT (RUNNER_TEMP, a SIBLING of WS so cp -a never recurses), CD
# (the case dir) and isolated Helm homes under CD/helm.
CASE_SEQ=0
new_case() {
  CASE_SEQ=$((CASE_SEQ + 1))
  CD="$W/case/${CASE_SEQ}"
  mkdir -p "$CD/rt" "$CD/helm/config" "$CD/helm/cache" "$CD/helm/data"
  git clone --quiet --no-local "$CLONE" "$CD/ws"
  git -C "$CD/ws" checkout --quiet --detach "$1"
  WS="$CD/ws"
  RT="$CD/rt"
}

# run_body <job> <id> [NAME=value ...]: run an extracted body the way the
# runner does (bash -e from the workspace root, job env + runner variables
# only, isolated Helm homes). Sets RC and STDOUT.
run_body() {
  local job="$1" id="$2"
  shift 2
  local jenv
  mapfile -t jenv < <(job_env "$job")
  local envs=(PATH="$PATH" HOME="$HOME" "${jenv[@]}"
    HELM_CONFIG_HOME="$CD/helm/config" HELM_CACHE_HOME="$CD/helm/cache" HELM_DATA_HOME="$CD/helm/data"
    GITHUB_WORKSPACE="$WS" RUNNER_TEMP="$RT" GITHUB_STEP_SUMMARY="$RT/summary" "$@")
  STDOUT="$CD/${id}.stdout"
  RC=0
  (cd "$WS" && env -i "${envs[@]}" bash -e "$W/bodies/${job}__${id}.sh") > "$STDOUT" 2>&1 || RC=$?
}

# ── 3. DEPS (D-18) and the real gate after a fresh-clone dependency build ────
echo "== 3 DEPS: extracted deps body (isolated Helm homes, network) =="
for chart in defectdojo nexus; do
  job="chart-gate-${chart}"

  new_case "$SHA"
  rm -rf "$WS/kubernetes/${chart}"
  run_body "$job" deps
  [ "$RC" = 0 ] || err "rc ${RC}, expected 0"
  has_prefix "$STDOUT" "::notice::kubernetes/${chart}/Chart.yaml is absent" || err "no ::notice naming kubernetes/${chart}/Chart.yaml"
  [ ! -e "$CD/helm/config/repositories.yaml" ] || err "helm repo add ran"
  verdict "DEPS-ABSENT-${chart}" "chart dir absent: deps body rc ${RC} with ::notice naming Chart.yaml, no helm repo add"
done

new_case "$SHA"
yq -i '.dependencies[0].repository = "oci://example.invalid/charts"' "$WS/kubernetes/defectdojo/Chart.yaml"
run_body chart-gate-defectdojo deps
[ "$RC" = 1 ] || err "rc ${RC}, expected 1"
has_prefix "$STDOUT" "::error::" || err "no ::error line"
has "$STDOUT" "only https:// repositories are supported" || err "no 'only https:// repositories are supported'"
[ ! -e "$CD/helm/config/repositories.yaml" ] || err "helm repo add ran before the https check"
verdict "DEPS-NONHTTPS-defectdojo" "oci:// dependency repository: deps body rc ${RC}, ::error 'only https:// repositories are supported', no helm repo add"

for chart in defectdojo nexus; do
  job="chart-gate-${chart}"
  new_case "$SHA"
  run_body "$job" deps
  [ "$RC" = 0 ] || err "rc ${RC}, expected 0 (last line: $(tail -n 1 "$STDOUT"))"
  compgen -G "$WS/kubernetes/${chart}/charts/*.tgz" > /dev/null || err "no kubernetes/${chart}/charts/*.tgz"
  git -C "$CLONE" show "${SHA}:kubernetes/${chart}/Chart.lock" > "$CD/Chart.lock.committed"
  cmp -s "$CD/Chart.lock.committed" "$WS/kubernetes/${chart}/Chart.lock" || err "Chart.lock differs from the committed blob"
  [ -s "$CD/helm/config/repositories.yaml" ] || err "isolated HELM_CONFIG_HOME has no repositories.yaml"
  tgzs=("$WS/kubernetes/${chart}/charts/"*.tgz)
  tgz="$(printf '%s ' "${tgzs[@]##*/}")"
  verdict "DEPS-BUILD-${chart}" "fresh clone: deps body rc ${RC}, built ${tgz% }, Chart.lock identical to the committed blob, repo registered in the isolated Helm config"

  run_body "$job" gate
  [ "$RC" = 0 ] || err "rc ${RC}, expected 0"
  has_prefix "$STDOUT" "chart-gate-${chart}: PASS" || err "no chart-gate-${chart}: PASS"
  has_prefix "$STDOUT" "chart gate mode: report-only" || err "mode was not report-only with CHART_GATE_MODE unset"
  ! has_prefix "$STDOUT" "::warning" || err "::warning emitted"
  ! has_prefix "$STDOUT" "::error" || err "::error emitted"
  last="$(tail -n 1 "$RT/chart-gate-${chart}.out" 2>/dev/null || true)"
  case "$last" in 'PASS -'*) ;; *) err "real gate .out last line is '${last}'" ;; esac
  verdict "REAL-GATE-${chart}" "real check-${chart}-chart.sh after the deps body, CHART_GATE_MODE unset: rc ${RC}, chart-gate-${chart}: PASS (${last})"
done

# ── 4. NEGATIVE (D-15) and D-22 ──────────────────────────────────────────────
echo "== 4 NEGATIVE: extracted negative body =="
# run_neg <job>: run the negative body and assert the invariants every case
# shares: workspace git status identical before and after, and no neg-*
# copies left in RUNNER_TEMP.
run_neg() {
  local before after
  before="$(git -C "$WS" status --porcelain=v1)"
  run_body "$1" negative
  after="$(git -C "$WS" status --porcelain=v1)"
  [ "$before" = "$after" ] || err "workspace git status changed during the body"
  if compgen -G "$RT/neg-*" > /dev/null; then err "neg-* copies left in RUNNER_TEMP"; fi
}
# pos_out <chart> <line>: write the positive gate output the negative step reads.
pos_out() { printf '%s\n' "$2" > "$RT/chart-gate-$1.out"; }
rm_guard() { rm -- "$WS/kubernetes/$1/templates/${JENV[chart-gate-$1.GUARD_TEMPLATE]}"; }
rm_dir() { rm -rf -- "$WS/kubernetes/$1"; }

for chart in defectdojo nexus; do
  job="chart-gate-${chart}"
  glabel="${JENV[${job}.GUARD_LABEL]}"
  clabel="${JENV[${job}.CHART_LABEL]}"

  new_case "$SHA"
  run_neg "$job"
  [ "$RC" = 0 ] || err "rc ${RC}, expected 0"
  has_prefix "$STDOUT" "negative (a) PASS" || err "no 'negative (a) PASS'"
  has_prefix "$STDOUT" "negative (b) PASS" || err "no 'negative (b) PASS'"
  ! has_prefix "$STDOUT" "::error" || err "::error emitted"
  verdict "NEG-FIXED-${chart}" "fixed ${SHA:0:7}, no .out: rc ${RC}, negative (a) PASS and (b) PASS, status unchanged, RUNNER_TEMP clean"

  new_case "$UNFIXED_SHA"
  run_neg "$job"
  [ "$RC" = 1 ] || err "rc ${RC}, expected 1"
  has_prefix "$STDOUT" "::error::negative (a)" || err "no ::error::negative (a)"
  has_prefix "$STDOUT" "::error::negative (b)" || err "no ::error::negative (b)"
  verdict "NEG-UNFIXED-${chart}" "unfixed ${UNFIXED_SHA:0:7} (SKIP exit 0): rc ${RC}, ::error for (a) and (b), status unchanged, RUNNER_TEMP clean"

  new_case "$SHA"
  rm_guard "$chart"
  pos_out "$chart" "FAIL: ${glabel}: x"
  run_neg "$job"
  [ "$RC" = 0 ] || err "rc ${RC}, expected 0"
  has_prefix "$STDOUT" "::notice::negative (a)" || err "no ::notice::negative (a)"
  has_prefix "$STDOUT" "negative (b) PASS" || err "no 'negative (b) PASS'"
  ! has_prefix "$STDOUT" "::error" || err "::error emitted"
  verdict "NEG-D22-GUARD-LABEL-${chart}" "guard template absent, .out has FAIL: ${glabel}: : rc ${RC}, ::notice (a), negative (b) PASS"

  new_case "$SHA"
  rm_dir "$chart"
  pos_out "$chart" "FAIL: ${clabel}: x"
  run_neg "$job"
  [ "$RC" = 0 ] || err "rc ${RC}, expected 0"
  has_prefix "$STDOUT" "::notice::negative (a)" || err "no ::notice::negative (a)"
  has_prefix "$STDOUT" "::notice::negative (b)" || err "no ::notice::negative (b)"
  ! has_prefix "$STDOUT" "::error" || err "::error emitted"
  verdict "NEG-D22-DIR-LABEL-${chart}" "chart dir absent, .out has FAIL: ${clabel}: : rc ${RC}, ::notice (a) and (b)"
done

job="chart-gate-defectdojo"
chart=defectdojo
glabel="${JENV[${job}.GUARD_LABEL]}"
clabel="${JENV[${job}.CHART_LABEL]}"

new_case "$SHA"
rm_guard "$chart"
pos_out "$chart" "PASS - 22 checks, 0 failures"
run_neg "$job"
[ "$RC" = 1 ] || err "rc ${RC}, expected 1"
has_prefix "$STDOUT" "::error::negative (a)" || err "no ::error::negative (a)"
! has_prefix "$STDOUT" "::notice::negative (a)" || err "(a) skipped with ::notice"
verdict "NEG-D22-GUARD-NOLABEL" "guard absent, .out without the label: rc ${RC}, ::error::negative (a)"

new_case "$SHA"
rm_guard "$chart"
run_neg "$job"
[ "$RC" = 1 ] || err "rc ${RC}, expected 1"
has_prefix "$STDOUT" "::error::negative (a)" || err "no ::error::negative (a)"
verdict "NEG-D22-GUARD-NOFILE" "guard absent, no .out file: rc ${RC}, ::error::negative (a)"

new_case "$SHA"
rm_dir "$chart"
pos_out "$chart" "FAIL: ${glabel}: x"
run_neg "$job"
[ "$RC" = 1 ] || err "rc ${RC}, expected 1"
has_prefix "$STDOUT" "::error::negative (b)" || err "no ::error::negative (b)"
verdict "NEG-D22-DIR-WRONGLABEL" "chart dir absent, .out has only FAIL: ${glabel}: : rc ${RC}, ::error::negative (b)"

new_case "$SHA"
rm_guard "$chart"
pos_out "$chart" "FAIL: ${clabel}: x"
run_neg "$job"
[ "$RC" = 1 ] || err "rc ${RC}, expected 1"
has_prefix "$STDOUT" "::error::negative (a)" || err "no ::error::negative (a)"
has_prefix "$STDOUT" "negative (b) PASS" || err "no 'negative (b) PASS'"
verdict "NEG-D22-GUARD-CHARTLABEL-DIRPRESENT" "guard absent, chart dir present, .out has only FAIL: ${clabel}: : rc ${RC}, ::error::negative (a) (chart label accepted only when the dir is absent)"

new_case "$SHA"
rm_dir "$chart"
run_neg "$job"
[ "$RC" = 1 ] || err "rc ${RC}, expected 1"
has_prefix "$STDOUT" "::error::negative (a)" || err "no ::error::negative (a)"
has_prefix "$STDOUT" "::error::negative (b)" || err "no ::error::negative (b)"
verdict "NEG-NOFILE-DIR" "chart dir absent, no .out file: rc ${RC}, ::error for (a) and (b)"

# ── RESULT ───────────────────────────────────────────────────────────────────
if [ "$F" -eq 0 ]; then
  echo "PROOF PASS - ${N} checks"
  exit 0
fi
echo "PROOF FAIL - ${F} of ${N} checks failed"
exit 1
