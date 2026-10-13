#!/usr/bin/env bash
# Claude Code SessionStart hook: re-export the client's direnv environment into
# the Bash tool via CLAUDE_ENV_FILE. Experimental workaround for
# CLAUDE_CODE_SUBPROCESS_ENV_SCRUB stripping GH_CONFIG_DIR, KUBECONFIG, etc.
# See docs/client-segregation.md, "Known issues".
set -u

[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0
command -v direnv >/dev/null 2>&1 || exit 0
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0

# The scrub keeps DIRENV_* but strips the client variables, so direnv believes
# the env is already loaded and exports nothing. Drop its state to force a
# fresh load. No .envrc (or not allowed) means empty output.
env -u DIRENV_DIR -u DIRENV_FILE -u DIRENV_DIFF -u DIRENV_WATCHES \
  DIRENV_LOG_FORMAT= direnv export bash >>"$CLAUDE_ENV_FILE" 2>/dev/null

exit 0
