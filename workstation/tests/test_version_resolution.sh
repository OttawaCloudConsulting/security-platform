# shellcheck shell=bash
# shellcheck disable=SC1090  # SETUP_SH is exported by run-tests.sh at a known path
# test_version_resolution.sh — Fixture-driven, offline unit tests for
# gh_api_get(), resolve_latest_version(), and resolve_latest_in_major().
#
# Sourced by run-tests.sh — do not `exit`, do not re-declare helpers, do not
# `set -e` in this file (see the isolation contract in run-tests.sh).
#
# Zero-network guarantee: every subshell below that exercises code reachable
# from gh_api_get() defines a `curl` tripwire that fails loudly if reached,
# and unsets GITHUB_TOKEN/GH_TOKEN plus stubs `gh` so a developer's real
# credentials are never resolved or leaked into assertion output.

describe "gh_api_get: token handling (no live network)"

# No token available anywhere: no Authorization header is sent, no crash.
out=$(
  (
    source "$SETUP_SH"
    set +e
    unset GITHUB_TOKEN GH_TOKEN
    # shellcheck disable=SC2329  # stub redefines gh_api_get's token-resolution dependency
    gh() { return 1; }
    # shellcheck disable=SC2329  # stub redefines gh_api_get's curl dependency for argv capture
    curl() {
      for a in "$@"; do
        if [[ "$a" == Authorization:* ]]; then
          echo "HEADER:$a"
        fi
      done
      echo "CURL_OK"
    }
    gh_api_get "https://example.invalid/x"
    echo "rc=$?"
  ) 2>&1
)
assert_contains "$out" "CURL_OK" "gh_api_get with no token still invokes curl and succeeds"
assert_not_contains "$out" "HEADER:" "gh_api_get with no token sends no Authorization header"
assert_contains "$out" "rc=0" "gh_api_get with no token returns success"

# A token is present: it appears in a -H header argument, never in the URL.
out=$(
  (
    source "$SETUP_SH"
    set +e
    unset GH_TOKEN
    export GITHUB_TOKEN="NOT-A-REAL-TOKEN-TEST"
    # shellcheck disable=SC2329  # stub redefines gh_api_get's token-resolution dependency
    gh() { return 1; }
    # shellcheck disable=SC2329  # stub redefines gh_api_get's curl dependency for argv capture
    curl() {
      local prev="" last=""
      for a in "$@"; do
        if [[ "$prev" = "-H" ]]; then
          echo "HEADER:$a"
        fi
        prev="$a"
        last="$a"
      done
      echo "URL:$last"
    }
    gh_api_get "https://example.invalid/x"
  ) 2>&1
)
assert_contains "$out" "HEADER:Authorization: Bearer NOT-A-REAL-TOKEN-TEST" "gh_api_get sends the token as an Authorization header"
assert_not_contains "$out" "URL:https://example.invalid/xNOT-A-REAL-TOKEN-TEST" "gh_api_get never appends the token to the URL"
case "$out" in
  *"URL:"*"NOT-A-REAL-TOKEN-TEST"*) fail "gh_api_get token leaked into the URL argument" ;;
  *) pass "gh_api_get token argument stays out of the URL argument" ;;
esac

describe "gh_api_get: sourcing has no side effects"

source_out=$( ( source "$SETUP_SH"; set +e; echo "SOURCED_OK" ) 2>&1 )
assert_eq "SOURCED_OK" "$source_out" "sourcing setup.sh does not shell out to gh or curl"

describe "resolve_latest_version: compact JSON (hadolint-style)"

out=$(
  (
    source "$SETUP_SH"
    set +e
    unset GITHUB_TOKEN GH_TOKEN
    # shellcheck disable=SC2329  # stub redefines gh_api_get's token-resolution dependency
    gh() { return 1; }
    # shellcheck disable=SC2329  # tripwire: fails the test loudly if a live network call is attempted
    curl() { echo "LIVE CURL ATTEMPTED" >&2; return 22; }
    # shellcheck disable=SC2329  # stub replaces the network boundary with a fixture read
    gh_api_get() { cat "$FIXTURES_DIR/hadolint-releases-compact.json"; }
    v=$(resolve_latest_version "hadolint/hadolint")
    echo "rc=$?"
    echo "v=$v"
  ) 2>&1
)
assert_contains "$out" "v=2.15.1" "resolve_latest_version extracts 2.15.1 from compact JSON"
assert_not_contains "$out" "LIVE CURL ATTEMPTED" "resolve_latest_version (compact) never calls curl directly"

describe "resolve_latest_version: spaced JSON (gitleaks-style)"

out=$(
  (
    source "$SETUP_SH"
    set +e
    unset GITHUB_TOKEN GH_TOKEN
    # shellcheck disable=SC2329  # stub redefines gh_api_get's token-resolution dependency
    gh() { return 1; }
    # shellcheck disable=SC2329  # tripwire: fails the test loudly if a live network call is attempted
    curl() { echo "LIVE CURL ATTEMPTED" >&2; return 22; }
    # shellcheck disable=SC2329  # stub replaces the network boundary with a fixture read
    gh_api_get() { cat "$FIXTURES_DIR/gitleaks-releases-spaced.json"; }
    v=$(resolve_latest_version "gitleaks/gitleaks")
    echo "rc=$?"
    echo "v=$v"
  ) 2>&1
)
assert_contains "$out" "v=8.30.1" "resolve_latest_version extracts 8.30.1 from spaced JSON"
assert_not_contains "$out" "LIVE CURL ATTEMPTED" "resolve_latest_version (spaced) never calls curl directly"

describe "resolve_latest_version: empty body is a visible, non-fatal failure"

out=$(
  (
    source "$SETUP_SH"
    set +e
    unset GITHUB_TOKEN GH_TOKEN
    # shellcheck disable=SC2329  # stub redefines gh_api_get's token-resolution dependency
    gh() { return 1; }
    # shellcheck disable=SC2329  # tripwire: fails the test loudly if a live network call is attempted
    curl() { echo "LIVE CURL ATTEMPTED" >&2; return 22; }
    # shellcheck disable=SC2329  # stub simulates an empty/rate-limited API body
    gh_api_get() { printf ''; }
    v=$(resolve_latest_version "any/repo")
    echo "rc=$?"
    echo "v=[$v]"
    echo "SURVIVED"
  ) 2>&1
)
assert_contains "$out" "rc=1" "resolve_latest_version returns exit status 1 on an empty body"
assert_contains "$out" "v=[]" "resolve_latest_version echoes nothing on an empty body"
assert_contains "$out" "rate-limited" "resolve_latest_version warns about rate limiting on an empty body"
assert_contains "$out" "SURVIVED" "the calling shell survives an empty-body resolution failure"

describe "resolve_latest_version: does not kill a set -e caller (bare call)"

bare_out=$(/bin/bash -euo pipefail -c "
  source '$SETUP_SH'
  gh() { return 1; }
  curl() { echo 'LIVE CURL ATTEMPTED' >&2; return 22; }
  gh_api_get() { printf ''; }
  resolve_latest_version any/repo
  echo UNREACHABLE
" 2>&1)
bare_rc=$?
assert_contains "$bare_out" "rate-limited" "a bare (unguarded) call still emits the rate-limit warning"
assert_not_contains "$bare_out" "UNREACHABLE" "the function's own return 1 stops execution at the call site as expected"
assert_status 1 "$bare_rc" "a bare call to resolve_latest_version on an empty body exits the process with status 1, not a pipefail SIGPIPE crash"
