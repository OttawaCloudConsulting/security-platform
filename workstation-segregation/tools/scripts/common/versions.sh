#!/bin/bash
# Version helpers. Comparison depends on the source: dpkg for apt, string
# equality for brew, sort -V for release binaries.

_curl() { curl -fsSL --retry 3 --connect-timeout 15 "$@"; }

# gh_latest_tag owner/repo -> tag name via the /releases/latest redirect.
gh_latest_tag() {
  local url
  url="$(_curl -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")" || return 1
  printf '%s\n' "${url##*/}"
}

# ver_normalize <raw> [prefix...]: strip a leading v and any given prefixes.
ver_normalize() {
  local v="$1" p
  shift
  for p in "$@"; do v="${v#"$p"}"; done
  v="${v#v}"
  printf '%s\n' "$v"
}

# ver_cmp <source> <a> <b>: prints lt, eq or gt.
ver_cmp() {
  local src="$1" a="$2" b="$3"
  [ "$a" = "$b" ] && { echo eq; return 0; }
  case "$src" in
    brew|os) echo ne; return 0 ;;
    apt)
      if command -v dpkg >/dev/null 2>&1; then
        if dpkg --compare-versions "$a" lt "$b"; then echo lt; else echo gt; fi
        return 0
      fi ;;
  esac
  if [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n1)" = "$a" ]; then echo lt; else echo gt; fi
}

# ver_matches <source> <observed> <target>: does the observed version satisfy
# the target? apt accepts a target without the package revision.
ver_matches() {
  local src="$1" obs="$2" tgt="$3"
  [ "$obs" = "$tgt" ] && return 0
  if [ "$src" = apt ]; then
    case "$obs" in "$tgt"-*|"$tgt"+*|*:"$tgt"|*:"$tgt"-*) return 0 ;; esac
  fi
  return 1
}

# ver_valid_syntax <value>: an exact pin must look like a version.
ver_valid_syntax() {
  case "$1" in
    ''|*[!0-9A-Za-z._+~:-]*) return 1 ;;
  esac
  case "$1" in [0-9A-Za-z]*) return 0 ;; *) return 1 ;; esac
}
