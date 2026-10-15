#!/bin/bash
# Handlers shared by the ansible, go and database-* groups on both OSes:
# Ansible via uv, Go from the official go.dev tarball (user-level), and the
# helpers the per-OS database client scripts use.
# shellcheck source=handlers.sh
. "$WST_ROOT/scripts/common/handlers.sh"

# ---- Ansible: PyPI "ansible" has no entry points of its own, so the executables
# of its ansible-core dependency are exposed through uv. -----------------------------
uv_tool ansible ansible ansible
tool_ansible_install() {
  "$(uv_bin)" tool install --force --with-executables-from ansible-core "ansible==$1" >/dev/null || return 1
  result_set "$2" integrity package-manager
}
tool_ansible_validate() {
  local b
  b="$("$(uv_bin)" tool dir --bin 2>/dev/null || echo "$HOME/.local/bin")"
  "$b/ansible" --version >/dev/null 2>&1 || ansible --version >/dev/null 2>&1
}

# ---- Go: https://go.dev/dl/?mode=json (version, files[].sha256) ---------------------------
GO_DL_JSON="https://go.dev/dl/?mode=json"
go_home() { printf '%s\n' "$HOME/.local/share/go"; }
go_arch() { if [ "$WST_ARCH" = arm64 ]; then echo arm64; else echo amd64; fi; }
go_json() { _curl "$GO_DL_JSON${1:-}"; }

tool_go_source() { echo release; }
tool_go_latest() {
  local v
  v="$(go_json | "$WST_JQ" -er '[.[] | select(.stable)][0].version')" || return 1
  printf '%s\n' "${v#go}"
}
tool_go_pin_ok() {
  go_json '&include=all' | "$WST_JQ" -e --arg v "go$1" 'any(.[]; .version == $v and .stable)' >/dev/null
}
tool_go_probe() {
  local ours active v
  ours="$(bin_dir)/go"; active="$(command -v go 2>/dev/null || true)"
  if [ -n "$active" ]; then
    v="$(ver_of "$active" version)"
    if [ "$active" -ef "$ours" ] 2>/dev/null; then
      printf '%s\t%s\trelease\t-\n' "${v:--}" "$ours"; return 0
    fi
    printf '%s\t%s\tother\t-\n' "${v:--}" "$active"
  fi
  if [ -x "$ours" ] && ! [ "$active" -ef "$ours" ] 2>/dev/null; then
    printf '%s\t%s\trelease\t-\n' "$(ver_of "$ours" version)" "$ours"
  fi
  return 0
}
tool_go_validate() { "$(bin_dir)/go" version >/dev/null 2>&1; }
tool_go_remove() {
  rm -f "$(bin_dir)/go" "$(bin_dir)/gofmt"
  rm -rf "$(go_home)"
}
tool_go_install() {
  local v="$1" res="$2" tmp="$TOOL_TMP" file name rec sha
  rec="$(go_json '&include=all' | "$WST_JQ" -c --arg v "go$v" --arg o "$(rel_os)" --arg a "$(go_arch)" \
    '[.[] | select(.version == $v) | .files[] | select(.os == $o and .arch == $a and .kind == "archive")][0] // empty')" || return 1
  [ -n "$rec" ] || die "go$v has no $(rel_os)/$(go_arch) archive"
  file="$("$WST_JQ" -r '.filename' <<< "$rec")"; sha="$("$WST_JQ" -r '.sha256' <<< "$rec")"
  name="$file"
  printf '%s  %s\n' "$sha" "$name" > "$tmp/sums"
  dl_fetch "https://go.dev/dl/$file" "$tmp/$file" || die "download failed: $file"
  dl_verify "$tmp/$file" "$name" yes "file://$tmp/sums" || die "$(dl_fail_message "$DL_STATUS" "$name")"
  rel_extract "$tmp/$file" "$tmp/x"
  [ -x "$tmp/x/go/bin/go" ] || die "unexpected Go archive layout"
  mkdir -p "$(dirname "$(go_home)")" "$(bin_dir)"
  rm -rf "$(go_home).new" && mv "$tmp/x/go" "$(go_home).new"
  rm -rf "$(go_home)" && mv "$(go_home).new" "$(go_home)"
  ln -sf "$(go_home)/bin/go" "$(bin_dir)/go"
  ln -sf "$(go_home)/bin/gofmt" "$(bin_dir)/gofmt"
  result_set "$res" integrity "$DL_STATUS"
}

# ---- database clients ------------------------------------------------------------------------
# apt_client_tool <id> <package> <bin> [validate cmd]: apt_tool plus detection of a
# same-named client from another source that is active on PATH.
apt_client_tool() {
  local id="$1" bin="$3" fn="${1//-/_}"
  apt_tool "$@"
  eval "
$(declare -f "tool_${fn}_probe" | sed "1s/tool_${fn}_probe/tool_${fn}_probe_apt/")
tool_${fn}_probe() {
  local line active
  line=\$(tool_${fn}_probe_apt)
  active=\$(command -v '$bin' 2>/dev/null || true)
  if [ -n \"\$line\" ]; then
    case \"\$active\" in /usr/bin/*|/bin/*) line=\$(awk -F'\t' -v p=\"\$active\" 'BEGIN{OFS=FS} \$2==\"-\"{\$2=p} {print}' <<< \"\$line\") ;; esac
    printf '%s\n' \"\$line\"
  elif [ -n \"\$active\" ]; then
    printf '%s\t%s\tother\t-\n' \"\$(ver_of '$bin' --version)\" \"\$active\"
  fi
  return 0
}
"
}

# brew_keg_tool <id> <formula> <bin>: keg-only formulas (libpq, mysql-client) are not
# on PATH; the client binary is symlinked into the managed bin dir.
brew_keg_tool() {
  local id="$1" formula="$2" bin="$3" fn="${1//-/_}"
  brew_tool "$id" "$formula" "$bin" true
  eval "
tool_${fn}_probe() {
  local v keg ours active
  ours=\"\$(bin_dir)/$bin\"; active=\$(command -v '$bin' 2>/dev/null || true)
  v=\$(brew list --versions '$formula' 2>/dev/null | awk '{print \$NF}'); v=\${v%%_*}
  if [ -n \"\$active\" ] && ! [ \"\$active\" -ef \"\$ours\" ] 2>/dev/null; then
    printf '%s\t%s\tother\t-\n' \"\$(ver_of '$bin' --version)\" \"\$active\"
  fi
  [ -n \"\$v\" ] || return 0
  keg=\$(brew --prefix '$formula')/bin/$bin
  if [ -L \"\$ours\" ] && [ \"\$ours\" -ef \"\$keg\" ]; then
    printf '%s\t%s\tbrew\t%s\n' \"\$v\" \"\$ours\" '$formula'
  else
    printf '%s\t%s\tbrew\t%s\n' \"\$v\" \"\$keg\" '$formula'
  fi
}
tool_${fn}_install() {
  brew install '$formula' >/dev/null || brew upgrade '$formula' >/dev/null || return 1
  mkdir -p \"\$(bin_dir)\"
  ln -sf \"\$(brew --prefix '$formula')/bin/$bin\" \"\$(bin_dir)/$bin\"
  result_set \"\$2\" integrity package-manager
}
tool_${fn}_remove() { rm -f \"\$(bin_dir)/$bin\"; brew uninstall '$formula' >/dev/null; }
tool_${fn}_validate() { \"\$(bin_dir)/$bin\" --version >/dev/null 2>&1; }
"
}
