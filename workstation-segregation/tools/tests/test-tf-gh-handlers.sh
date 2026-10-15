#!/bin/bash
# terraform / terragrunt / github handlers, offline: a stub curl serves canned
# content and the real group scripts are sourced under Bash 5.
. "$(dirname "$0")/helpers.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/wst-tf.XXXXXX")"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home" "$T/srv"

printf 'terraform_1.10.0-rc1<\nterraform_1.9.8<\nterraform_1.9.7<\n' > "$T/tf-index"
printf 'binary-bytes' > "$T/srv/terragrunt_linux_amd64"
good="$(sha256_of() { shasum -a 256 "$1" | cut -d' ' -f1; }; sha256_of "$T/srv/terragrunt_linux_amd64")"
printf '%s  terragrunt_linux_amd64\n' "$good" > "$T/srv/SHA256SUMS"
cat > "$T/bin/curl" <<STUB
#!/bin/bash
out=""; w=0; u=""
while [ \$# -gt 0 ]; do
  case "\$1" in -o) out="\$2"; shift ;; -w) w=1; shift ;; --retry|--connect-timeout) shift ;; -*) ;; *) u="\$1" ;; esac
  shift
done
if [ "\$w" = 1 ]; then echo "\${u%/latest}/tag/v1.1.6"; exit 0; fi
case "\$u" in
  */terraform/) src="$T/tf-index" ;;
  */releases/download/v1.1.6/*) src="$T/srv/\${u##*/}" ;;
  *) exit 22 ;;
esac
[ -f "\$src" ] || exit 22
if [ -n "\$out" ] && [ "\$out" != /dev/null ]; then cp "\$src" "\$out"; else cat "\$src"; fi
STUB
chmod +x "$T/bin/curl"

cat > "$T/driver.sh" <<'DRV'
set -u
export WST_ROOT="$1" WST_OS="$2" WST_ARCH="$3" HOME="$4" PATH="$5:$PATH"
export WST_JQ=true WST_CATALOG_DIR="$WST_ROOT/scripts/common/catalog"
. "$WST_ROOT/scripts/common/common.sh"
. "$WST_ROOT/scripts/common/catalog.sh"
. "$WST_ROOT/scripts/common/versions.sh"
. "$WST_ROOT/scripts/common/download.sh"
catalog_load
for g in terraform terragrunt github; do . "$WST_ROOT/scripts/$WST_OS/groups/$g.sh"; done
for id in terraform tfenv terragrunt gh; do
  for s in latest probe install remove validate pin_ok source; do
    fn_exists "$id" "$s" && echo "has $id $s" || echo "MISSING $id $s"
  done
done
echo "gh_asset $(rel_gh_asset 2.60.0)"
echo "gh_sums $(rel_gh_sums 2.60.0 BASE x)"
echo "tg_asset $(rel_terragrunt_asset)"
echo "tf_latest $(tool_terraform_latest)"
echo "tfenv_latest $(tool_tfenv_latest)"
echo "tg_latest $(tool_terragrunt_latest)"
echo "gh_latest $(tool_gh_latest)"
if [ "$WST_OS" = ubuntu ]; then
  TOOL_TMP="$(mktemp -d "$TMPDIR/wst-i.XXXXXX")"; : > "$TOOL_TMP/result"
  ( set -e; tool_terragrunt_install 1.1.6 "$TOOL_TMP/result" ) && echo "tg_install ok $(cat "$TOOL_TMP/result")"
  [ -x "$HOME/.local/bin/terragrunt" ] && echo "tg_bin present"
  rm -f "$HOME/.local/bin/terragrunt"
  printf 'tampered' >> "$5/../srv/terragrunt_linux_amd64"
  ( set -e; tool_terragrunt_install 1.1.6 "$TOOL_TMP/result" ) >/dev/null 2>&1 && echo "BAD tampered installed" || echo "tampered rejected"
  [ -e "$HOME/.local/bin/terragrunt" ] && echo "BAD bin exists"
fi
DRV

run_driver() { TMPDIR="$T" "$BASH5" "$T/driver.sh" "$TOOLS_DIR" "$1" "$2" "$T/home" "$T/bin" 2>&1; }
U="$(run_driver ubuntu amd64)"
M="$(run_driver macos arm64)"
assert_not_contains "$U" MISSING "ubuntu contract"
assert_not_contains "$M" MISSING "macos contract"
assert_contains "$U" "gh_asset gh_2.60.0_linux_amd64.tar.gz" "linux gh asset"
assert_contains "$M" "gh_asset gh_2.60.0_macOS_arm64.zip" "macos gh asset"
assert_contains "$U" "gh_sums BASE/gh_2.60.0_checksums.txt" "gh checksum file"
assert_contains "$U" "tg_asset terragrunt_linux_amd64" "linux terragrunt asset"
assert_contains "$M" "tg_asset terragrunt_darwin_arm64" "macos terragrunt asset"
assert_contains "$U" "tf_latest 1.9.8" "terraform latest skips prereleases"
assert_contains "$U" "tfenv_latest 1.1.6" "tfenv latest from tag"
assert_contains "$U" "tg_latest 1.1.6" "terragrunt latest"
assert_contains "$U" "gh_latest 1.1.6" "gh latest strips v"
assert_contains "$U" "tg_install ok integrity=verified" "terragrunt checksum verified"
assert_contains "$U" "tg_bin present" "terragrunt installed to bin_dir"
assert_contains "$U" "tampered rejected" "mismatch fails the install"
assert_not_contains "$U" "BAD" "no unverified artifact left"
finish
