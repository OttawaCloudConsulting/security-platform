# workstation-segregation: User Guide

For the person who sets up and uses a workstation with several clients. For internals, see [DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md).

## 1. What it does

Each client gets its own directory under one root (default `~/Documents`). When you `cd` into it, direnv switches your shell to that client's AWS, Kubernetes, GitHub, Git identity, Docker, Helm, Terraform, npm, pip, SOPS/age, SSH, Claude/Codex and shell-history settings. When you leave, your global environment returns. Nothing client-specific lives in your global config.

```
~/Documents/                 <- CLIENT_ROOT
  acme/                      <- one client = one top-level directory
    .envrc                   <- direnv environment (editable)
    .workstation/            <- per-client tool config and credentials
    .aws/  .kube/
    <your repos...>
```

A cron job watches `CLIENT_ROOT`. Create a new top-level directory and the tool scaffolds all of the above with placeholder values for you to fill in.

## 2. Install

Requirements: macOS or Ubuntu/Debian, `bash`, `curl`, `tar`, `unzip`, `git`, `cron`. On Ubuntu/Debian deploy offers to `apt-get install` missing ones. On macOS install Xcode Command Line Tools (`xcode-select --install`).

```bash
cd workstation-segregation
./deploy.sh                       # 1st run: writes workstation-segregation.conf and exits
$EDITOR workstation-segregation.conf
./deploy.sh --dry-run             # preview every change, touches nothing
./deploy.sh                       # do it
```

Then open a **new terminal**.

Deploy options:

| Option | Effect |
|---|---|
| `--config FILE` | Use another config file (default `./workstation-segregation.conf`) |
| `--dry-run` | Print actions only |
| `--skip-tools` | Skip tool downloads |
| `--update-tools` | Refresh unpinned tools to the latest release |
| `--yes` | Accept the `sudo apt-get` prompt (Ubuntu/Debian) |
| `--uninstall` | Remove everything the tool added (never client directories) |

Deploy is idempotent. Re-run it any time, for example after changing the config.

### macOS: grant cron Full Disk Access (one time)

macOS blocks cron from reading `~/Documents`, `~/Desktop` and `~/Downloads`. Add `/usr/sbin/cron` under System Settings → Privacy & Security → Full Disk Access (use Cmd-Shift-G to type the path). Until then the watcher cannot see new clients; `~/.local/state/workstation-segregation/cron.log` will say so. Alternative: set `CLIENT_ROOT` to a folder outside the protected ones, such as `~/clients`.

## 3. Configuration

File: `workstation-segregation.conf` in the project directory (shell syntax, `KEY=value`). Created from `workstation-segregation.conf.example`.

| Variable | Default | Meaning |
|---|---|---|
| `CLIENT_ROOT` | `~/Documents` | Directory whose subdirectories are clients. Absolute path, no spaces. |
| `EXCLUDE_DIRS` | `workstation workstation-segregation tools Codex Zoom` | Names never treated as clients. Dot-directories are always skipped. The project's own directory is excluded automatically. |
| `ADOPT_DIRS` | empty | Pre-existing, not-yet-segregated directories to treat as clients. |
| `WATCH_INTERVAL_MIN` | `5` | How often cron runs the watcher. Re-run deploy after changing it. |
| `MIN_AGE_MIN` | `2` | A new directory must be unmodified this long before scaffolding (avoids half-copied dirs). `0` disables. |
| `ENABLE_AGY_CLI_ISOLATION` | `0` | AGY wrapper for new clients only when both isolation flags are 1; enable only after two-account acceptance. |
| `ENABLE_AGENT_CLI_ISOLATION` | `1` | New clients get their own `CLAUDE_CONFIG_DIR` / `CODEX_HOME`. `0` writes them commented out. |
| `INSTALL_TOOLS` | jq yq direnv gh kubectl helm starship sops age terraform awscli | Tools to install. Remove names to skip. |
| `BIN_DIR` | `~/.local/bin` | Where tool binaries go. Put first on `PATH` by the shell integration. |
| `REQUIRE_CHECKSUMS` | `0` | `1` = abort a tool install if upstream publishes no checksum. |
| `TOOL_VERSION_<NAME>` | unset | Pin a tool, e.g. `TOOL_VERSION_KUBECTL=1.34.1`. Unpinned tools use the latest release. |

Pins can also live in `versions.conf` (see `versions.conf.example`). After a deploy, `versions.lock` lists what was installed. To reproduce this machine elsewhere, turn each `name=1.2.3` into `TOOL_VERSION_NAME=1.2.3` in `versions.conf` on the new machine.

## 4. Day-to-day: adding a client

1. `mkdir ~/Documents/acme`.
2. Wait up to about `WATCH_INTERVAL_MIN + MIN_AGE_MIN` minutes. The watcher scaffolds the directory and runs `direnv allow`. Check progress: `tail ~/.local/state/workstation-segregation/watch.log`.
3. `cd ~/Documents/acme`. direnv will warn about anything unfilled.
4. Fill in the placeholders (next section).

Naming: client names must match `[A-Za-z0-9][A-Za-z0-9._-]*`. The environment variable `WORKSTATION_CLIENT` is the upper-cased name (`acme` → `ACME`); it shows in your prompt.

### Placeholders to fill in

All paths are relative to the client directory. Dummy values are `REPLACE_ME`, `000000000000` and `*.example.invalid`, and most are commented out.

| File | What to do |
|---|---|
| `.workstation/git/config` | Uncomment `[user]` `name` and `email`. Until set, `git commit` fails by design. |
| `.workstation/gh/` | Inside the client dir run `gh auth login`. Git then authenticates to GitHub with that login. |
| `.aws/config` | Uncomment and edit the `sso-session` and `profile`. Then `export AWS_PROFILE=...` in `.envrc` and `direnv allow`. |
| `.kube/config` | Populate, for example `aws eks update-kubeconfig --name <cluster> --region <region>`. |
| `.workstation/ssh/` | Copy the client key to `id_ed25519` (mode 600). Add hosts to `config`. |
| `.workstation/npm/npmrc`, `terraform/terraformrc`, `python/pip.conf` | Registry URLs and tokens, if the client needs them. |
| `.workstation/age/keys.txt` | Replace the placeholder with a real key: `age-keygen -o keys.txt`. |
| `.workstation/claude`, `.workstation/codex` | Log in to Claude Code / Codex once per client. |
| `.workstation/openai/env` | Uncomment the client's GPT API key, project and organization settings as needed. Keep this private local file out of repositories. |
| `.envrc` | Optional extras are listed as comments (uv index, 1Password account, k9s). |

After editing `.envrc`, run `direnv allow`. Only the `.envrc` the tool generated is auto-approved; later edits and any pre-existing `.envrc` need your approval.

### Checking that segregation works

```bash
cd ~/Documents/acme
echo $WORKSTATION_CLIENT $GH_CONFIG_DIR $KUBECONFIG     # client values
cd ~/Documents/acme/some-repo && git config user.email   # client identity
cd ~ && echo ${WORKSTATION_CLIENT:-<none>}               # back to global
```

Git identity and credentials only apply inside a Git repository under the client directory (that is how Git's `includeIf` works).

## 5. Existing clients

Directories that already carry segregation (an `.envrc` mentioning `WORKSTATION_CLIENT`, or a `.workstation/` folder) are **adopted** at deploy: missing files are added, nothing is overwritten, and your `.envrc` is left alone. Adoption does not enable `core.sshCommand`, SSH wrappers or Claude/Codex isolation automatically. Existing manual configuration is preserved. Add any missing behavior by hand, copying the lines from `templates/client/envrc` and `templates/client/git-config`.

Other directories that existed at first deploy are ignored (they are not clients). Add a name to `ADOPT_DIRS` and re-run deploy to include one.

To preview additions to existing clients, run from the client root:

```bash
bash workstation-segregation/deploy.sh --dry-run --skip-tools
```

For adopted clients, `DRY-RUN: create` lists missing files that would be added;
existing files are skipped. The preview does not show file contents or apply
manual migration to existing `.envrc` files or shell fragments. Global shell,
Git, Claude-hook and cron lines describe normal deploy actions; they do not
necessarily mean the current configuration differs. No changes are made.

### Codex CLI and GPT API access

New clients with agent isolation enabled receive `.workstation/codex/config.toml`
with `cli_auth_credentials_store = "file"` and `forced_login_method = "chatgpt"`.
Codex settings, file credentials and local state use the client's `CODEX_HOME`;
inherited `CODEX_SQLITE_HOME` is cleared. Model, permissions, MCP servers and
plugins retain Codex defaults and can be customized per client. See the official
[authentication documentation](https://learn.chatgpt.com/docs/auth) and
[environment documentation](https://learn.chatgpt.com/docs/config-file/environment-variables).

GPT API scripts use `.workstation/openai/env` (dotenv syntax). The directory is
created with mode 700 and this file and the Codex config with mode 600. Existing
files and permissions are preserved. Uncomment `OPENAI_API_KEY`,
`OPENAI_PROJECT_ID` and `OPENAI_ORG_ID` as needed; `OPENAI_BASE_URL` is optional.
Use a separate API key and project for each client. SDKs differ in which settings
they consume; pass the project/organization explicitly in scripts when necessary.
The `.envrc` clears inherited exported `OPENAI_*`, `CODEX_API_KEY` and
`CODEX_ACCESS_TOKEN` before loading the private file, and watches it for changes.
An unconfigured client receives no inherited API settings. Leaving the client
restores the outer shell environment.

The client's `codex` shell function calls `bin/codex-client.sh`. The launcher
checks the active client, current directory and expected `CODEX_HOME`, then
removes `OPENAI_*` and Codex authentication/state overrides from its subprocess
environment. It preserves cloud/tool variables, arguments and exit status.
It uses the installed Codex binary on PATH; the kit adds no installer or model pin.
Calling the binary directly or `command codex` bypasses the shell wrapper.

Start Codex from the intended client directory and run a fresh `codex login`,
then `codex login status`. Choose that client's ChatGPT account in the browser.
Do not copy global authentication, settings or session history into the client.
Stop the old Codex process and start a new one after switching clients; a running
process retains the environment and login it started with.

When a command run by Codex needs GPT API access, explicitly reload the client's
API environment for that command:

```bash
direnv exec "$WORKSTATION_CLIENT_DIR" python path/to/gpt_script.py
```

No automatic API-key forwarding or Codex session hook is installed. Common
user/admin skills remain available through Codex's normal discovery. This
separates local configuration and credentials; it does not restrict filesystem
access, global skill discovery, desktop/browser sessions or remote account data.

### Manual migration for mlse, occ and zonal

Adoption adds missing Codex/API configuration files but preserves each existing
`.envrc` and shell fragments. For **each** of `~/Documents/mlse`,
`~/Documents/occ` and `~/Documents/zonal`:

1. Back up `.envrc`. Enable its existing
   `export CODEX_HOME="$(expand_path .workstation/codex)"` line and add
   `unset CODEX_SQLITE_HOME` immediately below it.
2. Copy the GPT API clearing/loading block from `templates/client/envrc`
   (the `for _openai_var` loop through the `dotenv` conditional) into `.envrc`.
3. Ensure the missing private files have been scaffolded. If doing this manually,
   create `.workstation/{codex,openai}` with mode 700 and copy
   `templates/client/codex-config.toml` and `templates/client/openai-env` to
   `.workstation/codex/config.toml` and `.workstation/openai/env` with mode 600,
   preserving any existing files. Fill the API file privately.
4. Add `.workstation/bash/codex.sh` with the following function (back up any
   existing fragment before editing):

   ```bash
   codex() { /bin/bash "$HOME/Documents/workstation-segregation/bin/codex-client.sh" "$@"; }
   ```

   Adjust the kit path if installed elsewhere. Open a new terminal to load the
   fragment; the fragment hook only reloads on client-directory changes.
5. Enter that client, run `direnv allow`, and let the shell prompt reload its
   environment. Confirm `CODEX_HOME` points to that client's directory, then
   run `codex login` and `codex login status` with the intended ChatGPT account.

These steps are manual; re-running deploy never migrates existing environment or
shell behavior automatically.

### This workstation: migration applied on 2026-10-13

The existing `mlse`, `occ` and `zonal` clients have now been updated:

- Each `.envrc` was backed up as `.envrc.bak.<timestamp>`, its existing
  `CODEX_HOME` export enabled, and `CODEX_SQLITE_HOME` clearing added.
- Each `.envrc` now clears inherited exported `OPENAI_*` and Codex authentication
  overrides before watching and loading `.workstation/openai/env`.
- Each client has `.workstation/bash/codex.sh`, calling the kit launcher.
- The private Codex/API files created by deploy were preserved; their permissions
  and Codex authentication defaults were checked.

Bash 3.2 syntax and real direnv environment checks passed for all three clients.
The checks used a temporary approval store because the agent sandbox could not
write to this user's normal direnv approval store. Approval in that store and
client logins were not confirmed during this update.

The local [temp-update-configs.sh](../../temp-update-configs.sh) helper lives in
`~/Documents`, alongside the client directories. Run it as your normal user:

```bash
cd ~/Documents
./temp-update-configs.sh
```

It verifies that direnv and all three `.envrc` files exist, then runs `direnv allow`
for each client. It only approves the already-updated environments; it does not
edit configuration or perform logins. It is a temporary local helper outside
the portable kit. The equivalent commands are:

```bash
for client in mlse occ zonal; do
  direnv allow "$HOME/Documents/$client"
done
```

After approval, open a new terminal so the client shell fragments load. Enter
each client directory, run `codex login` with its ChatGPT account, and check
`codex login status`. Fill each private `.workstation/openai/env` with that
client's GPT API settings when needed. API keys and login credentials were not
populated or copied as part of the migration.

## 6. What is and is not segregated

Segregated per client: AWS config and credentials file, kubeconfig, GitHub CLI login and Git credentials, Git identity, SSH keys and config, Docker registry logins, Helm config/cache, Terraform CLI config, npm/pip config, SOPS age key, shell history, Claude and Codex config (when enabled), and GPT API settings loaded by the new environment template.

Not segregated: AWS SSO and CLI token caches (`~/.aws/sso/cache`, `~/.aws/cli/cache`), Docker daemon and images, `~/.terraform.d`, browsers, Slack, 1Password vaults, other agent CLIs. SSH inside client directories uses only the client key (`IdentitiesOnly yes`), so agent-held keys are not offered there unless you edit `.workstation/ssh/config`.

## 7. Keeping tools current

`./deploy.sh --update-tools` moves unpinned tools to the latest release. Pinned tools stay put. Checksums are verified where upstream publishes them; direnv, age and awscli (on Linux) install over HTTPS only and deploy says so. Set `REQUIRE_CHECKSUMS=1` to refuse unverified installs.

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| New client not scaffolded | Check `watch.log` and `cron.log` under `~/.local/state/workstation-segregation/`. On macOS the usual cause is missing Full Disk Access for `/usr/sbin/cron`. Confirm the cron entry with `crontab -l`. Directory too new? Wait `MIN_AGE_MIN`. Directory existed before first deploy? Use `ADOPT_DIRS`. Name excluded or invalid? |
| `direnv: error ... .envrc is blocked` | Run `direnv allow` in the client directory. |
| `git commit` says "Author identity unknown" | Set `user.name`/`user.email` in `.workstation/git/config`. Expected until you do. |
| Git asks for GitHub credentials | Run `gh auth login` inside the client dir. Check you did not run `gh auth setup-git` (it re-adds a global helper that overrides the client one; re-run `./deploy.sh` to repair). |
| Git identity not applied | The directory must be inside a Git repo under the client dir. Check `~/.config/workstation-segregation/gitconfig-clients` lists the client. |
| Tools missing from `PATH` | Open a new terminal. Confirm `~/.bashrc` contains the `workstation-segregation:shell` block and your login shell is bash. |
| Doubled prompt or hooks | Old `../workstation` config is still present. See Migration. |
| A tool failed to install | Deploy continues with the others and lists failures. Re-run, or pin another version. |
| Claude Bash tool lacks client variables | The SessionStart hook runs at session start only; start Claude from inside the client directory. |

Logs: `~/.local/state/workstation-segregation/{watch.log,cron.log}`.

## 9. Migrating from the old `workstation` setup

Deploy leaves the old setup alone and warns about it. Running both duplicates hooks and prompts, so after a successful deploy:

1. **First** copy what the old block provided that this tool does not (the `/opt/homebrew/bin` PATH line, `EDITOR`/`VISUAL`, `HOMEBREW_NO_ANALYTICS`, nvm init, aliases from `~/.workstation_aliases`) into `~/.bashrc`, outside any managed block.
2. Remove the old `# >>> workstation managed >>>` and `# >>> workstation bash_profile managed >>>` blocks from `~/.bashrc` and `~/.bash_profile`.
3. Remove the old SessionStart hook (`workstation/config/claude/direnv-session-env.sh`) from `~/.claude/settings.json`.
4. Delete `~/Documents/.workstation-projects`.
5. Optionally delete hand-written `includeIf` blocks in `~/.gitconfig` once the generated ones work.

## 10. Uninstall

`./deploy.sh --uninstall` removes the shell blocks, the Git include, the Claude hook, the cron entry, installed tool binaries (those in `versions.lock`) and the state directory. Client directories and their files are never touched. Global Git defaults and the removed `gh` credential helpers are not restored; `~/.gitconfig.bak.*` holds the earlier file.

## 11. Files this tool changes

| Location | Change |
|---|---|
| `~/.bashrc`, `~/.bash_profile` | One marked block each (`# >>> workstation-segregation:shell >>>`). Created if absent on macOS. |
| `~/.gitconfig` | Defaults set if unset; global `gh` credential helpers removed; one marked `[include]` kept as the last entry. |
| `~/.config/workstation-segregation/gitconfig-clients` | Generated `includeIf` per client. |
| `~/.claude/settings.json` | SessionStart hook added (backup first). |
| `crontab` | One tagged line. Other entries are preserved. |
| `~/.local/bin` (`BIN_DIR`) | Tool binaries; awscli under `~/.local/aws-cli`. |
| `~/.local/state/workstation-segregation/` | Logs, baseline of pre-existing directories, watcher lock. |
| Each client directory | Created-if-missing files only. |

Every changed file is backed up as `<file>.bak.<timestamp>` when its content changes.

## AGY CLI (disabled pending acceptance)

See [persistent account testing, rollout and rollback](AGY-LOGIN-ISOLATION.md).
Private HOME changes apply only to the AGY child; existing clients are not
automatically migrated. One-account testing cannot authorize activation.
