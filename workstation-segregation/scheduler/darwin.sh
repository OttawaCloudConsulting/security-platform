#!/bin/bash
# macOS scheduler: user crontab + Full Disk Access guidance. Usage: darwin.sh install|remove
set -Eeuo pipefail
: "${KIT_ROOT:?}"
# shellcheck source=/dev/null
. "$KIT_ROOT/scheduler/cron-common.sh"

case "${1:-}" in
  install)
    cron_install
    cat <<MSG
[segregation] macOS one-time step: cron cannot read $CLIENT_ROOT (if under ~/Documents,
      ~/Desktop, ~/Downloads) until it has Full Disk Access:
        System Settings > Privacy & Security > Full Disk Access > "+" ,
        press Cmd-Shift-G, enter /usr/sbin/cron, add it and enable the toggle.
      The watcher logs this same instruction if it is blocked.
      Alternative: set CLIENT_ROOT outside the protected folders (e.g. ~/clients).
MSG
    ;;
  remove) cron_remove ;;
  *) echo "usage: darwin.sh install|remove" >&2; exit 2 ;;
esac
