# Backlog

Open work for the kit, in priority order. Each entry states the problem, the proposed change and
testable acceptance criteria. Notes record upstream behavior the fix depends on; **verified**
means checked against upstream source or documentation, otherwise confirm during implementation.

Priorities:

- **P0**: cross-client credential or state leak in the default configuration.
- **P1**: leak that needs a specific precondition (an exported variable, a login mode), or a
  reliability or integrity gap that silently weakens segregation.
- **P2**: optional isolation, convenience or maintenance.

Template changes reach **new** clients only. Scaffolding and adoption create missing files and
never rewrite existing ones (`lib/scaffold.sh` `_install_tpl`), so every template fix below also
needs the verify and migrate work in [P1-4](#p1-4-verify-and-migrate-existing-clients) to reach
existing clients.

## P0

### P0-1. Keep registry logins in the client (Docker and Helm)

**Problem.** The client `DOCKER_CONFIG` file has no auth settings. With none, the Docker CLI
auto-selects the platform's native credential helper (`osxkeychain` on macOS) when it is on
`PATH`, so `docker login` inside a client writes to a store every client shares, keyed only by
registry host. Helm's per-client `registry/config.json` (via `HELM_CONFIG_HOME`) behaves the same
through oras-go and also falls back to the Docker store. The kit does not create a Helm registry
file at all. An inherited `DOCKER_AUTH_CONFIG` outranks the config file.

**Proposal.** Seed both files with a placeholder `auths` entry for a dummy host, for example
`{"auths":{"placeholder.example.invalid":{}}}`: `templates/client/docker-config.json`, plus a new
`templates/client/helm-registry-config.json` installed at
`.workstation/helm/config/registry/config.json` (mode 600, private directory). Scrub
`DOCKER_AUTH_CONFIG` in `.envrc` (see [P1-3](#p1-3-one-ordered-environment-contract)).

**Acceptance.**

- A new client has both files, each with a non-empty `auths` map, mode 600.
- With stub `docker-credential-osxkeychain` / `docker-credential-desktop` first on `PATH` that
  log each call, `docker login` and `helm registry login` against a local test registry never call
  them and the credential lands in the client file. Skip when no daemon or registry is available.
- With users `a` and `b`: client A logs in as `a`, client B as `b`, A pulls; the registry log
  shows `a` for A's pull. Run once for an image and once for an OCI chart.
- Logout keeps the placeholder. An outer `DOCKER_AUTH_CONFIG` is absent inside a client.
- Verify ([P1-4](#p1-4-verify-and-migrate-existing-clients)) flags any client file containing
  `credsStore` or `credHelpers`.

**Notes.**

- A non-empty `auths` map makes Docker's `ContainsAuth()` and oras-go's `IsAuthConfigured()` true,
  which skips detection. `"credsStore": ""` does not work; an empty value counts as unset
  (**verified**, docker/cli `cli/config`, oras-go v2.6.2 `credentials/store.go`). This relies on
  CLI internals, hence the test.
- Both CLIs write a detected store back into the file on the first successful login
  (`credsStore: osxkeychain`). A client that already logged in needs that entry removed, after
  moving its credentials, during migration. Explicit `credsStore`/`credHelpers` still win over the
  placeholder.
- Helm's fallback to the Docker store honors `DOCKER_CONFIG`, so it stays inside the client once
  the Docker file is fixed. `helm registry logout` with a Docker credential present leaves the
  client authenticated through that fallback; document it as expected.
- Native-store auto-detection also exists on Linux (`secretservice`, `pass`); not re-verified.

### P0-2. Claude session hook must restore the pre-client environment

**Problem.** `hooks/direnv-session-env.sh` removes the inherited `DIRENV_DIFF` before running
`direnv export`. A Claude session that starts in client A and then works in client B, or outside
any client, keeps A's variables (`KUBECONFIG`, `GH_CONFIG_DIR`, private env-file values). The
baseline is not lost before the hook runs: Claude's env scrub keeps `DIRENV_*`, and the hook itself
discards it.

**Proposal.** Unload with the inherited direnv state first, restoring the baseline, then load the
project directory. Alternative if that proves unreliable: refuse to export when the inherited
client differs from the project's client, and tell the user to start a new session.

**Acceptance.** With real direnv and a fixture `XDG_DATA_HOME`: outside → A → B → outside. A's
variables and its private env-file values are absent in B and outside; inherited outside values
return exactly.

## P1

### P1-1. GitHub credentials come only from the client

**Problem.** The client Git helper calls `gh auth git-credential` only when the client's
`hosts.yml` is non-empty, which closes the empty-client case. A `hosts.yml` that names a user
without a token of its own still reaches gh's shared secure-storage fallback: with default storage
gh keeps tokens in the OS keyring under `gh:<host>` keyed by username, plus an **unkeyed** "active"
entry holding whichever account was activated last anywhere on the machine, and `ActiveToken`
falls back to it. `gh auth token` in an unconfigured client reaches the same fallback.

**Proposal (decided: direct helper reading `hosts.yml`).** Each client keeps its gh token in its
own `hosts.yml` (`gh auth login --insecure-storage`), and a kit script,
`bin/gh-git-credential.sh <client-dir> <action>`, replaces `gh auth git-credential` as the client's
github.com helper: `helper = !{{KIT}}/bin/gh-git-credential.sh {{DIR}}`. For `get` it prints
`username=x-access-token` and the single host-level `oauth_token` from the client's `hosts.yml`;
it never runs gh, so neither the keyring nor inherited token variables can be reached.
`store`/`erase` are no-ops. It accepts only the layout gh writes (4-space indentation, exactly one
`github.com:` header, exactly one host-level `oauth_token:` with a `[A-Za-z0-9_]+` value, no tabs)
and returns nothing for anything else, so a gh format change fails closed (Git prompts or fails)
rather than using another account. One login per client serves both gh and Git. One script path
(`{{KIT}}`) is added to the paths covered by the safe-character rule.

Rejected alternative: a per-client Git `credential-store` file holding a separate personal access
token (no parser, but two credentials per client to log in and rotate).

Roll-out: keep the current guarded helper until a client has migrated, since the direct helper
returns nothing for a client whose token is still in the keyring. Migrate per client with the
operator workflow below, then switch that client's helper (via
[P1-4](#p1-4-verify-and-migrate-existing-clients) migrate). New clients get the direct helper.

Documented operator workflow in the User Guide: inventory every gh account per host
(inactive ones included, and the global login outside clients); log out first; re-login with
`gh auth login --insecure-storage --expiring=false`, falling back to `--with-token
--insecure-storage` with a non-expiring token; decline gh's "Authenticate Git" prompt; then
optionally remove `gh:*` keyring items once no login anywhere uses secure storage.

**Acceptance.**

- Offline fixtures (direct helper): a host-level token is returned, also under a quoted
  `"github.com":` key, with CRLF line endings, trailing comments and `github_pat_` format. Nothing
  is returned for: no file, empty file, token only under `users:`, token for another host, empty
  or quoted-empty value, comment-only value, commented-out token, `refreshable_oauth_token:`,
  `github.com:other:` header, duplicate `oauth_token` lines (either order), duplicate host
  blocks, token text inside a block scalar, any tab, flow style, or a request for another host.
- gh is never invoked for `get`; sentinel `GH_TOKEN`/`GITHUB_TOKEN`/`GH_ENTERPRISE_TOKEN`/
  `GITHUB_ENTERPRISE_TOKEN` exported outside the client never appear in output.
- `git credential fill` runs with `GIT_TERMINAL_PROMPT=0` and `GIT_ASKPASS=` in every test.
- Verify reports the token source per client (config file vs keyring).
- Operator check: in an empty `GH_CONFIG_DIR`, `gh auth git-credential get` returns nothing once
  the keyring cleanup is done.

**Notes (verified against gh 2.103.3 and go-gh v2.17.0 source).**

- go-gh discards a `hosts.yml` read or parse error and treats it as "no token", so any guard that
  validates the file and then calls gh can still reach the keyring. Duplicate keys resolve to the
  **first** match.
- `gh config get -h github.com oauth_token` calls `ActiveToken` and falls back to the keyring;
  never use it as the token source.
- `--insecure-storage` login does not delete an existing per-user keyring entry; activation then
  copies the old keyring token into the unkeyed slot and removes the host-level token from
  `hosts.yml`. Hence log out first.
- Keyring entries are keyed by username only: logging out removes that username's credential for
  every client and the global login that share it.
- Refreshable credentials (`gh:_refreshable:<host>`) have no host-level copy; the direct helper
  rejects them.
- An inherited `GH_HOST` lets ordinary gh commands pass the empty-config auth gate; the template
  already unsets it.

### P1-2. Detect global Git helpers added after deploy

**Problem.** `deploy.sh` removes global `credential.https://github.com.helper` and
`gist.github.com` helpers and appends the kit include last. A later `gh auth setup-git`, or
accepting Git setup during a `gh auth login` run **outside** a client, adds a global gh helper
after the include. An empty client then falls through its guarded helper to the unguarded global
one. Nothing detects this between deploys.

**Proposal.** Check in verify ([P1-4](#p1-4-verify-and-migrate-existing-clients)) and in the
watcher; optionally `log_status` from `.envrc` when a global gh helper is present. Repair stays
explicit (re-run deploy).

**Acceptance.** A fixture appends a synthetic global helper after deploy; verify and the watcher
report it; after repair an empty client receives no credential and unrelated Git settings are
intact.

### P1-3. One ordered environment contract

**Problem.** `.envrc` scrubs fixed lists for AWS, Azure/ARM, GitHub and `OPENAI_*`/`CODEX_*`.
Every other override exported in the outer shell reaches every client, and the `OPENAI_*` scrub
runs late, next to the private env-file load.

**Proposal.** One contract, in this order, documented in the Developer Guide:

1. **Scrub** inherited overrides in one block at the top.
2. **Export** managed values (`*_CONFIG_DIR`, `KUBECONFIG`, `DOCKER_CONFIG`, ...).
3. **Load** private files (`.workstation/openai/env`, optionally a generic `.workstation/env`;
   mode 600 in a 700 directory) and warn with `log_status` when one overrides a managed path.

Never scrub `DIRENV_*`, `WORKSTATION_*`, `PATH`, `HOME`, `TMPDIR`, or Git operation state
(`GIT_DIR`, `GIT_WORK_TREE`).

**Delivery (decided): a kit library.** Each `.envrc` calls `source_env "{{KIT}}/lib/envrc.sh"`
first, so later scrub fixes reach every client without editing its `.envrc`. Existing clients
need that one line added once (via [P1-4](#p1-4-verify-and-migrate-existing-clients) migrate,
diff shown, user approves). Consequences to handle:

- `direnv allow` approves only the `.envrc` text, not files it sources. A kit update therefore
  changes every client's environment without re-approval: the kit checkout becomes trusted code
  for all clients (it already is for deploy, the shell hook and the Claude hook). Verify checks
  that the kit files are owned by the user and not group- or world-writable, and reports the kit
  commit.
- If the kit path is missing, the `.envrc` must stop with a clear error, not continue unscrubbed.
- direnv watches sourced files, so a kit update reloads open client shells on their next prompt.

| Group | Variables |
|---|---|
| Claude Code | `ANTHROPIC_*`, `CLAUDE_CODE_OAUTH_TOKEN`, `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX`, `CLAUDE_CODE_USE_FOUNDRY` |
| Git | `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_SYSTEM`, `GIT_CONFIG_NOSYSTEM`, `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_*`, `GIT_CONFIG_VALUE_*`, `GIT_CONFIG_PARAMETERS`, `GIT_SSH_COMMAND`, `GIT_SSH`, `GIT_ASKPASS`, `GIT_AUTHOR_*`, `GIT_COMMITTER_*` |
| Terraform | `TF_VAR_*`, `TF_TOKEN_*`, `TF_DATA_DIR`, `TF_CLI_ARGS`, `TF_CLI_ARGS_*`, `TF_WORKSPACE` |
| pip | `PIP_INDEX_URL`, `PIP_EXTRA_INDEX_URL`, `PIP_TRUSTED_HOST` |
| npm | `NPM_CONFIG_*`, `npm_config_*` |
| uv | `UV_INDEX*`, `UV_DEFAULT_INDEX`, `UV_INDEX_URL`, `UV_EXTRA_INDEX_URL`, `UV_KEYRING_PROVIDER`; export a client `UV_CREDENTIALS_DIR` |
| Helm | `HELM_KUBETOKEN`, `HELM_KUBEAPISERVER`, `HELM_KUBECONTEXT`, `HELM_KUBEASUSER`, `HELM_NAMESPACE`, `HELM_REGISTRY_CONFIG` |
| SOPS | `SOPS_AGE_KEY`, `SOPS_AGE_KEY_CMD`, `SOPS_AGE_SSH_PRIVATE_KEY_FILE`, `SOPS_AGE_SSH_PRIVATE_KEY_CMD` |
| Docker | `DOCKER_HOST`, `DOCKER_CONTEXT`, `DOCKER_AUTH_CONFIG`, `DOCKER_CERT_PATH`, `DOCKER_TLS`, `DOCKER_TLS_VERIFY` |
| Telemetry | `DD_*`, `DATADOG_*` |
| netrc | export `NETRC` pointing at a private, possibly empty `.workstation/netrc` (the file must exist) |

**Acceptance.**

- Transition test (outside → A → B → outside) with a sentinel for every group: none visible
  inside A or B; the outside environment is restored exactly, including scrubbed variables.
- Managed exports win over matching prefixes (`NPM_CONFIG_USERCONFIG`, `PIP_CONFIG_FILE`,
  `TF_CLI_CONFIG_FILE`, Helm and SOPS exports), which holds only because scrub runs first.
- A private file overriding `KUBECONFIG` produces a `log_status` warning.
- Runs under Bash 3.2 (`compgen -e` and `case`, as the existing loop does).

**Notes.**

- `CLAUDE_CODE_USE_*` with the client's cloud environment active bills that client's account.
  Gateway settings such as `ANTHROPIC_BASE_URL` are cleared too; a client that needs one sets it
  in its private file.
- SOPS always also reads `$HOME/.ssh/id_ed25519`, `$HOME/.ssh/id_rsa` and the default user age
  file, whatever the environment says (**verified**, sops v3.13.3 `age/keysource.go`). Keep global
  age/SSH keys out of client recipients; this is a documented limitation, not a fix.
- After scrubbing `DOCKER_HOST`/`DOCKER_CONTEXT` a client uses the `default` context, because the
  client `DOCKER_CONFIG` holds no contexts. That can differ from the daemon used outside (for
  example a Colima context). Document setting `DOCKER_HOST` in the client's private file; the kit
  does not manage daemon choice.
- `NETRC` support depends on the consumer: libcurl honors it from 8.16.0; older curl builds do
  not. uv falls back to `~/.netrc` when the `NETRC` file is missing. Keep `~/.netrc` empty for
  older consumers; verify warns when it exists.

### P1-4. Verify and migrate existing clients

**Problem.** Existing clients never receive template fixes. There is no way to see which clients
lack a fix, and manual migration is error-prone.

**Proposal.**

- `deploy.sh --verify`: read-only. Per client, report drift from current templates and unsafe
  state: guarded GitHub helper, `GH_HOST` unset, registry placeholders and stray
  `credsStore`/`credHelpers`, directory/file modes 700/600, gh token source, global gh helpers,
  `~/.netrc` present, and (macOS) `gh:*` keyring items. Add a template version stamp to generated
  files so staleness is detectable. Exit non-zero on any leak-class finding.
- `deploy.sh --migrate`: opt-in, with backups. Apply semantic, idempotent patches to non-`.envrc`
  files (Git helper via `git config --file`, JSON via `jq` merge, missing new templates). For
  `.envrc`, print the proposed diff only; never edit or auto-approve it.

**Acceptance.** A fixture client built from old templates is reported with one line per finding
and verify writes nothing; a current client reports ok. Migrate twice gives no second change,
unrelated settings survive, a backup exists, symlinks are refused, `.envrc` is untouched.

### P1-5. Deploy fails visibly when requested tools fail

**Problem.** `lib/tools.sh` collects install failures, warns and returns 0, so deploy reports
success with tools missing. A missing `direnv` means the shell hook is skipped and every client
silently runs on global config. Unknown tool names are only skipped.

**Proposal.** Finish the remaining steps, then exit non-zero with a summary naming each failed or
unknown tool. Treat a missing `direnv` after the tools step as a hard error.

**Acceptance.** Stub tests cover latest-version lookup failure, installer failure, unknown tool,
mixed results, success and dry run. Failed tools get no lock entry; deploy exits non-zero and
names them.

### P1-6. Installer integrity policy

**Problem.** Pins and checksum verification exist, but a missing checksum only warns
(`REQUIRE_CHECKSUMS=0`) and tools install latest by default. Same-origin checksums do not protect
against a compromised release. direnv runs on every `cd`.

**Proposal.** Allow per-tool, per-platform SHA-256 pins in `versions.conf` that take precedence
over published checksum files. Default `REQUIRE_CHECKSUMS=1` with explicit, listed exemptions
(awscli on Linux, azcli via PyPI). Consider pinning direnv and age by default.

**Acceptance.** A mismatch against a pin aborts that tool; with `REQUIRE_CHECKSUMS=1` and neither
pin nor published sum, the tool is refused unless exempted; exemptions are printed; a rejected
download never becomes an installed binary.

### P1-7. Kubernetes login caches (when a caching login mode is used)

**Problem.** kubelogin keeps tokens in `~/.kube/cache/kubelogin` by default, shared by every
client. In `azurecli` mode it keeps no cache of its own and uses the already-segregated Azure CLI
state; device-code, interactive and service-principal modes cache tokens.

**Proposal.** Document supported login modes. For caching modes, point the cache at the client:
`--cache-dir <client>/.kube/cache` in the kubeconfig `exec` args (`--token-cache-dir` is
deprecated) or `KUBECACHEDIR` where supported. Version support is unverified; confirm first.

**Acceptance.** Fixture kubeconfigs for two clients show distinct cache paths and keep their
existing `exec` args.

### P1-8. Test runner, lifecycle coverage and Linux validation

**Problem.** There is no single runner for `tests/`. Missing coverage: watcher rules (baseline,
`ADOPT_DIRS`, `MIN_AGE_MIN`, exclusions, symlinks), `~/.gitconfig` include ordering after a
simulated `gh auth setup-git`, and full uninstall. Linux has never been run.

**Proposal.** Add `tests/run.sh`: runs every offline suite with an isolated `HOME` and XDG
directories and exits non-zero on any failure. It excludes the two operator authentication
harnesses (`agy-account-isolation.sh`, `agy-login-isolation.sh`). Add the missing suites. Run the
deploy checklist and `tests/run.sh` in an `ubuntu:24.04` container.

**Acceptance.** Each watcher rule has a positive and a negative case; uninstall leaves unrelated
crontab and dotfile content intact; the Linux run passes or its failures are filed.

## P2

### P2-1. Atomic azcli reinstall

`tool_azcli_install` deletes the working venv before building the new one; a failed `pip install`
leaves no `az`. Build into a versioned directory, switch a symlink only after the install and an
`az --version` check succeed, then remove old versions. Do not move a venv (its scripts carry
absolute shebangs). Also check for python3 >= 3.10 before deleting anything. AC: a forced pip
failure leaves the previous `az` working; uninstall removes every version.

### P2-2. Browser launcher explains suppressed launches

With browser isolation on and no profile set, `browser-client.sh default` opens nothing and exits
0. Exit 0 is deliberate: a non-zero exit makes Python `webbrowser` and similar callers fall back to
the shared default browser. Print the received URL and the reason on stderr, and have verify
report unset, missing or ambiguous profiles. AC: with the profile unset, the URL appears on
stderr, no browser launches, exit is 0; explicit `chrome`/`firefox` calls still fail non-zero.

### P2-3. Opt-in Git credentials for other HTTPS hosts

Inside a client, HTTPS remotes other than GitHub (Azure DevOps, GitLab, Bitbucket) have no helper,
so Git prompts every time, which tempts users to re-add a shared global helper. Add commented
per-host blocks to `templates/client/git-config`:
`[credential "https://<host>"]`, `helper =`, `helper = store --file {{DIR}}/.workstation/git/credentials`.
Document that the file is plaintext (mode 600). AC: an uncommented block stores and reads back via
`git credential` in a fixture, file mode 600, other clients unaffected.

### P2-4. Opt-in SSH commit signing

Commented `gpg.format = ssh`, `user.signingkey = {{DIR}}/.workstation/ssh/id_ed25519` and
`commit.gpgsign = true` in the client Git template. Use the **private** key path: a `.pub` path
needs the key in `ssh-agent`, which the kit does not arrange. Document registering the key as a
signing key on the Git host, and that the commit email must match the host account. AC: a fixture
commit verifies against an allowed-signers file.

### P2-5. Per-client histories and tool state

Only shell history is per client. Add `.workstation/history/` (700, files 600) and exports for
`LESSHISTFILE`, `NODE_REPL_HISTORY`, `PYTHON_HISTORY` (Python 3.13+), `PSQL_HISTORY`,
`MYSQL_HISTFILE`; a client kubectl discovery cache; and an executable `k9s` launcher that sets
`XDG_*` for the child only (k9s keeps logs and screen dumps outside `K9S_CONFIG_DIR`). Never set
global `XDG_*` in `.envrc`: direnv keeps its approval store under `XDG_DATA_HOME`. Caveats: a
`HISTFILE` set in a shared `~/.psqlrc` overrides `PSQL_HISTORY` (set a client `PSQLRC`);
`PGPASSFILE` must be mode 600; long-running processes keep the file they started with. AC: inside
a client each variable points under the client; `XDG_DATA_HOME` is unchanged.

### P2-6. Opt-in editor isolation

VS Code profiles separate settings and extensions but not signed-in accounts or extension secrets.
Add `ENABLE_EDITOR_ISOLATION` (default 0) with an **executable** `shims/editor/code` calling a
`bin/code-client.sh` that validates the client path and runs `code` with
`--user-data-dir <client>/.workstation/vscode/data` and
`--extensions-dir <client>/.workstation/vscode/extensions`. A shell function would be invisible to
`EDITOR`/`VISUAL` callers such as Git. Opening VS Code from the Dock still uses shared data. AC: a
stub `code` receives client directories via `PATH`, `EDITOR` and `VISUAL`; outside a client the
shim refuses.

### P2-7. Opt-in Docker daemon per client

The Docker daemon, images, volumes and build cache are shared. Add `ENABLE_DOCKER_ISOLATION`
(default 0): one Colima profile per client with a namespaced name (for example `ws-<client>`), a
resolved rather than hard-coded socket (honor `COLIMA_HOME`), and mounts limited to the client
directory, since Colima mounts the whole home directory by default. Cost: RAM and disk per VM,
images pulled per client. AC: fixtures show unique names, correct socket selection, no whole-home
mount and no implicit VM start.

### P2-8. Installer ownership

`lib/tools.sh` (deploy) and `tools/setup-workstation.sh` install overlapping tools (direnv, gh,
kubectl, helm, ...) with separate version and removal tracking. Decide which owns each tool, or
document the split and how to avoid both managing the same binary. AC: one documented install
route per scenario.

## Done

Keep these covered by regression tests rather than reopening them:

- Guarded GitHub Git helper: no credential when the client has no gh login; inherited token
  variables removed for the gh call (`templates/client/git-config`, `tests/gh-credential-guard.sh`).
- `GH_HOST` and GitHub token variables unset in `.envrc`.
- AWS, Azure/ARM, `OPENAI_*` and `CODEX_*` scrubs in `.envrc`.
- Path-character allowlist for `CLIENT_ROOT`, `BIN_DIR`, the kit path, client names and the
  resolved gh path (`lib/common.sh`, `tests/path-validation.sh`).
- `tests/agy-isolation.sh` keeps the rendered guard instead of replacing it.
- The kit is under version control; `*.bak.*` is gitignored.

## Not doing

- **Per-client pass/GPG credential helper for registries.** Heavy setup for little gain over the
  placeholder and mode-600 client files.
- **Running `aws` with a client `HOME` to split the SSO cache.** Terraform's AWS provider and
  boto3 still read `~/.aws/sso/cache`, so SSO would break for them. Client-prefixed sso-session
  names remain the better trade-off.
- **Overriding `HOME` for the whole client.** Breaks the direnv approval store, the global Git
  include, browser profile lookup, new login shells and per-user tool installs. Process-scoped
  `HOME` for a single launcher remains acceptable.
- **Pre-emptive gcloud, glab, Vault and GnuPG support.** Add when a client needs it:
  `CLOUDSDK_CONFIG` plus an explicit client `GOOGLE_APPLICATION_CREDENTIALS` (Go's oauth2 reads
  `$HOME/.config/gcloud` regardless), `GLAB_CONFIG_DIR`, a `VAULT_*` scrub with a client token
  helper, `GNUPGHOME`.
- **Kit-managed Docker daemon selection when isolation is off.** A usability concern, not
  isolation; documented under P1-3 instead.
