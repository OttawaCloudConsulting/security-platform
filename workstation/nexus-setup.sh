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

# The repository entry name written into .helm/repositories.yaml. Stable, so a
# re-run updates one entry rather than accumulating them.
HELM_REPO_NAME="nexus"

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
  local registry_url="${NEXUS_URL}/repository/npm-proxy/"
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
  local index_url="${NEXUS_URL}/repository/pypi-proxy/simple"

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
  local repo_url="${NEXUS_URL}/repository/helm-proxy/"
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
  local docker_prefix="${NEXUS_HOST}/docker-proxy"

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
  echo "NOT PROVEN. Nothing above shows that any client actually reaches this"
  echo "Nexus; writing a configuration file is not the same as a client reading"
  echo "it. The verification pass that would prove it, --verify, is not"
  echo "implemented in this version of the script."
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
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --verify)
      # Recognised, and deliberately not implemented in this version. The
      # verification pass is plan 24-07's deliverable. Failing here with one
      # line — rather than falling through to the unknown-argument branch and
      # printing usage — is the honest answer: a flag that cannot verify
      # anything must not emit output that reads like a verification report.
      # Plan 24-07 replaces this arm with the real implementation.
      err "--verify is not implemented in this version of the script. Nothing was verified and nothing was written."
      exit 1
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

print_report

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
