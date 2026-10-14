#!/bin/bash
# Engine entry (Bash 5). Invoked by setup-workstation.sh with the orchestrator
# environment: WST_ROOT WST_PROJECT_DIR WST_JQ WST_OS WST_ARCH WST_LOCK DRY_RUN ASSUME_YES.
set -Eeuo pipefail
if [ "${BASH_VERSINFO[0]}" -lt 5 ]; then
  echo "main.sh requires Bash 5 (got $BASH_VERSION)" >&2; exit 1
fi
: "${WST_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
export WST_ROOT
D="$WST_ROOT/scripts/common"
# shellcheck source=/dev/null
for f in common catalog groups configuration versions download state plan engine; do . "$D/$f.sh"; done

main() {
  local e
  config_parse_args "$@"
  # the managed binary directory must be visible to probes and bundled-command checks
  case ":$PATH:" in *":$(bin_dir):"*) ;; *) PATH="$(bin_dir):$PATH"; export PATH ;; esac
  [ -n "${WST_OS:-}" ] || wst_detect_os
  [ -n "${WST_ARCH:-}" ] || wst_detect_arch
  export WST_OS WST_ARCH
  # A dry-run changes nothing, so it needs no lock (and creates no state dir).
  [ "$DRY_RUN" = 1 ] || wst_lock_adopt_or_acquire
  catalog_load
  config_select_groups
  state_init
  inst_valid || die "installed file is not valid: $INSTALLED_FILE"
  req_load || true
  req_apply || true
  removal_check_static
  if [ ${#REQ_ERRORS[@]} -gt 0 ] || [ ${#PLAN_ERRORS[@]} -gt 0 ]; then
    for e in "${REQ_ERRORS[@]}" "${PLAN_ERRORS[@]}"; do warn "$e"; done
    die "request rejected; nothing was changed"
  fi
  removal_reduced_groups
  req_write
  load_handlers
  plan_build
  plan_print
  if [ ${#PLAN_ERRORS[@]} -gt 0 ]; then
    for e in "${PLAN_ERRORS[@]}"; do warn "$e"; done
    die "removal request rejected; nothing was changed"
  fi
  if [ "$DRY_RUN" = 1 ]; then
    log "dry-run: no changes made"
    exit 0
  fi
  if has_removals; then
    wst_confirm "Remove the tools marked 'remove' above?" || die "removal not confirmed"
  fi
  run_removals
  run_installs
  report
  [ "$FAILED_COUNT" -eq 0 ]
}

main "$@"
