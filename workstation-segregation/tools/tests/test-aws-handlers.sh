#!/bin/bash
# Phase 2 handlers (containers + aws), offline: a stub curl serves canned
# content, and the real group scripts are sourced under Bash 5.
. "$(dirname "$0")/helpers.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/wst-aws.XXXXXX")"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home"

# canned upstream content
printf 'Changelog\n=========\n\n2.38.0\n======\n\n2.37.9\n======\n' > "$T/changelog"
printf '1.2.896.0' > "$T/ssm-version"
{
  printf 'Package: docker-ce-cli\nVersion: 5:27.3.1-1~ubuntu.24.04~noble\n\n'
  printf 'Package: docker-ce-cli\nVersion: 5:27.10.0-1~ubuntu.24.04~noble\n\n'
  printf 'Package: docker-ce-cli\nVersion: 5:26.1.4-1~ubuntu.24.04~noble\n\n'
  printf 'Package: docker-ce\nVersion: 5:25.0.0-1~ubuntu.24.04~noble\n\n'
} | gzip -c > "$T/Packages.gz"
cat > "$T/bin/curl" <<STUB
#!/bin/bash
for a in "\$@"; do u="\$a"; done
case "\$u" in
  *aws-cli/v2/CHANGELOG.rst) cat "$T/changelog" ;;
  *plugin/latest/VERSION) cat "$T/ssm-version" ;;
  *Packages.gz) cat "$T/Packages.gz" ;;
  *) exit 22 ;;
esac
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
for g in containers aws; do . "$WST_ROOT/scripts/$WST_OS/groups/$g.sh"; done
# 1. every non-bundled tool of both groups has the full contract
for id in "${TOOL_IDS[@]}"; do
  case " ${T_GROUPS[$id]} " in *" aws "*|*" containers "*) ;; *) continue ;; esac
  [ "$(tool_home_group "$id")" = base ] && continue
  if [ "${T_REL[$id]}" = bundled ] && ! fn_exists "$id" latest; then echo "follow $id"; continue; fi
  for s in latest probe install remove validate; do
    fn_exists "$id" "$s" && echo "has $id $s" || echo "MISSING $id $s"
  done
done
echo "awscli_url $(awscli_url 2.38.0)"
echo "ssm_url $(ssm_url 1.2.896.0)"
echo "awscli_latest $(tool_awscli_latest)"
echo "ssm_latest $(tool_session_manager_plugin_latest)"
if [ "$WST_OS" = ubuntu ]; then
  echo "sam_url $(sam_url 1.169.0)"
  # The archive's installer is directly inside the extraction directory.
  TOOL_TMP="$(mktemp -d "$HOME/sam-test.XXXXXX")"
  dl_fetch() { : > "$2"; }
  dl_verify() { DL_STATUS=unverified; }
  rel_extract() {
    mkdir -p "$2"
    printf '#!/bin/bash\nprintf "%%s\\n" "$*" > "$(dirname "$0")/args"\n' > "$2/install"
    chmod +x "$2/install"
  }
  ( set -e; tool_aws_sam_install 1.169.0 "$TOOL_TMP/result" ) && echo "sam_install ok"
  echo "sam_args $(cat "$TOOL_TMP/x/args")"
  echo "sam_integrity $(cat "$TOOL_TMP/result")"
  echo "docker_latest $(tool_docker_cli_latest)"
  echo "docker_resolve $(docker_resolve docker-ce-cli 27.3.1)"
  docker_resolve docker-ce-cli 99.0 >/dev/null && echo "BAD resolve" || echo "unknown pin rejected"
fi
DRV

run_driver() { "$BASH5" "$T/driver.sh" "$TOOLS_DIR" "$1" "$2" "$T/home" "$T/bin" 2>&1; }

U="$(run_driver ubuntu amd64)"
M="$(run_driver macos arm64)"
assert_not_contains "$U" MISSING "ubuntu contract"
assert_not_contains "$M" MISSING "macos contract"
for id in docker-cli docker-engine docker-compose docker-buildx awscli session-manager-plugin aws-cdk aws-sam; do
  assert_contains "$U" "has $id install" "ubuntu $id"
  assert_contains "$M" "has $id install" "macos $id"
done
assert_contains "$U" "follow docker" "docker follows docker-cli (ubuntu)"
assert_contains "$M" "follow docker" "docker follows docker-cli (macos)"
assert_contains "$U" "awscli_url https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.38.0.zip" "linux awscli url"
assert_contains "$M" "awscli_url https://awscli.amazonaws.com/AWSCLIV2-2.38.0.pkg" "macos awscli url"
assert_contains "$U" "ssm_url https://s3.amazonaws.com/session-manager-downloads/plugin/1.2.896.0/ubuntu_64bit/session-manager-plugin.deb" "ubuntu ssm url"
assert_contains "$M" "ssm_url https://s3.amazonaws.com/session-manager-downloads/plugin/1.2.896.0/mac_arm64/session-manager-plugin.pkg" "macos arm64 ssm url"
assert_contains "$U" "awscli_latest 2.38.0" "awscli latest from changelog"
assert_contains "$U" "ssm_latest 1.2.896.0" "ssm latest from VERSION"
assert_contains "$U" "sam_url https://github.com/aws/aws-sam-cli/releases/download/v1.169.0/aws-sam-cli-linux-x86_64.zip" "sam url"
assert_contains "$U" "sam_install ok" "SAM invokes extracted installer"
assert_contains "$U" "sam_args -i $T/home/.local/share/aws-sam-cli -b $T/home/.local/bin --update" "SAM install paths"
assert_contains "$U" "sam_integrity integrity=unverified" "SAM integrity recorded"
if command -v dpkg >/dev/null 2>&1; then   # dpkg --compare-versions exists on Ubuntu only
  assert_contains "$U" "docker_latest 5:27.10.0-1~ubuntu.24.04~noble" "docker latest is the max, not the first"
fi
assert_contains "$U" "docker_resolve 5:27.3.1-1~ubuntu.24.04~noble" "pin without epoch/revision resolves"
assert_contains "$U" "unknown pin rejected" "unknown docker pin"

finish
