#!/bin/bash
# bin/agy-migrate.sh against disposable clients: gating, dry run, unset-then-apply,
# idempotence, login-state preservation, skips and rollback. Never runs AGY.
set -Eeuo pipefail
kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/wsk-agy-migrate.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
trap 'rm -rf "$fixture"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
root="$fixture/clients"
mkdir -p "$fixture/home" "$fixture/bin" "$root"

client() { # client <name>: an existing (adopted) client without AGY
  mkdir -p "$root/$1/.workstation/git" "$root/$1/.workstation/bash"
  printf 'export WORKSTATION_CLIENT=%s\n' "$1" > "$root/$1/.envrc"
  printf '[user]\n\tname = %s\n' "$1" > "$root/$1/.workstation/git/config"
}
client fresh; client stale; client links; client relocating
mkdir -p "$root/plain"                       # not segregated: never a client
mkdir -p "$root/workstation-segregation/.workstation"   # excluded by default

conf() { # conf <agy flag>
  printf 'CLIENT_ROOT=%s\nBIN_DIR=%s\nENABLE_AGENT_CLI_ISOLATION=1\nENABLE_AGY_CLI_ISOLATION=%s\n' \
    "$root" "$fixture/bin" "$1" > "$fixture/config"
}
migrate() {
  env HOME="$fixture/home" XDG_STATE_HOME="$fixture/home/state" XDG_CONFIG_HOME="$fixture/home/config" \
    /bin/bash "$kit/bin/agy-migrate.sh" --config "$fixture/config" "$@"
}
snapshot() { find "$root" \( -type f -o -type l -o -type d \) -print | sort | while read -r p; do
  if [ -f "$p" ] && [ ! -L "$p" ]; then printf '%s %s\n' "$p" "$(shasum < "$p")"; else printf '%s\n' "$p"; fi; done; }
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

# Gate: apply refuses unless both flags are on.
conf 0
if migrate fresh > "$fixture/out" 2>&1; then fail 'applied with ENABLE_AGY_CLI_ISOLATION=0'; fi
grep -q 'ENABLE_AGY_CLI_ISOLATION=1' "$fixture/out" || fail 'gate message'
[ ! -e "$root/fresh/.workstation/agy" ] || fail 'gate left changes'
conf 1
if migrate > /dev/null 2>&1; then fail 'ran without clients'; fi
if migrate --all fresh > /dev/null 2>&1; then fail 'accepted --all with names'; fi

# Stale state from an older kit, with a login that must survive.
mkdir -p "$root/stale/.workstation/agy/home/.gemini" "$root/stale/.workstation/agy/tmp"
printf 'login-state\n' > "$root/stale/.workstation/agy/home/.gemini/token"
printf 'agy() { /old/kit/bin/agy-client.sh "$@"; }\n' > "$root/stale/.workstation/bash/agy.sh"
printf '[include]\n\tpath = /elsewhere/config\n' > "$root/stale/.workstation/agy/gitconfig"
# A redirected private home is refused, not repaired.
mkdir -p "$root/links/.workstation/agy" "$fixture/outside"
ln -s "$fixture/outside" "$root/links/.workstation/agy/home"
printf 'export ANTIGRAVITY_APP_DATA_DIR=x\n' >> "$root/relocating/.envrc"
cp "$root/relocating/.envrc" "$fixture/relocating.envrc"

# Dry run changes nothing.
snapshot > "$fixture/before"
migrate --dry-run fresh stale > "$fixture/dry" 2>&1 || fail 'dry run failed'
snapshot > "$fixture/after"
cmp -s "$fixture/before" "$fixture/after" || fail 'dry run changed files'
grep -q "DRY-RUN: create $root/stale/.workstation/bash/agy.sh" "$fixture/dry" || fail 'dry run hides stale replacement'

# --all: segregated, non-excluded clients only; the linked one fails the run.
if migrate --all > "$fixture/all" 2>&1; then fail 'redirected agy/home was accepted'; fi
grep -q 'not migrated: links' "$fixture/all" || fail 'links not reported'
grep -q 'ANTIGRAVITY_APP_DATA_DIR' "$fixture/all" || fail 'relocation export not reported'
cmp -s "$fixture/relocating.envrc" "$root/relocating/.envrc" || fail '.envrc was edited'
[ ! -e "$root/plain/.workstation" ] || fail 'unsegregated dir scaffolded'
[ ! -e "$root/workstation-segregation/.workstation/agy" ] || fail 'excluded dir scaffolded'
[ ! -e "$root/links/.workstation/bash/agy.sh" ] || fail 'linked client got the wrapper'

for c in fresh stale relocating; do
  w="$root/$c/.workstation"
  for d in agy agy/home agy/tmp; do
    [ -d "$w/$d" ] && [ "$(mode_of "$w/$d")" = 700 ] || fail "$c: $d missing or not 700"
  done
  [ "$(mode_of "$w/agy/gitconfig")" = 600 ] || fail "$c: gitconfig mode"
  [ "$(git config --file "$w/agy/gitconfig" include.path)" = "$w/git/config" ] || fail "$c: gitconfig include"
  grep -qF "\"$kit/bin/agy-client.sh\"" "$w/bash/agy.sh" || fail "$c: fragment does not use this kit"
  [ "$(mode_of "$w/bash/agy.sh")" = 644 ] || fail "$c: fragment mode"
done
# Unset-then-apply: stale files backed up and replaced; login state untouched.
ls "$root/stale/.workstation/bash/agy.sh.bak."* > /dev/null 2>&1 || fail 'stale fragment not backed up'
ls "$root/stale/.workstation/agy/gitconfig.bak."* > /dev/null 2>&1 || fail 'stale gitconfig not backed up'
if grep -q /old/kit "$root/stale/.workstation/bash/agy.sh"; then fail 'stale fragment kept'; fi
[ "$(cat "$root/stale/.workstation/agy/home/.gemini/token")" = login-state ] || fail 'login state changed'
[ -z "$(ls -A "$fixture/outside")" ] || fail 'wrote through a redirected home'

# The wrapper the migration installed loads and defines agy().
( . "$root/fresh/.workstation/bash/agy.sh"; declare -F agy > /dev/null ) || fail 'fragment does not define agy'

# Repeat runs are no-ops (no new backups either).
snapshot > "$fixture/before"
migrate fresh stale relocating > "$fixture/again" 2>&1 || fail 'repeat run failed'
snapshot > "$fixture/after"
cmp -s "$fixture/before" "$fixture/after" || fail 'repeat run changed files'
grep -q 'fresh: AGY wrapper fragment is current' "$fixture/again" || fail 'repeat run message'

# Unknown names fail; --remove is a rollback that keeps the private home, even with the flag off.
if migrate nosuch > /dev/null 2>&1; then fail 'accepted a missing client'; fi
if migrate plain > /dev/null 2>&1; then fail 'accepted an unsegregated dir'; fi
baks() { find "$root/stale/.workstation/bash" -name 'agy.sh.bak.*' | wc -l | tr -d ' '; }
before_baks=$(baks)
sleep 1   # backups are stamped to the second
conf 0
migrate --remove stale > /dev/null 2>&1 || fail 'remove failed'
[ ! -e "$root/stale/.workstation/bash/agy.sh" ] || fail 'fragment not removed'
[ "$(cat "$root/stale/.workstation/agy/home/.gemini/token")" = login-state ] || fail 'remove touched login state'
[ "$(baks)" -gt "$before_baks" ] || fail 'remove kept no backup'

printf 'PASS: AGY migration gate, dry run, unset-then-apply, idempotence, skips, login preservation and removal\n'
