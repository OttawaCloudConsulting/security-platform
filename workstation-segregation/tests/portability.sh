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
( cd "$kit" && git ls-files ) | while IFS= read -r f; do
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
printf 'docs/plant.md:someone\n' >> "$allow/.portability-allow"
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

echo "portability.sh: all cases passed"
