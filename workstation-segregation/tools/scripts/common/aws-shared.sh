#!/bin/bash
# aws group tools shared by Ubuntu and macOS: AWS CLI v2, Session Manager
# plugin and CDK. SAM and the container tools are per-OS. docker (aws group)
# has no handlers: it is a bundled command that follows docker-cli.
# shellcheck source=handlers.sh
. "$WST_ROOT/scripts/common/handlers.sh"

url_exists() { curl -fsSIL --connect-timeout 15 -o /dev/null "$1"; }
arch_x86_64_aarch64() { if [ "$WST_ARCH" = arm64 ]; then echo aarch64; else echo x86_64; fi; }

npm_tool aws-cdk aws-cdk cdk

# ---- AWS CLI v2 (user-level: ~/.local/share/aws-cli or ~/aws-cli, shim in ~/.local/bin) ------
awscli_url() {
  if [ "$WST_OS" = macos ]; then
    printf 'https://awscli.amazonaws.com/AWSCLIV2-%s.pkg\n' "$1"
  else
    printf 'https://awscli.amazonaws.com/awscli-exe-linux-%s-%s.zip\n' "$(arch_x86_64_aarch64)" "$1"
  fi
}
tool_awscli_source() { echo release; }
tool_awscli_latest() {
  local log v
  log="$(_curl https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst)" || return 1
  v="$(awk '!f && /^[0-9]+\.[0-9]+\.[0-9]+$/ {print; f=1}' <<< "$log")"
  [ -n "$v" ] && printf '%s\n' "$v"
}
tool_awscli_pin_ok() { url_exists "$(awscli_url "$1")"; }
tool_awscli_probe() { rel_probe aws; }
tool_awscli_validate() { "$(bin_dir)/aws" --version >/dev/null 2>&1; }
tool_awscli_remove() {
  rm -f "$(bin_dir)/aws" "$(bin_dir)/aws_completer"
  rm -rf "$HOME/.local/share/aws-cli" "$HOME/aws-cli"
}
tool_awscli_install() {
  local v="$1" res="$2" url dest x="$TOOL_TMP/x"
  url="$(awscli_url "$v")"
  if [ "$WST_OS" = macos ]; then
    dest="$TOOL_TMP/AWSCLIV2.pkg"
    dl_fetch "$url" "$dest" || die "download failed: $url"
    dl_verify_pkg_signature "$dest" || die "$(dl_fail_message "$DL_STATUS" AWSCLIV2.pkg)"
    cat > "$TOOL_TMP/choices.xml" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><array><dict>
<key>choiceAttribute</key><string>customLocation</string>
<key>attributeSetting</key><string>$HOME</string>
<key>choiceIdentifier</key><string>default</string>
</dict></array></plist>
XML
    installer -pkg "$dest" -target CurrentUserHomeDirectory -applyChoiceChangesXML "$TOOL_TMP/choices.xml" >/dev/null
    mkdir -p "$(bin_dir)"
    ln -sf "$HOME/aws-cli/aws" "$(bin_dir)/aws"
    ln -sf "$HOME/aws-cli/aws_completer" "$(bin_dir)/aws_completer"
  else
    dest="$TOOL_TMP/awscli.zip"
    dl_fetch "$url" "$dest" || die "download failed: $url"
    dl_verify "$dest" "${url##*/}" no   # AWS publishes a GPG signature only: reported unverified
    rel_extract "$dest" "$x"
    "$x/aws/install" -i "$HOME/.local/share/aws-cli" -b "$(bin_dir)" --update >/dev/null
  fi
  result_set "$res" integrity "$DL_STATUS"
}

# ---- Session Manager plugin (single binary, extracted without root) -------------------------
ssm_platform() {
  if [ "$WST_OS" = macos ]; then
    if [ "$WST_ARCH" = arm64 ]; then echo mac_arm64; else echo mac; fi
  elif [ "$WST_ARCH" = arm64 ]; then echo ubuntu_arm64
  else echo ubuntu_64bit; fi
}
ssm_url() {
  local ext=deb
  [ "$WST_OS" = macos ] && ext=pkg
  printf 'https://s3.amazonaws.com/session-manager-downloads/plugin/%s/%s/session-manager-plugin.%s\n' "$1" "$(ssm_platform)" "$ext"
}
tool_session_manager_plugin_source() { echo release; }
tool_session_manager_plugin_latest() {
  local v
  v="$(_curl https://s3.amazonaws.com/session-manager-downloads/plugin/latest/VERSION | tr -d '[:space:]')" || return 1
  [ -n "$v" ] && printf '%s\n' "$v"
}
tool_session_manager_plugin_pin_ok() { url_exists "$(ssm_url "$1")"; }
tool_session_manager_plugin_probe() { rel_probe session-manager-plugin; }
tool_session_manager_plugin_validate() { "$(bin_dir)/session-manager-plugin" --version >/dev/null 2>&1; }
tool_session_manager_plugin_remove() { rm -f "$(bin_dir)/session-manager-plugin"; }
tool_session_manager_plugin_install() {
  local v="$1" res="$2" url dest x="$TOOL_TMP/x" bin=usr/local/sessionmanagerplugin/bin/session-manager-plugin
  url="$(ssm_url "$v")"
  dest="$TOOL_TMP/${url##*/}"
  dl_fetch "$url" "$dest" || die "download failed: $url"
  if [ "$WST_OS" = macos ]; then
    dl_verify_pkg_signature "$dest" || die "$(dl_fail_message "$DL_STATUS" session-manager-plugin.pkg)"
    pkgutil --expand-full "$dest" "$x"
    bin="Payload/$bin"
  else
    dl_verify "$dest" "${url##*/}" no   # no checksum published for the deb: reported unverified
    dpkg-deb -x "$dest" "$x"
  fi
  rel_put "$x/$bin" session-manager-plugin
  result_set "$res" integrity "$DL_STATUS"
}
