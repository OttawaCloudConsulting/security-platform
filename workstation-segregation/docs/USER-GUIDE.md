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

Directories that already carry segregation (an `.envrc` mentioning `WORKSTATION_CLIENT`, or a `.workstation/` folder) are **adopted** at deploy: missing files are added, nothing is overwritten, and your `.envrc` is left alone. Adopted clients do not get `core.sshCommand`, the `ssh` wrapper, or Claude/Codex isolation. Add them by hand, copying the lines from `templates/client/envrc` and `templates/client/git-config`.

Other directories that existed at first deploy are ignored (they are not clients). Add a name to `ADOPT_DIRS` and re-run deploy to include one.

## 6. What is and is not segregated

Segregated per client: AWS config and credentials file, kubeconfig, GitHub CLI login and Git credentials, Git identity, SSH keys and config, Docker registry logins, Helm config/cache, Terraform CLI config, npm/pip config, SOPS age key, shell history, Claude and Codex config (when enabled).

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
