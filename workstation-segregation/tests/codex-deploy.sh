#!/bin/bash
# Exercise deploy twice in a disposable home, with a stub scheduler.
set -Eeuo pipefail
kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d /private/tmp/wsk-deploy.XXXXXX)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home" "$fixture/clients/existing/.workstation/bash" "$fixture/bin"
printf '# WORKSTATION_CLIENT keep existing behavior\n' > "$fixture/clients/existing/.envrc"
printf '# custom fragment\n' > "$fixture/clients/existing/.workstation/bash/custom.sh"
cat > "$fixture/bin/crontab" <<'STUB'
#!/bin/bash
case "${1:-}" in
  -l) [ -f "$HOME/stub-crontab" ] && cat "$HOME/stub-crontab" || exit 1 ;;
  -) cat > "$HOME/stub-crontab" ;;
  -r) rm -f "$HOME/stub-crontab" ;;
  *) exit 2 ;;
esac
STUB
chmod 755 "$fixture/bin/crontab"
printf 'CLIENT_ROOT=%s/clients\nBIN_DIR=%s/bin\nADOPT_DIRS="new"\n' "$fixture" "$fixture" > "$fixture/config"
mkdir -p "$fixture/clients/new"
deploy_fixture() {
  env HOME="$fixture/home" SHELL=/bin/bash PATH="$fixture/bin:$PATH" \
    XDG_CONFIG_HOME="$fixture/home/config" XDG_STATE_HOME="$fixture/home/state" \
    XDG_DATA_HOME="$fixture/home/data" \
    /bin/bash "$kit/deploy.sh" --config "$fixture/config" --skip-tools "$@"
}
snapshot() { find "$fixture/home" "$fixture/clients" -type f -exec shasum {} \; | sort; }
snapshot > "$fixture/before"
deploy_fixture --dry-run > "$fixture/dry.log" 2>&1
snapshot > "$fixture/after"
cmp -s "$fixture/before" "$fixture/after"
deploy_fixture > "$fixture/first.log" 2>&1
[ -f "$fixture/clients/new/.workstation/bash/codex.sh" ]
[ ! -e "$fixture/clients/existing/.workstation/bash/codex.sh" ]
grep -qx '# WORKSTATION_CLIENT keep existing behavior' "$fixture/clients/existing/.envrc"
grep -qx '# custom fragment' "$fixture/clients/existing/.workstation/bash/custom.sh"
[ -f "$fixture/clients/existing/.workstation/openai/env" ]
snapshot > "$fixture/before"
deploy_fixture > "$fixture/second.log" 2>&1
snapshot > "$fixture/after"
cmp -s "$fixture/before" "$fixture/after"
printf 'PASS: full deploy dry-run, adoption preservation and repeat-deploy idempotence\n'
