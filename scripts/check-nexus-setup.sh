#!/usr/bin/env bash
set -euo pipefail

# check-nexus-setup.sh — offline standing gate for the workstation Nexus
# routing script, workstation/nexus-setup.sh (created in plan 24-06).
#
# WHY THIS EXISTS. A script that writes four config files and prints "done" is
# indistinguishable, from its exit code, from a script that routed nothing: npm
# falls back to registry.npmjs.org when the local prefix resolves elsewhere,
# pip and Helm only obey an env file somebody has to source, and Docker has no
# per-repository config at all. Worse, the naive implementations of two of
# those writes DESTROY state the developer already had — a `cat > .npmrc`
# silently takes a private-registry `_authToken` with it, and a hand-written
# .helm/repositories.yaml is a forgery of Helm's own internal format. None of
# that is visible in an exit code, and all of it is visible here.
#
# This gate is written BEFORE its subject, following the Phase 23 precedent
# where scripts/check-nexus-chart.sh preceded the chart it measures. The names
# below are therefore a CONTRACT that plans 24-06 and 24-07 build against, not
# a description of something that already exists.
#
# It is offline: it makes no request to any Nexus instance, and the only
# network it touches is a loopback stub it starts and stops itself. It runs in
# seconds.
#
# TERMINAL CONVENTION — three states, counted at RUNTIME. Copied from
# scripts/nexus-live-smoke.sh, deliberately NOT from check-nexus-chart.sh:
#   FAILED - n check(s) …            at least one assertion produced the wrong result
#   NOTHING RAN - 0 check(s) …       nothing executed; this is NOT a pass
#   ALL PASS - n check(s) executed and passed; m sub-check(s) skipped …
# There is no compile-time constant holding the number of checks, and adding
# one would be a mistake: two later plans (24-06, 24-07) add behaviour to the
# subject, and a constant would become a merge point for no benefit. A SKIP is
# never counted as a pass, and zero failures on a run where zero checks ran is
# never reported as a pass.
#
# Exit codes — three, not two:
#   0  every check that ran passed, or nothing ran (subject absent, by design)
#   1  at least one assertion failed  (a SCRIPT defect — fix the subject)
#   2  preflight failed: a hard-tier binary is missing. That is an
#      INFRASTRUCTURE problem on this machine, not a defect in the subject, and
#      the two must never be conflated.
#
# Never set the executable bit on this file (project Script Safety rule).
# Invoke as:
#   bash scripts/check-nexus-setup.sh
#
# SUBJECT OVERRIDE. NEXUS_SETUP_GATE_SUBJECT overrides the path of the script
# under test. It exists for exactly one purpose: this gate's own SKIP guard
# means that, in this repository before plan 24-06, `bash
# scripts/check-nexus-setup.sh` exercises ZERO assertion bodies — so the gate
# could ship broken and nobody would know. Pointing it at a throwaway
# conforming subject built in a scratchpad is how every assertion body here was
# observed firing, and how nine single-defect mutations were each confirmed to
# produce exactly one red check. Plans 24-06 and 24-07 can use the same
# mechanism to iterate without committing. It is a TEST HOOK, not a
# configuration knob: CI and pre-commit must invoke this script with it unset.
#
#   NEXUS_SETUP_GATE_SUBJECT=/abs/path/to/nexus-setup.sh bash scripts/check-nexus-setup.sh
#
# ORDERING CONTRACT IMPOSED ON THE SUBJECT (read this before writing 24-06).
# `helm repo add` is not an offline operation: Helm fetches index.yaml during
# `repo add` and errors on an unreachable repository, with no --no-update
# escape. Two of the fixture runs below therefore point at hostnames that do
# not resolve and are EXPECTED to end non-zero at the Helm writer. They assert
# on the .npmrc and pip.conf those runs left behind, which is only possible if
# the subject writes .npmrc and pip.conf BEFORE it invokes `helm repo add`.
# That ordering is binding. The runs that need a completed subject use a
# loopback stub instead of a dead hostname.

# ── Paths ────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# The default is repository-relative; the override is expected to be absolute,
# because every fixture run below invokes the subject from a throwaway
# directory rather than from here.
SUBJECT="${NEXUS_SETUP_GATE_SUBJECT:-workstation/nexus-setup.sh}"

# ── Check-name registry ──────────────────────────────────────────────────────
# Every check name is a literal EXACTLY ONCE in this file, here. Assertions,
# skip entries and failure messages all reference the variable. Two reasons,
# both practical: `grep -c '<NAME>' scripts/check-nexus-setup.sh` is then a
# reliable "is this check implemented" test for a verifier, and a check whose
# skip entry and whose assertion spell its name differently cannot exist.

CHK_NOT_EXECUTABLE="SETUP-NOT-EXECUTABLE"
CHK_SHELLCHECK="SETUP-SHELLCHECK"
CHK_NPMRC_NO_REDIRECT="NPMRC-NO-REDIRECT"
CHK_HELM_NOT_HANDWRITTEN="HELM-NOT-HANDWRITTEN"
CHK_VERIFY_NO_SILENT_TRUE="VERIFY-NO-SILENT-TRUE"
CHK_DOCKER_DAEMON_WARNING="DOCKER-DAEMON-WARNING"
CHK_NPMRC_MERGE="NPMRC-MERGE"
CHK_DOCKER_PREFIX_SHAPE="DOCKER-PREFIX-SHAPE"
CHK_PIP_TRUSTED_HOST="PIP-TRUSTED-HOST-CONDITIONAL"
CHK_NEXUS_ENV_EXPORTS="NEXUS-ENV-EXPORTS"
CHK_GLOBAL_CONFIG_UNTOUCHED="GLOBAL-CONFIG-UNTOUCHED"
CHK_VERIFY_FAILS_LOUDLY="VERIFY-FAILS-LOUDLY"

# ── Accounting ───────────────────────────────────────────────────────────────

FAILURES=()
# SKIPPED: sub-checks that did not run — an optional tool is absent, or the
# check is conditional on source the subject may legitimately not contain.
# Reported separately from failures AND separately from passes, because a skip
# is neither. It never affects the exit status.
SKIPPED=()
# CHECKS_PASSED: counted from the run itself, so the summary cannot claim a
# pass on a run where nothing executed.
CHECKS_PASSED=0

pass() {
  echo "==> $1: PASS - $2"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

fail() {
  echo "==> $1: FAIL - $2"
  FAILURES+=("$1: $2")
}

skip() {
  echo "==> $1: SKIPPED - $2"
  SKIPPED+=("$1: $2")
}

# print_summary: the terminal verdict. Skips print first, under their own
# heading, on every path.
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
    echo "FAILED - ${#FAILURES[@]} check(s) did not produce the expected result:"
    for f in "${FAILURES[@]}"; do
      echo "  - ${f}"
    done
    exit 1
  elif [ "$CHECKS_PASSED" -eq 0 ]; then
    # Zero failures on a run where zero checks executed is NOT a pass. Printing
    # ALL PASS here is the vacuous-green this convention exists to forbid.
    echo "NOTHING RAN - 0 check(s) executed; ${#SKIPPED[@]} sub-check(s) skipped (not passed). Nothing was proven."
    exit 0
  else
    echo "ALL PASS - ${CHECKS_PASSED} check(s) executed and passed; ${#SKIPPED[@]} sub-check(s) skipped (not passed)."
    exit 0
  fi
}

# ── Guard: the subject does not exist yet (pre-24-06) ────────────────────────
# Checked BEFORE the binary preflight on purpose. At this gate's own creation
# commit the subject does not exist, and exiting 2 for a missing shellcheck on
# a repository state that is correct by design would report an infrastructure
# problem where there is none. This guard is why the gate can be committed in
# wave 1 and stay green until plan 24-06 lands. Do not "complete" this script
# by deleting it.
if [ ! -f "$SUBJECT" ]; then
  skip "check-nexus-setup" "${SUBJECT} does not exist yet — the workstation routing script is created in plan 24-06; no assertion could run"
  print_summary
fi

# ── Preflight, hard tier (exit 2 — infrastructure, not a defect) ─────────────
# The shellcheck binary drives an assertion directly (a comment here may not
# begin with that word, or shellcheck parses the line as a directive to itself
# and errors). jq reads npm's own resolved configuration as JSON in the merge
# check below, which is the only way to measure what npm READS rather than what
# the subject WROTE.
for bin in shellcheck jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "PREFLIGHT FAIL: required binary '${bin}' is not on PATH — this is a machine problem, not a defect in ${SUBJECT}" >&2
    exit 2
  fi
done

# ── Preflight, soft tier (SKIPPED, never a silent pass) ──────────────────────
# One absent tool must be exactly one skipped sub-check, with the tool named —
# the Phase 16 accounting introduced in scripts/smoke-scans.sh. These tiers are
# consumed by the fixture-driven checks; the source-level checks below need
# neither tool and run regardless.
HAVE_NPM=1
HAVE_HELM=1
HAVE_PYTHON3=1
command -v npm     >/dev/null 2>&1 || HAVE_NPM=0
command -v helm    >/dev/null 2>&1 || HAVE_HELM=0
command -v python3 >/dev/null 2>&1 || HAVE_PYTHON3=0
[ "$HAVE_NPM" = "1" ]     || echo "NOTE: optional binary 'npm' not found on PATH — fixture checks that need it will be SKIPPED, not passed."
[ "$HAVE_HELM" = "1" ]    || echo "NOTE: optional binary 'helm' not found on PATH — fixture checks that need a completed subject run will be SKIPPED, not passed."
[ "$HAVE_PYTHON3" = "1" ] || echo "NOTE: optional binary 'python3' not found on PATH — the loopback Helm stub cannot be served, so fixture checks that need a completed subject run will be SKIPPED, not passed."

echo "check-nexus-setup: asserting offline invariants against ${SUBJECT}"

# ── Scratch space ────────────────────────────────────────────────────────────
# Every fixture and every intermediate file lives here. Nothing this gate
# writes ever lands inside either repository working tree.
OUT="$(mktemp -d)"
# Assigned BEFORE the trap so `set -u` cannot trip inside the cleanup path.
STUB_PID=""
# The `|| true` below is teardown hygiene on a best-effort kill of a process
# that may already have exited — no verdict is derived from it.
trap 'rm -rf "$OUT"; if [ -n "$STUB_PID" ]; then kill "$STUB_PID" >/dev/null 2>&1 || true; fi' EXIT

# ── Source-reading helpers ───────────────────────────────────────────────────

# The comment-stripped source. Every "this construct must not appear" check
# reads THIS, never the raw file, so the subject can document a hazard in prose
# without failing its own gate for describing it.
SRC_NOCOMMENT="$OUT/subject.nocomment.sh"
# grep -v exits 1 when it selects no lines (a subject that is nothing but
# comments); that is not an error here, hence the tolerated non-zero.
grep -v '^[[:space:]]*#' "$SUBJECT" > "$SRC_NOCOMMENT" || true

# match_lines <ERE> <file> <outfile> — writes numbered matching lines, returns
# 0 if there was at least one. Wrapped in `if` at every call site so grep's
# no-match exit 1 cannot trip `set -e`, and written through a file rather than
# a pipeline so `pipefail` has no SIGPIPE to trip over either.
match_lines() {
  if grep -nE "$1" "$2" > "$3"; then
    return 0
  fi
  return 1
}

# One-line rendering of a file, for failure messages that must name the
# OBSERVED state rather than say "looks wrong".
summarise_file() {
  tr '\n' ' ' < "$1" | cut -c1-240
}

# ── 1. The executable bit ────────────────────────────────────────────────────
# workstation/setup.sh sits in this tree at mode 755 and is the analog that
# violates the project rule. It is deliberately not copied.
CHK="$CHK_NOT_EXECUTABLE"
if [ -x "$SUBJECT" ]; then
  # BSD stat first, GNU stat second — this gate runs on both workstations and CI.
  subject_mode="$(stat -f '%Sp' "$SUBJECT" 2>/dev/null || stat -c '%A' "$SUBJECT" 2>/dev/null || echo 'mode unreadable')"
  fail "$CHK" "${SUBJECT} has the executable bit set (mode ${subject_mode}). The project Script Safety rule forbids it: scripts are invoked as 'bash <path>' so the interpreter is never chosen by a shebang. workstation/setup.sh is 755 in this tree and is the analog violating the rule — it is not the precedent to follow. Fix with: chmod -x ${SUBJECT}"
else
  pass "$CHK" "${SUBJECT} is not executable, as the project Script Safety rule requires"
fi

# ── 2. shellcheck ────────────────────────────────────────────────────────────
CHK="$CHK_SHELLCHECK"
if shellcheck "$SUBJECT" > "$OUT/shellcheck.txt" 2>&1; then
  pass "$CHK" "shellcheck reports no findings on ${SUBJECT}"
else
  fail "$CHK" "shellcheck exited non-zero on ${SUBJECT}: $(summarise_file "$OUT/shellcheck.txt")"
fi

# ── 3. No redirect onto .npmrc ───────────────────────────────────────────────
# Pitfall 7. A developer's .npmrc may hold a //registry/:_authToken line that
# is the only copy of a private-registry credential. `npm config set
# registry=<url> --location=project` is measured non-destructive; a `>` or `>>`
# onto the same path is credential loss with no error message and no exit code.
CHK="$CHK_NPMRC_NO_REDIRECT"
if match_lines '>>?[[:space:]]*[^[:space:];&|)]*\.npmrc' "$SRC_NOCOMMENT" "$OUT/npmrc-redirect.txt"; then
  fail "$CHK" "a shell redirect targets .npmrc in ${SUBJECT} (comment lines already excluded): $(summarise_file "$OUT/npmrc-redirect.txt") — Pitfall 7: this destroys any existing //registry/:_authToken line silently, with no error and a zero exit status. Use 'npm config set registry=<url> --location=project', which is measured non-destructive."
else
  pass "$CHK" "no '>' or '>>' redirect targets .npmrc anywhere in the non-comment source"
fi

# ── 4. Helm's repositories.yaml is written by Helm ───────────────────────────
# Two sub-conditions, one verdict: the subject must shell out to `helm repo
# add`, and must not forge the file itself.
CHK="$CHK_HELM_NOT_HANDWRITTEN"
helm_reason=""
if ! grep -q 'helm repo add' "$SRC_NOCOMMENT"; then
  helm_reason="no 'helm repo add' invocation appears in the non-comment source"
fi
if match_lines '(<<[-~]?[A-Za-z_'"'"'"]|>>?[[:space:]]*[^[:space:];&|)]*)[^|;&]*repositories\.yaml' "$SRC_NOCOMMENT" "$OUT/helm-handwritten.txt"; then
  helm_reason="${helm_reason:+${helm_reason}; }the source writes repositories.yaml directly: $(summarise_file "$OUT/helm-handwritten.txt")"
fi
if [ -n "$helm_reason" ]; then
  fail "$CHK" "${helm_reason}. .helm/repositories.yaml is Helm's own internal format — it carries a 'generated' timestamp and per-entry cert/auth fields, and its shape has changed across major versions. Hand-writing it produces a file that looks right and is a forgery one Helm release later. Export HELM_REPOSITORY_CONFIG and HELM_REPOSITORY_CACHE and let 'helm repo add' write it."
else
  pass "$CHK" "the subject shells out to 'helm repo add' and never writes repositories.yaml itself"
fi

# ── 5. No verification fetch swallows its own result ─────────────────────────
# Pitfall 10 plus the project Error Handling rule: silent fallbacks convert a
# hard failure into silent corruption. A --verify pass whose fetches are
# '|| true'-ed reports success while routing nothing, which is the precise
# failure mode this gate exists to prevent.
CHK="$CHK_VERIFY_NO_SILENT_TRUE"
if match_lines '\|\|[[:space:]]*true' "$SRC_NOCOMMENT" "$OUT/or-true.txt"; then
  if match_lines '(curl|npm view|pip download|helm repo update|helm search)' "$OUT/or-true.txt" "$OUT/or-true-fetch.txt"; then
    fail "$CHK" "a verification fetch swallows its own result with '|| true' in ${SUBJECT}: $(summarise_file "$OUT/or-true-fetch.txt") — Pitfall 10 and the project Error Handling rule. An assertion that ignores its own failure IS the false-pass mechanism. Capture the status ('rc=0; curl … || rc=\$?') and report it."
  else
    pass "$CHK" "no '|| true' appears on any line that also performs a verification fetch"
  fi
else
  pass "$CHK" "no '|| true' appears anywhere in the non-comment source"
fi

# ── 6. ADR-009 wording wherever a TLS bypass is emitted ──────────────────────
# Conditional, and the one check that may legitimately report a skip: plan
# 24-04 decides whether the script touches the Docker daemon at all, and its A3
# verdict may be that it must not. Absent code is therefore not a defect. But
# if the subject DOES write daemon.json, ADR-009 governs the wording: the
# warning must name what the directive does, say that the change is
# machine-global rather than scoped to this repository, and say it must be
# removed once TLS is configured on the Nexus instance.
CHK="$CHK_DOCKER_DAEMON_WARNING"
if ! grep -q 'daemon\.json' "$SRC_NOCOMMENT"; then
  skip "$CHK" "${SUBJECT} contains no write to daemon.json — plan 24-04's A3 verdict may be that the Docker daemon must not be touched at all, so absent code here is by design and not a defect. This check binds only once such a write exists."
#
# The two wording assertions are WINDOWED on the `insecure-registries` mention
# rather than run over the whole file, and that is load-bearing rather than
# fussy: the pip writer emits its own ADR-009 removal sentence for
# trusted-host, so a whole-file search is satisfied by a sentence about a
# DIFFERENT directive and the Docker warning could be deleted entirely without
# turning this check red. Measured during this plan's mutation run. The window
# is generous (14 lines either side of the directive) because a warning block
# that is not adjacent to the directive it describes is not a warning.
elif ! grep -q 'insecure-registries' "$SUBJECT"; then
  fail "$CHK" "${SUBJECT} writes daemon.json but never names the 'insecure-registries' directive it is warning about. ADR-009 (docs/adr/adr009-tls-guidance.md in the blueprint repository) forbids presenting it as a neutral operational choice: it does not merely permit plain HTTP, it bypasses TLS for that registry entirely."
else
  adr_scope_ok=0
  adr_removal_ok=0
  grep -n 'insecure-registries' "$SUBJECT" | cut -d: -f1 > "$OUT/adr-anchors.txt"
  while read -r anchor; do
    win_start=$(( anchor - 14 )); [ "$win_start" -lt 1 ] && win_start=1
    sed -n "${win_start},$(( anchor + 14 ))p" "$SUBJECT" > "$OUT/adr-window.txt"
    win_scope=0
    win_removal=0
    grep -qiE '(machine-global|machine-wide|system-wide|every project on this machine|all repositories on this machine|not scoped to this repository)' "$OUT/adr-window.txt" && win_scope=1
    grep -qiE 'remov[a-z]*.*TLS' "$OUT/adr-window.txt" && win_removal=1
    if [ "$win_scope" = "1" ] && [ "$win_removal" = "1" ]; then
      adr_scope_ok=1
      adr_removal_ok=1
      break
    fi
    [ "$win_scope" = "1" ]   && adr_scope_ok=1
    [ "$win_removal" = "1" ] && adr_removal_ok=1
  done < "$OUT/adr-anchors.txt"
  adr_missing=()
  [ "$adr_scope_ok" = "1" ]   || adr_missing+=("no sentence beside the directive states that the change is machine-global rather than scoped to this repository")
  [ "$adr_removal_ok" = "1" ] || adr_missing+=("no sentence beside the directive states that it must be removed once TLS is configured on the Nexus instance")
  if [ "${#adr_missing[@]}" -gt 0 ]; then
    adr_reason="$(printf '%s; ' "${adr_missing[@]}")"
    fail "$CHK" "${SUBJECT} writes daemon.json but its warning is incomplete — ${adr_reason%; }. ADR-009 (docs/adr/adr009-tls-guidance.md in the blueprint repository) requires both, within 14 lines of the insecure-registries mention. A removal sentence elsewhere in the file describes a different directive and does not satisfy this."
  else
    pass "$CHK" "the daemon.json write carries the ADR-009 warning in full — the directive is named, and its machine-global scope and its removal once TLS is configured are both stated beside it"
  fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# BEHAVIOURAL ASSERTIONS
#
# Everything above reads the subject's source. Everything below RUNS it, inside
# throwaway git repositories under mktemp -d, and measures what it left behind.
# Source reading cannot catch a registry URL assembled correctly and written to
# the wrong file, and it cannot catch npm falling back to registry.npmjs.org
# because the fixture had no package.json for its local prefix to resolve
# against (24-RESEARCH.md Pattern 4 — measured; without package.json this whole
# section would measure nothing and report green).
#
# No fixture path is ever inside either repository working tree, and no fixture
# run is ever passed --docker-daemon.
# ═════════════════════════════════════════════════════════════════════════════

# Absolute, because every run below invokes the subject from a fixture dir.
SUBJECT_ABS="$(cd "$(dirname "$SUBJECT")" && pwd)/$(basename "$SUBJECT")"

# make_fixture: a throwaway repo. `git init` so the subject's
# `git rev-parse --show-toplevel` resolves; package.json so npm's local prefix
# resolves HERE rather than to some ancestor — Pattern 4.
make_fixture() {
  local d
  d="$(mktemp -d "$OUT/fixture.XXXXXX")"
  git -C "$d" init -q >> "$OUT/git-init.log" 2>&1
  printf '{\n  "name": "nexus-setup-gate-fixture",\n  "version": "1.0.0",\n  "private": true\n}\n' > "$d/package.json"
  printf '%s' "$d"
}

# run_subject <fixture> <logfile> [args…] — prints the subject's exit status.
# The four routing variables are UNSET for the run: an operator who has sourced
# a .nexus-env in this shell must not be able to skew the measurement. The npm
# cache is redirected into the scratch dir so the gate leaves nothing in ~/.npm.
run_subject() {
  local fix="$1" log="$2"
  shift 2
  local rc=0
  (
    cd "$fix"
    unset PIP_CONFIG_FILE HELM_REPOSITORY_CONFIG HELM_REPOSITORY_CACHE NEXUS_DOCKER_REGISTRY
    # The redirected cache is subshell-local ON PURPOSE — SC2030/SC2031 report
    # exactly that, and it is the property we want: the gate's own shell keeps
    # the operator's npm cache setting, while no fixture run writes into ~/.npm.
    # shellcheck disable=SC2030,SC2031
    export npm_config_cache="$OUT/npm-cache"
    bash "$SUBJECT_ABS" "$@"
  ) > "$log" 2>&1 || rc=$?
  printf '%s' "$rc"
}

# npm's OWN resolved view of the registry, from inside the fixture. This is the
# point of using jq rather than grepping .npmrc: writing a file is not the same
# as a client reading it (Pitfall 10), and only npm can say what npm reads.
npm_registry_in() {
  (
    cd "$1"
    unset PIP_CONFIG_FILE HELM_REPOSITORY_CONFIG HELM_REPOSITORY_CACHE NEXUS_DOCKER_REGISTRY
    # The redirected cache is subshell-local ON PURPOSE — SC2030/SC2031 report
    # exactly that, and it is the property we want: the gate's own shell keeps
    # the operator's npm cache setting, while no fixture run writes into ~/.npm.
    # shellcheck disable=SC2030,SC2031
    export npm_config_cache="$OUT/npm-cache"
    npm config list --json
  ) 2>/dev/null > "$OUT/npm-config.json"
  jq -r '.registry // ""' < "$OUT/npm-config.json"
}

# Trailing-slash-insensitive comparison. The contract shape carries the slash;
# npm is free to normalise, and a normalisation difference is not a defect.
strip_slash() {
  printf '%s' "${1%/}"
}

# digest: content fingerprint, or the literal ABSENT. A file that was absent
# before and is absent after is UNCHANGED, which is the whole point.
DIGEST_TOOL=""
if command -v shasum >/dev/null 2>&1; then
  DIGEST_TOOL="shasum"
elif command -v sha256sum >/dev/null 2>&1; then
  DIGEST_TOOL="sha256sum"
fi
digest() {
  if [ ! -e "$1" ]; then
    printf 'ABSENT'
    return 0
  fi
  case "$DIGEST_TOOL" in
    shasum)    shasum -a 256 < "$1" | awk '{print $1}' ;;
    sha256sum) sha256sum    < "$1" | awk '{print $1}' ;;
    *)         printf 'NO-DIGEST-TOOL' ;;
  esac
}

# ── The loopback Helm stub ───────────────────────────────────────────────────
# `helm repo add` is NOT an offline operation: Helm fetches index.yaml during
# `repo add` and errors on an unreachable repository, with no --no-update
# escape. A fixture run against a hostname that does not resolve therefore dies
# at the Helm writer, and every assertion that needs a COMPLETED run would go
# red for the wrong reason. So the runs that need a completed subject get a
# real repository to talk to: a python3 http.server over a temp directory
# holding an empty-but-valid index.yaml. Measured accepted by helm v4.3.0.
# Loopback also keeps the third pip case honest, since pip's SECURE_ORIGINS
# already trusts 127.0.0.0/8.
STUB_PORT=""
STUB_URL=""
start_stub() {
  local root="$OUT/helm-stub"
  mkdir -p "$root/repository/helm-proxy"
  printf 'apiVersion: v1\nentries: {}\ngenerated: "2026-01-01T00:00:00Z"\n' \
    > "$root/repository/helm-proxy/index.yaml"
  STUB_PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  ( cd "$root" && exec python3 -m http.server "$STUB_PORT" --bind 127.0.0.1 ) >/dev/null 2>&1 &
  STUB_PID=$!
  local i=0
  while [ "$i" -lt 100 ]; do
    # Readiness is polled on the listening socket rather than slept for; a
    # fixed sleep is either slower than it needs to be or flaky, never both
    # right. The tolerated non-zero is the connection refusal we are polling
    # FOR, not a swallowed assertion.
    if (exec 3<>"/dev/tcp/127.0.0.1/${STUB_PORT}") >/dev/null 2>&1; then
      exec 3>&- 2>/dev/null || true   # closing a descriptor that may not be open
      STUB_URL="http://127.0.0.1:${STUB_PORT}"
      return 0
    fi
    i=$((i + 1))
    sleep 0.1
  done
  return 1
}

# ── Tiers ────────────────────────────────────────────────────────────────────
# NPM tier: the subject writes .npmrc first, so without npm it cannot reach the
# pip writer either and no fixture assertion is measurable.
# FULL tier: additionally needs helm and a served stub, because those checks
# read files the subject only writes after `helm repo add` returns.
MISSING_NPM_TIER=""
[ "$HAVE_NPM" = "1" ] || MISSING_NPM_TIER="npm"

MISSING_FULL_TIER="$MISSING_NPM_TIER"
[ "$HAVE_HELM" = "1" ]    || MISSING_FULL_TIER="${MISSING_FULL_TIER:+${MISSING_FULL_TIER}, }helm"
[ "$HAVE_PYTHON3" = "1" ] || MISSING_FULL_TIER="${MISSING_FULL_TIER:+${MISSING_FULL_TIER}, }python3"

if [ -z "$MISSING_FULL_TIER" ]; then
  if ! start_stub; then
    MISSING_FULL_TIER="a served loopback Helm stub (python3 -m http.server never became reachable)"
  fi
fi

# The loopback URL used for the third pip case. The stub port when there is a
# stub; otherwise a closed loopback port, which is still loopback and still
# exercises the SECURE_ORIGINS branch, since pip.conf is written before the
# subject reaches the Helm writer.
LOOPBACK_URL="${STUB_URL:-http://127.0.0.1:1}"

# ── Global-config snapshot, taken BEFORE any fixture run ─────────────────────
GLOBAL_HELM_CFG=""
GLOBAL_NPM_USERCONFIG=""
GLOBAL_DOCKER_DAEMON="${HOME}/.docker/daemon.json"
GLOBAL_HELM_BEFORE=""
GLOBAL_NPM_BEFORE=""
GLOBAL_DOCKER_BEFORE=""
if [ -z "$MISSING_FULL_TIER" ] && [ -n "$DIGEST_TOOL" ]; then
  GLOBAL_HELM_CFG="$(helm env HELM_REPOSITORY_CONFIG | tr -d '"')"
  GLOBAL_NPM_USERCONFIG="$(npm config get userconfig)"
  GLOBAL_HELM_BEFORE="$(digest "$GLOBAL_HELM_CFG")"
  GLOBAL_NPM_BEFORE="$(digest "$GLOBAL_NPM_USERCONFIG")"
  GLOBAL_DOCKER_BEFORE="$(digest "$GLOBAL_DOCKER_DAEMON")"
fi

# ── Fixture runs ─────────────────────────────────────────────────────────────
# Seeded at runtime from /dev/urandom, never a literal: gitleaks runs over this
# repository as a pre-push hook, and a committed token-shaped literal is a real
# finding, not a test detail.
NPMRC_AUTH_LINE=""
FIX_TOKEN=""
FIX_HTTP=""
FIX_LOOP=""
FIX_STUB=""
FIX_VERIFY=""
RC_STUB=""
RC_VERIFY=""

if [ -z "$MISSING_NPM_TIER" ]; then
  NPMRC_AUTH_LINE="//registry.example.com/:_authToken=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')"

  # Run B — https, a hostname that does not resolve. Expected to end non-zero
  # at the Helm writer; only the files written before that point are asserted.
  FIX_TOKEN="$(make_fixture)"
  printf '%s\nsave-exact=true\n' "$NPMRC_AUTH_LINE" > "${FIX_TOKEN}/.npmrc"
  run_subject "$FIX_TOKEN" "$OUT/run-token.log" --url https://nexus.example.com > /dev/null

  # Run C — plain http to a NON-loopback host. Same expectation.
  FIX_HTTP="$(make_fixture)"
  run_subject "$FIX_HTTP" "$OUT/run-http.log" --url http://nexus.example.com > /dev/null

  # Run D — plain http to loopback.
  FIX_LOOP="$(make_fixture)"
  run_subject "$FIX_LOOP" "$OUT/run-loop.log" --url "$LOOPBACK_URL" > /dev/null
fi

if [ -z "$MISSING_FULL_TIER" ]; then
  # Run A — the happy path against the stub. This one must complete.
  FIX_STUB="$(make_fixture)"
  RC_STUB="$(run_subject "$FIX_STUB" "$OUT/run-stub.log" --url "$STUB_URL")"

  # Run E — --verify against the same stub. The stub serves the Helm index and
  # NOTHING else, so `helm repo add` succeeds, the write phase completes, and
  # the npm and pip verification fetches 404. That is a real verify-phase
  # failure. Pointing --verify at a closed port instead would kill the subject
  # at `helm repo add` and the non-zero exit would prove nothing about verify.
  FIX_VERIFY="$(make_fixture)"
  RC_VERIFY="$(run_subject "$FIX_VERIFY" "$OUT/run-verify.log" --url "$STUB_URL" --verify)"
fi

# ── 7. The .npmrc merge preserves what was already there ─────────────────────
# 24-W0-14. Three assertions, one verdict.
CHK="$CHK_NPMRC_MERGE"
if [ -n "$MISSING_NPM_TIER" ]; then
  skip "$CHK" "requires ${MISSING_NPM_TIER}, which is not on PATH — not run, and therefore NOT passed"
elif [ ! -f "${FIX_TOKEN}/.npmrc" ]; then
  fail "$CHK" "the subject left no .npmrc in the fixture at all: $(summarise_file "$OUT/run-token.log")"
else
  merge_reason=""
  grep -Fqx "$NPMRC_AUTH_LINE" "${FIX_TOKEN}/.npmrc" \
    || merge_reason="the seeded //registry.example.com/:_authToken line did not survive byte-identically"
  grep -Fqx 'save-exact=true' "${FIX_TOKEN}/.npmrc" \
    || merge_reason="${merge_reason:+${merge_reason}; }the seeded save-exact=true line did not survive"
  observed_registry="$(npm_registry_in "$FIX_TOKEN")"
  expected_registry="https://nexus.example.com/repository/npm-proxy/"
  if [ "$(strip_slash "$observed_registry")" != "$(strip_slash "$expected_registry")" ]; then
    merge_reason="${merge_reason:+${merge_reason}; }npm resolves registry to '${observed_registry}', expected '${expected_registry}'"
  fi
  if [ -n "$merge_reason" ]; then
    fail "$CHK" "${merge_reason}. Pitfall 7: a developer's .npmrc may carry the only copy of a private-registry credential, and destroying it is a credential-loss bug with no error message. Observed file: $(summarise_file "${FIX_TOKEN}/.npmrc")"
  else
    pass "$CHK" "the seeded auth-token and save-exact lines both survived and npm resolves the registry to ${observed_registry}"
  fi
fi

# ── 8. The Docker prefix has no /repository/ segment ─────────────────────────
# 24-W0-13. Asserted on the emitted NEXUS_DOCKER_REGISTRY line ONLY — never by
# grepping the whole subject. If plan 24-04's A3 verdict turns out positive, a
# daemon.json mirror URL legitimately carries that segment, and a whole-file
# search would fight correct code.
CHK="$CHK_DOCKER_PREFIX_SHAPE"
if [ -n "$MISSING_FULL_TIER" ]; then
  skip "$CHK" "requires ${MISSING_FULL_TIER} — the .nexus-env it reads is written after 'helm repo add' returns, so no completed run was available. Not passed."
elif [ ! -f "${FIX_STUB}/.nexus-env" ]; then
  fail "$CHK" "the subject completed with status ${RC_STUB} but left no .nexus-env: $(summarise_file "$OUT/run-stub.log")"
elif ! match_lines '^export NEXUS_DOCKER_REGISTRY=' "${FIX_STUB}/.nexus-env" "$OUT/docker-line.txt"; then
  fail "$CHK" ".nexus-env carries no 'export NEXUS_DOCKER_REGISTRY=' line. Docker has no per-repository config of any kind, so this string is the ONLY lever a developer has. Observed: $(summarise_file "${FIX_STUB}/.nexus-env")"
else
  docker_line="$(sed -n 's/^[0-9]*://p' "$OUT/docker-line.txt")"
  shape_reason=""
  case "$docker_line" in
    *"127.0.0.1:${STUB_PORT}"*) : ;;
    *) shape_reason="it does not carry the host 127.0.0.1:${STUB_PORT} the run was given" ;;
  esac
  case "$docker_line" in
    *docker-proxy*) : ;;
    *) shape_reason="${shape_reason:+${shape_reason}; }it does not name the docker-proxy repository" ;;
  esac
  case "$docker_line" in
    *"/repository/"*) shape_reason="${shape_reason:+${shape_reason}; }it carries a /repository/ segment" ;;
    *) : ;;
  esac
  if [ -n "$shape_reason" ]; then
    fail "$CHK" "the emitted line is '${docker_line}' and ${shape_reason}. Measured (24-RESEARCH.md Pattern 6): the Docker client inserts /v2/ immediately after the host, so the repository name must be the FIRST path segment. /v2/repository/docker-proxy/… returns 404, and while /repository/docker-proxy/v2/… does return 200, no Docker client can be made to emit that shape — it is a curl URL only. Docker is the one ecosystem of the four where the /repository/ prefix is wrong."
  else
    pass "$CHK" "the emitted prefix is '${docker_line}' — host present, docker-proxy named, no /repository/ segment"
  fi
fi

# ── 9. trusted-host only when it is actually needed ──────────────────────────
# Verified from pip's own source (pip/_internal/network/session.py):
# SECURE_ORIGINS already contains ("*","localhost","*") and ("*","127.0.0.0/8",
# "*"). So http:// to a NON-loopback host needs trusted-host; to loopback it
# does not; and setting it on an https:// URL is a needless downgrade of a real
# certificate check. Three runs, three assertions, one verdict.
CHK="$CHK_PIP_TRUSTED_HOST"
if [ -n "$MISSING_NPM_TIER" ]; then
  skip "$CHK" "requires ${MISSING_NPM_TIER}, which is not on PATH — the subject writes .npmrc before pip.conf, so no pip.conf was produced. Not passed."
elif [ ! -f "${FIX_TOKEN}/pip.conf" ] || [ ! -f "${FIX_HTTP}/pip.conf" ] || [ ! -f "${FIX_LOOP}/pip.conf" ]; then
  fail "$CHK" "one or more runs left no pip.conf — https:$([ -f "${FIX_TOKEN}/pip.conf" ] && echo present || echo ABSENT) http-nonloopback:$([ -f "${FIX_HTTP}/pip.conf" ] && echo present || echo ABSENT) http-loopback:$([ -f "${FIX_LOOP}/pip.conf" ] && echo present || echo ABSENT). pip.conf must be written BEFORE 'helm repo add', because two of these runs deliberately end non-zero at the Helm writer."
else
  th_reason=""
  if grep -q 'trusted-host' "${FIX_TOKEN}/pip.conf"; then
    th_reason="an https:// URL produced a trusted-host directive, which disables certificate verification for that host and downgrades a check that was working"
  fi
  if ! grep -q 'trusted-host' "${FIX_HTTP}/pip.conf"; then
    th_reason="${th_reason:+${th_reason}; }plain http:// to a non-loopback host produced NO trusted-host directive, so pip will refuse the index outright"
  elif ! grep -qiE 'remov[a-z]*.*TLS' "${FIX_HTTP}/pip.conf"; then
    th_reason="${th_reason:+${th_reason}; }the trusted-host directive was emitted without the ADR-009 sentence saying it must be removed once TLS is configured"
  fi
  if grep -q 'trusted-host' "${FIX_LOOP}/pip.conf"; then
    th_reason="${th_reason:+${th_reason}; }http:// to loopback produced a trusted-host directive, but pip's SECURE_ORIGINS already trusts localhost and 127.0.0.0/8, so it buys nothing and teaches the wrong habit"
  fi
  if [ -n "$th_reason" ]; then
    fail "$CHK" "${th_reason}. ADR-009 (docs/adr/adr009-tls-guidance.md in the blueprint repository) governs every emission of this directive."
  else
    pass "$CHK" "trusted-host appears only for plain http to a non-loopback host, and carries the ADR-009 removal sentence when it does"
  fi
fi

# ── 10. The env file exports exactly the four variables, and says so ─────────
# Pattern 5. npm needs no environment at all; pip and Helm work ONLY if this
# file is sourced; Docker works only if someone edits an image reference. A
# script that does not say that has produced the silent-corruption failure the
# project's rules exist to prevent.
CHK="$CHK_NEXUS_ENV_EXPORTS"
if [ -n "$MISSING_FULL_TIER" ]; then
  skip "$CHK" "requires ${MISSING_FULL_TIER} — .nexus-env is written after 'helm repo add' returns, so no completed run was available. Not passed."
elif [ ! -f "${FIX_STUB}/.nexus-env" ]; then
  fail "$CHK" "the subject exited ${RC_STUB} and left no .nexus-env: $(summarise_file "$OUT/run-stub.log")"
else
  sed -n 's/^export \([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "${FIX_STUB}/.nexus-env" | sort -u > "$OUT/env-names.txt"
  printf 'HELM_REPOSITORY_CACHE\nHELM_REPOSITORY_CONFIG\nNEXUS_DOCKER_REGISTRY\nPIP_CONFIG_FILE\n' > "$OUT/env-names-expected.txt"
  env_reason=""
  if ! cmp -s "$OUT/env-names.txt" "$OUT/env-names-expected.txt"; then
    env_reason="it exports [$(tr '\n' ' ' < "$OUT/env-names.txt")] rather than exactly [PIP_CONFIG_FILE HELM_REPOSITORY_CONFIG HELM_REPOSITORY_CACHE NEXUS_DOCKER_REGISTRY]"
  fi
  grep -qi 'source' "${FIX_STUB}/.nexus-env" \
    || env_reason="${env_reason:+${env_reason}; }its header never says the file is to be sourced"
  grep -qiE '(do not|don.t|never) execute' "${FIX_STUB}/.nexus-env" \
    || env_reason="${env_reason:+${env_reason}; }its header never says the file must not be executed"
  grep -q 'PIP_CONFIG_FILE' "${FIX_STUB}/.nexus-env" \
    || env_reason="${env_reason:+${env_reason}; }it never mentions PIP_CONFIG_FILE"
  if ! grep -qi 'user' "${FIX_STUB}/.nexus-env" \
     || ! grep -qiE '(replac|no longer|suppress|override|instead of)' "${FIX_STUB}/.nexus-env"; then
    env_reason="${env_reason:+${env_reason}; }it never states the Pitfall 8 consequence — with PIP_CONFIG_FILE set, 'pip config list -v' no longer lists EITHER user-scope variant, so the developer's own pip settings (a corporate CA bundle, an extra-index-url) silently stop applying in that shell"
  fi
  if [ -n "$env_reason" ]; then
    fail "$CHK" "${env_reason}. Observed: $(summarise_file "${FIX_STUB}/.nexus-env")"
  else
    pass "$CHK" "the env file exports exactly the four contracted variables and states both the sourcing requirement and the PIP_CONFIG_FILE user-scope consequence"
  fi
fi

# ── 11. The operator's machine is not mutated ────────────────────────────────
# This gate runs on a developer workstation. A gate that edits the operator's
# global Helm repository list, user .npmrc or Docker daemon config to do its
# job has done more damage than the defect it was looking for.
CHK="$CHK_GLOBAL_CONFIG_UNTOUCHED"
if [ -n "$MISSING_FULL_TIER" ]; then
  skip "$CHK" "requires ${MISSING_FULL_TIER} — no fixture run completed, so there is nothing to compare. Not passed."
elif [ -z "$DIGEST_TOOL" ]; then
  skip "$CHK" "neither shasum nor sha256sum is on PATH, so before/after fingerprints could not be taken. Not passed."
else
  global_reason=""
  helm_after="$(digest "$GLOBAL_HELM_CFG")"
  npm_after="$(digest "$GLOBAL_NPM_USERCONFIG")"
  docker_after="$(digest "$GLOBAL_DOCKER_DAEMON")"
  [ "$helm_after" = "$GLOBAL_HELM_BEFORE" ] \
    || global_reason="the operator's Helm repository config ${GLOBAL_HELM_CFG} changed (${GLOBAL_HELM_BEFORE} -> ${helm_after})"
  [ "$npm_after" = "$GLOBAL_NPM_BEFORE" ] \
    || global_reason="${global_reason:+${global_reason}; }the operator's npm userconfig ${GLOBAL_NPM_USERCONFIG} changed (${GLOBAL_NPM_BEFORE} -> ${npm_after})"
  [ "$docker_after" = "$GLOBAL_DOCKER_BEFORE" ] \
    || global_reason="${global_reason:+${global_reason}; }${GLOBAL_DOCKER_DAEMON} changed (${GLOBAL_DOCKER_BEFORE} -> ${docker_after})"
  if [ -n "$global_reason" ]; then
    fail "$CHK" "${global_reason}. This gate must never mutate the operator's machine: fixtures live under mktemp -d only, no run is ever passed --docker-daemon, and the subject must scope its Helm writes with HELM_REPOSITORY_CONFIG rather than touching the global list."
  else
    pass "$CHK" "the operator's Helm repository config, npm userconfig and ~/.docker/daemon.json are all byte-unchanged across every fixture run"
  fi
fi

# ── 12. --verify fails loudly when nothing is reachable ──────────────────────
# Pitfall 10 in its pure form: four files written, "Setup complete" printed,
# and every client still going to the public internet. The stub serves the Helm
# index and nothing else, so the write phase completes and the npm and pip
# fetches 404 — a genuine verify-phase failure rather than a run that died
# earlier for an unrelated reason.
CHK="$CHK_VERIFY_FAILS_LOUDLY"
if [ -n "$MISSING_FULL_TIER" ]; then
  skip "$CHK" "requires ${MISSING_FULL_TIER} — without the stub, a --verify run cannot be distinguished from a run that died at the Helm writer. Not passed."
elif [ "$RC_VERIFY" = "0" ]; then
  fail "$CHK" "--verify exited 0 against a URL serving nothing but the Helm index — the npm and pip fetches cannot have succeeded, so this is a success report over a routing failure. Output: $(summarise_file "$OUT/run-verify.log")"
elif ! grep -qiE '(npm|pip)' "$OUT/run-verify.log"; then
  fail "$CHK" "--verify exited ${RC_VERIFY}, which is correct, but its output names no ecosystem — a developer cannot tell which client is still going to the public internet. Output: $(summarise_file "$OUT/run-verify.log")"
else
  pass "$CHK" "--verify exited ${RC_VERIFY} with unreachable npm and pip indexes and named the failing ecosystem"
fi

print_summary
