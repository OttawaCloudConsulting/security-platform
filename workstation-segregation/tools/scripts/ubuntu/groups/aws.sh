#!/bin/bash
# aws group on Ubuntu: shared AWS tools plus SAM from the release zip
# (user-level install, no root).
# shellcheck source=../../common/aws-shared.sh
. "$WST_ROOT/scripts/common/aws-shared.sh"

sam_url() { printf 'https://github.com/aws/aws-sam-cli/releases/download/v%s/aws-sam-cli-linux-%s.zip\n' "$1" "$([ "$WST_ARCH" = arm64 ] && echo arm64 || echo x86_64)"; }
tool_aws_sam_source() { echo release; }
tool_aws_sam_latest() { local t; t="$(gh_latest_tag aws/aws-sam-cli)" || return 1; echo "${t#v}"; }
tool_aws_sam_pin_ok() { _curl -o /dev/null "https://github.com/aws/aws-sam-cli/releases/tag/v$1"; }
tool_aws_sam_probe() { rel_probe sam; }
tool_aws_sam_validate() { "$(bin_dir)/sam" --version >/dev/null 2>&1; }
tool_aws_sam_remove() { rm -f "$(bin_dir)/sam"; rm -rf "$HOME/.local/share/aws-sam-cli"; }
tool_aws_sam_install() {
  local v="$1" res="$2" url dest="$TOOL_TMP/sam.zip" x="$TOOL_TMP/x"
  url="$(sam_url "$v")"
  dl_fetch "$url" "$dest" || die "download failed: $url"
  dl_verify "$dest" "${url##*/}" no   # only a GPG signature is published: reported unverified
  rel_extract "$dest" "$x"
  "$x/install" -i "$HOME/.local/share/aws-sam-cli" -b "$(bin_dir)" --update >/dev/null
  result_set "$res" integrity "$DL_STATUS"
}
