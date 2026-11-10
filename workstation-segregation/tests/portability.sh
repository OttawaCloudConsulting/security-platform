#!/bin/bash
# Self-test for scripts/check-workstation-portability.sh: the clean tree passes and
# each planted violation is reported under its stable label. Works on a copy of the
# tracked kit files in a temp directory; never touches the working tree.
# Skips (exit 0) when the checker or git history is unavailable, e.g. when the kit is
# used outside the repository that carries the checker.
set -Eeuo pipefail
kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$kit/../scripts/check-workstation-portability.sh"
[ -f "$checker" ] || { echo "SKIP: $checker not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }
git -C "$kit" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "SKIP: kit is not in a git work tree"; exit 0; }

fixture="$(mktemp -d "${TMPDIR:-/tmp}/wsk-portability.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
trap 'rm -rf "$fixture"' EXIT

pristine="$fixture/pristine"
mkdir -p "$pristine"
# Tracked files only: untracked local state (config, backups) must not leak into the copy.
( cd "$kit" && git ls-files -z ) | while IFS= read -r -d '' f; do
  [ -f "$kit/$f" ] || continue
  mkdir -p "$pristine/$(dirname "$f")"
  cp -p "$kit/$f" "$pristine/$f"
done

nodeny="$fixture/no-such-denylist"
fail() { echo "FAIL: $*" >&2; exit 1; }

run_checker() { # run_checker <dir> [env VAR=value ...]; sets OUT and RC
  local dir="$1"; shift
  set +e
  OUT="$(env WSK_PORTABILITY_DENYLIST="$nodeny" "$@" /bin/bash "$checker" --dir "$dir" 2>&1)"
  RC=$?
  set -e
}

# The clean tree passes. The denylist is intentionally absent, as in CI.
run_checker "$pristine"
[ "$RC" = 0 ] || fail "clean tree rejected (rc=$RC): $OUT"
printf '%s\n' "$OUT" | grep -q '^PASS - ' || fail "no PASS line: $OUT"

# The remaining cases plant one violation at a time, so a small synthetic tree is enough
# (and keeps the suite fast); only the clean-tree assertion above needs the real kit.
mini="$fixture/mini"
mkdir -p "$mini/docs" "$mini/templates/client" "$mini/bin"
printf 'clean\n' > "$mini/docs/ok.md"
printf 'clean\n' > "$mini/templates/client/envrc"
printf 'clean\n' > "$mini/bin/watch.sh"
cp "$pristine/.portability-allow" "$mini/.portability-allow"
pristine="$mini"

# expect_fail <case> <label> <setup function>: apply to a fresh copy, expect rc=1 + label.
expect_fail() {
  local name="$1" label="$2" setup="$3" dir="$fixture/case-$1"
  cp -R "$pristine" "$dir"
  "$setup" "$dir"
  run_checker "$dir" "${EXTRA_ENV:-WSK_UNUSED=1}"
  [ "$RC" = 1 ] || fail "$name: expected rc=1, got $RC: $OUT"
  printf '%s\n' "$OUT" | grep -q "^FAIL: $label: " || fail "$name: missing label $label: $OUT"
}

# Violation strings are assembled at runtime so this file does not trigger the checker.
slash="/"
at="@"
plant_users() { printf 'see %sUsers%ssomeone%sproject\n' "$slash" "$slash" "$slash" >> "$1/docs/plant.md"; }
plant_home()  { printf 'see %shome%ssomeone%sproject\n' "$slash" "$slash" "$slash" >> "$1/docs/plant.md"; }
plant_email() { printf 'contact %s\n' "someone${at}realcompany.io" >> "$1/docs/plant.md"; }
plant_bak()   { printf 'x\n' > "$1/templates/client/envrc.bak.1"; }
plant_log()   { printf 'x\n' > "$1/docs/WORKSTATION-LOG.md"; }
plant_conf()  { printf 'x\n' > "$1/workstation-segregation.conf"; }
plant_claude(){ mkdir -p "$1/.claude"; printf 'x\n' > "$1/.claude/settings.json"; }

expect_fail users  ABS-HOME-PATH  plant_users
expect_fail home   ABS-HOME-PATH  plant_home
expect_fail email  EMAIL          plant_email
expect_fail bak    FORBIDDEN-FILE plant_bak
expect_fail log    FORBIDDEN-FILE plant_log
expect_fail conf   FORBIDDEN-FILE plant_conf
expect_fail claude FORBIDDEN-FILE plant_claude

# Reserved placeholder domains and fixture-style joins are accepted.
ok="$fixture/case-ok"
cp -R "$pristine" "$ok"
# shellcheck disable=SC2016  # the literal $base is the point of this case
printf 'a@example.invalid b@client.example c@example.com fixture=$base%shome%sx\n' "$slash" "$slash" >> "$ok/docs/plant.md"
run_checker "$ok"
[ "$RC" = 0 ] || fail "placeholders rejected: $OUT"

# An allowlist entry excuses exactly the matching line in the named file.
allow="$fixture/case-allow"
cp -R "$pristine" "$allow"
plant_users "$allow"
printf 'ABS-HOME-PATH:docs/plant.md:/someone$\n' >> "$allow/.portability-allow"
run_checker "$allow"
[ "$RC" = 0 ] || fail "allowlisted line rejected: $OUT"

# Denylist: content and path matches, case-insensitive; the list itself stays outside the tree.
deny="$fixture/denylist"
printf '# comment\nclientzed\n' > "$deny"
plant_deny_content() { printf 'Notes for ClientZed here\n' >> "$1/docs/plant.md"; }
plant_deny_path()    { printf 'x\n' > "$1/docs/clientzed-notes.md"; }
EXTRA_ENV="WSK_PORTABILITY_DENYLIST=$deny"
expect_fail deny-content DENYLIST plant_deny_content
expect_fail deny-path    DENYLIST plant_deny_path
EXTRA_ENV=""

# --require-denylist fails closed when the list is missing.
set +e
OUT="$(env WSK_PORTABILITY_DENYLIST="$nodeny" /bin/bash "$checker" --dir "$pristine" --require-denylist 2>&1)"
RC=$?
set -e
[ "$RC" = 2 ] || fail "--require-denylist: expected rc=2, got $RC: $OUT"

# --- additional detection forms ---------------------------------------------------------
plant_var_home() { printf 'see %svar%shome%ssomeone%sx\n' "$slash" "$slash" "$slash" "$slash" >> "$1/docs/plant.md"; }
plant_sysvol()   { printf 'see %sSystem%sVolumes%sData%sUsers%ssomeone\n' "$slash" "$slash" "$slash" "$slash" "$slash" >> "$1/docs/plant.md"; }
expect_fail var-home ABS-HOME-PATH plant_var_home
expect_fail sysvol   ABS-HOME-PATH plant_sysvol

# ssh remotes are not e-mail addresses; a real address next to one still is.
ssh="$fixture/case-ssh"
cp -R "$pristine" "$ssh"
printf 'clone git%sgithub.com:org/repo.git\n' "$at" >> "$ssh/docs/plant.md"
run_checker "$ssh"
[ "$RC" = 0 ] || fail "ssh remote flagged as e-mail: $OUT"
printf 'clone git%sgithub.com:org/repo.git or mail someone%srealcompany.io\n' "$at" "$at" >> "$ssh/docs/plant.md"
run_checker "$ssh"
[ "$RC" = 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL: EMAIL: ' || fail "address beside an ssh remote not reported: $OUT"

# A binary file (NUL byte) is scanned as text: a finding in it must not be hidden.
plant_binary() { printf 'x\0see %sUsers%ssomeone%sp\n' "$slash" "$slash" "$slash" > "$1/docs/blob.bin"; }
expect_fail binary ABS-HOME-PATH plant_binary

# File names with a tab, a newline, a pipe or a bracket must be scanned, not skipped.
for hostile in "$(printf 'tab\there.md')" "$(printf 'nl\nhere.md')" 'pipe|here.md' '[brack.md' "q'uote.md"; do
  hd="$fixture/case-hostile"
  rm -rf "$hd"; cp -R "$pristine" "$hd"
  printf 'see %sUsers%ssomeone%sp\n' "$slash" "$slash" "$slash" > "$hd/docs/$hostile"
  run_checker "$hd"
  [ "$RC" = 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL: ABS-HOME-PATH: ' || fail "hostile file name skipped (rc=$RC): $OUT"
done

# Same through git ls-files in tracked mode: temp repo with the checker and one hostile name.
repo="$fixture/gitrepo"
mkdir -p "$repo/scripts" "$repo/workstation-segregation/docs"
cp "$checker" "$repo/scripts/"
printf 'clean\n' > "$repo/workstation-segregation/docs/ok.md"
printf 'see %sUsers%ssomeone%sp\n' "$slash" "$slash" "$slash" > "$repo/workstation-segregation/docs/$(printf 'a\tb.md')"
git -C "$repo" init -q
git -C "$repo" add -A
set +e
OUT="$(env WSK_PORTABILITY_DENYLIST="$nodeny" /bin/bash "$repo/scripts/$(basename "$checker")" 2>&1)"
RC=$?
set -e
[ "$RC" = 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL: ABS-HOME-PATH: ' || fail "tracked-mode hostile file name skipped (rc=$RC): $OUT"

# An invalid denylist regex is a preflight error, not "no match".
badre="$fixture/bad-denylist"
printf '[unclosed\n' > "$badre"
set +e
OUT="$(env WSK_PORTABILITY_DENYLIST="$badre" /bin/bash "$checker" --dir "$pristine" 2>&1)"
RC=$?
set -e
[ "$RC" = 2 ] || fail "invalid denylist regex: expected rc=2, got $RC: $OUT"

# Allowlist scope: an entry excuses its label and matched value only, not the whole line.
scope="$fixture/case-scope"
cp -R "$pristine" "$scope"
printf 'ABS-HOME-PATH:docs/plant.md:%shome%slinuxbrew$\n' "$slash" "$slash" >> "$scope/.portability-allow"
printf 'brew %shome%slinuxbrew and mail someone%srealcompany.io\n' "$slash" "$slash" "$at" >> "$scope/docs/plant.md"
run_checker "$scope"
[ "$RC" = 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL: EMAIL: ' || fail "allowlisted path value hid an unrelated e-mail on the same line: $OUT"
! printf '%s\n' "$OUT" | grep -q '^FAIL: ABS-HOME-PATH: ' || fail "allowlisted value was still reported: $OUT"
# Same text for another label's entry must not excuse it.
other="$fixture/case-otherlabel"
cp -R "$pristine" "$other"
printf 'EMAIL:docs/plant.md:%shome%slinuxbrew$\n' "$slash" "$slash" >> "$other/.portability-allow"
printf 'brew %shome%slinuxbrew\n' "$slash" "$slash" >> "$other/docs/plant.md"
run_checker "$other"
[ "$RC" = 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL: ABS-HOME-PATH: ' || fail "entry for another label excused a finding: $OUT"

# Comment lines of the allowlist are scanned.
plant_allow_comment() { printf '# owner: someone%srealcompany.io\n' "$at" >> "$1/.portability-allow"; }
expect_fail allow-comment EMAIL plant_allow_comment

echo "portability.sh: all cases passed"
