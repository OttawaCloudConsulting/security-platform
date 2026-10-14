#!/bin/bash
# Ubuntu prerequisites: apt metadata, HTTPS transport, Bash. Bash 3.2-safe.

apt_get() { DEBIAN_FRONTEND=noninteractive $SUDO apt-get -y "$@"; }

ubuntu_transport() {
  local missing="" p
  for p in ca-certificates curl; do
    dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"
  done
  [ -z "$missing" ] && return 0
  if [ "$DRY_RUN" = 1 ]; then log "DRY-RUN: apt-get install$missing"; return 0; fi
  # shellcheck disable=SC2086
  apt_get install $missing || die "could not install$missing"
}

ubuntu_bash() {
  local before after
  BASH5=/bin/bash
  before="$(wst_bash_version "$BASH5")"
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: apt-get install --only-upgrade bash (current: ${before:-none})"
    return 0
  fi
  apt_get install --only-upgrade bash || die "could not upgrade bash"
  after="$(wst_bash_version "$BASH5")"
  [ "$before" = "$after" ] || BASH_CHANGED=1
}

os_prepare() {
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: apt-get update"
  else
    apt_get update -qq || die "apt-get update failed"
  fi
  ubuntu_transport
  ubuntu_bash
}

os_login_shell() { getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7; }

os_prereq_versions() { :; }
