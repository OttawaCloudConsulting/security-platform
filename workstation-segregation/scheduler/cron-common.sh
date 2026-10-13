#!/bin/bash
# Shared crontab editing for scheduler/{darwin,linux}.sh. Source only.
# shellcheck source=/dev/null
. "$KIT_ROOT/lib/common.sh"
KIT_CRON_TAG="# workstation-segregation watcher"

cron_line() {
  # The wrapper reports a macOS TCC denial (cron cannot even open watch.sh when the
  # kit lives under ~/Documents) instead of failing with a bare bash error.
  printf '*/%s * * * * /bin/bash -c '"'"'{ : < "%s/bin/watch.sh"; } 2>/dev/null || { echo "workstation-segregation: cannot read watch.sh - grant Full Disk Access to /usr/sbin/cron"; exit 1; }; exec /bin/bash "%s/bin/watch.sh" --config "%s"'"'"' >> "%s/cron.log" 2>&1 %s\n' \
    "$WATCH_INTERVAL_MIN" "$KIT_ROOT" "$KIT_ROOT" "$CONFIG_FILE" "$STATE_DIR" "$KIT_CRON_TAG"
}

cron_install() {
  local existing line
  command -v crontab >/dev/null 2>&1 || die "crontab not found"
  line="$(cron_line)"
  existing="$(crontab -l 2>/dev/null | grep -vF "$KIT_CRON_TAG" || true)"
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: install crontab entry: $line"
    return 0
  fi
  mkdir -p "$STATE_DIR"
  { [ -n "$existing" ] && printf '%s\n' "$existing"; printf '%s\n' "$line"; } | crontab -
  log "installed crontab entry (every $WATCH_INTERVAL_MIN min)"
}

cron_remove() {
  local existing
  command -v crontab >/dev/null 2>&1 || return 0
  crontab -l 2>/dev/null | grep -qF "$KIT_CRON_TAG" || return 0
  existing="$(crontab -l 2>/dev/null | grep -vF "$KIT_CRON_TAG" || true)"
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: remove workstation-segregation crontab entry"
    return 0
  fi
  if [ -n "$existing" ]; then printf '%s\n' "$existing" | crontab -; else crontab -r; fi
  log "removed crontab entry"
}
