#!/usr/bin/env bash
set -euo pipefail

# nexus-setup.sh — point ONE repository's package-manager clients at a Nexus
#
# Usage:
#   bash workstation/nexus-setup.sh --url https://nexus.example.com
#   bash workstation/nexus-setup.sh --url http://127.0.0.1:8081 --force
#   bash workstation/nexus-setup.sh --help
#
# WHAT THIS DOES, AND WHAT "PER-REPO" ACTUALLY MEANS.
# "Per-repository configuration" is four different things across the four
# ecosystems, and for one of them it is nothing at all:
#
#   npm    HAS a native project scope. .npmrc at the repository root is read
#          with no environment variable set, by any npm invocation inside the
#          repository. This is the only one of the four that just works.
#   pip    has NO project scope. pip enumerates exactly four candidate config
#          paths (global, two user variants, site) and none of them is
#          cwd-relative. A repo-local pip.conf is inert until PIP_CONFIG_FILE
#          points at it.
#   Helm   has NO project scope either. A repo-local repositories.yaml is inert
#          until HELM_REPOSITORY_CONFIG points at it.
#   Docker has no per-repository mechanism of ANY kind. Mirrors and insecure
#          registries are daemon-global keys, and DOCKER_CONFIG redirects only
#          the client's auth file. All this script can honestly give you is a
#          registry prefix string to paste into an image reference.
#
# So the env file this script writes is not a convenience — it is the mechanism
# for two of the three ecosystems it configures. npm works with no environment
# at all; pip and Helm work ONLY if .nexus-env has been sourced; Docker works
# only if a human edits an image reference.
#
# THE npm LOCAL-PREFIX SUBTLETY, which makes a correct run look like a no-op.
# npm reads .npmrc from its LOCAL PREFIX — the nearest ancestor directory
# containing package.json or node_modules — not from the current directory and
# not from the git root. Measured: in a tree with no package.json anywhere up
# the chain, npm falls back to https://registry.npmjs.org/ and this script
# appears to have done nothing. The script warns when that applies.
#
# WRITE SCOPE. Everything this script writes lands inside the target repository
# (git rev-parse --show-toplevel). It never edits the operator's global npm
# config, global Helm repository list, or any machine-wide daemon configuration.
#
# FILE MODE — copy the code, not the mode. workstation/setup.sh, the analog this
# script's scaffolding comes from, is mode 755 in this tree, which violates the
# project's Script Safety rule (scripts are invoked as 'bash <path>' so the
# interpreter is never chosen by a shebang). This file ships NON-EXECUTABLE on
# purpose. Do not "fix" it to match its analog: scripts/check-nexus-setup.sh
# asserts the absence of the executable bit and will go red.
#
# DO NOT `source` workstation/setup.sh to reuse its helpers. It runs its main
# body at load — argument parsing and command dispatch sit at file scope with no
# main() guard — so sourcing it would execute a tool installer. The four logging
# functions and write_config below are COPIED from it, deliberately.
#
# DOCKER, AND THE ONE THING THIS SCRIPT WRITES OUTSIDE THE REPOSITORY.
# The branch implemented below is `daemon-opt-in`, selected by the operator at
# plan 24-04's checkpoint with the A3 measurement in front of them. The
# measurement that justifies it, verbatim from
# .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-evidence/a3-docker-daemon-routing.md:
#
#   VERDICT: A3-FALSIFIED-CANDIDATE-1
#
# Read precisely: a path-routed Nexus Docker proxy CAN serve as a Docker daemon
# `registry-mirrors` target, at the `/repository/<repo>` URL and ONLY at that
# URL. The measurement is a components delta on the Nexus side, not a pull exit
# code: the other candidate, `HOST/<repo>` — the shape that looks right because
# it is the image-REFERENCE shape — produced `docker pull` exit 0 with real
# layer traffic and ZERO components in Nexus, because Docker silently fell back
# to Docker Hub. A mirror that does not route is invisible.
#
# Three consequences this file is built around:
#   * the mirror URL carries `/repository/`; the NEXUS_DOCKER_REGISTRY prefix in
#     .nexus-env does NOT. They are different URLs for different consumers and
#     must not be "unified".
#   * only docker.io references are ever mirrored. Confirmed from
#     version-matched moby source, not from the probe: mirrors are attached to
#     the Docker Hub index and to no other. ghcr.io, quay.io, public.ecr.aws and
#     every other registry are untouched by any registry-mirrors value.
#   * the whole path sits behind --docker-daemon, OFF by default, because it is
#     machine-global and this script is otherwise scoped to one repository.
#
# KNOWN INPUT LIMITATION. The --url validator below rejects bracketed IPv6
# literals ('[::1]:8081'), because the conservative character class that keeps
# shell metacharacters out of a string destined for config files also excludes
# '[' and ']'. Use a hostname or an IPv4 address. This is a deliberate trade:
# an over-permissive validator on an argument that is interpolated into files
# clients obey is the worse failure.

# ---------------------------------------------------------------------------
# Constants and state
# ---------------------------------------------------------------------------

VERBOSE=false
FORCE=false
COMMIT_CONFIG=false

# --docker-daemon: the `daemon-opt-in` branch, OFF by default. See the header.
# Everything else this script writes lands inside the target repository; this
# one flag is the single exception, and it is machine-global.
DOCKER_DAEMON=false

# --verify: the mandatory proof pass. Configuration runs first and --verify
# then measures, per ecosystem, whether a client actually reaches this Nexus.
# Running it against an ALREADY-configured repository is the same invocation:
# the writers leave existing files alone without --force, so a second run with
# --verify verifies rather than rewrites.
VERIFY=false

# Raw --url as the operator typed it, before validation. Empty means "not
# supplied", which is an error and never a guess.
NEXUS_URL_RAW=""

# Derived by validate_url(), and the only forms the rest of the script may use:
#   NEXUS_SCHEME       'http' or 'https'
#   NEXUS_URL          scheme://host[:port][/path], no trailing slash — used to
#                      build the three /repository/... URLs
#   NEXUS_HOST         host[:port], no scheme — used for the Docker prefix
#   NEXUS_HOST_NO_PORT host only, used for pip's trusted-host decision
#   NEXUS_PATH         any path component of --url, '' when there is none
#   NEXUS_IS_LOOPBACK  1 when the host is one pip's SECURE_ORIGINS already
#                      trusts over plain HTTP
NEXUS_SCHEME=""
NEXUS_URL=""
NEXUS_HOST=""
NEXUS_HOST_NO_PORT=""
NEXUS_PATH=""
NEXUS_IS_LOOPBACK=0

# Counters, following workstation/setup.sh's convention: CONFIG_COUNT is
# incremented by write_config, FAIL_COUNT drives the exit status at the end.
CONFIG_COUNT=0
FAIL_COUNT=0

# Per-ecosystem outcome, printed verbatim in the end-of-run report. The default
# is the pessimistic one: a row that was never reached reads "not configured",
# never "ok".
NPM_STATUS="not configured (writer never ran)"
PIP_STATUS="not configured (writer never ran)"
HELM_STATUS="not configured (writer never ran)"
GITIGNORE_STATUS="not touched (writer never ran)"

# Docker is never "configured" by this script and the report must never imply
# it. The string is a constant for that reason.
DOCKER_STATUS="MANUAL — no per-repository configuration exists; .nexus-env exports a prefix string and nothing routes until an image reference is edited to use it"

# The machine-global daemon write reports on its own row, separate from the
# docker row above, because the two are different things: one is a repository's
# routing (which does not exist for Docker) and the other is a workstation-wide
# setting that this script only touches when asked.
DOCKER_DAEMON_STATUS="not touched (--docker-daemon was not given)"
DOCKER_DAEMON_FILE="${HOME}/.docker/daemon.json"

# The repository entry name written into .helm/repositories.yaml. Stable, so a
# re-run updates one entry rather than accumulating them.
HELM_REPO_NAME="nexus"

# The four Nexus repository names, which are the chart's shipped defaults
# (kubernetes/nexus/values.yaml: repos.<eco>.name). Held in constants so the
# writers and the --verify probes below cannot drift apart: a verification that
# fetched from a different repository than the one configured would be measuring
# nothing.
NPM_REPO="npm-proxy"
PYPI_REPO="pypi-proxy"
HELM_REPO="helm-proxy"
DOCKER_REPO="docker-proxy"

# The sample artefacts --verify fetches. They are overridable because they name
# specific upstream packages: a package can be yanked, and a verification pass
# that then reports a routing failure would be lying about the cause.
#
# npm is split into name and version rather than held as one 'name@version'
# spec, because the diagnostic probe below has to build the tarball's component
# URL ('<name>/-/<name>-<version>.tgz') from the same two values. A floating
# spec would leave the licence-refusal diagnosis with no component URL to probe.
VERIFY_NPM_NAME="${NEXUS_VERIFY_NPM_NAME:-lodash}"
VERIFY_NPM_VERSION="${NEXUS_VERIFY_NPM_VERSION:-4.17.21}"
VERIFY_PIP_PACKAGE="${NEXUS_VERIFY_PIP_PACKAGE:-six}"

# Rows of the --verify status table, one per ecosystem, each
# 'ecosystem|mechanism|status|observed'. A row is appended by verify_row(),
# which is also the ONLY place FAIL_COUNT is incremented during verification —
# so a status that is neither 'ok' nor 'MANUAL' cannot reach the table without
# also reaching the exit code.
VERIFY_ROWS=()
VERIFY_OK=0
VERIFY_BAD=0
VERIFY_MANUAL=0

# Appended to the docker row of the --verify table. It is a variable rather
# than a literal so that the row can report what else happened on this run
# without the row ever becoming a pass.
DOCKER_VERIFY_NOTE=""

# Set by probe_url(). PROBE_RC is curl's own exit status (7 = connection
# refused, 6 = DNS, 28 = timeout), PROBE_CODE the HTTP status, PROBE_BYTES the
# body size — and the third one is load-bearing: a ~192-byte body at HTTP 403
# is the Nexus licence refusal, which is a perfectly well-formed response and is
# invisible to a status check alone (measured, 24-02).
PROBE_RC=0
PROBE_CODE=""
PROBE_BYTES=0

# Entries appended to the target repository's .gitignore unless
# --commit-config is passed. T-24-29.
GITIGNORE_ENTRIES=(".npmrc" "pip.conf" ".helm/" ".nexus-env")

# Scratch space for this run, created in the main body. Nothing a client reads
# is ever written here.
TMP_DIR=""

# ---------------------------------------------------------------------------
# Helper functions (shape copied verbatim from workstation/setup.sh)
# ---------------------------------------------------------------------------

usage() {
  cat <<'USAGE'
Usage: bash workstation/nexus-setup.sh --url <NEXUS_URL> [OPTIONS]

Point ONE repository's npm, pip and Helm clients at a Nexus instance, and emit
the one sourceable env file that makes two of those three take effect.
Run it from inside the repository you want to route.

Required:
  --url <URL>      Base URL of the Nexus instance: http:// or https://, host
                   with optional :port and optional path, e.g.
                   https://nexus.example.com or http://127.0.0.1:8081
                   A single trailing slash is accepted and stripped.

Options:
  --force          Overwrite generated files that already exist. Without it,
                   an existing pip.conf or .nexus-env is left alone and the run
                   reports it as skipped. .npmrc is never overwritten either
                   way — npm merges it.
  --verify         After configuring, PROVE it: ask each client what it
                   resolves, then pull a real component through it, and print
                   one row per ecosystem. Any row that is not 'ok' or 'MANUAL'
                   makes the run exit non-zero. Run it on an already-configured
                   repository too — without --force nothing is rewritten, so
                   the run verifies rather than reconfigures. Three sample
                   artefacts are fetched (an npm tarball, a PyPI wheel and the
                   chart index); override which with NEXUS_VERIFY_NPM_NAME,
                   NEXUS_VERIFY_NPM_VERSION and NEXUS_VERIFY_PIP_PACKAGE.
  --docker-daemon  ALSO write the MACHINE-GLOBAL Docker daemon configuration at
                   ~/.docker/daemon.json. OFF by default, and the only thing
                   this script writes outside the target repository.
                   WHAT IT COSTS: unlike the npm, pip and Helm configuration,
                   which is scoped to one repository, this affects every
                   repository and every project on this workstation. For a
                   plain-http Nexus it also adds an insecure-registries entry,
                   which disables TLS verification for that host entirely and
                   must be removed once TLS is configured on the instance
                   (ADR-009).
                   WHAT IT BUYS, precisely: docker.io image references are
                   pulled through Nexus. ghcr.io, quay.io, public.ecr.aws and
                   every other registry are NOT mirrored by any daemon mirror
                   and continue to be pulled directly.
                   The existing file is backed up with a timestamp first, each
                   entry is added at most once, a malformed file is never
                   overwritten, and the Docker engine must be restarted by you
                   afterwards — this script never restarts it.
  --commit-config  Do NOT add the generated files to .gitignore. By default
                   they are gitignored: a committed .npmrc pointing at one
                   operator's Nexus breaks dependency resolution for every
                   contributor who cannot reach it, and discloses an internal
                   hostname if the repository is public. Pass this flag when
                   the whole team shares the same Nexus and you want the
                   routing committed on purpose.
  -v, --verbose    Show detailed progress output
  -h, --help       Show this help message and exit

Files written, all inside the target repository:
  .npmrc                   via 'npm config set registry=... --location=project'
  pip.conf                 index-url, plus a TLS-bypass line only when it is
                           genuinely required (plain http to a non-loopback host)
  .helm/repositories.yaml  written by 'helm repo add' itself, never by hand
  .helm/cache/             Helm's repository cache for this repository
  .nexus-env               four exports — the mechanism, not a convenience
  .gitignore               append-only entries for the above, unless
                           --commit-config is passed

WHICH ECOSYSTEMS NEED .nexus-env SOURCED:
  npm     No environment needed. .npmrc is read natively.
  pip     ONLY works once you run 'source .nexus-env' in the shell.
  Helm    ONLY works once you run 'source .nexus-env' in the shell.
  Docker  Has no per-repository configuration of any kind. .nexus-env exports
          NEXUS_DOCKER_REGISTRY as a prefix string; routing an image through
          Nexus is a MANUAL step — you edit the image reference. Note the
          prefix carries NO '/repository/' segment: Docker is the one ecosystem
          of the four where that segment is wrong and produces a 404.

  Run 'source .nexus-env' in a shell session. Never add it to a shell rc file
  (.bashrc, .zshrc, ...): that would make one repository's Nexus the default for
  every project on this machine, and PIP_CONFIG_FILE REPLACES rather than adds
  to your user-level pip configuration, so your own pip settings would silently
  stop applying everywhere.

npm subtlety worth knowing before you report a bug: npm reads .npmrc from its
LOCAL PREFIX — the nearest ancestor containing package.json or node_modules —
not from the current directory. In a repository with no package.json anywhere
up the tree, npm falls back to https://registry.npmjs.org/ and this script will
look like it did nothing. It warns when that applies.

Re-running is safe: 'helm repo add' is invoked with --force-update, so a re-run
with a different --url replaces the 'nexus' entry rather than erroring, and
.gitignore entries are added only when absent.

This script does not prove that anything routes. Writing a config file is not
the same as a client reading it.
USAGE
}

log() {
  if [[ "$VERBOSE" = true ]]; then
    echo "==> $*"
  fi
}

info() {
  echo "==> $*"
}

err() {
  echo "ERROR: $*" >&2
}

# warn() is the carrier for every hazard this script must state rather than
# silently absorb: the PIP_CONFIG_FILE user-scope replacement, the npm
# local-prefix trap, an already-tracked .npmrc, and an unreachable Helm repo.
warn() {
  echo "WARNING: $*" >&2
}

# ---------------------------------------------------------------------------
# Idempotent config write (copied from workstation/setup.sh, plus --force)
# ---------------------------------------------------------------------------
#
# Content is supplied by the caller on stdin, normally via a heredoc.
#
# NOT every generated file goes through this function, and the two exceptions
# matter:
#   .npmrc  npm owns that merge. A redirect onto .npmrc destroys a developer's
#           //registry/:_authToken line with no error and a zero exit status.
#           'npm config set registry=<url> --location=project' is measured
#           non-destructive and is the only mechanism used here.
#   a machine-global Docker daemon configuration file must NEVER go through
#           this function, if a later version ever writes one: skip-if-exists
#           would silently no-op on a file that almost certainly already exists
#           on the operator's machine, printing a skip where the operator would
#           read "already configured".
write_config() {
  local target="$1" description="$2"

  if [[ -f "$target" && "$FORCE" != true ]]; then
    info "Exists, left alone (use --force to overwrite): $target"
    # Drain stdin so the caller's heredoc is consumed on both branches.
    cat > /dev/null
    return 0
  fi

  cat > "$target"
  CONFIG_COUNT=$((CONFIG_COUNT + 1))
  log "Wrote: $target ($description)"
}

# ---------------------------------------------------------------------------
# --url validation — runs BEFORE the value is interpolated anywhere
# ---------------------------------------------------------------------------
#
# T-24-27. This string crosses from an operator's argv into config files that
# npm, pip and Helm obey, and into shell command lines. Every rejection below
# names the rule that failed, so a rejected URL is a fixable message rather than
# a guess. Nothing is written before this function returns.
validate_url() {
  local raw="$1"
  local scheme rest port

  case "$raw" in
    http://*)  scheme="http"  ; rest="${raw#http://}"  ;;
    https://*) scheme="https" ; rest="${raw#https://}" ;;
    *)
      err "--url failed the scheme allowlist: it must begin with 'http://' or 'https://'. Got: ${raw}"
      exit 1
      ;;
  esac

  # Exactly one trailing slash is stripped, so concatenating '/repository/...'
  # below cannot produce a '//' segment. A second trailing slash is rejected
  # rather than silently stripped too: '<url>//' is far more likely to be a
  # typo than an intention, and guessing an operator's intent is what this
  # script does not do.
  rest="${rest%/}"

  if [[ -z "$rest" ]]; then
    err "--url failed the host rule: there is nothing after the scheme. Got: ${raw}"
    exit 1
  fi

  # The conservative character class. Letters, digits, dot, underscore, tilde,
  # colon, slash and hyphen only. Everything a shell would act on — whitespace,
  # ';', '&', '|', '(', ')', backtick, '$', quotes, '*', '?', '#', '\' — and
  # everything that would smuggle in credentials or a query ('@', '%') is
  # outside it.
  if [[ ! "$rest" =~ ^[A-Za-z0-9._~:/-]+$ ]]; then
    err "--url failed the character rule: after the scheme it may contain only letters, digits and the characters . _ ~ : / -"
    err "Rejected (whitespace, quotes, and shell metacharacters such as ; & | \$ \` ( ) * ? # @ % are not accepted): ${raw}"
    exit 1
  fi

  case "$rest" in
    /*)
      err "--url failed the host rule: there is no host before the first '/'. Got: ${raw}"
      exit 1
      ;;
    */)
      err "--url failed the trailing-slash rule: more than one trailing slash. Give the URL with at most one. Got: ${raw}"
      exit 1
      ;;
    *//*)
      err "--url failed the path rule: it contains an empty path segment ('//'). Got: ${raw}"
      exit 1
      ;;
  esac

  NEXUS_SCHEME="$scheme"
  NEXUS_URL="${scheme}://${rest}"
  NEXUS_HOST="${rest%%/*}"
  NEXUS_PATH="${rest#"$NEXUS_HOST"}"
  NEXUS_HOST_NO_PORT="${NEXUS_HOST%%:*}"

  if [[ -z "$NEXUS_HOST_NO_PORT" ]]; then
    err "--url failed the host rule: the host is empty. Got: ${raw}"
    exit 1
  fi

  # One colon at most, and only digits after it. This is also what rejects a
  # bare IPv6 literal, which the character class above would otherwise admit.
  case "$NEXUS_HOST" in
    *:*:*)
      err "--url failed the host rule: more than one ':' in the host. Bracketed IPv6 literals are not supported; use a hostname or an IPv4 address. Got: ${raw}"
      exit 1
      ;;
    *:*)
      port="${NEXUS_HOST##*:}"
      if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        err "--url failed the port rule: '${port}' is not a number. Got: ${raw}"
        exit 1
      fi
      ;;
  esac

  # pip's own SECURE_ORIGINS already trusts localhost and 127.0.0.0/8 over any
  # scheme, which is what makes the trusted-host decision conditional rather
  # than unconditional. Recorded here, acted on by the pip writer.
  case "$NEXUS_HOST_NO_PORT" in
    localhost|127.*) NEXUS_IS_LOOPBACK=1 ;;
    *)               NEXUS_IS_LOOPBACK=0 ;;
  esac
}

# ---------------------------------------------------------------------------
# npm — the one ecosystem with a native project scope
# ---------------------------------------------------------------------------
#
# The mechanism is 'npm config set registry=<url> --location=project', run from
# the repository root, and nothing else. Measured on npm 11.7.0: starting from
# an .npmrc containing a '//registry.example.com/:_authToken=' line and
# 'save-exact=true', both survived byte-identically and the registry line was
# appended.
#
# T-24-28. The alternative — writing the file ourselves — is a credential-loss
# bug. A developer's .npmrc may hold the only copy of a private-registry token,
# and a redirect onto it destroys that with no error message and a zero exit
# status. There is therefore no code path in this script that redirects onto
# that file, and scripts/check-nexus-setup.sh asserts as much.
configure_npm() {
  # Held in a variable rather than written inline so that no line in this file
  # can ever place that filename after a shell redirect.
  local npmrc_rel=".npmrc"
  local registry_url="${NEXUS_URL}/repository/${NPM_REPO}/"
  local rc=0

  if ! command -v npm > /dev/null 2>&1; then
    warn "npm is not on PATH, so ${REPO_ROOT}/${npmrc_rel} was NOT written and npm in this repository still resolves from whatever registry it resolved from before. Install npm and re-run to route it."
    NPM_STATUS="not configured (npm not on PATH)"
    return 0
  fi

  # T-24-29. Gitignoring a file git already tracks is a no-op: .gitignore is
  # consulted for UNtracked paths only. Warn, do not refuse — a team that
  # deliberately commits its routing is a legitimate configuration, and
  # --commit-config exists for exactly that.
  if git -C "$REPO_ROOT" ls-files --error-unmatch -- "$npmrc_rel" > /dev/null 2>&1; then
    warn "${npmrc_rel} is already TRACKED by git in this repository. Adding it to .gitignore will not untrack it, so the registry line written below will be committed on your next commit — an internal-hostname disclosure if this repository is public. Run 'git rm --cached ${npmrc_rel}' first if that is not what you want."
  fi

  # Pitfall 10 in its quietest form. npm resolves .npmrc from its LOCAL PREFIX,
  # the nearest ancestor holding package.json or node_modules — not from the
  # repository root and not from the current directory. Measured: with neither
  # anywhere up the tree, npm falls back to https://registry.npmjs.org/ and the
  # file this script just wrote is never read.
  if [[ ! -f "${REPO_ROOT}/package.json" && ! -d "${REPO_ROOT}/node_modules" ]]; then
    warn "there is no package.json and no node_modules at ${REPO_ROOT}. npm reads ${npmrc_rel} from its local prefix — the nearest ancestor containing one of those two — so the file written here may never be read, and npm may keep resolving from https://registry.npmjs.org/ with no error. Run 'npm config get registry' from inside the repository to see what npm itself resolves."
  fi

  ( cd "$REPO_ROOT" && npm config set "registry=${registry_url}" --location=project ) || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    warn "'npm config set registry=... --location=project' exited ${rc} in ${REPO_ROOT}. npm is NOT routed."
    NPM_STATUS="not configured (npm config set exited ${rc})"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 0
  fi

  NPM_STATUS="configured — ${npmrc_rel} registry=${registry_url} (no environment needed)"
}

# ---------------------------------------------------------------------------
# pip — no project scope, so the file is inert until the env var points at it
# ---------------------------------------------------------------------------
#
# T-24-30, Pitfall 8, measured: PIP_CONFIG_FILE does not ADD a configuration
# source, it REPLACES the user scope. With it set, 'pip config list -v' no
# longer lists either user-scope variant. This warning fires on every run, and
# names the developer's own keys when it can find them, because the consequence
# lands in a shell the developer keeps using for other projects.
warn_pip_user_scope() {
  local candidate
  local found=0

  warn "sourcing .nexus-env sets PIP_CONFIG_FILE, which REPLACES your user-level pip configuration rather than adding to it. Measured: with it set, 'pip config list -v' no longer lists EITHER user-scope variant, so settings such as a corporate CA bundle or an extra-index-url silently stop applying in that shell. Source it per shell session; never from a shell rc file."

  for candidate in "${HOME}/.pip/pip.conf" "${HOME}/.config/pip/pip.conf"; do
    [[ -f "$candidate" ]] || continue
    found=1
    # Keys present in the developer's own file that the generated pip.conf does
    # not carry are exactly the settings that will stop applying. The pipeline
    # exits non-zero when grep selects nothing, which is the "no orphaned keys"
    # case and is handled by the branch rather than swallowed.
    if sed -n 's/^[[:space:]]*\([A-Za-z0-9][A-Za-z0-9._-]*\)[[:space:]]*=.*/\1/p' "$candidate" \
       | grep -vxE '(index-url|trusted-host)' \
       | sort -u > "${TMP_DIR}/pip-user-keys.txt"; then
      warn "your pip configuration at ${candidate} sets keys the generated pip.conf does not carry, and they will stop applying in any shell that has sourced .nexus-env: $(tr '\n' ' ' < "${TMP_DIR}/pip-user-keys.txt")"
    else
      log "User pip configuration at ${candidate} carries no key outside the generated set."
    fi
  done

  if [[ "$found" -eq 0 ]]; then
    log "No user-level pip.conf found at either candidate path; nothing of the developer's own is replaced."
  fi
}

# pip.conf is written by hand through write_config, NOT by driving the pip CLI.
# Measured on pip 26.2.1: 'pip config set' with PIP_CONFIG_FILE exported exits
# with 'ERROR: Fatal Internal error [id=2]' and writes nothing at all.
configure_pip() {
  local pip_conf="${REPO_ROOT}/pip.conf"
  local index_url="${NEXUS_URL}/repository/${PYPI_REPO}/simple"

  warn_pip_user_scope

  # T-24-32. The TLS-bypass directive is emitted ONLY when it is genuinely
  # required. pip's own SECURE_ORIGINS already trusts https anywhere, and any
  # scheme to localhost, 127.0.0.0/8 or ::1 — so emitting it for an https URL
  # or for loopback downgrades a check that was working and teaches the habit
  # of disabling certificate verification by reflex.
  if [[ "$NEXUS_SCHEME" == "http" && "$NEXUS_IS_LOOPBACK" -eq 0 ]]; then
    write_config "$pip_conf" "pip index routed at ${NEXUS_HOST}, with a TLS bypass" <<PIPCONF
# pip.conf — generated by workstation/nexus-setup.sh
#
# This file is inert on its own. pip has no project scope and no cwd-relative
# configuration path, so nothing here applies until PIP_CONFIG_FILE points at
# it: run 'source .nexus-env' in this shell first.
[global]
index-url = ${index_url}

# SECURITY WARNING (ADR-009). The directive below does not merely permit plain
# HTTP. It disables TLS certificate verification for ${NEXUS_HOST_NO_PORT}
# entirely, so anything positioned between this machine and that host can
# substitute packages and pip will raise no certificate error. It is present
# only because --url gave a plain http:// URL for a non-loopback host.
# It MUST be removed once TLS is configured on this Nexus instance.
trusted-host = ${NEXUS_HOST_NO_PORT}
PIPCONF
    PIP_STATUS="configured — pip.conf index-url set, plus a TLS-verification bypass for ${NEXUS_HOST_NO_PORT} (ADR-009: remove it once TLS is configured); needs 'source .nexus-env'"
  else
    write_config "$pip_conf" "pip index routed at ${NEXUS_HOST}" <<PIPCONF
# pip.conf — generated by workstation/nexus-setup.sh
#
# This file is inert on its own. pip has no project scope and no cwd-relative
# configuration path, so nothing here applies until PIP_CONFIG_FILE points at
# it: run 'source .nexus-env' in this shell first.
#
# No TLS-bypass directive is emitted here, and that is deliberate rather than an
# omission: pip's own SECURE_ORIGINS already trusts https anywhere and any
# scheme to localhost or 127.0.0.0/8, so adding one would disable a
# certificate check that is currently working.
[global]
index-url = ${index_url}
PIPCONF
    PIP_STATUS="configured — pip.conf index-url set, no TLS bypass needed; needs 'source .nexus-env'"
  fi
}

# ---------------------------------------------------------------------------
# Helm — no project scope; the environment redirect IS the mechanism
# ---------------------------------------------------------------------------
#
# .helm/repositories.yaml is never hand-written. It is Helm's own internal
# format: it carries a 'generated' timestamp and per-entry cert/auth fields,
# and its shape has changed across major versions. A heredoc version of it
# looks right today and is a forgery one Helm release later. So the file is
# produced by 'helm repo add' itself, with HELM_REPOSITORY_CONFIG and
# HELM_REPOSITORY_CACHE exported for that single invocation.
#
# T-24-31. Those two variables are the ENTIRE mechanism that keeps this out of
# the operator's global repository list. Dropping either one means writing to
# the developer's real global file.
configure_helm() {
  local helm_dir="${REPO_ROOT}/.helm"
  local helm_cfg="${helm_dir}/repositories.yaml"
  local helm_cache="${helm_dir}/cache"
  local repo_url="${NEXUS_URL}/repository/${HELM_REPO}/"
  local global_cfg=""
  local rc=0

  mkdir -p "$helm_cache"

  if ! command -v helm > /dev/null 2>&1; then
    warn "helm is not on PATH, so no chart repository entry was created. ${helm_dir} exists and .nexus-env will still point at it, but Helm is NOT routed until helm is installed and this script is re-run."
    HELM_STATUS="not configured (helm not on PATH)"
    return 0
  fi

  # Read with the redirect removed, so this names the operator's REAL global
  # list even in a shell that has already sourced a .nexus-env.
  global_cfg="$(env -u HELM_REPOSITORY_CONFIG helm env HELM_REPOSITORY_CONFIG | tr -d '"')"
  log "Operator's global Helm repository list is ${global_cfg}. This run redirects Helm at the repository-local file instead and never writes the global one."

  # 'helm repo add' REACHES THE NETWORK: Helm fetches index.yaml during the
  # add and errors when the repository is unreachable, and there is no
  # --no-update escape. So the call gets an explicit caught branch.
  #
  # This is a caught branch and NOT a swallowed '|| true'. The distinction is
  # the point: this is a configuration writer, and an unreachable chart
  # repository must not cost the developer the .nexus-env and .gitignore
  # entries that the rest of the run produces. Reachability is judged by
  # --verify (plan 24-07), which tolerates nothing. The failure is counted, so
  # the run still exits non-zero.
  #
  # --force-update makes a re-run idempotent in both directions: the same URL
  # re-adds cleanly, and a DIFFERENT URL replaces the entry instead of erroring
  # with "repository name already exists". Stated in --help.
  HELM_REPOSITORY_CONFIG="$helm_cfg" HELM_REPOSITORY_CACHE="$helm_cache" \
    helm repo add "$HELM_REPO_NAME" "$repo_url" --force-update \
    > "${TMP_DIR}/helm-repo-add.log" 2>&1 || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    warn "'helm repo add ${HELM_REPO_NAME} ${repo_url}' exited ${rc}; Helm is NOT routed. Helm fetches index.yaml during 'repo add', so an unreachable or non-Helm URL fails here. Helm's own output: $(tr '\n' ' ' < "${TMP_DIR}/helm-repo-add.log")"
    HELM_STATUS="not configured (repository unreachable — 'helm repo add' exited ${rc})"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 0
  fi

  log "helm repo add: $(tr '\n' ' ' < "${TMP_DIR}/helm-repo-add.log")"
  HELM_STATUS="configured — entry '${HELM_REPO_NAME}' at ${repo_url}; needs 'source .nexus-env'"
}

# ---------------------------------------------------------------------------
# .nexus-env — the mechanism for two of the three configured ecosystems
# ---------------------------------------------------------------------------
write_nexus_env() {
  local env_file="${REPO_ROOT}/.nexus-env"
  local pip_conf="${REPO_ROOT}/pip.conf"
  local helm_cfg="${REPO_ROOT}/.helm/repositories.yaml"
  local helm_cache="${REPO_ROOT}/.helm/cache"
  # MEASURED: no '/repository/' segment here, unlike the other three. See the
  # comment reproduced in the generated file — it is repeated there on purpose,
  # because the generated file is what a developer actually reads.
  local docker_prefix="${NEXUS_HOST}/${DOCKER_REPO}"

  write_config "$env_file" "sourceable environment for pip, Helm and the Docker prefix" <<ENVFILE
# .nexus-env — generated by workstation/nexus-setup.sh
#
# source this file; do not execute it:
#
#     source .nexus-env
#
# What actually depends on it:
#   npm     Nothing. npm reads its project-scoped config natively and is
#           already routed with no environment set at all.
#   pip     Everything. pip has no project scope, so pip.conf in this
#           repository is inert until PIP_CONFIG_FILE below points at it.
#   Helm    Everything. Helm has no project scope either, so the repository
#           entry created for this repository is invisible to helm until
#           HELM_REPOSITORY_CONFIG below points at it.
#   Docker  Nothing automatic. Docker has no per-repository configuration of
#           any kind. NEXUS_DOCKER_REGISTRY below is a prefix string, and
#           routing an image is a MANUAL edit of an image reference.
#
# WARNING. PIP_CONFIG_FILE REPLACES your user-level pip configuration rather
# than adding to it. Measured: with it set, 'pip config list -v' no longer
# lists EITHER user-scope variant, so your own pip settings — a corporate CA
# bundle, an extra-index-url — silently stop applying in this shell.
#
# Source this in a shell session. Never add it to a shell rc file (.bashrc,
# .zshrc and friends): that would make one repository's Nexus the default for
# every project on this machine, which is the global workstation default this
# script is deliberately scoped to avoid.

export PIP_CONFIG_FILE="${pip_conf}"
export HELM_REPOSITORY_CONFIG="${helm_cfg}"
export HELM_REPOSITORY_CACHE="${helm_cache}"

# MEASURED, and the one asymmetry in this file: the Docker prefix carries NO
# '/repository/' segment, while the npm, pip and Helm URLs all do. A Docker
# client inserts '/v2/' immediately after the host, so the repository name has
# to be the first path segment; the '/repository/'-prefixed reference returns
# HTTP 404. Use it like this:
#
#     docker pull ${docker_prefix}/library/alpine:3.21
export NEXUS_DOCKER_REGISTRY="${docker_prefix}"
ENVFILE
}

# ---------------------------------------------------------------------------
# .gitignore — new behaviour, with no in-repo precedent
# ---------------------------------------------------------------------------
#
# workstation/setup.sh never touches .gitignore (grep -i gitignore returns
# nothing in that file), so this is not a pattern copied from the analog and
# the reasoning is stated rather than assumed.
#
# T-24-29. A committed .npmrc pointing at one operator's Nexus is a
# dependency-resolution failure for every contributor who cannot reach that
# host, and an internal-hostname disclosure if the repository is public.
# Default to ignoring the generated files; --commit-config opts out.
#
# Existing lines are never rewritten, reordered or removed — the file is only
# ever appended to, and only with entries that are not already present in any
# equivalent form.
normalise_ignore_line() {
  local value="$1"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value#/}"
  value="${value%/}"
  printf '%s' "$value"
}

update_gitignore() {
  local gi="${REPO_ROOT}/.gitignore"
  local marker="# Nexus routing config generated by workstation/nexus-setup.sh (machine-specific)"
  local entry norm_entry need_marker=1
  local to_add=()

  if [[ "$COMMIT_CONFIG" = true ]]; then
    info "--commit-config given: .gitignore was NOT modified, and the generated files are committable. That is the right choice when the whole team shares this Nexus and wants the routing in version control; it is the wrong one for a public repository, where .npmrc and pip.conf would disclose an internal hostname, and for any repository whose contributors cannot reach ${NEXUS_HOST}."
    GITIGNORE_STATUS="not modified (--commit-config)"
    return 0
  fi

  : > "${TMP_DIR}/gitignore-existing.txt"
  if [[ -f "$gi" ]]; then
    sed -e 's/[[:space:]]*$//' -e 's#^/##' -e 's#/$##' "$gi" \
      > "${TMP_DIR}/gitignore-existing.txt"
    if grep -Fqx "$marker" "$gi"; then
      need_marker=0
    fi
  fi

  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    norm_entry="$(normalise_ignore_line "$entry")"
    if grep -Fqx "$norm_entry" "${TMP_DIR}/gitignore-existing.txt"; then
      continue
    fi
    to_add+=("$entry")
  done

  if [[ "${#to_add[@]}" -eq 0 ]]; then
    log "Every generated file is already ignored by ${gi}; nothing was appended."
    GITIGNORE_STATUS="unchanged (all entries already present)"
    return 0
  fi

  # Decided BEFORE anything is appended: the blank separator line belongs only
  # between existing content and the new block, so a .gitignore this script
  # creates itself does not open on an empty line.
  local need_separator=0
  if [[ -s "$gi" ]]; then
    need_separator=1
  fi

  # A file that does not end in a newline would otherwise have its last line
  # glued to the first entry appended below.
  if [[ "$need_separator" -eq 1 ]] && [[ -n "$(tail -c 1 "$gi")" ]]; then
    printf '\n' >> "$gi"
  fi

  {
    if [[ "$need_separator" -eq 1 ]]; then
      printf '\n'
    fi
    if [[ "$need_marker" -eq 1 ]]; then
      printf '%s\n' "$marker"
    fi
    for entry in "${to_add[@]}"; do
      printf '%s\n' "$entry"
    done
  } >> "$gi"

  GITIGNORE_STATUS="appended ${#to_add[@]} entr$([[ "${#to_add[@]}" -eq 1 ]] && printf 'y' || printf 'ies') to .gitignore (--commit-config skips this)"
  log "${GITIGNORE_STATUS}"
}

# ---------------------------------------------------------------------------
# --docker-daemon — the ONE machine-global write, and the only file this
# script touches outside the target repository
# ---------------------------------------------------------------------------
#
# T-24-34. This file belongs to the operator, not to this script, and it very
# probably already exists with keys that matter — a credential store, a builder
# configuration, a proxy. The shape below is the realms guard from
# kubernetes/nexus/files/provision.sh: read the current state, compute the new
# state with jq, compare, and write ONLY if they differ.
#
# It deliberately does NOT go through write_config(): that function skips when
# the target exists, which on a file that almost certainly exists would print a
# skip where the operator would read "already configured".
print_docker_daemon_warning() {
  cat >&2 <<DOCKERWARN

SECURITY WARNING (ADR-009) — what was just written to ${DOCKER_DAEMON_FILE}:

  registry-mirrors     tells the Docker engine to try ${1} before Docker Hub.
                       Only docker.io references are ever mirrored: ghcr.io,
                       quay.io, public.ecr.aws and every other registry
                       continue to be pulled directly, so this routes PART of
                       a typical project's images and never all of them.
  insecure-registries  does not merely permit plain HTTP. It disables TLS
                       verification for ${NEXUS_HOST} entirely, so anything
                       positioned between this machine and that host can
                       substitute images and the engine will raise no
                       certificate error.

  This change is MACHINE-GLOBAL: it affects every repository and every project
  on this workstation, unlike the npm, pip and Helm configuration this script
  writes, which is scoped to one repository.
  It MUST be removed once TLS is configured on this Nexus instance.

DOCKERWARN
}

configure_docker_daemon() {
  local daemon_dir="${HOME}/.docker"
  local mirror_url="${NEXUS_URL}/repository/${DOCKER_REPO}"
  local current="${TMP_DIR}/daemon-current.json"
  local new="${TMP_DIR}/daemon-new.json"
  local parse_err="${TMP_DIR}/daemon-parse.err"
  local backup="" stamp=""

  # jq is not optional here and there is no fallback. Editing a JSON file this
  # script does not own with sed is how other people's keys get destroyed.
  if ! command -v jq > /dev/null 2>&1; then
    err "--docker-daemon needs jq, which is not on PATH. ${DOCKER_DAEMON_FILE} was NOT touched: this script will not edit a JSON file it does not own without a JSON parser."
    DOCKER_DAEMON_STATUS="not written (jq is not on PATH)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 0
  fi

  if [[ -n "$NEXUS_PATH" ]]; then
    warn "--url carries the path '${NEXUS_PATH}', so the mirror URL written below is '${mirror_url}'. The A3 measurement covered a Nexus at the root of its host; a mirror URL with an extra path component in front of '/repository/' is NOT a measured shape. Verify the pull actually lands in Nexus rather than trusting the exit code — a Docker pull that silently falls back to Docker Hub also exits 0."
  fi

  mkdir -p "$daemon_dir"

  if [[ -f "$DOCKER_DAEMON_FILE" ]]; then
    # A malformed file is a HARD failure, never an overwrite. A file this
    # script cannot parse is a file whose contents it cannot preserve, and
    # replacing it would destroy exactly the keys the backup exists to protect.
    if ! jq '.' "$DOCKER_DAEMON_FILE" > "$current" 2> "$parse_err"; then
      err "${DOCKER_DAEMON_FILE} exists and is not valid JSON, so it was NOT modified and NOT overwritten: $(tr '\n' ' ' < "$parse_err" | cut -c1-200). Fix the file by hand, then re-run."
      DOCKER_DAEMON_STATUS="not written (existing file is not valid JSON — left untouched)"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      return 0
    fi
    if ! jq -e 'type == "object"' "$current" > /dev/null 2>&1; then
      err "${DOCKER_DAEMON_FILE} parses as JSON but is not an object, so it was NOT modified. A Docker daemon configuration is a JSON object."
      DOCKER_DAEMON_STATUS="not written (existing file is valid JSON but not an object — left untouched)"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      return 0
    fi
  else
    printf '{}\n' > "$current"
    log "No ${DOCKER_DAEMON_FILE} exists; the current state is an empty document and there is nothing to back up."
  fi

  # Each entry is appended ONLY when absent, and the existing list is neither
  # sorted nor de-duplicated: registry-mirrors is a PRIORITY list, and
  # reordering an operator's mirrors would change which one is tried first.
  #
  # insecure-registries is emitted only for a plain-http Nexus. ADR-009 governs
  # it exactly as it governs pip's trusted-host: writing a TLS bypass for an
  # https:// URL would disable a certificate check that is currently working.
  # The measured A3 pair was http with both keys, so an http run ships exactly
  # the combination that was measured.
  if [[ "$NEXUS_SCHEME" == "http" ]]; then
    jq --arg m "$mirror_url" --arg h "$NEXUS_HOST" '
      .["registry-mirrors"]    = ((.["registry-mirrors"]    // []) | if index($m) then . else . + [$m] end)
      | .["insecure-registries"] = ((.["insecure-registries"] // []) | if index($h) then . else . + [$h] end)
    ' "$current" > "$new"
  else
    info "--url is https, so no insecure-registries entry is written: that directive disables TLS verification, and adding it for a URL that already has TLS would downgrade a check that is working. Only registry-mirrors is added."
    jq --arg m "$mirror_url" '
      .["registry-mirrors"] = ((.["registry-mirrors"] // []) | if index($m) then . else . + [$m] end)
    ' "$current" > "$new"
  fi

  # Canonicalised comparison rather than a byte comparison of the two files:
  # jq reformats, so a file whose entries are already present but indented
  # differently would otherwise be "changed", taking a backup and printing a
  # security warning for a rewrite that alters nothing.
  if [[ "$(jq -S -c '.' "$current")" == "$(jq -S -c '.' "$new")" ]]; then
    info "${DOCKER_DAEMON_FILE} already carries the mirror ${mirror_url}$([[ "$NEXUS_SCHEME" == "http" ]] && printf ' and the insecure-registries entry %s' "$NEXUS_HOST"). Nothing was written and no backup was taken."
    DOCKER_DAEMON_STATUS="unchanged (every entry was already present; nothing written)"
    DOCKER_VERIFY_NOTE=" A machine-global mirror for ${mirror_url} is already present in ${DOCKER_DAEMON_FILE}; that is a daemon key, not a per-repository route, and it mirrors docker.io references only."
    return 0
  fi

  if [[ -f "$DOCKER_DAEMON_FILE" ]]; then
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    backup="${DOCKER_DAEMON_FILE}.nexus-setup-backup-${stamp}"
    cp -p "$DOCKER_DAEMON_FILE" "$backup"
    info "Backed up ${DOCKER_DAEMON_FILE} to ${backup} BEFORE any write."
  fi

  cat "$new" > "$DOCKER_DAEMON_FILE"
  CONFIG_COUNT=$((CONFIG_COUNT + 1))
  DOCKER_DAEMON_STATUS="WRITTEN — machine-global mirror ${mirror_url} added to ${DOCKER_DAEMON_FILE}; a Docker engine restart is required before it takes effect"
  DOCKER_VERIFY_NOTE=" A machine-global mirror for ${mirror_url} was written to ${DOCKER_DAEMON_FILE} on this run; that is a daemon key rather than a per-repository route, it mirrors docker.io references only, and the engine has not been restarted, so it is not in effect yet."

  print_docker_daemon_warning "$mirror_url"

  if [[ -n "$backup" ]]; then
    info "To undo this change:  cp \"${backup}\" \"${DOCKER_DAEMON_FILE}\""
  else
    info "To undo this change:  rm \"${DOCKER_DAEMON_FILE}\"  (there was no file before this run)"
  fi
  info "The Docker engine reads ${DOCKER_DAEMON_FILE} at start, so you must restart the engine yourself before any of this takes effect. This script does NOT restart it: stopping a developer's engine — and every container on it — is not a thing an install script may decide."
  info "NOT MEASURED, and worth knowing before you trust it: the A3 probe ran against a nested Linux engine with the classic overlay2 image store. This workstation's own Docker Desktop engine was never configured with the mirror and never restarted during that measurement, so its first real run is here. After restarting, confirm the pull actually lands in Nexus (the repository's component count goes up) rather than trusting 'docker pull' exit 0 — a mirror that routes nothing also exits 0."
}

# ---------------------------------------------------------------------------
# --verify — the proof pass
# ---------------------------------------------------------------------------
#
# Pitfall 10, and the reason this mode is not optional garnish. Four files can
# be written, a success line printed, and pip and Helm still reach the public
# internet because .nexus-env was never sourced — or npm still does, because the
# repository has no package.json and npm's local prefix resolved somewhere else
# entirely. Writing a configuration file is not the same as a client reading it,
# and only the client can say which it did.
#
# TWO STAGES PER ECOSYSTEM, because they are different diagnoses:
#   1. CONFIGURATION READBACK — ask the CLIENT what it resolves, never grep the
#      file this script just wrote. A file can be perfect and unread.
#   2. FETCH — a real download through that configuration. A readback that is
#      right while the fetch fails is a server or network problem; a readback
#      that is wrong is a configuration problem. Reporting them as one verdict
#      would send the developer to the wrong place.
#
# STATUSES, and the arithmetic they drive:
#   ok            both stages passed. The only status that is proof of routing.
#   FAILED        a stage produced the wrong result.
#   UNVERIFIABLE  the client could not be made to answer the question at all
#                 (npm with no local prefix here). NOT a pass.
#   SKIPPED       the client is not installed. A SKIP IS NOT A PASS.
#   MANUAL        docker only, always, under every condition.
# Every status except 'ok' and 'MANUAL' increments FAIL_COUNT, so a run where
# nothing routes exits 1. No fetch below is ever '|| true'-ed: a tolerated
# failure in a verification pass IS the false-pass mechanism this mode exists to
# remove.

# bounded SECONDS COMMAND... — an outer wall-clock bound on a fetch, so an
# endpoint that accepts the connection and then stops talking cannot hang the
# run. Each client also carries its own timeout settings at the call sites
# below; this is the backstop for the one call that has no flag of its own
# (`helm repo update` has no --timeout in Helm v4).
#
# When neither binary is present the command still runs, bounded only by the
# client's own settings, and run_verify() says so out loud rather than claiming
# a bound it does not have.
BOUND_TOOL=""
if command -v timeout > /dev/null 2>&1; then
  BOUND_TOOL="timeout"
elif command -v gtimeout > /dev/null 2>&1; then
  BOUND_TOOL="gtimeout"
fi

bounded() {
  local secs="$1"
  shift
  if [[ -n "$BOUND_TOOL" ]]; then
    "$BOUND_TOOL" "$secs" "$@"
    return $?
  fi
  "$@"
}

# digest_of PATH — content fingerprint, or the literal ABSENT. A file that was
# absent before and is absent after is UNCHANGED, which is the property the Helm
# global-config assertion needs.
digest_of() {
  local target="$1"
  if [[ ! -e "$target" ]]; then
    printf 'ABSENT'
    return 0
  fi
  if command -v shasum > /dev/null 2>&1; then
    shasum -a 256 < "$target" | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum < "$target" | awk '{print $1}'
    return 0
  fi
  printf 'NO-DIGEST-TOOL'
}

# Trailing-slash-insensitive comparison. The URLs this script writes carry a
# trailing slash; a client is free to normalise, and a normalisation difference
# is not a routing defect.
strip_slash() {
  printf '%s' "${1%/}"
}

# verify_row ECOSYSTEM MECHANISM STATUS OBSERVED — the ONLY way a row reaches
# the table, and the only place FAIL_COUNT moves during verification. A status
# cannot therefore appear in the table without also reaching the exit code.
verify_row() {
  local ecosystem="$1" mechanism="$2" status="$3" observed="$4"
  VERIFY_ROWS+=("${ecosystem}|${mechanism}|${status}|${observed}")
  case "$status" in
    ok)
      VERIFY_OK=$((VERIFY_OK + 1))
      ;;
    MANUAL)
      VERIFY_MANUAL=$((VERIFY_MANUAL + 1))
      ;;
    *)
      VERIFY_BAD=$((VERIFY_BAD + 1))
      FAIL_COUNT=$((FAIL_COUNT + 1))
      ;;
  esac
}

# probe_url URL — one UNAUTHENTICATED, bounded GET whose result is used only to
# DIAGNOSE a failure the client already reported. It carries no -u and no -K,
# because the question it answers is what an anonymous client sees; and no -f,
# because the refusal body has to land on disk for its size to be measurable.
probe_url() {
  local url="$1"
  local body="${TMP_DIR}/probe-body.bin"
  PROBE_RC=0
  PROBE_CODE=""
  PROBE_BYTES=0
  rm -f "$body"
  if ! command -v curl > /dev/null 2>&1; then
    PROBE_RC=127
    return 0
  fi
  PROBE_CODE="$(curl -sS -o "$body" -w '%{http_code}' \
    --connect-timeout 5 --max-time 30 "$url" 2> "${TMP_DIR}/probe-err.txt")" || PROBE_RC=$?
  if [[ -f "$body" ]]; then
    PROBE_BYTES="$(wc -c < "$body" | tr -d ' ')"
  fi
}

# diagnose_url URL — three distinct server-side conditions, each named with the
# value responsible, because "verification failed" sends a developer to read
# their own config when the cause is on the server:
#
#   transport error  the endpoint is unreachable — URL, DNS, firewall, or the
#                    service is down. Nothing in this repository can fix it.
#   HTTP 401         anonymous read is not enabled on the Nexus SERVER.
#   HTTP 403 with a body under ~1,000 bytes — the Nexus licence refusal.
#                    MEASURED (plan 24-02): the refusal body is 192 bytes and is
#                    a perfectly well-formed HTTP response, so the size is what
#                    distinguishes it from an authorization rule.
diagnose_url() {
  local url="$1"
  probe_url "$url"

  if [[ "$PROBE_RC" -eq 127 ]]; then
    printf 'no diagnosis available: curl is not on PATH, so %s could not be probed independently.' "$url"
    return 0
  fi

  if [[ "$PROBE_RC" -ne 0 ]]; then
    printf 'REACHABILITY: an unauthenticated GET of %s did not complete (curl exited %s — 6 is DNS, 7 is connection refused, 28 is a timeout). The endpoint is unreachable from this machine: check the --url value, DNS, a firewall, and whether the service is running. No file in this repository can fix a connection that is never made.' \
      "$url" "$PROBE_RC"
    return 0
  fi

  case "$PROBE_CODE" in
    200)
      printf 'the endpoint %s itself answered HTTP 200 with %s bytes to an unauthenticated GET, so the server is reachable, anonymous read is open and the licence is accepted — the cause is on the client side of this ecosystem, not on the server.' \
        "$url" "$PROBE_BYTES"
      ;;
    401)
      printf 'SERVER-SIDE ANONYMOUS ACCESS: %s answered HTTP 401 to an unauthenticated GET. Anonymous read is NOT enabled on this Nexus — the server-side value responsible is anonymous.enabled (the chart value anonymous.enabled, PUT to /service/rest/v1/security/anonymous). Nothing written into this repository can change that; the Nexus instance has to be reconfigured.' \
        "$url"
      ;;
    403)
      if [[ "$PROBE_BYTES" -lt 1000 ]]; then
        printf 'SERVER-SIDE LICENCE REFUSAL: %s answered HTTP 403 with a %s-byte body to an unauthenticated GET. A component download refused with a body that small is the Sonatype licence gate, NOT a client misconfiguration — the server-side value responsible is eula.accepted (the chart value eula.accepted, POSTed to /service/rest/v1/system/eula). Measured, plan 24-02: the refusal body is 192 bytes, metadata still answers 200 while every component download is refused, and no file in this repository can change it.' \
          "$url" "$PROBE_BYTES"
      else
        printf '%s answered HTTP 403 with a %s-byte body. That is far larger than the ~192-byte Sonatype licence refusal, so this is an authorization rule on the server (a role or privilege on the anonymous user) rather than the eula.accepted gate.' \
          "$url" "$PROBE_BYTES"
      fi
      ;;
    404)
      printf '%s answered HTTP 404. The repository does not exist on this Nexus under that name, or the --url carries a path that the server does not serve. Check that the provisioning Job created it and that its name matches.' \
        "$url"
      ;;
    *)
      printf '%s answered HTTP %s with a %s-byte body to an unauthenticated GET — none of the three conditions this script can name (unreachable, 401 anonymous-disabled, 403 licence refusal).' \
        "$url" "$PROBE_CODE" "$PROBE_BYTES"
      ;;
  esac
}

# npm (24-W0-10). The one ecosystem with a native project scope, and therefore
# the one whose readback can be right while the file is never read: npm resolves
# .npmrc from its LOCAL PREFIX, so a repository with no package.json and no
# node_modules cannot be verified here at all. That case is UNVERIFIABLE with
# the reason named — never 'ok'.
verify_npm() {
  local mechanism=".npmrc (project scope)"
  local expected="${NEXUS_URL}/repository/${NPM_REPO}/"
  local component_url="${NEXUS_URL}/repository/${NPM_REPO}/${VERIFY_NPM_NAME}/-/${VERIFY_NPM_NAME}-${VERIFY_NPM_VERSION}.tgz"
  local spec="${VERIFY_NPM_NAME}@${VERIFY_NPM_VERSION}"
  local log="${TMP_DIR}/verify-npm.log"
  local dest="${TMP_DIR}/npm-pack"
  local observed_registry="" fetched="" bytes=0 rc=0

  if ! command -v npm > /dev/null 2>&1; then
    verify_row "npm" "$mechanism" "SKIPPED" \
      "npm is not on PATH, so nothing about npm routing was measured. A SKIP IS NOT A PASS: install npm and re-run --verify."
    return 0
  fi

  observed_registry="$( cd "$REPO_ROOT" && npm config get registry 2> "$log" )" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    verify_row "npm" "$mechanism" "FAILED" \
      "'npm config get registry' exited ${rc} in ${REPO_ROOT}: $(tr '\n' ' ' < "$log" | cut -c1-200)"
    return 0
  fi

  if [[ "$(strip_slash "$observed_registry")" != "$(strip_slash "$expected")" ]]; then
    verify_row "npm" "$mechanism" "FAILED" \
      "readback wrong: npm itself resolves registry to '${observed_registry}', not '${expected}'. npm reads .npmrc from its LOCAL PREFIX (the nearest ancestor holding package.json or node_modules), and an npm_config_registry environment variable outranks the file — check both before editing .npmrc."
    return 0
  fi

  if [[ ! -f "${REPO_ROOT}/package.json" && ! -d "${REPO_ROOT}/node_modules" ]]; then
    verify_row "npm" "$mechanism" "UNVERIFIABLE" \
      "npm reported registry '${observed_registry}', but there is no package.json and no node_modules at ${REPO_ROOT}, so npm's local prefix does not resolve here and that value came from somewhere else up the tree. Run 'npm init -y' (or add package.json) and re-run --verify. This row is NOT a pass."
    return 0
  fi

  mkdir -p "$dest"
  # A FRESH, EMPTY cache, and this is load-bearing rather than tidiness: a
  # tarball already in ~/.npm satisfies "a file appeared" with no network
  # traffic at all, which is a green row for a Nexus that was never contacted.
  # Retries are off and the fetch timeout is explicit so the call is bounded by
  # npm's own settings even where `timeout` is unavailable.
  rc=0
  ( cd "$REPO_ROOT" && bounded 90 env \
      npm_config_cache="${TMP_DIR}/npm-cache" \
      npm_config_fetch_retries=0 \
      npm_config_fetch_timeout=20000 \
      npm pack "$spec" --pack-destination "$dest" ) > "$log" 2>&1 || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    verify_row "npm" "$mechanism" "FAILED" \
      "readback is correct, but the fetch failed: 'npm pack ${spec}' exited ${rc}. $(diagnose_url "$component_url") npm's own output: $(tr '\n' ' ' < "$log" | cut -c1-300)"
    return 0
  fi

  fetched="$(find "$dest" -type f -name '*.tgz' | head -1)"
  if [[ -z "$fetched" ]]; then
    verify_row "npm" "$mechanism" "FAILED" \
      "'npm pack ${spec}' exited 0 but left no tarball in ${dest}, so nothing was actually downloaded: $(tr '\n' ' ' < "$log" | cut -c1-300)"
    return 0
  fi

  bytes="$(wc -c < "$fetched" | tr -d ' ')"
  verify_row "npm" "$mechanism" "ok" \
    "npm resolves registry=${observed_registry}; 'npm pack ${spec}' pulled ${bytes} bytes through it with an empty cache"
}

# pip (24-W0-11). The readback alone is not sufficient here and the gap is
# specific: PIP_INDEX_URL in the ENVIRONMENT outranks pip.conf, while
# 'pip config get' reports only what the FILE says. An operator with that
# variable set would get a correct readback, a successful download from public
# PyPI and a green row. pip's own 'Looking in indexes:' line is what closes it —
# that line names the index pip actually used.
verify_pip() {
  local mechanism="pip.conf via PIP_CONFIG_FILE"
  local expected="${NEXUS_URL}/repository/${PYPI_REPO}/simple"
  local simple_url="${NEXUS_URL}/repository/${PYPI_REPO}/simple/${VERIFY_PIP_PACKAGE}/"
  local pip_conf="${REPO_ROOT}/pip.conf"
  local log="${TMP_DIR}/verify-pip.log"
  local dest="${TMP_DIR}/pip-download"
  local observed="" looking="" pip_http="" fetched="" diag="" rc=0
  local -a pip_cmd=()

  if command -v pip3 > /dev/null 2>&1; then
    pip_cmd=(pip3)
  elif command -v pip > /dev/null 2>&1; then
    pip_cmd=(pip)
  elif command -v python3 > /dev/null 2>&1 && python3 -m pip --version > /dev/null 2>&1; then
    pip_cmd=(python3 -m pip)
  else
    verify_row "pip" "$mechanism" "SKIPPED" \
      "no pip on PATH (tried pip3, pip and 'python3 -m pip'), so nothing about pip routing was measured. A SKIP IS NOT A PASS."
    return 0
  fi

  if [[ ! -f "$pip_conf" ]]; then
    verify_row "pip" "$mechanism" "FAILED" \
      "there is no pip.conf at ${pip_conf}, so there is nothing for PIP_CONFIG_FILE to point at and pip is still using its own configuration."
    return 0
  fi

  # MEASURED on pip 26.2.1, and NOT what the obvious command does: with
  # PIP_CONFIG_FILE pointed at a file that plainly carries the key,
  # `pip config get global.index-url` exits 1 with "ERROR: No such key" under
  # every scope flag, while `pip config list` prints
  # global.index-url='<url>' from the same file in the same shell. `get` reads
  # the writable scopes (user/global/site) only and cannot see the ':env:'
  # variant that PIP_CONFIG_FILE creates. So the readback below uses
  # `config list`, which is also the better question: it reports pip's MERGED
  # view rather than one file's contents.
  rc=0
  env PIP_CONFIG_FILE="$pip_conf" "${pip_cmd[@]}" config list \
    > "${TMP_DIR}/pip-config-list.txt" 2> "$log" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    verify_row "pip" "$mechanism" "FAILED" \
      "'PIP_CONFIG_FILE=${pip_conf} ${pip_cmd[*]} config list' exited ${rc}: $(tr '\n' ' ' < "$log" | cut -c1-200)"
    return 0
  fi
  observed="$(sed -n "s/^global\.index-url='\(.*\)'\$/\1/p" "${TMP_DIR}/pip-config-list.txt" | head -1)"
  if [[ -z "$observed" ]]; then
    verify_row "pip" "$mechanism" "FAILED" \
      "with PIP_CONFIG_FILE=${pip_conf}, 'pip config list' reports no global.index-url at all, so pip is still resolving from its own default index. Observed: $(tr '\n' ' ' < "${TMP_DIR}/pip-config-list.txt" | cut -c1-200)"
    return 0
  fi

  if [[ "$(strip_slash "$observed")" != "$(strip_slash "$expected")" ]]; then
    verify_row "pip" "$mechanism" "FAILED" \
      "readback wrong: pip reads global.index-url as '${observed}', not '${expected}'."
    return 0
  fi

  mkdir -p "$dest"
  # --no-cache-dir for the same reason npm gets an empty cache: a wheel already
  # in pip's HTTP cache would satisfy "a file appeared" without one packet
  # reaching Nexus. --timeout and --retries bound the call from pip's own side.
  #
  # --no-input is not cosmetic. MEASURED against a Nexus with anonymous read
  # disabled: pip answers a 401 by PROMPTING on the terminal ("User for
  # <host>:"), so without it a verification fetch blocks forever on a developer's
  # TTY waiting for a username it must never be given — and `bounded` can only
  # rescue that on a machine where timeout(1) exists. With --no-input pip fails
  # the request instead, which is the answer the table needs.
  rc=0
  bounded 120 env PIP_CONFIG_FILE="$pip_conf" "${pip_cmd[@]}" download "$VERIFY_PIP_PACKAGE" \
    --no-deps --no-cache-dir --no-input --disable-pip-version-check \
    --dest "$dest" --timeout 10 --retries 0 > "$log" 2>&1 || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    # pip prints the component-level status itself, which is a better witness
    # than any probe this script could make: it is the status pip's own request
    # received, through pip's own configuration.
    pip_http="$(grep -oE 'HTTP error [0-9]{3}' "$log" | head -1)" || pip_http=""
    case "$pip_http" in
      *401*)
        diag="SERVER-SIDE ANONYMOUS ACCESS: pip's own request was answered HTTP 401. Anonymous read is NOT enabled on this Nexus — the server-side value responsible is anonymous.enabled."
        ;;
      *403*)
        diag="SERVER-SIDE LICENCE REFUSAL: pip's own COMPONENT request was answered HTTP 403 — the Sonatype licence gate, not a client misconfiguration. The server-side value responsible is eula.accepted. Measured, plan 24-02: a PyPI simple page answers 200 even while the licence is unaccepted, because it is metadata; only a component download such as this one sees the gate."
        ;;
      *)
        diag="$(diagnose_url "$simple_url") NOTE (measured, plan 24-02): a 200 from a PyPI simple page is METADATA and is NOT evidence that the server's licence is accepted — only a component download shows the eula.accepted gate."
        ;;
    esac
    verify_row "pip" "$mechanism" "FAILED" \
      "readback is correct, but the fetch failed: '${pip_cmd[*]} download ${VERIFY_PIP_PACKAGE}' exited ${rc}. ${diag} pip's own output: $(tr '\n' ' ' < "$log" | cut -c1-300)"
    return 0
  fi

  looking="$(grep -m1 'Looking in indexes:' "$log")" || looking=""
  if [[ -z "$looking" ]]; then
    verify_row "pip" "$mechanism" "FAILED" \
      "the download succeeded but pip never printed a 'Looking in indexes:' line, which it prints whenever the index is not its own default — so this wheel may have come from public PyPI rather than from ${expected}. pip's output: $(tr '\n' ' ' < "$log" | cut -c1-300)"
    return 0
  fi
  case "$looking" in
    *"$(strip_slash "$expected")"*)
      :
      ;;
    *)
      verify_row "pip" "$mechanism" "FAILED" \
        "the download succeeded, but pip reports '${looking}' — a different index from ${expected}. PIP_INDEX_URL in the environment outranks pip.conf and 'pip config get' cannot see it; unset it in this shell and re-run --verify."
      return 0
      ;;
  esac

  fetched="$(find "$dest" -type f | head -1)"
  if [[ -z "$fetched" ]]; then
    verify_row "pip" "$mechanism" "FAILED" \
      "'${pip_cmd[*]} download ${VERIFY_PIP_PACKAGE}' exited 0 but left no file in ${dest}: $(tr '\n' ' ' < "$log" | cut -c1-300)"
    return 0
  fi

  verify_row "pip" "$mechanism" "ok" \
    "pip reads global.index-url=${observed} and reports '${looking}'; downloaded $(basename "$fetched") with the cache disabled"
}

# Helm (24-W0-12). The env redirect IS the mechanism, so this stage also has to
# prove what it did NOT touch: the operator's global repository list is
# fingerprinted before and after, and a change there is a failure even if every
# fetch succeeded.
verify_helm() {
  local mechanism=".helm/repositories.yaml via env redirect"
  local expected="${NEXUS_URL}/repository/${HELM_REPO}/"
  local index_url="${NEXUS_URL}/repository/${HELM_REPO}/index.yaml"
  local helm_cfg="${REPO_ROOT}/.helm/repositories.yaml"
  local helm_cache="${REPO_ROOT}/.helm/cache"
  local log="${TMP_DIR}/verify-helm.log"
  local out="${TMP_DIR}/verify-helm.json"
  local global_cfg="" before="" after="" rows=0 rc=0

  if ! command -v helm > /dev/null 2>&1; then
    verify_row "helm" "$mechanism" "SKIPPED" \
      "helm is not on PATH, so nothing about Helm routing was measured. A SKIP IS NOT A PASS."
    return 0
  fi

  # Read with the redirect removed, so this names the operator's REAL global
  # list even in a shell that has already sourced a .nexus-env.
  global_cfg="$(env -u HELM_REPOSITORY_CONFIG helm env HELM_REPOSITORY_CONFIG | tr -d '"')"
  before="$(digest_of "$global_cfg")"

  if [[ ! -f "$helm_cfg" ]]; then
    verify_row "helm" "$mechanism" "FAILED" \
      "there is no ${helm_cfg}, so 'helm repo add' never completed and HELM_REPOSITORY_CONFIG has nothing to point at. $(diagnose_url "$index_url")"
    return 0
  fi

  rc=0
  bounded 30 env HELM_REPOSITORY_CONFIG="$helm_cfg" HELM_REPOSITORY_CACHE="$helm_cache" \
    helm repo list -o json > "$out" 2> "$log" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    verify_row "helm" "$mechanism" "FAILED" \
      "'helm repo list' exited ${rc} against ${helm_cfg}: $(tr '\n' ' ' < "$log" | cut -c1-200)"
    return 0
  fi
  if ! grep -Fq "\"${HELM_REPO_NAME}\"" "$out" || ! grep -Fq "$(strip_slash "$expected")" "$out"; then
    verify_row "helm" "$mechanism" "FAILED" \
      "readback wrong: with HELM_REPOSITORY_CONFIG pointed at ${helm_cfg}, 'helm repo list' does not show an entry named '${HELM_REPO_NAME}' at ${expected}. Observed: $(tr '\n' ' ' < "$out" | cut -c1-200)"
    return 0
  fi

  rc=0
  bounded 120 env HELM_REPOSITORY_CONFIG="$helm_cfg" HELM_REPOSITORY_CACHE="$helm_cache" \
    helm repo update "$HELM_REPO_NAME" > "$log" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    verify_row "helm" "$mechanism" "FAILED" \
      "the entry exists, but 'helm repo update ${HELM_REPO_NAME}' exited ${rc}, so no index.yaml was fetched. $(diagnose_url "$index_url") Helm's own output: $(tr '\n' ' ' < "$log" | cut -c1-300)"
    return 0
  fi

  # MEASURED on helm v4.3.0, and the reason the pattern below is NOT anchored:
  # `helm search repo -r '^nexus/'` reports "No results found" on an index whose
  # every row is named 'nexus/<chart>', while `-r 'nexus/'` returns all of them.
  # Helm's regexp search is not applied to the start of the 'repo/chart' string,
  # so an anchored pattern silently matches nothing — a false FAILED row. The
  # anchoring is done afterwards instead, on the JSON, where it is exact:
  # --fail-on-no-result only proves SOME row matched, and a chart in another
  # repository whose name contains 'nexus/' would satisfy it.
  rc=0
  bounded 60 env HELM_REPOSITORY_CONFIG="$helm_cfg" HELM_REPOSITORY_CACHE="$helm_cache" \
    helm search repo -r "${HELM_REPO_NAME}/" --fail-on-no-result -o json > "$out" 2> "$log" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    verify_row "helm" "$mechanism" "FAILED" \
      "'helm repo update' succeeded but 'helm search repo -r ${HELM_REPO_NAME}/' returned no row, so the index that was fetched carries no chart. Either the Nexus ${HELM_REPO} repository proxies nothing (the chart ships repos.helm.remoteUrl as null and creates that repository only when a consumer sets it), or the index is empty. Helm's own output: $(tr '\n' ' ' < "$log" | cut -c1-300)"
    return 0
  fi
  # Occurrences, not matching LINES: `helm search repo -o json` emits the whole
  # array on ONE line, so `grep -c` would report 1 for any non-empty result.
  rows="$(grep -o "\"name\":\"${HELM_REPO_NAME}/" "$out" | wc -l | tr -d ' ')" || rows=0
  if [[ "$rows" -eq 0 ]]; then
    verify_row "helm" "$mechanism" "FAILED" \
      "'helm search repo -r ${HELM_REPO_NAME}/' returned rows, but none of them belongs to the '${HELM_REPO_NAME}' repository this script configured — they came from another repository in ${helm_cfg}. Observed: $(tr '\n' ' ' < "$out" | cut -c1-200)"
    return 0
  fi

  after="$(digest_of "$global_cfg")"
  if [[ "$after" != "$before" ]]; then
    verify_row "helm" "$mechanism" "FAILED" \
      "every Helm fetch succeeded, but the operator's GLOBAL repository list ${global_cfg} changed during verification (${before} -> ${after}). HELM_REPOSITORY_CONFIG and HELM_REPOSITORY_CACHE are the entire mechanism keeping this repository-scoped, and something escaped them."
    return 0
  fi

  verify_row "helm" "$mechanism" "ok" \
    "'helm repo list' shows '${HELM_REPO_NAME}' at ${expected}; 'helm repo update' fetched its index and 'helm search repo -r ${HELM_REPO_NAME}/' returned ${rows} chart row(s) from that repository; the global list ${global_cfg} is unchanged (${before})"
}

# Docker. MANUAL under every condition, and never 'ok' — not because the fetch
# was not attempted but because there is nothing per-repository to attempt. No
# Docker client reads any file in this repository.
verify_docker() {
  verify_row "docker" "none - no per-repo mechanism exists" "MANUAL" \
    "NEXUS_DOCKER_REGISTRY=${NEXUS_HOST}/${DOCKER_REPO} — nothing routes until an image REFERENCE is edited to start with that prefix, e.g. 'docker pull ${NEXUS_HOST}/${DOCKER_REPO}/library/alpine:3.21'.${DOCKER_VERIFY_NOTE}"
}

run_verify() {
  local row eco mech status obs

  echo ""
  echo "Nexus routing verification"
  echo "--------------------------"
  echo "Repository: ${REPO_ROOT}"
  echo "Nexus:      ${NEXUS_URL}"
  echo ""

  if [[ -z "$BOUND_TOOL" ]]; then
    warn "neither 'timeout' nor 'gtimeout' is on PATH. The npm and pip fetches below are still bounded by those clients' own timeout settings, but 'helm repo update' has no timeout flag of its own in Helm v4, so that one call is UNBOUNDED on this machine. Install GNU coreutils to bound it."
  fi

  verify_npm
  verify_pip
  verify_helm
  verify_docker

  printf "%-9s %-42s %-13s %s\n" "ECOSYSTEM" "MECHANISM" "STATUS" "OBSERVED"
  printf "%-9s %-42s %-13s %s\n" "---------" "---------" "------" "--------"
  for row in "${VERIFY_ROWS[@]}"; do
    IFS='|' read -r eco mech status obs <<< "$row"
    printf "%-9s %-42s %-13s %s\n" "$eco" "$mech" "$status" "$obs"
  done

  echo ""
  echo "Rows: ${VERIFY_OK} ok, ${VERIFY_BAD} not ok, ${VERIFY_MANUAL} MANUAL."
  echo ""
  echo "What 'ok' means here: that client, run from this repository, resolved this"
  echo "Nexus AND pulled a real component through it just now. What it does not mean:"
  echo "that any other shell is configured — pip and Helm need 'source .nexus-env' in"
  echo "every shell that uses them."
  echo ""
  echo "MANUAL is not a pass and never becomes one. Docker has no per-repository"
  echo "configuration of any kind, so no run of this script can prove a Docker pull"
  echo "routes; and even a machine-global mirror only ever affects docker.io"
  echo "references — ghcr.io, quay.io and public.ecr.aws are never mirrored."
  if [[ "$VERIFY_BAD" -gt 0 ]]; then
    echo ""
    echo "${VERIFY_BAD} row(s) above are not 'ok'. This run exits non-zero."
  fi
}

# ---------------------------------------------------------------------------
# End-of-run report
# ---------------------------------------------------------------------------
#
# T-24-33. There is no "Setup complete" line here and there must never be one.
# Every row states what was WRITTEN, and the closing paragraph states plainly
# that writing a config file is not evidence that any client reads it.
print_report() {
  echo ""
  echo "Nexus routing report"
  echo "--------------------"
  echo "Repository: ${REPO_ROOT}"
  echo "Nexus:      ${NEXUS_URL}"
  echo ""
  printf "%-9s %s\n" "npm"    "$NPM_STATUS"
  printf "%-9s %s\n" "pip"    "$PIP_STATUS"
  printf "%-9s %s\n" "helm"   "$HELM_STATUS"
  printf "%-9s %s\n" "docker" "$DOCKER_STATUS"
  printf "%-9s %s\n" "daemon" "$DOCKER_DAEMON_STATUS"
  printf "%-9s %s\n" ".gitignore" "$GITIGNORE_STATUS"
  echo ""
  echo "Files generated this run: ${CONFIG_COUNT} (existing files are left alone unless --force)"
  echo ""
  echo "To make pip and Helm use any of this, run in this shell:"
  echo ""
  echo "    source .nexus-env"
  echo ""
  echo "npm needs no environment. Docker has no per-repository mechanism at all:"
  echo "NEXUS_DOCKER_REGISTRY is a prefix you paste into an image reference, and"
  echo "even a machine-global Docker mirror would only ever affect Docker Hub"
  echo "references — ghcr.io, quay.io and public.ecr.aws are never routed by one."
  echo ""
  if [[ "$VERIFY" = true ]]; then
    echo "NOT PROVEN BY THE ROWS ABOVE. They say what was WRITTEN. The verification"
    echo "table below is the part that measures whether any client reads it."
  else
    echo "NOT PROVEN. Nothing above shows that any client actually reaches this"
    echo "Nexus; writing a configuration file is not the same as a client reading"
    echo "it. Re-run this command with --verify to measure it, per ecosystem."
  fi
}

# ---------------------------------------------------------------------------
# Main execution
# ---------------------------------------------------------------------------

# ARGUMENT PARSING DIVERGES FROM THE ANALOG, DELIBERATELY. workstation/setup.sh
# iterates 'for arg in "$@"' with a case over bare words, which cannot take an
# option ARGUMENT. This script's --url does take one, so it uses a shift loop
# instead. That is a considered divergence from the in-repo pattern, not an
# oversight — noted here so a future reader does not "restore" the analog's
# shape and break --url.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      if [[ $# -lt 2 ]]; then
        err "--url requires a value, e.g. --url https://nexus.example.com"
        usage
        exit 1
      fi
      NEXUS_URL_RAW="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --commit-config)
      COMMIT_CONFIG=true
      shift
      ;;
    --docker-daemon)
      DOCKER_DAEMON=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --verify)
      VERIFY=true
      shift
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

# Checked AFTER the loop so --help and an unknown argument are both reachable
# without a URL. A missing --url is an error, never a default.
if [[ -z "$NEXUS_URL_RAW" ]]; then
  err "--url is required and was not supplied. There is no default Nexus URL and this script will not guess one."
  usage
  exit 1
fi

validate_url "$NEXUS_URL_RAW"

# The '|| pwd' fallback is the convention workstation/setup.sh already uses
# (line 846). It exists so the script still has a target directory when run
# outside a git repository; every acceptance path for this script is inside one,
# and the report below names the directory it wrote to either way.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if ! git -C "$REPO_ROOT" rev-parse --show-toplevel > /dev/null 2>&1; then
  warn "${REPO_ROOT} is not inside a git repository, so the target directory came from the current working directory rather than from 'git rev-parse --show-toplevel'. Everything below is written HERE. The .gitignore step has nothing to protect."
fi

if [[ -n "$NEXUS_PATH" ]]; then
  warn "--url carries the path '${NEXUS_PATH}'. It is kept for the npm, pip and Helm URLs, which are built by appending '/repository/<repo>/' to the URL you gave. It is NOT carried into the Docker registry prefix: a Docker image reference has no room for it, because the client inserts '/v2/' immediately after the host."
fi

info "Target repository: ${REPO_ROOT}"
info "Nexus base URL:    ${NEXUS_URL} (scheme ${NEXUS_SCHEME}, host ${NEXUS_HOST})"
log "Host without port: ${NEXUS_HOST_NO_PORT} (pip treats it as loopback: ${NEXUS_IS_LOOPBACK})"
log "Options:           force=${FORCE} commit-config=${COMMIT_CONFIG}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# ORDERING IS BINDING, not incidental. npm and pip are configured BEFORE the
# Helm writer, because 'helm repo add' reaches the network and can fail — and
# when it does, the files written above must already exist rather than being
# lost to an unreachable chart repository.
configure_npm
configure_pip
configure_helm

# Written after the Helm writer on purpose, and written even when that writer
# failed: an unreachable chart repository must not cost the developer the env
# file and the .gitignore entries.
write_nexus_env
update_gitignore

# LAST of the writers, and the only one that leaves the repository. Kept after
# every repository-scoped write so that a failure here cannot cost the
# developer the files that do not depend on it.
if [[ "$DOCKER_DAEMON" = true ]]; then
  configure_docker_daemon
fi

print_report

# LAST, on purpose. The final thing this script prints must be measured
# evidence rather than a claim: an `info "done"` as the closing line is the
# warning sign Pitfall 10 names.
if [[ "$VERIFY" = true ]]; then
  run_verify
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
