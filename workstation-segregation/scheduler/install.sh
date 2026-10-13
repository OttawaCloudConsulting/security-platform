#!/bin/bash
# Scheduler entry point: dispatch on OS. Usage: install.sh install|remove
# Expects KIT_ROOT, CONFIG_FILE, STATE_DIR, CLIENT_ROOT, WATCH_INTERVAL_MIN, DRY_RUN exported.
set -Eeuo pipefail
: "${KIT_ROOT:?}"
# shellcheck source=/dev/null
. "$KIT_ROOT/lib/common.sh"
case "$(uname -s)" in
  Darwin) exec /bin/bash "$KIT_ROOT/scheduler/darwin.sh" "$@" ;;
  Linux)  exec /bin/bash "$KIT_ROOT/scheduler/linux.sh" "$@" ;;
  *) die "unsupported OS: $(uname -s)" ;;
esac
