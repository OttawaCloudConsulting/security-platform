#!/bin/bash
# terraform, terragrunt and github group tools shared by Ubuntu and macOS:
# tfenv (git clone under ~/.local/share/tfenv, shims in ~/.local/bin), Terraform
# through tfenv, Terragrunt and GitHub CLI as checksum-verified release binaries.
# shellcheck source=handlers.sh
. "$WST_ROOT/scripts/common/handlers.sh"
[ -n "${_WST_TF_SHARED:-}" ] && return 0
_WST_TF_SHARED=1

tfenv_root() { printf '%s\n' "$HOME/.local/share/tfenv"; }
tfenv_bin() { printf '%s\n' "$(bin_dir)/tfenv"; }

# ---- tfenv (git tag clone; the tag is the pinned version; no checksum upstream) ------------
tool_tfenv_source() { echo release; }
tool_tfenv_latest() { local t; t="$(gh_latest_tag tfutils/tfenv)" || return 1; echo "${t#v}"; }
tool_tfenv_pin_ok() { _curl -o /dev/null "https://github.com/tfutils/tfenv/releases/tag/v$1"; }
tool_tfenv_probe() { rel_probe tfenv; }
tool_tfenv_validate() { "$(tfenv_bin)" --version >/dev/null 2>&1; }
tool_tfenv_remove() {
  local root; root="$(tfenv_root)"
  rm -f "$(bin_dir)/tfenv" "$(bin_dir)/terraform"
  rm -rf "$root"
}
tool_tfenv_install() {
  local v="$1" res="$2" root; root="$(tfenv_root)"
  mkdir -p "$(dirname "$root")" "$(bin_dir)"
  if [ -d "$root/.git" ]; then
    git -C "$root" fetch -q --depth 1 origin "refs/tags/v$v:refs/tags/v$v" || die "could not fetch tfenv v$v"
    git -C "$root" -c advice.detachedHead=false checkout -q "v$v"
  else
    rm -rf "$root"
    git clone -q --depth 1 --branch "v$v" https://github.com/tfutils/tfenv.git "$root" || die "could not clone tfenv v$v"
  fi
  ln -sf "$root/bin/tfenv" "$(bin_dir)/tfenv"
  ln -sf "$root/bin/terraform" "$(bin_dir)/terraform"
  result_set "$res" integrity provider
}

# ---- Terraform (versions managed by tfenv, which verifies SHA256SUMS itself) ---------------
tool_terraform_source() { echo release; }
tool_terraform_latest() {
  local index v
  index="$(_curl https://releases.hashicorp.com/terraform/)" || return 1
  # Consume all matches: head can cause SIGPIPE under pipefail on a large index.
  v="$(printf '%s\n' "$index" | grep -oE 'terraform_[0-9]+\.[0-9]+\.[0-9]+<' | awk 'NR == 1 { print }')" || return 1
  v="${v#terraform_}"; v="${v%<}"
  [ -n "$v" ] || { warn "no stable Terraform version found in the release index"; return 1; }
  printf '%s\n' "$v"
}
tool_terraform_pin_ok() { _curl -o /dev/null "https://releases.hashicorp.com/terraform/$1/"; }
tool_terraform_probe() {
  local ours active v
  ours="$(bin_dir)/terraform"; active="$(command -v terraform 2>/dev/null || true)"
  [ -n "$active" ] || return 0
  v="$(ver_of "$active" version)"
  if [ "$active" -ef "$ours" ] 2>/dev/null && [ -L "$ours" ]; then
    [ -n "$v" ] && printf '%s\t%s\trelease\t-\n' "$v" "$ours"
  else
    printf '%s\t%s\tother\t-\n' "${v:--}" "$active"
  fi
  return 0
}
tool_terraform_validate() { "$(bin_dir)/terraform" version >/dev/null 2>&1; }
tool_terraform_install() {
  local v="$1" res="$2" tf; tf="$(tfenv_bin)"
  [ -x "$tf" ] || die "tfenv is not installed"
  "$tf" install "$v" >/dev/null || die "tfenv could not install terraform $v"
  "$tf" use "$v" >/dev/null
  result_set "$res" integrity provider
}
tool_terraform_remove() {
  local tf d; tf="$(tfenv_bin)"
  if [ -x "$tf" ]; then
    for d in "$(tfenv_root)"/versions/*; do
      [ -d "$d" ] || continue
      "$tf" uninstall "${d##*/}" >/dev/null 2>&1 || rm -rf "$d"
    done
  fi
  rm -f "$(bin_dir)/terraform"
}

# ---- Terragrunt (raw binary, SHA256SUMS) --------------------------------------------------------
release_tool terragrunt terragrunt gruntwork-io/terragrunt ""
rel_terragrunt_asset() { printf 'terragrunt_%s_%s\n' "$(rel_os)" "$WST_ARCH"; }
rel_terragrunt_sums() { echo "$2/SHA256SUMS"; }
rel_terragrunt_unpack() { rel_put "$1" terragrunt; }

# ---- GitHub CLI (release archive, gh_<ver>_checksums.txt) -----------------------------------------
release_tool gh gh cli/cli ""
rel_gh_asset() {
  if [ "$WST_OS" = macos ]; then printf 'gh_%s_macOS_%s.zip\n' "$1" "$WST_ARCH"
  else printf 'gh_%s_linux_%s.tar.gz\n' "$1" "$WST_ARCH"; fi
}
rel_gh_sums() { echo "$2/gh_${1}_checksums.txt"; }
rel_gh_unpack() { rel_extract "$1" "$TOOL_TMP/x"; rel_put "$(find "$TOOL_TMP/x" -type f -path '*/bin/gh' | head -n1)" gh; }
