#!/usr/bin/env bash
set -Eeuo pipefail

# check-workstation-portability.sh - keep workstation-segregation/ free of
# client, project and machine-specific content so the kit deploys unchanged on
# a new workstation.
#
# Scans the tracked files of workstation-segregation/ (or a plain directory,
# see --dir). Binary files are scanned as text (grep -a), so a NUL byte cannot
# hide a finding. Labels reported:
#
#   ABS-HOME-PATH    absolute home paths with a literal user name: /Users/<n>,
#                    /home/<n>, /var/home/<n>, /System/Volumes/Data/Users/<n>.
#                    Path joins such as "$fixture/home/state" are not matched
#                    (the path must not continue a longer path or variable).
#                    /root is not flagged: it names no person.
#   EMAIL            e-mail addresses other than reserved placeholder domains
#                    (example.com/.org/.net and the .example/.invalid/.test
#                    TLDs). ssh remotes (git@host:path) are not e-mail.
#                    Quoted local parts ("a b"@host) are not detected.
#   FORBIDDEN-FILE   tracked local state: *.bak.*, WORKSTATION-LOG.md,
#                    workstation-segregation.conf, anything under .claude/
#   DENYLIST         client/project/account names, from an UNTRACKED local
#                    file: one extended regex per line, case-insensitive,
#                    matched against file contents and file paths.
#
# The denylist is deliberately not in the repository: committing the list of
# names to keep out would leak them. Default location:
#   ${WSK_PORTABILITY_DENYLIST:-$HOME/.config/workstation-segregation/forbidden-names}
# When it is absent the DENYLIST check is skipped with a notice (CI), unless
# --require-denylist is given. An invalid regex in it is a preflight error.
#
# Exceptions live in workstation-segregation/.portability-allow, one per line:
#   <LABEL>:<path relative to the kit>:<extended regex>
# An exception only excuses a finding with that label, in that file, whose
# matched value (not the whole line) matches the regex; anything else on the
# same line is still reported. Comment lines of the file are scanned too.
#
# Exit codes: 0 pass, 1 findings, 2 preflight or scan error.
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
ALLOW_NAME=".portability-allow"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/wsk-portability.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
FILES_LIST="$WORK/files"

# NUL-delimited, so file names with tabs, newlines or quotes survive intact.
if [ -n "$DIR" ]; then
  (cd "$BASE" && find . -type f ! -path './.git/*' -print0) > "$FILES_LIST"
else
  (cd "$REPO_ROOT" && git ls-files -z -- "$KIT_NAME") > "$FILES_LIST"
fi

rel_of() { # rel_of <list entry> -> path relative to the kit
  if [ -n "$DIR" ]; then printf '%s' "${1#./}"; else printf '%s' "${1#"$KIT_NAME"/}"; fi
}

# ---- denylist: load and validate ----------------------------------------------------
DENY_RE=""   # all terms as one alternation: one grep per file instead of one per term
if [ -f "$DENYLIST" ]; then
  while IFS= read -r term || [ -n "$term" ]; do
    case "$term" in ''|'#'*) continue ;; esac
    rc=0; grep -E -e "$term" /dev/null >/dev/null 2>&1 || rc=$?
    if [ "$rc" -gt 1 ]; then
      echo "ERROR: invalid extended regex in $DENYLIST: $term" >&2
      exit 2
    fi
    DENY_RE="${DENY_RE:+$DENY_RE|}($term)"
  done < "$DENYLIST"
elif [ "$REQUIRE_DENYLIST" = 1 ]; then
  echo "ERROR: denylist not found: $DENYLIST" >&2
  exit 2
else
  echo "NOTE: denylist not found ($DENYLIST); client-name check skipped"
fi

FAILURES=0

fail() { # fail <label> <message>
  echo "FAIL: $1: $2"
  FAILURES=$((FAILURES + 1))
}

# allowed <label> <rel> <matched value>: 0 when .portability-allow excuses it.
allowed() {
  local label="$1" rel="$2" value="$3" entry elabel rest epath re
  [ -f "$ALLOW_FILE" ] || return 1
  while IFS= read -r entry || [ -n "$entry" ]; do
    case "$entry" in ''|'#'*) continue ;; esac
    elabel="${entry%%:*}"; rest="${entry#*:}"
    epath="${rest%%:*}"; re="${rest#*:}"
    [ "$elabel" = "$label" ] && [ "$epath" = "$rel" ] || continue
    if printf '%s\n' "$value" | grep -Eq -- "$re"; then return 0; fi
  done < "$ALLOW_FILE"
  return 1
}

# matches <ere> [grep flag]: reads stdin, prints each matched value, one per line.
matches() { grep -aoE ${2:+"$2"} -e "$1" 2>/dev/null || true; }

# scan_content <label> <disk path> <display rel> <ere> [grep flag]
# Reports each line with a match unless every matched value on it is excused.
scan_content() {
  local label="$1" disk="$2" rel="$3" ere="$4" flag="${5:-}" out rc line n text v bad
  rc=0
  out="$(grep -naE ${flag:+"$flag"} -e "$ere" -- "$disk" 2>/dev/null)" || rc=$?
  case "$rc" in
    0) ;;
    1) return 0 ;;
    *) echo "ERROR: grep failed (status $rc) scanning $rel for $label" >&2; exit 2 ;;
  esac
  while IFS= read -r line; do
    n="${line%%:*}"; text="${line#*:}"
    bad=0
    while IFS= read -r v; do
      [ -n "$v" ] || continue
      allowed "$label" "$rel" "$v" || { bad=1; break; }
    done <<EOV
$(printf '%s\n' "$text" | matches "$ere" "$flag")
EOV
    if [ "$bad" = 1 ]; then fail "$label" "$rel:$n: $text"; fi
  done <<EOL
$out
EOL
  return 0
}

HOME_RE='(^|[^A-Za-z0-9_./})-])(/Users|/home|/var/home|/System/Volumes/Data/Users)/[A-Za-z0-9._-]+'
MAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
PLACEHOLDER_RE='@([A-Za-z0-9-]+\.)*(example|invalid|test)$|@example\.(com|org|net)$'

scan_email() { # scan_email <disk> <rel>
  local disk="$1" rel="$2" out rc line n text mails m bad
  rc=0
  out="$(grep -naE -e "$MAIL_RE" -- "$disk" 2>/dev/null)" || rc=$?
  case "$rc" in
    0) ;;
    1) return 0 ;;
    *) echo "ERROR: grep failed (status $rc) scanning $rel for EMAIL" >&2; exit 2 ;;
  esac
  while IFS= read -r line; do
    n="${line%%:*}"; text="${line#*:}"
    # Candidate addresses on the line, minus ssh remotes (git@host:path) and placeholders.
    mails="$(printf '%s\n' "$text" | matches "${MAIL_RE}:?" \
      | { grep -vE '^git@[^:]*:$' || true; } | sed 's/:$//' | { grep -vEi -e "$PLACEHOLDER_RE" || true; })"
    [ -n "$mails" ] || continue
    bad=0
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      allowed EMAIL "$rel" "$m" || { bad=1; break; }
    done <<EOM
$mails
EOM
    if [ "$bad" = 1 ]; then fail EMAIL "$rel:$n: $text"; fi
  done <<EOL
$out
EOL
  return 0
}

scan_all() { # scan_all <disk path> <rel>
  local disk="$1" rel="$2"
  scan_content ABS-HOME-PATH "$disk" "$rel" "$HOME_RE"
  scan_email "$disk" "$rel"
  if [ -n "$DENY_RE" ]; then scan_content DENYLIST "$disk" "$rel" "$DENY_RE" -i; fi
}

# ---- scan every file ----------------------------------------------------------------
while IFS= read -r -d '' entry; do
  rel="$(rel_of "$entry")"
  [ "$rel" = "$ALLOW_NAME" ] && continue          # its comment lines are scanned below
  if [ -n "$DIR" ]; then disk="$BASE/$rel"; else disk="$REPO_ROOT/$entry"; fi
  [ -f "$disk" ] || continue

  base="${rel##*/}"
  case "$base" in
    *.bak.*|WORKSTATION-LOG.md|workstation-segregation.conf) fail FORBIDDEN-FILE "$rel" ;;
    *) case "/$rel" in */.claude/*) fail FORBIDDEN-FILE "$rel" ;; esac ;;
  esac
  if [ -n "$DENY_RE" ] && printf '%s\n' "$rel" | grep -Eiq -e "$DENY_RE"; then fail DENYLIST "path: $rel"; fi
  scan_all "$disk" "$rel"
done < "$FILES_LIST"

# The allowlist holds exempted patterns by design, but its comments must stay clean.
if [ -f "$ALLOW_FILE" ]; then
  grep -a '^#' "$ALLOW_FILE" > "$WORK/allow-comments" 2>/dev/null || true
  scan_all "$WORK/allow-comments" "$ALLOW_NAME (comments)"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL - $FAILURES findings"
  exit 1
fi
echo "PASS - no findings"
