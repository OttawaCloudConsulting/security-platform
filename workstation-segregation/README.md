# workstation-segregation

Portable client segregation for a macOS or Ubuntu/Debian workstation. Each client gets its own
directory under one root; entering it (via direnv) switches cloud, cluster, Git, registry, SSH,
agent-CLI and shell-history state to that client's.

Full documentation: [docs/USER-GUIDE.md](docs/USER-GUIDE.md) (operating it) and [docs/DEVELOPER-GUIDE.md](docs/DEVELOPER-GUIDE.md) (changing it). Open problems: [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md). Open work: [docs/BACKLOG.md](docs/BACKLOG.md).

AGY integration is implemented but disabled pending a real two-account acceptance
test. Run `./tests/agy-account-isolation.sh --state-dir /absolute/new/path` for
the operator-run one-account persistence check. See [probe instructions and findings](docs/AGY-LOGIN-ISOLATION.md).

## Quick start

```bash
cd workstation-segregation
./deploy.sh                # first run copies workstation-segregation.conf.example -> workstation-segregation.conf and exits
$EDITOR workstation-segregation.conf   # at least review CLIENT_ROOT
./deploy.sh --dry-run      # preview everything
./deploy.sh                # install tools, write config, adopt clients, install cron watcher
```

Open a new terminal afterwards. Options: `--config FILE`, `--dry-run`, `--skip-tools`,
`--update-tools` (refresh unpinned tools to latest), `--yes`/`-y` (accept apt prompts), `--uninstall`, `--help`.

## What deploy does

1. **Prerequisites** – needs `curl tar unzip git crontab`. Ubuntu/Debian: offers `sudo apt-get install` for missing ones. macOS: asks for Xcode CLT.
2. **Tools** – release binaries into `BIN_DIR` (`~/.local/bin`), no package manager: jq yq direnv gh kubectl helm starship sops age terraform awscli. Optional, opt-in: `azcli` (the Azure CLI `az`, installed from PyPI into a private venv; add it to `INSTALL_TOOLS`; needs python3 >= 3.10). **Latest by default; pinned** via `TOOL_VERSION_<NAME>` in the config or `versions.conf`. SHA-256 is verified where upstream publishes one (all except direnv, age, azcli, awscli-on-Linux; awscli-on-macOS checks the pkg signature). `versions.lock` records what was installed.
3. **Shell** – managed blocks in `~/.bashrc` and `~/.bash_profile` (on Linux without a `~/.bash_profile`, `~/.profile`, bash only; the kit never creates a `~/.bash_profile` there) (direnv hook, per-client history, per-client shell fragments, Starship prompt showing the client). Non-interactive login shells (e.g. agent command shells, which draw no prompt) run `direnv export` once at startup so they get the approved client environment.
4. **Git** – defaults (`user.useConfigOnly=true`, empty global `credential.helper`), removes global `gh auth setup-git` helpers that override per-client ones, and appends one `[include]` **last** in `~/.gitconfig` pointing at `~/.config/workstation-segregation/gitconfig-clients` (generated `includeIf` per client).
5. **Claude Code** – registers a SessionStart hook in `~/.claude/settings.json` that re-exports the client's direnv environment into Claude's Bash tool.
6. **Adopt** – directories in `CLIENT_ROOT` that already carry segregation (`.envrc` mentioning `WORKSTATION_CLIENT`, or `.workstation/`) get any *missing* files added. Nothing existing is overwritten; an existing `.envrc` is never touched or auto-approved.
7. **Cron watcher** – `bin/watch.sh` every `WATCH_INTERVAL_MIN` minutes (see below).

## New clients

`mkdir $CLIENT_ROOT/acme` – within about `WATCH_INTERVAL_MIN + MIN_AGE_MIN` minutes the watcher creates
`.envrc`, `.workstation/{git,gh,docker,helm,terraform,npm,python,age,ssh,azure,bash,claude,codex,openai,notebooklm}`,
`.aws/config`, `.kube/config`, runs `direnv allow`, and refreshes the generated git includes.
Log: `~/.local/state/workstation-segregation/watch.log`.

Rules: any new top-level directory except `EXCLUDE_DIRS` and dot-dirs; directories that already
existed at first deploy are ignored unless segregated or listed in `ADOPT_DIRS`; a directory modified
within the last `MIN_AGE_MIN` minutes is deferred; names must match `[A-Za-z0-9][A-Za-z0-9._-]*`.

## Placeholders to fill per client

Scaffolded values are dummies (`REPLACE_ME`, `000000000000`, `*.example.invalid`), mostly commented out.
`direnv` warns on `cd` while git identity is unset or an *uncommented* `REPLACE_ME` remains.

| File (under the client dir) | Fill in |
|---|---|
| `.workstation/git/config` | `user.name`, `user.email` (uncomment). Git refuses to commit until set. |
| `.workstation/gh` | `GH_CONFIG_DIR=… gh auth login` (just `gh auth login` inside the dir) |
| `.aws/config` | SSO session/profile; then `AWS_PROFILE` in `.envrc` |
| `.kube/config` | e.g. `aws eks update-kubeconfig …` |
| `.workstation/azure` | `az login` once per client (inside the dir; `AZURE_CONFIG_DIR` keeps tokens and subscriptions out of `~/.azure`) |
| `.workstation/ssh/` | drop the client key at `id_ed25519`; add hosts to `config` |
| `.workstation/{npm/npmrc,terraform/terraformrc,python/pip.conf,age/keys.txt}` | registry tokens / `age-keygen -o` |
| `.workstation/claude`, `.workstation/codex` | log in once per client |
| `.workstation/openai/env` | client's private GPT API key, project and optional organization/base URL |
| `.workstation/notebooklm` | `nlm login` once per client (state is relocated by `NOTEBOOKLM_MCP_CLI_PATH`) |

After editing `.envrc` run `direnv allow` (the kit only auto-approves files it generated).

Codex uses a client ChatGPT login with file credentials; the client shell wrapper
removes GPT API settings from Codex's environment. API scripts load only the
client's private settings. Commands inside Codex can opt in with
`direnv exec "$WORKSTATION_CLIENT_DIR" <command>`. See the
[Codex/API operating and manual migration instructions](docs/USER-GUIDE.md#codex-cli-and-gpt-api-access).

## Assumptions and limitations

- **macOS privacy (TCC):** cron cannot read `~/Documents`, `~/Desktop` or `~/Downloads` until `/usr/sbin/cron` has *Full Disk Access* (System Settings → Privacy & Security). Manual, one-time. If the kit itself also lives there, cron cannot even open `watch.sh`; the cron line detects that and writes `cannot read watch.sh - grant Full Disk Access to /usr/sbin/cron` to `~/.local/state/workstation-segregation/cron.log`. Putting `CLIENT_ROOT` elsewhere (e.g. `~/clients`) avoids it.
- **Bash only**, scripts run on stock macOS bash 3.2. Interactive integration needs the login shell to be bash (`chsh -s /bin/bash`; deploy warns). macOS bash 3.2 is enough; no bash 5 is installed.
- **Paths may contain only `A-Z a-z 0-9 . _ / -`** (`CLIENT_ROOT`, `BIN_DIR`, kit location, client
  directory names and the resolved `gh` path), because they appear unquoted in generated Git
  credential helpers. A client directory with other characters is skipped with a warning.
- **AWS SSO/CLI token caches** (`~/.aws/sso/cache`, `~/.aws/cli/cache`) are not relocatable by env var and stay shared; sso-session names are client-prefixed to keep them distinguishable.
- **Agent CLIs:** with `ENABLE_AGENT_CLI_ISOLATION=1` new clients set `CLAUDE_CONFIG_DIR=<client>/.workstation/claude` and `CODEX_HOME=…/codex` for separate login, local settings and state. Common user/admin skills remain discoverable. Adopted clients keep their environment and shell behavior until manually migrated.
- **Browsers (opt-in, off by default):** with `ENABLE_BROWSER_ISOLATION=1` new clients put `shims/browser` on `PATH` and set `BROWSER`/`GH_BROWSER`, so `chrome`, `firefox` and CLI logins (gh, az, aws sso) open the client's existing named profile (`WORKSTATION_CHROME_PROFILE`, `WORKSTATION_FIREFOX_PROFILE`; `browser --list`). Links opened outside the client shell still use the system default browser, and profile data is not isolated, only which session is used. See the User Guide.
- Docker daemon/images, Slack and 1Password vaults, and the browsers' own data, are **not** segregated.
- **Docker and Helm registry logins are currently NOT segregated on macOS.** The client `config.json` has no `credsStore`, but the Docker CLI (and Helm, via oras-go) then auto-selects `osxkeychain` when that helper is on `PATH`, so `docker login` / `helm registry login` store credentials in the shared login Keychain. See [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md).
- **gh tokens live in the shared macOS Keychain** with default storage; `GH_CONFIG_DIR` separates only which account a client selects. **Confirmed:** in a client without its own gh login, Git's gh credential helper falls back to the last-activated account's token from the Keychain. See [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md).
- `gh auth setup-git` run later re-adds global helpers *after* the kit include; re-run `./deploy.sh` to repair ordering. Don't run it.
- Hand-written `includeIf` blocks in `~/.gitconfig` duplicate the generated ones (harmless; deploy warns).
- Absolute paths of `gh` and the client dir are rendered into per-client git config at scaffold time (machine-specific by design).
- Under a symlinked `CLIENT_ROOT` both logical and physical paths are emitted for `includeIf`.
- **azcli needs python3 ≥ 3.10 already on the machine** (stock macOS has 3.9; Homebrew/`tools/` base provide newer). The venv is bound to that interpreter. After a Python major upgrade, rebuild it: `rm -rf ~/.local/azure-cli` (the `az` link then dangles, so the next `./deploy.sh` reinstalls it). `--update-tools` alone does not, because it skips a tool whose recorded version is already current.
- Linux: Ubuntu/Debian assumed (apt only for prerequisites). **Linux is untested**, as is the awscli installer on both OSes. The other tools were installed on macOS/arm64 during development (checksum-verified where upstream publishes one); `azcli` is opt-in and has only been exercised with stubs, so check `az --version` after a first install.
- Starship uses `STARSHIP_CONFIG` pointing at `templates/starship.toml` (your `~/.config/starship.toml` is not touched). Set `STARSHIP_CONFIG` yourself to override.
- Adopted clients get inert config files only (no `ssh`/`scp`/`sftp` wrapper fragment) and keep their `.envrc`/git config, so they do **not** get `core.sshCommand` or agent-CLI isolation until added by hand.
- Per-client SSH uses `IdentitiesOnly yes` with a client key path; agent-held keys (1Password, ssh-agent) are not offered inside client directories unless you change `.workstation/ssh/config`.

## Uninstall

`./deploy.sh --uninstall` removes the managed blocks, git include, Claude hook, cron entry,
kit-installed binaries (per `versions.lock`) and state. Client directories are never touched. Global
git defaults and removed `gh` helpers are not restored (a `~/.gitconfig.bak.*` is kept).

## Layout

`deploy.sh` (entry) · `lib/` (common, tools, global, scaffold) · `bin/watch.sh` (cron entry) ·
`bin/{codex,browser,agy}-client.sh` (client launchers) · `shims/browser/` · `scheduler/`
(`install.sh` → `darwin.sh` | `linux.sh`) · `shell/` · `hooks/` · `templates/` · `tests/` (offline
suites) · `docs/` · `tools/` (separate OS-level tool installer, see [tools/README.md](tools/README.md))
