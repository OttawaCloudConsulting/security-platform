#!/bin/bash
# base group tools that are identical on Ubuntu and macOS: release binaries,
# npm AI CLIs, the uv-installed notebook CLI, and Antigravity.
# shellcheck source=handlers.sh
. "$WST_ROOT/scripts/common/handlers.sh"

release_tool jq jq jqlang/jq jq-
release_tool yq yq mikefarah/yq ""
release_tool direnv direnv direnv/direnv ""
release_tool starship starship starship/starship ""
release_tool uv uv astral-sh/uv "="

npm_tool codex @openai/codex codex
npm_tool claude-code @anthropic-ai/claude-code claude --allow-scripts=@anthropic-ai/claude-code
npm_tool gemini-cli @google/gemini-cli gemini
uv_tool gemini-notebook-mcp-cli notebooklm-mcp-cli nlm

# Antigravity: the installer's own release manifest (version, url, sha512) is the
# authoritative source. It publishes only the current build, so pins must equal latest.
AGY_BASE="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests"
agy_platform() {
  local os arch
  if [ "$WST_OS" = macos ]; then os=darwin; else os=linux; fi
  arch="$WST_ARCH"
  if [ "$os" = linux ] && { [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ]; }; then
    printf '%s_%s_musl\n' "$os" "$arch"
  else
    printf '%s_%s\n' "$os" "$arch"
  fi
}
agy_manifest() { _curl "$AGY_BASE/$(agy_platform).json"; }
agy_field() { printf '%s' "$1" | "$WST_JQ" -er --arg k "$2" '.[$k]'; }
tool_antigravity_source() { echo release; }
tool_antigravity_latest() { agy_field "$(agy_manifest)" version; }
tool_antigravity_pin_ok() { [ "$1" = "$(tool_antigravity_latest)" ]; }
tool_antigravity_probe() { rel_probe agy; }
tool_antigravity_validate() { "$(bin_dir)/agy" --version >/dev/null 2>&1; }
tool_antigravity_remove() { rm -f "$(bin_dir)/agy"; }
tool_antigravity_install() {
  local m url sha dest="$TOOL_TMP/agy.pkg"
  m="$(agy_manifest)" || die "could not fetch the Antigravity manifest"
  url="$(agy_field "$m" url)"; sha="$(agy_field "$m" sha512)"
  dl_fetch "$url" "$dest" || die "download failed: $url"
  if ! dl_verify_sha512 "$dest" "$sha"; then die "$(dl_fail_message "$DL_STATUS" agy)"; fi
  case "$url" in
    *.tar.gz*) rel_extract "$dest" "$TOOL_TMP/x"; rel_put "$TOOL_TMP/x/antigravity" agy ;;
    *) rel_put "$dest" agy ;;
  esac
  [ "$WST_OS" = macos ] && xattr -d com.apple.quarantine "$(bin_dir)/agy" 2>/dev/null || true
  result_set "$2" integrity "$DL_STATUS"
}
