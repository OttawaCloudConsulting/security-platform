#!/bin/bash
# Tool installer: pinned/latest release binaries into BIN_DIR (no package manager).
# Requires lib/common.sh, load_config, detect_platform. bash 3.2-safe.
#
# Pin precedence: TOOL_VERSION_<NAME> from versions.conf or the config file;
# otherwise the latest upstream release. versions.lock records what was
# installed (output only; copy it to versions.conf to pin another machine).

LOCK_FILE="$KIT_ROOT/versions.lock"
UPDATE_TOOLS="${UPDATE_TOOLS:-0}"
TOOL_TMP=""

_curl() { curl -fsSL --retry 3 --connect-timeout 15 "$@"; }
fetch() { _curl -o "$2" "$1"; }

gh_latest_tag() { # gh_latest_tag owner/repo -> tag name
  local url
  url="$(_curl -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")" || return 1
  printf '%s\n' "${url##*/}"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# checksum_lookup <sums file> <asset name>: handles "hash  name", "hash *name",
# "SHA256 (name) = hash" (BSD style: only the SHA256 line) and single-hash files.
checksum_lookup() {
  awk -v n="$2" '
    NF==1 && length($1)==64 && $1 ~ /^[0-9a-fA-F]+$/ { print $1; exit }
    $2==n || $2=="*" n { print $1; exit }
    index($0, "(" n ") = ") > 0 && $1 ~ /^SHA-?256$/ { print $NF; exit }
  ' "$1"
}

# verify_download <file> <asset name> <checksum url>...
verify_download() {
  local file="$1" name="$2" u expected="" actual i=0
  shift 2
  for u in "$@"; do
    i=$((i + 1))
    if fetch "$u" "$TOOL_TMP/sums.$i" 2>/dev/null; then
      expected="$(checksum_lookup "$TOOL_TMP/sums.$i" "$name")"
      [ -n "$expected" ] && break
    fi
    expected=""
  done
  if [ -z "$expected" ]; then
    [ "$REQUIRE_CHECKSUMS" = 1 ] && die "no published checksum found for $name (REQUIRE_CHECKSUMS=1)"
    warn "no published checksum for $name; installed unverified (HTTPS only)"
    return 0
  fi
  expected="$(printf '%s' "$expected" | tr 'A-F' 'a-f')"
  actual="$(sha256_of "$file")"
  [ "$actual" = "$expected" ] || die "checksum mismatch for $name (expected $expected, got $actual)"
  log "checksum ok: $name"
}

put_bin() { # put_bin <src> <name>
  mkdir -p "$BIN_DIR"
  install -m 0755 "$1" "$BIN_DIR/$2"
}

find_in() { # find_in <dir> <filename>: first regular file with that name
  find "$1" -type f -name "$2" | head -n 1
}

# --- lock file ---------------------------------------------------------------
lock_get() { [ -f "$LOCK_FILE" ] && sed -n "s/^$1=//p" "$LOCK_FILE" | head -n 1 || true; }
lock_set() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/wsk-lock.XXXXXX")"
  { [ -f "$LOCK_FILE" ] && grep -v "^$1=" "$LOCK_FILE" || true; printf '%s=%s\n' "$1" "$2"; } > "$tmp"
  sort "$tmp" > "$LOCK_FILE"
  rm -f "$tmp"
}

tool_bins() {
  case "$1" in
    age)    echo "age age-keygen" ;;
    awscli) echo "aws aws_completer" ;;
    *)      echo "$1" ;;
  esac
}

# --- per-tool definitions: tool_<n>_latest, tool_<n>_install <version> --------
tool_jq_latest() { local t; t="$(gh_latest_tag jqlang/jq)" || return 1; echo "${t#jq-}"; }
tool_jq_install() {
  local v="$1" os asset base
  if [ "$KIT_OS" = darwin ]; then os=macos; else os=linux; fi
  asset="jq-$os-$KIT_ARCH"
  base="https://github.com/jqlang/jq/releases/download/jq-$v"
  fetch "$base/$asset" "$TOOL_TMP/$asset"
  verify_download "$TOOL_TMP/$asset" "$asset" "$base/sha256sum.txt"
  put_bin "$TOOL_TMP/$asset" jq
}

tool_yq_latest() { local t; t="$(gh_latest_tag mikefarah/yq)" || return 1; echo "${t#v}"; }
tool_yq_install() {
  local v="$1" asset base
  asset="yq_${KIT_OS}_${KIT_ARCH}"
  base="https://github.com/mikefarah/yq/releases/download/v$v"
  fetch "$base/$asset" "$TOOL_TMP/$asset"
  verify_download "$TOOL_TMP/$asset" "$asset" "$base/checksums-bsd"
  put_bin "$TOOL_TMP/$asset" yq
}

tool_direnv_latest() { local t; t="$(gh_latest_tag direnv/direnv)" || return 1; echo "${t#v}"; }
tool_direnv_install() {
  local v="$1" asset base
  asset="direnv.${KIT_OS}-${KIT_ARCH}"
  base="https://github.com/direnv/direnv/releases/download/v$v"
  fetch "$base/$asset" "$TOOL_TMP/$asset"
  verify_download "$TOOL_TMP/$asset" "$asset" "$base/checksums.txt"
  put_bin "$TOOL_TMP/$asset" direnv
}

tool_gh_latest() { local t; t="$(gh_latest_tag cli/cli)" || return 1; echo "${t#v}"; }
tool_gh_install() {
  local v="$1" asset base bin
  base="https://github.com/cli/cli/releases/download/v$v"
  if [ "$KIT_OS" = darwin ]; then asset="gh_${v}_macOS_${KIT_ARCH}.zip"; else asset="gh_${v}_linux_${KIT_ARCH}.tar.gz"; fi
  fetch "$base/$asset" "$TOOL_TMP/$asset"
  verify_download "$TOOL_TMP/$asset" "$asset" "$base/gh_${v}_checksums.txt"
  mkdir -p "$TOOL_TMP/x"
  if [ "$KIT_OS" = darwin ]; then unzip -q -o "$TOOL_TMP/$asset" -d "$TOOL_TMP/x"; else tar -xzf "$TOOL_TMP/$asset" -C "$TOOL_TMP/x"; fi
  bin="$(find "$TOOL_TMP/x" -type f -name gh -path '*/bin/*' | head -n 1)"
  [ -n "$bin" ] || die "gh binary not found in archive"
  put_bin "$bin" gh
}

tool_kubectl_latest() { local t; t="$(_curl https://dl.k8s.io/release/stable.txt)" || return 1; echo "${t#v}"; }
tool_kubectl_install() {
  local v="$1" base
  base="https://dl.k8s.io/release/v$v/bin/$KIT_OS/$KIT_ARCH"
  fetch "$base/kubectl" "$TOOL_TMP/kubectl"
  verify_download "$TOOL_TMP/kubectl" kubectl "$base/kubectl.sha256"
  put_bin "$TOOL_TMP/kubectl" kubectl
}

tool_helm_latest() { local t; t="$(gh_latest_tag helm/helm)" || return 1; echo "${t#v}"; }
tool_helm_install() {
  local v="$1" asset base
  asset="helm-v${v}-${KIT_OS}-${KIT_ARCH}.tar.gz"
  base="https://get.helm.sh"
  fetch "$base/$asset" "$TOOL_TMP/$asset"
  verify_download "$TOOL_TMP/$asset" "$asset" "$base/$asset.sha256sum"
  mkdir -p "$TOOL_TMP/x"
  tar -xzf "$TOOL_TMP/$asset" -C "$TOOL_TMP/x"
  put_bin "$(find_in "$TOOL_TMP/x" helm)" helm
}

tool_starship_latest() { local t; t="$(gh_latest_tag starship/starship)" || return 1; echo "${t#v}"; }
tool_starship_install() {
  local v="$1" asset base triple a
  if [ "$KIT_ARCH" = arm64 ]; then a=aarch64; else a=x86_64; fi
  if [ "$KIT_OS" = darwin ]; then triple="${a}-apple-darwin"; else triple="${a}-unknown-linux-musl"; fi
  asset="starship-${triple}.tar.gz"
  base="https://github.com/starship/starship/releases/download/v$v"
  fetch "$base/$asset" "$TOOL_TMP/$asset"
  verify_download "$TOOL_TMP/$asset" "$asset" "$base/$asset.sha256"
  mkdir -p "$TOOL_TMP/x"
  tar -xzf "$TOOL_TMP/$asset" -C "$TOOL_TMP/x"
  put_bin "$(find_in "$TOOL_TMP/x" starship)" starship
}

tool_sops_latest() { local t; t="$(gh_latest_tag getsops/sops)" || return 1; echo "${t#v}"; }
tool_sops_install() {
  local v="$1" asset base
  asset="sops-v${v}.${KIT_OS}.${KIT_ARCH}"
  base="https://github.com/getsops/sops/releases/download/v$v"
  fetch "$base/$asset" "$TOOL_TMP/$asset"
  verify_download "$TOOL_TMP/$asset" "$asset" "$base/sops-v${v}.checksums.txt"
  put_bin "$TOOL_TMP/$asset" sops
}

tool_age_latest() { local t; t="$(gh_latest_tag FiloSottile/age)" || return 1; echo "${t#v}"; }
tool_age_install() {
  local v="$1" asset base
  asset="age-v${v}-${KIT_OS}-${KIT_ARCH}.tar.gz"
  base="https://github.com/FiloSottile/age/releases/download/v$v"
  fetch "$base/$asset" "$TOOL_TMP/$asset"
  verify_download "$TOOL_TMP/$asset" "$asset" "$base/age-v${v}-checksums.txt"
  mkdir -p "$TOOL_TMP/x"
  tar -xzf "$TOOL_TMP/$asset" -C "$TOOL_TMP/x"
  put_bin "$(find_in "$TOOL_TMP/x" age)" age
  put_bin "$(find_in "$TOOL_TMP/x" age-keygen)" age-keygen
}

tool_terraform_latest() {
  # releases index lists newest first; skip pre-releases (they contain '-').
  _curl https://releases.hashicorp.com/terraform/ \
    | grep -o 'terraform/[0-9][0-9.]*/' | head -n 1 | cut -d/ -f2
}
tool_terraform_install() {
  local v="$1" asset base
  asset="terraform_${v}_${KIT_OS}_${KIT_ARCH}.zip"
  base="https://releases.hashicorp.com/terraform/$v"
  fetch "$base/$asset" "$TOOL_TMP/$asset"
  verify_download "$TOOL_TMP/$asset" "$asset" "$base/terraform_${v}_SHA256SUMS"
  mkdir -p "$TOOL_TMP/x"
  unzip -q -o "$TOOL_TMP/$asset" -d "$TOOL_TMP/x"
  put_bin "$TOOL_TMP/x/terraform" terraform
}

# awscli: not a GitHub release. macOS: signed .pkg installed at user level.
# Linux: official zip installer into ~/.local/aws-cli. Neither publishes a
# sha256; macOS verifies the pkg signature, Linux relies on HTTPS.
tool_awscli_latest() {
  _curl https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst \
    | awk '/^[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }'
}
tool_awscli_install() {
  local v="$1" loc="$HOME/.local" a
  mkdir -p "$loc" "$BIN_DIR"
  if [ "$KIT_OS" = darwin ]; then
    fetch "https://awscli.amazonaws.com/AWSCLIV2-$v.pkg" "$TOOL_TMP/AWSCLIV2.pkg"
    pkgutil --check-signature "$TOOL_TMP/AWSCLIV2.pkg" >/dev/null 2>&1 \
      || die "AWS CLI pkg signature check failed"
    cat > "$TOOL_TMP/choices.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <array>
    <dict>
      <key>choiceAttribute</key><string>customLocation</string>
      <key>attributeSetting</key><string>$loc</string>
      <key>choiceIdentifier</key><string>default</string>
    </dict>
  </array>
</plist>
EOF
    installer -pkg "$TOOL_TMP/AWSCLIV2.pkg" -target CurrentUserHomeDirectory \
      -applyChoiceChangesXML "$TOOL_TMP/choices.xml" >/dev/null
  else
    if [ "$KIT_ARCH" = arm64 ]; then a=aarch64; else a=x86_64; fi
    warn "awscli: no published checksum on Linux; installed over HTTPS only"
    fetch "https://awscli.amazonaws.com/awscli-exe-linux-$a-$v.zip" "$TOOL_TMP/awscli.zip"
    unzip -q -o "$TOOL_TMP/awscli.zip" -d "$TOOL_TMP/x"
    "$TOOL_TMP/x/aws/install" -i "$loc/aws-cli" -b "$BIN_DIR" --update >/dev/null
  fi
  ln -sf "$loc/aws-cli/aws" "$BIN_DIR/aws"
  ln -sf "$loc/aws-cli/aws_completer" "$BIN_DIR/aws_completer"
}

# --- driver ------------------------------------------------------------------
_pinned_version() { # _pinned_version <tool>
  local var="TOOL_VERSION_$(printf '%s' "$1" | tr 'a-z' 'A-Z')" v
  eval "v=\${$var:-}"
  printf '%s\n' "${v#v}"
}

_tool_present() { [ -x "$BIN_DIR/$(tool_bins "$1" | cut -d' ' -f1)" ]; }

install_tools() {
  local t pin cur want rc failed=""
  for t in $INSTALL_TOOLS; do
    if ! type "tool_${t}_install" >/dev/null 2>&1; then
      warn "unknown tool '$t' in INSTALL_TOOLS; skipping"
      continue
    fi
    pin="$(_pinned_version "$t")"
    cur="$(lock_get "$t")"
    if [ -n "$pin" ]; then
      want="$pin"
    elif _tool_present "$t" && [ "$UPDATE_TOOLS" != 1 ]; then
      log "tool $t: already installed (${cur:-unknown version}); use --update-tools to refresh"
      continue
    elif [ "$DRY_RUN" = 1 ]; then
      log "DRY-RUN: would install latest $t into $BIN_DIR"
      continue
    else
      want="$("tool_${t}_latest")" || want=""
      if [ -z "$want" ]; then
        warn "tool $t: could not resolve latest version (network?); skipping"
        failed="$failed $t"
        continue
      fi
    fi
    if _tool_present "$t" && [ "$cur" = "$want" ]; then
      log "tool $t: $want already installed"
      continue
    fi
    if [ "$DRY_RUN" = 1 ]; then
      log "DRY-RUN: would install $t $want into $BIN_DIR"
      continue
    fi
    log "installing $t $want"
    TOOL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/wsk-tool.XXXXXX")"
    # Subshell so a die() inside an installer does not abort the other tools.
    # errexit is ignored inside an `if` condition, so capture the status instead.
    set +e
    ( set -e; "tool_${t}_install" "$want" )
    rc=$?
    set -e
    if [ "$rc" = 0 ]; then
      lock_set "$t" "$want"
    else
      warn "tool $t: install failed"
      failed="$failed $t"
    fi
    rm -rf "$TOOL_TMP"
  done
  [ -z "$failed" ] || warn "tools not installed:$failed"
  return 0
}

uninstall_tools() {
  local t b
  [ -f "$LOCK_FILE" ] || { log "no versions.lock; no kit-installed tools to remove"; return 0; }
  while IFS='=' read -r t _; do
    [ -n "$t" ] || continue
    for b in $(tool_bins "$t"); do
      [ -e "$BIN_DIR/$b" ] || [ -L "$BIN_DIR/$b" ] || continue
      run rm -f "$BIN_DIR/$b"
    done
    [ "$t" = awscli ] && run rm -rf "$HOME/.local/aws-cli"
  done < "$LOCK_FILE"
  run rm -f "$LOCK_FILE"
}
