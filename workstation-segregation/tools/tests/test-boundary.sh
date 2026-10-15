#!/bin/bash
# Real shell boundary: Bash 3.2 orchestrator -> exec -> Bash 5 engine, package
# tools stubbed. Never touches the real HOME, Homebrew, /etc/shells or chsh.
. "$(dirname "$0")/helpers.sh"
SYS_BASH=/bin/bash
new_fixture; set_latest_all
trap cleanup_fixture EXIT
S="$FX/stubs"; mkdir -p "$S" "$FX/brew/bin"
SPY="$FX/spy.log"; : > "$SPY"
REAL_JQ="$JQ"

mkstub() { printf '#!/bin/bash\n%s\n' "$2" > "$S/$1"; chmod +x "$S/$1"; }
mkstub sudo 'echo "sudo $*" >> "'$SPY'"; case "$1" in -v) exit 0 ;; tee) cat >/dev/null; exit 0 ;; esac; exit 0'
mkstub chsh 'echo "chsh $*" >> "'$SPY'"; exit 0'
mkstub apt-get 'echo "apt-get $*" >> "'$SPY'"'
mkstub softwareupdate 'echo "softwareupdate $*" >> "'$SPY'"'
mkstub xcode-select 'case "$1" in -p) echo /Library/Developer/CommandLineTools; exit 0 ;; esac; echo "xcode-select $*" >> "'$SPY'"'
mkstub dpkg 'exit 0'
mkstub dscl 'echo "UserShell: $STUB_SHELL"'
mkstub brew 'case "$1" in
  --prefix) echo "'$FX'/brew" ;;
  shellenv) ;;
  --version) echo "Homebrew 9.9.9" ;;
  list) echo "brew list $*" >> "'$SPY'"; exit 0 ;;
  *) echo "brew $*" >> "'$SPY'" ;;
esac'
cat > "$S/curl" <<STUB
#!/bin/bash
echo "curl \$*" >> "$SPY"
url=""; out=""; wfmt=0
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift ;;
    -w) wfmt=1; shift ;;
    http*) url="\$1" ;;
  esac
  shift
done
case "\$url" in
  */jqlang/jq/releases/latest) printf 'https://github.com/jqlang/jq/releases/tag/jq-1.7.1' ;;
  */nvm-sh/nvm/releases/latest) printf 'https://github.com/nvm-sh/nvm/releases/tag/v0.40.0' ;;
  */jq-macos-*|*/jq-linux-*) cp "$REAL_JQ" "\$out" ;;
  */sha256sum.txt) a=\$(basename "\$(ls "$FX"/jqdl 2>/dev/null | head -1)"); h=\$(shasum -a 256 "$REAL_JQ" | cut -d' ' -f1)
     printf '%s  jq-macos-arm64\n%s  jq-macos-amd64\n%s  jq-linux-amd64\n%s  jq-linux-arm64\n' \$h \$h \$h \$h > "\$out" ;;
  */nvm-sh/nvm/*/install.sh) printf 'mkdir -p "\$NVM_DIR"; printf "nvm() { :; }\n" > "\$NVM_DIR/nvm.sh"\n' > "\$out" ;;
  *) exit 22 ;;
esac
exit 0
STUB
chmod +x "$S/curl"
ln -s "$BASH5" "$FX/brew/bin/bash"

orch() { # orch <shell-var> args... : run the orchestrator under stock bash from another cwd
  local shellvar="$1"; shift
  set +e
  OUT="$(cd "$FX/project" && env -i HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" TMPDIR="$FX" PATH="$S:/usr/bin:/bin:/usr/sbin:/sbin:$(dirname "$JQ")" \
    STUB_SHELL="$shellvar" WST_OS=macos WST_ARCH=arm64 WST_BREW="$S/brew" WST_BOOTSTRAP_DIR="$FX/boot" NVM_DIR="$FX/nvm" \
    FAKE_WORLD="$FAKE_WORLD" FAKE_BIN="$FAKE_BIN" WST_TRACE_FILE="$WST_TRACE_FILE" \
    WST_PLATFORM_DIR="$TESTS_DIR/fixtures/platform-fake" WST_CATALOG_DIR="$TOOLS_DIR/scripts/common/catalog" \
    "$SYS_BASH" "$TOOLS_DIR/setup-workstation.sh" "$@" 2>&1 </dev/null)"
  RC=$?
  set -e
}

# 1. dry-run: exec happens, args preserved, nothing mutated
before="$(snapshot "$FX/home"; snapshot "$FX/project")"
orch "$FX/brew/bin/bash" --dry-run --groups github
assert_rc "$RC" 0 "dry-run"
assert_contains "$OUT" "DRY-RUN: brew update" "brew update planned"
assert_contains "$OUT" "gh " "engine plan reached with forwarded --groups"
assert_not_contains "$OUT" "ERROR" "no errors"
after="$(snapshot "$FX/home"; snapshot "$FX/project")"
if [ "$after" = "$before" ]; then ok; else fail "dry-run changed home/project"; echo "$before" > "$FX/b.txt"; echo "$after" > "$FX/a.txt"; diff "$FX/b.txt" "$FX/a.txt" | head -5 >&2; fi
assert_not_contains "$(cat "$SPY")" "sudo tee" "no /etc/shells write in dry-run"
assert_not_contains "$(cat "$SPY")" "chsh" "no chsh in dry-run"
assert_not_contains "$(cat "$SPY")" "brew update" "no brew update in dry-run"
assert_not_contains "$(cat "$SPY")" "apt-get" "no apt-get"
assert_no_file "$FX/boot"

# 2. dry-run with Bash 5 missing: prerequisites only, exit 0
rm "$FX/brew/bin/bash"
orch "$FX/brew/bin/bash" --dry-run
assert_rc "$RC" 0 "dry-run without bash5"
assert_contains "$OUT" "full plan needs Bash 5" "explains partial plan"
ln -s "$BASH5" "$FX/brew/bin/bash"

# 3. real run: lock held across exec and released, state written, summary shows prerequisites
orch "$FX/brew/bin/bash" --groups github
assert_rc "$RC" 0 "real run"
assert_contains "$OUT" "Prerequisites:" "prerequisite report"
assert_file "$FX/boot/bin/jq"
assert_eq "$(requested_value gh)" latest "forwarded args reached the engine"
assert_eq "$(installed_field gh status)" installed "engine ran"
assert_no_file "$XDG_STATE_HOME/workstation-tools/lock"
assert_contains "$(cat "$SPY")" "brew upgrade bash" "bash upgraded"

# 4. login shell change -> exit 75, lock released
orch /bin/zsh --groups github
assert_rc "$RC" 75 "restart status"
assert_contains "$OUT" "NEW terminal" "restart message"
assert_contains "$(cat "$SPY")" "chsh -s $FX/brew/bin/bash" "chsh called"
assert_no_file "$XDG_STATE_HOME/workstation-tools/lock"

# 5. engine failure still releases the lock
flag failinstall gh; set_latest gh 9.0.0
orch "$FX/brew/bin/bash" --groups github
assert_rc "$RC" 1 "engine failure propagates"
assert_no_file "$XDG_STATE_HOME/workstation-tools/lock"

# 6. contention: the orchestrator refuses a held lock
mkdir -p "$XDG_STATE_HOME/workstation-tools/lock"; echo $$ > "$XDG_STATE_HOME/workstation-tools/lock/pid"
orch "$FX/brew/bin/bash" --groups github
assert_rc "$RC" 1 "held lock"
assert_contains "$OUT" "in progress" "contention message"
finish
