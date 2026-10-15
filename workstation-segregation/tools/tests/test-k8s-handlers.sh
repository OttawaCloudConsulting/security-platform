#!/bin/bash
# Phase 3 handlers (kubernetes + argocd), offline: a stub curl serves canned
# content, and the real group scripts are sourced under Bash 5.
. "$(dirname "$0")/helpers.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/wst-k8s.XXXXXX")"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home" "$T/srv"

# canned upstream: a fake kind binary (raw asset) and a fake kubectx tarball
printf '#!/bin/sh\necho "kind v0.33.0 go1 linux/amd64"\n' > "$T/srv/kind-linux-amd64"
printf '#!/bin/sh\necho 0.11.0\n' > "$T/srv/kubectx"; chmod +x "$T/srv/kubectx"
printf '#!/bin/sh\necho 0.11.0\n' > "$T/srv/kubens"; chmod +x "$T/srv/kubens"
tar -czf "$T/srv/kubectx_v0.11.0_linux_x86_64.tar.gz" -C "$T/srv" kubectx
tar -czf "$T/srv/kubens_v0.11.0_linux_x86_64.tar.gz" -C "$T/srv" kubens
h() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
printf '%s  kind-linux-amd64\n' "$(h "$T/srv/kind-linux-amd64")" > "$T/srv/kind-linux-amd64.sha256sum"
{ printf '%s  kubectx_v0.11.0_linux_x86_64.tar.gz\n' "$(h "$T/srv/kubectx_v0.11.0_linux_x86_64.tar.gz")"
  printf '%s  kubens_v0.11.0_linux_x86_64.tar.gz\n' "$(h "$T/srv/kubens_v0.11.0_linux_x86_64.tar.gz")"; } > "$T/srv/checksums.txt"
printf 'v1.34.1\n' > "$T/srv/stable.txt"
printf 'kustomize/v5.8.3\n' > "$T/srv/tag"

cat > "$T/bin/curl" <<STUB
#!/bin/bash
out=""; prev=""
for a in "\$@"; do [ "\$prev" = -o ] && out="\$a"; prev="\$a"; u="\$a"; done
f="$T/srv/\${u##*/}"
case "\$u" in
  */releases/latest) printf '%s' "\${u%/releases/latest}/releases/tag/v9.9.9"; exit 0 ;;
  *api.github.com*releases*) printf '[{"tag_name":"kyaml/v0.1.0"},{"tag_name":"kustomize/v5.8.3"},{"tag_name":"kustomize/v5.8.2"}]'; exit 0 ;;
  *releases/tag/*) exit 0 ;;
esac
[ -f "\$f" ] || exit 22
if [ -n "\$out" ] && [ "\$out" != /dev/null ]; then cp "\$f" "\$out"; else cat "\$f"; fi
STUB
chmod +x "$T/bin/curl"

cat > "$T/driver.sh" <<'DRV'
set -u
export WST_ROOT="$1" WST_OS="$2" WST_ARCH="$3" HOME="$4" PATH="$5:$PATH" SRV="$6"
export WST_JQ="$(command -v jq)" WST_CATALOG_DIR="$WST_ROOT/scripts/common/catalog"
. "$WST_ROOT/scripts/common/common.sh"
. "$WST_ROOT/scripts/common/catalog.sh"
. "$WST_ROOT/scripts/common/versions.sh"
. "$WST_ROOT/scripts/common/download.sh"
catalog_load
for g in kubernetes argocd; do . "$WST_ROOT/scripts/$WST_OS/groups/$g.sh"; done
for id in "${TOOL_IDS[@]}"; do
  case " ${T_GROUPS[$id]} " in *" kubernetes "*|*" argocd "*) ;; *) continue ;; esac
  [ "$(tool_home_group "$id")" = base ] && continue
  if [ "${T_REL[$id]}" = bundled ] && ! fn_exists "$id" latest; then echo "follow $id"; continue; fi
  for s in latest probe install remove validate; do
    fn_exists "$id" "$s" && echo "has $id $s" || echo "MISSING $id $s"
  done
done
echo "kubectl_url $(kubectl_url 1.34.1)"
echo "helm_asset $(helm_asset 3.19.0)"
echo "kustomize_latest $(tool_kustomize_latest)"
echo "k9s_latest $(tool_k9s_latest)"
echo "kubectl_latest $(tool_kubectl_latest)"
echo "stern_asset $(ghr_expand "${GHR_ASSET[stern]}" 1.34.0 stern)"
echo "eksctl_asset $(ghr_expand "${GHR_ASSET[eksctl]}" 0.231.0 eksctl)"
TOOL_TMP="$(mktemp -d "$HOME/tt.XXXXXX")"; : > "$TOOL_TMP/res"
tool_kind_install 0.33.0 "$TOOL_TMP/res" && echo "kind_installed $(cat "$TOOL_TMP/res")"
tool_kind_validate && echo "kind_valid"
tool_kubectx_install 0.11.0 "$TOOL_TMP/res" && echo "kubectx_installed"
[ -x "$HOME/.local/bin/kubens" ] && echo "kubens_present"
tool_kubectx_remove; [ -e "$HOME/.local/bin/kubens" ] || echo "kubens_removed"
DRV

run_driver() { "$BASH5" "$T/driver.sh" "$TOOLS_DIR" "$1" "$2" "$T/home" "$T/bin" "$T/srv" 2>&1; }
U="$(run_driver ubuntu amd64)"
[ -n "${DBG:-}" ] && echo "$U" | tail -6
rm -rf "$T/home/.local"
M="$(run_driver macos arm64)"
assert_not_contains "$U" MISSING "ubuntu contract"
assert_not_contains "$M" MISSING "macos contract"
for id in eksctl kubectl kubectx kubecolor helm k9s stern kustomize kind helmfile argocd-cli; do
  assert_contains "$U" "has $id install" "ubuntu $id"
  assert_contains "$M" "has $id install" "macos $id"
done
assert_contains "$U" "follow kubens" "kubens follows kubectx"
assert_contains "$U" "follow kustomize-embedded" "kustomize-embedded follows kubectl"
assert_contains "$U" "kubectl_url https://dl.k8s.io/release/v1.34.1/bin/linux/amd64/kubectl" "kubectl url"
assert_contains "$M" "kubectl_url https://dl.k8s.io/release/v1.34.1/bin/darwin/arm64/kubectl" "macos kubectl url"
assert_contains "$U" "helm_asset helm-v3.19.0-linux-amd64.tar.gz" "helm asset"
assert_contains "$U" "kustomize_latest 5.8.3" "kustomize latest skips other modules"
assert_contains "$U" "k9s_latest 9.9.9" "gh latest tag"
assert_contains "$U" "kubectl_latest 1.34.1" "kubectl stable.txt"
assert_contains "$U" "stern_asset stern_1.34.0_linux_amd64.tar.gz" "stern asset"
assert_contains "$M" "eksctl_asset eksctl_Darwin_arm64.tar.gz" "eksctl asset"
assert_contains "$U" "kind_installed integrity=verified" "kind raw binary verified"
assert_contains "$U" "kind_valid" "kind validate"
assert_contains "$U" "kubens_present" "kubectx installs kubens"
assert_contains "$U" "kubens_removed" "kubectx removes kubens"
finish
