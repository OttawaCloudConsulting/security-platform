# workstation-segregation

Portable client segregation for a macOS or Ubuntu/Debian workstation. Each client gets its own
directory under one root; entering it (via direnv) switches cloud, cluster, Git, registry, SSH,
agent-CLI and shell-history state to that client's. Generalised from `../workstation/`.

Full documentation: [docs/USER-GUIDE.md](docs/USER-GUIDE.md) (operating it) and [docs/DEVELOPER-GUIDE.md](docs/DEVELOPER-GUIDE.md) (changing it). Open problems: [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md).

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
`--update-tools` (refresh unpinned tools to latest), `--yes` (accept apt prompts), `--uninstall`.

## What deploy does

1. **Prerequisites** – needs `curl tar unzip git crontab`. Ubuntu/Debian: offers `sudo apt-get install` for missing ones. macOS: asks for Xcode CLT.
2. **Tools** – release binaries into `BIN_DIR` (`~/.local/bin`), no package manager: jq yq direnv gh kubectl helm starship sops age terraform awscli. **Latest by default; pinned** via `TOOL_VERSION_<NAME>` in the config or `versions.conf`. SHA-256 is verified where upstream publishes one (all except direnv, age, awscli-on-Linux; awscli-on-macOS checks the pkg signature). `versions.lock` records what was installed.
3. **Shell** – managed blocks in `~/.bashrc` / `~/.bash_profile` (direnv hook, per-client history, per-client shell fragments, Starship prompt showing the client).
4. **Git** – defaults (`user.useConfigOnly=true`, empty global `credential.helper`), removes global `gh auth setup-git` helpers that override per-client ones, and appends one `[include]` **last** in `~/.gitconfig` pointing at `~/.config/workstation-segregation/gitconfig-clients` (generated `includeIf` per client).
5. **Claude Code** – registers a SessionStart hook in `~/.claude/settings.json` that re-exports the client's direnv environment into Claude's Bash tool.
6. **Adopt** – directories in `CLIENT_ROOT` that already carry segregation (`.envrc` mentioning `WORKSTATION_CLIENT`, or `.workstation/`) get any *missing* files added. Nothing existing is overwritten; an existing `.envrc` is never touched or auto-approved.
7. **Cron watcher** – `bin/watch.sh` every `WATCH_INTERVAL_MIN` minutes (see below).

## New clients

`mkdir $CLIENT_ROOT/acme` – within about `WATCH_INTERVAL_MIN + MIN_AGE_MIN` minutes the watcher creates
`.envrc`, `.workstation/{git,gh,docker,helm,terraform,npm,python,age,ssh,bash,claude,codex,openai}`,
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
| `.workstation/ssh/` | drop the client key at `id_ed25519`; add hosts to `config` |
| `.workstation/{npm/npmrc,terraform/terraformrc,python/pip.conf,age/keys.txt}` | registry tokens / `age-keygen -o` |
| `.workstation/claude`, `.workstation/codex` | log in once per client |
| `.workstation/openai/env` | client's private GPT API key, project and optional organization/base URL |

After editing `.envrc` run `direnv allow` (the kit only auto-approves files it generated).

Codex uses a client ChatGPT login with file credentials; the client shell wrapper
removes GPT API settings from Codex's environment. API scripts load only the
client's private settings. Commands inside Codex can opt in with
`direnv exec "$WORKSTATION_CLIENT_DIR" <command>`. See the
[Codex/API operating and manual migration instructions](docs/USER-GUIDE.md#codex-cli-and-gpt-api-access).

## Assumptions and limitations

- **macOS privacy (TCC):** cron cannot read `~/Documents`, `~/Desktop` or `~/Downloads` until `/usr/sbin/cron` has *Full Disk Access* (System Settings → Privacy & Security). Manual, one-time. If the kit itself also lives there, cron cannot even open `watch.sh`; the cron line detects that and writes `cannot read watch.sh - grant Full Disk Access to /usr/sbin/cron` to `~/.local/state/workstation-segregation/cron.log`. Putting `CLIENT_ROOT` elsewhere (e.g. `~/clients`) avoids it.
- **Bash only**, scripts run on stock macOS bash 3.2. Interactive integration needs the login shell to be bash (`chsh -s /bin/bash`; deploy warns). macOS bash 3.2 is enough; no bash 5 is installed.
- **Paths must not contain whitespace** (`CLIENT_ROOT`, `BIN_DIR`, kit location).
- **AWS SSO/CLI token caches** (`~/.aws/sso/cache`, `~/.aws/cli/cache`) are not relocatable by env var and stay shared; sso-session names are client-prefixed to keep them distinguishable.
- **Agent CLIs:** with `ENABLE_AGENT_CLI_ISOLATION=1` new clients set `CLAUDE_CONFIG_DIR=<client>/.workstation/claude` and `CODEX_HOME=…/codex` for separate login, local settings and state. Common user/admin skills remain discoverable. Adopted clients keep their environment and shell behavior until manually migrated.
- Docker daemon/images, browsers, Slack and 1Password vaults are **not** segregated.
- Docker `config.json` deliberately has no `credsStore` (a shared keychain store would leak registry logins).
- `gh auth setup-git` run later re-adds global helpers *after* the kit include; re-run `./deploy.sh` to repair ordering. Don't run it.
- Hand-written `includeIf` blocks in `~/.gitconfig` duplicate the generated ones (harmless; deploy warns).
- Absolute paths of `gh` and the client dir are rendered into per-client git config at scaffold time (machine-specific by design).
- Under a symlinked `CLIENT_ROOT` both logical and physical paths are emitted for `includeIf`.
- Linux: Ubuntu/Debian assumed (apt only for prerequisites). **Linux is untested**, as is the awscli installer on both OSes (the other ten tools were installed and checksum-verified on macOS/arm64).
- Starship uses `STARSHIP_CONFIG` pointing at `templates/starship.toml` (your `~/.config/starship.toml` is not touched). Set `STARSHIP_CONFIG` yourself to override.
- Adopted clients get inert config files only (no `ssh`/`scp`/`sftp` wrapper fragment) and keep their `.envrc`/git config, so they do **not** get `core.sshCommand` or agent-CLI isolation until added by hand.
- Per-client SSH uses `IdentitiesOnly yes` with a client key path; agent-held keys (1Password, ssh-agent) are not offered inside client directories unless you change `.workstation/ssh/config`.

## Migrating from `../workstation` (same machine)

The old setup is not removed automatically; deploy warns about each leftover. Running both causes duplicate
direnv hooks, `PROMPT_COMMAND` entries, starship init and Claude hooks. After the first successful deploy:

0. **First copy what the old block provides that the kit does not**: the `/opt/homebrew/bin` PATH line, `EDITOR`/`VISUAL`, `HOMEBREW_NO_ANALYTICS`, the nvm init, and any aliases you use from `~/.workstation_aliases` (e.g. `python`, `reload`, `path`) into `~/.bashrc` outside any managed block. Otherwise `node`, `k9s`, `shellcheck`, `code --wait` etc. vanish from interactive shells.
1. Remove the `# >>> workstation managed >>>` / `# >>> workstation bash_profile managed >>>` blocks from `~/.bashrc` and `~/.bash_profile`; delete `~/.workstation_aliases`, `~/.workstation_bash_profile`.
2. Remove the old SessionStart hook (`workstation/config/claude/direnv-session-env.sh`) from `~/.claude/settings.json`.
3. Delete `~/Documents/.workstation-projects` (the kit does not auto-approve edits; run `direnv allow` after changing an `.envrc`).
4. Leave the old launchd job unloaded; the cron watcher replaces it for client creation (tool updates: `./deploy.sh --update-tools`).
5. Optionally delete the hand-written `includeIf` blocks in `~/.gitconfig` once `git -C <repo> config user.email` resolves via the generated include.

## Uninstall

`./deploy.sh --uninstall` removes the managed blocks, git include, Claude hook, cron entry,
kit-installed binaries (per `versions.lock`) and state. Client directories are never touched. Global
git defaults and removed `gh` helpers are not restored (a `~/.gitconfig.bak.*` is kept).

## Layout

`deploy.sh` (entry) · `lib/` (common, tools, global, scaffold) · `bin/watch.sh` (cron entry) ·
`scheduler/` (`install.sh` → `darwin.sh` | `linux.sh`) · `shell/` · `hooks/` · `templates/`
