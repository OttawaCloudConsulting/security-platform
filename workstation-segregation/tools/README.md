# Workstation tools installer

An OS-level workstation tool installer for Ubuntu and macOS. It installs, pins, upgrades and removes developer tools in selectable groups, and records what it did. It is a sibling of `../deploy.sh`.

**Status:** all 13 groups are implemented and stub-tested. Real Ubuntu and macOS validation is still pending.

## Quick start

Run from your project directory (the one holding `.env`):

```bash
/path/to/tools/setup-workstation.sh --dry-run      # print the plan, change nothing
/path/to/tools/setup-workstation.sh                # real run (installs base)
/path/to/tools/setup-workstation.sh --groups base,github,terraform
/path/to/tools/setup-workstation.sh --yes          # confirm removals without a prompt
```

- Groups can also come from `.env` in the current directory, read as data and never sourced: `TOOL_GROUPS=base,github`. `--groups LIST` replaces it; `--env-file PATH` points at another file.
- `base` is always included, and dependencies are added automatically.
- Exit codes: `0` ok, `1` failure, `2` usage error, `75` restart needed. On 75 (Bash installed or upgraded, or login shell changed), open a new terminal and rerun.
- Other options: `--requested-file PATH`, `--installed-file PATH`, `--tool-version TOOL=VER` (repeatable, persisted), `--allow-base-removal`.

## Groups

| Group | Depends on | Key tools |
|---|---|---|
| `base` | none | git, curl, wget, jq, yq, ripgrep, fzf, tmux, direnv, starship, python3, uv, Codex, Claude Code, Gemini CLI |
| `containers` | none | docker-cli, Docker Engine (Colima on macOS), compose, buildx |
| `aws` | containers | awscli, session-manager-plugin, aws-cdk, aws-sam, docker |
| `kubernetes` | containers | kubectl, helm, k9s, kind, eksctl, kustomize, stern, kubectx, helmfile |
| `argocd` | kubernetes | argocd-cli |
| `terraform` | none | terraform, tfenv |
| `terragrunt` | terraform | terragrunt |
| `github` | none | gh |
| `ansible` | none | ansible |
| `go` | none | go |
| `database-postgres` | none | psql (client only) |
| `database-mysql` | none | mysql-client (client only) |
| `database-redis` | none | redis-cli (client only) |

The catalog lives in `scripts/common/catalog/groups.tsv` and `tools.tsv`. Deselecting a group never removes tools.

## Where things install

- `~/.local/bin`: release binaries (kubectl, helm, terragrunt, gh, ...) and symlinks.
- `~/.local/share/tfenv`: tfenv clone (Terraform versions live under it).
- `~/.local/share/go`: the Go tarball, with `go` and `gofmt` linked into `~/.local/bin`.
- `~/.local/share/workstation-tools`: private data, including a checksum-verified bootstrap `jq`.
- apt on Ubuntu and Homebrew on macOS for OS packages.

## Requested and installed files

- `.workstation-tools-requested.json` (project directory): per-tool `latest`, an exact version to pin, or `remove` / `delete` (synonyms) to request removal.
  ```json
  { "schema_version": 1, "tools": { "terraform": "1.9.8", "k9s": "remove" } }
  ```
- `~/.workstation-tools-installed.json`: a record of what was installed (version, path, source, integrity, owner, status). It is a record, not proof; every run inspects the machine.

Removal notes: `base` tools need `--allow-base-removal` on every run. These are never removable: jq, yq, direnv, starship, ca-certificates, curl, tar, gzip, unzip, git. Only installs made by this installer are removed.

## Integrity

Downloads are checked against upstream SHA-256 (SHA-512 for Antigravity); a mismatch fails the tool. Reported statuses:

- `verified`: upstream checksum matched (GitHub-release tools, kubectl, helm, terragrunt, gh, Go).
- `provider`: verified by another provider (tfenv, Terraform).
- `package-manager`: ansible.
- `unverified`: no published checksum (direnv, Homebrew and nvm installers).

## Layout

```
setup-workstation.sh        entry point
scripts/
  common/                   shared logic: configuration.sh, engine.sh, plan.sh, state.sh,
                            handlers.sh, catalog.sh, catalog/{groups,tools}.tsv
  orchestrator/             prerequisites: common.sh, ubuntu.sh, macos.sh
  ubuntu/groups/            per-group installers (Ubuntu)
  macos/groups/             per-group installers (macOS)
tests/                      run.sh plus test-*.sh, helpers.sh, fixtures/
docs/                       USER-GUIDE.md, DEVELOPER-GUIDE.md
```

## Tests

```bash
tests/run.sh
```

## Further reading

- [docs/USER-GUIDE.md](docs/USER-GUIDE.md)
- [docs/DEVELOPER-GUIDE.md](docs/DEVELOPER-GUIDE.md)
- [REQUIREMENTS.md](REQUIREMENTS.md)
- [TOOL-GROUPS-CONSOLIDATED.md](TOOL-GROUPS-CONSOLIDATED.md)
- [plan.md](plan.md)
