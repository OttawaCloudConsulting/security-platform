#!/bin/bash
# kubernetes + argocd group tools shared by Ubuntu and macOS. Everything is a
# release binary in ~/.local/bin verified against the published SHA-256.
# kubens follows kubectx (one handler installs both); kustomize-embedded and
# docker have no handlers (bundled commands that follow kubectl / docker-cli).
# shellcheck source=handlers.sh
. "$WST_ROOT/scripts/common/handlers.sh"

# ---- generic GitHub-release generator ---------------------------------------------------
# gh_release_tool <id> <bin[,bin...]> <repo> <tag prefix> <asset tmpl> <sums tmpl> <version cmd>
# Templates: {v} version, {bin}, {os} linux|darwin, {Os} Linux|Darwin,
# {arch} amd64|arm64, {x} x86_64|arm64. An asset without .tar.gz/.zip is the
# binary itself. A tag prefix containing "/" (kustomize) is searched in the
# releases list because /releases/latest may belong to another module.
declare -A GHR_BINS=() GHR_REPO=() GHR_TAGPRE=() GHR_ASSET=() GHR_SUMS=() GHR_VER=()

ghr_expand() { # ghr_expand <template> <ver> <bin>
  local t="$1" os oS x
  os="$(rel_os)"; oS="$(tr '[:lower:]' '[:upper:]' <<< "${os:0:1}")${os:1}"
  x=x86_64; [ "$WST_ARCH" = arm64 ] && x=arm64
  t="${t//\{v\}/$2}"; t="${t//\{bin\}/$3}"; t="${t//\{os\}/$os}"
  t="${t//\{Os\}/$oS}"; t="${t//\{arch\}/$WST_ARCH}"; t="${t//\{x\}/$x}"
  printf '%s\n' "$t"
}

ghr_latest() {
  local id="$1" t pre="${GHR_TAGPRE[$1]}"
  case "$pre" in
    */*) t="$(_curl "https://api.github.com/repos/${GHR_REPO[$id]}/releases?per_page=50" |
           "$WST_JQ" -r --arg p "$pre" '[.[] | select(.prerelease|not) | .tag_name | select(startswith($p))][0] // empty')" || return 1 ;;
    *) t="$(gh_latest_tag "${GHR_REPO[$id]}")" || return 1 ;;
  esac
  [ -n "$t" ] || return 1
  t="${t#"${pre%v}"}"; echo "${t#v}"
}
ghr_pin_ok() {
  local id="$1" pre="${GHR_TAGPRE[$1]}" r="${GHR_REPO[$1]}"
  case "$pre" in */*) pre="${pre//\//%2F}" ;; esac
  _curl -o /dev/null "https://github.com/$r/releases/tag/${pre}$2" 2>/dev/null ||
    _curl -o /dev/null "https://github.com/$r/releases/tag/${pre%v}v$2" 2>/dev/null
}

# bin_probe <bin> <version args...>: managed copy plus the PATH-active one.
bin_probe() {
  local bin="$1" ours active v
  shift
  ours="$(bin_dir)/$bin"; active="$(command -v "$bin" 2>/dev/null || true)"
  if [ -n "$active" ]; then
    v="$(ver_of "$active" "$@")"
    if [ "$active" -ef "$ours" ] 2>/dev/null; then
      printf '%s\t%s\trelease\t-\n' "${v:--}" "$ours"; return 0
    fi
    printf '%s\t%s\tother\t-\n' "${v:--}" "$active"
  fi
  if [ -x "$ours" ] && ! [ "$active" -ef "$ours" ] 2>/dev/null; then
    printf '%s\t%s\trelease\t-\n' "$(ver_of "$ours" "$@")" "$ours"
  fi
  return 0
}

# ghr_install <id> <ver> <result file>
ghr_install() {
  local id="$1" v="$2" res="$3" pre="${GHR_TAGPRE[$1]}" tag b asset base src n=0
  tag="${pre}${v}"; [ "$pre" = "" ] && tag="v$v"; [ "$pre" = = ] && tag="$v"
  base="https://github.com/${GHR_REPO[$id]}/releases/download/$tag"
  for b in ${GHR_BINS[$id]//,/ }; do
    asset="$(ghr_expand "${GHR_ASSET[$id]}" "$v" "$b")"
    rel_fetch_verify "$id" "$base/$asset" "$TOOL_TMP/$asset" "$asset" "$base/$(ghr_expand "${GHR_SUMS[$id]}" "$v" "$b")"
    case "$asset" in
      *.tar.gz|*.tgz|*.zip)
        n=$((n + 1)); rel_extract "$TOOL_TMP/$asset" "$TOOL_TMP/x$n"
        src="$(find "$TOOL_TMP/x$n" -type f -name "$b" | head -n1)"
        [ -n "$src" ] || die "$b not found in $asset"
        rel_put "$src" "$b" ;;
      *) rel_put "$TOOL_TMP/$asset" "$b" ;;
    esac
  done
  result_set "$res" integrity "$DL_STATUS"
}

gh_release_tool() {
  local id="$1" bins="$2" fn="${1//-/_}" first="${2%%,*}"
  GHR_BINS[$id]="$bins"; GHR_REPO[$id]="$3"; GHR_TAGPRE[$id]="$4"
  GHR_ASSET[$id]="$5"; GHR_SUMS[$id]="$6"; GHR_VER[$id]="$7"
  eval "
tool_${fn}_source() { echo release; }
tool_${fn}_latest() { ghr_latest '$id'; }
tool_${fn}_pin_ok() { ghr_pin_ok '$id' \"\$1\"; }
tool_${fn}_probe() { bin_probe '$first' ${GHR_VER[$id]}; }
tool_${fn}_validate() { local b; for b in ${bins//,/ }; do \"\$(bin_dir)/\$b\" ${GHR_VER[$id]} >/dev/null 2>&1 || return 1; done; }
tool_${fn}_remove() { local b; for b in ${bins//,/ }; do rm -f \"\$(bin_dir)/\$b\"; done; }
tool_${fn}_install() { ghr_install '$id' \"\$1\" \"\$2\"; }
"
}

# ---- tools hosted on GitHub releases ----------------------------------------------------------
gh_release_tool eksctl eksctl eksctl-io/eksctl v 'eksctl_{Os}_{arch}.tar.gz' eksctl_checksums.txt version
gh_release_tool kubectx kubectx,kubens ahmetb/kubectx v '{bin}_v{v}_{os}_{x}.tar.gz' checksums.txt --version
gh_release_tool kubecolor kubecolor kubecolor/kubecolor v 'kubecolor_{v}_{os}_{arch}.tar.gz' checksums.txt --kubecolor-version
gh_release_tool k9s k9s derailed/k9s v 'k9s_{Os}_{arch}.tar.gz' checksums.sha256 version -s
gh_release_tool stern stern stern/stern v 'stern_{v}_{os}_{arch}.tar.gz' checksums.txt --version
gh_release_tool kustomize kustomize kubernetes-sigs/kustomize kustomize/v 'kustomize_v{v}_{os}_{arch}.tar.gz' checksums.txt version
gh_release_tool kind kind kubernetes-sigs/kind v 'kind-{os}-{arch}' 'kind-{os}-{arch}.sha256sum' version
gh_release_tool helmfile helmfile helmfile/helmfile v 'helmfile_{v}_{os}_{arch}.tar.gz' 'helmfile_{v}_checksums.txt' --version
gh_release_tool argocd-cli argocd argoproj/argo-cd v 'argocd-{os}-{arch}' cli_checksums.txt version --client --short

# ---- kubectl: dl.k8s.io binary + published .sha256 (hash only) ----------------------------------
kubectl_url() { printf 'https://dl.k8s.io/release/v%s/bin/%s/%s/kubectl\n' "$1" "$(rel_os)" "$WST_ARCH"; }
tool_kubectl_source() { echo release; }
tool_kubectl_latest() { local v; v="$(_curl https://dl.k8s.io/release/stable.txt | tr -d '[:space:]')" || return 1; [ -n "$v" ] && echo "${v#v}"; }
tool_kubectl_pin_ok() { _curl -I -o /dev/null "$(kubectl_url "$1")" 2>/dev/null; }
tool_kubectl_probe() { bin_probe kubectl version --client; }
tool_kubectl_validate() { "$(bin_dir)/kubectl" version --client >/dev/null 2>&1; }
tool_kubectl_remove() { rm -f "$(bin_dir)/kubectl"; }
tool_kubectl_install() {
  local url dest="$TOOL_TMP/kubectl"
  url="$(kubectl_url "$1")"
  rel_fetch_verify kubectl "$url" "$dest" kubectl "$url.sha256"
  rel_put "$dest" kubectl
  result_set "$2" integrity "$DL_STATUS"
}

# ---- helm: get.helm.sh tarball + .sha256sum ----------------------------------------------------
helm_asset() { printf 'helm-v%s-%s-%s.tar.gz\n' "$1" "$(rel_os)" "$WST_ARCH"; }
tool_helm_source() { echo release; }
tool_helm_latest() { local t; t="$(gh_latest_tag helm/helm)" || return 1; echo "${t#v}"; }
tool_helm_pin_ok() { _curl -I -o /dev/null "https://get.helm.sh/$(helm_asset "$1")" 2>/dev/null; }
tool_helm_probe() { bin_probe helm version --short; }
tool_helm_validate() { "$(bin_dir)/helm" version --short >/dev/null 2>&1; }
tool_helm_remove() { rm -f "$(bin_dir)/helm"; }
tool_helm_install() {
  local a src
  a="$(helm_asset "$1")"
  rel_fetch_verify helm "https://get.helm.sh/$a" "$TOOL_TMP/$a" "$a" "https://get.helm.sh/$a.sha256sum"
  rel_extract "$TOOL_TMP/$a" "$TOOL_TMP/x"
  src="$(find "$TOOL_TMP/x" -type f -name helm | head -n1)"
  [ -n "$src" ] || die "helm not found in $a"
  rel_put "$src" helm
  result_set "$2" integrity "$DL_STATUS"
}
