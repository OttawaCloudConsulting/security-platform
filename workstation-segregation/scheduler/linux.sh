#!/bin/bash
# Linux scheduler: user crontab. Usage: linux.sh install|remove
set -Eeuo pipefail
: "${KIT_ROOT:?}"
# shellcheck source=/dev/null
. "$KIT_ROOT/scheduler/cron-common.sh"

case "${1:-}" in
  install)
    cron_install
    if [ "$DRY_RUN" != 1 ] && ! pgrep -x cron >/dev/null 2>&1 && ! pgrep -x crond >/dev/null 2>&1; then
      warn "cron daemon does not appear to be running; start it: sudo systemctl enable --now cron"
    fi
    ;;
  remove) cron_remove ;;
  *) echo "usage: linux.sh install|remove" >&2; exit 2 ;;
esac
