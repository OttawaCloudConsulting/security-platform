#!/bin/bash
# containers group on Ubuntu: Docker's official apt repository. The repo and
# key are added at install time only (never during discovery or dry-run);
# "latest" and pins are read from the repo's Packages index.
# shellcheck source=../../common/handlers.sh
. "$WST_ROOT/scripts/common/handlers.sh"

DOCKER_APT_URL=https://download.docker.com/linux/ubuntu
DOCKER_KEY_FPR=9DC858229FC7DD38854AE2D88D81803C0EBFCD88

docker_codename() { ( . /etc/os-release; printf '%s\n' "${UBUNTU_CODENAME:-$VERSION_CODENAME}" ); }
docker_dpkg_arch() { if [ "$WST_ARCH" = arm64 ]; then echo arm64; else echo amd64; fi; }

# docker_versions <package>: every version in the repo index, one per line.
docker_versions() {
  local idx
  idx="$(_curl "$DOCKER_APT_URL/dists/$(docker_codename)/stable/binary-$(docker_dpkg_arch)/Packages.gz" | gunzip -c)" || return 1
  awk -v p="$1" '$1=="Package:"{cur=$2} $1=="Version:" && cur==p{print $2}' <<< "$idx"
}
docker_latest() {
  local v best="" all
  all="$(docker_versions "$1")" || return 1
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    if [ -z "$best" ] || dpkg --compare-versions "$v" gt "$best"; then best="$v"; fi
  done <<< "$all"
  [ -n "$best" ] && printf '%s\n' "$best"
}
# docker_resolve <package> <pin>: the full repo version a pin refers to.
docker_resolve() {
  local v all
  all="$(docker_versions "$1")" || return 1
  while IFS= read -r v; do
    case "${v#*:}" in "$2"|"$2"-*|"$2"+*) printf '%s\n' "$v"; return 0 ;; esac
    [ "$v" = "$2" ] && { printf '%s\n' "$v"; return 0; }
  done <<< "$all"
  return 1
}

docker_repo_setup() {
  local key=/etc/apt/keyrings/docker.asc list=/etc/apt/sources.list.d/docker.list tmp="$TOOL_TMP/docker.gpg" fpr line
  apt_get install ca-certificates curl gnupg >/dev/null || return 1
  ${SUDO:-} install -m 0755 -d /etc/apt/keyrings
  if ! [ -s "$key" ]; then
    _curl -o "$tmp" "$DOCKER_APT_URL/gpg" || die "could not fetch the Docker apt key"
    fpr="$(gpg --show-keys --with-colons "$tmp" | awk -F: '$1=="fpr"{print $10; exit}')"
    [ "$fpr" = "$DOCKER_KEY_FPR" ] || die "Docker apt key fingerprint mismatch ($fpr)"
    ${SUDO:-} install -m 0644 "$tmp" "$key"
  fi
  line="deb [arch=$(docker_dpkg_arch) signed-by=$key] $DOCKER_APT_URL $(docker_codename) stable"
  [ "$(cat "$list" 2>/dev/null)" = "$line" ] || printf '%s\n' "$line" | ${SUDO:-} tee "$list" >/dev/null
  apt_get update >/dev/null
}

# docker_apt_tool <id> <package> <bin|-> <validate cmd> [extra packages]
docker_apt_tool() {
  local id="$1" pkg="$2" bin="$3" vcmd="$4" extra="${5:-}" fn="${1//-/_}"
  apt_tool "$id" "$pkg" "$bin" "$vcmd"   # probe/remove/validate; the rest is repo-aware
  eval "
tool_${fn}_latest() { docker_latest '$pkg'; }
tool_${fn}_pin_ok() { docker_resolve '$pkg' \"\$1\" >/dev/null; }
tool_${fn}_install() {
  local v
  v=\$(docker_resolve '$pkg' \"\$1\") || die \"version \$1 is not in the Docker apt repository\"
  docker_repo_setup || return 1
  apt_get install '$pkg='\"\$v\" $extra >/dev/null || return 1
  result_set \"\$2\" integrity package-manager
}
"
}

docker_apt_tool docker-cli docker-ce-cli docker 'docker --version'
docker_apt_tool docker-engine docker-ce dockerd 'dockerd --version' containerd.io
docker_apt_tool docker-compose docker-compose-plugin - 'docker compose version'
docker_apt_tool docker-buildx docker-buildx-plugin - 'docker buildx version'
