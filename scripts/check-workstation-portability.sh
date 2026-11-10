#!/usr/bin/env bash
set -Eeuo pipefail

# check-workstation-portability.sh - keep workstation-segregation/ free of
# client, project and machine-specific content so the kit deploys unchanged on
# a new workstation.
#
# Scans the tracked files of workstation-segregation/ (or a plain directory,
# see --dir) for:
#   ABS-HOME-PATH    absolute home paths with a literal user name
#                    (/Users/<name>, /home/<name>)
#   EMAIL            e-mail addresses other than reserved placeholder domains
#                    (example.com/.org/.net and the .example/.invalid/.test TLDs)
#   FORBIDDEN-FILE   tracked local state: *.bak.*, WORKSTATION-LOG.md,
#                    workstation-segregation.conf, anything under .claude/
#   DENYLIST         client/project/account names, read from an UNTRACKED
#                    local file (one extended regex per line, case-insensitive)
#
# The denylist is deliberately not in the repository: committing the list of
# names to keep out would leak them. Default location:
#   ${WSK_PORTABILITY_DENYLIST:-$HOME/.config/workstation-segregation/forbidden-names}
# When it is absent the DENYLIST check is skipped with a notice (CI), unless
# --require-denylist is given.
#
# Legitimate exceptions live in workstation-segregation/.portability-allow, one
# per line: <path relative to the kit>:<extended regex matched against the line>.
#
# Exit codes: 0 pass, 1 findings, 2 preflight error.
# Labels are stable; tests/portability.sh in the kit matches them literally.

usage() {
  cat <<'USAGE'
Usage: scripts/check-workstation-portability.sh [--dir DIR] [--require-denylist]

  --dir DIR           scan the files of DIR (a copy of the kit) instead of the
                      git-tracked files of workstation-segregation/
  --require-denylist  fail (exit 2) when the local denylist file is absent
  -h, --help          show this help
USAGE
}

KIT_NAME="workstation-segregation"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIR=""
REQUIRE_DENYLIST=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir)
      [ "$#" -ge 2 ] || { echo "ERROR: --dir needs a directory" >&2; exit 2; }
      DIR="$2"; shift ;;
    --require-denylist) REQUIRE_DENYLIST=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ -n "$DIR" ]; then
  [ -d "$DIR" ] || { echo "ERROR: not a directory: $DIR" >&2; exit 2; }
  BASE="$(cd "$DIR" && pwd)"
else
  BASE="$REPO_ROOT/$KIT_NAME"
  [ -d "$BASE" ] || { echo "ERROR: $BASE not found" >&2; exit 2; }
  command -v git >/dev/null 2>&1 || { echo "ERROR: git is required" >&2; exit 2; }
fi

DENYLIST="${WSK_PORTABILITY_DENYLIST:-$HOME/.config/workstation-segregation/forbidden-names}"
ALLOW_FILE="$BASE/.portability-allow"

FILES_LIST="$(mktemp "${TMPDIR:-/tmp}/wsk-portability.XXXXXX")"
trap 'rm -f "$FILES_LIST"' EXIT

# .portability-allow holds the exempted patterns by design, so it is not scanned itself.
if [ -n "$DIR" ]; then
  (cd "$BASE" && find . -type f ! -path './.git/*' | sed 's|^\./||' | LC_ALL=C sort) \
    | grep -vx '\.portability-allow' > "$FILES_LIST" || true
else
  (cd "$REPO_ROOT" && git ls-files -- "$KIT_NAME" | sed "s|^$KIT_NAME/||" | LC_ALL=C sort) \
    | grep -vx '\.portability-allow' > "$FILES_LIST" || true
fi

FAILURES=0
CHECKS=0

fail() { # fail <label> <message>
  echo "FAIL: $1: $2"
  FAILURES=$((FAILURES + 1))
}

# allowed <rel> <line text>: 0 when .portability-allow excuses this finding.
allowed() {
  local rel="$1" text="$2" entry path re
  [ -f "$ALLOW_FILE" ] || return 1
  while IFS= read -r entry || [ -n "$entry" ]; do
    case "$entry" in ''|'#'*) continue ;; esac
    path="${entry%%:*}"; re="${entry#*:}"
    [ "$path" = "$rel" ] || continue
    if printf '%s\n' "$text" | grep -Eq -- "$re"; then return 0; fi
  done < "$ALLOW_FILE"
  return 1
}

# scan_lines <label> <ere> [grep flags]: report every matching line of every file.
scan_lines() {
  local label="$1" ere="$2" flags="${3:-}" rel hit n text
  while IFS= read -r rel; do
    [ -f "$BASE/$rel" ] || continue
    # shellcheck disable=SC2086
    while IFS= read -r hit; do
      n="${hit%%:*}"; text="${hit#*:}"
      allowed "$rel" "$text" && continue
      fail "$label" "$rel:$n: $text"
    done < <(grep -InE $flags -e "$ere" -- "$BASE/$rel" 2>/dev/null | sed "s|^$BASE/$rel:||" || true)
  done < "$FILES_LIST"
}

# ---- 1. ABS-HOME-PATH ---------------------------------------------------------
CHECKS=$((CHECKS + 1))
# The leading class excludes path joins such as "$fixture/home/state".
scan_lines ABS-HOME-PATH '(^|[^A-Za-z0-9_./})-])(/Users|/home)/[A-Za-z0-9._-]+'

# ---- 2. EMAIL -----------------------------------------------------------------
CHECKS=$((CHECKS + 1))
while IFS= read -r rel; do
  [ -f "$BASE/$rel" ] || continue
  while IFS= read -r hit; do
    n="${hit%%:*}"; text="${hit#*:}"
    mails="$(printf '%s\n' "$text" | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
      | grep -vEi '@([A-Za-z0-9-]+\.)*(example|invalid|test)$|@example\.(com|org|net)$' || true)"
    [ -n "$mails" ] || continue
    allowed "$rel" "$text" && continue
    fail EMAIL "$rel:$n: $text"
  done < <(grep -InE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -- "$BASE/$rel" 2>/dev/null | sed "s|^$BASE/$rel:||" || true)
done < "$FILES_LIST"

# ---- 3. FORBIDDEN-FILE --------------------------------------------------------
CHECKS=$((CHECKS + 1))
while IFS= read -r rel; do
  base="${rel##*/}"
  case "$base" in
    *.bak.*|WORKSTATION-LOG.md|workstation-segregation.conf) fail FORBIDDEN-FILE "$rel" ;;
    *) case "/$rel" in */.claude/*) fail FORBIDDEN-FILE "$rel" ;; esac ;;
  esac
done < "$FILES_LIST"

# ---- 4. DENYLIST --------------------------------------------------------------
if [ -f "$DENYLIST" ]; then
  CHECKS=$((CHECKS + 1))
  while IFS= read -r term || [ -n "$term" ]; do
    case "$term" in ''|'#'*) continue ;; esac
    scan_lines DENYLIST "$term" -i
    while IFS= read -r rel; do
      if printf '%s\n' "$rel" | grep -Eiq -- "$term"; then fail DENYLIST "path: $rel"; fi
    done < "$FILES_LIST"
  done < "$DENYLIST"
elif [ "$REQUIRE_DENYLIST" = 1 ]; then
  echo "ERROR: denylist not found: $DENYLIST" >&2
  exit 2
else
  echo "NOTE: denylist not found ($DENYLIST); client-name check skipped"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL - $CHECKS checks, $FAILURES failures"
  exit 1
fi
echo "PASS - $CHECKS checks, 0 failures"
