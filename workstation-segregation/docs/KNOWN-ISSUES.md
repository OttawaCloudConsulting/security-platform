# Known issues

Problems seen while running workstation-segregation, with cause, workaround and status.
Planned fixes are in [BACKLOG.md](BACKLOG.md). Add new entries at the top.

## GitHub CLI tokens are stored in the shared OS keyring

**Symptom:** in a client with no gh login, `gh auth git-credential get` can return a token from
the shared keyring, so Git over HTTPS to github.com authenticates as another account. With gh's
default secure storage every client's token lives in the same login keyring (the macOS Keychain),
and an unconfigured client may authenticate gh, and Git via `gh auth git-credential`, as the
account most recently activated in another client.

**Cause:** `GH_CONFIG_DIR` separates only `hosts.yml`. gh stores tokens under the keyring service
`gh:<host>` keyed by GitHub username, copies the active account's token into an unkeyed
`gh:<host>` entry shared by all clients, and falls back to that entry when the current config has
no token for its active user (`cli/cli` `internal/config/config.go`: `ActiveToken`,
`setActiveCredential`, `TokenFromKeyring`; checked against gh 2.103.3). The global gh login
(`~/.config/gh`) writes the same unkeyed slot, so the fallback account is whichever
secure-storage login was activated last anywhere on the machine.

**Mitigation in the kit:** the client Git helper (`templates/client/git-config`) hands Git nothing
unless the client's `hosts.yml` exists and is non-empty, and drops inherited
`GH_TOKEN`/`GITHUB_TOKEN`/`GH_ENTERPRISE_TOKEN`/`GITHUB_ENTERPRISE_TOKEN` for the gh call, because
Git can run the helper outside direnv (an IDE, or `git -C <client-repo>` from another shell).
`.envrc` unsets the same variables and `GH_HOST`; an inherited `GH_HOST` would let ordinary gh
commands pass gh's empty-config auth gate and reach the fallback too. Clients scaffolded before
this change keep their old helper line until migrated by hand.

**Not closed:** a client whose `hosts.yml` names a user without a token of its own still reaches
the fallback, and `gh auth token` in an unconfigured client returns the shared token. Only moving
every gh login to `--insecure-storage` and removing the `gh:*` keyring entries closes it; see
[BACKLOG.md](BACKLOG.md#p1-1-github-credentials-come-only-from-the-client).

**Check** (as your normal user; prints the account name only, never the token):

```bash
printf 'protocol=https\nhost=github.com\n\n' \
  | env -u GH_TOKEN -u GITHUB_TOKEN GH_CONFIG_DIR="$(mktemp -d)" gh auth git-credential get \
  | sed -n 's/^password=//p' | { read -r t; GH_TOKEN="$t" gh api user --jq .login; }
```

If it prints a login, the fallback is live. `gh api user` alone is not a valid test: gh's auth
gate stops it before any token lookup when `hosts.yml` is empty.

## Docker and Helm registry logins go to the shared OS credential store

**Symptom:** none until someone logs in. `docker login` or `helm registry login` inside a client
stores the credential in the shared login keyring (the macOS Keychain), readable from every
client, and a second client logging in to the same registry overwrites the first.

**Cause:** `templates/client/docker-config.json` sets no `credsStore` and no `auths`. When a
config contains no auth settings, the Docker CLI calls `credentials.DetectDefaultStore`
(`docker/cli` `cli/config/config.go`, `LoadDefaultConfigFile`), which selects `osxkeychain` if
`docker-credential-osxkeychain` is on `PATH`. Helm 4 does the same for its per-client
`registry/config.json` (oras-go `DetectDefaultNativeStore`) and falls back to the Docker store.
An inherited `DOCKER_AUTH_CONFIG` also outranks the config file.

**Workaround:** do not run `docker login` or `helm registry login` inside a client until fixed.
**Status:** open. Planned fix: [BACKLOG.md](BACKLOG.md#p0-1-keep-registry-logins-in-the-client-docker-and-helm).

## Claude hook re-export does not restore the pre-client environment

**Symptom:** a Claude session started in one client can keep that client's variables
(`KUBECONFIG`, `GH_CONFIG_DIR`, `BROWSER`, shim `PATH` entry) if it later works elsewhere.

**Cause:** `hooks/direnv-session-env.sh` drops `DIRENV_DIFF` and re-exports the client
environment at SessionStart; direnv then has no baseline to unload.

**Workaround:** start Claude sessions per client. Browser launches additionally refuse to run
outside the client directory tree, so a stale `BROWSER` cannot open another client's profile.

**Status:** open; affects every client variable, not only browsers. Planned fix:
[BACKLOG.md](BACKLOG.md#p0-2-claude-session-hook-must-restore-the-pre-client-environment).

## Agent sandbox cannot approve the live client environments

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
