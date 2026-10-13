# AGY Google-login isolation probe

AGY integration is deferred until login-isolation evidence is available.
Run this guided probe from a normal interactive terminal in the kit directory:

```bash
./tests/agy-login-isolation.sh
# Optional explicit installed executable:
./tests/agy-login-isolation.sh --binary "$HOME/.local/bin/agy"
```

The script records the executable path and `--version` output in a private
temporary report directory. It asks whether you already know that AGY has an
existing Google login. Answer `no` or `unknown` if there is no confirmed
baseline; the result is inconclusive and interactive launches are skipped.
It does not launch the existing account to establish a baseline.

For each candidate, launch fresh clients A and B, observe the initial account
state, then exit AGY. Stop before selecting sign-in or opening browser
authentication. Do not log in, log out, submit a model prompt, or resume a
session. Record only a fixed-choice observation:

| Observation | Meaning |
|---|---|
| `signin` | AGY asks for sign-in; no authentication was performed. |
| `reuse` | AGY silently shows the existing signed-in account. |
| `failed` | Startup failed. |
| `unknown` | Account state cannot be determined. |

No model request is needed to verify an account. If the startup screen cannot
establish its state, use `unknown`. Each launch can also be skipped. The probe
forwards arguments after `--` unchanged; use only startup options that cannot
authenticate, log out, submit prompts, resume sessions, or modify configuration.
The default launch passes no arguments.

The three candidates are tested independently, with separate A/B state, home,
temporary and initially empty workspace directories:

| Candidate | Subprocess setting | Status |
|---|---|---|
| `GEMINI_CLI_HOME` | Private `state` directory; original `HOME` retained. | Experimental: support by this AGY is unverified. |
| `HOME` | Private home for this launch only. | Experimental: AGY may use OS account storage instead. |
| `ANTIGRAVITY_APP_DATA_DIR` | Private `state` directory; original `HOME` retained. | Experimental: support by this AGY is unverified. |

The launcher clears inherited `GOOGLE_*`, `GEMINI_*`, `GCLOUD_*`, `CLOUDSDK_*`,
`AGY_*`, `ANTIGRAVITY_*`, and `VERTEX_*` settings, including credentials and
authentication overrides, in its subprocess. It also clears inherited XDG,
direnv and workstation overrides so those cannot redirect the experiment into
deployed client directories. It sets only the candidate being tested, retains
the ordinary executable search path, and reads no shell startup profiles.
The parent shell, client `.envrc` files and deployment scripts are unchanged.
No Gemini CLI installation or explicit OS keyring operation is performed.

Reports separate file relocation from login reuse. The path inventories list
new files, links and directories under each private context, excluding the
precreated empty scaffolding. They do not read file contents or follow links.
The report records each inventory's original directory. Normal completion,
input EOF and handled interruption delete raw application state in the private
contexts and retain only reports, version metadata and path inventories.
An uncatchable termination can leave temporary state behind.

Choose `inside`, `outside`, `both`, `none` or `unknown` for the separate file
relocation observation. The script does **not** scan shared home directories
or the keyring, so outside locations may be unknown. Paths outside the private
contexts are not inventoried or cleaned up. An unsupported relocation setting
may let AGY use its ordinary shared storage. These environment settings are
experimental candidates, not a filesystem sandbox or isolation guarantee.
No startup terminal transcript, account identifier or credential contents are
collected. The printed report location is private (directory mode 700, files
created with mode 600).

| Candidate result | Acceptance meaning |
|---|---|
| **Login reuse detected** | Either context silently reused the existing login. Candidate fails login isolation, regardless of file relocation. |
| **No reuse observed** | Both fresh contexts requested sign-in. A subsequent two-account test is warranted; this does not prove isolation. |
| **Inconclusive** | Unconfirmed baseline, failed/skipped launch, or undetermined account state. |

A startup exit other than 0 or 130 (Ctrl-C) cannot support a no-reuse result.
A positively observed reused account still counts as failure. Successful file
relocation never counts as successful authentication isolation.

## Verification and findings (2026-10-13)

```bash
/bin/bash -n tests/agy-login-isolation.sh tests/agy-login-isolation-stub.sh
/bin/bash tests/agy-login-isolation-stub.sh
```

Both checks passed on stock macOS Bash 3.2.57. The offline stub verified cleared
credentials and competing settings, original versus subprocess `HOME`, fresh
workspaces, six distinct candidate/client contexts, exact argument forwarding
(including spaces, empty arguments and literal `*`), private permissions,
version recording, all three result categories, startup-failure handling,
unconfirmed baselines, skipped launches, EOF recovery, and removal of raw
application state without credential contents in retained reports.

## Supplied AGY 1.3.4 findings

The supplied operator report summary identifies AGY **1.3.4** on macOS.
`GEMINI_CLI_HOME` and `ANTIGRAVITY_APP_DATA_DIR` reused the existing login;
both candidates are rejected. Fresh subprocess `HOME` contexts requested
sign-in. This establishes only the fresh-context observation, not persistent
account independence. The raw report was not supplied in this implementation
context; these findings are transcribed from the approved plan.

## Completed one-account operator check (2026-10-13)

Reviewed report: `/Users/christian/Documents/agy-account-check-01/reports/run.8rsVdj`.
The operator ran installed AGY **1.3.4** from a fresh state root in one-account
mode. Every interactive launch exited with status 0. The report records:

- Ordinary account before testing: `expected`.
- Fresh A before authentication: `signin`.
- A after operator authentication: `expected`.
- A reopened in another AGY process: `expected` (persistence observed).
- Untouched B after A authentication: `signin` (no reuse observed).
- Ordinary account after A authentication: `expected` (unchanged).
- File relocation: `unknown`, independent of account observations.

These complete the initial one-account operator checks. Account observations
are operator reported; no credential contents or retained application state
were inspected. Persistence across a separate harness invocation has not yet
been recorded. The overall result remains **pending** because this was
one-account mode. Two distinct accounts and real wrapper integration acceptance
remain untested; AGY activation stays disabled. Offline stub results are not
account evidence. Preserve this root for further persistence checks and use a
new root for eventual full two-account acceptance.

AGY documents silent authentication through the OS keyring. It does not promise
independent accounts merely because HOME differs. See the
[authentication documentation](https://antigravity.google/docs/cli/install.md).
Do not use logout during testing: its documented behavior purges saved keyring
profiles. No fallback to either rejected relocation candidate is permitted.

## Persistent operator test

Run from an ordinary interactive terminal, using a new, nonexistent absolute
state root (not an existing empty directory):

```bash
./tests/agy-account-isolation.sh --state-dir "$HOME/Documents/agy-account-check-01"
# Later, with a distinct second Google account and another fresh root:
./tests/agy-account-isolation.sh --state-dir "$HOME/Documents/agy-account-check-02" --accounts two
# Optional installed binary: --binary /absolute/path/to/agy
```

The default is `--accounts one`. No arbitrary startup arguments are accepted.
Authentication is explicitly authorized for the **operator** in this harness;
the implementation agent must not authenticate. Label the ordinary account,
A and B mentally. Never enter email addresses into harness responses. Each
interactive launch uses terminal I/O directly; nothing captures its output.
Observe only the identity display; no model prompts, logout, token copying,
explicit keyring changes, or installation is needed.

The sequence observes the ordinary account, checks fresh A for sign-in,
authenticates A, reopens A, checks untouched B for sign-in without authenticating,
and rechecks the ordinary account. Two-account mode then confirms that A and B
are distinct, authenticates B, checks A/B/A and rechecks the ordinary account.
`expected` means the account assigned to that context; `other` means any other
account. `signin`, `failed` and `unknown` complete the fixed-choice observations.
An account mismatch stops the run immediately with failure. A skipped,
undetermined or failed startup stops with a pending result. Exit status 130
can be a normal TUI exit; other nonzero statuses cannot establish a pass.

The harness clears the original probe's Google/AGY, relocation, XDG, workstation,
direnv and shell startup overrides in each child, replaces only child HOME and
TMPDIR, and launches from empty workspaces. The ordinary-account checks retain
ordinary HOME with the same clearing rules. Application files left in a workspace
cause a pending startup result; they are not deleted automatically.

Homes, temporary directories, and application state survive completion, EOF and
handled interruption. Reuse the same state root to check persistence across harness processes
(A only in one-account mode; A/B/A in two-account mode). Reused roots skip
fresh-context and authentication steps; a reused root can never produce full acceptance. Two-account
acceptance requires a fresh root. Separate reports are retained per run. A
marker recognizes initialized roots; unrelated roots, symlinked paths and
redirected required directories are rejected. Directories are mode 700 and
reports mode 600. The only command output retained is an exact version number
from `--version`; unrecognized version output is recorded as unknown. No
credential file contents, emails, or terminal transcripts enter reports. File
relocation is a separate operator observation, never account evidence.

A run lock prevents overlapping tests. Handled interruption removes it. After
an uncatchable termination, confirm the old harness is no longer running before
manually removing `<state-root>/.run-lock`; homes remain intact. Use a fresh
root for acceptance, rather than treating recovery as a fresh run.

A standalone fresh two-account pass establishes HOME account persistence for
that executable and platform. Before activation, repeat the account checks
through the integration wrapper in two disposable client environments, including
ordinary-account checks before and after, with the private Git configuration
and preserved absolute tool settings. Any mismatch blocks activation. Do not
claim an integration pass from the standalone harness or offline fixtures.
Repeat acceptance after an AGY upgrade.

## Gated integration and rollout

`ENABLE_AGY_CLI_ISOLATION=0` is the default and example setting. The live
configuration has not been changed. Both it and `ENABLE_AGENT_CLI_ISOLATION`
must equal 1 to scaffold AGY. New clients then receive private
`.workstation/agy/{home,tmp,gitconfig}` and `.workstation/bash/agy.sh`.
Adoption may prepare inert private files but never adds the AGY shell fragment
or changes an existing `.envrc`. Existing fragments are never removed just by
changing a configuration flag.

The `agy()` function uses `bin/agy-client.sh`. It validates client label,
directory, current working directory and required files, resolves the installed
binary before changing HOME, and forwards arguments and exit status. It clears
Google/AGY authentication/relocation, XDG and shell startup overrides only in
the child. Active workstation context and absolute client tool settings remain.
Private Git defaults include only the active client's Git configuration;
`GIT_CONFIG_GLOBAL` selects this file and competing inherited `GIT_CONFIG*`
overrides are cleared. System Git config is disabled in the child. Repository
Git config and explicit command options still apply. See
[Git environment documentation](https://github.com/git/htmldocs/blob/gh-pages/git.adoc).

After a real integration pass, set both flags to 1 in the kit configuration and
use the normal reviewed deployment workflow for **new** clients. To manually
migrate an existing client after acceptance:

1. Back up and review its `.envrc` and `.workstation/bash` fragments. Confirm its
   absolute client tool paths and active WORKSTATION_CLIENT / WORKSTATION_CLIENT_DIR.
2. Prepare the private directories and Git configuration using the kit's
   create-if-missing scaffold in adoption mode; review the resulting file. It
   must carry the defaults from `templates/git-global.conf` and include only
   that client's `.workstation/git/config`.
3. Render `templates/client/agy-fragment.sh` with the client name and absolute
   kit path to `.workstation/bash/agy.sh`. Do not overwrite an existing fragment.
4. Leave and re-enter the client so the fragment loads. Authenticate with its
   assigned Google account and confirm identity across fresh wrapper processes.
   Recheck other clients and the ordinary account. A mismatch blocks rollout.

Do not automatically migrate `mlse`, `occ`, or `zonal`. Never copy or link the
ordinary home's authentication, settings, plugins, or skills into private homes.
HOME-dependent tools and AWS caches inside AGY may need separate configuration
or login. This is account/configuration segregation, not a filesystem sandbox;
calling the binary directly bypasses the function.

Rollback: remove only the enabled client's `.workstation/bash/agy.sh`, then leave
and re-enter the client (or open a new terminal). Keep its private home intact.
Do not log out or clean up the keyring. Reset the AGY flag to 0 to prevent new
clients receiving the fragment.

## Offline integration verification

```bash
/bin/bash tests/agy-account-isolation-stub.sh
/bin/bash tests/agy-isolation.sh
/bin/bash tests/agy-deploy.sh
/bin/bash tests/agy-login-isolation-stub.sh
/bin/bash tests/codex-isolation.sh
/bin/bash tests/codex-deploy.sh
```

These use disposable fixtures and stub AGY executables. They cover persistence,
privacy, interruption recovery, environment clearing, parent preservation,
argument forwarding, exit statuses, context rejection, private Git identity and
credential routing, preserved tool settings, shell transitions, disabled flags,
adoption preservation, dry-run behavior and repeat-deploy idempotence. They do
not install AGY or Gemini CLI, call a model, authenticate, modify keyrings, or
deploy into live clients.

All six suites passed on macOS Bash 3.2.57 during this implementation. Bash 3.2
syntax checks passed for the new scripts and changed libraries. ShellCheck
passed for the new scripts; checks of the sourced libraries excluded their
existing SC2034, SC2015, SC2088 and SC2048 warnings (and SC1091 for variable
source paths). Git routing verification invoked a fixture credential helper.
No live deployment or browser authentication was performed.
