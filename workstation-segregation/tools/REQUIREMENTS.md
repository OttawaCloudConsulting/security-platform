# Workstation Tool Installation Requirements

## Current requirements

The installer must configure development workstations from a clean installation of Ubuntu or macOS. A base installation script must read project group selections from a `.env` file or command-line arguments and dispatch installation to operating-system-specific group scripts.

[TOOL-GROUPS-CONSOLIDATED.md](TOOL-GROUPS-CONSOLIDATED.md) defines the tools, group membership, and group dependencies. It is the authoritative tool reference for this installer. Always include `base`; include other groups only when selected or required by a selected group. Install shared tools once, and retain the separate database groups.

For every selected tool, the script must first discover its current `latest` version, then check its existing presence and installed version. It must install or update the tool to its requested version and validate the result using `--version` or an equivalent tool-specific check. Requested versions default to `latest`, with explicit version pins supported.

The installer must maintain two dotfiles: one recording requested tools and versions, and one recording verified installed versions. Existing requested-version settings must be preserved and reused across runs.

The installer must also uninstall a tool when the requested-versions file marks it for removal. Removal is only ever triggered by that explicit flag; see [Tool removal](#tool-removal).

Bash, Homebrew, and Xcode Command Line Tools are orchestrator prerequisites rather than managed tools; see [Orchestrator prerequisites](#orchestrator-prerequisites).

## Group configuration

- Default to reading `.env` in the current project directory. Support `--env-file PATH` for an explicit configuration file.
- Read `TOOL_GROUPS` as a comma-separated list of group identifiers. Trim whitespace, remove duplicate entries, and reject unknown identifiers before installation.
- Support `--groups GROUPS`. When provided, this selection replaces the `.env` selection rather than merging with it.
- If no configuration or group selection is provided, select only `base`. An explicitly specified configuration file that cannot be read must produce an error.
- Expand dependencies recursively, detect dependency cycles, and install dependencies before dependent groups.
- Parse `.env` as data; do not source it as executable shell code. Ignore unrelated project variables and do not print their values.
- Changing the selected groups must not uninstall tools from previous runs. Deselecting a group never removes its tools; only an explicit removal flag does.

Example project configuration:

```dotenv
TOOL_GROUPS=aws,kubernetes,terraform,github
```

Example entry-point commands:

```bash
./setup-workstation.sh --env-file .env
./setup-workstation.sh --groups kubernetes,ansible,database-postgres
./setup-workstation.sh --env-file .env --groups aws,terraform
./setup-workstation.sh --dry-run
```

## Requested versions dotfile

Use `.workstation-tools-requested.json` in the project directory by default. Support `--requested-file PATH` to use an existing file elsewhere. This file expresses installation intent and is separate from observed workstation state.

- Create the file if it does not exist. Add all tools in the resolved selection, including dependency tools, with requested version `latest`.
- Use stable, canonical tool identifiers shared by both operating-system implementations. Multiple groups must refer to the same identifier for a shared tool.
- Preserve existing entries and explicit pins. Add newly selected tools without resetting earlier requests.
- Allow the user to replace `latest` with an exact version in the file.
- Allow the user to replace a version value with `remove` or `delete` to request removal. The two values are synonyms; preserve whichever the user wrote.
- Support repeatable `--tool-version TOOL=VERSION` arguments. These override and persist the corresponding entries for selected tools before installation; reject unknown or unselected tool identifiers. Reject a `--tool-version` argument for a tool the file marks for removal rather than choosing one by precedence.
- Preserve entries for tools outside the current selection, but do not install them merely because they appear in this file. A removal flag is acted on whether or not the tool is in the current selection.
- Accept removal flags only for known canonical tool identifiers; reject unknown identifiers before changing installations.
- Keep `latest` as the requested value after resolving it; do not overwrite it with the discovered version. An exact pin remains fixed until the user changes it.
- Validate the file and requested version syntax before changing installations. Write changes atomically.
- Orchestrator prerequisites must not appear in this file. Reject entries and `--tool-version` arguments for them.
- Installations are workstation-wide while this file is per project. When projects request different versions, the most recent run wins; switching between projects may change installed versions, and this is accepted.

Illustrative format:

```json
{
  "schema_version": 1,
  "tools": {
    "kubectl": "latest",
    "terraform": "1.9.8",
    "jq": "latest",
    "k9s": "remove"
  }
}
```

The Terraform version above illustrates a pin; it is not a recommended default. The `k9s` entry illustrates a removal request.

## Installed versions dotfile

Use `$HOME/.workstation-tools-installed.json` by default so the record describes the workstation across projects. Support `--installed-file PATH` for an alternate location.

- Create the file if absent and preserve records outside the current selection.
- Each record has an `owner` (`workstation-tools` when this installer installed or upgraded it, `external` when an existing installation was reused) and a `status` (`installed`, `stale`, `failed`, or `removed`).
- Record each selected tool's verified version, executable path or package identity, installation source, integrity verification method, operating system, architecture, and UTC verification timestamp.
- Record the latest version discovered during the run and the resolved target version separately from the verified installed version.
- Treat this file as a record, not proof that a tool is still installed. Inspect the actual workstation on every run.
- Update a successful record only after validation passes. A failed update must not be recorded as a successful installation; mark any existing record as stale or failed until verified again.
- Preserve successful results from partially completed runs and use atomic writes to prevent truncated state. Prevent concurrent runs from overwriting each other's records.
- Do not store credentials, tokens, or unrelated `.env` values in either dotfile.
- After a verified removal, mark the record `removed` with the UTC verification timestamp and the removed version and source. Retain the record rather than deleting it.
- Do not record orchestrator prerequisites as managed tools.

## Version discovery and installation sequence

0. Run the [orchestrator prerequisites](#orchestrator-prerequisites) step. If it installs or upgrades Bash, it terminates the run before step 1.
1. Read configuration, detect Ubuntu or macOS and CPU architecture, resolve groups and tool dependencies, and load or create the requested-version file.
2. Discover the current `latest` version of every tool in the resolved selection, including tools with explicit pins. Complete this discovery phase before checking selected tool presence and installed versions. Skip discovery for tools marked for removal; a discovery failure must not block a removal.
3. Resolve each requested target: the discovered version for `latest`, or the exact requested version for a pin. Confirm that an installation source supports the target on the detected OS and architecture.
4. Inspect actual tool presence, active executable paths, and installed versions. Detect conflicting installations and distinguish a present executable from one that can run successfully.
5. Produce an installation plan identifying tools that can be reused, installed, upgraded, changed to a pinned version, or removed. Validate removal requests against the rules in [Tool removal](#tool-removal) and obtain confirmation for planned removals. With `--dry-run`, print the plan and stop without changing the workstation or either dotfile.
6. Dispatch to the OS group scripts. Execute removals first, in reverse dependency order, then install exact resolved targets in dependency order. Skip changes when the active version already matches the target and validates successfully.
7. Verify the integrity of every downloaded artifact before installing it; see [Download integrity](#download-integrity). Run `--version` or the defined equivalent check after each installation or update. Also validate tools reused without changes. After each removal, confirm that the removed installation is no longer present.
8. Confirm that the observed version matches the resolved target, update the installed-version dotfile, and report results. Return a nonzero exit status if any required tool fails discovery, integrity verification, installation, or validation, or if any tool marked for removal remains installed.

### Latest version policy

- Define `latest` as the newest stable release installable for the selected OS and architecture from the tool's declared source. Exclude prereleases unless explicitly pinned.
- Use authoritative release metadata or package-manager metadata. Record the source and resolved version once per run so installation and validation use the same target even if a release changes mid-run.
- For OS packages, `latest` means the newest applicable version available from the configured supported repositories. Make this distinction visible in the installation plan.
- Do not silently fall back to a cached version or another version when discovery fails. Report the failure before installing selected tools.
- Never substitute `latest` for an unavailable pin. Report unsupported or unavailable pinned versions explicitly.
- Compare versions using tool-specific normalization, including version prefixes and package revisions; do not compare version strings lexicographically.
- Resolve bundled commands through their provider. For example, uvx follows uv, and embedded Kustomize follows kubectl. Reject conflicting pins on a provider and its bundled commands.
- For tools supplied by an OS component or package without a standalone version flag, use package or provider metadata plus a functional check. Record that relationship and reject pins the provider cannot honor.
- Respect compatibility requirements declared by tools and repository version files. If an exact pin conflicts with those requirements, stop with an explanation rather than silently changing it.

### Download integrity

- Verify every directly downloaded artifact against the checksum (SHA-256 or stronger) or signature (for example GPG, minisign, cosign, or a macOS package signature) that upstream publishes for that release. Fetch checksums and signatures over HTTPS from the same authoritative release source.
- For package-manager installations, rely on the package manager's signed repository metadata. Add third-party apt repositories only with their published signing key, scoped to that repository.
- On a checksum mismatch or failed signature, delete the artifact, do not install it, and record the tool as failed. Never fall back to an unverified artifact or another source.
- Each tool declares `checksum: yes|no` in the catalog. When upstream publishes a checksum and fetching or parsing it fails, the tool fails; it is never reported as unverified. Only tools declared `checksum: no` are reported as unverified.
- Where upstream publishes neither a checksum nor a signature, the tool may still be installed, but mark it as unverified in the installation plan, the final report, and the installed-versions record.

## Orchestrator prerequisites

Bash, Homebrew (macOS), and Xcode Command Line Tools (macOS) are handled by the orchestrator in the entry point before any configuration is read. They are not members of any group, do not appear in either dotfile, cannot be pinned, and are never removed.

- The entry point must run using the system-provided shell, such as Bash 3.2 on macOS, before Bash 5+, Python, jq, or other selected tools are installed. The orchestrator must remain compatible with that shell and must not depend on selected tools already being present.
- Only the minimum prerequisites needed to run the orchestrator, access release metadata, and invoke the platform package manager may be bootstrapped here. This includes HTTPS transport and trust prerequisites where missing.
- **Xcode Command Line Tools (macOS).** Install if absent. Because the installation is large and slow, do not reinstall or force updates on later runs.
- **Homebrew (macOS).** Install if absent, then update Homebrew to its latest release on every run.
- **nvm and Node.js.** Run nvm's installer on every run (it updates an existing clone), then install the Node.js LTS release with the latest npm and make it the nvm default. Never remove them; Node.js versions the user installed through nvm are untouched.
- **Private bootstrap jq.** Download the latest jq release to `~/.local/share/workstation-tools/bootstrap/bin/jq`, verified against the published `sha256sum.txt`. It is used only by the installer to read and write the dotfiles and is separate from the managed `jq` tool. Under `--dry-run` it is placed in a temporary directory only.
- **Bash.** Install or upgrade Bash to the latest version on every run: from Homebrew on macOS, and the newest version in the configured repositories on Ubuntu. Register the installed Bash in `/etc/shells` and configure it as the user's default login shell. Keep platform-provided system executables, including `/bin/bash` on macOS, intact.
- If the orchestrator installs or upgrades Bash, it must stop after doing so and print a message telling the user to open a new terminal so the updated shell is in effect, then rerun the script. Use a documented, distinct exit status for this case so automation can tell it apart from a failure.
- When Bash is already at the latest version, continue the run and invoke all fan-out scripts explicitly with that Bash, not the system Bash.
- All scripts other than the orchestrator, including the common libraries and OS group scripts, require and may use Bash 5 features.
- Report the versions of the orchestrator prerequisites in the final output.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | failure (a tool failed, a removal was rejected, or a prerequisite failed) |
| 2 | usage error |
| 75 | restart needed: Bash was installed or upgraded, or the login shell changed; open a new terminal and rerun |

With `--dry-run` when Bash is older than 5, the orchestrator prints the prerequisite actions only, exits 0, and states that the full plan needs Bash 5.

## Tool removal

A requested value of `remove` or `delete` declares that the tool must not be installed on the workstation. Removal is an explicit, per-tool request; it is never inferred from group deselection or from a tool's absence in the requested-versions file.

- **Base tools.** Tools in `base` are always retained. Reject a removal flag on a `base` tool before changing installations unless the run includes `--allow-base-removal`. With that flag, honor the removal as an explicit opt-out, exclude the tool from installation, and report `base` as reduced by request. The flag applies to one run only, so it is required on every run while a `base` tool carries a removal flag.
- **Not removable.** The installer installs and upgrades jq, yq, direnv, and starship but never removes them, even with `--allow-base-removal`. It also never removes the tools it needs to run: CA certificates, curl, tar, gzip, unzip, and Git. Reject removal flags on these tools with an explanation. Orchestrator prerequisites are not managed tools and cannot be flagged.
- **Other groups.** A removal flag on a tool listed by another selected group is honored as an explicit opt-out. Exclude the tool from installation and report the affected groups as reduced by request.
- **Hard dependencies.** Reject the removal, before changing installations, when the tool is a provider or bundled command of a tool that remains selected (for example uv and uvx, kubectl and its embedded Kustomize, tfenv and Terraform), or a tool-level dependency of a tool that remains selected (for example Docker while kind is selected). Removing a provider together with all of its bundled commands is permitted. Tool-level dependencies are declared in the authoritative tool reference.
- **Ownership.** Remove only installations this installer made, as identified by a matching installed-file record (source, executable path, or package identity) and confirmed by inspecting the workstation. For an installation that predates the installer, comes from a different source, or has no matching record, do not remove it. Print an error naming the tool, its path, and its detected source, and telling the user to remove it manually and rerun the script so the installer can manage it. Return a nonzero exit status because the request is unmet.
- **Method.** Uninstall through the same source used to install: the package manager for packages, the provider for provider-managed tools (for example `tfenv uninstall`), and deletion of the recorded files for direct downloads. Revert configuration the installer made for that tool only, such as a shell completion file, a PATH shim, or a package repository, keyring, or Homebrew tap it added when no remaining tool uses it.
- **User data.** Remove executables and packages only. Do not delete user configuration, credentials, caches, or data, such as `~/.aws`, `~/.kube`, Docker images, containers, and volumes, or Node.js versions installed by the user through nvm.
- **Confirmation.** Show every planned removal in the installation plan. Require interactive confirmation, or `--yes` in non-interactive runs, before removing anything. `--dry-run` prints planned removals without performing them.
- **Idempotence.** Keep the removal flag in the requested-versions file after a successful removal. A rerun verifies that the tool is still absent and makes no changes. To reinstall, the user replaces the flag with `latest` or a version.
- **Recording.** Mark the installed-file record `removed` only after absence is verified. A failed or partial removal must be recorded as failed, not as removed.
- Do not attempt to detect or protect other projects that still use a removed tool. Running the installer from such a project reinstalls it.

## Base script and OS group scripts

The base installation script is the single user-facing entry point. It owns the orchestrator prerequisites, configuration parsing, group and tool dependency expansion, requested-version persistence, release discovery, installation planning, state recording, and final reporting.

It must dispatch to scripts organized by operating system and group. A proposed structure is:

```text
setup-workstation.sh
scripts/
  common/
    configuration.sh
    groups.sh
    versions.sh
    state.sh
  ubuntu/
    bootstrap.sh
    groups/
      base.sh
      aws.sh
      kubernetes.sh
      ...other selected group scripts
  macos/
    bootstrap.sh
    groups/
      base.sh
      aws.sh
      kubernetes.sh
      ...other selected group scripts
```

- Provide an OS group script for every supported group, including each database group independently.
- Keep group membership and dependency definitions shared across operating systems so they remain consistent with the authoritative tool reference.
- OS scripts implement platform-specific release sources, presence checks, installation and removal methods, and validation commands behind a common interface.
- Pass each script the resolved tool targets and installation plan. OS scripts must not independently reinterpret group selections, discard pins, or re-resolve `latest` during installation.
- A tool installed through one group must be reused by subsequent groups in the same run.
- Support Ubuntu and macOS on x86_64 and arm64 where the selected tool has a supported installation. Fail clearly for unsupported required tools or platforms.
- Use elevated privileges only for operations that require them; install user-scoped tools as the invoking user.

## Validation and completion

- Define a presence probe, version probe, installation source, integrity check, and validation command for every supported tool or provider.
- Probe shell functions and CLI plugins through their supported interfaces rather than assuming every tool is a standalone executable.
- Validate Docker Compose and Buildx through the Docker CLI, and validate client tools without requiring account authentication or a running remote service.
- Show the requested value, discovered latest version, previous installed version, resolved target, integrity status, and final result for each selected tool.
- Make reruns repeatable: a validated tool already at its target version must not be reinstalled.
- Report failed tools and dependent groups that could not complete. Independent successful tools must remain recorded for the next run.
- Tool installation must not create clusters, deploy infrastructure, authenticate user accounts, or install local database servers when only clients are requested.

## Known limitations

- **dig and nslookup on Ubuntu.** They are provided by the `dnsutils` package, so they follow it as bundled commands and cannot carry independent pins.
- **pip3 on Ubuntu.** The Ubuntu system Python is externally managed (PEP 668), so pip cannot upgrade itself in the system environment. Install and validate pip3 from the OS package, with `latest` meaning the newest repository version. A full fix is deferred to a separate project.

## Acceptance criteria

- On a clean supported Ubuntu or macOS workstation, the entry point bootstraps successfully and installs the resolved selection.
- The first run on a workstation without the latest Bash installs or upgrades it, sets it as the login shell, and exits with the documented restart status and message. The next run, from a new terminal, continues with the installation.
- Homebrew is updated and Bash is upgraded to latest on every run; Xcode Command Line Tools is installed only when absent. None of them is ever removed.
- `.env` selection, explicit configuration paths, CLI group overrides, implicit `base`, and recursive dependencies behave as specified.
- Selecting `aws` does not automatically select `kubernetes`; selecting both supports the documented EKS tooling workflow.
- Each selected tool has its latest version resolved before the main presence/version inspection phase, then has its actual installation inspected and validated.
- A `latest` request updates to the discovered target; an exact pin is retained and installed, or produces an explicit failure if unavailable.
- Downloaded artifacts with a published checksum or signature are verified before installation; a mismatch fails that tool and installs nothing. Tools without published checksums are reported as unverified.
- Requested and installed version dotfiles are created when absent, reused when present, and retain unrelated entries.
- An unchanged rerun performs discovery and validation without reinstalling tools already at their targets.
- Failure and interruption do not produce false success records or malformed dotfiles.
- A tool marked `remove` or `delete` that the installer previously installed is uninstalled after confirmation, verified absent, and recorded as `removed`; user data for that tool is retained.
- A removal flag on a `base` tool is rejected unless `--allow-base-removal` is given. A removal flag on jq, yq, direnv, starship, an installer runtime prerequisite, or a hard dependency of a remaining selected tool is rejected even with that flag.
- A removal flag on an installation the installer does not own produces an error telling the user to remove it manually and rerun.
- Deselecting a group, or omitting a tool from the requested-versions file, removes nothing.
- A rerun with an unchanged removal flag makes no changes. `--dry-run` reports the full plan, including planned removals, without changing anything.

This document defines the implementation requirements; it does not implement the installer.
