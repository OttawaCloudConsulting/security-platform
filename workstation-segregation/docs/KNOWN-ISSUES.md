# Known issues

Problems seen while running workstation-segregation, with cause, workaround and status.
Add new entries at the top.

## Agent sandbox cannot approve the live client environments (2026-10-13)

**Symptom:** `direnv allow` from the agent failed with `operation not permitted`
while writing under `~/.local/share/direnv/allow/`.

**Cause:** that approval store is outside the agent's writable filesystem roots.
Client configuration under `~/Documents` was updated successfully, but the live
approval step could not be completed from that process.

**Workaround:** run `~/Documents/temp-update-configs.sh` as your normal user, or
run `direnv allow` in each of `mlse`, `occ` and `zonal`. Then open a new terminal
to load the Codex wrappers and perform a fresh client-specific login.

**Status:** client configuration and temporary-store environment checks are
complete. Approval in the normal user store and client logins were not confirmed
during the migration. This is an execution-environment limitation; deploy's
adoption behavior intentionally leaves existing `.envrc` files unapproved.
