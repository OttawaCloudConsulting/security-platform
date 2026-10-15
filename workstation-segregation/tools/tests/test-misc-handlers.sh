#!/bin/bash
# ansible, go and database-* handlers, offline: contract completeness, Go
# release-record selection and checksum verification against a canned go.dev feed.
. "$(dirname "$0")/helpers.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/wst-misc.XXXXXX")"; [ -n "${KEEP:-}" ] || trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home" "$T/tmp"

# a fake Go archive and a feed describing it for every platform
mkdir -p "$T/pkg/go/bin"
printf '#!/bin/sh\necho "go version go1.25.2 test/test"\n' > "$T/pkg/go/bin/go"
printf '#!/bin/sh\n' > "$T/pkg/go/bin/gofmt"
chmod +x "$T/pkg/go/bin/go" "$T/pkg/go/bin/gofmt"
tar -czf "$T/go.tgz" -C "$T/pkg" go
SHA="$(shasum -a 256 "$T/go.tgz" | cut -d' ' -f1)"
mkfeed() { # mkfeed <sha>
  local os arch files="" sep=""
  for os in linux darwin; do for arch in amd64 arm64; do
    files="$files$sep{\"filename\":\"go1.25.2.$os-$arch.tar.gz\",\"os\":\"$os\",\"arch\":\"$arch\",\"kind\":\"archive\",\"sha256\":\"$1\"}"; sep=,
  done; done
  printf '[{"version":"go1.25.2","stable":true,"files":[%s]},{"version":"go1.26rc1","stable":false,"files":[]},{"version":"go1.24.8","stable":true,"files":[]}]' "$files" > "$T/feed.json"
}
mkfeed "$SHA"
cat > "$T/bin/curl" <<STUB
#!/bin/bash
for a in "\$@"; do u="\$a"; done
out=""; prev=""
for a in "\$@"; do [ "\$prev" = -o ] && out="\$a"; prev="\$a"; done
case "\$u" in
  *go.dev/dl/\?mode=json*) src="$T/feed.json" ;;
  *go.dev/dl/*.tar.gz) src="$T/go.tgz" ;;
  file://*) src="\${u#file://}" ;;
  *) exit 22 ;;
esac
if [ -n "\$out" ]; then cp "\$src" "\$out"; else cat "\$src"; fi
STUB
chmod +x "$T/bin/curl"

cat > "$T/driver.sh" <<'DRV'
set -u
export WST_ROOT="$1" WST_OS="$2" WST_ARCH="$3" HOME="$4" PATH="$5:$PATH" TMPDIR="$6"
export WST_JQ="$7" WST_CATALOG_DIR="$WST_ROOT/scripts/common/catalog"
. "$WST_ROOT/scripts/common/common.sh"
. "$WST_ROOT/scripts/common/catalog.sh"
. "$WST_ROOT/scripts/common/versions.sh"
. "$WST_ROOT/scripts/common/download.sh"
catalog_load
for g in ansible go database-postgres database-mysql database-redis; do . "$WST_ROOT/scripts/$WST_OS/groups/$g.sh"; done
for id in ansible go psql mysql-client redis-cli; do
  for s in latest source probe install remove validate pin_ok; do
    fn_exists "$id" "$s" && echo "has $id $s" || echo "MISSING $id $s"
  done
done
tool_go_latest; echo "go_latest $(tool_go_latest)"
tool_go_pin_ok 1.24.8 && echo "pin 1.24.8 ok"
tool_go_pin_ok 1.26rc1 && echo "BAD rc pin" || echo "rc pin rejected"
TOOL_TMP="$HOME/tt"; mkdir -p "$TOOL_TMP"
if ( tool_go_install 1.25.2 "$HOME/res" ); then echo "go_install ok"; else echo "go_install FAILED"; fi
cat "$HOME/res" 2>/dev/null
tool_go_validate && echo "go_validate ok"
[ -x "$HOME/.local/share/go/bin/go" ] && echo "go_home ok"
tool_go_probe
tool_go_remove
[ -e "$HOME/.local/bin/go" ] || [ -e "$HOME/.local/share/go" ] && echo "BAD remove" || echo "go_removed"
DRV
JQBIN="${WST_JQ:-$(command -v jq)}"
run_driver() { rm -rf "${T:?}/home" "${T:?}/tmp"; mkdir -p "$T/home" "$T/tmp"
  "$BASH5" "$T/driver.sh" "$TOOLS_DIR" "$1" "$2" "$T/home" "$T/bin" "$T/tmp" "$JQBIN" 2>&1; }

for os in ubuntu macos; do
  O="$(run_driver "$os" amd64)"
  assert_not_contains "$O" MISSING "$os contract"
  assert_contains "$O" "go_latest 1.25.2" "$os go latest skips unstable"
  assert_contains "$O" "pin 1.24.8 ok" "$os stable pin"
  assert_contains "$O" "rc pin rejected" "$os unstable pin"
  assert_contains "$O" "go_install ok" "$os go install"
  assert_contains "$O" "integrity=verified" "$os go integrity"
  assert_contains "$O" "go_home ok" "$os go home"
  assert_contains "$O" "go_removed" "$os go remove"
done

mkfeed 0000000000000000000000000000000000000000000000000000000000000000
O="$(run_driver ubuntu arm64)"
assert_contains "$O" "go_install FAILED" "checksum mismatch rejected"
assert_no_file "$T/home/.local/share/go"

finish
