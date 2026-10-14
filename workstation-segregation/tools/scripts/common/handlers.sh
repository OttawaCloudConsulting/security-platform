#!/bin/bash
# Handler building blocks shared by the OS group scripts (Bash 5). Each
# generator defines the per-tool contract:
#   tool_<id>_latest | _probe | _install VER RESULT_FILE | _remove | _validate
#   optional: _kind (bin|os), _source, _pin_ok VER
# Probe lines: version<TAB>path<TAB>source<TAB>package_id, "-" for empty.

result_set() { printf '%s=%s\n' "$2" "$3" >> "$1"; }

ver_of() { "$@" 2>&1 | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true; }

# ---- Node (nvm is an orchestrator prerequisite) -------------------------------------
node_env() {
  command -v npm >/dev/null 2>&1 && return 0
  local nvm="${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  [ -s "$nvm" ] || return 1
  set +eu
  # shellcheck source=/dev/null
  . "$nvm" >/dev/null 2>&1
  nvm use default >/dev/null 2>&1
  set -eu
  command -v npm >/dev/null 2>&1
}

# ---- release binaries into ~/.local/bin ------------------------------------------------
rel_os() { if [ "$WST_OS" = macos ]; then echo darwin; else echo linux; fi; }
rel_triple_arch() { if [ "$WST_ARCH" = arm64 ]; then echo aarch64; else echo x86_64; fi; }

# rel_probe <bin>: managed copy under bin_dir plus the PATH-active one (first).
rel_probe() {
  local bin="$1" ours active v
  ours="$(bin_dir)/$bin"; active="$(command -v "$bin" 2>/dev/null || true)"
  if [ -n "$active" ]; then
    v="$(ver_of "$active" --version)"
    if [ "$active" -ef "$ours" ] 2>/dev/null; then
      printf '%s\t%s\trelease\t-\n' "${v:--}" "$ours"; return 0
    fi
    printf '%s\t%s\tother\t-\n' "${v:--}" "$active"
  fi
  if [ -x "$ours" ] && ! [ "$active" -ef "$ours" ] 2>/dev/null; then
    printf '%s\t%s\trelease\t-\n' "$(ver_of "$ours" --version)" "$ours"
  fi
  return 0
}

rel_put() { mkdir -p "$(bin_dir)"; install -m 0755 "$1" "$(bin_dir)/$2.new" && mv -f "$(bin_dir)/$2.new" "$(bin_dir)/$2"; }

# rel_fetch_verify <id> <url> <dest> <asset> <sums url>...
rel_fetch_verify() {
  local id="$1" url="$2" dest="$3" asset="$4"
  shift 4
  dl_fetch "$url" "$dest" || die "download failed: $url"
  if ! dl_verify "$dest" "$asset" "${T_CHECKSUM[$id]}" "$@"; then
    die "$(dl_fail_message "$DL_STATUS" "$asset")"
  fi
}

# rel_extract <archive> <dir>
rel_extract() {
  mkdir -p "$2"
  case "$1" in *.zip) unzip -q -o "$1" -d "$2" ;; *) tar -xzf "$1" -C "$2" ;; esac
}

# release_tool <id> <bin> <repo> <tag prefix> — defines the contract using
# per-tool hooks: rel_<id>_asset VER, rel_<id>_sums VER BASE ASSET, rel_<id>_unpack
release_tool() {
  local id="$1" bin="$2" repo="$3" tagpre="$4" fn="${1//-/_}" tp="${4#=}"
  eval "
tool_${fn}_latest() { local t; t=\$(gh_latest_tag $repo) || return 1; t=\${t#$tp}; echo \"\${t#v}\"; }
tool_${fn}_source() { echo release; }
tool_${fn}_probe() { rel_probe $bin; }
tool_${fn}_validate() { \"\$(bin_dir)/$bin\" --version >/dev/null 2>&1; }
tool_${fn}_pin_ok() { _curl -o /dev/null \"https://github.com/$repo/releases/tag/${tp}\${1}\" 2>/dev/null || _curl -o /dev/null \"https://github.com/$repo/releases/tag/${tp}v\${1}\"; }
tool_${fn}_remove() { rm -f \"\$(bin_dir)/$bin\"; }
tool_${fn}_install() {
  local v=\$1 res=\$2 asset base tmp=\$TOOL_TMP
  base=\$(rel_base $repo '$tagpre' \"\$v\")
  asset=\$(rel_${fn}_asset \"\$v\")
  rel_fetch_verify $id \"\$base/\$asset\" \"\$tmp/\$asset\" \"\$asset\" \$(rel_${fn}_sums \"\$v\" \"\$base\" \"\$asset\")
  rel_${fn}_unpack \"\$tmp/\$asset\"
  result_set \"\$res\" integrity \"\$DL_STATUS\"
}
"
}
# GitHub tags: jq uses jq-X, others vX (a pin may be given with or without the v).
rel_base() { # rel_base repo tagpre ver
  local tag="$2$3"
  [ -z "$2" ] && tag="v$3"
  [ "$2" = = ] && tag="$3"   # "=" marks tags with no prefix at all (uv)
  printf 'https://github.com/%s/releases/download/%s\n' "$1" "$tag"
}

rel_jq_asset() { printf 'jq-%s-%s\n' "$([ "$WST_OS" = macos ] && echo macos || echo linux)" "$WST_ARCH"; }
rel_jq_sums() { echo "$2/sha256sum.txt"; }
rel_jq_unpack() { rel_put "$1" jq; }

rel_yq_asset() { printf 'yq_%s_%s\n' "$(rel_os)" "$WST_ARCH"; }
rel_yq_sums() { echo "$2/checksums-bsd"; }
rel_yq_unpack() { rel_put "$1" yq; }

rel_direnv_asset() { printf 'direnv.%s-%s\n' "$(rel_os)" "$WST_ARCH"; }
rel_direnv_sums() { echo "$2/checksums.txt"; }
rel_direnv_unpack() { rel_put "$1" direnv; }

rel_starship_asset() {
  if [ "$WST_OS" = macos ]; then printf 'starship-%s-apple-darwin.tar.gz\n' "$(rel_triple_arch)"
  else printf 'starship-%s-unknown-linux-musl.tar.gz\n' "$(rel_triple_arch)"; fi
}
rel_starship_sums() { echo "$2/$3.sha256"; }
rel_starship_unpack() { rel_extract "$1" "$TOOL_TMP/x"; rel_put "$(find "$TOOL_TMP/x" -type f -name starship | head -n1)" starship; }

rel_uv_asset() {
  if [ "$WST_OS" = macos ]; then printf 'uv-%s-apple-darwin.tar.gz\n' "$(rel_triple_arch)"
  else printf 'uv-%s-unknown-linux-gnu.tar.gz\n' "$(rel_triple_arch)"; fi
}
rel_uv_sums() { echo "$2/$3.sha256"; }
rel_uv_unpack() {
  rel_extract "$1" "$TOOL_TMP/x"
  rel_put "$(find "$TOOL_TMP/x" -type f -name uv | head -n1)" uv
  rel_put "$(find "$TOOL_TMP/x" -type f -name uvx | head -n1)" uvx
}
tool_uv_remove() { rm -f "$(bin_dir)/uv" "$(bin_dir)/uvx"; }

# ---- npm global CLIs ----------------------------------------------------------------------
npm_tool() { # npm_tool <id> <package> <bin> [extra npm install flags]
  local id="$1" pkg="$2" bin="$3" fn="${1//-/_}" extra="${4:-}"
  eval "
tool_${fn}_source() { echo npm; }
tool_${fn}_latest() { node_env || return 1; npm view '$pkg' version; }
tool_${fn}_pin_ok() { node_env && [ -n \"\$(npm view '$pkg@'\$1 version 2>/dev/null)\" ]; }
tool_${fn}_probe() {
  local v
  node_env || return 0
  v=\$(npm ls -g --depth=0 --json 2>/dev/null | \"\$WST_JQ\" -r --arg p '$pkg' '.dependencies[\$p].version // empty')
  [ -n \"\$v\" ] || return 0
  printf '%s\t%s\tnpm\t%s\n' \"\$v\" \"\$(command -v '$bin' 2>/dev/null || echo -)\" '$pkg'
}
tool_${fn}_install() { node_env || die 'Node.js (nvm) is not available'; npm install -g $extra '$pkg'@\"\$1\" >/dev/null; result_set \"\$2\" integrity npm-registry; }
tool_${fn}_remove() { node_env && npm uninstall -g '$pkg' >/dev/null; }
tool_${fn}_validate() { node_env && '$bin' --version >/dev/null 2>&1; }
"
}

# ---- uv tool installs ---------------------------------------------------------------------
uv_bin() { command -v uv 2>/dev/null || echo "$(bin_dir)/uv"; }
uv_tool() { # uv_tool <id> <pypi package> <bin>
  local id="$1" pkg="$2" bin="$3" fn="${1//-/_}"
  eval "
tool_${fn}_source() { echo uv; }
tool_${fn}_latest() { _curl 'https://pypi.org/pypi/$pkg/json' | \"\$WST_JQ\" -er '.info.version'; }
tool_${fn}_pin_ok() { _curl -o /dev/null 'https://pypi.org/pypi/$pkg/'\$1'/json'; }
tool_${fn}_probe() {
  local v b
  [ -x \"\$(uv_bin)\" ] || return 0
  v=\$(\"\$(uv_bin)\" tool list 2>/dev/null | awk '\$1==\"$pkg\"{print \$2}')
  v=\${v#v}
  [ -n \"\$v\" ] || return 0
  b=\$(\"\$(uv_bin)\" tool dir --bin 2>/dev/null || echo \"\$HOME/.local/bin\")/$bin
  printf '%s\t%s\tuv\t%s\n' \"\$v\" \"\$b\" '$pkg'
}
tool_${fn}_install() { \"\$(uv_bin)\" tool install --force '$pkg'==\"\$1\" >/dev/null; result_set \"\$2\" integrity package-manager; }
tool_${fn}_remove() { \"\$(uv_bin)\" tool uninstall '$pkg' >/dev/null; }
tool_${fn}_validate() { '$bin' --help >/dev/null 2>&1 || \"\$(bin_dir)/$bin\" --help >/dev/null 2>&1 || \"\$(uv_bin)\" tool dir --bin >/dev/null; }
"
}

# ---- apt packages ----------------------------------------------------------------------------
apt_get() { DEBIAN_FRONTEND=noninteractive ${SUDO:-} apt-get -y "$@"; }

apt_tool() { # apt_tool <id> <package> <bin|-> [validate command...]
  local id="$1" pkg="$2" bin="$3" fn="${1//-/_}" vcmd="${4:-}"
  eval "
tool_${fn}_source() { echo apt; }
tool_${fn}_latest() { local c; c=\$(apt-cache policy '$pkg' | awk '/Candidate:/{print \$2}'); [ -n \"\$c\" ] && [ \"\$c\" != '(none)' ] && echo \"\$c\"; }
tool_${fn}_pin_ok() { apt-cache madison '$pkg' | awk '{print \$3}' | grep -qE \"^(\$(printf '%s' \"\$1\" | sed 's/[.+]/\\\\&/g'))(\$|-|\\\\+)|^[0-9]+:\$(printf '%s' \"\$1\" | sed 's/[.+]/\\\\&/g')(\$|-|\\\\+)\"; }
tool_${fn}_probe() {
  local v p=-
  v=\$(dpkg-query -W -f='\${db:Status-Abbrev}\t\${Version}' '$pkg' 2>/dev/null | awk -F'\t' '\$1 ~ /^ii/ {print \$2}')
  [ -n \"\$v\" ] || return 0
  [ '$bin' != '-' ] && p=\$(dpkg -L '$pkg' 2>/dev/null | grep -m1 -E \"/(s?bin)/$bin\\\$\" || echo -)
  printf '%s\t%s\tapt\t%s\n' \"\$v\" \"\$p\" '$pkg'
}
tool_${fn}_install() {
  local v=\$1
  apt_get install \"$pkg=\$v\" >/dev/null || return 1
  result_set \"\$2\" integrity package-manager
}
tool_${fn}_remove() { apt_get remove '$pkg' >/dev/null; }
tool_${fn}_validate() { ${vcmd:-true} >/dev/null 2>&1; }
"
}

# ---- Homebrew formulas ---------------------------------------------------------------------------
brew_prefix() { brew --prefix; }
brew_tool() { # brew_tool <id> <formula> <bin|-> [validate command...]
  local id="$1" formula="$2" bin="$3" fn="${1//-/_}" vcmd="${4:-}"
  eval "
tool_${fn}_source() { echo brew; }
tool_${fn}_latest() { brew info --json=v2 '$formula' | \"\$WST_JQ\" -er '.formulae[0].versions.stable'; }
tool_${fn}_pin_ok() { [ \"\$1\" = \"\$(tool_${fn}_latest)\" ]; }
tool_${fn}_probe() {
  local v p=-
  v=\$(brew list --versions '$formula' 2>/dev/null | awk '{print \$NF}')
  v=\${v%%_*}
  [ -n \"\$v\" ] || return 0
  [ '$bin' != '-' ] && p=\$(brew --prefix)/bin/$bin
  printf '%s\t%s\tbrew\t%s\n' \"\$v\" \"\$p\" '$formula'
}
tool_${fn}_install() { brew install '$formula' >/dev/null || brew upgrade '$formula' >/dev/null; result_set \"\$2\" integrity package-manager; }
tool_${fn}_remove() { brew uninstall '$formula' >/dev/null; }
tool_${fn}_validate() { ${vcmd:-true} >/dev/null 2>&1; }
"
}

# ---- platform-provided tools (macOS): probe and validate only -----------------------------------
os_tool() { # os_tool <id> <bin> <version cmd...>
  local id="$1" bin="$2" fn="${1//-/_}"
  shift 2
  eval "
tool_${fn}_kind() { echo os; }
tool_${fn}_source() { echo os; }
tool_${fn}_latest() { tool_${fn}_probe | cut -f1 | head -n1 | grep .; }
tool_${fn}_probe() {
  local p v
  p=\$(command -v '$bin' 2>/dev/null) || return 0
  v=\$(ver_of $*)
  printf '%s\t%s\tos\t-\n' \"\${v:-\$(sw_vers -productVersion 2>/dev/null || echo 0)}\" \"\$p\"
}
tool_${fn}_install() { return 1; }
tool_${fn}_remove() { return 1; }
tool_${fn}_validate() { command -v '$bin' >/dev/null 2>&1; }
"
}
