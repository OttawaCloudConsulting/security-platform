# Plan: Workstation tool installer — Phase 1 (framework + `base`)

## Context

`workstation-segregation/tools/REQUIREMENTS.md` and `TOOL-GROUPS-CONSOLIDATED.md` now specify an OS-level tool installer that is a sibling of `deploy.sh`. It selects groups from `.env` or the CLI, installs and upgrades tools to `latest` or a pin, verifies downloads, keeps requested and installed JSON dotfiles, and removes tools flagged `remove`/`delete`. Nothing is implemented yet.

Phase 1 delivers:
- the orchestrator;
- the shared engine;
- the tests;
- the `base` group on Ubuntu and macOS.

Later phases add the remaining groups, one at a time, on the same contract.

Decisions already made:
- Code lives in `tools/`.
- The private bootstrap jq is checksum-verified.
- The framework and `base` come first.
- nvm/Node.js/npm move into the orchestrator bootstrap.

This revision folds in the Codex review as triaged by the advisor; see "Codex review disposition" at the end.

## Step 0 — Doc updates (keep docs authoritative)

`REQUIREMENTS.md`:
- **Orchestrator prerequisites:**
  - Add nvm with Node.js LTS and the latest npm, updated every run and never removed.
  - Add the private bootstrap jq at `~/.local/share/workstation-tools/bootstrap/bin/jq`, which is separate from the managed `jq`.
- **Exit codes:**
  - `0` ok.
  - `1` failure.
  - `2` usage.
  - `75` restart needed: Bash was installed or upgraded, or the login shell changed.
- **Dry-run when Bash is older than 5:** print the prerequisite actions only, exit 0, and say that the full plan needs Bash 5.
- **Installed record:** add an `owner` field (`workstation-tools` | `external`) and a `status` (`installed|stale|failed|removed`).
- **Per-tool checksums:** each tool declares `checksum: yes|no`. If upstream publishes a checksum and fetching it fails, the tool fails; it is not reported as unverified.
- **Ubuntu `dnsutils`:** document it as the provider of dig and nslookup.

`TOOL-GROUPS-CONSOLIDATED.md`:
- Move nvm/Node.js/npm into Orchestrator prerequisites and delete the `nodejs` group. Drop it from the `aws` dependencies.
- Remove the Node/npm dependency-table rows and add `dig, nslookup → dnsutils (Ubuntu)`.
- Add a note that `scripts/common/catalog/*.tsv` is the machine-readable form, kept in sync by a test.

## Layout (new, under `tools/`)

```text
tools/
  setup-workstation.sh            # orchestrator, Bash 3.2-safe
  scripts/
    orchestrator/{common.sh,macos.sh,ubuntu.sh}   # 3.2-safe
    common/                       # Bash 5
      main.sh  common.sh(log/run/lock/sudo)  configuration.sh  catalog.sh
      groups.sh  versions.sh  download.sh  state.sh  plan.sh(+removal rules)  engine.sh
      catalog/{groups.tsv,tools.tsv}
    {ubuntu,macos}/groups/base.sh
  tests/{run.sh,helpers.sh,fixtures/platform-fake/,test-*.sh}
```

## Orchestrator (`setup-workstation.sh`, Bash 3.2)

1. **Paths and arguments:**
   - Compute `WST_ROOT="$(cd "$(dirname "$0")" && pwd -P)"` and export `WST_PROJECT_DIR="$PWD"`, which is the default location for `.env` and the requested file.
   - Pre-scan the arguments only for `--dry-run`, `--yes`, and `-h`. Forward all arguments unchanged.
   - Detect macOS, or Ubuntu via `/etc/os-release`, plus the architecture.
2. **Privilege:** set `SUDO=""` when `id -u` is 0, otherwise `sudo`, and run `sudo -v` once. Run only package and `/etc/shells` operations through it. nvm and `~/.local/bin` installs run as the invoking user.
3. **Lock:**
   - Take a `mkdir` lock in `~/.local/state/workstation-tools/lock` before any prerequisite mutation, write the PID, and export the path.
   - Treat the lock as stale only when the PID is dead and the pid file is older than N seconds; a lock with no pid file yet counts as initializing. An `EPERM` from `kill -0` counts as alive.
   - `exec` keeps the PID, so `main.sh` re-arms the EXIT trap on the same lock.
   - Every dotfile read-modify-write happens under this lock.
4. **macOS prerequisites:**
   - **CLT, when `xcode-select -p` fails:**
     - Touch the `installondemand` marker.
     - Pick the newest "Command Line Tools" label from `softwareupdate -l` and run `softwareupdate -i <label>` with a timeout, then remove the marker.
     - Verify that `xcode-select -p` works and that `/usr/bin/git --version` runs.
     - On timeout or failure, fail with "run `xcode-select --install`, then rerun". Never wait indefinitely.
   - **Homebrew:**
     - Install with `NONINTERACTIVE=1` if absent (integrity: unverified, reported).
     - Run `eval "$(<prefix>/bin/brew shellenv)"`, then `brew update`, then export `HOMEBREW_NO_AUTO_UPDATE=1` so targets stay frozen for the rest of the run.
   - **Bash:** `brew install` or `brew upgrade bash`. `BASH5="$(brew --prefix)/bin/bash"`.
5. **Ubuntu prerequisites:**
   - `$SUDO apt-get update`, then install `ca-certificates curl` if missing (both are also managed by `base`).
   - Bash: `apt-get install --only-upgrade bash`. `BASH5=/bin/bash`.
6. **Login shell, checked every run:**
   - Add `$BASH5` to `/etc/shells` if missing.
   - Run `chsh -s "$BASH5" "$USER"` if the login shell differs. If `chsh` fails (for example in a container), warn.
   - Exit 75 with the restart message if Bash changed or the login shell changed.
7. **nvm/Node:**
   - Run nvm's `install.sh` every run; it updates an existing clone to the latest tag (integrity: unverified, reported).
   - Then `nvm install --lts --latest-npm` and `nvm alias default 'lts/*'`. Node tarballs are verified by nvm against SHASUMS256 (integrity: `provider`).
8. **Bootstrap jq:** download the latest release asset and verify it against `sha256sum.txt` (strict). Under dry-run, put it in `$TMPDIR` only.
9. **Hand off to main:** check `"$BASH5" -c '[ "${BASH_VERSINFO[0]}" -ge 5 ]'`, then `exec "$BASH5" "$WST_ROOT/scripts/common/main.sh" "$@"` with `WST_ROOT`, `WST_PROJECT_DIR`, `WST_JQ`, `WST_OS`, `WST_ARCH`, `WST_LOCK`, `DRY_RUN`, and `ASSUME_YES` exported.
10. **Dry-run:** log every prerequisite action and mutate nothing. If Bash is older than 5, stop after the prerequisite report with exit 0.

Reused, by copying and adapting rather than sourcing:
- `lib/common.sh:9-33`: `log/warn/die/run` and the `detect_platform` shape.
- `deploy.sh:75-104`: the `[y/N]` prompt and `--yes` handling.
- `bin/watch.sh:38-45`: the `mkdir` lock idea.

## Engine (Bash 5)

- **configuration.sh:**
  - Parses `.env` line by line as data and reads only `TOOL_GROUPS`. Values are never echoed.
  - Flags: `--env-file`, `--groups`, `--requested-file`, `--installed-file`, repeatable `--tool-version`, `--allow-base-removal`, `--dry-run`, `--yes`.
  - Errors: an unreadable explicit env file exits 1; usage errors exit 2.
- **catalog.sh:**
  - `tools.tsv` columns: `id`, `groups`, `depends`, `relation` (bundled|provider|plugin|runtime), `removal` (never|base|normal), `checksum` (yes|no|n/a).
  - The `never` class holds jq, yq, direnv, starship, ca-certificates, curl, tar, gzip, unzip, and git.
- **groups.sh:**
  - Always adds `base`.
  - Rejects unknown identifiers.
  - Expands dependencies by DFS with cycle detection.
  - Returns a topological order with duplicates removed.
- **versions.sh:** comparison depends on the source:
  - **apt:** `latest` is the policy candidate (R defines it as the newest version from the configured repositories). Keep the full `dpkg` version and compare with `dpkg --compare-versions`.
  - **brew:** the current formula version, compared by string equality. Any other exact pin is rejected as unavailable.
  - **Release binaries:** `gh_latest_tag`, the redirect technique from `lib/tools.sh:16-20`, normalized per tool (`v`, `jq-`), and compared with `sort -V`.
- **download.sh:**
  - Ports `sha256_of`, `checksum_lookup`, and `verify_download` from `lib/tools.sh:22-61`.
  - Statuses are distinct: `verified`, `unverified` (the tool declared `checksum: no`), `fetch-failed`, `malformed`, `mismatch`. Only `verified` and `unverified` succeed.
  - On failure the artifact is deleted. Nothing downloaded runs before verification.
  - Supports SHA-256 and `pkgutil --check-signature` only.
- **state.sh:**
  - Reads and writes the JSON with `$WST_JQ`. Writes go to a temp file in the same directory followed by `mv`.
  - Validates the requested file: `schema_version`; values `latest`, exact version, `remove`, `delete`; no orchestrator prerequisites; no conflicting provider/bundled pins (uv/uvx, python3/pip3, dnsutils/dig/nslookup); `--tool-version` against a remove flag is an error.
  - Persists changes only after validation passes, and never under dry-run.
  - Installed record:
    - `requested`, `latest`, `target`, `version`, `path`, `package_id`;
    - `source`, `integrity`, `owner`, `status`;
    - `os`, `arch`, `verified_at` (UTC).
  - A failed update marks the existing record `stale` or `failed`.
- **plan.sh (including the removal rules):**
  - **Discovery:** freeze `latest` for every selected non-removal tool, including pinned ones, before any probe. A discovery failure fails that tool only and blocks its dependents. Removals still proceed.
  - **Probe** each tool, then classify it as `reuse|install|upgrade|pin|remove|absent|reject|conflict`.
  - **Removal rules, in order:**
    1. unknown identifier;
    2. orchestrator prerequisite;
    3. `never`;
    4. `base` without `--allow-base-removal`;
    5. hard dependency of a remaining tool (a provider removed together with all its bundled tools is allowed);
    6. ownership: the record must be `owner: workstation-tools` and must match the probe. Otherwise the error is "remove `<path>` manually, then rerun to let the installer manage it" and the exit is non-zero.

    Every rejection is collected before any change.
  - **Confirmation:** any removal needs confirmation, or `--yes` when there is no TTY.
  - **Dry-run:** stop after printing the plan table.
- **engine.sh:**
  - **Handlers:** source `scripts/$WST_OS/groups/<group>.sh` for the resolved groups, plus the first-group script of every removal-flagged tool, whatever the selection. Tests point `WST_PLATFORM_DIR` at the fake platform.
  - **Order:** removals in reverse topological order, then installs in topological order.
  - **Isolation:** each tool runs in `( set -e; tool_x_install "$v" "$result_file" )` (`lib/tools.sh:296-299`). Results (integrity status, path, package id) come back through `$TOOL_TMP/result`, not variables. Return codes are handled explicitly.
  - **Validation:** after each change and for each reused tool, the tool must run and its observed version must equal the frozen target. The record is written straight after validation, so independent successes survive a later failure.
  - **Removal:** check absence after each one, revert installer-created integration (completion files, shims), and record `failed` on a partial removal.
  - **Final report:**
    - prerequisite versions;
    - per tool: requested, latest, previous, target, integrity, result;
    - groups reduced by request and dependents that were blocked.
  - **Exit:** non-zero if anything failed.
- **Ownership:**
  - Only an install or upgrade done by this installer sets `owner: workstation-tools`. A reused install records `owner: external`.
  - Existing binaries are adopted only at our own target path (`~/.local/bin/<bin>`).
  - The same tool active elsewhere on PATH is a `conflict`: that tool fails with "remove manually, then rerun".
- **Per-tool OS contract (one definition, in the tool's first group's script):**
  - `tool_<id>_latest`;
  - `tool_<id>_probe`: one line per install found, active-on-PATH first, columns `version<TAB>path<TAB>source<TAB>package_id`;
  - `tool_<id>_install VER RESULT_FILE`;
  - `tool_<id>_remove`;
  - `tool_<id>_validate`.
- **Platform-provided tools** (source `os`): probe and validate only. Pins are rejected and they are never owned.

## `base` sources (Phase 1)

| Kind | Ubuntu | macOS |
|---|---|---|
| OS packages | apt: ca-certificates, curl, wget, zip, unzip, tar, gzip, git, openssh-client, build-essential, tree, ripgrep, fzf, tmux, rsync, dnsutils (dig + nslookup bundled), netcat-openbsd, python3, python3-pip | Homebrew: wget, tree, ripgrep, fzf, tmux, python3 (pip3 bundled). `os` source: curl, zip, unzip, tar, gzip, ssh, rsync, dig, nslookup, nc, make, git (CLT), CA certificates |
| Release binaries → `~/.local/bin`, SHA-256 | jq, yq, direnv, starship, uv (+uvx bundled) | same |
| AI CLIs | Codex, Claude Code, Gemini CLI, Antigravity CLI, gemini-notebook-mcp-cli | same |

- **AI CLI sources:** check each against current docs (Context7 or web) during implementation. Order of preference:
  1. a native installer or release binary with a checksum;
  2. npm through the bootstrap Node (re-sourcing `nvm.sh` in main; a Node bump moves the global prefix, so the probe sees the CLI as absent and reinstalls it);
  3. `uv tool install` for gemini-notebook-mcp-cli.

  If Antigravity has no CLI install route on a platform, it fails clearly.
- **Ubuntu pip3:** OS package only, per Known limitations.

## Tests (plain Bash, following the `tests/codex-deploy.sh` patterns)

- `run.sh` runs every `test-*.sh`. `helpers.sh` holds `assert`, `fail`, the fixture setup (fake HOME/XDG, stubs first on PATH), and a `snapshot` that also captures directories, symlinks, and modes via `ls -lRa`.
- **Mutation-spy stubs** for brew, apt-get, dpkg, sudo, chsh, softwareupdate, xcode-select, and curl log every call.
- **Fake platform** handlers append to a trace file. This drives the whole engine with no network or root.
- Coverage:
  - **Config:** `.env` as data (injection lines aren't executed, values aren't printed); `--groups` replaces the env selection; implicit base; unknown groups; cycles; topological order.
  - **Requested file:** create, preserve, pin, `latest` kept, remove/delete synonyms, `--tool-version` conflicts, provider/bundled pin conflicts.
  - **Sequence (trace):**
    - all discovery happens before any probe;
    - pinned tools are discovered too;
    - a discovery failure blocks installs but not removals;
    - a failed dependency blocks its dependents;
    - independent successes are recorded;
    - a version mismatch fails validation.
  - **Integrity:** verified, unverified, fetch-failed, malformed, and mismatch all handled; the artifact is deleted on failure; the status crosses the real install subshell.
  - **Removal rules:** base override, `never`, hard dependencies, `owner: external` and conflict errors (message text), absence check, idempotent rerun (with `--allow-base-removal` every run).
  - **Dry-run:** the snapshot and spy log show no mutation, including runs where Bash, private jq, Homebrew, or nvm is missing.
  - **Unchanged rerun:** reinstalls nothing.
  - **Interruption:** `WST_TEST_ABORT_AT` barriers after the lock `mkdir` (before the pid), around the state rename, and after install (before record). Each must leave no false success and no malformed JSON. Plus a two-process contention test.
- **Real shell boundary:** `/bin/bash tools/setup-workstation.sh --dry-run` from a different working directory, using macOS Bash 3.2 and a real Bash 5 found as `BASH5`, with package tools stubbed. Assert that the exec happens, arguments and environment are preserved, and the lock is cleaned up.
- **Catalog sync:** `test-catalog-sync.sh` compares the TSVs with `TOOL-GROUPS-CONSOLIDATED.md`.
- **Lint:** `bash -n` and `shellcheck -s bash -x` on everything, plus the Bash 3.2 forbidden-construct grep (`docs/DEVELOPER-GUIDE.md:9`) on the orchestrator files.

## Verification

1. Run `tools/tests/run.sh` on macOS. Everything must pass.
2. Ubuntu container: `docker run --rm -it -v "$PWD":/src ubuntu:24.04`, running as root, which exercises the `SUDO=""` path.
   - First run `--dry-run`, then a real run. The real run should exit 75, or warn that `chsh` isn't possible.
   - Rerun. Check the base plan table and both dotfiles.
   - Run a third time. It should report only reuse.
3. **Out of scope for Phase 1 development; owner-run later on a separate VM.** Not executed on the development machine. Done so far: stub suite, Ubuntu container runs (step 2), and a read-only macOS `--dry-run`. Real macOS, run by you because it changes Homebrew, `chsh`, and `/etc/shells`:
   - dry-run, then a real run, then a new terminal and a rerun;
   - `tree: remove` without the override should be rejected as base;
   - `tree: remove` with `--allow-base-removal --yes` should remove it, record `removed`, and make no changes on an identical rerun;
   - `jq: remove` should be rejected as `never`.
4. `./deploy.sh --dry-run` should still show jq/yq/direnv/starship unchanged.

## Known residual risk

`deploy.sh --uninstall` deletes `~/.local/bin` binaries listed in its `versions.lock`. That includes jq/yq/direnv/starship after this installer upgrades them. This is accepted until the deferred `deploy.sh` change.

## Codex review disposition

- **Accepted:**
  - incomplete base coverage (Ubuntu curl, macOS git);
  - state failure semantics and the record schema;
  - discovery and validation gates;
  - login shell checked every run;
  - provider/bundled pin conflicts;
  - removal completion;
  - the final report;
  - the subshell result channel;
  - dry-run through bootstrap;
  - integrity provenance (fetch-failed is not the same as unpublished);
  - the ownership `owner` field and conflicts;
  - the lock lifecycle across `exec`;
  - absolute paths;
  - root without sudo;
  - the headless CLT algorithm with a timeout;
  - brew `shellenv` and frozen targets;
  - nvm updated every run with `--latest-npm`;
  - the multi-install probe contract;
  - loading handlers for removal-flagged tools;
  - the boundary, snapshot, trace, integrity, and interruption tests.
- **Modified:**
  - **APT "latest" stays as the policy candidate.** R defines it as the newest version from the configured repositories; the full `dpkg` version and `dpkg --compare-versions` were adopted.
  - **Interruption tests use 3 barriers**, not the full matrix.
- **Cut:**
  - minisign/cosign/gpg backends (SHA-256 and `pkgutil` only);
  - the universal version comparator (comparison is per source);
  - the module count (log merged into common, removal merged into plan).
- **Deferred:**
  - real apt/brew package-behavior fixtures (Phase 2);
  - `deploy.sh` ownership coordination (deferred by you; risk noted above).

## Out of scope for Phase 1

Every group other than `base`; the `deploy.sh` tool-ownership change; the Ubuntu pip3 fix.

---

# Phase 2 — `containers` + `aws` groups

Phase 1 is complete and tested. Phase 2 adds `aws`, which declares `containers` as a group dependency. Both groups ship together, on the same per-tool contract (`latest/probe/install/remove/validate`) and the same engine. No engine changes are expected; the catalog TSVs, handlers, docs, and tests change.

## Scope

`containers` (catalog rows already exist): `docker-cli`, `docker-engine`, `docker-compose`, `docker-buildx`.
`aws` (rows exist): `awscli`, `session-manager-plugin`, `aws-cdk`, `aws-sam`, `docker`. `jq` and `python3` come from `base`.

## Files

- `scripts/ubuntu/groups/{containers,aws}.sh`
- `scripts/macos/groups/{containers,aws}.sh`
- `scripts/common/` — new generators only if two tools need the same shape (for example `pkg_tool` for a downloaded `.pkg`/`.deb`).
- Tests: extend `test-catalog-sync.sh`, add `test-aws-handlers.sh` (fake platform plus stubbed curl/apt/brew/pkgutil).

## Sources (to verify against current docs with Context7 or web before coding)

| Tool | Ubuntu | macOS |
|---|---|---|
| docker-cli, docker-compose, docker-buildx | Docker apt repo: `docker-ce-cli`, `docker-compose-plugin`, `docker-buildx-plugin` | Homebrew: `docker`, `docker-compose`, `docker-buildx` |
| docker-engine | `docker-ce`, `containerd.io` | Colima (`brew install colima`) |
| awscli | official zip from `awscli.amazonaws.com` | official `.pkg`, `pkgutil --check-signature` |
| session-manager-plugin | AWS-published `.deb` | AWS-published bundle or brew cask |
| aws-cdk | npm `aws-cdk` via the existing `npm_tool` | same |
| aws-sam | release zip from `aws/aws-sam-cli` | release `.pkg` or brew |
| docker (aws-group) | validate-only: CLI present and daemon reachable | same, via Colima |

## Open decisions (need owner input before implementation)

1. **Docker apt repo on Ubuntu.** It adds a third-party apt source and GPG key under `/etc/apt`, and installing `docker-ce` starts a daemon. Alternative: Ubuntu's own `docker.io` plus `docker-compose-v2` and `docker-buildx`, with no extra repo. Recommendation: Docker's official repo, matching the catalog's "latest" intent.
2. **Checksums for AWS artifacts.** AWS publishes GPG signatures for the CLI zip, not SHA-256, and Phase 1 cut the gpg backend. `awscli` is `checksum: yes` in the catalog. Either flip it to `no` (reported `unverified`) on Linux, or restore a GPG backend for this one tool. Recommendation: `pkgutil` on macOS, `unverified` on Linux, catalog updated to match.
3. **`docker` as a tool.** The catalog gives it `depends docker-cli`, `relation runtime`. Treat it as a validate-only aggregate with no install of its own, and reject pins. Confirm.
4. **Colima lifecycle.** The installer installs Colima but should not `colima start` (starts a VM). Validation checks the CLI only on macOS. Confirm.

## Order of work

1. Resolve the four decisions; update `REQUIREMENTS.md` and `TOOL-GROUPS-CONSOLIDATED.md` if any change.
2. `containers` handlers and tests, then `aws` handlers and tests.
3. `tools/tests/run.sh`, lint, and `./deploy.sh --dry-run` unchanged.
4. Ubuntu container run (`--groups aws`, root, then rerun for reuse-only). Real macOS stays owner-run.

---

# Phase 3 — `kubernetes` + `argocd` groups

Phase 2 handlers (`containers`, `aws`) exist for both OSes. Phase 3 adds `kubernetes` (depends on `containers`) and `argocd` (depends on `kubernetes`), on the same per-tool contract. No engine changes expected; catalog rows already exist.

## Scope

`kubernetes`: `eksctl`, `kubectl`, `kubectx`, `kubens` (bundled), `kubecolor`, `helm`, `k9s`, `stern`, `kustomize-embedded` (bundled in kubectl), `kustomize`, `kind`, `helmfile`, `docker` (validate-only, from Phase 2). `jq` and `yq` come from `base`.
`argocd`: `argocd-cli`, `kubectl`.

## Files

- `scripts/{ubuntu,macos}/groups/{kubernetes,argocd}.sh`
- `scripts/common/` — a shared `gh_release_tool` generator for tools that ship `.tar.gz`/binary + checksum file on GitHub releases (eksctl, kubectx/kubens, kubecolor, k9s, stern, kustomize, kind, helmfile, argocd). Add only if three or more handlers share the shape.
- Tests: extend `test-catalog-sync.sh`; add `test-k8s-handlers.sh` (fake platform, stubbed curl/tar/brew).

## Sources (verify against current docs with Context7 or web before coding)

| Tool | Ubuntu | macOS |
|---|---|---|
| kubectl | `dl.k8s.io` binary + published `.sha256`, to `~/.local/bin` | same (or brew `kubernetes-cli`) |
| kubectx, kubens | GitHub release tarball + `checksums.txt` | same |
| kubecolor | GitHub release tarball + checksums | same |
| helm | `get.helm.sh` tarball + `.sha256sum` | same |
| k9s | GitHub release tarball + `checksums.sha256` | same |
| stern | GitHub release tarball + checksums | same |
| kustomize | GitHub release tarball + `checksums.txt` | same |
| kind | `kind.sigs.k8s.io` binary + `.sha256sum` | same |
| helmfile | GitHub release tarball + checksums | same |
| eksctl | GitHub release tarball + checksums | same |
| argocd-cli | GitHub release binary + `cli_checksums.txt` | same |
| kustomize-embedded | validate-only: `kubectl kustomize` works | same |

## Open decisions (need owner input)

1. **kubectl pin skew.** `kubectl` supports only ±1 minor of the cluster. Keep `latest` default and let the requested file pin it per client. Confirm no automatic skew check.
2. **Plugin vs. binary for kubectx/kubens.** Release tarball (no krew) keeps the `~/.local/bin` model. Confirm krew is out of scope.
3. **kubecolor / helmfile `runtime` relation.** Removing `kubectl` or `helm` while these remain is rejected as a hard dependency (existing removal rule 5). Confirm.
4. **helm plugins** (for example helm-diff, needed by helmfile). Out of scope for this phase unless you want helmfile to bootstrap `helm-diff`.

## Order of work

1. Resolve the decisions; update `REQUIREMENTS.md` and `TOOL-GROUPS-CONSOLIDATED.md` if any change.
2. `kubernetes` handlers and tests, then `argocd`.
3. `tools/tests/run.sh`, lint, `./deploy.sh --dry-run` unchanged.
4. Ubuntu container run (`--groups argocd`, root, then rerun for reuse-only). Real macOS stays owner-run.

---

# Phase 3/4 status — all remaining groups implemented

Implemented on the same contract, no engine changes, `tests/run.sh` all passing:
- `kubernetes`, `argocd`: `scripts/common/k8s-shared.sh` (`gh_release_tool` generator; custom kubectl via `dl.k8s.io`, helm via `get.helm.sh`). Phase 3 decisions taken as recommended: no skew check, no krew, rule 5 applies, no helm plugins.
- `terraform`, `terragrunt`, `github`: `scripts/common/tf-shared.sh` (tfenv git clone in `~/.local/share/tfenv`; terraform via tfenv, integrity `provider`; terragrunt + gh release archives with SHA-256).
- `ansible`, `go`, `database-*`: `scripts/common/misc-shared.sh` (ansible via `uv tool install --with-executables-from ansible-core`; Go tarball from `go.dev/dl/?mode=json` into `~/.local/share/go`; DB clients via apt / brew, keg-only clients linked into `~/.local/bin`).

Pending Ubuntu field validation: `mysql-client` apt package name per release; real tfenv/terraform install; tool `--version` parsing; unauthenticated GitHub API rate limits (kustomize latest).
