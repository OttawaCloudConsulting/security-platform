#!/bin/bash
# Fake platform handlers driven by $FAKE_WORLD:
#   $FAKE_WORLD/latest/<id>      latest version, or the word FAIL
#   $FAKE_WORLD/installed/<id>   probe lines: version<TAB>path<TAB>source<TAB>package_id ('-' = empty)
#   $FAKE_WORLD/failinstall/<id> install exits 1 when present
#   $FAKE_WORLD/badvalidate/<id> validate fails when present
#   $FAKE_WORLD/kind/<id>        kind override (os)
#   $FAKE_WORLD/integrity/<id>   integrity status install reports (default verified/package-manager)
#   $FAKE_WORLD/wrongversion/<id> install writes this version instead of the target
#   $FAKE_WORLD/noremove/<id>    remove does nothing (partial removal)
# Every call is appended to $WST_TRACE_FILE by the engine (latest/probe/install/remove).
[ -n "${_FAKE_LOADED:-}" ] && return 0
_FAKE_LOADED=1
for _id in $(cut -f1 "$WST_CATALOG_DIR/tools.tsv" | grep -v '^#'); do
  _fn="${_id//-/_}"
  [ -f "$FAKE_WORLD/nohandler/$_id" ] && continue
  # bundled commands follow the provider unless a test gives them handlers
  if [ "$(awk -F'\t' -v i="$_id" '$1==i{print $5}' "$WST_CATALOG_DIR/tools.tsv")" = bundled ] \
     && [ ! -f "$FAKE_WORLD/ownhandlers/$_id" ]; then
    eval "tool_${_fn}_validate() { return 0; }"
    continue
  fi
  eval "
tool_${_fn}_latest() { [ -z \"\${FAKE_SLEEP:-}\" ] || sleep \"\$FAKE_SLEEP\"; v=\$(cat \"\$FAKE_WORLD/latest/$_id\" 2>/dev/null) || return 1; [ \"\$v\" != FAIL ] || return 1; echo \"\$v\"; }
tool_${_fn}_kind() { cat \"\$FAKE_WORLD/kind/$_id\" 2>/dev/null || echo bin; }
tool_${_fn}_source() { echo release; }
tool_${_fn}_probe() { cat \"\$FAKE_WORLD/installed/$_id\" 2>/dev/null || true; }
tool_${_fn}_install() {
  [ ! -f \"\$FAKE_WORLD/failinstall/$_id\" ] || return 1
  mkdir -p \"\$FAKE_WORLD/installed\"
  printf '%s\t%s\t%s\t%s\n' \"\$(cat \"\$FAKE_WORLD/wrongversion/$_id\" 2>/dev/null || echo \"\$1\")\" \"\$FAKE_BIN/$_id\" release - > \"\$FAKE_WORLD/installed/$_id\"
  printf 'integrity=%s\n' \"\$(cat \"\$FAKE_WORLD/integrity/$_id\" 2>/dev/null || echo verified)\" > \"\$2\"
}
tool_${_fn}_remove() {
  [ ! -f \"\$FAKE_WORLD/noremove/$_id\" ] || return 0
  rm -f \"\$FAKE_WORLD/installed/$_id\"
}
tool_${_fn}_validate() { [ ! -f \"\$FAKE_WORLD/badvalidate/$_id\" ]; }
"
done
