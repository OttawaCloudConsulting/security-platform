#!/bin/bash
# The catalog TSVs must match TOOL-GROUPS-CONSOLIDATED.md (groups, members, deps).
. "$(dirname "$0")/helpers.sh"
DOC="$TOOLS_DIR/TOOL-GROUPS-CONSOLIDATED.md"
CAT="$TOOLS_DIR/scripts/common/catalog"
T="$(mktemp -d "${TMPDIR:-/tmp}/wst-sync.XXXXXX")"; trap 'rm -rf "$T"' EXIT

groups="$(grep -v '^#' "$CAT/groups.tsv" | cut -f1)"
for g in $groups; do
  # doc members
  awk -v g="$g" '
    /^## /{ cur=$2; next }
    cur==g && /^- /{ s=substr($0,3); sub(/: .*/,"",s); print s }
  ' "$DOC" | LC_ALL=C sort -u > "$T/doc.$g"
  # catalog members: tools whose groups column lists g
  awk -F'\t' -v g="$g" '!/^#/{ n=split($3,a,","); for(i=1;i<=n;i++) if(a[i]==g) print $2 }' "$CAT/tools.tsv" | LC_ALL=C sort -u > "$T/cat.$g"
  if cmp -s "$T/doc.$g" "$T/cat.$g"; then ok; else fail "group $g members differ from the doc"; diff "$T/doc.$g" "$T/cat.$g" >&2 || true; fi
  # dependencies
  docdeps="$(awk -v g="$g" '/^## /{cur=$2} cur==g && /^Additional group dependencies:/{ s=$0; sub(/^[^:]*: */,"",s); gsub(/`/,"",s); sub(/\..*/,"",s); gsub(/, */," ",s); if (s=="none") s=""; print s; exit }' "$DOC")"
  catdeps="$(awk -F'\t' -v g="$g" '!/^#/ && $1==g { d=$2; if (d=="-") d=""; gsub(/,/," ",d); print d }' "$CAT/groups.tsv")"
  assert_eq "$catdeps" "$docdeps" "group $g dependencies"
done

# every group heading in the doc is in the catalog
grep '^## ' "$DOC" | sed 's/^## //' > "$T/headings"
while IFS= read -r g; do
  case "$g" in "Orchestrator prerequisites"|"Tool dependencies"|"Selection rules"|"Configuration examples"|"Machine-readable catalog") continue ;; esac
  echo "$groups" | grep -qx "$g" && ok || fail "doc group '$g' missing from groups.tsv"
done < "$T/headings"

# tool-level dependency table: every row's tools exist with the matching relation
awk -F'|' '/^\| [A-Za-z]/ && !/Tool \|/ && !/---/{ gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$3); gsub(/^ +| +$/,"",$4); print $2 "\t" $3 "\t" $4 }' "$DOC" > "$T/deps"
while IFS=$'\t' read -r tools dep rel; do
  case "$tools" in Tool) continue ;; esac
  OLDIFS="$IFS"; IFS=','; set -- $tools; IFS="$OLDIFS"
  for name in "$@"; do
    name="$(echo "$name" | sed 's/^ *//;s/ *$//')"
    if awk -F'\t' -v n="$name" '!/^#/ && ($1==n || $2==n || index($2, n " (")==1) {f=1} END{exit !f}' "$CAT/tools.tsv"; then ok; else fail "dependency-table tool '$name' not in tools.tsv"; fi
  done
done < "$T/deps"

# catalog invariants
awk -F'\t' '!/^#/ && $6!="never" && $6!="base" && $6!="normal" {print "bad removal class: " $1}' "$CAT/tools.tsv" > "$T/bad"
[ ! -s "$T/bad" ] && ok || fail "$(cat "$T/bad")"
for id in jq yq direnv starship ca-certificates curl tar gzip unzip git; do
  assert_eq "$(awk -F'\t' -v i="$id" '$1==i{print $6}' "$CAT/tools.tsv")" never "$id is never-removable"
done
finish
