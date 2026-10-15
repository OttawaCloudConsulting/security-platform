# Consolidated Tool Groups

Group identifiers are used by both `.env` configuration and command-line arguments. Always include `base`. Include other groups when selected by the project or required by another selected group. Resolve dependencies recursively and install each shared tool only once.

All former `base-*` groups are combined into `base`, all `aws-*` groups into `aws`, and all `kubernetes-*` groups into `kubernetes`. Database groups remain separate.

## Orchestrator prerequisites

These are installed by the entry point before any group is processed. They belong to no group, are not recorded in either dotfile, cannot be pinned, and are never removed.

- Bash (latest; upgraded on every run)
- nvm with Node.js LTS and the latest npm (updated on every run; never removed)
- Homebrew (macOS only; updated on every run)
- Xcode Command Line Tools (macOS only; installed when absent, not updated by the installer)

Node.js tooling (for example AWS CDK) uses the nvm-managed Node.js.

## base

Additional group dependencies: none. Resolve any prerequisites required by the chosen AI CLI installation methods.

`base` tools are always retained. A removal flag on a `base` tool is honored only with `--allow-base-removal`. jq, yq, direnv, starship, CA certificates, curl, tar, gzip, unzip, and Git are never removed by the installer.

- CA certificates
- curl
- wget
- zip
- unzip
- tar
- gzip
- Git
- OpenSSH client
- make and native compiler toolchain: `build-essential` on Ubuntu; on macOS, supplied by Xcode Command Line Tools (an orchestrator prerequisite)
- direnv
- starship
- tree
- ripgrep
- fzf
- tmux
- rsync
- dig
- nslookup
- nc
- jq
- yq
- Python 3
- pip3
- uv
- uvx (provided by uv)
- Codex
- Claude Code
- Google Gemini CLI
- Antigravity (AGY) CLI
- [gemini-notebook-mcp-cli](https://github.com/jacob-bd/gemini-notebook-mcp-cli)

## aws

Additional group dependencies: `containers`.

- AWS CLI v2
- AWS Session Manager plugin
- jq
- AWS CDK CLI
- AWS SAM CLI
- Python 3
- Docker

This group includes AWS access, CDK, and SAM tooling. Node.js and npm come from the orchestrator prerequisites; the `containers` dependency supplies the container runtime for local SAM workflows. Select `kubernetes` separately when Kubernetes or EKS work is required.

## kubernetes

Additional group dependencies: `containers`.

- eksctl
- kubectl
- kubectx
- kubens
- kubecolor
- Helm
- k9s
- stern
- jq
- yq
- Kustomize embedded in kubectl
- Standalone Kustomize
- kind
- Docker
- Helmfile

This group includes local cluster tooling and eksctl for EKS management. The `containers` dependency supplies the runtime required by kind. Select `aws` alongside `kubernetes` for AWS CLI access to EKS; on-premises Kubernetes work can select `kubernetes` alone.

## containers

Additional group dependencies: none.

- Docker CLI
- Docker Engine (Ubuntu) or Colima (macOS)
- Docker Compose plugin
- Docker Buildx plugin

## terraform

Additional group dependencies: none.

- Terraform
- tfenv
- jq

Let tfenv manage Terraform versions to avoid competing Terraform installations.

## terragrunt

Additional group dependencies: `terraform`.

- Terragrunt
- Terraform
- tfenv

## github

Additional group dependencies: none.

- GitHub CLI

## argocd

Additional group dependencies: `kubernetes`.

- Argo CD CLI
- kubectl

## ansible

Additional group dependencies: none.

- Ansible
- Python 3
- OpenSSH client
- rsync

## go

Additional group dependencies: none.

- Go

## database-postgres

Additional group dependencies: none.

- PostgreSQL client (`psql`)

## database-mysql

Additional group dependencies: none.

- MySQL client

## database-redis

Additional group dependencies: none.

- Redis client (`redis-cli`)

## Tool dependencies

Tool-level dependencies used to reject removals that would break a remaining selected tool. Group dependencies above are separate.

| Tool | Depends on | Relationship |
|---|---|---|
| uvx | uv | bundled command |
| Kustomize embedded in kubectl | kubectl | bundled command |
| kubens | kubectx | bundled command |
| Docker Compose plugin, Docker Buildx plugin | Docker CLI | CLI plugin |
| Docker | Docker CLI | bundled command |
| Terraform | tfenv | provider-managed |
| pip3 | Python 3 | bundled command |
| gemini-notebook-mcp-cli | uv | runtime |
| dig, nslookup | dnsutils (Ubuntu) | bundled command |
| AWS Session Manager plugin | AWS CLI v2 | plugin |
| AWS CDK CLI | nvm-managed Node.js (orchestrator) | runtime |
| AWS SAM CLI | Python 3, Docker | runtime |
| kind | Docker | runtime |
| kubecolor | kubectl | runtime |
| Helmfile | Helm | runtime |
| Terragrunt | Terraform | runtime |
| Ansible | Python 3 | runtime |

## Machine-readable catalog

`scripts/common/catalog/groups.tsv` and `tools.tsv` are the machine-readable form of this document. `tests/test-catalog-sync.sh` keeps them in sync.

## Selection rules

- With no selection, install only `base`.
- A command-line `--groups` value replaces `TOOL_GROUPS` from the selected `.env` file. Always add `base` and the selected groups' dependencies.
- Reject unknown group identifiers before installation.
- Install dependencies before their dependents and deduplicate tools across all resolved groups.
- Apply operating system and architecture checks to each tool, and reuse suitable existing installations.
- Build tools, Python, data utilities, and networking utilities are supplied by `base`.
- Before processing groups, the orchestrator installs Xcode Command Line Tools (if absent) and updates Homebrew on macOS, then upgrades Bash to latest. If Bash changed, it exits and asks the user to rerun from a new terminal.
- Keep version selection separate from group membership and honor repository version requirements.
- Checkov and shellcheck are managed by the separate linting/security/git-hook workflow and are excluded from these groups.

## Configuration examples

Project `.env` for AWS infrastructure development:

```dotenv
TOOL_GROUPS=aws,terraform,github
```

Project `.env` for on-premises Kubernetes and PostgreSQL work:

```dotenv
TOOL_GROUPS=kubernetes,ansible,database-postgres
```

Proposed command-line interface for the future installer:

```bash
./setup-workstation.sh --env-file .env
./setup-workstation.sh --groups kubernetes,terraform,database-redis
```

Read `.env` as configuration data rather than executing it as shell code. These examples describe group selection; the installer script is not implemented by this document.
