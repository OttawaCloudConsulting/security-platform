#!/bin/bash
# azcli is opt-in: absent from the default tool list, refuses to install without a
# suitable python3 (leaving any working install alone), and installs/uninstalls cleanly
# with stub python3/pip. No network: the stubs stand in for python3, venv and pip.
set -Eeuo pipefail
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KIT_ROOT
fixture="$(mktemp -d "${TMPDIR:-/tmp}/wsk-azcli.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/home"
mkdir -p "$HOME" "$fixture/stubbin"
fail() { echo "FAIL: $*" >&2; exit 1; }

# shellcheck source=/dev/null
. "$KIT_ROOT/lib/common.sh"
# shellcheck source=/dev/null
. "$KIT_ROOT/lib/tools.sh"

# 1. Not part of the default tool list, nor of the example config.
: > "$fixture/empty.conf"
load_config "$fixture/empty.conf"
case " $INSTALL_TOOLS " in *" azcli "*) fail "azcli is in the default INSTALL_TOOLS: $INSTALL_TOOLS" ;; esac
load_config "$KIT_ROOT/workstation-segregation.conf.example"
case " $INSTALL_TOOLS " in *" azcli "*) fail "azcli is in the example INSTALL_TOOLS: $INSTALL_TOOLS" ;; esac
[ "$(tool_bins azcli)" = az ] || fail "azcli should provide the az binary, got: $(tool_bins azcli)"

BIN_DIR="$fixture/bin"; mkdir -p "$BIN_DIR"
# These are read by the sourced kit functions.
# shellcheck disable=SC2034
REQUIRE_CHECKSUMS=0
DRY_RUN=0
LOCK_FILE="$fixture/versions.lock"   # default lives in the kit directory; keep the test out of it

# python3 stub: PY_VERSION_OK=0/1 answers the version probe; `-m venv DIR` builds a
# venv whose python stubs `-m pip install` by creating DIR/bin/az.
cat > "$fixture/stubbin/python3" <<'STUB'
#!/bin/bash
case "$1" in
  -c) [ "${PY_VERSION_OK:-1}" = 1 ]; exit $? ;;
  -V) echo "Python 3.9.6"; exit 0 ;;
  -m)
    [ "$2" = venv ] || exit 2
    mkdir -p "$3/bin"
    cat > "$3/bin/python" <<'PYSTUB'
#!/bin/bash
[ "$1 $2 $3" = "-m pip install" ] || exit 2
[ "${PIP_FAIL:-0}" = 0 ] || exit 1
d="$(cd "$(dirname "$0")" && pwd)"
printf '#!/bin/bash\necho azure-cli stub\n' > "$d/az"; chmod 755 "$d/az"
PYSTUB
    chmod 755 "$3/bin/python"; exit 0 ;;
esac
exit 2
STUB
chmod 755 "$fixture/stubbin/python3"
export PATH="$fixture/stubbin:$PATH"

venv="$HOME/.local/azure-cli"
install_azcli() { ( set -e; tool_azcli_install 9.9.9 ) >"$fixture/install.log" 2>&1; }

# 2. Too-old python3: refuse, and do not touch an existing working install.
mkdir -p "$venv/bin"; printf 'keep\n' > "$venv/bin/az"
PY_VERSION_OK=0 install_azcli && fail "install succeeded with python3 < 3.10"
grep -q 'python3 >= 3.10' "$fixture/install.log" || fail "no python3 >= 3.10 message: $(cat "$fixture/install.log")"
[ "$(cat "$venv/bin/az")" = keep ] || fail "existing install was removed by a refused install"
rm -rf "$venv"

# 3. REQUIRE_CHECKSUMS=1 refuses (PyPI has no verifiable checksum).
REQUIRE_CHECKSUMS=1 install_azcli && fail "install succeeded with REQUIRE_CHECKSUMS=1"
grep -q 'REQUIRE_CHECKSUMS' "$fixture/install.log" || fail "no REQUIRE_CHECKSUMS message"

# 4. Successful install links az into BIN_DIR.
install_azcli || fail "install failed: $(cat "$fixture/install.log")"
[ -x "$BIN_DIR/az" ] && [ -L "$BIN_DIR/az" ] || fail "az not linked into BIN_DIR"
[ "$("$BIN_DIR/az")" = "azure-cli stub" ] || fail "linked az does not run"

# 5. Uninstall removes the link and the private venv.
lock_set azcli 9.9.9
uninstall_tools >/dev/null 2>&1
[ ! -e "$BIN_DIR/az" ] && [ ! -L "$BIN_DIR/az" ] || fail "uninstall left the az link"
[ ! -e "$venv" ] || fail "uninstall left the azure-cli venv"

# 6. A failing pip install leaves no half-built venv.
PIP_FAIL=1 install_azcli && fail "install succeeded although pip failed"
[ ! -e "$venv" ] || fail "half-built venv left behind"

echo "PASS: azcli is opt-in, checks python3 before touching an install, installs and fails cleanly"
