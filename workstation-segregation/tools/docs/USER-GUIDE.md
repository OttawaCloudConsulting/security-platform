# Workstation Tool Installer: User Guide

`setup-workstation.sh` installs and upgrades developer tools on Ubuntu and macOS from group selections, records what it did in two JSON dotfiles, and removes tools you flag for removal. Developers: see [DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md). Normative requirements: [../REQUIREMENTS.md](../REQUIREMENTS.md). Tool lists: [../TOOL-GROUPS-CONSOLIDATED.md](../TOOL-GROUPS-CONSOLIDATED.md).

> **Status:** implemented groups: `base`, `containers`, `aws`, `kubernetes`, `argocd`, `terraform`, `terragrunt`, `github`, `ansible`, `go`, `database-postgres`, `database-mysql`, `database-redis`. The real macOS run has not been verified yet; the Ubuntu 24.04 container run has. Pending Ubuntu field validation: the `mysql-client` package name per release, a real tfenv/Terraform install, tool `--version` parsing, and GitHub API rate limits (kustomize).

## Quick start

```bash
cd your-project
/path/to/tools/setup-workstation.sh --dry-run     # plan only, changes nothing
/path/to/tools/setup-workstation.sh               # install base
```

On a first run that installs or upgrades Bash, or changes your login shell, the script exits with status **75**. Open a new terminal and run it again.

## Choosing groups

- `.env` in the current directory, read as data (never sourced): `TOOL_GROUPS=base,github`
- `--env-file PATH` for another file. An unreadable explicit file is an error.
- `--groups LIST` replaces the `.env` selection.
- `base` is always included. Dependencies are added automatically: `aws` and `kubernetes` pull in `containers`, `argocd` pulls in `kubernetes`, `terragrunt` pulls in `terraform`.
- `database-postgres`, `database-mysql` and `database-redis` install clients only (`psql`, `mysql`, `redis-cli`). Deselecting a group never removes tools.

## Options

| Option | Meaning |
|---|---|
| `--env-file PATH` | project `.env` (default `./.env`) |
| `--groups LIST` | comma-separated groups, replaces `.env` |
| `--requested-file PATH` | requested versions (default `./.workstation-tools-requested.json`) |
| `--installed-file PATH` | installed record (default `~/.workstation-tools-installed.json`) |
| `--tool-version TOOL=VER` | pin a selected tool, persisted (repeatable) |
| `--allow-base-removal` | honor removal flags on `base` tools, this run only |
| `--dry-run` | print the plan, change nothing |
| `--yes` | confirm removals without a prompt |

Exit codes: `0` ok, `1` failure, `2` usage error, `75` restart needed.

## What happens on a run

1. **Prerequisites** (not tools, never recorded or removed): Xcode Command Line Tools and Homebrew on macOS, latest Bash, login shell set to it, nvm with Node.js LTS and latest npm, and a private checksum-verified `jq` under `~/.local/share/workstation-tools/bootstrap/bin`.
2. **Discovery** of every selected tool's `latest` version, pinned tools included.
3. **Probe** of what is actually installed, then a plan table (`reuse`, `install`, `upgrade`, `pin`, `remove`, `conflict`, `blocked`).
4. **Removals**, then **installs** in dependency order. Each result is validated (`--version` or equivalent) and recorded immediately, so one failure does not lose other successes.
5. A summary: requested, latest, previous, target, integrity, result.

A rerun with nothing to change reinstalls nothing.

## Requested versions file

`.workstation-tools-requested.json` in the project:

```json
{ "schema_version": 1, "tools": { "jq": "latest", "terraform": "1.9.8", "k9s": "remove" } }
```

- `latest` stays `latest`; the discovered version is never written here.
- An exact version pins the tool.
- `remove` or `delete` (synonyms) requests removal, even if the group is not selected.
- Orchestrator prerequisites (bash, homebrew, nvm, node, npm) cannot appear here.
- Bundled commands (`uvx`, `pip3` on macOS, `dig`, `nslookup`, ...) cannot be pinned; pin their provider.

## Installed record

`~/.workstation-tools-installed.json` holds, per tool: requested, latest, target, version, path, package_id, source, integrity, `owner` (`workstation-tools` or `external`), `status` (`installed`, `stale`, `failed`, `removed`), os, arch, UTC timestamp. It is a record, not proof: every run inspects the machine.

## Removing tools

Set the tool to `remove` and run with `--yes` (or answer the prompt).

- `base` tools need `--allow-base-removal` on every run.
- Never removed: jq, yq, direnv, starship, ca-certificates, curl, tar, gzip, unzip, git.
- A tool another selected tool depends on is rejected (for example `uv` while `gemini-notebook-mcp-cli` remains; flag them together).
- Only installs made by this installer are removed. Anything else gets: *remove `<path>` manually, then rerun*.
- User data (`~/.aws`, caches, nvm Node versions) is never touched. The flag stays in the file; reruns make no changes.

## Where tools go

- `kubernetes`, `argocd`, `terragrunt`, `github`: release binaries in `~/.local/bin` (kubectl from `dl.k8s.io`, helm from `get.helm.sh`, the rest from GitHub releases). `kubectx` installs `kubens` too.
- `terraform`: `tfenv` is cloned to `~/.local/share/tfenv` with `tfenv` and `terraform` symlinks in `~/.local/bin`; Terraform versions live under the tfenv directory.
- `go`: the official tarball is unpacked to `~/.local/share/go`, with `go` and `gofmt` linked into `~/.local/bin`.
- `ansible`: `uv tool install` with the executables of `ansible-core`.
- `database-*`: apt packages (`postgresql-client`, `mysql-client`, `redis-tools`) on Ubuntu; on macOS Homebrew `libpq` and `mysql-client` (keg-only, linked into `~/.local/bin`) and `redis`.

## Integrity

Release downloads are verified against upstream SHA-256 (or SHA-512 for Antigravity) before use; a mismatch deletes the file and fails the tool. If a published checksum cannot be fetched, the tool fails rather than installing unverified. Tools with no published checksum (direnv, Homebrew and nvm installers) are reported as `unverified`. GitHub-release tools, kubectl, helm, terragrunt, gh and Go (checksum from `go.dev/dl`) are `verified`. `tfenv` has no upstream checksum and Terraform is verified by tfenv itself, so both report `provider`. `ansible` reports `package-manager`. OS packages rely on apt/Homebrew signatures; npm packages on registry integrity.

## Common situations

| You see | Meaning / fix |
|---|---|
| `conflict ... active at /opt/homebrew/bin/x` | Same tool installed elsewhere at a different version. Remove it, rerun. |
| `blocked: dependency X did not complete` | Fix X; dependents then proceed. |
| `removal rejected: ... --allow-base-removal` | Add the flag, or unflag the tool. |
| exit 75 | Open a new terminal, rerun. |
| `another run is in progress` | Wait; a crashed run's lock clears after 5 minutes (`WST_LOCK_STALE_SECS`). |
| `chsh` warning | Login shell not changed (common in containers); change it manually. |

## Known limitations

- Ubuntu `pip3` is the OS package only (PEP 668); `latest` means the newest repository version.
- Antigravity pins must equal `latest` (its manifest lists only the current build).
- `deploy.sh --uninstall` can delete `~/.local/bin` binaries this installer upgraded (jq, yq, direnv, starship).
- Phase 3 decisions: no kubectl/cluster version skew check, no krew, no helm plugins.
- Removing `terraform` or `tfenv` deletes every Terraform version tfenv installed, and `go` removal deletes `~/.local/share/go`.
- kustomize `latest` is read from the unauthenticated GitHub API and can fail when rate limited; pin a version meanwhile.
- Ubuntu `mysql-client` is the apt package for each release and may not exist on every release.
- On macOS the `redis-cli` tool installs the full `redis` formula (including the server).
- Installations are workstation-wide, requests per project: the last run wins.
