# Known issues

Problems seen while running workstation-segregation, with cause, workaround and status.
Add new entries at the top.

## Agent sandbox cannot approve the live client environments (2026-10-13)

**Symptom:** `direnv allow` from the agent failed with `operation not permitted`
while writing under `~/.local/share/direnv/allow/`.

**Cause:** that approval store is outside the agent's writable filesystem roots.
Client configuration can be updated from the agent, but the live approval step
cannot be completed from that process.

**Workaround:** run `direnv allow` in each existing client directory as your normal
user. Then open a new terminal to load the Codex wrappers and perform a fresh
client-specific login.

**Status:** an execution-environment limitation. Deploy's adoption behavior
intentionally leaves existing `.envrc` files unapproved.
