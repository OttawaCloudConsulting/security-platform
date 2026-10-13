# workstation-segregation: Developer Guide

For people changing the scripts. Operators should read [USER-GUIDE.md](USER-GUIDE.md).

## 1. Design goals and constraints

- **One entry point:** `deploy.sh` does everything; `bin/watch.sh` is the only other executable users see (via cron).
- **Portable:** macOS and Ubuntu/Debian. Tools are release binaries in `BIN_DIR`, not package-manager installs (apt only for prerequisites).
- **Runs on stock macOS bash 3.2.** Never use: `declare -A`, `mapfile`/`readarray`, `${v,,}`/`${v^^}`, `[[ -v ]]`, `|&`, `&>>`, `local -n`, `globstar`. `+=`, `${!var}`, `[[ ]]`, `local` are fine. The shell files in `shell/` are sourced by the user's interactive bash, so the same rule applies.
- **Non-destructive and idempotent:** create-if-missing for client files; marked, replaceable blocks for global files; backups only when content changes.
- **Config is data:** one sourced `KEY=value` file; no YAML/JSON parsing dependency.
- Scripts use `set -Eeuo pipefail` (as required by the old repo's AGENTS.md) and support `--dry-run`.

## 2. Layout

```
deploy.sh                 entry: arg parsing, prereqs, orchestration, summary
bin/watch.sh              cron entry: finds new client dirs, scaffolds them
lib/common.sh             logging, run(), config loading, block/backup/file helpers, template render, TCC check
lib/tools.sh              tool installers, checksum verification, versions.lock
lib/global.sh             ~/.bashrc, ~/.bash_profile, ~/.gitconfig, ~/.claude/settings.json handling
lib/scaffold.sh           per-client scaffolding, gitconfig-clients generation
scheduler/install.sh      OS dispatch -> darwin.sh | linux.sh   (cron-common.sh = shared crontab editing)
shell/                    sourced by the user's shell: bashrc.sh, bash_profile.sh, aliases.sh
hooks/direnv-session-env.sh   Claude Code SessionStart hook
templates/                client/* (rendered per client), starship.toml, git-global.conf
workstation-segregation.conf.example, versions.conf.example
```

`lib/*.sh` and `scheduler/cron-common.sh` are source-only. All use `KIT_ROOT` (absolute project path) and the config variables loaded by `load_config`.

## 3. Execution flow

### deploy.sh

1. Parse args; export `KIT_ROOT`, `DRY_RUN`, `UPDATE_TOOLS`.
2. Config: if missing, copy the example and exit 1 (uninstall falls back to the example's defaults). `load_config` sets defaults, sources the config, then `versions.conf`, then normalises and validates (`CLIENT_ROOT` absolute, no whitespace, numeric intervals) and derives `STATE_DIR` and `KIT_CONFIG_DIR`.
3. `--uninstall`: `scheduler/install.sh remove`, `global_uninstall`, `uninstall_tools`, remove `STATE_DIR`, exit.
4. `check_prereqs` (apt on Debian/Ubuntu, otherwise instruct).
5. `install_tools` unless `--skip-tools`; prepend `BIN_DIR` to `PATH`.
6. `global_install`: `setup_shell`, `setup_git`, `setup_claude_hook`.
7. Baseline: on first deploy write `STATE_DIR/baseline-dirs` (names of every top-level dir that exists).
8. Adopt loop: segregated dirs are scaffolded in `adopt` mode; `ADOPT_DIRS` names in `new` mode. Then `regen_gitconfig_clients`.
9. `scheduler/install.sh install`; print summary.

### bin/watch.sh (every `WATCH_INTERVAL_MIN`)

1. Set a minimal `PATH` (cron's is bare) plus `BIN_DIR` and common brew locations; load config; log to `STATE_DIR/watch.log` unless `--verbose`.
2. `mkdir` lock `STATE_DIR/watch.lock` (stale after 30 min). `flock` is unavailable on stock macOS.
3. Require the baseline file; `check_client_root` (surfaces TCC denials).
4. For each top-level real directory: skip excluded/dot-dirs, dirs with `.workstation/.segregation-managed`, baseline dirs not in `ADOPT_DIRS`, and dirs modified within `MIN_AGE_MIN`. Scaffold the rest.
5. Always `regen_gitconfig_clients` (cheap, writes only on change).

## 4. Core helpers (`lib/common.sh`)

| Function | Purpose |
|---|---|
| `log`, `warn`, `die` | Timestamped output (`warn`/`die` to stderr). |
| `run cmd…` | Executes, or prints under `DRY_RUN=1`. Use for every mutation that is not wrapped by another helper. |
| `block_insert file id` (stdin) | Writes `# >>> workstation-segregation:<id> >>>` … `<<<` at the **end** of the file, replacing any existing block. Skips (no backup) if the file would be unchanged. |
| `block_remove file id` | Removes the block, with backup. |
| `write_file_if_changed dest mode` (stdin) | Atomic-ish write only on difference. |
| `backup_file` | `cp -p file file.bak.<ts>`. |
| `render_template src` | `sed` substitution of `{{CLIENT}} {{CLIENT_UC}} {{DIR}} {{KIT}} {{GH}} {{HOME}} {{AGENT_PREFIX}}` from `R_*` shell variables (values escaped with `sed_escape`). |
| `is_excluded`, `in_list` | Membership tests on `EXCLUDE_DIRS` / space-separated lists. |
| `check_client_root` | `ls -A` the root and emit the Full Disk Access instruction on "Operation not permitted". |
| `detect_platform` | Sets `KIT_OS` (`darwin`/`linux`) and `KIT_ARCH` (`amd64`/`arm64`). |

Dry-run rule: any new code path that writes must go through `run`, a block/write helper, or an explicit `[ "$DRY_RUN" = 1 ]` guard. Test with `--dry-run` and confirm nothing changes.

## 5. Scaffolding (`lib/scaffold.sh`)

`scaffold_client <dir> [adopt]`:

- Validates the name, sets `R_CLIENT`, `R_CLIENT_UC`, `R_DIR`, `R_GH` (absolute `gh` path), `R_AGENT_PREFIX` (`""` or `"# "` per `ENABLE_AGENT_CLI_ISOLATION`).
- Creates `.workstation/*`, `.aws`, `.kube` directories (mode 700 only when newly created).
- `_install_tpl <template> <dest> <mode>` renders `templates/client/<template>` to `<client>/<dest>` **only if the destination does not exist** (returns 1 if it existed). Only a freshly created `.envrc` triggers `direnv allow`; a pre-existing `.envrc` is never trusted automatically.
- `adopt` mode skips `ssh-fragment.sh` because that file is *sourced* by the user's shell and redefines `ssh`/`scp`/`sftp`; adopting must not change behaviour.
- Writes the marker `.workstation/.segregation-managed` last.

`regen_gitconfig_clients` writes `$KIT_CONFIG_DIR/gitconfig-clients`: one `includeIf "gitdir:<dir>/"` per top-level dir that has `.workstation/git/config`. It uses `gitdir/i:` on macOS (case-insensitive FS) and also emits the physical (`cd -P`) path when `CLIENT_ROOT` is reached through a symlink, because Git matches the real path.

### Adding or changing a client file

1. Add `templates/client/<name>` using the tokens above.
2. Add one `_install_tpl <name> <dest> <mode> || true` line in `scaffold_client` (the `|| true` is required under `set -e`).
3. If it needs a new directory, add it to the `for sub in …` list.
4. Document it in the USER-GUIDE placeholder table if the user must edit it.
5. Remember existing clients only get the file if the destination is missing; changing a template does not rewrite deployed files.

### Placeholder policy

Fill values with `REPLACE_ME`, `000000000000` or `*.example.invalid`. Keep credential-bearing lines **commented**. The `.envrc` template warns (`log_status`) when git identity is unset or an *uncommented* `REPLACE_ME` remains in the watched files; keep that list in sync if you add a file.

## 6. Tools (`lib/tools.sh`)

Driver `install_tools` loops `INSTALL_TOOLS`. For each tool it needs two functions:

```bash
tool_<name>_latest   # prints the newest version without a leading "v"
tool_<name>_install  # $1 = version; downloads to $TOOL_TMP, verifies, put_bin
```

Also add the name to `INSTALL_TOOLS` defaults (`load_config` and the example config), and to `tool_bins` if it installs more or differently named binaries.

Decision logic per tool: pinned version (`TOOL_VERSION_<NAME>`) → install if absent or lock differs; unpinned → skip if present unless `--update-tools`, else resolve latest. `versions.lock` (`name=version`) is **output only**; it is never read as a pin.

Helpers: `gh_latest_tag owner/repo` (follows `releases/latest`, so no API rate limit), `fetch`, `verify_download file name url…` (tries each checksum URL), `checksum_lookup` (understands `hash  name`, `hash *name`, single-hash files and BSD `SHA256 (name) = hash`, matching only the SHA256 label), `put_bin`, `find_in`.

Checksum behaviour: found and matching → proceed; mismatch → `die` (that tool fails); none published → warn and install, or fail when `REQUIRE_CHECKSUMS=1`. Each installer runs in a subshell with `set -e` and its status captured explicitly, so one tool failing does not stop the rest.

Per-tool notes: terraform's version comes from the HashiCorp releases index (first non-prerelease entry); kubectl from `dl.k8s.io/release/stable.txt`; awscli from the CHANGELOG, installed with the macOS `.pkg` (`installer -target CurrentUserHomeDirectory` plus a choices XML, signature checked with `pkgutil`) or the Linux zip installer into `~/.local/aws-cli`.

## 7. Global configuration (`lib/global.sh`)

- **Shell:** `setup_shell` writes a `shell` block into `~/.bashrc` (exports `WORKSTATION_SEGREGATION_ROOT/BIN/CONFIG`, sources `shell/bashrc.sh`). `~/.bash_profile` gets a block only if it exists or on macOS (on Linux creating it would shadow `~/.profile`). It warns about the old `workstation` blocks and a non-bash login shell.
- **Shell integration (`shell/bashrc.sh`):** guarded against double sourcing; adds `BIN_DIR` to `PATH`; interactive-only part sets up the direnv hook, `_workstation_history_sync` (swap `HISTFILE` per client) and `_workstation_client_sync` (source/unload `<client>/.workstation/bash/*.sh`), and Starship using `STARSHIP_CONFIG` (default: the project's template).
- **Git:** `credential.helper` and `user.useConfigOnly` are always enforced; other defaults from `templates/git-global.conf` only when unset. Global `credential.https://github.com.helper` and the gist equivalent are unset because `gh auth setup-git` writes them after includes and they override the per-client helper. The `include` block is inserted **last**, and the previous `~/.gitconfig` is kept as `.bak` if anything changed.
- **Claude hook:** `jq` merges a SessionStart entry (`/bin/bash <root>/hooks/direnv-session-env.sh`) into `~/.claude/settings.json`, idempotently, with backup. `remove_claude_hook` reverses it. Per-client `.workstation/claude/settings.json` gets the same hook because `CLAUDE_CONFIG_DIR` replaces the global settings.

## 8. Scheduler

`scheduler/install.sh` dispatches on `uname` to `darwin.sh` or `linux.sh` (`install|remove`). Both source `cron-common.sh`, which builds one crontab line tagged `# workstation-segregation watcher` and edits the user crontab by filtering that tag, so other entries survive. The line runs a small `bash -c` wrapper that first tries to open `watch.sh` and prints a Full Disk Access hint to `cron.log` if macOS denies it (cron cannot read scripts under `~/Documents` without FDA). `darwin.sh` prints the FDA steps; `linux.sh` warns if no cron daemon is running.

## 9. Testing

The real deploy edits dotfiles, crontab and `~/.claude`; test in a fake HOME with a stub `crontab`:

```bash
T=$(mktemp -d); mkdir -p $T/{home,clients,stub}
cat > $T/stub/crontab <<'EOF'
#!/bin/bash
F="$HOME/.fc"
case "${1:-}" in -l) [ -f "$F" ] && cat "$F" || exit 1;; -r) rm -f "$F";; -) cat > "$F";; esac
EOF
chmod +x $T/stub/crontab
printf 'CLIENT_ROOT=%s/clients\nBIN_DIR=%s/stub\nMIN_AGE_MIN=0\n' $T $T > $T/c.conf
export HOME=$T/home SHELL=/bin/bash PATH=$T/stub:$PATH
/bin/bash deploy.sh --config $T/c.conf --dry-run --skip-tools     # nothing written
/bin/bash deploy.sh --config $T/c.conf --skip-tools               # real, fake HOME
mkdir $T/clients/acme && /bin/bash bin/watch.sh --config $T/c.conf --verbose
/bin/bash deploy.sh --config $T/c.conf --skip-tools               # idempotence: "unchanged"
/bin/bash deploy.sh --config $T/c.conf --uninstall
```

Always invoke with `/bin/bash` (3.2 on macOS) so version-specific bugs show. Checklist before merging:

- `/bin/bash -n` on every script; `shellcheck -s bash -x` (current output is only SC2034 for config variables, SC2088 and SC2016 noise).
- Grep for forbidden constructs (section 1).
- Dry-run changes nothing; second real run reports only `unchanged`.
- An existing `.envrc` and other client files are byte-identical after deploy.
- New client: files exist, `.kube/config` and `.aws/config` are mode 600, `git -C <client>/repo config core.sshCommand` resolves, `direnv exec <client> env` shows `WORKSTATION_CLIENT`.
- Uninstall leaves client directories intact and removes blocks, cron line and hook.
- Tools: install into a temp `BIN_DIR`, check `--version`, check the "checksum ok" line (or the documented warning).
- Linux has not been tested. Run the above in an `ubuntu:24.04` container (it needs `cron`, `curl`, `unzip`, `git`, `jq`) before relying on it. The awscli installer has not been run on either OS.

The sandbox used during development blocks some hosts; tool tests need `github.com` (and `objects.githubusercontent.com`), `dl.k8s.io`, `get.helm.sh`, `releases.hashicorp.com`, `awscli.amazonaws.com`.

## 10. Pitfalls learned

- `errexit` is ignored inside an `if` condition and a `&&`/`||` chain. To isolate a failing step use `set +e; ( set -e; … ); rc=$?; set -e`.
- Under `set -e`, a function whose last command is a failed `[ … ] && …` returns non-zero; end such functions with an explicit `return 0` or use `if`.
- `block_insert` must always re-append at the end of the file (gitconfig ordering). Do not add other global git writes after it in `setup_git`.
- Git's `includeIf "gitdir:"` compares physical paths; symlinked roots need both forms. It only applies inside a repository.
- cron has no `PATH`; `watch.sh` sets its own and must not assume `BIN_DIR` tools exist when called with a minimal environment.
- macOS TCC applies to cron reading `~/Documents`, including the script itself if the project lives there.
- `flock`, GNU `sed -i` without a suffix, `readlink -f`, `date -d` and `find -printf` do not exist or differ on macOS. Use portable forms (`sed -i.bak`, `cd -P && pwd`, `mkdir` locks).
- `direnv allow` only for files the tool generated; never auto-trust a user's `.envrc`.
- AWS CLI SSO/CLI token caches cannot be relocated by an environment variable; do not claim otherwise.
- Paths with whitespace are rejected up front because they appear unquoted in generated Git config and cron.

## 11. Known gaps and ideas

- Linux and awscli installers untested; direnv, age and awscli (Linux) have no upstream checksums.
- Adopted clients do not receive `core.sshCommand`, the ssh wrapper or agent-CLI isolation.
- `gh auth setup-git` run after deploy re-adds global helpers after the include; re-run deploy to repair. A watcher check could do this automatically.
- No `add-client` / `status` CLI, desktop notification, or zsh support (all deliberately out of scope).
- Not segregated: Docker daemon, browsers, Slack, 1Password, `~/.terraform.d`, AWS token caches.
- Tool updates are manual (`--update-tools`), not scheduled.
